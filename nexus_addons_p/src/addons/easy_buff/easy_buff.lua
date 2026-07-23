-- easy_buff ここから
function Easy_buff_save_settings()
    g.save_json(g.easy_buff_path, g.easy_buff_settings)
end

function Easy_buff_load_settings()
    g.easy_buff_path = string.format("../addons/%s/%s/easy_buff.json", addon_name_lower, g.active_id)
    local settings = g.load_json(g.easy_buff_path)
    if not settings then
        settings = {}
    end
    local defaults = {
        food_presets_name = {},
        food_presets_check = {},
        food_check = 1,
        confirm_check = 0,
        repair_check = 0
    }
    for k, v in pairs(defaults) do
        if settings[k] == nil then
            settings[k] = v
        end
    end
    local changed = false
    for i = 1, 4 do
        local str_i = tostring(i)
        if not settings.food_presets_name[str_i] then
            settings.food_presets_name[str_i] = "preset " .. i
            changed = true
        end
        if not settings.food_presets_check[str_i] then
            settings.food_presets_check[str_i] = {}
            changed = true
        end
        for check_index = 1, 6 do
            local str_index = tostring(check_index)
            if not settings.food_presets_check[str_i][str_index] then
                settings.food_presets_check[str_i][str_index] = 1
                changed = true
            end
        end
    end
    g.easy_buff_settings = settings
    if changed then
        Easy_buff_save_settings()
    end
end

function easy_buff_on_init()
    if not g.easy_buff_settings then
        Easy_buff_load_settings()
    end
    local old_func = g.settings.easy_buff.old_init_func
    if _G[old_func] then
        return
    end
    g.setup_hook_and_event(g.addon, "OPEN_FOOD_TABLE_UI", "Easy_buff_OPEN_FOOD_TABLE_UI", true)
    g.setup_hook_and_event(g.addon, "ITEMBUFF_REPAIR_UI_COMMON", "Easy_buff_ITEMBUFF_REPAIR_UI_COMMON", true)
    g.setup_hook_and_event(g.addon, "SQUIRE_BUFF_EQUIP_CTRL", "Easy_buff_SQUIRE_BUFF_EQUIP_CTRL", true)
    g.setup_hook_and_event(g.addon, "TARGET_BUFF_AUTOSELL_LIST", "Easy_buff_TARGET_BUFF_AUTOSELL_LIST", true)
    g.easy_buff_first = true
end
-- 設定フレーム
function Easy_buff_config_frame()
    local frame_name = addon_name_lower .. "easy_buff"
    local easy_buff = ui.CreateNewFrame("notice_on_pc", frame_name, 0, 0, 0, 0)
    easy_buff:RemoveAllChild()
    easy_buff:SetSkinName("test_frame_low")
    easy_buff:SetLayerLevel(999)
    easy_buff:Resize(490, 410)
    local list_frame_name = addon_name_lower .. "list_frame"
    local list_frame = ui.GetFrame(addon_name_lower .. "list_frame")
    -- ts(list_frame:GetX() + list_frame:GetWidth(), list_frame:GetY())
    easy_buff:SetPos(list_frame:GetX() + list_frame:GetWidth(), list_frame:GetY())
    easy_buff:SetTitleBarSkin("None")
    easy_buff:EnableHittestFrame(1)
    easy_buff:EnableHitTest(1)
    easy_buff:ShowWindow(1)
    local title_text = easy_buff:CreateOrGetControl('richtext', 'title_text', 20, 15, 50, 30)
    AUTO_CAST(title_text)
    title_text:SetText("{ol}Easy Buff Config")
    local close = easy_buff:CreateOrGetControl("button", "close", 0, 0, 20, 20)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Easy_buff_config_frame_close")
    local gbox = easy_buff:CreateOrGetControl("groupbox", "gbox", 10, 40, easy_buff:GetWidth() - 20,
        easy_buff:GetHeight() - 50)
    AUTO_CAST(gbox)
    gbox:SetSkinName("test_frame_midle_light")
    local icons = {"icon_item_sandwich", "icon_item_soup", "icon_item_yogurt", "icon_item_salad", "icon_item_BBQ",
                   "icon_item_champagne"}
    local x_offsets = {5, 75, 145, 215, 285, 355}
    local y = 0
    for i = 1, 4 do
        local str_i = tostring(i)
        local title_edit = gbox:CreateOrGetControl('edit', "preset_title_" .. i, 10, y + 5, 80, 20)
        AUTO_CAST(title_edit)
        title_edit:SetFontName('white_14_ol')
        title_edit:SetSkinName('test_weight_skin')
        title_edit:SetTextAlign('center', 'center')
        title_edit:SetText("{ol}" .. g.easy_buff_settings.food_presets_name[str_i])
        if str_i == "1" then
            title_edit:Focus()
        end
        title_edit:SetEventScript(ui.ENTERKEY, "Easy_buff_config_presetname_change")
        local food_check = gbox:CreateOrGetControl('checkbox', "food_check" .. i, 10, y + 35, 30, 30)
        AUTO_CAST(food_check)
        food_check:SetTextTooltip(g.lang == "Japanese" and "{ol}チェックすると食事バフ自動化" or
                                      "{ol}Checked: Automate food buff")
        food_check:SetEventScript(ui.LBUTTONUP, "Easy_buff_config_check_toggle")
        food_check:SetEventScriptArgNumber(ui.LBUTTONUP, i)
        food_check:SetCheck(i == g.easy_buff_settings.food_check and 1 or 0)
        local preset_gbox = gbox:CreateOrGetControl("groupbox", "preset_gbox_" .. i, 40, y + 30, gbox:GetWidth() - 50,
            40)
        AUTO_CAST(preset_gbox)
        preset_gbox:SetSkinName("test_frame_midle_light")
        for check_index = 1, #icons do
            local str_index = tostring(check_index)
            local icon_name = icons[check_index]
            local checkbox_x = x_offsets[check_index]
            local checkbox_name = "check_" .. i .. "_" .. check_index
            local checkbox_ctrl = preset_gbox:CreateOrGetControl('checkbox', checkbox_name, checkbox_x, 5, 30, 30)
            AUTO_CAST(checkbox_ctrl)
            checkbox_ctrl:SetText("{img " .. icon_name .. " 30 30}")
            checkbox_ctrl:SetCheck(g.easy_buff_settings.food_presets_check[str_i][str_index])
            checkbox_ctrl:SetEventScript(ui.LBUTTONUP, "Easy_buff_config_check_toggle")
        end
        y = y + 70
    end
    local confirm_check = gbox:CreateOrGetControl('checkbox', "confirm_check", 10, y + 10, 30, 30)
    AUTO_CAST(confirm_check)
    confirm_check:SetText(g.lang == "Japanese" and
                              "{ol}チェックするとバフ掛け直し確認(残り1時間以上)" or
                              "{ol}Check to Confirm Re-buffing (remaining over 1h)")
    confirm_check:SetEventScript(ui.LBUTTONUP, "Easy_buff_config_check_toggle")
    confirm_check:SetCheck(g.easy_buff_settings.confirm_check)
    -- repair_check
    local repair_check = gbox:CreateOrGetControl('checkbox', "repair_check", 10, y + 45, 30, 30)
    AUTO_CAST(repair_check)
    repair_check:SetText(g.lang == "Japanese" and
                             "{ol}チェックすると修理屋フレームを自動で閉じます" or
                             "{ol}Check to Auto-close Repair Shop Frame")
    repair_check:SetEventScript(ui.LBUTTONUP, "Easy_buff_config_check_toggle")
    repair_check:SetCheck(g.easy_buff_settings.repair_check)
end

function Easy_buff_config_frame_close(frame)
    ui.DestroyFrame(frame:GetName())
end

function Easy_buff_config_presetname_change(frame, ctrl)
    local ctrl_name = ctrl:GetName()
    local last_char = string.sub(ctrl_name, -1)
    local text = ctrl:GetText()
    local msg = g.lang == "Japanese" and text .. "{ol} 設定しました" or "{ol} Set up"
    ui.SysMsg(msg)
    g.easy_buff_settings.food_presets_name[last_char] = text
    Easy_buff_save_settings()
    Easy_buff_config_frame()
end

function Easy_buff_config_check_toggle(parent, ctrl, str, num)
    local ctrl_name = ctrl:GetName()
    local is_check = ctrl:IsChecked()
    if string.find(ctrl_name, "food_check") then
        if is_check == 1 then
            g.easy_buff_settings.food_check = num
        else
            g.easy_buff_settings.food_check = 0
        end
    elseif ctrl_name == "confirm_check" then
        g.easy_buff_settings.confirm_check = is_check
    elseif ctrl_name == "repair_check" then
        g.easy_buff_settings.repair_check = is_check
    else
        local preset_str, check_str = string.match(ctrl_name, "^check_(%d)_(%d)$")
        g.easy_buff_settings.food_presets_check[preset_str][check_str] = is_check
    end
    Easy_buff_save_settings()
    Easy_buff_config_frame()
end
-- メシ屋
function Easy_buff_OPEN_FOOD_TABLE_UI(my_frame, my_msg)
    if g.settings.easy_buff.use == 0 then
        return
    end
    local group_name, sell_type, handle, seller_cid, shared = g.get_event_args(my_msg)
    local foodtable_ui = ui.GetFrame("foodtable_ui")
    local actor = world.GetActor(handle)
    local apc = actor:GetPCApc()
    local aid = apc:GetAID()
    local info = session.party.GetPartyMemberInfoByAID(PARTY_GUILD, aid)
    if not info and shared == 1 then
        local msg = g.lang == "Japanese" and "ギルドメンバーのみに食事提供のお店です" or
                        "This shop provides food exclusively to guild members"
        ui.SysMsg(msg)
        foodtable_ui:ShowWindow(0)
        return
    end
    local x = 300
    local y = 60
    local btn
    for i = 1, 4 do
        local str_i = tostring(i)
        btn = foodtable_ui:CreateOrGetControl("button", "btn" .. i, x, y, 85, 30)
        AUTO_CAST(btn)
        btn:SetSkinName(i == g.easy_buff_settings.food_check and "test_red_button" or "test_gray_button")
        local text = g.easy_buff_settings.food_presets_name[str_i] or "{ol}preset " .. i
        btn:SetText("{ol}" .. text)
        btn:SetEventScript(ui.LBUTTONUP, "Easy_buff_clear_food_buff_timer")
        if btn:GetWidth() >= 85 then
            btn:Resize(85, 30)
        end
        if i == 1 then
            x = x + 80
        elseif i == 2 then
            x = 300
            y = 90
        elseif i == 3 then
            x = x + 80
        end
    end
    if g.easy_buff_settings.food_check ~= 0 and g.easy_buff_first then
        Easy_buff_clear_food_buff_timer(nil, btn)
        g.easy_buff_first = false
    end
end

function Easy_buff_clear_food_buff_timer(frame, btn)
    btn:RunUpdateScript("Easy_buff_clear_food_buff", 0.1)
end

function Easy_buff_clear_food_buff(btn)
    local food_buffs = {4021, 4022, 4023, 4024, 4087, 4136}
    local my_handle = session.GetMyHandle()
    for _, buff_id in ipairs(food_buffs) do
        local buff = info.GetBuff(my_handle, buff_id)
        if buff then
            packet.ReqRemoveBuff(buff_id)
            return 1
        end
    end
    btn:StopUpdateScript("Easy_buff_clear_food_buff")
    Easy_buff_set_food_buff(btn)
    return 0
end

function Easy_buff_set_food_buff(btn)
    local preset_index_str
    if g.easy_buff_settings.food_check ~= 0 then
        preset_index_str = tostring(g.easy_buff_settings.food_check)
    elseif btn then
        preset_index_str = string.sub(btn:GetName(), -1)
    else
        return
    end
    g.easy_buff_temp_food = {}
    for key, value in pairs(g.easy_buff_settings.food_presets_check[preset_index_str]) do
        if value == 1 then
            local num_key = tonumber(key)
            if num_key then
                table.insert(g.easy_buff_temp_food, num_key - 1)
            end
        end
    end
    table.sort(g.easy_buff_temp_food, function(a, b)
        return a > b
    end)
    if #g.easy_buff_temp_food > 0 then
        Easy_buff_eat_food(btn)
        btn:RunUpdateScript("Easy_buff_eat_food", 0.6)
    end
end

function Easy_buff_eat_food(btn)
    local foodtable_ui = ui.GetFrame("foodtable_ui")
    if foodtable_ui:IsVisible() == 0 then
        g.easy_buff_first = true
        return 0
    end
    local handle = foodtable_ui:GetUserIValue("HANDLE")
    local sell_type = foodtable_ui:GetUserIValue("SELLTYPE")
    if #g.easy_buff_temp_food > 0 then
        session.autoSeller.Buy(handle, g.easy_buff_temp_food[#g.easy_buff_temp_food], 1, sell_type)
        table.remove(g.easy_buff_temp_food, #g.easy_buff_temp_food)
        imcSound.PlaySoundEvent('system_craft_potion_succes')
        return 1
    else
        g.easy_buff_first = true
        foodtable_ui:ShowWindow(0)
        return 0
    end
end
-- バフ屋
function Easy_buff_TARGET_BUFF_AUTOSELL_LIST(my_frame, my_msg)
    if g.settings.easy_buff.use == 0 then
        return
    end
    local group_name, sell_type, handle = g.get_event_args(my_msg)
    if sell_type ~= 0 then
        return
    end
    local buffseller_target = ui.GetFrame("buffseller_target")
    if buffseller_target:HaveUpdateScript("Easy_buff_buy_buffs_update") == true or
        buffseller_target:HaveUpdateScript("Easy_buff_end_process") == true then
        return
    end
    local item_count = session.autoSeller.GetCount(group_name)
    for i = 0, item_count - 1 do
        local item_info = session.autoSeller.GetByIndex(group_name, i)
        if not item_info then
            ui.SysMsg(g.lang == "Japanese" and "お店のバフアイテムが足りません" or
                          "Insufficient buff items at the shop")
            return
        end
    end
    local my_handle = session.GetMyHandle()
    local buff_ids_to_check = {358, 359, 360, 370}
    local needs_rebuff = false
    for _, buff_id in ipairs(buff_ids_to_check) do
        local buff = info.GetBuff(my_handle, buff_id)
        -- バフが無い、または残り時間が60分以下なら購入対象
        if not buff then
            needs_rebuff = true
            break
        end
        if buff.time <= 3600000 then -- 60分 (ms)
            needs_rebuff = true
            break
        end
    end
    if needs_rebuff then
        Easy_buff_buy_buffs(handle)
        return
    else
        if g.easy_buff_settings.confirm_check == 1 then
            local msg_text = g.lang == "Japanese" and "{#FFFFFF}{ol}バフをかけ直しますか？" or
                                 "{#FFFFFF}{ol}Do you want to reapply the buff?"
            local yes_script = string.format("Easy_buff_buy_buffs(%d)", handle)
            local no_script = "Easy_buff_end_process()"
            ui.MsgBox(msg_text, yes_script, no_script)
        else
            Easy_buff_buy_buffs(handle)
            return
        end
    end
end

function Easy_buff_buy_buffs(handle)
    local buffseller_target = ui.GetFrame("buffseller_target")
    buffseller_target:SetUserValue("HANDLE", handle)
    buffseller_target:SetUserValue("BUFF_INDEX", 0)
    buffseller_target:SetUserValue("RETRY_COUNT", 0)
    buffseller_target:RunUpdateScript("Easy_buff_buy_buffs_update", 0.6)
end

function Easy_buff_buy_buffs_update(buffseller_target)
    local buff_index = buffseller_target:GetUserIValue("BUFF_INDEX")
    if buff_index <= 3 then
        local handle = buffseller_target:GetUserIValue("HANDLE")
        session.autoSeller.Buy(handle, buff_index, 1, 0)
        buffseller_target:SetUserValue("BUFF_INDEX", buff_index + 1)
        return 1
    else
        buffseller_target:RunUpdateScript("Easy_buff_end_process", 0.6)
        return 0
    end
end

function Easy_buff_end_process(buffseller_target)
    if not buffseller_target then
        buffseller_target = ui.GetFrame("buffseller_target")
    end
    local my_handle = session.GetMyHandle()
    local buff_check = {358, 359, 360, 370}
    local retry_count = buffseller_target:GetUserIValue("RETRY_COUNT")
    for i, buff_id in ipairs(buff_check) do
        local buff = info.GetBuff(my_handle, buff_id)
        if not buff or buff.time <= 3540000 then
            if retry_count < 3 then
                local handle = buffseller_target:GetUserIValue("HANDLE")
                session.autoSeller.Buy(handle, i - 1, 1, 0)
                buffseller_target:SetUserValue("RETRY_COUNT", retry_count + 1)
                return 1 -- 再チェックへ
            else
                ui.SysMsg(g.lang == "Japanese" and "バフの購入に失敗しました" or "Failed to purchase buff")
                break
            end
        end
    end
    buffseller_target:ShowWindow(0)
    return 0
end
-- 修理
function Easy_buff_ITEMBUFF_REPAIR_UI_COMMON(my_frame, my_msg)
    if g.settings.easy_buff.use == 0 then
        return
    end
    local itembuffrepair = ui.GetFrame("itembuffrepair")
    session.ResetItemList()
    local handle = itembuffrepair:GetUserValue("HANDLE")
    local skill_name = itembuffrepair:GetUserValue("SKILLNAME")
    local slot_set = GET_CHILD_RECURSIVELY(itembuffrepair, "slotlist", "ui::CSlotSet")
    local slot_count = slot_set:GetSlotCount()
    local cheapest = nil
    local price = 0
    local iesid = ""
    for i = 0, slot_count - 1 do
        local slot = slot_set:GetSlotByIndex(i)
        if slot:GetIcon() then
            local icon = slot:GetIcon()
            local icon_info = icon:GetInfo()
            local inv_item = GET_ITEM_BY_GUID(icon_info:GetIESID())
            if inv_item then
                local item_obj = GetIES(inv_item:GetObject())
                local need_item, need_count = ITEMBUFF_NEEDITEM_Squire_Repair(GetMyPCObject(), item_obj)
                if need_count < price or price == 0 then
                    cheapest = slot
                    price = need_count
                    iesid = icon_info:GetIESID()
                end
            end
        end
    end
    if cheapest then
        session.AddItemID(iesid)
        local auto_sell_index = 2 -- 元コードのAUTO_SELL_SQUIRE_BUFFが2
        session.autoSeller.BuyItems(handle, auto_sell_index, session.GetItemIDList(), skill_name)
        imcSound.PlaySoundEvent('system_craft_potion_succes')
    end
    itembuffrepair:RunUpdateScript("Easy_buff_repair_msg", 1.5)
end

function Easy_buff_repair_msg(itembuffrepair)
    local repair_buffs = {3127, 3128, 3129} -- 3127魔法 3128機敏 3129防御
    local my_handle = session.GetMyHandle()
    for _, buff_id in ipairs(repair_buffs) do
        local buff = info.GetBuff(my_handle, buff_id)
        if buff then
            local format_string
            if g.lang == "Japanese" then
                format_string = "%s バフを有効化"
            else
                format_string = "%s Activate Buff"
            end
            local buff_cls = GetClassByType("Buff", buff_id)
            local msg = string.format(format_string, buff_cls.Name)
            imcAddOn.BroadMsg("NOTICE_Dm_Bell", msg, 2.5)
            CHAT_SYSTEM(msg)
        end
    end
    if g.easy_buff_settings.repair_check == 1 then
        itembuffrepair:ShowWindow(0)
        local inventory = ui.GetFrame("inventory")
        if inventory:IsVisible() == 1 then
            ui.ToggleFrame('inventory')
        end
    end
end
-- メンテ処理
function Easy_buff_SQUIRE_BUFF_EQUIP_CTRL(my_frame, my_msg)
    if g.settings.easy_buff.use == 0 then
        return
    end
    local itembuffopen = ui.GetFrame("itembuffopen")
    itembuffopen:StopUpdateScript("Easy_buff_squire_frame_close")
    itembuffopen:RunUpdateScript("Easy_buff_squire_buff_equip_ctrl_update", 0.5)
    return
end

function Easy_buff_squire_buff_equip_ctrl_update(itembuffopen)
    if session.GetMyHandle() == itembuffopen:GetUserIValue("HANDLE") then
        return
    end
    local close = GET_CHILD_RECURSIVELY(itembuffopen, 'close')
    AUTO_CAST(close)
    close:SetEventScript(ui.LBUTTONUP, "Easy_buff_squire_timestop_frame_close")
    local checkall = GET_CHILD_RECURSIVELY(itembuffopen, 'checkall')
    AUTO_CAST(checkall)
    checkall:SetCheck(1)
    SQUIRE_BUFF_EQUIP_SELECT_ALL(itembuffopen, checkall)
    local btn_excute = GET_CHILD_RECURSIVELY(itembuffopen, "btn_excute")
    SQUIRE_BUFF_EXCUTE(itembuffopen, btn_excute)
    local str = g.lang == "Japanese" and
                    "{ol}装備メンテナンス自動付与中{nl}フレームを閉じればキャンセルします" or
                    "{ol}Equipment maintenance automatic grant is in progress{nl}Canceled when frame is closed"
    ui.SysMsg(str)
    itembuffopen:StopUpdateScript("Easy_buff_squire_buff_equip_ctrl_update")
    itembuffopen:RunUpdateScript("Easy_buff_squire_frame_close", 5.5)
end

function Easy_buff_squire_timestop_frame_close()
    packet.StopTimeAction(1)
    ui.CloseFrame("itembuffopen")
end

function Easy_buff_squire_frame_close(itembuffopen)
    itembuffopen:ShowWindow(0)
    return 0
end
-- easy_buff ここまで

