-- Icor Planner ここから
--
-- 目標にしたいステータス(クリ発 / 各種相殺 / 種族攻撃 / 材質攻撃 / 主ステ など)を決めて、
-- 「今の装備との差を埋めるにはイコルを何個更新すればよいか」を出す。
--
-- **自前の数値表を持たないこと。** オプションごとの min〜max は素の
-- shared_item_goddess_icor がレベル(UseLv) / 部位(StringArg2) / 上級・下級(NumberArg1)から
-- 返してくれる。書き写すと段が増えたときに黙って古い値のままになる
-- (market_favorite_rebuild が同じ轍を踏み、Lv560 のイコルに色が付かない不具合になった)。
g.icor_planner_slots = {{
    slot_name = "RH",
    clmsg = "RH"
}, {
    slot_name = "LH",
    clmsg = "LH"
}, {
    slot_name = "SHIRT",
    clmsg = "Shirt"
}, {
    slot_name = "PANTS",
    clmsg = "Pants"
}, {
    slot_name = "GLOVES",
    clmsg = "Gloves"
}, {
    slot_name = "BOOTS",
    clmsg = "Boots"
}, {
    slot_name = "RH_SUB",
    clmsg = "RH_SUB"
}, {
    slot_name = "LH_SUB",
    clmsg = "LH_SUB"
}}

-- 持ち替えで使う裏の武器セット。**枠数には数えない**(表と同じ 1 か所として扱う)。
-- 部位ごとの内訳には出す(どちらへ何が載っているかは見たいため)。
g.icor_planner_sub_slots = {
    RH_SUB = true,
    LH_SUB = true
}

-- グループの表示色。reroll_option.lua / goddess_icor_manager と揃える
g.icor_planner_group_color = {
    ATK = "{#FF6347}",
    DEF = "{#6495ED}",
    STAT = "{#90EE90}",
    UTIL_ARMOR = "{#DA70D6}",
    SPECIAL = "{#FFD700}"
}

-- ===== 設定の読み書き =====
--
-- 目標プリセットはアカウント共通(presets)、どれを使うかだけキャラごと(chars[cid])に持つ。
-- 複数キャラで同じ目標を使い回せるようにするため。
function Icor_planner_save_settings()
    g.save_json(g.icor_planner_path, g.icor_planner_settings)
end

function Icor_planner_load_settings()
    g.icor_planner_path = string.format("../addons/%s/%s/icor_planner.json", addon_name_lower, g.active_id)
    local settings = g.load_json(g.icor_planner_path)
    local changed = false
    if not settings then
        settings = {}
        changed = true
    end
    if not settings.presets or #settings.presets == 0 then
        settings.presets = Icor_planner_default_presets()
        changed = true
    end
    if not settings.chars then
        settings.chars = {}
        changed = true
    end
    -- 計算しないイコル。**キャラごと**(装備はキャラごとに違う)に、部位名で持つ。
    -- excluded[cid] = { RH = true, SHIRT = true }
    if not settings.excluded then
        settings.excluded = {}
        changed = true
    end
    -- マーケットを開いたときに評価パネルも一緒に出すか。**既定は 1**(これまでの挙動)。
    -- 0 にしても、マーケットの「お気に入り」の隣のボタンからいつでも出せる
    if settings.market_auto == nil then
        settings.market_auto = 1
        changed = true
    end
    -- マーケットのパネルの並び順。**既定は 0 = マーケットの並び順**。
    -- 素の一覧と行が対応していた方が、パネルを見ながら素の行を押せる
    if settings.market_sort == nil then
        settings.market_sort = 0
        changed = true
    end
    -- 試算タブ・マーケットのパネルでオプション名を略語にするか。**既定は 1**。
    -- 略語が分からなくなったときに正式名へ戻せるよう、試算タブの上にボタンを置いている
    if settings.short_names == nil then
        settings.short_names = 1
        changed = true
    end
    g.icor_planner_settings = settings
    if changed then
        Icor_planner_save_settings()
    end
end

-- 既定のプリセット。**1 つだけ**入れる(開発者本人の実際の目標を既定にした)。
-- 数値は Lv560 の段に合わせてある:
--   全ての防具の材質 / 全ての種族 16,800 … ステータスの割合が 100% になる値(Lv560 × 20 × 1.5)
--   レザー / 中型相殺 8,400                … 50% になる値
--   パーフェクト効果 12,636                … Lv560 武器イコル 1 枠の最小値
--   体力 517                               … Lv560 イコル 1 枠の最小値
-- Lv 上限が上がったら、目標タブの目安ボタンで入れ直せばよい(既定を書き換えなくても使える)。
function Icor_planner_default_presets()
    return {{
        name = g.lang == "Japanese" and "相殺・種族・材質" or "Counters / race / material",
        targets = {{
            opt = "AllMaterialType_Atk",
            value = 16800,
            mode = "total",
            spot = "both"
        }, {
            opt = "AllRace_Atk",
            value = 16800,
            mode = "total",
            spot = "both"
        }, {
            opt = "perfection",
            value = 12636,
            mode = "slot",
            spot = "Weapon"
        }, {
            opt = "Leather_Def",
            value = 8400,
            mode = "total",
            spot = "Armor"
        }, {
            opt = "MiddleSize_Def",
            value = 8400,
            mode = "total",
            spot = "Armor"
        }, {
            opt = "CON",
            value = 517,
            mode = "slot",
            spot = "both"
        }, {
            opt = "STR",
            value = 517,
            mode = "total",
            spot = "both"
        }, {
            opt = "CRTHR",
            value = 24000,
            mode = "total",
            spot = "both"
        }}
    }}
end

-- 目標 1 行ごとの id。**同じオプションを複数行持てるようにするため**に要る。
--
-- 「全ての種族の対象攻撃力は武器の各部位に載せて、足りない分は防具で合計を埋める」
-- のような組み方は、1 行では書けない(数え方も対象部位も行ごとに違うため)。
-- オプション名で行を引いていると 2 行目を区別できないので、id で引く。
function Icor_planner_assign_ids(preset)
    if preset == nil or preset.targets == nil then
        return
    end
    local max_id = 0
    for _, t in ipairs(preset.targets) do
        if type(t.id) == "number" and t.id > max_id then
            max_id = t.id
        end
    end
    for _, t in ipairs(preset.targets) do
        if type(t.id) ~= "number" then
            max_id = max_id + 1
            t.id = max_id
        end
    end
end

function Icor_planner_target_by_id(id)
    local preset = Icor_planner_cur_preset()
    for _, t in ipairs((preset and preset.targets) or {}) do
        if t.id == id then
            return t
        end
    end
    return nil
end

function Icor_planner_cur_preset()
    local settings = g.icor_planner_settings
    if not settings then
        return nil
    end
    local index = settings.chars[g.cid] or 1
    if not settings.presets[index] then
        index = 1
    end
    Icor_planner_assign_ids(settings.presets[index])
    return settings.presets[index], index
end

function Icor_planner_set_preset(index)
    g.icor_planner_settings.chars[g.cid] = index
    Icor_planner_save_settings()
end

-- ===== 素のデータを引くところ =====
--
-- 目標に選べるオプションの一覧。**素の option_list_by_group から作る。**
-- レベルは決め打ちできない(段が増える)ので 480 から 20 刻みで当たりに行き、
-- 引けたものだけを拾う。存在しないレベルを引くと素の実装が nil を添字するので pcall で包む。
function Icor_planner_candidate_options()
    if g.icor_planner_candidates then
        return g.icor_planner_candidates
    end
    local seen, list = {}, {}
    if shared_item_goddess_icor == nil then
        g.vlog("{#FF6347}icor_planner: shared_item_goddess_icor が無い。目標の候補を作れない{/}")
        g.icor_planner_candidates = list
        return list
    end
    local groups = {"ATK", "STAT", "UTIL_ARMOR", "DEF"}
    local spots = {"Weapon", "Armor"}
    local probed = 0
    for lv = 480, 800, 20 do
        for _, spot in ipairs(spots) do
            for _, group in ipairs(groups) do
                local ok, names = pcall(shared_item_goddess_icor.get_option_list_by_group, lv, spot, group)
                if ok and type(names) == "table" then
                    probed = probed + 1
                    -- **素の表に在る一番上の段を覚える。** 目標値の目安を「今の最大レベルの
                    -- イコル」で出すのに使う。Lv 上限が上がっても、素の表が増えれば追従する
                    g.icor_planner_max_lv = g.icor_planner_max_lv or {}
                    if (g.icor_planner_max_lv[spot] or 0) < lv then
                        g.icor_planner_max_lv[spot] = lv
                    end
                    for _, name in ipairs(names) do
                        if not seen[name] then
                            seen[name] = {
                                opt = name,
                                group = group,
                                spots = {}
                            }
                            list[#list + 1] = seen[name]
                        end
                        seen[name].spots[spot] = true
                    end
                end
            end
        end
    end
    -- 何組ぶん引けたかを 1 回だけ残す。0 なら素の作りが変わったということなので、
    -- 「目標の候補が空」を実機ログから切り分けられる
    g.vlog("icor_planner: 目標の候補 %d 件(素の表 %d 組から)", #list, probed)
    -- **並びは表示名で決める。** 内部名(ADD_CLOTH など)で並べると、画面に出るのは
    -- 訳した名前なので順序がばらばらに見える。
    -- **table.sort は安定ではない**ので、最後の決め手に内部名を置いて order を一意にする。
    for _, cand in ipairs(list) do
        cand.label = Icor_planner_option_name(cand.opt)
    end
    table.sort(list, function(a, b)
        if a.group ~= b.group then
            return a.group < b.group
        end
        if a.label ~= b.label then
            return a.label < b.label
        end
        return a.opt < b.opt
    end)
    -- 目標タブの左右や診断の並びを揃えるための順番。ここが唯一の基準
    for i, cand in ipairs(list) do
        cand.order = i
    end
    g.icor_planner_candidates = list
    return list
end

function Icor_planner_candidate_of(opt)
    for _, cand in ipairs(Icor_planner_candidate_options()) do
        if cand.opt == opt then
            return cand
        end
    end
    return nil
end

function Icor_planner_group_of(opt)
    local cand = Icor_planner_candidate_of(opt)
    return cand and cand.group or "None"
end

-- 画面に出すときの並び順。**候補一覧と同じ順番を使う**ことで、
-- 目標タブの左(候補)と右(今の目標)、診断の一覧がすべて同じ並びになる。
-- 候補に無いもの(素の表から消えたオプション)は末尾へ回す
-- そのオプションが、その部位(Weapon / Armor)のイコルに載りうるか。
-- 素の option_list_by_group をなめたときに拾った情報。perfection / revenge は Weapon だけ、
-- 各種抵抗や portion_expansion は Armor だけ、という違いがある
function Icor_planner_spot_can(opt, spot)
    local cand = Icor_planner_candidate_of(opt)
    if cand == nil or cand.spots == nil then
        return true
    end
    return cand.spots[spot] == true
end

-- ===== 目標 1 行の「数え方」と「対象部位」 =====
--
-- 目標には 2 種類ある。
--   * total … **合計で足りればよい**。どの部位が持っていてもかまわない
--              (クリ発 / 各種相殺 / 種族攻撃 など)
--   * slot  … **各部位に載っていてほしい**。合計が足りていても、載っていない部位があれば
--              まだ足りていない扱いにする(主ステ / パフェ など)
-- 「合計は足りているのに主ステが 1 部位にしか載っていない」を、前者だけでは表せない。
g.icor_planner_mode_total = "total"
g.icor_planner_mode_slot = "slot"

function Icor_planner_target_mode(t)
    -- **相殺は合計でしか意味を持たない**ので、各部位へは倒さない
    if Icor_planner_is_counter(t.opt) then
        return g.icor_planner_mode_total
    end
    return t.mode == g.icor_planner_mode_slot and g.icor_planner_mode_slot or g.icor_planner_mode_total
end

-- 対象部位。**素のデータで 1 部位にしか載らないものは、そちらへ固定する。**
-- perfection / revenge は武器だけ、各種抵抗や portion_expansion は防具だけなので、
-- 利用者に選ばせても意味が無いし、間違えると評価が狂う。
function Icor_planner_target_spot(t)
    local cand = Icor_planner_candidate_of(t.opt)
    local can_weapon = (cand == nil) or (cand.spots == nil) or (cand.spots.Weapon == true)
    local can_armor = (cand == nil) or (cand.spots == nil) or (cand.spots.Armor == true)
    if can_weapon and not can_armor then
        return "Weapon"
    end
    if can_armor and not can_weapon then
        return "Armor"
    end
    if t.spot == "Weapon" or t.spot == "Armor" then
        return t.spot
    end
    return "both"
end

-- 利用者が対象部位を選べるか(両方に載るオプションだけ)
function Icor_planner_target_spot_fixed(t)
    local cand = Icor_planner_candidate_of(t.opt)
    if cand == nil or cand.spots == nil then
        return false
    end
    return not (cand.spots.Weapon == true and cand.spots.Armor == true)
end

-- 各部位の目標で「何部位まで目指すか」。
-- **既定は装備している部位数で、それが上限。** 利用者が減らしたときだけ t.count を持つ。
-- 上限と同じ値は保存しない(nil に戻す)。こうしておくと、後で装備を足したときに
-- 既定の側が自然に増える。逆に上限を超える値は、装備を外した後に残っていても丸める
function Icor_planner_target_count(t, max_count)
    local count = tonumber(t.count)
    if count == nil or count > max_count then
        return max_count
    end
    return math.max(1, math.floor(count))
end

-- ステータスの値のうち、**装備イコルのオプション以外**から来ている分。
-- ギルドの威厳・共用スキル・クポル・モンスターカード・アシスター・固定イコル(協応など)・バフが
-- 全部ここへ入る。出どころを 1 つずつ読むのではなく、**全部込みのステータスの値から
-- イコルのオプションを引く**ので、取りこぼしが無い(逆に、出どころ別の内訳は出せない)。
-- 戻り値: それ以外 / イコルのオプション合計 / ステータスの値
function Icor_planner_other_sources(opt)
    local cur = tonumber(Icor_planner_current(opt)) or 0
    local icor_sum, sub_sum = 0, 0
    for _, entry in ipairs(Icor_planner_scan().slots) do
        -- 計算しない部位は数えない。今の値の側からも引いてあるので、「それ以外」は変わらない
        if entry.equipped and not entry.excluded then
            for _, op in ipairs(entry.options) do
                if op.opt == opt then
                    icor_sum = icor_sum + op.value
                    if g.icor_planner_sub_slots[entry.slot_name] then
                        sub_sum = sub_sum + op.value
                    end
                end
            end
        end
    end
    local other = math.max(0, cur - icor_sum)
    -- **判断の材料を残す。** 武器のセット 2(持ち替え側)がステータスの値に入っているかは
    -- 素を読んでも確かめきれていない。入っていなければ「それ以外」が sub の分だけ小さく出るので、
    -- 実機でステータス画面と見比べられるよう sub の分を別に出す
    g.vlog("icor_planner: %s ステータス %d = イコル %d (うち持ち替え側 %d) + それ以外 %d", tostring(opt), cur,
        icor_sum, sub_sum, other)
    return other, icor_sum, cur
end

-- 「各部位に載せたい」目標が、今いくつの部位に載っているか。
-- 目標タブが 1 行ごとに呼ぶので、装備の読み取りは 1 回だけにして使い回す。
-- 戻り値: 載っている数 / 目指す数(利用者が絞った値) / 装備している数(上限)
function Icor_planner_slot_progress(t)
    local scan = Icor_planner_scan()
    local have, want = 0, 0
    local min_value = tonumber(t.value) or 0
    for _, entry in ipairs(scan.slots) do
        -- 実際に装備している数で数える(Icor_planner_diagnose と揃える)
        if entry.equipped and Icor_planner_target_applies(t, entry.spot) then
            want = want + 1
            local value = Icor_planner_entry_value(entry, t.opt)
            if value > 0 and value >= min_value then
                have = have + 1
            end
        end
    end
    return have, Icor_planner_target_count(t, want), want
end

function Icor_planner_target_applies(t, spot)
    local target_spot = Icor_planner_target_spot(t)
    return target_spot == "both" or target_spot == spot
end

function Icor_planner_spot_label(spot)
    if spot == "Weapon" then
        return g.lang == "Japanese" and "武器" or "Weapon"
    elseif spot == "Armor" then
        return g.lang == "Japanese" and "防具" or "Armor"
    end
    return g.lang == "Japanese" and "両方" or "Both"
end

function Icor_planner_order_of(opt)
    local cand = Icor_planner_candidate_of(opt)
    return cand and cand.order or 9999
end

-- ===== ステータス画面と同じ ％ =====
--
-- ステータス画面は、対象攻撃力や相殺の数値の隣に「(87.3%)」を出す。出しているのは素の
-- get_percent_format -> get_<属性名>_ratio_for_status で、中身は
-- get_calc_atk_value_for_status = 値 / (Lv * ITEM_ATK_POINT_MULTIPLE * 1.5) * 100 (0〜100 で丸め)。
--
-- **この式を書き写さないこと。** 素の関数をそのまま呼んで、返ってきた文字列から ％ だけを
-- 取り出す。Lv 上限が上がって係数が変わっても追従する。
-- (goddess_icor_manager は Lv*30 / Lv*15 を自前で持っているが、素は攻撃も防御も同じ
--  除数を使っている。こちらは素に合わせる)
--
-- イコルのオプション名とステータスの属性名は綴りが違う。対応は素の calc_property_pc.lua の
-- SCR_GET_<属性>(pc) が GetSumOfEquipItem(pc, "<オプション>") を足しているところから取った。
g.icor_planner_status_attr = {
    ADD_CLOTH = "Cloth_Atk",
    ADD_LEATHER = "Leather_Atk",
    ADD_IRON = "Iron_Atk",
    ADD_GHOST = "Ghost_Atk",
    ADD_SMALLSIZE = "SmallSize_Atk",
    ADD_MIDDLESIZE = "MiddleSize_Atk",
    ADD_LARGESIZE = "LargeSize_Atk",
    ADD_FORESTER = "Forester_Atk",
    ADD_WIDLING = "Widling_Atk",
    ADD_VELIAS = "Velnias_Atk",
    ADD_PARAMUNE = "Paramune_Atk",
    ADD_KLAIDA = "Klaida_Atk"
}

-- そのオプションの「今の値」。**ステータス画面と同じ経路で取る。**
--
-- 以前はここで装備 8 部位のイコルのオプションを足していたが、それは**イコル由来の分だけ**で、
-- ステータス画面が出している値(装備の素の性能・他の部位・バフなども入った合計)と合わない。
-- 実際に「クロース対象攻撃力相殺 ステータス 9,046 / こちら 8,046」のように食い違った。
--
-- 素の STATUS_ATTRIBUTE_VALUE_NEW は次の 2 通りで取っている。どちらを通るかは status.lua の
-- special_option_list で決まるが、**あれは local なのでこちらからは読めない**。
-- そこで「PC のプロパティとして持っているか」で分ける:
--   * 持っている(> 0)  … TryGetProp + ADD_ALL_ATK_STATUS(全材質 / 全種族の加算)
--   * 持っていない(0)  … GET_SPECIAL_OPTION_VALUE(装備のイコルを足す。perfection / revenge /
--                        各種抵抗 / portion_expansion がこちら)
-- perfection のように PC プロパティを持たないものは前者が 0 になるので、そのまま後者へ落ちる。
-- 「全ての〜」のオプションが、ステータス画面ではどの項目に足されているか。
-- 出どころは素の ADD_ALL_ATK_STATUS(status.lua)。**あれは関数で、対応を表として読めない**ので
-- 名前の対応だけ持つ(式は写していない)。素が項目を増やしたら、ここも足すこと。
g.icor_planner_all_members = {
    AllRace_Atk = {"Forester_Atk", "Widling_Atk", "Klaida_Atk", "Paramune_Atk", "Velnias_Atk"},
    AllMaterialType_Atk = {"Cloth_Atk", "Leather_Atk", "Iron_Atk", "Ghost_Atk"},
    AllMaterialType_Def = {"Cloth_Def", "Leather_Def", "Iron_Def"},
    AllSize_Atk = {"SmallSize_Atk", "MiddleSize_Atk", "LargeSize_Atk"}
}

function Icor_planner_current(opt)
    local pc = GetMyPCObject()
    if pc == nil then
        return 0
    end
    -- **「全ての〜」は、足される先の項目の一番低い値を今の値にする。**
    -- PC の AllRace_Atk はイコルなど「全ての種族」の名前で付いた分しか持っておらず、
    -- 協応(植物型 +2,070 …)や共用スキルのように**種族ごとの名前で付く分が入らない**。
    -- ステータス画面の「植物型対象攻撃力」などは、その項目の値に全ての種族の分を足したもの
    -- (素の ADD_ALL_ATK_STATUS)なので、そちらを読めば全部入る。
    -- 一番低い項目を採るのは、「全ての種族で目標に届いた」と言えるのがその値だから
    local members = g.icor_planner_all_members[Icor_planner_status_attr_of(opt)]
    if members ~= nil then
        local lowest = nil
        for _, member in ipairs(members) do
            local value = Icor_planner_current(member)
            if lowest == nil or value < lowest then
                lowest = value
            end
        end
        if lowest ~= nil and lowest > 0 then
            return lowest
        end
    end
    local attr = Icor_planner_status_attr_of(opt)
    -- **計算しないイコルの分は引く。** ステータス画面の値には今装備しているイコルが全部入って
    -- いるので、「この部位は付け替える予定」のイコルを外した姿を今の値にする
    -- 試算タブで差し替えているときは、外すイコルの分を引いて差し替えるイコルの分を足す
    local delta = Icor_planner_status_delta()[attr] or 0
    local value = tonumber(TryGetProp(pc, attr, 0)) or 0
    if value > 0 then
        local ok, added = pcall(ADD_ALL_ATK_STATUS, pc, attr, value)
        if ok and type(added) == "number" then
            return math.max(0, added + delta)
        end
        return math.max(0, value + delta)
    end
    local ok, special = pcall(GET_SPECIAL_OPTION_VALUE, pc, attr)
    if ok and type(special) == "number" then
        return math.max(0, special + delta)
    end
    return 0
end

-- その部位のイコルを計算しないか(今のキャラ)
function Icor_planner_is_excluded(slot_name)
    local settings = g.icor_planner_settings
    local list = settings and settings.excluded and settings.excluded[tostring(g.cid)]
    return list ~= nil and list[slot_name] == true
end

-- 部位のイコルに載っているそのオプションの値。**計算しない部位は 0**(載っていない扱い)
function Icor_planner_entry_value(entry, opt)
    if entry.excluded then
        return 0
    end
    local value = 0
    for _, op in ipairs(entry.options) do
        if op.opt == opt then
            value = value + op.value
        end
    end
    return value
end

-- ステータス画面の値に足し引きする分(属性名 -> 値)。
--   * 計算しないイコル … その部位のイコルの分を引く
--   * 試算の差し替え   … 今のイコルの分を引き(計算しないにしていれば既に引いてある)、
--                         差し替えるイコルの分を足す(g.icor_planner_trial_on の間だけ)
-- 「全ての〜」のオプションは足される先の項目(植物型など)にも入れる
-- (素の ADD_ALL_ATK_STATUS がそこへ足しているため)。
--
-- **溜めること。** 今の値を引くたびに呼ばれ、中で装備を読むので、そのままだと診断 1 回で
-- 装備を何十回も読む。溜め込みは Icor_planner_reset_delta で捨てる(タブの作り直し・診断の先頭)
function Icor_planner_reset_delta()
    g.icor_planner_delta_cache = {}
end

function Icor_planner_status_delta()
    local mode = g.icor_planner_trial_on and "trial" or "real"
    g.icor_planner_delta_cache = g.icor_planner_delta_cache or {}
    if g.icor_planner_delta_cache[mode] then
        return g.icor_planner_delta_cache[mode]
    end
    local sums = {}
    local settings = g.icor_planner_settings
    local list = settings and settings.excluded and settings.excluded[tostring(g.cid)]
    local has_excluded = list ~= nil and next(list) ~= nil
    local swaps = g.icor_planner_trial_on and Icor_planner_trial_swaps() or {}
    if not has_excluded and next(swaps) == nil then
        g.icor_planner_delta_cache[mode] = sums
        return sums
    end
    local function add(options, sign)
        for _, op in ipairs(options) do
            local attr = Icor_planner_status_attr_of(op.opt)
            sums[attr] = (sums[attr] or 0) + sign * op.value
            for _, member in ipairs(g.icor_planner_all_members[attr] or {}) do
                sums[member] = (sums[member] or 0) + sign * op.value
            end
        end
    end
    -- **差し替える前の装備を読む。** 試算中に読むと、差し替え後の中身が返ってくる
    local was_on = g.icor_planner_trial_on
    g.icor_planner_trial_on = false
    local ok, scan = pcall(Icor_planner_scan)
    g.icor_planner_trial_on = was_on
    if not ok then
        return sums
    end
    for _, entry in ipairs(scan.slots) do
        if entry.equipped then
            local swap = swaps[entry.slot_name]
            if entry.excluded then
                add(entry.options, -1)
            elseif swap ~= nil then
                add(entry.options, -1)
            end
            if swap ~= nil then
                add(swap.options, 1)
            end
        end
    end
    g.icor_planner_delta_cache[mode] = sums
    return sums
end

-- ===== 試算(このイコルに替えたら) =====
--
-- 部位名 -> 差し替えるイコルの控え。控えにはオプションを写しておく。マーケットの出品は
-- ページを移ると中身が入れ替わるので、品物そのものを握っていると別の品を読んでしまう。
--
-- **差し替えは保存して、次に開いたときに読み込む。** 「上半身はこれ、下半身はこれ」と
-- 組んだ差し替えを、毎日マーケットで探し直すため(実機で要望された)。
-- 置き場所は icor_planner.json の trial_swaps[キャラ]。部位はキャラの装備で決まるので**キャラごと**。
-- 変えたら Icor_planner_trial_save を呼ぶこと(呼び忘れると、再起動で前の姿に戻る)
function Icor_planner_trial_swaps()
    local cid = tostring(g.cid)
    -- 設定を読む前に呼ばれたら、読み込まずに空で返す(溜めると、読んだ後も空のまま残る)
    if g.icor_planner_settings == nil then
        return {}
    end
    if g.icor_planner_trial == nil or g.icor_planner_trial.cid ~= cid then
        local saved = g.icor_planner_settings and g.icor_planner_settings.trial_swaps and
                          g.icor_planner_settings.trial_swaps[cid]
        local swaps = {}
        for slot_name, swap in pairs(type(saved) == "table" and saved or {}) do
            if type(swap) == "table" and type(swap.options) == "table" then
                swaps[slot_name] = swap
                -- 読み込むと options と base_options は別の表になる。リロールしていなければ同じ表に戻す
                if swap.reroll == nil or swap.base_options == nil then
                    swap.base_options = swap.options
                end
            end
        end
        g.icor_planner_trial = {
            cid = cid,
            swaps = swaps
        }
        local count = 0
        for _ in pairs(swaps) do
            count = count + 1
        end
        g.vlog("icor_planner: 保存した試算の差し替えを読み込んだ %d 部位 (cid %s)", count, cid)
    end
    return g.icor_planner_trial.swaps
end

-- 今の差し替えを保存する(差し替え / 戻す / リロール / 組み直しのたびに呼ぶ)
function Icor_planner_trial_save()
    local settings = g.icor_planner_settings
    if settings == nil then
        return
    end
    local cid = tostring(g.cid)
    settings.trial_swaps = settings.trial_swaps or {}
    local swaps = Icor_planner_trial_swaps()
    if next(swaps) == nil then
        settings.trial_swaps[cid] = nil
    else
        settings.trial_swaps[cid] = swaps
    end
    Icor_planner_save_settings()
end

-- イコル(アイテム)に載っているオプション
function Icor_planner_icor_options(item_obj)
    local options = {}
    for i = 1, shared_item_goddess_icor.get_max_option_count() do
        local opt = TryGetProp(item_obj, "RandomOption_" .. i, "None")
        local value = tonumber(TryGetProp(item_obj, "RandomOptionValue_" .. i, 0)) or 0
        if opt ~= nil and opt ~= "None" then
            local _, max_value = Icor_planner_range(item_obj, opt)
            options[#options + 1] = {
                opt = opt,
                value = value,
                group = TryGetProp(item_obj, "RandomOptionGroup_" .. i, "None"),
                max = max_value,
                state = Icor_planner_value_state(value, max_value)
            }
        end
    end
    return options
end

-- 試算の候補。インベントリのイコルと、今マーケットに出ている出品のうち、その部位に付けられるもの。
-- 未鑑定(NeedRandomOption)はオプションが決まっていないので外す
function Icor_planner_trial_candidates(spot)
    local rows = {}
    local function consider(item_obj, source, price)
        if item_obj == nil or TryGetProp(item_obj, "GroupName", "None") ~= "Icor" then
            return
        end
        if TryGetProp(item_obj, "StringArg2", "None") ~= spot or TryGetProp(item_obj, "NeedRandomOption", 0) == 1 then
            return
        end
        rows[#rows + 1] = {
            source = source,
            price = price,
            -- マーケットで探すときの部位(武器 / 防具)。差し替えを保存しても引けるよう控える
            spot = spot,
            name = dictionary.ReplaceDicIDInCompStr(TryGetProp(item_obj, "Name", "")),
            lv = tonumber(TryGetProp(item_obj, "UseLv", 0)) or 0,
            -- リロールの試算で、候補のオプションと値の範囲を素に引くのに使う(品物は握らない)
            class_name = TryGetProp(item_obj, "ClassName", "None"),
            options = Icor_planner_icor_options(item_obj)
        }
    end
    local inv_list = session.GetInvItemList()
    if inv_list ~= nil then
        local guid_list = inv_list:GetGuidList()
        for i = 0, guid_list:Count() - 1 do
            local inv_item = inv_list:GetItemByGuid(guid_list:Get(i))
            if inv_item ~= nil then
                consider(GetIES(inv_item:GetObject()), "inv", nil)
            end
        end
    end
    local market = ui.GetFrame("market")
    if market ~= nil and market:IsVisible() == 1 then
        local ok_n, n = pcall(session.market.GetItemCount)
        if ok_n and type(n) == "number" then
            for i = 0, n - 1 do
                pcall(function()
                    local market_item = session.market.GetItemByIndex(i)
                    local ok_price, price = pcall(function()
                        return market_item:GetSellPrice()
                    end)
                    consider(GetIES(market_item:GetObject()), "market", ok_price and tonumber(price) or 0)
                end)
            end
        end
    end
    return rows
end

-- ===== 試算: 試すイコルをオプションリロールで 1 枠だけ変える =====
--
-- **変えるのは試すイコル(差し替えたイコル)。** 今のイコルではない(「このイコルを買って
-- 1 枠リロールしたら」を見るため。実機で指摘された)。
-- 素のオプションリロールは**選んだ 1 枠だけ**を、**同じグループの中で**振り直すので、
-- 変えられるのは 1 枠だけ。別の枠を変えると、前に変えた枠は元へ戻る。
--
-- 変えた後の値は、そのイコルの段の範囲から assume で決める
-- (avg = (最小 + 最大) / 2 / min = 最小 / max = 最大)。
function Icor_planner_trial_assume_value(class_name, opt, assume)
    local cls = GetClass("Item", class_name or "None")
    local min_value, max_value = Icor_planner_range(cls, opt)
    if max_value <= 0 then
        return 0
    end
    if assume == "max" then
        return max_value
    elseif assume == "min" then
        return min_value
    end
    return math.floor((min_value + max_value) / 2)
end

-- リロールの元 = 差し替えたイコルの、買ったままの姿
function Icor_planner_trial_base(slot_name)
    local swap = Icor_planner_trial_swaps()[slot_name]
    if swap == nil then
        return nil
    end
    return {
        options = swap.base_options or swap.options,
        class_name = swap.class_name,
        lv = swap.lv,
        name = swap.name,
        swap = swap
    }
end

-- 枠 index をリロールしたときに出うるオプション。
-- **グループでは絞らない。** 素の再設定画面(reroll_item_option.lua)は、候補を
-- get_random_option_list(そのイコルの段・部位の全オプション)から作り、
-- is_valid_reroll_option(同じイコルの他の枠と重ならない)だけで外している。
-- 部位(武器 / 防具)の違いは get_random_option_list が段と部位で引き分けている
function Icor_planner_trial_reroll_options(base, index)
    local op = base.options[index]
    local cls = GetClass("Item", base.class_name or "None")
    if op == nil or cls == nil then
        return {}
    end
    local taken = {}
    for i, other in ipairs(base.options) do
        if i ~= index then
            taken[other.opt] = true
        end
    end
    local list = {}
    for _, opt in ipairs(Icor_planner_option_candidates(cls) or {}) do
        if not taken[opt] then
            list[#list + 1] = opt
        end
    end
    table.sort(list, function(a, b)
        local oa, ob = Icor_planner_order_of(a), Icor_planner_order_of(b)
        if oa ~= ob then
            return oa < ob
        end
        return a < b
    end)
    return list
end

-- 差し替えたイコルの枠 index を opt へ変える。index が無い / opt が元のままなら、リロールを取り消す
function Icor_planner_trial_set_reroll(slot_name, index, opt, assume)
    local base = Icor_planner_trial_base(slot_name)
    if base == nil then
        return
    end
    local from = index and base.options[index]
    if from == nil or opt == nil or opt == from.opt then
        base.swap.options = base.options
        base.swap.reroll = nil
        Icor_planner_trial_save()
        g.vlog("icor_planner: 試算のリロールを取り消した %s", tostring(slot_name))
        return
    end
    local value = Icor_planner_trial_assume_value(base.class_name, opt, assume)
    local cls = GetClass("Item", base.class_name or "None")
    local _, max_value = Icor_planner_range(cls, opt)
    local options = {}
    for i, op in ipairs(base.options) do
        if i == index then
            options[i] = {
                opt = opt,
                value = value,
                group = from.group,
                max = max_value,
                state = Icor_planner_value_state(value, max_value)
            }
        else
            options[i] = op
        end
    end
    local swap = base.swap
    swap.base_options = base.options
    swap.options = options
    swap.reroll = {
        index = index,
        from = from.opt,
        to = opt,
        value = value,
        assume = assume
    }
    Icor_planner_trial_save()
    g.vlog("icor_planner: 試算のリロール %s 枠%d %s -> %s (%d / %s)", tostring(slot_name), index, tostring(from.opt),
        tostring(opt), value, tostring(assume))
end

-- ===== 試算: 理想のイコルを自分で組む =====
--
-- 手持ちにもマーケットにも無いイコルを「こういうのを買ったら」で試す。
-- 値は**一番上の段の範囲**(Icor_planner_top_range)から assume で決める。買うのは最新の段なので、
-- 手持ちの古い段に合わせない。組んだイコルはマーケットの条件検索にもそのまま渡す
-- (Icor_planner_market_search_conditions)。

-- その部位のイコルに載せられるオプション。一番上の段で値が引けるものだけ(並びは候補一覧と同じ)
function Icor_planner_custom_option_list(spot)
    local list = {}
    for _, cand in ipairs(Icor_planner_candidate_options()) do
        if Icor_planner_spot_can(cand.opt, spot) then
            local _, max_value = Icor_planner_top_range(cand.opt, spot)
            if max_value > 0 then
                list[#list + 1] = cand.opt
            end
        end
    end
    return list
end

-- 一番上の段の範囲から assume で値を決める。
--   min / max … 範囲の端、avg … (最小 + 最大) / 2
--   limit     … 限凸で付く値(Icor_planner_limit_value)
function Icor_planner_custom_value(opt, spot, assume)
    local min_value, max_value = Icor_planner_top_range(opt, spot)
    if max_value <= 0 then
        return 0, max_value
    end
    if assume == "limit" then
        return Icor_planner_limit_value(max_value), max_value
    elseif assume == "max" then
        return max_value, max_value
    elseif assume == "min" then
        return min_value, max_value
    end
    return math.floor((min_value + max_value) / 2), max_value
end

-- 組んだイコルで slot_name を差し替える。opts はオプション名の並び("None" は空き枠)、
-- assumes は枠ごとの値の見込み(opts と同じ添字。無ければ平均)。
-- 同じオプションは 1 つのイコルに 1 つまで(素の is_valid_reroll_option)なので、重なりは後ろを捨てる。
-- 戻り値は載せたオプションの数(0 なら差し替えない)
function Icor_planner_trial_set_custom(slot_name, spot, opts, assumes)
    local options, seen = {}, {}
    local custom_opts, custom_assumes = {}, {}
    local lv = nil
    -- 空き枠を挟んでも後ろの枠を読むよう、ipairs ではなく添字で回す
    local count = 0
    for i in pairs(opts or {}) do
        count = math.max(count, i)
    end
    for i = 1, count do
        local opt = opts[i]
        local assume = (assumes or {})[i] or "avg"
        if opt ~= nil and opt ~= "None" and not seen[opt] then
            seen[opt] = true
            local value, max_value = Icor_planner_custom_value(opt, spot, assume)
            if value > 0 then
                local _, _, top_lv = Icor_planner_top_range(opt, spot)
                lv = lv or top_lv
                options[#options + 1] = {
                    opt = opt,
                    value = value,
                    group = Icor_planner_group_of(opt),
                    max = max_value,
                    state = Icor_planner_value_state(value, max_value)
                }
                custom_opts[#custom_opts + 1] = opt
                custom_assumes[#custom_assumes + 1] = assume
            end
        end
    end
    if #options == 0 then
        return 0
    end
    Icor_planner_trial_swaps()[slot_name] = {
        source = "custom",
        name = g.lang == "Japanese" and "自分で組んだイコル" or "Custom icor",
        lv = lv or 0,
        spot = spot,
        options = options,
        base_options = options,
        custom = {
            opts = custom_opts,
            assumes = custom_assumes
        }
    }
    Icor_planner_trial_save()
    local parts = {}
    for i, op in ipairs(options) do
        parts[#parts + 1] = string.format("%s=%d(%s)", op.opt, op.value, custom_assumes[i])
    end
    g.vlog("icor_planner: 試算 %s <- 自分で組んだイコル %s (Lv%s)", tostring(slot_name), table.concat(parts, ","),
        tostring(lv))
    return #options
end

-- 差し替えた姿で診断する。**試算の印は必ず戻す**(失敗しても、以降の診断が差し替え後のままになる)
function Icor_planner_diagnose_trial()
    g.icor_planner_trial_on = true
    Icor_planner_reset_delta()
    local ok, diag, scan = pcall(Icor_planner_diagnose)
    g.icor_planner_trial_on = false
    Icor_planner_reset_delta()
    if not ok then
        g.vlog("{#FF6347}icor_planner: 試算の診断に失敗した (%s){/}", tostring(diag))
        return nil, nil
    end
    return diag, scan
end

-- イコルのオプション名 -> ステータスの属性名。表に無いものは綴りがそのまま通る
function Icor_planner_status_attr_of(opt)
    return g.icor_planner_status_attr[opt] or opt
end

-- そのオプションの値を ％ にした文字列("87.3%")。％ を出せないオプションでは nil。
-- **出せないことは異常ではない。** 素が比率を持っているのは対象攻撃力・相殺の類だけで、
-- 主ステ(STR など)やパフェには ratio 関数が無い。
function Icor_planner_percent(opt, value)
    if not value or value <= 0 then
        return nil
    end
    local attr = Icor_planner_status_attr_of(opt)
    local func = _G["get_" .. attr .. "_ratio_for_status"]
    if type(func) ~= "function" then
        return nil
    end
    local ok, text = pcall(func, value)
    if not ok or type(text) ~= "string" then
        return nil
    end
    -- 素は "1234 {#ff4040}(87.3%)" の形で返す。数値の書式はこちらで作るので ％ だけ貰う。
    -- 取り出せなかった(素の書式が変わった)ときは ％ を出さずに素通りさせる
    local percent = string.match(text, "%(([%-%d%.]+)%%%)")
    if percent == nil then
        return nil
    end
    return percent .. "%"
end

-- 「1,234 (87.3%)」の形にする。％ を出せないオプションでは数値だけ。
function Icor_planner_value_text(opt, value, color)
    local text = GET_COMMAED_STRING(value or 0)
    local percent = Icor_planner_percent(opt, value)
    if percent then
        text = text .. " " .. (color or "{#AAAAAA}") .. "(" .. percent .. "){/}"
    end
    return text
end

function Icor_planner_option_name(opt)
    local ok, text = pcall(ScpArgMsg, opt)
    if ok and text and text ~= "" and text ~= "None" then
        return text
    end
    return opt
end

-- 幅の狭いところ(試算タブの候補と差し替えの行、マーケットのパネルのセット)で使う略語。
-- 正式名では 4 つ並べると 1 行に収まらず、縮めると読めない大きさになった(実機で指摘された)。
-- **表示名ではなく内部名から引く**(表示名は訳や表記の揺れで変わる)。
-- 素材は 1 文字(布・皮・鎧・霊)にし、攻撃と相殺を「皮攻撃 / 皮相殺」の形でそろえる。
-- 表に無いもの(主ステなど元から短いもの・新しく増えたもの)は正式名のまま
g.icor_planner_short_names = {
    AllMaterialType_Atk = "全防具",
    AllRace_Atk = "全種族",
    Add_Damage_Atk = "追ダメ",
    perfection = "パフェ",
    revenge = "復讐",
    ADD_CLOTH = "布攻撃",
    ADD_LEATHER = "皮攻撃",
    ADD_IRON = "鎧攻撃",
    ADD_GHOST = "霊攻撃",
    ADD_SMALLSIZE = "小型攻撃",
    ADD_MIDDLESIZE = "中型攻撃",
    ADD_LARGESIZE = "大型攻撃",
    ADD_FORESTER = "植物攻撃",
    ADD_WIDLING = "野獣攻撃",
    ADD_VELIAS = "悪魔攻撃",
    ADD_PARAMUNE = "変異攻撃",
    ADD_KLAIDA = "昆虫攻撃",
    Cloth_Def = "布相殺",
    Leather_Def = "皮相殺",
    Iron_Def = "鎧相殺",
    MiddleSize_Def = "中型相殺",
    ResAdd_Damage = "追ダメ抵",
    stun_res = "スタン抵",
    high_fire_res = "火抵",
    high_freezing_res = "氷抵",
    high_lighting_res = "雷抵",
    high_poison_res = "毒抵",
    high_laceration_res = "裂傷抵",
    portion_expansion = "ポーション",
    CRTHR = "クリ発",
    CRTDR = "クリ抵",
    BLK = "ブロ",
    BLK_BREAK = "ブロ貫",
    RHP = "HP回復"
}

function Icor_planner_option_short(opt)
    local settings = g.icor_planner_settings
    local on = settings == nil or settings.short_names ~= 0
    if on and g.lang == "Japanese" and g.icor_planner_short_names[opt] then
        return g.icor_planner_short_names[opt]
    end
    return Icor_planner_option_name(opt)
end

-- 突破(最大値を超えた値)の閾値。素の DRAW_EQUIP_GODDESS_ICOR と同じ式で、
-- market_favorite_rebuild の紫表示もこれを使っている。**== で見ないこと**
-- (段によって突破の値がちょうど閾値にならない)。
function Icor_planner_break_limit(max_value)
    if not max_value or max_value <= 0 then
        return 0
    end
    return math.floor(max_value * 1.5) - 1
end

-- 限凸で実際に付く値 = floor(最大値 × 1.5)。**突破の閾値(上の - 1)とは別物。**
-- 閾値は素が紫にする「これ以上なら限凸」の線で、付く値そのものではない
-- (Lv560 武器のパーフェクト: 最大 14,040 → 付く値 21,060。閾値の 21,059 を入れていた。実機で指摘された。
--  防具の全種族 3,296 → 4,944 / クリ発 1,933 → 2,899 と、切り捨てであることも実物で確かめた)
function Icor_planner_limit_value(max_value)
    if not max_value or max_value <= 0 then
        return 0
    end
    return math.floor(max_value * 1.5)
end

-- 値がどの段階にあるか。market_favorite_rebuild の色分けと基準を揃える
function Icor_planner_value_state(value, max_value)
    if not max_value or max_value <= 0 then
        return "none"
    end
    if value >= Icor_planner_break_limit(max_value) then
        return "break"
    elseif value >= max_value then
        return "max"
    elseif value >= math.ceil(max_value * 0.9) then
        return "near"
    end
    return "low"
end

function Icor_planner_state_color(state)
    if state == "break" then
        return "{#9932CC}"
    elseif state == "max" then
        return "{#98FB98}"
    elseif state == "near" then
        return "{#FFA500}"
    end
    return "{#FFFFFF}"
end

-- そのアイテム(装備でもイコルでも可)における、そのオプションの min / max。
-- 素が 0,0 を返す(段のデータが無い / イコルが刺さっていない)ことがあるので、呼び側で見ること。
function Icor_planner_range(item_obj, opt)
    if shared_item_goddess_icor == nil or item_obj == nil then
        return 0, 0
    end
    local ok, min_value, max_value = pcall(shared_item_goddess_icor.get_option_value_range_icor, item_obj, opt, true)
    if not ok or type(max_value) ~= "number" then
        return 0, 0
    end
    return min_value or 0, max_value
end

-- 装備 1 部位ぶんのイコル情報を読む。
function Icor_planner_read_slot(slot_info)
    local entry = {
        slot_name = slot_info.slot_name,
        clmsg = slot_info.clmsg,
        options = {},
        spot = "None",
        equipped = false,
        -- 利用者が「計算しない」にした部位。オプションは読むが(内訳には出す)、
        -- 現在値・達成数・伸びしろでは載っていない扱いにする
        excluded = Icor_planner_is_excluded(slot_info.slot_name)
    }
    local spot_num = item.GetEquipSpotNum(slot_info.slot_name)
    if spot_num == nil then
        return entry
    end
    local inv_item = session.GetEquipItemBySpot(spot_num)
    if inv_item == nil then
        return entry
    end
    local item_obj = GetIES(inv_item:GetObject())
    if item_obj == nil then
        return entry
    end
    entry.equipped = true
    entry.item_obj = item_obj
    entry.name = dictionary.ReplaceDicIDInCompStr(TryGetProp(item_obj, "Name", ""))
    local group_name = TryGetProp(item_obj, "GroupName", "None")
    if group_name == "Armor" then
        entry.spot = "Armor"
    elseif string.find(group_name, "Weapon") ~= nil then
        entry.spot = "Weapon"
    end
    if TryGetProp(item_obj, "ClassType", "None") == "Shield" then
        entry.spot = "Weapon"
    end
    entry.icor_name = TryGetProp(item_obj, "GoddessIcorName", "None")
    local dic = GET_ITEM_RANDOMOPTION_DIC(item_obj)
    local size = (dic and dic["Size"]) or 0
    for j = 1, size do
        local opt = dic["RandomOption_" .. j]
        local value = tonumber(dic["RandomOptionValue_" .. j]) or 0
        if opt ~= nil and opt ~= "None" then
            local _, max_value = Icor_planner_range(item_obj, opt)
            entry.options[#entry.options + 1] = {
                opt = opt,
                value = value,
                group = dic["RandomOptionGroup_" .. j],
                max = max_value,
                state = Icor_planner_value_state(value, max_value)
            }
        end
    end
    -- 試算中は、差し替えた部位の中身を差し替えるイコルのものにする。
    -- 差し替えた部位は「計算しない」より優先する(替えた姿を見たいので)
    local swap = g.icor_planner_trial_on and Icor_planner_trial_swaps()[slot_info.slot_name]
    if swap then
        entry.real_options = entry.options
        entry.options = swap.options
        entry.swapped = swap
        -- **元が「更新するイコル」だったことは残す。** 差し替えた部位は計算に入れるが、
        -- 数え方(更新するイコルを組む / 今の装備に足す)まで入れ替わると、差し替えの前後で
        -- 別の物差しの数を比べることになる(手袋を差し替えたら あと 1 → 7 と出た。実機で指摘された)
        entry.was_excluded = entry.excluded
        entry.excluded = false
    end
    return entry
end

-- 8 部位のイコルを読む。**ここで合計は作らない。**
-- 現在値はステータス画面と同じものを Icor_planner_current が PC から取る。
-- ここが持つのは「どの部位のどの枠に何が載っているか」= 更新の対象を決める材料。
-- 装備 8 部位の読み取りは**溜める**。
--
-- 1 回の組み立てで、診断・オススメ(平均と最低の 2 通り)・それ以外の分の引き算から
-- 何度も呼ばれる。1 回の読み取りで GET_ITEM_RANDOMOPTION_DIC と素の範囲引きが
-- 最大 32 回走るので、そのままだと**同じ内容を何十回も読み直す**ことになる
-- (ログイン後にマーケットを初めて開いたときが特に重かった。実機で指摘された)。
-- 中身が変わる操作(装備替え・差し替えの試算・「更新するイコル」の切り替え)では
-- Icor_planner_reset_scan() で捨てる。
function Icor_planner_reset_scan()
    g.icor_planner_scan_cache = nil
end

function Icor_planner_scan()
    -- 試算中は差し替えた姿を読むので、別の溜め込みにする
    local key = g.icor_planner_trial_on and "trial" or "real"
    g.icor_planner_scan_cache = g.icor_planner_scan_cache or {}
    if g.icor_planner_scan_cache[key] then
        return g.icor_planner_scan_cache[key]
    end
    local scan = {
        slots = {},
        spot_max = {}
    }
    for i, slot_info in ipairs(g.icor_planner_slots) do
        local entry = Icor_planner_read_slot(slot_info)
        scan.slots[i] = entry
        if entry.equipped then
            -- 「その部位のイコル 1 枠で狙える最大値」の入れ物。引くたびに素を叩かず
            -- ここへ溜める(1 回の診断で同じ部位 × 同じオプションを何度も引くため)
            scan.spot_max[i] = {}
        end
    end
    g.icor_planner_scan_cache[key] = scan
    return scan
end

function Icor_planner_slot_max(scan, slot_index, opt)
    local cache = scan.spot_max[slot_index]
    if not cache then
        return 0
    end
    if cache[opt] == nil then
        local _, max_value = Icor_planner_range(scan.slots[slot_index].item_obj, opt)
        cache[opt] = max_value or 0
    end
    return cache[opt]
end

-- ===== 目標値の目安 =====
--
-- 相殺(*_Def)。**これは合計でしか意味を持たない**ので、各部位へは切り替えさせない。
-- 目安も「1 枠の範囲」ではなく、ステータス画面の割合が 50% になる値を出す。
g.icor_planner_counter_opts = {
    Cloth_Def = true,
    Leather_Def = true,
    Iron_Def = true,
    MiddleSize_Def = true
}

function Icor_planner_is_counter(opt)
    return g.icor_planner_counter_opts[opt] == true
end

-- ステータス画面の割合がちょうど half(0〜1)になる値。
--
-- 素の get_calc_atk_value_for_status は 値 / (Lv × ITEM_ATK_POINT_MULTIPLE × 1.5) × 100。
-- ITEM_ATK_POINT_MULTIPLE はクライアントのグローバル(sharedscript.lua で 20)なので読める。
-- **式が変わっても黙って古い値を出さないよう、素の関数で答え合わせをする。**
-- 出した値を素へ通して割合が合わなければ、測った割合から比例で直す(素が唯一の基準)。
function Icor_planner_value_at_percent(opt, half)
    local pc = GetMyPCObject()
    if pc == nil then
        return 0
    end
    local lv = tonumber(TryGetProp(pc, "Lv", 0)) or 0
    local multiple = tonumber(_G["ITEM_ATK_POINT_MULTIPLE"]) or 20
    if lv <= 0 then
        return 0
    end
    local value = math.floor(lv * multiple * 1.5 * half)
    -- 答え合わせ。素が返す割合を読み、ずれていれば比例で寄せる
    local measured = Icor_planner_percent(opt, value)
    if measured then
        local got = tonumber(string.match(measured, "([%-%d%.]+)"))
        if got and got > 0 then
            local want = half * 100
            if math.abs(got - want) > 0.15 then
                local fixed = math.floor(value * want / got)
                g.vlog("icor_planner: %s の %d%% 値を素に合わせて %d -> %d へ直した", tostring(opt), want,
                    value, fixed)
                value = fixed
            end
        end
    end
    return value
end

-- 今の最大レベルのイコル 1 枚における、そのオプションの min / max。
--
-- **素の get_option_value_range_icor はアイテムから レベル / 部位 / 上級下級 を読む**ので、
-- その 3 つだけを持つ表を渡して試す。通れば段が増えても自動で追従する。
-- 通らないクライアントでは、手持ち(装備・インベントリ)で見つけた一番上のイコルで代用する。
-- その部位でイコルが存在する一番上のレベル。
--
-- **値を読む表そのもの(item_goddess_icor_range)で判定する。**
-- 以前は候補一覧の表(option_list_by_group)を探って決めていたが、こちらは段の入り方が違い、
-- **Lv560 のイコルがあるのに 540 と判定される**ことがあった(実機で確認)。
-- 範囲を引くのに使うのは item_goddess_icor_range の方なので、そちらを直接叩いて決める。
--
-- 上から下りて、最初に値が返った段を採る。STR はどの段・どちらの部位にもある。
function Icor_planner_detect_max_lv(spot)
    g.icor_planner_detected_lv = g.icor_planner_detected_lv or {}
    local cached = g.icor_planner_detected_lv[spot]
    if cached ~= nil then
        return cached or nil
    end
    local found = nil
    for lv = 800, 480, -20 do
        local stub = {
            GroupName = "Icor",
            StringArg = "GoddessIcor",
            NumberArg1 = 20,
            StringArg2 = spot,
            UseLv = lv
        }
        local ok, _, max_value = pcall(shared_item_goddess_icor.get_option_value_range_icor, stub, "STR", true)
        if ok and type(max_value) == "number" and max_value > 0 then
            found = lv
            break
        end
    end
    if found == nil then
        -- 表を直接叩けないクライアント。候補一覧の探索で分かった段へ落ちる
        found = (g.icor_planner_max_lv or {})[spot]
    end
    g.icor_planner_detected_lv[spot] = found or false
    -- **判断の材料を残す。** 「目安の値が古い段のものになっている」と言われたとき、
    -- どの段だと判定したのかがログから分かる
    g.vlog("icor_planner: %s のイコル最大レベルを %s と判定(候補一覧の探索では %s)", tostring(spot),
        tostring(found), tostring((g.icor_planner_max_lv or {})[spot]))
    return found
end

-- マーケットの件数が変わったら、範囲まわりの溜め込みを捨てる。
-- 検索し直すと並ぶ品が入れ替わるので、前の検索の結果を握ったままだと新しい段を拾えない。
-- **捨てるのは溜め込みを読み書きする前に限ること。** 書き込みの途中(Icor_planner_top_range が
-- 素を引いて結果を入れる直前)で捨てると、nil へ添字して落ちる。実際にそうなっていて、
-- 目標タブを開いた 1 回目だけ先頭の行で描画が止まっていた(2 回目は件数が変わらないので通る)
function Icor_planner_check_market_change()
    local ok_n, n = pcall(session.market.GetItemCount)
    n = (ok_n and type(n) == "number") and n or -1
    if g.icor_planner_best_icor_market_n ~= n then
        g.icor_planner_best_icor_market_n = n
        g.icor_planner_best_icor = nil
        g.icor_planner_top_range_cache = nil
    end
    return n
end

function Icor_planner_top_range(opt, spot)
    -- **溜めること。** 候補の評価から 1 枚ごとに呼ばれるので、素への pcall が
    -- 出品の件数 × 目標の数だけ走ってしまう。レベルと部位で決まるので使い回せる
    Icor_planner_check_market_change()
    g.icor_planner_top_range_cache = g.icor_planner_top_range_cache or {}
    local key = tostring(opt) .. "/" .. tostring(spot)
    local cached = g.icor_planner_top_range_cache[key]
    if cached ~= nil then
        return cached[1], cached[2], cached[3], cached[4]
    end
    local min_value, max_value, lv, src = Icor_planner_top_range_uncached(opt, spot)
    -- 素を引いている間に溜め込みが捨てられていても落ちないよう、入れる直前にも用意する
    g.icor_planner_top_range_cache = g.icor_planner_top_range_cache or {}
    g.icor_planner_top_range_cache[key] = {min_value, max_value, lv, src}
    -- **どこから取った値かを 1 回だけ残す。** 「目安が古い段の値になっている」と
    -- 言われたとき、実物から取れたのか素の表から取れたのかがログで分かる
    g.vlog("icor_planner: %s/%s の範囲 %s〜%s (Lv%s / %s)", tostring(opt), tostring(spot),
        tostring(min_value), tostring(max_value), tostring(lv),
        (src == "item") and "手持ちのイコルから" or ((src == "table") and "素の表から" or "取れなかった"))
    return min_value, max_value, lv, src
end

function Icor_planner_top_range_uncached(opt, spot)
    -- **対象が「両方」なら、武器と防具の**小さい方**を採る。** 同じオプションでも
    -- 1 枚に載る値は部位で違う(素の表が別)。大きい方を目安にすると、
    -- 小さい方の部位では**どのイコルでも届かない目標**になってしまう
    if spot == "both" then
        local w_min, w_max, w_lv, w_src = Icor_planner_top_range(opt, "Weapon")
        local a_min, a_max, a_lv, a_src = Icor_planner_top_range(opt, "Armor")
        if w_max <= 0 then
            return a_min, a_max, a_lv, a_src
        end
        if a_max <= 0 then
            return w_min, w_max, w_lv, w_src
        end
        -- **小さい方を採る。** 同じオプションでも 1 枚に載る値は部位で違うので、
        -- 大きい方を目安にすると小さい方の部位ではどのイコルでも届かない目標になる
        return math.min(w_min, a_min), math.min(w_max, a_max), math.max(w_lv or 0, a_lv or 0), "both"
    end
    -- **「一番上の段」を目安にする。** 見付け方は 2 通りあり、どちらも単独では足りない。
    --   実物(装備・インベントリ・マーケット) … 素がそのイコルに合った範囲を返すので確実だが、
    --                                          **手元に古い段しか無ければその段止まり**になる
    --   レベルを渡して素の表を引く         … 手元に無い段も引けるが、クライアントの表に
    --                                          その段が無ければ引けない
    -- なので**両方を見て、レベルの高い方を採る**。540 のイコルを着けていても、
    -- 素の表に 560 があればそちらの範囲が出る。
    local ref = Icor_planner_best_icor_class(spot)
    local lv = Icor_planner_detect_max_lv(spot)
    if ref ~= nil and (lv == nil or ref.lv >= lv) then
        local min_value, max_value = Icor_planner_range(ref.obj, opt)
        if max_value > 0 then
            return min_value, max_value, ref.lv, "item"
        end
    end
    if lv ~= nil then
        local stub = {
            GroupName = "Icor",
            StringArg = "GoddessIcor",
            NumberArg1 = 20,
            StringArg2 = spot,
            UseLv = lv
        }
        local ok, min_value, max_value = pcall(shared_item_goddess_icor.get_option_value_range_icor, stub, opt, true)
        if ok and type(max_value) == "number" and max_value > 0 then
            return min_value or 0, max_value, lv, "table"
        end
    end
    -- 素の表から引けなかった(そのオプションが表に無い等)。実物があるならそちらへ戻る
    if ref ~= nil then
        local min_value, max_value = Icor_planner_range(ref.obj, opt)
        if max_value > 0 then
            return min_value, max_value, ref.lv, "item"
        end
    end
    return 0, 0, lv, "none"
end

-- 目安に使うイコル(部位ごとに一番レベルの高いもの)。実物を
-- get_option_value_range_icor へ渡すのが一番正確なので、これを先に探す。
-- 見るのは 3 か所: 装備に刺さっているもの / インベントリ / マーケットの出品。
function Icor_planner_best_icor_class(spot)
    local n = Icor_planner_check_market_change()
    g.icor_planner_best_icor = g.icor_planner_best_icor or {}
    if g.icor_planner_best_icor[spot] ~= nil then
        return g.icor_planner_best_icor[spot] or nil
    end
    local best = nil
    local function consider(obj)
        if obj == nil then
            return
        end
        if TryGetProp(obj, "StringArg2", "None") ~= spot then
            return
        end
        local lv = tonumber(TryGetProp(obj, "UseLv", 0)) or 0
        if best == nil or lv > best.lv then
            best = {
                obj = obj,
                lv = lv
            }
        end
    end
    for _, slot_info in ipairs(g.icor_planner_slots) do
        local spot_num = item.GetEquipSpotNum(slot_info.slot_name)
        local inv_item = spot_num and session.GetEquipItemBySpot(spot_num)
        local item_obj = inv_item and GetIES(inv_item:GetObject())
        local icor_name = item_obj and TryGetProp(item_obj, "GoddessIcorName", "None")
        if icor_name ~= nil and icor_name ~= "None" then
            consider(GetClass("Item", icor_name))
        end
    end
    -- **素の表で引ける段に届いていれば、そこで探索を打ち切る。**
    -- 下のインベントリ / マーケットの走査は 1 件ずつ GetIES を呼ぶので、持ち物が多いと
    -- 目に見えて時間がかかる(ログイン後の初回が特に重かった。実機で指摘された)。
    -- 素の表の段より高いイコルは存在しないので、そこへ届いたら探す意味が無い
    local top_lv = Icor_planner_detect_max_lv(spot)
    if best ~= nil and top_lv ~= nil and best.lv >= top_lv then
        g.icor_planner_best_icor[spot] = best
        g.vlog("icor_planner: %s の目安は装備のイコル Lv%s で足りる(探索を打ち切り)", tostring(spot),
            tostring(best.lv))
        return best
    end
    local inv_list = session.GetInvItemList()
    if inv_list ~= nil then
        local guid_list = inv_list:GetGuidList()
        for i = 0, guid_list:Count() - 1 do
            local inv_item = inv_list:GetItemByGuid(guid_list:Get(i))
            local obj = inv_item and GetIES(inv_item:GetObject())
            if obj ~= nil and TryGetProp(obj, "GroupName", "None") == "Icor" then
                consider(obj)
            end
        end
    end
    if best ~= nil and top_lv ~= nil and best.lv >= top_lv then
        g.icor_planner_best_icor[spot] = best
        g.vlog("icor_planner: %s の目安はインベントリの Lv%s で足りる(マーケットは見ない)", tostring(spot),
            tostring(best.lv))
        return best
    end
    -- **マーケットに並んでいるイコルも見る。** 装備にもインベントリにも無い部位だと
    -- 素の表(レベル指定)へ落ちてしまい、そちらは実物より古い段で頭打ちになることがある。
    -- マーケットを眺めている間は最新の段が並んでいるので、そこから拾えれば正確になる
    if n > 0 then
        for i = 0, n - 1 do
            local ok_item, market_item = pcall(session.market.GetItemByIndex, i)
            if ok_item and market_item ~= nil then
                local ok_obj, obj = pcall(function()
                    return GetIES(market_item:GetObject())
                end)
                if ok_obj and obj ~= nil and TryGetProp(obj, "GroupName", "None") == "Icor" then
                    consider(obj)
                end
            end
        end
    end
    g.icor_planner_best_icor[spot] = best or false
    -- **見つからなかったことを残す。** 見つからないと素の表(レベル指定)へ落ちるが、
    -- そちらは実物より古い段で頭打ちになることがある。目安の値が低いときの手掛かり
    if best == nil then
        g.vlog("icor_planner: %s のイコルが見つからない(装備・インベントリ・マーケットとも)", tostring(spot))
    else
        g.vlog("icor_planner: %s の目安に使うイコルは Lv%s", tostring(spot), tostring(best.lv))
    end
    return best
end

-- ===== 診断 =====
--
-- 目標ごとに「不足」と「必要な枠数」を出し、枠を部位へ割り当ててイコル個数へ換算する。
--
-- 枠の割り当ては素直な貪欲法にしてある。厳密な最適割り当ては組合せの問題になるが、
--   * 1 つのイコルに同じオプションは 2 つ載らない(素の is_valid_reroll_option)
--   * 部位ごとに 1 枠あたりの最大値が違う(Weapon と Armor で別)
-- の 2 つを守れば実用上の数字は出る。**前提(1 枠には最大値が付く)を画面に出す**ことで、
-- 利用者が「その前提なら何個」と読み替えられるようにする方を取った。
function Icor_planner_diagnose()
    local preset = Icor_planner_cur_preset()
    -- **毎回読み直す。** 装備を替えた後に「再計算」を押したら、その姿で出したい
    Icor_planner_reset_scan()
    local scan = Icor_planner_scan()
    local result = {
        rows = {},
        used_slots = {},
        total_slots = 0,
        total_icors = 0,
        max_option_count = 4,
        -- 「各部位に載せたい」目標。合計の目標(rows)とは数え方が違うので分けて持つ
        slot_rows = {},
        -- 部位(Weapon / Armor)ごとに、イコルを挿せる装備が何か所あるか。
        -- 候補の評価を「1 部位ぶんのノルマに対して何割か」で出すのに使う
        -- **数え方が 2 通りあるので分けて持つ。**
        --   spot_slots … 実際に装備している数。武器 4(セット 1・2 のメイン/サブ) / 防具 4。
        --                4 本すべてがキャラの合計に効くので、**目標値の ％ と達成数**はこちら
        --   spot_icors … イコルとして何個要るか。武器は持ち替えで**1 個が 2 か所ぶん働く**ので
        --                武器 2 / 防具 4。**1 枚としての目安(割合の分母)**はこちら
        -- 片方だけで済ませようとして、％ が半分になる誤りを出した(実機で指摘された)。
        spot_slots = {},
        spot_icors = {}
    }
    for _, entry in ipairs(scan.slots) do
        if entry.equipped and entry.spot ~= "None" then
            result.spot_slots[entry.spot] = (result.spot_slots[entry.spot] or 0) + 1
            if not g.icor_planner_sub_slots[entry.slot_name] then
                result.spot_icors[entry.spot] = (result.spot_icors[entry.spot] or 0) + 1
            end
        end
    end
    if shared_item_goddess_icor ~= nil then
        local ok, count = pcall(shared_item_goddess_icor.get_max_option_count)
        if ok and type(count) == "number" and count > 0 then
            result.max_option_count = count
        end
    end
    if not preset then
        return result, scan
    end
    -- 部位ごとの空き枠。「今刺さっているイコルを丸ごと入れ替える」前提なので、
    -- 装備している部位はどれも max_option_count 枠ぶん使える扱いにする
    local free, assigned, have = {}, {}, {}
    for i, entry in ipairs(scan.slots) do
        free[i] = entry.equipped and result.max_option_count or 0
        assigned[i] = {}
        -- **その部位に既にそのオプションが載っているなら、伸びしろは max - 今の値**。
        -- 現在値がステータスの合計になった以上、ここを見ないと「もう最大値が付いている枠」を
        -- もう一度 +max と数えてしまい、必要な数を少なく見積もる
        have[i] = {}
        -- 計算しない部位は「何も載っていない」扱い(付け替える前提なので伸びしろは丸ごと)
        for _, op in ipairs(entry.excluded and {} or entry.options) do
            have[i][op.opt] = (have[i][op.opt] or 0) + op.value
        end
    end
    -- 不足の大きい目標から埋める。小さい目標を先に埋めると、枠が足りないときに
    -- 「大きい目標だけ丸ごと埋まらない」形になって読みにくい
    local order = {}
    for _, t in ipairs(preset.targets or {}) do
        local target_value = tonumber(t.value) or 0
        if Icor_planner_target_mode(t) == g.icor_planner_mode_slot then
            -- **各部位に載せたい目標。** 合計ではなく「載っている部位の数」で見る。
            -- 入力欄の値は「1 枠あたりの最低値」(0 = 付いてさえいればよい)
            local row = {
                opt = t.opt,
                spot = Icor_planner_target_spot(t),
                min_value = target_value,
                slots = {},
                have = 0,
                want = 0
            }
            for i, entry in ipairs(scan.slots) do
                -- **達成数は実際に装備している数で数える**(セット 2 も含む)。
                -- 4 本すべてがキャラの合計に効くので、セット 2 に載っていなければ未達
                if entry.equipped and Icor_planner_target_applies(t, entry.spot) then
                    row.want = row.want + 1
                    local value = Icor_planner_entry_value(entry, t.opt)
                    local ok = (value > 0) and (value >= row.min_value)
                    if ok then
                        row.have = row.have + 1
                    end
                    row.slots[i] = {
                        value = value,
                        ok = ok
                    }
                end
            end
            -- **何部位まで目指すかは利用者が絞れる**(既定 = 装備している数 = 上限)。
            -- 「全部位でなくてよい、2 部位に載っていれば十分」という組み方のため
            row.max_count = row.want
            row.want = Icor_planner_target_count(t, row.want)
            -- **目指す数に足りない分がそのまま「更新が要るオプションの数」。**
            -- 目標値(1 枠あたりの最低値)に届いていない枠も数に入る
            row.slots_needed = math.max(0, row.want - row.have)
            result.total_slots = result.total_slots + row.slots_needed
            result.slot_needed_total = (result.slot_needed_total or 0) + row.slots_needed
            result.slot_rows[#result.slot_rows + 1] = row
        elseif target_value > 0 then
            -- **ステータス画面と同じ値**を現在値にする(イコル由来の分だけではない)
            local cur = Icor_planner_current(t.opt)
            order[#order + 1] = {
                opt = t.opt,
                -- **合計の目標にも対象部位を持たせる。** 「相殺は防具のイコルで狙う」
                -- のように、どの部位に載せたいかは合計でも意味がある
                -- (武器は 1 本で 2 か所ぶん働くので、相殺のような数を稼ぐものは
                --  載せたくない、という判断ができる)
                spot = Icor_planner_target_spot(t),
                target = target_value,
                cur = cur,
                short = math.max(0, target_value - cur)
            }
        end
    end
    table.sort(order, function(a, b)
        if a.short ~= b.short then
            return a.short > b.short
        end
        return a.opt < b.opt
    end)
    for _, row in ipairs(order) do
        local remain = row.short
        local slots_used = 0
        local per_slot = {}
        -- 1 枠あたりの取り分が大きい部位から使う
        while remain > 0 do
            local best_index, best_gain = nil, 0
            for i = 1, #scan.slots do
                if free[i] > 0 and not assigned[i][row.opt] then
                    local gain = Icor_planner_slot_max(scan, i, row.opt) - (have[i][row.opt] or 0)
                    if gain > best_gain then
                        best_index, best_gain = i, gain
                    end
                end
            end
            if best_index == nil then
                break
            end
            free[best_index] = free[best_index] - 1
            assigned[best_index][row.opt] = true
            result.used_slots[best_index] = true
            per_slot[#per_slot + 1] = {
                slot = best_index,
                gain = best_gain
            }
            slots_used = slots_used + 1
            remain = remain - best_gain
        end
        -- **1 か所あたりの平均から必要数を出す。**
        -- 目標値をその目標が載る部位数で割ったものが「1 枠が受け持つ量」。
        -- 不足をそれで割れば、あと何枠のオプションを更新すればよいかが出る。
        -- (以前は「その部位で狙える最大値」で割っていたが、最大値が付く前提は強すぎた)
        local pieces = Icor_planner_target_pieces(result, row.spot)
        row.pieces = pieces
        row.per_slot_value = (pieces > 0) and (row.target / pieces) or 0
        if row.short <= 0 or row.per_slot_value <= 0 then
            row.slots_needed = 0
        else
            row.slots_needed = math.ceil(row.short / row.per_slot_value)
            -- 枠は部位数までしか無い
            if row.slots_needed > pieces then
                row.slots_needed = pieces
                row.remain = row.short - pieces * row.per_slot_value
            end
        end
        row.total_needed = row.slots_needed
        row.per_slot = per_slot
        row.remain = math.max(0, remain)
        -- 突破(floor(max*1.5)-1)が出たときに何枠で済むか。狙って出るものではないので
        -- 判定には使わず、参考として並べるだけにする
        if row.short > 0 and #per_slot > 0 then
            local brk_remain, brk_slots = row.short, 0
            for _, ps in ipairs(per_slot) do
                if brk_remain <= 0 then
                    break
                end
                brk_remain = brk_remain - Icor_planner_break_limit(ps.gain)
                brk_slots = brk_slots + 1
            end
            row.slots_needed_break = brk_slots
        end
        result.rows[#result.rows + 1] = row
        result.total_slots = result.total_slots + row.slots_needed
        result.sum_needed_total = (result.sum_needed_total or 0) + row.slots_needed
    end
    -- **割り当ては不足の大きい順、表示は並び順。** 枠の取り合いは大きい方から埋めないと
    -- 「大きい目標だけ丸ごと届かない」形になるが、画面の並びが毎回変わると読みにくい。
    -- 計算と表示で順序を分ける
    local by_order = function(a, b)
        local oa, ob = Icor_planner_order_of(a.opt), Icor_planner_order_of(b.opt)
        if oa ~= ob then
            return oa < ob
        end
        return a.opt < b.opt
    end
    table.sort(result.rows, by_order)
    table.sort(result.slot_rows, by_order)
    -- **目標タブで「計算しない」にした部位は、更新するイコルとして必ず ★ にする**
    for i, entry in ipairs(scan.slots) do
        if entry.equipped and entry.excluded then
            result.used_slots[i] = true
        end
    end
    for _ in pairs(result.used_slots) do
        result.total_icors = result.total_icors + 1
    end
    return result, scan
end

-- その目標が載る装備の数。両方なら武器 + 防具。
-- **実際に装備している数**を使う(4 本の武器はすべて合計に効く)。
function Icor_planner_target_pieces(result, spot)
    local slots = result.spot_slots or {}
    if spot == "Weapon" or spot == "Armor" then
        return slots[spot] or 0
    end
    return (slots.Weapon or 0) + (slots.Armor or 0)
end

-- ===== オススメのイコル構成 =====
--
-- 目標を満たすには、武器イコル / 防具イコルに**それぞれ何を何個ずつ**載せればよいか。
-- **部位の種類ごとに理想の 1 形**を出す(今のイコルに合わせた部位ごとの形ではない)。
--
-- 素の決まりで守るのは 3 つだけ(グループの数に縛りは無い。ATK が 3 つ載ったイコルもある)。
--   * 1 つのイコルに載るのは max_option_count 枠まで
--   * 同じオプションは 1 つのイコルに 1 つまで → 1 つのオプションを載せられるのはイコルの個数まで
--   * 部位で載るオプションが決まっている(Icor_planner_spot_can)
-- 「オプション o をイコル c_o 個に載せる」と数だけ決めれば、c_o <= 個数 かつ 合計 <= 枠数 のとき
-- 実際に 1 個ずつへ配る並べ方は必ず作れる(順に回して配ればよい)ので、数だけを決める。
--
-- 1 枠の値は assumption で決める。
--   "avg" … 一番上の段の (最小 + 最大) / 2
--   "min" … 一番上の段の最小値(マーケットで一番見つけやすい線)
function Icor_planner_assumed_value(opt, spot, assumption)
    local min_value, max_value = Icor_planner_top_range(opt, spot)
    if max_value <= 0 then
        return 0
    end
    if assumption == "min" then
        return min_value
    end
    return math.floor((min_value + max_value) / 2)
end

function Icor_planner_recommend(diag, scan, assumption)
    local per_icor = diag.max_option_count or 4
    -- **更新するイコル(目標タブで「計算しない」にした部位)があれば、そこだけを組む。**
    -- 残すイコルは今の値のまま(現在値・達成数は既にそれで出ている)として、足りない分を
    -- 更新するイコルに何を載せれば埋まるかを出す。無ければ全部位の理想の形を出す。
    -- 武器は持ち替えの表と裏(RH と RH_SUB)を 1 個として数える(1 個で 2 か所に効くため)
    local update_pairs = {
        Weapon = {},
        Armor = {}
    }
    local update_mode = Icor_planner_update_mode(scan)
    for _, entry in ipairs(scan.slots) do
        if entry.equipped and entry.excluded and update_pairs[entry.spot] then
            update_pairs[entry.spot][string.gsub(entry.slot_name, "_SUB$", "")] = true
        end
    end
    local types = {}
    for _, spot in ipairs({"Weapon", "Armor"}) do
        local all_icors = (diag.spot_icors and diag.spot_icors[spot]) or 0
        local slots = (diag.spot_slots and diag.spot_slots[spot]) or 0
        local icors = all_icors
        if update_mode then
            icors = 0
            for _ in pairs(update_pairs[spot]) do
                icors = icors + 1
            end
        end
        types[spot] = {
            spot = spot,
            icors = icors,
            -- 1 個が何か所に効くか。武器は持ち替えで 2 か所(セット 1 / 2)
            places = (all_icors > 0) and (slots / all_icors) or 0,
            free = icors * per_icor,
            counts = {},
            order = {}
        }
    end
    local placed = {} -- opt -> 置いた分がキャラの合計をいくつ押し上げるか
    local function put(opt, spot, n)
        local tp = types[spot]
        if n <= 0 or tp.icors <= 0 then
            return 0
        end
        local room = math.min(n, tp.icors - (tp.counts[opt] or 0), tp.free)
        if room <= 0 then
            return 0
        end
        if tp.counts[opt] == nil then
            tp.order[#tp.order + 1] = opt
        end
        tp.counts[opt] = (tp.counts[opt] or 0) + room
        tp.free = tp.free - room
        placed[opt] = (placed[opt] or 0) + room * tp.places * Icor_planner_assumed_value(opt, spot, assumption)
        return room
    end
    -- (1) 各部位の目標を先に置く。目指す部位数(want は「か所」)をイコルの個数へ直す。
    -- 「両方」は武器から埋める(1 枠で 2 か所に効くので、同じ枠数で多くのか所を満たせる)
    local slot_min = {} -- opt -> 各部位の目標値(1 枠の最低値)。検索の下限に使う
    local slot_unmet = {} -- opt -> 置ききれなかったか所の数
    for _, row in ipairs(diag.slot_rows or {}) do
        local want = row.want or 0
        if update_mode then
            -- 残すイコルに載っている分は満たしているので、足りない分だけを更新するイコルへ
            want = math.max(0, want - (row.have or 0))
        end
        if (row.min_value or 0) > (slot_min[row.opt] or 0) then
            slot_min[row.opt] = row.min_value
        end
        local spots = (row.spot == "Weapon" or row.spot == "Armor") and {row.spot} or {"Weapon", "Armor"}
        for _, spot in ipairs(spots) do
            local tp = types[spot]
            if want > 0 and tp.places > 0 and Icor_planner_spot_can(row.opt, spot) then
                local n = math.min(tp.icors, math.ceil(want / tp.places))
                local got = put(row.opt, spot, n)
                want = want - got * tp.places
            end
        end
        -- 置ききれなかったか所(更新するイコル / 載せられる場所が足りない)
        if want > 0 then
            slot_unmet[row.opt] = (slot_unmet[row.opt] or 0) + want
        end
    end
    -- (2) 合計の目標。イコルで持つ量 = 目標 - それ以外 - (1) で置いた分。
    -- 同じ項目が複数行あるときは、目標は大きい方、置ける部位は行の部位を合わせたもの
    local needs, allowed, order = {}, {}, {}
    local others = {}
    for _, row in ipairs(diag.rows or {}) do
        if (row.target or 0) > 0 then
            if needs[row.opt] == nil then
                order[#order + 1] = row.opt
                others[row.opt] = Icor_planner_other_sources(row.opt)
                needs[row.opt] = 0
                allowed[row.opt] = {}
            end
            -- 理想の形: イコルで持つ量 = 目標 - それ以外。
            -- 更新するイコルがあるとき: 残すイコルの分は今の値に入っているので、目標 - 今の値
            local need = row.target - others[row.opt]
            if update_mode then
                need = row.target - (row.cur or 0)
            end
            needs[row.opt] = math.max(needs[row.opt], need)
            if row.spot == "Weapon" or row.spot == "Armor" then
                allowed[row.opt][row.spot] = true
            else
                allowed[row.opt].Weapon = true
                allowed[row.opt].Armor = true
            end
        end
    end
    for _, opt in ipairs(order) do
        needs[opt] = needs[opt] - (placed[opt] or 0)
    end
    -- 残りの枠を、1 枠で一番多く埋まるところから置いていく。
    -- 1 枠の効き = 1 枠の値 × その部位の 1 個が効くか所数。届いた項目はそれ以上置かない
    while true do
        local best_opt, best_spot, best_gain = nil, nil, 0
        for _, opt in ipairs(order) do
            if needs[opt] > 0 then
                for _, spot in ipairs({"Weapon", "Armor"}) do
                    local tp = types[spot]
                    if allowed[opt][spot] and tp.free > 0 and (tp.counts[opt] or 0) < tp.icors and
                        Icor_planner_spot_can(opt, spot) then
                        local gain = math.min(needs[opt],
                            tp.places * Icor_planner_assumed_value(opt, spot, assumption))
                        if gain > best_gain then
                            best_opt, best_spot, best_gain = opt, spot, gain
                        end
                    end
                end
            end
        end
        if best_opt == nil then
            break
        end
        local before = placed[best_opt] or 0
        put(best_opt, best_spot, 1)
        needs[best_opt] = needs[best_opt] - ((placed[best_opt] or 0) - before)
    end
    -- (3) 今のイコルと突き合わせる。**持ち替え側(SUB)は数えない**(表のイコルと同じ 1 個として扱う)。
    -- その値(assumption の値)以上で載っているイコルの数を「今」とし、足りない分が更新の数
    local updates = 0
    for spot, tp in pairs(types) do
        tp.have = {}
        tp.updates = 0
        for _, opt in ipairs(tp.order) do
            local have = 0
            -- 更新するイコルは新しく買う前提なので「今」は数えない(全部が更新の数)
            if not update_mode then
                local value = Icor_planner_assumed_value(opt, spot, assumption)
                for _, entry in ipairs(scan.slots) do
                    if entry.equipped and entry.spot == spot and not g.icor_planner_sub_slots[entry.slot_name] then
                        local cur = Icor_planner_entry_value(entry, opt)
                        if cur > 0 and cur >= value then
                            have = have + 1
                        end
                    end
                end
            end
            tp.have[opt] = have
            tp.updates = tp.updates + math.max(0, tp.counts[opt] - have)
        end
        updates = updates + tp.updates
        tp.sets = Icor_planner_split_sets(tp, per_icor)
    end
    local unmet = {}
    for _, opt in ipairs(order) do
        if needs[opt] > 0 then
            unmet[#unmet + 1] = {
                opt = opt,
                short = needs[opt]
            }
        end
    end
    g.vlog("icor_planner: オススメ構成(%s) 武器 空き %d / 防具 空き %d / 更新 %d / 届かない %d 件", tostring(assumption),
        types.Weapon.free, types.Armor.free, updates, #unmet)
    local total_opts = {}
    for _, opt in ipairs(order) do
        total_opts[opt] = true
    end
    -- オプションごとのまとめ。診断の目標の一覧は**これを使って**「あと何個」「届かない」を出す
    -- (以前は一覧だけ別の簡易な計算で、オススメと食い違っていた。実機で指摘された)
    local by_opt = {}
    for _, tp in pairs(types) do
        for _, opt in ipairs(tp.order) do
            local o = by_opt[opt] or {
                count = 0,
                updates = 0
            }
            o.count = o.count + tp.counts[opt]
            o.updates = o.updates + math.max(0, tp.counts[opt] - (tp.have[opt] or 0))
            by_opt[opt] = o
        end
    end
    local unmet_by_opt = {}
    for _, u in ipairs(unmet) do
        unmet_by_opt[u.opt] = u.short
    end
    return {
        types = types,
        updates = updates,
        unmet = unmet,
        unmet_by_opt = unmet_by_opt,
        slot_unmet = slot_unmet,
        by_opt = by_opt,
        update_mode = update_mode,
        slot_min = slot_min,
        total_opts = total_opts,
        assumption = assumption
    }
end

-- 「更新するイコル」を組む数え方か。目標タブで選んだ部位があれば true。
-- **試算で差し替えた部位も、元が更新するイコルなら数える**(entry.was_excluded)。
-- 差し替えた部位は更新する枠には入らないので、全部差し替えれば更新する枠 0 個の組み方になり、
-- 目標に届いていれば 0 個、届かなければ「届かない」と出る
function Icor_planner_update_mode(scan)
    for _, entry in ipairs(scan.slots) do
        if entry.equipped and (entry.excluded or entry.was_excluded) then
            return true
        end
    end
    return false
end

-- 「あとオプション N 個」の数え方を選ぶ。診断の見出し・目標の一覧・試算の比較はすべてここを通す。
--   更新するイコルあり … その部位に何を載せるか(Icor_planner_recommend)
--   無し               … 今の装備を残したまま、どこを変えれば届くか(Icor_planner_plan_keep)
function Icor_planner_plan(diag, scan, assumption)
    -- **どちらの数え方になったかと、その決め手を残す。** 試算の差し替えで数え方が入れ替わる
    -- 不具合(1 → 7)を直したので、実機で期待した分岐を通っているかを verbose_log.txt で確かめられるように
    -- する(更新する = excluded / 差し替えた元が更新する = was_excluded)
    local marks = {}
    for _, entry in ipairs(scan.slots) do
        if entry.equipped and (entry.excluded or entry.was_excluded) then
            marks[#marks + 1] = string.format("%s(%s)", entry.slot_name, entry.excluded and "excluded" or "was_excluded")
        end
    end
    g.vlog("icor_planner: 数え方 %s (%s) 決め手: %s", Icor_planner_update_mode(scan) and "更新するイコル" or
        "今の装備に足す", tostring(assumption), #marks > 0 and table.concat(marks, " / ") or "無し")
    if Icor_planner_update_mode(scan) then
        return Icor_planner_recommend(diag, scan, assumption)
    end
    return Icor_planner_plan_keep(diag, scan, assumption)
end

-- ===== 今の装備に足す形で数える =====
--
-- 「更新するイコル」を選んでいないときの「あとオプション」。**今のイコルを残したまま**、
-- 足りない分を埋めるには何枠を変えればよいかを数える。
-- 以前は理想の形(Icor_planner_recommend)との差を数えていたので、目標にほぼ届いていても
-- 載せ方が理想と違うだけで数が膨らんだ(レザー相殺だけ 1,104 足りないのに 7 個と出た。実機で指摘された)。
--
-- 変えてよい枠は次の 2 つだけ。
--   * 空いている枠
--   * 目標に無いオプションの枠(外しても目標は減らない)
-- 目標にあるオプションは外さない。値が見込みより低ければ、その枠の値を上げる(これも 1 個と数える)。
-- **部位は 1 か所ずつ数える。** 持ち替え側(セット 2)も別のイコルなので、変えるなら別の 1 個になる。
-- 戻り値は Icor_planner_recommend と同じ形(updates / by_opt / unmet / slot_unmet)に、
-- どこを何に変えるか(moves)を足したもの
function Icor_planner_plan_keep(diag, scan, assumption)
    local per_icor = diag.max_option_count or 4
    -- 目標にあるオプション(外さない)
    local wanted = {}
    for _, row in ipairs(diag.rows or {}) do
        if (row.target or 0) > 0 then
            wanted[row.opt] = true
        end
    end
    for _, row in ipairs(diag.slot_rows or {}) do
        wanted[row.opt] = true
    end
    -- **「全ての〜」でつながるオプションも外さない。** 今の値は「全ての〜」を足される先の項目
    -- (Icor_planner_current / g.icor_planner_all_members)から読むので、目標に無いオプションでも
    -- 目標の今の値を支えていることがある(目標が 全ての防具の材質 で、枠が クロース対象攻撃力、またはその逆)。
    -- 外すと目標が下がるのに、置いた側の増分だけを数えて少なく見積もってしまう
    local wanted_attr = {}
    for opt in pairs(wanted) do
        wanted_attr[Icor_planner_status_attr_of(opt)] = true
    end
    local function supports(opt)
        if wanted[opt] then
            return true
        end
        local attr = Icor_planner_status_attr_of(opt)
        if wanted_attr[attr] then
            return true
        end
        for all_attr, members in pairs(g.icor_planner_all_members) do
            local has_attr, has_wanted = attr == all_attr, wanted_attr[all_attr] == true
            for _, member in ipairs(members) do
                if member == attr then
                    has_attr = true
                end
                if wanted_attr[member] then
                    has_wanted = true
                end
            end
            -- 同じ「全ての〜」の輪の中で、片方が目標・片方がこの枠
            if has_attr and has_wanted and (attr == all_attr or wanted_attr[all_attr]) then
                return true
            end
        end
        return false
    end
    local units, by_index = {}, {}
    for i, entry in ipairs(scan.slots) do
        if entry.equipped and (entry.spot == "Weapon" or entry.spot == "Armor") then
            local unit = {
                index = i,
                slot_name = entry.slot_name,
                spot = entry.spot,
                values = {},
                -- 外してよい枠(目標に無いオプション)。値の小さいものから使う
                spare = {},
                empty = per_icor
            }
            for _, op in ipairs(entry.excluded and {} or entry.options) do
                unit.values[op.opt] = (unit.values[op.opt] or 0) + op.value
                unit.empty = unit.empty - 1
                if not supports(op.opt) then
                    unit.spare[#unit.spare + 1] = op
                end
            end
            unit.empty = math.max(0, unit.empty)
            table.sort(unit.spare, function(a, b)
                if a.value ~= b.value then
                    return a.value < b.value
                end
                return a.opt < b.opt
            end)
            units[#units + 1] = unit
            by_index[i] = unit
        end
    end
    local moves, by_opt, placed = {}, {}, {}
    local function can_add(unit, opt)
        return unit.values[opt] == nil and (unit.empty > 0 or #unit.spare > 0) and Icor_planner_spot_can(opt, unit.spot)
    end
    -- unit の opt を value にする。戻り値はキャラの合計がいくつ増えるか
    local function change(unit, opt, value)
        local old = unit.values[opt]
        local from = nil
        if old == nil then
            if unit.empty > 0 then
                unit.empty = unit.empty - 1
            else
                from = table.remove(unit.spare, 1)
            end
        end
        unit.values[opt] = value
        moves[#moves + 1] = {
            index = unit.index,
            slot_name = unit.slot_name,
            spot = unit.spot,
            opt = opt,
            value = value,
            old = old,
            from = from
        }
        local o = by_opt[opt] or {
            count = 0,
            updates = 0
        }
        o.count = o.count + 1
        o.updates = o.updates + 1
        by_opt[opt] = o
        local delta = value - (old or 0)
        placed[opt] = (placed[opt] or 0) + delta
        return delta
    end
    -- (1) 各部位の目標。載っていない(値が足りない)部位へ置く。
    -- 同じオプションが既に載っている部位(値を上げるだけで済む)を先に使う
    local slot_unmet, slot_min = {}, {}
    for _, row in ipairs(diag.slot_rows or {}) do
        if (row.min_value or 0) > (slot_min[row.opt] or 0) then
            slot_min[row.opt] = row.min_value
        end
        local need = math.max(0, (row.want or 0) - (row.have or 0))
        local done = {}
        while need > 0 do
            local best, best_rank = nil, nil
            for i, info in pairs(row.slots or {}) do
                local unit = by_index[i]
                if unit ~= nil and not info.ok and not done[i] then
                    local rank = nil
                    if unit.values[row.opt] ~= nil then
                        rank = 1
                    elseif can_add(unit, row.opt) then
                        rank = 2
                    end
                    if rank ~= nil and (best == nil or rank < best_rank or (rank == best_rank and i < best.index)) then
                        best, best_rank = unit, rank
                    end
                end
            end
            if best == nil then
                break
            end
            local value = math.max(Icor_planner_assumed_value(row.opt, best.spot, assumption), row.min_value or 0)
            change(best, row.opt, value)
            done[best.index] = true
            need = need - 1
        end
        if need > 0 then
            slot_unmet[row.opt] = (slot_unmet[row.opt] or 0) + need
        end
    end
    -- (2) 合計の目標。不足を、1 枠で一番多く埋まるところから埋める。
    -- 同じだけ埋まるなら、枠を使わない方(値を上げるだけ)を採る
    local needs, allowed, order = {}, {}, {}
    for _, row in ipairs(diag.rows or {}) do
        if (row.target or 0) > 0 then
            if needs[row.opt] == nil then
                order[#order + 1] = row.opt
                needs[row.opt] = 0
                allowed[row.opt] = {}
            end
            needs[row.opt] = math.max(needs[row.opt], row.short or 0)
            if row.spot == "Weapon" or row.spot == "Armor" then
                allowed[row.opt][row.spot] = true
            else
                allowed[row.opt].Weapon = true
                allowed[row.opt].Armor = true
            end
        end
    end
    for _, opt in ipairs(order) do
        needs[opt] = needs[opt] - (placed[opt] or 0)
    end
    while true do
        local best_opt, best_unit, best_value, best_gain, best_cost = nil, nil, 0, 0, 0
        for _, opt in ipairs(order) do
            if needs[opt] > 0 then
                for _, unit in ipairs(units) do
                    if allowed[opt][unit.spot] and Icor_planner_spot_can(opt, unit.spot) then
                        local value = Icor_planner_assumed_value(opt, unit.spot, assumption)
                        local gain, cost = 0, nil
                        if unit.values[opt] ~= nil then
                            gain, cost = value - unit.values[opt], 0
                        elseif can_add(unit, opt) then
                            gain, cost = value, 1
                        end
                        gain = math.min(needs[opt], gain)
                        if cost ~= nil and gain > 0 and
                            (gain > best_gain or (gain == best_gain and cost < best_cost)) then
                            best_opt, best_unit, best_value, best_gain, best_cost = opt, unit, value, gain, cost
                        end
                    end
                end
            end
        end
        if best_opt == nil then
            break
        end
        needs[best_opt] = needs[best_opt] - change(best_unit, best_opt, best_value)
    end
    local unmet, unmet_by_opt, total_opts = {}, {}, {}
    for _, opt in ipairs(order) do
        total_opts[opt] = true
        if needs[opt] > 0 then
            unmet[#unmet + 1] = {
                opt = opt,
                short = needs[opt]
            }
            unmet_by_opt[opt] = needs[opt]
        end
    end
    -- 部位の並び(メイン武器1 → … → サブ武器2)で出す
    table.sort(moves, function(a, b)
        if a.index ~= b.index then
            return a.index < b.index
        end
        return Icor_planner_order_of(a.opt) < Icor_planner_order_of(b.opt)
    end)
    local slot_unmet_count = 0
    for _ in pairs(slot_unmet) do
        slot_unmet_count = slot_unmet_count + 1
    end
    g.vlog("icor_planner: 今の装備に足す形(%s) 変える枠 %d / 届かない %d 件 / 置ききれない部位目標 %d 件",
        tostring(assumption), #moves, #unmet, slot_unmet_count)
    return {
        keep = true,
        update_mode = false,
        updates = #moves,
        moves = moves,
        by_opt = by_opt,
        unmet = unmet,
        unmet_by_opt = unmet_by_opt,
        slot_unmet = slot_unmet,
        slot_min = slot_min,
        total_opts = total_opts,
        assumption = assumption
    }
end

-- 「オプション o をイコル c_o 個に」を、イコル 1 個ずつのセットへ配る。
-- 個数の多いオプションから、載っている数の少ないイコルへ順に置く(同じイコルに同じものは置かない)。
-- 同じ中身のセットはまとめて { opts = {...}, count = N } にする(マーケットで同じ条件で探せるため)
function Icor_planner_split_sets(tp, per_icor)
    local icors = {}
    for k = 1, tp.icors do
        icors[k] = {}
    end
    local opts = {}
    for i, opt in ipairs(tp.order) do
        opts[#opts + 1] = {
            opt = opt,
            count = tp.counts[opt],
            index = i
        }
    end
    table.sort(opts, function(a, b)
        if a.count ~= b.count then
            return a.count > b.count
        end
        return a.index < b.index
    end)
    for _, o in ipairs(opts) do
        local idx = {}
        for k = 1, #icors do
            if #icors[k] < per_icor then
                idx[#idx + 1] = k
            end
        end
        table.sort(idx, function(a, b)
            if #icors[a] ~= #icors[b] then
                return #icors[a] < #icors[b]
            end
            return a < b
        end)
        for n = 1, math.min(o.count, #idx) do
            table.insert(icors[idx[n]], o.opt)
        end
    end
    local sets, by_key = {}, {}
    for _, list in ipairs(icors) do
        if #list > 0 then
            local key = table.concat(list, ",")
            if by_key[key] then
                by_key[key].count = by_key[key].count + 1
            else
                local set = {
                    opts = list,
                    count = 1
                }
                by_key[key] = set
                sets[#sets + 1] = set
            end
        end
    end
    return sets
end

-- セットで探すときの下限。
--   各部位の目標だけのオプション … 目標タブの値(1 枠の最低値)。0 なら見込みの値
--   合計の目標があるオプション   … 見込みの値(組んだときに 1 枠をこの値で数えているため)。
--                                   各部位の目標値の方が大きければそちら
function Icor_planner_set_min(plan, opt, spot, assumption)
    local assumed = Icor_planner_assumed_value(opt, spot, assumption)
    local slot_min = plan.slot_min[opt] or 0
    if slot_min > 0 and not plan.total_opts[opt] then
        return slot_min
    end
    return math.max(slot_min, assumed)
end

-- ===== 候補のイコルを評価する =====
--
-- 「このイコルを 1 個持ってきたら、目標の不足をどれだけ埋められるか」。
-- インベントリの評価にもマーケットの評価にも同じものを使う。
--
-- 振り直しの見込みまで含めて必ず数える。**並べ替えの決め手に使うので、表示する行だけ
-- 計算するわけにはいかない。** 以前は重さを避けて二段構えにしていたが、
-- 候補一覧をレベル × 部位で溜めるようにして(Icor_planner_option_candidates)
-- 1 件あたりの pcall が 1/5 以下になったので、一度で数える形に戻した。
function Icor_planner_evaluate(item_obj, diag)
    local score = {
        gain = 0,
        short_total = 0,
        hits = {},
        reroll = {},
        ratio = 0
    }
    if item_obj == nil then
        return score
    end
    -- **割合は「1 部位ぶんの目標に対して何割か」で出す。**
    --
    -- 分母は **目標値そのもの** を部位数で割ったもの。**残りの不足で割らないこと。**
    -- 不足で割ると、目標に近づくほど分母が小さくなって数字が暴れる。
    -- 実機で「クリ発の残りが 139 のときに、クリ発 1,392 のイコルが 400%」になった
    -- (139 ÷ 4 部位 = 34.75 が 1 部位ぶんの目安になってしまう)。目標を達成しきると
    -- 分母が 0 になり、今度は全部 0% になる。
    -- 目標値で割れば、**進み具合によらず同じ物差し**でイコルを比べられる。
    --
    -- 分母は「その部位のイコルに載りうる目標だけ」を数えること。perfection のように
    -- 武器にしか載らないものを防具の目安へ入れると、防具の割合が不当に低くなる。
    local spot = TryGetProp(item_obj, "StringArg2", "None")
    -- **分母はイコルの実効数(spot_icors)。** 武器は 1 個が 2 か所ぶん働くので、
    -- そのイコルが受け持つのは 目標値 ÷ 2。装備数(4)で割ると受け持ちが半分になる
    local slots = diag.spot_icors and diag.spot_icors[spot] or 0
    if slots <= 0 then
        -- 部位が読めない / その部位を装備していない。装備は武器 4 か所・防具 4 か所なので
        -- 4 を既定にする(この既定のときも読み方は変わらない)
        slots = 4
    end
    -- goal … 割合を出すための「目標値」。達成済みでも分母に入れる(物差しを固定するため)
    -- need … まだ足りていないもの。**振り直しで当たりかどうか**の判定に使う
    -- goal … 1 枠がその目標について受け持つ「期待値」。割合の物差しになる
    -- need … まだ足りていないもの。**振り直しで当たりかどうか**の判定に使う
    --
    -- **合計の目標だけで割らないこと。** 以前は合計の目標しか分母に入れていなかったので、
    -- 「各部位」の目標ばかりを組んでいると、欲しいオプションが 3 つ載っていても 0% と
    -- 出ていた(実機で指摘された)。1 枠から見れば、合計だろうと各部位だろうと
    -- 「その枠がどれだけ働いているか」は同じなので、両方を同じ物差しに載せる。
    local goal, need = {}, {}
    for _, row in ipairs(diag.rows) do
        if row.short > 0 then
            need[row.opt] = row.short
        end
        -- その部位で狙う目標だけを数える。row.spot は利用者が選んだ対象部位で、
        -- Icor_planner_spot_can は素でその部位に載りうるかどうか
        local wanted = (row.spot == nil) or (row.spot == "both") or (row.spot == spot)
        if spot == "None" or (wanted and Icor_planner_spot_can(row.opt, spot)) then
            -- 合計の目標は、装備している部位数で分担する。
            -- **同じオプションが複数行あるときは大きい方**(1 枠の受け持ちは 1 つに決まる)
            local per = row.target / slots
            if goal[row.opt] == nil or per > goal[row.opt] then
                goal[row.opt] = per
            end
        end
    end
    local want = {}
    for _, row in ipairs(diag.slot_rows or {}) do
        if row.spot == "both" or spot == "None" or row.spot == spot then
            want[row.opt] = row.min_value or 0
            score.comp_total = (score.comp_total or 0) + 1
            -- 各部位の目標は、そのまま 1 枠あたりの期待値。**0(付いていればよい)のときは、
            -- 1 枠に載りうる最大値を期待値にする**(0 のままだと分母にも分子にも効かない)
            local expect = row.min_value or 0
            if expect <= 0 then
                local _, max_value = Icor_planner_top_range(row.opt, spot)
                expect = max_value
            end
            -- 同じオプションが複数行あるときは大きい方(上の合計側と同じ理由)
            if expect > 0 and (goal[row.opt] == nil or expect > goal[row.opt]) then
                goal[row.opt] = expect
            end
        end
    end
    -- **分母は「そのイコルが出せる一番良い姿」。** イコルの枠は max_option_count 個しか
    -- 無いので、期待値の大きい方から枠数ぶんだけ足したものを 100% とする。
    -- 目標を全部足して割ると、目標を増やすほどどのイコルも低く出て比べられなくなる。
    local expects = {}
    for _, v in pairs(goal) do
        expects[#expects + 1] = v
    end
    table.sort(expects, function(a, b)
        return a > b
    end)
    local best = 0
    for i = 1, math.min(#expects, diag.max_option_count) do
        best = best + expects[i]
    end
    score.short_total = best
    score.quota = best
    score.spot = spot
    score.spot_slots = slots
    score.comp_total = score.comp_total or 0
    score.comp_have = 0
    score.comp_missing = {}
    for i = 1, diag.max_option_count do
        local opt = TryGetProp(item_obj, "RandomOption_" .. i, "None")
        local value = tonumber(TryGetProp(item_obj, "RandomOptionValue_" .. i, 0)) or 0
        local group = TryGetProp(item_obj, "RandomOptionGroup_" .. i, "None")
        if opt ~= nil and opt ~= "None" and want[opt] ~= nil and value >= want[opt] then
            score.comp_have = score.comp_have + 1
            score.comp_hits = score.comp_hits or {}
            score.comp_hits[opt] = true
        end
        if opt ~= nil and opt ~= "None" and goal[opt] then
            local _, max_value = Icor_planner_range(item_obj, opt)
            -- 期待値を超える分は数えない(1 枠で受け持ちを超えても、その枠の仕事は終わり)
            local gain = math.min(goal[opt], value)
            score.gain = score.gain + gain
            score.hits[#score.hits + 1] = {
                opt = opt,
                value = value,
                gain = gain,
                max = max_value,
                state = Icor_planner_value_state(value, max_value)
            }
        end
        -- 枠ごとの当たり本数。オプションリロールで出うるのは、**そのイコルの段・部位の全オプション
        -- のうち、同じイコルの他の枠と重ならないもの**(素の reroll_item_option.lua)。
        -- **グループでは絞られない**(以前は再鑑定の注記を読み違えて同じグループに絞っていた。
        -- 実機で指摘された)。
        if opt ~= nil and opt ~= "None" then
            -- **当たりには「合計で足りない目標」だけでなく「各部位に載せたい目標」も含める。**
            -- 買う側から見れば、構成を埋める候補が出るかどうかも同じくらい大事
            local total, useful = Icor_planner_reroll_candidates(item_obj, i, need, want)
            score.reroll[i] = {
                group = group,
                total = total,
                useful = useful,
                opt = opt,
                -- 既に目標に載っている枠は**リロールの対象にしない**(回すと今の当たりを失う)
                is_hit = (opt ~= nil and opt ~= "None" and
                    (need[opt] ~= nil or (score.comp_hits and score.comp_hits[opt] == true)))
            }
        end
    end
    if score.quota > 0 then
        score.ratio = score.gain / score.quota
    end
    -- 「オプションリロールでどこまで持っていけるか」を出す。
    --
    -- **前提はオプションリロール(選んだ 1 枠だけを振り直す)**。全オプションを一度に
    -- 振り直す再鑑定は今は使われないので、そちらの「同時に当たる確率」は出さない。
    --
    -- 枠は 3 通りに分かれる。
    --   * 既に目標に載っている       … 回さない(回すと今の当たりを失う)
    --   * 載っていないが候補がある   … 回せば載る。期待回数は 候補総数 / 当たり数
    --   * 載っていないし候補も無い   … 目標のオプションが全部他の枠に載っている / その部位に
    --                                   載らないオプションしか目標に無い、のどちらか
    do
        local counted, hit_now, fixable, stuck, expect = 0, 0, 0, 0, 0
        for i = 1, diag.max_option_count do
            local r = score.reroll[i]
            if r and r.total > 0 then
                counted = counted + 1
                if r.is_hit then
                    hit_now = hit_now + 1
                elseif r.useful > 0 then
                    fixable = fixable + 1
                    -- 当たりを引くまでの期待回数(幾何分布) = 1 / (当たり / 候補総数)。
                    -- **画面には出さない**(回数まで出すと読むものが増えるだけ、との判断)。
                    -- 同点のときにどちらを上へ出すかの決め手としてだけ使う
                    expect = expect + (r.total / r.useful)
                else
                    stuck = stuck + 1
                end
            end
        end
        score.reroll_slots = counted
        score.reroll_now = hit_now
        score.reroll_fixable = fixable
        score.reroll_stuck = stuck
        score.reroll_expect = expect
    end
    return score
end

-- そのオプションのグループ。**素の関数はオプション名だけで決まる**ので溜める。
-- 溜めないと、候補 1 件ごとに pcall することになり、出品の多い一覧で効いてくる
function Icor_planner_group_name_cached(opt)
    g.icor_planner_group_cache = g.icor_planner_group_cache or {}
    local cached = g.icor_planner_group_cache[opt]
    if cached == nil then
        local ok, group = pcall(shared_item_goddess_icor.get_option_group_name, opt)
        cached = (ok and group) or "None"
        g.icor_planner_group_cache[opt] = cached
    end
    return cached
end

-- そのイコル(レベル × 部位)の候補一覧を、グループごとに分けて返す。
--
-- オプションリロールで出うる候補の一覧(素の get_random_option_list)。
-- **レベル(UseLv)と部位(StringArg2)だけで決まる**ので、イコル 1 個ごとに引き直さず溜める。
function Icor_planner_option_candidates(item_obj)
    if shared_item_goddess_icor == nil or item_obj == nil then
        return nil
    end
    local key = tostring(TryGetProp(item_obj, "UseLv", 0)) .. "/" .. tostring(TryGetProp(item_obj, "StringArg2", "None"))
    g.icor_planner_option_list_cache = g.icor_planner_option_list_cache or {}
    local cached = g.icor_planner_option_list_cache[key]
    if cached ~= nil then
        return cached or nil
    end
    local ok, list = pcall(shared_item_goddess_icor.get_random_option_list, item_obj, false)
    if not ok or type(list) ~= "table" then
        g.icor_planner_option_list_cache[key] = false
        return nil
    end
    g.icor_planner_option_list_cache[key] = list
    return list
end

-- 枠 index を振り直したときに出うる候補の数と、そのうち目標(不足あり)に載っている数。
-- 同じイコルに同じオプションは 2 つ載らない(素の is_valid_reroll_option と同じ判定)。
-- **素の判定を 1 件ずつ pcall で呼ばない。** 候補は約 40 件あり、一覧の件数 × 4 枠 × 40 件の
-- pcall になって目に見えて引っかかるので、他の枠のオプション名を先に集めて引き比べる
function Icor_planner_reroll_candidates(item_obj, index, need, want)
    local list = Icor_planner_option_candidates(item_obj)
    if list == nil then
        return 0, 0
    end
    local taken = {}
    for i = 1, shared_item_goddess_icor.get_max_option_count() do
        if i ~= index then
            taken[TryGetProp(item_obj, "RandomOption_" .. i, "None")] = true
        end
    end
    local total, useful = 0, 0
    for _, opt in ipairs(list) do
        if not taken[opt] then
            total = total + 1
            if need[opt] ~= nil or (want ~= nil and want[opt] ~= nil) then
                useful = useful + 1
            end
        end
    end
    return total, useful
end

-- 候補 1 件を描く。インベントリの「候補」タブとマーケットのパネルが共用する。
-- 戻り値は次に描き始める y。
--
-- **列へ置くこと。** 当たったオプションを 1 本の文字列に空白で並べても、名前も桁数も
-- 違うので揃わない(実機で指摘された)。当たり枠は最大 4 つ、再鑑定の見込みも最大 4 つ
-- なので、幅に応じて 4 列か 2 列の等幅グリッドへ入れる。
-- **行の高さは中身によらず一定**にする(揃っていないと目で追えない)。
--
-- click は {rbtn = "<グローバル関数名>", arg_num = <数値>, tooltip = "..."} を渡すと、
-- 行全体を覆う透明なボタンを置いて右クリックを拾う。**文字の上に置くこと**(richtext は
-- 当たり判定を持たないので、透明ボタンを重ねないと押せない)。
function Icor_planner_render_candidate(list, key, y, row, price, click)
    local width = list:GetWidth() - 30
    local hit_cols = (width >= 700) and 4 or 2
    local col_w = math.floor(width / hit_cols)
    local score = row.score
    -- 1 行目: 割合と名前。**割合は固定幅の列**にして、名前の開始位置を揃える
    -- 1 列目: 構成(各部位に載せたい目標をいくつ満たすか)。無ければ "-"
    local comp = list:CreateOrGetControl("richtext", key .. "_c", 10, y, 0, 0)
    AUTO_CAST(comp)
    local comp_total = score.comp_total or 0
    if comp_total == 0 then
        comp:SetText("{ol}{s16}{#666666} - ")
    else
        local full = (score.comp_have or 0) >= comp_total
        comp:SetText(string.format("{ol}{s16}%s%d/%d", full and "{#98FB98}" or "{#FFA500}",
            score.comp_have or 0, comp_total))
    end
    comp:SetTextTooltip(g.lang == "Japanese" and
                            "{ol}各部位に載せたい目標のうち、このイコルが満たしている数" or
                            "{ol}How many per-slot targets this icor already has")
    -- 2 列目: 合計の目標に対する、1 部位ぶんの目安への割合
    local pct = list:CreateOrGetControl("richtext", key .. "_p", 56, y, 0, 0)
    AUTO_CAST(pct)
    -- 100% = 1 部位ぶんのノルマちょうど。**超えているものが分かるように色を変える**
    local ratio = (score.ratio or 0) * 100
    local pct_color = "{#AAAAAA}"
    if ratio >= 150 then
        pct_color = "{#9932CC}"
    elseif ratio >= 100 then
        pct_color = "{#98FB98}"
    elseif ratio >= 50 then
        pct_color = "{#FFD700}"
    end
    if (score.quota or 0) <= 0 then
        -- その部位に当てはまる「合計」の目標が 1 つも無い。0% と出すと
        -- 「悪いイコル」に見えるので、対象外であることが分かる出し方にする
        pct:SetText("{ol}{s16}{#666666} - ")
    else
        pct:SetText(string.format("{ol}{s16}%s%d%%", pct_color, math.floor(ratio + 0.5)))
    end
    pct:SetTextTooltip(g.lang == "Japanese" and
                           string.format("{ol}イコル 1 枚として、どれだけ目標に働いているか{nl}100%% = このイコルの %d 枠すべてが目標を満たした姿(合計 %s){nl}合計の目標はイコル %d 個で分担した値(武器は持ち替えで 1 個が 2 か所ぶん働きます)",
            4, GET_COMMAED_STRING(math.floor(score.quota or 0)), score.spot_slots or 4) or
                           "{ol}How much this icor works toward the targets")
    local name = list:CreateOrGetControl("richtext", key .. "_n", 112, y, 0, 0)
    AUTO_CAST(name)
    name:SetText("{ol}{s16}" .. (row.name or ""))
    name:AdjustFontSizeByWidth(width - 102 - (price and 120 or 0))
    if price then
        local price_ctrl = list:CreateOrGetControl("richtext", key .. "_v", width - 60, y, 0, 0)
        AUTO_CAST(price_ctrl)
        price_ctrl:SetText("{ol}{s16}{#FFD700}" .. GET_COMMAED_STRING(price))
        price_ctrl:AdjustFontSizeByWidth(118)
    end
    -- 2 行目以降: 当たっている枠を等幅の列へ。**空でも高さは詰めない**
    local hit_rows = math.ceil(4 / hit_cols)
    for i = 1, 4 do
        local cell = list:CreateOrGetControl("richtext", key .. "_h" .. i, 20 + ((i - 1) % hit_cols) * col_w,
            y + 21 + math.floor((i - 1) / hit_cols) * 19, 0, 0)
        AUTO_CAST(cell)
        local hit = score.hits[i]
        if hit then
            cell:SetText(string.format("{ol}{s14}%s%s %s", Icor_planner_state_color(hit.state),
                Icor_planner_option_name(hit.opt), GET_COMMAED_STRING(hit.value)))
            cell:AdjustFontSizeByWidth(col_w - 10)
        else
            cell:SetText("")
        end
    end
    local reroll_y = y + 21 + hit_rows * 19
    if #score.hits == 0 then
        local none = list:CreateOrGetControl("richtext", key .. "_h1", 20, y + 21, 0, 0)
        AUTO_CAST(none)
        none:SetText(g.lang == "Japanese" and "{ol}{s14}{#888888}目標に載る枠なし" or
                         "{ol}{s14}{#888888}nothing on target")
    end
    -- **最後の行は空けておく。** 枠ごとの当たり本数と「あと何枠」は、一覧の上では
    -- 読むものが多すぎたので出さないことにした。ただし行間は残す。
    -- **候補が続けて並ぶと、どこまでが 1 件か分からなくなる**ため、ここが区切りになる。
    --
    -- 集計そのもの(reroll_slots / reroll_now / reroll_fixable / reroll_stuck / reroll_expect)は
    -- **並べ替えの決め手として使っている**ので、Icor_planner_evaluate 側では残してある。
    -- 行全体を右クリックで拾えるようにする。**最後に作って一番上へ重ねる**
    if click ~= nil then
        local hit = list:CreateOrGetControl("button", key .. "_hit", width + 10, reroll_y + 22 - y, ui.LEFT, ui.TOP,
            8, y, 0, 0)
        AUTO_CAST(hit)
        hit:SetSkinName("None")
        hit:SetText("")
        hit:EnableHitTest(1)
        if click.tooltip then
            -- **右クリックの案内だけにする。** 振り直しの内訳まで足すと読むものが増えるだけ、
            -- との判断(実機で指摘された)
            hit:SetTextTooltip(click.tooltip)
        end
        if click.rbtn then
            hit:SetEventScript(ui.RBUTTONUP, click.rbtn)
            if click.arg_num then
                hit:SetEventScriptArgNumber(ui.RBUTTONUP, click.arg_num)
            end
            if click.arg_str then
                hit:SetEventScriptArgString(ui.RBUTTONUP, click.arg_str)
            end
        end
    end
    return reroll_y + 24
end



-- 候補の並べ替え。**まず今の当たり(gain)、同点ならリロールで伸ばせる方を上に。**
-- オプションリロール前提なので、同じだけ当たっているなら
--   * 何度回しても載らない枠(stuck)が少ない
--   * 目標に載せられる余地(fixable)がある
--   * そこへ届くまでの期待回数が少ない
-- ものの方が買う価値が高い。gain を第一に置くのは、買ってすぐ効く分だから。
function Icor_planner_candidate_better(a, b)
    -- **まず構成。** 各部位に載せたい目標をいくつ満たすかが、買う / 使うの一番の決め手
    local ca, cb = a.score.comp_have or 0, b.score.comp_have or 0
    if ca ~= cb then
        return ca > cb
    end
    if a.score.gain ~= b.score.gain then
        return a.score.gain > b.score.gain
    end
    local sa, sb = a.score.reroll_stuck or 0, b.score.reroll_stuck or 0
    if sa ~= sb then
        return sa < sb
    end
    local fa, fb = a.score.reroll_fixable or 0, b.score.reroll_fixable or 0
    if fa ~= fb then
        return fa > fb
    end
    local ea, eb = a.score.reroll_expect or 0, b.score.reroll_expect or 0
    if ea ~= eb then
        return ea < eb
    end
    return nil
end

-- ===== 入口 =====
function icor_planner_on_init()
    if not g.icor_planner_settings then
        Icor_planner_load_settings()
    end
    -- 更新スクリプトを掛ける土台。**自分のアドオンのフレーム**(単体版は _icor_planner、
    -- Nexus Addons P に入れるときは _nexus_addons_p)
    local root = ui.GetFrame(addon_name_lower)
    if g.settings.icor_planner.use == 0 then
        ui.DestroyFrame(addon_name_lower .. "icor_planner")
        ui.DestroyFrame(addon_name_lower .. "icor_planner_market")
        -- マーケットへ足したボタンも片付ける。**自分の名前のものだけ**を消すこと
        -- (market_favorite_rebuild も同じフレームへボタンを足している)
        Icor_planner_remove_market_btn()
        if root then
            root:StopUpdateScript("Icor_planner_market_watch")
        end
        return
    end
    -- マーケットを開いたら横へ出す。素の MARKET_* は market_favorite_rebuild が
    -- 掴んでいる(控えは素の関数 1 つにつき 1 本しか持てないので、重ねると先客が黙って
    -- 落ちる)ため、フックは掛けずに表示状態を見に行く。0.5 秒ごとに ui.GetFrame を
    -- 数回引くだけなので負荷は無い
    if root then
        root:StopUpdateScript("Icor_planner_market_watch")
        root:RunUpdateScript("Icor_planner_market_watch", 0.5)
    end
end
