-- バウバスお知らせ
--
-- ボス名はこの dicID から引く(クライアントの言語で訳される)。
local BAUBAS_NAME_DICID = "@dicID_^*$ETC_20221117_069848$*^"
-- 出現する場所(魔法結社の議事堂)。マップ名も ClassName から引いて訳す。
local BAUBAS_MAP_CLASS = "ep14_2_d_castle_3"

-- 討伐のお知らせが「このボスのものか」を見る。
--
-- **韓国語のボス名だけで判定しないこと。** 出現側は dic のキー断片
-- (AppearFieldBoss_ep14_2_d_castle_3{name})で見ていて言語非依存なのに、討伐側だけ
-- 韓国語名の部分一致を要求していた。名前が訳されるクライアントでは一致せず、
-- **出現通知は出るのに討伐通知だけ出ない**(Issue #68)。
--
-- 引数がどの形で来るかはサーバー側の都合で、こちらからは確かめられない。そこで
-- 次の 3 通りのどれかで当てる。**広げる方向なので、今まで拾えていた経路は落ちない。**
local function baubas_in_message(str, name_text)
    -- 1. 名前が dicID のまま入っている
    if string.find(str, "ETC_20221117_069848", 1, true) then
        return true
    end
    -- 2. 訳すとボス名になる(dicID が別表記で入っている場合も拾える)
    if name_text and name_text ~= "" then
        local readable = dictionary.ReplaceDicIDInCompStr(str)
        if readable and string.find(readable, name_text, 1, true) then
            return true
        end
    end
    -- 3. 素の韓国語名がそのまま入っている(従来の判定)
    return string.find(str, "맹화의 바우바", 1, true) ~= nil
end

-- お知らせの本文。**素の韓国語文を ReplaceDicIDInCompStr へ渡しても訳されない。**
-- あれは compstr 中の dicID を差し替える関数で、dicID を含まない文には効かないため、
-- 以前は言語を問わず韓国語でチャットに出ていた(Issue #68)。
local function baubas_notice_text(kind, name_text, map_text)
    if kind == "appear" then
        if g.lang == "Japanese" then
            return string.format("%sにフィールドボス[%s]が出現しました。", map_text, name_text)
        elseif g.lang == "kr" then
            return string.format("%s에 필드 보스[%s]가 등장하였습니다.", map_text, name_text)
        end
        return string.format("Field boss [%s] has appeared in %s.", name_text, map_text)
    end
    if g.lang == "Japanese" then
        return string.format("フィールドボス[%s]が討伐されました。", name_text)
    elseif g.lang == "kr" then
        return string.format("필드 보스[%s]가 처치되었습니다.", name_text)
    end
    return string.format("Field boss [%s] has been defeated.", name_text)
end

function Mini_addons_NOTICE_ON_MSG_baubas(frame, msg)
    local _, _, str, _ = g.get_event_args(msg)
    if g.settings.baubas_call.use ~= 1 then
        return
    end
    local name_text = dictionary.ReplaceDicIDInCompStr(BAUBAS_NAME_DICID)
    if string.find(str, "AppearFieldBoss_" .. BAUBAS_MAP_CLASS .. "{name}") then
        local current_time = os.time()
        if g.last_baubas_time and (current_time - g.last_baubas_time < 60) then
            return
        end
        g.last_baubas_time = current_time
        imcSound.PlaySoundEvent("sys_tp_box_4")
        -- マップ名も決め打ちの韓国語ではなく、クラスから引いて訳す。
        -- 引けないときは場所を書かない(間違った言語で出すより、無いほうがよい)。
        local map_cls = GetClass("Map", BAUBAS_MAP_CLASS)
        local map_text = map_cls and dictionary.ReplaceDicIDInCompStr(map_cls.Name) or ""
        local clean_str = baubas_notice_text("appear", name_text, map_text)
        NICO_CHAT(string.format("{@st55_a}%s", clean_str))
        CHAT_SYSTEM(clean_str)
        Mini_addons_NOTICE_ON_MSG_GUILD(clean_str)
    elseif string.find(str, "{name}DisappearFieldBoss") and baubas_in_message(str, name_text) then
        local clean_str = baubas_notice_text("kill", name_text)
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
