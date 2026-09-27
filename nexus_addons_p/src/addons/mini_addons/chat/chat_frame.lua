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
    core_g.vlog("mini_addons: chat_frame[%s] 設定 chat_new_btn=%s group_chat=%s CHAT_TYPE_SELECTED_VALUE=%s",
        tostring(tag), tostring(g.settings.chat_new_btn), tostring(g.settings.group_chat),
        tostring(chat:GetUserValue("CHAT_TYPE_SELECTED_VALUE")))
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
-- 素の CHAT_SET_TO_TITLENAME(宛先を選び直すたびに走る)と、グループチャットの
-- Mini_addons_group_chat_setting は **mainchat:GetOriginalWidth()(= 415)基準で幅を組み直す**ので、
-- その都度ここを通すこと。
function Mini_addons_chat_fit_input(tag)
    if g.settings.chat_new_btn ~= 1 then
        return
    end
    local chat = ui.GetFrame("chat")
    if not chat then
        return
    end
    local mainchat = GET_CHILD(chat, "mainchat")
    local item_btn = GET_CHILD(chat, "item_btn")
    if not mainchat or not item_btn then
        return
    end
    -- ボタン列の左端(item_btn)の 4px 手前まで
    local limit = item_btn:GetX() - 4 - mainchat:GetX()
    local before_w = mainchat:GetWidth()
    if before_w <= limit then
        core_g.vlog("mini_addons: chat_fit_input[%s] mainchat x=%s w=%s は item_btn x=%s に届かないので触らない",
            tostring(tag), tostring(mainchat:GetX()), tostring(before_w), tostring(item_btn:GetX()))
        return
    end
    mainchat:Resize(limit, mainchat:GetHeight())
    -- OFF にしたとき素の幅へ返すための控え(Mini_addons_chat_unfit_input)
    chat:SetUserValue("NEXUS_CHAT_FIT_FROM_W", before_w)
    chat:SetUserValue("NEXUS_CHAT_FIT_TO_W", mainchat:GetWidth())
    core_g.vlog("mini_addons: chat_fit_input[%s] mainchat x=%s w=%s -> %s (item_btn x=%s)", tostring(tag),
        tostring(mainchat:GetX()), tostring(before_w), tostring(mainchat:GetWidth()), tostring(item_btn:GetX()))
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
    -- **ON でも OFF でも chat の幅は素の 500 のまま。** 旧版は ON で 585 へ広げていたので、
    -- それを戻すためだけに呼ぶ(既に 500 なら Resize は呼ばれず、高さの丸めも起きない)。
    -- 旧版で一度 150 に丸まった高さはクライアントを再起動するまで戻らない。
    Mini_addons_chat_resize_width(chat, chat:GetOriginalWidth())
    edit_bg:Resize(edit_bg:GetOriginalWidth(), edit_bg:GetOriginalHeight())
    mainchat:SetGravity(ui.LEFT, ui.TOP)
    if g.settings.chat_new_btn == 0 then
        Mini_addons_chat_unfit_input(chat, mainchat)
        chat:SetPos(g.settings.chat_xy.x or chat:GetX(), g.settings.chat_xy.y or chat:GetY())
        Mini_addons_chat_frame_vlog("off")
        -- 素の CHAT_SET_TO_TITLENAME は宛先が決まってから走るので、こちらが組み終えた
        -- 直後の姿だけでは足りない。後から素に上書きされていないかを遅れて見る
        ReserveScript("Mini_addons_chat_frame_vlog('off_delay')", 3.0)
        return
    end
    edit_to_bg:SetGravity(ui.LEFT, ui.TOP)
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
    Mini_addons_chat_fit_input("update")
    chat:SetPos(g.settings.chat_xy.x or chat:GetX(), g.settings.chat_xy.y or chat:GetY())
    chat:Invalidate()
    Mini_addons_chat_frame_vlog("on")
    ReserveScript("Mini_addons_chat_frame_vlog('on_delay')", 3.0)
end

