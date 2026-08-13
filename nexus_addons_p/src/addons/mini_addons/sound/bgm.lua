-- 町でBGMPLAYERを常に動かす
function Mini_addons_BGM_PLAY()
    if g.get_map_type() ~= "City" then
        ui.CloseFrame("bgmplayer_reduction")
        local bgm_player = ui.GetFrame("bgmplayer")
        local play_btn = GET_CHILD_RECURSIVELY(bgm_player, "playStart_btn")
        Mini_addons_BGMPLAYER_PLAY(bgm_player, play_btn)
        return
    end
    if g.settings.bgm == 0 then
        return
    end
    BGMPLAYER_OPEN_UI(nil, nil)
    local bgm_player = ui.GetFrame("bgmplayer")
    local player_controller_gb = GET_CHILD_RECURSIVELY(bgm_player, "playercontroler_gb")
    local play_start_btn = GET_CHILD_RECURSIVELY(bgm_player, "playStart_btn")
    local mode = tonumber(bgm_player:GetUserValue("MODE_ALL_LIST"))
    local option = tonumber(bgm_player:GetUserValue("MODE_FAVO_LIST"))
    local play_random = tonumber(bgm_player:GetUserConfig("PLAY_RANDOM"))
    local bgm_music_title_text = GET_CHILD_RECURSIVELY(bgm_player, "bgm_music_title")
    if bgm_music_title_text then
        local title = bgm_music_title_text:GetTextByKey("value")
        if title then
            local halt_image_name = bgm_player:GetUserConfig("PLAY_HALT_BTN_IMAGE_NAME")
            local start_image_name = bgm_player:GetUserConfig("PLAY_START_BTN_IMAGE_NAME")
            local select_ctrl_set_name = g.settings.select_bgm
            if not select_ctrl_set_name then
                return
            end
            local select_ctrl_set = GET_CHILD_RECURSIVELY(bgm_player, select_ctrl_set_name)
            local title_text = nil
            if select_ctrl_set then
                local parent = select_ctrl_set:GetParent()
                if parent ~= nil then
                    BGMPLAYER_SET_MUSIC_TITLE(bgm_player, parent, select_ctrl_set)
                end
                title_text = GET_CHILD_RECURSIVELY(select_ctrl_set, "musictitle_text")
            end
            if title_text == nil then
                return
            end
            local music_title = title_text:GetTextByKey("value")
            if music_title then
                local music_title_parts = StringSplit(music_title, ". ")
                local index_str = music_title_parts[1]
                if string.find(index_str, "{#ffc03a}") ~= nil then
                    local find_start, find_end = string.find(index_str, "{#ffc03a}")
                    if find_start ~= nil and find_end ~= nil then
                        index_str = string.sub(index_str, find_end + 1, string.len(index_str))
                    end
                end
                local index = tonumber(index_str)
                local bgm_type = GET_BGMPLAYER_MODE(bgm_player, mode, option)
                if bgm_type == 1 then
                    SetBgmCurIndex(index, play_random)
                elseif bgm_type == 0 then
                    SetBgmCurFVIndex(index, play_random)
                end
                title = bgm_music_title_text:GetTextByKey("value")
                PlayBgm(title, select_ctrl_set_name)
                BGMPLAYER_REDUCTION_SET_PLAYBTN(true)
                BGMPLAYER_REDUCTION_SET_TITLE(title)
                local total_time = GetPlayBgmTotalTime()
                total_time = total_time / 1000
                local start_time = 0
                if GetBgmPauseTime() > 0 then
                    start_time = GetBgmPauseTime() / 1000
                    SetPauseTime(0)
                end
                BGMPLAYER_PLAYTIME_GAUGE(start_time, total_time)
            end
            if play_start_btn:GetImageName() == start_image_name then
                play_start_btn:SetImage(halt_image_name)
                play_start_btn:SetTooltipArg(ScpArgMsg("BgmPlayer_HaltBtnToolTip"))
            else
                play_start_btn:SetImage(start_image_name)
                play_start_btn:SetTooltipArg(ScpArgMsg("BgmPlayer_StartBtnToolTip"))
            end
            BGMPLAYER_CLOSE_UI()
        end
    end
end

function Mini_addons_BGMPLAYER_PLAY(bgm_player, play_btn)
    local bgm_music_title_text = GET_CHILD_RECURSIVELY(bgm_player, "bgm_music_title")
    if bgm_music_title_text then
        local title = bgm_music_title_text:GetTextByKey("value")
        local delay_time = 0
        StopBgm(title, delay_time)
        BGMPLAYER_REDUCTION_SET_PLAYBTN(false)
        return
    end
end

function Mini_addons_BGM_PLAY_LIST()
    if g.settings.bgm == 0 then
        return
    end
    local bgm_player = ui.GetFrame("bgmplayer")
    if not bgm_player then
        return
    end
    if not g.settings.select_bgm or g.settings.select_bgm == "" or g.settings.select_bgm == "None" then
        g.settings.select_bgm = "MUSICINFO_1"
        Mini_addons_save_settings()
    end
    local current_sel = bgm_player:GetUserValue("CTRLSET_NAME_SELECTED")
    if bgm_player:IsVisible() == 0 and current_sel == "None" then
        bgm_player:SetUserValue("CTRLSET_NAME_SELECTED", g.settings.select_bgm)
        current_sel = g.settings.select_bgm
    end
    if current_sel ~= "None" and g.settings.select_bgm ~= current_sel then
        g.settings.select_bgm = current_sel
        Mini_addons_save_settings()
    end
end
