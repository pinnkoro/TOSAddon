-- オートキャスティングをキャラ毎に設定
function Mini_addons_CONFIG_ENABLE_AUTO_CASTING(my_frame, my_msg)
    local parent, ctrl = g.get_event_args(my_msg)
    local enable = ctrl:IsChecked()
    g.settings.auto_casting[g.cid] = enable
    Mini_addons_save_settings()
end

function Mini_addons_SET_ENABLE_AUTO_CASTING()
    if g.settings.auto_cast == 0 then
        return
    end
    local systemoption = ui.GetFrame("systemoption")
    local Check_EnableAutoCasting = GET_CHILD_RECURSIVELY(systemoption, "Check_EnableAutoCasting", "ui::CCheckBox")
    Check_EnableAutoCasting:SetCheck(g.settings.auto_casting[g.cid] or 1)
    config.SetEnableAutoCasting(g.settings.auto_casting[g.cid] or 1)
    config.SaveConfig()
end
