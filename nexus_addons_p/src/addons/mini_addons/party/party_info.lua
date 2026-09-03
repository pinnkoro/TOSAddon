-- パーティー情報フレームを小さくする
function Mini_addons_PARTY_BUFFLIST_UPDATE(frame, msg)
    -- **Party Icon Only が ON のときは触らない。** あちらは partyinfo を
    -- 「掴み代 + アイコンの列」(横 50px)まで縮めて当たり判定ごと畳んでいる。ここで
    -- 広げ直すと**見た目は畳んだままなのに当たり判定だけ広がる**という一番分かりにくい
    -- 形になる。しかも下の OFF 側の分岐も GetOriginalWidth() = 700px へ戻すので、
    -- **この機能(party_info)を使っていなくても**起きる。この関数は 5 秒ごとの更新からも
    -- 呼ばれ、あちらは 0.5 秒周期で畳み直すため、押せる帯が点滅するように現れていた。
    -- **展開表示のときは触ってよい。** あちらが畳んでいる(格納)ときだけ待避する。
    local pio = core_g.settings and core_g.settings.party_icon_only
    if pio and pio.use == 1 and pio.expanded ~= 1 then
        return
    end
    local party_info = ui.GetFrame("partyinfo")
    local list = session.party.GetPartyMemberList(PARTY_NORMAL)
    local member_count = list:Count()
    local display_count = member_count - 1
    if display_count < 0 then
        display_count = 0
    end
    if g.settings.party_info == 0 then
        -- OFF のときは素の見た目へ戻すだけにする。幅 560 は素の値ではないので、
        -- partyinfo.xml と同じ値(= GetOriginalWidth / layerlevel 50)へ戻す。
        -- 高さは素の PARTY_BUFFLIST_UPDATE が自分で計算するので触らない
        party_info:Resize(party_info:GetOriginalWidth(), party_info:GetHeight())
        party_info:SetLayerLevel(50)
        return
    end
    local max_buff_width = 0
    local slot_size = 25 -- スロット1つの幅
    for i = 0, member_count - 1 do
        local party_member_info = list:Element(i)
        local party_info_ctrl_set = party_info:GetChild('PTINFO_' .. party_member_info:GetAID())
        if party_info_ctrl_set then
            local current_member_buffs = 0
            local buff_list = GET_CHILD(party_info_ctrl_set, "buffList", "ui::CSlotSet")
            if buff_list then
                for j = 0, buff_list:GetSlotCount() - 1 do
                    local slot = buff_list:GetSlotByIndex(j)
                    if slot and slot:IsVisible() == 1 then
                        local icon = slot:GetIcon()
                        if icon then
                            current_member_buffs = current_member_buffs + 1
                        end
                    end
                end
            end
            local debuff_list = GET_CHILD(party_info_ctrl_set, "debuffList", "ui::CSlotSet")
            if debuff_list then
                for j = 0, debuff_list:GetSlotCount() - 1 do
                    local slot = debuff_list:GetSlotByIndex(j)
                    if slot and slot:IsVisible() == 1 then
                        local icon = slot:GetIcon()
                        if icon then
                            current_member_buffs = current_member_buffs + 1
                        end
                    end
                end
            end
            local needed_width = current_member_buffs * slot_size
            if needed_width > max_buff_width then
                max_buff_width = needed_width
            end
        end
    end
    party_info:Resize(250 + max_buff_width, display_count * 100 + 60)
    party_info:SetLayerLevel(0)
end

--[[function mini_addons_partyinfo_resize(partyinfo, ctrl, str, num)
    local list = session.party.GetPartyMemberList(PARTY_NORMAL)
    local count = list:Count() - 1
    if count < 0 then
        count = 0
    end
    if partyinfo:GetWidth() == 80 then
        partyinfo:Resize(560, count * 100 + 60)
    else
        partyinfo:Resize(80, count * 100 + 60)
    end
end]]
