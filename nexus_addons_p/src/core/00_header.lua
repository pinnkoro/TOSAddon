-- Nexus Addons P
-- norisan さんの Nexus Addons (v1.1.13 時点) を元にした派生版。
-- アドオン名 / 保存フォルダ / グローバル関数名をすべて `_nexus_addons_p` 系にリネームし、
-- 本家とは別系列として配布する。バージョンは本家と独立して 1.0.0 から採番する。
-- 本家の更新履歴は https://github.com/ajinorisan/TOSAddon-public を参照。
--
-- 1.0.0 本家 v1.1.13 からフォーク。本家と同時インストール時は自動で全機能を停止し、
--       本家の設定(../addons/_nexus_addons/<AID>/)を自分側へ引き継ぐ処理を追加。
local addon_name = "_NEXUS_ADDONS_P"
local addon_name_lower = string.lower(addon_name)
local author = "norisan"
local ver = "1.0.2"

_G["ADDONS"] = _G["ADDONS"] or {}
_G["ADDONS"][author] = _G["ADDONS"][author] or {}
_G["ADDONS"][author][addon_name] = _G["ADDONS"][author][addon_name] or {}
local g = _G["ADDONS"][author][addon_name]
local json = require("json")

local function ts(...)
    local num_args = select('#', ...)
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

local function print_all_child(ctrl, prefix)
    prefix = prefix or ""
    local count = ctrl:GetChildCount()
    for i = 0, count - 1 do
        local child = ctrl:GetChildByIndex(i)
        local name = child:GetName()
        local class_name = child:GetClassName()
        local w = child:GetWidth()
        local h = child:GetHeight()
        print(string.format("%sName: %s | Class: %s | Size: %dx%d", prefix, name, class_name, w, h))
        if child:GetChildCount() > 0 then
            print_all_child(child, prefix .. "  ")
        end
    end
end

-- フォルダを作る。作成済みを示すマーカーファイルが読めるときは何もしない。
-- os.execute は cmd.exe を同期起動する(コンソール窓が一瞬出ることもある)ので、
-- 起動のたびに空振りさせないためのガード。フォルダを作る箇所はすべてここを通すこと。
--
-- folder_path はそのまま cmd へ渡す。区切り文字の扱いは呼び出し側の既存挙動を
-- 変えないよう、こちらでは正規化しない(monster_kill_count はバックスラッシュ、
-- mkdir_new_folder はスラッシュのまま渡してきた)。
function g.create_folder(folder_path, marker_path)
    local file = io.open(marker_path, "r")
    if file then
        file:close()
        return
    end
    os.execute('mkdir "' .. folder_path .. '"')
    file = io.open(marker_path, "w")
    if file then
        file:write("A new file has been created")
        file:close()
    end
end

function g.mkdir_new_folder()
    g.create_folder(string.format("../addons/%s", addon_name_lower),
        string.format("../addons/%s/mkdir.txt", addon_name_lower))
    g.create_folder(string.format("../addons/%s/%s", addon_name_lower, g.active_id),
        string.format("../addons/%s/%s/mkdir.txt", addon_name_lower, g.active_id))
end

-- ===== 本家 Nexus Addons(_nexus_addons)との関係 =====
-- 本アドオンは本家をリネームした派生版なので、両方が同時にインストールされていると
-- 同じフレームが二重に出たり、同じバニラ関数を両方がフックして壊れる。そこで起動時に
--   A: 本家を検出したら自分の機能を一切初期化せず、削除を促すメッセージだけ出す
--   B: 自分側の設定がまだ無く本家の設定が残っていれば、それを丸ごと引き継ぐ
-- の 2 つを行う(呼び出しは core/20_lifecycle.lua の ON_INIT / GAME_START)。
local origin_name = "_NEXUS_ADDONS"
local origin_name_lower = string.lower(origin_name)

-- A: 本家 bundle が読み込まれているか。
-- ON_INIT の呼び出し順は保証されないため、ON_INIT で初めて存在する _ON_INIT 関数だけでなく、
-- bundle のファイル読み込み時点で作られる _G.ADDONS[author][origin_name] も判定材料にする。
function g.detect_origin_addon()
    if type(_G[origin_name .. "_ON_INIT"]) == "function" then
        return true
    end
    local addons = _G["ADDONS"]
    if type(addons) == "table" and type(addons[author]) == "table" and type(addons[author][origin_name]) == "table" then
        return true
    end
    return false
end

-- 1 ファイルをバイナリコピーする。xcopy が使えなかったときの最後の手段として、
-- 本家からの引き継ぎ(下)と設定のバックアップ/復元(core/30_maintenance.lua)から使う。
function g.copy_file(src_path, dst_path)
    local src_file = io.open(src_path, "rb")
    if not src_file then
        return false
    end
    local data = src_file:read("*all")
    src_file:close()
    if not data then
        return false
    end
    local dst_file = io.open(dst_path, "wb")
    if not dst_file then
        return false
    end
    local ok = dst_file:write(data)
    dst_file:close()
    return ok and true or false
end

-- B: 本家(_nexus_addons)の設定を引き継ぐ。戻り値は "copied" / "partial" / "failed" / nil(何もしない)。
-- 引き継ぎ単位は AID フォルダ丸ごと。各アドオンの .json/.lua/.dat のほかに
-- monster_kill_count/<map_id>.json のような可変名のファイルがあり、Lua 側に
-- ディレクトリ列挙が無いのでファイル名を列挙できない。よってコピー自体は xcopy に任せ、
-- それが失敗したときだけ settings.json を自前でコピーするフォールバックを持つ。
-- 実行条件は「自分側に settings.json が無い」= 実質初回起動時のみ。既に自分の設定が
-- あるときに走らせると本家の古い設定で上書きしてしまうため、この条件は必ず守ること。
function g.migrate_from_origin()
    local dst_dir = string.format("../addons/%s/%s", addon_name_lower, g.active_id)
    local dst_settings = dst_dir .. "/settings.json"
    local dst_file = io.open(dst_settings, "r")
    if dst_file then
        dst_file:close()
        return nil
    end
    local src_dir = string.format("../addons/%s/%s", origin_name_lower, g.active_id)
    local src_settings = src_dir .. "/settings.json"
    local src_file = io.open(src_settings, "r")
    if not src_file then
        return nil
    end
    src_file:close()
    -- os.execute は cmd 経由なので区切りをバックスラッシュに直す(monster_kill_count と同じ扱い)
    local src_win = string.gsub(src_dir, "/", "\\")
    local dst_win = string.gsub(dst_dir, "/", "\\")
    os.execute(string.format('xcopy "%s" "%s" /E /I /Y /Q >nul 2>&1', src_win, dst_win))
    local copied = io.open(dst_settings, "r")
    if copied then
        copied:close()
        return "copied"
    end
    if g.copy_file(src_settings, dst_settings) then
        return "partial"
    end
    return "failed"
end

function g.setup_hook_and_event(my_addon, origin_func_name, my_func_name, bool)
    g.FUNCS = g.FUNCS or {}
    if not g.FUNCS[origin_func_name] then
        g.FUNCS[origin_func_name] = _G[origin_func_name]
    end
    local origin_func = g.FUNCS[origin_func_name]
    local function hooked_function(...)
        local original_results
        if bool == true then
            original_results = {origin_func(...)}
        end
        g.ARGS = g.ARGS or {}
        g.ARGS[origin_func_name] = {...}
        imcAddOn.BroadMsg(origin_func_name)
        if original_results then
            return table.unpack(original_results)
        else
            return
        end
    end
    _G[origin_func_name] = hooked_function
    if not g.REGISTER[origin_func_name .. my_func_name] then -- g.REGISTERはON_INIT内で都度初期化
        g.REGISTER[origin_func_name .. my_func_name] = true
        my_addon:RegisterMsg(origin_func_name, my_func_name)
    end
end

function g.get_event_args(origin_func_name)
    local args = g.ARGS[origin_func_name]
    if args then
        return table.unpack(args)
    end
    return nil
end

function g.setup_hook(my_func, origin_func_name)
    local addon_upper = string.upper(addon_name)
    local replace_name = addon_upper .. "_REPLACE_" .. origin_func_name
    g.FUNCS = g.FUNCS or {}
    if not _G[replace_name] then
        _G[replace_name] = _G[origin_func_name]
    end
    _G[origin_func_name] = my_func
    g.FUNCS[origin_func_name] = _G[replace_name]
end

-- tmp を path へ差し替える(remove→rename)。成功可否を返す。
-- 厳密なアトミック差し替えではない: remove と rename の間でクラッシュすると path は
-- 消えるが、tmp に完全な内容が残るため次回 load の .tmp リカバリで復旧できる。この
-- tmp リカバリと対で実効的な原子性(=設定を失わない)を担保する。
-- Windows の os.rename は移動先が存在すると失敗するため先に remove する。
-- rename 失敗時は path が remove 済みのまま false を返す(呼び出し側が検知して報告)。
function g.atomic_replace(tmp_path, path)
    os.remove(path)
    local ok, err = os.rename(tmp_path, path)
    if not ok then
        return false, err
    end
    return true
end

function g.save_lua(path, tbl)
    local function serialize(o)
        if type(o) == "number" then
            return tostring(o)
        elseif type(o) == "string" then
            return string.format("%q", o)
        elseif type(o) == "boolean" then
            return tostring(o)
        elseif type(o) == "table" then
            local parts = {"{\n"}
            for k, v in pairs(o) do
                parts[#parts + 1] = "[" .. serialize(k) .. "]=" .. serialize(v) .. ",\n"
            end
            parts[#parts + 1] = "}"
            return table.concat(parts)
        else
            return "nil"
        end
    end
    local ok_s, content = pcall(function() return "return " .. serialize(tbl) end)
    if not ok_s or not content then
        if ts then ts("Save Lua Serialize Error:", tostring(content)) end
        return
    end
    local tmp_path = path .. ".tmp"
    local file, err = io.open(tmp_path, "w")
    if file then
        local ok_w, w_err = file:write(content)
        file:close()
        if ok_w then
            local ok_r, r_err = g.atomic_replace(tmp_path, path)
            if not ok_r and ts then ts("Save Lua Rename Error:", tostring(r_err)) end
        else
            if ts then ts("Save Lua Write Error:", tostring(w_err)) end
        end
    else
        if ts then ts("Save Lua Error:", err) end
    end
end

function g.load_lua(path)
    local chunk, err = loadfile(path)
    if chunk then
        local status, result = pcall(chunk)
        if status then
            return result
        end
    end
    local tmp_path = path .. ".tmp"
    local tmp_chunk = loadfile(tmp_path)
    if tmp_chunk then
        local status, result = pcall(tmp_chunk)
        if status then
            g.atomic_replace(tmp_path, path)
            return result
        end
    end
    return nil
end

-- path の .tmp をデコード成功時のみ path へ昇格し、(true, 値) を返す。
-- 壊れた/空/不在の .tmp は昇格させず(リカバリ元を失わないため) false を返す。
-- 本体ファイルが開けない/空の 2 経路で共通のリカバリ手順。
local function load_json_recover_from_tmp(path)
    local tmp_file = io.open(path .. ".tmp", "r")
    if not tmp_file then
        return false
    end
    local tmp_content = tmp_file:read("*all")
    tmp_file:close()
    if not tmp_content or tmp_content == "" then
        return false
    end
    local s, r = pcall(json.decode, tmp_content)
    if not s then
        return false
    end
    g.atomic_replace(path .. ".tmp", path)
    return true, r
end

function g.load_json(path)
    local file = io.open(path, "r")
    if not file then
        local ok, recovered = load_json_recover_from_tmp(path)
        if ok then
            return recovered, nil
        end
        return nil, "Error opening file: " .. path
    end
    local content = file:read("*all")
    file:close()
    if not content or content == "" then
        local ok, recovered = load_json_recover_from_tmp(path)
        if ok then
            return recovered, nil
        end
        return nil, "File content is empty or could not be read: " .. path
    end
    if string.sub(content, 1, 3) == "\239\187\191" then
        content = string.sub(content, 4)
    end
    local success, result = pcall(json.decode, content)
    if success then
        return result, nil
    else
        return nil, result
    end
end

function g.save_json(path, tbl)
    -- 先にエンコードしてから書き込む。エンコード失敗時に本体ファイルを
    -- 空に潰さないよう、まず tmp に書いてから rename でアトミックに差し替える。
    -- (load_json の .tmp リカバリと対になる)
    local success, str = pcall(json.encode, tbl)
    if not success then
        print(string.format("[g.save_json] JSON Encode Error in '%s': %s", tostring(path), tostring(str)))
        return false
    end
    local tmp_path = path .. ".tmp"
    local file, err = io.open(tmp_path, "w")
    if not file then
        print(string.format("[g.save_json] Error opening file for write: %s (Error: %s)", tostring(tmp_path), tostring(err)))
        return false
    end
    local ok_w, w_err = file:write(str)
    file:close()
    if not ok_w then
        print(string.format("[g.save_json] Write Error in '%s': %s", tostring(tmp_path), tostring(w_err)))
        return false
    end
    local ok_r, r_err = g.atomic_replace(tmp_path, path)
    if not ok_r then
        print(string.format("[g.save_json] Rename Error in '%s': %s", tostring(path), tostring(r_err)))
        return false
    end
    return true
end

-- 詳細ログ。アドオンメニューボタン右クリックの設定画面にある
-- 「詳細なログをシステムに出力する」が ON のときだけ、チャットのシステムメッセージへ出す。
-- 既定は OFF なので、通常の利用者のチャットは今までどおり静かなまま。
--
-- 保存先は g.settings(= ../addons/_nexus_addons_p/<AID>/settings.json)。
-- UI を出している 90_addons_menu.lua 側の addons_menu.json はメニューの位置と
-- 表示設定だけを持つので、アドオン全体の設定であるこれは置かない(詳細は 90 側のコメント)。
--
-- 初期化前(g.settings がまだ nil)や、本家検出で初期化を止めた場合も黙って何もしない。
-- 書式化の失敗でデバッグ用のログが本体を巻き込んで落とすことがないよう pcall で包む。
--
-- チャットは流れてしまい後から読み返せないので、同じ内容をファイルにも残す。
-- 不具合報告用に「そのまま送れる」ことを狙っており、
--   * 出力先は debug_log.txt とは別。あちらはエラーの履歴を追記し続ける用途で、
--     詳細ログを混ぜると際限なく育ち、必要な部分も探しにくくなる。
--   * 作り直すのはクライアント起動後の最初の 1 行だけ(下の vlog_write)。
--   * 色やタグ({ol} 等)は読みづらいだけなので、ファイル側では外す。
local vlog_file_path = string.format('../addons/%s/verbose_log.txt', addon_name_lower)
-- 行数の上限。マップ移動のたびに全アドオンの init 行(50 行前後)が出るため、
-- 1 回のプレイでも積み上がる。到達したら取り直して際限なく育たないようにする。
local vlog_max_lines = 20000

local function vlog_write(line)
    local mode, notice = "a", nil
    if not g.vlog_started then
        -- 作り直すのはここだけ。GAME_START はマップ移動のたびに来るので、
        -- そこで毎回作り直すと直前のマップのログ(初期化エラーを含む)が消える。
        -- g はクライアント起動中ずっと生きるので、1 回のプレイで 1 ファイルになる。
        mode = "w"
    elseif g.vlog_lines >= vlog_max_lines then
        mode = "w"
        notice = "===== 行数が上限に達したのでここから取り直し ====="
    end
    local file = io.open(vlog_file_path, mode)
    if not file then
        -- 開けなかったときは状態を進めない。ここで vlog_started を立ててしまうと、
        -- 作り直しに失敗したまま次回から追記モードになり、前回起動分のログに
        -- 書き足す形になる(「中身は常に今回の起動分だけ」が崩れ、報告用に使えない)。
        -- 上限到達時も同じで、取り直せていないのに行数だけ 0 に戻すと以後伸び続ける。
        return
    end
    g.vlog_started = true
    if mode == "w" then
        g.vlog_lines = 0
    end
    local stamp = os.date("[%H:%M:%S] ")
    if notice then
        file:write(stamp .. notice .. "\n")
        g.vlog_lines = g.vlog_lines + 1
    end
    file:write(stamp .. line .. "\n")
    file:close()
    g.vlog_lines = g.vlog_lines + 1
end

function g.vlog(fmt, ...)
    if not g.settings or g.settings.verbose_log ~= 1 then
        return
    end
    local ok, msg = pcall(string.format, fmt, ...)
    if not ok then
        msg = tostring(fmt)
    end
    ui.SysMsg("{ol}{#00BFFF}[NAP]{/} " .. msg)
    local plain = msg:gsub("{[^}]*}", "")
    vlog_write(plain)
end

-- 呼び出し箇所が 50 を超えており、FPS_UPDATE 経由で毎フレーム走る経路もある。
-- GetClass は IES 引きで重い一方、MapType は同じマップなら不変なので、
-- マップ名をキーにメモ化する。マップが変われば引き直すので意味は変わらない。
--
-- キャッシュするのは引けたときだけ。nil を覚えると、ロード中などに一度でも nil を
-- 掴んだ時点でそのマップに居る間ずっと nil が返り続け(無効化する契機が無い)、
-- guild_event_warp の移動可否チェックが素通りする等、呼び出し側の判定が全部壊れる。
-- 引けなかったマップは毎回引き直す = メモ化前と同じ挙動なので、退行にはならない。
function g.get_map_type()
    local map_name = session.GetMapName()
    if g.map_type_cache_name == map_name then
        return g.map_type_cache
    end
    local map_cls = GetClass("Map", map_name)
    -- 未知/インスタンスマップでは GetClass が nil を返しうるので nil ガード。
    -- 呼び出し側はいずれも文字列比較(== "Dungeon" 等)なので nil で問題ない。
    if not map_cls then
        -- 失敗はキャッシュしない = 毎フレームここへ来るので、ログはマップごとに 1 回だけ。
        -- (絞らないと FPS_UPDATE 経由でシステムメッセージが毎フレーム流れる)
        if g.map_type_failed_name ~= map_name then
            g.map_type_failed_name = map_name
            g.vlog("MapType 取得失敗: %s (キャッシュせず次回引き直す)", tostring(map_name))
        end
        return nil
    end
    local map_type = map_cls.MapType
    if map_type == nil or map_type == "" then
        -- クラスは引けたが MapType が空。これも「引けなかった」と同じ扱いにする。
        -- ここでキャッシュすると無効化する契機が無く、そのマップに居る間ずっと
        -- nil が返り続けてしまう(上のコメントと同じ理由)。
        if g.map_type_failed_name ~= map_name then
            g.map_type_failed_name = map_name
            g.vlog("MapType が空: %s (キャッシュせず次回引き直す)", tostring(map_name))
        end
        return nil
    end
    g.map_type_failed_name = nil
    g.map_type_cache_name = map_name
    g.map_type_cache = map_type
    -- ここを通るのは「マップが変わった」ときだけなので、移動のたびに 1 行出る。
    g.vlog("MapType: %s = %s", tostring(map_name), tostring(map_type))
    return map_type
end

-- ESC で消えない常時表示フレームを作る。常時出しておきたいフレームは必ずこれを使うこと。
--
-- ゲーム側の chat_memberlist.xml は <option hideable="true"> で、ESC はこの hideable な
-- フレームを閉じる。notice_on_pc は hideable="false" なので消えない。
-- ESC による非表示は IsVisible() に反映されないため、_nexus_addons_p_update_frames の
-- 毎フレーム復帰では検出も復旧もできない。土台の選択で防ぐしかない。
function g.create_persistent_frame(frame_name)
    return ui.CreateNewFrame("notice_on_pc", frame_name, 0, 0, 0, 0)
end

-- ESC で閉じる自作フレームの重なり(開いた順)スタック。
--
-- 土台が notice_on_pc のフレームはゲーム側の ESC では消えない(上のコメント参照)ので、
-- ESC で閉じているのは各アドオンが購読した ESCAPE_PRESSED のハンドラ。これはゲームから
-- 登録済みハンドラ全部へ一斉に配られるため、各自が素直に自分のフレームを閉じると
-- 「開いている自作ウィンドウが 1 回の ESC で全部消える」。
-- そこで開いたフレームをここへ積んでおき、閉じるのは一番手前(= 最後に開いた)1 枚だけにする。
--
-- 判定と close 呼び出しは core/20_lifecycle.lua の _nexus_addons_p_ESCAPE_PRESSED に集約する。
-- アドオンごとに ESCAPE_PRESSED を購読したままだと、先に閉じた側でスタックの中身が変わり、
-- 後から呼ばれたハンドラが「今度は自分が一番手前」と判断して結局まとめて消えてしまう。
g.esc_stack = g.esc_stack or {}

-- ESC で閉じたいフレームを開いたときに呼ぶ。
--   frame_name: ui.GetFrame に渡すフレーム名
--   close_func: 閉じるグローバル関数の名前(引数無しで呼べること)
-- 開き直しは積み直し = 最前面扱いにする。
-- **フレームを作って ShowWindow(1) した後で呼ぶこと**。まだ出ていない状態で呼ぶと、
-- 直後の同期で「閉じ終わった登録」と見なされてその場で捨てられる。
function g.esc_register(frame_name, close_func)
    for i = #g.esc_stack, 1, -1 do
        if g.esc_stack[i].frame == frame_name then
            table.remove(g.esc_stack, i)
        end
    end
    table.insert(g.esc_stack, {
        frame = frame_name,
        close = close_func
    })
    g.esc_sync_scp()
end

-- 生きている(存在して表示中の)中で一番手前の登録を、外さずに返す。
-- × ボタンで閉じた分は登録解除されないまま残るので、ここで一緒に捨てる。
-- 戻り値の 2 つ目はスタック上の位置(esc_pop_top が外すのに使う)。
function g.esc_top()
    for i = #g.esc_stack, 1, -1 do
        local entry = g.esc_stack[i]
        local frame = ui.GetFrame(entry.frame)
        if frame ~= nil and frame:IsVisible() == 1 then
            return entry, i
        end
        table.remove(g.esc_stack, i)
    end
    return nil
end

-- 一番手前の登録を 1 つ取り出す(閉じた後に開き直せば esc_register で積み直される)。
function g.esc_pop_top()
    local entry, index = g.esc_top()
    if entry then
        table.remove(g.esc_stack, index)
    end
    return entry
end

-- 1 回の押下を 2 度処理しないための間隔(ms)。ESC の届く経路は 2 つあり(g.esc_sync_scp 参照)、
-- その 2 経路の配信間隔は 1 フレーム未満なので、ここはそれを吸収できる最小限で十分。
-- 長くすると 2 つ実害が出る:
--   (1) 意図した ESC 連打(手前を閉じてすぐ下を閉じる)を握り潰す = esc_is_reentry
--   (2) 最後の 1 枚を閉じた後、この時間だけ esc_taken() が true を返し続け、
--       indun_panel の ESC トグルを無効化する = esc_taken
-- 60fps の 1 フレーム≒16ms に対しフレーム落ちの余裕を見て 50ms とする
-- (旧値 200ms は上記 2 つをはっきり踏むほど長すぎた)。
local ESC_DEDUP_MS = 50

-- 「今回の ESC はスタック側(= 手前の自作ウィンドウ)が使ったか」の問い合わせ。
--
-- ESCAPE_PRESSED はスタックに積めないものからも購読されている(indun_panel は常時表示の
-- パネルで、積むと ESC を常に横取りしてシステムメニューが開けなくなる)。そちら側が
-- 「手前にウィンドウがあるときは何もしない」を判断するのに使う。
-- ハンドラの呼ばれる順番はゲーム任せなので、次のどちらかなら true にする:
--   * まだ手前に生きているウィンドウがある      … 自分より後にそれが閉じられる
--   * この押下で 1 枚閉じた直後                  … 自分より先に閉じられていた
function g.esc_taken()
    if g.esc_top() then
        return true
    end
    return g.esc_closed_ms ~= nil and imcTime.GetAppTimeMS() - g.esc_closed_ms < ESC_DEDUP_MS
end

-- 同じ押下での再入(2 経路)を捨てるための判定。閉じた側は g.esc_closed_ms を更新する。
function g.esc_is_reentry()
    return g.esc_last_ms ~= nil and imcTime.GetAppTimeMS() - g.esc_last_ms < ESC_DEDUP_MS
end

-- 自作ウィンドウが開いている間だけ、ESC をこちらへ回してもらう。
--
-- ui.SetEscapeScp はゲーム側の「この ESC はこれを実行する」を差し替える口で、素の ESC
-- (チャットなど hideable なフレームを閉じる / システムメニューを開く)の代わりに走る。
-- これを設定しないと、自作ウィンドウを閉じるついでにチャットが消えたりシステムメニューが
-- 開いたりする。クライアントの uiscp/enchantchip.lua・uiscp/moru.lua・
-- fixframe/deletewarningbox/deletewarningbox.lua が「開いている間だけ設定し、
-- 閉じたら "" に戻す」使い方をしているので、それに倣う。
--
-- 現在値を読む API はクライアントに無い(SetEscapeScp だけ)ので、自分が設定したかどうかを
-- 覚えて、状態が変わったときだけ呼ぶ。毎フレーム呼ぶとゲーム側が設定した分を潰してしまう。
-- 閉じ忘れると ESC でシステムメニューが二度と開かなくなるため、× で閉じた場合も拾えるよう
-- _nexus_addons_p_update_frames(FPS_UPDATE)からも呼んで実際の表示状態に合わせ続ける。
function g.esc_sync_scp()
    local want = g.esc_top() ~= nil
    if want == (g.esc_scp_set or false) then
        return
    end
    g.esc_scp_set = want
    g.vlog("esc_scp: %s (stack=%d)", want and "set" or "clear", #g.esc_stack)
    -- 古いクライアントに SetEscapeScp が無くても、ここで巻き込んで落とさない
    -- (その場合は ESCAPE_PRESSED の一斉配信だけで従来どおり動く)。
    pcall(ui.SetEscapeScp, want and "_nexus_addons_p_ESCAPE_PRESSED()" or "")
end

function g.debug_print_table(tbl, indent)
    indent = indent or ""
    for key, value in pairs(tbl) do
        local key_str = indent .. "[" .. tostring(key) .. "] ="
        if type(value) == "table" then
            print(key_str .. "{")
            g.debug_print_table(value, indent .. "  ")
            print(indent .. "}")
        else
            print(key_str .. tostring(value))
        end
    end
end

function g.log_to_file(message)
    local log_file_path = string.format('../addons/%s/debug_log.txt', addon_name_lower)
    local file, err = io.open(log_file_path, "a")
    if file then
        local timestamp = os.date("[%Y-%m-%d %H:%M:%S] ")
        file:write(timestamp .. tostring(message) .. "\n")
        file:close()
    end
end

