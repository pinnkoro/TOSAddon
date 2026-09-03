-- mini_addons の「特性をスキル順に並べる」を luajit 上で検査する（ゲーム不要）。
--
-- 並びの規則（misc/ability_sort.lua）:
--   1. スキルに紐付かない特性 … 先頭
--   2. スキルに紐付く特性     … 対応するスキルの表示順。同じスキルの中は素の並びを保つ
--   3. DEFAULT_ABIL           … 末尾（素と同じ）
-- 実機では素の並びが不安定ソート由来で毎回同じとは限らず、目視では「なんとなく揃った」
-- までしか分からない。規則どおりに決まることをここで機械的に見る。
--
-- 使い方（リポジトリルートから）:
--     luajit docs/tests/test_ability_sort.lua

local MANIFEST = "nexus_addons_p/src/build_manifest.json"
local SRC_DIR = "nexus_addons_p/src/"
local SRC_PREFIX = "addons/mini_addons/"
local SRC = SRC_PREFIX .. "**（manifest 順に連結）"

local function read_file(path)
    local f = assert(io.open(path, "r"), "読めない（リポジトリルートから実行すること）: " .. path)
    local data = f:read("*a")
    f:close()
    return data
end

local function mini_addons_parts()
    local targets = assert(read_file(MANIFEST):match('"targets"%s*:%s*(%b{})'),
        "manifest の targets を切り出せない: " .. MANIFEST)
    local parts = nil
    for array in targets:gmatch("%b[]") do
        local found = {}
        for rel in array:gmatch('"(' .. SRC_PREFIX .. '[^"]+%.lua)"') do
            table.insert(found, rel)
        end
        if #found > 0 then
            assert(parts == nil, "mini_addons の断片が複数の targets に散っている: " .. MANIFEST)
            parts = found
        end
    end
    assert(parts and #parts > 0, "manifest から mini_addons の断片を拾えない: " .. MANIFEST)
    return parts
end

-- ===== ゲーム API のスタブ =====
package.preload["json"] = function()
    return {encode = function() return "" end, decode = function() return {} end}
end

-- 素のスキル・特性ウィンドウの「職業 1 つ分」をここで持つ。
-- スキル欄: 解放 Lv ごとの段（Y）と段の中の位置（X）
-- 特性欄: 素が作った行（Y = 素の並び）と、ActiveGroup の括弧枠
local world = {}
local function reset_world()
    world = {
        skills = {}, -- name -> {x, y}
        ability_rows = {}, -- 素の並び順に {name}
        row_pos = {}, -- name -> {x, y}
        ability_cls = {}, -- name -> {ClassName, SkillCategory, Keyword, ActiveGroup}
        group_calls = {}, -- SKILLABILITY_MAKE_GROUP_BY_ACTIVE_GROUP に渡った名前の並び
        destroyed = {}, -- DESTROY_CHILD_BYNAME に渡った検索名
        vlog = {}
    }
end
reset_world()

local ROW_PREFIX = "skillability_ability_"
local ROW_HEIGHT = 40

local function make_row(name)
    return {
        GetName = function() return ROW_PREFIX .. name end,
        GetX = function() return world.row_pos[name].x end,
        GetY = function() return world.row_pos[name].y end,
        SetPos = function(_, x, y) world.row_pos[name] = {x = x, y = y} end
    }
end

local abilitylist_gb = {
    GetChildCount = function() return #world.ability_rows end,
    GetChildByIndex = function(_, i) return make_row(world.ability_rows[i + 1]) end
}
local skilltree_gb = {}
local skill_gb = {}
local ability_gb = {}
local skillability_job = {}

_G.GET_CHILD = function(parent, name)
    if parent == ability_gb and name == "abilitylist_gb" then
        return abilitylist_gb
    end
    if parent == skillability_job and name == "skill_gb" then
        return skill_gb
    end
    return nil
end
_G.GET_CHILD_RECURSIVELY = function(parent, name)
    if parent == skill_gb and name == "skilltree_gb" then
        return skilltree_gb
    end
    if parent == skilltree_gb then
        local skill = name:match("^SKILL_(.+)$")
        local pos = skill and world.skills[skill]
        if pos then
            return {GetX = function() return pos.x end, GetY = function() return pos.y end}
        end
    end
    return nil
end
_G.AUTO_CAST = function() end
_G.TryGetProp = function(obj, prop, default)
    if obj ~= nil and obj[prop] ~= nil then
        return obj[prop]
    end
    return default
end
_G.GetClass = function(cat, name)
    if cat == "Ability" then
        return world.ability_cls[name]
    end
    return {Name = name}
end
-- SkillTree は "<job>_<n>" の連番で引く（素の GET_TREE_INFO_VEC と同じ）
local skill_tree = {}
_G.GetClassList = function(cat) return cat end
_G.GetClassByNameFromList = function(_, name)
    return skill_tree[name]
end
_G.IS_ABILITY_KEYWORD = function(cls, keyword)
    return cls.Keyword == keyword
end
_G.DESTROY_CHILD_BYNAME = function(_, searchname)
    table.insert(world.destroyed, searchname)
end
_G.SKILLABILITY_MAKE_GROUP_BY_ACTIVE_GROUP = function(_, cls_list, height)
    local names = {}
    for i, cls in ipairs(cls_list) do
        names[i] = cls.ClassName
    end
    world.group_calls[#world.group_calls + 1] = {names = names, height = height}
end
_G.ui = {
    GetControlSetAttribute = function() return ROW_HEIGHT end,
    GetFrame = function() return nil end,
    SysMsg = function() end,
    Chat = function() end,
    CreateContextMenu = function() return {} end,
    AddContextMenuItem = function() end,
    OpenContextMenu = function() end,
    ENTERKEY = "ENTERKEY"
}
_G.GetIES = function(obj) return obj end
_G.ReserveScript = function() end
_G.pc = {ReqExecuteTx_Item = function() end}
_G.session = {
    loginInfo = {GetAID = function() return "me_aid" end, GetChannel = function() return 1 end},
    world = {
        IsIntegrateServer = function() return false end,
        IsIntegrateIndunServer = function() return false end,
        IsDungeon = function() return false end
    },
    party = {GetAllMemberCount = function() return 1 end},
    colonywar = {GetIsColonyWarMap = function() return false end},
    IsGM = function() return 0 end
}
_G.ScpArgMsg = function(key) return key end
_G.ClMsg = function(key) return key end
_G.GetClassByType = function() return {} end
_G.IsBuffApplied = function() return "NO" end
_G.GetPCObjectByCID = function() return nil end
_G.GetMyPCObject = function() return {} end
_G.GETMYFAMILYNAME = function() return "me" end
_G.CHAT_SYSTEM = function() end
_G.config = {GetXMLConfig = function() return 0 end}
_G.info = {
    GetTargetInfo = function() return {IsDummyPC = 0, isSkillObj = 0} end,
    GetCID = function() return "None" end,
    IsPC = function() return 1 end
}
_G.world = {
    IsPVPMap = function() return false end,
    GetActor = function() return nil end
}
_G.FRIEND_LIST_COMPLETE = 0
_G.PARTY_NORMAL = 0
_G.PARTY_GUILD = 1
_G.IS_IN_EVENT_MAP = function() return false end

-- ===== 読み込み =====
_G.__core_g_stub = {
    vlog = function(fmt, ...)
        local ok, line = pcall(string.format, fmt, ...)
        table.insert(world.vlog, ok and line or fmt)
    end,
    FUNCS = {},
    save_json = function() end,
    load_json = function() return nil end,
    register_msg = function() end,
    setup_hook = function() end,
    setup_hook_and_event = function() end
}
local PRELUDE = [[
local addon_name_lower = "_nexus_addons_p"
local g = _G.__core_g_stub
]]

local src_parts = {}
for _, rel in ipairs(mini_addons_parts()) do
    local data = read_file(SRC_DIR .. rel)
    if #src_parts > 0 and src_parts[#src_parts]:sub(-1) ~= "\n" then
        table.insert(src_parts, "\n")
    end
    table.insert(src_parts, data)
end
local chunk = assert(loadstring(PRELUDE .. table.concat(src_parts), "@" .. SRC))
chunk()

local mini = _G.ADDONS.norisan.MINI_ADDONS_P
mini.settings = {ability_sort = 1}
mini.FUNCS = {}

-- ===== 検査の道具 =====
local failed = 0
local function check(label, got, want)
    if got == want then
        print(string.format("  ok  %s = %s", label, tostring(got)))
    else
        failed = failed + 1
        print(string.format("  NG  %s: expected %s, got %s", label, tostring(want), tostring(got)))
    end
end

local function join(list)
    return table.concat(list, ",")
end

-- 行の Y 座標の昇順に名前を並べる（= 画面に出る順）
local function screen_order()
    local names = {}
    for _, name in ipairs(world.ability_rows) do
        names[#names + 1] = name
    end
    table.sort(names, function(a, b) return world.row_pos[a].y < world.row_pos[b].y end)
    return names
end

-- 職業 1 つ分を組む。skills は表示順（{name, x, y}）、abilities は素の並び順
local function setup_job(job, skills, abilities)
    reset_world()
    skill_tree = {}
    for i, sk in ipairs(skills) do
        -- SkillTree の添字は表示順とわざと逆にして、画面の位置から順を取っていることを見る
        skill_tree[job .. "_" .. (#skills - i + 1)] = {SkillName = sk.name, UnlockClassLevel = sk.unlock or 1}
        if sk.x ~= nil then
            world.skills[sk.name] = {x = sk.x, y = sk.y}
        end
    end
    for i, ab in ipairs(abilities) do
        world.ability_rows[i] = ab.name
        world.row_pos[ab.name] = {x = 30, y = (i - 1) * ROW_HEIGHT}
        world.ability_cls[ab.name] = {
            ClassName = ab.name,
            SkillCategory = ab.skills,
            Keyword = ab.default and "DEFAULT_ABIL" or "None",
            ActiveGroup = ab.group or "None"
        }
    end
end

-- ===== 1. 純ロジック: 並びの規則 =====
print("[1] Mini_addons_ability_sort_order")
do
    local rows = {
        {name = "c_default", skills = {}, is_default = true, pos = 1},
        {name = "b2", skills = {"B"}, pos = 2},
        {name = "none1", skills = {}, pos = 3},
        {name = "a1", skills = {"A"}, pos = 4},
        {name = "b1", skills = {"B"}, pos = 5},
        {name = "ab", skills = {"B", "A"}, pos = 6}, -- 一番早いスキル(A)の位置へ
        {name = "none2", skills = {"Unknown"}, pos = 7}, -- 知らないスキルは紐付かない扱い
        {name = "a_default", skills = {"A"}, is_default = true, pos = 8}
    }
    local sorted = _G.Mini_addons_ability_sort_order(rows, {A = 1, B = 2})
    local names = {}
    for i, r in ipairs(sorted) do names[i] = r.name end
    check("並び", join(names), "none1,none2,a1,ab,b2,b1,c_default,a_default")
    check("要素はそのまま", sorted[3], rows[4])
end

print("[2] Mini_addons_ability_sort_split_skills")
do
    check("3 つ", join(_G.Mini_addons_ability_sort_split_skills("A;B;C")), "A,B,C")
    check("None", #_G.Mini_addons_ability_sort_split_skills("None"), 0)
    check("nil", #_G.Mini_addons_ability_sort_split_skills(nil), 0)
    check("空", #_G.Mini_addons_ability_sort_split_skills(""), 0)
end

-- ===== 2. フック: 素の行を並べ直す =====
print("[3] 画面の位置からスキル順を取り、行を並べ直す")
do
    -- スキル欄: Lv1 の段に Slash / Bash、Lv16 の段に Guard
    setup_job("Swordman", {
        {name = "Slash", x = 10, y = 0},
        {name = "Bash", x = 100, y = 0},
        {name = "Guard", x = 10, y = 80, unlock = 16}
    }, {
        {name = "Guard1", skills = "Guard", group = "G"},
        {name = "Default", skills = "None", default = true},
        {name = "Bash1", skills = "Bash"},
        {name = "Common", skills = "None"},
        {name = "Slash1", skills = "Slash"},
        {name = "Guard2", skills = "Guard", group = "G"}
    })
    local origin_called = 0
    mini.FUNCS["SKILLABILITY_FILL_ABILITY_GB"] = function() origin_called = origin_called + 1 end
    _G.Mini_addons_SKILLABILITY_FILL_ABILITY_GB(skillability_job, ability_gb, "Swordman")
    check("素を呼ぶ", origin_called, 1)
    check("画面の並び", join(screen_order()), "Common,Slash1,Bash1,Guard1,Guard2,Default")
    check("X は保つ", world.row_pos.Guard1.x, 30)
    check("行の高さで刻む", world.row_pos.Slash1.y, ROW_HEIGHT)
    check("括弧枠を消す", world.destroyed[1], "active_group_")
    check("括弧枠を描き直す回数", #world.group_calls, 1)
    check("描き直しの並び", join(world.group_calls[1].names), "Common,Slash1,Bash1,Guard1,Guard2,Default")
    check("描き直しの高さ", world.group_calls[1].height, ROW_HEIGHT)
    check("vlog に出所", world.vlog[#world.vlog]:find("画面の位置", 1, true) ~= nil, true)
end

print("[4] スキルの行が見つからなければ解放 Lv → 添字で決める")
do
    setup_job("Swordman", {
        {name = "Slash", unlock = 1}, -- 添字 3
        {name = "Bash", unlock = 1}, -- 添字 2
        {name = "Guard", unlock = 16} -- 添字 1
    }, {
        {name = "Guard1", skills = "Guard"},
        {name = "Slash1", skills = "Slash"},
        {name = "Bash1", skills = "Bash"}
    })
    mini.FUNCS["SKILLABILITY_FILL_ABILITY_GB"] = function() end
    _G.Mini_addons_SKILLABILITY_FILL_ABILITY_GB(skillability_job, ability_gb, "Swordman")
    -- 解放 Lv1 の中は添字順(Bash=2, Slash=3)、Lv16 の Guard が最後
    check("画面の並び", join(screen_order()), "Bash1,Slash1,Guard1")
    check("vlog に出所", world.vlog[#world.vlog]:find("解放Lv/添字", 1, true) ~= nil, true)
end

print("[5] OFF と Common タブは素のまま")
do
    setup_job("Swordman", {{name = "Slash", x = 0, y = 0}}, {
        {name = "Slash1", skills = "Slash"},
        {name = "Common", skills = "None"}
    })
    local origin_called = 0
    mini.FUNCS["SKILLABILITY_FILL_ABILITY_GB"] = function() origin_called = origin_called + 1 end
    mini.settings.ability_sort = 0
    _G.Mini_addons_SKILLABILITY_FILL_ABILITY_GB(skillability_job, ability_gb, "Swordman")
    check("OFF: 素を呼ぶ", origin_called, 1)
    check("OFF: 並びは素のまま", join(screen_order()), "Slash1,Common")
    check("OFF: 括弧枠を触らない", #world.destroyed, 0)
    mini.settings.ability_sort = 1
    _G.Mini_addons_SKILLABILITY_FILL_ABILITY_GB(skillability_job, ability_gb, "Common")
    check("Common: 素を呼ぶ", origin_called, 2)
    check("Common: 並びは素のまま", join(screen_order()), "Slash1,Common")
end

print("[6] 並べ直しに失敗しても素の結果を巻き込まない")
do
    setup_job("Swordman", {{name = "Slash", x = 0, y = 0}}, {{name = "Slash1", skills = "Slash"}})
    local saved = _G.SKILLABILITY_MAKE_GROUP_BY_ACTIVE_GROUP
    _G.SKILLABILITY_MAKE_GROUP_BY_ACTIVE_GROUP = function() error("boom") end
    mini.FUNCS["SKILLABILITY_FILL_ABILITY_GB"] = function() end
    local ok = pcall(_G.Mini_addons_SKILLABILITY_FILL_ABILITY_GB, skillability_job, ability_gb, "Swordman")
    _G.SKILLABILITY_MAKE_GROUP_BY_ACTIVE_GROUP = saved
    check("フックは落ちない", ok, true)
    check("vlog に失敗", world.vlog[#world.vlog]:find("並べ替えに失敗", 1, true) ~= nil, true)
end

if failed > 0 then
    print(string.format("FAILED: %d", failed))
    os.exit(1)
end
print("all ok")
