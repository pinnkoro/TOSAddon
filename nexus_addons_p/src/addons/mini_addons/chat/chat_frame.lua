-- チャットフレーム改造
function Mini_addons_chat_frame_drop(chat)
    g.settings.chat_xy.x = chat:GetX()
    g.settings.chat_xy.y = chat:GetY()
    Mini_addons_save_settings()
    -- チャット枠を掴んだとき = 利用者が「今の姿」を確かめたいとき。素の
    -- CHAT_SET_TO_TITLENAME は宛先を選び直すたびに走るので、起動時のログだけでは
    -- 崩れた瞬間を捉えられない。ここを手動の採取点にする(詳細ログ OFF なら何も出ない)
    Mini_addons_chat_frame_vlog("drop")
end

function Mini_addons_my_pos()
    local map_frame = ui.GetFrame("map")
    local map_pic = GET_CHILD(map_frame, "map")
    local my_pos = GET_CHILD(map_frame, "my")
    local x, y = GET_C_XY(my_pos)
    x = x + (my_pos:GetWidth() / 2) - map_pic:GetX()
    y = y + (my_pos:GetHeight() / 2) - map_pic:GetY()
    local map_name = session.GetMapName()
    local map_prop = geMapTable.GetMapProp(map_name)
    local worldPos = map_prop:MinimapPosToWorldPos(x, y, map_pic:GetWidth(), map_pic:GetHeight())
    LINK_MAP_POS(map_name, worldPos.x, worldPos.y)
end

function Mini_addons_toggle_inventory()
    ui.ToggleFrame("inventory")
end

-- チャット入力フレームの各コントロールの位置と大きさを詳細ログへ出す。
-- 「ボタン追加」(この下の Mini_addons_update_chat_frame)と、素の CHAT_SET_TO_TITLENAME
-- (グループ / ささやきの宛先表示)は **同じ edit_bg / edit_to_bg / mainchat を取り合う**。
-- 素は mainchat:GetOriginalWidth()(= XML の 415)を基準に組み直すので、こちらが 585 へ
-- 広げた分は素が走った時点で無かったことになる。どちらが最後に触ったかを見るための材料。
function Mini_addons_chat_frame_vlog(tag)
    local chat = ui.GetFrame("chat")
    if not chat then
        core_g.vlog("mini_addons: chat_frame[%s] chat フレームが無い", tostring(tag))
        return
    end
    local function dump(name, ctrl)
        if not ctrl then
            core_g.vlog("mini_addons: chat_frame[%s] %s = 無い", tostring(tag), name)
            return
        end
        core_g.vlog("mini_addons: chat_frame[%s] %s xy=(%s,%s) wh=(%s,%s) orig_y=%s orig_wh=(%s,%s) visible=%s",
            tostring(tag), name, tostring(ctrl:GetX()), tostring(ctrl:GetY()), tostring(ctrl:GetWidth()),
            tostring(ctrl:GetHeight()), tostring(ctrl:GetOriginalY()), tostring(ctrl:GetOriginalWidth()),
            tostring(ctrl:GetOriginalHeight()), tostring(ctrl:IsVisible()))
    end
    dump("chat", chat)
    dump("edit_bg", GET_CHILD(chat, "edit_bg"))
    dump("edit_to_bg", GET_CHILD(chat, "edit_to_bg"))
    dump("mainchat", GET_CHILD(chat, "mainchat"))
    dump("button_type", GET_CHILD(chat, "button_type"))
    dump("button_emo", GET_CHILD(chat, "button_emo"))
    local edit_to_bg = GET_CHILD(chat, "edit_to_bg")
    local title_to = nil
    if edit_to_bg then
        title_to = GET_CHILD(edit_to_bg, "title_to")
    end
    dump("title_to", title_to)
    if title_to then
        AUTO_CAST(title_to)
        core_g.vlog("mini_addons: chat_frame[%s] title_to text=%s", tostring(tag), tostring(title_to:GetText()))
    end
    core_g.vlog(
        "mini_addons: chat_frame[%s] 設定 chat_new_btn=%s chat_width=%s group_chat=%s CHAT_TYPE_SELECTED_VALUE=%s",
        tostring(tag), tostring(g.settings.chat_new_btn), tostring(Mini_addons_chat_width_px()),
        tostring(g.settings.group_chat), tostring(chat:GetUserValue("CHAT_TYPE_SELECTED_VALUE")))
end

-- chat フレームの幅だけを変える。
--
-- 素の chat.xml は `<input ... minheight="150">` を持っており、**Resize を呼んだ時点で
-- 高さが 36 → 150 へ丸め上げられる**(実機のログで確認。原寸の 36 を渡しても 150 になる)。
-- 高さが 150 になると次の 2 つが起きる。
--   * `layout_gravity="left center"` の edit_to_bg(宛先の箱)が親の縦中央 y=(150-32)/2=59 へ落ちる
--   * 下の SetPos で左上を固定しているので、増えた 114px が**下へ**出る
--     (素は `layout_gravity="center bottom"` の下端アンカーで**上へ**開く作り。
--      SetPos を呼んだ時点でそのアンカーが効かなくなる)
-- どちらも意図した動きではないので、**幅が既に目標なら Resize を呼ばない**。
-- 呼ばざるを得ないときも高さは原寸ではなく現在値を渡す。丸めが起きたかどうかは
-- 詳細ログ(chat_resize)で追える。
function Mini_addons_chat_resize_width(chat, width)
    local before_w = chat:GetWidth()
    local before_h = chat:GetHeight()
    if before_w == width then
        core_g.vlog("mini_addons: chat_resize 幅は既に %s なので Resize を呼ばない (h=%s)", tostring(width),
            tostring(before_h))
        return
    end
    chat:Resize(width, before_h)
    core_g.vlog("mini_addons: chat_resize (%s,%s) -> 指示(%s,%s) -> 実際(%s,%s)%s", tostring(before_w),
        tostring(before_h), tostring(width), tostring(before_h), tostring(chat:GetWidth()),
        tostring(chat:GetHeight()),
        chat:GetHeight() ~= before_h and " ★高さが勝手に変わった(minheight の丸め)" or "")
end

-- ボタンを置いたとき、入力欄(mainchat)の右端をボタンの手前で止める。
--
-- 以前は chat フレームを 585 へ広げてボタンの置き場を作っていたが、**chat を Resize すると
-- 高さが素の minheight="150" へ丸め上げられ**、SetPos で左上を固定しているので増えた
-- 114px が入力バーの**下へ**出ていた。chat.xml は hittestframe="true" なので、見た目には
-- 何も無いその帯がクリックを吸い、3D 画面へ抜けなくなる(#172)。
-- 高さの丸めは Resize を呼ぶ限り避けられないので、**幅は素の 500 のまま**にして、
-- ボタンは button_emo の左へ詰めて置く。代わりに入力欄の右端がボタンに重なるので、ここで縮める。
--
-- 入力バーを広げる(chat_width)が ON のときは、逆に入力欄を**右端まで伸ばす**(下の
-- Mini_addons_chat_width_px)。右端はボタン追加が ON なら item_btn、OFF なら button_emo の手前。
--
-- 素の CHAT_SET_TO_TITLENAME(宛先を選び直すたびに走る)・CHAT_OPEN_INIT(日本版は開くたびに
-- 入力欄の幅を組み直す)と、グループチャットの Mini_addons_group_chat_setting は
-- **mainchat:GetOriginalWidth()(= 415)基準で幅を組み直す**ので、その都度ここを通すこと。
function Mini_addons_chat_fit_input(tag)
    local extra = Mini_addons_chat_width_px()
    if g.settings.chat_new_btn ~= 1 and extra == 0 then
        return
    end
    local chat = ui.GetFrame("chat")
    if not chat then
        return
    end
    local mainchat = GET_CHILD(chat, "mainchat")
    local right_name = g.settings.chat_new_btn == 1 and "item_btn" or "button_emo"
    local right_ctrl = GET_CHILD(chat, right_name)
    if not mainchat or not right_ctrl then
        return
    end
    -- 右隣のコントロール(ボタン列の左端か絵文字ボタン)の 4px 手前まで
    local limit = right_ctrl:GetX() - 4 - mainchat:GetX()
    local before_w = mainchat:GetWidth()
    -- 広げない(ボタン追加だけ)ときは縮めるだけ。素の幅がボタンに届いていなければ触らない
    if before_w == limit or (extra == 0 and before_w < limit) then
        core_g.vlog("mini_addons: chat_fit_input[%s] mainchat x=%s w=%s は %s x=%s に合っているので触らない",
            tostring(tag), tostring(mainchat:GetX()), tostring(before_w), right_name, tostring(right_ctrl:GetX()))
        return
    end
    -- OFF にしたとき素の幅へ返すための控え(Mini_addons_chat_unfit_input)。
    -- **今の幅がこちらで組んだ幅(TO)のままなら、控え(FROM)は取り直さない。** 取り直すと
    -- 「前回こちらが組んだ幅」を素の幅として覚えてしまい、OFF にしても素の幅へ戻らない
    if before_w ~= chat:GetUserIValue("NEXUS_CHAT_FIT_TO_W") then
        chat:SetUserValue("NEXUS_CHAT_FIT_FROM_W", before_w)
    end
    mainchat:Resize(limit, mainchat:GetHeight())
    chat:SetUserValue("NEXUS_CHAT_FIT_TO_W", mainchat:GetWidth())
    core_g.vlog("mini_addons: chat_fit_input[%s] mainchat x=%s w=%s -> %s (%s x=%s, 広げる幅=%s)", tostring(tag),
        tostring(mainchat:GetX()), tostring(before_w), tostring(mainchat:GetWidth()), right_name,
        tostring(right_ctrl:GetX()), tostring(extra))
end

-- 入力欄の数値の上限と既定値。画面からはみ出すほど広げても使い道が無いので抑える
Mini_addons_CHAT_WIDTH_MAX = 1000
Mini_addons_CHAT_WIDTH_DEF = 200

-- 入力バーを広げる幅(px)。機能 OFF なら 0。
-- 設定の読み込みはトップレベルのキーしか既定値で補わないので、中身は欠けていてもよいように読む
function Mini_addons_chat_width_px()
    local cfg = g.settings.chat_width
    if type(cfg) ~= "table" or cfg.use ~= 1 then
        return 0
    end
    local px = tonumber(cfg.px) or Mini_addons_CHAT_WIDTH_DEF
    return math.max(0, math.min(Mini_addons_CHAT_WIDTH_MAX, math.floor(px)))
end

-- chat フレームの背景の当たり判定を、高さに合わせて切り替える。
--
-- 幅を変えると(Mini_addons_chat_resize_width)高さが素の minheight="150" へ丸め上げられ、
-- 増えた 114px が入力バーの下へ透明な帯として出る。chat.xml は hittestframe="true" なので、
-- そのままだと帯がクリックを吸い、3D 画面へ抜けなくなる(#172)。
-- **背景の当たり判定だけを切る**(EnableHittestFrame(0))。入力欄やボタンは各自の当たり判定で
-- 受けるので押せるまま(素の tutorial_text.lua も同じ使い方をしている)。
-- 高さが原寸(36)のときは素の XML と同じ 1 に戻す。旧版で 150 に丸まったまま
-- (再起動まで戻らない)の人も、ここを通れば帯を素通りするようになる。
--
-- 背景を切ると**入力バーを掴んで動かせなくなる**(実機で確認。掴める場所が背景しか無い)ので、
-- 代わりに入力バーの見た目の背景(edit_bg)に当たり判定を持たせ、そこを掴んだときだけ
-- 自前で動かす(Mini_addons_chat_drag_start)。edit_bg は入力欄やボタンの下に敷かれているので、
-- それらの操作は邪魔しない。
function Mini_addons_chat_update_hittest(chat)
    local tall = chat:GetHeight() > chat:GetOriginalHeight()
    chat:EnableHittestFrame(tall and 0 or 1)
    local edit_bg = GET_CHILD(chat, "edit_bg")
    if edit_bg then
        AUTO_CAST(edit_bg)
        edit_bg:EnableHittestGroupBox(tall)
        edit_bg:SetEventScript(ui.LBUTTONDOWN, tall and "Mini_addons_chat_drag_start" or "")
    end
    Mini_addons_chat_update_grip(chat, tall)
    core_g.vlog("mini_addons: chat_hittest h=%s orig_h=%s -> EnableHittestFrame(%s) edit_bg ドラッグ=%s",
        tostring(chat:GetHeight()), tostring(chat:GetOriginalHeight()), tall and "0" or "1", tostring(tall))
end

-- 入力バーの右端に、掴んで動かすための取っ手(nexus_chat_grip)を置く。
-- edit_bg の背景は入力欄やボタンの隙間しか見えておらず、掴める範囲が狭い(実機で確認)ので、
-- 目印になる場所を別に用意する。置き場は button_emo の右で、そのぶん button_emo の
-- 右余白(素は 6)を広げる。ボタン追加のボタンと入力欄の右端は button_emo の位置から
-- 決まるので、一緒に左へ寄る。帯が無い(背景を掴める)ときは素の余白へ戻して取っ手も消す
Mini_addons_CHAT_GRIP_W = 22
function Mini_addons_chat_update_grip(chat, tall)
    local button_emo = GET_CHILD(chat, "button_emo")
    if not button_emo then
        return
    end
    chat:RemoveChild("nexus_chat_grip")
    if not tall then
        button_emo:SetMargin(0, 0, 6, 0)
        return
    end
    button_emo:SetMargin(0, 0, 6 + Mini_addons_CHAT_GRIP_W, 0)
    local grip = chat:CreateOrGetControl("button", "nexus_chat_grip", 0, 0, Mini_addons_CHAT_GRIP_W, 36)
    AUTO_CAST(grip)
    grip:SetGravity(ui.RIGHT, ui.TOP)
    grip:SetMargin(0, 0, 4, 0)
    grip:SetSkinName("textbutton")
    grip:SetText("{ol}{s18}≡")
    grip:SetTextTooltip(g.lang == "Japanese" and "{ol}ドラッグで入力バーを移動" or g.lang == "kr" and
                            "{ol}드래그하여 입력창 이동" or "{ol}Drag to move the input bar")
    grip:SetEventScript(ui.LBUTTONDOWN, "Mini_addons_chat_drag_start")
    core_g.vlog("mini_addons: chat_grip chat w=%s button_emo x=%s grip x=%s", tostring(chat:GetWidth()),
        tostring(button_emo:GetX()), tostring(grip:GetX()))
end

-- edit_bg か取っ手を掴んだとき。素のチャット枠の LBtnDownScp(CHAT_CLICK_CHECK = 絵文字・チャット種別の
-- ポップアップを閉じる)も、背景を切ると呼ばれなくなるのでここで呼ぶ
function Mini_addons_chat_drag_start(parent, ctrl)
    local chat = ui.GetFrame("chat")
    CHAT_CLICK_CHECK()
    local mx, my = GET_MOUSE_POS()
    chat:SetUserValue("NEXUS_DRAG_MX", math.floor(mx / ui.GetRatioWidth()))
    chat:SetUserValue("NEXUS_DRAG_MY", math.floor(my / ui.GetRatioHeight()))
    chat:SetUserValue("NEXUS_DRAG_X", chat:GetX())
    chat:SetUserValue("NEXUS_DRAG_Y", chat:GetY())
    ctrl:RunUpdateScript("Mini_addons_chat_drag_update", 0.01)
    core_g.vlog("mini_addons: chat_drag start chat=(%s,%s) mouse=(%s,%s)", tostring(chat:GetX()),
        tostring(chat:GetY()), tostring(chat:GetUserIValue("NEXUS_DRAG_MX")),
        tostring(chat:GetUserIValue("NEXUS_DRAG_MY")))
end

function Mini_addons_chat_drag_update(ctrl)
    local chat = ui.GetFrame("chat")
    if mouse.IsLBtnPressed() == 0 then
        Mini_addons_chat_frame_drop(chat)
        core_g.vlog("mini_addons: chat_drag end chat=(%s,%s)", tostring(chat:GetX()), tostring(chat:GetY()))
        return 0
    end
    local mx, my = GET_MOUSE_POS()
    mx = mx / ui.GetRatioWidth()
    my = my / ui.GetRatioHeight()
    chat:SetPos(chat:GetUserIValue("NEXUS_DRAG_X") + math.floor(mx) - chat:GetUserIValue("NEXUS_DRAG_MX"),
        chat:GetUserIValue("NEXUS_DRAG_Y") + math.floor(my) - chat:GetUserIValue("NEXUS_DRAG_MY"))
    return 1
end

-- 設定画面の「広げる幅」の入力欄(Enter で確定)。
-- ENTERKEY の中なので、入力欄ごと設定画面を作り直さないこと(Enter でチャットが開く)
function Mini_addons_chat_width_edit(frame, ctrl)
    local value = tonumber(ctrl:GetText())
    g.settings.chat_width = g.settings.chat_width or {}
    if not value or value < 0 or value > Mini_addons_CHAT_WIDTH_MAX then
        ui.SysMsg(g.lang == "Japanese" and
                      string.format("無効な値です。0から%dの間で設定してください。", Mini_addons_CHAT_WIDTH_MAX) or
                      string.format("Invalid value please set between 0 and %d", Mini_addons_CHAT_WIDTH_MAX))
        value = Mini_addons_CHAT_WIDTH_DEF
    end
    value = math.floor(value)
    -- **{ol} を混ぜない**(混ぜると GetText がそのまま返し、次の Enter で無効な値になる)
    ctrl:SetText(tostring(value))
    g.settings.chat_width.px = value
    Mini_addons_save_settings()
    core_g.vlog("mini_addons: chat_width_edit px=%s use=%s", tostring(value), tostring(g.settings.chat_width.use))
    Mini_addons_update_chat_frame()
end

-- OFF にしたとき、Mini_addons_chat_fit_input が縮めた入力欄を縮める前の幅へ返す。
-- **縮めた後に素が組み直していたら(幅が控えと違う)触らない。** 素の幅を上書きしてしまうため
function Mini_addons_chat_unfit_input(chat, mainchat)
    local from_w = chat:GetUserIValue("NEXUS_CHAT_FIT_FROM_W")
    local to_w = chat:GetUserIValue("NEXUS_CHAT_FIT_TO_W")
    chat:SetUserValue("NEXUS_CHAT_FIT_FROM_W", 0)
    chat:SetUserValue("NEXUS_CHAT_FIT_TO_W", 0)
    if from_w <= 0 or mainchat:GetWidth() ~= to_w then
        core_g.vlog("mini_addons: chat_unfit_input 控え from=%s to=%s 今=%s なので触らない", tostring(from_w),
            tostring(to_w), tostring(mainchat:GetWidth()))
        return
    end
    mainchat:Resize(from_w, mainchat:GetHeight())
    core_g.vlog("mini_addons: chat_unfit_input mainchat w=%s -> %s", tostring(to_w), tostring(mainchat:GetWidth()))
end

-- 素の CHAT_SET_TO_TITLENAME の後に来る(イベント方式)。素が入力欄を 415 基準へ戻すので縮め直す
function Mini_addons_chat_fit_input_after_title(my_frame, my_msg)
    Mini_addons_chat_fit_input("set_to_titlename")
end

-- 素の CHAT_OPEN_INIT の後に来る(イベント方式)。日本版は入力バーを開くたびに入力欄の幅を
-- 415 基準で組み直すので、広げた分 / ボタンの分を合わせ直す
function Mini_addons_chat_fit_input_after_open(my_frame, my_msg)
    Mini_addons_chat_fit_input("open_init")
end

function Mini_addons_update_chat_frame()
    Mini_addons_chat_frame_vlog("before")
    local chat = ui.GetFrame("chat")
    local mainchat = GET_CHILD(chat, "mainchat")
    local edit_bg = GET_CHILD(chat, "edit_bg")
    local edit_to_bg = GET_CHILD(chat, "edit_to_bg")
    AUTO_CAST(mainchat)
    AUTO_CAST(edit_bg)
    AUTO_CAST(edit_to_bg)
    chat:RemoveChild("pos_btn")
    chat:RemoveChild("party_btn")
    chat:RemoveChild("item_btn")
    chat:SetEventScript(ui.LBUTTONUP, "Mini_addons_chat_frame_drop")
    -- **ボタン追加だけなら chat の幅は素の 500 のまま。** 広げるのは「入力バーを広げる」
    -- (chat_width)が ON のときだけ。旧版はボタン追加で 585 へ広げていたので、OFF ならそれを
    -- 戻すためにも呼ぶ(既に目標の幅なら Resize は呼ばれず、高さの丸めも起きない)。
    -- 一度 150 に丸まった高さはクライアントを再起動するまで戻らないので、背景の当たり判定は
    -- 高さを見て切り替える(Mini_addons_chat_update_hittest)。
    local extra = Mini_addons_chat_width_px()
    Mini_addons_chat_resize_width(chat, chat:GetOriginalWidth() + extra)
    edit_bg:Resize(edit_bg:GetOriginalWidth() + extra, edit_bg:GetOriginalHeight())
    Mini_addons_chat_update_hittest(chat)
    mainchat:SetGravity(ui.LEFT, ui.TOP)
    -- 高さが 150 になっていると、left center の宛先の箱が縦中央(y=59)へ落ちる
    if chat:GetHeight() > chat:GetOriginalHeight() then
        edit_to_bg:SetGravity(ui.LEFT, ui.TOP)
    end
    if g.settings.chat_new_btn == 0 and extra == 0 then
        Mini_addons_chat_unfit_input(chat, mainchat)
        chat:SetPos(g.settings.chat_xy.x or chat:GetX(), g.settings.chat_xy.y or chat:GetY())
        Mini_addons_chat_frame_vlog("off")
        -- 素の CHAT_SET_TO_TITLENAME は宛先が決まってから走るので、こちらが組み終えた
        -- 直後の姿だけでは足りない。後から素に上書きされていないかを遅れて見る
        ReserveScript("Mini_addons_chat_frame_vlog('off_delay')", 3.0)
        return
    end
    edit_to_bg:SetGravity(ui.LEFT, ui.TOP)
    if g.settings.chat_new_btn == 1 then
        Mini_addons_chat_create_buttons(chat)
    end
    Mini_addons_chat_fit_input("update")
    chat:SetPos(g.settings.chat_xy.x or chat:GetX(), g.settings.chat_xy.y or chat:GetY())
    chat:Invalidate()
    Mini_addons_chat_frame_vlog("on")
    ReserveScript("Mini_addons_chat_frame_vlog('on_delay')", 3.0)
end

-- ボタン追加(chat_new_btn)の 3 つのボタンを button_emo の左へ詰めて置く。
-- button_emo は right top なので、入力バーを広げたときも右端に付いて動く
function Mini_addons_chat_create_buttons(chat)
    local button_emo = GET_CHILD(chat, "button_emo")
    local base_x = button_emo:GetX() - 35
    local function create_btn(name, x_offset, img, script, w, h)
        local btn = chat:CreateOrGetControl("button", name, 0, 0, 0, 0)
        AUTO_CAST(btn)
        btn:SetPos(base_x + x_offset, 0)
        btn:SetClickSound("button_click")
        btn:SetOverSound("button_cursor_over_2")
        btn:SetAnimation("MouseOnAnim", "btn_mouseover")
        btn:SetAnimation("MouseOffAnim", "btn_mouseoff")
        btn:SetEventScript(ui.LBUTTONDOWN, script)
        if img:find("{") then
            btn:SetText(img)
            btn:SetSkinName("textbutton")
        else
            btn:SetImage(img)
        end
        btn:Resize(w, h)
        return btn
    end
    create_btn("pos_btn", 0, "button_pos_img", "Mini_addons_my_pos", 39, 39)
    create_btn("party_btn", -32, "btn_partyshare", "LINK_PARTY_INVITE", 36, 36)
    create_btn("item_btn", -70, "{img sysmenu_inv 42 42}", "Mini_addons_toggle_inventory", 40, 37)
    core_g.vlog("mini_addons: chat_create_buttons chat w=%s button_emo x=%s -> base_x=%s", tostring(chat:GetWidth()),
        tostring(button_emo:GetX()), tostring(base_x))
end

