-- ちょい残し　ここから
local reward_map = {"125000", "2000000", "5000000", "10000000", "18750000", "25000000", "37500000", "50000000",
                    "125000000", "175000000", "250000000", "300000000", "375000000", "625000000", "750000000",
                    "1250000000", "1750000000"}
function Mini_addons_WEEKLYBOSSREWARD_REWARD_OPEN(my_frame, my_msg)
    local index = g.get_event_args(my_msg)
    local weeklyboss_reward = ui.GetFrame("weeklyboss_reward")
    local btn_reward = GET_CHILD(weeklyboss_reward, "btn_reward")
    if g.settings.keep_first == 0 or index ~= 1 or btn_reward:IsEnable() == 0 then
        local my_btn = GET_CHILD(weeklyboss_reward, "my_btn")
        if my_btn then
            weeklyboss_reward:StopUpdateScript("Mini_addons_get_damage_reward")
            weeklyboss_reward:RemoveChild("my_btn")
        end
        return
    end
    local close = GET_CHILD(weeklyboss_reward, "closeBtn")
    AUTO_CAST(close)
    close:SetEventScript(ui.LBUTTONDOWN, "Mini_addons_start_get_reward_stop")
    local my_btn = weeklyboss_reward:CreateOrGetControl("button", "my_btn", 315, 655, 120, 40)
    AUTO_CAST(my_btn)
    my_btn:SetText("{ol}keep first")
    my_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_start_get_reward")
    local max_index = #reward_map
    my_btn:SetEventScriptArgString(ui.LBUTTONUP, reward_map[max_index])
    my_btn:SetEventScriptArgNumber(ui.LBUTTONUP, max_index)
end

function Mini_addons_start_get_reward_stop(weeklyboss_reward)
    local my_btn = GET_CHILD(weeklyboss_reward, "my_btn")
    my_btn:StopUpdateScript("Mini_addons_get_damage_reward")
end

function Mini_addons_start_get_reward(weeklyboss_reward, my_btn, amount_str, index_num)
    local reward = GET_CHILD_RECURSIVELY(weeklyboss_reward, "REWARD_" .. index_num)
    local attr_btn = GET_CHILD(reward, "attr_btn")
    if attr_btn and attr_btn:IsEnable() == 1 then
        local week_num = weeklyboss_reward:GetUserValue("WEEK_NUM")
        weekly_boss.RequestAcceptAbsoluteReward(week_num, amount_str)
    end
    my_btn:SetUserValue("REWARD_INDEX", index_num - 1) -- 最大値から開始
    my_btn:SetUserValue("LAST_REQ_INDEX", 0)
    my_btn:RunUpdateScript("Mini_addons_get_damage_reward", 0.3)
end

function Mini_addons_get_damage_reward(my_btn)
    local index = my_btn:GetUserIValue("REWARD_INDEX")
    if not index or index < 2 then
        return 0
    end
    local weeklyboss_reward = my_btn:GetParent()
    local reward = GET_CHILD_RECURSIVELY(weeklyboss_reward, "REWARD_" .. index)
    if reward then
        local attr_btn = GET_CHILD(reward, "attr_btn")
        if attr_btn:IsEnable() == 1 then
            local week_num = weeklyboss_reward:GetUserValue("WEEK_NUM")
            weekly_boss.RequestAcceptAbsoluteReward(week_num, reward_map[index])
            return 1
        else
            my_btn:SetUserValue("REWARD_INDEX", index - 1)
            return 1
        end
        return 1
    end
    return 0
end
