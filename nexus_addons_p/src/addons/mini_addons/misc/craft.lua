-- 製造自動セット
function Mini_addons_itemcraft_item_set(item_set, slot, recipe_item_cnt_str, cls_id, current_make_count)
    imcSound.PlaySoundEvent("inven_equip")
    AUTO_CAST(slot)
    local need_count = tonumber(recipe_item_cnt_str)
    local item_name = item_set:GetUserValue("ClassName")
    local inv_item = session.GetInvItemByName(item_name)
    if true == inv_item.isLockState then
        ui.SysMsg(ClMsg("MaterialItemIsLock"))
        return 0
    end
    local next_make_count = current_make_count
    if inv_item.type == cls_id and inv_item.count >= need_count then
        local possible_count = math.floor(inv_item.count / need_count)
        if next_make_count ~= 0 then
            if next_make_count == nil or next_make_count > possible_count then
                next_make_count = possible_count
            end
        end
        session.AddItemID(inv_item:GetIESID(), need_count)
        local icon = slot:GetIcon()
        icon:SetColorTone("FFFFFFFF")
        item_set:SetUserValue("MATERIAL_IS_SELECTED", "selected")
        local number = slot:CreateOrGetControl("richtext", "number", 0, 0, slot:GetWidth(), 20)
        AUTO_CAST(number)
        number:SetText("{ol}" .. inv_item.count)
    else
        next_make_count = 0
    end
    local btn = GET_CHILD(item_set, "btn", "ui::CButton")
    if btn then
        AUTO_CAST(btn)
        btn:ShowWindow(0)
    end
    local inv_frame = ui.GetFrame("inventory")
    INVENTORY_UPDATE_ICONS(inv_frame)
    return next_make_count
end

function Mini_addons_CRAFT_RECIPE_FOCUS(frame, msg)
    if g.settings.auto_craft == 0 then
        return
    end
    local page, ctrl_set = g.get_event_args(msg)
    local make_count = nil
    for i = 1, 5 do
        local item_set = GET_CHILD(ctrl_set, "EACHMATERIALITEM_" .. i)
        if not item_set then
            break
        end
        AUTO_CAST(item_set)
        local slot = GET_CHILD(item_set, "slot")
        AUTO_CAST(slot)
        DESTROY_CHILD_BYNAME(slot, "number")
        local top_frame = page:GetTopParentFrame()
        local id_space = top_frame:GetUserValue("IDSPACE")
        local recipe_cls = GetClass(id_space, ctrl_set:GetName())
        local recipe_item_cnt, inv_item_cnt, drag_recipe_item, inv_item, recipe_item_lv, inv_item_list =
            GET_RECIPE_MATERIAL_INFO(recipe_cls, i)
        local recipe_item_cnt_str = tostring(recipe_item_cnt)
        local cls_id = drag_recipe_item.ClassID
        make_count = Mini_addons_itemcraft_item_set(item_set, slot, recipe_item_cnt_str, cls_id, make_count)
    end
    local top_frame = page:GetTopParentFrame()
    local up_down = GET_CHILD_RECURSIVELY(top_frame, "upDown", "ui::CNumUpDown")
    up_down:SetNumberValue(make_count or 0)
end

function Mini_addons_CRAFT_START_CRAFT(frame, msg)
    if g.settings.auto_craft == 0 then
        return
    end
    local item_craft = ui.GetFrame("itemcraft")
    if item_craft then
        item_craft:RunUpdateScript("CREATE_CRAFT_ARTICLE", 8.2)
    end
end
