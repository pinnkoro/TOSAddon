-- Auto Map Change ここから
function auto_map_change_on_init()
    g.addon:RegisterMsg("DIALOG_CHANGE_SELECT", "Auto_map_change_DIALOG_ON_MSG")
end

function Auto_map_change_DIALOG_ON_MSG(frame, msg, str, num)
    if g.settings.auto_map_change.use == 0 then
        return
    end
    if string.find(str, "HighLvZoneEnterMsgCustom") then
        control.DialogItemSelect(1)
        control.DialogOk()
    end
end
-- Auto Map Change ここまで

