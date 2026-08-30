-- my_buffs_control の「バフ表は非表示リスト」を luajit 上で検査する（ゲーム不要）。
--
-- 表は **載っていない = 表示** の非表示リストで、.dat に書くのは非表示(0)だけ。
-- 以前は「== 1 なら表示」の許可リストで、表示するバフ全部を持つ必要があり、
-- .dat が実測 3816 行 / 40KB あった。壊れると次の形で出る。
--
--   1. **表示のバフを表へ書き戻すと**、許可リストへ逆戻りして .dat が再び膨らむ
--   2. **許可リスト時代の「非表示」は 0 の行ではなく「行が無いこと」**（v2.2.1 の
--      My_buffs_control_buff_toggle は非表示に nil を入れ、書き出しは nil の行を書かない）。
--      0 の行だけ拾う移行にすると、利用者が隠したバフを一件残らず捨てることになる
--   3. **移行が 1 回で終わらないと**、毎回読み捨てるだけで .dat がいつまでも縮まない
--   4. **ver を上げて移行すると**、settings ごと既定値へ差し替わって窓位置まで初期化される
--
-- 使い方（リポジトリルートから）:
--     luajit docs/tests/test_my_buffs_control.lua

local PARTS = {"nexus_addons_p/src/core/00_header.lua",
               "nexus_addons_p/src/addons/my_buffs_control/my_buffs_control.lua"}

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

-- .dat だけは中身を差し替えられる疑似ファイルにする（リポジトリの外は触らせない）
local fake_dat = nil
local written = nil
io.open = function(path, mode, ...)
    if type(path) == "string" and path:find("my_buffs_control.dat", 1, true) then
        if mode == "r" then
            if not fake_dat then
                return nil
            end
            local rest = fake_dat
            return {
                lines = function()
                    return function()
                        if rest == "" then
                            return nil
                        end
                        local line, tail = rest:match("^([^\n]*)\n?(.*)$")
                        rest = tail
                        if line == "" and tail == "" then
                            return nil
                        end
                        return line
                    end
                end,
                close = function()
                end
            }
        end
        written = ""
        return {
            write = function(_, s)
                written = written .. s
            end,
            close = function()
                fake_dat = written
            end
        }
    end
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
-- 移行は GetClassList("Buff") を舐めて「表示に載っていないバフ」を拾う。
-- デバフを 1 件混ぜて、設定の対象外が拾われないことも見る。
local BUFF_CLASSES = {{ClassID = 100, Group1 = "Buff"}, {ClassID = 200, Group1 = "Buff"},
                      {ClassID = 300, Group1 = "Buff"}, {ClassID = 400, Group1 = "Buff"},
                      {ClassID = 500, Group1 = "Buff"}, {ClassID = 600, Group1 = "Buff"},
                      {ClassID = 700, Group1 = "Debuff"}}
function GetClassList()
    return "BUFFLIST", #BUFF_CLASSES
end
function GetClassByIndexFromList(_, i)
    return BUFF_CLASSES[i + 1]
end
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
local fake_json = nil
g.load_json = function()
    return fake_json
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

-- .dat の行順は pairs の走査順そのままで保証が無い。**完全一致で比べないこと。**
-- 実装が正しいのに luajit のビルド差で CI が落ちる。並べ替えて集合として比べる
local function dat_set(text)
    local ids = {}
    for line in tostring(text or ""):gmatch("[^\n]+") do
        ids[#ids + 1] = line
    end
    table.sort(ids)
    return table.concat(ids, ",")
end

local function count(tbl)
    local n = 0
    for _ in pairs(tbl) do
        n = n + 1
    end
    return n
end

local function fresh_json()
    return {
        ver = 1.2,
        lock = false,
        default_x = 111,
        default_y = 222,
        custom_x = 333,
        custom_y = 444
    }
end

-- ===== 1. 許可リスト時代（v2.2.1）の .dat からの移行 =====
-- **非表示(200 / 400)は行そのものが無い**のが当時の形。700 はデバフなので対象外
print("[1] 許可リストの .dat から移行する")
fake_json = fresh_json()
fake_dat = "100:::1\n300:::1\n500:::1\n600:::1"
g.my_buffs_control_settings = nil
My_buffs_control_load_settings()
local buffs = g.my_buffs_control_settings.buffs
check("表に残るのは非表示のぶんだけ", count(buffs), 2)
check("隠したバフ 200（行が無かった）を拾えている", buffs["200"], 0)
check("隠したバフ 400（行が無かった）を拾えている", buffs["400"], 0)
check("表示のバフ 100 は表に載らない", buffs["100"], nil)
check("デバフ 700 は拾わない", buffs["700"], nil)
check(".dat も非表示だけになった", dat_set(fake_dat), "200:::0,400:::0")
-- **窓の位置と固定設定を初期化しないこと**（ver を上げると既定へ差し替わる）
check("lock を初期化していない", g.my_buffs_control_settings.lock, false)
check("窓の位置を初期化していない", g.my_buffs_control_settings.custom_x, 333)

-- ===== 2. 移行は 1 回で終わる =====
print("[2] 移行済みの .dat をもう一度読む")
local before = fake_dat
g.my_buffs_control_settings = nil
My_buffs_control_load_settings()
check("表の件数は変わらない", count(g.my_buffs_control_settings.buffs), 2)
check(".dat も変わらない", dat_set(fake_dat), dat_set(before))

-- ===== 3. トグル：表示へ戻すと行ごと消える =====
print("[3] チェックの ON / OFF")
local function toggle(id, checked)
    My_buffs_control_buff_toggle(nil, {
        IsChecked = function()
            return checked
        end
    }, id)
end
toggle("200", 1) -- 表示へ戻す
check("表示へ戻したら表から消える", g.my_buffs_control_settings.buffs["200"], nil)
check(".dat からも消える", dat_set(fake_dat), "400:::0")
toggle("600", 0) -- 新しく隠す
check("隠したら 0 で載る", g.my_buffs_control_settings.buffs["600"], 0)
check(".dat に 2 件", dat_set(fake_dat), "400:::0,600:::0")

-- ===== 4. 0 の行と 1 の行が混ざった .dat =====
-- 中間の dev ビルドを通した .dat がこの形になる。
-- 0 の行はそのまま採用し、載っていないバフも非表示として拾う
print("[4] 0 と 1 が混ざった .dat")
fake_json = fresh_json()
fake_dat = "100:::0\n300:::1\n500:::1\n600:::1"
g.my_buffs_control_settings = nil
My_buffs_control_load_settings()
check("0 の行はそのまま残る", g.my_buffs_control_settings.buffs["100"], 0)
check("行が無い 200 / 400 も拾う", dat_set(fake_dat), "100:::0,200:::0,400:::0")

-- ===== 5. 初回インストール（.dat も json も無い） =====
print("[5] 初回インストール")
fake_json = nil
fake_dat = nil
g.my_buffs_control_settings = nil
My_buffs_control_load_settings()
check("表は空（= 全部表示）", count(g.my_buffs_control_settings.buffs), 0)

if failures > 0 then
    print(string.format("FAILED: %d 件", failures))
    os.exit(1)
end
print("ALL OK")
