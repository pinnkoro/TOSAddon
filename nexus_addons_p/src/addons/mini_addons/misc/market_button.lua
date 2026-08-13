-- 町でマーケットボタンを常に表示
function Mini_addons_MINIMIZED_TOTAL_SHOP_BUTTON_CLICK()
    local market_button = ui.GetFrame("minimized_market_button")
    if g.settings.market_display == 1 and market_button:IsVisible() == 0 then
        MINIMIZED_TOTAL_SHOP_BUTTON_CLICK()
    end
end
