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
    if g.settings.chat_new_btn == 0 then
        Mini_addons_chat_resize_width(chat, chat:GetOriginalWidth())
        mainchat:SetGravity(ui.LEFT, ui.TOP)
        chat:SetPos(g.settings.chat_xy.x or chat:GetX(), g.settings.chat_xy.y or chat:GetY())
        Mini_addons_chat_frame_vlog("off")
        -- 素の CHAT_SET_TO_TITLENAME は宛先が決まってから走るので、こちらが組み終えた
        -- 直後の姿だけでは足りない。後から素に上書きされていないかを遅れて見る
        ReserveScript("Mini_addons_chat_frame_vlog('off_delay')", 3.0)
        return
    end
    Mini_addons_chat_resize_width(chat, 585)
    edit_bg:Resize(567, 36)
    mainchat:Resize(585, mainchat:GetOriginalHeight())
    mainchat:SetGravity(ui.LEFT, ui.TOP)
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
    chat:SetPos(g.settings.chat_xy.x or chat:GetX(), g.settings.chat_xy.y or chat:GetY())
    chat:Invalidate()
    Mini_addons_chat_frame_vlog("on")
    ReserveScript("Mini_addons_chat_frame_vlog('on_delay')", 3.0)
end

