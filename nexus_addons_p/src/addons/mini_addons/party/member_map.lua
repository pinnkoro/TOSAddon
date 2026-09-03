-- パーティーメンバーの場所表示
function Mini_addons_partymember_get_map()
    if g.settings.pt_info == 0 then
        return
    end
    -- **Party Icon Only が「格納」のときは触らない。** あちらは行をアイコンだけに畳むので、
    -- ここで足す location<n> は 5 秒ごとに作られては 0.5 秒後に隠される、の繰り返しになる。
    -- 「展開」に切り替えられているときは素の表示へ戻っているので、こちらも普通に出す。
    local pio = core_g.settings and core_g.settings.party_icon_only
    if pio and pio.use == 1 and pio.expanded ~= 1 then
        return
    end
    local list = session.party.GetPartyMemberList(PARTY_NORMAL)
    local count = list:Count()
    if count == 1 then
        return
    end
    local party_info = ui.GetFrame("partyinfo")
    if not party_info then
        return
    end
    for i = 0, count - 1 do
        local party_member_info = list:Element(i)
        if party_member_info and party_member_info:GetMapID() > 0 then
            local map_cls = GetClassByType("Map", party_member_info:GetMapID())
            if map_cls then
                local party_info_ctrl_set = party_info:GetChild("PTINFO_" .. party_member_info:GetAID())
                if party_info_ctrl_set then
                    local location = party_info_ctrl_set:CreateOrGetControl("richtext", "location" .. i, 0, 0, 0, 0)
                    AUTO_CAST(location)
                    location:SetText("")
                    location:SetText(string.format("{s12}{ol}[%s-%d]", map_cls.Name, party_member_info:GetChannel() + 1))
                    location:Resize(100, 20)
                    location:SetOffset(10, 0)
                    location:ShowWindow(1)
                    local lv_box = party_info_ctrl_set:GetChild("lvbox")
                    local name_text = party_info_ctrl_set:GetChild("name_text")
                    if lv_box and name_text then
                        AUTO_CAST(lv_box)
                        AUTO_CAST(name_text)
                        local name_x = lv_box:GetX() + lv_box:GetWidth()
                        name_text:SetPos(name_x, -12)
                    end
                end
            end
        end
    end
end
