-- 4人以下の入場確認スキップ
function Mini_addons_INDUNENTER_REQ_UNDERSTAFF_ENTER_ALLOW(parent, ctrl)
    local top_frame = parent:GetTopParentFrame()
    local use_count = tonumber(top_frame:GetUserValue("multipleCount"))
    if use_count > 0 then
        local multiple_item_list = GET_INDUN_MULTIPLE_ITEM_LIST()
        for i = 1, #multiple_item_list do
            local item_name = multiple_item_list[i]
            local inv_item = session.GetInvItemByName(item_name)
            if inv_item ~= nil and inv_item.isLockState then
                ui.SysMsg(ClMsg("MaterialItemIsLock"))
                return
            end
        end
    end
    local with_match_mode = top_frame:GetUserValue("WITHMATCH_MODE")
    if top_frame:GetUserValue("AUTOMATCH_MODE") ~= "YES" and with_match_mode == "NO" then
        ui.SysMsg(ScpArgMsg("EnableWhenAutoMatching"))
        return
    end
    local indun_type = top_frame:GetUserIValue("INDUN_TYPE")
    local indun_cls = GetClassByType("Indun", indun_type)
    local min_member = TryGetProp(indun_cls, "UnderstaffEnterAllowMinMember")
    if min_member == nil then
        return
    end
    local yes_scp_str = "_INDUNENTER_REQ_UNDERSTAFF_ENTER_ALLOW()"
    local client_msg = ScpArgMsg("ReallyAllowUnderstaffMatchingWith{MIN_MEMBER}?", "MIN_MEMBER", min_member)
    if INDUNENTER_CHECK_UNDERSTAFF_MODE_WITH_PARTY(top_frame) == true then
        client_msg = ClMsg("CancelUnderstaffMatching")
    end
    if with_match_mode == "YES" then
        yes_scp_str = "ReqUnderstaffEnterAllowModeWithParty(" .. indun_type .. ")"
    end
    if g.settings.under_staff == 1 then
        if with_match_mode == "NO" then
            _INDUNENTER_REQ_UNDERSTAFF_ENTER_ALLOW()
            return
        end
    end
    ui.MsgBox(client_msg, yes_scp_str, "None")
end
-- ヴェルニケ階数を覚える
function Mini_addons_INDUN_EDITMSGBOX_FRAME_OPEN(type, clmsg, desc, yes_scp, no_scp, min_number, max_number,
    default_number)
    if g.settings.velnice.use == 0 then
        if g.FUNCS["INDUN_EDITMSGBOX_FRAME_OPEN"] then
            g.FUNCS["INDUN_EDITMSGBOX_FRAME_OPEN"](type, clmsg, desc, yes_scp, no_scp, min_number, max_number,
                default_number)
        end
        return
    end
    default_number = g.settings.velnice.level
    ui.OpenFrame("indun_editmsgbox")
    local frame = ui.GetFrame("indun_editmsgbox")
    frame:EnableHide(1)
    frame:SetUserValue("user_value", type)
    local text = GET_CHILD_RECURSIVELY(frame, "text")
    text:SetText(clmsg)
    local text_desc = GET_CHILD_RECURSIVELY(frame, "text_desc")
    text_desc:SetText(desc)
    local edit = GET_CHILD_RECURSIVELY(frame, "edit")
    edit:SetText(default_number)
    edit:SetNumberMode(1)
    edit:SetMaxNumber(max_number)
    edit:SetMinNumber(min_number)
    edit:AcquireFocus()
    local yes_btn = GET_CHILD_RECURSIVELY(frame, "yesBtn", "ui::CButton")
    yes_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_INDUN_EDITMSGBOX_FRAME_OPEN_YES")
    yes_btn:SetEventScriptArgString(ui.LBUTTONUP, yes_scp)
    local no_btn = GET_CHILD_RECURSIVELY(frame, "noBtn", "ui::CButton")
    no_btn:SetEventScript(ui.LBUTTONUP, "_INDUN_EDITMSGBOX_FRAME_OPEN_NO")
    no_btn:SetEventScriptArgString(ui.LBUTTONUP, no_scp)
    yes_btn:ShowWindow(1)
    no_btn:ShowWindow(1)
end

function Mini_addons_SOLO_D_TIMER_UPDATE_TEXT_GAUGE(frame, msg, arg_str)
    if g.settings.velnice.use == 0 then
        return
    end
    local argument_list = StringSplit(arg_str, ";")
    local current_wave = tonumber(argument_list[3])
    local timer_frame = ui.GetFrame("solo_d_timer")
    local last_wave = timer_frame:GetUserIValue("LAST_WAVE")
    if last_wave ~= current_wave and current_wave ~= 1 then
        local remain_time_value = GET_CHILD_RECURSIVELY(timer_frame, "remaintimeValue")
        local min = remain_time_value:GetTextByKey("min")
        local sec = string.format("%02d", tonumber(remain_time_value:GetTextByKey("sec")))
        imcAddOn.BroadMsg("NOTICE_Dm_stage_start",
            string.format("{nl} {nl} {nl} {nl} {nl} {nl} {nl}{@st55_a}Round %s / 8 Fight{nl}{@st64}Remain Time %s : %s",
                current_wave - 1, min, sec), 2.0)
        timer_frame:SetUserValue("LAST_WAVE", current_wave)
    end
end

function Mini_addons_INDUN_EDITMSGBOX_FRAME_OPEN_YES(parent, ctrl, arg_str, arg_num)
    local edit = GET_CHILD_RECURSIVELY(parent, "edit")
    local text = edit:GetText()
    g.settings.velnice.level = tonumber(text)
    Mini_addons_save_settings()
    local scp = _G[arg_str]
    if scp ~= nil then
        local user_value = tonumber(parent:GetUserValue("user_value"))
        scp(user_value, text)
    end
    ui.CloseFrame("indun_editmsgbox")
end
