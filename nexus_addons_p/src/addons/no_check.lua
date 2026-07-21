-- no_check ここから
function no_check_on_init()
    No_check_inventory_frame_init()
    g.setup_hook_and_event(g.addon, "BEFORE_APPLIED_YESSCP_OPEN_BASIC_MSG",
        "No_check_BEFORE_APPLIED_YESSCP_OPEN_BASIC_MSG", false)
    g.setup_hook_and_event(g.addon, "CARD_SLOT_EQUIP", "No_check_CARD_SLOT_EQUIP", false)
    g.setup_hook_and_event(g.addon, "EQUIP_CARDSLOT_INFO_OPEN", "No_check_EQUIP_CARDSLOT_INFO_OPEN", false)
    g.setup_hook_and_event(g.addon, "EQUIP_GODDESSCARDSLOT_INFO_OPEN", "No_check_EQUIP_GODDESSCARDSLOT_INFO_OPEN", false)
    g.setup_hook_and_event(g.addon, "GODDESS_MGR_SOCKET_REQ_GEM_REMOVE", "No_check_GODDESS_MGR_SOCKET_REQ_GEM_REMOVE",
        false)
    g.setup_hook_and_event(g.addon, "UNLOCK_TRANSMUTATIONSPREADER_BELONGING_SCROLL_EXEC_ASK_AGAIN",
        "No_check_UNLOCK_TRANSMUTATIONSPREADER_BELONGING_SCROLL_EXEC_ASK_AGAIN", false)
    g.setup_hook_and_event(g.addon, "UNLOCK_ACC_BELONGING_SCROLL_EXEC_ASK_AGAIN",
        "No_check_UNLOCK_ACC_BELONGING_SCROLL_EXEC_ASK_AGAIN", false)
    g.setup_hook_and_event(g.addon, "SELECT_ZONE_MOVE_CHANNEL", "No_check_SELECT_ZONE_MOVE_CHANNEL", false)
    g.setup_hook_and_event(g.addon, "BEFORE_APPLIED_NON_EQUIP_ITEM_OPEN", "No_check_BEFORE_APPLIED_NON_EQUIP_ITEM_OPEN",
        false)
    g.setup_hook_and_event(g.addon, "INVENTORY_CLOSE", "No_check_frame_close", true)
    g.setup_hook_and_event(g.addon, "MORU_LBTN_CLICK", "No_check_MORU_LBTN_CLICK", true)
    if g.get_map_type() == "City" then
        local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
        _nexus_addons_p:RunUpdateScript("No_check_timer_update", 0.3)
    end
end

function No_check_inventory_frame_init()
    local inventory = ui.GetFrame("inventory")
    local inventory_btns = {"moncard_btn", "helper_btn", "cabinet_btn", "goddess_mgr_btn"}
    if inventory then
        for _, btn_name in ipairs(inventory_btns) do
            local btn = GET_CHILD_RECURSIVELY(inventory, btn_name)
            if btn and btn:IsVisible() == 0 then
                btn:ShowWindow(1)
            end
        end
    end
    local searchSkin = GET_CHILD_RECURSIVELY(inventory, "searchSkin")
    if g.settings.no_check.use == 1 then -- !
        local searchGbox = GET_CHILD_RECURSIVELY(inventory, "searchGbox")
        local btn = searchGbox:CreateOrGetControl("button", "btn", 160, -3, 35, 38)
        AUTO_CAST(btn)
        searchSkin:Resize(284, 30)
        searchSkin:SetMargin(38, 0, 0, 5)
        btn:SetSkinName("test_pvp_btn")
        local tool_tip = g.lang == "Japanese" and
                             "{ol}[No Check]{nl}左クリック: アイテム連続フレーム表示{nl}右クリック: ゴミ箱フレーム表示" or
                             "{ol}[No Check]{nl}Left Click: Item continuous frame display{nl}Right Click: Trash frame display"
        btn:SetTextTooltip(tool_tip)
        btn:SetText("{img equipment_info_btn_mark2 32 32}")
        btn:SetEventScript(ui.LBUTTONUP, "No_check_continuous_use_frame")
        btn:SetEventScript(ui.RBUTTONUP, "No_check_delete_item_frame")
    else
        searchSkin:Resize(317, 30)
        searchSkin:SetMargin(5, 0, 0, 5)
        local searchGbox = GET_CHILD_RECURSIVELY(inventory, "searchGbox")
        DESTROY_CHILD_BYNAME(searchGbox, "btn")
    end
end
-- アイテム連続使用
function No_check_continuous_use_frame(frame, ctrl, str, num)
    local inventory = ui.GetFrame("inventory")
    local no_check_use = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "no_check_use", 0, 0, 0, 0)
    AUTO_CAST(no_check_use)
    no_check_use:SetGravity(ui.RIGHT, ui.TOP)
    no_check_use:SetSkinName("test_win_lastpopup")
    local rect = no_check_use:GetMargin()
    no_check_use:SetMargin(rect.left - rect.left, rect.top - rect.top + 300,
        rect.right == 0 and rect.right + 310 + 200 or rect.right, rect.bottom)
    no_check_use:Resize(300, 300)
    no_check_use:RemoveAllChild()
    no_check_use:ShowWindow(1)
    local item_slot = no_check_use:CreateOrGetControl('slot', 'item_slot', 115, 100, 70, 70)
    AUTO_CAST(item_slot)
    item_slot:SetSkinName("slot")
    INVENTORY_SET_CUSTOM_RBTNDOWN("No_check_inv_rbtn")
    item_slot:SetEventScript(ui.RBUTTONUP, "No_check_use_icon_clear")
    local notice = no_check_use:CreateOrGetControl('richtext', 'notice', 30, 180, 0, 0)
    AUTO_CAST(notice)
    notice:SetText(g.lang == "Japanese" and "{ol}{s20}アイテムを連続使用します" or
                       "{ol}{s18}Use the item continuously")
    local continuous_use = no_check_use:CreateOrGetControl('button', 'continuous_use', 40, 220, 100, 50)
    AUTO_CAST(continuous_use)
    continuous_use:SetSkinName("test_red_button")
    continuous_use:SetText(g.lang == "Japanese" and "{ol}{s16}連続使用" or "{ol}{s16}Continu")
    continuous_use:SetEventScript(ui.LBUTTONUP, "No_check_continuous_use")
    local cancel = no_check_use:CreateOrGetControl('button', 'cancel', 155, 220, 100, 50)
    AUTO_CAST(cancel)
    cancel:SetSkinName("test_gray_button")
    cancel:SetText(g.lang == "Japanese" and "{ol}{s16}キャンセル" or "{ol}{s16}Cancel")
    cancel:SetEventScript(ui.LBUTTONUP, "No_check_frame_close")
end

function No_check_use_icon_clear(no_check_use, item_slot)
    CLEAR_SLOT_ITEM_INFO(item_slot)
end

function No_check_continuous_use(no_check_use, ctrl, str, num)
    local item_slot = GET_CHILD(no_check_use, "item_slot")
    AUTO_CAST(item_slot)
    local clsid = item_slot:GetUserIValue("CLASS_ID")
    if clsid == 0 then
        return
    end
    local inv_item = session.GetInvItemByType(clsid)
    if inv_item then
        no_check_use:SetUserValue("PREV_COUNT", -1)
        no_check_use:RunUpdateScript("No_check_icontinuous_use_result", 0.5)
    end
end

function No_check_icontinuous_use_result(no_check_use)
    local item_slot = GET_CHILD(no_check_use, "item_slot")
    AUTO_CAST(item_slot)
    local clsid = item_slot:GetUserIValue("CLASS_ID")
    local inv_item = session.GetInvItemByType(clsid)
    if inv_item then
        local current_count = inv_item.count
        local prev_count = no_check_use:GetUserIValue("PREV_COUNT")
        if prev_count ~= -1 and current_count == prev_count then
            No_check_use_icon_clear(no_check_use, item_slot)
            return 0 -- スクリプト停止
        end
        no_check_use:SetUserValue("PREV_COUNT", current_count)
        INV_ICON_USE(inv_item)
        local item_cls = GetClassByType("Item", clsid)
        SET_SLOT_ITEM_CLS(item_slot, item_cls)
        SET_SLOT_ITEM_TEXT(item_slot, inv_item, item_cls)
        return 1
    else
        No_check_use_icon_clear(no_check_use, item_slot)
    end
end
-- ゴミ箱フレーム
function No_check_delete_item_frame()
    local no_check_delete = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "no_check_delete", 0, 0, 10, 10)
    AUTO_CAST(no_check_delete)
    no_check_delete:SetSkinName("test_frame_low")
    no_check_delete:SetGravity(ui.RIGHT, ui.TOP)
    local rect = no_check_delete:GetMargin()
    no_check_delete:SetMargin(rect.left - rect.left, rect.top - rect.top + 100,
        rect.right == 0 and rect.right + 310 + 200 or rect.right, rect.bottom)
    no_check_delete:SetLayerLevel(100)
    no_check_delete:Resize(300, 698)
    no_check_delete:RemoveAllChild()
    local title = no_check_delete:CreateOrGetControl('richtext', 'title', 10, 15, 0, 0)
    AUTO_CAST(title)
    title:SetText(g.lang == "Japanese" and "{ol}{s18}ゴミ箱スロット" or "{ol}{s18}Discard item Slots")
    local close = no_check_delete:CreateOrGetControl("button", "close", 0, 0, 25, 25)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "No_check_frame_close")
    close:SetEventScriptArgString(ui.LBUTTONUP, "true")
    local delete_gb = no_check_delete:CreateOrGetControl("groupbox", "delete_gb", 10, 40, 380, 380)
    AUTO_CAST(delete_gb)
    delete_gb:SetSkinName("test_frame_midle_light")
    delete_gb:Resize(280, 600)
    no_check_delete:ShowWindow(1)
    local delete_slotset = delete_gb:CreateOrGetControl('slotset', 'delete_slotset', 0, 0, 0, 0)
    AUTO_CAST(delete_slotset)
    delete_slotset:SetSlotSize(40, 40)
    delete_slotset:EnablePop(0)
    delete_slotset:EnableDrag(1)
    delete_slotset:EnableDrop(1)
    delete_slotset:SetColRow(7, 15)
    delete_slotset:SetSpc(0, 0)
    delete_slotset:SetSkinName('slot')
    delete_slotset:CreateSlots()
    local slot_count = delete_slotset:GetSlotCount()
    local go_func = no_check_delete:CreateOrGetControl("button", "go_func", 0, 0, 100, 43)
    AUTO_CAST(go_func)
    go_func:SetText(g.lang == "Japanese" and "{ol}{s16}スタート" or "{ol}{s16}START")
    go_func:SetMargin(190, 645, 100, 0)
    go_func:SetSkinName("test_red_button")
    go_func:SetEventScript(ui.LBUTTONUP, "No_check_delete_item_msgbox")
    local stop_func = no_check_delete:CreateOrGetControl("button", "stop_func", 0, 0, 100, 43)
    AUTO_CAST(stop_func)
    stop_func:SetText(g.lang == "Japanese" and "{ol}{s16}ストップ" or "{ol}{s16}STOP")
    stop_func:SetMargin(10, 645, 100, 0)
    stop_func:SetSkinName("test_gray_button")
    stop_func:SetEventScript(ui.LBUTTONUP, "No_check_frame_close")
    INVENTORY_SET_CUSTOM_RBTNDOWN("No_check_inv_rbtn")
    g.no_check_iesids = {}
end

function No_check_delete_item_clear(parent, slot, iesid, num)
    CLEAR_SLOT_ITEM_INFO(slot)
    slot:SetSkinName('slot')
    slot:SetUserValue("DELETE_IDSID", "None")
    slot:SetUserValue("DELETE_NAME", "None")
    slot:SetUserValue("DELETE_COUNT", 0)
    g.no_check_iesids[iesid] = nil
    local inventory = ui.GetFrame("inventory")
    local inv_slot = INV_GET_SLOT_BY_ITEMGUID(iesid)
    if inv_slot then
        AUTO_CAST(inv_slot)
        inv_slot:Select(0)
        inv_slot:RunUpdateScript("No_check_inv_invalidate", 0.1)
        inv_slot:Invalidate()
    end
end

function No_check_delete_check(iesid, cls_id)
    if GetCraftState() == 1 then
        return false
    end
    if true == BEING_TRADING_STATE() then
        return false
    end
    local inventory = ui.GetFrame("inventory")
    local inv_item = session.GetInvItemByGuid(iesid)
    if not inv_item then
        return false
    end
    if true == inv_item.isLockState or true == IS_TEMP_LOCK(inventory, inv_item) then
        ui.SysMsg(ClMsg("MaterialItemIsLock"))
        return false
    end
    local item_cls = GetClassByType("Item", cls_id)
    if not item_cls then
        return false
    end
    local item_prop = geItemTable.IsDestroyable(cls_id)
    if item_cls.Destroyable == 'NO' or item_prop == false then
        local item_obj = GetIES(inv_item:GetObject())
        if item_obj.ItemLifeTimeOver == 0 then
            ui.AlarmMsg("ItemIsNotDestroy")
            return false
        end
    end
    return true
end

function No_check_delete_item_msgbox()
    local yes_scp = string.format("No_check_delete_item_reserve()")
    local msg = g.lang == "Japanese" and
                    "{ol}{#FF0000}本当にゴミ捨てを開始しますか？{nl}(リカバリーサービス対象外かも)" or
                    "{ol}{#FF0000}Are you sure you want to start trashing?{nl}(might not be covered by the{nl} recovery service)"
    ui.MsgBox(msg, yes_scp, "None")
end

function No_check_delete_item_reserve()
    local no_check_delete = ui.GetFrame(addon_name_lower .. "no_check_delete")
    No_check_delete_item(no_check_delete)
    no_check_delete:RunUpdateScript("No_check_delete_item", 0.5)
end

function No_check_delete_item(no_check_delete)
    if no_check_delete and no_check_delete:IsVisible() == 0 then
        return 0
    end
    local delete_slotset = GET_CHILD_RECURSIVELY(no_check_delete, "delete_slotset")
    AUTO_CAST(delete_slotset)
    local slot_count = delete_slotset:GetSlotCount()
    for i = 1, slot_count do
        local slot = GET_CHILD(delete_slotset, "slot" .. i)
        AUTO_CAST(slot)
        local icon = slot:GetIcon()
        if icon then
            local iesid = slot:GetUserValue("DELETE_IDSID")
            local name = slot:GetUserValue("DELETE_NAME")
            local count = slot:GetUserIValue("DELETE_COUNT")
            local trans_name = dic.getTranslatedStr(name)
            No_check_delete_item_execute(slot, iesid, trans_name, count)
            return 1
        end
    end
    No_check_frame_close(no_check_delete, delete_slotset)
    return 0
end

function No_check_delete_item_execute(slot, iesid, trans_name, count)
    IMC_LOG("INFO_NORMAL", "EXEC_DELETE_ITEMDROP")
    local pc = GetMyPCObject()
    local msg = g.lang == "Japanese" and "{ol}{#FFFF00}[" .. trans_name .. "]{/}{ol}{#FFFFFF}を" .. "{ol}{#FFFF00}[" ..
                    count .. "個]{/}" .. "{ol}{#FFFFFF}捨てました" or "{ol}{#FFFFFF}Discarded {/}" ..
                    "{ol}{#FFFF00}[" .. count .. "]{ol}{#FFFFFF} piece " .. "{ol}{#FFFF00}[" .. trans_name .. "]{/}"
    imcAddOn.BroadMsg("NOTICE_Dm_!", msg, 0.4)
    item.DropDelete(iesid, count)
    No_check_delete_item_clear(nil, slot, iesid, nil)
end
-- 連続使用とゴミ捨ての共通。インベントリマウス制御
function No_check_inv_rbtn(item_obj, slot)
    local icon = slot:GetIcon()
    local icon_info = icon:GetInfo()
    local no_check_use = ui.GetFrame(addon_name_lower .. "no_check_use")
    if no_check_use and no_check_use:IsVisible() == 1 then
        local clsid = icon_info.type
        local inv_item = session.GetInvItemByType(clsid)
        local item_slot = GET_CHILD(no_check_use, "item_slot")
        local item_cls = GetClassByType("Item", clsid)
        item_slot:SetUserValue("CLASS_ID", clsid)
        SET_SLOT_ITEM_CLS(item_slot, item_cls)
        SET_SLOT_ITEM_TEXT(item_slot, inv_item, item_cls)
        return
    end
    local no_check_delete = ui.GetFrame(addon_name_lower .. "no_check_delete")
    if no_check_delete and no_check_delete:IsVisible() == 1 then
        AUTO_CAST(no_check_delete)
        local iesid = icon_info:GetIESID()
        local inv_item = session.GetInvItemByGuid(iesid)
        local item_obj = GetIES(inv_item:GetObject())
        if g.no_check_iesids[iesid] then
            local msg = g.lang == "Japanese" and "{ol}既に登録されています" or "{ol}Already registered"
            ui.SysMsg(msg)
            return
        end
        if not No_check_delete_check(iesid, item_obj.ClassID) then
            return
        end
        local delete_slotset = GET_CHILD_RECURSIVELY(no_check_delete, "delete_slotset")
        AUTO_CAST(delete_slotset)
        local slot_count = delete_slotset:GetSlotCount()
        for i = 1, slot_count do
            local slot = GET_CHILD(delete_slotset, "slot" .. i)
            AUTO_CAST(slot)
            local icon = slot:GetIcon()
            if not icon then
                icon = CreateIcon(slot)
                slot:SetUserValue("DELETE_IDSID", iesid)
                slot:SetUserValue("DELETE_NAME", item_obj.Name)
                slot:SetUserValue("DELETE_COUNT", inv_item.count)
                g.no_check_iesids[iesid] = true
                SET_SLOT_ITEM_CLS(slot, item_obj)
                SET_SLOT_ITEM_TEXT(slot, inv_item, item_obj)
                SET_SLOT_STYLESET(slot, item_obj)
                SET_SLOT_IESID(slot, iesid)
                SET_SLOT_ICOR_CATEGORY(slot, item_obj)
                icon:SetTooltipArg("None", 0, iesid)
                SET_ITEM_TOOLTIP_TYPE(icon, item_obj.ClassID, item_obj, "None")
                SET_SLOT_ICOR_CATEGORY(slot, item_obj)
                slot:SetEventScript(ui.RBUTTONUP, "No_check_delete_item_clear")
                slot:SetEventScriptArgString(ui.RBUTTONUP, iesid)
                local inventory = ui.GetFrame("inventory")
                local inv_slot = INV_GET_SLOT_BY_ITEMGUID(iesid)
                if inv_slot then
                    AUTO_CAST(inv_slot)
                    inv_slot:SetSelectedImage('socket_slot_check')
                    inv_slot:Select(1)
                    inv_slot:RunUpdateScript("No_check_inv_invalidate", 0.1)
                    inv_slot:Invalidate()
                end
                return
            end
        end
    end
end

function No_check_frame_close(frame, ctrl)
    if frame:GetName() ~= "_nexus_addons_p" then
        ui.DestroyFrame(frame:GetName())
    end
    INVENTORY_SET_CUSTOM_RBTNDOWN('None')
    INVENTORY_CLEAR_SELECT(nil)
    if ctrl:GetName() == "delete_slotset" then
        ui.SysMsg("{ol}[No Check]End of Operation")
    end
end

function No_check_inv_invalidate(inv_slot)
    inv_slot:Invalidate()
end
-- 欠片アイテム他使用時のメッセージボックス非表示
function No_check_BEFORE_APPLIED_YESSCP_OPEN_BASIC_MSG(my_frame, my_msg)
    local inv_item = g.get_event_args(my_msg)
    if g.settings.no_check.use == 1 then
        if not inv_item then
            return
        end
        local item_obj = GetIES(inv_item:GetObject())
        if not item_obj then
            return
        end
        local inventory = ui.GetFrame("inventory")
        inventory:SetUserValue("REQ_USE_ITEM_GUID", inv_item:GetIESID())
        REQUEST_SUMMON_BOSS_TX()
    else
        g.FUNCS["BEFORE_APPLIED_YESSCP_OPEN_BASIC_MSG"](inv_item)
    end
end
-- レジェンドカード装着時のメッセージボックス非表示
function No_check_CARD_SLOT_EQUIP(my_frame, my_msg)
    local slot, item, group_name_str = g.get_event_args(my_msg)
    if g.settings.no_check.use == 1 then
        local item_obj = GetIES(item:GetObject())
        if item_obj.GroupName == "Card" then
            local slot_index = CARD_SLOT_GET_SLOT_INDEX(group_name_str, slot:GetSlotIndex())
            local card_info = equipcard.GetCardInfo(slot_index + 1)
            if card_info then
                ui.SysMsg(ClMsg("AlreadyEquippedThatCardSlot"))
                return
            end
            if item.isLockState == true then
                ui.SysMsg(ClMsg("MaterialItemIsLock"))
                return
            end
            local item_guid = item:GetIESID()
            local inventory = ui.GetFrame("inventory")
            inventory:SetUserValue("EQUIP_CARD_GUID", item_guid)
            inventory:SetUserValue("EQUIP_CARD_SLOTINDEX", slot_index)
            local pc_etc = GetMyEtcObject()
            if pc_etc.IS_LEGEND_CARD_OPEN ~= 1 and group_name_str == 'LEG' then
                ui.SysMsg(ClMsg("LegendCard_Slot_NotOpen"))
                return
            end
            REQUEST_EQUIP_CARD_TX()
        end
    else
        g.FUNCS["CARD_SLOT_EQUIP"](slot, item, group_name_str)
    end
end
-- レジェンドカード脱着時
function No_check_EQUIP_CARDSLOT_INFO_OPEN(my_frame, my_msg)
    local slot_index = g.get_event_args(my_msg)
    if g.settings.no_check.use == 1 then
        slot_index = slot_index .. " 1"
        pc.ReqExecuteTx_NumArgs("SCR_TX_UNEQUIP_CARD_SLOT", slot_index)
    else
        g.FUNCS["EQUIP_CARDSLOT_INFO_OPEN"](slot_index)
    end
end
-- ゴッデスカード脱着時
function No_check_EQUIP_GODDESSCARDSLOT_INFO_OPEN(my_frame, my_msg)
    local slot_index = g.get_event_args(my_msg)
    if g.settings.no_check.use == 1 then
        slot_index = slot_index .. " 1"
        pc.ReqExecuteTx_NumArgs("SCR_TX_UNEQUIP_CARD_SLOT", slot_index)
    else
        g.FUNCS["EQUIP_GODDESSCARDSLOT_INFO_OPEN"](slot_index)
    end
end
-- エーテルジェム着脱時のメッセージ非表示
function No_check_GODDESS_MGR_SOCKET_REQ_GEM_REMOVE(my_frame, my_msg)
    local parent, btn = g.get_event_args(my_msg)
    if g.settings.no_check.use == 1 then
        local frame = parent:GetTopParentFrame()
        local slot = GET_CHILD_RECURSIVELY(frame, 'socket_slot')
        local guid = slot:GetUserValue('ITEM_GUID')
        if guid ~= 'None' then
            local index = parent:GetUserValue('SLOT_INDEX')
            local inv_item = session.GetInvItemByGuid(guid)
            if not inv_item then
                return
            end
            local item_obj = GetIES(inv_item:GetObject())
            local item_name = dic.getTranslatedStr(TryGetProp(item_obj, 'Name', 'None'))
            local gem_id = inv_item:GetEquipGemID(index)
            local gem_cls = GetClassByType('Item', gem_id)
            local gem_numarg1 = TryGetProp(gem_cls, 'NumberArg1', 0)
            local price = gem_numarg1 * 100
            local clmsg = 'None'
            local msg_cls_name = ''
            if TryGetProp(gem_cls, 'GemType', 'None') == 'Gem_High_Color' then
                _GODDESS_MGR_SOCKET_REQ_GEM_REMOVE(index)
            else
                local pc = GetMyPCObject()
                local is_gem_remove_care = IS_GEM_EXTRACT_FREE_CHECK(pc)
                local free_gem = nil
                for optionIdx = 1, 4 do
                    free_gem = GET_GEM_PROPERTY_TEXT(item_obj, optionIdx, index)
                    if free_gem then
                        _GODDESS_MGR_SOCKET_REQ_GEM_REMOVE(index)
                        return
                    end
                end
                if is_gem_remove_care then
                    msg_cls_name = "ReallyRemoveGem_Care"
                else
                    msg_cls_name = "ReallyRemoveGem"
                end
                local clmsg = "'" .. item_name .. ScpArgMsg("Auto_'_SeonTaeg") .. ScpArgMsg(msg_cls_name)
                local yes_scp = string.format('_GODDESS_MGR_SOCKET_REQ_GEM_REMOVE(%s)', index)
                local msgbox = ui.MsgBox(clmsg, yes_scp, '')
                SET_MODAL_MSGBOX(msgbox)
            end
        end
    else
        g.FUNCS["GODDESS_MGR_SOCKET_REQ_GEM_REMOVE"](parent, btn)
    end
end
-- ゴッデス装備帰属解除時の簡易化
function No_check_UNLOCK_TRANSMUTATIONSPREADER_BELONGING_SCROLL_EXEC_ASK_AGAIN(my_frame, my_msg)
    local frame, btn = g.get_event_args(my_msg)
    if g.settings.no_check.use == 1 then
        local scroll_type = frame:GetUserValue("ScrollType")
        local clickable = frame:GetUserValue("EnableTranscendButton")
        if tonumber(clickable) ~= 1 then
            return
        end
        local slot = GET_CHILD(frame, "slot")
        local inv_item = GET_SLOT_ITEM(slot)
        if not inv_item then
            ui.MsgBox(ScpArgMsg("DropItemPlz"))
            imcSound.PlaySoundEvent(frame:GetUserConfig("TRANS_BTN_OVER_SOUND"))
            return
        end
        local item_obj = GetIES(inv_item:GetObject())
        local scroll_guid = frame:GetUserValue("ScrollGuid")
        local scroll_inv_item = session.GetInvItemByGuid(scroll_guid)
        if not scroll_inv_item then
            return
        end
        UNLOCK_TRANSMUTATIONSPREADER_BELONGING_SCROLL_EXEC()
    else
        g.FUNCS["UNLOCK_TRANSMUTATIONSPREADER_BELONGING_SCROLL_EXEC_ASK_AGAIN"](frame, btn)
    end
end
-- ゴッデスアクセ帰属解除時の簡易化
function No_check_UNLOCK_ACC_BELONGING_SCROLL_EXEC_ASK_AGAIN(my_frame, my_msg)
    local frame, btn = g.get_event_args(my_msg)
    if g.settings.no_check.use == 1 then
        local scroll_type = frame:GetUserValue("ScrollType")
        local clickable = frame:GetUserValue("EnableTranscendButton")
        if tonumber(clickable) ~= 1 then
            return
        end
        local slot = GET_CHILD(frame, "slot")
        local inv_item = GET_SLOT_ITEM(slot)
        if not inv_item then
            ui.MsgBox(ScpArgMsg("DropItemPlz"))
            imcSound.PlaySoundEvent(frame:GetUserConfig("TRANS_BTN_OVER_SOUND"))
            return
        end
        local item_obj = GetIES(inv_item:GetObject())
        local scroll_guid = frame:GetUserValue("ScrollGuid")
        local scroll_inv_item = session.GetInvItemByGuid(scroll_guid)
        if not scroll_inv_item then
            return
        end
        UNLOCK_ACC_BELONGING_SCROLL_EXEC()
    else
        g.FUNCS["UNLOCK_ACC_BELONGING_SCROLL_EXEC_ASK_AGAIN"](frame, btn)
    end
end
-- チャンネル移動時の確認を削除
function No_check_SELECT_ZONE_MOVE_CHANNEL(my_frame, my_msg)
    local index, channel_id = g.get_event_args(my_msg)
    if g.settings.no_check.use == 1 then
        local zone_insts = session.serverState.GetMap()
        if not zone_insts or zone_insts.pcCount == -1 then
            ui.SysMsg(ClMsg("ChannelIsClosed"))
            return
        end
        local pc = GetMyPCObject()
        if IS_BOUNTY_BATTLE_BUFF_APPLIED(pc) == 1 then
            ui.SysMsg(ClMsg("DoingBountyBattle"))
            return
        end
        if IS_JUMP_MAP_BUFF_APPLIED(pc) == 1 then
            return
        end
        RUN_GAMEEXIT_TIMER("Channel", channel_id)
    else
        g.FUNCS["SELECT_ZONE_MOVE_CHANNEL"](index, channel_id)
    end
end
-- カードブック使用時の確認削除
function No_check_BEFORE_APPLIED_NON_EQUIP_ITEM_OPEN(my_frame, my_msg)
    local inv_item = g.get_event_args(my_msg)
    if g.settings.no_check.use == 1 then
        if not inv_item then
            return
        end
        local inventory = ui.GetFrame("inventory")
        local item_obj = GetIES(inv_item:GetObject())
        if not item_obj then
            return
        end
        inventory:SetUserValue("REQ_USE_ITEM_GUID", inv_item:GetIESID())
        if item_obj.Script == 'SCR_SUMMON_MONSTER_FROM_CARDBOOK' then
            REQUEST_SUMMON_BOSS_TX()
        elseif item_obj.Script == 'SCR_QUEST_CLEAR_LEGEND_CARD_LIFT' then
            local textmsg = string.format("[ %s ]{nl}%s", item_obj.Name, ScpArgMsg("Use_Item_LegendCard_Slot_Open2"))
            ui.MsgBox_NonNested(textmsg, item_obj.Name, "REQUEST_SUMMON_BOSS_TX", "None")
            return
        end
    else
        g.FUNCS["BEFORE_APPLIED_NON_EQUIP_ITEM_OPEN"](inv_item)
    end
end

function No_check_timer_update(_nexus_addons_p, no_check_timer)
    if g.settings.no_check.use == 0 then
        return 0
    end
    No_check_WARNINGMSGBOX_FRAME_OPEN()
    No_check_WARNINGMSGBOX_EX_FRAME_OPEN()
    return 1
end
-- warning_boxs制御
function No_check_WARNINGMSGBOX_FRAME_OPEN()
    local warningmsgbox = ui.GetFrame("warningmsgbox")
    if warningmsgbox:IsVisible() == 0 then
        return
    end
    local warningtext = GET_CHILD_RECURSIVELY(warningmsgbox, "warningtext")
    local msg = ClMsg("destory_now")
    msg = dictionary.ReplaceDicIDInCompStr(msg)
    if string.find(warningtext:GetText(), msg) then
        local input = GET_CHILD_RECURSIVELY(warningmsgbox, "input")
        input:SetText(msg)
    end
end

function No_check_WARNINGMSGBOX_EX_FRAME_OPEN()
    local warningmsgbox_ex = ui.GetFrame('warningmsgbox_ex')
    if warningmsgbox_ex:IsVisible() == 0 then
        return
    end
    local compareText = GET_CHILD_RECURSIVELY(warningmsgbox_ex, "comparetext")
    local start, finish = string.find(compareText:GetText(), "nl%}%[")
    if start and finish then
        local next_sub_string = compareText:GetText():sub(finish + 1)
        local next_start, next_finish = string.find(next_sub_string, "%]")
        if next_start and next_finish then
            local desiredText = next_sub_string:sub(1, next_start - 1)
            local input = GET_CHILD_RECURSIVELY(warningmsgbox_ex, "input")
            input:SetText(desiredText)
        end
    end
end
-- 連続金床強化
function No_check_MORU_LBTN_CLICK(my_frame, my_msg)
    if g.settings.no_check.use == 0 then
        return
    end
    No_check_REINFORCE_131014_MSGBOX()
end

function No_check_REINFORCE_131014_MSGBOX()
    local reinforce_131014 = ui.GetFrame("reinforce_131014")
    local from_item, from_moru = GET_REINFORCE_TARGET_AND_MORU(reinforce_131014)
    local from_item_obj = GetIES(from_item:GetObject())
    local moru_obj = GetIES(from_moru:GetObject())
    local exec = GET_CHILD_RECURSIVELY(reinforce_131014, "exec")
    local skipOver5 = GET_CHILD_RECURSIVELY(reinforce_131014, "skipOver5")
    skipOver5:SetCheck(1)
    exec:ShowWindow(0)
    No_check_REINFORCE_131014_EXEC(reinforce_131014, from_item, from_moru)
end

function No_check_REINFORCE_131014_EXEC(reinforce_131014)
    if reinforce_131014:IsVisible() == 0 then
        reinforce_131014:StopUpdateScript("No_check_REINFORCE_131014_EXEC")
        return 0
    end
    local from_item, from_moru = GET_REINFORCE_TARGET_AND_MORU(reinforce_131014)
    if from_item and from_moru ~= nil and reinforce_131014:IsVisible() == 1 then
        session.ResetItemList()
        session.AddItemID(from_item:GetIESID())
        session.AddItemID(from_moru:GetIESID())
        local resultlist = session.GetItemIDList()
        item.DialogTransaction("ITEM_REINFORCE_131014", resultlist)
        reinforce_131014:RunUpdateScript("No_check_REINFORCE_131014_EXEC", 0.3)
    end
    REINFORCE_131014_UPDATE_MORU_COUNT(reinforce_131014)
    return 1
end
-- no_check ここまで

