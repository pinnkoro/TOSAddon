-- Guild Storage List 本体
--
-- ギルド保管庫(ギルド情報の「保管箱」タブ。素は 66px のアイコンを並べるだけ)の中身を
-- 文字の一覧にし、配布対象者の口数で割った 1 口あたりの個数を出す。
--
-- 配布対象者は vc_attendance(封鎖戦の出席管理の Bot)が、スプレッドシートの「アドオン連携」タブに
-- 書く 1 行の連携文字列から読む。配布する人はそのセルをコピーして、一覧の窓の「出席データ」欄に貼る。
--   連携文字列: gsl1|<ID>|<週の見出し,...>|<名前 b64>:<週ごとの出席 0/1>,...
--   1 口 = まだ配っていない週 1 つぶんの出席(同じ週に複数のボスへ出ても 1 口)
--   1 口あたり = 指定が空なら 切り捨て((在庫 - 取り置き) / 口数の合計)、指定があればその数
--   1 人の数   = 1 口あたり × その人の口数
--   残り       = 在庫 - 1 口あたり × 口数の合計 - 取り置き
-- 名前を base64url にしているのは、ゲーム内の入力欄への貼り付けが Shift_JIS を経由するらしく、
-- 「枝」(8E 7D)のように 2 バイト目が「}」になる文字の後ろに文字が続くと貼れないため(実機で確認)。
--
-- 配り終わったら「配布記録を作る」で 1 行の配布記録を出し、配布する人がそれを Discord の
-- /配布記録 に貼る。Bot が「配布履歴」に残して告知文を返し(打った人にだけ見える)、配った週は次の連携文字列から外れる。
--   配布記録: gsr1|<ID>|<アイテム名 b64>:<1 口あたりの個数>,...|<ギルドに見つからず送らなかった人 b64>,...|
--
-- **送付そのものは素の「アイテム送る」窓(guildinven_send)に任せる。** 保管庫のアイテムを
-- 押して素の窓が開いたところで、対象者のチェックと個数を入れておくだけで、送信ボタンは
-- 利用者が押す。素の GUILDINVEN_SEND_CLICK は送る前に
--   * 残数が足りるか(LackOfHaveCount)
--   * コロニー戦中のコロニー報酬でないか(CannotSendColonyReward)
-- を見ており、窓を開く経路(GUILDINFO_INVEN_ITEM_CLICK)はギルド長か権限 20 の確認を
-- 通している。ReqGuildInventorySend を直接呼ぶとこの門番を全部外すことになるので呼ばない。
--
-- ファイルの置き場所:
--   ../addons/_guild_storage_list/<AID>/guild_storage_list.json  … アイテムごとの配布ルール・並び
--   ../addons/_guild_storage_list/link.txt    … 最後に貼った連携文字列
--   ../addons/_guild_storage_list/record.txt  … 最後に作った配布記録
--   ../addons/_guild_storage_list/stock.tsv   … 在庫(シートの K:L 列へ貼れる形)
-- (Nexus Addons P v2.13.x に同梱していた頃は ../addons/_nexus_addons_p/ の下。初回に 90_init.lua が引き継ぐ)
--
-- **local は増やさない。** このファイルはメインチャンク直下へ連結されるので、ファイル単位の
-- local が 1 関数 200 個の枠を食う(超えるとバンドル全体が読めなくなる)。定数も g の下に置く。
g.guild_storage_list = g.guild_storage_list or {
    -- 保管庫の中身。Guild_storage_list_read_storage が作り直す
    items = {},
    -- ClassName → 在庫の合計(送付窓の事前入力で使う)
    stock = {},
    -- 貼った連携文字列(g.guild_storage_list_parse_link の戻り値)と、ギルドメンバーとの照合結果
    --   matched … {name = ギルドでの表記, units = 口数} の配列 / unmatched … 見つからなかった名前
    link = nil,
    matched = {},
    unmatched = {},
    -- 素の保管庫(ギルド情報)へ足したボタンの印
    button_added = false,
    -- 順に配る(Guild_storage_list_dist_*)の状態
    --   active … 配っている途中か / queue … 配る ClassName の並び / index … 今の位置
    --   opened … 事前入力した送付窓のアイテム / opened_per … そのとき入れた 1 口あたりの個数
    --   sent … この回で送ったアイテム ClassName → {name, per}(二重配布の防止と配布記録に使う)
    --   sent_order … 送った順の ClassName
    --   mode … "units"(口数で配る。「配布を始める」)か "reserve"(取り置きを 1 人に送る。「取り置きを配布する」)
    --   opened_mode … 事前入力した送付窓がどちらの入力か / reserve_sent … 取り置きを送ったアイテム
    --   (取り置きは配布記録に載せないので sent とは分けて持つ。分けないと、配った後の取り置きが
    --    「配布済み」として入力されない)
    dist = {
        active = false,
        mode = "units",
        queue = {},
        index = 1,
        opened = nil,
        opened_mode = nil,
        opened_per = 0,
        sent = {},
        sent_order = {},
        reserve_sent = {}
    }
}
g.guild_storage_list_const = {
    frame = "guild_storage_list",
    width = 720,
    -- 見出しで並べ替えられる列。値は Guild_storage_list_sort_value が返す
    sort_keys = {
        name = true,
        stock = true,
        per = true,
        remain = true
    },
    list_height = 420,
    row_height = 30,
    b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
}

function Guild_storage_list_t(ja, en)
    return g.lang == "Japanese" and ja or en
end

function Guild_storage_list_io_dir()
    return string.format("../addons/%s", addon_name_lower)
end

-- ===== 純ロジック(docs/tests/test_guild_storage_list.lua が検査する) =====

-- 1 口あたりの個数・配る総数・残り・在庫不足かを返す。
--   stock … 在庫の合計 / count … 口数の合計 / rule … {use, reserve, amount}
-- amount(指定)が空(0)なら均等割り: 1 口あたり = 切り捨て((在庫 - 取置) / 口数)。シートの M / O / R 列と同じ式。
-- amount を入れたら 1 口あたりはその数ちょうど。**在庫が足りなくても数を勝手に減らさない**
-- (1 個のつもりが黙って 0 個になる、を起こさない)。足りないときは 4 つ目の short を true にして、
-- 呼び出し側が「配らない」扱いにする(告知文・順に配る・送付窓の事前入力のどれにも載せない)。
function g.guild_storage_list_calc(stock, count, rule)
    stock = tonumber(stock) or 0
    count = tonumber(count) or 0
    local reserve = math.max(0, math.floor(tonumber(rule and rule.reserve) or 0))
    local amount = math.max(0, math.floor(tonumber(rule and rule.amount) or 0))
    if not rule or rule.use ~= 1 or count <= 0 then
        return 0, 0, stock, false
    end
    local avail = stock - reserve
    if amount > 0 then
        local total = amount * count
        return amount, total, stock - total - reserve, total > avail
    end
    if avail <= 0 then
        return 0, 0, stock, false
    end
    local per = math.floor(avail / count)
    local total = per * count
    return per, total, stock - total - reserve, false
end

-- 実際に配る 1 口あたりの個数(在庫不足なら 0)
function g.guild_storage_list_sendable(stock, count, rule)
    local per, _, _, short = g.guild_storage_list_calc(stock, count, rule)
    if short then
        return 0
    end
    return per
end

-- 名前の照合用。前後の空白と、表示用のタグ({ol} など)を落とす。
function g.guild_storage_list_norm(name)
    local s = tostring(name or ""):gsub("{[^}]*}", "")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

-- base64url(パディング無し)。bit ライブラリに頼らず算術だけで行う。
function g.guild_storage_list_b64e(text)
    local chars = g.guild_storage_list_const.b64
    local out = {}
    for i = 1, #text, 3 do
        local b1, b2, b3 = string.byte(text, i, i + 2)
        local n = b1 * 65536 + (b2 or 0) * 256 + (b3 or 0)
        local idx = {math.floor(n / 262144) % 64, math.floor(n / 4096) % 64, math.floor(n / 64) % 64, n % 64}
        local count = b3 and 4 or (b2 and 3 or 2)
        for k = 1, count do
            out[#out + 1] = string.sub(chars, idx[k] + 1, idx[k] + 1)
        end
    end
    return table.concat(out)
end

-- 読めない文字が混じっていたら nil
function g.guild_storage_list_b64d(text)
    local chars = g.guild_storage_list_const.b64
    local values = {}
    for i = 1, #text do
        local pos = string.find(chars, string.sub(text, i, i), 1, true)
        if not pos then
            return nil
        end
        values[i] = pos - 1
    end
    if #values % 4 == 1 then
        return nil
    end
    local out = {}
    for i = 1, #values, 4 do
        local v1, v2, v3, v4 = values[i], values[i + 1], values[i + 2], values[i + 3]
        local n = v1 * 262144 + v2 * 4096 + (v3 or 0) * 64 + (v4 or 0)
        out[#out + 1] = string.char(math.floor(n / 65536) % 256)
        if v3 then
            out[#out + 1] = string.char(math.floor(n / 256) % 256)
        end
        if v4 then
            out[#out + 1] = string.char(n % 256)
        end
    end
    return table.concat(out)
end

-- 連携文字列を読む。戻り値は {id, weeks = {見出し}, people = {{team, bits, units}}}。読めなければ nil, 理由
function g.guild_storage_list_parse_link(text)
    text = g.guild_storage_list_norm(text)
    local tag, id, weeks, people = string.match(text, "^([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
    if tag ~= "gsl1" or not id or id == "" then
        return nil, "format"
    end
    local link = {
        id = id,
        weeks = {},
        people = {}
    }
    for w in string.gmatch(weeks, "[^,]+") do
        link.weeks[#link.weeks + 1] = w
    end
    for chunk in string.gmatch(people, "[^,]+") do
        local enc, bits = string.match(chunk, "^([^:]+):([01]+)$")
        local team = enc and g.guild_storage_list_b64d(enc)
        if not team or #bits ~= #link.weeks then
            return nil, "person"
        end
        local units = 0
        for _ in string.gmatch(bits, "1") do
            units = units + 1
        end
        link.people[#link.people + 1] = {
            team = team,
            bits = bits,
            units = units
        }
    end
    return link
end

-- 連携文字列の人(people)をギルドメンバーの名前と突き合わせる。
-- 戻り値: {name = ギルドでの表記, units = 口数} の配列, 見つからなかった人の名前の配列
function g.guild_storage_list_match(people, member_names)
    local exact, lower = {}, {}
    for _, name in ipairs(member_names or {}) do
        local n = g.guild_storage_list_norm(name)
        exact[n] = n
        lower[string.lower(n)] = n
    end
    local matched, unmatched, seen = {}, {}, {}
    for _, p in ipairs(people or {}) do
        local team = g.guild_storage_list_norm(p.team)
        local hit = exact[team] or lower[string.lower(team)]
        if hit and not seen[hit] then
            seen[hit] = true
            matched[#matched + 1] = {
                name = hit,
                units = p.units or 1
            }
        elseif not hit then
            unmatched[#unmatched + 1] = team
        end
    end
    return matched, unmatched
end

-- 配布記録に載せる行を決める。
--   items  … 一覧の並びのアイテム / rule_of(class_name) … ルール / plan(item) … 今の在庫での 1 口あたり, 在庫不足か
--   sent   … この回で送ったアイテム ClassName → {name, per} / sent_order … 送った順
-- **送ったアイテムは、送ったときの 1 口あたりで載せる。** 今の在庫で計算し直すと、送った後は
-- 在庫が減っているので 0 個や在庫不足になり、実際に配ったものが記録から抜ける(PR #220 のレビュー指摘)。
-- 送り切って保管庫から消えたアイテムも、送った順に後ろへ足す。まだ送っていないものは今の在庫で計算する。
-- 戻り値: {name, per} の配列, 在庫不足で外したアイテム名の配列
function g.guild_storage_list_record_rows(items, rule_of, plan, sent, sent_order)
    local rows, shorts, seen = {}, {}, {}
    sent = sent or {}
    for _, item in ipairs(items) do
        local done = sent[item.class_name]
        if done then
            seen[item.class_name] = true
            rows[#rows + 1] = {
                name = done.name,
                per = done.per
            }
        elseif rule_of(item.class_name).use == 1 then
            local per, short = plan(item)
            if short then
                shorts[#shorts + 1] = item.name
            elseif per > 0 then
                rows[#rows + 1] = {
                    name = item.name,
                    per = per
                }
            end
        end
    end
    for _, class_name in ipairs(sent_order or {}) do
        local done = sent[class_name]
        if done and not seen[class_name] then
            seen[class_name] = true
            rows[#rows + 1] = {
                name = done.name,
                per = done.per
            }
        end
    end
    return rows, shorts
end

-- 配布記録を組み立てる。rows は {name = アイテム名, per = 1 口あたり} の配列、excluded は送らなかった人。
function g.guild_storage_list_record(link_id, rows, excluded)
    local items, names = {}, {}
    for _, row in ipairs(rows) do
        items[#items + 1] = g.guild_storage_list_b64e(row.name) .. ":" .. row.per
    end
    for _, name in ipairs(excluded) do
        names[#names + 1] = g.guild_storage_list_b64e(name)
    end
    -- 末尾に「|」を 1 つ余分に付ける。ゲーム内の欄をマウスでなぞってコピーすると最後の 1 文字を
    -- 取りこぼしやすく(実機で発生)、それが送らなかった人の名前の最後の文字だと名前が壊れるため。
    -- Bot(vc_attendance の link.parse_record)は、この「|」が有っても無くても読む
    return string.format("gsr1|%s|%s|%s|", link_id, table.concat(items, ","), table.concat(names, ","))
end

-- items を手動の並び(order: ClassName の配列)で並べた新しい配列を返す。
-- order に無いもの(新しく入ったアイテム)は、元の並び(スロット順)のまま後ろへ付く。
function g.guild_storage_list_ordered(items, order)
    local pos, base, out = {}, {}, {}
    for i, class_name in ipairs(order or {}) do
        if pos[class_name] == nil then
            pos[class_name] = i
        end
    end
    for i, item in ipairs(items) do
        base[item.class_name] = i
        out[i] = item
    end
    table.sort(out, function(a, b)
        local pa, pb = pos[a.class_name], pos[b.class_name]
        if pa and pb then
            return pa < pb
        end
        if pa or pb then
            return pa ~= nil
        end
        return base[a.class_name] < base[b.class_name]
    end)
    return out
end

-- 見出しで選んだ列(key)で並べ替える。key が空なら手動の並びのまま。
-- value_of(item, key) が nil を返すもの(配らないアイテムの「1人」「残り」)は、昇順でも降順でも後ろへ寄せる。
-- 値が同じものは手動の並びを保つ。
function g.guild_storage_list_sorted(items, order, key, desc, value_of)
    local ordered = g.guild_storage_list_ordered(items, order)
    if not key or key == "" then
        return ordered
    end
    local idx = {}
    for i, item in ipairs(ordered) do
        idx[item.class_name] = i
    end
    table.sort(ordered, function(a, b)
        local va, vb = value_of(a, key), value_of(b, key)
        if va ~= nil and vb ~= nil and va ~= vb then
            if desc then
                return va > vb
            end
            return va < vb
        end
        if (va == nil) ~= (vb == nil) then
            return va ~= nil
        end
        return idx[a.class_name] < idx[b.class_name]
    end)
    return ordered
end

-- 手動の並びで class_name を 1 つ前(delta = -1)/後ろ(delta = 1)へ動かした新しい並びを返す。
--   full    … 今の見た目の全体の並び(ClassName の配列。並べ替え中ならその並び)
--   visible … 画面に出ているものだけの並び(「配るものだけ表示」で絞っているとき)
-- 隣は visible の隣で決める(絞り込み中に、見えていないアイテムと入れ替わって動かないように見えるのを防ぐ)。
-- 動かせないとき(端・見つからない)は nil。
function g.guild_storage_list_move(full, visible, class_name, delta)
    local vi
    for i, name in ipairs(visible) do
        if name == class_name then
            vi = i
            break
        end
    end
    local target = vi and visible[vi + delta]
    if not target then
        return nil
    end
    local out = {}
    for _, name in ipairs(full) do
        if name ~= class_name then
            out[#out + 1] = name
        end
    end
    for i, name in ipairs(out) do
        if name == target then
            table.insert(out, delta < 0 and i or i + 1, class_name)
            return out
        end
    end
    return nil
end

-- ===== 設定 =====

function Guild_storage_list_settings_path()
    return string.format("../addons/%s/%s/guild_storage_list.json", addon_name_lower, g.active_id)
end

function Guild_storage_list_load_settings()
    local settings = g.load_json(Guild_storage_list_settings_path())
    local changed = false
    if type(settings) ~= "table" then
        settings = {}
        changed = true
    end
    if type(settings.items) ~= "table" then
        settings.items = {}
        changed = true
    end
    -- 告知文は Bot が組み立てるようになったので、前の版の設定は捨てる
    settings.notice = nil
    if settings.only_use ~= 1 then
        settings.only_use = 0
    end
    -- 取り置きの送り先(ギルドのチーム名)。空なら送付窓でチェックを入れずに開き、利用者が選ぶ
    if type(settings.reserve_to) ~= "string" then
        settings.reserve_to = ""
    end
    -- 並び。order は手動で動かしたときの ClassName の並び(保管庫から消えたものも覚えておく)。
    -- sort_key は見出しで選んだ列(空 = 手動の並び)
    if type(settings.order) ~= "table" then
        settings.order = {}
    end
    if not g.guild_storage_list_const.sort_keys[settings.sort_key] then
        settings.sort_key = ""
    end
    settings.sort_desc = settings.sort_desc == 1 and 1 or 0
    g.guild_storage_list_settings = settings
    if changed then
        Guild_storage_list_save_settings()
    end
end

function Guild_storage_list_save_settings()
    if g.guild_storage_list_settings then
        g.save_json(Guild_storage_list_settings_path(), g.guild_storage_list_settings)
    end
end

-- アイテムのルール。無ければ「配らない」を返す(保管庫には配布物以外も入っているため)。
-- **保存するのは触ったものだけ。** 見ただけのアイテムまで書くと、保管庫を通り過ぎた
-- アイテムが設定ファイルに溜まり続ける。書き換える側は create=true で呼ぶ。
function Guild_storage_list_rule(class_name, create)
    local items = g.guild_storage_list_settings.items
    local rule = items[class_name]
    if type(rule) ~= "table" then
        rule = {
            use = 0,
            reserve = 0,
            -- 1 口あたりの指定。0 = 均等割り
            amount = 0
        }
        if create then
            items[class_name] = rule
        end
    end
    return rule
end

-- ===== 初期化 =====

function guild_storage_list_on_init()
    if not g.guild_storage_list_settings then
        Guild_storage_list_load_settings()
    end
    if g.settings.guild_storage_list.use == 0 then
        ui.DestroyFrame(addon_name_lower .. g.guild_storage_list_const.frame)
        ui.DestroyFrame(addon_name_lower .. g.guild_storage_list_const.frame .. "_members")
        Guild_storage_list_remove_button()
        return
    end
    g.register_msg("GUILD_WAREHOUSE_ITEM_LIST", "Guild_storage_list_on_warehouse_msg")
    g.register_msg("GUILD_WAREHOUSE_ITEM_ADD", "Guild_storage_list_on_warehouse_msg")
    -- 素の送付窓を開いた直後に対象者と個数を入れる。**素を必ず先に呼ぶ**(窓の中身は素が作る)
    g.setup_hook(Guild_storage_list_GUILDINVEN_SEND_INIT, "GUILDINVEN_SEND_INIT")
    -- 送るボタンが押されて実際に送れたら、次のアイテムの送付窓を開く(順に配る)
    g.setup_hook(Guild_storage_list_GUILDINVEN_SEND_CLICK, "GUILDINVEN_SEND_CLICK")
end

-- 素の送るボタン。**素をそのまま呼ぶ**(残数・コロニー報酬の確認と送信は素が行う)。
-- 素は送れたときだけ最後に ui.CloseFrame('guildinven_send') するので、呼んだ後に窓が
-- 閉じていれば「送った」、開いたままなら確認で止まった(送っていない)と分かる。
function Guild_storage_list_GUILDINVEN_SEND_CLICK(parent, ctrl)
    local origin = g.FUNCS["GUILDINVEN_SEND_CLICK"]
    local results
    if origin then
        results = {origin(parent, ctrl)}
    else
        g.vlog("{#FF6347}guild_storage_list: GUILDINVEN_SEND_CLICK の素の実装が控えに無い{/}")
    end
    if g.settings.guild_storage_list.use == 1 then
        local ok, err = pcall(Guild_storage_list_dist_after_send)
        if not ok then
            g.vlog("{#FF6347}guild_storage_list: 送った後の処理で失敗 %s{/}", tostring(err))
        end
    end
    if results then
        return table.unpack(results)
    end
end

function Guild_storage_list_GUILDINVEN_SEND_INIT(item_class_name, item_count, item_id)
    local origin = g.FUNCS["GUILDINVEN_SEND_INIT"]
    local results
    if origin then
        results = {origin(item_class_name, item_count, item_id)}
    else
        g.vlog("{#FF6347}guild_storage_list: GUILDINVEN_SEND_INIT の素の実装が控えに無い{/}")
    end
    if g.settings.guild_storage_list.use == 1 then
        local ok, err = pcall(Guild_storage_list_prefill, item_class_name, tonumber(item_count) or 0)
        if not ok then
            g.vlog("{#FF6347}guild_storage_list: 事前入力で失敗 %s{/}", tostring(err))
        end
    end
    if results then
        return table.unpack(results)
    end
end

-- ===== データの読み込み =====

-- 保管庫の中身を ClassName ごとにまとめる。並びは素の画面と同じ(スロット番号順)。
function Guild_storage_list_read_storage()
    local items, by_class = {}, {}
    local list = session.GetEtcItemList(IT_GUILD)
    if list then
        FOR_EACH_INVENTORY(list, function(inv_list, inv_item)
            local obj = GetIES(inv_item:GetObject())
            if obj then
                local class_name = obj.ClassName
                local entry = by_class[class_name]
                if not entry then
                    entry = {
                        class_name = class_name,
                        name = dictionary.ReplaceDicIDInCompStr(obj.Name),
                        icon = GET_ITEM_ICON_IMAGE(obj),
                        count = 0,
                        index = inv_item.invIndex
                    }
                    by_class[class_name] = entry
                    items[#items + 1] = entry
                end
                entry.count = entry.count + inv_item.count
                if inv_item.invIndex < entry.index then
                    entry.index = inv_item.invIndex
                end
            end
        end, false)
    end
    table.sort(items, function(a, b)
        return a.index < b.index
    end)
    local stock = {}
    for _, entry in ipairs(items) do
        stock[entry.class_name] = entry.count
    end
    g.guild_storage_list.items = items
    g.guild_storage_list.stock = stock
    return items
end

function Guild_storage_list_guild_member_names()
    local names = {}
    local list = session.party.GetPartyMemberList(PARTY_GUILD)
    if not list then
        return names
    end
    for i = 0, list:Count() - 1 do
        local info = list:Element(i)
        if info then
            names[#names + 1] = info:GetName()
        end
    end
    return names
end

function Guild_storage_list_link_path()
    return Guild_storage_list_io_dir() .. "/link.txt"
end

-- 最後に貼った連携文字列(link.txt)を読み直し、ギルドメンバーと照合する。
function Guild_storage_list_load_link()
    local text
    local file = io.open(Guild_storage_list_link_path(), "r")
    if file then
        text = file:read("*a")
        file:close()
    end
    local link, err
    if text and text ~= "" then
        link, err = g.guild_storage_list_parse_link(text)
    end
    if not link then
        g.guild_storage_list.link = nil
        g.guild_storage_list.matched = {}
        g.guild_storage_list.unmatched = {}
        g.vlog("guild_storage_list: link.txt を読めない(%s)", tostring(err or "無い"))
        return false
    end
    g.guild_storage_list.link = link
    local members = Guild_storage_list_guild_member_names()
    local matched, unmatched = g.guild_storage_list_match(link.people, members)
    g.guild_storage_list.matched = matched
    g.guild_storage_list.unmatched = unmatched
    g.vlog("guild_storage_list: 連携 %s 週=%d 対象 %d 人 / ギルドで見つかった %d 人(%d 口) / 見つからない %d 人 / ギルド %d 人",
        link.id, #link.weeks, #link.people, #matched, Guild_storage_list_unit_count(), #unmatched, #members)
    return true
end

-- 口数の合計(ギルドで見つかった人だけ)
function Guild_storage_list_unit_count()
    local units = 0
    for _, m in ipairs(g.guild_storage_list.matched) do
        units = units + m.units
    end
    return units
end

-- ===== 素の保管庫(ギルド情報)へ足すボタン =====

function Guild_storage_list_on_warehouse_msg(frame, msg, arg_str, arg_num)
    if g.settings.guild_storage_list.use == 0 then
        return
    end
    Guild_storage_list_add_button()
    local list_frame = ui.GetFrame(addon_name_lower .. g.guild_storage_list_const.frame)
    if list_frame and list_frame:IsVisible() == 1 then
        Guild_storage_list_commit_edits()
        Guild_storage_list_read_storage()
        Guild_storage_list_build_rows(true)
    end
end

-- 保管庫の見出し(「ギルドアイテム」)の右へ、一覧を開くボタンを置く。
-- 見出しの親(保管箱タブの中身)に置くので、他のタブへ切り替えると一緒に隠れる。
function Guild_storage_list_add_button()
    local guildinfo = ui.GetFrame("guildinfo")
    if not guildinfo then
        return
    end
    local header = GET_CHILD_RECURSIVELY(guildinfo, "guildInventoryHeaderText")
    local slot_box = GET_CHILD_RECURSIVELY(guildinfo, "slotBox")
    if not header or not slot_box then
        return
    end
    local parent = header:GetParent() or guildinfo
    local x = slot_box:GetGlobalX() - parent:GetGlobalX() + slot_box:GetWidth() - 150
    local y = header:GetGlobalY() - parent:GetGlobalY()
    local btn = parent:CreateOrGetControl("button", "guild_storage_list_btn", x, y, 150, 30)
    AUTO_CAST(btn)
    btn:SetSkinName("test_pvp_btn")
    btn:SetText("{@st66b}" .. Guild_storage_list_t("文字で一覧", "Text List"))
    btn:SetEventScript(ui.LBUTTONUP, "Guild_storage_list_open")
    btn:SetTextTooltip(Guild_storage_list_t("{ol}保管庫の中身を文字で一覧にし、配布数を計算します",
        "{ol}List the guild storage as text and calculate the distribution"))
    btn:ShowWindow(1)
    if not g.guild_storage_list.button_added then
        g.guild_storage_list.button_added = true
        g.vlog("guild_storage_list: ボタンを置いた parent=%s(%s) x=%d y=%d", tostring(parent:GetName()),
            tostring(parent:GetClassString()), x, y)
    end
end

-- 機能を OFF にしたときに外す。**自分が置いた印が無ければ何もしない**(使っていない人の
-- ギルド情報を毎回探しに行かない)。
function Guild_storage_list_remove_button()
    if not g.guild_storage_list.button_added then
        return
    end
    local guildinfo = ui.GetFrame("guildinfo")
    local btn = guildinfo and GET_CHILD_RECURSIVELY(guildinfo, "guild_storage_list_btn")
    if btn then
        btn:GetParent():RemoveChild("guild_storage_list_btn")
    end
    g.guild_storage_list.button_added = false
end

-- ===== 一覧の窓 =====

function Guild_storage_list_open()
    if not g.guild_storage_list_settings then
        Guild_storage_list_load_settings()
    end
    local c = g.guild_storage_list_const
    local frame_name = addon_name_lower .. c.frame
    local frame = ui.GetFrame(frame_name)
    if not frame then
        frame = ui.CreateNewFrame("notice_on_pc", frame_name, 0, 0, 0, 0)
    end
    AUTO_CAST(frame)
    g.block_click_through(frame)
    frame:SetSkinName("test_frame_low")
    frame:SetTitleBarSkin("None")
    -- ギルド情報(92)と同じ高さ。素の送付窓(93)はこれより手前に出る
    frame:SetLayerLevel(92)
    frame:EnableMove(1)
    local height = c.list_height + 302
    frame:Resize(c.width, height)
    frame:SetPos(g.settings_frame_pos(c.width, height))
    frame:RemoveAllChild()

    local title = frame:CreateOrGetControl("richtext", "title", 20, 12, 200, 30)
    AUTO_CAST(title)
    title:SetText("{@st66b18}Guild Storage List")
    local close = frame:CreateOrGetControl("button", "close", 0, 0, 25, 25)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Guild_storage_list_close")

    local info = frame:CreateOrGetControl("richtext", "info", 20, 45, c.width - 40, 24)
    AUTO_CAST(info)
    local warn = frame:CreateOrGetControl("richtext", "warn", 20, 70, c.width - 40, 24)
    AUTO_CAST(warn)

    local only = frame:CreateOrGetControl("checkbox", "only_use", 20, 95, 200, 25)
    AUTO_CAST(only)
    only:SetText(Guild_storage_list_t("{ol}配るものだけ表示", "{ol}Show distributed only"))
    only:SetCheck(g.guild_storage_list_settings.only_use)
    only:SetEventScript(ui.LBUTTONUP, "Guild_storage_list_toggle_only")

    local reload = frame:CreateOrGetControl("button", "reload", c.width - 330, 92, 150, 32)
    AUTO_CAST(reload)
    reload:SetSkinName("test_pvp_btn")
    reload:SetText("{@st66b}" .. Guild_storage_list_t("読み直す", "Reload"))
    reload:SetTextTooltip(Guild_storage_list_t("{ol}保管庫の中身と、最後に貼った出席データを読み直します",
        "{ol}Reload the guild storage and the last pasted attendance data"))
    reload:SetEventScript(ui.LBUTTONUP, "Guild_storage_list_reload")

    local export = frame:CreateOrGetControl("button", "export", c.width - 170, 92, 150, 32)
    AUTO_CAST(export)
    export:SetSkinName("test_red_button")
    export:SetText("{@st41b}{s16}" .. Guild_storage_list_t("配布記録を作る", "Make record"))
    export:SetTextTooltip(Guild_storage_list_t(
        "{ol}下の「配布記録」欄に 1 行の配布記録を出します{nl}配り終わったら、それを Discord の /配布記録 に貼ってください{nl}(Bot が配布履歴に残し、告知文をあなたにだけ返します)",
        "{ol}Puts a one-line record in the Record field below{nl}After distributing, paste it into /distribute-record on Discord"))
    export:SetEventScript(ui.LBUTTONUP, "Guild_storage_list_export")

    -- 順に配る。押せるのはギルド情報の「保管箱」タブを開いているときだけ
    -- (送付窓は保管庫の枠を押す素の経路で開くため)。押せるかどうかは下の更新で追う
    local dist = frame:CreateOrGetControl("button", "dist", c.width - 490, 92, 150, 32)
    AUTO_CAST(dist)
    dist:SetSkinName("test_red_button")
    dist:SetEventScript(ui.LBUTTONUP, "Guild_storage_list_dist_click")
    local status = frame:CreateOrGetControl("richtext", "dist_status", 260, 14, c.width - 300, 24)
    AUTO_CAST(status)
    Guild_storage_list_dist_update(frame)
    frame:RunUpdateScript("Guild_storage_list_dist_update", 0.5)

    -- 見出し。列の位置は Guild_storage_list_build_rows と揃える
    local header = frame:CreateOrGetControl("groupbox", "header", 10, 130, c.width - 20, 26)
    AUTO_CAST(header)
    header:SetSkinName("market_listbase")
    Guild_storage_list_build_header(header)

    local list = frame:CreateOrGetControl("groupbox", "list", 10, 158, c.width - 20, c.list_height)
    AUTO_CAST(list)
    list:SetSkinName("bg")
    list:EnableScrollBar(1)

    -- 出席データ。スプレッドシートの「アドオン連携」のセル(連携文字列)を Ctrl+V で貼って Enter。
    -- 600 文字ほどまで欠けずに貼れることを実機で確かめてある(名前は base64url なので英数字だけ)
    local paste_y = 158 + c.list_height + 12
    local paste_label = frame:CreateOrGetControl("richtext", "paste_label", 20, paste_y + 5, 90, 24)
    AUTO_CAST(paste_label)
    paste_label:SetText("{ol}" .. Guild_storage_list_t("出席データ", "Attendance"))
    local paste = frame:CreateOrGetControl("edit", "paste", 110, paste_y, c.width - 130, 32)
    AUTO_CAST(paste)
    paste:SetSkinName("test_weight_skin")
    paste:SetFontName("white_16_ol")
    paste:SetTextAlign("left", "center")
    paste:SetMaxLen(4000)
    paste:SetEventScript(ui.ENTERKEY, "Guild_storage_list_paste_enter")
    paste:SetTextTooltip(Guild_storage_list_t("{ol}スプレッドシートの「アドオン連携」のセルを Ctrl+V で貼って Enter",
        "{ol}Paste the cell from the sheet with Ctrl+V and press Enter"))

    -- 配布記録。「配布記録を作る」で中身が入る。**Ctrl+A は効かない**(警告音が鳴る)ので、
    -- マウスでなぞって選び Ctrl+C する(実機で確認)。同じものを record.txt にも書く
    local record_y = paste_y + 42
    local record_label = frame:CreateOrGetControl("richtext", "record_label", 20, record_y + 5, 90, 24)
    AUTO_CAST(record_label)
    record_label:SetText("{ol}" .. Guild_storage_list_t("配布記録", "Record"))
    local record = frame:CreateOrGetControl("edit", "record", 110, record_y, c.width - 130, 32)
    AUTO_CAST(record)
    record:SetSkinName("test_weight_skin")
    record:SetFontName("white_16_ol")
    record:SetTextAlign("left", "center")
    record:SetMaxLen(4000)
    record:SetTextTooltip(Guild_storage_list_t(
        "{ol}マウスでなぞって選び Ctrl+C でコピーし、Discord の /配布記録 に貼る{nl}(Ctrl+A は効きません)",
        "{ol}Select with the mouse, Ctrl+C, then paste into /distribute-record on Discord"))

    -- 対象者の一覧(別窓)と、取り置きを 1 人に送る
    local tools_y = record_y + 42
    -- 詳細ログ。単体版は設定画面を持たないので、ここで切り替える(不具合を追うときに使う)
    local verbose = frame:CreateOrGetControl("checkbox", "verbose_log", 15, tools_y + 4, 90, 25)
    AUTO_CAST(verbose)
    verbose:SetText(Guild_storage_list_t("{ol}詳細ログ", "{ol}Log"))
    verbose:SetCheck(g.settings.verbose_log)
    verbose:SetTextTooltip(Guild_storage_list_t(
        "{ol}動作の記録を ../addons/_guild_storage_list/verbose_log.txt に出します{nl}不具合を報告するときに ON にしてください",
        "{ol}Writes a log to ../addons/_guild_storage_list/verbose_log.txt"))
    verbose:SetEventScript(ui.LBUTTONUP, "Guild_storage_list_toggle_verbose")
    local members = frame:CreateOrGetControl("button", "members", 110, tools_y, 170, 32)
    AUTO_CAST(members)
    members:SetSkinName("test_pvp_btn")
    members:SetText("{@st66b}" .. Guild_storage_list_t("対象者を見る", "Recipients"))
    members:SetTextTooltip(Guild_storage_list_t("{ol}貼った出席データの配布対象者と口数を、別の窓に出します",
        "{ol}Shows the recipients and their units from the pasted data in another window"))
    members:SetEventScript(ui.LBUTTONUP, "Guild_storage_list_members_open")
    local reserve = frame:CreateOrGetControl("button", "reserve", 290, tools_y, 190, 32)
    AUTO_CAST(reserve)
    reserve:SetSkinName("test_red_button")
    reserve:SetEventScript(ui.LBUTTONUP, "Guild_storage_list_reserve_click")
    local reserve_to_label = frame:CreateOrGetControl("richtext", "reserve_to_label", 490, tools_y + 6, 60, 24)
    AUTO_CAST(reserve_to_label)
    reserve_to_label:SetText("{ol}" .. Guild_storage_list_t("送り先", "To"))
    local reserve_to = frame:CreateOrGetControl("edit", "reserve_to", 545, tools_y, c.width - 565, 32)
    AUTO_CAST(reserve_to)
    reserve_to:SetSkinName("test_weight_skin")
    reserve_to:SetFontName("white_16_ol")
    reserve_to:SetTextAlign("left", "center")
    reserve_to:SetText(g.guild_storage_list_settings.reserve_to)
    reserve_to:SetEventScript(ui.ENTERKEY, "Guild_storage_list_reserve_to_enter")
    reserve_to:SetTextTooltip(Guild_storage_list_t(
        "{ol}取り置きを送る人(チーム名)。入れておくと、その人にだけチェックを入れて開きます{nl}空なら誰にもチェックを入れません。Enter で保存",
        "{ol}Who receives the kept items (team name). If set, only that person is ticked{nl}Empty = nobody is ticked. Press Enter to save"))

    frame:ShowWindow(1)
    g.esc_register(frame_name, "Guild_storage_list_close")

    -- 保管庫の中身はギルド情報を開かないと届いていないことがあるので、読み込みも頼む。
    -- 届いたら GUILD_WAREHOUSE_ITEM_LIST が来て Guild_storage_list_on_warehouse_msg が描き直す
    party.RequestLoadInventory(PARTY_GUILD)
    Guild_storage_list_load_link()
    Guild_storage_list_read_storage()
    Guild_storage_list_build_rows()
end

-- 見出し。列の位置は Guild_storage_list_build_rows と揃える。
-- key のある列は押すと並べ替える(昇順 → 降順 → 手動の並びへ戻る)。今の向きを ▲▼ で出す。
-- 素の送付窓の「チーム名」見出しも richtext に LBtnUpScp を付けて並べ替えている
function Guild_storage_list_build_header(header)
    local settings = g.guild_storage_list_settings
    local heads = {{8, Guild_storage_list_t("配る", "Use")}, {64, Guild_storage_list_t("アイテム", "Item"), "name"},
                   {318, Guild_storage_list_t("在庫", "Stock"), "stock"}, {384, Guild_storage_list_t("取置", "Keep")},
                   {440, Guild_storage_list_t("指定", "Set")}, {490, Guild_storage_list_t("1口", "Unit"), "per"},
                   {545, Guild_storage_list_t("残り", "Left"), "remain"}, {604, Guild_storage_list_t("並び", "Order")}}
    for i, h in ipairs(heads) do
        local t = header:CreateOrGetControl("richtext", "h" .. i, h[1], 4, 80, 20)
        AUTO_CAST(t)
        local key = h[3]
        local mark = ""
        if key and settings.sort_key == key then
            mark = settings.sort_desc == 1 and "{#FFD700}▼" or "{#FFD700}▲"
        end
        t:SetText("{ol}{s14}" .. h[2] .. mark)
        if key then
            t:EnableHitTest(1)
            t:SetEventScript(ui.LBUTTONUP, "Guild_storage_list_sort_click")
            t:SetEventScriptArgString(ui.LBUTTONUP, key)
            t:SetTextTooltip(Guild_storage_list_t("{ol}押すと並べ替え(昇順 → 降順 → 手動の並び)",
                "{ol}Click to sort (ascending → descending → manual order)"))
        elseif i == #heads then
            t:EnableHitTest(1)
            t:SetEventScript(ui.LBUTTONUP, "Guild_storage_list_sort_click")
            t:SetEventScriptArgString(ui.LBUTTONUP, "")
            t:SetText("{ol}{s14}" .. h[2] .. (settings.sort_key == "" and "{#FFD700}●" or ""))
            t:SetTextTooltip(Guild_storage_list_t("{ol}押すと手動の並びに戻す。▲▼ で 1 つずつ動かせます",
                "{ol}Click to return to the manual order. Use ▲▼ to move items"))
        else
            t:EnableHitTest(0)
        end
    end
end

-- 並べ替えの値。nil は「値が無い」(配らないアイテムの 1人 / 残り)で、並べると後ろへ寄る。
function Guild_storage_list_sort_value(item, key)
    if key == "name" then
        return item.name
    elseif key == "stock" then
        return item.count
    end
    local rule = Guild_storage_list_rule(item.class_name)
    if rule.use ~= 1 then
        return nil
    end
    local per, _, remain = g.guild_storage_list_calc(item.count, Guild_storage_list_unit_count(), rule)
    if key == "per" then
        return per
    end
    return remain
end

-- 今の設定で並べた全アイテム
function Guild_storage_list_sorted_items()
    local settings = g.guild_storage_list_settings
    return g.guild_storage_list_sorted(g.guild_storage_list.items, settings.order, settings.sort_key,
        settings.sort_desc == 1, Guild_storage_list_sort_value)
end

function Guild_storage_list_sort_click(parent, ctrl, key)
    Guild_storage_list_commit_edits()
    local settings = g.guild_storage_list_settings
    if key == "" or (settings.sort_key == key and settings.sort_desc == 1) then
        settings.sort_key = ""
        settings.sort_desc = 0
    elseif settings.sort_key == key then
        settings.sort_desc = 1
    else
        settings.sort_key = key
        settings.sort_desc = 0
    end
    Guild_storage_list_save_settings()
    Guild_storage_list_refresh_header()
    Guild_storage_list_build_rows()
end

function Guild_storage_list_refresh_header()
    local frame = ui.GetFrame(addon_name_lower .. g.guild_storage_list_const.frame)
    local header = frame and GET_CHILD_RECURSIVELY(frame, "header")
    if header then
        Guild_storage_list_build_header(header)
    end
end

-- ▲▼。見出しで並べ替えている最中に押したら、**今の見た目の並びを手動の並びとして取り込んでから**
-- 動かす(並べ替えた結果を土台に微調整できるように)。以後は手動の並びになる。
function Guild_storage_list_move_click(parent, ctrl, class_name, delta)
    Guild_storage_list_commit_edits()
    local settings = g.guild_storage_list_settings
    local full, visible, present = {}, {}, {}
    local only_use = settings.only_use == 1
    for _, item in ipairs(Guild_storage_list_sorted_items()) do
        full[#full + 1] = item.class_name
        present[item.class_name] = true
        if not only_use or Guild_storage_list_rule(item.class_name).use == 1 then
            visible[#visible + 1] = item.class_name
        end
    end
    -- 今は保管庫に無いアイテムの位置も覚えておく(次に入ったとき同じ場所へ出す)
    for _, name in ipairs(settings.order) do
        if not present[name] then
            full[#full + 1] = name
            present[name] = true
        end
    end
    local moved = g.guild_storage_list_move(full, visible, class_name, delta)
    if not moved then
        return
    end
    settings.order = moved
    settings.sort_key = ""
    settings.sort_desc = 0
    Guild_storage_list_save_settings()
    Guild_storage_list_refresh_header()
    Guild_storage_list_build_rows(true)
end

-- 取り置きの送り先の Enter。保存するだけで、窓は作り直さない(docs/UI_RULES.md「入力欄の Enter で一覧を作り直さない」)
function Guild_storage_list_reserve_to_enter(parent, ctrl)
    local chat = ui.GetFrame("chat")
    g.guild_storage_list.chat_was_open = chat ~= nil and chat:IsVisible() == 1
    ReserveScript("Guild_storage_list_after_enter()", 0.05)
    Guild_storage_list_commit_reserve_to()
    local to = g.guild_storage_list_settings.reserve_to
    ui.SysMsg(to == "" and
                  Guild_storage_list_t("取り置きの送り先を空にしました(送付窓で選びます)",
            "Cleared the kept-items recipient (choose in the send window)") or
                  string.format(Guild_storage_list_t("取り置きの送り先を「%s」にしました", "Kept items go to \"%s\""), to))
end

-- 送り先の入力欄の値を設定へ取り込む(Enter を押さずに閉じたときも拾う)
function Guild_storage_list_commit_reserve_to()
    local frame = ui.GetFrame(addon_name_lower .. g.guild_storage_list_const.frame)
    local edit = frame and GET_CHILD_RECURSIVELY(frame, "reserve_to")
    if not edit or not g.guild_storage_list_settings then
        return
    end
    local to = g.guild_storage_list_norm(edit:GetText())
    if to ~= g.guild_storage_list_settings.reserve_to then
        g.guild_storage_list_settings.reserve_to = to
        Guild_storage_list_save_settings()
        g.vlog("guild_storage_list: 取り置きの送り先 = %s", to)
    end
end

function Guild_storage_list_toggle_verbose(parent, ctrl)
    g.settings.verbose_log = ctrl:IsChecked() == 1 and 1 or 0
    g.save_core_settings()
    g.vlog("guild_storage_list: 詳細ログを ON にした v%s", tostring(g.ver))
end

function Guild_storage_list_close()
    Guild_storage_list_commit_reserve_to()
    Guild_storage_list_commit_edits()
    Guild_storage_list_save_settings()
    ui.DestroyFrame(addon_name_lower .. g.guild_storage_list_const.frame)
    -- 対象者の窓も一緒に畳む。一覧の窓を破棄する経路は全部で 2 か所
    -- (ここと guild_storage_list_on_init の OFF のとき)。どちらでも畳むこと
    ui.DestroyFrame(addon_name_lower .. g.guild_storage_list_const.frame .. "_members")
end

function Guild_storage_list_reload()
    Guild_storage_list_commit_edits()
    party.RequestLoadInventory(PARTY_GUILD)
    Guild_storage_list_load_link()
    Guild_storage_list_read_storage()
    Guild_storage_list_build_rows()
    Guild_storage_list_members_refresh()
end

function Guild_storage_list_toggle_only(parent, ctrl)
    Guild_storage_list_commit_edits()
    g.guild_storage_list_settings.only_use = ctrl:IsChecked()
    Guild_storage_list_save_settings()
    Guild_storage_list_build_rows()
end

function Guild_storage_list_update_info(frame)
    local info = GET_CHILD_RECURSIVELY(frame, "info")
    local warn = GET_CHILD_RECURSIVELY(frame, "warn")
    local link = g.guild_storage_list.link
    if not link then
        info:SetText(Guild_storage_list_t("{ol}{#FF6347}出席データがありません", "{ol}{#FF6347}No attendance data"))
        warn:SetText(Guild_storage_list_t(
            "{ol}{s14}スプレッドシートの「アドオン連携」のセルを、下の「出席データ」に貼って Enter を押してください",
            "{ol}{s14}Paste the cell from the sheet into the Attendance field below and press Enter"))
        return
    end
    if #link.weeks == 0 then
        info:SetText(string.format(Guild_storage_list_t("{ol}まだ配っていない週はありません(ID %s)",
            "{ol}No undistributed weeks (ID %s)"), link.id))
    else
        info:SetText(string.format(Guild_storage_list_t("{ol}配布対象 %d 人 / %d 口(%s の %d 週分 / ID %s)",
            "{ol}%d people / %d units (%s, %d weeks / ID %s)"), #g.guild_storage_list.matched,
            Guild_storage_list_unit_count(), table.concat(link.weeks, "・"), #link.weeks, link.id))
    end
    local unmatched = g.guild_storage_list.unmatched
    if #unmatched > 0 then
        warn:SetText(string.format(Guild_storage_list_t("{ol}{#FF6347}ギルドに見つからない(送られない): %s",
            "{ol}{#FF6347}Not in the guild (will not receive): %s"), table.concat(unmatched, ", ")))
    else
        warn:SetText("")
    end
end

-- keep_scroll … 描き直した後もスクロール位置を保つ(行の中の操作で一覧の先頭へ飛ばないように)
function Guild_storage_list_build_rows(keep_scroll)
    local c = g.guild_storage_list_const
    local frame = ui.GetFrame(addon_name_lower .. c.frame)
    if not frame then
        return
    end
    Guild_storage_list_update_info(frame)
    local list = GET_CHILD_RECURSIVELY(frame, "list")
    if not list then
        return
    end
    local scroll = keep_scroll and g.scroll_cur_pos(list) or 0
    list:RemoveAllChild()
    local count = Guild_storage_list_unit_count()
    local only_use = g.guild_storage_list_settings.only_use == 1
    local visible = {}
    for _, item in ipairs(Guild_storage_list_sorted_items()) do
        if not only_use or Guild_storage_list_rule(item.class_name).use == 1 then
            visible[#visible + 1] = item
        end
    end
    local y = 0
    local shown = 0
    for i, item in ipairs(visible) do
        local rule = Guild_storage_list_rule(item.class_name)
        do
            shown = shown + 1
            local row = list:CreateOrGetControl("groupbox", "row_" .. i, 0, y, c.width - 40, c.row_height)
            AUTO_CAST(row)
            row:SetSkinName(shown % 2 == 0 and "chat_window" or "None")
            row:SetUserValue("CLASS_NAME", item.class_name)

            local chk = row:CreateOrGetControl("checkbox", "use", 6, 3, 24, 24)
            AUTO_CAST(chk)
            chk:SetCheck(rule.use == 1 and 1 or 0)
            chk:SetEventScript(ui.LBUTTONUP, "Guild_storage_list_toggle_use")
            chk:SetEventScriptArgString(ui.LBUTTONUP, item.class_name)

            local pic = row:CreateOrGetControl("picture", "icon", 36, 3, 24, 24)
            AUTO_CAST(pic)
            pic:SetImage(item.icon)
            pic:SetEnableStretch(1)
            pic:EnableHitTest(0)

            local name = row:CreateOrGetControl("richtext", "name", 62, 6, 250, 20)
            AUTO_CAST(name)
            name:SetText("{ol}{s14}" .. item.name)
            -- 長い名前(製造書など)が在庫の列へはみ出さないよう、幅に収まる大きさまで縮める
            name:AdjustFontSizeByWidth(250)
            name:SetTextTooltip("{ol}" .. item.name)

            local stock = row:CreateOrGetControl("richtext", "stock", 318, 6, 60, 20)
            AUTO_CAST(stock)
            stock:SetText("{ol}" .. item.count)

            local reserve = row:CreateOrGetControl("edit", "reserve", 374, 2, 52, 26)
            AUTO_CAST(reserve)
            reserve:SetFontName("white_16_ol")
            reserve:SetTextAlign("center", "center")
            reserve:SetNumberMode(1)
            reserve:SetText(tostring(rule.reserve))
            reserve:SetEventScript(ui.ENTERKEY, "Guild_storage_list_edit_enter")
            reserve:SetTextTooltip(Guild_storage_list_t("{ol}配らずに残す数(食堂など)。Enter で反映",
                "{ol}Amount to keep (not distributed). Press Enter"))

            -- 指定。空なら均等割り。入れたら 1 口あたりその数ちょうど(在庫が足りなければ赤字で配らない)
            local amount = row:CreateOrGetControl("edit", "amount", 434, 2, 46, 26)
            AUTO_CAST(amount)
            amount:SetFontName("white_16_ol")
            amount:SetTextAlign("center", "center")
            amount:SetNumberMode(1)
            amount:SetText((tonumber(rule.amount) or 0) > 0 and tostring(rule.amount) or "")
            amount:SetEventScript(ui.ENTERKEY, "Guild_storage_list_edit_enter")
            amount:SetTextTooltip(Guild_storage_list_t(
                "{ol}1 口(出席 1 週)あたりに配る数。空なら在庫を均等に割ります{nl}在庫が足りないときは赤字になり、配りません。Enter で反映",
                "{ol}Amount per unit (one attended week). Empty = split the stock evenly{nl}Shown in red and skipped when the stock is short. Press Enter"))

            local per_text = row:CreateOrGetControl("richtext", "per", 490, 6, 50, 20)
            AUTO_CAST(per_text)
            local remain_text = row:CreateOrGetControl("richtext", "remain", 545, 6, 50, 20)
            AUTO_CAST(remain_text)
            Guild_storage_list_set_row_values(per_text, remain_text, item.count, count, rule)

            -- ▲▼。押せない端は灰色にして、押しても何も起きないことを見せる(another_warehouse と同じ)
            local moves = {{"up", 600, -1, i > 1, "▲", Guild_storage_list_t("{ol}1 つ前へ", "{ol}Move up")},
                           {"down", 628, 1, i < #visible, "▼", Guild_storage_list_t("{ol}1 つ後ろへ", "{ol}Move down")}}
            for _, m in ipairs(moves) do
                local btn = row:CreateOrGetControl("button", m[1], m[2], 2, 26, 26)
                AUTO_CAST(btn)
                btn:SetSkinName("None")
                btn:SetTextAlign("center", "center")
                btn:SetText((m[4] and "{ol}{s18}{#FFFFFF}" or "{ol}{s18}{#555555}") .. m[5])
                if m[4] then
                    btn:SetTextTooltip(m[6])
                    btn:SetEventScript(ui.LBUTTONUP, "Guild_storage_list_move_click")
                    btn:SetEventScriptArgString(ui.LBUTTONUP, item.class_name)
                    btn:SetEventScriptArgNumber(ui.LBUTTONUP, m[3])
                end
            end

            y = y + c.row_height
        end
    end
    if shown == 0 then
        local empty = list:CreateOrGetControl("richtext", "empty", 10, 10, 400, 24)
        AUTO_CAST(empty)
        empty:SetText(#g.guild_storage_list.items == 0 and
                          Guild_storage_list_t("{ol}保管庫が空か、まだ読み込まれていません",
                "{ol}The storage is empty or not loaded yet") or
                          Guild_storage_list_t("{ol}配るものがありません(左のチェックで選びます)",
                "{ol}Nothing to distribute (tick the box on the left)"))
    end
    -- 作り直した中身で範囲を測り直してから戻す(逆だと先頭に貼り付く。g.scroll_cur_pos のコメント)
    list:InvalidateScrollBar()
    list:SetScrollPos(scroll)
end

-- 入力欄の値を設定へ取り込む。Enter を押さずに閉じた / 書き出した分も拾うため、
-- 描き直す前と書き出す前に必ず通す。
function Guild_storage_list_commit_edits()
    local frame = ui.GetFrame(addon_name_lower .. g.guild_storage_list_const.frame)
    if not frame or not g.guild_storage_list_settings then
        return
    end
    local list = GET_CHILD_RECURSIVELY(frame, "list")
    if not list then
        return
    end
    for i = 0, list:GetChildCount() - 1 do
        local row = list:GetChildByIndex(i)
        local class_name = row and row:GetUserValue("CLASS_NAME")
        if class_name and class_name ~= "None" and class_name ~= "" then
            local reserve = GET_CHILD(row, "reserve")
            local amount = GET_CHILD(row, "amount")
            local reserve_value = reserve and tonumber(g.guild_storage_list_norm(reserve:GetText()))
            reserve_value = reserve_value and reserve_value >= 0 and math.floor(reserve_value) or nil
            -- 指定は空欄 = 0(均等割り)。数字以外は取り込まない
            local amount_value
            if amount then
                local text = g.guild_storage_list_norm(amount:GetText())
                amount_value = text == "" and 0 or tonumber(text)
                amount_value = amount_value and amount_value >= 0 and math.floor(amount_value) or nil
            end
            local rule = Guild_storage_list_rule(class_name)
            if (reserve_value and reserve_value ~= rule.reserve) or
                (amount_value and amount_value ~= (tonumber(rule.amount) or 0)) then
                rule = Guild_storage_list_rule(class_name, true)
                rule.reserve = reserve_value or rule.reserve
                rule.amount = amount_value or tonumber(rule.amount) or 0
                -- 廃止した「単位」の値は捨てる
                rule.step = nil
            end
        end
    end
end

-- 取置・指定の Enter。
--
-- **Enter の最中に一覧を作り直さないこと。** 以前はここで Guild_storage_list_build_rows を呼んでいて、
-- 押した入力欄そのものを RemoveAllChild で消していた。入力欄が消えると Enter の行き先が無くなり、
-- ゲーム側の「Enter でチャット入力欄を出す」まで届いてしまう(実機で発生)。
-- そこで、この行の「1人」「残り」だけをその場で書き換える。並び順が変わりうる列(1人 / 残り)で
-- 並べ替えているときだけ、Enter が済んだ後で作り直す。
-- 念のため、この Enter でチャット入力欄が開いてしまったら閉じる(前から開いていたものは触らない)。
function Guild_storage_list_edit_enter(parent, ctrl)
    local chat = ui.GetFrame("chat")
    g.guild_storage_list.chat_was_open = chat ~= nil and chat:IsVisible() == 1
    Guild_storage_list_commit_edits()
    Guild_storage_list_save_settings()
    -- 行は ctrl の親から取る(イベントの第 1 引数が行とは限らない。行でないと書き換えが空振りする)
    local row = ctrl and ctrl:GetParent()
    local updated = Guild_storage_list_update_row(row)
    g.vlog("guild_storage_list: Enter row=%s class=%s 書き換え=%s", row and tostring(row:GetName()) or "nil",
        row and tostring(row:GetUserValue("CLASS_NAME")) or "nil", tostring(updated))
    local key = g.guild_storage_list_settings.sort_key
    if not updated or key == "per" or key == "remain" then
        -- Enter が済んでから作り直す(Enter の最中に入力欄を消さない)
        ReserveScript("Guild_storage_list_build_rows(true)", 0.1)
    end
    ReserveScript("Guild_storage_list_after_enter()", 0.05)
end

-- 出席データ欄の Enter。連携文字列を読んで link.txt に保存し、一覧を描き直す。
-- **一覧の作り直しは Enter が済んでから**(docs/UI_RULES.md「入力欄の Enter で一覧を作り直さない」)
function Guild_storage_list_paste_enter(parent, ctrl)
    local chat = ui.GetFrame("chat")
    g.guild_storage_list.chat_was_open = chat ~= nil and chat:IsVisible() == 1
    ReserveScript("Guild_storage_list_after_enter()", 0.05)
    local text = g.guild_storage_list_norm(ctrl:GetText())
    local link, err = g.guild_storage_list_parse_link(text)
    g.vlog("guild_storage_list: 出席データ %d バイト 読めた=%s (%s)", #text, tostring(link ~= nil), tostring(err))
    if not link then
        ui.SysMsg(Guild_storage_list_t(
            "{#FF6347}出席データを読めませんでした。スプレッドシートの「アドオン連携」のセルをそのまま貼ってください",
            "{#FF6347}Could not read the attendance data. Paste the cell from the sheet as is"))
        return
    end
    if not Guild_storage_list_write_file(Guild_storage_list_link_path(), text) then
        ui.SysMsg(Guild_storage_list_t("書き出せませんでした: ", "Could not write: ") .. Guild_storage_list_link_path())
        return
    end
    Guild_storage_list_load_link()
    ui.SysMsg(string.format(Guild_storage_list_t("出席データを読み込みました(%d 週分 / ギルドで見つかった %d 人 / %d 口)",
        "Loaded the attendance data (%d weeks / %d people / %d units)"), #link.weeks, #g.guild_storage_list.matched,
        Guild_storage_list_unit_count()))
    ReserveScript("Guild_storage_list_build_rows(true)", 0.1)
    ReserveScript("Guild_storage_list_members_refresh()", 0.1)
end

function Guild_storage_list_after_enter()
    local chat = ui.GetFrame("chat")
    local open = chat ~= nil and chat:IsVisible() == 1
    g.vlog("guild_storage_list: Enter の後のチャット入力欄 前=%s 後=%s", tostring(g.guild_storage_list.chat_was_open),
        tostring(open))
    if open and not g.guild_storage_list.chat_was_open then
        ui.CloseFrame("chat")
    end
end

-- 1 行ぶんの「1人」「残り」を、作り直さずに書き換える。書き換えられたら true
function Guild_storage_list_update_row(row)
    local class_name = row and row:GetUserValue("CLASS_NAME")
    if not class_name or class_name == "None" or class_name == "" then
        return false
    end
    local per_text = GET_CHILD(row, "per")
    local remain_text = GET_CHILD(row, "remain")
    if not per_text or not remain_text then
        return false
    end
    Guild_storage_list_set_row_values(per_text, remain_text, g.guild_storage_list.stock[class_name] or 0,
        Guild_storage_list_unit_count(), Guild_storage_list_rule(class_name))
    return true
end

-- 行の「1人」「残り」の表示。配らないものは「-」、在庫不足(指定 × 人数 > 在庫 - 取置)は赤字
function Guild_storage_list_set_row_values(per_text, remain_text, stock, count, rule)
    if rule.use ~= 1 then
        per_text:SetText("{ol}{#808080}-")
        remain_text:SetText("{ol}{#808080}-")
        per_text:SetTextTooltip("")
        return
    end
    local per, _, remain, short = g.guild_storage_list_calc(stock, count, rule)
    if short then
        per_text:SetText("{ol}{#FF6347}" .. per)
        remain_text:SetText("{ol}{#FF6347}" .. remain)
        per_text:SetTextTooltip(Guild_storage_list_t("{ol}在庫が足りないので配りません",
            "{ol}Not enough stock, will not be distributed"))
    else
        per_text:SetText("{ol}{#FFD700}" .. per)
        remain_text:SetText("{ol}" .. remain)
        per_text:SetTextTooltip("")
    end
end

function Guild_storage_list_toggle_use(parent, ctrl, class_name)
    Guild_storage_list_commit_edits()
    local rule = Guild_storage_list_rule(class_name, true)
    rule.use = ctrl:IsChecked() == 1 and 1 or 0
    Guild_storage_list_save_settings()
    Guild_storage_list_build_rows(true)
end

-- ===== 書き出し =====

-- フォルダは連携文字列を貼ったときに作っていることが多いので、まず書いてみる。
-- 無かったときだけ作る(g.create_folder は os.execute でコンソール窓が一瞬出るため)。
function Guild_storage_list_write_file(path, text)
    local file = io.open(path, "w")
    if not file then
        local dir = Guild_storage_list_io_dir()
        g.create_folder(dir, dir .. "/mkdir.txt")
        file = io.open(path, "w")
    end
    if not file then
        return false
    end
    file:write(text)
    file:close()
    return true
end

-- 「配布記録を作る」。配るもの(配る ON・在庫が足りる・1 口 1 個以上)の 1 口あたりの個数と、
-- ギルドに見つからず送らなかった人を 1 行にまとめて「配布記録」欄と record.txt に出す。
-- あわせて在庫を stock.tsv に書く(シートの K:L 列へ貼れる形)
function Guild_storage_list_export()
    Guild_storage_list_commit_edits()
    Guild_storage_list_save_settings()
    local link = g.guild_storage_list.link
    if not link then
        ui.SysMsg(Guild_storage_list_t("出席データを貼ってから押してください", "Paste the attendance data first"))
        return
    end
    local dir = Guild_storage_list_io_dir()
    local units = Guild_storage_list_unit_count()
    local items = Guild_storage_list_sorted_items()
    local stock_lines = {"在庫\tアイテム"}
    for _, item in ipairs(items) do
        stock_lines[#stock_lines + 1] = string.format("%d\t%s", item.count, item.name)
    end
    local d = g.guild_storage_list.dist
    local rows, short_names = g.guild_storage_list_record_rows(items, Guild_storage_list_rule, function(item)
        local per, _, _, short = g.guild_storage_list_calc(item.count, units, Guild_storage_list_rule(item.class_name))
        return per, short
    end, d.sent, d.sent_order)
    -- 在庫不足で外したものは、記録に載らないことを知らせる(黙って消えると気付けない)
    if #short_names > 0 then
        ui.SysMsg(Guild_storage_list_t("{#FF6347}在庫が足りないので配布記録から外しました: ",
            "{#FF6347}Left out of the record (not enough stock): ") .. table.concat(short_names, ", "))
    end
    local text = g.guild_storage_list_record(link.id, rows, g.guild_storage_list.unmatched)
    local frame = ui.GetFrame(addon_name_lower .. g.guild_storage_list_const.frame)
    local record = frame and GET_CHILD_RECURSIVELY(frame, "record")
    if record then
        record:SetText(text)
    end
    local ok_record = Guild_storage_list_write_file(dir .. "/record.txt", text)
    local ok_stock = Guild_storage_list_write_file(dir .. "/stock.tsv", table.concat(stock_lines, "\n") .. "\n")
    g.vlog("guild_storage_list: 配布記録 %s record=%s stock=%s 配る %d 品 / %d 口 (%d 文字)", link.id,
        tostring(ok_record), tostring(ok_stock), #rows, units, #text)
    ui.SysMsg(string.format(Guild_storage_list_t(
        "配布記録を作りました(%d 品)。配り終わったら「配布記録」欄をマウスでなぞって Ctrl+C し、Discord の /配布記録 に貼ってください",
        "Made the record (%d items). After distributing, copy the Record field and paste it into /distribute-record"),
        #rows))
end

-- ===== 素の送付窓への事前入力 =====

function Guild_storage_list_prefill(item_class_name, item_count)
    if not g.guild_storage_list_settings then
        Guild_storage_list_load_settings()
    end
    local d = g.guild_storage_list.dist
    d.opened = nil
    d.opened_mode = nil
    -- 「取り置きを配布する」の途中で、そのアイテムの窓なら取り置きの入力をする
    if d.active and d.mode == "reserve" and d.queue[d.index] == item_class_name then
        Guild_storage_list_prefill_reserve(item_class_name, item_count)
        return
    end
    local rule = Guild_storage_list_rule(item_class_name)
    if rule.use ~= 1 then
        return
    end
    -- この回で送ったアイテムを開き直したときは入れない。入れると、送った後の残りを人数で
    -- 割り直した数が入り、続けて送ると二重に配ることになる
    if g.guild_storage_list.dist.sent[item_class_name] then
        ui.SysMsg(Guild_storage_list_t(
            "Guild Storage List: {#FF6347}このアイテムは配布済みなので入力しませんでした{/}(もう一度配るときは「配布を始める」から)",
            "Guild Storage List: {#FF6347}Already distributed, nothing was filled in{/} (press Start to distribute again)"))
        return
    end
    -- 送る直前の状態で照合し直す(一覧を開いた後にメンバーが増減していることがある)
    if not Guild_storage_list_load_link() then
        ui.SysMsg(Guild_storage_list_t("Guild Storage List: 出席データが無いので入力しませんでした",
            "Guild Storage List: no attendance data, nothing was filled in"))
        return
    end
    local count = Guild_storage_list_unit_count()
    -- 1 口あたりは保管庫全体の在庫で決める(一覧・配布記録と同じ数にするため)。
    -- 同じアイテムが複数の枠に分かれていると、この窓の枠だけでは足りないことがある。
    -- 直前に別のアイテムを送っているので、在庫は読み直す(手元の控えは古い)
    Guild_storage_list_read_storage()
    local stock = g.guild_storage_list.stock[item_class_name] or item_count
    local per, total, _, short = g.guild_storage_list_calc(stock, count, rule)
    if short then
        ui.SysMsg(string.format(Guild_storage_list_t(
            "Guild Storage List: {#FF6347}在庫が足りないので入力しませんでした{/}(%d 個 × %d 口 = %d / 在庫 %d)",
            "Guild Storage List: {#FF6347}Not enough stock, nothing was filled in{/} (%d x %d = %d / stock %d)"), per,
            count, total, stock))
        return
    end
    if per <= 0 then
        ui.SysMsg(Guild_storage_list_t("Guild Storage List: 1 口あたり 0 個なので入力しませんでした",
            "Guild Storage List: 0 per person, nothing was filled in"))
        return
    end
    local frame = ui.GetFrame("guildinven_send")
    local list_box = frame and GET_CHILD_RECURSIVELY(frame, "listBox")
    if not list_box then
        return
    end
    -- 名前 → 口数。1 人に入れる数は 1 口あたり × 口数
    local targets = {}
    for _, m in ipairs(g.guild_storage_list.matched) do
        targets[m.name] = m.units
    end
    local all_check = GET_CHILD_RECURSIVELY(frame, "allMemberCheck")
    if all_check then
        all_check:SetCheck(0)
    end
    local filled, filled_total = 0, 0
    for i = 0, list_box:GetChildCount() - 1 do
        local child = list_box:GetChildByIndex(i)
        if child and string.find(child:GetName(), "ITEMSEND_", 1, true) then
            local name_text = GET_CHILD(child, "nameText")
            local send_check = GET_CHILD(child, "sendCheck")
            local count_edit = GET_CHILD_RECURSIVELY(child, "countEdit")
            local name = name_text and g.guild_storage_list_norm(name_text:GetText()) or ""
            if send_check and count_edit then
                if targets[name] then
                    send_check:SetCheck(1)
                    count_edit:SetText(tostring(per * targets[name]))
                    filled = filled + 1
                    filled_total = filled_total + per * targets[name]
                else
                    send_check:SetCheck(0)
                    count_edit:SetText("")
                end
            end
        end
    end
    GUILDINVEN_SEND_UPDATE_COUNT_BOX(frame)
    -- 送るボタンの後で「事前入力したアイテムを送った」と判断するための印
    g.guild_storage_list.dist.opened = item_class_name
    g.guild_storage_list.dist.opened_mode = "units"
    g.guild_storage_list.dist.opened_per = per
    -- 名前もここで控える(送り切ると保管庫の一覧から消え、後から名前を引けなくなる)
    g.guild_storage_list.dist.opened_name = Guild_storage_list_item_name(item_class_name)
    g.vlog("guild_storage_list: 事前入力 %s 1口 %d 個 / 入力 %d 人 計 %d / 照合 %d 人 %d 口 / 在庫 %d (この枠 %d)",
        item_class_name, per, filled, filled_total, #g.guild_storage_list.matched, count, stock, item_count)
    local msg = string.format(Guild_storage_list_t("Guild Storage List: %d 人に入力しました(1 口 %d 個 × 口数、計 %d)",
        "Guild Storage List: filled in for %d people (%d per unit, total %d)"), filled, per, filled_total)
    if filled ~= #g.guild_storage_list.matched then
        msg = msg .. string.format(Guild_storage_list_t(" {#FF6347}送付窓に見つからない人が %d 人います",
            " {#FF6347}%d recipients are missing from the send window"), #g.guild_storage_list.matched - filled)
    end
    if filled_total > item_count then
        msg = msg .. Guild_storage_list_t(" {#FF6347}この枠の個数では足りません", " {#FF6347}Not enough in this slot")
    end
    ui.SysMsg(msg)
end

-- ===== 順に配る =====
--
-- 「配布を始める」で、配るアイテム(配る ON かつ 1 口あたり 1 個以上)を一覧の並びで順に、
-- 素の送付窓で開いていく。窓は保管庫の枠を押したときと同じ素の経路(GUILDINFO_INVEN_ITEM_CLICK。
-- ギルド長か権限の確認込み)で開き、事前入力は GUILDINVEN_SEND_INIT のフックが行う。
-- **送るボタンは利用者が押す。** 押して送れたら(GUILDINVEN_SEND_CLICK の後に窓が閉じていたら)
-- 次のアイテムの窓を開く。窓を × で閉じたときは止まり、「配布を続ける」で同じアイテムから再開する。

-- 配る順の ClassName の並び。rule_of(class_name) はルール、per_of(item) は 1 口あたりの個数を返す。
function g.guild_storage_list_dist_queue(items, rule_of, per_of)
    local queue = {}
    for _, item in ipairs(items) do
        if rule_of(item.class_name).use == 1 and per_of(item) > 0 then
            queue[#queue + 1] = item.class_name
        end
    end
    return queue
end

-- ギルド情報の「保管箱」タブを開いているか
function Guild_storage_list_storage_tab_open()
    local guildinfo = ui.GetFrame("guildinfo")
    if not guildinfo or guildinfo:IsVisible() ~= 1 then
        return false
    end
    local tab = GET_CHILD_RECURSIVELY(guildinfo, "maintab")
    if not tab then
        return false
    end
    AUTO_CAST(tab)
    return tab:GetSelectItemName() == "inventorytab"
end

function Guild_storage_list_item_name(class_name)
    for _, item in ipairs(g.guild_storage_list.items) do
        if item.class_name == class_name then
            return item.name
        end
    end
    return tostring(class_name)
end

-- 一覧の窓のボタンと状態の表示。RunUpdateScript から 0.5 秒ごとにも呼ばれる(1 を返すと続く)。
-- 保管箱タブの開閉にはメッセージが無いので、押せるかどうかはこれで追う
function Guild_storage_list_dist_update(frame)
    local btn = GET_CHILD(frame, "dist")
    local status = GET_CHILD(frame, "dist_status")
    if not btn or not status then
        return 0
    end
    local d = g.guild_storage_list.dist
    local can = Guild_storage_list_storage_tab_open()
    local units_active = d.active and d.mode == "units"
    local reserve_active = d.active and d.mode == "reserve"
    if units_active then
        btn:SetText("{@st41b}{s16}" ..
                        string.format(Guild_storage_list_t("配布を続ける %d/%d", "Continue %d/%d"), d.index, #d.queue))
        status:SetText(string.format(Guild_storage_list_t("{ol}{#FFD700}配布中 %d/%d: %s",
            "{ol}{#FFD700}Distributing %d/%d: %s"), d.index, #d.queue, Guild_storage_list_item_name(d.queue[d.index])))
    elseif reserve_active then
        btn:SetText("{@st41b}{s16}" .. Guild_storage_list_t("配布を始める", "Start"))
        status:SetText(string.format(Guild_storage_list_t("{ol}{#FFD700}取り置き配布中 %d/%d: %s",
            "{ol}{#FFD700}Sending kept items %d/%d: %s"), d.index, #d.queue,
            Guild_storage_list_item_name(d.queue[d.index])))
    else
        btn:SetText("{@st41b}{s16}" .. Guild_storage_list_t("配布を始める", "Start"))
        status:SetText("")
    end
    btn:SetEnable(can and 1 or 0)
    local reserve = GET_CHILD(frame, "reserve")
    if reserve then
        reserve:SetText("{@st41b}{s16}" .. (reserve_active and
                            string.format(Guild_storage_list_t("取り置きを続ける %d/%d", "Continue kept %d/%d"),
                d.index, #d.queue) or Guild_storage_list_t("取り置きを配布する", "Send kept items")))
        reserve:SetEnable(can and 1 or 0)
        reserve:SetTextTooltip(can and Guild_storage_list_t(
            "{ol}「取置」を入れたアイテムの送付窓を順に開き、全員の個数に取り置きの数を入れます{nl}送る人に 1 人だけチェックを入れて送ってください",
            "{ol}Opens the send window for each item with a Keep amount and fills that amount for everyone{nl}Tick only the one person to send to") or
                                   Guild_storage_list_t("{ol}ギルド情報の「保管箱」タブを開くと押せます",
                "{ol}Open the Storage tab of the guild info to use this"))
    end
    btn:SetTextTooltip(can and Guild_storage_list_t(
        "{ol}配るアイテムの送付窓を、一覧の並びで順に開きます{nl}送るボタンを押すと次のアイテムが開きます",
        "{ol}Opens the send window for each item in list order{nl}Press Send to move on to the next item") or
                           Guild_storage_list_t("{ol}ギルド情報の「保管箱」タブを開くと押せます",
            "{ol}Open the Storage tab of the guild info to use this"))
    return 1
end

function Guild_storage_list_dist_refresh()
    local frame = ui.GetFrame(addon_name_lower .. g.guild_storage_list_const.frame)
    if frame then
        Guild_storage_list_dist_update(frame)
    end
end

function Guild_storage_list_dist_click()
    if not Guild_storage_list_storage_tab_open() then
        ui.SysMsg(Guild_storage_list_t("ギルド情報の「保管箱」タブを開いてから押してください",
            "Open the Storage tab of the guild info first"))
        return
    end
    local d = g.guild_storage_list.dist
    if not d.active then
        Guild_storage_list_commit_edits()
        Guild_storage_list_save_settings()
        if not Guild_storage_list_load_link() then
            ui.SysMsg(Guild_storage_list_t("出席データを貼ってから押してください",
                "Paste the attendance data first"))
            return
        end
        Guild_storage_list_read_storage()
        local count = Guild_storage_list_unit_count()
        local queue = g.guild_storage_list_dist_queue(Guild_storage_list_sorted_items(), Guild_storage_list_rule,
            function(item)
                return g.guild_storage_list_sendable(item.count, count, Guild_storage_list_rule(item.class_name))
            end)
        if #queue == 0 then
            ui.SysMsg(Guild_storage_list_t("配るものがありません(1 口あたり 1 個以上のものだけ配ります)",
                "Nothing to distribute (only items with 1 or more per person)"))
            return
        end
        d.active = true
        d.queue = queue
        d.index = 1
        d.opened = nil
        d.sent = {}
        d.sent_order = {}
        g.vlog("guild_storage_list: 配布を始める %d 品 / %d 人 (%s)", #queue, count, table.concat(queue, ","))
    end
    Guild_storage_list_dist_open_current()
end

-- 保管庫の枠から、そのアイテムが入っている枠を探す(複数あれば一番多い枠)。
-- 素は枠を空にするとき ClearIconAll するだけで ITEM_CLASS_NAME の値は残るので、アイコンの有無も見る
function Guild_storage_list_find_slot(class_name)
    local guildinfo = ui.GetFrame("guildinfo")
    local slotset = guildinfo and GET_CHILD_RECURSIVELY(guildinfo, "itemSlotset")
    if not slotset then
        return nil
    end
    AUTO_CAST(slotset)
    local best, best_count
    for i = 0, slotset:GetSlotCount() - 1 do
        local slot = slotset:GetSlotByIndex(i)
        if slot and slot:GetIcon() and slot:GetUserValue("ITEM_CLASS_NAME") == class_name then
            local count = slot:GetUserIValue("ITEM_COUNT")
            if not best or count > best_count then
                best, best_count = slot, count
            end
        end
    end
    return best, slotset
end

function Guild_storage_list_dist_open_current()
    local d = g.guild_storage_list.dist
    while d.active do
        local class_name = d.queue[d.index]
        if not class_name then
            Guild_storage_list_dist_finish()
            return
        end
        if not Guild_storage_list_storage_tab_open() then
            ui.SysMsg(Guild_storage_list_t("ギルド情報の「保管箱」タブを開いてから「配布を続ける」を押してください",
                "Open the Storage tab of the guild info, then press Continue"))
            Guild_storage_list_dist_refresh()
            return
        end
        local slot, slotset = Guild_storage_list_find_slot(class_name)
        if slot then
            g.vlog("guild_storage_list: 配布 %d/%d %s の送付窓を開く", d.index, #d.queue, class_name)
            -- 枠を押したときと同じ素の経路(ギルド長でなければ権限を確かめてから開く)
            GUILDINFO_INVEN_ITEM_CLICK(slotset, slot)
            Guild_storage_list_dist_refresh()
            return
        end
        ui.SysMsg(string.format(Guild_storage_list_t("保管庫に見つからないので飛ばします: %s",
            "Not found in the storage, skipped: %s"), Guild_storage_list_item_name(class_name)))
        d.index = d.index + 1
    end
end

-- 素の送るボタンの後。送れたときだけ次へ進む
function Guild_storage_list_dist_after_send()
    local frame = ui.GetFrame("guildinven_send")
    if frame and frame:IsVisible() == 1 then
        -- 素の確認(残数が足りない・コロニー報酬)で止まった。送っていない
        return
    end
    local d = g.guild_storage_list.dist
    local sent_class = d.opened
    local sent_mode = d.opened_mode
    d.opened = nil
    d.opened_mode = nil
    if not sent_class then
        return
    end
    if sent_mode == "reserve" then
        d.reserve_sent[sent_class] = true
    else
        d.sent[sent_class] = {
            name = d.opened_name or Guild_storage_list_item_name(sent_class),
            per = d.opened_per or 0
        }
        d.sent_order[#d.sent_order + 1] = sent_class
    end
    g.vlog("guild_storage_list: 送った %s (%s / 配布中=%s %s %d/%d)", sent_class, tostring(sent_mode), tostring(d.active),
        tostring(d.mode), d.index, #d.queue)
    if not d.active or d.mode ~= (sent_mode or "units") or d.queue[d.index] ~= sent_class then
        return
    end
    d.index = d.index + 1
    Guild_storage_list_dist_refresh()
    if d.queue[d.index] then
        -- 素が窓を閉じた直後(同じ呼び出しの中)なので、一呼吸おいてから次を開く
        ReserveScript("Guild_storage_list_dist_open_current()", 0.5)
    else
        Guild_storage_list_dist_finish()
    end
end

function Guild_storage_list_dist_finish()
    local d = g.guild_storage_list.dist
    local total = #d.queue
    local mode = d.mode
    d.active = false
    d.mode = "units"
    d.queue = {}
    d.index = 1
    if mode == "reserve" then
        ui.SysMsg(string.format(Guild_storage_list_t("Guild Storage List: 取り置きの配布が終わりました(%d 品)",
            "Guild Storage List: finished sending the kept items (%d items)"), total))
    else
        ui.SysMsg(string.format(Guild_storage_list_t(
            "Guild Storage List: 配布が終わりました(%d 品)。「配布記録を作る」から Discord の /配布記録 に貼ってください",
            "Guild Storage List: distribution finished (%d items). Make the record and paste it into /distribute-record"),
            total))
    end
    Guild_storage_list_dist_refresh()
end

-- ===== 取り置きを配布する =====
--
-- 「取置」を入れたアイテムを、一覧の並びで順に素の送付窓で開く。全員の行に取り置きの個数を入れ、
-- **チェックはすべて外したまま**にする(送る相手は利用者が 1 人選ぶ)。素の GUILDINVEN_SEND_CLICK は
-- チェックの入った行だけを送るので、1 人だけチェックすればその人に取り置きの数だけ送られる。
-- 送れたら次のアイテムへ進む流れは「配布を始める」と同じ(Guild_storage_list_dist_after_send)。

-- 取り置きを配る順の ClassName の並び。取置が 1 以上で、在庫がそれ以上あるもの
function g.guild_storage_list_reserve_queue(items, rule_of)
    local queue = {}
    for _, item in ipairs(items) do
        local reserve = math.floor(tonumber(rule_of(item.class_name).reserve) or 0)
        if reserve > 0 and (tonumber(item.count) or 0) >= reserve then
            queue[#queue + 1] = item.class_name
        end
    end
    return queue
end

function Guild_storage_list_reserve_click()
    if not Guild_storage_list_storage_tab_open() then
        ui.SysMsg(Guild_storage_list_t("ギルド情報の「保管箱」タブを開いてから押してください",
            "Open the Storage tab of the guild info first"))
        return
    end
    local d = g.guild_storage_list.dist
    if d.active and d.mode == "units" then
        ui.SysMsg(Guild_storage_list_t("配布の途中です。「配布を続ける」で終わらせてから押してください",
            "A distribution is in progress. Finish it with Continue first"))
        return
    end
    Guild_storage_list_commit_reserve_to()
    if not d.active then
        Guild_storage_list_commit_edits()
        Guild_storage_list_save_settings()
        Guild_storage_list_read_storage()
        local queue = g.guild_storage_list_reserve_queue(Guild_storage_list_sorted_items(), Guild_storage_list_rule)
        if #queue == 0 then
            ui.SysMsg(Guild_storage_list_t("取り置きを入れたアイテムがありません(取置が 1 以上で、在庫がそれ以上あるもの)",
                "No items with a Keep amount (Keep of 1 or more, with enough stock)"))
            return
        end
        d.active = true
        d.mode = "reserve"
        d.queue = queue
        d.index = 1
        d.opened = nil
        d.reserve_sent = {}
        g.vlog("guild_storage_list: 取り置きの配布を始める %d 品 (%s)", #queue, table.concat(queue, ","))
    end
    Guild_storage_list_dist_open_current()
end

-- 送付窓に取り置きの個数を入れる(チェックは入れない)
function Guild_storage_list_prefill_reserve(item_class_name, item_count)
    local d = g.guild_storage_list.dist
    if d.reserve_sent[item_class_name] then
        ui.SysMsg(Guild_storage_list_t(
            "Guild Storage List: {#FF6347}このアイテムの取り置きは送り済みなので入力しませんでした",
            "Guild Storage List: {#FF6347}The kept amount was already sent, nothing was filled in"))
        return
    end
    local reserve = math.floor(tonumber(Guild_storage_list_rule(item_class_name).reserve) or 0)
    local frame = ui.GetFrame("guildinven_send")
    local list_box = frame and GET_CHILD_RECURSIVELY(frame, "listBox")
    if reserve <= 0 or not list_box then
        return
    end
    local all_check = GET_CHILD_RECURSIVELY(frame, "allMemberCheck")
    if all_check then
        all_check:SetCheck(0)
    end
    -- 送り先が決めてあれば、その人の行だけにチェックと個数を入れる(大文字小文字の違いは吸収)。
    -- 決めていない / 送付窓に見つからないときは、全員の行に個数だけ入れてチェックは利用者に任せる
    local to = string.lower(g.guild_storage_list_settings.reserve_to or "")
    local to_found = false
    if to ~= "" then
        for i = 0, list_box:GetChildCount() - 1 do
            local child = list_box:GetChildByIndex(i)
            local name_text = child and string.find(child:GetName(), "ITEMSEND_", 1, true) and GET_CHILD(child, "nameText")
            if name_text and string.lower(g.guild_storage_list_norm(name_text:GetText())) == to then
                to_found = true
            end
        end
    end
    local rows = 0
    for i = 0, list_box:GetChildCount() - 1 do
        local child = list_box:GetChildByIndex(i)
        if child and string.find(child:GetName(), "ITEMSEND_", 1, true) then
            local name_text = GET_CHILD(child, "nameText")
            local send_check = GET_CHILD(child, "sendCheck")
            local count_edit = GET_CHILD_RECURSIVELY(child, "countEdit")
            if send_check and count_edit then
                local is_to = to_found and name_text and
                                  string.lower(g.guild_storage_list_norm(name_text:GetText())) == to
                send_check:SetCheck(is_to and 1 or 0)
                count_edit:SetText((not to_found or is_to) and tostring(reserve) or "")
                rows = rows + 1
            end
        end
    end
    GUILDINVEN_SEND_UPDATE_COUNT_BOX(frame)
    d.opened = item_class_name
    d.opened_mode = "reserve"
    g.vlog("guild_storage_list: 取り置きを入力 %s %d 個 / %d 行 / 送り先 %s 見つかった=%s (この枠 %d)", item_class_name,
        reserve, rows, to, tostring(to_found), item_count)
    local msg
    if to_found then
        msg = string.format(Guild_storage_list_t("Guild Storage List: 取り置き %d 個を「%s」に入れました。確かめて送ってください",
            "Guild Storage List: filled in the kept amount (%d) for \"%s\". Check and send"), reserve,
            g.guild_storage_list_settings.reserve_to)
    else
        msg = string.format(Guild_storage_list_t(
            "Guild Storage List: 取り置き %d 個を入れました。{#FFD700}送る人に 1 人だけチェックを入れて{/}送ってください",
            "Guild Storage List: filled in the kept amount (%d). {#FFD700}Tick only one person{/} and send"), reserve)
        if to ~= "" then
            msg = msg .. string.format(Guild_storage_list_t(" {#FF6347}送り先「%s」が送付窓に見つかりません",
                " {#FF6347}Recipient \"%s\" not found in the send window"), g.guild_storage_list_settings.reserve_to)
        end
    end
    if reserve > item_count then
        msg = msg .. Guild_storage_list_t(" {#FF6347}この枠の個数では足りません", " {#FF6347}Not enough in this slot")
    end
    ui.SysMsg(msg)
end

-- ===== 対象者の窓 =====
--
-- 貼った出席データの対象者を、口数の多い順に並べて出す。ギルドに見つからない人は赤字で末尾に。
-- 週ごとの出席は ●(出席)/ ○(欠席)で、左から出席データの週の順。

function Guild_storage_list_members_open()
    local c = g.guild_storage_list_const
    local name = addon_name_lower .. c.frame .. "_members"
    local frame = ui.GetFrame(name)
    if not frame then
        frame = ui.CreateNewFrame("notice_on_pc", name, 0, 0, 0, 0)
    end
    AUTO_CAST(frame)
    g.block_click_through(frame)
    frame:SetSkinName("test_frame_low")
    frame:SetTitleBarSkin("None")
    frame:SetLayerLevel(92)
    frame:EnableMove(1)
    local width, height = 380, 560
    frame:Resize(width, height)
    -- 一覧の窓の右隣(はみ出すなら左隣)。一覧が無ければ画面の中央
    local main = ui.GetFrame(addon_name_lower .. c.frame)
    if main then
        local map_ui = ui.GetFrame("map")
        local screen_w = (map_ui and map_ui:GetWidth()) or 1920
        local x = main:GetX() + main:GetWidth()
        if x + width > screen_w then
            x = math.max(0, main:GetX() - width)
        end
        frame:SetPos(x, main:GetY())
    else
        frame:SetPos(g.settings_frame_pos(width, height))
    end
    frame:RemoveAllChild()
    local title = frame:CreateOrGetControl("richtext", "title", 20, 12, 200, 30)
    AUTO_CAST(title)
    title:SetText("{@st66b18}" .. Guild_storage_list_t("配布対象者", "Recipients"))
    local close = frame:CreateOrGetControl("button", "close", 0, 0, 25, 25)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Guild_storage_list_members_close")
    local info = frame:CreateOrGetControl("richtext", "info", 20, 45, width - 40, 24)
    AUTO_CAST(info)
    local list = frame:CreateOrGetControl("groupbox", "list", 10, 75, width - 20, height - 85)
    AUTO_CAST(list)
    list:SetSkinName("bg")
    list:EnableScrollBar(1)
    frame:ShowWindow(1)
    g.esc_register_destroy(name)
    Guild_storage_list_members_refresh()
end

function Guild_storage_list_members_close()
    ui.DestroyFrame(addon_name_lower .. g.guild_storage_list_const.frame .. "_members")
end

-- 開いていれば中身を描き直す(出席データを貼り直したとき・読み直したとき)
function Guild_storage_list_members_refresh()
    local frame = ui.GetFrame(addon_name_lower .. g.guild_storage_list_const.frame .. "_members")
    if not frame or frame:IsVisible() ~= 1 then
        return
    end
    local info = GET_CHILD_RECURSIVELY(frame, "info")
    local list = GET_CHILD_RECURSIVELY(frame, "list")
    if not info or not list then
        return
    end
    list:RemoveAllChild()
    local link = g.guild_storage_list.link
    if not link then
        info:SetText(Guild_storage_list_t("{ol}{#FF6347}出席データがありません", "{ol}{#FF6347}No attendance data"))
        return
    end
    info:SetText(string.format(Guild_storage_list_t("{ol}{s14}%d 人 / %d 口(%s)", "{ol}{s14}%d people / %d units (%s)"),
        #g.guild_storage_list.matched, Guild_storage_list_unit_count(), table.concat(link.weeks, "・")))
    -- ギルドで見つかった人の表記(大文字小文字の違いはギルド側へ寄せている)
    local members = Guild_storage_list_guild_member_names()
    local found = g.guild_storage_list_match(link.people, members)
    local rows = {}
    for i, p in ipairs(link.people) do
        local hit = g.guild_storage_list_match({p}, members)[1]
        rows[#rows + 1] = {
            name = hit and hit.name or p.team,
            units = p.units,
            bits = p.bits,
            found = hit ~= nil,
            index = i
        }
    end
    table.sort(rows, function(a, b)
        if a.found ~= b.found then
            return a.found
        end
        if a.units ~= b.units then
            return a.units > b.units
        end
        return a.index < b.index
    end)
    local y = 0
    for i, r in ipairs(rows) do
        local bits = string.gsub(string.gsub(r.bits, "1", "●"), "0", "○")
        local line = list:CreateOrGetControl("richtext", "row_" .. i, 10, y + 4, 340, 22)
        AUTO_CAST(line)
        if r.found then
            line:SetText(string.format("{ol}{s15}%s  {#FFD700}%d 口{/}  {#AAAAAA}%s", r.name, r.units, bits))
        else
            line:SetText(string.format("{ol}{s15}{#FF6347}%s  %s", r.name,
                Guild_storage_list_t("(ギルドに見つからない・送られない)", "(not in the guild, not sent)")))
        end
        y = y + 26
    end
    g.vlog("guild_storage_list: 対象者の窓 %d 行 (見つかった %d 人)", #rows, #found)
end
-- Guild Storage List ここまで
