-- vakarine_equip ここから
function Vakarine_equip_save_settings()
    g.save_json(g.vakarine_equip_path, g.vakarine_equip_settings)
end

function Vakarine_equip_load_settings()
    g.vakarine_equip_path = string.format("../addons/%s/%s/vakarine_equip.json", addon_name_lower, g.active_id)
    local settings = g.load_json(g.vakarine_equip_path)
    if not settings then
        settings = {
            buffid = {},
            delay = 0.1,
            jsr = 0,
            x = 0,
            y = 0,
            move = 1,
            chars = {},
            auto_remove = 0
        }
    end
    g.vakarine_equip_settings = settings
    Vakarine_equip_save_settings()
end

function vakarine_equip_on_init()
    ui.SetHoldUI(false)
    if not g.vakarine_equip_settings then
        Vakarine_equip_load_settings()
    end
    if not g.vakarine_equip_settings.chars[g.cid] then
        Vakarine_equip_chrs_settings()
    end
    if g.settings.vakarine_equip.use == 0 then
        ui.DestroyFrame(addon_name_lower .. "vakarine_equip")
        return
    end
    g.addon:RegisterMsg('STAT_UPDATE', 'Vakarine_equip_stat_update')
    g.addon:RegisterMsg('TAKE_DAMAGE', 'Vakarine_equip_stat_update')
    g.addon:RegisterMsg('TAKE_HEAL', 'Vakarine_equip_stat_update')
    g.addon:RegisterMsg('BUFF_ADD', 'Vakarine_equip_BUFF_ON_MSG')
    g.addon:RegisterMsg('BUFF_UPDATE', 'Vakarine_equip_BUFF_ON_MSG')
    Vakarine_equip_frame_init()
    if g.get_map_type() ~= "City" then
        Vakarine_equip_start_operation()
    end
end

function Vakarine_equip_chrs_settings()
    local equips = {"RH", "LH", "RH_SUB", "LH_SUB", "RING1", "RING2", "SHIRT", "PANTS", "GLOVES", "BOOTS", "SHOULDER",
                    "BELT", "NECK"}
    g.vakarine_equip_settings.chars[g.cid] = {
        use = 0
    }
    for _, equip in ipairs(equips) do
        g.vakarine_equip_settings.chars[g.cid][equip] = 0
    end
    Vakarine_equip_save_settings()
end

function Vakarine_equip_frame_init()
    local vakarine_equip = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "vakarine_equip", 0, 0, 0, 0)
    AUTO_CAST(vakarine_equip)
    vakarine_equip:SetSkinName("None")
    vakarine_equip:SetTitleBarSkin("None")
    vakarine_equip:Resize(40, 30)
    vakarine_equip:SetGravity(ui.RIGHT, ui.TOP)
    vakarine_equip:EnableMove(g.vakarine_equip_settings.move == 1 and 0 or 1)
    vakarine_equip:EnableHittestFrame(1)
    local rect = vakarine_equip:GetMargin()
    vakarine_equip:SetMargin(rect.left - rect.left, rect.top - rect.top + 300,
        rect.right == 0 and rect.right + 10 or rect.right, rect.bottom)
    if g.vakarine_equip_settings.x ~= 0 and g.vakarine_equip_settings.y ~= 0 then
        vakarine_equip:SetPos(g.vakarine_equip_settings.x, g.vakarine_equip_settings.y)
    end
    vakarine_equip:SetEventScript(ui.LBUTTONUP, "Vakarine_equip_location_save")
    local vaka_pic = vakarine_equip:CreateOrGetControl("picture", "vaka_pic", 0, 0, 30, 30)
    AUTO_CAST(vaka_pic)
    vaka_pic:SetImage("bakarine_emotion68") -- vaka_pic:SetImage("bakarine_emotion61") vaka_pic:SetImage("emoticon_0024")
    vaka_pic:SetColorTone("FFFFFFFF")
    vaka_pic:SetEnableStretch(1)
    vaka_pic:EnableHitTest(1)
    vaka_pic:SetGravity(ui.LEFT, ui.TOP)
    vaka_pic:SetTextTooltip(g.lang == "Japanese" and
                                "{ol}Vakarine Equip{nl} {nl}左クリック{nl}街: 設定{nl}街以外: 手動起動{nl} {nl}右クリック{nl}自動起動ON/OFF" or
                                "{ol}Vakarine Equip{nl} {nl}Left click{nl}City: Setup{nl}Outside City: Manual activation{nl} {nl}Right click: Auto-activation ON/OFF")
    if g.vakarine_equip_settings.chars[g.cid].use == 0 then
        vaka_pic:SetColorTone("FF555555")
    else
        vaka_pic:SetColorTone("FFFFFFFF")
    end
    vaka_pic:SetEventScript(ui.RBUTTONUP, "Vakarine_equip_onoff_switch")
    vaka_pic:SetEventScript(ui.LBUTTONUP, "Vakarine_equip_config_or_startup")
    vakarine_equip:ShowWindow(1)
    if g.vakarine_equip_animas_iesid and g.get_map_type() == "City" then
        vakarine_equip:RunUpdateScript("Vakarine_equip_animas_equip", 1.0)
    end
end

function Vakarine_equip_location_save(frame, ctrl)
    if frame:GetName() == addon_name_lower .. "vakarine_equip" then
        g.vakarine_equip_settings.x = frame:GetX()
        g.vakarine_equip_settings.y = frame:GetY()
    elseif ctrl:GetName() == "default_btn" then
        g.vakarine_equip_settings.x = 0
        g.vakarine_equip_settings.y = 0
        ui.DestroyFrame(addon_name_lower .. "vakarine_equip")
        ReserveScript("Vakarine_equip_frame_init()", 0.1)
    end
    Vakarine_equip_save_settings()
end

function Vakarine_equip_onoff_switch(vakarine_equip, vaka_pic)
    if g.vakarine_equip_settings.chars[g.cid].use == 0 then
        g.vakarine_equip_settings.chars[g.cid].use = 1
        vaka_pic:SetColorTone("FFFFFFFF")
    else
        vaka_pic:SetColorTone("FF555555")
        g.vakarine_equip_settings.chars[g.cid].use = 0
    end
    Vakarine_equip_save_settings()
    if keyboard.IsKeyPressed("LSHIFT") == 1 then
        Vakarine_equip_buff_list(nil, nil, "")
        return
    end
end

function Vakarine_equip_animas_equip(vakarine_equip)
    local equip_item_list = session.GetEquipItemList()
    local equip_item = equip_item_list:GetEquipItemByIndex(19)
    if equip_item then
        local iesid = equip_item:GetIESID()
        local try = vakarine_equip:GetUserIValue("TRY")
        if iesid ~= g.vakarine_equip_animas_iesid and try < 3 then
            local equip_item = session.GetInvItemByGuid(g.vakarine_equip_animas_iesid)
            item.Equip(equip_item.invIndex)
            vakarine_equip:GetUserIValue("TRY", try + 1)
            return 1
        end
    end
    vakarine_equip:GetUserIValue("TRY", 0)
    g.vakarine_equip_animas_iesid = nil
    return 0
end

function Vakarine_equip_config_or_startup(frame, ctrl)
    if g.get_map_type() == "City" then
        Vakarine_equip_config_frame_open()
    else
        Vakarine_equip_start_operation(true)
    end
end

function Vakarine_equip_start_operation(is_manual)
    if not is_manual then
        local char_data = g.vakarine_equip_settings.chars[g.cid]
        if not char_data or char_data.use == 0 then
            return
        end
    end
    local is_vakarine = Vakarine_equip_is_vakarine()
    if not is_vakarine and not is_manual then
        return
    end
    local is_valid_map =
        (g.get_map_type() == "Instance" and g.map_id ~= 11227) -- 11244 聖域3F 11227 分裂 8022 ヴェルニケ
        or g.map_id == 8022 or g.map_id == 11244
    if is_valid_map or is_manual or g.vakarine_equip_settings.jsr == 1 then
        g.vakarine_equip_field_boss = nil
        local inventory = ui.GetFrame("inventory")
        inventory:ShowWindow(1)
        DO_WEAPON_SLOT_CHANGE(inventory, 1)
        ui.SetHoldUI(true)
        local vakarine_equip = ui.GetFrame(addon_name_lower .. "vakarine_equip")
        vakarine_equip:RunUpdateScript("Vakarine_equip_holdui_release", 10.0)
        local equip_map = {
            RH = 8,
            LH = 9,
            RH_SUB = 30,
            LH_SUB = 31,
            RING1 = 17,
            RING2 = 18,
            SHIRT = 3,
            PANTS = 14,
            GLOVES = 4,
            BOOTS = 5,
            SHOULDER = 34,
            BELT = 33,
            NECK = 19
        }
        g.vakarine_equip_queue = {}
        local char_settings = g.vakarine_equip_settings.chars[g.cid]
        local equip_item_list = session.GetEquipItemList()
        for spot_name, index in pairs(equip_map) do
            local current_item = equip_item_list:GetEquipItemByIndex(index)
            if char_settings[spot_name] == 1 and current_item then
                table.insert(g.vakarine_equip_queue, {
                    spot = spot_name,
                    index = index,
                    iesid = current_item:GetIESID()
                })
            end
        end
        local animas_item = session.GetInvItemByName("NECK04_103")
        g.vakarine_equip_animas_iesid = animas_item and animas_item:GetIESID() or nil
        if #g.vakarine_equip_queue == 0 then
            ui.SetHoldUI(false)
            return
        end
        for i, data in ipairs(g.vakarine_equip_queue) do
            if data.spot == "RH_SUB" then
                item.UnEquip(data.index)
                break
            end
        end
        g.vakarine_equip_process_step = "unequip"
        vakarine_equip:RunUpdateScript("Vakarine_equip_main_loop", g.vakarine_equip_settings.delay)
    end
end

function Vakarine_equip_main_loop(vakarine_equip)
    local equip_item_list = session.GetEquipItemList()
    if g.vakarine_equip_process_step == "unequip" then
        local all_unequipped = true
        for _, data in ipairs(g.vakarine_equip_queue) do
            local current_item = equip_item_list:GetEquipItemByIndex(data.index)
            if current_item and current_item:GetIESID() ~= "0" then
                item.UnEquip(data.index)
                return 1
            end
        end
        if all_unequipped then
            g.vakarine_equip_process_step = "equip"
        end
        return 1
    elseif g.vakarine_equip_process_step == "equip" then
        local weapon_order = {"RH", "LH", "RH_SUB", "LH_SUB"}
        for _, spot_name in ipairs(weapon_order) do
            for _, data in ipairs(g.vakarine_equip_queue) do
                if data.spot == spot_name then
                    local current_item = equip_item_list:GetEquipItemByIndex(data.index)
                    if not current_item or current_item:GetIESID() ~= data.iesid then
                        local inv_item = session.GetInvItemByGuid(data.iesid)
                        if inv_item then
                            ITEM_EQUIP(inv_item.invIndex, data.spot)
                            return 1
                        end
                    end
                    break
                end
            end
        end
        for _, data in ipairs(g.vakarine_equip_queue) do
            local spot_name = data.spot
            if spot_name ~= "RH" and spot_name ~= "LH" and spot_name ~= "RH_SUB" and spot_name ~= "LH_SUB" and spot_name ~=
                "NECK" then
                local current_item = equip_item_list:GetEquipItemByIndex(data.index)
                if not current_item or current_item:GetIESID() ~= data.iesid then
                    local inv_item = session.GetInvItemByGuid(data.iesid)
                    if inv_item then
                        ITEM_EQUIP(inv_item.invIndex, data.spot)
                        return 1
                    end
                end
            end
        end
        for _, data in ipairs(g.vakarine_equip_queue) do
            if data.spot == "NECK" then
                local iesid_to_equip = g.vakarine_equip_animas_iesid or data.iesid
                local current_item = equip_item_list:GetEquipItemByIndex(data.index)
                local current_iesid = current_item and current_item:GetIESID() or "0"
                if current_iesid ~= iesid_to_equip then
                    local inv_item = session.GetInvItemByGuid(iesid_to_equip)
                    if inv_item then
                        ITEM_EQUIP(inv_item.invIndex, data.spot)
                        return 1
                    end
                end
                break
            end
        end
        local inventory = ui.GetFrame("inventory")
        inventory:ShowWindow(0)
        imcAddOn.BroadMsg("NOTICE_Dm_stage_start", "[VE]End of Operation", 3)
        ui.SetHoldUI(false)
        return 0
    end
    return 1
end

function Vakarine_equip_is_vakarine()
    local equip_item_list = session.GetEquipItemList()
    local equip_guid_list = equip_item_list:GetGuidList()
    local count = equip_guid_list:Count()
    local vakarine_count = 0
    for i = 0, count - 1 do
        local guid = equip_guid_list:Get(i)
        if guid ~= '0' then
            local equip_item = equip_item_list:GetItemByGuid(guid)
            local item = GetIES(equip_item:GetObject())
            for j = 1, MAX_OPTION_EXTRACT_COUNT do
                local prop_name = "RandomOption_" .. j
                local cls_msg = ScpArgMsg(item[prop_name])
                if string.find(cls_msg, "vakarine_bless") then
                    vakarine_count = vakarine_count + 1
                    break
                end
            end
        end
    end
    if vakarine_count >= 5 then
        return true
    elseif vakarine_count == 4 then
        return false
    else
        return false
    end
end

function Vakarine_equip_holdui_release(frame)
    ui.SetHoldUI(false)
    return 0
end

function Vakarine_equip_config_frame_open()
    local config = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "vakarine_equip_config_frame", 0, 0, 0, 0)
    AUTO_CAST(config)
    config:RemoveAllChild()
    config:SetLayerLevel(999)
    config:SetSkinName("test_frame_low")
    local title_text = config:CreateOrGetControl("richtext", "title_text", 10, 10)
    AUTO_CAST(title_text)
    title_text:SetText("{ol}Vakarine Equip")
    local config_gb = config:CreateOrGetControl("groupbox", "config_gb", 10, 40, 0, 0)
    AUTO_CAST(config_gb)
    config_gb:SetSkinName("bg")
    local close = config:CreateOrGetControl("button", "close", 0, 0, 20, 20)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Vakarine_equip_frame_close")
    local jsr_check = config_gb:CreateOrGetControl('checkbox', "jsr_check", 10, 5, 30, 30)
    AUTO_CAST(jsr_check)
    jsr_check:SetCheck(g.vakarine_equip_settings.jsr)
    local text = g.lang == "Japanese" and "チェックするとJSRで作動" or "Activated in JSR when checked"
    jsr_check:SetText("{ol}" .. text)
    jsr_check:SetEventScript(ui.LBUTTONUP, "Vakarine_equip_check_switch")
    local x = 0
    local width = jsr_check:GetWidth()
    if x < width then
        x = width
    end
    local y = 40
    local equips = {"RH", "LH", "RH_SUB", "LH_SUB", "RING1", "RING2", "SHIRT", "PANTS", "GLOVES", "BOOTS", "SHOULDER",
                    "BELT", "NECK"}
    for i, equip_name in ipairs(equips) do
        local check_box = config_gb:CreateOrGetControl('checkbox', "check_box" .. i, 20, y, 30, 30)
        AUTO_CAST(check_box)
        check_box:SetCheck(g.vakarine_equip_settings.chars[g.cid][equip_name])
        check_box:SetTextTooltip(g.lang == "Japanese" and "{ol}チェックした装備を脱着します" or
                                     "{ol}Remove and detach checked equipment")
        check_box:SetEventScript(ui.LBUTTONUP, "Vakarine_equip_check_switch")
        check_box:SetEventScriptArgString(ui.LBUTTONUP, equip_name)
        if equip_name == "RING1" then
            equip_name = "Ring1"
        elseif equip_name == "RING2" then
            equip_name = "Ring2"
        elseif equip_name == "SHIRT" then
            equip_name = "Shirt"
        elseif equip_name == "PANTS" then
            equip_name = "Pants"
        end
        check_box:SetText("{ol}" .. ClMsg(equip_name))
        y = y + 30
    end
    y = y + 10
    local move_check = config_gb:CreateOrGetControl('checkbox', "move_check", 10, y, 30, 30)
    AUTO_CAST(move_check)
    move_check:SetCheck(g.vakarine_equip_settings.move)
    move_check:SetText(g.lang == "Japanese" and "{ol}チェックするとフレーム固定" or
                           "{ol}If checked, the frame is fixed")
    move_check:SetEventScript(ui.LBUTTONUP, "Vakarine_equip_check_switch")
    y = y + 40
    local default_btn = config_gb:CreateOrGetControl("button", "default_btn", 20, y, 120, 30)
    AUTO_CAST(default_btn)
    default_btn:SetText(g.lang == "Japanese" and "{ol}フレーム初期位置" or "{ol}Init frame pos")
    default_btn:SetEventScript(ui.LBUTTONUP, "Vakarine_equip_location_save")
    y = y + 30
    config:Resize(x + 70, y + 60)
    config_gb:Resize(x + 50, y + 10)
    local list_frame = ui.GetFrame(addon_name_lower .. "list_frame")
    if list_frame then
        config:SetPos(list_frame:GetX() + list_frame:GetWidth(), list_frame:GetY())
    else
        local map_frame = ui.GetFrame("map")
        local width = map_frame:GetWidth()
        config:SetPos(width / 2 - config:GetWidth() / 2 or 1165, 105)
    end
    config:ShowWindow(1)
end

function Vakarine_equip_check_switch(config, ctrl, equip_name, num)
    local ischeck = ctrl:IsChecked()
    if ctrl:GetName() == "jsr_check" then
        g.vakarine_equip_settings.jsr = ischeck
    elseif ctrl:GetName() == "move_check" then
        g.vakarine_equip_settings.move = ischeck
        Vakarine_equip_frame_init()
    elseif string.find(ctrl:GetName(), "check_box") then
        g.vakarine_equip_settings.chars[g.cid][equip_name] = ischeck
        if equip_name == "RH_SUB" then
            g.vakarine_equip_settings.chars[g.cid]["LH_SUB"] = ischeck
        elseif equip_name == "LH_SUB" then
            g.vakarine_equip_settings.chars[g.cid]["RH_SUB"] = ischeck
        end
        Vakarine_equip_config_frame_open()
    end
    Vakarine_equip_save_settings()
end

function Vakarine_equip_stat_update()
    if g.settings.vakarine_equip.use == 0 then
        return
    end
    g.vakarine_equip_is_vakarine = Vakarine_equip_is_vakarine()
    local charbaseinfo1_my = ui.GetFrame("charbaseinfo1_my")
    if not charbaseinfo1_my then
        return
    end
    local hp = GET_CHILD(charbaseinfo1_my, "pcHpGauge")
    AUTO_CAST(hp)
    local handle = session.GetMyHandle()
    local stat = info.GetStat(handle)
    local hp_now = (stat.HP * 100) / stat.maxHP
    local status = ''
    local color = ""
    if (hp_now == 100) then
        color = '#00EC00'
        status = 'Perfect'
    elseif g.vakarine_equip_is_vakarine and (hp_now <= 45) then
        color = '#EA0000'
        status = 'Revenge'
    elseif not g.vakarine_equip_is_vakarine and (hp_now <= 35) then
        color = '#EA0000'
        status = 'Revenge'
    elseif hp_now == 0 then
        color = '#FFFFFF'
    else
        color = '#FFFFFF'
    end
    local effecttext =
        charbaseinfo1_my:CreateOrGetControl("richtext", "effecttext", 0, 0, hp:GetWidth(), hp:GetHeight())
    effecttext:SetText(string.format('{ol}{%s}{%s}%s', "s15", color, status))
    effecttext:SetGravity(ui.RIGHT, ui.TOP)
    effecttext:SetOffset(hp:GetX(), hp:GetY() - 25 - (15 - 15))
    local hptext = charbaseinfo1_my:CreateOrGetControl("richtext", "hptext", 0, 0, hp:GetWidth(), hp:GetHeight())
    hptext:SetText(string.format('{%s}{ol}{%s}%d%%', "s15", color, hp_now))
    hptext:SetGravity(ui.RIGHT, ui.TOP)
    hptext:SetOffset(hp:GetX(), hp:GetY() - 10 - (15 - 15))
end

function Vakarine_equip_BUFF_ON_MSG(frame, msg, str, buff_id)
    if g.settings.vakarine_equip.use == 0 then
        return
    end
    if g.vakarine_equip_settings and g.vakarine_equip_settings["buffid"] then
        for id_str, val in pairs(g.vakarine_equip_settings["buffid"]) do
            if tonumber(id_str) == buff_id then
                if g.vakarine_equip_settings.auto_remove == 1 then
                    if val and g.vakarine_equip_is_vakarine then
                        packet.ReqRemoveBuff(buff_id) -- 良くないね
                        return
                    end
                end
            end
        end
    end
end

function Vakarine_equip_buff_list(buff_list, ctrl, ctrl_text)
    local buff_list = ui.GetFrame(addon_name_lower .. "Vakarine_equip_buff_list")
    if not buff_list then
        buff_list = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "vakarine_equip_buff_list", 0, 0, 0, 0)
        AUTO_CAST(buff_list)
        buff_list:SetSkinName("test_frame_low")
        buff_list:Resize(500, 1060)
        buff_list:SetPos(150, 10)
        buff_list:SetLayerLevel(121)
        local search_edit = buff_list:CreateOrGetControl("edit", "search_edit", 40, 10, 305, 38)
        AUTO_CAST(search_edit)
        search_edit:SetFontName("white_18_ol")
        search_edit:SetTextAlign("left", "center")
        search_edit:SetSkinName("inventory_serch")
        search_edit:SetEventScript(ui.ENTERKEY, "Vakarine_equip_buff_list_search")
        local search_btn = search_edit:CreateOrGetControl("button", "search_btn", 0, 0, 40, 38)
        AUTO_CAST(search_btn)
        search_btn:SetImage("inven_s")
        search_btn:SetGravity(ui.RIGHT, ui.TOP)
        search_btn:SetEventScript(ui.LBUTTONUP, "Vakarine_equip_buff_list_search")
        local func_toggle = buff_list:CreateOrGetControl('checkbox', 'func_toggle', 415, 15, 25, 25)
        AUTO_CAST(func_toggle)
        func_toggle:SetTextTooltip(g.lang == "Japanese" and "{ol}チェックすると自動バフ削除有効化" or
                                       "{ol}Check to enable auto buff removal")
        func_toggle:SetEventScript(ui.LBUTTONUP, "Vakarine_equip_buff_aoto_remove")
        func_toggle:SetCheck(g.vakarine_equip_settings.auto_remove or 0)
        local close = buff_list:CreateOrGetControl('button', 'close', 0, 0, 20, 20)
        AUTO_CAST(close)
        close:SetImage("testclose_button")
        close:SetGravity(ui.RIGHT, ui.TOP)
        close:SetEventScript(ui.LBUTTONUP, "Vakarine_equip_frame_close")
    end
    local buff_list_gb = buff_list:CreateOrGetControl("groupbox", "buff_list_gb", 10, 50, 480,
        buff_list:GetHeight() - 60)
    AUTO_CAST(buff_list_gb)
    buff_list_gb:SetSkinName("bg")
    buff_list_gb:RemoveAllChild()
    local cls_list, count = GetClassList("Buff")
    local all_buffs = {}
    for i = 0, count - 1 do
        local buff_cls = GetClassByIndexFromList(cls_list, i)
        if buff_cls then
            if buff_cls.Group1 ~= 'Debuff' and buff_cls.Group1 ~= 'Deuff' then
                local buff_name = dictionary.ReplaceDicIDInCompStr(buff_cls.Name)
                if not ctrl_text or ctrl_text == "" or string.find(buff_name, ctrl_text) then
                    local image_name = GET_BUFF_ICON_NAME(buff_cls)
                    if image_name ~= "icon_None" and buff_name ~= "None" then
                        local is_checked = g.vakarine_equip_settings["buffid"][tostring(buff_cls.ClassID)] == true
                        table.insert(all_buffs, {
                            cls = buff_cls,
                            name = buff_name,
                            image = image_name,
                            is_checked = is_checked
                        })
                    end
                end
            end
        end
    end
    table.sort(all_buffs, function(a, b)
        if a.is_checked and not b.is_checked then
            return true
        elseif not a.is_checked and b.is_checked then
            return false
        else
            return a.cls.ClassID < b.cls.ClassID
        end
    end)
    local y = 0
    for _, buff_data in ipairs(all_buffs) do
        local buff_cls = buff_data.cls
        local buff_id = buff_cls.ClassID
        local buff_slot = buff_list_gb:CreateOrGetControl('slot', 'buffslot' .. buff_id, 10, y + 5, 30, 30)
        AUTO_CAST(buff_slot)
        SET_SLOT_IMG(buff_slot, buff_data.image)
        local icon = CreateIcon(buff_slot)
        AUTO_CAST(icon)
        icon:SetTooltipType('buff')
        icon:SetTooltipArg(buff_data.name, buff_id, 0)
        local buff_check = buff_list_gb:CreateOrGetControl('checkbox', 'buff_check' .. buff_id, 50, y + 10, 200, 30)
        AUTO_CAST(buff_check)
        buff_check:SetText("{ol}" .. buff_id .. " : " .. buff_data.name)
        buff_check:SetTextTooltip(g.lang == "Japanese" and "{ol}チェックすると自動でバフ削除" or
                                      "{ol}Check to automatically remove buff")
        buff_check:SetCheck(buff_data.is_checked and 1 or 0)
        buff_check:SetEventScript(ui.LBUTTONUP, "Vakarine_equip_buff_toggle")
        buff_check:SetEventScriptArgString(ui.LBUTTONUP, buff_id)
        y = y + 35
    end
    buff_list:ShowWindow(1)
end

function Vakarine_equip_buff_list_search(buff_list, ctrl, ctrl_text, num)
    local search_edit = GET_CHILD_RECURSIVELY(buff_list, "search_edit")
    local ctrl_text = search_edit:GetText()
    if ctrl_text ~= "" then
        Vakarine_equip_buff_list(buff_list, ctrl, ctrl_text)
    else
        Vakarine_equip_buff_list(buff_list, ctrl, "")
    end
end

function Vakarine_equip_buff_aoto_remove()
    if g.vakarine_equip_settings.auto_remove == 0 then
        g.vakarine_equip_settings.auto_remove = 1
    else
        g.vakarine_equip_settings.auto_remove = 0
    end
    Vakarine_equip_save_settings()
end

function Vakarine_equip_buff_toggle(frame, ctrl, str_buff_id, num)
    local is_check = ctrl:IsChecked()
    if is_check == 1 then
        g.vakarine_equip_settings["buffid"][str_buff_id] = true
    else
        g.vakarine_equip_settings["buffid"][str_buff_id] = false
    end
    Vakarine_equip_save_settings()
end

function Vakarine_equip_frame_close(frame, ctrl, str, num)
    ui.DestroyFrame(frame:GetName())
end
-- vakarine_equip ここまで

