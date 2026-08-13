-- ペットコマンド制御
function Mini_addons_SHOW_PET_RINGCOMMAND(my_frame, my_msg)
    local actor = g.get_event_args(my_msg)
    if g.settings.pet_ring == 1 then
        return
    else
        g.FUNCS["SHOW_PET_RINGCOMMAND"](actor)
    end
end
-- レリックゲージ
function Mini_addons_CHARBASE_RELIC()
    if g.settings.relic_gauge == 0 then
        return
    end
    if HEADSUPDISPLAY_OPTION.relic_equip == 0 then
        return
    end
    local charbaseinfo1_my = ui.GetFrame("charbaseinfo1_my")
    local pcRelicGauge = charbaseinfo1_my:CreateOrGetControl("gauge", "pcRelicGauge", -1, 54, 104, 11)
    AUTO_CAST(pcRelicGauge)
    local pcRelic_text = pcRelicGauge:CreateOrGetControl("richtext", "pcRelic_text", 0, 0, 50, 0)
    AUTO_CAST(pcRelic_text)
    pcRelicGauge:SetGravity(ui.CENTER_HORZ, ui.TOP)
    pcRelicGauge:EnableHitTest(0)
    pcRelicGauge:SetSkinName("pcinfo_gauge_rp_relic")
    pcRelicGauge:StopTimeProcess()
    local pc = GetMyPCObject()
    local cur_rp, max_rp = shared_item_relic.get_rp(pc)
    pcRelic_text:SetGravity(ui.CENTER_HORZ, ui.CENTER_VERT)
    pcRelic_text:SetText("{ol}{s12}" .. cur_rp)
    pcRelicGauge:SetPoint(cur_rp / 10, max_rp / 10)
end
