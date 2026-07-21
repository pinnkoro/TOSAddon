-- pick_item_tracker ここから
g.pick_item_tracker_grade_colors = {
    [0] = "#FFBF33", -- Unique
    [1] = "#FFFFFF", -- Normal
    [2] = "#108CFF", -- Magic
    [3] = "#9F30FF", -- Rare
    [4] = "#FF4F00", -- Legend
    [5] = "#FFFF53" -- Goddess
}
function Pick_item_tracker_save_settings()
    g.save_json(g.pick_item_tracker_path, g.pick_item_tracker_settings)
end

function Pick_item_tracker_load_settings()
    g.pick_item_tracker_path = string.format("../addons/%s/%s/pick_item_tracker.json", addon_name_lower, g.active_id)
    local settings = g.load_json(g.pick_item_tracker_path)
    if not settings then
        settings = {
            move = 1,
            x = 330,
            y = 330
        }
    end
    g.pick_item_tracker_settings = settings
    Pick_item_tracker_save_settings()
end

function pick_item_tracker_on_init()
    if not g.pick_item_tracker_settings then
        Pick_item_tracker_load_settings()
    end
    local old_func = g.settings.pick_item_tracker.old_init_func
    if _G[old_func] then
        return
    end
    if g.get_map_type() ~= "City" and g.get_map_type() ~= "Instance" then
        if not g.pick_item_tracker_map_id or g.map_id ~= g.pick_item_tracker_map_id then
            g.pick_item_tracker_map_id = g.map_id
            g.pick_item_tracker_start_time = imcTime.GetAppTimeMS() - 3000
            g.pick_item_tracker_items = {}
            g.pick_item_tracker_y = 45
            g.pick_item_tracker_x = 120
        end
        g.addon:RegisterMsg('ITEM_PICK', 'Pick_item_tracker_ITEMMSG_ITEM_COUNT')
        Pick_item_tracker_frame_init()
    else
        g.pick_item_tracker_map_id = nil
        g.pick_item_tracker_items = {}
        g.pick_item_tracker_y = 45
        g.pick_item_tracker_x = 120
        Pick_item_tracker_frame_init("is_city")
    end
end

function Pick_item_tracker_frame_init(msg)
    local pick_item_tracker = ui.CreateNewFrame("chat_memberlist", addon_name_lower .. "pick_item_tracker", 0, 0, 0, 0)
    AUTO_CAST(pick_item_tracker)
    pick_item_tracker:EnableHitTest(1)
    pick_item_tracker:EnableHittestFrame(1)
    pick_item_tracker:EnableMove(g.pick_item_tracker_settings.move)
    pick_item_tracker:SetPos(g.pick_item_tracker_settings.x, g.pick_item_tracker_settings.y)
    pick_item_tracker:SetTitleBarSkin("None")
    pick_item_tracker:SetSkinName("None")
    pick_item_tracker:SetLayerLevel(61)
    pick_item_tracker:SetEventScript(ui.LBUTTONUP, "Pick_item_tracker_frame_move")
    pick_item_tracker:SetEventScript(ui.RBUTTONUP, "Pick_item_tracker_frame_lock")
    local title_text = pick_item_tracker:CreateOrGetControl("richtext", "title_text", 20, 10)
    AUTO_CAST(title_text)
    title_text:SetText("{ol}{S10}Pick Item Tracker")
    title_text:SetTextTooltip("{ol}Right click to position lock")
    title_text:SetEventScript(ui.LBUTTONUP, "Pick_item_tracker_frame_move")
    title_text:SetEventScript(ui.RBUTTONUP, "Pick_item_tracker_frame_lock")
    local itemlock = pick_item_tracker:CreateOrGetControlSet('inv_itemlock', "itemlock", 0, 0)
    AUTO_CAST(itemlock)
    itemlock:SetGravity(ui.LEFT, ui.TOP)
    if g.pick_item_tracker_settings.move == 1 then
        itemlock:SetGrayStyle(1)
    else
        itemlock:SetGrayStyle(0)
    end
    pick_item_tracker:Resize(120, g.pick_item_tracker_y or 25)
    local gb = pick_item_tracker:CreateOrGetControl("groupbox", "gb", 0, 45, 90, pick_item_tracker:GetHeight() - 45)
    gb:SetSkinName("None")
    AUTO_CAST(gb)
    Pick_item_tracker_redraw_item_list(pick_item_tracker)
    local time_text = pick_item_tracker:CreateOrGetControl("richtext", "time_text", 25, 25)
    AUTO_CAST(time_text)
    if msg == "is_city" then
        pick_item_tracker:ShowWindow(0)
    else
        local pick_item_tracker_timer = pick_item_tracker:CreateOrGetControl("timer", "pick_item_tracker_timer", 0, 0)
        AUTO_CAST(pick_item_tracker_timer)
        pick_item_tracker_timer:SetUpdateScript("Pick_item_tracker_timer_update")
        pick_item_tracker_timer:Start(1.0)
        pick_item_tracker:ShowWindow(1)
    end
end

function Pick_item_tracker_frame_move(pick_item_tracker)
    g.pick_item_tracker_settings.x = pick_item_tracker:GetX()
    g.pick_item_tracker_settings.y = pick_item_tracker:GetY()
    Pick_item_tracker_save_settings()
end

function Pick_item_tracker_frame_lock(pick_item_tracker)
    local itemlock = GET_CHILD(pick_item_tracker, "itemlock")
    if g.pick_item_tracker_settings.move == 1 then
        g.pick_item_tracker_settings.move = 0
        itemlock:SetGrayStyle(0)
    else
        g.pick_item_tracker_settings.move = 1
        itemlock:SetGrayStyle(1)
    end
    pick_item_tracker:EnableMove(g.pick_item_tracker_settings.move)
    Pick_item_tracker_save_settings()
end

function Pick_item_tracker_redraw_item_list(pick_item_tracker)
    local gb = GET_CHILD(pick_item_tracker, "gb")
    gb:RemoveAllChild()
    local count = 0
    local keys = {}
    for k in pairs(g.pick_item_tracker_items) do
        table.insert(keys, k)
    end
    table.sort(keys)
    for i, k in ipairs(keys) do
        local v = g.pick_item_tracker_items[k]
        local item_text = gb:CreateOrGetControl("richtext", "item_text" .. k, 5, count * 25)
        AUTO_CAST(item_text)
        count = count + 1
        local item_cls = GetClassByType("Item", v.cls_id)
        local color = g.pick_item_tracker_grade_colors[item_cls.ItemGrade] or "#FFFFFF"
        item_text:SetText("{img " .. item_cls.Icon .. " 20 20}" .. "{ol}{s15}{" .. color .. "}" ..
                              dictionary.ReplaceDicIDInCompStr(k) .. "{/}{ol}{s14}{#00FF00}( + " .. v.item_count .. " )")
        if g.pick_item_tracker_x < item_text:GetWidth() then
            g.pick_item_tracker_x = item_text:GetWidth()
        end
    end
    g.pick_item_tracker_y = count * 25 + 50
    pick_item_tracker:Resize(g.pick_item_tracker_x + 15, g.pick_item_tracker_y)
    gb:Resize(pick_item_tracker:GetWidth(), pick_item_tracker:GetHeight() - 45)
end

function Pick_item_tracker_timer_update(pick_item_tracker, timer)
    g.pick_item_tracker_diff_time = imcTime.GetAppTimeMS() - g.pick_item_tracker_start_time
    local h = math.floor(g.pick_item_tracker_diff_time / (60 * 60 * 1000))
    local m = math.floor((g.pick_item_tracker_diff_time / (60 * 1000)) % 60)
    local s = math.floor((g.pick_item_tracker_diff_time / 1000) % 60)
    local time_text = GET_CHILD(pick_item_tracker, "time_text")
    time_text:SetText(string.format("{ol}{s14}%02d:%02d:%02d{/}", h, m, s))
    if g.settings.pick_item_tracker.use == 1 then
        pick_item_tracker:ShowWindow(1)
    else
        ui.DestroyFrame(pick_item_tracker:GetName())
    end
end

function Pick_item_tracker_ITEMMSG_ITEM_COUNT(frame, msg, cls_id, item_count)
    local num = tonumber(cls_id)
    if num then
        cls_id = math.floor(num)
    end
    local item_cls = GetClassByType("Item", cls_id)
    local item_name = item_cls.Name
    local items = g.pick_item_tracker_items
    if not items[item_name] then
        items[item_name] = {
            cls_id = cls_id,
            item_count = item_count
        }
        Pick_item_tracker_frame_update(item_name, item_count, cls_id, "new")
    else
        items[item_name].cls_id = cls_id
        items[item_name].item_count = items[item_name].item_count + item_count
        Pick_item_tracker_frame_update(item_name, items[item_name].item_count, items[item_name].cls_id)
    end
end

function Pick_item_tracker_frame_update(item_name, item_count, cls_id, new)
    local pick_item_tracker = ui.GetFrame(addon_name_lower .. "pick_item_tracker")
    if new == "new" then
        Pick_item_tracker_redraw_item_list(pick_item_tracker)
    else
        local gb = GET_CHILD(pick_item_tracker, "gb")
        local item_text = GET_CHILD(gb, "item_text" .. item_name)
        local item_cls = GetClassByType("Item", cls_id)
        local color = g.pick_item_tracker_grade_colors[item_cls.ItemGrade] or "#FFFFFF"
        item_text:SetText("{img " .. item_cls.Icon .. " 20 20}" .. "{ol}{s15}{" .. color .. "}" ..
                              dictionary.ReplaceDicIDInCompStr(item_name) .. "{/}{ol}{s14}{#00FF00}( + " .. item_count ..
                              " )")
        pick_item_tracker:Resize(g.pick_item_tracker_x + 15, g.pick_item_tracker_y)
        gb:Resize(pick_item_tracker:GetWidth(), pick_item_tracker:GetHeight() - 45)
    end
end
-- pick_item_tracker ここまで

