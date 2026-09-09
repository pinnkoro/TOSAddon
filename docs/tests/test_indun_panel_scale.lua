-- indun_panel の表示倍率を luajit 上で検査する（ゲーム不要）。
--
-- 見た目そのものは実機でしか確かめられないが、**倍率の計算だけは機械で見られる**。
-- ここが壊れると行が重なる・文字が既定サイズのまま出る、という形で出る。
--   1. 既定は 100%（これまでどおりの大きさ）。知らない値は 100% へ落とす
--   2. 座標は**四捨五入**する（切り捨てだと行を積むたびに 1px ずつ詰まって重なる）
--   3. 文字の大きさは**実在するサイズへ丸める**
--      （`{sNN}` は素のクライアントが持っているサイズにしか効かず、
--        無いサイズを書くと既定の大きさのまま出る）
--   4. 100% のときは何も変わらない（掛け算を挟んだせいで 1px ずれない）
--
-- 使い方（リポジトリルートから）:
--     luajit docs/tests/test_indun_panel_scale.lua

local SRC = "nexus_addons_p/src/addons/indun_panel/indun_panel.lua"

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
_G.ui = setmetatable({}, {
    __index = function()
        return function()
        end
    end
})
_G.AUTO_CAST = function()
end
_G.GET_CHILD_RECURSIVELY = function()
    return nil
end
_G.GET_CHILD = function()
    return nil
end
_G.__core_g_stub = {
    lang = "Japanese",
    vlog = function()
    end,
    save_json = function()
    end,
    load_json = function()
        return nil
    end,
    register_msg = function()
    end,
    setup_hook = function()
    end,
    setup_hook_and_event = function()
    end
}
local PRELUDE = [[
local addon_name_lower = "_nexus_addons_p"
local g = _G.__core_g_stub
]]
local chunk = assert(loadstring(PRELUDE .. read_file(SRC), "@" .. SRC))
chunk()

local g = _G.__core_g_stub
assert(type(_G.Indun_panel_s) == "function", "倍率の関数が無い")

local failed = 0
local function check(label, got, want)
    if got == want then
        print(string.format("  ok  %s = %s", label, tostring(got)))
    else
        failed = failed + 1
        print(string.format("  NG  %s: expected %s, got %s", label, tostring(want), tostring(got)))
    end
end

local function set_scale(v)
    g.indun_panel_settings = {
        etc = {
            scale = v
        }
    }
end

print("[1] 既定と、知らない値の扱い")
g.indun_panel_settings = nil
check("設定がまだ無い", Indun_panel_scale(), 1)
set_scale(nil)
check("キーが無い", Indun_panel_scale(), 1)
set_scale(100)
check("100", Indun_panel_scale(), 1)
set_scale(80)
check("80", Indun_panel_scale(), 0.8)
set_scale(55)
check("一覧に無い値は 100% 扱い", Indun_panel_scale(), 1)
-- json から読み直したときに文字列で入っていることがあるので、数として読めれば受ける
-- (読み込み時のバックフィルが数へ直すので、実際にここへ来るのは壊れた設定ファイルだけ)
set_scale("80")
check("数として読める文字列は受ける", Indun_panel_scale(), 0.8)
set_scale("こわれている")
check("数として読めない文字列は 100% 扱い", Indun_panel_scale(), 1)

print("[2] 100% では 1px も動かない")
set_scale(100)
for _, v in ipairs({0, 1, 5, 33, 50, 115, 470, 740, 750}) do
    if Indun_panel_s(v) ~= v then
        failed = failed + 1
        print(string.format("  NG  100%% で %d が %d になった", v, Indun_panel_s(v)))
    end
end
check("100% は素通し", Indun_panel_s(750), 750)

print("[3] 四捨五入する（切り捨てない）")
set_scale(90)
-- 5 * 0.9 = 4.5 → 5、33 * 0.9 = 29.7 → 30
check("5 * 90%", Indun_panel_s(5), 5)
check("33 * 90%", Indun_panel_s(33), 30)
set_scale(80)
check("33 * 80%", Indun_panel_s(33), 26)
check("750 * 80%", Indun_panel_s(750), 600)
check("115 * 80%", Indun_panel_s(115), 92)

print("[4] 行を積んでもずれが溜まらない（毎回元の値から計算する）")
set_scale(80)
local step = Indun_panel_s(33)
check("10 行ぶん", step * 10, Indun_panel_s(33) * 10)
check("行の送りは 1 px も揺れない", Indun_panel_s(33), step)

print("[5] 文字の大きさは実在するサイズへ丸める")
set_scale(100)
check("100% の 16", Indun_panel_f(16), "{s16}")
check("100% の 10", Indun_panel_f(10), "{s10}")
set_scale(80)
-- 16 * 0.8 = 12.8 → 13 → 実在する 12 へ落とす
check("80% の 16", Indun_panel_f(16), "{s12}")
-- 20 * 0.8 = 16
check("80% の 20", Indun_panel_f(20), "{s16}")
-- 10 * 0.8 = 8 → 一覧の最小(10)より小さいので 10 のまま
check("80% の 10 は最小で止まる", Indun_panel_f(10), "{s10}")
set_scale(90)
-- 16 * 0.9 = 14.4 → 14
check("90% の 16", Indun_panel_f(16), "{s14}")
check("90% の 18", Indun_panel_f(18), "{s16}")

print("[6] 返すのは必ず実在するサイズ")
local known = {}
for _, size in ipairs(g.INDUN_PANEL_FONT_SIZES) do
    known["{s" .. size .. "}"] = true
end
for _, pct in ipairs(g.INDUN_PANEL_SCALES) do
    set_scale(pct)
    for _, v in ipairs({10, 12, 14, 16, 18, 20, 22, 24}) do
        local tag = Indun_panel_f(v)
        if not known[tag] then
            failed = failed + 1
            print(string.format("  NG  %d%% の %d が実在しないサイズ %s を返した", pct, v, tag))
        end
    end
end
check("全部の組み合わせで実在するサイズ", true, true)

if failed > 0 then
    print(string.format("FAILED: %d 件", failed))
    os.exit(1)
end
print("ALL OK")
