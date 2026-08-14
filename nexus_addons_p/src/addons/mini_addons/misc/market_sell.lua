-- マーケット販売時に持ってる最大値を自動入力
function Mini_addons_MARKET_SELL_UPDATE_REG_SLOT_ITEM(frame, msg)
    local market_sell = ui.GetFrame("market_sell")
    local edit_count = GET_CHILD_RECURSIVELY(market_sell, "edit_count")
    AUTO_CAST(edit_count)
    local slot = GET_CHILD_RECURSIVELY(market_sell, "slot_item")
    local icon = slot:GetIcon()
    if icon then
        local info = icon:GetInfo()
        local iesid = info:GetIESID()
        local inv_item = session.GetInvItemByGuid(iesid)
        if inv_item then
            edit_count:SetText(inv_item.count)
        end
    end
end
