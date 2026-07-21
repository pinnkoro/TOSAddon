-- save_quest ここから
function Save_quest_save_settings()
    g.save_json(g.save_quest_path, g.save_quest_settings)
end

function Save_quest_load_settings()
    g.save_quest_path = string.format("../addons/%s/%s/save_quest.json", addon_name_lower, g.active_id)
    local settings = g.load_json(g.save_quest_path)
    local changed = false
    local ver = 1.1
    if not settings then
        settings = {
            ver = ver,
            save_quests = {},
            short_cuts = {},
            frame = {
                move = 0,
                x = 0,
                y = 0,
                skin = "None"
            }
        }
        changed = true
    elseif not settings.ver or settings.ver < ver then
        settings.ver = ver
        settings.frame.skin = "bg2"
        changed = true
    end
    g.save_quest_settings = settings
    if changed then
        Save_quest_save_settings()
    end
end

function save_quest_on_init()
    if not g.save_quest_settings then
        Save_quest_load_settings()
    end
    local old_func = g.settings.save_quest.old_init_func
    if _G[old_func] then
        return
    end
    if g.settings.save_quest.use == 0 then
        ui.DestroyFrame(addon_name_lower .. "save_quest")
        return
    end
    g.setup_hook_and_event(g.addon, "SET_QUEST_CTRL_MARK", "Save_quest_SET_QUEST_CTRL_MARK", true)
    g.setup_hook_and_event(g.addon, "SCR_QUEST_SHARE_PARTY_MEMBER", "Save_quest_SCR_QUEST_SHARE_PARTY_MEMBER", true)
    g.setup_hook_and_event(g.addon, "EXEC_ABANDON_QUEST", "Save_quest_EXEC_ABANDON_QUEST", true)
    g.addon:RegisterMsg("TARGET_SET", "Save_quest_ON_TARGET_SET")
    Save_quest_npc_hide()
    Save_quest_short_cut()
end

function Save_quest_npc_hide()
    local objs, count = SelectObject(GetMyPCObject(), 1000, "ALL")
    local cnt = 0
    for i = 1, count do
        local handle = GetHandle(objs[i])
        if handle then
            if info.IsPC(handle) ~= 1 then
                cnt = cnt + 1
                local gen_type = world.GetActor(handle):GetNPCStateType()
                local pc = GetMyPCObject()
                local gen_list = SCR_GET_XML_IES('GenType_' .. GetZoneName(pc), 'GenType', gen_type)
                for j = 1, #gen_list do
                    local gen_obj = gen_list[j]
                    if g.save_quest_settings.save_quests[gen_obj.Dialog] == 1 then
                        world.Leave(handle, 0.0)
                        break
                    end
                end
            end
        end
    end
end

function Save_quest_settings()
    local list_frame = ui.GetFrame(addon_name_lower .. "list_frame")
    local setting = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "save_quest_setting", 0, 0, 0, 0)
    AUTO_CAST(setting)
    setting:SetPos(list_frame:GetX() + list_frame:GetWidth(), list_frame:GetY())
    setting:SetSkinName("test_frame_low")
    setting:EnableHittestFrame(1)
    setting:EnableHitTest(1)
    setting:SetLayerLevel(999)
    setting:RemoveAllChild()
    local title_text = setting:CreateOrGetControl('richtext', 'title_text', 20, 15, 50, 30)
    AUTO_CAST(title_text)
    title_text:SetText("{ol}Save Quest Config")
    local close = setting:CreateOrGetControl("button", "close", 0, 0, 20, 20)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Save_quest_frame_close")
    local gbox = setting:CreateOrGetControl("groupbox", "gbox", 10, 40, 0, 0)
    AUTO_CAST(gbox)
    gbox:SetSkinName("test_frame_midle_light")
    local move_check = gbox:CreateOrGetControl('checkbox', "move_check", 10, 5, 30, 30)
    AUTO_CAST(move_check)
    move_check:SetCheck(g.save_quest_settings.frame.move)
    move_check:SetEventScript(ui.LBUTTONUP, "Save_quest_check_switch")
    move_check:SetText(g.lang == "Japanese" and "{ol}チェックするとフレーム固定" or
                           "{ol}If checked, the frame is fixed")
    local skin_change = gbox:CreateOrGetControl("button", "skin_change", 40, 40, 80, 30)
    AUTO_CAST(skin_change)
    local skin_text = g.lang == "Japanese" and "{ol}フレームスキン選択" or "{ol}Select Frame Skin"
    skin_change:SetEventScript(ui.LBUTTONUP, "Save_quest_skin_select")
    skin_change:SetText("{ol}SKIN SELECT")
    skin_change:SetTextTooltip(skin_text)
    setting:Resize(300, 130)
    gbox:Resize(setting:GetWidth() - 20, setting:GetHeight() - 50)
    setting:ShowWindow(1)
end

function Save_quest_skin_select()
    local context = ui.CreateContextMenu("save_quest_skin_select", "{ol}Skin Select", 0, 0, 0, 0)
    ui.AddContextMenuItem(context, " ")
    local skin_tbl = {"None", "bg", "bg2"}
    for _, skin_name in ipairs(skin_tbl) do
        local str_scp
        str_scp = string.format("Save_quest_skin_select_('%s')", skin_name)
        local text
        if skin_name == "None" then
            text = g.lang == "Japanese" and "{ol}無し" or "None"
        elseif skin_name == "bg" then
            text = g.lang == "Japanese" and "{ol}黒" or "Solid black"
        elseif skin_name == "bg2" then
            text = g.lang == "Japanese" and "{ol}透明度高め" or "High transparency"
        end
        ui.AddContextMenuItem(context, text, str_scp)
    end
    ui.OpenContextMenu(context)
end

function Save_quest_skin_select_(skin_name)
    g.save_quest_settings.frame.skin = skin_name
    Save_quest_save_settings()
    Save_quest_short_cut()
end

function Save_quest_frame_close(frame)
    ui.DestroyFrame(addon_name_lower .. "save_quest_setting")
end

function Save_quest_check_switch(frame, move_check)
    g.save_quest_settings.frame.move = move_check:IsChecked()
    Save_quest_save_settings()
    Save_quest_short_cut()
end

function Save_quest_EXEC_ABANDON_QUEST(my_frame, my_msg)
    if g.settings.save_quest.use == 0 then
        return
    end
    local quest_id = g.get_event_args(my_msg)
    Save_quest_save(quest_id, "release")
    Save_quest_short_cut_release(nil, nil, tostring(quest_id), nil)
end

function Save_quest_SET_QUEST_CTRL_MARK(my_frame, my_msg)
    local ctrl, quest_cls, state = g.get_event_args(my_msg)
    if g.settings.save_quest.use == 0 then
        DESTROY_CHILD_BYNAME(ctrl, "save_text")
        DESTROY_CHILD_BYNAME(ctrl, "state_pic")
        return
    end
    local quest = ui.GetFrame("quest")
    local questBox = GET_CHILD(quest, "questBox")
    if questBox:GetSelectItemIndex() ~= 1 then
        return
    end
    AUTO_CAST(ctrl)
    --[[local level = GET_CHILD(ctrl, "level")
    if level then
        AUTO_CAST(level)
        level:SetPos(0, 25)
    end]]
    local quest_id = quest_cls.ClassID
    local save_text = GET_CHILD(ctrl, "save_text")
    if save_text then
        DESTROY_CHILD_BYNAME(ctrl, "save_text")
    end
    local result = SCR_QUEST_CHECK_C(GetMyPCObject(), quest_cls.ClassName)
    local npc_state = quest_cls[CONVERT_STATE(result) .. 'NPC']
    if not npc_state then
        return
    end
    if not g.save_quest_settings.save_quests[npc_state] then
        g.save_quest_settings.save_quests[npc_state] = 0
    end
    if g.save_quest_settings.save_quests[npc_state] == 1 then
        local save_text = ctrl:CreateOrGetControl('richtext', "save_text", 0, 0, 20, 10)
        AUTO_CAST(save_text)
        save_text:SetText("{ol}saved")
        save_text:SetPos(330, 5)
    end
    if quest:IsVisible() == 1 then
        if Save_quest_is_warp(quest_cls) == 1 then
            local quest = ui.GetFrame("quest")
            local quest_ctrl_set = GET_CHILD_RECURSIVELY(quest, ctrl:GetName())
            AUTO_CAST(quest_ctrl_set)
            quest_ctrl_set:SetEventScript(ui.RBUTTONDOWN, 'Save_quest_menu')
            quest_ctrl_set:SetEventScriptArgString(ui.RBUTTONDOWN, quest_cls.Name)
            quest_ctrl_set:SetEventScriptArgNumber(ui.RBUTTONDOWN, quest_id)
            local state_pic = ctrl:CreateOrGetControl('picture', "state_pic", 0, 0, 20, 20)
            AUTO_CAST(state_pic)
            state_pic:SetEnableStretch(1)
            state_pic:SetImage("questinfo_return")
            state_pic:SetAngleLoop(-3)
            state_pic:EnableHitTest(1)
            state_pic:SetEventScript(ui.LBUTTONUP, "QUESTION_QUEST_WARP")
            state_pic:SetEventScriptArgNumber(ui.LBUTTONUP, quest_id)
            state_pic:SetEventScript(ui.RBUTTONUP, 'Save_quest_menu')
            state_pic:SetEventScriptArgString(ui.RBUTTONUP, quest_cls.Name)
            state_pic:SetEventScriptArgNumber(ui.RBUTTONUP, quest_id)
            state_pic:SetTextTooltip(g.lang == "Japanese" and
                                         "{ol}[Save Quest]{nl}左クリック:ワープ{nl}右クリック:設定" or
                                         "{ol}[Save Quest]{nl}Left Click: Warp{nl}Right Click: Settings")
            state_pic:SetPos(380, 5)
        end
    end
end

function Save_quest_menu(frame, ctrl, quest_name, quest_id)
    local menu_title = string.format("{ol}[%d] %s", quest_id, quest_name)
    local context = ui.CreateContextMenu("CONTEXT_save_quest", menu_title, 0, 0, string.len(menu_title) * 6, 100)
    ui.AddContextMenuItem(context, "Save", string.format("Save_quest_save(%d,'%s')", quest_id, "save"))
    ui.AddContextMenuItem(context, "Release", string.format("Save_quest_save(%d)", quest_id))
    ui.AddContextMenuItem(context, "ShortCut", string.format("Save_quest_short_cut(%d)", quest_id))
    ui.AddContextMenuItem(context, "ShortCut Release", string.format("Save_quest_short_cut_release(%d)", quest_id))
    ui.AddContextMenuItem(context, "Cancel", "None")
    ui.OpenContextMenu(context)
end

function Save_quest_save(quest_id, stat)
    local quest_cls = GetClassByType("QuestProgressCheck", quest_id)
    local result = SCR_QUEST_CHECK_C(GetMyPCObject(), quest_cls.ClassName)
    local npc_state = quest_cls[CONVERT_STATE(result) .. 'NPC']
    if stat == "save" then
        g.save_quest_settings.save_quests[npc_state] = 1
    else
        g.save_quest_settings.save_quests[npc_state] = nil
    end
    Save_quest_save_settings()
    local quest = ui.GetFrame("quest")
    if quest:IsVisible() == 1 then
        local quest_ctrl_set = GET_CHILD_RECURSIVELY(quest, "_Q_" .. quest_id)
        AUTO_CAST(quest_ctrl_set)
        local quest_cls = GetClassByType("QuestProgressCheck", quest_id)
        SET_QUEST_CTRL_MARK(quest_ctrl_set, quest_cls)
    end
end

function Save_quest_short_cut(quest_id)
    local save_quest = ui.GetFrame(addon_name_lower .. "save_quest")
    if not save_quest then
        save_quest = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "save_quest", 0, 0, 0, 0)
        AUTO_CAST(save_quest)
    end
    save_quest:SetSkinName(g.save_quest_settings.frame.skin)
    save_quest:EnableHittestFrame(1)
    save_quest:EnableMove(g.save_quest_settings.frame.move == 0 and 1 or 0)
    local x = g.save_quest_settings.frame.x
    local y = g.save_quest_settings.frame.y
    if x == 0 and y == 0 then
        x, y = 555, 200
    end
    save_quest:SetPos(x, y)
    save_quest:SetLayerLevel(79)
    save_quest:SetEventScript(ui.LBUTTONUP, "Save_quest_frame_end_drag")
    if quest_id then
        local quest_cls = GetClassByType("QuestProgressCheck", quest_id)
        g.save_quest_settings.short_cuts[tostring(quest_id)] = 1
        Save_quest_save_settings()
    end
    save_quest:ShowWindow(0)
    Save_quest_short_cut_set(save_quest)
end

function Save_quest_frame_end_drag(frame)
    g.save_quest_settings.frame.x = frame:GetX()
    g.save_quest_settings.frame.y = frame:GetY()
    Save_quest_save_settings()
end

function Save_quest_short_cut_set(save_quest)
    save_quest:RemoveAllChild()
    if not next(g.save_quest_settings.short_cuts) then
        save_quest:Resize(0, 0)
        return
    end
    local max_text_width = 0
    local y = 0
    local valid_quest_ids = {}
    for quest_id_str, _ in pairs(g.save_quest_settings.short_cuts) do
        local quest_id = tonumber(quest_id_str)
        local quest_cls = GetClassByType("QuestProgressCheck", quest_id)
        if quest_cls then
            if Save_quest_is_warp(quest_cls) == 1 then
                local state_pic =
                    save_quest:CreateOrGetControl('picture', "state_pic" .. quest_id_str, 5, y + 5, 20, 20)
                AUTO_CAST(state_pic)
                state_pic:SetEnableStretch(1)
                state_pic:SetImage("questinfo_return")
                state_pic:SetAngleLoop(-3)
                state_pic:EnableHitTest(1)
                state_pic:SetEventScript(ui.LBUTTONUP, "QUESTION_QUEST_WARP")
                state_pic:SetEventScriptArgNumber(ui.LBUTTONUP, quest_id)
                state_pic:SetTooltipType('texthelp')
                state_pic:SetTooltipArg("{ol}" .. quest_cls.Name)
                state_pic:SetEventScript(ui.RBUTTONUP, "SAVEQUEST_OPEN_SHORTCUT_MENU")
                local map_info =
                    save_quest:CreateOrGetControl('richtext', "map_info" .. quest_id_str, 27, y + 10, 0, 30)
                AUTO_CAST(map_info)
                local result = SCR_QUEST_CHECK_Q(SCR_QUESTINFO_GET_PC(), quest_cls.ClassName)
                local map_name = quest_cls[CONVERT_STATE(result) .. 'Map']
                local zone_name = GetClassString('Map', map_name, 'Name')
                map_info:SetText(string.format("{s12}{ol}%s", zone_name))
                --[[map_info:SetEventScript(ui.RBUTTONUP, "Save_quest_short_cut_release")
                map_info:SetEventScriptArgString(ui.RBUTTONUP, quest_id_str)]]
                map_info:EnableHitTest(1)
                local text_w = map_info:GetWidth()
                if max_text_width < text_w then
                    max_text_width = text_w
                end
                local share_party = save_quest:CreateOrGetControl("picture", "share_party" .. quest_id_str, 0, y + 5,
                    20, 20)
                AUTO_CAST(share_party)
                share_party:SetEnableStretch(1)
                share_party:SetImage("btn_partyshare")
                share_party:EnableHitTest(1)
                share_party:SetTextTooltip(g.lang == "Japanese" and "{ol}クエストPTシェア切替" or
                                               "Quest PT Share Toggle")
                share_party:SetEventScript(ui.LBUTTONUP, "SCR_QUEST_SHARE_PARTY_MEMBER")
                share_party:SetEventScriptArgNumber(ui.LBUTTONUP, quest_id)
                if IS_SHARED_QUEST(quest_id) then
                    share_party:SetColorTone("FFFFFFFF")
                else
                    share_party:SetColorTone("FF696969")
                end
                table.insert(valid_quest_ids, quest_id_str)
                y = y + 30
            end
        end
    end
    local icon_align_x = 27 + max_text_width + 10
    for _, quest_id_str in ipairs(valid_quest_ids) do
        local share_party = save_quest:GetChild("share_party" .. quest_id_str)
        if share_party then
            share_party:SetOffset(icon_align_x, share_party:GetY())
        end
    end
    save_quest:Resize(icon_align_x + 30, y)
    save_quest:ShowWindow(1)
end

function Save_quest_ON_TARGET_SET(frame, msg, str, num)
    local handle = session.GetTargetHandle()
    local gen_type = world.GetActor(handle):GetNPCStateType()
    local pc = GetMyPCObject()
    local gen_list = SCR_GET_XML_IES('GenType_' .. GetZoneName(pc), 'GenType', gen_type)
    for i = 1, #gen_list do
        local gen_obj = gen_list[i]
        if g.save_quest_settings.save_quests[gen_obj.Dialog] == 1 then
            world.Leave(handle, 0.0)
            break
        end
    end
end

function Save_quest_SCR_QUEST_SHARE_PARTY_MEMBER()
    if g.settings.save_quest.use == 0 then
        ui.DestroyFrame(addon_name_lower .. "save_quest")
        return
    end
    local save_quest = ui.GetFrame(addon_name_lower .. "save_quest")
    if save_quest then
        Save_quest_short_cut_set(save_quest)
    end
end

function Save_quest_short_cut_release(quest_id)
    g.save_quest_settings.short_cuts[tostring(quest_id)] = nil
    Save_quest_save_settings()
    if not next(g.save_quest_settings.short_cuts) then
        local save_quest = ui.GetFrame(addon_name_lower .. "save_quest")
        save_quest:Resize(0, 0)
        return
    else
        Save_quest_short_cut(nil)
    end
end
-- ワープ可能か判定
function Save_quest_is_warp(quest_cls)
    local result = SCR_QUEST_CHECK_C(GetMyPCObject(), quest_cls.ClassName)
    if not GET_QUEST_NPC_STATE(quest_cls, result) then
        return 0
    end
    if (result == 'POSSIBLE' and quest_cls.POSSI_WARP == 'YES') or
        (result == 'PROGRESS' and quest_cls.PROG_WARP == 'YES') or
        (result == 'SUCCESS' and quest_cls.SUCC_WARP == 'YES') then
        return 1
    end
    return 0
end
-- save_quest ここまで

