-- mini_addons のコンテキストメニュー横取り（Issue #53）を luajit 上で検査する（ゲーム不要）。
--
-- 「素を呼び、その最中の ui.AddContextMenuItem / ui.OpenContextMenu を一時的に横取りして
-- 項目を足す」作りは、失敗の仕方が怖い:
--   * 横取りを戻し忘れると、**ゲーム中の全ての右クリックメニュー**を巻き込む
--   * 素の戻り値を返し忘れると、PC 選択からのメニューが位置合わせできなくなる
--   * 自分が足した項目まで差し替え対象(drop)に食われると、項目が消える
-- どれも実機でしか気付けないので、ここで機械的に見る。
--
-- 使い方（リポジトリルートから）:
--     luajit docs/tests/test_mini_addons_menu.lua

local SRC = "nexus_addons_p/src/addons/mini_addons/mini_addons.lua"

-- ===== ゲーム API のスタブ =====
package.preload["json"] = function()
    return {encode = function() return "" end, decode = function() return {} end}
end

local menu = {} -- 今組み立て中のメニュー（{caption, scp} の並び）
local opened = nil -- 最後に ui.OpenContextMenu へ渡された context

local real_ui = {}
real_ui.CreateContextMenu = function(name)
    menu = {}
    return {name = name}
end
real_ui.AddContextMenuItem = function(context, caption, scp)
    table.insert(menu, {caption = caption, scp = scp, context = context})
end
real_ui.OpenContextMenu = function(context)
    opened = context
    return "opened"
end

_G.ui = {
    CreateContextMenu = real_ui.CreateContextMenu,
    AddContextMenuItem = real_ui.AddContextMenuItem,
    OpenContextMenu = real_ui.OpenContextMenu,
    Chat = function() end
}

-- 表示名の引き方は素の関数ごとに違う（ScpArgMsg / ClMsg）。どちらも素通しで返す。
_G.ScpArgMsg = function(key) return key end
_G.ClMsg = function(key) return key end
_G.GetClass = function() return {Name = "skill"} end
_G.GetClassByType = function() return {} end
_G.AUTO_CAST = function() end
_G.GET_CHILD = function() end
_G.GET_CHILD_RECURSIVELY = function() end
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
    GetActor = function()
        return {
            IsMyPC = function() return 0 end,
            GetHandleVal = function() return 1 end,
            GetPCApc = function()
                return {GetFamilyName = function() return "target_pc" end, GetAID = function() return "1" end}
            end
        }
    end
}
_G.session = {
    loginInfo = {GetAID = function() return "me_aid" end, GetChannel = function() return 1 end},
    world = {
        IsIntegrateServer = function() return false end,
        IsIntegrateIndunServer = function() return false end,
        IsDungeon = function() return false end
    },
    party = {
        GetPartyMemberInfoByAID = function()
            return {
                GetName = function() return "member" end,
                GetHandle = function() return 42 end,
                GetAID = function() return "aid" end
            }
        end,
        GetPartyInfo = function() return {info = {GetLeaderAID = function() return "me_aid" end}} end,
        GetAllMemberCount = function() return 2 end
    },
    friends = {
        GetFriendByAID = function()
            return {GetInfo = function() return {GetFamilyName = function() return "friend_pc" end} end}
        end
    },
    colonywar = {GetIsColonyWarMap = function() return false end},
    IsGM = function() return 0 end
}
_G.FRIEND_LIST_COMPLETE = 0
_G.PARTY_NORMAL = 0
_G.PARTY_GUILD = 1
_G.IS_IN_EVENT_MAP = function() return false end

-- ===== 読み込み =====
-- mini_addons.lua は bundle の途中に置かれる断片で、チャンクローカルの
-- g / addon_name_lower を外から受け取る。テストでも同じ形に組み立てて読む。
local vlog_lines = {}
local PRELUDE = [[
local addon_name_lower = "_nexus_addons_p"
local g = _G.__core_g_stub
]]

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

local f = assert(io.open(SRC, "r"), "読めない（リポジトリルートから実行すること）: " .. SRC)
local src = f:read("*a")
f:close()
local chunk = assert(loadstring(PRELUDE .. src, "@" .. SRC))
chunk()

local mini = _G.ADDONS.norisan.MINI_ADDONS_P
mini.settings = {memberinfo = 0}
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

local function captions()
    local out = {}
    for _, item in ipairs(menu) do
        table.insert(out, item.caption)
    end
    return table.concat(out, ",")
end

local function ui_is_clean()
    return ui.AddContextMenuItem == real_ui.AddContextMenuItem and ui.OpenContextMenu == real_ui.OpenContextMenu
end

-- 素のふるまいを真似た関数。最後が「キャンセル」なのは素のメニュー全部に共通。
local function fake_origin(...)
    local context = ui.CreateContextMenu("CONTEXT", "")
    ui.AddContextMenuItem(context, "WHISPER", "whisper")
    ui.AddContextMenuItem(context, "ShowInfomation", "OPEN_PARTY_MEMBER_INFO(42)")
    ui.AddContextMenuItem(context, "Cancel", "None")
    ui.OpenContextMenu(context)
    return context
end

print("[1] OFF: 素の項目はそのまま、追加項目は出さない")
mini.settings.memberinfo = 0
mini.FUNCS["CONTEXT_PARTY"] = fake_origin
Mini_addons_CONTEXT_PARTY({}, {}, "aid")
-- 決闘の項目は memberinfo と無関係に足す（従来どおり）。キャンセルの手前へ入る。
check("項目の並び", captions(), "WHISPER,ShowInfomation,----,RequestFriendlyFight,Cancel")
check("横取りを戻している", ui_is_clean(), true)

print("[2] ON: 素の「詳細情報を見る」を /memberinfo へ差し替える")
mini.settings.memberinfo = 1
Mini_addons_CONTEXT_PARTY({}, {}, "aid")
check("項目の並び", captions(), "WHISPER,----,RequestFriendlyFight,-----,ShowInfomation,Cancel")
-- 自分が足した ShowInfomation まで drop に食われていないこと（素の add を通す作り）。
check("差し替えた項目が残っている", menu[5].scp, "ui.Chat('/memberinfo member')")
check("横取りを戻している", ui_is_clean(), true)

print("[3] 素が失敗しても横取りを戻す")
mini.FUNCS["CONTEXT_PARTY"] = function()
    error("boom")
end
Mini_addons_CONTEXT_PARTY({}, {}, "aid")
check("横取りを戻している", ui_is_clean(), true)
check("失敗をログに残す", vlog_lines[#vlog_lines]:find("CONTEXT_PARTY") ~= nil, true)

print("[4] 素の戻り値を返す（_SHOW_PC_CONTEXT_MENU が位置合わせに使う）")
mini.settings.memberinfo = 0
mini.FUNCS["SHOW_PC_CONTEXT_MENU"] = fake_origin
local ret = Mini_addons_SHOW_PC_CONTEXT_MENU(1)
check("context を返す", type(ret) == "table" and ret.name, "CONTEXT")
check("追加は出ない(OFF)", captions(), "WHISPER,ShowInfomation,Cancel")

print("[5] ON: 「見比べる」を落として /memberinfo を足す")
mini.settings.memberinfo = 1
mini.FUNCS["SHOW_PC_CONTEXT_MENU"] = function()
    local context = ui.CreateContextMenu("PC_CONTEXT_MENU", "")
    ui.AddContextMenuItem(context, "{img context_look_into 18 17} Auto_SalPyeoBoKi", "PROPERTY_COMPARE(1)")
    ui.AddContextMenuItem(context, "{img context_cancel 18 17} Cancel", "None")
    ui.OpenContextMenu(context)
    return context
end
Mini_addons_SHOW_PC_CONTEXT_MENU(1)
check("項目の並び", captions(), "-----,ShowInfomation,{img context_cancel 18 17} Cancel")
check("相手の名前を渡している", menu[2].scp, "ui.Chat('/memberinfo target_pc')")

print("[6] 露店キャラ・自分自身は素へそのまま回す")
local dummy_called = 0
_G.info.GetTargetInfo = function() return {IsDummyPC = 1, isSkillObj = 0} end
mini.FUNCS["SHOW_PC_CONTEXT_MENU"] = function()
    dummy_called = dummy_called + 1
    local context = ui.CreateContextMenu("DPC_CONTEXT", "")
    ui.AddContextMenuItem(context, "Auto_SalPyeoBoKi", "PROPERTY_COMPARE(1)")
    ui.OpenContextMenu(context)
    return context
end
Mini_addons_SHOW_PC_CONTEXT_MENU(1)
check("素を呼んでいる", dummy_called, 1)
check("露店には足さない", captions(), "Auto_SalPyeoBoKi")
check("横取りしていない", ui_is_clean(), true)
_G.info.GetTargetInfo = function() return {IsDummyPC = 0, isSkillObj = 0} end

print("[7] キャンセルが無いメニューでも、開く直前に足せる")
mini.FUNCS["CHAT_RBTN_POPUP"] = function()
    local context = ui.CreateContextMenu("CONTEXT_CHAT_RBTN", "")
    ui.AddContextMenuItem(context, "WHISPER", "whisper")
    ui.OpenContextMenu(context)
    return context
end
Mini_addons_CHAT_RBTN_POPUP({}, {GetUserValue = function() return "chat_pc" end})
check("項目の並び", captions(), "WHISPER,-----,ShowInfomation")
check("横取りを戻している", ui_is_clean(), true)

print("[8] 素の控えが無いときは何もしない（落ちない）")
mini.FUNCS["POPUP_GUILD_MEMBER"] = nil
menu = {}
Mini_addons_POPUP_GUILD_MEMBER({GetUserValue = function() return "aid" end}, {})
check("項目を作らない", #menu, 0)
check("横取りしていない", ui_is_clean(), true)

print("[9] ui.* を差し替えられないクライアントでは素をそのまま呼ぶ")
-- ui を書き換え不可にする（rawset を拒む __newindex）。判定結果は 1 回だけ出す。
local plain_ui = _G.ui
_G.ui = setmetatable({}, {
    __index = plain_ui,
    __newindex = function()
    end
})
local reprobe = loadstring([[
local addon_name_lower = "_nexus_addons_p"
local g = _G.__core_g_stub
]] .. src, "@" .. SRC)
reprobe()
local mini2 = _G.ADDONS.norisan.MINI_ADDONS_P
mini2.settings = {memberinfo = 1}
mini2.FUNCS = {CHAT_RBTN_POPUP = fake_origin}
menu = {}
Mini_addons_CHAT_RBTN_POPUP({}, {GetUserValue = function() return "chat_pc" end})
check("素のメニューは壊れない", captions(), "WHISPER,ShowInfomation,Cancel")
check("差し替え不可を記録する", vlog_lines[#vlog_lines]:find("差し替え可否 = false") ~= nil, true)
_G.ui = plain_ui

if failed > 0 then
    print(string.format("FAILED: %d", failed))
    os.exit(1)
end
print("ALL OK")
