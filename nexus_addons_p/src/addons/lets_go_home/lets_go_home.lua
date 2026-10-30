-- lets_go_home　ここから
function Lets_go_home_save_settings()
    g.save_json(g.lets_go_home_path, g.lets_go_home_settings)
end

function Lets_go_home_load_settings()
    g.lets_go_home_path = string.format("../addons/%s/%s/lets_go_home.json", addon_name_lower, g.active_id)
    local settings = g.load_json(g.lets_go_home_path)
    if not settings then
        settings = {
            map = "",
            ch = 1,
            arrival = "none",
            x = 0,
            y = 0,
            move = 1,
            display = 1,
            short_cut = 1,
            quest = {}
        }
    end
    -- キャラごとに選んだクエストワープ(CID → 都市 → QuestProgressCheck の ClassID)。後から足したので無い人もいる。
    if type(settings.quest) ~= "table" then
        settings.quest = {}
    end
    -- 到着後の移動先は、以前は「レティーシャへ移動するか」の 0 / 1(leticia)だった。
    -- 倉庫番を足して 3 択(arrival)にしたので、ON だった人は "leticia" として引き継ぐ。
    if not settings.arrival then
        settings.arrival = settings.leticia == 1 and "leticia" or "none"
    end
    settings.leticia = nil
    g.lets_go_home_settings = settings
    Lets_go_home_save_settings()
end

-- 到着後の移動先。dialog は FullScreenMenuMoveNpc に渡す NPC のダイアログ名(倉庫番は都市ごと)。
-- 倉庫番のダイアログ名は gentype_<都市>.ies の Dialog 列(Name が「[창고지기]」の行)。
-- レティーシャはナビゲーションメニュー(full_screen_navigation_menu 309)の定義をそのまま使う。
g.lets_go_home_arrivals = {{
    key = "none",
    ja = "しない",
    en = "None"
}, {
    key = "leticia",
    ja = "レティーシャ",
    en = "Leticia"
}, {
    key = "warehouse",
    ja = "倉庫番",
    en = "Warehouse keeper",
    dialog = {
        ["c_Klaipe"] = "WAREHOUSE", -- リタ
        ["c_orsha"] = "ORSHA_WAREHOUSE", -- アイサ
        ["c_fedimian"] = "WAREHOUSE_FEDIMIAN" -- ジャダン
    }
}}

g.lets_go_home_citys = {"c_Klaipe", "c_orsha", "c_fedimian"}

-- クエストを選んでいないキャラが先に探すクエスト(この機能を足す前に固定で判定していたもの)。
-- どれも使えなければ、その都市へワープできるほかのクエストを ClassID 順に探す。
g.lets_go_home_quest_defaults = {
    ["c_Klaipe"] = {91055, 72165}, -- [英雄譚] の語り部(受注可能) / クォレルシューターマスター(完了可能)
    ["c_orsha"] = {90170, 90171}, -- リンカーマスター(どちらも完了可能)
    ["c_fedimian"] = {60400} -- パヤウタ(受注可能)
}

-- その都市へクエストワープしうるクエスト(QuestProgressCheck の ClassID)。都市ごとに 1 回だけ作る。
-- 素がクエストワープのアイコンを出す条件(MAKE_QUEST_INFO_COMMON)のうち、状態に依らない部分で先に絞る:
-- 受注可能 = POSSI_WARP / 進行中 = PROG_WARP / 完了可能 = SUCC_WARP が YES で、その段階の Map が都市のもの。
-- 受注可能は、POSSI_WARP が NO でも素の SCR_MAIN_QUEST_WARP_CHECK でワープできるメインクエスト
-- (mainquest_startnpcwarp に載っているもの)があるので、それも候補に入れる。
g.lets_go_home_quest_candidates = {}
function Lets_go_home_quest_candidates(city)
    if g.lets_go_home_quest_candidates[city] then
        return g.lets_go_home_quest_candidates[city]
    end
    local candidates = {}
    local cls_list, cnt = GetClassList("QuestProgressCheck")
    for i = 0, cnt - 1 do
        local cls = GetClassByIndexFromList(cls_list, i)
        if cls and (((TryGetProp(cls, "POSSI_WARP", "NO") == "YES" or GetClass("mainquest_startnpcwarp", cls.ClassName)) and
            TryGetProp(cls, "StartMap", "None") == city) or
            (TryGetProp(cls, "PROG_WARP", "NO") == "YES" and TryGetProp(cls, "ProgMap", "None") == city) or
            (TryGetProp(cls, "SUCC_WARP", "NO") == "YES" and TryGetProp(cls, "EndMap", "None") == city)) then
            table.insert(candidates, cls.ClassID)
        end
    end
    g.vlog("lets_go_home: %s へクエストワープしうるクエスト %d 件(全 %d 件から)", city, #candidates, cnt)
    g.lets_go_home_quest_candidates[city] = candidates
    return candidates
end

-- このキャラで、いまそのクエストを使って都市へワープできるか。
-- 素のクエストワープ(QUESTION_QUEST_WARP)と同じ関数(SCR_QUEST_CHECK_Q / GET_QUEST_NPC_STATE に pc を渡す)で
-- 段階を決め、その段階の Map を見る。**素と別の関数(SCR_QUEST_CHECK_C)で決めないこと。**
-- 素は g_questCheckFunc が残っていると _Q の結果で段階を決め直し、nil の段階に 'Map' を連結して落ちる。
function Lets_go_home_quest_usable(quest_id, city)
    local questIES = GetClassByType('QuestProgressCheck', quest_id)
    if not questIES then
        return false
    end
    local pc = GetMyPCObject()
    local result = SCR_QUEST_CHECK_Q(pc, questIES.ClassName)
    local questState = GET_QUEST_NPC_STATE(questIES, result, pc)
    return questState ~= nil and questIES[questState .. "Map"] == city
end

-- 探す順: 既定のクエスト → 残りの候補(ClassID 順)。visit が true を返したらそこで打ち切る。
function Lets_go_home_each_quest(city, visit)
    local listed = {}
    for _, quest_id in ipairs(g.lets_go_home_quest_defaults[city] or {}) do
        listed[quest_id] = true
        if visit(quest_id) then
            return
        end
    end
    for _, quest_id in ipairs(Lets_go_home_quest_candidates(city)) do
        if not listed[quest_id] and visit(quest_id) then
            return
        end
    end
end

-- このキャラで今その都市へワープできるクエストの ClassID(設定の窓の一覧用。全件を判定する)
function Lets_go_home_available_quests(city)
    local available = {}
    Lets_go_home_each_quest(city, function(quest_id)
        if Lets_go_home_quest_usable(quest_id, city) then
            table.insert(available, quest_id)
        end
    end)
    return available
end

-- このキャラが選んだクエスト(選んでいなければ nil)
function Lets_go_home_chosen_quest(city)
    local chosen = g.lets_go_home_settings.quest[tostring(g.cid)]
    return chosen and chosen[city]
end

-- ワープに使うクエスト。このキャラで選んだものが使えればそれ、使えなければ探す順で最初に使えるもの。
-- ショートカットを押している間は 0.2 秒ごとに呼ばれるので、全件はそろえず見つけた時点で打ち切る。
function Lets_go_home_pick_quest(city)
    local chosen = Lets_go_home_chosen_quest(city)
    if chosen and Lets_go_home_quest_usable(chosen, city) then
        return chosen
    end
    local picked = nil
    Lets_go_home_each_quest(city, function(quest_id)
        if quest_id ~= chosen and Lets_go_home_quest_usable(quest_id, city) then
            picked = quest_id
            return true
        end
    end)
    return picked
end

function lets_go_home_on_init()
    if not g.lets_go_home_settings then
        Lets_go_home_load_settings()
    end
    local old_func = g.settings.lets_go_home.old_init_func
    if _G[old_func] then
        return
    end
    if g.settings.lets_go_home.use == 0 then
        local lets_go_home = ui.GetFrame(addon_name_lower .. "lets_go_home")
        if lets_go_home then
            ui.DestroyFrame(lets_go_home:GetName())
        end
        local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
        _nexus_addons_p:SetVisible(1)
        local lets_go_home_timer = GET_CHILD(_nexus_addons_p, "lets_go_home_timer")
        if lets_go_home_timer then
            AUTO_CAST(lets_go_home_timer)
            lets_go_home_timer:Stop()
        end
        return
    end
    Lets_go_home_frame_init()
    if g.lets_go_home_warp_state == 1 then
        Lets_go_home_change_move()
    end
end

function Lets_go_home_frame_init()
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    _nexus_addons_p:SetVisible(1)
    local lets_go_home_timer = _nexus_addons_p:CreateOrGetControl("timer", "lets_go_home_timer", 0, 0)
    AUTO_CAST(lets_go_home_timer)
    lets_go_home_timer:SetUpdateScript("Lets_go_home_key_press")
    lets_go_home_timer:Start(0.2)
    if g.lets_go_home_settings.display == 0 then
        return
    end
    local lets_go_home = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "lets_go_home", 0, 0, 0, 0)
    AUTO_CAST(lets_go_home)
    lets_go_home:SetSkinName('None')
    lets_go_home:SetTitleBarSkin("None")
    lets_go_home:Resize(40, 30)
    lets_go_home:SetGravity(ui.RIGHT, ui.TOP)
    lets_go_home:EnableHitTest(1)
    lets_go_home:EnableHittestFrame(1)
    lets_go_home:EnableMove(g.lets_go_home_settings.move)
    local rect = lets_go_home:GetMargin()
    lets_go_home:SetMargin(rect.left - rect.left, rect.top - rect.top + 305, rect.right + 305, rect.bottom)
    if g.lets_go_home_settings.x ~= 0 and g.lets_go_home_settings.y ~= 0 then
        lets_go_home:SetPos(g.lets_go_home_settings.x, g.lets_go_home_settings.y)
    end
    local btn = lets_go_home:CreateOrGetControl('button', 'home', 0, 0, 30, 30)
    AUTO_CAST(btn)
    btn:SetGravity(ui.LEFT, ui.TOP)
    btn:SetSkinName("None")
    btn:SetText("{img btn_housing_editmode_small_resize 30 30}")
    btn:SetTextTooltip(g.lang == "Japanese" and
                           "{ol}右クリック:ホーム設定{nl}左クリック:ワープ{nl}ショートカット:BackSlash+RSHIFT" or
                           "{ol}Rightclick:Home Setting{nl}Leftclick:Warp{nl}Shortcut:BackSlash+RSHIFT")
    btn:SetEventScript(ui.RBUTTONUP, "Lets_go_home_settings")
    btn:SetEventScript(ui.LBUTTONDOWN, "Lets_go_home_warp_do")
    lets_go_home:ShowWindow(1)
    btn:SetEventScript(ui.LBUTTONUP, "Lets_go_home_frame_move_save")
    lets_go_home:RunUpdateScript("Lets_go_home_update_frame", 1.0)
end

function Lets_go_home_frame_move_save(lets_go_home)
    g.lets_go_home_settings.x = lets_go_home:GetX()
    g.lets_go_home_settings.y = lets_go_home:GetY()
    Lets_go_home_save_settings()
end

function Lets_go_home_settings_frame_close(list_frame)
    ui.DestroyFrame(list_frame:GetName())
end

function Lets_go_home_settings_frame()
    local lets_go_home_setting = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "lets_go_home_setting", 0, 0, 0,
        0)
    lets_go_home_setting:Resize(370, 280)
    -- 位置は g.settings_frame_pos に任せる(一覧が開いていなければ画面中央)。
    -- **素で list_frame:GetX() を呼ばないこと。** Addons Menu のショートカットから
    -- 開くと一覧は開いておらず nil で落ちる = 空の窓が出る(g.settings_frame_pos のコメント)。
    lets_go_home_setting:SetPos(g.settings_frame_pos(370, 280))
    lets_go_home_setting:SetSkinName("test_frame_low")
    lets_go_home_setting:EnableHittestFrame(1)
    lets_go_home_setting:EnableHitTest(1)
    lets_go_home_setting:SetLayerLevel(999)
    lets_go_home_setting:ShowWindow(1)
    g.esc_register_destroy(addon_name_lower .. "lets_go_home_setting")
    local title_text = lets_go_home_setting:CreateOrGetControl('richtext', 'title_text', 20, 15, 50, 30)
    AUTO_CAST(title_text)
    title_text:SetText("{ol}Lets Go Home Config")
    local close = lets_go_home_setting:CreateOrGetControl("button", "close", 0, 0, 20, 20)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Lets_go_home_settings_frame_close")
    local gbox = lets_go_home_setting:CreateOrGetControl("groupbox", "gbox", 10, 40,
        lets_go_home_setting:GetWidth() - 20, lets_go_home_setting:GetHeight() - 50)
    AUTO_CAST(gbox)
    gbox:SetSkinName("test_frame_midle_light")
    local map_text = gbox:CreateOrGetControl('richtext', 'map_text', 10, 10, 150, 30)
    AUTO_CAST(map_text)
    map_text:SetText(g.lang == "Japanese" and "{ol}ホームタウン" or "{ol}Hometown")
    local map_drop_list = gbox:CreateOrGetControl('droplist', 'map_drop_list', 150, 10, 180, 20)
    AUTO_CAST(map_drop_list)
    map_drop_list:SetSkinName('droplist_normal')
    map_drop_list:EnableHitTest(1)
    map_drop_list:SetTextAlign("center", "center")
    local citys = g.lets_go_home_citys
    local selected_index = 0
    map_drop_list:AddItem(0, g.lang == "Japanese" and "{ol}未設定" or "{ol}None", 0, "Lets_go_home_map_settings('')")
    for i, city_class_name in ipairs(citys) do
        local map_cls = GetClass("Map", city_class_name)
        if map_cls then
            local scp = string.format("Lets_go_home_map_settings('%s')", city_class_name)
            map_drop_list:AddItem(i, "{ol}" .. map_cls.Name, 0, scp)
            if g.lets_go_home_settings.map == city_class_name then
                selected_index = i
            end
        end
    end
    map_drop_list:SelectItem(selected_index)
    local ch_text = gbox:CreateOrGetControl('richtext', 'ch_text', 10, 40, 150, 30)
    AUTO_CAST(ch_text)
    ch_text:SetText(g.lang == "Japanese" and "{ol}チャンネル" or "{ol}Channel")
    local ch_drop_list = gbox:CreateOrGetControl('droplist', 'ch_drop_list', 150, 40, 180, 20)
    AUTO_CAST(ch_drop_list)
    ch_drop_list:SetSkinName('droplist_normal')
    ch_drop_list:EnableHitTest(1)
    ch_drop_list:SetTextAlign("center", "center")
    for i = 1, 10 do
        local scp = string.format("Lets_go_home_ch_settings(%d)", i)
        ch_drop_list:AddItem(i - 1, "{ol}" .. tostring(i) .. " ch", 0, scp)
        if g.lets_go_home_settings.ch == i then
            selected_index = i - 1
        end
    end
    ch_drop_list:SelectItem(selected_index)
    local btn_move = gbox:CreateOrGetControl('checkbox', "btn_move", 10, 70, 30, 30)
    AUTO_CAST(btn_move)
    btn_move:SetText(g.lang == "Japanese" and "{ol}ボタン位置固定" or "{ol}Fix button position")
    btn_move:SetTextTooltip(g.lang == "Japanese" and "{ol}チェックするとボタン固定" or
                                "{ol}Checked: the button is fixed")
    btn_move:SetEventScript(ui.LBUTTONUP, "Lets_go_home_check_toggle")
    btn_move:SetCheck(g.lets_go_home_settings.move)
    local btn = gbox:CreateOrGetControl('button', 'home', 210, 70, 80, 30)
    AUTO_CAST(btn)
    btn:SetText(g.lang == "Japanese" and "{ol}ボタン初期位置" or "{ol}Btn Init Pos")
    btn:SetEventScript(ui.LBUTTONUP, "Lets_go_home_init_pos")
    local btn_display = gbox:CreateOrGetControl('checkbox', "btn_display", 10, 100, 30, 30)
    AUTO_CAST(btn_display)
    btn_display:SetText(g.lang == "Japanese" and "{ol}ボタン表示設定" or "{ol}Button display settings")
    btn_display:SetTextTooltip(g.lang == "Japanese" and "{ol}チェックするとボタン表示" or
                                   "{ol}Checked: the button is shown")
    btn_display:SetEventScript(ui.LBUTTONUP, "Lets_go_home_check_toggle")
    btn_display:SetCheck(g.lets_go_home_settings.display)
    local short_cut = gbox:CreateOrGetControl('checkbox', "short_cut", 10, 130, 30, 30)
    AUTO_CAST(short_cut)
    short_cut:SetText(g.lang == "Japanese" and "{ol}ショートカット設定(BackSlash+RSHIFT)" or
                          "{ol}Shortcut Setting(BackSlash+RSHIFT)")
    short_cut:SetTextTooltip(g.lang == "Japanese" and "{ol}チェックするとショートカット有効化" or
                                 "{ol}Checked: enables the shortcut")
    short_cut:SetEventScript(ui.LBUTTONUP, "Lets_go_home_check_toggle")
    short_cut:SetCheck(g.lets_go_home_settings.short_cut)
    local arrival_text = gbox:CreateOrGetControl('richtext', 'arrival_text', 10, 165, 150, 30)
    AUTO_CAST(arrival_text)
    arrival_text:SetText(g.lang == "Japanese" and "{ol}到着後の移動先" or "{ol}Move after arrival")
    arrival_text:SetTextTooltip(g.lang == "Japanese" and "{ol}ホームに着いたら、選んだ NPC の前まで移動します" or
                                    "{ol}After arriving home, move to the selected NPC")
    local arrival_list = gbox:CreateOrGetControl('droplist', 'arrival_list', 150, 160, 180, 20)
    AUTO_CAST(arrival_list)
    arrival_list:SetSkinName('droplist_normal')
    arrival_list:EnableHitTest(1)
    arrival_list:SetTextAlign("center", "center")
    local arrival_index = 0
    for i, arrival in ipairs(g.lets_go_home_arrivals) do
        local label = g.lang == "Japanese" and arrival.ja or arrival.en
        arrival_list:AddItem(i - 1, "{ol}" .. label, 0,
            string.format("Lets_go_home_arrival_settings('%s')", arrival.key))
        if g.lets_go_home_settings.arrival == arrival.key then
            arrival_index = i - 1
        end
    end
    arrival_list:SelectItem(arrival_index)
    local quest_text = gbox:CreateOrGetControl('richtext', 'quest_text', 10, 195, 150, 30)
    AUTO_CAST(quest_text)
    quest_text:SetText(g.lang == "Japanese" and "{ol}クエストワープ" or "{ol}Quest warp")
    quest_text:SetTextTooltip(g.lang == "Japanese" and
                                  "{ol}このキャラで使うクエストワープ(キャラごとに覚えます){nl}ホームタウンへ今ワープできるクエストだけ並びます{nl}選んだものが使えなくなったら、残っているものを使います" or
                                  "{ol}The quest warp this character uses (remembered per character){nl}Only quests that can warp to the hometown now are listed{nl}If the chosen one is no longer usable, a remaining one is used")
    local quest_list = gbox:CreateOrGetControl('droplist', 'quest_list', 150, 190, 180, 20)
    AUTO_CAST(quest_list)
    quest_list:SetSkinName('droplist_normal')
    quest_list:EnableHitTest(1)
    quest_list:SetTextAlign("center", "center")
    Lets_go_home_quest_list_build(quest_list)
end

-- クエストワープの一覧を、このキャラと今のホームタウンで作り直す。使えるものが無ければ空のまま(空白になる)。
-- 既定で選ぶのは、いまワープしたら使われるもの(Lets_go_home_pick_quest)。
function Lets_go_home_quest_list_build(quest_list)
    quest_list:ClearItems()
    local city = g.lets_go_home_settings.map
    if city == "" then
        return
    end
    local picked = Lets_go_home_pick_quest(city)
    local available = Lets_go_home_available_quests(city)
    g.vlog("lets_go_home: クエストワープの候補 map=%s 使える=%d 件 選択=%s 既定=%s", city, #available,
        tostring(Lets_go_home_chosen_quest(city)), tostring(picked))
    -- 同じ名前のクエストが並ぶと見分けられないので、そのときだけ ClassID を添える
    local name_count = {}
    for _, quest_id in ipairs(available) do
        local name = GetClassByType('QuestProgressCheck', quest_id).Name
        name_count[name] = (name_count[name] or 0) + 1
    end
    for i, quest_id in ipairs(available) do
        local name = GetClassByType('QuestProgressCheck', quest_id).Name
        local label = name_count[name] > 1 and string.format("%s (%d)", name, quest_id) or name
        -- 都市も一緒に渡す。一覧を開いたままホームを右クリック登録で変えても、一覧の都市へ保存する
        quest_list:AddItem(i - 1, "{ol}" .. label, 0,
            string.format("Lets_go_home_quest_settings('%s', %d)", city, quest_id))
        if quest_id == picked then
            quest_list:SelectItem(i - 1)
        end
    end
end

function Lets_go_home_quest_settings(city, quest_id)
    local cid = tostring(g.cid)
    g.lets_go_home_settings.quest[cid] = g.lets_go_home_settings.quest[cid] or {}
    g.lets_go_home_settings.quest[cid][city] = quest_id
    g.vlog("lets_go_home: クエストワープを選択 cid=%s map=%s quest=%d", cid, city, quest_id)
    Lets_go_home_save_settings()
end

function Lets_go_home_arrival_settings(key)
    g.lets_go_home_settings.arrival = key
    Lets_go_home_save_settings()
end

function Lets_go_home_map_settings(city_class_name)
    g.lets_go_home_settings.map = city_class_name
    Lets_go_home_save_settings()
    -- クエストワープの候補は都市ごとなので、ホームタウンを変えたら作り直す
    local lets_go_home_setting = ui.GetFrame(addon_name_lower .. "lets_go_home_setting")
    if lets_go_home_setting then
        local quest_list = GET_CHILD_RECURSIVELY(lets_go_home_setting, "quest_list")
        if quest_list then
            AUTO_CAST(quest_list)
            Lets_go_home_quest_list_build(quest_list)
        end
    end
end

function Lets_go_home_ch_settings(channel)
    g.lets_go_home_settings.ch = channel
    Lets_go_home_save_settings()
end

function Lets_go_home_check_toggle(parent, ctrl)
    local ctrl_name = ctrl:GetName()
    local is_check = ctrl:IsChecked()
    if ctrl_name == "btn_move" then
        g.lets_go_home_settings.move = is_check
    elseif ctrl_name == "btn_display" then
        g.lets_go_home_settings.display = is_check
        if is_check == 0 then
            local lets_go_home = ui.GetFrame(addon_name_lower .. "lets_go_home")
            if lets_go_home then
                ui.DestroyFrame(lets_go_home:GetName())
            end
        else
            Lets_go_home_frame_init()
        end
    elseif ctrl_name == "short_cut" then
        g.lets_go_home_settings.short_cut = is_check
    end
    Lets_go_home_save_settings()
end

function Lets_go_home_init_pos()
    g.lets_go_home_settings.x = 0
    g.lets_go_home_settings.y = 0
    Lets_go_home_save_settings()
    local lets_go_home = ui.GetFrame(addon_name_lower .. "lets_go_home")
    if lets_go_home then
        ui.DestroyFrame(lets_go_home:GetName())
    end
    ReserveScript("Lets_go_home_frame_init()", 0.1)
end

function Lets_go_home_settings()
    if g.get_map_type() == "City" then
        local msg = g.lang == "Japanese" and "現在のマップとチャンネルをホームにしますか？" or
                        "Do you want to home in on the current map and channel?"
        local yes_scp = string.format("Lets_go_home_settings_reg()")
        ui.MsgBox(msg, yes_scp, "None")
    else
        ui.SysMsg(g.lang == "Japanese" and "このマップは設定できません" or "This map cannot be set up")
    end
end

function Lets_go_home_settings_reg()
    local channel = session.loginInfo.GetChannel() + 1
    local map_cls = GetClass("Map", g.map_name)
    local map_clas_name = map_cls.ClassName
    local map_name = map_cls.Name
    g.lets_go_home_settings.ch = channel
    g.lets_go_home_settings.map = map_clas_name
    Lets_go_home_save_settings()
    -- 到着後の移動先は 3 択になったので、登録のたびに聞かずに設定の窓で選んでもらう(登録しても変えない)
    local arrival_label = ""
    for _, arrival in ipairs(g.lets_go_home_arrivals) do
        if arrival.key == g.lets_go_home_settings.arrival then
            arrival_label = g.lang == "Japanese" and arrival.ja or arrival.en
        end
    end
    ui.SysMsg(g.lang == "Japanese" and "マップ名: " .. map_name .. " チャンネル: " .. channel ..
                  "を登録{nl}到着後の移動先: " .. arrival_label .. "(設定の窓で変えられます)" or "MapName: " ..
                  map_name .. " Channel: " .. channel .. " Registered{nl}Move after arrival: " .. arrival_label ..
                  " (change it in the settings)")
end

function Lets_go_home_update_frame(lets_go_home)
    local home = GET_CHILD(lets_go_home, "home")
    local cd_text = home:CreateOrGetControl('richtext', 'cd_text', 5, 10)
    AUTO_CAST(cd_text)
    local cd = GET_TOKEN_WARP_COOLDOWN()
    cd_text:SetText("{ol}{#FFFFFF}{s13}" .. cd)
    if cd >= 100 then
        cd_text:ShowWindow(1)
        return 1
    elseif cd < 100 and cd >= 10 then
        cd_text:SetOffset(9, 10)
        return 1
    elseif cd < 10 and cd >= 1 then
        cd_text:SetOffset(13, 10)
        return 1
    else
        cd_text:ShowWindow(0)
        return 0
    end
end

function Lets_go_home_warp_do()
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    g.lets_go_home_warp_state = 1
    Lets_go_home_change_move(_nexus_addons_p)
end

function Lets_go_home_key_press(_nexus_addons_p, lets_go_home_timer)
    if g.lets_go_home_settings.short_cut == 0 then
        return
    end
    if 1 == keyboard.IsKeyPressed("BACKSLASH") and 1 == keyboard.IsKeyPressed("RSHIFT") then
        g.lets_go_home_warp_state = 1
        Lets_go_home_change_move()
    end
end

function Lets_go_home_change_move()
    if ENABLE_WARP_CHECK(GetMyPCObject()) == false then
        ui.SysMsg(ScpArgMsg("WarpBanBountyHunt"))
        g.lets_go_home_warp_state = 0
        return
    end
    local save_map = g.lets_go_home_settings.map
    if save_map == "" then
        ui.MsgBox(g.lang == "Japanese" and "マップ未設定です" or "Not Map setting")
        g.lets_go_home_warp_state = 0
        return
    end
    if save_map ~= g.map_name then
        local quest_id = Lets_go_home_pick_quest(save_map)
        g.vlog("lets_go_home: クエストワープ map=%s 選択=%s 使う=%s", save_map,
            tostring(Lets_go_home_chosen_quest(save_map)), tostring(quest_id))
        if quest_id then
            QUESTION_QUEST_WARP(nil, nil, nil, quest_id)
        else
            Lets_go_home_not_quest_warp(save_map)
        end
        return
    end
    local save_ch = g.lets_go_home_settings.ch
    local channel = session.loginInfo.GetChannel() + 1
    if channel ~= save_ch then
        RUN_GAMEEXIT_TIMER("Channel", save_ch - 1)
        return
    end
    g.lets_go_home_warp_state = 0
    local arrival = g.lets_go_home_settings.arrival
    g.vlog("lets_go_home: ホームに着いた map=%s 到着後の移動先=%s", g.map_name, tostring(arrival))
    if arrival == "leticia" then
        Lets_go_home_leticia_move()
    elseif arrival == "warehouse" then
        Lets_go_home_warehouse_move()
    end
end

function Lets_go_home_not_quest_warp(save_map)
    local cd = GET_TOKEN_WARP_COOLDOWN()
    if cd == 0 then
        g.lets_go_home_warp_state = 1
        WORLDMAP2_TOKEN_WARP_REQUEST(save_map)
        return
    end
    local warp_items = {
        ["c_Klaipe"] = 640073,
        ["c_orsha"] = 640156,
        ["c_fedimian"] = 640182
    }
    session.ResetItemList()
    local inv_item_list = session.GetInvItemList()
    local guid_list = inv_item_list:GetGuidList()
    local cnt = guid_list:Count()
    for i = 0, cnt - 1 do
        local guid = guid_list:Get(i)
        local inv_item = inv_item_list:GetItemByGuid(guid)
        local item_obj = GetIES(inv_item:GetObject())
        local target_id = warp_items[save_map]
        if item_obj.ClassID == target_id and g.map_name ~= save_map then
            if TRY_TO_USE_WARP_ITEM(inv_item, item_obj) ~= 1 then
                g.lets_go_home_warp_state = 1
                INV_ICON_USE(inv_item)
                return
            end
        end
    end
    ui.MsgBox(g.lang == "Japanese" and "ワープする方法がありません" or "There is no way to warp")
    g.lets_go_home_warp_state = 0
end

function Lets_go_home_leticia_move()
    local guid = 309
    local cls = GetClassByType("full_screen_navigation_menu", guid)
    if cls ~= nil then
        local name = TryGetProp(cls, "Name", "None")
        local move_zone_select = TryGetProp(cls, "MoveZoneSelect", "NO")
        local move_zone = TryGetProp(cls, "MoveZone", "None")
        local move_npc_dialog = TryGetProp(cls, "MoveNpcDialog", "None")
        local move_zone_select_msg = TryGetProp(cls, "MoveZoneSelectMsg", "None")
        local move_only_in_town = TryGetProp(cls, "MoveOnlyInTown", "None")
        if move_zone ~= "None" and move_npc_dialog ~= "None" then
            if not Lets_go_home_can_move_npc() then
                return
            end
            FullScreenMenuMoveNpc(name, move_zone_select, move_zone, move_npc_dialog, move_zone_select_msg,
                move_only_in_town)
            ui.CloseFrame("fullscreen_navigation_menu")
        end
    end
end
-- NPC の前へ移動してよい場所か。ナビゲーションメニューの移動と同じ制限。
-- 駄目なら素と同じ文言を出して false を返す。
function Lets_go_home_can_move_npc()
    local pc = GetMyPCObject()
    if session.world.IsIntegrateServer() == true or IsPVPField(pc) == 1 or IsPVPServer(pc) == 1 then
        ui.SysMsg(ScpArgMsg("ThisLocalUseNot"))
        return false
    end
    if world.GetLayer() ~= 0 then
        ui.SysMsg(ScpArgMsg("ThisLocalUseNot"))
        return false
    end
    if g.get_map_type() == "Dungeon" then
        ui.SysMsg(ScpArgMsg("ThisLocalUseNot"))
        return false
    end
    local cur_map = GetClass("Map", session.GetMapName())
    local zoneKeyword = TryGetProp(cur_map, 'Keyword', 'None')
    local keywordTable = StringSplit(zoneKeyword, '')
    if table.find(keywordTable, 'IsRaidField') > 0 or table.find(keywordTable, 'WeeklyBossMap') > 0 then
        ui.SysMsg(ScpArgMsg('ThisLocalUseNot'))
        return false
    end
    return true
end

-- 今いる都市の倉庫番の前へ移動する。ナビゲーションメニューに倉庫番は無いので、
-- ダイアログ名を直接渡す(Archeology Helper のアイリーネへの移動と同じやり方)。
function Lets_go_home_warehouse_move()
    local map_name = session.GetMapName()
    local dialog = nil
    for _, arrival in ipairs(g.lets_go_home_arrivals) do
        if arrival.key == "warehouse" then
            dialog = arrival.dialog[map_name]
        end
    end
    if not dialog then
        g.vlog("lets_go_home: %s には倉庫番の定義が無いので移動しない", map_name)
        return
    end
    if not Lets_go_home_can_move_npc() then
        return
    end
    local name = g.lang == "Japanese" and "倉庫番" or "Warehouse keeper"
    g.vlog("lets_go_home: 倉庫番へ移動する map=%s dialog=%s", map_name, dialog)
    FullScreenMenuMoveNpc(name, "NO", map_name, dialog, "None", "YES")
end
-- lets_go_home　ここまで

