-- ダイアログ制御系
function Mini_addons_DIALOG_CHANGE_SELECT(frame, msg, str, num)
    if g.settings.dialog_ctrl == 0 then
        return
    end
    local dialogselect = ui.GetFrame("dialogselect")
    if str == "WAREHOUSE_DLG" or str == "ORSHA_WAREHOUSE_DLG" or str == "WAREHOUSE_FEDIMIAN_DLG" and msg ==
        "DIALOG_CHANGE_SELECT" then -- 倉庫
        session.SetSelectDlgList()
        ui.OpenFrame("dialogselect")
        DialogSelect_index = 2
        local btn2 = GET_CHILD_RECURSIVELY(dialogselect, "item2Btn")
        local x, y = GET_SCREEN_XY(btn2)
        mouse.SetPos(x + 190, y)
        return
    end
    if str == "NPC_PERSONAL_HOUSING_MANAGER_DLG_2" then -- 住居クポル
        session.SetSelectDlgList()
        ui.OpenFrame("dialogselect")
        control.DialogItemSelect(1)
    elseif string.find(str, "PERSONAL_HOUSING_POINT_CHECK_MSG_1") then
        session.SetSelectDlgList()
        ui.OpenFrame("dialogselect")
        control.DialogItemSelect(1)
    elseif string.find(str, "PH_POINT_SHOP_DLG_SEL_1") then
        session.SetSelectDlgList()
        ui.CloseFrame("dialog")
        ui.OpenFrame("dialogselect")
        DialogSelect_index = 3
        local btn = GET_CHILD_RECURSIVELY(dialogselect, "item3Btn")
        local x, y = GET_SCREEN_XY(btn)
        mouse.SetPos(x + 190, y)
        return
    end
    if str == "Goddess_Raid_Rozethemiserable_Start_Npc_Dlg" or str == "Goddess_Raid_Spreader_Start_Npc_DLG1" or str ==
        "Goddess_Raid_Jellyzele_Start_Npc_DLG1" or str == "EP14_Raid_Delmore_NPC_DLG1" or str ==
        "Goddess_Raid_DespairIsland_Start_Npc_Dlg" then
        session.SetSelectDlgList()
        ui.CloseFrame("dialog")
        ui.OpenFrame("dialogselect")
        DialogSelect_index = 2
        local btn = GET_CHILD_RECURSIVELY(dialogselect, "item2Btn")
        local x, y = GET_SCREEN_XY(btn)
        mouse.SetPos(x + 190, y)
        return
    end
    local pc = GetMyPCObject()
    local cur_map = GetZoneName(pc)
    if (str == "Legend_Raid_Giltine_ENTER_MSG" and cur_map == "raid_dcapital_108") then
        session.SetSelectDlgList()
        ui.CloseFrame("dialog")
        ui.OpenFrame("dialogselect")
        DialogSelect_index = 2
        local btn = GET_CHILD_RECURSIVELY(dialogselect, "item2Btn")
        local x, y = GET_SCREEN_XY(btn)
        mouse.SetPos(x + 190, y)
        return
    end
end
