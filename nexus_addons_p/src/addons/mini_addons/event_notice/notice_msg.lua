-- バウバスお知らせ
function Mini_addons_NOTICE_ON_MSG_baubas(frame, msg)
    local _, _, str, _ = g.get_event_args(msg)
    if g.settings.baubas_call.use ~= 1 then
        return
    end
    local name_text = dictionary.ReplaceDicIDInCompStr("@dicID_^*$ETC_20221117_069848$*^")
    if string.find(str, "AppearFieldBoss_ep14_2_d_castle_3{name}") then
        local current_time = os.time()
        if g.last_baubas_time and (current_time - g.last_baubas_time < 60) then
            return
        end
        g.last_baubas_time = current_time
        imcSound.PlaySoundEvent("sys_tp_box_4")
        local fmt = "마법 결사의 의사당에 필드 보스[{name}]가 등장하였습니다."
        local readable_str = dictionary.ReplaceDicIDInCompStr(fmt)
        local clean_str = string.gsub(readable_str, "{name}", name_text)
        NICO_CHAT(string.format("{@st55_a}%s", clean_str))
        CHAT_SYSTEM(clean_str)
        Mini_addons_NOTICE_ON_MSG_GUILD(clean_str)
    elseif string.find(str, "{name}DisappearFieldBoss") and string.find(str, "맹화의 바우바") then
        local fmt = "필드 보스[{name}]가 처치되었습니다."
        local readable_str = dictionary.ReplaceDicIDInCompStr(fmt)
        local clean_str = string.gsub(readable_str, "{name}", name_text)
        CHAT_SYSTEM(clean_str)
        Mini_addons_NOTICE_ON_MSG_GUILD(clean_str)
    end
end

function Mini_addons_NOTICE_ON_MSG_GUILD(clean_str)
    if g.settings.baubas_call.guild_notice == 0 then
        return
    end
    ui.Chat("/g " .. clean_str)
end

-- 押されたボタン自身の表示だけを切り替える。以前は設定画面を作り直していたが、
-- 検索で絞り込んだ状態が消えてしまうので、Mini_addons_GP_AUTOSTART_OPERATION と同じやり方に揃えた。
function Mini_addons_baubas_call_switch(frame, ctrl, str)
    AUTO_CAST(ctrl)
    if g.settings.baubas_call.guild_notice == 0 then
        g.settings.baubas_call.guild_notice = 1
        ctrl:SetText("{ol}{#FFFFFF}ON")
        ctrl:SetSkinName("test_red_button")
    else
        g.settings.baubas_call.guild_notice = 0
        ctrl:SetText("{ol}{#FFFFFF}OFF")
        ctrl:SetSkinName("test_gray_button")
    end
    Mini_addons_save_settings()
end
-- ブラックマーケットのお知らせ
function Mini_addons_NOTICE_ON_MSG(frame, msg, str, num)
    -- str の nil ガード。個別版ではこの関数は 3SEC の NOTICE_ON_MSG フックに上書きされて
    -- 実際には呼ばれていなかったが、登録簿をまとめ版へ寄せたことで連鎖の中に入り、
    -- 毎回のお知らせで通るようになった。ここで落とすとお知らせ表示ごと巻き込む。
    if g.settings.chat_system == 1 and str then
        if string.find(str, "StartBlackMarketBetween") then
            return
        end
    end
    g.FUNCS["NOTICE_ON_MSG"](frame, msg, str, num)
end

-- 素の CHAT_TEXT_LINKCHAR_FONTSET は「整形した文字列を返す」だけなので、素をそのまま
-- 呼べる。書き写す必要が無いので持たない(素が変わっても自動で追随する。Issue #53)。
-- ここでやるのは「消したいメッセージなら nil を返して表示させない」判定だけ。
function Mini_addons_CHAT_TEXT_LINKCHAR_FONTSET(frame, msg)
    if not msg then
        return
    end
    if g.settings.chat_system == 1 then
        if string.find(msg, "StartBlackMarketBetween") then
            return
        end
    end
    local origin = g.FUNCS["CHAT_TEXT_LINKCHAR_FONTSET"]
    if origin then
        return origin(frame, msg)
    end
    -- 控えが無い = 素へ戻せない。整形は諦めて元の文字列をそのまま出す(消すよりまし)。
    -- ここはチャットが 1 行来るたびに通り、origin は setup_hook のときに確定して
    -- セッション中変わらない。絞らないと同じ 1 行で verbose_log.txt が埋まる
    -- (CLAUDE.md「出しすぎない」)。状況は変わらないのでセッション中 1 回でよい。
    -- 印は出力できたときだけ立てる(core の g.vlog のコメント参照)。先に立てると
    -- ログ OFF の間に消費され、後から ON にしてもこの行が出ないままになる。
    if not g.logged_linkchar_origin_missing and
        core_g.vlog("mini_addons: CHAT_TEXT_LINKCHAR_FONTSET の素の実装が控えに無い") then
        g.logged_linkchar_origin_missing = true
    end
    return msg
end
