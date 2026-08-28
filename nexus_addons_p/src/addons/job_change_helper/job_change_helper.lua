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
        toggle:SetTextTooltip(g.lang == "Japanese" and "{ol}装備を全部外します{nl}ペットも外します" or
                                  "{ol}Remove all equipment{nl}The companion is also removed")
    else
        toggle:SetSkinName("baseyellow_btn")
        toggle:Resize(35, 35)
        toggle:SetPos(388, 342)
        toggle:SetText("{ol}{img equipment_info_btn_mark2 30 25}")
        toggle:SetEventScript(ui.LBUTTONUP, "Job_change_helper_equip")
        toggle:SetEventScript(ui.RBUTTONUP, "Job_change_helper_modechange")
        toggle:SetTextTooltip(g.lang == "Japanese" and
                                  "{ol}直前に脱いだ装備を全部着けます。{nl}外したペットも呼び戻します{nl}右クリックでモードを強制クリア" or
                                  "{ol}Equip all gear that was just unequipped{nl}The removed companion is re-summoned{nl}Right-click to force-clear the mode")
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

-- 装備と一緒にペット（コンパニオン）も外す。外す要求を出したら true。
-- 鷹（Falconer の召喚）は装備ではなくクラスの召喚なので触らない。転職経路だけが
-- Job_change_helper_post_unequip でバラック送りの面倒を見る。
--
-- **控えるのは guid だけにすること。** 呼び戻すときの monClassID は、そのとき
-- session.pet.GetPetByGUID(guid) から引き直す。外した直後のペット情報を持ち回すと、
-- 取れなかったときに理由が分からないまま「呼び戻せない」だけが残る。
function Job_change_helper_unsummon_pet()
    g.job_change_helper_pet_guid = nil
    local pet = GET_SUMMONED_PET()
    if not pet then
        g.vlog("job_change_helper: ペットは連れていないので何もしない")
        return false
    end
    local ok, guid = pcall(function()
        return pet:GetStrGuid()
    end)
    if ok and guid then
        g.job_change_helper_pet_guid = guid
    else
        g.vlog("job_change_helper: ペットの guid を控えられなかったので呼び戻せない")
    end
    control.SummonPet(0, 0, 0)
    g.vlog("job_change_helper: ペットを外す要求を出した (guid=%s)", tostring(guid))
    return true
end

-- guid からペットの monClassID を引く（control.SummonPet の第 1 引数）。
-- 素の companionlist.lua と同じく GetIES(info:GetObject()).ClassID から取る。
function Job_change_helper_pet_class_id(pet_info)
    local ok, cls_id = pcall(function()
        return GetIES(pet_info:GetObject()).ClassID
    end)
    if not ok then
        return nil
    end
    return cls_id
end

-- 呼び戻せる状態なら召喚要求を出す。
-- 戻り値: "done"(出した / もう不要) / "wait"(クールタイム中) / "give_up"(呼び戻せない)
function Job_change_helper_try_summon_pet()
    local guid = g.job_change_helper_pet_guid
    if not guid then
        return "done"
    end
    if GET_SUMMONED_PET() then
        g.vlog("job_change_helper: 既にペットが出ているので呼び戻さない")
        g.job_change_helper_pet_guid = nil
        return "done"
    end
    local pet_info = session.pet.GetPetByGUID(guid)
    if not pet_info then
        g.vlog("job_change_helper: guid=%s のペットが見つからないので呼び戻さない", tostring(guid))
        g.job_change_helper_pet_guid = nil
        return "give_up"
    end
    local cool = pet_info:GetCurrentCoolDownTime()
    if cool and cool > 0 then
        return "wait"
    end
    local cls_id = Job_change_helper_pet_class_id(pet_info)
    if not cls_id then
        g.vlog("job_change_helper: ペットの ClassID が引けないので呼び戻せない (guid=%s)", tostring(guid))
        g.job_change_helper_pet_guid = nil
        return "give_up"
    end
    control.SummonPet(cls_id, guid, 0)
    g.vlog("job_change_helper: ペットを呼び戻す要求を出した (guid=%s cls=%s)", tostring(guid), tostring(cls_id))
    g.job_change_helper_pet_guid = nil
    return "done"
end

-- 「着ける」で外したペットを呼び戻す。外した直後は召喚のクールタイムが残るので、
-- 明いたら出すよう待つ（素の HOTKEY_SUMMON_COMPANION と同じ判定）。
function Job_change_helper_resummon_pet(frame)
    if not g.job_change_helper_pet_guid then
        g.vlog("job_change_helper: 呼び戻すペットの控えが無い（外したときに控えられなかったか、既に呼び戻した）")
        return
    end
    g.vlog("job_change_helper: ペットの呼び戻しを開始 (guid=%s)", tostring(g.job_change_helper_pet_guid))
    if Job_change_helper_try_summon_pet() == "wait" then
        g.job_change_helper_pet_summon_wait = 0
        g.vlog("job_change_helper: 召喚のクールタイム中なので明くのを待つ")
        frame:RunUpdateScript("Job_change_helper_resummon_pet_", 0.5)
    end
end

function Job_change_helper_resummon_pet_(frame)
    local waited = (g.job_change_helper_pet_summon_wait or 0) + 1
    g.job_change_helper_pet_summon_wait = waited
    if Job_change_helper_try_summon_pet() ~= "wait" then
        return 0
    end
    if waited >= 120 then
        ui.SysMsg(g.lang == "Japanese" and "[JCH]クールタイムが明かないのでペットは呼び戻しませんでした" or
                      "[JCH]The companion was not re-summoned (still on cooldown)")
        g.vlog("job_change_helper: 60 秒待ってもクールタイムが明かないので呼び戻しを諦めた")
        g.job_change_helper_pet_guid = nil
        return 0
    end
    return 1
end

-- ペットを外すのを先に済ませてから装備を外す。**順番を入れ替えないこと。**
-- ペット（コンパニオン）を連れたままだと装備の外し要求が通らず、ペットだけが外れて
-- 装備が残る。外し終わるのを待ってから ReqUnEquipItemAll を出す。
function Job_change_helper_unequip(frame, ctrl)
    if Job_change_helper_unsummon_pet() then
        g.job_change_helper_pet_wait = 0
        ctrl:RunUpdateScript("Job_change_helper_wait_pet", 0.2)
        return
    end
    Job_change_helper_unequip_start(ctrl)
end

-- ペットが実際に消えるまで待つ。外せない状態（騎乗直後など）で止まらないよう
-- 5 秒で見切って先へ進む（装備だけでも外れたほうが利用者の意図に近い）。
function Job_change_helper_wait_pet(ctrl)
    local waited = (g.job_change_helper_pet_wait or 0) + 1
    g.job_change_helper_pet_wait = waited
    if GET_SUMMONED_PET() and waited < 25 then
        return 1
    end
    if GET_SUMMONED_PET() then
        g.vlog("job_change_helper: ペットが外れないまま %.1f 秒待ったので装備外しへ進む", waited * 0.2)
    else
        g.vlog("job_change_helper: ペットが外れた(%.1f 秒)", waited * 0.2)
    end
    Job_change_helper_unequip_start(ctrl)
    return 0
end

function Job_change_helper_unequip_start(ctrl)
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
    g.vlog("job_change_helper: 装備を外す要求を出した (対象 %d 箇所 / ペット=%s)",
           #g.job_change_helper_sorted_equip_list, GET_SUMMONED_PET() and "居る" or "居ない")
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
    g.vlog("job_change_helper: 着け直しを開始 (装備 %d 箇所 / ペットの控え=%s)",
           #(g.job_change_helper_sorted_equip_list or {}), tostring(g.job_change_helper_pet_guid))
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
    Job_change_helper_resummon_pet(inventory)
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

