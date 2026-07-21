-- Bulk Sales ここから
g.bulk_sales = {
    amount = 0,
    tbl = {},
    time = 0
}
function bulk_sales_on_init(frame, addon)
    g.addon:RegisterMsg('DIALOG_CLOSE', 'Bulk_sales_SHOP_ON_MSG')
end

function Bulk_sales_SHOP_ON_MSG(frame, msg, str, num)
    if g.settings.bulk_sales.use == 0 then
        return
    end
    g.bulk_sales.time = g.bulk_sales.time or 0
    local current_time = os.clock()
    if (current_time - g.bulk_sales.time) < 0.5 then
        return
    end
    if str ~= "Klapeda_Misc" and str ~= "Orsha_Misc" and str ~= "Fedimian_Misc" and
        not string.find(str, "CertificateCoin_Shop") then
        return
    else
        g.setup_hook_and_event(g.addon, "SHOP_UI_CLOSE", "Bulk_sales_frame_close", true)
        Bulk_sales_slotset()
    end
end

function Bulk_sales_slotset()
    local bulk_sales = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "bulk_sales", 0, 0, 0, 0)
    AUTO_CAST(bulk_sales)
    bulk_sales:SetSkinName("test_frame_low")
    bulk_sales:SetLayerLevel(80)
    bulk_sales:SetTitleBarSkin("None")
    bulk_sales:RemoveAllChild()
    local gbox = bulk_sales:CreateOrGetControl("groupbox", 'gbox', 10, 35, 0, 0)
    AUTO_CAST(gbox)
    gbox:SetSkinName("None")
    local slotset = gbox:CreateOrGetControl('slotset', 'slotset', 0, 0, 0, 0)
    AUTO_CAST(slotset)
    slotset:EnablePop(1)
    slotset:EnableDrag(1)
    slotset:EnableDrop(1)
    slotset:EnableHitTest(1)
    slotset:SetColRow(15, 33)
    slotset:SetSlotSize(35, 35)
    slotset:SetSpc(1, 1)
    slotset:SetSkinName('invenslot2')
    slotset:CreateSlots()
    local title = bulk_sales:CreateOrGetControl("richtext", "title", 40, 10, 120, 30)
    AUTO_CAST(title)
    title:SetText("{@st66b18}Balk Sales")
    local close = bulk_sales:CreateOrGetControl("button", "close", 0, 0, 25, 25)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.LEFT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Bulk_sales_frame_close")
    local sell_btn = bulk_sales:CreateOrGetControl("button", "sell_btn", 0, 0, 120, 50)
    AUTO_CAST(sell_btn)
    sell_btn:SetSkinName("test_red_button")
    sell_btn:SetEventScript(ui.LBUTTONDOWN, "Bulk_sales_sell_execution_reserve")
    sell_btn:SetPos(slotset:GetWidth() - 115, 790)
    sell_btn:SetText("{@st41b}SELL{/}")
    local amount = bulk_sales:CreateOrGetControl("richtext", "amount", 0, 0, 120, 50)
    AUTO_CAST(amount)
    amount:SetPos(30, 800)
    amount:SetText("{@st41b}Sales Amount ▶{/}")
    local sales_amount = bulk_sales:CreateOrGetControl("richtext", "sales_amount", 0, 0, 120, 50)
    AUTO_CAST(sales_amount)
    sales_amount:SetPos(200, 800)
    sales_amount:SetText("{@st41b}{#FFA500}0{/}")
    bulk_sales:Resize(slotset:GetWidth() + 40, 850)
    gbox:Resize(bulk_sales:GetWidth() - 15, bulk_sales:GetHeight() - 100)
    gbox:SetScrollPos(0)
    local shop_frame = ui.GetFrame('shop')
    bulk_sales:SetPos(shop_frame:GetWidth() + 5, 5)
    bulk_sales:ShowWindow(1)
    INVENTORY_SET_CUSTOM_RBTNDOWN("Bulk_sales_inv_rbtn")
end

function Bulk_sales_frame_close()
    local bulk_sales = ui.GetFrame(addon_name_lower .. "bulk_sales")
    if bulk_sales then
        ui.DestroyFrame(addon_name_lower .. "bulk_sales")
    end
    INVENTORY_CLEAR_SELECT(nil)
    INVENTORY_SET_CUSTOM_RBTNDOWN("None")
    g.bulk_sales.time = os.clock()
    g.bulk_sales.amount = 0
    g.bulk_sales.tbl = {}
end

function Bulk_sales_inv_invalidate(frame)
    frame:Invalidate()
    return 0
end

function Bulk_sales_inv_rbtn(item_obj, slot)
    local icon = slot:GetIcon()
    local icon_info = icon:GetInfo()
    local base_guid = icon_info:GetIESID()
    local base_inv_item = session.GetInvItemByGuid(base_guid)
    local base_obj = GetIES(base_inv_item:GetObject())
    local target_clsid = base_obj.ClassID
    local item_prop = geItemTable.GetPropByName(base_obj.ClassName)
    if item_prop:IsEnableShopTrade() == false then
        ui.SysMsg(ClMsg("CannoTradeToNPC"))
        return
    end
    if base_obj.MarketCategory == "Housing_Furniture" or base_obj.MarketCategory == "PHousing_Furniture" or
        base_obj.MarketCategory == "PHousing_Wall" or base_obj.MarketCategory == "PHousing_Carpet" then
        ui.SysMsg(ClMsg("Housing_Cant_Sell_This_Item"))
        return
    end
    local bulk_sales = ui.GetFrame(addon_name_lower .. "bulk_sales")
    local slot_set = GET_CHILD_RECURSIVELY(bulk_sales, "slotset")
    local slot_count = slot_set:GetSlotCount()
    local inv_item_list = session.GetInvItemList()
    local inv_guid_list = inv_item_list:GetGuidList()
    local cnt = inv_guid_list:Count()
    local current_slot_index = 1
    local registered_any = false
    for i = 0, cnt - 1 do
        local guid = inv_guid_list:Get(i)
        local inv_item = inv_item_list:GetItemByGuid(guid)
        local obj = GetIES(inv_item:GetObject())
        if obj.ClassID == target_clsid and not g.bulk_sales.tbl[guid] then
            if not inv_item.isLockState then
                local set_success = false
                for j = current_slot_index, slot_count do
                    local new_slot = GET_CHILD_RECURSIVELY(slot_set, "slot" .. j)
                    local new_icon = new_slot:GetIcon()
                    if not new_icon then
                        g.bulk_sales.tbl[guid] = inv_item.count
                        local item_cls = GetClassByType("Item", target_clsid)
                        local sell_price = geItemTable.GetSellPrice(item_prop) * inv_item.count
                        g.bulk_sales.amount = g.bulk_sales.amount + sell_price
                        new_slot:SetEventScript(ui.RBUTTONDOWN, "Bulk_sales_slot_cancel")
                        new_slot:SetEventScriptArgString(ui.RBUTTONDOWN, guid)
                        new_slot:SetEventScriptArgNumber(ui.RBUTTONDOWN, sell_price)
                        SET_SLOT_ITEM_CLS(new_slot, item_cls)
                        SET_SLOT_ITEM_TEXT(new_slot, inv_item, item_cls)
                        new_slot:SetSkinName('slot')
                        local item_slot = INV_GET_SLOT_BY_ITEMGUID(guid)
                        if item_slot then
                            AUTO_CAST(item_slot)
                            item_slot:SetSelectedImage('socket_slot_check')
                            item_slot:Select(1)
                            item_slot:RunUpdateScript("Bulk_sales_inv_invalidate", 0.1)
                            item_slot:Invalidate()
                        end
                        current_slot_index = j + 1
                        set_success = true
                        registered_any = true
                        break
                    end
                end
                if not set_success then
                    ui.SysMsg(ClMsg("MaxCount"))
                    break
                end
            end
        end
    end
    if registered_any then
        local sales_amount = GET_CHILD_RECURSIVELY(bulk_sales, "sales_amount")
        AUTO_CAST(sales_amount)
        sales_amount:SetText("{@st41b}{#FFA500}" .. GET_COMMAED_STRING(g.bulk_sales.amount))
    end
end

function Bulk_sales_slot_cancel(frame, ctrl, guid, item_price)
    local inventory = ui.GetFrame("inventory")
    local item_slot = INV_GET_SLOT_BY_ITEMGUID(guid)
    if item_slot then
        item_slot:Select(0)
        item_slot:RunUpdateScript("Bulk_sales_inv_invalidate", 0.1)
        item_slot:Invalidate()
    end
    g.bulk_sales.tbl[tostring(guid)] = nil
    g.bulk_sales.amount = g.bulk_sales.amount - item_price
    local bulk_sales = ui.GetFrame(addon_name_lower .. "bulk_sales")
    local sales_amount = GET_CHILD_RECURSIVELY(bulk_sales, "sales_amount")
    AUTO_CAST(sales_amount)
    sales_amount:SetText("{@st41b}{#FFA500}" .. GET_COMMAED_STRING(g.bulk_sales.amount))
    ctrl:ClearText()
    ctrl:ClearIcon()
    ctrl:SetSkinName('invenslot2')
end

function Bulk_sales_sell_execution_reserve(frame, ctrl, str, num)
    local yes_scp = string.format("Bulk_sales_sell_execution()")
    local msg = g.lang == "Japanese" and "アイテムを販売しますか?" or "Do you want to sell this items?"
    ui.MsgBox(msg, yes_scp, "None")
end

function Bulk_sales_sell_execution()
    local bulk_sales = ui.GetFrame(addon_name_lower .. "bulk_sales")
    local slot_set = GET_CHILD_RECURSIVELY(bulk_sales, "slotset")
    AUTO_CAST(slot_set)
    local slot_count = slot_set:GetSlotCount()
    for guid, count in pairs(g.bulk_sales.tbl) do
        if type(count) == "number" and count > 0 then
            item.AddToSellList(guid, count)
        end
    end
    item.SellList()
    slot_set:ClearIconAll()
    Bulk_sales_frame_close()
end
-- Bulk Sales　ここまで

