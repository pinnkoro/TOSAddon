-- レイドレコードの2度呼ばれるバグ修正。正確に測れる
function Mini_addons__REQ_PLAYER_CONTENTS_RECORD(frame, msg, arg_str, state)
    g.raid_msg = g.raid_msg or {}
    if g.raid_msg[msg] then
        return
    end
    g.raid_msg[msg] = true
    frame:SetUserValue("MA_arg_str", arg_str)
    frame:RunUpdateScript("Mini_addons_REQ_PLAYER_CONTENTS_RECORD_", 0.3)
end

function Mini_addons_REQ_PLAYER_CONTENTS_RECORD_(frame)
    local arg_str = frame:GetUserValue("MA_arg_str")
    local raid_record = ui.GetFrame("raid_record")
    if not raid_record then
        g.raid_msg = {}
        return
    end
    local token = StringSplit(arg_str, ";")
    if not token or not token[1] or not token[2] or not token[3] then
        g.raid_msg = {}
        return
    end
    local name = token[1]
    local before_str = token[2]
    local record_str = token[3]
    local function time_to_milliseconds(time_str)
        if type(time_str) ~= "string" then
            return nil
        end
        local min_str, sec_str, ms_str = time_str:match("(%d+):(%d+)%.(%d+)")
        if min_str and sec_str and ms_str then
            local ms_num = tonumber(ms_str)
            if not ms_num then
                return nil
            end
            if string.len(ms_str) == 1 then
                ms_num = ms_num * 100
            elseif string.len(ms_str) == 2 then
                ms_num = ms_num * 10
            end
            local minutes = tonumber(min_str)
            local seconds = tonumber(sec_str)
            return (minutes * 60 * 1000) + (seconds * 1000) + ms_num
        end
        return nil
    end
    local before_ms = time_to_milliseconds(before_str)
    local record_ms = time_to_milliseconds(record_str)
    if not before_ms or not record_ms then
        g.raid_msg = {}
        return
    end
    local record_time = GET_CHILD_RECURSIVELY(raid_record, "textRecord")
    local my_info = GET_CHILD_RECURSIVELY(raid_record, "myInfo")
    local time = GET_CHILD_RECURSIVELY(my_info, "time")
    record_time:SetTextByKey("value", record_str)
    if before_ms >= record_ms then
        local text_new_record = GET_CHILD_RECURSIVELY(raid_record, "textNewRecord")
        text_new_record:ShowWindow(1)
        local effect_name = raid_record:GetUserConfig("DO_NEWRECORD_EFFECT")
        local effect_scale = tonumber(raid_record:GetUserConfig("NEWRECORD_EFFECT_SCALE"))
        local effect_duration = tonumber(raid_record:GetUserConfig("NEWRECORD_EFFECT_DURATION"))
        local effect_bg = GET_CHILD_RECURSIVELY(raid_record, "success_effect_bg")
        if effect_bg then
            effect_bg:PlayUIEffect(effect_name, effect_scale, "DoNewRecordEffect")
            raid_record:RunUpdateScript("_RAID_NEWRECORD_EFFECT", effect_duration)
        end
        time:SetTextByKey("value", before_str .. "→" .. record_str)
    else
        time:SetTextByKey("value", before_str)
    end
    g.raid_msg = {}
    GetPlayerRecord("callback_get_player_current_record", name)
    return 0
end
-- レイドレコードのサイズ、位置変更
function Mini_addons_RAID_RECORD_INIT(my_frame, my_msg)
    if g.settings.raid_record == 0 then
        return
    end
    local raid_record = ui.GetFrame("raid_record")
    raid_record:SetSkinName("shadow_box")
    raid_record:SetEventScript(ui.LBUTTONUP, "Mini_addons_raid_record_loc_save")
    raid_record:SetLayerLevel(5)
    raid_record:SetTitleBarSkin("None")
    raid_record:ShowTitleBar(0)
    raid_record:Resize(550, 260)
    raid_record:SetOffset(g.settings.reword_x, g.settings.reword_y)
    local widget_list = {{
        name = "myInfo",
        font = "white_16_ol"
    }, {
        name = "friendInfo1",
        font = "white_16_ol"
    }, {
        name = "friendInfo2",
        font = "white_16_ol"
    }, {
        name = "friendInfo3",
        font = "white_16_ol"
    }}
    for i, data in ipairs(widget_list) do
        local widget = GET_CHILD_RECURSIVELY(raid_record, data.name)
        local name = GET_CHILD_RECURSIVELY(widget, "name")
        local time = GET_CHILD_RECURSIVELY(widget, "time")
        name:SetFontName(data.font)
        time:SetFontName(data.font)
    end
end

function Mini_addons_raid_record_loc_save(raid_record)
    g.settings.reword_x = raid_record:GetX()
    g.settings.reword_y = raid_record:GetY()
    Mini_addons_save_settings()
end
