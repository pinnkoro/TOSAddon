-- 最初回のイベントバナーのレイヤー下げる
function Mini_addons_event_banner_layer()
    local ingameeventbanner = ui.GetFrame("ingameeventbanner")
    if ingameeventbanner and ingameeventbanner:IsVisible() == 1 then
        AUTO_CAST(ingameeventbanner)
        ingameeventbanner:SetLayerLevel(99)
    end
end
-- 追加報酬券チェック ここから
local multiple_tokens = {
    ["Goddess_Raid_DespairIsland_Party"] = {11200361, 11200362},
    ["Goddess_Raid_BlackRevelation_Party"] = {11200387, 11200388},
    ["Goddess_Raid_CollapsingMine_Party"] = {11200395, 11200396},
    ["Goddess_Raid_Redania_Party"] = {11200403, 11200404},
    ["Goddess_Raid_Laimara_Party"] = {11200434, 11200435},
    ["Goddess_Raid_Veliora_Party"] = {11200438, 11200439}
}
function Mini_addons_REQ_PLAYER_CONTENTS_RECORD(frame, msg)
    if g.settings.multiple_item == 0 then
        return
    end
    local current_raid_name = session.mgame.GetCurrentMGameName()
    local target_tokens = multiple_tokens[current_raid_name]
    if not target_tokens then
        return
    end
    local function has_inv_item(target_cls_id)
        local inv_item_list = session.GetInvItemList()
        local guid_list = inv_item_list:GetGuidList()
        local cnt = guid_list:Count()
        for i = 0, cnt - 1 do
            local guid = guid_list:Get(i)
            local inv_item = inv_item_list:GetItemByGuid(guid)
            if inv_item and inv_item.type == target_cls_id then
                return true
            end
        end
        return false
    end
    for _, token_id in ipairs(target_tokens) do
        if has_inv_item(token_id) then
            local msg = g.lang == "Japanese" and "追加報酬券持ってるで！！" or
                            "I've got Additional Reward Tickets!"
            _G.imcAddOn.BroadMsg("NOTICE_Dm_Global_Shout", "{st55_a}{#FF8C00}" .. msg, 10)
            if _G["NICO_CHAT"] then
                for j = 1, 10 do
                    NICO_CHAT(string.format("{@st55_a}%s", msg))
                end
            end
            return 0
        end
    end
end
