-- monster_card_changer ここから
function Monster_card_changer_save_settings()
    g.save_json(g.monster_card_changer_path, g.monster_card_changer_settings)
end

function Monster_card_changer_load_settings()
    g.monster_card_changer_path = string.format("../addons/%s/%s/monster_card_changer.json", addon_name_lower,
        g.active_id)
    local settings = g.load_json(g.monster_card_changer_path)
    if not settings then
        settings = {
            presets = {}
        }
    end
    local changed = false
    for i = 1, 10 do
        if not settings.presets[i] then
            local title = ScpArgMsg('CardPresetNumber{index}', 'index', i)
            settings.presets[i] = {
                name = title,
                slots = {}
            }
            changed = true
        end
        if not settings.presets[i].slots or #settings.presets[i].slots < 12 then
            local slots = settings.presets[i].slots or {}
            for j = 1, 12 do
                if not slots[j] then
                    slots[j] = {
                        card_id = 0,
                        card_exp = 0,
                        card_lv = 0
                    }
                end
            end
            settings.presets[i].slots = slots
            changed = true
        end
    end
    g.monster_card_changer_settings = settings
    if changed then
        Monster_card_changer_save_settings()
    end
end

function monster_card_changer_on_init()
    if not g.monster_card_changer_settings then
        Monster_card_changer_load_settings()
    end
    local old_func = g.settings.monster_card_changer.old_init_func
    if _G[old_func] then
        return
    end
    if g.settings.monster_card_changer.use == 0 then
        Monster_card_changer_not_use()
        return
    end
    if g.get_map_type() == "City" then
        Monster_card_changer_inventory_frame_init()
        g.setup_hook_and_event(g.addon, "CARD_PRESET_CHANGE_NAME_EXEC",
            "Monster_card_changer_CARD_PRESET_CHANGE_NAME_EXEC", false)
    end
end

function Monster_card_changer_not_use()
    local inventory = ui.GetFrame('inventory')
    local mcc = GET_CHILD(inventory, "mcc")
    if mcc then
        DESTROY_CHILD_BYNAME(inventory, "mcc")
    end
    local monster_card_changer = ui.GetFrame(addon_name_lower .. "monster_card_changer")
    if monster_card_changer then
        ui.DestroyFrame(monster_card_changer:GetName())
    end
    local monstercardslot = ui.GetFrame("monstercardslot")
    local applyBtn = GET_CHILD(monstercardslot, "applyBtn")
    if applyBtn then
        applyBtn:SetEventScript(ui.LBUTTONUP, "MONSTERCARDPRESET_FRAME_OPEN")
    end
    local monstercardpreset = ui.GetFrame('monstercardpreset')
    local preset_list = GET_CHILD_RECURSIVELY(monstercardpreset, "preset_list")
    preset_list:ShowWindow(1)
    local saveBtn = GET_CHILD_RECURSIVELY(monstercardpreset, "saveBtn")
    saveBtn:ShowWindow(1)
    local applyBtn = GET_CHILD_RECURSIVELY(monstercardpreset, "applyBtn")
    applyBtn:ShowWindow(1)
    local drop_list = GET_CHILD(monstercardpreset, 'drop_list')
    if drop_list then
        monstercardpreset:RemoveChild("drop_list")
    end
    local save_btn = GET_CHILD(monstercardpreset, 'save_btn')
    if save_btn then
        monstercardpreset:RemoveChild("save_btn")
    end
    local unequip = GET_CHILD(monstercardpreset, 'unequip')
    if unequip then
        monstercardpreset:RemoveChild("unequip")
    end
    local equip = GET_CHILD(monstercardpreset, 'equip')
    if equip then
        monstercardpreset:RemoveChild("equip")
    end
    local monstercardslot = ui.GetFrame('monstercardslot')
    local card_colors = {"red", "blue", "purple", "green"}
    for _, color in ipairs(card_colors) do
        local check_box = GET_CHILD(monstercardslot, color)
        if check_box then
            monstercardslot:RemoveChild(color)
        end
    end
end

function Monster_card_changer_CARD_PRESET_CHANGE_NAME_EXEC(my_frame, my_msg)
    local input_frame, ctrl = g.get_event_args(my_msg)
    if g.settings.monster_card_changer.use == 0 then
        g.FUNCS["CARD_PRESET_CHANGE_NAME_EXEC"](input_frame, ctrl)
        return
    end
    local new_name = GET_INPUT_STRING_TXT(input_frame)
    local name_str = TRIM_STRING_WITH_SPACING(new_name)
    if name_str == '' then
        ui.SysMsg(ClMsg('InvalidStringOrUnderMinLen'))
        return
    end
    local monstercardpreset = ui.GetFrame('monstercardpreset')
    local drop_list = GET_CHILD(monstercardpreset, 'drop_list')
    AUTO_CAST(drop_list)
    local page = tonumber(drop_list:GetSelItemKey())
    g.monster_card_changer_settings.presets[page + 1].name = name_str
    Monster_card_changer_save_settings()
    _DISABLE_CARD_PRESET_CHANGE_NAME_BTN()
    input_frame:ShowWindow(0)
    local monster_card_changer = ui.GetFrame(addon_name_lower .. "monster_card_changer")
    AUTO_CAST(monster_card_changer)
    monster_card_changer:SetUserValue("PAGE", page)
    Monster_card_changer_preset_open(monster_card_changer)
end

function Monster_card_changer_inventory_frame_init()
    local inventory = ui.GetFrame('inventory')
    local mcc = inventory:CreateOrGetControl("button", "mcc", 3, 345, 30, 30)
    AUTO_CAST(mcc)
    mcc:SetSkinName("test_red_button")
    mcc:SetTextAlign("right", "center")
    mcc:SetText("{img monsterbtn_image 28 23}{/}")
    mcc:SetTextTooltip(g.lang == "Japanese" and "{ol}カード自動搬出入、自動着脱{/}" or
                           "{ol}Automatic card loading/unloading, automatic insertion/removal{nl}")
    mcc:SetEventScript(ui.LBUTTONUP, "Monster_card_changer_monstercardpreset_open")
    local monstercardslot = ui.GetFrame("monstercardslot")
    local applyBtn = GET_CHILD(monstercardslot, "applyBtn")
    AUTO_CAST(applyBtn)
    applyBtn:SetEventScript(ui.LBUTTONUP, "Monster_card_changer_monstercardpreset_open")
end

function Monster_card_changer_monstercardpreset_open(is_cc_helper)
    local monstercardpreset = ui.GetFrame('monstercardpreset')
    if monstercardpreset:IsVisible() == 1 and is_cc_helper ~= 1 then
        MONSTERCARDSLOT_CLOSE()
        return
    end
    MONSTERCARDSLOT_FRAME_OPEN()
    local preset_list = GET_CHILD_RECURSIVELY(monstercardpreset, "preset_list")
    AUTO_CAST(preset_list)
    preset_list:SelectItemByKey(4)
    local monster_card_changer = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "monster_card_changer", 0, 0, 0,
        0)
    AUTO_CAST(monster_card_changer)
    monster_card_changer:SetSkinName("None")
    monster_card_changer:SetVisible(1)
    Monster_card_changer_preset_open(monster_card_changer)
end

function Monster_card_changer_preset_open(monster_card_changer)
    local monstercardpreset = ui.GetFrame('monstercardpreset')
    CARD_PRESET_CLEAR_SLOT(monstercardpreset)
    local preset_list = GET_CHILD_RECURSIVELY(monstercardpreset, "preset_list")
    AUTO_CAST(preset_list)
    preset_list:SelectItemByKey(4)
    SetCardPreset(4, {}, {})
    monstercardpreset:RemoveChild("drop_list")
    local drop_list = monstercardpreset:CreateOrGetControl('droplist', 'drop_list', 45, 66, 178, 20)
    AUTO_CAST(drop_list)
    drop_list:SetSkinName('droplist_normal')
    drop_list:EnableHitTest(1)
    drop_list:SetTextAlign("center", "center")
    for i, preset_data in ipairs(g.monster_card_changer_settings.presets) do
        local preset_name = "{ol}" .. preset_data.name
        local scp = string.format("Monster_card_changer_select_preset(%d)", i - 1)
        drop_list:AddItem(i - 1, preset_name, 0, scp)
    end
    local item_num = monster_card_changer:GetUserIValue("PAGE")
    drop_list:SelectItem(item_num)
    preset_list:ShowWindow(0)
    local saveBtn = GET_CHILD_RECURSIVELY(monstercardpreset, "saveBtn")
    saveBtn:ShowWindow(0)
    local save_btn = monstercardpreset:CreateOrGetControl("button", "save_btn", 340, 57, 70, 38)
    AUTO_CAST(save_btn)
    save_btn:SetText("{@st66b}SAVE")
    save_btn:SetSkinName("test_pvp_btn")
    save_btn:SetTextTooltip(g.lang == "Japanese" and
                                "{ol}現在装備中のカード情報を、現在のプリセットに呼び出します" or
                                "{ol}Load currently equipped card information{nl}into the current preset")
    save_btn:SetEventScript(ui.LBUTTONUP, "Monster_card_changer_msgbox")
    local unequip = monstercardpreset:CreateOrGetControl("button", "unequip", 480, 57, 70, 38)
    AUTO_CAST(unequip)
    unequip:SetText("{@st66b}REMOVE")
    unequip:SetSkinName("test_pvp_btn")
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    if accountwarehouse:IsVisible() == 1 then
        unequip:SetTextTooltip(g.lang == "Japanese" and
                                   "{ol}現在装備中のカードを取り外し、倉庫へ搬入します" or
                                   "{ol}Unequip currently equipped cards{nl}and transfer them to the warehouse")
    else
        unequip:SetTextTooltip(g.lang == "Japanese" and "{ol}現在装備中のカードを取り外します" or
                                   "{ol}Unequip currently equipped cards")
    end
    unequip:SetEventScript(ui.LBUTTONUP, "Monster_card_changer_remove")
    local applyBtn = GET_CHILD_RECURSIVELY(monstercardpreset, "applyBtn")
    applyBtn:ShowWindow(0)
    local equip = monstercardpreset:CreateOrGetControl("button", "equip", 410, 57, 70, 38)
    AUTO_CAST(equip)
    equip:SetText("{@st66b}EQUIP")
    equip:SetSkinName("test_pvp_btn")
    equip:SetTextTooltip(
        g.lang == "Japanese" and "{ol}現在のプリセットへ、装備カードを変更します" or
            "{ol}Change equipped cards to the current preset")
    equip:SetEventScript(ui.LBUTTONUP, "Monster_card_changer_equip_get_presetinfo")
    local monstercardslot = ui.GetFrame('monstercardslot')
    local mcc_settings = g.monster_card_changer_settings
    if not mcc_settings[g.login_name] then
        mcc_settings[g.login_name] = {}
    end
    local card_colors = {{
        name = "red",
        x = 50,
        y = 70
    }, {
        name = "blue",
        x = 365,
        y = 70
    }, {
        name = "purple",
        x = 50,
        y = 210
    }, {
        name = "green",
        x = 365,
        y = 210
    }}
    for _, color_info in ipairs(card_colors) do
        local color_name = color_info.name
        if not mcc_settings[g.login_name][color_name] then
            mcc_settings[g.login_name][color_name] = 0
        end
        local checkbox = monstercardslot:CreateOrGetControl('checkbox', color_name, color_info.x, color_info.y, 25, 25)
        AUTO_CAST(checkbox)
        checkbox:SetEventScript(ui.LBUTTONUP, "Monster_card_changer_color_save")
        checkbox:SetEventScriptArgString(ui.LBUTTONUP, color_name)
        checkbox:SetCheck(mcc_settings[g.login_name][color_name])
        checkbox:SetTextTooltip(g.lang == "Japanese" and
                                    "{ol}チェックを入れると該当の色のカードを外しません" or
                                    "{ol}checked, cards of the specified color will not be unequipped")
    end
    Monster_card_changer_save_settings()
    monster_card_changer:RunUpdateScript("Monster_card_changer_preset_card_set", 1.0)
    return 0
end

function Monster_card_changer_preset_card_set(monster_card_changer)
    local card_list = {}
    local exp_list = {}
    local monstercardpreset = ui.GetFrame("monstercardpreset")
    monstercardpreset:ShowWindow(1)
    local drop_list = GET_CHILD(monstercardpreset, "drop_list")
    local page = tonumber(drop_list:GetSelItemKey())
    local preset_data = g.monster_card_changer_settings.presets[page + 1].slots
    if not preset_data then
        return 0
    end
    for i, slot_data in ipairs(preset_data) do
        local card_id = slot_data.card_id
        if card_id and card_id ~= 0 then
            local card_exp = slot_data.card_exp or 0
            local card_lv = slot_data.card_lv or 0
            table.insert(card_list, card_id)
            table.insert(exp_list, card_exp)
        end
    end
    SetCardPreset(0, card_list, exp_list)
    MONSTERCARDPRESET_FRAME_OPEN()
    g.monster_card_changer_ready = 1
    return 0
end

function Monster_card_changer_select_preset(page)
    local monster_card_changer = ui.GetFrame(addon_name_lower .. "monster_card_changer")
    AUTO_CAST(monster_card_changer)
    monster_card_changer:SetUserValue("PAGE", page)
    monster_card_changer:RunUpdateScript("Monster_card_changer_preset_card_set", 1.0)
end

function Monster_card_changer_msgbox()
    local msg = g.lang == "Japanese" and
                    "現在装備中のカード情報を、プリセットに登録しますか？" or
                    "Do you want to save the currently equipped cards to the preset?"
    local yes_scp = string.format("Monster_card_changer_save_preset()")
    ui.MsgBox(msg, yes_scp, "None")
end

function Monster_card_changer_save_preset()
    local monstercardslot = ui.GetFrame("monstercardslot")
    local monstercardpreset = ui.GetFrame("monstercardpreset")
    local drop_list = GET_CHILD(monstercardpreset, "drop_list")
    local page = tonumber(drop_list:GetSelItemKey())
    if not g.monster_card_changer_settings.presets[page + 1] then
        return
    end
    local slots_settings = g.monster_card_changer_settings.presets[page + 1].slots
    for i = 1, 12 do
        local card_id, card_lv, card_exp = GETMYCARD_INFO(i - 1)
        if slots_settings[i] then
            slots_settings[i].card_id = card_id
            slots_settings[i].card_exp = card_exp
            slots_settings[i].card_lv = card_lv
        end
        _CARD_PRESET_SLOT_EQUIP(i, card_id, card_lv, card_exp)
    end
    Monster_card_changer_save_settings()
end

function Monster_card_changer_color_save(monstercardslot, checkbox, check_name)
    local is_check = checkbox:IsChecked()
    g.monster_card_changer_settings[g.login_name][check_name] = is_check
    Monster_card_changer_save_settings()
end

function Monster_card_changer_remove(monstercardpreset)
    g.monster_card_changer_cardlist = {}
    local mcc_settings = g.monster_card_changer_settings[g.login_name]
    local slot_to_color = {"red", "red", "red", "blue", "blue", "blue", "purple", "purple", "purple", "green", "green",
                           "green"}
    for i = 1, 12 do
        local group_name = CARD_SLOT_GET_GROUP_NAME(i - 1)
        local card_cls_id, card_lv, card_exp = GETMYCARD_INFO(i - 1)
        local color = slot_to_color[i]
        if color and mcc_settings[color] ~= 1 and card_cls_id ~= 0 then
            table.insert(g.monster_card_changer_cardlist, {card_cls_id, card_lv, group_name, nil})
        end
    end
    local preset_list = GET_CHILD_RECURSIVELY(monstercardpreset, "preset_list")
    AUTO_CAST(preset_list)
    local monster_card_changer = ui.GetFrame(addon_name_lower .. "monster_card_changer")
    AUTO_CAST(monster_card_changer)
    local page = tonumber(preset_list:GetSelItemKey())
    monster_card_changer:SetUserValue("PAGE", page)
    preset_list:SelectItemByKey(4)
    local page = 4
    pc.ReqExecuteTx_NumArgs("SCR_TX_APPLY_CARD_PRESET", page)
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    if accountwarehouse:IsVisible() == 1 then
        local monster_card_changer = ui.GetFrame(addon_name_lower .. "monster_card_changer")
        AUTO_CAST(monster_card_changer)
        monster_card_changer:RunUpdateScript("Monster_card_changer_get_guid", 1.0)
    end
end

function Monster_card_changer_get_guid(monster_card_changer)
    local msg = g.lang == "Japanese" and
                    "{ol}{#CCCC22}[MCC]動作中。バグ防止の為他の動作は行わないでください" or
                    "{ol}{#CCCC22}[MCC]Operating. Please do not perform other operations to prevent bugs"
    imcAddOn.BroadMsg("NOTICE_Dm_Bell", msg, 2.5)
    local inventory = ui.GetFrame("inventory")
    local inventype_Tab = GET_CHILD_RECURSIVELY(inventory, "inventype_Tab")
    inventype_Tab:SelectTab(4)
    local inv_item_list = session.GetInvItemList()
    local guid_list = inv_item_list:GetGuidList()
    local cnt = guid_list:Count()
    g.monster_card_changer_group_counts = {
        ATK = 0,
        DEF = 0,
        UTIL = 0,
        STAT = 0
    }
    for i = 0, cnt - 1 do
        local guid = guid_list:Get(i)
        local inv_item = inv_item_list:GetItemByGuid(guid)
        local item_obj = GetIES(inv_item:GetObject())
        local item_lv = TryGetProp(item_obj, "Level", 0)
        for i, data in ipairs(g.monster_card_changer_cardlist) do
            if not data[4] then
                local cls_id = data[1]
                local card_lv = data[2]
                local group_name = data[3]
                if item_obj.ClassID == cls_id and card_lv == item_lv then
                    if g.monster_card_changer_group_counts[group_name] < 3 then
                        g.monster_card_changer_group_counts[group_name] =
                            g.monster_card_changer_group_counts[group_name] + 1
                        data[4] = guid
                        break
                    end
                end
            end
        end
    end
    local take = monster_card_changer:GetUserValue("TAKE")
    if take ~= "take" then
        monster_card_changer:RunUpdateScript("Monster_card_changer_put_inv_to_warehouse", 0.1)
        return 0
    else
        return g.monster_card_changer_cardlist
    end
end

function Monster_card_changer_put_inv_to_warehouse(monster_card_changer)
    if #g.monster_card_changer_cardlist == 0 then
        Monster_card_changer_end_of_operation(monster_card_changer)
        return 0
    end
    local data = g.monster_card_changer_cardlist[1]
    local guid = data[4]
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    local inventory = ui.GetFrame("inventory")
    if accountwarehouse:IsVisible() ~= 1 and inventory:IsVisible() ~= 1 then
        return 0
    end
    local inv_item = session.GetInvItemList():GetItemByGuid(guid)
    if inv_item then
        item.PutItemToWarehouse(IT_ACCOUNT_WAREHOUSE, guid, 1, accountwarehouse:GetUserIValue("HANDLE"), nil)
    else
        table.remove(g.monster_card_changer_cardlist, 1)
    end
    return 1
end

function Monster_card_changer_equip_get_presetinfo()
    g.monster_card_changer_cardlist = {}
    local mcc_settings = g.monster_card_changer_settings[g.login_name]
    local slot_to_color = {"red", "red", "red", "blue", "blue", "blue", "purple", "purple", "purple", "green", "green",
                           "green"}
    for i = 0, 11 do
        local group_name = CARD_SLOT_GET_GROUP_NAME(i)
        local card_id, card_lv, card_exp = _GETMYCARD_INFO(i)
        local color = slot_to_color[i + 1]
        if mcc_settings[color] == 0 and card_id ~= 0 then
            table.insert(g.monster_card_changer_cardlist, {card_id, card_lv, group_name, nil})
        end
    end
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    if accountwarehouse:IsVisible() == 1 then
        Monster_card_changer_warehouse(accountwarehouse)
    else
        local monster_card_changer = ui.GetFrame(addon_name_lower .. "monster_card_changer")
        Monster_card_changer_apply_card_preset(monster_card_changer)
    end
end

function Monster_card_changer_warehouse(accountwarehouse)
    local monster_card_changer = ui.GetFrame(addon_name_lower .. "monster_card_changer")
    AUTO_CAST(monster_card_changer)
    monster_card_changer:SetUserValue("TAKE", "take")
    g.monster_card_changer_cardlist = Monster_card_changer_get_guid(monster_card_changer)
    local item_list = session.GetEtcItemList(IT_ACCOUNT_WAREHOUSE)
    local guid_list = item_list:GetGuidList()
    local cnt = guid_list:Count()
    local take_list = {}
    for i = 0, cnt - 1 do
        local guid = guid_list:Get(i)
        local acw_item = item_list:GetItemByGuid(guid)
        local type = acw_item.type
        local item_obj = GetIES(acw_item:GetObject())
        local item_lv = TryGetProp(item_obj, "Level", 0)
        local group_counts = {
            ATK = 0,
            DEF = 0,
            UTIL = 0,
            STAT = 0
        }
        for i, data in ipairs(g.monster_card_changer_cardlist) do
            if not data[4] then
                local cls_id = data[1]
                local card_lv = data[2]
                local group_name = data[3]
                if type == cls_id and card_lv == item_lv then
                    if g.monster_card_changer_group_counts[group_name] < 3 then
                        g.monster_card_changer_group_counts[group_name] =
                            g.monster_card_changer_group_counts[group_name] + 1
                        data[4] = guid
                        take_list[guid] = 1
                        break
                    end
                end
            end
        end
    end
    session.ResetItemList()
    for guid, count in pairs(take_list) do
        session.AddItemID(tonumber(guid), count)
    end
    item.TakeItemFromWarehouse_List(IT_ACCOUNT_WAREHOUSE, session.GetItemIDList(),
        accountwarehouse:GetUserIValue("HANDLE"))
    monster_card_changer:RunUpdateScript("Monster_card_changer_apply_card_preset", 1.0)
end

function Monster_card_changer_apply_card_preset(monster_card_changer)
    pc.ReqExecuteTx_NumArgs("SCR_TX_APPLY_CARD_PRESET", 0)
    Monster_card_changer_end_of_operation(monster_card_changer)
end

function Monster_card_changer_end_of_operation(monster_card_changer)
    g.monster_card_changer_ready = 3
    if not monster_card_changer then
        monster_card_changer = ui.GetFrame(addon_name_lower .. "monster_card_changer")
    end
    if not monster_card_changer then
        return
    end
    local take = monster_card_changer:GetUserValue("TAKE")
    monster_card_changer:SetUserValue("TAKE", "None")
    g.monster_card_changer_cardlist = nil
    ui.SysMsg("[MCC]End of Operation")
    monster_card_changer:RunUpdateScript("Monster_card_changer_preset_card_set", 1.0)
    monster_card_changer:RunUpdateScript("MONSTERCARDPRESET_FRAME_CLOSE", 3.0)
    monster_card_changer:RunUpdateScript("MONSTERCARDSLOT_CLOSE", 3.0)
end
-- monster_card_changer ここまで

