-- quickslot_operate ここから
g.quickslot_operate_raid_list = {
    Paramune = {623, 667, 666, 665, 674, 673, 675, 680, 679, 681, 707, 708, 710, 711, 709, 712, 722, 723, 724, 725, 726,
                727, 729, 730, 731},
    Klaida = {686, 685, 687, 716, 717, 718},
    Velnias = {689, 688, 690, 669, 635, 628, 696, 695, 697},
    Forester = {672, 671, 670},
    Widling = {677, 676, 678}
}
g.quickslot_operate_zone_list = {11208, 11230, 11250, 11252, 11256, 11257, 11261, 11263, 11266, 11267, 11270, 11276,
                                 11277, 11278, 11285, 11286, 11291}
-- 11267=ドラグーン 11257=バウバス 11290=アシャーク
g.quickslot_guild_eventmap = {11267, 11257, 11290, 11285, 11286}
g.quickslot_operate_atk_list = {
    Velnias = {640504, 640368},
    Klaida = {640503, 640370},
    Paramune = {640502, 640369},
    Widling = {640501, 640372},
    Forester = {640500, 640371}
}
g.quickslot_operate_def_list = {
    Velnias = 640373,
    Klaida = 640375,
    Paramune = 640374,
    Widling = 640377,
    Forester = 640376
}
function Quickslot_operate_save_settings()
    g.save_json(g.quickslot_operate_path, g.quickslot_operate_settings)
end

function Quickslot_operate_load_settings()
    g.quickslot_operate_path = string.format("../addons/%s/%s/quickslot_operate.json", addon_name_lower, g.active_id)
    g.quickslot_operate_old_path = string.format("../addons/%s/%s/settings_250609.json", "quickslot_operate",
        g.active_id)
    local ver = 1.1
    local settings = g.load_json(g.quickslot_operate_path)

    if not settings then
        local old_settings = g.load_json(g.quickslot_operate_old_path)
        if old_settings then
            settings = old_settings
        else
            settings = {
                slotset = {},
                straight = false,
                rshift = false
            }
        end
        settings.ver = ver
    end
    if not settings.ver or settings.ver < ver then
        settings.ver = ver
    end
    g.quickslot_operate_settings = settings
    Quickslot_operate_save_settings()
end

function quickslot_operate_on_init()
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    if not g.quickslot_operate_settings then
        _nexus_addons_p:RunUpdateScript("Quickslot_operate_lazy_start", 0.1)
        return
    end
    if g.settings.quickslot_operate.use == 0 then
        local quickslot_operate_map_timer = GET_CHILD(_nexus_addons_p, "quickslot_operate_map_timer")
        if _nexus_addons_p then
            _nexus_addons_p:RemoveChild("quickslot_operate_map_timer")
            _nexus_addons_p:RemoveChild("quickslot_operate_timer")
        end
        local quickslotnexpbar = ui.GetFrame("quickslotnexpbar")
        if quickslotnexpbar then
            quickslotnexpbar:RemoveChild("setting")
            if g.quickslot_operate_settings and g.quickslot_operate_settings.straight then
                g.quickslot_operate_settings.straight = false
                Quickslot_operate_redraw_slots()
            end
            quickslotnexpbar:SetUserValue("USE", 0)
            quickslotnexpbar:RunUpdateScript("Quickslot_operate_set_script", 2.0)
        end
        return
    end
    Quickslot_operate_init_logic()
end

function Quickslot_operate_lazy_start(frame)
    if not g.quickslot_operate_settings then
        Quickslot_operate_load_settings()
    end
    local old_func = g.settings.quickslot_operate.old_init_func
    if _G[old_func] then
        return
    end
    if g.settings.quickslot_operate.use == 1 then
        Quickslot_operate_init_logic()
    end
    return 0
end

function Quickslot_operate_init_logic()
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    _nexus_addons_p:SetVisible(1)
    g.setup_hook_and_event(g.addon, "SHOW_INDUNENTER_DIALOG", "Quickslot_operate_SHOW_INDUNENTER_DIALOG", true)
    Quickslot_operate_frame_init()
    local quickslot_operate_map_timer = _nexus_addons_p:CreateOrGetControl("timer", "quickslot_operate_map_timer", 0, 0)
    AUTO_CAST(quickslot_operate_map_timer)
    quickslot_operate_map_timer:SetUpdateScript("Quickslot_operate_map_change")
    quickslot_operate_map_timer:Stop()
    quickslot_operate_map_timer:Start(3.0)
    if g.quickslot_operate_settings.rshift then
        local quickslot_operate_timer = _nexus_addons_p:CreateOrGetControl("timer", "quickslot_operate_timer", 0, 0)
        AUTO_CAST(quickslot_operate_timer)
        quickslot_operate_timer:SetUpdateScript("Quickslot_operate_set_rshift_script")
        quickslot_operate_timer:Start(0.15)
    end
end

function Quickslot_operate_frame_init()
    local quickslotnexpbar = ui.GetFrame("quickslotnexpbar")
    local setting = quickslotnexpbar:CreateOrGetControl("button", "setting", 0, 0, 30, 20)
    AUTO_CAST(setting)
    setting:SetMargin(-260, 0, 0, 55)
    setting:SetText("{ol}{s11}QSO")
    setting:SetGravity(ui.CENTER_HORZ, ui.BOTTOM)
    setting:SetTextTooltip(g.lang == "Japanese" and
                               "{ol}左クリック: スロットセット読込{nl}右クリック: 各種設定" or
                               "{ol}Left-click: Load Slot Set{nl}Right-click: Settings")
    setting:SetEventScript(ui.RBUTTONUP, "Quickslot_operate_context")
    setting:SetEventScript(ui.LBUTTONUP, "Quickslot_operate_load_slotset_context")
    Quickslot_operate_redraw_slots()
    quickslotnexpbar:SetUserValue("USE", 1)
    quickslotnexpbar:RunUpdateScript("Quickslot_operate_set_script", 2.0)
end

function Quickslot_operate_context()
    local context = ui.CreateContextMenu("CONTEXT", "{ol}slotset context", 0, -300, 0, 0)
    ui.AddContextMenuItem(context, "-----", "None")
    ui.AddContextMenuItem(context,
        g.lang == "Japanese" and "{ol}スロットレイアウト保存" or "{ol}Save Slot layout",
        "Quickslot_operate_save_slotset()")
    ui.AddContextMenuItem(context,
        g.lang == "Japanese" and "{ol}スロットレイアウト削除" or "{ol}Delete Slot layout",
        "Quickslot_operate_delete_slotset()")
    ui.AddContextMenuItem(context, "------", "None")
    if g.quickslot_operate_settings.rshift then
        ui.AddContextMenuItem(context, g.lang == "Japanese" and "{ol}RSHIFT {#FF0000}ON {#FFFF00}OFFにする" or
            "{ol}RSHIFT {#FF0000}ON {#FFFF00}Turn OFF", "Quickslot_operate_switch_rshift()")
    else
        ui.AddContextMenuItem(context, g.lang == "Japanese" and "{ol}RSHIFT {#FF0000}OFF {#FFFF00}ONにする" or
            "{ol}RSHIFT {#FF0000}OFF {#FFFF00}Turn ON", "Quickslot_operate_switch_rshift()")
    end
    ui.AddContextMenuItem(context, "-------", "None")
    ui.AddContextMenuItem(context,
        g.lang == "Japanese" and "{ol}ストレートモード切替" or "{ol}Switch straight mode",
        "Quickslot_operate_straight()")
    ui.OpenContextMenu(context)
end

function Quickslot_operate_redraw_slots()
    local qso_settings = g.quickslot_operate_settings
    local quickslotnexpbar = ui.GetFrame("quickslotnexpbar")
    local margin, margin_2, margin_3
    if qso_settings.straight then
        margin, margin_2, margin_3 = -200, -200, -200
    else
        margin, margin_2, margin_3 = -225, -250, -225
    end
    for i = 11, MAX_QUICKSLOT_CNT do
        local slot = GET_CHILD_RECURSIVELY(quickslotnexpbar, "slot" .. i)
        AUTO_CAST(slot)
        if i <= 20 then
            slot:SetMargin(margin, 230, 0, 0)
            margin = margin + 50
        elseif i <= 30 then
            slot:SetMargin(margin_2, 180, 0, 0)
            margin_2 = margin_2 + 50
        elseif i <= 40 then
            slot:SetMargin(margin_3, 130, 0, 0)
            margin_3 = margin_3 + 50
        end
    end
    quickslotnexpbar:Invalidate()
    DebounceScript("QUICKSLOTNEXTBAR_UPDATE_ALL_SLOT", 0.1)
end

function Quickslot_operate_straight()
    g.quickslot_operate_settings.straight = not g.quickslot_operate_settings.straight
    Quickslot_operate_save_settings()
    Quickslot_operate_redraw_slots()
end

function Quickslot_operate_save_slotset()
    if not g.quickslot_operate_settings.slotset[g.login_name] then
        g.quickslot_operate_settings.slotset[g.login_name] = {}
    end
    Quickslot_operate_INPUT_STRING_BOX()
end

function Quickslot_operate_INPUT_STRING_BOX()
    local inputstring = ui.GetFrame("inputstring")
    inputstring:Resize(500, 220)
    inputstring:SetLayerLevel(999)
    local edit = GET_CHILD(inputstring, 'input')
    AUTO_CAST(edit)
    edit:SetNumberMode(0)
    edit:SetMaxLen(99)
    edit:SetText("")
    inputstring:ShowWindow(1)
    inputstring:SetEnable(1)
    local title = inputstring:GetChild("title")
    AUTO_CAST(title)
    local text = g.lang == "Japanese" and "{ol}{#FFFFFF}セット名を入力" or "{ol}{#FFFFFF}Enter set name"
    title:SetText(text)
    local confirm = inputstring:GetChild("confirm")
    confirm:SetEventScript(ui.LBUTTONUP, "Quickslot_operate_save_setname")
    edit:SetEventScript(ui.ENTERKEY, "Quickslot_operate_save_setname")
    edit:AcquireFocus()
end

function Quickslot_operate_save_setname(inputstring, ctrl, str, num)
    inputstring:ShowWindow(0)
    local edit = GET_CHILD(inputstring, 'input')
    local get_text = edit:GetText()
    if get_text == "" then
        local text = g.lang == "Japanese" and "{ol}文字を入力してください" or "{ol}Please enter text"
        ui.SysMsg(text)
        Quickslot_operate_INPUT_STRING_BOX()
        return
    end
    g.quickslot_operate_settings.slotset[g.login_name][get_text] = {}
    local temp_data = g.quickslot_operate_settings.slotset[g.login_name][get_text]
    local main_session = session.GetMainSession()
    local pc_job_data = main_session:GetPCJobInfo()
    local job_count = pc_job_data:GetJobCount()
    for i = 0, job_count - 1 do
        local current_job_info = pc_job_data:GetJobInfoByIndex(i)
        if current_job_info then
            local job_key = "jobid_" .. i
            temp_data[job_key] = tonumber(current_job_info.jobID)
        end
    end
    local quickslotnexpbar = ui.GetFrame("quickslotnexpbar")
    for i = 1, 40 do
        local slot = GET_CHILD_RECURSIVELY(quickslotnexpbar, "slot" .. i)
        if slot then
            local icon = slot:GetIcon()
            if icon then
                local icon_info = icon:GetInfo()
                local category = icon_info:GetCategory()
                local item_type = icon_info.type
                local iesid = icon_info:GetIESID()
                temp_data[tostring(i)] = {
                    ["category"] = category,
                    ["type"] = item_type,
                    ["iesid"] = iesid
                }
            end
        end
    end
    ui.SysMsg(g.lang == "Japanese" and "{ol}スロットレイアウト保存" or "{ol}Save Slot layout")
    Quickslot_operate_save_settings()
end

function Quickslot_operate_load_slotset_context()
    local context = ui.CreateContextMenu("CONTEXT_LOAD", "{ol}Load Slotset", 0, -350, 0, 0)
    Quickslot_operate_build_slotset_menu(context, "LOAD")
    ui.OpenContextMenu(context)
end

function Quickslot_operate_delete_slotset()
    local context = ui.CreateContextMenu("CONTEXT", "{ol}Delete slotset", 0, -100, 0, 0)
    Quickslot_operate_build_slotset_menu(context, "DELETE")
    ui.OpenContextMenu(context)
end

function Quickslot_operate_delete_slotset_(name, title)
    g.quickslot_operate_settings.slotset[name][title] = nil
    Quickslot_operate_save_settings()
    local msg = name .. ":" .. title .. (g.lang == "Japanese" and " 削除しました" or " Deleted")
    ui.SysMsg(msg)
end

function Quickslot_operate_load_all_slot(name, title)
    local quickslotnexpbar = ui.GetFrame('quickslotnexpbar')
    for i = 1, MAX_QUICKSLOT_CNT do
        local str_index = tostring(i)
        local slot = GET_CHILD_RECURSIVELY(quickslotnexpbar, "slot" .. str_index)
        AUTO_CAST(slot)
        local slot_info = g.quickslot_operate_settings.slotset[name][title][str_index]
        if slot_info then
            local category = slot_info.category
            local clsid = slot_info.type
            local iesid = slot_info.iesid
            SET_QUICK_SLOT(quickslotnexpbar, slot, category, clsid, iesid, 0, true, true)
        else
            slot:ClearText()
            CLEAR_QUICKSLOT_SLOT(slot, 0, true)
        end
        slot:Invalidate()
    end
    quickslot.RequestSave()
    QUICKSLOTNEXPBAR_UPDATE_HOTKEYNAME(quickslotnexpbar)
    DebounceScript("QUICKSLOTNEXTBAR_UPDATE_ALL_SLOT", 0.1)
end

function Quickslot_operate_build_slotset_menu(context, mode)
    local slotset_data = g.quickslot_operate_settings.slotset
    if not slotset_data then
        return
    end
    ui.AddContextMenuItem(context, "-----", "None")
    for name, data in pairs(slotset_data) do
        for title, layout_data in pairs(data) do
            local display_name_parts = {}
            for i = 0, 3 do
                local job_key = "jobid_" .. i
                local saved_job_id = layout_data[job_key]
                if saved_job_id then
                    local job_cls = GetClassByType("Job", tonumber(saved_job_id))
                    if job_cls then
                        local job_name = dic.getTranslatedStr(TryGetProp(job_cls, "Name", "None"))
                        table.insert(display_name_parts, job_name)
                    end
                end
            end
            local display_str = table.concat(display_name_parts, ", ")
            local display_text, scp
            if mode == "DELETE" then
                display_text = string.format("%s : (%s)", tostring(title), tostring(display_str))
                scp = string.format("Quickslot_operate_delete_slotset_('%s','%s')", name, title)
            elseif mode == "LOAD" then
                display_text = string.format("%s : (%s)", tostring(title), tostring(display_str))
                scp = string.format("Quickslot_operate_load_all_slot('%s','%s')", name, title)
            end
            if display_text and scp then
                ui.AddContextMenuItem(context, display_text, scp)
            end
        end
    end
end

function Quickslot_operate_set_script(quickslotnexpbar)
    g.qso_potion_map = {}
    for race, pots in pairs(g.quickslot_operate_atk_list) do
        for _, pot_id in ipairs(pots) do
            g.qso_potion_map[pot_id] = true
        end
    end
    for race, pot_id in pairs(g.quickslot_operate_def_list) do
        g.qso_potion_map[pot_id] = true
    end
    local is_use = quickslotnexpbar:GetUserIValue("USE")
    for i = 1, MAX_QUICKSLOT_CNT do
        local slot = GET_CHILD_RECURSIVELY(quickslotnexpbar, "slot" .. i)
        AUTO_CAST(slot)
        local slot_info = quickslot.GetInfoByIndex(i - 1)
        if slot_info and slot_info.type ~= 0 then
            if slot_info and g.qso_potion_map[slot_info.type] then
                if is_use == 0 then
                    slot:SetEventScript(ui.MOUSEON, "None")
                else
                    slot:SetEventScript(ui.MOUSEON, "Quickslot_operate_choice_potion")
                end
            end
        end
    end
end

function Quickslot_operate_choice_potion(frame, slot, str, num)
    slot:RunUpdateScript("Quickslot_operate_frame_close", 5.0)
    local joystickquickslot = ui.GetFrame('joystickquickslot')
    joystickquickslot:RunUpdateScript("Quickslot_operate_frame_close", 5.0)
    local quickslot_operate = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "quickslot_operate", 0, 0, 0, 0)
    quickslot_operate:RemoveAllChild()
    quickslot_operate:Resize(150, 30)
    local map_frame = ui.GetFrame("map")
    local width = map_frame:GetWidth()
    quickslot_operate:SetPos(width / 2 - 75, 780)
    quickslot_operate:SetTitleBarSkin("None")
    quickslot_operate:SetSkinName("chat_window")
    quickslot_operate:SetLayerLevel(150)
    local slotset = quickslot_operate:CreateOrGetControl('slotset', 'slotset', 0, 0, 0, 0)
    AUTO_CAST(slotset)
    slotset:SetSlotSize(30, 30)
    slotset:EnablePop(0)
    slotset:EnableDrag(0)
    slotset:EnableDrop(0)
    slotset:SetColRow(5, 1)
    slotset:SetSpc(0, 0)
    slotset:SetSkinName('slot')
    slotset:CreateSlots()
    local slot_count = slotset:GetSlotCount()
    local atk_list = {640372, 640370, 640369, 640368, 640371}
    for i = 0, slot_count - 1 do
        local slot = slotset:GetSlotByIndex(i)
        slot:SetEventScript(ui.LBUTTONDOWN, "Quickslot_operate_set_potion")
        slot:SetEventScriptArgNumber(ui.LBUTTONDOWN, atk_list[i + 1])
        local class = GetClassByType('Item', atk_list[i + 1])
        SET_SLOT_ITEM_CLS(slot, class)
    end
    quickslot_operate:ShowWindow(1)
end

function Quickslot_operate_set_potion(parent, slot, str, pot_id)
    for race, data in pairs(g.quickslot_operate_atk_list) do
        for _, id in ipairs(data) do
            if id == pot_id then
                local down_potion_id = g.quickslot_operate_def_list[race]
                Quickslot_operate_check_all_slots(race, down_potion_id)
            end
        end
    end
end

function Quickslot_operate_check_all_slots(race, down_potion_id, atk_id, def_id)
    local quickslotnexpbar = ui.GetFrame("quickslotnexpbar")
    local joystickquickslot = ui.GetFrame('joystickquickslot')
    if IsJoyStickMode() == 1 then
        quickslotnexpbar:ShowWindow(1)
        joystickquickslot:ShowWindow(0)
    end
    local atk_list = g.quickslot_operate_atk_list
    for i = 1, MAX_QUICKSLOT_CNT do
        local slot = GET_CHILD_RECURSIVELY(quickslotnexpbar, "slot" .. i)
        AUTO_CAST(slot)
        local slot_info = quickslot.GetInfoByIndex(i - 1)
        if slot_info and g.qso_potion_map[slot_info.type] then
            local is_atk_potion = false
            for _, pot_ids in pairs(atk_list) do
                for _, pot_id in ipairs(pot_ids) do
                    if pot_id == slot_info.type then
                        is_atk_potion = true
                        break
                    end
                end
                if is_atk_potion then
                    break
                end
            end
            local target_race = race or detected_race
            if is_atk_potion then
                local new_atk_id = atk_id
                if not new_atk_id or new_atk_id == 0 then
                    if target_race then
                        local list = atk_list[target_race]
                        local inv_item = session.GetInvItemByType(list[1]) or session.GetInvItemByType(list[2])
                        if inv_item then
                            new_atk_id = inv_item.type
                        else
                            new_atk_id = list[1]
                        end
                    end
                end
                if new_atk_id and new_atk_id ~= 0 then
                    SET_QUICK_SLOT(quickslotnexpbar, slot, slot_info.category, new_atk_id, nil, 0, true, true)
                end
            else
                local new_def_id = def_id
                if not new_def_id or new_def_id == 0 then
                    if target_race then
                        new_def_id = g.quickslot_operate_def_list[target_race]
                    elseif down_potion_id then
                        new_def_id = down_potion_id
                    end
                end
                if new_def_id and new_def_id ~= 0 then
                    SET_QUICK_SLOT(quickslotnexpbar, slot, slot_info.category, new_def_id, nil, 0, true, true)
                end
            end
        end
    end
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    local quickslot_operate_map_timer = _nexus_addons_p:CreateOrGetControl("timer", "quickslot_operate_map_timer", 0, 0)
    AUTO_CAST(quickslot_operate_map_timer)
    quickslot_operate_map_timer:Stop()
    quickslot.RequestSave()
    QUICKSLOTNEXPBAR_UPDATE_HOTKEYNAME(quickslotnexpbar)
    if IsJoyStickMode() == 1 then
        quickslotnexpbar:ShowWindow(0)
        joystickquickslot:ShowWindow(1)
    end
    DebounceScript("JOYSTICK_QUICKSLOT_UPDATE_ALL_SLOT", 0.1)
end

function Quickslot_operate_frame_close()
    local quickslot_operate = ui.GetFrame(addon_name_lower .. "quickslot_operate")
    if quickslot_operate then
        ui.DestroyFrame(quickslot_operate:GetName())
    end
end

function Quickslot_operate_map_change(_nexus_addons_p, Quickslot_operate_map_timer)
    local quickslotnexpbar = ui.GetFrame("quickslotnexpbar")
    for _, zone_id in ipairs(g.quickslot_operate_zone_list) do
        if zone_id == g.map_id then
            local potion_type = Quickslot_operate_get_potion_type(g.quickslot_operate_indun_type)
            if potion_type then
                quickslotnexpbar:SetUserValue("POT_TYPE", potion_type)
                quickslotnexpbar:RunUpdateScript("Quickslot_operate_get_potion", 2.0)
                return
            end
        end
    end -- 11285, 11286
    for _, eventmap_id in ipairs(g.quickslot_guild_eventmap) do
        if eventmap_id == g.map_id then
            if eventmap_id == 11285 or eventmap_id == 11286 then
                quickslotnexpbar:SetUserValue("POT_TYPE", "Paramune")
            else
                quickslotnexpbar:SetUserValue("POT_TYPE", "Velnias")
            end
            quickslotnexpbar:RunUpdateScript("Quickslot_operate_get_potion", 2.0)
            return
        end
    end
end

function Quickslot_operate_SHOW_INDUNENTER_DIALOG()
    if g.settings.quickslot_operate.use == 0 then
        return
    end
    local indunenter = ui.GetFrame('indunenter')
    local indun_type = tonumber(indunenter:GetUserValue("INDUN_TYPE"))
    g.quickslot_operate_indun_type = indun_type
    local potion_type = Quickslot_operate_get_potion_type(indun_type)
    if potion_type then
        local quickslotnexpbar = ui.GetFrame("quickslotnexpbar")
        quickslotnexpbar:SetUserValue("POT_TYPE", potion_type)
        Quickslot_operate_get_potion(quickslotnexpbar)
    end
end

function Quickslot_operate_get_potion_type(indun_type)
    for potion_type, indun_list in pairs(g.quickslot_operate_raid_list) do
        for _, indun_id in ipairs(indun_list) do
            if indun_id == indun_type then
                return potion_type
            end
        end
    end
    return nil
end

function Quickslot_operate_get_potion(quickslotnexpbar)
    local potion_type = quickslotnexpbar:GetUserValue("POT_TYPE")
    local atk_list = g.quickslot_operate_atk_list
    local def_list = g.quickslot_operate_def_list
    local atk_id = atk_list[potion_type][1]
    local inv_item = session.GetInvItemByType(atk_id)
    if not inv_item then
        atk_id = atk_list[potion_type][2]
        inv_item = session.GetInvItemByType(atk_id)
        if not inv_item then
            atk_id = 0
        end
    end
    local def_id = def_list[potion_type]
    inv_item = session.GetInvItemByType(def_id)
    if not inv_item then
        def_id = 0
    end
    if (atk_id and atk_id ~= 0) or (def_id and def_id ~= 0) or atk_id == 0 or def_id == 0 then
        Quickslot_operate_check_all_slots(potion_type, nil, atk_id, def_id)
    end
end

function Quickslot_operate_switch_rshift(is_first)
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    _nexus_addons_p:SetVisible(1)
    if g.quickslot_operate_settings.rshift == true then
        g.quickslot_operate_settings.rshift = false
        local quickslot_operate_timer = GET_CHILD(_nexus_addons_p, "quickslot_operate_timer")
        if quickslot_operate_timer then
            _nexus_addons_p:RemoveChild("quickslot_operate_timer")
        end
    else
        g.quickslot_operate_settings.rshift = true
        local quickslot_operate_timer = _nexus_addons_p:CreateOrGetControl("timer", "quickslot_operate_timer", 0, 0)
        AUTO_CAST(quickslot_operate_timer)
        quickslot_operate_timer:SetUpdateScript("Quickslot_operate_set_rshift_script")
        quickslot_operate_timer:Start(0.15)
    end
    Quickslot_operate_save_settings()
end

function Quickslot_operate_set_rshift_script()
    if keyboard.IsKeyPressed("RSHIFT") == 0 then
        return
    end
    local quickslotnexpbar = ui.GetFrame("quickslotnexpbar")
    local joystickquickslot = ui.GetFrame('joystickquickslot')
    if IsJoyStickMode() == 1 then
        quickslotnexpbar:ShowWindow(1)
        joystickquickslot:ShowWindow(0)
    end
    local current_potion_type = nil
    for i = 1, MAX_QUICKSLOT_CNT do
        local slot_info = quickslot.GetInfoByIndex(i - 1)
        if slot_info and slot_info.type ~= 0 then
            for race, pot_ids in pairs(g.quickslot_operate_atk_list) do
                for _, pot_id in ipairs(pot_ids) do
                    if pot_id == slot_info.type then
                        current_potion_type = race
                        break
                    end
                end
                if current_potion_type then
                    break
                end
            end
            if current_potion_type then
                break
            end
            for race, pot_id in pairs(g.quickslot_operate_def_list) do
                if pot_id == slot_info.type then
                    current_potion_type = race
                    break
                end
            end
        end
        if current_potion_type then
            break
        end
    end
    if not current_potion_type then
        return
    end
    local potion_type_order = {"Velnias", "Klaida", "Paramune", "Widling", "Forester"}
    local current_index = 0
    for i, p_type in ipairs(potion_type_order) do
        if p_type == current_potion_type then
            current_index = i
            break
        end
    end
    local next_index = (current_index % #potion_type_order) + 1
    local target_race = potion_type_order[next_index]
    local atk_ids = g.quickslot_operate_atk_list[target_race]
    local inv_atk = session.GetInvItemByType(atk_ids[1]) or session.GetInvItemByType(atk_ids[2])
    local found_atk_id = inv_atk and inv_atk.type or 0 -- 持ってなければ 0
    local def_id_candidate = g.quickslot_operate_def_list[target_race]
    local inv_def = session.GetInvItemByType(def_id_candidate)
    local found_def_id = inv_def and def_id_candidate or 0 -- 持ってなければ 0
    Quickslot_operate_check_all_slots(target_race, nil, found_atk_id, found_def_id)
    quickslot.RequestSave()
    if target_race then
        Quickslot_operate_check_all_slots(target_race, nil, found_atk_id, found_def_id)
        quickslot.RequestSave()
    end

    if IsJoyStickMode() == 1 then
        quickslotnexpbar:ShowWindow(0)
        joystickquickslot:ShowWindow(1)
    end
end
-- quickslot_operate ここまで

