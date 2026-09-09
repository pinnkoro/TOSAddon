-- another_warehouse の設定読み込みを luajit 上で検査する（ゲーム不要）。
--
-- 見るのは **TAKE SET の 10 セットが必ず揃うこと**（Issue #90）。旧アドオンから移行した
-- 利用者は take_list が空のまま ver だけ最新で保存され、右クリックしても空のメニューしか
-- 出ない状態になっていた。セットを足す導線は一覧から開く編集画面しか無いので、
-- **ゲーム内からは復旧できない**。壊れ方が分かりにくいわりに直し方が 1 行なので、
-- 回帰しないようここで押さえる。
--
-- 使い方（リポジトリルートから）:
--     luajit docs/tests/test_another_warehouse.lua

local PARTS = {"nexus_addons_p/src/core/00_header.lua",
               "nexus_addons_p/src/addons/another_warehouse/another_warehouse.lua"}

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
    -- ../addons/** はリポジトリの外なので触らせない。
    if type(path) == "string" and path:find("addons", 1, true) then
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

local chunks = {}
for _, rel in ipairs(PARTS) do
    local f = assert(real_io_open(rel, "rb"), "読めない（リポジトリルートから実行すること）: " .. rel)
    chunks[#chunks + 1] = f:read("*a")
    f:close()
end
assert(load(table.concat(chunks, "\n"), "=core"))()

local g = _G["ADDONS"]["norisan"]["_NEXUS_ADDONS_P"]
g.active_id = "TESTAID"

local failures = 0
local function check(label, got, want)
    if got ~= want then
        failures = failures + 1
        print(string.format("  NG  %s: got=%s want=%s", label, tostring(got), tostring(want)))
    else
        print(string.format("  ok  %s = %s", label, tostring(got)))
    end
end

-- 保存と読み込みはスタブへ差し替える（実ファイルを作らない / 状況を作りやすくする）。
local saved
g.save_lua = function(_, tbl)
    saved = tbl
end
local function run(lua_settings, json_settings, old_settings)
    saved = nil
    g.load_lua = function()
        return lua_settings
    end
    g.load_json = function(path)
        if path:find("settings.json", 1, true) then
            return old_settings
        end
        return json_settings
    end
    Another_warehouse_load_settings()
    return g.awh_settings
end

print("[1] 移行で take_list が空のまま最新バージョンになっていても 10 セット揃う")
-- Issue #90 の状態。旧アドオンの設定に handlelist / setitems が無いと、移行経路が
-- take_list = {} と ver = 1.1 を同時に書くので、従来はここで埋め直しが走らなかった。
local settings = run({
    take_list = {},
    ver = 1.1
})
check("セット数", #settings.take_list, 10)
check("1 つ目の名前", settings.take_list[1].name, "Take Items 1")
check("保存された", saved ~= nil, true)

print("[2] 旧アドオンからの移行（セットが 1 つも無い設定）")
settings = run(nil, nil, {
    items = {}
})
check("セット数", #settings.take_list, 10)

print("[3] 旧アドオンからの移行（セットが 2 つある設定）")
settings = run(nil, nil, {
    handlelist = {"よく使う", "強化素材"},
    setitems = {
        ["1"] = {"item_a"},
        ["2"] = {"item_b"}
    }
})
check("セット数", #settings.take_list, 10)
check("移行した名前は残る", settings.take_list[1].name, "よく使う")
check("移行した中身も残る", settings.take_list[2].items[1], "item_b")
check("足したぶんは既定名", settings.take_list[3].name, "Take Items 3")

print("[4] 既に 10 セットあるなら触らない（保存もしない）")
local ten = {}
for i = 1, 10 do
    ten[i] = {
        name = "セット" .. i,
        items = {}
    }
end
settings = run({
    take_list = ten,
    ver = 1.1
})
check("セット数", #settings.take_list, 10)
check("名前はそのまま", settings.take_list[1].name, "セット1")
check("保存していない", saved, nil)

print("[5] 利用者が 10 個より増やしていたら減らさない")
local twelve = {}
for i = 1, 12 do
    twelve[i] = {
        name = "セット" .. i,
        items = {}
    }
end
settings = run({
    take_list = twelve,
    ver = 1.1
})
check("セット数", #settings.take_list, 12)
check("保存していない", saved, nil)

print("[6] take_list がテーブルでなくても落ちない")
settings = run({
    take_list = false,
    ver = 1.1
})
check("セット数", #settings.take_list, 10)

print("[7] お気に入り（足す / 消す / 並べ替え）")
-- 読み込みでは作らない（何も変えていない設定を毎回保存し直さないため）。
settings = run({
    take_list = twelve,
    ver = 1.1
})
check("読み込みでは作らない", settings.favorites, nil)
check("読み込みでは保存もしない", saved, nil)
-- 使いはじめた時点で入れ物ができる。
check("初めて引いたら空の入れ物", #Another_warehouse_favorites(), 0)
saved = nil
check("足せた", Another_warehouse_favorite_add(101), true)
check("保存した", saved ~= nil, true)
check("1 件になった", #Another_warehouse_favorites(), 1)
check("同じものは足さない", Another_warehouse_favorite_add(101), false)
check("件数は増えない", #Another_warehouse_favorites(), 1)
Another_warehouse_favorite_add(102)
Another_warehouse_favorite_add(103)
check("3 件", #Another_warehouse_favorites(), 3)
check("入っている", Another_warehouse_is_favorite(102), true)
check("入っていない", Another_warehouse_is_favorite(999), false)

print("[8] 並び順そのものが表示順")
local function order()
    local out = {}
    for i, id in ipairs(Another_warehouse_favorites()) do
        out[i] = tostring(id)
    end
    return table.concat(out, ",")
end
check("足した順", order(), "101,102,103")
check("▲で 1 つ前へ", Another_warehouse_favorite_swap(103, -1), true)
check("入れ替わった", order(), "101,103,102")
check("先頭を▲は何もしない", Another_warehouse_favorite_swap(101, -1), false)
check("末尾を▼は何もしない", Another_warehouse_favorite_swap(102, 1), false)
check("並びは変わっていない", order(), "101,103,102")
check("知らないものは動かない", Another_warehouse_favorite_swap(999, -1), false)

print("[9] 外す")
check("外せた", Another_warehouse_favorite_delete(103), true)
check("残りは 2 件", order(), "101,102")
check("入っていないものは外せない", Another_warehouse_favorite_delete(999), false)
check("番号は詰まる（穴が空かない）", Another_warehouse_favorite_index()[102], 2)

print("[10] 文字列で渡されても数として扱う（設定ファイル経由）")
check("文字列で足す", Another_warehouse_favorite_add("104"), true)
check("数として入っている", Another_warehouse_is_favorite(104), true)
check("文字列で外せる", Another_warehouse_favorite_delete("104"), true)

print("[11] お気に入りの窓は、開き直しても位置が動かない")
-- 中身は足す / 消す / 並べ替えのたびに組み直すので、そのつど位置を計算し直すと
-- 行が 1 つ増えるたびに窓が上へ跳ぶ（中央寄せは高さの半分だけ上げるため）。
-- **初めて開いたときの位置を控える**ことで防いでいる。
local dummy
dummy = setmetatable({}, {
    __index = function()
        return function()
            return dummy
        end
    end
})
ui.CreateNewFrame = function()
    return dummy
end
ui.DestroyFrame = function()
end
_G.GET_CHILD_RECURSIVELY = function()
    return nil
end
_G.GET_CHILD = function()
    return nil
end
_G.GetClassByType = function()
    return nil
end
_G.dictionary = {
    ReplaceDicIDInCompStr = function(x)
        return x
    end
}
g.block_click_through = function()
end
g.esc_register_keep = function()
end
-- 呼ばれた高さを控える。**2 回目以降は呼ばれないこと**が要点。
local pos_calls = {}
g.settings_frame_pos = function(w, h)
    table.insert(pos_calls, h)
    return 500, 300
end

settings = run({
    take_list = twelve,
    ver = 1.1
})
Another_warehouse_favorite_add(201)
pos_calls = {}
Another_warehouse_favorite_frame_open()
check("初回は計算する", #pos_calls, 1)
check("控えた x", g.awh_settings.etc.fav_x, 500)
check("控えた y", g.awh_settings.etc.fav_y, 300)
-- 行が増えた状態で開き直す（足すたびにこの関数が呼ばれる）
Another_warehouse_favorite_add(202)
Another_warehouse_favorite_add(203)
pos_calls = {}
Another_warehouse_favorite_frame_open()
check("2 回目以降は計算し直さない", #pos_calls, 0)
check("x は動かない", g.awh_settings.etc.fav_x, 500)
check("y は動かない", g.awh_settings.etc.fav_y, 300)

if failures > 0 then
    print(string.format("FAILED: %d 件", failures))
    os.exit(1)
end
print("ALL OK")
