-- Monster Kill Count の「記録を壊さない」性質を検査する（ゲーム不要）。
--
-- このアドオンは討伐数・滞在時間・取得アイテムをマップごとの .json に貯める。
-- 記録は積み上がる一方で復元手段が無いため、消してしまう変更が入っても
-- 実機では「気付いたときには手遅れ」になる。壊れやすい 2 箇所を機械で見る:
--
--   * Monster_kill_count_load_settings の早期 return（既存の設定ファイルがある経路）
--     … スキーマ補完が無いと map_ids が nil のまま on_init の ipairs で落ち、
--       pcall に飲まれてアドオンが無言で止まる。
--   * Monster_kill_count_information_context（マップ情報のコンテキストメニュー）
--     … 中身のあるファイルを雛形で上書きすると討伐数と滞在時間が消える。
--
-- 使い方（リポジトリルートから）:
--     luajit docs/tests/test_monster_kill_count.lua
--
-- core と同じく、単体では完結しないので 1 チャンクに連結して読む
-- （チャンクローカルの g / addon_name_lower / json を共有させるため）。

local PARTS = {
    "nexus_addons_p/src/core/00_header.lua",
    "nexus_addons_p/src/core/10_registry.lua",
    "nexus_addons_p/src/core/20_lifecycle.lua",
    "nexus_addons_p/src/addons/monster_kill_count.lua",
}

-- ソースの読み込みは io を差し替える前に済ませる（下で io.open を潰すため）。
local chunks = {}
for _, rel in ipairs(PARTS) do
    local f = assert(io.open(rel, "rb"), "読めない（リポジトリルートから実行すること）: " .. rel)
    chunks[#chunks + 1] = f:read("*a")
    f:close()
end

-- ===== ゲーム API のスタブ =====
package.preload["json"] = function()
    return {encode = function() return "" end, decode = function() return {} end}
end

-- 実ファイルには触らせない（パスが ../addons/... でリポジトリの外を指すため）。
io.open = function() return nil end
os.execute = function() return 0 end
os.remove = function() return true end

local MAPS = {[1001] = "map_a", [1002] = "map_b", [1003] = "map_c"}

function GetClassByType(_kind, id)
    local name = MAPS[id]
    if not name then
        return nil
    end
    return {Name = name, ClassName = name}
end

local ctx_items = {}
ui = {
    CreateContextMenu = function(name) return {name = name} end,
    AddContextMenuItem = function(_ctx, text, script)
        ctx_items[#ctx_items + 1] = {text = text, script = script}
    end,
    OpenContextMenu = function() end,
    SysMsg = function() end,
}
session = {
    GetMapName = function() return "map_a" end,
    GetMapID = function() return 1001 end,
    GetMySession = function() return {GetCID = function() return 1 end} end,
}

assert(load(table.concat(chunks, "\n"), "=mkc"))()

local g = _G["ADDONS"]["norisan"]["_NEXUS_ADDONS_P"]
g.active_id = "TESTAID"

-- ===== ファイル入出力のスタブ（アドオンは g.load_json / g.save_json 経由） =====
local files, saved = {}, {}
g.load_json = function(path)
    local v = files[path]
    if not v then
        return nil, "not found"
    end
    -- 呼び出し側が書き換えても元データが汚れないよう複製して返す（実物と同じ挙動）
    local copy = {}
    for k, val in pairs(v) do
        copy[k] = val
    end
    return copy
end
g.save_json = function(path, tbl)
    saved[#saved + 1] = {path = path, tbl = tbl}
    files[path] = tbl
    return true
end

local function map_path(id)
    return string.format("../addons/_nexus_addons_p/TESTAID/monster_kill_count/%s.json", id)
end

-- ===== 検査ヘルパ =====
local failures = 0
local function check(label, got, want)
    if got ~= want then
        failures = failures + 1
        print(string.format("  NG  %s: got=%s want=%s", label, tostring(got), tostring(want)))
    else
        print(string.format("  ok  %s = %s", label, tostring(got)))
    end
end

-- ===== 1. 既存設定を読む経路でスキーマが補完される =====
-- ここは下のスキーマ構築を丸ごと飛ばすので、欠けたキーを補うのはこの経路の責任。
print("[1] load_settings の早期 return がスキーマを補う")
files["../addons/_nexus_addons_p/TESTAID/monster_kill_count.json"] = {frame_x = 100, frame_y = 200}
Monster_kill_count_load_settings()
check("map_ids が table になる", type(g.mkc_settings.map_ids), "table")
check("map_ids は空", #g.mkc_settings.map_ids, 0)
check("frame_x は既存値を保つ", g.mkc_settings.frame_x, 100)
check("frame_y は既存値を保つ", g.mkc_settings.frame_y, 200)

-- 数値でない座標が入っていても、フレーム生成時の比較で落ちないようにする
g.mkc_settings = nil
files["../addons/_nexus_addons_p/TESTAID/monster_kill_count.json"] = {map_ids = {1001}, frame_x = "壊れた値"}
Monster_kill_count_load_settings()
check("壊れた frame_x は既定値へ", g.mkc_settings.frame_x, 1340)
check("欠けた frame_y は既定値へ", g.mkc_settings.frame_y, 20)
check("既存の map_ids は残す", g.mkc_settings.map_ids[1], 1001)

-- ===== 2. マップ情報が既存の記録を壊さない =====
-- 討伐しただけでアイテムを拾わなかったマップは get_items が空になる。
-- 「get_items が空 = 記録なし」と見なして雛形で上書きすると、討伐数と滞在時間が消える。
print("[2] マップ情報は記録を上書きしない")
g.mkc_settings = {frame_x = 1340, frame_y = 20, map_ids = {1001, 1002, 1003}}
files = {}
files[map_path(1001)] = {map_name = "map_a", kill_count = 500, stay_time = 60000, get_items = {}}
files[map_path(1002)] = {map_name = "map_b", kill_count = 0, stay_time = 0, get_items = {["123"] = 3}}
files[map_path(1003)] = {map_name = "map_c", kill_count = 0, stay_time = 0, get_items = {}}
ctx_items, saved = {}, {}
Monster_kill_count_information_context()

check("討伐数だけのマップも一覧に出る", #ctx_items >= 1, true)
local listed = {}
for _, item in ipairs(ctx_items) do
    listed[item.text] = true
end
check("1001(討伐のみ) が出る", listed["1001 map_a"], true)
check("1002(取得のみ) が出る", listed["1002 map_b"], true)
check("1003(記録なし) は出ない", listed["1003 map_c"], nil)
check("既存ファイルを上書きしない", #saved, 0)
check("1001 の討伐数が残る", files[map_path(1001)].kill_count, 500)
check("1001 の滞在時間が残る", files[map_path(1001)].stay_time, 60000)

-- ===== 3. 記録ファイルが無いときだけ雛形を作る =====
print("[3] ファイル不在なら雛形を作る")
g.mkc_settings = {frame_x = 1340, frame_y = 20, map_ids = {1001}}
files, ctx_items, saved = {}, {}, {}
Monster_kill_count_information_context()
check("雛形を1件保存する", #saved, 1)
check("保存先が正しい", saved[1] and saved[1].path, map_path(1001))
check("雛形の討伐数は0", saved[1] and saved[1].tbl.kill_count, 0)
check("記録が無いので一覧には出ない", #ctx_items, 0)

-- ===== 4. get_items が無い旧形式でも落ちず、記録は保つ =====
-- next(nil) で落ちるとコンテキストメニューが一切開かず、設定ボタンが無反応に見える。
print("[4] 旧形式(get_items なし)を壊さずに扱う")
g.mkc_settings = {frame_x = 1340, frame_y = 20, map_ids = {1001}}
files, ctx_items, saved = {}, {}, {}
files[map_path(1001)] = {map_name = "map_a", kill_count = 42, stay_time = 1000}
check("落ちない", (pcall(Monster_kill_count_information_context)), true)
check("討伐数は保たれる", files[map_path(1001)].kill_count, 42)
check("get_items が補われる", type(files[map_path(1001)].get_items), "table")
check("記録があるので一覧に出る", #ctx_items, 1)

-- ===== 5. クラスを引けないマップは一覧に出さない =====
-- GetClassByType が nil を返す状態で .Name を触ると、メニュー全体が開かなくなる。
print("[5] 未知のマップ ID でも落ちない")
g.mkc_settings = {frame_x = 1340, frame_y = 20, map_ids = {9999}}
files, ctx_items, saved = {}, {}, {}
files[map_path(9999)] = {map_name = "?", kill_count = 5, stay_time = 10, get_items = {}}
check("落ちない", (pcall(Monster_kill_count_information_context)), true)
check("一覧には出さない", #ctx_items, 0)

if failures > 0 then
    print(string.format("FAILED: %d 件", failures))
    os.exit(1)
end
print("ALL OK")
