-- Guild Storage List — ギルド保管庫の配布を手伝うアドオン
--
-- 保管庫の中身を文字の一覧にし、封鎖戦の出席(vc_attendance の Bot がスプレッドシートに書く連携文字列)から
-- 1 人あたりの配布数を出して、素の送付窓に対象者と個数を入れておく。使い方は README.md を参照。
--
-- **このファイルは単体版の土台。** 共通部品(shared/src/**)が使う
-- g / addon_name_lower / json を用意し、詳細ログの印と設定の入れ物を決める。
-- 共通部品は Nexus Addons P と共有しているので、あちらの都合をここへ持ち込まないこと
-- (詳しくは shared/README.md)。
--
-- Nexus Addons P v2.13.x までは同梱していた。本体(guild_storage_list.lua)が使っていた
-- Nexus の共通基盤のうち、共通部品に無いもの(g.register_msg / g.setup_hook / g.scroll_cur_pos)は
-- ここで最小限の形で用意する。
local addon_name = "_GUILD_STORAGE_LIST"
local addon_name_lower = string.lower(addon_name)
local author = "pinnkoro"
local ver = "1.0.0"

_G["ADDONS"] = _G["ADDONS"] or {}
_G["ADDONS"][author] = _G["ADDONS"][author] or {}
_G["ADDONS"][author][addon_name] = _G["ADDONS"][author][addon_name] or {}
local g = _G["ADDONS"][author][addon_name]
-- **素の名前でも本体テーブルを引けるようにしておく。** _G["ADDONS"] は全アドオン共有で、
-- `= {}` と書くアドオンが居ると入れ替わってしまう(Nexus Addons P と同じ理由)。
_G["_guild_storage_list_core_g"] = g
g.ver = ver
local json = require("json")

-- 詳細ログ(共通部品 shared/src/20_vlog.lua)がチャットへ出すときの印
g.vlog_tag = "GSL"
-- ESC の割り込み先(共通部品 shared/src/40_esc.lua が ui.SetEscapeScp へ渡す)。
-- **90_init.lua で購読しているグローバルと同じ名前にすること。**
-- ここが合っていないと、窓を開いた後に ESC でシステムメニューが開かなくなる
g.esc_scp_call = "_GUILD_STORAGE_LIST_ESCAPE_PRESSED()"

-- 共通部品と本体が見る設定の入れ物。
--   verbose_log … 詳細ログを出すか(0 / 1)
--   guild_storage_list.use … 機能の ON / OFF。**単体版は常に 1**(アドオンごと入れ外しするため)
-- 配布のルールや並びは別ファイル(<AID>/guild_storage_list.json)で、本体側が読み書きする。
g.settings_path = string.format("../addons/%s/settings.json", addon_name_lower)
g.settings = {
    verbose_log = 0,
    guild_storage_list = {
        use = 1
    }
}

function g.load_core_settings()
    local loaded = g.load_json(g.settings_path)
    if type(loaded) == "table" then
        g.settings.verbose_log = loaded.verbose_log == 1 and 1 or 0
    end
end

function g.save_core_settings()
    g.save_json(g.settings_path, {
        verbose_log = g.settings.verbose_log
    })
end

-- ===== Nexus Addons P の共通基盤の代わり =====

-- メッセージの購読。単体版は addon オブジェクトを自分だけで持っているので、潰し合いは起きない。
-- 購読は ON_INIT のたびに新しい addon へ張り直す必要がある(古い addon への購読は届かなくなる)ので、
-- GAME_START から毎回呼ばれる前提で書く(同じメッセージを張り直しても 1 本のまま)。
function g.register_msg(msg, func_name)
    if not g.addon then
        g.vlog("{#FF6347}register_msg: addon がまだ無いので %s を購読できない{/}", tostring(msg))
        return
    end
    g.addon:RegisterMsg(msg, func_name)
end

-- 置き換え方式のフック。素の関数を g.FUNCS へ控えて、_G を自分の関数へ差し替える。
-- 差し替えた関数は**必ず g.FUNCS[名前] で素を呼ぶ**(CLAUDE.md「素の関数を書き写さない」)。
--
-- **素を控えるのは最初の 1 回だけ。** 2 回目以降に「今の _G」を控えると、後から別のアドオンが
-- 自分を包んでいた場合に 自分 → 相手 → 自分 … と回り続ける。
-- **外れていたら掛け直す。** 掛けたのに _G が別物に入れ替わっていたら(素のスクリプトの読み直しや
-- 他のアドオンの上書き)、控えた素を呼ぶ形のまま自分を入れ直す(Nexus Addons P の g.setup_hook と同じ規則)。
-- 「1 回掛けたら終わり」にしていた頃、配布中に送るボタンのフックが効かず、送った後に次へ進まなかった
-- (2026-10-06 実機。外れていたかどうかは g.check_hooks のログで確かめる)。
-- nil を渡されたとき(関数名の綴り間違いなど)は素を消さずに何もしない。
g.FUNCS = g.FUNCS or {}
-- 掛けたフック。素の名前 → 自分の関数(g.check_hooks が見回る)
g.hooks_installed = g.hooks_installed or {}
function g.setup_hook(my_func, origin_func_name)
    if type(my_func) ~= "function" then
        g.vlog("{#FF6347}setup_hook: %s へ掛ける関数が無い(nil)ので、素はそのままにする{/}", origin_func_name)
        return
    end
    if not g.FUNCS[origin_func_name] then
        local origin = _G[origin_func_name]
        if type(origin) ~= "function" then
            g.vlog("{#FF6347}setup_hook: 素の %s が無いので掛けない{/}", origin_func_name)
            return
        end
        g.FUNCS[origin_func_name] = origin
        g.vlog("setup_hook: %s を掛けた", origin_func_name)
    elseif _G[origin_func_name] ~= my_func then
        g.vlog("{#FF6347}setup_hook: %s が外れていたので掛け直す{/}", origin_func_name)
    end
    _G[origin_func_name] = my_func
    g.hooks_installed[origin_func_name] = my_func
end

-- 掛けたフックが外れていないかを見回り、外れていたら掛け直す。
-- 0.5 秒ごとの見回り(90_init.lua)と、配布で送付窓を開く直前に呼ぶ。外れていなければ何も出さない
function g.check_hooks()
    for name, my_func in pairs(g.hooks_installed) do
        if _G[name] ~= my_func then
            g.setup_hook(my_func, name)
        end
    end
end

-- groupbox のスクロール位置。古いクライアントに GetScrollCurPos が無くても落とさない
function g.scroll_cur_pos(gbox)
    local ok, pos = pcall(function()
        return gbox:GetScrollCurPos()
    end)
    if ok and type(pos) == "number" then
        return pos
    end
    if not g.scroll_api_failed then
        g.scroll_api_failed = true
        g.vlog("GetScrollCurPos が使えない(%s)。スクロール位置は引き継げない", tostring(pos))
    end
    return 0
end
