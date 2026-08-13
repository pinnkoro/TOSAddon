-- インベントリイコル検索
local inven_title_name = nil
local _inven_sort_type_option = {}
local function mini_addons_is_match_or(text, keyword_list)
    if text == nil then
        return false
    end
    for _, word in ipairs(keyword_list) do
        if string.find(text, word) then
            return true
        end
    end
    return false
end

function Mini_addons_INVENTORY_TOTAL_LIST_GET(frame, set_pos, is_ignore_lift_icon, inven_type_str)
    if g.settings.icor_status_search == 0 then
        if g.FUNCS["INVENTORY_TOTAL_LIST_GET"] then
            g.FUNCS["INVENTORY_TOTAL_LIST_GET"](frame, set_pos, is_ignore_lift_icon, inven_type_str)
        end
        return
    end
    local inv_frame = ui.GetFrame("inventory")
    if not inv_frame then
        return
    end
    local lift_icon = ui.GetLiftIcon()
    if not is_ignore_lift_icon then
        is_ignore_lift_icon = "NO"
    end
    if is_ignore_lift_icon ~= "NO" and lift_icon ~= nil then
        return
    end
    local my_session = session.GetMySession()
    local cid = my_session:GetCID()
    local sort_type = _inven_sort_type_option[cid] or 0
    session.BuildInvItemSortedList()
    local sorted_list = session.GetInvItemSortedList()
    local inv_item_count = sorted_list:size()
    local group = GET_CHILD_RECURSIVELY(inv_frame, "inventoryGbox", "ui::CGroupBox")
    for type_no = 1, #g_invenTypeStrList do
        if inven_type_str == nil or inven_type_str == g_invenTypeStrList[type_no] or type_no == 1 then
            local tree_box = GET_CHILD_RECURSIVELY(group, "treeGbox_" .. g_invenTypeStrList[type_no], "ui::CGroupBox")
            local tree =
                GET_CHILD_RECURSIVELY(tree_box, "inventree_" .. g_invenTypeStrList[type_no], "ui::CTreeControl")
            local group_font_name = inv_frame:GetUserConfig("TREE_GROUP_FONT")
            local tab_width = inv_frame:GetUserConfig("TREE_TAB_WIDTH")
            tree:Clear()
            tree:EnableDrawFrame(false)
            tree:SetFitToChild(true, 60)
            tree:SetFontName(group_font_name)
            tree:SetTabWidth(tab_width)
            local slot_set_name_list_cnt = ui.inventory.GetInvenSlotSetNameCount()
            for i = 1, slot_set_name_list_cnt do
                local slot_set_name = ui.inventory.GetInvenSlotSetNameByIndex(i - 1)
                ui.inventory.RemoveInvenSlotSetName(slot_set_name)
            end
            local group_name_list_cnt = ui.inventory.GetInvenGroupNameCount()
            for i = 1, group_name_list_cnt do
                local group_name = ui.inventory.GetInvenGroupNameByIndex(i - 1)
                ui.inventory.RemoveInvenGroupName(group_name)
            end
        end
    end
    local search_gbox = group:GetChild("searchGbox")
    local search_skin = GET_CHILD_RECURSIVELY(search_gbox, "searchSkin", "ui::CGroupBox")
    local edit = GET_CHILD_RECURSIVELY(search_skin, "ItemSearch", "ui::CEditControl")
    local cap = edit:GetText()
    local search_keywords = {}
    local is_searching = false
    if cap ~= "" then
        local query = string.lower(cap)
        for word in string.gmatch(query, "%S+") do
            table.insert(search_keywords, word)
        end
        if #search_keywords > 0 then
            is_searching = true
        end
    end
    local inv_item_list = {}
    local index_count = 1
    for i = 0, inv_item_count - 1 do
        local inv_item = sorted_list:at(i)
        if inv_item ~= nil then
            inv_item_list[index_count] = inv_item
            index_count = index_count + 1
        end
    end
    if sort_type == 1 then
        table.sort(inv_item_list, INVENTORY_SORT_BY_GRADE)
    elseif sort_type == 2 then
        table.sort(inv_item_list, INVENTORY_SORT_BY_WEIGHT)
    elseif sort_type == 3 then
        table.sort(inv_item_list, INVENTORY_SORT_BY_NAME)
    elseif sort_type == 4 then
        table.sort(inv_item_list, INVENTORY_SORT_BY_COUNT)
    else
        table.sort(inv_item_list, INVENTORY_SORT_BY_NAME)
    end
    if inven_title_name == nil then
        inven_title_name = {}
        local base_id_cls_list, base_id_cnt = GetClassList("inven_baseid")
        for i = 1, base_id_cnt do
            local base_id_cls = GetClassByIndexFromList(base_id_cls_list, i - 1)
            local temp_title = base_id_cls.ClassName
            if base_id_cls.MergedTreeTitle ~= "NO" then
                temp_title = base_id_cls.MergedTreeTitle
            end
            if table.find(inven_title_name, temp_title) == 0 then
                inven_title_name[#inven_title_name + 1] = temp_title
            end
        end
    end
    local cls_inv_index = {}
    for i = 1, #inven_title_name do
        local category = inven_title_name[i]
        for j = 1, #inv_item_list do
            local inv_item = inv_item_list[j]
            if inv_item ~= nil then
                local item_cls = GetIES(inv_item:GetObject())
                if item_cls.MarketCategory ~= "None" then
                    local base_id_cls = nil
                    if cls_inv_index[inv_item.invIndex] == nil then
                        base_id_cls = GET_BASEID_CLS_BY_INVINDEX(inv_item.invIndex)
                        cls_inv_index[inv_item.invIndex] = base_id_cls
                    else
                        base_id_cls = cls_inv_index[inv_item.invIndex]
                    end
                    local title_name = base_id_cls.ClassName
                    if base_id_cls.MergedTreeTitle ~= "NO" then
                        title_name = base_id_cls.MergedTreeTitle
                    end
                    if category == title_name then
                        local type_str = GET_INVENTORY_TREEGROUP(base_id_cls)
                        if item_cls ~= nil then
                            local make_slot = true
                            if is_searching then
                                make_slot = false
                                local item_name = string.lower(dictionary.ReplaceDicIDInCompStr(item_cls.Name))
                                local prefix_class_name = TryGetProp(item_cls, "LegendPrefix")
                                if prefix_class_name ~= nil and prefix_class_name ~= "None" then
                                    local prefix_cls = GetClass("LegendSetItem", prefix_class_name)
                                    local prefix_name = string.lower(dictionary.ReplaceDicIDInCompStr(prefix_cls.Name))
                                    item_name = prefix_name .. " " .. item_name
                                end
                                if mini_addons_is_match_or(item_name, search_keywords) then
                                    make_slot = true
                                else
                                    if TryGetProp(item_cls, "GroupName", "None") == "Earring" then
                                        local max_option_count =
                                            shared_item_earring.get_max_special_option_count(TryGetProp(item_cls,
                                                "UseLv", 1))
                                        for ii = 1, max_option_count do
                                            local option_name = "EarringSpecialOption_" .. ii
                                            local job = TryGetProp(item_cls, option_name, "None")
                                            if job ~= "None" then
                                                local job_cls = GetClass("Job", job)
                                                if job_cls ~= nil then
                                                    item_name = string.lower(
                                                        dictionary.ReplaceDicIDInCompStr(job_cls.Name))
                                                    if mini_addons_is_match_or(item_name, search_keywords) then
                                                        make_slot = true
                                                        break
                                                    end
                                                end
                                            end
                                        end
                                    elseif TryGetProp(item_cls, "GroupName", "None") == "Icor" then
                                        local max_option = 5
                                        for iii = 1, max_option do
                                            local item = GetIES(inv_item:GetObject())
                                            local option_name = "RandomOption_" .. iii
                                            local option = TryGetProp(item, option_name, "None")
                                            if option ~= "None" and option ~= nil then
                                                item_name =
                                                    string.lower(dictionary.ReplaceDicIDInCompStr(ClMsg(option)))
                                                if mini_addons_is_match_or(item_name, search_keywords) then
                                                    make_slot = true
                                                    break
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            local view_option_check = 1
                            if type_str == "Equip" then
                                view_option_check = CHECK_INVENTORY_OPTION_EQUIP(item_cls)
                            elseif type_str == "Card" then
                                view_option_check = CHECK_INVENTORY_OPTION_CARD(item_cls)
                            elseif type_str == "Etc" then
                                view_option_check = CHECK_INVENTORY_OPTION_ETC(item_cls)
                            elseif type_str == "Gem" then
                                view_option_check = CHECK_INVENTORY_OPTION_GEM(item_cls)
                            end
                            if make_slot == true and view_option_check == 1 then
                                if inv_item.count > 0 and base_id_cls.ClassName ~= "Unused" then
                                    if inven_type_str == nil or inven_type_str == type_str then
                                        local tree_box = GET_CHILD_RECURSIVELY(group, "treeGbox_" .. type_str,
                                            "ui::CGroupBox")
                                        local tree = GET_CHILD_RECURSIVELY(tree_box, "inventree_" .. type_str,
                                            "ui::CTreeControl")
                                        INSERT_ITEM_TO_TREE(inv_frame, tree, inv_item, item_cls, base_id_cls)
                                    end
                                    if type_str ~= "Quest" then
                                        local tree_box_all =
                                            GET_CHILD_RECURSIVELY(group, "treeGbox_All", "ui::CGroupBox")
                                        local tree_all = GET_CHILD_RECURSIVELY(tree_box_all, "inventree_All",
                                            "ui::CTreeControl")
                                        INSERT_ITEM_TO_TREE(inv_frame, tree_all, inv_item, item_cls, base_id_cls)
                                    end
                                end
                            else
                                local is_option_applied = CHECK_INVENTORY_OPTION_APPLIED(base_id_cls)
                                if is_option_applied == 1 and cap == "" then
                                    if inven_type_str == nil or inven_type_str == type_str then
                                        local tree_box = GET_CHILD_RECURSIVELY(group, "treeGbox_" .. type_str,
                                            "ui::CGroupBox")
                                        local tree = GET_CHILD_RECURSIVELY(tree_box, "inventree_" .. type_str,
                                            "ui::CTreeControl")
                                        EMPTY_TREE_INVENTORY_OPTION_TEXT(base_id_cls, tree)
                                    end
                                    if type_str ~= "Quest" then
                                        local tree_box_all =
                                            GET_CHILD_RECURSIVELY(group, "treeGbox_All", "ui::CGroupBox")
                                        local tree_all = GET_CHILD_RECURSIVELY(tree_box_all, "inventree_All",
                                            "ui::CTreeControl")
                                        EMPTY_TREE_INVENTORY_OPTION_TEXT(base_id_cls, tree_all)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    for type_no = 1, #g_invenTypeStrList do
        local tree_box = GET_CHILD_RECURSIVELY(group, "treeGbox_" .. g_invenTypeStrList[type_no], "ui::CGroupBox")
        local tree = GET_CHILD_RECURSIVELY(tree_box, "inventree_" .. g_invenTypeStrList[type_no], "ui::CTreeControl")
        local slot_set_name_list_cnt = ui.inventory.GetInvenSlotSetNameCount()
        for i = 1, slot_set_name_list_cnt do
            local get_slot_set_name = ui.inventory.GetInvenSlotSetNameByIndex(i - 1)
            local slot_set = GET_CHILD_RECURSIVELY(tree, get_slot_set_name, "ui::CSlotSet")
            if slot_set ~= nil then
                ui.InventoryHideEmptySlotBySlotSet(slot_set)
            end
        end
        ADD_GROUP_BOTTOM_MARGIN(inv_frame, tree)
        tree:OpenNodeAll()
        tree:SetEventScript(ui.LBUTTONDOWN, "INVENTORY_TREE_OPENOPTION_CHANGE")
        INVENTORY_CATEGORY_OPENCHECK(inv_frame, tree)
        for i = 1, slot_set_name_list_cnt do
            if set_pos == "setpos" then
                local saved_pos = inv_frame:GetUserValue("INVENTORY_CUR_SCROLL_POS")
                if saved_pos == "None" then
                    saved_pos = 0
                end
                tree_box:SetScrollPos(tonumber(saved_pos))
            end
        end
    end
end
