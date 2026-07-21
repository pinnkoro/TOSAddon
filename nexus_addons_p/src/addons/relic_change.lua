-- relic_change ここから
function Relic_change_save_settings()
    g.save_json(g.relic_change_path, g.relic_change_settings)
end

function Relic_change_load_settings()
    g.relic_change_path = string.format("../addons/%s/%s/relic_change.json", addon_name_lower, g.active_id)
    local settings = g.load_json(g.relic_change_path)
    if not settings then
        settings = {
            x = 0,
            y = 0,
            move = 0
        }
    end
    g.relic_change_settings = settings
    Relic_change_save_settings()
end

function relic_change_on_init()
    if not g.relic_change_settings then
        Relic_change_load_settings()
    end
    local old_func = g.settings.relic_change.old_init_func
    if _G[old_func] then
        return
    end
    if g.settings.relic_change.use == 0 then
        local relic_change = ui.GetFrame(addon_name_lower .. "relic_change")
        if relic_change then
            ui.DestroyFrame(addon_name_lower .. "relic_change")
        end
        return
    end
    if g.get_map_type() == "City" then
        Relic_change_frame_init()
    end
end

function Relic_change_frame_init()
    local relic_change = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "relic_change", 0, 0, 0, 0)
    AUTO_CAST(relic_change)
    relic_change:SetSkinName('None')
    relic_change:SetTitleBarSkin("None")
    relic_change:Resize(40, 35)
    relic_change:SetGravity(ui.RIGHT, ui.TOP)
    relic_change:EnableHitTest(1)
    relic_change:EnableHittestFrame(1)
    relic_change:EnableMove(g.relic_change_settings.move)
    local rect = relic_change:GetMargin()
    relic_change:SetMargin(rect.left - rect.left, rect.top - rect.top + 300, rect.right + 50, rect.bottom)
    if g.relic_change_settings.x ~= 0 and g.relic_change_settings.y ~= 0 then
        relic_change:SetPos(g.relic_change_settings.x, g.relic_change_settings.y)
    end
    relic_change:SetEventScript(ui.LBUTTONUP, "Relic_change_frame_move")
    local slot = relic_change:CreateOrGetControl("slot", "slot", 0, 0, 35, 35)
    AUTO_CAST(slot)
    slot:SetGravity(ui.LEFT, ui.TOP)
    slot:EnablePop(0)
    slot:EnableDrop(0)
    slot:EnableDrag(0)
    slot:SetSkinName('None')
    slot:SetEventScript(ui.LBUTTONUP, "Relic_change_relicmanager_open")
    slot:SetEventScript(ui.RBUTTONUP, "Relic_change_frame_context")
    local icon = CreateIcon(slot)
    AUTO_CAST(icon)
    local item_cls = GetClassByType('Item', 845000)
    icon:SetImage(item_cls.Icon)
    icon:SetTextTooltip(g.lang == "Japanese" and
                            "{ol}左クリック:シアンジェム入替え{nl}右クリック:フレーム設定" or
                            "{ol}Left Click: Cyan Gem swap{nl}Right Click: Frame settings")
    relic_change:ShowWindow(1)
end

function Relic_change_frame_context(relic_change, slot)
    local context = ui.CreateContextMenu("CONTEXT", "{ol}Relic Change Setting", 0, 0, 0, 0)
    ui.AddContextMenuItem(context, "-----", "None")
    ui.AddContextMenuItem(context, g.lang == "Japanese" and "{ol}フレーム固定" or "{ol}Fix frame",
        "Relic_change_gem_move_setting()")
    ui.AddContextMenuItem(context,
        g.lang == "Japanese" and "{ol}フレーム位置を戻す" or "{ol}Restore frame position",
        "Relic_change_gem_move_restore()")
    ui.OpenContextMenu(context)
end

function Relic_change_gem_move_setting()
    if g.relic_change_settings.move == 0 then
        g.relic_change_settings.move = 1
    else
        g.relic_change_settings.move = 0
    end
    Relic_change_save_settings()
    ui.DestroyFrame(addon_name_lower .. "relic_change")
    ReserveScript("Relic_change_frame_init()", 0.1)
end

function Relic_change_gem_move_restore(relic_change)
    g.relic_change_settings.x = 0
    g.relic_change_settings.y = 0
    Relic_change_save_settings()
    ui.DestroyFrame(addon_name_lower .. "relic_change")
    ReserveScript("Relic_change_frame_init()", 0.1)
end

function Relic_change_frame_move(relic_change)
    g.relic_change_settings.x = relic_change:GetX()
    g.relic_change_settings.y = relic_change:GetY()
    Relic_change_save_settings()
end

function Relic_change_relicmanager_open(relic_change, slot)
    local inventory = ui.GetFrame("inventory")
    if inventory:IsVisible() == 0 then
        UI_TOGGLE_INVENTORY()
        local inventype_Tab = GET_CHILD_RECURSIVELY(inventory, "inventype_Tab")
        inventype_Tab:SelectTab(6)
    end
    local relicmanager = ui.GetFrame("relicmanager")
    relicmanager:ShowWindow(1)
    local tab = GET_CHILD_RECURSIVELY(relicmanager, 'type_Tab')
    tab:SelectTab(2)
    RELICMANAGER_SOCKET_UPDATE(relicmanager)
    Relic_change_context()
end

function Relic_change_context()
    local relic_gems = {}
    local inv_item_list = session.GetInvItemList()
    local guid_list = inv_item_list:GetGuidList()
    local cnt = guid_list:Count()
    for i = 0, cnt - 1 do
        local guid = guid_list:Get(i)
        local inv_item = inv_item_list:GetItemByGuid(guid)
        local item_obj = GetIES(inv_item:GetObject())
        local item_name = item_obj.Name
        if string.find(item_obj.ClassName, "Gem_Relic_Cyan") then
            local lv = TryGetProp(item_obj, 'GemLevel', 0)
            local existing_gem = relic_gems[item_obj.ClassID]
            if not existing_gem or lv > existing_gem.level then
                relic_gems[item_obj.ClassID] = {
                    level = lv,
                    guid = guid,
                    name = item_obj.Name
                }
            end
        end
    end
    local context = ui.CreateContextMenu("CONTEXT", "{ol}Relic Cyan Change", 0, 0, 0, 0)
    ui.AddContextMenuItem(context, "-----", "None")
    for gem_id, gem_data in pairs(relic_gems) do
        ui.AddContextMenuItem(context, dictionary.ReplaceDicIDInCompStr(gem_data.name) .. "Lv." .. gem_data.level,
            string.format("Relic_change_gem_remove(%s)", gem_data.guid))
    end
    ui.OpenContextMenu(context)
end

function Relic_change_gem_remove(guid)
    local arg_list = string.format('%d', 0)
    local relicmanager = ui.GetFrame('relicmanager')
    local relic_id = relicmanager:GetUserValue('RELIC_GUID')
    pc.ReqExecuteTx_Item('RELIC_SOCKET_GEM_REMOVE', relic_id, arg_list)
    relicmanager:SetUserValue("GEM_IESID", guid)
    relicmanager:RunUpdateScript("Relic_change_gem_add", 1.0)
end

function Relic_change_gem_add(relicmanager)
    local guid = relicmanager:GetUserValue("GEM_IESID")
    local relic_item = session.GetEquipItemBySpot(item.GetEquipSpotNum('RELIC'))
    local inv_item = session.GetInvItemByGuid(guid)
    if inv_item.isLockState == true then
        ui.SysMsg(ClMsg('MaterialItemIsLock'))
        return
    end
    session.ResetItemList()
    session.AddItemID(relic_item:GetIESID(), 1)
    session.AddItemID(inv_item:GetIESID(), 1)
    _RELICMANAGER_SOCKET_GEM_ADD()
    relicmanager:StopUpdateScript("Relic_change_gem_add")
    relicmanager:RunUpdateScript("Relic_change_end", 1.0)
end

function Relic_change_end(relicmanager)
    relicmanager:StopUpdateScript("Relic_change_end")
    RELICMANAGER_CLOSE(relicmanager)
    local inventory = ui.GetFrame("inventory")
    if inventory:IsVisible() == 1 then
        UI_TOGGLE_INVENTORY()
        local inventype_Tab = GET_CHILD_RECURSIVELY(inventory, "inventype_Tab")
        inventype_Tab:SelectTab(0)
    end
    ui.SysMsg("[RC]End of Operation")
end
-- relic_change ここまで

