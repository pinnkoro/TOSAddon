-- 細かい修正
function Mini_addons_minor_fixes()
    -- ノーマルジェムはめる時の修正
    g.setup_hook_and_event(g.addon, "GODDESS_MGR_SOCKET_INV_RBTN", "Mini_addons_GODDESS_MGR_SOCKET_INV_RBTN", true)
    -- カード強化とかジェム強化のインプット最適化
    g.setup_hook_and_event(g.addon, "INPUT_NUMBER_BOX", "Mini_addons_INPUT_NUMBER_BOX", true)
    -- ジェムロースティング屋の最適化
    g.setup_hook_and_event(g.addon, "GEMROASTING_TARGET_UI_CENCEL", "Mini_addons_GEMROASTING_TARGET_UI_CENCEL", true)
    g.setup_hook_and_event(g.addon, "ITEMBUFFGEMROASTING_UI_COMMON", "Mini_addons_ITEMBUFFGEMROASTING_UI_COMMON", true)
    -- 昔の装備ダメージフレーム消す
    -- Mini_addons_durnotify_hide()
end
-- ノーマルジェムはめる時の修正
function Mini_addons_GODDESS_MGR_SOCKET_INV_RBTN(my_frame, my_msg)
    local item_obj, slot, guid = g.get_event_args(my_msg)
    local inv_item = session.GetInvItemByGuid(guid)
    local gem_type = GET_EQUIP_GEM_TYPE(item_obj)
    local frame = ui.GetFrame('goddess_equip_manager')
    local normal_inner_bg = GET_CHILD_RECURSIVELY(frame, 'normal_inner_bg')
    local equip_item = session.GetInvItemByGuid(guid)
    local equip_obj = GetIES(equip_item:GetObject())
    local use_lv = TryGetProp(equip_obj, 'UseLv', 0)
    local max_socket_cnt = GET_MAX_GODDESS_NORMAL_SOCKET_COUNT(use_lv)
    for i = 0, max_socket_cnt - 1 do
        local ctrlset = GET_CHILD(normal_inner_bg, 'NORMAL_CSET_' .. i)
        AUTO_CAST(ctrlset)
        local gem_id = ctrlset:GetUserIValue('GEM_ID')
        if gem_id == 0 then
            local gem_slot = GET_CHILD(ctrlset, 'gem_slot')
            AUTO_CAST(gem_slot)
            GODDESS_MGR_SOCKET_NORMAL_GEM_EQUIP(ctrlset, gem_slot, inv_item, item_obj)
            break
        end
    end
end
-- カード強化とかジェム強化のインプット最適化
function Mini_addons_INPUT_NUMBER_BOX()
    local reinforce_by_mix = ui.GetFrame("reinforce_by_mix")
    if reinforce_by_mix:IsVisible() == 1 then
        local title = GET_CHILD_RECURSIVELY(reinforce_by_mix, "title")
        local titleValue = title:GetTextByKey("value")
        if titleValue == "@dicID_^*$ETC_20150317_001699$*^" or titleValue == "@dicID_^*$ETC_20150323_010016$*^" then
            local newframe = ui.GetFrame("inputstring")
            local edit = GET_CHILD(newframe, 'input', "ui::CEditControl")
            edit:SetEnableEditTag(1)
            edit:SetText("1")
        end
    end
end
-- ジェムロースティング屋の最適化
function Mini_addons_GEMROASTING_TARGET_UI_CENCEL()
    INVENTORY_SET_CUSTOM_RBTNDOWN("None")
end

function Mini_addons_ITEMBUFFGEMROASTING_UI_COMMON(frame, msg)
    INVENTORY_SET_CUSTOM_RBTNDOWN("Mini_addons_gem_roasting_rbtn")
end

function Mini_addons_gem_roasting_rbtn(item_obj, slot)
    local icon = slot:GetIcon()
    local icon_info = icon:GetInfo()
    local iesid = icon_info:GetIESID()
    local inv_item = GET_PC_ITEM_BY_GUID(iesid)
    if not inv_item then
        return
    end
    local type = icon_info.type
    local item_cls = GetClassByType("Item", type)
    local pc = GetMyPCObject()
    local obj = GetIES(inv_item:GetObject())
    local itembuffgemroasting = ui.GetFrame("itembuffgemroasting")
    local target_slot = GET_CHILD_RECURSIVELY(itembuffgemroasting, "slot")
    if obj.GemRoastingLv >= itembuffgemroasting:GetUserIValue("SKILLLEVEL") then
        ui.SysMsg(ClMsg("CannontDropGam"))
        return
    end
    local check_item = _G["ITEMBUFF_CHECK_" .. itembuffgemroasting:GetUserValue("SKILLNAME")]
    if check_item(pc, obj) ~= 1 then
        ui.SysMsg(ClMsg("WrongDropItem"))
        return
    end
    local check_func = _G["ITEMBUFF_NEEDITEM_" .. itembuffgemroasting:GetUserValue("SKILLNAME")]
    local name, cnt = check_func(pc, obj)
    SET_SLOT_ITEM_IMAGE(target_slot, inv_item)
    target_slot:SetUserValue("GEM_IESID", icon_info:GetIESID())
    local roasting = itembuffgemroasting:GetChild("roasting")
    local slotName = roasting:GetChild("slotName")
    slotName:SetTextByKey("txt", obj.Name)
    local effectGbox = GET_CHILD(roasting, "effectGbox")
    AUTO_CAST(effectGbox)
    effectGbox:RemoveChild('tooltip_gem_property')
    local y_pos = 100
    local tooltip_gem_property = effectGbox:CreateOrGetControlSet('tooltip_gem_property', 'tooltip_gem_property', 0,
        y_pos)
    AUTO_CAST(tooltip_gem_property)
    local gem_property_gbox = GET_CHILD(tooltip_gem_property, 'gem_property_gbox')
    AUTO_CAST(gem_property_gbox)
    local inner_y_pos = 0
    local inner_cset = nil
    local inner_prop_count = 0
    local inner_prop_y_pos = 0
    local lv = GET_ITEM_LEVEL_EXP(obj, obj.ItemExp) - itembuffgemroasting:GetUserIValue("SKILLLEVEL")
    if lv < 1 then
        lv = 0
    end
    local gem_prop = geItemTable.GetProp(obj.ClassID)
    local socket_penalty_prop = gem_prop:GetSocketPropertyByLevel(lv)
    local prop_index = 0
    local prop_name_list = GET_ITEM_PROP_NAME_LIST(obj)
    for i = 1, #prop_name_list do
        local title = prop_name_list[i]["Title"]
        local prop_name = prop_name_list[i]["PropName"]
        local prop_value = prop_name_list[i]["PropValue"]
        local use_operator = prop_name_list[i]["UseOperator"]
        if title then
            inner_cset = gem_property_gbox:CreateOrGetControlSet('tooltip_each_gem_property', title, 0, inner_y_pos)
            AUTO_CAST(inner_cset)
            local type_text = GET_CHILD(inner_cset, 'type_text')
            AUTO_CAST(type_text)
            type_text:SetText(ScpArgMsg(title))
            local type_icon = GET_CHILD(inner_cset, 'type_icon')
            AUTO_CAST(type_icon)
            local img_name = GET_ICONNAME_BY_WHENEQUIPSTR(tooltip_gem_property, title)
            type_icon:SetImage(img_name)
            inner_prop_count = 0
            inner_prop_y_pos = type_text:GetHeight() + type_text:GetY()
            inner_cset:GetChild("labelline"):ShowWindow(0)
        else
            if inner_cset then
                local inner_inner_cset = inner_cset:CreateOrGetControlSet('tooltip_each_gem_property_each_text',
                    'proptext' .. inner_prop_count, 0, inner_prop_y_pos)
                AUTO_CAST(inner_inner_cset)
                local real_text = nil
                local penalty_text = nil
                if use_operator and prop_value > 0 then
                    real_text = ScpArgMsg(prop_name) .. " : " .. "{img green_up_arrow 16 16}" .. prop_value
                else
                    local prop_penalty_add = socket_penalty_prop:GetPropPenaltyAddByIndex(prop_index, 0)
                    if nil == prop_penalty_add then
                        ui.SysMsg(ClMsg("WrongDropItem"))
                        GEMROASTING_UI_RESET(itembuffgemroasting)
                        return
                    end
                    prop_index = prop_index + 1
                    real_text = ScpArgMsg(prop_name) .. " : " .. "{img red_down_arrow 16 16}" .. prop_value
                    penalty_text =
                        string.format("   {img alch_gemlos_arrow %d %d}   ", 80, 18) .. ScpArgMsg('PropDown') ..
                            prop_penalty_add.value
                end
                local prop_text = GET_CHILD(inner_inner_cset, 'prop_text')
                AUTO_CAST(prop_text)
                prop_text:SetText(real_text)
                local prop_penalty_text = GET_CHILD(inner_inner_cset, 'prop_text2')
                AUTO_CAST(prop_penalty_text)
                prop_penalty_text:SetText(penalty_text)
                prop_penalty_text:SetMargin(210, 0, 0, 0)
                inner_prop_count = inner_prop_count + 1
                AUTO_CAST(inner_cset)
                inner_prop_y_pos = inner_inner_cset:GetY() + inner_inner_cset:GetHeight()
                inner_cset:Resize(inner_cset:GetOriginalWidth(),
                    inner_inner_cset:GetY() + inner_inner_cset:GetHeight() + 10)
                inner_y_pos = inner_cset:GetY() + inner_cset:GetHeight()
            end
        end
    end
    gem_property_gbox:Resize(gem_property_gbox:GetOriginalWidth(), inner_y_pos)
    tooltip_gem_property:Resize(tooltip_gem_property:GetWidth(), tooltip_gem_property:GetHeight() +
        gem_property_gbox:GetHeight() + gem_property_gbox:GetY() + 10)
    GEMROASTING_UPDATE_MATERIAL(itembuffgemroasting, cnt, icon_info:GetIESID())
    GEMROASTING_VIEW(itembuffgemroasting)
    if itembuffgemroasting:GetUserIValue("HANDLE") ~= session.GetMyHandle() then
        local reqitemMoney = roasting:GetChild("reqitemMoney")
        reqitemMoney:SetTextByKey("txt", cnt * itembuffgemroasting:GetUserIValue("PRICE"))
    end
end
-- 昔の装備ダメージフレーム消す
function Mini_addons_durnotify_hide()
    local durnotify = ui.GetFrame("durnotify")
    if durnotify and durnotify:IsVisible() == 1 then
        durnotify:Resize(0, 0)
    end
end

