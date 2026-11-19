-- Boss Action Monitor の判定を検査する（ゲーム不要）。
--
-- 知らせが出なくても、出すぎても、画面からは「たまたまそうだった」のか分からない。
-- ボス戦の最中にしか確かめられないので、次を機械で見る。
--   * 残り時間の跨ぎ（N 秒前とその時点・飛んだとき・出直したとき）
--   * HP の下回り（1 回だけ・途中から見たボスでは過ぎた件を出さない）
--   * "4:30" の読み取りと、壊れた設定の補正
--
-- 使い方（リポジトリルートから）:
--     luajit docs/tests/test_boss_action_monitor.lua
--
-- 見るのは g に置いた純ロジックだけなので、このファイル単体を空の g で読む。

g = {}
addon_name_lower = "_nexus_addons_p"
local f = assert(io.open("nexus_addons_p/src/addons/boss_action_monitor/boss_action_monitor.lua", "rb"),
    "読めない（リポジトリルートから実行すること）")
local src = f:read("*a")
f:close()
assert(load(src, "=boss_action_monitor"))()

local failures = 0
local function check(name, got, want)
    if got == want then
        print("  ok   " .. name)
    else
        failures = failures + 1
        print(string.format("  FAIL %s: got=%s want=%s", name, tostring(got), tostring(want)))
    end
end

local function due_str(list)
    local parts = {}
    for _, d in ipairs(list) do
        parts[#parts + 1] = d.kind .. "@" .. tostring(d.trig.at or d.trig.pct)
    end
    return table.concat(parts, ",")
end

print("[1] 時刻の読み取り")
check("4:30", g.bam_parse_time("4:30"), 270)
check("04:30", g.bam_parse_time("04:30"), 270)
check("秒だけ", g.bam_parse_time("270"), 270)
check("空白は無視", g.bam_parse_time(" 7:00 "), 420)
check("秒が 60 以上は読めない", g.bam_parse_time("4:75"), nil)
check("打ちかけ", g.bam_parse_time("4:"), nil)
check("空", g.bam_parse_time(""), nil)
check("書式", g.bam_fmt_time(270), "4:30")
check("1 桁の秒", g.bam_fmt_time(125), "2:05")

local function boss(t)
    return g.bam_normalize_boss(t)
end

print("[2] 残り時間: N 秒前とその時点")
local b = boss({cls = "naktis", time = {{at = 270, before = 10, text = "shield"}}})
check("4:41 → 4:40 で 10 秒前", due_str(g.bam_time_due(b.time, 281, 280)), "before@270")
check("4:31 → 4:30 でその時点", due_str(g.bam_time_due(b.time, 271, 270)), "at@270")
check("4:30 → 4:29 では何も無い", due_str(g.bam_time_due(b.time, 270, 269)), "")
check("同じ秒なら何も無い", due_str(g.bam_time_due(b.time, 270, 270)), "")
check("前回が無ければ何も無い", due_str(g.bam_time_due(b.time, nil, 270)), "")
check("2 秒飛んでも跨げば出る", due_str(g.bam_time_due(b.time, 272, 270)), "at@270")
check("大きく飛んだら出さない", due_str(g.bam_time_due(b.time, 300, 260)), "")
check("増えた(出直した)ら出さない", due_str(g.bam_time_due(b.time, 100, 420)), "")
local b0 = boss({cls = "x", time = {{at = 140, before = 0}}})
check("before 0 はその時点だけ", due_str(g.bam_time_due(b0.time, 151, 150)) .. "|" ..
    due_str(g.bam_time_due(b0.time, 141, 140)), "|at@140")
local boff = boss({cls = "x", time = {{at = 140, before = 0, on = false}}})
check("OFF は出ない", due_str(g.bam_time_due(boff.time, 141, 140)), "")

print("[3] HP: 下回ったら 1 回だけ")
local bh = boss({cls = "x", hp = {{pct = 70, text = "a"}, {pct = 50, text = "b"}}})
local state = {}
check("初回 100% は何も無い", due_str(g.bam_hp_due(bh.hp, state, 100)), "")
check("70% ちょうどで出る", due_str(g.bam_hp_due(bh.hp, state, 70)), "hp@70")
check("下回ったままでは二度出ない", due_str(g.bam_hp_due(bh.hp, state, 65)), "")
check("回復しても二度出ない", due_str(g.bam_hp_due(bh.hp, state, 80)), "")
check("一気に 40% まで落ちたら 50% が出る", due_str(g.bam_hp_due(bh.hp, state, 40)), "hp@50")

print("[4] HP: 途中から見たボスでは過ぎた件を出さない")
local late = {}
check("初めて見た時点で 60%", due_str(g.bam_hp_due(bh.hp, late, 60)), "")
check("その後 50% は出る", due_str(g.bam_hp_due(bh.hp, late, 49.5)), "hp@50")

print("[5] 次の件")
local bn = boss({cls = "x", time = {{at = 270}, {at = 140}, {at = 30, on = false}}})
check("残り 300 の次は 4:30", g.bam_next_time(bn.time, 300).at, 270)
check("残り 200 の次は 2:20", g.bam_next_time(bn.time, 200).at, 140)
check("OFF は数えない", g.bam_next_time(bn.time, 100), nil)

print("[6] 壊れた設定の補正")
local broken = boss({cls = "x", duration = "abc", hp = {{pct = 150}}, time = {{at = -5, before = 9999}}, name = 3})
check("duration", broken.duration, 0)
check("pct 上限", broken.hp[1].pct, 99)
check("at 下限", broken.time[1].at, 0)
check("before 上限", broken.time[1].before, 600)
check("name は cls", broken.name, "x")
check("text は空", broken.hp[1].text, "")
check("on は ON", broken.time[1].on, true)
local empty = boss({cls = "y"})
check("hp が無ければ空の表", type(empty.hp) == "table" and #empty.hp, 0)
check("map が無ければ空", empty.map, "")

if failures > 0 then
    print(string.format("FAILED: %d 件", failures))
    os.exit(1)
end
print("ALL OK")
