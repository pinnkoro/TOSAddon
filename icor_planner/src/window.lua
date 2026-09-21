-- Icor Planner: 診断ウィンドウ
--
-- タブは 3 枚(診断 / 目標 / 候補)。中身の作り直しは build 系が受け持ち、
-- 窓そのものを開くのは Icor_planner_open だけにしてある。
-- **ESC の登録は Icor_planner_open にしか置かない。** タブを切り替えるたびに積み直すと、
-- 繰り返し呼ばれる関数から積むことになり、重なり順が意図せず入れ替わる(CLAUDE.md)。
g.icor_planner_frame_name = "icor_planner"

-- 診断タブの列の左端(list の左端からの相対)。**見出しと行が同じ表を見る**ことで揃う
g.icor_planner_cols = {0, 330, 510, 690, 870}

-- 目標タブ右側の列の左端(項目 / 現在値 / 目標値の入力欄 / 目標値の ％)。
-- **見出しと行が同じ表を見る**こと。別々に書くと必ずずれる
-- 項目 / 数え方 / 対象部位 / 現在 / 入力欄 / 目標値の％
-- 項目 / (行を足す) / 数え方 / 部位 / 現在 / 入力欄 / 目標値の％
--
-- **右端の ％ が切れないよう、列は左へ詰めてある。** 右の一覧の幅は
-- 窓の幅(1280) - 450 = 790 しかないので、目安ボタンの右に ％ の 80px を残すこと
-- (実機で 100.0% が切れていた)。
g.icor_planner_target_cols = {8, 210, 282, 344, 460, 702}
-- 「行を足す」ボタンの左端。項目名の右、数え方の左
g.icor_planner_target_add_x = 178

-- 目標値の目安ボタン(最低 / 最大 / 限凸)の左端
g.icor_planner_target_btns = {556, 604, 652}
g.icor_planner_tab = g.icor_planner_tab or 0

function Icor_planner_open()
    local frame_name = addon_name_lower .. g.icor_planner_frame_name
    local frame = ui.GetFrame(frame_name)
    if frame and frame:IsVisible() == 1 then
        Icor_planner_close()
        return
    end
    if not g.icor_planner_settings then
        Icor_planner_load_settings()
    end
    -- **開くたびに範囲の溜め込みを捨てる。** 1 枚に載る値は「手持ちで一番良いイコル」から
    -- 引いているので、新しいイコルを買った / 装備を替えた後も古い値のままになってしまう
    g.icor_planner_best_icor = nil
    g.icor_planner_top_range_cache = nil
    g.icor_planner_detected_lv = nil
    frame = g.create_persistent_frame(frame_name)
    AUTO_CAST(frame)
    g.block_click_through(frame)
    local width, height = 1280, 800
    local x, y = g.settings_frame_pos(width, height)
    frame:SetPos(x, y)
    frame:Resize(width, height)
    frame:SetLayerLevel(99)
    frame:SetTitleBarSkin("None")
    -- **窓を掴んで動かせるようにする。** 以前は窓全体を groupbox(big_bg)で覆っていて、
    -- どこを掴んでもその groupbox がマウスを受けてしまい動かなかった(実機で指摘された)。
    -- 下地の skin はフレーム自身に付け、タイトルの帯は当たり判定を持たせない。
    -- こうすると、タイトルの帯と窓の縁を掴んだときにフレームへ届いて動く
    -- (Market Favorite Rebuild と同じ作り。EnableHittestFrame は block_click_through が入れている)
    frame:SetSkinName("test_frame_low")
    frame:EnableMove(1)
    frame:RemoveAllChild()
    local title_bg = frame:CreateOrGetControl("groupbox", "title_bg", width, 64, ui.LEFT, ui.TOP, 0, 0, 0, 0)
    AUTO_CAST(title_bg)
    title_bg:SetSkinName("test_frame_top")
    -- **子を置かないこと。** 当たり判定を切った groupbox の子がマウスを受けられるかは
    -- 確かめていないので、閉じるボタンやタイトルはフレーム直下に置く
    title_bg:EnableHitTest(0)
    local title = frame:CreateOrGetControl("richtext", "title", 200, 30, ui.CENTER_HORZ, ui.TOP, 0, 18, 0, 0)
    title:SetText("{@st43}{s22}Icor Planner{/}")
    title:EnableHitTest(false)
    local close = frame:CreateOrGetControl("button", "close", 44, 44, ui.RIGHT, ui.TOP, 0, 20, 27, 0)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetClickSound("button_click_big")
    close:SetOverSound("button_over")
    close:SetAnimation("MouseOnAnim", "btn_mouseover")
    close:SetAnimation("MouseOffAnim", "btn_mouseoff")
    -- **閉じるのは離したとき。** 素の閉じるボタンは LBtnUpScp="CLOSE_UI" で、
    -- リポジトリの他の窓もすべて ui.LBUTTONUP。押した瞬間に消えると、
    -- 掴み直しや押し間違いの取り消しが利かない
    close:SetEventScript(ui.LBUTTONUP, "Icor_planner_close")
    local tab = frame:CreateOrGetControl("tab", "tab", width - 40, 40, ui.LEFT, ui.TOP, 20, 66, 0, 0)
    AUTO_CAST(tab)
    tab:SetSkinName("tab2")
    tab:SetEventScript(ui.LBUTTONUP, "Icor_planner_tab_change")
    tab:AddItem(g.lang == "Japanese" and "{@st66b}診断" or "{@st66b}Diagnosis", true, "", "", "", "", "", false)
    tab:AddItem(g.lang == "Japanese" and "{@st66b}目標" or "{@st66b}Target", true, "", "", "", "", "", false)
    tab:AddItem(g.lang == "Japanese" and "{@st66b}候補" or "{@st66b}Candidates", true, "", "", "", "", "", false)
    tab:AddItem(g.lang == "Japanese" and "{@st66b}試算" or "{@st66b}Trial", true, "", "", "", "", "", false)
    tab:SetItemsFixWidth(150)
    tab:SetItemsAdjustFontSizeByWidth(150)
    tab:SelectTab(g.icor_planner_tab)
    local bg = frame:CreateOrGetControl("groupbox", "bg", width - 40, height - 170, ui.LEFT, ui.TOP, 20, 110, 0, 0)
    AUTO_CAST(bg)
    bg:SetSkinName("test_frame_midle")
    -- **タブの外(フレーム直下)へ置くこと。** タブの中身は Icor_planner_build_tab が
    -- 毎回 RemoveAllChild するので、中に置くとタブを切り替えるたびに作り直しになり、
    -- どのタブから見ても同じ設定という形にならない
    local auto_check = frame:CreateOrGetControl("checkbox", "market_auto", 26, 26, ui.LEFT, ui.TOP, 24,
        height - 52, 0, 0)
    AUTO_CAST(auto_check)
    auto_check:SetCheck(g.icor_planner_settings.market_auto or 0)
    auto_check:SetEventScript(ui.LBUTTONUP, "Icor_planner_toggle_market_auto")
    auto_check:SetTextTooltip(g.lang == "Japanese" and
                                  "{ol}OFF にしても、マーケットの「お気に入り」の隣のボタンからいつでも出せます" or
                                  "{ol}You can still open it from the button next to Favorites in the market")
    auto_check:ShowWindow(1)
    local auto_label = frame:CreateOrGetControl("richtext", "market_auto_text", 56, height - 48, 0, 0)
    AUTO_CAST(auto_label)
    auto_label:SetText(g.lang == "Japanese" and
                           "{ol}{s16}マーケットを開いたら評価パネルも一緒に開く" or
                           "{ol}{s16}Open the evaluation panel together with the market")
    auto_label:EnableHitTest(false)
    frame:ShowWindow(1)
    Icor_planner_build_tab()
    -- **判断の材料になった値を残す。** 「個数が合わない」の相談を受けたとき、
    -- 目標が何件立っていて、装備を何部位読めていて、何枠に割り当てた結果なのかが
    -- verbose_log.txt から分かる。窓を開いたときだけなのでログは流れない
    local diag, scan = Icor_planner_diagnose()
    local equipped = 0
    for _, entry in ipairs(scan.slots) do
        if entry.equipped then
            equipped = equipped + 1
        end
    end
    local preset = Icor_planner_cur_preset()
    g.vlog("icor_planner: 目標[%s](%d 件中 %d 件が有効) 装備 %d/%d 部位 -> イコル %d 個 / %d 枠",
        (preset and preset.name) or "-", #((preset and preset.targets) or {}), #diag.rows, equipped,
        #scan.slots, diag.total_icors, diag.total_slots)
    -- **ShowWindow(1) の後で積むこと。** まだ出ていない状態で積むと、直後の同期で
    -- 「閉じ終わった登録」と見なされてその場で捨てられる
    g.esc_register(frame_name, "Icor_planner_close")
end

-- × ボタンと ESC の両方がここを通る。**片方だけ後始末が抜けると
-- 「× なら直るのに ESC だと壊れる」という追いにくい差になる**(CLAUDE.md)。
function Icor_planner_close()
    ui.DestroyFrame(addon_name_lower .. g.icor_planner_frame_name)
end

-- チェックボックスは窓を開いている間ずっと出ているので、切り替えたらその場で保存する。
-- マーケットのパネルは 0.5 秒ごとの見回りが拾うので、ここでは何もしない。
function Icor_planner_toggle_market_auto(parent, ctrl)
    AUTO_CAST(ctrl)
    g.icor_planner_settings.market_auto = (ctrl:IsChecked() == 1) and 1 or 0
    -- ON に戻したときは「× で閉じた」印も捨てる。そうしないと、この窓で ON にしたのに
    -- 今開いているマーケットでは出ない、という分かりにくい状態が残る
    if g.icor_planner_settings.market_auto == 1 then
        g.icor_planner_market_hidden = nil
    end
    Icor_planner_save_settings()
end

function Icor_planner_tab_change(parent, ctrl)
    AUTO_CAST(ctrl)
    g.icor_planner_tab = ctrl:GetSelectItemIndex()
    Icor_planner_build_tab()
end

function Icor_planner_body()
    local frame = ui.GetFrame(addon_name_lower .. g.icor_planner_frame_name)
    if not frame then
        return nil
    end
    local bg = GET_CHILD_RECURSIVELY(frame, "bg")
    if bg then
        AUTO_CAST(bg)
    end
    return bg
end

function Icor_planner_build_tab()
    local bg = Icor_planner_body()
    if not bg then
        return
    end
    -- **同じタブを作り直すときはスクロール位置を残す。** 目標の候補を押すたびにタブごと
    -- 作り直すので、控えないと一覧が先頭へ戻ってしまう(実機で指摘された)。
    -- タブを切り替えたときは先頭から見せる
    local scroll = {}
    if g.icor_planner_built_tab == g.icor_planner_tab then
        for _, name in ipairs(g.icor_planner_scroll_boxes) do
            local box = GET_CHILD(bg, name)
            if box ~= nil then
                AUTO_CAST(box)
                local ok, pos = pcall(function()
                    return box:GetScrollCurPos()
                end)
                scroll[name] = ok and tonumber(pos) or nil
            end
        end
    end
    bg:RemoveAllChild()
    -- 計算しないイコル / 差し替えを変えた後に古い値を使わないよう、作り直すたびに捨てる
    Icor_planner_reset_delta()
    Icor_planner_reset_scan()
    if g.icor_planner_tab == 0 then
        Icor_planner_build_diagnosis(bg)
    elseif g.icor_planner_tab == 1 then
        Icor_planner_build_target(bg)
    elseif g.icor_planner_tab == 3 then
        Icor_planner_build_trial(bg)
    else
        Icor_planner_build_candidates(bg)
    end
    g.icor_planner_built_tab = g.icor_planner_tab
    for name, pos in pairs(scroll) do
        local box = GET_CHILD(bg, name)
        if box ~= nil and pos > 0 then
            AUTO_CAST(box)
            -- **先に InvalidateScrollBar を呼ぶこと。** 逆だと作り直す前(中身が空)の範囲で
            -- 丸められて先頭に貼り付く(indun_panel の設定画面と同じ理由)
            pcall(function()
                box:InvalidateScrollBar()
                box:SetScrollPos(pos)
            end)
        end
    end
end

-- 作り直しでスクロール位置を残す一覧(タブの bg 直下の groupbox の名前)。
-- 目標タブの候補 / 目標、診断タブと候補タブの一覧
g.icor_planner_scroll_boxes = {"cand", "targets", "list", "trial_cand", "trial_result"}

-- ===== 試算タブ =====
--
-- 「この部位のイコルを、インベントリ / マーケットのこのイコルに替えたら」を見る。
-- 差し替えは重ねられる(上半身と手袋を両方替えたら、まで見られる)。保存はしない。
g.icor_planner_trial_slot = g.icor_planner_trial_slot or nil

function Icor_planner_build_trial(bg)
    local jp = g.lang == "Japanese"
    Icor_planner_preset_droplist(bg, 10)
    local reset = bg:CreateOrGetControl("button", "trial_reset", 140, 30, ui.LEFT, ui.TOP, 280, 10, 0, 0)
    AUTO_CAST(reset)
    reset:SetSkinName("test_pvp_btn")
    reset:SetText(jp and "{ol}{s15}差し替えを全部戻す" or "{ol}{s15}Reset all")
    reset:SetEventScript(ui.LBUTTONUP, "Icor_planner_trial_reset")
    local scan = Icor_planner_scan()
    local swaps = Icor_planner_trial_swaps()
    -- 2 段目: 差し替える部位
    local label = bg:CreateOrGetControl("richtext", "trial_slot_label", 10, 52, 0, 0)
    AUTO_CAST(label)
    label:SetText(jp and "{ol}{s15}{#AAAAAA}差し替える部位" or "{ol}{s15}{#AAAAAA}Slot")
    for i, entry in ipairs(scan.slots) do
        local btn = bg:CreateOrGetControl("button", "trial_slot_" .. entry.slot_name, 100, 30, ui.LEFT, ui.TOP,
            150 + (i - 1) * 106, 46, 0, 0)
        AUTO_CAST(btn)
        local name = ClMsg(entry.clmsg)
        if jp and g.icor_planner_exclude_labels[entry.slot_name] then
            name = g.icor_planner_exclude_labels[entry.slot_name]
        end
        local selected = g.icor_planner_trial_slot == entry.slot_name
        btn:SetSkinName(selected and "baseyellow_btn" or "test_pvp_btn")
        local color = "{#FFFFFF}"
        if not entry.equipped then
            color = "{#666666}"
        elseif swaps[entry.slot_name] then
            color = "{#00FFFF}"
        end
        btn:SetText("{ol}{s14}" .. color .. name)
        btn:SetTextTooltip(jp and "{ol}押すと、左にこの部位へ付けられるイコルが並びます{nl}{#00FFFF}水色{/} = 差し替え中" or
                               "{ol}Pick the slot to swap")
        if entry.equipped then
            btn:SetEventScript(ui.LBUTTONUP, "Icor_planner_trial_select_slot")
            btn:SetEventScriptArgString(ui.LBUTTONUP, entry.slot_name)
        end
    end
    local left = bg:CreateOrGetControl("groupbox", "trial_cand", 560, bg:GetHeight() - 94, ui.LEFT, ui.TOP, 10, 84,
        0, 0)
    AUTO_CAST(left)
    left:SetSkinName("bg")
    left:EnableScrollBar(1)
    local right = bg:CreateOrGetControl("groupbox", "trial_result", bg:GetWidth() - 590, bg:GetHeight() - 94, ui.LEFT,
        ui.TOP, 580, 84, 0, 0)
    AUTO_CAST(right)
    right:SetSkinName("bg")
    right:EnableScrollBar(1)
    Icor_planner_fill_trial_candidates(left, scan)
    Icor_planner_fill_trial_result(right, scan)
end

-- オプションを 1 つずつの塊にする(値の段階で色を付ける)。Icor_planner_flow で折り返して並べる用。
-- 名前は略語(Icor_planner_option_short)。1 行に収まらないときだけ折り返す
function Icor_planner_options_parts(options)
    local parts = {}
    for _, op in ipairs(options or {}) do
        local color = g.icor_planner_group_color[Icor_planner_group_of(op.opt)] or "{#FFFFFF}"
        parts[#parts + 1] = string.format("%s%s %s%s", color, Icor_planner_option_short(op.opt),
            Icor_planner_state_color(op.state), GET_COMMAED_STRING(op.value))
    end
    if #parts == 0 then
        parts[1] = g.lang == "Japanese" and "{#888888}イコル無し" or "{#888888}no icor"
    end
    return parts
end

-- 略語で並べたオプションの正式名。ボタンのツールチップに出す(略語だけでは分からないとき用)
function Icor_planner_options_tooltip(options)
    local lines = {}
    for _, op in ipairs(options or {}) do
        lines[#lines + 1] = string.format("%s %s", Icor_planner_option_name(op.opt), GET_COMMAED_STRING(op.value))
    end
    return "{ol}" .. table.concat(lines, "{nl}")
end

function Icor_planner_fill_trial_candidates(left, scan)
    left:RemoveAllChild()
    local jp = g.lang == "Japanese"
    -- 「自分で組む」を押している間は、左を組む画面にする
    if g.icor_planner_trial_custom ~= nil then
        for _, e in ipairs(scan.slots) do
            if e.slot_name == g.icor_planner_trial_custom and e.equipped then
                Icor_planner_draw_trial_custom(left, e)
                return
            end
        end
        g.icor_planner_trial_custom = nil
    end
    -- 右の「リロール」を押している間は、左をリロールの画面にする(右は結果だけにしておく)
    if g.icor_planner_trial_edit ~= nil and Icor_planner_trial_swaps()[g.icor_planner_trial_edit] ~= nil then
        Icor_planner_draw_trial_reroll(left, g.icor_planner_trial_edit)
        return
    end
    g.icor_planner_trial_edit = nil
    local entry = nil
    for _, e in ipairs(scan.slots) do
        if e.slot_name == g.icor_planner_trial_slot and e.equipped then
            entry = e
        end
    end
    if entry == nil then
        local msg = left:CreateOrGetControl("richtext", "msg", 10, 10, 0, 0)
        AUTO_CAST(msg)
        msg:SetText(jp and "{ol}{s15}{#AAAAAA}上の「差し替える部位」を押してください" or
                        "{ol}{s15}{#AAAAAA}Pick a slot above")
        return
    end
    local y = 8
    -- **見出しと中身を分け、中身は縮めずに折り返す。** 1 行に収めようと AdjustFontSizeByWidth で縮めると、
    -- 右に「自分で組む」を置いた分だけ幅が減り、読めない大きさになった(実機で指摘された)
    local cur = left:CreateOrGetControl("richtext", "cur", 10, y + 4, 0, 0)
    AUTO_CAST(cur)
    cur:SetText(jp and "{ol}{s15}{#FFD700}今のイコル" or "{ol}{s15}{#FFD700}Equipped")
    local custom_btn = left:CreateOrGetControl("button", "custom_open", 100, 28, ui.LEFT, ui.TOP,
        left:GetWidth() - 124, y - 2, 0, 0)
    AUTO_CAST(custom_btn)
    custom_btn:SetSkinName("test_pvp_btn")
    custom_btn:SetText(jp and "{ol}{s14}自分で組む" or "{ol}{s14}Custom")
    custom_btn:SetTextTooltip(jp and
                                  "{ol}載せたいオプションを自分で選んだイコルで試します{nl}値は一番上の段の範囲から決めます。組んだイコルはマーケットで探せます" or
                                  "{ol}Try an icor with the options you pick")
    custom_btn:SetEventScript(ui.LBUTTONUP, "Icor_planner_trial_open_custom")
    custom_btn:SetEventScriptArgString(ui.LBUTTONUP, entry.slot_name)
    y = y + 32
    y = Icor_planner_flow(left, "cur_ops", 24, y, left:GetWidth() - 50, nil, Icor_planner_options_parts(entry.options),
        "{ol}{s14}", 22) + 6
    local rows = Icor_planner_trial_candidates(entry.spot)
    -- ボタンの引数は添字なので、押したときに同じ並びを引けるよう控える
    g.icor_planner_trial_list = rows
    local sections = {{
        source = "inv",
        title = jp and "インベントリ" or "Inventory"
    }, {
        source = "market",
        title = jp and "マーケット(今の検索結果)" or "Market (current results)"
    }}
    for _, sec in ipairs(sections) do
        local head = left:CreateOrGetControl("richtext", "sec_" .. sec.source, 10, y, 0, 0)
        AUTO_CAST(head)
        head:SetText("{ol}{s15}{#FFD700}" .. sec.title)
        y = y + 24
        local shown = 0
        for i, row in ipairs(rows) do
            if row.source == sec.source then
                shown = shown + 1
                local name = left:CreateOrGetControl("richtext", "cn_" .. i, 14, y, 0, 0)
                AUTO_CAST(name)
                local price = ""
                if row.price then
                    price = "{#AAAAAA}  " .. GET_COMMAED_STRING(row.price) .. "s"
                end
                name:SetText(string.format("{ol}{s14}{#FFFFFF}[Lv%d] %s%s", row.lv, row.name, price))
                name:AdjustFontSizeByWidth(left:GetWidth() - 110)
                -- オプションは縮めずに折り返す(「今のイコル」と同じ。縮めると読めない大きさになった)
                local next_y = Icor_planner_flow(left, "co_" .. i, 24, y + 22, left:GetWidth() - 130, nil,
                    Icor_planner_options_parts(row.options), "{ol}{s14}", 22)
                local btn = left:CreateOrGetControl("button", "cb_" .. i, 64, 30, ui.LEFT, ui.TOP,
                    left:GetWidth() - 88, y + 4, 0, 0)
                AUTO_CAST(btn)
                btn:SetSkinName("test_pvp_btn")
                btn:SetText(jp and "{ol}{s14}試す" or "{ol}{s14}Try")
                btn:SetTextTooltip(Icor_planner_options_tooltip(row.options))
                btn:SetEventScript(ui.LBUTTONUP, "Icor_planner_trial_apply")
                btn:SetEventScriptArgNumber(ui.LBUTTONUP, i)
                y = math.max(next_y, y + 46) + 4
            end
        end
        if shown == 0 then
            local none = left:CreateOrGetControl("richtext", "none_" .. sec.source, 24, y, 0, 0)
            AUTO_CAST(none)
            local text = jp and "この部位に付けられるイコルがありません" or "None"
            if sec.source == "market" then
                local market = ui.GetFrame("market")
                if market == nil or market:IsVisible() ~= 1 then
                    text = jp and "マーケットを開くと、今の検索結果から選べます" or "Open the market to use its listings"
                end
            end
            none:SetText("{ol}{s14}{#888888}" .. text)
            y = y + 24
        end
        y = y + 8
    end
end

function Icor_planner_trial_select_slot(parent, ctrl, slot_name)
    g.icor_planner_trial_slot = slot_name
    g.icor_planner_trial_edit = nil
    g.icor_planner_trial_custom = nil
    g.icor_planner_custom_pending = nil
    Icor_planner_build_tab()
end

function Icor_planner_trial_apply(parent, ctrl, arg_str, index)
    local row = g.icor_planner_trial_list and g.icor_planner_trial_list[index]
    local slot = g.icor_planner_trial_slot
    if row == nil or slot == nil then
        return
    end
    -- **一覧の行をそのまま入れない。** リロールで options を書き換えるので、写しを持つ
    local swap = {}
    for k, v in pairs(row) do
        swap[k] = v
    end
    swap.base_options = row.options
    swap.reroll = nil
    Icor_planner_trial_swaps()[slot] = swap
    g.vlog("icor_planner: 試算 %s <- [Lv%d] %s (%s)", tostring(slot), row.lv, tostring(row.name), row.source)
    Icor_planner_build_tab()
end

function Icor_planner_trial_remove(parent, ctrl, slot_name)
    Icor_planner_trial_swaps()[slot_name] = nil
    if g.icor_planner_trial_edit == slot_name then
        g.icor_planner_trial_edit = nil
    end
    if g.icor_planner_trial_custom == slot_name then
        g.icor_planner_trial_custom = nil
        g.icor_planner_custom_pending = nil
    end
    Icor_planner_build_tab()
    Icor_planner_refresh_market_customs()
end

-- 左のリロールの画面。右の差し替えの行の「リロール」から入る。
--
-- 枠ごとのドロップリストで変える先を選び、**「決定」を押したときだけ再計算する**
-- (選ぶたびに作り直すと、試している途中で右の結果が動いて見比べにくい)。
-- 選んでいる途中の内容は g.icor_planner_trial_pending に持つ。
g.icor_planner_assume_labels = {
    avg = "平均",
    min = "最低",
    max = "最大",
    limit = "限凸"
}

function Icor_planner_draw_trial_reroll(left, slot_name)
    local jp = g.lang == "Japanese"
    local base = Icor_planner_trial_base(slot_name)
    local swap = base.swap
    local pending = g.icor_planner_trial_pending
    if pending == nil or pending.slot ~= slot_name then
        -- 開いた直後は、今の差し替えに入っているリロールから始める
        pending = {
            slot = slot_name,
            index = swap.reroll and swap.reroll.index or nil,
            opt = swap.reroll and swap.reroll.to or nil,
            assume = (swap.reroll and swap.reroll.assume) or "avg"
        }
        g.icor_planner_trial_pending = pending
    end
    local y = 8
    local title = left:CreateOrGetControl("richtext", "rr_title", 10, y, 0, 0)
    AUTO_CAST(title)
    local label = (jp and g.icor_planner_exclude_labels[slot_name]) or slot_name
    title:SetText(string.format(jp and "{ol}{s16}{#FFD700}リロール{#FFFFFF}  %s ← [Lv%d] %s" or
                                    "{ol}{s16}{#FFD700}Reroll{#FFFFFF}  %s <- [Lv%d] %s", label, base.lv or 0,
        tostring(base.name)))
    title:AdjustFontSizeByWidth(left:GetWidth() - 30)
    y = y + 28
    local note = left:CreateOrGetControl("richtext", "rr_note", 10, y, 0, 0)
    AUTO_CAST(note)
    note:SetText(jp and
                     "{ol}{s13}{#AAAAAA}オプションリロールは 1 枠だけを振り直します(その部位に載るオプションから)。別の枠を選ぶと前の枠は「変えない」に戻ります" or
                     "{ol}{s13}{#AAAAAA}A reroll changes one slot")
    note:AdjustFontSizeByWidth(left:GetWidth() - 30)
    y = y + 26
    local assume_label = left:CreateOrGetControl("richtext", "rr_assume_label", 10, y + 4, 0, 0)
    AUTO_CAST(assume_label)
    assume_label:SetText(jp and "{ol}{s14}{#AAAAAA}変えた後の値" or "{ol}{s14}{#AAAAAA}Value")
    for i, key in ipairs({"min", "avg", "max"}) do
        local btn = left:CreateOrGetControl("button", "rr_assume_" .. key, 60, 26, ui.LEFT, ui.TOP, 120 + (i - 1) * 64,
            y, 0, 0)
        AUTO_CAST(btn)
        btn:SetSkinName(pending.assume == key and "baseyellow_btn" or "test_pvp_btn")
        btn:SetText("{ol}{s14}" .. (jp and g.icor_planner_assume_labels[key] or key))
        btn:SetEventScript(ui.LBUTTONUP, "Icor_planner_trial_pending_assume")
        btn:SetEventScriptArgString(ui.LBUTTONUP, key)
    end
    y = y + 36
    for i, op in ipairs(base.options) do
        local color = g.icor_planner_group_color[Icor_planner_group_of(op.opt)] or "{#FFFFFF}"
        local from = left:CreateOrGetControl("richtext", "rr_from_" .. i, 20, y + 5, 0, 0)
        AUTO_CAST(from)
        from:SetText(string.format("{ol}{s14}{#AAAAAA}枠%d  %s%s %s%s", i, color, Icor_planner_option_name(op.opt),
            Icor_planner_state_color(op.state), GET_COMMAED_STRING(op.value)))
        from:AdjustFontSizeByWidth(250)
        local drop = left:CreateOrGetControl("droplist", "rr_drop_" .. i, 250, 26, ui.LEFT, ui.TOP, 290, y, 0, 0)
        AUTO_CAST(drop)
        drop:SetSkinName("droplist_normal")
        drop:EnableHitTest(1)
        drop:ClearItems()
        drop:AddItem(op.opt, jp and "{ol}{#AAAAAA}変えない" or "{ol}{#AAAAAA}Keep")
        for _, opt in ipairs(Icor_planner_trial_reroll_options(base, i)) do
            if opt ~= op.opt then
                local c = g.icor_planner_group_color[Icor_planner_group_of(opt)] or "{#FFFFFF}"
                drop:AddItem(opt, "{ol}" .. c .. Icor_planner_option_name(opt))
            end
        end
        drop:SelectItemByKey((pending.index == i and pending.opt) or op.opt)
        drop:SetUserValue("INDEX", i)
        drop:SetSelectedScp("Icor_planner_trial_pending_select")
        y = y + 32
    end
    y = y + 10
    local ok_btn = left:CreateOrGetControl("button", "rr_ok", 120, 32, ui.LEFT, ui.TOP, 120, y, 0, 0)
    AUTO_CAST(ok_btn)
    ok_btn:SetSkinName("test_pvp_btn")
    ok_btn:SetText(jp and "{ol}{s15}決定" or "{ol}{s15}Apply")
    ok_btn:SetTextTooltip(jp and "{ol}選んだリロールで右の結果を計算し直します" or "{ol}Recalculate with this reroll")
    ok_btn:SetEventScript(ui.LBUTTONUP, "Icor_planner_trial_pending_apply")
    local cancel = left:CreateOrGetControl("button", "rr_cancel", 120, 32, ui.LEFT, ui.TOP, 250, y, 0, 0)
    AUTO_CAST(cancel)
    cancel:SetSkinName("test_pvp_btn")
    cancel:SetText(jp and "{ol}{s15}キャンセル" or "{ol}{s15}Cancel")
    cancel:SetTextTooltip(jp and "{ol}変えずに候補の一覧へ戻ります" or "{ol}Back without changes")
    cancel:SetEventScript(ui.LBUTTONUP, "Icor_planner_trial_pending_cancel")
end

-- 右の差し替えの行の「リロール」。左をリロールの画面にする
function Icor_planner_trial_open_reroll(parent, ctrl, slot_name)
    g.icor_planner_trial_edit = slot_name
    g.icor_planner_trial_pending = nil
    -- **組む画面の印も消す。** 左は組む画面を先に見るので、残っているとリロールの画面へ切り替わらない
    g.icor_planner_trial_custom = nil
    g.icor_planner_custom_pending = nil
    Icor_planner_build_tab()
end

-- 枠を選んだ。**作り直さない**(決定まで再計算しない)。1 枠だけなので、他の枠は「変えない」へ戻す
function Icor_planner_trial_pending_select(parent, ctrl)
    AUTO_CAST(ctrl)
    local pending = g.icor_planner_trial_pending
    if pending == nil then
        return
    end
    local index = tonumber(ctrl:GetUserValue("INDEX")) or 0
    local base = Icor_planner_trial_base(pending.slot)
    if base == nil then
        return
    end
    local key = ctrl:GetSelItemKey()
    local from = base.options[index]
    if from ~= nil and key ~= from.opt then
        pending.index = index
        pending.opt = key
    elseif pending.index == index then
        pending.index = nil
        pending.opt = nil
    end
    local left = ctrl:GetParent()
    for i, op in ipairs(base.options) do
        if i ~= index then
            local other = GET_CHILD(left, "rr_drop_" .. i)
            if other ~= nil then
                AUTO_CAST(other)
                other:SelectItemByKey(op.opt)
            end
        end
    end
end

-- 値の見込みを切り替えた。ボタンの見た目だけ替える(決定まで再計算しない)
function Icor_planner_trial_pending_assume(parent, ctrl, key)
    local pending = g.icor_planner_trial_pending
    if pending == nil then
        return
    end
    pending.assume = key
    local left = ctrl:GetParent()
    for _, k in ipairs({"min", "avg", "max"}) do
        local btn = GET_CHILD(left, "rr_assume_" .. k)
        if btn ~= nil then
            AUTO_CAST(btn)
            btn:SetSkinName(k == key and "baseyellow_btn" or "test_pvp_btn")
        end
    end
end

function Icor_planner_trial_pending_apply()
    local pending = g.icor_planner_trial_pending
    if pending ~= nil then
        Icor_planner_trial_set_reroll(pending.slot, pending.index, pending.opt, pending.assume)
    end
    g.icor_planner_trial_pending = nil
    g.icor_planner_trial_edit = nil
    Icor_planner_build_tab()
end

function Icor_planner_trial_pending_cancel()
    g.icor_planner_trial_pending = nil
    g.icor_planner_trial_edit = nil
    Icor_planner_build_tab()
end

function Icor_planner_trial_reset()
    g.icor_planner_trial = {
        swaps = {}
    }
    g.icor_planner_trial_edit = nil
    g.icor_planner_trial_pending = nil
    g.icor_planner_trial_custom = nil
    g.icor_planner_custom_pending = nil
    Icor_planner_build_tab()
    Icor_planner_refresh_market_customs()
end

-- ===== 試算: 理想のイコルを自分で組む画面(左) =====
--
-- 4 枠それぞれで「オプション」と「値の見込み(最低 / 平均 / 最大 / 限凸)」を選び、
-- 「試す」で差し替える。**値の見込みは枠ごと**(一部の枠だけ限凸、を試すため。実機で要望された)。
-- 上の 4 つのボタンは全部の枠をまとめて切り替える近道。
-- リロールの画面と同じく、**選んでいる途中では再計算しない**。
-- 選んでいる途中の内容は g.icor_planner_custom_pending に持つ。
-- 最初の中身は、組んだイコルで差し替え中ならその中身、そうでなければ今のイコルのオプション
g.icor_planner_custom_assumes = {"min", "avg", "max", "limit"}

function Icor_planner_draw_trial_custom(left, entry)
    local jp = g.lang == "Japanese"
    local slot_name = entry.slot_name
    local pending = g.icor_planner_custom_pending
    if pending == nil or pending.slot ~= slot_name then
        local swap = Icor_planner_trial_swaps()[slot_name]
        local opts, assumes = {}, {}
        if swap ~= nil and swap.source == "custom" then
            for i, opt in ipairs(swap.custom.opts) do
                opts[i] = opt
                assumes[i] = swap.custom.assumes[i]
            end
        else
            for i, op in ipairs(entry.real_options or entry.options) do
                opts[i] = op.opt
            end
        end
        pending = {
            slot = slot_name,
            spot = entry.spot,
            opts = opts,
            assumes = assumes
        }
        g.icor_planner_custom_pending = pending
    end
    local per_icor = 4
    if shared_item_goddess_icor ~= nil then
        local ok, count = pcall(shared_item_goddess_icor.get_max_option_count)
        if ok and type(count) == "number" and count > 0 then
            per_icor = count
        end
    end
    pending.per_icor = per_icor
    local y = 8
    local title = left:CreateOrGetControl("richtext", "cu_title", 10, y, 0, 0)
    AUTO_CAST(title)
    local label = (jp and g.icor_planner_exclude_labels[slot_name]) or ClMsg(entry.clmsg)
    local _, _, top_lv = Icor_planner_top_range("STR", entry.spot)
    title:SetText(string.format(jp and "{ol}{s16}{#FFD700}自分で組む{#FFFFFF}  %s  {#AAAAAA}(%s・Lv%s の範囲)" or
                                    "{ol}{s16}{#FFD700}Custom{#FFFFFF}  %s  {#AAAAAA}(%s / Lv%s)", label,
        Icor_planner_spot_label(entry.spot), tostring(top_lv or "-")))
    title:AdjustFontSizeByWidth(left:GetWidth() - 30)
    y = y + 28
    local note = left:CreateOrGetControl("richtext", "cu_note", 10, y, 0, 0)
    AUTO_CAST(note)
    note:SetText(jp and
                     "{ol}{s13}{#AAAAAA}枠ごとにオプションと値を選んで「試す」を押すと、右で差し替えた結果を計算します{nl}同じオプションは 1 つのイコルに 1 つまでです。限凸 = 最大 × 1.5(切り捨て)" or
                     "{ol}{s13}{#AAAAAA}Pick an option and a value for each slot, then press Try")
    y = y + 44
    local assume_label = left:CreateOrGetControl("richtext", "cu_assume_label", 10, y + 4, 0, 0)
    AUTO_CAST(assume_label)
    assume_label:SetText(jp and "{ol}{s14}{#AAAAAA}値(全部の枠)" or "{ol}{s14}{#AAAAAA}Value (all)")
    for i, key in ipairs(g.icor_planner_custom_assumes) do
        local btn = left:CreateOrGetControl("button", "cu_assume_" .. key, 60, 26, ui.LEFT, ui.TOP, 120 + (i - 1) * 64,
            y, 0, 0)
        AUTO_CAST(btn)
        btn:SetSkinName("test_pvp_btn")
        btn:SetText("{ol}{s14}" .. (jp and g.icor_planner_assume_labels[key] or key))
        btn:SetTextTooltip(jp and "{ol}4 枠の値をまとめてこれにします(試すまで計算しません)" or "{ol}Set all slots")
        btn:SetEventScript(ui.LBUTTONUP, "Icor_planner_custom_pending_assume_all")
        btn:SetEventScriptArgString(ui.LBUTTONUP, key)
    end
    y = y + 36
    local choices = Icor_planner_custom_option_list(entry.spot)
    for i = 1, per_icor do
        local head = left:CreateOrGetControl("richtext", "cu_head_" .. i, 14, y + 5, 0, 0)
        AUTO_CAST(head)
        head:SetText(string.format(jp and "{ol}{s14}{#AAAAAA}枠%d" or "{ol}{s14}{#AAAAAA}Slot %d", i))
        local drop = left:CreateOrGetControl("droplist", "cu_drop_" .. i, 230, 26, ui.LEFT, ui.TOP, 56, y, 0, 0)
        AUTO_CAST(drop)
        drop:SetSkinName("droplist_normal")
        drop:EnableHitTest(1)
        drop:ClearItems()
        drop:AddItem("None", jp and "{ol}{#AAAAAA}(空き)" or "{ol}{#AAAAAA}(empty)")
        for _, opt in ipairs(choices) do
            local c = g.icor_planner_group_color[Icor_planner_group_of(opt)] or "{#FFFFFF}"
            drop:AddItem(opt, "{ol}" .. c .. Icor_planner_option_name(opt))
        end
        drop:SelectItemByKey(pending.opts[i] or "None")
        drop:SetUserValue("INDEX", i)
        drop:SetSelectedScp("Icor_planner_custom_pending_select")
        -- 枠ごとの値の見込み
        local adrop = left:CreateOrGetControl("droplist", "cu_adrop_" .. i, 74, 26, ui.LEFT, ui.TOP, 292, y, 0, 0)
        AUTO_CAST(adrop)
        adrop:SetSkinName("droplist_normal")
        adrop:EnableHitTest(1)
        adrop:ClearItems()
        for _, key in ipairs(g.icor_planner_custom_assumes) do
            adrop:AddItem(key, "{ol}" .. (jp and g.icor_planner_assume_labels[key] or key))
        end
        adrop:SelectItemByKey(pending.assumes[i] or "avg")
        adrop:SetUserValue("INDEX", i)
        adrop:SetSelectedScp("Icor_planner_custom_pending_assume")
        -- 選んだ値と一番上の段の範囲。選び直したらこの行だけ書き換える
        local range = left:CreateOrGetControl("richtext", "cu_range_" .. i, 374, y + 5, 0, 0)
        AUTO_CAST(range)
        range:SetText(Icor_planner_custom_range_text(pending.opts[i], entry.spot, pending.assumes[i]))
        y = y + 32
    end
    y = y + 10
    local buttons = {{
        name = "cu_ok",
        text = jp and "試す" or "Try",
        tip = jp and "{ol}このイコルで差し替えて、右の結果を計算し直します" or "{ol}Swap with this icor",
        scp = "Icor_planner_custom_pending_apply"
    }, {
        name = "cu_rec",
        text = jp and "オススメから" or "Suggested",
        tip = jp and "{ol}診断タブのオススメのイコル構成(この部位の種類の 1 個目の中身)を入れます{nl}値は今の選択のまま。まだ試しません" or
            "{ol}Fill with the suggested set",
        scp = "Icor_planner_custom_pending_suggest"
    }, {
        name = "cu_cancel",
        text = jp and "キャンセル" or "Cancel",
        tip = jp and "{ol}変えずに候補の一覧へ戻ります" or "{ol}Back without changes",
        scp = "Icor_planner_custom_pending_cancel"
    }}
    for i, b in ipairs(buttons) do
        local btn = left:CreateOrGetControl("button", b.name, 120, 32, ui.LEFT, ui.TOP, 20 + (i - 1) * 130, y, 0, 0)
        AUTO_CAST(btn)
        btn:SetSkinName("test_pvp_btn")
        btn:SetText("{ol}{s15}" .. b.text)
        btn:SetTextTooltip(b.tip)
        btn:SetEventScript(ui.LBUTTONUP, b.scp)
    end
end

-- 「6,169 (3,702〜4,113)」。使う値を段階の色で出し、範囲を添える。空き枠は何も出さない
function Icor_planner_custom_range_text(opt, spot, assume)
    if opt == nil or opt == "None" then
        return ""
    end
    local min_value, max_value = Icor_planner_top_range(opt, spot)
    local value = Icor_planner_custom_value(opt, spot, assume)
    return string.format("{ol}{s14}%s%s {#AAAAAA}{s13}(%s〜%s)",
        Icor_planner_state_color(Icor_planner_value_state(value, max_value)), GET_COMMAED_STRING(value),
        GET_COMMAED_STRING(min_value), GET_COMMAED_STRING(max_value))
end

-- 枠 index の値の表示だけを書き換える(作り直さない)
function Icor_planner_custom_refresh_row(left, pending, index)
    local range = GET_CHILD(left, "cu_range_" .. index)
    if range ~= nil then
        AUTO_CAST(range)
        range:SetText(Icor_planner_custom_range_text(pending.opts[index], pending.spot, pending.assumes[index]))
    end
end

function Icor_planner_trial_open_custom(parent, ctrl, slot_name)
    g.icor_planner_trial_slot = slot_name
    g.icor_planner_trial_custom = slot_name
    g.icor_planner_trial_edit = nil
    g.icor_planner_custom_pending = nil
    Icor_planner_build_tab()
end

-- 枠のオプションを選んだ。**作り直さない**(試すまで再計算しない)。値の表示だけ替える
function Icor_planner_custom_pending_select(parent, ctrl)
    AUTO_CAST(ctrl)
    local pending = g.icor_planner_custom_pending
    if pending == nil then
        return
    end
    local index = tonumber(ctrl:GetUserValue("INDEX")) or 0
    if index <= 0 then
        return
    end
    for i = #pending.opts + 1, index - 1 do
        pending.opts[i] = "None"
    end
    pending.opts[index] = ctrl:GetSelItemKey()
    Icor_planner_custom_refresh_row(ctrl:GetParent(), pending, index)
end

-- 枠の値の見込みを選んだ。値の表示だけ替える
function Icor_planner_custom_pending_assume(parent, ctrl)
    AUTO_CAST(ctrl)
    local pending = g.icor_planner_custom_pending
    if pending == nil then
        return
    end
    local index = tonumber(ctrl:GetUserValue("INDEX")) or 0
    if index <= 0 then
        return
    end
    pending.assumes[index] = ctrl:GetSelItemKey()
    Icor_planner_custom_refresh_row(ctrl:GetParent(), pending, index)
end

-- 上のボタン。全部の枠の値の見込みをまとめて切り替え、各枠のドロップリストと表示も揃える
function Icor_planner_custom_pending_assume_all(parent, ctrl, key)
    local pending = g.icor_planner_custom_pending
    if pending == nil then
        return
    end
    local left = ctrl:GetParent()
    for i = 1, pending.per_icor or 4 do
        pending.assumes[i] = key
        local adrop = GET_CHILD(left, "cu_adrop_" .. i)
        if adrop ~= nil then
            AUTO_CAST(adrop)
            adrop:SelectItemByKey(key)
        end
        Icor_planner_custom_refresh_row(left, pending, i)
    end
end

-- 診断タブのオススメのイコル構成から、この部位の種類の 1 個目の中身を入れる。
-- 差し替える前の姿で組む(試算の印は立てない)。更新するイコルを選んでいれば、その部位に載せる中身になる
function Icor_planner_custom_pending_suggest()
    local pending = g.icor_planner_custom_pending
    if pending == nil then
        return
    end
    local diag, scan = Icor_planner_diagnose()
    local plan = Icor_planner_recommend(diag, scan, "avg")
    local tp = plan.types and plan.types[pending.spot]
    local set = tp and tp.sets and tp.sets[1]
    g.vlog("icor_planner: 自分で組む <- オススメ %s (%s)", tostring(pending.spot),
        set and table.concat(set.opts, ",") or "無し")
    if set == nil then
        ui.SysMsg(g.lang == "Japanese" and "{ol}この部位の種類にはオススメの中身がありません" or
                      "{ol}No suggested set for this slot type")
        return
    end
    local opts = {}
    for _, opt in ipairs(set.opts) do
        opts[#opts + 1] = opt
    end
    pending.opts = opts
    Icor_planner_build_tab()
end

function Icor_planner_custom_pending_apply()
    local pending = g.icor_planner_custom_pending
    if pending == nil then
        return
    end
    local count = Icor_planner_trial_set_custom(pending.slot, pending.spot, pending.opts, pending.assumes)
    if count == 0 then
        ui.SysMsg(g.lang == "Japanese" and "{ol}オプションを 1 つ以上選んでください" or "{ol}Pick at least one option")
        return
    end
    g.icor_planner_custom_pending = nil
    g.icor_planner_trial_custom = nil
    Icor_planner_build_tab()
    Icor_planner_refresh_market_customs()
end

-- マーケットのパネルの「試算で組んだイコルで探す」を作り直す。
-- パネルは出品一覧が入れ替わったときにしか組み直さないので、組んだ / 戻した直後はここで呼ぶ
function Icor_planner_refresh_market_customs()
    local panel = ui.GetFrame(addon_name_lower .. g.icor_planner_market_frame)
    if panel ~= nil and panel:IsVisible() == 1 then
        Icor_planner_market_fill()
    end
end

function Icor_planner_custom_pending_cancel()
    g.icor_planner_custom_pending = nil
    g.icor_planner_trial_custom = nil
    Icor_planner_build_tab()
end

-- 組んだイコルをマーケットで探す。下限は試算に使った値(値の見込み)
function Icor_planner_trial_search_custom(parent, ctrl, slot_name)
    local swap = Icor_planner_trial_swaps()[slot_name]
    if swap == nil or swap.source ~= "custom" then
        return
    end
    local conds = {}
    for _, op in ipairs(swap.options) do
        conds[#conds + 1] = {
            opt = op.opt,
            min_value = op.value
        }
    end
    Icor_planner_market_search_conditions(swap.spot, conds)
end

-- 差の文字列。良くなったら緑、悪くなったら赤。better_is_lower は「少ないほど良い」項目(不足・必要数)
function Icor_planner_diff_text(before, after, better_is_lower)
    local d = (after or 0) - (before or 0)
    if d == 0 then
        return "{#AAAAAA}±0"
    end
    local good = (d > 0) ~= (better_is_lower == true)
    return string.format("%s%s%s", good and "{#98FB98}" or "{#FF6347}", d > 0 and "+" or "-",
        GET_COMMAED_STRING(math.abs(math.floor(d))))
end

function Icor_planner_fill_trial_result(right, scan)
    right:RemoveAllChild()
    local jp = g.lang == "Japanese"
    local swaps = Icor_planner_trial_swaps()
    local y = 8
    -- 差し替えの一覧(× でその部位だけ戻す)
    local labels = {}
    for i, entry in ipairs(scan.slots) do
        labels[entry.slot_name] = (jp and g.icor_planner_exclude_labels[entry.slot_name]) or ClMsg(entry.clmsg)
    end
    local any = false
    for _, slot_info in ipairs(g.icor_planner_slots) do
        local swap = swaps[slot_info.slot_name]
        if swap then
            any = true
            local line = right:CreateOrGetControl("richtext", "sw_" .. slot_info.slot_name, 40, y + 4, 0, 0)
            AUTO_CAST(line)
            local source_text = jp and "インベントリ" or "inventory"
            if swap.source == "market" then
                source_text = jp and "マーケット" or "market"
            elseif swap.source == "custom" then
                -- 値の見込みが全部の枠で同じならその名前、違えば「枠ごと」(値は下の行に出ている)
                local same = swap.custom.assumes[1]
                for _, key in ipairs(swap.custom.assumes) do
                    if key ~= same then
                        same = nil
                    end
                end
                local assume_text = jp and "枠ごと" or "per slot"
                if same ~= nil then
                    assume_text = (jp and g.icor_planner_assume_labels[same]) or same
                end
                source_text = string.format(jp and "%s・一番上の段" or "%s / top tier", assume_text)
            end
            local custom = swap.source == "custom"
            -- **1 行ずつ別のコントロールに置く。** {nl} で繋いだ 1 本を AdjustFontSizeByWidth で縮めると、
            -- 一番長い行に合わせて全部の行が読めない大きさになる(実機で指摘された。
            -- マーケットのパネルで直したのと同じ件)
            line:SetText(string.format("{ol}{s15}{#00FFFF}%s{#FFFFFF} ← [Lv%d] %s{#AAAAAA} (%s)",
                labels[slot_info.slot_name] or slot_info.slot_name, swap.lv, swap.name, source_text))
            line:AdjustFontSizeByWidth(right:GetWidth() - (custom and 240 or 150))
            -- オプションは縮めずに折り返す(左の候補と同じ)
            local ops_end = Icor_planner_flow(right, "swo_" .. slot_info.slot_name, 40, y + 26, right:GetWidth() - 70,
                nil, Icor_planner_options_parts(swap.options), "{ol}{s14}", 22)
            local extra = 0
            if swap.reroll then
                local rr_line = right:CreateOrGetControl("richtext", "swrr_" .. slot_info.slot_name, 40, ops_end, 0, 0)
                AUTO_CAST(rr_line)
                rr_line:SetText(string.format(jp and "{ol}{s14}{#FFD700}リロール: 枠%d %s → %s %s{#AAAAAA} (%s)" or
                                                  "{ol}{s14}{#FFD700}Reroll: slot %d %s -> %s %s{#AAAAAA} (%s)",
                    swap.reroll.index, Icor_planner_option_name(swap.reroll.from),
                    Icor_planner_option_name(swap.reroll.to), GET_COMMAED_STRING(swap.reroll.value),
                    g.icor_planner_assume_labels[swap.reroll.assume] or ""))
                rr_line:AdjustFontSizeByWidth(right:GetWidth() - 60)
                extra = 22
            end
            local rr = right:CreateOrGetControl("button", "swr_" .. slot_info.slot_name, 80, 26, ui.LEFT, ui.TOP,
                right:GetWidth() - 104, y + 4, 0, 0)
            AUTO_CAST(rr)
            if custom then
                -- 組んだイコルはリロールではなく、組み直す(左を組む画面にする)
                rr:SetSkinName(g.icor_planner_trial_custom == slot_info.slot_name and "baseyellow_btn" or
                                   "test_pvp_btn")
                rr:SetText(jp and "{ol}{s14}組み直す" or "{ol}{s14}Edit")
                rr:SetTextTooltip(jp and "{ol}左で、このイコルのオプションを選び直します" or "{ol}Edit this icor")
                rr:SetEventScript(ui.LBUTTONUP, "Icor_planner_trial_open_custom")
                rr:SetEventScriptArgString(ui.LBUTTONUP, slot_info.slot_name)
                -- マーケットで同じ条件の品を探す(条件検索へ 4 オプションと下限をまとめて入れる)
                local tips = {}
                for _, op in ipairs(swap.options) do
                    tips[#tips + 1] = string.format("%s >= %s", Icor_planner_option_name(op.opt),
                        GET_COMMAED_STRING(op.value))
                end
                local search = right:CreateOrGetControl("button", "sws_" .. slot_info.slot_name, 80, 26, ui.LEFT,
                    ui.TOP, right:GetWidth() - 190, y + 4, 0, 0)
                AUTO_CAST(search)
                search:SetSkinName("test_pvp_btn")
                search:SetText(jp and "{ol}{s14}探す" or "{ol}{s14}Search")
                search:SetTextTooltip("{ol}" .. (jp and
                                          "マーケットの条件検索にこのイコルを入れて検索します(今の条件は消えます){nl}マーケットを開いてから押してください{nl}" or
                                          "Search the market for this icor{nl}") .. table.concat(tips, "{nl}"))
                search:SetEventScript(ui.LBUTTONUP, "Icor_planner_trial_search_custom")
                search:SetEventScriptArgString(ui.LBUTTONUP, slot_info.slot_name)
            else
                rr:SetSkinName(g.icor_planner_trial_edit == slot_info.slot_name and "baseyellow_btn" or
                                   "test_pvp_btn")
                rr:SetText(jp and "{ol}{s14}リロール" or "{ol}{s14}Reroll")
                rr:SetTextTooltip(jp and "{ol}このイコルの 1 枠をオプションリロールで変えたら、を左で試します" or
                                      "{ol}Try rerolling one slot of this icor")
                rr:SetEventScript(ui.LBUTTONUP, "Icor_planner_trial_open_reroll")
                rr:SetEventScriptArgString(ui.LBUTTONUP, slot_info.slot_name)
            end
            local x = right:CreateOrGetControl("button", "swx_" .. slot_info.slot_name, 26, 24, ui.LEFT, ui.TOP, 8, y + 4,
                0, 0)
            AUTO_CAST(x)
            x:SetSkinName("test_pvp_btn")
            x:SetText("{ol}{s14}{#FF6347}×")
            x:SetTextTooltip(jp and "{ol}この部位の差し替えを戻す" or "{ol}Undo this swap")
            x:SetEventScript(ui.LBUTTONUP, "Icor_planner_trial_remove")
            x:SetEventScriptArgString(ui.LBUTTONUP, slot_info.slot_name)
            y = ops_end + 4 + extra
        end
    end
    if not any then
        local msg = right:CreateOrGetControl("richtext", "msg", 10, y, 0, 0)
        AUTO_CAST(msg)
        msg:SetText(jp and
                        "{ol}{s15}{#AAAAAA}左で部位とイコルを選んで「試す」を押すと、差し替えた結果がここに出ます{nl}差し替えは重ねられます(保存はしません)" or
                        "{ol}{s15}{#AAAAAA}Pick a slot and an icor, then press Try")
        return
    end
    Icor_planner_reset_delta()
    local before, before_scan = Icor_planner_diagnose()
    local after, after_scan = Icor_planner_diagnose_trial()
    if after == nil then
        return
    end
    y = y + 6
    local cols = {10, 250, 400, 560}
    local heads = jp and {"項目", "今", "差し替え後", "差"} or {"Option", "Now", "After", "Diff"}
    for i, text in ipairs(heads) do
        local h = right:CreateOrGetControl("richtext", "rh_" .. i, cols[i], y, 0, 0)
        AUTO_CAST(h)
        h:SetText("{ol}{s15}{#AAAAAA}" .. text)
    end
    y = y + 26
    local function cell(name, x, text)
        local c = right:CreateOrGetControl("richtext", name, x, y, 0, 0)
        AUTO_CAST(c)
        c:SetText("{ol}{s15}" .. text)
        -- 項目名は自分の列の幅まで縮める(長い名前が「今」の列へはみ出していた)
        if x == cols[1] then
            c:AdjustFontSizeByWidth(cols[2] - cols[1] - 10)
        end
    end
    -- 合計の目標: 現在値(と ％)
    for i, row in ipairs(before.rows) do
        local a = after.rows[i]
        if a ~= nil and a.opt == row.opt then
            local color = g.icor_planner_group_color[Icor_planner_group_of(row.opt)] or "{#FFFFFF}"
            cell("r1_" .. i, cols[1], color .. Icor_planner_option_name(row.opt))
            cell("r2_" .. i, cols[2], "{#FFFFFF}" .. Icor_planner_value_text(row.opt, row.cur))
            cell("r3_" .. i, cols[3], "{#FFFFFF}" .. Icor_planner_value_text(row.opt, a.cur))
            cell("r4_" .. i, cols[4], Icor_planner_diff_text(row.cur, a.cur))
            y = y + 24
        end
    end
    -- 各部位の目標: 載っている部位数
    for i, row in ipairs(before.slot_rows) do
        local a = after.slot_rows[i]
        if a ~= nil and a.opt == row.opt then
            local color = g.icor_planner_group_color[Icor_planner_group_of(row.opt)] or "{#FFFFFF}"
            local unit = jp and " 部位" or ""
            cell("s1_" .. i, cols[1], color .. Icor_planner_option_name(row.opt) .. "{#AAAAAA}{s13} (" ..
                Icor_planner_spot_label(row.spot) .. ")")
            cell("s2_" .. i, cols[2], string.format("{#FFFFFF}%d/%d%s", math.min(row.have, row.want), row.want, unit))
            cell("s3_" .. i, cols[3], string.format("{#FFFFFF}%d/%d%s", math.min(a.have, a.want), a.want, unit))
            cell("s4_" .. i, cols[4], Icor_planner_diff_text(math.min(row.have, row.want), math.min(a.have, a.want)))
            y = y + 24
        end
    end
    -- まとめ: 更新が要るオプションの数 / オススメ構成の更新数
    y = y + 10
    local rec_before = Icor_planner_plan(before, before_scan, "avg")
    -- **差し替え後の組み立ては試算の印を立てたまま行う。** 中で今の値(Icor_planner_current)を
    -- 引き直すので、印が無いと差し替える前の値で組んでしまう
    local rec_after = Icor_planner_with_trial(function()
        return Icor_planner_plan(after, after_scan, "avg")
    end) or rec_before
    -- 診断タブの見出しと同じ数(オススメのイコル構成と同じ計算)
    cell("u1", cols[1], jp and "{#FFD700}あとオプション" or "{#FFD700}Options to update")
    cell("u2", cols[2], "{#FFFFFF}" .. tostring(rec_before.updates))
    cell("u3", cols[3], "{#FFFFFF}" .. tostring(rec_after.updates))
    cell("u4", cols[4], Icor_planner_diff_text(rec_before.updates, rec_after.updates, true))
    y = y + 24
    -- 試したイコルに替えた後、残りの部位(更新するイコル)に何を載せればよいか。
    -- 診断タブと同じ描き方を、差し替え後の診断で使う
    Icor_planner_with_trial(function()
        return Icor_planner_draw_recommend(right, y, after, after_scan)
    end)
end

-- 試算の印を立てて fn を呼ぶ。**印は必ず戻す**(失敗しても、以降の計算が差し替え後のままになる)
function Icor_planner_with_trial(fn)
    g.icor_planner_trial_on = true
    Icor_planner_reset_delta()
    local ok, result = pcall(fn)
    g.icor_planner_trial_on = false
    Icor_planner_reset_delta()
    if not ok then
        g.vlog("{#FF6347}icor_planner: 試算の計算に失敗した (%s){/}", tostring(result))
        return nil
    end
    return result
end


-- 診断タブの「オススメのイコル構成」。平均で組んだ形を出し、最低値で組んだときの必要数と
-- 形の違い(個数が変わる項目)を添える。イコル 1 個ずつのセットも並べる。戻り値は次に描き始める y
--
-- 目標タブで「計算しない」にした部位があれば、**その部位を更新するイコルとして**組む
-- (残すイコルは今の値のまま。Icor_planner_recommend を参照)
function Icor_planner_set_text(set)
    local names = {}
    for _, opt in ipairs(set.opts) do
        local c = g.icor_planner_group_color[Icor_planner_group_of(opt)] or "{#FFFFFF}"
        names[#names + 1] = c .. Icor_planner_option_name(opt)
    end
    return table.concat(names, "{#AAAAAA} / ")
end

-- 文字の塊を左から並べ、幅を超えたら次の行へ折り返す。戻り値は次の行の y。
-- **縮めない。** 1 本の長い文字列を AdjustFontSizeByWidth で幅に収めると、項目が多い行だけ
-- 読めない大きさになる(実機で指摘された)。塊ごとに別のコントロールへ置き、
-- 置いた後の幅(GetWidth)を見て次の位置を決める。折り返した行は見出しの右から始める
function Icor_planner_flow(parent, name, x0, y, max_w, head, parts, font, line_h)
    local x = x0
    local indent = x0
    if head ~= nil then
        local h = parent:CreateOrGetControl("richtext", name .. "_head", x0, y, 0, 0)
        AUTO_CAST(h)
        h:SetText(font .. head)
        indent = x0 + h:GetWidth() + 8
        x = indent
    end
    for i, part in ipairs(parts) do
        local text = part
        if i < #parts then
            text = text .. "{#AAAAAA} /"
        end
        local c = parent:CreateOrGetControl("richtext", name .. "_" .. i, x, y, 0, 0)
        AUTO_CAST(c)
        c:SetText(font .. text)
        local w = c:GetWidth()
        if x > indent and x + w > x0 + max_w then
            y = y + line_h
            x = indent
            c:SetOffset(x, y)
        end
        x = x + w + 6
    end
    return y + line_h
end

function Icor_planner_draw_recommend(list, y, diag, scan)
    if #diag.rows == 0 and #diag.slot_rows == 0 then
        return y
    end
    local avg = Icor_planner_recommend(diag, scan, "avg")
    local low = Icor_planner_recommend(diag, scan, "min")
    local jp = g.lang == "Japanese"
    -- 更新するイコルを選んでいないときは、**先に「今の装備から変えるなら」を出す。**
    -- 見出しの「あとオプション」はこちらの数。下の理想の形は、組み直すならの参考
    if not avg.update_mode then
        y = Icor_planner_draw_keep_plan(list, y, diag, scan)
    end
    y = y + 10
    local title = list:CreateOrGetControl("richtext", "rec_title", 10, y, 0, 0)
    AUTO_CAST(title)
    if avg.update_mode then
        local head = jp and "更新するイコルのオススメ" or "Suggested icor for slots to update"
        title:SetText(jp and
                          string.format(
                "{ol}{s16}{#FFD700}%s{#AAAAAA}{s14}  平均値で計算  {#FFFFFF}あとオプション {#FFD700}%d{#FFFFFF} 個{#AAAAAA}  /  最低値なら {#FFFFFF}%d{#AAAAAA} 個",
                head, avg.updates, low.updates) or
                          string.format("{ol}{s16}{#FFD700}%s{#AAAAAA}  (avg) %d / (min) %d", head, avg.updates,
                low.updates))
    else
        -- **「あとオプション」とは呼ばない。** 理想の形との差で、目標までの数ではない
        -- (目標に届いていても、載せ方が違えば数が出る)
        title:SetText(jp and
                          string.format(
                "{ol}{s16}{#FFD700}理想のイコル構成(参考){#AAAAAA}{s14}  平均値で計算  理想の形との差 {#FFFFFF}%d{#AAAAAA} 個  /  最低値なら {#FFFFFF}%d{#AAAAAA} 個",
                avg.updates, low.updates) or
                          string.format("{ol}{s16}{#FFD700}Ideal layout (reference){#AAAAAA}  diff (avg) %d / (min) %d",
                avg.updates, low.updates))
    end
    title:SetTextTooltip(jp and (avg.update_mode and
                             "{ol}目標タブで「更新するイコル」にした部位に、何を載せれば目標に届くかです{nl}残すイコルは今の値のまま計算しています{nl}×N = 更新するイコル N 個に載せる{nl}平均 = 一番上の段の (最小 + 最大) / 2、最低値 = 一番上の段の最小値" or
                             "{ol}全部の部位を一から組み直すなら、の理想の形です(今のイコルに合わせた形ではありません){nl}「理想の形との差」は目標までの数ではありません。目標に届いていても、載せ方が違えば数が出ます{nl}目標タブで「更新するイコル」を選ぶと、その部位だけを組みます{nl}×N = その部位のイコル N 個に載せる / (今 M) = 今その値以上で載っている個数{nl}平均 = 一番上の段の (最小 + 最大) / 2、最低値 = 一番上の段の最小値") or
                             "{ol}Suggested layout")
    y = y + 26
    for _, spot in ipairs({"Weapon", "Armor"}) do
        local tp = avg.types[spot]
        local tp_low = low.types[spot]
        if tp.icors > 0 then
            local parts = {}
            for _, opt in ipairs(tp.order) do
                local c, have = tp.counts[opt], tp.have[opt] or 0
                if avg.update_mode then
                    parts[#parts + 1] = string.format("{#FFA500}%s ×%d", Icor_planner_option_name(opt), c)
                else
                    local color = (have >= c) and "{#98FB98}" or "{#FFA500}"
                    parts[#parts + 1] = string.format("%s%s ×%d{#AAAAAA}{s13}(今 %d){/}{s15}", color,
                        Icor_planner_option_name(opt), c, have)
                end
            end
            if tp.free > 0 then
                parts[#parts + 1] = string.format("{#888888}空き %d", tp.free)
            end
            local label = jp and string.format("%s (%s%d 個%s)", Icor_planner_spot_label(spot),
                avg.update_mode and "更新 " or "", tp.icors,
                tp.places > 1 and string.format("・1 個で %d か所", tp.places) or "") or Icor_planner_spot_label(spot)
            if #parts == 0 then
                parts[1] = "{#888888}-"
            end
            y = Icor_planner_flow(list, "rec_" .. spot, 20, y, list:GetWidth() - 50,
                "{#FFFFFF}" .. label .. " :", parts, "{ol}{s15}", 24)
            -- イコル 1 個ずつのセット(マーケットで探すときの形)
            for k, set in ipairs(tp.sets or {}) do
                local names = {}
                for _, opt in ipairs(set.opts) do
                    names[#names + 1] = (g.icor_planner_group_color[Icor_planner_group_of(opt)] or "{#FFFFFF}") ..
                                            Icor_planner_option_name(opt)
                end
                y = Icor_planner_flow(list, "recset_" .. spot .. "_" .. k, 40, y, list:GetWidth() - 70,
                    string.format("{#AAAAAA}%s ×%d :", jp and "1 個の中身" or "Set", set.count), names, "{ol}{s14}", 22)
            end
            -- 最低値で組むと個数が変わる項目だけを並べる(同じなら出さない)
            local diffs = {}
            local seen = {}
            for _, opt in ipairs(tp_low.order) do
                seen[opt] = true
                if (tp_low.counts[opt] or 0) ~= (tp.counts[opt] or 0) then
                    diffs[#diffs + 1] = string.format("%s ×%d→×%d", Icor_planner_option_name(opt),
                        tp.counts[opt] or 0, tp_low.counts[opt] or 0)
                end
            end
            for _, opt in ipairs(tp.order) do
                if not seen[opt] then
                    diffs[#diffs + 1] = string.format("%s ×%d→×0", Icor_planner_option_name(opt), tp.counts[opt])
                end
            end
            if #diffs > 0 then
                y = Icor_planner_flow(list, "rec90_" .. spot, 40, y, list:GetWidth() - 70, "{#AAAAAA}最低値なら:",
                    diffs, "{ol}{s14}{#AAAAAA}", 22)
            end
        end
    end
    -- 全部の枠を使っても届かない項目
    local function unmet_text(plan)
        local parts = {}
        for _, u in ipairs(plan.unmet) do
            parts[#parts + 1] = string.format("%s あと %s", Icor_planner_option_name(u.opt),
                GET_COMMAED_STRING(math.ceil(u.short)))
        end
        return parts
    end
    local unmet, unmet_low = unmet_text(avg), unmet_text(low)
    if #unmet > 0 or #unmet_low > 0 then
        local parts = {}
        for _, p in ipairs(#unmet > 0 and unmet or {jp and "無し" or "none"}) do
            parts[#parts + 1] = "{#FF6347}" .. p
        end
        if #unmet_low > 0 then
            parts[#parts + 1] = "{#AAAAAA}(最低値なら " .. table.concat(unmet_low, " / ") .. ")"
        end
        y = Icor_planner_flow(list, "rec_unmet", 20, y, list:GetWidth() - 50,
            "{#FF6347}" .. (jp and "枠が足りず届かない:" or "Not reachable:"), parts, "{ol}{s14}", 22)
    end
    return y
end

-- 「今の装備から変えるなら」。今のイコルを残したまま、どの部位のどの枠を何に変えれば目標に届くか
-- (Icor_planner_plan_keep)。部位ごとに 1 行で並べる。戻り値は次に描き始める y
function Icor_planner_draw_keep_plan(list, y, diag, scan)
    local jp = g.lang == "Japanese"
    local avg = Icor_planner_plan_keep(diag, scan, "avg")
    local low = Icor_planner_plan_keep(diag, scan, "min")
    y = y + 10
    local title = list:CreateOrGetControl("richtext", "keep_title", 10, y, 0, 0)
    AUTO_CAST(title)
    title:SetText(jp and
                      string.format(
            "{ol}{s16}{#FFD700}今の装備から変えるなら{#AAAAAA}{s14}  平均値で計算  {#FFFFFF}あとオプション {#FFD700}%d{#FFFFFF} 個{#AAAAAA}  /  最低値なら {#FFFFFF}%d{#AAAAAA} 個",
            avg.updates, low.updates) or
                      string.format("{ol}{s16}{#FFD700}From your current icor{#AAAAAA}  (avg) %d / (min) %d", avg.updates,
            low.updates))
    title:SetTextTooltip(jp and
                             "{ol}今のイコルを残したまま、目標に届くまでにどの枠を変えればよいかです{nl}変えるのは 空いている枠 / 目標に無いオプションの枠 / 目標にあるが値の低い枠 だけです{nl}部位は 1 か所ずつ数えます(持ち替え側も別のイコル){nl}平均 = 一番上の段の (最小 + 最大) / 2、最低値 = 一番上の段の最小値" or
                             "{ol}Which slots to change while keeping your current icor")
    y = y + 26
    if #avg.moves == 0 and #avg.unmet == 0 and next(avg.slot_unmet) == nil then
        local ok = list:CreateOrGetControl("richtext", "keep_ok", 20, y, 0, 0)
        AUTO_CAST(ok)
        ok:SetText(jp and "{ol}{s15}{#98FB98}今の装備のままで目標に届いています" or "{ol}{s15}{#98FB98}All targets met")
        return y + 24
    end
    local groups, order = {}, {}
    for _, m in ipairs(avg.moves) do
        if groups[m.index] == nil then
            groups[m.index] = {}
            order[#order + 1] = m.index
        end
        table.insert(groups[m.index], m)
    end
    for _, index in ipairs(order) do
        local entry = scan.slots[index]
        local label = (jp and g.icor_planner_exclude_labels[entry.slot_name]) or ClMsg(entry.clmsg)
        local parts = {}
        for _, m in ipairs(groups[index]) do
            local color = g.icor_planner_group_color[Icor_planner_group_of(m.opt)] or "{#FFFFFF}"
            local to = string.format("%s%s {#FFFFFF}%s", color, Icor_planner_option_name(m.opt),
                GET_COMMAED_STRING(m.value))
            if m.old ~= nil then
                -- 同じオプションの値を上げる(リロールし直す / 買い替える)
                parts[#parts + 1] = string.format("%s%s {#AAAAAA}%s → {#FFFFFF}%s", color,
                    Icor_planner_option_name(m.opt), GET_COMMAED_STRING(m.old), GET_COMMAED_STRING(m.value))
            elseif m.from ~= nil then
                parts[#parts + 1] = string.format("{#888888}%s → %s", Icor_planner_option_name(m.from.opt), to)
            else
                parts[#parts + 1] = string.format("{#888888}%s → %s", jp and "空き" or "empty", to)
            end
        end
        y = Icor_planner_flow(list, "keep_" .. index, 20, y, list:GetWidth() - 50, "{#FFFFFF}" .. label .. " :", parts,
            "{ol}{s15}", 24)
    end
    -- 変えられる枠を使い切っても届かない項目
    local parts = {}
    for _, u in ipairs(avg.unmet) do
        parts[#parts + 1] = string.format("{#FF6347}%s あと %s", Icor_planner_option_name(u.opt),
            GET_COMMAED_STRING(math.ceil(u.short)))
    end
    for opt, left in pairs(avg.slot_unmet) do
        parts[#parts + 1] = string.format("{#FF6347}%s あと %d か所", Icor_planner_option_name(opt), left)
    end
    if #parts > 0 then
        y = Icor_planner_flow(list, "keep_unmet", 20, y, list:GetWidth() - 50, "{#FF6347}" ..
            (jp and "変えられる枠では届かない:" or "Not reachable:"), parts, "{ol}{s14}", 22)
    end
    return y
end

-- 目標プリセットを選ぶドロップリスト。3 枚のタブすべての先頭に置く
function Icor_planner_preset_droplist(bg, y)
    local drop = bg:CreateOrGetControl("droplist", "preset_drop", 260, 30, ui.LEFT, ui.TOP, 10, y, 0, 0)
    AUTO_CAST(drop)
    drop:SetSkinName("droplist_normal")
    drop:EnableHitTest(1)
    drop:SetTextAlign("center", "center")
    drop:ClearItems()
    local _, cur_index = Icor_planner_cur_preset()
    for i, preset in ipairs(g.icor_planner_settings.presets) do
        drop:AddItem(i, preset.name)
    end
    drop:SelectItemByKey(cur_index or 1)
    drop:SetSelectedScp("Icor_planner_preset_select")
    drop:Invalidate()
    return drop
end

function Icor_planner_preset_select(parent, ctrl)
    AUTO_CAST(ctrl)
    local key = tonumber(ctrl:GetSelItemKey())
    if key then
        Icor_planner_set_preset(key)
    end
    Icor_planner_build_tab()
end

-- ===== 診断タブ =====
function Icor_planner_build_diagnosis(bg)
    Icor_planner_preset_droplist(bg, 10)
    local reload = bg:CreateOrGetControl("button", "reload", 120, 30, ui.LEFT, ui.TOP, 280, 10, 0, 0)
    AUTO_CAST(reload)
    reload:SetSkinName("test_pvp_btn")
    reload:SetText(g.lang == "Japanese" and "{ol}{s16}再計算" or "{ol}{s16}Refresh")
    reload:SetEventScript(ui.LBUTTONUP, "Icor_planner_build_tab")
    local diag, scan = Icor_planner_diagnose()
    local head = bg:CreateOrGetControl("richtext", "head", 10, 50, 0, 0)
    AUTO_CAST(head)
    if #diag.rows == 0 and #diag.slot_rows == 0 then
        head:SetText(g.lang == "Japanese" and
                         "{ol}{s16}{#FFA500}目標が設定されていません。「目標」タブで項目と目標値を決めてください" or
                         "{ol}{s16}{#FFA500}No target set. Use the Target tab.")
        return
    end
    -- **「あとオプション何個か」を主役にする。** どのイコルを何個買うかより、
    -- 更新が要るオプションの数の方が作業量に直結する。
    -- **数は下のオススメのイコル構成と同じ計算から出す**(一覧とオススメが食い違わないように)
    local plan = Icor_planner_plan(diag, scan, "avg")
    local all_met = true
    for _, row in ipairs(diag.rows) do
        if row.short > 0 then
            all_met = false
        end
    end
    for _, row in ipairs(diag.slot_rows) do
        if row.have < row.want then
            all_met = false
        end
    end
    local unreachable = #plan.unmet > 0 or next(plan.slot_unmet) ~= nil
    if all_met then
        head:SetText(g.lang == "Japanese" and "{ol}{s18}{#98FB98}目標はすべて達成しています" or
                         "{ol}{s18}{#98FB98}All targets met")
    else
        head:SetText(g.lang == "Japanese" and
                         string.format("{ol}{s18}あと {#FFD700}オプション %d 個{/} の更新%s", plan.updates,
                unreachable and "{#FF6347}(枠が足りず届かない目標があります)" or "で目標に届きます") or
                         string.format("{ol}{s18}{#FFD700}%d option(s){/} to update", plan.updates))
    end
    local note = bg:CreateOrGetControl("richtext", "note", 10, 78, 0, 0)
    AUTO_CAST(note)
    if plan.update_mode then
        note:SetText(g.lang == "Japanese" and
                         "{ol}{s14}{#AAAAAA}数え方: 下の{#FFFFFF}更新するイコルのオススメ{#AAAAAA}と同じ計算です(1 枠は一番上の段の{#FFFFFF}平均値{#AAAAAA}で数えます)" or
                         "{ol}{s14}{#AAAAAA}Counted the same way as the suggestion below (average value per slot)")
    else
        note:SetText(g.lang == "Japanese" and
                         "{ol}{s14}{#AAAAAA}数え方: 今のイコルを残したまま、下の{#FFFFFF}今の装備から変えるなら{#AAAAAA}の枠を変えた数です(1 枠は一番上の段の{#FFFFFF}平均値{#AAAAAA}で数えます)" or
                         "{ol}{s14}{#AAAAAA}Options to change while keeping the current icor (average value per slot)")
    end
    -- 列の左端。**見出しと行で同じ表を使う**こと。別々に書くと必ずずれる
    local cols = g.icor_planner_cols
    local labels = g.lang == "Japanese" and {"項目", "現在", "目標", "不足", "必要オプション"} or
                       {"Option", "Current", "Target", "Short", "Options"}
    for i, label in ipairs(labels) do
        local head_col = bg:CreateOrGetControl("richtext", "col_" .. i, 10 + cols[i], 106, 0, 0)
        AUTO_CAST(head_col)
        head_col:SetText("{ol}{s15}{#AAAAAA}" .. label)
    end
    local list = bg:CreateOrGetControl("groupbox", "list", bg:GetWidth() - 20, bg:GetHeight() - 200, ui.LEFT, ui.TOP,
        10, 130, 0, 0)
    AUTO_CAST(list)
    list:SetSkinName("bg")
    list:EnableScrollBar(1)
    local y = 6
    for i, row in ipairs(diag.rows) do
        local color = g.icor_planner_group_color[Icor_planner_group_of(row.opt)] or "{#FFFFFF}"
        local slots_text
        local o = plan.by_opt[row.opt]
        local updates = o and o.updates or 0
        local unmet = plan.unmet_by_opt[row.opt]
        if row.short <= 0 then
            slots_text = "{#98FB98}" .. (g.lang == "Japanese" and "達成" or "done")
        elseif unmet then
            -- オススメでも枠が足りずに届かない。**何個置いても、あといくつ足りないか**を出す
            -- (以前は「3 個でも届きません」で、何の 3 個なのかが分からなかった。実機で指摘された)
            local short_text = GET_COMMAED_STRING(math.ceil(unmet))
            if g.lang == "Japanese" then
                slots_text = string.format("{#FF6347}%d 個 置いても あと %s 不足", updates, short_text)
            else
                slots_text = string.format("{#FF6347}%d placed, short %s", updates, short_text)
            end
        elseif updates > 0 then
            slots_text = string.format("{#FFD700}%d %s", updates, g.lang == "Japanese" and "個" or "")
        else
            -- オススメの形は今の構成で満たしている(平均で数えると届く)が、実際の値が少し足りない
            slots_text = g.lang == "Japanese" and "{#FFD700}0 個(値を上げれば届く)" or "{#FFD700}0 (raise values)"
        end
        -- 対象攻撃力・相殺はステータス画面と同じ ％ を数値の隣に出す(素の ratio 関数を通す)。
        -- **列ごとに別のコントロールへ置く。** 1 本の文字列に空白で並べても、
        -- 名前や桁数が違えば揃わない
        local cells = {color .. Icor_planner_option_name(row.opt),
                       "{#FFFFFF}" .. Icor_planner_value_text(row.opt, row.cur),
                       "{#FFFFFF}" .. Icor_planner_value_text(row.opt, row.target, "{#FFD700}"),
                       "{#FFFFFF}" .. Icor_planner_value_text(row.opt, row.short), slots_text}
        for c, cell in ipairs(cells) do
            local ctrl = list:CreateOrGetControl("richtext", "row_" .. i .. "_" .. c, 10 + cols[c], y, 0, 0)
            AUTO_CAST(ctrl)
            ctrl:SetText("{ol}{s16}" .. cell)
            -- はみ出すのは列の幅まで。**行全体の幅で縮めないこと**(1 つ長い名前があるだけで
            -- 行ごと小さくなる)
            local next_x = cols[c + 1] or (list:GetWidth() - 20)
            ctrl:AdjustFontSizeByWidth(next_x - cols[c] - 10)
        end
        y = y + 26
    end
    -- 各部位に載せたい目標。合計とは数え方が違うので節を分ける
    if #diag.slot_rows > 0 then
        y = y + 10
        local slot_title = list:CreateOrGetControl("richtext", "slot_title", 10, y, 0, 0)
        AUTO_CAST(slot_title)
        slot_title:SetText(g.lang == "Japanese" and
                               "{ol}{s16}{#FFD700}各部位に載せたい目標{#AAAAAA}{s14}  ※載っていない部位を並べています" or
                               "{ol}{s16}{#FFD700}Wanted on every slot")
        y = y + 26
        for i, row in ipairs(diag.slot_rows) do
            local line = list:CreateOrGetControl("richtext", "sr_" .. i, 10, y, 0, 0)
            AUTO_CAST(line)
            local color = g.icor_planner_group_color[Icor_planner_group_of(row.opt)] or "{#FFFFFF}"
            local missing = {}
            for slot_index, info in pairs(row.slots) do
                if not info.ok then
                    missing[#missing + 1] = ClMsg(scan.slots[slot_index].clmsg)
                end
            end
            table.sort(missing)
            local state = (row.want > 0 and row.have >= row.want) and "{#98FB98}" or "{#FFA500}"
            if row.have >= row.want then
                -- 目指す数に届いていれば、残りの部位は「載っていない」ではなく「狙っていない」
                missing = {}
            end
            -- 「あと何個」はオススメと同じ計算(置いた数 - 今載っている数)
            local o = plan.by_opt[row.opt]
            local need_text = ""
            if row.have < row.want then
                need_text = string.format("{#FFD700}あと %d 個{/}  ", o and o.updates or 0)
                local left = plan.slot_unmet[row.opt]
                if left then
                    need_text = need_text .. string.format(plan.update_mode and
                                                               "{#FF6347}(更新するイコルが足りず あと %d か所){/}  " or
                                                               "{#FF6347}(載せる場所が足りず あと %d か所){/}  ", left)
                end
            end
            line:SetText(string.format("{ol}{s16}%s%s{#FFFFFF}  %s%d/%d %s{/}  %s%s", color,
                Icor_planner_option_name(row.opt), state, math.min(row.have, row.want), row.want,
                g.lang == "Japanese" and "部位" or "slots", need_text,
                #missing > 0 and ("{#888888}" .. table.concat(missing, " / ")) or ""))
            line:AdjustFontSizeByWidth(list:GetWidth() - 30)
            y = y + 24
        end
    end
    -- 目標を満たすための、部位の種類ごとの理想の構成
    y = Icor_planner_draw_recommend(list, y, diag, scan)
    -- 「部位ごとのイコル」(8 部位のオプションの内訳)は出さない。更新するイコルは目標タブで選び、
    -- 何を載せるかは上のオススメで見る形にしたので、読むものが増えるだけだった(実機で指摘された)
end

-- ===== 目標タブ =====
--
-- 左に候補(押すと目標へ入れる / 外す)、右に今の目標(目標値を入力する)。
function Icor_planner_build_target(bg)
    Icor_planner_preset_droplist(bg, 10)
    local name_edit = bg:CreateOrGetControl("edit", "preset_name", 240, 30, ui.LEFT, ui.TOP, 280, 10, 0, 0)
    AUTO_CAST(name_edit)
    name_edit:SetSkinName("test_weight_skin")
    local preset = Icor_planner_cur_preset()
    name_edit:SetText(preset and preset.name or "")
    name_edit:SetEventScript(ui.ENTERKEY, "Icor_planner_preset_rename")
    local add_btn = bg:CreateOrGetControl("button", "preset_add", 100, 30, ui.LEFT, ui.TOP, 530, 10, 0, 0)
    AUTO_CAST(add_btn)
    add_btn:SetSkinName("test_pvp_btn")
    add_btn:SetText(g.lang == "Japanese" and "{ol}{s15}新規" or "{ol}{s15}New")
    add_btn:SetEventScript(ui.LBUTTONUP, "Icor_planner_preset_add")
    local del_btn = bg:CreateOrGetControl("button", "preset_del", 100, 30, ui.LEFT, ui.TOP, 640, 10, 0, 0)
    AUTO_CAST(del_btn)
    del_btn:SetSkinName("test_pvp_btn")
    del_btn:SetText(g.lang == "Japanese" and "{ol}{s15}削除" or "{ol}{s15}Delete")
    del_btn:SetEventScript(ui.LBUTTONUP, "Icor_planner_preset_delete")
    -- 2 段目は「計算しないイコル」(Icor_planner_exclude_buttons)。ヒントと一覧はその下
    local hint = bg:CreateOrGetControl("richtext", "hint", 10, 84, 0, 0)
    AUTO_CAST(hint)
    hint:SetText(g.lang == "Japanese" and
                     "{ol}{s14}{#AAAAAA}左の候補を押すと目標に入ります。{#FFD700}合計{#AAAAAA}=キャラの合計で足りればよい / {#FFD700}各部位{#AAAAAA}=その部位のイコル 1 つずつに載せたい(目標値は 1 枠の最低値・0 可)" or
                     "{ol}{s14}{#AAAAAA}Click a candidate to add it. Type the target value and press Enter (0 disables)")
    local left = bg:CreateOrGetControl("groupbox", "cand", 420, bg:GetHeight() - 146, ui.LEFT, ui.TOP, 10, 112, 0, 0)
    AUTO_CAST(left)
    left:SetSkinName("bg")
    left:EnableScrollBar(1)
    local right = bg:CreateOrGetControl("groupbox", "targets", bg:GetWidth() - 450, bg:GetHeight() - 146, ui.LEFT,
        ui.TOP, 440, 112, 0, 0)
    AUTO_CAST(right)
    right:SetSkinName("bg")
    right:EnableScrollBar(1)
    Icor_planner_fill_candidates(left)
    Icor_planner_fill_targets(right)
    Icor_planner_exclude_buttons(bg)
end

-- 「計算しないイコル」の切り替え。目標タブの 2 段目(プリセットの行の下)に並べる。
-- **プリセットの行の右へ詰めないこと。** 8 部位ぶんの幅が足りず、部位名が潰れて読めなかった
-- 押した部位のイコルは、現在値・それ以外・達成数・診断のすべてで**載っていない扱い**になる
-- (「この部位は付け替える予定」のときに、外した後の姿で目標との差を見るため)
g.icor_planner_exclude_y = 46

-- ボタンの表示名。**武器は持ち替えのセットが分かるように自前の名前にする**
-- (素の名前だと「セット1(右手)」のように長く、ボタンに収まらない)。防具は素の名前のまま
g.icor_planner_exclude_labels = {
    RH = "メイン武器1",
    LH = "サブ武器1",
    RH_SUB = "メイン武器2",
    LH_SUB = "サブ武器2"
}

function Icor_planner_exclude_buttons(bg)
    local y = g.icor_planner_exclude_y
    local label = bg:CreateOrGetControl("richtext", "excl_label", 10, y + 6, 0, 0)
    AUTO_CAST(label)
    label:SetText(g.lang == "Japanese" and "{ol}{s15}{#AAAAAA}更新するイコル" or "{ol}{s15}{#AAAAAA}Icor to update")
    label:SetTextTooltip(g.lang == "Japanese" and
                             "{ol}押した部位のイコルを「更新する(付け替える)」ものとして計算から外します(キャラごとに保存){nl}現在値・それ以外・達成数では載っていない扱いになり、{nl}診断タブではこの部位に何を載せればよいかをオススメします" or
                             "{ol}Mark these slots as icor to replace")
    local scan = Icor_planner_scan()
    for i, entry in ipairs(scan.slots) do
        local btn = bg:CreateOrGetControl("button", "excl_" .. entry.slot_name, 100, 30, ui.LEFT, ui.TOP,
            150 + (i - 1) * 106, y, 0, 0)
        AUTO_CAST(btn)
        btn:SetSkinName("test_pvp_btn")
        local name = ClMsg(entry.clmsg)
        if g.lang == "Japanese" and g.icor_planner_exclude_labels[entry.slot_name] then
            name = g.icor_planner_exclude_labels[entry.slot_name]
        end
        if entry.excluded then
            btn:SetText("{ol}{s14}{#FF6347}" .. name)
        elseif entry.equipped and #entry.options > 0 then
            btn:SetText("{ol}{s14}" .. name)
        else
            btn:SetText("{ol}{s14}{#666666}" .. name)
        end
        -- 何を外すのか分かるよう、載っているオプションをツールチップに並べる
        local lines = {}
        for _, op in ipairs(entry.options) do
            lines[#lines + 1] = string.format("%s %s", Icor_planner_option_name(op.opt), GET_COMMAED_STRING(op.value))
        end
        local state
        if entry.excluded then
            state = g.lang == "Japanese" and "{#FF6347}更新する(計算しない){/}" or "{#FF6347}to update{/}"
        else
            state = g.lang == "Japanese" and "計算する" or "counted"
        end
        local body = #lines > 0 and table.concat(lines, "{nl}") or (g.lang == "Japanese" and "イコル無し" or "no icor")
        btn:SetTextTooltip(string.format("{ol}%s : %s{nl}%s", name, state, body))
        btn:SetEventScript(ui.LBUTTONUP, "Icor_planner_toggle_exclude")
        btn:SetEventScriptArgString(ui.LBUTTONUP, entry.slot_name)
    end
end

function Icor_planner_toggle_exclude(parent, ctrl, slot_name)
    local settings = g.icor_planner_settings
    local key = tostring(g.cid)
    settings.excluded[key] = settings.excluded[key] or {}
    local list = settings.excluded[key]
    if list[slot_name] == true then
        list[slot_name] = nil
    else
        list[slot_name] = true
    end
    g.vlog("icor_planner: %s のイコルを%s", tostring(slot_name), list[slot_name] and "計算しない" or "計算する")
    Icor_planner_save_settings()
    Icor_planner_build_tab()
end

function Icor_planner_fill_candidates(left)
    left:RemoveAllChild()
    local preset = Icor_planner_cur_preset()
    local chosen = {}
    for _, t in ipairs((preset and preset.targets) or {}) do
        chosen[t.opt] = true
    end
    -- 何行あるかを数える(同じオプションを 2 行持てるので)
    local counts = {}
    for _, t in ipairs((preset and preset.targets) or {}) do
        counts[t.opt] = (counts[t.opt] or 0) + 1
    end
    local y, last_group = 6, nil
    for _, cand in ipairs(Icor_planner_candidate_options()) do
        if cand.group ~= last_group then
            last_group = cand.group
            local head = left:CreateOrGetControl("richtext", "gh_" .. cand.group, 8, y, 0, 0)
            AUTO_CAST(head)
            head:SetText(string.format("{ol}{s15}%s%s", g.icor_planner_group_color[cand.group] or "{#FFFFFF}",
                cand.group))
            y = y + 22
        end
        local btn = left:CreateOrGetControl("button", "c_" .. cand.opt, 390, 22, ui.LEFT, ui.TOP, 14, y, 0, 0)
        AUTO_CAST(btn)
        btn:SetSkinName("None")
        btn:SetTextAlign("left", "center")
        btn:SetText(string.format("{ol}{s15}%s %s%s", chosen[cand.opt] and "{#FFD700}■" or "{#666666}□",
            Icor_planner_option_name(cand.opt),
            (counts[cand.opt] or 0) > 1 and string.format("{#AAAAAA} x%d", counts[cand.opt]) or ""))
        btn:SetEventScript(ui.LBUTTONUP, "Icor_planner_toggle_target")
        btn:SetEventScriptArgString(ui.LBUTTONUP, cand.opt)
        y = y + 22
    end
end

function Icor_planner_toggle_target(parent, ctrl, opt)
    local preset = Icor_planner_cur_preset()
    if not preset then
        return
    end
    preset.targets = preset.targets or {}
    -- **外すときはそのオプションの行を全部落とす。** 2 行に分けている場合、
    -- 1 行だけ消えると「押したのに残っている」ことになって分かりにくい
    local removed = false
    for i = #preset.targets, 1, -1 do
        if preset.targets[i].opt == opt then
            table.remove(preset.targets, i)
            removed = true
        end
    end
    if removed then
        Icor_planner_save_settings()
        Icor_planner_build_tab()
        return
    end
    preset.targets[#preset.targets + 1] = {
        opt = opt,
        value = 0
    }
    Icor_planner_assign_ids(preset)
    Icor_planner_save_settings()
    Icor_planner_build_tab()
end

function Icor_planner_fill_targets(right)
    right:RemoveAllChild()
    local preset = Icor_planner_cur_preset()
    -- **見出しも列で置く。** 空白で位置を合わせても、名前も桁数も違えば揃わない
    local tcols = g.icor_planner_target_cols
    local labels = g.lang == "Japanese" and {"項目", "数え方", "部位", "現在", "目標値"} or
                       {"Option", "Count", "Spot", "Current", "Target"}
    for i, text in ipairs(labels) do
        local head = right:CreateOrGetControl("richtext", "th_" .. i, tcols[i], 6, 0, 0)
        AUTO_CAST(head)
        head:SetText("{ol}{s15}{#AAAAAA}" .. text)
    end
    -- **左(候補)と同じ並びで出す。** targets は押した順に足されるので、そのまま並べると
    -- 左右で順番が食い違う(実機で指摘された)。候補一覧の order を唯一の基準にする
    local sorted = {}
    for _, t in ipairs((preset and preset.targets) or {}) do
        sorted[#sorted + 1] = t
    end
    table.sort(sorted, function(a, b)
        local oa, ob = Icor_planner_order_of(a.opt), Icor_planner_order_of(b.opt)
        if oa ~= ob then
            return oa < ob
        end
        if a.opt ~= b.opt then
            return a.opt < b.opt
        end
        -- **同じ項目の行は id 順で固定する。** table.sort は安定ではないので、決め手が無いと
        -- 開くたびに上下が入れ替わる。％ をまとめて出す行(先頭)もこの順で決めている
        return (a.id or 0) < (b.id or 0)
    end)
    local y = 30
    -- 項目ごとの 1 行目の id。並びは id 順で固定してあるので、先に出た行が 1 行目
    local first_row_of = {}
    for _, t in ipairs(sorted) do
        -- **項目名と現在値は別のコントロールへ。** 1 本の文字列に空白で繋ぐと、
        -- 名前の長さで現在値の位置が動く(診断タブで直したのと同じ形が残っていた)
        -- **コントロール名は id で作る。** 同じオプションを 2 行持てるようにしたので、
        -- オプション名だと 2 行目が 1 行目を掴んでしまう
        local key = tostring(t.id or 0)
        local label = right:CreateOrGetControl("richtext", "tl_" .. key, tcols[1], y + 4, 0, 0)
        AUTO_CAST(label)
        label:SetText(string.format("{ol}{s15}%s%s",
            g.icor_planner_group_color[Icor_planner_group_of(t.opt)] or "{#FFFFFF}",
            Icor_planner_option_name(t.opt)))
        -- 縮めるのは自分の列の幅まで。長い名前が 1 つあっても他の行に影響しない
        label:AdjustFontSizeByWidth(g.icor_planner_target_add_x - tcols[1] - 10)
        -- **その項目の 1 行目は「+」(もう 1 行足す)、足した 2 行目以降は「×」(その行を消す)。**
        -- 「武器の各部位に載せて、足りない分は防具で合計を埋める」のように、
        -- 数え方と対象部位を変えた 2 行目が要る組み方があるため足せるようにしてあり、
        -- 足しすぎた行を消す手段も要る(実機で指摘された)。1 行目を消すのは左の候補を押し直す
        local is_extra = first_row_of[t.opt] ~= nil
        first_row_of[t.opt] = first_row_of[t.opt] or t.id
        local add_btn = right:CreateOrGetControl("button", "ta_" .. key, 26, 24, ui.LEFT, ui.TOP,
            g.icor_planner_target_add_x, y, 0, 0)
        AUTO_CAST(add_btn)
        add_btn:SetSkinName("test_pvp_btn")
        if is_extra then
            add_btn:SetText("{ol}{s14}{#FF6347}×")
            add_btn:SetTextTooltip(g.lang == "Japanese" and "{ol}この行を消す" or "{ol}Remove this row")
            add_btn:SetEventScript(ui.LBUTTONUP, "Icor_planner_remove_target_row")
        else
            add_btn:SetText("{ol}{s14}+")
            add_btn:SetTextTooltip(g.lang == "Japanese" and
                                       "{ol}この項目をもう 1 行足す{nl}例: 武器は「各部位」、防具は「合計」で残りを埋める{nl}足した行は「×」で消せます" or
                                       "{ol}Add another row for this option")
            add_btn:SetEventScript(ui.LBUTTONUP, "Icor_planner_duplicate_target")
        end
        add_btn:SetEventScriptArgNumber(ui.LBUTTONUP, t.id or 0)
        -- 数え方(合計 / 各部位)。押すたびに入れ替える
        local mode = Icor_planner_target_mode(t)
        local is_slot = (mode == g.icor_planner_mode_slot)
        local mode_btn = right:CreateOrGetControl("button", "tm_" .. key, 64, 24, ui.LEFT, ui.TOP, tcols[2], y, 0,
            0)
        AUTO_CAST(mode_btn)
        mode_btn:SetSkinName("test_pvp_btn")
        mode_btn:SetText(g.lang == "Japanese" and ("{ol}{s14}" .. (is_slot and "各部位" or "合計")) or
                             ("{ol}{s14}" .. (is_slot and "Slot" or "Total")))
        mode_btn:SetTextTooltip(g.lang == "Japanese" and
                                    "{ol}合計 : キャラの合計が目標に届けばよい{nl}各部位 : その部位のイコル 1 つずつに載っていてほしい" or
                                    "{ol}Total: character total{nl}Slot: wanted on every icor of that spot")
        if Icor_planner_is_counter(t.opt) then
            -- 相殺は合計でしか意味を持たないので押せなくする
            mode_btn:SetText("{ol}{s14}{#888888}" .. (g.lang == "Japanese" and "合計" or "Total"))
            mode_btn:SetTextTooltip(g.lang == "Japanese" and
                                        "{ol}相殺は合計でのみ意味を持つため、各部位には切り替えられません" or
                                        "{ol}Counters only make sense as a total")
        else
            mode_btn:SetEventScript(ui.LBUTTONUP, "Icor_planner_toggle_mode")
            mode_btn:SetEventScriptArgNumber(ui.LBUTTONUP, t.id or 0)
        end
        -- 対象部位。**素で 1 部位にしか載らないものは押せない**(押しても意味が無い)
        local spot = Icor_planner_target_spot(t)
        local spot_btn = right:CreateOrGetControl("button", "ts_" .. key, 58, 24, ui.LEFT, ui.TOP, tcols[3], y, 0,
            0)
        AUTO_CAST(spot_btn)
        spot_btn:SetSkinName("test_pvp_btn")
        if Icor_planner_target_spot_fixed(t) then
            spot_btn:SetText("{ol}{s14}{#888888}" .. Icor_planner_spot_label(spot))
            spot_btn:SetTextTooltip(g.lang == "Japanese" and
                                        "{ol}このオプションはこの部位にしか載りません(素の仕様)" or
                                        "{ol}This option only exists on this spot")
        else
            spot_btn:SetText("{ol}{s14}" .. Icor_planner_spot_label(spot))
            spot_btn:SetTextTooltip(g.lang == "Japanese" and
                                        "{ol}どの部位のイコルで狙うか{nl}合計の目標でも効きます(例: 相殺は防具だけで狙う)" or
                                        "{ol}Which spot's icors should carry this")
            spot_btn:SetEventScript(ui.LBUTTONUP, "Icor_planner_toggle_spot")
            spot_btn:SetEventScriptArgNumber(ui.LBUTTONUP, t.id or 0)
        end
        local cur = right:CreateOrGetControl("richtext", "tc_" .. key, tcols[4], y + 4, 0, 0)
        AUTO_CAST(cur)
        local slot_want = 0
        if is_slot then
            -- 各部位の目標は「載っている部位の数」で見る
            local have, want, max_count = Icor_planner_slot_progress(t)
            slot_want = want
            Icor_planner_slot_text(cur, have, want, max_count)
            -- **分母(何部位まで目指すか)を −/＋ で変える。** 上限は装備している数。
            -- 入力欄にしないのは、Enter で窓を作り直すとチャットが開く件を避けるため
            for i, step in ipairs({-1, 1}) do
                local btn = right:CreateOrGetControl("button", "tn" .. i .. "_" .. key, 20, 22, ui.LEFT, ui.TOP,
                    tcols[4] + g.icor_planner_count_btn_x[i], y + 1, 0, 0)
                AUTO_CAST(btn)
                btn:SetSkinName("test_pvp_btn")
                btn:SetText("{ol}{s14}" .. (step < 0 and "-" or "+"))
                btn:SetEventScript(ui.LBUTTONUP, "Icor_planner_step_count")
                btn:SetEventScriptArgString(ui.LBUTTONUP, tostring(t.id or 0))
                btn:SetEventScriptArgNumber(ui.LBUTTONUP, step)
                btn:SetTextTooltip(g.lang == "Japanese" and
                                       string.format("{ol}何部位まで目指すか(上限は装備している %d 部位)", max_count) or
                                       string.format("{ol}How many slots to aim for (max %d)", max_count))
            end
        else
            cur:SetText("{ol}{s15}{#FFFFFF}" .. Icor_planner_value_text(t.opt, Icor_planner_current(t.opt)))
            cur:AdjustFontSizeByWidth(tcols[5] - tcols[4] - 10)
        end
        local edit = right:CreateOrGetControl("edit", "te_" .. key, 90, 26, ui.LEFT, ui.TOP, tcols[5], y, 0, 0)
        AUTO_CAST(edit)
        edit:SetSkinName("test_weight_skin")
        edit:SetText(tostring(tonumber(t.value) or 0))
        edit:SetEventScript(ui.ENTERKEY, "Icor_planner_target_value")
        edit:SetEventScriptArgNumber(ui.ENTERKEY, t.id or 0)
        -- 目標値の目安(最低 / 平均 / 最大)。押すとその値を入力欄へ入れる
        Icor_planner_value_buttons(right, t, is_slot, spot, y, key)
        -- 入力した数値の ％。**入力欄の中ではなく隣に出す。** 中へ入れると打ち直すたびに
        -- 消すことになり、日本語変換も巻き込む
        local percent = right:CreateOrGetControl("richtext", "tp_" .. key, tcols[6], y + 4, 0, 0)
        AUTO_CAST(percent)
        -- **各部位でも ％ を出す。** 1 枠あたりの最低値であっても、
        -- **各部位の目標は「全部位に載せたときの合計」で ％ を出す。**
        -- 入力値は 1 枠あたりの最低値なので、そのまま ％ にすると 1 枠ぶんの割合になり、
        -- 「その目標を満たしたらキャラの割合がいくつになるか」が分からない
        -- (実機で指摘された。武器 2 か所なら入力値の 2 倍が合計)
        Icor_planner_set_target_percent(percent, t, is_slot, slot_want)
        -- **開いた直後に Focus() しないこと。** キーボードフォーカスが入力欄にあると
        -- ESC の 1 回目が「入力欄から抜ける」に使われ、窓が閉じなくなる(CLAUDE.md)
        y = y + 30
    end
    if y == 30 then
        local empty = right:CreateOrGetControl("richtext", "empty", 8, 40, 0, 0)
        AUTO_CAST(empty)
        empty:SetText(g.lang == "Japanese" and "{ol}{s15}{#888888}左から項目を選んでください" or
                          "{ol}{s15}{#888888}Pick options on the left")
    end
end

-- 目標値の目安ボタン。押すと入力欄へ値を入れる。
--
-- 何を入れるかは行の性格で変わる。
--   * 相殺        … 最大だけが働き、**ステータスの割合が 50% になる値**を入れる
--                    (Lv560 なら 8,400)。最低 / 平均は意味を持たないので灰色
--   * 各部位      … **今の最大レベルのイコル 1 枚**の min / 中間 / max
--   * 合計        … 目安を出しようがない(何部位で分担するかは利用者次第)ので灰色
-- 「合計」のとき、最大ボタンで**ステータスの割合が 100% になる値**を入れる項目。
-- 全ての〜 はキャラの合計で 100% まで積むのが目標になるので、1 枚の範囲より割合の方が目安になる
g.icor_planner_full_percent_opts = {
    AllRace_Atk = true,
    AllMaterialType_Atk = true
}

function Icor_planner_value_buttons(right, t, is_slot, spot, y, key)
    local btns = g.icor_planner_target_btns
    -- **最低 / 最大 / 限凸。** 限凸(上限突破)は、素のツールチップが紫にする線
    -- (equip_tooltip.lua の DRAW_EQUIP_GODDESS_ICOR: floor(最大値 × 1.5) - 1 以上)。
    -- 「上限突破のイコルを狙う」目標をそのまま入れられるようにするため
    local labels = g.lang == "Japanese" and {"最低", "最大", "限凸"} or {"Min", "Max", "Break"}
    local counter = Icor_planner_is_counter(t.opt)
    local full = (not is_slot) and g.icor_planner_full_percent_opts[t.opt] == true
    for i = 1, 3 do
        local btn = right:CreateOrGetControl("button", "tb" .. i .. "_" .. key, 44, 24, ui.LEFT, ui.TOP, btns[i], y,
            0, 0)
        AUTO_CAST(btn)
        btn:SetSkinName("test_pvp_btn")
        -- 合計の目標で使えるのは「最大」だけ(相殺は 50%、全ての〜 は 100% の値が入る)。
        -- 各部位の目標では 3 つとも使える
        local enabled = ((counter or full) and i == 2) or (not counter and is_slot)
        if enabled then
            btn:SetText("{ol}{s14}" .. (i == 3 and "{#DA70D6}" or "") .. labels[i])
            btn:SetEventScript(ui.LBUTTONUP, "Icor_planner_fill_value")
            btn:SetEventScriptArgString(ui.LBUTTONUP, tostring(t.id or 0))
            btn:SetEventScriptArgNumber(ui.LBUTTONUP, i)
            if counter then
                btn:SetTextTooltip(g.lang == "Japanese" and
                                       "{ol}ステータスの割合が 50% になる値を入れます" or
                                       "{ol}Fills the value that reaches 50% on the status screen")
            elseif full then
                btn:SetTextTooltip(g.lang == "Japanese" and
                                       "{ol}ステータスの割合が 100% になる値を入れます(イコル以外の分も含めた合計)" or
                                       "{ol}Fills the value that reaches 100% on the status screen")
            elseif i == 3 then
                btn:SetTextTooltip(Icor_planner_break_tooltip(t.opt, spot))
            else
                btn:SetTextTooltip(Icor_planner_range_tooltip(t.opt, spot))
            end
        else
            btn:SetText("{ol}{s14}{#666666}" .. labels[i])
            btn:SetTextTooltip(g.lang == "Japanese" and
                                   (counter and "{ol}相殺では「最大」(割合 50% の値)だけ使えます" or
                                       "{ol}「各部位」のときだけ使えます(合計は分担の仕方で変わるため)") or
                                   "{ol}Only available for per-slot targets")
        end
    end
end

-- 「限凸」ボタンの説明。上限突破の値がどう決まるかを出す
function Icor_planner_break_tooltip(opt, spot)
    if g.lang ~= "Japanese" then
        return "{ol}Fills the value that counts as a limit break"
    end
    local function line(label, sp)
        local _, max_value = Icor_planner_top_range(opt, sp)
        if max_value <= 0 then
            return string.format("{nl}%s: 取れませんでした", label)
        end
        return string.format("{nl}%s: 最大 %s → 限凸 %s 以上", label, GET_COMMAED_STRING(max_value),
            GET_COMMAED_STRING(Icor_planner_break_limit(max_value)))
    end
    local head = "{ol}上限突破(限凸)と見なされる値を入れます{nl}{#AAAAAA}素のツールチップが紫にする線と同じ" ..
                     "(最大値 × 1.5 の切り捨て − 1 以上){/}"
    if spot == "both" then
        return head .. line("武器", "Weapon") .. line("防具", "Armor") ..
                   "{nl}{#FFA500}両方に載せる目標なので、小さい方を入れます"
    end
    return head .. line(Icor_planner_spot_label(spot), spot)
end

-- 目安ボタンの説明。**武器と防具で 1 枚に載る値が違う**ので、
-- 「両方」のときは両方の範囲を並べて出す(小さい方を採っていることも書く)。
-- どこから取った値か(手持ちの実物 / 素の表)も出す。素の表は Lv540 までしか無いため、
-- 実物から取れているかどうかで信頼度が変わる。
function Icor_planner_range_tooltip(opt, spot)
    local function line(label, sp)
        local min_value, max_value, lv, src = Icor_planner_top_range(opt, sp)
        if max_value <= 0 then
            return string.format("{nl}%s: 取れませんでした", label)
        end
        return string.format("{nl}%s: Lv%s %s 〜 %s{#AAAAAA} (%s){/}", label, tostring(lv or "?"),
            GET_COMMAED_STRING(min_value), GET_COMMAED_STRING(max_value),
            (src == "item") and "手持ちのイコルから" or "素の表から")
    end
    if g.lang ~= "Japanese" then
        return "{ol}From one icor's value range"
    end
    if spot == "both" then
        return "{ol}イコル 1 枚に載る範囲" .. line("武器", "Weapon") .. line("防具", "Armor") ..
                   "{nl}{#FFA500}両方に載せる目標なので、小さい方を入れます"
    end
    return "{ol}イコル 1 枚に載る範囲" .. line(Icor_planner_spot_label(spot), spot)
end

function Icor_planner_fill_value(parent, ctrl, id_str, which)
    local t = Icor_planner_target_by_id(tonumber(id_str) or 0)
    do
        if t ~= nil then
            local opt = t.opt
            local value = 0
            if Icor_planner_is_counter(opt) then
                value = Icor_planner_value_at_percent(opt, 0.5)
            elseif g.icor_planner_full_percent_opts[opt] and Icor_planner_target_mode(t) ~= g.icor_planner_mode_slot then
                value = Icor_planner_value_at_percent(opt, 1.0)
            else
                local min_value, max_value = Icor_planner_top_range(opt, Icor_planner_target_spot(t))
                if which == 1 then
                    value = min_value
                elseif which == 3 then
                    -- 限凸。素のツールチップが紫にする線(Icor_planner_break_limit)
                    value = Icor_planner_break_limit(max_value)
                else
                    value = max_value
                end
            end
            if value <= 0 then
                ui.SysMsg(g.lang == "Japanese" and "{ol}目安を出せませんでした" or
                              "{ol}Could not work out a value")
                return
            end
            t.value = value
        end
    end
    Icor_planner_save_settings()
    Icor_planner_build_tab()
end

function Icor_planner_toggle_mode(parent, ctrl, arg_str, id)
    local t = Icor_planner_target_by_id(id)
    if t ~= nil then
        t.mode = (Icor_planner_target_mode(t) == g.icor_planner_mode_slot) and g.icor_planner_mode_total or
                     g.icor_planner_mode_slot
        Icor_planner_save_settings()
        Icor_planner_build_tab()
    end
end

function Icor_planner_toggle_spot(parent, ctrl, arg_str, id)
    local t = Icor_planner_target_by_id(id)
    if t ~= nil then
        local spot = Icor_planner_target_spot(t)
        t.spot = (spot == "both") and "Weapon" or ((spot == "Weapon") and "Armor" or "both")
        Icor_planner_save_settings()
        Icor_planner_build_tab()
    end
end

-- **同じオプションをもう 1 行足す。**
-- 足した行は「合計 / 元の行と違う部位」を既定にする。
-- 「武器の各部位に載せて、残りは防具で合計を埋める」がいちばん多い組み方なので、
-- 押しただけでその形に近いところまで持っていく。
function Icor_planner_duplicate_target(parent, ctrl, arg_str, id)
    local src = Icor_planner_target_by_id(id)
    local preset = Icor_planner_cur_preset()
    if src == nil or preset == nil then
        return
    end
    local spot = Icor_planner_target_spot(src)
    local other = "both"
    if spot == "Weapon" then
        other = "Armor"
    elseif spot == "Armor" then
        other = "Weapon"
    end
    preset.targets[#preset.targets + 1] = {
        opt = src.opt,
        value = 0,
        mode = g.icor_planner_mode_total,
        spot = other
    }
    Icor_planner_assign_ids(preset)
    Icor_planner_save_settings()
    Icor_planner_build_tab()
end

-- 足した行(同じ項目の 2 行目以降)を 1 行だけ消す
function Icor_planner_remove_target_row(parent, ctrl, arg_str, id)
    local preset = Icor_planner_cur_preset()
    if preset == nil then
        return
    end
    for i, t in ipairs(preset.targets or {}) do
        if t.id == id then
            g.vlog("icor_planner: 目標の行を消した %s (id %s)", tostring(t.opt), tostring(id))
            table.remove(preset.targets, i)
            break
        end
    end
    Icor_planner_save_settings()
    Icor_planner_build_tab()
end

function Icor_planner_target_value(parent, ctrl, arg_str, id)
    AUTO_CAST(ctrl)
    local value = tonumber(ctrl:GetText()) or 0
    local t = Icor_planner_target_by_id(id)
    if t == nil then
        return
    end
    t.value = math.max(0, math.floor(value))
    Icor_planner_save_settings()
    -- **ここでタブを組み直さないこと。** 入力欄ごと作り直すことになり、
    -- キーボードフォーカスが外れて **Enter がゲーム側へ抜けてチャットが開く**
    -- (実機で踏んだ)。変わるのは「現在」と「％」だけなので、そこだけ書き替える。
    -- ％ は同じ項目の行でまとめているので、その項目の行を全部書き替える
    Icor_planner_refresh_opt_rows(t.opt)
end

-- 目標値の右の ％。描画と行の書き替えの両方から呼ぶ(文言を 1 か所で持つ)。
--
--   合計   … 入力値は**最終的な合計**なので、そのままの ％。イコル以外の分も含めて目指す値
--   各部位 … 入力値は 1 枠あたりの最低値。**イコル分(値 × 目指す部位数)に、イコル以外の分を
--            足した合計**で ％ を出す。足さないと、協応・カード・ギルドなどの上乗せが
--            抜けて実際より低い ％ に見える(実機で指摘された)
function Icor_planner_set_target_percent(ctrl, t, is_slot, slot_want)
    local value = tonumber(t.value) or 0
    local percent_text, note
    if is_slot then
        -- **同じ項目の「各部位」行はまとめて 1 つの ％ にする。** 「武器で 2 部位 + 防具で 1 部位」
        -- のように行を分けたとき、行ごとにイコル以外の分を足すと二重に数えてしまう
        -- (実機で指摘された)。まとめた ％ は先頭の行にだけ出し、残りの行には「上と合算」と出す
        local group = Icor_planner_slot_percent_group(t.opt)
        if #group == 0 or not group.has[t] then
            -- 0(付いていればよい)の行。それ以外の分だけの ％ になって紛らわしいので出さない
            ctrl:SetText("")
            return
        end
        if group[1].t ~= t then
            ctrl:SetText(g.lang == "Japanese" and "{ol}{s13}{#888888}上と合算" or "{ol}{s13}{#888888}see above")
            ctrl:SetTextTooltip(g.lang == "Japanese" and
                                    "{ol}同じ項目の各部位の行は、上の行でまとめて ％ を出しています" or
                                    "{ol}Combined into the row above")
            return
        end
        local other = Icor_planner_other_sources(t.opt)
        local icor_part = 0
        local lines = {}
        for _, member in ipairs(group) do
            local part = member.value * member.want
            icor_part = icor_part + part
            lines[#lines + 1] = string.format("%s %s × %d = %s", Icor_planner_spot_label(member.spot),
                GET_COMMAED_STRING(member.value), member.want, GET_COMMAED_STRING(part))
        end
        percent_text = Icor_planner_percent(t.opt, icor_part + other)
        note = g.lang == "Japanese" and
                   string.format(
                "{ol}各部位の行をまとめたときのステータスでの割合{nl}%s{nl}イコル %s + それ以外 %s = %s{nl}{#AAAAAA}それ以外 = 今のステータスの値 − 装備イコルのオプション{nl}(ギルド・共用スキル・クポル・カード・アシスター・固定イコル・バフ){nl}バフが切れていると低めに出ます",
                table.concat(lines, "{nl}"), GET_COMMAED_STRING(icor_part), GET_COMMAED_STRING(other),
                GET_COMMAED_STRING(icor_part + other)) or "{ol}Share incl. non-icor sources"
    else
        percent_text = Icor_planner_percent(t.opt, value)
        note = g.lang == "Japanese" and
                   "{ol}この値のときのステータス画面での割合{nl}{#AAAAAA}合計の目標値はイコル以外(ギルド・カードなど)も含めた最終的な値です" or
                   "{ol}Share on the status screen"
    end
    ctrl:SetText(percent_text and ("{ol}{s15}{#FFD700}" .. percent_text) or "")
    if percent_text then
        ctrl:SetTextTooltip(note)
    end
end

-- ％ をまとめる対象 = 今のプリセットで、その項目の「各部位」行のうち値が入っているもの(id 順)。
-- 並びは目標タブの表示と揃えてあるので、group[1] が画面で一番上の行になる
function Icor_planner_slot_percent_group(opt)
    local group = {
        has = {}
    }
    local preset = Icor_planner_cur_preset()
    for _, t in ipairs((preset and preset.targets) or {}) do
        if t.opt == opt and Icor_planner_target_mode(t) == g.icor_planner_mode_slot then
            local value = tonumber(t.value) or 0
            local _, want = Icor_planner_slot_progress(t)
            if value > 0 and want > 0 then
                group[#group + 1] = {
                    t = t,
                    value = value,
                    want = want,
                    spot = Icor_planner_target_spot(t)
                }
                group.has[t] = true
            end
        end
    end
    table.sort(group, function(a, b)
        return (a.t.id or 0) < (b.t.id or 0)
    end)
    return group
end

-- 同じ項目の行をまとめて書き替える。値や部位数を 1 行変えると、
-- まとめた ％ を出している先頭の行と「上と合算」の出し分けも変わるため
function Icor_planner_refresh_opt_rows(opt)
    local preset = Icor_planner_cur_preset()
    for _, t in ipairs((preset and preset.targets) or {}) do
        if t.opt == opt then
            Icor_planner_refresh_target_row(t)
        end
    end
end

-- 「現在」列の −/＋ ボタンの位置(列の左端から)。文字はその手前までに収める
g.icor_planner_count_btn_x = {68, 90}

-- 各部位の「載っている数 / 目指す数」。**目指す数を絞っていれば (上限 N) を添える。**
-- 載っている数が目指す数を超えても、分子は目指す数で止める(「3/2」は読みにくい)
function Icor_planner_slot_text(ctrl, have, want, max_count)
    local shown = math.min(have, want)
    local color = (want > 0 and have >= want) and "{#98FB98}" or "{#FFA500}"
    local text = string.format("{ol}{s15}%s%d/%d", color, shown, want)
    if want < max_count then
        text = text .. string.format("{#AAAAAA}{s12}(%d)", max_count)
    elseif g.lang == "Japanese" then
        text = text .. "{#AAAAAA}{s13}部位"
    end
    ctrl:SetText(text)
    ctrl:AdjustFontSizeByWidth(g.icor_planner_count_btn_x[1] - 4)
end

-- 何部位まで目指すかを 1 つ増減する。上限(装備している数)と同じになったら t.count を消す
function Icor_planner_step_count(parent, ctrl, id_str, step)
    local t = Icor_planner_target_by_id(tonumber(id_str) or 0)
    if t == nil then
        return
    end
    local _, want, max_count = Icor_planner_slot_progress(t)
    local next_count = math.max(1, math.min(max_count, want + (tonumber(step) or 0)))
    t.count = (next_count < max_count) and next_count or nil
    g.vlog("icor_planner: %s の目指す部位数 %d -> %d (上限 %d)", tostring(t.opt), want, next_count, max_count)
    Icor_planner_save_settings()
    Icor_planner_refresh_opt_rows(t.opt)
end

-- 目標 1 行の「現在」と「％」を書き替える。**入力欄には触らない。**
-- 描画(Icor_planner_fill_targets)と同じ文言になるようにしてあるので、
-- 片方だけ直すと食い違う。直すときは両方を見ること。
function Icor_planner_refresh_target_row(t)
    local frame = ui.GetFrame(addon_name_lower .. g.icor_planner_frame_name)
    if frame == nil then
        return
    end
    local key = tostring(t.id or 0)
    local is_slot = (Icor_planner_target_mode(t) == g.icor_planner_mode_slot)
    local cur = GET_CHILD_RECURSIVELY(frame, "tc_" .. key)
    local slot_want = 0
    if cur ~= nil then
        AUTO_CAST(cur)
        if is_slot then
            local have, want, max_count = Icor_planner_slot_progress(t)
            slot_want = want
            Icor_planner_slot_text(cur, have, want, max_count)
        else
            cur:SetText("{ol}{s15}{#FFFFFF}" .. Icor_planner_value_text(t.opt, Icor_planner_current(t.opt)))
        end
    elseif is_slot then
        local _, want = Icor_planner_slot_progress(t)
        slot_want = want
    end
    local percent = GET_CHILD_RECURSIVELY(frame, "tp_" .. key)
    if percent ~= nil then
        AUTO_CAST(percent)
        Icor_planner_set_target_percent(percent, t, is_slot, slot_want)
    end
end

function Icor_planner_preset_rename(parent, ctrl)
    AUTO_CAST(ctrl)
    local preset = Icor_planner_cur_preset()
    local text = ctrl:GetText()
    if preset and text and text ~= "" then
        preset.name = text
        Icor_planner_save_settings()
        Icor_planner_build_tab()
    end
end

function Icor_planner_preset_add()
    local presets = g.icor_planner_settings.presets
    presets[#presets + 1] = {
        name = string.format("%s %d", g.lang == "Japanese" and "目標" or "Target", #presets + 1),
        targets = {}
    }
    Icor_planner_set_preset(#presets)
    Icor_planner_build_tab()
end

function Icor_planner_preset_delete()
    local presets = g.icor_planner_settings.presets
    if #presets <= 1 then
        ui.SysMsg(g.lang == "Japanese" and "{ol}最後の 1 つは削除できません" or
                      "{ol}Cannot delete the last preset")
        return
    end
    local _, index = Icor_planner_cur_preset()
    table.remove(presets, index)
    Icor_planner_set_preset(math.min(index, #presets))
    Icor_planner_build_tab()
end

-- ===== 候補タブ(インベントリのイコル) =====
function Icor_planner_build_candidates(bg)
    Icor_planner_preset_droplist(bg, 10)
    local note = bg:CreateOrGetControl("richtext", "note", 10, 48, 0, 0)
    AUTO_CAST(note)
    note:SetText(g.lang == "Japanese" and
                     "{ol}{s14}{#AAAAAA}持っているイコルを、目標の不足をどれだけ埋められるかで並べます。{#9932CC}再{#AAAAAA} は再鑑定でその枠から目標に載る候補が出る割合" or
                     "{ol}{s14}{#AAAAAA}Your icors ranked by how much of the shortfall they cover")
    local list = bg:CreateOrGetControl("groupbox", "list", bg:GetWidth() - 20, bg:GetHeight() - 90, ui.LEFT, ui.TOP,
        10, 76, 0, 0)
    AUTO_CAST(list)
    list:SetSkinName("bg")
    list:EnableScrollBar(1)
    local diag = Icor_planner_diagnose()
    local rows = Icor_planner_inventory_icors(diag)
    if #rows == 0 then
        local empty = list:CreateOrGetControl("richtext", "empty", 10, 10, 0, 0)
        AUTO_CAST(empty)
        empty:SetText(g.lang == "Japanese" and "{ol}{s15}{#888888}インベントリにイコルがありません" or
                          "{ol}{s15}{#888888}No icor found in the inventory")
        return
    end
    local y = 6
    for i, row in ipairs(rows) do
        y = Icor_planner_render_candidate(list, "c_" .. i, y, row, nil, {
            rbtn = "Icor_planner_toggle_lock",
            arg_str = row.iesid,
            tooltip = g.lang == "Japanese" and
                "{ol}右クリック: このイコルの保護(ロック)を切り替える{nl}保護すると売却や分解で消えなくなります" or
                "{ol}Right click: toggle the item lock"
        })
    end
end

-- インベントリからイコルを集めて評価する。
-- **開いたとき(と再計算のとき)だけ走らせる。** 全件走査なので繰り返し呼ばない。
-- インベントリのイコルの保護(ロック)を切り替える。
--
-- **素の SendLockItem をそのまま呼ぶ。** 素のインベントリは「ロックモードに入って
-- スロットを押す」作りだが(INV_ITEM_LOCK_LBTN_CLICK)、こちらは対象が決まっているので
-- その手続きは要らない。送るのは素と同じ
-- session.inventory.SendLockItem(IESID, 1 = 保護 / 0 = 解除)。
function Icor_planner_toggle_lock(parent, ctrl, iesid)
    if iesid == nil or iesid == "" then
        return
    end
    local inv_item = Icor_planner_find_inv_by_iesid(iesid)
    if inv_item == nil then
        ui.SysMsg(g.lang == "Japanese" and "{ol}そのイコルが見つかりません" or "{ol}Item not found")
        return
    end
    local state = (inv_item.isLockState == true) and 0 or 1
    local ok = pcall(session.inventory.SendLockItem, iesid, state)
    if not ok then
        g.vlog("{#FF6347}icor_planner: SendLockItem に失敗した (%s){/}", tostring(iesid))
        return
    end
    g.vlog("icor_planner: 保護を %s にした (%s)", state == 1 and "ON" or "OFF", tostring(iesid))
    -- **送っただけでは手元の isLockState はまだ変わらない**(サーバの返事を待つ)ので、
    -- 少し置いてから作り直す。その場で組み直すと押す前の状態がそのまま出る
    local frame = ui.GetFrame(addon_name_lower .. g.icor_planner_frame_name)
    if frame then
        frame:RunUpdateScript("Icor_planner_refresh_after_lock", 0.4)
    end
end

function Icor_planner_refresh_after_lock(frame)
    frame:StopUpdateScript("Icor_planner_refresh_after_lock")
    Icor_planner_build_tab()
    return 0
end

function Icor_planner_find_inv_by_iesid(iesid)
    local inv_list = session.GetInvItemList()
    if inv_list == nil then
        return nil
    end
    local guid_list = inv_list:GetGuidList()
    for i = 0, guid_list:Count() - 1 do
        local inv_item = inv_list:GetItemByGuid(guid_list:Get(i))
        if inv_item ~= nil and inv_item:GetIESID() == iesid then
            return inv_item
        end
    end
    return nil
end

function Icor_planner_inventory_icors(diag)
    local rows = {}
    local inv_list = session.GetInvItemList()
    if inv_list == nil then
        return rows
    end
    local guid_list = inv_list:GetGuidList()
    local count = guid_list:Count()
    for i = 0, count - 1 do
        local guid = guid_list:Get(i)
        local inv_item = inv_list:GetItemByGuid(guid)
        if inv_item ~= nil then
            local item_obj = GetIES(inv_item:GetObject())
            if item_obj ~= nil and TryGetProp(item_obj, "GroupName", "None") == "Icor" then
                -- 保護(ロック)されているものは名前の前に印を出す。**どれを残すつもりか**が
                -- 一覧の上で分かるようにするため
                local locked = (inv_item.isLockState == true)
                rows[#rows + 1] = {
                    iesid = inv_item:GetIESID(),
                    locked = locked,
                    name = (locked and "{#FFD700}[保護]{/} " or "") ..
                               dictionary.ReplaceDicIDInCompStr(TryGetProp(item_obj, "Name", "")),
                    item_obj = item_obj,
                    score = Icor_planner_evaluate(item_obj, diag)
                }
            end
        end
    end
    table.sort(rows, function(a, b)
        local better = Icor_planner_candidate_better(a, b)
        if better ~= nil then
            return better
        end
        return a.name < b.name
    end)
    return rows
end

