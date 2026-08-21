-- market_voucher の記録の置き場所を luajit 上で検査する（ゲーム不要）。
--
-- 見るのは Issue #101 で直した性質。**どれも実機では「なんとなく重い」としか出ない**ので、
-- 機械で押さえておかないと簡単に戻る。
--   * ログイン（on_init）で記録を読み書きしないこと
--   * アドオンが OFF ならフックを張らないこと（張ってしまうと素の処理を肩代わりする）
--   * 記録は txt へ追記するだけで、json へは書かないこと
--   * 旧い置き場所からの移行は txt が空のときに 1 回だけ行うこと
--   * Clear Log は .bak へ退避してから消し、退避できなければ消さないこと
--
-- 使い方（リポジトリルートから）:
--     luajit docs/tests/test_market_voucher.lua

local PARTS = {"nexus_addons_p/src/core/00_header.lua",
               "nexus_addons_p/src/addons/market_voucher/market_voucher.lua"}

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

-- ===== ファイルを記憶上に持つ =====
-- 実ファイルを触らせない（../addons/** はリポジトリの外）ためと、
-- 「何回開いたか」を数えるため。
local fs = {}
local opens = {}
local real_io_open = io.open

local function fake_file(path, mode)
    local buf = fs[path]
    if mode == "r" then
        if buf == nil then
            return nil
        end
        local pos = 1
        local handle = {}
        function handle:read(fmt)
            if fmt == "*a" then
                local rest = string.sub(buf, pos)
                pos = #buf + 1
                return rest
            end
            -- "*l"
            if pos > #buf then
                return nil
            end
            local nl = string.find(buf, "\n", pos, true)
            local line
            if nl then
                line = string.sub(buf, pos, nl - 1)
                pos = nl + 1
            else
                line = string.sub(buf, pos)
                pos = #buf + 1
            end
            return line
        end
        function handle:lines()
            return function()
                return handle:read("*l")
            end
        end
        function handle:close()
        end
        return handle
    end
    if mode == "w" then
        fs[path] = ""
    elseif fs[path] == nil then
        fs[path] = ""
    end
    local handle = {}
    function handle:write(text)
        fs[path] = fs[path] .. text
        return true
    end
    function handle:close()
    end
    return handle
end

io.open = function(path, mode, ...)
    if type(path) == "string" and path:find("addons", 1, true) then
        opens[path] = (opens[path] or 0) + 1
        return fake_file(path, mode or "r")
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
function TryGetProp(_, _, d)
    return d
end
local sysmsgs = {}
ui = {
    GetFrame = function()
        return nil
    end,
    SysMsg = function(msg)
        sysmsgs[#sysmsgs + 1] = msg
    end,
    SetEscapeScp = function()
    end,
    DestroyFrame = function()
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

-- フックの登録を数えるスタブ。
local hooks
g.setup_hook_and_event = function(_, origin)
    hooks[#hooks + 1] = origin
end
g.register_msg = function(msg)
    hooks[#hooks + 1] = msg
end
local json_files = {}
g.load_json = function(path)
    return json_files[path]
end
g.save_json = function(path)
    fs[path] = "SAVED"
end

local LOG = "../addons/_nexus_addons_p/TESTAID/market_voucher_log.txt"
local JSON = "../addons/_nexus_addons_p/TESTAID/market_voucher.json"
local OLD_LOG = "../addons/market_voucher/log_2507.txt"

local function reset(use)
    fs = {}
    opens = {}
    json_files = {}
    hooks = {}
    sysmsgs = {}
    g.market_voucher_migrated = nil
    g.settings = {
        market_voucher = {
            use = use,
            old_init_func = "MARKET_VOUCHER_ON_INIT_OLD"
        }
    }
end

print("[1] ログイン（on_init）では記録を読み書きしない")
reset(1)
market_voucher_on_init()
check("記録ファイルを開いていない", opens[LOG], nil)
check("json を保存していない", fs[JSON], nil)
check("フックは張る", #hooks, 4)

print("[2] OFF ならフックを張らない（素の処理を肩代わりしない）")
reset(0)
market_voucher_on_init()
check("フックの数", #hooks, 0)
check("パスは組み立てる", g.market_voucher_log_path, LOG)

print("[3] 記録は txt へ追記するだけ")
reset(1)
market_voucher_on_init()
Market_voucher_append_record("2026-08-21 10:00:00/名前/アイテム/1/100/100/buy")
Market_voucher_append_log({"2026-08-21 11:00:00/名前/アイテム/2/50/100/sell",
                           "2026-08-21 12:00:00/名前/アイテム/3/10/30/sell"})
check("json へは書かない", fs[JSON], nil)
local records = Market_voucher_get_records()
check("読み戻せる件数", #records, 3)
check("1 件目", records[1], "2026-08-21 10:00:00/名前/アイテム/1/100/100/buy")
check("3 件目", records[3], "2026-08-21 12:00:00/名前/アイテム/3/10/30/sell")

print("[4] txt が空なら json から 1 回だけ移行する")
reset(1)
market_voucher_on_init()
json_files[JSON] = {"2026-08-01 10:00:00/名前/古いアイテム/1/1/1/buy"}
records = Market_voucher_get_records()
check("移行できた", #records, 1)
-- 2 回目は移行しない（json をいじっても増えない）。
json_files[JSON] = {"a", "b", "c"}
records = Market_voucher_get_records()
check("2 回目は移行しない", #records, 1)

print("[5] txt に中身があれば json を見ない")
reset(1)
market_voucher_on_init()
fs[LOG] = "2026-08-21 10:00:00/名前/アイテム/1/1/1/buy\n"
json_files[JSON] = {"消えてはいけない", "上書きもされてはいけない"}
records = Market_voucher_get_records()
check("txt のまま", #records, 1)
check("中身も txt のもの", records[1], "2026-08-21 10:00:00/名前/アイテム/1/1/1/buy")

print("[6] 個別配布版のログ（log_2507.txt）を先に拾う")
reset(1)
market_voucher_on_init()
fs[OLD_LOG] = "2026-07-01 10:00:00/名前/個別版/1/1/1/buy\n"
json_files[JSON] = {"json より log_2507.txt を優先する"}
records = Market_voucher_get_records()
check("件数", #records, 1)
check("拾った先", records[1], "2026-07-01 10:00:00/名前/個別版/1/1/1/buy")

print("[7] Clear Log は .bak へ退避してから消す")
reset(1)
market_voucher_on_init()
Market_voucher_append_log({"1 件目", "2 件目"})
Market_voucher_clear()
check("txt は空", fs[LOG], "")
check("bak に残る", fs[LOG .. ".bak"], "1 件目\n2 件目\n")
check("読み直すと 0 件", #Market_voucher_get_records(), 0)

print("[8] 退避できないときは消さない")
reset(1)
market_voucher_on_init()
Market_voucher_append_log({"消えては困る記録"})
local saved_open = io.open
io.open = function(path, mode, ...)
    if type(path) == "string" and path:find(".bak", 1, true) then
        return nil -- 退避先だけ開けない状況を作る
    end
    return saved_open(path, mode, ...)
end
Market_voucher_clear()
io.open = saved_open
check("記録は残っている", #Market_voucher_get_records(), 1)

if failures > 0 then
    print(string.format("FAILED: %d 件", failures))
    os.exit(1)
end
print("ALL OK")
