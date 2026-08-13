function Mini_addons_INVENTORY_OP_POP(my_frame, my_msg)
    if g.settings.chat_new_btn == 0 then
        return
    end
    local chat = ui.GetFrame("chat")
    if chat:IsVisible() == 0 then
        return
    end
    if keyboard.IsKeyPressed("LCTRL") == 1 then
        return
    end
    local frame, slot, str, num = g.get_event_args(my_msg)
    local icon = slot:GetIcon()
    local icon_info = icon:GetInfo()
    local iesid = icon_info:GetIESID()
    local inv_item = session.GetInvItemByGuid(iesid)
    if inv_item then
        LINK_ITEM_TEXT(inv_item)
    end
end
