function Mini_addons_FPS_UPDATE()
    -- オートズーム
    Mini_addons_autozoom()
    -- 傭兵団コイン獲得フレームを表示
    if g.get_map_type() == "City" then
        local coin_get_gauge = ui.GetFrame("coin_get_gauge")
        if config.GetXMLStrConfig("ShowCoinGetGauge") ~= "0" and coin_get_gauge:IsVisible() == 0 then
            coin_get_gauge:ShowWindow(1)
        end
    end
    -- ESC などで隠れたメニューボタンを出し直す。ただし
    -- 「システムメニューの右クリックのみにする」(core/90_addons_menu.lua の sysmenu_only)を
    -- 選んでいるときは、意図して隠しているので出し直さない。
    -- ここは毎フレーム走るので、設定を見ないと消した直後に必ず復活する(実機で発生)。
    if _G["norisan"] and _G["norisan"]["MENU"] and _G["norisan"]["MENU"].sysmenu_only == 1 then
        return
    end
    local norisan_menu_frame = ui.GetFrame("norisan_menu_frame")
    if norisan_menu_frame and norisan_menu_frame:IsVisible() == 0 then
        norisan_menu_frame:ShowWindow(1)
    end
end

function Mini_addons_make_menu(frame)
    _G["norisan"] = _G["norisan"] or {}
    _G["norisan"]["MENU"] = _G["norisan"]["MENU"] or {}
    local menu_data = {
        name = "Mini Addons",
        icon = "sysmenu_jal",
        func = "Mini_addons_SETTING_FRAME_INIT",
        image = ""
    }
    _G["norisan"]["MENU"][addon_name] = menu_data
    core_g.vlog("mini_addons: メニューへ登録 key=%s", tostring(addon_name))
    local frame_name = _G["norisan"]["MENU"].frame_name
    local menu_frame = ui.GetFrame(frame_name)
    if menu_frame and frame_name ~= "norisan_menu_frame" then
        ui.DestroyFrame(frame_name)
    end
    frame_name = "norisan_menu_frame"
    menu_frame = ui.GetFrame(frame_name)
    -- sysmenu_only のときは「隠れている」が正常なので作り直さない
    -- (作り直すと create_frame 側が非表示で作るため、毎回作り直し続けることになる)。
    if _G["norisan"]["MENU"].sysmenu_only == 1 then
        return 0
    end
    if not menu_frame or menu_frame:IsVisible() == 0 then
        _G["norisan"]["MENU"].frame_name = frame_name
        _G.addons_menu_create_frame()
        return 1
    end
    return 0
end

function Mini_addons_runupdate_5(mini_addons)
    -- セパレートバフフレームの周りを綺麗に
    Mini_addons_buff_separatedlist()
    -- クポルポーションフレームの移動と非表示
    Mini_addons_cupole_portion_frame()
    -- パーティーメンバーの場所表示
    Mini_addons_partymember_get_map()
    local restart = ui.GetFrame("restart")
    if restart:IsVisible() == 0 then
        restart:SetUserValue("COLONY_TIMER_RUNNING", 0)
    end
    local mini_addons_channel = ui.GetFrame((addon_name_lower .. "_channel"))
    if g.zone_insts and mini_addons_channel and mini_addons_channel:IsVisible() == 0 then
        mini_addons_channel:ShowWindow(1)
    end
    -- 町でマーケットボタンを常に表示
    Mini_addons_MINIMIZED_TOTAL_SHOP_BUTTON_CLICK()
    -- 傭兵団コイン、女神コイン、王国再建団コインを取得時、自動で使用
    Mini_addons_INV_ICON_USE()
    -- 町でBGMPLAYERを常に動かす
    Mini_addons_BGM_PLAY_LIST()
    -- パーティー情報フレームを小さくする
    Mini_addons_PARTY_BUFFLIST_UPDATE()
    return 1
end

