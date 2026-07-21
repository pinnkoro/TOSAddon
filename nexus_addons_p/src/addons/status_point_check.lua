-- status_point_check ここから
function status_point_check_on_init()
    if g.settings.status_point_check.use == 0 then
        local status = ui.GetFrame("status")
        DESTROY_CHILD_BYNAME(status, "spc_btn")
        return
    end
    g.setup_hook_and_event(g.addon, "STATUS_TAB_CHANGE", "Status_point_check_STATUS_TAB_CHANGE", true)
end

function Status_point_check_frame()
    Status_point_check_toggle_frame()
end

function Status_point_check_STATUS_TAB_CHANGE(my_frame, my_msg)
    if g.settings.status_point_check.use == 0 then
        local status = ui.GetFrame("status")
        DESTROY_CHILD_BYNAME(status, "spc_btn")
        return
    end
    local status = g.get_event_args(my_msg)
    local statusTab = status:GetChild('statusTab')
    AUTO_CAST(statusTab)
    local index = statusTab:GetSelectItemIndex()
    if index == 0 then
        local spc_btn = status:CreateOrGetControl("button", "spc_btn", 350, 140, 120, 40) -- 350, 140, 120, 40
        AUTO_CAST(spc_btn)
        spc_btn:SetSkinName("test_pvp_btn")
        spc_btn:SetFontName("white_16_ol")
        spc_btn:SetText(g.lang == "Japanese" and "{@st66b}クエスト確認" or "{@st66b}Check Quest")
        spc_btn:SetTextTooltip(g.lang == "Japanese" and
                                   "{ol}ステータスポイントがもらえるクエストを{nl}クリアしているかどうか確認できます" or
                                   "{ol}Check whether you are clearing quests{nl}that receive status points")
        spc_btn:SetClickSound("button_click_big")
        spc_btn:SetOverSound("button_over")
        spc_btn:SetAnimation("MouseOnAnim", "btn_mouseover")
        spc_btn:SetAnimation("MouseOffAnim", "btn_mouseoff")
        spc_btn:SetEventScript(ui.LBUTTONDOWN, "Status_point_check_toggle_frame")
    else
        DESTROY_CHILD_BYNAME(status, "spc_btn")
    end
end

function Status_point_check_toggle_frame(frame, ctrl)
    local status_point_check = ui.GetFrame(addon_name_lower .. "status_point_check")
    if status_point_check and status_point_check:IsVisible() == 1 then
        ui.DestroyFrame(addon_name_lower .. "status_point_check")
        return
    end
    if not status_point_check then
        status_point_check = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "status_point_check", 0, 0, 0, 0)
        AUTO_CAST(status_point_check)
    end
    status_point_check:SetSkinName("collection_complete")
    status_point_check:SetPos(510, 100)
    status_point_check:Resize(950, 850)
    status_point_check:SetLayerLevel(99)
    status_point_check:SetTitleBarSkin("None")
    status_point_check:SetSkinName('None')
    local big_bg = status_point_check:CreateOrGetControl("groupbox", "big_bg", 950, 850, ui.LEFT, ui.TOP, 0, 0, 0, 0)
    AUTO_CAST(big_bg)
    big_bg:SetSkinName("test_frame_low")
    local title_bg = big_bg:CreateOrGetControl("groupbox", "title_bg", 950, 64, ui.LEFT, ui.TOP, 0, 0, 0, 0)
    AUTO_CAST(title_bg)
    title_bg:SetSkinName("test_frame_top")
    local title = big_bg:CreateOrGetControl("richtext", "title", 100, 30, ui.CENTER_HORZ, ui.TOP, 0, 18, 0, 0)
    title:SetText("{@st43}{s22}Status Point Check{/}")
    title:EnableHitTest(false)
    local close = title_bg:CreateOrGetControl("button", "close", 44, 44, ui.RIGHT, ui.TOP, 0, 20, 27, 0)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetClickSound("button_click_big")
    close:SetOverSound("button_over")
    close:SetAnimation("MouseOnAnim", "btn_mouseover")
    close:SetAnimation("MouseOffAnim", "btn_mouseoff")
    close:SetEventScript(ui.LBUTTONDOWN, "Status_point_check_toggle_frame")
    local tab = big_bg:CreateOrGetControl("tab", "tab", 930, 40, ui.LEFT, ui.TOP, 22, 65, 0, 0)
    AUTO_CAST(tab)
    tab:SetEventScript(ui.LBUTTONUP, "Status_point_check_tab_change")
    tab:SetSkinName("tab2")
    tab:AddItem("{@st66b}Status", true, "", "", "", "", "", false)
    tab:AddItem("{@st66b}Zemina", true, "", "", "", "", "", false)
    tab:AddItem("{@st66b}Master Quest", true, "", "", "", "", "", false)
    tab:SetItemsFixWidth(150)
    tab:SetItemsAdjustFontSizeByWidth(150)
    local bg = big_bg:CreateOrGetControl("groupbox", "bg", 910, 725, ui.LEFT, ui.TOP, 20, 105, 0, 0)
    AUTO_CAST(bg)
    bg:SetSkinName("test_frame_midle")
    Status_point_check_tab_change(big_bg, tab)
    status_point_check:ShowWindow(1)
end

function Status_point_check_tab_change(big_bg, tab, str, num)
    local bg = GET_CHILD(big_bg, "bg")
    AUTO_CAST(bg)
    bg:RemoveAllChild()
    local index = tab:GetSelectItemIndex()
    if index == 0 then
        Status_point_check_quest_list(big_bg, bg)
    elseif index == 1 then
        Status_point_check_zemina_list(big_bg, bg)
    elseif index == 2 then
        Status_point_check_master_quest_list(big_bg, bg)
    end
end

function Status_point_check_master_quest_list(big_bg, bg)
    local title = bg:CreateOrGetControl("richtext", "title", 15, 5, 0, 0)
    AUTO_CAST(title)
    title:SetFontName("white_18_ol")
    title:SetText("Quest List For Master Quest")
    local start_map = bg:CreateOrGetControl("richtext", "start_map", 545, 5, 0, 0)
    AUTO_CAST(start_map)
    start_map:SetFontName("white_18_ol")
    start_map:SetText("Quest Start Map")
    local y = 35
    local quests, quests_cnt = GetClassList("QuestProgressCheck_Auto")
    for i = 0, quests_cnt - 1 do
        local quest_cls = GetClassByIndexFromList(quests, i)
        if quest_cls.Success_ItemName1 == "Point_Stone_100_Q" then -- ts("{img quest_detail_pic2 24 24}")
            local script_btn = bg:CreateOrGetControl("button", "script_btn" .. i, 15, y, 20, 20)
            AUTO_CAST(script_btn)
            script_btn:SetSkinName("None")
            script_btn:SetText("{img quest_detail_pic2 20 20}")
            script_btn:SetTextTooltip(g.lang == "Japanese" and "{ol}クエスト詳細表示" or
                                          "{ol}Show quest information")
            script_btn:SetEventScript(ui.LBUTTONDOWN, "QUEST_CLICK_INFO")
            script_btn:SetEventScriptArgNumber(ui.LBUTTONDOWN, quest_cls.ClassID)
            local quest_name = bg:CreateOrGetControl("richtext", "quest_name" .. i, 40, y, 0, 20)
            AUTO_CAST(quest_name)
            local quest_result = bg:CreateOrGetControl("richtext", "quest_result" .. i, 400, y, 0, 20)
            AUTO_CAST(quest_result)
            local map_name = bg:CreateOrGetControl("richtext", "map_name" .. i, 550, y, 0, 20)
            AUTO_CAST(map_name)
            local color = ""
            local result = ""
            if Status_point_check_quest_clear_check(quest_cls) then
                color = "{#FF3333}{ol}{b}{s16}"
                result = "OK"
            else
                color = "{#666666}{ol}{b}{s16}"
                result = "NO"
                local quest = GetClassByType('QuestProgressCheck', quest_cls.ClassID)
                local map_prop = geMapTable.GetMapProp(quest.StartMap)
                if map_prop then
                    local map_name_ = dictionary.ReplaceDicIDInCompStr(map_prop:GetName())
                    map_name:SetText(color .. map_name_ .. "[Level:" .. quest.Level .. "]")
                else
                    map_name:SetText(color .. "??[Level:" .. quest.Level .. "]")
                end
            end
            quest_name:SetText(color .. quest_cls.Name)
            quest_result:SetText(color .. result)
            y = y + 24
        end
    end
end

function Status_point_check_quest_list(big_bg, bg)
    local y = Status_point_check_quest_check(big_bg, bg)
    Status_point_check_status_quest_check(big_bg, bg, y)
end

function Status_point_check_zemina_list(big_bg, bg)
    local title = bg:CreateOrGetControl("richtext", "title", 15, 5, 0, 0)
    AUTO_CAST(title)
    title:SetFontName("white_18_ol")
    title:SetText("Zemina List")
    local y = 35
    local ui_index = 0
    local maps, maps_cnt = GetClassList("Map")
    for i = 0, maps_cnt - 1 do
        local map_cls = GetClassByIndexFromList(maps, i)
        local count = GetClassCount('GenType_' .. map_cls.ClassName)
        if count > 0 then
            for j = 0, count - 1 do
                local npc_cls = GetClassByIndex('GenType_' .. map_cls.ClassName, j)
                if npc_cls.ClassType == "statue_zemina" then
                    local map_name = bg:CreateOrGetControl("richtext", "map_name" .. ui_index, 20, y, 0, 20)
                    AUTO_CAST(map_name)
                    local zemina_result = bg:CreateOrGetControl("richtext", "zemina_result" .. ui_index, 400, y, 0, 20)
                    AUTO_CAST(zemina_result)
                    local color = ""
                    local result = ""
                    local state = GetNPCState(map_cls.ClassName, npc_cls.GenType)
                    if state == 20 or state == 1 then
                        color = "{#FF3333}{ol}{b}{s16}"
                        result = "OK"
                    else
                        color = "{#666666}{ol}{b}{s16}"
                        result = "NO"
                    end
                    map_name:SetText(color .. map_cls.Name)
                    zemina_result:SetText(color .. result)
                    y = y + 25
                    ui_index = ui_index + 1
                    break
                end
            end
        end
    end
end

function Status_point_check_status_quest_check(big_bg, bg, y)
    local title_2 = bg:CreateOrGetControl("richtext", "title_2", 15, y + 10, 0, 0)
    AUTO_CAST(title_2)
    title_2:SetFontName("white_18_ol")
    title_2:SetText("Quest List For Status")
    local start_map_2 = bg:CreateOrGetControl("richtext", "start_map_2", 545, y + 10, 0, 0)
    AUTO_CAST(start_map_2)
    start_map_2:SetFontName("white_18_ol")
    start_map_2:SetText("Quest Start Map")
    local rewards, rewards_cnt = GetClassList("reward_property")
    local y = y + 40
    for i = 0, rewards_cnt - 1 do
        local reward_cls = GetClassByIndexFromList(rewards, i)
        if reward_cls.Property ~= "None" and reward_cls.Property ~= "AchievePoint" then
            local quest_cls = GetClass("QuestProgressCheck_Auto", reward_cls.ClassName)
            local script_btn = bg:CreateOrGetControl("button", "script_btn" .. i, 15, y, 20, 20)
            AUTO_CAST(script_btn)
            script_btn:SetSkinName("None")
            script_btn:SetText("{img quest_detail_pic2 20 20}")
            script_btn:SetTextTooltip(g.lang == "Japanese" and "{ol}クエスト詳細表示" or
                                          "{ol}Show quest information")
            script_btn:SetEventScript(ui.LBUTTONDOWN, "QUEST_CLICK_INFO")
            script_btn:SetEventScriptArgNumber(ui.LBUTTONDOWN, quest_cls.ClassID)
            local quest_name_2 = bg:CreateOrGetControl("richtext", "quest_name_2" .. i, 40, y, 0, 0)
            AUTO_CAST(quest_name_2)
            local quest_result_2 = bg:CreateOrGetControl("richtext", "quest_result_2" .. i, 400, y, 0, 0)
            AUTO_CAST(quest_result_2)
            local point_2 = bg:CreateOrGetControl("richtext", "point_2" .. i, 440, y, 0, 0)
            AUTO_CAST(point_2)
            local map_2 = bg:CreateOrGetControl("richtext", "map_2" .. i, 550, y, 0, 0)
            AUTO_CAST(map_2)
            local color = ""
            local result = "" -- ClMsg(reward_cls.Property)
            if Status_point_check_quest_clear_check(quest_cls) then
                color = "{#FF3333}{ol}{b}{s16}"
                result = "OK"
            else
                color = "{#666666}{ol}{b}{s16}"
                result = "NO"
                local quest = GetClass("QuestProgressCheck", quest_cls.ClassName)
                local map_prop = geMapTable.GetMapProp(quest.StartMap)
                if map_prop then
                    local map_name = dictionary.ReplaceDicIDInCompStr(map_prop:GetName())
                    map_2:SetText(color .. map_name .. "[Level:" .. quest.Level .. "]")
                else
                    map_2:SetText(color .. "??[Level:" .. quest.Level .. "]")
                end
            end
            quest_name_2:SetText(color .. quest_cls.Name)
            quest_result_2:SetText(color .. result)
            if reward_cls.Property == "MaxWeight" then
                local suffix = g.lang == "Japanese" and "所持量" .. " + " .. reward_cls.Value or "Weight" .. " + " ..
                                   reward_cls.Value
                point_2:SetText(color .. suffix)
            else
                point_2:SetText(color .. ClMsg(reward_cls.Property) .. " + " .. reward_cls.Value)
            end
            y = y + 25
        end
    end
end

function Status_point_check_quest_check(big_bg, bg)
    local title = bg:CreateOrGetControl("richtext", "title", 15, 5, 0, 0)
    AUTO_CAST(title)
    local start_map = bg:CreateOrGetControl("richtext", "start_map", 545, 5, 0, 0)
    AUTO_CAST(start_map)
    start_map:SetFontName("white_18_ol")
    start_map:SetText("Quest Start Map")
    local quests, quest_cnt = GetClassList("QuestProgressCheck_Auto")
    local sum_point = 0
    local get_point = 0
    local y = 35
    for i = 0, quest_cnt - 1 do
        local quest_cls = GetClassByIndexFromList(quests, i)
        if quest_cls.Success_StatByBonus and quest_cls.Success_StatByBonus > 0 then
            sum_point = sum_point + quest_cls.Success_StatByBonus
            local script_btn = bg:CreateOrGetControl("button", "script_btn" .. i, 15, y, 20, 20)
            AUTO_CAST(script_btn)
            script_btn:SetSkinName("None")
            script_btn:SetText("{img quest_detail_pic2 20 20}")
            script_btn:SetTextTooltip(g.lang == "Japanese" and "{ol}クエスト詳細表示" or
                                          "{ol}Show quest information")
            script_btn:SetEventScript(ui.LBUTTONDOWN, "QUEST_CLICK_INFO")
            script_btn:SetEventScriptArgNumber(ui.LBUTTONDOWN, quest_cls.ClassID)
            local quest_name = bg:CreateOrGetControl("richtext", "quest_name" .. i, 40, y, 0, 0)
            AUTO_CAST(quest_name)
            local quest_result = bg:CreateOrGetControl("richtext", "quest_result" .. i, 400, y, 0, 0)
            AUTO_CAST(quest_result)
            local point = bg:CreateOrGetControl("richtext", "point" .. i, 440, y, 0, 0)
            AUTO_CAST(point)
            local map = bg:CreateOrGetControl("richtext", "map" .. i, 550, y, 0, 0)
            AUTO_CAST(map)
            local color = ""
            local result = ""
            if Status_point_check_quest_clear_check(quest_cls) then
                color = "{#FF3333}{ol}{b}{s16}"
                result = "OK"
                get_point = get_point + quest_cls.Success_StatByBonus
            else
                color = "{#666666}{ol}{b}{s16}"
                result = "NO"
                local quest = GetClassByType('QuestProgressCheck', quest_cls.ClassID)
                local map_prop = geMapTable.GetMapProp(quest.StartMap)
                if map_prop then
                    local map_name = dictionary.ReplaceDicIDInCompStr(map_prop:GetName())
                    map:SetText(color .. map_name .. "[Level:" .. quest.Level .. "]")
                else
                    map:SetText(color .. "??[Level:" .. quest.Level .. "]")
                end
            end
            quest_name:SetText(color .. quest_cls.Name)
            quest_result:SetText(color .. result)
            point:SetText(color .. quest_cls.Success_StatByBonus .. " Point")
            y = y + 25
        end
    end
    title:SetFontName("white_18_ol")
    title:SetText("Quest List For Status Point (" .. get_point .. "/" .. sum_point .. ")")
    return y
end

function Status_point_check_quest_clear_check(quest_cls)
    local result = SCR_QUEST_CHECK(GetMyPCObject(), quest_cls.ClassName)
    if result == 'SUCCESS' or result == 'COMPLETE' then
        return true
    end
    return false
end
-- status_point_check ここまで

