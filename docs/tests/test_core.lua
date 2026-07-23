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
-- ../addons/_nexus_addons_p/<AID>/ 配下を xcopy で丸ごと運ぶ。ファイル名を列挙できない
-- （Lua にディレクトリ列挙が無い）ので、settings.json 以外も確実に運べているかを見る。
print("[16] 設定のバックアップと復元")
local vfs = {} -- path -> 中身（文字列）
local vfs_json = {} -- g.save_json/g.load_json 側の実体
local xcopy_works = true
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
local prev_os_execute = os.execute
os.execute = function(cmd)
    local src, dst = cmd:match('^xcopy "([^"]+)" "([^"]+)"')
    if not src then
        return prev_os_execute(cmd)
    end
    if not xcopy_works then
        return 1
    end
    src, dst = src:gsub("\\", "/"), dst:gsub("\\", "/")
    local copied = {}
    for path, content in pairs(vfs) do -- 走査中に書き込まない（新しいキーの追加は未定義動作）
        if path:sub(1, #src + 1) == src .. "/" then
            copied[dst .. path:sub(#src + 1)] = content
        end
    end
    for path, content in pairs(copied) do
        vfs[path] = content
    end
    return 0
end
-- コピー先の settings.json を脇へ退かす／戻す経路で使う
local prev_os_remove, prev_os_rename = os.remove, os.rename
os.remove = function(path)
    if type(path) ~= "string" or not path:find("^%.%./addons/") then
        return prev_os_remove(path)
    end
    if vfs[path] == nil then
        return nil, path .. ": No such file or directory"
    end
    vfs[path], vfs_json[path] = nil, nil
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
g.save_json = function(path, tbl) vfs_json[path] = tbl; vfs[path] = "{json}"; return true end
g.load_json = function(path) return vfs_json[path] end

g.active_id = "1234567"
local paths = g.backup_paths()
-- バックアップ先が AID フォルダの中だと、自分自身をバックアップし続けることになる
check("退避先は AID フォルダの外", paths.backup:find(paths.live .. "/", 1, true), nil)

local function reset_live()
    vfs, vfs_json = {}, {}
    vfs[paths.live .. "/settings.json"] = "LIVE-SETTINGS"
    vfs[paths.live .. "/always_status/settings.json"] = "LIVE-ALWAYS-STATUS"
    vfs[paths.live .. "/monster_kill_count/1001.json"] = "LIVE-KILL-COUNT"
end

reset_live()
check("バックアップが無ければ nil", g.backup_info(), nil)
check("バックアップが無ければ復元しない", (select(2, g.restore_settings())), "no_source")

check("バックアップできる", g.backup_settings(), true)
check("settings.json が入る", vfs[paths.backup .. "/settings.json"], "LIVE-SETTINGS")
check("各アドオンの設定も入る", vfs[paths.backup .. "/always_status/settings.json"], "LIVE-ALWAYS-STATUS")
check("可変名のファイルも入る", vfs[paths.backup .. "/monster_kill_count/1001.json"], "LIVE-KILL-COUNT")
local info = g.backup_info()
check("取得日時を記録する", type(info and info.time), "string")
-- 日時のファイルは退避先の *外*。中に置くと復元時に live 側へ紛れ込む
check("日時は退避先の外に置く", paths.info:find(paths.backup .. "/", 1, true), nil)

-- 復元は上書き。バックアップ後に増えたファイルは消さない（消す方向の同期はしない）
vfs[paths.live .. "/settings.json"] = "BROKEN"
vfs[paths.live .. "/after_backup.json"] = "NEW"
check("復元できる", g.restore_settings(), true)
check("設定が戻る", vfs[paths.live .. "/settings.json"], "LIVE-SETTINGS")
check("バックアップ後のファイルは消さない", vfs[paths.live .. "/after_backup.json"], "NEW")
check("日時のファイルは live へ入らない", vfs[paths.live .. "/" .. g.active_id .. "_info.json"], nil)

-- xcopy が使えない環境では、最低限 settings.json（= 各アドオンの ON/OFF）だけ運ぶ
reset_live()
xcopy_works = false
local ok_partial, kind = g.backup_settings()
check("xcopy が失敗しても運ぶ", ok_partial, true)
check("部分的だと分かる", kind, "partial")
check("settings.json は入る", vfs[paths.backup .. "/settings.json"], "LIVE-SETTINGS")
check("他のファイルは入らない", vfs[paths.backup .. "/monster_kill_count/1001.json"], nil)
xcopy_works = true

-- コピー先に前回の settings.json が残っていても xcopy の失敗を見落とさない。
-- 成否は「コピー先に settings.json が *出来たか*」で見るので、古いファイルを残したまま
-- 判定すると、それを掴んで成功に見えてしまう（フォールバックにも入らない）。
reset_live()
check("1 回目のバックアップ", g.backup_settings(), true)
vfs[paths.live .. "/settings.json"] = "NEWER-SETTINGS"
xcopy_works = false
local ok_again, kind_again = g.backup_settings()
check("前回の退避が残っていても成否を誤らない", kind_again, "partial")
check("再バックアップも運べる", ok_again, true)
check("中身は新しい方に入れ替わる", vfs[paths.backup .. "/settings.json"], "NEWER-SETTINGS")
check("退かしたファイルは残さない", vfs[paths.backup .. "/settings.json.old"], nil)

-- xcopy もフォールバックも失敗したときは、退かした設定を元へ戻す。
-- 復元に失敗したうえにユーザーの現設定まで消える方が悪い。
local prev_copy_file = g.copy_file
g.copy_file = function() return false end
local ok_failed, kind_failed = g.restore_settings()
check("どちらも失敗すれば失敗を返す", ok_failed, false)
check("失敗の理由が分かる", kind_failed, "failed")
check("復元先の設定は消さない", vfs[paths.live .. "/settings.json"], "NEWER-SETTINGS")
check("退かしたファイルは残さない(失敗時)", vfs[paths.live .. "/settings.json.old"], nil)
g.copy_file = prev_copy_file
xcopy_works = true

-- AID が未取得（ON_INIT 前）でも落ちない
g.active_id = nil
check("AID 前でもパスは nil", g.backup_paths(), nil)
check("AID 前のバックアップは失敗", g.backup_settings(), false)
check("AID 前の復元は失敗", g.restore_settings(), false)
check("AID 前の情報取得は nil", g.backup_info(), nil)

io.open, os.execute = prev_io_open, prev_os_execute
os.remove, os.rename = prev_os_remove, prev_os_rename
g.settings = saved_settings

if failures > 0 then
    print(string.format("FAILED: %d 件", failures))
    os.exit(1)
end
print("ALL OK")
