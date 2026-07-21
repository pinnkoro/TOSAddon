-- core の純ロジックを luajit 上で検査する（ゲーム不要）。
--
-- 対象は「ゲーム API をスタブに差し替えれば単体で動かせる」部分に限る。
-- ここでは g.get_map_type() のメモ化と、FPS_UPDATE から毎フレーム呼ばれる
-- _nexus_addons_p_update_frames() の表示判定を見る。どちらも実機でしか確認できないと
-- 壊しても気付けないため、最低限の回帰テストとして置いている。
--
-- 使い方（リポジトリルートから）:
--     luajit docs/tests/test_core.lua
--
-- core/*.lua は単体では完結せず、bundle と同じく 1 チャンクに連結して初めて
-- チャンクローカル(g / addon_name_lower)が共有される。そのため下でも連結して読む。

local CORE_PARTS = {
    "nexus_addons_p/src/core/00_header.lua",
    "nexus_addons_p/src/core/20_lifecycle.lua",
}

-- ===== ゲーム API のスタブ =====
package.preload["json"] = function()
    return {encode = function() return "" end, decode = function() return {} end}
end

local state = {map_name = "town", getclass_calls = 0}
local MAP_TYPES = {town = "City", field1 = "Field", raid1 = "Instance"} -- "unknown" は未登録

session = {
    GetMapName = function() return state.map_name end,
    GetMapID = function() return 1 end,
    GetMySession = function() return {GetCID = function() return 1 end} end,
}

function GetClass(_kind, name)
    state.getclass_calls = state.getclass_calls + 1
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

ui = {GetFrame = function(name) return frames[name] end}
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

-- ===== 2. get_map_type: 同一マップではメモ化される =====
print("[2] 同一マップでの GetClass 呼び出し回数")
for _, map in ipairs({"field1", "unknown"}) do
    state.map_name = map
    g.get_map_type() -- ここで 1 回引かせる
    state.getclass_calls = 0
    for _ = 1, 5 do g.get_map_type() end
    check(map .. " を5回引いたときの GetClass 回数", state.getclass_calls, 0)
end

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

if failures > 0 then
    print(string.format("FAILED: %d 件", failures))
    os.exit(1)
end
print("ALL OK")
