-- 共通部品: 設定ファイル(JSON)の読み書き
--
-- **このファイルは Nexus Addons P と Icor Planner の両方の .ipf に入る。**
-- ゲーム内では .ipf 同士で関数を共有できないので、共有はビルド時に行う
-- (build_manifest.json の targets が、同じこのファイルを両方へ連結する)。
-- そのため**特定のアドオンの名前や設定を直接見ないこと**。使ってよいのは、
-- 取り込む側が先に用意する次のものだけ:
--   g                … そのアドオンの本体テーブル
--   addon_name_lower … そのアドオンの名前(小文字)
--   json             … require("json")

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
