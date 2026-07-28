local addon_name = "_NEXUS_ADDONS_P"
local addon_name_lower = string.lower(addon_name)
local author = "norisan"
_G["ADDONS"] = _G["ADDONS"] or {}
_G["ADDONS"][author] = _G["ADDONS"][author] or {}
_G["ADDONS"][author][addon_name] = _G["ADDONS"][author][addon_name] or {}
local g = _G["ADDONS"][author][addon_name]
-- 【解消済みの前提】かつてこの部分は別ファイル(_nexus_addons_p_conclude.lua)で、
-- **main(_nexus_addons_p.lua)より先に読まれることがあった**(実機で確認)。その場合、
-- 上の 3 行は main とは無関係に空のテーブルを新規に作り、直後の guard_open.lua で
-- g.detect_origin_addon が nil になって、**チャンクの読み込みがそこで止まり
-- conclude 側のアドオンが丸ごと消えた**。main は無事なので他は普通に動き、
-- 「一部のアドオンだけ無反応」だけが残る。読み込み順は同居するアドオンの顔ぶれで
-- 変わるため、「単体なら出るのに他のアドオンを入れると出ない」「起動ごとに揺れる」
-- という形で表面化していた。
--
-- 現在は _nexus_addons_p.lua 1 本に取り込まれ、**この直前に core が必ず走っている**
-- ので、上の 3 行は main が作ったテーブルをそのまま拾う。順序の問題は消えた。
-- ただし下の救済分岐は残す(_G["ADDONS"] を他アドオンに作り直される事故は別件で、
-- 1 本化しても起こりうる)。
--
-- 下は「main が先に読まれたが _G["ADDONS"] だけ他アドオンに作り直された」場合の救済。
-- main が素の名前で置いた本体を優先し、_G["ADDONS"] 側も繋ぎ直す。
-- 先読みのときは _nexus_addons_p_core_g もまだ無いので、この分岐は素通りする。
if type(_G["_nexus_addons_p_core_g"]) == "table" then
    -- 別物を掴んでいたときだけ印を残す(正常時に立てると意味が無くなる)。
    -- 報告は GAME_START で行う。ここは g.settings より前なので vlog が使えない。
    local rebuilt = (g ~= _G["_nexus_addons_p_core_g"])
    g = _G["_nexus_addons_p_core_g"]
    _G["ADDONS"][author][addon_name] = g
    if rebuilt then
        g.addons_table_rebuilt = true
    end
end
-- ここにあった local json = require("json") は削除した。どこからも使っていないうえ、
-- **読み込み時に走る require を素で書くと、例外でこの下の定義が丸ごと失われる**
-- (conclude_scope_open.lua)。

-- 【この節の前提は解消済み】かつて配布 .lua は _nexus_addons_p.lua と
-- _nexus_addons_p_conclude.lua の 2 本で、クライアントはそれぞれを別のチャンクとして
-- 読んでいた。**その読み込み順は保証されず、片方だけ読まれない事故が実際にあった**
-- (mini_addons と market_favorite_rebuild が揃って無反応になる = この 2 つは conclude 側に
-- しか入っていなかった)。読めていないと定義が丸ごと無いので、当のファイルの中には
-- 「読めなかった」と言える場所が存在しない。そこで**読めたときに印を置く**ようにした。
--
-- 現在この 3 アドオンは conclude_scope_open.lua / conclude_scope_close.lua の
-- do ... end に包まれて _nexus_addons_p.lua **1 本**に取り込まれており、
-- 読み込み順の問題そのものが消えている。それでも印は残す。1 本になっても
-- 「途中で例外が出て後ろが失われる」経路は残っており(下の conclude_stage)、
-- 同じ症状が出たときに切り分けられるのはこの 2 つだけだから。
-- ここは g.settings より前なので vlog は使えない。判定は GAME_START 側で行う
-- (core/20_lifecycle.lua の _nexus_addons_p_GAME_START)。
g.conclude_loaded = true
-- どこまで読めたかの目印。conclude は 3 アドオンを連結した 1 本のチャンクなので、
-- **途中で例外が出るとそこから後ろの定義が丸ごと失われる**。しかも読み込み時の例外は
-- どこにも残らないため、「特定のアドオンだけ無反応」という形でしか表に出ない。
-- 各アドオンの末尾でこの値を更新し、GAME_START でどこまで届いたかを出す
-- (core/20_lifecycle.lua)。最後まで通れば "market_favorite_rebuild" になる。
g.conclude_stage = "header"

local function ts(...)
    local num_args = select("#", ...)
    if num_args == 0 then
        print("ts() -- 引数がありません")
        return
    end
    local string_parts = {}
    for i = 1, num_args do
        local arg = select(i, ...)
        local arg_type = type(arg)
        local is_success, value_str = pcall(tostring, arg)
        if not is_success then
            value_str = "[tostringでエラー発生]"
        end
        table.insert(string_parts, string.format("(%s) %s", arg_type, value_str))
    end
    print(table.concat(string_parts, "   |   "))
end
