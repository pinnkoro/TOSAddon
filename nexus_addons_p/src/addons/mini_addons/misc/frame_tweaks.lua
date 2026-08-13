-- オートズーム
function Mini_addons_autozoom_edit(frame, ctrl)
    local value = tonumber(ctrl:GetText())
    if value < 1 or value > 700 then
        local errorMsg =
            g.lang == "Japanese" and "無効な値です。1から700の間で設定してください。" or
                "Invalid value please set between 1 and 700"
        ui.SysMsg(errorMsg)
        ctrl:SetText("336")
        g.settings.auto_zoom.zoom = 336
    else
        if value ~= g.settings.auto_zoom.zoom then
            ui.SysMsg("Auto Zoom setting set to " .. value)
            g.settings.auto_zoom.zoom = value
        end
    end
    Mini_addons_save_settings()
    ctrl:RunUpdateScript("Mini_addons_autozoom", 1.0)
end

function Mini_addons_autozoom(ctrl)
    if g.settings.auto_zoom.use == 1 then
        camera.CustomZoom(tonumber(g.settings.auto_zoom.zoom))
    end
end
-- セパレートバフフレームの周りを綺麗に
function Mini_addons_buff_separatedlist()
    local buff_separatedlist = ui.GetFrame("buff_separatedlist")
    local gbox = GET_CHILD_RECURSIVELY(buff_separatedlist, "gbox")
    AUTO_CAST(gbox)
    if g.settings.separated_buff == 1 then
        gbox:SetSkinName("None")
    else
        gbox:SetSkinName("chat_window")
    end
end
-- クポルポーションフレームの移動と非表示
function Mini_addons_cupole_portion_frame_save(cupole_external_addon)
    g.settings.cupole_portion.x = cupole_external_addon:GetX()
    g.settings.cupole_portion.y = cupole_external_addon:GetY()
    Mini_addons_save_settings()
end

function Mini_addons_cupole_portion_frame()
    local cupole_external_addon = ui.GetFrame("cupole_external_addon")
    if g.settings.cupole_portion.x == 0 and g.settings.cupole_portion.y == 0 then
        local cur_x = cupole_external_addon:GetX()
        local cur_y = cupole_external_addon:GetY()
        if g.settings.cupole_portion.def_x ~= cur_x or g.settings.cupole_portion.def_y ~= cur_y then
            g.settings.cupole_portion.def_x = cur_x
            g.settings.cupole_portion.def_y = cur_y
            Mini_addons_save_settings()
        end
    end
    if g.settings.cupole_portion.use == 1 then
        cupole_external_addon:ShowWindow(0)
    else
        if g.settings.cupole_portion.x == 0 and g.settings.cupole_portion.y == 0 then
            cupole_external_addon:SetPos(g.settings.cupole_portion.def_x, g.settings.cupole_portion.def_y)
        else
            cupole_external_addon:SetPos(g.settings.cupole_portion.x, g.settings.cupole_portion.y)
        end
        cupole_external_addon:ShowWindow(1)
    end
end
