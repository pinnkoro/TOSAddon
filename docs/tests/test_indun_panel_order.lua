-- indun_panel の並べ替え（設定ウィンドウの▲▼）を luajit 上で検査する（ゲーム不要）。
--
-- 見るのは次の 4 つ。どれも実機では「押しても動かない」「知らない行が真ん中に割り込む」
-- という形でしか出ず、目視では気付きにくい。
--   1. 番号(order)を持たないキーは末尾へ回る（新しいダンジョン / ショートカットを足したとき、
--      既に並べ替えている利用者の並びの真ん中へ割り込まないこと）
--   2. ▲▼ は一覧全体へ 1 から番号を振り直す（隣と入れ替えるだけにしない）
--   3. 番号が同じ・欠けていても、元の定義順が最後の決め手になる
--      （table.sort は安定ではないので、これが無いと起動ごとに並びが変わる）
--   4. 「ON のものだけ表示」で絞っている間の▲▼は、隠れている行を飛ばして
--      見えている次の行と入れ替える（隠れた行と入れ替えると画面上は何も動かない）
--
-- 使い方（リポジトリルートから）:
--     luajit docs/tests/test_indun_panel_order.lua

local SRC = "nexus_addons_p/src/addons/indun_panel/indun_panel.lua"

local function read_file(path)
    local f = assert(io.open(path, "r"), "読めない（リポジトリルートから実行すること）: " .. path)
    local data = f:read("*a")
    f:close()
    return data
end

-- ===== ゲーム API のスタブ =====
-- 読み込むだけなら実際に呼ばれるのはテーブルの定義だけだが、
-- 素の関数を参照している行があるので最低限だけ置いておく。
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

local vlog_lines = {}
_G.__core_g_stub = {
    lang = "Japanese",
    vlog = function(fmt, ...)
        local ok, line = pcall(string.format, fmt, ...)
        table.insert(vlog_lines, ok and line or fmt)
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
assert(type(g.indun_panel_ordered_shortcuts) == "function", "並べ替えの関数が g へ載っていない")

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

local function keys_of(list)
    local names = {}
    for i, item in ipairs(list) do
        names[i] = item.key
    end
    return table.concat(names, ",")
end

local function reset_settings()
    g.indun_panel_settings = {
        col_order = {},
        row_order = {}
    }
end

-- 定義順（まだ誰も並べ替えていないときの並び）
reset_settings()
local DEFAULT_SHORTCUTS = keys_of(g.indun_panel_ordered_shortcuts())
local DEFAULT_ROWS = keys_of(g.indun_panel_ordered_induns())

print("[1] 既定は定義順のまま")
check("ショートカットの先頭", DEFAULT_SHORTCUTS:match("^[^,]+"), "tos")
check("ショートカットの末尾", DEFAULT_SHORTCUTS:match("[^,]+$"), "leticia")
check("ショートカットの数", #g.indun_panel_ordered_shortcuts(), #g.indun_panel_shortcut_defs)
check("コンテンツの先頭", DEFAULT_ROWS:match("^[^,]+"), "challenge")

print("[2] ▲ で 1 つ前へ動き、全体へ 1 から番号が振り直される")
reset_settings()
local moved = g.indun_panel_move_in_order(g.indun_panel_ordered_shortcuts(), "col_order", "leticia", -1)
check("動かせた", moved, true)
local after = g.indun_panel_ordered_shortcuts()
check("末尾の 1 つ前へ来た", keys_of(after):match("([^,]+,[^,]+)$"), "leticia,craft")
check("番号は 1 から連番", g.indun_panel_settings.col_order.tos, 1)
check("最後の番号 = 件数", g.indun_panel_settings.col_order.craft, #after)
check("番号を持たないキーが残っていない", (function()
    for _, def in ipairs(g.indun_panel_shortcut_defs) do
        if g.indun_panel_settings.col_order[def.key] == nil then
            return def.key
        end
    end
    return "none"
end)(), "none")

print("[3] 端では何もしない")
reset_settings()
check("先頭を▲", g.indun_panel_move_in_order(g.indun_panel_ordered_shortcuts(), "col_order", "tos", -1), false)
check("末尾を▼", g.indun_panel_move_in_order(g.indun_panel_ordered_shortcuts(), "col_order", "leticia", 1), false)
check("知らないキー", g.indun_panel_move_in_order(g.indun_panel_ordered_shortcuts(), "col_order", "unknown", -1),
    false)
check("並びは変わっていない", keys_of(g.indun_panel_ordered_shortcuts()), DEFAULT_SHORTCUTS)

print("[4] 番号を持たないキーは末尾へ回る（後から足したものが割り込まない）")
reset_settings()
-- 「利用者が leticia と craft だけを先頭へ並べ替えた後、新しい女神が足された」状態を作る。
g.indun_panel_settings.col_order = {
    leticia = 1,
    craft = 2
}
local mixed = keys_of(g.indun_panel_ordered_shortcuts())
check("並べ替えた 2 つが先頭", mixed:match("^([^,]+,[^,]+)"), "leticia,craft")
check("残りは定義順のまま末尾へ", mixed:match("^[^,]+,[^,]+,(.*)$"),
    (DEFAULT_SHORTCUTS:gsub(",craft,leticia$", ""):gsub("^", "")))

print("[5] 番号が重複していても定義順が最後の決め手（起動ごとに並びが変わらない）")
reset_settings()
for _, def in ipairs(g.indun_panel_shortcut_defs) do
    g.indun_panel_settings.col_order[def.key] = 1
end
local first = keys_of(g.indun_panel_ordered_shortcuts())
check("全部同じ番号なら定義順", first, DEFAULT_SHORTCUTS)
check("何度呼んでも同じ", keys_of(g.indun_panel_ordered_shortcuts()), first)

print("[6] コンテンツの行も同じ規則で動く")
reset_settings()
check("末尾を▲", g.indun_panel_move_in_order(g.indun_panel_ordered_induns(), "row_order", "jsr", -1), true)
local rows = keys_of(g.indun_panel_ordered_induns())
check("jsr が 1 つ前へ", rows:match("([^,]+,[^,]+)$"), "jsr,zawra")
check("row_order は連番", g.indun_panel_settings.row_order.challenge, 1)
-- ショートカット側の控えを巻き込んでいないこと（控えは別のキーで持つ）
check("col_order は触っていない", next(g.indun_panel_settings.col_order), nil)

print("[7] 元の定義テーブルを並べ替えていない")
reset_settings()
g.indun_panel_settings.col_order = {
    leticia = 1
}
g.indun_panel_ordered_shortcuts()
check("定義の先頭は tos のまま", g.indun_panel_shortcut_defs[1].key, "tos")

print("[8] 絞り込み中の▲▼は、隠れている行を飛ばして見えている次の行と入れ替える")
reset_settings()
-- 「ON のものだけ表示」で tos / market / leticia だけが見えている状態
local shown = {
    tos = true,
    market = true,
    leticia = true
}
local function only_shown(item)
    return shown[item.key] == true
end
check("leticia を▲", g.indun_panel_move_in_order(g.indun_panel_ordered_shortcuts(), "col_order", "leticia", -1,
    only_shown), true)
local skipped = keys_of(g.indun_panel_ordered_shortcuts())
-- craft(隠れている)は飛ばして market と入れ替わる。craft はその場に留まる
check("market と入れ替わった", skipped:match("([^,]+,[^,]+,[^,]+)$"), "leticia,craft,market")
check("先頭は動いていない", skipped:match("^[^,]+"), "tos")
reset_settings()
check("見えている行が先に無ければ動かさない",
    g.indun_panel_move_in_order(g.indun_panel_ordered_shortcuts(), "col_order", "tos", -1, only_shown), false)
reset_settings()
check("見えている行が後ろに無ければ動かさない",
    g.indun_panel_move_in_order(g.indun_panel_ordered_shortcuts(), "col_order", "leticia", 1, only_shown), false)

if failed > 0 then
    print(string.format("FAILED: %d 件", failed))
    os.exit(1)
end
print("all ok")
