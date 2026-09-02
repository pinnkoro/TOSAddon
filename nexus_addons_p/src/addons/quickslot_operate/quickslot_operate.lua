-- quickslot_operate ここから
g.quickslot_operate_raid_list = {
    -- 733/734 = 偽りの輝翼(A/S)、736/737 = 堕落した審判の翼(A/S)。どちらもボスの RaceType は Paramune。
    -- Hard(パーティ) は未実装なので、追加されたら 735 / 738 をここへ足す。
    Paramune = {623, 667, 666, 665, 674, 673, 675, 680, 679, 681, 707, 708, 710, 711, 709, 712, 722, 723, 724, 725, 726,
                727, 733, 734, 736, 737},
    Klaida = {686, 685, 687, 716, 717, 718},
    Velnias = {689, 688, 690, 669, 635, 628, 696, 695, 697},
    Forester = {672, 671, 670},
    -- 677/676/678 = 高位ファルオロス、729/730/731 = ズメイ(A/S/H)。ズメイは野獣なので Widling。
    -- 732 = 共鳴の聖所: ザウラ。レイドではないが同じくボス戦で、ザウラの RaceType も Widling。
    Widling = {677, 676, 678, 729, 730, 731, 732}
}
-- 差し替えの対象マップ(手書き)。**新レイドのたびにここへ足す必要は無い。**
-- レイドのマップは Quickslot_operate_build_map_race が raid_list から自動で拾う。
-- 残しているのは、そこから拾えない次の 2 つのため:
--   11257 / 11267 … ギルドイベントのマップ(quickslot_guild_eventmap 側で種族を決める)
-- 併せて「対象マップではあるが種族を決められない」状態を数えない判定にも使う。
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
    -- 保険。OFF のときは core が on_init ではなく quickslot_operate_on_teardown を呼ぶ。
    if g.settings.quickslot_operate.use == 0 then
        quickslot_operate_on_teardown()
        return
    end
    Quickslot_operate_init_logic()
end

-- RSHIFT 押下区間の記録を捨てる。**0.15 秒タイマーを消す側は必ずここを通すこと。**
-- 記録が残ったままだと「押している」と誤認したままになり、次に押しても
-- 押し始めのログが出ず、要約が前回の累計を混ぜて出る。
function Quickslot_operate_reset_rshift()
    g.qso_rshift = nil
end

-- 機能 OFF にされたときの後始末(core/20_lifecycle.lua が use==0 のとき on_init の
-- 代わりに呼ぶ)。外す前に止めておく(RemoveChild が効くまでに tick が来ないように)。
function quickslot_operate_on_teardown()
    -- 設定は OFF でも読んでおく(以前は on_init 経由の lazy_start が読んでいた)。
    -- 下の straight の戻しもこれが無いと素通りしてしまう。
    if not g.quickslot_operate_settings then
        Quickslot_operate_load_settings()
    end
    g.stop_timer("quickslot_operate_map_timer")
    g.stop_timer("quickslot_operate_timer")
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    if _nexus_addons_p then
        _nexus_addons_p:RemoveChild("quickslot_operate_map_timer")
        _nexus_addons_p:RemoveChild("quickslot_operate_timer")
    end
    Quickslot_operate_reset_rshift()
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
    g.quickslot_operate_slot_fails = 0
    -- マップ ID -> 種族。raid_list から毎回組み立てるので手入れは要らない。
    -- Indun / Map のクラスが引ければよく、街でも作れる(マップ移動のたびに作り直す)。
    if not g.quickslot_operate_map_race then
        local ok = pcall(Quickslot_operate_build_map_race)
        if not ok then
            g.vlog("{#FF6347}quickslot_operate: マップ種族表を作れなかった{/}")
        end
    end
    Quickslot_operate_reset_rshift()
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

-- アドオン一覧(メニューボタン)の「設定」から開く入口。
--
-- クイックスロットバー上の QSO ボタンは quickslotnexpbar の子なので、
-- **ジョイスティックモードではバーごと隠れて押せない**。RSHIFT の ON/OFF も
-- スロットセットの保存・読込も全部そこからなので、パッド操作の人は設定に
-- 一切たどり着けなかった(キーボードモードへ戻すしかなかった)。
-- 一覧側からも同じメニューを開けるようにする。
function Quickslot_operate_config_open()
    if not g.quickslot_operate_settings then
        Quickslot_operate_load_settings()
    end
    -- OFF のまま設定を触らせない。ここから RSHIFT を ON にすると、機能 OFF なのに
    -- 0.15 秒タイマーだけが動き出す(このリリースで潰したのと同じ形)。
    if g.settings.quickslot_operate.use == 0 then
        ui.SysMsg(g.lang == "Japanese" and
                      "{ol}{#FF6347}[Quickslot Operate]{/} 機能が OFF です。ON にしてから設定してください" or
                      "{ol}{#FF6347}[Quickslot Operate]{/} The addon is OFF. Turn it ON before changing settings.")
        return
    end
    Quickslot_operate_context()
end

function Quickslot_operate_context()
    local context = ui.CreateContextMenu("CONTEXT", "{ol}slotset context", 0, -300, 0, 0)
    ui.AddContextMenuItem(context, "-----", "None")
    -- 読込はバー上の QSO ボタンでは左クリック側にあるが、一覧の「設定」からは
    -- こちらのメニューしか開けないので、ここにも置いて全部たどり着けるようにする。
    ui.AddContextMenuItem(context, g.lang == "Japanese" and "{ol}スロットセット読込" or "{ol}Load Slot Set",
        "Quickslot_operate_load_slotset_context()")
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
    -- この関数は quickslotnexpbar への RunUpdateScript からしか呼ばれない。
    -- 以前は「実機で一度も実行されていない」と見ていたが、**それは誤りだった**:
    -- v1.4.0 の実機ログで `set_script 実行 USE=1` が出ている(レイド入場後に発火)。
    -- マウスオーバーの種族選択パネルが出ない件の原因はここではない。
    -- ログは同じ調査を繰り返さないために残す。
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
    g.block_click_through(quickslot_operate)
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
    g.esc_register(addon_name_lower .. "quickslot_operate", "Quickslot_operate_frame_close")
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

-- スロットの差し替えには quickslotnexpbar が表示されている必要がある、というのが
-- 元々の言い分。以前はジョイスティックモードのとき「joystickquickslot を隠す →
-- 差し替え → 戻す」としていたが、途中の早期 return やエラーで復元を飛ばすと、
-- ジョイスティックバーが消えたまま次のマップ移動まで戻らなかった。
--
-- 次に「キーボード用バーを SetAlpha(0) で透明にして出す」に変えたが、**これは効かない**。
-- **実機で確認済み(2026-07-29): SetAlpha はフレームのスキンにしか効かず、中のスロット
-- アイコンはそのまま描画される。**ジョイスティックモードで RSHIFT を押すと
-- キーボード用バーがはっきり見える。同じ調査を繰り返さないこと。
--
-- そこで今は「**まず表示を触らずに差し替えてみて、反映されていなかったときだけ出す**」
-- という順にしている(Quickslot_operate_check_all_slots)。キーボードモードでは元から
-- 出ているので一切触らず、ジョイスティックモードでも本当に必要なときしか出さない。
-- joystickquickslot には引き続き一切触れない(隠さないので消えようがない)。
--
-- **そして実機で確かめた結果、「表示が必要」という前提そのものが誤りだった**
-- (2026-07-29 / ジョイスティックモードで RSHIFT 循環 50 回以上):
--     quickslot_operate: 差し替えにバーの表示が不要だった (joystick=1)
-- バーを一度も出さずに全部成功し、画面にも出なくなった。
-- 下の「出してやり直す」経路は保険として残してあるだけで、通常は通らない。
-- **この経路を通ったらログに出る**ので、通ったという報告があるまで消さないこと。
--
-- 戻り値は「触る前の状態」。復元に使う。**推測で埋めないこと。**
-- 以前はジョイスティックモードかどうかだけで「元は非表示だったはず」と決めていたので、
-- ジョイスティックモードでキーボード用バーを出している人のバーを差し替えのたびに
-- 消してしまい(次のマップ移動まで戻らない)、透明度も 100 決め打ちで上書きしていた。
--
-- **透明度は保存も復元もしない。** ここで触るのは ShowWindow だけなので戻すものが無く、
-- GetAlpha が無いクライアントでは pcall のフォールバック 100 を掴んでしまう。
-- そのまま SetAlpha すると、利用者が設定したバーの透明度をこちらが勝手に
-- 不透明へ書き換えることになる(戻す手段はゲーム側の設定をやり直すしかない)。
function Quickslot_operate_begin_slot_edit(quickslotnexpbar)
    local restore = {
        visible = quickslotnexpbar:IsVisible()
    }
    quickslotnexpbar:ShowWindow(1)
    return restore
end

function Quickslot_operate_end_slot_edit(quickslotnexpbar, restore)
    if quickslotnexpbar and restore then
        -- 触る前の実測値へ戻す(触ったのは表示だけ。上のコメント参照)。
        quickslotnexpbar:ShowWindow(restore.visible)
    end
    -- 隠していないジョイスティックバーは、中身だけ描き直してもらう(従来どおり毎回)。
    DebounceScript("JOYSTICK_QUICKSLOT_UPDATE_ALL_SLOT", 0.1)
end

-- 差し替えが実際に効いたか。apply_slots が「こう入れたい」と投げた分を読み直す。
-- 対象が 0 件なら「やることが無かった」= 成功扱い(バーを出す必要も無い)。
function Quickslot_operate_slots_applied(targets)
    if not targets then
        return false
    end
    for _, t in ipairs(targets) do
        local slot_info = quickslot.GetInfoByIndex(t.index)
        if not slot_info or slot_info.type ~= t.id then
            return false
        end
    end
    return true
end

function Quickslot_operate_check_all_slots(race, down_potion_id, atk_id, def_id)
    if not g.qso_potion_map then
        Quickslot_operate_build_potion_map()
    end
    -- **表示の切り替えも pcall の中に入れること。** 以前は begin_slot_edit を外に
    -- 置いていたので、quickslotnexpbar がまだ組み上がっていない(マップ読み込み直後や
    -- バラック復帰直後)ときにそこで落ちると、復元もマップ監視の停止もエラーログも
    -- まとめて飛ばして、3 秒ごとに同じ所で無言のまま落ち続けた。
    local quickslotnexpbar = ui.GetFrame("quickslotnexpbar")
    local restore
    local ok, err = pcall(function()
        if not quickslotnexpbar then
            error("quickslotnexpbar がまだ無い", 0)
        end
        -- 1 回目は表示を一切触らずに試す。
        local targets = Quickslot_operate_apply_slots(quickslotnexpbar, race, down_potion_id, atk_id, def_id)
        if Quickslot_operate_slots_applied(targets) then
            return
        end
        -- 反映されていなかった = バーを出さないと差し替えられないクライアント。
        -- ここで初めて出す(ジョイスティックモードではこの瞬間だけ画面に見える)。
        restore = Quickslot_operate_begin_slot_edit(quickslotnexpbar)
        Quickslot_operate_apply_slots(quickslotnexpbar, race, down_potion_id, atk_id, def_id)
    end)
    Quickslot_operate_end_slot_edit(quickslotnexpbar, restore)
    if ok then
        g.quickslot_operate_slot_fails = 0
        g.clear_error_once("quickslot_operate_slot")
        -- 「バーを出す必要があったか」は判断の材料になるので残す。毎回出すと
        -- RSHIFT 経路(0.15 秒周期)で流れるので、変わったときだけ 1 行出す。
        local needed = restore ~= nil
        if g.quickslot_operate_needs_visible ~= needed and
            g.vlog("quickslot_operate: 差し替えにバーの表示が%s (joystick=%s)",
                needed and "必要だった" or "不要だった", tostring(IsJoyStickMode())) then
            g.quickslot_operate_needs_visible = needed
        end
        -- 差し替えられたのでマップ監視は要らない。
        Quickslot_operate_stop_map_timer()
        return
    end
    -- **一度の失敗で監視を止めないこと。** バーやスロットがまだ組み上がっていない
    -- だけのことがあり、止めるとそのマップでは二度と差し替わらない(3 秒後の再試行で
    -- 成功していた形を壊してしまう)。連続で失敗したときだけ止める。
    -- ログは g.log_error_once に任せる(RSHIFT 経路は 0.15 秒周期なので、
    -- 絞らないと同じ行が毎秒 13 本流れる)。
    g.log_error_once("quickslot_operate_slot", "QuickslotOperate スロット差し替えでエラー: " .. tostring(err))
    local fails = (g.quickslot_operate_slot_fails or 0) + 1
    g.quickslot_operate_slot_fails = fails
    if fails >= 5 then
        Quickslot_operate_stop_map_timer()
        g.vlog("quickslot_operate: 差し替えに %d 回続けて失敗したのでマップ監視を止める (map=%s)", fails,
            tostring(g.map_id))
    end
end

-- 戻り値は「このスロットにこの ID を入れたい」の一覧({index = 0 起点, id = アイテム ID})。
-- 呼び出し元が読み直して、実際に反映されたかを確かめるために使う
-- (Quickslot_operate_slots_applied)。0 件なら差し替える対象が無かったということ。
function Quickslot_operate_apply_slots(quickslotnexpbar, race, down_potion_id, atk_id, def_id)
    local atk_list = g.quickslot_operate_atk_list
    local targets = {}
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
            local target_race = race
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
                    table.insert(targets, {
                        index = i - 1,
                        id = new_atk_id
                    })
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
                    table.insert(targets, {
                        index = i - 1,
                        id = new_def_id
                    })
                end
            end
        end
    end
    -- マップ監視の停止は呼び出し元(check_all_slots)に移した。ここで止めると、
    -- 途中で落ちたときだけ止め損ねて無言のリトライが続くため。
    quickslot.RequestSave()
    QUICKSLOTNEXPBAR_UPDATE_HOTKEYNAME(quickslotnexpbar)
    return targets
end

function Quickslot_operate_frame_close()
    local quickslot_operate = ui.GetFrame(addon_name_lower .. "quickslot_operate")
    if quickslot_operate then
        ui.DestroyFrame(quickslot_operate:GetName())
    end
end

function Quickslot_operate_stop_map_timer()
    return g.stop_timer("quickslot_operate_map_timer")
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
    -- マップから種族を引けるならそこも対象マップとして扱う。zone_list は手書きの
    -- マップ ID の一覧で、新レイドのたびに足す必要があった(Lv560 の 3 マップが抜けていた)。
    local map_race = Quickslot_operate_get_potion_type_by_map(g.map_id)
    -- **「対象マップか」と「種族が一意に決まったか」は別物。**
    -- 種族が食い違うマップ(表に false が入っている)も *対象マップではある* ので、
    -- map_race が nil であることを理由に弾いてはいけない。弾くと
    --   * ダイアログ経由で覚えた by_indun のフォールバックまで届かない
    --   * 「対象外」と数えられて 15 秒ほどでマップ監視が止まる
    --   * 診断ログも「未登録のレイドマップ」になる(登録はされているのに)
    -- となる。所属は表にキーがあるか(~= nil)で見る。
    local map_race_tbl = g.quickslot_operate_map_race
    local in_zone_list = map_race_tbl ~= nil and map_race_tbl[g.map_id] ~= nil
    for _, zone_id in ipairs(g.quickslot_operate_zone_list) do
        if zone_id == g.map_id then
            in_zone_list = true
            break
        end
    end
    if in_zone_list then
        -- **今いるマップから引いた種族を優先する。**
        -- g.quickslot_operate_indun_type は入場ダイアログの 1 箇所でしか代入されず、
        -- どこでもクリアされないので**セッション中ずっと残る**(古い記憶になる)。
        -- クリアはできない。ダイアログは街で発火し、その後のマップ移動で init_logic が
        -- 走るので、そこで消すと**到着時に消えて本来効く経路まで壊れる**。
        -- 代わりに、マップ由来(= 今いる場所から導いた確実な情報)を先に見て、
        -- 記憶のほうは**そのマップのものだったときだけ**使う。これをしないと、
        -- 種族 X のレイドへダイアログ経由で入ったあと、ダイアログを通らない経路で
        -- 種族 Y のレイドへ入ったときに X のポーションへ差し替えてしまう
        -- (この取り違えは今回の変更以前から成立していた)。
        local remembered = g.quickslot_operate_indun_type
        local by_indun = nil
        if remembered then
            -- **捨てるのは「解決できて、別のマップだった」ときだけ。**
            -- 解決に失敗した(nil)ものまで捨てると、MapName を引けないレイドで
            -- ダイアログを正しく通ったのに差し替わらなくなる。そういうレイドは
            -- map_race にも載らない(同じ解決を使っている)ので、ここが最後の拠り所になる。
            local remembered_map = Quickslot_operate_indun_map_id(remembered)
            if remembered_map == nil or remembered_map == g.map_id then
                by_indun = Quickslot_operate_get_potion_type(remembered)
            end
        end
        local potion_type = map_race or by_indun
        if potion_type then
            g.vlog("quickslot_operate: map=%s indun_type=%s -> %s (%s)", tostring(g.map_id),
                tostring(remembered), potion_type, map_race and "マップ" or "indun_type")
            quickslotnexpbar:SetUserValue("POT_TYPE", potion_type)
            -- ここは 3 秒周期のタイマーから呼ばれる。RunUpdateScript を挟むと
            -- 実行が観測できなかった（実機ログで差し替えが一度も走らなかった）ので直接呼ぶ。
            -- 差し替えに成功すれば check_all_slots がこのタイマーを止める。第 2 引数の
            -- retryable は「空振りなら確定させず次の 3 秒に回してよい」の印(get_potion 参照)。
            Quickslot_operate_get_potion(quickslotnexpbar, true)
            return
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
    --
    -- ただし in_zone_list = **対象マップではあるが indun_type がまだ載っていない**
    -- 状態は数えない。indun_type を載せるのは入場ダイアログ
    -- (Quickslot_operate_SHOW_INDUNENTER_DIALOG)だけなので、パーティリーダーに
    -- 飛ばされた・再入場した・レイドの中で再ログインした人はそこを通らない。
    -- 数えて打ち切ると、そういう人だけレイド中ずっと差し替わらなくなる。
    local ticks = g.quickslot_operate_no_map_ticks or 0
    if not in_zone_list then
        ticks = ticks + 1
        g.quickslot_operate_no_map_ticks = ticks
    end
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
    if not in_zone_list and ticks >= 5 then
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

-- マップ ID から種族を引く表を quickslot_operate_raid_list から組み立てる。
--
-- **indun_type だけでは足りない。** 種族を決める indun_type を載せているのは入場
-- ダイアログ(Quickslot_operate_SHOW_INDUNENTER_DIALOG)だけで、次の経路はそこを通らない。
--   * パーティリーダーに飛ばされた / 再入場した / レイドの中で再ログインした
--   * Indun Panel の SOLO / AUTO(ReqRaidAutoUIOpen 経由。素の Lua に実体が無く、
--     サーバーがダイアログを出すかは静的に確かめられない)
-- そういう人は差し替えが一度も走らない。マップに居ることは分かっているので、
-- indun_type が取れないときはマップから引く。
--
-- **表は手で持たない。** 手書きのマップ ID の一覧(quickslot_operate_zone_list)は
-- 新レイドのたびに足す必要があり、実際 Lv560 の 3 マップが抜けていた。
-- raid_list は種族ごとに indun ID を持っているので、Indun -> MapName -> Map の
-- ClassID を辿れば同じ表を毎回作れる。**raid_list に足せばこちらは自動で追随する。**
-- indun_type からそのダンジョンのマップ ID を引く。引けなければ nil
function Quickslot_operate_indun_map_id(indun_type)
    if not indun_type then
        return nil
    end
    local indun_cls = GetClassByType("Indun", indun_type)
    local map_name = indun_cls and TryGetProp(indun_cls, "MapName", "None")
    if not map_name or map_name == "None" or map_name == "" then
        return nil
    end
    local map_cls = GetClass("Map", map_name)
    if not map_cls then
        return nil
    end
    local map_id = tonumber(TryGetProp(map_cls, "ClassID", 0))
    if map_id and map_id > 0 then
        return map_id
    end
    return nil
end

function Quickslot_operate_build_map_race()
    local map_race = {}
    for potion_type, indun_list in pairs(g.quickslot_operate_raid_list) do
        for _, indun_id in ipairs(indun_list) do
            local map_id = Quickslot_operate_indun_map_id(indun_id)
            -- 同じマップを複数のレイドが使うことがある(格動の核 = ファロウロス
            -- と変質の伝播者)。先に入ったほうを残さず、**種族が食い違うことだけ
            -- 記録して差し替えない**。誤った種族を当てるより何もしないほうがよい。
            if map_id then
                if map_race[map_id] == nil then
                    map_race[map_id] = potion_type
                elseif map_race[map_id] ~= potion_type and map_race[map_id] ~= false then
                    g.vlog("quickslot_operate: map=%d に種族が 2 つ(%s / %s)。マップからは決めない", map_id,
                        tostring(map_race[map_id]), tostring(potion_type))
                    map_race[map_id] = false
                end
            end
        end
    end
    -- **1 件も解決できなかったときは確定させない。** raid_list は静的な非空リテラルなので、
    -- 空になるのは Indun / Map のクラスをまだ引けないときだけ。空表も Lua では真なので、
    -- そのまま入れると呼び出し側の「まだ作っていなければ作る」判定を素通りしてしまい、
    -- **そのセッション中ずっと空のまま**になる。入れなければ次のマップ移動でやり直せる。
    if next(map_race) == nil then
        g.vlog("{#FF6347}quickslot_operate: マップ種族表が空。次のマップ移動でやり直す{/}")
        return
    end
    g.quickslot_operate_map_race = map_race
end

-- マップから引いた種族。食い違いのあるマップ(false)は決めない
function Quickslot_operate_get_potion_type_by_map(map_id)
    local map_race = g.quickslot_operate_map_race
    if not map_race then
        return nil
    end
    local race = map_race[map_id]
    if race == false then
        return nil
    end
    return race
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
    -- 機能 OFF のまま ON にされると、アドオンは OFF なのに 0.15 秒タイマーだけが
    -- 動き出す。設定は保存するが、タイマーは張らない(次に ON にしたとき
    -- Quickslot_operate_init_logic が rshift 設定を見て張る)。
    if g.settings.quickslot_operate.use == 0 then
        g.quickslot_operate_settings.rshift = not g.quickslot_operate_settings.rshift
        Quickslot_operate_save_settings()
        return
    end
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    _nexus_addons_p:SetVisible(1)
    if g.quickslot_operate_settings.rshift == true then
        g.quickslot_operate_settings.rshift = false
        g.stop_timer("quickslot_operate_timer")
        _nexus_addons_p:RemoveChild("quickslot_operate_timer")
        -- 押したままここへ来る(片手で RSHIFT、もう片手で切り替え)ことがある。
        -- 捨てておかないと「押している」と誤認したままになる。
        Quickslot_operate_reset_rshift()
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
    -- 押下区間の状態は 1 つのテーブルにまとめて持ち、**存在そのものを「押している」の
    -- 印にする**。以前は held / count / miss / last の 4 つを別々に持ち、リセットは
    -- 押し始めの 1 箇所だけだった。押したままタイマーを消される経路が 2 つあり
    -- (Quickslot_operate_switch_rshift / 機能 OFF)、そこを通ると held が true のまま
    -- 残って、以降このログが二度と正しい値を出さなくなった。
    -- 消す側は g.qso_rshift = nil を書くだけでよい(Quickslot_operate_reset_rshift)。
    if keyboard.IsKeyPressed("RSHIFT") == 0 then
        local held = g.qso_rshift
        if held then
            g.qso_rshift = nil
            g.vlog("QuickslotOperate RSHIFT 循環: 押下終了 切替 %d 回 最終=%s 種別不明で中止 %d 回", held.count,
                tostring(held.last), held.miss)
        end
        return
    end
    if not g.qso_rshift then
        g.qso_rshift = {
            count = 0,
            miss = 0,
            last = nil
        }
    end
    local held = g.qso_rshift
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
        held.miss = held.miss + 1
        if held.miss == 1 then
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
    held.count = held.count + 1
    held.last = target_race
    if held.count == 1 then
        g.vlog("QuickslotOperate RSHIFT 循環開始: %s -> %s (atk=%s def=%s)", tostring(current_potion_type),
            tostring(target_race), tostring(found_atk_id), tostring(found_def_id))
    end
    -- 2 回呼ぶのは従来どおり(1 回では反映が漏れることがあるため)。
    -- **quickslot.RequestSave() をここで足さないこと。** Quickslot_operate_apply_slots が
    -- 最後に毎回出しているので、足すと 1 tick あたり 4 回 = 0.15 秒周期で毎秒約 27 回の
    -- 保存要求をサーバへ投げることになる。
    for _ = 1, 2 do
        Quickslot_operate_check_all_slots(target_race, nil, found_atk_id, found_def_id)
    end
end
-- quickslot_operate ここまで

