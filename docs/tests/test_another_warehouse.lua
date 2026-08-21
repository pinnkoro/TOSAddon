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

if failures > 0 then
    print(string.format("FAILED: %d 件", failures))
    os.exit(1)
end
print("ALL OK")
