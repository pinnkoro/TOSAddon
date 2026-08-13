-- 自分のエフェクト設定を戻すIMCのバグ修正
function Mini_addons_MY_EFFECT_SETTING()
    if g.settings.my_effect == 0 then
        return
    end
    local systemoption = ui.GetFrame("systemoption")
    local slide = GET_CHILD_RECURSIVELY(systemoption, "effect_transparency_my_value", "ui::CSlideBar")
    if g.settings.my_effect_value then
        config.SetMyEffectTransparency(g.settings.my_effect_value)
        slide:SetLevel(g.settings.my_effect_value)
    else
        local my_effect = config.GetMyEffectTransparency()
        config.SetMyEffectTransparency(my_effect)
    end
end

function Mini_addons_MY_EFFECT_EDIT(frame, ctrl)
    local my_effect = tonumber(ctrl:GetText())
    if my_effect <= 100 and my_effect >= 1 then
        local num = math.floor(my_effect / 0.392156862745 + 0.5)
        g.settings.my_effect_value = num
        Mini_addons_save_settings()
        config.SetMyEffectTransparency(num)
        ui.SysMsg("my effect changed.")
    else
        ui.SysMsg("Not a valid value.")
        return
    end
end
-- ボスのエフェクト設定を戻すIMCのバグ修正
function Mini_addons_BOSS_EFFECT_SETTING()
    if g.settings.boss_effect == 0 then
        return
    end
    local systemoption = ui.GetFrame("systemoption")
    local slide = GET_CHILD_RECURSIVELY(systemoption, "effect_transparency_boss_monster_value", "ui::CSlideBar")
    if g.settings.boss_effect_value then
        config.SetBossMonsterEffectTransparency(g.settings.boss_effect_value)
        slide:SetLevel(g.settings.boss_effect_value)
    else
        local boss_effect = config.GetBossMonsterEffectTransparency()
        config.SetBossMonsterEffectTransparency(boss_effect)
    end
end

function Mini_addons_BOSS_EFFECT_EDIT(frame, ctrl)
    local boss_effect = tonumber(ctrl:GetText())
    if boss_effect <= 100 and boss_effect >= 1 then
        local num = math.floor(boss_effect / 0.392156862745 + 0.5)
        g.settings.boss_effect_value = num
        Mini_addons_save_settings()
        config.SetBossMonsterEffectTransparency(num)
        ui.SysMsg("boss effect changed.")
    else
        ui.SysMsg("Not a valid value.")
        return
    end
end
-- その他のエフェクト設定を戻すIMCのバグ修正
function Mini_addons_OTHER_EFFECT_SETTING()
    if g.settings.other_effect == 0 then
        return
    end
    local frame = ui.GetFrame("systemoption")
    local slide = GET_CHILD_RECURSIVELY(frame, "effect_transparency_other_value", "ui::CSlideBar")
    if g.settings.other_effect_value then
        config.SetOtherEffectTransparency(g.settings.other_effect_value)
        slide:SetLevel(g.settings.other_effect_value)
    else
        local other_effect = config.GetOtherEffectTransparency()
        config.SetOtherEffectTransparency(other_effect)
    end
end

function Mini_addons_OTHER_EFFECT_EDIT(frame, ctrl)
    local other_effect = tonumber(ctrl:GetText())
    if other_effect <= 100 and other_effect >= 1 then
        local num = math.floor(other_effect / 0.392156862745 + 0.5)
        g.settings.other_effect_value = num
        Mini_addons_save_settings()
        config.SetOtherEffectTransparency(num)
        ui.SysMsg("other effect changed.")
    else
        ui.SysMsg("Not a valid value.")
        return
    end
end
