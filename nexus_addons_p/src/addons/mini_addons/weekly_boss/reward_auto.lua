-- ヴェルニケ自動受取り
function Mini_addons_SOLODUNGEON_RANKINGPAGE_GET_REWARD()
    if g.settings.solodun_reward == 0 then
        return
    end
    if g.solodun_reward then
        return
    end
    soloDungeonClient.ReqSoloDungeonReward()
    g.solodun_reward = true
end
-- ボスレ報酬自動受取り
function Mini_addons_WEEKLY_BOSS_REWARD()
    if g.settings.weekly_boss_reward == 0 then
        return
    end
    if session.weeklyboss.GetNowWeekNum() == 0 then
        weekly_boss.RequestWeeklyBossNowWeekNum()
    end
    local week_num = WEEKLY_BOSS_RANK_WEEKNUM_NUMBER()
    if g.settings.reward_switch == 1 then
        week_num = WEEKLY_BOSS_RANK_WEEKNUM_NUMBER() - 1
    end
    if week_num ~= 0 then
        weekly_boss.RequestAcceptAbsoluteRewardAll(week_num)
        if not g.wbreward then
            local indun_info = ui.GetFrame("induninfo")
            indun_info:Resize(0, 0)
            indun_info:ShowWindow(1)
            TOGGLE_INDUNINFO(indun_info, 3)
            local tab = GET_CHILD_RECURSIVELY(indun_info, "tab")
            AUTO_CAST(tab)
            tab:SelectTab(3)
            INDUNINFO_TAB_CHANGE(tab, tab)
            local season_tab = GET_CHILD_RECURSIVELY(indun_info, "season_tab")
            AUTO_CAST(season_tab)
            season_tab:SelectTab(1)
            g.index = 0
            indun_info:RunUpdateScript("Mini_addons_WEEKLY_BOSS_RANK_REWARD", 1.5)
        end
    end
end

function Mini_addons_WEEKLY_BOSS_RANK_REWARD(indun_info)
    local classtype_tab = GET_CHILD_RECURSIVELY(indun_info, "classtype_tab")
    AUTO_CAST(classtype_tab)
    classtype_tab:SelectTab(g.index)
    if g.index <= 4 then
        WEEKLY_BOSS_DATA_REUQEST()
        classtype_tab:RunUpdateScript("Mini_addons_WEEKLY_BOSS_RANK_GET_REWARD", 1.0)
        return 1
    else
        indun_info:ShowWindow(0)
        indun_info:Resize(1095, 610)
        indun_info:StopUpdateScript("Mini_addons_WEEKLY_BOSS_RANK_REWARD")
        g.wbreward = true
        return 0
    end
end

function Mini_addons_WEEKLY_BOSS_RANK_GET_REWARD(classtype_tab)
    local week_num = WEEKLY_BOSS_RANK_WEEKNUM_NUMBER()
    local myrank = session.weeklyboss.GetMyRankInfo(week_num)
    local indun_info = ui.GetFrame("induninfo")
    local classtype_tab = GET_CHILD_RECURSIVELY(indun_info, "classtype_tab")
    AUTO_CAST(classtype_tab)
    if myrank ~= 0 and myrank <= 100 then
        weekly_boss.RequestAccpetRankingReward(week_num, myrank)
        indun_info:ShowWindow(0)
        indun_info:Resize(1095, 610)
        indun_info:StopUpdateScript("Mini_addons_WEEKLY_BOSS_RANK_REWARD")
        classtype_tab:StopUpdateScript("Mini_addons_WEEKLY_BOSS_RANK_GET_REWARD")
        g.wbreward = true
        return
    elseif myrank ~= 0 and myrank > 100 then
        indun_info:ShowWindow(0)
        indun_info:Resize(1095, 610)
        indun_info:StopUpdateScript("Mini_addons_WEEKLY_BOSS_RANK_REWARD")
        classtype_tab:StopUpdateScript("Mini_addons_WEEKLY_BOSS_RANK_GET_REWARD")
        g.wbreward = true
        return
    end
    g.index = g.index + 1
end

function Mini_addons_WEEKLY_BOSS_REWARD_SWITCH(frame, ctrl, str, num)
    if g.settings.reward_switch == 1 then
        g.settings.reward_switch = 0
        ctrl:SetText(g.lang == "Japanese" and "{ol}今週分" or "{ol}this week")
    else
        g.settings.reward_switch = 1
        ctrl:SetText(g.lang == "Japanese" and "{ol}先週分" or "{ol}last week")
    end
    Mini_addons_save_settings()
end
