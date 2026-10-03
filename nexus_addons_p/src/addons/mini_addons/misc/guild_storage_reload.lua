-- 封鎖戦の報酬を受け取り、ギルド保管箱を更新する(週 1 回、日曜 19:00 以降)
--
-- 封鎖戦ヘルプ:「封鎖戦の報酬受け取りは日曜日午後7時以降、ギルドマスター権限があるプレイヤーが
-- '報酬受取'タブを通して受け取ることができます」。なので区切りは**毎週日曜 19:00**。
-- その区切りを過ぎてから最初のログイン(マップ移動)で 1 回だけ、
--   1. ギルド長なら、封鎖戦ランキングの「報酬をもらう」を 3 体(ドラグーン / アラクネ姉妹 / バウバス)ぶん押す
--   2. ギルド情報「保管箱」タブの更新ボタンを押す(受け取った報酬が保管箱に見えるように)
-- を代わりに行う。ギルド長でなければ 2 だけ行う(1 は権限が無く、押すとエラーになるだけ)。
--
-- 素の実装(guild_activity_ui.lua)との対応:
--   「報酬をもらう」 GUILD_ACTIVITY_DETAIL_BLOCKADE_RANK_REWARD … boruta.RequestBorutaReward(週, 種類)
--     週   = session.boruta_ranking.GetNowWeekNum() - 右の週タブの位置(0 が今の週)
--     種類 = "50" .. 上のボスタブの位置(500 ドラグーン / 501 アラクネ姉妹 / 502 バウバス)
--   受け取り済み session.boruta_ranking.RewardAccepted(週)(boruta.RequestBorutaAcceptedRewardInfo(週) で取り寄せる)
--   週の終わり   session.boruta_ranking.GetBorutaEndTime()(boruta.RequestBorutaEndTime(週) で取り寄せる)
--   保管箱の更新 GUILDINFO_INFO_UPDATE_WAREHOUSE … party.RequestReloadInventory(PARTY_GUILD)
-- 取り寄せはどれもサーバーへの要求で、結果は後から届く。なので 1 段ずつ ReserveScript で間を空けて進める。
--
-- **受け取る週は「今の週」と「前の週」のうち、終わっていて、まだ受け取っていない週。**
-- 日曜 19:00 に週の番号が切り替わるのかどうかが分からないので、どちらでも取りこぼさないよう両方を見る
-- (切り替わるなら前の週、切り替わらないなら今の週が当たる)。受け取り済みの判定は素と同じく週ごと。
--
-- 回したかどうかは g.settings.guild_storage_reload_week に「その週の区切り(日曜 19:00)の日付」で控える
-- (アカウントごと)。週の番号が取れなかったときは控えず、次のマップ移動でやり直す。
--
-- **local は増やさない**(mini_addons の断片はメインチャンク直下へ連結され、1 関数 200 個の枠を食う)。
-- 途中の状態は g.guild_storage_reload に持つ。
g.guild_storage_reload = g.guild_storage_reload or {
    running = false,
    weeks = {},
    week_index = 0,
    claimed = 0
}

-- いちばん最近の日曜 19:00(今がそれより前なら前の週の日曜)の日付。週 1 回の区切りに使う
function Mini_addons_guild_storage_reload_week(now)
    now = now or os.time()
    local d = os.date("*t", now)
    -- wday は 1 が日曜
    local boundary = os.time({
        year = d.year,
        month = d.month,
        day = d.day - (d.wday - 1),
        hour = 19,
        min = 0,
        sec = 0
    })
    if boundary > now then
        boundary = boundary - 7 * 24 * 3600
    end
    return os.date("%Y-%m-%d", boundary)
end

-- GAME_START_3SEC(マップ移動のたび)から呼ぶ。回すのはその週の最初の 1 回だけ
function Mini_addons_guild_storage_reload()
    if g.settings.guild_storage_reload ~= 1 then
        return
    end
    local st = g.guild_storage_reload
    if st.running then
        return
    end
    local week = Mini_addons_guild_storage_reload_week()
    if g.settings.guild_storage_reload_week == week then
        return
    end
    -- ギルドに入っていない(またはまだ情報が届いていない)ときは何もせず、日付も控えない。
    -- 次のマップ移動でもう一度見る
    if session.party.GetPartyInfo(PARTY_GUILD) == nil then
        core_g.vlog("mini_addons: 封鎖戦報酬と保管箱 ギルドの情報が無いので見送り(%s)", week)
        return
    end
    st.running = true
    st.key = week
    st.claimed = 0
    if AM_I_LEADER(PARTY_GUILD) == 1 then
        core_g.vlog("mini_addons: 封鎖戦報酬と保管箱 開始(週 %s / ギルド長)", week)
        boruta.RequestBorutaNowWeekNum()
        ReserveScript("Mini_addons_guild_storage_reload_weeks()", 1.5)
    else
        core_g.vlog("mini_addons: 封鎖戦報酬と保管箱 開始(週 %s / ギルド長でないので保管箱の更新だけ)", week)
        Mini_addons_guild_storage_reload_finish(true)
    end
end

-- 週の番号が届いたら、見る週(今の週と前の週)を決める
function Mini_addons_guild_storage_reload_weeks()
    local st = g.guild_storage_reload
    local now_week = session.boruta_ranking.GetNowWeekNum()
    if not now_week or now_week < 1 then
        -- 取れなかったときは控えずに終える(次のマップ移動でやり直す)
        core_g.vlog("mini_addons: 封鎖戦報酬 週の番号が取れないので見送り(%s)", tostring(now_week))
        st.running = false
        return
    end
    st.weeks = {now_week, now_week - 1}
    st.week_index = 0
    Mini_addons_guild_storage_reload_next_week()
end

-- 次の週について、終わりの時刻と受け取り済みかを取り寄せる
function Mini_addons_guild_storage_reload_next_week()
    local st = g.guild_storage_reload
    st.week_index = st.week_index + 1
    local week_num = st.weeks[st.week_index]
    if not week_num or week_num < 1 then
        -- 受け取った報酬が保管箱へ入るまで少し待ってから更新する
        Mini_addons_guild_storage_reload_finish(false)
        return
    end
    boruta.RequestBorutaEndTime(week_num)
    boruta.RequestBorutaAcceptedRewardInfo(week_num)
    ReserveScript("Mini_addons_guild_storage_reload_check_week()", 1.5)
end

-- 終わっていて、まだ受け取っていない週なら 3 体ぶん受け取る
function Mini_addons_guild_storage_reload_check_week()
    local st = g.guild_storage_reload
    local week_num = st.weeks[st.week_index]
    local ended = imcTime.IsLaterThan(geTime.GetServerSystemTime(), session.boruta_ranking.GetBorutaEndTime()) ~= 0
    local accepted = session.boruta_ranking.RewardAccepted(week_num) == 1
    core_g.vlog("mini_addons: 封鎖戦報酬 週 %d 終了=%s 受取済み=%s", week_num, tostring(ended), tostring(accepted))
    if ended and not accepted then
        -- 500 ドラグーン / 501 アラクネ姉妹 / 502 バウバス(素の上のタブの並び)。少しずつ間を空けて送る
        for i, event_type in ipairs({500, 501, 502}) do
            ReserveScript(string.format("Mini_addons_guild_storage_reload_claim(%d, %d)", week_num, event_type), 0.3 * i)
        end
        st.claimed = st.claimed + 1
        core_g.vlog("mini_addons: 封鎖戦報酬 週 %d の 3 体ぶんを送る", week_num)
        ReserveScript("Mini_addons_guild_storage_reload_next_week()", 1.5)
        return
    end
    Mini_addons_guild_storage_reload_next_week()
end

-- 「報酬をもらう」1 体ぶん。素の GUILD_ACTIVITY_DETAIL_BLOCKADE_RANK_REWARD と同じ要求
-- (ReserveScript から呼ぶので関数にしておく。素の API の一覧 vanilla_api.json にも載る)
function Mini_addons_guild_storage_reload_claim(week_num, event_type)
    boruta.RequestBorutaReward(week_num, event_type)
    core_g.vlog("mini_addons: 封鎖戦報酬 週 %d 種類 %d を受け取りに行った", week_num, event_type)
end

-- 保管箱を更新して、その週は済んだと控える
function Mini_addons_guild_storage_reload_finish(now)
    if not now then
        ReserveScript("Mini_addons_guild_storage_reload_finish(true)", 2.0)
        return
    end
    local st = g.guild_storage_reload
    party.RequestReloadInventory(PARTY_GUILD)
    core_g.vlog("mini_addons: ギルド保管箱を更新した(受け取った週 %d / 前回 %s → %s)", st.claimed,
        tostring(g.settings.guild_storage_reload_week), tostring(st.key))
    if st.claimed > 0 then
        ui.SysMsg(g.lang == "Japanese" and "{ol}Mini Addons: 封鎖戦の報酬を受け取り、ギルド保管箱を更新しました" or
                      "{ol}Mini Addons: claimed the siege rewards and refreshed the guild storage")
    end
    g.settings.guild_storage_reload_week = st.key
    Mini_addons_save_settings()
    st.running = false
end
