-- quickslot_operate ここから
g.quickslot_operate_raid_list = {
    Paramune = {623, 667, 666, 665, 674, 673, 675, 680, 679, 681, 707, 708, 710, 711, 709, 712, 722, 723, 724, 725, 726,
                727},
    Klaida = {686, 685, 687, 716, 717, 718},
    Velnias = {689, 688, 690, 669, 635, 628, 696, 695, 697},
    Forester = {672, 671, 670},
    -- 677/676/678 = 高位ファルオロス、729/730/731 = ズメイ(A/S/H)。ズメイは野獣なので Widling。
    Widling = {677, 676, 678, 729, 730, 731}
}
g.quickslot_operate_zone_list = {11208, 11230, 11250, 11252, 11256, 11257, 11261, 11263, 11266, 11267, 11270, 11276,
                                 11277, 11278, 11285, 11286, 11291}
-- 11267=ドラグーン 11257=バウバス 11290=アシャーク
g.quickslot_guild_eventmap = {11267, 11257, 11290, 11285, 11286}
g.quickslot_operate_atk_list = {
    Velnias = {640504, 640368},
    Klaida = {640503, 640370},
    Paramune = {640502, 640369},
    Widling = {640501, 640372},
    Forester = {640500, 640371}
}
g.quickslot_operate_def_list = {
    Velnias = 640373,
    Klaida = 640375,
    Paramune = 640374,
    Widling = 640377,
    Forester = 640376
}
function Quickslot_operate_save_settings()
    g.save_json(g.quickslot_operate_path, g.quickslot_operate_settings)
end

function Quickslot_operate_load_settings()
    g.quickslot_operate_path = string.format("../addons/%s/%s/quickslot_operate.json", addon_name_lower, g.active_id)
    g.quickslot_operate_old_path = string.format("../addons/%s/%s/settings_250609.json", "quickslot_operate",
        g.active_id)
    local ver = 1.1
    local settings = g.load_json(g.quickslot_operate_path)

    if not settings then
        local old_settings = g.load_json(g.quickslot_operate_old_path)
        if old_settings then
            settings = old_settings
        else
            settings = {
                slotset = {},
                straight = false,
                rshift = false
            }
        end
        settings.ver = ver
    end
    if not settings.ver or settings.ver < ver then
        settings.ver = ver
    end
    g.quickslot_operate_settings = settings
    Quickslot_operate_save_settings()
end

function quickslot_operate_on_init()
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    if not g.quickslot_operate_settings then
        _nexus_addons_p:RunUpdateScript("Quickslot_operate_lazy_start", 0.1)
        return
    end
    if g.settings.quickslot_operate.use == 0 then
        local quickslot_operate_map_timer = GET_CHILD(_nexus_addons_p, "quickslot_operate_map_timer")
        if _nexus_addons_p then
            _nexus_addons_p:RemoveChild("quickslot_operate_map_timer")
            _nexus_addons_p:RemoveChild("quickslot_operate_timer")
        end
        local quickslotnexpbar = ui.GetFrame("quickslotnexpbar")
        if quickslotnexpbar then
            quickslotnexpbar:RemoveChild("setting")
            if g.quickslot_operate_settings and g.quickslot_operate_settings.straight then
                g.quickslot_operate_settings.straight = false
                Quickslot_operate_redraw_slots()
            end
            quickslotnexpbar:SetUserValue("USE", 0)
            quickslotnexpbar:RunUpdateScript("Quickslot_operate_set_script", 2.0)
        end
        return
    end
    Quickslot_operate_init_logic()
end

function Quickslot_operate_lazy_start(frame)
    if not g.quickslot_operate_settings then
        Quickslot_operate_load_settings()
    end
    local old_func = g.settings.quickslot_operate.old_init_func
    if _G[old_func] then
        return
    end
    if g.settings.quickslot_operate.use == 1 then
        Quickslot_operate_init_logic()
    end
    return 0
end

function Quickslot_operate_init_logic()
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    _nexus_addons_p:SetVisible(1)
    g.setup_hook_and_event(g.addon, "SHOW_INDUNENTER_DIALOG", "Quickslot_operate_SHOW_INDUNENTER_DIALOG", true)
    Quickslot_operate_frame_init()
    local quickslot_operate_map_timer = _nexus_addons_p:CreateOrGetControl("timer", "quickslot_operate_map_timer", 0, 0)
    AUTO_CAST(quickslot_operate_map_timer)
    quickslot_operate_map_timer:SetUpdateScript("Quickslot_operate_map_change")
    quickslot_operate_map_timer:Stop()
    -- on_init はマップ移動のたびに走る(GAME_START_3SEC 経由)ので、打ち切り用の
    -- カウンタもここで毎回 0 に戻る。前のマップで諦めていても次のマップでやり直す。
    g.quickslot_operate_no_potion_ticks = 0
    g.quickslot_operate_no_item_ticks = 0
    g.quickslot_operate_no_map_ticks = 0
    quickslot_operate_map_timer:Start(3.0)
    if g.quickslot_operate_settings.rshift then
        local quickslot_operate_timer = _nexus_addons_p:CreateOrGetControl("timer", "quickslot_operate_timer", 0, 0)
        AUTO_CAST(quickslot_operate_timer)
        quickslot_operate_timer:SetUpdateScript("Quickslot_operate_set_rshift_script")
        quickslot_operate_timer:Start(0.15)
    end
end

function Quickslot_operate_frame_init()
    local quickslotnexpbar = ui.GetFrame("quickslotnexpbar")
    local setting = quickslotnexpbar:CreateOrGetControl("button", "setting", 0, 0, 30, 20)
    AUTO_CAST(setting)
    setting:SetMargin(-260, 0, 0, 55)
    setting:SetText("{ol}{s11}QSO")
    setting:SetGravity(ui.CENTER_HORZ, ui.BOTTOM)
    setting:SetTextTooltip(g.lang == "Japanese" and
                               "{ol}左クリック: スロットセット読込{nl}右クリック: 各種設定" or
                               "{ol}Left-click: Load Slot Set{nl}Right-click: Settings")
    setting:SetEventScript(ui.RBUTTONUP, "Quickslot_operate_context")
    setting:SetEventScript(ui.LBUTTONUP, "Quickslot_operate_load_slotset_context")
    Quickslot_operate_redraw_slots()
    quickslotnexpbar:SetUserValue("USE", 1)
    quickslotnexpbar:RunUpdateScript("Quickslot_operate_set_script", 2.0)
end

function Quickslot_operate_context()
    local context = ui.CreateContextMenu("CONTEXT", "{ol}slotset context", 0, -300, 0, 0)
    ui.AddContextMenuItem(context, "-----", "None")
    ui.AddContextMenuItem(context,
        g.lang == "Japanese" and "{ol}スロットレイアウト保存" or "{ol}Save Slot layout",
        "Quickslot_operate_save_slotset()")
    ui.AddContextMenuItem(context,
        g.lang == "Japanese" and "{ol}スロットレイアウト削除" or "{ol}Delete Slot layout",
        "Quickslot_operate_delete_slotset()")
    ui.AddContextMenuItem(context, "------", "None")
    if g.quickslot_operate_settings.rshift then
        ui.AddContextMenuItem(context, g.lang == "Japanese" and "{ol}RSHIFT {#FF0000}ON {#FFFF00}OFFにする" or
            "{ol}RSHIFT {#FF0000}ON {#FFFF00}Turn OFF", "Quickslot_operate_switch_rshift()")
    else
        ui.AddContextMenuItem(context, g.lang == "Japanese" and "{ol}RSHIFT {#FF0000}OFF {#FFFF00}ONにする" or
            "{ol}RSHIFT {#FF0000}OFF {#FFFF00}Turn ON", "Quickslot_operate_switch_rshift()")
    end
    ui.AddContextMenuItem(context, "-------", "None")
    ui.AddContextMenuItem(context,
        g.lang == "Japanese" and "{ol}ストレートモード切替" or "{ol}Switch straight mode",
        "Quickslot_operate_straight()")
    ui.OpenContextMenu(context)
end

function Quickslot_operate_redraw_slots()
    local qso_settings = g.quickslot_operate_settings
    local quickslotnexpbar = ui.GetFrame("quickslotnexpbar")
    local margin, margin_2, margin_3
    if qso_settings.straight then
        margin, margin_2, margin_3 = -200, -200, -200
    else
        margin, margin_2, margin_3 = -225, -250, -225
    end
    for i = 11, MAX_QUICKSLOT_CNT do
        local slot = GET_CHILD_RECURSIVELY(quickslotnexpbar, "slot" .. i)
        AUTO_CAST(slot)
        if i <= 20 then
            slot:SetMargin(margin, 230, 0, 0)
            margin = margin + 50
        elseif i <= 30 then
            slot:SetMargin(margin_2, 180, 0, 0)
            margin_2 = margin_2 + 50
        elseif i <= 40 then
            slot:SetMargin(margin_3, 130, 0, 0)
            margin_3 = margin_3 + 50
        end
    end
    quickslotnexpbar:Invalidate()
    DebounceScript("QUICKSLOTNEXTBAR_UPDATE_ALL_SLOT", 0.1)
end

function Quickslot_operate_straight()
    g.quickslot_operate_settings.straight = not g.quickslot_operate_settings.straight
    Quickslot_operate_save_settings()
    Quickslot_operate_redraw_slots()
end

function Quickslot_operate_save_slotset()
    if not g.quickslot_operate_settings.slotset[g.login_name] then
        g.quickslot_operate_settings.slotset[g.login_name] = {}
    end
    Quickslot_operate_INPUT_STRING_BOX()
end

function Quickslot_operate_INPUT_STRING_BOX()
    local inputstring = ui.GetFrame("inputstring")
    inputstring:Resize(500, 220)
    inputstring:SetLayerLevel(999)
    local edit = GET_CHILD(inputstring, 'input')
    AUTO_CAST(edit)
    edit:SetNumberMode(0)
    edit:SetMaxLen(99)
    edit:SetText("")
    inputstring:ShowWindow(1)
    inputstring:SetEnable(1)
    local title = inputstring:GetChild("title")
    AUTO_CAST(title)
    local text = g.lang == "Japanese" and "{ol}{#FFFFFF}セット名を入力" or "{ol}{#FFFFFF}Enter set name"
    title:SetText(text)
    local confirm = inputstring:GetChild("confirm")
    confirm:SetEventScript(ui.LBUTTONUP, "Quickslot_operate_save_setname")
    edit:SetEventScript(ui.ENTERKEY, "Quickslot_operate_save_setname")
    edit:AcquireFocus()
end

function Quickslot_operate_save_setname(inputstring, ctrl, str, num)
    inputstring:ShowWindow(0)
    local edit = GET_CHILD(inputstring, 'input')
    local get_text = edit:GetText()
    if get_text == "" then
        local text = g.lang == "Japanese" and "{ol}文字を入力してください" or "{ol}Please enter text"
        ui.SysMsg(text)
        Quickslot_operate_INPUT_STRING_BOX()
        return
    end
    g.quickslot_operate_settings.slotset[g.login_name][get_text] = {}
    local temp_data = g.quickslot_operate_settings.slotset[g.login_name][get_text]
    local main_session = session.GetMainSession()
    local pc_job_data = main_session:GetPCJobInfo()
    local job_count = pc_job_data:GetJobCount()
    for i = 0, job_count - 1 do
        local current_job_info = pc_job_data:GetJobInfoByIndex(i)
        if current_job_info then
            local job_key = "jobid_" .. i
            temp_data[job_key] = tonumber(current_job_info.jobID)
        end
    end
    local quickslotnexpbar = ui.GetFrame("quickslotnexpbar")
    for i = 1, 40 do
        local slot = GET_CHILD_RECURSIVELY(quickslotnexpbar, "slot" .. i)
        if slot then
            local icon = slot:GetIcon()
            if icon then
                local icon_info = icon:GetInfo()
                local category = icon_info:GetCategory()
                local item_type = icon_info.type
                local iesid = icon_info:GetIESID()
                temp_data[tostring(i)] = {
                    ["category"] = category,
                    ["type"] = item_type,
                    ["iesid"] = iesid
                }
            end
        end
    end
    ui.SysMsg(g.lang == "Japanese" and "{ol}スロットレイアウト保存" or "{ol}Save Slot layout")
    Quickslot_operate_save_settings()
end

function Quickslot_operate_load_slotset_context()
    local context = ui.CreateContextMenu("CONTEXT_LOAD", "{ol}Load Slotset", 0, -350, 0, 0)
    Quickslot_operate_build_slotset_menu(context, "LOAD")
    ui.OpenContextMenu(context)
end

function Quickslot_operate_delete_slotset()
    local context = ui.CreateContextMenu("CONTEXT", "{ol}Delete slotset", 0, -100, 0, 0)
    Quickslot_operate_build_slotset_menu(context, "DELETE")
    ui.OpenContextMenu(context)
end

function Quickslot_operate_delete_slotset_(name, title)
    g.quickslot_operate_settings.slotset[name][title] = nil
    Quickslot_operate_save_settings()
    local msg = name .. ":" .. title .. (g.lang == "Japanese" and " 削除しました" or " Deleted")
    ui.SysMsg(msg)
end

function Quickslot_operate_load_all_slot(name, title)
    local quickslotnexpbar = ui.GetFrame('quickslotnexpbar')
    for i = 1, MAX_QUICKSLOT_CNT do
        local str_index = tostring(i)
        local slot = GET_CHILD_RECURSIVELY(quickslotnexpbar, "slot" .. str_index)
        AUTO_CAST(slot)
        local slot_info = g.quickslot_operate_settings.slotset[name][title][str_index]
        if slot_info then
            local category = slot_info.category
            local clsid = slot_info.type
            local iesid = slot_info.iesid
            SET_QUICK_SLOT(quickslotnexpbar, slot, category, clsid, iesid, 0, true, true)
        else
            slot:ClearText()
            CLEAR_QUICKSLOT_SLOT(slot, 0, true)
        end
        slot:Invalidate()
    end
    quickslot.RequestSave()
    QUICKSLOTNEXPBAR_UPDATE_HOTKEYNAME(quickslotnexpbar)
    DebounceScript("QUICKSLOTNEXTBAR_UPDATE_ALL_SLOT", 0.1)
end

function Quickslot_operate_build_slotset_menu(context, mode)
    local slotset_data = g.quickslot_operate_settings.slotset
    if not slotset_data then
        return
    end
    ui.AddContextMenuItem(context, "-----", "None")
    for name, data in pairs(slotset_data) do
        for title, layout_data in pairs(data) do
            local display_name_parts = {}
            for i = 0, 3 do
                local job_key = "jobid_" .. i
                local saved_job_id = layout_data[job_key]
                if saved_job_id then
                    local job_cls = GetClassByType("Job", tonumber(saved_job_id))
                    if job_cls then
                        local job_name = dic.getTranslatedStr(TryGetProp(job_cls, "Name", "None"))
                        table.insert(display_name_parts, job_name)
                    end
                end
            end
            local display_str = table.concat(display_name_parts, ", ")
            local display_text, scp
            if mode == "DELETE" then
                display_text = string.format("%s : (%s)", tostring(title), tostring(display_str))
                scp = string.format("Quickslot_operate_delete_slotset_('%s','%s')", name, title)
            elseif mode == "LOAD" then
                display_text = string.format("%s : (%s)", tostring(title), tostring(display_str))
                scp = string.format("Quickslot_operate_load_all_slot('%s','%s')", name, title)
            end
            if display_text and scp then
                ui.AddContextMenuItem(context, display_text, scp)
            end
        end
    end
end

-- 「このアイテム ID は女神ポーションか」の逆引き。以前は Quickslot_operate_set_script の
-- 冒頭でだけ作っていたが、これは RunUpdateScript 経由でしか呼ばれない。差し替え本体
-- (check_all_slots)がそれより先に走ると g.qso_potion_map が nil のまま参照されて落ちるので、
-- 生成を切り出して、参照する側が自分で用意できるようにする。
function Quickslot_operate_build_potion_map()
    local map = {}
    for _, pots in pairs(g.quickslot_operate_atk_list) do
        for _, pot_id in ipairs(pots) do
            map[pot_id] = true
        end
    end
    for _, pot_id in pairs(g.quickslot_operate_def_list) do
        map[pot_id] = true
    end
    g.qso_potion_map = map
    return map
end

function Quickslot_operate_set_script(quickslotnexpbar)
    Quickslot_operate_build_potion_map()
    local is_use = quickslotnexpbar:GetUserIValue("USE")
    -- この関数は quickslotnexpbar への RunUpdateScript からしか呼ばれず、実機では
    -- 実行されていない（このログが一度も出ない）。マウスオーバーの種族選択パネルが
    -- 出ないのはそのため。ログは同じ調査を繰り返さないために残す。
    -- 印は出力できたときだけ立てる(core の g.vlog のコメント参照)。ログを ON にする前に
    -- 一度通っていると、印だけ立って「実行されたか」が二度と分からなくなる。
    if g.quickslot_operate_logged_use ~= is_use and
        g.vlog("quickslot_operate: set_script 実行 USE=%s", tostring(is_use)) then
        g.quickslot_operate_logged_use = is_use
    end
    for i = 1, MAX_QUICKSLOT_CNT do
        local slot = GET_CHILD_RECURSIVELY(quickslotnexpbar, "slot" .. i)
        AUTO_CAST(slot)
        local slot_info = quickslot.GetInfoByIndex(i - 1)
        if slot_info and slot_info.type ~= 0 then
            if slot_info and g.qso_potion_map[slot_info.type] then
                if is_use == 0 then
                    slot:SetEventScript(ui.MOUSEON, "None")
                else
                    slot:SetEventScript(ui.MOUSEON, "Quickslot_operate_choice_potion")
                end
            end
        end
    end
end

function Quickslot_operate_choice_potion(frame, slot, str, num)
    slot:RunUpdateScript("Quickslot_operate_frame_close", 5.0)
    local joystickquickslot = ui.GetFrame('joystickquickslot')
    joystickquickslot:RunUpdateScript("Quickslot_operate_frame_close", 5.0)
    local quickslot_operate = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "quickslot_operate", 0, 0, 0, 0)
    quickslot_operate:RemoveAllChild()
    quickslot_operate:Resize(150, 30)
    local map_frame = ui.GetFrame("map")
    local width = map_frame:GetWidth()
    quickslot_operate:SetPos(width / 2 - 75, 780)
    quickslot_operate:SetTitleBarSkin("None")
    quickslot_operate:SetSkinName("chat_window")
    quickslot_operate:SetLayerLevel(150)
    local slotset = quickslot_operate:CreateOrGetControl('slotset', 'slotset', 0, 0, 0, 0)
    AUTO_CAST(slotset)
    slotset:SetSlotSize(30, 30)
    slotset:EnablePop(0)
    slotset:EnableDrag(0)
    slotset:EnableDrop(0)
    slotset:SetColRow(5, 1)
    slotset:SetSpc(0, 0)
    slotset:SetSkinName('slot')
    slotset:CreateSlots()
    local slot_count = slotset:GetSlotCount()
    local atk_list = {640372, 640370, 640369, 640368, 640371}
    for i = 0, slot_count - 1 do
        local slot = slotset:GetSlotByIndex(i)
        slot:SetEventScript(ui.LBUTTONDOWN, "Quickslot_operate_set_potion")
        slot:SetEventScriptArgNumber(ui.LBUTTONDOWN, atk_list[i + 1])
        local class = GetClassByType('Item', atk_list[i + 1])
        SET_SLOT_ITEM_CLS(slot, class)
    end
    quickslot_operate:ShowWindow(1)
end

function Quickslot_operate_set_potion(parent, slot, str, pot_id)
    for race, data in pairs(g.quickslot_operate_atk_list) do
        for _, id in ipairs(data) do
            if id == pot_id then
                local down_potion_id = g.quickslot_operate_def_list[race]
                Quickslot_operate_check_all_slots(race, down_potion_id)
            end
        end
    end
end

-- スロットの差し替えには quickslotnexpbar が表示されている必要があるという
-- クライアント側の制約がある。以前はジョイスティックモードのとき
-- 「joystickquickslot を隠す → 差し替え → 戻す」としていたが、途中の早期 return や
-- エラーで復元を飛ばすと、ジョイスティックバーが消えたまま次のマップ移動まで戻らなかった。
--
-- そこで joystickquickslot には一切触れない。隠さないので消えようがない。
-- キーボード用バーだけを「完全に透明」にして一瞬表示するので、画面上でちらつかない。
-- 万一復元を飛ばしても、残るのは透明な quickslotnexpbar だけで見た目に影響しない。
function Quickslot_operate_begin_slot_edit()
    local quickslotnexpbar = ui.GetFrame("quickslotnexpbar")
    if IsJoyStickMode() ~= 1 then
        return quickslotnexpbar, false
    end
    quickslotnexpbar:SetAlpha(0)
    quickslotnexpbar:ShowWindow(1)
    return quickslotnexpbar, true
end

function Quickslot_operate_end_slot_edit(quickslotnexpbar, was_hidden)
    if was_hidden then
        -- ジョイスティックモードではキーボード用バーは元から非表示。透明のまま残すと
        -- クリックを吸う恐れがあるので、隠してから不透明に戻す(次に普通に表示された
        -- ときに透明のままにならないようにする)。
        quickslotnexpbar:ShowWindow(0)
        quickslotnexpbar:SetAlpha(100)
    end
    -- 隠していないジョイスティックバーは、中身だけ描き直してもらう(従来どおり毎回)。
    DebounceScript("JOYSTICK_QUICKSLOT_UPDATE_ALL_SLOT", 0.1)
end

function Quickslot_operate_check_all_slots(race, down_potion_id, atk_id, def_id)
    if not g.qso_potion_map then
        Quickslot_operate_build_potion_map()
    end
    local quickslotnexpbar, was_hidden = Quickslot_operate_begin_slot_edit()
    -- 差し替えの途中で落ちても必ず復元へ抜けるように pcall で囲む。
    local ok, err = pcall(Quickslot_operate_apply_slots, quickslotnexpbar, race, down_potion_id, atk_id, def_id)
    Quickslot_operate_end_slot_edit(quickslotnexpbar, was_hidden)
    -- 差し替えの成否によらずマップ監視は止める。apply_slots の中で止めていた頃は、
    -- 途中で落ちると 3 秒周期のタイマーが残り、同じエラーを黙って踏み続けていた。
    Quickslot_operate_stop_map_timer()
    if not ok then
        local msg = "QuickslotOperate スロット差し替えでエラー: " .. tostring(err)
        g.vlog("%s", msg)
        -- vlog は既定 OFF なので、利用者の手元には何も残らない。debug_log.txt にも出す。
        -- ただし RSHIFT 経路は 0.15 秒周期なので、同じエラーの連投は 1 回に丸める。
        if g.quickslot_operate_last_slot_error ~= msg then
            g.quickslot_operate_last_slot_error = msg
            g.log_to_file(msg)
        end
    else
        g.quickslot_operate_last_slot_error = nil
    end
end

function Quickslot_operate_apply_slots(quickslotnexpbar, race, down_potion_id, atk_id, def_id)
    local atk_list = g.quickslot_operate_atk_list
    for i = 1, MAX_QUICKSLOT_CNT do
        local slot = GET_CHILD_RECURSIVELY(quickslotnexpbar, "slot" .. i)
        AUTO_CAST(slot)
        local slot_info = quickslot.GetInfoByIndex(i - 1)
        if slot_info and g.qso_potion_map[slot_info.type] then
            local is_atk_potion = false
            for _, pot_ids in pairs(atk_list) do
                for _, pot_id in ipairs(pot_ids) do
                    if pot_id == slot_info.type then
                        is_atk_potion = true
                        break
                    end
                end
                if is_atk_potion then
                    break
                end
            end
            local target_race = race or detected_race
            if is_atk_potion then
                local new_atk_id = atk_id
                if not new_atk_id or new_atk_id == 0 then
                    if target_race then
                        local list = atk_list[target_race]
                        local inv_item = session.GetInvItemByType(list[1]) or session.GetInvItemByType(list[2])
                        if inv_item then
                            new_atk_id = inv_item.type
                        else
                            new_atk_id = list[1]
                        end
                    end
                end
                if new_atk_id and new_atk_id ~= 0 then
                    SET_QUICK_SLOT(quickslotnexpbar, slot, slot_info.category, new_atk_id, nil, 0, true, true)
                end
            else
                local new_def_id = def_id
                if not new_def_id or new_def_id == 0 then
                    if target_race then
                        new_def_id = g.quickslot_operate_def_list[target_race]
                    elseif down_potion_id then
                        new_def_id = down_potion_id
                    end
                end
                if new_def_id and new_def_id ~= 0 then
                    SET_QUICK_SLOT(quickslotnexpbar, slot, slot_info.category, new_def_id, nil, 0, true, true)
                end
            end
        end
    end
    -- マップ監視の停止は呼び出し元(check_all_slots)に移した。ここで止めると、
    -- 途中で落ちたときだけ止め損ねて無言のリトライが続くため。
    quickslot.RequestSave()
    QUICKSLOTNEXPBAR_UPDATE_HOTKEYNAME(quickslotnexpbar)
end

function Quickslot_operate_frame_close()
    local quickslot_operate = ui.GetFrame(addon_name_lower .. "quickslot_operate")
    if quickslot_operate then
        ui.DestroyFrame(quickslot_operate:GetName())
    end
end

function Quickslot_operate_stop_map_timer()
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    if not _nexus_addons_p then
        return
    end
    local quickslot_operate_map_timer = GET_CHILD(_nexus_addons_p, "quickslot_operate_map_timer")
    if quickslot_operate_map_timer then
        AUTO_CAST(quickslot_operate_map_timer)
        quickslot_operate_map_timer:Stop()
    end
end

-- クイックスロットに女神ポーションが 1 つでも入っているか。
-- 入っていなければ差し替える対象そのものが無いので、監視を続ける意味が無い。
function Quickslot_operate_has_potion_in_slots()
    if not g.qso_potion_map then
        Quickslot_operate_build_potion_map()
    end
    for i = 1, MAX_QUICKSLOT_CNT do
        local slot_info = quickslot.GetInfoByIndex(i - 1)
        if slot_info and g.qso_potion_map[slot_info.type] then
            return true
        end
    end
    return false
end

function Quickslot_operate_map_change(_nexus_addons_p, Quickslot_operate_map_timer)
    -- ポーションを 1 つも置いていない人には、この監視は最後まで空振りし続ける。
    -- ただし GAME_START 直後はクイックスロットの中身がまだ載っていないことがあり、
    -- 1 回見て無いだけで止めると、載る前に諦めてしまう。数回続けて見つからない
    -- ときだけ止める（3 秒周期なので約 15 秒ぶんの猶予）。打ち切りはこのマップ限りで、
    -- 次のマップ移動では init_logic がカウンタを戻してタイマーを張り直す。
    if not Quickslot_operate_has_potion_in_slots() then
        local ticks = (g.quickslot_operate_no_potion_ticks or 0) + 1
        g.quickslot_operate_no_potion_ticks = ticks
        if ticks >= 5 then
            Quickslot_operate_stop_map_timer()
            g.vlog("quickslot_operate: スロットに女神ポーションが無いのでマップ監視を止める (map=%s)",
                tostring(g.map_id))
        end
        return
    end
    g.quickslot_operate_no_potion_ticks = 0
    local quickslotnexpbar = ui.GetFrame("quickslotnexpbar")
    -- 11257/11267/11285/11286 は zone_list と guild_eventmap の両方に載っている。
    -- zone_list で種族を決められなくても下の eventmap 側が拾うので、ここでは
    -- 「載っていた」ことだけ憶えて、失敗ログは両方を試したあとで出す（そうしないと
    -- 正しく差し替えたマップに失敗ログが出るうえ、共有の unknown_map を消費して
    -- 「未登録のレイドマップ」の診断まで潰してしまう）。
    local in_zone_list = false
    for _, zone_id in ipairs(g.quickslot_operate_zone_list) do
        if zone_id == g.map_id then
            in_zone_list = true
            local potion_type = Quickslot_operate_get_potion_type(g.quickslot_operate_indun_type)
            if potion_type then
                g.vlog("quickslot_operate: map=%s indun_type=%s -> %s", tostring(g.map_id),
                    tostring(g.quickslot_operate_indun_type), potion_type)
                quickslotnexpbar:SetUserValue("POT_TYPE", potion_type)
                -- ここは 3 秒周期のタイマーから呼ばれる。RunUpdateScript を挟むと
                -- 実行が観測できなかった（実機ログで差し替えが一度も走らなかった）ので直接呼ぶ。
                -- 差し替えに成功すれば check_all_slots がこのタイマーを止める。第 2 引数の
                -- retryable は「空振りなら確定させず次の 3 秒に回してよい」の印(get_potion 参照)。
                Quickslot_operate_get_potion(quickslotnexpbar, true)
                return
            end
            break
        end
    end -- 11285, 11286
    for _, eventmap_id in ipairs(g.quickslot_guild_eventmap) do
        if eventmap_id == g.map_id then
            if eventmap_id == 11285 or eventmap_id == 11286 then
                quickslotnexpbar:SetUserValue("POT_TYPE", "Paramune")
            else
                quickslotnexpbar:SetUserValue("POT_TYPE", "Velnias")
            end
            Quickslot_operate_get_potion(quickslotnexpbar, true)
            return
        end
    end
    -- ここまで来た = このマップでは差し替えるものが無い。街や普通の狩り場がこれで、
    -- 何もしないまま次のマップ移動まで 3 秒ごとに回り続けていた。数回続けて空振り
    -- したら止める(3 秒周期なので約 15 秒ぶんの猶予。入場直後で indun_type がまだ
    -- 載っていないことがあるので即断はしない)。打ち切りはこのマップ限りで、
    -- 次のマップ移動では init_logic がカウンタを戻してタイマーを張り直す。
    local ticks = (g.quickslot_operate_no_map_ticks or 0) + 1
    g.quickslot_operate_no_map_ticks = ticks
    -- どちらの一覧でも差し替えられなかったときだけ理由を残す。3 秒ごとに走るので
    -- マップごとに 1 回に絞る。
    if g.quickslot_operate_unknown_map ~= g.map_id then
        if in_zone_list then
            g.quickslot_operate_unknown_map = g.map_id
            g.vlog("quickslot_operate: map=%s は対象だが種族を特定できない (indun_type=%s)", tostring(g.map_id),
                tostring(g.quickslot_operate_indun_type))
        elseif g.map_name and string.find(g.map_name, "^Raid_") then
            -- 対象マップの一覧はマップ ID の直値なので、新レイドが増えると取りこぼす。
            -- レイドマップに居るのに差し替えなかったときだけ、その ID を残す。
            g.quickslot_operate_unknown_map = g.map_id
            g.vlog("quickslot_operate: 未登録のレイドマップ name=%s id=%s (indun_type=%s)", tostring(g.map_name),
                tostring(g.map_id), tostring(g.quickslot_operate_indun_type))
        end
    end
    if ticks >= 5 then
        Quickslot_operate_stop_map_timer()
        g.vlog("quickslot_operate: map=%s は差し替えの対象外なのでマップ監視を止める (name=%s)", tostring(g.map_id),
            tostring(g.map_name))
    end
end

function Quickslot_operate_SHOW_INDUNENTER_DIALOG()
    if g.settings.quickslot_operate.use == 0 then
        return
    end
    local indunenter = ui.GetFrame('indunenter')
    local indun_type = tonumber(indunenter:GetUserValue("INDUN_TYPE"))
    g.quickslot_operate_indun_type = indun_type
    local potion_type = Quickslot_operate_get_potion_type(indun_type)
    g.vlog("quickslot_operate: 入場ダイアログ indun_type=%s -> %s", tostring(indun_type),
        tostring(potion_type or "該当なし"))
    if potion_type then
        local quickslotnexpbar = ui.GetFrame("quickslotnexpbar")
        quickslotnexpbar:SetUserValue("POT_TYPE", potion_type)
        Quickslot_operate_get_potion(quickslotnexpbar)
    end
end

function Quickslot_operate_get_potion_type(indun_type)
    for potion_type, indun_list in pairs(g.quickslot_operate_raid_list) do
        for _, indun_id in ipairs(indun_list) do
            if indun_id == indun_type then
                return potion_type
            end
        end
    end
    return nil
end

-- retryable = マップ監視タイマーから呼ばれた（＝空振りしても 3 秒後にまた来る）ことの印。
-- 入場ダイアログ経由(SHOW_INDUNENTER_DIALOG)は 1 回しか来ないので、こちらは付けない。
function Quickslot_operate_get_potion(quickslotnexpbar, retryable)
    local potion_type = quickslotnexpbar:GetUserValue("POT_TYPE")
    local atk_list = g.quickslot_operate_atk_list
    local def_list = g.quickslot_operate_def_list
    if not atk_list[potion_type] then
        g.vlog("quickslot_operate: POT_TYPE=%s は未知の種族なので差し替えない", tostring(potion_type))
        return
    end
    local atk_id = atk_list[potion_type][1]
    local inv_item = session.GetInvItemByType(atk_id)
    if not inv_item then
        atk_id = atk_list[potion_type][2]
        inv_item = session.GetInvItemByType(atk_id)
        if not inv_item then
            atk_id = 0
        end
    end
    local def_id = def_list[potion_type]
    inv_item = session.GetInvItemByType(def_id)
    if not inv_item then
        def_id = 0
    end
    g.vlog("quickslot_operate: %s に差し替え atk=%s def=%s (0 は未所持)", potion_type, tostring(atk_id),
        tostring(def_id))
    -- atk も def も見つからない = マップ読み込み直後でインベントリがまだ載っていない
    -- 可能性がある。この状態で確定させると check_all_slots が所持品を見ずに
    -- atk_list[1](新シリーズ)を書き込むので、旧シリーズしか持っていない人のスロットを
    -- 空にしたうえ、そのままタイマーが止まって直る機会も無くなる。
    -- タイマー経由のときだけ数回は確定させずに見送る（3 秒周期なので約 15 秒ぶん）。
    -- 本当に 1 本も持っていない人もいるので、猶予を使い切ったら従来どおり確定させる。
    if retryable and atk_id == 0 and def_id == 0 then
        local ticks = (g.quickslot_operate_no_item_ticks or 0) + 1
        g.quickslot_operate_no_item_ticks = ticks
        if ticks < 5 then
            g.vlog("quickslot_operate: %s の atk/def をどちらも所持していない。インベントリ未ロードとみて確定させず再試行する (%d/5)",
                potion_type, ticks)
            return
        end
        g.vlog("quickslot_operate: %s の atk/def を %d 回続けて所持していない。未所持として確定させる", potion_type,
            ticks)
    end
    g.quickslot_operate_no_item_ticks = 0
    Quickslot_operate_check_all_slots(potion_type, nil, atk_id, def_id)
end

function Quickslot_operate_switch_rshift(is_first)
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    _nexus_addons_p:SetVisible(1)
    if g.quickslot_operate_settings.rshift == true then
        g.quickslot_operate_settings.rshift = false
        local quickslot_operate_timer = GET_CHILD(_nexus_addons_p, "quickslot_operate_timer")
        if quickslot_operate_timer then
            _nexus_addons_p:RemoveChild("quickslot_operate_timer")
        end
    else
        g.quickslot_operate_settings.rshift = true
        local quickslot_operate_timer = _nexus_addons_p:CreateOrGetControl("timer", "quickslot_operate_timer", 0, 0)
        AUTO_CAST(quickslot_operate_timer)
        quickslot_operate_timer:SetUpdateScript("Quickslot_operate_set_rshift_script")
        quickslot_operate_timer:Start(0.15)
    end
    Quickslot_operate_save_settings()
end

-- この関数は 0.15 秒周期のタイマーから呼ばれる(= RSHIFT を押している間は毎秒約 7 回)。
-- 中のログをそのまま出すとチャットと verbose_log.txt が流れて肝心の行が埋もれるので、
-- 「押し始めの 1 回」と「離したときの要約」だけに絞る。判断材料(何回・最後にどれへ
-- 切り替わったか・種別を特定できなかった回数)は要約側に残す。
function Quickslot_operate_set_rshift_script()
    if keyboard.IsKeyPressed("RSHIFT") == 0 then
        if g.quickslot_operate_rshift_held then
            g.quickslot_operate_rshift_held = nil
            g.vlog("QuickslotOperate RSHIFT 循環: 押下終了 切替 %d 回 最終=%s 種別不明で中止 %d 回",
                g.quickslot_operate_rshift_count or 0, tostring(g.quickslot_operate_rshift_last),
                g.quickslot_operate_rshift_miss or 0)
        end
        return
    end
    if not g.quickslot_operate_rshift_held then
        g.quickslot_operate_rshift_held = true
        g.quickslot_operate_rshift_count = 0
        g.quickslot_operate_rshift_miss = 0
        g.quickslot_operate_rshift_last = nil
    end
    -- ここではバーの表示を触らない。現在のポーション種別を調べるだけなら表示は不要で、
    -- 実際に差し替える Quickslot_operate_check_all_slots が表示の面倒を見る。
    -- (以前はここで先に切り替えていたため、下の「ポーションが見つからない」early return を
    --  通るとジョイスティックバーが消えたまま戻らなかった)
    local current_potion_type = nil
    for i = 1, MAX_QUICKSLOT_CNT do
        local slot_info = quickslot.GetInfoByIndex(i - 1)
        if slot_info and slot_info.type ~= 0 then
            for race, pot_ids in pairs(g.quickslot_operate_atk_list) do
                for _, pot_id in ipairs(pot_ids) do
                    if pot_id == slot_info.type then
                        current_potion_type = race
                        break
                    end
                end
                if current_potion_type then
                    break
                end
            end
            if current_potion_type then
                break
            end
            for race, pot_id in pairs(g.quickslot_operate_def_list) do
                if pot_id == slot_info.type then
                    current_potion_type = race
                    break
                end
            end
        end
        if current_potion_type then
            break
        end
    end
    if not current_potion_type then
        -- 押下区間の 1 回目だけ出す(回数は離したときの要約に出る)。
        g.quickslot_operate_rshift_miss = (g.quickslot_operate_rshift_miss or 0) + 1
        if g.quickslot_operate_rshift_miss == 1 then
            g.vlog("QuickslotOperate RSHIFT 循環: 現在のポーション種別を特定できず中止")
        end
        return
    end
    local potion_type_order = {"Velnias", "Klaida", "Paramune", "Widling", "Forester"}
    local current_index = 0
    for i, p_type in ipairs(potion_type_order) do
        if p_type == current_potion_type then
            current_index = i
            break
        end
    end
    local next_index = (current_index % #potion_type_order) + 1
    local target_race = potion_type_order[next_index]
    local atk_ids = g.quickslot_operate_atk_list[target_race]
    local inv_atk = session.GetInvItemByType(atk_ids[1]) or session.GetInvItemByType(atk_ids[2])
    local found_atk_id = inv_atk and inv_atk.type or 0 -- 持ってなければ 0
    local def_id_candidate = g.quickslot_operate_def_list[target_race]
    local inv_def = session.GetInvItemByType(def_id_candidate)
    local found_def_id = inv_def and def_id_candidate or 0 -- 持ってなければ 0
    g.quickslot_operate_rshift_count = (g.quickslot_operate_rshift_count or 0) + 1
    g.quickslot_operate_rshift_last = target_race
    if g.quickslot_operate_rshift_count == 1 then
        g.vlog("QuickslotOperate RSHIFT 循環開始: %s -> %s (atk=%s def=%s)", tostring(current_potion_type),
            tostring(target_race), tostring(found_atk_id), tostring(found_def_id))
    end
    -- 2 回呼ぶのは従来どおり(1 回では反映が漏れることがあるため)。
    -- 常に真だった `if target_race then` のぶんだけ畳んでいる。
    Quickslot_operate_check_all_slots(target_race, nil, found_atk_id, found_def_id)
    quickslot.RequestSave()
    Quickslot_operate_check_all_slots(target_race, nil, found_atk_id, found_def_id)
    quickslot.RequestSave()
end
-- quickslot_operate ここまで

