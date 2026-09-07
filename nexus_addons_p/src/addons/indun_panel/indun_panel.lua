-- indun_panel ここから
local induns = {{
    -- チャレンジ / 分裂は Lv 帯(段)が複数あり、その一覧は CHALLENGE_TIERS / SINGULARITY_TIERS が持つ。
    -- ここに入場 ID を並べていた頃は段の数だけ描画関数が呼ばれていた(1 行を 3 回描いていた)うえ、
    -- Lv 上限が上がるたびに 2 か所へ書く必要があったので、ID は段の表へ寄せた。
    challenge = {
        jp = "チャレンジ",
        icon = {"Item", 490363}
    }
}, {
    singularity = {
        jp = "分裂特異点",
        icon = {"Item", 11030017}
    }
}, {
    -- Lv560。実装時点では Solo/Auto のみで Hard(パーティ) は未実装(indun ID 735 が欠番)。
    -- 追加されたら h = 735 を足すだけでよい(HARD ボタンは h があるときだけ出る)。
    -- アイコンは**入場券**を使う。他のレイドはボス(Monster)の画像だが、
    -- Uriel 系は monster.ies の Icon が 9 体すべて "boss_uriel" の 1 枚で、
    -- ボスの画像にすると偽りの輝翼と堕落した審判の翼が同じ絵になって見分けが付かない。
    -- 入場券なら item_Boss_LightUriel_Auto_Enter / item_Boss_DarkUriel_Auto_Enter で別絵になる。
    -- 参照する ID は raid_tbl の期限なし(通常)の券。嘆きの墓地 / 共鳴の聖所と同じ持ち方。
    light_uriel = {
        s = 734,
        a = 733,
        ac = 80049,
        jp = "偽りの輝翼",
        icon = {"Item", 11210072}
    }
}, {
    -- Lv560。上と対の実装で、こちらも Hard(パーティ) は未実装(indun ID 738 が欠番)。
    dark_uriel = {
        s = 737,
        a = 736,
        ac = 80051,
        jp = "堕落した審判の翼",
        icon = {"Item", 11210076}
    }
}, {
    zmei = {
        h = 731,
        s = 730,
        a = 729,
        ac = 80047,
        jp = "ズメイ",
        icon = {"Monster", 71076}
    }
}, {
    belliora = {
        h = 727,
        s = 726,
        a = 725,
        ac = 80045,
        jp = "ベリオラ",
        icon = {"Monster", 71043}
    }
}, {
    laimara = {
        h = 724,
        s = 723,
        a = 722,
        ac = 80043,
        jp = "ライマラ",
        icon = {"Monster", 71040}
    }
}, {
    ledania = {
        h = 718,
        s = 717,
        a = 716,
        ac = 80039,
        jp = "レダニア",
        icon = {"Monster", 59864}
    }
}, {
    neringa = {
        h = 709,
        s = 708,
        a = 707,
        ac = 80035,
        jp = "ネリンガ",
        icon = {"Monster", 59856}
    }
}, {
    golem = {
        h = 712,
        s = 711,
        a = 710,
        ac = 80037,
        jp = "ゴーレム",
        icon = {"Monster", 59859}
    }
}, {
    merregina = {
        s = 696,
        a = 695,
        h = 697,
        ac = 80032,
        jp = "メレジナ",
        icon = {"Monster", 59824}
    }
}, {
    slogutis = {
        s = 689,
        a = 688,
        h = 690,
        ac = 80031,
        jp = "スローガティス",
        icon = {"Monster", 59798}
    }
}, {
    upinis = {
        s = 686,
        a = 685,
        h = 687,
        ac = 80030,
        jp = "ウピニス",
        icon = {"Monster", 59795}
    }
}, {
    roze = {
        s = 680,
        a = 679,
        h = 681,
        ac = 80015,
        jp = "ロゼ",
        icon = {"Monster", 59773}
    }
}, {
    falouros = {
        s = 677,
        a = 676,
        h = 678,
        ac = 80017,
        jp = "ファロウロス",
        icon = {"Monster", 59760}
    }
}, {
    reservoir = {
        s = 674,
        a = 673,
        h = 675,
        ac = 80016,
        jp = "プロパゲーター",
        icon = {"Monster", 59752}
    }
}, {
    jellyzele = {
        s = 672,
        a = 671,
        h = 670,
        jp = "ジェリージェル",
        icon = {"Monster", 59730}
    }
}, {
    delmore = {
        s = 667,
        a = 666,
        h = 665,
        jp = "デルムーア",
        icon = {"Monster", 59690}
    }
}, {
    giltine = {
        s = 669,
        a = 635,
        h = 628,
        jp = "ギルティネ",
        icon = {"Monster", 59549}
    }
}, {
    memory = {
        s = 661,
        a = 662,
        h = 663,
        jp = "焔の記憶",
        icon = {"Item", 11100001}
    }
}, {
    telharsha = {
        id = 623,
        jp = "テルハルシャ",
        icon = {"Monster", 59477}
    }
}, {
    bernice = {
        id = 201,
        jp = "ヴェルニケ",
        icon = {"Item", 11030257}
    }
}, {
    wailing = {
        id = 684,
        jp = "嘆きの墓地",
        icon = {"Item", 960213}
    }
}, {
    -- Lv560。嘆きの墓地と同じ「入場券で入るパーティダンジョン」型
    zawra = {
        id = 732,
        jp = "共鳴の聖所",
        icon = {"Item", 11210069}
    }
}, {
    jsr = {
        id = 0,
        jp = "ボス協同戦",
        icon = {}
    }
}}

-- パネルの右側へ並べるショートカット。
--
-- **並びの出どころはここ 1 つにする。** 以前はパネル側(展開 / 畳みの 2 か所)に
-- button_keys のべた書き、設定ウィンドウ側にアイコンの表、と 3 か所に同じ並びがあった。
-- 利用者が▲▼で並べ替えられるようにすると、ずれた瞬間に「どのチェックがどのボタンか
-- 分からない」状態になるので、定義をここへ寄せて全員がここを見る。
--
-- city = 都市に居るときだけ出るボタン(Indun_panel_create_shortcut_button の g.get_map_type 判定)。
-- **足したときは Indun_panel_create_shortcut_button の分岐と、設定の既定 / バックフィル
--  (Indun_panel_load_settings の col_keys)にも足すこと。**
local INDUN_PANEL_SHORTCUTS = {{
    key = "tos",
    img = "icon_item_Tos_Event_Coin",
    size = 25,
    city = true,
    jp = "TOSイベントショップ",
    en = "TOS Event Shop"
}, {
    key = "gabija",
    img = "goddess_shop_btn",
    size = 29,
    city = true,
    jp = "ガビヤショップ",
    en = "Gabija Shop"
}, {
    key = "vakarine",
    img = "goddess2_shop_btn",
    size = 29,
    city = true,
    jp = "ヴァカリネショップ",
    en = "Vakarine Shop"
}, {
    key = "rada",
    img = "goddess3_shop_btn",
    size = 29,
    city = true,
    jp = "ラダショップ",
    en = "Rada Shop"
}, {
    key = "jurate",
    img = "goddess4_shop_btn",
    size = 29,
    city = true,
    jp = "ユラテショップ",
    en = "Jurate Shop"
}, {
    key = "austeja",
    img = "goddess5_shop_btn",
    size = 29,
    jp = "アウステヤショップ",
    en = "Austeja Shop"
}, {
    key = "saule",
    img = "icon_item_season_coin_Saule",
    size = 29,
    jp = "サウレショップ",
    en = "Saule Shop"
}, {
    key = "pvp_mine",
    img = "pvpmine_shop_btn_total",
    size = 29,
    jp = "傭兵団ショップ",
    en = "Mercenary Shop"
}, {
    key = "market",
    img = "market_shortcut_btn02",
    size = 29,
    city = true,
    jp = "マーケット",
    en = "Market"
}, {
    key = "craft",
    img = "icon_fullscreen_menu_equipment_processing",
    size = 28,
    city = true,
    jp = "装備加工",
    en = "Equipment Processing"
}, {
    key = "leticia",
    img = "icon_fullscreen_menu_letica",
    size = 28,
    city = true,
    jp = "レティーシャへ移動",
    en = "Leticia Move"
}}

-- ===== 並べ替え(▲▼) =====
--
-- 控えは settings.col_order(ショートカット)と settings.row_order(コンテンツの行)に
-- 「キー → 何番目か」で持つ。**セットとは無関係の共通設定**にしてある(段の設定と同じ)。
-- セットごとに順番まで変えられると、セットを切り替えるたびに並びが動いて位置を覚えられない。
--
-- **番号を持たないキーは末尾へ回す。** 新しいダンジョンやショートカットを足したとき、
-- 既に並べ替えている利用者の並びの真ん中へ知らない行が割り込まないようにするため
-- (core/90_addons_menu.lua の Addons Menu の並べ替えと同じ考え方)。
-- table.sort は安定ではないので、元の位置(idx)を最後の決め手にする。
local function Indun_panel_order_tbl(name)
    local settings = g.indun_panel_settings
    if not settings then
        return {}
    end
    if type(settings[name]) ~= "table" then
        settings[name] = {}
    end
    return settings[name]
end

-- items = {{key = "...", ...}, ...} を利用者の並びへ直した写しを返す。
-- **元のテーブルを並べ替えないこと**(定義の並びは「まだ並べ替えていない人」の既定)。
local function Indun_panel_sort_by_order(items, order_name)
    local order = Indun_panel_order_tbl(order_name)
    local sorted = {}
    for idx, item in ipairs(items) do
        sorted[idx] = {
            item = item,
            idx = idx,
            order = tonumber(order[item.key]) or (10000 + idx)
        }
    end
    table.sort(sorted, function(a, b)
        if a.order ~= b.order then
            return a.order < b.order
        end
        return a.idx < b.idx
    end)
    local out = {}
    for i, row in ipairs(sorted) do
        out[i] = row.item
    end
    return out
end

-- 利用者の並びに直したショートカットの一覧。
local function Indun_panel_ordered_shortcuts()
    return Indun_panel_sort_by_order(INDUN_PANEL_SHORTCUTS, "col_order")
end

-- 利用者の並びに直したコンテンツの行。induns は {key = value} が 1 組ずつ入った
-- 配列なので、並べ替えに使えるよう {key = ..., def = ...} へならしてから渡す。
local function Indun_panel_ordered_induns()
    local items = {}
    for i, entry in ipairs(induns) do
        local key, value = next(entry)
        items[i] = {
            key = key,
            def = value
        }
    end
    return Indun_panel_sort_by_order(items, "row_order")
end

-- ▲▼ を押したときの並べ直し。**一覧全体へ 1 から番号を振り直す。**
-- 隣と番号を入れ替えるだけだと、番号を持たない行(まだ並べ替えていないもの)が
-- 混ざったときに「押しても動かない」組み合わせが残る。
--
-- is_visible を渡すと、**そこで偽になる行を飛ばして次の行と入れ替える**。
-- 設定の「ON のものだけ表示」で絞っている間に使う。隠れている行と素直に入れ替えると、
-- 画面上は何も動かないので「押しても効かない」ように見える。
-- 飛ばされた行はその場に留まる(画面に出ていないものを勝手に動かさない)。
--
-- 戻り値は動かせたかどうか(端では何もしない)。
local function Indun_panel_move_in_order(ordered, order_name, key, delta, is_visible)
    local at
    for idx, item in ipairs(ordered) do
        if item.key == key then
            at = idx
            break
        end
    end
    if not at then
        return false
    end
    local to = at + delta
    if is_visible then
        while to >= 1 and to <= #ordered and not is_visible(ordered[to]) do
            to = to + delta
        end
    end
    if to < 1 or to > #ordered then
        return false
    end
    ordered[at], ordered[to] = ordered[to], ordered[at]
    local order = Indun_panel_order_tbl(order_name)
    for idx, item in ipairs(ordered) do
        order[item.key] = idx
    end
    g.vlog("indun_panel: %s の %s を %d 番目から %d 番目へ動かした", order_name, tostring(key), at, to)
    return true
end

-- パネルの背景。**選べるものはここ 1 か所に持つ。**
-- 以前は `SKIN SELECT` ボタン → コンテキストメニューで選ぶ作りだったが、
-- **今どれを使っているのかが画面のどこにも出ていなかった**(押してみるまで分からず、
-- メニューにも印が付かない)。設定では 3 つを横に並べて、選んでいるものを赤くする。
local INDUN_PANEL_SKINS = {{
    key = "chat_window_2",
    jp = "いつもの",
    en = "The usual"
}, {
    key = "bg",
    jp = "黒",
    en = "Solid black"
}, {
    key = "bg2",
    jp = "透明度高め",
    en = "High transparency"
}}

-- 行の絵。**パネルと設定で同じものを出す**(設定の一覧で「パネルのどの行か」を
-- 目で追い直さずに済むように)。ボス協同戦だけは相手が週ごとに変わるので、
-- 固定の ID ではなくその週のフィールドボスから引く。
function Indun_panel_row_icon_class(key, def)
    if key == "jsr" then
        local fieldbossPattern = session.fieldboss.GetPatternInfo()
        return GetClass("Monster", fieldbossPattern.MonsterClassName)
    elseif def and def.icon and def.icon[1] then
        return GetClassByType(def.icon[1], def.icon[2])
    end
    return nil
end

-- 並べ替えの規則は実機でしか目に見えず、「番号を持たない行の扱い」と「table.sort が
-- 安定ではないこと」で静かに壊れる。docs/tests/test_indun_panel_order.lua から呼べるよう
-- g へも載せておく(呼び出し側は上のローカルをそのまま使う。
--  core/90_addons_menu.lua の g.addons_menu_collect_items と同じやり方)。
g.indun_panel_shortcut_defs = INDUN_PANEL_SHORTCUTS
g.indun_panel_ordered_shortcuts = Indun_panel_ordered_shortcuts
g.indun_panel_ordered_induns = Indun_panel_ordered_induns
g.indun_panel_move_in_order = Indun_panel_move_in_order

-- チャレンジ / 分裂の段(Lv 帯)の一覧は、下のほうの CHALLENGE_TIERS / SINGULARITY_TIERS が持つ。
-- **設定の読み込みや設定ウィンドウはそれより前に定義される**ので素では見えない
-- (Lua の local は宣言行より後ろからしか見えない。CLAUDE.md「local function は
--  呼び出しより前で定義する」と同じ話)。段の顔ぶれを 2 か所に書かずに済ませるため、
-- ここで前方宣言して下で代入する。
local CHALLENGE_TIERS, SINGULARITY_TIERS
-- 入場券型のパーティダンジョン(嘆きの墓地 / 共鳴の聖所)の表も同じ理由で
-- 前方宣言する。Indun_panel_enter_solo がこの表の open_only を見るため。
local DUNGEON_TICKET_CONFIG

-- 段の表示切替(520 / 540 / 560)を持つ行。
-- prefix は設定ウィンドウのチェックボックス名に使う。名前から段を引き直すので、
-- **他のチェックボックス名と混ざらない綴りにすること**(Indun_panel_ischecked 参照)。
local INDUN_PANEL_TIER_ROWS = {{
    key = "challenge",
    prefix = "ch",
    jp = "チャレンジ",
    en = "Challenge"
}, {
    key = "singularity",
    prefix = "sg",
    jp = "分裂特異点",
    en = "Singularity"
}}

-- 行のキー → 段の表。前方宣言した local を関数越しに引くための入れ物
-- (宣言時点では nil なので、テーブルへ直接入れておくことはできない)。
function Indun_panel_tiers_of(row_key)
    if row_key == "challenge" then
        return CHALLENGE_TIERS
    elseif row_key == "singularity" then
        return SINGULARITY_TIERS
    end
    return nil
end

-- 段の設定キー。**数字だけのキーにしないこと。** "520" のような数字の文字列を
-- JSON の object キーに使うと、実装によっては配列と取り違えられる。
function Indun_panel_tier_key(label)
    return "lv" .. label
end

-- その段を出すか。**設定が無いときは出す**(古い保存の取りこぼしで消えないように)。
function Indun_panel_tier_enabled(row_key, label)
    local tiers = g.indun_panel_settings and g.indun_panel_settings.tiers
    local row = tiers and tiers[row_key]
    if not row then
        return true
    end
    return row[Indun_panel_tier_key(label)] ~= 0
end

-- 段のチェックボックスの見た目。**灰色は「その行そのものが OFF」の印。**
-- 段は行にぶら下がっているので、行を非表示にしていると段をどう触っても何も出ない。
-- 効かない設定だと分かるように色を落とす。**段それぞれのチェックの有無では色を変えない**
-- (チェックボックスの✓で分かるうえ、上の意味とぶつかる)。
-- 文字を作る場所を 1 か所にしておかないと、押した直後の塗り替え(Indun_panel_ischecked)と
-- 開き直したときの色が食い違う。
function Indun_panel_tier_label_text(label, row_enabled)
    return string.format("{ol}%s{s16}%s", row_enabled and "{#FFFFFF}" or "{#808080}", label)
end

-- 選択中のセットで、その行を表示する設定になっているか。
function Indun_panel_row_checked(row_key)
    local use_tbl = g.indun_panel_settings and g.indun_panel_settings[g.indun_panel_settings.etc.use_set]
    return use_tbl ~= nil and use_tbl[row_key] == 1
end

-- 行の ON/OFF を切り替えたときに、その行の段のチェックの色を塗り替える。
-- 設定ウィンドウは開いたままなので、ここで直さないと開き直すまで色が古いままになる。
function Indun_panel_tier_refresh_color(indun_panel, row_key)
    local row = Indun_panel_tier_row_of(row_key)
    local tiers = row and Indun_panel_tiers_of(row_key)
    if not tiers or not indun_panel then
        return
    end
    local row_enabled = Indun_panel_row_checked(row_key)
    for _, tier in ipairs(tiers) do
        -- パネル側から呼ばれたときは段のチェックが無い(設定ウィンドウを開いていない)ので、
        -- 引けなければ何もしない
        local checkbox = GET_CHILD_RECURSIVELY(indun_panel, row.prefix .. tier.label)
        if checkbox then
            AUTO_CAST(checkbox)
            checkbox:SetText(Indun_panel_tier_label_text(tier.label, row_enabled))
        end
    end
end

-- 行のキー → INDUN_PANEL_TIER_ROWS の 1 件。段を持たない行では nil。
function Indun_panel_tier_row_of(row_key)
    for _, row in ipairs(INDUN_PANEL_TIER_ROWS) do
        if row.key == row_key then
            return row
        end
    end
    return nil
end

-- 段を持つ行(チャレンジ / 分裂)を出すか。**全部の段を外したら行ごと畳む。**
-- 残すと見出しだけの空の行になって、壊れているように見える。
-- 段を持たない行はここでは判断しないので、そのまま true を返す。
function Indun_panel_tier_row_visible(row_key)
    local tiers = Indun_panel_tiers_of(row_key)
    if not tiers then
        return true
    end
    for _, tier in ipairs(tiers) do
        if Indun_panel_tier_enabled(row_key, tier.label) then
            return true
        end
    end
    return false
end

-- ── パネルの表示倍率 ───────────────────────────────────────────
-- **フレームごと拡縮する素の API は無い。** 実機で使えるのは次の 2 つだけで、
-- どちらもフレームの中身をまとめて縮める用途には使えない(調査済み・繰り返さないこと)。
--   * `SetScale(x, y)` … picture / richtext などのコントロール用。frame には効かない
--   * `SetScaleX(比率, 秒)` … 「何秒かけて何倍にするか」のアニメーション(uiscp/fade.lua)
-- そのため座標・大きさ・文字の大きさを 1 つずつ掛ける。
--
-- **設定ウィンドウは掛けない。** あちらはパネルとは別のポップアップで、
-- 500 x 640 と決め打ちにしてある(1280x720 に収まる大きさ。タブでも中身の量でも
-- 変えない ⇒ INDUN_PANEL_CONFIG_W のコメント)。掛けるとその前提が崩れる。
g.INDUN_PANEL_SCALES = {100, 90, 80}

function Indun_panel_scale()
    local settings = g.indun_panel_settings
    local v = settings and settings.etc and tonumber(settings.etc.scale)
    for _, s in ipairs(g.INDUN_PANEL_SCALES) do
        if s == v then
            return v / 100
        end
    end
    return 1
end

-- 座標と大きさ。**四捨五入する。** 切り捨てだと、行を積み上げるたびに 1px ずつ
-- 詰まっていって下のほうの行が重なる。
function Indun_panel_s(v)
    return math.floor(v * Indun_panel_scale() + 0.5)
end

-- 文字の大きさ。**`{sNN}` は実在するサイズにしか効かない**(無いサイズを書くと
-- 既定の大きさのままになる)ので、素のクライアントが使っているサイズへ丸める。
-- 素の inventory.lua などは 14/16/18/20/22 のように偶数しか使っていない。
g.INDUN_PANEL_FONT_SIZES = {10, 12, 14, 16, 18, 20, 22, 24}

function Indun_panel_f(v)
    local scaled = Indun_panel_s(v)
    local picked = g.INDUN_PANEL_FONT_SIZES[1]
    for _, size in ipairs(g.INDUN_PANEL_FONT_SIZES) do
        if size <= scaled then
            picked = size
        end
    end
    return string.format("{s%d}", picked)
end

-- ── 入場券の使用順 ─────────────────────────────────────────────
-- 券を使う経路は 6 つある(レイド 12 種 / チャレンジ / 分裂特異点 / ヴェルニース /
-- テルハーシャ / 嘆きの墓地・共鳴の聖所)。どれも「持っている券から 1 枚選ぶ」という
-- 同じことをしているのに、**それぞれ別々に書かれていた**ので、経路ごとに順序が
-- 食い違い、片方だけ壊れても気付けなかった。選び方をここへ集める。
--
-- 分類は **ID の直書きではなく所持品の実物から決める**。段が増えるたびに
-- 「どれが取引不可か」を手で振り分ける作りだと、書き間違えても実機で券を 1 枚
-- 溶かすまで気付けない。見方は素のクライアントに合わせてある
-- (`BelongingCount` は exchange.lua、`IsEnableMarketTrade` は market_sell.lua)。
--
-- **既定は現行の挙動そのまま。** 並べ替えは設定ウィンドウの「入場券」タブで行う。
g.INDUN_PANEL_TICKET_KINDS = {{
    key = "expiring",
    jp = "期限付き",
    en = "Time-limited",
    jp_note = "放っておくと消えるので先に使う",
    en_note = "It expires if left alone"
}, {
    key = "no_trade",
    jp = "取引不可",
    en = "Untradeable",
    jp_note = "売れないので温存する意味が無い",
    en_note = "It cannot be sold, so there is no point saving it"
}, {
    key = "buy",
    jp = "購入",
    en = "Buy",
    jp_note = "ショップの購入枠から買って使う(枠が無ければ飛ばす)",
    en_note = "Buy from the shop allowance (skipped when there is none)"
}, {
    key = "tradable",
    jp = "取引可",
    en = "Tradable",
    jp_note = "売れる券。後ろへ置くほど温存される",
    en_note = "A ticket you could sell; the later it is, the more it is saved"
}}

-- 順序を持つグループ。**「購入」を持たない経路がある**ので、グループごとに
-- 並ぶ分類が違う(レイドの券はショップで売っていない)。
--
-- default は **今の実装が実際に行っている順序**。ここを yoma16 版の推奨順
-- (期限付き → 取引不可 → 購入 → 取引可)にはしていない。既定を変えると、
-- 設定を触っていない利用者の券の使われ方が黙って変わるため。
g.INDUN_PANEL_TICKET_GROUPS = {{
    key = "raid",
    jp = "レイド",
    en = "Raids",
    kinds = {"expiring", "no_trade", "tradable"},
    default = {"expiring", "no_trade", "tradable"}
}, {
    key = "challenge",
    jp = "チャレンジ / 分裂特異点",
    en = "Challenge / Singularity",
    kinds = {"expiring", "no_trade", "buy", "tradable"},
    default = {"expiring", "buy", "no_trade", "tradable"}
}, {
    key = "other",
    jp = "その他(ヴェルニース / テルハーシャ / 嘆きの墓地 / 共鳴の聖所)",
    en = "Other (Bernice / Telharsha / Wailing / Resonance)",
    kinds = {"expiring", "no_trade", "tradable", "buy"},
    default = {"expiring", "no_trade", "tradable", "buy"}
}}

function Indun_panel_ticket_group_def(group_key)
    for _, def in ipairs(g.INDUN_PANEL_TICKET_GROUPS) do
        if def.key == group_key then
            return def
        end
    end
    return nil
end

function Indun_panel_ticket_kind_def(kind_key)
    for _, def in ipairs(g.INDUN_PANEL_TICKET_KINDS) do
        if def.key == kind_key then
            return def
        end
    end
    return nil
end

-- 保存済みの並びを、そのグループが持つ分類ちょうどへ直した写しを返す。
-- **保存された配列をそのまま信用しないこと。** 手で書き換えられていることもあるし、
-- 後から分類を足したときに古い保存には入っていない。知らないものは捨て、
-- 足りないものは既定の並びの順で末尾へ足す(1 つも欠けさせない)。
function Indun_panel_ticket_order(group_key)
    local def = Indun_panel_ticket_group_def(group_key)
    if not def then
        return {}
    end
    local settings = g.indun_panel_settings
    local saved = settings and type(settings.ticket_order) == "table" and settings.ticket_order[group_key] or nil
    local allowed = {}
    for _, kind in ipairs(def.kinds) do
        allowed[kind] = true
    end
    local out = {}
    local seen = {}
    if type(saved) == "table" then
        for _, kind in ipairs(saved) do
            if allowed[kind] and not seen[kind] then
                seen[kind] = true
                table.insert(out, kind)
            end
        end
    end
    for _, kind in ipairs(def.default) do
        if not seen[kind] then
            seen[kind] = true
            table.insert(out, kind)
        end
    end
    return out
end

-- 券 1 枚の分類。**戻り値の 2 つめは期限の残り秒**(期限付きの中の並べ替えに使う)。
--
-- 取引できるかは 2 つ見る。片方だけでは足りない。
--   * BelongingCount    … その山のうち何個がアカウント固定か(手に入れ方で変わる)
--   * IsEnableMarketTrade … そもそも市場へ出せない品か(品目そのものの性質)
function Indun_panel_ticket_kind(inv_item)
    local item_obj = GetIES(inv_item:GetObject())
    local life = tonumber(GET_REMAIN_ITEM_LIFE_TIME(item_obj)) or 0
    if life > 0 then
        return "expiring", life
    end
    local belonging = tonumber(TryGetProp(item_obj, "BelongingCount", 0)) or 0
    if belonging > 0 then
        return "no_trade", 0
    end
    -- ネイティブのメソッドなので、無いクライアントに当たっても落とさない。
    local ok, tradable = pcall(function()
        return item_obj:IsEnableMarketTrade()
    end)
    if ok and tradable == false then
        return "no_trade", 0
    end
    return "tradable", 0
end

-- 候補の ClassID を分類ごとに仕分ける。
--
-- **同じ分類の中の並びも決めておくこと。** 以前は期限付きを「1 日を切っているか」
-- だけで table.sort していたが、1 日券は残り **ちょうど 86400 秒**で切っていないため
-- ほぼ全部が同点になり、table.sort は安定ではないので**どれが使われるか不定**だった。
-- 期限付きは残りの短い順、それ以外は渡された ID の並び順。どちらも同点は元の位置で割る。
--
-- 戻り値の 2 つめは**鍵の掛かっていた券の名前**。ここでは知らせないこと。
-- 使える券が別にあれば入場は成功するので、その場合に警告を出すと「押すたびに
-- ロックの注意が出るが、実際には入場できている」というノイズになる
-- (レイド / ヴェルニース / テルハーシャ / 嘆きの墓地の経路には元々この警告が無い)。
-- 知らせるかどうかは Indun_panel_consume_ticket が「何もできなかったか」で決める。
function Indun_panel_collect_tickets(ticket_ids)
    local buckets = {}
    local locked = {}
    for idx, class_id in ipairs(ticket_ids or {}) do
        local inv_item = session.GetInvItemByType(class_id)
        if inv_item then
            if inv_item.isLockState then
                -- **名前は必ずこの券のものを控えること**(以前は選び終わった後の変数を
                -- 見ていて、nil のときに参照して落ちていた)。
                table.insert(locked, inv_item.Name)
            else
                local kind, life = Indun_panel_ticket_kind(inv_item)
                buckets[kind] = buckets[kind] or {}
                table.insert(buckets[kind], {
                    item = inv_item,
                    idx = idx,
                    life = life or 0
                })
            end
        end
    end
    for kind, list in pairs(buckets) do
        table.sort(list, function(a, b)
            if kind == "expiring" and a.life ~= b.life then
                return a.life < b.life
            end
            return a.idx < b.idx
        end)
    end
    return buckets, locked
end

-- 使用順に沿って「券を 1 枚使う」か「ショップで買う」を **1 回だけ** 行う。
--   group_key  … g.INDUN_PANEL_TICKET_GROUPS のキー
--   ticket_ids … 候補の ClassID(同じ分類の中ではこの並び順)
--   opts       … 省略可。次のものを入れられる
--     on_use     … 券を使った後にすること(入場の予約など)
--     on_buy     … 「購入」の段で呼ばれる。買えたら true を返すこと
--     before_use … 券を使う**直前**にすること
--                  (分裂特異点は AnsGiveUpPrevPlayingIndun を券の使用より前に呼ぶ作りで、
--                   後ろへ回すと「前のダンジョンを諦める」のが券を使った後になる)
--     hold_permanent … 期限の無い券をまだ温存するか。true を返す間、**「購入」より
--                  後ろに置かれた**期限なしの分類(取引不可 / 取引可)を飛ばす
--
-- **hold_permanent が要る理由。** チャレンジ Lv560 の段は TOS と採掘場の 2 つの
-- ショップを持つ。on_buy は押されたボタン側の取引名しか見ないので、片方の購入枠を
-- 使い切っただけで「買えなかった」と判断され、もう片方に枠が残っていても手持ちの
-- 期限なし券を溶かしてしまう。あわせて、券を使って戻ってしまうため
-- **追加購入枠(OverBuy)の経路にも辿り着けなくなる**。
--
-- **「購入」より前に置かれた分類には効かせない。** 利用者が `取引不可` を `購入` の
-- 上へ並べ替えたのなら、それは「買う前に手持ちを使いたい」という意思表示なので、
-- そこで温存すると設定が効かないことになる。
--
-- 何かできたら true。
function Indun_panel_consume_ticket(group_key, ticket_ids, opts)
    opts = opts or {}
    local buckets, locked = Indun_panel_collect_tickets(ticket_ids)
    local order = Indun_panel_ticket_order(group_key)
    local buy_tried = false
    for _, kind in ipairs(order) do
        if kind == "buy" then
            buy_tried = true
            if opts.on_buy and opts.on_buy() == true then
                g.vlog("indun_panel: 入場券をショップで買った group=%s 順=%s", tostring(group_key),
                    table.concat(order, ">"))
                return true
            end
        else
            local hold = buy_tried and kind ~= "expiring" and opts.hold_permanent and
                             opts.hold_permanent() == true
            if hold then
                g.vlog("indun_panel: まだ買えるので期限の無い券を温存した group=%s 分類=%s", tostring(group_key),
                    kind)
            else
                local entry = buckets[kind] and buckets[kind][1]
                if entry then
                    if opts.before_use then
                        opts.before_use()
                    end
                    INV_ICON_USE(entry.item)
                    g.vlog("indun_panel: 入場券を使った group=%s 分類=%s 残り=%s 順=%s", tostring(group_key),
                        kind, tostring(entry.life), table.concat(order, ">"))
                    if opts.on_use then
                        opts.on_use()
                    end
                    return true
                end
            end
        end
    end
    -- **鍵の掛かっていた券を知らせるのはここだけ。** 何もできなかったときに限る。
    if #locked > 0 then
        ui.SysMsg(ClMsg("MaterialItemIsLock") .. " (" .. table.concat(locked, ", ") .. ")")
    end
    g.vlog("indun_panel: 使える入場券が無かった group=%s 順=%s (鍵付き %d 枚)", tostring(group_key),
        table.concat(order, ">"), #locked)
    return false
end

function Indun_panel_save_settings()
    g.save_json(g.indun_panel_path, g.indun_panel_settings)
end

function Indun_panel_load_settings()
    g.indun_panel_path = string.format("../addons/%s/%s/indun_panel.json", addon_name_lower, g.active_id)
    g.indun_panel_old_path = string.format("../addons/%s/%s/settings.json", "indun_panel", g.active_id)
    local settings = g.load_json(g.indun_panel_path)
    local indun_keys = {"challenge", "singularity", "light_uriel", "dark_uriel", "zmei", "belliora", "laimara",
                        "ledania", "neringa", "golem", "merregina", "slogutis", "upinis", "roze", "falouros",
                        "reservoir", "jellyzele", "delmore", "telharsha", "bernice", "giltine", "memory", "wailing",
                        "zawra", "jsr"}
    local json_to_indun_map = {
        veliora = "belliora",
        limara = "laimara",
        redania = "ledania",
        spreader = "reservoir",
        velnice = "bernice",
        cemetery = "wailing",
        earring = "memory"
    }
    if not settings then
        local function create_default_set()
            local set = {}
            for _, name in ipairs(indun_keys) do
                set[name] = 1
            end
            return set
        end
        settings = {
            etc = {
                challenge_ticket = "month",
                always_open = 0,
                singularity_check = 0,
                skin_name = "chat_window_2",
                en_ver = 0,
                x = 665,
                y = 30,
                move = 0,
                use_set = "set_a",
                challenge_map = 0,
                base_date = "",
                shading = 0,
                field_mode = 0,
                toscoin = 0,
                scale = 100
            },
            cols = {
                tos = 1,
                gabija = 1,
                vakarine = 1,
                rada = 1,
                jurate = 1,
                austeja = 1,
                saule = 1,
                pvp_mine = 1,
                market = 1,
                craft = 1,
                leticia = 1
            },
            set_names = {{
                set_a = "SET A"
            }, {
                set_b = "SET B"
            }, {
                set_c = "SET C"
            }},
            set_a = create_default_set(),
            set_b = create_default_set(),
            set_c = create_default_set()
        }
        local old_settings = g.load_json(g.indun_panel_old_path)
        if old_settings then
            for k, v in pairs(old_settings) do
                if type(v) == "table" then
                    if k == "set_a" or k == "set_b" or k == "set_c" then
                        for k2, v2 in pairs(v) do
                            if string.find(k2, "_checkbox") then
                                local json_key = string.gsub(k2, "_checkbox", "")
                                local correct_key = json_to_indun_map[json_key] or json_key
                                if settings[k] and settings[k][correct_key] ~= nil then
                                    settings[k][correct_key] = v2
                                end
                            end
                        end
                    elseif k == "cols" then
                        settings.cols = v
                    end
                else
                    if k ~= "auto_challenge" then
                        if k == "checkbox" then
                            settings.etc.always_open = v
                        elseif settings.etc[k] ~= nil then
                            settings.etc[k] = v
                        end
                    end
                end
            end
        end
    end
    -- 新しいショートカット追加時のバックフィル。cols に無いキーは既定 ON(1) で補う。
    -- これが無いと、既存ユーザーの保存済み cols に無い新ボタンは nil 判定で描画されず、
    -- 設定のチェックも外れたままになる = 追加したのに誰にも出ない
    local col_keys = {"tos", "gabija", "vakarine", "rada", "jurate", "austeja", "saule", "pvp_mine", "market", "craft",
                      "leticia"}
    if type(settings.cols) == "table" then
        for _, name in ipairs(col_keys) do
            if settings.cols[name] == nil then
                settings.cols[name] = 1
            end
        end
    end
    -- 段(520 / 540 / 560)の表示切替。**既定はここだけで作る。** 上の初期値の表に段を
    -- 並べると CHALLENGE_TIERS / SINGULARITY_TIERS と二重に持つことになり、Lv 上限が
    -- 上がったとき片方だけ直す事故が起きる。新規も既存もここで既定 ON(1) を補う。
    if type(settings.tiers) ~= "table" then
        settings.tiers = {}
    end
    for _, row in ipairs(INDUN_PANEL_TIER_ROWS) do
        if type(settings.tiers[row.key]) ~= "table" then
            settings.tiers[row.key] = {}
        end
        local tiers = Indun_panel_tiers_of(row.key)
        if tiers then
            for _, tier in ipairs(tiers) do
                local tier_key = Indun_panel_tier_key(tier.label)
                if settings.tiers[row.key][tier_key] == nil then
                    settings.tiers[row.key][tier_key] = 1
                end
            end
        end
    end
    -- パネルの表示倍率。**既定は 100(これまでどおりの大きさ)。**
    -- 既に使っている人の設定にはこのキーが無いので、ここで補う。
    -- 知らない値が入っていたら Indun_panel_scale が 1 へ落とす。
    if type(settings.etc.scale) ~= "number" then
        settings.etc.scale = 100
    end
    -- 入場券の使用順。**既定はここだけで作る**(段の表示切替と同じ理由)。
    -- Indun_panel_ticket_order が読むたびに直すので、ここでは入れ物だけ用意して
    -- 既定を書き込んでおく(設定ファイルを開いたときに何が指定できるのか見えるように)。
    if type(settings.ticket_order) ~= "table" then
        settings.ticket_order = {}
    end
    for _, group in ipairs(g.INDUN_PANEL_TICKET_GROUPS) do
        if type(settings.ticket_order[group.key]) ~= "table" then
            local def = {}
            for i, kind in ipairs(group.default) do
                def[i] = kind
            end
            settings.ticket_order[group.key] = def
        end
    end
    -- 新ダンジョン追加時のバックフィル: 既存ユーザーの保存済み設定に無いキーを既定ON(1)で補完
    for _, set_name in ipairs({"set_a", "set_b", "set_c"}) do
        if type(settings[set_name]) == "table" then
            for _, name in ipairs(indun_keys) do
                if settings[set_name][name] == nil then
                    settings[set_name][name] = 1
                end
            end
        end
    end
    g.indun_panel_settings = settings
    Indun_panel_save_settings()
end

function indun_panel_on_init()
    -- 設定ロードと CHAT_SYSTEM(デイリー額取得)フックは機能ON/OFFに関わらず従来通り行う。
    -- 旧来ここで開いていた PVP_MINE ショップだけは、機能OFFでもログイン時にショップが開き
    -- インベントリが閉じる不具合の原因だったため撤去し、パネル展開時の遅延同期
    -- (Indun_panel_frame_open → Indun_panel_sync_mine_shop)へ移した。
    if not g.indun_panel_settings then
        Indun_panel_load_settings()
    end
    g.setup_hook_and_event(g.addon, "CHAT_SYSTEM", "Indun_panel_CHAT_SYSTEM", true)
    -- 機能OFF: フレームを破棄し、パネル用フック(ESCAPE/INDUN_ALREADY_PLAYING)は張らない。
    -- use チェックはフレーム構築より前に置く。これで機能OFF時に一度フレームを組んで
    -- 即破棄する(map パネル破棄や save_current_char_counts の副作用込みの)無駄を無くす。
    -- フレーム構築は下の `if not indun_panel` に一本化した(初回/再init どちらもここを通る)。
    if g.settings.indun_panel.use == 0 then
        ui.DestroyFrame(addon_name_lower .. "indun_panel")
        ui.DestroyFrame(addon_name_lower .. "indun_panel_map")
        -- **設定ウィンドウも一緒に畳むこと。** 設定はパネルとは別フレームなので、
        -- パネルだけ消すと設定ウィンドウが画面に残る(一覧のチェックを外した瞬間に起きる)。
        -- ここで Indun_panel_setting_frame_close を呼ばないのは、あちらが
        -- Indun_panel_refresh_panel 経由でパネルを組み直してしまうため。
        -- ESC スタックの登録は g.esc_top が「死んだ登録」として自分で掃除する。
        ui.DestroyFrame(Indun_panel_config_frame_name())
        return
    end
    g.register_msg("ESCAPE_PRESSED", "Indun_panel_frame_init")
    local indun_panel = ui.GetFrame(addon_name_lower .. "indun_panel")
    if not indun_panel then
        Indun_panel_frame_init()
    end
    g.setup_hook_and_event(g.addon, "INDUN_ALREADY_PLAYING", "Indun_panel_INDUN_ALREADY_PLAYING", false)
end

-- PVP_MINE ショップを一瞬開いて ssn_shop を同期する。ショップを開くとゲームが
-- インベントリ等の排他UIを閉じるため、開いていたインベントリを記録しておき、
-- 同期完了時(Indun_panel_earthtowershop_close)に復元する。
-- 同期を開始できたら true、ショップフレーム未取得で空振りしたら false を返す。
-- (呼び出し側は開始時に syncing を立てて二重起動を防ぎ、synced は完了時=
--  Indun_panel_earthtowershop_close で立てる。空振り時は何も立てず次の展開で再試行する)
function Indun_panel_sync_mine_shop()
    local earthtowershop = ui.GetFrame('earthtowershop')
    if not earthtowershop then
        return false
    end
    local inventory = ui.GetFrame("inventory")
    g.indun_panel_inv_restore = (inventory and inventory:IsVisible() == 1) and true or false
    earthtowershop:Resize(0, 0)
    pc.ReqExecuteTx_NumArgs("SCR_PVP_MINE_SHOP_OPEN", 0)
    earthtowershop:RunUpdateScript("Indun_panel_earthtowershop_close", 0.1)
    return true
end

function Indun_panel_earthtowershop_close(earthtowershop)
    if earthtowershop:IsVisible() == 1 then
        earthtowershop:Resize(580, 1920)
        ui.CloseFrame("earthtowershop")
        -- 同期完了(ショップが実際に開いて ssn_shop を取得できた)。以後セッション中は再同期しない。
        -- synced をここで立てることで、ショップが一度も開けなかった場合は synced が立たず
        -- 次の展開で再試行される(開始時点で立てると空取得のまま固定される問題を防ぐ)。
        g.indun_panel_mine_synced = true
        g.indun_panel_mine_syncing = false
        -- 同期のためにゲームが閉じたインベントリを、元々開いていたら復元する
        if g.indun_panel_inv_restore then
            g.indun_panel_inv_restore = false
            ui.OpenFrame("inventory")
        end
        -- 同期完了。表示中かつ展開中(高さ>40)のパネルだけ再描画して PVP_MINE 数を反映する。
        -- (同期中の0.1秒間にユーザーが畳んだ/閉じた場合は再描画しない=無駄な再構築を避ける)
        local indun_panel = ui.GetFrame(addon_name_lower .. "indun_panel")
        if indun_panel and indun_panel:IsVisible() == 1 and indun_panel:GetHeight() > 40 then
            Indun_panel_frame_open(indun_panel)
        end
        return 1
    else
        return 0
    end
end

function Indun_panel_CHAT_SYSTEM(my_frame, my_msg)
    local msg, color = g.get_event_args(my_msg)
    if msg then
        local pattern = "EVENT_TOS_WHOLE_GET_SUCCESS_MSG"
        if string.find(msg, pattern) then
            local daily_value_str = msg:match("%$%*%$DAILY%$%*%$(%d+)%$%*%$")
            g.indun_panel_settings.etc.toscoin = tonumber(daily_value_str)
            Indun_panel_save_settings()
        end
    end
end

function Indun_panel_INDUN_ALREADY_PLAYING(my_frame, my_msg)
    if g.settings.indun_panel.use == 0 then
        g.FUNCS["INDUN_ALREADY_PLAYING"]()
        return
    end
    ReserveScript("Indun_panel_INDUN_ALREADY_PLAYING_dilay()", 0.3)
end

function Indun_panel_INDUN_ALREADY_PLAYING_dilay()
    local indunenter = ui.GetFrame("indunenter")
    local indun_type = indunenter:GetUserIValue('INDUN_TYPE')
    -- 対象は「自動マッチングで入るもの」= チャレンジの PT と分裂の全段。
    -- 以前は 1005 / 2000 / 2001 を直接並べていたが、1005 は削除され 1007 と 2003 が
    -- 増えたので、段の表から引く Indun_panel_is_auto_rejoin_indun に任せる
    -- (この関数は段の表より前にあるので、表を upvalue で掴めない。
    --  グローバル関数にして実行時に引く)。
    if Indun_panel_is_auto_rejoin_indun(indun_type) then
        AnsGiveUpPrevPlayingIndun(1)
        ui.CloseFrame("indunenter")
        ReserveScript(string.format("Indun_panel_enter_singularity(nil,nil,'', %d)", indun_type), 0.5)
        return
    else
        local yes_scp = string.format("AnsGiveUpPrevPlayingIndun(%d)", 1)
        local no_scp = string.format("AnsGiveUpPrevPlayingIndun(%d)", 0)
        ui.MsgBox(ClMsg("IndunAlreadyPlaying_AreYouGiveUp"), yes_scp, no_scp)
    end
end

function Indun_panel_challenge(_nexus_addons_p)
    if not g.indun_panel_challenge_start_time then
        _nexus_addons_p:StopUpdateScript("Indun_panel_challenge")
        return 0
    end
    local now = imcTime.GetAppTimeMS()
    if (now - g.indun_panel_challenge_start_time) >= 3000 then
        _nexus_addons_p:StopUpdateScript("Indun_panel_challenge")
        g.indun_panel_challenge_start_time = nil
        return 0
    end
    local is_auto_challenge_map = session.IsAutoChallengeMap()
    local is_solo_challenge_map = session.IsSoloChallengeMap()
    if is_auto_challenge_map == true or is_solo_challenge_map == true then
        ui.DestroyFrame(addon_name_lower .. "indun_panel")
        -- **設定ウィンドウも一緒に畳む。** 設定はパネルとは別フレームなので、パネルを
        -- 破棄する経路すべてで畳まないと、設定を開いたまま挑戦マップへ入ったときに
        -- 中央のポップアップだけが残る。パネルを破棄するのはここを含めて 3 か所
        -- (アドオン OFF / フィールドで非表示 / ここ)。
        ui.DestroyFrame(Indun_panel_config_frame_name())
        _nexus_addons_p:StopUpdateScript("Indun_panel_challenge")
        g.indun_panel_challenge_start_time = nil
        if g.indun_panel_settings.etc.base_date ~= "" then
            return 0
        end
        local cnt = 0
        local found_clsid = nil
        local challenge_map_list, count = GetClassList('challenge_mode_auto_map')
        for i = 0, count - 1 do
            local map_cls = GetClassByIndexFromList(challenge_map_list, i)
            if map_cls then
                local map_name = map_cls.MapName
                if g.map_name == map_name then
                    cnt = cnt + 1
                    if found_clsid == nil then
                        found_clsid = map_cls.ClassID
                    end
                end
            end
        end
        if cnt == 1 and found_clsid then
            g.indun_panel_settings.etc.challenge_map = found_clsid
            local server_time_str = date_time.get_lua_now_datetime_str()
            if server_time_str then
                local y, m, d, H, M, S = server_time_str:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
                if y then
                    local time_table = {
                        year = tonumber(y),
                        month = tonumber(m),
                        day = tonumber(d),
                        hour = 12,
                        min = 0,
                        sec = 0
                    }
                    g.indun_panel_settings.etc.base_date = os.time(time_table)
                    Indun_panel_save_settings()
                end
            end
        end
        return 0
    end
    return 1
end

-- test_code
--[[local challenge_map_list, count = GetClassList('challenge_mode_auto_map')
for i = 0, count - 1 do
    local map_cls = GetClassByIndexFromList(challenge_map_list, i)
    if map_cls then
        local map_name = map_cls.Name
        local map_clsname = map_cls.MapName
        local map_cls_ = GetClass("Map", map_clsname)
        local map_level = map_cls_.QuestLevel
        ts(i, dic.getTranslatedStr(map_name), map_level)
    end
end]]

local function indun_panel_get_server_elapsed_days(base_date)
    if not base_date or base_date == "" or base_date == 0 then
        return 0
    end
    local server_time_str = date_time.get_lua_now_datetime_str()
    if not server_time_str then
        return 0
    end
    local y, m, d = server_time_str:match("(%d+)-(%d+)-(%d+)")
    if not y then
        return 0
    end
    local server_now = os.time({
        year = tonumber(y),
        month = tonumber(m),
        day = tonumber(d),
        hour = 12
    })
    local base_tbl = os.date("*t", base_date)
    base_tbl.hour = 12
    local server_base = os.time(base_tbl)
    return math.floor((server_now - server_base) / 86400)
end

function Indun_panel_challenge_map_context(indun_panel, ctrl)
    local base_date = g.indun_panel_settings.etc.base_date
    if not base_date or base_date == "" or base_date == 0 then
        return
    end
    local weekdays = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"}
    local elapsed_days = indun_panel_get_server_elapsed_days(base_date)
    local context = ui.CreateContextMenu("challenge_map_schedule", "{ol}Challenge Map Schedule", 0, 100, 0, 0)
    local challenge_map_list, count = GetClassList('challenge_mode_auto_map')
    local start_index = g.indun_panel_settings.etc.challenge_map
    for i = 0, 6 do
        local map_index = (start_index + elapsed_days + i) % count
        local map_cls = GetClassByIndexFromList(challenge_map_list, map_index)
        if map_cls then
            local map_name = map_cls.Name
            local map_clsname = map_cls.MapName
            local server_time_str = date_time.get_lua_now_datetime_str()
            local y, m, d = server_time_str:match("(%d+)-(%d+)-(%d+)")
            local base_time = os.time({
                year = tonumber(y),
                month = tonumber(m),
                day = tonumber(d),
                hour = 12
            })
            local display_time = base_time + (i * 86400)
            local month_day = os.date("%m-%d", display_time)
            local day_of_week_num = tonumber(os.date("%w", display_time))
            local day_of_week_str = weekdays[day_of_week_num + 1]
            local date_str = string.format("%s (%s)", month_day, day_of_week_str)
            local scp = string.format("Indun_panel_challenge_map_display('%s','%s')", map_clsname, date_str)
            ui.AddContextMenuItem(context, date_str .. " " .. map_name, scp)
        end
    end
    ui.OpenContextMenu(context)
end

function Indun_panel_challenge_map_display(map_clsname, date_str)
    local indun_panel_map = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "indun_panel_map", 0, 0, 0, 0)
    AUTO_CAST(indun_panel_map)
    g.block_click_through(indun_panel_map)
    indun_panel_map:RemoveAllChild()
    indun_panel_map:SetSkinName("bg")
    indun_panel_map:SetLayerLevel(100)
    indun_panel_map:Resize(300, 320)
    local gb = indun_panel_map:CreateOrGetControl("picture", "gb", 0, 20, indun_panel_map:GetWidth(),
        indun_panel_map:GetHeight() - 20)
    AUTO_CAST(gb)
    gb:Resize(300, 300)
    gb:EnableHitTest(0)
    local close = indun_panel_map:CreateOrGetControl('button', 'close', 0, 0, 30, 30)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Indun_panel_challenge_map_close")
    local map_width = gb:GetWidth()
    local map_height = gb:GetHeight()
    local map_cls = GetClass("Map", map_clsname)
    if not map_cls then
        return
    end
    local map_title = indun_panel_map:CreateOrGetControl("richtext", "map_title", 0, 0)
    map_title:SetGravity(ui.LEFT, ui.TOP)
    map_title:SetText("{ol}" .. map_cls.Name .. " " .. date_str)
    local pic = gb:CreateOrGetControl('picture', "picture_" .. map_clsname, ui.CENTER_HORZ, ui.CENTER_VERT, map_width,
        map_height)
    AUTO_CAST(pic)
    pic:SetEnableStretch(1)
    local is_valid = ui.IsImageExist(map_clsname .. "_fog")
    if is_valid == false then
        world.PreloadMinimap(map_clsname)
    end
    pic:SetImage(map_clsname .. "_fog")
    local icon_group = gb:CreateOrGetControl("picture", "icon_group", ui.CENTER_HORZ, ui.CENTER_VERT, gb:GetWidth(),
        gb:GetHeight())
    AUTO_CAST(icon_group)
    icon_group:SetSkinName("None")
    local name_group = gb:CreateOrGetControl("picture", "name_group", ui.CENTER_HORZ, ui.CENTER_VERT, gb:GetWidth(),
        gb:GetHeight())
    AUTO_CAST(name_group)
    name_group:SetSkinName("None")
    UPDATE_MAP_BY_NAME(icon_group, map_clsname, pic, map_width, map_height, 0, 0)
    MAKE_MAP_AREA_INFO(name_group, map_clsname, "{s15}", map_width, map_height, -100, -30)
    local map_frame = ui.GetFrame("map")
    local width = map_frame:GetWidth()
    local height = map_frame:GetHeight()
    indun_panel_map:SetPos(width / 2 - 620, height / 2 - 300)
    indun_panel_map:ShowWindow(1)
    g.esc_register_destroy(addon_name_lower .. "indun_panel_map")
end

function Indun_panel_challenge_map_close(frame)
    ui.DestroyFrame(frame:GetName())
end

-- 今のマップでパネルをどう扱うか。**判定は 1 か所にまとめること。**
-- 以前は Indun_panel_frame_init だけが持っていて、Indun_panel_frame_open には無かった。
-- そのため展開中に「フィールドで表示」を OFF にすると、畳んでいれば消えるのに
-- 展開していると残る、という非対称な挙動になっていた。
--   "ok"   … 出してよい(街、またはフィールドで「フィールドで表示」が ON)
--   "keep" … 触らない(インスタンス / ヴェルニケ。素の窓と取り合いにならないよう放置する)
--   "hide" … 消す(フィールドで「フィールドで表示」が OFF)
function Indun_panel_map_verdict()
    local map_type = g.get_map_type()
    if map_type == "City" then
        return "ok"
    end
    if map_type == "Instance" or g.map_id == g.MAP_VELNIKE then
        return "keep"
    end
    if g.indun_panel_settings.etc.field_mode ~= 1 then
        return "hide"
    end
    return "ok"
end

function Indun_panel_frame_init(is_toggle, msg)
    if msg == "ESCAPE_PRESSED" then
        if g.indun_panel_settings.etc.always_open == 1 then
            return
        end
        -- ILV や OCSL が手前に開いているときは、その 1 枚だけが閉じればよい。
        -- ここでパネルを作り直すと、一緒に畳まれて「まとめて消えた」ように見える
        -- (挑戦マップのフレームも下で破棄している)。
        -- このパネルは常時表示なので g.esc_register でスタックに積むわけにはいかない
        -- (積むと ESC を常に横取りしてシステムメニューが開けなくなる)。詳細は core/00_header.lua。
        if g.esc_taken() then
            g.vlog("indun_panel: ESC は手前のウィンドウが使ったので何もしない")
            return
        end
    end
    local map_verdict = Indun_panel_map_verdict()
    if map_verdict == "keep" then
        return
    end
    if map_verdict == "hide" then
        ui.DestroyFrame(addon_name_lower .. "indun_panel")
        -- 設定ウィンドウも畳む。**ここは Indun_panel_frame_init の中**なので、
        -- Indun_panel_setting_frame_close を呼ぶと refresh 経由でここへ戻ってくる。
        ui.DestroyFrame(Indun_panel_config_frame_name())
        return
    end
    --[[if g.get_map_type() ~= "City" and
        (g.indun_panel_settings.etc.field_mode ~= 1 and g.get_map_type() == "Instance" and g.map_id == g.MAP_VELNIKE) then
        return
    end]]
    Indun_list_viewer_save_current_char_counts()
    ui.DestroyFrame(addon_name_lower .. "indun_panel_map")
    local indun_panel = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "indun_panel", 0, 0, 0, 0)
    AUTO_CAST(indun_panel)
    indun_panel:SetSkinName('None')
    indun_panel:SetLayerLevel(30)
    indun_panel:RemoveAllChild()
    Indun_panel_setup_frame(indun_panel)
    local btn = indun_panel:CreateOrGetControl("button", "btn", Indun_panel_s(5), Indun_panel_s(5),
        Indun_panel_s(80), Indun_panel_s(30))
    AUTO_CAST(btn)
    btn:SetText("{ol}" .. Indun_panel_f(10) .. "INDUNPANEL")
    btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_frame_toggle")
    btn:SetEventScript(ui.RBUTTONUP, "Indun_panel_always_init")
    btn:SetEventScriptArgString(ui.RBUTTONUP, "OPEN")
    btn:SetTextTooltip(g.lang == "Japanese" and "{ol}右クリック: 常時展開で開く" or
                           "{ol}Right click: Open in Always Expand")
    local x = Indun_panel_create_common_buttons(indun_panel)
    -- 並びは設定ウィンドウの▲▼で決まる(INDUN_PANEL_SHORTCUTS の順が既定)
    for _, def in ipairs(Indun_panel_ordered_shortcuts()) do
        local value = g.indun_panel_settings.cols[def.key]
        if value == 1 then
            if Indun_panel_create_shortcut_button(indun_panel, def.key, x) then
                x = x + Indun_panel_s(30)
            end
        end
    end
    indun_panel:Resize(x, Indun_panel_s(40))
    indun_panel:ShowWindow(1)
    if not is_toggle then
        if g.indun_panel_settings.etc.always_open == 1 then
            Indun_panel_frame_open(indun_panel)
        end
    end
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    g.indun_panel_challenge_start_time = imcTime.GetAppTimeMS()
    _nexus_addons_p:RunUpdateScript("Indun_panel_challenge", 0.1)
    return indun_panel
end

function Indun_panel_setup_frame(indun_panel)
    local map = ui.GetFrame("map")
    local width = map:GetWidth()
    local x = g.indun_panel_settings.etc.x
    if width <= 1920 and x > 1920 then
        x = x / 21 * 16
    end
    indun_panel:SetPos(x, g.indun_panel_settings.etc.y)
    indun_panel:SetTitleBarSkin("None")
    local enable = g.indun_panel_settings.etc.move == 0 and 1 or 0
    indun_panel:EnableMove(enable)
    -- 「フレームを固定」は**動かさない**だけの設定なので、当たり判定は固定でも残す。
    -- 以前は EnableHittestFrame(enable) と EnableMove に相乗りさせていたが、これだと
    -- 固定にした利用者だけパネルの余白が当たり判定を失い、展開表示(横 600px 以上)の
    -- 上を押すとその入力が下の 3D 画面へ抜けてキャラクターが歩き出していた。
    g.block_click_through(indun_panel)
    -- フレーム固定チェックの状態に関わらず、ドラッグ保存ハンドラは常にバインドしておく。
    -- 固定モード(move==1)は EnableMove(0) で位置が動かず、Indun_panel_frame_drag は
    -- 座標が変わっていなければ何もしないので無害。
    -- これにより、設定で固定を外して即ドラッグした場合(リビルド前)も、既にハンドラが
    -- 付いているので位置が保存される。
    -- (以前は固定モードで "None" にしており、チェックを外した直後に動かすと
    --  Indun_panel_ischecked が EnableMove を戻すだけでハンドラ未バインドのまま→保存されなかった)
    indun_panel:SetEventScript(ui.LBUTTONUP, "Indun_panel_frame_drag")
end

function Indun_panel_frame_drag(indun_panel)
    -- ネイティブ移動(EnableMove)で動かした後の座標を保存するだけ。
    -- リビルド(frame_init)しないことで、展開表示を畳まずに位置を維持する。
    -- LBUTTONUP は移動を伴わない単なるクリックでも発火するため、位置が変わっていなければ
    -- JSON 書き込み(save_settings)を省いて無駄なディスク I/O を避ける。
    local x = indun_panel:GetX()
    local y = indun_panel:GetY()
    if x == g.indun_panel_settings.etc.x and y == g.indun_panel_settings.etc.y then
        return
    end
    g.indun_panel_settings.etc.x = x
    g.indun_panel_settings.etc.y = y
    Indun_panel_save_settings()
end

function Indun_panel_create_common_buttons(indun_panel)
    local ccbtn = indun_panel:CreateOrGetControl('button', 'ccbtn', Indun_panel_s(85), Indun_panel_s(5),
        Indun_panel_s(30), Indun_panel_s(30))
    AUTO_CAST(ccbtn)
    ccbtn:SetSkinName("None")
    ccbtn:SetText(string.format("{img barrack_button_normal %d %d}", Indun_panel_s(30), Indun_panel_s(30)))
    local lbtn_action = "APPS_TRY_MOVE_BARRACK"
    local rbtn_action = nil
    local tooltip_parts = {}
    local lbtn_tooltip = nil
    if type(_G["INSTANTCC_APPS_TRY_MOVE_BARRACK"]) == "function" and g.settings.instant_cc.use == 1 then
        lbtn_action = "INSTANTCC_APPS_TRY_MOVE_BARRACK"
        lbtn_tooltip = "[InstantCC] Open"
    end
    if type(_G["indun_list_viewer_title_frame_open"]) == "function" and g.settings.indun_list_viewer.use == 1 then
        lbtn_action = "indun_list_viewer_title_frame_open"
        lbtn_tooltip = "Left-Click: [ILV] Open"
    end
    if lbtn_tooltip then
        table.insert(tooltip_parts, lbtn_tooltip)
    end
    if type(_G["other_character_skill_list_frame_open"]) == "function" and g.settings.other_character_skill_list.use ==
        1 then
        rbtn_action = "other_character_skill_list_frame_open"
        table.insert(tooltip_parts, "Right-Click: [OCSL] Open")
    end
    ccbtn:SetEventScript(ui.LBUTTONUP, lbtn_action)
    if rbtn_action then
        ccbtn:SetEventScript(ui.RBUTTONUP, rbtn_action)
    end
    local default_tooltip = g.lang == "Japanese" and "{ol}バラックに戻ります" or "{ol}Return to Barracks"
    ccbtn:SetTextTooltip(#tooltip_parts > 0 and "{ol}" .. table.concat(tooltip_parts, "{nl}") or default_tooltip)
    return Indun_panel_s(115) -- 次のボタンを開始するX座標を返す
end

function Indun_panel_create_shortcut_button(indun_panel, key_name, x)
    local account_obj = GetMyAccountObj()
    local coin_count = 0
    local tooltip_msg = ""
    local btn = nil
    if key_name == "tos" and g.get_map_type() == "City" then
        btn = indun_panel:CreateOrGetControl("button", "tos", x + Indun_panel_s(2), Indun_panel_s(8),
            Indun_panel_s(25), Indun_panel_s(25))
        btn:SetText(string.format("{img icon_item_Tos_Event_Coin %d %d}", Indun_panel_s(25), Indun_panel_s(25)))
        tooltip_msg = g.lang == "Japanese" and "{ol}TOSイベントショップ" or "{ol}TOS Event Shop"
        btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_event_tos_whole_shop_open")
    elseif key_name == "gabija" and g.get_map_type() == "City" then
        btn = indun_panel:CreateOrGetControl("button", "gabija", x, Indun_panel_s(7),
            Indun_panel_s(29), Indun_panel_s(29))
        btn:SetText(string.format("{img goddess_shop_btn %d %d}", Indun_panel_s(29), Indun_panel_s(29)))
        coin_count = GET_COMMAED_STRING(TryGetProp(account_obj, "GabijaCertificate", "0"))
        tooltip_msg =
            (g.lang == "Japanese" and "{ol}ガビヤショップ{nl}" or "{ol}Gabija Shop{nl}") .. "{#FFFF00}" ..
                coin_count
        btn:SetEventScript(ui.LBUTTONUP, "REQ_GabijaCertificate_SHOP_OPEN")
    elseif key_name == "vakarine" and g.get_map_type() == "City" then
        btn = indun_panel:CreateOrGetControl("button", "vakarine", x, Indun_panel_s(7),
            Indun_panel_s(29), Indun_panel_s(29))
        btn:SetText(string.format("{img goddess2_shop_btn %d %d}", Indun_panel_s(29), Indun_panel_s(29)))
        coin_count = GET_COMMAED_STRING(TryGetProp(account_obj, "VakarineCertificate", "0"))
        tooltip_msg = (g.lang == "Japanese" and "{ol}ヴァカリネショップ{nl}" or "{ol}Vakarine Shop{nl}") ..
                          "{#FFFF00}" .. coin_count
        btn:SetEventScript(ui.LBUTTONUP, "REQ_VakarineCertificate_SHOP_OPEN")
    elseif key_name == "rada" and g.get_map_type() == "City" then
        btn = indun_panel:CreateOrGetControl("button", "rada", x, Indun_panel_s(8),
            Indun_panel_s(29), Indun_panel_s(29))
        btn:SetText(string.format("{img goddess3_shop_btn %d %d}", Indun_panel_s(29), Indun_panel_s(29)))
        coin_count = GET_COMMAED_STRING(TryGetProp(account_obj, "RadaCertificate", "0"))
        tooltip_msg = (g.lang == "Japanese" and "{ol}ラダショップ{nl}" or "{ol}Rada Shop{nl}") .. "{#FFFF00}" ..
                          coin_count
        btn:SetEventScript(ui.LBUTTONUP, "REQ_RadaCertificate_SHOP_OPEN")
    elseif key_name == "jurate" and g.get_map_type() == "City" then
        btn = indun_panel:CreateOrGetControl("button", "jurate", x, Indun_panel_s(7),
            Indun_panel_s(29), Indun_panel_s(29))
        btn:SetText(string.format("{img goddess4_shop_btn %d %d}", Indun_panel_s(29), Indun_panel_s(29)))
        coin_count = GET_COMMAED_STRING(TryGetProp(account_obj, "JurateCertificate", "0"))
        tooltip_msg =
            (g.lang == "Japanese" and "{ol}ユラテショップ{nl}" or "{ol}Jurate Shop{nl}") .. "{#FFFF00}" ..
                coin_count
        btn:SetEventScript(ui.LBUTTONUP, "REQ_JurateCertificate_SHOP_OPEN")
    elseif key_name == "austeja" then
        btn = indun_panel:CreateOrGetControl("button", "austeja", x, Indun_panel_s(7),
            Indun_panel_s(29), Indun_panel_s(29))
        btn:SetText(string.format("{img goddess5_shop_btn %d %d}", Indun_panel_s(29), Indun_panel_s(29)))
        coin_count = GET_COMMAED_STRING(TryGetProp(account_obj, "AustejaCertificate", "0"))
        tooltip_msg = (g.lang == "Japanese" and "{ol}アウステヤショップ{nl}" or "{ol}Austeja Shop{nl}") ..
                          "{#FFFF00}" .. coin_count
        btn:SetEventScript(ui.LBUTTONUP, "REQ_AustejaCertificate_SHOP_OPEN")
    elseif key_name == "saule" then
        btn = indun_panel:CreateOrGetControl("button", "saule", x, Indun_panel_s(7),
            Indun_panel_s(29), Indun_panel_s(29))
        -- 素のクライアントに **サウレ専用のショップボタン画像は無い**(baseskinset の
        -- goddess*_shop_btn は goddess_ / 2 / 3 / 4 / 5 の 5 枚だけで、素の
        -- minimized_certificate_shop_button は goddess5_shop_btn = アウステヤの絵のまま
        -- サウレの商店を開いている)。それをそのまま真似るとアウステヤのボタンと
        -- 隣同士で同じ絵になって見分けが付かないので、コインの画像を使う。
        btn:SetText(string.format("{img icon_item_season_coin_Saule %d %d}", Indun_panel_s(29), Indun_panel_s(29)))
        coin_count = GET_COMMAED_STRING(TryGetProp(account_obj, "SauleCertificate", "0"))
        tooltip_msg = (g.lang == "Japanese" and "{ol}サウレショップ{nl}" or "{ol}Saule Shop{nl}") ..
                          "{#FFFF00}" .. coin_count
        btn:SetEventScript(ui.LBUTTONUP, "REQ_SauleCertificate_SHOP_OPEN")
    elseif key_name == "pvp_mine" then
        btn = indun_panel:CreateOrGetControl("button", "pvp_mine", x, Indun_panel_s(7),
            Indun_panel_s(29), Indun_panel_s(29))
        btn:SetText(string.format("{img pvpmine_shop_btn_total %d %d}", Indun_panel_s(29), Indun_panel_s(29)))
        tooltip_msg = g.lang == "Japanese" and "{ol}傭兵団ショップ" or "{ol}Mercenary Shop"
        btn:SetEventScript(ui.LBUTTONUP, "MINIMIZED_PVPMINE_SHOP_BUTTON_CLICK")
    elseif key_name == "market" and g.get_map_type() == "City" then
        btn = indun_panel:CreateOrGetControl("button", "market", x, Indun_panel_s(6),
            Indun_panel_s(29), Indun_panel_s(29))
        btn:SetText(string.format("{img market_shortcut_btn02 %d %d}", Indun_panel_s(29), Indun_panel_s(29)))
        tooltip_msg = g.lang == "Japanese" and "{ol}マーケット" or "{ol}Market"
        btn:SetEventScript(ui.LBUTTONUP, "MINIMIZED_MARKET_BUTTON_CLICK")
    elseif key_name == "craft" and g.get_map_type() == "City" then
        btn = indun_panel:CreateOrGetControl("button", "craft", x, Indun_panel_s(5),
            Indun_panel_s(29), Indun_panel_s(29))
        btn:SetText(string.format("{img icon_fullscreen_menu_equipment_processing %d %d}", Indun_panel_s(28),
            Indun_panel_s(28)))
        tooltip_msg = g.lang == "Japanese" and "{ol}装備加工" or "{ol}Equipment Processing"
        btn:SetEventScript(ui.LBUTTONUP, "FULLSCREEN_NAVIGATION_MENU_DEATIL_EQUIPMENT_PROCESSING_NPC")
    elseif key_name == "leticia" and g.get_map_type() == "City" then
        btn = indun_panel:CreateOrGetControl("button", "leticia", x, Indun_panel_s(5),
            Indun_panel_s(29), Indun_panel_s(29))
        btn:SetText(string.format("{img icon_fullscreen_menu_letica %d %d}", Indun_panel_s(28), Indun_panel_s(28)))
        tooltip_msg = g.lang == "Japanese" and "{ol}レティーシャへ移動" or "{ol}Leticia Move"
        btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_FULLSCREEN_NAVIGATION_MENU_DETAIL_MOVE_NPC")
        btn:SetEventScriptArgNumber(ui.LBUTTONUP, 309)
    end
    if btn then
        AUTO_CAST(btn)
        btn:SetSkinName("None")
        btn:SetTextTooltip(tooltip_msg)
        btn:SetEventScript(ui.LBUTTONDOWN, "Indun_panel_earthtowershop_close_restart")
        return true -- ボタンが作成された
    end
    return false -- ボタンが作成されなかった
end

function Indun_panel_event_tos_whole_shop_open()
    local earthtowershop = ui.GetFrame("earthtowershop")
    earthtowershop:SetUserValue("SHOP_TYPE", 'EVENT_TOS_WHOLE_SHOP')
    ui.OpenFrame('earthtowershop')
end

function Indun_panel_FULLSCREEN_NAVIGATION_MENU_DETAIL_MOVE_NPC(frame, ctrl, str, guid)
    if g.get_map_type() ~= "City" then
        return
    end
    local cls = GetClassByType("full_screen_navigation_menu", guid)
    if cls then
        local name = TryGetProp(cls, "Name", "None")
        local move_zone_select = TryGetProp(cls, "MoveZoneSelect", "NO")
        local move_zone = TryGetProp(cls, "MoveZone", "None")
        local move_npc_dialog = TryGetProp(cls, "MoveNpcDialog", "None")
        local move_zone_select_msg = TryGetProp(cls, "MoveZoneSelectMsg", "None")
        local move_only_in_town = TryGetProp(cls, "MoveOnlyInTown", "None")
        if move_zone ~= "None" and move_npc_dialog ~= "None" then
            local pc = GetMyPCObject()
            if session.world.IsIntegrateServer() == true or IsPVPField(pc) == 1 or IsPVPServer(pc) == 1 then
                ui.SysMsg(ScpArgMsg("ThisLocalUseNot"))
                return
            end
            if world.GetLayer() ~= 0 then
                ui.SysMsg(ScpArgMsg("ThisLocalUseNot"))
                return
            end
            if g.get_map_type() == "Dungeon" then
                ui.SysMsg(ScpArgMsg("ThisLocalUseNot"))
                return
            end
            local cur_map = GetClass("Map", session.GetMapName())
            if cur_map then
                local zone_keyword = TryGetProp(cur_map, 'Keyword', 'None')
                local keyword_table = StringSplit(zone_keyword, '')
                if table.find(keyword_table, 'IsRaidField') > 0 or table.find(keyword_table, 'WeeklyBossMap') > 0 then
                    ui.SysMsg(ScpArgMsg('ThisLocalUseNot'))
                    return
                end
                FullScreenMenuMoveNpc(name, move_zone_select, move_zone, move_npc_dialog, move_zone_select_msg,
                    move_only_in_town)
                ui.CloseFrame("fullscreen_navigation_menu")
            end
        end
    end
end

function Indun_panel_earthtowershop_close_restart()
    local earthtowershop = ui.GetFrame('earthtowershop')
    if earthtowershop:IsVisible() == 1 then
        earthtowershop:Resize(580, 1920)
        ui.CloseFrame("earthtowershop")
        return 0
    else
        earthtowershop:Resize(580, 1920)
        return 1
    end
end

function Indun_panel_always_init(indun_panel, ctrl, str)
    if str == "OPEN" then
        g.indun_panel_settings.etc.always_open = 1
        Indun_panel_frame_open(indun_panel)
    else
        g.indun_panel_settings.etc.always_open = 0
        Indun_panel_frame_init()
    end
    Indun_panel_save_settings()
end

function Indun_panel_frame_toggle(indun_panel)
    if indun_panel:GetHeight() > 40 then
        Indun_panel_frame_init(true)
    else
        Indun_panel_frame_open(indun_panel)
    end
end

function Indun_panel_frame_open(indun_panel)
    -- 展開表示で使う PVP_MINE 購入可能数は ssn_shop(セッションのショップ値)に入るため、
    -- セッション中まだ同期していなければ、ここで一度だけショップを開いて取得する。
    -- (取得は非同期。完了時に Indun_panel_earthtowershop_close が展開中パネルを再描画し、
    --  そこで synced を立てる)。syncing は開始〜完了間のガードで、二重にショップを開かない。
    -- 空振り(ショップフレーム未取得)時は何も立てず次回展開で再試行する。
    if not g.indun_panel_mine_synced and not g.indun_panel_mine_syncing and Indun_panel_sync_mine_shop() then
        g.indun_panel_mine_syncing = true
    end
    indun_panel:RemoveAllChild()
    Indun_panel_setup_frame(indun_panel)
    local btn = indun_panel:CreateOrGetControl("button", "btn", Indun_panel_s(5), Indun_panel_s(5),
        Indun_panel_s(80), Indun_panel_s(30))
    AUTO_CAST(btn)
    btn:SetText("{ol}" .. Indun_panel_f(10) .. "INDUNPANEL")
    btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_frame_toggle")
    btn:SetEventScript(ui.RBUTTONUP, "Indun_panel_always_init")
    btn:SetTextTooltip(g.lang == "Japanese" and "{ol}右クリック: 常時展開解除で閉じる" or
                           "{ol}Right click: Close with permanent unexpand")
    -- **歯車は一番右(常時展開チェックの右隣)へ置く。** 畳んだ状態(Indun_panel_frame_init)は
    -- 歯車を作らないので、ここで共通ボタンとショートカットの間へ挟むと、展開したときだけ
    -- ショートカットが 30px 右へずれて「畳む/展開で位置が変わる」ことになる。
    local x = Indun_panel_create_common_buttons(indun_panel)
    -- 並びは設定ウィンドウの▲▼で決まる(INDUN_PANEL_SHORTCUTS の順が既定)
    for _, def in ipairs(Indun_panel_ordered_shortcuts()) do
        local value = g.indun_panel_settings.cols[def.key]
        if value == 1 then
            if Indun_panel_create_shortcut_button(indun_panel, def.key, x) then
                x = x + Indun_panel_s(30)
            end
        end
    end
    local current_x = x + Indun_panel_s(10) -- SET A の開始位置
    local set_w = Indun_panel_s(80)
    for _, item in ipairs(g.indun_panel_settings.set_names) do
        for key, name in pairs(item) do
            local btn = indun_panel:CreateOrGetControl("button", key, current_x, Indun_panel_s(5), set_w,
                Indun_panel_s(30))
            AUTO_CAST(btn)
            btn:Resize(set_w, Indun_panel_s(30))
            btn:SetText("{ol}" .. name)
            btn:AdjustFontSizeByWidth(set_w)
            btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_set_toggle")
            btn:SetEventScriptArgString(ui.LBUTTONUP, key) -- "set_a" を渡す
            btn:SetEventScriptArgNumber(ui.LBUTTONUP, 0) -- 0 を渡す (ArgNumberにする)
            if g.indun_panel_settings.etc.use_set == key then
                btn:SetSkinName("test_red_button")
            end
            current_x = current_x + Indun_panel_s(85)
        end
    end
    -- 位置は SET ボタンの右隣。x=710 の決め打ちだと、ショートカットを 1 つ足すだけで
    -- SET ボタン列が 30px 右へずれて SET C と重なる(実際サウレの追加で 25px 重なった)
    local always_open = indun_panel:CreateOrGetControl('checkbox', 'always_open', current_x, Indun_panel_s(5),
        Indun_panel_s(30), Indun_panel_s(30))
    AUTO_CAST(always_open)
    always_open:SetCheck(g.indun_panel_settings.etc.always_open)
    always_open:SetEventScript(ui.LBUTTONUP, "Indun_panel_ischecked")
    always_open:SetTextTooltip(g.lang == "Japanese" and "{ol}チェックすると常時展開" or
                                   "{ol}IsCheck AlwaysOpen")
    local configbtn = indun_panel:CreateOrGetControl('button', 'configbtn', current_x + Indun_panel_s(35),
        Indun_panel_s(5), Indun_panel_s(30), Indun_panel_s(30))
    AUTO_CAST(configbtn)
    configbtn:SetSkinName("None")
    configbtn:SetText(string.format("{img config_button_normal %d %d}", Indun_panel_s(30), Indun_panel_s(30)))
    configbtn:SetEventScript(ui.LBUTTONUP, "Indun_panel_setting_frame_open")
    configbtn:SetTextTooltip(g.lang == "Japanese" and "{ol}Indun Panel 設定" or "{ol}Indun Panel Config")
    local function indun_panel_FIELD_BOSS_TIME_TAB_SETTING()
        local induninfo = ui.GetFrame("induninfo")
        local field_boss_ranking_control = GET_CHILD_RECURSIVELY(induninfo, "field_boss_ranking_control")
        local sub_tab = GET_CHILD_RECURSIVELY(field_boss_ranking_control, "sub_tab")
        local server_time_str = date_time.get_lua_now_datetime_str()
        local _, _, _, hour_str, min_str, _ = server_time_str:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
        local server_hour = tonumber(hour_str)
        local server_min = tonumber(min_str)
        if (server_hour < 12) or (server_hour == 12 and server_min < 5) then
            sub_tab:SelectTab(0)
        else
            sub_tab:SelectTab(1)
        end
    end
    local current_set = g.indun_panel_settings.etc.use_set
    if g.indun_panel_settings[current_set] and g.indun_panel_settings[current_set].jsr == 1 then
        indun_panel_FIELD_BOSS_TIME_TAB_SETTING()
    end
    -- 常時展開チェック(30px) + 歯車(30px) ぶんを足す
    local final_x = current_x + Indun_panel_s(70)
    -- **上段に要る幅を控えておく。** 展開すると Indun_panel_frame_contents が行の幅で
    -- パネルを resize し直すので、ここで控えないと上段のほうが広いときに右端が切れる
    -- (実機で発生。下の panel_width のコメント参照)。
    g.indun_panel_header_width = final_x
    -- 幅が足りているかを実機で確かめる材料。展開のたびに 1 行だけ(毎フレームではない)。
    g.vlog("indun_panel: 上段の幅 %d (ショートカットの右端 %d / SET の右端 %d)", final_x, x, current_x)
    indun_panel:Resize(final_x, Indun_panel_s(40))
    indun_panel:ShowWindow(1)
    Indun_panel_frame_contents(configbtn)
    configbtn:RunUpdateScript("Indun_panel_frame_contents", 1.0)
end

function Indun_panel_set_toggle(indun_panel, ctrl, set_key, num)
    g.indun_panel_settings.etc.use_set = set_key
    Indun_panel_save_settings()
    if num == 1 then
        -- 設定ウィンドウからのセット切替。並ぶ行が変わるのでパネルも作り直す
        -- (残したままだと前のセットの行が重なる。Indun_panel_refresh_panel のコメント)
        -- **設定ウィンドウは開き直さず中身だけ入れ替える。** 開き直すと ESC の登録を
        -- 積み直すことになり、タブの選択も作り直しに巻き込まれる。
        Indun_panel_refresh_panel()
        Indun_panel_config_rebuild()
    else
        Indun_panel_frame_open(indun_panel)
    end
end

-- 設定を変えたらパネルを描き直す。
--
-- **Indun_panel_frame_contents は「作り直し」ではない。** コントロールを名前で
-- CreateOrGetControl して使い回すだけなので、行や段を消しても前の位置のコントロールが
-- そのまま残り、下の行の上に重なって描かれる(網掛けの line<key> も同じ)。
-- 以前は設定画面がパネルそのものだったので、閉じたときの Indun_panel_frame_init が
-- 必ず作り直していて表面化しなかった。設定を別ウィンドウにして、パネルが生きたまま
-- 1 秒ごとに再描画されるようになったので、ここで明示的に作り直す。
-- RemoveAllChild から組み直すのは Indun_panel_frame_open 側。
--
-- **展開しているか畳んでいるかは変えない。** 判定は Indun_panel_frame_toggle と同じく
-- 高さで見る(畳んだパネルは Resize(x, 40) なのでちょうど 40)。畳んでいてもショートカット
-- ボタンの出し入れは効くので、そちらも作り直す。
function Indun_panel_refresh_panel()
    local panel = ui.GetFrame(addon_name_lower .. "indun_panel")
    if not panel then
        return
    end
    -- **マップの判定を飛ばさないこと。** 展開中に呼ぶ Indun_panel_frame_open には
    -- この判定が無いので、素通りするとフィールドで「フィールドで表示」を OFF にしたとき
    -- パネルが消えずに残る(畳んでいるときだけ消える、という非対称になる)。
    -- "keep" も "hide" も後始末は Indun_panel_frame_init 側が持っているので、そちらへ回す。
    if Indun_panel_map_verdict() ~= "ok" then
        Indun_panel_frame_init(true)
        return
    end
    if panel:GetHeight() > 40 then
        Indun_panel_frame_open(panel)
    else
        -- is_toggle = true で「常時展開」の自動展開を通さない(畳んだままにする)
        Indun_panel_frame_init(true)
    end
end

function Indun_panel_ischecked(indun_panel, ctrl)
    local ischeck = ctrl:IsChecked()
    local ctrlname = ctrl:GetName()
    local current_set = g.indun_panel_settings.etc.use_set
    local use_tbl = g.indun_panel_settings[current_set]
    if use_tbl and use_tbl[ctrlname] then
        use_tbl[ctrlname] = ischeck
        -- 段(520 / 540 / 560)を持つ行なら、ぶら下がっている段の色を合わせ直す
        Indun_panel_tier_refresh_color(indun_panel, ctrlname)
    elseif g.indun_panel_settings.cols then
        if g.indun_panel_settings.cols[ctrlname] then
            g.indun_panel_settings.cols[ctrlname] = ischeck
        end
    end
    if g.indun_panel_settings.etc[ctrlname] then
        g.indun_panel_settings.etc[ctrlname] = ischeck
    end
    -- チャレンジ / 分裂の段(520 / 540 / 560)。控えは settings.tiers に持つ。
    -- **段の表(CHALLENGE_TIERS)はこの関数より後ろの local なのでここからは見えない。**
    -- コントロール名から「行の綴り + 段」を読み取り、控えに在るものだけを書く
    -- (在るかどうかの判定が、そのまま知らない名前を弾く役目も果たす)。
    local prefix, label = string.match(ctrlname, "^(%a+)(%d+)$")
    if prefix then
        for _, row in ipairs(INDUN_PANEL_TIER_ROWS) do
            if row.prefix == prefix then
                local tbl = g.indun_panel_settings.tiers and g.indun_panel_settings.tiers[row.key]
                local tier_key = Indun_panel_tier_key(label)
                if tbl and tbl[tier_key] ~= nil then
                    tbl[tier_key] = ischeck
                end
                break
            end
        end
    end
    -- **設定ウィンドウからの変更のときだけ描き直す。** パネルの上のチェック
    -- (singularity_check / 常時展開)から呼ばれたときにやると、Indun_panel_frame_open の
    -- RemoveAllChild が「今まさにこのイベントを処理しているコントロール」を壊すことになる。
    --
    -- 発火元の名前を出しておく。**ここの判定を落とすとパネルが組み直されず、消したはずの
    -- 行が残って次の行と重なる**(一覧を枠に入れたとき第 1 引数がその枠になり、実際に踏んだ)。
    -- 押したときだけなのでログは流れない。
    local from_config = Indun_panel_from_config(indun_panel)
    g.vlog("indun_panel: チェック %s = %s (発火元 %s / 設定から %s)", tostring(ctrlname), tostring(ischeck),
        indun_panel and indun_panel:GetName() or "nil", tostring(from_config))
    if from_config then
        Indun_panel_refresh_panel()
    end
    if ctrlname == "move" then
        -- 動かせるかどうかだけを切り替える。当たり判定は常に残す(Indun_panel_setup_frame 参照)。
        -- **第 1 引数はチェックの乗っているフレーム = 設定ウィンドウ**なので、
        -- パネルは名前で引き直す(設定を別ウィンドウにしたときの取りこぼし)。
        local panel = ui.GetFrame(addon_name_lower .. "indun_panel")
        if panel then
            local enable = g.indun_panel_settings.etc.move == 0 and 1 or 0
            panel:EnableMove(enable)
        end
    end
    Indun_panel_save_settings()
    -- 「ON のものだけ表示」で絞っているときは、**外した行をその場で一覧から消す**。
    -- 絞り込みは「今 ON のものだけ」を見せるための表示なので、外したものが残っていると
    -- 件数(n / m)と中身が食い違う。
    --
    -- **必ず一番最後に呼ぶこと。** 中身を作り直す = 今このイベントを処理している
    -- チェックそのものを壊すので、ctrl と設定を見終わってからでなければならない
    -- (押した直後にコントロールが消える形は core/90_addons_menu.lua の☆と同じ)。
    if from_config and (g.indun_panel_sc_only_on == true or g.indun_panel_row_only_on == true) then
        Indun_panel_config_rebuild()
    end
end

-- 段(520 / 540 / 560)のチェックボックスを、コンテンツ一覧のその行の右へ並べる。
-- 段を持たない行では何もしない。
--
-- **一覧の枠(rows_gb)の幅を超えないこと。** 呼び出しは 1 か所で、x = 285
-- (▲▼ 56px + チェックと名前 186px + 絵 35px の右)。段は 55px 刻みなので、
-- 3 段なら 285〜450 に収まる。枠は幅 484(窓 500 − 左右 8)で、右端はスクロールバーが
-- 20px ほど食うため使えるのは 464 まで。
--
-- **Lv 上限が上がって段が 4 つになると 505 まで伸びてはみ出す**(はみ出した分は黙って
-- 切れる)。そのときは名前の幅を詰めるか、窓の幅(INDUN_PANEL_CONFIG_W)を広げること。
-- 幅を広げるときは**両タブとも同じ値にする**(そちらのコメントを参照)。
function Indun_panel_tier_checkboxes(indun_panel, row_key, x, y)
    local row = Indun_panel_tier_row_of(row_key)
    local tiers = row and Indun_panel_tiers_of(row_key)
    if not tiers then
        return
    end
    local tooltip = g.lang == "Japanese" and
                        "{ol}チェックを外すとその段のボタンを出しません{nl}すべて外すとその行ごと消えます{nl}灰色のときは行そのものが非表示です" or
                        "{ol}Unchecked tiers are not shown{nl}Unchecking every tier hides the whole row{nl}Greyed out means the row itself is hidden"
    local row_enabled = Indun_panel_row_checked(row_key)
    local tier_x = x
    for _, tier in ipairs(tiers) do
        -- 名前は Indun_panel_ischecked が「綴り + 数字」で読み直す
        -- (綴りは INDUN_PANEL_TIER_ROWS の prefix。変えるなら両方揃えること)
        local checkbox = indun_panel:CreateOrGetControl('checkbox', row.prefix .. tier.label, tier_x, y, 25, 25)
        AUTO_CAST(checkbox)
        checkbox:SetCheck(Indun_panel_tier_enabled(row_key, tier.label) and 1 or 0)
        checkbox:SetEventScript(ui.LBUTTONUP, "Indun_panel_ischecked")
        checkbox:SetText(Indun_panel_tier_label_text(tier.label, row_enabled))
        checkbox:SetTextTooltip(tooltip)
        tier_x = tier_x + 55
    end
end

-- 設定は**パネルとは別のポップアップ**として出す。
--
-- 以前はパネルのフレームそのものを RemoveAllChild して設定画面へ作り替えていた。
-- パネルは画面の端に寄せて置くものなので設定もそこへ出ることになり、縦に長い一覧を
-- 画面の端で読む形になっていた。別フレームにして中央へ出す。
--
-- **中身はタブで分ける。** ショートカットに名前と▲▼を、コンテンツの行にも▲▼を付けた
-- ことで 1 枚には収まらなくなったため。分け方は「パネルそのものの設定」と
-- 「どのコンテンツを出すか」で、後者はセットごとに保存される設定でもある。
--
-- **タブは tab コントロールではなくボタンで作る。** ゲーム標準の tab は skin の縦幅に
-- 合わせて窓ごと大きくする必要があり、この土台(chat_memberlist)と馴染まない
-- (core/90_addons_menu.lua の設定画面が同じ理由でボタン式にしている)。
local INDUN_PANEL_CONFIG_TABS = {{
    key = "panel",
    jp = "パネル",
    en = "Panel"
}, {
    key = "contents",
    jp = "コンテンツ",
    en = "Contents"
}, {
    key = "ticket",
    jp = "入場券",
    en = "Tickets"
}}

-- 窓の幅。**タブで変えないこと。**
--
-- タブごとに幅を変えていたとき、窓を画面の右端へ寄せていると、広いタブへ切り替えた
-- ところではみ出したぶんだけ左へ戻され、狭いタブへ戻しても元の位置には復帰しなかった
-- (切り替えるたびに少しずつ左へ寄っていく)。幅を揃えれば丸めが起きない。
--
-- 500 はコンテンツ側の 1 行「▲▼(56) + チェックと名前(186) + 絵(35) + 段 3 つ(165)」から。
-- パネル側もこの幅に収まるよう、2 列組みの右列を寄せてある。
local INDUN_PANEL_CONFIG_W = 500
-- 窓の高さ。**幅と同じく、タブでも中身の量でも変えない。**
--
-- 一覧(ショートカット / コンテンツ)は数が増えるたびに伸びるので、窓の背丈で受け止めると
-- **画面へ収まらなくなる**。どちらの一覧も枠へ入れて縦スクロールさせる。
-- 640 にしてあるのは 1280x720 の画面にも収まる大きさだから(以前はパネル側だけ中身なりに
-- 伸ばしていて、ショートカット 11 個で 751px になり、720 の画面では最後の 1 行が
-- 画面の外へ落ちて押せなかった)。
local INDUN_PANEL_CONFIG_H = 640
-- タイトルとタブのぶん。中身(body)はこの下から始まる。
local INDUN_PANEL_CONFIG_BODY_Y = 78
-- 中身を入れる枠の名前。
--
-- **チェックのイベントの第 1 引数はこれらの groupbox になる**ので、「設定ウィンドウから
-- 来たか」を見る Indun_panel_from_config がこの名前を知っている必要がある。
--
-- **入れ物を増やしたらここへ足すこと。** 足し忘れると「設定から来た」と見なされず、
-- チェックを外してもパネルを組み直さなくなる。パネルは名前でコントロールを使い回すので、
-- 組み直さないと消したはずの行がその場に残り、次の行と重なって描かれる(実機で発生)。
local INDUN_PANEL_CONFIG_BODY = "config_body"
local INDUN_PANEL_CONFIG_ROWS = "rows_gb" -- コンテンツの一覧
local INDUN_PANEL_CONFIG_SC = "sc_gb" -- ショートカットの一覧
local INDUN_PANEL_CONFIG_TICKET = "ticket_gb" -- 入場券の使用順の一覧
local INDUN_PANEL_CONFIG_CONTAINERS = {INDUN_PANEL_CONFIG_BODY, INDUN_PANEL_CONFIG_ROWS, INDUN_PANEL_CONFIG_SC,
                                       INDUN_PANEL_CONFIG_TICKET}

function Indun_panel_config_frame_name()
    return addon_name_lower .. "indun_panel_config"
end

-- そのイベントが設定ウィンドウから来たか。
-- **タブ化で第 1 引数が groupbox(body)になった。** パネルの上のチェック
-- (常時展開 / 分裂)と区別が付かないと、イベント処理中に自分を壊すことになる
-- (Indun_panel_ischecked のコメント参照)。
function Indun_panel_from_config(frame)
    if not frame then
        return false
    end
    local name = frame:GetName()
    if name == Indun_panel_config_frame_name() then
        return true
    end
    for _, container in ipairs(INDUN_PANEL_CONFIG_CONTAINERS) do
        if name == container then
            return true
        end
    end
    return false
end

-- 今のタブ。知らない値が入っていたら既定へ落とす。
local function Indun_panel_config_tab()
    for _, def in ipairs(INDUN_PANEL_CONFIG_TABS) do
        if def.key == g.indun_panel_config_tab then
            return def.key
        end
    end
    return "panel"
end

-- 位置の丸め。**タブとセットで窓の大きさが変わる**ので、前の位置のままだと画面からはみ出す。
local function Indun_panel_config_clamp_pos(x, y, width, height)
    local map_ui = ui.GetFrame("map")
    local screen_w = (map_ui and map_ui:GetWidth()) or 1920
    local screen_h = (map_ui and map_ui:GetHeight()) or 1080
    if x + width > screen_w then
        x = screen_w - width
    end
    if y + height > screen_h then
        y = screen_h - height
    end
    if x < 0 then
        x = 0
    end
    if y < 0 then
        y = 0
    end
    return x, y
end

-- × と ESC で同じ動きにする。**設定を変えたぶんを反映するため、閉じたらパネルを組み直す。**
-- 片方だけ組み直すと「× なら反映されるのに ESC だと変わらない」という追いにくい差になる。
function Indun_panel_setting_frame_close()
    ui.DestroyFrame(Indun_panel_config_frame_name())
    -- 開いている間の変更は Indun_panel_refresh_panel が随時反映しているが、取りこぼしが
    -- あっても閉じたら必ず揃うよう、ここでも 1 回描き直す。
    -- **展開 / 畳みの状態は変えない。** 以前は Indun_panel_frame_init を直に呼んでいて、
    -- 設定を閉じるたびに展開していたパネルが畳まれていた(設定画面がパネルそのものだった
    -- 頃の名残で、別ウィンドウにした今は畳む理由が無い)。
    Indun_panel_refresh_panel()
end

-- セクションの見出し。戻り値は次に置ける y。
function Indun_panel_config_section(body, name, text, y, w)
    local title = body:CreateOrGetControl("richtext", "section_" .. name, 15, y, 400, 25)
    AUTO_CAST(title)
    title:SetText(string.format("{ol}{#FFD900}{s18}%s", text))
    local line = body:CreateOrGetControl("labelline", "line_" .. name, 10, y + 26, w - 20, 5)
    AUTO_CAST(line)
    line:SetSkinName("labelline2")
    return y + 36
end

-- 説明文。設定そのものより一段落とした色で置く(どこまでが操作する項目か分かるように)。
local function Indun_panel_config_note(body, name, text, y, w)
    local note = body:CreateOrGetControl("richtext", "note_" .. name, 15, y, w - 30, 20)
    AUTO_CAST(note)
    note:SetText("{ol}{#CCCCCC}{s15}" .. text)
    return y + 22
end

-- 一覧の枠のスクロール位置。**作り直しても位置を保つ**ための控え。
-- 控えは Indun_panel_config_build が RemoveAllChild より前に取る(壊した後の枠は必ず 0 を返す)。
local indun_panel_config_scroll = {}

-- 控えておいた位置へ戻す。**先に InvalidateScrollBar を呼ぶこと。**
-- 順番が逆だと、作り直す前(中身が空だったとき)の範囲で丸められて先頭に貼り付く
-- (core/90_addons_menu.lua のショートカットタブと同じ理由)。
local function Indun_panel_config_restore_scroll(gb, name, content_h)
    local prev = indun_panel_config_scroll[name] or 0
    local scroll_max = content_h - gb:GetHeight()
    if scroll_max < 0 then
        scroll_max = 0
    end
    if prev > scroll_max then
        prev = scroll_max
    end
    pcall(function()
        gb:InvalidateScrollBar()
    end)
    pcall(function()
        gb:SetScrollPos(prev)
    end)
end

-- ▲▼ の 2 つ。押せない端は灰色にして、押しても何も起きないことを見せる。
-- 動かす対象がショートカットと行で違うので、呼ぶ関数名は呼び出し側から渡す。
local function Indun_panel_config_move_buttons(body, prefix, idx, count, key, x, y, script)
    local is_jp = g.lang == "Japanese"
    local up = body:CreateOrGetControl("button", prefix .. "_up_" .. idx, x, y, 24, 26)
    AUTO_CAST(up)
    up:SetSkinName("None")
    up:SetTextAlign("center", "center")
    local can_up = idx > 1
    up:SetText(can_up and "{ol}{s18}{#FFFFFF}▲" or "{ol}{s18}{#555555}▲")
    if can_up then
        up:SetTextTooltip(is_jp and "{ol}1 つ前へ" or "{ol}Move up")
        up:SetEventScript(ui.LBUTTONUP, script)
        up:SetEventScriptArgString(ui.LBUTTONUP, key)
        up:SetEventScriptArgNumber(ui.LBUTTONUP, -1)
    end
    local down = body:CreateOrGetControl("button", prefix .. "_down_" .. idx, x + 26, y, 24, 26)
    AUTO_CAST(down)
    down:SetSkinName("None")
    down:SetTextAlign("center", "center")
    local can_down = idx < count
    down:SetText(can_down and "{ol}{s18}{#FFFFFF}▼" or "{ol}{s18}{#555555}▼")
    if can_down then
        down:SetTextTooltip(is_jp and "{ol}1 つ後ろへ" or "{ol}Move down")
        down:SetEventScript(ui.LBUTTONUP, script)
        down:SetEventScriptArgString(ui.LBUTTONUP, key)
        down:SetEventScriptArgNumber(ui.LBUTTONUP, 1)
    end
end

-- 「ON のものだけ表示」の絞り込み。**保存しない**(画面の見せ方だけなので、
-- 起動のたびに「すべて表示」から始まる。core/90_addons_menu.lua のショートカットタブと同じ)。
-- 絞っている間の▲▼は、隠れている行を飛び越して**見えている次の行と入れ替える**
-- (見えない行と入れ替えると「押しても動かない」ように見える。Indun_panel_move_in_order 参照)。
local function Indun_panel_config_filter_button(body, name, only_on, shown, total, y, script)
    local is_jp = g.lang == "Japanese"
    local btn = body:CreateOrGetControl("button", "filter_" .. name, 15, y, 190, 26)
    AUTO_CAST(btn)
    btn:SetSkinName(only_on and "test_pvp_btn" or "test_gray_button")
    -- 文字は**押すと何が起きるか**にする(core/90_addons_menu.lua の表示切り替えと同じ書き方)
    btn:SetText(only_on and (is_jp and "{ol}{s14}すべて表示" or "{ol}{s14}Show all") or
                    (is_jp and "{ol}{s14}ON のものだけ表示" or "{ol}{s14}Show only enabled"))
    btn:SetTextTooltip(is_jp and "{ol}チェックを入れているものだけに絞ります{nl}絞っている間の▲▼は、隠れている行を飛ばして動きます" or
                          "{ol}Show only the checked entries{nl}While filtered, the arrows skip over hidden rows")
    btn:SetEventScript(ui.LBUTTONUP, script)
    local count = body:CreateOrGetControl("richtext", "count_" .. name, 215, y + 4, 10, 20)
    AUTO_CAST(count)
    count:SetText(string.format(is_jp and "{ol}{s14}{#FFFFFF}%d / %d 件" or "{ol}{s14}{#FFFFFF}%d of %d", shown,
        total))
    return y + 32
end

-- ===== タブ 1: パネル =====
-- 位置・背景・表示まわりと、パネルへ並べるショートカット。戻り値は中身の高さ。
local function Indun_panel_config_build_panel(body, w, body_h)
    local is_jp = g.lang == "Japanese"
    local y = Indun_panel_config_section(body, "panel", is_jp and "Indun Panel の設定" or "Panel settings", 8, w)
    local position = body:CreateOrGetControl("button", "position", 15, y, 70, 30)
    AUTO_CAST(position)
    position:SetText("{ol}{s10}BASE POS")
    position:SetEventScript(ui.LBUTTONUP, "Indun_panel_frame_base_position")
    position:SetTextTooltip(is_jp and "{ol}ボタンを元の位置に戻す" or "Reset button position")
    -- **セット(A / B / C)のボタンはここには置かない。** セットが選ぶのは「表示する
    -- コンテンツの組み合わせ」なので、コンテンツのタブの、効く一覧のすぐ上へ置く。
    --
    -- 背景は**3 つを横に並べて、今使っているものを赤くする**(セットのボタンと同じ見せ方)。
    -- 以前は `SKIN SELECT` の 1 ボタンからコンテキストメニューを開く作りで、
    -- 今どれなのかが画面に出ていなかった。
    -- **見出しは上の行、ボタンはその下の行**に置く(BASE POS と同じ行に押し込むと、
    -- 何に対する 3 択なのかが読み取りにくい)。
    y = y + 38
    local skin_label = body:CreateOrGetControl("richtext", "skin_label", 15, y, 100, 20)
    AUTO_CAST(skin_label)
    skin_label:SetText(is_jp and "{ol}{s16}{#FFFFFF}背景" or "{ol}{s16}{#FFFFFF}Skin")
    y = y + 24
    local current_skin = g.indun_panel_settings.etc.skin_name or "chat_window_2"
    for i, skin in ipairs(INDUN_PANEL_SKINS) do
        local btn = body:CreateOrGetControl("button", "skin_" .. skin.key, 15 + (i - 1) * 95, y, 90, 30)
        AUTO_CAST(btn)
        btn:Resize(90, 30)
        btn:SetText("{ol}" .. (is_jp and skin.jp or skin.en))
        btn:AdjustFontSizeByWidth(90)
        btn:SetTextTooltip(is_jp and "{ol}パネルの背景を変えます" or "{ol}Change the panel background")
        btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_skin_ctrl")
        btn:SetEventScriptArgString(ui.LBUTTONUP, skin.key)
        if current_skin == skin.key then
            btn:SetSkinName("test_red_button")
        end
    end
    y = y + 38

    -- パネルの表示倍率。**背景と同じ見せ方**(横に並べて、今のものだけ赤くする)にする。
    -- ここに置くのは、上の「背景」と同じ「パネルの見た目」の話だから。
    local scale_label = body:CreateOrGetControl("richtext", "scale_label", 15, y, 200, 20)
    AUTO_CAST(scale_label)
    scale_label:SetText(is_jp and "{ol}{s16}{#FFFFFF}パネルの大きさ" or "{ol}{s16}{#FFFFFF}Panel size")
    y = y + 24
    local current_scale = math.floor(Indun_panel_scale() * 100 + 0.5)
    for i, pct in ipairs(g.INDUN_PANEL_SCALES) do
        local btn = body:CreateOrGetControl("button", "scale_" .. pct, 15 + (i - 1) * 95, y, 90, 30)
        AUTO_CAST(btn)
        btn:Resize(90, 30)
        btn:SetText(string.format("{ol}%d%%", pct))
        btn:AdjustFontSizeByWidth(90)
        btn:SetTextTooltip(is_jp and
                               "{ol}パネルの大きさを変えます{nl}座標も文字も一緒に縮みます{nl}この設定ウィンドウの大きさは変わりません" or
                               "{ol}Changes the panel size{nl}Positions and text shrink together{nl}This settings window keeps its size")
        btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_scale_ctrl")
        btn:SetEventScriptArgNumber(ui.LBUTTONUP, pct)
        if current_scale == pct then
            btn:SetSkinName("test_red_button")
        end
    end
    y = y + 38

    -- 表示まわりの設定。**2 列に並べる。** 1 列だと右半分が空くのに縦へ 4 行ぶん伸びる。
    --
    -- **文字から「チェックすると」を落としてある。** チェックボックスなのは見れば分かるので、
    -- 4 行すべての先頭に同じ 7 文字が並ぶだけになり、肝心の違いが右へ押し出されていた。
    -- **語尾は名詞止めで揃える**(「〜します」「〜する」を混ぜない)。何が起きるのかの
    -- 補足はツールチップへ回す。
    local etc_label = body:CreateOrGetControl("richtext", "etc_label", 15, y, 200, 20)
    AUTO_CAST(etc_label)
    etc_label:SetText(is_jp and "{ol}{s16}{#FFFFFF}表示・操作" or "{ol}{s16}{#FFFFFF}Display and controls")
    y = y + 24
    local other_settings = {{
        name = "en_ver",
        col = 1,
        jp = "英語で表示",
        en = "Display in English",
        jp_tip = "コンテンツ名を英語(内部の名前)で表示します",
        en_tip = "Show content names in English (internal keys)"
    }, {
        name = "field_mode",
        col = 2,
        jp = "フィールドでも表示",
        en = "Show in fields too",
        jp_tip = "街以外でもパネルを出します",
        en_tip = "Show the panel outside cities as well"
    }, {
        name = "move",
        col = 1,
        jp = "フレームを固定",
        en = "Lock the frame",
        jp_tip = "ドラッグで動かせなくします",
        en_tip = "Stops the panel from being dragged"
    }, {
        name = "shading",
        col = 2,
        jp = "網掛けで表示",
        en = "Shade the rows",
        jp_tip = "行を 1 行おきに網掛けします",
        en_tip = "Shades every other row"
    }}
    for i, setting_info in ipairs(other_settings) do
        -- 左 25 / 右 270 は、文字が長い「フィールドでも表示」が右の列と重ならず、
        -- かつ右端(窓 500)からはみ出さない間隔。窓を狭めるならここも詰めること。
        local col_x = setting_info.col == 1 and 25 or 270
        local col_y = y + math.floor((i - 1) / 2) * 35
        local checkbox = body:CreateOrGetControl("checkbox", setting_info.name, col_x, col_y, 25, 25)
        AUTO_CAST(checkbox)
        checkbox:SetCheck(g.indun_panel_settings.etc[setting_info.name])
        checkbox:SetEventScript(ui.LBUTTONUP, "Indun_panel_ischecked")
        checkbox:SetText(is_jp and "{ol}" .. setting_info.jp or "{ol}" .. setting_info.en)
        checkbox:SetTextTooltip("{ol}" .. (is_jp and setting_info.jp_tip or setting_info.en_tip))
    end
    y = y + math.ceil(#other_settings / 2) * 35 + 5

    -- ===== パネルに並べるショートカット =====
    --
    -- **アイコンだけを横一列に並べていたのをやめた。** 何のチェックなのか見た目からは
    -- 分からず、女神が増えるたびに右へ伸びて枠の外へ出ていた(サウレを足したときに
    -- 「レティーシャへ移動」が見切れた)。名前を添えて 1 行 1 つの縦並びにすると、
    -- 数が増えても下へ伸びるだけで破綻しない。
    y = Indun_panel_config_section(body, "shortcut", is_jp and "パネルに並べるショートカット" or
                                       "Shortcut buttons on the panel", y, w)
    y = Indun_panel_config_note(body, "shortcut", is_jp and "チェックしたものを、この順番で並べます" or
                                    "Checked buttons are shown in this order", y, w)
    local all = Indun_panel_ordered_shortcuts()
    local only_on = g.indun_panel_sc_only_on == true
    local shortcuts = {}
    for _, def in ipairs(all) do
        if not only_on or g.indun_panel_settings.cols[def.key] == 1 then
            table.insert(shortcuts, def)
        end
    end
    y = Indun_panel_config_filter_button(body, "sc", only_on, #shortcuts, #all, y,
        "Indun_panel_shortcut_filter_ctrl")
    -- 一覧は枠へ入れて縦スクロールさせる(コンテンツ側と同じ)。**窓の背丈で受け止めないこと。**
    -- 中身なりに伸ばしていたときはショートカット 11 個で 751px になり、1280x720 の画面では
    -- 最後の 1 行(レティーシャへ移動)が画面の外へ落ちて押せなかった。
    local gb = body:CreateOrGetControl("groupbox", INDUN_PANEL_CONFIG_SC, 8, y, w - 16,
        math.max(body_h - y - 8, 100))
    AUTO_CAST(gb)
    gb:SetSkinName("bg")
    gb:RemoveAllChild()
    gb:EnableScrollBar(1)
    local ry = 5
    for idx, def in ipairs(shortcuts) do
        Indun_panel_config_move_buttons(gb, "sc", idx, #shortcuts, def.key, 8, ry + 2, "Indun_panel_shortcut_move")
        local checkbox = gb:CreateOrGetControl("checkbox", def.key, 64, ry, 25, 25)
        AUTO_CAST(checkbox)
        local label = is_jp and def.jp or def.en
        -- 都市でだけ出るボタンはその場で分かるようにする。ツールチップだけだと
        -- 「チェックを入れたのに出ない」と読まれる(素の判定は g.get_map_type() == "City")。
        if def.city then
            label = label .. (is_jp and "  {s13}{#999999}(都市)" or "  {s13}{#999999}(cities)")
        end
        checkbox:SetText(string.format("{ol}{s16}{#FFFFFF}{img %s %d %d} %s", def.img, def.size, def.size, label))
        checkbox:SetEventScript(ui.LBUTTONUP, "Indun_panel_ischecked")
        checkbox:SetEventScriptArgString(ui.LBUTTONUP, "config")
        checkbox:SetTextTooltip(is_jp and "{ol}チェックするとパネルに表示" or "{ol}Check to show on the panel")
        local is_checked = 0
        for k, v in pairs(g.indun_panel_settings.cols) do
            if k == def.key then
                is_checked = v
                break
            end
        end
        checkbox:SetCheck(is_checked)
        ry = ry + 30
    end
    if #shortcuts == 0 then
        local empty = gb:CreateOrGetControl("richtext", "sc_empty", 12, 10, 10, 20)
        AUTO_CAST(empty)
        empty:SetText(is_jp and "{ol}{#FFA500}ON のショートカットがありません" or
                          "{ol}{#FFA500}No shortcut is enabled")
    end
    Indun_panel_config_restore_scroll(gb, INDUN_PANEL_CONFIG_SC, ry)
    return body_h
end

-- ===== タブ 2: コンテンツ =====
--
-- セットの切り替えと、行ごとの表示 ON/OFF。戻り値は中身の高さ。
--
-- **1 列 + 縦スクロールにしてある。** 以前は 2 列に折り返していたが、▲▼ を付けたら
-- 「右の列の先頭で▲を押すと左の列の末尾へ飛ぶ」ことになり、並べ替えの操作が読めなくなる。
-- パネルは縦 1 列なので、設定も同じ 1 列にして上下だけで考えられるようにした。
local function Indun_panel_config_build_contents(body, w, body_h)
    local is_jp = g.lang == "Japanese"
    -- セット(A / B / C)は**一覧の上**へ置く。選ぶのは下に並ぶチェックの組み合わせなので、
    -- 効く範囲の直前に置いて対応が分かるようにする。
    local y = 10
    local set_x = 15
    for _, item in ipairs(g.indun_panel_settings.set_names) do
        for key, name in pairs(item) do
            local btn = body:CreateOrGetControl("button", name .. key, set_x, y, 80, 30)
            AUTO_CAST(btn)
            btn:Resize(80, 30)
            btn:SetText("{ol}" .. name)
            btn:Resize(80, 30)
            btn:AdjustFontSizeByWidth(80)
            btn:SetTextTooltip(is_jp and "{ol}左クリック: セット選択{nl}右クリック: セット名変更" or
                                   "{ol}Left Click: Select Set{nl}Right Click: Change Set Name")
            btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_set_toggle")
            btn:SetEventScriptArgString(ui.LBUTTONUP, key)
            btn:SetEventScriptArgNumber(ui.LBUTTONUP, 1)
            btn:SetEventScript(ui.RBUTTONUP, "Indun_panel_INPUT_STRING_BOX")
            btn:SetEventScriptArgString(ui.RBUTTONUP, key)
            if g.indun_panel_settings.etc.use_set == key then
                btn:SetSkinName("test_red_button")
            end
            set_x = set_x + 85
        end
    end
    y = Indun_panel_config_note(body, "set", is_jp and "下のチェックはセットごとに保存 (右クリックで改名)" or
                                   "Saved per set (right click to rename)", y + 34, w)
    y = Indun_panel_config_section(body, "contents", is_jp and "レイド・コンテンツの表示 ON/OFF" or
                                       "Show / hide raids and contents", y + 4, w)
    -- 並べ替えは**セットに関わらず共通**。セットごとに順番まで変わると、切り替えるたびに
    -- 並びが動いて位置を覚えられない(段の設定と同じ持ち方)。
    y = Indun_panel_config_note(body, "contents", is_jp and "▲▼ で並ぶ順番を変えられます (セット共通)" or
                                    "Reorder with the arrows (shared by all sets)", y, w)
    local current_set = g.indun_panel_settings.etc.use_set
    local use_tbl = g.indun_panel_settings[current_set]
    local all = Indun_panel_ordered_induns()
    local only_on = g.indun_panel_row_only_on == true
    local rows = {}
    for _, entry in ipairs(all) do
        if not only_on or use_tbl[entry.key] == 1 then
            table.insert(rows, entry)
        end
    end
    y = Indun_panel_config_filter_button(body, "row", only_on, #rows, #all, y, "Indun_panel_row_filter_ctrl")

    -- 一覧は枠の中へ入れて縦スクロールさせる。行数はコンテンツが増えるたびに伸びるので、
    -- 窓の背丈で受け止めると画面へ収まらなくなる。
    local gb = body:CreateOrGetControl("groupbox", INDUN_PANEL_CONFIG_ROWS, 8, y, w - 16,
        math.max(body_h - y - 8, 100))
    AUTO_CAST(gb)
    gb:SetSkinName("bg")
    gb:RemoveAllChild()
    gb:EnableScrollBar(1)
    local row_h = 32
    local ry = 5
    for idx, entry in ipairs(rows) do
        local key, def = entry.key, entry.def
        Indun_panel_config_move_buttons(gb, "row", idx, #rows, key, 8, ry + 2, "Indun_panel_row_move")
        local checkbox = gb:CreateOrGetControl("checkbox", key, 64, ry, 25, 25)
        AUTO_CAST(checkbox)
        local is_checked = use_tbl[key]
        if is_checked == nil then
            is_checked = 0
        end
        checkbox:SetCheck(is_checked)
        checkbox:SetEventScript(ui.LBUTTONUP, "Indun_panel_ischecked")
        local bool = g.indun_panel_settings.etc.en_ver == 0 and is_jp
        local display_name = key
        if bool and def.jp then
            display_name = def.jp
        end
        checkbox:SetText(bool and "{ol}{#FFFFFF}{s16}" .. display_name or "{ol}{#FFFFFF}{s20}" .. key)
        checkbox:SetTextTooltip(is_jp and "チェックすると表示" or "Check to show")
        -- **名前の右にパネルと同じ絵を置く。** 名前だけだと、パネルのどの行のことなのかを
        -- 目で追い直すことになる(パネル側は絵が先頭に付いている)。
        local icon_cls = Indun_panel_row_icon_class(key, def)
        if icon_cls then
            local icon = gb:CreateOrGetControl("picture", "row_icon_" .. key, 250, ry + 2, 22, 22)
            AUTO_CAST(icon)
            icon:SetImage(icon_cls.Icon)
            icon:SetEnableStretch(1)
            icon:EnableHitTest(0)
        end
        -- 段(520 / 540 / 560)を持つ行は、その行の右へ段のチェックを並べる
        Indun_panel_tier_checkboxes(gb, key, 285, ry)
        ry = ry + row_h
    end
    if #rows == 0 then
        local empty = gb:CreateOrGetControl("richtext", "row_empty", 12, 10, 10, 20)
        AUTO_CAST(empty)
        empty:SetText(is_jp and "{ol}{#FFA500}表示 ON のコンテンツがありません" or
                          "{ol}{#FFA500}No content is enabled")
    end
    Indun_panel_config_restore_scroll(gb, INDUN_PANEL_CONFIG_ROWS, ry)
    return body_h
end

-- 「入場券」タブ。**グループごとに、券の分類を使う順に並べる。**
--
-- 一覧に入れているのは「レイド」「チャレンジ / 分裂特異点」「その他」の 3 つ。
-- 経路は 6 つあるが、利用者から見た使い分けは「週ごとに配られる券か / 買える枠が
-- あるか」の違いなので、そこで束ねている。
--
-- **▲▼ の入れ替えは一覧全体へ番号を振り直す**(隣と入れ替えるだけの作りだと、
-- 番号を持たない項目が混ざったとき「押しても動かない」組み合わせが残る。
-- core/90_addons_menu.lua の並べ替えと同じ考え方)。
function Indun_panel_config_build_ticket(body, w, body_h)
    local is_jp = g.lang == "Japanese"
    local y = Indun_panel_config_section(body, "ticket", is_jp and "入場券の使用順" or "Ticket use order", 8, w)
    y = Indun_panel_config_note(body, "ticket", is_jp and
        "上にあるものから順に試します。持っていない分類は飛ばします。" or
        "Tried from the top; a category you have none of is skipped.", y, w)
    local gb = body:CreateOrGetControl("groupbox", INDUN_PANEL_CONFIG_TICKET, 8, y, w - 16,
        math.max(body_h - y - 8, 100))
    AUTO_CAST(gb)
    gb:SetSkinName("bg")
    gb:RemoveAllChild()
    gb:EnableScrollBar(1)
    local ry = 5
    for _, group in ipairs(g.INDUN_PANEL_TICKET_GROUPS) do
        local head = gb:CreateOrGetControl("richtext", "tk_head_" .. group.key, 10, ry, w - 60, 22)
        AUTO_CAST(head)
        head:SetText(string.format("{ol}{#FFD900}{s16}%s", is_jp and group.jp or group.en))
        head:AdjustFontSizeByWidth(w - 60)
        ry = ry + 26
        local order = Indun_panel_ticket_order(group.key)
        for idx, kind in ipairs(order) do
            local def = Indun_panel_ticket_kind_def(kind)
            -- ▲▼ の引数は 1 本の文字列しか渡せないので、グループと分類をつないで渡す。
            local arg = group.key .. ":" .. kind
            Indun_panel_config_move_buttons(gb, "tk_" .. group.key, idx, #order, arg, 12, ry, "Indun_panel_ticket_move")
            local label = gb:CreateOrGetControl("richtext", "tk_" .. group.key .. "_" .. idx, 70, ry + 4, w - 110, 22)
            AUTO_CAST(label)
            label:SetText(string.format("{ol}{#FFFFFF}{s16}%d. %s", idx, def and (is_jp and def.jp or def.en) or kind))
            if def then
                label:SetTextTooltip("{ol}" .. (is_jp and def.jp_note or def.en_note))
            end
            ry = ry + 30
        end
        ry = ry + 8
    end
    Indun_panel_config_restore_scroll(gb, INDUN_PANEL_CONFIG_TICKET, ry)
    return body_h
end

-- 入場券の使用順の▲▼。**保存してからパネルも組み直す**(ツールチップの「優先順位」が
-- この順序を写しているので、直さないと説明と動きが食い違う)。
function Indun_panel_ticket_move(frame, ctrl, arg, delta)
    delta = tonumber(delta) or 0
    if delta == 0 or type(arg) ~= "string" then
        return
    end
    local group_key, kind = string.match(arg, "^(.-):(.+)$")
    local def = group_key and Indun_panel_ticket_group_def(group_key)
    if not def then
        return
    end
    local order = Indun_panel_ticket_order(group_key)
    local at
    for i, k in ipairs(order) do
        if k == kind then
            at = i
            break
        end
    end
    local to = at and (at + delta)
    if not at or not to or to < 1 or to > #order then
        return
    end
    order[at], order[to] = order[to], order[at]
    local settings = g.indun_panel_settings
    if type(settings.ticket_order) ~= "table" then
        settings.ticket_order = {}
    end
    settings.ticket_order[group_key] = order
    Indun_panel_save_settings()
    g.vlog("indun_panel: 入場券の使用順を変えた group=%s 順=%s", group_key, table.concat(order, ">"))
    Indun_panel_refresh_panel()
    Indun_panel_config_rebuild()
end

-- タブとその中身を作る。**開き直しでもタブ切り替えでもここを通る**ので、中身は毎回作り直す。
-- keep_pos = true なら今の位置を保つ(画面からはみ出したぶんだけ戻す)。
local function Indun_panel_config_build(config_frame, keep_pos)
    local is_jp = g.lang == "Japanese"
    local tab = Indun_panel_config_tab()
    local w = INDUN_PANEL_CONFIG_W
    local title = config_frame:CreateOrGetControl("richtext", "title", 20, 8, 300, 30)
    AUTO_CAST(title)
    title:SetText(is_jp and "{ol}{#FFFFFF}{s20}Indun Panel 設定" or "{ol}{#FFFFFF}{s20}Indun Panel Settings")
    local close = config_frame:CreateOrGetControl("button", "close", 0, 0, 30, 30)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Indun_panel_setting_frame_close")
    for i, def in ipairs(INDUN_PANEL_CONFIG_TABS) do
        local btn = config_frame:CreateOrGetControl("button", "tab_" .. def.key, 15 + (i - 1) * 110, 42, 105, 28)
        AUTO_CAST(btn)
        btn:SetSkinName(def.key == tab and "test_pvp_btn" or "test_gray_button")
        btn:SetText("{ol}{s16}" .. (is_jp and def.jp or def.en))
        btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_config_tab_ctrl")
        btn:SetEventScriptArgString(ui.LBUTTONUP, def.key)
    end
    local body = config_frame:CreateOrGetControl("groupbox", INDUN_PANEL_CONFIG_BODY, 0, INDUN_PANEL_CONFIG_BODY_Y, w,
        100)
    AUTO_CAST(body)
    body:SetSkinName("None")
    body:EnableScrollBar(0)
    -- **中身を壊す前にスクロール位置を控える。** ここを飛ばすと、▲▼ を押して組み立て直した
    -- 瞬間に一覧の先頭へ戻る(下のほうの行を触れない)。控えるのは RemoveAllChild より前で
    -- なければならない(壊した後の枠は必ず 0 を返す)。
    for _, name in ipairs({INDUN_PANEL_CONFIG_ROWS, INDUN_PANEL_CONFIG_SC, INDUN_PANEL_CONFIG_TICKET}) do
        local gb = GET_CHILD_RECURSIVELY(config_frame, name)
        if gb then
            indun_panel_config_scroll[name] = g.scroll_cur_pos(gb)
        end
    end
    -- **中身は毎回捨てて作り直す。** タブによって並ぶものが違い、名前で使い回すと
    -- 前のタブのコントロールが残って重なる(CreateOrGetControl は名前で引き当てるだけ)。
    body:RemoveAllChild()
    local content_h = INDUN_PANEL_CONFIG_H - INDUN_PANEL_CONFIG_BODY_Y
    if tab == "contents" then
        Indun_panel_config_build_contents(body, w, content_h)
    elseif tab == "ticket" then
        Indun_panel_config_build_ticket(body, w, content_h)
    else
        Indun_panel_config_build_panel(body, w, content_h)
    end
    body:Resize(w, content_h)
    local h = INDUN_PANEL_CONFIG_BODY_Y + content_h
    config_frame:Resize(w, h)
    local pos_x, pos_y
    if keep_pos then
        pos_x, pos_y = Indun_panel_config_clamp_pos(config_frame:GetX(), config_frame:GetY(), w, h)
    else
        pos_x, pos_y = g.settings_frame_pos(w, h)
    end
    config_frame:SetPos(pos_x, pos_y)
    g.vlog("indun_panel: 設定のタブ %s を組み立てた(%dx%d / 位置 %d,%d / %s)", tab, w, h, pos_x, pos_y,
        keep_pos and "位置を引き継ぎ" or "初回")
end

-- 設定画面が開いていれば中身を作り直す。開いていなければ何もしない。
-- **グローバルにしておくこと。** これより前で定義しているセット切替(Indun_panel_set_toggle)から
-- 呼ぶので、local だと見えない(CLAUDE.md「local function は呼び出しより前で定義する」)。
function Indun_panel_config_rebuild()
    local frame = ui.GetFrame(Indun_panel_config_frame_name())
    if frame and frame:IsVisible() == 1 then
        AUTO_CAST(frame)
        Indun_panel_config_build(frame, true)
    end
end

-- タブの切り替え。窓はそのままで中身だけ入れ替える。
function Indun_panel_config_tab_ctrl(frame, ctrl, tab_key, num)
    g.indun_panel_config_tab = tab_key
    Indun_panel_config_rebuild()
end

-- 「ON のものだけ表示」の切り替え。画面の見せ方だけなので保存しない。
function Indun_panel_shortcut_filter_ctrl(frame, ctrl, str, num)
    g.indun_panel_sc_only_on = not (g.indun_panel_sc_only_on == true)
    Indun_panel_config_rebuild()
end

function Indun_panel_row_filter_ctrl(frame, ctrl, str, num)
    g.indun_panel_row_only_on = not (g.indun_panel_row_only_on == true)
    Indun_panel_config_rebuild()
end

-- ショートカットの▲▼。並べ替えたらパネルもその場で並べ直す。
function Indun_panel_shortcut_move(frame, ctrl, key, delta)
    delta = tonumber(delta) or 0
    -- 絞り込み中は、隠れている行を飛ばして「見えている次の行」と入れ替える
    local visible
    if g.indun_panel_sc_only_on == true then
        visible = function(item)
            return g.indun_panel_settings.cols[item.key] == 1
        end
    end
    if delta == 0 or
        not Indun_panel_move_in_order(Indun_panel_ordered_shortcuts(), "col_order", key, delta, visible) then
        return
    end
    Indun_panel_save_settings()
    Indun_panel_refresh_panel()
    Indun_panel_config_rebuild()
end

-- コンテンツの行の▲▼。
function Indun_panel_row_move(frame, ctrl, key, delta)
    delta = tonumber(delta) or 0
    local visible
    if g.indun_panel_row_only_on == true then
        local use_tbl = g.indun_panel_settings[g.indun_panel_settings.etc.use_set]
        visible = function(item)
            return use_tbl and use_tbl[item.key] == 1
        end
    end
    if delta == 0 or not Indun_panel_move_in_order(Indun_panel_ordered_induns(), "row_order", key, delta, visible) then
        return
    end
    Indun_panel_save_settings()
    Indun_panel_refresh_panel()
    Indun_panel_config_rebuild()
end

function Indun_panel_setting_frame_open()
    -- **開き直しで中央へ戻さないこと。** この関数はセット名の変更からも呼ばれる。
    -- 毎回 g.settings_frame_pos を通していたので、押すたびに窓が画面中央へ飛んでいた。
    local prev_frame = ui.GetFrame(Indun_panel_config_frame_name())
    local keep_pos = (prev_frame ~= nil and prev_frame:IsVisible() == 1)
    local config_frame = ui.CreateNewFrame("chat_memberlist", Indun_panel_config_frame_name())
    AUTO_CAST(config_frame)
    g.block_click_through(config_frame)
    config_frame:EnableHitTest(1)
    config_frame:SetSkinName("test_frame_low")
    config_frame:SetLayerLevel(999)
    Indun_panel_config_build(config_frame, keep_pos)
    config_frame:ShowWindow(1)
    -- **ShowWindow(1) の後に積むこと。** まだ出ていない状態で積むと、直後の同期で
    -- 「閉じ終わった登録」と見なされてその場で捨てられる(core/00_header.lua)。
    -- × と同じ後始末(パネルの組み直し)が要るので、esc_register_destroy ではなく esc_register。
    g.esc_register(Indun_panel_config_frame_name(), "Indun_panel_setting_frame_close")
end

-- 戻すのは**パネル**の位置。**引数のフレームを動かさないこと。**
-- このボタンは設定ウィンドウの上にあるので、第 1 引数は設定ウィンドウ自身で、
-- 素で動かすと設定ウィンドウのほうが飛んでいく(設定を別ウィンドウにしたときの取りこぼし)。
function Indun_panel_frame_base_position()
    g.indun_panel_settings.etc.x = 665
    g.indun_panel_settings.etc.y = 30
    Indun_panel_save_settings()
    local panel = ui.GetFrame(addon_name_lower .. "indun_panel")
    if panel then
        panel:SetPos(665, 30)
    end
end

function Indun_panel_INPUT_STRING_BOX(frame, ctrl, set_key, num)
    local inputstring = ui.GetFrame("inputstring")
    inputstring:Resize(500, 220)
    inputstring:SetLayerLevel(999)
    local edit = GET_CHILD(inputstring, 'input', "ui::CEditControl")
    edit:SetNumberMode(0)
    edit:SetMaxLen(999)
    edit:SetText("")
    inputstring:ShowWindow(1)
    inputstring:SetEnable(1)
    local title = inputstring:GetChild("title")
    AUTO_CAST(title)
    local text = g.lang == "Japanese" and "{ol}{#FFFFFF}セット名を入力" or "{ol}{#FFFFFF}Enter set name"
    title:SetText(text)
    local confirm = inputstring:GetChild("confirm")
    confirm:SetEventScript(ui.LBUTTONUP, "Indun_panel_save_setname")
    confirm:SetEventScriptArgString(ui.LBUTTONUP, set_key)
    edit:SetEventScript(ui.ENTERKEY, "Indun_panel_save_setname")
    edit:SetEventScriptArgString(ui.ENTERKEY, set_key)
    edit:AcquireFocus()
end

function Indun_panel_save_setname(inputstring, ctrl, set_key, num)
    inputstring:ShowWindow(0)
    local edit = GET_CHILD(inputstring, 'input')
    local get_text = edit:GetText()
    if get_text == "" then
        local text = g.lang == "Japanese" and "{ol}文字を入力してください" or "{ol}Please enter text"
        ui.SysMsg(text)
        Indun_panel_INPUT_STRING_BOX(nil, nil, set_key, 0)
        return
    end
    local text = g.lang == "Japanese" and "{ol}セット名を登録しました" or "{ol}Set name registered"
    ui.SysMsg(text)
    for _, item in ipairs(g.indun_panel_settings.set_names) do
        if item[set_key] then
            item[set_key] = get_text
            break
        end
    end
    Indun_panel_save_settings()
    -- 名前を変えたボタンを出し直す(窓は開いたままなので中身だけ)
    Indun_panel_config_rebuild()
end

-- 背景のボタン。押した直後に設定の一覧も組み直して、赤い印を押したものへ移す。
-- パネルの表示倍率を変える。**パネルは組み直しが要る**(座標を持ったコントロールを
-- 名前で使い回すので、Resize だけでは前の大きさのまま残る)。
-- 設定ウィンドウは倍率を掛けないので、中身の作り直しだけでよい(赤いボタンの移動)。
function Indun_panel_scale_ctrl(frame, ctrl, str, pct)
    pct = tonumber(pct)
    if not pct or pct == math.floor(Indun_panel_scale() * 100 + 0.5) then
        return
    end
    g.indun_panel_settings.etc.scale = pct
    Indun_panel_save_settings()
    g.vlog("indun_panel: パネルの大きさを %d%% にした", pct)
    Indun_panel_refresh_panel()
    Indun_panel_config_rebuild()
end

function Indun_panel_skin_ctrl(frame, ctrl, skin_name, num)
    Indun_panel_frame_skin_select_(skin_name)
    Indun_panel_config_rebuild()
end

function Indun_panel_frame_skin_select_(skin_name)
    g.indun_panel_settings.etc.skin_name = skin_name
    Indun_panel_save_settings()
    -- パネルを描き直して、選んだ背景をその場で見せる。設定ウィンドウは別フレームなので
    -- 開いたまま残る(以前はパネル自身を設定画面にしていたため、ここで設定が閉じていた)。
    -- **frame_open を直に呼ばないこと。** 畳んでいるパネルが背景を選んだ瞬間に展開する。
    -- 設定からの変更は展開 / 畳みの状態を変えない方針で揃えてある。
    Indun_panel_refresh_panel()
end

-- 各行の描画関数が「この行は横 n px 使った」と申告する先。
-- パネルの幅は Indun_panel_frame_contents の最後でこの値から決める。
function Indun_panel_note_row_width(width)
    if not width then
        return
    end
    if not g.indun_panel_row_width or width > g.indun_panel_row_width then
        g.indun_panel_row_width = width
    end
end

-- Lv560 で足した ID が実機のクライアントで引けているかを、起動につき 1 回だけ出す。
-- パネルの組み立ては FPS_UPDATE 経由で何度も走るので、毎回出すとログが流れて埋もれる。
-- 見るのは「その ID の Indun クラスが引けたか」と「引けた場合の ClassName」。
-- 引けていなければ ID がずれている(データ側で差し替わった)ということなので、ここで分かる。
local vlog_new_induns_done = false
local function vlog_new_induns()
    if vlog_new_induns_done then
        return
    end
    vlog_new_induns_done = true
    local targets = {733, 734, 736, 737, 732, 1006, 1007, 2003}
    for _, indun_type in ipairs(targets) do
        local cls = GetClassByType("Indun", indun_type)
        if cls then
            g.vlog("indun_panel: Lv560 indun %d = %s (Lv%s, Ticket=%s)", indun_type,
                tostring(TryGetProp(cls, 'ClassName', 'None')), tostring(TryGetProp(cls, 'Level', 0)),
                tostring(TryGetProp(cls, 'TicketingType', 'None')))
        else
            g.vlog("indun_panel: Lv560 indun %d が引けない(ID が変わった可能性)", indun_type)
        end
    end
end

function Indun_panel_frame_contents(configbtn)
    vlog_new_induns()
    local indun_panel = ui.GetFrame(addon_name_lower .. "indun_panel")
    local shop_buttons = {"gabija", "vakarine", "rada", "jurate", "austeja", "saule"}
    local shop_props = {"GabijaCertificate", "VakarineCertificate", "RadaCertificate", "JurateCertificate",
                        "AustejaCertificate", "SauleCertificate"}
    local shop_names_jp = {"ガビヤショップ", "ヴァカリネショップ", "ラダショップ",
                           "ユラテショップ", "アウステヤショップ", "サウレショップ"}
    local shop_names_en = {"Gabija Shop", "Vakarine Shop", "Rada Shop", "Jurate Shop", "Austeja Shop", "Saule Shop"}
    local account_obj = GetMyAccountObj()
    for i, btn_name in ipairs(shop_buttons) do
        local btn = GET_CHILD_RECURSIVELY(indun_panel, btn_name)
        if btn then
            AUTO_CAST(btn)
            local count = GET_COMMAED_STRING(TryGetProp(account_obj, shop_props[i], "0"))
            local name = g.lang == "Japanese" and shop_names_jp[i] or shop_names_en[i]
            local tooltip = string.format("{ol}%s{nl}{#FFFF00}%s", name, count)
            btn:SetTextTooltip(tooltip)
        end
    end
    local prefix = "DD"
    if g.indun_panel_settings.etc.skin_name and g.indun_panel_settings.etc.skin_name == "bg" then
        prefix = "FF"
    end
    local x = Indun_panel_s(150)
    local shading_lines = {}
    -- 行の右端はこれまで一律 600px で足りていたが、チャレンジ / 分裂が Lv 帯 3 段になって
    -- はみ出すようになった。実際に描いた行の幅を覚えておいて、最後にパネルの幅を決める。
    -- (チャレンジを非表示にしている人のパネルは今までどおりの幅のまま)
    g.indun_panel_row_width = Indun_panel_s(600)
    local current_set = g.indun_panel_settings.etc.use_set
    local use_tbl = g.indun_panel_settings[current_set]
    if not use_tbl then
        return 1
    end
    local y = Indun_panel_s(40)
    local index = 1
    local index_remainder = 0
    local lasy_y = 0
    -- 並びは設定ウィンドウの▲▼で決まる(induns の定義順が既定)
    for _, entry in ipairs(Indun_panel_ordered_induns()) do
        local key, value = entry.key, entry.def
        -- 段(520 / 540 / 560)を全部外した行は、見出しだけの空の行になるので畳む。
        -- 段を持たない行では Indun_panel_tier_row_visible が常に true を返す。
        if use_tbl[key] == 1 and Indun_panel_tier_row_visible(key) then
            if g.indun_panel_settings.etc.shading == 1 then
                local line = indun_panel:CreateOrGetControl("picture", "line" .. key, Indun_panel_s(5),
                    y - Indun_panel_s(2), Indun_panel_s(740), Indun_panel_s(33))
                -- 縞の幅はパネルの幅が確定してから合わせ直す(行を描く前は幅が分からない)
                table.insert(shading_lines, line)
                AUTO_CAST(line)
                line:SetImage("fullwhite")
                line:SetEnableStretch(1)
                line:EnableHitTest(0)
                local tone = (index % 2 == 1) and "696969" or "A9A9A9"
                line:SetColorTone(prefix .. tone)
            end
            if key == "jsr" or value.icon then
                local img_icon = indun_panel:CreateOrGetControl("picture", "img_icon" .. key,
                    x - Indun_panel_s(140), y + Indun_panel_s(5), Indun_panel_s(20), Indun_panel_s(20))
                AUTO_CAST(img_icon)
                local icon_cls = Indun_panel_row_icon_class(key, value)
                if icon_cls then
                    img_icon:SetImage(icon_cls.Icon)
                    img_icon:SetEnableStretch(1)
                    img_icon:EnableHitTest(0)
                end
                local text = indun_panel:CreateOrGetControl("richtext", key, x - Indun_panel_s(120),
                    y + Indun_panel_s(5))
                local is_jp_mode = (g.indun_panel_settings.etc.en_ver == 0 and g.lang == "Japanese")
                local display_name = key
                if is_jp_mode and value.jp then
                    display_name = value.jp
                end
                local font_tag = is_jp_mode and Indun_panel_f(16) or Indun_panel_f(20)
                text:SetText(string.format("{ol}{#FFFFFF}%s%s", font_tag, display_name))
                index = index + 1
                if key == "challenge" then
                    local tooltip = g.lang == "Japanese" and
                                        "{ol}左クリック: チャレンジマップの1週間分のスケジュール表示" or
                                        "{ol}Left Click: Display the schedule for one week of the Challenge Map"
                    img_icon:EnableHitTest(1)
                    img_icon:SetEventScript(ui.LBUTTONUP, "Indun_panel_challenge_map_context")
                    img_icon:SetTextTooltip(tooltip)
                    text:EnableHitTest(1)
                    text:SetEventScript(ui.LBUTTONUP, "Indun_panel_challenge_map_context")
                    text:SetTextTooltip(tooltip)
                end
                text:AdjustFontSizeByWidth(Indun_panel_s(120))
            end
            if type(value) == "table" then
                if key == "challenge" then
                    -- 段の一覧は関数側が持っているので、行につき 1 回だけ呼ぶ
                    Indun_panel_challenge_frame(indun_panel, key, nil, nil, y, x)
                elseif key == "singularity" then
                    Indun_panel_singularity_frame(indun_panel, key, nil, nil, y, x)
                elseif key == "light_uriel" or key == "dark_uriel" or key == "zmei" or key == "belliora" or key ==
                    "laimara" or key == "ledania" or key == "neringa" or key == "golem" or key == "merregina" or key ==
                    "slogutis" or key == "upinis" or key == "roze" or key == "falouros" or key == "reservoir" then -- レイド系 (onsweep)
                    for sub_key, sub_value in pairs(value) do
                        if sub_key ~= "jp" and sub_key ~= "icon" then
                            Indun_panel_create_frame_onsweep(indun_panel, key, sub_key, sub_value, y, x)
                        end
                    end
                elseif key == "jellyzele" or key == "delmore" or key == "giltine" or key == "memory" then -- 通常ダンジョン系 (create_frame)
                    for sub_key, sub_value in pairs(value) do
                        if sub_key ~= "jp" and sub_key ~= "icon" then
                            Indun_panel_create_frame(indun_panel, key, sub_key, sub_value, y, x)
                        end
                    end
                elseif key == "telharsha" then
                    Indun_panel_telharsha_frame(indun_panel, key, value.id, y, x)
                elseif key == "bernice" then
                    Indun_panel_velnice_frame(indun_panel, key, value.id, y, x)
                elseif key == "wailing" then
                    Indun_panel_cemetery_frame(indun_panel, key, value.id, y, x)
                elseif key == "zawra" then
                    Indun_panel_resonance_frame(indun_panel, key, value.id, y, x)
                elseif key == "jsr" then
                    Indun_panel_jsr_frame(indun_panel, y, x)
                end
            end
            y = y + Indun_panel_s(33)
        end
        index_remainder = index % 2
        lasy_y = y
    end
    local y = lasy_y or Indun_panel_s(40)
    local status, err = pcall(Indun_panel_create_currency_display, indun_panel, y)
    if not status then
        print("[IndunPanel] Currency Display Error: " .. tostring(err))
    end
    y = y + Indun_panel_s(40)
    if g.indun_panel_settings.etc.shading == 1 then
        local line = indun_panel:CreateOrGetControl("picture", "last_line", Indun_panel_s(5),
            y - Indun_panel_s(2), Indun_panel_s(740), Indun_panel_s(33))
        table.insert(shading_lines, line)
        AUTO_CAST(line)
        line:SetImage("fullwhite")
        line:SetEnableStretch(1)
        line:EnableHitTest(0)
        line:SetColorTone(prefix .. (index_remainder == 1 and "696969" or "A9A9A9"))
    end
    indun_panel:SetLayerLevel(80)
    -- **上段(ボタンの並び)より狭くしないこと。** 行の幅だけで決めていたので、
    -- ショートカットを全部出すと歯車が枠の外へ出ていた(実機で発生)。
    -- ショートカットが 10 個までは上段が 750px でちょうど行の幅と並んでいたが、
    -- 「レティーシャへ移動」を出せるようにして 11 個になった時点で 780px 要る。
    -- ショートカットは今後も増えるので、上段の幅は Indun_panel_frame_open が控える。
    local panel_width = math.max(x + (g.indun_panel_row_width or Indun_panel_s(600)),
        g.indun_panel_header_width or 0)
    for _, line in ipairs(shading_lines) do
        line:Resize(panel_width - Indun_panel_s(10), Indun_panel_s(33))
    end
    indun_panel:Resize(panel_width, y)
    indun_panel:SetSkinName(g.indun_panel_settings.etc.skin_name or "chat_window_2")
    indun_panel:EnableHitTest(1)
    indun_panel:SetAlpha(100)
    return 1
end

function Indun_panel_create_currency_display(indun_panel, y)
    local account_obj = GetMyAccountObj()
    local bonusTP_pic = indun_panel:CreateOrGetControl("richtext", "bonusTP_pic", Indun_panel_s(320),
        y + Indun_panel_s(5))
    AUTO_CAST(bonusTP_pic)
    bonusTP_pic:SetText(string.format("{img bonusTP_pic %d %d}", Indun_panel_s(22), Indun_panel_s(22)))
    local bonusTP_count = indun_panel:CreateOrGetControl("richtext", "bonusTP_count", Indun_panel_s(350),
        y + Indun_panel_s(5))
    AUTO_CAST(bonusTP_count)
    bonusTP_count:SetText("{ol}{#FFD900}" .. Indun_panel_f(18) .. account_obj.Medal)
    bonusTP_count:SetTextTooltip("{ol}Free TP")
    local housing_btn = indun_panel:CreateOrGetControl("richtext", "housing_btn", Indun_panel_s(370),
        y + Indun_panel_s(5))
    AUTO_CAST(housing_btn)
    housing_btn:SetText(string.format("{img btn_housing_editmode_small_resize %d %d}", Indun_panel_s(23),
        Indun_panel_s(23)))
    local housing_count = indun_panel:CreateOrGetControl("richtext", "housing_count", Indun_panel_s(400),
        y + Indun_panel_s(5))
    AUTO_CAST(housing_count)
    -- housing_count:SetText("{ol}{#FFD900}{s18}...")
    housing_count:SetTextTooltip("{ol}Housing Point")
    local current_time = imcTime.GetAppTime()
    if not g.indun_panel_housing_call_time or (current_time - g.indun_panel_housing_call_time) > 5 then
        g.indun_panel_housing_call_time = current_time
        Indun_panel_get_my_housing_point_callback_ready()
    elseif g.indun_panel_housing_point then
        housing_count:SetText("{ol}{#FFD900}" .. Indun_panel_f(18) .. g.indun_panel_housing_point)
    end
    local tos_coin = indun_panel:CreateOrGetControl("richtext", "tos_coin", Indun_panel_s(450), y + Indun_panel_s(5))
    tos_coin:SetText(string.format("{img icon_item_Tos_Event_Coin %d %d}", Indun_panel_s(21), Indun_panel_s(21)))
    local tos_coin_count = indun_panel:CreateOrGetControl("richtext", "tos_coin_count", Indun_panel_s(475),
        y + Indun_panel_s(5))
    local coin_count = GET_COMMAED_STRING(TryGetProp(account_obj, "EVENT_TOS_WHOLE_TOTAL_COIN", "0"))
    local target_coin = GET_COMMAED_STRING(g.indun_panel_settings.etc.toscoin or 0)
    tos_coin_count:SetText(string.format("{ol}{#FFD900}%s%s/{#FFD900}%s", Indun_panel_f(18), coin_count, target_coin))
    local pvpmine = indun_panel:CreateOrGetControl("richtext", "pvpmine", Indun_panel_s(605), y + Indun_panel_s(5))
    pvpmine:SetText(string.format("{img pvpmine_shop_btn_total %d %d}", Indun_panel_s(25), Indun_panel_s(25)))
    local pvpminecount = indun_panel:CreateOrGetControl("richtext", "pvpminecount", Indun_panel_s(630),
        y + Indun_panel_s(5))
    local mine_count = GET_COMMAED_STRING(TryGetProp(account_obj, "MISC_PVP_MINE2", "0"))
    pvpminecount:SetText(string.format("{ol}{#FFD900}%s%s", Indun_panel_f(18), mine_count))
end

function Indun_panel_get_my_housing_point_callback_ready()
    local aidx = session.loginInfo.GetAID()
    GetMyHousingPageInfo("Indun_panel_get_my_housing_point_callback", aidx)
end

function Indun_panel_get_my_housing_point_callback(code, ret_json)
    if code ~= 200 or not ret_json or ret_json == "" then
        return
    end
    local status, parsed = pcall(json.decode, ret_json)
    if not (status and parsed) then
        return
    end
    if not parsed or type(parsed) ~= "table" then
        return
    end
    local housing_point = 0
    if parsed["pointInfo"] and parsed["pointInfo"]["personalHousing_Point1"] then
        housing_point = tonumber(parsed["pointInfo"]["personalHousing_Point1"]) or 0
    end
    g.indun_panel_housing_point = housing_point
    local indun_panel = ui.GetFrame(addon_name_lower .. "indun_panel")
    if indun_panel and indun_panel:IsVisible() == 1 then
        local housing_count = GET_CHILD_RECURSIVELY(indun_panel, "housing_count")
        if housing_count then
            housing_count:SetText("{ol}{#FFD900}{s18}" .. housing_point)
        end
    end
end

function Indun_panel_item_buy_use(recipe_name)
    local recipe_cls = GetClass("ItemTradeShop", recipe_name)
    if not recipe_cls then
        return
    end
    session.ResetItemList()
    session.AddItemID(tostring(0), 1)
    local itemlist = session.GetItemIDList()
    local cnt_text = string.format("%s %s", recipe_cls.ClassID, 1)
    if string.find(recipe_name, "EVENT_TOS", 1, true) then
        item.DialogTransaction("EVENT_TOS_WHOLE_SHOP", itemlist, cnt_text)
    else
        item.DialogTransaction("PVP_MINE_SHOP", itemlist, cnt_text)
    end
    local item_name = recipe_cls.TargetItem
    ReserveScript(string.format("Indun_panel_inv_item_use('%s')", item_name), 1.0)
end

function Indun_panel_inv_item_use(item_name)
    local item_cls = GetClass("Item", item_name)
    if item_cls then
        local inv_item = session.GetInvItemByType(item_cls.ClassID)
        if inv_item then
            INV_ICON_USE(inv_item)
        end
    end
end

function Indun_panel_get_entrance_count(indun_type, index)
    local indun_cls = GetClassByType("Indun", indun_type)
    if not indun_cls then
        return 0
    end
    local reset_type = indun_cls.PlayPerResetType
    -- 素の GET_CURRENT_ENTERANCE_COUNT は第 2 引数にダンジョンのクラスを取り、
    -- TicketingType == "Entrance_Ticket" のときだけ CheckCountName をアカウント/etc から読む。
    -- 渡さないと PlayPerResetType 側の経路に落ちて回数が出ない(0 のままになる)。
    -- 素も「Entrance_Ticket のときだけ渡す」書き分けをしているので、そこに合わせる
    -- (induninfo.lua の INDUNINFO_SET_ENTERANCE_COUNT / 詳細一覧の countText と同じ判定)。
    -- ただし素が第 2 引数を実際に使うのは **ClassName が Challenge_ か
    -- SanctuartyResonance_ で始まるときだけ**なので、効くのは
    -- チャレンジ(1004/1006/1007)・分裂(2000/2001/2003)・共鳴の聖所(732)の 7 つ。
    -- それ以外は TicketingType が Entrance_Ticket でも素の分岐に載らず、
    -- PlayPerResetType 側の経路へ落ちる。**これは素の induninfo も同じ**(素も
    -- Entrance_Ticket なら cls を渡すが、同じ理由で使われない)ので、ここで
    -- CheckCountName を自前で読んでゲームの表示とずらすことはしない。
    local ticket_type = TryGetProp(indun_cls, 'TicketingType', 'None')
    local current_count
    if ticket_type == 'Entrance_Ticket' then
        current_count = GET_CURRENT_ENTERANCE_COUNT(reset_type, indun_cls) or 0
    else
        current_count = GET_CURRENT_ENTERANCE_COUNT(reset_type) or 0
    end
    local max_count = GET_INDUN_MAX_ENTERANCE_COUNT(reset_type) or 0
    if index == 1 then
        return string.format("{ol}{#FFFFFF}{s16}(%s)", current_count)
    elseif index == 2 then
        return string.format("{ol}{#FFFFFF}{s16}(%s/%s)", current_count, max_count)
    elseif index == 3 then
        local count = 1
        local class_name = TryGetProp(indun_cls, 'ClassName', 'None')
        if string.find(class_name, 'Challenge_') then
            if ticket_type == 'Entrance_Ticket' then
                local check_name = TryGetProp(indun_cls, 'CheckCountName', 'None')
                local etc = GetMyEtcObject()
                if TryGetProp(etc, check_name, 0) == 1 then
                    count = 0
                end
            end
        end
        return string.format("{ol}{#FFFFFF}{s16}(%s/%s)", count, max_count)
    elseif index == 4 then
        if indun_type == 1001 then
            return current_count
        end
        -- 以前は 1004/1005/2000/2001 を直接並べていたが、Lv560 の追加(1006/1007/2003)と
        -- 1005 の削除で毎回ここを書き換えることになるので、素と同じ「チャレンジ系の
        -- 入場券ダンジョン」という条件で判定する。
        local class_name = TryGetProp(indun_cls, 'ClassName', 'None')
        if string.find(class_name, 'Challenge_') and ticket_type == 'Entrance_Ticket' then
            local unit_per_reset = TryGetProp(indun_cls, 'UnitPerReset', 'None')
            local check_name = TryGetProp(indun_cls, 'CheckCountName', 'None')
            if unit_per_reset ~= 'None' and check_name ~= 'None' then
                if unit_per_reset == 'ACCOUNT' then
                    return TryGetProp(GetMyAccountObj(), check_name, 0) or 0
                elseif unit_per_reset == 'PC' then
                    return TryGetProp(GetMyEtcObject(), check_name, 0) or 0
                end
            end
        end
        return 0
    end
    return 0
end

function Indun_panel_get_recipe_trade_count(recipe_name)
    local recipe_cls = GetClass("ItemTradeShop", recipe_name)
    if not recipe_cls then
        return 0
    end
    if recipe_cls.NeedProperty ~= "None" and recipe_cls.NeedProperty ~= "" then
        return TryGetProp(GetSessionObject(GetMyPCObject(), "ssn_shop"), recipe_cls.NeedProperty, 0)
    end
    if recipe_cls.AccountNeedProperty ~= "None" and recipe_cls.AccountNeedProperty ~= "" then
        return TryGetProp(GetMyAccountObj(), recipe_cls.AccountNeedProperty, 0)
    end
    return 0
end

function Indun_panel_overbuy_count(recipe_name)
    local account_obj = GetMyAccountObj()
    local recipe_cls = GetClass('ItemTradeShop', recipe_name)
    if not recipe_cls then
        return 0
    end
    local max_count = TryGetProp(recipe_cls, 'MaxOverBuyCount', 0)
    local prop_name = TryGetProp(recipe_cls, 'OverBuyProperty', 'None')
    local current_count = TryGetProp(account_obj, prop_name, 0)
    return tonumber(max_count) - tonumber(current_count)
end

function Indun_panel_overbuy_amount(recipe_name)
    local account_obj = GetMyAccountObj()
    local recipe_cls = GetClass('ItemTradeShop', recipe_name)
    if not recipe_cls then
        return 0
    end
    local trade_count = Indun_panel_get_recipe_trade_count(recipe_name)
    if trade_count > 0 then
        return 1000
    end
    local prop_name = TryGetProp(recipe_cls, 'OverBuyProperty', 'None')
    local current_overbuy_count = TryGetProp(account_obj, prop_name, 0)
    return 1050 + (current_overbuy_count * 50)
end

function Indun_panel_get_invitem_count(tbl)
    local count = 0
    local inv_item_list = session.GetInvItemList()
    local guid_list = inv_item_list:GetGuidList()
    local cnt = guid_list:Count()
    for i = 0, cnt - 1 do
        local guid = guid_list:Get(i)
        local inv_item = inv_item_list:GetItemByGuid(guid)
        if inv_item then
            local obj = GetIES(inv_item:GetObject())
            local item_id = obj.ClassID
            for _, class_id in ipairs(tbl) do
                if item_id == class_id then
                    count = count + inv_item.count
                    break
                end
            end
        end
    end
    return count
end

-- チャレンジモードは Lv 帯ごとに「ソロ / PT / 入場券 / 買えるショップ」が別物なので、
-- 段(tier)の表にまとめて 1 か所で回す。Lv 上限が上がるたびに段が増える。
-- 2026-09 の Lv560 追加で実データが次のように変わっている(indun.ies / itemtradeshop.ies):
--   * 1006(ソロ) / 1007(自動マッチング = PT ボタン) / 分裂 2003 が増えた
--   * 540 の PT だった 1005(Challenge_Auto_Hard_Party_540) は **データごと消えた**ので段から外す
--     (残しておくと押しても何も起きないボタンになる)
--   * PVP_MINE_40 の売り物が 540 用から **560 用の入場券**へ差し替わった。
--     540 の段に PVP ボタンを残すと「560 の券を買って 540 へ入ろうとする」ので、
--     PVP ショップのボタンは 560 の段だけに置く
local CHALLENGE_CONFIG = {
    LOW = {
        expiring = {10820019, 11030080, 641954, 641955, 641969},
        non_expiring = {10000073, 10820028, 490363, 641953, 641963, 641987}
    },
    HIGH = {
        expiring = {11201299, 11201300, 10820052},
        non_expiring = {11201298, 11201297}
    },
    TOP = {
        -- ChallengeModeReset_560 系。並びは 540 と同じ「1日 / 7日 / TOS ショップ」→「取引不可 / 通常」
        expiring = {11202130, 11202131, 10820054},
        non_expiring = {11202129, 11202128}
    }
}
-- 前方宣言してある(ファイル上部)。ここは代入なので local を付けないこと
CHALLENGE_TIERS = {{
    label = "520",
    solo = 1001,
    config = "LOW",
    tos_recipe = "EVENT_TOS_WHOLE_SHOP_315",
    count_index = 2
}, {
    label = "540",
    solo = 1004,
    config = "HIGH",
    tos_recipe = "EVENT_TOS_WHOLE_SHOP_320",
    count_index = 3
}, {
    label = "560",
    solo = 1006,
    pt = 1007,
    config = "TOP",
    tos_recipe = "EVENT_TOS_WHOLE_SHOP_322",
    pvp_recipe = "PVP_MINE_40",
    count_index = 3
}}
local CHALLENGE_TIER_BY_INDUN = {}
for _, tier in ipairs(CHALLENGE_TIERS) do
    CHALLENGE_TIER_BY_INDUN[tier.solo] = tier
    if tier.pt then
        CHALLENGE_TIER_BY_INDUN[tier.pt] = tier
    end
end
-- 段(tier)ごとに「Lv ボタン / PT ボタン / 入場回数 / USE ボタン」を左から並べる。
-- 段の顔ぶれは CHALLENGE_TIERS 側にあるので、Lv 上限が上がったら表へ 1 段足すだけでよい。
-- 戻り値は使った横幅。呼び元が行の右端を覚えてパネルの幅を決める。
-- チャレンジの USE ボタンのツールチップを組み立てる。
--   with_click_hint … PT ボタンがある段。左クリック=PT / 右クリック=ソロ の案内を足す
--   coin_img        … 「購入」の行に出す通貨の絵
-- ツールチップの「優先順位」は **設定の使用順をそのまま並べる**。
-- 以前は 520 かどうかで 2 通りを書き分けていたが、順序が設定で変えられるように
-- なったので、文面を固定していると実際の動きと食い違う。この食い違いは
-- **実機で券を 1 枚使うまで見えない**ので、書き分けではなく設定から組み立てる。
function Indun_panel_ticket_tooltip(with_click_hint, coin_img)
    local is_jp = g.lang == "Japanese"
    local parts = {"{ol}"}
    if with_click_hint then
        table.insert(parts, is_jp and "左クリック: PT入場{nl}右クリック: ソロ入場{nl}" or
            "Left Click: PT Entry{nl}Right Click: Solo Entry{nl}")
    end
    table.insert(parts, is_jp and "優先順位{nl}" or "Priority{nl}")
    local lines = {}
    for i, kind in ipairs(Indun_panel_ticket_order("challenge")) do
        local label
        if kind == "buy" then
            local sz = Indun_panel_s(20)
            label = is_jp and string.format("{img %s %d %d}チケット(買って使います)", coin_img, sz, sz) or
                        string.format("{img %s %d %d}tickets(buy and use)", coin_img, sz, sz)
        else
            local def = Indun_panel_ticket_kind_def(kind)
            label = def and (is_jp and def.jp or def.en) or kind
        end
        table.insert(lines, string.format("%d.%s", i, label))
    end
    table.insert(parts, table.concat(lines, "{nl}"))
    return table.concat(parts)
end

local function challenge_shop_button(indun_panel, name, x, y, recipe, indun_type, mode, icon, icon_text, tooltip)
    local btn = indun_panel:CreateOrGetControl('button', name, x, y, Indun_panel_s(100), Indun_panel_s(30))
    AUTO_CAST(btn)
    btn:SetText(string.format("{ol}{#EE7800}USEor%s{img %s %d %d}{#FFFFFF}%s", Indun_panel_f(16), icon,
        Indun_panel_s(15), Indun_panel_s(15), Indun_panel_get_recipe_trade_count(recipe) or 0))
    btn:SetTextTooltip(icon_text .. tooltip)
    btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_challenge_item_use")
    btn:SetEventScriptArgString(ui.LBUTTONUP, mode)
    btn:SetEventScriptArgNumber(ui.LBUTTONUP, indun_type)
    return btn
end

function Indun_panel_challenge_frame(indun_panel, key, sub_key, indun_type, y, x)
    local offset = 0
    for _, tier in ipairs(CHALLENGE_TIERS) do
        -- 設定で外した段は描かない(パネルは frame_init が RemoveAllChild してから
        -- 組み直すので、描かなければコントロールごと残らない)
        if Indun_panel_tier_enabled("challenge", tier.label) then
            local suffix = "_ch" .. tier.label
            local config = CHALLENGE_CONFIG[tier.config]
            -- 所持数はその段の入場券だけを数える(段をまたいで合算すると別 Lv の券まで数えてしまう)
            local count = Indun_panel_get_invitem_count(config.expiring) + Indun_panel_get_invitem_count(config.non_expiring)
            local icon_text = ""
            local item_cls = GetClassByType('Item', config.expiring[1])
            if item_cls then
                local fmt = g.lang == "Japanese" and "{ol}{img %s %d %d } %d枚持っています{nl} {nl}" or
                                "{ol}{img %s %d %d } Quantity in Inventory: %d{nl} {nl}"
                icon_text = string.format(fmt, item_cls.Icon, Indun_panel_s(25), Indun_panel_s(25), count)
            end
            local btn = indun_panel:CreateOrGetControl('button', "btn" .. suffix, x + offset, y,
                Indun_panel_s(50), Indun_panel_s(30))
            AUTO_CAST(btn)
            btn:SetText("{ol}" .. tier.label)
            btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_enter_challenge")
            btn:SetEventScriptArgString(ui.LBUTTONUP, "1")
            btn:SetEventScriptArgNumber(ui.LBUTTONUP, tier.solo)
            offset = offset + Indun_panel_s(50)
            -- PT(自動マッチング)がある段だけボタンを出す。無い段で出すと押しても何も起きない
            local pt_indun_type = tier.pt or tier.solo
            if tier.pt then
                local pt_btn = indun_panel:CreateOrGetControl('button', "pt" .. suffix, x + offset, y,
                    Indun_panel_s(50), Indun_panel_s(30))
                AUTO_CAST(pt_btn)
                pt_btn:SetText("{ol}{#FFD900}PT")
                pt_btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_enter_challenge")
                pt_btn:SetEventScriptArgString(ui.LBUTTONUP, "2")
                pt_btn:SetEventScriptArgNumber(ui.LBUTTONUP, tier.pt)
                offset = offset + Indun_panel_s(50)
            end
            local txt = indun_panel:CreateOrGetControl("richtext", "txt" .. suffix, x + offset, y + Indun_panel_s(5),
                Indun_panel_s(40), Indun_panel_s(30))
            txt:SetText(Indun_panel_get_entrance_count(tier.solo, tier.count_index))
            offset = offset + Indun_panel_s(40)
            -- クリックの案内は PT ボタンがある段だけ(tier.pt)。
            -- 消費の優先順位は設定から組み立てるので、段による書き分けは無くなった。
            local tooltip_tos = Indun_panel_ticket_tooltip(tier.pt ~= nil, "icon_item_Tos_Event_Coin")
            local tos_btn = challenge_shop_button(indun_panel, "buyuse_tos" .. suffix, x + offset, y, tier.tos_recipe,
                pt_indun_type, "tos", "icon_item_Tos_Event_Coin", icon_text, tooltip_tos)
            if tier.pt then
                tos_btn:SetEventScript(ui.RBUTTONUP, "Indun_panel_challenge_item_use")
                tos_btn:SetEventScriptArgString(ui.RBUTTONUP, "tos")
                tos_btn:SetEventScriptArgNumber(ui.RBUTTONUP, tier.solo)
            end
            offset = offset + Indun_panel_s(100)
            if tier.pvp_recipe then
                local tooltip_pvp = Indun_panel_ticket_tooltip(tier.pt ~= nil, "pvpmine_shop_btn_total")
                local pvp_btn = challenge_shop_button(indun_panel, "buyuse_pvp" .. suffix, x + offset, y, tier.pvp_recipe,
                    pt_indun_type, "pvp", "pvpmine_shop_btn_total", icon_text, tooltip_pvp)
                pvp_btn:SetText(string.format("{ol}{#FFFFFF}USEor%s{img %s %d %d}{#FFFFFF}%s", Indun_panel_f(16),
                    "pvpmine_shop_btn_total", Indun_panel_s(18), Indun_panel_s(18),
                    Indun_panel_get_recipe_trade_count(tier.pvp_recipe) or 0))
                if tier.pt then
                    pvp_btn:SetEventScript(ui.RBUTTONUP, "Indun_panel_challenge_item_use")
                    pvp_btn:SetEventScriptArgString(ui.RBUTTONUP, "pvp")
                    pvp_btn:SetEventScriptArgNumber(ui.RBUTTONUP, tier.solo)
                end
                offset = offset + Indun_panel_s(100)
            end
            offset = offset + Indun_panel_s(5)
        end
    end
    Indun_panel_note_row_width(offset)
end

function Indun_panel_challenge_item_use(indun_panel, ctrl, mode, indun_type)
    local tier = CHALLENGE_TIER_BY_INDUN[indun_type]
    if not tier then
        g.vlog("indun_panel: チャレンジの段が見つからない indun_type=%s", tostring(indun_type))
        return
    end
    local entrance_count = Indun_panel_get_entrance_count(indun_type, 4)
    -- 520 は入場券ダンジョンではないので「残り回数」がそのまま返る(行けるとき > 0)。
    -- 540 以降は入場券の消費済みフラグなので、行けるときが 1 で、0 のときに券を使う。
    local need_ticket
    if indun_type == 1001 then
        need_ticket = entrance_count > 0
    else
        need_ticket = entrance_count == 0
    end
    if need_ticket then
        Indun_panel_process_ticket(indun_type, mode, CHALLENGE_CONFIG[tier.config])
    end
end

-- その段で「買って使う」ショップの取引名を返す。無ければ空文字。
function Indun_panel_challenge_recipe(indun_type, mode)
    local tier = CHALLENGE_TIER_BY_INDUN[indun_type]
    if not tier then
        return ""
    end
    if mode == "pvp" then
        return tier.pvp_recipe or ""
    end
    return tier.tos_recipe or ""
end

function Indun_panel_process_ticket(indun_type, mode, config)
    local tier = CHALLENGE_TIER_BY_INDUN[indun_type]
    -- PT(自動マッチング)側の indun_type で押されたときだけ ReqMoveToIndun の第 1 引数が 2 になる。
    -- 以前は 1005 決め打ちだったが、1005 は削除され 1007 になったので段の表から引く。
    local enter_mode = (tier and tier.pt == indun_type) and 2 or 1
    local recipe_name = Indun_panel_challenge_recipe(indun_type, mode)
    -- 券の候補は「期限付きに書いたもの → 期限なしに書いたもの」の並びで渡す。
    -- **どちらの分類になるかは実物から決める**ので、この 2 つのリストは
    -- 「同じ分類の中でどれを先に使うか」を決めるだけの意味になった。
    local ticket_ids = {}
    for _, list in ipairs({config.expiring, config.non_expiring}) do
        for _, class_id in ipairs(list or {}) do
            table.insert(ticket_ids, class_id)
        end
    end
    local used = Indun_panel_consume_ticket("challenge", ticket_ids, {
        on_use = function()
            Indun_panel_enter_reserve(enter_mode, indun_type)
        end,
        on_buy = function()
            if recipe_name ~= "" and Indun_panel_get_recipe_trade_count(recipe_name) >= 1 then
                Indun_panel_item_buy_use(recipe_name)
                Indun_panel_enter_reserve(enter_mode, indun_type)
                return true
            end
            return false
        end,
        -- **押したボタンのショップだけで判断しないこと。** Lv560 の段は TOS と
        -- 採掘場の 2 つを持つので、片方の購入枠を使い切っただけでは「もう買えない」
        -- ことにはならない。ここを見ないと、もう片方に枠が残っていても手持ちの
        -- 期限なし券を溶かし、さらに追加購入枠(OverBuy)の経路にも辿り着けなくなる。
        hold_permanent = function()
            -- 520 は入場券ダンジョンではなく、元から温存しない作り。
            if indun_type == 1001 then
                return false
            end
            local tos_recipe = Indun_panel_challenge_recipe(indun_type, "tos")
            local pvp_recipe = Indun_panel_challenge_recipe(indun_type, "pvp")
            local tos_left = tos_recipe ~= "" and Indun_panel_get_recipe_trade_count(tos_recipe) or 0
            local pvp_left = pvp_recipe ~= "" and Indun_panel_get_recipe_trade_count(pvp_recipe) or 0
            return tos_left >= 1 or pvp_left >= 1
        end
    })
    if used then
        return
    end
    -- PVP ショップだけは上限を超えて買える枠(OverBuy)がある。**これは使用順の外に置く。**
    -- 追加で買える枠なので、持っている券を使い切ってから手を付けるのが今までの動きで、
    -- 設定の「購入」(通常の購入枠)とは意味が違う。
    if mode == "pvp" and recipe_name ~= "" then
        if Indun_panel_overbuy_count(recipe_name) > 0 then
            Indun_panel_item_buy_use(recipe_name)
            Indun_panel_enter_reserve(enter_mode, indun_type)
            g.vlog("indun_panel: 入場券を追加購入枠(OverBuy)で買った recipe=%s", recipe_name)
        end
    end
end

function Indun_panel_enter_reserve(index, indun_type)
    AnsGiveUpPrevPlayingIndun(1)
    ReserveScript(string.format("Indun_panel_enter_challenge(nil,nil,'%d', %d)", index, indun_type), 1.5)
end

function Indun_panel_enter_challenge(indun_panel, ctrl, index, indun_type)
    index = tonumber(index)
    if not indun_type then
        return
    end
    local pcparty = session.party.GetPartyInfo()
    if not pcparty then
        CREATE_PARTY_BTN()
    end
    ReqChallengeAutoUIOpen(indun_type)
    ReserveScript(string.format("ReqMoveToIndun(%d,%d)", index, 0), 0.3)
end

-- 分裂特異点もチャレンジと同じく Lv 帯ごとに入場券とショップが別物なので段の表にする。
-- 2026-09 の Lv560 追加で 2003 が増え、PVP_MINE_41 / 42 の売り物が 540 用から
-- **560 用の入場券**へ差し替わった。540 の段に PVP ボタンを残すと
-- 「560 の券を買って 540 へ入ろうとする」ので、PVP ショップは 560 の段だけに置く。
local SINGULARITY_CONFIG = {
    [2000] = { -- 520
        expiring = {10820018, 11030067},
        non_expiring = {10000470, 11030021, 11030017}
    },
    [2001] = { -- 540
        expiring = {11201303, 11201304, 10820051},
        non_expiring = {11201302, 11201301}
    },
    [2003] = { -- 560 (ChallengeExpertModeCountUp_560 系。並びは 540 と同じ)
        expiring = {11202140, 11202141, 10820053},
        non_expiring = {11202139, 11202138}
    }
}
-- 前方宣言してある(ファイル上部)。ここは代入なので local を付けないこと
SINGULARITY_TIERS = {{
    label = "520",
    indun = 2000,
    tos_recipe = "EVENT_TOS_WHOLE_SHOP_314"
}, {
    label = "540",
    indun = 2001,
    tos_recipe = "EVENT_TOS_WHOLE_SHOP_319"
}, {
    label = "560",
    indun = 2003,
    tos_recipe = "EVENT_TOS_WHOLE_SHOP_321",
    pvp_recipes = {"PVP_MINE_41", "PVP_MINE_42"}
}}
local SINGULARITY_TIER_BY_INDUN = {}
for _, tier in ipairs(SINGULARITY_TIERS) do
    SINGULARITY_TIER_BY_INDUN[tier.indun] = tier
end

-- 他のダンジョンに入りっぱなしの状態で押されたとき、確認を出さずに
-- 「前のを放棄して入り直す」対象かどうか。自動マッチングで入るもの
-- (チャレンジの PT / 分裂の全段)だけが対象で、ソロ入場は確認を出す。
-- Lv 帯が増えても段の表を直せば追従する。
function Indun_panel_is_auto_rejoin_indun(indun_type)
    local tier = CHALLENGE_TIER_BY_INDUN[indun_type]
    if tier and tier.pt == indun_type then
        return true
    end
    return SINGULARITY_TIER_BY_INDUN[indun_type] ~= nil
end

function Indun_panel_singularity_frame(indun_panel, key, sub_key, indun_type, y, x)
    local offset = 0
    for _, tier in ipairs(SINGULARITY_TIERS) do
        -- 設定で外した段は描かない(理由は Indun_panel_challenge_frame と同じ)
        if Indun_panel_tier_enabled("singularity", tier.label) then
            local suffix = "_sg" .. tier.label
            local config = SINGULARITY_CONFIG[tier.indun]
            local count = Indun_panel_get_invitem_count(config.expiring) + Indun_panel_get_invitem_count(config.non_expiring)
            local icon_text = ""
            local item_cls = GetClassByType('Item', config.expiring[1])
            if item_cls then
                local fmt = g.lang == "Japanese" and "{ol}{img %s %d %d } %d枚持っています{nl} {nl}" or
                                "{ol}{img %s %d %d } Quantity in Inventory: %d{nl} {nl}"
                icon_text = string.format(fmt, item_cls.Icon, Indun_panel_s(25), Indun_panel_s(25), count)
            end
            local btn = indun_panel:CreateOrGetControl('button', "btn" .. suffix, x + offset, y,
                Indun_panel_s(50), Indun_panel_s(30))
            AUTO_CAST(btn)
            btn:SetText("{ol}" .. tier.label)
            btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_enter_singularity")
            btn:SetEventScriptArgNumber(ui.LBUTTONUP, tier.indun)
            offset = offset + Indun_panel_s(55)
            local count_txt = indun_panel:CreateOrGetControl("richtext", "count" .. suffix, x + offset,
                y + Indun_panel_s(5), Indun_panel_s(30), Indun_panel_s(30))
            count_txt:SetText("{ol}(" .. Indun_panel_get_entrance_count(tier.indun, 4) .. ")")
            offset = offset + Indun_panel_s(30)
            -- **手書きの固定文にしないこと。** 消費の順序は設定で変わるので、
            -- 書き固めると説明と動きが食い違う(食い違いは実機で券を 1 枚使うまで見えない)。
            -- チャレンジと同じ組み立て(グループも同じ "challenge")。
            local tooltip = Indun_panel_ticket_tooltip(false, "icon_item_Tos_Event_Coin")
            local tos_btn = indun_panel:CreateOrGetControl('button', 'ticket_tos' .. suffix, x + offset, y,
                Indun_panel_s(100), Indun_panel_s(30))
            AUTO_CAST(tos_btn)
            tos_btn:SetText(string.format("{ol}{#EE7800}USEor%s{img %s %d %d}{#FFFFFF}%s", Indun_panel_f(16),
                "icon_item_Tos_Event_Coin", Indun_panel_s(15), Indun_panel_s(15),
                Indun_panel_get_recipe_trade_count(tier.tos_recipe) or 0))
            tos_btn:SetTextTooltip(icon_text .. tooltip)
            tos_btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_item_use_sin")
            tos_btn:SetEventScriptArgString(ui.LBUTTONUP, "tos")
            tos_btn:SetEventScriptArgNumber(ui.LBUTTONUP, tier.indun)
            offset = offset + Indun_panel_s(105)
            if tier.pvp_recipes then
                local pvp_btn = indun_panel:CreateOrGetControl('button', 'ticket_pvp' .. suffix, x + offset, y,
                    Indun_panel_s(140), Indun_panel_s(30))
                AUTO_CAST(pvp_btn)
                local tooltip_pvp = Indun_panel_ticket_tooltip(false, "pvpmine_shop_btn_total")
                pvp_btn:SetText(string.format("{ol}{#FFFFFF}%sUSEor{img %s %d %d}d:%s w:%s", Indun_panel_f(16),
                    "pvpmine_shop_btn_total", Indun_panel_s(18), Indun_panel_s(18),
                    Indun_panel_get_recipe_trade_count(tier.pvp_recipes[1]) or 0,
                    Indun_panel_get_recipe_trade_count(tier.pvp_recipes[2]) or 0))
                pvp_btn:SetTextTooltip(icon_text .. tooltip_pvp)
                pvp_btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_item_use_sin")
                pvp_btn:SetEventScriptArgString(ui.LBUTTONUP, "pvp")
                pvp_btn:SetEventScriptArgNumber(ui.LBUTTONUP, tier.indun)
                offset = offset + Indun_panel_s(145)
            end
        end
    end
    local singularity_check = indun_panel:CreateOrGetControl("checkbox", "singularity_check", x + offset, y,
        Indun_panel_s(25), Indun_panel_s(25))
    AUTO_CAST(singularity_check)
    singularity_check:SetEventScript(ui.LBUTTONUP, "Indun_panel_ischecked")
    singularity_check:SetTextTooltip(g.lang == "Japanese" and
                                         "{ol}チェックをすると自動マッチングボタンを押しません" or
                                         "{ol}If checked, the automatic matching button will not be pressed")
    singularity_check:SetCheck(g.indun_panel_settings.etc.singularity_check)
    Indun_panel_note_row_width(offset + Indun_panel_s(30))
end

function Indun_panel_item_use_sin(frame, ctrl, mode, indun_type)
    local ent_count = Indun_panel_get_entrance_count(indun_type, 4)
    if tonumber(ent_count) > 0 then
        return
    end
    local config = SINGULARITY_CONFIG[indun_type]
    if not config then
        return
    end
    -- 取引名は段の表から引く。以前は 2000 かどうかで 2 つを出し分けていたが、
    -- 段が 3 つになったので分岐では足りない。
    local tier = SINGULARITY_TIER_BY_INDUN[indun_type]
    if not tier then
        g.vlog("indun_panel: 分裂の段が見つからない indun_type=%s", tostring(indun_type))
        return
    end
    local recipes = {}
    if mode == "pvp" and tier.pvp_recipes then
        recipes = tier.pvp_recipes
    elseif tier.tos_recipe then
        recipes = {tier.tos_recipe}
    end
    -- チャレンジと同じ扱い(設定のグループも同じ "challenge")。
    local ticket_ids = {}
    for _, list in ipairs({config.expiring, config.non_expiring}) do
        for _, class_id in ipairs(list or {}) do
            table.insert(ticket_ids, class_id)
        end
    end
    -- **温存の判定(hold_permanent)は置かない。** 分裂特異点は元から
    -- 「買えなければ手持ちを使う」だけの作りで、ショップの在庫を見ていない。
    Indun_panel_consume_ticket("challenge", ticket_ids, {
        on_use = function()
            ReserveScript(string.format("Indun_panel_enter_singularity(nil,nil,'', %d)", indun_type), 0.5)
        end,
        on_buy = function()
            for _, recipe in ipairs(recipes) do
                if Indun_panel_get_recipe_trade_count(recipe) >= 1 then
                    Indun_panel_item_buy_use(recipe)
                    ReserveScript(string.format("Indun_panel_enter_singularity(nil,nil,'', %d)", indun_type), 1.5)
                    return true
                end
            end
            return false
        end,
        before_use = function()
            -- **券を使う前に呼ぶこと。** 前のダンジョンを諦める合図なので、
            -- 券を使った後に回すと順序が入れ替わる(元の実装はここで呼んでいた)。
            AnsGiveUpPrevPlayingIndun(1)
        end
    })
end

function Indun_panel_enter_singularity(frame, ctrl, str, indun_type)
    ReqChallengeAutoUIOpen(indun_type)
    local indun_cls = GetClassByType('Indun', indun_type)
    if indun_cls then
        local indun_min_rank = TryGetProp(indun_cls, 'PCRank')
        local totaljobcount = session.GetPcTotalJobGrade()
        if indun_min_rank then
            if indun_min_rank > totaljobcount and indun_min_rank ~= totaljobcount then
                ui.SysMsg(ScpArgMsg('IndunEnterNeedPCRank', 'NEED_RANK', indun_min_rank))
                return
            end
        end
        if g.indun_panel_settings.etc.singularity_check == 0 then
            ReserveScript(string.format("ReqMoveToIndun(%d,%d)", 2, 0), 0.3)
        end
    end
end

local raid_tbl = {
    [733] = {11210074, 11210073, 11210072}, -- 偽りの輝翼 (7日 / 取引不可 / 通常)
    [736] = {11210078, 11210077, 11210076}, -- 堕落した審判の翼
    [729] = {11210063, 11210062, 11210061},
    [725] = {11210057, 11210056, 11210055},
    [722] = {11210053, 11210052, 11210051},
    [716] = {11210044, 10820040, 11210043, 11210042},
    [707] = {11210024, 11210023, 11210022},
    [710] = {11210028, 11210027, 11210026},
    [695] = {11200356, 11200355, 11200354},
    [688] = {11200290, 10820036, 11200289, 11200288},
    [685] = {11200281, 10820035, 11200280, 11200279},
    [679] = {108020026, 11200222, 11200221, 11200220}
}
local buff_ids = {
    [733] = 80049, -- 偽りの輝翼
    [736] = 80051, -- 堕落した審判の翼
    [729] = 80047, -- ズメイ
    [725] = 80045, -- ベリオラ
    [722] = 80043, -- ライマラ
    [716] = 80039, -- レダニア
    [707] = 80035, -- ネリンガ
    [710] = 80037, -- ゴーレム
    [673] = 80016, -- スプレッダー
    [676] = 80017, -- ファロウス
    [679] = 80015, -- ロゼ
    [685] = 80030, -- 蝶々
    [688] = 80031, -- スロガ
    [695] = 80032 -- メレジ
}

function Indun_panel_create_frame_onsweep(indun_panel, key, sub_key, sub_value, y, x)
    if raid_tbl[sub_value] then
        local use_btn = indun_panel:CreateOrGetControl('button', key .. "use", x + Indun_panel_s(470), y,
            Indun_panel_s(80), Indun_panel_s(30))
        AUTO_CAST(use_btn)
        use_btn:SetText("{ol}{#EE7800}USE")
        local count = Indun_panel_get_invitem_count(raid_tbl[sub_value])
        local item_cls = GetClassByType('Item', raid_tbl[sub_value][2])
        if item_cls then
            local fmt = g.lang == "Japanese" and "{ol}{img %s %d %d } %d枚持っています" or
                            "{ol}{img %s %d %d } Quantity in Inventory: %d"
            use_btn:SetTextTooltip(string.format(fmt, item_cls.Icon, Indun_panel_s(25), Indun_panel_s(25), count))
        end
        use_btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_raid_itemuse")
        use_btn:SetEventScriptArgNumber(ui.LBUTTONUP, sub_value)
    end
    local btn_solo = indun_panel:CreateOrGetControl('button', key .. "solo", x, y, Indun_panel_s(80), Indun_panel_s(30))
    local btn_auto = indun_panel:CreateOrGetControl('button', key .. "auto", x + Indun_panel_s(85), y,
        Indun_panel_s(80), Indun_panel_s(30))
    local btn_sweep = indun_panel:CreateOrGetControl('button', key .. "sweep", x + Indun_panel_s(350), y,
        Indun_panel_s(80), Indun_panel_s(30))
    local txt_count = indun_panel:CreateOrGetControl("richtext", key .. "count", x + Indun_panel_s(170),
        y + Indun_panel_s(5), Indun_panel_s(50), Indun_panel_s(30))
    local txt_sweep_count = indun_panel:CreateOrGetControl("richtext", key .. "sweepcount", x + Indun_panel_s(435),
        y + Indun_panel_s(5), Indun_panel_s(50), Indun_panel_s(30))
    btn_solo:SetText("{ol}SOLO")
    btn_auto:SetText("{ol}{#FFD900}AUTO")
    btn_sweep:SetText("{ol}{#00FF00}ACLEAR")
    if sub_key == "s" then -- Solo
        txt_count:SetText(Indun_panel_get_entrance_count(sub_value, 2))
        btn_solo:SetEventScript(ui.LBUTTONUP, "Indun_panel_enter_solo")
        btn_solo:SetEventScriptArgNumber(ui.LBUTTONUP, sub_value)
    elseif sub_key == "a" then -- Auto
        btn_auto:SetEventScript(ui.LBUTTONUP, "Indun_panel_enter_auto")
        btn_auto:SetEventScriptArgNumber(ui.LBUTTONUP, sub_value)
        btn_sweep:SetEventScript(ui.LBUTTONUP, "Indun_panel_raid_itemuse")
        btn_sweep:SetEventScriptArgNumber(ui.LBUTTONUP, sub_value)
        btn_sweep:SetEventScriptArgString(ui.LBUTTONUP, "SWEEP")
    elseif sub_key == "h" then -- Hard
        -- HARD ボタンと回数は h を持つレイドだけに作る。以前は無条件に作っていたので、
        -- Hard がまだ実装されていないレイド(偽りの輝翼 / 堕落した審判の翼)を足すと
        -- 押しても何も起きない HARD ボタンが並んでしまう
        local ent_count = Indun_panel_get_entrance_count(sub_value, 2)
        if ent_count then
            local btn_hard = indun_panel:CreateOrGetControl('button', key .. "hard", x + Indun_panel_s(215), y,
                Indun_panel_s(80), Indun_panel_s(30))
            AUTO_CAST(btn_hard)
            local txt_hard_count = indun_panel:CreateOrGetControl("richtext", key .. "counthard",
                x + Indun_panel_s(300), y + Indun_panel_s(5), Indun_panel_s(50), Indun_panel_s(30))
            btn_hard:SetText("{ol}{#FF0000}HARD")
            txt_hard_count:SetText(ent_count)
            btn_hard:SetEventScript(ui.LBUTTONDOWN, "Indun_panel_enter_hard")
            btn_hard:SetEventScriptArgNumber(ui.LBUTTONDOWN, sub_value)
            btn_hard:SetEventScriptArgString(ui.LBUTTONDOWN, "false")
        end
    elseif sub_key == "ac" then -- Auto Clear (Sweep) Count
        local count_str = Indun_panel_sweep_count(sub_value)
        txt_sweep_count:SetText(string.format("{ol}{#FFFFFF}%s(%s)", Indun_panel_f(16), count_str))
    end
end

function Indun_panel_raid_itemuse(indun_panel, ctrl, str, indun_type)
    local target_items = raid_tbl[indun_type]
    local buff_id = buff_ids[indun_type]
    if not buff_id then
        return
    end
    local indun_cls = GetClassByType("Indun", indun_type)
    local enter_count = 0
    if indun_cls then
        enter_count = GET_CURRENT_ENTERANCE_COUNT(indun_cls.PlayPerResetType) or 0
    end
    local limit_count = 2
    if indun_type == 673 or indun_type == 676 then
        limit_count = 4
    end
    local is_limit_reached = (enter_count >= limit_count)
    local sweep_count = Indun_panel_sweep_count(buff_id)
    if sweep_count == 0 and str == "SWEEP" then
        ui.SysMsg(g.lang == "Japanese" and "掃討バフがありません" or "There is no auto clear buff")
        return
    end
    -- レイドの券はショップで売っていないので、「購入」の段は無い(グループ "raid")。
    -- 以前はリストに書いた順で最初に見つかったものを使っていた。並びは
    -- 「7日 / 取引不可 / 通常」で書かれていたので既定の順序はこれまでと同じになる。
    if sweep_count > 0 then
        if not is_limit_reached then
            ReqUseRaidAutoSweep(indun_type)
        elseif not Indun_panel_consume_ticket("raid", target_items, {
            on_use = function()
                ReserveScript(string.format("ReqUseRaidAutoSweep(%d)", indun_type), 0.5)
            end
        }) then
            ui.SysMsg(g.lang == "Japanese" and "入場回数不足（チケットなし）" or
                          "Not enough entry count (No tickets).")
        end
    elseif not Indun_panel_consume_ticket("raid", target_items) then
        if string.find(ctrl:GetName(), "use") then
            ui.SysMsg(g.lang == "Japanese" and "(自動マッチング/1人)入場券を持っていません" or
                          "There are no ticket items in inventory")
        else
            ui.SysMsg(g.lang == "Japanese" and "掃討バフがありません" or "There is no auto clear buff")
        end
    end
end

function Indun_panel_sweep_count(buff_id)
    local my_handle = session.GetMyHandle()
    local buff = info.GetBuff(my_handle, buff_id)
    if buff then
        return buff.over or 0
    end
    return 0
end

function Indun_panel_enter_solo(indun_panel, ctrl, str, indun_type)
    local pcparty = session.party.GetPartyInfo()
    if not pcparty then
        CREATE_PARTY_BTN()
    end
    ReqRaidAutoUIOpen(indun_type)
    -- open_only の付いたダンジョン(共鳴の聖所)は**窓を開くところで止める**。
    -- 押す前に中身を選びたいものがあるため、入場は利用者に任せる。
    -- 表に無い indun_type(config が nil)は今までどおり続けて入場を押す。
    local config = DUNGEON_TICKET_CONFIG[indun_type]
    if config and config.open_only then
        g.vlog("indun_panel: indun %d は窓を開くところで止める(入場は押さない)", indun_type)
        return
    end
    ReserveScript(string.format("ReqMoveToIndun(%d,%d)", 1, 0), 0.3)
end

function Indun_panel_enter_auto(indun_panel, ctrl, str, indun_type)
    ReqRaidAutoUIOpen(indun_type)
    local indun_cls = GetClassByType('Indun', indun_type)
    if indun_cls then
        local indun_min_rank = TryGetProp(indun_cls, 'PCRank')
        local totaljobcount = session.GetPcTotalJobGrade()
        if indun_min_rank ~= nil then
            if indun_min_rank > totaljobcount and indun_min_rank ~= totaljobcount then
                ui.SysMsg(ScpArgMsg('IndunEnterNeedPCRank', 'NEED_RANK', indun_min_rank))
                return
            end
        end
        ReserveScript(string.format("ReqMoveToIndun(%d,%d)", 2, 0), 0.3)
    end
end

local function Indun_panel_induninfo_set_buttons(indun_type, ctrl)
    local indun_cls = GetClassByType('Indun', indun_type)
    if indun_cls then
        local dungeon_type = TryGetProp(indun_cls, "DungeonType", "None")
        local btn_info_cls = GetClassByStrProp("IndunInfoButton", "DungeonType", dungeon_type)
        if dungeon_type == "Raid" then
            btn_info_cls = INDUNINFO_SET_BUTTONS_FIND_CLASS(indun_cls)
        end
        local red_button_scp = TryGetProp(btn_info_cls, "RedButtonScp")
        ctrl:SetUserValue('MOVE_INDUN_CLASSID', indun_cls.ClassID)
        ctrl:SetEventScript(ui.LBUTTONUP, red_button_scp)
    end
end

function Indun_panel_enter_hard(indun_panel, ctrl, str, indun_type)
    local indun_cls = GetClassByType("Indun", indun_type)
    if str == "false" then
        Indun_panel_induninfo_set_buttons(indun_type, ctrl)
        str = "true"
        if indun_type then
            ReserveScript(string.format("Indun_panel_enter_hard(nil,nil,'%s',%d)", str, indun_type), 0.5)
            return
        end
    else
        SHOW_INDUNENTER_DIALOG(indun_type)
        return
    end
end

function Indun_panel_create_frame(indun_panel, key, sub_key, sub_value, y, x)
    local btn_solo = indun_panel:CreateOrGetControl('button', key .. "solo", x, y, Indun_panel_s(80), Indun_panel_s(30))
    local btn_auto = indun_panel:CreateOrGetControl('button', key .. "auto", x + Indun_panel_s(85), y,
        Indun_panel_s(80), Indun_panel_s(30))
    local btn_hard = indun_panel:CreateOrGetControl('button', key .. "hard", x + Indun_panel_s(215), y,
        Indun_panel_s(80), Indun_panel_s(30))
    local txt_count = indun_panel:CreateOrGetControl("richtext", key .. "count", x + Indun_panel_s(170),
        y + Indun_panel_s(5), Indun_panel_s(50), Indun_panel_s(30))
    local txt_hard_count = indun_panel:CreateOrGetControl("richtext", key .. "counthard", x + Indun_panel_s(300),
        y + Indun_panel_s(5), Indun_panel_s(50), Indun_panel_s(30))
    btn_solo:SetText("{ol}SOLO")
    btn_auto:SetText(key == "memory" and "{ol}{#FFD900}NORMAL" or "{ol}{#FFD900}AUTO")
    btn_hard:SetText("{ol}{#FF0000}HARD")
    if sub_key == "s" then
        local count_idx = (key == "memory") and 1 or 2
        txt_count:SetText(Indun_panel_get_entrance_count(sub_value, count_idx))
        btn_solo:SetEventScript(ui.LBUTTONUP, "Indun_panel_enter_solo")
        btn_solo:SetEventScriptArgNumber(ui.LBUTTONUP, sub_value)
    elseif sub_key == "a" then
        btn_auto:SetEventScript(ui.LBUTTONUP, "Indun_panel_enter_auto")
        btn_auto:SetEventScriptArgNumber(ui.LBUTTONUP, sub_value)
    elseif sub_key == "h" then
        local count_idx
        if key == "memory" then
            count_idx = 1
        elseif key == "giltine" then
            count_idx = 1
        else
            count_idx = 2
        end
        txt_hard_count:SetText(Indun_panel_get_entrance_count(sub_value, count_idx))
        btn_hard:SetEventScript(ui.LBUTTONDOWN, "Indun_panel_enter_hard")
        btn_hard:SetEventScriptArgNumber(ui.LBUTTONDOWN, sub_value)
        btn_hard:SetEventScriptArgString(ui.LBUTTONDOWN, "false")
    end
end

local TELHARSHA_CONFIG = {
    recipe = "EVENT_TOS_WHOLE_SHOP_306",
    -- 入場券。**ツールチップの所持数もここから引くこと**(2 か所に書くと必ずずれる)。
    --   10820009 Event_SoloRaidCntReset_limit_renew … 期限付き
    --   11035056 SoloRaidCntReset_TP                … 通常
    --
    -- 以前は使う側だけ `ticket_id = 108020009` という**実在しない ID** を持っていた
    -- (桁が 1 つ多い。本家から引き継いだ誤記)。session.GetInvItemByType が必ず nil を
    -- 返すので、**手持ちの券があっても使われず、毎回ショップで買っていた**。
    -- ツールチップ側の {10820009, 11035056} が正しいことは、ゲーム本体の item*.ies を
    -- 引いて確認済み(108020009 はどの表にも無い / docs/LEVEL_CAP_UPDATE.md の手順)。
    tickets = {10820009, 11035056},
    max_count = 3
}
function Indun_panel_telharsha_frame(indun_panel, key, value, y, x)
    local btn = indun_panel:CreateOrGetControl('button', key .. 'btn', x, y, Indun_panel_s(80), Indun_panel_s(30))
    AUTO_CAST(btn)
    btn:SetText("{ol}IN")
    btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_enter_solo")
    btn:SetEventScriptArgNumber(ui.LBUTTONUP, value)
    local count = indun_panel:CreateOrGetControl("richtext", key .. "count", x + Indun_panel_s(85),
        y + Indun_panel_s(5), Indun_panel_s(50), Indun_panel_s(30))
    count:SetText(Indun_panel_get_entrance_count(value, 2))
    local ticket_btn = indun_panel:CreateOrGetControl('button', key .. 'ticket_btn', x + Indun_panel_s(130), y,
        Indun_panel_s(80), Indun_panel_s(30))
    AUTO_CAST(ticket_btn)
    local count = Indun_panel_get_invitem_count(TELHARSHA_CONFIG.tickets)
    local icon_text = ""
    local item_cls = GetClassByType('Item', TELHARSHA_CONFIG.tickets[1])
    if item_cls then
        local fmt = g.lang == "Japanese" and "{ol}{img %s %d %d } %d枚持っています" or
                        "{ol}{img %s %d %d } Quantity in Inventory: %d"
        icon_text = string.format(fmt, item_cls.Icon, Indun_panel_s(25), Indun_panel_s(25), count)
    end
    ticket_btn:SetTextTooltip(icon_text)
    ticket_btn:SetText("{ol}{#EE7800}" .. Indun_panel_f(14) .. "BUYUSE")
    ticket_btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_buyuse_telharsha")
    ticket_btn:SetEventScriptArgString(ui.LBUTTONUP, TELHARSHA_CONFIG.recipe)
    ticket_btn:SetEventScriptArgNumber(ui.LBUTTONUP, value)
    local change_count = Indun_panel_get_recipe_trade_count(TELHARSHA_CONFIG.recipe)
    local tos_shop_count = indun_panel:CreateOrGetControl("richtext", key .. "tos_shop_count", x + Indun_panel_s(215),
        y + Indun_panel_s(5), Indun_panel_s(40), Indun_panel_s(30))
    tos_shop_count:SetText(string.format("{ol}%s({img icon_item_Tos_Event_Coin %d %d}%s)", Indun_panel_f(16),
        Indun_panel_s(15), Indun_panel_s(15), change_count))
end

function Indun_panel_buyuse_telharsha(indun_panel, ctrl, recipe_name, indun_type)
    if not indun_type then
        return
    end
    local indun_cls = GetClassByType("Indun", indun_type)
    if not indun_cls then
        return
    end
    local current_count = 0
    if indun_cls then
        current_count = GET_CURRENT_ENTERANCE_COUNT(indun_cls.PlayPerResetType) or 0
    end
    if tonumber(current_count) < TELHARSHA_CONFIG.max_count then
        ReserveScript(string.format("Indun_panel_enter_solo(nil, nil, '', %d)", indun_type), 0.2)
        return
    end
    local used = Indun_panel_consume_ticket("other", TELHARSHA_CONFIG.tickets, {
        on_use = function()
            ReserveScript(string.format("Indun_panel_enter_solo(nil, nil, '', %d)", indun_type), 0.5)
        end,
        on_buy = function()
            if Indun_panel_get_recipe_trade_count(recipe_name) >= 1 then
                Indun_panel_item_buy_use(recipe_name)
                ReserveScript(string.format("Indun_panel_enter_solo(nil, nil, '', %d)", indun_type), 1.5)
                return true
            end
            return false
        end
    })
    if not used then
        local msg = g.lang == "Japanese" and "トレード回数が足りません。" or "No trade count."
        ui.SysMsg(msg)
    end
end

local VELNICE_CONFIG = {
    recipe = "PVP_MINE_52",
    tickets = {11030169, 11030257}, -- 優先順: 1日期限 -> 通常
    max_count = 1
}
function Indun_panel_velnice_frame(indun_panel, key, value, y, x)
    local btn = indun_panel:CreateOrGetControl('button', key .. 'btn', x, y, Indun_panel_s(80), Indun_panel_s(30))
    AUTO_CAST(btn)
    btn:SetText("{ol}IN")
    btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_enter_velnice_solo")
    btn:SetEventScriptArgNumber(ui.LBUTTONUP, value)
    local count = indun_panel:CreateOrGetControl("richtext", key .. "count", x + Indun_panel_s(85),
        y + Indun_panel_s(5), Indun_panel_s(50), Indun_panel_s(30))
    count:SetText(Indun_panel_get_entrance_count(value, 2))
    local ticket_btn = indun_panel:CreateOrGetControl('button', key .. 'ticket_btn', x + Indun_panel_s(130), y,
        Indun_panel_s(80), Indun_panel_s(30))
    AUTO_CAST(ticket_btn)
    local count = Indun_panel_get_invitem_count(VELNICE_CONFIG.tickets)
    local icon_text = ""
    local item_cls = GetClassByType('Item', VELNICE_CONFIG.tickets[1])
    if item_cls then
        local fmt = g.lang == "Japanese" and "{ol}{img %s %d %d } %d枚持っています" or
                        "{ol}{img %s %d %d } Quantity in Inventory: %d"
        icon_text = string.format(fmt, item_cls.Icon, Indun_panel_s(25), Indun_panel_s(25), count)
    end
    ticket_btn:SetTextTooltip(icon_text)
    ticket_btn:SetText("{ol}{#EE7800}" .. Indun_panel_f(14) .. "BUYUSE")
    ticket_btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_buyuse_vel")
    ticket_btn:SetEventScriptArgString(ui.LBUTTONUP, VELNICE_CONFIG.recipe)
    ticket_btn:SetEventScriptArgNumber(ui.LBUTTONUP, value)
    local trade_count = Indun_panel_get_recipe_trade_count(VELNICE_CONFIG.recipe)
    trade_count = math.max(0, trade_count)
    local overbuy_limit = Indun_panel_overbuy_count(VELNICE_CONFIG.recipe)
    local change_text = indun_panel:CreateOrGetControl("richtext", key .. "change_text", x + Indun_panel_s(215),
        y + Indun_panel_s(5), Indun_panel_s(60), Indun_panel_s(30))
    change_text:SetText(string.format("{ol}{#FFFFFF}(%d/%d)", trade_count, overbuy_limit))
    local amount = indun_panel:CreateOrGetControl("richtext", key .. "amount", x + Indun_panel_s(280),
        y + Indun_panel_s(5), Indun_panel_s(50), Indun_panel_s(30))
    local cost = Indun_panel_overbuy_amount(VELNICE_CONFIG.recipe)
    local color = (trade_count > 0) and "{#FFFFFF}" or "{#FF0000}"
    local amount_str = string.format("{ol}{#FFFFFF}({img pvpmine_shop_btn_total %d %d}%s%s{ol}{#FFFFFF})",
        Indun_panel_s(20), Indun_panel_s(20), color, GET_COMMAED_STRING(cost))
    amount:SetText(amount_str)
end

function Indun_panel_buyuse_vel(indun_panel, ctrl, recipe_name, indun_type)
    if not indun_type then
        return
    end
    local indun_cls = GetClassByType("Indun", indun_type)
    if not indun_cls then
        return
    end
    local current_count = 0
    if indun_cls then
        current_count = GET_CURRENT_ENTERANCE_COUNT(indun_cls.PlayPerResetType) or 0
    end
    local reserve_script = string.format("Indun_panel_enter_velnice_solo(nil, nil, '', %d)", indun_type)
    if tonumber(current_count) < VELNICE_CONFIG.max_count then
        ReserveScript(reserve_script, 0.2)
        return
    end
    -- ヴェルニースは追加購入枠(OverBuy)も「購入」の段でまとめて見る。
    -- チャレンジと違い、以前からここは通常枠と追加枠を同じ 1 手として扱っている。
    local used = Indun_panel_consume_ticket("other", VELNICE_CONFIG.tickets, {
        on_use = function()
            ReserveScript(reserve_script, 1.0)
        end,
        on_buy = function()
            local trade_count = Indun_panel_get_recipe_trade_count(recipe_name)
            local overbuy_limit = Indun_panel_overbuy_count(recipe_name)
            if trade_count >= 1 or overbuy_limit > 0 then
                Indun_panel_item_buy_use(recipe_name)
                ReserveScript(reserve_script, 1.5)
                return true
            end
            return false
        end
    })
    if not used then
        ui.SysMsg(g.lang == "Japanese" and "トレード回数が足りません。" or "No trade count.")
    end
end

function Indun_panel_enter_velnice_solo(indun_panel, ctrl, str, indun_type)
    local indun_cls = GetClassByType("Indun", indun_type)
    if not indun_cls then
        return
    end
    local account_obj = GetMyAccountObj()
    if account_obj then
        local stage = TryGetProp(account_obj, "SOLO_DUNGEON_MINI_CLEAR_STAGE", 0)
        local yes_scp = "INDUNINFO_MOVE_TO_SOLO_DUNGEON_PRECHECK"
        local title = ScpArgMsg("Select_Stage_SoloDungeon", "Stage", stage + 5)
        INDUN_EDITMSGBOX_FRAME_OPEN(indun_type, title, "", yes_scp, "", 1, stage + 5, 1)
    end
end

-- 前方宣言してある(ファイル上部)。ここは代入なので local を付けないこと
DUNGEON_TICKET_CONFIG = {
    [684] = { -- (嘆きの墓地)
        label = "490",
        tickets = {11200276, 11200275, 11200274}
    },
    [732] = { -- (共鳴の聖所: ザウラ)
        label = "560",
        tickets = {11210071, 11210070, 11210069},
        -- **入場はこちらで押さない。** 窓を開くところで止める(Indun_panel_enter_solo)
        open_only = true
    }
}
function Indun_panel_create_common_ticket_frame(indun_panel, key, indun_type, y, x)
    local config = DUNGEON_TICKET_CONFIG[indun_type]
    if not config then
        return
    end
    local btn = indun_panel:CreateOrGetControl('button', key .. 'btn', x, y, Indun_panel_s(80), Indun_panel_s(30))
    AUTO_CAST(btn)
    btn:SetText("{ol}" .. config.label)
    btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_enter_solo")
    btn:SetEventScriptArgNumber(ui.LBUTTONUP, indun_type)
    local count_text = indun_panel:CreateOrGetControl("richtext", key .. "count", x + Indun_panel_s(85),
        y + Indun_panel_s(5), Indun_panel_s(50), Indun_panel_s(30))
    count_text:SetText(Indun_panel_get_entrance_count(indun_type, 1))
    local ticket_btn = indun_panel:CreateOrGetControl('button', key .. 'ticket_btn', x + Indun_panel_s(115), y,
        Indun_panel_s(80), Indun_panel_s(30))
    AUTO_CAST(ticket_btn)
    ticket_btn:SetText("{ol}{#EE7800}" .. Indun_panel_f(14) .. "USE")
    local inv_count = 0
    for _, id in ipairs(config.tickets) do
        local inv_item = session.GetInvItemByType(id)
        if inv_item then
            inv_count = inv_count + inv_item.count
        end
    end
    if #config.tickets > 0 then
        local item_cls = GetClassByType('Item', config.tickets[1])
        if item_cls then
            local fmt = g.lang == "Japanese" and "{ol}{img %s %d %d } %d枚持っています" or
                            "{ol}{img %s %d %d } Quantity in Inventory: %d"
            ticket_btn:SetTextTooltip(string.format(fmt, item_cls.Icon, Indun_panel_s(25), Indun_panel_s(25),
                inv_count))
        end
    end
    ticket_btn:SetEventScript(ui.LBUTTONUP, "Indun_panel_item_use")
    ticket_btn:SetEventScriptArgNumber(ui.LBUTTONUP, indun_type)
end

function Indun_panel_cemetery_frame(indun_panel, key, indun_type, y, x)
    Indun_panel_create_common_ticket_frame(indun_panel, key, indun_type, y, x)
end

-- 共鳴の聖所(SanctuartyResonance)。嘆きの墓地と同じく入場券で入るパーティダンジョンなので、
-- 素の入場も ReqRaidAutoUIOpen で同じ経路を通る(induninfo.lua の RaidType = PartyNormal 系)
function Indun_panel_resonance_frame(indun_panel, key, indun_type, y, x)
    Indun_panel_create_common_ticket_frame(indun_panel, key, indun_type, y, x)
end

-- 嘆きの墓地 / 共鳴の聖所の入場券。ショップで売っていないので「購入」の段は空振りする。
function Indun_panel_item_use(indun_panel, ctrl, str, indun_type)
    local config = DUNGEON_TICKET_CONFIG[indun_type]
    if not config then
        return
    end
    Indun_panel_consume_ticket("other", config.tickets)
end

function Indun_panel_jsr_frame(indun_panel, y, x)
    local jsrbtn = indun_panel:CreateOrGetControl('button', 'jsrbtn', x, y, Indun_panel_s(80), Indun_panel_s(30))
    AUTO_CAST(jsrbtn)
    jsrbtn:SetText("{ol}JSR")
    jsrbtn:SetEventScript(ui.LBUTTONUP, "FIELD_BOSS_JOIN_ENTER_CLICK")
    jsrbtn:SetUserValue("BASE_X", x)
    jsrbtn:SetUserValue("BASE_Y", y)
    Indun_panel_field_boss_enter_timer_setting(jsrbtn)
    jsrbtn:RunUpdateScript("Indun_panel_field_boss_enter_timer_setting", 1.0)
end

local function format_jsr_time(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local seconds_rem = seconds % 60

    local jp = string.format("%d時間%d分%d秒", hours, minutes, seconds_rem)
    local en = string.format("%02d:%02d:%02d", hours, minutes, seconds_rem)
    return jp, en
end

function Indun_panel_field_boss_enter_timer_setting(ctrl)
    local frame = ctrl:GetTopParentFrame()
    if not frame then
        return 0
    end
    local server_time_str = date_time.get_lua_now_datetime_str()
    if not server_time_str then
        return 1
    end
    local _, _, _, hour_str, min_str, sec_str = server_time_str:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
    if not hour_str then
        return 1
    end
    local today_sec = tonumber(hour_str) * 3600 + tonumber(min_str) * 60 + tonumber(sec_str)
    local sec12 = 12 * 3600
    local sec22 = 22 * 3600
    local diff12 = sec12 - today_sec
    local diff22 = sec22 - today_sec
    local text_str = ""
    local is_en = (g.indun_panel_settings.etc.en_ver == 1) -- 設定参照先を修正
    if diff12 >= 0 then
        local jp, en = format_jsr_time(diff12)
        text_str = is_en and (en .. " After Start") or (jp .. ClMsg("After_Start"))
    elseif diff12 >= -300 then
        local jp, en = format_jsr_time(300 + diff12)
        text_str = is_en and (en .. " After Exit") or (jp .. ClMsg("After_Exit"))
    elseif diff22 >= 0 then
        local jp, en = format_jsr_time(diff22)
        text_str = is_en and (en .. " After Start") or (jp .. ClMsg("After_Start"))
    elseif diff22 >= -300 then
        local jp, en = format_jsr_time(300 + diff22)
        text_str = is_en and (en .. " After Exit") or (jp .. ClMsg("After_Exit"))
    else
        text_str = is_en and "Already Exit" or ClMsg("Already_Exit")
    end
    local x = ctrl:GetUserIValue("BASE_X")
    local y = ctrl:GetUserIValue("BASE_Y")
    local jsrtime = frame:CreateOrGetControl("richtext", "jsrtime", x + 85, y + 5, 10, 10)
    jsrtime:SetText("{ol}" .. text_str)
    if x == 0 then
        jsrtime:ShowWindow(0)
    else
        jsrtime:ShowWindow(1)
    end
    return 1
end
-- indun_panel ここまで

