-- アドオンメニューボタン
--
-- ===== norisan_menu からの改称について =====
-- ファイル名・関数名・コントロール名は addons_menu_* に統一した(本家と同名の
-- グローバル関数を持たなくなるので、同時インストール時に上書きし合う危険も減る)。
-- ただし次の 2 つは *意図的に* norisan のまま残している。改称すると壊れる:
--
--   * _G["norisan"]["MENU"] … メニュー項目の共有登録先。norisan さんの他アドオンが
--     ここへ {name, func, icon} を入れて 1 つのボタンに相乗りする作りなので、
--     ここを変えると相手の項目が出なくなる(下の toggle_items_display が読む先)。
--   * フレーム名 "norisan_menu_frame" … 上と同じく相乗り側との待ち合わせ名。
--     20_lifecycle.lua 側にも「別名のフレームがあれば壊してこの名前で作り直す」
--     処理があるため、片方だけ改称すると互いに壊し合う。
--
-- 設定(位置・レイヤー等)の保存先は他のアドオン設定と同じ
-- ../addons/_nexus_addons_p/<AID>/addons_menu.json へ移した。
-- 以前は本家と共有の ../addons/norisan_menu/settings.json だったので、
-- 自分側がまだ無ければ 1 回だけ引き継ぐ(下の addons_menu_load_json)。
local addons_menu_legacy_settings = string.format("../addons/%s/settings.json", "norisan_menu")
_G["norisan"] = _G["norisan"] or {}
_G["norisan"]["MENU"] = _G["norisan"]["MENU"] or {}

-- g.active_id は ON_INIT で入るので、ロード時ではなく呼ばれた時点で組み立てる。
-- (このファイルはチャンク末尾にあるが、実行されるのは GAME_START 以降)
local function addons_menu_settings_path()
    if not g.active_id then
        return nil
    end
    return string.format("../addons/%s/%s/addons_menu.json", addon_name_lower, g.active_id)
end

-- MENU テーブルにはメニュー項目の登録(table)や lang / frame_name も同居するので、
-- 位置と表示設定だけを抜き出して書く(相乗り側の登録内容を設定ファイルへ漏らさない)。
local function addons_menu_save_json(tbl)
    local path = addons_menu_settings_path()
    if not path then
        return
    end
    g.save_json(path, {
        x = tbl.x,
        y = tbl.y,
        move = tbl.move,
        open = tbl.open,
        layer = tbl.layer,
        -- 1 のとき、右上のフローティングボタンを出さずシステムメニューの右クリックだけにする
        sysmenu_only = tbl.sysmenu_only
    })
end

local function addons_menu_load_json()
    local path = addons_menu_settings_path()
    if not path then
        return nil
    end
    local cfg = g.load_json(path)
    if cfg then
        return cfg
    end
    -- 引き継ぎ: 自分側の設定がまだ無いときだけ、旧 norisan_menu の設定を拾う。
    -- 条件を「自分側に無い」に限るのは g.migrate_from_origin() と同じ理由で、
    -- 既に自分の設定があるときに走らせると古い値で上書きしてしまうため。
    local legacy = g.load_json(addons_menu_legacy_settings)
    if not legacy then
        return nil
    end
    g.save_json(path, {
        x = legacy.x,
        y = legacy.y,
        move = legacy.move,
        open = legacy.open,
        layer = legacy.layer
        -- sysmenu_only はこちら独自の設定なので、旧設定からは引き継がない(既定 = OFF)
    })
    return legacy
end

function _G.addons_menu_move_drag(frame, ctrl)
    if not frame then
        return
    end
    local current_frame_y = frame:GetY()
    local current_frame_h = frame:GetHeight()
    local base_button_h = 40
    local y_to_save = current_frame_y
    if current_frame_h > base_button_h and (_G["norisan"]["MENU"].open == 1) then
        local items_area_h_calculated = current_frame_h - base_button_h
        y_to_save = current_frame_y + items_area_h_calculated

    end
    _G["norisan"]["MENU"].x = frame:GetX()
    _G["norisan"]["MENU"].y = y_to_save
    addons_menu_save_json(_G["norisan"]["MENU"])
end

function _G.addons_menu_setting_frame_ctrl(setting, ctrl)
    local ctrl_name = ctrl:GetName()
    -- frame_name は相乗り側が入れることもあり、まだ誰も入れていない状態で
    -- 設定画面を開ける経路がある。フレーム名は固定なのでフォールバックを置き、
    -- それでも引けなければ frame 無しで進める(下は毎回 nil ガードする)。
    local frame = ui.GetFrame(_G["norisan"]["MENU"].frame_name or "norisan_menu_frame")
    if ctrl_name == "layer_edit" then
        local layer = tonumber(ctrl:GetText())
        if layer then
            _G["norisan"]["MENU"].layer = layer
            if frame then
                frame:SetLayerLevel(layer)
            end
            addons_menu_save_json(_G["norisan"]["MENU"])

            local notice = _G["norisan"]["MENU"].lang == "Japanese" and "{ol}レイヤーを変更" or
                               "{ol}Change Layer"
            ui.SysMsg(notice)
            _G.addons_menu_create_frame()
            setting:ShowWindow(0)
            return
        end
    end
    if ctrl_name == "def_setting" then
        _G["norisan"]["MENU"].x = 1190
        _G["norisan"]["MENU"].y = 30
        _G["norisan"]["MENU"].move = true
        _G["norisan"]["MENU"].open = 0
        _G["norisan"]["MENU"].layer = 79
        addons_menu_save_json(_G["norisan"]["MENU"])
        _G.addons_menu_create_frame()
        setting:ShowWindow(0)
        return
    end
    if ctrl_name == "close" then
        setting:ShowWindow(0)
        return
    end
    local is_check = ctrl:IsChecked()
    if ctrl_name == "move_toggle" then
        if is_check == 1 then
            _G["norisan"]["MENU"].move = false
        else
            _G["norisan"]["MENU"].move = true
        end
        if frame then
            frame:EnableMove(_G["norisan"]["MENU"].move == true and 1 or 0)
        end
        addons_menu_save_json(_G["norisan"]["MENU"])
        return
    elseif ctrl_name == "open_toggle" then
        _G["norisan"]["MENU"].open = is_check
        addons_menu_save_json(_G["norisan"]["MENU"])
        _G.addons_menu_create_frame()
        return
    elseif ctrl_name == "sysmenu_only_toggle" then
        -- ON にすると右上のフローティングボタンを出さず、システムメニュー
        -- (右下アイコン列の system)の右クリックだけを導線にする。
        _G["norisan"]["MENU"].sysmenu_only = is_check
        addons_menu_save_json(_G["norisan"]["MENU"])
        addons_menu_apply_visibility()
        local notice
        if _G["norisan"]["MENU"].lang == "Japanese" then
            notice = is_check == 1 and "{ol}システムメニューの右クリックだけにしました" or
                         "{ol}右上のボタンを表示します"
        else
            notice = is_check == 1 and "{ol}System menu right click only" or "{ol}Showing the floating button"
        end
        ui.SysMsg(notice)
        return
    elseif ctrl_name == "verbose_log_toggle" then
        -- このチェックはメニューの表示設定ではなくアドオン全体の設定なので、
        -- addons_menu.json ではなく本体の settings.json 側に置く
        -- (addons_menu_save_json は {x,y,move,open,layer} しか書き出さない)。
        -- g.settings が無いのは本家検出で初期化を止めたときなので、その場合は何もしない。
        if g.settings then
            g.settings.verbose_log = is_check
            _nexus_addons_p_save_settings()
            local notice
            if _G["norisan"]["MENU"].lang == "Japanese" then
                notice = is_check == 1 and "{ol}詳細なログを出力します" or "{ol}詳細なログを止めました"
            else
                notice = is_check == 1 and "{ol}Verbose logging enabled" or "{ol}Verbose logging disabled"
            end
            ui.SysMsg(notice)
        end
        return
    end
end

function _G.addons_menu_setting_frame(frame, ctrl)
    -- 同じ導線をもう一度押したら閉じる。閉じ方は × ボタンと同じ ShowWindow(0) にする
    -- (このフレームは CreateNewFrame で作り直せないので、破棄せず隠して使い回す)。
    local opened = ui.GetFrame("addons_menu_setting")
    if opened and opened:IsVisible() == 1 then
        AUTO_CAST(opened)
        opened:ShowWindow(0)
        g.vlog("addons_menu: 設定画面を閉じる(呼び元 %s)", ctrl and ctrl:GetName() or "unknown")
        return
    end
    g.vlog("addons_menu: 設定画面を開く(呼び元 %s)", ctrl and ctrl:GetName() or "unknown")
    -- 中身(チェックボックスの行数)に合わせた大きさ。行を足したらここも直すこと。
    -- 下の位置決めでも同じ値を使うので、Resize より前に決めておく。
    local setting_w, setting_h = 380, 205
    local setting = ui.CreateNewFrame("chat_memberlist", "addons_menu_setting", 0, 0, 0, 0)
    AUTO_CAST(setting)
    setting:SetTitleBarSkin("None")
    setting:SetSkinName("chat_window")
    setting:Resize(setting_w, setting_h)
    setting:SetLayerLevel(999)
    setting:EnableHitTest(1)
    setting:EnableMove(1)
    -- 呼び元の右隣に出すが、画面からはみ出す位置には置かない。
    -- 画面右端から開いた場合(システムメニュー側の一覧は x=1830 付近)、素直に +200 すると
    -- 2000 超えの画面外に出て「押しても何も出ない」ように見える(実機で発生)。
    -- 画面幅は addons_menu_create_frame と同じく map フレームから取り、
    -- 取れないときだけ 1920 とみなす。
    local map_ui = ui.GetFrame("map")
    local screen_w = (map_ui and map_ui:IsVisible() == 1) and map_ui:GetWidth() or 1920
    local screen_h = (map_ui and map_ui:IsVisible() == 1) and map_ui:GetHeight() or 1080
    local pos_x = frame:GetX() + 200
    if pos_x + setting_w > screen_w then
        -- 右に置けないなら左へ回す。それでも収まらなければ画面内へ寄せる。
        pos_x = frame:GetX() - setting_w - 10
    end
    if pos_x < 0 then
        pos_x = 0
    end
    local pos_y = frame:GetY()
    if pos_y + setting_h > screen_h then
        pos_y = screen_h - setting_h
    end
    if pos_y < 0 then
        pos_y = 0
    end
    setting:SetPos(pos_x, pos_y)
    g.vlog("addons_menu: 設定画面の位置 %d,%d (呼び元 %d,%d 画面 %dx%d)", pos_x, pos_y, frame:GetX(), frame:GetY(),
        screen_w, screen_h)
    setting:ShowWindow(1)
    local close = setting:CreateOrGetControl("button", "close", 0, 0, 30, 30)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "addons_menu_setting_frame_ctrl")
    local def_setting = setting:CreateOrGetControl("button", "def_setting", 10, 5, 150, 30)
    AUTO_CAST(def_setting)
    local notice = _G["norisan"]["MENU"].lang == "Japanese" and "{ol}デフォルトに戻す" or "{ol}Reset to default"
    def_setting:SetText(notice)
    def_setting:SetEventScript(ui.LBUTTONUP, "addons_menu_setting_frame_ctrl")
    local move_toggle = setting:CreateOrGetControl('checkbox', "move_toggle", 10, 35, 30, 30)
    AUTO_CAST(move_toggle)
    move_toggle:SetCheck(_G["norisan"]["MENU"].move == true and 0 or 1)
    move_toggle:SetEventScript(ui.LBUTTONDOWN, 'addons_menu_setting_frame_ctrl')
    local notice = _G["norisan"]["MENU"].lang == "Japanese" and "{ol}チェックするとフレーム固定" or
                       "{ol}Check to fix frame"
    move_toggle:SetText(notice)
    local open_toggle = setting:CreateOrGetControl('checkbox', "open_toggle", 10, 70, 30, 30)
    AUTO_CAST(open_toggle)
    open_toggle:SetCheck(_G["norisan"]["MENU"].open)
    open_toggle:SetEventScript(ui.LBUTTONDOWN, 'addons_menu_setting_frame_ctrl')
    local notice = _G["norisan"]["MENU"].lang == "Japanese" and "{ol}チェックすると上開き" or
                       "{ol}Check to open upward"
    open_toggle:SetText(notice)
    -- 保存先だけ他項目と違い、Nexus Addons P 側の settings.json を見る(_ctrl 側のコメント参照)。
    -- 本家検出で初期化を止めているときは g.settings が無いので、その場合は OFF 表示。
    local verbose_log_toggle = setting:CreateOrGetControl('checkbox', "verbose_log_toggle", 10, 105, 30, 30)
    AUTO_CAST(verbose_log_toggle)
    verbose_log_toggle:SetCheck((g.settings and g.settings.verbose_log == 1) and 1 or 0)
    verbose_log_toggle:SetEventScript(ui.LBUTTONDOWN, 'addons_menu_setting_frame_ctrl')
    local notice = _G["norisan"]["MENU"].lang == "Japanese" and "{ol}詳細なログをシステムに出力する" or
                       "{ol}Output verbose logs to system messages"
    verbose_log_toggle:SetText(notice)
    -- 右上のフローティングボタンを消して、システムメニューの右クリックだけにする設定。
    -- 右クリックの割り当て自体は常に行っているので、これは「右上を出すかどうか」だけ。
    local sysmenu_only_toggle = setting:CreateOrGetControl('checkbox', "sysmenu_only_toggle", 10, 140, 30, 30)
    AUTO_CAST(sysmenu_only_toggle)
    sysmenu_only_toggle:SetCheck(_G["norisan"]["MENU"].sysmenu_only == 1 and 1 or 0)
    sysmenu_only_toggle:SetEventScript(ui.LBUTTONDOWN, 'addons_menu_setting_frame_ctrl')
    local notice = _G["norisan"]["MENU"].lang == "Japanese" and
                       "{ol}システムメニューの右クリックのみにする(右上のボタンを消す)" or
                       "{ol}System menu right click only (hide the floating button)"
    sysmenu_only_toggle:SetText(notice)
    local layer_text = setting:CreateOrGetControl('richtext', 'layer_text', 10, 175, 50, 20)
    AUTO_CAST(layer_text)
    local notice = _G["norisan"]["MENU"].lang == "Japanese" and "{ol}レイヤー設定" or "{ol}Set Layer"
    layer_text:SetText(notice)
    local layer_edit = setting:CreateOrGetControl('edit', 'layer_edit', 130, 175, 70, 20)
    AUTO_CAST(layer_edit)
    layer_edit:SetFontName("white_16_ol")
    layer_edit:SetTextAlign("center", "center")
    layer_edit:SetText(_G["norisan"]["MENU"].layer or 79)
    layer_edit:SetEventScript(ui.ENTERKEY, "addons_menu_setting_frame_ctrl")
end

-- 並べる項目を集める。フローティングのメニューと apps(ESC のシステムメニュー)側で
-- 同じ並びにしたいので、収集はここ 1 箇所に集約する。
--
-- variant に "sysmenu" を渡すと、項目が icon_sysmenu / icon_inflate_sysmenu を
-- 持っている場合にそちらへ差し替える。2 つのメニューは周りの見た目が違う
-- (右上は自前の小さいアイコン、右下はシステムメニューのボタン群の隣)ので、
-- 置き場所ごとに別の画像を使えるようにしてある。持っていない項目
-- (他アドオンが登録したもの)は従来どおり icon をそのまま使う。
local function addons_menu_collect_items(variant)
    local menu_src = _G["norisan"]["MENU"]
    local items = {}
    -- 差し替えは元のテーブルを書き換えず、表示用の浅いコピーへ行う。
    -- _G["norisan"]["MENU"] は相乗り側と共有しているので、こちらの都合で
    -- 中身を書き換えると相手の表示まで変わってしまう。
    local function shape(key, data)
        if variant ~= "sysmenu" or not (data.icon_sysmenu or data.icon_inflate_sysmenu) then
            return {
                key = key,
                data = data
            }
        end
        local copy = {}
        for k, v in pairs(data) do
            copy[k] = v
        end
        copy.icon = data.icon_sysmenu or data.icon
        copy.icon_inflate = data.icon_inflate_sysmenu or data.icon_inflate
        return {
            key = key,
            data = copy
        }
    end
    if menu_src then
        for key, data in pairs(menu_src) do
            if type(data) == "table" then
                if key ~= "x" and key ~= "y" and key ~= "open" and key ~= "move" and data.name and data.func and
                    ((data.image and data.image ~= "") or (data.icon and data.icon ~= "")) then
                    table.insert(items, shape(key, data))
                end
            end
        end
    end
    -- 設定を開くボタンを最後に並べる。**システムメニュー側だけ**。
    -- 右上のフローティング側は本体アイコンの右クリックで設定を開けるので、
    -- 同じ導線を 2 つ並べない。システムメニュー側は右クリックが「一覧を開く」に
    -- 使われていて設定へ行けないので、こちらにはボタンが要る。
    --
    -- ここは _G["norisan"]["MENU"] へは入れない。あのテーブルは相乗り側と共有していて、
    -- 入れると本家側のメニューにもこちらの設定項目が出てしまうため、表示のときだけ足す。
    -- 並び順を末尾にしているのは、既存の項目の位置がこの追加でずれないようにするため。
    if variant ~= "sysmenu" then
        return items
    end
    local setting_label = _G["norisan"]["MENU"].lang == "Japanese" and "Addons Menu の設定" or "Addons Menu settings"
    table.insert(items, {
        key = "addons_menu_setting",
        data = {
            name = setting_label,
            -- config_button_normal は一覧フレームの設定ボタンと同じ既存アイコン。
            -- image({img ...} のテキスト描画)ではなく icon(picture + ストレッチ)で持つ。
            -- テキスト描画はボタンの内側余白が乗るぶん、同じ数値を指定しても他の
            -- アイコンより小さく見える(実機で確認)。他項目と同じ経路に揃える。
            icon = "config_button_normal",
            -- それでも小さく見えるのは、この画像が絵の周りに余白を持っているため。
            -- 引き伸ばしても余白ごと拡大されるので、セルより一回り大きく描いて
            -- 見た目の大きさを他のアイコンへ合わせる(はみ出す分はフレームの余白で吸収する)。
            -- 拡大しない。この項目はシステムメニュー側にしか出さず、そちらのセルは
            -- apps のボタンと同寸(44)なので実寸で揃う。
            -- ここは下の shape()(置き場所ごとの差し替え)を通らない位置で足しているので、
            -- icon_inflate_sysmenu を書いても効かない。値は icon_inflate に直接入れること。
            icon_inflate = 0,
            func = "addons_menu_setting_frame"
        }
    })
    return items
end

-- 項目 1 つ分の大きさ。フローティングのメニューとシステムメニュー側の一覧で
-- 見た目を揃えるため、両方ここを見る(片方だけ 40 にしていて不揃いだった)。
local ADDONS_MENU_ITEM_SIZE = 35

-- 項目 1 つ分のコントロールを作る。image(テキストとして描く指定)が有ればボタン、
-- 無ければ icon 画像の picture。フローティング側と apps 側で見た目を揃えるため共通化する。
local function addons_menu_create_item(parent, ctrl_name, entry, x, y, w, h)
    local data = entry.data
    local item_elem
    -- icon_inflate を持つ項目は、セルの中央を保ったまま一回り大きく描く。
    if data.icon_inflate then
        local inflate = data.icon_inflate
        x, y = x - inflate, y - inflate
        w, h = w + inflate * 2, h + inflate * 2
    end
    -- image は他アドオンが登録する固定文字列({img ...})。こちらが足す項目は icon 側を使う
    -- (テキスト描画は余白が乗って小さく見えるため。collect_items のコメント参照)。
    local image = data.image
    if image and image ~= "" then
        item_elem = parent:CreateOrGetControl('button', ctrl_name, x, y, w, h)
        AUTO_CAST(item_elem)
        item_elem:SetSkinName("None")
        item_elem:SetText(image)
    else
        item_elem = parent:CreateOrGetControl('picture', ctrl_name, x, y, w, h)
        AUTO_CAST(item_elem)
        item_elem:SetImage(data.icon)
        item_elem:SetEnableStretch(1)
    end
    if item_elem then
        item_elem:SetTextTooltip("{ol}" .. data.name)
        item_elem:SetEventScript(ui.LBUTTONUP, data.func)
        item_elem:ShowWindow(1)
    end
    return item_elem
end

function _G.addons_menu_toggle_items_display(frame, ctrl, open_dir)
    local open_up = (open_dir == 1)
    local max_cols = 5
    local item_w = ADDONS_MENU_ITEM_SIZE
    local item_h = ADDONS_MENU_ITEM_SIZE
    local y_off_down = 35
    local items = addons_menu_collect_items()
    local num_items = #items
    local num_rows = math.ceil(num_items / max_cols)
    local items_h = num_rows * item_h
    local frame_h_new = 40 + items_h
    local frame_y_new = _G["norisan"]["MENU"].y or 30
    if open_up then
        frame_y_new = frame_y_new - items_h
    end
    local frame_w_new
    if num_rows == 1 then
        frame_w_new = math.max(40, num_items * item_w)
    else
        frame_w_new = math.max(40, max_cols * item_w)
    end
    frame:SetPos(frame:GetX(), frame_y_new)
    frame:Resize(frame_w_new, frame_h_new)
    for idx, entry in ipairs(items) do
        local item_sidx = idx - 1
        local col = item_sidx % max_cols
        local x = col * item_w
        local y = 0
        if open_up then
            local logical_row_from_bottom = math.floor(item_sidx / max_cols)
            y = (frame_h_new - 40) - ((logical_row_from_bottom + 1) * item_h)
        else
            local row_down = math.floor(item_sidx / max_cols)
            y = y_off_down + (row_down * item_h)
        end
        addons_menu_create_item(frame, "menu_item_" .. entry.key, entry, x, y, item_w, item_h)
    end
    local main_btn = GET_CHILD(frame, "addons_menu_pic")
    if main_btn then
        if open_up then
            main_btn:SetPos(0, frame_h_new - 40)
        else
            main_btn:SetPos(0, 0)
        end
    end
end

-- ===== システムメニュー(sysmenu の "system" ボタン)側の導線 =====
--
-- 実機調査で確定した前提(core/00_header.lua の g.probe_esc_menu で毎回確認できる):
--   * 右上アイコン列 sysmenu の "system" ボタン(コレクション F11 の右隣)は
--     ui.ToggleFrame('apps') を呼ぶ。ESC で開くシステムメニューと同じもの
--   * "apps" は幅 44 / 高さ 290 前後の縦一列で、46x46 のボタンが 6 個
--     (EXITAPP / LOG_OUT / GO_BARRACKMODE / Config / helpBtn / attendanceBtn)
--
-- ここでは **"system" ボタンの右クリックだけ** を借りる。左クリックは触らないので、
-- システムメニューは従来どおり開く。
--
-- apps 側に 7 個目のボタンを足す方式は取らない。一覧が apps のボタン列と重なるうえ、
-- ゲーム側がフレームを作り直すたびに高さを戻す必要があり、割に合わなかった
-- (実機で確認済み。同じ方式を再検討するときはこの経緯を踏まえること)。
local SYSMENU_FRAME_NAME = "sysmenu"
local SYSMENU_BTN_NAME = "system"
local SYSMENU_LIST_FRAME = "addons_menu_sysmenu_list"

-- 一覧のアイコンの大きさと配置間隔。システムメニュー(apps)の実寸に合わせてある。
-- 定義は ui.ipf の fixframe/apps/apps.xml:
--   ボタンは 44x44、margin は 5 / 50 / 95 / 140 / 185 / 230 = 45 刻み。
-- 以前はフローティング側と同じ 35 のセルに、はみ出させて大きく描いていたので
-- アイコン同士が詰まって見えた。大きさと間隔の両方をここで揃える。
local SYSMENU_ITEM_SIZE = 44
local SYSMENU_ITEM_PITCH = 45

-- 開閉音。右下のアイコン列(sysmenu)のボタンは、インベントリ等も含めて左クリック時に
-- すべて同じ押下音が鳴る。右クリックでもそれに合わせる。
--
-- sysmenu のボタンはクライアント側で Lua から作られており定義ファイルが無い
-- (ui.ipf の xml にも uiscp にも sysmenu の定義は無かった)ため、押下音の名前は
-- 直接は読めない。使えるイベント名は sound.ipf の FMOD 定義(R1.txt)にあり、
-- 汎用の押下音は button_click(ほかに button_click_2/3/4、button_click_big などが実在)。
--
-- 参考: apps 自体の開閉音は fixframe/apps/apps.xml に書かれていて
--   <sound opensound="sys_popup_open_1" closesound="character_item_window_close"/>
-- だが、これは「窓が開く音」で、ボタンを押した音とは別。
-- 実際に鳴らして選んだ結果が button_click_2(実機で左クリック時の音と一致)。
-- 候補を順に鳴らして選ぶ仕組みは役目を終えたので消した。もう一度選び直したくなったら、
-- R1.txt から候補名を拾って同じことをすればよい(開くたびに候補を 1 つずつ鳴らし、
-- 鳴らした名前を vlog へ出す)。
local SYSMENU_SE_OPEN = "button_click_2"
local SYSMENU_SE_CLOSE = "button_click_2"

local function addons_menu_play_se(name)
    pcall(imcSound.PlaySoundEvent, name)
end

-- 右上のフローティングボタンを、設定(sysmenu_only)に合わせて出し入れする。
-- 消す側は破棄ではなく非表示にする。norisan_menu_frame は相乗り側との待ち合わせ名で、
-- 破棄すると向こうが持っている参照まで無効にしてしまうため。
function _G.addons_menu_apply_visibility()
    local frame = ui.GetFrame(_G["norisan"]["MENU"].frame_name or "norisan_menu_frame")
    local hide = (_G["norisan"]["MENU"].sysmenu_only == 1)
    if hide then
        if frame then
            AUTO_CAST(frame)
            frame:ShowWindow(0)
        end
        return
    end
    if not frame then
        _G.addons_menu_create_frame()
        return
    end
    AUTO_CAST(frame)
    frame:ShowWindow(1)
end

-- 右クリックの案内を足したツールチップ。characters_item_serch が inven ボタンへ
-- 同じことをしているので、書式(1 行目に元の説明、2 行目に右クリックの案内)を揃える。
local function addons_menu_sysmenu_tooltip(lang)
    if lang == "Japanese" then
        return "{@st59}システムメニュー (ESC){nl}右クリック: Addons Menu"
    elseif lang == "kr" then
        return "{@st59}시스템 메뉴 (ESC){nl}Right click: Addons Menu"
    end
    return "{@st59}System Menu (ESC){nl}Right click: Addons Menu"
end

function _G.addons_menu_attach_to_sysmenu()
    local sysmenu = ui.GetFrame(SYSMENU_FRAME_NAME)
    if not sysmenu then
        g.vlog("addons_menu: sysmenu が取れないので右クリックを付けられない")
        return false
    end
    local btn = GET_CHILD(sysmenu, SYSMENU_BTN_NAME)
    if not btn then
        g.vlog("addons_menu: sysmenu の %s が取れない", SYSMENU_BTN_NAME)
        return false
    end
    AUTO_CAST(btn)
    -- 左クリックは「元の処理をそのまま行い、加えてこちらの一覧を閉じる」ようにしたいので、
    -- 元のスクリプト文字列を控えてから包む。実機では "ui.ToggleFrame('apps')" が入っている。
    -- 控えるのは自前の関数を入れる前だけ。付け直し(マップ移動ごと)で自分自身を
    -- 「元の処理」として控えてしまうと、左クリックが何もしなくなる。
    local ok, orig = pcall(function()
        return btn:GetEventScript(ui.LBUTTONUP)
    end)
    if ok and orig and orig ~= "" and not string.find(orig, "addons_menu_", 1, true) then
        g.addons_menu_sysmenu_lclick_orig = orig
    end
    btn:SetEventScript(ui.LBUTTONUP, "addons_menu_sysmenu_lclick")
    -- 同じボタンの右クリックを他アドオンが使っていると後勝ちになるが、
    -- 設定済みかどうかを読む手段が無いので検出はできない(実機で踏んで気付くしかない)。
    btn:SetEventScript(ui.RBUTTONUP, "addons_menu_sysmenu_toggle")
    btn:SetTextTooltip(addons_menu_sysmenu_tooltip(_G["norisan"]["MENU"].lang or option.GetCurrentCountry()))
    -- 付け直しはゲーム側が sysmenu を作り直した後にも要るので、毎回黙って上書きする。
    -- ログは初回だけにして、マップ移動のたびに 1 行増えるのを避ける。
    if not g.addons_menu_sysmenu_attached then
        g.addons_menu_sysmenu_attached = true
        g.vlog("addons_menu: sysmenu の %s に右クリックを設定した", SYSMENU_BTN_NAME)
    end
    return true
end

-- silent = true のときは音を鳴らさない。左クリック側から閉じるときに使う
-- (あちらはゲーム自身がボタン音とシステムメニューの開閉音を鳴らすので、
--  こちらも鳴らすと二重になる)。
function _G.addons_menu_sysmenu_close(silent)
    -- 誰が閉じたのかを追えるようにしておく。一覧が勝手に消える件を追ったとき、
    -- 「こちらが閉じたのか、外から壊されたのか」の切り分けがログだけでは付かなかった。
    if ui.GetFrame(SYSMENU_LIST_FRAME) then
        g.vlog("addons_menu: システムメニューの一覧を閉じる")
        if not silent then
            addons_menu_play_se(SYSMENU_SE_CLOSE)
        end
    end
    ui.DestroyFrame(SYSMENU_LIST_FRAME)
end

-- ESC を受けたときに、こちら側の状態をゲームの表示に合わせる。
--
-- 土台にしている chat_memberlist 由来のフレームは、ゲーム側の ESC で**隠される**。
-- ところが ESC による非表示は IsVisible() に反映されないので、こちらからは
-- 「まだ開いている」ように見える。その状態で右クリックすると
-- 「開いている → 閉じる」と判断してしまい、1 回目は何も起きず 2 回目でやっと開く
-- (実機で発生)。ESC の時点で畳んでおけば、次の 1 回で開く。
--
-- ESC は押すたびに必ず通る経路なので、ここは軽い処理だけにすること
-- (ui.GetFrame 2 回。ログとファイル I/O は置かない。詳細は 20_lifecycle.lua)。
function _G.addons_menu_on_escape()
    local list = ui.GetFrame(SYSMENU_LIST_FRAME)
    if list then
        ui.DestroyFrame(SYSMENU_LIST_FRAME)
    end
    -- 設定画面も同じ土台なので同じことが起きる。こちらは破棄せず隠す
    -- (CreateNewFrame で作り直せないため。addons_menu_setting_frame のコメント参照)。
    local setting = ui.GetFrame("addons_menu_setting")
    if setting then
        AUTO_CAST(setting)
        setting:ShowWindow(0)
    end
end

-- "system" ボタンの左クリック。元の処理(システムメニューの開閉)はそのまま行い、
-- 併せて右クリック側の一覧を閉じる。両方出しっぱなしにならないようにするため。
--
-- 元の処理は attach 時に控えた文字列を実行する。決め打ちで ui.ToggleFrame('apps') と
-- 書かないのは、クライアント側が中身を変えたときに追随できるようにするため。
-- 控えが無い/実行できないときだけ、既知の内容へフォールバックする。
-- ここが転ぶとシステムメニューが開かなくなるので、全部 pcall で握る。
function _G.addons_menu_sysmenu_lclick()
    pcall(addons_menu_sysmenu_close, true)
    local orig = g.addons_menu_sysmenu_lclick_orig
    if orig and orig ~= "" and loadstring then
        local fn = loadstring(orig)
        if fn and pcall(fn) then
            return
        end
        g.vlog("addons_menu: 左クリックの元処理を実行できなかった(%s)", tostring(orig))
    end
    pcall(ui.ToggleFrame, "apps")
end

-- "system" ボタンの右クリックで開く一覧。ボタンの真下に、右端を揃えて出す。
-- ボタンは画面右上の端に居るので、右へ伸ばすと画面外に出る。
function _G.addons_menu_sysmenu_toggle()
    local existing = ui.GetFrame(SYSMENU_LIST_FRAME)
    if existing and existing:IsVisible() == 1 then
        addons_menu_sysmenu_close()
        return
    end
    local sysmenu = ui.GetFrame(SYSMENU_FRAME_NAME)
    local btn = sysmenu and GET_CHILD(sysmenu, SYSMENU_BTN_NAME)
    if not btn then
        return
    end
    -- システムメニュー(apps)が開いていれば閉じる。左クリック側と両方出ていると、
    -- 同じボタンから出た窓が 2 つ並ぶことになって分かりにくい。
    local apps = ui.GetFrame("apps")
    if apps and apps:IsVisible() == 1 then
        pcall(ui.CloseFrame, "apps")
    end
    local items = addons_menu_collect_items("sysmenu")
    local item_w, item_h = SYSMENU_ITEM_SIZE, SYSMENU_ITEM_SIZE
    local pitch = SYSMENU_ITEM_PITCH
    -- 縦一列に積む。設定(collect_items が末尾に足す歯車)が一番下に来て、
    -- 他のボタンはその上へ、登録順に下から積み上がる。
    -- 項目が増えて画面に入らなくなったら、左へ列を足して折り返す。
    local max_rows = 12
    local num_rows = math.min(#items, max_rows)
    local num_cols = math.ceil(#items / max_rows)
    local inner_w, inner_h = num_cols * pitch, num_rows * pitch
    -- 端の余白。ここは apps に合わせた実寸で描くので、はみ出す分の吸収は要らない。
    local pad = 2
    local width, height = inner_w + pad * 2, inner_h + pad * 2
    -- 既存フレームがあると CreateNewFrame では作り直せないので先に壊す
    -- (項目が増減したときにサイズを取り直すため、毎回作り直す)。
    -- ここは「開く」経路なので閉じる音は鳴らさない。
    addons_menu_sysmenu_close(true)
    -- 土台は chat_memberlist。g.create_persistent_frame(= notice_on_pc 由来)で作ると、
    -- こちらが閉じていないのに数秒で破棄されていた(実機ログ: esc_stack ... frame=無)。
    -- notice_on_pc はゲームの通知用テンプレートなので、通知の処理に巻き込まれるとみられる。
    -- chat_memberlist 由来はゲーム側の ESC で閉じられるが、この一覧はむしろ
    -- ESC で閉じてほしいものなので都合がよい(だから g.esc_register もしない。
    -- 自前で ESC を横取りしないぶん、ESC 周りに触る箇所も減る)。
    local frame = ui.CreateNewFrame("chat_memberlist", SYSMENU_LIST_FRAME, 0, 0, 0, 0)
    AUTO_CAST(frame)
    frame:RemoveAllChild()
    -- 背景は付けない。"chat_window" を当てると黒い板が敷かれてアイコンが浮いて見える。
    -- フローティング側のメニュー(addons_menu_create_frame)も "None" で、見た目を揃える。
    frame:SetSkinName("None")
    frame:SetTitleBarSkin("None")
    frame:Resize(width, height)
    -- レイヤーは sysmenu + 1 では足りない。ボタンの真下はミニマップ等が居る領域で、
    -- そちらのほうが手前にあると、出てはいるのにクリックが吸われて押せない(実機で発生)。
    -- 設定画面(addons_menu_setting_frame)と同じ 999 まで上げて、確実に最前面へ出す。
    frame:SetLayerLevel(999)
    -- ヒットテストを明示的に有効化する。土台(chat_memberlist)の既定に任せると、
    -- フレーム自体がクリックを受けずに下の UI へ抜けることがある。
    frame:EnableHitTest(1)
    frame:EnableHittestFrame(1)
    -- ボタンの座標は sysmenu の中での相対値なので、フレームの位置を足して画面座標にする。
    local btn_x = sysmenu:GetX() + btn:GetX()
    local btn_y = sysmenu:GetY() + btn:GetY()
    -- 右端をボタンに揃える。左へはみ出す分は画面内に収める。
    local pos_x = btn_x + btn:GetWidth() - width
    if pos_x < 0 then
        pos_x = 0
    end
    -- 縦は「下に出す」固定にしない。sysmenu は画面下側に置かれていることがあり
    -- (利用者の環境では右下)、真下に出すと画面外になって触れなくなる(実機で発生)。
    -- 下に収まるなら下、収まらないなら上へ返す。
    local map_ui = ui.GetFrame("map")
    local screen_h = (map_ui and map_ui:IsVisible() == 1) and map_ui:GetHeight() or 1080
    local below_y = btn_y + btn:GetHeight() + 4
    local pos_y = below_y
    if below_y + height > screen_h then
        pos_y = btn_y - height - 4
    end
    if pos_y < 0 then
        pos_y = 0
    end
    frame:SetPos(pos_x, pos_y)
    for idx, entry in ipairs(items) do
        -- 末尾(= 設定)を一番下に置きたいので、下から数えた位置で配置する。
        local from_bottom = #items - idx
        local col = math.floor(from_bottom / max_rows)
        local row_in_col = from_bottom % max_rows
        -- 列も右端(ボタン側)から左へ足す。座標は端の余白の内側で、間隔(pitch)で数える。
        local x = pad + inner_w - (col + 1) * pitch
        local y = pad + inner_h - (row_in_col + 1) * pitch
        addons_menu_create_item(frame, "sysmenu_item_" .. entry.key, entry, x, y, item_w, item_h)
    end
    frame:ShowWindow(1)
    -- ui.OpenFrame 経由では音が鳴らなかった(実機で確認)ので、明示的に鳴らす。
    addons_menu_play_se(SYSMENU_SE_OPEN)
    -- 位置ずれを追えるよう、判断材料(ボタンの画面座標・画面の高さ・上下どちらに出したか)を出す。
    g.vlog("addons_menu: システムメニューの一覧を開いた 項目=%d 位置=%d,%d ボタン=%d,%d 画面高=%d %s", #items,
        frame:GetX(), frame:GetY(), btn_x, btn_y, screen_h, (pos_y == below_y) and "下に表示" or "上に表示")
end

function _G.addons_menu_frame_open(frame, ctrl)
    if not frame then
        return
    end
    if frame:GetHeight() > 40 then
        local children = {}
        for i = 0, frame:GetChildCount() - 1 do
            local child_obj = frame:GetChildByIndex(i)
            if child_obj then
                table.insert(children, child_obj)
            end
        end
        for _, child_obj in ipairs(children) do
            if child_obj:GetName() ~= "addons_menu_pic" then
                frame:RemoveChild(child_obj:GetName())
            end
        end
        frame:Resize(40, 40)
        frame:SetPos(frame:GetX(), _G["norisan"]["MENU"].y or 30)
        local main_pic = GET_CHILD(frame, "addons_menu_pic")
        if main_pic then
            main_pic:SetPos(0, 0)
        end
        return
    end
    local open_dir_val = _G["norisan"]["MENU"].open or 0
    _G.addons_menu_toggle_items_display(frame, ctrl, open_dir_val)
end

-- 定義は _G 側。改称前は `g.norisan_menu_create_frame` として定義しつつ、
-- 設定画面の 3 箇所(レイヤー変更 / デフォルトに戻す / 上開き)が
-- `_G.norisan_menu_create_frame()` を呼んでおり、nil 呼び出しになっていた。
-- 改称で本家とグローバル名がぶつからなくなったので、_G 側に寄せて揃える。
function _G.addons_menu_create_frame()
    _G["norisan"]["MENU"].lang = option.GetCurrentCountry()
    local loaded_cfg = addons_menu_load_json()
    if loaded_cfg and loaded_cfg.layer ~= nil then
        _G["norisan"]["MENU"].layer = loaded_cfg.layer
    elseif _G["norisan"]["MENU"].layer == nil then
        _G["norisan"]["MENU"].layer = 79
    end
    if loaded_cfg and loaded_cfg.move ~= nil then
        _G["norisan"]["MENU"].move = loaded_cfg.move
    elseif _G["norisan"]["MENU"].move == nil then
        _G["norisan"]["MENU"].move = true
    end
    if loaded_cfg and loaded_cfg.open ~= nil then
        _G["norisan"]["MENU"].open = loaded_cfg.open
    elseif _G["norisan"]["MENU"].open == nil then
        _G["norisan"]["MENU"].open = 0
    end
    -- 既定は OFF(= 右上のボタンを出す)。ここで読んでおかないと、設定を保存した後の
    -- 再ログインで「消したはずのボタンがまた出る」ことになる。
    if loaded_cfg and loaded_cfg.sysmenu_only ~= nil then
        _G["norisan"]["MENU"].sysmenu_only = loaded_cfg.sysmenu_only
    elseif _G["norisan"]["MENU"].sysmenu_only == nil then
        _G["norisan"]["MENU"].sysmenu_only = 0
    end
    local default_x = 1190
    local default_y = 30
    local final_x = default_x
    local final_y = default_y
    if _G["norisan"]["MENU"].x ~= nil then
        final_x = _G["norisan"]["MENU"].x
    end
    if _G["norisan"]["MENU"].y ~= nil then
        final_y = _G["norisan"]["MENU"].y
    end
    if loaded_cfg and type(loaded_cfg.x) == "number" then
        final_x = loaded_cfg.x
    end
    if loaded_cfg and type(loaded_cfg.y) == "number" then
        final_y = loaded_cfg.y
    end
    local map_ui = ui.GetFrame("map")
    local screen_w = 1920
    if map_ui and map_ui:IsVisible() then
        screen_w = map_ui:GetWidth()
    end
    if final_x > 1920 and screen_w <= 1920 then
        final_x = default_x
        final_y = default_y
    end
    _G["norisan"]["MENU"].x = final_x
    _G["norisan"]["MENU"].y = final_y
    addons_menu_save_json(_G["norisan"]["MENU"])
    -- 既存フレームがあると CreateNewFrame では作り直せないので、先に破棄する。
    -- 元々この関数は GAME_START の「フレームが無いとき」からしか呼ばれず破棄なしで
    -- 済んでいたが、設定画面の再描画(レイヤー変更 / デフォルトに戻す / 上開き)は
    -- フレームが在る状態で呼ぶため、破棄しないと見た目がまったく変わらない。
    -- 他アドオンが古い定義で作っていた場合も、ここで自前の定義に置き換わる。
    if ui.GetFrame("norisan_menu_frame") then
        ui.DestroyFrame("norisan_menu_frame")
    end
    -- ESC で消えない土台で作る(理由は g.create_persistent_frame のコメント)。
    local frame = g.create_persistent_frame("norisan_menu_frame")
    AUTO_CAST(frame)
    -- 相乗り側との待ち合わせ名を必ず立てる。ここを飛ばすと、他アドオンが先に
    -- フレームを作っていた場合に frame_name が nil のまま設定画面が開き、
    -- レイヤー変更や固定チェックが対象フレームを引けなくなる。
    -- 併せて「このフレームは自前の定義で作った」印を残す。20_lifecycle.lua の
    -- GAME_START はこの印を見て、旧定義のまま残っているフレームを作り替える。
    _G["norisan"]["MENU"].frame_name = "norisan_menu_frame"
    g.addons_menu_frame_owned = true
    frame:RemoveAllChild()
    frame:SetSkinName("None")
    frame:SetTitleBarSkin("None")
    frame:Resize(40, 40)
    frame:SetLayerLevel(_G["norisan"]["MENU"].layer)
    frame:EnableMove(_G["norisan"]["MENU"].move == true and 1 or 0)
    frame:SetPos(_G["norisan"]["MENU"].x, _G["norisan"]["MENU"].y)
    frame:SetEventScript(ui.LBUTTONUP, "addons_menu_move_drag")
    local addons_menu_pic = frame:CreateOrGetControl('picture', "addons_menu_pic", 0, 0, 35, 40)
    AUTO_CAST(addons_menu_pic)
    addons_menu_pic:SetImage("sysmenu_sys")
    addons_menu_pic:SetEnableStretch(1)
    -- こちら(フローティング側)の設定は右クリック。一覧に歯車は並べない
    -- (同じ導線を 2 つ置かない。collect_items のコメント参照)。
    local notice = _G["norisan"]["MENU"].lang == "Japanese" and
                       "{nl}{ol}クリック: 一覧を開く{nl}{ol}右クリック: 設定" or
                       "{nl}{ol}Click: Open list{nl}{ol}Right click: Settings"
    addons_menu_pic:SetTextTooltip("{ol}Addons Menu" .. notice)
    addons_menu_pic:SetEventScript(ui.LBUTTONUP, "addons_menu_frame_open")
    addons_menu_pic:SetEventScript(ui.RBUTTONUP, "addons_menu_setting_frame")
    -- 「システムメニューの右クリックのみ」設定のときは出さない。フレーム自体は作る
    -- (相乗り側が名前で待ち合わせているため)。
    frame:ShowWindow(_G["norisan"]["MENU"].sysmenu_only == 1 and 0 or 1)
end
