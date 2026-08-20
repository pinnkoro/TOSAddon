-- Addons Menu へ並べる項目の集め方を luajit 上で検査する（ゲーム不要）。
--
-- ここで見るのは、実機でしか表に出ない割に壊れやすい 3 点。
--   * 並び順が起動ごとに変わらないこと（pairs をそのまま使うと変わる）
--   * 出す / 出さないの既定が出どころで違うこと（相乗り項目は出す、こちらの設定画面は出さない）
--   * アイコンの上書きが _G["norisan"]["MENU"]（相乗り側と共有）を汚さないこと
--
-- 使い方（リポジトリルートから）:
--     luajit docs/tests/test_addons_menu.lua

local PARTS = {"nexus_addons_p/src/core/00_header.lua", "nexus_addons_p/src/core/10_registry.lua",
               "nexus_addons_p/src/core/90_addons_menu.lua"}

-- ===== ゲーム API のスタブ =====
package.preload["json"] = function()
    return {
        encode = function()
            return ""
        end,
        decode = function()
            return {}
        end
    }
end

local real_io_open = io.open
io.open = function(path, mode, ...)
    -- 詳細ログとマーカーは実ファイルを作らせない（../addons/... はリポジトリの外）。
    if type(path) == "string" and (path:find("verbose_log.txt", 1, true) or path:find("mkdir.txt", 1, true)) then
        return nil
    end
    return real_io_open(path, mode, ...)
end
os.execute = function()
    return 0
end

session = {
    GetMapName = function()
        return "town"
    end,
    GetMySession = function()
        return {
            GetCID = function()
                return 1
            end
        }
    end
}
function GetClass()
    return nil
end
function TryGetProp(_, _, default)
    return default
end
ui = {
    GetFrame = function()
        return nil
    end,
    SysMsg = function()
    end,
    SetEscapeScp = function()
    end
}
function AUTO_CAST(x)
    return x
end
option = {
    GetCurrentCountry = function()
        return "Japanese"
    end
}
imcTime = {
    GetAppTimeMS = function()
        return 0
    end
}
table.unpack = table.unpack or unpack

-- ===== 対象を 1 チャンクとして読み込む =====
local chunks = {}
for _, rel in ipairs(PARTS) do
    local f = assert(real_io_open(rel, "rb"), "読めない（リポジトリルートから実行すること）: " .. rel)
    chunks[#chunks + 1] = f:read("*a")
    f:close()
end
assert(load(table.concat(chunks, "\n"), "=core"))()

local g = _G["ADDONS"]["norisan"]["_NEXUS_ADDONS_P"]

local failures = 0
local function check(label, got, want)
    if got ~= want then
        failures = failures + 1
        print(string.format("  NG  %s: got=%s want=%s", label, tostring(got), tostring(want)))
    else
        print(string.format("  ok  %s = %s", label, tostring(got)))
    end
end

-- 設定画面(config_func)を持つ registry のキーを 2 つ拾っておく。
local with_config = {}
for _, entry in ipairs(g._nexus_addons_p) do
    if entry.data.config_func and entry.data.config_func ~= "" then
        with_config[#with_config + 1] = entry.key
    end
end
assert(#with_config >= 2, "設定画面を持つ登録が 2 つ以上あること")
local KEY_A, KEY_B = with_config[1], with_config[2]

local function reset_settings()
    g.settings = {
        menu_shortcuts = {}
    }
    for _, entry in ipairs(g._nexus_addons_p) do
        g.settings[entry.key] = {
            use = 1,
            name = entry.data.name
        }
    end
    _G["norisan"]["MENU"] = {
        lang = "Japanese",
        zzz_other = {
            name = "Other Addon",
            func = "Other_addon_func",
            icon = "sysmenu_coll"
        },
        aaa_other = {
            name = "Another Addon",
            func = "Another_addon_func",
            icon = "sysmenu_jal"
        }
    }
end

local function names_of(items)
    local out = {}
    for _, entry in ipairs(items) do
        out[#out + 1] = entry.shortcut_key or entry.key
    end
    return table.concat(out, ",")
end

print("[1] 相乗り項目は既定で出る / registry の設定画面は既定で出ない")
reset_settings()
local items = g.addons_menu_collect_items()
check("相乗りの 2 件だけ", names_of(items), "menu:aaa_other,menu:zzz_other")

print("[2] ☆を入れた設定画面が並ぶ")
g.settings.menu_shortcuts[g.menu_shortcut_key("addon", KEY_B)] = {
    show = 1
}
g.settings.menu_shortcuts[g.menu_shortcut_key("addon", KEY_A)] = {
    show = 1
}
items = g.addons_menu_collect_items()
check("件数", #items, 4)
-- registry の並び順で出ること（設定へ入れた順ではない）。
local order = {}
for _, entry in ipairs(g._nexus_addons_p) do
    if entry.key == KEY_A or entry.key == KEY_B then
        order[#order + 1] = "addon:" .. entry.key
    end
end
check("相乗り → registry 順", names_of(items),
    "menu:aaa_other,menu:zzz_other," .. table.concat(order, ","))

print("[3] 何度呼んでも並びが変わらない")
local first = names_of(g.addons_menu_collect_items())
local same = true
for _ = 1, 20 do
    if names_of(g.addons_menu_collect_items()) ~= first then
        same = false
    end
end
check("20 回とも同じ並び", same, true)

print("[4] アドオンが OFF なら出さない")
g.settings[KEY_A].use = 0
items = g.addons_menu_collect_items()
check("OFF は落ちる", names_of(items):find("addon:" .. KEY_A, 1, true), nil)
-- 設定画面のショートカットタブ（list_all）には出す。そこで OFF と分かるようにするため。
local all = g.addons_menu_collect_items(nil, true)
local found_disabled = false
for _, entry in ipairs(all) do
    if entry.shortcut_key == "addon:" .. KEY_A then
        found_disabled = (entry.enabled == false and entry.shown == true)
    end
end
check("一覧には OFF として出る", found_disabled, true)
g.settings[KEY_A].use = 1

print("[5] 相乗り項目を「出さない」にできる")
g.settings.menu_shortcuts["menu:zzz_other"] = {
    show = 0
}
check("外れる", names_of(g.addons_menu_collect_items()):find("menu:zzz_other", 1, true), nil)
g.settings.menu_shortcuts["menu:zzz_other"] = nil

print("[6] アイコンの上書きは共有テーブルを汚さない")
g.settings.menu_shortcuts["menu:zzz_other"] = {
    icon = "star_mark"
}
items = g.addons_menu_collect_items()
local overridden
for _, entry in ipairs(items) do
    if entry.shortcut_key == "menu:zzz_other" then
        overridden = entry.data.icon
    end
end
check("表示側は上書きされる", overridden, "star_mark")
check("共有テーブルは元のまま", _G["norisan"]["MENU"].zzz_other.icon, "sysmenu_coll")

print("[7] 絵を持たない相乗り項目は出さない（設定画面には出す）")
reset_settings()
_G["norisan"]["MENU"].noicon = {
    name = "No Icon Addon",
    func = "No_icon_func"
}
check("メニューには出ない", names_of(g.addons_menu_collect_items()):find("menu:noicon", 1, true), nil)
local listed = false
for _, entry in ipairs(g.addons_menu_collect_items(nil, true)) do
    if entry.shortcut_key == "menu:noicon" then
        listed = (entry.drawable == false)
    end
end
check("設定画面には描けない印付きで出る", listed, true)
-- アイコンを選べば出せるようになる（そのための一覧なので、ここまで通って初めて意味がある）。
g.settings.menu_shortcuts["menu:noicon"] = {
    icon = "star_mark"
}
check("アイコンを選ぶと出る", names_of(g.addons_menu_collect_items()):find("menu:noicon", 1, true) ~= nil, true)

print("[8] システムメニュー側は末尾に設定の歯車が付く")
reset_settings()
local sys = g.addons_menu_collect_items("sysmenu")
check("末尾が設定", sys[#sys].key, "addons_menu_setting")
check("右上側には付かない", names_of(g.addons_menu_collect_items()):find("addons_menu_setting", 1, true), nil)
-- ショートカットタブには出さない（出す / 出さないを選べる項目ではない）。
local has_setting = false
for _, entry in ipairs(g.addons_menu_collect_items("sysmenu", true)) do
    if entry.key == "addons_menu_setting" then
        has_setting = true
    end
end
check("設定画面の一覧には出ない", has_setting, false)

print("[9] 置き場所ごとのアイコンの差し替え")
reset_settings()
_G["norisan"]["MENU"].zzz_other.icon_sysmenu = "calendar_button_normal"
local function icon_of(items_, key)
    for _, entry in ipairs(items_) do
        if entry.shortcut_key == key then
            return entry.data.icon
        end
    end
end
check("右上は icon", icon_of(g.addons_menu_collect_items(), "menu:zzz_other"), "sysmenu_coll")
check("システムメニューは icon_sysmenu", icon_of(g.addons_menu_collect_items("sysmenu"), "menu:zzz_other"),
    "calendar_button_normal")
-- 利用者が選んだアイコンは置き場所によらず優先される。
g.settings.menu_shortcuts["menu:zzz_other"] = {
    icon = "star_mark"
}
check("上書きはどちらにも効く", icon_of(g.addons_menu_collect_items("sysmenu"), "menu:zzz_other"), "star_mark")

if failures > 0 then
    print(string.format("FAILED: %d 件", failures))
    os.exit(1)
end
print("ALL OK")
