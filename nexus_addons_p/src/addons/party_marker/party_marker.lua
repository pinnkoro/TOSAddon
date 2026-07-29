-- Party Marker　ここから
function party_marker_on_init()
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    if _nexus_addons_p then
        _nexus_addons_p:SetVisible(1)
        local party_marker_timer = _nexus_addons_p:CreateOrGetControl("timer", "party_marker_timer", 0, 0)
        AUTO_CAST(party_marker_timer)
        party_marker_timer:SetUpdateScript("Party_marker_set")
        party_marker_timer:Start(0.5)
    end
end

-- 機能 OFF にされたときの後始末(core/20_lifecycle.lua が use==0 のとき on_init の
-- 代わりに呼ぶ)。
--
-- 以前は on_init で use を見ておらず、Party_marker_set 側も use==0 のとき
-- 目印を消すだけで **タイマーを止めていなかった**。そのため OFF にしても、
-- そのマップに居る間はずっと 0.5 秒ごとにパーティ一覧を舐め続けていた
-- (boss_direction と同じ形。マップをまたぐかどうかは g.stop_timer のコメント参照)。
-- **順序が要る**: 先に止めると tick が来なくなり、出ている目印を消せなくなる。
function party_marker_on_teardown()
    Party_marker_cleanup()
    g.stop_timer("party_marker_timer")
end

function Party_marker_cleanup()
    if g.party_marker and next(g.party_marker) then
        for handle_str, _ in pairs(g.party_marker) do
            local party_marker = ui.GetFrame("party_marker" .. handle_str)
            if party_marker then
                ui.DestroyFrame(party_marker:GetName())
            end
        end
        g.party_marker = {}
    end
end

function Party_marker_set(_nexus_addons_p, party_marker_timer)
    -- 保険。通常は on_teardown が止めるが、そこを通らずに OFF になった場合でも
    -- 回り続けないようにする。
    if g.settings.party_marker.use == 0 then
        party_marker_on_teardown()
        return
    end
    local party_list = session.party.GetPartyMemberList(PARTY_NORMAL)
    -- テスト用ギルドメンバー
    -- local party_list = session.party.GetPartyMemberList(PARTY_GUILD)
    if not party_list or party_list:Count() <= 1 then
        Party_marker_cleanup()
        return
    end
    local current_party = {}
    for i = 0, party_list:Count() - 1 do
        local member = party_list:Element(i)
        if member then
            local handle = member:GetHandle()
            if handle ~= 0 then
                current_party[tostring(handle)] = handle
            end
        end
    end
    local is_colony = false
    local check_word = "GuildColony_"
    if string.find(g.map_name, check_word) then
        is_colony = true
    end
    g.party_marker = {}
    local list, count = SelectObject(GetMyPCObject(), 1000, 'ALL')
    for i = 1, count do
        if list[i] then
            local handle = GetHandle(list[i])
            if info.IsPC(handle) == 1 then
                local handle_str = tostring(handle)
                if current_party[handle_str] then
                    g.party_marker[handle_str] = handle
                    local party_marker = ui.GetFrame("party_marker" .. handle_str)
                    if not party_marker then
                        party_marker = ui.CreateNewFrame("notice_on_pc", "party_marker" .. handle_str, 0, 0, 50, 50)
                        party_marker:SetSkinName("None")
                        party_marker:SetLayerLevel(80)
                        local pic = party_marker:CreateOrGetControl('picture', 'marker', 0, 0, 50, 50)
                        AUTO_CAST(pic)
                        pic:SetImage("friend_party")
                        pic:SetEnableStretch(1)
                    end
                    if is_colony then
                        FRAME_AUTO_POS_TO_OBJ(party_marker, handle, 25, -70, 3, 1, 1)
                    else
                        FRAME_AUTO_POS_TO_OBJ(party_marker, handle, -25, -70, 3, 1, 1)
                    end
                    party_marker:ShowWindow(1)
                end
            end
        end
    end
    for handle_str, _ in pairs(current_party) do
        if not g.party_marker[handle_str] then
            local party_marker = ui.GetFrame("party_marker" .. handle_str)
            if party_marker then
                ui.DestroyFrame(party_marker:GetName())
            end
        end
    end
end
-- Party Marker　ここまで

