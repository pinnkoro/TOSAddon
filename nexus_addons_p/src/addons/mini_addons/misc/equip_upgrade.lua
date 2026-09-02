-- 装備錬成を自動化
function Mini_addons_COMMON_EQUIP_UPGRADE_OPEN(my_frame, my_msg)
    local frame = ui.GetFrame("common_equip_upgrade")
    if g.settings.status_upgrade == 0 then
        local target_status_text = GET_CHILD_RECURSIVELY(frame, "target_status_text")
        if target_status_text ~= nil then
            AUTO_CAST(target_status_text)
            target_status_text:ShowWindow(0)
        end
        local target_status_edit = GET_CHILD_RECURSIVELY(frame, "target_status_edit")
        if target_status_edit ~= nil then
            AUTO_CAST(target_status_edit)
            target_status_edit:ShowWindow(0)
        end
    else
        local target_status_text = frame:CreateOrGetControl("richtext", "target_status_text", 20, 650, 80, 30)
        AUTO_CAST(target_status_text)
        target_status_text:SetFontName("white_18_ol")
        target_status_text:SetText("Target Status")
        target_status_text:ShowWindow(1)
        if g.settings.target_status_value == nil then
            g.settings.target_status_value = 20
            Mini_addons_save_settings()
        end
        local target_status_edit = frame:CreateOrGetControl("edit", "target_status_edit", 30, 680, 80, 25)
        AUTO_CAST(target_status_edit)
        target_status_edit:SetTextAlign("center", "center")
        target_status_edit:SetFontName("white_18_ol")
        target_status_edit:SetSkinName("test_weight_skin")
        target_status_edit:SetText(g.settings.target_status_value)
        target_status_edit:SetTextTooltip(g.lang == "Japanese" and "1~20の間で設定" or "Set between 1~20")
        target_status_edit:SetEventScript(ui.ENTERKEY, "Mini_addons_EQUIP_UPGRADE_SET")
        target_status_edit:ShowWindow(1)
    end
end

function Mini_addons_EQUIP_UPGRADE_SET(frame, ctrl, str, num)
    if not tonumber(ctrl:GetText()) then
        ui.SysMsg("Invalid value")
        return
    elseif tonumber(ctrl:GetText()) > 20 or tonumber(ctrl:GetText()) < 1 then
        ui.SysMsg("Invalid value")
        return
    else
        g.settings.target_status_value = tonumber(ctrl:GetText())
        ui.SysMsg("Set target value")
        Mini_addons_save_settings()
    end
end

function Mini_addons_COMMON_EQUIP_UPGRADE_PROGRESS(parent, ctrl, str, nym)
    if g.settings.status_upgrade == 0 then
        g.FUNCS["COMMON_EQUIP_UPGRADE_PROGRESS"](parent, ctrl, str, nym)
        return
    end
    local frame = parent:GetTopParentFrame()
    local slot = GET_CHILD_RECURSIVELY(frame, "slot")
    local guid = slot:GetUserValue("SET_ID")
    pc.ReqExecuteTx_Item("UPGRADE_EQUIP", guid)
    local inv_item = session.GetInvItemByGuid(guid)
    if inv_item == nil then
        return
    end
    local item_obj = GetIES(inv_item:GetObject())
    COMMON_EQUIP_UPGRADE_MAT_NUM_SET(frame, item_obj)
    local cur_rank = TryGetProp(item_obj, "UpgradeRank", 0)
    if tonumber(cur_rank) < g.settings.target_status_value then
        ReserveScript("Mini_addons_COMMON_EQUIP_UPGRADE_PROGRESS_CONTINUE()", 2.0)
        return
    end
end

function Mini_addons_COMMON_EQUIP_UPGRADE_PROGRESS_CONTINUE()
    local parent = ui.GetFrame("common_equip_upgrade")
    if parent:IsVisible() == 0 then
        return
    end
    Mini_addons_COMMON_EQUIP_UPGRADE_PROGRESS(parent, nil, nil, nil)
end
