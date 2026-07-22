-- continue_reinforce ここから
g.continue_reinforce = {
    use = true,
    rf_count = 0,
    limit_clear = false,
    is_first = false,
    delay = 0.1,
    count = 0,
    premium_mat = false,
    normal_mat = false,
    inv_tbl = {}
}
function continue_reinforce_on_init()
    if g.settings.continue_reinforce.use == 0 then
        return
    end
    g.setup_hook_and_event(g.addon, "GODDESS_MGR_TAB_CHANGE", "Continue_reinforce_GODDESS_MGR_TAB_CHANGE", true)
    g.setup_hook_and_event(g.addon, "GODDESS_EQUIP_MANAGER_OPEN", "Continue_reinforce_GODDESS_EQUIP_MANAGER_OPEN", true)
    g.setup_hook_and_event(g.addon, "GODDESS_MGR_REFORGE_REG_ITEM", "Continue_reinforce_GODDESS_MGR_REFORGE_REG_ITEM",
        true)
    g.setup_hook_and_event(g.addon, "_END_REFORGE_REINFORCE_EXEC", "Continue_reinforce__END_REFORGE_REINFORCE_EXEC",
        true)
    g.setup_hook_and_event(g.addon, "GODDESS_MGR_REFORGE_ITEM_REMOVE",
        "Continue_reinforce_GODDESS_MGR_REFORGE_ITEM_REMOVE", true)
    g.setup_hook_and_event(g.addon, "GODDESS_MGR_REFORGE_TAB_CHANGE",
        "Continue_reinforce_GODDESS_MGR_REFORGE_TAB_CHANGE", true)
end

function Continue_reinforce_GODDESS_MGR_TAB_CHANGE()
    local goddess_equip_manager = ui.GetFrame('goddess_equip_manager')
    local main_tab = GET_CHILD_RECURSIVELY(goddess_equip_manager, 'main_tab')
    local tab_index = main_tab:GetSelectItemIndex()
    if tab_index == 0 then
        Continue_reinforce_GODDESS_EQUIP_MANAGER_OPEN()
    else
        goddess_equip_manager:RemoveChild("gbox")
    end
end

function Continue_reinforce_GODDESS_EQUIP_MANAGER_OPEN()
    local goddess_equip_manager = ui.GetFrame('goddess_equip_manager')
    local reinf_left_bg = GET_CHILD_RECURSIVELY(goddess_equip_manager, 'reinf_left_bg')
    local reinf_no_msgbox = GET_CHILD_RECURSIVELY(reinf_left_bg, 'reinf_no_msgbox')
    AUTO_CAST(reinf_no_msgbox)
    if g.continue_reinforce.use and g.settings.continue_reinforce.use == 1 then
        reinf_no_msgbox:SetCheck(1)
        reinf_no_msgbox:SetMargin(-30, 0, 0, 110)
    else
        reinf_no_msgbox:SetCheck(0)
        reinf_no_msgbox:SetMargin(0, 0, 0, 110)
    end
    local ref_ok_reinforce = GET_CHILD_RECURSIVELY(goddess_equip_manager, 'ref_ok_reinforce')
    AUTO_CAST(ref_ok_reinforce)
    ref_ok_reinforce:SetSkinName("baseyellow_btn")
    if g.continue_reinforce.use and g.settings.continue_reinforce.use == 1 then
        ref_ok_reinforce:Resize(100, 70)
        local ref_ok_text = ref_ok_reinforce:GetTextByKey("value")
        ref_ok_reinforce:SetText(ref_ok_text)
        local rect = ref_ok_reinforce:GetMargin()
        ref_ok_reinforce:SetPos(-30, rect.bottom)
    else
        ref_ok_reinforce:Resize(160, 70)
        local ref_do_text = ref_ok_reinforce:GetTextByKey("value")
        ref_ok_reinforce:SetText(ref_do_text)
        local rect = ref_ok_reinforce:GetMargin()
        ref_ok_reinforce:SetPos(0, rect.bottom)
    end
    local ref_do_reinforce = GET_CHILD_RECURSIVELY(goddess_equip_manager, 'ref_do_reinforce')
    AUTO_CAST(ref_do_reinforce)
    if g.continue_reinforce.use and g.settings.continue_reinforce.use == 1 then
        ref_do_reinforce:Resize(100, 70)
        local ref_do_text = ref_do_reinforce:GetTextByKey("value")
        ref_do_reinforce:SetText(ref_do_text)
        local rect = ref_do_reinforce:GetMargin()
        ref_do_reinforce:SetPos(-30, rect.bottom)
    else
        ref_do_reinforce:Resize(160, 70)
        local ref_do_text = ref_do_reinforce:GetTextByKey("value")
        ref_do_reinforce:SetText(ref_do_text)
        local rect = ref_do_reinforce:GetMargin()
        ref_do_reinforce:SetPos(0, rect.bottom)
    end
    reinf_left_bg:RemoveChild("cancel")
    if g.continue_reinforce.use and g.settings.continue_reinforce.use == 1 then
        local cancel = reinf_left_bg:CreateOrGetControl("button", "cancel", 0, 647, 100, 70)
        AUTO_CAST(cancel)
        cancel:SetEventScript(ui.LBUTTONDOWN, "Continue_reinforce_stop_script")
        cancel:SetSkinName("test_red_button")
        cancel:SetText("{@st41b}{s18}Cancel")
    end
    local use_toggle =
        reinf_left_bg:CreateOrGetControl('picture', "use_toggle", 315, reinf_no_msgbox:GetY() - 5, 60, 30)
    AUTO_CAST(use_toggle)
    local icon_name = "test_com_ability_on"
    if g.continue_reinforce.use == false then
        icon_name = "test_com_ability_off"
    end
    use_toggle:SetImage(icon_name)
    use_toggle:SetEnableStretch(1)
    use_toggle:EnableHitTest(1)
    use_toggle:SetTextTooltip(g.lang == "Japanese" and "{ol}ON/Continue Reinfoceを使用" or
                                  "{ol}ON/Use Continue Reinforce")
    use_toggle:SetEventScript(ui.LBUTTONUP, "Continue_reinforce_setting_change")
    goddess_equip_manager:RemoveChild("gbox")
    if g.continue_reinforce.use and g.settings.continue_reinforce.use == 1 then
        local gbox = goddess_equip_manager:CreateOrGetControl("groupbox", "gbox", 1035, 755, 180, 110)
        AUTO_CAST(gbox)
        gbox:SetSkinName("None")
        gbox:RunUpdateScript("Continue_reinforce_run_update_script", 0.5)
        g.continue_reinforce.inv_tbl = {}
        gbox:SetUserValue("IESID", "None")
        local clear = gbox:CreateOrGetControl("button", "clear", 0, 0, 60, 30)
        AUTO_CAST(clear)
        clear:SetText("{ol}clear")
        clear:SetSkinName("test_red_button")
        clear:SetTextTooltip(g.lang == "Japanese" and "{ol}強化回数制限をクリアーします" or
                                 "{ol}Clear the reinforcement count limit")
        clear:SetEventScript(ui.LBUTTONUP, "Continue_reinforce_setting_change")
        local normal = gbox:CreateOrGetControl("button", "normal", 60, 0, 60, 30)
        AUTO_CAST(normal)
        normal:SetText("{ol}{s13}normal") -- relic_btn_purple
        normal:SetSkinName("relic_btn_purple")
        normal:SetTextTooltip(g.lang == "Japanese" and "{ol}強化補助剤をセットします" or
                                  "{ol}Set the reinforcement aid")
        normal:SetEventScript(ui.LBUTTONUP, "Continue_reinforce_mat_select")
        local premium = gbox:CreateOrGetControl("button", "premium", 120, -4, 60, 36)
        AUTO_CAST(premium)
        premium:SetText("{ol}{s10}Premium")
        premium:SetSkinName("baseyellow_btn")
        premium:SetTextTooltip(g.lang == "Japanese" and "{ol}プレミアム強化補助剤をセットします" or
                                   "{ol}Set the Premium Reinforcement Aid")
        premium:SetEventScript(ui.LBUTTONUP, "Continue_reinforce_mat_select")
        local x = 30
        local y = 30
        local text = 1
        for i = 0, 9 do
            local number = gbox:CreateOrGetControl("button", "number" .. i, x + 30 * i, y, 30, 25)
            AUTO_CAST(number)
            number:SetEventScript(ui.LBUTTONDOWN, "Continue_reinforce_count_input")
            number:SetEventScriptArgNumber(ui.LBUTTONDOWN, text)
            number:SetText("{ol}" .. text)
            if i == 4 then
                x = 30 - 5 * 30
                y = 55
                text = text + 5
            elseif i >= 5 then
                text = text + 5
            else
                text = text + 1
            end
        end
        local clear_toggle = gbox:CreateOrGetControl('picture', "clear_toggle", 30, 80, 60, 30)
        AUTO_CAST(clear_toggle)
        local icon_name = "test_com_ability_on"
        if g.continue_reinforce.limit_clear == false then
            icon_name = "test_com_ability_off"
        end
        clear_toggle:SetImage(icon_name)
        clear_toggle:SetEnableStretch(1)
        clear_toggle:EnableHitTest(1)
        clear_toggle:SetTextTooltip(g.lang == "Japanese" and
                                        "{ol}ON/回数制限到達時に制限をクリアーします" or
                                        "{ol}upon reaching the limit")
        clear_toggle:SetEventScript(ui.LBUTTONUP, "Continue_reinforce_setting_change")
        local count_edit = gbox:CreateOrGetControl('edit', 'count_edit', 95, 80, 55, 30)
        AUTO_CAST(count_edit)
        count_edit:SetFontName("white_16_ol")
        count_edit:SetTextAlign("center", "center")
        count_edit:SetText(g.continue_reinforce.rf_count ~= 0 and "{ol}" .. g.continue_reinforce.rf_count or "")
        count_edit:SetNumberMode(0)
        count_edit:SetMaxLen(2)
        count_edit:SetTypingScp("Continue_reinforce_count_input")
        count_edit:SetTextTooltip(g.lang == "Japanese" and "{ol}強化回数制限" or
                                      "{ol}Continuous Reinforcement Limit")
    end
end

function Continue_reinforce_setting_change(frame, ctrl)
    local ctrl_name = ctrl:GetName()
    if ctrl_name == "use_toggle" then
        if g.continue_reinforce.use == true then
            g.continue_reinforce.use = false
            ctrl:SetImage("test_com_ability_off")
        else
            g.continue_reinforce.use = true
            ctrl:SetImage("test_com_ability_on")
        end
    elseif ctrl_name == "clear" then
        g.continue_reinforce.rf_count = 0
        local format_string
        local limit_text
        if g.lang == "Japanese" then
            format_string = "強化制限回数を %s に設定しました"
            limit_text = "無制限"
        else
            format_string = "Continuous Reinforcement Limit set to %s"
            limit_text = "Unlimited"
        end
        local msg = string.format(format_string, limit_text)
        imcAddOn.BroadMsg("NOTICE_Dm_Bell", msg, 2.5)
    elseif ctrl_name == "clear_toggle" then
        if g.continue_reinforce.limit_clear == true then
            g.continue_reinforce.limit_clear = false
            ctrl:SetImage("test_com_ability_off")
        else
            g.continue_reinforce.limit_clear = true
            ctrl:SetImage("test_com_ability_on")
        end
    end
    Continue_reinforce_GODDESS_EQUIP_MANAGER_OPEN()
end

function Continue_reinforce_count_input(parent, ctrl, str, num)
    if ctrl:GetName() ~= "count_edit" then
        local count_edit = GET_CHILD(parent, "count_edit")
        count_edit:SetText("{ol}" .. num)
        g.continue_reinforce.rf_count = num
    else
        local number_text = string.gsub(ctrl:GetText(), "%D", "")
        number_text = tonumber(number_text)
        if number_text then
            g.continue_reinforce.rf_count = number_text
        else
            g.continue_reinforce.rf_count = 0
        end
    end
    g.continue_reinforce.is_first = false
    ctrl:StopUpdateScript("Continue_reinforce_save_settings_reserve")
    ctrl:RunUpdateScript("Continue_reinforce_save_settings_reserve", 0.5)
end

function Continue_reinforce_save_settings_reserve(ctrl)
    Continue_reinforce_GODDESS_EQUIP_MANAGER_OPEN()
    local count_text
    if g.continue_reinforce.rf_count == 0 then
        count_text = g.lang == "Japanese" and "無制限" or "Unlimited"
    else
        count_text = g.continue_reinforce.rf_count
    end
    local format_string
    if g.lang == "Japanese" then
        format_string = "強化制限回数を %s に設定しました"
    else
        format_string = "Continuous Reinforcement Limit set to %s"
    end
    local msg = string.format(format_string, count_text)
    imcAddOn.BroadMsg("NOTICE_Dm_Bell", msg, 2.5)
end

function Continue_reinforce_stop_process(goddess_equip_manager)
    goddess_equip_manager:StopUpdateScript("Continue_reinforce_GODDESS_MGR_REFORGE_REINFORCE_EXEC")
    g.continue_reinforce.is_first = false
    Continue_reinforce_next_mat_set(goddess_equip_manager, false)
    if g.continue_reinforce.limit_clear then
        g.continue_reinforce.rf_count = 0
        Continue_reinforce_GODDESS_EQUIP_MANAGER_OPEN()
        return true
    end
    return false
end

function Continue_reinforce__END_REFORGE_REINFORCE_EXEC()
    if not g.continue_reinforce.use or g.settings.continue_reinforce.use == 0 then
        return
    end
    local goddess_equip_manager = ui.GetFrame('goddess_equip_manager')
    local reinf_left_bg = GET_CHILD_RECURSIVELY(goddess_equip_manager, "reinf_left_bg")
    local ref_ok_reinforce = GET_CHILD_RECURSIVELY(goddess_equip_manager, 'ref_ok_reinforce')
    ref_ok_reinforce:ShowWindow(0)
    local ref_do_reinforce = GET_CHILD_RECURSIVELY(goddess_equip_manager, "ref_do_reinforce")
    AUTO_CAST(ref_do_reinforce)
    ref_do_reinforce:ShowWindow(1)
    ref_do_reinforce:SetEnable(1)
    if not g.continue_reinforce.is_first then
        g.continue_reinforce.is_first = true
        g.continue_reinforce.count = g.continue_reinforce.rf_count
    end
    local result_str = goddess_equip_manager:GetUserValue('REINFORCE_RESULT')
    if result_str == 'SUCCESS' then
        goddess_equip_manager:SetUserValue('REINFORCE_RESULT', "None")
        GODDESS_MGR_REFORGE_REINFORCE_CLEAR(goddess_equip_manager, true)
        if not Continue_reinforce_stop_process(goddess_equip_manager) then
            goddess_equip_manager:RunUpdateScript("Continue_reinforce_next_mat_set", 0.2)
        end
        local ref_item_reinf_text = GET_CHILD_RECURSIVELY(goddess_equip_manager, 'ref_item_reinf_text')
        local ref_slot = GET_CHILD_RECURSIVELY(goddess_equip_manager, 'ref_slot')
        local ref_slot_guid = ref_slot:GetUserValue('ITEM_GUID')
        local inv_item = session.GetInvItemByGuid(ref_slot_guid)
        if inv_item then
            local item_obj = GetIES(inv_item:GetObject())
            if item_obj then
                ref_item_reinf_text:SetTextByKey('value', TryGetProp(item_obj, 'Reinforce_2', 0))
            end
        end
        return
    end
    local is_material_shortage = false
    local mat_bg = GET_CHILD_RECURSIVELY(goddess_equip_manager, 'reinf_main_mat_bg')
    for i = 0, mat_bg:GetChildCount() - 1 do
        local ctrlset = GET_CHILD(mat_bg, 'GODDESS_REINF_MAT_' .. i)
        if ctrlset then
            local slot = GET_CHILD(ctrlset, 'slot')
            local mat_name = ctrlset:GetUserValue('ITEM_NAME')
            local cur_count_str = '0'
            if IS_ACCOUNT_COIN(mat_name) then
                cur_count_str = TryGetProp(GetMyAccountObj(), mat_name, '0')
            else
                local mat_item = session.GetInvItemByName(mat_name)
                if mat_item then
                    cur_count_str = tostring(mat_item.count)
                end
            end
            local need_count_str = slot:GetEventScriptArgString(ui.DROP)
            local inv_count = GET_CHILD_RECURSIVELY(ctrlset, 'invcount')
            inv_count:SetTextByKey('have', cur_count_str)
            inv_count:SetTextByKey('need', need_count_str)
            if tonumber(cur_count_str) < tonumber(need_count_str) then
                is_material_shortage = true
                break
            end
        end
    end
    if is_material_shortage or (g.continue_reinforce.rf_count > 0 and g.continue_reinforce.count <= 1) then
        if not Continue_reinforce_stop_process(goddess_equip_manager) then
            goddess_equip_manager:RunUpdateScript("Continue_reinforce_GODDESS_MGR_REFORGE_REG_ITEM", 0.2)
            GODDESS_MGR_REINFORCE_CLEAR_BTN(reinf_left_bg, ref_ok_reinforce)
        end
        return
    end
    if g.continue_reinforce.rf_count > 0 then
        g.continue_reinforce.count = g.continue_reinforce.count - 1
    end
    goddess_equip_manager:RunUpdateScript("Continue_reinforce_GODDESS_MGR_REFORGE_REINFORCE_EXEC",
        g.continue_reinforce.delay)
end

function Continue_reinforce_GODDESS_MGR_REFORGE_REINFORCE_EXEC(goddess_equip_manager)
    local reinf_left_bg = GET_CHILD_RECURSIVELY(goddess_equip_manager, "reinf_left_bg")
    local ref_do_reinforce = GET_CHILD(reinf_left_bg, "ref_do_reinforce")
    GODDESS_MGR_REFORGE_REINFORCE_EXEC(reinf_left_bg, ref_do_reinforce)
    local ref_ok_reinforce = GET_CHILD_RECURSIVELY(goddess_equip_manager, 'ref_ok_reinforce')
    GODDESS_MGR_REINFORCE_CLEAR_BTN(reinf_left_bg, ref_ok_reinforce)
    return 0
end

function Continue_reinforce_stop_script()
    local goddess_equip_manager = ui.GetFrame('goddess_equip_manager')
    goddess_equip_manager:StopUpdateScript("Continue_reinforce_GODDESS_MGR_REFORGE_REINFORCE_EXEC")
    goddess_equip_manager:SetUserValue('REINFORCE_RESULT', "SUCCESS")
    GODDESS_MGR_REFORGE_REINFORCE_CLEAR(goddess_equip_manager, true)
    g.continue_reinforce.is_first = false
    g.continue_reinforce.count = 0
    Continue_reinforce_next_mat_set(goddess_equip_manager, false)
    ui.SysMsg("{ol}Continuous Reinforcement Cancelled")
end

function Continue_reinforce_mat_select(parent, ctrl)
    local goddess_equip_manager = ctrl:GetTopParentFrame()
    ui.EnableSlotMultiSelect(1)
    local ref_slot = GET_CHILD_RECURSIVELY(goddess_equip_manager, 'ref_slot')
    local use_lv = ref_slot:GetUserIValue('ITEM_USE_LEVEL')
    if use_lv == 0 then
        return
    end
    local ctrl_name = ctrl:GetName()
    if ctrl_name == "normal" then
        local normal_max = GET_MAX_SUB_REVISION_COUNT(use_lv)
        Continue_reinforce_mat_select_(goddess_equip_manager, use_lv, "normal", normal_max)
    elseif ctrl_name == "premium" then
        local premium_max = GET_MAX_PREMIUM_SUB_REVISION_COUNT(use_lv)
        Continue_reinforce_mat_select_(goddess_equip_manager, use_lv, "premium", premium_max)
    end
end

function Continue_reinforce_mat_select_(goddess_equip_manager, use_lv, mat_type, need_count)
    local reinf_extra_mat_list = GET_CHILD_RECURSIVELY(goddess_equip_manager, "reinf_extra_mat_list")
    if mat_type == "premium" then
        for i = 0, reinf_extra_mat_list:GetSlotCount() - 1 do
            local slot = reinf_extra_mat_list:GetSlotByIndex(i)
            if slot:GetUserValue('MAT_TYPE') == mat_type then
                local icon = slot:GetIcon()
                if icon then
                    if slot:GetSelectCount() > 0 then
                        slot:SetSelectCount(0)
                        slot:Select(0)
                        g.continue_reinforce.premium_mat = false
                    else
                        local inv_item = session.GetInvItemByType(slot:GetIcon():GetInfo().type)
                        local select_count = math.min(inv_item.count, need_count)
                        slot:SetSelectCount(select_count)
                        slot:Select(1)
                        g.continue_reinforce.premium_mat = true
                    end
                    SCR_LBTNDOWN_GODDESS_REINFORCE_EXTRA_MAT(reinf_extra_mat_list, slot)
                    return
                end
            end
        end
        return
    end
    local available_mats = {}
    local release = false
    for i = 0, reinf_extra_mat_list:GetSlotCount() - 1 do
        local slot = reinf_extra_mat_list:GetSlotByIndex(i)
        if slot:GetUserValue('MAT_TYPE') == "normal" then
            local icon = slot:GetIcon()
            if icon then
                local icon_info = icon:GetInfo()
                local item_cls = GetClassByType('Item', icon_info.type)
                local inv_item = session.GetInvItemByType(icon_info.type)
                if slot:GetSelectCount() > 0 then
                    release = true
                    g.continue_reinforce.normal_mat = false
                end
                local item_lv_str = item_cls.ClassName:match("_([%d]+)_")
                local item_lv = tonumber(item_lv_str)
                if inv_item and item_lv then
                    table.insert(available_mats, {
                        level = item_lv,
                        count = inv_item.count,
                        slot = slot
                    })
                end
            end
        end
    end
    if release == true then
        for _, mat_info in ipairs(available_mats) do
            if mat_info.slot:GetSelectCount() > 0 then
                mat_info.slot:SetSelectCount(0)
                mat_info.slot:Select(0)
            end
        end
        SCR_LBTNDOWN_GODDESS_REINFORCE_EXTRA_MAT(reinf_extra_mat_list, nil)
        return
    end
    table.sort(available_mats, function(a, b)
        return a.level < b.level
    end)
    local selected_count = 0
    local selection_plan = {}
    for _, mat_info in ipairs(available_mats) do
        if selected_count >= need_count then
            break
        end
        local amount_to_select = math.min(mat_info.count, need_count - selected_count)
        if amount_to_select > 0 then
            table.insert(selection_plan, {
                slot = mat_info.slot,
                count = amount_to_select,
                level = mat_info.level
            })
            selected_count = selected_count + amount_to_select
        end
    end
    local used_higher_level = false
    for _, plan in ipairs(selection_plan) do
        plan.slot:SetSelectCount(plan.count)
        plan.slot:Select(1)
        local item_level = plan.level
        if item_level and item_level > use_lv then
            used_higher_level = true
        end
        g.continue_reinforce.normal_mat = true
        SCR_LBTNDOWN_GODDESS_REINFORCE_EXTRA_MAT(reinf_extra_mat_list, plan.slot)
    end
    if used_higher_level then
        local msg = g.lang == "Japanese" and
                        "同レベルの補助材がありません{nl}上位レベルの補助剤を使用します" or
                        "No same-level aid available{nl}Using a higher-level aid"
        imcAddOn.BroadMsg("NOTICE_Dm_!", msg, 2.5)
    end
end

function Continue_reinforce_next_mat_set(goddess_equip_manager, do_set)
    local gbox = GET_CHILD_RECURSIVELY(goddess_equip_manager, "gbox")
    if g.continue_reinforce.normal_mat then
        local normal_btn = GET_CHILD(gbox, "normal")
        if do_set == false then
            g.continue_reinforce.normal_mat = false
        end
        Continue_reinforce_mat_select(gbox, normal_btn)
    end
    if g.continue_reinforce.premium_mat then
        local premium_btn = GET_CHILD(gbox, "premium")
        if do_set == false then
            g.continue_reinforce.premium_mat = false
        end
        Continue_reinforce_mat_select(gbox, premium_btn)
    end
end

function Continue_reinforce_run_update_script(gbox)
    if g.continue_reinforce.inv_tbl["first"] == nil then
        g.continue_reinforce.inv_tbl["first"] = true
    end
    if g.continue_reinforce.inv_tbl["first"] then
        local inv_item_list = session.GetInvItemList()
        local inv_guid_list = inv_item_list:GetGuidList()
        local count = inv_guid_list:Count()
        for i = 0, count - 1 do
            local guid = inv_guid_list:Get(i)
            local inv_item = inv_item_list:GetItemByGuid(guid)
            local inv_obj = GetIES(inv_item:GetObject())
            local inv_clsname = inv_obj.ClassName
            if (string.find(inv_clsname, "misc_reinforce_percentUp_") and
                (not string.find(inv_clsname, "_NoTrade") or string.find(inv_clsname, "ea_"))) or
                (string.find(inv_clsname, "misc_Premium_reinforce_percentUp_") and string.find(inv_clsname, "plus")) then
                local inv_item_count = inv_item.count
                g.continue_reinforce.inv_tbl[inv_clsname] = inv_item_count
                g.continue_reinforce.inv_tbl["first"] = false
            end
        end
    end
    for cls_name, count in pairs(g.continue_reinforce.inv_tbl) do
        local inv_item = nil
        local item_count = 0
        if cls_name ~= "first" and cls_name ~= "remove" then
            inv_item = session.GetInvItemByName(cls_name)
            if inv_item then
                item_count = inv_item.count
            end
            if count ~= item_count then
                local frame = gbox:GetTopParentFrame()
                if not g.continue_reinforce.inv_tbl["remove"] then
                    local ref_slot_bg = GET_CHILD_RECURSIVELY(frame, "ref_slot_bg")
                    local ref_slot = GET_CHILD(ref_slot_bg, "ref_slot")
                    GODDESS_MGR_REFORGE_ITEM_REMOVE(ref_slot_bg, ref_slot)
                    g.continue_reinforce.inv_tbl["remove"] = true
                    return 1
                else
                    local iesid = gbox:GetUserValue("IESID")
                    local inv_item_ = session.GetInvItemByGuid(iesid)
                    if inv_item_ then
                        local item_obj = GetIES(inv_item_:GetObject())
                        GODDESS_MGR_REFORGE_REG_ITEM(frame, inv_item_, item_obj)
                    end
                    g.continue_reinforce.inv_tbl["remove"] = false
                    g.continue_reinforce.inv_tbl["first"] = true
                    return 1
                end
            end
        end
    end
    return 1
end

function Continue_reinforce_GODDESS_MGR_REFORGE_INV_RBTN(item_obj, slot, guid)
    local frame = ui.GetFrame('goddess_equip_manager')
    local inv_item = session.GetInvItemByGuid(guid)
    if inv_item then
        local item_cls = GetClassByType("Item", inv_item.type)
        if string.find(item_cls.MarketCategory, "Weapon_") or string.find(item_cls.MarketCategory, "Armor_") or
            string.find(item_cls.MarketCategory, "Accessory_") then
            GODDESS_MGR_REFORGE_REG_ITEM(frame, inv_item, item_obj)
        else
            INV_ICON_USE(inv_item)
            Continue_reinforce_GODDESS_MGR_REFORGE_REG_ITEM()
            frame:RunUpdateScript("Continue_reinforce_GODDESS_MGR_REFORGE_REG_ITEM_reserve", 0.2)
        end
    end
end

function Continue_reinforce_GODDESS_MGR_REFORGE_REG_ITEM_reserve(frame)
    local warningmsgbox = ui.GetFrame("warningmsgbox")
    if warningmsgbox:IsVisible() == 1 then
        return 1
    end
    local inputstring = ui.GetFrame("inputstring")
    if inputstring:IsVisible() == 1 then
        return 1
    end
    Continue_reinforce_GODDESS_MGR_REFORGE_REG_ITEM()
    return 0
end

function Continue_reinforce_GODDESS_MGR_REFORGE_REG_ITEM()
    if not g.continue_reinforce.use or g.settings.continue_reinforce.use == 0 then
        return
    end
    INVENTORY_SET_CUSTOM_RBTNDOWN('GODDESS_MGR_REFORGE_INV_RBTN')
    local frame = ui.GetFrame('goddess_equip_manager')
    local main_tab = GET_CHILD_RECURSIVELY(frame, 'main_tab')
    if main_tab:GetSelectItemIndex() ~= 0 then
        return
    end
    local reforge_tab = GET_CHILD_RECURSIVELY(frame, 'reforge_tab')
    if reforge_tab:GetSelectItemIndex() ~= 0 then
        return
    end
    INVENTORY_SET_CUSTOM_RBTNDOWN('Continue_reinforce_GODDESS_MGR_REFORGE_INV_RBTN')
    local ref_slot = GET_CHILD_RECURSIVELY(frame, 'ref_slot')
    local iesid = ref_slot:GetUserValue("ITEM_GUID")
    local gbox = GET_CHILD_RECURSIVELY(frame, 'gbox')
    gbox:SetUserValue("IESID", iesid)
    g.continue_reinforce.is_first = false
    local reinf_main_mat_bg = GET_CHILD_RECURSIVELY(frame, 'reinf_main_mat_bg')
    local child_count = reinf_main_mat_bg:GetChildCount()
    local stop = false
    for i = 0, child_count - 1 do
        local child = reinf_main_mat_bg:GetChildByIndex(i)
        if child and string.find(child:GetName(), "GODDESS_REINF_MAT_") then
            local btn = GET_CHILD_RECURSIVELY(child, "btn")
            GODDESS_MGR_REFORGE_REINFORCE_REG_MAT(child, btn)
            local slot = GET_CHILD(child, 'slot')
            local mat_name = child:GetUserValue('ITEM_NAME')
            local cur_count = '0'
            if IS_ACCOUNT_COIN(mat_name) == true then
                local acc = GetMyAccountObj()
                cur_count = TryGetProp(acc, mat_name, '0')
                if cur_count == 'None' then
                    cur_count = '0'
                end
            else
                local mat_item = session.GetInvItemByName(mat_name)
                if mat_item == nil then
                    cur_count = '0'
                else
                    cur_count = tostring(mat_item.count)
                end
            end
            local need_count = slot:GetEventScriptArgString(ui.DROP)
            local inv_count = GET_CHILD_RECURSIVELY(child, 'invcount')
            inv_count:SetTextByKey('have', cur_count)
            inv_count:SetTextByKey('need', need_count)
            if tonumber(need_count) > tonumber(cur_count) then
                stop = true
            end
        end
    end
    if stop then
        frame:StopUpdateScript("Continue_reinforce_GODDESS_MGR_REFORGE_REG_ITEM_reserve")
    end
end

function Continue_reinforce_GODDESS_MGR_REFORGE_ITEM_REMOVE()
    INVENTORY_SET_CUSTOM_RBTNDOWN('GODDESS_MGR_REFORGE_INV_RBTN')
end

function Continue_reinforce_GODDESS_MGR_REFORGE_TAB_CHANGE()
    INVENTORY_SET_CUSTOM_RBTNDOWN('GODDESS_MGR_REFORGE_INV_RBTN')
    local goddess_equip_manager = ui.GetFrame('goddess_equip_manager')
    local reforge_tab = GET_CHILD_RECURSIVELY(goddess_equip_manager, 'reforge_tab')
    local tab_index = reforge_tab:GetSelectItemIndex()
    if tab_index == 0 then
        Continue_reinforce_GODDESS_EQUIP_MANAGER_OPEN()
    else
        goddess_equip_manager:RemoveChild("gbox")
    end
end
-- continue_reinforce ここまで

