-- party_keeper　ここから
-- 今入っている PT の ID を控えておき、後から同じ PT へ入り直す。
--
-- 入り直しはチャットの PT リンクを押したときと同じ経路(素の SLP → party.JoinPartyByLink)。
-- PT ID はサーバーが払い出すもので、同じ ID の PT を作り直す API は無い
-- (party.ReqPartyMake が受け取るのは名前だけ)。なので「入る」だけを持つ。
-- 入れるかどうかはサーバーが決める。PT が解散していれば入れず、リンク参加(AllowLinkJoin)が
-- 許可されていない PT も入れないはず(素の LINK_PARTY_INVITE はリンクを貼る前に 1 へ上げている)。
function Party_keeper_save_settings()
    g.save_json(g.party_keeper_path, g.party_keeper_settings)
end

function Party_keeper_load_settings()
    -- PT はキャラではなくチーム(アカウント)単位なので、保存先もアカウント単位にする
    g.party_keeper_path = string.format("../addons/%s/%s/party_keeper.json", addon_name_lower, g.active_id)
    local settings = g.load_json(g.party_keeper_path)
    if not settings then
        settings = {
            party_id = "",
            name = "",
            saved_at = ""
        }
    end
    g.party_keeper_settings = settings
    Party_keeper_save_settings()
end

function party_keeper_on_init()
    if not g.party_keeper_settings then
        Party_keeper_load_settings()
    end
    if g.settings.party_keeper.use == 0 then
        local setting = ui.GetFrame(addon_name_lower .. "party_keeper_setting")
        if setting then
            ui.DestroyFrame(setting:GetName())
        end
    end
end

-- 今入っている PT の情報。入っていなければ nil。
-- allow_link: リンク参加の許可(AllowLinkJoin)。0 だと保存しても入り直せないはず
local function party_keeper_current()
    local pcparty = session.party.GetPartyInfo()
    if not pcparty or not pcparty.info then
        return nil
    end
    local party_obj = GetIES(pcparty:GetObject())
    return {
        party_id = tostring(pcparty.info:GetPartyID()),
        name = pcparty.info.name,
        is_leader = session.loginInfo.GetAID() == pcparty.info:GetLeaderAID(),
        allow_link = TryGetProp(party_obj, "AllowLinkJoin", 0)
    }
end

function Party_keeper_settings_frame_close(frame)
    ui.DestroyFrame(addon_name_lower .. "party_keeper_setting")
end

function Party_keeper_settings_frame()
    local frame_name = addon_name_lower .. "party_keeper_setting"
    local setting = ui.CreateNewFrame("notice_on_pc", frame_name, 0, 0, 0, 0)
    AUTO_CAST(setting)
    setting:Resize(400, 210)
    setting:SetPos(g.settings_frame_pos(400, 210))
    setting:SetSkinName("test_frame_low")
    g.block_click_through(setting)
    setting:EnableHitTest(1)
    setting:SetLayerLevel(999)
    setting:ShowWindow(1)
    g.esc_register_destroy(frame_name)
    local title_text = setting:CreateOrGetControl('richtext', 'title_text', 20, 15, 50, 30)
    AUTO_CAST(title_text)
    title_text:SetText("{ol}Party Keeper")
    local close = setting:CreateOrGetControl("button", "close", 0, 0, 20, 20)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Party_keeper_settings_frame_close")
    local gbox = setting:CreateOrGetControl("groupbox", "gbox", 10, 40, setting:GetWidth() - 20,
        setting:GetHeight() - 50)
    AUTO_CAST(gbox)
    gbox:SetSkinName("test_frame_midle_light")
    local labels = {"saved_text", "saved_at_text", "current_text"}
    for i, name in ipairs(labels) do
        local text = gbox:CreateOrGetControl('richtext', name, 10, 10 + (i - 1) * 25, 360, 20)
        AUTO_CAST(text)
    end
    local buttons = {{
        name = "save_btn",
        ja = "現在のPTを保存",
        en = "Save current PT",
        scp = "Party_keeper_save_current"
    }, {
        name = "join_btn",
        ja = "保存したPTに入る",
        en = "Join saved PT",
        scp = "Party_keeper_join"
    }, {
        name = "clear_btn",
        ja = "消去",
        en = "Clear",
        scp = "Party_keeper_clear"
    }}
    local x = 10
    for _, def in ipairs(buttons) do
        local width = def.name == "clear_btn" and 70 or 140
        local btn = gbox:CreateOrGetControl('button', def.name, x, 95, width, 35)
        AUTO_CAST(btn)
        btn:SetSkinName("test_pvp_btn")
        btn:SetText("{ol}" .. (g.lang == "Japanese" and def.ja or def.en))
        btn:SetEventScript(ui.LBUTTONUP, def.scp)
        x = x + width + 5
    end
    Party_keeper_refresh_frame()
end

-- 窓の文言だけを書き直す(窓を作り直さない)。保存・消去・PT の出入りのあとに呼ぶ
function Party_keeper_refresh_frame()
    local setting = ui.GetFrame(addon_name_lower .. "party_keeper_setting")
    if not setting then
        return
    end
    local ja = g.lang == "Japanese"
    local saved = g.party_keeper_settings
    local saved_text = GET_CHILD_RECURSIVELY(setting, "saved_text")
    local saved_at_text = GET_CHILD_RECURSIVELY(setting, "saved_at_text")
    local current_text = GET_CHILD_RECURSIVELY(setting, "current_text")
    if saved.party_id == "" then
        saved_text:SetText(ja and "{ol}保存中のPT: なし" or "{ol}Saved PT: none")
        saved_at_text:SetText("")
    else
        saved_text:SetText(string.format(ja and "{ol}保存中のPT: %s" or "{ol}Saved PT: %s", saved.name))
        saved_at_text:SetText(string.format(ja and "{ol}{s14}保存日時: %s" or "{ol}{s14}Saved at: %s",
            saved.saved_at))
    end
    local cur = party_keeper_current()
    if not cur then
        current_text:SetText(ja and "{ol}現在のPT: 未参加" or "{ol}Current PT: none")
    else
        local link = cur.allow_link == 1 and (ja and "許可" or "allowed") or
                         (ja and "{#FF6666}不許可{/}" or "{#FF6666}not allowed{/}")
        current_text:SetText(string.format(ja and "{ol}現在のPT: %s (リンク参加: %s)" or
                                               "{ol}Current PT: %s (Link join: %s)", cur.name, link))
    end
end

function Party_keeper_save_current()
    local ja = g.lang == "Japanese"
    local cur = party_keeper_current()
    if not cur then
        ui.SysMsg(ClMsg("NotBelongsToParty"))
        return
    end
    g.party_keeper_settings.party_id = cur.party_id
    g.party_keeper_settings.name = cur.name
    g.party_keeper_settings.saved_at = os.date("%Y-%m-%d %H:%M")
    Party_keeper_save_settings()
    g.vlog("party_keeper: 保存した id=%s name=%s leader=%s AllowLinkJoin=%s", cur.party_id, tostring(cur.name),
        tostring(cur.is_leader), tostring(cur.allow_link))
    -- リンク参加が許可されていないと入り直せないはずなので、リーダーなら素の
    -- LINK_PARTY_INVITE(PT リンクを貼るボタン)と同じく許可へ上げておく。
    -- リーダーでなければ上げられないので、許可してもらうよう知らせるだけにする
    if cur.allow_link == 0 then
        if cur.is_leader then
            party.ReqChangeProperty(PARTY_NORMAL, "AllowLinkJoin", 1)
            g.vlog("party_keeper: リーダーなので AllowLinkJoin を 1 へ上げた")
        else
            ui.SysMsg(ja and "このPTはリンク参加が許可されていないため、保存しても入り直せないことがあります" ..
                          "{nl}リーダーにPTリンクをチャットへ貼ってもらうと許可されます" or
                          "This PT does not allow link join, so you may not be able to rejoin it" ..
                          "{nl}It is allowed once the leader posts the PT link in chat")
        end
    end
    ui.SysMsg(string.format(ja and "PT「%s」を保存しました" or "Saved PT \"%s\"", cur.name))
    Party_keeper_refresh_frame()
end

function Party_keeper_join()
    local ja = g.lang == "Japanese"
    local saved = g.party_keeper_settings
    if saved.party_id == "" then
        ui.SysMsg(ja and "保存したPTがありません" or "No saved PT")
        return
    end
    -- 入っている間は素の SLP と同じ文言で止める(同じ PT か別の PT か)
    local cur = party_keeper_current()
    if cur then
        if cur.party_id == saved.party_id then
            ui.SysMsg(ClMsg("HadMyPartySame"))
        else
            ui.SysMsg(ClMsg("HadMyPartyOther"))
        end
        return
    end
    g.vlog("party_keeper: JoinPartyByLink id=%s name=%s", saved.party_id, tostring(saved.name))
    party.JoinPartyByLink(PARTY_NORMAL, saved.party_id)
    -- 入れたかどうかはサーバーの返事次第なので、少し待ってから窓を書き直す
    ReserveScript("Party_keeper_refresh_frame()", 1.0)
end

function Party_keeper_clear()
    g.party_keeper_settings.party_id = ""
    g.party_keeper_settings.name = ""
    g.party_keeper_settings.saved_at = ""
    Party_keeper_save_settings()
    Party_keeper_refresh_frame()
end
-- party_keeper　ここまで
