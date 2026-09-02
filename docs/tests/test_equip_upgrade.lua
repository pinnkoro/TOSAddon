-- mini_addons の「装備錬成の自動化」を luajit 上で検査する（ゲーム不要）。
--
-- この自動化は 2 秒おきに自分を呼び直す作りで、**終わり方を間違えると止まらない**。
-- ReserveScript には取り消しが無いので、打ち切り条件が抜けていると素材が尽きた後も
-- UPGRADE_EQUIP を送り続け、窓を閉じるまで止まらない（実機では「なんとなく重い」
-- 「勝手に錬成しようとする」としか見えず、原因に辿り着けない）。
-- 目標到達・素材切れ・窓を閉じた、のどれでも必ず止まることをここで機械的に見る。
--
-- 使い方（リポジトリルートから）:
--     luajit docs/tests/test_equip_upgrade.lua

-- 断片の並びは manifest が正（test_mini_addons_menu.lua と同じ理由でファイル名を直書きしない）。
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

-- 錬成窓のふるまいをここで持つ。rank はサーバ側の状態のつもりで、
-- 「素材が在れば要求 1 回につき 1 上がる」形にする。
local world_state = {
    guid = "GUID_A",
    rank = 0,
    materials = 99,
    visible = 1,
    requests = 0,     -- UPGRADE_EQUIP を投げた回数
    reserved = nil,   -- 最後に予約されたスクリプト
    sysmsgs = {}
}

local slot = {GetUserValue = function() return world_state.guid end}
local frame = {
    GetTopParentFrame = function(self) return self end,
    IsVisible = function() return world_state.visible end
}

_G.ui = {
    GetFrame = function(name)
        if name == "common_equip_upgrade" then
            return frame
        end
        return nil
    end,
    SysMsg = function(msg) table.insert(world_state.sysmsgs, msg) end,
    Chat = function() end,
    CreateContextMenu = function() return {} end,
    AddContextMenuItem = function() end,
    OpenContextMenu = function() end,
    ENTERKEY = "ENTERKEY"
}
_G.GET_CHILD_RECURSIVELY = function(_, name)
    if name == "slot" then
        return slot
    end
    return nil
end
_G.GET_CHILD = function() end
_G.AUTO_CAST = function() end
_G.COMMON_EQUIP_UPGRADE_MAT_NUM_SET = function() end
_G.GetIES = function(obj) return obj end
_G.TryGetProp = function(obj, prop, default)
    if prop == "UpgradeRank" then
        return obj.rank
    end
    return default
end
_G.ReserveScript = function(scp) world_state.reserved = scp end
_G.pc = {
    ReqExecuteTx_Item = function()
        world_state.requests = world_state.requests + 1
        -- 素材が在るあいだだけランクが上がる。尽きたら何も起きない（実機と同じ）。
        if world_state.materials > 0 then
            world_state.materials = world_state.materials - 1
            world_state.rank = world_state.rank + 1
        end
    end
}
_G.session = {
    GetInvItemByGuid = function(guid)
        if guid ~= world_state.guid then
            return nil
        end
        return {GetObject = function() return world_state end}
    end,
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
_G.GetClass = function() return {Name = "skill"} end
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
local vlog_lines = {}
_G.__core_g_stub = {
    vlog = function(fmt, ...)
        local ok, line = pcall(string.format, fmt, ...)
        table.insert(vlog_lines, ok and line or fmt)
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

-- 予約が入っているあいだ、2 秒後の続行を実際に呼ぶ。**上限を置くこと。**
-- 打ち切りが効いていないと、ここが無限ループになってテストが返らなくなる。
local function run_until_stop(limit)
    local rounds = 0
    while world_state.reserved ~= nil do
        rounds = rounds + 1
        if rounds > (limit or 50) then
            return rounds, false
        end
        world_state.reserved = nil
        Mini_addons_COMMON_EQUIP_UPGRADE_PROGRESS_CONTINUE()
    end
    return rounds, true
end

local function reset(opts)
    world_state.guid = opts.guid or "GUID_A"
    world_state.rank = opts.rank or 0
    world_state.materials = opts.materials or 99
    world_state.visible = opts.visible or 1
    world_state.requests = 0
    world_state.reserved = nil
    world_state.sysmsgs = {}
    mini.settings = {status_upgrade = 1, target_status_value = opts.target or 5}
    mini.equip_upgrade_run = nil
end

print("[1] 目標ランクに届いたら止まる")
reset({target = 5})
Mini_addons_COMMON_EQUIP_UPGRADE_PROGRESS(frame, nil, nil, nil)
local rounds, stopped = run_until_stop()
check("止まった", stopped, true)
check("到達したランク", world_state.rank, 5)
check("予約が残っていない", world_state.reserved, nil)
check("走った回数の記録を捨てている", mini.equip_upgrade_run, nil)

print("[2] 素材が尽きたら打ち切る（進まないのに投げ続けない）")
reset({target = 20, materials = 2})
Mini_addons_COMMON_EQUIP_UPGRADE_PROGRESS(frame, nil, nil, nil)
rounds, stopped = run_until_stop()
check("止まった", stopped, true)
check("目標には届いていない", world_state.rank < 20, true)
-- 素材 2 個ぶん進んだ後、ランクが変わらない回を数えて打ち切る。上限は 5 回。
check("要求の回数が抑えられている", world_state.requests <= 8, true)
check("利用者に知らせている", #world_state.sysmsgs > 0, true)
check("ログに残している", vlog_lines[#vlog_lines]:find("進まないので打ち切る") ~= nil, true)

print("[3] 窓を閉じたら続行しない")
reset({target = 20, materials = 99})
Mini_addons_COMMON_EQUIP_UPGRADE_PROGRESS(frame, nil, nil, nil)
check("続行が予約されている", world_state.reserved ~= nil, true)
world_state.visible = 0
world_state.reserved = nil
Mini_addons_COMMON_EQUIP_UPGRADE_PROGRESS_CONTINUE()
check("予約し直していない", world_state.reserved, nil)
check("記録を捨てている", mini.equip_upgrade_run, nil)

print("[4] アイテムを差し替えたら数え直す")
reset({target = 20, materials = 0})
Mini_addons_COMMON_EQUIP_UPGRADE_PROGRESS(frame, nil, nil, nil)
Mini_addons_COMMON_EQUIP_UPGRADE_PROGRESS(frame, nil, nil, nil)
check("同じアイテムでは数が増える", mini.equip_upgrade_run.stall, 2)
world_state.guid = "GUID_B"
Mini_addons_COMMON_EQUIP_UPGRADE_PROGRESS(frame, nil, nil, nil)
check("別のアイテムなら数え直す", mini.equip_upgrade_run.stall, 1)
check("見ているアイテムを持ち替えている", mini.equip_upgrade_run.guid, "GUID_B")

print("[5] 機能が OFF なら素をそのまま呼ぶ")
reset({target = 5})
mini.settings.status_upgrade = 0
local origin_called = 0
mini.FUNCS["COMMON_EQUIP_UPGRADE_PROGRESS"] = function() origin_called = origin_called + 1 end
Mini_addons_COMMON_EQUIP_UPGRADE_PROGRESS(frame, nil, nil, nil)
check("素を呼んだ", origin_called, 1)
check("自分では要求を投げない", world_state.requests, 0)
check("続行を予約しない", world_state.reserved, nil)

if failed > 0 then
    print(string.format("FAILED: %d", failed))
    os.exit(1)
end
print("ALL OK")
