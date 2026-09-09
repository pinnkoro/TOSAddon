-- indun_panel の「入場券をどれから使うか」を luajit 上で検査する（ゲーム不要）。
--
-- ここは**実機で券を 1 枚溶かすまで間違いが見えない**場所なので、機械で見ておく。
-- 見るのは次の 6 つ。
--   1. 既定の順序が、これまでの実装が実際にしていた順序と同じであること
--      （既定を変えると、設定を触っていない利用者の券の使われ方が黙って変わる）
--   2. 分類が**所持品の実物**から決まること（ID の直書きで振り分けない）
--   3. 期限付きは残りの短い順。同点は書いた順で割る
--      （以前は「1 日を切っているか」だけを見る table.sort で、1 日券は残り
--        ちょうど 86400 秒なので同点になり、table.sort は安定ではないため不定だった）
--   4. 期限の無い券は**書いた順の先頭**が勝つこと
--      （以前は for の中で上書きし続けていたので、リストの最後の ID が勝っていた）
--   5. 順序を入れ替えると、買う前に手持ちを使うようになること
--   6. 保存済みの順序が壊れていても直ること（知らない値は捨て、欠けは足す）
--   7. 「購入」より後ろの期限なし券は、まだ買えるうちは温存すること
--      （チャレンジ Lv560 は TOS と採掘場の 2 つのショップを持つので、押したボタン側の
--        枠を使い切っただけで手持ちを溶かしてはいけない。並べ替えて「購入」より前へ
--        持っていったときは、温存せずに使うこと）
--   8. 鍵の掛かった券の警告は、**何もできなかったときだけ**出すこと
--      （使える券が別にあれば入場は成功するので、そこで出すとノイズになる）
--
-- 使い方（リポジトリルートから）:
--     luajit docs/tests/test_indun_panel_ticket.lua

local SRC = "nexus_addons_p/src/addons/indun_panel/indun_panel.lua"

local function read_file(path)
    local f = assert(io.open(path, "r"), "読めない（リポジトリルートから実行すること）: " .. path)
    local data = f:read("*a")
    f:close()
    return data
end

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
-- ui.SysMsg だけは拾う（鍵の掛かった券の警告を数えるため）。
local sysmsgs = {}
_G.ui = setmetatable({
    SysMsg = function(text)
        table.insert(sysmsgs, text)
    end
}, {
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
_G.ClMsg = function(key)
    return key
end

-- 所持品。テストごとに inventory を差し替える。
local inventory = {}
local used = {}
_G.session = {
    GetInvItemByType = function(class_id)
        return inventory[class_id]
    end
}
_G.GetIES = function(obj)
    return obj
end
_G.TryGetProp = function(obj, name, default)
    local v = obj and obj[name]
    if v == nil then
        return default
    end
    return v
end
_G.GET_REMAIN_ITEM_LIFE_TIME = function(obj)
    return (obj and obj.life) or 0
end
_G.INV_ICON_USE = function(item)
    table.insert(used, item.ClassID)
end

-- 券 1 枚を作る。既定は「期限なし・取引できる」。
local function ticket(class_id, opt)
    opt = opt or {}
    local item = {
        ClassID = class_id,
        Name = "ticket" .. class_id,
        isLockState = opt.locked or false,
        life = opt.life or 0,
        BelongingCount = opt.belonging or 0
    }
    item.GetObject = function(self)
        return self
    end
    item.IsEnableMarketTrade = function(self)
        return opt.market ~= false
    end
    return item
end

local function set_inventory(list)
    inventory = {}
    used = {}
    sysmsgs = {}
    for _, item in ipairs(list) do
        inventory[item.ClassID] = item
    end
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
assert(type(_G.Indun_panel_consume_ticket) == "function", "入場券の共通処理が無い")

local failed = 0
local function check(label, got, want)
    if got == want then
        print(string.format("  ok  %s = %s", label, tostring(got)))
    else
        failed = failed + 1
        print(string.format("  NG  %s: expected %s, got %s", label, tostring(want), tostring(got)))
    end
end

local function reset_settings()
    g.indun_panel_settings = {
        ticket_order = {}
    }
end

local function order_of(group)
    return table.concat(Indun_panel_ticket_order(group), ",")
end

print("[1] 既定の順序は、これまでの実装が実際にしていた順序")
reset_settings()
check("レイド", order_of("raid"), "expiring,no_trade,tradable")
check("チャレンジ / 分裂", order_of("challenge"), "expiring,buy,no_trade,tradable")
check("その他", order_of("other"), "expiring,no_trade,tradable,buy")

print("[2] 分類は所持品の実物から決まる")
local function kind_of(opt)
    local kind = Indun_panel_ticket_kind(ticket(1, opt))
    return kind
end
check("期限が残っている", kind_of({
    life = 100
}), "expiring")
check("アカウント固定を含む", kind_of({
    belonging = 1
}), "no_trade")
check("市場へ出せない品", kind_of({
    market = false
}), "no_trade")
check("どれでもない", kind_of({}), "tradable")
check("期限は取引可否より先", kind_of({
    life = 100,
    belonging = 1
}), "expiring")

print("[3] 期限付きは残りの短い順。同点は書いた順")
reset_settings()
set_inventory({ticket(10, {
    life = 86400
}), ticket(11, {
    life = 3600
}), ticket(12, {
    life = 86400
})})
check("使えた", Indun_panel_consume_ticket("raid", {10, 11, 12}), true)
check("一番短いものを使った", used[1], 11)
-- 1 日券どうし（残りちょうど 86400 秒）は書いた順で割れること
set_inventory({ticket(10, {
    life = 86400
}), ticket(12, {
    life = 86400
})})
Indun_panel_consume_ticket("raid", {10, 12})
check("同点は書いた順の先頭", used[1], 10)
set_inventory({ticket(12, {
    life = 86400
}), ticket(10, {
    life = 86400
})})
Indun_panel_consume_ticket("raid", {12, 10})
check("並びを入れ替えたら先頭も変わる", used[1], 12)

print("[4] 期限の無い券は書いた順の先頭が勝つ（最後が勝たない）")
reset_settings()
set_inventory({ticket(20, {
    belonging = 1
}), ticket(21, {
    belonging = 1
})})
Indun_panel_consume_ticket("raid", {20, 21})
check("先頭を使った", used[1], 20)

print("[5] 既定では買うほうが先。順序を入れ替えると手持ちが先になる")
reset_settings()
set_inventory({ticket(30, {
    belonging = 1
})})
local bought = 0
Indun_panel_consume_ticket("challenge", {30}, {
    on_buy = function()
        bought = bought + 1
        return true
    end
})
check("既定は買う", bought, 1)
check("券は使っていない", #used, 0)
-- 「取引不可」を「購入」より前へ持っていく
g.indun_panel_settings.ticket_order.challenge = {"expiring", "no_trade", "buy", "tradable"}
set_inventory({ticket(30, {
    belonging = 1
})})
bought = 0
Indun_panel_consume_ticket("challenge", {30}, {
    on_buy = function()
        bought = bought + 1
        return true
    end
})
check("入れ替えたら手持ちを使う", used[1], 30)
check("買っていない", bought, 0)

print("[6] 買えなかったら次の分類へ進む")
reset_settings()
set_inventory({ticket(40, {
    belonging = 1
})})
bought = 0
Indun_panel_consume_ticket("challenge", {40}, {
    on_buy = function()
        bought = bought + 1
        return false
    end
})
check("買おうとはした", bought, 1)
check("買えなかったので券を使った", used[1], 40)

print("[7] 鍵の掛かった券は飛ばす")
reset_settings()
set_inventory({ticket(50, {
    belonging = 1,
    locked = true
}), ticket(51, {
    belonging = 1
})})
Indun_panel_consume_ticket("raid", {50, 51})
check("鍵の掛かっていないほうを使った", used[1], 51)

print("[8] 「購入」より後ろの期限なし券は、まだ買えるうちは温存する")
reset_settings()
set_inventory({ticket(60, {
    belonging = 1
})})
local shops_left = true
local tried = 0
local ok_used = Indun_panel_consume_ticket("challenge", {60}, {
    on_buy = function()
        tried = tried + 1
        return false -- 押した側のショップは空
    end,
    hold_permanent = function()
        return shops_left -- もう片方のショップにはまだ枠がある
    end
})
check("買おうとはした", tried, 1)
check("券は使っていない", #used, 0)
check("何もできていない", ok_used, false)
-- もう片方も空になったら使う
set_inventory({ticket(60, {
    belonging = 1
})})
shops_left = false
Indun_panel_consume_ticket("challenge", {60}, {
    on_buy = function()
        return false
    end,
    hold_permanent = function()
        return shops_left
    end
})
check("両方空なら使う", used[1], 60)

print("[9] 「購入」より前へ並べ替えたら温存しない（設定が効く）")
reset_settings()
g.indun_panel_settings.ticket_order.challenge = {"expiring", "no_trade", "buy", "tradable"}
set_inventory({ticket(61, {
    belonging = 1
})})
Indun_panel_consume_ticket("challenge", {61}, {
    on_buy = function()
        return false
    end,
    hold_permanent = function()
        return true -- まだ買えるが、利用者が手持ちを先に使う順にしている
    end
})
check("温存せずに使う", used[1], 61)

print("[10] 期限付きの券は温存の対象にしない")
reset_settings()
set_inventory({ticket(62, {
    life = 3600
})})
Indun_panel_consume_ticket("challenge", {62}, {
    on_buy = function()
        return false
    end,
    hold_permanent = function()
        return true
    end
})
check("期限付きはそのまま使う", used[1], 62)

print("[11] 鍵の掛かった券の警告は、何もできなかったときだけ出す")
reset_settings()
set_inventory({ticket(70, {
    belonging = 1,
    locked = true
}), ticket(71, {
    belonging = 1
})})
Indun_panel_consume_ticket("raid", {70, 71})
check("使えた", used[1], 71)
check("入場できたので警告は出さない", #sysmsgs, 0)
set_inventory({ticket(70, {
    belonging = 1,
    locked = true
})})
Indun_panel_consume_ticket("raid", {70})
check("何もできなかったので 1 回だけ出す", #sysmsgs, 1)

print("[12] 保存済みの順序が壊れていても直る")
reset_settings()
g.indun_panel_settings.ticket_order.raid = {"buy", "tradable", "tradable", "unknown"}
check("知らない値と重複を捨て、欠けを足す", order_of("raid"), "tradable,expiring,no_trade")
g.indun_panel_settings.ticket_order.challenge = "こわれている"
check("配列でなければ既定へ戻る", order_of("challenge"), "expiring,buy,no_trade,tradable")

if failed > 0 then
    print(string.format("FAILED: %d 件", failed))
    os.exit(1)
end
print("ALL OK")
