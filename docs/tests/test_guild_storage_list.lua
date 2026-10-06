-- guild_storage_list の計算・照合・告知文を luajit 上で検査する（ゲーム不要）。
--
-- 配布の個数は**間違えると取り消せない**（素の送付は戻せない）。実機では「数が合わない」と
-- 気付くのが送った後になるので、スプレッドシートの配布用シートと同じ数になることを機械で押さえる。
--
-- 使い方（リポジトリルートから）:
--     luajit docs/tests/test_guild_storage_list.lua

local PARTS = {"guild_storage_list/src/00_header.lua", "shared/src/10_json.lua", "shared/src/20_vlog.lua",
               "shared/src/30_frame.lua", "shared/src/40_esc.lua", "shared/src/50_frame_pos.lua",
               "shared/src/60_files.lua", "guild_storage_list/src/guild_storage_list.lua"}

package.preload["json"] = function()
    return {
        encode = function()
            return ""
        end,
        decode = function()
            return {}
        end
    }
end
session = {}
ui = {
    GetFrame = function()
        return nil
    end,
    SysMsg = function()
    end
}
option = {
    GetCurrentCountry = function()
        return "Japanese"
    end
}
imcTime = {
    GetAppTimeMS = function()
        return 0
    end
}
function AUTO_CAST(x)
    return x
end
table.unpack = table.unpack or unpack

local chunks = {}
for _, rel in ipairs(PARTS) do
    local f = assert(io.open(rel, "rb"), "読めない（リポジトリルートから実行すること）: " .. rel)
    chunks[#chunks + 1] = f:read("*a")
    f:close()
end
assert(load(table.concat(chunks, "\n"), "=core"))()

local g = _G["ADDONS"]["pinnkoro"]["_GUILD_STORAGE_LIST"]

local failures = 0
local function check(label, got, want)
    if got ~= want then
        failures = failures + 1
        print(string.format("  NG  %s: got=%s want=%s", label, tostring(got), tostring(want)))
    else
        print(string.format("  ok  %s = %s", label, tostring(got)))
    end
end

local function calc(stock, count, rule)
    local per, total, remain, short = g.guild_storage_list_calc(stock, count, rule)
    return string.format("%d/%d/%d%s", per, total, remain, short and " 不足" or "")
end

print("[1] 配布用シート(2026-10-03 時点、20 人)と同じ数になる")
-- 焔の破片: 食堂 20 を引いて均等割り = 109。シートは 5 個単位(M3=105)にしているので、
-- 同じ数にするなら指定に 105 を入れる。O3=2100 / R3=81
check("焔のイヤリングの破片(均等割り)", calc(2201, 20, {use = 1, reserve = 20}), "109/2180/1")
check("焔のイヤリングの破片(指定 105)", calc(2201, 20, {use = 1, reserve = 20, amount = 105}), "105/2100/81")
-- イコルの破片: 切り捨てだけ。M4=39 / O4=780 / R4=10
check("ゴッデスイコル(武器)の破片", calc(790, 20, {use = 1, reserve = 0}), "39/780/10")
-- 人数より少ない: 0 個。R6=10
check("上級のイコルの破片", calc(10, 20, {use = 1, reserve = 0}), "0/0/10")
check("サウレキューブ", calc(40, 20, {use = 1, reserve = 0}), "2/40/0")
check("バウバスキューブ Ⅳ", calc(80, 20, {use = 1, reserve = 0}), "4/80/0")

print("[2] 配らないもの・配れないとき")
check("配らない(use=0)", calc(100, 20, {use = 0, reserve = 0}), "0/0/100")
check("ルール無し", calc(100, 20, nil), "0/0/100")
check("対象者 0 人", calc(100, 0, {use = 1, reserve = 0}), "0/0/100")
check("取り置きが在庫以上", calc(10, 5, {use = 1, reserve = 20}), "0/0/10")
check("文字列の数", calc("21", "5", {use = 1, reserve = "1"}), "4/20/0")
check("指定 0 は均等割り", calc(21, 5, {use = 1, reserve = 0, amount = 0}), "4/20/1")

print("[2b] 指定(1 人あたりの数を決める)")
check("1 人 1 個(在庫が多くても 1 個)", calc(561, 18, {use = 1, reserve = 0, amount = 1}), "1/18/543")
check("ちょうど足りる", calc(18, 18, {use = 1, reserve = 0, amount = 1}), "1/18/0")
-- **足りないときに数を勝手に減らさない**。不足として返し、配る側で外す
check("足りない", calc(17, 18, {use = 1, reserve = 0, amount = 1}), "1/18/-1 不足")
check("取置を引くと足りない", calc(20, 18, {use = 1, reserve = 3, amount = 1}), "1/18/-1 不足")
check("配らないなら指定は効かない", calc(17, 18, {use = 0, reserve = 0, amount = 1}), "0/0/17")
check("配れる数(足りる)", g.guild_storage_list_sendable(561, 18, {use = 1, amount = 2}), 2)
check("配れる数(足りない)", g.guild_storage_list_sendable(17, 18, {use = 1, amount = 1}), 0)

print("[3] ギルドメンバーとの照合")
local matched, unmatched = g.guild_storage_list_match({{
    team = "くろねこ",
    units = 2
}, {
    team = "Yukichi",
    units = 1
}, {
    team = " TeamAB ",
    units = 3
}, {
    team = "抜けた人",
    units = 1
}, {
    team = "くろねこ",
    units = 9
}}, {"くろねこ", "yukichi", "TeamAB", "ほかの人"})
check("見つかった人数", #matched, 3)
check("1 人目はそのまま", matched[1].name, "くろねこ")
check("口数も持つ", matched[1].units, 2)
check("大文字小文字の違いはギルドでの表記へ寄せる", matched[2].name, "yukichi")
check("空白は落とす", matched[3].name, "TeamAB")
check("見つからない人数", #unmatched, 1)
check("見つからない人", unmatched[1], "抜けた人")
check("タグを落とす", g.guild_storage_list_norm("{ol}{#FFFFFF} みけねこ "), "みけねこ")

print("[4] base64url(vc_attendance の link.py と同じ結果になる)")
-- 期待値は Python の base64.urlsafe_b64encode(...).rstrip("=") で作ったもの
local b64 = {{"小枝", "5bCP5p6d"}, {"白詰草改", "55m96Kmw6I2J5pS5"}, {"PlayerLARK", "UGxheWVyTEFSSw"}, {"a", "YQ"},
             {"ab", "YWI"}, {"abc", "YWJj"}, {"サウレキューブ", "44K144Km44Os44Kt44Ol44O844OW"}}
for _, pair in ipairs(b64) do
    check("encode " .. pair[1], g.guild_storage_list_b64e(pair[1]), pair[2])
    check("decode " .. pair[2], g.guild_storage_list_b64d(pair[2]), pair[1])
end
check("読めない文字は nil", g.guild_storage_list_b64d("ab+c"), nil)
check("長さが合わないと nil", g.guild_storage_list_b64d("abcde"), nil)

print("[4b] 連携文字列と配布記録")
local link = g.guild_storage_list_parse_link("gsl1|20261004|9/21~9/27,9/28~10/4|5bCP5p6d:11,55m96Kmw6I2J5pS5:01")
check("ID", link and link.id, "20261004")
check("週の数", link and #link.weeks, 2)
check("2 週目の見出し", link and link.weeks[2], "9/28~10/4")
check("1 人目の名前", link and link.people[1].team, "小枝")
check("1 人目の口数", link and link.people[1].units, 2)
check("2 人目の口数", link and link.people[2].units, 1)
check("前後の空白は落とす", g.guild_storage_list_parse_link("  gsl1|X|9/21~9/27|YQ:1 ") ~= nil, true)
check("配っていない週が無い", #g.guild_storage_list_parse_link("gsl1|X||").weeks, 0)
check("形が違う", g.guild_storage_list_parse_link("gsr1|X||"), nil)
check("出席の桁が週の数と合わない", g.guild_storage_list_parse_link("gsl1|X|9/21~9/27|YQ:11"), nil)
check("名前が base64url でない", g.guild_storage_list_parse_link("gsl1|X|9/21~9/27|小枝:1"), nil)
check("配布記録", g.guild_storage_list_record("20261004", {{
    name = "サウレキューブ",
    per = 2
}, {
    name = "a",
    per = 105
}}, {"小枝"}), "gsr1|20261004|44K144Km44Os44Kt44Ol44O844OW:2,YQ:105|5bCP5p6d|")
check("除外なし", g.guild_storage_list_record("X", {}, {}), "gsr1|X|||")

print("[5] 並び")
local function names(list)
    local out = {}
    for _, v in ipairs(list) do
        out[#out + 1] = type(v) == "table" and v.class_name or v
    end
    return table.concat(out, ",")
end
local items = {{
    class_name = "A",
    name = "b",
    count = 10
}, {
    class_name = "B",
    name = "a",
    count = 30
}, {
    class_name = "C",
    name = "c",
    count = 20
}, {
    class_name = "D",
    name = "d",
    count = 20
}}
check("手動の並びが無ければスロット順", names(g.guild_storage_list_ordered(items, {})), "A,B,C,D")
check("手動の並び。無いものは後ろへスロット順で", names(g.guild_storage_list_ordered(items, {"C", "GONE", "A"})),
    "C,A,B,D")
check("元の配列は崩さない", names(items), "A,B,C,D")
local per = {
    A = 3,
    C = 1,
    D = 1
}
local function value_of(item, key)
    if key == "name" then
        return item.name
    elseif key == "stock" then
        return item.count
    end
    return per[item.class_name]
end
check("名前の昇順", names(g.guild_storage_list_sorted(items, {}, "name", false, value_of)), "B,A,C,D")
check("在庫の降順・同じ値は手動の並び", names(g.guild_storage_list_sorted(items, {"D", "C"}, "stock", true, value_of)),
    "B,D,C,A")
check("値が無いものは昇順でも後ろ", names(g.guild_storage_list_sorted(items, {}, "per", false, value_of)), "C,D,A,B")
check("値が無いものは降順でも後ろ", names(g.guild_storage_list_sorted(items, {}, "per", true, value_of)), "A,C,D,B")
check("key が空なら手動の並び", names(g.guild_storage_list_sorted(items, {"D"}, "", false, value_of)), "D,A,B,C")

local full = {"A", "B", "C", "D", "GONE"}
check("1 つ前へ", names(g.guild_storage_list_move(full, full, "C", -1)), "A,C,B,D,GONE")
check("1 つ後ろへ", names(g.guild_storage_list_move(full, full, "B", 1)), "A,C,B,D,GONE")
check("先頭は前へ動かない", g.guild_storage_list_move(full, full, "A", -1), nil)
check("絞り込み中は見えている隣と入れ替わる", names(g.guild_storage_list_move(full, {"A", "D"}, "D", -1)),
    "D,A,B,C,GONE")
check("見えていないものは動かない", g.guild_storage_list_move(full, {"A", "D"}, "B", 1), nil)

print("[5b] 配布記録の行(送ったものは送ったときの数で載せる。PR #220 のレビュー指摘)")
local function rows_text(rows, shorts)
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = r.name .. "=" .. r.per
    end
    return table.concat(out, ",") .. " / 不足:" .. table.concat(shorts, ",")
end
local use_all = function()
    return {
        use = 1
    }
end
-- 今の在庫での計算(送った後は在庫が減っている想定)
local after_send = {
    A = {0, false},
    B = {0, true},
    C = {3, false},
    D = {1, false}
}
local plan = function(item)
    return after_send[item.class_name][1], after_send[item.class_name][2]
end
check("送る前(sent なし)は今の在庫で計算", rows_text(g.guild_storage_list_record_rows(items, use_all, plan, {}, {})),
    "c=3,d=1 / 不足:a")
local sent = {
    A = {
        name = "b",
        per = 10
    },
    B = {
        name = "a",
        per = 5
    },
    GONE = {
        name = "送り切って消えた",
        per = 2
    }
}
check("送ったものは送ったときの数。0 個や在庫不足で抜けない",
    rows_text(g.guild_storage_list_record_rows(items, use_all, plan, sent, {"A", "GONE", "B"})),
    "b=10,a=5,c=3,d=1,送り切って消えた=2 / 不足:")
check("配らないものは載せない", rows_text(g.guild_storage_list_record_rows(items, function()
    return {
        use = 0
    }
end, plan, {}, {})), " / 不足:")

print("[6] 順に配る順番")
local rules = {
    A = {
        use = 1
    },
    B = {
        use = 0
    },
    C = {
        use = 1
    },
    D = {
        use = 1
    }
}
local per_of = {
    A = 3,
    B = 5,
    C = 0,
    D = 1
}
local queue = g.guild_storage_list_dist_queue(g.guild_storage_list_ordered(items, {"D", "C", "B", "A"}),
    function(class_name)
        return rules[class_name]
    end, function(item)
        return per_of[item.class_name]
    end)
check("配る ON かつ 1 人 1 個以上だけ、一覧の並びで", names(queue), "D,A")

print("[7] 取り置きを配る順番")
local reserves = {
    A = {
        reserve = 20
    },
    B = {
        reserve = 0
    },
    C = {
        reserve = 25
    },
    D = {
        reserve = "5"
    }
}
-- 在庫は A=30 / B=30(取置 0) / C=20(取置 25 に足りない) / D=20(取置は文字列の "5")
local stock_items = {{
    class_name = "A",
    count = 30
}, {
    class_name = "B",
    count = 30
}, {
    class_name = "C",
    count = 20
}, {
    class_name = "D",
    count = 20
}}
check("取置が 1 以上で在庫が足りるものだけ、一覧の並びで",
    names(g.guild_storage_list_reserve_queue(stock_items, function(class_name)
        return reserves[class_name]
    end)), "A,D")

if failures > 0 then
    print(string.format("FAILED: %d", failures))
    os.exit(1)
end
print("ALL PASSED")
