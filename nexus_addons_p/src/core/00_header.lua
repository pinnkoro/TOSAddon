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
local ver = "1.0.1"

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

function g.mkdir_new_folder()
    local function create_folder(folder_path, file_path)
        local file = io.open(file_path, "r")
        if not file then
            os.execute('mkdir "' .. folder_path .. '"')
            file = io.open(file_path, "w")
            if file then
                file:write("A new file has been created")
                file:close()
            end
        else
            file:close()
        end
    end
    local folder = string.format("../addons/%s", addon_name_lower)
    local file_path = string.format("../addons/%s/mkdir.txt", addon_name_lower)
    create_folder(folder, file_path)
    local user_folder = string.format("../addons/%s/%s", addon_name_lower, g.active_id)
    local user_file_path = string.format("../addons/%s/%s/mkdir.txt", addon_name_lower, g.active_id)
    create_folder(user_folder, user_file_path)
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

local function copy_file(src_path, dst_path)
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
    if copy_file(src_settings, dst_settings) then
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
        return nil
    end
    g.map_type_cache_name = map_name
    g.map_type_cache = map_cls.MapType
    return g.map_type_cache
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

