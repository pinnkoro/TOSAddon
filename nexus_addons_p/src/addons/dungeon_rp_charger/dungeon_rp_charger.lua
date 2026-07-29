-- Dungeon RP charger ここから
-- タイマーを載せる _nexus_addons_p フレームはマップ移動をまたいで残るので、
-- 一度 Start した 3 秒タイマーは明示的に Stop しない限りクライアントを落とすまで
-- 回り続ける。以前は Stop がどこにも無く、聖域を出ても・設定を OFF にしても・
-- 中でエラーが出ても止まらなかった(同じエラーを 3 秒ごとに無言で踏み続けた)。
-- 止める経路は必ずこの関数を通すこと。
function Dungeon_rp_charger_stop_timer(reason)
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    if not _nexus_addons_p then
        return
    end
    -- 止める判定は g のフラグに頼らない。フラグが落ちていてもタイマー側が生きている
    -- 可能性がある(タイマーはフレームに載っているので g より寿命が長い)ため、
    -- 見つけたら必ず Stop する。フラグは「毎マップのログを増やさない」ためだけに使う。
    local dungeon_rp_charger_timer = GET_CHILD(_nexus_addons_p, "dungeon_rp_charger_timer")
    if dungeon_rp_charger_timer then
        AUTO_CAST(dungeon_rp_charger_timer)
        dungeon_rp_charger_timer:Stop()
    end
    if g.dungeon_rp_charger_running then
        g.dungeon_rp_charger_running = false
        g.vlog("dungeon_rp_charger: 自動補充タイマーを止める (%s)", tostring(reason))
    end
end

function dungeon_rp_charger_on_init()
    -- 11244 未知の聖域3F -- 40049 レリックバフ -- 11030036 エクトナイト(マケ売り可) misc_Ectonite    -- 11030451 エクトナイト misc_Ectonite_Care
    -- on_init はマップ移動のたびに全アドオン分走る(GAME_START_3SEC 経由)。
    -- 対象マップを離れたことに気付けるのはここだけなので、張るより先に止める判定を置く。
    if not g.settings.dungeon_rp_charger or g.settings.dungeon_rp_charger.use == 0 then
        Dungeon_rp_charger_stop_timer("設定が OFF")
        return
    end
    if g.map_id ~= 11244 then
        Dungeon_rp_charger_stop_timer(string.format("対象マップ外へ移動した map=%s", tostring(g.map_id)))
        return
    end
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    if not _nexus_addons_p then
        return
    end
    local dungeon_rp_charger_timer = GET_CHILD(_nexus_addons_p, "dungeon_rp_charger_timer")
    if not dungeon_rp_charger_timer then
        dungeon_rp_charger_timer = _nexus_addons_p:CreateOrGetControl("timer", "dungeon_rp_charger_timer", 0, 0)
    end
    AUTO_CAST(dungeon_rp_charger_timer)
    dungeon_rp_charger_timer:SetUpdateScript("Dungeon_rp_charger_auto_charge")
    dungeon_rp_charger_timer:Start(3.0)
    g.dungeon_rp_charger_running = true
    g.dungeon_rp_charger_last_error = nil
    g.vlog("dungeon_rp_charger: 聖域で自動補充を開始する (map=%s)", tostring(g.map_id))
end

--[[function Dungeon_rp_charger_BUFF_ADD(frame, msg, str, buff_id)
    if g.settings.dungeon_rp_charger.use == 0 then
        return
    end
    if buff_id == 40049 then
        local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
        if _nexus_addons_p then
            _nexus_addons_p:SetVisible(1)
            local dungeon_rp_charger_timer = GET_CHILD(_nexus_addons_p, "dungeon_rp_charger_timer")
            if not dungeon_rp_charger_timer then
                dungeon_rp_charger_timer = _nexus_addons_p:CreateOrGetControl("timer", "dungeon_rp_charger_timer", 0, 0)
            end
            AUTO_CAST(dungeon_rp_charger_timer)
            dungeon_rp_charger_timer:SetUpdateScript("Dungeon_rp_charger_auto_charge")
            dungeon_rp_charger_timer:Start(1.0)
        end
    end
end]]

function Dungeon_rp_charger_auto_charge(_nexus_addons_p, dungeon_rp_charger_timer)
    if not g.settings.dungeon_rp_charger or g.settings.dungeon_rp_charger.use == 0 then
        Dungeon_rp_charger_stop_timer("設定が OFF")
        return
    end
    -- 保険。通常はマップ移動時の on_init が止めるが、そこを通らずに抜けた場合でも
    -- 対象マップ外で回り続けないようにする。
    if g.map_id ~= 11244 then
        Dungeon_rp_charger_stop_timer(string.format("対象マップ外 map=%s", tostring(g.map_id)))
        return
    end
    -- 中で落ちると 3 秒周期でそのまま踏み続けるので、必ず止めて理由を残す。
    local ok, err = pcall(Dungeon_rp_charger_charge_once)
    if ok then
        g.dungeon_rp_charger_last_error = nil
        return
    end
    Dungeon_rp_charger_stop_timer("補充処理でエラー")
    local msg = "DungeonRpCharger 自動補充でエラー: " .. tostring(err)
    g.vlog("%s", msg)
    -- vlog は既定 OFF なので、利用者の手元には何も残らない。debug_log.txt にも出す。
    if g.dungeon_rp_charger_last_error ~= msg then
        g.dungeon_rp_charger_last_error = msg
        g.log_to_file(msg)
    end
end

-- RP 満タン・素材未所持でもタイマーは止めない。聖域に居る間は RP がまた減るし、
-- エクトナイトを後から手に入れることもあるので、止めると再開する機会が無くなる。
-- (止めてよいのは「この先ずっと空振りする」= OFF / マップ外 / エラー の 3 つだけ)
function Dungeon_rp_charger_charge_once()
    local pc = GetMyPCObject()
    local cur_rp, max_rp = shared_item_relic.get_rp(pc)
    if cur_rp >= 200 then
        return
    end
    session.ResetItemList()
    local mat_item = session.GetInvItemByType(11030451)
    if not mat_item then
        mat_item = session.GetInvItemByType(11030036)
        if not mat_item then
            return
        end
    end
    if mat_item.isLockState then
        return
    end
    local item_index = mat_item:GetIESID()
    local cur_count = mat_item.count
    local recharge_count = math.floor((max_rp - cur_rp) / 10)
    if cur_count and cur_count > 0 then
        if recharge_count > cur_count then
            recharge_count = cur_count
        end
        if recharge_count > 0 then
            session.AddItemID(item_index, recharge_count)
            local result_list = session.GetItemIDList()
            item.DialogTransaction('RELIC_CHARGE_RP', result_list)
        end
    end
end
-- Dungeon RP charger ここまで

