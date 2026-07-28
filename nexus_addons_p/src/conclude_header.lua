local addon_name = "_NEXUS_ADDONS_P"
local addon_name_lower = string.lower(addon_name)
local author = "norisan"
_G["ADDONS"] = _G["ADDONS"] or {}
_G["ADDONS"][author] = _G["ADDONS"][author] or {}
_G["ADDONS"][author][addon_name] = _G["ADDONS"][author][addon_name] or {}
local g = _G["ADDONS"][author][addon_name]
-- **このファイルが main(_nexus_addons_p.lua)より先に読まれることがある。** 実機で確認済み。
-- その場合、上の 3 行は main とは無関係に空のテーブルを新規に作り、直後の
-- guard_open.lua で g.detect_origin_addon が nil になって、
-- **チャンクの読み込みがそこで止まり conclude 側のアドオンが丸ごと消える**。
-- main は無事なので他の 49 個は普通に動き、「一部のアドオンだけ無反応」だけが残る。
-- 読み込み順は同居するアドオンの顔ぶれで変わるため、「単体なら出るのに他のアドオンを
-- 入れると出ない」「起動ごとに揺れる」という形で表面化する。
--
-- **conclude 側は main が読み込み済みであることを前提にしてはいけない。**
-- なお先にこちらが作ったテーブルは、後から main の `... or {}` がそのまま拾うので、
-- 実行時には同じテーブルを共有できる(順序が逆でも機能は失われない)。
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
local json = require("json")

-- 配布 .lua は _nexus_addons_p.lua と _nexus_addons_p_conclude.lua の 2 本で、
-- クライアントはそれぞれを別のチャンクとして読む。**片方だけ読まれない事故が実際にある**
-- (mini_addons と market_favorite_rebuild が揃って無反応になる = この 2 つは conclude 側に
-- しか入っていない)。読めていないと定義が丸ごと無いので、当のファイルの中には
-- 「読めなかった」と言える場所が存在しない。そこで**読めたときに印を置く**。
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
