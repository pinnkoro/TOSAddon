-- スキル錬成の連続実行。素の「スキル錬成」ボタンを、回している間だけ「停止」として働かせる。

-- 素の「スキル錬成」ボタン。**置換方式のフック**なので、引数は素と同じ (parent, ctrl) で
-- 受け、元の関数は g.FUNCS から自分で呼ぶ。
-- 素の COMMON_SKILL_ENCHANT_DO は確認を挟まずその場で ReqExecuteTx_Item を投げるため、
-- 呼び忘れると押しても何も起きない / 二重に呼ぶと 1 回の押下で 2 回撃つ
function Mini_addons_COMMON_SKILL_ENCHANT_DO(parent, ctrl)
    if g.settings.skill_reroll == 0 then
        g.FUNCS["COMMON_SKILL_ENCHANT_DO"](parent, ctrl)
        return
    end
    if skill_reroll.is_running() then
        core_g.vlog("mini_addons: スキル錬成 錬成ボタン(停止)が押されたので連続実行を止める")
        skill_reroll.stop("停止ボタンが押された")
        Mini_addons_skill_reroll_status(g.lang == "Japanese" and "停止しました" or "Stopped")
        return
    end
    local adv = ui.GetFrame(addon_name_lower .. "skill_reroll")
    if adv == nil or adv:IsVisible() == 0 then
        -- 連続で回すかどうかは**高度な設定を開いたかどうか**で決める。
        -- 開いていなければ素をそのまま呼ぶ(＝1 回だけ)
        core_g.vlog("mini_addons: スキル錬成 高度な設定を開いていないので素のまま 1 回だけ実行する")
        g.FUNCS["COMMON_SKILL_ENCHANT_DO"](parent, ctrl)
        return
    end
    local frame = ui.GetFrame("common_skill_enchant")
    local guid, obj = skill_reroll.item()
    if frame == nil or guid == nil then
        g.FUNCS["COMMON_SKILL_ENCHANT_DO"](parent, ctrl)
        return
    end
    -- **回し始める前に画面を写し直す。** 停止判定は表(g.skill_reroll_wanted)を見るので、
    -- 画面に入っているチェックが表へ届いていないと、当たっても止まらない
    skill_reroll.sync_from_screen()
    local wanted = {}
    for class_name, want in pairs(g.skill_reroll_wanted or {}) do
        if want.is_check == 1 then
            table.insert(wanted, string.format("%s(Lv%s以上)", tostring(class_name), tostring(want.min_lv or 0)))
        end
    end
    local repeat_count = GET_CHILD_RECURSIVELY(adv, "repeat_count")
    -- 停止条件は後から追いにくいので、回し始めに 1 回だけまとめて出す
    core_g.vlog("mini_addons: スキル錬成 開始(希望スキル=%s / リピート回数=%s)",
        #wanted == 0 and "指定なし" or table.concat(wanted, ", "),
        repeat_count ~= nil and tostring(repeat_count:GetText()) or "不明")
    adv:SetUserValue("COUNT", 0)
    -- **回す対象をここで固定する。** 回している最中にインベントリで別の品を右クリック /
    -- ドロップされると素がスロットを差し替えるので、見ずに続けると**乗せ替えた別の
    -- アイテムを黙って回して素材を溶かす**(「外れたら止める」のに「差し替えたら
    -- 止まらない」という非対称になる)
    adv:SetUserValue("TARGET_GUID", tostring(guid))
    -- 1 回目はすぐ撃つ。以降は結果が返るまで tick の関門で待つ。
    -- **今アイテムに付いているものは当たり扱いにしないこと。** 希望のスキルが既に
    -- 付いているアイテムだと、1 発も撃たないうちに「出ました」の確認と成功音が出る。
    -- 開始時の状態を見送る印にしておけば、**新しく出た結果からだけ**止まる。
    -- ただし**候補が既に出ているときは印を置かない**(それは前回の結果であって、
    -- 当たっているなら捨てる前に訊くべきもの)。
    -- 指紋の未設定値は "None"(skill_reroll.fingerprint が返す "a/b/c" 形とは重ならない)
    adv:SetUserValue("READY", "yes")
    adv:SetUserValue("FIRED_FP", "None")
    adv:SetUserValue("SKIP_FP", skill_reroll.candidate(obj) == nil and skill_reroll.fingerprint(obj) or "None")
    adv:SetUserValue("ASKING", "None")
    adv:SetUserValue("FIRED_AT", tostring(os.time()))
    frame:RunUpdateScript("Mini_addons_skill_reroll_tick", skill_reroll.TICK)
    -- 素の錬成ボタンを「停止」に変える(押されたら止められるように)
    skill_reroll.sync_do_button()
end

-- 連続実行を回している最中かどうか。合図を受ける 3 つのフックで共通に使う
skill_reroll.running_frame = function()
    if g.settings.skill_reroll == 0 then
        return nil
    end
    local adv = ui.GetFrame(addon_name_lower .. "skill_reroll")
    if adv == nil or adv:IsVisible() == 0 then
        return nil
    end
    local frame = ui.GetFrame("common_skill_enchant")
    if frame == nil or frame:HaveUpdateScript("Mini_addons_skill_reroll_tick") ~= true then
        -- 手で 1 回だけ錬成したときは何もしない
        return nil
    end
    return adv
end

-- 結果が返った。**「維持」だけはここで次へ進めてよい。**
-- 素は arg_num == 2(維持)のときだけ演出を出さずに return する(素の
-- SUCCESS_COMMON_SKILL_ENCHANT)。錬成の結果(1 / 3)は 0.8 秒の演出を出すので、
-- その終わり(COMMON_SKILL_ENCHANT_END)を待つ。ここで撃つと演出と重なる
function Mini_addons_skill_reroll_SUCCESS(my_frame, my_msg)
    local adv = skill_reroll.running_frame()
    if adv == nil then
        return
    end
    local _frame, _msg, _arg_str, arg_num = g.get_event_args(my_msg)
    if tonumber(arg_num) == 2 then
        adv:SetUserValue("READY", "yes")
        return
    end
    -- 演出の終わりを待つ。**その合図を取りこぼしたときの保険として時刻を控える**
    -- (下の関門が、これを見て遅れを打ち切る)
    adv:SetUserValue("EFFECT_AT", tostring(os.time()))
end

-- 素の演出(0.8 秒)が終わった合図。ここで「次を撃ってよい」を立てる
function Mini_addons_skill_reroll_END(my_frame, my_msg)
    local adv = skill_reroll.running_frame()
    if adv == nil then
        return
    end
    adv:SetUserValue("READY", "yes")
end

-- 素から失敗が返った。素材不足やサーバに弾かれたときなので、黙って回し続けない
function Mini_addons_skill_reroll_FAILED(my_frame, my_msg)
    local adv = skill_reroll.running_frame()
    if adv == nil then
        return
    end
    ui.SysMsg(g.lang == "Japanese" and "スキル錬成に失敗したため連続実行を止めました" or
                  "Stopped: the skill enchant failed")
    Mini_addons_skill_reroll_status(g.lang == "Japanese" and "失敗が返ったので止まりました" or
                                        "Stopped: the server returned a failure")
    skill_reroll.stop("素から失敗が返った")
end

-- 「続けますか？」の返事。
--   YES … この当たりを見送ってもう一度回す(候補があれば捨てる = 素の「維持」)
--   NO  … 止める。**候補はそのまま残す**ので、素の「変更」/「維持」で決められる
function mini_addons_p_skill_reroll_msgbox(answer)
    local adv = ui.GetFrame(addon_name_lower .. "skill_reroll")
    if adv == nil then
        -- 返事を待っている間に窓が畳まれた(× / 素の窓を閉じた)。
        -- ここを見ずに進むと nil のまま触って落ちる
        core_g.vlog("mini_addons: スキル錬成 確認の返事(%s)が来たが窓が無いので何もしない", tostring(answer))
        return
    end
    adv:SetUserValue("ASKING", "None")
    if answer ~= "YES" then
        Mini_addons_skill_reroll_status(g.lang == "Japanese" and "希望のスキルが出たので止まりました" or
                                            "Stopped: a wanted skill showed up")
        skill_reroll.stop("希望のスキルが出た(利用者が終了を選んだ)")
        return
    end
    local guid, obj = skill_reroll.item()
    if guid == nil then
        skill_reroll.stop("アイテムが無くなった")
        return
    end
    -- **この当たりを見送る印を置く。** 置かないと、次の tick で同じ当たりを見つけて
    -- 同じ確認を出し続ける(アイテムの中身が変われば印は合わなくなるので、
    --  次の結果からはまた止まる)
    adv:SetUserValue("SKIP_FP", skill_reroll.fingerprint(obj))
    adv:SetUserValue("READY", "yes")
    adv:SetUserValue("FIRED_FP", "None")
    adv:SetUserValue("FIRED_AT", tostring(os.time()))
    core_g.vlog("mini_addons: スキル錬成 当たりを見送って続行する")
    local frame = ui.GetFrame("common_skill_enchant")
    if frame ~= nil then
        frame:RunUpdateScript("Mini_addons_skill_reroll_tick", skill_reroll.TICK)
    end
    skill_reroll.sync_do_button()
end

-- 1 周ぶんの処理。**前の結果が返るまで進めない。**
-- 判定はアイテムの実データを読むので、結果より先に進むと古い状態を見て
-- 「まだ当たっていない」と誤判定し、当たった候補を維持で捨ててしまう
function Mini_addons_skill_reroll_tick(frame, ctrl)
    local jp = g.lang == "Japanese"
    if g.settings.skill_reroll == 0 then
        skill_reroll.stop("機能が OFF にされた")
        return 0
    end
    local adv = ui.GetFrame(addon_name_lower .. "skill_reroll")
    if adv == nil then
        skill_reroll.stop("高度な設定が畳まれた")
        return 0
    end
    -- **毎 tick 見ること。** 素は結果のたびに do_enchant を無効化するので、
    -- ここで戻さないと 1 周ごとに「停止」を押せない時間ができる
    skill_reroll.sync_do_button()
    if adv:GetUserValue("ASKING") == "yes" then
        -- 「続けますか？」の返事待ち。返事が来たら向こうが回し直す
        return 0
    end
    if frame == nil then
        frame = ui.GetFrame("common_skill_enchant")
    end
    if frame == nil or frame:IsVisible() == 0 then
        skill_reroll.stop("素の窓が閉じた")
        return 0
    end
    local guid, obj = skill_reroll.item()
    if guid == nil then
        ui.SysMsg(jp and "アイテムが外れたため連続実行を止めました" or "Stopped: the item is no longer set")
        skill_reroll.stop("アイテムがスロットから外れた")
        return 0
    end
    -- 回し始めに固定した対象と違う = 途中で別の品を乗せられた。**別の品を回さないこと**
    local target_guid = adv:GetUserValue("TARGET_GUID")
    if target_guid ~= "None" and target_guid ~= tostring(guid) then
        ui.SysMsg(jp and "アイテムが差し替えられたため連続実行を止めました" or
                      "Stopped: the item on the slot was replaced")
        Mini_addons_skill_reroll_status(jp and "アイテムが差し替えられたので止まりました" or
                                            "Stopped: the item was replaced")
        skill_reroll.stop("アイテムが差し替えられた")
        return 0
    end
    -- 前の結果が届くのを待つ関門。待つ理由は 2 つあり、**どちらも同じ見張りタイマーに
    -- 掛けること**(片方だけ先に return すると、見張りへ辿り着けず永久に空回りする)
    local fired_at = tonumber(adv:GetUserValue("FIRED_AT")) or 0
    local waiting = nil
    if adv:GetUserValue("READY") ~= "yes" then
        waiting = "結果の合図が来ない"
    elseif adv:GetUserValue("FIRED_FP") == skill_reroll.fingerprint(obj) then
        waiting = "アイテムの中身が前のまま変わらない"
    end
    if waiting ~= nil then
        -- 素の演出の終わり(COMMON_SKILL_ENCHANT_END)を取りこぼしたときの保険。
        -- 結果自体は届いている(= アイテムの中身が変わった)のに合図だけ来ないときは、
        -- 演出の 0.8 秒を大きく越えたところで先へ進める。**アイテムの中身が
        -- 変わっていることを必ず条件にすること**(でないと結果より先に撃つ)
        local effect_at = tonumber(adv:GetUserValue("EFFECT_AT")) or 0
        if waiting == "結果の合図が来ない" and effect_at > 0 and os.time() - effect_at >= 3 and
            adv:GetUserValue("FIRED_FP") ~= skill_reroll.fingerprint(obj) then
            core_g.vlog("mini_addons: スキル錬成 演出終わりの合図を取りこぼしたので先へ進める")
            adv:SetUserValue("READY", "yes")
            adv:SetUserValue("EFFECT_AT", "0")
            return 1
        end
        if os.time() - fired_at < skill_reroll.WATCHDOG then
            return 1
        end
        -- **ここで撃ち直さないこと。** 応答が遅れているだけだと、まだ飛んでいる 1 発と
        -- 重ねて撃つことになり、当たった候補を次の結果で潰す。黙って止まるのを避けるのが
        -- 目的なので、**撃たずに止めて知らせる**方に倒す(続けたければもう一度押せばよい)
        core_g.vlog("mini_addons: スキル錬成 停止(%s まま %s 秒経過 / 撃ち直しはしない)", waiting,
            tostring(skill_reroll.WATCHDOG))
        ui.SysMsg(jp and "スキル錬成の結果が返らないため連続実行を止めました。もう一度お試しください" or
                      "Stopped: no result came back from the server. Please try again")
        Mini_addons_skill_reroll_status(jp and "結果が返らないので止まりました" or "Stopped: no result came back")
        skill_reroll.stop(waiting)
        return 0
    end
    adv:SetUserValue("EFFECT_AT", "0")
    local state = skill_reroll.state(obj)
    if state == nil then
        ui.SysMsg(jp and "スキル錬成の状態を判定できないため連続実行を止めました" or
                      "Stopped: cannot read the skill enchant state")
        skill_reroll.stop("素の状態判定を引けない")
        return 0
    end
    -- 当たり判定。候補が出ていれば候補を、出ていなければ今付いているスキルを見る
    -- (状態 0 のアイテムは 1 回目でいきなりスキルが付き、候補は出ないため)
    local hit_name, hit_lv = skill_reroll.candidate(obj)
    local from_candidate = hit_name ~= nil
    if hit_name == nil then
        hit_name, hit_lv = skill_reroll.enchanted(obj)
    end
    local fingerprint = skill_reroll.fingerprint(obj)
    if hit_name ~= nil and skill_reroll.is_wanted(hit_name, hit_lv) and adv:GetUserValue("SKIP_FP") ~= fingerprint then
        local shown = string.format("%s Lv.%s", skill_reroll.skill_name(hit_name), tostring(hit_lv))
        core_g.vlog("mini_addons: スキル錬成 停止(希望スキル %s が%s)", shown,
            from_candidate and "候補に出た" or "付いた")
        imcSound.PlaySoundEvent("sys_transcend_success")
        Mini_addons_skill_reroll_status(string.format(jp and "希望のスキル %s が出ました" or
                                                          "A wanted skill showed up: %s", shown))
        -- **「続ける = この当たりを捨てる」と分かる文にすること。** 押し間違いで
        -- 当たりを潰すのが一番痛い操作なので、何が起きるかを書いておく
        local msg
        if jp then
            msg = string.format("{#FFFFFF}{ol}希望のスキル「%s」が%s。{nl}続けますか？{nl}%s", shown,
                from_candidate and "候補に出ました" or "付きました",
                from_candidate and "(続けるとこの候補を捨ててもう一度回します)" or
                    "(続けるともう一度回します)")
        else
            msg = string.format("{#FFFFFF}{ol}A wanted skill \"%s\" %s.{nl}Continue?{nl}%s", shown,
                from_candidate and "is now the candidate" or "is now attached",
                from_candidate and "(Continuing discards this candidate and rolls again)" or
                    "(Continuing rolls again)")
        end
        -- **返事待ちの間も「回している」扱いにする**(素のボタンは「停止」のまま)。
        -- 更新スクリプトは止めるので、次を撃つのは返事が来てから
        adv:SetUserValue("ASKING", "yes")
        ui.MsgBox(msg, string.format("%s_skill_reroll_msgbox('YES')", addon_name_lower),
            string.format("%s_skill_reroll_msgbox('NO')", addon_name_lower))
        return 0
    end
    if from_candidate then
        -- 当たりでない候補を捨てる = 素の「維持」(今付いているスキルをそのまま残す)。
        -- **素の関数を呼ぶこと**(送る引数は素の持ち物)
        adv:SetUserValue("READY", "no")
        adv:SetUserValue("FIRED_AT", tostring(os.time()))
        adv:SetUserValue("FIRED_FP", fingerprint)
        core_g.vlog("mini_addons: スキル錬成 候補 %s Lv.%s は希望ではないので維持で捨てる",
            tostring(skill_reroll.skill_name(hit_name)), tostring(hit_lv))
        COMMON_SKILL_ENCHANT_SELECT_BTN_LEFT(frame, nil)
        return 1
    end
    -- ここから 1 回撃つ。まずリピート上限
    local repeat_count = GET_CHILD_RECURSIVELY(adv, "repeat_count")
    local set_repeat = repeat_count ~= nil and tonumber(repeat_count:GetText()) or nil
    -- **空欄を放置しないこと。** tonumber("") は nil なので、上限判定が常に偽になって
    -- 止まらなくなる。0 以下は「1 回だけ」として扱う(素も 0 と 1 を区別しない)
    if set_repeat == nil then
        if repeat_count ~= nil then
            repeat_count:SetText("0")
        end
        core_g.vlog("mini_addons: スキル錬成 リピート回数が空だったので 0(＝1 回)を入れた")
        set_repeat = 1
    elseif set_repeat < 1 then
        set_repeat = 1
    elseif set_repeat > skill_reroll.REPEAT_MAX then
        set_repeat = skill_reroll.REPEAT_MAX
        repeat_count:SetText(tostring(set_repeat))
        core_g.vlog("mini_addons: スキル錬成 リピート回数が上限を超えていたので %d に丸めた",
            skill_reroll.REPEAT_MAX)
    end
    local count = adv:GetUserIValue("COUNT")
    -- == ではなく >=。回している最中に入力欄の数字を今の回数より小さくされると、
    -- == では一致する瞬間が来ずに止まらなくなる
    if count >= set_repeat then
        core_g.vlog("mini_addons: スキル錬成 停止(リピート上限 %d 回)", set_repeat)
        Mini_addons_skill_reroll_status(string.format(jp and "リピート上限(%d 回)に達しました" or
                                                          "Reached the repeat limit (%d)", set_repeat))
        skill_reroll.stop("リピート上限")
        return 0
    end
    if state ~= 0 and state ~= 1 then
        -- 候補が無いのに撃てない状態。素の判定が変わったときにここへ来る
        core_g.vlog("mini_addons: スキル錬成 停止(撃てない状態 state=%s)", tostring(state))
        skill_reroll.stop("撃てない状態")
        return 0
    end
    -- 素材を確保する。**素と同じ判定を通すこと**(必要量は素の表から作られている)。
    -- Mini_addons_COMMON_SKILL_ENCHANT_ADD_MAT は素の COMMON_SKILL_ENCHANT_ADD_MAT に
    -- アイコンの nil よけを足したもので、揃えば IS_READY を TRUE にする
    Mini_addons_COMMON_SKILL_ENCHANT_ADD_MAT()
    if frame:GetUserValue("IS_READY") ~= "TRUE" then
        core_g.vlog("mini_addons: スキル錬成 停止(素材が足りない / %d 回実施)", count)
        ui.SysMsg(jp and "素材が足りないので連続実行を終了しました" or "Stopped: not enough materials")
        Mini_addons_skill_reroll_status(string.format(jp and "素材が足りません(%d 回実施)" or
                                                          "Not enough materials (%d attempts done)", count))
        skill_reroll.stop("素材が足りない")
        return 0
    end
    -- 撃つ前の中身を控える。次の回でこれと同じなら結果がまだ届いていない
    adv:SetUserValue("READY", "no")
    adv:SetUserValue("FIRED_AT", tostring(os.time()))
    adv:SetUserValue("FIRED_FP", fingerprint)
    adv:SetUserValue("COUNT", count + 1)
    Mini_addons_skill_reroll_status(string.format(jp and "%d / %d 回目" or "%d / %d", count + 1, set_repeat))
    -- 素の窓にも残りを出す(高度な設定を閉じていても、あと何回で終わるか分かるように)
    skill_reroll.set_remain(string.format(jp and "残り %d 回" or "%d left", set_repeat - (count + 1)))
    g.FUNCS["COMMON_SKILL_ENCHANT_DO"](frame, nil)
    return 1
end
