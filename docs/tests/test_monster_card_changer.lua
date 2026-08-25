-- monster_card_changer の「適用するプリセットの組み立て」を luajit 上で検査する（ゲーム不要）。
--
-- 実機でしか出ないわりに壊れ方が分かりにくい 2 点を押さえる。
--
--   1. **空き枠を詰めないこと**。素の CARD_PRESET_GET_CARD_EXP_LIST と同じで、リストの
--      位置がそのままスロット番号になる（0-2=赤 / 3-5=青 / 6-8=紫 / 9-11=緑）。
--      詰めると後ろのカードが前の色の枠へずれ込み、**紫のカードが赤の枠に入る**。
--   2. **保護色の枠には今装備しているカードを書き戻すこと**。SCR_TX_APPLY_CARD_PRESET は
--      12 枠を丸ごと差し替える命令なので、外す側のリストを絞るだけでは保護色まで外れる。
--      利用者からは「チェックの有無に関係なく全部外れる」という形で出ていた。
--
-- 使い方（リポジトリルートから）:
--     luajit docs/tests/test_monster_card_changer.lua

local PARTS = {"nexus_addons_p/src/core/00_header.lua",
               "nexus_addons_p/src/addons/monster_card_changer/monster_card_changer.lua"}

-- ===== ゲーム API のスタブ =====
package.preload["json"] = function()
    return {
        encode = function()
            return ""
        end,
        decode = function()
            return {}
        end
    }
end

local real_io_open = io.open
io.open = function(path, mode, ...)
    -- ../addons/** はリポジトリの外なので触らせない。
    if type(path) == "string" and path:find("addons", 1, true) then
        return nil
    end
    return real_io_open(path, mode, ...)
end
os.execute = function()
    return 0
end

session = {
    GetMapName = function()
        return "town"
    end,
    GetMySession = function()
        return {
            GetCID = function()
                return 1
            end
        }
    end
}
function GetClass()
    return nil
end
function TryGetProp(_, _, default)
    return default
end
ui = {
    GetFrame = function()
        return nil
    end,
    SysMsg = function()
    end,
    SetEscapeScp = function()
    end
}
function AUTO_CAST(x)
    return x
end
option = {
    GetCurrentCountry = function()
        return "Japanese"
    end
}
imcTime = {
    GetAppTimeMS = function()
        return 0
    end,
    GetAppTime = function()
        return 0
    end
}
-- カードレベルは exp から引き直す作りなので、prop を引けない環境では 0 が返る。
-- 本テストが見るのは組み立ての位置と保護なので、これで足りる。
geItemTable = {
    GetProp = function()
        return nil
    end
}
table.unpack = table.unpack or unpack

local chunks = {}
for _, rel in ipairs(PARTS) do
    local f = assert(real_io_open(rel, "rb"), "読めない（リポジトリルートから実行すること）: " .. rel)
    chunks[#chunks + 1] = f:read("*a")
    f:close()
end
assert(load(table.concat(chunks, "\n"), "=core"))()

local g = _G["ADDONS"]["norisan"]["_NEXUS_ADDONS_P"]
g.active_id = "TESTAID"
g.login_name = "TESTCHAR"
g.save_json = function()
end

local failures = 0
local function check(label, got, want)
    if got ~= want then
        failures = failures + 1
        print(string.format("  NG  %s: got=%s want=%s", label, tostring(got), tostring(want)))
    else
        print(string.format("  ok  %s = %s", label, tostring(got)))
    end
end

-- 今装備しているカード（スロット 0〜11）。GETMYCARD_INFO のスタブが返す。
local equipped = {}
function GETMYCARD_INFO(slot_index)
    local e = equipped[slot_index + 1]
    if not e then
        return 0, 0, 0
    end
    return e[1], e[2], e[3]
end

-- 設定を組み立てる。slots は {[枠番号] = ClassID} で指定する。
local function make_settings(slots, protect)
    local presets = {}
    for i = 1, 10 do
        local s = {}
        for j = 1, 12 do
            s[j] = {
                card_id = 0,
                card_exp = 0,
                card_lv = 0
            }
        end
        presets[i] = {
            name = "preset" .. i,
            slots = s
        }
    end
    for slot_no, cls_id in pairs(slots or {}) do
        presets[2].slots[slot_no].card_id = cls_id
        presets[2].slots[slot_no].card_exp = cls_id * 10
    end
    g.monster_card_changer_settings = {
        presets = presets,
        [g.login_name] = protect or {}
    }
end

local function concat(list)
    local out = {}
    for i = 1, 12 do
        out[i] = tostring(list[i])
    end
    return table.concat(out, ",")
end

print("[1] 空き枠を詰めない（紫が赤の枠へずれ込まない）")
-- 赤(1-3)は空、青(4-6)に 1 枚、紫(7-9)に 2 枚。詰めると青のカードが赤の 1 枠目へ来る。
make_settings({
    [4] = 501,
    [7] = 701,
    [8] = 702
})
local card_list, exp_list = Monster_card_changer_build_preset("equip", 1)
check("要素数", #card_list, 12)
check("並び", concat(card_list), "0,0,0,501,0,0,701,702,0,0,0,0")
check("赤の 1 枠目は空のまま", card_list[1], 0)
check("青の 1 枠目にだけ青のカード", card_list[4], 501)
check("exp も同じ位置", exp_list[4], 5010)

print("[2] 全枠空のプリセットでも 12 要素になる")
make_settings({})
card_list = Monster_card_changer_build_preset("equip", 1)
check("要素数", #card_list, 12)
check("並び", concat(card_list), "0,0,0,0,0,0,0,0,0,0,0,0")

print("[3] REMOVE は保護色以外を空にする")
-- 赤を保護。今は 12 枠すべてに何か着いている。
equipped = {}
for i = 1, 12 do
    equipped[i] = {1000 + i, 1, (1000 + i) * 10}
end
make_settings({}, {
    red = 1,
    blue = 0,
    purple = 0,
    green = 0
})
card_list, exp_list = Monster_card_changer_build_preset("remove")
check("赤は今の装備を書き戻す", concat(card_list),
    "1001,1002,1003,0,0,0,0,0,0,0,0,0")
check("赤の exp も書き戻す", exp_list[2], 10020)

print("[4] EQUIP は保護色の枠を上書きしない")
make_settings({
    [1] = 601,
    [2] = 602,
    [4] = 604,
    [7] = 607
}, {
    red = 1,
    blue = 0,
    purple = 0,
    green = 0
})
card_list = Monster_card_changer_build_preset("equip", 1)
check("赤は今の装備のまま / 青と紫はプリセットの内容", concat(card_list),
    "1001,1002,1003,604,0,0,607,0,0,0,0,0")

print("[5] 保護していなければ今の装備は無視してプリセットの内容になる")
make_settings({
    [1] = 601
}, {
    red = 0,
    blue = 0,
    purple = 0,
    green = 0
})
card_list = Monster_card_changer_build_preset("equip", 1)
check("並び", concat(card_list), "601,0,0,0,0,0,0,0,0,0,0,0")

print("[6] 色の設定が無いキャラでも保護なし扱いで落ちない")
make_settings({
    [1] = 601
}, nil)
card_list = Monster_card_changer_build_preset("equip", 1)
check("並び", concat(card_list), "601,0,0,0,0,0,0,0,0,0,0,0")
check("色設定が 0 で埋まる", g.monster_card_changer_settings[g.login_name].purple, 0)

print("[7] 枠と色の対応（3 枠ずつ赤・青・紫・緑）")
check("枠1", g.monster_card_changer_slot_colors[1], "red")
check("枠4", g.monster_card_changer_slot_colors[4], "blue")
check("枠7", g.monster_card_changer_slot_colors[7], "purple")
check("枠10", g.monster_card_changer_slot_colors[10], "green")

print("[8] 書き込み確認は slot_idx で突き合わせる（詰まった応答を通さない）")
local preset_info
equipcard = {
    GetCardPresetInfo = function()
        return preset_info
    end
}
local function fake_info(entries)
    return {
        Count = function()
            return #entries
        end,
        Element = function(_, i)
            return entries[i + 1]
        end
    }
end
local want = {0, 0, 0, 501, 0, 0, 701, 0, 0, 0, 0, 0}
preset_info = fake_info({{
    slot_idx = 4,
    class_id = 501
}, {
    slot_idx = 7,
    class_id = 701
}})
check("位置が合っていれば一致", Monster_card_changer_preset_matches(want), true)
preset_info = fake_info({{
    slot_idx = 1,
    class_id = 501
}, {
    slot_idx = 2,
    class_id = 701
}})
check("詰まった応答は不一致", Monster_card_changer_preset_matches(want), false)
preset_info = fake_info({{
    slot_idx = 4,
    class_id = 501
}})
check("足りない応答は不一致", Monster_card_changer_preset_matches(want), false)
preset_info = nil
check("全枠空を書いたなら nil でも一致", Monster_card_changer_preset_matches({0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}),
    true)
check("中身があるのに nil なら不一致", Monster_card_changer_preset_matches(want), false)

if failures > 0 then
    print(string.format("FAILED: %d 件", failures))
    os.exit(1)
end
print("ALL OK")
