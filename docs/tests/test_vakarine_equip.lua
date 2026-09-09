-- vakarine_equip の設定まわりを luajit 上で検査する（ゲーム不要）。
--
-- 見た目は実機でしか確かめられないが、**設定の読み書きだけは機械で見られる**。
-- ここが壊れると「チェックが毎回消える」「全選択が一部の部位を取りこぼす」という形で
-- 出て、実際に着脱を回すまで気付けない。
--   1. 全選択 / 全解除が **13 部位すべて**に効く（対で持つ RH_SUB / LH_SUB も含む）
--   2. 「今の状態で意味が切り替わる」（1 つでも外れていれば全選択、全部 ON なら全解除）
--   3. 設定ウィンドウの位置は、控えがあればそれを使い、無ければ計算に落とす
--   4. 作動するマップ種別は**キー単位で既定を補う**（項目を後から足すため）
--
-- 使い方（リポジトリルートから）:
--     luajit docs/tests/test_vakarine_equip.lua

local SRC = "nexus_addons_p/src/addons/vakarine_equip/vakarine_equip.lua"

local function read_file(path)
    local f = assert(io.open(path, "r"), "読めない（リポジトリルートから実行すること）: " .. path)
    local data = f:read("*a")
    f:close()
    return data
end

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
-- フレームとコントロールのふり。**どのメソッドを呼ばれても自分を返す**ので、
-- 設定ウィンドウを組み立てる処理をそのまま走らせられる（描画は起きない）。
local dummy
dummy = setmetatable({}, {
    __index = function()
        return function()
            return dummy
        end
    end
})
_G.ui = setmetatable({}, {
    __index = function()
        return function()
            return dummy
        end
    end
})
_G.AUTO_CAST = function()
end
_G.GET_CHILD_RECURSIVELY = function()
    return dummy
end
_G.GET_CHILD = function()
    return dummy
end
_G.ClMsg = function(k)
    return k
end
_G.ReserveScript = function()
end

local saved = 0
_G.__core_g_stub = {
    lang = "Japanese",
    cid = "char1",
    vlog = function()
    end,
    save_json = function()
        saved = saved + 1
    end,
    load_json = function()
        return nil
    end,
    register_msg = function()
    end,
    setup_hook = function()
    end,
    setup_hook_and_event = function()
    end,
    block_click_through = function()
    end,
    esc_register_keep = function()
    end,
    settings_frame_pos = function()
        return 111, 222
    end
}
local PRELUDE = [[
local addon_name_lower = "_nexus_addons_p"
local g = _G.__core_g_stub
]]
local chunk = assert(loadstring(PRELUDE .. read_file(SRC), "@" .. SRC))
chunk()

local g = _G.__core_g_stub
assert(type(_G.Vakarine_equip_spots_toggle_all) == "function", "全選択の関数が無い")

local failed = 0
local function check(label, got, want)
    if got == want then
        print(string.format("  ok  %s = %s", label, tostring(got)))
    else
        failed = failed + 1
        print(string.format("  NG  %s: expected %s, got %s", label, tostring(want), tostring(got)))
    end
end

local function reset(spot_value)
    local chars = {
        char1 = {}
    }
    for _, spot in ipairs(g.vakarine_equip_spots) do
        chars.char1[spot.name] = spot_value
    end
    g.vakarine_equip_settings = {
        chars = chars,
        maps = {},
        move = 0,
        open_inventory = 1
    }
end

local function count_on()
    local n = 0
    for _, spot in ipairs(g.vakarine_equip_spots) do
        if g.vakarine_equip_settings.chars.char1[spot.name] == 1 then
            n = n + 1
        end
    end
    return n
end

print("[1] 部位の表そのもの")
check("部位の数", #g.vakarine_equip_spots, 13)
check("RH_SUB がある", (function()
    for _, s in ipairs(g.vakarine_equip_spots) do
        if s.name == "RH_SUB" then
            return true
        end
    end
    return false
end)(), true)

print("[2] 全選択 / 全解除は全部の部位に効く")
reset(0)
check("最初は 0 個", count_on(), 0)
check("1 つでも外れていれば「全部 ON」", Vakarine_equip_spots_all_checked(), false)
Vakarine_equip_spots_toggle_all()
check("全部 ON になった", count_on(), #g.vakarine_equip_spots)
check("今度は「全部 OFF」に変わる", Vakarine_equip_spots_all_checked(), true)
Vakarine_equip_spots_toggle_all()
check("全部 OFF になった", count_on(), 0)

print("[3] 1 つだけ ON でも「全部 ON」と見なさない")
reset(0)
g.vakarine_equip_settings.chars.char1[g.vakarine_equip_spots[1].name] = 1
check("まだ全部 ON ではない", Vakarine_equip_spots_all_checked(), false)
Vakarine_equip_spots_toggle_all()
check("押すと全部 ON", count_on(), #g.vakarine_equip_spots)

print("[4] キーが欠けていても落ちない（部位を後から足したとき）")
reset(1)
g.vakarine_equip_settings.chars.char1[g.vakarine_equip_spots[3].name] = nil
check("欠けは ON 扱いしない", Vakarine_equip_spots_all_checked(), false)
Vakarine_equip_spots_toggle_all()
check("押せば全部埋まる", count_on(), #g.vakarine_equip_spots)

print("[5] 設定ウィンドウの位置を控える")
reset(0)
local frame = {
    GetX = function()
        return 300
    end,
    GetY = function()
        return 400
    end
}
saved = 0
Vakarine_equip_config_drag(frame)
check("控えた x", g.vakarine_equip_settings.config_x, 300)
check("控えた y", g.vakarine_equip_settings.config_y, 400)
check("保存した", saved, 1)
saved = 0
Vakarine_equip_config_drag(frame)
check("動いていなければ保存しない", saved, 0)

print("[6] 作動するマップ種別の既定")
local kinds = {}
for _, k in ipairs(g.vakarine_equip_map_kinds) do
    kinds[k.key] = k.default
end
check("JSR は既定 ON", kinds.jsr, 1)
check("インスタンスは既定 ON", kinds.instance, 1)
check("フィールドは既定 OFF", kinds.field, 0)
check("分裂は既定 OFF", kinds.split, 0)

if failed > 0 then
    print(string.format("FAILED: %d 件", failed))
    os.exit(1)
end
print("ALL OK")
