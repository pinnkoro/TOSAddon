-- sub_slotset ここから
function Sub_slotset_save_settings()
    g.save_json(g.sub_slotset_path, g.sub_slotset_settings)
end

function Sub_slotset_load_settings()
    g.sub_slotset_path = string.format("../addons/%s/%s/sub_slotset.json", addon_name_lower, g.active_id)
    g.sub_slotset_old_path = string.format("../addons/%s/%s/settings.json", "sub_slotset", g.active_id)
    local settings = g.load_json(g.sub_slotset_path)
    if not settings then
        settings = {
            config = {
                index = 0
            },
            share = {},
            personal = {}
        }
        local old_settings = g.load_json(g.sub_slotset_old_path)
        if old_settings then
            for ss_name, data in pairs(old_settings) do
                if string.find(ss_name, "sub_slotset_") then
                    if data.etc then
                        data.etc.x = data.etc.X
                        data.etc.y = data.etc.Y
                        data.etc.col = data.etc.column
                        data.etc.X = nil
                        data.etc.Y = nil
                        data.etc.column = nil
                    end
                    settings.share["sub_slotset_" .. settings.config.index] = data
                    settings.config.index = settings.config.index + 1
                end
            end
        end
    end
    g.sub_slotset_settings = settings
    Sub_slotset_save_settings()
end

function Sub_slotset_char_load_settings()
    g.sub_slotset_old_personal_path = string.format("../addons/%s/%s.json", "sub_slotset", g.cid)
    if not g.sub_slotset_settings.personal[g.cid] then
        g.sub_slotset_settings.personal[g.cid] = {}
        local old_personal_settings = g.load_json(g.sub_slotset_old_personal_path)
        if old_personal_settings then
            for ss_name, data in pairs(old_personal_settings) do
                if string.find(ss_name, "sub_slotset_") then
                    if data.etc then
                        data.etc.x = data.etc.X
                        data.etc.y = data.etc.Y
                        data.etc.col = data.etc.column
                        data.etc.X = nil
                        data.etc.Y = nil
                        data.etc.column = nil
                    end
                    local new_index = g.sub_slotset_settings.config.index
                    g.sub_slotset_settings.personal[g.cid]["sub_slotset_" .. new_index] = data
                    g.sub_slotset_settings.config.index = new_index + 1
                end
            end
        end
        Sub_slotset_save_settings()
    end
end

function sub_slotset_on_init()
    if not g.sub_slotset_settings then
        Sub_slotset_load_settings()
    end
    local old_func = g.settings.sub_slotset.old_init_func
    if _G[old_func] then
        return
    end
    if not g.sub_slotset_settings.personal[g.cid] then
        Sub_slotset_char_load_settings()
    end
    g.setup_hook_and_event(g.addon, "SET_QUEST_CTRL_TEXT", "Sub_slotset_SET_QUEST_CTRL_TEXT", true)
    g.setup_hook_and_event(g.addon, "EMO_OPEN", "Sub_slotset_EMO_OPEN", true)
    if g.settings.sub_slotset.use == 0 then
        if g.sub_slotset_settings.share then
            for ss_name, data in pairs(g.sub_slotset_settings.share) do
                ui.DestroyFrame(addon_name_lower .. ss_name)
            end
        end
        if g.sub_slotset_settings.personal[g.cid] then
            for ss_name, data in pairs(g.sub_slotset_settings.personal[g.cid]) do
                ui.DestroyFrame(addon_name_lower .. ss_name)
            end
        end
        return
    end
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    _nexus_addons_p:RunUpdateScript("Sub_slotset_frame_init", 0.1)
end

function Sub_slotset_EMO_OPEN(my_frame, my_msg)
    if g.settings.sub_slotset.use == 0 then
        return
    end
    local button = g.get_event_args(my_msg)
    local chat_emoticon = ui.GetFrame("chat_emoticon")
    local group_name = chat_emoticon:GetUserValue("EMOTICON_GROUP")
    if group_name == "None" then
        group_name = "Normal"
    end
    local emoticons = GET_CHILD_RECURSIVELY(chat_emoticon, "emoticons")
    local slot_count = emoticons:GetSlotCount()
    local count = 0
    for i = 1, slot_count do
        local slot = GET_CHILD_RECURSIVELY(emoticons, "slot" .. i)
        local icon = slot:GetIcon()
        if icon then
            count = count + 1
        end
    end
    local gbox = GET_CHILD_RECURSIVELY(chat_emoticon, "gbox")
    gbox:RemoveAllChild()
    local emoticons = gbox:CreateOrGetControl('slotset', 'emoticons', 0, 0, 420, 0)
    AUTO_CAST(emoticons)
    emoticons:SetSlotSize(42, 42)
    emoticons:EnablePop(1)
    emoticons:EnableDrag(1)
    emoticons:EnableDrop(0)
    emoticons:EnableHitTest(1)
    emoticons:SetColRow(10, math.ceil(count / 10))
    emoticons:SetSpc(0, 0)
    emoticons:SetSkinName('invenslot')
    emoticons:CreateSlots()
    for i = 0, count - 1 do
        local slot = emoticons:GetSlotByIndex(i)
        AUTO_CAST(slot)
        local icon = CreateIcon(slot)
        slot:SetEventScript(ui.LBUTTONDOWN, "CHAT_EMOTICON_SELECT")
    end
    CHAT_EMOTICON_MAKELIST(chat_emoticon)
end

function Sub_slotset_SET_QUEST_CTRL_TEXT(my_frame, my_msg)
    if g.settings.sub_slotset.use == 0 then
        return
    end
    local quest_ctrl, quest_ies = g.get_event_args(my_msg)
    AUTO_CAST(quest_ctrl)
    --[[local nametxt = GET_CHILD(quest_ctrl, "name", "ui::CRichText")
    AUTO_CAST(nametxt)]]
    local leveltxt = GET_CHILD(quest_ctrl, "level", "ui::CRichText")
    AUTO_CAST(leveltxt)
    --[[local font = ""
    local color = ""
    if quest_ies.QuestMode == "MAIN" then
        font = quest_ctrl:GetUserConfig("MAIN_FONT")
        color = quest_ctrl:GetUserConfig("MAIN_COLOR")
    elseif quest_ies.QuestMode == "SUB" then
        font = quest_ctrl:GetUserConfig("SUB_FONT")
        color = quest_ctrl:GetUserConfig("SUB_COLOR")
    elseif quest_ies.QuestMode == "REPEAT" then
        font = quest_ctrl:GetUserConfig("REPEAT_FONT")
        color = quest_ctrl:GetUserConfig("REPEAT_COLOR")
    elseif quest_ies.QuestMode == "PARTY" then
        font = quest_ctrl:GetUserConfig("PARTY_FONT")
        color = quest_ctrl:GetUserConfig("PARTY_COLOR")
    elseif quest_ies.QuestMode == "KEYITEM" then
        font = quest_ctrl:GetUserConfig("KEYITEM_FONT")
        color = quest_ctrl:GetUserConfig("KEYITEM_COLOR")
    end
    nametxt:SetText(font .. color .. quest_ies.Name)
    leveltxt:SetText(color .. "Lv " .. quest_ies.Level)]]
    local rect = leveltxt:GetMargin()
    leveltxt:SetMargin(rect.left - 10, rect.top, rect.right, rect.bottom)
    local questmark = GET_CHILD(quest_ctrl, "questmark")
    AUTO_CAST(questmark)
    local image_name = questmark:GetImageName()
    local result = SCR_QUEST_CHECK_C(GetMyPCObject(), quest_ies.ClassName)
    if (result == 'POSSIBLE' and quest_ies.POSSI_WARP == 'YES') or
        (result == 'PROGRESS' and quest_ies.PROG_WARP == 'YES') or
        (result == 'SUCCESS' and quest_ies.SUCC_WARP == 'YES') then
        local slot = quest_ctrl:CreateOrGetControl("slot", "slot", 78, 5, 20, 20)
        AUTO_CAST(slot)
        slot:EnablePop(1)
        slot:EnableDrop(0)
        local icon = CreateIcon(slot)
        icon:SetImage("questinfo_return")
        icon:SetUserValue("QUEST_ID", quest_ies.ClassID)
        local msg = g.lang == "Japanese" and "{ol}Sub Slotset{nl}左クリック: スロットに登録" or
                        "{ol}Sub Slotset{nl}LeftClick:for Registration"
        icon:SetTextTooltip(msg)
    end
end

function Sub_slotset_frame_init()
    if g.sub_slotset_settings.share then
        for ss_name, data in pairs(g.sub_slotset_settings.share) do
            Sub_slotset_process(ss_name, data, true)
        end
    end
    if g.sub_slotset_settings.personal[g.cid] then
        for ss_name, data in pairs(g.sub_slotset_settings.personal[g.cid]) do
            Sub_slotset_process(ss_name, data, false)
        end
    end
    return 1
end

function Sub_slotset_process(ss_name, data, is_share)
    local frame_name = addon_name_lower .. ss_name
    local sub_slotset = ui.GetFrame(frame_name)
    if not sub_slotset then
        sub_slotset = ui.CreateNewFrame("notice_on_pc", frame_name, 0, 0, 0, 0)
        AUTO_CAST(sub_slotset)
        sub_slotset:SetSkinName("chat_window_2")
        sub_slotset:SetAlpha(20)
        sub_slotset:SetLayerLevel(data.etc.layer)
        sub_slotset:EnableHittestFrame(1)
        sub_slotset:SetEventScript(ui.LBUTTONUP, "Sub_slotset_end_drag")
        sub_slotset:SetEventScript(ui.RBUTTONUP, "Sub_slotset_rbtn")
        Sub_slotset_slotset_make(sub_slotset, data.etc, true)
        if is_share then
            local titlelabel = sub_slotset:CreateOrGetControl('richtext', 'titlelabel', 0, 0, 0, 0)
            titlelabel:SetTextAlign('center', 'center')
            titlelabel:SetGravity(ui.LEFT, ui.TOP)
            titlelabel:SetText("{ol}{s10}shared")
        else
            sub_slotset:RemoveChild("titlelabel")
        end
        if data.etc then
            if data.etc.x and data.etc.y then
                sub_slotset:SetPos(data.etc.x, data.etc.y)
            end
            sub_slotset:EnableMove(data.etc.lock and 0 or 1)
        end
    end
    if sub_slotset:IsVisible() == 0 then
        sub_slotset:ShowWindow(1)
    end
    Sub_slotset_update_contents(sub_slotset, data)
end

function Sub_slotset_change_layer(skillability)

end

function Sub_slotset_update_contents(sub_slotset, data)
    local slot_set = GET_CHILD(sub_slotset, "slotset")
    if not slot_set then
        return
    end
    slot_set:SetUserValue("LAYER", data.etc.layer)
    local skillability = ui.GetFrame("skillability")
    if skillability:IsVisible() == 1 then
        local lift_icon = ui.GetLiftIcon()
        if lift_icon then
            sub_slotset:SetLayerLevel(999)
        else
            sub_slotset:SetLayerLevel(data.etc.layer)
        end
    else
        sub_slotset:SetLayerLevel(data.etc.layer)
    end
    slot_set:EnablePop(data.etc.lock and 0 or 1)
    slot_set:EnableDrag(data.etc.lock and 0 or 1)
    slot_set:EnableDrop(data.etc.lock and 0 or 1)
    slot_set:EnableHitTest(1)
    local slot_count = slot_set:GetSlotCount()
    for i = 1, slot_count do
        local slot = GET_CHILD(slot_set, "slot" .. i)
        AUTO_CAST(slot)
        local str_i = tostring(i)
        local saved_item = data[str_i]
        slot:EnablePop(data.etc.lock and 0 or 1)
        slot:EnableDrag(data.etc.lock and 0 or 1)
        slot:EnableDrop(data.etc.lock and 0 or 1)
        slot:SetEventScript(ui.DROP, 'Sub_slotset_drop')
        slot:SetEventScriptArgNumber(ui.DROP, i)
        slot:SetEventScript(ui.POP, 'Sub_slotset_pop')
        slot:SetEventScriptArgString(ui.POP, str_i)
        slot:SetEventScript(ui.RBUTTONUP, 'Sub_slotset_slot_rbutton')
        if saved_item and saved_item.iesid then
            local iesid = saved_item.iesid
            local category = saved_item.category
            local cls_id = saved_item.clsid
            slot:EnableDrop(data.etc.lock and 0 or 1)
            slot:SetEventScriptArgNumber(ui.RBUTTONUP, cls_id)
            slot:SetEventScriptArgString(ui.RBUTTONUP, category)
            slot:SetEventScriptArgString(ui.DROP, category)
            local icon = slot:GetIcon()
            if not icon then
                icon = CreateIcon(slot)
            end
            if category == "Item" then
                local item_cls = GetClassByType("Item", cls_id)
                SET_SLOT_ITEM_CLS(slot, item_cls)
                local inv_item = session.GetInvItemByGuid(iesid) or session.GetInvItemByType(cls_id)
                if inv_item then
                    local item_obj = GetIES(inv_item:GetObject())
                    icon:SetColorTone('FFFFFFFF')
                    SET_SLOT_ITEM_IMAGE(slot, inv_item)
                    ICON_SET_ITEM_COOLDOWN_OBJ(icon, item_obj)
                    Sub_slotset_SET_SLOT_ITEM_TEXT(slot, inv_item, item_cls)
                else
                    icon:SetColorTone('FFFF0000')
                    slot:SetText("{s15}{ol}{b}" .. 0, 'count', ui.RIGHT, ui.BOTTOM, -2, 1);
                end
            elseif category == "Pose" then
                local pose = GetClassByType('Pose', cls_id)
                if pose then
                    icon:Set(pose.Icon, category, cls_id, 0, iesid)
                    icon:SetColorTone('FFFFFFFF')
                    icon:SetTextTooltip(pose.Name)
                end
                slot:ClearText()
            elseif category == "Skill" then
                icon:SetOnCoolTimeUpdateScp('ICON_UPDATE_SKILL_COOLDOWN')
                icon:SetEnableUpdateScp('ICON_UPDATE_SKILL_ENABLE')
                icon:SetColorTone('FFFFFFFF')
                icon:SetTooltipType('skill')
                icon:Set('icon_' .. GetClassString('Skill', cls_id, 'Icon'), category, cls_id, 0, iesid)
                icon:SetTooltipNumArg(cls_id)
                icon:SetTooltipIESID(iesid)
                slot:ClearText()
                QUICKSLOT_MAKE_GAUGE(slot)
                QUICKSLOT_SET_GAUGE_VISIBLE(slot, 0)
                SET_QUICKSLOT_OVERHEAT(slot)
            elseif category == 'Ability' then
                local pc = GetMyPCObject()
                local abil_class = GetClassByType("Ability", cls_id)
                local abil_ies = GetAbilityIESObject(pc, abil_class.ClassName)
                if abil_class then
                    icon:SetTooltipType("ability")
                    icon:SetTooltipNumArg(cls_id)
                    icon:Set(abil_class.Icon, category, cls_id, 0, iesid)
                    local abil_ies = GetAbilityIESObject(pc, abil_class.ClassName)
                    if abil_ies then
                        icon:SetColorTone('FFFFFFFF')
                        SET_ABILITY_TOGGLE_COLOR(icon, cls_id)
                    else
                        icon:SetColorTone('FFFF0000')
                    end
                end
                slot:ClearText()
            elseif category == 'Quest' then
                local pc = GetMyPCObject()
                local quest_ies = GetClassByType("QuestProgressCheck", cls_id)
                if quest_ies then
                    local result = SCR_QUEST_CHECK_Q(pc, quest_ies.ClassName)
                    local target_map_name = GET_QUEST_LOCATION(quest_ies)
                    local zone_name = GetClassString('Map', target_map_name, 'Name')
                    icon:SetImage("questinfo_return")
                    local check_result = SCR_QUEST_CHECK_C(pc, quest_ies.ClassName)
                    if (check_result == 'POSSIBLE' and quest_ies.POSSI_WARP == 'YES') or
                        (check_result == 'PROGRESS' and quest_ies.PROG_WARP == 'YES') or
                        (check_result == 'SUCCESS' and quest_ies.SUCC_WARP == 'YES') then
                        icon:SetColorTone('FFFFFFFF')
                    else
                        icon:SetColorTone('FFFF0000')
                    end
                    icon:SetTextTooltip("{ol}" .. quest_ies.Name)
                    SET_SLOT_COUNT_TEXT(slot, zone_name, '{s10}{ol}{b}', ui.LEFT, ui.BOTTOM, 0, 0)
                end
            elseif category == 'Emoticon' then
                local list, cnt = GetClassList("chat_emoticons")
                local acc_obj = GetMyAccountObj()
                local etc_obj = GetMyEtcObject()
                local target_group = cls_id
                for j = 0, cnt - 1 do
                    local cls = GetClassByIndexFromList(list, j)
                    if cls.IconGroup == target_group then
                        if iesid == cls.ClassName then
                            local image_name = cls.ClassName
                            local name_parts = StringSplit(cls.ClassName, "motion_")
                            if #name_parts > 1 then
                                image_name = name_parts[2]
                            end
                            slot:SetUserValue("EMO_ID", target_group)
                            local is_owned = false
                            if cls.CheckServer == 'YES' then
                                local target_obj = acc_obj
                                if TryGetProp(cls, 'HaveUnit', 'None') == 'PC' then
                                    target_obj = etc_obj
                                end
                                if TryGetProp(target_obj, 'HaveEmoticon_' .. cls.ClassID, 0) > 0 then
                                    is_owned = true
                                end
                            else
                                is_owned = true
                            end
                            if not icon then
                                icon = CreateIcon(slot)
                            end
                            icon:SetImage(image_name)
                            slot:ClearText()
                            if is_owned then
                                icon:SetColorTone('FFFFFFFF')
                            else
                                icon:SetColorTone('FF696969')
                            end
                            break
                        end
                    end
                end
            elseif category == 'None' then
                CLEAR_SLOT_ITEM_INFO(slot)
                slot:ClearText()
            end
        else
            slot:ClearIcon()
            slot:ClearText()
        end
    end
end

function Sub_slotset_SET_SLOT_ITEM_TEXT(slot, inv_item, item_obj)
    if item_obj.MaxStack > 1 then
        Sub_slotset_SET_SLOT_COUNT_TEXT(slot, inv_item.count)
        return
    end
    local lv = TryGetProp(item_obj, "Level");
    if lv and lv > 1 then
        slot:SetFrontImage('enchantlevel_indi_icon')
        slot:SetText('{s20}{ol}{#FFFFFF}{b}' .. lv, 'count', ui.LEFT, ui.TOP, 8, 2)
        return
    end
end

function Sub_slotset_SET_SLOT_COUNT_TEXT(slot, count, font)
    if not font then
        font = '{s15}{ol}{b}'
    end
    slot:SetText(font .. count, 'count', ui.RIGHT, ui.BOTTOM, -2, 1)
end

function Sub_slotset_pop(parent, slot, str_i, num)
    local sub_slotset = slot:GetTopParentFrame()
    local sub_slotset_name = string.gsub(sub_slotset:GetName(), addon_name_lower, "")
    local target_settings, is_share = Sub_slotset_get_settings(sub_slotset_name)
    if keyboard.IsKeyPressed("LSHIFT") == 1 then
        CLEAR_SLOT_ITEM_INFO(slot)
        target_settings[str_i] = nil
        Sub_slotset_save_settings()
        return
    end
    g.sub_slotset_drag = nil
    if target_settings and target_settings[str_i] then
        g.sub_slotset_drag = {
            index = str_i,
            data = target_settings[str_i],
            frame_name = sub_slotset_name
        }
    end
end

function Sub_slotset_drop(parent, slot, category, i)
    local sub_slotset = slot:GetTopParentFrame()
    local sub_slotset_name = string.gsub(sub_slotset:GetName(), addon_name_lower, "")
    local target_settings, is_share = Sub_slotset_get_settings(sub_slotset_name)
    if not target_settings then
        return
    end
    local str_i = tostring(i)
    if g.sub_slotset_drag and g.sub_slotset_drag.frame_name == sub_slotset_name then
        local from_index = g.sub_slotset_drag.index
        if from_index == str_i then
            g.sub_slotset_drag = nil
            return
        end
        local swap_target = target_settings[str_i]
        target_settings[str_i] = g.sub_slotset_drag.data
        target_settings[from_index] = swap_target
        g.sub_slotset_drag = nil
        Sub_slotset_save_settings()
        Sub_slotset_update_contents(sub_slotset, target_settings)
        return
    end
    local lift_icon = ui.GetLiftIcon()
    local poseid = lift_icon:GetUserValue('POSEID')
    local info = lift_icon:GetInfo()
    if not info then
        return
    end
    local image = info:GetImageName()
    local cls_id = info.type
    local iesid = info:GetIESID()
    local category_val = info:GetCategory()
    local chat_emoticon = ui.GetFrame("chat_emoticon")
    local group_name = chat_emoticon:GetUserValue("EMOTICON_GROUP")
    if group_name == "Motion" then
        image = "motion_" .. image
    end
    if group_name == "None" then
        group_name = "Normal"
    end
    if string.find(image, "emot") then
        target_settings[str_i] = {
            category = "Emoticon",
            clsid = group_name,
            iesid = image
        }
        local chat = ui.GetFrame('chat')
        local mainchat = chat:GetChild('mainchat')
        SET_CHAT_TEXT_TO_CHATFRAME("")
        mainchat:RunEnterKeyScript()
        ui.ProcessReturnKey()
        chat:ShowWindow(0)
    elseif image == "questinfo_return" then
        local quest_id = lift_icon:GetUserIValue("QUEST_ID")
        target_settings[str_i] = {
            category = "Quest",
            clsid = quest_id,
            iesid = ""
        }
    elseif poseid ~= "None" then
        target_settings[str_i] = {
            category = 'Pose',
            clsid = poseid,
            iesid = ""
        }
    else
        target_settings[str_i] = {
            category = category_val,
            clsid = cls_id,
            iesid = iesid
        }
    end
    Sub_slotset_save_settings()
    Sub_slotset_update_contents(sub_slotset, target_settings)
end

function Sub_slotset_slot_rbutton(frame, slot, category, cls_id)
    if category == 'Item' then
        SLOT_ITEMUSE_BY_TYPE(frame, slot, category, cls_id)
    elseif category == 'Pose' then
        control.Pose(GetClassByType('Pose', cls_id).ClassName)
    elseif category == 'Skill' or category == 'Ability' then
        local icon = slot:GetIcon()
        if icon then
            ICON_USE(icon)
        end
    elseif category == 'Quest' then
        local quest_ies = GetClassByType("QuestProgressCheck", cls_id)
        local pc = GetMyPCObject()
        local result = SCR_QUEST_CHECK_Q(pc, quest_ies.ClassName)
        if (result == 'POSSIBLE' and quest_ies.POSSI_WARP == 'YES') or
            (result == 'PROGRESS' and quest_ies.PROG_WARP == 'YES') or
            (result == 'SUCCESS' and quest_ies.SUCC_WARP == 'YES') then
            local cheat = string.format("/retquest %d", cls_id)
            movie.QuestWarp(session.GetMyHandle(), cheat, 1)
            packet.ClientDirect("QuestWarp")
        else
            local icon = slot:GetIcon()
            if icon then
                icon:SetColorTone('FFFF0000')
            end
        end
    elseif category == 'Emoticon' then
        local icongroup = slot:GetUserValue("EMO_ID")
        local chat_emoticon = ui.GetFrame("chat_emoticon")
        local chat = ui.GetFrame('chat')
        local mainchat = chat:GetChild('mainchat')
        AUTO_CAST(mainchat)
        local icon = slot:GetIcon()
        if icon then
            local image_name = icon:GetInfo():GetImageName()
            local tag = ""
            if image_name ~= "" then
                if icongroup == 'Motion' then
                    local image_name = icon:GetInfo():GetImageName()
                    if not string.find(image_name, "motion_") then
                        image_name = "motion_" .. image_name
                        tag = string.format("{spine %s %d %d}{/}", image_name, 120, 120)
                    end
                else
                    tag = string.format("{img %s %d %d}{/}", image_name, 30, 30)
                end
                SET_CHAT_TEXT_TO_CHATFRAME(tag)
                mainchat:RunEnterKeyScript()
                ui.ProcessReturnKey()
                chat:ShowWindow(0)
            end
        end
    end
end

function Sub_slotset_get_settings(sub_slotset_name)
    local settings = g.sub_slotset_settings.share[sub_slotset_name]
    if settings then
        return settings, true
    end
    if g.sub_slotset_settings.personal[g.cid] then
        settings = g.sub_slotset_settings.personal[g.cid][sub_slotset_name]
        if settings then
            return settings, false
        end
    end
    return nil
end

function Sub_slotset_setting(sub_slotset_name)
    local x = 0
    local y = 0
    local is_new = true
    local list_frame = ui.GetFrame(addon_name_lower .. "list_frame")
    if list_frame then
        x = list_frame:GetX() + list_frame:GetWidth()
        y = list_frame:GetY()
    else
        local client_Width = ui.GetClientInitialWidth() -- 1920
        local client_Height = ui.GetClientInitialHeight() -- 1080
        x = client_Width / 2
        y = client_Height / 2
        is_new = false
    end
    local setting = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "sub_slotset_setting", 0, 0, 0, 0)
    AUTO_CAST(setting)
    setting:SetPos(x, y)
    setting:EnableHittestFrame(1)
    setting:SetLayerLevel(999)
    setting:RemoveAllChild()
    setting:SetSkinName("test_frame_low")
    local title_text = setting:CreateOrGetControl('richtext', 'title_text', 20, 15, 50, 30)
    AUTO_CAST(title_text)
    if is_new then
        title_text:SetText("{ol}Sub Slotset Config")
    else
        title_text:SetText("{ol}{s14}Sub Slotset Resettings")
    end
    local close = setting:CreateOrGetControl("button", "close", 0, 0, 20, 20)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Sub_slotset_setting_close")
    local gbox = setting:CreateOrGetControl("groupbox", "gbox", 10, 40, 0, 0)
    AUTO_CAST(gbox)
    gbox:SetSkinName("test_frame_midle_light")
    g.sub_slotset_col = g.sub_slotset_col or 3
    g.sub_slotset_row = g.sub_slotset_row or 3
    g.sub_slotset_size = g.sub_slotset_size or 48
    g.sub_slotset_layer = g.sub_slotset_layer or 90
    g.sub_slotset_personal = g.sub_slotset_personal or 0
    local col = gbox:CreateOrGetControl("richtext", "col", 10, 10, 80, 25)
    AUTO_CAST(col)
    col:SetText("{ol}{s16}Column")
    local col_edit = gbox:CreateOrGetControl('edit', 'col_edit', 10, 35, 80, 25)
    AUTO_CAST(col_edit)
    col_edit:SetFontName('white_16_ol')
    col_edit:SetSkinName('test_weight_skin')
    col_edit:SetTextAlign('center', 'center')
    col_edit:SetText(g.sub_slotset_col)
    col_edit:SetNumberMode(1)
    col_edit:SetMaxLen(2)
    col_edit:SetTypingScp("Sub_slotset_setting_edit")
    col_edit:SetEventScript(ui.ENTERKEY, "Sub_slotset_setting_edit")
    local row = gbox:CreateOrGetControl("richtext", "row", 100, 10, 80, 25)
    AUTO_CAST(row)
    row:SetText("{ol}{s16}Row")
    local row_edit = gbox:CreateOrGetControl('edit', 'row_edit', 100, 35, 80, 25)
    AUTO_CAST(row_edit)
    row_edit:SetFontName('white_16_ol')
    row_edit:SetSkinName('test_weight_skin')
    row_edit:SetTextAlign('center', 'center')
    row_edit:SetNumberMode(1)
    row_edit:SetMaxLen(2)
    row_edit:SetText(g.sub_slotset_row)
    row_edit:SetTypingScp("Sub_slotset_setting_edit")
    row_edit:SetEventScript(ui.ENTERKEY, "Sub_slotset_setting_edit")
    local size = gbox:CreateOrGetControl("richtext", "size", 10, 70, 80, 25)
    AUTO_CAST(size)
    size:SetText("{ol}{s16}Slot Size")
    local size_edit = gbox:CreateOrGetControl('edit', 'size_edit', 10, 95, 80, 25)
    AUTO_CAST(size_edit)
    size_edit:SetFontName('white_16_ol')
    size_edit:SetSkinName('test_weight_skin')
    size_edit:SetTextAlign('center', 'center')
    size_edit:SetNumberMode(1)
    size_edit:SetText(g.sub_slotset_size)
    size_edit:SetMaxLen(2)
    size_edit:SetTypingScp("Sub_slotset_setting_edit")
    size_edit:SetEventScript(ui.ENTERKEY, "Sub_slotset_setting_edit")
    local layer = gbox:CreateOrGetControl("richtext", "layer", 100, 70, 80, 25)
    AUTO_CAST(layer)
    layer:SetText("{ol}{s16}Layer")
    local layer_edit = gbox:CreateOrGetControl('edit', 'layer_edit', 100, 95, 80, 25)
    AUTO_CAST(layer_edit)
    layer_edit:SetFontName('white_16_ol')
    layer_edit:SetSkinName('test_weight_skin')
    layer_edit:SetTextAlign('center', 'center')
    layer_edit:SetNumberMode(1)
    layer_edit:SetText(g.sub_slotset_layer)
    layer_edit:SetMaxLen(3)
    layer_edit:SetTypingScp("Sub_slotset_setting_edit")
    layer_edit:SetEventScript(ui.ENTERKEY, "Sub_slotset_setting_edit")
    local parsonal = gbox:CreateOrGetControl("checkbox", "parsonal", 10, 130, 30, 30)
    AUTO_CAST(parsonal)
    if is_new then
        parsonal:SetTextTooltip(g.lang == "Japanese" and
                                    "{ol}チェックを入れるとキャラ用に作成{nl}後から変更可能" or
                                    "{ol}If checked, created for the character{nl}Can be changed later")
        parsonal:SetText(g.lang == "Japanese" and "{ol}キャラクター専用" or "{ol}Character Only")
        parsonal:SetCheck(g.sub_slotset_personal)
        local make = gbox:CreateOrGetControl('button', 'make', 100, 165, 80, 30)
        AUTO_CAST(make)
        make:SetSkinName("test_red_button")
        make:SetText("{ol}{s16}Make")
        make:SetEventScript(ui.LBUTTONUP, "Sub_slotset_make")
    else
        parsonal:SetTextTooltip(g.lang == "Japanese" and "{ol}チェックを入れるとキャラ用に切替" or
                                    "{ol}If checked, switches to character-specific setting")
        parsonal:SetText(g.lang == "Japanese" and "{ol}共有/キャラ切替" or "{ol}Shared/Character{nl}Switch")
        local target_settings = g.sub_slotset_settings.share[sub_slotset_name]
        parsonal:SetCheck(target_settings and 0 or 1)
        parsonal:SetEventScript(ui.LBUTTONUP, "Sub_slotset_setting_checkbox")
        local change = gbox:CreateOrGetControl('button', 'change', 100, 165, 80, 30)
        AUTO_CAST(change)
        change:SetSkinName("test_red_button")
        change:SetText("{ol}{s16}Change")
        change:SetEventScript(ui.LBUTTONUP, "Sub_slotset_change")
        change:SetEventScriptArgString(ui.LBUTTONUP, sub_slotset_name)
    end
    parsonal:SetEventScript(ui.LBUTTONUP, "Sub_slotset_setting_checkbox")
    setting:Resize(210, 255)
    gbox:Resize(setting:GetWidth() - 20, setting:GetHeight() - 50)
    setting:ShowWindow(1)
end

function Sub_slotset_setting_close(setting)
    ui.DestroyFrame(setting:GetName())
end

function Sub_slotset_end_drag(sub_slotset, ctrl)
    local sub_slotset_name = string.gsub(sub_slotset:GetName(), addon_name_lower, "")
    local target_settings = Sub_slotset_get_settings(sub_slotset_name)
    if target_settings and target_settings.etc then
        target_settings.etc.x = sub_slotset:GetX()
        target_settings.etc.y = sub_slotset:GetY()
        Sub_slotset_save_settings()
    end
end

function Sub_slotset_setting_checkbox(parent, ctrl)
    g.sub_slotset_personal = ctrl:IsChecked()
end

function Sub_slotset_setting_edit(parent, ctrl)
    local ctrl_name = ctrl:GetName()
    local val = tonumber(ctrl:GetText())
    if not val then
        return
    end
    if (ctrl_name == "col_edit" or ctrl_name == "row_edit") and val > 10 then
        ui.SysMsg(g.lang == "Japanese" and "10以下で設定してください" or "Enter 10 or less")
        val = 10
        ctrl:SetText(val)
    end
    if ctrl_name == "col_edit" then
        g.sub_slotset_col = val
    elseif ctrl_name == "row_edit" then
        g.sub_slotset_row = val
    elseif ctrl_name == "size_edit" then
        local row_edit = GET_CHILD_RECURSIVELY(parent, "row_edit")
        local current_row = tonumber(row_edit:GetText())
        if not current_row or current_row == 0 then
            current_row = g.sub_slotset_row or 1
        end
        local map = ui.GetFrame("map")
        local h = map:GetHeight()
        local limit_size = math.floor(tonumber(h) / current_row)
        if val > limit_size then
            local msg = g.lang == "Japanese" and
                            string.format("入力は %d 以下に制限されています", limit_size) or
                            string.format("Input is limited to %d or less", limit_size)
            ui.SysMsg(msg)
            val = 48
            ctrl:SetText(val)
        end
        g.sub_slotset_size = val
    elseif ctrl_name == "layer_edit" then
        g.sub_slotset_layer = val
    end
end

function Sub_slotset_change(parent, ctrl, sub_slotset_name)
    local target_settings, is_in_share = Sub_slotset_get_settings(sub_slotset_name)
    if not target_settings then
        return
    end
    local setting_frame = ctrl:GetTopParentFrame()
    ui.DestroyFrame(setting_frame:GetName())
    local function CloneTable(orig)
        local orig_type = type(orig)
        local copy
        if orig_type == 'table' then
            copy = {}
            for orig_key, orig_value in next, orig, nil do
                copy[CloneTable(orig_key)] = CloneTable(orig_value)
            end
            setmetatable(copy, CloneTable(getmetatable(orig)))
        else
            copy = orig
        end
        return copy
    end
    if is_in_share and g.sub_slotset_personal == 1 then -- Share -> Personal
        if not g.sub_slotset_settings.personal[g.cid] then
            g.sub_slotset_settings.personal[g.cid] = {}
        end
        g.sub_slotset_settings.personal[g.cid][sub_slotset_name] = CloneTable(target_settings)
        g.sub_slotset_settings.share[sub_slotset_name] = nil
        target_settings = g.sub_slotset_settings.personal[g.cid][sub_slotset_name]
    elseif not is_in_share and g.sub_slotset_personal == 0 then -- Personal -> Share
        g.sub_slotset_settings.share[sub_slotset_name] = CloneTable(target_settings)
        if g.sub_slotset_settings.personal[g.cid] then
            g.sub_slotset_settings.personal[g.cid][sub_slotset_name] = nil
        end
        target_settings = g.sub_slotset_settings.share[sub_slotset_name]
    end
    Sub_slotset_save_settings()
    local index = tonumber((string.gsub(sub_slotset_name, "sub_slotset_", "")))
    Sub_slotset_make(parent, ctrl, sub_slotset_name, index, target_settings)
end

function Sub_slotset_make(parent, ctrl, sub_slotset_name, index, target_settings)
    local setting = ctrl:GetTopParentFrame()
    local is_share = (g.sub_slotset_personal == 0)
    if target_settings then
        local sub_slotset = ui.GetFrame("_nexus_addons_p" .. sub_slotset_name)
        AUTO_CAST(sub_slotset)
        sub_slotset:RemoveAllChild()
        target_settings.etc = {
            x = target_settings.etc.x,
            y = target_settings.etc.y,
            row = g.sub_slotset_row,
            col = g.sub_slotset_col,
            size = g.sub_slotset_size,
            layer = g.sub_slotset_layer,
            lock = target_settings.etc.lock
        }
        sub_slotset:SetLayerLevel(g.sub_slotset_layer)
        sub_slotset:SetEventScript(ui.LBUTTONUP, "Sub_slotset_end_drag")
        -- sub_slotset:SetEventScript(ui.RBUTTONUP, "Sub_slotset_rbtn")
        Sub_slotset_save_settings()
        local is_share = (g.sub_slotset_settings.share[sub_slotset_name] ~= nil)
        Sub_slotset_slotset_make(sub_slotset, target_settings.etc, is_share)
        return
    end
    local setting = ctrl:GetTopParentFrame()
    ui.DestroyFrame(setting:GetName())
    local list_frame_name = addon_name_lower .. "list_frame"
    ui.DestroyFrame(addon_name_lower .. "list_frame")
    local tbl
    local is_share_new = false
    if g.sub_slotset_personal == 1 then
        if not g.sub_slotset_settings.personal[g.cid] then
            g.sub_slotset_settings.personal[g.cid] = {}
        end
        tbl = g.sub_slotset_settings.personal[g.cid]
    else
        tbl = g.sub_slotset_settings.share
        is_share_new = true
    end
    local new_index = g.sub_slotset_settings.config.index
    local new_name = "sub_slotset_" .. new_index
    local sub_slotset = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "sub_slotset_" .. new_index, 0, 0, 0, 0)
    AUTO_CAST(sub_slotset)
    tbl["sub_slotset_" .. new_index] = {}
    tbl["sub_slotset_" .. new_index].etc = {
        x = setting:GetX() + 100,
        y = setting:GetY() + 400,
        row = g.sub_slotset_row,
        col = g.sub_slotset_col,
        size = g.sub_slotset_size,
        layer = g.sub_slotset_layer,
        lock = false
    }
    g.sub_slotset_settings.config.index = new_index + 1
    Sub_slotset_save_settings()
    sub_slotset:SetSkinName("chat_window_2")
    sub_slotset:SetAlpha(20)
    sub_slotset:SetLayerLevel(g.sub_slotset_layer)
    sub_slotset:EnableHittestFrame(1)
    sub_slotset:EnableMove(1)
    sub_slotset:SetPos(setting:GetX() + 100, setting:GetY() + 400)
    sub_slotset:ShowWindow(1)
    sub_slotset:SetEventScript(ui.LBUTTONUP, "Sub_slotset_end_drag")
    -- sub_slotset:SetEventScript(ui.RBUTTONUP, "Sub_slotset_rbtn")
    Sub_slotset_slotset_make(sub_slotset, tbl[new_name].etc, is_share_new)
end

function Sub_slotset_slotset_make(sub_slotset, etc_settings, is_share)
    local slotset = sub_slotset:CreateOrGetControl('slotset', 'slotset', 2, 9, 0, 0)
    AUTO_CAST(slotset)
    slotset:EnablePop(1)
    slotset:EnableDrag(1)
    slotset:EnableDrop(1)
    slotset:EnableHitTest(1)
    local col = (etc_settings and etc_settings.col) or g.sub_slotset_col or 3
    local row = (etc_settings and etc_settings.row) or g.sub_slotset_row or 3
    local size = (etc_settings and etc_settings.size) or g.sub_slotset_size or 48
    local is_locked = (etc_settings and etc_settings.lock) or false
    slotset:SetColRow(col, row)
    slotset:SetSlotSize(size, size)
    slotset:SetSpc(2, 2)
    slotset:SetSkinName('invenslot2')
    slotset:CreateSlots()
    if g.sub_slotset_personal == 0 then
        local titlelabel = sub_slotset:CreateOrGetControl('richtext', 'titlelabel', 0, 0, 0, 0)
        titlelabel:SetTextAlign('center', 'center')
        titlelabel:SetGravity(ui.LEFT, ui.TOP)
        titlelabel:SetText("{ol}{s10}shared")
    else
        sub_slotset:RemoveChild("titlelabel")
    end
    local gb = sub_slotset:CreateOrGetControl("groupbox", "gb", 0, 0, 20, 30)
    AUTO_CAST(gb)
    gb:SetGravity(ui.RIGHT, ui.TOP)
    local text = g.lang == "Japanese" and
                     "{ol}右クリック: 各種設定{nl} {nl}スロット LSHIFT+左クリック: アイコン削除" or
                     "{ol}Right Click: Various Settings{nl} {nl}Slot LSHIFT + Left Click: Remove Icon"
    gb:SetTextTooltip(text)
    gb:SetEventScript(ui.RBUTTONUP, "Sub_slotset_rbtn")
    local itemlock = gb:CreateOrGetControlSet('inv_itemlock', "itemlock", 0, 0)
    itemlock:SetGrayStyle(is_locked and 0 or 1)
    sub_slotset:Resize(size * col + 10 + col * 2, size * row + 10 + row * 2)
    return slotset
end

function Sub_slotset_rbtn(sub_slotset, ctrl)
    local sub_slotset_name = string.gsub(sub_slotset:GetName(), "_nexus_addons_p", "")
    local context = ui.CreateContextMenu("slotset_context",
        g.lang == "Japanese" and "{ol}各種設定" or "{ol}Various Settings", 0, 0, 100, 100)
    ui.AddContextMenuItem(context, " ", "None")
    local scp = string.format("Sub_slotset_remove_msg('%s')", sub_slotset_name)
    local msg = g.lang == "Japanese" and "{ol}スロットセット削除" or "{ol}Remove Slot Set"
    ui.AddContextMenuItem(context, msg, scp)
    scp = string.format("Sub_slotset_lock_toggle('%s')", sub_slotset_name)
    msg = g.lang == "Japanese" and "{ol}スロットセットロック切替" or "{ol}Toggle Slot Set Lock"
    ui.AddContextMenuItem(context, msg, scp)
    scp = string.format("Sub_slotset_resetting('%s')", sub_slotset_name)
    msg = g.lang == "Japanese" and "{ol}スロットセット設定変更" or "{ol}Change Slot Set Settings"
    ui.AddContextMenuItem(context, msg, scp)
    ui.AddContextMenuItem(context, "  ", "None")
    ui.OpenContextMenu(context)
end

function Sub_slotset_remove_msg(sub_slotset_name)
    local scp = string.format("Sub_slotset_remove('%s')", sub_slotset_name)
    local msg = g.lang == "Japanese" and "削除しますか？" or "Confirm Deletion?"
    ui.MsgBox(msg, scp, "None")
end

function Sub_slotset_remove(sub_slotset_name)
    local _, is_in_share = Sub_slotset_get_settings(sub_slotset_name)
    if is_in_share == true then
        g.sub_slotset_settings.share[sub_slotset_name] = nil
    elseif is_in_share == false then
        g.sub_slotset_settings.personal[g.cid][sub_slotset_name] = nil
    end
    Sub_slotset_save_settings()
    ui.DestroyFrame(addon_name_lower .. sub_slotset_name)
end

function Sub_slotset_lock_toggle(sub_slotset_name)
    local sub_srotset = ui.GetFrame(addon_name_lower .. sub_slotset_name)
    local target_settings = Sub_slotset_get_settings(sub_slotset_name)
    if not target_settings then
        return
    end
    target_settings.etc.lock = not target_settings.etc.lock
    local is_locked = target_settings.etc.lock
    local itemlock = GET_CHILD_RECURSIVELY(sub_srotset, "itemlock")
    AUTO_CAST(itemlock)
    itemlock:SetGrayStyle(is_locked and 0 or 1)
    sub_srotset:EnableMove(is_locked and 0 or 1)
    Sub_slotset_save_settings()
end

function Sub_slotset_resetting(sub_slotset_name)
    local target_settings, is_share = Sub_slotset_get_settings(sub_slotset_name)
    g.sub_slotset_col = target_settings.etc.col
    g.sub_slotset_row = target_settings.etc.row
    g.sub_slotset_size = target_settings.etc.size
    g.sub_slotset_layer = target_settings.etc.layer
    g.sub_slotset_personal = is_share and 0 or 1
    Sub_slotset_setting(sub_slotset_name)
end
-- sub_slotset ここまで

