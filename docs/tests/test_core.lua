-- core の純ロジックを luajit 上で検査する（ゲーム不要）。
--
-- 対象は「ゲーム API をスタブに差し替えれば単体で動かせる」部分に限る。
-- ここでは g.get_map_type() のメモ化、FPS_UPDATE から毎フレーム呼ばれる
-- _nexus_addons_p_update_frames() の表示判定、詳細ログ(g.vlog)の出力条件を見る。
-- どれも実機でしか確認できないと壊しても気付けないため、最低限の回帰テストとして置いている。
--
-- 使い方（リポジトリルートから）:
--     luajit docs/tests/test_core.lua
--
-- core/*.lua は単体では完結せず、bundle と同じく 1 チャンクに連結して初めて
-- チャンクローカル(g / addon_name_lower)が共有される。そのため下でも連結して読む。

local CORE_PARTS = {
    "nexus_addons_p/src/core/00_header.lua",
    "nexus_addons_p/src/core/10_registry.lua", -- 設定のプルーニング検査に登録リストが要る
    "nexus_addons_p/src/core/20_lifecycle.lua",
}

-- ===== ゲーム API のスタブ =====
package.preload["json"] = function()
    return {encode = function() return "" end, decode = function() return {} end}
end

-- 詳細ログのファイル出力を捕まえる。実ファイルを作らせないためでもある
-- (パスが ../addons/... なので、素通しするとリポジトリの外へ書き出してしまう)。
local vlog_file = {}
-- g.create_folder のマーカーファイル。有無を差し替えて os.execute の空振りを見る。
local marker_exists = {}
local real_io_open = io.open
io.open = function(path, mode, ...)
    if type(path) == "string" and path:find("verbose_log.txt", 1, true) then
        if mode == "w" then
            vlog_file = {}
        end
        return {
            write = function(_, s) vlog_file[#vlog_file + 1] = s end,
            close = function() end
        }
    end
    if type(path) == "string" and path:find("mkdir.txt", 1, true) then
        if mode == "r" and not marker_exists[path] then
            return nil
        end
        marker_exists[path] = true
        return {read = function() return "x" end, write = function() end, close = function() end}
    end
    return real_io_open(path, mode, ...)
end

local os_execute_calls = {}
os.execute = function(cmd)
    os_execute_calls[#os_execute_calls + 1] = cmd
    return 0
end

local state = {map_name = "town", getclass_calls = 0}
local MAP_TYPES = {town = "City", field1 = "Field", raid1 = "Instance"} -- "unknown" は未登録
local MAP_TYPE_EMPTY = {} -- クラスは引けるが MapType が空、という実機で起こりうる状態

session = {
    GetMapName = function() return state.map_name end,
    GetMapID = function() return 1 end,
    GetMySession = function() return {GetCID = function() return 1 end} end,
}

function GetClass(_kind, name)
    state.getclass_calls = state.getclass_calls + 1
    if MAP_TYPE_EMPTY[name] then
        return {MapType = ""}
    end
    local t = MAP_TYPES[name]
    if not t then
        return nil -- 未知/インスタンスマップでは実機でも nil が返りうる
    end
    return {MapType = t}
end

local frames = {}
local function new_frame(name, visible)
    return {
        _name = name,
        _visible = visible or 0,
        _show_calls = 0,
        IsVisible = function(self) return self._visible end,
        ShowWindow = function(self, v)
            self._visible = v
            self._show_calls = self._show_calls + 1
        end,
        GetName = function(self) return self._name end,
    }
end

local sysmsgs = {}
local created_frames = {}
ui = {
    GetFrame = function(name) return frames[name] end,
    SysMsg = function(msg) sysmsgs[#sysmsgs + 1] = msg end,
    CreateNewFrame = function(template, name)
        created_frames[#created_frames + 1] = {template = template, name = name}
        frames[name] = new_frame(name, 1)
        return frames[name]
    end,
}
function AUTO_CAST(x) return x end
option = {GetCurrentCountry = function() return "Japanese" end}
imcTime = {GetAppTimeMS = function() return 0 end}

-- ===== 対象を 1 チャンクとして読み込む =====
local chunks = {}
for _, rel in ipairs(CORE_PARTS) do
    local f = assert(io.open(rel, "rb"), "読めない（リポジトリルートから実行すること）: " .. rel)
    chunks[#chunks + 1] = f:read("*a")
    f:close()
end
assert(load(table.concat(chunks, "\n"), "=core"))()

local g = _G["ADDONS"]["norisan"]["_NEXUS_ADDONS_P"]

-- ===== 検査ヘルパ =====
local failures = 0
local function check(label, got, want)
    if got ~= want then
        failures = failures + 1
        print(string.format("  NG  %s: got=%s want=%s", label, tostring(got), tostring(want)))
    else
        print(string.format("  ok  %s = %s", label, tostring(got)))
    end
end

-- ===== 1. get_map_type: マップ切替をまたいだ戻り値 =====
print("[1] get_map_type の戻り値")
state.map_name = "town";    check("town", g.get_map_type(), "City")
state.map_name = "field1";  check("field1", g.get_map_type(), "Field")
state.map_name = "raid1";   check("raid1", g.get_map_type(), "Instance")
state.map_name = "unknown"; check("unknown(GetClass が nil)", g.get_map_type(), nil)
state.map_name = "town";    check("town に戻る(古い値が残らない)", g.get_map_type(), "City")

-- ===== 2. get_map_type: 引けたマップだけメモ化される =====
print("[2] 同一マップでの GetClass 呼び出し回数")
state.map_name = "field1"
g.get_map_type() -- ここで 1 回引かせる
state.getclass_calls = 0
for _ = 1, 5 do g.get_map_type() end
check("field1(引けた) を5回引いたときの GetClass 回数", state.getclass_calls, 0)

-- 引けなかった結果は覚えない。覚えると、ロード中などに一度 nil を掴んだだけで
-- そのマップに居る間ずっと nil が返り続け(無効化する契機が無い)、
-- guild_event_warp の移動可否チェック等の呼び出し側が全部壊れる。
state.map_name = "unknown"
g.get_map_type()
state.getclass_calls = 0
for _ = 1, 5 do g.get_map_type() end
check("unknown(引けない) を5回引いたときの GetClass 回数", state.getclass_calls, 5)

-- ===== 2-2. 一時的に引けなかった後、引けるようになったら拾い直す =====
print("[2-2] 一時的な取得失敗から回復する")
state.map_name = "late_map" -- MAP_TYPES 未登録 = まだ引けない
check("引けない間は nil", g.get_map_type(), nil)
MAP_TYPES["late_map"] = "Field" -- IES が引けるようになった
check("引けるようになれば拾い直す", g.get_map_type(), "Field")
MAP_TYPES["late_map"] = nil

-- ===== 3. update_frames: 非表示フレームの表示判定 =====
local FRAME_KEYS = {"always_status", "pick_item_tracker", "monster_kill_count", "debuff_notice",
                    "guild_event_warp", "lets_go_home", "relic_change", "vakarine_equip", "sub_map",
                    "save_quest", "indun_panel", "Battle_ritual", "muteki", "au_map", "tos_btn"}

local function reset_frames(visible)
    frames = {}
    frames["_nexus_addons_p"] = new_frame("_nexus_addons_p", 1)
    for _, k in ipairs(FRAME_KEYS) do
        frames["_nexus_addons_p" .. k] = new_frame(k, visible)
    end
end

print("[3] update_frames: pick_item_tracker は街/インスタンスでは出さない")
for _, case in ipairs({{"town", 0}, {"raid1", 0}, {"field1", 1}, {"unknown", 1}}) do
    local map, want_pick = case[1], case[2]
    state.map_name = map
    reset_frames(0)
    _nexus_addons_p_update_frames()
    local others_ok = true
    for _, k in ipairs(FRAME_KEYS) do
        if k ~= "pick_item_tracker" and frames["_nexus_addons_p" .. k]._visible ~= 1 then
            others_ok = false
        end
    end
    check(map .. ": pick_item_tracker", frames["_nexus_addons_ppick_item_tracker"]._visible, want_pick)
    check(map .. ": その他のフレームは表示", others_ok, true)
end

-- ===== 4. 既に表示中のものへ余計な ShowWindow を呼ばない =====
print("[4] 表示中のフレームは触らない")
state.map_name = "field1"
reset_frames(1)
_nexus_addons_p_update_frames()
local reshown = 0
for _, k in ipairs(FRAME_KEYS) do
    reshown = reshown + frames["_nexus_addons_p" .. k]._show_calls
end
check("ShowWindow 呼び出し回数", reshown, 0)

-- ===== 5. フレームが存在しなくても落ちない =====
print("[5] フレーム不在でも完走する")
state.map_name = "field1"
reset_frames(0)
frames["_nexus_addons_psub_map"] = nil
frames["_nexus_addons_p"] = nil
check("エラーなく完走", (pcall(_nexus_addons_p_update_frames)), true)

-- ===== 6. 詳細ログ(g.vlog): 出力条件 =====
print("[6] g.vlog は設定 ON のときだけ出す")
local saved_settings = g.settings
g.settings = nil
sysmsgs, vlog_file = {}, {}
g.vlog("設定ロード前")
check("設定未ロード時はチャットに出さない", #sysmsgs, 0)
check("設定未ロード時はファイルにも書かない", #vlog_file, 0)

g.settings = {verbose_log = 0}
g.vlog("OFF のとき")
check("OFF のときはチャットに出さない", #sysmsgs, 0)
check("OFF のときはファイルにも書かない", #vlog_file, 0)

g.settings = {verbose_log = 1}
g.vlog("値=%d", 42)
check("ON のときはチャットに出す", #sysmsgs, 1)
check("書式が展開される", sysmsgs[1]:find("値=42", 1, true) ~= nil, true)
check("ON のときはファイルにも書く", #vlog_file, 1)
check("ファイルにも同じ内容が入る", vlog_file[1]:find("値=42", 1, true) ~= nil, true)

-- ファイル側は色やタグを外す（報告用に読めるテキストで残す）
sysmsgs, vlog_file = {}, {}
g.vlog("{#FF6347}init: xxx FAILED{/} 理由")
check("チャットには色タグが残る", sysmsgs[1]:find("{#FF6347}", 1, true) ~= nil, true)
check("ファイルからは色タグを外す", vlog_file[1]:find("{", 1, true), nil)
check("タグを外しても本文は残る", vlog_file[1]:find("init: xxx FAILED 理由", 1, true) ~= nil, true)

-- 作り直すのはクライアント起動後の最初の1行だけ。
-- GAME_START はマップ移動のたびに来るので、そこで作り直すと直前のマップのログが消える。
g.vlog_started, g.vlog_lines = nil, nil
vlog_file = {"前回起動時に残っていた行"}
g.vlog("起動後の1行目")
check("起動後の最初の1行で作り直す", #vlog_file, 1)
g.vlog("===== GAME_START (マップ移動)")
g.vlog("init: always_status (0ms)")
check("マップ移動をまたいでも消えない", #vlog_file, 3)

-- 際限なく育たせない（マップ移動のたびに 50 行前後の init が出るため）
g.vlog_lines = 20000
g.vlog("上限到達後の行")
check("上限で取り直す(注記+本文の2行)", #vlog_file, 2)
check("取り直しは注記を残す", vlog_file[1]:find("取り直し", 1, true) ~= nil, true)

-- 書式化に失敗しても、デバッグ用のログが本体を巻き込んで落としてはいけない
sysmsgs, vlog_file = {}, {}
check("引数不足でも落ちない", (pcall(g.vlog, "%d と %d", 1)), true)
check("落ちずに1行は出す", #sysmsgs, 1)

-- ===== 7. 詳細ログ: 取得失敗はマップごとに 1 回だけ =====
-- 失敗はキャッシュしない = 毎フレーム来るので、絞らないと毎フレーム流れる。
print("[7] MapType 取得失敗のログはマップごとに1回")
g.map_type_cache_name, g.map_type_failed_name = nil, nil
sysmsgs = {}
state.map_name = "unknown"
for _ = 1, 5 do g.get_map_type() end
check("同じマップで5回引いてもログは1行", #sysmsgs, 1)
state.map_name = "unknown2"
g.get_map_type()
check("別のマップなら改めて出す", #sysmsgs, 2)
-- 引けるようになったら成功ログ側へ切り替わる
sysmsgs = {}
MAP_TYPES["unknown2"] = "Field"
g.get_map_type()
check("成功したら1行出す", #sysmsgs, 1)
check("成功ログに種別が入る", sysmsgs[1]:find("Field", 1, true) ~= nil, true)
MAP_TYPES["unknown2"] = nil

-- ===== 8. 設定の verbose_log がプルーニングで消えない =====
-- _nexus_addons_p_load_settings は登録アドオン以外のトップレベルキーを削除するので、
-- 除外し忘れると「チェックしても次回起動で戻る」形で壊れる。
print("[8] verbose_log が設定のプルーニングを生き延びる")
local stored
g.save_json = function(_, tbl) stored = tbl; return true end
g.settings_path = "dummy"

g.load_json = function() return nil end -- 設定ファイルがまだ無い状態
_nexus_addons_p_load_settings()
check("既定値は 0", g.settings.verbose_log, 0)

g.load_json = function() return {verbose_log = 1, bogus_key = "x"} end
_nexus_addons_p_load_settings()
check("ON が保持される", g.settings.verbose_log, 1)
check("登録外のキーは従来どおり削除", g.settings.bogus_key, nil)
check("保存内容にも載る", stored and stored.verbose_log, 1)
g.settings = saved_settings

-- ===== 9. get_map_type: MapType が空のときも「失敗」として扱う =====
-- クラスは引けたが MapType が空、という状態を覚えると無効化する契機が無く、
-- そのマップに居る間ずっと nil が返り続ける(引けなかったときと同じ問題)。
print("[9] MapType が空のときはキャッシュしない")
g.map_type_cache_name, g.map_type_failed_name = nil, nil
MAP_TYPE_EMPTY["empty_map"] = true
state.map_name = "empty_map"
check("空なら nil を返す", g.get_map_type(), nil)
state.getclass_calls = 0
for _ = 1, 5 do g.get_map_type() end
check("5回引いたら5回とも引き直す", state.getclass_calls, 5)
MAP_TYPE_EMPTY["empty_map"] = nil
MAP_TYPES["empty_map"] = "Field" -- 埋まったら拾い直す
check("値が入れば拾い直す", g.get_map_type(), "Field")
MAP_TYPES["empty_map"] = nil

-- ===== 10. create_folder: マーカーがあれば cmd を起動しない =====
-- os.execute は cmd.exe の同期起動なので、毎回空振りさせない。
print("[10] create_folder のマーカーによる空振り防止")
marker_exists, os_execute_calls = {}, {}
g.create_folder("..\\addons\\test_folder", "../addons/test_folder/mkdir.txt")
check("初回は mkdir を実行", #os_execute_calls, 1)
check("マーカーを作る", marker_exists["../addons/test_folder/mkdir.txt"], true)
os_execute_calls = {}
g.create_folder("..\\addons\\test_folder", "../addons/test_folder/mkdir.txt")
check("2回目は実行しない", #os_execute_calls, 0)

-- ===== 11. create_persistent_frame: ESC で消えない土台を使う =====
-- chat_memberlist は hideable="true" で ESC に閉じられる。常時表示フレームが
-- ここを踏むと ESC で消え、IsVisible() にも出ないので復帰もできない。
print("[11] 常時表示フレームの土台")
created_frames = {}
g.create_persistent_frame("test_frame")
check("生成に使う土台", created_frames[1] and created_frames[1].template, "notice_on_pc")
check("フレーム名をそのまま使う", created_frames[1] and created_frames[1].name, "test_frame")

-- ===== 12. init の詳細ログは ON のアドオンだけ =====
-- on_init は ON/OFF によらず全アドオン分呼ばれる(OFF 側はフレームの後始末に使う)ので、
-- 絞らないとマップ移動のたびに 48 行流れて肝心の行が埋もれる。
print("[12] init ログは ON のアドオンだけに出す")
g.settings = {
    verbose_log = 1,
    addon_on = {use = 1},
    addon_off = {use = 0}
}
sysmsgs, vlog_file = {}, {}
_nexus_addons_p_vlog_init("addon_on", 3)
check("ON は出す", #sysmsgs, 1)
check("所要時間が入る", sysmsgs[1]:find("(3ms)", 1, true) ~= nil, true)

sysmsgs, vlog_file = {}, {}
_nexus_addons_p_vlog_init("addon_off", 3)
check("OFF は出さない", #sysmsgs, 0)
check("OFF はファイルにも書かない", #vlog_file, 0)

-- 登録リストに在るのに設定が無い、という壊れた状態でも落ちない
sysmsgs = {}
check("設定が無くても落ちない", (pcall(_nexus_addons_p_vlog_init, "unknown_addon", 1)), true)
check("設定が無ければ出さない", #sysmsgs, 0)
g.settings = nil
check("設定未ロードでも落ちない", (pcall(_nexus_addons_p_vlog_init, "addon_on", 1)), true)
g.settings = saved_settings

if failures > 0 then
    print(string.format("FAILED: %d 件", failures))
    os.exit(1)
end
print("ALL OK")
