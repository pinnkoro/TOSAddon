-- Icor Planner の「あとオプション N 個」の数え方を luajit 上で検査する（ゲーム不要）。
--
-- 見るのは実機で指摘された 3 件。**どちらも画面に数が出るだけで、間違っていても気付きにくい。**
--   * 更新するイコルを選んでいないとき、今の装備を残したまま足りない分だけを数えること
--     （以前は理想の形との差を数えていて、レザー相殺だけ 1,104 足りないのに 7 個と出た）
--   * 試算で「更新するイコル」を差し替えても、数え方が入れ替わらないこと
--     （手袋を差し替えたら 1 → 7 と、別の物差しの数を比べていた）
--   * 変えるイコルは、目標のオプションが少ないものから選ぶこと。武器から / 防具から の 2 つの形を出すこと
--     （以前は部位の並び順に埋めていて、目標の揃ったイコルへ先に手を入れることがあった）
--
-- 使い方（リポジトリルートから）:
--     luajit docs/tests/test_icor_planner_plan.lua

local PARTS = {"icor_planner/src/00_header.lua", "icor_planner/src/icor_planner.lua"}

package.preload["json"] = function()
    return {}
end

local chunks = {}
for _, path in ipairs(PARTS) do
    local f = assert(io.open(path, "rb"))
    chunks[#chunks + 1] = f:read("*a")
    f:close()
end
local fn = assert(loadstring(table.concat(chunks, "\n"), "icor_planner"))
fn()
local g = _G["_icor_planner_core_g"]
g.vlog = function()
end

local failed = 0
local function check(name, got, want)
    if got == want then
        print("  ok   " .. name)
    else
        failed = failed + 1
        print(string.format("  FAIL %s: got %s, want %s", name, tostring(got), tostring(want)))
    end
end

-- ===== 素のデータの代わり =====
-- 1 枠の見込みの値(平均 / 最低)。部位で変える
local AVG = {
    Armor = {
        ADD_LEATHER = 2600,
        MiddleSize_Def = 3000,
        STR = 500,
        CON = 500,
        CRTHR = 1300,
        AllMaterialType_Atk = 2800
    },
    Weapon = {
        perfection = 13000,
        STR = 600,
        CON = 600,
        CRTHR = 1600,
        AllMaterialType_Atk = 3500
    }
}
function Icor_planner_assumed_value(opt, spot, assumption)
    local v = (AVG[spot] or {})[opt] or 0
    if assumption == "min" then
        return math.floor(v * 0.9)
    end
    return v
end
-- perfection は武器だけ、相殺は防具だけ
function Icor_planner_spot_can(opt, spot)
    if opt == "perfection" then
        return spot == "Weapon"
    end
    if opt == "ADD_LEATHER" or opt == "MiddleSize_Def" then
        return spot == "Armor"
    end
    return true
end
function Icor_planner_order_of(opt)
    return 1
end
function Icor_planner_other_sources(opt)
    return 0
end

local function op(opt, value)
    return {
        opt = opt,
        value = value
    }
end

local function slot(name, spot, options, extra)
    local e = {
        slot_name = name,
        spot = spot,
        equipped = true,
        options = options
    }
    for k, v in pairs(extra or {}) do
        e[k] = v
    end
    return e
end

-- 防具 4 部位だけの装備。手袋に目標に無いオプション(命中)がある
local function armor_scan(gloves_extra)
    return {
        slots = {slot("SHIRT", "Armor", {op("STR", 500), op("CON", 500), op("MiddleSize_Def", 3000), op("CRTHR", 1300)}),
                 slot("PANTS", "Armor", {op("STR", 500), op("CON", 500), op("MiddleSize_Def", 3000), op("CRTHR", 1300)}),
                 slot("GLOVES", "Armor", {op("ADD_HR", 1282), op("CON", 500), op("STR", 322), op("BLK", 1269)},
            gloves_extra),
                 slot("BOOTS", "Armor", {op("STR", 500), op("CON", 500), op("ADD_LEATHER", 2932), op("CRTHR", 1300)})}
    }
end

local function diag_of(rows, slot_rows)
    return {
        rows = rows,
        slot_rows = slot_rows or {},
        max_option_count = 4,
        spot_slots = {
            Armor = 4
        },
        spot_icors = {
            Armor = 4
        }
    }
end

print("[1] 足りないのが 1 項目だけなら 1 個(理想の形との差は数えない)")
do
    local scan = armor_scan()
    local diag = diag_of({{
        opt = "ADD_LEATHER",
        spot = "Armor",
        target = 8400,
        cur = 7296,
        short = 1104
    }, {
        opt = "MiddleSize_Def",
        spot = "Armor",
        target = 8400,
        cur = 9551,
        short = 0
    }, {
        opt = "CRTHR",
        spot = "both",
        target = 24000,
        cur = 27663,
        short = 0
    }, {
        opt = "STR",
        spot = "both",
        target = 316,
        cur = 6372,
        short = 0
    }, {
        opt = "CON",
        spot = "both",
        target = 316,
        cur = 3000,
        short = 0
    }})
    local plan = Icor_planner_plan(diag, scan, "avg")
    check("数え方は今の装備に足す形", plan.keep, true)
    check("あとオプション", plan.updates, 1)
    check("届かない項目は無い", #plan.unmet, 0)
    local m = plan.moves[1]
    check("変えるのは手袋", m and m.slot_name, "GLOVES")
    check("目標に無いオプションの枠を使う", m and m.from and m.from.opt ~= nil, true)
    check("外すのは目標に無いもの(値の小さい方=ブロック)", m and m.from and m.from.opt, "BLK")
    check("目標別の数", plan.by_opt.ADD_LEATHER and plan.by_opt.ADD_LEATHER.updates, 1)
end

print("[2] 全部届いていれば 0 個")
do
    local diag = diag_of({{
        opt = "CRTHR",
        spot = "both",
        target = 24000,
        cur = 27663,
        short = 0
    }})
    local plan = Icor_planner_plan(diag, armor_scan(), "avg")
    check("あとオプション", plan.updates, 0)
end

print("[3] 目標の揃ったイコルの値を上げるより、目標の少ないイコルを変える")
do
    -- レザー相殺が 300 足りない。靴のレザー 2,932 は見込み(3,400)へ上げれば埋まり、
    -- 手袋の外せる枠(命中 / ブロック)に置いても埋まる。**目標の一番少ない手袋**を変える
    -- (靴は目標を 4 つ持つので、手を入れると作り直しになる)
    AVG.Armor.ADD_LEATHER = 3400
    -- 上着・ズボン・靴は目標を 4 つ、手袋は 2 つ(力 / 体力)持つ
    local diag = diag_of({{
        opt = "ADD_LEATHER",
        spot = "Armor",
        target = 8400,
        cur = 8100,
        short = 300
    }, {
        opt = "MiddleSize_Def",
        spot = "Armor",
        target = 8400,
        cur = 9551,
        short = 0
    }, {
        opt = "CRTHR",
        spot = "both",
        target = 24000,
        cur = 27663,
        short = 0
    }, {
        opt = "STR",
        spot = "both",
        target = 316,
        cur = 6372,
        short = 0
    }, {
        opt = "CON",
        spot = "both",
        target = 316,
        cur = 3000,
        short = 0
    }})
    local plan = Icor_planner_plan(diag, armor_scan(), "avg")
    check("あとオプション", plan.updates, 1)
    check("手袋を変える", plan.moves[1] and plan.moves[1].slot_name, "GLOVES")
    check("外せる枠を使う", plan.moves[1] and plan.moves[1].from ~= nil, true)
    AVG.Armor.ADD_LEATHER = 2600
end

print("[3b] 目標の数が同じイコルどうしなら、枠を使わず値を上げる方を採る")
do
    AVG.Armor.ADD_LEATHER = 3400
    local scan = {
        slots = {slot("SHIRT", "Armor", {op("STR", 500), op("ADD_HR", 1000), op("BLK", 1000), op("DEX", 300)}),
                 slot("BOOTS", "Armor", {op("ADD_LEATHER", 2932), op("ADD_HR", 1000), op("BLK", 1000), op("DEX", 300)})}
    }
    local diag = diag_of({{
        opt = "ADD_LEATHER",
        spot = "Armor",
        target = 8400,
        cur = 8100,
        short = 300
    }, {
        opt = "STR",
        spot = "both",
        target = 1,
        cur = 1,
        short = 0
    }})
    local plan = Icor_planner_plan(diag, scan, "avg")
    check("あとオプション", plan.updates, 1)
    check("靴のレザーの値を上げる", plan.moves[1] and plan.moves[1].slot_name, "BOOTS")
    check("元の値を持つ(値上げ)", plan.moves[1] and plan.moves[1].old, 2932)
    AVG.Armor.ADD_LEATHER = 2600
end

print("[4] 各部位の目標は、載っていない部位だけを数える")
do
    local scan = armor_scan()
    -- 力を 400 以上で全部位に。手袋は 322 なので足りない
    local slots_info = {}
    for i, e in ipairs(scan.slots) do
        local v = 0
        for _, o in ipairs(e.options) do
            if o.opt == "STR" then
                v = o.value
            end
        end
        slots_info[i] = {
            value = v,
            ok = v >= 400
        }
    end
    local diag = diag_of({}, {{
        opt = "STR",
        spot = "both",
        min_value = 400,
        slots = slots_info,
        have = 3,
        want = 4
    }})
    local plan = Icor_planner_plan(diag, scan, "avg")
    check("あとオプション", plan.updates, 1)
    check("手袋の力を上げる", plan.moves[1] and plan.moves[1].slot_name, "GLOVES")
    check("枠は増やさない(値上げ)", plan.moves[1] and plan.moves[1].old, 322)
end

print("[5] 変えられる枠が無ければ届かないと出す")
do
    -- 全部位の全枠が目標のオプションで埋まっている
    local full = {
        slots = {slot("SHIRT", "Armor", {op("STR", 500), op("CON", 500), op("MiddleSize_Def", 3000), op("CRTHR", 1300)})}
    }
    local diag = diag_of({{
        opt = "ADD_LEATHER",
        spot = "Armor",
        target = 8400,
        cur = 0,
        short = 8400
    }, {
        opt = "STR",
        spot = "both",
        target = 1,
        cur = 1,
        short = 0
    }, {
        opt = "CON",
        spot = "both",
        target = 1,
        cur = 1,
        short = 0
    }, {
        opt = "MiddleSize_Def",
        spot = "Armor",
        target = 1,
        cur = 1,
        short = 0
    }, {
        opt = "CRTHR",
        spot = "both",
        target = 1,
        cur = 1,
        short = 0
    }})
    local plan = Icor_planner_plan(diag, full, "avg")
    check("変える枠は無い", plan.updates, 0)
    check("届かない", plan.unmet_by_opt.ADD_LEATHER, 8400)
end

print("[6] 試算で更新するイコルを差し替えても、数え方は変わらない")
do
    -- 手袋が更新するイコル → 差し替え後は excluded が外れ、was_excluded が残る
    local before = armor_scan({
        excluded = true
    })
    local after = armor_scan({
        excluded = false,
        was_excluded = true
    })
    check("差し替える前は更新するイコルの数え方", Icor_planner_update_mode(before), true)
    check("差し替えた後も更新するイコルの数え方", Icor_planner_update_mode(after), true)
    check("選んでいなければ今の装備に足す形", Icor_planner_update_mode(armor_scan()), false)
    -- 差し替えた後に全部届いているなら 0 個(理想の形を組み直さない)
    local diag = diag_of({{
        opt = "ADD_LEATHER",
        spot = "Armor",
        target = 8400,
        cur = 10228,
        short = 0
    }, {
        opt = "CRTHR",
        spot = "both",
        target = 24000,
        cur = 27663,
        short = 0
    }})
    local plan = Icor_planner_plan(diag, after, "avg")
    check("更新するイコルの数え方で組む", plan.update_mode, true)
    check("あとオプション", plan.updates, 0)
    check("届かない項目は無い", #plan.unmet, 0)
    -- 届いていなければ「届かない」と出る(更新する枠はもう無い)
    local short = diag_of({{
        opt = "ADD_LEATHER",
        spot = "Armor",
        target = 12000,
        cur = 10228,
        short = 1772
    }})
    local plan2 = Icor_planner_plan(short, after, "avg")
    check("更新する枠が無いので 0 個", plan2.updates, 0)
    check("足りない分は届かないと出る", plan2.unmet[1] and plan2.unmet[1].opt, "ADD_LEATHER")
end

print("[6b] 「全ての〜」と個別の項目は別のオプションとして扱う")
do
    -- 目標は 全ての防具の材質。手袋のクロース対象攻撃力は目標に無いので外してよい(利用者の判断で別物)
    local function scan_with(gloves)
        return {
            slots = {slot("GLOVES", "Armor", gloves)}
        }
    end
    local need = diag_of({{
        opt = "AllMaterialType_Atk",
        spot = "Armor",
        target = 5000,
        cur = 4000,
        short = 1000
    }})
    local plan = Icor_planner_plan(need, scan_with({op("ADD_CLOTH", 300), op("ADD_HR", 900), op("CON", 500),
                                                    op("BLK", 1200)}), "avg")
    check("あとオプション", plan.updates, 1)
    check("クロース(300)は全ての防具の材質を支えない扱いで外す", plan.moves[1] and plan.moves[1].from and
        plan.moves[1].from.opt, "ADD_CLOTH")
end

print("[9] 武器から変える形と防具から変える形を出す。目標の少ないイコルから変える")
do
    -- クリ発が 1,000 足りない(両方に載る)。武器も防具も外せる枠を持つ。
    -- 防具は上着(目標 3 つ)より手袋(目標 0)が後ろに並ぶが、手袋を先に変える
    local scan = {
        slots = {slot("RH", "Weapon", {op("STR", 600), op("CON", 600), op("ADD_HR", 900), op("BLK", 900)}),
                 slot("LH", "Weapon", {op("ADD_HR", 900), op("BLK", 900), op("DEX", 300), op("INT", 300)}),
                 slot("SHIRT", "Armor", {op("STR", 500), op("CON", 500), op("CRTHR", 1300), op("BLK", 800)}),
                 slot("GLOVES", "Armor", {op("ADD_HR", 1282), op("BLK", 1269), op("DEX", 300), op("INT", 300)})}
    }
    local diag = diag_of({{
        opt = "CRTHR",
        spot = "both",
        target = 24000,
        cur = 23000,
        short = 1000
    }, {
        opt = "STR",
        spot = "both",
        target = 1,
        cur = 1,
        short = 0
    }, {
        opt = "CON",
        spot = "both",
        target = 1,
        cur = 1,
        short = 0
    }})
    local plans = Icor_planner_plan_keep_both(diag, scan, "avg")
    local by = {}
    for _, p in ipairs(plans) do
        by[p.prefer] = p
    end
    check("2 つの形を出す", by.Weapon ~= nil and by.Armor ~= nil, true)
    check("武器から: 目標の無い左手を変える", by.Weapon.moves[1] and by.Weapon.moves[1].slot_name, "LH")
    check("防具から: 目標の無い手袋を変える", by.Armor.moves[1] and by.Armor.moves[1].slot_name, "GLOVES")
    check("どちらも 1 個", by.Weapon.updates + by.Armor.updates, 2)
    check("変え方は別", Icor_planner_same_moves(by.Weapon, by.Armor), false)
    -- 部位を問わない形でも、目標の少ないイコルから
    local any = Icor_planner_plan_keep(diag, scan, "avg", nil)
    local first = any.moves[1] and any.moves[1].slot_name
    check("部位を問わなければ目標 0 のイコル", first == "LH" or first == "GLOVES", true)
    -- 防具だけに載る目標は、武器から変える形でも防具に置く
    local armor_only = diag_of({{
        opt = "ADD_LEATHER",
        spot = "Armor",
        target = 8400,
        cur = 7000,
        short = 1400
    }, {
        opt = "STR",
        spot = "both",
        target = 1,
        cur = 1,
        short = 0
    }, {
        opt = "CON",
        spot = "both",
        target = 1,
        cur = 1,
        short = 0
    }})
    local w = Icor_planner_plan_keep(armor_only, scan, "avg", "Weapon")
    check("防具だけの目標は防具へ", w.moves[1] and w.moves[1].slot_name, "GLOVES")
    local a = Icor_planner_plan_keep(armor_only, scan, "avg", "Armor")
    check("両方の目標が無ければ 2 つは同じ変え方", Icor_planner_same_moves(w, a), true)
    check("防具だけの目標は回した分ではない", w.moves[1] and w.moves[1].fallback, nil)
    -- 防具の枠が尽きたら武器へ回す。回した分には印を付ける(画面で分けて出す)
    local full = {
        slots = {slot("LH", "Weapon", {op("ADD_HR", 900), op("BLK", 900), op("DEX", 300), op("INT", 300)}),
                 slot("SHIRT", "Armor", {op("STR", 500), op("CON", 500), op("CRTHR", 1300), op("ADD_LEATHER", 800)})}
    }
    local need = diag_of({{
        opt = "CRTHR",
        spot = "both",
        target = 24000,
        cur = 23000,
        short = 1000
    }, {
        opt = "STR",
        spot = "both",
        target = 1,
        cur = 1,
        short = 0
    }, {
        opt = "CON",
        spot = "both",
        target = 1,
        cur = 1,
        short = 0
    }, {
        opt = "ADD_LEATHER",
        spot = "Armor",
        target = 1,
        cur = 1,
        short = 0
    }})
    local spill = Icor_planner_plan_keep(need, full, "avg", "Armor")
    local m = spill.moves[1]
    check("防具が尽きたら武器へ", m and m.slot_name, "LH")
    check("回した分の印", m and m.fallback, true)
end

print("[10] 目標にあるオプションでも、外して目標値を下回らなければ外す")
do
    -- クリ発 31,238 / 目標 25,000(余裕 6,238)。全種族が 1,000 足りない。
    -- 上着も手袋も目標ばかり(クリ発 4,000 / 力 500 / 中型相殺 / レザー)
    local function armor(name)
        return slot(name, "Armor", {op("CRTHR", 4000), op("STR", 500), op("MiddleSize_Def", 3000),
                                    op("ADD_LEATHER", 2900)})
    end
    local scan = {
        slots = {armor("SHIRT"), armor("GLOVES")}
    }
    local diag = diag_of({{
        opt = "AllRace_Atk",
        spot = "both",
        target = 16800,
        cur = 13000,
        short = 3800
    }, {
        opt = "CRTHR",
        spot = "both",
        target = 25000,
        cur = 31238,
        short = 0
    }, {
        opt = "STR",
        spot = "both",
        target = 5000,
        cur = 5865,
        short = 0
    }, {
        opt = "ADD_LEATHER",
        spot = "Armor",
        target = 8400,
        cur = 8400,
        short = 0
    }, {
        opt = "MiddleSize_Def",
        spot = "Armor",
        target = 8400,
        cur = 8400,
        short = 0
    }})
    AVG.Armor.AllRace_Atk = 2500
    local plan = Icor_planner_plan_keep(diag, scan, "avg", "Armor")
    local removed = {}
    for _, m in ipairs(plan.moves) do
        if m.from then
            removed[#removed + 1] = m.from.opt .. "=" .. m.from.value
        end
    end
    -- 上着は値の小さい力(余裕 865)を外す。手袋の力は余裕が 365 に減ったので外せず、
    -- クリ発(余裕 6,238)を外す。余裕の無い中型相殺 / レザーは外さない
    check("外したもの", table.concat(removed, ","), "STR=500,CRTHR=4000")
    check("あとオプション", plan.updates, 2)
    check("届く", plan.unmet_by_opt.AllRace_Atk, nil)
    -- 各部位の目標(体力を 2 部位に)は、目指す数ちょうどなら外さない
    local slot_diag = diag_of({{
        opt = "AllRace_Atk",
        spot = "both",
        target = 16800,
        cur = 13000,
        short = 3800
    }}, {{
        opt = "CON",
        spot = "both",
        min_value = 0,
        slots = {{
            value = 500,
            ok = true
        }, {
            value = 500,
            ok = true
        }},
        have = 2,
        want = 2
    }})
    local con_scan = {
        slots = {slot("SHIRT", "Armor", {op("CON", 500), op("STR", 500), op("MiddleSize_Def", 3000),
                                         op("ADD_LEATHER", 2900)}),
                 slot("GLOVES", "Armor", {op("CON", 500), op("STR", 500), op("MiddleSize_Def", 3000),
                                          op("ADD_LEATHER", 2900)})}
    }
    for _, opt in ipairs({"STR", "MiddleSize_Def", "ADD_LEATHER"}) do
        table.insert(slot_diag.rows, {
            opt = opt,
            spot = "both",
            target = 100,
            cur = 100,
            short = 0
        })
    end
    local p2 = Icor_planner_plan_keep(slot_diag, con_scan, "avg", "Armor")
    local con = false
    for _, m in ipairs(p2.moves) do
        if m.from and m.from.opt == "CON" then
            con = true
        end
    end
    check("目指す数ちょうどの体力は外さない", con, false)
    check("外せる枠が無いので届かない", p2.unmet_by_opt.AllRace_Atk, 3800)
    -- 目指す数が 1 なら 1 部位ぶんは外せる
    slot_diag.slot_rows[1].want = 1
    local p3 = Icor_planner_plan_keep(slot_diag, con_scan, "avg", "Armor")
    local con_n = 0
    for _, m in ipairs(p3.moves) do
        if m.from and m.from.opt == "CON" then
            con_n = con_n + 1
        end
    end
    check("目指す数を超えた 1 部位ぶんだけ外す", con_n, 1)
    AVG.Armor.AllRace_Atk = nil
end

-- 試算の差し替えは設定(icor_planner.json)へ保存する。ファイルには書かず、書いた回数だけ数える
g.cid = 1001
g.icor_planner_settings = {}
local saved_count = 0
function Icor_planner_save_settings()
    saved_count = saved_count + 1
end

print("[7] 自分で組むイコルは枠ごとに値を決める(一部だけ限凸)")
do
    -- 一番上の段の範囲(Lv560 の武器イコル相当)
    local RANGE = {
        AllMaterialType_Atk = {3702, 4113},
        STR = {650, 722},
        perfection = {12636, 14040}
    }
    function Icor_planner_top_range(opt, spot)
        local r = RANGE[opt]
        if r == nil then
            return 0, 0, nil
        end
        return r[1], r[2], 560
    end
    function Icor_planner_group_of(opt)
        return "ATK"
    end
    local n = Icor_planner_trial_set_custom("RH", "Weapon", {"AllMaterialType_Atk", "None", "perfection", "STR"},
        {"limit", "avg", "max", "min"})
    check("空き枠を挟んでも後ろの枠を読む", n, 3)
    local swap = Icor_planner_trial_swaps().RH
    check("限凸 = floor(最大 × 1.5)", swap.options[1].value, 6169)
    check("限凸は突破の色", swap.options[1].state, "break")
    check("最大", swap.options[2].value, 14040)
    check("最低", swap.options[3].value, 650)
    check("枠ごとの見込みを控える", table.concat(swap.custom.assumes, ","), "limit,max,min")
    check("段を控える", swap.lv, 560)
    -- 同じオプションは 1 つだけ
    local dup = Icor_planner_trial_set_custom("LH", "Weapon", {"STR", "STR"}, {"avg", "limit"})
    check("重なりは後ろを捨てる", dup, 1)
    -- 実物で確かめた値(Lv560 武器のパーフェクト 最大 14,040 → 限凸 21,060)
    Icor_planner_trial_set_custom("RH", "Weapon", {"perfection"}, {"limit"})
    check("パーフェクトの限凸", Icor_planner_trial_swaps().RH.options[1].value, 21060)
    check("防具の全種族(最大 3,296)の限凸", Icor_planner_limit_value(3296), 4944)
    check("防具のクリ発(最大 1,933)の限凸は切り捨て", Icor_planner_limit_value(1933), 2899)
    check("見込みを指定しなければ平均", Icor_planner_trial_set_custom("LH", "Weapon", {"STR"}, nil) and
        Icor_planner_trial_swaps().LH.options[1].value, 686)
end

print("[8] 試算の差し替えは保存して、次に開いたときに読み込む")
do
    -- [7] で RH / LH に組んだイコルが入っている
    local before = saved_count
    Icor_planner_trial_set_custom("SHIRT", "Armor", {"STR"}, {"max"})
    check("差し替えたら保存する", saved_count > before, true)
    local stored = g.icor_planner_settings.trial_swaps[tostring(g.cid)]
    check("キャラごとに控える", stored ~= nil and stored.SHIRT ~= nil, true)
    -- 再起動 = 溜め込みが無い状態から読み直す(JSON を通ったのと同じく、別の表として読ませる)
    local copy = {}
    for slot_name, swap in pairs(stored) do
        local c = {}
        for k, v in pairs(swap) do
            c[k] = v
        end
        c.options = {}
        for i, op in ipairs(swap.options) do
            c.options[i] = op
        end
        c.base_options = {}
        for i, op in ipairs(swap.options) do
            c.base_options[i] = op
        end
        copy[slot_name] = c
    end
    g.icor_planner_settings.trial_swaps[tostring(g.cid)] = copy
    g.icor_planner_trial = nil
    local swaps = Icor_planner_trial_swaps()
    check("読み込んだ", swaps.SHIRT and swaps.SHIRT.source, "custom")
    check("値も戻る", swaps.SHIRT and swaps.SHIRT.options[1].value, 722)
    check("リロールしていなければ options と base_options は同じ表に戻す",
        swaps.SHIRT and swaps.SHIRT.base_options == swaps.SHIRT.options, true)
    -- 別のキャラでは読み込まない
    g.cid = 2002
    check("別のキャラには出ない", next(Icor_planner_trial_swaps()), nil)
    g.cid = 1001
    check("元のキャラに戻れば出る", Icor_planner_trial_swaps().SHIRT ~= nil, true)
    -- 全部戻したら、そのキャラの控えも消す
    for k in pairs(Icor_planner_trial_swaps()) do
        Icor_planner_trial_swaps()[k] = nil
    end
    Icor_planner_trial_save()
    check("空なら控えを消す", g.icor_planner_settings.trial_swaps[tostring(g.cid)], nil)
end

if failed > 0 then
    print(string.format("FAILED: %d 件", failed))
    os.exit(1)
end
print("ALL OK")
