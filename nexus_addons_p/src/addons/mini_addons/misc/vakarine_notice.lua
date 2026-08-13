-- ヴァカリネを伝える
function Mini_addons_vakarine_notice()
    if g.settings.vakarine == 0 then
        return
    end
    local map_name = session.GetMapName()
    local map_cls = GetClass("Map", map_name)
    local keyword = TryGetProp(map_cls, "Keyword", "None")
    local keyword_table = StringSplit(keyword, ";")
    if table.find(keyword_table, "IsRaidField") == 0 then
        return
    end
    local equip_item_list = session.GetEquipItemList()
    local equip_guid_list = equip_item_list:GetGuidList()
    local count = equip_guid_list:Count()
    local vakarine_count = 0
    local max_option = MAX_OPTION_EXTRACT_COUNT or 6
    for i = 0, count - 1 do
        local guid = equip_guid_list:Get(i)
        if guid ~= "0" then
            local equip_item = equip_item_list:GetItemByGuid(guid)
            if equip_item and equip_item:GetObject() then
                local item = GetIES(equip_item:GetObject())
                for j = 1, max_option do
                    local prop_name = "RandomOption_" .. j
                    local cls_msg = ScpArgMsg(item[prop_name])
                    if string.find(cls_msg, "vakarine_bless") then
                        vakarine_count = vakarine_count + 1
                    end
                end
            end
        end
    end
    if vakarine_count >= 5 then
        ui.Chat("!! " .. "vakarine")
    end
end
