-- 設定の一括操作（全アドオン OFF / バックアップ / 復元）
--
-- ボタンはアドオン一覧フレーム(_nexus_addons_p_frame_init)のタイトル行に出す。
-- 一覧は各アドオンの ON/OFF を並べている画面なので、まとめて OFF にする操作と
-- その設定ごと退避/復旧する操作を同じ場所に置いている。
--
-- ===== バックアップの対象と方法 =====
-- 対象は ../addons/_nexus_addons_p/<AID>/ 配下。コピーは io だけで 1 ファイルずつ行い、
-- xcopy(cmd)は使わない。os.execute は GUI プロセスから呼ぶと必ずコンソール窓を作るので、
-- 押すたびに画面が一瞬点滅してしまうため(io.popen も同じうえ GUI アプリでは不安定)。
--
-- 代わりに「何をコピーするか」を自前で知る必要がある。Lua 側にディレクトリ列挙が無く、
-- 列挙する唯一の手段が cmd だから、ここを避けるとファイル名は自分で持つしかない。
--   * 固定名 … 下の g.backup_files。追加漏れ = 黙って取り残されるので、
--     docs/tests/test_core.lua [17] が bundle 内のパス文字列と突き合わせて落とす。
--     新しい設定ファイルを増やしたら、そこの検査に従ってここへ足すこと。
--   * 可変名 … monster_kill_count/<map_id>.json だけ。こちらは monster_kill_count.json の
--     map_ids が記録のあるマップを持っているので、そこから組み立てる。
--
-- フォルダ作成(cmd の mkdir)だけは代わりが無いので残る。ただし g.create_folder が
-- マーカーで空振りを防ぐため、コンソール窓が出るのは *初回のバックアップ 1 回だけ*。
-- 2 回目以降のバックアップと、復元では出ない。
--
-- 保存先は AID フォルダの *外* ../addons/_nexus_addons_p/backup/<AID>/。
-- 中に置くとバックアップ自身をバックアップし続けることになる。
-- 取得日時は復元前に「いつの設定か」を見せるためのもので、これも AID フォルダの外
-- (backup/<AID>_info.json)に置く。バックアップフォルダの中に入れると、復元のときに
-- 一緒に live 側へコピーされてしまう。
--
-- ===== 復元は「上書き」であって「巻き戻し」ではない =====
-- コピー元に無いファイルは消さないので、バックアップ後に増えたファイルは残る
-- (settings.json のような主要な設定は上書きされる)。消す方向の同期にすると
-- 対象の取り違えでユーザーのファイルを消しかねないので、意図的に上書きだけにしている。
-- 復元後は g.* にキャッシュ済みの各アドオン設定までは戻らないため、再起動を案内する。
-- 唯一の例外が g.drop_superseded_lua(.lua/.json の対)。上書きだけだと復元そのものが
-- 効かなくなるので、そこだけ消す方向へ回している。理由は g.paired_lua_settings を参照。

-- AID フォルダ直下に置かれるファイル名。ここに無いものはバックアップされない。
-- mkdir.txt(g.create_folder のマーカー)と filelist_temp.txt(monster_kill_count が
-- 列挙に使う一時ファイル)は設定ではないので、意図的に載せていない。
g.backup_files = {"settings.json", "addons_menu.json", "aethergem_manager.json", "always_status.json",
                  "always_status.lua", "ancient_auto_set.json", "another_warehouse.json", "another_warehouse.lua",
                  "archeology_helper.json", "auto_pet_summon.json", "auto_repair.json", "battle_ritual.json",
                  "boss_direction.json", "cc_helper.json", "cc_helper.lua", "characters_item_serch.json",
                  "characters_item_serch_accountwarehouse.dat", "characters_item_serch_equips.dat",
                  "characters_item_serch_inventory.dat", "characters_item_serch_warehouse.dat",
                  "cupole_manager.json", "easy_buff.json", "equips.dat", "fragmentation_presets.json",
                  "goddess_icor_manager.lua",
                  "guild_event_warp.json", "indun_list_viewer.json", "indun_list_viewer.lua", "indun_panel.json",
                  "instant_cc.json", "inventory.dat", "lets_go_home.json", "market_favorite_rebuild.json",
                  "market_voucher.json", "market_voucher_log.txt", "mini_addons.json", "mini_addons_buffs.json",
                  "mini_addons_buffs.lua", "mini_addons_buffs_backup.json", "mini_addons_buffs_backup.lua",
                  "monster_card_changer.json", "monster_kill_count.json", "muteki.json",
                  "my_buffs_control.dat", "my_buffs_control.json", "other_character_skill_list.json",
                  "other_character_skill_list.lua", "pick_item_tracker.json", "quickslot_operate.json",
                  "relic_change.json", "revival_timer.json", "save_quest.json", "separate_buff_custom.json",
                  "settings_250609.json", "settings_2507.json", "settings_2510.json", "sub_map.json",
                  "sub_slotset.json", "vakarine_equip.json", "warehouse.dat"}

-- 「.lua を先に読み、無ければ旧 .json へ落ちる」形で読んでいる設定の対。
--
-- 復元は上書きしかしないので、*移行前*(= .json だけ)のバックアップを戻すと、live 側に
-- 残ったままの .lua が勝って、書き戻した .json が黙って無視される。利用者から見ると
-- 「復元しましたと出たのに設定が戻らない」になる。そこで復元の最後に、
-- 「バックアップに .lua が無く .json だけがある」対に限って live の .lua を消す。
--
-- ここだけは消す方向の同期になるが、対象は対になっている .lua 1 ファイルだけで、
-- しかも「同じ設定の新しい表現」なので、取り違えて別の設定を消すことはない。
-- 新しく .lua/.json の対を増やしたら、g.backup_files と併せてここにも足すこと
-- (docs/tests/test_core.lua [17] が両方に載っているかを見る)。
g.paired_lua_settings = {{
    json = "always_status.json",
    lua = "always_status.lua"
}, {
    json = "another_warehouse.json",
    lua = "another_warehouse.lua"
}, {
    json = "cc_helper.json",
    lua = "cc_helper.lua"
}, {
    json = "indun_list_viewer.json",
    lua = "indun_list_viewer.lua"
}, {
    json = "mini_addons_buffs.json",
    lua = "mini_addons_buffs.lua"
}, {
    json = "mini_addons_buffs_backup.json",
    lua = "mini_addons_buffs_backup.lua"
}, {
    json = "other_character_skill_list.json",
    lua = "other_character_skill_list.lua"
}}

-- 可変名のファイルを置いている唯一のサブフォルダ。コピー先に無ければ作る必要がある。
local BACKUP_SUBFOLDER = "monster_kill_count"

local function file_exists(path)
    local file = io.open(path, "rb")
    if not file then
        return false
    end
    file:close()
    return true
end

-- names に可変名のファイル(サブフォルダ付き)が含まれるときだけ、コピー先へその
-- サブフォルダを作る。普段はアドオン側が作っているが、monster_kill_count を一度も
-- 使っていない環境や、引き継ぎ直後の空フォルダには無い。
-- cmd の mkdir はここでしか呼ばないので、g.create_folder のマーカーが効いて
-- コンソール窓が出るのは最初の 1 回だけ。戻り値は作りに行ったかどうか。
function g.ensure_settings_subfolder(dst_dir, names)
    for _, name in ipairs(names) do
        if string.find(name, "/", 1, true) then
            g.create_folder(dst_dir .. "/" .. BACKUP_SUBFOLDER, dst_dir .. "/" .. BACKUP_SUBFOLDER .. "/mkdir.txt")
            return true
        end
    end
    return false
end

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

-- コピー対象のファイル名(src_dir からの相対)。固定名の一覧に、可変名の
-- monster_kill_count/<map_id>.json を足して返す。後者はフォルダを列挙できないので、
-- *コピー元* の monster_kill_count.json が持つ map_ids から組み立てる
-- (記録のあるマップの一覧で、アドオン側が記録の追加時に更新している)。
-- コピー元側を読むので、復元ではバックアップした時点の一覧が使われる。
-- (本家からの引き継ぎ g.migrate_from_origin も同じ一覧でコピーするので g. で公開する)
function g.settings_file_names(src_dir)
    local names = {}
    for _, name in ipairs(g.backup_files) do
        names[#names + 1] = name
    end
    local mkc = g.load_json(src_dir .. "/monster_kill_count.json")
    if mkc and type(mkc.map_ids) == "table" then
        for _, map_id in ipairs(mkc.map_ids) do
            names[#names + 1] = string.format("%s/%s.json", BACKUP_SUBFOLDER, tostring(map_id))
        end
    end
    return names
end

-- src_dir の設定ファイルを dst_dir へ 1 つずつコピーする。戻り値は copied, failed。
--
-- 数えるのは g.copy_file の戻り値であって「コピー先にファイルが在るか」ではない。
-- 在るかで見ると、コピー先に前回の分が残っているとき(復元先の live は起動時に必ず
-- 作られ、2 回目以降のバックアップ先には前回の分が残る)に、失敗しても古いファイルを
-- 掴んで成功に見える。xcopy を使っていた頃はここを取り違えていた(e250046ed)。
-- 1 ファイルずつ自前でコピーする今は、成否がそのまま戻り値で分かるので取り違えない。
--
-- コピー元に無いファイルは飛ばす。全アドオンを使っている利用者はまず居ないので、
-- 一覧のほとんどが存在しないのが普通の状態。
function g.copy_settings_files(src_dir, dst_dir, names)
    local copied, failed = 0, 0
    for _, name in ipairs(names) do
        local src_path = src_dir .. "/" .. name
        local src = io.open(src_path, "rb")
        if src then
            src:close()
            if g.copy_file(src_path, dst_dir .. "/" .. name) then
                copied = copied + 1
            else
                failed = failed + 1
                g.vlog("{#FF6347}copy 失敗{/} %s", name)
            end
        end
    end
    return copied, failed
end

-- 現在の設定をバックアップへ退避する。戻り値は ok, copied, failed。
function g.backup_settings()
    local paths = g.backup_paths()
    if not paths then
        return false, 0, 0
    end
    -- cmd の mkdir は途中のフォルダもまとめて作るので、深い方だけ作れば backup/<AID> も
    -- 出来る = 起動する cmd は 1 回。g.create_folder がマーカーで空振りを防ぐため、
    -- コンソール窓が一瞬出るのは初回のバックアップだけになる。
    g.create_folder(paths.backup .. "/" .. BACKUP_SUBFOLDER,
        paths.backup .. "/" .. BACKUP_SUBFOLDER .. "/mkdir.txt")
    local copied, failed = g.copy_settings_files(paths.live, paths.backup, g.settings_file_names(paths.live))
    if copied == 0 then
        g.vlog("{#FF6347}backup: 1 件もコピーできなかった{/} %s -> %s (失敗 %d 件)", paths.live,
            paths.backup, failed)
        return false, 0, failed
    end
    -- time は復元前に「いつの設定か」を見せるため。partial はそのとき「取りこぼしがある
    -- 退避だった」と断れるようにするため。ver と files は使わないが、不具合報告でこの
    -- ファイルを見たときに、どの版で何件退避したのかが分かるように残す。
    g.save_json(paths.info, {
        time = os.date("%Y-%m-%d %H:%M:%S"),
        ver = ver,
        partial = (failed > 0) and 1 or 0,
        files = copied
    })
    g.vlog("backup: %s -> %s (%d 件, 失敗 %d 件)", paths.live, paths.backup, copied, failed)
    return true, copied, failed
end

-- 移行前のバックアップ(= .json だけ)を戻したときに、live に残った .lua が勝って
-- 復元が無視されるのを防ぐ。消した件数を返す。理由は g.paired_lua_settings の宣言コメント。
--
-- 判定に使うのは *書き戻したあとの live 側の .json* が在るかどうか。バックアップ側で
-- 見ると、.json のコピーに失敗していた場合に .lua だけを消して設定を丸ごと失う。
function g.drop_superseded_lua(backup_dir, live_dir)
    local dropped = 0
    for _, pair in ipairs(g.paired_lua_settings) do
        if not file_exists(backup_dir .. "/" .. pair.lua) and file_exists(live_dir .. "/" .. pair.json) and
            file_exists(live_dir .. "/" .. pair.lua) then
            if os.remove(live_dir .. "/" .. pair.lua) then
                dropped = dropped + 1
                g.vlog("restore: 移行前の %s を活かすため %s を消した", pair.json, pair.lua)
            else
                g.vlog("{#FF6347}restore: %s を消せなかった(復元した %s が無視される){/}", pair.lua, pair.json)
            end
        end
    end
    return dropped
end

-- バックアップから設定を書き戻す。戻り値は ok, copied, failed。
function g.restore_settings()
    local paths = g.backup_paths()
    if not paths then
        return false, 0, 0
    end
    local names = g.settings_file_names(paths.backup)
    -- 戻すマップ記録があるときだけサブフォルダを作りに行く
    g.ensure_settings_subfolder(paths.live, names)
    local copied, failed = g.copy_settings_files(paths.backup, paths.live, names)
    if copied == 0 then
        g.vlog("{#FF6347}restore: 1 件もコピーできなかった{/} %s -> %s (失敗 %d 件)", paths.backup,
            paths.live, failed)
        return false, 0, failed
    end
    local dropped = g.drop_superseded_lua(paths.backup, paths.live)
    g.vlog("restore: %s -> %s (%d 件, 失敗 %d 件, 旧形式に戻した対 %d 件)", paths.backup, paths.live, copied,
        failed, dropped)
    return true, copied, failed
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
    local ok, copied, failed = g.backup_settings()
    if not ok then
        maintenance_notice(g.lang == "Japanese" and "[Nexus Addons P] バックアップに失敗しました" or
                               "[Nexus Addons P] Backup failed", false)
        return
    end
    local msg
    if g.lang == "Japanese" then
        msg = string.format("[Nexus Addons P] 設定を %d 件バックアップしました", copied)
        if failed > 0 then
            msg = msg .. string.format("({#FF6347}%d 件はコピーできませんでした{/})", failed)
        end
    else
        msg = string.format("[Nexus Addons P] Backed up %d file(s)", copied)
        if failed > 0 then
            msg = msg .. string.format(" ({#FF6347}%d could not be copied{/})", failed)
        end
    end
    maintenance_notice(msg, failed == 0)
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
    local ok, copied, failed = g.restore_settings()
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
    local msg
    if g.lang == "Japanese" then
        msg = string.format(
            "[Nexus Addons P] 設定を %d 件復元しました。すべて反映するにはゲームを再起動してください", copied)
        if failed > 0 then
            msg = msg .. string.format("({#FF6347}%d 件は書き戻せませんでした{/})", failed)
        end
    else
        msg = string.format("[Nexus Addons P] Restored %d file(s). Restart the game to apply everything", copied)
        if failed > 0 then
            msg = msg .. string.format(" ({#FF6347}%d could not be written back{/})", failed)
        end
    end
    maintenance_notice(msg, failed == 0)
    _nexus_addons_p_frame_init()
end

-- ===== 一覧フレームの下段に載せるボタン =====
--
-- 元はタイトル行の右側に並べていたが、**この 3 つがフレームの幅を決めてしまう**のをやめた。
-- 行の中身に要る幅は 500px 前後なのに、タイトル + ボタン 3 つで 700px 近くを要求するため、
-- 一覧の右側に 200px ほどの空白が残っていた(実機で確認)。下段へ移すと幅は行の中身で
-- 決まるようになり、ラベルを削らずに窓が狭くなる。
-- 併せて、押し間違いの怖い「全て OFF」が、頻繁に押す ON/OFF トグルから離れる。
local MAINTENANCE_BTN_H = 28
local MAINTENANCE_BTN_GAP = 6
local MAINTENANCE_RIGHT_PAD = 10 -- 右端に残す余白

local function maintenance_button_defs()
    local ja = (g.lang == "Japanese")
    local info = g.backup_info()
    local backup_when
    if not info then
        backup_when = ja and "{nl}バックアップはまだありません" or "{nl}No backup yet"
    else
        backup_when = string.format(ja and "{nl}最終バックアップ: %s" or "{nl}Last backup: %s",
            info.time or (ja and "不明" or "unknown"))
        -- 一部のファイルをコピーできないまま取った退避。復元しても戻らない設定が
        -- あるということなので、押す前に分かるようにしておく。
        if info.partial == 1 then
            backup_when = backup_when ..
                              (ja and "{nl}(一部のファイルは退避できていません)" or
                                  "{nl}(some files could not be backed up)")
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

-- ボタン列が右詰めで占める幅(右端の余白を含む)。一覧の幅がこれを下回るとボタンが
-- 左へはみ出すので、呼び出し側が最低幅の判断に使えるよう公開する。
-- 末尾の GAP は数えない(最後のボタンの右は MAINTENANCE_RIGHT_PAD が受け持つ)。
function g.maintenance_buttons_width()
    local total = MAINTENANCE_RIGHT_PAD
    for i, btn in ipairs(maintenance_button_defs()) do
        total = total + btn.width
        if i > 1 then
            total = total + MAINTENANCE_BTN_GAP
        end
    end
    return total
end

-- 下段へ右詰めで並べる。frame_width / y は _nexus_addons_p_list_build が Resize に
-- 使った値をそのまま受け取る(GetWidth() でも同じだが、呼び出し側の計算と食い違わせないため)。
function g.create_maintenance_buttons(list_frame, frame_width, y)
    local x = frame_width - g.maintenance_buttons_width()
    for _, btn in ipairs(maintenance_button_defs()) do
        local ctrl = list_frame:CreateOrGetControl('button', btn.name, x, y, btn.width, MAINTENANCE_BTN_H)
        AUTO_CAST(ctrl)
        ctrl:SetText(btn.text)
        ctrl:SetTextTooltip(btn.tooltip)
        ctrl:SetEventScript(ui.LBUTTONUP, btn.func)
        x = x + btn.width + MAINTENANCE_BTN_GAP
    end
end
