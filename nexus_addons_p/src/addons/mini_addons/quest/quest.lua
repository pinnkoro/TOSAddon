-- クエストインフォを隠す
function Mini_addons_ON_UPDATE_QUESTINFOSET_2(questinfoset_2, msg, check, update_quest_id)
    local chase_info = ui.GetFrame("chaseinfo")
    local open_mark_quest = GET_CHILD_RECURSIVELY(chase_info, "openMark_quest")
    AUTO_CAST(open_mark_quest)
    open_mark_quest:ShowWindow(1)
    open_mark_quest:SetEventScript(ui.RBUTTONUP, "Mini_addons_questinfo_toggle")
    local notice =
        g.lang == "Japanese" and "{ol}Mini Addons{nl}右クリック: クエストの表示/非表示切替" or
            "{ol}Mini Addons{nl}Right-click: Show/hide quests"
    open_mark_quest:SetTextTooltip(notice)
    if not questinfoset_2 then
        questinfoset_2 = ui.GetFrame("questinfoset_2")
    end
    if g.settings.quest_hide == 1 then
        questinfoset_2:ShowWindow(0)
        return
    end
    if CHASEINFO_IS_SHOW() == 0 then
        CHASEINFO_CLOSE_FRAME()
        return
    end
    CHASEINFO_SHOW_QUEST_TOGGLE(QUESTINFOSET_2_IS_DRAW())
    CHASEINFO_SHOW_ACHIEVE_TOGGLE(ACHIEVEINFOSET_IS_DRAW())
    if QUESTINFOSET_2_IS_DRAW() == 0 then
        questinfoset_2:ShowWindow(0)
        return
    else
        if ACHIEVEINFOSET_IS_DRAW() == 1 then
            if CHASEINFO_IS_ACHIEVE_FOLD() == 0 then
                CHASEINFO_SET_QUEST_INFOSET_FOLD(1)
            else
                if CHASEINFO_IS_QUEST_FOLD() == 1 then
                    CHASEINFO_SET_QUEST_INFOSET_FOLD(1)
                else
                    CHASEINFO_SET_QUEST_INFOSET_FOLD(0)
                end
            end
        else
            CHASEINFO_SET_QUEST_INFOSET_FOLD(0)
        end
    end
    if ACHIEVEINFOSET_IS_VALID_ACHIEVE() == 1 and CHASEINFO_IS_ACHIEVE_FOLD() == 0 then
        questinfoset_2:ShowWindow(0)
        return
    elseif CHASEINFO_IS_QUEST_FOLD() == 1 then
        questinfoset_2:ShowWindow(0)
        return
    else
        questinfoset_2:ShowWindow(1)
    end
    if update_quest_id ~= nil and update_quest_id > 0 then
        local group_ctrl = GET_CHILD(questinfoset_2, "member", "ui::CGroupBox")
        UPDATE_QUESTINFOSET_2_BY_TYPE(group_ctrl, msg, update_quest_id)
        QUESTINFOSET_2_AUTO_ALIGN(questinfoset_2, group_ctrl)
        return
    end
    if msg == "GAME_START" then
        PC_ENTER_QUESTINFO(questinfoset_2)
    end
    local group_ctrl = GET_CHILD(questinfoset_2, "member", "ui::CGroupBox")
    group_ctrl:DeleteAllControl()
    local quest_custom = GET_CHILD(questinfoset_2, "quest_custom")
    local quest_custom_size = quest_custom:GetMargin().top + quest_custom:GetHeight()
    local y = quest_custom_size
    local custom_option = GET_CHILD(questinfoset_2, "quest_custom", "ui::CCheckBox")
    if custom_option:IsChecked() == 0 then
        local cnt = QUESTINFOSET_2_GET_QUEST_NUM()
        for i = 0, cnt - 1 do
            local quest_id = quest.GetCheckQuest(i)
            local quest_cls = GetClassByType("QuestProgressCheck", quest_id)
            local ctrl_set = MAKE_QUEST_INFO_C(group_ctrl, quest_cls, msg)
            if ctrl_set ~= nil then
                y = y + ctrl_set:GetHeight()
            end
        end
    end
    local value = custom_option:GetUserIValue("is_quest_custom_draw")
    local custom_cnt = QUESTINFOSET_2_GET_CUSTOM_QUEST_NUM()
    if custom_cnt > 0 and (value ~= -1 or custom_option:IsChecked() == 1) then
        local ctrl_set = QUESTINFOSET_2_MAKE_CUSTOM(questinfoset_2, true)
        if ctrl_set ~= nil then
            y = y + ctrl_set:GetHeight()
        end
    end
    QUESTINFOSET_2_AUTO_ALIGN(questinfoset_2, group_ctrl)
    if custom_option:IsChecked() == 0 then
        QUEST_PARTY_MEMBER_PROP_UPDATE(questinfoset_2)
    end
end

function Mini_addons_questinfo_toggle(parent, openMark_quest)
    g.settings.quest_hide = 1 - g.settings.quest_hide
    Mini_addons_save_settings()
    Mini_addons_ON_UPDATE_QUESTINFOSET_2(nil)
end
-- お使いクエストフレーム
function Mini_addons_quest_update(frame, msg)
    if g.settings.daily_quest == 0 then
        ui.DestroyFrame((addon_name_lower .. "_q7quest"))
        return
    end
    local questinfoset_2 = ui.GetFrame("questinfoset_2")
    local _Q_7 = GET_CHILD_RECURSIVELY(questinfoset_2, "_Q_7")
    if _Q_7 then
        local color = "{#FFFFFF}"
        local extracted_content
        local MON_1 = GET_CHILD(_Q_7, "MON_1")
        if MON_1 then
            local text = MON_1:GetText()
            local pattern = "%((.-)%)"
            extracted_content = text:match(pattern)
            extracted_content = color .. extracted_content
        else
            color = "{#FF0000}"
            extracted_content = color .. "150/150"
        end
        local QUESTINFOMAP = GET_CHILD(_Q_7, "QUESTINFOMAP")
        local last_part
        if QUESTINFOMAP then
            local text = QUESTINFOMAP:GetText()
            last_part = text:match(".*{nl}(.-)$") or ""
        end
        if last_part == "" then
            local q7quest = ui.GetFrame((addon_name_lower .. "_q7quest"))
            if q7quest then
                AUTO_CAST(q7quest)
                q7quest:ShowWindow(0)
                return
            end
        end
        local groupQuest_title = GET_CHILD(_Q_7, "groupQuest_title")
        local text = groupQuest_title:GetText()
        local pattern = "{#ffe792}(.-) %-"
        local extracted_text = text:match(pattern) or "Quest"
        local q7quest = ui.GetFrame((addon_name_lower .. "_q7quest"))
        if not q7quest then
            q7quest = ui.CreateNewFrame("notice_on_pc", (addon_name_lower .. "_q7quest"), 0, 0, 0, 0)
            AUTO_CAST(q7quest)
        end
        if not msg then
            q7quest:RemoveAllChild()
        end
        q7quest:SetSkinName("bg2")
        q7quest:Resize(200, 85)
        local current_frame_w = q7quest:GetWidth()
        local map_frame = ui.GetFrame("map")
        local map_width = map_frame:GetWidth()
        q7quest:SetPos((map_width - current_frame_w) / 2, 130)
        q7quest:SetLayerLevel(100)
        if _G["INDUN_PANEL_ON_INIT"] and type(_G["INDUN_PANEL_ON_INIT"]) == "function" then
            local indun_panel = ui.GetFrame("indun_panel")
            if indun_panel then
                indun_panel_always_init(indun_panel, nil, nil)
            end
        end
        if _G["indun_panel_on_init"] and type(_G["indun_panel_on_init"]) == "function" then
            -- 自分側の indun_panel。フレーム名は core の addon_name_lower("_nexus_addons_p")
            -- が前に付く。ここを直書きにすると P へのリネームで食い違う
            local indun_panel = ui.GetFrame(core_addon_name_lower .. "indun_panel")
            if indun_panel then
                Indun_panel_always_init(indun_panel, nil, nil)
            end
        end
        local quest_name = q7quest:CreateOrGetControl("richtext", "quest_name", 10, 5, 180, 25)
        AUTO_CAST(quest_name)
        quest_name:SetTextAlign("center", "center")
        quest_name:SetText("{ol}{s16}" .. extracted_text)
        quest_name:EnableTextOmitByWidth(1)
        local map_name = q7quest:CreateOrGetControl("richtext", "map_name", 10, 30, 180, 25)
        AUTO_CAST(map_name)
        map_name:SetTextAlign("center", "center")
        map_name:SetText("{ol}{s16}" .. last_part)
        map_name:EnableTextOmitByWidth(1)
        local kill_count = q7quest:CreateOrGetControl("richtext", "kill_count", 10, 55, 180, 25)
        AUTO_CAST(kill_count)
        kill_count:SetTextAlign("center", "center")
        kill_count:SetText("{ol}{s18}" .. extracted_content)
        local token_warp = q7quest:CreateOrGetControl("button", "token_warp", 5, 48, 40, 40)
        AUTO_CAST(token_warp)
        token_warp:SetSkinName("None")
        local is_token_state = session.loginInfo.IsPremiumState(ITEM_TOKEN)
        local image_name = ""
        if is_token_state == true and GET_TOKEN_WARP_COOLDOWN() == 0 then
            image_name = "{img worldmap2_token_gold 35 35} {@st101lightbrown_16}"
        else
            image_name = "{img worldmap2_token_gray 35 35} {@st101lightbrown_16}"
        end
        token_warp:SetText(image_name)
        token_warp:SetTextTooltip("{ol}" .. last_part)
        token_warp:SetEventScript(ui.LBUTTONUP, "Mini_addons_quest_token_warp")
        q7quest:ShowWindow(1)
        local abandon = q7quest:CreateOrGetControl("button", "abandon", 165, 53, 30, 30)
        AUTO_CAST(abandon)
        abandon:SetSkinName("test_gray_button")
        abandon:SetText("×")
        abandon:SetEventScript(ui.LBUTTONUP, "SCR_QUEST_ABANDON_SELECT")
        abandon:SetEventScriptArgNumber(ui.LBUTTONUP, 7)
    else
        ui.DestroyFrame((addon_name_lower .. "_q7quest"))
    end
end

function Mini_addons_quest_token_warp()
    local target_map = Mini_addons_quest_get_map()
    if target_map then
        WORLDMAP2_TOKEN_WARP(target_map)
    end
end

function Mini_addons_quest_get_map()
    local quest_ies = GetClassByType("QuestProgressCheck", 7)
    local pc = SCR_QUESTINFO_GET_PC()
    local quest_max_mon_check = 6
    if quest_ies.Quest_SSN ~= "None" then
        local s_obj_quest = GetSessionObject(pc, quest_ies.Quest_SSN)
        if s_obj_quest and s_obj_quest.SSNMonKill ~= "None" then
            local mon_list = SCR_STRING_CUT(s_obj_quest.SSNMonKill, ":")
            if mon_list[1] == "ZONEMONKILL" then
                for i = 1, quest_max_mon_check do
                    if #mon_list - 1 >= i then
                        local index = i + 1
                        local zone_mon_info = SCR_STRING_CUT(mon_list[index])
                        local target_map = tostring(zone_mon_info[1])
                        return target_map
                    end
                end
            end
        end
    end
    return nil
end
