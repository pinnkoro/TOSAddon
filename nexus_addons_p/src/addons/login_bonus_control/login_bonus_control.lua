-- Login Bonus Control ここから
--
-- ログインボーナス(素の「出席報酬確認」)を、キャラごとに
--   表示する(素のまま) / 表示しない / 自動で受け取る
-- のどれかにする。
--
-- 素の流れ(addon.ipf/attendance/attendance.lua, listselect_ui/listselect_ui.lua):
--   1. 受け取っていない報酬があると、サーバーから ATTENDANCE_REWARD_CHECK_UI_ON が届く
--   2. 素の ATTENDANCE_REWARD_CHECK_UI_ON が 2 秒後に ATTENDANCE_LIST_TOGGLE_UI() を予約し、
--      出席チェックの一覧(listselect_ui)が開く
--   3. 一覧の行を押すと ATTENDANCE_TOGGLE_UI → ATTENDANCE_GIVE_REWARD(id) →
--      AttendanceRewardClick(id) で受け取りの要求が飛ぶ
--   4. 受け取ると UPDATE_ATTENDANCE_REWARD が届き、素の ON_ATTENDANCE_RESULT が出席表を開く
--
-- ここでは 1 の受け口(ATTENDANCE_REWARD_CHECK_UI_ON)を置換方式で掴み、キャラの設定で分ける。
-- **一覧を開くボタン(システムメニューのカレンダー)は ATTENDANCE_LIST_TOGGLE_UI を直接呼ぶ**ので、
-- 「表示しない」にしても手で開く経路は素のまま残る。
--
-- 自動で受け取るときは素の ATTENDANCE_GIVE_REWARD を呼ぶ(「今日もう受け取ったか」の判定は
-- 素に任せる)。実際に要求が飛んだかは AttendanceRewardClick のフックで拾い、
-- その ID の出席表(4)だけを開かずにチャットへ知らせる。
--
-- 設定はアカウント単位のファイルに、キャラの CID ごとに持つ。名前は表示用の控え。
--
-- 関数は local にせずグローバルの Login_bonus_control_* にしている(bundle の local 200 個上限)。

-- キャラごとのモード。default は「未登録のキャラの既定」に従う。既定のほうに default は選べない。
g.login_bonus_control_modes = {{
    key = "default",
    ja = "既定に従う",
    en = "Follow default"
}, {
    key = "show",
    ja = "表示する",
    en = "Show"
}, {
    key = "hide",
    ja = "表示しない",
    en = "Hide"
}, {
    key = "auto",
    ja = "自動で受け取る",
    en = "Auto receive"
}}

-- 設定 JSON のキー。**CID をそのままキーにしない**(数字だけの文字列は配列と取り違えられうる。
-- docs/NEW_ADDON.md §3)。
function Login_bonus_control_char_key(cid)
    return "cid_" .. tostring(cid)
end

function Login_bonus_control_save_settings()
    g.save_json(g.login_bonus_control_path, g.login_bonus_control_settings)
end

-- 設定を読む。**ファイルへは書かない**(書くのはキャラの登録と、設定画面で変えたときだけ)。
-- フックはアドオンが OFF でも素通しのために走るので、ここで書くと使っていない利用者にもファイルができる。
--
-- アカウント ID は g.active_id ではなくその場で引く。フックは ON_INIT より先に呼ばれうるので、
-- 別アカウントへ入り直した直後だと g.active_id が前のアカウントのまま残っている。
function Login_bonus_control_settings()
    local aid = session.loginInfo.GetAID()
    if g.login_bonus_control_settings and g.login_bonus_control_aid == aid then
        return g.login_bonus_control_settings
    end
    g.login_bonus_control_aid = aid
    g.login_bonus_control_path = string.format("../addons/%s/%s/login_bonus_control.json", addon_name_lower, aid)
    local settings = g.load_json(g.login_bonus_control_path)
    if type(settings) ~= "table" then
        settings = {}
    end
    if settings.default_mode ~= "show" and settings.default_mode ~= "hide" and settings.default_mode ~= "auto" then
        settings.default_mode = "show"
    end
    if type(settings.chars) ~= "table" then
        settings.chars = {}
    end
    g.login_bonus_control_settings = settings
    return settings
end

-- アドオンが ON か。g.settings は GAME_START で読まれるので、**ゲームを起動して最初のキャラでは
-- ATTENDANCE_REWARD_CHECK_UI_ON がそれより先に届く**(素はロード画面が閉じるのを待つために
-- 2 秒遅らせている)。そのときは settings.json を直に読んで判定する。
function Login_bonus_control_enabled()
    if g.settings and g.settings.login_bonus_control then
        return g.settings.login_bonus_control.use == 1
    end
    local ok, settings = pcall(function()
        return g.load_json(string.format("../addons/%s/%s/settings.json", addon_name_lower,
            session.loginInfo.GetAID()))
    end)
    if ok and type(settings) == "table" and type(settings.login_bonus_control) == "table" then
        return settings.login_bonus_control.use == 1
    end
    return false
end

-- 今のキャラのモード(show / hide / auto)。OFF なら show(素のまま)。
-- CID は g.cid ではなくその場で引く(キャラを替えた直後は ON_INIT より先に呼ばれうる)。
function Login_bonus_control_current_mode()
    if not Login_bonus_control_enabled() then
        return "show"
    end
    local settings = Login_bonus_control_settings()
    local cid = session.GetMySession():GetCID()
    local entry = settings.chars[Login_bonus_control_char_key(cid)]
    local mode = entry and entry.mode or "default"
    if mode == "default" then
        mode = settings.default_mode
    end
    return mode
end

-- 掛けるフック。**ゲームを起動して最初のキャラ**では on_init(GAME_START の後、分割実行で
-- さらに遅れうる)より先に ATTENDANCE_REWARD_CHECK_UI_ON が届くので、読み込みの時点でも掛ける
-- (この関数をファイルの末尾で 1 回呼ぶ)。素の関数がまだ定義されていなければ掛けない。
-- 控えが nil で確定してしまい、以後ずっと素を呼べなくなるため(g.setup_hook の hook_captured)。
-- 素が後から読み込まれて上書きされても、on_init で掛け直される。
function Login_bonus_control_install_hooks()
    local hooks = {{Login_bonus_control_ATTENDANCE_REWARD_CHECK_UI_ON, "ATTENDANCE_REWARD_CHECK_UI_ON"},
                   {Login_bonus_control_ON_ATTENDANCE_RESULT, "ON_ATTENDANCE_RESULT"},
                   {Login_bonus_control_AttendanceRewardClick, "AttendanceRewardClick"}}
    local installed = 0
    for _, hook in ipairs(hooks) do
        if type(_G[hook[2]]) == "function" then
            g.setup_hook(hook[1], hook[2])
            installed = installed + 1
        end
    end
    return installed
end

function login_bonus_control_on_init()
    Login_bonus_control_install_hooks()
    -- 読み込みの時点で掛けられていたか。**最初のキャラで効くかどうかはこれで決まる**ので、
    -- 実機のログで確かめられるように 1 回だけ出す。
    if not g.login_bonus_control_load_logged then
        g.login_bonus_control_load_logged = true
        g.vlog("login_bonus_control: 読み込み時のフック %d/3", g.login_bonus_control_hooked_at_load or 0)
    end
    if g.settings.login_bonus_control.use == 1 then
        Login_bonus_control_sync_chars()
    end
end

-- 今のキャラと、同じバラックの層に居るキャラを一覧へ登録する(名前は毎回書き直す。改名に追従するため)。
-- 書くのは変わったときだけ。
function Login_bonus_control_sync_chars()
    local settings = Login_bonus_control_settings()
    local changed = false
    local function upsert(cid, name)
        if not cid or cid == "" or not name or name == "" then
            return
        end
        local key = Login_bonus_control_char_key(cid)
        local entry = settings.chars[key]
        if not entry then
            settings.chars[key] = {
                name = name,
                mode = "default"
            }
            changed = true
        elseif entry.name ~= name then
            entry.name = name
            changed = true
        end
    end
    upsert(session.GetMySession():GetCID(), session.GetMySession():GetPCApc():GetName())
    local acc_info = session.barrack.GetMyAccount()
    if acc_info then
        for i = 0, acc_info:GetPCCount() - 1 do
            local pc_info = acc_info:GetPCByIndex(i)
            if pc_info then
                local pc_apc = pc_info:GetApc()
                if pc_apc then
                    upsert(pc_info:GetCID(), pc_apc:GetName())
                end
            end
        end
    end
    if changed then
        Login_bonus_control_save_settings()
    end
end

-- 置換方式フック。受け取っていない報酬があるときにサーバーから届く。
-- 引数は数を決め打ちせずそのまま素へ渡す。
function Login_bonus_control_ATTENDANCE_REWARD_CHECK_UI_ON(...)
    local origin = g.FUNCS["ATTENDANCE_REWARD_CHECK_UI_ON"]
    local ok, mode = pcall(Login_bonus_control_current_mode)
    if not ok then
        -- 判定で転んだら素のままにする(画面が出ないより、出るほうが害が小さい)
        g.vlog("{#FF6347}login_bonus_control: モードの判定に失敗したので素のまま err=%s{/}", tostring(mode))
        mode = "show"
    end
    g.vlog("login_bonus_control: ATTENDANCE_REWARD_CHECK_UI_ON mode=%s", mode)
    -- 統合サーバーでは素も一覧を出さない。自動で受け取るのもやめて素に任せる
    if mode == "show" or session.world.IsIntegrateServer() == true then
        if origin then
            return origin(...)
        end
        return
    end
    if mode == "auto" then
        -- 素と同じく、ロード画面が閉じるのを待ってから
        ReserveScript("Login_bonus_control_receive_all()", 2)
    end
end

-- 置換方式フック。出席表を開く素の関数。
--   UPDATE_ATTENDANCE_REWARD … 受け取った直後。こちらが自動で受け取った ID なら開かずにチャットで知らせる
--   GAME_START             … 素は GetNeedToShow() が 0 でなければ出席表を開く。表示しない / 自動のキャラでは開かない
-- それ以外(カレンダーのボタンから開いたときなど)は素のまま。
function Login_bonus_control_ON_ATTENDANCE_RESULT(frame, msg, arg_str, arg_num, ...)
    local origin = g.FUNCS["ON_ATTENDANCE_RESULT"]
    if msg == "UPDATE_ATTENDANCE_REWARD" or msg == "GAME_START" then
        local ok, id = pcall(function()
            return GET_ATTENDANCE_ID_NEED_TO_SHOW(arg_num or 0)
        end)
        id = ok and id or 0
        if msg == "UPDATE_ATTENDANCE_REWARD" and g.login_bonus_control_sent and g.login_bonus_control_sent[id] then
            g.login_bonus_control_sent[id] = nil
            -- 受け取りごとに 1 行だけ(毎フレームの経路ではない)。出席表を止めた証跡として残す
            g.vlog("login_bonus_control: 受け取った id=%s 出席表は開かずにチャットへ知らせる", tostring(id))
            Login_bonus_control_notify(id)
            return
        end
        if msg == "GAME_START" and id ~= 0 then
            local mode_ok, mode = pcall(Login_bonus_control_current_mode)
            g.vlog("login_bonus_control: GAME_START の出席表 id=%s mode=%s", tostring(id), tostring(mode))
            if mode_ok and (mode == "hide" or mode == "auto") then
                return
            end
        end
    end
    if origin then
        return origin(frame, msg, arg_str, arg_num, ...)
    end
end

-- 置換方式フック(素はネイティブ)。自動受け取りの最中に呼ばれたら、要求が飛んだ ID として控える。
-- 判定は素の ATTENDANCE_GIVE_REWARD に任せたまま、「実際に送ったか」だけをここで知る。
function Login_bonus_control_AttendanceRewardClick(id, ...)
    if g.login_bonus_control_capturing then
        g.login_bonus_control_sent = g.login_bonus_control_sent or {}
        g.login_bonus_control_sent[tonumber(id) or id] = true
        g.login_bonus_control_capture_hit = true
    end
    local origin = g.FUNCS["AttendanceRewardClick"]
    if origin then
        return origin(id, ...)
    end
end

-- 開催中の出席チェックを順に受け取る。並べ方は素の一覧(ATTENDANCE_LIST_CHECK)と同じ条件。
function Login_bonus_control_receive_all()
    local list, cnt = GetClassList("TPEventAttendance")
    if not list then
        return
    end
    g.login_bonus_control_sent = {}
    local queue = {}
    for i = 0, cnt - 1 do
        local cls = GetClassByIndexFromList(list, i)
        if cls and session.attendance.GetAttendanceData(cls.ClassID) ~= nil and
            CHECK_ATTENDANCE_VALID(cls.ClassID) == true then
            table.insert(queue, cls.ClassID)
        end
    end
    g.login_bonus_control_queue = queue
    g.login_bonus_control_sent_count = 0
    g.vlog("login_bonus_control: 自動受け取り 対象 %d 件", #queue)
    Login_bonus_control_receive_next()
end

-- 1 件ずつ送る。送ったら少し空けて次へ(サーバーへ要求をまとめて投げない)。
function Login_bonus_control_receive_next()
    local queue = g.login_bonus_control_queue or {}
    while #queue > 0 do
        local id = table.remove(queue, 1)
        g.login_bonus_control_capturing = true
        g.login_bonus_control_capture_hit = false
        local ok, err = pcall(function()
            ATTENDANCE_GIVE_REWARD(id)
        end)
        g.login_bonus_control_capturing = nil
        g.vlog("login_bonus_control: id=%s 送った=%s%s", tostring(id), tostring(g.login_bonus_control_capture_hit),
            ok and "" or (" err=" .. tostring(err)))
        if g.login_bonus_control_capture_hit then
            g.login_bonus_control_sent_count = g.login_bonus_control_sent_count + 1
            if #queue > 0 then
                ReserveScript("Login_bonus_control_receive_next()", 0.5)
            end
            return
        end
    end
    if g.login_bonus_control_sent_count == 0 then
        g.vlog("login_bonus_control: 受け取れるものは無かった")
    end
end

function Login_bonus_control_notify(id)
    local cls = GetClassByType("TPEventAttendance", id)
    local name = cls and cls.Name or tostring(id)
    CHAT_SYSTEM(string.format(g.lang == "Japanese" and "[LBC] 出席報酬「%s」を受け取りました" or
                                  "[LBC] Received the attendance reward \"%s\"", name))
end

-- 設定画面 ------------------------------------------------------------------

function Login_bonus_control_mode_label(key)
    for _, def in ipairs(g.login_bonus_control_modes) do
        if def.key == key then
            return g.lang == "Japanese" and def.ja or def.en
        end
    end
    return key
end

-- キャラ名は利用者が付けた文字列なので、{ } を書式タグとして解釈させない
function Login_bonus_control_plain(text)
    return (tostring(text or ""):gsub("{", "｛"):gsub("}", "｝"))
end

function Login_bonus_control_settings_frame_close(frame)
    ui.DestroyFrame(addon_name_lower .. "login_bonus_control_setting")
end

function Login_bonus_control_settings_frame()
    Login_bonus_control_sync_chars()
    local frame_name = addon_name_lower .. "login_bonus_control_setting"
    -- 開いているなら作り直さない(動かした位置と ESC の積み順をそのまま残す)
    if ui.GetFrame(frame_name) then
        Login_bonus_control_build_list()
        return
    end
    local ja = g.lang == "Japanese"
    local width, height = 440, 520
    local setting = ui.CreateNewFrame("notice_on_pc", frame_name, 0, 0, 0, 0)
    AUTO_CAST(setting)
    setting:Resize(width, height)
    setting:SetPos(g.settings_frame_pos(width, height))
    setting:SetSkinName("test_frame_low")
    g.block_click_through(setting)
    setting:EnableHitTest(1)
    setting:SetLayerLevel(999)
    setting:ShowWindow(1)
    g.esc_register_destroy(frame_name)
    local title_text = setting:CreateOrGetControl('richtext', 'title_text', 20, 15, 50, 30)
    AUTO_CAST(title_text)
    title_text:SetText("{ol}Login Bonus Control")
    local close = setting:CreateOrGetControl("button", "close", 0, 0, 20, 20)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Login_bonus_control_settings_frame_close")
    -- 未登録のキャラ(と「既定に従う」のキャラ)の既定
    local default_text = setting:CreateOrGetControl('richtext', 'default_text', 20, 52, 200, 20)
    AUTO_CAST(default_text)
    default_text:SetText(ja and "{ol}既定（未登録のキャラ）" or "{ol}Default (unregistered)")
    local default_list = setting:CreateOrGetControl('droplist', 'default_list', 240, 48, 180, 20)
    AUTO_CAST(default_list)
    default_list:SetSkinName('droplist_normal')
    default_list:EnableHitTest(1)
    default_list:SetTextAlign("center", "center")
    local settings = Login_bonus_control_settings()
    local index = 0
    local selected = 0
    for _, def in ipairs(g.login_bonus_control_modes) do
        if def.key ~= "default" then
            default_list:AddItem(index, "{ol}" .. (ja and def.ja or def.en), 0,
                string.format("Login_bonus_control_set_default('%s')", def.key))
            if settings.default_mode == def.key then
                selected = index
            end
            index = index + 1
        end
    end
    default_list:SelectItem(selected)
    local gbox = setting:CreateOrGetControl("groupbox", "gbox", 10, 85, width - 20, height - 135)
    AUTO_CAST(gbox)
    gbox:SetSkinName("test_frame_midle_light")
    gbox:EnableScrollBar(1)
    local note = setting:CreateOrGetControl('richtext', 'note', 20, height - 42, width - 40, 30)
    AUTO_CAST(note)
    note:SetText(ja and "{ol}{s14}一度ログインしたキャラと、同じバラックの層のキャラが並びます" or
                     "{ol}{s14}Characters you have logged in and those in the same barrack layer are listed")
    Login_bonus_control_build_list()
end

-- キャラの行を組み直す(窓は作り直さない)。並びは名前順で、今のキャラは色を変える。
function Login_bonus_control_build_list()
    local setting = ui.GetFrame(addon_name_lower .. "login_bonus_control_setting")
    if not setting then
        return
    end
    local gbox = GET_CHILD(setting, "gbox")
    if not gbox then
        return
    end
    AUTO_CAST(gbox)
    gbox:RemoveAllChild()
    local ja = g.lang == "Japanese"
    local settings = Login_bonus_control_settings()
    local current_key = Login_bonus_control_char_key(session.GetMySession():GetCID())
    local keys = {}
    for key, _ in pairs(settings.chars) do
        table.insert(keys, key)
    end
    table.sort(keys, function(a, b)
        return tostring(settings.chars[a].name) < tostring(settings.chars[b].name)
    end)
    local y = 8
    for _, key in ipairs(keys) do
        local entry = settings.chars[key]
        local name_text = gbox:CreateOrGetControl('richtext', 'name_' .. key, 10, y + 4, 200, 20)
        AUTO_CAST(name_text)
        local color = key == current_key and "{#FFCC33}" or ""
        name_text:SetText("{ol}" .. color .. Login_bonus_control_plain(entry.name))
        local list = gbox:CreateOrGetControl('droplist', 'mode_' .. key, 210, y, 160, 20)
        AUTO_CAST(list)
        list:SetSkinName('droplist_normal')
        list:EnableHitTest(1)
        list:SetTextAlign("center", "center")
        local selected = 0
        for i, def in ipairs(g.login_bonus_control_modes) do
            local label = ja and def.ja or def.en
            if def.key == "default" then
                -- 既定が何なのかを行の上で読めるようにする
                label = label .. "(" .. Login_bonus_control_mode_label(settings.default_mode) .. ")"
            end
            list:AddItem(i - 1, "{ol}" .. label, 0,
                string.format("Login_bonus_control_set_mode('%s', '%s')", key, def.key))
            if entry.mode == def.key then
                selected = i - 1
            end
        end
        list:SelectItem(selected)
        local delete = gbox:CreateOrGetControl('button', 'delete_' .. key, 378, y, 30, 26)
        AUTO_CAST(delete)
        delete:SetSkinName("test_pvp_btn")
        delete:SetText("{ol}×")
        delete:SetTextTooltip(ja and "{ol}一覧から消す（削除したキャラ用）" or "{ol}Remove from list (for deleted characters)")
        delete:SetEventScript(ui.LBUTTONUP, "Login_bonus_control_delete_char")
        delete:SetEventScriptArgString(ui.LBUTTONUP, key)
        y = y + 32
    end
    gbox:Invalidate()
end

function Login_bonus_control_set_default(mode)
    local settings = Login_bonus_control_settings()
    settings.default_mode = mode
    Login_bonus_control_save_settings()
    g.vlog("login_bonus_control: 既定を %s にした", mode)
    -- 行の「既定に従う(…)」の表示が変わるので組み直す
    Login_bonus_control_build_list()
end

function Login_bonus_control_set_mode(key, mode)
    local settings = Login_bonus_control_settings()
    local entry = settings.chars[key]
    if not entry then
        return
    end
    entry.mode = mode
    Login_bonus_control_save_settings()
    g.vlog("login_bonus_control: %s(%s) を %s にした", tostring(entry.name), key, mode)
end

function Login_bonus_control_delete_char(frame, ctrl, key)
    local settings = Login_bonus_control_settings()
    if not settings.chars[key] then
        return
    end
    settings.chars[key] = nil
    Login_bonus_control_save_settings()
    -- 今のキャラ・同じ層のキャラは開き直すとまた並ぶ(消したいのは削除したキャラなので、それでよい)
    Login_bonus_control_build_list()
end

-- 読み込みの時点で掛けられるものは掛けておく(理由は Login_bonus_control_install_hooks)
g.login_bonus_control_hooked_at_load = Login_bonus_control_install_hooks()
-- Login Bonus Control ここまで
