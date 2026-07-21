-- Auto Repaire ここから
g.auto_repair = {
    item_cls_id = 11201388,
    repair_item = "AustejaCertificate_14",
    shop_type = "AustejaCertificate"
}
function Auto_repair_save_settings()
    g.save_json(g.auto_repair_path, g.auto_repair_settings)
end

function Auto_repair_load_settings()
    g.auto_repair_path = string.format("../addons/%s/%s/auto_repair.json", addon_name_lower, g.active_id)
    local settings = g.load_json(g.auto_repair_path)
    local changed = false
    if not settings then
        settings = {
            buy_qty = 50,
            msg_qty = 20,
            setting_x = 800,
            setting_y = 700,
            auto_buy = false
        }
        changed = true
    end
    g.auto_repair_settings = settings
    if changed then
        Auto_repair_save_settings()
    end
end

function auto_repair_on_init()
    if not g.auto_repair_settings then
        Auto_repair_load_settings()
    end
    local old_func = g.settings.auto_repair.old_init_func
    if _G[old_func] then
        return
    end
    local durnotify = ui.GetFrame("durnotify")
    if durnotify and durnotify:IsVisible() == 1 then
        durnotify:Resize(0, 0)
    end
    g.setup_hook_and_event(g.addon, "DURNOTIFY_UPDATE", "Auto_repair_DURNOTIFY_UPDATE", false)
    if g.get_map_type() == "City" then
        local auto_repair_item = session.GetInvItemByType(g.auto_repair.item_cls_id)
        if not auto_repair_item or (auto_repair_item and auto_repair_item.count < g.auto_repair_settings.msg_qty) then
            Auto_repair_msg_box_init()
        end
    end
end

function Auto_repair_msg_box_init()
    if g.settings.auto_repair.use == 0 then
        return
    end
    if g.auto_repair_settings.auto_buy then
        local text = g.lang == "Japanese" and "{ol}[Auto Repair] 自動補充します" or
                         "{ol}[Auto Repair] Auto Replenish"
        ui.SysMsg(text)
        Auto_repair_buy_item()
        return
    end
    local yes_scp = string.format("Auto_repair_buy_item()")
    local msg = g.lang == "Japanese" and
                    "{ol}{#FFFFFF}[Auto Repair]修理キットの残りが少ないですが補充しますか？" or
                    "{ol}{#FFFFFF}[Auto Repair]{nl}Your repair kits are low{ol}Would you like to resupply them?"
    ui.MsgBox(msg, yes_scp, "None")
end

function Auto_repair_buy_item()
    local auto_repair_item = session.GetInvItemByType(g.auto_repair.item_cls_id)
    local recipe_cls = GetClass("ItemTradeShop", g.auto_repair.repair_item)
    local count = 0
    if auto_repair_item ~= nil then
        local repair_count = auto_repair_item.count
        count = g.auto_repair_settings.buy_qty - repair_count
    else
        count = g.auto_repair_settings.buy_qty
    end
    session.ResetItemList()
    session.AddItemID(tostring(0), 1)
    local item_list = session.GetItemIDList()
    local count_text = string.format("%s %s", tostring(recipe_cls.ClassID), tostring(count))
    local str_list = NewStringList()
    str_list:Add(g.auto_repair.shop_type)
    item.DialogTransaction("Certificate_SHOP", item_list, count_text, str_list)
end

function Auto_repair_setting_frame_close(frame)
    local frame_name = addon_name_lower .. "auto_repair_settings"
    ui.DestroyFrame(frame_name)
end

function Auto_repair_settings_frame_init()
    local list_frame = ui.GetFrame(addon_name_lower .. "list_frame")
    local auto_repair_settings = ui.CreateNewFrame("chat_memberlist", addon_name_lower .. "auto_repair_settings")
    AUTO_CAST(auto_repair_settings)
    auto_repair_settings:SetPos(list_frame:GetX() + list_frame:GetWidth(), list_frame:GetY())
    auto_repair_settings:EnableHitTest(1)
    auto_repair_settings:SetSkinName("test_frame_low")
    auto_repair_settings:SetLayerLevel(999)
    local title = auto_repair_settings:CreateOrGetControl('richtext', 'title', 20, 10, 10, 30)
    AUTO_CAST(title)
    title:SetText("{#000000}{s20}Auto Repair Settings")
    local close_button = auto_repair_settings:CreateOrGetControl('button', 'close_button', 0, 0, 20, 20)
    AUTO_CAST(close_button)
    close_button:SetImage("testclose_button")
    close_button:SetGravity(ui.RIGHT, ui.TOP)
    close_button:SetEventScript(ui.LBUTTONUP, "Auto_repair_setting_frame_close")
    local auto_repair_gb = auto_repair_settings:CreateOrGetControl("groupbox", "auto_repair_gb", 10, 40, 100, 100)
    AUTO_CAST(auto_repair_gb)
    auto_repair_gb:SetSkinName("bg")
    auto_repair_gb:RemoveAllChild()
    local buy_qty = auto_repair_gb:CreateOrGetControl('richtext', 'buy_qty', 10, 10)
    AUTO_CAST(buy_qty)
    buy_qty:SetText(g.lang == "Japanese" and "{ol}自動購入数入力" or "{ol}Number of automatic purchases")
    local msg_qty = auto_repair_gb:CreateOrGetControl('richtext', 'msg_qty', 10, 40)
    AUTO_CAST(msg_qty)
    msg_qty:SetText(g.lang == "Japanese" and "{ol}入力数以下で補充メッセージ" or
                        "{ol}Message with less than input quantit")
    local auto_purchase = auto_repair_gb:CreateOrGetControl('checkbox', "auto_purchase", 10, 70, 100, 25)
    AUTO_CAST(auto_purchase)
    auto_purchase:SetText(g.lang == "Japanese" and "{ol}自動補充有効化" or "{ol}Auto Replenishment Enable")
    auto_purchase:SetTextTooltip(g.lang == "Japanese" and "{ol}チェックすると自動で購入" or
                                     "{ol}Automatic purchase when checked")
    auto_purchase:SetCheck(g.auto_repair_settings.auto_buy and 1 or 0)
    auto_purchase:SetEventScript(ui.LBUTTONUP, "Auto_repair_setting")
    local width = math.max(buy_qty:GetWidth(), msg_qty:GetWidth())
    local buy_edit = auto_repair_gb:CreateOrGetControl('edit', 'buy_edit', width + 20, 15, 60, 30)
    AUTO_CAST(buy_edit)
    buy_edit:SetText("{ol}" .. g.auto_repair_settings.buy_qty)
    buy_edit:SetFontName("white_16_ol")
    buy_edit:SetTextAlign("center", "center")
    buy_edit:SetNumberMode(1)
    buy_edit:SetEventScript(ui.ENTERKEY, "Auto_repair_setting")
    buy_edit:SetTextTooltip(g.lang == "Japanese" and "{ol}エンターキー押下で登録" or
                                "{ol}Register by pressing enter key")
    local msg_edit = auto_repair_gb:CreateOrGetControl('edit', 'msg_edit', width + 20, 45, 60, 30)
    AUTO_CAST(msg_edit)
    msg_edit:SetText("{ol}" .. g.auto_repair_settings.msg_qty)
    msg_edit:SetFontName("white_16_ol")
    msg_edit:SetTextAlign("center", "center")
    msg_edit:SetNumberMode(1)
    msg_edit:SetEventScript(ui.ENTERKEY, "Auto_repair_setting")
    msg_edit:SetTextTooltip(g.lang == "Japanese" and "{ol}エンターキー押下で登録" or
                                "{ol}Register by pressing enter key")
    auto_repair_settings:Resize(width + 100, 150)
    auto_repair_gb:Resize(width + 80, 100)
    auto_repair_settings:ShowWindow(1)
end

function Auto_repair_setting(frame, ctrl)
    local ctrl_name = ctrl:GetName()
    if ctrl_name ~= "auto_purchase" then
        local value = tonumber(ctrl:GetText())
        if not value then
            return
        end
        if tonumber(value) ~= tonumber(g.auto_repair_settings.buy_qty) and ctrl_name == "buy_edit" then
            ui.SysMsg(g.lang == "Japanese" and "購入数量を " .. value .. " 個に設定しました" or
                          "Buy quantity set to " .. value)
            g.auto_repair_settings.buy_qty = value

        elseif tonumber(value) ~= tonumber(g.auto_repair_settings.msg_qty) and ctrl_name == "msg_edit" then
            ui.SysMsg(g.lang == "Japanese" and "お知らせ数量を " .. value .. " 個に設定しました" or
                          "Msg quantity set to " .. value)
            g.auto_repair_settings.msg_qty = value
        end
    elseif ctrl_name == "auto_purchase" then
        local is_check = ctrl:IsChecked()
        g.auto_repair_settings.auto_buy = is_check == 1 and true or false
    end
    Auto_repair_save_settings()
end

function Auto_repair_DURNOTIFY_UPDATE(my_frame, my_msg)
    local frame, notOpenFrame = g.get_event_args(my_msg)
    if g.settings.auto_repair.use == 0 then
        g.FUNCS["DURNOTIFY_UPDATE"](frame, notOpenFrame)
        return
    end
    if frame and frame:IsVisible() == 0 then
        frame:ShowWindow(1)
    end
    local slot_set = GET_CHILD_RECURSIVELY(frame, 'slotlist', 'ui::CSlotSet')
    slot_set:ClearIconAll()
    for i = 0, slot_set:GetSlotCount() - 1 do
        local slot = slot_set:GetSlotByIndex(i)
        slot:ShowWindow(0)
    end
    local reverse_index = slot_set:GetSlotCount() - 1
    local equip_list = session.GetEquipItemList()
    local some_flag = 1
    for i = 0, equip_list:Count() - 1 do
        local equip_item = equip_list:GetEquipItemByIndex(i)
        local spot = item.GetEquipSpotName(equip_item.equipSpot)
        local slot_cnt = imcSlot:GetFilledSlotCount(slot_set)
        local temp_obj = equip_item:GetObject()
        if temp_obj then
            local obj = GetIES(temp_obj)
            if IS_DUR_UNDER_10PER(obj) == true then
                local color_tone = "FF999900"
                if some_flag < 2 then
                    some_flag = 2
                    local type = equip_item.type
                    Auto_repair_item_use(obj, spot)
                end
                if IS_DUR_ZERO(obj) == true then
                    color_tone = "FF990000"
                    if some_flag < 3 then
                        some_flag = 3
                    end
                end
                local slot = slot_set:GetSlotByIndex(reverse_index - slot_cnt)
                local icon = CreateIcon(slot)
                local icon_img = obj.Icon
                local briquetting_id = TryGetProp(obj, 'BriquettingIndex', 0)
                if briquetting_id > 0 then
                    local briquetting_item_cls = GetClassByType('Item', briquetting_id)
                    icon_img = briquetting_item_cls.Icon
                end
                icon:Set(icon_img, 'Item', equip_item.type, reverse_index - slot_cnt, equip_item:GetIESID())
                icon:SetColorTone(color_tone)
                slot:ShowWindow(1)
            end
        end
    end
    local now_value = frame:GetValue()
    if some_flag == 1 then
        frame:SetValue(1)
    elseif some_flag == 2 and now_value < some_flag then
        frame:SetValue(2)
        ui.SysMsg(ScpArgMsg('DurUnder30'))
    elseif some_flag == 3 and now_value < some_flag then
        frame:SetValue(3)
        ui.SysMsg(ScpArgMsg('DurUnder0'))
    end
end

function Auto_repair_item_use(obj, spot)
    session.ResetItemList()
    local repair_kit = session.GetInvItemByType(g.auto_repair.item_cls_id)
    if repair_kit ~= nil and not repair_kit.isLockState then
        local repeat_count = math.min(repair_kit.count, 4)
        for i = 0, repeat_count - 1 do
            if obj.Dur / obj.MaxDur < 0.9 then
                item.UseByGUID(repair_kit:GetIESID())
            end
        end
    end
end
-- Auto Repaire ここまで

