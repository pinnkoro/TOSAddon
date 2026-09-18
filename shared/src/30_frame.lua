-- 共通部品: ウィンドウの土台と当たり判定
--
-- 詳しくは 10_json.lua の冒頭。

-- ESC で消えない常時表示フレームを作る。常時出しておきたいフレームは必ずこれを使うこと。
--
-- ゲーム側の chat_memberlist.xml は <option hideable="true"> で、ESC はこの hideable な
-- フレームを閉じる。notice_on_pc は hideable="false" なので消えない。
-- ESC による非表示は IsVisible() に反映されないため、_nexus_addons_p_update_frames の
-- 毎フレーム復帰では検出も復旧もできない。土台の選択で防ぐしかない。
function g.create_persistent_frame(frame_name)
    return ui.CreateNewFrame("notice_on_pc", frame_name, 0, 0, 0, 0)
end

-- ウィンドウの裏をクリックできてしまうのを防ぐ。**窓を開いたら必ず呼ぶこと。**
--
-- 土台の notice_on_pc.xml は <input ... hittestframe="false"/> なので、既定では
-- フレーム自身の背景(コントロールが乗っていない部分)が当たり判定を持たない。
-- そこを押した入力は下の 3D 画面へ抜けてしまい、窓の上をクリックしたつもりが
-- キャラクターが歩き出す・敵を選ぶ、という動きになる。
-- (子のボタンやスロットは各自の EnableHitTest で受けるので、そこだけは抜けない。
--  つまり「窓の余白を押したときだけ裏に通る」という分かりにくい出方をする)
--
-- 逆に**通したいもの**では呼ばないこと。常時表示の HUD(always_status / muteki /
-- monster_kill_count のように、利用者の「固定」「ロック」設定で通す/通さないを
-- 切り替える作りのもの)、マーカー、ツールチップ、大きさ 0 の入れ物フレームが当たる。
-- ここで塞ぐと、画面の一部が押せなくなる。
-- (indun_panel は畳んでいても展開していても塞ぐ。「フレームを固定」は**動かさない**
--  だけの設定で、当たり判定まで捨てる意味は無い。Indun_panel_setup_frame を参照)
function g.block_click_through(frame)
    if not frame then
        return
    end
    frame:EnableHittestFrame(1)
end
