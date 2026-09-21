-- Icor Planner の「あとオプション N 個」の数え方を luajit 上で検査する（ゲーム不要）。
--
-- 見るのは実機で指摘された 2 件。**どちらも画面に数が出るだけで、間違っていても気付きにくい。**
--   * 更新するイコルを選んでいないとき、今の装備を残したまま足りない分だけを数えること
--     （以前は理想の形との差を数えていて、レザー相殺だけ 1,104 足りないのに 7 個と出た）
--   * 試算で「更新するイコル」を差し替えても、数え方が入れ替わらないこと
--     （手袋を差し替えたら 1 → 7 と、別の物差しの数を比べていた）
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

print("[3] 同じだけ埋まるなら、枠を使わず値を上げる方を採る")
do
    -- レザー相殺が 300 足りない。靴のレザー 2,932 は見込み(2,600)より高いので上げられない。
    -- 見込みを 3,400 にすると、靴の値上げ(+468)と空き枠(+3,400)はどちらも 300 を埋める
    AVG.Armor.ADD_LEATHER = 3400
    local diag = diag_of({{
        opt = "ADD_LEATHER",
        spot = "Armor",
        target = 8400,
        cur = 8100,
        short = 300
    }})
    local plan = Icor_planner_plan(diag, armor_scan(), "avg")
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

print("[6b] 「全ての〜」でつながるオプションは外さない")
do
    -- 目標は 全ての防具の材質(今の値はクロース / レザー… の一番低い値)。
    -- 手袋のクロース対象攻撃力は目標に無いが、クロースの値を支えているので外してはいけない
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
    check("値の小さいクロース(300)ではなく、目標に関係ない枠を外す", plan.moves[1] and plan.moves[1].from and plan.moves[1].from.opt,
        "CON")
    -- 逆向き: 目標がクロース、枠が 全ての防具の材質
    local need2 = diag_of({{
        opt = "ADD_CLOTH",
        spot = "Armor",
        target = 99999,
        cur = 0,
        short = 99999
    }})
    AVG.Armor.ADD_CLOTH = 2000
    local plan2 = Icor_planner_plan(need2, scan_with({op("AllMaterialType_Atk", 2800), op("ADD_LEATHER", 100),
                                                      op("STR", 500), op("CON", 500)}), "avg")
    local removed = {}
    for _, m in ipairs(plan2.moves) do
        if m.from then
            removed[m.from.opt] = true
        end
    end
    AVG.Armor.ADD_CLOTH = nil
    check("全ての防具の材質は外さない", removed.AllMaterialType_Atk, nil)
    check("同じ輪の兄弟(レザー)はクロースを支えないので外してよい", removed.ADD_LEATHER, true)
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

if failed > 0 then
    print(string.format("FAILED: %d 件", failed))
    os.exit(1)
end
print("ALL OK")
