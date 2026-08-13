-- ボタン右クリックでサウンドオフ
--
-- ここは GAME_START_3SEC から毎回呼ばれる(マップ移動のたびに張り直す)。
-- 以前は minimap_outsidebutton / BGM_PLAYER の nil を見ておらず、片方でも無いと
-- ここで落ちて GAME_START_3SEC の**残り全部**(エフェクト設定の復元・ヴァカリネ通知・
-- チャンネル一覧など)が道連れになっていた。必ず nil を見てから触ること。
function Mini_addons_toggle_sound_set()
    local minimap_outsidebutton = ui.GetFrame("minimap_outsidebutton")
    if not minimap_outsidebutton then
        core_g.vlog("mini_addons: minimap_outsidebutton が無いので音量トグルを張らない")
        return
    end
    -- 直下に居なければ孫まで探す(クライアント側の階層が変わっても拾えるように)。
    local BGM_PLAYER = GET_CHILD(minimap_outsidebutton, "BGM_PLAYER") or
                           GET_CHILD_RECURSIVELY(minimap_outsidebutton, "BGM_PLAYER")
    if not BGM_PLAYER then
        core_g.vlog("mini_addons: minimap_outsidebutton に BGM_PLAYER が無いので音量トグルを張らない")
        return
    end
    AUTO_CAST(BGM_PLAYER)
    BGM_PLAYER:SetEventScript(ui.RBUTTONUP, "Mini_addons_SOUND_TOGGLE")
    local tooltip = g.lang == "Japanese" and "{@st59}BGMプレイヤー{nl}右クリック: Sound Play/Mute{/}" or
                        g.lang == "kr" and "{@st59}BGM 플레이어{nl}우클릭: 소리 켜기/끄기{/}" or
                        "{@st59}BGM Player{nl}Right-click: Sound Play/Mute{/}"
    BGM_PLAYER:SetTextTooltip(tooltip)
    -- 音量 API がクライアントに在るか。**トグルが無反応のときの一次切り分けはここ。**
    -- 張るところまでは成功していても、押した先で config.* が nil なら何も起きない。
    -- 毎マップ出すと流れるので、判定が変わったときだけ 1 行出す。
    local api = type(config) == "table" and
                    (type(config.GetTotalVolume) == "function" and type(config.SetTotalVolume) == "function")
    if g.sound_toggle_api ~= api and
        core_g.vlog("mini_addons: 音量トグルを設定 (config.GetTotalVolume/SetTotalVolume=%s)", tostring(api)) then
        g.sound_toggle_api = api
    end
end

-- 右クリックでミュート ⇔ 復帰。
--
-- **イベントスクリプトの中で落ちてもどこにも記録が残らない**(debug_log.txt に載るのは
-- メッセージハンドラだけ)ので、pcall で受けて vlog に出す。実際、利用者の設定ファイルに
-- volume キーが一度も書かれていなかった = ここが最後まで走ったことが無かった。
--
-- 以前の判定は `g.settings.volume == nil or volume ~= 0` で、**記憶が 0 のときに詰む**:
-- ゲーム側で音量 0 にしている状態で最初に押すと volume=0 を記憶してしまい、以後は
-- 「復帰」に回っても SetTotalVolume(0) を書くだけになって、二度と音が戻らなかった。
-- 記憶するのは 0 より大きい値だけにする。
function Mini_addons_SOUND_TOGGLE(frame, ctrl, str, num)
    local ok, err = pcall(function()
        if type(config) ~= "table" or type(config.GetTotalVolume) ~= "function" or
            type(config.SetTotalVolume) ~= "function" then
            error("config.GetTotalVolume/SetTotalVolume がこのクライアントに無い", 0)
        end
        local volume = tonumber(config.GetTotalVolume()) or 0
        core_g.vlog("mini_addons: 音量トグル 現在=%s 記憶=%s", tostring(volume), tostring(g.settings.volume))
        if volume > 0 then
            g.settings.volume = volume
            Mini_addons_save_settings()
            config.SetTotalVolume(0)
        else
            local restore = tonumber(g.settings.volume) or 0
            if restore <= 0 then
                -- 記憶が無い(ミュート状態で初めて押した)。ここで勝手な値を書くと
                -- 音量を上書きすることになるので、戻す先はゲームの設定で決めてもらう。
                core_g.vlog("mini_addons: 音量トグル 記憶が無いので復帰できない(先に音量を上げてから使う)")
                ui.SysMsg(g.lang == "Japanese" and
                              "{ol}{#FF6347}[MiniAddons]{/} 元の音量を記憶していません。ゲームの設定で音量を上げてから右クリックしてください" or
                              "{ol}{#FF6347}[MiniAddons]{/} No previous volume stored. Raise the volume in the game options first.")
                return
            end
            config.SetTotalVolume(restore)
        end
        core_g.vlog("mini_addons: 音量トグル後=%s", tostring(config.GetTotalVolume()))
    end)
    if not ok then
        core_g.log_error_once("mini_addons_sound_toggle", "MiniAddons 音量トグルでエラー: " .. tostring(err))
    end
end
