-- Job Change Helper ここから
function job_change_helper_on_init()
    if g.get_map_type() == "City" then
        Job_change_helper_frame_init()
    end
end

function Job_change_helper_frame_init()
    if g.settings.job_change_helper.use == 0 then
        local inventory = ui.GetFrame('inventory')
        local toggle = GET_CHILD(inventory, "Job_change_helper_toggle")
        if toggle then
            DESTROY_CHILD_BYNAME(inventory, "Job_change_helper_toggle")
        end
        local changejob = ui.GetFrame("changejob")
        local jobTreeBox = GET_CHILD_RECURSIVELY(changejob, "jobTreeBox")
        local job_change = GET_CHILD(jobTreeBox, "Job_change_helper_job_change")
        if job_change then
            DESTROY_CHILD_BYNAME(jobTreeBox, "Job_change_helper_job_change")
        end
        return
    end
    local inventory = ui.GetFrame('inventory')
    DO_WEAPON_SLOT_CHANGE(inventory, 1)
    local toggle = inventory:CreateOrGetControl("button", "job_change_helper_toggle", 388, 345, 25, 30)
    AUTO_CAST(toggle)
    if not g.job_change_helper_mode then
        toggle:SetSkinName("test_red_button")
        toggle:Resize(30, 30)
        toggle:SetPos(388, 345)
        toggle:SetText("{img equipment_info_btn_mark2 30 25}")
        toggle:SetEventScript(ui.LBUTTONUP, "Job_change_helper_unequip")
        toggle:SetTextTooltip(g.lang == "Japanese" and "{ol}装備を全部外します" or "{ol}Remove all equipment")
    else
        toggle:SetSkinName("baseyellow_btn")
        toggle:Resize(35, 35)
        toggle:SetPos(388, 342)
        toggle:SetText("{ol}{img equipment_info_btn_mark2 30 25}")
        toggle:SetEventScript(ui.LBUTTONUP, "Job_change_helper_equip")
        toggle:SetEventScript(ui.RBUTTONUP, "Job_change_helper_modechange")
        toggle:SetTextTooltip(g.lang == "Japanese" and
                                  "{ol}直前に脱いだ装備を全部着けます。{nl}右クリックでモードを強制クリア" or
                                  "{ol}Equip all gear that was just unequipped{nl}Right-click to force-clear the mode")
    end
    local changejob = ui.GetFrame("changejob")
    if changejob then
        local jobTreeBox = GET_CHILD_RECURSIVELY(changejob, "jobTreeBox")
        AUTO_CAST(jobTreeBox)
        local job_change = jobTreeBox:CreateOrGetControl("button", "Job_change_helper_job_change", 70, 110, 226, 78)
        AUTO_CAST(job_change)
        job_change:SetPos(70, 110)
        job_change:SetSkinName("None")
        job_change:SetImage("btn_lv3")
        job_change:SetText("{ol}Job Change Helper")
        job_change:EnableHitTest(1)
        job_change:SetAnimation('MouseOnAnim', 'btn_mouseover')
        job_change:SetAnimation('MouseOffAnim', 'btn_mouseoff')
        job_change:SetEventScript(ui.LBUTTONDOWN, "OUT_PARTY")
        job_change:SetEventScript(ui.LBUTTONUP, "Job_change_helper_unequip")
    end
end

function Job_change_helper_modechange()
    g.job_change_helper_mode = false
    Job_change_helper_frame_init()
end

function Job_change_helper_unequip(frame, ctrl)
    local equip_list = {}
    local need_run = false
    local equip_item_list = session.GetEquipItemList()
    local cnt = equip_item_list:Count()
    for i = 0, cnt - 1 do
        local equip_item = equip_item_list:GetEquipItemByIndex(i)
        local spot_name = item.GetEquipSpotName(equip_item.equipSpot)
        local iesid = tostring(equip_item:GetIESID())
        local cls_id = equip_item.type
        if iesid ~= "0" then
            equip_list[spot_name] = {
                iesid = iesid,
                cls_id = cls_id,
                index = i
            }
            if spot_name == "HELMET" then
                need_run = true
            elseif spot_name == "CORE" then
                need_run = true
            end
        end
    end
    session.job.ReqUnEquipItemAll()
    g.job_change_helper_sorted_equip_list = {}
    for spot_name, data in pairs(equip_list) do
        data.spot_name = spot_name
        table.insert(g.job_change_helper_sorted_equip_list, data)
    end
    table.sort(g.job_change_helper_sorted_equip_list, function(a, b)
        return a.index < b.index
    end)
    if need_run then
        ctrl:RunUpdateScript("Job_change_helper_unequip_", 0.2)
    else
        local changejob = ui.GetFrame("changejob")
        if changejob and changejob:IsVisible() == 1 then
            ctrl:RunUpdateScript("Job_change_helper_post_unequip", 0.3)
        else
            Job_change_helper_end("unequip")
        end
    end
end

function Job_change_helper_unequip_(ctrl)
    local equip_item_list = session.GetEquipItemList()
    local pc = GetMyPCObject()
    for _, equip_data in ipairs(g.job_change_helper_sorted_equip_list) do
        local spot_name = equip_data.spot_name
        local iesid = equip_data.iesid
        if spot_name == "HELMET" or spot_name == "CORE" then

            local inv_item = session.GetInvItemByGuid(iesid)
            if not inv_item then
                local current_equip = equip_item_list:GetEquipItem(pc, spot_name)
                if current_equip then
                    local index = equip_data.index
                    item.UnEquip(index)
                    return 1
                end
            end
        end
    end
    local changejob = ui.GetFrame("changejob")
    if changejob and changejob:IsVisible() == 1 then
        ctrl:RunUpdateScript("Job_change_helper_post_unequip", 0.3)
    else
        Job_change_helper_end("unequip")
    end
    return 0
end

function Job_change_helper_post_unequip(ctrl)
    local changejob = ui.GetFrame("changejob")
    if changejob and changejob:IsVisible() == 1 then
        local pet = GET_SUMMONED_PET()
        if pet then
            control.SummonPet(0, 0, 0)
            return 1
        end
        local hawk = GET_SUMMONED_PET_HAWK()
        if hawk then
            ui.SysMsg(g.lang == "Japanese" and "鷹を連れているのでバラックへ戻ります" or
                          "Will return to the barracks due to the hawk")
            GAME_TO_BARRACK()
            return 0
        end
        local multiple_class_change = ui.GetFrame("multiple_class_change")
        MULTIPLE_CLASS_CHANGE_OPEN(multiple_class_change)
        multiple_class_change:ShowWindow(1)
    end
    Job_change_helper_end("unequip")
    return 0
end

function Job_change_helper_equip(inventory, ctrl)
    inventory:RunUpdateScript("Job_change_helper_equip_", 0.3)
end

function Job_change_helper_equip_(inventory)
    if #g.job_change_helper_sorted_equip_list > 0 then
        for i, equip_data in ipairs(g.job_change_helper_sorted_equip_list) do
            local spot_name = equip_data.spot_name
            local iesid = equip_data.iesid
            local cls_id = equip_data.cls_id
            local ret = CHECK_EQUIPABLE(cls_id)
            if ret ~= "OK" then
                table.remove(g.job_change_helper_sorted_equip_list, i)
                return 1
            end
            local inv_item = session.GetInvItemByGuid(iesid)
            if inv_item then
                ITEM_EQUIP(inv_item.invIndex, spot_name)
                return 1
            else
                if i >= 9 then
                    DO_WEAPON_SLOT_CHANGE(inventory, 2)
                end
                table.remove(g.job_change_helper_sorted_equip_list, i)
                return 1
            end
        end
    end
    Job_change_helper_end("equip")
    return 0
end

function Job_change_helper_end(str)
    if str == "equip" then
        g.job_change_helper_mode = false
    else
        g.job_change_helper_mode = true
    end
    local inventory = ui.GetFrame('inventory')
    inventory:RunUpdateScript("Job_change_helper_frame_init", 0.5)
    ui.SysMsg("[JCH]End of Operation")
end
-- Job Change Helper ここまで

