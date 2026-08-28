-- market_voucher ここから
g.market_voucher_trans = {
    Japanese = {
        ["Sale Date/Time:"] = "販売日時 : ",
        ["Purchase Date/Time:"] = "購入日時 : ",
        ["name:"] = "名前 : ",
        ["item:"] = "アイテム: ",
        ["quantity:"] = "数量 : ",
        ["unit price:"] = "単価 : ",
        ["total amount:"] = "合計金額 : ",
        ["Total Sales:"] = "売上合計 : ",
        ["Period:"] = "集計期間 : ",
        ["Sales Slip"] = "売上伝票",
        ["Clear Log"] = "ログ削除",
        ["ClearedMsg"] = "販売履歴を削除しました。market_voucher_log.txt.bak に退避しています。",
        ["ClearFailedMsg"] = "退避に失敗したため、販売履歴は削除していません。",
        ["TruncatedMsg"] = "新しい %d 件だけ表示しています(全 %d 件)。すべては market_voucher_log.txt にあります。",
        ["CloseFrameTooltip"] = "左クリックでフレームを閉じます。",
        ["ClearLogTooltip"] = "販売履歴を削除します",
        ["sell"] = "販売",
        ["buy"] = "購入"
    },
    Default = {
        ["Sale Date/Time:"] = "Sale Date : ",
        ["Purchase Date/Time:"] = "Purch. Date : ",
        ["name:"] = "Name : ",
        ["item:"] = "Item : ",
        ["quantity:"] = "Qty : ",
        ["unit price:"] = "Unit Price : ",
        ["total amount:"] = "Total : ",
        ["Total Sales:"] = "Total Sales : ",
        ["Period:"] = "Period : ",
        ["Sales Slip"] = "Sales Slip",
        ["Clear Log"] = "Clear Log",
        ["ClearedMsg"] = "The sales history was cleared. A backup was kept as market_voucher_log.txt.bak.",
        ["ClearFailedMsg"] = "Could not write the backup, so the sales history was kept.",
        ["TruncatedMsg"] = "Showing the newest %d of %d records. The full log is in market_voucher_log.txt.",
        ["CloseFrameTooltip"] = "Left-click to close the frame.",
        ["ClearLogTooltip"] = "Clear the sales history",
        ["sell"] = "Sell",
        ["buy"] = "Buy"
    }
}
-- 取引記録の置き場所。**正本は market_voucher_log.txt の 1 本だけ**。
--
-- 以前は同じ内容を market_voucher.json にも書き、さらに
-- Market_voucher_load_settings() が**ログインのたびに json を全件 decode して、
-- そのまま re-encode で書き戻していた**。記録が増えるほど遅くなり、
-- 派生元の実測では 1,360 件 / 124KB で 5.2 秒かかっていた(Issue #101)。
-- しかも読み書きは on_init から無条件に走るので、**アドオンを OFF にしていても**往復していた。
--
-- 今は次のようにする。
--   * 書くのは追記だけ(Market_voucher_append_log)。json へは書かない
--   * 読むのは**伝票ウィンドウを開いたときだけ**(Market_voucher_get_records)
--   * on_init はパスを組み立てるだけ。OFF ならフックも張らない
--
-- 旧 json からの移行は「txt が空のときに 1 回だけ」行う(Market_voucher_migrate_log)。
-- json 自体は消さずに残す(利用者のデータなので、こちらの都合で捨てない)。
function Market_voucher_setup_paths()
    g.market_voucher_path = string.format("../addons/%s/%s/market_voucher.json", addon_name_lower, g.active_id)
    g.market_voucher_old_path = string.format("../addons/%s/%s/settings_2507.json", "market_voucher", g.active_id)
    g.market_voucher_log_path = string.format("../addons/%s/%s/market_voucher_log.txt", addon_name_lower, g.active_id)
    g.market_voucher_old_log_path = string.format('../addons/%s/log_2507.txt', "market_voucher")
end

-- txt に中身があるか。**全部読まない**(件数が多いほど遅くなるので、1 行だけ見る)。
local function market_voucher_log_has_content()
    local file = io.open(g.market_voucher_log_path, "r")
    if not file then
        return false
    end
    local first = file:read("*l")
    file:close()
    return first ~= nil and first ~= ""
end

-- 旧い置き場所から txt へ移す。**txt が空のときだけ、セッションに 1 回だけ**。
--
-- 拾う順番は次のとおり。個別配布版から引き継いだ利用者は log_2507.txt を持っている。
--   1. 個別版のログ(log_2507.txt)        … 行がそのまま使える
--   2. こちらの json(market_voucher.json) … 配列なので 1 行ずつ書き出す
--   3. 個別版の設定(settings_2507.json)   … 同上
function Market_voucher_migrate_log()
    if g.market_voucher_migrated then
        return
    end
    g.market_voucher_migrated = true
    if market_voucher_log_has_content() then
        return
    end
    local lines = nil
    local source = nil
    local old_log = io.open(g.market_voucher_old_log_path, "r")
    if old_log then
        local content = old_log:read("*a")
        old_log:close()
        if content and content ~= "" then
            lines = content
            source = "log_2507.txt"
        end
    end
    if not lines then
        for _, path in ipairs({g.market_voucher_path, g.market_voucher_old_path}) do
            local records = g.load_json(path)
            if type(records) == "table" and #records > 0 then
                lines = table.concat(records, "\n") .. "\n"
                source = path
                break
            end
        end
    end
    if not lines then
        return
    end
    local file = io.open(g.market_voucher_log_path, "w")
    if not file then
        g.log_error_once("market_voucher_migrate", "MarketVoucher: 記録の移行先を開けない")
        return
    end
    file:write(lines)
    file:close()
    g.vlog("market_voucher: 取引記録を %s から market_voucher_log.txt へ移した", tostring(source))
end

-- 記録を追記する。**1 回の取引で開くファイルは 1 つ、書き込みも 1 回**。
function Market_voucher_append_log(records)
    if type(records) ~= "table" or #records == 0 then
        return
    end
    Market_voucher_migrate_log()
    local file = io.open(g.market_voucher_log_path, "a")
    if not file then
        -- 記録できないこと自体は取引を止める理由にならないので、1 回だけ残して続ける。
        g.log_error_once("market_voucher_append", "MarketVoucher: 記録を書けない(取引自体は続行)")
        return
    end
    file:write(table.concat(records, "\n") .. "\n")
    file:close()
end

-- 記録を読む。**伝票ウィンドウを開いたときだけ呼ぶこと。**
-- ログインやマップ移動で呼ぶと、件数が増えるほど重くなる(それが Issue #101 の中身)。
function Market_voucher_get_records()
    Market_voucher_migrate_log()
    local records = {}
    local file = io.open(g.market_voucher_log_path, "r")
    if not file then
        return records
    end
    for line in file:lines() do
        if line ~= "" then
            records[#records + 1] = line
        end
    end
    file:close()
    return records
end

function market_voucher_on_init()
    -- パスの組み立てだけは OFF でも行う(設定画面から ON にしたときにすぐ使えるように)。
    Market_voucher_setup_paths()
    -- **use == 0 の早期 return はここでだけ行うこと。** 下の 3 本は
    -- setup_hook_and_event の第 4 引数が false = ゲーム側の関数を呼ばずに丸ごと
    -- 置き換える形で張る。張らなければ素の関数がそのまま残るので OFF は安全だが、
    -- **フックの中で早期 return すると市場で買えない / 受け取れなくなる**。
    if g.settings.market_voucher.use == 0 then
        return
    end
    local old_func = g.settings.market_voucher.old_init_func
    if _G[old_func] then
        return
    end
    g.setup_hook_and_event(g.addon, "CABINET_GET_ALL_LIST", "Market_voucher_CABINET_GET_ALL_LIST", false)
    g.setup_hook_and_event(g.addon, "_BUY_MARKET_ITEM", "Market_voucher__BUY_MARKET_ITEM", false)
    g.setup_hook_and_event(g.addon, "_CABINET_ITEM_BUY", "Market_voucher__CABINET_ITEM_BUY", false)
    g.register_msg("CABINET_ITEM_LIST", "Market_voucher_init_frame")
end

function Market_voucher_lang_trans(key)
    if g.market_voucher_trans[g.lang] and g.market_voucher_trans[g.lang][key] then
        return g.market_voucher_trans[g.lang][key]
    end
    return g.market_voucher_trans.Default[key] or key
end

function Market_voucher_ui_text(key)
    return "{ol}" .. Market_voucher_lang_trans(key)
end

-- 記録を取る 3 本のフック(CABINET_GET_ALL_LIST / _BUY_MARKET_ITEM / _CABINET_ITEM_BUY)は
-- OFF でも記録を書き続けていた。use を見ていたのは「売上伝票」ボタンを作る init_frame
-- だけで、OFF ではボタンが消えるだけだったため。
--
-- **ただし、この 3 本は setup_hook_and_event の第 4 引数が false = ゲーム側の関数を
-- 呼ばずに丸ごと置き換える形で張っている。**つまり買い注文・受け取りの実処理そのものを
-- このアドオンが肩代わりしている。OFF で早期 return すると、市場で買えない/受け取れない
-- という致命的な壊れ方をする。止めてよいのは記録の部分だけ。
-- 記録の失敗を、実処理(買い注文・受け取り)へ波及させないための共通の呼び出し方。
-- **3 本とも必ずここを通すこと。** 記録の中で落ちると、置き換えたゲーム側の処理へ
-- 届かず「押しても何も起きない」= 市場で買えない/受け取れない、という壊れ方をする。
-- 記録が落ちるのは実際にありえる(例: レシピ検索タブで買い個数が nil になる行)。
function Market_voucher_record_safely(key, record_func, ...)
    local ok, err = pcall(record_func, ...)
    if not ok then
        g.log_error_once(key, "MarketVoucher 記録でエラー(取引自体は続行): " .. tostring(err))
    end
end

-- 記録を 1 行足す。3 本のフックが同じ書き方をしていたのでまとめる。
function Market_voucher_append_record(result_string)
    Market_voucher_append_log({result_string})
end

function Market_voucher_CABINET_GET_ALL_LIST(my_frame, my_msg)
    local item_count = session.market.GetCabinetItemCount()
    if item_count == 0 then
        return
    end
    Market_voucher_record_safely("market_voucher_sold_list", Market_voucher_record_sold_list, item_count)
    AddLuaTimerFuncWithLimitCount("CABINET_GET_ITEM", 200, item_count * 5)
    local market_cabinet_soldlist = ui.GetFrame("market_cabinet_soldlist")
    if market_cabinet_soldlist then
        ui.CloseFrame("market_cabinet_soldlist")
    end
end

-- 一括受け取りの中身を売上として記録する。OFF なら何もしない。
function Market_voucher_record_sold_list(item_count)
    if g.settings.market_voucher.use == 0 then
        return
    end
    local my_char_name = GETMYPCNAME()
    local results_table = {}
    for i = 0, item_count - 1 do
        local cabinet_item = session.market.GetCabinetItemByIndex(i)
        if cabinet_item then
            local where_from = cabinet_item:GetWhereFrom()
            if where_from == "market_sell" then
                local item_obj = GetIES(cabinet_item:GetObject())
                local item_name = dictionary.ReplaceDicIDInCompStr(item_obj.Name)
                local sanitized_item_name = string.gsub(item_name, "-", "?")
                local reg_time = cabinet_item:GetRegSysTime()
                local formatted_time = string.format("%04d-%02d-%02d %02d:%02d:%02d", reg_time.wYear, reg_time.wMonth,
                    reg_time.wDay, reg_time.wHour, reg_time.wMinute, reg_time.wSecond)
                local quantity = tonumber(cabinet_item.sellItemAmount)
                local total_amount = tonumber(cabinet_item:GetCount())
                local unit_price = 0
                if quantity > 0 then
                    unit_price = total_amount / quantity
                end
                local result_string = string.format("%s/%s/%s/%d/%d/%d/%s", formatted_time, my_char_name,
                    sanitized_item_name, quantity, unit_price, total_amount, "sell")
                table.insert(results_table, result_string)
            end
        end
    end
    Market_voucher_append_log(results_table)
end

-- 買い注文の内容を記録する。OFF なら何もしない
-- (極性は record_sold_list と揃える。同じ機能の 3 本が use==0 と use==1 で
--  書き分かれていると、0/1 以外の値が入ったときに片方だけ記録が続く)。
function Market_voucher_record_buy(market_item, buy_count, total_price)
    if g.settings.market_voucher.use == 0 then
        return
    end
    local my_char_name = GETMYPCNAME()
    local item_obj = GetIES(market_item:GetObject())
    local item_name = dictionary.ReplaceDicIDInCompStr(item_obj.Name)
    local sanitized_item_name = string.gsub(item_name, "-", "?")
    local time = geTime.GetServerSystemTime()
    local formatted_time = string.format("%04d-%02d-%02d %02d:%02d:%02d", time.wYear, time.wMonth, time.wDay, time.wHour,
        time.wMinute, time.wSecond)
    local quantity = tonumber(buy_count)
    local total_amount = tonumber(total_price)
    local unit_price = 0
    if quantity and quantity > 0 then
        unit_price = total_amount / quantity
    end
    Market_voucher_append_record(string.format("%s/%s/%s/%d/%d/%d/%s", formatted_time, my_char_name,
        sanitized_item_name, quantity or 1, unit_price, total_amount, "buy"))
end

-- 個別受け取りの内容を売上として記録する。OFF なら何もしない。
function Market_voucher_record_cabinet_sell(guid)
    if g.settings.market_voucher.use == 0 then
        return
    end
    local cabinet_item = session.market.GetCabinetItemByItemID(guid)
    local item_obj = GetIES(cabinet_item:GetObject())
    local item_name = dictionary.ReplaceDicIDInCompStr(item_obj.Name)
    local sanitized_item_name = string.gsub(item_name, "-", "?")
    local reg_time = cabinet_item:GetRegSysTime()
    local formatted_time = string.format("%04d-%02d-%02d %02d:%02d:%02d", reg_time.wYear, reg_time.wMonth, reg_time.wDay,
        reg_time.wHour, reg_time.wMinute, reg_time.wSecond)
    local quantity = tonumber(cabinet_item.sellItemAmount)
    local total_amount = tonumber(cabinet_item:GetCount())
    local unit_price = 0
    if quantity > 0 then
        unit_price = total_amount / quantity
    end
    Market_voucher_append_record(string.format("%s/%s/%s/%d/%d/%d/%s", formatted_time, GETMYPCNAME(),
        sanitized_item_name, quantity, unit_price, total_amount, "sell"))
end

function Market_voucher__BUY_MARKET_ITEM(my_frame, my_msg)
    local row, is_recipe_search_box = g.get_event_args(my_msg)
    local frame = ui.GetFrame("market")
    local total_price = 0
    market.ClearBuyInfo()
    local market_item = nil
    local buy_count = nil
    if is_recipe_search_box and is_recipe_search_box == 1 then
        local recipeSearchGbox = GET_CHILD_RECURSIVELY(frame, "recipeSearchGbox")
        local child = recipeSearchGbox:GetChildByIndex(row - 1)
        local count = GET_CHILD_RECURSIVELY(child, "count")
        if count == nil then
            market_item = session.market.GetRecipeSearchByIndex(row - 1)
            market.AddBuyInfo(market_item:GetMarketGuid(), 1)
            total_price = SumForBigNumber(total_price, market_item:GetSellPrice())
        else
            buy_count = count:GetText()
            if tonumber(buy_count) > 0 then
                market_item = session.market.GetRecipeSearchByIndex(row - 1)
                market.AddBuyInfo(market_item:GetMarketGuid(), buy_count)
                total_price = SumForBigNumber(total_price, math.mul_int_for_lua(buy_count, market_item:GetSellPrice()))
            else
                ui.SysMsg(ScpArgMsg("YouCantBuyZeroItem"))
            end
        end
    else
        local itemListGbox = GET_CHILD_RECURSIVELY(frame, "itemListGbox")
        local child = itemListGbox:GetChildByIndex(row - 1)
        if child == nil then
            market_item = session.market.GetItemByIndex(row - 1)
            market.AddBuyInfo(market_item:GetMarketGuid(), 1)
            total_price = SumForBigNumber(total_price, market_item:GetSellPrice())
        else
            local count = GET_CHILD_RECURSIVELY(child, "count")
            buy_count = 1
            if count then
                buy_count = count:GetText()
            end
            if tonumber(buy_count) > 0 then
                market_item = session.market.GetItemByIndex(row - 1)
                market.AddBuyInfo(market_item:GetMarketGuid(), buy_count)
                total_price = SumForBigNumber(total_price, math.mul_int_for_lua(buy_count, market_item:GetSellPrice()))
            else
                ui.SysMsg(ScpArgMsg("YouCantBuyZeroItem"))
            end
        end
    end
    if total_price == 0 then
        return
    end
    if IsGreaterThanForBigNumber(total_price, GET_TOTAL_MONEY_STR()) == 1 then
        ui.SysMsg(ClMsg("NotEnoughMoney"))
        return
    end
    local limit_trade_str = GET_REMAIN_MARKET_TRADE_AMOUNT_STR()
    if limit_trade_str then
        if IsGreaterThanForBigNumber(total_price, limit_trade_str) == 1 then
            ui.SysMsg(ScpArgMsg('MarketMaxSilverLimit{LIMIT}Over', 'LIMIT', GET_COMMAED_STRING(limit_trade_str)))
            return
        end
    end
    -- 記録は OFF なら取らない。買い注文(ReqBuyItems)は OFF でも必ず出すこと
    -- (このフックがゲーム側の _BUY_MARKET_ITEM を置き換えているため)。
    Market_voucher_record_safely("market_voucher_buy", Market_voucher_record_buy, market_item, buy_count, total_price)
    market.ReqBuyItems()
end

function Market_voucher__CABINET_ITEM_BUY(my_frame, my_msg)
    local frame, ctrl, guid = g.get_event_args(my_msg)
    -- 記録は OFF なら取らない。受け取り(ReqGetCabinetItem)は OFF でも必ず出すこと
    -- (このフックがゲーム側の _CABINET_ITEM_BUY を置き換えているため)。
    Market_voucher_record_safely("market_voucher_cabinet", Market_voucher_record_cabinet_sell, guid)
    market.ReqGetCabinetItem(guid)
    local market_cabinet_popup = ui.GetFrame("market_cabinet_popup")
    if market_cabinet_popup then
        ui.CloseFrame("market_cabinet_popup")
    end
end

function Market_voucher_init_frame()
    local market_cabinet = ui.GetFrame("market_cabinet")
    if g.settings.market_voucher.use == 0 then
        local log_btn = GET_CHILD(market_cabinet, "log_btn")
        if log_btn then
            DESTROY_CHILD_BYNAME(market_cabinet, "log_btn")
        end
        return
    end
    if market_cabinet:GetChild("log_btn") then
        return
    end
    local log_btn = market_cabinet:CreateOrGetControl("button", "log_btn", 610, 120, 100, 30)
    AUTO_CAST(log_btn)
    log_btn:SetSkinName("tab2_btn")
    local text = "{@st66b18}" .. Market_voucher_lang_trans("Sales Slip")
    log_btn:SetText(text)
    log_btn:SetEventScript(ui.LBUTTONUP, "Market_voucher_print")
    log_btn:ShowWindow(1)
end

-- 伝票に並べる行数の上限。**ここでしか記録を読まない**とはいえ、1 行につき richtext を
-- 1 つ作るので、数千件あるとウィンドウを開くたびに数千個のコントロールを作ることになる。
-- 枠(720px / 1 行 20px)に入るのは 36 行なので、それを大きく超えるぶんは作っても見えない。
-- 並びは新しい順なので、上限で切っても**新しい取引から順に見える**。
-- 合計と集計期間は**切る前の全件**から出す(数字だけ小さくなると、消えたように見えるため)。
local MARKET_VOUCHER_MAX_ROWS = 200

function Market_voucher_print()
    -- 記録を読むのはここだけ。ログインやマップ移動では読まない(Issue #101)。
    local records = Market_voucher_get_records()
    if #records == 0 then
        return
    end
    local market_voucher = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "market_voucher", 0, 0, 0, 0)
    AUTO_CAST(market_voucher)
    g.block_click_through(market_voucher)
    market_voucher:SetSkinName("downbox")
    market_voucher:ShowTitleBar(0)
    market_voucher:SetOffset(15, 175)
    market_voucher:Resize(1280, 770)
    market_voucher:EnableHitTest(1)
    market_voucher:SetLayerLevel(100)
    local bg = market_voucher:CreateOrGetControl("groupbox", "bg", 5, 5, 1270, 720)
    AUTO_CAST(bg)
    bg:SetSkinName("chat_window")
    bg:SetTextTooltip(Market_voucher_ui_text("CloseFrameTooltip"))
    bg:SetEventScript(ui.LBUTTONUP, "Market_voucher_print_close")
    local log_delete_button = market_voucher:CreateOrGetControl("button", "logdelete", 1180, 735, 80, 30)
    AUTO_CAST(log_delete_button)
    log_delete_button:SetTextTooltip(Market_voucher_ui_text("ClearLogTooltip"))
    log_delete_button:SetText(Market_voucher_ui_text("Clear Log"))
    log_delete_button:SetEventScript(ui.LBUTTONUP, "Market_voucher_clear")
    local close_button = market_voucher:CreateOrGetControl("button", "close", 1245, 0, 30, 30)
    AUTO_CAST(close_button)
    close_button:SetImage("testclose_button")
    close_button:SetEventScript(ui.LBUTTONUP, "Market_voucher_print_close")
    local sumtotal_amount = 0
    table.sort(records, function(a, b)
        return a > b
    end)
    local item_count = #records
    local shown_count = math.min(item_count, MARKET_VOUCHER_MAX_ROWS)
    local y_pos = 5
    for i = 1, item_count do
        local tokens = StringSplit(records[i], '/')
        local date_str = tokens[1]
        local name_str = tokens[2]
        local item_str = string.gsub(tokens[3], "?", "-")
        local quantity_str = tokens[4]
        local unit_price_val = tonumber(tokens[5])
        local total_amount_val = tonumber(tokens[6])
        local status = tokens[7]
        local line_text = ""
        if status == "sell" then
            status = Market_voucher_ui_text(status)
            sumtotal_amount = sumtotal_amount + total_amount_val
            unit_price_val = unit_price_val / 0.9
            line_text = string.format("%s%s ･ %s ･ %s ･ %s%s ･ %s%s ･ %s%s ･ %s",
                Market_voucher_lang_trans("Sale Date/Time:"), date_str, name_str, item_str,
                Market_voucher_lang_trans("quantity:"), quantity_str, Market_voucher_lang_trans("unit price:"),
                GET_COMMAED_STRING(unit_price_val), Market_voucher_lang_trans("total amount:"),
                GET_COMMAED_STRING(total_amount_val), status)
        elseif status == "buy" then
            status = Market_voucher_ui_text(status)
            sumtotal_amount = sumtotal_amount - total_amount_val
            line_text = "{#DAA520}" .. string.format("%s%s ･ %s ･ %s ･ %s%s ･ %s%s ･ %s△%s ･ %s",
                Market_voucher_lang_trans("Purchase Date/Time:"), date_str, name_str, item_str,
                Market_voucher_lang_trans("quantity:"), quantity_str, Market_voucher_lang_trans("unit price:"),
                GET_COMMAED_STRING(unit_price_val), Market_voucher_lang_trans("total amount:"),
                GET_COMMAED_STRING(total_amount_val), status)
        end
        -- 合計と集計期間は全件から出すので、ループ自体は最後まで回す。
        -- **作るのを止めるのはコントロールだけ。**
        if i <= shown_count then
            local text_view = bg:CreateOrGetControl("richtext", "textview" .. i, 5, y_pos)
            AUTO_CAST(text_view)
            text_view:SetText("{ol}" .. line_text)
            y_pos = y_pos + 20
        end
    end
    if item_count > shown_count then
        -- 上限で切ったことを黙らない(全部出たと誤解させない)。全件は txt に残っている。
        local note = bg:CreateOrGetControl("richtext", "truncated", 5, y_pos)
        AUTO_CAST(note)
        note:SetText("{ol}{#FF9933}" ..
                         string.format(Market_voucher_lang_trans("TruncatedMsg"), shown_count, item_count))
    end
    local date_pattern = "^(%d%d%d%d%-%d%d%-%d%d)"
    local latest_date_str = string.match(records[1], date_pattern)
    local earliest_date_str = string.match(records[item_count], date_pattern)
    local sum_total_amount_text = market_voucher:CreateOrGetControl("richtext", "sumtotal_amount_text", 900, 740, 100,
        30)
    local rounded_number = math.floor(sumtotal_amount / 1000000 + 0.5)
    sum_total_amount_text:SetText("{#FF0000}" .. Market_voucher_ui_text("Total Sales:") ..
                                      GET_COMMAED_STRING(sumtotal_amount) .. "(" .. GET_COMMAED_STRING(rounded_number) ..
                                      "M)")
    sum_total_amount_text:ShowWindow(1)
    local period_text = market_voucher:CreateOrGetControl("richtext", "date_text", 620, 740, 100, 30)
    period_text:SetText(Market_voucher_ui_text("Period:") .. earliest_date_str .. "～" .. latest_date_str)
    market_voucher:ShowWindow(1)
    g.esc_register(addon_name_lower .. "market_voucher", "Market_voucher_print_close")
    market_voucher:RunUpdateScript("Market_voucher_auto_close", 0.3)
end

function Market_voucher_auto_close(market_voucher)
    local market_cabinet = ui.GetFrame("market_cabinet")
    if market_cabinet:IsVisible() == 1 then
        return 1
    else
        ui.DestroyFrame(market_voucher:GetName())
        market_cabinet:RemoveChild("log_btn")
        return 0
    end
end

-- 「Clear Log」。**txt が正本になったので、消す前に .bak へ退避する。**
-- 以前は json だけ消して txt を残していたので「ログテキストには残っています」で済んでいたが、
-- 今そのまま消すと戻す手段が無くなる。文言も揃えて直してある(ClearedMsg)。
function Market_voucher_clear()
    local records = Market_voucher_get_records()
    if #records > 0 then
        local backup = io.open(g.market_voucher_log_path .. ".bak", "w")
        if backup then
            backup:write(table.concat(records, "\n") .. "\n")
            backup:close()
        else
            -- 退避できないなら消さない。**消えて戻せない**より、消えないほうがまだよい。
            g.log_error_once("market_voucher_clear", "MarketVoucher: 退避先を開けないので削除を中止した")
            ui.SysMsg(Market_voucher_ui_text("ClearFailedMsg"))
            return
        end
    end
    local file = io.open(g.market_voucher_log_path, "w")
    if file then
        file:close()
    end
    ui.SysMsg(Market_voucher_ui_text("ClearedMsg"))
    g.vlog("market_voucher: 記録 %d 件を .bak へ退避して消した", #records)
    -- 開いている伝票は中身が古いままになるので畳む。
    Market_voucher_print_close()
end

function Market_voucher_print_close()
    local market_voucher = ui.GetFrame(addon_name_lower .. "market_voucher")
    -- **無いことがある。** 伝票を開いていない状態からも呼ばれる(Clear Log の後始末)。
    -- 素で :GetName() を呼ぶとそこで落ちる。
    if not market_voucher then
        return
    end
    ui.DestroyFrame(market_voucher:GetName())
end
-- market_voucher ここまで

