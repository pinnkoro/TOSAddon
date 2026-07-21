-- separate_buff_custom ここから
function Separate_buff_custom_save_settings()
    g.save_json(g.separate_buff_custom_path, g.separate_buff_custom_settings)
end

function Separate_buff_custom_load_settings()
    g.separate_buff_custom_path = string.format("../addons/%s/%s/separate_buff_custom.json", addon_name_lower,
        g.active_id)
    local settings = g.load_json(g.separate_buff_custom_path)
    if not settings then
        settings = {
            x = 0,
            y = 0,
            move = 1,
            sep_buffs = {},
            location_share = 0,
            tracking = 0
        }
    end
    g.separate_buff_custom_settings = settings
    Separate_buff_custom_save_settings()
end

function separate_buff_custom_on_init()
    if not g.separate_buff_custom_settings then
        Separate_buff_custom_load_settings()
    end
    g.setup_hook_and_event(g.addon, "BUFF_SEPARATEDLIST_CTRLSET_CREATE",
        "Separate_buff_custom_BUFF_SEPARATEDLIST_CTRLSET_CREATE", true)
    g.setup_hook_and_event(g.addon, "BUFF_SEPARATEDLIST_CTRLSET_REMOVE",
        "Separate_buff_custom_BUFF_SEPARATEDLIST_CTRLSET_REMOVE", true)
    g.setup_hook_and_event(g.addon, "BUFF_SEPARATEDLIST_ON_RELOAD", "Separate_buff_custom_BUFF_SEPARATEDLIST_ON_RELOAD",
        true)
    g.setup_hook_and_event(g.addon, "BUFF_SEPARATED_TIME_UPDATE", "Separate_buff_custom_BUFF_SEPARATED_TIME_UPDATE",
        false)
    g.separate_buff_custom_temp_buffs = {}
    Separate_buff_custom_frame_move()
end

function Separate_buff_custom_buff_separatedlist_save_pos(frame)
    local x = frame:GetX()
    local y = frame:GetY()
    local userID = session.loginInfo.GetUserID()
    local path = string.format('../release/addon_setting/buff_separatedlist/%s/settings.json', userID)
    local settings = g.load_json(path)
    if not settings then
        settings = {
            pc_id = {}
        }
    end
    if not settings.pc_id then
        settings.pc_id = {}
    end
    local cid = session.GetMySession():GetCID()
    if not settings.pc_id[g.cid] then
        settings.pc_id[cid] = {}
    end
    if not settings.pc_id[g.cid]["pos"] then
        settings.pc_id[g.cid]["pos"] = {}
    end
    local current_pos = settings.pc_id[cid].pos
    if current_pos.x ~= x or current_pos.y ~= y then
        current_pos.x = x
        current_pos.y = y
        g.save_json(path, settings)
    end
end

function Separate_buff_custom_BUFF_SEPARATED_TIME_UPDATE(my_frame, my_msg)
    local frame, timer, argstr, argnum, passedtime = g.get_event_args(my_msg)
    local myhandle = session.GetMyHandle()
    local TOKEN_BUFF_ID = TryGetProp(GetClass("Buff", "Premium_Token"), "ClassID")
    local gbox = GET_CHILD_RECURSIVELY(frame, "buffGBox")
    if gbox == nil then
        return
    end
    local updated = 0
    local cnt = gbox:GetChildCount()
    for i = 1, cnt do
        local ctrlSet = gbox:GetChildByIndex(i - 1)
        if ctrlSet ~= nil then
            local slot = GET_CHILD_RECURSIVELY(ctrlSet, "slot")
            local text = GET_CHILD_RECURSIVELY(ctrlSet, "caption")
            if slot:IsVisible() == 1 then
                local icon = slot:GetIcon()
                local iconInfo = icon:GetInfo()
                local buffIndex = icon:GetUserIValue("BuffIndex")
                local buff = info.GetBuff(myhandle, iconInfo.type, buffIndex)
                if buff ~= nil then
                    text:SetText(GET_BUFF_TIME_TXT(buff.time, 0))
                    updated = 1
                    if buff.time < 5000 and buff.time ~= 0.0 then
                        if slot:IsBlinking() == 0 then
                            slot:SetBlink(600000, 1.0, "55FFFFFF", 1)
                        end
                    elseif buff.buffID == TOKEN_BUFF_ID and GET_REMAIN_TOKEN_SEC() < 3600 then
                        if slot:IsBlinking() == 0 then
                            slot:SetBlink(0, 1.0, "55FFFFFF", 1)
                        end
                    else
                        if slot:IsBlinking() == 1 then
                            slot:ReleaseBlink()
                        end
                    end
                end
            end
        end
    end
    if updated == 1 then
        ui.UpdateVisibleToolTips("buff")
    end
end

function Separate_buff_custom_BUFF_SEPARATEDLIST_ON_RELOAD(my_frame, my_msg)
    local frame = g.get_event_args(my_msg)
    Separate_buff_custom_frame_move()
    if g.settings.separate_buff_custom.use == 0 then
        INIT_BUFF_SEPARATEDLIST_UI(frame)
        frame:SetEventScript(ui.LBUTTONUP, "Separate_buff_custom_buff_separatedlist_save_pos")
    end
end

function Separate_buff_custom_restore_vanilla_position(frame)
    frame:EnableMove(1)
    frame:EnableHittestFrame(1)
    local path_format = string.format("../release/addon_setting/buff_separatedlist/%s/settings.json", g.active_id)
    local settings = g.load_json(path_format)
    if settings and settings.pc_id and settings.pc_id[g.cid] and settings.pc_id[g.cid].pos then
        local pos = settings.pc_id[g.cid].pos
        frame:MoveFrame(pos.x, pos.y)
    end
end

function Separate_buff_custom_frame_move()
    local frame = ui.GetFrame("buff_separatedlist")
    frame:StopUpdateScript("_FRAME_AUTOPOS")
    frame:SetEventScript(ui.LBUTTONUP, "Separate_buff_custom_end_drag")
    if g.settings.separate_buff_custom.use == 0 then
        Separate_buff_custom_restore_vanilla_position(frame)
        return
    end
    if (g.separate_buff_custom_settings.location_share == 0 and g.separate_buff_custom_settings.tracking == 0) then
        Separate_buff_custom_restore_vanilla_position(frame)
        return
    end
    if g.separate_buff_custom_settings.tracking == 1 then
        frame:EnableMove(0)
        frame:EnableHittestFrame(0)
        local my_handle = session.GetMyHandle()
        FRAME_AUTO_POS_TO_OBJ(frame, my_handle, 30, -40, 3, 1)
        return
    end
    if g.separate_buff_custom_settings.location_share == 1 then
        frame:EnableMove(g.separate_buff_custom_settings.move)
        frame:EnableHittestFrame(g.separate_buff_custom_settings.move)
        frame:MoveFrame(g.separate_buff_custom_settings.x, g.separate_buff_custom_settings.y)
        return
    end
end

function Separate_buff_custom_end_drag(frame)
    if g.separate_buff_custom_settings.location_share == 1 then
        g.separate_buff_custom_settings.x = frame:GetX()
        g.separate_buff_custom_settings.y = frame:GetY()
        Separate_buff_custom_save_settings()
    end
end

function Separate_buff_custom_BUFF_SEPARATEDLIST_CTRLSET_CREATE(my_frame, my_msg)
    if g.settings.separate_buff_custom.use == 0 then
        return
    end
    local frame, my_handle, buff_index, buff_id = g.get_event_args(my_msg)
    if ui.buff.IsBuffSeparate(buff_id) == 1 then
        return
    end
    local setting = g.separate_buff_custom_settings.sep_buffs[tostring(buff_id)]
    if setting and setting.display == 1 then
        local buff = info.GetBuff(my_handle, buff_id)
        local buff_cls = GetClassByType("Buff", buff_id)
        CTRLSET_CREATE(frame, my_handle, buff, buff_cls, buff_index, buff_id)
        local gbox = GET_CHILD_RECURSIVELY(frame, "buffGBox")
        if gbox then
            local ctrl_set = GET_CHILD(gbox, "BUFFSLOT_buff" .. buff_id)
            if ctrl_set then
                local slot = GET_CHILD_RECURSIVELY(ctrl_set, "slot")
                if buff_cls.OverBuff <= buff.over then
                    if setting.with_effect == 1 and not g.separate_buff_custom_temp_buffs[tostring(buff_id)] then
                        local my_handle = session.GetMyHandle()
                        local actor = world.GetActor(my_handle)
                        effect.PlayActorEffect(actor, 'F_pattern025_loop', 'None', 1.0, 1.5)
                        imcSound.PlaySoundEvent("sys_cube_open_jackpot")
                        g.separate_buff_custom_temp_buffs[tostring(buff_id)] = true
                    end
                    slot:SetText('{s30}{ol}{#FF0000}' .. buff.over, 'count', ui.RIGHT, ui.BOTTOM, 0, 0)
                elseif buff.over > 1 then
                    slot:SetText('{s30}{ol}{b}' .. buff.over, 'count', ui.RIGHT, ui.BOTTOM, 0, 0)
                end
                slot:AdjustFontSizeByWidth(30)
            end
        end
    end
end

function Separate_buff_custom_BUFF_SEPARATEDLIST_CTRLSET_REMOVE(my_frame, my_msg)
    if g.settings.separate_buff_custom.use == 0 then
        return
    end
    local frame, my_handle, buff_index, buff_id = g.get_event_args(my_msg)
    local buff_cls = GetClassByType("Buff", buff_id)
    if buff_cls then
        local setting = g.separate_buff_custom_settings.sep_buffs[tostring(buff_id)]
        if setting and setting.display == 1 then
            g.separate_buff_custom_temp_buffs[tostring(buff_id)] = false
            CTRLSET_REMOVE(frame, "buff", buff_id)
        end
    end
end

function Separate_buff_custom_settings(buff_list, ctrl, ctrl_text)
    local buff_list = ui.GetFrame(addon_name_lower .. "separate_buff_custom_buff_list")
    local search_edit
    if not buff_list then
        buff_list = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "separate_buff_custom_buff_list", 0, 0, 0, 0)
        AUTO_CAST(buff_list)
        buff_list:SetSkinName("test_frame_low")
        buff_list:SetPos(150, 10)
        buff_list:SetLayerLevel(999)
        search_edit = buff_list:CreateOrGetControl("edit", "search_edit", 40, 10, 305, 38)
        AUTO_CAST(search_edit)
        search_edit:SetFontName("white_18_ol")
        search_edit:SetTextAlign("left", "center")
        search_edit:SetSkinName("inventory_serch")
        search_edit:SetEventScript(ui.ENTERKEY, "Separate_buff_custom_buff_list_search")
        local search_btn = search_edit:CreateOrGetControl("button", "search_btn", 0, 0, 40, 38)
        AUTO_CAST(search_btn)
        search_btn:SetImage("inven_s")
        search_btn:SetGravity(ui.RIGHT, ui.TOP)
        search_btn:SetEventScript(ui.LBUTTONUP, "Separate_buff_custom_buff_list_search")
        local location = buff_list:CreateOrGetControl('checkbox', 'location', 355, 10, 30, 30)
        AUTO_CAST(location)
        location:SetTextTooltip(g.lang == "Japanese" and
                                    "{ol}チェックすると{nl}セパレートバフフレームの位置を各キャラ共有" or
                                    "{ol}If checked{nl}location of the separated buff frame{nl}is shared by all characters")
        location:SetCheck(g.separate_buff_custom_settings.location_share or 0)
        location:SetEventScript(ui.LBUTTONUP, "Separate_buff_custom_buff_toggle")
        local move = buff_list:CreateOrGetControl('checkbox', 'move', 390, 10, 30, 30)
        AUTO_CAST(move)
        move:SetTextTooltip(g.lang == "Japanese" and
                                "{ol}チェックすると{nl}セパレートバフフレームの位置を固定" or
                                "{ol}If checked{nl}{nl}fixes the position of the separate buff frame")
        move:SetCheck(g.separate_buff_custom_settings.move == 1 and 0 or 1)
        move:SetEventScript(ui.LBUTTONUP, "Separate_buff_custom_buff_toggle")
        local tracking = buff_list:CreateOrGetControl('checkbox', 'tracking', 425, 10, 30, 30)
        AUTO_CAST(tracking)
        tracking:SetTextTooltip(g.lang == "Japanese" and
                                    "{ol}チェックすると{nl}セパレートバフフレーム追従モード" or
                                    "{ol}If checked{nl}{nl}Separate Buff Frame Tracking Mode")
        tracking:SetCheck(g.separate_buff_custom_settings.tracking or 0)
        tracking:SetEventScript(ui.LBUTTONUP, "Separate_buff_custom_buff_toggle")
        local close = buff_list:CreateOrGetControl('button', 'close', 0, 0, 20, 20)
        AUTO_CAST(close)
        close:SetImage("testclose_button")
        close:SetGravity(ui.RIGHT, ui.TOP)
        close:SetEventScript(ui.LBUTTONUP, "Separate_buff_custom_frame_close")
    else
        search_edit = GET_CHILD_RECURSIVELY(buff_list, "search_edit")
    end
    if ctrl_text then
        search_edit:SetText(ctrl_text)
    end
    local buff_list_gb = buff_list:CreateOrGetControl("groupbox", "buff_list_gb", 10, 50, 480,
        buff_list:GetHeight() - 60)
    AUTO_CAST(buff_list_gb)
    buff_list_gb:SetSkinName("bg")
    buff_list_gb:RemoveAllChild()
    local cls_list, count = GetClassList("Buff")
    local search_lower = (ctrl_text and ctrl_text ~= "") and string.lower(ctrl_text) or nil
    local all_buffs = {}
    for i = 0, count - 1 do
        local buff_cls = GetClassByIndexFromList(cls_list, i)
        if buff_cls then
            local buff_name = dictionary.ReplaceDicIDInCompStr(buff_cls.Name)
            if not search_lower or string.find(string.lower(buff_name), search_lower) then
                local image_name = GET_BUFF_ICON_NAME(buff_cls)
                if image_name ~= "icon_None" and buff_name ~= "None" then
                    local buff_id_str = tostring(buff_cls.ClassID)
                    local setting = g.separate_buff_custom_settings.sep_buffs[buff_id_str]
                    local display = 0
                    local with_effect = 0
                    if setting then
                        display = setting.display or 0
                        with_effect = setting.with_effect or 0
                    end
                    table.insert(all_buffs, {
                        cls = buff_cls,
                        name = buff_name,
                        image = image_name,
                        display = display,
                        with_effect = with_effect
                    })
                end
            end
        end
    end
    table.sort(all_buffs, function(a, b)
        if a.display == 1 and b.display ~= 1 then
            return true
        elseif a.display ~= 1 and b.display == 1 then
            return false
        else
            return a.cls.ClassID < b.cls.ClassID
        end
    end)
    g.separate_buff_custom_x = g.separate_buff_custom_x or 0
    local y = 0
    for _, buff_data in ipairs(all_buffs) do
        local buff_cls = buff_data.cls
        local buff_id = buff_cls.ClassID
        local buff_slot = buff_list_gb:CreateOrGetControl('slot', 'buffslot' .. buff_id, 10, y + 5, 30, 30)
        AUTO_CAST(buff_slot)
        SET_SLOT_IMG(buff_slot, buff_data.image)
        local icon = CreateIcon(buff_slot)
        AUTO_CAST(icon)
        icon:SetTooltipType('buff')
        icon:SetTooltipArg(buff_data.name, buff_id, 0)
        local with_effect = buff_list_gb:CreateOrGetControl('checkbox', 'with_effect' .. buff_id, 50, y + 10, 30, 30)
        AUTO_CAST(with_effect)
        with_effect:SetTextTooltip(g.lang == "Japanese" and "{ol}チェックするとエフェクト表示" or
                                       "{ol}If checked, show effect")
        with_effect:SetCheck(buff_data.with_effect or 0)
        with_effect:SetEventScript(ui.LBUTTONUP, "Separate_buff_custom_buff_toggle")
        with_effect:SetEventScriptArgNumber(ui.LBUTTONUP, buff_id)
        with_effect:SetEventScriptArgString(ui.LBUTTONUP, search_edit:GetText())
        local buff_check = buff_list_gb:CreateOrGetControl('checkbox', 'buff_check' .. buff_id, 80, y + 10, 200, 30)
        AUTO_CAST(buff_check)
        buff_check:SetText("{ol}" .. buff_id .. " : " .. buff_data.name)
        if g.separate_buff_custom_x < buff_check:GetWidth() then
            g.separate_buff_custom_x = buff_check:GetWidth()
        end
        buff_check:SetTextTooltip(g.lang == "Japanese" and
                                      "{ol}チェックするとセパレートバフフレームに表示" or
                                      "{ol}If checked, display on the separated buff frame")
        buff_check:SetCheck(buff_data.display or 0)
        buff_check:SetEventScript(ui.LBUTTONUP, "Separate_buff_custom_buff_toggle")
        buff_check:SetEventScriptArgNumber(ui.LBUTTONUP, buff_id)
        buff_check:SetEventScriptArgString(ui.LBUTTONUP, search_edit:GetText())
        y = y + 35
    end
    buff_list:Resize(g.separate_buff_custom_x + 20, 1060)
    buff_list_gb:Resize(g.separate_buff_custom_x, buff_list:GetHeight() - 60)
    buff_list_gb:SetScrollPos(0)
    buff_list:ShowWindow(1)
end

function Separate_buff_custom_buff_toggle(buff_list, ctrl, ctrl_text, buff_id)
    local str_id = tostring(buff_id)
    local changed = false
    if not g.separate_buff_custom_settings.sep_buffs[str_id] then
        g.separate_buff_custom_settings.sep_buffs[str_id] = {}
    end
    local setting = g.separate_buff_custom_settings.sep_buffs[str_id]
    if string.find(ctrl:GetName(), "buff_check") then
        if ctrl:IsChecked() == 1 then
            setting.display = 1
        else
            g.separate_buff_custom_settings.sep_buffs[str_id] = nil
            changed = true
        end
    elseif string.find(ctrl:GetName(), "with_effect") then
        setting.with_effect = ctrl:IsChecked()
    else
        if ctrl:GetName() == "location" then
            g.separate_buff_custom_settings.location_share = ctrl:IsChecked()
            local buff_separatedlist = ui.GetFrame("buff_separatedlist")
            g.separate_buff_custom_settings.x = buff_separatedlist:GetX()
            g.separate_buff_custom_settings.y = buff_separatedlist:GetY()
        elseif ctrl:GetName() == "move" then
            g.separate_buff_custom_settings.move = ctrl:IsChecked() == 1 and 0 or 1
        elseif ctrl:GetName() == "tracking" then
            g.separate_buff_custom_settings.tracking = ctrl:IsChecked()
        end
        Separate_buff_custom_frame_move()
    end
    Separate_buff_custom_save_settings()
    if changed then
        Separate_buff_custom_settings(buff_list, ctrl, ctrl_text)
    end
end

function Separate_buff_custom_buff_list_search(buff_list, ctrl, ctrl_text, num)
    local buff_list = ui.GetFrame(addon_name_lower .. "separate_buff_custom_buff_list")
    local search_edit = GET_CHILD_RECURSIVELY(buff_list, "search_edit")
    local ctrl_text = search_edit:GetText()
    if ctrl_text ~= "" then
        Separate_buff_custom_settings(buff_list, ctrl, ctrl_text)
    else
        Separate_buff_custom_settings(buff_list, ctrl, "")
    end
end

function Separate_buff_custom_frame_close(buff_list)
    ui.DestroyFrame(buff_list:GetName())
end
-- separate_buff_custom ここまで

