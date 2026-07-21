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
        layer = tbl.layer
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
    local frame_name = _G["norisan"]["MENU"].frame_name
    local frame = ui.GetFrame(frame_name)
    if ctrl_name == "layer_edit" then
        local layer = tonumber(ctrl:GetText())
        if layer then
            _G["norisan"]["MENU"].layer = layer
            frame:SetLayerLevel(layer)
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
        frame:EnableMove(_G["norisan"]["MENU"].move == true and 1 or 0)
        addons_menu_save_json(_G["norisan"]["MENU"])
        return
    elseif ctrl_name == "open_toggle" then
        _G["norisan"]["MENU"].open = is_check
        addons_menu_save_json(_G["norisan"]["MENU"])
        _G.addons_menu_create_frame()
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
    local setting = ui.CreateNewFrame("chat_memberlist", "addons_menu_setting", 0, 0, 0, 0)
    AUTO_CAST(setting)
    setting:SetTitleBarSkin("None")
    setting:SetSkinName("chat_window")
    setting:Resize(330, 170) -- verbose_log_toggle を 1 行足した分だけ縦横を広げている
    setting:SetLayerLevel(999)
    setting:EnableHitTest(1)
    setting:EnableMove(1)
    setting:SetPos(frame:GetX() + 200, frame:GetY())
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
    local layer_text = setting:CreateOrGetControl('richtext', 'layer_text', 10, 140, 50, 20)
    AUTO_CAST(layer_text)
    local notice = _G["norisan"]["MENU"].lang == "Japanese" and "{ol}レイヤー設定" or "{ol}Set Layer"
    layer_text:SetText(notice)
    local layer_edit = setting:CreateOrGetControl('edit', 'layer_edit', 130, 140, 70, 20)
    AUTO_CAST(layer_edit)
    layer_edit:SetFontName("white_16_ol")
    layer_edit:SetTextAlign("center", "center")
    layer_edit:SetText(_G["norisan"]["MENU"].layer or 79)
    layer_edit:SetEventScript(ui.ENTERKEY, "addons_menu_setting_frame_ctrl")
end

function _G.addons_menu_toggle_items_display(frame, ctrl, open_dir)
    local open_up = (open_dir == 1)
    local menu_src = _G["norisan"]["MENU"]
    local max_cols = 5
    local item_w = 35
    local item_h = 35
    local y_off_down = 35
    local items = {}
    if menu_src then
        for key, data in pairs(menu_src) do
            if type(data) == "table" then
                if key ~= "x" and key ~= "y" and key ~= "open" and key ~= "move" and data.name and data.func and
                    ((data.image and data.image ~= "") or (data.icon and data.icon ~= "")) then
                    table.insert(items, {
                        key = key,
                        data = data
                    })
                end
            end
        end
    end
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
        local data = entry.data
        local key = entry.key
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
        local ctrl_name = "menu_item_" .. key
        local item_elem
        if data.image and data.image ~= "" then
            item_elem = frame:CreateOrGetControl('button', ctrl_name, x, y, item_w, item_h)
            AUTO_CAST(item_elem)
            item_elem:SetSkinName("None")
            item_elem:SetText(data.image)
        else
            item_elem = frame:CreateOrGetControl('picture', ctrl_name, x, y, item_w, item_h)
            AUTO_CAST(item_elem)
            item_elem:SetImage(data.icon)
            item_elem:SetEnableStretch(1)
        end
        if item_elem then
            item_elem:SetTextTooltip("{ol}" .. data.name)
            item_elem:SetEventScript(ui.LBUTTONUP, data.func)
            item_elem:ShowWindow(1)
        end
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
    local frame = ui.CreateNewFrame("chat_memberlist", "norisan_menu_frame", 0, 0, 0, 0)
    AUTO_CAST(frame)
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
    local notice = _G["norisan"]["MENU"].lang == "Japanese" and "{nl}{ol}右クリック: 設定" or
                       "{nl}{ol}Right click: Settings"
    addons_menu_pic:SetTextTooltip("{ol}Addons Menu" .. notice)
    addons_menu_pic:SetEventScript(ui.LBUTTONUP, "addons_menu_frame_open")
    addons_menu_pic:SetEventScript(ui.RBUTTONUP, "addons_menu_setting_frame")
    frame:ShowWindow(1)
end
