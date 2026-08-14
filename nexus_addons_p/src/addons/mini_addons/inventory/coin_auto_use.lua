-- 傭兵団コイン、女神コイン、王国再建団コインを取得時、自動で使用
function Mini_addons_INV_ICON_USE(mini_addons)
    if g.settings.coin_use == 0 then
        return
    end
    if g.get_map_type() ~= "City" then
        return
    end
    local god_protection = ui.GetFrame("godprotection")
    if god_protection:IsVisible() == 1 then
        return
    end
    local inv_item_list = session.GetInvItemList()
    local guid_list = inv_item_list:GetGuidList()
    local cnt = guid_list:Count()
    for i = 0, cnt - 1 do
        local guid = guid_list:Get(i)
        local inv_item = inv_item_list:GetItemByGuid(guid)
        local item_obj = GetIES(inv_item:GetObject())
        for _, coin_id in ipairs(COIN_ITEM) do
            if item_obj.ClassID == coin_id then
                item.UseByGUID(guid)
                return
            end
        end
    end
end
