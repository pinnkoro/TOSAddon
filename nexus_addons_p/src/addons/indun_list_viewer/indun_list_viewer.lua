-- ndun_list_viewer ここから
g.ilv_RAID_KEYS = {"Z", "V", "L", "R", "N", "G", "M", "S", "U", "RO", "F", "P", "D"}
g.ilv_RAID_INFO = {
    Z = {
        name = "Zmei",
        hard = 731,
        solo = 730,
        auto = 729,
        icon = "icon_item_misc_boss_Zmei",
        sweep_buff = 80047
    },
    V = {
        name = "Veliora",
        hard = 727,
        solo = 726,
        auto = 725,
        icon = "icon_item_misc_boss_Veliora",
        sweep_buff = 80045
    },
    L = {
        name = "Limara",
        hard = 724,
        solo = 723,
        auto = 722,
        icon = "icon_item_misc_boss_Laimara",
        sweep_buff = 80043
    },
    R = {
        name = "Redania",
        hard = 718,
        solo = 717,
        auto = 716,
        icon = "icon_item_misc_boss_Redania",
        sweep_buff = 80039
    },
    N = {
        name = "Neringa",
        hard = 709,
        solo = 708,
        auto = 707,
        icon = "icon_item_misc_boss_DarkNeringa",
        sweep_buff = 80035
    },
    G = {
        name = "Golem",
        hard = 712,
        solo = 711,
        auto = 710,
        icon = "icon_item_misc_boss_CrystalGolem",
        sweep_buff = 80037
    },
    M = {
        name = "Merregina",
        hard = 697,
        solo = 696,
        auto = 695,
        icon = "icon_item_misc_merregina_blackpearl",
        sweep_buff = 80032
    },
    S = {
        name = "Slogutis",
        hard = 690,
        solo = 689,
        auto = 688,
        icon = "icon_item_misc_boss_Slogutis",
        sweep_buff = 80031
    },
    U = {
        name = "Upinis",
        hard = 687,
        solo = 686,
        auto = 685,
        icon = "icon_item_misc_boss_Upinis",
        sweep_buff = 80030
    },
    RO = {
        name = "Roze",
        hard = 681,
        solo = 680,
        auto = 679,
        icon = "icon_item_misc_boss_Roze",
        sweep_buff = 80015
    },
    F = {
        name = "Falouros",
        hard = 678,
        solo = 677,
        auto = 676,
        icon = "icon_item_misc_high_falouros",
        sweep_buff = 80017
    },
    P = {
        name = "Spreader",
        hard = 675,
        solo = 674,
        auto = 673,
        icon = "icon_item_misc_high_transmutationSpreader",
        sweep_buff = 80016
    },
    D = {
        name = "Delmore",
        hard = 665,
        solo = 667,
        auto = 666,
        icon = "icon_item_misc_RevivalPaulius",
        sweep_buff = nil
    }
}
-- 掃討バフ(sweep_buff)一覧は ilv_RAID_INFO から生成する。
-- 新レイド追加時に個別リストを手動更新する必要をなくし、更新漏れを防ぐ。
g.ilv_sweep_buffs = {}
for _, info in pairs(g.ilv_RAID_INFO) do
    if info.sweep_buff then
        table.insert(g.ilv_sweep_buffs, info.sweep_buff)
    end
end
function Indun_list_viewer_save_settings()
    g.save_lua(g.ilv_path, g.ilv_settings)
end

function Indun_list_viewer_load_settings()
    g.ilv_path = string.format("../addons/%s/%s/indun_list_viewer.lua", addon_name_lower, g.active_id)
    local json_path = string.format("../addons/%s/%s/indun_list_viewer.json", addon_name_lower, g.active_id)
    g.ilv_old_path = string.format("../addons/%s/%s/settings_2510.json", "indun_list_viewer", g.active_id)
    local settings = g.load_lua(g.ilv_path)
    local need_save = false
    local ver = 1.2 -- ズメイ追加: 既存ユーザーの display に Zmei_H/Zmei_S を補完するため繰り上げ
    if not settings then
        settings = g.load_json(json_path)
        if settings then
            need_save = true
        end
    end
    if not settings then
        local old_settings = g.load_json(g.ilv_old_path)
        if old_settings then
            settings = {
                options = old_settings.default_options or {},
                display = old_settings.display_options or {},
                chars = {},
                ver = 0 -- 新規作成時は0にし、下のバックフィルで display の H/S キーを補完させる
            }
            for key, data in pairs(old_settings) do
                if type(data) == "table" and key ~= "default_options" and key ~= "display_options" then
                    settings.chars[key] = data
                end
            end
        else
            settings = {
                options = {
                    reset_time = 0,
                    display_mode = "full",
                    hidden = 0
                },
                display = {
                    Memo = 1
                },
                chars = {},
                ver = 0 -- 新規作成時は0にし、下のバックフィルで display の H/S キーを補完させる
            }
        end
        need_save = true
    end
    if not settings.ver or settings.ver < ver then
        if not settings.display then
            settings.display = {}
        end
        if settings.display.Memo == nil then
            settings.display.Memo = 1
        end
        for _, info in pairs(g.ilv_RAID_INFO) do
            if info.name then
                local h_key = info.name .. "_H"
                local s_key = info.name .. "_S"
                if info.hard and settings.display[h_key] == nil then
                    settings.display[h_key] = 1
                end
                if settings.display[s_key] == nil then
                    settings.display[s_key] = 1
                end
            end
        end
        settings.ver = ver
        need_save = true
    end
    g.ilv_settings = settings
    if need_save then
        Indun_list_viewer_save_settings()
    end
end

function Indun_list_viewer_char_load_settings()
    local acc_info = session.barrack.GetMyAccount()
    if acc_info then
        local layer_pc_count = acc_info:GetPCCount()
        local barrack_all = acc_info:GetBarrackPCCount()
        for order = 0, layer_pc_count - 1 do
            local pc_info = acc_info:GetPCByIndex(order)
            if pc_info then
                local pc_apc = pc_info:GetApc()
                local pc_name = pc_apc:GetName()
                local pc_cid = pc_info:GetCID()
                local existing_data = g.ilv_settings.chars[pc_name] or {}
                g.ilv_settings.chars[pc_name] = {
                    layer = g.ilv_layer or existing_data.layer or 9,
                    order = order,
                    hide = existing_data.hide or false,
                    memo = existing_data.memo or "",
                    president_jobid = existing_data.president_jobid or "",
                    jobid = existing_data.jobid or "",
                    raid_count = existing_data.raid_count or {},
                    auto_clear_count = existing_data.auto_clear_count or {},
                    cid = pc_cid,
                    pc_name = pc_name
                }
            end
        end
        if barrack_all > 0 then
            local barrack_chars = {}
            for i = 0, barrack_all - 1 do
                local pc_info = acc_info:GetBarrackPCByIndex(i)
                if pc_info then
                    barrack_chars[pc_info:GetName()] = true
                end
            end
            local chars_to_delete = {}
            for char_name, _ in pairs(g.ilv_settings.chars) do
                if not barrack_chars[char_name] then
                    table.insert(chars_to_delete, char_name)
                end
            end
            for _, char_name in ipairs(chars_to_delete) do
                g.ilv_settings.chars[char_name] = nil
            end
        end
        Indun_list_viewer_save_settings()
        return
    end
    if g.get_map_type() == "City" then
        local pc_name = session.GetMySession():GetPCApc():GetName()
        local pc_cid = session.GetMySession():GetCID()
        local existing_data = g.ilv_settings.chars[pc_name] or {}
        g.ilv_settings.chars[pc_name] = {
            layer = g.ilv_layer or existing_data.layer or 1,
            order = existing_data.order or 99,
            hide = existing_data.hide or false,
            memo = existing_data.memo or "",
            president_jobid = existing_data.president_jobid or "",
            jobid = existing_data.jobid or "",
            raid_count = existing_data.raid_count or {},
            auto_clear_count = existing_data.auto_clear_count or {},
            cid = pc_cid,
            pc_name = pc_name
        }
        Indun_list_viewer_save_settings()
    end
end

function indun_list_viewer_on_init()
    if _G["BARRACK_CHARLIST_ON_INIT"] and _G["current_layer"] then
        g.ilv_layer = _G["current_layer"]
    end
    if not g.ilv_settings then
        Indun_list_viewer_load_settings()
    end
    local old_func = g.settings.indun_list_viewer.old_init_func
    if _G[old_func] then
        return
    end
    g.addon:RegisterMsg("EXPIREDITEM_ALERT_OPEN", "Indun_list_viewer_EXPIREDITEM_ALERT_ON_MSG")
    if g.get_map_type() == "City" then
        Indun_list_viewer_char_load_settings()
        Indun_list_viewer_sort_characters()
        Indun_list_viewer_raid_reset_reserve()
        Indun_list_viewer_save_current_char_counts()
    end
    if g.settings.indun_list_viewer.use == 0 then
        if _G["indun_list_viewer_title_frame_open"] == _G["Indun_list_viewer_title_frame_open"] then
            _G["indun_list_viewer_title_frame_open"] = nil
        end
    else
        if type(_G["Indun_list_viewer_title_frame_open"]) == "function" then
            if type(_G["indun_list_viewer_title_frame_open"]) ~= "function" then
                _G["indun_list_viewer_title_frame_open"] = _G["Indun_list_viewer_title_frame_open"]
            end
        end
    end
    -- ESC は core 側でまとめて受ける(ここで購読すると他のウィンドウも一緒に閉じる)
    g.setup_hook_and_event(g.addon, "STATUS_SELET_REPRESENTATION_CLASS",
        "Indun_list_viewer_STATUS_SELET_REPRESENTATION_CLASS", true)
    g.setup_hook(Indun_list_viewer_EXPIREDITEM_ALERT_OK_BTN, "EXPIREDITEM_ALERT_OK_BTN")
end

function Indun_list_viewer_CHECK_ALERT(type)
    if g.settings.indun_list_viewer.use == 0 then
        return false
    end
    type = type or "Barrack" -- typeが無い場合はBarrack扱い
    if type == "Barrack" or type == "Logout" or type == "Exit" then
        local expireditem_alert = ui.GetFrame("expireditem_alert")
        local near_future_sec = tonumber(expireditem_alert:GetUserConfig("NearFutureSec"))
        local need_item = false
        local need_token = false
        if near_future_sec then
            local list = GET_SCHEDULED_TO_EXPIRED_ITEM_LIST(near_future_sec)
            need_item = (list ~= nil and #list > 0)
            need_token = IS_NEED_TO_ALERT_TOKEN_EXPIRATION(near_future_sec)
        end
        local sweep_buffs = g.ilv_sweep_buffs
        local sweep_tbl = {}
        local my_handle = session.GetMyHandle()
        local limit_time_ms = 12 * 60 * 60 * 1000
        for _, buff_id in ipairs(sweep_buffs) do
            local buff_info = info.GetBuff(my_handle, buff_id)
            if buff_info and buff_info.time <= limit_time_ms then
                table.insert(sweep_tbl, {
                    buff_over = buff_info.over,
                    buff_time = buff_info.time,
                    buff_id = buff_id
                })
            end
        end
        if need_item or need_token or #sweep_tbl > 0 then
            Indun_list_viewer_EXPIREDITEM_ALERT_OPEN(nil, type, sweep_tbl)
            return true -- 警告あり
        end
    end
    return false -- 警告なし
end

function Indun_list_viewer_EXPIREDITEM_ALERT_OPEN(frame, arg_str, tbl, cid, layer)
    local expireditem_alert = ui.GetFrame("expireditem_alert")
    local near_future_sec = tonumber(expireditem_alert:GetUserConfig("NearFutureSec"))
    local itemlist = GET_CHILD(expireditem_alert, "itemlist", "ui::CGroupBox")
    itemlist:RemoveAllChild()
    local start_index = 0
    local ypos = 0
    if tbl then
        for key, data in ipairs(tbl) do
            if type(data) == "table" then
                local ctrlset = itemlist:CreateOrGetControlSet("expireditem_ctrlset",
                    "expireditem_ctrlset" .. start_index + 1, 0, ypos)
                AUTO_CAST(ctrlset)
                local name = GET_CHILD_RECURSIVELY(ctrlset, "name", "ui::CRichText")
                local expiration_time = GET_CHILD_RECURSIVELY(ctrlset, "expirationTime", "ui::CRichText")
                local remaining_time = GET_CHILD_RECURSIVELY(ctrlset, "remainingTime", "ui::CRichText")
                local item_pic = GET_CHILD_RECURSIVELY(ctrlset, "item_pic", "ui::CPicture")
                local buff_cls = GetClassByType("Buff", data.buff_id)
                if buff_cls then
                    name:SetTextByKey("itemname", buff_cls.Name)
                    local icon_name = "icon_" .. buff_cls.Icon
                    item_pic:SetImage(icon_name)
                end
                local expiration_systime = geTime.GetServerSystemTime()
                expiration_systime = imcTime.AddSec(expiration_systime, data.buff_time / 1000)
                expiration_time:SetTextByKey("year", expiration_systime.wYear)
                expiration_time:SetTextByKey("month", GET_TWO_DIGIT_STR(expiration_systime.wMonth))
                expiration_time:SetTextByKey("day", GET_TWO_DIGIT_STR(expiration_systime.wDay))
                local buff_time = data.buff_time / 1000
                local days = math.floor(buff_time / 86400)
                local hours = math.floor((buff_time % 86400) / 3600)
                local mins = math.floor(((buff_time % 86400) % 3600) / 60)
                local sec = ((buff_time % 86400) % 3600) % 60
                local dif_sec_msg = ""
                if days > 0 then
                    dif_sec_msg = ScpArgMsg("{Day}Day{Hour}Hour{Min}Min", "Day", days, "Hour", hours, "Min", mins)
                elseif hours > 0 then
                    dif_sec_msg = ScpArgMsg("{Hour}Hour{Min}Min{Sec}Sec", "Hour", hours, "Min", mins, "Sec", sec)
                elseif mins > 0 then
                    dif_sec_msg = ScpArgMsg("{Min}Min{Sec}Sec", "Min", mins, "Sec", sec)
                else
                    dif_sec_msg = ScpArgMsg("{Sec}Sec", "Sec", sec)
                end
                remaining_time:SetText(dif_sec_msg)
                local time_parent = remaining_time:GetParent()
                local amend_h = remaining_time:GetY() + remaining_time:GetHeight()
                if amend_h < time_parent:GetHeight() then
                    amend_h = ctrlset:GetHeight()
                else
                    local addedHeight = amend_h - time_parent:GetHeight()
                    ctrlset:Resize(ctrlset:GetWidth(), ctrlset:GetHeight() + addedHeight)
                end
                ypos = ypos + ctrlset:GetHeight()
                start_index = start_index + 1
            end
        end
    end
    if IS_NEED_TO_ALERT_TOKEN_EXPIRATION(near_future_sec, itemlist) then
        ypos = ASK_EXPIREDITEM_ALERT_TOKEN(expireditem_alert, itemlist, start_index, ypos)
        start_index = start_index + 1
    end
    local list = GET_SCHEDULED_TO_EXPIRED_ITEM_LIST(near_future_sec)
    if list and #list >= 1 then
        ypos = ASK_EXPIREDITEM_ALERT_LIFETIME(expireditem_alert, itemlist, near_future_sec, start_index, ypos)
        start_index = start_index + #list
    end
    expireditem_alert:Resize(expireditem_alert:GetWidth(), expireditem_alert:GetOriginalHeight() + itemlist:GetHeight())
    if arg_str then
        expireditem_alert:SetUserValue("TimerType", arg_str)
    end
    if cid then
        expireditem_alert:SetUserValue("CC_CID", cid)
        expireditem_alert:SetUserValue("CC_LAYER", layer or 0)
    else
        expireditem_alert:SetUserValue("CC_CID", "None")
    end
    expireditem_alert:ShowWindow(1)
end

local function get_safe_entrance_count(indun_type)
    local indun_cls = GetClassByType("Indun", indun_type)
    if indun_cls and indun_cls.PlayPerResetType then
        return GET_CURRENT_ENTERANCE_COUNT(indun_cls.PlayPerResetType)
    end
    return nil
end

function Indun_list_viewer_save_current_char_counts()
    if g.get_map_type() ~= "City" then
        return
    end
    local raid_data = {}
    for key, raid in pairs(g.ilv_RAID_INFO) do
        local count = raid.hard and get_safe_entrance_count(raid.hard)
        raid_data[key .. "_H"] = count or "?"
        count = get_safe_entrance_count(raid.auto)
        raid_data[key .. "_A"] = count or "?"
    end
    g.ilv_settings.chars[g.login_name].raid_count = raid_data
    local auto_clear_data = g.ilv_settings.chars[g.login_name].auto_clear_count
    local my_handle = session.GetMyHandle()
    for _, key in ipairs(g.ilv_RAID_KEYS) do
        local raid = g.ilv_RAID_INFO[key]
        auto_clear_data[key .. "_S"] = 0
        if raid.sweep_buff then
            local buff_info = info.GetBuff(my_handle, raid.sweep_buff)
            if buff_info then
                auto_clear_data[key .. "_S"] = buff_info.over
            end
        end
    end
    g.ilv_settings.chars[g.login_name].auto_clear_count = auto_clear_data
    Indun_list_viewer_save_settings()
end

function Indun_list_viewer_EXPIREDITEM_ALERT_ON_MSG(frame, msg, str, num)
    local expireditem_alert = ui.GetFrame("expireditem_alert")
    if expireditem_alert then
        expireditem_alert:SetLayerLevel(100)
    end
end

function Indun_list_viewer_raid_reset_reserve()
    local server_time_str = date_time.get_lua_now_datetime_str()
    if server_time_str then
        local y, m, d, H, M, S = server_time_str:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
        if y then
            local server_now_timestamp = os.time({
                year = tonumber(y),
                month = tonumber(m),
                day = tonumber(d),
                hour = tonumber(H),
                min = tonumber(M),
                sec = tonumber(S)
            })
            if server_now_timestamp > g.ilv_settings.options.reset_time then
                Indun_list_viewer_raid_reset()
            end
        end
    end
end

function Indun_list_viewer_raid_reset()
    local acc_info = session.barrack.GetMyAccount()
    local barrack_pc_count = acc_info:GetBarrackPCCount() -- ゲーム起動直後はtonumber(0)そのため初期化は2回目以降
    if barrack_pc_count > 0 then
        for i = 0, barrack_pc_count - 1 do
            local barrack_pc_info = acc_info:GetBarrackPCByIndex(i)
            if barrack_pc_info then
                local barrack_pc_name = barrack_pc_info:GetName()
                local char_data = g.ilv_settings.chars[barrack_pc_name]
                if char_data then
                    char_data.raid_count = {}
                    for _, key in ipairs(g.ilv_RAID_KEYS) do
                        char_data.raid_count[key .. "_H"] = "?"
                        char_data.raid_count[key .. "_A"] = "?"
                    end
                end
            end
        end
        g.ilv_settings.options.reset_time = Indun_list_viewer_get_reset_time()
        Indun_list_viewer_save_settings()
        if g.settings.indun_list_viewer.use ~= 0 then
            if g.lang == "Japanese" then
                ui.SysMsg("[ILV]レイドの回数を初期化しました")
            else
                ui.SysMsg("[ILV]Raid counts were initialized")
            end
        end
    end
end

function Indun_list_viewer_get_reset_time()
    local server_time_str = date_time.get_lua_now_datetime_str()
    if not server_time_str then
        return 0
    end
    local year, month, day, hour, min, sec = server_time_str:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
    if not year then
        return 0
    end
    local now_table = {
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(min),
        sec = tonumber(sec)
    }
    local now_timestamp = os.time(now_table)
    local current_day_of_week = tonumber(os.date("%w", now_timestamp)) + 1
    local days_to_next_monday
    if current_day_of_week == 2 and now_table.hour < 6 then
        days_to_next_monday = 0
    else
        days_to_next_monday = (9 - current_day_of_week) % 7
        if days_to_next_monday == 0 then
            days_to_next_monday = 7
        end
    end
    local next_monday_timestamp_base = now_timestamp + days_to_next_monday * 86400
    local next_monday_date = os.date("*t", next_monday_timestamp_base)
    local next_monday_6am_timestamp = os.time({
        year = next_monday_date.year,
        month = next_monday_date.month,
        day = next_monday_date.day,
        hour = 6,
        min = 0,
        sec = 0
    })
    return next_monday_6am_timestamp
end

function Indun_list_viewer_sort_characters()
    g.ilv_sorted_settings = {}
    for key, data in pairs(g.ilv_settings.chars) do
        if type(data) == "table" then
            table.insert(g.ilv_sorted_settings, data)
        end
    end
    local function sort_layer_order(a, b)
        if a.layer ~= b.layer then
            return a.layer < b.layer
        else
            return a.order < b.order
        end
    end
    table.sort(g.ilv_sorted_settings, sort_layer_order)
end

function Indun_list_viewer_STATUS_SELET_REPRESENTATION_CLASS(my_frame, my_msg)
    if not g.ilv_settings then
        return
    end
    local _, select_key = g.get_event_args(my_msg)
    local pc_job_info = session.GetMainSession():GetPCJobInfo()
    local job_count = pc_job_info:GetJobCount()
    local job_id_parts = {}
    for i = 0, job_count - 1 do
        local job_info = pc_job_info:GetJobInfoByIndex(i)
        table.insert(job_id_parts, job_info.jobID)
    end
    g.ilv_settings.chars[g.login_name].jobid = "/" .. table.concat(job_id_parts, "/")
    g.ilv_settings.chars[g.login_name].president_jobid = tostring(select_key)
    Indun_list_viewer_save_settings()
    Indun_list_viewer_title_frame_open()
end

function Indun_list_viewer_INDUNINFO_SET_BUTTONS(indun_type, ctrl)
    local indun_cls = GetClassByType("Indun", indun_type)
    local dungeon_type = TryGetProp(indun_cls, "DungeonType", "None")
    local btn_info_cls = GetClassByStrProp("IndunInfoButton", "DungeonType", dungeon_type)
    if dungeon_type == "Raid" then
        btn_info_cls = INDUNINFO_SET_BUTTONS_FIND_CLASS(indun_cls)
    end
    local red_button_scp = TryGetProp(btn_info_cls, "RedButtonScp")
    ctrl:SetUserValue("MOVE_INDUN_CLASSID", indun_cls.ClassID)
    ctrl:SetEventScript(ui.LBUTTONUP, red_button_scp)
end

function Indun_list_viewer_enter_hard(parent, ctrl, str, indun_type)
    if str == "false" then
        Indun_list_viewer_INDUNINFO_SET_BUTTONS(indun_type, ctrl)
        ReserveScript(string.format("Indun_list_viewer_enter_hard(nil, nil, 'true', %d)", indun_type), 0.5)
    else
        SHOW_INDUNENTER_DIALOG(indun_type)
        local indun_list_viewer = parent:GetTopParentFrame()
        ui.DestroyFrame(indun_list_viewer:GetName())
    end
end

function Indun_list_viewer_enter_solo_or_auto(parent, ctrl, move_type_str, indun_type)
    local move_type = tonumber(move_type_str)
    ReqRaidAutoUIOpen(indun_type)
    if move_type == 2 then
        local indunenter = ui.GetFrame("indunenter")
        local indun_cls = GetClassByType("Indun", indunenter:GetUserValue("INDUN_TYPE"))
        local min_rank = TryGetProp(indun_cls, "PCRank")
        if min_rank and min_rank > session.GetPcTotalJobGrade() then
            ui.SysMsg(ScpArgMsg("IndunEnterNeedPCRank", "NEED_RANK", min_rank))
            return
        end
    end
    ReserveScript(string.format("ReqMoveToIndun(%d, 0)", move_type), 0.3)
    local indun_list_viewer = parent:GetTopParentFrame()
    ui.DestroyFrame(indun_list_viewer:GetName())
end

function Indun_list_viewer_config(parent)
    local indun_list_viewer = parent:GetTopParentFrame()
    if not indun_list_viewer then
        indun_list_viewer = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "indun_list_viewer", 0, 0, 10, 10)
        AUTO_CAST(indun_list_viewer)
    end
    indun_list_viewer:RemoveAllChild()
    local title_gb = indun_list_viewer:CreateOrGetControl("groupbox", "title_gb", 0, 0, 10, 10)
    AUTO_CAST(title_gb)
    local config_gb = indun_list_viewer:CreateOrGetControl("groupbox", "config_gb", 10, 35, 10, 10)
    AUTO_CAST(config_gb)
    config_gb:SetSkinName("bg")
    local text = config_gb:CreateOrGetControl("richtext", "text", 10, 10)
    AUTO_CAST(text)
    text:SetText(g.lang == "Japanese" and "チェックすると表示" or "{ol}Check to show")
    local x = text:GetX() + text:GetWidth() + 5
    -- x はハード枠内でのみ増加するので、初期値 x がそのまま「ハード列の先頭位置」。
    -- ハードモードのレイドが 1 つも無くても hard_text が x=-40 に飛ばない。
    local text_x = x
    for _, raid_key in ipairs(g.ilv_RAID_KEYS) do
        local raid_info = g.ilv_RAID_INFO[raid_key]
        if raid_info.hard then
            local pic = title_gb:CreateOrGetControl("picture", "title_pic_" .. raid_key .. "_H", x + 5, 5, 30, 30)
            AUTO_CAST(pic)
            pic:SetImage(raid_info.icon)
            pic:SetEnableStretch(1)
            pic:EnableHitTest(1)
            local check = config_gb:CreateOrGetControl("checkbox", "check_" .. raid_key .. "_H", x, 5, 30, 30)
            AUTO_CAST(check)
            check:SetCheck(g.ilv_settings.display[raid_info.name .. "_H"])
            check:SetEventScript(ui.LBUTTONDOWN, "Indun_list_viewer_display_check")
            check:SetEventScriptArgString(ui.LBUTTONDOWN, raid_info.name .. "_H")
            x = x + 30
        end
    end
    local hard_text = title_gb:CreateOrGetControl("richtext", "hard_text", text_x - 40, 10)
    AUTO_CAST(hard_text)
    hard_text:SetText("{ol}Hard")
    x = x + 100
    text_x = 0
    for _, raid_key in ipairs(g.ilv_RAID_KEYS) do
        local raid_info = g.ilv_RAID_INFO[raid_key]
        if text_x == 0 then
            text_x = x
        end
        local pic = title_gb:CreateOrGetControl("picture", "title_pic_" .. raid_key .. "_S", x + 5, 5, 30, 30)
        AUTO_CAST(pic)
        pic:SetImage(raid_info.icon)
        pic:SetEnableStretch(1)
        pic:EnableHitTest(1)
        local check = config_gb:CreateOrGetControl("checkbox", "check_" .. raid_key .. "_S", x, 5, 30, 30)
        AUTO_CAST(check)
        check:SetCheck(g.ilv_settings.display[raid_info.name .. "_S"])
        check:SetEventScript(ui.LBUTTONDOWN, "Indun_list_viewer_display_check")
        check:SetEventScriptArgString(ui.LBUTTONDOWN, raid_info.name .. "_S")
        x = x + 30
    end
    local auto_text = title_gb:CreateOrGetControl("richtext", "auto_text", text_x - 80, 10)
    AUTO_CAST(auto_text)
    auto_text:SetText("{ol}Solo/Auto")
    x = x + 30
    local memo_text = title_gb:CreateOrGetControl("richtext", "memo_text", x, 10)
    AUTO_CAST(memo_text)
    memo_text:SetText("{ol}Memo")
    local memo_check = config_gb:CreateOrGetControl("checkbox", "check_memo", x, 5, 30, 30)
    AUTO_CAST(memo_check)
    memo_check:SetCheck(g.ilv_settings.display["Memo"])
    memo_check:SetEventScript(ui.LBUTTONDOWN, "Indun_list_viewer_display_check")
    memo_check:SetEventScriptArgString(ui.LBUTTONDOWN, "Memo")
    local close_button = title_gb:CreateOrGetControl("button", "close_button", 0, 0, 20, 20)
    AUTO_CAST(close_button)
    close_button:SetImage("testclose_button")
    close_button:SetGravity(ui.RIGHT, ui.TOP)
    close_button:SetEventScript(ui.LBUTTONUP, "Indun_list_viewer_close")
    close_button:SetEventScriptArgNumber(ui.LBUTTONUP, 1)
    -- 右上の閉じるボタン(title_gb の右端 20px)が、右端の「Memo」見出しに被らない幅を確保する。
    -- 見出しの幅は言語とフォントで変わるので実測から出す(本体側の frame_width と同じ考え方)。
    -- 下限の +50 は変更前と同じ幅。
    title_gb:Resize(math.max(x + 50, x + memo_text:GetWidth() + 30), 55)
    indun_list_viewer:Resize(title_gb:GetWidth() + 20, 85)
    config_gb:Resize(indun_list_viewer:GetWidth() - 20, indun_list_viewer:GetHeight() - 45)
end

function Indun_list_viewer_display_check(parent, ctrl, key, num)
    g.ilv_settings.display[key] = ctrl:IsChecked() == 1 and 1 or 0
    Indun_list_viewer_save_settings()
end

function Indun_list_viewer_title_frame_open()
    Indun_list_viewer_save_current_char_counts()
    if g.settings.indun_list_viewer.use == 0 then
        return
    end
    local indun_list_viewer = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "indun_list_viewer", 0, 0, 10, 10)
    AUTO_CAST(indun_list_viewer)
    indun_list_viewer:RemoveAllChild()
    indun_list_viewer:SetLayerLevel(99)
    indun_list_viewer:SetSkinName("test_frame_low")
    local title_gb = indun_list_viewer:CreateOrGetControl("groupbox", "title_gb", 0, 0, 10, 10)
    AUTO_CAST(title_gb)
    local texts = (g.lang == "Japanese") and {
        hard_raid = "ハード",
        auto_raid = "左クリック:ソロ入場{nl}右クリック:自動入場{nl} {nl}入場回数/掃討回数",
        mode_text = "チェックを入れるとスクロールモードに切替",
        display_text = "チェックしたキャラはレイド回数非表示",
        memo = "メモ",
        display = "表示",
        hidden = "チェックを入れると非表示キャラを表示しません"
    } or {
        hard_raid = "Hard Count",
        auto_raid = "Left-click: Solo Entry{nl}Right-click: Automatic Entry{nl} {nl}Entry Count/Auto clear count",
        mode_text = "Switch to scroll mode when checked",
        display_text = "Checked characters hide raid count",
        memo = "Memo",
        display = "Disp",
        hidden = "If checked, do not show hidden characters"
    }
    local x = 185
    for _, raid_key in ipairs(g.ilv_RAID_KEYS) do
        local raid_info = g.ilv_RAID_INFO[raid_key]
        if raid_info and raid_info.name then -- ここで安全確認
            if raid_info.hard and g.ilv_settings.display[raid_info.name .. "_H"] == 1 then
                local pic = title_gb:CreateOrGetControl("picture", "title_pic_" .. raid_key .. "_H", x, 5, 30, 30)
                AUTO_CAST(pic)
                pic:SetImage(raid_info.icon)
                pic:SetEnableStretch(1)
                pic:EnableHitTest(1)
                pic:SetEventScript(ui.LBUTTONDOWN, "Indun_list_viewer_enter_hard")
                pic:SetEventScriptArgNumber(ui.LBUTTONDOWN, raid_info.hard)
                pic:SetEventScriptArgString(ui.LBUTTONDOWN, "false")
                pic:SetTextTooltip("{ol}" .. texts.hard_raid)
                x = x + 30
            end
        end
    end
    x = x + 30
    for _, raid_key in ipairs(g.ilv_RAID_KEYS) do
        local raid_info = g.ilv_RAID_INFO[raid_key]
        if raid_info and raid_info.name then -- ここで安全確認
            if g.ilv_settings.display[raid_info.name .. "_S"] == 1 then
                local pic = title_gb:CreateOrGetControl("picture", "title_pic_" .. raid_key .. "_S", x, 5, 30, 30)
                AUTO_CAST(pic)
                pic:SetImage(raid_info.icon)
                pic:SetEnableStretch(1)
                pic:EnableHitTest(1)
                pic:SetEventScript(ui.LBUTTONUP, "Indun_list_viewer_enter_solo_or_auto")
                pic:SetEventScriptArgString(ui.LBUTTONUP, "1")
                pic:SetEventScriptArgNumber(ui.LBUTTONUP, raid_info.solo)
                pic:SetEventScript(ui.RBUTTONUP, "Indun_list_viewer_enter_solo_or_auto")
                pic:SetEventScriptArgString(ui.RBUTTONUP, "2")
                pic:SetEventScriptArgNumber(ui.RBUTTONUP, raid_info.auto)
                pic:SetTextTooltip("{ol}" .. texts.auto_raid)
                x = x + 65
            end
        end
    end
    local close_button = title_gb:CreateOrGetControl("button", "close_button", 0, 0, 20, 20)
    AUTO_CAST(close_button)
    close_button:SetImage("testclose_button")
    close_button:SetGravity(ui.RIGHT, ui.TOP)
    close_button:SetEventScript(ui.LBUTTONUP, "Indun_list_viewer_close")
    local cc_button = title_gb:CreateOrGetControl("button", "cc_button", 40, 5, 30, 30)
    AUTO_CAST(cc_button)
    cc_button:SetSkinName("None")
    cc_button:SetText("{img barrack_button_normal 30 30}")
    cc_button:SetEventScript(ui.LBUTTONUP, "_nexus_addons_p_APPS_TRY_MOVE_BARRACK")
    local config_btn = title_gb:CreateOrGetControl("button", "config_btn", 75, 5, 30, 30)
    AUTO_CAST(config_btn)
    config_btn:SetSkinName("None")
    config_btn:SetText("{img config_button_normal 30 30}")
    config_btn:SetEventScript(ui.LBUTTONUP, "Indun_list_viewer_config")
    local mode_check = title_gb:CreateOrGetControl("checkbox", "mode_check", 115, 5, 30, 30)
    AUTO_CAST(mode_check)
    mode_check:SetCheck(g.ilv_settings.options.display_mode == "slide" and 1 or 0)
    mode_check:SetEventScript(ui.LBUTTONUP, "Indun_list_viewer_modechange")
    mode_check:SetTextTooltip("{ol}" .. texts.mode_text)
    local hidden_check = title_gb:CreateOrGetControl("checkbox", "hidden_check", 150, 5, 30, 30)
    AUTO_CAST(hidden_check)
    hidden_check:SetCheck(g.ilv_settings.options.hidden)
    hidden_check:SetEventScript(ui.LBUTTONUP, "Indun_list_viewer_modechange")
    hidden_check:SetTextTooltip("{ol}" .. texts.hidden)
    if g.ilv_settings.display["Memo"] == 1 then
        local memo_text = title_gb:CreateOrGetControl("richtext", "memo_text", x, 10)
        AUTO_CAST(memo_text)
        memo_text:SetText("{ol}" .. texts.memo)
        x = x + 160
    end
    local display_text = title_gb:CreateOrGetControl("richtext", "display_text", x, 10)
    AUTO_CAST(display_text)
    display_text:SetText("{ol}" .. texts.display)
    display_text:SetTextTooltip("{ol}" .. texts.display_text)
    indun_list_viewer:ShowWindow(1)
    g.esc_register(addon_name_lower .. "indun_list_viewer", "Indun_list_viewer_ESCAPE_PRESSED")
    Indun_list_viewer_frame_open(indun_list_viewer)
end

function Indun_list_viewer_ESCAPE_PRESSED()
    local indun_list_viewer = ui.GetFrame(addon_name_lower .. "indun_list_viewer")
    Indun_list_viewer_close(indun_list_viewer)
end

function Indun_list_viewer_close(parent, ctrl, str, num)
    local indun_list_viewer = parent:GetTopParentFrame()
    ui.DestroyFrame(indun_list_viewer:GetName())
    if num == 1 then
        ReserveScript("Indun_list_viewer_title_frame_open()", 0.1)
    end
end

function Indun_list_viewer_modechange(parent, ctrl)
    local ctrl_name = ctrl:GetName()
    local is_checked = ctrl:IsChecked()
    if ctrl_name == "hidden_check" then
        g.ilv_settings.options.hidden = is_checked
    else -- mode_check
        g.ilv_settings.options.display_mode = is_checked == 1 and "slide" or "full"
    end
    Indun_list_viewer_save_settings()
    Indun_list_viewer_title_frame_open()
end

function Indun_list_viewer_frame_open(indun_list_viewer)
    local title_gb = GET_CHILD(indun_list_viewer, "title_gb")
    AUTO_CAST(title_gb)
    local gb = indun_list_viewer:CreateOrGetControl("groupbox", "gb", 10, 35, 10, 10)
    AUTO_CAST(gb)
    gb:SetSkinName("bg")
    local sorted_char_list = {}
    for _, data in ipairs(g.ilv_sorted_settings) do
        if type(data) == "table" then
            if g.ilv_settings.options.hidden == 0 or not data.hide then
                table.insert(sorted_char_list, data)
            end
        end
    end
    local y = 10
    local max_x = 0
    if not g.ilv_RAID_KEYS or not g.ilv_RAID_INFO then
        return
    end
    for _, data in ipairs(sorted_char_list) do
        local x = 35
        local pc_name = data.pc_name
        local name = gb:CreateOrGetControl("richtext", pc_name, x, y)
        AUTO_CAST(name)
        name:SetText(("{ol}{s14}" .. (g.login_name == pc_name and "{#FF4500}" or "") .. pc_name))
        Indun_list_viewer_job_slot(indun_list_viewer, data, y)
        x = x + 60
        if not data.hide then
            local current_x = 180
            local raid_count_data = data.raid_count or {}
            local auto_clear_data = data.auto_clear_count or {}
            for _, raid_key in ipairs(g.ilv_RAID_KEYS) do
                local raid_info = g.ilv_RAID_INFO[raid_key]
                if raid_info and raid_info.name and raid_info.hard then
                    if g.ilv_settings.display[raid_info.name .. "_H"] == 1 then
                        local count = raid_count_data[raid_key .. "_H"] or "?"
                        local text_ctrl = gb:CreateOrGetControl("richtext", raid_key .. "_H_" .. pc_name, current_x, y)
                        AUTO_CAST(text_ctrl)
                        text_ctrl:SetText("{ol}{s14}( " .. count .. " )")
                        local limit = (raid_key == "P" or raid_key == "F") and 2 or 1
                        local num_count = tonumber(count) or 0
                        text_ctrl:SetColorTone(num_count >= limit and "FF990000" or "FFFFFFFF")
                        current_x = current_x + 30
                    end
                end
            end
            current_x = current_x + 30
            for _, raid_key in ipairs(g.ilv_RAID_KEYS) do
                local raid_info = g.ilv_RAID_INFO[raid_key]
                if raid_info and raid_info.name then
                    if g.ilv_settings.display[raid_info.name .. "_S"] == 1 then
                        local limit = (raid_key == "P" or raid_key == "F") and 4 or 2
                        local count_a = raid_count_data[raid_key .. "_A"] or "?"
                        local text_a = gb:CreateOrGetControl("richtext", raid_key .. "_A_" .. pc_name, current_x, y)
                        AUTO_CAST(text_a)
                        text_a:SetText("{ol}{s14}( " .. count_a .. " )")
                        local num_a = tonumber(count_a)
                        if num_a and num_a > 0 then
                            text_a:SetColorTone(num_a == limit and "FF990000" or "FFFFFFFF")
                        end
                        if raid_key ~= "D" then
                            current_x = current_x + 25
                            local count_s = auto_clear_data[raid_key .. "_S"] or 0
                            local text_s = gb:CreateOrGetControl("richtext", raid_key .. "_S_" .. pc_name, current_x, y)
                            AUTO_CAST(text_s)
                            text_s:SetText("{ol}{s14}/( " .. count_s .. " )")
                            local num_s = tonumber(count_s)
                            if num_s and num_s > 0 then
                                -- text_s:SetColorTone(num_s == limit and "FFFFA500" or "FFFFFFFF")
                                text_s:SetColorTone("FFFFA500")
                            end
                        end
                        current_x = current_x + 40
                    end
                end
            end
            if g.ilv_settings.display["Memo"] == 1 then
                local memo = gb:CreateOrGetControl("edit", "memo" .. pc_name, current_x, y - 2, 180, 20)
                AUTO_CAST(memo)
                memo:SetFontName("white_14_ol")
                memo:SetTextAlign("left", "center")
                memo:SetSkinName("inventory_serch")
                memo:SetEventScript(ui.ENTERKEY, "Indun_list_viewer_memo_save")
                memo:SetEventScriptArgString(ui.ENTERKEY, pc_name)
                memo:SetText(data.memo or "")
                current_x = current_x + 180
            end
            x = current_x
        end
        if x > max_x then
            max_x = x
        end
        y = y + 25
    end
    local display_x = max_x + 20
    y = 10
    for _, data in ipairs(sorted_char_list) do
        local pc_name = data.pc_name
        local line = gb:CreateOrGetControl("labelline", "line" .. pc_name, 25, y + 20, max_x - 20, 1)
        AUTO_CAST(line)
        line:SetSkinName("labelline_def_3")
        local display_check = gb:CreateOrGetControl("checkbox", "display" .. pc_name, display_x, y - 5, 25, 25)
        AUTO_CAST(display_check)
        display_check:SetEventScript(ui.LBUTTONUP, "Indun_list_viewer_display_save")
        display_check:SetEventScriptArgString(ui.LBUTTONUP, pc_name)
        display_check:SetCheck(data.hide and 1 or 0)
        y = y + 25
    end
    -- 閉じるボタンは title_gb(= フレーム幅 - 20)の右上に付き、右端 20px を占める。
    -- その手前に来るのが display_x に置く「表示」見出しなので、
    --   フレーム幅 - 20(title_gb) - 20(ボタン) - 10(余白) >= display_x + 見出しの幅
    -- を満たす幅を確保する。見出しの幅は言語とフォントで変わる(日本語「表示」/英語「Disp」)ため、
    -- 固定値ではなく実測から出す(アドオン一覧のタイトル幅と同じ考え方。20_lifecycle.lua 参照)。
    -- 下限の +60 は見出しが無い場合用で、変更前と同じ幅。
    local frame_width = display_x + 60
    local display_text = GET_CHILD_RECURSIVELY(indun_list_viewer, "display_text")
    if display_text then
        AUTO_CAST(display_text)
        frame_width = math.max(frame_width, display_x + display_text:GetWidth() + 50)
    end
    local frame_height = y + 50
    if g.ilv_settings.options.display_mode == "slide" and frame_height > 545 then
        frame_height = 545
        gb:EnableScrollBar(1)
    end
    indun_list_viewer:Resize(frame_width, frame_height)
    gb:Resize(indun_list_viewer:GetWidth() - 20, indun_list_viewer:GetHeight() - 45)
    title_gb:Resize(indun_list_viewer:GetWidth() - 20, 55)
    if display_text then
        display_text:SetPos(display_x, 10)
    end
    local map_frame = ui.GetFrame("map")
    indun_list_viewer:SetPos((map_frame:GetWidth() - indun_list_viewer:GetWidth()) / 2, 35)
end

function Indun_list_viewer_job_slot(indun_list_viewer, data, y)
    local pc_name = data.pc_name
    local job_id_str = data.jobid or ""
    local president_id_str = data.president_jobid or ""
    local _, _, last_job_id = GetJobListFromAdventureBookCharData(pc_name)
    local prepresentative_job_id = (president_id_str ~= "") and president_id_str or last_job_id
    local job_class = GetClassByType("Job", tonumber(prepresentative_job_id) or 0)
    local job_icon_name = "icon_item_nothing" -- デフォルト（?マークや空）
    if job_class then
        job_icon_name = TryGetProp(job_class, "Icon", "icon_item_nothing")
    end
    local gb = GET_CHILD_RECURSIVELY(indun_list_viewer, "gb")
    local job_slot = gb:CreateOrGetControl("slot", "jobslot" .. pc_name, 5, y - 4, 25, 25)
    AUTO_CAST(job_slot)
    job_slot:SetSkinName("None")
    job_slot:EnableHitTest(1)
    job_slot:EnablePop(0)
    local job_icon = CreateIcon(job_slot)
    job_icon:SetImage(job_icon_name)
    local tooltip_parts = {}
    if job_id_str ~= "" then
        local highlight_color = "{#FF0000}"
        for id_str in job_id_str:gmatch("/([^/]+)") do
            local job_id_num = tonumber(id_str)
            if job_id_num then
                local cls = GetClassByType("Job", job_id_num)
                if cls and cls.Name then
                    local name = (string.gsub(dic.getTranslatedStr(cls.Name), "{s18}", ""))
                    if id_str == president_id_str then
                        table.insert(tooltip_parts, highlight_color .. name .. "{/}")
                    else
                        table.insert(tooltip_parts, name)
                    end
                end
            end
        end
    else
        if job_class and job_class.Name then
            local name = TryGetProp(job_class, "Name")
            table.insert(tooltip_parts, (string.gsub(dic.getTranslatedStr(name), "{s18}", "")))
        end
    end
    local tooltip_text = "{ol}" .. table.concat(tooltip_parts, "{nl}")
    if g.login_name == pc_name then
        local r_click_text = (g.lang == "Japanese") and "右クリック: 表示アイコン選択" or
                                 "Right-click: Select Display Icon"
        tooltip_text = tooltip_text .. "{nl} {nl}" .. r_click_text
        job_slot:SetEventScript(ui.RBUTTONDOWN, "STATUS_OPEN_CLASS_DROPLIST")
        local name_text = GET_CHILD_RECURSIVELY(gb, pc_name)
        name_text:SetEventScript(ui.RBUTTONDOWN, "STATUS_OPEN_CLASS_DROPLIST")
    end
    if type(_G["INSTANTCC_ON_INIT"]) == "function" and g.settings.instant_cc.use == 1 then -- InstantCCアドオン連携
        local cc_text = (g.lang == "Japanese") and "左クリック: キャラクターチェンジ" or
                            "Left-click: Character Change"
        tooltip_text = tooltip_text .. "{nl} {nl}{#FF4500}" .. cc_text
        job_slot:SetEventScript(ui.LBUTTONDOWN, "Indun_list_viewer_INSTANTCC_DO_CC")
        job_slot:SetEventScriptArgString(ui.LBUTTONDOWN, data.cid)
        job_slot:SetEventScriptArgNumber(ui.LBUTTONDOWN, data.layer)
        local name_text = GET_CHILD_RECURSIVELY(gb, pc_name)
        name_text:SetEventScript(ui.LBUTTONDOWN, "Indun_list_viewer_INSTANTCC_DO_CC")
        name_text:SetEventScriptArgString(ui.LBUTTONDOWN, data.cid)
        name_text:SetEventScriptArgNumber(ui.LBUTTONDOWN, data.layer)
        name_text:SetTextTooltip(tooltip_text)
    end
    job_icon:SetTextTooltip(tooltip_text)
end

function Indun_list_viewer_INSTANTCC_DO_CC(parent, ctrl, cid, layer)
    if ui.CheckHoldedUI() then
        return
    end
    if g.get_map_type() == "City" then
        Indun_list_viewer_save_current_char_counts()
    end
    local expireditem_alert = ui.GetFrame("expireditem_alert")
    local near_future_sec = tonumber(expireditem_alert:GetUserConfig("NearFutureSec"))
    local need_alert = false
    if near_future_sec then
        local list = GET_SCHEDULED_TO_EXPIRED_ITEM_LIST(near_future_sec)
        if list and #list > 0 then
            need_alert = true
        end
        if IS_NEED_TO_ALERT_TOKEN_EXPIRATION(near_future_sec) then
            need_alert = true
        end
    end
    local sweep_buffs = g.ilv_sweep_buffs
    local sweep_tbl = {}
    local my_handle = session.GetMyHandle()
    local limit_time_ms = 12 * 60 * 60 * 1000
    for _, buff_id in ipairs(sweep_buffs) do
        local buff_info = info.GetBuff(my_handle, buff_id)
        if buff_info and buff_info.time <= limit_time_ms then
            table.insert(sweep_tbl, {
                buff_over = buff_info.over,
                buff_time = buff_info.time,
                buff_id = buff_id
            })
            need_alert = true
        end
    end
    if need_alert then
        Indun_list_viewer_EXPIREDITEM_ALERT_OPEN(nil, "Barrack", sweep_tbl, cid, layer)
        return
    end
    if _G["INSTANTCC_DO_CC"] then
        _G["INSTANTCC_DO_CC"](cid, layer)
    end
end

function Indun_list_viewer_EXPIREDITEM_ALERT_OK_BTN(frame)
    local timerType = frame:GetUserValue("TimerType")
    local cid = frame:GetUserValue("CC_CID")
    local layer = frame:GetUserIValue("CC_LAYER")
    if cid and cid ~= "None" then
        if not g.instant_cc then
            g.instant_cc = {}
        end -- 安全策
        g.instant_cc.do_cc = {
            cid = cid,
            layer = layer
        }
        RUN_GAMEEXIT_TIMER("Barrack")
        frame:ShowWindow(0)
        return
    end
    RUN_GAMEEXIT_TIMER(timerType)
    frame:ShowWindow(0)
end

function Indun_list_viewer_memo_save(frame, ctrl, pc_name, num)
    if g.ilv_settings.chars[pc_name] then
        g.ilv_settings.chars[pc_name].memo = ctrl:GetText()
        Indun_list_viewer_save_settings()
    end
    ui.SysMsg(g.lang == "Japanese" and "メモを登録しました。" or "MEMO registered.")
end

function Indun_list_viewer_display_save(frame, ctrl, pc_name, num)
    local is_checked = ctrl:IsChecked()
    if g.ilv_settings.chars[pc_name] then
        g.ilv_settings.chars[pc_name].hide = (is_checked == 1)
        Indun_list_viewer_save_settings()
    end
    Indun_list_viewer_title_frame_open()
end
-- indun_list_viewer ここまで

