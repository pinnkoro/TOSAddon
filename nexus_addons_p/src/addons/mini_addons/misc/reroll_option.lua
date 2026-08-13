-- オプションリロールの表を横に表示
function Mini_addons_OPEN_DLG_REROLL_ITEM()
    local reroll_item = ui.GetFrame("reroll_item")
    for i = 1, MAX_RANDOM_OPTION_COUNT do
        local op = GET_CHILD_RECURSIVELY(reroll_item, "op" .. i)
        if op then
            AUTO_CAST(op)
            DESTROY_CHILD_BYNAME(reroll_item, op:GetName())
        end
    end
    if g.settings.reroll_option == 0 then
        reroll_item:StopUpdateScript("Mini_addons_REROLL_ITEM_OPTION_LIST")
        return
    end
    if reroll_item and reroll_item:IsVisible() == 1 and g.settings.reroll_option == 1 then
        reroll_item:RunUpdateScript("Mini_addons_REROLL_ITEM_OPTION_LIST", 0.2)
    end
end

function Mini_addons_REROLL_ITEM_OPTION_LIST(reroll_frame)
    local reroll_item_option = ui.GetFrame("reroll_item_option")
    local reroll_frame = ui.GetFrame("reroll_item")
    if reroll_frame == nil or reroll_frame:IsVisible() ~= 1 then
        ui.CloseFrame("reroll_item_option")
        return 1
    end
    local slot = GET_CHILD_RECURSIVELY(reroll_frame, "slot")
    local inv_item = GET_SLOT_ITEM(slot)
    if inv_item == nil then
        for i = 1, MAX_RANDOM_OPTION_COUNT do
            local op = GET_CHILD_RECURSIVELY(reroll_frame, "op" .. i)
            if op then
                AUTO_CAST(op)
                DESTROY_CHILD_BYNAME(reroll_frame, op:GetName())
            end
        end
        ui.CloseFrame("reroll_item_option")
        return 1
    end
    if reroll_item_option:IsVisible() == 1 then
        return 1
    end
    local img_tbl = {
        ["ATK"] = "{img tooltip_attribute1}",
        ["DEF"] = "{img tooltip_attribute2}",
        ["UTIL_ARMOR"] = "{img tooltip_attribute3}",
        ["STAT"] = "{img tooltip_attribute4}",
        ["SPECIAL"] = "{img tooltip_attribute5}"
    }
    local item_obj = GetIES(inv_item:GetObject())
    local group = TryGetProp(item_obj, "GroupName", "None")
    for i = 1, MAX_RANDOM_OPTION_COUNT do
        local group_name = "RandomOptionGroup_" .. i
        local prop_name = "RandomOption_" .. i
        local prop_value = "RandomOptionValue_" .. i
        local min, max = 0, 0
        if group == "BELT" then
            min, max = shared_item_belt.get_option_value_range_equip(item_obj, item_obj[prop_name])
        elseif group == "SHOULDER" then
            min, max = shared_item_shoulder.get_option_value_range_equip(item_obj, item_obj[prop_name])
        elseif group == "Icor" then
            min, max = shared_item_goddess_icor.get_option_value_range_icor(item_obj, item_obj[prop_name])
        end
        reroll_frame:RemoveChild("op" .. i)
        local op = reroll_frame:CreateOrGetControl("richtext", "op" .. i, 60, i * 20 + 75, 20, 160)
        AUTO_CAST(op)
        local op_value = item_obj[prop_value]
        if op_value > max then
            op_value = "{/}{s16}{#9932CC}" .. GET_COMMAED_STRING(op_value)
        elseif op_value == max then
            op_value = "{/}{s16}{#98FB98}" .. GET_COMMAED_STRING(op_value)
        end
        if item_obj[group_name] ~= "SPECIAL" then
            op_value = GET_COMMAED_STRING(op_value) .. " {#98FB98}(" .. GET_COMMAED_STRING(max) .. ")" ..
                           "{@st43b}{s16}"
        else
            op_value = GET_COMMAED_STRING(op_value) .. "{@st43b}{s16}"
        end
        if item_obj[prop_name] ~= "None" then
            local op_text = img_tbl[item_obj[group_name]] .. "{@st43b}{s16}" .. " " .. op_value .. " " ..
                                ScpArgMsg(item_obj[prop_name])
            op:SetText(op_text)
        end
    end
    local cur_index = reroll_frame:GetUserValue("CURRENT_INDEX")
    if cur_index == "None" then
        cur_index = 1
    end
    if cur_index == nil or cur_index == "None" then
        return 1
    end
    local reroll_index = TryGetProp(item_obj, "RerollIndex", 0)
    if reroll_index <= 0 then
        reroll_index = tonumber(cur_index)
    end
    local candidate_option_list = nil
    local group_name = TryGetProp(item_obj, "GroupName", "None")
    if group_name == "BELT" then
        candidate_option_list = shared_item_belt.get_option_list_by_index(item_obj, reroll_index)
    elseif group_name == "SHOULDER" then
        candidate_option_list = shared_item_shoulder.get_option_list_by_index(item_obj, reroll_index)
    elseif group_name == "Icor" then
        candidate_option_list = shared_item_goddess_icor.get_random_option_list(item_obj, false)
    end
    if candidate_option_list == nil or #candidate_option_list == 0 then
        return 1
    end
    local max_random_option_count = 0
    if group_name == "BELT" then
        max_random_option_count = shared_item_belt.get_max_random_option_count(item_obj)
    elseif group_name == "SHOULDER" then
        max_random_option_count = shared_item_shoulder.get_max_random_option_count(item_obj)
    elseif group_name == "Icor" then
        max_random_option_count = shared_item_goddess_icor.get_max_option_count()
    end
    if max_random_option_count == nil then
        return 1
    end
    local optionGbox = GET_CHILD_RECURSIVELY(reroll_item_option, "optionGbox")
    optionGbox:RemoveAllChild()
    local op_count = 0
    local function _MAKE_PROPERTY_MIN_MAX_DESC(desc, min, max)
        return string.format(" %s " .. ScpArgMsg("PropUp") .. "%d" .. " ~ " .. ScpArgMsg("PropUp") .. "%d", desc,
            math.abs(min), math.abs(max))
    end
    for i = 1, #candidate_option_list do
        local prop_name = candidate_option_list[i]
        if group_name == "BELT" then
            if shared_item_belt.is_valid_reroll_option(item_obj, reroll_index, prop_name, max_random_option_count) ==
                true then
                op_count = op_count + 1
                local group_name = shared_item_belt.get_option_group_name(prop_name)
                local clmsg = GET_CLMSG_BY_OPTION_GROUP(group_name)
                local min, max = shared_item_belt.get_option_value_range_equip(item_obj, prop_name)
                local op_name = string.format("%s %s", ClMsg(clmsg), ScpArgMsg(prop_name))
                local info_str = _MAKE_PROPERTY_MIN_MAX_DESC(op_name, min, max)
                local option_ctrlset = optionGbox:CreateOrGetControlSet("eachproperty_in_reroll_item",
                    "PROPERTY_CSET_" .. op_count, 0, 0)
                option_ctrlset = AUTO_CAST(option_ctrlset)
                local pos_y = option_ctrlset:GetUserConfig("POS_Y")
                option_ctrlset:Move(0, (op_count - 1) * pos_y)
                local property_name = GET_CHILD_RECURSIVELY(option_ctrlset, "property_name", "ui::CRichText")
                property_name:SetEventScript(ui.LBUTTONUP, "None")
                property_name:SetText(info_str)
                local help_pic = GET_CHILD_RECURSIVELY(option_ctrlset, "help_pic")
                help_pic:ShowWindow(0)
            end
        elseif group_name == "SHOULDER" then
            if shared_item_shoulder.is_valid_reroll_option(item_obj, reroll_index, prop_name, max_random_option_count) ==
                true then
                op_count = op_count + 1
                local group_name = shared_item_shoulder.get_option_group_name(prop_name)
                local clmsg = GET_CLMSG_BY_OPTION_GROUP(group_name)
                local min, max = shared_item_shoulder.get_option_value_range_equip(item_obj, prop_name)
                local op_name = string.format("%s %s", ClMsg(clmsg), ScpArgMsg(prop_name))
                local info_str = _MAKE_PROPERTY_MIN_MAX_DESC(op_name, min, max)
                local option_ctrlset = optionGbox:CreateOrGetControlSet("eachproperty_in_reroll_item",
                    "PROPERTY_CSET_" .. op_count, 0, 0)
                option_ctrlset = AUTO_CAST(option_ctrlset)
                local pos_y = option_ctrlset:GetUserConfig("POS_Y")
                option_ctrlset:Move(0, (op_count - 1) * pos_y)
                local property_name = GET_CHILD_RECURSIVELY(option_ctrlset, "property_name", "ui::CRichText")
                property_name:SetEventScript(ui.LBUTTONUP, "None")
                property_name:SetText(info_str)
                local help_pic = GET_CHILD_RECURSIVELY(option_ctrlset, "help_pic")
                help_pic:ShowWindow(0)
            end
        elseif group_name == "Icor" then
            if shared_item_goddess_icor.is_valid_reroll_option(item_obj, reroll_index, prop_name) == true then
                op_count = op_count + 1
                local group_name = shared_item_goddess_icor.get_option_group_name(prop_name)
                local clmsg = GET_CLMSG_BY_OPTION_GROUP(group_name)
                local min, max = shared_item_goddess_icor.get_option_value_range_icor(item_obj, prop_name)
                local op_name = string.format("%s %s", ClMsg(clmsg), ScpArgMsg(prop_name))
                local info_str = _MAKE_PROPERTY_MIN_MAX_DESC(op_name, min, max)
                local option_ctrlset = optionGbox:CreateOrGetControlSet("eachproperty_in_reroll_item",
                    "PROPERTY_CSET_" .. op_count, 0, 0)
                option_ctrlset = AUTO_CAST(option_ctrlset)
                local pos_y = option_ctrlset:GetUserConfig("POS_Y")
                option_ctrlset:Move(0, (op_count - 1) * pos_y)
                local property_name = GET_CHILD_RECURSIVELY(option_ctrlset, "property_name", "ui::CRichText")
                property_name:SetEventScript(ui.LBUTTONUP, "None")
                property_name:SetText(info_str)
                local help_pic = GET_CHILD_RECURSIVELY(option_ctrlset, "help_pic")
                help_pic:ShowWindow(0)
            end
        end
    end
    reroll_item_option:Resize(500, 970)
    reroll_item_option:SetSkinName("None")
    local bg = GET_CHILD(reroll_item_option, "bg")
    bg:Resize(470, reroll_item_option:GetHeight())
    local optionGbox = GET_CHILD(reroll_item_option, "optionGbox")
    optionGbox:Resize(430, bg:GetHeight() - 100)
    reroll_item_option:ShowWindow(1)
    return 1
end
