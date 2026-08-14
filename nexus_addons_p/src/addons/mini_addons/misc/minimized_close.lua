-- 小さいボタンをレイドで非表示
function Mini_addons_MINIMIZED_CLOSE()
    if g.settings.mini_btn == 0 then
        return
    end
    if g.get_map_type() ~= "Instance" then
        return
    end
    local tp_button = ui.GetFrame("openingameshopbtn") -- TP受け取りボタン
    if tp_button and tp_button:IsVisible() == 1 then
        tp_button:ShowWindow(0)
    end
    local pilgrim_mode = ui.GetFrame("minimized_pilgrim_mode") -- ピルグリムボタン
    if pilgrim_mode and pilgrim_mode:IsVisible() == 1 then
        pilgrim_mode:ShowWindow(0)
    end
    local total_shop_button = ui.GetFrame("minimized_total_shop_button") -- マーケットとかのボタン
    if total_shop_button and total_shop_button:IsVisible() == 1 then
        total_shop_button:ShowWindow(0)
    end
    local total_party_button = ui.GetFrame("minimized_total_party_button") -- パーティー募集ボタン
    if total_party_button and total_party_button:IsVisible() == 1 then
        total_party_button:ShowWindow(0)
    end
    local tpshop_button = ui.GetFrame("minimized_tp_button") -- TPショップボタン
    if tpshop_button and tpshop_button:IsVisible() == 1 then
        tpshop_button:ShowWindow(0)
    end
    local total_bord = ui.GetFrame("minimized_total_board_button") -- 掲示板
    if total_bord and total_bord:IsVisible() == 1 then
        total_bord:ShowWindow(0)
    end
    local guidequest = ui.GetFrame("minimized_guidequest_button") -- なんか冒険者ガイドのやつ
    if guidequest and guidequest:IsVisible() == 1 then
        guidequest:ShowWindow(0)
    end
    local menu = ui.GetFrame("minimized_fullscreen_navigation_menu_button") -- menu
    if menu and menu:IsVisible() == 1 then
        menu:ShowWindow(0)
    end
end
