-- 自動女神ガチャ
function Mini_addons_GP_FULL_BET()
    local godprotection = ui.GetFrame("godprotection")
    local auto_gb = GET_CHILD_RECURSIVELY(godprotection, "auto_gb")
    if g.settings.auto_gacha == 1 then
        local fbbtn = auto_gb:CreateOrGetControl("button", "fbbtn", 200, 30, 100, 40)
        AUTO_CAST(fbbtn)
        fbbtn:SetSkinName("None")
        fbbtn:SetText("{img login_test_button 95 35}")
        local fbtext = fbbtn:CreateOrGetControl("button", "fbtext", 0, 0, 100, 40)
        fbtext:SetSkinName("None")
        fbtext:SetText("{ol}  Full Bet")
        fbtext:SetAnimation("MouseOnAnim", "btn_mouseover")
        fbtext:SetEventScript(ui.LBUTTONUP, "Mini_addons_GP_FULL_BET_START")
    else
        auto_gb:RemoveChild("fbbtn")
    end
end

function Mini_addons_GP_DO_OPEN()
    if g.settings.auto_gacha == 0 then
        g.first = nil
        return
    end
    if not g.first then
        g.first = true
        GODPROTECTION_DO_OPEN()
        if g.settings.auto_gacha_start == 1 then
            local mini_addons = g.get_frame()
            mini_addons:RunUpdateScript("Mini_addons_GP_FULL_BET_START", 2.0)
        end
    end
end

function Mini_addons_GP_FULL_BET_START(mini_addons)
    local godprotection = ui.GetFrame("godprotection")
    local multiple_count = 20
    local multiple_count_edit = GET_CHILD_RECURSIVELY(godprotection, "multiple_count_edit")
    multiple_count_edit:SetText(multiple_count)
    local edit = GET_CHILD_RECURSIVELY(godprotection, "auto_edit")
    local count = 99999999
    local next_count = count - 1
    edit:SetText(next_count)
    local auto_text = GET_CHILD_RECURSIVELY(godprotection, "auto_text")
    auto_text:ShowWindow(0)
    local parent = GET_CHILD_RECURSIVELY(godprotection, "auto_gb")
    local auto_btn = GET_CHILD_RECURSIVELY(godprotection, "auto_btn")
    GODPROTECTION_AUTO_START_BTN_CLICK(parent, auto_btn)
    return 0
end

function Mini_addons_FIELD_BOSS_WORLD_EVENT_END(frame)
    local godprotection = ui.GetFrame("godprotection")
    godprotection:ShowWindow(0)
    g.first = nil
end

function Mini_addons_GP_AUTOSTART_OPERATION(frame, ctrl)
    AUTO_CAST(ctrl)
    if g.settings.auto_gacha_start == 0 then
        g.settings.auto_gacha_start = 1
        ctrl:SetText("{ol}{#FFFFFF}ON")
        ctrl:SetSkinName("test_red_button")
    else
        g.settings.auto_gacha_start = 0
        ctrl:SetText("{ol}{#FFFFFF}OFF")
        ctrl:SetSkinName("test_gray_button")
    end
    Mini_addons_save_settings()
end
