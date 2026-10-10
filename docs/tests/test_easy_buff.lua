-- easy_buff の装備メンテナンスのプリセットを luajit 上で検査する（ゲーム不要）。
--
-- 2.13.0〜2.15.0 はキャラごとに部位のチェックを持っていた（char_maint_check）。
-- それをメシ屋と同じ「共通のプリセット + キャラごとにどれを自動実行するか」へ移す。
-- 移行を誤ると、**他人の店で黙って違う部位を選んで実行する**（メンテナンスは取り消せない）ので、
-- 実機で店を開く前にここで押さえる。
--   1. 新規（設定ファイルなし）: プリセット 5 つ・中身はすべて選択・自動実行は 1
--   2. 移行: 全部選択 → 1 / 全部外す → 0 / 一部 → 空きプリセットへ。同じ中身は同じプリセットに寄せる
--   3. 空きが尽きたらプリセット 1 に寄せる
--   4. 移行は 1 回だけ（char_maint_check を消す）
--   5. 設定画面の操作（自動実行の選択・部位のチェック・名前）が正しいキーへ書かれる
--
-- 使い方（リポジトリルートから）:
--     luajit docs/tests/test_easy_buff.lua

local SRC = "nexus_addons_p/src/addons/easy_buff/easy_buff.lua"

local function read_file(path)
    local f = assert(io.open(path, "r"), "読めない（リポジトリルートから実行すること）: " .. path)
    local data = f:read("*a")
    f:close()
    return data
end

-- フレームとコントロールのふり。**どのメソッドを呼ばれても自分を返す**ので、
-- 設定ウィンドウを組み立てる処理をそのまま走らせられる（描画は起きない）。
local dummy
dummy = setmetatable({}, {
    __index = function(_, key)
        if key == "GetWidth" or key == "GetHeight" then
            return function()
                return 500
            end
        end
        return function()
            return dummy
        end
    end
})
_G.ui = setmetatable({
    SysMsg = function()
    end
}, {
    __index = function()
        return function()
            return dummy
        end
    end
})
_G.AUTO_CAST = function()
end

local loaded_json
local saved = 0
_G.__core_g_stub = {
    lang = "Japanese",
    cid = "char1",
    active_id = "acc",
    login_name = "tester",
    vlog = function()
    end,
    save_json = function()
        saved = saved + 1
    end,
    load_json = function()
        return loaded_json
    end,
    esc_register_destroy = function()
    end,
    settings_frame_pos = function()
        return 0, 0
    end
}
local PRELUDE = [[
local addon_name_lower = "_nexus_addons_p"
local g = _G.__core_g_stub
]]
local chunk = assert(loadstring(PRELUDE .. read_file(SRC), "@" .. SRC))
chunk()

local g = _G.__core_g_stub

local failed = 0
local function check(label, got, want)
    if got == want then
        print(string.format("  ok  %s = %s", label, tostring(got)))
    else
        failed = failed + 1
        print(string.format("  NG  %s: expected %s, got %s", label, tostring(want), tostring(got)))
    end
end

local function count_on(preset)
    local n = 0
    for _, slot_name in ipairs(g.easy_buff_maint_slots) do
        if g.easy_buff_settings.maint_presets_check[tostring(preset)][slot_name] == 1 then
            n = n + 1
        end
    end
    return n
end

local function only(...)
    local t = {}
    for _, slot_name in ipairs(g.easy_buff_maint_slots) do
        t[slot_name] = 0
    end
    for _, slot_name in ipairs({...}) do
        t[slot_name] = 1
    end
    return t
end

print("[1] 新規")
loaded_json = nil
g.cid = "char1"
Easy_buff_load_settings()
check("プリセットの数", g.easy_buff_maint_preset_count, 5)
for i = 1, 5 do
    check("プリセット " .. i .. " の名前", g.easy_buff_settings.maint_presets_name[tostring(i)], "preset " .. i)
    check("プリセット " .. i .. " はすべて選択", count_on(i), 8)
end
check("自動実行は 1", Easy_buff_maint_preset(), 1)
check("RH を選ぶ", Easy_buff_maint_selected("RH"), 1)
check("char_maint_check は作らない", g.easy_buff_settings.char_maint_check, nil)

print("[2] 移行")
loaded_json = {
    char_maint_check = {
        a_all = {},                           -- 無い部位は 1 = すべて選択
        b_none = only(),                      -- 全部外す = 自動実行しない
        c_weapon = only("RH", "LH"),
        d_armor = only("SHIRT", "PANTS", "GLOVES", "BOOTS"),
        e_weapon = only("RH", "LH")           -- c と同じ中身
    }
}
saved = 0
Easy_buff_load_settings()
local cp = g.easy_buff_settings.char_maint_preset
check("すべて選択 → 1", cp.a_all, 1)
check("全部外す → 0", cp.b_none, 0)
check("武器だけ → 2", cp.c_weapon, 2)
check("防具だけ → 3", cp.d_armor, 3)
check("同じ中身は同じプリセット", cp.e_weapon, 2)
check("プリセット 2 は 2 部位", count_on(2), 2)
check("プリセット 2 の RH", g.easy_buff_settings.maint_presets_check["2"].RH, 1)
check("プリセット 2 の SHIRT", g.easy_buff_settings.maint_presets_check["2"].SHIRT, 0)
check("プリセット 3 は 4 部位", count_on(3), 4)
check("プリセット 4 は手付かず", count_on(4), 8)
check("char_maint_check を消した", g.easy_buff_settings.char_maint_check, nil)
check("保存した", saved, 1)
g.cid = "b_none"
check("全部外したキャラは選ばない", Easy_buff_maint_selected("RH"), 0)
g.cid = "c_weapon"
check("武器だけのキャラは RH を選ぶ", Easy_buff_maint_selected("RH"), 1)
check("武器だけのキャラは BOOTS を選ばない", Easy_buff_maint_selected("BOOTS"), 0)

print("[3] 空きが尽きたら 1 へ")
loaded_json = {
    char_maint_check = {
        c1 = only("RH"),
        c2 = only("LH"),
        c3 = only("RH_SUB"),
        c4 = only("LH_SUB"),
        c5 = only("SHIRT")
    }
}
Easy_buff_load_settings()
cp = g.easy_buff_settings.char_maint_preset
check("c1 → 2", cp.c1, 2)
check("c4 → 5", cp.c4, 5)
check("c5 は空きが無いので 1", cp.c5, 1)

print("[4] 2 回目は何もしない")
local again = g.easy_buff_settings
loaded_json = again
saved = 0
Easy_buff_load_settings()
check("保存しない", saved, 0)
check("c1 はそのまま", g.easy_buff_settings.char_maint_preset.c1, 2)

print("[5] 設定画面の操作")
loaded_json = nil
g.cid = "char1"
Easy_buff_load_settings()
Easy_buff_config_frame()
local function ctrl(name, checked)
    return {
        GetName = function()
            return name
        end,
        IsChecked = function()
            return checked
        end,
        GetText = function()
            return "武器"
        end
    }
end
Easy_buff_config_check_toggle(nil, ctrl("maint_auto_3", 1), "", 3)
check("自動実行を 3 に", g.easy_buff_settings.char_maint_preset.char1, 3)
check("メシ屋の自動実行は触らない", g.easy_buff_settings.char_food_check.char1, nil)
Easy_buff_config_check_toggle(nil, ctrl("maint_auto_3", 0), "", 3)
check("外すと 0", g.easy_buff_settings.char_maint_preset.char1, 0)
Easy_buff_config_check_toggle(nil, ctrl("mcheck_4_RH_SUB", 0), "", 0)
check("プリセット 4 の RH_SUB を外す", g.easy_buff_settings.maint_presets_check["4"].RH_SUB, 0)
check("プリセット 4 の RH は残る", g.easy_buff_settings.maint_presets_check["4"].RH, 1)
Easy_buff_config_check_toggle(nil, ctrl("check_2_5", 0), "", 0)
check("メシ屋の料理チェックは従来どおり", g.easy_buff_settings.food_presets_check["2"]["5"], 0)
Easy_buff_config_presetname_change(nil, ctrl("maint_title_5", 0))
check("メンテの名前", g.easy_buff_settings.maint_presets_name["5"], "武器")
check("メシ屋の名前は触らない", g.easy_buff_settings.food_presets_name["5"], nil)
Easy_buff_config_presetname_change(nil, ctrl("preset_title_2", 0))
check("メシ屋の名前", g.easy_buff_settings.food_presets_name["2"], "武器")

if failed > 0 then
    print(string.format("FAILED: %d 件", failed))
    os.exit(1)
end
print("ALL OK")
