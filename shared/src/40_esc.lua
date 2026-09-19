-- 共通部品: ESC で閉じるフレームのスタック
--
-- **ESCAPE_PRESSED の購読は取り込む側が行う**(アドオンごとに 1 か所だけ)。
-- 受けたら g.esc_on_escape() を呼ぶ。判定と close の呼び出しはその中にある。
-- 詳しくは 10_json.lua の冒頭。

-- ESC で閉じる自作フレームの重なり(開いた順)スタック。
--
-- 土台が notice_on_pc のフレームはゲーム側の ESC では消えない(上のコメント参照)ので、
-- ESC で閉じているのは各アドオンが購読した ESCAPE_PRESSED のハンドラ。これはゲームから
-- 登録済みハンドラ全部へ一斉に配られるため、各自が素直に自分のフレームを閉じると
-- 「開いている自作ウィンドウが 1 回の ESC で全部消える」。
-- そこで開いたフレームをここへ積んでおき、閉じるのは一番手前(= 最後に開いた)1 枚だけにする。
--
-- 判定と close 呼び出しは core/20_lifecycle.lua の _nexus_addons_p_ESCAPE_PRESSED に集約する。
-- アドオンごとに ESCAPE_PRESSED を購読したままだと、先に閉じた側でスタックの中身が変わり、
-- 後から呼ばれたハンドラが「今度は自分が一番手前」と判断して結局まとめて消えてしまう。
g.esc_stack = g.esc_stack or {}

-- ESC で閉じたいフレームを開いたときに呼ぶ。
--   frame_name: ui.GetFrame に渡すフレーム名
--   close_func: 閉じ方。次のどちらでもよい
--     * グローバル関数の**名前**(引数無しで呼べること) … 既存の閉じる処理を使い回すとき
--     * 関数そのもの(引数無しで呼ばれる)               … その場の無名関数で足りるとき
--   後者を許すのは、閉じる処理がフレーム名を引数に取る作りのアドオンが多く、
--   そのたびに引数無しのラッパをグローバルへ足していると名前が増えるだけだから。
-- 開き直しは積み直し = 最前面扱いにする。
-- **フレームを作って ShowWindow(1) した後で呼ぶこと**。まだ出ていない状態で呼ぶと、
-- 直後の同期で「閉じ終わった登録」と見なされてその場で捨てられる。
function g.esc_register(frame_name, close_func)
    for i = #g.esc_stack, 1, -1 do
        if g.esc_stack[i].frame == frame_name then
            table.remove(g.esc_stack, i)
        end
    end
    table.insert(g.esc_stack, {
        frame = frame_name,
        close = close_func
    })
    g.esc_sync_scp()
end

-- 既に積んである登録は動かさずに積む。**中身を作り直す初期化関数から積むときはこちら**。
--
-- esc_register は「開き直し = 最前面」なので、同じフレームをもう一度積むと一番上へ来る。
-- 検索し直しのように「その窓自身を開き直した」ときはそれで正しいが、
-- **子の一覧を開いたまま親の設定画面を組み立て直す**作り(battle_ritual / muteki は
-- スキルやバフを足すたびに設定画面の初期化関数を呼び直す)でこれを使うと、
-- 親が子より手前に積み直され、ESC 1 回で親の close が走って子まで道連れになる
-- = スタックが防ぐはずの「まとめて消える」がそのまま出る。
--
-- **ここで「その登録が生きているか」を見ても意味が無い。** 呼ばれる時点ではフレームを
-- 作って ShowWindow(1) した直後なので、開き直した場合でも必ず生きていると出る。
-- 「閉じた窓の登録が下に残っている」状態を作らせないのは esc_top の掃除の役目
-- (毎フレームの esc_sync_scp から呼ばれる)。そちらを参照。
function g.esc_register_keep(frame_name, close_func)
    for _, entry in ipairs(g.esc_stack) do
        if entry.frame == frame_name then
            -- 位置は動かさず、閉じ方だけ最新にする
            entry.close = close_func
            g.esc_sync_scp()
            return
        end
    end
    g.esc_register(frame_name, close_func)
end

-- 「ESC で破棄する」だけの窓のための短縮形。閉じるときに保存などの後始末が要らない、
-- ui.DestroyFrame するだけの窓はこれで足りる(自作ウィンドウの大半がこれ)。
function g.esc_register_destroy(frame_name)
    g.esc_register(frame_name, function()
        ui.DestroyFrame(frame_name)
    end)
end

-- 「ESC で隠す」だけの窓のための短縮形。作り直せない土台(chat_memberlist など)や、
-- 破棄すると持っている参照が無効になる窓はこちらを使う。
function g.esc_register_hide(frame_name)
    g.esc_register(frame_name, function()
        local frame = ui.GetFrame(frame_name)
        if frame then
            AUTO_CAST(frame)
            frame:ShowWindow(0)
        end
    end)
end

-- 生きている(存在して表示中の)中で一番手前の登録を、外さずに返す。
-- × ボタンで閉じた分は登録解除されないまま残るので、ここで一緒に捨てる。
-- 戻り値の 2 つ目はスタック上の位置(esc_pop_top が外すのに使う)。
--
-- **掃除は「一番手前の生きた登録」で打ち切らず、スタック全体に対して行うこと。**
-- 途中で止めると、下に沈んだ死んだ登録が永久に残る。そうなると esc_register_keep が
-- それを掴んで位置を据え置き、**閉じた窓を開き直しても手前に来ない**:
--   一覧を開く → 別の窓を開く(一覧の上) → 一覧を × で閉じる(登録は下に残る)
--   → 一覧を開き直す → 据え置かれて下のまま → ESC が別の窓を先に閉じる
-- 全体を見ても、スタックに載るのは開いている自作ウィンドウだけ(実測で数枚)なので、
-- 毎フレーム呼ばれても走査は数回の ui.GetFrame で済む。
function g.esc_top()
    for i = #g.esc_stack, 1, -1 do
        local entry = g.esc_stack[i]
        local frame = ui.GetFrame(entry.frame)
        if frame == nil or frame:IsVisible() ~= 1 then
            -- 捨てた理由を残す。「開いているのに ESC で閉じられない」「開いた直後に
            -- 登録が消える」を追うとき、フレームが無いのか表示扱いでないのかで原因が別。
            -- 捨てるときしか出ないので、毎フレーム呼ばれてもログは流れない。
            g.vlog("esc_stack: %s を捨てた(frame=%s visible=%s)", tostring(entry.frame), frame and "有" or "無",
                frame and tostring(frame:IsVisible()) or "-")
            -- 下から順に詰めるので、i より下の位置は動かない(上向きに走査しているため安全)。
            table.remove(g.esc_stack, i)
        end
    end
    local top = #g.esc_stack
    if top == 0 then
        return nil
    end
    return g.esc_stack[top], top
end

-- 一番手前の登録を 1 つ取り出す(閉じた後に開き直せば esc_register で積み直される)。
function g.esc_pop_top()
    local entry, index = g.esc_top()
    if entry then
        table.remove(g.esc_stack, index)
    end
    return entry
end

-- 1 回の押下を 2 度処理しないための間隔(ms)。ESC の届く経路は 2 つあり(g.esc_sync_scp 参照)、
-- その 2 経路の配信間隔は 1 フレーム未満なので、ここはそれを吸収できる最小限で十分。
-- 長くすると 2 つ実害が出る:
--   (1) 意図した ESC 連打(手前を閉じてすぐ下を閉じる)を握り潰す = esc_is_reentry
--   (2) 最後の 1 枚を閉じた後、この時間だけ esc_taken() が true を返し続け、
--       indun_panel の ESC トグルを無効化する = esc_taken
-- 60fps の 1 フレーム≒16ms に対しフレーム落ちの余裕を見て 50ms とする
-- (旧値 200ms は上記 2 つをはっきり踏むほど長すぎた)。
local ESC_DEDUP_MS = 50

-- 「今回の ESC はスタック側(= 手前の自作ウィンドウ)が使ったか」の問い合わせ。
--
-- ESCAPE_PRESSED はスタックに積めないものからも購読されている(indun_panel は常時表示の
-- パネルで、積むと ESC を常に横取りしてシステムメニューが開けなくなる)。そちら側が
-- 「手前にウィンドウがあるときは何もしない」を判断するのに使う。
-- ハンドラの呼ばれる順番はゲーム任せなので、次のどちらかなら true にする:
--   * まだ手前に生きているウィンドウがある      … 自分より後にそれが閉じられる
--   * この押下で 1 枚閉じた直後                  … 自分より先に閉じられていた
function g.esc_taken()
    if g.esc_top() then
        return true
    end
    return g.esc_closed_ms ~= nil and imcTime.GetAppTimeMS() - g.esc_closed_ms < ESC_DEDUP_MS
end

-- 同じ押下での再入(2 経路)を捨てるための判定。閉じた側は g.esc_closed_ms を更新する。
function g.esc_is_reentry()
    return g.esc_last_ms ~= nil and imcTime.GetAppTimeMS() - g.esc_last_ms < ESC_DEDUP_MS
end

-- 自作ウィンドウが開いている間だけ、ESC をこちらへ回してもらう。
--
-- ui.SetEscapeScp はゲーム側の「この ESC はこれを実行する」を差し替える口で、素の ESC
-- (チャットなど hideable なフレームを閉じる / システムメニューを開く)の代わりに走る。
-- これを設定しないと、自作ウィンドウを閉じるついでにチャットが消えたりシステムメニューが
-- 開いたりする。クライアントの uiscp/enchantchip.lua・uiscp/moru.lua・
-- fixframe/deletewarningbox/deletewarningbox.lua が「開いている間だけ設定し、
-- 閉じたら "" に戻す」使い方をしているので、それに倣う。
--
-- 現在値を読む API はクライアントに無い(SetEscapeScp だけ)ので、自分が設定したかどうかを
-- 覚えて、状態が変わったときだけ呼ぶ。毎フレーム呼ぶとゲーム側が設定した分を潰してしまう。
-- 閉じ忘れると ESC でシステムメニューが二度と開かなくなるため、× で閉じた場合も拾えるよう
-- _nexus_addons_p_update_frames(FPS_UPDATE)からも呼んで実際の表示状態に合わせ続ける。
-- force=true のときは「覚えている状態」を無視して必ず設定し直す。
-- 記憶(g.esc_scp_set)はこちらが最後に書いた値でしかなく、クライアント側の実際の値とは
-- ずれうる。特に g.esc_scp_set を nil に戻した直後は want=false と「記憶なし(=false 扱い)」が
-- 一致してしまい、こちらが割り込み先を握ったままでも clear が一度も飛ばない。
-- こうなると ESC はすべてこちらへ来て、閉じるものが無いので何も起きない
-- = 利用者から見ると「ESC でシステムメニューが開かない」になる(実機で発生)。
function g.esc_sync_scp(force)
    local want = g.esc_top() ~= nil
    if not force and want == (g.esc_scp_set or false) then
        return
    end
    g.esc_scp_set = want
    g.vlog("esc_scp: %s (stack=%d force=%s)", want and "set" or "clear", #g.esc_stack, tostring(force or false))
    -- 古いクライアントに SetEscapeScp が無くても、ここで巻き込んで落とさない
    -- (その場合は ESCAPE_PRESSED の一斉配信だけで従来どおり動く)。
    -- **割り込み先は取り込む側が決める。** 共通部品から特定のアドオンの関数名を書くと、
    -- 単体アドオンのバンドルでは存在しない名前を指すことになり、以後 ESC を押しても
    -- システムメニューが開かなくなる(shared/README.md の決まり。PR #191 のレビュー指摘)
    pcall(ui.SetEscapeScp, want and (g.esc_scp_call or "") or "")
end

-- ESC を受けたときの中身。**購読は取り込む側が 1 か所だけで行い**、ここを呼ぶ。
-- (アドオンごとに ESCAPE_PRESSED を購読したままだと、先に閉じた側でスタックの中身が
--  変わり、後から呼ばれたハンドラが「今度は自分が一番手前」と判断してまとめて消える)
function g.esc_on_escape()
    -- ESC は 2 経路で届きうる: g.esc_sync_scp が仕込む ui.SetEscapeScp と、
    -- ゲームからアドオンへ一斉配信される ESCAPE_PRESSED。どちらが来る(あるいは両方来る)かは
    -- クライアント任せなので、同じ押下で二重に閉じないよう直後の再入は捨てる。
    -- 押下ごとに 1 行出す。**「ESC がこちらへ届いているか」を切り分けるのに要る。**
    --
    -- かつてここを黙らせていたのは、esc_probe(1 回で 30 行以上)を毎押下で回していた頃の
    -- 話。1 行なら実用上の重さは出ないので戻した。既定は詳細ログ OFF なので普段は黙る。
    -- この行が無いと「押しても何も起きない」を追えない: 閉じたときしか行が出ないため、
    -- **こちらへ届いていないのか、届いたが閉じる対象が無かったのかが区別できない**
    -- (実機で Easy Buff / Market Favorite が「1 回目は空振り、2 回目で閉じる」と報告され、
    --  ログからは press 1 の行跡が一切拾えなかった)。
    if g.esc_is_reentry() then
        g.vlog("ESCAPE_PRESSED: 同じ押下の再入として捨てた (stack=%d)", #g.esc_stack)
        return
    end
    g.esc_last_ms = imcTime.GetAppTimeMS()
    g.vlog("ESCAPE_PRESSED: 受けた (stack=%d scp=%s)", #g.esc_stack, tostring(g.esc_scp_set))
    local entry = g.esc_pop_top()
    if not entry then
        -- スタックに閉じるものが無いときだけ、Addons Menu 側(一覧と設定画面)を畳む。
        -- ゲーム側の ESC は chat_memberlist 由来のフレームを「隠す」が、それは IsVisible() に
        -- 出ないので、こちらの開閉判定と食い違う分をここで合わせる
        -- (詳細は core/90_addons_menu.lua の addons_menu_on_escape)。
        --
        -- **スタックより先に呼んではいけない。** 以前は無条件に先頭で呼んでいたため、
        -- 手前の自作ウィンドウを閉じる押下で Addons Menu の設定画面まで一緒に消えていた
        -- (「1 回の ESC でまとめて消える」を防ぐためのスタックが、ここだけ素通りしていた)。
        -- **取り込む側が渡したものだけを呼ぶ。** 共通部品から特定のアドオンのグローバルを
        -- 直接呼ぶと、同居しているときに相手のメニューまで畳んでしまう
        -- (Icor Planner のスタックが空の ESC で、Nexus Addons P の一覧が閉じていた)
        local extra = g.esc_extra_close
        local ok, closed = false, false
        if type(extra) == "function" then
            ok, closed = pcall(extra)
        elseif type(extra) == "string" and type(_G[extra]) == "function" then
            ok, closed = pcall(_G[extra])
        end
        if ok and closed then
            -- 実際に畳んだ押下は「使った」扱いにする。そうしないと設定画面が閉じるのと
            -- 同時にシステムメニューが開き、indun_panel のトグルまで走る。
            g.esc_closed_ms = imcTime.GetAppTimeMS()
            g.esc_sync_scp()
            return
        end
        -- 閉じるものが無いのに ESC が回ってきた = SetEscapeScp を戻し損ねている。
        -- そのままだとシステムメニューが開けなくなるので、ここで必ず戻す。
        -- ここは force を付けない。押下のたびに SetEscapeScp("") を撃つと、
        -- ゲーム側が自分の都合で入れた割り込み先(開いているダイアログを閉じる等)まで
        -- 消してしまい、次の 1 回が空振りする = ESC の効きが悪くなる。
        -- こちらが握ったままの状態は GAME_START の force 同期で必ず解ける。
        g.esc_sync_scp()
        -- 右クリックの付け直しもここではやらない。ESC は押すたびに必ず通る経路なので、
        -- 毎回 UI を触る処理を積むほど反応が鈍る(ログで実証済み。上のコメント参照)。
        -- 付け直しは GAME_START(マップ移動のたび)に任せる。もし移動を挟まずに
        -- 外れる事例が出たら、mini_addons が sysmenu へ掛けているような
        -- 数秒周期の更新スクリプトで直すこと。ESC の経路には戻さない。
        -- ここで esc_probe を回していたが、押下のたびに 30 行以上の vlog(ファイル書き込み +
        -- チャットへのシステムメッセージ)が走り、ESC の反応を悪くしていた。
        -- 調べたかったこと(システムメニュー = フレーム "apps")は分かったので、
        -- 定期的な調査は起動後 1 回(GAME_START)だけにする。
        return
    end
    -- close は関数そのものか、グローバル関数の名前(g.esc_register 参照)。
    local close_func = entry.close
    if type(close_func) ~= "function" then
        close_func = _G[close_func]
    end
    if type(close_func) ~= "function" then
        g.vlog("ESCAPE_PRESSED: close func not found frame=%s func=%s", tostring(entry.frame), tostring(entry.close))
        g.esc_sync_scp()
        return
    end
    g.vlog("ESCAPE_PRESSED: close %s (残り %d)", tostring(entry.frame), #g.esc_stack)
    -- 閉じる処理が転んでもゲーム側の ESC 処理を巻き込まないよう握る
    local ok, err = pcall(close_func)
    if ok then
        -- ESCAPE_PRESSED を購読している側(indun_panel)が「この押下は使われた」と
        -- 判断できるよう、実際に閉じられたときだけ印を置く。転んだ押下(まだ表示が
        -- 残っているかもしれない)や閉じるものが無かった押下は「使っていない」扱いにし、
        -- 購読側/ゲーム側へそのまま渡す。ここで無条件に印を置くと、閉じ損ねているのに
        -- indun_panel のトグルを無効化してしまう。
        g.esc_closed_ms = imcTime.GetAppTimeMS()
    else
        g.vlog("ESCAPE_PRESSED: close failed frame=%s err=%s", tostring(entry.frame), tostring(err))
    end
    -- 最後の 1 枚を閉じたら ESC をゲームへ返す
    g.esc_sync_scp()
end
