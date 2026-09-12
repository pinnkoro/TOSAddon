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
frag.FILTER_H = 108 -- 見出し + 自前のフィルタ 3 行(等級 / 最大Lv / 枠)ぶんの高さ
-- 自前のフィルタ行を、素のフィルタ枠(filter_box)の上端からどれだけ下げるか。
-- 枠の上 50px は素の見出し(「フィルタ | 耳飾り」)が使っているので、その下へ置く。
-- **枠の外(上)へ出さないこと。** 見出しから離れて宙に浮いて見えるうえ、
-- スロットに使える高さもそのぶん削ることになる。
frag.FILTER_PAD = 2
-- 枠を広げたときの窓のレイヤー。**素の破片化は 81 で、クイックスロット(91)より下**。
-- 素の大きさ(5x5)なら画面下まで届かないので誰も困らないが、行を増やすと窓の下側
-- (自前のフィルタ行・素の「すべて選択」「破片へ変換」)がクイックスロットの裏に回る。
-- 95 は素のインベントリや倉庫と同じ値で、そこへ揃える(必要以上に持ち上げない)。
frag.LAYER = 95
frag.ROW_H = 27
frag.GROUP = "nexus_p_frag_filter"
-- 素の見出し(「フィルター | イヤリング」)の枠幅。素は 180px 固定で、韓国語の
-- 「필터 | 귀걸이」なら収まるが、**日本語だと入りきらず 2 行になる**。
-- richtext が fixwidth="true" resizebytext="true" なので、幅はそのままに高さだけ
-- 伸び、入れ物(filter_title は高さ 40)からはみ出して下の行に被る。広げて 1 行に収める
frag.TITLE_W = 320
frag.TITLE = "nexus_p_frag_title"
frag.TITLE_H = 26 -- 自前の見出しの高さ(1 行目はこの下から始まる)
frag.TITLE_BOX = "nexus_p_frag_title_box" -- 耳飾り以外のタブで、素の入れ物の中へ描く見出し
-- 見出しに出すアイテム名。**素が filter_title_text へ入れているのと同じ ClMsg のキー**
-- (素の FRAGMENTATION_SET_FILTER_SECTION がタブごとにこれを渡している)。
-- 訳は素から引くのでずれない。**知らないタブ(素にタブが増えた等)は素の見出しへ戻す**
frag.TAB_MSG = {
    [0] = "Earring",
    [1] = "Belt",
    [2] = "GemSkill",
    [3] = "Icor",
    [4] = "Shoulder"
}
-- 素の一覧更新。名前で持つ理由は Mini_addons_FRAGMENTATION_OPEN のコメント
frag.REFRESH = "FRAGMENTATION_REFRESH_ALL"

-- 素の窓の寸法。**実物から控える**(XML の数値を書き写すと、IMC が窓を変えたときに
-- こちらだけ古い前提で計算し続けることになる)。控えるのは 1 回だけ。
frag.base = nil
-- 素の shared_item_earring.MAX_SLOT_CNT。機能を OFF にしたときに戻す
frag.base_max_slot = nil
-- 素の窓へ手を入れたか。OFF のときに素へ戻すのは、これが真のときだけでよい
frag.applied = false

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

-- 続き(入り切らなかったぶん)の控えを手放す。**控えは 2 つで 1 組**なので、
-- 片方だけ消すと「選び直されたか」の判定が狂う。捨てるときは必ずここを通すこと
function frag.forget_pending()
    frag.pending, frag.pending_n = nil, nil
    frag.pending_kept, frag.pending_kept_n = nil, nil
end

-- 25 個ずつの続きを自動で実行するか。**既定は OFF**(設定画面の「自動」ボタン)。
-- 破片化は取り消せないので、押すのを省くかどうかは利用者に決めてもらう
function frag.auto_enabled()
    return g.settings.fragmentation ~= nil and g.settings.fragmentation.auto == 1
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
        row = slotset:GetRow(),
        layer = frame:GetLayerLevel()
    }
    -- 素のスロットの大きさ。**slotset の幅と列数から割り出してはいけない**
    -- (slotset の幅は XML の rect のままで spc を含まないことがあり、素の 82 に対して
    --  80 という 2px ずれた値が出る。範囲の見張りにも掛からないので黙って小さくなる)。
    -- スロット本体の幅がそのまま答えなので、そちらを読む。
    local slot = nil
    local first = slotset:GetSlotByIndex(0)
    if first then
        slot = first:GetWidth()
    end
    if slot == nil or slot < frag.SLOT_MIN or slot > frag.SLOT_MAX then
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
function frag.geometry(col, row, frame_y)
    local base = frag.base
    local avail_w = base.center_w - 12
    -- **先に「横で決まる大きさ」を出すこと。** 列を増やすとスロットは横幅で頭打ちになり、
    -- 10 列なら 56px まで小さくなる。ここを素の 82px で見積もると、窓だけが
    -- 10 行ぶん(= 260px 近く)余計に伸び、**スロットとフィルタ行の間が丸ごと空く**
    -- (実機で「全然詰まっていない」形で出た)。
    local slot_w = frag.clamp(math.floor(avail_w / col) - frag.SPC, frag.SLOT_MIN, frag.SLOT_MAX)
    local want_h = row * (slot_w + frag.SPC) + base.slot_top + 5 + base.bottom
    -- 伸ばしてよい量は「窓の下端が画面に収まる」まで。**窓の上端(frame_y)から数えること。**
    -- 画面の高さだけで決めていたとき、窓は上端が 25〜100 の位置にあるぶん画面の下から
    -- はみ出し、下側のボタンが見えなくなっていた
    local room = ui.GetClientInitialHeight() - (frame_y or 0) - base.frame_h - 20
    local extra = math.max(0, math.min(math.max(0, room), want_h - base.main_h))
    -- 素のフィルタ枠の上端。スロットはここより上に収める(自前の行は枠の中へ置くので、
    -- スロットに使える高さは素と同じ考え方のままでよい)
    local filter_area = base.main_h + extra - base.bottom
    local filter_top = filter_area + frag.FILTER_PAD
    local avail_h = filter_area - 5 - base.slot_top
    -- 画面に収まらず want_h まで伸ばせなかったときは、縦で更に小さくなる
    local slot = math.min(slot_w, math.floor(avail_h / row) - frag.SPC)
    slot = frag.clamp(slot, frag.SLOT_MIN, frag.SLOT_MAX)
    return extra, slot, filter_top
end

-- 見出しの文字列(「フィルター | イヤリング」)。素の書式(filter_title_text の format)に
-- 色と大きさを合わせてある。アイテム名は素と同じ ClMsg から引く
function frag.title_text(tabindex)
    local key = frag.TAB_MSG[tabindex or 0]
    if key == nil then
        return nil
    end
    return "{@st41}{s20}" .. frag.lang("フィルター", "필터", "Filter") .. "{/}{/} {@st66b}{s20}|{/}{/} {@st45ty}{s20}" ..
               tostring(ClMsg(key)) .. "{/}{/}"
end

-- 素の見出し(「フィルター | イヤリング」)が 2 行に折り返して下へはみ出すのを直す。
--
-- 素の filter_title_text は幅 180px の richtext で `fixwidth="true"`。韓国語
-- (「필터 | 귀걸이」)なら収まるが、**日本語はどのタブ名でも入りきらない**。
-- 高さだけ伸びて、入れ物(filter_title は高さ 40)からはみ出し下の行に被る。
--
-- **素の文字コントロールは直せない。** 試したことと結果:
--   * 文字を Resize で広げる → 効かない(指定 320 → 直後も 180x32。fixwidth のため)
--   * 入れ物ごと SetOffset で動かす → 見出しがどこにも出なくなった
--   * 入れ物は触らず、中の文字だけ隠して自前の richtext を重ねる → **これは効いた**
-- (入れ物の Resize は効く。計測で 箱=320x40 になっている)
--
-- そこで**素の文字だけを隠し、こちらで 1 行の見出しを描く**。耳飾りタブだけは
-- 3 行を 110px に収めるために見出しも自前の行の中へ入れるので、素の入れ物ごと隠す。
--
-- 知らないタブ(素にタブが増えた等)では素の見出しをそのまま出す。
function frag.own_title(frame, tabindex)
    local box = GET_CHILD_RECURSIVELY(frame, "filter_title")
    local origin_text = GET_CHILD_RECURSIVELY(frame, "filter_title_text")
    if not box or not origin_text then
        return
    end
    if frag.base_title_w == nil then
        frag.base_title_w = box:GetWidth()
    end
    local own = GET_CHILD_RECURSIVELY(box, frag.TITLE_BOX)
    local text = frag.enabled() and frag.title_text(tabindex) or nil
    -- 耳飾りタブは自前の行が見出しごと描くので、素の入れ物は丸ごと隠す。
    -- **ただし自前の行が在るときだけ。** 行を作るのは Mini_addons_frag_apply の
    -- capture_base が通ったときだけなので、失敗した経路で隠してしまうと
    -- 「素の見出しは消えているのに自前の見出しも無い」= 見出しが消える
    if frag.enabled() and tabindex == 0 and GET_CHILD_RECURSIVELY(frame, frag.GROUP) ~= nil then
        box:ShowWindow(0)
        return
    end
    box:ShowWindow(1)
    if text == nil then
        -- 機能が OFF / 知らないタブ。素へ戻す
        origin_text:ShowWindow(1)
        if own then
            own:ShowWindow(0)
        end
        box:Resize(frag.base_title_w, box:GetHeight())
        return
    end
    box:Resize(frag.TITLE_W, box:GetHeight())
    origin_text:ShowWindow(0)
    own = box:CreateOrGetControl("richtext", frag.TITLE_BOX, 0, 0, frag.TITLE_W, box:GetHeight())
    AUTO_CAST(own)
    own:SetOffset(0, 0)
    own:Resize(frag.TITLE_W, box:GetHeight())
    own:SetTextAlign("center", "center")
    own:SetText(text)
    own:ShowWindow(1)
end

-- 等級 / 最大 Lv のチェックボックスを作る(既に在れば取り直すだけ)。
-- 置き場所は素の filter_box ではなく main_bg。素の枠の中に行を足すと、素が
-- 下端合わせで並べている 5 タブぶんのフィルタが全部ずれるため。
--
-- **行の頭に「等級」「最大Lv」を出し、チェックボックスは数字だけにする。**
-- 1 つずつ「1等級」「2等級」と書くと 8 個が 1 行に入らず 2 段になり、
-- 縦に食われたぶんスロットが小さくなる。何の数字かは行の見出しとツールチップで示す。
function frag.build_filter(main_bg, filter_top)
    local group = main_bg:CreateOrGetControl("groupbox", frag.GROUP, 10, filter_top, 580, frag.FILTER_H)
    AUTO_CAST(group)
    -- **CreateOrGetControl は既にあるコントロールを置き直さない。** 行数を変えると
    -- filter_top が動くので、位置と大きさは毎回当て直すこと(でないと前回の位置に
    -- residue が残り、スロットと重なる)
    group:SetOffset(10, filter_top)
    group:Resize(580, frag.FILTER_H)
    group:SetSkinName("None")
    -- 見出し。素の filter_title は frag.own_title が隠すので、ここで丸ごと描く。
    -- 色と大きさは素の書式(filter_title_text の format)に合わせてある
    local title = group:CreateOrGetControl("richtext", frag.TITLE, 0, 0, 580, frag.TITLE_H)
    AUTO_CAST(title)
    title:SetOffset(0, 0)
    title:Resize(580, frag.TITLE_H)
    title:SetTextAlign("center", "center")
    title:SetText(frag.title_text(0) or "")
    -- 以下の行はすべて見出しの下から始める
    local top = frag.TITLE_H
    local grade_label = group:CreateOrGetControl("richtext", "nexus_p_frag_grade_text", 0, top + 4, 65, 25)
    AUTO_CAST(grade_label)
    grade_label:SetText("{ol}" .. frag.lang("等級", "등급", "Grade"))
    local grade_tip = frag.lang("{ol}等級 = 特殊オプション 3 つのレベル合計",
        "{ol}등급 = 특수 옵션 3 개의 레벨 합계", "{ol}Grade = total of the three special option levels")
    for i = 1, frag.GRADE_CNT do
        local cb = group:CreateOrGetControl("checkbox", "nexus_p_frag_grade_" .. i, 70 + (i - 1) * 47, top, 25, 25)
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
    local maxlv_label = group:CreateOrGetControl("richtext", "nexus_p_frag_maxlv_text", 0, top + frag.ROW_H + 4, 65, 25)
    AUTO_CAST(maxlv_label)
    maxlv_label:SetText("{ol}" .. frag.lang("最大Lv", "최대 Lv", "Max Lv"))
    local maxlv_tip = frag.lang("{ol}最大Lv = 特殊オプション 3 つのうち一番高いレベル",
        "{ol}최대 Lv = 특수 옵션 3 개 중 가장 높은 레벨",
        "{ol}Max Lv = highest of the three special option levels")
    for i = 1, frag.MAXLV_CNT do
        local cb = group:CreateOrGetControl("checkbox", "nexus_p_frag_maxlv_" .. i, 70 + (i - 1) * 47, top + frag.ROW_H, 25,
            25)
        AUTO_CAST(cb)
        cb:SetText("{ol}" .. i)
        cb:SetTextTooltip(maxlv_tip)
        cb:SetEventScript(ui.LBUTTONUP, "Mini_addons_frag_check")
    end
    -- **枠(X / Y)と「自動」を、この窓からも変えられるようにする。**
    -- 設定画面まで戻らずに、一覧を見ながら詰め方を決められるようにするため。
    -- 3 行目に置き、見出し(等級 / 最大Lv)と同じ位置へ「枠」を出して列を揃える
    local row3 = top + frag.ROW_H * 2
    local size_label = group:CreateOrGetControl("richtext", "nexus_p_frag_size_text", 0, row3 + 4, 65, 25)
    AUTO_CAST(size_label)
    size_label:SetOffset(0, row3 + 4)
    size_label:SetText("{ol}" .. frag.lang("枠", "칸", "Grid"))
    local size_tip = frag.lang("{ol}スロットの並べ方(横 x 縦)。1〜10{nl}Enter で確定します",
        "{ol}슬롯 배치(가로 x 세로). 1~10{nl}Enter 로 확정합니다",
        "{ol}Slot layout (columns x rows). 1-10{nl}Press Enter to apply")
    size_label:SetTextTooltip(size_tip)
    local col_edit = group:CreateOrGetControl("edit", "nexus_p_frag_col_edit", 70, row3, 40, 25)
    AUTO_CAST(col_edit)
    col_edit:SetOffset(70, row3)
    col_edit:SetEventScript(ui.ENTERKEY, "Mini_addons_frag_col_edit")
    col_edit:SetTextTooltip(size_tip)
    col_edit:SetFontName("white_16_ol")
    col_edit:SetTextAlign("center", "center")
    local x_label = group:CreateOrGetControl("richtext", "nexus_p_frag_x_text", 114, row3 + 4, 10, 25)
    AUTO_CAST(x_label)
    x_label:SetOffset(114, row3 + 4)
    x_label:SetText("{ol}x")
    local row_edit = group:CreateOrGetControl("edit", "nexus_p_frag_row_edit", 126, row3, 40, 25)
    AUTO_CAST(row_edit)
    row_edit:SetOffset(126, row3)
    row_edit:SetEventScript(ui.ENTERKEY, "Mini_addons_frag_row_edit")
    row_edit:SetTextTooltip(size_tip)
    row_edit:SetFontName("white_16_ol")
    row_edit:SetTextAlign("center", "center")
    local auto_tip = frag.lang(
        "{ol}一度に破片化できるのは 25 個までです{nl}ON にすると、残りを自動で選び直して続けて実行します{nl}(OFF のときは選び直しまで。実行は毎回ご自身で押します)",
        "{ol}한 번에 파편화할 수 있는 것은 25 개까지입니다{nl}ON 이면 남은 것을 자동으로 다시 선택해 이어서 실행합니다",
        "{ol}Only 25 items can be fragmented at once{nl}ON: automatically re-select and run the rest")
    local auto_label = group:CreateOrGetControl("richtext", "nexus_p_frag_auto_text", 182, row3 + 4, 40, 25)
    AUTO_CAST(auto_label)
    auto_label:SetOffset(182, row3 + 4)
    auto_label:SetText("{ol}" .. frag.lang("自動", "자동", "Auto"))
    auto_label:SetTextTooltip(auto_tip)
    local auto_btn = group:CreateOrGetControl("button", "nexus_p_frag_auto_btn", 226, row3 - 2, 52, 28)
    AUTO_CAST(auto_btn)
    auto_btn:SetOffset(226, row3 - 2)
    auto_btn:SetTextTooltip(auto_tip)
    auto_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_frag_auto_toggle")
    -- 値の当て込みは 1 か所へ寄せる(設定画面と食い違わないように)
    frag.sync_controls()
    -- 高度な選択(残す条件)への入口。押すと条件の窓が開く
    local keep_btn = group:CreateOrGetControl("button", "nexus_p_frag_keep_btn", 470, top + 2, 105, 30)
    AUTO_CAST(keep_btn)
    keep_btn:SetOffset(470, top + 2)
    keep_btn:SetSkinName("test_gray_button")
    keep_btn:SetText("{ol}" .. frag.lang("条件で選択", "조건으로 선택", "Select by rule"))
    keep_btn:SetTextTooltip(frag.lang(
        "{ol}残したい クラス / ランク / Lv を並べて、{nl}それに当てはまらない耳飾りだけを選択します",
        "{ol}남길 클래스 / 랭크 / Lv 를 나열하고,{nl}거기에 해당하지 않는 귀걸이만 선택합니다",
        "{ol}List the class / rank / Lv you want to keep,{nl}then select only the earrings that match none of them"))
    keep_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_frag_keep_open")
    local keep_count = group:CreateOrGetControl("richtext", "nexus_p_frag_keep_count", 470, top + frag.ROW_H + 4, 105, 25)
    AUTO_CAST(keep_count)
    keep_count:SetOffset(470, top + frag.ROW_H + 4)
    -- 文言は条件の窓と同じものを使う(frag.keep_count_text)。
    -- 数が変わったときの書き直しは frag.keep_update_count がまとめて行う
    keep_count:SetText(frag.keep_count_text())
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
    -- **一度も広げていないなら、素の窓には一切触らない。** 既定は OFF なので、
    -- 機能を使っていない利用者の窓が Resize / CreateSlots を通ることが無いようにする
    -- (素の見た目を変えないだけでなく、素が並べ終えたスロットを作り直さないため)。
    if not frag.enabled() and not frag.applied then
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
        extra, slot, filter_top = frag.geometry(col, row, frame:GetY())
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
        frame:SetLayerLevel(frag.LAYER)
        frag.applied = true
    else
        col, row, extra, slot = frag.base.col, frag.base.row, 0, frag.base.slot
        local group = GET_CHILD_RECURSIVELY(frame, frag.GROUP)
        if group then
            group:ShowWindow(0)
        end
        if frag.base_max_slot ~= nil then
            shared_item_earring.MAX_SLOT_CNT = frag.base_max_slot
        end
        frame:SetLayerLevel(frag.base.layer)
        -- **見出しはここで素へ戻すこと。** この後の FRAGMENTATION_REFRESH_ALL で走る
        -- Mini_addons_FRAGMENTATION_SET_FILTER_SECTION は「enabled か applied のとき」
        -- しか見出しに触らないが、その時点では既に両方 false なので一度も呼ばれない。
        -- 素の SET_FILTER_SECTION も SetTextByKey するだけで ShowWindow(1) はしないため、
        -- ここで戻さないと**隠した素の見出しがセッション中ずっと消えたまま**になる
        frag.own_title(frame, nil)
        frag.applied = false -- 素へ戻したので、次からはまた触らない
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
    core_g.vlog("mini_addons: 破片化 %dx%d slot=%d 窓+%d 上限=%d layer=%d", col, row, slot, extra,
        shared_item_earring.MAX_SLOT_CNT, frame:GetLayerLevel())
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
-- 入力欄へ数字を当て込む。**マークアップを混ぜないこと。**
-- `SetText("{ol}10")` と書くと、次に読んだとき GetText がそのまま "{ol}10" を返し、
-- tonumber が nil になる = 「無効な値」と見なして既定値へ戻してしまう
-- (実際に「5x5 にしたら 10x10 へ戻せない」形で出た)。
-- 縁取りは SetFontName("white_16_ol") が受け持つので、{ol} は元々要らない。
function frag.edit_set(ctrl, value)
    AUTO_CAST(ctrl)
    ctrl:SetText(tostring(value))
end

-- 入力欄から数字を読む。**読む側でもマークアップを落とす。**
-- 素や他のアドオンが {ol} 付きで入れた欄を後から読むことがあるため
function frag.read_number(ctrl)
    local raw = ctrl:GetText() or ""
    local plain = tostring(raw):gsub("{[^}]*}", "")
    if plain ~= raw then
        core_g.vlog("mini_addons: 破片化 入力欄の書式を落として読んだ raw=%s plain=%s", tostring(raw), plain)
    end
    return tonumber(plain)
end

-- 破片化の窓で今いくつ選ばれているか(窓が出ていなければ 0)
function frag.count_selected()
    local frame = ui.GetFrame(frag.FRAME)
    if not frame or frame:IsVisible() == 0 then
        return 0
    end
    local slotset = GET_CHILD_RECURSIVELY(frame, "fragmentation_slotset", "ui::CSlotSet")
    if not slotset then
        return 0
    end
    AUTO_CAST(slotset)
    local n = 0
    for i = 0, slotset:GetSlotCount() - 1 do
        local slot = slotset:GetSlotByIndex(i)
        if slot and slot:IsSelected() == 1 then
            n = n + 1
        end
    end
    return n
end

function frag.edit_apply(ctrl, key, def, high)
    local value = frag.read_number(ctrl)
    g.settings.fragmentation = g.settings.fragmentation or {}
    if value == nil then
        -- 数字として読めない。**既定へ飛ばさない**(読めなかっただけで今の設定を捨てると、
        -- 利用者から見ると「勝手に 5x5 へ戻された」になる)。今の値へ据え置く
        ui.SysMsg(frag.lang("無効な値です。1から" .. high .. "の間で設定してください。",
            "잘못된 값입니다. 1~" .. high .. " 사이로 설정해 주세요.",
            "Invalid value please set between 1 and " .. high))
        value = g.settings.fragmentation[key] or def
    elseif value < 1 or value > high then
        -- **範囲外は上限 / 下限へ丸める**(打ち直しを求めない)。
        -- 「11」と打った人が欲しいのは上限いっぱいであって、前の値ではない
        value = frag.clamp(value, 1, high)
        ui.SysMsg(frag.lang("1から" .. high .. "の間で設定できます。" .. value .. " にしました。",
            "1~" .. high .. " 사이로 설정할 수 있습니다. " .. value .. " 으로 했습니다.",
            "Only 1 to " .. high .. " is allowed - set to " .. value .. "."))
    end
    value = frag.clamp(value, 1, high)
    frag.edit_set(ctrl, value)
    -- **選択が消えることを黙って起こさない。** 枠を変えるとスロットを作り直すので、
    -- 選んでいたものは全部外れる(一覧の作り直しで frag.drop_stale_selection を通る)。
    -- 入力欄が破片化の窓の中にも在るので、選び終えてから触ってしまうことがある
    if value ~= (g.settings.fragmentation[key] or def) then
        local cleared = frag.count_selected()
        if cleared > 0 then
            ui.SysMsg(frag.lang("{ol}{#00BFFF}[Nexus Addons P] 枠を変えたので、選んでいた " .. cleared ..
                                    " 個の選択は解除されました",
                "{ol}{#00BFFF}[Nexus Addons P] 칸을 바꿨으므로 선택했던 " .. cleared .. " 개는 해제되었습니다",
                "{ol}{#00BFFF}[Nexus Addons P] Grid changed - the " .. cleared ..
                    " items you had selected were deselected"))
        end
    end
    g.settings.fragmentation[key] = value
    Mini_addons_save_settings()
    -- 設定画面と窓の両方へ当て直す(窓が開いていなければ次に開いたときに載る)
    frag.sync_controls()
    Mini_addons_frag_reapply()
end

-- 「自動」ボタンの見た目。**設定画面と破片化の窓の 2 か所にある**ので、
-- 文字とスキンの決め方はここへ寄せる(片方だけ直して食い違うのを防ぐ)
function Mini_addons_frag_auto_btn_apply(btn, on)
    AUTO_CAST(btn)
    btn:SetText(on and "{ol}{#FFFFFF}ON" or "{ol}{#FFFFFF}OFF")
    btn:SetSkinName(on and "test_pvp_btn" or "test_gray_button")
end

function frag.auto_btn_apply(btn, on)
    Mini_addons_frag_auto_btn_apply(btn, on)
end

-- 枠(X / Y)と「自動」は設定画面と破片化の窓のどちらからでも変えられる。
-- **開いている方を両方とも書き直す**(片方に古い値が残ると、次にそちらを触ったときに
-- 巻き戻る)。無い方は黙って飛ばす
function frag.sync_controls()
    local on = frag.auto_enabled()
    local col, row = frag.col_row()
    local setting = ui.GetFrame(addon_name_lower .. "setting")
    if setting then
        local btn = GET_CHILD_RECURSIVELY(setting, "fragmentation_auto_btn")
        if btn then
            frag.auto_btn_apply(btn, on)
        end
        local ce = GET_CHILD_RECURSIVELY(setting, "fragmentation_col_edit")
        if ce then
            frag.edit_set(ce, col)
        end
        local re = GET_CHILD_RECURSIVELY(setting, "fragmentation_row_edit")
        if re then
            frag.edit_set(re, row)
        end
    end
    local frame = ui.GetFrame(frag.FRAME)
    local group = frame and GET_CHILD_RECURSIVELY(frame, frag.GROUP)
    if group then
        local btn = GET_CHILD_RECURSIVELY(group, "nexus_p_frag_auto_btn")
        if btn then
            frag.auto_btn_apply(btn, on)
        end
        local ce = GET_CHILD_RECURSIVELY(group, "nexus_p_frag_col_edit")
        if ce then
            frag.edit_set(ce, col)
        end
        local re = GET_CHILD_RECURSIVELY(group, "nexus_p_frag_row_edit")
        if re then
            frag.edit_set(re, row)
        end
    end
end

-- 「自動」ボタン(25 個ずつの続きを自動で実行するか)。設定画面と破片化の窓の
-- 両方から同じ関数を呼ぶ
function Mini_addons_frag_auto_toggle(frame, ctrl)
    g.settings.fragmentation = g.settings.fragmentation or {}
    local on = (g.settings.fragmentation.auto == 1) and 0 or 1
    g.settings.fragmentation.auto = on
    Mini_addons_save_settings()
    frag.sync_controls()
    core_g.vlog("mini_addons: 破片化 続きの自動実行を %s にした", on == 1 and "ON" or "OFF")
end

function Mini_addons_frag_col_edit(frame, ctrl)
    frag.edit_apply(ctrl, "col", frag.COL_DEF, frag.COL_MAX)
end

function Mini_addons_frag_row_edit(frame, ctrl)
    frag.edit_apply(ctrl, "row", frag.ROW_DEF, frag.ROW_MAX)
end

-- ===== 高度な選択(残す条件) =====
--
-- 耳飾りの特殊オプションは「クラス / ランク(1〜3) / Lv(1〜5)」の 3 点セットが最大 3 つ。
-- **クラスごとに「この Lv 以上なら残す」を決め、どれにも当てはまらないものだけ選択する。**
-- 選ぶだけで、破片化そのものは今までどおり利用者が実行ボタンを押す。
--
-- 指定は **系統(ソードマン / ウィザード / …)のタブ + クラスごとの数字 3 つ**。
-- 「R1 / R2 / R3」の枠それぞれに最低 Lv を置き、**0 はその枠を使わない**。
-- ランクを 1 つしか指定できないと「R2 か R3 なら残す」が書けないので、
-- **ランクは 1〜3 を並べて置き、枠ごとに Lv を決める**形にしてある
-- (横に並べたので行の高さは変わらない)。以前は 1 行ずつ
-- 「系統 ▼ / クラス ▼ / ランク ▼ / Lv ▼」を選ぶ作りだったが、**残したいクラスを
-- 何個も足すのに droplist を 4 回ずつ開くことになり、実際に使うと重かった**。
--
-- 判定は「オプション 3 つのうち **1 つでも** 条件に合えば残す」。
-- 指定が 1 件も無いときは何もしない。**全部を選択してはいけない**
-- (「条件に合うものが無い = 全部破片化」になり、事故で全損させることになる)。

frag.KEEP_SUFFIX = "frag_keep"
frag.KEEP_LV_MAX = 5 -- 特殊オプションのレベルの上限(= frag.MAXLV_CNT)
frag.KEEP_RANK_MAX = 3 -- 特殊オプションのランクの上限(素の shared_item_earring と同じ 1〜3)
-- 1 クラスぶんの枠。r1〜r3 = そのランクのオプションだけを見る枠。
-- **この並びが画面の列の並びでもある**(header と keep_fill で使い回す)。
-- 「ランク不問」の枠は置いていない。3 つとも同じ Lv にすれば同じことになるうえ、
-- 枠が 1 つ増えると横も窮屈になるため(旧い設定の lv は 3 つへ配って移す)
frag.KEEP_FIELDS = {"r1", "r2", "r3"}
frag.KEEP_ROW_H = 28
-- 一度に見えるクラスの数。**1 列に並べてスクロールさせる。**
-- 2 列に折り返す作りにしていたが、系統によってクラスの数が違い(アーチャーは 27 個)、
-- 折り返しの数を決め打ちにすると 3 列目が窓の外へ出る。列を増やす方向で直すと
-- 系統が増えるたびに同じことが起きるので、1 列にしてスクロールで見る形にした
frag.KEEP_ROWS = 13
-- 今どのボタンから droplist を開いたか。ui.MakeDropListFrame のコールバックは
-- (index, keyword) しか受け取らないので、何を選んでいるのかはここで覚えておくしかない
frag.keep_edit = nil
-- 開いている系統のタブ(0 始まり)。窓を組み立て直しても戻れるように覚えておく
frag.keep_tab = 0

function frag.keep_frame_name()
    return addon_name_lower .. frag.KEEP_SUFFIX
end

-- 旧い形(1 行 = {ctrl, cls, rank, lv} の並び)からの引き継ぎ。
-- クラスを指定していた行だけ「クラス → Lv」へ移す。系統だけ / ランクだけの行は
-- 移しようがないので落とす(黙って落とさず、何件落としたかはログへ出す)。
function frag.keep_migrate(keep)
    -- 旧 1: 1 行 = {ctrl, cls, rank, lv} の並び。
    -- **ここで return しないこと。** この段の出力は {lv, rank} 止まりで、
    -- 今の形(r1〜r3)ではない。返してしまうと、その回だけ
    -- frag.keep_has_value / keep_count / keep_match が 1 件も拾えず
    -- (見ているのは frag.KEEP_FIELDS = r1〜r3 だけ)、「指定中 0 クラス」や
    -- 「残す条件がありません」になる。下の段へ流して最後まで変換する
    if type(keep[1]) == "table" then
        local moved, moved_n, dropped = {}, 0, 0
        for _, cond in ipairs(keep) do
            if type(cond) == "table" and cond.cls then
                local lv = tonumber(cond.lv) or 1
                local now = moved[cond.cls]
                if now == nil then
                    moved_n = moved_n + 1
                end
                -- 同じクラスが 2 行あったら緩い方(小さい Lv)を採る。厳しくすると
                -- 残すつもりだったものが破片化の対象に回るため
                if now == nil or lv < (now.lv or 0) then
                    moved[cond.cls] = {
                        lv = lv,
                        rank = tonumber(cond.rank)
                    }
                end
            else
                dropped = dropped + 1
            end
        end
        core_g.vlog("mini_addons: 破片化 残す条件を旧い形(行の並び)から移した(移動 %d / 落とした %d)", moved_n,
            dropped)
        keep = moved
    end
    -- 旧 2: クラス名 → 最低 Lv の数値。枠を足したので入れ物へ包み直す
    -- 旧 3: {lv, rank} の組。ランクを指定していたなら、その枠へ移す
    local wrapped, ranked = 0, 0
    for class_name, value in pairs(keep) do
        if type(value) == "number" then
            keep[class_name] = {
                lv = value
            }
            wrapped = wrapped + 1
        elseif type(value) == "table" and value.rank ~= nil then
            local rank = tonumber(value.rank) or 0
            if rank >= 1 and rank <= frag.KEEP_RANK_MAX then
                value["r" .. rank] = tonumber(value.lv) or 1
                value.lv = nil -- ランク不問の枠は空ける(そのままだと全ランクに当たる)
                ranked = ranked + 1
            end
            value.rank = nil
        end
    end
    -- 旧 4: ランク不問(lv)の枠。枠を無くしたので R1〜R3 へ同じ値を配る
    -- (「どのランクでも Lv N 以上」と同じ意味になる)。**黙って捨てないこと**:
    -- 捨てると、指定していたクラスが破片化の対象へ回る
    local spread = 0
    for _, value in pairs(keep) do
        if type(value) == "table" and value.lv ~= nil then
            local lv = tonumber(value.lv) or 0
            if lv > 0 then
                for r = 1, frag.KEEP_RANK_MAX do
                    local now = tonumber(value["r" .. r]) or 0
                    -- 既に入っている枠は緩い方(小さい Lv)を残す。厳しくすると
                    -- 残すつもりだったものが破片化の対象へ回るため
                    if now == 0 or lv < now then
                        value["r" .. r] = lv
                    end
                end
                spread = spread + 1
            end
            value.lv = nil
        end
    end
    if spread > 0 then
        core_g.vlog("mini_addons: 破片化 残す条件のランク不問を R1〜R3 へ配った(%d クラス)", spread)
    end
    if wrapped > 0 or ranked > 0 then
        core_g.vlog("mini_addons: 破片化 残す条件を旧い形から移した(数値 %d / ランク指定 %d)", wrapped, ranked)
    end
    return keep
end

-- クラス 1 つぶんの指定。無ければ作る(呼び出し側で nil を気にしないで済むように)
function frag.keep_want(keep, class_name)
    local want = keep[class_name]
    if type(want) ~= "table" then
        want = {
            lv = tonumber(want) or 0
        }
        keep[class_name] = want
    end
    return want
end

-- 枠 1 つの表示。0 は「使わない」
function frag.keep_field_value(want, field)
    if type(want) ~= "table" then
        return (field == "lv") and (tonumber(want) or 0) or 0
    end
    return tonumber(want[field]) or 0
end

-- 「クラス名 → 最低 Lv」の表。0 や未登録は対象外
function frag.keep_list()
    if not g.settings then
        return {}
    end
    -- **実体を返すこと。** 使い捨ての表を返すと、指定した Lv がどこにも残らない
    g.settings.fragmentation = g.settings.fragmentation or {}
    if type(g.settings.fragmentation.keep) ~= "table" then
        g.settings.fragmentation.keep = {}
    end
    g.settings.fragmentation.keep = frag.keep_migrate(g.settings.fragmentation.keep)
    return g.settings.fragmentation.keep
end

-- 指定しているクラスの数。**`#` で数えられない**(クラス名をキーにした表なので)
-- 何か 1 つでも Lv を入れているクラスの数
function frag.keep_has_value(want)
    if type(want) ~= "table" then
        return (tonumber(want) or 0) > 0
    end
    for _, field in ipairs(frag.KEEP_FIELDS) do
        if (tonumber(want[field]) or 0) > 0 then
            return true
        end
    end
    return false
end

function frag.keep_count(keep)
    local n = 0
    for _, want in pairs(keep or {}) do
        if frag.keep_has_value(want) then
            n = n + 1
        end
    end
    return n
end

-- クラス名(ClassName)から表示名。素のツールチップと同じ引き方をする
function frag.job_name(class_name)
    local cls = GetClass("Job", class_name)
    if not cls then
        return class_name
    end
    return dic.getTranslatedStr(TryGetProp(cls, "Name", class_name))
end

-- 系統(Warrior / Wizard / Archer / Cleric / Scout)。素の破片化のジェムフィルタと同じ引き方
function frag.base_jobs()
    local list = {}
    for i = 1, 5 do
        local cls = GetClassByStrProp("Job", "ClassName", "Char" .. i .. "_1")
        if cls then
            local ctrl = TryGetProp(cls, "CtrlType", "None")
            if ctrl ~= "None" then
                list[#list + 1] = {
                    key = ctrl,
                    name = dic.getTranslatedStr(TryGetProp(cls, "Name", ctrl))
                }
            end
        end
    end
    return list
end

-- 系統に属する上級クラス。素の shared_item_earring と同じ条件(有効な職業で Rank > 1)で拾う
function frag.class_list(ctrl)
    local list = {}
    local cls_list, cnt = GetClassList("Job")
    for i = 0, cnt - 1 do
        local cls = GetClassByIndexFromList(cls_list, i)
        if TryGetProp(cls, "EnableJob", "None") == "YES" and TryGetProp(cls, "Rank", 0) > 1 and
            TryGetProp(cls, "CtrlType", "None") == ctrl then
            local name = TryGetProp(cls, "ClassName", "None")
            if name ~= "None" then
                list[#list + 1] = {
                    key = name,
                    name = dic.getTranslatedStr(TryGetProp(cls, "Name", name))
                }
            end
        end
    end
    return list
end

-- 耳飾り 1 つが「残す条件」に当てはまるか。
-- **オプション 3 つのうち 1 つでも、そのクラスの指定 Lv 以上なら残す。**
function frag.keep_match(obj, keep)
    local item_lv = TryGetProp(obj, "ItemLv", 0)
    local cnt = shared_item_earring.get_max_special_option_count(item_lv)
    for i = 1, cnt do
        local class_name = TryGetProp(obj, "EarringSpecialOption_" .. i, "None")
        if class_name ~= "None" then
            local want = keep[class_name]
            if type(want) == "table" then
                -- そのオプションのランクの枠だけを見る。Lv は「その値以上なら残す」
                -- **等号ではない**(利用者の指定は下限)
                local by_rank = tonumber(want["r" .. TryGetProp(obj, "EarringSpecialOptionRankValue_" .. i, 0)]) or 0
                if by_rank > 0 and TryGetProp(obj, "EarringSpecialOptionLevelValue_" .. i, 0) >= by_rank then
                    return true
                end
            end
        end
    end
    return false
end

-- 条件に当てはまらないものを選択する。**当てはまるものは選択を外す**
-- (押すたびに結果が同じになるようにする。前の選択が混ざると何を実行するのか読めない)
function Mini_addons_frag_keep_apply()
    local frame = ui.GetFrame(frag.FRAME)
    if not frame then
        return
    end
    local keep = frag.keep_list()
    if frag.keep_count(keep) == 0 then
        ui.SysMsg(frag.lang("{ol}残す条件がありません(どれか 1 つでも Lv を 1 以上にしてください)",
            "{ol}남길 조건이 없습니다(하나라도 Lv 를 1 이상으로 해 주세요)",
            "{ol}No rules to keep (set at least one class to Lv 1 or higher)"))
        return
    end
    if type(shared_item_earring) ~= "table" then
        return
    end
    local slotset = GET_CHILD_RECURSIVELY(frame, "fragmentation_slotset", "ui::CSlotSet")
    if not slotset then
        return
    end
    AUTO_CAST(slotset)
    local selected, kept = 0, 0
    for i = 0, slotset:GetSlotCount() - 1 do
        local slot = slotset:GetSlotByIndex(i)
        local guid = slot:GetUserValue("FRAGMENTATION_GUID")
        if guid and guid ~= "None" then
            local inv_item = session.GetInvItemByGuid(guid)
            local obj = inv_item and GetIES(inv_item:GetObject())
            -- 耳飾り以外(タブが違う)は触らない。クラスの特殊オプションを持たないので判定できない
            if obj and TryGetProp(obj, "GroupName", "None") == "Earring" then
                if frag.keep_match(obj, keep) then
                    slot:Select(0)
                    kept = kept + 1
                else
                    slot:Select(1)
                    selected = selected + 1
                end
            end
        end
    end
    core_g.vlog("mini_addons: 破片化 条件で選択 指定=%d クラス 選択=%d 残す=%d", frag.keep_count(keep), selected,
        kept)
    ui.SysMsg(frag.lang(
        "{ol}{#00BFFF}[Nexus Addons P] " .. selected .. " 個を選択しました(残す " .. kept .. " 個)",
        "{ol}{#00BFFF}[Nexus Addons P] " .. selected .. " 개를 선택했습니다(남김 " .. kept .. " 개)",
        "{ol}{#00BFFF}[Nexus Addons P] Selected " .. selected .. " (keeping " .. kept .. ")"))
    Mini_addons_frag_keep_close()
end

-- Lv / ランクの数字を 1 つ動かす。0(Lv なら対象外、ランクなら不問)から上限までを回る。
-- **左で上げ、右で下げる。** スキル錬成の希望スキル(skill_reroll)と同じ向きに揃えている。
function frag.keep_step(ctrl, step)
    AUTO_CAST(ctrl)
    local class_name = ctrl:GetUserValue("CLASS")
    if class_name == nil or class_name == "None" then
        return
    end
    local field = ctrl:GetUserValue("FIELD")
    if field == nil or field == "None" then
        return
    end
    local keep = frag.keep_list()
    local want = frag.keep_want(keep, class_name)
    local now = (tonumber(want[field]) or 0) + step
    if now > frag.KEEP_LV_MAX then
        now = 0
    elseif now < 0 then
        now = frag.KEEP_LV_MAX
    end
    want[field] = (now > 0) and now or nil
    -- **枠が全部 0 になったらクラスごと落とす。** 触っただけのクラスが 0 のまま
    -- 溜まると、保存したものを見たときに「指定しているのかどうか」が読めなくなる
    if not frag.keep_has_value(want) then
        keep[class_name] = nil
    end
    ctrl:SetText(frag.keep_btn_text(now))
    ctrl:SetSkinName(now > 0 and "test_pvp_btn" or "test_gray_button")
    Mini_addons_save_settings()
    frag.keep_update_count()
    core_g.vlog("mini_addons: 破片化 残す条件 %s %s = Lv%d", tostring(class_name), tostring(field), now)
end

function frag.keep_btn_text(value)
    if value <= 0 then
        return "{ol}-"
    end
    return string.format("{ol}Lv%d", value)
end

-- 枠の見出し(R1 / R2 / R3)
function frag.keep_field_head(field)
    return string.upper(field)
end

function Mini_addons_frag_keep_lv_up(gbox, ctrl)
    frag.keep_step(ctrl, 1)
end

function Mini_addons_frag_keep_lv_down(gbox, ctrl)
    frag.keep_step(ctrl, -1)
end

function frag.keep_count_text()
    return "{ol}" .. frag.lang("指定中 ", "지정 ", "Set: ") .. frag.keep_count(frag.keep_list()) ..
               frag.lang(" クラス", " 클래스", "")
end

-- 指定中のクラス数の表示を書き直す。**窓ごと組み立て直さないこと**
-- (数字を 1 つ動かすたびに作り直すと、押し続けたときに重いうえタブまで戻る)
--
-- **同じ数字を出している場所が 2 つある**(条件の窓の左下と、破片化の窓の
-- 「条件で選択」ボタンの下)。条件の窓だけ書き直していたため、破片化の窓の方は
-- 開いた時点の数のまま古くなっていた。両方ここで書き直す
function frag.keep_update_count()
    local text = frag.keep_count_text()
    local frame = ui.GetFrame(frag.keep_frame_name())
    if frame then
        local ctrl = GET_CHILD_RECURSIVELY(frame, "keep_count")
        if ctrl then
            ctrl:SetText(text)
        end
    end
    local frag_frame = ui.GetFrame(frag.FRAME)
    if frag_frame then
        local ctrl = GET_CHILD_RECURSIVELY(frag_frame, "nexus_p_frag_keep_count")
        if ctrl then
            ctrl:SetText(text)
        end
    end
end

-- 枠(不問 / R1 / R2 / R3)の左端。**見出しと行で同じ式を使う**
-- (別々に書くと、どちらかを直したときにずれる)
function frag.keep_cell_x(at)
    return 235 + (at - 1) * 60
end

-- 選んでいる系統のクラスを並べ直す
function frag.keep_fill(frame)
    local gbox = GET_CHILD_RECURSIVELY(frame, "class_box")
    if not gbox then
        return
    end
    AUTO_CAST(gbox)
    gbox:RemoveAllChild()
    local bases = frag.base_jobs()
    local base = bases[frag.keep_tab + 1]
    if not base then
        return
    end
    local keep = frag.keep_list()
    local lv_tip = frag.lang(
        "{ol}この Lv 以上のオプションが 1 つでもあれば残します{nl}左クリックで 1 つ上げ、5 の次は - に戻ります{nl}右クリックで 1 つ下げます{nl}「-」はこの枠を使いません",
        "{ol}이 Lv 이상의 옵션이 하나라도 있으면 남깁니다{nl}좌클릭으로 1 단계 올리고, 5 다음은 - 로 돌아갑니다{nl}우클릭으로 1 단계 내립니다{nl}「-」는 이 칸을 쓰지 않습니다",
        "{ol}Keeps the earring if any option of this class is at least this level{nl}Left click steps up (wraps to - after 5){nl}Right click steps down{nl}\"-\" means this cell is unused")
    local rank_tip = frag.lang(
        "{ol}このランクのオプションだけ見ます{nl}ランクはツールチップの「[N] ランク スキルレベル」の N{nl}ランクを問わないときは 3 つとも同じ Lv にします",
        "{ol}이 랭크의 옵션만 봅니다{nl}랭크는 툴팁의 「[N] 랭크 스킬 레벨」의 N{nl}랭크를 따지지 않으려면 3 개 모두 같은 Lv 로 합니다",
        "{ol}Matches only options of this rank{nl}Rank is the N in \"[N] rank skill level\"{nl}For any rank, set all three to the same level")
    for i, cls in ipairs(frag.class_list(base.key)) do
        local y = (i - 1) * frag.KEEP_ROW_H
        local label = gbox:CreateOrGetControl("richtext", "cls_" .. cls.key, 10, y + 3, 215, 24)
        AUTO_CAST(label)
        label:SetText("{ol}" .. cls.name)
        label:AdjustFontSizeByWidth(215)
        local want = keep[cls.key]
        for at, field in ipairs(frag.KEEP_FIELDS) do
            local value = frag.keep_field_value(want, field)
            local btn = gbox:CreateOrGetControl("button", field .. "_" .. cls.key, frag.keep_cell_x(at), y, 52, 24)
            AUTO_CAST(btn)
            btn:SetSkinName(value > 0 and "test_pvp_btn" or "test_gray_button")
            btn:SetText(frag.keep_btn_text(value))
            -- **名前ではなくクラス名と枠を持たせる**(skill_reroll と同じ理由。名前から
            -- 切り出す作りは、クラス名にどんな文字が入っても壊れないとは言えない)
            btn:SetUserValue("CLASS", cls.key)
            btn:SetUserValue("FIELD", field)
            btn:SetTextTooltip(lv_tip .. "{nl}{nl}" .. rank_tip)
            btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_frag_keep_lv_up")
            btn:SetEventScript(ui.RBUTTONUP, "Mini_addons_frag_keep_lv_down")
        end
    end
    -- **中身を作り直したらスクロールバーの範囲を計算し直させること。**
    -- 順番が逆だと、作り直す前の範囲のまま丸められて末尾まで送れない
    -- (素のクライアントも作り直しの後に InvalidateScrollBar を呼んでいる)
    gbox:EnableScrollBar(1)
    pcall(function()
        gbox:InvalidateScrollBar()
    end)
    -- タブを切り替えたら先頭から見せる(前の系統の位置に残っていると、
    -- 上の方が空に見えて「クラスが無い」と読める)
    pcall(function()
        gbox:SetScrollPos(0)
    end)
end

function Mini_addons_frag_keep_tab(parent, ctrl)
    AUTO_CAST(ctrl)
    frag.keep_tab = ctrl:GetSelectItemIndex()
    local frame = ui.GetFrame(frag.keep_frame_name())
    if frame then
        frag.keep_fill(frame)
    end
end

-- 全系統の指定を消す。**押し間違いで全部消えると痛いので、必ず確認を挟む。**
-- 消える件数を数字で見せる(「今どれだけ持っているか」を見てから決められるように)
function Mini_addons_frag_keep_clear_all()
    local count = frag.keep_count(frag.keep_list())
    if count == 0 then
        return
    end
    local msg = frag.lang("指定している " .. count .. " クラスを全部 - に戻します。よろしいですか?",
        "지정한 " .. count .. " 클래스를 모두 - 로 되돌립니다. 괜찮습니까?",
        "Reset all " .. count .. " classes back to - ?")
    ui.MsgBox(msg, "Mini_addons_frag_keep_clear_all_ok()", "None")
end

function Mini_addons_frag_keep_clear_all_ok()
    local keep = frag.keep_list()
    local count = frag.keep_count(keep)
    -- **表を作り直さず、キーを 1 つずつ落とす。** 入れ物を差し替えると、
    -- 他所(プリセット読込など)が持っている参照と食い違う
    for class_name in pairs(keep) do
        keep[class_name] = nil
    end
    Mini_addons_save_settings()
    local frame = ui.GetFrame(frag.keep_frame_name())
    if frame then
        frag.keep_fill(frame)
    end
    frag.keep_update_count()
    core_g.vlog("mini_addons: 破片化 残す条件を全部消した(%d クラス)", count)
    ui.SysMsg(frag.lang("{ol}{#00BFFF}[Nexus Addons P] 指定を全部消しました(" .. count .. " クラス)",
        "{ol}{#00BFFF}[Nexus Addons P] 지정을 모두 지웠습니다(" .. count .. " 클래스)",
        "{ol}{#00BFFF}[Nexus Addons P] Cleared all (" .. count .. " classes)"))
end

-- 開いている系統だけ全部 0 に戻す。**全系統を消さないこと**
-- (他のタブで指定したものまで消えると、押した人には何が起きたのか分からない)
function Mini_addons_frag_keep_clear_tab()
    local bases = frag.base_jobs()
    local base = bases[frag.keep_tab + 1]
    if not base then
        return
    end
    local keep = frag.keep_list()
    local cleared = 0
    for _, cls in ipairs(frag.class_list(base.key)) do
        if keep[cls.key] then
            keep[cls.key] = nil
            cleared = cleared + 1
        end
    end
    Mini_addons_save_settings()
    local frame = ui.GetFrame(frag.keep_frame_name())
    if frame then
        frag.keep_fill(frame)
    end
    frag.keep_update_count()
    ui.SysMsg(frag.lang("{ol}{#00BFFF}[Nexus Addons P] " .. base.name .. " の指定を " .. cleared .. " 件消しました",
        "{ol}{#00BFFF}[Nexus Addons P] " .. base.name .. " 지정을 " .. cleared .. " 건 지웠습니다",
        "{ol}{#00BFFF}[Nexus Addons P] Cleared " .. cleared .. " in " .. base.name))
end

-- ===== 条件のプリセット(保存 / 読込) =====
--
-- 今の指定に名前を付けて保存し、後から呼び戻せるようにする。
-- キャラや用途ごとに「残す条件」を持ち替えたい、という使い方を想定している。

-- プリセットの保存先。**mini_addons.json とは別ファイルにしてある。**
-- 人に渡せるようにするため: mini_addons.json は Mini Addons の設定が全部入っていて、
-- そのまま渡すと相手の他の設定まで上書きしてしまう。プリセットだけのファイルなら
-- 同じ場所へ置くだけで持っていける。
-- 置き場所は他の設定と同じ AID フォルダの中(**外へ出さないこと**。
-- バックアップ / 復元は AID フォルダ直下しか運ばない)。
function frag.presets_path()
    return string.format("../addons/%s/%s/fragmentation_presets.json", core_addon_name_lower, g.active_id)
end

-- 読み込みはセッション中 1 回だけ。**毎回読み直さないこと**
-- (窓を組み立て直すたびに呼ばれるので、そのたびにファイルを開くことになる)
function frag.presets()
    if frag.presets_cache then
        return frag.presets_cache
    end
    local list = core_g.load_json(frag.presets_path())
    if type(list) ~= "table" then
        list = {}
    end
    frag.presets_cache = list
    frag.presets_migrate(list)
    return list
end

-- 旧い置き場所(mini_addons.json の中)からの引き継ぎ。
--
-- **旧い方を消してよいのは「新しいファイルへ書けた」ときだけ。**
-- 消す処理を移行の判定と分けて無条件に走らせていたため、次の 2 つでプリセットが
-- どこにも残らないまま消えていた(PR #164 の指摘)。
--   1. 人から貰った fragmentation_presets.json を置いた利用者。新しいファイルが
--      空でないので移行は起きないのに、旧い方だけ消えていた
--   2. 書き込みに失敗したとき(save_json は false を返す)。移せていないのに消していた
--
-- **中身が在るときは捨てずに足す。** 名前がぶつかったら新しいファイル側を残し、
-- 旧い方は「(旧)」を付けて別物として並べる(片方を黙って捨てない)。
function frag.presets_migrate(list)
    local cfg = (g.settings and type(g.settings.fragmentation) == "table") and g.settings.fragmentation or nil
    local old = (cfg and type(cfg.presets) == "table") and cfg.presets or nil
    if old == nil or #old == 0 then
        if cfg and cfg.presets ~= nil then
            cfg.presets = nil -- 空の残骸だけは落としてよい(失うものが無い)
            Mini_addons_save_settings()
        end
        return
    end
    local names, seen = {}, {}
    for _, preset in ipairs(list) do
        names[tostring(preset.name)] = true
        seen[frag.preset_signature(preset)] = true
        -- **改名したものは、元の名前でも照合できるようにする。** 書き込みに失敗した回の
        -- .tmp が次の起動で本体として復元されると、ファイル側は改名後・旧い設定側は
        -- 元の名前で残るため、名前を見るだけでは「もう入っている」と分からず、
        -- 「(旧) (旧)」と増え続ける(PR #164 の指摘)
        if preset.origin ~= nil then
            seen[frag.preset_signature({
                name = preset.origin,
                keep = preset.keep
            })] = true
        end
    end
    local moved, renamed, same = 0, 0, 0
    for _, preset in ipairs(old) do
        -- **同じ名前で同じ中身のものは足さない。** 保存の rename に失敗すると、
        -- 書き込み済みの .tmp が次の起動で本体として復元される一方、旧い方は
        -- 消せていないので、もう一度この移行を通る。素通しにすると同じ内容が
        -- 「(旧)」付きで増え続ける(PR #164 の指摘)
        if seen[frag.preset_signature(preset)] then
            same = same + 1
        else
            local name = tostring(preset.name)
            -- **付け直した名前も見ること。** 1 回だけだと、貰ったファイルに
            -- 「汎用」と「汎用 (旧)」が既に在るときに同名が 2 件並ぶ
            while names[name] do
                name = name .. frag.lang(" (旧)", " (구)", " (old)")
                renamed = renamed + 1
            end
            names[name] = true
            local one = {
                name = name,
                keep = preset.keep
            }
            if name ~= tostring(preset.name) then
                one.origin = tostring(preset.name) -- 上の照合に使う
            end
            seen[frag.preset_signature(one)] = true
            list[#list + 1] = one
            moved = moved + 1
        end
    end
    if moved == 0 and same > 0 then
        -- 全部が「もう入っている」なら、書き直さずに旧い方だけ落とす
        cfg.presets = nil
        Mini_addons_save_settings()
        core_g.vlog("mini_addons: 破片化 プリセットは移行済みだった(%d 件)", same)
        return
    end
    -- 旧い方を落とすのは書けたときだけ。**その判断は frag.presets_save に任せる。**
    -- ここで失敗したときにキャッシュを捨てると、呼び出し元が持っている一覧と
    -- キャッシュが食い違い、次の保存が空の一覧でファイルを潰す(PR #164 の指摘 2)
    frag.presets_pending_old = cfg
    if frag.presets_save() then
        core_g.vlog("mini_addons: 破片化 プリセットを %s へ移した(%d 件 / 改名 %d 件)", frag.presets_path(), moved,
            renamed)
    else
        -- 書けなかったので旧い方は残す。この後の保存が成功すれば、そこで落ちる
        core_g.vlog("{#FF6347}mini_addons: 破片化 プリセットの移行に失敗(%s へ書けない)。旧い方は残す{/}",
            frag.presets_path())
    end
end

-- **保存はここ 1 本に集約する。** 旧い置き場所を空にするのも、移行のときだけでなく
-- 「この後どこかで書けたとき」で拾えるよう、ここでまとめて行う
-- (移行の書き込みが一度失敗しても、次にプリセットを保存できた時点で移行が完了する)。
-- プリセット 1 件の「名前 + 中身」。同じものを二度足さないための照合に使う。
-- **中身まで見ること。** 名前だけで見ると、同じ名前の別物を取り違えて捨てる
function frag.preset_signature(preset)
    local keep = (type(preset) == "table" and type(preset.keep) == "table") and preset.keep or {}
    local classes = {}
    for class_name in pairs(keep) do
        classes[#classes + 1] = class_name
    end
    table.sort(classes)
    local parts = {tostring(preset and preset.name)}
    for _, class_name in ipairs(classes) do
        local want = keep[class_name]
        parts[#parts + 1] = string.format("%s=%s/%s/%s", class_name, tostring(frag.keep_field_value(want, "r1")),
            tostring(frag.keep_field_value(want, "r2")), tostring(frag.keep_field_value(want, "r3")))
    end
    return table.concat(parts, "\1")
end

function frag.presets_save()
    -- **読み込む前には書かない。** ここが唯一の書き出し口なので、キャッシュが
    -- まだ無いまま呼ばれると空の一覧でファイルを潰すことになる
    if frag.presets_cache == nil then
        return false
    end
    local ok = core_g.save_json(frag.presets_path(), frag.presets_cache)
    if ok and frag.presets_pending_old ~= nil then
        frag.presets_pending_old.presets = nil
        frag.presets_pending_old = nil
        Mini_addons_save_settings()
    end
    return ok
end

-- 指定の写しを作る。**参照のまま入れてはいけない。** 保存したプリセットと編集中の
-- 表が同じものを指すことになり、保存した後に数字をいじると中身まで書き換わる
function frag.copy_keep(keep)
    local copy = {}
    for class_name, want in pairs(keep or {}) do
        if frag.keep_has_value(want) then
            local one = {}
            -- **枠を 1 つずつ写すこと。** 表ごと入れると、保存したプリセットと
            -- 編集中の表が同じものを指し、後から数字をいじると中身まで書き換わる
            for _, field in ipairs(frag.KEEP_FIELDS) do
                local value = frag.keep_field_value(want, field)
                if value > 0 then
                    one[field] = value
                end
            end
            copy[class_name] = one
        end
    end
    return copy
end

-- 窓の名前入力の中身。窓を組み立て直しても打った名前が消えないよう控えておく
function frag.keep_name_text()
    local frame = ui.GetFrame(frag.keep_frame_name())
    if frame then
        local edit = GET_CHILD_RECURSIVELY(frame, "preset_name")
        if edit then
            local text = edit:GetText()
            if text and text ~= "" then
                return text
            end
        end
    end
    return frag.keep_name or ""
end

function Mini_addons_frag_keep_save_preset()
    local name = frag.keep_name_text()
    if name == "" then
        ui.SysMsg(frag.lang("{ol}プリセットの名前を入れてください", "{ol}프리셋 이름을 입력해 주세요",
            "{ol}Enter a preset name"))
        return
    end
    local keep = frag.keep_list()
    if frag.keep_count(keep) == 0 then
        ui.SysMsg(frag.lang("{ol}保存する指定がありません", "{ol}저장할 지정이 없습니다", "{ol}Nothing to save"))
        return
    end
    local presets = frag.presets()
    local slot = nil
    for _, preset in ipairs(presets) do
        if preset.name == name then
            slot = preset -- 同じ名前は上書き(増やし続けると選べなくなるため)
        end
    end
    if not slot then
        slot = {}
        presets[#presets + 1] = slot
    end
    slot.name = name
    slot.keep = frag.copy_keep(keep)
    slot.origin = nil -- 手で保存し直したものは移行の照合から外す(名前は利用者が決めた)
    frag.keep_name = name
    -- **書けたかどうかを見る。** 分けたファイルを書くのはここだけなので、
    -- 失敗を黙って「保存しました」と出すと、その 1 件がどこにも残らない
    if not frag.presets_save() then
        core_g.vlog("{#FF6347}mini_addons: 破片化 プリセットの保存に失敗(%s){/}", frag.presets_path())
        frag.presets_cache = nil -- 書けていないので、次に読み直させる
        ui.SysMsg(frag.lang("{ol}{#FF6347}[Nexus Addons P] プリセットを保存できませんでした",
            "{ol}{#FF6347}[Nexus Addons P] 프리셋을 저장하지 못했습니다",
            "{ol}{#FF6347}[Nexus Addons P] Could not save the preset"))
        return
    end
    core_g.vlog("mini_addons: 破片化 プリセット保存 %s (%d クラス)", name, frag.keep_count(slot.keep))
    ui.SysMsg(frag.lang("{ol}{#00BFFF}[Nexus Addons P] 「" .. name .. "」を保存しました",
        "{ol}{#00BFFF}[Nexus Addons P] 「" .. name .. "」을(를) 저장했습니다",
        "{ol}{#00BFFF}[Nexus Addons P] Saved \"" .. name .. "\""))
end

-- 読込 / 削除の droplist。プリセットが 1 つも無ければ知らせて開かない
function frag.preset_droplist(ctrl, field)
    local presets = frag.presets()
    if #presets == 0 then
        ui.SysMsg(frag.lang("{ol}保存したプリセットがありません", "{ol}저장된 프리셋이 없습니다",
            "{ol}No saved presets"))
        return
    end
    frag.keep_edit = field
    local shown = math.min(10, #presets)
    ui.MakeDropListFrame(ctrl, 0, 0, math.max(ctrl:GetWidth(), 150), shown * 30, shown, ui.LEFT,
        "Mini_addons_frag_keep_select", nil, nil)
    for i, preset in ipairs(presets) do
        ui.AddDropListItem(preset.name or ("#" .. i), nil, tostring(i))
    end
end

function Mini_addons_frag_keep_open_load(frame, ctrl)
    frag.preset_droplist(ctrl, "load")
end

function Mini_addons_frag_keep_open_delete(frame, ctrl)
    frag.preset_droplist(ctrl, "delete")
end

function Mini_addons_frag_keep_select(index, keyword)
    local field = frag.keep_edit
    frag.keep_edit = nil
    if not field then
        return
    end
    local presets = frag.presets()
    local at = tonumber(keyword) or 0
    local preset = presets[at]
    if not preset then
        return
    end
    if field == "load" then
        -- **写しを入れること**(理由は frag.copy_keep のコメント)
        g.settings.fragmentation.keep = frag.copy_keep(preset.keep or {})
        frag.keep_name = preset.name
        core_g.vlog("mini_addons: 破片化 プリセット読込 %s (%d クラス)", tostring(preset.name),
            frag.keep_count(g.settings.fragmentation.keep))
        ui.SysMsg(frag.lang("{ol}{#00BFFF}[Nexus Addons P] 「" .. tostring(preset.name) .. "」を読み込みました",
            "{ol}{#00BFFF}[Nexus Addons P] 「" .. tostring(preset.name) .. "」을(를) 불러왔습니다",
            "{ol}{#00BFFF}[Nexus Addons P] Loaded \"" .. tostring(preset.name) .. "\""))
    else
        local removed = tostring(preset.name)
        table.remove(presets, at)
        -- **消せたかどうかを見てから知らせる。** 書けなかったらファイルには残るので、
        -- 一覧の方も戻して食い違わせない
        if not frag.presets_save() then
            table.insert(presets, at, preset)
            core_g.vlog("{#FF6347}mini_addons: 破片化 プリセットの削除に失敗(%s){/}", frag.presets_path())
            ui.SysMsg(frag.lang("{ol}{#FF6347}[Nexus Addons P] プリセットを削除できませんでした",
                "{ol}{#FF6347}[Nexus Addons P] 프리셋을 삭제하지 못했습니다",
                "{ol}{#FF6347}[Nexus Addons P] Could not delete the preset"))
            Mini_addons_frag_keep_open()
            return
        end
        if frag.keep_name == preset.name then
            frag.keep_name = ""
        end
        ui.SysMsg(frag.lang("{ol}{#00BFFF}[Nexus Addons P] 「" .. removed .. "」を削除しました",
            "{ol}{#00BFFF}[Nexus Addons P] 「" .. removed .. "」을(를) 삭제했습니다",
            "{ol}{#00BFFF}[Nexus Addons P] Deleted \"" .. removed .. "\""))
    end
    -- 読み込んだときは「今の指定」が変わるので、そちらは設定へ保存する
    Mini_addons_save_settings()
    Mini_addons_frag_keep_open()
end

-- 条件の窓を開く / 作り直す
function Mini_addons_frag_keep_open()
    local name = frag.keep_frame_name()
    local frame = ui.GetFrame(name)
    local is_new = false
    if not frame then
        is_new = true
        frame = ui.CreateNewFrame("notice_on_pc", name, 0, 0, 10, 10)
        AUTO_CAST(frame)
        core_g.block_click_through(frame)
        frame:SetSkinName("test_frame_low")
        frame:SetLayerLevel(999)
    end
    AUTO_CAST(frame)
    -- **窓を開いた時点で 1 回読む。** 旧い置き場所からの移行はここで走る
    -- (保存 / 読込 / 削除を押したときだけだと、開いただけでは移行が起きず、
    --  更新履歴の説明と食い違う)。2 回目以降はキャッシュを返すだけ
    frag.presets()
    -- 打ちかけの名前は控えてから捨てる(プリセットを読み込むと組み立て直すため)
    frag.keep_name = frag.keep_name_text()
    frame:RemoveAllChild()
    local title = frame:CreateOrGetControl("richtext", "title", 15, 12, 10, 30)
    AUTO_CAST(title)
    title:SetText("{#000000}{s20}" ..
                      frag.lang("破片化しないで残す条件", "파편화하지 않고 남길 조건", "Rules to keep (do not fragment)"))
    -- **窓の幅に収まる長さで書き、そのうえで縮める。** 説明文は言語ごとに長さが違い
    -- (英語が一番長い)、はみ出すと途中で切れて読めなくなる。細かい操作の説明は
    -- 枠のツールチップが持っているので、ここは 1 行で言い切る
    local desc = frame:CreateOrGetControl("richtext", "desc", 15, 45, 465, 25)
    AUTO_CAST(desc)
    desc:SetText("{ol}" .. frag.lang("クラスごとに「この Lv 以上なら残す」を決めます",
        "클래스마다 「이 Lv 이상이면 남김」을 정합니다", "Set \"keep at this level or above\" per class"))
    desc:AdjustFontSizeByWidth(465)
    -- プリセット(保存 / 読込 / 削除)
    local preset_label = frame:CreateOrGetControl("richtext", "preset_label", 15, 78, 80, 25)
    AUTO_CAST(preset_label)
    preset_label:SetText("{ol}" .. frag.lang("プリセット", "프리셋", "Preset"))
    local preset_name = frame:CreateOrGetControl("edit", "preset_name", 105, 74, 150, 28)
    AUTO_CAST(preset_name)
    -- 素が入力欄に使っているスキンと字(guildinfo の noticeEdit と同じ組み合わせ)。
    -- 窓の地が明るいので白字にすると読めない
    preset_name:SetSkinName("test_weight_skin")
    preset_name:SetFontName("black_18")
    preset_name:SetTextAlign("left", "center")
    preset_name:SetText(frag.keep_name or "")
    -- **Focus() は呼ばない。** 入力欄にフォーカスがあると ESC の 1 回目が
    -- 「入力欄から抜ける」に使われ、窓が閉じなくなる(CLAUDE.md の ESC の節)
    preset_name:SetEventScript(ui.ENTERKEY, "Mini_addons_frag_keep_save_preset")
    local preset_btns = {{
        name = "preset_save",
        x = 265,
        text = frag.lang("保存", "저장", "Save"),
        script = "Mini_addons_frag_keep_save_preset",
        tip = frag.lang("{ol}今の指定を、その名前で保存します{nl}同じ名前なら上書きします",
            "{ol}지금 지정을 그 이름으로 저장합니다{nl}같은 이름이면 덮어씁니다",
            "{ol}Saves the current setup under that name (overwrites the same name)")
    }, {
        name = "preset_load",
        x = 340,
        text = frag.lang("読込", "불러오기", "Load"),
        script = "Mini_addons_frag_keep_open_load",
        tip = frag.lang("{ol}保存したプリセットで、今の指定を置き換えます",
            "{ol}저장한 프리셋으로 지금 지정을 바꿉니다", "{ol}Replaces the current setup with a saved preset")
    }, {
        name = "preset_del",
        x = 415,
        text = frag.lang("削除", "삭제", "Delete"),
        script = "Mini_addons_frag_keep_open_delete",
        tip = frag.lang("{ol}保存したプリセットを消します(今の指定はそのまま)",
            "{ol}저장한 프리셋을 지웁니다(지금 지정은 그대로)",
            "{ol}Deletes a saved preset (the current setup stays)")
    }}
    for _, def in ipairs(preset_btns) do
        local btn = frame:CreateOrGetControl("button", def.name, def.x, 74, 70, 28)
        AUTO_CAST(btn)
        btn:SetSkinName("test_gray_button")
        btn:SetText("{ol}" .. def.text)
        btn:SetTextTooltip(def.tip)
        btn:SetEventScript(ui.LBUTTONUP, def.script)
    end
    -- 系統のタブ。**タブ本体は 10 引数の並び**(幅 / 高さ / 寄せ / 寄せ / x / y)で、
    -- 他のコントロール(x / y / 幅 / 高さ)とは違うので注意
    local bases = frag.base_jobs()
    -- **幅は項目の合計ぴったりにする。** 余らせると、タブの地(skin)だけが右へ伸びて
    -- 見出しの無い帯が 1 本入っているように見える。高さも skin に合わせて 40
    -- (素の status_point_check と同じ組み合わせ)
    local tab_item_w = 92
    local tab = frame:CreateOrGetControl("tab", "job_tab", tab_item_w * #bases, 40, ui.LEFT, ui.TOP, 15, 108, 0, 0)
    AUTO_CAST(tab)
    tab:SetSkinName("tab2")
    for _, base in ipairs(bases) do
        tab:AddItem("{@st66b}" .. base.name, true, "", "", "", "", "", false)
    end
    tab:SetItemsFixWidth(tab_item_w)
    tab:SetItemsAdjustFontSizeByWidth(tab_item_w)
    tab:SetEventScript(ui.LBUTTONUP, "Mini_addons_frag_keep_tab")
    if frag.keep_tab >= #bases then
        frag.keep_tab = 0
    end
    tab:SelectTab(frag.keep_tab)
    -- **タブ(y=108, 高さ 40 → 148 まで)と枠の見出しが重ならない位置にすること。**
    -- 見出しは box_y - 20 に置くので、152 だと 132 = タブの上に被っていた
    local box_y = 178
    local box_h = frag.KEEP_ROWS * frag.KEEP_ROW_H
    -- 枠の見出し。**行の枠と同じ式(frag.keep_cell_x)で置く**
    for at, field in ipairs(frag.KEEP_FIELDS) do
        local head = frame:CreateOrGetControl("richtext", "head_" .. field, 15 + frag.keep_cell_x(at) + 8,
            box_y - 20, 52, 20)
        AUTO_CAST(head)
        head:SetText("{ol}" .. frag.keep_field_head(field))
    end
    local class_box = frame:CreateOrGetControl("groupbox", "class_box", 15, box_y, 470, box_h)
    AUTO_CAST(class_box)
    class_box:SetSkinName("test_frame_midle")
    class_box:EnableScrollBar(1)
    local count_text = frame:CreateOrGetControl("richtext", "keep_count", 15, box_y + box_h + 8, 110, 25)
    AUTO_CAST(count_text)
    local clear_defs = {{
        name = "clear_btn",
        x = 130,
        width = 78,
        text = frag.lang("タブ解除", "탭 해제", "This tab"),
        script = "Mini_addons_frag_keep_clear_tab",
        tip = frag.lang("{ol}開いている系統の指定だけを - に戻します(他の系統はそのまま)",
            "{ol}열려 있는 계열의 지정만 - 로 되돌립니다(다른 계열은 그대로)",
            "{ol}Resets only the open tree back to - (other trees stay)")
    }, {
        name = "clear_all_btn",
        x = 213,
        width = 68,
        text = frag.lang("全解除", "전체 해제", "All"),
        script = "Mini_addons_frag_keep_clear_all",
        tip = frag.lang("{ol}全系統の指定を - に戻します{nl}押すと確認が出ます",
            "{ol}모든 계열의 지정을 - 로 되돌립니다{nl}누르면 확인이 나옵니다",
            "{ol}Resets every tree back to -{nl}Asks for confirmation first")
    }}
    for _, def in ipairs(clear_defs) do
        local btn = frame:CreateOrGetControl("button", def.name, def.x, box_y + box_h + 5, def.width, 30)
        AUTO_CAST(btn)
        btn:SetSkinName("test_gray_button")
        btn:SetText("{ol}" .. def.text)
        btn:SetTextTooltip(def.tip)
        btn:SetEventScript(ui.LBUTTONUP, def.script)
    end
    local apply_btn = frame:CreateOrGetControl("button", "apply_btn", 290, box_y + box_h + 2, 195, 36)
    AUTO_CAST(apply_btn)
    apply_btn:SetSkinName("test_red_button")
    apply_btn:SetText("{ol}" .. frag.lang("この条件で選択", "이 조건으로 선택", "Select by these rules"))
    apply_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_frag_keep_apply")
    local close_btn = frame:CreateOrGetControl("button", "close_btn", 0, 0, 22, 22)
    AUTO_CAST(close_btn)
    close_btn:SetImage("testclose_button")
    close_btn:SetGravity(ui.RIGHT, ui.TOP)
    close_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_frag_keep_close")
    frame:Resize(500, box_y + box_h + 50)
    frag.keep_fill(frame)
    frag.keep_update_count()
    -- **位置を決めるのは作った回だけ。** プリセットを読み込むと組み立て直すので、
    -- 毎回置き直すと利用者が動かした窓が操作のたびに飛ぶ
    local frag_frame = is_new and ui.GetFrame(frag.FRAME) or nil
    if frag_frame then
        -- 破片化の窓の右隣。画面からはみ出すなら左隣へ回す
        local x = frag_frame:GetX() + frag_frame:GetWidth() + 5
        if x + 500 > ui.GetClientInitialWidth() then
            x = math.max(0, frag_frame:GetX() - 505)
        end
        frame:SetPos(x, frag_frame:GetY() + 100)
    end
    frame:ShowWindow(1)
    -- × と同じく破棄で閉じる窓なので esc_register_destroy(CLAUDE.md の ESC の節)
    core_g.esc_register_destroy(name)
end

function Mini_addons_frag_keep_close()
    ui.DestroyFrame(frag.keep_frame_name())
    -- 破片化の窓に出している数も合わせる(条件の窓が消えた後の値を出しておく)
    frag.keep_update_count()
end

-- ここから素のフック。いずれも「素を呼んでから加工」で、素の中身は写していない。

function Mini_addons_FRAGMENTATION_OPEN(frame)
    local origin = g.FUNCS["FRAGMENTATION_OPEN"]
    if not frag.enabled() and not frag.applied then
        if origin then
            origin(frame)
        end
        return
    end
    -- 素の OPEN は最後に FRAGMENTATION_REFRESH_ALL(インベントリ全走査)を呼ぶが、
    -- この直後にスロットを作り直すので**その結果は必ず捨てられる**。素を呼んでいる
    -- 同期実行の間だけ空にして、走査を 1 回に減らす。**必ず元へ戻すこと**
    -- (戻し忘れると、以降フィルタを触っても一覧が更新されなくなる)。
    --
    -- **差し替え先の名前を frag.REFRESH 経由で引いているのはわざと。**
    -- `_G["FRAGMENTATION_REFRESH_ALL"] = ...` と直に書くと、docs/vanilla_api.py が
    -- 「この名前は自分たちが定義したもの」と見なして素の API の一覧から外してしまい、
    -- IMC 側でこの関数が消えても気付けなくなる(実際に一覧から落ちた)。
    -- 呼び出しは Mini_addons_frag_apply の中に直書きが残っているので、そちらで追える。
    local refresh = _G[frag.REFRESH]
    local stubbed = type(refresh) == "function"
    if stubbed then
        _G[frag.REFRESH] = function()
        end
    end
    local ok, err = pcall(function()
        if origin then
            origin(frame)
        end
    end)
    if stubbed then
        _G[frag.REFRESH] = refresh
    end
    if not ok then
        core_g.vlog("{#FF6347}mini_addons: 破片化の素の OPEN が FAILED{/} %s", tostring(err))
    end
    -- 中で FRAGMENTATION_REFRESH_ALL を 1 回呼ぶ(素の呼び出しを止めたぶんはここで賄う)
    local ok2, err2 = pcall(Mini_addons_frag_apply, frame)
    if not ok2 then
        core_g.vlog("{#FF6347}mini_addons: 破片化の適用 FAILED{/} %s", tostring(err2))
        -- 適用に失敗しても一覧は出す(素の呼び出しを止めているため)
        pcall(FRAGMENTATION_REFRESH_ALL, frame)
    end
end

-- 素はここで「どのフィルタ枠を出すか」を決め、argList を返す。
-- こちらが有効な耳飾りタブでは、素の等級チェックボックスを引っ込めて自前の行を出し、
-- **argList は空にする**(判定は is_able_to_fragmetation の横取り側で行う)。
function Mini_addons_FRAGMENTATION_SET_FILTER_SECTION(frame, tabindex)
    local origin = g.FUNCS["FRAGMENTATION_SET_FILTER_SECTION"]
    local argList = (origin and origin(frame, tabindex)) or {}
    -- 素が文字を入れた後に差し替える(折り返し対策。frag.own_title 参照)。
    -- 耳飾りタブ以外と、機能を切ったときは素へ戻す
    if frag.enabled() or frag.applied then
        frag.own_title(frame, tabindex)
    end
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

-- 一覧を作り直した**後**に残っている選択を外す。
--
-- 素の FRAGMENTATION_CLEAR_ALL_SLOTS は ClearIconAll と FRAGMENTATION_GUID の消去しか
-- しておらず、選択フラグを Select(0) していない。ClearIconAll が選択まで落とすかは
-- C++ 側の話で素の Lua からは分からないが、**落とさないなら実害がある**。
-- 絞り込みでスロットには別の耳飾りが入り直すので、位置に選択だけが残っていると、
-- 素は入れ替わった後の GUID を読んで**警告も出さずに違う耳飾りを破片化する**。
-- 落ちるより厄介なので、分からないなら明示的に外す。
--
-- **素を呼んだ後に外すこと。** 詰め直しが終わった時点で選択が残っていれば
-- 「ClearIconAll は選択を落とさない」が確定するので、そのまま計測を兼ねられる
-- (落とすなら常に 0 件で、ログにも出ない)。
--
-- 素の REFRESH_ALL 自身も CHECK_IS_SELECT_ALL_BEFORE を FALSE へ戻していて、
-- 「更新 = 選択リセット」のつもりで書かれているので、素の意図とも揃う。
function frag.drop_stale_selection(frame)
    local slotset = GET_CHILD_RECURSIVELY(frame, "fragmentation_slotset", "ui::CSlotSet")
    if not slotset then
        return
    end
    AUTO_CAST(slotset)
    local cleared = 0
    for i = 0, slotset:GetSlotCount() - 1 do
        local slot = slotset:GetSlotByIndex(i)
        if slot and slot:IsSelected() == 1 then
            slot:Select(0)
            cleared = cleared + 1
        end
    end
    if cleared > 0 then
        core_g.vlog("mini_addons: 破片化 一覧の更新後に選択が %d 個残っていたので外した", cleared)
    end
    local picked = frag.pick_pending(slotset)
    if cleared > 0 or picked > 0 then
        slotset:MakeSelectionList()
    end
end

-- 25 個ずつの続き。**実行が終わった直後の更新のときだけ**、前回入り切らなかった
-- ぶんを選び直す(frag.resume が真のときだけ走る)。
--
-- **残っているぶんを全部選び直す**(25 個だけに絞らない)。押すたびに
-- 「75 → 50 → 25」と減っていく見え方になり、あと何個残っているかが一覧で分かる。
-- 実際に実行されるのは次に押したときに frag.guard_execute が先頭 25 個へ丸めたぶんで、
-- 溢れたぶんはそこでまた控えに戻る。
--
-- **やるのは選択だけで、実行はしない。** 破片化は取り消せないので、押すのは必ず
-- 利用者にしてもらう(「自動」が ON のときだけ、下の Mini_addons_frag_auto_exec が押す)。
--
-- **覚えているのは GUID で、位置ではない。** 実行が終わると消えたぶんだけ詰め直されて
-- 並びが変わるので、位置で覚えると別の耳飾りを掴む。GUID なら、利用者が最初に
-- 選んだ実体そのものだけを選び直せる(見当たらないものは黙って落ちる)。
function frag.pick_pending(slotset)
    if frag.pending == nil then
        return 0
    end
    if not frag.resume then
        -- 実行以外の理由で一覧が作り直された(絞り込み / タブ / 開き直し)。
        -- 並びも中身も変わっているので、前の意思は持ち越さずここで捨てる。
        -- **確認ダイアログを閉じただけでは一覧は作り直されない**ので、
        -- そちらは frag.guard_execute が選択へ戻す
        frag.forget_pending()
        return 0
    end
    local picked = 0
    local picked_set = {}
    for i = 0, slotset:GetSlotCount() - 1 do
        local slot = slotset:GetSlotByIndex(i)
        if slot and slot:GetIcon() ~= nil then
            local guid = slot:GetUserValue("FRAGMENTATION_GUID")
            if guid ~= nil and guid ~= "None" and frag.pending[guid] then
                slot:Select(1)
                picked_set[guid] = true
                picked = picked + 1
            end
        end
    end
    -- 控えは選択そのものへ移したので手放す。見当たらなかったぶん(タブや絞り込みを
    -- 変えた、他で消費した等)も、ここで一緒に忘れる。黙って抱え続けない
    frag.forget_pending()
    if picked == 0 then
        return 0
    end
    local limit = frag.base_max_slot or 25
    core_g.vlog("mini_addons: 破片化 残り %d 個を選び直した 自動=%s", picked, tostring(frag.auto_enabled()))
    if frag.auto_enabled() then
        -- **その場で実行しない。** ここは素の完了処理(ON_FRAGMENTATION_END)の
        -- 最中なので、同じ流れの中から次の送信を始めると素の後始末と噛み合わない。
        -- 少し置いてから、改めてボタンを押したのと同じ経路へ入る。
        -- 連鎖は「完了 → 選び直し → 実行」の輪で回るので、完了が来なければ
        -- そこで自然に止まる(暴走しない)
        -- **何を選び直したのかを控える。** 予約から実行までの 0.5 秒の間に利用者が
        -- 選択を足す / 「すべて選択」を押すことがあり、そのまま実行すると意図しない
        -- 耳飾りを破片化してしまう(取り消せない)。手で押す経路(frag.guard_execute)は
        -- 同じ確認をしているので、自動だけ素通しにしない
        frag.auto_expect, frag.auto_expect_n = picked_set, picked
        ReserveScript("Mini_addons_frag_auto_exec()", 0.5)
        return picked
    end
    ui.SysMsg(frag.lang(
        "{ol}{#00BFFF}[Nexus Addons P] 残りの " .. picked ..
            " 個を選び直しました。もう一度「破片へ変換」を押すと、このうち " .. math.min(picked, limit) ..
            " 個を実行します",
        "{ol}{#00BFFF}[Nexus Addons P] 남은 " .. picked .. " 개를 다시 선택했습니다. 「파편화」를 한 번 더 누르면 이 중 " ..
            math.min(picked, limit) .. " 개를 실행합니다",
        "{ol}{#00BFFF}[Nexus Addons P] Re-selected the remaining " .. picked ..
            " - press Fragment again to run " .. math.min(picked, limit) .. " of them"))
    return picked
end

-- 素の並べ替え本体。**素をそのまま呼び**、その同期実行の間だけ
-- shared_item_earring.is_able_to_fragmetation を横取りして自前フィルタで落とす。
-- 横取りは pcall で失敗した経路も含めて必ず戻すこと(戻し忘れると、以降どの窓でも
-- 破片化の対象判定が壊れる)。
--
-- 並べ終えたら frag.drop_stale_selection を必ず 1 回通す(どの経路からでも)。
function Mini_addons_FRAGMENTATION_SHOW_TARGETS_FROM_INV(frame, tabindex, argList)
    local origin = g.FUNCS["FRAGMENTATION_SHOW_TARGETS_FROM_INV"]
    if not origin then
        return
    end
    -- **枠を広げている間だけ**後始末をする(素の窓に触っていない利用者の挙動は変えない)
    local sweep = frag.enabled() or frag.applied
    local state = nil
    if frag.enabled() and tabindex == 0 and type(shared_item_earring) == "table" then
        state = frag.filter_state(frame)
    end
    local able = nil
    if state then
        able = shared_item_earring.is_able_to_fragmetation
        if type(able) ~= "function" then
            able, state = nil, nil
        end
    end
    if state then
        shared_item_earring.is_able_to_fragmetation = function(item)
            if able(item) == false then
                return false
            end
            return frag.pass(item, state)
        end
    end
    local ok, err = pcall(origin, frame, tabindex, argList)
    if state then
        shared_item_earring.is_able_to_fragmetation = able
    end
    if not ok then
        core_g.vlog("{#FF6347}mini_addons: 破片化の一覧作成 FAILED{/} %s", tostring(err))
    end
    if sweep then
        frag.drop_stale_selection(frame)
    end
end

-- 「自動」が ON のとき、選び直した続きをそのまま実行する。
-- **押したのと同じ経路を通す**(素の FRAGMENTATION_EXECUTE = こちらのフック)ので、
-- 枚数の頭打ちも素の確認ダイアログもそのまま効く。
function Mini_addons_frag_auto_exec()
    if not frag.auto_enabled() then
        return
    end
    local frame = ui.GetFrame(frag.FRAME)
    -- 待っている間に窓を閉じられていたら止める
    if not frame or frame:IsVisible() == 0 then
        core_g.vlog("mini_addons: 破片化 自動実行を取りやめ(窓が閉じている)")
        frag.forget_pending()
        return
    end
    local btn = GET_CHILD_RECURSIVELY(frame, "exec_fragmentation")
    if not btn then
        core_g.vlog("{#FF6347}mini_addons: 破片化 実行ボタンが見つからないので自動実行しない{/}")
        return
    end
    local slotset = GET_CHILD_RECURSIVELY(frame, "fragmentation_slotset", "ui::CSlotSet")
    if not slotset then
        return
    end
    AUTO_CAST(slotset)
    local selected = 0
    for i = 0, slotset:GetSlotCount() - 1 do
        local slot = slotset:GetSlotByIndex(i)
        if slot and slot:IsSelected() == 1 then
            selected = selected + 1
        end
    end
    -- 選び直しの後に利用者が全部外していたら、何もしない
    if selected == 0 then
        core_g.vlog("mini_addons: 破片化 自動実行を取りやめ(選択が 0)")
        frag.auto_expect, frag.auto_expect_n = nil, nil
        return
    end
    -- **選び直したものと今の選択が一致するときだけ実行する。**
    -- 待っている間に利用者が選択を変えていたら、こちらの都合で実行しない
    -- **控えは先に手元へ取ってから消すこと**(消した後に読むと必ず nil になる)
    local expect, expect_n = frag.auto_expect, frag.auto_expect_n
    frag.auto_expect, frag.auto_expect_n = nil, nil
    local same = (expect ~= nil and selected == expect_n)
    if expect ~= nil then
        for i = 0, slotset:GetSlotCount() - 1 do
            local slot = slotset:GetSlotByIndex(i)
            if slot and slot:IsSelected() == 1 then
                local guid = slot:GetUserValue("FRAGMENTATION_GUID")
                if guid == nil or guid == "None" or not expect[guid] then
                    same = false
                end
            end
        end
    else
        same = false
    end
    if not same then
        core_g.vlog("mini_addons: 破片化 自動実行を取りやめ(選択が変わっている 選択=%d)", selected)
        ui.SysMsg(frag.lang("{ol}{#00BFFF}[Nexus Addons P] 選択が変わったので自動実行を止めました。ご自身で「破片へ変換」を押してください",
            "{ol}{#00BFFF}[Nexus Addons P] 선택이 바뀌어 자동 실행을 멈췄습니다. 직접 「파편화」를 눌러 주세요",
            "{ol}{#00BFFF}[Nexus Addons P] Selection changed - auto run stopped. Press Fragment yourself"))
        frag.forget_pending()
        return
    end
    core_g.vlog("mini_addons: 破片化 続きを自動で実行する 選択=%d", selected)
    local ok, err = pcall(FRAGMENTATION_EXECUTE, btn, btn)
    if not ok then
        core_g.vlog("{#FF6347}mini_addons: 破片化の自動実行が FAILED{/} %s", tostring(err))
        frag.forget_pending()
    end
end

-- 素の実行(破片へ変換)の直前に、**落ちる形になっているスロットを取り除く**。
--
-- 素の FRAGMENTATION_EXECUTE は
--   for i=0, shared_item_earring.MAX_SLOT_CNT-1 do
--       local slot = slotSet:GetSlotByIndex(i)
--       if slot:IsSelected()==1 then
--           local icon = slot:GetIcon(); local iconInfo = icon:GetInfo()
-- という作りで、次の 2 つをどちらも見ていない。
--   (a) 選択されているのにアイコンが無いスロット … icon が nil のまま GetInfo を呼ぶ
--   (b) スロット数より MAX_SLOT_CNT が多い状態 … GetSlotByIndex が nil を返す
-- (b) は MAX_SLOT_CNT をこちらが書き換えているぶん、こちらの責任でもある。
--
-- ここはボタンのイベントスクリプトなので、落ちても debug_log.txt には残らない
-- (あれは RegisterMsg 経由の分しか記録しない)。**そのため計測値を vlog へ出す。**
-- 残骸が 1 つでも出れば「ClearIconAll は選択を落とさない」が実証され、
-- 常に 0 なら原因は別だと分かる。押したときだけ通る経路なので出しすぎにはならない。
function frag.guard_execute(frame)
    local slotset = GET_CHILD_RECURSIVELY(frame, "fragmentation_slotset", "ui::CSlotSet")
    if not slotset then
        return
    end
    AUTO_CAST(slotset)
    local count = slotset:GetSlotCount()
    -- **前回の実行が始まらなかったぶんを、選択へ戻してから数える。**
    -- 素は延性値 / リロール回数を持つものが 1 つでもあると ui.MsgBox を出して実行を
    -- 委ねるので、「いいえ」で閉じると実行は起きない = FRAGMENTATION_END も来ない。
    -- ここで戻さないと、直前に「終わったら選び直します」と伝えた超過分が、次に押した
    -- ときの覚え直しで黙って消える(利用者は手で選び直すことになる)。
    -- 退避は一覧が作り直されると捨てるので(frag.pick_pending)、ここへ残っているのは
    -- 「まだ一度も実行に移れていない、同じ一覧に対する意思」だけ。
    local restored = 0
    if frag.pending ~= nil then
        -- **利用者が選び直していたら、退避は捨てる。** 確認ダイアログを「いいえ」で
        -- 閉じた後に選択を組み替えてから押し直した場合、黙って古い選択を足し戻すと
        -- **外したはずの耳飾りを破片化してしまう**(取り消せない)。前回そのまま実行
        -- しようとしていた顔ぶれ(frag.pending_kept)と今の選択が一致するときだけ、
        -- 「同じ意思の続き」と見なす
        local same = (frag.pending_kept ~= nil)
        local now = 0
        for i = 0, count - 1 do
            local slot = slotset:GetSlotByIndex(i)
            if slot and slot:IsSelected() == 1 then
                now = now + 1
                local guid = slot:GetUserValue("FRAGMENTATION_GUID")
                if guid == nil or guid == "None" or not (frag.pending_kept and frag.pending_kept[guid]) then
                    same = false
                end
            end
        end
        if not same or now ~= (frag.pending_kept_n or -1) then
            core_g.vlog("mini_addons: 破片化 選択が変わっているので退避(%d 個)を捨てる", frag.pending_n or 0)
            frag.forget_pending()
        end
    end
    if frag.pending ~= nil then
        for i = 0, count - 1 do
            local slot = slotset:GetSlotByIndex(i)
            if slot and slot:GetIcon() ~= nil and slot:IsSelected() == 0 then
                local guid = slot:GetUserValue("FRAGMENTATION_GUID")
                if guid ~= nil and guid ~= "None" and frag.pending[guid] then
                    slot:Select(1)
                    restored = restored + 1
                end
            end
        end
        if restored > 0 then
            core_g.vlog("mini_addons: 破片化 実行に移れていなかった %d 個を選択へ戻した", restored)
        end
    end
    local selected, residue = 0, 0
    for i = 0, count - 1 do
        local slot = slotset:GetSlotByIndex(i)
        if slot and slot:IsSelected() == 1 then
            if slot:GetIcon() == nil then
                slot:Select(0) -- (a) これが残っていると素が nil を触って落ちる
                residue = residue + 1
            else
                selected = selected + 1
            end
        end
    end
    -- 素はこの後、選択スロットごとに GUID からインベントリの実体を引き直す。
    --   local targetinvitem = session.GetInvItemByGuid(guid)
    --   local targetitemobj = GetIES(targetinvitem:GetObject());
    -- ここも **nil を確かめずに触る**ので、引けない GUID が 1 つでもあると落ちる。
    -- 同じ GUID が 2 つのスロットに乗っていると session.AddItemID が二重に積まれる。
    -- どちらも枠を広げて枚数が増えるほど当たりやすくなるので、手前で数えて外す。
    local unresolved, duplicated = 0, 0
    local seen = {}
    for i = 0, count - 1 do
        local slot = slotset:GetSlotByIndex(i)
        if slot and slot:IsSelected() == 1 then
            local guid = slot:GetUserValue("FRAGMENTATION_GUID")
            if guid == nil or guid == "None" then
                slot:Select(0)
                unresolved = unresolved + 1
                selected = selected - 1
            elseif seen[guid] then
                slot:Select(0) -- 2 枚目以降は外す(素は同じ実体を二重に積んでしまう)
                duplicated = duplicated + 1
                selected = selected - 1
            else
                seen[guid] = true
                local inv_item = session.GetInvItemByGuid(guid)
                local obj = inv_item and GetIES(inv_item:GetObject())
                if not obj then
                    slot:Select(0)
                    unresolved = unresolved + 1
                    selected = selected - 1
                end
            end
        end
    end
    -- **一度に送れる枚数の頭打ち。** 素は shared_item_earring.MAX_SLOT_CNT(既定 25)を
    -- 前提に組まれていて、FRAGMENTATION_EXECUTE の
    --   if slotCnt > shared_item_earring.MAX_SLOT_CNT then return end
    -- が「枠より多い枚数は実行させない」歯止めになっている。こちらは枠を広げるために
    -- この上限を col*row へ書き換えるので、その歯止めが外れる。
    --
    -- **100 件を選んで実行するとクライアントが落ちる**(実機で再現・2026-09-11)。
    -- 素の Lua は最後まで通り、session.AddItemID も 100 件積み終えて
    -- _FRAGMENTATION_EXECUTE まで到達する。落ちているのはその先の
    -- item.DialogTransaction("FRAGMENTATION_BUNDLE_ITEMS", ...) で、pcall で包んでも
    -- Lua エラーは出ない = ネイティブ側。よってクライアントからは枚数で避けるしかない。
    --
    -- 上限は**素が持っていた値**(frag.base_max_slot)を使う。25 を直書きすると、
    -- IMC が素の上限を変えたときに付いていけない。
    local limit = frag.base_max_slot or 25
    local trimmed = 0
    -- 押すたびに覚え直す(前回の積み残しを引きずらない)。ここに入るのは
    -- **利用者が今まさに選んでいたものの GUID** だけで、位置では覚えない。
    -- 位置で覚えると、実行後に詰め直された別の耳飾りを掴んでしまう
    frag.forget_pending()
    if selected > limit then
        local kept = 0
        local keep_set = {}
        local rest = {}
        local rest_n = 0
        for i = 0, count - 1 do
            local slot = slotset:GetSlotByIndex(i)
            if slot and slot:IsSelected() == 1 then
                if kept < limit then
                    kept = kept + 1
                    local guid = slot:GetUserValue("FRAGMENTATION_GUID")
                    if guid ~= nil and guid ~= "None" then
                        keep_set[guid] = true
                    end
                else
                    local guid = slot:GetUserValue("FRAGMENTATION_GUID")
                    if guid ~= nil and guid ~= "None" then
                        rest[guid] = true
                        rest_n = rest_n + 1
                    end
                    slot:Select(0)
                    trimmed = trimmed + 1
                end
            end
        end
        selected = kept
        if rest_n > 0 then
            frag.pending = rest
            frag.pending_n = rest_n
            -- 次に押されたとき「選び直されていないか」を見るための控え
            frag.pending_kept = keep_set
            frag.pending_kept_n = kept
        end
        -- **黙って減らさない。** 選んだつもりの枚数と実行される枚数が食い違うので、
        -- 何個だけ実行するのか・残りはどうすればよいのかをその場で伝える
        -- **「自動」の ON / OFF で言うことが変わるので、3 言語とも分岐させること。**
        -- 片方だけ直すと、その言語の利用者だけが「押してください」を知らされないまま
        -- 待ち続ける(逆に、自動なのに押してくださいと言われる)
        local auto = frag.auto_enabled()
        ui.SysMsg(frag.lang(
            "{ol}{#00BFFF}[Nexus Addons P] 一度に破片化できるのは " .. limit ..
            " 個までです。先頭の " .. limit .. " 個を実行します(残り " .. trimmed ..
            (auto and " 個は、終わったら自動で続けます)" or
                " 個は、終わったら選び直すので、もう一度押してください)"),
            "{ol}{#00BFFF}[Nexus Addons P] 한 번에 파편화할 수 있는 것은 " .. limit ..
            " 개까지입니다. 앞의 " .. limit .. " 개를 실행합니다(남은 " .. trimmed ..
            (auto and " 개는 끝나면 자동으로 이어서 진행합니다)" or
                " 개는 끝나면 다시 선택하므로 한 번 더 눌러 주세요)"),
            "{ol}{#00BFFF}[Nexus Addons P] Only " .. limit ..
            " items can be fragmented at once. Running the first " .. limit .. " (the remaining " ..
            trimmed .. (auto and " continue automatically when it finishes)" or
                " are re-selected when it finishes - press Fragment again)")))
    end
    if residue > 0 or unresolved > 0 or duplicated > 0 or trimmed > 0 or restored > 0 then
        slotset:MakeSelectionList()
    end
    -- (b) 素は MAX_SLOT_CNT までを回すので、実際のスロット数より多いと nil を掴む。
    -- 上げたのはこちらなので、実際の枚数へ合わせ直す(素は slotCnt > MAX なら
    -- 何もせず戻る作りなので、減らす方向へ丸めてはいけない)
    local max_slot = type(shared_item_earring) == "table" and shared_item_earring.MAX_SLOT_CNT or nil
    if max_slot ~= nil and max_slot ~= count then
        shared_item_earring.MAX_SLOT_CNT = count
    end
    core_g.vlog(
        "mini_addons: 破片化 実行前 スロット=%d 選択=%d 空の選択=%d 引けないGUID=%d 重複GUID=%d 減らした=%d 一度の上限=%d 枠の上限=%s",
        count, selected, residue, unresolved, duplicated, trimmed, limit, tostring(max_slot))
end

-- 素の実行。**素の中身は写さず**、上の後始末をしてから素へ渡す
function Mini_addons_FRAGMENTATION_EXECUTE(parent, ctrl)
    local origin = g.FUNCS["FRAGMENTATION_EXECUTE"]
    -- **枠を広げている間だけ**触る(素の窓しか使っていない利用者の挙動は変えない)
    if frag.enabled() or frag.applied then
        local frame = ui.GetFrame(frag.FRAME)
        if frame then
            local ok, err = pcall(frag.guard_execute, frame)
            if not ok then
                -- **素へ進めないこと。** guard_execute は最後で MAX_SLOT_CNT を選択数へ
                -- 合わせ直すので、途中で落ちると枠を広げたままの大きい値が残る。
                -- 素の「枠より多い枚数は実行させない」歯止めも効かないまま実行へ入り、
                -- この修正が塞いだはずの「大量選択で落ちる」状態がそのまま再現する
                core_g.vlog("{#FF6347}mini_addons: 破片化の実行前チェック FAILED{/} %s", tostring(err))
                ui.SysMsg(frag.lang("{ol}{#FF6347}[Nexus Addons P] 破片化の準備に失敗したので実行を中止しました。選び直してもう一度お試しください",
                    "{ol}{#FF6347}[Nexus Addons P] 파편화 준비에 실패하여 실행을 중단했습니다. 다시 선택해 주세요",
                    "{ol}{#FF6347}[Nexus Addons P] Preparation failed - execution cancelled. Please re-select and try again"))
                frag.forget_pending()
                return
            end
        end
    end
    if not origin then
        return
    end
    -- **素を pcall で包む。** ボタンのイベントスクリプトで落ちると debug_log.txt にも
    -- 何も残らない(あれは RegisterMsg 経由の分だけ)ので、Lua エラーならここで捕まえる。
    -- 握り潰さず必ずログに出すこと
    local ok, err = pcall(origin, parent, ctrl)
    if not ok then
        core_g.vlog("{#FF6347}mini_addons: 破片化の実行(素)が FAILED{/} %s", tostring(err))
        return
    end
    core_g.vlog("mini_addons: 破片化 素の実行から戻った")
end

-- 素の送信本体(確認ダイアログの「はい」からも呼ばれる)。
-- **素は写さない。** 何件をまとめて送ろうとしたかだけ記録して素へ渡す
function Mini_addons__FRAGMENTATION_EXECUTE(tab_index)
    local origin = g.FUNCS["_FRAGMENTATION_EXECUTE"]
    if not origin then
        return
    end
    local cnt = "?"
    -- **関数を渡さず、ここで呼ぶこと。** pcall(session.GetItemIDList) と書くと
    -- docs/vanilla_api.py の検査が「素の API を使っている」と見なせず、一覧に載らない
    local ok_list, list = pcall(function()
        return session.GetItemIDList()
    end)
    if ok_list and list ~= nil then
        local ok_cnt, n = pcall(function()
            return list:Count()
        end)
        if ok_cnt then
            cnt = tostring(n)
        end
    end
    core_g.vlog("mini_addons: 破片化 送信する tab=%s 件数=%s", tostring(tab_index), cnt)
    local ok, err = pcall(origin, tab_index)
    if not ok then
        core_g.vlog("{#FF6347}mini_addons: 破片化の送信(素)が FAILED{/} %s", tostring(err))
        return
    end
    core_g.vlog("mini_addons: 破片化 送信から戻った")
end

-- 素は破片化が終わると一覧を作り直す。**その更新のときだけ**続きを選び直したいので、
-- ここで印を立てる(絞り込みやタブ切り替えの更新では立てない = 続きは選ばれない)。
-- 立てたら必ず倒すこと。倒し忘れると、以降どの更新でも勝手に選択が付く
function Mini_addons_ON_FRAGMENTATION_END(frame)
    local origin = g.FUNCS["ON_FRAGMENTATION_END"]
    frag.resume = true
    local ok, err = pcall(function()
        if origin then
            origin(frame)
        end
    end)
    frag.resume = false
    if not ok then
        core_g.vlog("{#FF6347}mini_addons: 破片化の完了処理(素)が FAILED{/} %s", tostring(err))
    end
end

-- 破片化の窓を閉じたら、条件の窓も一緒に畳む(単体で残っても操作先が無い)
function Mini_addons_FRAGMENTATION_CLOSE(frame)
    local origin = g.FUNCS["FRAGMENTATION_CLOSE"]
    if origin then
        origin(frame)
    end
    -- 閉じたら続きは忘れる(次に開いたときに勝手に選択が付かないように)
    frag.forget_pending()
    Mini_addons_frag_keep_close()
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
    -- **失敗したら続きは抱えない。** 何が起きたか分からない状態で次の 25 個を
    -- 選び直すと、利用者が意図しない実行につながる
    frag.forget_pending()
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
    g.setup_hook(Mini_addons_FRAGMENTATION_CLOSE, "FRAGMENTATION_CLOSE")
    -- 素の実行ボタン。**素が nil を触って落ちるのを手前で止める**(frag.guard_execute)
    if type(_G["FRAGMENTATION_EXECUTE"]) == "function" then
        g.setup_hook(Mini_addons_FRAGMENTATION_EXECUTE, "FRAGMENTATION_EXECUTE")
        if type(_G["_FRAGMENTATION_EXECUTE"]) == "function" then
            g.setup_hook(Mini_addons__FRAGMENTATION_EXECUTE, "_FRAGMENTATION_EXECUTE")
        end
        if type(_G["ON_FRAGMENTATION_END"]) == "function" then
            g.setup_hook(Mini_addons_ON_FRAGMENTATION_END, "ON_FRAGMENTATION_END")
        end
    else
        core_g.vlog("mini_addons: FRAGMENTATION_EXECUTE が無いので実行前チェックは掛けない")
    end
    core_g.register_msg("FRAGMENTATION_BUNDLE_ITEMS_FAILED", "Mini_addons_FRAGMENTATION_BUNDLE_FAILED")
end
