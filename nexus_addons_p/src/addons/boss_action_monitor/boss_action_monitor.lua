-- Boss Action Monitor ここから
--
-- ボスの行動を HP と残り時間で前もって知らせる。設定はボス(モンスターの ClassName)ごと。
--   HP   … 「HP 50% でシールド」のように登録。ボスの HP がその割合を下回ったら 1 回知らせる
--   時間 … 「残り 4:30 でシールド」のように登録。その N 秒前と、その時点で知らせる
--
-- 時間の基準は 3 つ。ゲームのタイマーがあればそれに合わせ、無ければ手動。
--   * レイドタイマー(素の raid_timer)… 素の RAID_TIMER_UPDATE(set_time, remain_time) に相乗りする
--   * 週間ボスレイドのタイマー(素の damage_meter の 7 分)… **レイドタイマーとは別物。**
--     素の DAMAGE_METER_UPDATE_TIMER(frame) に相乗りし、frame の NOW_TIME / END_TIME から残りを出す
--   * どちらも無いときは、HUD の ▶ で自分のカウントダウン(ボスごとの「手動タイマーの長さ」)を始める
-- どれもイベント方式(素を先に呼ぶ)で相乗りするので、素の表示はそのまま。
--
-- 「共通」の件(g.bam_groups)は特別な登録で、決まった種類のマップ(Keyword で判定)に居るときだけ、
-- そこに居るどのボスにも効く。ボスが週ごと・回ごとに替わっても、タイマーに沿った知らせ
-- (例: 残り 1:00)を登録し直さずに済むようにするため。
--   @weekly_boss … 週間ボスレイド(WeeklyBossMap)
--   @field_boss  … ボス協同戦(FieldBossMap)。キーワードは Vakarine Equip で実機確認済み
--
-- weizlogy さんの HP Monitor(ボスの HP で PT チャットを出すアドオン)と同じ目的のものを
-- 時間の知らせと合わせて作り直した。HP Monitor にはライセンスの表記が無いので、コードは流用していない。
--
-- **bundle の local は 200 個が上限なので、このファイルではトップレベルの local を作らない。**
-- 定数は g.bam_* に置く。

-- 「共通」の登録。manual … 設定画面に「手動タイマーの長さ」を出すか(ゲームのタイマーが
-- 届くと分かっているコンテンツでは要らない)。
g.bam_groups = {{
    cls = "@weekly_boss",
    keyword = "WeeklyBossMap",
    ja = "★ 週間ボス共通",
    en = "* Weekly Boss (all)",
    tip_ja = "{ol}週間ボスレイドの中で、その週のボスに効きます",
    tip_en = "{ol}Applies to the boss of the week in Weekly Boss Raid",
    note_ja = "{ol}{s13}{#CCCCCC}週間ボスレイドの中だけで、その週のボスに効きます。{nl}残り時間は週間ボスレイドの 7 分のタイマーです",
    note_en = "{ol}{s13}{#CCCCCC}Works only in Weekly Boss Raid, for that week's boss.{nl}Time is the raid's 7-minute timer",
    manual = false
}, {
    cls = "@field_boss",
    keyword = "FieldBossMap",
    ja = "★ 協同戦共通",
    en = "* Boss Co-op (all)",
    tip_ja = "{ol}ボス協同戦の中で、そこに居るボスに効きます",
    tip_en = "{ol}Applies to the boss in Boss Co-op battles",
    -- 右の欄の幅(約 440)に収まるよう 1 行を短くする。richtext は折り返さず、はみ出た分は切れる。
    note_ja = "{ol}{s13}{#CCCCCC}ボス協同戦の中だけで、そこに居るボスに効きます。{nl}残り時間はゲームのタイマー(無ければ HUD の ▶ で手動)",
    note_en = "{ol}{s13}{#CCCCCC}Works only in Boss Co-op, for the boss there.{nl}Time: the game timer, or the manual timer (▶ on HUD)",
    manual = true
}}
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
    -- 以前の版はボスごとにマップを覚えていた(そのマップに入ると、ボスを見る前から残り時間の
    -- 知らせを動かす)。週間ボスレイドは属性ごとに同じマップを使うので、別の週の別のボスにまで
    -- 前のボスの知らせが出ていた。機能ごと落としたので、残っていれば捨てる。
    b.map = nil
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

-- 幅に収まるように末尾を「…」で切る(純ロジック)。ボタンや HUD の 1 行に長い名前を入れると
-- 枠からはみ出す(「[週間ボスレイド] ヴェルニケ…」で実機で指摘)。
-- 幅は {s14} の目安で、全角(UTF-8 で 3 バイト以上の文字)を 14、それ以外を 7 と数える。
-- 全文はツールチップで見せること。
function g.bam_fit_text(text, max_w)
    text = tostring(text or "")
    local chars, widths, total = {}, {}, 0
    -- UTF-8 の 1 文字ずつに分ける(先頭バイトで長さが決まる)。
    local i, n = 1, #text
    while i <= n do
        local b = string.byte(text, i)
        local len = (b >= 240 and 4) or (b >= 224 and 3) or (b >= 192 and 2) or 1
        local ch = string.sub(text, i, i + len - 1)
        i = i + len
        local w = (len >= 3) and 14 or 7
        chars[#chars + 1] = ch
        widths[#widths + 1] = w
        total = total + w
    end
    if total <= max_w then
        return text, false
    end
    local ellipsis_w = 14
    local out, used = {}, 0
    for i, ch in ipairs(chars) do
        if used + widths[i] + ellipsis_w > max_w then
            break
        end
        out[#out + 1] = ch
        used = used + widths[i]
    end
    return table.concat(out) .. "…", true
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
    -- 「共通」の登録は常に一覧の先頭に g.bam_groups の順で置く(無ければ作る。消せない)。
    for gi, grp in ipairs(g.bam_groups) do
        local found = nil
        for i, b in ipairs(settings.bosses) do
            if b.cls == grp.cls then
                found = i
            end
        end
        local entry = found and table.remove(settings.bosses, found) or g.bam_normalize_boss({
            cls = grp.cls,
            name = ""
        })
        table.insert(settings.bosses, gi, entry)
    end
    g.bam_settings = settings
    Boss_action_monitor_save_settings()
end

-- 「共通」の登録なら、その定義(g.bam_groups の 1 つ)を返す。普通のボスなら nil。
function Boss_action_monitor_group(b)
    if not b then
        return nil
    end
    for _, grp in ipairs(g.bam_groups) do
        if grp.cls == b.cls then
            return grp
        end
    end
    return nil
end

-- 表示名。「共通」は言語に合わせる(保存する name は空)。
function Boss_action_monitor_display_name(b)
    local grp = Boss_action_monitor_group(b)
    if grp then
        return Boss_action_monitor_t(grp.ja, grp.en)
    end
    return b.name
end

-- その「共通」が今のマップで効くか。Keyword が引けなかったとき(nil)は効かない扱い。
function Boss_action_monitor_group_active(grp)
    return g.map_has_keyword(grp.keyword) == true
end

-- 今のマップで効く「共通」の登録(ログ用に名前も)。
function Boss_action_monitor_active_groups()
    local result, names = {}, {}
    for _, grp in ipairs(g.bam_groups) do
        if Boss_action_monitor_group_active(grp) then
            local b = Boss_action_monitor_find(grp.cls)
            if b then
                result[#result + 1] = b
                names[#names + 1] = grp.cls
            end
        end
    end
    return result, table.concat(names, ",")
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
        g.bam_group_boss_name = {}
        g.bam_prev_remain = nil
        g.bam_prev_source = nil
    end
    g.setup_hook_and_event(g.addon, "RAID_TIMER_UPDATE", "Boss_action_monitor_RAID_TIMER_UPDATE", true)
    g.setup_hook_and_event(g.addon, "DAMAGE_METER_UPDATE_TIMER", "Boss_action_monitor_DAMAGE_METER_UPDATE_TIMER", true)
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
    local _, group_names = Boss_action_monitor_active_groups()
    g.vlog("boss_action_monitor: 監視を開始 map=%s 登録 %d 体 共通=%s", tostring(g.map_name),
        #g.bam_settings.bosses, group_names)
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

-- 今のマップで効く「共通」の登録(週間ボスレイドなら「週間ボス共通」など)。
function Boss_action_monitor_group_bosses()
    local result = {}
    for _, b in ipairs(g.bam_settings.bosses) do
        local grp = Boss_action_monitor_group(b)
        if grp and Boss_action_monitor_group_active(grp) then
            result[#result + 1] = b
        end
    end
    return result
end

-- 時間の知らせを見るボス。このマップで姿を見たもの + 今のマップで効く「共通」。
-- **個別のボスは姿を見るまで動かさない。** マップで決め打ちすると、同じマップを使う
-- 別のボス(週間ボスレイドは属性ごとに同じマップ)にまで知らせが出る。
function Boss_action_monitor_active_bosses()
    local result = {}
    for _, b in ipairs(g.bam_settings.bosses) do
        local grp = Boss_action_monitor_group(b)
        if grp then
            if Boss_action_monitor_group_active(grp) then
                result[#result + 1] = b
            end
        elseif g.bam_seen and g.bam_seen[b.cls] then
            result[#result + 1] = b
        end
    end
    return result
end

-- HUD に出すボス。直近に姿を見たもの、無ければ今のマップで効く最初の「共通」。
function Boss_action_monitor_hud_boss()
    if g.bam_active_cls then
        local b = Boss_action_monitor_find(g.bam_active_cls)
        if b then
            return b
        end
    end
    return Boss_action_monitor_group_bosses()[1]
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
    Boss_action_monitor_game_timer(remain, "raid", set_time)
end

-- 素の DAMAGE_METER_UPDATE_TIMER(frame) の後に呼ばれる(週間ボスレイドの 7 分のタイマー)。
-- 素は 0.1 秒ごとに呼ぶが、残りは秒単位なので、同じ秒なら time_step で何もしない。
function Boss_action_monitor_DAMAGE_METER_UPDATE_TIMER(my_frame, my_msg)
    if g.settings.boss_action_monitor.use ~= 1 or not g.bam_settings then
        return
    end
    local frame = g.get_event_args(my_msg)
    if not frame then
        return
    end
    local now_time = tonumber(frame:GetUserValue("NOW_TIME"))
    local end_time = tonumber(frame:GetUserValue("END_TIME"))
    if not now_time or not end_time then
        return
    end
    local remain = math.floor(end_time - now_time)
    if remain < 0 then
        return
    end
    Boss_action_monitor_game_timer(remain, "weekly", 420)
end

-- ゲームのタイマー(レイド / 週間ボス)から残りを受け取る。kind が HUD の表示と前回の区別に使われる。
function Boss_action_monitor_game_timer(remain, kind, set_time)
    if not g.bam_raid or g.bam_raid.kind ~= kind then
        g.vlog("boss_action_monitor: ゲームのタイマーを受け取った kind=%s set=%s remain=%s map=%s", kind,
            tostring(set_time), tostring(remain), tostring(g.map_name))
    end
    g.bam_raid = {
        kind = kind,
        remain = remain,
        set = tonumber(set_time),
        at_ms = imcTime.GetAppTimeMS()
    }
    -- ゲームのタイマーが来たら手動タイマーは要らない(二重に知らせない)。
    if g.bam_manual then
        g.vlog("boss_action_monitor: ゲームのタイマーが来たので手動タイマーを止める")
        g.bam_manual = nil
    end
    if g.bam_prev_source == kind and g.bam_prev_remain == remain then
        return
    end
    Boss_action_monitor_time_step(remain, kind)
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

-- 「共通」が効くマップで、ボス(isBoss)ならその「共通」の HP の件を見る。
-- HP の印は個別の登録とは別に持つ(同じボスを個別にも登録していれば、両方の件が動く)。
function Boss_action_monitor_scan_group(entry, handle, cls)
    local target_info = info.GetTargetInfo(handle)
    local stat = target_info and target_info.stat
    if not target_info or target_info.isBoss ~= 1 or not stat or not stat.maxHP or stat.maxHP <= 0 or stat.HP <= 0 then
        return
    end
    local pct = stat.HP / stat.maxHP * 100
    if not g.bam_group_boss_name[entry.cls] then
        local mon_cls = cls and GetClass("Monster", cls)
        g.bam_group_boss_name[entry.cls] = mon_cls and dictionary.ReplaceDicIDInCompStr(mon_cls.Name) or tostring(cls)
        g.vlog("boss_action_monitor: %s のボスを見つけた %s handle=%d HP=%.1f%%", entry.cls, tostring(cls), handle, pct)
    end
    if not g.bam_active_cls or Boss_action_monitor_group(Boss_action_monitor_find(g.bam_active_cls)) then
        g.bam_active_cls = entry.cls
        g.bam_hp_now = pct
    end
    local key = entry.cls .. ":" .. handle
    local state = g.bam_hp_state[key]
    if not state then
        state = {}
        g.bam_hp_state[key] = state
    end
    for _, d in ipairs(g.bam_hp_due(entry.hp, state, pct)) do
        g.vlog("boss_action_monitor: HP %s %s pct=%d 今=%.1f%%", entry.cls, tostring(cls), d.trig.pct, pct)
        Boss_action_monitor_notify(entry, d)
    end
end

function Boss_action_monitor_scan()
    local objects, count = SelectObject(GetMyPCObject(), g.bam_scan_range, "ENEMY")
    local groups = Boss_action_monitor_active_groups()
    for i = 1, count or 0 do
        local handle = GetHandle(objects[i])
        local cls = info.GetMonsterClassName(handle)
        local b = cls and Boss_action_monitor_find(cls)
        for _, entry in ipairs(groups) do
            Boss_action_monitor_scan_group(entry, handle, cls)
        end
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
    local label = (t.text ~= "" and t.text) or
                      (Boss_action_monitor_group(b) and g.bam_group_boss_name and g.bam_group_boss_name[b.cls]) or Boss_action_monitor_display_name(b)
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
-- 登録したボスが居る(または「共通」が効くマップに居る)ときだけ出す。
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
    local group_boss = Boss_action_monitor_group(b) and g.bam_group_boss_name and g.bam_group_boss_name[b.cls]
    if group_boss then
        name:SetText("{ol}{s14}" .. g.bam_fit_text(group_boss, 168))
    else
        name:SetText("{ol}{s14}" .. g.bam_fit_text(Boss_action_monitor_display_name(b), 168))
    end
    local remain_text = GET_CHILD(hud, "remain")
    remain_text:SetOffset(10, 28)
    local start = GET_CHILD(hud, "start")
    AUTO_CAST(start)
    local remain
    if Boss_action_monitor_raid_fresh() then
        remain = g.bam_raid.remain
        remain_text:SetText("{ol}{s18}" .. g.bam_fmt_time(remain) .. "{/}{s13} " ..
                                (g.bam_raid.kind == "weekly" and Boss_action_monitor_t("週間ボス", "Weekly") or
                                    Boss_action_monitor_t("レイド", "Raid")))
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
-- 右: 選んだボスの設定(手動タイマーの長さ・HP の件・時間の件)
-- 入力欄は Enter か、閉じる・ボスを切り替える・行を足す / 消すとき(commit_all)に保存する。
-- 行が何件目かは行の名前(hp_<n> / tm_<n>)から取る。SetUserValue で持たせると、
-- 入力欄の GetParent() から読めないことがある(Revival Timer の試作で実機で発生)。

g.bam_setting_w = 680
-- 右下の注記(2 行)まで入る高さ。580 では注記が窓の外に切れていた(実機で指摘)。
g.bam_setting_h = 630

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
            btn:SetText("{ol}{s14}" .. g.bam_fit_text(m.name, 148))
            btn:SetTextTooltip("{ol}" .. m.name .. "{nl}" .. m.cls .. (registered and Boss_action_monitor_t("{nl}登録済み", "{nl}Registered") or
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
        btn:SetText("{ol}{s14}" .. g.bam_fit_text(Boss_action_monitor_display_name(b), 148))
        local grp = Boss_action_monitor_group(b)
        btn:SetTextTooltip(grp and Boss_action_monitor_t(grp.tip_ja, grp.tip_en) or ("{ol}" .. b.name .. "{nl}" .. b.cls))
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
        Boss_action_monitor_add_cls(cls, mon_cls)
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
    -- **打鍵の後の自動保存(SetTypingScp)は付けないこと。** 打ち終えたかは推測でしか分からず、
    -- 「50」と打つ途中の「5」が設定に入って、ずれた時点で知らせが出る(Revival Timer で同じ判断をした)。
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
    local grp = Boss_action_monitor_group(b)
    if grp then
        Boss_action_monitor_label(detail, "boss_name", 10, 8, "{ol}{s18}" .. Boss_action_monitor_display_name(b))
        if grp.manual then
            -- 注記は 1 行目だけにし、手動タイマーの長さの欄を空ける
            Boss_action_monitor_label(detail, "group_note", 10, 34, Boss_action_monitor_t(grp.note_ja, grp.note_en))
            Boss_action_monitor_label(detail, "duration_label", 10, 76,
                Boss_action_monitor_t("{ol}手動タイマーの長さ (分:秒)", "{ol}Manual timer length (m:ss)"))
            Boss_action_monitor_edit(detail, "duration", 250, 70, 80,
                b.duration > 0 and g.bam_fmt_time(b.duration) or "", false)
        else
            Boss_action_monitor_label(detail, "group_note", 10, 40, Boss_action_monitor_t(grp.note_ja, grp.note_en))
        end
        Boss_action_monitor_build_triggers(detail, b)
        return
    end
    Boss_action_monitor_label(detail, "boss_name", 10, 8, "{ol}{s18}" .. b.name .. "{/}{s13}{#AAAAAA}  " .. b.cls)
    -- 手動タイマーの長さ
    Boss_action_monitor_label(detail, "duration_label", 10, 48,
        Boss_action_monitor_t("{ol}手動タイマーの長さ (分:秒)", "{ol}Manual timer length (m:ss)"))
    Boss_action_monitor_edit(detail, "duration", 250, 42, 80, b.duration > 0 and g.bam_fmt_time(b.duration) or "", false)
    Boss_action_monitor_build_triggers(detail, b)
end

-- HP の件と時間の件(どのボスでも同じ形)。
function Boss_action_monitor_build_triggers(detail, b)
    local w = detail:GetWidth()
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
        "{ol}{s13}{#CCCCCC}※ 時間はレイドタイマーの残り時間です。{nl}　 無いときは HUD の ▶ で手動タイマーを始めます",
        "{ol}{s13}{#CCCCCC}* Time is the raid timer's remaining time.{nl}  Without it, start the manual timer with ▶ on the HUD"))
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
            -- 100% は付けられない(初めて見た時点で下回っている扱いになり、出ない)。黙って 99 に
            -- 丸めると、Enter を押しても変わらないように見える(実機で指摘)。
            if n < 1 or n > 99 then
                ui.SysMsg(Boss_action_monitor_t("HP% は 1〜99 で入れてください", "HP% must be 1-99"))
            end
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
    -- 入力欄は実際に効く値(丸めた値・読めなければ前の値)に書き直す。
    if kind == "hp" then
        Boss_action_monitor_sync_edit(GET_CHILD(row, "pct"), tostring(t.pct))
    else
        Boss_action_monitor_sync_edit(GET_CHILD(row, "at"), g.bam_fmt_time(t.at))
        Boss_action_monitor_sync_edit(GET_CHILD(row, "before"), tostring(t.before))
    end
    return true
end

function Boss_action_monitor_sync_edit(edit, text)
    if edit and edit:GetText() ~= text then
        g.vlog("boss_action_monitor: 入力欄を書き直す %s %s -> %s", edit:GetName(), edit:GetText(), text)
        edit:SetText(text)
    end
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

-- 入力欄 1 つぶんを保存する(Enter で通る)。
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
    Boss_action_monitor_add_cls(cls, mon_cls)
end

-- ClassName で 1 体登録して選ぶ(ターゲットからと検索からの両方)。
function Boss_action_monitor_add_cls(cls, mon_cls)
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
    if Boss_action_monitor_group(b) then
        ui.SysMsg(string.format(Boss_action_monitor_t("「%s」は消せません。使わないときは件を OFF にしてください",
            "\"%s\" cannot be deleted. Turn its entries OFF instead"), Boss_action_monitor_display_name(b)))
        return
    end
    ui.MsgBox(string.format(Boss_action_monitor_t("「%s」の設定を消しますか？", "Delete the settings for \"%s\"?"),
        Boss_action_monitor_display_name(b)), string.format("Boss_action_monitor_delete(%d)", g.bam_sel), "None")
end

function Boss_action_monitor_delete(idx)
    local b = g.bam_settings.bosses[idx]
    if not b or Boss_action_monitor_group(b) then
        return
    end
    table.remove(g.bam_settings.bosses, idx)
    g.vlog("boss_action_monitor: 削除 %s", b.cls)
    g.bam_sel = math.max(1, math.min(idx, #g.bam_settings.bosses))
    Boss_action_monitor_save_settings()
    Boss_action_monitor_rebuild()
    Boss_action_monitor_hud_update()
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
