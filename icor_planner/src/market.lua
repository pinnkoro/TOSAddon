-- Icor Planner: マーケットの横に出す評価パネル
--
-- **素の行(MARKET_DRAW_CTRLSET_EQUIP)には一切触らない。** あれは
-- market_favorite_rebuild が既に g.setup_hook_and_event で掴んでおり、控え(_REPLACE_)は
-- 素の関数 1 つにつき 1 本しか持てないので、重ねると先客が黙って落ちる(CLAUDE.md)。
-- こちらは session.market から出品一覧を自分で読み、自前のフレームへ並べるだけにする。
-- そのぶん market_favorite_rebuild の ON / OFF と無関係に動く。
g.icor_planner_market_frame = "icor_planner_market"

-- _nexus_addons_p フレームの更新スクリプトから 0.5 秒ごとに呼ばれる。
-- **ここでログを出さないこと。** 毎回出すと verbose_log が流れて肝心の行が埋もれる。
function Icor_planner_market_watch()
    if g.settings.icor_planner.use == 0 then
        Icor_planner_market_close()
        return 1
    end
    local market = ui.GetFrame("market")
    local visible = (market ~= nil and market:IsVisible() == 1)
    local panel = ui.GetFrame(addon_name_lower .. g.icor_planner_market_frame)
    if not visible then
        -- **マーケットが閉じたら一緒に畳む。** ゲーム側の窓に貼り付いているパネルなので
        -- ESC も横取りしない(横取りすると本来閉じるべき market が開いたまま残る)
        if panel then
            Icor_planner_market_close()
        end
        g.icor_planner_market_sig = nil
        -- **閉じた印はマーケットを閉じたら捨てる。** 残すと次にマーケットを開いたときも
        -- 自動で出なくなり、「設定は ON なのに出ない」になる
        g.icor_planner_market_hidden = nil
        return 1
    end
    -- マーケットが開いている間は、いつでも押せるボタンを「お気に入り」の隣へ出す
    Icor_planner_attach_market_btn()
    if not panel then
        -- 自動で開くのは設定が ON で、かつ利用者が × で閉じていないときだけ
        if g.icor_planner_settings.market_auto == 1 and not g.icor_planner_market_hidden then
            Icor_planner_market_open()
        end
        return 1
    end
    -- 出品一覧が入れ替わったときだけ組み直す。件数と先頭の GUID を「今の一覧の印」にする
    local sig = Icor_planner_market_signature()
    if sig ~= g.icor_planner_market_sig then
        g.icor_planner_market_sig = sig
        Icor_planner_market_fill()
    end
    return 1
end

function Icor_planner_market_signature()
    local ok, count = pcall(session.market.GetItemCount)
    if not ok or type(count) ~= "number" then
        return "none"
    end
    local head = ""
    if count > 0 then
        local ok_item, market_item = pcall(session.market.GetItemByIndex, 0)
        if ok_item and market_item ~= nil then
            local ok_obj, item_obj = pcall(GetIES, market_item:GetObject())
            if ok_obj and item_obj ~= nil then
                head = tostring(TryGetProp(item_obj, "ClassName", "")) .. ":" ..
                           tostring(TryGetProp(item_obj, "RandomOptionValue_1", 0))
            end
        end
    end
    return tostring(count) .. "/" .. head
end

function Icor_planner_market_open()
    local market = ui.GetFrame("market")
    if not market then
        return
    end
    local frame_name = addon_name_lower .. g.icor_planner_market_frame
    local panel = g.create_persistent_frame(frame_name)
    AUTO_CAST(panel)
    g.block_click_through(panel)
    local width, height = 470, market:GetHeight()
    -- マーケットの右隣。画面からはみ出すようなら左隣へ回す。
    -- **画面幅は ui.GetClientInitialWidth() で取る。** map フレームの幅は画面幅とは限らず、
    -- 以前これを使っていて右にはみ出したまま出ていた
    local screen_w = nil
    local ok_w, w = pcall(ui.GetClientInitialWidth)
    if ok_w and type(w) == "number" and w > 0 then
        screen_w = w
    end
    if screen_w == nil then
        local map_ui = ui.GetFrame("map")
        screen_w = (map_ui and map_ui:GetWidth()) or 1920
    end
    local x = market:GetX() + market:GetWidth()
    if x + width > screen_w then
        x = math.max(0, market:GetX() - width)
    end
    panel:SetPos(x, market:GetY())
    panel:Resize(width, height)
    panel:SetLayerLevel(market:GetLayerLevel())
    panel:SetTitleBarSkin("None")
    panel:SetSkinName("None")
    panel:RemoveAllChild()
    local big_bg = panel:CreateOrGetControl("groupbox", "big_bg", width, height, ui.LEFT, ui.TOP, 0, 0, 0, 0)
    AUTO_CAST(big_bg)
    big_bg:SetSkinName("test_frame_low")
    local title = big_bg:CreateOrGetControl("richtext", "title", 10, 10, 0, 0)
    AUTO_CAST(title)
    title:SetText("{@st43}{s18}Icor Planner{/}")
    title:EnableHitTest(false)
    -- マーケットを開いたままでも畳めるようにする。ESC は横取りしないので、
    -- 閉じる手段はこの × とマーケット側のボタンの 2 つ
    local close = big_bg:CreateOrGetControl("button", "close", 36, 36, ui.RIGHT, ui.TOP, 0, 8, 8, 0)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetClickSound("button_click_big")
    close:SetOverSound("button_over")
    close:SetAnimation("MouseOnAnim", "btn_mouseover")
    close:SetAnimation("MouseOffAnim", "btn_mouseoff")
    -- 閉じるのは離したとき(理由は window.lua の × と同じ)
    close:SetEventScript(ui.LBUTTONUP, "Icor_planner_market_hide")
    local drop = big_bg:CreateOrGetControl("droplist", "preset_drop", 250, 28, ui.LEFT, ui.TOP, 10, 38, 0, 0)
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
    drop:SetSelectedScp("Icor_planner_market_preset_select")
    drop:Invalidate()
    local open_btn = big_bg:CreateOrGetControl("button", "open_btn", 130, 28, ui.LEFT, ui.TOP, 270, 38, 0, 0)
    AUTO_CAST(open_btn)
    open_btn:SetSkinName("test_pvp_btn")
    open_btn:SetText(g.lang == "Japanese" and "{ol}{s15}診断を開く" or "{ol}{s15}Open planner")
    open_btn:SetEventScript(ui.LBUTTONUP, "Icor_planner_open")
    local sort_drop = big_bg:CreateOrGetControl("droplist", "sort_drop", 250, 26, ui.LEFT, ui.TOP, 10, 72, 0, 0)
    AUTO_CAST(sort_drop)
    sort_drop:SetSkinName("droplist_normal")
    sort_drop:EnableHitTest(1)
    sort_drop:SetTextAlign("center", "center")
    sort_drop:ClearItems()
    sort_drop:AddItem(0, g.lang == "Japanese" and "マーケットの並び順" or "Market order")
    sort_drop:AddItem(1, g.lang == "Japanese" and "評価順" or "By score")
    sort_drop:SelectItemByKey(g.icor_planner_settings.market_sort or 0)
    sort_drop:SetSelectedScp("Icor_planner_market_sort_select")
    sort_drop:Invalidate()
    local list = big_bg:CreateOrGetControl("groupbox", "list", width - 20, height - 144, ui.LEFT, ui.TOP, 10, 110, 0,
        0)
    AUTO_CAST(list)
    list:SetSkinName("bg")
    list:EnableScrollBar(1)
    panel:ShowWindow(1)
    -- **ESC スタックへ積まないこと。** ゲーム側の market に連動して開閉するパネルなので、
    -- ここで ESC を横取りすると本来閉じるべき market が開いたまま残る(CLAUDE.md)
    g.icor_planner_market_sig = nil
    Icor_planner_market_fill()
end

-- ===== 素の一覧の行を目立たせる =====
--
-- パネルの行を右クリックすると、素のマーケット一覧の対応する行を赤くする。
-- 一覧が長いと「パネルのこれは素のどれか」が分からないため。
--
-- **色を戻せるようにすること。** 素は行を作り直すときに色を設定し直すとは限らないので、
-- 付けた行を覚えておいて、次に付けるときと消すときに必ず白へ戻す。
-- 行の名前は素が付けている "ITEM_EQUIP_<添字>"(market.lua)。
g.icor_planner_market_mark_tone = "FFFF6347"

function Icor_planner_market_row_ctrl(index)
    local market = ui.GetFrame("market")
    if not market or index == nil then
        return nil
    end
    return GET_CHILD_RECURSIVELY(market, "ITEM_EQUIP_" .. index)
end

function Icor_planner_market_clear_mark()
    local ctrl = Icor_planner_market_row_ctrl(g.icor_planner_marked_index)
    if ctrl then
        local ok = pcall(function()
            AUTO_CAST(ctrl)
            ctrl:SetColorTone("FFFFFFFF")
        end)
        if not ok then
            g.vlog("{#FF6347}icor_planner: 行の色を戻せなかった (ITEM_EQUIP_%s){/}",
                tostring(g.icor_planner_marked_index))
        end
    end
    g.icor_planner_marked_index = nil
end

-- パネルの行の右クリックから呼ぶ。同じ行をもう一度押したら消す
function Icor_planner_market_mark(parent, ctrl, arg_str, index)
    local same = (g.icor_planner_marked_index == index)
    Icor_planner_market_clear_mark()
    if same then
        return
    end
    local row = Icor_planner_market_row_ctrl(index)
    if not row then
        ui.SysMsg(g.lang == "Japanese" and "{ol}素の一覧に対応する行が見つかりません" or
                      "{ol}Cannot find the matching row")
        return
    end
    local ok = pcall(function()
        AUTO_CAST(row)
        row:SetColorTone(g.icor_planner_market_mark_tone)
    end)
    if ok then
        g.icor_planner_marked_index = index
    else
        g.vlog("{#FF6347}icor_planner: 行に色を付けられなかった (ITEM_EQUIP_%s){/}", tostring(index))
    end
end

function Icor_planner_market_close()
    -- 閉じるときは印を消す。**残すと素の行が赤いまま**になる
    Icor_planner_market_clear_mark()
    ui.DestroyFrame(addon_name_lower .. g.icor_planner_market_frame)
end

-- パネルの × から呼ぶ。**「閉じた」印を立てて、0.5 秒後の見回りで開き直されないようにする。**
-- 印はマーケットを閉じたときに捨てるので、次に開けば設定どおりに戻る。
function Icor_planner_market_hide()
    g.icor_planner_market_hidden = true
    Icor_planner_market_close()
end

-- マーケットの「お気に入り」の隣に置くボタン。押すたびに出す / 畳むを切り替える
function Icor_planner_market_toggle()
    local panel = ui.GetFrame(addon_name_lower .. g.icor_planner_market_frame)
    if panel then
        Icor_planner_market_hide()
        return
    end
    g.icor_planner_market_hidden = nil
    Icor_planner_market_open()
end

-- **ボタン名には接頭辞を付けること。** 同じ market フレームへ market_favorite_rebuild も
-- ボタンを足しており、名前が被ると CreateOrGetControl が相手のものを掴んでイベントを
-- 書き換えてしまう(あちらの実装のコメントと同じ理由)。
g.icor_planner_market_btn_name = "icor_planner_market_btn"

function Icor_planner_attach_market_btn()
    local market = ui.GetFrame("market")
    if not market then
        return
    end
    local btn_name = addon_name_lower .. g.icor_planner_market_btn_name
    -- 「お気に入り」(market_favorite_rebuild)の隣へ置く。相手の内部には触らず、
    -- 名前で引いて位置だけ見る。
    --
    -- **名前は "market_favorite_rebuild_p_open_btn"。** あちらは自分のスコープで
    -- `local addon_name_lower = string.lower('MARKET_FAVORITE_REBUILD_P')` と
    -- 上書きしているので、こちらの addon_name_lower("_nexus_addons_p")で組み立てると
    -- 一致しない(実機でボタンが出なかった原因)。
    --
    -- **見つからなくても必ず作ること。** あちらがボタンを付けるのは OPEN_DLG_MARKET と
    -- 買/売モードの切り替えで、こちらの 0.5 秒ごとの見回りの方が先に来ることがある。
    -- 見つかるまで作らない作りにすると、名前が変わったときに永久に出なくなる。
    -- 既定位置はあちらの定位置(610,120 / 幅 100)の右隣にしてあるので、
    -- 先に置いても重ならない。
    local fav = GET_CHILD(market, "market_favorite_rebuild_p_open_btn")
    local x, y = 715, 120
    if fav then
        x = fav:GetX() + fav:GetWidth() + 5
        y = fav:GetY()
    elseif g.settings.market_favorite_rebuild ~= nil and g.settings.market_favorite_rebuild.use == 0 then
        -- あちらが OFF なら「お気に入り」は出ないので、その位置をこちらが使う。
        -- **単体版では判断材料が無い**(相手の設定を読めない)ので、既定位置のまま待つ。
        -- あちらが後からボタンを作れば、次の見回りで隣へ寄せ直す
        x = 610
    elseif not g.icor_planner_fav_missing_logged then
        -- あちらが ON なのに見つからない。名前が変わった可能性があるので 1 回だけ残す
        g.icor_planner_fav_missing_logged = true
        g.vlog("icor_planner: お気に入りボタンが見つからないので既定位置(%d,%d)へ置く", x, y)
    end
    local btn = market:CreateOrGetControl("button", btn_name, x, y, 120, 30)
    AUTO_CAST(btn)
    -- **毎回置き直す。** CreateOrGetControl は 2 度目以降は既存を返すだけで動かさないので、
    -- 一度ずれた位置に作られるとそのまま残る
    btn:SetOffset(x, y)
    btn:SetSkinName("tab2_btn")
    btn:SetText(g.lang == "Japanese" and "{@st66b18}イコル診断" or "{@st66b18}Icor Plan")
    btn:SetTextTooltip(g.lang == "Japanese" and
                           "{ol}目標に対する評価パネルを出す / 畳む{nl}目標は Icor Planner の窓で決めます" or
                           "{ol}Show / hide the Icor Planner panel")
    btn:SetEventScript(ui.LBUTTONUP, "Icor_planner_market_toggle")
    btn:ShowWindow(1)
end

function Icor_planner_remove_market_btn()
    local market = ui.GetFrame("market")
    if market then
        market:RemoveChild(addon_name_lower .. g.icor_planner_market_btn_name)
    end
end

function Icor_planner_market_preset_select(parent, ctrl)
    AUTO_CAST(ctrl)
    local key = tonumber(ctrl:GetSelItemKey())
    if key then
        Icor_planner_set_preset(key)
    end
    g.icor_planner_market_sig = nil
    Icor_planner_market_fill()
end

-- **切り替えたら組み直す。** 見回りは「出品一覧が変わったときだけ」組み直すので、
-- 印(sig)を捨てないと並びが変わらない
function Icor_planner_market_sort_select(parent, ctrl)
    AUTO_CAST(ctrl)
    local key = tonumber(ctrl:GetSelItemKey())
    if key then
        g.icor_planner_settings.market_sort = key
        Icor_planner_save_settings()
    end
    g.icor_planner_market_sig = nil
    Icor_planner_market_fill()
end

function Icor_planner_market_fill()
    local panel = ui.GetFrame(addon_name_lower .. g.icor_planner_market_frame)
    if not panel then
        return
    end
    local list = GET_CHILD_RECURSIVELY(panel, "list")
    if not list then
        return
    end
    AUTO_CAST(list)
    list:RemoveAllChild()
    -- 出品一覧が入れ替わると素の行も作り直されるので、印は持ち越さない
    g.icor_planner_marked_index = nil
    local diag, diag_scan = Icor_planner_diagnose()
    if #diag.rows == 0 and #diag.slot_rows == 0 then
        local empty = list:CreateOrGetControl("richtext", "empty", 10, 10, 0, 0)
        AUTO_CAST(empty)
        empty:SetText(g.lang == "Japanese" and
                          "{ol}{s15}{#FFA500}目標が未設定です{nl}{#AAAAAA}「診断を開く」から決めてください" or
                          "{ol}{s15}{#FFA500}No target set")
        return
    end
    local y_sets = Icor_planner_fill_set_buttons(list, diag, diag_scan)
    local y0 = Icor_planner_fill_search_buttons(list, diag, y_sets)
    local rows, unappraised = Icor_planner_market_rows(diag)
    local head = list:CreateOrGetControl("richtext", "head", 10, y0, 0, 0)
    AUTO_CAST(head)
    if #rows == 0 then
        head:SetText(g.lang == "Japanese" and
                         string.format("{ol}{s15}{#888888}この一覧に評価できるイコルはありません%s",
                unappraised > 0 and string.format("{nl}{#AAAAAA}(未鑑定 %d 件)", unappraised) or "") or
                         "{ol}{s15}{#888888}No appraised icor in this list")
        return
    end
    head:SetText(g.lang == "Japanese" and
                     string.format("{ol}{s15}{#AAAAAA}%d 件 / %s%s", #rows,
            (g.icor_planner_settings.market_sort == 1) and "1 部位ぶんの目安に対する割合が高い順" or
                "マーケットの並び順",
            unappraised > 0 and string.format("{nl}未鑑定 %d 件は評価できません", unappraised) or "") or
                     string.format("{ol}{s15}{#AAAAAA}%d listing(s)", #rows))
    local y = y0 + 38
    for i, row in ipairs(rows) do
        if i > 30 then
            -- 出品が多いときに全件ぶんのコントロールを作ると、一覧が入れ替わるたびに
            -- 引っかかる。並べ替えは全件で行い、出すのは上位だけにする
            break
        end
        y = Icor_planner_render_candidate(list, "m_" .. i, y, row, row.price or 0, {
            rbtn = "Icor_planner_market_mark",
            arg_num = row.index,
            tooltip = g.lang == "Japanese" and
                "{ol}右クリック: 素の一覧の対応する行を赤くする{nl}もう一度で消えます" or
                "{ol}Right click: highlight the matching row"
        })
    end
end

-- 「オススメの検索条件」ボタンを並べる。戻り値は次に描き始める y。
--
-- 目標のうち**まだ不足しているもの**を、不足の大きい順にボタンにする。押すと素の
-- 条件検索(optionGroupSet)へ 1 行足して、オプションと下限値を入れる。
-- 条件を入れたら**そのまま検索する**(素の MARKET_REQ_LIST)。押した本人の操作なので、
-- 通信を起こしてよい(実機で「押したら検索までしてほしい」と指摘された)。
function Icor_planner_fill_search_buttons(list, diag, base_y)
    base_y = base_y or 6
    local targets = {}
    local seen = {}
    -- 下限の候補を足す。**同じオプションは 1 つにまとめ、下限は小さい方を採る。**
    -- 目標タブで武器 / 防具に行を分けると同じ項目が 2 行あり、検索条件も 2 つ並んでいた。
    -- 検索の条件はオプション名と下限値だけで部位を持たないので、1 つにまとめる。
    -- 小さい方を採るのは、**武器と防具で 1 枚に載る値が違う**ため。大きい方(たいてい武器)に
    -- 合わせると、防具のイコルが検索に 1 件も出ない(実機で指摘された)
    local function add(opt, min_value, basis)
        min_value = math.ceil(tonumber(min_value) or 0)
        if min_value <= 0 then
            return
        end
        local found = seen[opt]
        if found ~= nil then
            if min_value < found.min_value then
                found.min_value = min_value
                found.basis = basis
            end
            return
        end
        -- 素の条件検索に無いオプションは出しても押せないので外す
        local ok, searchable = pcall(IS_MARKET_SEARCH_OPTION_GROUP, opt)
        if ok and searchable == true then
            local row = {
                opt = opt,
                min_value = min_value,
                basis = basis
            }
            seen[opt] = row
            targets[#targets + 1] = row
        end
    end
    -- 目標値を持たない行の下限。**目安ボタンと同じ「一番上の段」の最小値**。
    -- (以前は最大値の 9 割だったが、そこまでの品はなかなか出ないので最低値にした。実機で指摘された)。
    -- 部位が「両方」なら Icor_planner_top_range が武器と防具の**小さい方**を返すので、防具のイコルも拾える
    local function by_range(opt, spot)
        local min_value = Icor_planner_top_range(opt, spot or "both")
        return min_value, string.format("%s の最低値 %s", Icor_planner_spot_label(spot or "both"),
            GET_COMMAED_STRING(min_value))
    end
    -- **各部位に載せたい目標を先に出す。** 買うときに一番効くのはそちらで、
    -- 合計はどの部位が持っていてもよいぶん急がない
    for _, row in ipairs(diag.slot_rows) do
        if row.have < row.want then
            if (row.min_value or 0) > 0 then
                -- 目標タブで入れた 1 枠の最低値。これ以上のイコルが「目標を満たす」もの
                add(row.opt, row.min_value, string.format("目標タブの %s の値", Icor_planner_spot_label(row.spot)))
            else
                add(row.opt, by_range(row.opt, row.spot))
            end
        end
    end
    for _, row in ipairs(diag.rows) do
        if row.short > 0 then
            add(row.opt, by_range(row.opt, row.spot))
        end
    end
    if #targets == 0 then
        return base_y
    end
    local title = list:CreateOrGetControl("richtext", "search_title", 10, base_y, 0, 0)
    AUTO_CAST(title)
    title:SetText(g.lang == "Japanese" and
                      "{ol}{s15}{#FFD700}オススメの検索条件{#AAAAAA}(押すと条件を足して検索します)" or
                      "{ol}{s15}{#FFD700}Suggested search{#AAAAAA} (fills the search fields)")
    local y = base_y + 22
    for i, row in ipairs(targets) do
        if i > 6 then
            break
        end
        local min_value = row.min_value
        local btn = list:CreateOrGetControl("button", "sb_" .. i, list:GetWidth() - 40, 24, ui.LEFT, ui.TOP, 14, y, 0,
            0)
        AUTO_CAST(btn)
        btn:SetSkinName("test_pvp_btn")
        btn:SetTextAlign("left", "center")
        btn:SetText(string.format("{ol}{s14}%s  >= %s", Icor_planner_option_name(row.opt),
            GET_COMMAED_STRING(min_value)))
        btn:SetTextTooltip(g.lang == "Japanese" and
                               ("{ol}この条件を足して検索します{nl}{#AAAAAA}下限: " ..
                                   tostring(row.basis)) or
                               "{ol}Fills the market search with this option and minimum")
        btn:SetEventScript(ui.LBUTTONUP, "Icor_planner_market_search_fill")
        btn:SetEventScriptArgString(ui.LBUTTONUP, row.opt)
        btn:SetEventScriptArgNumber(ui.LBUTTONUP, min_value)
        y = y + 26
    end
    return y + 8
end

-- 素の条件検索へ 1 行足して、オプションと下限を入れる。
-- 手順は素の market.lua が保存済み条件を復元しているところと同じ
-- (MARKET_ADD_SEARCH_OPTION_GROUP -> groupList -> 値の一覧を作り直す -> nameList -> minEdit)。
function Icor_planner_market_search_fill(parent, ctrl, opt, min_value)
    local market = ui.GetFrame("market")
    if not market then
        return
    end
    local option_group_set = GET_CHILD_RECURSIVELY(market, "optionGroupSet")
    if option_group_set == nil or option_group_set:IsVisible() ~= 1 or
        market:GetUserValue("SELECTED_CATEGORY") ~= "OPTMisc" then
        -- **条件欄が出ていなければ「特殊装備強化素材」を開く。** イコルはこのカテゴリにあり、
        -- 条件検索の欄もカテゴリを選ばないと出ない。開き方は Market Favorite Rebuild と同じ
        -- (素の MARKET_CATEGORY_CLICK を forceOpen で呼ぶ)。
        --   reqList = false … 一覧の再取得(サーバへの問い合わせ)はしない。検索の実行は利用者に任せる
        --   forceOpen = true … 素が空の条件行を 1 つ足さない / 選択済みを押したときの「畳む」を通らない
        -- **既に開いていて条件欄も出ているときは押し直さない。** 押し直すと条件欄が作り直され、
        -- 先に入れた条件が消える(オススメを続けて押す使い方ができなくなる)
        local ok_open = pcall(function()
            local category_set = GET_CHILD_RECURSIVELY(market, "CATEGORY_OPTMisc")
            MARKET_CATEGORY_CLICK(category_set, GET_CHILD(category_set, "bgBox"), false, true)
        end)
        option_group_set = GET_CHILD_RECURSIVELY(market, "optionGroupSet")
        g.vlog("icor_planner: 特殊装備強化素材を開いた (成功 %s / 条件欄 %s)", tostring(ok_open),
            tostring(option_group_set ~= nil))
    end
    if option_group_set == nil or option_group_set:IsVisible() ~= 1 then
        ui.SysMsg(g.lang == "Japanese" and
                      "{ol}条件検索の欄を開けませんでした。「特殊装備強化素材」を選んでから押してください" or
                      "{ol}The option search area is not open")
        return
    end
    if Icor_planner_market_add_condition(option_group_set, opt, min_value) then
        Icor_planner_market_search_now(market)
    end
end

-- 素の検索を実行する。**素の関数へ渡すのはフレーム**(中で GetTopParentFrame している)。
-- 失敗しても握る(条件は入っているので、素の検索ボタンを押せば同じことができる)
function Icor_planner_market_search_now(market)
    local ok = pcall(MARKET_REQ_LIST, market)
    g.vlog("icor_planner: 検索を実行した (成功 %s)", tostring(ok))
    if not ok then
        ui.SysMsg(g.lang == "Japanese" and
                      "{ol}条件は入れました。検索はマーケットの検索ボタンを押してください" or
                      "{ol}Filled the conditions. Press the market search button")
    end
end

-- 条件欄へ 1 行足して、オプションと下限を入れる
function Icor_planner_market_add_condition(option_group_set, opt, min_value)
    local ok_group, is_group, group = pcall(IS_MARKET_SEARCH_OPTION_GROUP, opt)
    if not ok_group or is_group ~= true then
        return false
    end
    local ok = pcall(function()
        local select_set = MARKET_ADD_SEARCH_OPTION_GROUP(option_group_set)
        local group_list = GET_CHILD(select_set, "groupList")
        group_list:SelectItemByKey(group)
        MARKET_INIT_OPTION_GROUP_VALUE_DROPLIST(group_list:GetParent(), group_list)
        local name_list = GET_CHILD(select_set, "nameList")
        name_list:SelectItemByKey(opt)
        local min_edit = GET_CHILD_RECURSIVELY(select_set, "minEdit")
        if min_edit then
            min_edit:SetText(tostring(min_value))
        end
    end)
    if not ok then
        g.vlog("{#FF6347}icor_planner: 検索条件の書き込みに失敗した (%s){/}", tostring(opt))
        return false
    end
    g.vlog("icor_planner: 検索条件を入れた %s >= %s", tostring(opt), tostring(min_value))
    return true
end

-- ===== オススメのセットで探す =====
--
-- 診断タブの「オススメのイコル構成」のイコル 1 個ぶんのセットを、マーケットの条件検索へ
-- **まとめて**入れる(カテゴリ「特殊装備強化素材」と、武器 / 防具のサブカテゴリも選ぶ)。
-- 下限は 最低 / 平均 の 2 通りから選べる(Icor_planner_set_min)。
function Icor_planner_fill_set_buttons(list, diag, scan)
    local jp = g.lang == "Japanese"
    g.icor_planner_market_sets = {}
    if scan == nil then
        return 6
    end
    local avg = Icor_planner_recommend(diag, scan, "avg")
    local y = 6
    local any = false
    for _, spot in ipairs({"Weapon", "Armor"}) do
        for k, set in ipairs(avg.types[spot].sets or {}) do
            if not any then
                local title = list:CreateOrGetControl("richtext", "set_title", 10, y, 0, 0)
                AUTO_CAST(title)
                title:SetText(jp and
                                  string.format("{ol}{s15}{#FFD700}%s{#AAAAAA}(押すとまとめて検索します)",
                        avg.update_mode and "更新するイコルのセットで探す" or "オススメのセットで探す") or
                                  "{ol}{s15}{#FFD700}Search by suggested set")
                y = y + 22
                any = true
            end
            local idx = #g.icor_planner_market_sets + 1
            local entry = {
                spot = spot,
                opts = set.opts,
                mins = {
                    min = {},
                    avg = {}
                }
            }
            for _, opt in ipairs(set.opts) do
                entry.mins.avg[opt] = Icor_planner_set_min(avg, opt, spot, "avg")
                entry.mins.min[opt] = Icor_planner_set_min(avg, opt, spot, "min")
            end
            g.icor_planner_market_sets[idx] = entry
            -- **縮めずに折り返す**(長いセットだけ読めない大きさになっていた。実機で指摘された)。
            -- ボタンは 1 行目の右に置き、次のセットは折り返した行の下から始める
            local names = {}
            for _, opt in ipairs(set.opts) do
                names[#names + 1] = (g.icor_planner_group_color[Icor_planner_group_of(opt)] or "{#FFFFFF}") ..
                                        Icor_planner_option_name(opt)
            end
            local row_y = y
            local next_y = Icor_planner_flow(list, "set_text_" .. idx, 14, y + 4, list:GetWidth() - 160,
                string.format("{#FFFFFF}%s ×%d :", Icor_planner_spot_label(spot), set.count), names, "{ol}{s14}", 22)
            local tips = {}
            for _, opt in ipairs(set.opts) do
                tips[#tips + 1] = string.format("%s  最低 >= %s / 平均 >= %s", Icor_planner_option_name(opt),
                    GET_COMMAED_STRING(entry.mins.min[opt]), GET_COMMAED_STRING(entry.mins.avg[opt]))
            end
            for n, key in ipairs({"min", "avg"}) do
                local btn = list:CreateOrGetControl("button", "set_btn_" .. idx .. "_" .. key, 56, 24, ui.LEFT, ui.TOP,
                    list:GetWidth() - 150 + (n - 1) * 60, row_y, 0, 0)
                AUTO_CAST(btn)
                btn:SetSkinName("test_pvp_btn")
                btn:SetText("{ol}{s13}" .. (key == "avg" and (jp and "平均" or "Avg") or (jp and "最低" or "Min")))
                btn:SetTextTooltip("{ol}" .. (jp and "この条件でまとめて検索します(今の条件は消えます){nl}" or "") ..
                                       table.concat(tips, "{nl}"))
                btn:SetEventScript(ui.LBUTTONUP, "Icor_planner_market_search_set")
                btn:SetEventScriptArgString(ui.LBUTTONUP, key)
                btn:SetEventScriptArgNumber(ui.LBUTTONUP, idx)
            end
            y = math.max(next_y, row_y + 28) + 4
        end
    end
    return any and (y + 8) or 6
end

function Icor_planner_market_search_set(parent, ctrl, key, idx)
    local set = g.icor_planner_market_sets and g.icor_planner_market_sets[idx]
    local market = ui.GetFrame("market")
    if set == nil or market == nil then
        return
    end
    -- **カテゴリから開き直して条件欄を空にする。** セットは 1 個のイコルの中身なので、
    -- 前に入れた条件が残っていると別の組み合わせで探してしまう
    local ok_open = pcall(function()
        local category_set = GET_CHILD_RECURSIVELY(market, "CATEGORY_OPTMisc")
        MARKET_CATEGORY_CLICK(category_set, GET_CHILD(category_set, "bgBox"), false, true)
        local sub = GET_CHILD_RECURSIVELY(market, "SUB_CATE_" .. (set.spot == "Weapon" and "GoddessIcorWeapon" or
            "GoddessIcorArmor"))
        if sub ~= nil then
            MARKET_SUB_CATEOGRY_CLICK(sub:GetParent(), sub, false)
        end
    end)
    local option_group_set = GET_CHILD_RECURSIVELY(market, "optionGroupSet")
    if not ok_open or option_group_set == nil then
        ui.SysMsg(g.lang == "Japanese" and "{ol}条件検索の欄を開けませんでした" or "{ol}Could not open the search area")
        return
    end
    local count = 0
    for _, opt in ipairs(set.opts) do
        if Icor_planner_market_add_condition(option_group_set, opt, set.mins[key][opt] or 0) then
            count = count + 1
        end
    end
    g.vlog("icor_planner: セットの条件を入れた %s %d/%d 件 (%s)", tostring(set.spot), count, #set.opts, tostring(key))
    if count > 0 then
        Icor_planner_market_search_now(market)
    end
end

-- 今マーケットに出ている一覧からイコルだけを拾って評価する。
-- 戻り値の 2 つ目は未鑑定の件数(オプションが決まっていないので評価できない)。
function Icor_planner_market_rows(diag)
    local rows, unappraised = {}, 0
    local ok, count = pcall(session.market.GetItemCount)
    if not ok or type(count) ~= "number" then
        return rows, unappraised
    end
    for i = 0, count - 1 do
        local ok_item, market_item = pcall(session.market.GetItemByIndex, i)
        if ok_item and market_item ~= nil then
            local item_obj = GetIES(market_item:GetObject())
            if item_obj ~= nil and TryGetProp(item_obj, "GroupName", "None") == "Icor" then
                if TryGetProp(item_obj, "NeedRandomOption", 0) == 1 then
                    -- 未鑑定。買ってから鑑定するまでオプションが決まらないので評価できない
                    unappraised = unappraised + 1
                else
                    local ok_price, price = pcall(function()
                        return market_item:GetSellPrice()
                    end)
                    rows[#rows + 1] = {
                        -- **素の一覧での添字**。行の名前 "ITEM_EQUIP_<添字>" を引くのに使う
                        index = i,
                        name = dictionary.ReplaceDicIDInCompStr(TryGetProp(item_obj, "Name", "")),
                        price = ok_price and tonumber(price) or 0,
                        item_obj = item_obj,
                        score = Icor_planner_evaluate(item_obj, diag)
                    }
                end
            end
        end
    end
    -- **既定はマーケットの並び順**(= session.market の添字順)。素の一覧と行が対応するので、
    -- パネルを見ながら素の行を押せる。並べ替えるのは「評価順」を選んだときだけ
    if g.icor_planner_settings.market_sort == 1 then
        table.sort(rows, function(a, b)
            local better = Icor_planner_candidate_better(a, b)
            if better ~= nil then
                return better
            end
            return (a.price or 0) < (b.price or 0)
        end)
    end
    return rows, unappraised
end
