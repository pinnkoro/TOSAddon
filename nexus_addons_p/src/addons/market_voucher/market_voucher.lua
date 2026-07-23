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
        ["ClearedMsg"] = "販売履歴を削除しました。logtextには残っています。",
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
        ["ClearedMsg"] = "The sales history has been deleted. It remains in the log text.",
        ["CloseFrameTooltip"] = "Left-click to close the frame.",
        ["ClearLogTooltip"] = "Clear the sales history",
        ["sell"] = "Sell",
        ["buy"] = "Buy"
    }
}
function Market_voucher_save_settings()
    g.save_json(g.market_voucher_path, g.market_voucher_settings)
end

function Market_voucher_load_settings()
    g.market_voucher_path = string.format("../addons/%s/%s/market_voucher.json", addon_name_lower, g.active_id)
    g.market_voucher_old_path = string.format("../addons/%s/%s/settings_2507.json", "market_voucher", g.active_id)
    g.market_voucher_log_path = string.format("../addons/%s/%s/market_voucher_log.txt", addon_name_lower, g.active_id)
    g.market_voucher_old_log_path = string.format('../addons/%s/log_2507.txt', "market_voucher")
    local settings = g.load_json(g.market_voucher_path)
    if not settings then
        local old_settings = g.load_json(g.market_voucher_old_path)
        if old_settings then
            settings = old_settings
            local old_log_file = io.open(g.market_voucher_old_log_path, "r")
            if old_log_file then
                local content = old_log_file:read("*a")
                old_log_file:close()
                local new_log_file = io.open(g.market_voucher_log_path, "w")
                if new_log_file then
                    new_log_file:write(content)
                    new_log_file:close()
                end
            end
        else
            settings = {}
        end
    end
    g.market_voucher_settings = settings
    Market_voucher_save_settings()
end

function market_voucher_on_init()
    if not g.market_voucher_settings then
        Market_voucher_load_settings()
    end
    local old_func = g.settings.market_voucher.old_init_func
    if _G[old_func] then
        return
    end
    g.setup_hook_and_event(g.addon, "CABINET_GET_ALL_LIST", "Market_voucher_CABINET_GET_ALL_LIST", false)
    g.setup_hook_and_event(g.addon, "_BUY_MARKET_ITEM", "Market_voucher__BUY_MARKET_ITEM", false)
    g.setup_hook_and_event(g.addon, "_CABINET_ITEM_BUY", "Market_voucher__CABINET_ITEM_BUY", false)
    g.addon:RegisterMsg("CABINET_ITEM_LIST", "Market_voucher_init_frame")
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

function Market_voucher_CABINET_GET_ALL_LIST(my_frame, my_msg)
    local fmarket_cabinet, control, strarg, now = g.get_event_args(my_msg)
    local item_count = session.market.GetCabinetItemCount()
    if item_count == 0 then
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
    for i, result_string in ipairs(results_table) do
        table.insert(g.market_voucher_settings, result_string)
    end
    Market_voucher_save_settings()
    if #results_table > 0 then
        local all_results = table.concat(results_table, "\n")
        local file_handle = io.open(g.market_voucher_log_path, "a")
        if file_handle then
            file_handle:write(all_results .. "\n")
            file_handle:close()
        end
    end
    local count = session.market.GetCabinetItemCount()
    AddLuaTimerFuncWithLimitCount("CABINET_GET_ITEM", 200, count * 5)
    local market_cabinet_soldlist = ui.GetFrame("market_cabinet_soldlist")
    if market_cabinet_soldlist then
        ui.CloseFrame("market_cabinet_soldlist")
    end
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
    local my_char_name = GETMYPCNAME()
    local item_obj = GetIES(market_item:GetObject())
    local item_name = dictionary.ReplaceDicIDInCompStr(item_obj.Name)
    local sanitized_item_name = string.gsub(item_name, "-", "?")
    local time = geTime.GetServerSystemTime()
    local formatted_time = string.format("%04d-%02d-%02d %02d:%02d:%02d", time.wYear, time.wMonth, time.wDay,
        time.wHour, time.wMinute, time.wSecond)
    local quantity = tonumber(buy_count)
    local total_amount = tonumber(total_price)
    local unit_price = 0
    if quantity > 0 then
        unit_price = total_amount / quantity
    end
    local result_string = string.format("%s/%s/%s/%d/%d/%d/%s", formatted_time, my_char_name, sanitized_item_name,
        quantity, unit_price, total_amount, "buy")
    table.insert(g.market_voucher_settings, result_string)
    local file_handle = io.open(g.market_voucher_log_path, "a")
    if file_handle then
        file_handle:write(result_string .. "\n")
        file_handle:close()
    end
    Market_voucher_save_settings()
    market.ReqBuyItems()
end

function Market_voucher__CABINET_ITEM_BUY(my_frame, my_msg)
    local frame, ctrl, guid = g.get_event_args(my_msg)
    local cabinet_item = session.market.GetCabinetItemByItemID(guid)
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
    local my_char_name = GETMYPCNAME()
    local result_string = string.format("%s/%s/%s/%d/%d/%d/%s", formatted_time, my_char_name, sanitized_item_name,
        quantity, unit_price, total_amount, "sell")
    table.insert(g.market_voucher_settings, result_string)
    local file_handle = io.open(g.market_voucher_log_path, "a")
    if file_handle then
        file_handle:write(result_string .. "\n")
        file_handle:close()
    end
    Market_voucher_save_settings()
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

function Market_voucher_print()
    if #g.market_voucher_settings == 0 then
        return
    end
    local market_voucher = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "market_voucher", 0, 0, 0, 0)
    AUTO_CAST(market_voucher)
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
    table.sort(g.market_voucher_settings, function(a, b)
        return a > b
    end)
    local item_count = #g.market_voucher_settings
    local y_pos = 5
    for i = 1, item_count do
        local tokens = StringSplit(g.market_voucher_settings[i], '/')
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
        local text_view = bg:CreateOrGetControl("richtext", "textview" .. i, 5, y_pos)
        AUTO_CAST(text_view)
        text_view:SetText("{ol}" .. line_text)
        y_pos = y_pos + 20
    end
    local date_pattern = "^(%d%d%d%d%-%d%d%-%d%d)"
    local latest_date_str = string.match(g.market_voucher_settings[1], date_pattern)
    local earliest_date_str = string.match(g.market_voucher_settings[item_count], date_pattern)
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

function Market_voucher_clear()
    g.market_voucher_settings = {}
    ui.SysMsg(Market_voucher_ui_text("ClearedMsg"))
    Market_voucher_save_settings()
end

function Market_voucher_print_close()
    local market_voucher = ui.GetFrame(addon_name_lower .. "market_voucher")
    ui.DestroyFrame(market_voucher:GetName())
end
-- market_voucher ここまで

