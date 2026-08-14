-- チャットフレーム改造
function Mini_addons_chat_frame_drop(chat)
    g.settings.chat_xy.x = chat:GetX()
    g.settings.chat_xy.y = chat:GetY()
    Mini_addons_save_settings()
end

function Mini_addons_my_pos()
    local map_frame = ui.GetFrame("map")
    local map_pic = GET_CHILD(map_frame, "map")
    local my_pos = GET_CHILD(map_frame, "my")
    local x, y = GET_C_XY(my_pos)
    x = x + (my_pos:GetWidth() / 2) - map_pic:GetX()
    y = y + (my_pos:GetHeight() / 2) - map_pic:GetY()
    local map_name = session.GetMapName()
    local map_prop = geMapTable.GetMapProp(map_name)
    local worldPos = map_prop:MinimapPosToWorldPos(x, y, map_pic:GetWidth(), map_pic:GetHeight())
    LINK_MAP_POS(map_name, worldPos.x, worldPos.y)
end

function Mini_addons_toggle_inventory()
    ui.ToggleFrame("inventory")
end

function Mini_addons_update_chat_frame()
    local chat = ui.GetFrame("chat")
    local mainchat = GET_CHILD(chat, "mainchat")
    local edit_bg = GET_CHILD(chat, "edit_bg")
    local edit_to_bg = GET_CHILD(chat, "edit_to_bg")
    AUTO_CAST(mainchat)
    AUTO_CAST(edit_bg)
    AUTO_CAST(edit_to_bg)
    chat:RemoveChild("pos_btn")
    chat:RemoveChild("party_btn")
    chat:RemoveChild("item_btn")
    chat:SetEventScript(ui.LBUTTONUP, "Mini_addons_chat_frame_drop")
    if g.settings.chat_new_btn == 0 then
        chat:Resize(chat:GetOriginalWidth(), chat:GetOriginalHeight())
        mainchat:SetGravity(ui.LEFT, ui.TOP)
        chat:SetPos(g.settings.chat_xy.x or chat:GetX(), g.settings.chat_xy.y or chat:GetY())
        return
    end
    chat:Resize(585, chat:GetOriginalHeight())
    edit_bg:Resize(567, 36)
    mainchat:Resize(585, mainchat:GetOriginalHeight())
    mainchat:SetGravity(ui.LEFT, ui.TOP)
    edit_to_bg:SetGravity(ui.LEFT, ui.TOP)
    local button_emo = GET_CHILD(chat, "button_emo")
    local base_x = button_emo:GetX() - 35
    local function create_btn(name, x_offset, img, script, w, h)
        local btn = chat:CreateOrGetControl("button", name, 0, 0, 0, 0)
        AUTO_CAST(btn)
        btn:SetPos(base_x + x_offset, 0)
        btn:SetClickSound("button_click")
        btn:SetOverSound("button_cursor_over_2")
        btn:SetAnimation("MouseOnAnim", "btn_mouseover")
        btn:SetAnimation("MouseOffAnim", "btn_mouseoff")
        btn:SetEventScript(ui.LBUTTONDOWN, script)
        if img:find("{") then
            btn:SetText(img)
            btn:SetSkinName("textbutton")
        else
            btn:SetImage(img)
        end
        btn:Resize(w, h)
        return btn
    end
    create_btn("pos_btn", 0, "button_pos_img", "Mini_addons_my_pos", 39, 39)
    create_btn("party_btn", -32, "btn_partyshare", "LINK_PARTY_INVITE", 36, 36)
    create_btn("item_btn", -70, "{img sysmenu_inv 42 42}", "Mini_addons_toggle_inventory", 40, 37)
    chat:SetPos(g.settings.chat_xy.x or chat:GetX(), g.settings.chat_xy.y or chat:GetY())
    chat:Invalidate()
end

