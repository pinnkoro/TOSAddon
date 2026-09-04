-- アイテム破片化(素の fragmentation フレーム)の拡張。
--
-- やっていることは 3 つ。
--   1. スロットを 5x5 から利用者が決めた列 x 行へ増やす
--   2. 耳飾りタブの等級フィルタを 1〜7 等級と「8 等級以上」の 8 個へ細かくする
--   3. 「最大 Lv」(特殊オプション 3 つのうち一番高いレベル)でも絞れるようにする
--
-- **素の関数を書き写していない**(CLAUDE.md「素の関数を書き写さない」)。
-- 素の FRAGMENTATION_SHOW_TARGETS_APPLY_FILTER / _NO_APPLY_FILTER はどちらも
-- shared_item_earring.is_able_to_fragmetation を通してから並べるので、**素を呼んでいる
-- 同期実行の間だけこの関数を横取りして**、自分のフィルタで落とす形にしてある
-- (context_menu.lua の ui.AddContextMenuItem 横取りと同じ考え方)。
-- こうすると並べる処理そのものは素のままなので、IMC が置き方を変えても付いていける。
--
-- 素の等級フィルタ(argList)を使わない理由: 素は argList の値と完全一致で判定し、
-- **4 だけ「4 以上」の特例**になっている。5 等級以上を足すと「4 等級ちょうど」を
-- 表せないので、こちらが有効なときは argList を空にして
-- (= 素はフィルタ無しの経路へ入る)判定を全部 is_able_to_fragmetation 側へ寄せている。

-- **この入れ物 1 つだけを local にすること。** mini_addons は do ... end の中身が
-- まるごとメインチャンクの直下に並ぶので、ファイルごとに local を増やすと
-- Lua の「1 関数あたり local 200 個」に当たってバンドル全体が読めなくなる
-- (実際にこのファイルで越えた)。定数も補助関数もここへぶら下げる。
local frag = {}

frag.FRAME = "fragmentation"
frag.SPC = 2 -- 素の slotset の spc(XML の spc="2 2")
frag.SLOT_MAX = 82 -- 素のスロットの大きさ。これより大きくはしない
frag.SLOT_MIN = 24 -- これ以上小さくすると絵が潰れて選べなくなる
frag.COL_MAX = 10
frag.ROW_MAX = 10
frag.COL_DEF = 5
frag.ROW_DEF = 5
frag.GRADE_CNT = 8 -- 8 個目は「8 等級以上」
frag.MAXLV_CNT = 5 -- 特殊オプションのレベルは 1〜5
frag.FILTER_H = 74 -- 自前のフィルタ 2 行(等級 / 最大Lv)ぶんの高さ
frag.ROW_H = 34
frag.GROUP = "nexus_p_frag_filter"

-- 素の窓の寸法。**実物から控える**(XML の数値を書き写すと、IMC が窓を変えたときに
-- こちらだけ古い前提で計算し続けることになる)。控えるのは 1 回だけ。
frag.base = nil
-- 素の shared_item_earring.MAX_SLOT_CNT。機能を OFF にしたときに戻す
frag.base_max_slot = nil

function frag.lang(jp, kr, en)
    if g.lang == "Japanese" then
        return jp
    elseif g.lang == "kr" then
        return kr
    end
    return en
end

function frag.clamp(value, low, high)
    value = tonumber(value) or low
    value = math.floor(value)
    if value < low then
        return low
    elseif value > high then
        return high
    end
    return value
end

-- 設定が有効か。既定は OFF なので、触っていない利用者には何も起きない
function frag.enabled()
    local cfg = g.settings and g.settings.fragmentation
    return cfg ~= nil and cfg.use == 1
end

function frag.col_row()
    local cfg = (g.settings and g.settings.fragmentation) or {}
    return frag.clamp(cfg.col or frag.COL_DEF, 1, frag.COL_MAX), frag.clamp(cfg.row or frag.ROW_DEF, 1, frag.ROW_MAX)
end

-- 素の窓の基準寸法を控える。**1 回だけ**(2 回目以降に控えると、こちらが広げた後の
-- 値を基準にしてしまい、開くたびに窓が伸び続ける)
function frag.capture_base(frame, main_bg, center_bg, slotset, filter_box)
    if frag.base then
        return true
    end
    if not (frame and main_bg and center_bg and slotset and filter_box) then
        return false
    end
    frag.base = {
        frame_h = frame:GetHeight(),
        main_h = main_bg:GetHeight(),
        center_h = center_bg:GetHeight(),
        center_w = center_bg:GetWidth(),
        -- スロットの上端(センター枠の中での位置)。ここより上はタブの領域なので詰めない
        slot_top = slotset:GetY(),
        -- 素のフィルタ枠の上端から下(実行ボタン込み)に要る高さ
        bottom = main_bg:GetHeight() - filter_box:GetY(),
        col = slotset:GetCol(),
        row = slotset:GetRow()
    }
    -- 素のスロットの大きさは getter が無いので、今の幅と列数から割り出す
    local slot = math.floor(slotset:GetWidth() / math.max(1, frag.base.col)) - frag.SPC
    if slot < frag.SLOT_MIN or slot > frag.SLOT_MAX then
        slot = frag.SLOT_MAX
    end
    frag.base.slot = slot
    core_g.vlog("mini_addons: 破片化 素の寸法 frame=%d main=%d center=%d slot_top=%d bottom=%d %dx%d slot=%d",
        frag.base.frame_h, frag.base.main_h, frag.base.center_h, frag.base.slot_top, frag.base.bottom, frag.base.col,
        frag.base.row, frag.base.slot)
    return true
end

-- 窓の高さとスロットの大きさを決める。
-- **窓は画面に収まる範囲でだけ伸ばし、それでも入らないぶんはスロットを縮める。**
-- 伸ばすだけにすると 1080p では 1 行も増やせず、縮めるだけにすると既定の 5x5 でも
-- 小さくなってしまうため、両方を組み合わせている。
function frag.geometry(col, row)
    local base = frag.base
    local want_h = row * (frag.SLOT_MAX + frag.SPC) + base.slot_top + frag.FILTER_H + 5 + base.bottom
    local room = ui.GetClientInitialHeight() - 60 - base.frame_h
    local extra = math.max(0, math.min(math.max(0, room), want_h - base.main_h))
    -- 自前のフィルタ行の上端 = スロットに使える下限
    local filter_top = (base.main_h + extra - base.bottom) - frag.FILTER_H - 5
    local avail_h = filter_top - base.slot_top
    local avail_w = base.center_w - 12
    local slot = math.min(frag.SLOT_MAX, math.floor(avail_w / col) - frag.SPC, math.floor(avail_h / row) - frag.SPC)
    slot = frag.clamp(slot, frag.SLOT_MIN, frag.SLOT_MAX)
    return extra, slot, filter_top
end

-- 等級 / 最大 Lv のチェックボックスを作る(既に在れば取り直すだけ)。
-- 置き場所は素の filter_box ではなく main_bg。素の枠の中に行を足すと、素が
-- 下端合わせで並べている 5 タブぶんのフィルタが全部ずれるため。
--
-- **行の頭に「等級」「最大Lv」を出し、チェックボックスは数字だけにする。**
-- 1 つずつ「1等級」「2等級」と書くと 8 個が 1 行に入らず 2 段になり、
-- 縦に食われたぶんスロットが小さくなる。何の数字かは行の見出しとツールチップで示す。
function frag.build_filter(main_bg, filter_top)
    local group = main_bg:CreateOrGetControl("groupbox", frag.GROUP, 45, filter_top, 520, frag.FILTER_H)
    AUTO_CAST(group)
    group:SetSkinName("None")
    local grade_label = group:CreateOrGetControl("richtext", "nexus_p_frag_grade_text", 0, 4, 65, 25)
    AUTO_CAST(grade_label)
    grade_label:SetText("{ol}" .. frag.lang("等級", "등급", "Grade"))
    local grade_tip = frag.lang("{ol}等級 = 特殊オプション 3 つのレベル合計",
        "{ol}등급 = 특수 옵션 3 개의 레벨 합계", "{ol}Grade = total of the three special option levels")
    for i = 1, frag.GRADE_CNT do
        local cb = group:CreateOrGetControl("checkbox", "nexus_p_frag_grade_" .. i, 70 + (i - 1) * 47, 0, 25, 25)
        AUTO_CAST(cb)
        -- 最後の 1 つだけは「以上」まで書く(数字だけだと 8 等級ちょうどに見えるため)
        if i == frag.GRADE_CNT then
            cb:SetText("{ol}" .. frag.lang(i .. "以上", i .. " 이상", i .. "+"))
        else
            cb:SetText("{ol}" .. i)
        end
        cb:SetTextTooltip(grade_tip)
        cb:SetEventScript(ui.LBUTTONUP, "Mini_addons_frag_check")
    end
    local maxlv_label = group:CreateOrGetControl("richtext", "nexus_p_frag_maxlv_text", 0, frag.ROW_H + 4, 65, 25)
    AUTO_CAST(maxlv_label)
    maxlv_label:SetText("{ol}" .. frag.lang("最大Lv", "최대 Lv", "Max Lv"))
    local maxlv_tip = frag.lang("{ol}最大Lv = 特殊オプション 3 つのうち一番高いレベル",
        "{ol}최대 Lv = 특수 옵션 3 개 중 가장 높은 레벨",
        "{ol}Max Lv = highest of the three special option levels")
    for i = 1, frag.MAXLV_CNT do
        local cb = group:CreateOrGetControl("checkbox", "nexus_p_frag_maxlv_" .. i, 70 + (i - 1) * 47, frag.ROW_H, 25,
            25)
        AUTO_CAST(cb)
        cb:SetText("{ol}" .. i)
        cb:SetTextTooltip(maxlv_tip)
        cb:SetEventScript(ui.LBUTTONUP, "Mini_addons_frag_check")
    end
    return group
end

-- 自前フィルタの選択状態。1 つも選ばれていなければ nil(= 絞らない)を返す
function frag.filter_state(frame)
    local group = GET_CHILD_RECURSIVELY(frame, frag.GROUP)
    if not group then
        return nil
    end
    local grade, maxlv = {}, {}
    local grade_on, maxlv_on = false, false
    for i = 1, frag.GRADE_CNT do
        local cb = GET_CHILD_RECURSIVELY(group, "nexus_p_frag_grade_" .. i)
        if cb and cb:IsChecked() == 1 then
            grade[i] = true
            grade_on = true
        end
    end
    for i = 1, frag.MAXLV_CNT do
        local cb = GET_CHILD_RECURSIVELY(group, "nexus_p_frag_maxlv_" .. i)
        if cb and cb:IsChecked() == 1 then
            maxlv[i] = true
            maxlv_on = true
        end
    end
    if not grade_on and not maxlv_on then
        return nil
    end
    return {
        grade = grade,
        maxlv = maxlv,
        grade_on = grade_on,
        maxlv_on = maxlv_on
    }
end

-- 耳飾り 1 つが自前フィルタを通るか。
-- 等級は素と同じ「特殊オプションのレベル合計」、最大 Lv はその 3 つの最大値。
function frag.pass(obj, state)
    if TryGetProp(obj, "GroupName", "None") ~= "Earring" then
        return true -- 耳飾り以外は素の判定のまま
    end
    local lv = TryGetProp(obj, "ItemLv", 0)
    local cnt = shared_item_earring.get_max_special_option_count(lv)
    local total, top = 0, 0
    for i = 1, cnt do
        local value = TryGetProp(obj, "EarringSpecialOptionLevelValue_" .. i, 0)
        total = total + value
        if value > top then
            top = value
        end
    end
    if state.grade_on then
        local hit = false
        for i = 1, frag.GRADE_CNT do
            if state.grade[i] then
                if i == frag.GRADE_CNT then
                    hit = hit or total >= frag.GRADE_CNT
                else
                    hit = hit or total == i
                end
            end
        end
        if not hit then
            return false
        end
    end
    if state.maxlv_on and not state.maxlv[top] then
        return false
    end
    return true
end

-- 窓とスロットの寸法を実際に当てる。OFF のときは素の寸法へ戻す
function Mini_addons_frag_apply(frame)
    frame = frame or ui.GetFrame(frag.FRAME)
    if not frame then
        return
    end
    local main_bg = GET_CHILD_RECURSIVELY(frame, "main_bg")
    local center_bg = GET_CHILD_RECURSIVELY(frame, "center_bg")
    local slotset = GET_CHILD_RECURSIVELY(frame, "fragmentation_slotset", "ui::CSlotSet")
    local filter_box = GET_CHILD_RECURSIVELY(frame, "filter_box")
    if not frag.capture_base(frame, main_bg, center_bg, slotset, filter_box) then
        core_g.vlog("{#FF6347}mini_addons: 破片化のコントロールが見つからないので触らない{/}")
        return
    end
    AUTO_CAST(slotset)
    local col, row, extra, slot
    if frag.enabled() then
        col, row = frag.col_row()
        local filter_top
        extra, slot, filter_top = frag.geometry(col, row)
        local group = frag.build_filter(main_bg, filter_top)
        group:ShowWindow(0) -- 出すかどうかはタブに合わせて SET_FILTER_SECTION 側で決める
        if frag.base_max_slot == nil then
            frag.base_max_slot = shared_item_earring.MAX_SLOT_CNT
        end
        -- **機能 OFF の後始末(Mini_addons_teardown)ではここを戻さない。** 戻すのは
        -- 枠を 5x5 へ畳むのと対で、枠が広いまま上限だけ 25 に戻ると素の実行ボタンが
        -- 「何もせず戻る」状態になる。畳むのはこの関数(= 窓を開き直したとき)だけにする。
        -- 素の実行ボタンは MAX_SLOT_CNT を上限に見て、超えていると**何もせず戻る**。
        -- 見えているスロットぶんを実行できるよう、こちらの枚数へ合わせる
        shared_item_earring.MAX_SLOT_CNT = col * row
    else
        col, row, extra, slot = frag.base.col, frag.base.row, 0, frag.base.slot
        local group = GET_CHILD_RECURSIVELY(frame, frag.GROUP)
        if group then
            group:ShowWindow(0)
        end
        if frag.base_max_slot ~= nil then
            shared_item_earring.MAX_SLOT_CNT = frag.base_max_slot
        end
    end
    local slot_h = row * (slot + frag.SPC)
    frame:Resize(frame:GetWidth(), frag.base.frame_h + extra)
    main_bg:Resize(main_bg:GetWidth(), frag.base.main_h + extra)
    -- スロットは枠の中央に置かれるので、上端を素と同じ位置に保つには
    -- 「スロットの高さ + 上端 * 2」の枠にする
    center_bg:Resize(frag.base.center_w, slot_h + frag.base.slot_top * 2)
    slotset:SetSlotSize(slot, slot)
    slotset:SetColRow(col, row)
    slotset:SetMaxSelectionCount(col * row)
    slotset:RemoveAllChild()
    slotset:CreateSlots()
    core_g.vlog("mini_addons: 破片化 %dx%d slot=%d 窓+%d 上限=%d", col, row, slot, extra,
        shared_item_earring.MAX_SLOT_CNT)
    FRAGMENTATION_REFRESH_ALL(frame)
end

-- 設定を変えた直後に反映する(窓が開いていなければ次に開いたときに効く)
function Mini_addons_frag_reapply()
    local frame = ui.GetFrame(frag.FRAME)
    if not frame or frame:IsVisible() == 0 then
        return
    end
    local ok, err = pcall(Mini_addons_frag_apply, frame)
    if not ok then
        core_g.vlog("{#FF6347}mini_addons: 破片化の再適用 FAILED{/} %s", tostring(err))
    end
end

function Mini_addons_frag_check(parent, ctrl)
    local frame = ui.GetFrame(frag.FRAME)
    if frame then
        FRAGMENTATION_REFRESH_ALL(frame)
    end
end

-- 設定画面の「列」「行」入力
function frag.edit_apply(ctrl, key, def)
    local value = tonumber(ctrl:GetText())
    g.settings.fragmentation = g.settings.fragmentation or {}
    if value == nil or value < 1 or value > frag.COL_MAX then
        ui.SysMsg(frag.lang("無効な値です。1から" .. frag.COL_MAX .. "の間で設定してください。",
            "잘못된 값입니다. 1~" .. frag.COL_MAX .. " 사이로 설정해 주세요.",
            "Invalid value please set between 1 and " .. frag.COL_MAX))
        value = def
    end
    value = frag.clamp(value, 1, frag.COL_MAX)
    ctrl:SetText("{ol}" .. value)
    g.settings.fragmentation[key] = value
    Mini_addons_save_settings()
    Mini_addons_frag_reapply()
end

function Mini_addons_frag_col_edit(frame, ctrl)
    frag.edit_apply(ctrl, "col", frag.COL_DEF)
end

function Mini_addons_frag_row_edit(frame, ctrl)
    frag.edit_apply(ctrl, "row", frag.ROW_DEF)
end

-- ここから素のフック。いずれも「素を呼んでから加工」で、素の中身は写していない。

function Mini_addons_FRAGMENTATION_OPEN(frame)
    local origin = g.FUNCS["FRAGMENTATION_OPEN"]
    if origin then
        origin(frame)
    end
    local ok, err = pcall(Mini_addons_frag_apply, frame)
    if not ok then
        core_g.vlog("{#FF6347}mini_addons: 破片化の適用 FAILED{/} %s", tostring(err))
    end
end

-- 素はここで「どのフィルタ枠を出すか」を決め、argList を返す。
-- こちらが有効な耳飾りタブでは、素の等級チェックボックスを引っ込めて自前の行を出し、
-- **argList は空にする**(判定は is_able_to_fragmetation の横取り側で行う)。
function Mini_addons_FRAGMENTATION_SET_FILTER_SECTION(frame, tabindex)
    local origin = g.FUNCS["FRAGMENTATION_SET_FILTER_SECTION"]
    local argList = (origin and origin(frame, tabindex)) or {}
    if not frag.enabled() then
        return argList
    end
    local group = GET_CHILD_RECURSIVELY(frame, frag.GROUP)
    if not group then
        return argList
    end
    if tabindex == 0 then
        local vanilla = GET_CHILD_RECURSIVELY(frame, "filter_group_earring")
        if vanilla then
            vanilla:ShowWindow(0)
        end
        group:ShowWindow(1)
        return {}
    end
    group:ShowWindow(0)
    return argList
end

-- 素の並べ替え本体。**素をそのまま呼び**、その同期実行の間だけ
-- shared_item_earring.is_able_to_fragmetation を横取りして自前フィルタで落とす。
-- 横取りは pcall で失敗した経路も含めて必ず戻すこと(戻し忘れると、以降どの窓でも
-- 破片化の対象判定が壊れる)。
function Mini_addons_FRAGMENTATION_SHOW_TARGETS_FROM_INV(frame, tabindex, argList)
    local origin = g.FUNCS["FRAGMENTATION_SHOW_TARGETS_FROM_INV"]
    if not origin then
        return
    end
    local state = nil
    if frag.enabled() and tabindex == 0 and type(shared_item_earring) == "table" then
        state = frag.filter_state(frame)
    end
    if not state then
        return origin(frame, tabindex, argList)
    end
    local able = shared_item_earring.is_able_to_fragmetation
    if type(able) ~= "function" then
        return origin(frame, tabindex, argList)
    end
    shared_item_earring.is_able_to_fragmetation = function(item)
        if able(item) == false then
            return false
        end
        return frag.pass(item, state)
    end
    local ok, err = pcall(origin, frame, tabindex, argList)
    shared_item_earring.is_able_to_fragmetation = able
    if not ok then
        core_g.vlog("{#FF6347}mini_addons: 破片化の一覧作成 FAILED{/} %s", tostring(err))
    end
end

-- タブを切り替えたとき、素は自分のチェックボックスだけを外す。自前の行も外す
function Mini_addons_FRAGMENTATION_INIT_FILTER(ctrl)
    local origin = g.FUNCS["FRAGMENTATION_INIT_FILTER"]
    if origin then
        origin(ctrl)
    end
    local frame = ui.GetFrame(frag.FRAME)
    if not frame then
        return
    end
    local group = GET_CHILD_RECURSIVELY(frame, frag.GROUP)
    if not group then
        return
    end
    for i = 1, frag.GRADE_CNT do
        local cb = GET_CHILD_RECURSIVELY(group, "nexus_p_frag_grade_" .. i)
        if cb and cb:IsChecked() == 1 then
            cb:SetCheck(0)
        end
    end
    for i = 1, frag.MAXLV_CNT do
        local cb = GET_CHILD_RECURSIVELY(group, "nexus_p_frag_maxlv_" .. i)
        if cb and cb:IsChecked() == 1 then
            cb:SetCheck(0)
        end
    end
end

-- 破片化に失敗したときのログ。**26 枚以上をまとめて送れるかはサーバー側の話で、
-- クライアントからは判断できない。** 枚数を増やした利用者が失敗したときに、
-- verbose_log.txt から切り分けられるようにここで 1 行残す。
function Mini_addons_FRAGMENTATION_BUNDLE_FAILED(frame, msg, str, num)
    if not frag.enabled() then
        return
    end
    local col, row = frag.col_row()
    core_g.vlog("{#FF6347}mini_addons: 破片化に失敗(枠 %dx%d = %d 枚に拡張中){/}", col, row, col * row)
end

-- フックを掛ける。素の fragmentation が居ないクライアント(改名など)では何もしない
function Mini_addons_frag_setup()
    if type(_G["FRAGMENTATION_OPEN"]) ~= "function" then
        core_g.vlog("mini_addons: FRAGMENTATION_OPEN が無いので破片化の拡張は掛けない")
        return
    end
    g.setup_hook(Mini_addons_FRAGMENTATION_OPEN, "FRAGMENTATION_OPEN")
    g.setup_hook(Mini_addons_FRAGMENTATION_SET_FILTER_SECTION, "FRAGMENTATION_SET_FILTER_SECTION")
    g.setup_hook(Mini_addons_FRAGMENTATION_SHOW_TARGETS_FROM_INV, "FRAGMENTATION_SHOW_TARGETS_FROM_INV")
    g.setup_hook(Mini_addons_FRAGMENTATION_INIT_FILTER, "FRAGMENTATION_INIT_FILTER")
    core_g.register_msg("FRAGMENTATION_BUNDLE_ITEMS_FAILED", "Mini_addons_FRAGMENTATION_BUNDLE_FAILED")
end
