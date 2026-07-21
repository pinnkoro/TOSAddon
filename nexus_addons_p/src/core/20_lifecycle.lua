function _nexus_addons_p_save_settings()
    g.save_json(g.settings_path, g.settings)
end

function _nexus_addons_p_load_settings()
    local settings = g.load_json(g.settings_path)
    if not settings then
        settings = {}
    end
    local changed = false
    local valid_keys = {}
    for _, entry in ipairs(g._nexus_addons_p) do
        valid_keys[entry.key] = true
    end
    -- アドオン登録キー以外のトップレベル設定はここに列挙する。書き忘れると
    -- すぐ下のプルーニングで毎回消され、設定を保存しても復元できない。
    valid_keys.verbose_log = true
    for key, _ in pairs(settings) do
        if not valid_keys[key] then
            settings[key] = nil
            changed = true
        end
    end
    local force_update_keys = {
        name = true,
        config_func = true,
        frame_use = true,
        old_init_func = true
    }
    for _, entry in ipairs(g._nexus_addons_p) do
        local key = entry.key
        local default_data = entry.data
        if not settings[key] then
            settings[key] = {}
            for k, v in pairs(default_data) do
                settings[key][k] = v
            end
            changed = true
        elseif type(settings[key]) == "table" then
            for k, v in pairs(default_data) do
                if settings[key][k] == nil then
                    settings[key][k] = v
                    changed = true
                elseif force_update_keys[k] and settings[key][k] ~= v then
                    settings[key][k] = v
                    changed = true
                end
            end
            for k, v in pairs(settings[key]) do
                if default_data[k] == nil then
                    settings[key][k] = nil
                    changed = true
                end
            end
        end
    end
    if settings.verbose_log == nil then
        settings.verbose_log = 0 -- 既定は OFF（普段のチャットを埋めない）
        changed = true
    end
    g.settings = settings
    if changed then
        _nexus_addons_p_save_settings()
    end
end

function _NEXUS_ADDONS_P_ON_INIT(addon, frame)
    g.addon = addon
    g.frame = frame
    -- 返るのは「国UI名」で、日本語は "Japanese"、韓国語は "Korean" ではなく "kr"。
    -- 言語名と2文字コードが混在するのはゲーム側の仕様で、こちらの typo ではない。
    -- 根拠: クライアントの systemoption.lua / barrack_charlist.lua が言語ドロップダウンを
    -- 組む際に lanUIString ~= "kr" と lanUIString ~= "Japanese" を並べて比較している。
    -- (norisan さんの native_lang アドオンも {Japanese="ja", kr="ko"} で対応付けている)
    -- "kr" を "Korean" に直すと韓国語表示が全滅するので触らないこと。
    g.lang = option.GetCurrentCountry()
    g.cid = session.GetMySession():GetCID()
    g.active_id = session.loginInfo.GetAID()
    g.settings_path = string.format("../addons/%s/%s/settings.json", addon_name_lower, g.active_id)
    if not g.folders_created then
        g.mkdir_new_folder()
        g.folders_created = true
    end
    -- B: 本家の設定引き継ぎ。フォルダ作成後・設定ロード(GAME_START)前に済ませる必要がある。
    -- セッション中に何度 ON_INIT が呼ばれても実行は 1 回でよいので結果をキャッシュする。
    if g.migrate_result == nil then
        g.migrate_result = g.migrate_from_origin() or false
    end
    -- A: 本家と同時インストールされている場合は共存できないので何も初期化しない。
    -- 告知だけは出したいので GAME_START(全アドオンのロード完了後)にだけ入る。
    if g.detect_origin_addon() then
        g.origin_conflict = true
        addon:RegisterMsg('GAME_START', '_nexus_addons_p_GAME_START')
        return
    end
    g.login_name = session.GetMySession():GetPCApc():GetName()
    g.map_name = session.GetMapName()
    g.map_id = session.GetMapID()
    g.current_channel = session.loginInfo.GetChannel() -- 0が1ch
    g.pc = GetMyPCObject()
    g.REGISTER = {}
    addon:RegisterMsg('GAME_START', '_nexus_addons_p_GAME_START')
    addon:RegisterMsg('GAME_START_3SEC', '_nexus_addons_p_GAME_START_3SEC')
    addon:RegisterMsg('ESCAPE_PRESSED', '_nexus_addons_p_ESCAPE_PRESSED')
    g.setup_hook(_nexus_addons_p_CHAT_SYSTEM, "CHAT_SYSTEM")
end

-- A: 本家が同居している間は機能を止め、削除を促すメッセージだけ出す。
-- CHAT_SYSTEM は GAME_START 直後だと流れてしまうことがあるため、
-- 既存の pending_messages と同じく UpdateScript 経由で遅延表示する。
function _nexus_addons_p_origin_conflict_notice(frame)
    if g.conflict_notified then
        return
    end
    g.conflict_notified = true
    g.pending_messages = {}
    local notice, migrated
    if g.lang == "Japanese" then
        notice =
            "{ol}{#FF6347}[Nexus Addons P] 本家 Nexus Addons が同時にインストールされています{nl}競合するため Nexus Addons P の機能はすべて停止しました{nl}dataフォルダから本家の _nexus_addons-⛄-*.ipf を削除して、ゲームを再起動してください"
        migrated =
            "{ol}{#00BFFF}[Nexus Addons P] 本家の設定を引き継ぎました。本家を削除して再起動すれば、そのままの設定で使えます"
    else
        notice =
            "{ol}{#FF6347}[Nexus Addons P] The original Nexus Addons is installed at the same time{nl}All Nexus Addons P features are disabled to avoid conflicts{nl}Please remove _nexus_addons-⛄-*.ipf from your data folder and restart the game"
        migrated =
            "{ol}{#00BFFF}[Nexus Addons P] Your settings were copied from the original. They will be used once you remove it and restart"
    end
    table.insert(g.pending_messages, notice)
    if g.migrate_result == "copied" or g.migrate_result == "partial" then
        table.insert(g.pending_messages, migrated)
    end
    frame:RunUpdateScript("_nexus_addons_p_chat_system", 0.5)
end

function _nexus_addons_p_CHAT_SYSTEM(msg, color)
    if msg == "None" then
        return
    end
    g.FUNCS["CHAT_SYSTEM"](msg, color)
end

function _nexus_addons_p_init_addons(is_toggle, toggled_addon_name, _nexus_addons_p)
    g.error_count = 0
    local function safe_call(func, name)
        if type(func) == "function" then
            local func_start = imcTime.GetAppTimeMS()
            local success, err = pcall(func)
            local func_end = imcTime.GetAppTimeMS()
            local duration = func_end - func_start
            if not success then
                g.error_count = g.error_count + 1
                local err_msg = string.format("Error during on_init of '%s': %s", name, tostring(err))
                ts(err_msg)
                g.log_to_file(err_msg)
                g.vlog("{#FF6347}init: %s FAILED{/} %s", name, tostring(err))
            else
                g.vlog("init: %s (%dms)", name, duration)
            end
        end
    end
    if not g.loaded then
        -- GAME_START で積んだ引き継ぎ通知を消さないよう、既存があればそのまま使う
        g.pending_messages = g.pending_messages or {}
        for _, entry in ipairs(g._nexus_addons_p) do
            local key = entry.key
            local old_init_func_name = entry.data.old_init_func
            if old_init_func_name and old_init_func_name ~= "" and _G[old_init_func_name] then
                local message
                old_init_func_name = string.lower(string.gsub(old_init_func_name, "_ON_INIT", ""))
                old_init_func_name = string.gsub(old_init_func_name, "_", " ")
                if g.lang == "Japanese" then
                    message = string.format(
                        "{ol}{#FF6347}[Nexus Addons P] 競合する古いアドオン '%s' が検出されました{nl}'%s' を無効化しました{nl}dataフォルダから、古いアドオンのipfファイルを削除してください",
                        old_init_func_name, key)
                else
                    message = string.format(
                        "{ol}{#FF6347}[Nexus Addons P] Conflicting old addon '%s' detected{nl}Disabled '%s'{nl}Please remove the old addon's ipf file from your data folders",
                        old_init_func_name, key)
                end
                table.insert(g.pending_messages, message)
                if g.settings[key] then
                    if g.settings[key].use == 1 then
                        g.settings[key].use = 0
                        _nexus_addons_p_save_settings()
                    end
                else
                    ts(string.format("[Nexus Addons P] Error: Settings for '%s' not found.", key))
                end
            end
        end
    end
    if not g.loaded then
        _nexus_addons_p:SetUserValue("FUNC_INDEX", 1)
        _nexus_addons_p:RunUpdateScript("_nexus_addons_p_async_safe_call", 0.1)
        return
    else
        for _, entry in ipairs(g._nexus_addons_p) do
            local key = entry.key
            local on_init_func = _G[key .. "_on_init"]
            if is_toggle then
                if key == toggled_addon_name then
                    safe_call(on_init_func, key)
                end
            else
                safe_call(on_init_func, key)
            end
        end
    end
    if not is_toggle then
        if g.error_count == 0 then
            ts("All add-ons initialized successfully.")
        else
            ts(string.format("%d add-on(s) failed to initialize...", g.error_count))
        end
    end
end

function _nexus_addons_p_async_safe_call(_nexus_addons_p)
    local start_time = imcTime.GetAppTimeMS()
    local time_limit = 6
    local process_count = 0
    local max_process_per_frame = 2
    while true do
        local func_index = _nexus_addons_p:GetUserIValue("FUNC_INDEX")
        local entry = g._nexus_addons_p[func_index]
        if not entry then
            if #g.pending_messages > 0 and not g.loaded then
                _nexus_addons_p:RunUpdateScript("_nexus_addons_p_chat_system", 0.5)
            end
            g.loaded = true
            if g.error_count == 0 then
                ts("All add-ons initialized successfully.")
            else
                ts(string.format("%d add-on(s) failed to initialize...", g.error_count))
            end
            return 0
        end
        local func_name = entry.key
        local on_init_func = _G[func_name .. "_on_init"]
        if type(on_init_func) == "function" then
            local func_start = imcTime.GetAppTimeMS()
            local success, err = pcall(on_init_func)
            local func_end = imcTime.GetAppTimeMS()
            local duration = func_end - func_start
            ts(string.format("init ADDON: %s (%d ms)", func_name, duration))
            if not success then
                g.error_count = g.error_count + 1
                local err_msg = string.format("Error during on_init of '%s': %s", func_name, tostring(err))
                ts(err_msg)
                g.log_to_file(err_msg)
                g.vlog("{#FF6347}init: %s FAILED{/} %s", func_name, tostring(err))
            else
                g.vlog("init: %s (%dms)", func_name, duration)
            end
        end
        _nexus_addons_p:SetUserValue("FUNC_INDEX", func_index + 1)
        process_count = process_count + 1
        if (imcTime.GetAppTimeMS() - start_time) >= time_limit or process_count >= max_process_per_frame then
            return 1
        end
    end
end

function _nexus_addons_p_chat_system(_nexus_addons_p)
    if #g.pending_messages > 0 then
        local msg = table.remove(g.pending_messages, 1)
        CHAT_SYSTEM(msg)
        return 1
    end
    return 0
end

function _nexus_addons_p_frame_init()
    local list_frame_name = addon_name_lower .. "list_frame"
    local list_frame = ui.CreateNewFrame("notice_on_pc", list_frame_name, 0, 0, 10, 10)
    AUTO_CAST(list_frame)
    list_frame:RemoveAllChild()
    list_frame:SetSkinName("test_frame_low")
    list_frame:EnableHittestFrame(1)
    list_frame:SetTitleBarSkin("None")
    list_frame:SetLayerLevel(92)
    local title = list_frame:CreateOrGetControl('richtext', 'title', 20, 10, 10, 30)
    AUTO_CAST(title)
    title:SetText("{#000000}{s25}Nexus Addons P" .. " {s15}ver " .. ver)
    local close_button = list_frame:CreateOrGetControl('button', 'close_button', 0, 0, 20, 20)
    AUTO_CAST(close_button)
    close_button:SetImage("testclose_button")
    close_button:SetGravity(ui.RIGHT, ui.TOP)
    close_button:SetEventScript(ui.LBUTTONUP, "_nexus_addons_p_list_close")
    local list_gb = list_frame:CreateOrGetControl("groupbox", "list_gb", 10, 40, 0, 0)
    AUTO_CAST(list_gb)
    list_gb:SetSkinName("bg")
    list_gb:RemoveAllChild()
    list_gb:EnableHitTest(1)
    list_frame:ShowWindow(1)
    local base_num = 25
    local col1_x = 20
    local row_height = 35
    local max_width1 = 0
    local max_width2 = 0
    for i, entry in ipairs(g._nexus_addons_p) do
        local name = entry.data.name
        local current_y = (i <= base_num) and (i - 1) * row_height or (i - (base_num + 1)) * row_height
        local name_text = list_gb:CreateOrGetControl('richtext', 'name_text' .. i, col1_x, current_y + 10, 10, 30)
        AUTO_CAST(name_text)
        name_text:SetText("{ol}{s20}" .. name)
        if i <= base_num then
            max_width1 = math.max(max_width1, name_text:GetWidth())
        else
            max_width2 = math.max(max_width2, name_text:GetWidth())
        end
    end
    local col2_x = col1_x + max_width1 + 180
    for i, entry in ipairs(g._nexus_addons_p) do
        local child_addon_name = entry.key
        local data = entry.data
        local use = g.settings[child_addon_name].use
        local buttons_x, current_y
        if i <= base_num then
            buttons_x = col1_x + max_width1 + 25
            current_y = (i - 1) * row_height
        else
            local name_text = GET_CHILD(list_gb, 'name_text' .. i)
            name_text:SetPos(col2_x, name_text:GetY())
            buttons_x = col2_x + max_width2 + 25
            current_y = (i - (base_num + 1)) * row_height
        end
        local use_toggle = list_gb:CreateOrGetControl('picture', "use_toggle" .. i, buttons_x, current_y + 10, 60, 25)
        AUTO_CAST(use_toggle)
        use_toggle:SetImage(use == 1 and "test_com_ability_on" or "test_com_ability_off")
        use_toggle:SetEnableStretch(1)
        use_toggle:EnableHitTest(1)
        use_toggle:SetTextTooltip("{ol}ON/OFF")
        use_toggle:SetEventScript(ui.LBUTTONUP, "_nexus_addons_p_toggle_addons")
        use_toggle:SetEventScriptArgString(ui.LBUTTONUP, child_addon_name)
        if data.frame_use then
            local config_btn = list_gb:CreateOrGetControl('button', 'config_btn' .. i, buttons_x + 65, current_y + 10,
                25, 25)
            AUTO_CAST(config_btn)
            config_btn:SetSkinName("None")
            config_btn:SetTextTooltip(g.lang == "Japanese" and "{ol}設定フレーム呼出し" or
                                          "Call Settings Frame")
            config_btn:SetText("{img config_button_normal 25 25}")
            if data.config_func and data.config_func ~= "" then
                config_btn:SetEventScript(ui.LBUTTONUP, data.config_func)
            end
        end
        local help_btn = list_gb:CreateOrGetControl('button', 'help_btn' .. i, buttons_x + 100, current_y + 5, 40, 30)
        AUTO_CAST(help_btn)
        help_btn:SetText("{ol}{img question_mark 20 15}")
        -- 登録リストに追加したのに翻訳を書き忘れると、ここの index で一覧フレームごと
        -- 落ちる(この関数は pcall の外)。説明が無いだけで一覧は開けるようにしておく。
        local trans = g._nexus_addons_p_trans[child_addon_name] or {}
        local tooltip_text
        if g.lang == "Japanese" then
            tooltip_text = trans.ja
        elseif g.lang == "kr" then
            tooltip_text = trans.kr
        else
            tooltip_text = trans.etc
        end
        tooltip_text = tooltip_text or ("{ol}" .. data.name)
        help_btn:SetTextTooltip(tooltip_text)
        help_btn:SetSkinName("test_pvp_btn")
    end
    local total_width = col2_x + max_width2 + 200
    local total_height = base_num * row_height + 70
    list_frame:Resize(total_width, total_height)
    list_gb:Resize(list_frame:GetWidth() - 20, list_frame:GetHeight() - 50)
    list_frame:SetPos(310, 100)
    return list_frame
end

function _nexus_addons_p_list_close(frame)
    local frame_to_close = {"boss_direction_settings", "auto_repair_settings", "instant_cc_settings",
                            "my_buffs_control_setting", "revival_timer_setting", "vakarine_equip_config_frame",
                            "easy_buff", "always_status_settings", "lets_go_home_setting", "characters_item_serch",
                            "sub_map_setting_frame", "separate_buff_custom_buff_list", "save_quest_setting",
                            "sub_slotset_setting", "Battle_ritual_setting", "Battle_ritual_skill_list",
                            "Battle_ritual_buff_list", "get_event_msg_setting", "archeology_helper_setting"}
    for _, suffix in ipairs(frame_to_close) do
        local frame_name = addon_name_lower .. suffix
        local frame_to_close = ui.GetFrame(frame_name)
        if frame_to_close then
            ui.DestroyFrame(frame_name)
        end
    end
    ui.DestroyFrame(frame:GetName())
end

function _nexus_addons_p_toggle_addons(list_gb, use_toggle, child_addon_name, num)
    local old_init_func_name = nil
    for _, entry in ipairs(g._nexus_addons_p) do
        if entry.key == child_addon_name then
            old_init_func_name = entry.data.old_init_func
            break
        end
    end
    if old_init_func_name and old_init_func_name ~= "" and _G[old_init_func_name] and
        not (old_init_func_name == "INSTANTCC_ON_INIT" and _G["instant_cc_on_init"]) then
        local message = nil
        old_init_func_name = string.lower(string.gsub(old_init_func_name, "_ON_INIT", ""))
        old_init_func_name = string.gsub(old_init_func_name, "_", " ")
        if g.lang == "Japanese" then
            message = string.format(
                "[Nexus Addons P] 競合する古いアドオン '%s' が検出されました '%s' を有効化できません{nl}dataフォルダから、古いアドオンのipfファイルを削除してください",
                old_init_func_name, child_addon_name)
        else
            message = string.format(
                "[Nexus Addons P] Conflicting old addon '%s' detected Cannot enable '%s'{nl}Please remove the old addon's ipf file from your data folders",
                old_init_func_name, child_addon_name)
        end
        if message then
            imcAddOn.BroadMsg("NOTICE_Dm_!", message, 5.0)
        end
        return
    end
    if g.settings[child_addon_name].use == 1 then
        g.settings[child_addon_name].use = 0
        local msg = g.lang == "Japanese" and g.settings[child_addon_name].name .. " 無効にしました" or
                        g.settings[child_addon_name].name .. " Disabled"
        imcAddOn.BroadMsg("NOTICE_Dm_!", msg, 5.0)
    else
        g.settings[child_addon_name].use = 1
        local msg = g.lang == "Japanese" and g.settings[child_addon_name].name .. " 有効にしました" or
                        g.settings[child_addon_name].name .. " Enabled"
        imcAddOn.BroadMsg("NOTICE_Dm_Bell", msg, 5.0)
    end
    _nexus_addons_p_init_addons(true, child_addon_name)
    _nexus_addons_p_save_settings()
    _nexus_addons_p_frame_init()
end

function _nexus_addons_p_GAME_START(_nexus_addons_p, msg)
    -- A: ON_INIT の時点ではまだ本家が読み込まれていない可能性があるため、
    -- 全アドオンのロードが終わっているここで必ず再判定する。
    if g.origin_conflict or g.detect_origin_addon() then
        g.origin_conflict = true
        _nexus_addons_p_origin_conflict_notice(_nexus_addons_p)
        return
    end
    -- if not g.settings then
    _nexus_addons_p_load_settings()
    -- end
    -- 以降の init ログを読むときの起点。ここより前は g.settings が無く vlog も黙る。
    -- ファイル側はここで作り直すので、常に「今回の起動分だけ」が入る。
    g.vlog_reset()
    g.vlog("===== GAME_START v%s lang=%s map=%s(%s) cid=%s", tostring(ver), tostring(g.lang),
        tostring(session.GetMapName()), tostring(g.get_map_type()), tostring(g.cid))
    if g.migrate_result == "copied" or g.migrate_result == "partial" then
        g.migrate_result = false
        g.pending_messages = g.pending_messages or {}
        table.insert(g.pending_messages, g.lang == "Japanese" and
            "{ol}{#00BFFF}[Nexus Addons P] 本家 Nexus Addons の設定を引き継ぎました" or
            "{ol}{#00BFFF}[Nexus Addons P] Settings were carried over from the original Nexus Addons")
        _nexus_addons_p:RunUpdateScript("_nexus_addons_p_chat_system", 0.5)
    end
    _G["norisan"] = _G["norisan"] or {}
    _G["norisan"]["MENU"] = _G["norisan"]["MENU"] or {}
    local menu_data = {
        name = "Nexus Addons P",
        icon = "sysmenu_coll",
        func = "_nexus_addons_p_frame_init",
        image = ""
    }
    _G["norisan"]["MENU"][addon_name] = menu_data
    local frame_name = _G["norisan"]["MENU"].frame_name
    local menu_frame = ui.GetFrame(frame_name)
    if menu_frame and frame_name ~= "norisan_menu_frame" then
        ui.DestroyFrame(frame_name)
    end
    frame_name = "norisan_menu_frame"
    menu_frame = ui.GetFrame(frame_name)
    if not menu_frame then
        _G["norisan"]["MENU"].frame_name = frame_name
        addons_menu_create_frame()
    elseif menu_frame:IsVisible() == 0 then
        menu_frame:ShowWindow(1)
    end
    g.setup_hook(_nexus_addons_p_APPS_TRY_MOVE_BARRACK, "APPS_TRY_MOVE_BARRACK")
    _nexus_addons_p_fast_func()
end

-- ESC は hideable なフレーム(ゲーム側定義が <option hideable="true"> のもの)を閉じる。
-- 自前のメニューボタンは notice_on_pc 由来に変えて消えないようにしたが、
-- norisan_menu_frame という名前は他の norisan 系アドオンと共有していて、向こうが先に
-- 旧定義(chat_memberlist 由来)で作っていると ESC で消えたままになる。消えていたら
-- 作り直し、以後は消えない自前の定義に置き換える。
-- ESCAPE_PRESSED はフレームが閉じられる前に届くことがあるため、次の更新まで待って調べる。
function _nexus_addons_p_ESCAPE_PRESSED(_nexus_addons_p)
    _nexus_addons_p:RunUpdateScript("_nexus_addons_p_restore_menu_frame", 0.1)
end

function _nexus_addons_p_restore_menu_frame()
    local menu_frame = ui.GetFrame("norisan_menu_frame")
    if not menu_frame then
        _G["norisan"]["MENU"].frame_name = "norisan_menu_frame"
        addons_menu_create_frame()
    elseif menu_frame:IsVisible() == 0 then
        AUTO_CAST(menu_frame)
        menu_frame:ShowWindow(1)
    end
    return 0 -- 1 回で止める
end

function _nexus_addons_p_GAME_START_3SEC(_nexus_addons_p, msg)
    -- A: GAME_START で初めて競合が判明した場合、ここは ON_INIT で既に登録済みなので止める
    if g.origin_conflict then
        return
    end
    _nexus_addons_p_init_addons(false, nil, _nexus_addons_p)
    g.addon:RegisterMsg('FPS_UPDATE', '_nexus_addons_p_update_frames')
end

function _nexus_addons_p_fast_func(_nexus_addons_p)
    if g.separate_buff_custom_settings and g.settings.separate_buff_custom.use == 1 and
        g.separate_buff_custom_settings.tracking == 1 then
        Separate_buff_custom_frame_move()
    end
    if g.quickslot_operate_settings and g.quickslot_operate_settings.straight then
        Quickslot_operate_redraw_slots()
    end --
    if g.indun_panel_settings and g.settings.indun_panel.use == 1 then
        Indun_panel_frame_init()
    end
    if g.awh_settings then
        another_warehouse_on_init()
    end
end

-- _nexus_addons_p_update_frames は FPS_UPDATE = 毎フレーム呼ばれる。以前は毎フレーム
-- この 15 要素のテーブルを作り直し、そのつど addon_name_lower との連結でフレーム名を
-- 組み立てていたので、読み込み時に一度だけ組み立てて使い回す。
-- (要素の追加・削除はここだけ触ればよい。city_hidden は街/インスタンスで出さない印)
local update_check_frames = {}
do
    local frame_keys = {"always_status", "pick_item_tracker", "monster_kill_count", "debuff_notice",
                        "guild_event_warp", "lets_go_home", "relic_change", "vakarine_equip", "sub_map",
                        "save_quest", "indun_panel", "Battle_ritual", "muteki", "au_map", "tos_btn"}
    for i, frame_key in ipairs(frame_keys) do
        update_check_frames[i] = {
            name = addon_name_lower .. frame_key,
            city_hidden = (frame_key == "pick_item_tracker")
        }
    end
end

function _nexus_addons_p_update_frames()
    local root_frame = ui.GetFrame("_nexus_addons_p")
    if root_frame and root_frame:IsVisible() == 0 then
        root_frame:ShowWindow(1)
    end
    -- マップ種別の取得は g.get_map_type() 側でマップ単位にメモ化済みなので、
    -- ここで重ねてキャッシュしない(以前は同じ行で 2 回呼んでいた分だけが無駄だった)。
    for _, entry in ipairs(update_check_frames) do
        local frame = ui.GetFrame(entry.name)
        if frame and frame:IsVisible() == 0 then
            if entry.city_hidden then
                local map_type = g.get_map_type()
                if map_type ~= "City" and map_type ~= "Instance" then
                    AUTO_CAST(frame)
                    frame:ShowWindow(1)
                end
            else
                AUTO_CAST(frame)
                frame:ShowWindow(1)
            end
        end
    end
end

function _nexus_addons_p_APPS_TRY_MOVE_BARRACK()
    Other_character_skill_list_save_enchant()
    Indun_list_viewer_save_current_char_counts()
    if g.settings.instant_cc and g.settings.instant_cc.use == 1 then
        if Instant_cc_APPS_TRY_LEAVE_ then
            Instant_cc_APPS_TRY_LEAVE_("Barrack")
            return
        end
    end
    if g.settings.indun_list_viewer and g.settings.indun_list_viewer.use == 1 then
        if Indun_list_viewer_CHECK_ALERT and Indun_list_viewer_CHECK_ALERT("Barrack") then
            return
        end
    end
    APPS_TRY_LEAVE("Barrack")
end
