-- 経過時間の物差し。imcTime が無い環境でも落ちないよう pcall で包み、取れなければ
-- 0 を返す(その場合は計測値が全部 0 になるだけで、本体の処理には影響しない)。
local function now_ms()
    local ok, ms = pcall(function()
        return imcTime.GetAppTimeMS()
    end)
    if ok and type(ms) == "number" then
        return ms
    end
    return 0
end

-- テーブルのキー数。**計測ログの判断材料にしか使わない。** 所要時間だけ出しても
-- 「そのファイルがどれだけ大きかったか」が分からず、他の環境のログと比べられない。
local function count_keys(tbl)
    if type(tbl) ~= "table" then
        return -1
    end
    local n = 0
    for _ in pairs(tbl) do
        n = n + 1
    end
    return n
end

-- 初回ログインで mini_addons の on_init だけが 5813ms 掛かる(他 49 本は最大 63ms)
-- 事象の切り分け用。**読み込みと書き戻しを分けて出すこと。** 合計だけだと
-- 「json.decode が重いのか、書き戻し(encode + tmp 書き + rename)が重いのか」が
-- 区別できず、直す先を選べない。
-- 走るのはセッション中 1 回だけ(呼び元が if not g.settings で囲っている)なので、
-- 毎フレーム流れる心配はない(CLAUDE.md「出しすぎない」)。
function Mini_addons_load_settings()
    local t0 = now_ms()
    local settings = g.load_json(g.settings_path)
    local t_load = now_ms()
    if not settings then
        settings = DEFAULT_SETTINGS
    else
        for key, value in pairs(DEFAULT_SETTINGS) do
            if settings[key] == nil then
                settings[key] = value
            end
        end
    end
    g.settings = settings
    local t_merge = now_ms()
    Mini_addons_save_settings()
    local t_save = now_ms()
    core_g.vlog("mini_addons: 計測 load_settings 読込=%dms 既定補完=%dms 書戻=%dms キー=%d", t_load - t0,
        t_merge - t_load, t_save - t_merge, count_keys(g.settings))
end

function Mini_addons_save_settings()
    g.save_json(g.settings_path, g.settings)
end

-- バフ一覧の保存。**必ずここを通すこと**(g.save_json を直接呼ばない)。
-- 保存先が .lua なのは g.update_paths のコメントを参照。書き込み側が 1 箇所でも
-- json のまま残ると、次の読み込みが .lua を見つけられずに旧 json へ落ちて、
-- せっかく直した 5 秒がそのまま戻る。
function Mini_addons_save_buffs()
    g.save_lua(g.buffs_path, g.buffs)
end

-- 計測はそのまま残す。**これが無いと同じ不具合を二度追うことになる**
-- (5 秒フリーズの切り分けで、この行が無いせいで「ON_INIT のどこか」までしか
--  絞れなかった)。走るのはセッション中 1 回だけ。
function Mini_addons_load_buffs()
    local t0 = now_ms()
    local buffs = g.load_lua(g.buffs_path)
    local lua_ok = buffs ~= nil
    local migrated = false
    if not buffs then
        -- 旧 json からの移行。**変換は 1 回だけで、この回だけは従来どおり遅い**
        -- (2806 キーで約 5 秒)。避けるには生の JSON を自前で舐めることになり、
        -- 割に合わないので受け入れる。次回以降は .lua だけを読む。
        -- 本家個別版から引き継いだ人も、初回はここを通る。
        buffs = g.load_json(g.buffs_json_path)
        migrated = buffs ~= nil
    end
    local t_load = now_ms()
    if not buffs then
        buffs = {}
    end
    g.buffs = buffs
    -- 書き戻すのは .lua がまだ無いときだけ(移行の回と、まっさらな初回)。
    -- .lua を読めたときは読んだ内容と同じものを書くだけなので省く。
    if not lua_ok then
        Mini_addons_save_buffs()
    end
    local t_save = now_ms()
    -- 変換できたら旧 json は消す。**残すと恒久的な「古い代替」になる**。
    -- .lua の読み込みが一度でも失敗した回に変換当日の内容へ巻き戻り、それをそのまま
    -- .lua へ書き戻すので、以降のバフ設定の変更が黙って消える。
    -- 消す前に .lua が本当に出来ているかを確かめること(書けていない状態で消すと全部失う)。
    if migrated then
        local written = io.open(g.buffs_path, "rb")
        if written then
            written:close()
            local removed = os.remove(g.buffs_json_path)
            core_g.vlog("mini_addons: バフ一覧を .lua へ変換したので旧 json を%s (%s)",
                removed and "削除した" or "{#FF6347}削除できなかった{/}", tostring(g.buffs_json_path))
        else
            core_g.vlog("{#FF6347}mini_addons: バフ一覧の .lua を書き出せていないので旧 json は残す{/} (%s)",
                tostring(g.buffs_path))
        end
    end
    core_g.vlog("mini_addons: 計測 load_buffs 読込=%dms 書戻=%dms キー=%d 旧json移行=%s", t_load - t0,
        t_save - t_load, count_keys(g.buffs), tostring(migrated))
end

