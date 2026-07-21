-- revival_timer ここから
function Revival_timer_save_settings()
    g.save_json(g.revival_timer_path, g.revival_timer_settings)
end

function Revival_timer_load_settings()
    g.revival_timer_path = string.format("../addons/%s/%s/revival_timer.json", addon_name_lower, g.active_id)
    local settings = g.load_json(g.revival_timer_path)
    if not settings then
        settings = {
            x = 400,
            y = 300,
            set_second = 60,
            set_text = "",
            ptchat = false,
            nicochat = false,
            shortcut = false,
            shortcut_l = false
        }
    end
    g.revival_timer_settings = settings
    Revival_timer_save_settings()
end

function revival_timer_on_init()
    if not g.revival_timer_settings then
        Revival_timer_load_settings()
    end
    local old_func = g.settings.revival_timer.old_init_func
    if _G[old_func] then
        return
    end
    if g.settings.revival_timer.use == 1 then
        Revival_timer_frame_init()
    else
        local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
        _nexus_addons_p:RemoveChild("Revival_timer_keypress")
        local revival_timer = ui.GetFrame(addon_name_lower .. "revival_timer")
        if revival_timer then
            revival_timer:ShowWindow(0)
        end
    end
    g.setup_hook_and_event(g.addon, "EXEC_CHATMACRO", "Revival_timer_EXEC_CHATMACRO", false)
end

function Revival_timer_frame_init()
    local revival_timer = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "revival_timer", 0, 0, 0, 0)
    AUTO_CAST(revival_timer)
    revival_timer:RemoveAllChild()
    revival_timer:SetPos(g.revival_timer_settings.x, g.revival_timer_settings.y)
    revival_timer:SetSkinName("bg2")
    revival_timer:SetLayerLevel(61)
    revival_timer:Resize(160, 130)
    revival_timer:EnableHittestFrame(1)
    revival_timer:EnableMove(1)
    revival_timer:SetEventScript(ui.LBUTTONUP, "Revival_timer_end_drag")
    local close = revival_timer:CreateOrGetControl("button", "close", 0, 0, 30, 30)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Revival_timer_frame_close")
    local info_text = revival_timer:CreateOrGetControl('richtext', 'info_text', 10, 10, 50, 20)
    AUTO_CAST(info_text)
    local timer_text = revival_timer:CreateOrGetControl('richtext', 'timer_text', 15, 30, 50, 20)
    AUTO_CAST(timer_text)
    local loop_text = revival_timer:CreateOrGetControl('richtext', 'loop_text', 10, 90, 50, 20)
    AUTO_CAST(loop_text)
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    _nexus_addons_p:SetVisible(1)
    local revival_timer_keypress = _nexus_addons_p:CreateOrGetControl("timer", "revival_timer_keypress", 0, 0)
    AUTO_CAST(revival_timer_keypress)
    revival_timer_keypress:SetUpdateScript("Revival_timer_keypress")
    revival_timer_keypress:Start(0.1)
    g.revival_timer_last_keypress = 0
end

function Revival_timer_end_drag(frame)
    g.revival_timer_settings.x = frame:GetX()
    g.revival_timer_settings.y = frame:GetY()
    Revival_timer_save_settings()
end

function Revival_timer_frame_close(frame)
    if frame:GetName() == addon_name_lower .. "revival_timer_setting" then
        ui.DestroyFrame(frame:GetName())
    else
        frame:ShowWindow(0)
        frame:SetPos(g.revival_timer_settings.x, g.revival_timer_settings.y)
        -- frame:SetVisible(1)
    end
end

function Revival_timer_setting()
    local list_frame = ui.GetFrame(addon_name_lower .. "list_frame")
    local setting = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "revival_timer_setting", 0, 0, 0, 0)
    AUTO_CAST(setting)
    setting:Resize(240, 420)
    setting:SetPos(list_frame:GetX() + list_frame:GetWidth(), list_frame:GetY())
    setting:SetSkinName("test_frame_low")
    setting:EnableHittestFrame(1)
    setting:EnableHitTest(1)
    setting:SetLayerLevel(999)
    setting:RemoveAllChild()
    local title_text = setting:CreateOrGetControl('richtext', 'title_text', 20, 15, 50, 30)
    AUTO_CAST(title_text)
    title_text:SetText("{ol}Lets Go Home Config")
    local close = setting:CreateOrGetControl("button", "close", 0, 0, 20, 20)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Revival_timer_frame_close")
    local gbox = setting:CreateOrGetControl("groupbox", "gbox", 10, 40, setting:GetWidth() - 20,
        setting:GetHeight() - 50)
    AUTO_CAST(gbox)
    gbox:SetSkinName("test_frame_midle_light")
    local info_text = gbox:CreateOrGetControl('richtext', 'info_text', 10, 10, 50, 20)
    AUTO_CAST(info_text)
    info_text:SetText(g.lang == "Japanese" and "{ol}お知らせメッセージ" or "{ol}Notice Text")
    local info_edit = gbox:CreateOrGetControl('edit', 'info_edit', 10, 30, 140, 30)
    AUTO_CAST(info_edit)
    info_edit:SetFontName("white_16_ol")
    info_edit:SetTextAlign("center", "center")
    info_edit:SetText("{ol}" .. g.revival_timer_settings.set_text)
    info_edit:SetEventScript(ui.ENTERKEY, "Revival_timer_edit_save")
    local set_second = gbox:CreateOrGetControl('richtext', 'set_second', 10, 65, 50, 20)
    AUTO_CAST(set_second)
    set_second:SetText(g.lang == "Japanese" and "{ol}秒数設定" or "{ol}Set Seconds")
    local set_second_edit = gbox:CreateOrGetControl('edit', 'set_second_edit', 10, 85, 80, 30)
    AUTO_CAST(set_second_edit)
    set_second_edit:SetFontName("white_16_ol")
    set_second_edit:SetTextAlign("center", "center")
    set_second_edit:SetNumberMode(1)
    set_second_edit:SetText("{ol}" .. g.revival_timer_settings.set_second)
    set_second_edit:SetEventScript(ui.ENTERKEY, "Revival_timer_edit_save")
    local with_ptchat = gbox:CreateOrGetControl('checkbox', "with_ptchat", 10, 120, 30, 30)
    AUTO_CAST(with_ptchat)
    with_ptchat:SetCheck(g.revival_timer_settings.ptchat and 1 or 0)
    with_ptchat:SetEventScript(ui.LBUTTONDOWN, 'Revival_timer_checkbox_save')
    with_ptchat:SetText(g.lang == "Japanese" and "{ol}PTチャット表示" or "{ol}Show PT Chat")
    local nicochat = gbox:CreateOrGetControl('checkbox', "nicochat", 10, 150, 30, 30)
    AUTO_CAST(nicochat)
    nicochat:SetCheck(g.revival_timer_settings.nicochat and 1 or 0)
    nicochat:SetEventScript(ui.LBUTTONDOWN, 'Revival_timer_checkbox_save')
    nicochat:SetText(g.lang == "Japanese" and "{ol}ニコチャット表示" or "{ol}Show Nico Chat")
    local short_cut = gbox:CreateOrGetControl('checkbox', "short_cut", 10, 180, 30, 30)
    AUTO_CAST(short_cut)
    short_cut:SetCheck(g.revival_timer_settings.shortcut and 1 or 0)
    short_cut:SetEventScript(ui.LBUTTONDOWN, 'Revival_timer_checkbox_save')
    short_cut:SetText(g.lang == "Japanese" and "{ol}ショートカット使用" .. "{nl}{#FFD700}(Right ALT)" or
                          "{ol}Use shortcut" .. "{nl}{#FFD700}(Right ALT)")
    local short_cut_l = gbox:CreateOrGetControl('checkbox', "short_cut_l", 10, 220, 30, 30)
    AUTO_CAST(short_cut_l)
    short_cut_l:SetCheck(g.revival_timer_settings.shortcut_l and 1 or 0)
    short_cut_l:SetEventScript(ui.LBUTTONDOWN, 'Revival_timer_checkbox_save')
    short_cut_l:SetText(g.lang == "Japanese" and "{ol}ショートカット使用" .. "{nl}{#FFD700}(Left ALT)" or
                            "{ol}Use shortcut" .. "{nl}{#FFD700}(Left ALT)")
    local show_timer = gbox:CreateOrGetControl("button", "show_timer", 50, 270, 100, 40)
    AUTO_CAST(show_timer)
    show_timer:SetText(g.lang == "Japanese" and "{ol}テスト表示" or "{ol}Test Show")
    show_timer:SetEventScript(ui.LBUTTONUP, "Revival_timer_test_show")
    show_timer:SetEventScriptArgString(ui.LBUTTONUP, "test")
    local notice = gbox:CreateOrGetControl('richtext', 'notice', 10, 320, 100, 20)
    AUTO_CAST(notice)
    notice:SetText(g.lang == "Japanese" and
                       "{ol}スタートと非表示は{nl}チャットコマンド{#FFD700}'/rtimer'" or
                       "{ol}Start and hide with the{nl}chat command{#FFD700}'/rtimer'")
    setting:ShowWindow(1)
end

function Revival_timer_edit_save(frame, ctrl)
    local ctrl_name = ctrl:GetName()
    if ctrl_name == "info_edit" then
        g.revival_timer_settings.set_text = ctrl:GetText()
    elseif ctrl_name == "set_second_edit" then
        g.revival_timer_settings.set_second = tonumber(ctrl:GetText())
    end
    Revival_timer_save_settings()
    Revival_timer_setting()
end

function Revival_timer_checkbox_save(frame, ctrl)
    local ctrl_name = ctrl:GetName()
    local is_check = ctrl:IsChecked()
    if ctrl_name == "with_ptchat" then
        g.revival_timer_settings.ptchat = is_check == 1 and true or false
    elseif ctrl_name == "nicochat" then
        g.revival_timer_settings.nicochat = is_check == 1 and true or false
    elseif ctrl_name == "short_cut" then
        g.revival_timer_settings.shortcut = is_check == 1 and true or false
    elseif ctrl_name == "short_cut_l" then
        g.revival_timer_settings.shortcut_l = is_check == 1 and true or false
    end
    Revival_timer_save_settings()
end

function Revival_timer_test_show(frame)
    local revival_timer_setting = ui.GetFrame(addon_name_lower .. "revival_timer_setting")
    local revival_timer = ui.GetFrame(addon_name_lower .. "revival_timer")
    revival_timer:SetPos(revival_timer_setting:GetX() + revival_timer_setting:GetWidth(), revival_timer_setting:GetY())
    g.revival_timer_start_time = imcTime.GetAppTimeMS()
    g.revival_timer_announced = 0
    local revival_timer_timer = revival_timer:CreateOrGetControl("timer", "revival_timer_timer", 0, 0)
    AUTO_CAST(revival_timer_timer)
    revival_timer_timer:SetUpdateScript("Revival_timer_update")
    revival_timer_timer:Start(0.1)
    revival_timer:ShowWindow(1)
    revival_timer:RunUpdateScript("Revival_timer_frame_close", 10.0)
end

function Revival_timer_EXEC_CHATMACRO(my_frame, my_msg)
    local index = g.get_event_args(my_msg)
    if g.settings.revival_timer.use == 0 then
        g.FUNCS["EXEC_CHATMACRO"](index)
        return
    end
    local macro = GET_CHAT_MACRO(index)
    if not macro then
        return
    end
    local pose_cls = GetClassByType('Pose', macro.poseID)
    if pose_cls then
        control.Pose(pose_cls.ClassName)
    end
    if macro.macro == "" then
        return
    end
    local msg = macro.macro
    if string.find(msg, "/rtimer", 1, true) then
        local revival_timer = ui.GetFrame(addon_name_lower .. "revival_timer")
        if revival_timer:IsVisible() == 1 then
            revival_timer:ShowWindow(0)
            return
        else
            g.revival_timer_start_time = imcTime.GetAppTimeMS()
            g.revival_timer_announced = 0
            local revival_timer_timer = revival_timer:CreateOrGetControl("timer", "revival_timer_timer", 0, 0)
            AUTO_CAST(revival_timer_timer)
            revival_timer_timer:SetUpdateScript("Revival_timer_update")
            revival_timer_timer:Start(0.1)
            revival_timer:ShowWindow(1)
        end
    end
    ui.Chat(REPLACE_EMOTICON(macro.macro))
end

function Revival_timer_keypress(_nexus_addons_p)
    if not g.revival_timer_settings.shortcut and not g.revival_timer_settings.shortcut_l then
        return
    end
    local cool_down = 200 -- 200ミリ秒
    local now = imcTime.GetAppTimeMS()
    if now - g.revival_timer_last_keypress < cool_down then
        return
    end
    g.revival_timer_last_keypress = now
    if (1 == keyboard.IsKeyPressed("RALT") and g.revival_timer_settings.shortcut) or
        (1 == keyboard.IsKeyPressed("LALT") and g.revival_timer_settings.shortcut_l) then
        g.revival_timer_last_keypress = now
        local revival_timer = ui.GetFrame(addon_name_lower .. "revival_timer")
        if revival_timer:IsVisible() == 0 then
            g.revival_timer_start_time = imcTime.GetAppTimeMS()
            g.revival_timer_announced = 0
            local revival_timer_timer = revival_timer:CreateOrGetControl("timer", "revival_timer_timer", 0, 0)
            AUTO_CAST(revival_timer_timer)
            revival_timer_timer:SetUpdateScript("Revival_timer_update")
            revival_timer_timer:Start(0.1)
            revival_timer:ShowWindow(1)
        else
            revival_timer:ShowWindow(0)
        end
    end
end

function Revival_timer_update(revival_timer, revival_timer_timer)
    local elapsed_ms = imcTime.GetAppTimeMS() - g.revival_timer_start_time
    local remaining_s = g.revival_timer_settings.set_second - math.floor(elapsed_ms / 1000)
    if remaining_s < 0 then
        Revival_timer_loop_timer()
        return
    end
    local info_text = GET_CHILD(revival_timer, "info_text")
    info_text:SetText("{ol}{#FF0000}{s20}" .. g.revival_timer_settings.set_text)
    local loop_text = GET_CHILD(revival_timer, "loop_text")
    local m = math.floor((g.revival_timer_settings.set_second / 60) % 60)
    local s = math.floor(g.revival_timer_settings.set_second % 60)
    loop_text:SetText("{ol}Set Time : " .. string.format("%02d:%02d{/}", m, s))
    local timer_text = GET_CHILD(revival_timer, "timer_text")
    local m = math.floor((remaining_s / 60) % 60)
    local s = math.floor(remaining_s % 60)
    timer_text:SetText(string.format("{ol}{s46}%02d:%02d{/}", m, s))
    local diff_time = g.revival_timer_start_time - imcTime.GetAppTimeMS()
    if remaining_s <= 10 and g.revival_timer_announced == 0 then
        g.revival_timer_announced = 1
        local suffix = g.lang == "Japanese" and " 10秒前" or " 10 sec rem."
        local msg = "/p " .. g.revival_timer_settings.set_text .. suffix
        if g.revival_timer_settings.ptchat then
            _UI_CHAT(msg)
        end
        if g.revival_timer_settings.nicochat then
            Revival_timer_NICO_CHAT("{@st55_a}" .. g.revival_timer_settings.set_text .. suffix)
        end
    elseif remaining_s <= 5 and g.revival_timer_announced == 1 then
        g.revival_timer_announced = 2
        local suffix = g.lang == "Japanese" and " 5秒前" or " 5 sec rem."
        local msg = "/p " .. g.revival_timer_settings.set_text .. suffix
        if g.revival_timer_settings.ptchat then
            _UI_CHAT(msg)
        end
        if g.revival_timer_settings.nicochat then
            Revival_timer_NICO_CHAT("{@st55_a}" .. g.revival_timer_settings.set_text .. suffix)
        end
    end
end

function Revival_timer_loop_timer()
    g.revival_timer_start_time = imcTime.GetAppTimeMS()
    g.revival_timer_announced = 0
end

function Revival_timer_NICO_CHAT(msg)
    local x = ui.GetClientInitialWidth()
    local y = ui.GetClientInitialHeight() * 0.6
    local nico_chat = ui.GetFrame("nico_chat")
    change_client_size(nico_chat)
    local name = UI_EFFECT_GET_NAME(nico_chat, "NICO_")
    local nico_text = nico_chat:CreateControl("richtext", name, x, y, 200, 20)
    AUTO_CAST(nico_text)
    nico_chat:SetLayerLevel(90)
    nico_chat:ShowWindow(1)
    nico_text:EnableResizeByText(1)
    nico_text:SetText(msg)
    nico_text:RunUpdateScript("NICO_MOVING")
    nico_text:SetUserValue("NICO_SPD", -150)
    nico_text:SetUserValue("NICO_START_X", x)
    nico_text:ShowWindow(1)
    nico_chat:RunUpdateScript("INVALIDATE_NICO")
end
-- revival_timer ここまで

