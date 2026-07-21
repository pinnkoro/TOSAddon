-- my_buffs_control ここから
function My_buffs_control_save_settings()
    local json_data = {
        lock = g.my_buffs_control_settings.lock,
        default_x = g.my_buffs_control_settings.default_x,
        default_y = g.my_buffs_control_settings.default_y,
        custom_x = g.my_buffs_control_settings.custom_x,
        custom_y = g.my_buffs_control_settings.custom_y,
        ver = g.my_buffs_control_settings.ver
    }
    g.save_json(g.my_buffs_control_path, json_data)
    local file = io.open(g.my_buffs_control_dat_path, "w")
    if file then
        local lines = {}
        for id, val in pairs(g.my_buffs_control_settings.buffs) do
            if val ~= nil then
                table.insert(lines, tostring(id) .. ":::" .. tostring(val))
            end
        end
        if #lines > 0 then
            file:write(table.concat(lines, "\n"))
        end
        file:close()
    end
end

function My_buffs_control_load_settings()
    g.my_buffs_control_path = string.format("../addons/%s/%s/my_buffs_control.json", addon_name_lower, g.active_id)
    g.my_buffs_control_dat_path = string.format("../addons/%s/%s/my_buffs_control.dat", addon_name_lower, g.active_id)
    g.my_buffs_control_old_path = string.format("../addons/%s/settings_2503.json", "my_buffs")
    local settings = g.load_json(g.my_buffs_control_path)
    local ver = 1.2
    local need_init = false
    if not settings or not settings.ver or settings.ver < ver then
        settings = {
            lock = true,
            default_x = 20,
            default_y = 130,
            custom_x = 20,
            custom_y = 130,
            ver = ver,
            buffs = {}
        }
        need_init = true
    end
    if not settings.buffs then
        settings.buffs = {}
    end
    if need_init then
        local old_settings = g.load_json(g.my_buffs_control_old_path)
        if old_settings and old_settings.buffs then
            for id, is_visible in pairs(old_settings.buffs) do
                settings.buffs[tostring(id)] = (is_visible == true) and 1 or 0
            end
        end
        local cls_list, count = GetClassList("Buff")
        for i = 0, count - 1 do
            local buff_cls = GetClassByIndexFromList(cls_list, i)
            if buff_cls then
                if buff_cls.Group1 ~= 'Debuff' and buff_cls.Group1 ~= 'Deuff' then
                    local buff_id = tostring(buff_cls.ClassID)
                    -- 既に設定がある(移行された)場合は上書きしない
                    if settings.buffs[buff_id] == nil then
                        settings.buffs[buff_id] = 1
                    end
                end
            end
        end
    else
        local file = io.open(g.my_buffs_control_dat_path, "r")
        if file then
            for line in file:lines() do
                local id, val = string.match(line, "^(.-):::(.*)$")
                if id and val then
                    settings.buffs[id] = tonumber(val)
                end
            end
            file:close()
        end
    end
    g.my_buffs_control_settings = settings
    if need_init then
        My_buffs_control_save_settings()
    end
end

function my_buffs_control_on_init()
    if not g.my_buffs_control_settings then
        My_buffs_control_load_settings()
    end
    local old_func = g.settings.my_buffs_control.old_init_func
    if _G[old_func] then
        return
    end
    if g.settings.my_buffs_control.use == 1 then
        My_buffs_control_frame()
    else
        My_buffs_control_reset_ui()
    end
    if g.my_buffs_control_is_change then
        My_buffs_control_save_settings()
        g.my_buffs_control_is_change = false
    end
    if g.get_map_type() == 'City' then
        return
    end
    g.setup_hook_and_event(g.addon, "BUFF_ON_MSG", "My_buffs_control_BUFF_ON_MSG", true)
    g.addon:RegisterMsg("BUFF_ADD", "My_buffs_control_BUFF_ADD")
    My_buffs_control_common_buff_msg()
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    _nexus_addons_p:RunUpdateScript("My_buffs_control_delayed_init", 1.0)
end

function My_buffs_control_delayed_init(_nexus_addons_p)
    My_buffs_control_common_buff_msg()
    return 0
end

function My_buffs_control_common_buff_msg()
    local buff_frame = ui.GetFrame("buff")
    local my_handle = session.GetMyHandle()
    local buff_count = info.GetBuffCount(my_handle)
    if g.settings.my_buffs_control.use == 0 then
        if type(_G["COMMON_BUFF_MSG_OLD"]) == "function" then
            COMMON_BUFF_MSG_OLD(buff_frame, "CLEAR", 0, 0, s_buff_ui, 0)
        else
            COMMON_BUFF_MSG(buff_frame, "CLEAR", 0, 0, s_buff_ui, 0)
        end
        for i = 0, buff_count - 1 do
            local buff = info.GetBuffIndexed(my_handle, i)
            if buff then
                g.FUNCS["BUFF_ON_MSG"](buff_frame, "BUFF_ADD", tostring(buff.index), buff.buffID)
            end
        end
    else
        local displayed_buffs = {}
        for group_index = 0, s_buff_ui["buff_group_cnt"] do
            if s_buff_ui["slotlist"][group_index] and s_buff_ui["slotcount"][group_index] then
                for i = 0, s_buff_ui["slotcount"][group_index] - 1 do
                    local slot = s_buff_ui["slotlist"][group_index][i]
                    if slot:IsVisible() == 1 then
                        local icon = slot:GetIcon()
                        if icon then
                            local info = icon:GetInfo()
                            displayed_buffs[info.type] = {
                                index = tostring(icon:GetUserIValue("BuffIndex"))
                            }
                        end
                    end
                end
            end
        end
        local player_buffs = {}
        for i = 0, buff_count - 1 do
            local buff = info.GetBuffIndexed(my_handle, i)
            if buff and BUFF_CHECK_SEPARATELIST(buff.buffID) ~= true then
                local is_debuff = false
                local cls = GetClassByType('Buff', buff.buffID)
                if cls and (cls.Group1 == 'Debuff' or cls.Group1 == 'Deuff') then
                    is_debuff = true
                end
                player_buffs[buff.buffID] = {
                    index = buff.index,
                    is_debuff = is_debuff
                }
            end
        end
        for buff_id, data in pairs(displayed_buffs) do
            local str_buff_id = tostring(buff_id)
            local current_buff = player_buffs[buff_id]
            if current_buff then
                if not current_buff.is_debuff and g.my_buffs_control_settings.buffs[str_buff_id] ~= 1 then
                    if type(_G["COMMON_BUFF_MSG_OLD"]) == "function" then
                        COMMON_BUFF_MSG_OLD(buff_frame, "REMOVE", buff_id, my_handle, s_buff_ui, data.index)
                    else
                        COMMON_BUFF_MSG(buff_frame, "REMOVE", buff_id, my_handle, s_buff_ui, data.index)
                    end
                end
            end
        end
        for buff_id, data in pairs(player_buffs) do
            local str_buff_id = tostring(buff_id)
            if not displayed_buffs[buff_id] then
                if data.is_debuff or g.my_buffs_control_settings.buffs[str_buff_id] == 1 then
                    if type(_G["COMMON_BUFF_MSG_OLD"]) == "function" then
                        COMMON_BUFF_MSG_OLD(buff_frame, "ADD", buff_id, my_handle, s_buff_ui, data.index)
                    else
                        COMMON_BUFF_MSG(buff_frame, "ADD", buff_id, my_handle, s_buff_ui, data.index)
                    end
                end
            end
        end
    end
end

function My_buffs_control_BUFF_ON_MSG(my_frame, my_msg)
    local frame, msg, str, num = g.get_event_args(my_msg)
    if g.settings.my_buffs_control.use == 0 then
        return
    end
    if g.get_map_type() == 'City' then
        return
    end
    local buff = ui.GetFrame("buff")
    local handle = session.GetMyHandle()
    local str_buff_id = tostring(num)
    local is_debuff = false
    local cls = GetClassByType('Buff', num)
    if cls and (cls.Group1 == 'Debuff' or cls.Group1 == 'Deuff') then
        is_debuff = true
    end
    if not is_debuff and g.my_buffs_control_settings.buffs[str_buff_id] ~= 1 then
        if BUFF_CHECK_SEPARATELIST(num) == true then
            return
        end
        if type(_G["COMMON_BUFF_MSG_OLD"]) == "function" then
            COMMON_BUFF_MSG_OLD(frame, "REMOVE", num, handle, s_buff_ui, str)
        else
            COMMON_BUFF_MSG(frame, "REMOVE", num, handle, s_buff_ui, str)
        end
        MY_BUFF_TIME_UPDATE(buff)
        BUFF_RESIZE(buff, s_buff_ui)
        return
    end
end

function My_buffs_control_reset_ui()
    local buff = ui.GetFrame("buff")
    if buff then
        AUTO_CAST(buff)
        buff:SetPos(g.my_buffs_control_settings.default_x, g.my_buffs_control_settings.default_y)
        buff:RemoveChild("lock_slot")
        g.my_buffs_control_settings.lock = true
        buff:EnableHittestFrame(0)
        buff:EnableMove(0)
        buff:SetEventScript(ui.LBUTTONUP, "None")
    end
end

function My_buffs_control_frame()
    if g.settings.my_buffs_control.use == 0 then
        My_buffs_control_reset_ui()
        return
    end
    local buff = ui.GetFrame("buff")
    AUTO_CAST(buff)
    buff:SetEventScript(ui.LBUTTONUP, "My_buffs_control_end_drag")
    if g.get_map_type() ~= 'City' then
        buff:SetPos(g.my_buffs_control_settings.custom_x, g.my_buffs_control_settings.custom_y)
    else
        buff:SetPos(g.my_buffs_control_settings.default_x, g.my_buffs_control_settings.default_y)
    end
    buff:SetLayerLevel(61)
    buff:RemoveChild("lock_slot")
    local lock_slot = buff:CreateOrGetControl('slot', "lock_slot", 0, 0, 20, 30)
    AUTO_CAST(lock_slot)
    lock_slot:SetTextTooltip(g.lang == "Japanese" and
                                 "{ol}[MBC]{nl}左クリック:フレームを動かせる様に{nl} {nl}{#FF0000}街では全て表示します" or
                                 "{ol}[MBC]{nl}Left Click: Make frame movable{nl} {nl}{#FF0000}Show all in town")
    lock_slot:SetEventScript(ui.LBUTTONUP, "My_buffs_control_frame_lock")
    local lock = lock_slot:CreateOrGetControlSet('inv_itemlock', "lock", 0, 0)
    AUTO_CAST(lock)
    lock:SetGravity(ui.LEFT, ui.TOP)
    if g.my_buffs_control_settings.lock then
        lock:SetGrayStyle(0)
    else
        lock:SetGrayStyle(1)
    end
end

function My_buffs_control_end_drag(buff, ctrl, str, num)
    g.my_buffs_control_settings.custom_x = buff:GetX()
    g.my_buffs_control_settings.custom_y = buff:GetY()
    My_buffs_control_save_settings()
end

function My_buffs_control_frame_lock(buff, lock_slot)
    local lock = GET_CHILD(lock_slot, "lock")
    if g.my_buffs_control_settings.lock then
        g.my_buffs_control_settings.lock = false
        lock:SetGrayStyle(1)
        buff:EnableHittestFrame(1)
        buff:EnableMove(1)
    else
        g.my_buffs_control_settings.lock = true
        lock:SetGrayStyle(0)
        buff:EnableHittestFrame(0)
        buff:EnableMove(0)
    end
    My_buffs_control_save_settings()
end

function My_buffs_control_setting_menu()
    local list_frame_name = addon_name_lower .. "list_frame"
    local list_frame = ui.GetFrame(addon_name_lower .. "list_frame")
    local my_buffs_control_setting = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "my_buffs_control_setting",
        0, 0, 0, 0)
    my_buffs_control_setting:Resize(250, 180)
    my_buffs_control_setting:SetPos(list_frame:GetX() + list_frame:GetWidth(), list_frame:GetY())
    my_buffs_control_setting:SetSkinName("test_frame_low")
    my_buffs_control_setting:EnableHittestFrame(1)
    my_buffs_control_setting:EnableHitTest(1)
    my_buffs_control_setting:ShowWindow(1)
    my_buffs_control_setting:SetLayerLevel(999)
    local title_text = my_buffs_control_setting:CreateOrGetControl('richtext', 'title_text', 20, 15, 50, 30)
    AUTO_CAST(title_text)
    title_text:SetText("{ol}My Buffs Control Config")
    local close = my_buffs_control_setting:CreateOrGetControl("button", "close", 0, 0, 20, 20)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "My_buffs_control_frame_close")
    local gbox = my_buffs_control_setting:CreateOrGetControl("groupbox", "gbox", 10, 40,
        my_buffs_control_setting:GetWidth() - 20, my_buffs_control_setting:GetHeight() - 50)
    AUTO_CAST(gbox)
    gbox:SetSkinName("test_frame_midle_light")
    local list_open_btn = gbox:CreateOrGetControl('button', 'list_open_btn', 10, 10, 130, 30)
    AUTO_CAST(list_open_btn)
    list_open_btn:SetText("{ol}Buff list")
    list_open_btn:SetTextTooltip(g.lang == "Japanese" and "{ol}バフリスト表示" or "{ol}Buff list Open")
    list_open_btn:SetEventScript(ui.LBUTTONUP, "My_buffs_control_buff_list_open")
    local org_pos = gbox:CreateOrGetControl('button', 'org_pos', 10, 50, 130, 30)
    AUTO_CAST(org_pos)
    org_pos:SetText("Default Pos")
    org_pos:SetTextTooltip(g.lang == "Japanese" and "{ol}バフ欄の位置を元に戻します" or
                               "{ol}Restore the buff frame position to default")
    org_pos:SetEventScript(ui.LBUTTONUP, "My_buffs_control_original_position")
    local text = gbox:CreateOrGetControl('richtext', 'text', 10, 100, 150, 30)
    AUTO_CAST(text)
    text:SetText(g.lang == "Japanese" and "{ol}{#FF0000}※街では全て表示します" or
                     "{ol}{#FF0000}※Show all in town")
end

function My_buffs_control_original_position()
    local buff = ui.GetFrame("buff")
    buff:SetPos(g.my_buffs_control_settings.default_x, g.my_buffs_control_settings.default_y)
    g.my_buffs_control_settings.custom_x = g.my_buffs_control_settings.default_x
    g.my_buffs_control_settings.custom_y = g.my_buffs_control_settings.default_y
    My_buffs_control_save_settings()
end

function My_buffs_control_frame_close(frame, ctrl, str, num)
    ui.DestroyFrame(frame:GetName())
end

function My_buffs_control_buff_list_search(my_buffs_control, ctrl, ctrl_text, num)
    local search_edit = GET_CHILD_RECURSIVELY(my_buffs_control, "search_edit")
    local ctrl_text = search_edit:GetText()
    if ctrl_text ~= "" then
        My_buffs_control_buff_list_open(my_buffs_control, ctrl, ctrl_text)
    else
        My_buffs_control_buff_list_open(my_buffs_control, ctrl, "")
    end
end

function My_buffs_control_buff_list_open(frame, ctrl, ctrl_text, num)
    local my_buffs_control = ui.GetFrame(addon_name_lower .. "my_buffs_control")
    if not my_buffs_control then
        my_buffs_control = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "my_buffs_control", 0, 0, 0, 0)
        AUTO_CAST(my_buffs_control)
        my_buffs_control:SetSkinName("test_frame_low")
        my_buffs_control:Resize(500, 1060)
        my_buffs_control:SetPos(150, 10)
        my_buffs_control:SetLayerLevel(121)
        local search_edit = my_buffs_control:CreateOrGetControl("edit", "search_edit", 40, 10, 305, 38)
        AUTO_CAST(search_edit)
        search_edit:SetFontName("white_18_ol")
        search_edit:SetTextAlign("left", "center")
        search_edit:SetSkinName("inventory_serch")
        search_edit:SetEventScript(ui.ENTERKEY, "My_buffs_control_buff_list_search")
        local search_btn = search_edit:CreateOrGetControl("button", "search_btn", 0, 0, 40, 38)
        AUTO_CAST(search_btn)
        search_btn:SetImage("inven_s")
        search_btn:SetGravity(ui.RIGHT, ui.TOP)
        search_btn:SetEventScript(ui.LBUTTONUP, "My_buffs_control_buff_list_search")
        local close = my_buffs_control:CreateOrGetControl('button', 'close', 0, 0, 20, 20)
        AUTO_CAST(close)
        close:SetImage("testclose_button")
        close:SetGravity(ui.RIGHT, ui.TOP)
        close:SetEventScript(ui.LBUTTONUP, "My_buffs_control_frame_close")
    end
    local buff_list_gb = my_buffs_control:CreateOrGetControl("groupbox", "buff_list_gb", 10, 50, 480,
        my_buffs_control:GetHeight() - 60)
    AUTO_CAST(buff_list_gb)
    buff_list_gb:SetSkinName("bg")
    buff_list_gb:RemoveAllChild()
    local cls_list, count = GetClassList("Buff")
    local all_buffs = {}
    for i = 0, count - 1 do
        local buff_cls = GetClassByIndexFromList(cls_list, i)
        if buff_cls then
            if buff_cls.Group1 ~= 'Debuff' and buff_cls.Group1 ~= 'Deuff' then
                local buff_name = dictionary.ReplaceDicIDInCompStr(buff_cls.Name)
                if not ctrl_text or ctrl_text == "" or string.find(buff_name, ctrl_text) then
                    local image_name = GET_BUFF_ICON_NAME(buff_cls)
                    if image_name ~= "icon_None" and buff_name ~= "None" then
                        local is_checked = g.my_buffs_control_settings.buffs[tostring(buff_cls.ClassID)] == 1
                        table.insert(all_buffs, {
                            cls = buff_cls,
                            name = buff_name,
                            image = image_name,
                            is_checked = is_checked
                        })
                    end
                end
            else
                if g.my_buffs_control_settings.buffs[tostring(buff_cls.ClassID)] then
                    g.my_buffs_control_settings.buffs[tostring(buff_cls.ClassID)] = nil
                end
            end
        end
    end
    My_buffs_control_save_settings()
    table.sort(all_buffs, function(a, b)
        if a.is_checked and not b.is_checked then
            return true
        elseif not a.is_checked and b.is_checked then
            return false
        else
            return a.cls.ClassID < b.cls.ClassID
        end
    end)
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
        local buff_check = buff_list_gb:CreateOrGetControl('checkbox', 'buff_check' .. buff_id, 50, y + 10, 200, 30)
        AUTO_CAST(buff_check)
        buff_check:SetText("{ol}" .. buff_id .. " : " .. buff_data.name)
        buff_check:SetTextTooltip(g.lang == "Japanese" and "チェックを外すとバフを非表示にします" or
                                      "Unchecking hides the buff")
        buff_check:SetCheck(buff_data.is_checked and 1 or 0)
        buff_check:SetEventScript(ui.LBUTTONUP, "My_buffs_control_buff_toggle")
        buff_check:SetEventScriptArgString(ui.LBUTTONUP, buff_id)
        y = y + 35
    end
    my_buffs_control:ShowWindow(1)
end

function My_buffs_control_buff_toggle(frame, ctrl, str_buff_id, num)
    local is_check = ctrl:IsChecked()
    if is_check == 1 then
        g.my_buffs_control_settings.buffs[str_buff_id] = 1
    else
        g.my_buffs_control_settings.buffs[str_buff_id] = nil
    end
    My_buffs_control_save_settings()
end

function My_buffs_control_BUFF_ADD(frame, ctrl, str, buff_id)
    local str_buff_id = tostring(buff_id)
    local buff_cls = GetClassByType("Buff", buff_id)
    if buff_cls.Group1 ~= 'Debuff' and buff_cls.Group1 ~= 'Deuff' then
        if not g.my_buffs_control_settings.buffs[str_buff_id] then
            g.my_buffs_control_settings.buffs[str_buff_id] = 1
            g.my_buffs_control_is_change = true
        end
    end
end
-- my_buffs_control ここまで

