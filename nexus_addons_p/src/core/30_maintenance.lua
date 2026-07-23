-- 設定の一括操作（全アドオン OFF / バックアップ / 復元）
--
-- ボタンはアドオン一覧フレーム(_nexus_addons_p_frame_init)のタイトル行に出す。
-- 一覧は各アドオンの ON/OFF を並べている画面なので、まとめて OFF にする操作と
-- その設定ごと退避/復旧する操作を同じ場所に置いている。
--
-- ===== バックアップの対象と方法 =====
-- 対象は ../addons/_nexus_addons_p/<AID>/ 配下まるごと。settings.json だけでなく
-- 各アドオンの .json/.lua/.dat や monster_kill_count/<map_id>.json のような可変名の
-- ファイルもあり、Lua 側にディレクトリ列挙が無いのでファイル名を列挙できない。
-- よってコピーは xcopy に任せ、失敗したときだけ settings.json を自前でコピーする
-- フォールバックを持つ(g.migrate_from_origin と同じ作り。あちらのコメントも参照)。
--
-- 保存先は AID フォルダの *外* ../addons/_nexus_addons_p/backup/<AID>/。
-- 中に置くとバックアップ自身をバックアップし続けることになる。
-- 取得日時は復元前に「いつの設定か」を見せるためのもので、これも AID フォルダの外
-- (backup/<AID>_info.json)に置く。バックアップフォルダの中に入れると、復元のときに
-- 一緒に live 側へコピーされてしまう。
--
-- ===== 復元は「上書き」であって「巻き戻し」ではない =====
-- xcopy はコピー元に無いファイルを消さないので、バックアップ後に増えたファイルは
-- 残る(settings.json のような主要な設定は上書きされる)。消す方向の同期にすると
-- 対象の取り違えでユーザーのファイルを消しかねないので、意図的に上書きだけにしている。
-- 復元後は g.* にキャッシュ済みの各アドオン設定までは戻らないため、再起動を案内する。

-- バックアップ関連のパス。g.active_id は ON_INIT で入るので、ロード時ではなく
-- 呼ばれた時点で組み立てる(90_addons_menu.lua の設定パスと同じ理由)。
function g.backup_paths()
    if not g.active_id then
        return nil
    end
    local base = string.format("../addons/%s", addon_name_lower)
    return {
        live = string.format("%s/%s", base, g.active_id),
        backup = string.format("%s/backup/%s", base, g.active_id),
        info = string.format("%s/backup/%s_info.json", base, g.active_id)
    }
end

-- src_dir を dst_dir へ丸ごとコピーする。戻り値は ok, kind。
-- 成否は「コピー先に settings.json があるか」で見る。os.execute の戻り値は
-- 環境依存で当てにならないため、xcopy の終了コードは見ない。
local function copy_settings_dir(src_dir, dst_dir)
    local src = io.open(src_dir .. "/settings.json", "r")
    if not src then
        return false, "no_source"
    end
    src:close()
    -- os.execute は cmd 経由なので区切りをバックスラッシュに直す(migrate_from_origin と同じ扱い)
    local src_win = string.gsub(src_dir, "/", "\\")
    local dst_win = string.gsub(dst_dir, "/", "\\")
    os.execute(string.format('xcopy "%s" "%s" /E /I /Y /Q >nul 2>&1', src_win, dst_win))
    local copied = io.open(dst_dir .. "/settings.json", "r")
    if copied then
        copied:close()
        return true, "copied"
    end
    -- xcopy が使えなかったとき用。最低限 settings.json(= 各アドオンの ON/OFF)だけは運ぶ。
    if g.copy_file(src_dir .. "/settings.json", dst_dir .. "/settings.json") then
        return true, "partial"
    end
    return false, "failed"
end

-- 現在の設定をバックアップへ退避する。戻り値は ok, kind("copied"/"partial"/失敗理由)。
function g.backup_settings()
    local paths = g.backup_paths()
    if not paths then
        return false, "no_id"
    end
    -- xcopy /I が作ってくれるが、フォールバック(g.copy_file)は自分ではフォルダを作れない。
    -- cmd の mkdir は途中のフォルダもまとめて作るので 1 回でよい。
    g.create_folder(paths.backup, paths.backup .. "/mkdir.txt")
    local ok, kind = copy_settings_dir(paths.live, paths.backup)
    if not ok then
        g.vlog("{#FF6347}backup: 失敗{/} %s -> %s (%s)", paths.live, paths.backup, tostring(kind))
        return false, kind
    end
    -- time は復元前に「いつの設定か」を見せるため。partial はそのとき
    -- 「settings.json だけの退避だった」と断れるようにするため。ver は使わないが、
    -- 不具合報告でこのファイルを見たときに、どの版で取ったかが分かるように残す。
    g.save_json(paths.info, {
        time = os.date("%Y-%m-%d %H:%M:%S"),
        ver = ver,
        partial = (kind == "partial") and 1 or 0
    })
    g.vlog("backup: %s -> %s (%s)", paths.live, paths.backup, tostring(kind))
    return true, kind
end

-- バックアップから設定を書き戻す。戻り値は ok, kind。
function g.restore_settings()
    local paths = g.backup_paths()
    if not paths then
        return false, "no_id"
    end
    local ok, kind = copy_settings_dir(paths.backup, paths.live)
    if not ok then
        g.vlog("{#FF6347}restore: 失敗{/} %s -> %s (%s)", paths.backup, paths.live, tostring(kind))
        return false, kind
    end
    g.vlog("restore: %s -> %s (%s)", paths.backup, paths.live, tostring(kind))
    return true, kind
end

-- バックアップの有無と取得日時。無ければ nil。
-- 日時は info が壊れている/古い版で作られた場合に nil になりうるので、
-- 「バックアップは在る」ことと「日時が分かる」ことは分けて返す。
function g.backup_info()
    local paths = g.backup_paths()
    if not paths then
        return nil
    end
    local file = io.open(paths.backup .. "/settings.json", "r")
    if not file then
        return nil
    end
    file:close()
    local info = g.load_json(paths.info)
    return {
        time = info and info.time or nil,
        partial = info and info.partial or 0
    }
end

-- 登録アドオンの use をまとめて value にする。変更した件数を返す。
-- 設定の保存も init もしないので、呼び出し側で行うこと(テストからも直接叩ける)。
function g.set_all_addons_use(value)
    if not g.settings then
        return 0
    end
    local changed = 0
    for _, entry in ipairs(g._nexus_addons_p) do
        local setting = g.settings[entry.key]
        if setting and setting.use ~= value then
            setting.use = value
            changed = changed + 1
        end
    end
    return changed
end

local function maintenance_notice(msg, ok)
    imcAddOn.BroadMsg(ok and "NOTICE_Dm_Bell" or "NOTICE_Dm_!", msg, 5.0)
end

-- ===== 全アドオン OFF =====
-- 押し間違いで全部消えると元の ON/OFF が分からなくなるので、確認を挟む。
function _nexus_addons_p_disable_all_addons()
    local msg
    if g.lang == "Japanese" then
        msg = "{ol}{#FFFFFF}[Nexus Addons P] すべてのアドオンを OFF にしますか？{nl}元の ON/OFF に戻したい場合は、先に「バックアップ」を押してください"
    else
        msg = "{ol}{#FFFFFF}[Nexus Addons P] Turn OFF every addon?{nl}Press \"Backup\" first if you want to restore the current ON/OFF later"
    end
    ui.MsgBox(msg, "_nexus_addons_p_disable_all_addons_exec()", "None")
end

function _nexus_addons_p_disable_all_addons_exec()
    local changed = g.set_all_addons_use(0)
    if changed == 0 then
        maintenance_notice(g.lang == "Japanese" and "[Nexus Addons P] すでにすべて OFF です" or
                               "[Nexus Addons P] Every addon is already OFF", false)
        return
    end
    _nexus_addons_p_save_settings()
    -- OFF 側の on_init はフレームの後始末に使われるので、OFF にしたあとも必ず呼ぶ
    -- (マップ移動のたびに走る GAME_START_3SEC と同じ呼び方)。
    -- g.loaded 前は init_addons が非同期ロードを開始する経路に入るため、そちらへは入れない。
    if g.loaded then
        _nexus_addons_p_init_addons(false, nil)
    end
    g.vlog("disable_all: %d 件を OFF にした", changed)
    maintenance_notice(g.lang == "Japanese" and
                           string.format("[Nexus Addons P] %d 個のアドオンを OFF にしました", changed) or
                           string.format("[Nexus Addons P] Turned OFF %d addon(s)", changed), true)
    _nexus_addons_p_frame_init()
end

-- ===== バックアップ =====
function _nexus_addons_p_backup_settings()
    local existing = g.backup_info()
    if not existing then
        _nexus_addons_p_backup_settings_exec()
        return
    end
    -- 保存先は 1 つだけ(復元先を選ばせるにはフォルダ列挙が要り、Lua 側では出来ない)。
    -- 上書きになるので、前回の日時を見せてから確認する。
    local when = existing.time or (g.lang == "Japanese" and "不明" or "unknown")
    local msg
    if g.lang == "Japanese" then
        msg = string.format(
            "{ol}{#FFFFFF}[Nexus Addons P] 既存のバックアップ(%s)を上書きしますか？", when)
    else
        msg = string.format("{ol}{#FFFFFF}[Nexus Addons P] Overwrite the existing backup (%s)?", when)
    end
    ui.MsgBox(msg, "_nexus_addons_p_backup_settings_exec()", "None")
end

function _nexus_addons_p_backup_settings_exec()
    local ok, kind = g.backup_settings()
    if not ok then
        maintenance_notice(g.lang == "Japanese" and "[Nexus Addons P] バックアップに失敗しました" or
                               "[Nexus Addons P] Backup failed", false)
        return
    end
    local msg
    if g.lang == "Japanese" then
        msg = kind == "partial" and
                  "[Nexus Addons P] settings.json だけバックアップしました(他のファイルはコピーできませんでした)" or
                  "[Nexus Addons P] 設定をバックアップしました"
    else
        msg = kind == "partial" and
                  "[Nexus Addons P] Backed up settings.json only (other files could not be copied)" or
                  "[Nexus Addons P] Settings backed up"
    end
    maintenance_notice(msg, true)
    _nexus_addons_p_frame_init() -- ツールチップの日時を取り直す
end

-- ===== 復元 =====
function _nexus_addons_p_restore_settings()
    local existing = g.backup_info()
    if not existing then
        maintenance_notice(g.lang == "Japanese" and "[Nexus Addons P] バックアップがありません" or
                               "[Nexus Addons P] No backup found", false)
        return
    end
    local when = existing.time or (g.lang == "Japanese" and "不明" or "unknown")
    local msg
    if g.lang == "Japanese" then
        msg = string.format(
            "{ol}{#FFFFFF}[Nexus Addons P] %s のバックアップから設定を復元しますか？{nl}現在の設定は上書きされます",
            when)
    else
        msg = string.format(
            "{ol}{#FFFFFF}[Nexus Addons P] Restore settings from the backup taken at %s?{nl}Your current settings will be overwritten",
            when)
    end
    ui.MsgBox(msg, "_nexus_addons_p_restore_settings_exec()", "None")
end

function _nexus_addons_p_restore_settings_exec()
    local ok = g.restore_settings()
    if not ok then
        maintenance_notice(g.lang == "Japanese" and "[Nexus Addons P] 復元に失敗しました" or
                               "[Nexus Addons P] Restore failed", false)
        return
    end
    -- 書き戻した settings.json を読み直して ON/OFF を反映する。
    _nexus_addons_p_load_settings()
    if g.loaded then
        _nexus_addons_p_init_addons(false, nil)
    end
    maintenance_notice(g.lang == "Japanese" and
                           "[Nexus Addons P] 設定を復元しました。すべて反映するにはゲームを再起動してください" or
                           "[Nexus Addons P] Settings restored. Restart the game to apply everything", true)
    _nexus_addons_p_frame_init()
end

-- ===== 一覧フレームのタイトル行に載せるボタン =====
local MAINTENANCE_BTN_Y = 5
local MAINTENANCE_BTN_H = 28
local MAINTENANCE_BTN_GAP = 6
local MAINTENANCE_CLOSE_W = 35 -- 右上の閉じるボタンの分だけ空ける

local function maintenance_button_defs()
    local ja = (g.lang == "Japanese")
    local info = g.backup_info()
    local backup_when
    if not info then
        backup_when = ja and "{nl}バックアップはまだありません" or "{nl}No backup yet"
    else
        backup_when = string.format(ja and "{nl}最終バックアップ: %s" or "{nl}Last backup: %s",
            info.time or (ja and "不明" or "unknown"))
        -- xcopy が使えず settings.json だけ退避できた場合。復元しても各アドオンの
        -- 細かい設定は戻らないので、押す前に分かるようにしておく。
        if info.partial == 1 then
            backup_when = backup_when .. (ja and "{nl}(settings.json のみ)" or "{nl}(settings.json only)")
        end
    end
    return {{
        name = "disable_all_btn",
        width = 110,
        text = ja and "{ol}全て OFF" or "{ol}All OFF",
        tooltip = ja and "{ol}すべてのアドオンを OFF にします" or "{ol}Turn OFF every addon",
        func = "_nexus_addons_p_disable_all_addons"
    }, {
        name = "backup_btn",
        width = 130,
        text = ja and "{ol}バックアップ" or "{ol}Backup",
        tooltip = (ja and "{ol}現在の設定をバックアップします" or "{ol}Back up the current settings") ..
            backup_when,
        func = "_nexus_addons_p_backup_settings"
    }, {
        name = "restore_btn",
        width = 90,
        text = ja and "{ol}復元" or "{ol}Restore",
        tooltip = (ja and "{ol}バックアップから設定を復元します" or "{ol}Restore settings from the backup") ..
            backup_when,
        func = "_nexus_addons_p_restore_settings"
    }}
end

-- ボタン列(と閉じるボタン)が占める幅。一覧の幅はアドオン名の長さで決まるので、
-- タイトルとボタンが重なっていないかを呼び出し側が判断できるように公開する。
function g.maintenance_buttons_width()
    local total = MAINTENANCE_CLOSE_W
    for _, btn in ipairs(maintenance_button_defs()) do
        total = total + btn.width + MAINTENANCE_BTN_GAP
    end
    return total
end

-- タイトル行へ右詰めで並べる。frame_width は _nexus_addons_p_frame_init が Resize に
-- 使った値をそのまま受け取る(この時点では GetWidth() でも同じだが、呼び出し側の計算と
-- 食い違わせないため)。
function g.create_maintenance_buttons(list_frame, frame_width)
    local x = frame_width - g.maintenance_buttons_width()
    for _, btn in ipairs(maintenance_button_defs()) do
        local ctrl = list_frame:CreateOrGetControl('button', btn.name, x, MAINTENANCE_BTN_Y, btn.width,
            MAINTENANCE_BTN_H)
        AUTO_CAST(ctrl)
        ctrl:SetText(btn.text)
        ctrl:SetTextTooltip(btn.tooltip)
        ctrl:SetEventScript(ui.LBUTTONUP, btn.func)
        x = x + btn.width + MAINTENANCE_BTN_GAP
    end
end
