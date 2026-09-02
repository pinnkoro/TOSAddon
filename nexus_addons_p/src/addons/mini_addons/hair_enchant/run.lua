-- ALL ボタン。手持ちの魔法付与スクロールの数をリピート回数へ入れる。
-- 窓を開いたときの初期値は 1 にしてあるので、全部使うのはここを押したときだけ
function Mini_addons_hair_enchant_repeat_all(parent, ctrl)
    local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
    local high_hairenchant = ui.GetFrame("high_hairenchant")
    if reroll_option == nil or high_hairenchant == nil then
        return
    end
    local repeat_count = GET_CHILD_RECURSIVELY(reroll_option, "repeat_count")
    if repeat_count == nil then
        return
    end
    local scroll = session.GetInvItemByGuid(high_hairenchant:GetUserValue("Enchant"))
    local count = (scroll ~= nil and scroll.count and scroll.count > 0) and scroll.count or 1
    if count > HAIR_ENCHANT_REPEAT_MAX then
        count = HAIR_ENCHANT_REPEAT_MAX
    end
    repeat_count:SetText(tostring(count))
    -- 手で打ったときと同じく、素のリピート表示も合わせる
    SET_REPEAT_COUNT_TEXT(count)
    core_g.vlog("mini_addons: ヘアエンチャント ALL でリピート回数に手持ちのスクロール数 %d を入れた", count)
end

-- 素の「마법 부여」ボタン。**回している最中は「停止」として働かせる。**
-- 素の SEND_BTN は State が 0 のときに止める作りだが、その State が 0 になるのは
-- auto_run == 1 のときだけで、こちらのループでは立てられない(上のコメント参照)。
-- そこで押下をここで受けて、回っていれば止める。回っていなければ素へそのまま流す
function Mini_addons_HIGH_HAIRENCHANT_SEND_BTN(my_frame, my_msg)
    local frame, ctrl = g.get_event_args(my_msg)
    if g.settings.hair_enchant == 1 and hair_enchant_is_running() then
        core_g.vlog("mini_addons: ヘアエンチャント 付与ボタン(停止)が押されたので連続付与を止める")
        SET_REPEAT_COUNT_TEXT(0)
        hair_enchant_close_advanced()
        return
    end
    g.FUNCS["HIGH_HAIRENCHANT_SEND_BTN"](frame, ctrl)
end

function Mini_addons_HIGH_HAIRENCHANT_OK_BTN(my_frame, my_msg)
    local frame, ctrl = g.get_event_args(my_msg)
    -- 掛けたフックが bool=false(元の関数を呼ばない)なので、元の処理はここで自分で呼ぶ。
    -- **return を忘れないこと。** 素の HIGH_HAIRENCHANT_OK_BTN は確認ダイアログを挟まず
    -- その場で item.DoPremiumItemEnchantchip() を投げるため、下の else へ抜けると
    -- 1 回の押下で 2 回付与してしまう(この機能が OFF = 既定のときに必ず通る経路)
    if g.settings.hair_enchant == 0 then
        g.FUNCS["HIGH_HAIRENCHANT_OK_BTN"](frame, ctrl)
        return
    end
    local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
    if reroll_option and reroll_option:IsVisible() == 1 then
        -- **回し始める前に画面を写し直す。** 停止判定は g.need_options を見るので、
        -- 画面に入っているチェックが表へ届いていないと、当たっても止まらない
        -- (理由は g.hair_enchant_sync_from_screen)
        g.hair_enchant_sync_from_screen()
        -- 停止条件は後から追いにくいので、回し始めに 1 回だけ両方の設定を出す
        local high_hairenchant = ui.GetFrame("high_hairenchant")
        local rank_up = high_hairenchant and GET_CHILD_RECURSIVELY(high_hairenchant, "rank_up")
        local rank_until = reroll_option:GetUserValue("RANK_UNTIL")
        -- 連続で回すかどうかは**設定画面(この自前の窓)を開いたかどうか**で決める。
        -- 開いていなければ下の else で素をそのまま呼ぶ(＝1 回だけ)。
        -- 窓を開いた時点で連続付与の意思表示とみなすので、希望オプションも目標ランクも
        -- 未設定のまま回すこともできる(そのときはリピート回数だけが止める条件になる。
        -- 既定値は 0(＝1 回)なので、何もしなければ 1 回で終わる。全部使うのは
        --  ALL ボタンを押したときだけ)
        core_g.vlog(
            "mini_addons: ヘアエンチャント 開始(ランクアップ時に停止=%s / 目標ランク=%s / 演出を待たずに実行=%s)",
            (rank_up ~= nil and rank_up:IsChecked() == 1) and "ON" or "OFF",
            hair_enchant_rank_index(rank_until) == nil and "指定なし" or rank_until,
            reroll_option:GetUserValue("FAST") == "yes" and "ON" or "OFF")
        -- **回している間の目標ランクはここで控えた値を使う(RANK_GOAL)。**
        -- 画面側の RANK_UNTIL は、目標へ届いた時点の組み直し(プリセットの入れ直しや
        -- ドロップリストの作り直し。どちらも「今のランクより上」しか残さない)で
        -- "None" に落ちる。停止判定がそれを直に読んでいると、
        -- **ちょうど届いた瞬間に目標が消えて止まらなくなる**
        -- (素の「ランクアップ時に停止」は目標指定中に灰色にしてあるので、そちらでも
        --  止まらず、リピート上限か在庫切れまで回り続ける)
        reroll_option:SetUserValue("RANK_GOAL", rank_until)
        -- 1 回目はすぐ撃つ。以降は結果が返るまで下の関門で待つ。
        -- **前回の FIRED_FP / FIRED_AT も必ず消すこと。** 残っていると、見張りタイマーで
        -- 止まった後に押し直したとき、「指紋が前と同じ」かつ「FIRED_AT が古い」で
        -- 1 発も撃たないまま同じ停止メッセージを出す無限ループになる。
        -- 指紋の未設定値は "None"(大文字始まり)にする
        -- (hair_enchant_option_fingerprint が返しうる "none" と衝突させないため)
        --
        -- **「続けますか？」の『はい』から来たときは、既に 1 発撃った後**なので、
        -- 上の立て方をしてはいけない。関門(READY / FIRED_FP)が素通りになり、飛んでいる
        -- 1 発の結果が届く前に**振る前のオプションを見て止める**ことになる
        -- (「1 回で止まり、元のオプションを指して止まる」形で報告された)。
        -- 撃った後の状態は PENDING_FP で受け取る。**呼び出しから戻った後で立て直す形に
        -- しないこと。** RunUpdateScript がその場で 1 回走ると、立て直しより先に
        -- 1 tick 目が入って同じことが起きる
        local pending_fp = reroll_option:GetUserValue("PENDING_FP")
        if pending_fp ~= "None" then
            reroll_option:SetUserValue("READY", "no")
            reroll_option:SetUserValue("FIRED_FP", pending_fp)
            reroll_option:SetUserValue("ROLLED", "yes")
            reroll_option:SetUserValue("PENDING_FP", "None")
        else
            reroll_option:SetUserValue("READY", "yes")
            reroll_option:SetUserValue("FIRED_FP", "None")
            -- **この回でまだ 1 発も撃っていない目印。** 停止判定は振った結果に対して
            -- 行うものなので、これが "yes" になるまで希望オプションでは止めない
            reroll_option:SetUserValue("ROLLED", "no")
            -- **控えているランクも捨てる。** 前の対象のランクが残っていると、
            -- 別のアクセを乗せて回し始めた 1 tick 目で「ランクが変わった」と誤判定し、
            -- 「ランクアップ時に停止」が ON だと 1 発も撃たずに止まる
            reroll_option:SetUserValue("RANK", "None")
        end
        reroll_option:SetUserValue("FIRED_AT", tostring(os.time()))
        frame:RunUpdateScript("Mini_addons_HIGH_HAIRENCHANT_OK_BTN_", HAIR_ENCHANT_TICK)
        -- 素の付与ボタンを「停止」に変える(押されたら止められるように)
        hair_enchant_sync_send_button()
    else
        core_g.vlog("mini_addons: ヘアエンチャント 設定画面を開いていないので素のまま 1 回だけ実行する")
        g.FUNCS["HIGH_HAIRENCHANT_OK_BTN"](frame, ctrl)
    end
end

-- 連続付与を回している最中かどうか。合図を受ける 2 つのフックで共通に使う
local function hair_enchant_running_frame()
    if g.settings.hair_enchant == 0 then
        return nil
    end
    local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
    if reroll_option == nil or reroll_option:IsVisible() == 0 then
        return nil
    end
    -- 手で 1 回だけ付与したときは何もしない。
    -- **STATUS で見てはいけない。** STATUS が "is_repeat" になるのは 1 回目を撃ち終えた
    -- 後なので、「回し始めていきなり停止条件へ当たり、確認ダイアログの『はい』から
    -- 撃った 1 発」の間はまだ "None" のまま。ここで弾くと**その結果の合図だけが
    -- 捨てられ**、READY が立たないまま見張りタイマーの「結果の合図が来ない」で
    -- 止まる(希望オプションが既に付いている髪で回すと毎回そうなり、
    -- 「はい」を押しても 1 回で止まる形で出た)。
    -- 判定は更新スクリプトが載っているかを見る hair_enchant_is_running を使う
    if not hair_enchant_is_running() then
        return nil
    end
    return reroll_option
end

-- 結果を受けた時点の合図。**「演出を待たずに実行」が ON のときだけ**使う。
--
-- **HIGH_HAIRENCHANT_SUCEECD_RESULT ではなく SUCEECD の方を使うこと。**
-- こちらの停止判定はアイテムの実データ(obj["HatPropName_1..3"])を読むので、
-- それが更新される前に合図を出すと、古い状態を見て「まだ付いていない」と誤判定し、
-- 当たりを潰してもう 1 回撃つ。SUCEECD は HIGH_HAIRENCHANT_UPDATE_ITEM_OPTION を
-- 通す側なので、ここまで来ていればアイテムの状態は新しいと分かる。
-- (SUCEECD_RESULT は表示用の値を引数で受け取るだけで、実データの更新とは別)
function Mini_addons_HIGH_HAIRENCHANT_SUCEECD(my_frame, my_msg)
    local reroll_option = hair_enchant_running_frame()
    if reroll_option == nil or reroll_option:GetUserValue("FAST") ~= "yes" then
        return
    end
    reroll_option:SetUserValue("READY", "yes")
end

-- 素の演出が終わって HoldUI が解けた合図。ここで「次を撃ってよい」を立てる。
-- 素より先に撃つと演出と HoldUI が重なるので、結果受信(HIGH_HAIRENCHANT_SUCEECD_RESULT)
-- ではなくここを使っている。1 回あたり EFFECT_DURATION(0.5秒)ぶん譲る代わりに、
-- 素の見た目を一切崩さない
function Mini_addons__HIGH_HAIRENCHANT_SUCCESS(my_frame, my_msg)
    local reroll_option = hair_enchant_running_frame()
    if reroll_option == nil then
        return
    end
    -- 「演出を待たずに実行」が ON なら、ひとつ手前の合図で既に立っている(二重でも害は無い)
    reroll_option:SetUserValue("READY", "yes")
end

function Mini_addons_HIGH_HAIRENCHANT_OK_BTN_(frame, ctrl)
    if frame == nil then
        frame = ui.GetFrame("high_hairenchant")
    end
    frame = frame:GetTopParentFrame()
    local enchantGuid = frame:GetUserValue("Enchant")
    local itemIES = frame:GetUserValue("itemIES")
    if "None" == itemIES or "None" == enchantGuid then
        return 0
    end
    local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
    if not reroll_option and reroll_option:IsVisible() == 0 and reroll_option:GetUserValue("STATUS") == "None" then
        item.DoPremiumItemEnchantchip(itemIES, enchantGuid)
        return 0
    end
    -- ここから下は「1 回分」の処理。**前の結果が返るまで通さない。**
    -- 判定は obj["HatPropName_1..3"](アイテムの今のオプション)を読むので、結果より先に
    -- 進むと古い状態を見て「まだ付いていない」と誤判定し、当たったロールを潰して
    -- もう 1 回撃つことになる。以前は 1.0 秒固定で撃っていたため、応答がそれより
    -- 遅い環境では実際にこれが起きうる作りだった。
    -- 合図は Mini_addons__HIGH_HAIRENCHANT_SUCCESS(素の演出が終わる所)が立てる
    -- 前の結果が届くのを待つ関門。待つ理由は 2 つあり、**どちらも同じ見張りタイマーに
    -- 掛けること**(片方だけ先に return すると、見張りへ辿り着けず永久に空回りする)。
    --
    -- (1) 合図(READY)がまだ来ていない
    -- (2) 「演出を待たずに実行」で、合図は来たがアイテムの中身が前のまま。
    --     このモードは素の演出を待たずに合図を受けるぶん、実データの更新より合図が
    --     先に来る余地がある。そのまま進むと古い状態で「まだ付いていない」と誤判定し、
    --     当たりを潰してもう 1 回撃つ(実際に報告された)。指紋が変わるまで待てば、
    --     合図の順序が実際どうであっても成立する
    local waiting = nil
    if reroll_option:GetUserValue("READY") ~= "yes" then
        waiting = "結果の合図が来ない"
    elseif reroll_option:GetUserValue("FAST") == "yes" and
        hair_enchant_option_fingerprint(itemIES) == reroll_option:GetUserValue("FIRED_FP") then
        -- 振り直しで偶然まったく同じ 3 つが出たときもここに入るが、下の見張りが
        -- 止めるので当たりを潰すことはない(止まるだけ)
        waiting = "オプションが前のまま変わらない"
    end
    if waiting ~= nil then
        local fired_at = tonumber(reroll_option:GetUserValue("FIRED_AT")) or 0
        if os.time() - fired_at < HAIR_ENCHANT_WATCHDOG then
            return 1
        end
        -- **ここで撃ち直さないこと。**
        -- 応答が遅れているだけだと、まだ飛んでいる 1 発と重ねて撃つことになる。
        -- そうなると「希望オプションが付いた結果」が届いて確認ダイアログを出した直後に、
        -- 余分な 1 発の結果が届いて振り直され、当たりが消える(実際に報告された)。
        -- 黙って止まるのを避けるのが目的なので、**撃たずに止めて知らせる**方に倒す。
        -- 続けたければもう一度押せばよく、素材も当たりも失わない
        core_g.vlog(
            "mini_addons: ヘアエンチャント 停止(%s まま %s 秒経過 / 撃ち直しはしない / READY=%s STATUS=%s ASKING=%s)",
            waiting, tostring(HAIR_ENCHANT_WATCHDOG), tostring(reroll_option:GetUserValue("READY")),
            tostring(reroll_option:GetUserValue("STATUS")), tostring(reroll_option:GetUserValue("ASKING")))
        ui.SysMsg(g.lang == "Japanese" and
                      "魔法付与の結果が返らないため連続付与を止めました。もう一度お試しください" or
                      "Stopped: no result came back from the server. Please try again")
        reroll_option:SetUserValue("REPERT", "None")
        reroll_option:SetUserValue("STATUS", "None")
        return 0
    end
    reroll_option:SetUserValue("READY", "no")
    reroll_option:SetUserValue("FIRED_AT", tostring(os.time()))
    local repeatCount = GET_CHILD_RECURSIVELY(frame, "repeatCount")
    local repeat_count = GET_CHILD_RECURSIVELY(reroll_option, "repeat_count")
    local set_repeat_num = tonumber(repeat_count:GetText())
    -- **空欄を放置しないこと。** tonumber("") は nil なので、下の上限判定
    -- (count >= set_repeat_num)が常に偽になって止まらなくなるうえ、
    -- 表示の set_repeat_num - count が nil の引き算で落ちる。
    -- 0 以下は「1 回だけ」として扱う。素も 0 と 1 を区別しない(cnt > 1 のときだけ続行)
    -- ので、初期値の 0 をそのまま押したら 1 回、という素と同じ動きになる。
    -- **空欄は入力欄にも 0 を書き戻す。** 空欄のままだと、いくつで止まるのか
    -- 画面から読み取れない(以前は手持ちのスクロール数と解釈していたが、
    -- うっかり全部溶ける側に倒れるのでやめた。全部使いたいときは ALL ボタン)
    if set_repeat_num == nil then
        repeat_count:SetText("0")
        core_g.vlog("mini_addons: ヘアエンチャント リピート回数が空だったので 0(＝1 回)を入れた")
    end
    if set_repeat_num == nil or set_repeat_num < 1 then
        set_repeat_num = 1
    end
    -- 上限を掛ける前に入れた値や、古いプリセットに入っている値への保険
    if set_repeat_num > HAIR_ENCHANT_REPEAT_MAX then
        set_repeat_num = HAIR_ENCHANT_REPEAT_MAX
        repeat_count:SetText(tostring(set_repeat_num))
        core_g.vlog("mini_addons: ヘアエンチャント リピート回数が上限を超えていたので %d に丸めた",
            HAIR_ENCHANT_REPEAT_MAX)
    end
    local count = reroll_option:GetUserIValue("REPERT")
    -- == ではなく >=。回している最中に入力欄の数字を今の回数より小さくされると、
    -- == では一致する瞬間が来ずに止まらなくなる
    if count >= set_repeat_num then
        core_g.vlog("mini_addons: ヘアエンチャント 停止(リピート上限 %s 回)", tostring(set_repeat_num))
        repeatCount:SetTextByKey("value", string.format("%s : %d", ClMsg("REPEAT"), set_repeat_num - count))
        reroll_option:SetUserValue("REPERT", "None")
        reroll_option:SetUserValue("STATUS", "None")
        return 0
    end
    -- **スクロールを使い切ったら、上限に届いていなくてもここで終わり。**
    -- 素は 1 スタック使い切ると HIGH_HAIRENCHANT_SUCEECD で Enchant を次のスタックへ
    -- 差し替える。それでも引けない = 本当に在庫が尽きたとき。
    -- 放っておくと引けない GUID のまま撃ち続け、結果が返らないまま見張りタイマーの
    -- 「結果が返らない」で止まることになり、何が起きたのか分からない
    -- (リピート回数に手持ちより多い数を入れたときや、その数を保存したプリセットを
    --  読み込んだときに必ず通る経路)
    if session.GetInvItemByGuid(enchantGuid) == nil then
        core_g.vlog("mini_addons: ヘアエンチャント 停止(魔法付与スクロールを使い切った / %d 回実施)", count)
        repeatCount:SetTextByKey("value", string.format("%s : %d", ClMsg("REPEAT"), 0))
        reroll_option:SetUserValue("REPERT", "None")
        reroll_option:SetUserValue("STATUS", "None")
        ui.SysMsg(g.lang == "Japanese" and "魔法付与スクロールを使い切ったので連続付与を終了しました" or
                      "Stopped: you have run out of enchant scrolls")
        return 0
    end
    local invItem = session.GetInvItemByGuid(itemIES)
    if nil == invItem then
        return
    end
    local obj = GetIES(invItem:GetObject())
    local item_grade, item_rank = get_current_enchant_item_grade_and_rank()
    local befor_rank = reroll_option:GetUserValue("RANK")
    local rank_up = GET_CHILD_RECURSIVELY(frame, "rank_up")
    -- 素の "ランクアップ時に停止"。素は HIGH_HAIRENCHANT_SUCEECD_RESULT で
    -- GET_CHECKBOX_STATE() を見て判定しているが、自前のループを回している間は
    -- そちらが実質発火しない(素の判定は hairenchant_option 側のリピート数を見るが、
    -- この機能が ON のときはその窓を閉じている)ので、ここで見て同じ挙動にする。
    -- **条件に入れ忘れると、チェックの ON / OFF に関わらず必ず止まる**
    -- (実際にそうなっていて「チェックボックスが効かない」と報告された)
    local rank_check = rank_up ~= nil and rank_up:IsChecked() == 1
    -- 目標ランク(ドロップリスト)。指定があるときはそちらが優先で、素のチェックは見ない。
    -- 「A まで回す」と言っているのに途中の D → C で止まっては指定した意味が無いため
    -- 画面側(RANK_UNTIL)ではなく、回し始めに控えた目標を読む(理由は OK_BTN 側のコメント)
    local rank_until = reroll_option:GetUserValue("RANK_GOAL")
    local rank_until_index = hair_enchant_rank_index(rank_until)
    local now_index = hair_enchant_rank_index(item_rank)
    local ranked_up = befor_rank ~= "None" and item_rank ~= befor_rank
    if rank_until_index ~= nil then
        if now_index ~= nil and now_index >= rank_until_index then
            core_g.vlog("mini_addons: ヘアエンチャント 停止(目標ランク %s へ到達 %s → %s)",
                tostring(rank_until), tostring(befor_rank), tostring(item_rank))
            imcAddOn.BroadMsg("NOTICE_Dm_TrapPlus", "{st41b}" .. ClMsg("MagicAutoRankUpMessage"), 5.0)
            imcSound.PlaySoundEvent("sys_transcend_success")
            reroll_option:SetUserValue("REPERT", "None")
            reroll_option:SetUserValue("STATUS", "None")
            Mini_addons_HIGH_HAIRENCHANT_CLOSE_BTN(nil, "")
            return 0
        end
        if ranked_up then
            core_g.vlog("mini_addons: ヘアエンチャント ランクアップ %s → %s(目標 %s には未到達なので続行)",
                tostring(befor_rank), tostring(item_rank), tostring(rank_until))
        end
    elseif ranked_up then
        if rank_check then
            core_g.vlog("mini_addons: ヘアエンチャント 停止(ランクアップ %s → %s / 素のランクアップ時に停止)",
                tostring(befor_rank), tostring(item_rank))
            imcAddOn.BroadMsg("NOTICE_Dm_TrapPlus", "{st41b}" .. ClMsg("MagicAutoRankUpMessage"), 5.0)
            imcSound.PlaySoundEvent("sys_transcend_success")
            reroll_option:SetUserValue("REPERT", "None")
            reroll_option:SetUserValue("STATUS", "None")
            Mini_addons_HIGH_HAIRENCHANT_CLOSE_BTN(nil, "")
            return 0
        end
        core_g.vlog("mini_addons: ヘアエンチャント ランクアップ %s → %s したが停止設定が OFF なので続行",
            tostring(befor_rank), tostring(item_rank))
    end
    if ranked_up then
        -- 止めずに続けるので、上がったランクで一覧を組み直す(組み直す理由は
        -- hair_enchant_build_reroll_body のコメントを参照)。ここを飛ばすと、
        -- 上のランクでしか出ないオプション(ALLSKILL / MSPD など)を選べないまま
        -- 古い数値範囲を見せ続けることになる。
        -- 印で比べる方(監視スクリプトと同じ経路)を通すので、先に組み直されていれば空振りする
        hair_enchant_refresh_if_changed(reroll_option)
    end
    reroll_option:SetUserValue("RANK", item_rank)
    function mini_addons_hair_enchant_msgbox(boolean, frame_name, itemIES, enchantGuid)
        local frame = ui.GetFrame(frame_name)
        frame:StopUpdateScript("Mini_addons_HIGH_HAIRENCHANT_OK_BTN_")
        local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
        if reroll_option == nil then
            -- 返事を待っている間に窓が畳まれた(停止ボタン / × / 素の窓を閉じた)。
            -- 「続ける」でも、もう回すものが無いので何もしない。
            -- ここを見ずに進むと reroll_option が nil のまま触って落ちる
            core_g.vlog("mini_addons: ヘアエンチャント 確認の返事(%s)が来たが窓が無いので何もしない",
                tostring(boolean))
            return
        end
        reroll_option:SetUserValue("ASKING", "None")
        if boolean == "YES" then
            -- **撃つ前の指紋を控えて、OK_BTN へ渡してから撃つこと。**
            -- OK_BTN は「1 回目はすぐ撃つ」ために READY / FIRED_FP を素通りの値へ
            -- 立てるので、ここで撃った 1 発を知らせないと、その結果が届く前に
            -- 1 tick 目が動いて**振る前のオプションで止める**
            -- (呼び出しから戻った後で立て直す形だと、RunUpdateScript がその場で
            --  1 回走ったときに間に合わない)
            reroll_option:SetUserValue("PENDING_FP", hair_enchant_option_fingerprint(itemIES))
            item.DoPremiumItemEnchantchip(itemIES, enchantGuid)
            reroll_option:SetUserValue("REPERT", reroll_option:GetUserIValue("REPERT") + 1)
            Mini_addons_HIGH_HAIRENCHANT_OK_BTN(nil, "HIGH_HAIRENCHANT_OK_BTN")
            -- OK_BTN が窓を見ずに素へ流した経路(設定画面が閉じている)への後始末。
            -- 残すと次に回し始めたときへ持ち越して、1 発目の関門が誤って効く
            reroll_option:SetUserValue("PENDING_FP", "None")
        else
            Mini_addons_HIGH_HAIRENCHANT_CLOSE_BTN(nil, "")
        end
    end
    local margin = reroll_option:GetMargin()
    reroll_option:SetMargin(margin.left, margin.top, 905, margin.bottom)
    local map_frame = ui.GetFrame("map")
    local width = map_frame:GetWidth()
    local retio = width / ui.GetClientInitialWidth()
    -- 目標ランクを指定しているときは希望オプションで止めない。
    -- 全スキル系(下の ALLSKILL_ 分岐)も同じく素通りさせる
    --
    -- **この回でまだ 1 発も撃っていないなら、ここは見ない。** 停止判定は
    -- obj["HatPropName_1..3"](＝今アイテムに付いているもの)を読むので、振る前に見ると
    -- **元から付いていたオプションを指して、1 発も撃たないまま止まる**
    -- (「ロール 1 回で停止し、元のオプションを参照して止まった」として報告された)。
    -- 撃つのはこのすぐ下なので、飛ばしても 1 回ぶん回るだけで空撃ちにはならない
    local rolled = reroll_option:GetUserValue("ROLLED") == "yes"
    if not rolled then
        core_g.vlog(
            "mini_addons: ヘアエンチャント まだ 1 発も撃っていないので、今付いているオプション(%s)では止めない",
            tostring(hair_enchant_option_fingerprint(itemIES)))
    end
    for key, value in pairs(g.need_options) do
        if rolled and rank_until_index == nil and value.is_check == 1 then
            local target_text = value.text
            for i = 1, 3 do
                local propName = "HatPropName_" .. i
                local propValue = "HatPropValue_" .. i
                if obj[propValue] ~= 0 and obj[propName] ~= "None" then
                    local yes_scp = string.format("mini_addons_hair_enchant_msgbox('%s','%s','%s','%s')", "YES",
                        frame:GetName(), itemIES, enchantGuid)
                    local no_scp = string.format("mini_addons_hair_enchant_msgbox('%s','%s','%s','%s')", "NO",
                        frame:GetName(), itemIES, enchantGuid)
                    local msg = string.format(g.lang == "Japanese" and "{#FFFFFF}{ol}続けますか？" or
                                                  "{#FFFFFF}{ol}Do you want to continue? ")
                    if string.find(obj[propName], "ALLSKILL_") == nil then
                        if target_text == ScpArgMsg(obj[propName]) then
                            core_g.vlog("mini_addons: ヘアエンチャント 停止(希望オプション %s が付いた)",
                                tostring(target_text))
                            if margin.right == 905 then
                                reroll_option:SetMargin(margin.left, margin.top, 1150 * retio, margin.bottom)
                            end
                            repeatCount:SetTextByKey("value",
                                string.format("%s : %d", ClMsg("REPEAT"), set_repeat_num - count))
                            local befor_rank = reroll_option:GetUserValue("RANK")
                            reroll_option:SetUserValue("ASKING", "yes")
                            ui.MsgBox(msg, yes_scp, no_scp)
                            return 0
                        end
                    else
                        -- 全スキル系は付く名前が ALLSKILL_<職業> で、チェックボックス側の
                        -- クラス名 ALLSKILL とは一致しない。そのため本家から「チェックの
                        -- 有無に関わらず止める」挙動をそのまま引き継いでいる
                        core_g.vlog("mini_addons: ヘアエンチャント 停止(全スキル系 %s が付いた)",
                            tostring(obj[propName]))
                        if margin.right == 905 then
                            reroll_option:SetMargin(margin.left, margin.top, 1150 * retio, margin.bottom)
                        end
                        repeatCount:SetTextByKey("value",
                            string.format("%s : %d", ClMsg("REPEAT"), set_repeat_num - count))
                        reroll_option:SetUserValue("ASKING", "yes")
                        ui.MsgBox(msg, yes_scp, no_scp)
                        return 0
                    end
                end
            end
        end
    end
    reroll_option:SetGravity(ui.RIGHT, ui.TOP)
    local margin = reroll_option:GetMargin()
    reroll_option:SetMargin(margin.left, margin.top, 905, margin.bottom)
    reroll_option:SetPos(reroll_option:GetX(), frame:GetY())
    -- 撃つ前の中身を控える。次の回でこれと同じなら結果がまだ届いていない
    reroll_option:SetUserValue("FIRED_FP", hair_enchant_option_fingerprint(itemIES))
    -- ここから先の結果は「振った結果」なので、次の回から希望オプションで止めてよい
    reroll_option:SetUserValue("ROLLED", "yes")
    item.DoPremiumItemEnchantchip(itemIES, enchantGuid)
    repeatCount:SetTextByKey("value", string.format("%s : %d", ClMsg("REPEAT"), set_repeat_num - count))
    reroll_option:SetUserValue("REPERT", reroll_option:GetUserIValue("REPERT") + 1)
    reroll_option:SetUserValue("STATUS", "is_repeat")
    return 1
end
