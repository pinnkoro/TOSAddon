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
check("以前の版の map は捨てる", boss({cls = "z", map = "weekly_f_gele_57_4"}).map, nil)

print("[7] ボスの検索(部分一致)")
local index = {{cls = "Raid_boss_Naktis", name = "ナクティス"}, {cls = "Raid_boss_Naktis_hard", name = "ナクティス"},
               {cls = "boss_Velnias", name = "ベルニアス"}}
local hits, total = g.bam_search(index, "クティ", 50)
check("名前の途中で当たる", total, 2)
hits, total = g.bam_search(index, "NAKTIS_H", 50)
check("ClassName でも当たる(大文字小文字を区別しない)", total == 1 and hits[1].cls, "Raid_boss_Naktis_hard")
hits, total = g.bam_search(index, "ス", 1)
check("上限で切る", #hits, 1)
check("総数は数える", total, 3)
hits, total = g.bam_search(index, "", 50)
check("空なら何も返さない", #hits + total, 0)
hits, total = g.bam_search(index, "%a", 50)
check("パターン文字は文字として扱う", total, 0)

print("[8] 「共通」の登録は先頭に決まった順で置く(無ければ作る)")
g.active_id = "TESTAID"
g.save_json = function() end
g.load_json = function()
    return {bosses = {{cls = "boss_x", name = "X"}, {cls = "@field_boss", hp = {{pct = 30, text = "keep"}}}}}
end
Boss_action_monitor_load_settings()
local order = {}
for _, b in ipairs(g.bam_settings.bosses) do
    order[#order + 1] = b.cls
end
check("並び", table.concat(order, ","), "@weekly_boss,@field_boss,boss_x")
check("既存の共通の件は残る", g.bam_settings.bosses[2].hp[1].text, "keep")
Boss_action_monitor_load_settings()
check("読み直しても増えない", #g.bam_settings.bosses, 3)
check("共通は表示名が言語に合う", Boss_action_monitor_group(g.bam_settings.bosses[1]).cls, "@weekly_boss")
check("普通のボスは共通ではない", Boss_action_monitor_group(g.bam_settings.bosses[3]), nil)

print("[9] 長い名前を幅で切る")
check("収まるならそのまま", (g.bam_fit_text("魔将ヘルガ・セルクル", 148)), "魔将ヘルガ・セルクル")
local cut, was_cut = g.bam_fit_text("[週間ボスレイド] ヴェルニケの影", 148)
check("はみ出すなら … で切る", was_cut, true)
check("切った結果", cut, "[週間ボスレイド] ヴ…")
check("英字は半分の幅で数える", (g.bam_fit_text(string.rep("a", 21), 148)), string.rep("a", 21))
check("英字でも切る", (g.bam_fit_text(string.rep("a", 22), 148)), string.rep("a", 19) .. "…")
check("空", (g.bam_fit_text("", 148)), "")

print("[10] パターンの条件")
local bp = boss({cls = "@weekly_boss", time = {{at = 270, text = "火の障壁", pattern = "Weekly_FireWall"},
                                               {at = 140, text = "条件なし"}, {at = 60, pattern = 3}}})
check("pattern が無ければ空", bp.time[2].pattern, "")
check("pattern が文字でなければ空", bp.time[3].pattern, "")
local passed = g.bam_pattern_pass(bp.time, {Weekly_FireWall = true})
check("パターンがあれば条件付きも通る", #passed, 3)
check("通すのは元の件", passed[1], bp.time[1])
passed = g.bam_pattern_pass(bp.time, {Weekly_Ice_Wall = true})
check("パターンが無ければ条件付きは通さない", #passed, 2)
check("条件なしは通る", passed[1].text, "条件なし")
check("パターンが分からなければ条件付きは通さない", #g.bam_pattern_pass(bp.time, nil), 2)
local due = g.bam_time_due(g.bam_pattern_pass(bp.time, {Weekly_FireWall = true}), 271, 269)
check("パターンがある週は 4:30 で出る", #due == 1 and due[1].trig.text, "火の障壁")
due = g.bam_time_due(g.bam_pattern_pass(bp.time, {}), 271, 269)
check("パターンが無い週は出ない", #due, 0)

print("[11] 間隔ごとに繰り返す")
local br = boss({cls = "@weekly_boss", time = {{at = 402, before = 10, every = 50, pattern = "Weekly_FireWall"}}})
local occ = g.bam_occurrences(br.time[1])
check("回数", #occ, 9)
check("2 回目は 5:52", occ[2], 352)
check("最後は 0:02", occ[9], 2)
local d2 = g.bam_time_due(br.time, 353, 351)
check("2 回目もちょうどで出る", #d2 == 1 and d2[1].kind == "at" and d2[1].at, 352)
d2 = g.bam_time_due(br.time, 363, 361)
check("2 回目の 10 秒前も出る", #d2 == 1 and d2[1].kind == "before" and d2[1].at, 352)
check("繰り返さない件は 1 回", #g.bam_occurrences({at = 270, every = 0}), 1)
check("every が壊れていたら 0", boss({cls = "q", time = {{at = 10, every = "x"}}}).time[1].every, 0)
local nt, nt_at = g.bam_next_time(br.time, 380)
check("次は繰り返しの近い回", nt_at, 352)
check("次の件は元の件", nt, br.time[1])

print("[12] パターンの最初の時刻と、件の用意")
local ms, jit = g.bam_parse_start("18000")
check("1 つなら揺れなし", ms == 18000 and jit, false)
ms, jit = g.bam_parse_start("13000/43000")
check("2 つなら早い方", ms, 13000)
check("2 つなら揺れあり", jit, true)
check("空は nil", (g.bam_parse_start("")), nil)
local plist = {{cls = "Weekly_FireWall", start_ms = 18000, every = 50, timed = true},
               {cls = "Weekly_Thunderstroke", start_ms = 13000, every = 40, timed = true},
               {cls = "Weekly_Ballista", start_ms = 13000, every = 10, timed = true},
               {cls = "Weekly_StarFall", start_ms = 83000, every = 450, timed = true},
               {cls = "Weekly_PurifyingStone", start_ms = 0, every = 999, timed = false}}
local prows = {{at = 100, pattern = "Weekly_Thunderstroke"}}
check("足した件数(既にあるものと時間で出ないものは足さない)", g.bam_pattern_preset(prows, plist, 420), 3)
check("火の障壁は 6:42", prows[2].at, 402)
check("火の障壁は 50 秒ごと", prows[2].every, 50)
check("火の障壁は 10 秒前", prows[2].before, 10)
check("間隔が短いものは何秒前なし", prows[3].before, 0)
check("タイマーより長い間隔は繰り返さない", prows[4].every, 0)
check("条件はパターン", prows[2].pattern, "Weekly_FireWall")
check("2 回目は何も足さない", g.bam_pattern_preset(prows, plist, 420), 0)

if failures > 0 then
    print(string.format("FAILED: %d 件", failures))
    os.exit(1)
end
print("ALL OK")
