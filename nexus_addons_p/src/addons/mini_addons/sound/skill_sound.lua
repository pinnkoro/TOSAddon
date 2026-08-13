-- スキル連打音消す
function Mini_addons_ICON_USE(object, re_action)
    local original_func = g.FUNCS["ICON_USE"]
    if g.settings.skill_cool_sound == 0 then
        if original_func then
            original_func(object, re_action)
        end
        return
    end
    if object then
        local icon = tolua.cast(object, "ui::CIcon")
        local icon_info = icon:GetInfo()
        local category = icon_info:GetCategory()
        if category == "Skill" then
            if ICON_UPDATE_SKILL_COOLDOWN(icon) > 0 then
                return
            end
        end
    end
    if original_func then
        original_func(object, re_action)
    end
end
