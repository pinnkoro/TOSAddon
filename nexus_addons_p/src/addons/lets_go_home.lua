-- lets_go_home　ここから
function Lets_go_home_save_settings()
    g.save_json(g.lets_go_home_path, g.lets_go_home_settings)
end

function Lets_go_home_load_settings()
    g.lets_go_home_path = string.format("../addons/%s/%s/lets_go_home.json", addon_name_lower, g.active_id)
    local settings = g.load_json(g.lets_go_home_path)
    if not settings then
        settings = {
            map = "",
            ch = 1,
            leticia = 0,
            x = 0,
            y = 0,
            move = 1,
            display = 1,
            short_cut = 1
        }
    end
    g.lets_go_home_settings = settings
    Lets_go_home_save_settings()
end

function lets_go_home_on_init()
    if not g.lets_go_home_settings then
        Lets_go_home_load_settings()
    end
    local old_func = g.settings.lets_go_home.old_init_func
    if _G[old_func] then
        return
    end
    if g.settings.lets_go_home.use == 0 then
        local lets_go_home = ui.GetFrame(addon_name_lower .. "lets_go_home")
        if lets_go_home then
            ui.DestroyFrame(lets_go_home:GetName())
        end
        local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
        _nexus_addons_p:SetVisible(1)
        local lets_go_home_timer = GET_CHILD(_nexus_addons_p, "lets_go_home_timer")
        if lets_go_home_timer then
            AUTO_CAST(lets_go_home_timer)
            lets_go_home_timer:Stop()
        end
        return
    end
    Lets_go_home_frame_init()
    if g.lets_go_home_warp_state == 1 then
        Lets_go_home_change_move()
    end
end

function Lets_go_home_frame_init()
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    _nexus_addons_p:SetVisible(1)
    local lets_go_home_timer = _nexus_addons_p:CreateOrGetControl("timer", "lets_go_home_timer", 0, 0)
    AUTO_CAST(lets_go_home_timer)
    lets_go_home_timer:SetUpdateScript("Lets_go_home_key_press")
    lets_go_home_timer:Start(0.2)
    if g.lets_go_home_settings.display == 0 then
        return
    end
    local lets_go_home = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "lets_go_home", 0, 0, 0, 0)
    AUTO_CAST(lets_go_home)
    lets_go_home:SetSkinName('None')
    lets_go_home:SetTitleBarSkin("None")
    lets_go_home:Resize(40, 30)
    lets_go_home:SetGravity(ui.RIGHT, ui.TOP)
    lets_go_home:EnableHitTest(1)
    lets_go_home:EnableHittestFrame(1)
    lets_go_home:EnableMove(g.lets_go_home_settings.move)
    local rect = lets_go_home:GetMargin()
    lets_go_home:SetMargin(rect.left - rect.left, rect.top - rect.top + 305, rect.right + 305, rect.bottom)
    if g.lets_go_home_settings.x ~= 0 and g.lets_go_home_settings.y ~= 0 then
        lets_go_home:SetPos(g.lets_go_home_settings.x, g.lets_go_home_settings.y)
    end
    local btn = lets_go_home:CreateOrGetControl('button', 'home', 0, 0, 30, 30)
    AUTO_CAST(btn)
    btn:SetGravity(ui.LEFT, ui.TOP)
    btn:SetSkinName("None")
    btn:SetText("{img btn_housing_editmode_small_resize 30 30}")
    btn:SetTextTooltip(g.lang == "Japanese" and
                           "{ol}右クリック:ホーム設定{nl}左クリック:ワープ{nl}ショートカット:BackSlash+RSHIFT" or
                           "{ol}Rightclick:Home Setting{nl}Leftclick:Warp{nl}Shortcut:BackSlash+RSHIFT")
    btn:SetEventScript(ui.RBUTTONUP, "Lets_go_home_settings")
    btn:SetEventScript(ui.LBUTTONDOWN, "Lets_go_home_warp_do")
    lets_go_home:ShowWindow(1)
    btn:SetEventScript(ui.LBUTTONUP, "Lets_go_home_frame_move_save")
    lets_go_home:RunUpdateScript("Lets_go_home_update_frame", 1.0)
end

function Lets_go_home_frame_move_save(lets_go_home)
    g.lets_go_home_settings.x = lets_go_home:GetX()
    g.lets_go_home_settings.y = lets_go_home:GetY()
    Lets_go_home_save_settings()
end

function Lets_go_home_settings_frame_close(list_frame)
    ui.DestroyFrame(list_frame:GetName())
end

function Lets_go_home_settings_frame()
    local list_frame = ui.GetFrame(addon_name_lower .. "list_frame")
    local lets_go_home_setting = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "lets_go_home_setting", 0, 0, 0,
        0)
    lets_go_home_setting:Resize(370, 250)
    lets_go_home_setting:SetPos(list_frame:GetX() + list_frame:GetWidth(), list_frame:GetY())
    lets_go_home_setting:SetSkinName("test_frame_low")
    lets_go_home_setting:EnableHittestFrame(1)
    lets_go_home_setting:EnableHitTest(1)
    lets_go_home_setting:SetLayerLevel(999)
    lets_go_home_setting:ShowWindow(1)
    local title_text = lets_go_home_setting:CreateOrGetControl('richtext', 'title_text', 20, 15, 50, 30)
    AUTO_CAST(title_text)
    title_text:SetText("{ol}Lets Go Home Config")
    local close = lets_go_home_setting:CreateOrGetControl("button", "close", 0, 0, 20, 20)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Lets_go_home_settings_frame_close")
    local gbox = lets_go_home_setting:CreateOrGetControl("groupbox", "gbox", 10, 40,
        lets_go_home_setting:GetWidth() - 20, lets_go_home_setting:GetHeight() - 50)
    AUTO_CAST(gbox)
    gbox:SetSkinName("test_frame_midle_light")
    local map_text = gbox:CreateOrGetControl('richtext', 'map_text', 10, 10, 150, 30)
    AUTO_CAST(map_text)
    map_text:SetText(g.lang == "Japanese" and "{ol}ホームタウン" or "{ol}Hometown")
    local map_drop_list = gbox:CreateOrGetControl('droplist', 'map_drop_list', 150, 10, 180, 20)
    AUTO_CAST(map_drop_list)
    map_drop_list:SetSkinName('droplist_normal')
    map_drop_list:EnableHitTest(1)
    map_drop_list:SetTextAlign("center", "center")
    local citys = {"c_Klaipe", "c_orsha", "c_fedimian"}
    local selected_index = 0
    map_drop_list:AddItem(0, g.lang == "Japanese" and "{ol}未設定" or "{ol}None", 0, "Lets_go_home_map_settings('')")
    for i, city_class_name in ipairs(citys) do
        local map_cls = GetClass("Map", city_class_name)
        if map_cls then
            local scp = string.format("Lets_go_home_map_settings('%s')", city_class_name)
            map_drop_list:AddItem(i, "{ol}" .. map_cls.Name, 0, scp)
            if g.lets_go_home_settings.map == city_class_name then
                selected_index = i
            end
        end
    end
    map_drop_list:SelectItem(selected_index)
    local ch_text = gbox:CreateOrGetControl('richtext', 'ch_text', 10, 40, 150, 30)
    AUTO_CAST(ch_text)
    ch_text:SetText(g.lang == "Japanese" and "{ol}チャンネル" or "{ol}Channel")
    local ch_drop_list = gbox:CreateOrGetControl('droplist', 'ch_drop_list', 150, 40, 180, 20)
    AUTO_CAST(ch_drop_list)
    ch_drop_list:SetSkinName('droplist_normal')
    ch_drop_list:EnableHitTest(1)
    ch_drop_list:SetTextAlign("center", "center")
    for i = 1, 10 do
        local scp = string.format("Lets_go_home_ch_settings(%d)", i)
        ch_drop_list:AddItem(i - 1, "{ol}" .. tostring(i) .. " ch", 0, scp)
        if g.lets_go_home_settings.ch == i then
            selected_index = i - 1
        end
    end
    ch_drop_list:SelectItem(selected_index)
    local btn_move = gbox:CreateOrGetControl('checkbox', "btn_move", 10, 70, 30, 30)
    AUTO_CAST(btn_move)
    btn_move:SetText(g.lang == "Japanese" and "{ol}ボタン位置固定" or "{ol}Fix button position")
    btn_move:SetTextTooltip(g.lang == "Japanese" and "{ol}チェックするとボタン固定" or
                                "{ol}Checked: the button is fixed")
    btn_move:SetEventScript(ui.LBUTTONUP, "Lets_go_home_check_toggle")
    btn_move:SetCheck(g.lets_go_home_settings.move)
    local btn = gbox:CreateOrGetControl('button', 'home', 210, 70, 80, 30)
    AUTO_CAST(btn)
    btn:SetText(g.lang == "Japanese" and "{ol}ボタン初期位置" or "{ol}Btn Init Pos")
    btn:SetEventScript(ui.LBUTTONUP, "Lets_go_home_init_pos")
    local btn_display = gbox:CreateOrGetControl('checkbox', "btn_display", 10, 100, 30, 30)
    AUTO_CAST(btn_display)
    btn_display:SetText(g.lang == "Japanese" and "{ol}ボタン表示設定" or "{ol}Button display settings")
    btn_display:SetTextTooltip(g.lang == "Japanese" and "{ol}チェックするとボタン表示" or
                                   "{ol}Checked: the button is shown")
    btn_display:SetEventScript(ui.LBUTTONUP, "Lets_go_home_check_toggle")
    btn_display:SetCheck(g.lets_go_home_settings.display)
    local short_cut = gbox:CreateOrGetControl('checkbox', "short_cut", 10, 130, 30, 30)
    AUTO_CAST(short_cut)
    short_cut:SetText(g.lang == "Japanese" and "{ol}ショートカット設定(BackSlash+RSHIFT)" or
                          "{ol}Shortcut Setting(BackSlash+RSHIFT)")
    short_cut:SetTextTooltip(g.lang == "Japanese" and "{ol}チェックするとショートカット有効化" or
                                 "{ol}Checked: enables the shortcut")
    short_cut:SetEventScript(ui.LBUTTONUP, "Lets_go_home_check_toggle")
    short_cut:SetCheck(g.lets_go_home_settings.short_cut)
    local leticia = gbox:CreateOrGetControl('checkbox', "leticia", 10, 160, 30, 30)
    AUTO_CAST(leticia)
    leticia:SetText(g.lang == "Japanese" and "{ol}レティーシア移動設定" or "{ol}Leticia Move Settings")
    leticia:SetTextTooltip(g.lang == "Japanese" and "{ol}チェックするとレティーシア移動有効化" or
                               "{ol}Checked: enables the Leticia Move")
    leticia:SetEventScript(ui.LBUTTONUP, "Lets_go_home_check_toggle")
    leticia:SetCheck(g.lets_go_home_settings.leticia)
end

function Lets_go_home_map_settings(city_class_name)
    g.lets_go_home_settings.map = city_class_name
    Lets_go_home_save_settings()
end

function Lets_go_home_ch_settings(channel)
    g.lets_go_home_settings.ch = channel
    Lets_go_home_save_settings()
end

function Lets_go_home_check_toggle(parent, ctrl)
    local ctrl_name = ctrl:GetName()
    local is_check = ctrl:IsChecked()
    if ctrl_name == "btn_move" then
        g.lets_go_home_settings.move = is_check
    elseif ctrl_name == "btn_display" then
        g.lets_go_home_settings.display = is_check
        if is_check == 0 then
            local lets_go_home = ui.GetFrame(addon_name_lower .. "lets_go_home")
            if lets_go_home then
                ui.DestroyFrame(lets_go_home:GetName())
            end
        else
            Lets_go_home_frame_init()
        end
    elseif ctrl_name == "short_cut" then
        g.lets_go_home_settings.short_cut = is_check
    elseif ctrl_name == "leticia" then
        g.lets_go_home_settings.leticia = is_check
    end
    Lets_go_home_save_settings()
end

function Lets_go_home_init_pos()
    g.lets_go_home_settings.x = 0
    g.lets_go_home_settings.y = 0
    Lets_go_home_save_settings()
    local lets_go_home = ui.GetFrame(addon_name_lower .. "lets_go_home")
    if lets_go_home then
        ui.DestroyFrame(lets_go_home:GetName())
    end
    ReserveScript("Lets_go_home_frame_init()", 0.1)
end

function Lets_go_home_settings()
    if g.get_map_type() == "City" then
        local msg = g.lang == "Japanese" and "現在のマップとチャンネルをホームにしますか？" or
                        "Do you want to home in on the current map and channel?"
        local yes_scp = string.format("Lets_go_home_settings_reg()")
        ui.MsgBox(msg, yes_scp, "None")
    else
        ui.SysMsg(g.lang == "Japanese" and "このマップは設定できません" or "This map cannot be set up")
    end
end

function Lets_go_home_settings_reg()
    local channel = session.loginInfo.GetChannel() + 1
    local map_cls = GetClass("Map", g.map_name)
    local map_clas_name = map_cls.ClassName
    local map_name = map_cls.Name
    g.lets_go_home_settings.ch = channel
    g.lets_go_home_settings.map = map_clas_name
    g.lets_go_home_settings.leticia = 0
    ui.SysMsg(g.lang == "Japanese" and "マップ名: " .. map_name .. " チャンネル: " .. channel ..
                  "を登録{nl}レティーシャへの移動を無効にしました" or "MapName: " .. map_name ..
                  " Channel: " .. channel .. "Registered{nl}Move to Leticia disabled")
    Lets_go_home_save_settings()
    local msg = g.lang == "Japanese" and "レティーシャへ移動は使用しますか？" or
                    "Do you use Move to Leticia?"
    local yes_scp = string.format("Lets_go_home_settings_reg_()")
    ui.MsgBox(msg, yes_scp, "None")
end

function Lets_go_home_settings_reg_()
    ui.SysMsg(g.lang == "Japanese" and "レティーシャへの移動を有効にしました" or
                  "Move to Leticia enabled")
    g.lets_go_home_settings.leticia = 1
    Lets_go_home_save_settings()
end

function Lets_go_home_update_frame(lets_go_home)
    local home = GET_CHILD(lets_go_home, "home")
    local cd_text = home:CreateOrGetControl('richtext', 'cd_text', 5, 10)
    AUTO_CAST(cd_text)
    local cd = GET_TOKEN_WARP_COOLDOWN()
    cd_text:SetText("{ol}{#FFFFFF}{s13}" .. cd)
    if cd >= 100 then
        cd_text:ShowWindow(1)
        return 1
    elseif cd < 100 and cd >= 10 then
        cd_text:SetOffset(9, 10)
        return 1
    elseif cd < 10 and cd >= 1 then
        cd_text:SetOffset(13, 10)
        return 1
    else
        cd_text:ShowWindow(0)
        return 0
    end
end

function Lets_go_home_warp_do()
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    g.lets_go_home_warp_state = 1
    Lets_go_home_change_move(_nexus_addons_p)
end

function Lets_go_home_key_press(_nexus_addons_p, lets_go_home_timer)
    if g.lets_go_home_settings.short_cut == 0 then
        return
    end
    if 1 == keyboard.IsKeyPressed("BACKSLASH") and 1 == keyboard.IsKeyPressed("RSHIFT") then
        g.lets_go_home_warp_state = 1
        Lets_go_home_change_move()
    end
end

function Lets_go_home_change_move()
    if ENABLE_WARP_CHECK(GetMyPCObject()) == false then
        ui.SysMsg(ScpArgMsg("WarpBanBountyHunt"))
        g.lets_go_home_warp_state = 0
        return
    end
    local save_map = g.lets_go_home_settings.map
    if save_map == "" then
        ui.MsgBox(g.lang == "Japanese" and "マップ未設定です" or "Not Map setting")
        g.lets_go_home_warp_state = 0
        return
    end
    local quests = {
        ["c_Klaipe"] = {{
            quest_id = 91055,
            result = "POSSIBLE",
            state = "Start"
        }, {
            quest_id = 72165,
            result = "SUCCESS",
            state = "End"
        }},
        ["c_orsha"] = {{
            quest_id = 90170,
            result = "SUCCESS",
            state = "End"
        }, {
            quest_id = 90171,
            result = "SUCCESS",
            state = "End"
        }},
        ["c_fedimian"] = {{
            quest_id = 60400,
            result = "POSSIBLE",
            state = "Start"
        }}
    }
    if save_map ~= g.map_name then
        local pc = GetMyPCObject()
        local quest_id = nil
        for key, value in pairs(quests) do
            if key == save_map then
                for key2, value2 in pairs(value) do
                    local questIES = GetClassByType('QuestProgressCheck', value2.quest_id)
                    local result = SCR_QUEST_CHECK_C(pc, questIES.ClassName)
                    local questState = GET_QUEST_NPC_STATE(questIES, result)
                    if result == value2.result and questState == value2.state then
                        quest_id = value2.quest_id
                        break
                    end
                end
            end
        end
        if quest_id then
            QUESTION_QUEST_WARP(nil, nil, nil, quest_id)
        else
            Lets_go_home_not_quest_warp(save_map)
        end
        return
    end
    local save_ch = g.lets_go_home_settings.ch
    local channel = session.loginInfo.GetChannel() + 1
    if channel ~= save_ch then
        RUN_GAMEEXIT_TIMER("Channel", save_ch - 1)
        return
    end
    g.lets_go_home_warp_state = 0
    local leticia_warp = g.lets_go_home_settings.leticia
    if leticia_warp == 1 then
        Lets_go_home_leticia_move()
    end
end

function Lets_go_home_not_quest_warp(save_map)
    local cd = GET_TOKEN_WARP_COOLDOWN()
    if cd == 0 then
        g.lets_go_home_warp_state = 1
        WORLDMAP2_TOKEN_WARP_REQUEST(save_map)
        return
    end
    local warp_items = {
        ["c_Klaipe"] = 640073,
        ["c_orsha"] = 640156,
        ["c_fedimian"] = 640182
    }
    session.ResetItemList()
    local inv_item_list = session.GetInvItemList()
    local guid_list = inv_item_list:GetGuidList()
    local cnt = guid_list:Count()
    for i = 0, cnt - 1 do
        local guid = guid_list:Get(i)
        local inv_item = inv_item_list:GetItemByGuid(guid)
        local item_obj = GetIES(inv_item:GetObject())
        local target_id = warp_items[save_map]
        if item_obj.ClassID == target_id and g.map_name ~= save_map then
            if TRY_TO_USE_WARP_ITEM(inv_item, item_obj) ~= 1 then
                g.lets_go_home_warp_state = 1
                INV_ICON_USE(inv_item)
                return
            end
        end
    end
    ui.MsgBox(g.lang == "Japanese" and "ワープする方法がありません" or "There is no way to warp")
    g.lets_go_home_warp_state = 0
end

function Lets_go_home_leticia_move()
    local guid = 309
    local cls = GetClassByType("full_screen_navigation_menu", guid)
    if cls ~= nil then
        local name = TryGetProp(cls, "Name", "None")
        local move_zone_select = TryGetProp(cls, "MoveZoneSelect", "NO")
        local move_zone = TryGetProp(cls, "MoveZone", "None")
        local move_npc_dialog = TryGetProp(cls, "MoveNpcDialog", "None")
        local move_zone_select_msg = TryGetProp(cls, "MoveZoneSelectMsg", "None")
        local move_only_in_town = TryGetProp(cls, "MoveOnlyInTown", "None")
        if move_zone ~= "None" and move_npc_dialog ~= "None" then
            local pc = GetMyPCObject()
            if session.world.IsIntegrateServer() == true or IsPVPField(pc) == 1 or IsPVPServer(pc) == 1 then
                ui.SysMsg(ScpArgMsg("ThisLocalUseNot"))
                return
            end
            if world.GetLayer() ~= 0 then
                ui.SysMsg(ScpArgMsg("ThisLocalUseNot"))
                return
            end
            if g.get_map_type() == "Dungeon" then
                ui.SysMsg(ScpArgMsg("ThisLocalUseNot"))
                return
            end
            local cur_map = GetClass("Map", session.GetMapName())
            local zoneKeyword = TryGetProp(cur_map, 'Keyword', 'None')
            local keywordTable = StringSplit(zoneKeyword, '')
            if table.find(keywordTable, 'IsRaidField') > 0 or table.find(keywordTable, 'WeeklyBossMap') > 0 then
                ui.SysMsg(ScpArgMsg('ThisLocalUseNot'))
                return
            end
            FullScreenMenuMoveNpc(name, move_zone_select, move_zone, move_npc_dialog, move_zone_select_msg,
                move_only_in_town)
            ui.CloseFrame("fullscreen_navigation_menu")
        end
    end
end
-- lets_go_home　ここまで

