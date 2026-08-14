-- ファミリーネームからログインネームへ変換
function Mini_addons_PCNAME_REPLACE(frame, msg)
    if g.settings.pc_name == 0 then
        return
    end
    local headsupdisplay = ui.GetFrame("headsupdisplay")
    local name_text = GET_CHILD_RECURSIVELY(headsupdisplay, "name_text")
    local login_name = session.GetMySession():GetPCApc():GetName()
    if name_text:GetText() ~= "{@st41}" .. tostring(login_name) then
        name_text:SetText("{@st41}" .. tostring(login_name))
    end
end
