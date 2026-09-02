-- Party Icon Only ここから
--
-- パーティ情報(partyinfo)を「掴み代 + 職業アイコンの縦一列」にして、当たり判定も
-- その範囲へ縮める。
--
-- 素の partyinfo は controlset "partyinfo"(700 x 80)を人数分並べる作りで、frame 側は
-- partyinfo.xml の `<input ... moveable="true" hittestframe="true">`。名前・HP/SP・
-- レベル・バフ欄まで含めた**横 700px の帯がそのまま当たり判定**になるので、画面左側の
-- 広い範囲でクリックが 3D 画面へ抜けない。
--
-- ここでは行の中身をアイコン(jobportrait_bg)だけにして、controlset と frame を
-- アイコンと同じ大きさへ縮める。**frame の矩形 = 掴み代 + アイコンの列**になるので、
-- その外を押した入力は素どおり下へ抜ける。
--
-- **見出し(titlegbox)は消さずに 50x26 の掴み代として残す。** 掴めるのは
-- 「frame の当たり判定がある範囲のうち、hittest を持つコントロールが乗っていない所」で、
-- titlegbox は hittestbox="false" なので押すと下の frame が受けて動かせる。frame を
-- アイコンの列まで縮めると残りはアイコンで埋まってしまうため、**この帯を残さないと
-- ウィンドウを動かす手段が無くなる**(hittestframe を落とすと今度は掴めなくなる)。

-- controlset "partyinfo" の jobportrait_bg と同じ大きさ。行と frame の幅・高さをこれに合わせる。
local PARTY_ICON_ONLY_SIZE = 50
-- 掴み代(titlegbox)の高さ。素の 26 をそのまま使う。
local PARTY_ICON_ONLY_TITLE_H = 26
-- titlegbox の中の partyinfobutton の幅。見出しの文字はこれを避けて置く。
local PARTY_ICON_ONLY_BUTTON_W = 24
-- controlset "partyinfo" の leader_img の幅。素は margin "27 4 0 0" に置いているので、
-- 行を 50px 幅へ縮めると右が 3px はみ出て切れる。これを使って右上へ寄せ直す。
local PARTY_ICON_ONLY_LEADER_W = 26

-- 行の中で残す子。**ここに無い子は隠す。** 名指しで隠す形にしないのは、他のアドオンが
-- 足した子(素の controlset に無いもの)までまとめて畳むため。
--   jobportrait … jobportrait_bg の子なので、親を残せば一緒に出る
--   leader_img  … **素が出し入れしている**(パーティ長の行だけ ShowWindow(1))。
--                 こちらから表示を触ると全員にリーダーの印が付くので、残す側に置く
local PARTY_ICON_ONLY_KEEP = {
    jobportrait_bg = true,
    leader_img = true
}

function party_icon_only_on_init()
    if g.settings.party_icon_only.use == 0 then
        return
    end
    -- 素が partyinfo を組み直す経路。組み直した直後に畳み直す。
    g.register_msg("PARTY_UPDATE", "Party_icon_only_apply")
    g.register_msg("PARTY_INST_UPDATE", "Party_icon_only_apply")
    g.register_msg("PARTY_BUFFLIST_UPDATE", "Party_icon_only_apply")
    -- **素の組み立ては同期で畳み直す。** SET_PARTYINFO_ITEM が最後に
    -- `frame:Resize(frame:GetOriginalWidth(), count * 行の高さ)` を呼ぶので、ここを
    -- 取りこぼすと**見た目は畳んだままなのに、当たり判定だけ横 700px・1 行ぶん余計な
    -- 高さへ戻る**という一番分かりにくい形になる(メッセージ経由だと、配信の順によっては
    -- 素の Resize より先に来てしまう)。
    --
    -- **ON_PARTYINFO_BUFFLIST_UPDATE には掛けないこと。** あちらは mini_addons が
    -- 既に g.setup_hook で掴んでいる。同じ名前を重ねて掛けると、控え(_REPLACE_)が
    -- 名前ごとに 1 つしか無いので後から掛けた側も「素」を控えることになり、
    -- **mini_addons の PT バフ表示切替が黙って落ちる**。
    g.setup_hook(Party_icon_only_ON_PARTYINFO_UPDATE, "ON_PARTYINFO_UPDATE")
    -- 上で拾えない経路の受け皿(素の PARTYINFO_CONTROL_INIT / hud スキンの適用など)。
    local root = ui.GetFrame("_nexus_addons_p")
    if not root then
        return
    end
    root:SetVisible(1)
    local timer = root:CreateOrGetControl("timer", "party_icon_only_timer", 0, 0)
    AUTO_CAST(timer)
    timer:SetUpdateScript("Party_icon_only_apply")
    timer:Start(0.5)
    -- 職業構成はキャラを跨ぐと変わる。初期化のたびに引き直す(判定は Party_icon_only_fold_title)。
    g.party_icon_only_summon_ui = nil
    g.party_icon_only_logged = nil
end

-- 機能 OFF にされたときの後始末(core/20_lifecycle.lua が use==0 のとき on_init の代わりに呼ぶ)。
-- **順序が要る**: 先に止めないと、素へ戻した直後に次の tick がまた畳んでしまう。
function party_icon_only_on_teardown()
    g.stop_timer("party_icon_only_timer")
    Party_icon_only_restore()
end

-- 置換方式フック。**素を必ず呼び、戻り値もそのまま返す**(CLAUDE.md)。
function Party_icon_only_ON_PARTYINFO_UPDATE(frame, msg, arg_str, arg_num)
    local origin = g.FUNCS["ON_PARTYINFO_UPDATE"]
    local results
    if origin then
        results = {origin(frame, msg, arg_str, arg_num)}
    else
        g.vlog("{#FF6347}party_icon_only: ON_PARTYINFO_UPDATE の素の実装が控えに無い{/}")
    end
    Party_icon_only_apply()
    if results then
        return table.unpack(results)
    end
end

-- 余白の控え。GetMargin が返す値は呼び出しごとに作り直されるとは限らないので、
-- 4 辺を数値で写し取っておく。
function Party_icon_only_margin_of(ctrl)
    local rect = ctrl:GetMargin()
    return {
        left = rect.left,
        top = rect.top,
        right = rect.right,
        bottom = rect.bottom
    }
end

-- 控えた余白を戻す。控えが無ければ何もしない(= 一度も畳んでいない)。
function Party_icon_only_restore_margin(ctrl, margin)
    if ctrl and margin then
        ctrl:SetMargin(margin.left, margin.top, margin.right, margin.bottom)
    end
end

-- 縦に積み直す。素の PARTYINFO_CONTROLSET_AUTO_ALIGN と同じく margin で動かす
-- (GBOX_AUTO_ALIGN の alignByMargin = true と同じやり方)。left を渡すと左寄せも変える。
function Party_icon_only_move_y(ctrl, y, left)
    local rect = ctrl:GetMargin()
    if left == nil then
        left = rect.left
    end
    ctrl:SetMargin(left, y, rect.right, rect.bottom)
end

-- 行 1 つをアイコンだけにする。
function Party_icon_only_fold_row(ctrl_set)
    AUTO_CAST(ctrl_set)
    for i = 0, ctrl_set:GetChildCount() - 1 do
        local child = ctrl_set:GetChildByIndex(i)
        if child and not PARTY_ICON_ONLY_KEEP[child:GetName()] and child:IsVisible() == 1 then
            child:ShowWindow(0)
        end
    end
    local icon = GET_CHILD(ctrl_set, "jobportrait_bg", "ui::CPicture")
    if icon then
        -- 素は margin "17 4 0 0" で行の中ほどに置いている。行そのものをアイコンの
        -- 大きさへ縮めるので、余白を落として左上へ寄せる。
        icon:SetMargin(0, 0, 0, 0)
    end
    local leader = GET_CHILD(ctrl_set, "leader_img", "ui::CPicture")
    if leader then
        -- アイコンの右上へ。**表示の出し入れは素に任せる**(パーティ長の行だけ出る)。
        leader:SetMargin(PARTY_ICON_ONLY_SIZE - PARTY_ICON_ONLY_LEADER_W, 0, 0, 0)
    end
    ctrl_set:Resize(PARTY_ICON_ONLY_SIZE, PARTY_ICON_ONLY_SIZE)
end

-- 見出し(titlegbox)を掴み代に仕立てる。戻り値は「最初の行を置く y」。
function Party_icon_only_fold_title(title_gbox)
    AUTO_CAST(title_gbox)
    local text = GET_CHILD(title_gbox, "buttontitle")
    if not g.party_icon_only_title_margin then
        -- 戻すときのために素の余白を控える。上は素の AUTO_ALIGN が入れ直してくれるが、
        -- 左右と下は誰も戻さないので、こちらで覚えておく。
        g.party_icon_only_title_margin = Party_icon_only_margin_of(title_gbox)
        if text then
            g.party_icon_only_text_margin = Party_icon_only_margin_of(text)
        end
    end
    if title_gbox:IsVisible() == 0 then
        title_gbox:ShowWindow(1)
    end
    title_gbox:EnableDrawFrame(1)
    title_gbox:Resize(PARTY_ICON_ONLY_SIZE, PARTY_ICON_ONLY_TITLE_H)
    Party_icon_only_move_y(title_gbox, 0, 0)
    -- 召喚獣 UI を持つクラスでは、この中の partyinfobutton が
    -- 「パーティ情報 ⇄ 召喚獣情報」の切り替えになっている。ボタンの出し入れは素に任せるが、
    -- **出ているときは見出しの文字がその下へ潜らないように幅を空ける**。
    -- 判定は素の IS_NEED_SUMMON_UI()。**ボタンの IsVisible() では見ない**
    -- (親ごと隠した後は当てにならない)。毎 tick 呼ぶと GetClassList("Job") を
    -- 舐め直すことになるので、初期化ごとに 1 回だけ引く。
    if g.party_icon_only_summon_ui == nil then
        -- **関数そのものを pcall へ渡さないこと。** 呼び出しの形になっていないと
        -- docs/vanilla_api.py が「素の API を使っている」と見つけられず、
        -- 素から消えたときの検知から漏れる。
        local ok, need = pcall(function()
            return IS_NEED_SUMMON_UI()
        end)
        g.party_icon_only_summon_ui = (ok and need == 1)
    end
    if text then
        AUTO_CAST(text)
        local text_w = PARTY_ICON_ONLY_SIZE
        if g.party_icon_only_summon_ui then
            -- ボタンは gbox の右端に寄る。素の左余白 8px のままだと文字がその下へ潜るので、
            -- 余白を落として左端から幅を取り直す。
            text_w = text_w - PARTY_ICON_ONLY_BUTTON_W
        end
        Party_icon_only_move_y(text, 0, 0)
        text:Resize(text_w, PARTY_ICON_ONLY_TITLE_H)
        -- 素は ClMsg("SummonsInfo_PartyInfo")(=「パーティー情報」)を入れるが、
        -- 50px では途中で切れる。掴み代と分かればよいので短い見出しにする。
        text:SetTextByKey("title", "PT")
        if text:IsVisible() == 0 then
            text:ShowWindow(1)
        end
    end
    return PARTY_ICON_ONLY_TITLE_H
end

function Party_icon_only_apply()
    if g.settings.party_icon_only.use == 0 then
        -- 保険。通常は on_teardown が止める。ここでは止めるだけにして、素へ戻すのは
        -- on_teardown 側に任せる(メッセージ経由でも呼ばれるので、ここで戻し直すと
        -- パーティ更新のたびに素の組み立てをやり直すことになる)。
        g.stop_timer("party_icon_only_timer")
        return
    end
    local partyinfo = ui.GetFrame("partyinfo")
    if not partyinfo or partyinfo:IsVisible() == 0 then
        -- 召喚獣情報へ切り替えている間は素が partyinfo を隠す。そのときは触らない。
        return
    end
    local rows = 0
    local title_gbox = nil
    for i = 0, partyinfo:GetChildCount() - 1 do
        local child = partyinfo:GetChildByIndex(i)
        if child then
            local name = child:GetName()
            if name == "titlegbox" then
                title_gbox = child
            elseif string.find(name, "PTINFO_", 1, true) == 1 then
                Party_icon_only_fold_row(child)
                rows = rows + 1
            end
        end
    end
    if rows == 0 then
        -- パーティを組んでいない(素が frame を畳む)。掴み代だけ残しても意味が無いので触らない。
        return
    end
    -- **掴み代を先に置く。** 見出しを出せたかどうかで最初の行の y が変わるので、
    -- 行を積むより前に高さを確定させる。
    local y = 0
    if title_gbox then
        y = Party_icon_only_fold_title(title_gbox)
    end
    local row_top = y
    for i = 0, partyinfo:GetChildCount() - 1 do
        local child = partyinfo:GetChildByIndex(i)
        if child and string.find(child:GetName(), "PTINFO_", 1, true) == 1 then
            Party_icon_only_move_y(child, y, 0)
            y = y + PARTY_ICON_ONLY_SIZE
        end
    end
    -- frame の矩形を「掴み代 + アイコンの列」と同じにする。ここが
    -- 「当たり判定もアイコンまで」の実体で、この外を押した入力は素どおり下へ抜ける。
    partyinfo:Resize(PARTY_ICON_ONLY_SIZE, y)
    partyinfo:Invalidate()
    -- 0.5 秒ごとに走るので、判断の材料になった値を 1 回だけ出す(CLAUDE.md「出しすぎない」)。
    if not g.party_icon_only_logged then
        g.party_icon_only_logged = true
        g.vlog("party_icon_only: %d 行を %dx%d へ畳んだ (掴み代 %dpx / summon_ui=%s)", rows,
            PARTY_ICON_ONLY_SIZE, y, row_top, tostring(g.party_icon_only_summon_ui))
    end
end

-- 素の見た目へ戻す。隠した子や縮めた大きさを 1 つずつ覚えて戻すのではなく、行を捨てて
-- 素の ON_PARTYINFO_UPDATE に組み立て直させる(CLAUDE.md「素の関数を書き写さない」。
-- 素が変われば戻し方も自動で追従する)。
function Party_icon_only_restore()
    local partyinfo = ui.GetFrame("partyinfo")
    if not partyinfo then
        return
    end
    local title_gbox = GET_CHILD_RECURSIVELY(partyinfo, "titlegbox")
    if title_gbox then
        AUTO_CAST(title_gbox)
        title_gbox:Resize(title_gbox:GetOriginalWidth(), title_gbox:GetOriginalHeight())
        title_gbox:EnableDrawFrame(1)
        title_gbox:ShowWindow(1)
        -- 上は素の PARTYINFO_CONTROLSET_AUTO_ALIGN(starty = 10)が入れ直すが、
        -- パーティを組んでいないと素の組み立てを通らないので、ここで 4 辺とも戻す。
        Party_icon_only_restore_margin(title_gbox, g.party_icon_only_title_margin)
        local text = GET_CHILD(title_gbox, "buttontitle")
        if text then
            AUTO_CAST(text)
            Party_icon_only_restore_margin(text, g.party_icon_only_text_margin)
            text:Resize(text:GetOriginalWidth(), text:GetOriginalHeight())
            text:SetTextByKey("title", ClMsg("SummonsInfo_PartyInfo"))
            text:ShowWindow(1)
        end
    end
    partyinfo:Resize(partyinfo:GetOriginalWidth(), partyinfo:GetOriginalHeight())
    -- 行は作り直す。隠した子・縮めた大きさ・寄せた margin をまとめて捨てられる。
    DESTROY_CHILD_BYNAME(partyinfo, "PTINFO_")
    -- パーティを組んでいないときの素は「行を消して frame を隠す」だけなので、呼ばない。
    if session.party.GetPartyInfo() and type(_G["ON_PARTYINFO_UPDATE"]) == "function" then
        ON_PARTYINFO_UPDATE(partyinfo)
    end
    g.vlog("party_icon_only: 素の partyinfo へ戻した")
end
-- Party Icon Only ここまで
