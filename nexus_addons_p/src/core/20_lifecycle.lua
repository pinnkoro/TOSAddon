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
    -- ESC はここ 1 箇所だけで受ける(アドオン側で個別に購読しないこと。理由は g.esc_register)
    addon:RegisterMsg('ESCAPE_PRESSED', '_nexus_addons_p_ESCAPE_PRESSED')
    g.setup_hook(_nexus_addons_p_CHAT_SYSTEM, "CHAT_SYSTEM")
end

-- ESC で閉じるのは、開いている自作ウィンドウのうち一番手前の 1 枚だけ。
-- 登録は各アドオンがフレームを開いたところで g.esc_register する(詳細は core/00_header.lua)。
function _nexus_addons_p_ESCAPE_PRESSED()
    -- ESC は 2 経路で届きうる: g.esc_sync_scp が仕込む ui.SetEscapeScp と、
    -- ゲームからアドオンへ一斉配信される ESCAPE_PRESSED。どちらが来る(あるいは両方来る)かは
    -- クライアント任せなので、同じ押下で二重に閉じないよう直後の再入は捨てる。
    if g.esc_is_reentry() then
        return
    end
    g.esc_last_ms = imcTime.GetAppTimeMS()
    local entry = g.esc_pop_top()
    if not entry then
        -- 閉じるものが無いのに ESC が回ってきた = SetEscapeScp を戻し損ねている。
        -- そのままだとシステムメニューが開けなくなるので、ここで必ず戻す。
        g.esc_sync_scp()
        return
    end
    local close_func = _G[entry.close]
    if type(close_func) ~= "function" then
        g.vlog("ESCAPE_PRESSED: close func not found frame=%s func=%s", tostring(entry.frame), tostring(entry.close))
        g.esc_sync_scp()
        return
    end
    g.vlog("ESCAPE_PRESSED: close %s (残り %d)", tostring(entry.frame), #g.esc_stack)
    -- ESCAPE_PRESSED を購読している側(indun_panel)が「この押下は使われた」と判断できるよう、
    -- 実際に閉じたときだけ印を置く。閉じるものが無かった押下はゲーム側へ渡す。
    g.esc_closed_ms = imcTime.GetAppTimeMS()
    -- 閉じる処理が転んでもゲーム側の ESC 処理を巻き込まないよう握る
    local ok, err = pcall(close_func)
    if not ok then
        g.vlog("ESCAPE_PRESSED: close failed frame=%s err=%s", tostring(entry.frame), tostring(err))
    end
    -- 最後の 1 枚を閉じたら ESC をゲームへ返す
    g.esc_sync_scp()
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

-- 成功した init の詳細ログ。ON のアドオンだけに絞る。
-- on_init は ON/OFF によらず全アドオン分呼ばれる(OFF 側はフレームの後始末に使う)ため、
-- 絞らないとマップ移動のたびに 48 行流れて、肝心の行が埋もれる。
-- 失敗(FAILED)は OFF でも知りたいので、そちらは絞らずそのまま出す。
function _nexus_addons_p_vlog_init(name, duration)
    local setting = g.settings and g.settings[name]
    if not setting or setting.use ~= 1 then
        return
    end
    g.vlog("init: %s (%dms)", name, duration)
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
                _nexus_addons_p_vlog_init(name, duration)
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
                _nexus_addons_p_vlog_init(func_name, duration)
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
    -- タイトル行の右側に一括操作ボタン(全て OFF / バックアップ / 復元)を並べるので、
    -- タイトルと重ならない幅を確保する。幅はアドオン名の長さで決まり、翻訳やフォントで
    -- 変わりうるため、固定値ではなく実際のタイトル幅から計算する。
    total_width = math.max(total_width, title:GetWidth() + 40 + g.maintenance_buttons_width())
    local total_height = base_num * row_height + 70
    list_frame:Resize(total_width, total_height)
    list_gb:Resize(list_frame:GetWidth() - 20, list_frame:GetHeight() - 50)
    g.create_maintenance_buttons(list_frame, total_width)
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
    -- マップ移動でゲーム側が ESC の割り込み先を戻している可能性があるので、
    -- 「設定済み」の記憶を捨てて次の同期で入れ直させる(g.esc_sync_scp 参照)。
    g.esc_scp_set = nil
    -- 以降の init ログを読むときの起点。ここより前は g.settings が無く vlog も黙る。
    -- GAME_START はマップ移動のたびに来るので、この行はマップごとの区切りにもなる
    -- (ログファイルはここでは作り直さない。詳細は 00_header.lua の vlog_write)。
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
    -- 相乗り側が別名でメニューを作っていたら壊してから、こちらの名前で作り直す。
    -- frame_name を入れるのは相乗り側なので、まだ誰も入れていなければ nil。
    -- 初回ログインは常にこの状態なので、nil を ui.GetFrame へ渡さないよう
    -- 名前がある場合だけ引く(順序を入れ替えただけで、壊す条件は変えていない)。
    local frame_name = _G["norisan"]["MENU"].frame_name
    if frame_name and frame_name ~= "norisan_menu_frame" and ui.GetFrame(frame_name) then
        ui.DestroyFrame(frame_name)
    end
    frame_name = "norisan_menu_frame"
    local menu_frame = ui.GetFrame(frame_name)
    -- norisan_menu_frame という名前は他の norisan 系アドオンと共有していて、向こうが
    -- 先に旧定義(chat_memberlist 由来 = ESC で閉じられる)で作っていることがある。
    -- その場合はここで消えない自前の定義(notice_on_pc 由来)へ作り替える。
    --
    -- 「ESC で消えたら直す」方式は成立しない。ESC による非表示は IsVisible() に
    -- 反映されないので、隠れたことを検出する手段が無いため。土台を先に置き換える。
    if not menu_frame or not g.addons_menu_frame_owned then
        _G["norisan"]["MENU"].frame_name = frame_name
        addons_menu_create_frame()
    elseif menu_frame:IsVisible() == 0 then
        AUTO_CAST(menu_frame)
        menu_frame:ShowWindow(1)
    end
    g.setup_hook(_nexus_addons_p_APPS_TRY_MOVE_BARRACK, "APPS_TRY_MOVE_BARRACK")
    _nexus_addons_p_fast_func()
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
    -- × ボタンで閉じた場合はどこからも通知が来ないので、ここで実際の表示状態に合わせる。
    -- 状態が変わったときだけ ui.SetEscapeScp を呼ぶので、毎フレームでも実害は無い。
    g.esc_sync_scp()
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
