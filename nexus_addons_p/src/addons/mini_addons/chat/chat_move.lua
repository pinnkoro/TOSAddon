-- チャットフレーム移動のワイドモニター制限解除
function Mini_addons__PROCESS_MOVE_MAIN_POPUPCHAT_FRAME(my_frame, my_msg)
    local frame = g.get_event_args(my_msg)
    frame:RunUpdateScript("Mini_addons_PROCESS_MOVE_MAIN_POPUPCHAT_FRAME", 0.1)
end

function Mini_addons_PROCESS_MOVE_MAIN_POPUPCHAT_FRAME(frame)
    if mouse.IsLBtnPressed() == 0 then
        MOVE_FRAME_MAIN_POPUP_CHAT_END(frame)
        return 0
    end
    local ratio = option.GetClientHeight() / option.GetClientWidth()
    local limit_offset = 10
    local limit_max_w
    local limit_max_h
    if g.settings.chat_frame == 1 then
        limit_max_w = ui.GetSceneWidth() - limit_offset
        limit_max_h = limit_max_w * ratio - limit_offset
    else
        limit_max_w = ui.GetSceneWidth() / ui.GetRatioWidth() - limit_offset
        limit_max_h = limit_max_w * ratio - limit_offset * 12
    end
    local mx, my = GET_MOUSE_POS()
    mx = mx / ui.GetRatioWidth()
    my = my / ui.GetRatioHeight()
    local prev_mouse_x = frame:GetUserIValue("MOUSE_X")
    local prev_mouse_y = frame:GetUserIValue("MOUSE_Y")
    local diff_x = (mx - prev_mouse_x)
    local diff_y = (my - prev_mouse_y)
    local new_x = frame:GetUserIValue("BEFORE_W")
    local new_y = frame:GetUserIValue("BEFORE_H")
    new_x = new_x + diff_x
    new_y = new_y + diff_y
    if new_x < limit_offset then
        new_x = limit_offset
    end
    if new_y < limit_offset then
        new_y = limit_offset
    end
    local frame_w = frame:GetWidth()
    local frame_h = frame:GetHeight()
    if (new_x + frame_w) > limit_max_w then
        new_x = limit_max_w - frame_w
    end
    if (new_y + frame_h) > limit_max_h then
        new_y = (limit_max_h - frame_h)
    end
    frame:SetOffset(new_x, new_y)
    return 1
end
