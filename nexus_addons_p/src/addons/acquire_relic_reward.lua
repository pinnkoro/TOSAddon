-- Acquire relic reward ここから
function acquire_relic_reward_on_init()
    if g.settings.acquire_relic_reward.use == 0 then
        return
    end
    if g.map_name == "c_Klaipe" or g.map_name == "c_fedimian" or g.map_name == "c_orsha" then
        local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
        if _nexus_addons_p then
            _nexus_addons_p:SetVisible(1)
            _nexus_addons_p:RunUpdateScript("Acquire_relic_reward_process", 1.0)
        end
    end
end

function Acquire_relic_reward_process(_nexus_addons_p)
    local pc_obj = GetMyPCObject()
    local cls_list, cnt = GetClassList("Relic_Quest")
    for i = 0, cnt - 1 do
        local relic_cls = GetClassByIndexFromList(cls_list, i)
        local quest_type = TryGetProp(relic_cls, 'QuestType', 'None')
        if quest_type ~= 'None' then
            local result = SCR_RELIC_QUEST_CHECK(pc_obj, relic_cls.ClassName)
            if result == "Reward" then
                pc.ReqExecuteTx("SCR_TX_RELIC_QUEST_REWARD", relic_cls.ClassName)
                return 1
            end
        end
    end
    _nexus_addons_p:StopUpdateScript("Acquire_relic_reward_process")
    return 0
end
-- Acquire relic reward ここまで

