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
        sysmenu_only = tbl.sysmenu_only,
        -- 項目の並べ方。置き場所ごとに別で持つ("h" = 横に並べて折り返す / "v" = 縦に積んで折り返す)。
        -- 既定は今までの見た目(右上 = 横 5 個、システムメニュー = 縦 12 個)。
        float_dir = tbl.float_dir,
        float_wrap = tbl.float_wrap,
        sys_dir = tbl.sys_dir,
        sys_wrap = tbl.sys_wrap
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

-- 並べ方の既定値。**ここを変えると既存利用者の見た目が変わる**ので、
-- 従来の実装と同じ値(右上は横 5 個で折り返し / システムメニューは縦 12 個で折り返し)にしてある。
local ADDONS_MENU_LAYOUT_DEFAULT = {
    float = {
        dir = "h",
        wrap = 5
    },
    sysmenu = {
        dir = "v",
        wrap = 12
    }
}

-- 並べ方の設定を読む。**フローティング側を作らない経路でも要る**ので、
-- addons_menu_create_frame 任せにせずここでも 1 回だけ読む
-- (システムメニューの右クリックだけを使っている利用者はそちらしか通らない)。
local function addons_menu_load_layout()
    if g.addons_menu_layout_loaded then
        return
    end
    local menu = _G["norisan"]["MENU"]
    local cfg = addons_menu_load_json()
    if cfg then
        for _, key in ipairs({"float_dir", "float_wrap", "sys_dir", "sys_wrap"}) do
            if menu[key] == nil and cfg[key] ~= nil then
                menu[key] = cfg[key]
            end
        end
    end
    g.addons_menu_layout_loaded = true
end

-- 置き場所ごとの「向き」と「折り返す数」を返す。
-- 壊れた値(手で書き換えた設定ファイル)でも並べられるよう、ここで必ず正す。
local function addons_menu_layout(variant)
    addons_menu_load_layout()
    local menu = _G["norisan"]["MENU"]
    local def = ADDONS_MENU_LAYOUT_DEFAULT[variant] or ADDONS_MENU_LAYOUT_DEFAULT.float
    local dir, wrap
    if variant == "sysmenu" then
        dir, wrap = menu.sys_dir, menu.sys_wrap
    else
        dir, wrap = menu.float_dir, menu.float_wrap
    end
    if dir ~= "h" and dir ~= "v" then
        dir = def.dir
    end
    wrap = math.floor(tonumber(wrap) or def.wrap)
    if wrap < 1 then
        wrap = 1
    elseif wrap > 30 then
        wrap = 30
    end
    return dir, wrap
end

-- 折り返しの計算。dir が "h" なら 1 行あたり wrap 個で下へ折り返し、
-- "v" なら 1 列あたり wrap 個で横へ折り返す。戻り値は列数・行数と、
-- **並べる番号(0 始まり)から (列, 行) を出す関数**。
--
-- 置き場所によって数える向きが逆(右上は先頭から、システムメニューは末尾から)なので、
-- 番号の作り方は呼び元に任せ、ここでは「番号 → 位置」だけを持つ。
local function addons_menu_grid(count, dir, wrap)
    local cols, rows
    if dir == "v" then
        rows = math.min(count, wrap)
        cols = math.ceil(count / wrap)
    else
        cols = math.min(count, wrap)
        rows = math.ceil(count / wrap)
    end
    if cols < 1 then
        cols = 1
    end
    if rows < 1 then
        rows = 1
    end
    local function cell(n)
        if dir == "v" then
            return math.floor(n / wrap), n % wrap
        end
        return n % wrap, math.floor(n / wrap)
    end
    return cols, rows, cell
end

-- 折り返しの計算は右上とシステムメニューの両方が見ていて、間違えると項目が重なる。
-- docs/tests/test_addons_menu.lua から呼べるよう g へも載せる(呼び出し側は上のローカル)。
g.addons_menu_grid = addons_menu_grid

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

-- 並べる項目を集める。フローティングのメニューと apps(ESC のシステムメニュー)側で
-- 同じ並びにしたいので、収集はここ 1 箇所に集約する。
--
-- 出どころは 3 つある。
--   1. _G["norisan"]["MENU"] … Nexus Addons P 本体 / Mini Addons と、**他アドオンが
--      相乗りで入れてきた項目**。既定は「出す」(既定を非表示にすると、他アドオンが
--      登録した項目が黙って消えて「あのボタンが出なくなった」という報告になる)
--   2. registry(g._nexus_addons_p)の設定画面 … 一覧の行の☆で選んだものだけ。既定は「出さない」
--   3. Addons Menu の設定を開く歯車 … システムメニュー側だけ、末尾に足す
--
-- variant に "sysmenu" を渡すと、項目が icon_sysmenu / icon_inflate_sysmenu を
-- 持っている場合にそちらへ差し替える。2 つのメニューは周りの見た目が違う
-- (右上は自前の小さいアイコン、右下はシステムメニューのボタン群の隣)ので、
-- 置き場所ごとに別の画像を使えるようにしてある。持っていない項目
-- (他アドオンが登録したもの)は従来どおり icon をそのまま使う。
--
-- **_G["norisan"]["MENU"] を書き換えないこと。** あのテーブルは相乗り側と共有していて、
-- アイコンの上書きを直接書き込むと本家側のメニューの見た目まで変わる。ここで作るのは
-- 表示用の別テーブルで、共有テーブルからは値を読むだけにする。
--
-- list_all = true のときは「出さない」ものも落とさずに返し、各項目へ shown を付ける。
-- 設定画面のショートカットタブ(出す / 出さないを選ぶ画面)がこれを使う。
local function addons_menu_collect_items(variant, list_all)
    local menu_src = _G["norisan"]["MENU"]
    local items = {}
    -- 相乗り側と共有しているテーブルから、表示に要るぶんだけを写した新しいテーブルを作る。
    local function shape(kind, key, data, name, func)
        local shortcut_key = g.menu_shortcut_key(kind, key)
        local cfg = g.menu_shortcut_cfg(shortcut_key)
        local icon = data and data.icon
        local icon_inflate = data and data.icon_inflate
        if variant == "sysmenu" and data then
            icon = data.icon_sysmenu or icon
            icon_inflate = data.icon_inflate_sysmenu or icon_inflate
        end
        -- 利用者が選んだアイコンは、置き場所によらず最優先。画像は引き伸ばして描くので、
        -- 元の項目が持っていた「一回り大きく描く」指定は引き継がない。
        if cfg and cfg.icon and cfg.icon ~= "" then
            icon = cfg.icon
            icon_inflate = nil
        end
        return {
            key = kind .. "_" .. key,
            shortcut_key = shortcut_key,
            kind = kind,
            name = name,
            -- 利用者が並べ替えた順。設定していない項目は nil のままで、下の並べ替えで末尾へ回る
            -- (相乗り項目はアドオンを入れた / 外した起動で顔ぶれが変わるので、
            --  知らない項目が既存の並びへ割り込まないようにする)。
            order = cfg and tonumber(cfg.order) or nil,
            data = {
                name = name,
                func = func,
                -- image は他アドオンが登録する固定文字列({img ...})。利用者がアイコンを
                -- 選んだ項目は、そちらを優先したいので image を伏せる。
                image = (cfg and cfg.icon and cfg.icon ~= "") and "" or (data and data.image),
                icon = icon,
                icon_inflate = icon_inflate
            }
        }
    end
    if menu_src then
        -- **pairs の順で並べないこと。** 起動のたびに順番が変わる。キー順に固定する。
        local keys = {}
        for key, data in pairs(menu_src) do
            if type(data) == "table" and key ~= "x" and key ~= "y" and key ~= "open" and key ~= "move" and data.name and
                data.func then
                keys[#keys + 1] = key
            end
        end
        table.sort(keys)
        for _, key in ipairs(keys) do
            local data = menu_src[key]
            local entry = shape("menu", key, data, data.name, data.func)
            -- 相乗り側の既定は「出す」。従来どおりの見え方にするため。
            entry.shown = g.menu_shortcut_shown(entry.shortcut_key, true)
            -- 描く絵が無い項目は出せない(アイコンも image も登録していない相乗り項目)。
            -- 設定画面には出すので、そこでアイコンを選べば出せるようになる。
            -- **必ず true / false にすること。** `x and x ~= ""` は x が nil のとき nil を返し、
            -- 設定画面側の「描けない印」の判定(== false)がすり抜ける。
            entry.drawable = (entry.data.image ~= nil and entry.data.image ~= "") or
                                 (entry.data.icon ~= nil and entry.data.icon ~= "")
            if list_all or (entry.shown and entry.drawable) then
                items[#items + 1] = entry
            end
        end
    end
    -- registry から、一覧の☆で選ばれた設定画面を足す。並びは registry の順で固定
    -- (ここも pairs を使わない)。**OFF のアドオンは出さない**。初期化されていないので
    -- 設定画面を開いても中で使う値が揃っておらず、一覧の☆も押せなくしてある。
    if g.settings and g._nexus_addons_p then
        for _, entry in ipairs(g._nexus_addons_p) do
            local saved = g.settings[entry.key]
            local config_func = entry.data.config_func
            if saved and config_func and config_func ~= "" then
                local shortcut = shape("addon", entry.key, nil, saved.name or entry.data.name, config_func)
                shortcut.shown = g.menu_shortcut_shown(shortcut.shortcut_key, false)
                shortcut.enabled = (saved.use == 1)
                if not shortcut.data.icon or shortcut.data.icon == "" then
                    shortcut.data.icon = g.MENU_SHORTCUT_DEFAULT_ICON
                end
                shortcut.drawable = true
                if list_all or (shortcut.shown and shortcut.enabled) then
                    items[#items + 1] = shortcut
                end
            end
        end
    end
    -- 利用者が決めた順(ショートカットタブの▲▼)へ並べ替える。
    --
    -- **order を持たない項目は末尾へ回す。** 相乗り項目は後から増減するので、
    -- 知らない項目が既存の並びの真ん中へ割り込むと、並べ替えた意味が無くなる。
    -- 同じ order 同士と order 無し同士は、上で決めた既定の並び(相乗りはキー順 /
    -- registry は登録順)を保つ。**table.sort は安定ではない**ので、
    -- 元の位置を控えて必ず最後の決め手にすること。
    for idx, entry in ipairs(items) do
        entry.natural = idx
    end
    table.sort(items, function(a, b)
        if a.order and b.order then
            if a.order ~= b.order then
                return a.order < b.order
            end
        elseif a.order then
            return true
        elseif b.order then
            return false
        end
        return a.natural < b.natural
    end)
    -- 設定を開くボタンを最後に並べる。**システムメニュー側だけ**。
    -- 右上のフローティング側は本体アイコンの右クリックで設定を開けるので、
    -- 同じ導線を 2 つ並べない。システムメニュー側は右クリックが「一覧を開く」に
    -- 使われていて設定へ行けないので、こちらにはボタンが要る。
    --
    -- ここは _G["norisan"]["MENU"] へは入れない。あのテーブルは相乗り側と共有していて、
    -- 入れると本家側のメニューにもこちらの設定項目が出てしまうため、表示のときだけ足す。
    -- 並び順を末尾にしているのは、既存の項目の位置がこの追加でずれないようにするため。
    -- ショートカットタブの一覧(list_all)にも出さない。出す / 出さないを選べる項目ではない。
    if variant ~= "sysmenu" or list_all then
        return items
    end
    local setting_label = _G["norisan"]["MENU"].lang == "Japanese" and "Addons Menu の設定" or "Addons Menu settings"
    table.insert(items, {
        key = "addons_menu_setting",
        kind = "builtin",
        name = setting_label,
        shown = true,
        drawable = true,
        data = {
            name = setting_label,
            -- config_button_normal は一覧フレームの設定ボタンと同じ既存アイコン。
            -- image({img ...} のテキスト描画)ではなく icon(picture + ストレッチ)で持つ。
            -- テキスト描画はボタンの内側余白が乗るぶん、同じ数値を指定しても他の
            -- アイコンより小さく見える(実機で確認)。他項目と同じ経路に揃える。
            icon = "config_button_normal",
            -- 拡大しない。この項目はシステムメニュー側にしか出さず、そちらのセルは
            -- apps のボタンと同寸(44)なので実寸で揃う。
            icon_inflate = 0,
            func = "addons_menu_setting_frame"
        }
    })
    return items
end

-- 収集の結果は「並び順」「出す / 出さないの既定」「アイコンの上書き」がぶつかりやすく、
-- どれも実機でしか出ない不具合になる。docs/tests/test_addons_menu.lua から呼べるよう
-- g へも載せておく(呼び出し側は上のローカルをそのまま使う)。
g.addons_menu_collect_items = addons_menu_collect_items

-- ===== Addons Menu の設定画面 =====
--
-- 中身はタブで分ける。**タブは tab コントロールではなくボタンで作る。**
-- この窓は chat_memberlist 土台の小さい窓で、ゲーム標準の tab を載せると skin の
-- 縦幅に合わせて窓ごと大きくする必要があり、周りと馴染まない(cc_helper が同じ理由で
-- ボタン式にしている)。
--
--   共通           … どこから開いても同じ設定(固定・レイヤー・詳細ログ・右上を出すか)
--   並び           … 置き場所ごとの並べ方。右上とシステムメニューを左右に並べて見比べられる
--   ショートカット … Addons Menu へ出す項目とアイコン
local ADDONS_MENU_SETTING_FRAME = "addons_menu_setting"
local ADDONS_MENU_SETTING_TABS = {{
    key = "common",
    ja = "共通",
    etc = "General"
}, {
    key = "layout",
    ja = "並び",
    etc = "Layout"
}, {
    key = "shortcut",
    ja = "ショートカット",
    etc = "Shortcuts"
}}
-- タブごとの窓の大きさ。**中身(行数)を足したらここも直すこと。**
local ADDONS_MENU_SETTING_SIZE = {
    common = {460, 330},
    layout = {460, 240},
    shortcut = {470, 430}
}
local ADDONS_MENU_SETTING_TAB_H = 40

local function addons_menu_ml(ja, etc)
    return (_G["norisan"]["MENU"].lang == "Japanese") and ja or etc
end

local function addons_menu_setting_tab()
    local tab = g.addons_menu_setting_tab
    for _, def in ipairs(ADDONS_MENU_SETTING_TABS) do
        if def.key == tab then
            return tab
        end
    end
    return "common"
end

-- 共通タブ。従来の設定画面の中身がそのまま入る(上開きだけは並びタブへ移した)。
local function addons_menu_setting_build_common(body, w)
    local def_setting = body:CreateOrGetControl("button", "def_setting", 10, 5, 150, 30)
    AUTO_CAST(def_setting)
    def_setting:SetText(addons_menu_ml("{ol}デフォルトに戻す", "{ol}Reset to default"))
    def_setting:SetEventScript(ui.LBUTTONUP, "addons_menu_setting_frame_ctrl")
    local move_toggle = body:CreateOrGetControl('checkbox', "move_toggle", 10, 40, 30, 30)
    AUTO_CAST(move_toggle)
    move_toggle:SetCheck(_G["norisan"]["MENU"].move == true and 0 or 1)
    move_toggle:SetEventScript(ui.LBUTTONDOWN, 'addons_menu_setting_frame_ctrl')
    move_toggle:SetText(addons_menu_ml("{ol}チェックするとフレーム固定", "{ol}Check to fix frame"))
    -- 保存先だけ他項目と違い、Nexus Addons P 側の settings.json を見る(_ctrl 側のコメント参照)。
    -- 本家検出で初期化を止めているときは g.settings が無いので、その場合は OFF 表示。
    local verbose_log_toggle = body:CreateOrGetControl('checkbox', "verbose_log_toggle", 10, 75, 30, 30)
    AUTO_CAST(verbose_log_toggle)
    verbose_log_toggle:SetCheck((g.settings and g.settings.verbose_log == 1) and 1 or 0)
    verbose_log_toggle:SetEventScript(ui.LBUTTONDOWN, 'addons_menu_setting_frame_ctrl')
    verbose_log_toggle:SetText(addons_menu_ml("{ol}詳細なログをシステムに出力する",
        "{ol}Output verbose logs to system messages"))
    -- 右上のフローティングボタンを消して、システムメニューの右クリックだけにする設定。
    -- 右クリックの割り当て自体は常に行っているので、これは「右上を出すかどうか」だけ。
    local sysmenu_only_toggle = body:CreateOrGetControl('checkbox', "sysmenu_only_toggle", 10, 110, 30, 30)
    AUTO_CAST(sysmenu_only_toggle)
    sysmenu_only_toggle:SetCheck(_G["norisan"]["MENU"].sysmenu_only == 1 and 1 or 0)
    sysmenu_only_toggle:SetEventScript(ui.LBUTTONDOWN, 'addons_menu_setting_frame_ctrl')
    -- **チェックの文字を長くしないこと。** コントロールの幅ではなく文字の長さで右へ伸び、
    -- 窓からはみ出した分は黙って切れる(実機で「…(右上のボタ」まで出て切れていた)。
    -- 補足はツールチップへ回す。
    sysmenu_only_toggle:SetText(addons_menu_ml("{ol}システムメニューの右クリックのみにする",
        "{ol}System menu right click only"))
    sysmenu_only_toggle:SetTextTooltip(addons_menu_ml("{ol}右上のフローティングボタンを消します",
        "{ol}Hides the floating button in the top right"))
    local layer_text = body:CreateOrGetControl('richtext', 'layer_text', 10, 148, 50, 20)
    AUTO_CAST(layer_text)
    layer_text:SetText(addons_menu_ml("{ol}レイヤー設定", "{ol}Set Layer"))
    local layer_edit = body:CreateOrGetControl('edit', 'layer_edit', 130, 148, 70, 20)
    AUTO_CAST(layer_edit)
    layer_edit:SetFontName("white_16_ol")
    layer_edit:SetTextAlign("center", "center")
    layer_edit:SetText(_G["norisan"]["MENU"].layer or 79)
    layer_edit:SetEventScript(ui.ENTERKEY, "addons_menu_setting_frame_ctrl")
    -- 初回ロードの分割実行の速さ。詳細ログと同じくアドオン全体の設定なので、
    -- 保存先は addons_menu.json ではなく本体の settings.json（_ctrl 側のコメント参照）。
    -- 出す数値は 1 つだけにする。tick 間隔と時間予算は g.init_throttle が連動させるので、
    -- 3 つ並べても噛み合わせが崩れるだけで利用者が正しく決められない。
    local init_label = body:CreateOrGetControl("richtext", "init_label", 10, 178, 50, 20)
    AUTO_CAST(init_label)
    init_label:SetText(addons_menu_ml("{ol}初期化の速さ", "{ol}Init speed"))
    local shown_batch = (g.init_throttle(g.settings and g.settings.init_batch))
    local init_edit = body:CreateOrGetControl("edit", "init_batch_edit", 130, 178, 70, 20)
    AUTO_CAST(init_edit)
    init_edit:SetFontName("white_16_ol")
    init_edit:SetTextAlign("center", "center")
    init_edit:SetText(shown_batch)
    init_edit:SetTextTooltip(addons_menu_ml(
        string.format("{ol}Enter で確定(%d〜%d / 推奨 %d)", g.INIT_BATCH_MIN, g.INIT_BATCH_MAX, g.INIT_BATCH_DEFAULT),
        string.format("{ol}Press Enter to apply (%d-%d, recommended %d)", g.INIT_BATCH_MIN, g.INIT_BATCH_MAX,
            g.INIT_BATCH_DEFAULT)))
    init_edit:SetEventScript(ui.ENTERKEY, "addons_menu_setting_frame_ctrl")
    -- 何の数字なのかと、上げると何を失うのかを添える。数字だけ出しても決められない。
    -- 所要時間は今の登録数から出す(アドオンを足しても説明文がずれない)。
    local addon_count = #g._nexus_addons_p
    local estimate = g.init_estimate_sec(addon_count, shown_batch)
    local notes = {}
    notes[1] = addons_menu_ml(
        string.format("ログイン直後に 1 回で初期化する数(%d〜%d / 推奨 %d)", g.INIT_BATCH_MIN, g.INIT_BATCH_MAX,
            g.INIT_BATCH_DEFAULT),
        string.format("Addons initialized per tick right after login (%d-%d, recommended %d)", g.INIT_BATCH_MIN,
            g.INIT_BATCH_MAX, g.INIT_BATCH_DEFAULT))
    notes[2] = addons_menu_ml("大きいほど速く終わりますが、そのぶん動作が重くなります",
        "Higher finishes sooner but makes those frames heavier")
    notes[3] = addons_menu_ml(
        string.format("今の設定なら %d 個で約 %.2f 秒。次のログインから反映されます", addon_count, estimate),
        string.format("About %.2fs for %d addons. Applies from the next login", estimate, addon_count))
    -- 補足は**枠に入れて「注記」に見せる**。設定そのものと同じ地の上に同じ色で置くと、
    -- どこまでが操作する項目でどこからが説明なのか見分けが付かない(実機で指摘)。
    -- 暗い枠("bg")へ載せるので、文字は薄い灰色にして本文より一段落とす。
    local note_box = body:CreateOrGetControl("groupbox", "init_note_box", 10, 200, w - 20, #notes * 18 + 10)
    AUTO_CAST(note_box)
    note_box:SetSkinName("bg")
    note_box:EnableScrollBar(0)
    note_box:RemoveAllChild()
    for i, line in ipairs(notes) do
        local note = note_box:CreateOrGetControl("richtext", "init_note_" .. i, 8, 4 + (i - 1) * 18, 10, 20)
        AUTO_CAST(note)
        -- 先頭の行にだけ ※ を付ける。全行に付けると箇条書きに見えて、
        -- 「3 つの注意点」ではなく「1 つの説明」であることが伝わらない。
        note:SetText("{ol}{#CCCCCC}{s14}" .. (i == 1 and "※ " or "     ") .. line)
    end
end

-- 並びタブ。右上とシステムメニューを**左右に並べる**。
-- 置き場所ごとにタブを分けると、ほぼ同じ画面が 2 枚並んで「今どちらを触っているのか」が
-- 分からなくなるうえ、別々に設定できること自体が見えない。
local function addons_menu_setting_build_layout(body)
    local col_x = {150, 290}
    local variants = {"float", "sysmenu"}
    local head = {addons_menu_ml("{ol}{#FFCC33}右上のメニュー", "{ol}{#FFCC33}Floating"),
                  addons_menu_ml("{ol}{#FFCC33}システムメニュー", "{ol}{#FFCC33}System menu")}
    for i, x in ipairs(col_x) do
        local title = body:CreateOrGetControl("richtext", "col_head_" .. i, x, 8, 10, 20)
        AUTO_CAST(title)
        title:SetText(head[i])
    end
    local dir_label = body:CreateOrGetControl("richtext", "dir_label", 10, 40, 10, 20)
    AUTO_CAST(dir_label)
    dir_label:SetText(addons_menu_ml("{ol}並べる向き", "{ol}Direction"))
    local wrap_label = body:CreateOrGetControl("richtext", "wrap_label", 10, 78, 10, 20)
    AUTO_CAST(wrap_label)
    wrap_label:SetText(addons_menu_ml("{ol}折り返す数", "{ol}Wrap after"))
    for i, variant in ipairs(variants) do
        local dir, wrap = addons_menu_layout(variant)
        local x = col_x[i]
        for j, d in ipairs({"h", "v"}) do
            local btn = body:CreateOrGetControl("button", variant .. "_dir_" .. d, x + (j - 1) * 62, 36, 58, 26)
            AUTO_CAST(btn)
            -- 選んでいるほうを目立つ skin にする(cc_helper のタブと同じ見せ方)。
            btn:SetSkinName(dir == d and "test_pvp_btn" or "test_gray_button")
            btn:SetText(d == "h" and addons_menu_ml("{ol}横", "{ol}Rows") or addons_menu_ml("{ol}縦", "{ol}Cols"))
            btn:SetTextTooltip(d == "h" and
                                   addons_menu_ml("{ol}横に並べて、指定した数で下へ折り返す",
                    "{ol}Fill rows, wrap downward") or
                                   addons_menu_ml("{ol}縦に積んで、指定した数で横へ折り返す",
                    "{ol}Stack in columns, wrap sideways"))
            btn:SetEventScript(ui.LBUTTONUP, "addons_menu_setting_frame_ctrl")
        end
        local edit = body:CreateOrGetControl("edit", variant .. "_wrap_edit", x, 76, 58, 24)
        AUTO_CAST(edit)
        edit:SetFontName("white_16_ol")
        edit:SetTextAlign("center", "center")
        edit:SetText(wrap)
        edit:SetTextTooltip(addons_menu_ml("{ol}Enter で確定(1〜30)", "{ol}Press Enter to apply (1-30)"))
        edit:SetEventScript(ui.ENTERKEY, "addons_menu_setting_frame_ctrl")
    end
    -- 上開きは右上のメニューだけの設定(システムメニュー側は画面の端に合わせて自動で上下する)。
    local open_label = body:CreateOrGetControl("richtext", "open_label", 10, 116, 10, 20)
    AUTO_CAST(open_label)
    open_label:SetText(addons_menu_ml("{ol}上へ開く", "{ol}Open upward"))
    local open_toggle = body:CreateOrGetControl('checkbox', "open_toggle", col_x[1], 112, 30, 30)
    AUTO_CAST(open_toggle)
    open_toggle:SetCheck(_G["norisan"]["MENU"].open)
    open_toggle:SetEventScript(ui.LBUTTONDOWN, 'addons_menu_setting_frame_ctrl')
    open_toggle:SetText("")
    local none = body:CreateOrGetControl("richtext", "open_none", col_x[2], 116, 10, 20)
    AUTO_CAST(none)
    none:SetText(addons_menu_ml("{ol}{#FFFFFF}画面に合わせて自動", "{ol}{#FFFFFF}Automatic"))
    local note = body:CreateOrGetControl("richtext", "layout_note", 10, 155, 10, 20)
    AUTO_CAST(note)
    -- 文字色は白 + 縁取り。**薄い灰色にしないこと。** 背景("test_frame_low")が明るいので沈む。
    note:SetText(addons_menu_ml("{ol}{#FFFFFF}{s14}出す項目はショートカットタブで選びます",
        "{ol}{#FFFFFF}{s14}Choose the items in the Shortcuts tab"))
end

-- ショートカットタブ。今 Addons Menu へ並ぶ候補を全部出して、出す / 出さないとアイコンを選ぶ。
--
-- **他アドオンが相乗りで入れてきた項目もここに出る。** あちらは一覧の行を持たないので、
-- ここが唯一の管理場所になる。
-- ショートカットタブに並べる項目を決める。
--
-- **既定は「今 Addons Menu に出ているものだけ」。** 出す / 出さないを選ぶ場所は
-- アドオン一覧の行の☆で、ここは並べ替えとアイコンを決める場所として使う。
-- 候補を全部並べると 20 行を超えて、並べ替えたい行を探すのが手間になる。
--
-- ただし**それだけだと、いちど外した相乗り項目を戻せなくなる**(相乗り項目は
-- 一覧の行を持たないので、ここが唯一の管理場所)。ヘッダのボタンで
-- 「出していないものも表示」へ切り替えられるようにしておく。
--
-- 出せない状態(アイコンが無い / アドオンが OFF)の項目は、☆が立っているなら残す。
-- 「☆を入れたのに出てこない」理由をここでしか伝えられないため。
local function addons_menu_shortcut_rows()
    local all = addons_menu_collect_items(nil, true)
    if g.addons_menu_shortcut_show_all then
        return all, #all
    end
    local rows = {}
    for _, entry in ipairs(all) do
        if entry.shown then
            rows[#rows + 1] = entry
        end
    end
    return rows, #all
end

local function addons_menu_setting_build_shortcut(body, w, h)
    local rows, total = addons_menu_shortcut_rows()
    local view_btn = body:CreateOrGetControl("button", "sc_view", 5, 4, 190, 24)
    AUTO_CAST(view_btn)
    view_btn:SetSkinName(g.addons_menu_shortcut_show_all and "test_pvp_btn" or "test_gray_button")
    view_btn:SetText(g.addons_menu_shortcut_show_all and
                         addons_menu_ml("{ol}{s14}出している項目だけ表示", "{ol}{s14}Show only visible items") or
                         addons_menu_ml("{ol}{s14}出していない項目も表示", "{ol}{s14}Show hidden items too"))
    view_btn:SetTextTooltip(addons_menu_ml("{ol}外した項目を戻したいときに切り替えます",
        "{ol}Switch this to bring back items you removed"))
    view_btn:SetEventScript(ui.LBUTTONUP, "addons_menu_shortcut_view_ctrl")
    local count_text = body:CreateOrGetControl("richtext", "sc_count", 205, 8, 10, 20)
    AUTO_CAST(count_text)
    count_text:SetText(string.format(addons_menu_ml("{ol}{s14}{#FFFFFF}%d / %d 件",
        "{ol}{s14}{#FFFFFF}%d of %d"), #rows, total))
    local gb = body:CreateOrGetControl("groupbox", "sc_gb", 5, 32, w - 10, h - 37)
    AUTO_CAST(gb)
    gb:SetSkinName("bg")
    gb:RemoveAllChild()
    gb:EnableScrollBar(1)
    local row_h = 30
    local y = 5
    for idx, entry in ipairs(rows) do
        local disabled = (entry.kind == "addon") and (entry.enabled ~= true)
        local icon_pic = gb:CreateOrGetControl("picture", "sc_pic_" .. idx, 8, y + 2, 24, 24)
        AUTO_CAST(icon_pic)
        if entry.data.icon and entry.data.icon ~= "" then
            icon_pic:SetImage(entry.data.icon)
            icon_pic:SetEnableStretch(1)
        end
        local name = gb:CreateOrGetControl("richtext", "sc_name_" .. idx, 40, y + 6, 10, 20)
        AUTO_CAST(name)
        -- 絵を持たない相乗り項目は、アイコンを選ぶまでメニューへ出せない。
        -- 「☆を入れたのに出てこない」理由がここでしか分からないので、行に書いておく。
        local label = "{ol}{s16}" .. (disabled and "{#777777}" or "{#FFFFFF}") .. entry.name
        if not entry.drawable then
            label = label .. addons_menu_ml("  {s13}{#FF9933}(アイコンを選ぶと出せます)",
                "  {s13}{#FF9933}(choose an icon to show it)")
        end
        name:SetText(label)
        if disabled then
            name:EnableHitTest(1)
            name:SetTextTooltip(addons_menu_ml("{ol}アドオンが OFF です。一覧で ON にすると出せます",
                "{ol}The addon is OFF. Turn it on in the list first"))
        end
        -- 並べ替え。**動かせるのは今この一覧に出ている範囲だけ**で、押すと
        -- 一覧全体へ 1 から番号を振り直す(隙間や同番が残ると次の並べ替えで効かなくなる)。
        local up = gb:CreateOrGetControl("button", "sc_up_" .. idx, w - 200, y + 2, 24, 26)
        AUTO_CAST(up)
        up:SetSkinName("None")
        up:SetTextAlign("center", "center")
        local can_up = (idx > 1)
        up:SetText(can_up and "{ol}{s18}{#FFFFFF}▲" or "{ol}{s18}{#555555}▲")
        if can_up then
            up:SetTextTooltip(addons_menu_ml("{ol}1 つ前へ", "{ol}Move up"))
            up:SetEventScript(ui.LBUTTONUP, "addons_menu_shortcut_move_ctrl")
            up:SetEventScriptArgString(ui.LBUTTONUP, entry.shortcut_key)
            up:SetEventScriptArgNumber(ui.LBUTTONUP, -1)
        end
        local down = gb:CreateOrGetControl("button", "sc_down_" .. idx, w - 174, y + 2, 24, 26)
        AUTO_CAST(down)
        down:SetSkinName("None")
        down:SetTextAlign("center", "center")
        local can_down = (idx < #rows)
        down:SetText(can_down and "{ol}{s18}{#FFFFFF}▼" or "{ol}{s18}{#555555}▼")
        if can_down then
            down:SetTextTooltip(addons_menu_ml("{ol}1 つ後ろへ", "{ol}Move down"))
            down:SetEventScript(ui.LBUTTONUP, "addons_menu_shortcut_move_ctrl")
            down:SetEventScriptArgString(ui.LBUTTONUP, entry.shortcut_key)
            down:SetEventScriptArgNumber(ui.LBUTTONUP, 1)
        end
        local star = gb:CreateOrGetControl("button", "sc_show_" .. idx, w - 140, y + 2, 26, 26)
        AUTO_CAST(star)
        star:SetSkinName("None")
        star:SetTextAlign("center", "center")
        if disabled then
            star:SetText("{ol}{s20}{#555555}" .. (entry.shown and "★" or "☆"))
            star:SetTextTooltip(addons_menu_ml("{ol}アドオンが OFF の間は出せません",
                "{ol}Cannot be shown while the addon is OFF"))
        else
            star:SetText(entry.shown and "{ol}{s20}{#FFCC33}★" or "{ol}{s20}{#999999}☆")
            star:SetTextTooltip(addons_menu_ml("{ol}クリックで出す / 出さないを切り替え", "{ol}Click to show or hide"))
            star:SetEventScript(ui.LBUTTONUP, "addons_menu_shortcut_show_ctrl")
            star:SetEventScriptArgString(ui.LBUTTONUP, entry.shortcut_key)
        end
        local icon_btn = gb:CreateOrGetControl("button", "sc_icon_" .. idx, w - 110, y + 2, 80, 26)
        AUTO_CAST(icon_btn)
        icon_btn:SetSkinName("test_gray_button")
        icon_btn:SetText(addons_menu_ml("{ol}{s14}アイコン", "{ol}{s14}Icon"))
        icon_btn:SetTextTooltip(addons_menu_ml("{ol}クリック: アイコンを選ぶ{nl}右クリック: 既定に戻す",
            "{ol}Click: choose icon{nl}Right click: reset to default"))
        icon_btn:SetEventScript(ui.LBUTTONUP, "addons_menu_shortcut_icon_ctrl")
        icon_btn:SetEventScriptArgString(ui.LBUTTONUP, entry.shortcut_key)
        icon_btn:SetEventScript(ui.RBUTTONUP, "addons_menu_shortcut_icon_reset")
        icon_btn:SetEventScriptArgString(ui.RBUTTONUP, entry.shortcut_key)
        y = y + row_h
    end
    if #rows == 0 then
        local empty = gb:CreateOrGetControl("richtext", "sc_empty", 12, 10, 10, 20)
        AUTO_CAST(empty)
        empty:SetText(total > 0 and
                          addons_menu_ml("{ol}{#FFA500}出している項目がありません(一覧の☆で選べます)",
                "{ol}{#FFA500}Nothing is shown yet (pick items with the star in the list)") or
                          addons_menu_ml("{ol}{#FFA500}出せる項目がありません",
                "{ol}{#FFA500}Nothing can be added yet"))
    end
    pcall(function()
        gb:InvalidateScrollBar()
    end)
end

-- タブとその中身を作る。**開き直しでもタブ切り替えでもここを通る**ので、
-- 中身(body)は毎回作り直す。窓の大きさもタブごとに違うのでここで合わせる。
local function addons_menu_setting_build(setting)
    local tab = addons_menu_setting_tab()
    local size = ADDONS_MENU_SETTING_SIZE[tab]
    local w, h = size[1], size[2]
    setting:Resize(w, h)
    local close = setting:CreateOrGetControl("button", "close", 0, 0, 30, 30)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "addons_menu_setting_frame_ctrl")
    for i, def in ipairs(ADDONS_MENU_SETTING_TABS) do
        local btn = setting:CreateOrGetControl("button", "tab_" .. def.key, 10 + (i - 1) * 100, 8, 96, 26)
        AUTO_CAST(btn)
        btn:SetSkinName(def.key == tab and "test_pvp_btn" or "test_gray_button")
        btn:SetText("{ol}{s16}" .. addons_menu_ml(def.ja, def.etc))
        btn:SetEventScript(ui.LBUTTONUP, "addons_menu_setting_tab_ctrl")
        btn:SetEventScriptArgString(ui.LBUTTONUP, def.key)
    end
    local body = setting:CreateOrGetControl("groupbox", "body", 0, ADDONS_MENU_SETTING_TAB_H, w,
        h - ADDONS_MENU_SETTING_TAB_H)
    AUTO_CAST(body)
    body:SetSkinName("None")
    body:EnableScrollBar(0)
    body:RemoveAllChild()
    body:Resize(w, h - ADDONS_MENU_SETTING_TAB_H)
    if tab == "layout" then
        addons_menu_setting_build_layout(body)
    elseif tab == "shortcut" then
        addons_menu_setting_build_shortcut(body, w, h - ADDONS_MENU_SETTING_TAB_H)
    else
        addons_menu_setting_build_common(body, w)
    end
    -- タブによって窓の背が変わるので、画面からはみ出したぶんだけ戻す
    -- (開いたときの位置合わせと同じ理由。addons_menu_setting_frame のコメント参照)。
    local map_ui = ui.GetFrame("map")
    local screen_w = (map_ui and map_ui:GetWidth()) or 1920
    local screen_h = (map_ui and map_ui:GetHeight()) or 1080
    local pos_x, pos_y = setting:GetX(), setting:GetY()
    if pos_x + w > screen_w then
        pos_x = screen_w - w
    end
    if pos_y + h > screen_h then
        pos_y = screen_h - h
    end
    setting:SetPos(math.max(pos_x, 0), math.max(pos_y, 0))
    g.vlog("addons_menu: 設定画面のタブ %s を組み立てた(%dx%d)", tab, w, h)
end

-- 設定画面が開いていれば中身を作り直す。開いていなければ何もしない。
local function addons_menu_setting_rebuild()
    local frame = ui.GetFrame(ADDONS_MENU_SETTING_FRAME)
    if frame and frame:IsVisible() == 1 then
        AUTO_CAST(frame)
        addons_menu_setting_build(frame)
    end
end

-- タブの切り替え。開いている窓の中身だけ作り直す。
function _G.addons_menu_setting_tab_ctrl(setting, ctrl, tab_key, num)
    g.addons_menu_setting_tab = tab_key
    g.vlog("addons_menu: 設定画面のタブを %s にした", tostring(tab_key))
    addons_menu_setting_rebuild()
end

-- ショートカットの☆(設定画面側)。一覧の行の☆と同じことをする。
function _G.addons_menu_shortcut_show_ctrl(setting, ctrl, shortcut_key, num)
    if not (g.settings and shortcut_key and shortcut_key ~= "") then
        return
    end
    -- 既定は出どころで違う。"menu:"(相乗り)は出す、"addon:"(こちらの設定画面)は出さない。
    local default_show = string.sub(shortcut_key, 1, 5) == "menu:"
    local shown = g.menu_shortcut_shown(shortcut_key, default_show)
    g.menu_shortcut_set(shortcut_key, "show", shown and 0 or 1)
    _G.addons_menu_refresh_open()
    addons_menu_setting_rebuild()
    -- アドオン一覧の☆も同じ設定を見ているので、開いていれば合わせる。
    if type(_G["_nexus_addons_p_list_build"]) == "function" then
        local list_frame = ui.GetFrame(addon_name_lower .. "list_frame")
        if list_frame then
            pcall(_G["_nexus_addons_p_list_build"], list_frame, g.list_applied_filter or "", true)
        end
    end
end

-- ショートカットタブの表示切り替え(出している項目だけ / 全部)。
-- 画面の見せ方だけなので保存しない(起動のたびに「出している項目だけ」から始まる)。
function _G.addons_menu_shortcut_view_ctrl(setting, ctrl, str, num)
    g.addons_menu_shortcut_show_all = not g.addons_menu_shortcut_show_all
    addons_menu_setting_rebuild()
end

-- ▲▼。今この一覧に出ている範囲で 1 つ動かし、**一覧全体へ 1 から番号を振り直す**。
--
-- 隣とだけ番号を入れ替える作りにしないこと。番号を持たない項目(まだ並べ替えていない
-- ものと、後から入ってきた相乗り項目)が混ざるので、入れ替えだけだと「押しても動かない」
-- 組み合わせが残る。振り直しは対象が数十件なので毎回やっても安い。
--
-- 動かせるのは表示中の並びの中だけ。隠している項目は番号を持ったまま据え置き、
-- 表示へ戻したときにその番号の位置(無ければ末尾)へ入る。
function _G.addons_menu_shortcut_move_ctrl(setting, ctrl, shortcut_key, delta)
    if not (g.settings and shortcut_key and shortcut_key ~= "") then
        return
    end
    delta = tonumber(delta) or 0
    if delta == 0 then
        return
    end
    local rows = addons_menu_shortcut_rows()
    local at
    for idx, entry in ipairs(rows) do
        if entry.shortcut_key == shortcut_key then
            at = idx
            break
        end
    end
    local to = at and (at + delta)
    if not at or to < 1 or to > #rows then
        return
    end
    rows[at], rows[to] = rows[to], rows[at]
    for idx, entry in ipairs(rows) do
        if entry.shortcut_key then
            -- 書き込みは溜めて、下で 1 回だけ保存する(1 押下で項目数ぶん書かない)。
            g.menu_shortcut_set(entry.shortcut_key, "order", idx, true)
        end
    end
    _nexus_addons_p_save_settings()
    g.vlog("menu_shortcut: %s を %d 番目から %d 番目へ動かした", tostring(shortcut_key), at, to)
    _G.addons_menu_refresh_open()
    addons_menu_setting_rebuild()
end

function _G.addons_menu_shortcut_icon_ctrl(setting, ctrl, shortcut_key, num)
    if not (shortcut_key and shortcut_key ~= "") then
        return
    end
    local label = shortcut_key
    for _, entry in ipairs(addons_menu_collect_items(nil, true)) do
        if entry.shortcut_key == shortcut_key then
            label = entry.name
            break
        end
    end
    _G.addons_menu_icon_picker_open(shortcut_key, label)
end

-- アイコンを既定へ戻す。エントリ自体は show を持つので消さず、icon だけ落とす。
function _G.addons_menu_shortcut_icon_reset(setting, ctrl, shortcut_key, num)
    if not (g.settings and shortcut_key and shortcut_key ~= "") then
        return
    end
    g.menu_shortcut_set(shortcut_key, "icon", nil)
    _G.addons_menu_refresh_open()
    addons_menu_setting_rebuild()
    ui.SysMsg(addons_menu_ml("{ol}アイコンを既定に戻しました", "{ol}Icon reset to default"))
end

function _G.addons_menu_setting_frame_ctrl(setting, ctrl)
    local ctrl_name = ctrl:GetName()
    -- frame_name は相乗り側が入れることもあり、まだ誰も入れていない状態で
    -- 設定画面を開ける経路がある。フレーム名は固定なのでフォールバックを置き、
    -- それでも引けなければ frame 無しで進める(下は毎回 nil ガードする)。
    local frame = ui.GetFrame(_G["norisan"]["MENU"].frame_name or "norisan_menu_frame")
    -- 閉じる / 隠すのは**設定画面そのもの**。第 1 引数はタブ化で groupbox(body)に
    -- なることがあるので、ここは必ず名前から引き直す。
    local setting_frame = ui.GetFrame(ADDONS_MENU_SETTING_FRAME)
    if setting_frame then
        AUTO_CAST(setting_frame)
    end
    if ctrl_name == "layer_edit" then
        local layer = tonumber(ctrl:GetText())
        if layer then
            _G["norisan"]["MENU"].layer = layer
            if frame then
                frame:SetLayerLevel(layer)
            end
            addons_menu_save_json(_G["norisan"]["MENU"])
            ui.SysMsg(addons_menu_ml("{ol}レイヤーを変更", "{ol}Change Layer"))
            _G.addons_menu_create_frame()
            if setting_frame then
                setting_frame:ShowWindow(0)
            end
            return
        end
    end
    -- 初期化の速さ。Enter で確定する。**入力をそのまま保存しないこと。**
    -- 0 や負数が入ると分割実行が 1 件も進まないまま回り続ける（g.init_throttle 参照）ので、
    -- 正した値を書き、表示は下の組み立て直しでその値に入れ替える。
    if ctrl_name == "init_batch_edit" then
        local value = tonumber(ctrl:GetText())
        -- g.settings が無いのは本家検出で初期化を止めたときなので、その場合は何もしない
        -- （verbose_log_toggle と同じ理由）。
        if value and g.settings then
            g.settings.init_batch = (g.init_throttle(value))
            _nexus_addons_p_save_settings()
            g.vlog("addons_menu: 初期化の件数を %d にした（入力 %s）", g.settings.init_batch, tostring(value))
            ui.SysMsg(addons_menu_ml("{ol}次のログインから反映されます", "{ol}Applies from the next login"))
        end
        addons_menu_setting_rebuild()
        return
    end
    -- 折り返す数。Enter で確定する。数字以外や範囲外は addons_menu_layout 側で正すので、
    -- ここでは読めた数字をそのまま保存し、表示は組み立て直しで正した値に入れ替わる。
    if ctrl_name == "float_wrap_edit" or ctrl_name == "sysmenu_wrap_edit" then
        local is_float = (ctrl_name == "float_wrap_edit")
        local value = tonumber(ctrl:GetText())
        if value then
            if is_float then
                _G["norisan"]["MENU"].float_wrap = value
            else
                _G["norisan"]["MENU"].sys_wrap = value
            end
            addons_menu_save_json(_G["norisan"]["MENU"])
            _G.addons_menu_refresh_open()
            g.vlog("addons_menu: %s の折り返しを %s にした", is_float and "float" or "sysmenu", tostring(value))
        end
        addons_menu_setting_rebuild()
        return
    end
    if ctrl_name == "float_dir_h" or ctrl_name == "float_dir_v" or ctrl_name == "sysmenu_dir_h" or ctrl_name ==
        "sysmenu_dir_v" then
        local dir = string.sub(ctrl_name, -1)
        if string.sub(ctrl_name, 1, 5) == "float" then
            _G["norisan"]["MENU"].float_dir = dir
        else
            _G["norisan"]["MENU"].sys_dir = dir
        end
        addons_menu_save_json(_G["norisan"]["MENU"])
        _G.addons_menu_refresh_open()
        addons_menu_setting_rebuild()
        return
    end
    if ctrl_name == "def_setting" then
        _G["norisan"]["MENU"].x = 1190
        _G["norisan"]["MENU"].y = 30
        _G["norisan"]["MENU"].move = true
        _G["norisan"]["MENU"].open = 0
        _G["norisan"]["MENU"].layer = 79
        -- 並べ方も既定へ戻す。**足した設定をここへ書き忘れると、
        -- 「デフォルトに戻す」を押しても直らない項目が残る。**
        _G["norisan"]["MENU"].float_dir = ADDONS_MENU_LAYOUT_DEFAULT.float.dir
        _G["norisan"]["MENU"].float_wrap = ADDONS_MENU_LAYOUT_DEFAULT.float.wrap
        _G["norisan"]["MENU"].sys_dir = ADDONS_MENU_LAYOUT_DEFAULT.sysmenu.dir
        _G["norisan"]["MENU"].sys_wrap = ADDONS_MENU_LAYOUT_DEFAULT.sysmenu.wrap
        addons_menu_save_json(_G["norisan"]["MENU"])
        -- 初期化の速さも共通タブに出している設定なので、ここで既定へ戻す。
        -- **詳細ログ(verbose_log)は意図して戻さない。** あちらは調査のために利用者が
        -- 自分で ON にしている状態で、黙って OFF にすると集めている最中のログが止まる。
        if g.settings then
            g.settings.init_batch = g.INIT_BATCH_DEFAULT
            _nexus_addons_p_save_settings()
        end
        _G.addons_menu_create_frame()
        if setting_frame then
            setting_frame:ShowWindow(0)
        end
        return
    end
    if ctrl_name == "close" then
        if setting_frame then
            setting_frame:ShowWindow(0)
        end
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
        -- (addons_menu_save_json は決まったキーしか書き出さない)。
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
    local opened = ui.GetFrame(ADDONS_MENU_SETTING_FRAME)
    if opened and opened:IsVisible() == 1 then
        AUTO_CAST(opened)
        opened:ShowWindow(0)
        g.vlog("addons_menu: 設定画面を閉じる(呼び元 %s)", ctrl and ctrl:GetName() or "unknown")
        return
    end
    g.vlog("addons_menu: 設定画面を開く(呼び元 %s)", ctrl and ctrl:GetName() or "unknown")
    -- 位置決めでも使うので、今のタブの大きさは Resize より前に読んでおく。
    local size = ADDONS_MENU_SETTING_SIZE[addons_menu_setting_tab()]
    local setting_w, setting_h = size[1], size[2]
    local setting = ui.CreateNewFrame("chat_memberlist", ADDONS_MENU_SETTING_FRAME, 0, 0, 0, 0)
    AUTO_CAST(setting)
    setting:SetTitleBarSkin("None")
    -- 他の設定画面と同じ skin にする。**"chat_window" は半透明**で、後ろの画面が透けて
    -- 文字が読みにくかった(実機で指摘)。アドオン一覧や各アドオンの設定画面はどれも
    -- "test_frame_low" なので、見た目をそちらへ揃える。
    setting:SetSkinName("test_frame_low")
    setting:Resize(setting_w, setting_h)
    setting:SetLayerLevel(999)
    setting:EnableHitTest(1)
    setting:EnableMove(1)
    -- **画面の中央に出す。** 以前は呼び元(右上のボタン / システムメニューの一覧)の
    -- 右隣に出していたが、導線が画面の端に居るぶん窓も端へ寄り、はみ出しの手当てが要った。
    -- タブで大きさが変わる窓でもあるので、中央固定のほうが位置が動かず落ち着く。
    -- 画面の大きさは addons_menu_create_frame と同じく map フレームから取り、
    -- 取れないときだけ 1920x1080 とみなす。
    -- 可視かどうかは見ないこと。"map" は全画面のワールドマップで普段は閉じており、
    -- IsVisible() == 1 で絞ると実質いつも 1920x1080 の決め打ちに落ちて、
    -- 下のはみ出し防止が 1920x1080 以外のクライアントで一度も効かなくなる。
    -- 非表示でもフレームのサイズ自体は画面サイズを返す(他アドオンも可視判定なしで読んでいる)。
    local map_ui = ui.GetFrame("map")
    local screen_w = (map_ui and map_ui:GetWidth()) or 1920
    local screen_h = (map_ui and map_ui:GetHeight()) or 1080
    local pos_x = math.floor((screen_w - setting_w) / 2)
    local pos_y = math.floor((screen_h - setting_h) / 2)
    if pos_x < 0 then
        pos_x = 0
    end
    if pos_y < 0 then
        pos_y = 0
    end
    setting:SetPos(pos_x, pos_y)
    g.vlog("addons_menu: 設定画面の位置 %d,%d (中央 / 画面 %dx%d)", pos_x, pos_y, screen_w, screen_h)
    setting:ShowWindow(1)
    addons_menu_setting_build(setting)
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
        -- 本来の処理は addons_menu_item_click 経由で呼ぶ(理由はそちらのコメント)。
        -- 関数名は引数文字列で渡す。ここで data.func を直接入れると一覧が残る。
        item_elem:SetEventScript(ui.LBUTTONUP, "addons_menu_item_click")
        item_elem:SetEventScriptArgString(ui.LBUTTONUP, data.func)
        item_elem:ShowWindow(1)
    end
    return item_elem
end

-- 一覧の項目を押したときの入口。本来の処理を呼んでから、システムメニュー側の一覧を畳む。
--
-- 畳まないと、開いたウィンドウの後ろに一覧(アイコン列)が出たまま残る。この一覧は
-- ESC で閉じる対象なので、**利用者が「開いたウィンドウを閉じよう」と押した ESC が
-- 先に一覧へ使われ、目的のウィンドウは 2 回目でやっと閉じる**ように見える。
--
-- **順番を逆にしないこと。** 呼び元のフレーム(= 一覧)を見る項目があると、先に畳むと
-- 破棄済みのフレームを触ることになる。こちらの設定画面は中央固定にしたので
-- 呼び元を見なくなったが、相乗り側の項目が何を見ているかはこちらでは分からない。
--
-- 引数は受け取ったものをそのまま渡す。相乗り側(_G["norisan"]["MENU"])の項目も
-- イベントスクリプトとして (frame, ctrl, str, num) で呼ばれる前提のため。
function _G.addons_menu_item_click(frame, ctrl, func_name, num)
    local func = _G[func_name]
    if type(func) ~= "function" then
        g.vlog("addons_menu: 項目の関数が見つからない (%s)", tostring(func_name))
        pcall(addons_menu_sysmenu_close, true)
        return
    end
    -- 項目側が転んでも一覧は畳む(残ると上記の「ESC が吸われる」が続く)。
    local ok, err = pcall(func, frame, ctrl, "", num)
    if not ok then
        g.vlog("addons_menu: 項目の処理が転んだ (%s) %s", tostring(func_name), tostring(err))
    end
    pcall(addons_menu_sysmenu_close, true)
end

-- 右上のフローティングメニューの項目を並べる。
--
-- 並べ方は設定(向き / 折り返す数)で決まる。**フレームは本体ボタン(40px)の下または上へ
-- 伸びる**ので、行数が決まらないと高さも上開きの座標も出せない。
-- 縦積み("v")のときは列が右へ増える。横並び("h")と同じく「下と右へ伸びる」に揃えてある
-- (このフレームは利用者が好きな位置へ動かせるので、伸びる向きは固定しないと分かりにくい)。
function _G.addons_menu_toggle_items_display(frame, ctrl, open_dir)
    local open_up = (open_dir == 1)
    local item_w = ADDONS_MENU_ITEM_SIZE
    local item_h = ADDONS_MENU_ITEM_SIZE
    local y_off_down = 35
    local items = addons_menu_collect_items()
    local num_items = #items
    if num_items == 0 then
        -- 出す項目が 1 つも無いとき(全部「出さない」にした)は、本体ボタンだけの大きさに戻す。
        -- 空の枠を開くと「押したのに何も出ない」ように見える。
        frame:Resize(40, 40)
        frame:SetPos(frame:GetX(), _G["norisan"]["MENU"].y or 30)
        local only_btn = GET_CHILD(frame, "addons_menu_pic")
        if only_btn then
            only_btn:SetPos(0, 0)
        end
        g.vlog("addons_menu: 右上の一覧は項目が無いので開かない")
        return
    end
    local dir, wrap = addons_menu_layout("float")
    local num_cols, num_rows, cell = addons_menu_grid(num_items, dir, wrap)
    local items_h = num_rows * item_h
    local frame_h_new = 40 + items_h
    local frame_y_new = _G["norisan"]["MENU"].y or 30
    if open_up then
        frame_y_new = frame_y_new - items_h
    end
    local frame_w_new = math.max(40, num_cols * item_w)
    frame:SetPos(frame:GetX(), frame_y_new)
    frame:Resize(frame_w_new, frame_h_new)
    for idx, entry in ipairs(items) do
        local col, row = cell(idx - 1)
        local x = col * item_w
        local y
        if open_up then
            -- 上開きは下から数える。row 0 が本体ボタンのすぐ上に来る。
            y = (frame_h_new - 40) - ((row + 1) * item_h)
        else
            y = y_off_down + (row * item_h)
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
    g.vlog("addons_menu: 右上の一覧を並べた 項目=%d 向き=%s 折り返し=%d 列=%d 行=%d", num_items, dir, wrap, num_cols,
        num_rows)
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
--
-- 呼び出し元が「この押下を使ったか」を判断できるよう、
-- **画面に出ていたものを畳んだときだけ true** を返す。
--
-- **存在するかどうかで数えないこと。** 一覧は破棄されるまで残るので、
-- 「在るが画面には出ていない」状態で数えると、利用者から見て何も起きない押下を
-- 消費してしまう(実機ログ: stack=0 の押下が消費され、次の 1 回でようやくシステムメニューが
-- 開いた = 「1 回目が空振り」の正体)。畳む処理自体は残骸の掃除として毎回行い、
-- 消費するかどうかだけを可視だったかで決める。
function _G.addons_menu_on_escape()
    local closed = false
    local list = ui.GetFrame(SYSMENU_LIST_FRAME)
    if list then
        -- 出ていた分だけ「この押下で閉じた」と数える。残骸は掃除だけして数えない。
        if list:IsVisible() == 1 then
            closed = true
        end
        ui.DestroyFrame(SYSMENU_LIST_FRAME)
    end
    -- 設定画面も同じ土台なので同じことが起きる。こちらは破棄せず隠す
    -- (CreateNewFrame で作り直せないため。addons_menu_setting_frame のコメント参照)。
    local setting = ui.GetFrame("addons_menu_setting")
    if setting and setting:IsVisible() == 1 then
        AUTO_CAST(setting)
        setting:ShowWindow(0)
        closed = true
    end
    return closed
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
    _G.addons_menu_sysmenu_open()
end

-- 一覧を組み立てて出す。**開閉の判断はしない**ので、出したまま中身を作り直したいとき
-- (☆や並べ方を変えた直後)にも呼べる。開閉の入口は上の toggle。
function _G.addons_menu_sysmenu_open(silent)
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
    -- 並べ方は設定(向き / 折り返す数)で決まる。既定は縦一列で、設定(collect_items が
    -- 末尾に足す歯車)が一番下に来て、他のボタンはその上へ登録順に積み上がる。
    -- 入らなくなったら左へ列を足して折り返す。
    --
    -- **ここは右下(ボタンの側)から数える。** フレームの右下をボタンに合わせて置くので、
    -- 末尾の項目が角に来るように並べないと、項目が増えたときに既存の項目の位置が動く。
    local dir, wrap = addons_menu_layout("sysmenu")
    local num_cols, num_rows = addons_menu_grid(#items, dir, wrap)
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
    -- 可視判定を挟まないこと(理由は addons_menu_open_setting と同じ)。
    local map_ui = ui.GetFrame("map")
    local screen_h = (map_ui and map_ui:GetHeight()) or 1080
    local below_y = btn_y + btn:GetHeight() + 4
    local pos_y = below_y
    if below_y + height > screen_h then
        pos_y = btn_y - height - 4
    end
    if pos_y < 0 then
        pos_y = 0
    end
    frame:SetPos(pos_x, pos_y)
    -- 位置は「末尾から数えた番号」で決める。addons_menu_grid の cell はこの番号を
    -- そのまま (列, 行) にするので、右下の角から左と上へ伸びる。
    local _, _, cell = addons_menu_grid(#items, dir, wrap)
    for idx, entry in ipairs(items) do
        local col, row = cell(#items - idx)
        -- 座標は端の余白の内側で、間隔(pitch)で数える。
        local x = pad + inner_w - (col + 1) * pitch
        local y = pad + inner_h - (row + 1) * pitch
        addons_menu_create_item(frame, "sysmenu_item_" .. entry.key, entry, x, y, item_w, item_h)
    end
    frame:ShowWindow(1)
    -- ui.OpenFrame 経由では音が鳴らなかった(実機で確認)ので、明示的に鳴らす。
    -- 出したまま中身を作り直しただけのとき(silent)は鳴らさない。開いた覚えが無いのに
    -- 音だけ鳴ると、押していないボタンが反応したように聞こえる。
    if not silent then
        addons_menu_play_se(SYSMENU_SE_OPEN)
    end
    -- 位置ずれを追えるよう、判断材料(ボタンの画面座標・画面の高さ・上下どちらに出したか)を出す。
    g.vlog("addons_menu: システムメニューの一覧を開いた 項目=%d 向き=%s 折り返し=%d 位置=%d,%d ボタン=%d,%d 画面高=%d %s",
        #items, dir, wrap, frame:GetX(), frame:GetY(), btn_x, btn_y, screen_h,
        (pos_y == below_y) and "下に表示" or "上に表示")
end

-- 開いたままのメニューへ、項目の増減やアイコンの変更を反映する。
-- どちらも開いていなければ何もしない(閉じている窓を勝手に開かない)。
--
-- 一覧の☆や設定画面から呼ばれる。**呼び元は「定義されていれば呼ぶ」形にすること。**
-- core/20_lifecycle.lua は読み込み時ガードの内側から呼ぶ経路があり、
-- こちらが読まれる前に呼ばれうる。
function _G.addons_menu_refresh_open()
    local list = ui.GetFrame(SYSMENU_LIST_FRAME)
    if list and list:IsVisible() == 1 then
        _G.addons_menu_sysmenu_open(true)
    end
    local frame = ui.GetFrame(_G["norisan"]["MENU"].frame_name or "norisan_menu_frame")
    -- フローティング側は「本体ボタン(40px)より背が高い = 項目を出している」で判断する。
    -- 開いているかどうかを持っている変数は無く、フレームの大きさが唯一の手がかり。
    if frame and frame:IsVisible() == 1 and frame:GetHeight() > 40 then
        AUTO_CAST(frame)
        -- 項目が減ると余ったコントロールが残るので、作り直す前に落とす
        -- (本体ボタンだけは残す。addons_menu_frame_open が畳むときと同じ扱い)。
        for i = frame:GetChildCount() - 1, 0, -1 do
            local child = frame:GetChildByIndex(i)
            if child and child:GetName() ~= "addons_menu_pic" then
                frame:RemoveChild(child:GetName())
            end
        end
        _G.addons_menu_toggle_items_display(frame, nil, _G["norisan"]["MENU"].open or 0)
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
    -- **並べ方の設定を先に読むこと。** この関数は下で addons_menu_save_json を呼ぶが、
    -- あれは決まったキーを丸ごと書き出すので、読む前に保存すると float_dir などが
    -- 未設定のまま上書きされ、**ログインのたびに並べ方の設定が消える**。
    addons_menu_load_layout()
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
    -- ここも可視判定は挟まない(理由は addons_menu_open_setting と同じ)。
    -- 元は if map_ui:IsVisible() then と書いていたが、IsVisible() は 0/1 を返し
    -- Lua では 0 も真なので、結局いつも実サイズを読んでいた。挙動は変えていない。
    local map_ui = ui.GetFrame("map")
    local screen_w = (map_ui and map_ui:GetWidth()) or 1920
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
