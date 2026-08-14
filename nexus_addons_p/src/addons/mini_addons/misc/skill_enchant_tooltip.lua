-- スキル錬成のスロットにツールチップ
function Mini_addons_COMMON_SKILL_ENCHANT_SET_GB(my_frame, my_msg)
    if g.settings.enchant_tooltip == 0 then
        return
    end
    local gb, index, argStr1, argStr2 = g.get_event_args(my_msg)
    AUTO_CAST(gb)
    local cls_list, count = GetClassList("Skill")
    for i = 1, 2 do
        local mat_slot = GET_CHILD_RECURSIVELY(gb, "mat_slot" .. index)
        local text = GET_CHILD_RECURSIVELY(gb, "mat_name" .. index)
        if text:IsVisible() == 1 then
            local icon = mat_slot:GetIcon()
            if icon then
                AUTO_CAST(mat_slot)
                mat_slot:EnableHitTest(1)
                for j = 0, count - 1 do
                    AUTO_CAST(icon)
                    local skill_cls = GetClassByIndexFromList(cls_list, j)
                    if skill_cls then
                        local skill_cls_name = skill_cls.ClassName
                        if tostring(skill_cls_name) == tostring(argStr1) then
                            local skill_id = skill_cls.ClassID
                            SET_SLOT_SKILL_BY_LEVEL(mat_slot, skill_id, tonumber(argStr2))
                            break
                        end
                    end
                end
            end
        end
    end
end
