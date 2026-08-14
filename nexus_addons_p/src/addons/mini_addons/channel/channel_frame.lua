-- チャンネル切替フレーム
function Mini_addons_GAME_START_CHANNEL_LIST()
    if g.settings.channel_info == 0 then
        return
    end
    Mini_addons_POPUP_CHANNEL_LIST()
    local sysmenu = ui.GetFrame("sysmenu")
    if sysmenu then
        local system = GET_CHILD(sysmenu, "system")
        if system then
            if system:HaveUpdateScript("Mini_addons_POPUP_CHANNEL_LIST") == false then
                system:RunUpdateScript("Mini_addons_POPUP_CHANNEL_LIST", 2)
            end
        end
    end
end

function Mini_addons_POPUP_CHANNEL_LIST()
    local zone_insts = session.serverState.GetMap()
    local frame_name = (addon_name_lower .. "_channel")
    -- この関数は sysmenu/system(自分のフレームではない)へ 2 秒周期の更新スクリプトとして
    -- 掛かっており、1 を返す限り走り続ける。Mini_addons_teardown は自分のフレームしか
    -- 畳めないので、機能 OFF にしてもここが生き残り、2 秒後にフレームを作り直していた。
    -- 0 を返すと更新スクリプトが外れるので、OFF はここで止める。再び ON にすれば
    -- Mini_addons_GAME_START_CHANNEL_LIST が HaveUpdateScript を見て掛け直す。
    -- チャンネル表示だけ OFF にした場合も同じ経路で片付く。
    if not core_g.settings or not core_g.settings.mini_addons or core_g.settings.mini_addons.use ~= 1 or
        not g.settings or g.settings.channel_info == 0 then
        ui.DestroyFrame(frame_name)
        core_g.vlog("mini_addons: チャンネル窓の更新を止めた(機能 OFF)")
        return 0
    end
    if not zone_insts then
        local frame = ui.GetFrame(frame_name)
        if frame then
            frame:ShowWindow(0)
        end
        g.zone_insts = false
        return 0
    else
        g.zone_insts = true
    end
    local frame = ui.CreateNewFrame("notice_on_pc", frame_name, 10, 10, 10, 10)
    AUTO_CAST(frame)
    frame:RemoveAllChild()
    frame:SetSkinName("None")
    frame:SetTitleBarSkin("None")
    frame:EnableHittestFrame(1)
    frame:EnableMove(1)
    if not g.settings.frame_X then
        g.settings.frame_X = 1500
        g.settings.frame_Y = 385
        Mini_addons_save_settings()
    end
    if not g.settings.ch_frame_size then
        g.settings.ch_frame_size = 40
        Mini_addons_save_settings()
    end
    local map_frame = ui.GetFrame("map")
    local screen_width = map_frame:GetWidth()
    local x = g.settings.frame_X
    local y = g.settings.frame_Y
    if x > 1920 and screen_width <= 1920 then
        x = 1500
        y = 385
    end
    frame:SetPos(x, y)
    frame:SetEventScript(ui.LBUTTONUP, "Mini_addons_channelframe_move")
    frame:SetEventScript(ui.RBUTTONUP, "Mini_addons_ch_frame_resize")
    local title = frame:CreateOrGetControl("richtext", "title", 5, 0)
    title:SetText("{ol}{s12}channel info")
    if zone_insts:NeedToCheckUpdate() == true then
        app.RequestChannelTraffics()
    end
    local cnt = zone_insts:GetZoneInstCount()
    local current_channel = session.loginInfo.GetChannel()
    local size = g.settings.ch_frame_size
    for i = 0, cnt - 1 do
        local zone_inst = zone_insts:GetZoneInstByIndex(i)
        local pc_count = zone_inst.pcCount
        local btn = frame:CreateOrGetControl("button", "slot" .. i, i * size + 5, 15, size, size)
        AUTO_CAST(btn)
        btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_ch_change")
        btn:SetEventScriptArgString(ui.LBUTTONUP, i)
        if i == current_channel then
            btn:SetSkinName("test_pvp_btn")
        end
        local color_tag = ""
        if tonumber(pc_count) >= 50 then
            color_tag = "{#FF0000}" -- 赤
        elseif tonumber(pc_count) >= 20 then
            color_tag = "{#FFCC33}" -- 黄
        else
            color_tag = "" -- デフォルト(白)
        end
        local text = string.format("{ol}{s12}ch%d{nl}{s16}%s%d", i + 1, color_tag, pc_count)
        btn:SetText(text)
    end
    frame:Resize(cnt * size + 20, 60)
    frame:ShowWindow(1)
    return 1
end

function Mini_addons_channelframe_move(frame)
    g.settings.frame_X = frame:GetX()
    g.settings.frame_Y = frame:GetY()
    Mini_addons_save_settings()
end

function Mini_addons_ch_frame_resize(frame, btn, str, num)
    if g.settings.ch_frame_size == 40 then
        g.settings.ch_frame_size = 50
    else
        g.settings.ch_frame_size = 40
    end
    Mini_addons_save_settings()
    Mini_addons_POPUP_CHANNEL_LIST()
end

function Mini_addons_ch_change(frame, ctrl, str, num)
    local channel = tonumber(str) -- 0が1chらしい
    RUN_GAMEEXIT_TIMER("Channel", str)
end
