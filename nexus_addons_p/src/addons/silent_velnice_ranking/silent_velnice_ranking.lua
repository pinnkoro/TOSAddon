-- silent_velnice_ranking ここから
function silent_velnice_ranking_on_init()
    if g.settings.silent_velnice_ranking.use == 0 then
        return
    end
    if g.map_id == 8022 then
        g.addon:RegisterMsg("DO_SOLODUNGEON_SCOREBOARD_OPEN", "Silent_velnice_ranking_SOLODUNGEON_SCOREBOARD_OPEN")
    end
end

function Silent_velnice_ranking_SOLODUNGEON_SCOREBOARD_OPEN(frame, msg)
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    _nexus_addons_p:SetVisible(1)
    local silent_velnice_ranking_timer = _nexus_addons_p:CreateOrGetControl("timer", "silent_velnice_ranking_timer", 0, 0)
    AUTO_CAST(silent_velnice_ranking_timer)
    silent_velnice_ranking_timer:SetUpdateScript("Silent_velnice_ranking_keypress")
    silent_velnice_ranking_timer:Start(0.2)
end

function Silent_velnice_ranking_keypress(_nexus_addons_p, silent_velnice_ranking_timer)
    local solodungeonscoreboard = ui.GetFrame("solodungeonscoreboard")
    if 1 == keyboard.IsKeyPressed("TAB") then
        SOLODUNGEON_SCOREBOARD_OPEN(nil, nil, nil, nil)
        silent_velnice_ranking_timer:Stop()
        return
    end
    if solodungeonscoreboard:IsVisible() == 1 then
        solodungeonscoreboard:ShowWindow(0)
    end
end
-- silent_velnice_ranking ここまで

