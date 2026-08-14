-- ボスレランキングにメンバーインフォ
function Mini_addons_WEEKLY_BOSS_RANK_UPDATE_()
    if type(_G["native_lang_WEEKLY_BOSS_RANK_UPDATE"]) == "function" then
        return
    end
    local induninfo = ui.GetFrame("induninfo")
    local rankListBox = GET_CHILD_RECURSIVELY(induninfo, "rankListBox", "ui::CGroupBox")
    local cnt = session.weeklyboss.GetRankInfoListSize()
    if cnt == 0 then
        return
    end
    for i = 1, cnt do
        local ctrl_set = GET_CHILD_RECURSIVELY(rankListBox, "CTRLSET_" .. i)
        if ctrl_set then
            AUTO_CAST(ctrl_set)
            local name = GET_CHILD(ctrl_set, "attr_name_text", "ui::CRichText")
            local teamname = session.weeklyboss.GetRankInfoTeamName(i - 1)
            local info_btn = rankListBox:CreateOrGetControl("button", "info_btn_" .. i, name:GetX(), (i - 1) * 73 + 50,
                50, 25)
            AUTO_CAST(info_btn)
            info_btn:SetText("{ol}Info")
            info_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_MEMBERINFO_ONCLICK")
            info_btn:SetEventScriptArgString(ui.LBUTTONUP, teamname)
            local txtGs = GET_CHILD(rankListBox, "txtGs_" .. i)
            if txtGs then
                rankListBox:RemoveChild("txtGs_" .. i)
            end
        end
    end
end

function Mini_addons_MEMBERINFO_ONCLICK(frame, ctrl, teamname, num)
    ui.Chat("/memberinfo " .. teamname)
    local compare = ui.GetFrame("compare")
    compare:SetLayerLevel(102)
end
