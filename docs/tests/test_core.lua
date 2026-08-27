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
    "nexus_addons_p/src/core/30_maintenance.lua", -- 全 OFF / 設定のバックアップ・復元
}

-- ===== ゲーム API のスタブ =====
package.preload["json"] = function()
    return {encode = function() return "" end, decode = function() return {} end}
end

-- 詳細ログのファイル出力を捕まえる。実ファイルを作らせないためでもある
-- (パスが ../addons/... なので、素通しするとリポジトリの外へ書き出してしまう)。
local vlog_file = {}
-- 詳細ログのファイルを開けない状態を作れるようにする（[13] で使う）。
local vlog_open_fails = false
-- g.create_folder のマーカーファイル。有無を差し替えて os.execute の空振りを見る。
local marker_exists = {}
local real_io_open = io.open
io.open = function(path, mode, ...)
    if type(path) == "string" and path:find("verbose_log.txt", 1, true) then
        if vlog_open_fails then
            return nil
        end
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

-- Keyword は ";" 区切りの並び。実機では別キーワードが前後に付く。
local MAP_KEYWORDS = {
    town = "CityMap;SafeZone",
    field1 = "FieldMap",
    raid1 = "WeeklyBossMap;RaidMap",
    -- 「部分一致で誤爆しないか」を見るための、紛らわしい名前だけを持つマップ
    tricky = "WeeklyBossMapEntrance;NotWeeklyBossMap",
}

function GetClass(_kind, name)
    state.getclass_calls = state.getclass_calls + 1
    if MAP_TYPE_EMPTY[name] then
        return {MapType = ""}
    end
    local t = MAP_TYPES[name]
    if not t then
        if MAP_KEYWORDS[name] then
            return {Keyword = MAP_KEYWORDS[name]} -- MapType は無いが Keyword はある
        end
        return nil -- 未知/インスタンスマップでは実機でも nil が返りうる
    end
    return {MapType = t, Keyword = MAP_KEYWORDS[name]}
end

function TryGetProp(cls, prop, default)
    local v = cls and cls[prop]
    if v == nil then
        return default
    end
    return v
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
-- ゲームクライアントの Lua には table.unpack がある(5.2 互換)。素の LuaJIT には無いので補う。
-- フックのラッパ(g.setup_hook_and_event)が戻り値を返すときに通る。
table.unpack = table.unpack or unpack
option = {GetCurrentCountry = function() return "Japanese" end}
-- ESC の二重処理よけ（同じ押下で 2 経路から来る）を試すため、時計は進められるようにする。
local app_ms = 0
imcTime = {GetAppTimeMS = function() return app_ms end}
-- ESC の割り込み先。ゲーム側は設定しかできない（取得 API が無い）ので、記録だけ取る。
local escape_scp = nil
ui.SetEscapeScp = function(scp) escape_scp = scp end

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

-- 初期化のスロットルも同じ経路に乗る。**正規化まで load_settings で済ませること。**
-- 0 や文字列が残ると分割実行が 1 件も進まないまま回り続ける（g.init_throttle 参照）。
g.load_json = function() return nil end
_nexus_addons_p_load_settings()
check("init_batch の既定は推奨値", g.settings.init_batch, g.INIT_BATCH_DEFAULT)
g.load_json = function() return {init_batch = 8} end
_nexus_addons_p_load_settings()
check("範囲内の値は保持される", g.settings.init_batch, 8)
g.load_json = function() return {init_batch = 0} end
_nexus_addons_p_load_settings()
check("0 は下限まで押し上げる", g.settings.init_batch, g.INIT_BATCH_MIN)
check("正した値が保存される", stored and stored.init_batch, g.INIT_BATCH_MIN)
g.load_json = function() return {init_batch = "abc"} end
_nexus_addons_p_load_settings()
check("数字でなければ推奨値", g.settings.init_batch, g.INIT_BATCH_DEFAULT)
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

-- ===== 13. ログファイルを開けなかったら状態を進めない =====
-- 起動後の最初の 1 行だけがファイルを作り直す。開けなかったのに「作り直した」ことに
-- してしまうと、次回から追記になり前回起動分のログへ書き足す形になる。
-- verbose_log.txt は「そのまま不具合報告に添付できる = 今回の起動分だけ」が前提なので、
-- 2 回のプレイが混ざると読む側が判断を誤る。
print("[13] ログファイルを開けなければ作り直し扱いにしない")
g.settings = {verbose_log = 1}
g.vlog_started, g.vlog_lines, vlog_file = nil, nil, {"前回起動分の残り\n"}
vlog_open_fails = true
g.vlog("開けないので書けない行")
check("開けないので書けない", #vlog_file, 1)
check("作り直し済みにしない", g.vlog_started, nil)
vlog_open_fails = false
g.vlog("開けたので作り直す")
check("開けた時点で作り直す", #vlog_file, 1)
check("前回分は残っていない", vlog_file[1]:find("前回起動分", 1, true), nil)
check("作り直し済みになる", g.vlog_started, true)

-- 上限到達も同じ。取り直せていないのに行数だけ 0 に戻すと、以後は上限が効かない。
g.vlog_lines = 999999
vlog_open_fails = true
g.vlog("上限に達したが開けない")
check("行数を戻さない", g.vlog_lines, 999999)
vlog_open_fails = false
g.settings = saved_settings

-- ===== 14. GAME_START がメニューのフレーム名に nil を渡さない =====
-- _G["norisan"]["MENU"].frame_name を入れるのは相乗り側のアドオンなので、
-- 誰も入れていなければ nil。初回ログインは常にこの状態で、ここを素通しすると
-- ui.GetFrame(nil) を踏む。以降のメニュー生成まで巻き添えで止まる。
print("[14] GAME_START がフレーム名に nil を渡さない")
local getframe_args = {}
local real_ui_getframe = ui.GetFrame
ui.GetFrame = function(name)
    getframe_args[#getframe_args + 1] = name
    assert(name ~= nil, "ui.GetFrame に nil が渡された")
    return real_ui_getframe(name)
end
-- GAME_START の後半だけを見たいので、その手前が要求するものを揃える。
local created_menu = 0
_G.addons_menu_create_frame = function() created_menu = created_menu + 1 end
g.load_json = function() return nil end
g.save_json = function() return true end
g.settings_path, g.migrate_result, g.origin_conflict = "dummy", false, nil
_G["norisan"] = {MENU = {}} -- frame_name を誰も入れていない = 初回ログイン
frames, state.map_name = {}, "town"

local ok, err = pcall(_nexus_addons_p_GAME_START, new_frame("root", 1))
check("落ちない", ok, true)
if not ok then
    print("      " .. tostring(err))
end
for _, name in ipairs(getframe_args) do
    check("nil を渡していない", name ~= nil, true)
end
check("メニューを作りに行く", created_menu, 1)

-- 相乗り側が別名で作っていたら、そちらは壊してから作り直す（既存の挙動）
local destroyed = {}
ui.DestroyFrame = function(name) destroyed[#destroyed + 1] = name end
_G["norisan"] = {MENU = {frame_name = "other_addon_menu"}}
frames["other_addon_menu"] = new_frame("other_addon_menu", 1)
created_menu = 0
check("落ちない", (pcall(_nexus_addons_p_GAME_START, new_frame("root", 1))), true)
check("別名のフレームは壊す", destroyed[1], "other_addon_menu")
check("こちらの名前で作り直す", created_menu, 1)

g.settings = saved_settings

-- ===== 15. 全アドオン OFF =====
-- 押し間違いで全部消えると元の ON/OFF が分からなくなるので、UI 側は確認を挟む。
-- ここで見るのは確認の後に走る本体（設定の書き換えと保存・再 init の呼び方）。
print("[15] 全アドオンを OFF にする")
local broad_msgs = {}
imcAddOn = {BroadMsg = function(_, msg) broad_msgs[#broad_msgs + 1] = msg end}
local frame_inits = 0
_G._nexus_addons_p_frame_init = function() frame_inits = frame_inits + 1 end
g.save_json = function(_, tbl) stored = tbl; return true end
g.settings_path = "dummy"

g.settings = {verbose_log = 0}
for i, entry in ipairs(g._nexus_addons_p) do
    g.settings[entry.key] = {use = (i % 2 == 0) and 1 or 0} -- ON/OFF が混ざった状態から
end
local half_on = 0
for _, entry in ipairs(g._nexus_addons_p) do
    half_on = half_on + g.settings[entry.key].use
end
check("ON になっている件数を数える", g.set_all_addons_use(0), half_on)
local left_on = 0
for _, entry in ipairs(g._nexus_addons_p) do
    left_on = left_on + g.settings[entry.key].use
end
check("ON が残らない", left_on, 0)
check("すでに全 OFF なら 0 件", g.set_all_addons_use(0), 0)
-- 設定未ロード(本家検出で初期化を止めた等)でも落ちない
g.settings = nil
check("設定未ロードでも落ちない", (pcall(g.set_all_addons_use, 0)), true)

g.settings = {verbose_log = 0}
for _, entry in ipairs(g._nexus_addons_p) do
    g.settings[entry.key] = {use = 1}
end
stored, broad_msgs, frame_inits = nil, {}, 0
g.loaded = false -- ロード完了前は init_addons が非同期ロードを開始する経路に入る
check("ロード前でも落ちない", (pcall(_nexus_addons_p_disable_all_addons_exec)), true)
check("設定は保存する", stored and stored[g._nexus_addons_p[1].key].use, 0)
check("一覧を作り直す", frame_inits, 1)
check("件数を知らせる", broad_msgs[1] and broad_msgs[1]:find("OFF", 1, true) ~= nil, true)

-- 変更が無いときは保存も再 init もしない（無用な cmd 起動やフレーム再生成を避ける）
stored, broad_msgs, frame_inits = nil, {}, 0
_nexus_addons_p_disable_all_addons_exec()
check("すでに全 OFF なら保存しない", stored, nil)
check("すでに全 OFF なら作り直さない", frame_inits, 0)

-- ===== 16. 設定のバックアップと復元 =====
-- コピーは io だけで 1 ファイルずつ行う（xcopy を使うと押すたびにコンソール窓が
-- 一瞬出るため）。代わりに「何をコピーするか」を g.backup_files と
-- monster_kill_count.json の map_ids から自前で組み立てるので、そこを見る。
print("[16] 設定のバックアップと復元")
local vfs = {} -- path -> 中身（文字列）
local prev_io_open = io.open
io.open = function(path, mode, ...)
    if type(path) ~= "string" or not path:find("^%.%./addons/") or path:find("mkdir.txt", 1, true) or
        path:find("verbose_log.txt", 1, true) then
        return prev_io_open(path, mode, ...)
    end
    if mode == nil or mode:find("r", 1, true) then
        local content = vfs[path]
        if not content then
            return nil
        end
        return {read = function() return content end, close = function() end}
    end
    local buf = {}
    return {
        write = function(_, s) buf[#buf + 1] = s; return true end,
        close = function() vfs[path] = table.concat(buf) end
    }
end
-- 実ファイルを消しに行かせない（パスが ../addons/... なのでリポジトリの外を指す）
local prev_os_remove, prev_os_rename = os.remove, os.rename
os.remove = function(path)
    if type(path) ~= "string" or not path:find("^%.%./addons/") then
        return prev_os_remove(path)
    end
    if vfs[path] == nil then
        return nil, path .. ": No such file or directory"
    end
    vfs[path] = nil
    return true
end
os.rename = function(from, to)
    if type(from) ~= "string" or not from:find("^%.%./addons/") then
        return prev_os_rename(from, to)
    end
    if vfs[from] == nil then
        return nil, from .. ": No such file or directory"
    end
    vfs[to], vfs[from] = vfs[from], nil
    return true
end
-- JSON は Lua のテーブル表記で vfs に置く。文字列としてコピーされても中身が保てるので、
-- 「バックアップした monster_kill_count.json を読んで復元対象を組み立てる」経路まで見られる。
local function ser(o)
    if type(o) == "table" then
        local parts = {"{"}
        for k, v in pairs(o) do
            parts[#parts + 1] = "[" .. ser(k) .. "]=" .. ser(v) .. ","
        end
        parts[#parts + 1] = "}"
        return table.concat(parts)
    elseif type(o) == "string" then
        return string.format("%q", o)
    end
    return tostring(o)
end
g.save_json = function(path, tbl) vfs[path] = "return " .. ser(tbl); return true end
g.load_json = function(path)
    local content = vfs[path]
    if not content or content:sub(1, 7) ~= "return " then
        return nil
    end
    local chunk = load(content)
    if not chunk then
        return nil
    end
    local ok_load, result = pcall(chunk)
    return ok_load and result or nil
end

g.active_id = "1234567"
local paths = g.backup_paths()
-- バックアップ先が AID フォルダの中だと、自分自身をバックアップし続けることになる
check("退避先は AID フォルダの外", paths.backup:find(paths.live .. "/", 1, true), nil)

local function reset_live()
    vfs = {}
    vfs[paths.live .. "/settings.json"] = "LIVE-SETTINGS"
    vfs[paths.live .. "/always_status.json"] = "LIVE-ALWAYS-STATUS"
    vfs[paths.live .. "/warehouse.dat"] = "LIVE-DAT"
    -- 可変名のファイル。どのマップの記録があるかは monster_kill_count.json が持っている
    g.save_json(paths.live .. "/monster_kill_count.json", {map_ids = {1001, 1002}})
    vfs[paths.live .. "/monster_kill_count/1001.json"] = "LIVE-KILL-1001"
    vfs[paths.live .. "/monster_kill_count/1002.json"] = "LIVE-KILL-1002"
    vfs[paths.live .. "/not_listed.json"] = "LIVE-UNKNOWN" -- 一覧に無いファイル
end

reset_live()
check("バックアップが無ければ nil", g.backup_info(), nil)
check("バックアップが無ければ復元しない", g.restore_settings(), false)

marker_exists, os_execute_calls = {}, {}
local ok_backup, copied, failed = g.backup_settings()
check("バックアップできる", ok_backup, true)
check("コピーした件数を返す", copied, 6) -- settings/always_status/warehouse/mkc + マップ 2 件
check("失敗は 0 件", failed, 0)
check("settings.json が入る", vfs[paths.backup .. "/settings.json"], "LIVE-SETTINGS")
check("各アドオンの設定も入る", vfs[paths.backup .. "/always_status.json"], "LIVE-ALWAYS-STATUS")
check(".dat も入る", vfs[paths.backup .. "/warehouse.dat"], "LIVE-DAT")
check("可変名のファイルも入る", vfs[paths.backup .. "/monster_kill_count/1001.json"], "LIVE-KILL-1001")
check("可変名のファイルは全部入る", vfs[paths.backup .. "/monster_kill_count/1002.json"], "LIVE-KILL-1002")
-- 一覧に無いものは運べない。これが本方式の代償で、[17] が一覧の追加漏れを検出する。
check("一覧に無いファイルは入らない", vfs[paths.backup .. "/not_listed.json"], nil)
local info = g.backup_info()
check("取得日時を記録する", type(info and info.time), "string")
check("取りこぼしなしと記録する", info.partial, 0)
-- 日時のファイルは退避先の *外*。中に置くと復元時に live 側へ紛れ込む
check("日時は退避先の外に置く", paths.info:find(paths.backup .. "/", 1, true), nil)

-- コンソール窓を出さないのが本方式の目的。フォルダ作成だけは cmd に頼るが、
-- g.create_folder のマーカーが効くので初回だけ。ここが崩れると点滅が戻る。
check("初回はフォルダ作成で 1 回だけ cmd を起動", #os_execute_calls, 1)
os_execute_calls = {}
check("2 回目のバックアップ", (g.backup_settings()), true)
check("2 回目は cmd を起動しない", #os_execute_calls, 0)

-- 復元は上書き。バックアップ後に増えたファイルは消さない（消す方向の同期はしない）
-- 書き戻し先の monster_kill_count/ は実機では monster_kill_count 側が起動時に作っている
-- （＝マーカーが在る）ので、その状態を作ってから見る。無い場合は下の分岐で別途見る。
marker_exists[paths.live .. "/monster_kill_count/mkdir.txt"] = true
os_execute_calls = {}
vfs[paths.live .. "/settings.json"] = "BROKEN"
vfs[paths.live .. "/after_backup.json"] = "NEW"
local ok_restore, restored = g.restore_settings()
check("復元できる", ok_restore, true)
check("復元も件数を返す", restored, 6)
check("復元では cmd を起動しない", #os_execute_calls, 0)
check("設定が戻る", vfs[paths.live .. "/settings.json"], "LIVE-SETTINGS")
check("マップ記録も戻る", vfs[paths.live .. "/monster_kill_count/1002.json"], "LIVE-KILL-1002")
check("バックアップ後のファイルは消さない", vfs[paths.live .. "/after_backup.json"], "NEW")
check("日時のファイルは live へ入らない", vfs[paths.live .. "/" .. g.active_id .. "_info.json"], nil)

-- コピー先に前回の分が残っていても、失敗を成功と取り違えない。
-- 「コピー先にファイルが在るか」で見ると古いファイルを掴んでしまうので、
-- 数えるのは g.copy_file の戻り値の方（xcopy を使っていた頃の取り違え e250046ed）。
local prev_copy_file = g.copy_file
g.copy_file = function() return false end
local ok_failed, copied_failed, failed_count = g.backup_settings()
check("1 件も運べなければ失敗", ok_failed, false)
check("成功件数は 0", copied_failed, 0)
check("失敗件数を返す", failed_count, 6)
check("前回の退避は残っている", vfs[paths.backup .. "/settings.json"], "LIVE-SETTINGS")
check("失敗したら日時を更新しない", g.backup_info().time, info.time)
g.copy_file = prev_copy_file

-- 一部だけ失敗した場合は、取りこぼしがあると記録する（復元前に分かるように）
local fail_once = true
g.copy_file = function(src, dst)
    if fail_once then
        fail_once = false
        return false
    end
    return prev_copy_file(src, dst)
end
local ok_partial, copied_partial, failed_partial = g.backup_settings()
check("一部失敗でも運べた分は残す", ok_partial, true)
check("成功件数", copied_partial, 5)
check("失敗件数", failed_partial, 1)
check("取りこぼしを記録する", g.backup_info().partial, 1)
g.copy_file = prev_copy_file

-- 復元先の monster_kill_count/ が無い場合だけフォルダを作る（マーカーが無い＝未作成）
reset_live()
check("退避", (g.backup_settings()), true)
marker_exists, os_execute_calls = {}, {}
check("復元", (g.restore_settings()), true)
check("戻すマップ記録があればフォルダを作る", #os_execute_calls, 1)

-- AID が未取得（ON_INIT 前）でも落ちない
g.active_id = nil
check("AID 前でもパスは nil", g.backup_paths(), nil)
check("AID 前のバックアップは失敗", g.backup_settings(), false)
check("AID 前の復元は失敗", g.restore_settings(), false)
check("AID 前の情報取得は nil", g.backup_info(), nil)

-- ===== 16-2. 本家からの引き継ぎ =====
-- 以前は xcopy(cmd)でフォルダごとコピーしていたが、バックアップと同じ一覧
-- (g.settings_file_names)を使って io で 1 ファイルずつ写す形にした。cmd が出るのは
-- 可変名ファイルを置くサブフォルダを作る mkdir だけ。vfs のスタブをそのまま使うので
-- [16] の中に置いている。
print("[16-2] 本家の設定を引き継ぐ")
do
    g.active_id = "7654321"
    local src = "../addons/_nexus_addons/" .. g.active_id
    local dst = "../addons/_nexus_addons_p/" .. g.active_id
    vfs[src .. "/settings.json"] = "ORIGIN-SETTINGS"
    vfs[src .. "/muteki.json"] = "ORIGIN-MUTEKI"
    vfs[src .. "/not_listed.json"] = "ORIGIN-UNKNOWN" -- 一覧に無いファイル
    g.save_json(src .. "/monster_kill_count.json", {map_ids = {1001}})
    vfs[src .. "/monster_kill_count/1001.json"] = "ORIGIN-KILL-1001"
    marker_exists, os_execute_calls = {}, {}
    check("引き継いだ", g.migrate_from_origin(), "copied")
    check("settings.json が入る", vfs[dst .. "/settings.json"], "ORIGIN-SETTINGS")
    check("各アドオンの設定も入る", vfs[dst .. "/muteki.json"], "ORIGIN-MUTEKI")
    check("可変名のファイルも入る", vfs[dst .. "/monster_kill_count/1001.json"], "ORIGIN-KILL-1001")
    check("一覧に無いファイルは入らない", vfs[dst .. "/not_listed.json"], nil)
    check("件数は GAME_START まで持ち越す", g.migrate_summary ~= nil, true)
    local used_xcopy = false
    for _, cmd in ipairs(os_execute_calls) do
        if string.find(cmd, "xcopy", 1, true) then
            used_xcopy = true
        end
    end
    check("xcopy は使わない", used_xcopy, false)
    check("cmd はサブフォルダの mkdir だけ", #os_execute_calls, 1)

    -- 自分側に設定があるときは絶対に走らせない(本家の古い設定で上書きしてしまう)
    vfs[dst .. "/settings.json"] = "MINE"
    check("既に自分の設定があれば何もしない", g.migrate_from_origin(), nil)
    check("自分の設定は書き換わらない", vfs[dst .. "/settings.json"], "MINE")
    g.active_id = nil
end

-- ===== 16-3. 移行前のバックアップを戻したときに .lua が勝たない =====
-- 復元は上書きだけなので、.json しか無いバックアップを戻しても live に残った .lua が
-- 勝ち、「復元しました」と出たのに設定が戻らない。対になっている .lua だけを消す
-- g.drop_superseded_lua がその 1 点を埋めている。消しすぎないことも併せて見る。
print("[16-3] 移行前のバックアップを復元すると古い .lua を退ける")
do
    local backup_dir, live_dir = "../addons/_nexus_addons_p/bk", "../addons/_nexus_addons_p/live"
    local function reset_pair()
        for path in pairs(vfs) do
            if path:find(backup_dir, 1, true) or path:find(live_dir, 1, true) then
                vfs[path] = nil
            end
        end
    end

    -- 移行前のバックアップ(.json だけ)。復元済みの live の .json は在る
    reset_pair()
    vfs[backup_dir .. "/cc_helper.json"] = "OLD"
    vfs[live_dir .. "/cc_helper.json"] = "OLD"
    vfs[live_dir .. "/cc_helper.lua"] = "NEW"
    check("対の .lua を消す", g.drop_superseded_lua(backup_dir, live_dir), 1)
    check("消えている", vfs[live_dir .. "/cc_helper.lua"], nil)
    check("復元した .json は残る", vfs[live_dir .. "/cc_helper.json"], "OLD")

    -- 移行後のバックアップ(.lua が在る)。こちらは .lua そのものが復元されているので触らない
    reset_pair()
    vfs[backup_dir .. "/cc_helper.lua"] = "BK"
    vfs[live_dir .. "/cc_helper.lua"] = "BK"
    vfs[live_dir .. "/cc_helper.json"] = "OLD"
    check("バックアップに .lua が在れば消さない", g.drop_superseded_lua(backup_dir, live_dir), 0)
    check("復元した .lua は残る", vfs[live_dir .. "/cc_helper.lua"], "BK")

    -- .json のコピーに失敗して live に届かなかったとき。ここで .lua を消すと設定を丸ごと失う
    reset_pair()
    vfs[backup_dir .. "/cc_helper.json"] = "OLD"
    vfs[live_dir .. "/cc_helper.lua"] = "NEW"
    check("復元できていなければ消さない", g.drop_superseded_lua(backup_dir, live_dir), 0)
    check("live の .lua は残る", vfs[live_dir .. "/cc_helper.lua"], "NEW")

    -- 対を持たない設定は対象外(消す方向の同期はここだけに閉じ込める)
    reset_pair()
    vfs[backup_dir .. "/muteki.json"] = "OLD"
    vfs[live_dir .. "/muteki.json"] = "OLD"
    vfs[live_dir .. "/always_status.lua"] = "KEEP"
    check("関係ない .lua は消さない", g.drop_superseded_lua(backup_dir, live_dir), 0)
    check("残っている", vfs[live_dir .. "/always_status.lua"], "KEEP")
    reset_pair()
end

io.open = prev_io_open
os.remove, os.rename = prev_os_remove, prev_os_rename
g.settings = saved_settings

-- ===== 17. バックアップ対象の一覧が src の実態と食い違っていないか =====
-- ディレクトリ列挙が無いので、g.backup_files に無いファイルは黙って取り残される
-- （バックアップしたつもりで設定が失われる）。bundle 内の
-- "../addons/%s/%s/<名前>" 文字列を全部拾って突き合わせ、追加漏れをここで落とす。
-- 新しい設定ファイルを増やしたら core/30_maintenance.lua の一覧に足すこと。
print("[17] バックアップ対象の一覧が src と一致する")
-- bundle は 1 本だけ。以前は _nexus_addons_p_conclude.lua という 2 本目があったが、
-- 読み込み順や読み込み漏れで壊れる事故が実機で出たため main へ取り込んだ
-- （nexus_addons_p/src/conclude_scope_open.lua を参照）。
local BUNDLES = {"nexus_addons_p/_nexus_addons_p/_nexus_addons_p.lua"}
-- 可変名。ここに載せたものは g.backup_files では扱えないので、扱いを個別に決めてある。
local KNOWN_DYNAMIC = {
    ["%s"] = "monster_kill_count フォルダ自体（g.create_folder で作る）",
    ["%s/%s.json"] = "monster_kill_count/<map_id>.json（map_ids から組み立てて運ぶ）",
    ["%s_copy.json"] = "旧 cc_helper 単体アドオンのフォルダ側。こちらの AID フォルダではない"
}
-- 設定ではないので運ばないもの
local NOT_SETTINGS = {["mkdir.txt"] = true}

local listed = {}
for _, name in ipairs(g.backup_files) do
    listed[name] = true
end
local found, missing, unknown_dynamic = {}, {}, {}
for _, rel in ipairs(BUNDLES) do
    local bundle = assert(io.open(rel, "rb"),
        "bundle が無い（先に python docs/bundle_from_src.py を実行すること）: " .. rel)
    local content = bundle:read("*a")
    bundle:close()
    for rest in content:gmatch('%.%./addons/%%s/%%s/([^"]*)"') do
        if rest ~= "" then
            if rest:find("%%s") then
                if not KNOWN_DYNAMIC[rest] then
                    unknown_dynamic[rest] = true
                end
            elseif not NOT_SETTINGS[rest] then
                found[rest] = true
                if not listed[rest] then
                    missing[rest] = true
                end
            end
        end
    end
end
local missing_names, unknown_names, stale_names = {}, {}, {}
for name in pairs(missing) do
    missing_names[#missing_names + 1] = name
end
for name in pairs(unknown_dynamic) do
    unknown_names[#unknown_names + 1] = name
end
for _, name in ipairs(g.backup_files) do
    if not found[name] then
        stale_names[#stale_names + 1] = name
    end
end
table.sort(missing_names)
table.sort(unknown_names)
table.sort(stale_names)
check("src にあって一覧に無いファイル", table.concat(missing_names, ", "), "")
check("扱いを決めていない可変名のパス", table.concat(unknown_names, ", "), "")
check("src から消えたのに一覧に残っているファイル", table.concat(stale_names, ", "), "")
check("一覧が空でない", #g.backup_files > 0, true)
-- .lua/.json の対（g.paired_lua_settings）は、両方が g.backup_files に載っていないと
-- 復元で片方だけが戻り、g.drop_superseded_lua の前提（live の .json は復元済み）が崩れる。
local pair_missing = {}
for _, pair in ipairs(g.paired_lua_settings) do
    if not listed[pair.json] then
        pair_missing[#pair_missing + 1] = pair.json
    end
    if not listed[pair.lua] then
        pair_missing[#pair_missing + 1] = pair.lua
    end
end
table.sort(pair_missing)
check("対になっているのに一覧に無いファイル", table.concat(pair_missing, ", "), "")

-- ===== 18. ESC で閉じるのは一番手前の 1 枚だけ =====
-- ESCAPE_PRESSED は登録済みハンドラ全部へ一斉に配られるので、各アドオンが素直に自分の
-- フレームを閉じると自作ウィンドウが全部まとめて消える。core 側の 1 ハンドラに集約して
-- スタックの一番上だけ閉じる、という前提が崩れていないかを見る。
print("[18] ESC は一番手前の 1 枚だけ閉じる")
local esc_closed = {}
local function esc_closer(key)
    return function()
        esc_closed[#esc_closed + 1] = key
        frames["f" .. key] = nil -- 実機と同じく、閉じたらフレームは消える
    end
end
_G["esc_test_close_a"] = esc_closer("a")
_G["esc_test_close_b"] = esc_closer("b")
_G["esc_test_close_boom"] = function()
    error("close で転んだ")
end
local function esc_setup(open_list)
    esc_closed = {}
    frames = {}
    g.esc_stack = {}
    g.esc_scp_set = nil
    g.esc_last_ms = nil
    g.esc_closed_ms = nil
    escape_scp = nil
    for _, key in ipairs(open_list) do
        frames["f" .. key] = new_frame("f" .. key, 1)
        g.esc_register("f" .. key, "esc_test_close_" .. key)
    end
end
-- 別の押下として扱わせる（同じ押下の二重配信よけは下で別途見る）
local function esc_press()
    app_ms = app_ms + 1000
    _nexus_addons_p_ESCAPE_PRESSED()
end

esc_setup({"a", "b"})
esc_press()
check("後から開いた方だけ閉じる", table.concat(esc_closed, ","), "b")
esc_press()
check("次の ESC でその下が閉じる", table.concat(esc_closed, ","), "b,a")
esc_press()
check("閉じるものが無ければ何もしない", table.concat(esc_closed, ","), "b,a")

-- × ボタンで閉じた分は登録が残るので、死んだ登録を飛ばして次を閉じる
esc_setup({"a", "b"})
frames["fb"] = nil
esc_press()
check("消えている登録は飛ばす", table.concat(esc_closed, ","), "a")

-- 開き直したものは最前面扱い
esc_setup({"a", "b"})
g.esc_register("fa", "esc_test_close_a")
esc_press()
check("開き直した方が先に閉じる", table.concat(esc_closed, ","), "a")
check("登録は重複しない", #g.esc_stack, 1)

-- 閉じる処理が転んでもゲーム側の ESC 処理を巻き込まない
esc_setup({"a"})
g.esc_register("fboom", "esc_test_close_boom")
frames["fboom"] = new_frame("fboom", 1)
check("エラーなく完走", (pcall(esc_press)), true)
esc_press()
check("転んだ分は積み残さず次へ進む", table.concat(esc_closed, ","), "a")

-- 同じ押下が 2 経路(SetEscapeScp / ESCAPE_PRESSED 一斉配信)から来ても 1 枚だけ
esc_setup({"a", "b"})
esc_press()
_nexus_addons_p_ESCAPE_PRESSED() -- 時間を進めない = 同じ押下
check("同じ押下では 1 枚だけ閉じる", table.concat(esc_closed, ","), "b")

-- ===== 18-2. ESC の割り込み先(ui.SetEscapeScp)の付け外し =====
-- 付けっぱなしにするとシステムメニューが開けなくなるので、閉じたら必ず戻す。
print("[18-2] ESC の割り込み先を開いている間だけ差し込む")
esc_setup({})
check("何も開いていなければ差し込まない", escape_scp, nil)
esc_setup({"a"})
check("開いたら差し込む", escape_scp, "_nexus_addons_p_ESCAPE_PRESSED()")
frames["fb"] = new_frame("fb", 1) -- 登録はフレームを出した後（順序が逆だと死んだ登録として捨てられる）
g.esc_register("fb", "esc_test_close_b")
esc_press()
check("まだ残っていれば差し込んだまま", escape_scp, "_nexus_addons_p_ESCAPE_PRESSED()")
esc_press()
check("最後の 1 枚を閉じたら戻す", escape_scp, "")

-- × ボタンで閉じた場合は誰も知らせてくれないので、毎フレームの同期で戻す
esc_setup({"a"})
check("開いている間は差し込み", escape_scp, "_nexus_addons_p_ESCAPE_PRESSED()")
frames["fa"] = nil -- × で閉じた
_nexus_addons_p_update_frames()
check("× で閉じても戻す", escape_scp, "")

-- ===== 18-3. ESCAPE_PRESSED を購読している側(indun_panel)への合図 =====
-- 常時表示のパネルはスタックに積めない(積むと ESC を常に横取りしてしまう)ので、
-- 「今回の押下は手前のウィンドウが使った」を g.esc_taken() で判断する。
-- ハンドラの呼ばれる順番はゲーム任せなので、前後どちらでも true になること。
print("[18-3] 手前にウィンドウがあるかの問い合わせ")
esc_setup({})
check("何も開いていなければ false", g.esc_taken(), false)
esc_setup({"a"})
check("開いていれば true（自分より後に閉じられる）", g.esc_taken(), true)
esc_press()
check("閉じた直後も true（自分より先に閉じられていた）", g.esc_taken(), true)
app_ms = app_ms + 1000
check("次の押下では false", g.esc_taken(), false)

-- 閉じるものが無かった押下は、ゲーム側／購読側へそのまま渡す
esc_setup({})
esc_press()
check("空振りの押下は使ったことにしない", g.esc_taken(), false)

-- ===== 18-4. 閉じ方の指定は「グローバル関数名」でも「関数そのもの」でもよい =====
-- 閉じる処理がフレームを引数に取るアドオンが多く、そのたびに引数無しのラッパを
-- グローバルへ足すと名前が増えるだけなので、無名関数を直接渡せるようにしてある。
print("[18-4] 閉じ方は関数名でも関数そのものでもよい")
esc_setup({})
do
    local called = 0
    frames["fclosure"] = new_frame("fclosure", 1)
    g.esc_register("fclosure", function()
        called = called + 1
        frames["fclosure"] = nil
    end)
    esc_press()
    check("関数そのものを渡しても閉じる", called, 1)
    check("閉じたら使った扱いになる", g.esc_taken(), true)
end

-- 短縮形。破棄するだけ / 隠すだけの窓はこの 2 つで足りる。
esc_setup({})
do
    destroyed = {}
    frames["fdestroy"] = new_frame("fdestroy", 1)
    g.esc_register_destroy("fdestroy")
    esc_press()
    check("esc_register_destroy は破棄する", destroyed[#destroyed], "fdestroy")
end
esc_setup({})
do
    local hidden = new_frame("fhide", 1)
    frames["fhide"] = hidden
    g.esc_register_hide("fhide")
    esc_press()
    check("esc_register_hide は隠す", hidden:IsVisible(), 0)
    check("破棄はしない", frames["fhide"] ~= nil, true)
end

-- ===== 18-4-2. 作り直す初期化関数から積むときは位置を動かさない =====
-- battle_ritual / muteki の設定画面は、スキルやバフを足すたびに初期化関数ごと呼び直される。
-- そこで esc_register を使うと**子の一覧を開いたまま親が最前面へ積み直され**、
-- ESC 1 回で親の close が走って子まで道連れになる(スタックが防ぐはずの挙動が出る)。
print("[18-4-2] esc_register_keep は既にある登録を動かさない")
esc_setup({"a"}) -- a = 親(設定画面)を先に開いた状態
do
    frames["fchild"] = new_frame("fchild", 1)
    g.esc_register("fchild", "esc_test_close_b") -- 子の一覧をその上に開く
    -- 親の初期化関数が呼び直された
    g.esc_register_keep("fa", "esc_test_close_a")
    esc_press()
    check("親を積み直さないので子が先に閉じる", table.concat(esc_closed, ","), "b")
    check("親はスタックに残る", #g.esc_stack, 1)
    -- 参考: esc_register だと親が手前へ来てしまう(この差が今回の不具合)
    esc_setup({"a"})
    frames["fchild"] = new_frame("fchild", 1)
    g.esc_register("fchild", "esc_test_close_b")
    g.esc_register("fa", "esc_test_close_a")
    esc_press()
    check("esc_register だと親が先に閉じる", table.concat(esc_closed, ","), "a")
end
-- 死んだ登録が下に沈んだまま残ると、esc_register_keep がそれを掴んで位置を据え置き、
-- **閉じた窓を開き直しても手前に来ない**。掃除は esc_top の役目(毎フレームの同期で走る)。
esc_setup({"a"}) -- a = 一覧(esc_register_keep で積む側)
do
    frames["fother"] = new_frame("fother", 1)
    g.esc_register("fother", "esc_test_close_b") -- 別の窓をその上に開く
    frames["fa"] = nil -- 一覧を × で閉じた(登録は fother の下に残る)
    check("死んだ登録は手前の生きた登録の下でも掃除する", (function()
        _nexus_addons_p_update_frames() -- 1 フレーム経過(esc_sync_scp -> esc_top)
        return #g.esc_stack
    end)(), 1)
    -- 一覧を開き直す
    frames["fa"] = new_frame("fa", 1)
    g.esc_register_keep("fa", "esc_test_close_a")
    esc_press()
    check("開き直した一覧が手前に来る", table.concat(esc_closed, ","), "a")
    esc_press()
    check("その下に別の窓が残っている", table.concat(esc_closed, ","), "a,b")
end

-- 閉じ方だけは最新に差し替える(作り直しで close の中身が変わってもよいように)
esc_setup({})
do
    local which = {}
    frames["fk"] = new_frame("fk", 1)
    g.esc_register("fk", function() which[#which + 1] = "old" end)
    g.esc_register_keep("fk", function()
        which[#which + 1] = "new"
        frames["fk"] = nil
    end)
    check("積み直さないので 1 件のまま", #g.esc_stack, 1)
    esc_press()
    check("閉じ方は新しい方を使う", table.concat(which, ","), "new")
end

-- ===== 18-5. Addons Menu 側(一覧と設定画面)を畳むのはスタックが空のときだけ =====
-- 先頭で無条件に呼んでいた頃は、手前の自作ウィンドウを閉じる押下で設定画面まで
-- 一緒に消えていた(「1 回の ESC でまとめて消える」を防ぐスタックがここだけ素通り)。
-- 逆に畳んだときは「使った」印を置かないと、閉じるのと同時にシステムメニューが開く。
print("[18-5] Addons Menu 側を畳むのはスタックが空のときだけ")
do
    local menu_calls, menu_closed = 0, false
    _G.addons_menu_on_escape = function()
        menu_calls = menu_calls + 1
        return menu_closed
    end

    esc_setup({"a"})
    menu_calls, menu_closed = 0, true
    esc_press()
    check("スタックが残っていれば呼ばない", menu_calls, 0)
    check("閉じたのは手前の 1 枚だけ", table.concat(esc_closed, ","), "a")

    esc_setup({})
    menu_calls, menu_closed = 0, true
    esc_press()
    check("スタックが空なら呼ぶ", menu_calls, 1)
    check("畳んだ押下は使った扱いにする", g.esc_taken(), true)

    esc_setup({})
    menu_calls, menu_closed = 0, false
    esc_press()
    check("何も畳めなければ呼びはする", menu_calls, 1)
    check("畳めなかった押下はゲームへ渡す", g.esc_taken(), false)

    _G.addons_menu_on_escape = nil
end

-- ===== 19. メッセージの多重配信 =====
-- addon:RegisterMsg は 1 メッセージ 1 ハンドラしか持てないので、購読を 1 本にまとめて
-- 配信役から配る。ここが壊れると「後から登録した側だけ動く」形で黙って機能が死ぬ。
-- （新しい local を増やしすぎないよう do ブロックに閉じる）
print("[19] 1 メッセージに複数のハンドラを配る")
do
    local registered = {}
    local function new_addon(tag)
        return {
            _tag = tag,
            RegisterMsg = function(self, msg, func_name)
                registered[#registered + 1] = {tag = self._tag, msg = msg, func = func_name}
            end
        }
    end
    -- 前の検査の登録を持ち越さない
    g.msg_handlers, g.msg_registered_cycle, g.msg_registered_addon, g.msg_failed = {}, {}, {}, {}
    g.addon = new_addon("A")
    local called = {}
    _G["Test_handler_1"] = function() called[#called + 1] = "1" end
    _G["Test_handler_2"] = function() called[#called + 1] = "2" end
    g.register_msg("TEST_MSG", "Test_handler_1")
    g.register_msg("TEST_MSG", "Test_handler_2")
    check("購読は 1 本だけ", #registered, 1)
    check("配信役の名前で登録する", registered[1].func, "_nexus_addons_p_msg_TEST_MSG")
    _G["_nexus_addons_p_msg_TEST_MSG"](nil, "TEST_MSG", "", 0)
    check("2 本とも呼ばれる", table.concat(called, ","), "1,2")
    g.register_msg("TEST_MSG", "Test_handler_1")
    check("同じハンドラは二重に足さない", #g.msg_handlers["TEST_MSG"], 2)

    -- 受けた引数は数を決め打ちせず、そのまま流す。ゲーム側には 5 個目以降を渡す
    -- メッセージがある(MON_MINIMAP の info など)。ここを 4 個で決め打ちすると、
    -- そこを使うハンドラが nil 参照で転び、pcall が握るので黙って機能だけ死ぬ。
    local got
    _G["Test_handler_1"] = function(...) got = {n = select("#", ...), ...} end
    _G["Test_handler_2"] = function() end
    local info = {handle = 7}
    _G["_nexus_addons_p_msg_TEST_MSG"]("FRAME", "TEST_MSG", "str", 3, info, "extra")
    check("引数の数を削らない", got.n, 6)
    check("5 個目(info)が届く", got[5] == info, true)
    check("6 個目も届く", got[6], "extra")
    _G["Test_handler_1"] = function() called[#called + 1] = "1" end
    _G["Test_handler_2"] = function() called[#called + 1] = "2" end

    -- 1 本が転んでも後続へ配る。報告は debug_log.txt にも出すが、毎フレーム来る経路
    -- (FPS_UPDATE)があるので同じ組では 1 回だけ。
    local logged = {}
    local real_log_to_file = g.log_to_file
    g.log_to_file = function(msg) logged[#logged + 1] = msg end
    called = {}
    _G["Test_handler_1"] = function() error("わざと落とす") end
    _G["_nexus_addons_p_msg_TEST_MSG"](nil, "TEST_MSG", "", 0)
    check("転んでも後続へ配る", table.concat(called, ","), "2")
    check("debug_log にも残す", #logged, 1)
    _G["_nexus_addons_p_msg_TEST_MSG"](nil, "TEST_MSG", "", 0)
    check("同じ失敗は繰り返し報告しない", #logged, 1)
    g.log_to_file = real_log_to_file

    -- ON_INIT のたびに購読を張り直す。addon が別物に差し替わっても届かせるため。
    registered = {}
    g.msg_registered_cycle = {} -- ON_INIT が空にする
    g.addon = new_addon("B")
    g.register_msg("TEST_MSG", "Test_handler_2")
    check("ON_INIT ごとに張り直す", #registered, 1)
    check("新しい addon で張る", registered[1].tag, "B")
    g.register_msg("TEST_MSG", "Test_handler_1")
    check("同じ ON_INIT の 2 回目は張らない", #registered, 1)

    -- 機能 OFF になったアドオンは自分のハンドラだけ外す
    check("外した本数", g.unregister_msg_by_prefix("Test_handler_"), 2)
    called = {}
    _G["_nexus_addons_p_msg_TEST_MSG"](nil, "TEST_MSG", "", 0)
    check("外した後は呼ばれない", #called, 0)
end

-- ===== 20. フックの張り直し =====
-- 同じグローバルに置換方式(g.setup_hook)とイベント方式(g.setup_hook_and_event)が
-- 乗ることがある。ON_INIT のたびに掛け直すと相手を落とすので、掛け直しは
-- 「知らない誰かに差し替えられていたとき」だけにしている。
print("[20] 置換方式とイベント方式が同じグローバルに乗っても潰し合わない")
do
    g.msg_handlers, g.msg_registered_cycle, g.msg_failed = {}, {}, {}
    g.REGISTER, g.FUNCS, g.ARGS = {}, {}, {}
    g.EVENT_HOOKS, g.EVENT_HOOK_BOOL, g.hook_owner, g.core_hooks = {}, {}, {}, {}
    -- 配信の回数だけ見たいので、ここでは数える版に差し替える
    -- (共用のスタブは imcAddOn:BroadMsg 形式で受けており、ここの呼び方とは引数がずれる)
    local real_broad_msg = imcAddOn.BroadMsg
    local broads = 0
    imcAddOn.BroadMsg = function() broads = broads + 1 end
    local vanilla_calls = 0
    _G["TEST_GLOBAL"] = function() vanilla_calls = vanilla_calls + 1 end
    g.setup_hook_and_event(g.addon, "TEST_GLOBAL", "Test_handler_2", true)
    local wrapper = _G["TEST_GLOBAL"]
    g.setup_hook_and_event(g.addon, "TEST_GLOBAL", "Test_handler_1", true)
    check("ラッパは作り直さない", _G["TEST_GLOBAL"] == wrapper, true)
    _G["TEST_GLOBAL"]()
    check("元の関数は 1 回だけ", vanilla_calls, 1)
    check("配信も 1 回だけ", broads, 1)
    imcAddOn.BroadMsg = real_broad_msg

    -- 置換方式を上から掛けたあと、イベント方式を掛け直しても落とさない
    local my_func = function() end
    g.setup_hook(my_func, "TEST_GLOBAL")
    check("置換方式が手前に入る", _G["TEST_GLOBAL"] == my_func, true)
    check("元の実体は控えから呼べる", g.FUNCS["TEST_GLOBAL"] == wrapper, true)
    g.setup_hook_and_event(g.addon, "TEST_GLOBAL", "Test_handler_2", true)
    check("イベント方式の掛け直しで落とさない", _G["TEST_GLOBAL"] == my_func, true)
    g.setup_hook(my_func, "TEST_GLOBAL")
    check("置換方式も入れ直さない", _G["TEST_GLOBAL"] == my_func, true)

    -- 知らない誰かに差し替えられていたら、連鎖が切れているので掛け直す
    local stranger = function() end
    _G["TEST_GLOBAL"] = stranger
    g.setup_hook_and_event(g.addon, "TEST_GLOBAL", "Test_handler_2", true)
    check("外れていたら掛け直す", _G["TEST_GLOBAL"] ~= stranger, true)

    -- 設定画面で OFF → ON とその場で戻したとき、購読が戻ること。
    -- setup_hook_and_event は「登録済み」印(g.REGISTER)で二重登録を弾くので、OFF で
    -- 外すときに印も落としておかないと、次のマップ移動まで購読が空のままになる。
    g.msg_handlers, g.REGISTER = {}, {}
    g.setup_hook_and_event(g.addon, "TEST_GLOBAL", "Test_handler_2", true)
    check("購読が入る", #g.msg_handlers["TEST_GLOBAL"], 1)
    g.unregister_msg_by_prefix("Test_handler_")
    check("OFF で外れる", #g.msg_handlers["TEST_GLOBAL"], 0)
    g.setup_hook_and_event(g.addon, "TEST_GLOBAL", "Test_handler_2", true)
    check("同じ ON_INIT のまま ON に戻しても購読が戻る", #g.msg_handlers["TEST_GLOBAL"], 1)
end

print("[21] 置換方式フック(g.setup_hook)の掛け直しと控えの取り方")
do
    g.FUNCS, g.hook_owner, g.core_hooks, g.EVENT_HOOKS, g.hook_captured = {}, {}, {}, {}, {}
    local vanilla = function() end
    local mine = function() end
    _G["TEST_HOOK_A"] = vanilla
    g.setup_hook(mine, "TEST_HOOK_A")
    check("掛かる", _G["TEST_HOOK_A"] == mine, true)
    check("元の実体を控える", g.FUNCS["TEST_HOOK_A"] == vanilla, true)

    -- 知らない誰かが連鎖しない形で差し替えたら、こちらの機能が死んでいるので掛け直す。
    -- 「掛け済みなら何もしない」で済ませると、セッション中ずっと外れたままになる。
    local stranger = function() end
    _G["TEST_HOOK_A"] = stranger
    g.setup_hook(mine, "TEST_HOOK_A")
    check("差し替えられていたら掛け直す", _G["TEST_HOOK_A"] == mine, true)
    check("控えは最初の実体のまま", g.FUNCS["TEST_HOOK_A"] == vanilla, true)

    -- 味方(同梱アドオンの置換フック)が自分より後に掛かって手前に居るときは触らない。
    -- 相手はこちらを呼ぶ形で連鎖しているので、掛け直すと相手を落としてしまう。
    local friend = function() end
    _G["TEST_HOOK_A"] = friend
    g.hook_owner_add("TEST_HOOK_A", friend) -- mine(先) の後に friend(後) が掛かった並び
    g.setup_hook(mine, "TEST_HOOK_A")
    check("後から掛けた味方が手前なら張り直さない", _G["TEST_HOOK_A"] == friend, true)

    -- 掛けようとしたグローバルが走っているクライアントに無い場合。控えは nil のままだが、
    -- 2 回目に**自分自身**を「元の関数」として控えてはいけない(呼ぶと無限再帰する)。
    _G["TEST_HOOK_MISSING"] = nil
    g.setup_hook(mine, "TEST_HOOK_MISSING")
    check("無いグローバルでも掛かる", _G["TEST_HOOK_MISSING"] == mine, true)
    check("控えは nil のまま", g.FUNCS["TEST_HOOK_MISSING"], nil)
    g.setup_hook(mine, "TEST_HOOK_MISSING")
    check("2 回目も自分を控えない", g.FUNCS["TEST_HOOK_MISSING"], nil)

    -- 同梱アドオン(mini_addons)は同じ実装へ自分の表と控えの名前だけ渡す。
    -- ここを共有すると、控えが相手のラッパを指して無限再帰する。
    local sub_funcs, sub_installed = {}, {}
    local sub_func = function() end
    _G["TEST_HOOK_B"] = vanilla
    g.setup_hook(sub_func, "TEST_HOOK_B",
        {installed = sub_installed, funcs = sub_funcs, prefix = "SUB", label = "sub"})
    check("同梱側の表に入る", sub_installed["TEST_HOOK_B"] == sub_func, true)
    check("まとめ版の表には入らない", g.core_hooks["TEST_HOOK_B"], nil)
    check("控えは呼び出し元の g.FUNCS へ", sub_funcs["TEST_HOOK_B"] == vanilla, true)
    check("まとめ版の g.FUNCS は汚さない", g.FUNCS["TEST_HOOK_B"], nil)
    check("控えのグローバル名が分かれる", _G["SUB_REPLACE_TEST_HOOK_B"] == vanilla, true)
    check("まとめ版へ味方だと伝える", g.hook_owner_index("TEST_HOOK_B", sub_func), 1)
end

-- 同じグローバルに味方が 2 つ乗り(まとめ版 + 同梱アドオン)、そのうえで知らない誰かが
-- 割り込んだあとの復帰。まとめ版が先・同梱が後(=手前)に掛けた状態で _G を第三者に
-- 差し替えられると、次の ON_INIT でまとめ版が先に復帰する。ここで hook_owner が単一
-- スロットだと、まとめ版で埋まって手前の同梱側が「味方が手前」と誤判定し張り直しを飛ばす
-- → 同梱側のフックがチェーンから外れて黙って死ぬ。並びで持てば防げることを固定する。
print("[21-2] 味方 2 つ + 第三者割り込みからの復帰で手前の味方を落とさない")
do
    g.FUNCS, g.hook_owner, g.core_hooks, g.EVENT_HOOKS, g.hook_captured = {}, {}, {}, {}, {}
    local vanilla = function() end
    local core_func = function() end -- まとめ版(先に掛ける=後ろ)
    local mini_func = function() end -- 同梱(後に掛ける=手前)
    local mini_funcs, mini_installed = {}, {}
    _G["CO_HOOK"] = vanilla
    -- 通常の連鎖: まとめ版 → 同梱 の順で掛かり、_G には手前の mini_func が入る
    g.setup_hook(core_func, "CO_HOOK")
    g.setup_hook(mini_func, "CO_HOOK",
        {installed = mini_installed, funcs = mini_funcs, prefix = "MINI", label = "mini"})
    check("手前は同梱側", _G["CO_HOOK"] == mini_func, true)

    -- 第三者が _G を差し替える(このアドオンが耐えたいまさにその状況)
    local stranger = function() end
    _G["CO_HOOK"] = stranger

    -- 次の ON_INIT。順序どおり、まず まとめ版が復帰(第三者を検出して掛け直す)
    g.setup_hook(core_func, "CO_HOOK")
    check("まとめ版が第三者を退けて復帰", _G["CO_HOOK"] == core_func, true)
    -- 続いて 同梱側。まとめ版で手前が埋まっていても、掛けた順(同梱が後)で見るので
    -- 「先に掛けた まとめ版が手前に居る=連鎖が壊れた」と分かり、正しく張り直す。
    g.setup_hook(mini_func, "CO_HOOK",
        {installed = mini_installed, funcs = mini_funcs, prefix = "MINI", label = "mini"})
    check("同梱側が手前へ復帰する(黙って死なない)", _G["CO_HOOK"] == mini_func, true)
    check("同梱の控えは まとめ版フックを指し連鎖が保たれる", mini_funcs["CO_HOOK"] == core_func, true)
end

-- ===== 22. map_has_keyword: トークン単位で当てる =====
-- Keyword は ";" 区切り。素の部分一致だと "WeeklyBossMapEntrance" のような別キーワードにも
-- 当たり、対象外のマップでアドオンが作動する(vakarine_equip が直したかったのがこれ)。
print("[22] map_has_keyword はトークン単位で当てる")
state.map_name = "raid1"
check("持っているキーワード", g.map_has_keyword("WeeklyBossMap"), true)
check("同じマップの別キーワード", g.map_has_keyword("RaidMap"), true)
check("持っていないキーワード", g.map_has_keyword("FieldMap"), false)
state.map_name = "tricky"
check("紛らわしい名前には当たらない", g.map_has_keyword("WeeklyBossMap"), false)
check("その名前そのものには当たる", g.map_has_keyword("NotWeeklyBossMap"), true)
-- 「該当しない(false)」と「判定できなかった(nil)」を混ぜないこと。混ぜると
-- 利用者の verbose_log.txt から「なぜ動かないのか」を切り分けられなくなる。
state.map_name = "unknown"
check("Map クラスを引けなければ nil", g.map_has_keyword("WeeklyBossMap"), nil)
state.getclass_calls = 0
g.map_has_keyword("WeeklyBossMap")
g.map_has_keyword("WeeklyBossMap")
check("引けないマップは毎回引き直す", state.getclass_calls, 2)
state.map_name = "raid1"
state.getclass_calls = 0
g.map_has_keyword("WeeklyBossMap")
g.map_has_keyword("RaidMap")
check("引けたマップはメモ化する", state.getclass_calls, 1)

-- ===== 23. OFF のアドオンは on_teardown へ振り分ける =====
-- 「OFF なら畳む」を各アドオンが手書きしていたため、守り漏れが実際に出ていた
-- (party_marker / boss_direction は OFF のままタイマーを回し続けていた)。
-- 振り分けは core の責任にし、on_teardown を定義したアドオンだけ opt-in で拾う。
print("[23] use==0 なら on_teardown を呼び、畳むのは 1 回だけ")
g.addon_torn_down = {}
g.settings = g.settings or {} -- ここまでの検査で差し替えられていることがある
g.settings.dummy_addon = {use = 0}
_G["dummy_addon_on_init"] = function() end
_G["dummy_addon_on_teardown"] = function() end
local picked, mode = _nexus_addons_p_resolve_init_func("dummy_addon")
check("OFF なら teardown を選ぶ", mode, "teardown")
check("選ばれたのは on_teardown", picked == _G["dummy_addon_on_teardown"], true)
local _, mode2 = _nexus_addons_p_resolve_init_func("dummy_addon")
-- マップ移動のたびに畳み直すと、OFF で固定している人の移動ごとに購読表の全走査が走る
check("2 度目は畳み直さない", mode2, "skip")
g.settings.dummy_addon.use = 1
local picked3, mode3 = _nexus_addons_p_resolve_init_func("dummy_addon")
check("ON に戻せば on_init", mode3, "init")
check("選ばれたのは on_init", picked3 == _G["dummy_addon_on_init"], true)
check("畳み済みの印が落ちる", g.addon_torn_down["dummy_addon"], nil)
g.settings.dummy_addon.use = 0
local _, mode4 = _nexus_addons_p_resolve_init_func("dummy_addon")
check("もう一度 OFF にすればまた畳む", mode4, "teardown")
-- on_teardown を持たないアドオン(OFF でもフックを張る必要がある側)は従来どおり
g.settings.legacy_addon = {use = 0}
_G["legacy_addon_on_init"] = function() end
local picked5, mode5 = _nexus_addons_p_resolve_init_func("legacy_addon")
check("teardown が無ければ OFF でも on_init", mode5, "init")
check("選ばれたのは on_init(legacy)", picked5 == _G["legacy_addon_on_init"], true)

-- ===== 24. 古い個別版の検出が、自分自身を誤検出しない =====
-- instant_cc は他アドオンとの連携用に _G["INSTANTCC_ON_INIT"] を自分で公開する。
-- 素で見ると自分を古い個別版と誤検出して、個別版を入れていないのに OFF にされる
-- (実機で発生。初回ロードでは未公開なので通り、キャラ切替の 2 回目で踏む)。
print("[24] 古い個別版の検出が自分自身を誤検出しない")
_G["FOO_ON_INIT"] = nil
check("グローバルが無ければ検出しない", _nexus_addons_p_origin_addon_present("FOO_ON_INIT"), false)
_G["FOO_ON_INIT"] = function() end
check("グローバルが在れば検出する", _nexus_addons_p_origin_addon_present("FOO_ON_INIT"), true)
check("名前が空なら検出しない", _nexus_addons_p_origin_addon_present(""), false)
check("名前が nil でも落ちない", _nexus_addons_p_origin_addon_present(nil), false)
_G["INSTANTCC_ON_INIT"] = function() end
_G["instant_cc_on_init"] = nil
check("INSTANTCC: 自分が居なければ個別版とみなす", _nexus_addons_p_origin_addon_present("INSTANTCC_ON_INIT"), true)
_G["instant_cc_on_init"] = function() end
check("INSTANTCC: 自分が居れば誤検出しない", _nexus_addons_p_origin_addon_present("INSTANTCC_ON_INIT"), false)

-- ===== 25. mini_addons の断片が manifest に期待どおりの順で並んでいる =====
-- mini_addons は機能ごとの断片に分かれていて、**実行順を決めるのは manifest だけ**
-- (ファイル名に数字を振っていないので、並びを目視で確かめられない)。
-- 断片をまたいで共有しているトップレベルの local は、宣言より前へ利用側を動かすと
-- グローバル読み(= nil)に化ける。**エラーにならず静かに壊れる**ので、ここで並びを固定する。
-- 意図して並べ替えたときは、この一覧も一緒に直すこと。
print("[25] mini_addons 断片の並び")
local MINI_PREFIX = "addons/mini_addons/"
local MINI_EXPECTED = {
    "mini_addons.lua",
    "settings/definitions.lua",
    "settings/ui.lua",
    "settings/storage.lua",
    "lifecycle/init.lua",
    "misc/ui_tweaks.lua",
    "lifecycle/update.lua",
    "chat/chat_system.lua",
    "misc/frame_tweaks.lua",
    "quest/quest.lua",
    "event_notice/reward_token.lua",
    "chat/chat_frame.lua",
    "inventory/inventory_op_pop.lua",
    "weekly_boss/reward_partial.lua",
    "misc/skill_enchant_tooltip.lua",
    "chat/group_chat.lua",
    "weekly_boss/ranking.lua",
    "misc/craft.lua",
    "party/member_map.lua",
    "chat/death_notice.lua",
    "quest/token_warp.lua",
    "context_menu/context_menu.lua",
    "event_notice/notice_msg.lua",
    "misc/fps_option.lua",
    "weekly_boss/rank_memberinfo.lua",
    "hair_enchant/core.lua",
    "hair_enchant/window.lua",
    "hair_enchant/run.lua",
    "skill_reroll/core.lua",
    "skill_reroll/window.lua",
    "skill_reroll/run.lua",
    "chat/chat_move.lua",
    "misc/vakarine_notice.lua",
    "sound/skill_sound.lua",
    "misc/coin_shop.lua",
    "misc/indun_enter.lua",
    "buff_list/buff_list.lua",
    "channel/channel_traffic.lua",
    "inventory/ikor_search.lua",
    "event_notice/event_shout.lua",
    "misc/equip_upgrade.lua",
    "misc/market_sell.lua",
    "misc/raid_record.lua",
    "misc/effect_settings.lua",
    "misc/indun_dialog.lua",
    "misc/duel_and_restart.lua",
    "misc/dialog.lua",
    "misc/pc_name.lua",
    "misc/auto_casting.lua",
    "channel/channel_frame.lua",
    "misc/pet_and_relic.lua",
    "party/party_info.lua",
    "misc/reputation_shop.lua",
    "weekly_boss/reward_auto.lua",
    "misc/ragana.lua",
    "misc/rp_check.lua",
    "misc/market_button.lua",
    "inventory/coin_auto_use.lua",
    "misc/skill_enchant_auto.lua",
    "misc/goddess_gacha.lua",
    "sound/bgm.lua",
    "misc/minimized_close.lua",
    "sound/toggle.lua",
    "misc/reroll_option.lua",
    "inventory/inventory_open.lua",
    "footer.lua"
}

local manifest_f = assert(io.open("nexus_addons_p/src/build_manifest.json", "rb"),
    "読めない（リポジトリルートから実行すること）: nexus_addons_p/src/build_manifest.json")
local manifest_src = manifest_f:read("*a")
manifest_f:close()

-- JSON パーサを持ち込まずに、引用符で囲まれた .lua の相対パスを出現順に拾う
-- （targets の配列は文字列の並びしか持たない）。
--
-- **拾う範囲は targets 配列の中だけに絞ること。** manifest 全体を舐めると、将来
-- targets が 2 つ以上になったときに別ターゲットの分まで混ざり、件数も「連続して
-- いるか」も実体と無関係に落ちる。%b{} / %b[] で対応する括弧まで切り出す。
local targets_obj = manifest_src:match('"targets"%s*:%s*(%b{})')
check("targets を切り出せる", targets_obj ~= nil, true)
local mini_parts, first_at, last_at, arrays_with_mini = {}, nil, nil, 0
for array in (targets_obj or ""):gmatch("%b[]") do
    local found, f_at, l_at = {}, nil, nil
    local i = 0
    for rel in array:gmatch('"([^"]+%.lua)"') do
        i = i + 1
        if rel:sub(1, #MINI_PREFIX) == MINI_PREFIX then
            table.insert(found, rel:sub(#MINI_PREFIX + 1))
            f_at = f_at or i
            l_at = i
        end
    end
    if #found > 0 then
        arrays_with_mini = arrays_with_mini + 1
        mini_parts, first_at, last_at = found, f_at, l_at
    end
end
-- 断片が複数のターゲットへ散ると、どちらの並びを見ているのか分からなくなる。
check("断片を含む targets は 1 つ", arrays_with_mini, 1)
check("断片の数", #mini_parts, #MINI_EXPECTED)
-- 間に他アドオンが挟まると、共有している local の見え方が変わる。連続していること。
check("連続して並んでいる", (last_at or 0) - (first_at or 0) + 1, #mini_parts)
local order_ng = nil
for i, want in ipairs(MINI_EXPECTED) do
    if mini_parts[i] ~= want then
        order_ng = string.format("%d 番目: got=%s want=%s", i, tostring(mini_parts[i]), want)
        break
    end
end
check("並びが期待どおり", order_ng, nil)
-- 先頭と末尾は入れ替えてはいけない（先頭が do と共有 local、末尾が end）。
check("先頭はヘッダ", mini_parts[1], "mini_addons.lua")
check("末尾は footer", mini_parts[#mini_parts], "footer.lua")
-- 一覧に載っているだけで実体が無いと、bundle 生成が落ちるまで気付けない。
local missing = nil
for _, rel in ipairs(MINI_EXPECTED) do
    local path = "nexus_addons_p/src/" .. MINI_PREFIX .. rel
    local fh = io.open(path, "rb")
    if fh then
        fh:close()
    else
        missing = rel
        break
    end
end
check("全ての断片が実在する", missing, nil)
-- 断片のあるフォルダには README を置く（Issue #69）。増やしたときの置き忘れを止める。
local no_readme = nil
for _, rel in ipairs(MINI_EXPECTED) do
    local dir = rel:match("^(.*)/[^/]+$")
    if dir then
        local fh = io.open("nexus_addons_p/src/" .. MINI_PREFIX .. dir .. "/README.md", "rb")
        if fh then
            fh:close()
        else
            no_readme = dir
            break
        end
    end
end
check("各フォルダに README がある", no_readme, nil)

-- ===== 26. 一覧のカテゴリ =====
-- 各エントリの category は g._nexus_addons_p_sections の見出しを指す。指していないと
-- そのアドオンは末尾の その他 へ落ちる（_nexus_addons_p_list_build がそう作ってある）。
-- 実機では「なぜかその他に居る」という形でしか出ず気付けないので、ここで落とす。
print("[26] 一覧のカテゴリが見出しと対応している")
local section_names = {}
local section_order = {}
for _, section in ipairs(g._nexus_addons_p_sections) do
    check("見出しに name がある: " .. tostring(section.name), type(section.name), "string")
    -- 表示言語ごとの文言。1 つでも欠けるとその言語だけ見出しが nil になる
    -- （list_localized は素の nil を返し、呼び元が section.name で代替する）。
    for _, lang_key in ipairs({"ja", "kr", "etc"}) do
        check("  " .. section.name .. " の " .. lang_key, type(section[lang_key]), "string")
    end
    section_names[section.name] = true
    section_order[#section_order + 1] = section.name
end
-- その他 は「category を書き忘れたエントリ」の受け皿でもあるので必ず要る。
check("受け皿の misc がある", section_names["misc"], true)
check("misc は末尾に置く", section_order[#section_order], "misc")

local no_category, bad_category = nil, nil
local per_section = {}
for _, entry in ipairs(g._nexus_addons_p) do
    if type(entry.category) ~= "string" then
        no_category = no_category or entry.key
    elseif not section_names[entry.category] then
        bad_category = bad_category or (entry.key .. " -> " .. entry.category)
    else
        per_section[entry.category] = (per_section[entry.category] or 0) + 1
    end
end
check("category を書き忘れたエントリが無い", no_category, nil)
check("見出しに無い category を指すエントリが無い", bad_category, nil)
-- 使われていない見出しは、見出しだけが出て中身が空になる…のではなく
-- （#items > 0 のときだけ描くので）静かに消える。綴り違いの取り違えを拾うために見る。
local unused_section = nil
for _, name in ipairs(section_order) do
    if not per_section[name] then
        unused_section = name
        break
    end
end
check("どの見出しにも 1 件以上ある", unused_section, nil)

-- ===== 27. README のアドオン一覧が registry と一致している =====
-- 利用者向けの README とゲーム内の一覧で分類が食い違っていたので、registry 側へ揃えた。
-- 手で並べ直す限り必ずまた離れる（実際に Market Favorite Rebuild が README から
-- 丸ごと抜けていた）ので、ここで突き合わせる。README を直すか registry を直すかは
-- そのときの判断だが、**片方だけ変えた状態はここで落ちる**。
print("[27] README のアドオン一覧が registry と一致する")
local readme = assert(io.open("nexus_addons_p/README.md", "rb"), "README.md が開けない")
local readme_text = readme:read("*a")
readme:close()

-- 「## アドオン一覧」から次の「## 」までを切り出す（使い方側の ### を拾わないため）
local list_body = readme_text:match("\n## アドオン一覧\n(.-)\n## ")
check("アドオン一覧の節を切り出せる", list_body ~= nil, true)

local rd_section_order, rd_of, rd_rows = {}, {}, {}
if list_body then
    local cur = nil
    for line in list_body:gmatch("[^\n]+") do
        local heading = line:match("^### (.+)$")
        if heading then
            cur = heading
            rd_section_order[#rd_section_order + 1] = heading
            rd_rows[heading] = {}
        else
            local label, key = line:match("^| %[([^%]]+)%]%(src/addons/([a-z_]+)/README%.md%)")
            if key then
                rd_of[key] = cur
                if cur then
                    table.insert(rd_rows[cur], {key = key, label = label})
                end
            end
        end
    end
end

-- 見出しの並びと文言が g._nexus_addons_p_sections と揃っているか
local ja_of, expected_headings = {}, {}
for _, section in ipairs(g._nexus_addons_p_sections) do
    ja_of[section.name] = section.ja
    expected_headings[#expected_headings + 1] = section.ja
end
check("見出しの数が同じ", #rd_section_order, #expected_headings)
local heading_ng = nil
for i, want in ipairs(expected_headings) do
    if rd_section_order[i] ~= want then
        heading_ng = string.format("%d 番目: README=%s registry=%s", i, tostring(rd_section_order[i]), want)
        break
    end
end
check("見出しの文言と並びが同じ", heading_ng, nil)

-- 登録済みのアドオンが、自分の category の見出しの下に居るか
local not_listed, wrong_section = nil, nil
local listed_keys = {}
for _, entry in ipairs(g._nexus_addons_p) do
    listed_keys[entry.key] = true
    local want = ja_of[entry.category]
    if not rd_of[entry.key] then
        not_listed = not_listed or entry.key
    elseif rd_of[entry.key] ~= want then
        wrong_section = wrong_section or
                            string.format("%s: README=%s registry=%s", entry.key, rd_of[entry.key], tostring(want))
    end
end
check("README に載っていない登録が無い", not_listed, nil)
check("README の節が category と食い違わない", wrong_section, nil)

-- 逆向き。登録していないのに載っているものは、無効と分かる形で その他 に置く。
-- 増やすときはここへ足すこと（黙って通すと「一覧に在るのに ON にできない」になる）。
local UNREGISTERED_OK = {
    ancient_monster_bookshelf = "未完成のため登録をコメントアウトしてある"
}
local stray = nil
for key, section in pairs(rd_of) do
    if not listed_keys[key] then
        if not UNREGISTERED_OK[key] then
            stray = key
        elseif section ~= ja_of["misc"] then
            stray = key .. "(未登録なので " .. tostring(ja_of["misc"]) .. " へ置くこと)"
        end
    end
end
check("未登録のアドオンが紛れていない", stray, nil)

-- 並び順。README には「並び順はゲーム内のアドオン一覧ウィンドウと同じ」と書いてあり、
-- ゲーム内は _nexus_addons_p_list_build がカテゴリ内をアドオン名で並べ替えている。
-- 表示名は README のリンク文字列と同じなので、そこを名前順に見るだけで突き合わせられる。
local order_ng = nil
for _, heading in ipairs(rd_section_order) do
    local rows = rd_rows[heading] or {}
    for i = 2, #rows do
        if string.lower(rows[i - 1].label) > string.lower(rows[i].label) then
            order_ng = string.format("%s: %s の後に %s", heading, rows[i - 1].label, rows[i].label)
            break
        end
    end
    if order_ng then
        break
    end
end
check("カテゴリの中がアドオン名順に並んでいる", order_ng, nil)

-- ===== 28. 初期化スロットルの正規化 =====
-- 設定画面から入る数値で、利用者が settings.json を手で書き換えることもできる。
-- **件数が 0 以下になる経路を残さないこと。** _nexus_addons_p_async_safe_call の while は
-- 1 件処理してから件数を見るので 0 でも進みはするが、時間予算も 0 になると 1 tick で
-- 1 件しか進まず、初期化が終わるまで何十秒もかかる状態になる。
print("[28] init_throttle は範囲外・数字以外を正す")
local batch, budget = g.init_throttle(g.INIT_BATCH_DEFAULT)
check("推奨値はそのまま", batch, g.INIT_BATCH_DEFAULT)
check("推奨値の時間予算", budget, 12)
check("下限より小さい値", (g.init_throttle(0)), g.INIT_BATCH_MIN)
check("負数", (g.init_throttle(-5)), g.INIT_BATCH_MIN)
check("上限より大きい値", (g.init_throttle(999)), g.INIT_BATCH_MAX)
check("小数は切り捨て", (g.init_throttle(4.9)), 4)
check("数字でない", (g.init_throttle("abc")), g.INIT_BATCH_DEFAULT)
check("未設定", (g.init_throttle(nil)), g.INIT_BATCH_DEFAULT)
local _, min_budget = g.init_throttle(g.INIT_BATCH_MIN)
local _, max_budget = g.init_throttle(g.INIT_BATCH_MAX)
check("時間予算は 6ms を下回らない", min_budget, 6)
-- 上限は 60fps の 1 フレーム分。素のクライアントには「1 フレームの時間予算」という
-- 考え方が無く、意図して 1 フレーム以上を使う処理も無い（g.init_throttle のコメント）。
check("時間予算の上限は 1 フレーム分", g.INIT_TIME_LIMIT_MAX, 16)
check("時間予算は上限で頭打ち", max_budget, g.INIT_TIME_LIMIT_MAX)
local _, mid_budget = g.init_throttle(4)
check("上限に届かない件数はそのまま伸びる", mid_budget, 12)

-- 設定画面に出す目安の秒数。tick 間隔 × 必要な tick 数（端数は切り上げ）。
check("51 個 / 1 件は従来と同じ約 2.55 秒", g.init_estimate_sec(51, 1), 51 * g.INIT_TICK_SEC)
check("51 個 / 4 件は 13 tick", g.init_estimate_sec(51, 4), 13 * g.INIT_TICK_SEC)
check("端数は切り上げる", g.init_estimate_sec(9, 4), 3 * g.INIT_TICK_SEC)
check("0 件なら 0 秒", g.init_estimate_sec(0, 4), 0)

-- ===== 29. 更新のお知らせ（NEW / 更新 の印） =====
-- 版の比較と印の判定は純ロジックなのでここで検査できる。**実機でしか確かめられない
-- 部分（帯の高さ・窓の中身）とは分けてある**ので、少なくとも「いつ出るか」は機械で守る。
print("[29] ver_cmp と badge_of")
check("同じ版", g.ver_cmp("2.1.0", "2.1.0"), 0)
check("桁が違っても比べられる", g.ver_cmp("2.1", "2.1.0"), 0)
check("小さい", g.ver_cmp("2.0.9", "2.1.0"), -1)
check("大きい", g.ver_cmp("2.1.1", "2.1.0"), 1)
check("10 は 9 より大きい（文字列比較になっていない）", g.ver_cmp("2.10.0", "2.9.0"), 1)
-- 未採番の印。main へ入れる PR では版を上げないので、開発中の since / updated はこれになる。
check("next はどの版より新しい", g.ver_cmp(g.VER_NEXT, "99.0.0"), 1)
check("next 同士は同じ", g.ver_cmp(g.VER_NEXT, g.VER_NEXT), 0)
-- 設定ファイルは手で書き換えられる。数字が無い値で比較が壊れないこと。
check("nil は 0.0.0 扱い", g.ver_cmp(nil, "0.0.0"), 0)
check("数字でない値も 0.0.0 扱い", g.ver_cmp("abc", "0.0.1"), -1)

local saved_settings = g.settings
g.settings = {seen_ver = "2.1.0"}
check("印が無い定義には何も出さない", g.badge_of({}), nil)
check("新しい since は NEW", g.badge_of({since = "2.2.0"}), "new")
check("知っている版の since は出さない", g.badge_of({since = "2.1.0"}), nil)
check("新しい updated は 更新", g.badge_of({updated = "2.2.0"}), "upd")
check("知っている版の updated は出さない", g.badge_of({updated = "2.0.0"}), nil)
-- 追加した版で中身も直したときに両方出ると読み手が混乱するので NEW を優先する。
check("NEW と 更新 が重なったら NEW", g.badge_of({since = "2.2.0", updated = "2.2.0"}), "new")
check("定義でないものを渡しても落ちない", g.badge_of(nil), nil)
-- **seen_ver が無いとき（既に使っている人が更新した直後）は印を出す。**
-- ここで「知っている」扱いにすると、印を導入した版の新着が誰にも出なくなる。
g.settings = {}
check("seen_ver が無ければ since は出す", g.badge_of({since = "2.0.0"}), "new")

-- 行の中身（Mini Addons の設定項目）の新着を、行の印へ集約する。
-- **一覧しか見ていない人に伝える唯一の経路**なので、集約の規則をここで守る。
g.settings = {seen_ver = "2.1.0"}
local mini = {key = "mini_addons"}
g.badge_children["mini_addons"] = {{name = "a", text_jp = "あ"}, {name = "b", text_jp = "い", updated = "2.2.0"},
                                   {name = "c", text_jp = "う", since = "2.2.0"}}
local row_badge, row_count = g.badge_row(mini)
check("子に新着があれば行にも出す", row_badge, "new")
check("新着の件数を数える", row_count, 2)
-- 子に NEW と Update が混ざったら NEW（g.badge_of と同じ「増えたほうを見せる」規則）
g.badge_children["mini_addons"] = {{name = "b", text_jp = "い", updated = "2.2.0"}}
check("子が Update だけなら Update", (g.badge_row(mini)), "upd")
g.badge_children["mini_addons"] = {{name = "a", text_jp = "あ"}}
check("子に新着が無ければ出さない", (g.badge_row(mini)), nil)
-- 行そのものの印が優先。件数は 0（子から来た印のときだけ件数を出すため）
g.badge_children["mini_addons"] = {{name = "b", text_jp = "い", updated = "2.2.0"}}
local own_badge, own_count = g.badge_row({key = "mini_addons", since = "2.2.0"})
check("行そのものの印が優先", own_badge, "new")
check("行そのものの印なら件数は 0", own_count, 0)
-- 子を預けていない行（大多数のアドオン）で落ちないこと
check("子を預けていない行", (g.badge_row({key = "no_such_addon"})), nil)
g.badge_children["mini_addons"] = nil
g.settings = saved_settings

if failures > 0 then
    print(string.format("FAILED: %d 件", failures))
    os.exit(1)
end
print("ALL OK")
