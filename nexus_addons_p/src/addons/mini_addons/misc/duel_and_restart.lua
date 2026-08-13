-- コロニー死んだ時に30秒タイマー動かないバグ修正
-- 決闘の申し込みを自動で受ける。
--
-- クライアントの ASKED_FRIENDLY_FIGHT / ASKED_ANCIENT_FRIENDLY_FIGHT(ui.ipf の
-- uiscp/community.lua)は確認ダイアログを出し、「はい」で ACK_*_FRIENDLY_FIGHT を呼ぶ。
-- ここではその ACK を直接呼んで、ダイアログを飛ばす。
--
-- **自前でパケットを送らず ACK を経由すること。** ACK_FRIENDLY_FIGHT は楽器バフ中に
-- 申し込みを弾く判定(packet.RequestFriendlyFight を呼ばず SysMsg を出す)を持っている。
-- ここを迂回すると、その判定ごと無くなる。
--
-- 通常の決闘と古代の決闘は別の関数なので、両方に同じ処理を掛ける
-- (利用者から見ればどちらも「決闘の申し込み」で、片方だけ自動だと分かりにくい)。
--
-- **フックは設定に関係なく全利用者に掛かる**(掛け外しは GAME_START_3SEC の一度きり)。
-- そのため、自動で受けない経路は元の関数へ**素通し**でなければならない。引数を
-- (handle, family_name) に固定して受け直すと、クライアントが 3 つ目以降を渡すように
-- なったときに黙って落ち、戻り値も握り潰す。機能を OFF にしている利用者まで巻き込むので、
-- ここは可変長(...)で受けてそのまま渡し、戻り値も返すこと。
local function Mini_addons_auto_accept_duel(ack_func_name, origin_func_name, ...)
    local handle, family_name = ...
    if g.settings and g.settings.auto_accept_duel == 1 and handle ~= nil then
        -- **成功ログは ACK を呼べたときだけ出す。** 存在チェックより前に出すと、
        -- ACK が無いときに「自動で受けた」と下の「戻す」が並んで出て、ログから
        -- どちらが起きたのか読めなくなる。
        local ack = _G[ack_func_name]
        if type(ack) == "function" then
            core_g.vlog("mini_addons: 決闘の申し込みを自動で受けた (%s / 相手 %s)", ack_func_name,
                tostring(family_name))
            return ack(handle)
        end
        -- ACK が居ない = クライアント側の作りが変わった。黙って握ると
        -- 「自動で受ける設定にしたのに何も起きない」になるので、元の確認ダイアログへ回す。
        core_g.vlog("{#FF6347}mini_addons: %s が見つからないので確認ダイアログに戻す{/}", ack_func_name)
    end
    local origin = g.FUNCS[origin_func_name]
    if origin then
        return origin(...)
    end
end

function Mini_addons_ASKED_FRIENDLY_FIGHT(...)
    return Mini_addons_auto_accept_duel("ACK_FRIENDLY_FIGHT", "ASKED_FRIENDLY_FIGHT", ...)
end

function Mini_addons_ASKED_ANCIENT_FRIENDLY_FIGHT(...)
    return Mini_addons_auto_accept_duel("ACK_ANCIENT_FRIENDLY_FIGHT", "ASKED_ANCIENT_FRIENDLY_FIGHT", ...)
end

function Mini_addons_RESTART_ON_MSG(frame, msg, str, num)
    if not g.settings.restart_colony or g.settings.restart_colony ~= 1 or msg ~= "RESTART_HERE" or
        (BitGet(num, 12) ~= 1 and BitGet(num, 14) ~= 1) then
        if g.FUNCS["RESTART_ON_MSG"] then
            g.FUNCS["RESTART_ON_MSG"](frame, msg, str, num)
        end
        return
    end
    local restart = ui.GetFrame("restart")
    restart:ShowWindow(1)
    for i = 1, 5 do
        local res_btn = GET_CHILD(restart, "restart" .. i .. "btn", "ui::CButton")
        if res_btn then
            res_btn:ShowWindow(BitGet(num, i))
        end
    end
    local mystic_btn = GET_CHILD(restart, "restart8btn", "ui::CButton")
    if mystic_btn then
        if BitGet(num, 14) == 1 then
            mystic_btn:ShowWindow(1)
        else
            mystic_btn:ShowWindow(0)
        end
    end
    if restart:GetUserIValue("COLONY_TIMER_RUNNING") ~= 1 then
        restart:SetUserValue("COLONY_TIMER_RUNNING", 1) -- 実行中フラグを立てる
        local res_btn_6 = GET_CHILD(restart, "restart6btn", "ui::CButton")
        if res_btn_6 then
            res_btn_6:ShowWindow(1)
            local text = "{@st66b}" .. ScpArgMsg("ReturnCity{SEC}", "SEC", 30) .. "{/}"
            res_btn_6:SetText(text)
        end
        g.colony_wait_time = 30
        restart:RunUpdateScript("Mini_addons_COLONY_WAR_RESTART_UPDATE", 1)
        AUTORESIZE_RESTART(restart)
        local res_btn_9 = GET_CHILD(restart, "restart9btn", "ui::CButton")
        if res_btn_9 then
            res_btn_9:ShowWindow(0)
        end
        local res_btn_10 = GET_CHILD(restart, "restart10btn", "ui::CButton")
        if res_btn_10 then
            res_btn_10:ShowWindow(0)
        end
        local restart_wait = GET_CHILD(restart, "restart_wait")
        if restart_wait then
            AUTO_CAST(restart_wait)
            restart_wait:ShowWindow(0)
        end
        restart:ShowWindow(1)
    end
end

function Mini_addons_COLONY_WAR_RESTART_UPDATE(restart)
    local res_btn = GET_CHILD(restart, "restart6btn", "ui::CButton")
    if not res_btn then
        return 0
    end
    g.colony_wait_time = g.colony_wait_time - 1
    if g.colony_wait_time < 0 then
        g.colony_wait_time = 0
    end
    local text = "{@st66b}" .. ScpArgMsg("ReturnCity{SEC}", "SEC", g.colony_wait_time) .. "{/}"
    res_btn:SetText(text)
    if g.colony_wait_time <= 0 then
        restart:SetUserValue("COLONY_TIMER_RUNNING", 0)
        return 0
    end
    if _G["COLONY_WAR_RESTART_BY_MYSTIC_UPDATE"] then
        COLONY_WAR_RESTART_BY_MYSTIC_UPDATE(restart)
    end
    return 1
end
