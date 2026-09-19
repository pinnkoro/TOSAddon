-- 共通部品: フォルダ作成とファイル複写
--
-- 詳しくは 10_json.lua の冒頭。
-- **os.execute はコンソール窓を出すので、フォルダ作成以外では使わないこと**
-- (Lua にフォルダを作る手段が他に無い。マーカーファイルで空振りを防いでいる)。

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
