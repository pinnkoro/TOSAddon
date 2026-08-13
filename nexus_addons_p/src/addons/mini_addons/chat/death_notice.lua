-- PTメンバーの死亡と復活をNICO_CHATで流す
local last_time = 0
local cd_time = 0.5
function Mini_addons_DRAW_CHAT_MSG(my_frame, my_msg)
    if g.settings.chat_recv == 0 then
        return
    end
    local now = os.clock()
    if (now - last_time) < cd_time then
        return
    end
    local groupboxname, startindex, frame = g.get_event_args(my_msg)
    local size = session.ui.GetMsgInfoSize(groupboxname)
    local chat = session.ui.GetChatMsgInfo(groupboxname, size - 1)
    local msg_type = chat:GetMsgType()
    if msg_type ~= "Battle" then
        return
    end
    local chat_option = ui.GetFrame("chat_option")
    local resurrectCheck_party = GET_CHILD_RECURSIVELY(chat_option, "resurrectCheck_party")
    AUTO_CAST(resurrectCheck_party)
    resurrectCheck_party:SetCheck(1)
    local msg = chat:GetMsg()
    if string.find(msg, "!@#$Dead{MEMBER}$*$MEMBER$*$", 1, true) then
        local pattern = "^!@#%$Dead%{MEMBER%}%$%*%$MEMBER%$%*%$(.-)#@!$"
        local rep_msg = string.match(msg, pattern)
        if rep_msg then
            rep_msg = "[ " .. rep_msg .. " ]"
            rep_msg = g.lang == "Japanese" and rep_msg .. " が死亡" or rep_msg .. " died"
            NICO_CHAT(tostring("{ol}{#FF0000}{s40}" .. rep_msg))
        end
    elseif string.find(msg, "!@#$Resurrect{MEMBER}$*$MEMBER$*$", 1, true) then
        local pattern = "^!@#%$Resurrect{MEMBER}%$%*%$MEMBER%$%*%$(.-)#@!$"
        local rep_msg = string.match(msg, pattern)
        if rep_msg then
            rep_msg = "[ " .. rep_msg .. " ]"
            rep_msg = g.lang == "Japanese" and rep_msg .. " が復活" or rep_msg .. " revived"
            NICO_CHAT(tostring("{ol}{#00BFFF}{s40}" .. rep_msg))
        end
    end
    last_time = os.clock()
end
