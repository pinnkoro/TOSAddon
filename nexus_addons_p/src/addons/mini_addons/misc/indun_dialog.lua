-- エンブレム、アークの着け忘れお知らせ
function Mini_addons_SHOW_INDUNENTER_DIALOG(my_frame, my_msg)
    local current_time = os.clock()
    if g.last_indun_check_time and (current_time - g.last_indun_check_time < 1.0) then
        return
    end
    g.last_indun_check_time = current_time
    if g.settings.equip_info == 0 then
        return
    end
    local indun_frame = ui.GetFrame("indunenter")
    local indun_type = indun_frame:GetUserValue("INDUN_TYPE")
    local target_indun_list = {665, 670, 675, 678, 681, 628, 687, 690, 697, 709, 712, 718, 724, 727}
    local is_target = false
    for i = 1, #target_indun_list do
        if tostring(target_indun_list[i]) == tostring(indun_type) then
            is_target = true
            break
        end
    end
    if not is_target then
        return
    end
    local equip_item_list = session.GetEquipItemList()
    local cnt = equip_item_list:Count()
    for i = 0, cnt - 1 do
        local equip_item = equip_item_list:GetEquipItemByIndex(i)
        local spot_name = item.GetEquipSpotName(equip_item.equipSpot)
        local iesid = tostring(equip_item:GetIESID())
        if tostring(spot_name) == "SEAL" and tonumber(iesid) == 0 then
            if g.lang == "Japanese" then
                imcAddOn.BroadMsg("NOTICE_Dm_Global_Shout",
                    "{st55_a}{#FF8C00}エンブレム装備してないけど{nl}ええんか？", 3.0)
            else -- You don't have an emblem equipped. {nl} Is this okay?
                imcAddOn.BroadMsg("NOTICE_Dm_Global_Shout",
                    "{st55_a}{#FF8C00}You don't have an emblem equipped{nl}Is this okay?", 3.0)
            end
            break
        elseif tostring(spot_name) == "ARK" and tonumber(iesid) == 0 then
            if g.lang == "Japanese" then
                imcAddOn.BroadMsg("NOTICE_Dm_Global_Shout",
                    "{st55_a}{#FF8C00}アーク装備してないけど{nl}ええんか？", 3.0)
            else
                imcAddOn.BroadMsg("NOTICE_Dm_Global_Shout",
                    "{st55_a}{#FF8C00}You don't have an ark equipped{nl}Is this okay?", 3.0)
            end
            break
        end
    end
end
-- 自動マッチのレイヤーを下げる
function Mini_addons_INDUNENTER_AUTOMATCH_TYPE(my_frame, my_msg)
    local indunenter = ui.GetFrame("indunenter")
    if g.settings.automatch_layer == 1 then
        indunenter:SetLayerLevel(97)
    elseif g.settings.automatch_layer == 0 then
        indunenter:SetLayerLevel(100)
    end
end
-- 死んだ時の選択肢を動かす
function Mini_addons_RESTART_HERE()
    if g.settings.restart_move == 0 then
        return
    end
    local restart_contents = ui.GetFrame("restart_contents")
    if restart_contents:IsVisible() == 1 then
        restart_contents:EnableHittestFrame(1)
        restart_contents:EnableMove(1)
    end
    local restart = ui.GetFrame("restart")
    if restart:IsVisible() == 1 then
        restart:EnableHittestFrame(1)
        restart:EnableMove(1)
    end
end
-- 死んだ時のマウス位置制御
function Mini_addons_RESTART_CONTENTS_ON_HERE(my_frame, my_msg)
    if g.settings.restart_move == 0 then
        return
    end
    local restart_contents = ui.GetFrame("restart_contents")
    local btn_restart = GET_CHILD_RECURSIVELY(restart_contents, "btn_restart_" .. 1)
    local item_width = btn_restart:GetWidth()
    local item_height = btn_restart:GetHeight()
    local x, y = GET_SCREEN_XY(btn_restart + item_width / 2, btn_restart + item_height / 2)
    mouse.SetPos(x, y)
end
