-- チャンネルのズレを直す
function Mini_addons_UPDATE_CURRENT_CHANNEL_TRAFFIC(frame)
    -- 置換方式のフックなので、OFF のときは素の実装へ回す。
    -- ここで自前の分岐へ落とすとチャンネル欄が空になる
    if g.settings.channel_display ~= 1 then
        if g.FUNCS["UPDATE_CURRENT_CHANNEL_TRAFFIC"] then
            return g.FUNCS["UPDATE_CURRENT_CHANNEL_TRAFFIC"](frame)
        end
        -- 控えが無い = 素の実装へ戻せない。チャンネル欄が空のままになるので知らせる
        core_g.vlog("mini_addons: UPDATE_CURRENT_CHANNEL_TRAFFIC の素の実装が控えに無い")
        return
    end
    local curchannel = frame:GetChild("curchannel")
    local channel = session.loginInfo.GetChannel()
    local zone_inst = session.serverState.GetZoneInst(channel)
    local function set_channel_text(str, state_string)
        local spacing = (g.lang == "Japanese") and "                      " or "                                  "
        curchannel:SetTextByKey("value", str .. spacing .. state_string)
    end
    if zone_inst then
        local str, state_string
        if GET_PRIVATE_CHANNEL_ACTIVE_STATE() == false then
            str, state_string = GET_CHANNEL_STRING(zone_inst)
        else
            local suffix = GET_SUFFIX_PRIVATE_CHANNEL(zone_inst.mapID, zone_inst.channel + 1)
            str, state_string = GET_CHANNEL_STRING(zone_inst, suffix)
        end
        set_channel_text(str, state_string)
    else
        curchannel:SetTextByKey("value", "")
    end
end
