-- sub_map ここから
function Sub_map_save_settings()
    g.save_json(g.sub_map_path, g.sub_map_settings)
end

function Sub_map_load_settings()
    g.sub_map_path = string.format("../addons/%s/%s/sub_map.json", addon_name_lower, g.active_id)
    local settings = g.load_json(g.sub_map_path)
    local ver = 1.1
    if not settings or not settings.ver then
        settings = {
            visible = 1,
            x = 0,
            y = 0,
            skin_name = "None",
            move = 1,
            size = 200,
            minimap = 0,
            challenge_minimap = 0,
            challenge_only = 0,
            loc_name = 0,
            mob_display = 0,
            ver = ver
        }
    end
    g.sub_map_settings = settings
    Sub_map_save_settings()
end

function sub_map_on_init()
    if not g.sub_map_settings then
        Sub_map_load_settings()
    end
    local old_func = g.settings.sub_map.old_init_func
    if _G[old_func] then
        return
    end
    if g.settings.sub_map.use == 0 or g.get_map_type() == "Instance" then
        if g.settings.sub_map.use == 0 then
            ui.DestroyFrame(addon_name_lower .. "sub_map")
        end
        return
    end
    if g.get_map_type() == "Instance" then
        return
    end
    g.sub_map_handles = {}
    g.addon:RegisterMsg("MAP_CHARACTER_UPDATE", "Sub_map_MAP_CHARACTER_UPDATE")
    g.addon:RegisterMsg("MON_MINIMAP", "Sub_map_MAP_MON_MINIMAP")
    g.addon:RegisterMsg("MON_MINIMAP_END", "Sub_map_ON_MON_MINIMAP_END")
    g.addon:RegisterMsg("PARTY_INST_UPDATE", "Sub_map_MAP_UPDATE_PARTY_INST")
    g.addon:RegisterMsg("PARTY_UPDATE", "Sub_map_update_party_or_guild")
    g.addon:RegisterMsg("GUILD_INFO_UPDATE", "Sub_map_update_party_or_guild")
    g.addon:RegisterMsg("UI_CHALLENGE_MODE_TOTAL_KILL_COUNT", "Sub_map_ON_CHALLENGE_MODE_TOTAL_KILL_COUNT")
    g.sub_map_challenge_first = true
    g.sub_map_challenge = 0
    if g.get_map_type() == "City" then
        Sub_map_frame_init()
        return
    end
    if string.find(g.map_name, "GuildColony_") then
        g.sub_map_challenge = 1
    else
        local my_info = session.party.GetMyPartyObj(PARTY_NORMAL)
        if not my_info then
            return
        end
        if my_info:GetChannel() + 1 > 10 then
            g.sub_map_challenge = 1
        end
    end
    Sub_map_frame_init()
end

function Sub_map_ON_CHALLENGE_MODE_TOTAL_KILL_COUNT(frame, msg)
    if g.sub_map_challenge_first == true and g.sub_map_challenge == 0 then
        g.sub_map_challenge = 1
        Sub_map_frame_init()
        g.sub_map_challenge_first = false
    end
end

function Sub_map_settings()
    local list_frame = ui.GetFrame(addon_name_lower .. "list_frame")
    local config = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "sub_map_setting_frame", 0, 0, 0, 0)
    AUTO_CAST(config)
    config:RemoveAllChild()
    config:SetLayerLevel(999)
    config:SetSkinName("test_frame_low")
    local title_text = config:CreateOrGetControl("richtext", "title_text", 10, 10)
    AUTO_CAST(title_text)
    title_text:SetText("{ol}Sub Map")
    local config_gb = config:CreateOrGetControl("groupbox", "config_gb", 10, 40, 0, 0)
    AUTO_CAST(config_gb)
    config_gb:SetSkinName("bg")
    config:SetPos(list_frame:GetX() + list_frame:GetWidth(), list_frame:GetY())
    local close = config:CreateOrGetControl("button", "close", 0, 0, 20, 20)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Sub_map_setting_close")
    local y = 10
    local info_text = config_gb:CreateOrGetControl("richtext", "info_text", 10, y + 5, 0, 30)
    AUTO_CAST(info_text)
    info_text:SetText(g.lang == "Japanese" and "{ol}サイズ設定" or "{ol}Size setting")
    local size_edit = config_gb:CreateOrGetControl("edit", "size_edit", info_text:GetWidth() + 20, y, 100, 30)
    AUTO_CAST(size_edit)
    size_edit:SetFontName("white_16_ol")
    size_edit:SetTextAlign("center", "center")
    size_edit:SetNumberMode(1)
    size_edit:SetText("{ol}" .. g.sub_map_settings.size)
    size_edit:SetTextTooltip(g.lang == "Japanese" and "{ol}150~350の間で設定" or "{ol}Setting range: 150 to 350")
    size_edit:SetEventScript(ui.ENTERKEY, "Sub_map_setting_change")
    y = y + 40
    local move_check = config_gb:CreateOrGetControl("checkbox", "move_check", 10, y, 30, 30)
    AUTO_CAST(move_check)
    move_check:SetCheck(g.sub_map_settings.move == 1 and 0 or 1)
    move_check:SetText(g.lang == "Japanese" and "{ol}チェックするとフレーム固定" or
                           "{ol}If checked, the frame is fixed")
    move_check:SetEventScript(ui.LBUTTONUP, "Sub_map_setting_change")
    y = y + 40
    local challenge_minimap = config_gb:CreateOrGetControl("checkbox", "challenge_minimap", 10, y, 30, 30)
    AUTO_CAST(challenge_minimap)
    challenge_minimap:SetCheck(g.sub_map_settings.challenge_minimap or 0)
    challenge_minimap:SetText(g.lang == "Japanese" and
                                  "{ol}チェックするとチャレンジでミニマップモード" or
                                  "{ol}If checked, mini-map mode is enabled during the Challenge")
    challenge_minimap:SetEventScript(ui.LBUTTONUP, "Sub_map_setting_change")
    y = y + 40
    local challenge_only = config_gb:CreateOrGetControl("checkbox", "challenge_only", 10, y, 30, 30)
    AUTO_CAST(challenge_only)
    challenge_only:SetCheck(g.sub_map_settings.challenge_only or 0)
    challenge_only:SetText(g.lang == "Japanese" and "{ol}チェックするとチャレンジでのみ表示" or
                               "{ol}If checked, display only during Challenges")
    challenge_only:SetEventScript(ui.LBUTTONUP, "Sub_map_setting_change")
    y = y + 40
    local loc_name = config_gb:CreateOrGetControl("checkbox", "loc_name", 10, y, 30, 30)
    AUTO_CAST(loc_name)
    loc_name:SetCheck(g.sub_map_settings.loc_name or 0)
    loc_name:SetText(g.lang == "Japanese" and "{ol}チェックすると地域名表示" or
                         "{ol}If checked, display the region name")
    loc_name:SetEventScript(ui.LBUTTONUP, "Sub_map_setting_change")
    y = y + 40
    local mob_display = config_gb:CreateOrGetControl("checkbox", "mob_display", 10, y, 30, 30)
    AUTO_CAST(mob_display)
    mob_display:SetCheck(g.sub_map_settings.mob_display or 0)
    mob_display:SetText(g.lang == "Japanese" and "{ol}チェックするとチャレンジで雑魚を表示" or
                            "{ol}If checked, display mobs only during Challenges")
    mob_display:SetEventScript(ui.LBUTTONUP, "Sub_map_setting_change")
    y = y + 40
    local default_btn = config_gb:CreateOrGetControl("button", "default_btn", 20, y, 120, 30)
    AUTO_CAST(default_btn)
    default_btn:SetText(g.lang == "Japanese" and "{ol}フレーム初期位置" or "{ol}Init frame pos")
    default_btn:SetEventScript(ui.LBUTTONUP, "Sub_map_setting_change")
    y = y + 40
    local skin_change = config_gb:CreateOrGetControl("button", "skin_change", 20, y, 120, 30)
    AUTO_CAST(skin_change)
    skin_change:SetText(g.lang == "Japanese" and "{ol}フレームスキン変更" or "{ol}Change frame skin")
    skin_change:SetEventScript(ui.LBUTTONUP, "Sub_map_skin_change_context")
    y = y + 30
    config:Resize(challenge_minimap:GetWidth() + 40, y + 60)
    config_gb:Resize(config:GetWidth() - 20, y + 10)
    config:ShowWindow(1)
end

function Sub_map_setting_close(config)
    ui.DestroyFrame(config:GetName())
end

function Sub_map_setting_change(parent, ctrl)
    local ctrl_name = ctrl:GetName()
    if ctrl_name == "size_edit" then
        local size = tonumber(ctrl:GetText())
        if size and size >= 150 and size <= 350 then
            g.sub_map_settings.size = size
        else
            ui.SysMsg(g.lang == "Japanese" and "{ol}範囲外です" or "{ol}Out of range")
            Sub_map_settings()
            return
        end
    elseif ctrl_name == "move_check" then
        local is_check = ctrl:IsChecked()
        g.sub_map_settings.move = is_check == 1 and 0 or 1
    elseif ctrl_name == "default_btn" then
        g.sub_map_settings.x = 0
        g.sub_map_settings.y = 0
    else
        g.sub_map_settings[ctrl_name] = ctrl:IsChecked()
        if ctrl_name == "challenge_only" then
            g.sub_map_settings.visible = ctrl:IsChecked() == 1 and 0 or 1
        end
    end
    Sub_map_save_settings()
    Sub_map_frame_init()
end

function Sub_map_skin_change_context(frame, ctrl)
    local context = ui.CreateContextMenu("sub_map_context", "{ol}Sub Map Change Skin", 0, 0, 0, 0)
    ui.AddContextMenuItem(context, "-----", "None")
    ui.AddContextMenuItem(context, g.lang == "Japanese" and "{ol}無し" or "{ol}None",
        string.format("Sub_map_skin_change('%s')", "None"))
    ui.AddContextMenuItem(context, g.lang == "Japanese" and "{ol}薄め" or "{ol}Faint",
        string.format("Sub_map_skin_change('%s')", "bg2"))
    ui.AddContextMenuItem(context, g.lang == "Japanese" and "{ol}濃いめ" or "{ol}Darker",
        string.format("Sub_map_skin_change('%s')", "bg"))
    ui.OpenContextMenu(context)
end

function Sub_map_skin_change(skin_name)
    g.sub_map_settings.skin_name = skin_name
    Sub_map_save_settings()
    Sub_map_frame_init()
end

function Sub_map_frame_init()
    local sub_map = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "sub_map", 0, 0, 0, 0)
    AUTO_CAST(sub_map)
    sub_map:ShowWindow(0)
    local challenge = g.sub_map_challenge
    sub_map:SetUserValue("CHALLENGE", challenge)
    sub_map:RemoveAllChild()
    sub_map:EnableMove(g.sub_map_settings.move)
    sub_map:EnableHittestFrame(1)
    sub_map:SetTitleBarSkin("None")
    sub_map:SetGravity(ui.RIGHT, ui.TOP)
    sub_map:SetMargin(0, 0, 0, 0)
    local use_minimap = (challenge == 1 and g.sub_map_settings.challenge_minimap == 1) or
                            (challenge == 0 and g.sub_map_settings.minimap ~= 0)

    local size = g.sub_map_settings.size
    if use_minimap then
        size = 310
        sub_map:SetSkinName("bg")
        local rect = sub_map:GetMargin()
        sub_map:SetMargin(rect.left - rect.left, rect.top - rect.top + 70,
            rect.right == 0 and rect.right + 35 or rect.right, rect.bottom)
        sub_map:Resize(310, 350)
    else
        sub_map:SetLayerLevel(12)
        local rect = sub_map:GetMargin()
        sub_map:SetMargin(rect.left - rect.left, rect.top - rect.top + 50,
            rect.right == 0 and rect.right + 550 or rect.right, rect.bottom)
        if g.sub_map_settings.x ~= 0 and g.sub_map_settings.y ~= 0 then
            sub_map:SetPos(g.sub_map_settings.x, g.sub_map_settings.y)
        end
    end
    sub_map:SetEventScript(ui.LBUTTONUP, "Sub_map_frame_end_drag")
    local title = sub_map:CreateOrGetControl("richtext", "title", 25, 2)
    AUTO_CAST(title)
    local map_real_name = GetClassByType("Map", g.map_id).Name
    title:SetText("{ol}{S12}" .. map_real_name)
    if challenge == 0 and g.sub_map_settings.challenge_only == 1 then
        g.sub_map_settings.visible = 0
    end
    local display = sub_map:CreateOrGetControl("picture", "display", 5, 3, 15, 15)
    AUTO_CAST(display)
    display:SetEnableStretch(1)
    display:EnableHitTest(1)
    display:SetEventScript(ui.LBUTTONUP, "Sub_map_frame_toggle")
    display:SetTextTooltip("{ol}Display / hide")
    display:ShowWindow(1)
    local gbox_visible = 1
    if not use_minimap then
        if g.sub_map_settings.visible == 1 then
            display:SetImage("btn_minus")
            sub_map:Resize(size + 10, size + 40)
            sub_map:SetSkinName(g.sub_map_settings.skin_name)
            gbox_visible = 1
        else
            display:SetImage("btn_plus")
            sub_map:Resize(size + 10, 40)
            sub_map:SetSkinName("None")
            gbox_visible = 0
        end
    else
        -- display:SetImage("btn_minus") -- ミニマップモードではボタン画像はどうするか要検討
        display:ShowWindow(0)
        gbox_visible = 1
    end
    local gbox = sub_map:CreateOrGetControl("picture", "gbox", size + 10, size + 10, ui.LEFT, ui.BOTTOM, 0, 30, 0, 0)
    AUTO_CAST(gbox)
    gbox:ShowWindow(gbox_visible) -- ★ここで制御
    if not use_minimap then
        gbox:SetEventScript(ui.MOUSEON, "Sub_map_frame_layer_change")
        gbox:SetEventScriptArgString(ui.MOUSEON, "mouse_on")
        gbox:SetEventScript(ui.MOUSEOFF, "Sub_map_frame_layer_change")
        gbox:SetEventScriptArgString(ui.MOUSEOFF, "mouse_off")
    end
    gbox:SetEventScript(ui.LBUTTONDOWN, "Sub_map_frame_map_link")
    gbox:SetEventScript(ui.RBUTTONDOWN, "Sub_map_mini_map")
    gbox:SetTextTooltip(g.lang == "Japanese" and
                            "{ol}LCTRL+右クリック: ミニマップモード 切替{nl}LCTRL+左クリック: マップリンク" or
                            "{ol}LCTRL+Right click: Minimap Mode Toggle{nl}LCTRL+Left click: Map Link")
    local map_pic = gbox:CreateOrGetControl("picture", "map_pic", size, size, ui.LEFT, ui.TOP, 0, 0, 0, 0)
    AUTO_CAST(map_pic)
    map_pic:SetEnableStretch(1)
    map_pic:EnableHitTest(0)
    if g.sub_map_settings.loc_name == 1 then
        local name_group = map_pic:CreateOrGetControl("picture", "name_group", ui.CENTER_HORZ, ui.CENTER_VERT,
            map_pic:GetWidth(), map_pic:GetHeight())
        MAKE_MAP_AREA_INFO(name_group, GetClassByType("Map", g.map_id).ClassName, "{s12}", map_pic:GetWidth(),
            map_pic:GetHeight(), -100, -30)
        AUTO_CAST(name_group)
        name_group:SetSkinName("None")
    end
    local icon_size = use_minimap and g.sub_map_settings.size * 0.08 or size * 0.08
    sub_map:SetUserValue("ICON_SIZE", icon_size)
    local my = gbox:CreateOrGetControl("picture", "my", icon_size * 2, icon_size * 2, ui.LEFT, ui.TOP, 0, 0, 0, 0)
    AUTO_CAST(my)
    my:ShowWindow(0)
    my:SetImage("minimap_leader")
    my:SetEnableStretch(1)
    map_pic:SetImage(g.map_name)
    Sub_map_char_update(sub_map, my, map_pic)
    if challenge == 0 then
        Sub_map_set_warp_point(sub_map, gbox, map_pic, g.map_name, icon_size, map_real_name)
        Sub_map_mapicon_update(sub_map, map_pic)
    end
    if challenge == 0 and g.sub_map_settings.challenge_only == 1 then
        sub_map:ShowWindow(0)
    else
        sub_map:ShowWindow(1)
    end
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    local sub_map_timer = _nexus_addons_p:CreateOrGetControl("timer", "sub_map_timer", 0, 0)
    AUTO_CAST(sub_map_timer)
    sub_map_timer:SetUpdateScript("Sub_map_timer_update")
    sub_map_timer:Start(0.5)
end

--[[function Sub_map_frame_init()
    local sub_map = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "sub_map", 0, 0, 0, 0)
    AUTO_CAST(sub_map)
    sub_map:ShowWindow(0)
    local challenge = g.sub_map_challenge
    sub_map:SetUserValue("CHALLENGE", challenge)
    sub_map:RemoveAllChild()
    sub_map:EnableMove(g.sub_map_settings.move)
    sub_map:EnableHittestFrame(1)
    sub_map:SetTitleBarSkin("None")
    sub_map:SetGravity(ui.RIGHT, ui.TOP)
    sub_map:SetMargin(0, 0, 0, 0)
    local use_minimap = (challenge == 1 and g.sub_map_settings.challenge_minimap == 1) or
                            (challenge == 0 and g.sub_map_settings.minimap ~= 0)
    if use_minimap then
        sub_map:SetSkinName("bg")
        local rect = sub_map:GetMargin()
        sub_map:SetMargin(rect.left - rect.left, rect.top - rect.top + 70,
            rect.right == 0 and rect.right + 35 or rect.right, rect.bottom)
        sub_map:Resize(310, 350)
    else
        sub_map:SetSkinName(g.sub_map_settings.skin_name)
        sub_map:SetLayerLevel(12)
        local rect = sub_map:GetMargin()
        sub_map:SetMargin(rect.left - rect.left, rect.top - rect.top + 50,
            rect.right == 0 and rect.right + 550 or rect.right, rect.bottom)
        if g.sub_map_settings.x ~= 0 and g.sub_map_settings.y ~= 0 then
            sub_map:SetPos(g.sub_map_settings.x, g.sub_map_settings.y)
        end
    end
    sub_map:SetEventScript(ui.LBUTTONUP, "Sub_map_frame_end_drag")
    local title = sub_map:CreateOrGetControl("richtext", "title", 25, 2)
    AUTO_CAST(title)
    local map_real_name = GetClassByType("Map", g.map_id).Name
    title:SetText("{ol}{S12}" .. map_real_name)
    if challenge == 0 and g.sub_map_settings.challenge_only == 1 then
        g.sub_map_settings.visible = 0
    else
        g.sub_map_settings.visible = 1
    end
    local display = sub_map:CreateOrGetControl("picture", "display", 5, 3, 15, 15)
    AUTO_CAST(display)
    display:SetEnableStretch(1)
    display:EnableHitTest(1)
    display:SetEventScript(ui.LBUTTONUP, "Sub_map_frame_toggle")
    display:SetTextTooltip("{ol}Display / hide")
    display:ShowWindow(1)
    if g.sub_map_settings.visible == 1 then
        display:SetImage("btn_minus")
    else
        display:SetImage("btn_plus")
    end
    local size = g.sub_map_settings.size
    local gbox_visible = 1
    if not use_minimap then
        if g.sub_map_settings.visible == 1 then
            sub_map:Resize(size + 10, size + 40)
            sub_map:SetSkinName(g.sub_map_settings.skin_name)
            gbox_visible = 1
        else
            sub_map:Resize(size + 10, 40)
            sub_map:SetSkinName("None")
            gbox_visible = 0
        end
    else
        size = 310
        gbox_visible = 1
    end
    local gbox = sub_map:CreateOrGetControl("picture", "gbox", size + 10, size + 10, ui.LEFT, ui.BOTTOM, 0, 30, 0, 0)
    AUTO_CAST(gbox)
    gbox:ShowWindow(gbox_visible)
    if not use_minimap then
        gbox:SetEventScript(ui.MOUSEON, "Sub_map_frame_layer_change")
        gbox:SetEventScriptArgString(ui.MOUSEON, "mouse_on")
        gbox:SetEventScript(ui.MOUSEOFF, "Sub_map_frame_layer_change")
        gbox:SetEventScriptArgString(ui.MOUSEOFF, "mouse_off")
    end
    gbox:SetEventScript(ui.LBUTTONDOWN, "Sub_map_frame_map_link")
    gbox:SetEventScript(ui.RBUTTONDOWN, "Sub_map_mini_map")
    gbox:SetTextTooltip(g.lang == "Japanese" and
                            "{ol}LCTRL+右クリック: ミニマップモード 切替{nl}LCTRL+左クリック: マップリンク" or
                            "{ol}LCTRL+Right click: Minimap Mode Toggle{nl}LCTRL+Left click: Map Link")
    local map_pic = gbox:CreateOrGetControl("picture", "map_pic", size, size, ui.LEFT, ui.TOP, 0, 0, 0, 0)
    AUTO_CAST(map_pic)
    map_pic:SetEnableStretch(1)
    map_pic:EnableHitTest(0)
    if g.sub_map_settings.loc_name == 1 then
        local name_group = map_pic:CreateOrGetControl("picture", "name_group", ui.CENTER_HORZ, ui.CENTER_VERT,
            map_pic:GetWidth(), map_pic:GetHeight())
        MAKE_MAP_AREA_INFO(name_group, GetClassByType("Map", g.map_id).ClassName, "{s12}", map_pic:GetWidth(),
            map_pic:GetHeight(), -100, -30)
        AUTO_CAST(name_group)
        name_group:SetSkinName("None")
    end
    local icon_size = use_minimap and g.sub_map_settings.size * 0.08 or size * 0.08
    sub_map:SetUserValue("ICON_SIZE", icon_size)
    local my = gbox:CreateOrGetControl("picture", "my", icon_size * 2, icon_size * 2, ui.LEFT, ui.TOP, 0, 0, 0, 0)
    AUTO_CAST(my)
    my:ShowWindow(0)
    my:SetImage("minimap_leader")
    my:SetEnableStretch(1)
    map_pic:SetImage(g.map_name)
    Sub_map_char_update(sub_map, my, map_pic)
    if challenge == 0 then
        Sub_map_set_warp_point(sub_map, gbox, map_pic, g.map_name, icon_size, map_real_name)
        Sub_map_mapicon_update(sub_map, map_pic)
    end
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    local sub_map_timer = _nexus_addons_p:CreateOrGetControl("timer", "sub_map_timer", 0, 0)
    AUTO_CAST(sub_map_timer)
    sub_map_timer:SetUpdateScript("Sub_map_timer_update")
    sub_map_timer:Start(0.5)
end]]

function Sub_map_frame_end_drag(sub_map)
    g.sub_map_settings.x = sub_map:GetX()
    g.sub_map_settings.y = sub_map:GetY()
    Sub_map_save_settings()
end

function Sub_map_frame_toggle(frame, ctrl)
    if g.sub_map_settings.visible == 1 then
        g.sub_map_settings.visible = 0
    else
        g.sub_map_settings.visible = 1
    end
    Sub_map_save_settings()
    Sub_map_frame_init()
end

function Sub_map_frame_map_link(sub_map, gbox)
    if keyboard.IsKeyPressed("LCTRL") ~= 1 then
        return
    end
    local x, y = GET_LOCAL_MOUSE_POS(gbox)
    local map_prop = geMapTable.GetMapProp(g.map_name)
    local world_pos = map_prop:MinimapPosToWorldPos(x, y, gbox:GetWidth(), gbox:GetHeight())
    LINK_MAP_POS(g.map_name, world_pos.x, world_pos.y)
end

function Sub_map_mini_map(sub_map, gbox)
    if keyboard.IsKeyPressed("LCTRL") ~= 1 then
        return
    end
    if g.sub_map_settings.minimap == 0 then
        g.sub_map_settings.minimap = 1
    else
        g.sub_map_settings.minimap = 0
    end
    Sub_map_save_settings()
    ui.DestroyFrame(addon_name_lower .. "sub_map")
    ReserveScript("Sub_map_frame_init()", 0.1)
end

function Sub_map_frame_layer_change(sub_map, gbox, str)
    if str == "mouse_on" then
        sub_map:SetLayerLevel(999)
    elseif str == "mouse_off" then
        sub_map:SetLayerLevel(12)
    end
end

function Sub_map_char_update(sub_map, my, map_pic)
    local my_handle = session.GetMyHandle()
    local pos = info.GetPositionInMap(my_handle, map_pic:GetWidth(), map_pic:GetHeight())
    my:SetOffset(pos.x - my:GetWidth() / 2, pos.y - my:GetHeight() / 2)
    local map_prop = session.GetCurrentMapProp()
    local angle = info.GetAngle(my_handle) - map_prop.RotateAngle
    my:SetAngle(angle)
    my:ShowWindow(1)
    map_pic:Invalidate()
end

function Sub_map_set_warp_point(sub_map, gbox, map_pic, map_name, icon_size, map_real_name)
    local map_prop = geMapTable.GetMapProp(map_name)
    local mongens = map_prop.mongens
    local count = mongens:Count()
    for i = 0, count - 1 do
        local mon_prop = mongens:Element(i)
        local icon_name = mon_prop:GetMinimapIcon()
        if icon_name == "minimap_portal" or icon_name == "minimap_erosion" then
            local gen_list = mon_prop.GenList
            local gen_count = gen_list:Count()
            for j = 0, gen_count - 1 do
                local dialog = mon_prop:GetDialog()
                local warp_cls = GetClass("Warp", mon_prop:GetDialog())
                if not warp_cls then
                    for match in dialog:gmatch("[a-zA-Z]+_(.*)") do
                        warp_cls = GetClass("Warp", match)
                    end
                end
                if warp_cls then
                    local pos = gen_list:Element(j)
                    local map_pos = map_prop:WorldPosToMinimapPos(pos.x, pos.z, map_pic:GetWidth(), map_pic:GetHeight())
                    local icon = gbox:CreateOrGetControl("picture", "icon_" .. i, icon_size, icon_size, ui.LEFT, ui.TOP,
                        0, 0, 0, 0)
                    AUTO_CAST(icon)
                    icon:SetTextTooltip("{ol}{s10}" .. map_real_name)
                    icon:SetImage(mon_prop:GetMinimapIcon())
                    icon:SetOffset(map_pos.x - icon:GetWidth() / 2, map_pos.y - icon:GetHeight() / 2)
                    icon:SetEnableStretch(1)
                end
            end
        end
    end
    gbox:Invalidate()
end

function Sub_map_timer_update(_nexus_addons_p, sub_map_timer)
    local sub_map = ui.GetFrame(addon_name_lower .. "sub_map")
    AUTO_CAST(sub_map)
    local challenge = sub_map:GetUserIValue("CHALLENGE")
    local use_minimap = (challenge == 1 and g.sub_map_settings.challenge_minimap == 1) or
                            (challenge == 0 and g.sub_map_settings.minimap == 1)
    if use_minimap then
        Sub_map_time_update_(sub_map, sub_map_timer)
        if ui.GetFrame("buffseller_target"):IsVisible() == 1 then
            sub_map:SetLayerLevel(79)
        elseif sub_map:GetLayerLevel() ~= 94 then
            sub_map:SetLayerLevel(94)
        end
    end
    if MAP_USE_FOG(g.map_name) ~= 0 then
        Sub_map_draw_fog(sub_map)
    end
    local challenge = sub_map:GetUserIValue("CHALLENGE")
    if challenge == 1 then
        Sub_map_callenge_pcicon_update(sub_map)
    end
    Sub_map_update_remove_member(sub_map)
end

function Sub_map_time_update_(sub_map, sub_map_timer)
    local server_time = geTime.GetServerSystemTime()
    local hour = server_time.wHour
    local min = server_time.wMinute
    local ampm = "AM"
    local display_hour = hour
    if hour == 0 then
        display_hour = 12
        ampm = "AM"
    elseif hour == 12 then
        display_hour = 12
        ampm = "PM"
    elseif hour > 12 then
        display_hour = hour - 12
        ampm = "PM"
    end
    local display_min = string.format("%02d", min)
    local clock_text = string.format("{ol}{s18}%s %d:%s", ampm, display_hour, display_min)
    local clock = GET_CHILD(sub_map, "clock")
    if not clock then
        clock = sub_map:CreateOrGetControl("richtext", "clock", 0, 0)
        AUTO_CAST(clock)
    end
    clock:SetGravity(ui.RIGHT, ui.BOTTOM)
    clock:SetMargin(0, 0, 10, 5)
    clock:SetText(clock_text)
    local colony_battle_info = ui.GetFrame("colony_battle_info")
    if colony_battle_info:IsVisible() == 1 and g.sub_map_settings.minimap == 1 then
        local colony_clock = GET_CHILD(sub_map, "colony_clock")
        if not colony_clock then
            colony_clock = sub_map:CreateOrGetControl("richtext", "colony_clock", 0, 0)
            AUTO_CAST(clock)
        end
        colony_clock:SetGravity(ui.LEFT, ui.BOTTOM)
        colony_clock:SetMargin(0, 0, 0, 5)
        local colony_end_time = session.colonywar.GetEndTime()
        local remain_time = -1 * imcTime.GetDiffSecFromNow(colony_end_time.wHour, colony_end_time.wMinute, 0)
        if remain_time <= 0 then
            sub_map:RemoveChild("colony_clock")
            return
        end
        local remain_min = math.floor(remain_time / 60)
        local remain_sec = remain_time % 60
        local remain_time_str = string.format("{ol}{s18}" .. ClMsg("RemainTime") .. " %d:%02d", remain_min, remain_sec)
        colony_clock:SetText(remain_time_str)
    end
end

function Sub_map_draw_fog(sub_map)
    local map_pic = GET_CHILD_RECURSIVELY(sub_map, "map_pic")
    AUTO_CAST(map_pic)
    HIDE_CHILD_BYNAME(map_pic, "sub_map_fog_")
    local map_frame = ui.GetFrame("map")
    local map = GET_CHILD(map_frame, "map")
    AUTO_CAST(map)
    local map_zoom = math.abs(tonumber(map_pic:GetWidth()) / tonumber(map:GetWidth()))
    local list = session.GetMapFogList(g.map_name)
    local cnt = list:Count()
    for i = 0, cnt - 1 do
        local tile = list:PtrAt(i)
        if tile.revealed == 0 then
            local name = string.format("sub_map_fog_%d", i)
            local tile_X = (tile.x * map_zoom)
            local tile_Y = (tile.y * map_zoom)
            local tile_width = math.ceil(tile.w * map_zoom)
            local tile_height = math.ceil(tile.h * map_zoom)
            local pic = map_pic:CreateOrGetControl("picture", name, tile_X, tile_Y, tile_width, tile_height)
            AUTO_CAST(pic)
            pic:SetImage("fullred")
            pic:SetEnableStretch(1)
            pic:SetAlpha(40)
            pic:EnableHitTest(0)
            pic:ShowWindow(1)
        end
    end
    sub_map:Invalidate()
end

function Sub_map_callenge_pcicon_update(sub_map)
    local gbox = GET_CHILD(sub_map, "gbox")
    local names = {}
    for i = 0, gbox:GetChildCount() - 1 do
        local child = gbox:GetChildByIndex(i)
        if child and child:GetName() ~= "map_pic" and child:GetName() ~= "my" then
            local aid = tonumber(child:GetName())
            if aid then
                gbox:RemoveChild(child:GetName())
            end
            names[child:GetName()] = true
        end
    end
    local map_pic = GET_CHILD(gbox, "map_pic")
    local mapprop = session.GetCurrentMapProp()
    local party_list = session.party.GetPartyMemberList(PARTY_NORMAL)
    local party_count = party_list:Count()
    local my_info = session.party.GetMyPartyObj(PARTY_NORMAL)
    local my_handle = session.GetMyHandle()
    local icon_size = sub_map:GetUserIValue("ICON_SIZE")
    local selected_objects, selected_objects_count = SelectObject(GetMyPCObject(), 5000, "ALL")
    local icon_img_160063 = GetClassByType("Item", 870004).Icon
    local icon_img_160055 = GetClassByType("Item", 664039).Icon
    for i = 1, selected_objects_count do
        local handle = GetHandle(selected_objects[i])
        if not g.sub_map_handles[tostring(handle)] then
            local actor = world.GetActor(handle)
            if handle and actor then
                local clsid = actor:GetType()
                local mon_cls = GetClassByType("Monster", clsid)
                if clsid == 160063 or clsid == 160055 then
                    local icon_name = "mon_" .. handle
                    names[icon_name] = false
                    local world_pos = actor:GetPos()
                    local pos = mapprop:WorldPosToMinimapPos(world_pos, map_pic:GetWidth(), map_pic:GetHeight())
                    local x = (pos.x - icon_size / 4)
                    local y = (pos.y - icon_size / 4)
                    local icon = gbox:CreateOrGetControl("picture", icon_name, icon_size * 0.5, icon_size * 0.5,
                        ui.LEFT, ui.TOP, 0, 0, 0, 0)
                    AUTO_CAST(icon)
                    icon:SetPos(x, y)
                    if clsid == 160063 then
                        icon:SetImage(icon_img_160063)
                    elseif clsid == 160055 then
                        icon:SetImage(icon_img_160055)
                    end
                    icon:SetEnableStretch(1)
                    icon:ShowWindow(1)
                end
                if my_handle ~= handle and info.IsPC(handle) == 1 then
                    for j = 0, party_count - 1 do
                        local pc_info = party_list:Element(j)
                        local name = pc_info:GetName()
                        local apc = actor:GetPCApc()
                        if apc then
                            local actor_name = apc:GetFamilyName()
                            if my_info ~= pc_info and name == actor_name then
                                names[name] = false -- 削除対象から除外
                                local inst_info = pc_info:GetInst()
                                local world_pos = actor:GetPos()
                                local hp = inst_info.hp
                                local pc_icon = GET_CHILD(gbox, name)
                                if not pc_icon then
                                    pc_icon = gbox:CreateOrGetControl("picture", name, 0, 0, icon_size * 1.25,
                                        icon_size * 1.25)
                                end
                                AUTO_CAST(pc_icon)
                                pc_icon:SetTextTooltip("{ol}{s10}" .. name)
                                pc_icon:SetEnableStretch(1)
                                local pos = mapprop:WorldPosToMinimapPos(world_pos, map_pic:GetWidth(),
                                    map_pic:GetHeight())
                                local x = (pos.x - icon_size * 1.25 / 2)
                                local y = (pos.y - icon_size * 1.25 / 2)
                                pc_icon:SetPos(x, y)
                                pc_icon:ShowWindow(1)
                                local image_name = "Archer_party"
                                if hp <= 0 then
                                    image_name = "die_party"
                                end
                                pc_icon:SetImage(image_name)
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    for check_name, bool in pairs(names) do
        if bool == true and not string.find(check_name, "_MONPOS_") and not string.find(check_name, "SCR") then
            local icon = GET_CHILD(gbox, check_name)
            if icon then
                gbox:RemoveChild(check_name)
            end
        end
    end
end

function Sub_map_update_remove_member(sub_map)
    local gbox = GET_CHILD(sub_map, "gbox")
    local icons = {}
    for i = 0, gbox:GetChildCount() - 1 do
        local child = gbox:GetChildByIndex(i)
        if child then
            local aid = tonumber(child:GetName())
            if aid then
                icons[aid] = true
            end
        end
    end
    local function process_member_list(party_type)
        local list = session.party.GetPartyMemberList(party_type)
        local my_handle = session.GetMyHandle()
        local my_info = session.party.GetMyPartyObj(party_type)
        if my_info then
            for i = 0, list:Count() - 1 do
                local pc_info = list:Element(i)
                local aid = tonumber(pc_info:GetAID())
                local handle = pc_info:GetHandle()
                if handle ~= my_handle and pc_info:GetMapID() == my_info:GetMapID() and pc_info:GetChannel() ==
                    my_info:GetChannel() then
                    icons[aid] = false
                end
            end
        end
    end
    process_member_list(PARTY_NORMAL)
    process_member_list(PARTY_GUILD)
    for aid, remove in pairs(icons) do
        if remove == true then
            gbox:RemoveChild(tostring(aid))
        end
    end
end

function Sub_map_MAP_CHARACTER_UPDATE()
    local sub_map = ui.GetFrame(addon_name_lower .. "sub_map")
    if not sub_map then
        return
    end
    AUTO_CAST(sub_map)
    local my_handle = session.GetMyHandle()
    local map_pic = GET_CHILD_RECURSIVELY(sub_map, "map_pic")
    AUTO_CAST(map_pic)
    local pos = info.GetPositionInMap(my_handle, map_pic:GetWidth(), map_pic:GetHeight())
    local my = GET_CHILD_RECURSIVELY(sub_map, "my")
    AUTO_CAST(my)
    my:ShowWindow(0)
    my:SetOffset(pos.x - my:GetWidth() / 2, pos.y - my:GetHeight() / 2)
    local mapprop = session.GetCurrentMapProp()
    local angle = info.GetAngle(my_handle) - mapprop.RotateAngle
    my:SetAngle(angle)
    my:ShowWindow(1)
    map_pic:Invalidate()
    local challenge = sub_map:GetUserIValue("CHALLENGE")
    if challenge == 0 then
        Sub_map_mapicon_update(sub_map, map_pic)
    end
end

function Sub_map_mapicon_update(sub_map, map_pic)
    local now = imcTime.GetAppTimeMS()
    if g.sub_map_last_update_time then
        if now - g.sub_map_last_update_time < 1000 then
            return
        end
    end
    g.sub_map_last_update_time = now
    local map_tbl = Sub_map_get_mapinfo(sub_map, map_pic)
    local gbox = GET_CHILD(sub_map, "gbox")
    local function split(str, delim)
        local return_data = {}
        for match in string.gmatch(str, "[^" .. delim .. "]+") do
            table.insert(return_data, match)
        end
        return return_data
    end
    local icon_size = sub_map:GetUserIValue("ICON_SIZE")
    for i, data in ipairs(map_tbl) do
        if string.find(data.class_type, "treasure_box") then
            local item_split = split(data.argstr2, ":")
            local item_name = GetClass("Item", item_split[2]).Name
            local icon = GET_CHILD(gbox, "icon_" .. i)
            if not icon then
                icon = gbox:CreateOrGetControl("picture", "icon_" .. i, 0, 0, icon_size, icon_size)
                AUTO_CAST(icon)
                icon:SetOffset(data.map_pos.x - icon:GetWidth() / 2, data.map_pos.y - icon:GetHeight() / 2)
                icon:SetEnableStretch(1)
            end
            icon:SetTextTooltip("{ol}{s10}" .. data.argstr1 .. "{nl}" .. item_name)
            if data.state then
                icon:SetImage("icon_item_box")
            else
                icon:SetText("{ol}{s10}" .. data.argstr1)
                icon:SetImage("compen_btn")
            end
        end
        if string.find(data.class_type, "statue_vakarine") or string.find(data.class_type, "klaipeda_square_statue") or
            string.find(data.class_type, "npc_orsha_goddess") or string.find(data.class_type, "statue_zemina") then
            local icon = GET_CHILD(gbox, "icon_" .. i)
            if not icon then
                icon = gbox:CreateOrGetControl("picture", "icon_" .. i, 0, 0, icon_size, icon_size)
                AUTO_CAST(icon)
                icon:SetOffset(data.map_pos.x - icon:GetWidth() / 2, data.map_pos.y - icon:GetHeight() / 2)
                icon:SetEnableStretch(1)
                icon:SetTextTooltip("{ol}{s10}" .. data.name)
                icon:SetImage(data.icon_name)
            end
            if data.state then
                icon:SetColorTone("FFFFFFFF")
            else
                icon:SetColorTone("FF555555")
            end
        end
    end
    gbox:Invalidate()
end

function Sub_map_get_mapinfo(sub_map, map_pic)
    if not g.map_name or g.map_name == "" or g.map_name == "None" then
        return
    end
    local property = geMapTable.GetMapProp(g.map_name)
    local class_list, class_count = GetClassList("GenType_" .. g.map_name)
    local mongens = property.mongens
    local map_tbl = {}
    local count = mongens:Count()
    for i = 0, count - 1 do
        local mon_prop = mongens:Element(i)
        local ies_data = GetClassByIndexFromList(class_list, i)
        local class_type = ies_data.ClassType
        local state = GetNPCState(g.map_name, ies_data.GenType)
        if not state then
            state = false
        end
        local gen_list = mon_prop.GenList
        local map_pos
        if gen_list:Count() > 0 then
            map_pos = property:WorldPosToMinimapPos(gen_list:Element(0), map_pic:GetWidth(), map_pic:GetHeight())
        end
        local icon_name = mon_prop:GetMinimapIcon()
        if string.find(class_type, "treasure_box") then
            if ies_data.ArgStr1 ~= "None" then
                local data = {
                    class_type = class_type,
                    state = state,
                    map_pos = map_pos,
                    icon_name = icon_name,
                    argstr1 = ies_data.ArgStr1,
                    argstr2 = ies_data.ArgStr2,
                    argstr3 = ies_data.ArgStr3,
                    name = ies_data.Name
                }
                table.insert(map_tbl, data)
            end
        elseif string.find(class_type, "statue_zemina") or string.find(class_type, "statue_vakarine") or
            string.find(class_type, "klaipeda_square_statue") or string.find(class_type, "npc_orsha_goddess") then
            local data = {
                class_type = class_type,
                state = state,
                map_pos = map_pos,
                icon_name = icon_name,
                argstr1 = ies_data.ArgStr1,
                argstr2 = ies_data.ArgStr2,
                argstr3 = ies_data.ArgStr3,
                name = ies_data.Name
            }
            table.insert(map_tbl, data)
        end
    end
    return map_tbl
end

function Sub_map_MAP_MON_MINIMAP(frame, msg, str, num, info)
    local sub_map = ui.GetFrame(addon_name_lower .. "sub_map")
    if not sub_map then
        return
    end
    AUTO_CAST(sub_map)
    local gbox = GET_CHILD(sub_map, "gbox")
    local handle = info.handle
    g.sub_map_handles = g.sub_map_handles or {}
    if g.sub_map_handles[tostring(handle)] then
        return
    end
    local mon_cls = GetClassByType("Monster", info.type)
    if not mon_cls then
        return
    end
    local mon_rank = TryGetProp(mon_cls, "MonRank", "None")
    local is_boss = (mon_rank == "Boss")
    local is_mob_display = (g.sub_map_settings.mob_display == 1)
    if not is_boss and not is_mob_display then
        return
    end
    local base_size = sub_map:GetUserIValue("ICON_SIZE")
    local icon_w, icon_h
    if is_boss then
        if is_mob_display then
            icon_w, icon_h = base_size * 1.5, base_size * 1.5
        else
            icon_w, icon_h = base_size, base_size
        end
    else
        icon_w, icon_h = base_size / 3, base_size / 3
    end
    g.sub_map_handles[tostring(handle)] = true
    local mon_pic = gbox:CreateOrGetControl("picture", "_MONPOS_" .. handle, 0, 0, icon_w, icon_h)
    AUTO_CAST(mon_pic)
    mon_pic:SetUserValue("HANDLE", handle)
    if mon_cls.MinimapIcon ~= "None" then
        mon_pic:SetImage(mon_cls.MinimapIcon)
    else
        mon_pic:SetImage("fullwhite")
        mon_pic:SetColorTone("FFFF4500")
    end
    mon_pic:SetEnableStretch(1)
    local map_pic = GET_CHILD_RECURSIVELY(sub_map, "map_pic")
    AUTO_CAST(map_pic)
    if map_pic then
        local map_prop = session.GetCurrentMapProp()
        local pos = map_prop:WorldPosToMinimapPos(info.x, info.z, map_pic:GetWidth(), map_pic:GetHeight())
        mon_pic:SetOffset(pos.x - icon_w / 2, pos.y - icon_h / 2)
    end
    mon_pic:ShowWindow(1)
    if not mon_pic:HaveUpdateScript("Sub_map_monpic_auto_update") then
        mon_pic:RunUpdateScript("Sub_map_monpic_auto_update", 0.5)
    end
end

function Sub_map_monpic_auto_update(mon_pic)
    local sub_map = mon_pic:GetTopParentFrame()
    local gbox = GET_CHILD(sub_map, "gbox")
    local handle = mon_pic:GetUserIValue("HANDLE")
    local actor = world.GetActor(handle)
    if actor then
        local map_prop = session.GetCurrentMapProp()
        local map_pic = GET_CHILD_RECURSIVELY(sub_map, "map_pic")
        AUTO_CAST(map_pic)
        local actor_pos = actor:GetPos()
        local mon_cls = GetClassByType("Monster", actor:GetType())
        if mon_cls then
            local pos = map_prop:WorldPosToMinimapPos(actor_pos, map_pic:GetWidth(), map_pic:GetHeight())
            local x = pos.x - mon_pic:GetWidth() / 2
            local y = pos.y - mon_pic:GetHeight() / 2
            mon_pic:SetOffset(x, y)
        end
    end
    return 1
end

function Sub_map_ON_MON_MINIMAP_END(frame, msg, str, handle)
    local sub_map = ui.GetFrame(addon_name_lower .. "sub_map")
    if not sub_map then
        return
    end
    AUTO_CAST(sub_map)
    local gbox = GET_CHILD(sub_map, "gbox")
    local mon_pic = GET_CHILD(gbox, "_MONPOS_" .. handle)
    if mon_pic then
        if g.sub_map_handles then
            g.sub_map_handles[tostring(handle)] = nil
        end
        gbox:RemoveChild("_MONPOS_" .. handle)
        gbox:Invalidate()
    end
end

function Sub_map_MAP_UPDATE_PARTY_INST(frame, msg, str, party_type)
    local sub_map = ui.GetFrame(addon_name_lower .. "sub_map")
    if not sub_map then
        return
    end
    AUTO_CAST(sub_map)
    local gbox = GET_CHILD(sub_map, "gbox")
    local map_prop = session.GetCurrentMapProp()
    local my_info = session.party.GetMyPartyObj(party_type)
    local list = session.party.GetPartyMemberList(party_type)
    local count = list:Count()
    for i = 0, count - 1 do
        local pc_info = list:Element(i)
        if my_info ~= pc_info then
            local aid = pc_info:GetAID()
            local pc_icon = GET_CHILD(gbox, aid)
            if pc_icon then
                local inst_info = pc_info:GetInst()
                Sub_map_SET_MINIMAP_ICON(pc_icon, inst_info.hp, aid)
                Sub_map_SET_MAPPOS(sub_map, pc_icon, inst_info, map_prop)
            end
        end
    end
end

function Sub_map_SET_MINIMAP_ICON(pc_icon, hp, aid)
    local image_name = "die_party"
    if hp > 0 then
        if session.party.GetPartyMemberInfoByAID(PARTY_NORMAL, aid) then
            image_name = "Archer_party"
        elseif session.party.GetPartyMemberInfoByAID(PARTY_GUILD, aid) then
            image_name = "Wizard_party"
        end
    end
    pc_icon:SetImage(image_name)
end

function Sub_map_SET_MAPPOS(sub_map, pc_icon, inst_info, map_prop, info)
    local world_pos = inst_info:GetPos()
    local map_pic = GET_CHILD_RECURSIVELY(sub_map, "map_pic")
    local pos
    if info then
        pos = map_prop:WorldPosToMinimapPos(info.x, info.z, map_pic:GetWidth(), map_pic:GetHeight())
    else
        pos = map_prop:WorldPosToMinimapPos(world_pos, map_pic:GetWidth(), map_pic:GetHeight())
    end
    local icon_size = sub_map:GetUserIValue("ICON_SIZE")
    local x = (pos.x - icon_size / 2)
    local y = (pos.y - icon_size / 2)
    pc_icon:SetPos(x, y)
end

function Sub_map_update_party_or_guild(frame, msg, arg, num, info)
    local sub_map = ui.GetFrame(addon_name_lower .. "sub_map")
    if not sub_map then
        return
    end
    AUTO_CAST(sub_map)
    local party_type = 0
    if msg == "GUILD_INFO_UPDATE" then
        party_type = 1
    end
    local list = session.party.GetPartyMemberList(party_type)
    local count = list:Count()
    if count == 1 then
        return
    end
    local my_info = session.party.GetMyPartyObj(party_type)
    if not my_info then
        return
    end
    local map_prop = session.GetCurrentMapProp()
    for i = 0, count - 1 do
        local pc_info = list:Element(i)
        if my_info ~= pc_info and my_info:GetMapID() == pc_info:GetMapID() and my_info:GetChannel() ==
            pc_info:GetChannel() then
            Sub_map_CREATE_PICTURE(sub_map, pc_info, party_type, map_prop, info)
        end
    end
end

function Sub_map_CREATE_PICTURE(sub_map, pc_info, party_type, mapprop, info)
    local aid = pc_info:GetAID()
    local gbox = GET_CHILD(sub_map, "gbox")
    local pc_icon = GET_CHILD(gbox, aid)
    if not pc_icon then
        local icon_size = sub_map:GetUserIValue("ICON_SIZE")
        pc_icon = gbox:CreateOrGetControl("picture", aid, 0, 0, icon_size, icon_size)
        AUTO_CAST(pc_icon)
    end
    pc_icon:SetEnableStretch(1)
    pc_icon:SetTooltipType("partymap")
    local name = ""
    if type(_G["NATIVE_LANG_ON_INIT"]) == "function" then
        local ntr = _G["ADDONS"]["norisan"]["NATIVE_LANG"]
        name = ntr.names[pc_info:GetName()] or pc_info:GetName() -- {#FF0000}★
        name = string.gsub(name, "{#FF0000}★", "")
        name = string.gsub(name, "{/}", "")
    end
    local inst_info = pc_info:GetInst()
    if pc_info:GetName() ~= name then
        local tool_msg = "{ol}" .. name .. "(" .. ClMsg("Level") .. pc_info:GetLevel() .. "){nl}" .. "HP : (" ..
                             inst_info.hp .. "/" .. inst_info.maxhp .. "){nl}" .. "SP : (" .. inst_info.sp .. "/" ..
                             inst_info.maxsp .. ")"
        pc_icon:SetTextTooltip(tool_msg)
        -- pc_icon:SetTooltipArg(pc_info:GetName(), party_type)
    else
        pc_icon:SetTooltipArg(pc_info:GetName(), party_type)
    end
    pc_icon:ShowWindow(1)
    Sub_map_SET_MINIMAP_ICON(pc_icon, inst_info.hp, aid)
    Sub_map_SET_MAPPOS(sub_map, pc_icon, inst_info, mapprop, info)
end
-- sub_map ここまで

