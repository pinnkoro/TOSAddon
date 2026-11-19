-- Boss Action Monitor ここから
--
-- ボスの行動を HP と残り時間で前もって知らせる。設定はボス(モンスターの ClassName)ごと。
--   HP   … 「HP 50% でシールド」のように登録。ボスの HP がその割合を下回ったら 1 回知らせる
--   時間 … 「残り 4:30 でシールド」のように登録。その N 秒前と、その時点で知らせる
--
-- 時間の基準は 2 つ。
--   * レイドタイマー(素の raid_timer)が動いているコンテンツでは、その残り時間に合わせる。
--     素の RAID_TIMER_UPDATE(set_time, remain_time) にイベント方式(素を先に呼ぶ)で相乗りする
--   * 動いていないときは、HUD の ▶ で自分のカウントダウン(ボスごとの「手動タイマーの長さ」)を始める
--
-- weizlogy さんの HP Monitor(ボスの HP で PT チャットを出すアドオン)と同じ目的のものを
-- 時間の知らせと合わせて作り直した。HP Monitor にはライセンスの表記が無いので、コードは流用していない。
--
-- **bundle の local は 200 個が上限なので、このファイルではトップレベルの local を作らない。**
-- 定数は g.bam_* に置く。

g.bam_hud_name = addon_name_lower .. "boss_action_monitor_hud"
g.bam_setting_name = addon_name_lower .. "boss_action_monitor_setting"
g.bam_max_bosses = 30
g.bam_max_rows = 15
-- 敵を探す範囲。boss_direction(500)より広めにとる(レイドのボスは間合いが広い)。
g.bam_scan_range = 800
-- レイドタイマーが最後に届いてから、この間はレイドタイマーを基準にする(手動タイマーより優先)。
g.bam_raid_fresh_ms = 3000
-- 残り時間が一度にこれより大きく減ったら(読み込み画面など)、過ぎた知らせは出さない。
g.bam_time_catchup = 10
-- 入力欄の自動保存の予約の通し番号(続けて打たれたぶんの古い予約を捨てるため)。
g.bam_typing_seq = 0

function Boss_action_monitor_t(ja, en)
    return g.lang == "Japanese" and ja or en
end

-- ===== 純ロジック(docs/tests/test_boss_action_monitor.lua で見る) =====

-- "4:30" / "04:30" / "270" を秒へ。読めなければ nil。
function g.bam_parse_time(text)
    text = string.gsub(tostring(text or ""), "%s", "")
    local m, s = string.match(text, "^(%d+):(%d+)$")
    if m then
        m, s = tonumber(m), tonumber(s)
        if s >= 60 then
            return nil
        end
        return m * 60 + s
    end
    local n = string.match(text, "^(%d+)$")
    return n and tonumber(n) or nil
end

function g.bam_fmt_time(sec)
    sec = math.max(0, math.floor(tonumber(sec) or 0))
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

function g.bam_clamp(v, lo, hi, default)
    v = tonumber(v)
    if not v then
        return default
    end
    if v < lo then
        return lo
    elseif v > hi then
        return hi
    end
    return v
end

-- 1 体ぶんの設定を、壊れていても使える形へ揃える(手で JSON を書き換えられても落ちないように)。
function g.bam_normalize_boss(b)
    b.cls = tostring(b.cls or "")
    b.name = type(b.name) == "string" and b.name or b.cls
    b.map = type(b.map) == "string" and b.map or ""
    b.duration = math.floor(g.bam_clamp(b.duration, 0, 7200, 0))
    if type(b.hp) ~= "table" then
        b.hp = {}
    end
    if type(b.time) ~= "table" then
        b.time = {}
    end
    for _, t in ipairs(b.hp) do
        t.on = t.on ~= false
        t.pct = math.floor(g.bam_clamp(t.pct, 1, 99, 50))
        t.text = type(t.text) == "string" and t.text or ""
    end
    for _, t in ipairs(b.time) do
        t.on = t.on ~= false
        t.at = math.floor(g.bam_clamp(t.at, 0, 7200, 0))
        t.before = math.floor(g.bam_clamp(t.before, 0, 600, 0))
        t.text = type(t.text) == "string" and t.text or ""
    end
    return b
end

-- 時間の知らせ。残り時間が prev から now へ減ったときに、跨いだものを返す。
-- 返すのは {trig = 件, kind = "before"(N 秒前) / "at"(その時点)} の並び。
-- 前回が無い・残り時間が増えた(タイマーが出直した)・大きく飛んだときは何も返さない。
function g.bam_time_due(triggers, prev, now)
    local result = {}
    if not prev or not now or now >= prev or prev - now > g.bam_time_catchup then
        return result
    end
    for _, t in ipairs(triggers or {}) do
        if t.on ~= false then
            if t.before > 0 then
                local x = t.at + t.before
                if prev > x and x >= now then
                    result[#result + 1] = {trig = t, kind = "before"}
                end
            end
            if prev > t.at and t.at >= now then
                result[#result + 1] = {trig = t, kind = "at"}
            end
        end
    end
    return result
end

-- HP の知らせ。state はボス 1 体(ハンドル)ごとの「もう出した」印({[件] = true})。
-- **初めて見たボスでは、もう下回っている件を黙って出したことにする**(途中から入ったときや、
-- 設定を開き直したときに、過ぎた知らせをまとめて出さない)。
function g.bam_hp_due(triggers, state, hp_pct)
    local result = {}
    local first = not state.seen
    state.seen = true
    for _, t in ipairs(triggers or {}) do
        if t.on ~= false and not state[t] and hp_pct <= t.pct then
            state[t] = true
            if not first then
                result[#result + 1] = {trig = t, kind = "hp"}
            end
        end
    end
    return result
end

-- 残り時間 remain より後に来る、いちばん近い件(HUD の「次」)。無ければ nil。
function g.bam_next_time(triggers, remain)
    local best
    for _, t in ipairs(triggers or {}) do
        if t.on ~= false and t.at < remain and (not best or t.at > best.at) then
            best = t
        end
    end
    return best
end

-- ===== 設定 =====

function Boss_action_monitor_save_settings()
    g.save_json(g.bam_path, g.bam_settings)
end

function Boss_action_monitor_load_settings()
    g.bam_path = string.format("../addons/%s/%s/boss_action_monitor.json", addon_name_lower, g.active_id)
    local settings = g.load_json(g.bam_path)
    if type(settings) ~= "table" then
        settings = {}
    end
    if settings.nicochat == nil then
        settings.nicochat = true
    end
    if settings.ptchat == nil then
        settings.ptchat = false
    end
    if settings.sound == nil then
        settings.sound = true
    end
    if settings.hud == nil then
        settings.hud = true
    end
    settings.x = tonumber(settings.x) or 400
    settings.y = tonumber(settings.y) or 200
    if type(settings.bosses) ~= "table" then
        settings.bosses = {}
    end
    for _, b in ipairs(settings.bosses) do
        g.bam_normalize_boss(b)
    end
    g.bam_settings = settings
    Boss_action_monitor_save_settings()
end

function Boss_action_monitor_find(cls)
    for i, b in ipairs(g.bam_settings.bosses) do
        if b.cls == cls then
            return b, i
        end
    end
    return nil
end

-- ===== 初期化 =====

function boss_action_monitor_on_init()
    if not g.bam_settings then
        Boss_action_monitor_load_settings()
    end
    -- マップが変わったら、そのマップで見たボス・HP の印・手動タイマーを捨てる。
    if g.bam_map ~= g.map_id then
        g.bam_map = g.map_id
        g.bam_seen = {}
        g.bam_hp_state = {}
        g.bam_active_cls = nil
        g.bam_hp_now = nil
        g.bam_manual = nil
        g.bam_raid = nil
        g.bam_prev_remain = nil
        g.bam_prev_source = nil
    end
    g.setup_hook_and_event(g.addon, "RAID_TIMER_UPDATE", "Boss_action_monitor_RAID_TIMER_UPDATE", true)
    if g.get_map_type() == "City" then
        g.vlog("boss_action_monitor: 街なので監視しない (map=%s stopped=%s)", tostring(g.map_name),
            tostring(g.stop_timer("boss_action_monitor_timer")))
        Boss_action_monitor_hud_close()
        return
    end
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    if _nexus_addons_p then
        _nexus_addons_p:SetVisible(1)
        local timer = _nexus_addons_p:CreateOrGetControl("timer", "boss_action_monitor_timer", 0, 0)
        AUTO_CAST(timer)
        timer:SetUpdateScript("Boss_action_monitor_tick")
        timer:Start(0.5)
    end
    g.vlog("boss_action_monitor: 監視を開始 map=%s 登録 %d 体 このマップに登録=%d", tostring(g.map_name),
        #g.bam_settings.bosses, #Boss_action_monitor_map_bosses())
end

-- OFF にされたときの後始末。**一度も ON にしていない利用者にも 1 回呼ばれる**ので、
-- 自分で作ったもの(HUD・タイマー)があるときだけ片付ける(どちらも無ければ何も起きない)。
function boss_action_monitor_on_teardown()
    if not g.bam_settings then
        Boss_action_monitor_load_settings()
    end
    g.stop_timer("boss_action_monitor_timer")
    Boss_action_monitor_hud_close()
end

-- 今のマップで登録したボス(マップを登録してあるもの)。
function Boss_action_monitor_map_bosses()
    local result = {}
    for _, b in ipairs(g.bam_settings.bosses) do
        if b.map ~= "" and b.map == g.map_name then
            result[#result + 1] = b
        end
    end
    return result
end

-- 時間の知らせを見るボス。このマップで姿を見たもの + このマップを登録してあるもの。
-- (レイドタイマーはボスが出る前から動くので、マップの登録でも拾えるようにしている)
function Boss_action_monitor_active_bosses()
    local result = {}
    for _, b in ipairs(g.bam_settings.bosses) do
        if (g.bam_seen and g.bam_seen[b.cls]) or (b.map ~= "" and b.map == g.map_name) then
            result[#result + 1] = b
        end
    end
    return result
end

-- HUD に出すボス。直近に姿を見たもの、無ければこのマップを登録してある最初のもの。
function Boss_action_monitor_hud_boss()
    if g.bam_active_cls then
        local b = Boss_action_monitor_find(g.bam_active_cls)
        if b then
            return b
        end
    end
    return Boss_action_monitor_map_bosses()[1]
end

function Boss_action_monitor_raid_fresh()
    return g.bam_raid ~= nil and imcTime.GetAppTimeMS() - g.bam_raid.at_ms <= g.bam_raid_fresh_ms
end

-- ===== 監視 =====

-- 素の RAID_TIMER_UPDATE(set_time, remain_time) の後に呼ばれる。
function Boss_action_monitor_RAID_TIMER_UPDATE(my_frame, my_msg)
    if g.settings.boss_action_monitor.use ~= 1 or not g.bam_settings then
        return
    end
    local set_time, remain = g.get_event_args(my_msg)
    remain = tonumber(remain)
    if not remain then
        return
    end
    if not g.bam_raid then
        g.vlog("boss_action_monitor: レイドタイマーを受け取った set=%s remain=%s map=%s", tostring(set_time),
            tostring(remain), tostring(g.map_name))
    end
    g.bam_raid = {
        remain = remain,
        set = tonumber(set_time),
        at_ms = imcTime.GetAppTimeMS()
    }
    -- レイドタイマーが来たら手動タイマーは要らない(二重に知らせない)。
    if g.bam_manual then
        g.vlog("boss_action_monitor: レイドタイマーが来たので手動タイマーを止める")
        g.bam_manual = nil
    end
    Boss_action_monitor_time_step(remain, "raid")
    Boss_action_monitor_hud_update()
end

-- 残り時間を 1 歩進め、跨いだ知らせを出す。source が変わったら(手動 → レイドなど)前回を捨てる。
function Boss_action_monitor_time_step(remain, source)
    local prev = g.bam_prev_remain
    if g.bam_prev_source ~= source then
        prev = nil
    end
    g.bam_prev_remain = remain
    g.bam_prev_source = source
    if prev == remain then
        return
    end
    for _, b in ipairs(Boss_action_monitor_active_bosses()) do
        for _, d in ipairs(g.bam_time_due(b.time, prev, remain)) do
            g.vlog("boss_action_monitor: 時間 %s %s at=%d before=%d 前回=%s 今=%d (%s)", b.cls, d.kind, d.trig.at,
                d.trig.before, tostring(prev), remain, source)
            Boss_action_monitor_notify(b, d)
        end
    end
end

-- 0.5 秒ごと。近くの登録ボスの HP を見て、手動タイマーを進める。
function Boss_action_monitor_tick(_nexus_addons_p, timer)
    if g.settings.boss_action_monitor.use ~= 1 then
        boss_action_monitor_on_teardown()
        return
    end
    if #g.bam_settings.bosses > 0 then
        Boss_action_monitor_scan()
    end
    if g.bam_manual and not Boss_action_monitor_raid_fresh() then
        local elapsed = math.floor((imcTime.GetAppTimeMS() - g.bam_manual.start_ms) / 1000)
        local remain = g.bam_manual.duration - elapsed
        if remain < 0 then
            g.vlog("boss_action_monitor: 手動タイマーが 0 になった")
            g.bam_manual = nil
        else
            Boss_action_monitor_time_step(remain, "manual")
        end
    end
    Boss_action_monitor_hud_update()
end

function Boss_action_monitor_scan()
    local objects, count = SelectObject(GetMyPCObject(), g.bam_scan_range, "ENEMY")
    for i = 1, count or 0 do
        local handle = GetHandle(objects[i])
        local cls = info.GetMonsterClassName(handle)
        local b = cls and Boss_action_monitor_find(cls)
        if b then
            local target_info = info.GetTargetInfo(handle)
            local stat = target_info and target_info.stat
            -- 倒した後(HP 0)は見ない。見ると残りの件が全部まとめて出る。
            if stat and stat.maxHP and stat.maxHP > 0 and stat.HP > 0 then
                if not g.bam_seen[cls] then
                    g.bam_seen[cls] = true
                    g.vlog("boss_action_monitor: 登録ボスを見つけた %s handle=%d HP=%.1f%%", cls, handle,
                        stat.HP / stat.maxHP * 100)
                end
                g.bam_active_cls = cls
                local pct = stat.HP / stat.maxHP * 100
                g.bam_hp_now = pct
                local state = g.bam_hp_state[handle]
                if not state then
                    state = {}
                    g.bam_hp_state[handle] = state
                end
                for _, d in ipairs(g.bam_hp_due(b.hp, state, pct)) do
                    g.vlog("boss_action_monitor: HP %s pct=%d 今=%.1f%%", cls, d.trig.pct, pct)
                    Boss_action_monitor_notify(b, d, pct)
                end
            end
        end
    end
end

-- ===== 知らせ =====

function Boss_action_monitor_message(b, d)
    local t = d.trig
    local label = (t.text ~= "" and t.text) or b.name
    if d.kind == "hp" then
        return string.format("%s (HP %d%%)", label, t.pct)
    elseif d.kind == "before" then
        return string.format(Boss_action_monitor_t("%s あと%d秒 (残り %s)", "%s in %ds (at %s)"), label, t.before,
            g.bam_fmt_time(t.at))
    end
    return string.format(Boss_action_monitor_t("%s (残り %s)", "%s now (at %s)"), label, g.bam_fmt_time(t.at))
end

function Boss_action_monitor_notify(b, d)
    local msg = Boss_action_monitor_message(b, d)
    -- チャット欄には必ず残す(ニコチャットは流れて消えるので、見逃したときの控え)。
    CHAT_SYSTEM(msg)
    if g.bam_settings.nicochat then
        Boss_action_monitor_nico_chat("{@st55_a}" .. msg)
    end
    if g.bam_settings.ptchat then
        _UI_CHAT("/p " .. msg)
    end
    if g.bam_settings.sound then
        imcSound.PlaySoundEvent("button_click_stats_up")
    end
end

function Boss_action_monitor_nico_chat(msg)
    local nico_chat = ui.GetFrame("nico_chat")
    if not nico_chat then
        return
    end
    local x = ui.GetClientInitialWidth()
    local y = ui.GetClientInitialHeight() * 0.5
    change_client_size(nico_chat)
    local name = UI_EFFECT_GET_NAME(nico_chat, "NICO_")
    local nico_text = nico_chat:CreateControl("richtext", name, x, y, 200, 20)
    AUTO_CAST(nico_text)
    nico_chat:SetLayerLevel(90)
    nico_chat:ShowWindow(1)
    nico_text:EnableResizeByText(1)
    nico_text:SetText(msg)
    nico_text:RunUpdateScript("NICO_MOVING")
    nico_text:SetUserValue("NICO_SPD", -150)
    nico_text:SetUserValue("NICO_START_X", x)
    nico_text:ShowWindow(1)
    nico_chat:RunUpdateScript("INVALIDATE_NICO")
end

-- ===== HUD =====
-- 登録したボスが居る(または登録したマップに居る)ときだけ出す。
-- 残り時間・HP・次の時間の知らせと、手動タイマーの ▶ / ■ を持つ。
-- HUD なので ESC のスタックには積まない(UI_RULES.md)。

function Boss_action_monitor_hud_close()
    local hud = ui.GetFrame(g.bam_hud_name)
    if hud then
        hud:ShowWindow(0)
    end
end

function Boss_action_monitor_hud_update()
    local b = g.bam_settings.hud and Boss_action_monitor_hud_boss()
    if not b then
        Boss_action_monitor_hud_close()
        return
    end
    local hud = ui.GetFrame(g.bam_hud_name)
    if not hud then
        hud = ui.CreateNewFrame("notice_on_pc", g.bam_hud_name, 0, 0, 0, 0)
        AUTO_CAST(hud)
        hud:SetSkinName("bg2")
        hud:SetLayerLevel(61)
        hud:Resize(230, 104)
        hud:SetPos(g.bam_settings.x, g.bam_settings.y)
        hud:EnableHittestFrame(1)
        hud:EnableMove(1)
        hud:SetEventScript(ui.LBUTTONUP, "Boss_action_monitor_hud_end_drag")
        local start = hud:CreateOrGetControl("button", "start", 186, 8, 36, 30)
        AUTO_CAST(start)
        start:SetEventScript(ui.LBUTTONUP, "Boss_action_monitor_manual_toggle")
        for _, n in ipairs({"name", "remain", "hp", "next"}) do
            hud:CreateOrGetControl("richtext", n, 10, 0, 170, 20)
        end
        g.vlog("boss_action_monitor: HUD を作った (%s)", b.cls)
    end
    AUTO_CAST(hud)
    local name = GET_CHILD(hud, "name")
    name:SetOffset(10, 8)
    name:SetText("{ol}{s14}" .. b.name)
    local remain_text = GET_CHILD(hud, "remain")
    remain_text:SetOffset(10, 28)
    local start = GET_CHILD(hud, "start")
    AUTO_CAST(start)
    local remain
    if Boss_action_monitor_raid_fresh() then
        remain = g.bam_raid.remain
        remain_text:SetText("{ol}{s18}" .. g.bam_fmt_time(remain) .. "{/}{s13} " ..
                                Boss_action_monitor_t("レイド", "Raid"))
        start:ShowWindow(0)
    elseif g.bam_manual then
        remain = g.bam_prev_remain
        remain_text:SetText("{ol}{s18}" .. g.bam_fmt_time(remain) .. "{/}{s13} " ..
                                Boss_action_monitor_t("手動", "Manual"))
        start:ShowWindow(1)
        start:SetText("{ol}■")
    else
        remain_text:SetText("{ol}{s18}--:--")
        start:ShowWindow(1)
        start:SetText("{ol}▶")
    end
    local hp = GET_CHILD(hud, "hp")
    hp:SetOffset(10, 54)
    if g.bam_active_cls == b.cls and g.bam_hp_now then
        hp:SetText(string.format("{ol}{s14}HP %.1f%%", g.bam_hp_now))
    else
        hp:SetText("{ol}{s14}HP --")
    end
    local next_text = GET_CHILD(hud, "next")
    next_text:SetOffset(10, 76)
    local nt = remain and g.bam_next_time(b.time, remain)
    if nt then
        next_text:SetText(string.format("{ol}{s14}{#FFD700}%s %s %s", Boss_action_monitor_t("次:", "Next:"),
            g.bam_fmt_time(nt.at), (nt.text ~= "" and nt.text) or ""))
    else
        next_text:SetText("")
    end
    if hud:IsVisible() == 0 then
        hud:ShowWindow(1)
    end
end

function Boss_action_monitor_hud_end_drag(frame)
    g.bam_settings.x = frame:GetX()
    g.bam_settings.y = frame:GetY()
    Boss_action_monitor_save_settings()
end

-- HUD の ▶ / ■。手動タイマーの長さは HUD に出ているボスのもの。
function Boss_action_monitor_manual_toggle()
    if g.bam_manual then
        g.bam_manual = nil
        g.bam_prev_remain = nil
        g.vlog("boss_action_monitor: 手動タイマーを止めた")
    else
        local b = Boss_action_monitor_hud_boss()
        if not b or b.duration <= 0 then
            ui.SysMsg(Boss_action_monitor_t("設定画面でこのボスの「手動タイマーの長さ」を入れてください",
                "Set this boss's \"Manual timer length\" in the settings first"))
            return
        end
        g.bam_manual = {
            start_ms = imcTime.GetAppTimeMS(),
            duration = b.duration
        }
        g.bam_prev_remain = nil
        g.bam_prev_source = nil
        Boss_action_monitor_time_step(b.duration, "manual")
        g.vlog("boss_action_monitor: 手動タイマーを開始 %s %s", b.cls, g.bam_fmt_time(b.duration))
    end
    Boss_action_monitor_hud_update()
end

-- ===== 設定画面 =====
--
-- 左: 登録したボスの一覧(「ターゲットを登録」「削除」)
-- 右: 選んだボスの設定(マップ・手動タイマーの長さ・HP の件・時間の件)
-- 入力欄は打ち終えて 0.5 秒たつと保存する(Enter でも確定できる)。
-- 行が何件目かは行の名前(hp_<n> / tm_<n>)から取る。SetUserValue で持たせると、
-- 入力欄の GetParent() から読めないことがある(Revival Timer の試作で実機で発生)。

g.bam_setting_w = 680
g.bam_setting_h = 580

function Boss_action_monitor_setting()
    local setting = ui.CreateNewFrame("notice_on_pc", g.bam_setting_name, 0, 0, 0, 0)
    AUTO_CAST(setting)
    setting:Resize(g.bam_setting_w, g.bam_setting_h)
    setting:SetPos(g.settings_frame_pos(g.bam_setting_w, g.bam_setting_h))
    setting:SetSkinName("test_frame_low")
    setting:SetLayerLevel(999)
    g.block_click_through(setting)
    setting:EnableHitTest(1)
    if not g.bam_sel or not g.bam_settings.bosses[g.bam_sel] then
        local b, i = nil, nil
        if g.bam_active_cls then
            b, i = Boss_action_monitor_find(g.bam_active_cls)
        end
        g.bam_sel = i or 1
    end
    Boss_action_monitor_setting_build(setting)
    setting:ShowWindow(1)
    g.esc_register_keep(g.bam_setting_name, "Boss_action_monitor_setting_close")
end

function Boss_action_monitor_setting_close()
    local setting = ui.GetFrame(g.bam_setting_name)
    if setting then
        Boss_action_monitor_commit_all(setting)
        Boss_action_monitor_save_settings()
    end
    ui.DestroyFrame(g.bam_setting_name)
end

function Boss_action_monitor_setting_build(setting)
    setting:RemoveAllChild()
    local title = setting:CreateOrGetControl('richtext', 'title', 20, 12, 50, 30)
    AUTO_CAST(title)
    title:SetText("{ol}Boss Action Monitor Config")
    local close = setting:CreateOrGetControl("button", "close", 0, 0, 20, 20)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Boss_action_monitor_setting_close")
    -- 共通の設定
    local checks = {{"nicochat", 20, Boss_action_monitor_t("ニコチャット表示", "Show Nico Chat")},
                    {"ptchat", 190, Boss_action_monitor_t("PTチャット表示", "Show PT Chat")},
                    {"sound", 360, Boss_action_monitor_t("効果音", "Sound")},
                    {"hud", 480, Boss_action_monitor_t("HUD を出す", "Show HUD")}}
    for _, c in ipairs(checks) do
        local cb = setting:CreateOrGetControl('checkbox', "common_" .. c[1], c[2], 42, 30, 30)
        AUTO_CAST(cb)
        cb:SetCheck(g.bam_settings[c[1]] and 1 or 0)
        cb:SetEventScript(ui.LBUTTONUP, "Boss_action_monitor_common_check")
        cb:SetEventScriptArgString(ui.LBUTTONUP, c[1])
        cb:SetText("{ol}" .. c[3])
    end
    local bosses = g.bam_settings.bosses
    -- 左: ボスの検索欄 + 一覧。検索欄が空なら登録済みのボス、何か入っていれば検索の結果を出す。
    local search = setting:CreateOrGetControl("edit", "boss_search", 10, 80, 200, 34)
    AUTO_CAST(search)
    search:SetFontName("white_16_ol")
    search:SetTextAlign("left", "center")
    search:SetSkinName("inventory_serch")
    search:SetTextTooltip(Boss_action_monitor_t("{ol}ボスの名前で検索して登録します（部分一致）",
        "{ol}Search bosses by name to register (partial match)"))
    search:SetEventScript(ui.ENTERKEY, "Boss_action_monitor_search")
    -- 打鍵のたびに絞り込む。走査するのは最初に 1 回だけ作るボスの索引で、
    -- 出すのも 50 件までなので、打鍵ごとに走らせてよい。空なら登録済みの一覧へ戻る。
    g.setup_incremental_search(search, "Boss_action_monitor_search")
    local list = setting:CreateOrGetControl("groupbox", "boss_list", 10, 118, 200, g.bam_setting_h - 214)
    AUTO_CAST(list)
    list:SetSkinName("test_frame_midle_light")
    list:EnableScrollBar(1)
    Boss_action_monitor_build_list(list, "")
    -- ボタンは 2 段に分ける(横に並べると「ターゲットを登録」の文字が隣へはみ出す。実機で指摘)。
    local add = setting:CreateOrGetControl("button", "boss_add", 10, g.bam_setting_h - 90, 200, 34)
    AUTO_CAST(add)
    add:SetText(Boss_action_monitor_t("{ol}ターゲットを登録", "{ol}Add target"))
    add:SetTextTooltip(Boss_action_monitor_t(
        "{ol}今ターゲットしているモンスターを登録します{nl}（ボス以外も登録できます）",
        "{ol}Register the monster you are targeting{nl}(non-boss monsters too)"))
    add:SetEventScript(ui.LBUTTONUP, "Boss_action_monitor_add_target")
    local del = setting:CreateOrGetControl("button", "boss_del", 10, g.bam_setting_h - 50, 200, 34)
    AUTO_CAST(del)
    del:SetText(Boss_action_monitor_t("{ol}選んだボスを削除", "{ol}Delete selected"))
    del:SetEventScript(ui.LBUTTONUP, "Boss_action_monitor_delete_ask")
    -- 右: 選んだボスの設定
    local detail = setting:CreateOrGetControl("groupbox", "detail", 220, 80, g.bam_setting_w - 230,
        g.bam_setting_h - 90)
    AUTO_CAST(detail)
    detail:SetSkinName("test_frame_midle_light")
    detail:EnableScrollBar(0)
    Boss_action_monitor_build_detail(detail)
    g.vlog("boss_action_monitor: 設定画面を組み立てた 登録 %d 体 選択=%s", #bosses, tostring(g.bam_sel))
end

-- 左の一覧を作る。query が空なら登録済みのボス、何かあれば検索の結果。
-- **検索欄は作り直さない**(打鍵のたびにここへ来るので、作り直すと入力が壊れる)。
g.bam_search_max = 50
function Boss_action_monitor_build_list(list, query)
    list:RemoveAllChild()
    if query ~= "" then
        local hits, total = g.bam_search(Boss_action_monitor_boss_index(), query, g.bam_search_max)
        if #hits == 0 then
            Boss_action_monitor_label(list, "empty", 10, 10, Boss_action_monitor_t("{ol}{#AAAAAA}見つかりません",
                "{ol}{#AAAAAA}No match"))
        end
        for i, m in ipairs(hits) do
            local registered = Boss_action_monitor_find(m.cls) ~= nil
            local btn = list:CreateOrGetControl("button", "hit_" .. i, 6, 6 + (i - 1) * 34, 168, 30)
            AUTO_CAST(btn)
            btn:SetSkinName(registered and "test_pvp_btn" or "test_gray_button")
            btn:SetText("{ol}{s14}" .. m.name)
            btn:SetTextTooltip("{ol}" .. m.cls .. (registered and Boss_action_monitor_t("{nl}登録済み", "{nl}Registered") or
                Boss_action_monitor_t("{nl}クリックで登録", "{nl}Click to register")))
            btn:SetEventScript(ui.LBUTTONUP, "Boss_action_monitor_search_pick")
            btn:SetEventScriptArgString(ui.LBUTTONUP, m.cls)
        end
        if total > #hits then
            Boss_action_monitor_label(list, "more", 10, 10 + #hits * 34, string.format(Boss_action_monitor_t(
                "{ol}{s13}{#AAAAAA}ほか %d 件。もっと絞ってください", "{ol}{s13}{#AAAAAA}%d more. Narrow it down"),
                total - #hits))
        end
        return
    end
    local bosses = g.bam_settings.bosses
    if #bosses == 0 then
        Boss_action_monitor_label(list, "empty", 10, 10, Boss_action_monitor_t(
            "{ol}{#AAAAAA}上の欄でボスの名前を{nl}検索するか、ボスを{nl}ターゲットして{nl}「ターゲットを登録」を{nl}押してください",
            "{ol}{#AAAAAA}Search a boss name above,{nl}or target a boss and{nl}press \"Add target\""))
    end
    for i, b in ipairs(bosses) do
        local btn = list:CreateOrGetControl("button", "boss_" .. i, 6, 6 + (i - 1) * 34, 168, 30)
        AUTO_CAST(btn)
        btn:SetSkinName(i == g.bam_sel and "test_pvp_btn" or "test_gray_button")
        btn:SetText("{ol}{s14}" .. b.name)
        btn:SetTextTooltip("{ol}" .. b.cls)
        btn:SetEventScript(ui.LBUTTONUP, "Boss_action_monitor_select")
        btn:SetEventScriptArgNumber(ui.LBUTTONUP, i)
    end
end

-- ボスの索引。モンスターの表からランクが Boss のものを 1 回だけ拾って覚える
-- (表は数万行あるので、打鍵のたびに走査しない)。
function Boss_action_monitor_boss_index()
    if g.bam_boss_index then
        return g.bam_boss_index
    end
    local index = {}
    local started = imcTime.GetAppTimeMS()
    local cls_list, count = GetClassList("Monster")
    for i = 0, (count or 0) - 1 do
        local cls = GetClassByIndexFromList(cls_list, i)
        if cls and TryGetProp(cls, "MonRank", "None") == "Boss" then
            local name = dictionary.ReplaceDicIDInCompStr(TryGetProp(cls, "Name", "") or "")
            if name ~= "" and name ~= "None" then
                index[#index + 1] = {
                    cls = cls.ClassName,
                    name = name
                }
            end
        end
    end
    g.bam_boss_index = index
    g.vlog("boss_action_monitor: ボスの索引を作った %d 件 / 表 %d 行 (%dms)", #index, count or 0,
        imcTime.GetAppTimeMS() - started)
    return index
end

-- 部分一致の検索(純ロジック)。名前と ClassName のどちらかに含まれれば当たり。英字は大文字・小文字を区別しない。
-- 返すのは (先頭から max 件, 当たった総数)。
function g.bam_search(index, query, max)
    local q = string.lower(tostring(query or ""))
    local hits, total = {}, 0
    if q == "" then
        return hits, 0
    end
    for _, m in ipairs(index) do
        if string.find(string.lower(m.name), q, 1, true) or string.find(string.lower(m.cls), q, 1, true) then
            total = total + 1
            if #hits < max then
                hits[#hits + 1] = m
            end
        end
    end
    return hits, total
end

-- 検索欄(打鍵 / Enter / 「×」から来る)。一覧だけを作り直す。
function Boss_action_monitor_search(frame, ctrl, text)
    local setting = ui.GetFrame(g.bam_setting_name)
    local list = setting and GET_CHILD_RECURSIVELY(setting, "boss_list")
    if not list then
        return
    end
    AUTO_CAST(list)
    -- 検索語は入力欄から読む。Enter から来たときの第 3 引数は検索語ではない(空の argStr)。
    local query = (ctrl and ctrl:GetName() == "boss_search" and ctrl:GetText()) or text
    if type(query) ~= "string" then
        query = ""
    end
    Boss_action_monitor_build_list(list, query)
end

-- 検索の結果をクリック。登録して選び、登録済みの一覧へ戻す。
function Boss_action_monitor_search_pick(parent, ctrl, cls)
    local mon_cls = GetClass("Monster", cls)
    g.vlog("boss_action_monitor: 検索から登録 cls=%s", tostring(cls))
    if mon_cls then
        Boss_action_monitor_add_cls(cls, mon_cls, false)
    end
end

function Boss_action_monitor_label(parent, name, x, y, text)
    local label = parent:CreateOrGetControl('richtext', name, x, y, 50, 20)
    AUTO_CAST(label)
    label:SetText(text)
    return label
end

function Boss_action_monitor_edit(parent, name, x, y, w, text, number_mode)
    local edit = parent:CreateOrGetControl('edit', name, x, y, w, 28)
    AUTO_CAST(edit)
    edit:SetFontName("white_16_ol")
    edit:SetTextAlign("center", "center")
    if number_mode then
        edit:SetNumberMode(1)
    end
    edit:SetText(text)
    -- 打ち終えて少し手を止めたら保存する。打鍵のたびの呼び出しは g.setup_incremental_search と同じ SetTypingScp。
    edit:SetTypingScp("Boss_action_monitor_typing")
    edit:SetEventScript(ui.ENTERKEY, "Boss_action_monitor_edit_enter")
    return edit
end

function Boss_action_monitor_build_detail(detail)
    detail:RemoveAllChild()
    local b = g.bam_settings.bosses[g.bam_sel]
    if not b then
        Boss_action_monitor_label(detail, "none", 10, 10, Boss_action_monitor_t("{ol}{#AAAAAA}ボスが登録されていません",
            "{ol}{#AAAAAA}No boss registered"))
        return
    end
    local w = detail:GetWidth()
    Boss_action_monitor_label(detail, "boss_name", 10, 8, "{ol}{s18}" .. b.name .. "{/}{s13}{#AAAAAA}  " .. b.cls)
    -- マップ
    local map_cls = b.map ~= "" and GetClass("Map", b.map)
    local map_label = map_cls and dictionary.ReplaceDicIDInCompStr(map_cls.Name) or
                          Boss_action_monitor_t("(登録なし)", "(none)")
    Boss_action_monitor_label(detail, "map", 10, 38, Boss_action_monitor_t("{ol}マップ: ", "{ol}Map: ") .. map_label)
    local map_set = detail:CreateOrGetControl("button", "map_set", w - 190, 32, 110, 28)
    AUTO_CAST(map_set)
    map_set:SetText(Boss_action_monitor_t("{ol}今のマップ", "{ol}This map"))
    map_set:SetTextTooltip(Boss_action_monitor_t(
        "{ol}このマップに入ると、ボスが出る前からレイドタイマーの知らせを出します",
        "{ol}In this map, time alerts work even before the boss appears"))
    map_set:SetEventScript(ui.LBUTTONUP, "Boss_action_monitor_map_set")
    local map_clear = detail:CreateOrGetControl("button", "map_clear", w - 76, 32, 66, 28)
    AUTO_CAST(map_clear)
    map_clear:SetText(Boss_action_monitor_t("{ol}解除", "{ol}Clear"))
    map_clear:SetEventScript(ui.LBUTTONUP, "Boss_action_monitor_map_clear")
    -- 手動タイマーの長さ
    Boss_action_monitor_label(detail, "duration_label", 10, 72,
        Boss_action_monitor_t("{ol}手動タイマーの長さ (分:秒)", "{ol}Manual timer length (m:ss)"))
    Boss_action_monitor_edit(detail, "duration", 250, 66, 80, b.duration > 0 and g.bam_fmt_time(b.duration) or "", false)
    -- HP
    local y = 106
    Boss_action_monitor_label(detail, "hp_head", 10, y + 4, "{ol}{#FFD700}" ..
        Boss_action_monitor_t("HP で知らせる", "Alert by HP"))
    local hp_add = detail:CreateOrGetControl("button", "hp_add", w - 90, y, 80, 28)
    AUTO_CAST(hp_add)
    hp_add:SetText(Boss_action_monitor_t("{ol}追加", "{ol}Add"))
    hp_add:SetEventScript(ui.LBUTTONUP, "Boss_action_monitor_row_add")
    hp_add:SetEventScriptArgString(ui.LBUTTONUP, "hp")
    Boss_action_monitor_label(detail, "hp_cols", 10, y + 32, "{ol}{s13}{#CCCCCC}ON      HP%       " ..
        Boss_action_monitor_t("メッセージ", "Message"))
    local hp_list = detail:CreateOrGetControl("groupbox", "hp_list", 0, y + 52, w, 130)
    AUTO_CAST(hp_list)
    hp_list:SetSkinName("None")
    hp_list:EnableScrollBar(1)
    Boss_action_monitor_build_rows(hp_list, "hp", b.hp)
    -- 時間
    y = 296
    Boss_action_monitor_label(detail, "tm_head", 10, y + 4, "{ol}{#FFD700}" ..
        Boss_action_monitor_t("残り時間で知らせる", "Alert by remaining time"))
    local tm_add = detail:CreateOrGetControl("button", "tm_add", w - 90, y, 80, 28)
    AUTO_CAST(tm_add)
    tm_add:SetText(Boss_action_monitor_t("{ol}追加", "{ol}Add"))
    tm_add:SetEventScript(ui.LBUTTONUP, "Boss_action_monitor_row_add")
    tm_add:SetEventScriptArgString(ui.LBUTTONUP, "tm")
    Boss_action_monitor_label(detail, "tm_cols", 10, y + 32, "{ol}{s13}{#CCCCCC}ON      " ..
        Boss_action_monitor_t("残り      何秒前      メッセージ", "At        Sec before   Message"))
    local tm_list = detail:CreateOrGetControl("groupbox", "tm_list", 0, y + 52, w, 130)
    AUTO_CAST(tm_list)
    tm_list:SetSkinName("None")
    tm_list:EnableScrollBar(1)
    Boss_action_monitor_build_rows(tm_list, "tm", b.time)
    Boss_action_monitor_label(detail, "note", 10, y + 188, Boss_action_monitor_t(
        "{ol}{s13}{#CCCCCC}※ 時間はレイドタイマーの残り時間です。無いときは HUD の ▶ で手動タイマーを始めます",
        "{ol}{s13}{#CCCCCC}* Time is the raid timer's remaining time. Without it, start the manual timer with ▶ on the HUD"))
end

-- 行を作る。kind は "hp" / "tm"。行の名前は kind_<n>。
function Boss_action_monitor_build_rows(list, kind, rows)
    list:RemoveAllChild()
    for i, t in ipairs(rows) do
        local row = list:CreateOrGetControl("groupbox", kind .. "_" .. i, 0, (i - 1) * 34, list:GetWidth() - 20, 32)
        AUTO_CAST(row)
        row:SetSkinName("None")
        row:EnableScrollBar(0)
        local on = row:CreateOrGetControl('checkbox', "on", 8, 2, 30, 30)
        AUTO_CAST(on)
        on:SetCheck(t.on and 1 or 0)
        on:SetEventScript(ui.LBUTTONUP, "Boss_action_monitor_row_on")
        if kind == "hp" then
            Boss_action_monitor_edit(row, "pct", 44, 2, 56, tostring(t.pct), true)
            Boss_action_monitor_edit(row, "text", 108, 2, 270, t.text, false)
        else
            Boss_action_monitor_edit(row, "at", 44, 2, 64, g.bam_fmt_time(t.at), false)
            Boss_action_monitor_edit(row, "before", 116, 2, 56, tostring(t.before), true)
            Boss_action_monitor_edit(row, "text", 180, 2, 198, t.text, false)
        end
        local del = row:CreateOrGetControl("button", "del", 386, 2, 28, 28)
        AUTO_CAST(del)
        del:SetText("{ol}{#FF6347}×")
        del:SetEventScript(ui.LBUTTONUP, "Boss_action_monitor_row_del")
    end
end

-- 行の名前から (種類, 何件目) を取る。"hp_3" → "hp", 3
function Boss_action_monitor_row_key(row)
    if not row then
        return nil
    end
    local kind, idx = string.match(tostring(row:GetName()), "^(%a+)_(%d+)$")
    if kind ~= "hp" and kind ~= "tm" then
        return nil
    end
    return kind, tonumber(idx)
end

function Boss_action_monitor_row_item(row)
    local b = g.bam_settings.bosses[g.bam_sel]
    local kind, idx = Boss_action_monitor_row_key(row)
    if not b or not kind then
        return nil
    end
    local rows = kind == "hp" and b.hp or b.time
    return rows[idx], b, kind, idx
end

-- 1 行の入力欄を読み取って設定へ写す。読めない値(打ちかけ)は前の値のまま。
function Boss_action_monitor_commit_row(row)
    local t, b, kind = Boss_action_monitor_row_item(row)
    if not t then
        return false
    end
    local text = GET_CHILD(row, "text")
    if text then
        t.text = text:GetText()
    end
    if kind == "hp" then
        local pct = GET_CHILD(row, "pct")
        local n = pct and tonumber(pct:GetText())
        if n then
            t.pct = n
        end
    else
        local at = GET_CHILD(row, "at")
        local sec = at and g.bam_parse_time(at:GetText())
        if sec then
            t.at = sec
        end
        local before = GET_CHILD(row, "before")
        local n = before and tonumber(before:GetText())
        if n then
            t.before = n
        end
    end
    g.bam_normalize_boss(b)
    return true
end

function Boss_action_monitor_commit_duration(detail)
    local b = g.bam_settings.bosses[g.bam_sel]
    local edit = detail and GET_CHILD(detail, "duration")
    if not b or not edit then
        return
    end
    local text = edit:GetText()
    if text == "" then
        b.duration = 0
    else
        local sec = g.bam_parse_time(text)
        if sec then
            b.duration = sec
        end
    end
    g.bam_normalize_boss(b)
end

function Boss_action_monitor_commit_all(setting)
    local b = g.bam_settings.bosses[g.bam_sel]
    if not b then
        return
    end
    Boss_action_monitor_commit_duration(GET_CHILD_RECURSIVELY(setting, "detail"))
    for _, kind in ipairs({"hp", "tm"}) do
        local list = GET_CHILD_RECURSIVELY(setting, kind .. "_list")
        local rows = kind == "hp" and b.hp or b.time
        if list then
            for i = 1, #rows do
                Boss_action_monitor_commit_row(GET_CHILD(list, kind .. "_" .. i))
            end
        end
    end
end

-- 入力欄 1 つぶんを保存する(Enter と、打鍵の後の自動保存の両方がここを通る)。
function Boss_action_monitor_commit_edit(ctrl)
    local parent = ctrl:GetParent()
    if ctrl:GetName() == "duration" then
        Boss_action_monitor_commit_duration(parent)
    else
        Boss_action_monitor_commit_row(parent)
    end
    Boss_action_monitor_save_settings()
    local b = g.bam_settings.bosses[g.bam_sel]
    g.vlog("boss_action_monitor: 入力を保存 %s/%s boss=%s", tostring(parent and parent:GetName()),
        tostring(ctrl:GetName()), b and b.cls or "nil")
end

function Boss_action_monitor_typing(parent, ctrl)
    local row = ctrl:GetParent()
    g.bam_typing_seq = g.bam_typing_seq + 1
    ReserveScript(string.format("Boss_action_monitor_typing_fire(%q, %q, %d)", tostring(row:GetName()),
        tostring(ctrl:GetName()), g.bam_typing_seq), 0.5)
end

function Boss_action_monitor_typing_fire(row_name, ctrl_name, seq)
    if seq ~= g.bam_typing_seq then
        return
    end
    local setting = ui.GetFrame(g.bam_setting_name)
    if not setting or setting:IsVisible() ~= 1 then
        return
    end
    local row = GET_CHILD_RECURSIVELY(setting, row_name)
    local edit = row and GET_CHILD(row, ctrl_name)
    if edit then
        AUTO_CAST(edit)
        Boss_action_monitor_commit_edit(edit)
    end
end

-- Enter。**ここで設定画面を作り直さないこと**(押した入力欄が消えるとチャット入力欄が開く。
-- docs/UI_RULES.md)。この Enter でチャット入力欄が開いていたら閉じる。
function Boss_action_monitor_edit_enter(parent, ctrl)
    local chat = ui.GetFrame("chat")
    g.bam_chat_was_open = chat ~= nil and chat:IsVisible() == 1
    ReserveScript("Boss_action_monitor_after_enter()", 0.05)
    Boss_action_monitor_commit_edit(ctrl)
end

function Boss_action_monitor_after_enter()
    local chat = ui.GetFrame("chat")
    local open = chat ~= nil and chat:IsVisible() == 1
    g.vlog("boss_action_monitor: Enter の後のチャット入力欄 前=%s 後=%s", tostring(g.bam_chat_was_open), tostring(open))
    if open and not g.bam_chat_was_open then
        ui.CloseFrame("chat")
    end
end

-- 窓を作り直す前に、打ちかけの入力を読み取っておく(ボタンからなので Enter の問題は起きない)。
function Boss_action_monitor_rebuild()
    local setting = ui.GetFrame(g.bam_setting_name)
    if not setting then
        return
    end
    AUTO_CAST(setting)
    Boss_action_monitor_setting_build(setting)
end

function Boss_action_monitor_common_check(parent, ctrl, key)
    if key ~= "nicochat" and key ~= "ptchat" and key ~= "sound" and key ~= "hud" then
        return
    end
    g.bam_settings[key] = ctrl:IsChecked() == 1
    Boss_action_monitor_save_settings()
    g.vlog("boss_action_monitor: %s=%s", key, tostring(g.bam_settings[key]))
    if key == "hud" then
        Boss_action_monitor_hud_update()
    end
end

function Boss_action_monitor_select(parent, ctrl, str, idx)
    local setting = ui.GetFrame(g.bam_setting_name)
    Boss_action_monitor_commit_all(setting)
    Boss_action_monitor_save_settings()
    g.bam_sel = idx
    Boss_action_monitor_rebuild()
end

-- 今のターゲット(無ければボスのゲージに出ているボス)を登録する。
function Boss_action_monitor_add_target()
    local setting = ui.GetFrame(g.bam_setting_name)
    Boss_action_monitor_commit_all(setting)
    local handle = session.GetTargetHandle()
    if not handle or handle == 0 then
        handle = session.GetTargetBossHandle()
    end
    local cls = handle and handle ~= 0 and info.GetMonsterClassName(handle)
    local mon_cls = cls and cls ~= "" and cls ~= "None" and GetClass("Monster", cls)
    g.vlog("boss_action_monitor: ターゲットを登録 handle=%s cls=%s", tostring(handle), tostring(cls))
    if not mon_cls then
        ui.SysMsg(Boss_action_monitor_t("登録したいボスをターゲットしてから押してください",
            "Target the boss you want to add first"))
        return
    end
    Boss_action_monitor_add_cls(cls, mon_cls, true)
end

-- ClassName で 1 体登録して選ぶ(ターゲットからと検索からの両方)。
-- with_map … 今のマップも一緒に覚えるか。ターゲットから登録したときだけ(そのボスの居るマップに居るので)。
-- 検索からは街で登録することが多く、今のマップはボスと関係が無い。
function Boss_action_monitor_add_cls(cls, mon_cls, with_map)
    Boss_action_monitor_commit_all(ui.GetFrame(g.bam_setting_name))
    local found, i = Boss_action_monitor_find(cls)
    if found then
        g.bam_sel = i
        ui.SysMsg(Boss_action_monitor_t("このボスはもう登録してあります", "This boss is already registered"))
        Boss_action_monitor_rebuild()
        return
    end
    if #g.bam_settings.bosses >= g.bam_max_bosses then
        ui.SysMsg(string.format(Boss_action_monitor_t("登録できるのは %d 体までです", "Up to %d bosses"),
            g.bam_max_bosses))
        return
    end
    local bosses = g.bam_settings.bosses
    bosses[#bosses + 1] = g.bam_normalize_boss({
        cls = cls,
        name = dictionary.ReplaceDicIDInCompStr(mon_cls.Name),
        map = (with_map and g.get_map_type() ~= "City") and tostring(g.map_name or "") or "",
        duration = 0,
        hp = {},
        time = {}
    })
    g.bam_sel = #bosses
    Boss_action_monitor_save_settings()
    Boss_action_monitor_rebuild()
end

function Boss_action_monitor_delete_ask()
    local b = g.bam_settings.bosses[g.bam_sel]
    if not b then
        return
    end
    ui.MsgBox(string.format(Boss_action_monitor_t("「%s」の設定を消しますか？", "Delete the settings for \"%s\"?"),
        b.name), string.format("Boss_action_monitor_delete(%d)", g.bam_sel), "None")
end

function Boss_action_monitor_delete(idx)
    local b = g.bam_settings.bosses[idx]
    if not b then
        return
    end
    table.remove(g.bam_settings.bosses, idx)
    g.vlog("boss_action_monitor: 削除 %s", b.cls)
    g.bam_sel = math.max(1, math.min(idx, #g.bam_settings.bosses))
    Boss_action_monitor_save_settings()
    Boss_action_monitor_rebuild()
    Boss_action_monitor_hud_update()
end

function Boss_action_monitor_map_set()
    local b = g.bam_settings.bosses[g.bam_sel]
    if not b then
        return
    end
    Boss_action_monitor_commit_all(ui.GetFrame(g.bam_setting_name))
    b.map = tostring(g.map_name or "")
    Boss_action_monitor_save_settings()
    Boss_action_monitor_rebuild()
end

function Boss_action_monitor_map_clear()
    local b = g.bam_settings.bosses[g.bam_sel]
    if not b then
        return
    end
    Boss_action_monitor_commit_all(ui.GetFrame(g.bam_setting_name))
    b.map = ""
    Boss_action_monitor_save_settings()
    Boss_action_monitor_rebuild()
end

function Boss_action_monitor_row_add(parent, ctrl, kind)
    local b = g.bam_settings.bosses[g.bam_sel]
    if not b then
        return
    end
    Boss_action_monitor_commit_all(ui.GetFrame(g.bam_setting_name))
    local rows = kind == "hp" and b.hp or b.time
    if #rows >= g.bam_max_rows then
        ui.SysMsg(string.format(Boss_action_monitor_t("登録できるのは %d 件までです", "Up to %d entries"),
            g.bam_max_rows))
        return
    end
    if kind == "hp" then
        rows[#rows + 1] = {on = true, pct = 50, text = ""}
    else
        rows[#rows + 1] = {on = true, at = 0, before = 10, text = ""}
    end
    g.bam_normalize_boss(b)
    Boss_action_monitor_save_settings()
    Boss_action_monitor_rebuild()
end

function Boss_action_monitor_row_del(parent, ctrl)
    local t, b, kind, idx = Boss_action_monitor_row_item(ctrl:GetParent())
    if not t then
        return
    end
    Boss_action_monitor_commit_all(ui.GetFrame(g.bam_setting_name))
    table.remove(kind == "hp" and b.hp or b.time, idx)
    Boss_action_monitor_save_settings()
    Boss_action_monitor_rebuild()
end

function Boss_action_monitor_row_on(parent, ctrl)
    local t = Boss_action_monitor_row_item(ctrl:GetParent())
    if not t then
        return
    end
    t.on = ctrl:IsChecked() == 1
    Boss_action_monitor_save_settings()
end
-- Boss Action Monitor ここまで
