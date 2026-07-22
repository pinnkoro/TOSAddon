-- Dungeon RP charger ここから
function dungeon_rp_charger_on_init()
    if g.map_id == 11244 then -- 11244 未知の聖域3F -- 40049 レリックバフ -- 11030036 エクトナイト(マケ売り可) misc_Ectonite    -- 11030451 エクトナイト misc_Ectonite_Care
        local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
        if _nexus_addons_p then
            local dungeon_rp_charger_timer = GET_CHILD(_nexus_addons_p, "dungeon_rp_charger_timer")
            if not dungeon_rp_charger_timer then
                dungeon_rp_charger_timer = _nexus_addons_p:CreateOrGetControl("timer", "dungeon_rp_charger_timer", 0, 0)
            end
            AUTO_CAST(dungeon_rp_charger_timer)
            dungeon_rp_charger_timer:SetUpdateScript("Dungeon_rp_charger_auto_charge")
            dungeon_rp_charger_timer:Start(3.0)
        end
    end
end

--[[function Dungeon_rp_charger_BUFF_ADD(frame, msg, str, buff_id)
    if g.settings.dungeon_rp_charger.use == 0 then
        return
    end
    if buff_id == 40049 then
        local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
        if _nexus_addons_p then
            _nexus_addons_p:SetVisible(1)
            local dungeon_rp_charger_timer = GET_CHILD(_nexus_addons_p, "dungeon_rp_charger_timer")
            if not dungeon_rp_charger_timer then
                dungeon_rp_charger_timer = _nexus_addons_p:CreateOrGetControl("timer", "dungeon_rp_charger_timer", 0, 0)
            end
            AUTO_CAST(dungeon_rp_charger_timer)
            dungeon_rp_charger_timer:SetUpdateScript("Dungeon_rp_charger_auto_charge")
            dungeon_rp_charger_timer:Start(1.0)
        end
    end
end]]

function Dungeon_rp_charger_auto_charge(_nexus_addons_p, dungeon_rp_charger_timer)
    if g.settings.dungeon_rp_charger.use == 0 then
        return
    end
    local pc = GetMyPCObject()
    local cur_rp, max_rp = shared_item_relic.get_rp(pc)
    if cur_rp >= 200 then
        return
    end
    session.ResetItemList()
    local mat_item = session.GetInvItemByType(11030451)
    if not mat_item then
        mat_item = session.GetInvItemByType(11030036)
        if not mat_item then
            return
        end
    end
    if mat_item.isLockState then
        return
    end
    local item_index = mat_item:GetIESID()
    local cur_count = mat_item.count
    local recharge_count = math.floor((max_rp - cur_rp) / 10)
    if cur_count and cur_count > 0 then
        if recharge_count > cur_count then
            recharge_count = cur_count
        end
        if recharge_count > 0 then
            session.AddItemID(item_index, recharge_count)
            local result_list = session.GetItemIDList()
            item.DialogTransaction('RELIC_CHARGE_RP', result_list)
        end
    end
end
-- Dungeon RP charger ここまで

