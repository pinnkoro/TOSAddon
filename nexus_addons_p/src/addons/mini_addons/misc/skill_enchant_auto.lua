-- 錬成時に自動でアイテムセット
function Mini_addons_SUCCESS_COMMON_SKILL_ENCHANT(frame, msg)
    if g.settings.skill_enchant == 0 then
        return
    end
    ReserveScript("Mini_addons_COMMON_SKILL_ENCHANT_ADD_MAT()", 0.9)
    return
end

function Mini_addons_COMMON_SKILL_ENCHANT_MAT_SET(my_frame, my_msg)
    if g.settings.skill_enchant == 0 then
        return
    end
    ReserveScript("Mini_addons_COMMON_SKILL_ENCHANT_ADD_MAT()", 0.2)
    return
end

function Mini_addons_COMMON_SKILL_ENCHANT_ADD_MAT(parent, ctrl)
    local common_skill_enchant = ui.GetFrame("common_skill_enchant")
    if not common_skill_enchant then
        return
    end
    local bottom_bg = GET_CHILD_RECURSIVELY(common_skill_enchant, "bottom_Bg")
    local cnt = bottom_bg:GetChildCount()
    local set_ready_count = 0
    for i = 1, cnt - 1 do
        local ctrl_set = bottom_bg:GetChildByIndex(i)
        local mat_slot = GET_CHILD_RECURSIVELY(ctrl_set, "mat_slot")
        local plus = GET_CHILD_RECURSIVELY(ctrl_set, "plus")
        plus:ShowWindow(1)
        local mat_name = GET_CHILD_RECURSIVELY(ctrl_set, "mat_name")
        local cnt_in_my_bag = GET_CHILD_RECURSIVELY(ctrl_set, "cnt_in_my_bag")
        local val_1 = GET_NOT_COMMAED_NUMBER(mat_name:GetTextByKey("value2"))
        local val_2 = GET_NOT_COMMAED_NUMBER(cnt_in_my_bag:GetTextByKey("value"))
        val_1 = tonumber(val_1)
        val_2 = tonumber(val_2)
        if val_1 <= val_2 then
            local icon = mat_slot:GetIcon()
            if icon then
                icon:SetColorTone("FFFFFFFF")
            end
            plus:ShowWindow(0)
            set_ready_count = set_ready_count + 1
        else
            local msg = string.format("<%s> %s", mat_name:GetTextByKey("value"), ClMsg("NotEnoughMaterial"))
            ui.SysMsg(msg)
        end
    end
    if set_ready_count == (cnt - 1) then
        common_skill_enchant:SetUserValue("IS_READY", "TRUE")
        GET_CHILD_RECURSIVELY(common_skill_enchant, "do_enchant"):SetEnable(1)
    else
        common_skill_enchant:SetUserValue("IS_READY", "FALSE")
    end
end
