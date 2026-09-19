-- Icor Planner — イコルの更新計画を立てるアドオン
--
-- 目標のステータスと目標値を決めると、そこへ届くまでにオプションをあと何個更新すれば
-- よいかと、武器 / 防具のイコルに何を載せればよいか(オススメの構成)を出す。
-- 使い方は README.md を参照。
--
-- **このファイルは単体版の土台。** 共通部品(shared/src/**)が使う
-- g / addon_name_lower / json を用意し、詳細ログの印と設定の入れ物を決める。
-- 共通部品は Nexus Addons P と共有しているので、あちらの都合をここへ持ち込まないこと
-- (詳しくは shared/README.md)。
local addon_name = "_ICOR_PLANNER"
local addon_name_lower = string.lower(addon_name)
local author = "pinnkoro"
local ver = "1.0.0"

_G["ADDONS"] = _G["ADDONS"] or {}
_G["ADDONS"][author] = _G["ADDONS"][author] or {}
_G["ADDONS"][author][addon_name] = _G["ADDONS"][author][addon_name] or {}
local g = _G["ADDONS"][author][addon_name]
-- **素の名前でも本体テーブルを引けるようにしておく。** _G["ADDONS"] は全アドオン共有で、
-- `= {}` と書くアドオンが居ると入れ替わってしまう(Nexus Addons P と同じ理由)。
_G["_icor_planner_core_g"] = g
g.ver = ver
local json = require("json")

-- 詳細ログ(共通部品 shared/src/20_vlog.lua)がチャットへ出すときの印
g.vlog_tag = "IP"

-- 共通部品と本体が見る設定の入れ物。
--   verbose_log … 詳細ログを出すか(0 / 1)
--   icor_planner.use … 機能の ON / OFF。**単体版は常に 1**(アドオンごと入れ外しするため)
-- 目標プリセットは別ファイル(icor_planner.json)で、本体側が読み書きする。
g.settings_path = string.format("../addons/%s/settings.json", addon_name_lower)
g.settings = {
    verbose_log = 0,
    icor_planner = {
        use = 1
    },
    -- 画面に出す「イコル計画」ボタンの位置(掴んで動かしたら覚える)
    button_pos = nil
}

function g.load_core_settings()
    local loaded = g.load_json(g.settings_path)
    if type(loaded) == "table" then
        if loaded.verbose_log == 1 then
            g.settings.verbose_log = 1
        end
        if type(loaded.button_pos) == "table" then
            g.settings.button_pos = loaded.button_pos
        end
    end
end

function g.save_core_settings()
    g.save_json(g.settings_path, {
        verbose_log = g.settings.verbose_log,
        button_pos = g.settings.button_pos
    })
end

-- 詳細ログの ON / OFF。設定画面は持たないので、チャットコマンドから切り替える
function g.toggle_verbose_log()
    g.settings.verbose_log = (g.settings.verbose_log == 1) and 0 or 1
    g.save_core_settings()
    ui.SysMsg(string.format("{ol}{#00BFFF}[IP]{/} 詳細なログを %s にしました (%s)",
        g.settings.verbose_log == 1 and "ON" or "OFF",
        string.format("../addons/%s/verbose_log.txt", addon_name_lower)))
end
