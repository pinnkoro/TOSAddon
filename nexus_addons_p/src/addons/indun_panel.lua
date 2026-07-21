-- indun_panel ここから
local induns = {{
    challenge = {
        solo_520 = 1001,
        solo_540 = 1004,
        pt_540 = 1005,
        jp = "チャレンジ",
        icon = {"Item", 490363}
    }
}, {
    singularity = {
        singularity_520 = 2000,
        singularity_540 = 2001,
        jp = "分裂特異点",
        icon = {"Item", 11030017}
    }
}, {
    zmei = {
        h = 731,
        s = 730,
        a = 729,
        ac = 80047,
        jp = "ズメイ",
        icon = {"Monster", 71076}
    }
}, {
    belliora = {
        h = 727,
        s = 726,
        a = 725,
        ac = 80045,
        jp = "ベリオラ",
        icon = {"Monster", 71043}
    }
}, {
    laimara = {
        h = 724,
        s = 723,
        a = 722,
        ac = 80043,
        jp = "ライマラ",
        icon = {"Monster", 71040}
    }
}, {
    ledania = {
        h = 718,
        s = 717,
        a = 716,
        ac = 80039,
        jp = "レダニア",
        icon = {"Monster", 59864}
    }
}, {
    neringa = {
        h = 709,
        s = 708,
        a = 707,
        ac = 80035,
        jp = "ネリンガ",
        icon = {"Monster", 59856}
    }
}, {
    golem = {
        h = 712,
        s = 711,
        a = 710,
        ac = 80037,
        jp = "ゴーレム",
        icon = {"Monster", 59859}
    }
}, {
    merregina = {
        s = 696,
        a = 695,
        h = 697,
        ac = 80032,
        jp = "メレジナ",
        icon = {"Monster", 59824}
    }
}, {
    slogutis = {
        s = 689,
        a = 688,
        h = 690,
        ac = 80031,
        jp = "スローガティス",
        icon = {"Monster", 59798}
    }
}, {
    upinis = {
        s = 686,
        a = 685,
        h = 687,
        ac = 80030,
        jp = "ウピニス",
        icon = {"Monster", 59795}
    }
}, {
    roze = {
        s = 680,
        a = 679,
        h = 681,
        ac = 80015,
        jp = "ロゼ",
        icon = {"Monster", 59773}
    }
}, {
    falouros = {
        s = 677,
        a = 676,
        h = 678,
        ac = 80017,
        jp = "ファロウロス",
        icon = {"Monster", 59760}
    }
}, {
    reservoir = {
        s = 674,
        a = 673,
        h = 675,
        ac = 80016,
        jp = "プロパゲーター",
        icon = {"Monster", 59752}
    }
}, {
    jellyzele = {
        s = 672,
        a = 671,
        h = 670,
        jp = "ジェリージェル",
        icon = {"Monster", 59730}
    }
}, {
    delmore = {
        s = 667,
        a = 666,
        h = 665,
        jp = "デルムーア",
        icon = {"Monster", 59690}
    }
}, {
    giltine = {
        s = 669,
        a = 635,
        h = 628,
        jp = "ギルティネ",
        icon = {"Monster", 59549}
    }
}, {
    memory = {
        s = 661,
        a = 662,
        h = 663,
        jp = "焔の記憶",
        icon = {"Item", 11100001}
    }
}, {
    telharsha = {
        id = 623,
        jp = "テルハルシャ",
        icon = {"Monster", 59477}
    }
}, {
    bernice = {
        id = 201,
        jp = "ヴェルニケ",
        icon = {"Item", 11030257}
    }
}, {
    wailing = {
        id = 684,
        jp = "嘆きの墓地",
        icon = {"Item", 960213}
    }
}, {
    ashaq = {
        id = 728,
        jp = "アシャーク",
        icon = {"Item", 11200484}
    }
}, {
    jsr = {
        id = 0,
        jp = "ボス協同戦",
        icon = {}
    }
}}

function Indun_panel_save_settings()
    g.save_json(g.indun_panel_path, g.indun_panel_settings)
end

function Indun_panel_load_settings()
    g.indun_panel_path = string.format("../addons/%s/%s/indun_panel.json", addon_name_lower, g.active_id)
    g.indun_panel_old_path = string.format("../addons/%s/%s/settings.json", "indun_panel", g.active_id)
    local settings = g.load_json(g.indun_panel_path)
    local indun_keys = {"challenge", "singularity", "zmei", "belliora", "laimara", "ledania", "neringa", "golem",
                        "merregina", "slogutis", "upinis", "roze", "falouros", "reservoir", "jellyzele", "delmore",
                        "telharsha", "bernice", "giltine", "memory", "wailing", "ashaq", "jsr"}
    local json_to_indun_map = {
        veliora = "belliora",
        limara = "laimara",
        redania = "ledania",
        spreader = "reservoir",
        velnice = "bernice",
        cemetery = "wailing",
        demonlair = "ashaq",
        earring = "memory"
    }
    if not settings then
        local function create_default_set()
            local set = {}
            for _, name in ipairs(indun_keys) do
                set[name] = 1
            end
            return set
        end
        settings = {
            etc = {
                challenge_ticket = "month",
                always_open = 0,
                singularity_check = 0,
                skin_name = "chat_window_2",
                en_ver = 0,
                x = 665,
                y = 30,
                move = 0,
                use_set = "set_a",
                challenge_map = 0,
                base_date = "",
                shading = 0,
                field_mode = 0,
                toscoin = 0
            },
            cols = {
                tos = 1,
                gabija = 1,
                vakarine = 1,
                rada = 1,
                jurate = 1,
                austeja = 1,
                pvp_mine = 1,
                market = 1,
                craft = 1,
                leticia = 1
            },
            set_names = {{
                set_a = "SET A"
            }, {
                set_b = "SET B"
            }, {
                set_c = "SET C"
            }},
            set_a = create_default_set(),
            set_b = create_default_set(),
            set_c = create_default_set()
        }
        local old_settings = g.load_json(g.indun_panel_old_path)
        if old_settings then
            for k, v in pairs(old_settings) do
                if type(v) == "table" then
                    if k == "set_a" or k == "set_b" or k == "set_c" then
                        for k2, v2 in pairs(v) do
                            if string.find(k2, "_checkbox") then
                                local json_key = string.gsub(k2, "_checkbox", "")
                                local correct_key = json_to_indun_map[json_key] or json_key
                                if settings[k] and settings[k][correct_key] ~= nil then
                                    settings[k][correct_key] = v2
                                end
                            end
                        end
                    elseif k == "cols" then
                        settings.cols = v
                    end
                else
                    if k ~= "auto_challenge" then
                        if k == "checkbox" then
                            settings.etc.always_open = v
                        elseif settings.etc[k] ~= nil then
                            settings.etc[k] = v
                        end
                    end
                end
            end
        end
    end
    -- 新ダンジョン追加時のバックフィル: 既存ユーザーの保存済み設定に無いキーを既定ON(1)で補完
    for _, set_name in ipairs({"set_a", "set_b", "set_c"}) do
        if type(settings[set_name]) == "table" then
            for _, name in ipairs(indun_keys) do
                if settings[set_name][name] == nil then
                    settings[set_name][name] = 1
                end
            end
        end
    end
    g.indun_panel_settings = settings
    Indun_panel_save_settings()
end

function indun_panel_on_init()
    -- 設定ロードと CHAT_SYSTEM(デイリー額取得)フックは機能ON/OFFに関わらず従来通り行う。
    -- 旧来ここで開いていた PVP_MINE ショップだけは、機能OFFでもログイン時にショップが開き
    -- インベントリが閉じる不具合の原因だったため撤去し、パネル展開時の遅延同期
    -- (Indun_panel_frame_open → Indun_panel_sync_mine_shop)へ移した。
    if not g.indun_panel_settings then
        Indun_panel_load_settings()
    end
    g.setup_hook_and_event(g.addon, "CHAT_SYSTEM", "Indun_panel_CHAT_SYSTEM", true)
    -- 機能OFF: フレームを破棄し、パネル用フック(ESCAPE/INDUN_ALREADY_PLAYING)は張らない。
    -- use チェックはフレーム構築より前に置く。これで機能OFF時に一度フレームを組んで
    -- 即破棄する(map パネル破棄や save_current_char_counts の副作用込みの)無駄を無くす。
    -- フレーム構築は下の `if not indun_panel` に一本化した(初回/再init どちらもここを通る)。
    if g.settings.indun_panel.use == 0 then
        ui.DestroyFrame(addon_name_lower .. "indun_panel")
        ui.DestroyFrame(addon_name_lower .. "indun_panel_map")
        return
    end
    g.addon:RegisterMsg("ESCAPE_PRESSED", "Indun_panel_frame_init")
    local indun_panel = ui.GetFrame(addon_name_lower .. "indun_panel")
    if not indun_panel then
        Indun_panel_frame_init()
    end
    g.setup_hook_and_event(g.addon, "INDUN_ALREADY_PLAYING", "Indun_panel_INDUN_ALREADY_PLAYING", false)
end

-- PVP_MINE ショップを一瞬開いて ssn_shop を同期する。ショップを開くとゲームが
-- インベントリ等の排他UIを閉じるため、開いていたインベントリを記録しておき、
-- 同期完了時(Indun_panel_earthtowershop_close)に復元する。
-- 同期を開始できたら true、ショップフレーム未取得で空振りしたら false を返す。
-- (呼び出し側は開始時に syncing を立てて二重起動を防ぎ、synced は完了時=
--  Indun_panel_earthtowershop_close で立てる。空振り時は何も立てず次の展開で再試行する)
function Indun_panel_sync_mine_shop()
    local earthtowershop = ui.GetFrame('earthtowershop')
    if not earthtowershop then
        return false
    end
    local inventory = ui.GetFrame("inventory")
    g.indun_panel_inv_restore = (inventory and inventory:IsVisible() == 1) and true or false
    earthtowershop:Resize(0, 0)
    pc.ReqExecuteTx_NumArgs("SCR_PVP_MINE_SHOP_OPEN", 0)
    earthtowershop:RunUpdateScript("Indun_panel_earthtowershop_close", 0.1)
    return true
end

function Indun_panel_earthtowershop_close(earthtowershop)
    if earthtowershop:IsVisible() == 1 then
        earthtowershop:Resize(580, 1920)
        ui.CloseFrame("earthtowershop")
        -- 同期完了(ショップが実際に開いて ssn_shop を取得できた)。以後セッション中は再同期しない。
        -- synced をここで立てることで、ショップが一度も開けなかった場合は synced が立たず
        -- 次の展開で再試行される(開始時点で立てると空取得のまま固定される問題を防ぐ)。
        g.indun_panel_mine_synced = true
        g.indun_panel_mine_syncing = false
        -- 同期のためにゲームが閉じたインベントリを、元々開いていたら復元する
        if g.indun_panel_inv_restore then
            g.indun_panel_inv_restore = false
            ui.OpenFrame("inventory")
        end
        -- 同期完了。表示中かつ展開中(高さ>40)のパネルだけ再描画して PVP_MINE 数を反映する。
        -- (同期中の0.1秒間にユーザーが畳んだ/閉じた場合は再描画しない=無駄な再構築を避ける)
        local indun_panel = ui.GetFrame(addon_name_lower .. "indun_panel")
        if indun_panel and indun_panel:IsVisible() == 1 and indun_panel:GetHeight() > 40 then
            Indun_panel_frame_open(indun_panel)
        end
        return 1
    else
        return 0
    end
end

function Indun_panel_CHAT_SYSTEM(my_frame, my_msg)
    local msg, color = g.get_event_args(my_msg)
    if msg then
        local pattern = "EVENT_TOS_WHOLE_GET_SUCCESS_MSG"
        if string.find(msg, pattern) then
            local daily_value_str = msg:match("%$%*%$DAILY%$%*%$(%d+)%$%*%$")
            g.indun_panel_settings.etc.toscoin = tonumber(daily_value_str)
            Indun_panel_save_settings()
        end
    end
end

function Indun_panel_INDUN_ALREADY_PLAYING(my_frame, my_msg)
    if g.settings.indun_panel.use == 0 then
        g.FUNCS["INDUN_ALREADY_PLAYING"]()
        return
    end
    ReserveScript("Indun_panel_INDUN_ALREADY_PLAYING_dilay()", 0.3)
end

function Indun_panel_INDUN_ALREADY_PLAYING_dilay()
    local indunenter = ui.GetFrame("indunenter")
    local indun_type = indunenter:GetUserIValue('INDUN_TYPE')
    if indun_type == 1005 or indun_type == 2000 or indun_type == 2001 then -- 1005＝540チャレPT 2001＝540分裂
        AnsGiveUpPrevPlayingIndun(1)
        ui.CloseFrame("indunenter")
        ReserveScript(string.format("Indun_panel_enter_singularity(nil,nil,'', %d)", indun_type), 0.5)
        return
    else
        local yes_scp = string.format("AnsGiveUpPrevPlayingIndun(%d)", 1)
        local no_scp = string.format("AnsGiveUpPrevPlayingIndun(%d)", 0)
        ui.MsgBox(ClMsg("IndunAlreadyPlaying_AreYouGiveUp"), yes_scp, no_scp)
    end
end

function Indun_panel_challenge(_nexus_addons_p)
    if not g.indun_panel_challenge_start_time then
        _nexus_addons_p:StopUpdateScript("Indun_panel_challenge")
        return 0
    end
    local now = imcTime.GetAppTimeMS()
    if (now - g.indun_panel_challenge_start_time) >= 3000 then
        _nexus_addons_p:StopUpdateScript("indun_panel_challenge")
        g.indun_panel_challenge_start_time = nil
        return 0
    end
    local is_auto_challenge_map = session.IsAutoChallengeMap()
    local is_solo_challenge_map = session.IsSoloChallengeMap()
    if is_auto_challenge_map == true or is_solo_challenge_map == true then
        ui.DestroyFrame(addon_name_lower .. "indun_panel")
        _nexus_addons_p:StopUpdateScript("Indun_panel_challenge")
        g.indun_panel_challenge_start_time = nil
        if g.indun_panel_settings.etc.base_date ~= "" then
            return 0
        end
        local cnt = 0
        local found_clsid = nil
        local challenge_map_list, count = GetClassList('challenge_mode_auto_map')
        for i = 0, count - 1 do
            local map_cls = GetClassByIndexFromList(challenge_map_list, i)
            if map_cls then
                local map_name = map_cls.MapName
                if g.map_name == map_name then
                    cnt = cnt + 1
                    if found_clsid == nil then
                        found_clsid = map_cls.ClassID
                    end
                end
            end
        end
        if cnt == 1 and found_clsid then
            g.indun_panel_settings.etc.challenge_map = found_clsid
            local server_time_str = date_time.get_lua_now_datetime_str()
            if server_time_str then
                local y, m, d, H, M, S = server_time_str:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
                if y then
                    local time_table = {
                        year = tonumber(y),
                        month = tonumber(m),
                        day = tonumber(d),
                        hour = 12,
                        min = 0,
                        sec = 0
                    }
                    g.indun_panel_settings.etc.base_date = os.time(time_table)
                    Indun_panel_save_settings()
                end
            end
        end
        return 0
    end
    return 1
end

-- test_code
--[[local challenge_map_list, count = GetClassList('challenge_mode_auto_map')
for i = 0, count - 1 do
    local map_cls = GetClassByIndexFromList(challenge_map_list, i)
    if map_cls then
        local map_name = map_cls.Name
        local map_clsname = map_cls.MapName
        local map_cls_ = GetClass("Map", map_clsname)
        local map_level = map_cls_.QuestLevel
        ts(i, dic.getTranslatedStr(map_name), map_level)
    end
end]]

local function indun_panel_get_server_elapsed_days(base_date)
    if not base_date or base_date == "" or base_date == 0 then
        return 0
    end
    local server_time_str = date_time.get_lua_now_datetime_str()
    if not server_time_str then
        return 0
    end
    local y, m, d = server_time_str:match("(%d+)-(%d+)-(%d+)")
    if not y then
        return 0
    end
    local server_now = os.time({
        year = tonumber(y),
        month = tonumber(m),
        day = tonumber(d),
        hour = 12
    })
    local base_tbl = os.date("*t", base_date)
    base_tbl.hour = 12
    local server_base = os.time(base_tbl)
    return math.floor((server_now - server_base) / 86400)
end

function Indun_panel_challenge_map_context(indun_panel, ctrl)
    local base_date = g.indun_panel_settings.etc.base_date
    if not base_date or base_date == "" or base_date == 0 then
        return
    end
    local weekdays = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"}
    local elapsed_days = indun_panel_get_server_elapsed_days(base_date)
    local context = ui.CreateContextMenu("challenge_map_schedule", "{ol}Challenge Map Schedule", 0, 100, 0, 0)
    local challenge_map_list, count = GetClassList('challenge_mode_auto_map')
    local start_index = g.indun_panel_settings.etc.challenge_map
    for i = 0, 6 do
        local map_index = (start_index + elapsed_days + i) % count
        local map_cls = GetClassByIndexFromList(challenge_map_list, map_index)
        if map_cls then
            local map_name = map_cls.Name
            local map_clsname = map_cls.MapName
            local server_time_str = date_time.get_lua_now_datetime_str()
            local y, m, d = server_time_str:match("(%d+)-(%d+)-(%d+)")
            local base_time = os.time({
                year = tonumber(y),
                month = tonumber(m),
                day = tonumber(d),
                hour = 12
            })
            local display_time = base_time + (i * 86400)
            local month_day = os.date("%m-%d", display_time)
            local day_of_week_num = tonumber(os.date("%w", display_time))
            local day_of_week_str = weekdays[day_of_week_num + 1]
            local date_str = string.format("%s (%s)", month_day, day_of_week_str)
            local scp = string.format("Indun_panel_challenge_map_display('%s','%s')", map_clsname, date_str)
            ui.AddContextMenuItem(context, date_str .. " " .. map_name, scp)
        end
    end
    ui.OpenContextMenu(context)
end

function Indun_panel_challenge_map_display(map_clsname, date_str)
    local indun_panel_map = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "indun_panel_map", 0, 0, 0, 0)
    AUTO_CAST(indun_panel_map)
    indun_panel_map:RemoveAllChild()
    indun_panel_map:SetSkinName("bg")
    indun_panel_map:SetLayerLevel(100)
    indun_panel_map:Resize(300, 320)
    local gb = indun_panel_map:CreateOrGetControl("picture", "gb", 0, 20, indun_panel_map:GetWidth(),
        indun_panel_map:GetHeight() - 20)
    AUTO_CAST(gb)
    gb:Resize(300, 300)
    gb:EnableHitTest(0)
    local close = indun_panel_map:CreateOrGetControl('button', 'close', 0, 0, 30, 30)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Indun_panel_challenge_map_close")
    local map_width = gb:GetWidth()
    local map_height = gb:GetHeight()
    local map_cls = GetClass("Map", map_clsname)
    if not map_cls then
        return
    end
    local map_title = indun_panel_map:CreateOrGetControl("richtext", "map_title", 0, 0)
    map_title:SetGravity(ui.LEFT, ui.TOP)
    map_title:SetText("{ol}" .. map_cls.Name .. " " .. date_str)
    local pic = gb:CreateOrGetControl('picture', "picture_" .. map_clsname, ui.CENTER_HORZ, ui.CENTER_VERT, map_width,
        map_height)
    AUTO_CAST(pic)
    pic:SetEnableStretch(1)
    local is_valid = ui.IsImageExist(map_clsname .. "_fog")
    if is_valid == false then
        world.PreloadMinimap(map_clsname)
    end
    pic:SetImage(map_clsname .. "_fog")
    local icon_group = gb:CreateOrGetControl("picture", "icon_group", ui.CENTER_HORZ, ui.CENTER_VERT, gb:GetWidth(),
        gb:GetHeight())
    AUTO_CAST(icon_group)
    icon_group:SetSkinName("None")
    local name_group = gb:CreateOrGetControl("picture", "name_group", ui.CENTER_HORZ, ui.CENTER_VERT, gb:GetWidth(),
        gb:GetHeight())
    AUTO_CAST(name_group)
    name_group:SetSkinName("None")
    UPDATE_MAP_BY_NAME(icon_group, map_clsname, pic, map_width, map_height, 0, 0)
    MAKE_MAP_AREA_INFO(name_group, map_clsname, "{s15}", map_width, map_height, -100, -30)
    local map_frame = ui.GetFrame("map")
    local width = map_frame:GetWidth()
    local height = map_frame:GetHeight()
    indun_panel_map:SetPos(width / 2 - 620, height / 2 - 300)
    indun_panel_map:ShowWindow(1)
end

function Indun_panel_challenge_map_close(frame)
    ui.DestroyFrame(frame:GetName())
end

function Indun_panel_frame_init(is_toggle, msg)
    if msg == "ESCAPE_PRESSED" then
        if g.indun_panel_settings.etc.always_open == 1 then
            return
        end
    end
    if g.get_map_type() ~= "City" then
        if g.get_map_type() == "Instance" or g.map_id == 8022 then
            return
        end
        if g.indun_panel_settings.etc.field_mode ~= 1 then
            ui.DestroyFrame(addon_name_lower .. "indun_panel")
            return
        end
    end
    --[[if g.get_map_type() ~= "City" and
        (g.indun_panel_settings.etc.field_mode ~= 1 and g.get_map_type() == "Instance" and g.map_id == 8022) then
        return
    end]]
    Indun_list_viewer_save_current_char_counts()
    ui.DestroyFrame(addon_name_lower .. "indun_panel_map")
    local indun_panel = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "indun_panel", 0, 0, 0, 0)
    AUTO_CAST(indun_panel)
    indun_panel:SetSkinName('None')
    indun_panel:SetLayerLevel(30)
    indun_panel:RemoveAllChild()
    Indun_panel_setup_frame(indun_panel)
    local btn = indun_panel:CreateOrGetControl("button", "btn", 5, 5, 80, 30)
    AUTO_CAST(btn)
    btn:SetText("{ol}{s10}INDUNPANEL")
    btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_frame_toggle")
    btn:SetEventScript(ui.RBUTTONUP, "Indun_panel_always_init")
    btn:SetEventScriptArgString(ui.RBUTTONUP, "OPEN")
    btn:SetTextTooltip(g.lang == "Japanese" and "{ol}右クリック: 常時展開で開く" or
                           "{ol}Right click: Open in Always Expand")
    local x = Indun_panel_create_common_buttons(indun_panel)
    local button_keys = {"tos", "gabija", "vakarine", "rada", "jurate", "austeja", "pvp_mine", "market", "craft",
                         "leticia"}
    for _, key_name in ipairs(button_keys) do
        local value = g.indun_panel_settings.cols[key_name]
        if value == 1 then
            if Indun_panel_create_shortcut_button(indun_panel, key_name, x) then
                x = x + 30
            end
        end
    end
    indun_panel:Resize(x, 40)
    indun_panel:ShowWindow(1)
    if not is_toggle then
        if g.indun_panel_settings.etc.always_open == 1 then
            Indun_panel_frame_open(indun_panel)
        end
    end
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    g.indun_panel_challenge_start_time = imcTime.GetAppTimeMS()
    _nexus_addons_p:RunUpdateScript("Indun_panel_challenge", 0.1)
    return indun_panel
end

function Indun_panel_setup_frame(indun_panel)
    local map = ui.GetFrame("map")
    local width = map:GetWidth()
    local x = g.indun_panel_settings.etc.x
    if width <= 1920 and x > 1920 then
        x = x / 21 * 16
    end
    indun_panel:SetPos(x, g.indun_panel_settings.etc.y)
    indun_panel:SetTitleBarSkin("None")
    local enable = g.indun_panel_settings.etc.move == 0 and 1 or 0
    indun_panel:EnableMove(enable)
    indun_panel:EnableHittestFrame(enable)
    -- フレーム固定チェックの状態に関わらず、ドラッグ保存ハンドラは常にバインドしておく。
    -- 固定モード(move==1)は EnableHittestFrame(0) で LBUTTONUP 自体が発火しないため無害。
    -- これにより、設定で固定を外して即ドラッグした場合(リビルド前)も、既にハンドラが
    -- 付いているので位置が保存される。
    -- (以前は固定モードで "None" にしており、チェックを外した直後に動かすと
    --  Indun_panel_ischecked が EnableMove を戻すだけでハンドラ未バインドのまま→保存されなかった)
    indun_panel:SetEventScript(ui.LBUTTONUP, "Indun_panel_frame_drag")
end

function Indun_panel_frame_drag(indun_panel)
    -- ネイティブ移動(EnableMove)で動かした後の座標を保存するだけ。
    -- リビルド(frame_init)しないことで、展開表示を畳まずに位置を維持する。
    -- LBUTTONUP は移動を伴わない単なるクリックでも発火するため、位置が変わっていなければ
    -- JSON 書き込み(save_settings)を省いて無駄なディスク I/O を避ける。
    local x = indun_panel:GetX()
    local y = indun_panel:GetY()
    if x == g.indun_panel_settings.etc.x and y == g.indun_panel_settings.etc.y then
        return
    end
    g.indun_panel_settings.etc.x = x
    g.indun_panel_settings.etc.y = y
    Indun_panel_save_settings()
end

function Indun_panel_create_common_buttons(indun_panel)
    local ccbtn = indun_panel:CreateOrGetControl('button', 'ccbtn', 85, 5, 30, 30)
    AUTO_CAST(ccbtn)
    ccbtn:SetSkinName("None")
    ccbtn:SetText("{img barrack_button_normal 30 30}")
    local lbtn_action = "APPS_TRY_MOVE_BARRACK"
    local rbtn_action = nil
    local tooltip_parts = {}
    local lbtn_tooltip = nil
    if type(_G["INSTANTCC_APPS_TRY_MOVE_BARRACK"]) == "function" and g.settings.instant_cc.use == 1 then
        lbtn_action = "INSTANTCC_APPS_TRY_MOVE_BARRACK"
        lbtn_tooltip = "[InstantCC] Open"
    end
    if type(_G["indun_list_viewer_title_frame_open"]) == "function" and g.settings.indun_list_viewer.use == 1 then
        lbtn_action = "indun_list_viewer_title_frame_open"
        lbtn_tooltip = "Left-Click: [ILV] Open"
    end
    if lbtn_tooltip then
        table.insert(tooltip_parts, lbtn_tooltip)
    end
    if type(_G["other_character_skill_list_frame_open"]) == "function" and g.settings.other_character_skill_list.use ==
        1 then
        rbtn_action = "other_character_skill_list_frame_open"
        table.insert(tooltip_parts, "Right-Click: [OCSL] Open")
    end
    ccbtn:SetEventScript(ui.LBUTTONUP, lbtn_action)
    if rbtn_action then
        ccbtn:SetEventScript(ui.RBUTTONUP, rbtn_action)
    end
    local default_tooltip = g.lang == "Japanese" and "{ol}バラックに戻ります" or "{ol}Return to Barracks"
    ccbtn:SetTextTooltip(#tooltip_parts > 0 and "{ol}" .. table.concat(tooltip_parts, "{nl}") or default_tooltip)
    return 115 -- 次のボタンを開始するX座標を返す
end

function Indun_panel_create_shortcut_button(indun_panel, key_name, x)
    local account_obj = GetMyAccountObj()
    local coin_count = 0
    local tooltip_msg = ""
    local btn = nil
    if key_name == "tos" and g.get_map_type() == "City" then
        btn = indun_panel:CreateOrGetControl("button", "tos", x + 2, 8, 25, 25)
        btn:SetText("{img icon_item_Tos_Event_Coin 25 25}")
        tooltip_msg = g.lang == "Japanese" and "{ol}TOSイベントショップ" or "{ol}TOS Event Shop"
        btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_event_tos_whole_shop_open")
    elseif key_name == "gabija" and g.get_map_type() == "City" then
        btn = indun_panel:CreateOrGetControl("button", "gabija", x, 7, 29, 29)
        btn:SetText("{img goddess_shop_btn 29 29}")
        coin_count = GET_COMMAED_STRING(TryGetProp(account_obj, "GabijaCertificate", "0"))
        tooltip_msg =
            (g.lang == "Japanese" and "{ol}ガビヤショップ{nl}" or "{ol}Gabija Shop{nl}") .. "{#FFFF00}" ..
                coin_count
        btn:SetEventScript(ui.LBUTTONUP, "REQ_GabijaCertificate_SHOP_OPEN")
    elseif key_name == "vakarine" and g.get_map_type() == "City" then
        btn = indun_panel:CreateOrGetControl("button", "vakarine", x, 7, 29, 29)
        btn:SetText("{img goddess2_shop_btn 29 29}")
        coin_count = GET_COMMAED_STRING(TryGetProp(account_obj, "VakarineCertificate", "0"))
        tooltip_msg = (g.lang == "Japanese" and "{ol}ヴァカリネショップ{nl}" or "{ol}Vakarine Shop{nl}") ..
                          "{#FFFF00}" .. coin_count
        btn:SetEventScript(ui.LBUTTONUP, "REQ_VakarineCertificate_SHOP_OPEN")
    elseif key_name == "rada" and g.get_map_type() == "City" then
        btn = indun_panel:CreateOrGetControl("button", "rada", x, 8, 29, 29)
        btn:SetText("{img goddess3_shop_btn 29 29}")
        coin_count = GET_COMMAED_STRING(TryGetProp(account_obj, "RadaCertificate", "0"))
        tooltip_msg = (g.lang == "Japanese" and "{ol}ラダショップ{nl}" or "{ol}Rada Shop{nl}") .. "{#FFFF00}" ..
                          coin_count
        btn:SetEventScript(ui.LBUTTONUP, "REQ_RadaCertificate_SHOP_OPEN")
    elseif key_name == "jurate" and g.get_map_type() == "City" then
        btn = indun_panel:CreateOrGetControl("button", "jurate", x, 7, 29, 29)
        btn:SetText("{img goddess4_shop_btn 29 29}")
        coin_count = GET_COMMAED_STRING(TryGetProp(account_obj, "JurateCertificate", "0"))
        tooltip_msg =
            (g.lang == "Japanese" and "{ol}ユラテショップ{nl}" or "{ol}Jurate Shop{nl}") .. "{#FFFF00}" ..
                coin_count
        btn:SetEventScript(ui.LBUTTONUP, "REQ_JurateCertificate_SHOP_OPEN")
    elseif key_name == "austeja" then
        btn = indun_panel:CreateOrGetControl("button", "austeja", x, 7, 29, 29)
        btn:SetText("{img goddess5_shop_btn 29 29}")
        coin_count = GET_COMMAED_STRING(TryGetProp(account_obj, "AustejaCertificate", "0"))
        tooltip_msg = (g.lang == "Japanese" and "{ol}アウステヤショップ{nl}" or "{ol}Austeja Shop{nl}") ..
                          "{#FFFF00}" .. coin_count
        btn:SetEventScript(ui.LBUTTONUP, "REQ_AustejaCertificate_SHOP_OPEN")
    elseif key_name == "pvp_mine" then
        btn = indun_panel:CreateOrGetControl("button", "pvp_mine", x, 7, 29, 29)
        btn:SetText("{img pvpmine_shop_btn_total 29 29}")
        tooltip_msg = g.lang == "Japanese" and "{ol}傭兵団ショップ" or "{ol}Mercenary Shop"
        btn:SetEventScript(ui.LBUTTONUP, "MINIMIZED_PVPMINE_SHOP_BUTTON_CLICK")
    elseif key_name == "market" and g.get_map_type() == "City" then
        btn = indun_panel:CreateOrGetControl("button", "market", x, 6, 29, 29)
        btn:SetText("{img market_shortcut_btn02 29 29}")
        tooltip_msg = g.lang == "Japanese" and "{ol}マーケット" or "{ol}Market"
        btn:SetEventScript(ui.LBUTTONUP, "MINIMIZED_MARKET_BUTTON_CLICK")
    elseif key_name == "craft" and g.get_map_type() == "City" then
        btn = indun_panel:CreateOrGetControl("button", "craft", x, 5, 29, 29)
        btn:SetText("{img icon_fullscreen_menu_equipment_processing 28 28}")
        tooltip_msg = g.lang == "Japanese" and "{ol}装備加工" or "{ol}Equipment Processing"
        btn:SetEventScript(ui.LBUTTONUP, "FULLSCREEN_NAVIGATION_MENU_DEATIL_EQUIPMENT_PROCESSING_NPC")
    elseif key_name == "leticia" and g.get_map_type() == "City" then
        btn = indun_panel:CreateOrGetControl("button", "leticia", x, 5, 29, 29)
        btn:SetText("{img icon_fullscreen_menu_letica 28 28}")
        tooltip_msg = g.lang == "Japanese" and "{ol}レティーシャへ移動" or "{ol}Leticia Move"
        btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_FULLSCREEN_NAVIGATION_MENU_DETAIL_MOVE_NPC")
        btn:SetEventScriptArgNumber(ui.LBUTTONUP, 309)
    end
    if btn then
        AUTO_CAST(btn)
        btn:SetSkinName("None")
        btn:SetTextTooltip(tooltip_msg)
        btn:SetEventScript(ui.LBUTTONDOWN, "Indun_panel_earthtowershop_close_restart")
        return true -- ボタンが作成された
    end
    return false -- ボタンが作成されなかった
end

function Indun_panel_event_tos_whole_shop_open()
    local earthtowershop = ui.GetFrame("earthtowershop")
    earthtowershop:SetUserValue("SHOP_TYPE", 'EVENT_TOS_WHOLE_SHOP')
    ui.OpenFrame('earthtowershop')
end

function Indun_panel_FULLSCREEN_NAVIGATION_MENU_DETAIL_MOVE_NPC(frame, ctrl, str, guid)
    if g.get_map_type() ~= "City" then
        return
    end
    local cls = GetClassByType("full_screen_navigation_menu", guid)
    if cls then
        local name = TryGetProp(cls, "Name", "None")
        local move_zone_select = TryGetProp(cls, "MoveZoneSelect", "NO")
        local move_zone = TryGetProp(cls, "MoveZone", "None")
        local move_npc_dialog = TryGetProp(cls, "MoveNpcDialog", "None")
        local move_zone_select_msg = TryGetProp(cls, "MoveZoneSelectMsg", "None")
        local move_only_in_town = TryGetProp(cls, "MoveOnlyInTown", "None")
        if move_zone ~= "None" and move_npc_dialog ~= "None" then
            local pc = GetMyPCObject()
            if session.world.IsIntegrateServer() == true or IsPVPField(pc) == 1 or IsPVPServer(pc) == 1 then
                ui.SysMsg(ScpArgMsg("ThisLocalUseNot"))
                return
            end
            if world.GetLayer() ~= 0 then
                ui.SysMsg(ScpArgMsg("ThisLocalUseNot"))
                return
            end
            if g.get_map_type() == "Dungeon" then
                ui.SysMsg(ScpArgMsg("ThisLocalUseNot"))
                return
            end
            local cur_map = GetClass("Map", session.GetMapName())
            if cur_map then
                local zone_keyword = TryGetProp(cur_map, 'Keyword', 'None')
                local keyword_table = StringSplit(zone_keyword, '')
                if table.find(keyword_table, 'IsRaidField') > 0 or table.find(keyword_table, 'WeeklyBossMap') > 0 then
                    ui.SysMsg(ScpArgMsg('ThisLocalUseNot'))
                    return
                end
                FullScreenMenuMoveNpc(name, move_zone_select, move_zone, move_npc_dialog, move_zone_select_msg,
                    move_only_in_town)
                ui.CloseFrame("fullscreen_navigation_menu")
            end
        end
    end
end

function Indun_panel_earthtowershop_close_restart()
    local earthtowershop = ui.GetFrame('earthtowershop')
    if earthtowershop:IsVisible() == 1 then
        earthtowershop:Resize(580, 1920)
        ui.CloseFrame("earthtowershop")
        return 0
    else
        earthtowershop:Resize(580, 1920)
        return 1
    end
end

function Indun_panel_always_init(indun_panel, ctrl, str)
    if str == "OPEN" then
        g.indun_panel_settings.etc.always_open = 1
        Indun_panel_frame_open(indun_panel)
    else
        g.indun_panel_settings.etc.always_open = 0
        Indun_panel_frame_init()
    end
    Indun_panel_save_settings()
end

function Indun_panel_frame_toggle(indun_panel)
    if indun_panel:GetHeight() > 40 then
        Indun_panel_frame_init(true)
    else
        Indun_panel_frame_open(indun_panel)
    end
end

function Indun_panel_frame_open(indun_panel)
    -- 展開表示で使う PVP_MINE 購入可能数は ssn_shop(セッションのショップ値)に入るため、
    -- セッション中まだ同期していなければ、ここで一度だけショップを開いて取得する。
    -- (取得は非同期。完了時に Indun_panel_earthtowershop_close が展開中パネルを再描画し、
    --  そこで synced を立てる)。syncing は開始〜完了間のガードで、二重にショップを開かない。
    -- 空振り(ショップフレーム未取得)時は何も立てず次回展開で再試行する。
    if not g.indun_panel_mine_synced and not g.indun_panel_mine_syncing and Indun_panel_sync_mine_shop() then
        g.indun_panel_mine_syncing = true
    end
    indun_panel:RemoveAllChild()
    Indun_panel_setup_frame(indun_panel)
    local btn = indun_panel:CreateOrGetControl("button", "btn", 5, 5, 80, 30)
    AUTO_CAST(btn)
    btn:SetText("{ol}{s10}INDUNPANEL")
    btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_frame_toggle")
    btn:SetEventScript(ui.RBUTTONUP, "Indun_panel_always_init")
    btn:SetTextTooltip(g.lang == "Japanese" and "{ol}右クリック: 常時展開解除で閉じる" or
                           "{ol}Right click: Close with permanent unexpand")
    local x = Indun_panel_create_common_buttons(indun_panel)
    local configbtn = indun_panel:CreateOrGetControl('button', 'configbtn', x, 5, 30, 30)
    AUTO_CAST(configbtn)
    configbtn:SetSkinName("None")
    configbtn:SetText("{img config_button_normal 30 30}")
    configbtn:SetEventScript(ui.LBUTTONUP, "Indun_panel_setting_frame_open")
    configbtn:SetTextTooltip(g.lang == "Japanese" and "{ol}Indun Panel 設定" or "{ol}Indun Panel Config")
    x = x + 30
    local button_keys = {"tos", "gabija", "vakarine", "rada", "jurate", "austeja", "pvp_mine", "market", "craft",
                         "leticia"}
    for _, key_name in ipairs(button_keys) do
        local value = g.indun_panel_settings.cols[key_name]
        if value == 1 then
            if Indun_panel_create_shortcut_button(indun_panel, key_name, x) then
                x = x + 30
            end
        end
    end
    local current_x = x + 10 -- SET A の開始位置
    for _, item in ipairs(g.indun_panel_settings.set_names) do
        for key, name in pairs(item) do
            local btn = indun_panel:CreateOrGetControl("button", key, current_x, 5, 80, 30)
            AUTO_CAST(btn)
            btn:Resize(80, 30)
            btn:SetText("{ol}" .. name)
            btn:Resize(80, 30)
            btn:AdjustFontSizeByWidth(80)
            btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_set_toggle")
            btn:SetEventScriptArgString(ui.LBUTTONUP, key) -- "set_a" を渡す
            btn:SetEventScriptArgNumber(ui.LBUTTONUP, 0) -- 0 を渡す (ArgNumberにする)
            if g.indun_panel_settings.etc.use_set == key then
                btn:SetSkinName("test_red_button")
            end
            current_x = current_x + 85
        end
    end
    local always_open = indun_panel:CreateOrGetControl('checkbox', 'always_open', 710, 5, 30, 30)
    AUTO_CAST(always_open)
    always_open:SetCheck(g.indun_panel_settings.etc.always_open)
    always_open:SetEventScript(ui.LBUTTONUP, "Indun_panel_ischecked")
    always_open:SetTextTooltip(g.lang == "Japanese" and "{ol}チェックすると常時展開" or
                                   "{ol}IsCheck AlwaysOpen")
    local function indun_panel_FIELD_BOSS_TIME_TAB_SETTING()
        local induninfo = ui.GetFrame("induninfo")
        local field_boss_ranking_control = GET_CHILD_RECURSIVELY(induninfo, "field_boss_ranking_control")
        local sub_tab = GET_CHILD_RECURSIVELY(field_boss_ranking_control, "sub_tab")
        local server_time_str = date_time.get_lua_now_datetime_str()
        local _, _, _, hour_str, min_str, _ = server_time_str:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
        local server_hour = tonumber(hour_str)
        local server_min = tonumber(min_str)
        if (server_hour < 12) or (server_hour == 12 and server_min < 5) then
            sub_tab:SelectTab(0)
        else
            sub_tab:SelectTab(1)
        end
    end
    local current_set = g.indun_panel_settings.etc.use_set
    if g.indun_panel_settings[current_set] and g.indun_panel_settings[current_set].jsr == 1 then
        indun_panel_FIELD_BOSS_TIME_TAB_SETTING()
    end
    local final_x = current_x + 30
    indun_panel:Resize(final_x, 40)
    indun_panel:ShowWindow(1)
    Indun_panel_frame_contents(configbtn)
    configbtn:RunUpdateScript("Indun_panel_frame_contents", 1.0)
end

function Indun_panel_set_toggle(indun_panel, ctrl, set_key, num)
    g.indun_panel_settings.etc.use_set = set_key
    Indun_panel_save_settings()
    if num == 1 then
        Indun_panel_setting_frame_open()
    else
        Indun_panel_frame_open(indun_panel)
    end
end

function Indun_panel_ischecked(indun_panel, ctrl)
    local ischeck = ctrl:IsChecked()
    local ctrlname = ctrl:GetName()
    local current_set = g.indun_panel_settings.etc.use_set
    local use_tbl = g.indun_panel_settings[current_set]
    if use_tbl and use_tbl[ctrlname] then
        use_tbl[ctrlname] = ischeck
    elseif g.indun_panel_settings.cols then
        if g.indun_panel_settings.cols[ctrlname] then
            g.indun_panel_settings.cols[ctrlname] = ischeck
        end
    end
    if g.indun_panel_settings.etc[ctrlname] then
        g.indun_panel_settings.etc[ctrlname] = ischeck
    end
    if ctrlname == "move" then
        local enable = g.indun_panel_settings.etc.move == 0 and 1 or 0
        indun_panel:EnableMove(enable)
        indun_panel:EnableHittestFrame(enable)
    end
    Indun_panel_save_settings()
end

function Indun_panel_setting_frame_open() -- Indun_list_viewer_save_current_char_counts()
    local indun_panel = ui.GetFrame(addon_name_lower .. "indun_panel")
    indun_panel:SetSkinName("test_frame_low")
    indun_panel:SetLayerLevel(90)
    indun_panel:EnableHittestFrame(1)
    indun_panel:SetAlpha(100)
    indun_panel:RemoveAllChild()
    indun_panel:ShowWindow(1)
    local close = indun_panel:CreateOrGetControl('button', 'close', 0, 0, 30, 30)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Indun_panel_frame_init")
    local btn = indun_panel:CreateOrGetControl("button", "btn", 5, 5, 80, 30)
    AUTO_CAST(btn)
    btn:SetText("{ol}{s10}INDUNPANEL")
    btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_frame_init")
    local position = indun_panel:CreateOrGetControl("button", "position", 90, 5, 60, 30)
    AUTO_CAST(position)
    position:SetText("{ol}{s10}BASE POS")
    position:SetEventScript(ui.LBUTTONUP, "Indun_panel_frame_base_position")
    position:SetTextTooltip(g.lang == "Japanese" and "{ol}ボタンを元の位置に戻す" or "Reset button position")
    local x = 200
    for _, item in ipairs(g.indun_panel_settings.set_names) do
        for key, name in pairs(item) do
            local btn = indun_panel:CreateOrGetControl("button", name .. key, x, 5, 80, 30)
            AUTO_CAST(btn)
            btn:Resize(80, 30)
            btn:SetText("{ol}" .. name)
            btn:Resize(80, 30)
            btn:AdjustFontSizeByWidth(80)
            btn:SetTextTooltip(g.lang == "Japanese" and
                                   "{ol}左クリック: セット選択{nl}右クリック: セット名変更" or
                                   "{ol}Left Click: Select Set{nl}Right Click: Change Set Name")
            btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_set_toggle")
            btn:SetEventScriptArgString(ui.LBUTTONUP, key)
            btn:SetEventScriptArgNumber(ui.LBUTTONUP, 1)
            btn:SetEventScript(ui.RBUTTONUP, "Indun_panel_INPUT_STRING_BOX")
            btn:SetEventScriptArgString(ui.RBUTTONUP, key)
            if g.indun_panel_settings.etc.use_set == key then
                btn:SetSkinName("test_red_button")
            end
            x = x + 85
        end
    end
    local skin_change = indun_panel:CreateOrGetControl("button", "skin_change", 470, 5, 80, 30)
    AUTO_CAST(skin_change)
    local skin_text = g.lang == "Japanese" and "{ol}フレームスキン選択" or "{ol}Select Frame Skin"
    skin_change:SetEventScript(ui.LBUTTONUP, "Indun_panel_frame_skin_select")
    skin_change:SetText("{ol}SKIN SELECT")
    skin_change:SetTextTooltip(skin_text)
    local shortcut_icons = {{ -- ショートカットアイコンのチェックボックス作成をループ処理に
        name = "tos",
        img = "icon_item_Tos_Event_Coin",
        size = 25
    }, {
        name = "gabija",
        img = "goddess_shop_btn",
        size = 29
    }, {
        name = "vakarine",
        img = "goddess2_shop_btn",
        size = 29
    }, {
        name = "rada",
        img = "goddess3_shop_btn",
        size = 29
    }, {
        name = "jurate",
        img = "goddess4_shop_btn",
        size = 29
    }, {
        name = "austeja",
        img = "goddess5_shop_btn",
        size = 29
    }, {
        name = "pvp_mine",
        img = "pvpmine_shop_btn_total",
        size = 29
    }, {
        name = "market",
        img = "market_shortcut_btn02",
        size = 29
    }, {
        name = "craft",
        img = "icon_fullscreen_menu_equipment_processing",
        size = 28
    }, {
        name = "leticia",
        img = "icon_fullscreen_menu_letica",
        size = 28
    }}
    local config_x = 15
    local tooltip_always_show = g.lang == "Japanese" and "{ol}チェックすると常に表示" or
                                    "{ol}Always visible when checked"
    for _, icon_info in ipairs(shortcut_icons) do
        local checkbox = indun_panel:CreateOrGetControl("checkbox", icon_info.name, config_x, 47, icon_info.size,
            icon_info.size)
        AUTO_CAST(checkbox)
        checkbox:SetText(string.format("{img %s %d %d}", icon_info.img, icon_info.size, icon_info.size))
        checkbox:SetEventScript(ui.LBUTTONUP, "Indun_panel_ischecked")
        checkbox:SetEventScriptArgString(ui.LBUTTONUP, "config")
        checkbox:SetTextTooltip(tooltip_always_show)
        local is_checked = 0
        for k, v in pairs(g.indun_panel_settings.cols) do
            if k == icon_info.name then
                is_checked = v
                break
            end
        end
        checkbox:SetCheck(is_checked)
        config_x = config_x + checkbox:GetWidth() + 5
    end
    local label_line2 = indun_panel:CreateControl('labelline', 'label_line2', 10, 77, config_x, 5)
    AUTO_CAST(label_line2)
    label_line2:SetSkinName("labelline2")
    local other_settings = {{ -- その他の設定チェックボックス作成をループ処理に
        name = "en_ver",
        y = 85,
        jp = "チェックすると英語表示に変更します",
        en = "Check to display to English"
    }, {
        name = "move",
        y = 120,
        jp = "チェックするとフレームを固定",
        en = "Check to fixes the frame"
    }, {
        name = "field_mode",
        y = 155,
        jp = "チェックするとフィールドで表示",
        en = "Check to display in field"
    }, {
        name = "shading",
        y = 190,
        jp = "チェックすると網掛け表示",
        en = "Check to display shading"
    }}
    for _, setting_info in ipairs(other_settings) do
        local checkbox = indun_panel:CreateOrGetControl('checkbox', setting_info.name, 25, setting_info.y, 25, 25)
        AUTO_CAST(checkbox)
        checkbox:SetCheck(g.indun_panel_settings.etc[setting_info.name])
        checkbox:SetEventScript(ui.LBUTTONUP, "Indun_panel_ischecked")
        checkbox:SetText(g.lang == "Japanese" and "{ol}" .. setting_info.jp or "{ol}" .. setting_info.en)
    end
    local label_line = indun_panel:CreateControl('labelline', 'label_line', 10, 215, config_x, 5)
    AUTO_CAST(label_line)
    label_line:SetSkinName("labelline2")
    local posy_left = 220
    local posy_right = 220
    local count = #induns
    local half_count = math.ceil(count / 2)
    local current_set = g.indun_panel_settings.etc.use_set
    local use_tbl = g.indun_panel_settings[current_set]
    for i = 1, count do
        local entry = induns[i]
        for key, value in pairs(entry) do
            local checkbox
            if i <= half_count then
                checkbox = indun_panel:CreateOrGetControl('checkbox', key, 15, posy_left, 25, 25)
                AUTO_CAST(checkbox)
                posy_left = posy_left + 35
            else
                checkbox = indun_panel:CreateOrGetControl('checkbox', key, 325, posy_right, 25, 25)
                AUTO_CAST(checkbox)
                posy_right = posy_right + 35
            end
            local is_checked = use_tbl[key]
            if is_checked == nil then
                is_checked = 0
            end
            checkbox:SetCheck(is_checked)
            checkbox:SetEventScript(ui.LBUTTONUP, "Indun_panel_ischecked")
            local bool = g.indun_panel_settings.etc.en_ver == 0 and g.lang == "Japanese"
            local display_name = key
            if bool and value.jp then
                display_name = value.jp
            end
            checkbox:SetText(bool and "{ol}{#FFFFFF}{s16}" .. display_name or "{ol}{#FFFFFF}{s20}" .. key)
            checkbox:SetTextTooltip(g.lang == "Japanese" and "チェックすると表示" or "Check to show")
        end
    end
    local final_height = math.max(posy_left, posy_right)
    indun_panel:Resize(660, final_height + 5)
end

function Indun_panel_frame_base_position(indun_panel)
    indun_panel:SetPos(665, 30)
    g.indun_panel_settings.etc.x = 665
    g.indun_panel_settings.etc.y = 30
    Indun_panel_save_settings()
end

function Indun_panel_INPUT_STRING_BOX(frame, ctrl, set_key, num)
    local inputstring = ui.GetFrame("inputstring")
    inputstring:Resize(500, 220)
    inputstring:SetLayerLevel(999)
    local edit = GET_CHILD(inputstring, 'input', "ui::CEditControl")
    edit:SetNumberMode(0)
    edit:SetMaxLen(999)
    edit:SetText("")
    inputstring:ShowWindow(1)
    inputstring:SetEnable(1)
    local title = inputstring:GetChild("title")
    AUTO_CAST(title)
    local text = g.lang == "Japanese" and "{ol}{#FFFFFF}セット名を入力" or "{ol}{#FFFFFF}Enter set name"
    title:SetText(text)
    local confirm = inputstring:GetChild("confirm")
    confirm:SetEventScript(ui.LBUTTONUP, "Indun_panel_save_setname")
    confirm:SetEventScriptArgString(ui.LBUTTONUP, set_key)
    edit:SetEventScript(ui.ENTERKEY, "Indun_panel_save_setname")
    edit:SetEventScriptArgString(ui.ENTERKEY, set_key)
    edit:AcquireFocus()
end

function Indun_panel_save_setname(inputstring, ctrl, set_key, num)
    inputstring:ShowWindow(0)
    local edit = GET_CHILD(inputstring, 'input')
    local get_text = edit:GetText()
    if get_text == "" then
        local text = g.lang == "Japanese" and "{ol}文字を入力してください" or "{ol}Please enter text"
        ui.SysMsg(text)
        Indun_panel_INPUT_STRING_BOX(nil, nil, set_key, 0)
        return
    end
    local text = g.lang == "Japanese" and "{ol}セット名を登録しました" or "{ol}Set name registered"
    ui.SysMsg(text)
    for _, item in ipairs(g.indun_panel_settings.set_names) do
        if item[set_key] then
            item[set_key] = get_text
            break
        end
    end
    Indun_panel_save_settings()
    Indun_panel_setting_frame_open()
end

function Indun_panel_frame_skin_select()
    local context = ui.CreateContextMenu("indun_panel_skin_select", "{ol}Skin Select", 0, 0, 0, 0)
    ui.AddContextMenuItem(context, " ")
    local skin_tbl = {"chat_window_2", "bg", "bg2"}
    for _, skin_name in ipairs(skin_tbl) do
        local str_scp
        str_scp = string.format("Indun_panel_frame_skin_select_('%s')", skin_name)
        local text
        if skin_name == "chat_window_2" then
            text = g.lang == "Japanese" and "{ol}いつもの" or "The usual"
        elseif skin_name == "bg" then
            text = g.lang == "Japanese" and "{ol}黒" or "Solid black"
        elseif skin_name == "bg2" then
            text = g.lang == "Japanese" and "{ol}透明度高め" or "High transparency"
        end
        ui.AddContextMenuItem(context, text, str_scp)
    end
    ui.OpenContextMenu(context)
end

function Indun_panel_frame_skin_select_(skin_name)
    g.indun_panel_settings.etc.skin_name = skin_name
    Indun_panel_save_settings()
    local indun_panel = ui.GetFrame(addon_name_lower .. "indun_panel")
    Indun_panel_frame_open(indun_panel)
end

function Indun_panel_frame_contents(configbtn)
    local indun_panel = ui.GetFrame(addon_name_lower .. "indun_panel")
    local shop_buttons = {"gabija", "vakarine", "rada", "jurate", "austeja"}
    local shop_props = {"GabijaCertificate", "VakarineCertificate", "RadaCertificate", "JurateCertificate",
                        "AustejaCertificate"}
    local shop_names_jp = {"ガビヤショップ", "ヴァカリネショップ", "ラダショップ",
                           "ユラテショップ", "アウステヤショップ"}
    local shop_names_en = {"Gabija Shop", "Vakarine Shop", "Rada Shop", "Jurate Shop", "Austeja Shop"}
    local account_obj = GetMyAccountObj()
    for i, btn_name in ipairs(shop_buttons) do
        local btn = GET_CHILD_RECURSIVELY(indun_panel, btn_name)
        if btn then
            AUTO_CAST(btn)
            local count = GET_COMMAED_STRING(TryGetProp(account_obj, shop_props[i], "0"))
            local name = g.lang == "Japanese" and shop_names_jp[i] or shop_names_en[i]
            local tooltip = string.format("{ol}%s{nl}{#FFFF00}%s", name, count)
            btn:SetTextTooltip(tooltip)
        end
    end
    local prefix = "DD"
    if g.indun_panel_settings.etc.skin_name and g.indun_panel_settings.etc.skin_name == "bg" then
        prefix = "FF"
    end
    local x = 150
    local current_set = g.indun_panel_settings.etc.use_set
    local use_tbl = g.indun_panel_settings[current_set]
    if not use_tbl then
        return 1
    end
    local y = 40
    local index = 1
    local index_remainder = 0
    local lasy_y = 0
    for i, entry in ipairs(induns) do
        local key, value = next(entry)
        if use_tbl[key] == 1 then
            if g.indun_panel_settings.etc.shading == 1 then
                local line = indun_panel:CreateOrGetControl("picture", "line" .. key, 5, y - 2, 740, 33)
                AUTO_CAST(line)
                line:SetImage("fullwhite")
                line:SetEnableStretch(1)
                line:EnableHitTest(0)
                local tone = (index % 2 == 1) and "696969" or "A9A9A9"
                line:SetColorTone(prefix .. tone)
            end
            if key == "jsr" or value.icon then
                local img_icon = indun_panel:CreateOrGetControl("picture", "img_icon" .. key, x - 140, y + 5, 20, 20)
                AUTO_CAST(img_icon)
                local icon_cls = nil
                if key == "jsr" then
                    local fieldbossPattern = session.fieldboss.GetPatternInfo()
                    local icon_cls_name = fieldbossPattern.MonsterClassName
                    icon_cls = GetClass("Monster", icon_cls_name)
                elseif value.icon then
                    icon_cls = GetClassByType(value.icon[1], value.icon[2])
                end
                if icon_cls then
                    img_icon:SetImage(icon_cls.Icon)
                    img_icon:SetEnableStretch(1)
                    img_icon:EnableHitTest(0)
                end
                local text = indun_panel:CreateOrGetControl("richtext", key, x - 120, y + 5)
                local is_jp_mode = (g.indun_panel_settings.etc.en_ver == 0 and g.lang == "Japanese")
                local display_name = key
                if is_jp_mode and value.jp then
                    display_name = value.jp
                end
                local font_tag = is_jp_mode and "{s16}" or "{s20}"
                text:SetText(string.format("{ol}{#FFFFFF}%s%s", font_tag, display_name))
                index = index + 1
                if key == "challenge" then
                    local tooltip = g.lang == "Japanese" and
                                        "{ol}左クリック: チャレンジマップの1週間分のスケジュール表示" or
                                        "{ol}Left Click: Display the schedule for one week of the Challenge Map"
                    img_icon:EnableHitTest(1)
                    img_icon:SetEventScript(ui.LBUTTONUP, "Indun_panel_challenge_map_context")
                    img_icon:SetTextTooltip(tooltip)
                    text:EnableHitTest(1)
                    text:SetEventScript(ui.LBUTTONUP, "Indun_panel_challenge_map_context")
                    text:SetTextTooltip(tooltip)
                end
                text:AdjustFontSizeByWidth(120)
            end
            if type(value) == "table" then
                if key == "challenge" then
                    for sub_key, sub_value in pairs(value) do
                        if sub_key ~= "jp" and sub_key ~= "icon" then
                            Indun_panel_challenge_frame(indun_panel, key, sub_key, sub_value, y, x)
                        end
                    end
                elseif key == "singularity" then
                    for sub_key, sub_value in pairs(value) do
                        if sub_key ~= "jp" and sub_key ~= "icon" then
                            Indun_panel_singularity_frame(indun_panel, key, sub_key, sub_value, y, x)
                        end
                    end
                elseif key == "zmei" or key == "belliora" or key == "laimara" or key == "ledania" or key == "neringa" or
                    key == "golem" or key == "merregina" or key == "slogutis" or key == "upinis" or key == "roze" or
                    key == "falouros" or key == "reservoir" then -- レイド系 (onsweep)
                    for sub_key, sub_value in pairs(value) do
                        if sub_key ~= "jp" and sub_key ~= "icon" then
                            Indun_panel_create_frame_onsweep(indun_panel, key, sub_key, sub_value, y, x)
                        end
                    end
                elseif key == "jellyzele" or key == "delmore" or key == "giltine" or key == "memory" then -- 通常ダンジョン系 (create_frame)
                    for sub_key, sub_value in pairs(value) do
                        if sub_key ~= "jp" and sub_key ~= "icon" then
                            Indun_panel_create_frame(indun_panel, key, sub_key, sub_value, y, x)
                        end
                    end
                elseif key == "telharsha" then
                    Indun_panel_telharsha_frame(indun_panel, key, value.id, y, x)
                elseif key == "bernice" then
                    Indun_panel_velnice_frame(indun_panel, key, value.id, y, x)
                elseif key == "wailing" then
                    Indun_panel_cemetery_frame(indun_panel, key, value.id, y, x)
                elseif key == "ashaq" then
                    Indun_panel_demonlair_frame(indun_panel, key, value.id, y, x)
                elseif key == "jsr" then
                    Indun_panel_jsr_frame(indun_panel, y, x)
                end
            end
            y = y + 33
        end
        index_remainder = index % 2
        lasy_y = y
    end
    local y = lasy_y or 40
    local status, err = pcall(Indun_panel_create_currency_display, indun_panel, y)
    if not status then
        print("[IndunPanel] Currency Display Error: " .. tostring(err))
    end
    y = y + 40
    if g.indun_panel_settings.etc.shading == 1 then
        local line = indun_panel:CreateOrGetControl("picture", "last_line", 5, y - 2, 740, 33)
        AUTO_CAST(line)
        line:SetImage("fullwhite")
        line:SetEnableStretch(1)
        line:EnableHitTest(0)
        line:SetColorTone(prefix .. (index_remainder == 1 and "696969" or "A9A9A9"))
    end
    indun_panel:SetLayerLevel(80)
    indun_panel:Resize(x + 600, y)
    indun_panel:SetSkinName(g.indun_panel_settings.etc.skin_name or "chat_window_2")
    indun_panel:EnableHitTest(1)
    indun_panel:SetAlpha(100)
    return 1
end

function Indun_panel_create_currency_display(indun_panel, y)
    local account_obj = GetMyAccountObj()
    local bonusTP_pic = indun_panel:CreateOrGetControl("richtext", "bonusTP_pic", 320, y + 5)
    AUTO_CAST(bonusTP_pic)
    bonusTP_pic:SetText("{img bonusTP_pic 22 22}")
    local bonusTP_count = indun_panel:CreateOrGetControl("richtext", "bonusTP_count", 350, y + 5)
    AUTO_CAST(bonusTP_count)
    bonusTP_count:SetText("{ol}{#FFD900}{s18}" .. account_obj.Medal)
    bonusTP_count:SetTextTooltip("{ol}Free TP")
    local housing_btn = indun_panel:CreateOrGetControl("richtext", "housing_btn", 370, y + 5)
    AUTO_CAST(housing_btn)
    housing_btn:SetText("{img btn_housing_editmode_small_resize 23 23}")
    local housing_count = indun_panel:CreateOrGetControl("richtext", "housing_count", 400, y + 5)
    AUTO_CAST(housing_count)
    -- housing_count:SetText("{ol}{#FFD900}{s18}...")
    housing_count:SetTextTooltip("{ol}Housing Point")
    local current_time = imcTime.GetAppTime()
    if not g.indun_panel_housing_call_time or (current_time - g.indun_panel_housing_call_time) > 5 then
        g.indun_panel_housing_call_time = current_time
        Indun_panel_get_my_housing_point_callback_ready()
    elseif g.indun_panel_housing_point then
        housing_count:SetText("{ol}{#FFD900}{s18}" .. g.indun_panel_housing_point)
    end
    local tos_coin = indun_panel:CreateOrGetControl("richtext", "tos_coin", 450, y + 5)
    tos_coin:SetText("{img icon_item_Tos_Event_Coin 21 21}")
    local tos_coin_count = indun_panel:CreateOrGetControl("richtext", "tos_coin_count", 475, y + 5)
    local coin_count = GET_COMMAED_STRING(TryGetProp(account_obj, "EVENT_TOS_WHOLE_TOTAL_COIN", "0"))
    local target_coin = GET_COMMAED_STRING(g.indun_panel_settings.etc.toscoin or 0)
    tos_coin_count:SetText(string.format("{ol}{#FFD900}{s18}%s/{#FFD900}%s", coin_count, target_coin))
    local pvpmine = indun_panel:CreateOrGetControl("richtext", "pvpmine", 605, y + 5)
    pvpmine:SetText("{img pvpmine_shop_btn_total 25 25}")
    local pvpminecount = indun_panel:CreateOrGetControl("richtext", "pvpminecount", 630, y + 5)
    local mine_count = GET_COMMAED_STRING(TryGetProp(account_obj, "MISC_PVP_MINE2", "0"))
    pvpminecount:SetText(string.format("{ol}{#FFD900}{s18}%s", mine_count))
end

function Indun_panel_get_my_housing_point_callback_ready()
    local aidx = session.loginInfo.GetAID()
    GetMyHousingPageInfo("Indun_panel_get_my_housing_point_callback", aidx)
end

function Indun_panel_get_my_housing_point_callback(code, ret_json)
    if code ~= 200 or not ret_json or ret_json == "" then
        return
    end
    local status, parsed = pcall(json.decode, ret_json)
    if not (status and parsed) then
        return
    end
    if not parsed or type(parsed) ~= "table" then
        return
    end
    local housing_point = 0
    if parsed["pointInfo"] and parsed["pointInfo"]["personalHousing_Point1"] then
        housing_point = tonumber(parsed["pointInfo"]["personalHousing_Point1"]) or 0
    end
    g.indun_panel_housing_point = housing_point
    local indun_panel = ui.GetFrame(addon_name_lower .. "indun_panel")
    if indun_panel and indun_panel:IsVisible() == 1 then
        local housing_count = GET_CHILD_RECURSIVELY(indun_panel, "housing_count")
        if housing_count then
            housing_count:SetText("{ol}{#FFD900}{s18}" .. housing_point)
        end
    end
end

function Indun_panel_item_buy_use(recipe_name)
    local recipe_cls = GetClass("ItemTradeShop", recipe_name)
    if not recipe_cls then
        return
    end
    session.ResetItemList()
    session.AddItemID(tostring(0), 1)
    local itemlist = session.GetItemIDList()
    local cnt_text = string.format("%s %s", recipe_cls.ClassID, 1)
    if string.find(recipe_name, "EVENT_TOS", 1, true) then
        item.DialogTransaction("EVENT_TOS_WHOLE_SHOP", itemlist, cnt_text)
    else
        item.DialogTransaction("PVP_MINE_SHOP", itemlist, cnt_text)
    end
    local item_name = recipe_cls.TargetItem
    ReserveScript(string.format("Indun_panel_inv_item_use('%s')", item_name), 1.0)
end

function Indun_panel_inv_item_use(item_name)
    local item_cls = GetClass("Item", item_name)
    if item_cls then
        local inv_item = session.GetInvItemByType(item_cls.ClassID)
        if inv_item then
            INV_ICON_USE(inv_item)
        end
    end
end

function Indun_panel_get_entrance_count(indun_type, index)
    local indun_cls = GetClassByType("Indun", indun_type)
    if not indun_cls then
        return 0
    end
    local reset_type = indun_cls.PlayPerResetType
    local current_count = GET_CURRENT_ENTERANCE_COUNT(reset_type) or 0
    local max_count = GET_INDUN_MAX_ENTERANCE_COUNT(reset_type) or 0
    if index == 1 then
        return string.format("{ol}{#FFFFFF}{s16}(%s)", current_count)
    elseif index == 2 then
        return string.format("{ol}{#FFFFFF}{s16}(%s/%s)", current_count, max_count)
    elseif index == 3 then
        local count = 1
        local class_name = TryGetProp(indun_cls, 'ClassName', 'None')
        if string.find(class_name, 'Challenge_') then
            local ticket_type = TryGetProp(indun_cls, 'TicketingType', 'None')
            if ticket_type == 'Entrance_Ticket' then
                local check_name = TryGetProp(indun_cls, 'CheckCountName', 'None')
                local etc = GetMyEtcObject()
                if TryGetProp(etc, check_name, 0) == 1 then
                    count = 0
                end
            end
        end
        return string.format("{ol}{#FFFFFF}{s16}(%s/%s)", count, max_count)
    elseif index == 4 then
        if indun_type == 1001 then
            return current_count
        elseif indun_type == 1004 or indun_type == 1005 or indun_type == 2000 or indun_type == 2001 then
            local class_name = TryGetProp(indun_cls, 'ClassName', 'None')
            if string.find(class_name, 'Challenge_') then
                local unit_per_reset = TryGetProp(indun_cls, 'UnitPerReset', 'None')
                local check_name = TryGetProp(indun_cls, 'CheckCountName', 'None')
                if unit_per_reset ~= 'None' and check_name ~= 'None' then
                    if unit_per_reset == 'ACCOUNT' then
                        return TryGetProp(GetMyAccountObj(), check_name, 0) or 0
                    elseif unit_per_reset == 'PC' then
                        return TryGetProp(GetMyEtcObject(), check_name, 0) or 0
                    end
                end
            end
        end
        return 0
    end
    return 0
end

function Indun_panel_get_recipe_trade_count(recipe_name)
    local recipe_cls = GetClass("ItemTradeShop", recipe_name)
    if not recipe_cls then
        return 0
    end
    if recipe_cls.NeedProperty ~= "None" and recipe_cls.NeedProperty ~= "" then
        return TryGetProp(GetSessionObject(GetMyPCObject(), "ssn_shop"), recipe_cls.NeedProperty, 0)
    end
    if recipe_cls.AccountNeedProperty ~= "None" and recipe_cls.AccountNeedProperty ~= "" then
        return TryGetProp(GetMyAccountObj(), recipe_cls.AccountNeedProperty, 0)
    end
    return 0
end

function Indun_panel_overbuy_count(recipe_name)
    local account_obj = GetMyAccountObj()
    local recipe_cls = GetClass('ItemTradeShop', recipe_name)
    if not recipe_cls then
        return 0
    end
    local max_count = TryGetProp(recipe_cls, 'MaxOverBuyCount', 0)
    local prop_name = TryGetProp(recipe_cls, 'OverBuyProperty', 'None')
    local current_count = TryGetProp(account_obj, prop_name, 0)
    return tonumber(max_count) - tonumber(current_count)
end

function Indun_panel_overbuy_amount(recipe_name)
    local account_obj = GetMyAccountObj()
    local recipe_cls = GetClass('ItemTradeShop', recipe_name)
    if not recipe_cls then
        return 0
    end
    local trade_count = Indun_panel_get_recipe_trade_count(recipe_name)
    if trade_count > 0 then
        return 1000
    end
    local prop_name = TryGetProp(recipe_cls, 'OverBuyProperty', 'None')
    local current_overbuy_count = TryGetProp(account_obj, prop_name, 0)
    return 1050 + (current_overbuy_count * 50)
end

function Indun_panel_get_invitem_count(tbl)
    local count = 0
    local inv_item_list = session.GetInvItemList()
    local guid_list = inv_item_list:GetGuidList()
    local cnt = guid_list:Count()
    for i = 0, cnt - 1 do
        local guid = guid_list:Get(i)
        local inv_item = inv_item_list:GetItemByGuid(guid)
        if inv_item then
            local obj = GetIES(inv_item:GetObject())
            local item_id = obj.ClassID
            for _, class_id in ipairs(tbl) do
                if item_id == class_id then
                    count = count + inv_item.count
                    break
                end
            end
        end
    end
    return count
end

local CHALLENGE_CONFIG = {
    LOW = {
        expiring = {10820019, 11030080, 641954, 641955, 641969},
        non_expiring = {10000073, 10820028, 490363, 641953, 641963, 641987}
    },
    HIGH = {
        expiring = {11201299, 11201300, 10820052},
        non_expiring = {11201298, 11201297}
    }
}
function Indun_panel_challenge_frame(indun_panel, key, sub_key, indun_type, y, x)
    local low_indun_type = 1001
    local btn_low = indun_panel:CreateOrGetControl('button', "btn_low", x + 0, y, 50, 30)
    AUTO_CAST(btn_low)
    btn_low:SetText("{ol}520")
    btn_low:SetEventScript(ui.LBUTTONUP, "Indun_panel_enter_challenge")
    btn_low:SetEventScriptArgString(ui.LBUTTONUP, "1")
    btn_low:SetEventScriptArgNumber(ui.LBUTTONUP, low_indun_type)
    local txt_low = indun_panel:CreateOrGetControl("richtext", "txt_low", x + 50, y + 5, 40, 30)
    txt_low:SetText(Indun_panel_get_entrance_count(low_indun_type, 2))
    local buyuse_low = indun_panel:CreateOrGetControl('button', "buyuse_low", x + 90, y, 100, 30)
    AUTO_CAST(buyuse_low)
    local text_low = string.format("{ol}{#EE7800}USEor{s16}{img %s 15 15}{#FFFFFF}%s", "icon_item_Tos_Event_Coin",
        Indun_panel_get_recipe_trade_count("EVENT_TOS_WHOLE_SHOP_315") or 0)
    local count = Indun_panel_get_invitem_count(CHALLENGE_CONFIG.LOW.expiring)
    count = count + Indun_panel_get_invitem_count(CHALLENGE_CONFIG.LOW.non_expiring)
    local icon_text = ""
    local item_cls = GetClassByType('Item', CHALLENGE_CONFIG.LOW.expiring[1])
    if item_cls then
        local fmt = g.lang == "Japanese" and "{ol}{img %s 25 25 } %d枚持っています{nl} {nl}" or
                        "{ol}{img %s 25 25 } Quantity in Inventory: %d{nl} {nl}"
        icon_text = string.format(fmt, item_cls.Icon, count)
    end
    local tooltip_low = g.lang == "Japanese" and
                            "{ol}優先順位{nl}1.期限付き{nl}2.期限なし{nl}3.{img icon_item_Tos_Event_Coin 20 20}チケット(買って使います)" or
                            "{ol}Priority{nl}1.Expiring{nl}2.Non-expiring{nl}3.{img icon_item_Tos_Event_Coin 20 20}tickets(buy and use)"
    buyuse_low:SetTextTooltip(icon_text .. tooltip_low)
    buyuse_low:SetText(text_low)
    buyuse_low:SetEventScript(ui.LBUTTONUP, "Indun_panel_challenge_item_use")
    buyuse_low:SetEventScriptArgNumber(ui.LBUTTONUP, low_indun_type)
    local high_indun_type = 1004
    local high_pt_indun_type = 1005
    local btn_high = indun_panel:CreateOrGetControl('button', "btn_high", x + 195, y, 50, 30)
    AUTO_CAST(btn_high)
    btn_high:SetText("{ol}540")
    btn_high:SetEventScript(ui.LBUTTONUP, "Indun_panel_enter_challenge")
    btn_high:SetEventScriptArgString(ui.LBUTTONUP, "1")
    btn_high:SetEventScriptArgNumber(ui.LBUTTONUP, high_indun_type)
    local btn_high_pt = indun_panel:CreateOrGetControl('button', "btn_high_pt", x + 250, y, 50, 30)
    AUTO_CAST(btn_high_pt)
    btn_high_pt:SetText("{ol}{#FFD900}PT")
    btn_high_pt:SetEventScript(ui.LBUTTONUP, "Indun_panel_enter_challenge")
    btn_high_pt:SetEventScriptArgString(ui.LBUTTONUP, "2")
    btn_high_pt:SetEventScriptArgNumber(ui.LBUTTONUP, high_pt_indun_type)
    local txt_high = indun_panel:CreateOrGetControl("richtext", "txt_high", x + 300, y + 5, 40, 30)
    txt_high:SetText(Indun_panel_get_entrance_count(high_indun_type, 3))
    local buyuse_high_tos = indun_panel:CreateOrGetControl('button', "buyuse_high_tos", x + 340, y, 100, 30)
    AUTO_CAST(buyuse_high_tos)
    local count = Indun_panel_get_invitem_count(CHALLENGE_CONFIG.HIGH.expiring)
    count = count + Indun_panel_get_invitem_count(CHALLENGE_CONFIG.HIGH.non_expiring)
    local icon_text_high = ""
    local item_cls = GetClassByType('Item', CHALLENGE_CONFIG.HIGH.expiring[1])
    if item_cls then
        local fmt = g.lang == "Japanese" and "{ol}{img %s 25 25 } %d枚持っています{nl} {nl}" or
                        "{ol}{img %s 25 25 } Quantity in Inventory: %d{nl} {nl}"
        icon_text_high = string.format(fmt, item_cls.Icon, count)
    end
    local text_high_tos = string.format("{ol}{#EE7800}USEor{s16}{img %s 15 15}{#FFFFFF}%s", "icon_item_Tos_Event_Coin",
        Indun_panel_get_recipe_trade_count("EVENT_TOS_WHOLE_SHOP_320") or 0)
    local tooltip_high_tos = g.lang == "Japanese" and
                                 "{ol}左クリック: PT入場{nl}右クリック: ソロ入場{nl}優先順位{nl}1.期限付き{nl}2.{img icon_item_Tos_Event_Coin 20 20}チケット(買って使います){nl}3.期限なし" or
                                 "{ol}Left Click: PT Entry{nl}Right Click: Solo Entry{nl}Priority{nl}1.Expiring{nl}2.{img pvpmine_shop_btn_total 20 20}tickets(buy and use){nl}3.Non-expiring"
    buyuse_high_tos:SetText(text_high_tos)
    buyuse_high_tos:SetTextTooltip(icon_text_high .. tooltip_high_tos)
    buyuse_high_tos:SetEventScript(ui.LBUTTONUP, "Indun_panel_challenge_item_use")
    buyuse_high_tos:SetEventScriptArgString(ui.LBUTTONUP, "tos")
    buyuse_high_tos:SetEventScriptArgNumber(ui.LBUTTONUP, high_pt_indun_type)
    buyuse_high_tos:SetEventScript(ui.RBUTTONUP, "Indun_panel_challenge_item_use")
    buyuse_high_tos:SetEventScriptArgString(ui.RBUTTONUP, "tos")
    buyuse_high_tos:SetEventScriptArgNumber(ui.RBUTTONUP, high_indun_type)
    local buyuse_high_pvp = indun_panel:CreateOrGetControl('button', "buyuse_high_pvp", x + 450, y, 100, 30)
    AUTO_CAST(buyuse_high_pvp)
    local text_high_pvp = string.format("{ol}{#FFFFFF}USEor{s16}{img pvpmine_shop_btn_total 18 18}{#FFFFFF}%s",
        Indun_panel_get_recipe_trade_count("PVP_MINE_40") or 0)
    local tooltip_high_pvp = g.lang == "Japanese" and
                                 "{ol}左クリック: PT入場{nl}右クリック: ソロ入場{nl}優先順位{nl}1.期限付き{nl}2.{img pvpmine_shop_btn_total 20 20}チケット(買って使います){nl}3.期限なし" or
                                 "{ol}Left Click: PT Entry{nl}Right Click: Solo Entry{nl}Priority{nl}1.Expiring{nl}2.{img pvpmine_shop_btn_total 20 20}tickets(buy and use){nl}3.Non-expiring"
    buyuse_high_pvp:SetText(text_high_pvp)
    buyuse_high_pvp:SetTextTooltip(icon_text_high .. tooltip_high_pvp)
    buyuse_high_pvp:SetEventScript(ui.LBUTTONUP, "Indun_panel_challenge_item_use")
    buyuse_high_pvp:SetEventScriptArgString(ui.LBUTTONUP, "pvp")
    buyuse_high_pvp:SetEventScriptArgNumber(ui.LBUTTONUP, high_pt_indun_type)
    buyuse_high_pvp:SetEventScript(ui.RBUTTONUP, "Indun_panel_challenge_item_use")
    buyuse_high_pvp:SetEventScriptArgString(ui.RBUTTONUP, "pvp")
    buyuse_high_pvp:SetEventScriptArgNumber(ui.RBUTTONUP, high_indun_type)
end

function Indun_panel_challenge_item_use(indun_panel, ctrl, mode, indun_type)
    local entrance_count = Indun_panel_get_entrance_count(indun_type, 4)
    if indun_type == 1001 and entrance_count > 0 then -- 520は行ける場合0行けない場合1
        Indun_panel_process_ticket(indun_type, mode, CHALLENGE_CONFIG.LOW)
    elseif indun_type ~= 1001 and entrance_count == 0 then -- 540は行ける場合1行けない場合0
        Indun_panel_process_ticket(indun_type, mode, CHALLENGE_CONFIG.HIGH)
    end
end

function Indun_panel_process_ticket(indun_type, mode, config)
    local enter_mode = indun_type == 1005 and 2 or 1
    if Indun_panel_use_prioritized_ticket(config.expiring, enter_mode, indun_type) then
        return
    end
    local recipe_name = ""
    if indun_type == 1001 then
        recipe_name = "EVENT_TOS_WHOLE_SHOP_315"
    elseif mode == "tos" then
        recipe_name = "EVENT_TOS_WHOLE_SHOP_320"
    elseif mode == "pvp" then
        recipe_name = "PVP_MINE_40"
    end
    if Indun_panel_get_recipe_trade_count(recipe_name) >= 1 then
        Indun_panel_item_buy_use(recipe_name)
        Indun_panel_enter_reserve(enter_mode, indun_type)
        return
    end
    if Indun_panel_use_prioritized_ticket(config.non_expiring, enter_mode, indun_type) then
        return
    end
    if recipe_name == "PVP_MINE_40" then
        local account_obj = GetMyAccountObj()
        local recipe_cls = GetClass('ItemTradeShop', recipe_name)
        if recipe_cls then
            local over_max = TryGetProp(recipe_cls, 'MaxOverBuyCount', 0)
            local over_prop = TryGetProp(recipe_cls, 'OverBuyProperty', 'None')
            local over_count = TryGetProp(account_obj, over_prop, 0)
            if (tonumber(over_max) - tonumber(over_count)) > 0 then
                Indun_panel_item_buy_use(recipe_name)
                Indun_panel_enter_reserve(enter_mode, indun_type)
                return
            end
        end
    end
end

function Indun_panel_use_prioritized_ticket(ticket_ids, enter_mode, indun_type)
    local candidate_tickets = {}
    local use_item = nil
    for _, classid in ipairs(ticket_ids) do
        local inv_item = session.GetInvItemByType(classid)
        if inv_item then
            if not inv_item.isLockState then
                local item_obj = GetIES(inv_item:GetObject())
                local life_time = tonumber(GET_REMAIN_ITEM_LIFE_TIME(item_obj)) or 0
                if life_time > 0 then
                    table.insert(candidate_tickets, {
                        use_item = inv_item,
                        priority = (life_time and life_time > 0 and life_time < 86400) and 1 or 2
                    })
                else
                    if indun_type == 1001 then
                        use_item = inv_item
                    else
                        if Indun_panel_get_recipe_trade_count("EVENT_TOS_WHOLE_SHOP_320") < 1 and
                            Indun_panel_get_recipe_trade_count("PVP_MINE_40") < 1 then
                            use_item = inv_item
                        end
                    end
                end
            else
                ui.SysMsg(ClMsg("MaterialItemIsLock") .. " (" .. use_item.Name .. ")")
            end
        end
    end
    if #candidate_tickets > 0 then
        table.sort(candidate_tickets, function(a, b)
            return a.priority < b.priority
        end)
        use_item = candidate_tickets[1].use_item
    end
    if use_item then
        INV_ICON_USE(use_item)
        Indun_panel_enter_reserve(enter_mode, indun_type)
        return true
    end
    return false
end

function Indun_panel_enter_reserve(index, indun_type)
    AnsGiveUpPrevPlayingIndun(1)
    ReserveScript(string.format("Indun_panel_enter_challenge(nil,nil,'%d', %d)", index, indun_type), 1.5)
end

function Indun_panel_enter_challenge(indun_panel, ctrl, index, indun_type)
    index = tonumber(index)
    if not indun_type then
        return
    end
    local pcparty = session.party.GetPartyInfo()
    if not pcparty then
        CREATE_PARTY_BTN()
    end
    ReqChallengeAutoUIOpen(indun_type)
    ReserveScript(string.format("ReqMoveToIndun(%d,%d)", index, 0), 0.3)
end

local SINGULARITY_CONFIG = {
    [2000] = { -- 520
        expiring = {10820018, 11030067},
        non_expiring = {10000470, 11030021, 11030017}
    },
    [2001] = { -- 540
        expiring = {11201303, 11201304, 10820051},
        non_expiring = {11201302, 11201301}
    }
}
function Indun_panel_singularity_frame(indun_panel, key, sub_key, indun_type, y, x)
    local low_indun_type = 2000
    local btn_low = indun_panel:CreateOrGetControl('button', "btn_low" .. indun_type, x, y, 50, 30)
    AUTO_CAST(btn_low)
    btn_low:SetText("{ol}520")
    btn_low:SetEventScript(ui.LBUTTONUP, "Indun_panel_enter_singularity")
    btn_low:SetEventScriptArgNumber(ui.LBUTTONUP, low_indun_type)
    local count_low = indun_panel:CreateOrGetControl("richtext", "count_low" .. indun_type, x + 55, y + 5, 30, 30)
    count_low:SetText("{ol}(" .. Indun_panel_get_entrance_count(low_indun_type, 4) .. ")")
    local ticket_low = indun_panel:CreateOrGetControl('button', 'ticket_low' .. indun_type, x + 85, y, 100, 30)
    AUTO_CAST(ticket_low)
    local text_low = string.format("{ol}{#EE7800}USEor{s16}{img %s 15 15}{#FFFFFF}%s", "icon_item_Tos_Event_Coin",
        Indun_panel_get_recipe_trade_count("EVENT_TOS_WHOLE_SHOP_314") or 0)
    local count = Indun_panel_get_invitem_count(SINGULARITY_CONFIG[2000].expiring)
    count = count + Indun_panel_get_invitem_count(SINGULARITY_CONFIG[2000].non_expiring)
    local icon_text = ""
    local item_cls = GetClassByType('Item', SINGULARITY_CONFIG[2000].expiring[1])
    if item_cls then
        local fmt = g.lang == "Japanese" and "{ol}{img %s 25 25 } %d枚持っています{nl} {nl}" or
                        "{ol}{img %s 25 25 } Quantity in Inventory: %d{nl} {nl}"
        icon_text = string.format(fmt, item_cls.Icon, count)
    end
    local tooltip_low = g.lang == "Japanese" and
                            "{ol}優先順位{nl}1.期限付き{nl}2.期限なし{nl}3.{img icon_item_Tos_Event_Coin 20 20}チケット(買って使います)" or
                            "{ol}Priority{nl}1.Expiring{nl}2.Non-expiring{nl}3.{img icon_item_Tos_Event_Coin 20 20}tickets(buy and use)"
    ticket_low:SetText(text_low)
    ticket_low:SetTextTooltip(icon_text .. tooltip_low)
    ticket_low:SetEventScript(ui.LBUTTONUP, "Indun_panel_item_use_sin")
    ticket_low:SetEventScriptArgNumber(ui.LBUTTONUP, low_indun_type)
    local high_indun_type = 2001
    local btn_high = indun_panel:CreateOrGetControl('button', "btn_high" .. indun_type, x + 195, y, 50, 30)
    AUTO_CAST(btn_high)
    btn_high:SetText("{ol}540")
    btn_high:SetEventScript(ui.LBUTTONUP, "Indun_panel_enter_singularity")
    btn_high:SetEventScriptArgNumber(ui.LBUTTONUP, high_indun_type)
    local count_high = indun_panel:CreateOrGetControl("richtext", "count_high" .. indun_type, x + 250, y + 5, 30, 30)
    count_high:SetText("{ol}(" .. Indun_panel_get_entrance_count(high_indun_type, 4) .. ")")
    local ticket_high_tos = indun_panel:CreateOrGetControl('button', 'ticket_high_tos' .. indun_type, x + 280, y, 100,
        30)
    AUTO_CAST(ticket_high_tos)
    local text_high_tos = string.format("{ol}{#EE7800}USEor{s16}{img %s 15 15}{#FFFFFF}%s", "icon_item_Tos_Event_Coin",
        Indun_panel_get_recipe_trade_count("EVENT_TOS_WHOLE_SHOP_319") or 0)
    local count = Indun_panel_get_invitem_count(SINGULARITY_CONFIG[2001].expiring)
    count = count + Indun_panel_get_invitem_count(SINGULARITY_CONFIG[2001].non_expiring)
    local icon_text_high = ""
    local item_cls = GetClassByType('Item', SINGULARITY_CONFIG[2001].expiring[1])
    if item_cls then
        local fmt = g.lang == "Japanese" and "{ol}{img %s 25 25 } %d枚持っています{nl} {nl}" or
                        "{ol}{img %s 25 25 } Quantity in Inventory: %d{nl} {nl}"
        icon_text_high = string.format(fmt, item_cls.Icon, count)
    end
    local tooltip_high_tos = g.lang == "Japanese" and
                                 "{ol}優先順位{nl}1.24時間以内の期限付きチケット{nl}2.期限付きチケット{nl}3.{img icon_item_Tos_Event_Coin 20 20}チケット(買って使います){nl}4.期限の無いチケット" or
                                 "{ol}Priority{nl}1.Limited-time tickets (under 24 hours){nl}2.Limited-time tickets{nl}3.{img icon_item_Tos_Event_Coin 20 20}tickets(buy and use){nl}4.Tickets without an expiration date"
    ticket_high_tos:SetText(text_high_tos)
    ticket_high_tos:SetTextTooltip(icon_text_high .. tooltip_high_tos)
    ticket_high_tos:SetEventScript(ui.LBUTTONUP, "Indun_panel_item_use_sin")
    ticket_high_tos:SetEventScriptArgString(ui.LBUTTONUP, "tos")
    ticket_high_tos:SetEventScriptArgNumber(ui.LBUTTONUP, high_indun_type)
    local ticket_high_pvp = indun_panel:CreateOrGetControl('button', 'ticket_high_pvp' .. indun_type, x + 390, y, 140,
        30)
    AUTO_CAST(ticket_high_pvp)
    local text_high_pvp = string.format("{ol}{#FFFFFF}{s16}USEor{img %s 18 18}d:%s w:%s", "pvpmine_shop_btn_total",
        Indun_panel_get_recipe_trade_count("PVP_MINE_41") or 0, Indun_panel_get_recipe_trade_count("PVP_MINE_42") or 0)
    local tooltip_high_pvp = g.lang == "Japanese" and
                                 "{ol}優先順位{nl}1.24時間以内の期限付きチケット{nl}2.期限付きチケット{nl}3.{img pvpmine_shop_btn_total 20 20}チケット(買って使います){nl}4.期限の無いチケット" or
                                 "{ol}Priority{nl}1.Limited-time tickets (under 24 hours){nl}2.Limited-time tickets{nl}3.{img pvpmine_shop_btn_total 20 20}tickets(buy and use){nl}4.Tickets without an expiration date"
    ticket_high_pvp:SetText(text_high_pvp)
    ticket_high_pvp:SetTextTooltip(icon_text_high .. tooltip_high_pvp)
    ticket_high_pvp:SetEventScript(ui.LBUTTONUP, "Indun_panel_item_use_sin")
    ticket_high_pvp:SetEventScriptArgString(ui.LBUTTONUP, "pvp")
    ticket_high_pvp:SetEventScriptArgNumber(ui.LBUTTONUP, high_indun_type)
    local singularity_check = indun_panel:CreateOrGetControl("checkbox", "singularity_check", x + 545, y, 25, 25)
    AUTO_CAST(singularity_check)
    singularity_check:SetEventScript(ui.LBUTTONUP, "Indun_panel_ischecked")
    singularity_check:SetTextTooltip(g.lang == "Japanese" and
                                         "{ol}チェックをすると自動マッチングボタンを押しません" or
                                         "{ol}If checked, the automatic matching button will not be pressed")
    singularity_check:SetCheck(g.indun_panel_settings.etc.singularity_check)
end

function Indun_panel_item_use_sin(frame, ctrl, mode, indun_type)
    local ent_count = Indun_panel_get_entrance_count(indun_type, 4)
    if tonumber(ent_count) > 0 then
        return
    end
    local config = SINGULARITY_CONFIG[indun_type]
    if not config then
        return
    end
    if Indun_panel_try_use_ticket_list(config.expiring, indun_type) then
        return
    end
    if mode == "tos" or indun_type == 2000 then
        local recipe = (indun_type == 2000) and "EVENT_TOS_WHOLE_SHOP_314" or "EVENT_TOS_WHOLE_SHOP_319"
        if Indun_panel_get_recipe_trade_count(recipe) >= 1 then
            Indun_panel_item_buy_use(recipe)
            ReserveScript(string.format("Indun_panel_enter_singularity(nil,nil,'', %d)", indun_type), 1.5)
            return
        end
    elseif mode == "pvp" then
        if Indun_panel_get_recipe_trade_count("PVP_MINE_41") >= 1 then
            Indun_panel_item_buy_use("PVP_MINE_41")
            ReserveScript(string.format("Indun_panel_enter_singularity(nil,nil,'', %d)", indun_type), 1.5)
            return
        end
        if Indun_panel_get_recipe_trade_count("PVP_MINE_42") >= 1 then
            Indun_panel_item_buy_use("PVP_MINE_42")
            ReserveScript(string.format("Indun_panel_enter_singularity(nil,nil,'', %d)", indun_type), 1.5)
            return
        end
    end
    if Indun_panel_try_use_ticket_list(config.non_expiring, indun_type) then
        return
    end
end

function Indun_panel_try_use_ticket_list(ticket_ids, indun_type)
    local candidate_tickets = {}
    for _, classid in ipairs(ticket_ids) do
        local inv_item = session.GetInvItemByType(classid)
        if inv_item then
            if not inv_item.isLockState then
                local item_obj = GetIES(inv_item:GetObject())
                local life_time = tonumber(GET_REMAIN_ITEM_LIFE_TIME(item_obj)) or 0
                local priority = (life_time > 0 and life_time < 86400) and 1 or 2
                table.insert(candidate_tickets, {
                    use_item = inv_item,
                    priority = priority
                })
            else
                ui.SysMsg(ClMsg("MaterialItemIsLock") .. " (" .. inv_item.Name .. ")")
            end
        end
    end
    if #candidate_tickets > 0 then
        table.sort(candidate_tickets, function(a, b)
            return a.priority < b.priority
        end)
        local best_ticket = candidate_tickets[1].use_item
        Indun_panel_item_use_and_run(best_ticket, indun_type)
        return true
    end
    return false
end

function Indun_panel_item_use_and_run(use_item, indun_type)
    AnsGiveUpPrevPlayingIndun(1)
    if use_item and indun_type then
        INV_ICON_USE(use_item)
        ReserveScript(string.format("Indun_panel_enter_singularity(nil,nil,'', %d)", indun_type), 0.5)
        return
    end
end

function Indun_panel_enter_singularity(frame, ctrl, str, indun_type)
    ReqChallengeAutoUIOpen(indun_type)
    local indun_cls = GetClassByType('Indun', indun_type)
    if indun_cls then
        local indun_min_rank = TryGetProp(indun_cls, 'PCRank')
        local totaljobcount = session.GetPcTotalJobGrade()
        if indun_min_rank then
            if indun_min_rank > totaljobcount and indun_min_rank ~= totaljobcount then
                ui.SysMsg(ScpArgMsg('IndunEnterNeedPCRank', 'NEED_RANK', indun_min_rank))
                return
            end
        end
        if g.indun_panel_settings.etc.singularity_check == 0 then
            ReserveScript(string.format("ReqMoveToIndun(%d,%d)", 2, 0), 0.3)
        end
    end
end

local raid_tbl = {
    [729] = {11210063, 11210062, 11210061},
    [725] = {11210057, 11210056, 11210055},
    [722] = {11210053, 11210052, 11210051},
    [716] = {11210044, 10820040, 11210043, 11210042},
    [707] = {11210024, 11210023, 11210022},
    [710] = {11210028, 11210027, 11210026},
    [695] = {11200356, 11200355, 11200354},
    [688] = {11200290, 10820036, 11200289, 11200288},
    [685] = {11200281, 10820035, 11200280, 11200279},
    [679] = {108020026, 11200222, 11200221, 11200220}
}
local buff_ids = {
    [729] = 80047, -- ズメイ
    [725] = 80045, -- ベリオラ
    [722] = 80043, -- ライマラ
    [716] = 80039, -- レダニア
    [707] = 80035, -- ネリンガ
    [710] = 80037, -- ゴーレム
    [673] = 80016, -- スプレッダー
    [676] = 80017, -- ファロウス
    [679] = 80015, -- ロゼ
    [685] = 80030, -- 蝶々
    [688] = 80031, -- スロガ
    [695] = 80032 -- メレジ
}

function Indun_panel_create_frame_onsweep(indun_panel, key, sub_key, sub_value, y, x)
    if raid_tbl[sub_value] then
        local use_btn = indun_panel:CreateOrGetControl('button', key .. "use", x + 470, y, 80, 30)
        AUTO_CAST(use_btn)
        use_btn:SetText("{ol}{#EE7800}USE")
        local count = Indun_panel_get_invitem_count(raid_tbl[sub_value])
        local item_cls = GetClassByType('Item', raid_tbl[sub_value][2])
        if item_cls then
            local fmt = g.lang == "Japanese" and "{ol}{img %s 25 25 } %d枚持っています" or
                            "{ol}{img %s 25 25 } Quantity in Inventory: %d"
            use_btn:SetTextTooltip(string.format(fmt, item_cls.Icon, count))
        end
        use_btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_raid_itemuse")
        use_btn:SetEventScriptArgNumber(ui.LBUTTONUP, sub_value)
    end
    local btn_solo = indun_panel:CreateOrGetControl('button', key .. "solo", x, y, 80, 30)
    local btn_auto = indun_panel:CreateOrGetControl('button', key .. "auto", x + 85, y, 80, 30)
    local btn_hard = indun_panel:CreateOrGetControl('button', key .. "hard", x + 215, y, 80, 30)
    local btn_sweep = indun_panel:CreateOrGetControl('button', key .. "sweep", x + 350, y, 80, 30)
    local txt_count = indun_panel:CreateOrGetControl("richtext", key .. "count", x + 170, y + 5, 50, 30)
    local txt_hard_count = indun_panel:CreateOrGetControl("richtext", key .. "counthard", x + 300, y + 5, 50, 30)
    local txt_sweep_count = indun_panel:CreateOrGetControl("richtext", key .. "sweepcount", x + 435, y + 5, 50, 30)
    btn_solo:SetText("{ol}SOLO")
    btn_auto:SetText("{ol}{#FFD900}AUTO")
    btn_hard:SetText("{ol}{#FF0000}HARD")
    btn_sweep:SetText("{ol}{#00FF00}ACLEAR")
    if sub_key == "s" then -- Solo
        txt_count:SetText(Indun_panel_get_entrance_count(sub_value, 2))
        btn_solo:SetEventScript(ui.LBUTTONUP, "Indun_panel_enter_solo")
        btn_solo:SetEventScriptArgNumber(ui.LBUTTONUP, sub_value)
    elseif sub_key == "a" then -- Auto
        btn_auto:SetEventScript(ui.LBUTTONUP, "Indun_panel_enter_auto")
        btn_auto:SetEventScriptArgNumber(ui.LBUTTONUP, sub_value)
        btn_sweep:SetEventScript(ui.LBUTTONUP, "Indun_panel_raid_itemuse")
        btn_sweep:SetEventScriptArgNumber(ui.LBUTTONUP, sub_value)
        btn_sweep:SetEventScriptArgString(ui.LBUTTONUP, "SWEEP")
    elseif sub_key == "h" then -- Hard
        local ent_count = Indun_panel_get_entrance_count(sub_value, 2)
        if ent_count then
            txt_hard_count:SetText(ent_count)
            btn_hard:SetEventScript(ui.LBUTTONDOWN, "Indun_panel_enter_hard")
            btn_hard:SetEventScriptArgNumber(ui.LBUTTONDOWN, sub_value)
            btn_hard:SetEventScriptArgString(ui.LBUTTONDOWN, "false")
        end
    elseif sub_key == "ac" then -- Auto Clear (Sweep) Count
        local count_str = Indun_panel_sweep_count(sub_value)
        txt_sweep_count:SetText(string.format("{ol}{#FFFFFF}{s16}(%s)", count_str))
    end
end

function Indun_panel_raid_itemuse(indun_panel, ctrl, str, indun_type)
    local target_items = raid_tbl[indun_type]
    local buff_id = buff_ids[indun_type]
    if not buff_id then
        return
    end
    local indun_cls = GetClassByType("Indun", indun_type)
    local enter_count = 0
    if indun_cls then
        enter_count = GET_CURRENT_ENTERANCE_COUNT(indun_cls.PlayPerResetType) or 0
    end
    local limit_count = 2
    if indun_type == 673 or indun_type == 676 then
        limit_count = 4
    end
    local is_limit_reached = (enter_count >= limit_count)
    local sweep_count = Indun_panel_sweep_count(buff_id)
    if sweep_count == 0 and str == "SWEEP" then
        ui.SysMsg(g.lang == "Japanese" and "掃討バフがありません" or "There is no auto clear buff")
        return
    end
    local ticket_item = nil
    if target_items then
        for _, class_id in ipairs(target_items) do
            local inv_item = session.GetInvItemByType(class_id)
            if inv_item then
                ticket_item = inv_item
                break
            end
        end
    end
    if sweep_count > 0 then
        if not is_limit_reached then
            ReqUseRaidAutoSweep(indun_type)
        else
            if ticket_item then
                INV_ICON_USE(ticket_item)
                ReserveScript(string.format("ReqUseRaidAutoSweep(%d)", indun_type), 0.5)
            else
                ui.SysMsg(g.lang == "Japanese" and "入場回数不足（チケットなし）" or
                              "Not enough entry count (No tickets).")
            end
        end
    else
        if ticket_item then
            INV_ICON_USE(ticket_item)
        else
            if string.find(ctrl:GetName(), "use") then
                ui.SysMsg(g.lang == "Japanese" and "(自動マッチング/1人)入場券を持っていません" or
                              "There are no ticket items in inventory")
            else
                ui.SysMsg(g.lang == "Japanese" and "掃討バフがありません" or "There is no auto clear buff")
            end
        end
    end
end

function Indun_panel_sweep_count(buff_id)
    local my_handle = session.GetMyHandle()
    local buff = info.GetBuff(my_handle, buff_id)
    if buff then
        return buff.over or 0
    end
    return 0
end

function Indun_panel_enter_solo(indun_panel, ctrl, str, indun_type)
    local pcparty = session.party.GetPartyInfo()
    if not pcparty then
        CREATE_PARTY_BTN()
    end
    ReqRaidAutoUIOpen(indun_type)
    ReserveScript(string.format("ReqMoveToIndun(%d,%d)", 1, 0), 0.3)
end

function Indun_panel_enter_auto(indun_panel, ctrl, str, indun_type)
    ReqRaidAutoUIOpen(indun_type)
    local indun_cls = GetClassByType('Indun', indun_type)
    if indun_cls then
        local indun_min_rank = TryGetProp(indun_cls, 'PCRank')
        local totaljobcount = session.GetPcTotalJobGrade()
        if indun_min_rank ~= nil then
            if indun_min_rank > totaljobcount and indun_min_rank ~= totaljobcount then
                ui.SysMsg(ScpArgMsg('IndunEnterNeedPCRank', 'NEED_RANK', indun_min_rank))
                return
            end
        end
        ReserveScript(string.format("ReqMoveToIndun(%d,%d)", 2, 0), 0.3)
    end
end

local function Indun_panel_induninfo_set_buttons(indun_type, ctrl)
    local indun_cls = GetClassByType('Indun', indun_type)
    if indun_cls then
        local dungeon_type = TryGetProp(indun_cls, "DungeonType", "None")
        local btn_info_cls = GetClassByStrProp("IndunInfoButton", "DungeonType", dungeon_type)
        if dungeon_type == "Raid" then
            btn_info_cls = INDUNINFO_SET_BUTTONS_FIND_CLASS(indun_cls)
        end
        local red_button_scp = TryGetProp(btn_info_cls, "RedButtonScp")
        ctrl:SetUserValue('MOVE_INDUN_CLASSID', indun_cls.ClassID)
        ctrl:SetEventScript(ui.LBUTTONUP, red_button_scp)
    end
end

function Indun_panel_enter_hard(indun_panel, ctrl, str, indun_type)
    local indun_cls = GetClassByType("Indun", indun_type)
    if str == "false" then
        Indun_panel_induninfo_set_buttons(indun_type, ctrl)
        str = "true"
        if indun_type then
            ReserveScript(string.format("Indun_panel_enter_hard(nil,nil,'%s',%d)", str, indun_type), 0.5)
            return
        end
    else
        SHOW_INDUNENTER_DIALOG(indun_type)
        return
    end
end

function Indun_panel_create_frame(indun_panel, key, sub_key, sub_value, y, x)
    local btn_solo = indun_panel:CreateOrGetControl('button', key .. "solo", x, y, 80, 30)
    local btn_auto = indun_panel:CreateOrGetControl('button', key .. "auto", x + 85, y, 80, 30)
    local btn_hard = indun_panel:CreateOrGetControl('button', key .. "hard", x + 215, y, 80, 30)
    local txt_count = indun_panel:CreateOrGetControl("richtext", key .. "count", x + 170, y + 5, 50, 30)
    local txt_hard_count = indun_panel:CreateOrGetControl("richtext", key .. "counthard", x + 300, y + 5, 50, 30)
    btn_solo:SetText("{ol}SOLO")
    btn_auto:SetText(key == "memory" and "{ol}{#FFD900}NORMAL" or "{ol}{#FFD900}AUTO")
    btn_hard:SetText("{ol}{#FF0000}HARD")
    if sub_key == "s" then
        local count_idx = (key == "memory") and 1 or 2
        txt_count:SetText(Indun_panel_get_entrance_count(sub_value, count_idx))
        btn_solo:SetEventScript(ui.LBUTTONUP, "Indun_panel_enter_solo")
        btn_solo:SetEventScriptArgNumber(ui.LBUTTONUP, sub_value)
    elseif sub_key == "a" then
        btn_auto:SetEventScript(ui.LBUTTONUP, "Indun_panel_enter_auto")
        btn_auto:SetEventScriptArgNumber(ui.LBUTTONUP, sub_value)
    elseif sub_key == "h" then
        local count_idx
        if key == "memory" then
            count_idx = 1
        elseif key == "giltine" then
            count_idx = 1
        else
            count_idx = 2
        end
        txt_hard_count:SetText(Indun_panel_get_entrance_count(sub_value, count_idx))
        btn_hard:SetEventScript(ui.LBUTTONDOWN, "Indun_panel_enter_hard")
        btn_hard:SetEventScriptArgNumber(ui.LBUTTONDOWN, sub_value)
        btn_hard:SetEventScriptArgString(ui.LBUTTONDOWN, "false")
    end
end

local TELHARSHA_CONFIG = {
    recipe = "EVENT_TOS_WHOLE_SHOP_306",
    ticket_id = 108020009,
    max_count = 3
}
function Indun_panel_telharsha_frame(indun_panel, key, value, y, x)
    local btn = indun_panel:CreateOrGetControl('button', key .. 'btn', x, y, 80, 30)
    AUTO_CAST(btn)
    btn:SetText("{ol}IN")
    btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_enter_solo")
    btn:SetEventScriptArgNumber(ui.LBUTTONUP, value)
    local count = indun_panel:CreateOrGetControl("richtext", key .. "count", x + 85, y + 5, 50, 30)
    count:SetText(Indun_panel_get_entrance_count(value, 2))
    local ticket_btn = indun_panel:CreateOrGetControl('button', key .. 'ticket_btn', x + 130, y, 80, 30)
    AUTO_CAST(ticket_btn)
    local tickets = {10820009, 11035056}
    local count = Indun_panel_get_invitem_count(tickets)
    local icon_text = ""
    local item_cls = GetClassByType('Item', tickets[1])
    if item_cls then
        local fmt = g.lang == "Japanese" and "{ol}{img %s 25 25 } %d枚持っています" or
                        "{ol}{img %s 25 25 } Quantity in Inventory: %d"
        icon_text = string.format(fmt, item_cls.Icon, count)
    end
    ticket_btn:SetTextTooltip(icon_text)
    ticket_btn:SetText("{ol}{#EE7800}{s14}BUYUSE")
    ticket_btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_buyuse_telharsha")
    ticket_btn:SetEventScriptArgString(ui.LBUTTONUP, TELHARSHA_CONFIG.recipe)
    ticket_btn:SetEventScriptArgNumber(ui.LBUTTONUP, value)
    local change_count = Indun_panel_get_recipe_trade_count(TELHARSHA_CONFIG.recipe)
    local tos_shop_count = indun_panel:CreateOrGetControl("richtext", key .. "tos_shop_count", x + 215, y + 5, 40, 30)
    tos_shop_count:SetText(string.format("{ol}{s16}({img icon_item_Tos_Event_Coin 15 15}%s)", change_count))
end

function Indun_panel_buyuse_telharsha(indun_panel, ctrl, recipe_name, indun_type)
    if not indun_type then
        return
    end
    local indun_cls = GetClassByType("Indun", indun_type)
    if not indun_cls then
        return
    end
    local current_count = 0
    if indun_cls then
        current_count = GET_CURRENT_ENTERANCE_COUNT(indun_cls.PlayPerResetType) or 0
    end
    if tonumber(current_count) < TELHARSHA_CONFIG.max_count then
        ReserveScript(string.format("Indun_panel_enter_solo(nil, nil, '', %d)", indun_type), 0.2)
        return
    end
    local use_item = session.GetInvItemByType(TELHARSHA_CONFIG.ticket_id)
    if use_item then
        INV_ICON_USE(use_item)
        ReserveScript(string.format("Indun_panel_enter_solo(nil, nil, '', %d)", indun_type), 0.5)
        return
    end
    local change_count = Indun_panel_get_recipe_trade_count(recipe_name)
    if change_count >= 1 then
        Indun_panel_item_buy_use(recipe_name)
        ReserveScript(string.format("Indun_panel_enter_solo(nil, nil, '', %d)", indun_type), 1.5)
        return
    end
    local msg = g.lang == "Japanese" and "トレード回数が足りません。" or "No trade count."
    ui.SysMsg(msg)
end

local VELNICE_CONFIG = {
    recipe = "PVP_MINE_52",
    tickets = {11030169, 11030257}, -- 優先順: 1日期限 -> 通常
    max_count = 1
}
function Indun_panel_velnice_frame(indun_panel, key, value, y, x)
    local btn = indun_panel:CreateOrGetControl('button', key .. 'btn', x, y, 80, 30)
    AUTO_CAST(btn)
    btn:SetText("{ol}IN")
    btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_enter_velnice_solo")
    btn:SetEventScriptArgNumber(ui.LBUTTONUP, value)
    local count = indun_panel:CreateOrGetControl("richtext", key .. "count", x + 85, y + 5, 50, 30)
    count:SetText(Indun_panel_get_entrance_count(value, 2))
    local ticket_btn = indun_panel:CreateOrGetControl('button', key .. 'ticket_btn', x + 130, y, 80, 30)
    AUTO_CAST(ticket_btn)
    local count = Indun_panel_get_invitem_count(VELNICE_CONFIG.tickets)
    local icon_text = ""
    local item_cls = GetClassByType('Item', VELNICE_CONFIG.tickets[1])
    if item_cls then
        local fmt = g.lang == "Japanese" and "{ol}{img %s 25 25 } %d枚持っています" or
                        "{ol}{img %s 25 25 } Quantity in Inventory: %d"
        icon_text = string.format(fmt, item_cls.Icon, count)
    end
    ticket_btn:SetTextTooltip(icon_text)
    ticket_btn:SetText("{ol}{#EE7800}{s14}BUYUSE")
    ticket_btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_buyuse_vel")
    ticket_btn:SetEventScriptArgString(ui.LBUTTONUP, VELNICE_CONFIG.recipe)
    ticket_btn:SetEventScriptArgNumber(ui.LBUTTONUP, value)
    local trade_count = Indun_panel_get_recipe_trade_count(VELNICE_CONFIG.recipe)
    trade_count = math.max(0, trade_count)
    local overbuy_limit = Indun_panel_overbuy_count(VELNICE_CONFIG.recipe)
    local change_text = indun_panel:CreateOrGetControl("richtext", key .. "change_text", x + 215, y + 5, 60, 30)
    change_text:SetText(string.format("{ol}{#FFFFFF}(%d/%d)", trade_count, overbuy_limit))
    local amount = indun_panel:CreateOrGetControl("richtext", key .. "amount", x + 280, y + 5, 50, 30)
    local cost = Indun_panel_overbuy_amount(VELNICE_CONFIG.recipe)
    local color = (trade_count > 0) and "{#FFFFFF}" or "{#FF0000}"
    local amount_str = string.format("{ol}{#FFFFFF}({img pvpmine_shop_btn_total 20 20}%s%s{ol}{#FFFFFF})", color,
        GET_COMMAED_STRING(cost))
    amount:SetText(amount_str)
end

function Indun_panel_buyuse_vel(indun_panel, ctrl, recipe_name, indun_type)
    if not indun_type then
        return
    end
    local indun_cls = GetClassByType("Indun", indun_type)
    if not indun_cls then
        return
    end
    local current_count = 0
    if indun_cls then
        current_count = GET_CURRENT_ENTERANCE_COUNT(indun_cls.PlayPerResetType) or 0
    end
    local reserve_script = string.format("Indun_panel_enter_velnice_solo(nil, nil, '', %d)", indun_type)
    if tonumber(current_count) < VELNICE_CONFIG.max_count then
        ReserveScript(reserve_script, 0.2)
        return
    end
    for _, ticket_id in ipairs(VELNICE_CONFIG.tickets) do
        local use_item = session.GetInvItemByType(ticket_id)
        if use_item then
            INV_ICON_USE(use_item)
            ReserveScript(reserve_script, 1.0)
            return
        end
    end
    local trade_count = Indun_panel_get_recipe_trade_count(recipe_name)
    local overbuy_limit = Indun_panel_overbuy_count(recipe_name)
    if trade_count >= 1 or overbuy_limit > 0 then
        Indun_panel_item_buy_use(recipe_name)
        ReserveScript(reserve_script, 1.5)
        return
    else
        ui.SysMsg(g.lang == "Japanese" and "トレード回数が足りません。" or "No trade count.")
        return
    end
end

function Indun_panel_enter_velnice_solo(indun_panel, ctrl, str, indun_type)
    local indun_cls = GetClassByType("Indun", indun_type)
    if not indun_cls then
        return
    end
    local account_obj = GetMyAccountObj()
    if account_obj then
        local stage = TryGetProp(account_obj, "SOLO_DUNGEON_MINI_CLEAR_STAGE", 0)
        local yes_scp = "INDUNINFO_MOVE_TO_SOLO_DUNGEON_PRECHECK"
        local title = ScpArgMsg("Select_Stage_SoloDungeon", "Stage", stage + 5)
        INDUN_EDITMSGBOX_FRAME_OPEN(indun_type, title, "", yes_scp, "", 1, stage + 5, 1)
    end
end

local DUNGEON_TICKET_CONFIG = {
    [684] = { -- (嘆きの墓地)
        label = "490",
        tickets = {11200276, 11200275, 11200274}
    },
    [728] = { --  (アシャーク)
        label = "540",
        tickets = {11200486, 11200485, 11200484}
    }
}
function Indun_panel_create_common_ticket_frame(indun_panel, key, indun_type, y, x)
    local config = DUNGEON_TICKET_CONFIG[indun_type]
    if not config then
        return
    end
    local btn = indun_panel:CreateOrGetControl('button', key .. 'btn', x, y, 80, 30)
    AUTO_CAST(btn)
    btn:SetText("{ol}" .. config.label)
    btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_enter_solo")
    btn:SetEventScriptArgNumber(ui.LBUTTONUP, indun_type)
    local count_text = indun_panel:CreateOrGetControl("richtext", key .. "count", x + 85, y + 5, 50, 30)
    count_text:SetText(Indun_panel_get_entrance_count(indun_type, 1))
    local ticket_btn = indun_panel:CreateOrGetControl('button', key .. 'ticket_btn', x + 115, y, 80, 30)
    AUTO_CAST(ticket_btn)
    ticket_btn:SetText("{ol}{#EE7800}{s14}USE")
    local inv_count = 0
    for _, id in ipairs(config.tickets) do
        local inv_item = session.GetInvItemByType(id)
        if inv_item then
            inv_count = inv_count + inv_item.count
        end
    end
    if #config.tickets > 0 then
        local item_cls = GetClassByType('Item', config.tickets[1])
        if item_cls then
            local fmt = g.lang == "Japanese" and "{ol}{img %s 25 25 } %d枚持っています" or
                            "{ol}{img %s 25 25 } Quantity in Inventory: %d"
            ticket_btn:SetTextTooltip(string.format(fmt, item_cls.Icon, inv_count))
        end
    end
    ticket_btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_item_use")
    ticket_btn:SetEventScriptArgNumber(ui.LBUTTONUP, indun_type)
end

function Indun_panel_cemetery_frame(indun_panel, key, indun_type, y, x)
    Indun_panel_create_common_ticket_frame(indun_panel, key, indun_type, y, x)
end

function Indun_panel_demonlair_frame(indun_panel, key, indun_type, y, x)
    Indun_panel_create_common_ticket_frame(indun_panel, key, indun_type, y, x)
end

function Indun_panel_item_use(indun_panel, ctrl, str, indun_type)
    local config = DUNGEON_TICKET_CONFIG[indun_type]
    if not config then
        return
    end
    for _, classid in ipairs(config.tickets) do
        local use_item = session.GetInvItemByType(classid)
        if use_item then
            INV_ICON_USE(use_item)
            return
        end
    end
end

function Indun_panel_jsr_frame(indun_panel, y, x)
    local jsrbtn = indun_panel:CreateOrGetControl('button', 'jsrbtn', x, y, 80, 30)
    AUTO_CAST(jsrbtn)
    jsrbtn:SetText("{ol}JSR")
    jsrbtn:SetEventScript(ui.LBUTTONUP, "FIELD_BOSS_JOIN_ENTER_CLICK")
    jsrbtn:SetUserValue("BASE_X", x)
    jsrbtn:SetUserValue("BASE_Y", y)
    Indun_panel_field_boss_enter_timer_setting(jsrbtn)
    jsrbtn:RunUpdateScript("Indun_panel_field_boss_enter_timer_setting", 1.0)
end

local function format_jsr_time(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local seconds_rem = seconds % 60

    local jp = string.format("%d時間%d分%d秒", hours, minutes, seconds_rem)
    local en = string.format("%02d:%02d:%02d", hours, minutes, seconds_rem)
    return jp, en
end

function Indun_panel_field_boss_enter_timer_setting(ctrl)
    local frame = ctrl:GetTopParentFrame()
    if not frame then
        return 0
    end
    local server_time_str = date_time.get_lua_now_datetime_str()
    if not server_time_str then
        return 1
    end
    local _, _, _, hour_str, min_str, sec_str = server_time_str:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
    if not hour_str then
        return 1
    end
    local today_sec = tonumber(hour_str) * 3600 + tonumber(min_str) * 60 + tonumber(sec_str)
    local sec12 = 12 * 3600
    local sec22 = 22 * 3600
    local diff12 = sec12 - today_sec
    local diff22 = sec22 - today_sec
    local text_str = ""
    local is_en = (g.indun_panel_settings.etc.en_ver == 1) -- 設定参照先を修正
    if diff12 >= 0 then
        local jp, en = format_jsr_time(diff12)
        text_str = is_en and (en .. " After Start") or (jp .. ClMsg("After_Start"))
    elseif diff12 >= -300 then
        local jp, en = format_jsr_time(300 + diff12)
        text_str = is_en and (en .. " After Exit") or (jp .. ClMsg("After_Exit"))
    elseif diff22 >= 0 then
        local jp, en = format_jsr_time(diff22)
        text_str = is_en and (en .. " After Start") or (jp .. ClMsg("After_Start"))
    elseif diff22 >= -300 then
        local jp, en = format_jsr_time(300 + diff22)
        text_str = is_en and (en .. " After Exit") or (jp .. ClMsg("After_Exit"))
    else
        text_str = is_en and "Already Exit" or ClMsg("Already_Exit")
    end
    local x = ctrl:GetUserIValue("BASE_X")
    local y = ctrl:GetUserIValue("BASE_Y")
    local jsrtime = frame:CreateOrGetControl("richtext", "jsrtime", x + 85, y + 5, 10, 10)
    jsrtime:SetText("{ol}" .. text_str)
    if x == 0 then
        jsrtime:ShowWindow(0)
    else
        jsrtime:ShowWindow(1)
    end
    return 1
end
-- indun_panel ここまで

