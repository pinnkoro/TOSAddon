-- グループチャット機能
function Mini_addons_CHAT_GROUPLIST_SELECT_LISTTYPE_(my_frame, my_msg)
    local type = g.get_event_args(my_msg)
    if type ~= 3 then
        return
    end
    Mini_addons_CHAT_GROUPLIST_SELECT_LISTTYPE(nil)
end

function Mini_addons_CHAT_GROUPLIST_SELECT_LISTTYPE(mini_addons)
    local chat_grouplist = ui.GetFrame("chat_grouplist")
    local listbtn_group = GET_CHILD_RECURSIVELY(chat_grouplist, "listbtn_group")
    local group_str = string.gsub(listbtn_group:GetText(), "{@st66b}", "")
    if not g.settings.group_caption then
        g.settings.group_caption = group_str
        Mini_addons_save_settings()
    end
    local chatlist_group = GET_CHILD_RECURSIVELY(chat_grouplist, "chatlist_group")
    local child_count = chatlist_group:GetChildCount()
    local delete_ids = {}
    for room_id, _ in pairs(g.settings.new_groups) do
        delete_ids[room_id] = true
    end
    local default_name = session.chat.GetNewGroupChatDefName()
    local pattern = "%s*%d+$"
    default_name = string.gsub(default_name, pattern, "")
    local chat = ui.GetFrame("chat")
    local groups = g.settings.new_groups
    if not groups then
        return
    end
    local changed = false
    local index = 1
    for i = 0, child_count - 1 do
        local child = chatlist_group:GetChildByIndex(i)
        local child_name = child:GetName()
        if string.find(child_name, "btn_") then
            local room_id = string.gsub(child_name, "btn_", "")
            if delete_ids[room_id] then
                delete_ids[room_id] = nil
            end
            local info = session.chat.GetByStringID(room_id)
            local title = GET_CHILD(child, "title")
            AUTO_CAST(title)
            local title_text = title:GetText()
            title_text = string.gsub(title_text, "%s*%[.-%]", "")
            local def_name = string.gsub(session.chat.GetNewGroupChatDefName(), "%s*%d+$", "")
            if string.find(title_text, def_name) then
                title_text = def_name .. index
                index = index + 1
            end
            local text = GET_CHILD_RECURSIVELY(child, "text")
            AUTO_CAST(text)
            local text_str = text:GetText()
            local color_code = "ffffff"
            if mini_addons and not text_str then
                return 1
            end
            if not string.find(text_str, "%{img ") then
                color_code = string.match(text_str, "%{#(%x+)%}")
            end
            if mini_addons and not color_code then
                return 1
            end
            if not groups[room_id] then
                groups[room_id] = {
                    name = title_text,
                    color = color_code,
                    room_id = room_id,
                    now = 0
                }
                changed = true
            end
            local name = groups[room_id].name
            title_text = ScpArgMsg("GroupChatTitleWithMemCnt", "Text", name, "Cnt", tostring(info:GetMemberCount()))
            title:SetText(title_text)
        end
    end
    if next(delete_ids) then
        for delete_room_id, _ in pairs(delete_ids) do
            g.settings.new_groups[delete_room_id] = nil
            changed = true
        end
    end
    if changed then
        Mini_addons_save_settings()
    end
    local is_start = chat_grouplist:GetUserValue("IS_START")
    if is_start == "None" then
        local active_room_id = ""
        for room_id, data in pairs(g.settings.new_groups) do
            active_room_id = room_id
            if data.now == 1 then
                active_room_id = room_id
                break
            end
        end
        Mini_addons_group_chat_setting(chat, active_room_id)
        chat_grouplist:SetUserValue("IS_START", "start")
    end
    local selected_chat_str = chat:GetUserValue("CHAT_TYPE_SELECTED_VALUE")
    local selected_chat_num = 0
    if selected_chat_str then
        if selected_chat_str == "None" then
            chat:SetUserValue("CHAT_TYPE_SELECTED_VALUE", "0")
        else
            selected_chat_num = tonumber(selected_chat_str) - 1
        end
        ui.SetChatType(selected_chat_num)
    end
    return 0
end

function Mini_addons_CHAT_GROUPLIST_OPTION_OK()
    local chat_grouplist_option = ui.GetFrame("chat_grouplist_option")
    local room_id = chat_grouplist_option:GetUserValue("ROOMID")
    local info = session.chat.GetByStringID(room_id)
    if not info then
        return
    end
    if info:GetRoomType() ~= 3 then
        return
    end
    local color_num = tonumber(chat_grouplist_option:GetUserValue("SelectedColor"))
    if color_num == 0 then
        local vmark = GET_CHILD_RECURSIVELY(chat_grouplist_option, "vmark")
        local x = vmark:GetX()
        color_num = x / 25 + 100
    end
    local color_cls = GetClassByType("ChatColorStyle", color_num)
    if color_cls then
        g.settings.new_groups[room_id].color = color_cls.TextColor
    end
    local groupname_edit = GET_CHILD_RECURSIVELY(chat_grouplist_option, "groupname_edit")
    local new_title = groupname_edit:GetText()
    g.settings.new_groups[room_id].name = new_title
    Mini_addons_now_chat_setting(room_id)
    Mini_addons_save_settings()
    CHAT_GROUPLIST_SELECT_LISTTYPE(3)
end

function Mini_addons_now_chat_setting(target_id)
    local target_group = g.settings.new_groups[target_id]
    if target_group and target_group.now ~= 1 then
        g.settings.new_groups[target_id].now = 1
        for room_id, data in pairs(g.settings.new_groups) do
            if room_id ~= target_id then
                data.now = 0
            end
        end
        Mini_addons_save_settings()
    end
end

function Mini_addons_group_chat_setting(chat, target_id)
    local group_data = g.settings.new_groups[target_id]
    if not group_data then
        return
    end
    local chat = ui.GetFrame("chat")
    AUTO_CAST(chat)
    local mainchat = chat:GetChild("mainchat")
    AUTO_CAST(mainchat)
    local edit_bg = GET_CHILD(chat, "edit_bg")
    AUTO_CAST(edit_bg)
    local button_type = GET_CHILD(chat, "button_type")
    AUTO_CAST(button_type)
    local edit_to_bg = GET_CHILD(chat, "edit_to_bg")
    AUTO_CAST(edit_to_bg)
    local title_to = GET_CHILD(edit_to_bg, "title_to")
    AUTO_CAST(title_to)
    ui.SetGroupChatTargetID(target_id)
    local btn_text = g.settings.group_caption
    local color = "{#" .. group_data.color .. "}"
    btn_text = color .. btn_text
    button_type:SetText("{ol}{s18}" .. color .. btn_text)
    local color_tone = "FF" .. group_data.color
    title_to:SetText(group_data.name)
    title_to:SetColorTone(color_tone)
    button_type:SetColorTone(color_tone)
    edit_to_bg:SetSkinName("bg")
    edit_to_bg:SetOffset(button_type:GetOriginalWidth(), edit_to_bg:GetOriginalY())
    local offset_x = button_type:GetOriginalWidth()
    title_to:SetEventScript(ui.LBUTTONUP, "Mini_addons_chat_group_context")
    title_to:SetEventScriptArgString(ui.LBUTTONUP, group_data.name)
    edit_to_bg:Resize(title_to:GetWidth() + 20, edit_to_bg:GetOriginalHeight())
    edit_to_bg:SetVisible(1)
    offset_x = offset_x + edit_to_bg:GetWidth()
    local width = mainchat:GetOriginalWidth() - edit_to_bg:GetWidth() - button_type:GetWidth()
    mainchat:Resize(width, mainchat:GetOriginalHeight())
    mainchat:SetOffset(offset_x, mainchat:GetOriginalY())
end

function Mini_addons_CHAT_SET_TO_TITLENAME_(chat)
    local target_id = chat:GetUserValue("ROOM_ID")
    Mini_addons_now_chat_setting(target_id)
    Mini_addons_group_chat_setting(chat, target_id)
end

function Mini_addons_CHAT_SET_TO_TITLENAME(my_frame, my_msg)
    local chat_type, target_id = g.get_event_args(my_msg) -- グルチャはchat_type=5 強調も何故か5
    local chat = ui.GetFrame("chat")
    local edit_to_bg = GET_CHILD(chat, "edit_to_bg")
    local title_to = GET_CHILD(edit_to_bg, "title_to")
    AUTO_CAST(title_to)
    if string.find(title_to:GetText(), "To.") then
        title_to:SetFontName("white_16_ol")
        title_to:SetColorTone("FFFFFFFF")
        edit_to_bg:SetSkinName("bg")
        title_to:SetEventScript(ui.LBUTTONUP, "")
        title_to:SetEventScriptArgString(ui.LBUTTONUP, "None")
        return
    end
    if chat_type ~= 5 then
        return
    end
    local selected_chat_str = chat:GetUserValue("CHAT_TYPE_SELECTED_VALUE")
    if selected_chat_str ~= "5" then
        return
    end
    local group_data = g.settings.new_groups[target_id]
    if not group_data or not next(group_data) then
        return
    end
    title_to:SetEventScript(ui.LBUTTONUP, "Mini_addons_chat_group_context")
    title_to:SetEventScriptArgString(ui.LBUTTONUP, group_data.name)
    chat:SetUserValue("ROOM_ID", target_id)
    edit_to_bg:SetVisible(0)
    chat:RunUpdateScript("Mini_addons_CHAT_SET_TO_TITLENAME_", 0.05)
end

function Mini_addons_change_title_name(target_id)
    local chat = ui.GetFrame("chat")
    Mini_addons_now_chat_setting(target_id)
    Mini_addons_group_chat_setting(chat, target_id)
end

function Mini_addons_chat_group_context(parent, title_to, target_name, num)
    local context = ui.CreateContextMenu("select_group", "{ol}GROUP SELECT", 0, 0, 0, 0)
    for room_id, data in pairs(g.settings.new_groups) do
        local color = data.color
        color = "{#" .. data.color .. "}"
        local name = data.name
        if name ~= target_name then
            local scp = string.format("Mini_addons_change_title_name('%s')", room_id)
            ui.AddContextMenuItem(context, color .. name, scp)
        end
    end
    ui.OpenContextMenu(context)
end
