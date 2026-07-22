-- Boss Gauge ここから
function boss_gauge_on_init()
    g.addon:RegisterMsg('TARGET_BUFF_UPDATE', 'Boss_gauge_TARGETINFOTOBOSS_ON_MSG')
    g.addon:RegisterMsg('TARGET_UPDATE', 'Boss_gauge_TARGETINFOTOBOSS_ON_MSG')
    g.addon:RegisterMsg("TARGET_SET_BOSS", "Boss_gauge_TARGETINFOTOBOSS_ON_MSG")
    g.setup_hook_and_event(g.addon, "TARGETINFOTOBOSS_UPDATE_SHIELD", "Boss_gauge_TARGETINFOTOBOSS_UPDATE_SHIELD", true)
end

function Boss_gauge_frame_position()
    local targetinfotoboss = ui.GetFrame("targetinfotoboss")
    local name = GET_CHILD_RECURSIVELY(targetinfotoboss, "name")
    AUTO_CAST(name)
    if name then
        local x = name:GetX()
        local width = name:GetWidth()
        if width > 190 then
            width = 190
        end
        local height = name:GetHeight()
        return targetinfotoboss, x, width, height
    end
end

function Boss_gauge_TARGETINFOTOBOSS_ON_MSG(frame, msg)
    if g.settings.boss_gauge.use == 0 then
        return
    end
    local stat = info.GetStat(session.GetTargetBossHandle())
    if stat then
        local cur_faint = stat.cur_faint
        local max_faint = stat.max_faint
        local targetinfotoboss, x, width, height = Boss_gauge_frame_position()
        if not targetinfotoboss then
            return
        end
        if cur_faint and max_faint and cur_faint >= 0 and max_faint > 0 then
            local faint = GET_CHILD_RECURSIVELY(targetinfotoboss, "faint")
            if faint then
                AUTO_CAST(faint)
                local diff_faint = max_faint - cur_faint
                if diff_faint < 0 then
                    diff_faint = 0
                end
                local stun = targetinfotoboss:CreateOrGetControl("richtext", "stun", x + width + 35, 66, 120, height)
                AUTO_CAST(stun)
                local stun_text = "STUN:" .. string.format("(%.2f%%)", (diff_faint / max_faint) * 100)
                stun:SetText(stun_text)
                stun:SetFontName("yellow_16_ol")
                local name = GET_CHILD_RECURSIVELY(targetinfotoboss, "name")
                AUTO_CAST(name)
                name:AdjustFontSizeByWidth(220)
            end
        end
        local shield = GET_CHILD_RECURSIVELY(targetinfotoboss, "shield", "ui::CGauge")
        if shield:IsVisible() == 0 then
            local shield_text = GET_CHILD_RECURSIVELY(targetinfotoboss, "shield_text")
            if shield_text then
                AUTO_CAST(shield_text)
                shield_text:ShowWindow(0)
            end
        end
    end
end

function Boss_gauge_TARGETINFOTOBOSS_UPDATE_SHIELD(my_frame, my_msg)
    if g.settings.boss_gauge.use == 0 then
        return
    end
    local data = g.get_event_args(my_msg)
    if not data then
        return
    end
    local data_list = StringSplit(data, '/')
    if #data_list > 0 then
        local shield = data_list[1]
        if shield then
            local shield_num = tonumber(data_list[1])
            local max_hp = tonumber(data_list[2])
            if shield_num and max_hp and max_hp > 0 then
                local targetinfotoboss, x, width, height = Boss_gauge_frame_position()
                if not targetinfotoboss then
                    return
                end
                local shield_text = targetinfotoboss:CreateOrGetControl("richtext", "shield_text", x + width + 165, 66,
                    120, height)
                AUTO_CAST(shield_text)
                local text = "SHIELD:" .. string.format("(%.2f%%)", (shield_num / max_hp) * 100)
                shield_text:SetText(text)
                shield_text:SetFontName("yellow_16_ol")
            end
        end
    end
end
-- Boss Gauge ここまで

