-- インベントリを改造
function Mini_addons_inventory_open_func(frame, msg)
    g.inven_tbl = g.inven_tbl or {}
    local inventory = ui.GetFrame("inventory")
    local tab = GET_CHILD_RECURSIVELY(inventory, "inventype_Tab")
    if not tab then
        return 1
    end
    local tab_index = tab:GetSelectItemIndex()
    if tab_index ~= 0 and tab_index ~= 3 and tab_index ~= 5 and tab_index ~= 1 and tab_index ~= 2 and tab_index ~= 4 and
        tab_index ~= 6 then
        return 1
    end
    local group = GET_CHILD_RECURSIVELY(inventory, "inventoryGbox", "ui::CGroupBox")
    if not group then
        return 1
    end
    local trees_to_process = {}
    if tab_index == 0 then
        for i = 1, #g_invenTypeStrList do
            local tab_name = g_invenTypeStrList[i]
            local tree_box = GET_CHILD_RECURSIVELY(group, "treeGbox_" .. tab_name, "ui::CGroupBox")
            if tree_box then
                local tree = GET_CHILD_RECURSIVELY(tree_box, "inventree_" .. tab_name, "ui::CTreeControl")
                if tree then
                    table.insert(trees_to_process, tree)
                end
            end
        end
    else
        local tab_name = g_invenTypeStrList[tab_index + 1]
        if tab_name then
            local tree_box = GET_CHILD_RECURSIVELY(group, "treeGbox_" .. tab_name, "ui::CGroupBox")
            if tree_box then
                local tree = GET_CHILD_RECURSIVELY(tree_box, "inventree_" .. tab_name, "ui::CTreeControl")
                if tree then
                    table.insert(trees_to_process, tree)
                end
            end
        end
    end
    for _, tree in ipairs(trees_to_process) do
        local recipe_ssets = {}
        for i = 0, tree:GetChildCount() - 1 do
            local child = tree:GetChildByIndex(i)
            if child and string.find(child:GetName(), "sset_Recipe", 1, true) then
                table.insert(recipe_ssets, child)
            end
        end
        for _, recipe_slot_set in ipairs(recipe_ssets) do
            local child_count = recipe_slot_set:GetChildCount()
            for i = 0, child_count - 1 do
                local slot = recipe_slot_set:GetChildByIndex(i)
                if slot then
                    AUTO_CAST(slot)
                    local icon = slot:GetIcon()
                    if icon then
                        local info = icon:GetInfo()
                        local iesid = info:GetIESID()
                        local inv_item = GET_ITEM_BY_GUID(iesid)
                        local inv_index = inv_item.invIndex
                        local unique_key = iesid .. "_" .. inv_index
                        if not g.inven_tbl[unique_key] or msg ~= "INV_ITEM_ADD" then
                            g.inven_tbl[unique_key] = true
                            if inv_item then
                                local item_obj = GetIES(inv_item:GetObject())
                                local item_cls = GetClassByType("Item", item_obj.ClassID)
                                if item_cls then
                                    local recipe_cls = GetClass("Recipe", item_cls.ClassName)
                                    if recipe_cls then
                                        local target_item_cls = GetClass("Item", recipe_cls.TargetItem)
                                        if target_item_cls then
                                            local image = nil
                                            if g.settings.inventory_mod == 1 then
                                                local image = GET_ITEM_ICON_IMAGE(target_item_cls)
                                                local recipe_pic =
                                                    slot:CreateOrGetControl("picture", "recipe_pic" .. i, 0, 0, 25, 25)
                                                AUTO_CAST(recipe_pic)
                                                recipe_pic:SetEnableStretch(1)
                                                recipe_pic:SetGravity(ui.RIGHT, ui.TOP)
                                                recipe_pic:SetImage(image)
                                                SET_ITEM_TOOLTIP_TYPE(recipe_pic, target_item_cls.ClassID,
                                                    target_item_cls, "accountwarehouse")
                                            else
                                                local recipe_pic = GET_CHILD(slot, "recipe_pic" .. i)
                                                if recipe_pic then
                                                    DESTROY_CHILD_BYNAME(slot, "recipe_pic" .. i)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        local card_ssets = {}
        for i = 0, tree:GetChildCount() - 1 do
            local child = tree:GetChildByIndex(i)
            if child and string.find(child:GetName(), "^sset_Card") and not string.find(child:GetName(), "Summon") then
                table.insert(card_ssets, child)
            end
        end
        for _, card_slot_set in ipairs(card_ssets) do
            local child_count = card_slot_set:GetChildCount()
            for i = 0, child_count - 1 do
                local slot = card_slot_set:GetChildByIndex(i)
                if slot then
                    AUTO_CAST(slot)
                    local icon = slot:GetIcon()
                    if icon then
                        local info = icon:GetInfo()
                        local iesid = info:GetIESID()
                        local inv_item = GET_ITEM_BY_GUID(iesid)
                        local inv_index = inv_item.invIndex
                        local unique_key = iesid .. "_" .. inv_index
                        if not g.inven_tbl[unique_key] or msg ~= "INV_ITEM_ADD" then
                            g.inven_tbl[unique_key] = true
                            if inv_item then
                                local item_obj = GetIES(inv_item:GetObject())
                                local item_cls = GetClassByType("Item", item_obj.ClassID)
                                local image = nil
                                if g.settings.inventory_mod == 1 then
                                    image = TryGetProp(item_obj, "TooltipImage", "None")
                                else
                                    image = GET_ITEM_ICON_IMAGE(item_cls)
                                end
                                if item_cls then
                                    icon:Set(image, "Item", inv_item.type, inv_item.invIndex, inv_item:GetIESID(),
                                        inv_item.count)
                                end
                            end
                        end
                    end
                end
            end
        end
        local gem_skill_slotset = GET_CHILD_RECURSIVELY(tree, "sset_Gem_GemSkill", "ui::CSlotSet")
        if gem_skill_slotset then
            local child_count = gem_skill_slotset:GetChildCount()
            for i = 0, child_count - 1 do
                local slot = gem_skill_slotset:GetChildByIndex(i)
                if slot then
                    AUTO_CAST(slot)
                    local icon = slot:GetIcon()
                    if icon then
                        local info = icon:GetInfo()
                        local iesid = info:GetIESID()
                        local inv_item = GET_ITEM_BY_GUID(iesid)
                        local inv_index = inv_item.invIndex
                        local unique_key = iesid .. "_" .. inv_index
                        if not g.inven_tbl[unique_key] or msg ~= "INV_ITEM_ADD" then
                            g.inven_tbl[unique_key] = true
                            if inv_item then
                                local item_obj = GetIES(inv_item:GetObject())
                                local item_cls = GetClassByType("Item", item_obj.ClassID)
                                if item_cls then
                                    local cls_name = item_cls.ClassName
                                    local image = GET_ITEM_ICON_IMAGE(item_cls)
                                    if g.settings.inventory_mod == 1 then
                                        local skill_name = TryGetProp(item_cls, "SkillName", "None")
                                        local skill_cls = GetClass("Skill", skill_name)
                                        local skill_pic = slot:CreateOrGetControl("picture", "skill_pic" .. i, 0, 0, 35,
                                            35)
                                        AUTO_CAST(skill_pic)
                                        skill_pic:SetEnableStretch(1)
                                        skill_pic:SetGravity(ui.LEFT, ui.TOP)
                                        skill_pic:SetImage(image)
                                        SET_ITEM_TOOLTIP_TYPE(skill_pic, item_cls.ClassID, item_cls, "accountwarehouse")
                                        image = "icon_" .. GET_ITEM_ICON_IMAGE(skill_cls)
                                    else
                                        local trade = GET_CHILD(slot, "skill_pic" .. i)
                                        if trade then
                                            DESTROY_CHILD_BYNAME(slot, "skill_pic" .. i)
                                        end
                                    end
                                    if item_cls then
                                        icon:Set(image, "Item", inv_item.type, inv_item.invIndex, inv_item:GetIESID(),
                                            inv_item.count)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        local Gem_High_Color_slotset = GET_CHILD_RECURSIVELY(tree, "sset_Gem_High_Color", "ui::CSlotSet")
        if Gem_High_Color_slotset then
            local child_count = Gem_High_Color_slotset:GetChildCount()
            for i = 0, child_count - 1 do
                local slot = Gem_High_Color_slotset:GetChildByIndex(i)
                if slot then
                    AUTO_CAST(slot)
                    local icon = slot:GetIcon()
                    if icon then
                        local info = icon:GetInfo()
                        local iesid = info:GetIESID()
                        local inv_item = GET_ITEM_BY_GUID(iesid)
                        local inv_index = inv_item.invIndex
                        local unique_key = iesid .. "_" .. inv_index
                        if not g.inven_tbl[unique_key] or msg ~= "INV_ITEM_ADD" then
                            g.inven_tbl[unique_key] = true
                            if inv_item then
                                local item_obj = GetIES(inv_item:GetObject())
                                local item_cls = GetClassByType("Item", item_obj.ClassID)
                                if item_cls then
                                    if g.settings.inventory_mod == 1 then
                                        local cls_name = item_cls.ClassName
                                        -- 最上位の段のエーテルジェムも女神等級
                                        -- (これ以上の枠は無いので 540 と同じ扱い)。
                                        -- **数字を決め打ちしないこと**(docs/LEVEL_CAP_UPDATE.md の罠)
                                        if string.find(cls_name, tostring(core_g.ICOR_TOP_LV)) or
                                            string.find(cls_name, "540") then
                                            slot:SetSkinName("invenslot_pic_goddess")
                                        elseif string.find(cls_name, 520) then
                                            slot:SetSkinName("invenslot_legend")
                                        elseif string.find(cls_name, 500) then
                                            slot:SetSkinName("invenslot_unique")
                                        elseif string.find(cls_name, 480) then
                                            slot:SetSkinName("invenslot_rare")
                                        else
                                            slot:SetSkinName("invenslot_nomal")
                                        end
                                    else
                                        slot:SetSkinName("invenslot_nomal")
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        local sset_Ancient_Card = GET_CHILD_RECURSIVELY(tree, "sset_Ancient_Card", "ui::CSlotSet")
        if sset_Ancient_Card then
            local child_count = sset_Ancient_Card:GetChildCount()
            for i = 0, child_count - 1 do
                local slot = sset_Ancient_Card:GetChildByIndex(i)
                if slot then
                    AUTO_CAST(slot)
                    local icon = slot:GetIcon()
                    if icon then
                        local info = icon:GetInfo()
                        local inv_item = GET_ITEM_BY_GUID(info:GetIESID())
                        if inv_item then
                            local item_obj = GetIES(inv_item:GetObject())
                            local item_cls = GetClassByType("Item", item_obj.ClassID)
                            local name = string.gsub(item_obj.ClassName, "Ancient_Card_", "Ancient_")
                            local mon_cls = GetClass("Monster", name)
                            local icon_name = TryGetProp(mon_cls, "Icon", "None")
                            if g.settings.inventory_mod == 1 then
                                local ancient_pic = slot:CreateOrGetControl("picture", "ancient_pic" .. i, 0, 0, 25, 25)
                                AUTO_CAST(ancient_pic)
                                ancient_pic:SetEnableStretch(1)
                                ancient_pic:SetGravity(ui.LEFT, ui.TOP)
                                ancient_pic:SetImage(icon_name)
                                SET_ITEM_TOOLTIP_TYPE(ancient_pic, item_cls.ClassID, item_cls, "accountwarehouse")
                            else
                                local trade = GET_CHILD(slot, "ancient_pic" .. i)
                                if trade then
                                    DESTROY_CHILD_BYNAME(slot, "ancient_pic" .. i)
                                end
                            end
                        end

                    end
                end
            end
        end
        local icor_slot_set = GET_CHILD_RECURSIVELY(tree, "sset_Icor", "ui::CSlotSet")
        if icor_slot_set then
            local child_count = icor_slot_set:GetChildCount()
            for i = 0, child_count - 1 do
                local slot = icor_slot_set:GetChildByIndex(i)
                if slot then
                    AUTO_CAST(slot)
                    local icon = slot:GetIcon()
                    if icon then
                        local info = icon:GetInfo()
                        local iesid = info:GetIESID()
                        local inv_item = GET_ITEM_BY_GUID(iesid)
                        local inv_index = inv_item.invIndex
                        local unique_key = iesid .. "_" .. inv_index
                        if not g.inven_tbl[unique_key] or msg ~= "INV_ITEM_ADD" then
                            g.inven_tbl[unique_key] = true
                            if inv_item then
                                local item_obj = GetIES(inv_item:GetObject())
                                local item_cls = GetClassByType("Item", item_obj.ClassID)
                                if item_cls then
                                    local cls_name = item_cls.ClassName
                                    if g.settings.inventory_mod == 1 then
                                        -- 最上位の段(core_g.ICOR_TOP_EP)を足す。**古い段は外さない**
                                        -- ("EP17" 決め打ちだったので Lv560 のイコルが格下の枠で出ていた)
                                        local is_special_item =
                                            string.find(cls_name, core_g.ICOR_TOP_EP) or
                                                string.find(cls_name, "EP17") or string.find(cls_name, "Weapon2") or
                                                string.find(cls_name, "Armor2")
                                        if not is_special_item then
                                            slot:SetSkinName("invenslot_rare")
                                        end
                                        local market_trade = TryGetProp(item_cls, "MarketTrade")
                                        if market_trade == "NO" then
                                            local trade = slot:CreateOrGetControl("richtext", "trade" .. i, 5, 40, 30,
                                                10)
                                            AUTO_CAST(trade)
                                            trade:SetText("{ol}{s10}NoTrade")
                                        end
                                    else
                                        local trade = GET_CHILD(slot, "trade" .. i)
                                        if trade then
                                            DESTROY_CHILD_BYNAME(slot, "trade" .. i)
                                        end
                                        slot:SetSkinName("invenslot_pic_goddess")
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        local armor_slot_set = GET_CHILD_RECURSIVELY(tree, "sset_Armor", "ui::CSlotSet")
        if armor_slot_set then
            local child_count = armor_slot_set:GetChildCount()
            for i = 0, child_count - 1 do
                local slot = armor_slot_set:GetChildByIndex(i)
                if slot then
                    AUTO_CAST(slot)
                    local icon = slot:GetIcon()
                    if icon then
                        local info = icon:GetInfo()
                        local iesid = info:GetIESID()
                        local inv_item = GET_ITEM_BY_GUID(iesid)
                        local inv_index = inv_item.invIndex
                        local unique_key = iesid .. "_" .. inv_index
                        if not g.inven_tbl[unique_key] or msg ~= "INV_ITEM_ADD" then
                            g.inven_tbl[unique_key] = true
                            if inv_item then
                                local item_obj = GetIES(inv_item:GetObject())
                                local item_cls = GetClassByType("Item", item_obj.ClassID)
                                if item_cls then
                                    if g.settings.inventory_mod == 1 then
                                        local cls_name = item_cls.ClassName
                                        local is_special_item =
                                            string.find(cls_name, core_g.ICOR_TOP_EP) or
                                                string.find(cls_name, "EP17") or
                                                (string.find(cls_name, "EP16") and string.find(cls_name, "high")) or
                                                (string.find(cls_name, "EP13") and string.find(cls_name, "high2"))
                                        if not is_special_item and
                                            (string.find(cls_name, "belt") or string.find(cls_name, "shoulder")) then
                                            slot:SetSkinName("invenslot_rare")
                                        end
                                    else
                                        slot:SetSkinName("invenslot_pic_goddess")
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    inventory:Invalidate()
    local try = inventory:GetUserIValue("TRY")
    if (msg == "INV_ITEM_REMOVE" or msg == "INV_ITEM_ADD") and try < 2 then
        try = try + 1
        inventory:SetUserValue("TRY", try)
        inventory:StopUpdateScript("Mini_addons_inventory_open_func")
        inventory:RunUpdateScript("Mini_addons_INVENTORY_OPEN_logic", 1.0)
        return 1
    elseif (msg == "INV_ITEM_REMOVE" or msg == "INV_ITEM_ADD") and try >= 2 then
        inventory:SetUserValue("TRY", 0)
        inventory:StopUpdateScript("Mini_addons_inventory_open_func")
        inventory:StopUpdateScript("Mini_addons_INVENTORY_OPEN_logic")

    elseif try >= 2 then
        inventory:SetUserValue("TRY", 0)
        return 0
    else
        try = try + 1
        inventory:SetUserValue("TRY", try)
        return 1 -- スクリプトを継続
    end
end

function Mini_addons_INVENTORY_OPEN_logic(frame)
    if frame:IsVisible() == 1 then
        frame:StopUpdateScript("Mini_addons_inventory_open_func")
        frame:RunUpdateScript("Mini_addons_inventory_open_func", 1.0)
    else
        frame:StopUpdateScript("Mini_addons_inventory_open_func")
    end
    return 0
end

function Mini_addons_INVENTORY_OPEN(my_frame, my_msg)
    local frame = g.get_event_args(my_msg)
    if not frame then
        return
    end
    local inventory = ui.GetFrame("inventory")
    if not inventory then
        return
    end
    if (os.clock() - (g.last_inventory_open_time or 0)) < 1.0 then
        return
    end
    g.last_inventory_open_time = os.clock()
    inventory:SetUserValue("TRY", 0)
    g.inven_tbl = {}
    local elapsed_time = os.clock() - (g.load_time or 0)
    if elapsed_time < 5.0 then
        local delay = 5.0 - elapsed_time
        local delay_str = tostring(delay)
        local truncated_str = string.sub(delay_str, 1, 3)
        local final_delay = tonumber(truncated_str)
        final_delay = math.max(final_delay, 0.1)
        inventory:RunUpdateScript("Mini_addons_INVENTORY_OPEN_logic", final_delay)
    else
        Mini_addons_INVENTORY_OPEN_logic(inventory)
    end
end
