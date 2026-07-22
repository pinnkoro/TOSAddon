-- Battle_ritual ここから
function Battle_ritual_save_settings()
    g.save_json(g.battle_ritual_path, g.battle_ritual_settings)
end

function Battle_ritual_load_settings()
    g.battle_ritual_path = string.format("../addons/%s/%s/battle_ritual.json", addon_name_lower, g.active_id)
    local settings = g.load_json(g.battle_ritual_path)
    if not settings then
        settings = {
            skills = {},
            etc = {
                x = 0,
                y = 0,
                move = 0,
                use = 0
            }
        }
    end
    g.battle_ritual_settings = settings
    Battle_ritual_save_settings()
end

function battle_ritual_on_init()
    if not g.battle_ritual_settings then
        Battle_ritual_load_settings()
    end
    if g.settings.battle_ritual.use == 0 then
        ui.DestroyFrame(addon_name_lower .. "Battle_ritual")
        return
    end
    Battle_ritual_frame_init()
    if g.get_map_type() == "Instance" or g.map_id == 11244 or g.map_id == 8022 then -- 11244 聖域3F 11227 分裂 8022 ヴェルニケ
        g.addon:RegisterMsg('REQ_PLAYER_CONTENTS_RECORD', 'Battle_ritual_REQ_PLAYER_CONTENTS_RECORD')
        Battle_ritual_auto_buff_skill_start()
    end
end

function Battle_ritual_auto_buff_skill_start()
    -- pcallでラップしてエラー落ちを防ぎつつログを出す
    local status, err = pcall(function()
        if g.battle_ritual_settings.etc.use == 0 then
            return
        end

        local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
        local list = session.party.GetPartyMemberList(PARTY_NORMAL)
        if list:Count() > 1 then
            _nexus_addons_p:StopUpdateScript("Battle_ritual_auto_buff_skill")
            return
        end
        local skills_table = g.battle_ritual_settings.skills
        if not skills_table then
            return
        end
        local sorted_list = {}
        for s_id, data in pairs(skills_table) do
            table.insert(sorted_list, {
                skill_id = tonumber(s_id),
                buff_id = data.buff_id,
                priority = data.priority
            })
        end
        table.sort(sorted_list, function(a, b)
            if a.priority ~= b.priority then
                return a.priority < b.priority
            else
                return tonumber(a.skill_id) < tonumber(b.skill_id)
            end
        end)
        local skill_map = {}
        for i = 0, 40 - 1 do
            local quick_slot_info = quickslot.GetInfoByIndex(i)
            if quick_slot_info and quick_slot_info.category == 'Skill' then
                skill_map[quick_slot_info.type] = i
            end
        end
        g.battle_ritual_use_queue = {}
        local my_handle = session.GetMyHandle()
        local quickslotnexpbar = ui.GetFrame("quickslotnexpbar")
        for _, data in ipairs(sorted_list) do
            local skill_id = data.skill_id
            local slot_index = skill_map[skill_id]
            if slot_index then
                local slot = GET_CHILD_RECURSIVELY(quickslotnexpbar, "slot" .. (slot_index + 1), "ui::CSlot")
                if slot then
                    local icon = slot:GetIcon()
                    if icon then
                        local cur_time = ICON_UPDATE_SKILL_COOLDOWN(icon)
                        if cur_time == 0 then
                            local buff_id = data.buff_id
                            local need_buff = true
                            if buff_id > 0 then
                                if info.GetBuff(my_handle, buff_id) then
                                    need_buff = false
                                end
                            end
                            if need_buff then
                                table.insert(g.battle_ritual_use_queue, {
                                    buff_id = buff_id,
                                    skill_id = skill_id,
                                    icon = icon
                                })
                            end
                        end
                    end
                end
            end
        end
        if #g.battle_ritual_use_queue > 0 then
            _nexus_addons_p:RunUpdateScript("Battle_ritual_auto_buff_skill", 0.1)
        end
    end)
end

function Battle_ritual_auto_buff_skill(_nexus_addons_p)
    local status, result = pcall(function()
        if not g.battle_ritual_use_queue or #g.battle_ritual_use_queue == 0 then
            return 0
        end
        local next_skill_info = g.battle_ritual_use_queue[1]
        if not next_skill_info or not next_skill_info.icon then
            table.remove(g.battle_ritual_use_queue, 1)
            return 1
        end
        local my_handle = session.GetMyHandle()
        local buff_info = nil
        if next_skill_info.buff_id and next_skill_info.buff_id > 0 then
            buff_info = info.GetBuff(my_handle, next_skill_info.buff_id)
        end
        local current_cooldown = ICON_UPDATE_SKILL_COOLDOWN(next_skill_info.icon)
        if current_cooldown == 0 and (next_skill_info.buff_id == 0 or not buff_info) then
            ICON_USE(next_skill_info.icon)
            if not session.GetSkill(next_skill_info.skill_id) then
                table.remove(g.battle_ritual_use_queue, 1)
            end
            local changed_image = QUICKSLOT_CHANGE_ICON_LIST[tostring(next_skill_info.skill_id)]
            if changed_image then
                table.remove(g.battle_ritual_use_queue, 1)
            end
            return 1
        end
        if #g.battle_ritual_use_queue > 0 then
            table.remove(g.battle_ritual_use_queue, 1)
            return 1
        else
            return 0
        end
    end)
    if not status then
        return 0 -- エラー時は停止
    end
    return result
end

--[[function Battle_ritual_auto_buff_skill_start()
    if g.battle_ritual_settings.etc.use == 0 then
        return
    end
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    local list = session.party.GetPartyMemberList(PARTY_NORMAL)
    if list:Count() > 1 then
        _nexus_addons_p:StopUpdateScript("Battle_ritual_auto_buff_skill")
        return
    end
    local skills_table = g.battle_ritual_settings.skills
    if not skills_table then
        return
    end
    local sorted_list = {}
    for s_id, data in pairs(skills_table) do
        table.insert(sorted_list, {
            skill_id = tonumber(s_id),
            buff_id = data.buff_id,
            priority = data.priority
        })
    end
    table.sort(sorted_list, function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority
        else
            return tonumber(a.skill_id) < tonumber(b.skill_id)
        end
    end)
    local skill_map = {}
    for i = 0, 40 - 1 do
        local quick_slot_info = quickslot.GetInfoByIndex(i)
        if quick_slot_info and quick_slot_info.category == 'Skill' then
            skill_map[quick_slot_info.type] = i
        end
    end
    g.battle_ritual_use_queue = {}
    local my_handle = session.GetMyHandle()
    local quickslotnexpbar = ui.GetFrame("quickslotnexpbar")
    for _, data in ipairs(sorted_list) do
        local skill_id = data.skill_id
        local slot_index = skill_map[skill_id]
        if slot_index then
            local slot = GET_CHILD_RECURSIVELY(quickslotnexpbar, "slot" .. (slot_index + 1), "ui::CSlot")
            if slot then
                local icon = slot:GetIcon()
                if icon then
                    local cur_time = ICON_UPDATE_SKILL_COOLDOWN(icon)
                    if cur_time == 0 then
                        local buff_id = data.buff_id
                        local need_buff = true
                        if buff_id > 0 then
                            if info.GetBuff(my_handle, buff_id) then
                                need_buff = false
                            end
                        end
                        if need_buff then
                            table.insert(g.battle_ritual_use_queue, {
                                buff_id = buff_id,
                                skill_id = skill_id,
                                icon = icon
                            })
                        end
                    end
                end
            end
        end
    end
    if #g.battle_ritual_use_queue > 0 then
        _nexus_addons_p:RunUpdateScript("Battle_ritual_auto_buff_skill", 0.1)
    end
end

function Battle_ritual_auto_buff_skill(_nexus_addons_p)
    if not g.battle_ritual_use_queue or #g.battle_ritual_use_queue == 0 then
        return 0
    end
    local next_skill_info = g.battle_ritual_use_queue[1]
    if not next_skill_info or not next_skill_info.icon then
        table.remove(g.battle_ritual_use_queue, 1)
        return 1
    end
    local my_handle = session.GetMyHandle()
    local buff_info = nil
    if next_skill_info.buff_id and next_skill_info.buff_id > 0 then
        buff_info = info.GetBuff(my_handle, next_skill_info.buff_id)
    end
    local current_cooldown = ICON_UPDATE_SKILL_COOLDOWN(next_skill_info.icon)
    if current_cooldown == 0 and (next_skill_info.buff_id == 0 or not buff_info) then
        ICON_USE(next_skill_info.icon)
        local changed_image = QUICKSLOT_CHANGE_ICON_LIST[tostring(next_skill_info.skill_id)]
        if changed_image then
            table.remove(g.battle_ritual_use_queue, 1)
        end
        return 1
    end
    if #g.battle_ritual_use_queue > 0 then
        table.remove(g.battle_ritual_use_queue, 1)
        return 1
    else
        return 0
    end
end]]

function Battle_ritual_frame_init()
    local Battle_ritual = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "Battle_ritual", 0, 0, 0, 0)
    AUTO_CAST(Battle_ritual)
    Battle_ritual:SetSkinName("None")
    Battle_ritual:SetTitleBarSkin("None")
    Battle_ritual:Resize(40, 30)
    Battle_ritual:SetGravity(ui.RIGHT, ui.TOP)
    Battle_ritual:EnableMove(g.battle_ritual_settings.etc.move == 1 and 0 or 1)
    Battle_ritual:EnableHittestFrame(1)
    local rect = Battle_ritual:GetMargin()
    Battle_ritual:SetMargin(rect.left - rect.left, rect.top - rect.top + 2,
        rect.right == 0 and rect.right + 305 or rect.right, rect.bottom)
    if g.battle_ritual_settings.etc.x ~= 0 and g.battle_ritual_settings.etc.y ~= 0 then
        Battle_ritual:SetPos(g.battle_ritual_settings.etc.x, g.battle_ritual_settings.etc.y)
    end
    Battle_ritual:SetEventScript(ui.LBUTTONUP, "Battle_ritual_frame_location_save")
    local pic = Battle_ritual:CreateOrGetControl("picture", "pic", 0, 0, 30, 30)
    AUTO_CAST(pic)
    pic:SetImage("emoticon_0015")
    pic:SetColorTone("FFFFFFFF")
    pic:SetEnableStretch(1)
    pic:EnableHitTest(1)
    pic:SetGravity(ui.LEFT, ui.TOP)
    pic:SetTextTooltip(g.lang == "Japanese" and "{ol}Battle Ritual{nl}右クリック ON/OFF" or
                           "{ol}Battle Ritual{nl}Right click ON/OFF")
    if g.battle_ritual_settings.etc.use == 0 then
        pic:SetColorTone("FF555555")
    else
        pic:SetColorTone("FFFFFFFF")
    end
    pic:SetEventScript(ui.RBUTTONUP, "Battle_ritual_onoff_switch")
    Battle_ritual:ShowWindow(1)
end

function Battle_ritual_onoff_switch(Battle_ritual)
    g.battle_ritual_settings.etc.use = 1 - g.battle_ritual_settings.etc.use
    Battle_ritual_save_settings()
    Battle_ritual_frame_init()
end

function Battle_ritual_frame_location_save(Battle_ritual)
    g.battle_ritual_settings.etc.x = Battle_ritual:GetX()
    g.battle_ritual_settings.etc.y = Battle_ritual:GetY()
    Battle_ritual_save_settings()
end

function Battle_ritual_settings_frame()
    local list_frame = ui.GetFrame(addon_name_lower .. "list_frame")
    local setting = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "Battle_ritual_setting", 0, 0, 0, 0)
    setting:SetPos(list_frame:GetX() + list_frame:GetWidth(), list_frame:GetY())
    setting:SetSkinName("test_frame_low")
    setting:EnableHittestFrame(1)
    setting:EnableHitTest(1)
    setting:SetLayerLevel(999)
    setting:RemoveAllChild()
    local title_text = setting:CreateOrGetControl('richtext', 'title_text', 20, 15, 50, 30)
    AUTO_CAST(title_text)
    title_text:SetText("{ol}Battle ritual Config")
    local close = setting:CreateOrGetControl("button", "close", 0, 0, 20, 20)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Battle_ritual_frame_close")
    local gbox = setting:CreateOrGetControl("groupbox", "gbox", 10, 40, setting:GetWidth() - 20,
        setting:GetHeight() - 50) -- 945
    AUTO_CAST(gbox)
    gbox:SetSkinName("test_frame_midle_light")
    gbox:EnableScrollBar(1)
    Battle_ritual_settings_frame_child(setting, gbox)
end

function Battle_ritual_settings_frame_child(setting, gbox) -- gbox:EnableScrollBar(0)
    local move_check = gbox:CreateOrGetControl('checkbox', "move_check", 10, 10, 30, 30)
    AUTO_CAST(move_check)
    move_check:SetCheck(g.battle_ritual_settings.etc.move)
    move_check:SetText(g.lang == "Japanese" and "{ol}チェックするとフレーム固定" or
                           "{ol}If checked, the frame is fixed")
    move_check:SetEventScript(ui.LBUTTONUP, "Battle_ritual_frame_move")
    local default_btn = gbox:CreateOrGetControl("button", "default_btn", move_check:GetWidth() + 30, 10, 120, 30)
    AUTO_CAST(default_btn)
    default_btn:SetText(g.lang == "Japanese" and "{ol}フレーム初期位置" or "{ol}Init frame pos")
    default_btn:SetEventScript(ui.LBUTTONUP, "Battle_ritual_frame_default")
    local skill_lbl = gbox:CreateOrGetControl('richtext', 'header_skill', 10, 45, 100, 20)
    AUTO_CAST(skill_lbl)
    skill_lbl:SetText(g.lang == "Japanese" and "{ol}スキル" or "{ol}Skill")
    local buff_lbl = gbox:CreateOrGetControl('richtext', 'header_buff', 230, 45, 100, 20)
    AUTO_CAST(buff_lbl)
    buff_lbl:SetText(g.lang == "Japanese" and "{ol}バフ" or "{ol}Buff")
    local priority_lbl = gbox:CreateOrGetControl('richtext', 'header_priority', 450, 45, 100, 20)
    AUTO_CAST(priority_lbl)
    priority_lbl:SetText(g.lang == "Japanese" and "{ol}優先度" or "{ol}Priority")
    local y_pos = 70
    local row_height = 40
    local sorted_skills = {}
    if g.battle_ritual_settings.skills then
        for s_id, data in pairs(g.battle_ritual_settings.skills) do
            table.insert(sorted_skills, {
                skill_id = tonumber(s_id),
                buff_id = data.buff_id or 0,
                priority = data.priority or 0
            })
        end
    end
    table.sort(sorted_skills, function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority
        else
            return a.skill_id < b.skill_id
        end
    end)
    for i, entry in ipairs(sorted_skills) do
        Battle_ritual_create_row(gbox, i, entry.skill_id, entry.buff_id, entry.priority, y_pos)
        y_pos = y_pos + row_height
    end
    Battle_ritual_create_row(gbox, #sorted_skills + 1, 0, 0, 0, y_pos)
end

function Battle_ritual_frame_default(parent)
    ui.DestroyFrame(addon_name_lower .. "Battle_ritual")
    g.battle_ritual_settings.etc.x = 0
    g.battle_ritual_settings.etc.y = 0
    Battle_ritual_save_settings()
    ReserveScript("Battle_ritual_frame_init()", 0.1)
end

function Battle_ritual_frame_move(Battle_ritual, gbox)
    g.battle_ritual_settings.etc.move = 1 - g.battle_ritual_settings.etc.move
    Battle_ritual_save_settings()
    Battle_ritual_frame_init()
end

function Battle_ritual_create_row(gbox, index, skill_id, buff_id, priority, y)
    local skill_add = gbox:CreateOrGetControl("button", "skill_add_" .. index, 10, y, 50, 30)
    AUTO_CAST(skill_add)
    skill_add:SetSkinName("test_cardtext_btn")
    skill_add:SetText("{ol}Add")
    skill_add:SetTextTooltip(g.lang == "Japanese" and "{ol}スキルリスト表示" or "{ol}Display the skill list")
    skill_add:SetEventScript(ui.LBUTTONUP, "Battle_ritual_skill_list_open")
    skill_add:SetEventScriptArgNumber(ui.LBUTTONUP, index)
    local skill_pic = gbox:CreateOrGetControl('picture', "skill_pic_" .. index, 65, y, 30, 30)
    AUTO_CAST(skill_pic)
    local skill_img = ""
    if skill_id > 0 then
        local cls = GetClassByType("Skill", skill_id)
        if cls then
            skill_img = "icon_" .. cls.Icon
        end
    end
    skill_pic:SetImage(skill_img)
    skill_pic:SetEnableStretch(1)
    skill_pic:EnableHitTest(1)
    if skill_id > 0 then
        SET_SKILL_TOOLTIP_BY_TYPE(skill_pic, skill_id)
    end
    local skill_edit = gbox:CreateOrGetControl('edit', 'skill_edit_' .. index, 100, y, 80, 30)
    AUTO_CAST(skill_edit)
    skill_edit:SetNumberMode(1)
    skill_edit:SetFontName("white_16_ol")
    skill_edit:SetText(skill_id == 0 and "" or skill_id)
    skill_edit:SetTextAlign("center", "center")
    skill_edit:SetTextTooltip(g.lang == "Japanese" and "{ol}スキルID入力{nl}錬成スキルは141001～" or
                                  "{ol}Enter the Skill ID.{nl}Alchemic skills start from 141001")
    if skill_edit:GetText() ~= "" then
        skill_edit:SetUserValue("ORIG_SKILL_ID", skill_id)
    end
    skill_edit:SetTypingScp("Battle_ritual_add_skill")
    local skill_remove = gbox:CreateOrGetControl("button", "skill_remove_" .. index, 185, y, 30, 30)
    AUTO_CAST(skill_remove)
    skill_remove:SetSkinName("test_cardtext_btn")
    skill_remove:SetText("{ol}×")
    skill_remove:SetTextTooltip(g.lang == "Japanese" and "{ol}登録解除" or "{ol}unregister")
    skill_remove:SetEventScript(ui.LBUTTONUP, "Battle_ritual_remove")
    skill_remove:SetEventScriptArgString(ui.LBUTTONUP, tostring(skill_id))
    if skill_id > 0 then
        local buff_add = gbox:CreateOrGetControl("button", "buff_add_" .. index, 230, y, 50, 30)
        AUTO_CAST(buff_add)
        buff_add:SetSkinName("test_cardtext_btn")
        buff_add:SetText("{ol}Add")
        buff_add:SetTextTooltip(g.lang == "Japanese" and "{ol}バフリスト表示" or "{ol}Display the buff list")
        buff_add:SetEventScript(ui.LBUTTONUP, "Battle_ritual_buff_list_open")
        buff_add:SetEventScriptArgNumber(ui.LBUTTONUP, skill_id)
        gbox:SetUserValue("INDEX", index)
        local buff_pic = gbox:CreateOrGetControl('picture', "buff_pic_" .. index, 285, y, 30, 30)
        AUTO_CAST(buff_pic)
        local buff_img = ""
        if buff_id > 0 then
            local cls = GetClassByType("Buff", buff_id)
            if cls then
                buff_img = "icon_" .. cls.Icon
            end
        end
        buff_pic:SetImage(buff_img)
        buff_pic:SetEnableStretch(1)
        buff_pic:EnableHitTest(1)
        local buff_edit = gbox:CreateOrGetControl('edit', 'buff_edit_' .. index, 320, y, 80, 30)
        AUTO_CAST(buff_edit)
        buff_edit:SetNumberMode(1)
        buff_edit:SetFontName("white_16_ol")
        buff_edit:SetText(buff_id == 0 and "" or buff_id)
        buff_edit:SetTextAlign("center", "center")
        buff_edit:SetTextTooltip(g.lang == "Japanese" and
                                     "{ol}バフID入力{nl}対応バフが無い場合は 空白{nl}(例)テンペストショットは 空白{nl}ダブルアタックは 322など{nl}※入力無しは毎回掛け直し" or
                                     "{ol}Enter the Buff ID{nl}Leave blank if there is no corresponding buff{nl}(e.g.)Tempest Shot is blank{nl}Double Attack is 322, etc.{nl}※If no input is provided,will be recast every time")
        buff_edit:SetUserValue("SKILL_ID", skill_id)

        buff_edit:SetTypingScp("Battle_ritual_add_buff")
        local buff_remove = gbox:CreateOrGetControl("button", "buff_remove" .. index, 405, y, 30, 30)
        AUTO_CAST(buff_remove)
        buff_remove:SetSkinName("test_cardtext_btn")
        buff_remove:SetText("{ol}×")
        buff_remove:SetTextTooltip(g.lang == "Japanese" and "{ol}登録解除" or "{ol}unregister")
        buff_remove:SetEventScript(ui.LBUTTONUP, "Battle_ritual_remove")
        buff_remove:SetEventScriptArgString(ui.LBUTTONUP, tostring(skill_id))
        local priority_edit = gbox:CreateOrGetControl('edit', 'priority_edit_' .. index, 450, y, 50, 30)
        AUTO_CAST(priority_edit)
        priority_edit:SetNumberMode(1)
        priority_edit:SetFontName("white_16_ol")
        priority_edit:SetText(priority)
        priority_edit:SetTextAlign("center", "center")
        priority_edit:SetTextTooltip(g.lang == "Japanese" and "{ol}優先度入力" or "{ol}Enter Priority")
        priority_edit:SetUserValue("SKILL_ID", skill_id)
        priority_edit:SetTypingScp("Battle_ritual_priority")
    end
    local setting = gbox:GetParent()
    setting:Resize(550, 945)
    gbox:Resize(setting:GetWidth() - 20, 895) -- 945
    setting:ShowWindow(1)
end

function Battle_ritual_priority_change(ctrl)
    local new_priority = tonumber(ctrl:GetText())
    local skill_id_str = ctrl:GetUserValue("SKILL_ID")
    local skills = g.battle_ritual_settings.skills
    if skills and skills[skill_id_str] then
        for s_id, data in pairs(skills) do
            if s_id ~= skill_id_str and data.priority >= new_priority then
                data.priority = data.priority + 1
            end
        end
        skills[skill_id_str].priority = new_priority
    end
    Battle_ritual_save_settings()
    Battle_ritual_settings_frame()
    return 0
end

function Battle_ritual_priority(parent, ctrl)
    local priority = tonumber(ctrl:GetText())
    if priority > 0 then
        ctrl:RunUpdateScript("Battle_ritual_priority_change", 0.5)
    end
end

function Battle_ritual_remove(parent, ctrl, skill_id_str)
    local ctrl_name = ctrl:GetName()
    if string.find(ctrl_name, "skill") then
        g.battle_ritual_settings.skills[skill_id_str] = nil
    else
        g.battle_ritual_settings.skills[skill_id_str].buff_id = 0
    end
    Battle_ritual_save_settings()
    Battle_ritual_settings_frame()
end

function Battle_ritual_skill_list_open(frame, add, ctrl_text, index)
    local skill_list = ui.GetFrame(addon_name_lower .. "Battle_ritual_skill_list")
    if not skill_list then
        skill_list = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "Battle_ritual_skill_list", 0, 0, 10, 10)
        AUTO_CAST(skill_list)
        skill_list:SetSkinName("test_frame_low")
        skill_list:Resize(500, 1005)
        skill_list:SetPos(720, 30)
        skill_list:SetLayerLevel(999)
        local title_text = skill_list:CreateOrGetControl('richtext', 'title_text', 15, 15, 10, 30)
        AUTO_CAST(title_text)
        title_text:SetText("{#000000}{s20}Skill List")
        local search_edit =
            skill_list:CreateOrGetControl("edit", "search_edit", title_text:GetWidth() + 30, 10, 305, 38)
        AUTO_CAST(search_edit)
        search_edit:SetFontName("white_18_ol")
        search_edit:SetTextAlign("left", "center")
        search_edit:SetSkinName("inventory_serch")
        search_edit:SetEventScript(ui.ENTERKEY, "Battle_ritual_skill_list_search")
        search_edit:SetEventScriptArgNumber(ui.ENTERKEY, index)
        local search_btn = search_edit:CreateOrGetControl("button", "search_btn", 0, 0, 40, 38)
        AUTO_CAST(search_btn)
        search_btn:SetImage("inven_s")
        search_btn:SetGravity(ui.RIGHT, ui.TOP)
        search_btn:SetEventScript(ui.LBUTTONUP, "Battle_ritual_skill_list_search")
        local close_button = skill_list:CreateOrGetControl('button', 'close_button', 0, 0, 20, 20)
        AUTO_CAST(close_button)
        close_button:SetImage("testclose_button")
        close_button:SetGravity(ui.RIGHT, ui.TOP)
        close_button:SetEventScript(ui.LBUTTONUP, "Battle_ritual_frame_close")
    end
    local skill_gb = skill_list:CreateOrGetControl("groupbox", "skill_gb", 10, 50, 480, skill_list:GetHeight() - 60)
    AUTO_CAST(skill_gb)
    skill_gb:SetSkinName("bg")
    skill_gb:RemoveAllChild()
    local cls_list, count = GetClassList("Skill")
    local y = 0
    for i = 0, count - 1 do
        local skill_cls = GetClassByIndexFromList(cls_list, i)
        if skill_cls then
            local skill_id = skill_cls.ClassID
            local skill_cls_name = skill_cls.ClassName
            local skill_engname = skill_cls.EngName
            local skill_caption = skill_cls.Caption
            local skill_name = dictionary.ReplaceDicIDInCompStr(skill_cls.Name)
            if ctrl_text == "" or (ctrl_text ~= "" and string.find(skill_name, ctrl_text)) then
                local skill_slot = skill_gb:CreateOrGetControl('slot', 'skill_slot' .. i, 10, y + 5, 30, 30)
                AUTO_CAST(skill_slot)
                local image_name = "icon_" .. skill_cls.Icon
                if skill_id > 10000 then
                    if not string.find(skill_cls_name, "^Mon_") and not string.find(skill_engname, "plzInputEngName") and
                        not string.find(skill_name, "_") and not string.find(skill_name, "TEST") then
                        if ctrl_text == "" or (ctrl_text ~= "" and string.find(skill_name, ctrl_text)) then
                            SET_SLOT_IMG(skill_slot, image_name)
                            local icon = CreateIcon(skill_slot)
                            AUTO_CAST(icon)
                            SET_SKILL_TOOLTIP_BY_TYPE(icon, skill_id)
                            local skill_set = skill_gb:CreateOrGetControl('button', 'skill_set' .. skill_id, 45, y + 5,
                                40, 30)
                            AUTO_CAST(skill_set)
                            skill_set:SetText("{ol}Add")
                            skill_set:SetSkinName("test_cardtext_btn")
                            skill_set:SetTextTooltip(g.lang == "Japanese" and "{ol}スキル追加" or "{ol}Add Skill")
                            skill_set:SetEventScript(ui.LBUTTONUP, "Battle_ritual_add_skill")
                            skill_set:SetEventScriptArgString(ui.LBUTTONUP, skill_id)
                            skill_set:SetEventScriptArgNumber(ui.LBUTTONUP, index)
                            local skill_text = skill_gb:CreateOrGetControl('richtext', 'skill_text' .. skill_id, 90,
                                y + 10, 200, 30)
                            AUTO_CAST(skill_text)
                            skill_text:SetText("{ol}" .. skill_id .. " : " .. skill_name)
                            skill_text:AdjustFontSizeByWidth(380)
                            y = y + 35
                        end
                    end
                end
            end
        end

    end
    skill_list:ShowWindow(1)
end

function Battle_ritual_skill_list_search(frame, ctrl, str, index)
    local search_edit = GET_CHILD_RECURSIVELY(frame, "search_edit")
    local ctrl_text = search_edit:GetText()
    if ctrl_text ~= "" then
        Battle_ritual_skill_list_open(frame, ctrl, ctrl_text, index)
    else
        Battle_ritual_skill_list_open(frame, ctrl, "", index)
    end
end

function Battle_ritual_add_skill(parent, ctrl, skill_id_str, index)
    local ctrl_name = ctrl:GetName()
    if string.find(ctrl_name, "skill_edit_") then
        ctrl:RunUpdateScript("Battle_ritual_setting_change_skill_edit", 0.5)
    else
        local setting = ui.GetFrame(addon_name_lower .. "Battle_ritual_setting")
        local skill_edit = GET_CHILD_RECURSIVELY(setting, "skill_edit_" .. index)
        skill_edit:SetText(skill_id_str)
        ctrl:SetUserValue("SKILL_ID", skill_id_str)
        Battle_ritual_setting_change_skill_edit(ctrl)
    end
end

function Battle_ritual_setting_change_skill_edit(ctrl)
    local user_val = ctrl:GetUserValue("SKILL_ID")
    local new_id_str = (user_val == "None" or user_val == "") and ctrl:GetText() or user_val
    local orig_id_str = ctrl:GetUserValue("ORIG_SKILL_ID")
    local skills = g.battle_ritual_settings.skills
    local new_skill_cls = GetClassByType("Skill", tonumber(new_id_str))
    if not new_skill_cls then
        if skills[orig_id_str] then
            skills[orig_id_str] = nil
            Battle_ritual_save_settings()
        end
        Battle_ritual_settings_frame()
        return 0
    end
    if not skills[new_id_str] then
        local new_data = {
            priority = 0,
            buff_id = 0
        }
        local old_data = skills[orig_id_str]
        if old_data then
            new_data.priority = old_data.priority
            skills[orig_id_str] = nil
        else
            local max_priority = 0
            for _, data in pairs(skills) do
                if data.priority and data.priority > max_priority then
                    max_priority = data.priority
                end
            end
            new_data.priority = max_priority + 1
        end
        skills[new_id_str] = new_data
        Battle_ritual_save_settings()
        Battle_ritual_settings_frame()
    end
    return 0
end

function Battle_ritual_buff_list_open(frame, ctrl, ctrl_text, skill_id)
    local buff_list = ui.GetFrame(addon_name_lower .. "Battle_ritual_buff_list")
    if not buff_list then
        buff_list = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "Battle_ritual_buff_list", 0, 0, 10, 10)
        AUTO_CAST(buff_list)
        buff_list:SetSkinName("test_frame_low")
        buff_list:Resize(500, 1005)
        buff_list:SetPos(720, 30)
        buff_list:SetLayerLevel(999)
        local title_text = buff_list:CreateOrGetControl('richtext', 'title_text', 15, 15, 10, 30)
        AUTO_CAST(title_text)
        title_text:SetText("{#000000}{s20}Buff List")
        local search_edit = buff_list:CreateOrGetControl("edit", "search_edit", title_text:GetWidth() + 30, 10, 305, 38)
        AUTO_CAST(search_edit)
        search_edit:SetFontName("white_18_ol")
        search_edit:SetTextAlign("left", "center")
        search_edit:SetSkinName("inventory_serch")
        search_edit:SetEventScript(ui.ENTERKEY, "Battle_ritual_buff_list_search")
        search_edit:SetEventScriptArgNumber(ui.ENTERKEY, skill_id)
        local search_btn = search_edit:CreateOrGetControl("button", "search_btn", 0, 0, 40, 38)
        AUTO_CAST(search_btn)
        search_btn:SetImage("inven_s")
        search_btn:SetGravity(ui.RIGHT, ui.TOP)
        search_btn:SetEventScript(ui.LBUTTONUP, "Battle_ritual_buff_list_search")
        search_btn:SetEventScriptArgNumber(ui.LBUTTONUP, skill_id)
        local close_button = buff_list:CreateOrGetControl('button', 'close_button', 0, 0, 20, 20)
        AUTO_CAST(close_button)
        close_button:SetImage("testclose_button")
        close_button:SetGravity(ui.RIGHT, ui.TOP)
        close_button:SetEventScript(ui.LBUTTONUP, "Battle_ritual_frame_close")
    end
    local buff_list_gb = buff_list:CreateOrGetControl("groupbox", "buff_list_gb", 10, 50, 480,
        buff_list:GetHeight() - 60)
    AUTO_CAST(buff_list_gb)
    buff_list_gb:SetSkinName("bg")
    buff_list_gb:RemoveAllChild()
    local cls_list, count = GetClassList("Buff")
    local y = 0
    for i = 0, count - 1 do
        local buff_cls = GetClassByIndexFromList(cls_list, i)
        if buff_cls then
            local buff_id = buff_cls.ClassID
            local buff_name = dictionary.ReplaceDicIDInCompStr(buff_cls.Name)
            if ctrl_text == "" or (ctrl_text ~= "" and string.find(buff_name, ctrl_text)) then
                local buff_slot = buff_list_gb:CreateOrGetControl('slot', 'buffslot' .. i, 10, y + 5, 30, 30)
                AUTO_CAST(buff_slot)
                local image_name = GET_BUFF_ICON_NAME(buff_cls)
                if image_name == "icon_None" then
                    image_name = "icon_item_nothing"
                end
                if buff_name ~= "None" then
                    SET_SLOT_IMG(buff_slot, image_name)
                    local icon = CreateIcon(buff_slot)
                    AUTO_CAST(icon)
                    icon:SetTooltipType('buff')
                    icon:SetTooltipArg(buff_name, buff_id, 0)
                    local buff_set = buff_list_gb:CreateOrGetControl('button', 'buff_set' .. buff_id, 45, y + 5, 40, 30)
                    AUTO_CAST(buff_set)
                    buff_set:SetText("{ol}Add")
                    buff_set:SetSkinName("test_cardtext_btn")
                    buff_set:SetTextTooltip(g.lang == "Japanese" and "{ol}バフ追加" or "{ol}Add Buff")
                    buff_set:SetEventScript(ui.LBUTTONUP, "Battle_ritual_add_buff")
                    buff_set:SetEventScriptArgString(ui.LBUTTONUP, buff_id)
                    buff_set:SetEventScriptArgNumber(ui.LBUTTONUP, skill_id)
                    local buff_text = buff_list_gb:CreateOrGetControl('richtext', 'buff_text' .. buff_id, 90, y + 10,
                        200, 30)
                    AUTO_CAST(buff_text)
                    buff_text:SetText("{ol}" .. buff_id .. " : " .. buff_name)
                    buff_text:AdjustFontSizeByWidth(380)
                    y = y + 35
                end
            end
        end
    end
    buff_list:ShowWindow(1)
end

function Battle_ritual_buff_list_search(frame, ctrl, str, skill_id)
    local search_edit = GET_CHILD_RECURSIVELY(frame, "search_edit")
    local ctrl_text = search_edit:GetText()
    if ctrl_text ~= "" then
        Battle_ritual_buff_list_open(frame, ctrl, ctrl_text, skill_id)
    else
        Battle_ritual_buff_list_open(frame, ctrl, "", skill_id)
    end
end

function Battle_ritual_add_buff(parent, ctrl, buff_id_str, skill_id)
    local ctrl_name = ctrl:GetName()
    if string.find(ctrl_name, "buff_edit") then
        ctrl:SetUserValue("BUFF_ID", tonumber(ctrl:GetText()))
        ctrl:RunUpdateScript("Battle_ritual_setting_change_buff_edit", 0.5)
    else
        local buff_cls = GetClassByType("Buff", tonumber(buff_id_str))
        local s_id_str = tostring(skill_id)
        if g.battle_ritual_settings.skills[s_id_str] then
            if buff_cls then
                g.battle_ritual_settings.skills[s_id_str].buff_id = tonumber(buff_id_str)
            else
                g.battle_ritual_settings.skills[s_id_str].buff_id = 0
            end
            Battle_ritual_save_settings()
            Battle_ritual_settings_frame()
        end
    end
end

function Battle_ritual_setting_change_buff_edit(ctrl)
    local buff_id = ctrl:GetUserIValue("BUFF_ID")
    local skill_id_str = ctrl:GetUserValue("SKILL_ID")
    if g.battle_ritual_settings.skills[skill_id_str] then
        local buff_cls = GetClassByType("Buff", buff_id)
        if not buff_cls then
            g.battle_ritual_settings.skills[skill_id_str].buff_id = 0
        else
            g.battle_ritual_settings.skills[skill_id_str].buff_id = buff_id
        end
    end
    Battle_ritual_save_settings()
    Battle_ritual_settings_frame()
end

function Battle_ritual_frame_close(frame)
    ui.DestroyFrame(frame:GetName())
    if frame:GetName() == addon_name_lower .. "Battle_ritual_setting" then
        ui.DestroyFrame(addon_name_lower .. "Battle_ritual_skill_list")
        ui.DestroyFrame(addon_name_lower .. "Battle_ritual_buff_list")
    end
end

function Battle_ritual_REQ_PLAYER_CONTENTS_RECORD(frame, type)
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    _nexus_addons_p:RunUpdateScript("Battle_ritual_overlord_off", 0.1)
end

function Battle_ritual_overlord_off(_nexus_addons_p)
    local buff = info.GetBuff(session.GetMyHandle(), 40049)
    if not buff then
        return 0
    end
    local quickslotnexpbar = ui.GetFrame("quickslotnexpbar")
    for i = 1, 40 do
        local slot = GET_CHILD_RECURSIVELY(quickslotnexpbar, "slot" .. i)
        AUTO_CAST(slot)
        local icon = slot:GetIcon()
        if icon then
            AUTO_CAST(icon)
            local icon_info = icon:GetInfo()
            if icon_info then
                local category = icon_info:GetCategory()
                if category == "Skill" then
                    local buff_id = icon_info.type
                    if buff_id == 100085 then
                        local current_cooldown = ICON_UPDATE_SKILL_COOLDOWN(icon)
                        if current_cooldown == 0 then
                            control.Skill(buff_id)
                        end
                        return 1
                    end
                end
            end
        end
    end
end
-- Battle_ritual ここまで

