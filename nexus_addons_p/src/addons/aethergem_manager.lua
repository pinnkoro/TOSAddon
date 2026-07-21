-- Aethergem Manager　ここから
function Aethergem_manager_save_settings()
    g.save_json(g.aethergem_manager_path, g.aethergem_manager_settings)
end

function Aethergem_manager_load_settings()
    g.aethergem_manager_path = string.format("../addons/%s/%s/aethergem_manager.json", addon_name_lower, g.active_id)
    g.aethergem_manager_old_path = string.format("../addons/%s/%s.json", "aethergem_mgr", g.active_id)
    local changed = false
    local settings = g.load_json(g.aethergem_manager_path)
    if not settings then
        local old_settings = g.load_json(g.aethergem_manager_old_path)
        if old_settings then
            if old_settings then
                settings = {}
                for key, value in pairs(old_settings) do
                    if key ~= "delay" then
                        if tonumber(key) and string.len(key) < 3 then
                            if not settings.set then
                                settings.set = {}
                            end
                            settings.set[key] = value
                        else
                            if type(value) == "table" and value.use_index and type(value.use_index) == "string" then
                                value.use_index = value.use_index
                            end
                            settings[key] = value
                        end
                    end
                end
                changed = true
            end
        else
            settings = {
                set = {}
            }
            changed = true
        end
    end
    if not settings.set then
        settings.set = {}
        changed = true
    end
    for i = 1, 6 do
        local i_str = tostring(i)
        if not settings.set[i_str] then
            settings.set[i_str] = {}
            changed = true
        end
        for j = 1, 4 do
            local j_str = tostring(j)
            if not settings.set[i_str][j_str] then
                settings.set[i_str][j_str] = 0
                changed = true
            end
        end
    end
    if not g.aethergem_manager then
        g.aethergem_manager = {}
    end
    g.aethergem_manager_settings = settings
    if changed then
        Aethergem_manager_save_settings()
    end
end

function aethergem_manager_on_init()
    if not g.aethergem_manager_settings then
        Aethergem_manager_load_settings()
    end
    local old_func = g.settings.aethergem_manager.old_init_func
    if _G[old_func] then
        return
    end
    Aethergem_manager_frame_init()
end

function Aethergem_manager_frame_init()
    local inventory = ui.GetFrame('inventory')
    local item_cls = GetClassByType('Item', 850006)
    local icon_img = GET_ITEM_ICON_IMAGE(item_cls, 'Icon')
    local btn_pic = inventory:CreateOrGetControl('picture', "btn_pic", 470, 345, 30, 30)
    AUTO_CAST(btn_pic)
    btn_pic:SetImage(icon_img)
    btn_pic:SetEnableStretch(1)
    btn_pic:Resize(30, 30)
    btn_pic:SetTextTooltip(g.lang == "Japanese" and "{ol}右クリック：設定{nl}左クリック：作動" or
                               "{ol}Aethegem Manager{nl}Right click:Setup{nl}Left click:activation")
    btn_pic:SetEventScript(ui.RBUTTONUP, "Aethergem_manager_gem_setting")
    btn_pic:SetEventScript(ui.LBUTTONUP, "Aethergem_manager_operation")
    if g.settings.aethergem_manager.use == 0 then
        btn_pic:ShowWindow(0)
    else
        btn_pic:ShowWindow(1)
    end
end

function Aethergem_manager_gem_setting_close(setting_frame, close, str, num)
    ui.DestroyFrame(setting_frame:GetName())
end

function Aethergem_manager_gem_setting_rbtn(slotset, slot, i_str, j)
    local j_str = tostring(j)
    g.aethergem_manager_settings.set[i_str][j_str] = 0
    Aethergem_manager_save_settings()
    local inventory = ui.GetFrame('inventory')
    Aethergem_manager_gem_setting(inventory)
end

function Aethergem_manager_gem_setting_drop(slotset, slot, i_str, j)
    local lift_icon = ui.GetLiftIcon()
    local info = lift_icon:GetInfo()
    local clsid = info.type
    local item_cls = GetClassByType("Item", clsid)
    local name = item_cls.ClassName
    local j_str = tostring(j)
    local image = info:GetImageName()
    if string.find(image, "highcolorgem") then
        CreateIcon(slot)
        SET_SLOT_ITEM_CLS(slot, item_cls)
        local levels = {"520", "500", "480", "460"}
        local lv_text = slot:CreateOrGetControl('richtext', 'lv_text', 0, 25, 25, 25)
        AUTO_CAST(lv_text)
        for _, lv in ipairs(levels) do
            if string.find(name, lv) then
                lv_text:SetText("{ol}{s14}LV" .. lv)
                break
            end
        end
        g.aethergem_manager_settings.set[i_str][j_str] = clsid
        Aethergem_manager_save_settings()
    end
end

function Aethergem_manager_gem_setting_lbtn(gb, use_btn, i_str, num)
    if not next(g.aethergem_manager_settings.set[i_str]) then
        return
    end
    g.aethergem_manager_settings[g.cid].use_index = i_str
    Aethergem_manager_save_settings()
    local inventory = ui.GetFrame('inventory')
    Aethergem_manager_gem_setting(inventory)
end

function Aethergem_manager_gem_setting(inventory, btn_pic, str, num)
    local setting_frame = ui.CreateNewFrame("chat_memberlist", "Aethergem_manager_setting_frame", 0, 0, 0, 0)
    AUTO_CAST(setting_frame)
    -- 2560,1920
    setting_frame:SetSkinName("test_frame_low")
    local map_frame = ui.GetFrame("map")
    local map_width = map_frame:GetWidth()
    local x = map_width - inventory:GetWidth()
    setting_frame:Resize(300, 360)
    setting_frame:SetPos(x - setting_frame:GetWidth(), 500)
    setting_frame:SetLayerLevel(121)
    setting_frame:RemoveAllChild()
    local gb = setting_frame:CreateOrGetControl("groupbox", "gb", 10, 35, setting_frame:GetWidth() - 20,
        setting_frame:GetHeight() - 45)
    AUTO_CAST(gb)
    gb:SetSkinName("bg")
    local close = setting_frame:CreateOrGetControl('button', 'close', 0, 0, 20, 20)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Aethergem_manager_gem_setting_close")
    local title = setting_frame:CreateOrGetControl('richtext', 'title', 10, 10, 200, 30)
    AUTO_CAST(title)
    title:SetText("{ol}Aether Gem Setting")
    for i = 1, 6 do
        local slotset = gb:CreateOrGetControl('slotset', 'slotset' .. i, 85, 10 + (i - 1) * 50, 0, 0)
        AUTO_CAST(slotset)
        slotset:EnablePop(1)
        slotset:EnableDrag(1)
        slotset:EnableDrop(1)
        slotset:EnableHitTest(1)
        slotset:SetColRow(4, 1)
        slotset:SetSlotSize(45, 45)
        slotset:SetSpc(2, 2)
        slotset:SetSkinName('invenslot2')
        slotset:CreateSlots()
        local i_str = tostring(i)
        local slot_count = slotset:GetSlotCount()
        for j = 1, slot_count do
            local slot = GET_CHILD(slotset, "slot" .. j)
            AUTO_CAST(slot)
            slot:EnableDrop(1)
            local j_str = tostring(j)
            local clsid = g.aethergem_manager_settings.set[i_str][j_str]
            if clsid and clsid ~= 0 then
                local item_cls = GetClassByType("Item", clsid)
                if item_cls then
                    local name = item_cls.ClassName
                    CreateIcon(slot)
                    SET_SLOT_ITEM_CLS(slot, item_cls)
                    local levels = {"540", "520", "500", "480", "460"}
                    local skins = {"invenslot_pic_goddess", "invenslot_legend", "invenslot_unique", "invenslot_rare",
                                   "invenslot_nomal"}
                    local lv_text = slot:CreateOrGetControl('richtext', 'lv_text', 0, 25, 25, 25)
                    AUTO_CAST(lv_text)
                    for i, lv in ipairs(levels) do
                        if string.find(name, lv) then
                            lv_text:SetText("{ol}{s14}LV" .. lv)
                            slot:SetSkinName(skins[i])
                            break
                        end
                    end
                end
            end
            slot:SetEventScript(ui.RBUTTONUP, 'Aethergem_manager_gem_setting_rbtn')
            slot:SetEventScriptArgString(ui.RBUTTONUP, i_str)
            slot:SetEventScriptArgNumber(ui.RBUTTONUP, j)
            slot:SetEventScript(ui.DROP, 'Aethergem_manager_gem_setting_drop')
            slot:SetEventScriptArgString(ui.DROP, i_str)
            slot:SetEventScriptArgNumber(ui.DROP, j)
        end
        local use_btn = gb:CreateOrGetControl('button', "use_btn" .. i, 5, (i - 1) * 50 + 15, 75, 30)
        AUTO_CAST(use_btn)
        if not g.aethergem_manager_settings[g.cid] then
            g.aethergem_manager_settings[g.cid] = {
                use_index = "-1"
            }
        end
        if g.aethergem_manager_settings[g.cid].use_index == i_str then
            use_btn:SetSkinName("test_red_button")
            use_btn:SetText("{ol}use")
        else
            use_btn:SetSkinName("test_gray_button")
            use_btn:SetText("{ol}not use")
        end
        use_btn:SetEventScript(ui.LBUTTONUP, 'Aethergem_manager_gem_setting_lbtn')
        use_btn:SetEventScriptArgString(ui.LBUTTONUP, i_str)
    end
    Aethergem_manager_save_settings()
    INVENTORY_SET_CUSTOM_RBTNDOWN('Aethergem_manager_INV_RBTN')
    setting_frame:ShowWindow(1)
end

function Aethergem_manager_INV_RBTN(item_obj, slot, guid)
    for i = 1, 6 do
        local setting_frame = ui.GetFrame("Aethergem_manager_setting_frame")
        local slotset = GET_CHILD_RECURSIVELY(setting_frame, 'slotset' .. i)
        AUTO_CAST(slotset)
        local i_str = tostring(i)
        local slot_count = slotset:GetSlotCount()
        for j = 1, slot_count do
            local slot = GET_CHILD(slotset, "slot" .. j)
            AUTO_CAST(slot)
            local j_str = tostring(j)
            local clsid = g.aethergem_manager_settings.set[i_str][j_str]
            if clsid == 0 then
                local gem_clsid = item_obj.ClassID
                local item_cls = GetClassByType("Item", gem_clsid)
                if item_cls then
                    local name = item_cls.ClassName
                    CreateIcon(slot)
                    SET_SLOT_ITEM_CLS(slot, item_cls)
                    local levels = {"540", "520", "500", "480", "460"}
                    local skins = {"invenslot_pic_goddess", "invenslot_legend", "invenslot_unique", "invenslot_rare",
                                   "invenslot_nomal"}
                    local lv_text = slot:CreateOrGetControl('richtext', 'lv_text', 0, 25, 25, 25)
                    AUTO_CAST(lv_text)
                    for i, lv in ipairs(levels) do
                        if string.find(name, lv) then
                            lv_text:SetText("{ol}{s14}LV" .. lv)
                            slot:SetSkinName(skins[i])
                            g.aethergem_manager_settings.set[i_str][j_str] = gem_clsid
                            Aethergem_manager_save_settings()
                            return
                        end
                    end
                end
            end
        end
    end
end

function Aethergem_manager_equip(btn_pic)
    local inventory = btn_pic:GetTopParentFrame()
    if inventory:IsVisible() == 0 then
        btn_pic:StopUpdateScript("Aethergem_manager_equip")
    end
    local step = btn_pic:GetUserIValue("STEP")
    local goddess_equip_manager = ui.GetFrame("goddess_equip_manager")
    local spot_nums = {8, 9, 30}
    local equips = {"RH", "LH", "RH_SUB", "LH_SUB"}
    if step <= 3 then
        local guid = g.aethergem_manager.guids[equips[step]]
        local equip_item = session.GetEquipItemByGuid(guid)
        if step == 3 then
            DO_WEAPON_SLOT_CHANGE(inventory, 2)
        end
        if not equip_item then
            btn_pic:SetUserValue("STEP", step + 1)
        else
            item.UnEquip(spot_nums[step])
        end
        return 1
    end
    local msg = g.lang == "Japanese" and "エーテルジェムソケットが空いていません" or
                    "The Aether Gem socket is unavailable"
    if step >= 4 and step <= 7 then
        local guid = g.aethergem_manager.guids[equips[step - 3]]
        local gem_guid = g.aethergem_manager.gems[step - 3].iesid
        local inv_item = session.GetInvItemByGuid(guid)
        if inv_item then
            local item_obj = GetIES(inv_item:GetObject())
            local aether_available = item_goddess_socket.enable_aether_socket_add(item_obj)
            if aether_available == false then
                GODDESS_MGR_SOCKET_REG_ITEM(goddess_equip_manager, inv_item, item_obj)
            else
                GODDESS_EQUIP_MANAGER_CLOSE(goddess_equip_manager)
                ui.SysMsg(msg)
                return 0
            end
            local gem_item = session.GetInvItemByGuid(gem_guid)
            if gem_item then
                local gem_obj = GetIES(gem_item:GetObject())
                local ctrl_set = GET_CHILD_RECURSIVELY(goddess_equip_manager, 'AETHER_CSET_0')
                local gem_id = ctrl_set:GetUserIValue('GEM_ID')
                if gem_id == 0 then
                    local gem_slot = GET_CHILD(ctrl_set, 'gem_slot')
                    GODDESS_MGR_SOCKET_AETHER_GEM_EQUIP(ctrl_set, gem_slot, gem_item, gem_obj)
                end
                return 1
            else
                local spot_name = equips[step - 3]
                if step == 4 then
                    DO_WEAPON_SLOT_CHANGE(inventory, 1)
                elseif step == 6 then
                    DO_WEAPON_SLOT_CHANGE(inventory, 2)
                end
                ITEM_EQUIP(inv_item.invIndex, spot_name)
                return 1
            end
        else
            btn_pic:SetUserValue("STEP", step + 1)
            return 1
        end
    end
    Aethergem_manager_end_operation(goddess_equip_manager, inventory)
    return 0
end

function Aethergem_manager_unequip(btn_pic)
    local inventory = btn_pic:GetTopParentFrame()
    if inventory:IsVisible() == 0 then
        btn_pic:StopUpdateScript("Aethergem_manager_unequip")
    end
    local step = btn_pic:GetUserIValue("STEP")
    local goddess_equip_manager = ui.GetFrame("goddess_equip_manager")
    local spot_nums = {8, 9, 30}
    local equips = {"RH", "LH", "RH_SUB", "LH_SUB"}
    if step <= 3 then
        local guid = g.aethergem_manager.guids[equips[step]]
        local equip_item = session.GetEquipItemByGuid(guid)
        if step == 3 then
            DO_WEAPON_SLOT_CHANGE(inventory, 2)
        end
        if not equip_item then
            btn_pic:SetUserValue("STEP", step + 1)
        else
            item.UnEquip(spot_nums[step])
        end
        return 1
    end
    if step >= 4 and step <= 7 then
        local gem_index = 2 -- エーテルジェムは2
        local guid = g.aethergem_manager.guids[equips[step - 3]]
        local inv_item = session.GetInvItemByGuid(guid)
        if inv_item then
            local item_obj = GetIES(inv_item:GetObject())
            GODDESS_MGR_SOCKET_REG_ITEM(goddess_equip_manager, inv_item, item_obj)
            local gem_id = inv_item:GetEquipGemID(gem_index)
            if not gem_id or gem_id ~= 0 then
                _GODDESS_MGR_SOCKET_REQ_GEM_REMOVE(gem_index)
            else
                local spot_name = equips[step - 3]
                if step == 4 then
                    DO_WEAPON_SLOT_CHANGE(inventory, 1)
                elseif step == 6 then
                    DO_WEAPON_SLOT_CHANGE(inventory, 2)
                end
                ITEM_EQUIP(inv_item.invIndex, spot_name)
            end
            return 1
        else
            btn_pic:SetUserValue("STEP", step + 1)
        end
        return 1
    end
    Aethergem_manager_end_operation(goddess_equip_manager, inventory)
    return 0
end

function Aethergem_manager_operation_start(is_equip, btn_pic)
    local goddess_equip_manager = ui.GetFrame("goddess_equip_manager")
    if goddess_equip_manager:IsVisible() == 0 then
        help.RequestAddHelp('TUTO_GODDESSEQUIP_1')
        goddess_equip_manager:ShowWindow(1)
        local main_tab = GET_CHILD_RECURSIVELY(goddess_equip_manager, 'main_tab')
        main_tab:SelectTab(2)
        GODDESS_MGR_SOCKET_OPEN(goddess_equip_manager)
        GODDESS_EQUIP_UI_TUTORIAL_CHECK(goddess_equip_manager)
    end
    item.UnEquip(8)
    btn_pic:SetUserValue("STEP", 1)
    if is_equip then
        btn_pic:RunUpdateScript("Aethergem_manager_equip", 0.1)
    else
        btn_pic:RunUpdateScript("Aethergem_manager_unequip", 0.1)
    end
end

function Aethergem_manager_end_operation(goddess_equip_manager, inventory)
    DO_WEAPON_SLOT_CHANGE(inventory, 1)
    GODDESS_MGR_SOCKET_CLEAR(goddess_equip_manager)
    goddess_equip_manager:ShowWindow(0)
    ui.SysMsg("[AGM]End of Operation")
end

function Aethergem_manager_operation(inventory, btn_pic)
    local setting_frame = ui.GetFrame("Aethergem_manager_setting_frame")
    if setting_frame then
        Aethergem_manager_gem_setting_close(setting_frame)
    end
    if TUTORIAL_CLEAR_CHECK(GetMyPCObject()) == false then
        ui.SysMsg(ClMsg('CanUseAfterTutorialClear'))
        return
    end
    g.aethergem_manager.guids = {}
    local equips = {"RH", "LH", "RH_SUB", "LH_SUB"}
    local count = 0
    local is_equip = true
    for _, slot_name in ipairs(equips) do
        local equip_slot = GET_CHILD_RECURSIVELY(inventory, slot_name)
        local icon = equip_slot:GetIcon()
        if icon then
            local icon_info = icon:GetInfo()
            local guid = icon_info:GetIESID()
            local equip_item = session.GetEquipItemByGuid(guid)
            local available = equip_item:IsAvailableSocket(2)
            if available then
                count = count + 1
                local gem_id = equip_item:GetEquipGemID(2)
                if gem_id ~= 0 then
                    is_equip = false
                end
                g.aethergem_manager.guids[slot_name] = guid
            end
        end
    end
    if count < 4 then
        ui.SysMsg(g.lang == "Japanese" and
                      "エーテルジェムソケットが開いた武器を4ケ所装備して使用してください" or
                      "Please equip 4 weapons with open Aether Gem sockets and use the feature")
        return
    end
    if is_equip then
        g.aethergem_manager.gems = {}
        local use_index = g.aethergem_manager_settings[g.cid].use_index
        session.ResetItemList()
        local inv_list = session.GetInvItemList()
        local inv_guid_list = inv_list:GetGuidList()
        local cnt = inv_guid_list:Count()
        local gem_count = 0
        for i = 0, cnt - 1 do
            local guid = inv_guid_list:Get(i)
            local inv_item = inv_list:GetItemByGuid(guid)
            local inv_obj = GetIES(inv_item:GetObject())
            local inv_clsid = inv_obj.ClassID
            for index, clsid in pairs(g.aethergem_manager_settings.set[use_index]) do
                if clsid == inv_clsid then
                    local level = get_current_aether_gem_level(inv_obj)
                    table.insert(g.aethergem_manager.gems, {
                        level = level,
                        iesid = guid,
                        clsid = clsid
                    })
                    gem_count = gem_count + 1
                    break
                end
            end
        end
        if gem_count < 4 then
            ui.SysMsg(g.lang == "Japanese" and "インベントリにエーテルジェムが4個ありません" or
                          "There are not 4 Aether Gem in the inventory")
            return
        end
        table.sort(g.aethergem_manager.gems, function(a, b)
            return a.level > b.level
        end)
        Aethergem_manager_operation_start(is_equip, btn_pic)
    else
        Aethergem_manager_operation_start(is_equip, btn_pic)
    end
end
-- Aethergem Manager　ここまで

