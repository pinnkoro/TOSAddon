-- monster_kill_count ここから 
function Monster_kill_count_save_settings()
    g.save_json(g.mkc_path, g.mkc_settings)
end

function Monster_kill_count_load_settings()
    g.mkc_path = string.format("../addons/%s/%s/monster_kill_count.json", addon_name_lower, g.active_id)
    g.mkc_old_path = string.format("../addons/%s/%s/settings.json", "klcount", g.active_id)
    local settings = g.load_json(g.mkc_path)
    if settings then
        g.mkc_settings = settings
        return
    end
    local allowed_map_ids_by_level = {}
    local map_list, cnt = GetClassList("Map")
    for i = 0, cnt - 1 do
        local map_cls = GetClassByIndexFromList(map_list, i)
        if map_cls then
            local map_level = map_cls.QuestLevel
            local my_level = info.GetLevel(session.GetMyHandle())
            if math.abs(my_level - map_level) <= 50 or map_cls.ClassID == 11244 then
                allowed_map_ids_by_level[tostring(map_cls.ClassID)] = true
            end
        end
    end
    local old_settings = g.load_json(g.mkc_old_path)
    local final_map_ids = {}
    if old_settings then
        settings = {
            frame_x = old_settings.frame_x or 1340,
            frame_y = old_settings.frame_y or 20,
            map_ids = {}
        }
        local old_dir = string.format("../addons/%s/%s/", "klcount", g.active_id)
        local new_folder_path = string.format("../addons/%s/%s/%s", addon_name_lower, g.active_id, "monster_kill_count")
        os.execute('mkdir "' .. new_folder_path .. '"')
        for map_id, _ in pairs(allowed_map_ids_by_level) do
            local old_file_path = old_dir .. map_id .. ".json"
            local new_file_path = new_folder_path .. "/" .. map_id .. ".json"
            local old_file = io.open(old_file_path, "r")
            if old_file then
                local content = old_file:read("*a")
                old_file:close()
                if content and content ~= "" and pcall(json.decode, content) then
                    local new_file = io.open(new_file_path, "w")
                    if new_file then
                        new_file:write(content)
                        new_file:close()
                        table.insert(final_map_ids, tonumber(map_id))
                    end
                end
            end
        end
    else
        settings = {
            frame_x = 1340,
            frame_y = 20,
            map_ids = {}
        }
    end
    local folder_path = string.format("../addons/%s/%s/%s", addon_name_lower, g.active_id, "monster_kill_count")
    local win_folder_path = string.gsub(folder_path, "/", "\\")
    local list_file_path = folder_path .. "/filelist_temp.txt"
    os.execute('dir "' .. win_folder_path .. '\\*.json" /b > "' .. list_file_path .. '"')
    local list_file = io.open(list_file_path, "r")
    if list_file then
        for line in list_file:lines() do
            local map_id = string.match(line, "(%d+)%.json")
            local file_path = folder_path .. "/" .. map_id .. ".json"
            local file = io.open(file_path, "r")
            if file then
                local content = file:read("*a")
                file:close()
                if content and content ~= "" and pcall(json.decode, content) then
                    local is_new = true
                    for _, existing_id in pairs(final_map_ids) do
                        if tostring(existing_id) == map_id then
                            is_new = false
                            break
                        end
                    end
                    if is_new then
                        if is_new and allowed_map_ids_by_level[map_id] then
                            table.insert(final_map_ids, map_id)
                            ts("Found orphan file, adding to list: " .. map_id)
                        end
                    end
                else
                    ts("Broken JSON removed: " .. tostring(map_id))
                    os.remove(file_path)
                end
            end
        end
        list_file:close()
    end
    os.remove(list_file_path)
    settings.map_ids = final_map_ids
    g.mkc_settings = settings
    Monster_kill_count_save_settings()
end

function monster_kill_count_on_init()
    if not g.mkc_settings then
        Monster_kill_count_load_settings()
    end
    local old_func = g.settings.monster_kill_count.old_init_func
    if _G[old_func] then
        return
    end
    g.setup_hook_and_event(g.addon, "APPLY_SCREEN", "Monster_kill_count_APPLY_SCREEN", true)
    if g.get_map_type() == "Field" or g.get_map_type() == "Dungeon" then
        local map_cls = GetClass("Map", g.map_name)
        local map_level = map_cls.QuestLevel
        local my_level = info.GetLevel(session.GetMyHandle())
        if my_level - map_level <= 50 or g.map_id == 11244 then
            local colony_list, cnt = GetClassList("guild_colony")
            for i = 0, cnt - 1 do
                local check_word = "GuildColony_"
                if string.find(g.map_name, check_word) then
                    return
                end
            end
            local list = session.party.GetPartyMemberList(PARTY_NORMAL)
            local count = list:Count()
            for i = 0, count - 1 do
                local party_member_info = list:Element(i)
                local name = party_member_info:GetName()
                local channel = party_member_info:GetChannel() + 1
                if channel > 10 then
                    return
                end
            end
            g.addon:RegisterMsg("EXP_UPDATE", "Monster_kill_count_EXP_UPDATE")
            g.addon:RegisterMsg("ITEM_PICK", "Monster_kill_count_ITEM_PICK")
            g.addon:RegisterMsg("UI_CHALLENGE_MODE_TOTAL_KILL_COUNT",
                "Monster_kill_count_ON_CHALLENGE_MODE_TOTAL_KILL_COUNT")
            g.mkc_autosave_counter = 0
            if not g.mkc_map_id then
                g.mkc_map_id = g.map_id
                g.mkc_count = 0
                g.mkc_start_time = imcTime.GetAppTimeMS() - 3000
                g.mkc_last_tick_ms = g.mkc_start_time
            elseif g.mkc_map_id ~= g.map_id then
                local map_file_path = Monster_kill_count_get_map_filepath(g.mkc_map_id)
                local map_data = g.load_json(map_file_path)
                if map_data then
                    g.save_json(map_file_path, map_data)
                end
                g.mkc_count = 0
                g.mkc_start_time = imcTime.GetAppTimeMS() - 3000
                g.mkc_last_tick_ms = g.mkc_start_time
                g.mkc_map_id = g.map_id
            end
            local map_file_path = Monster_kill_count_get_map_filepath(g.map_id)
            local map_data = g.load_json(map_file_path)
            if not map_data then
                map_data = {
                    map_name = g.map_name,
                    stay_time = 3000,
                    kill_count = 0,
                    get_items = {}
                }
            end
            g.mkc_map_data = map_data
            g.save_json(map_file_path, map_data)
            Monster_kill_count_frame_init()
        end
    else
        if g.mkc_map_id then
            local map_file_path = Monster_kill_count_get_map_filepath(g.mkc_map_id)
            local map_data = g.load_json(map_file_path)
            if map_data then
                g.save_json(map_file_path, map_data)
            end
            g.mkc_map_id = nil
            g.mkc_count = nil
            g.mkc_start_time = nil
            ui.DestroyFrame(addon_name_lower .. "monster_kill_count")
            local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
            _nexus_addons_p:RemoveChild("monster_kill_count_timer")
        end
    end
end

function Monster_kill_count_ON_CHALLENGE_MODE_TOTAL_KILL_COUNT(frame, msg)
    ui.DestroyFrame(addon_name_lower .. "monster_kill_count")
end

function Monster_kill_count_get_map_filepath(map_id)
    return string.format("../addons/%s/%s/%s/%s.json", addon_name_lower, g.active_id, "monster_kill_count", map_id)
end

function Monster_kill_count_APPLY_SCREEN(my_frame, my_msg)
    Monster_kill_count_frame_init()
end

function Monster_kill_count_EXP_UPDATE(frame, msg)
    local monster_kill_count = ui.GetFrame(addon_name_lower .. "monster_kill_count")
    local count_text = GET_CHILD(monster_kill_count, "count_text")
    AUTO_CAST(count_text)
    g.mkc_count = g.mkc_count + 1
    count_text:SetText(string.format("{ol}{s16}Count : %d{/}", g.mkc_count))
    g.mkc_map_data.kill_count = g.mkc_map_data.kill_count + 1
end

function Monster_kill_count_ITEM_PICK(frame, msg, class_id, item_count)
    local cls_id = tonumber(class_id)
    if cls_id then
        cls_id = math.floor(cls_id)
        local cls_id_str = tostring(cls_id)
        g.mkc_map_data.get_items = g.mkc_map_data.get_items or {}
        if not g.mkc_map_data.get_items[cls_id_str] then
            g.mkc_map_data.get_items[cls_id_str] = item_count
        else
            g.mkc_map_data.get_items[cls_id_str] = g.mkc_map_data.get_items[cls_id_str] + item_count
        end
    end
end

function Monster_kill_count_frame_init()
    -- 元フレームに chat_memberlist を使うと ESC で閉じられて消える。ゲーム側の定義
    -- (addon.ipf の chat_memberlist.xml) が <option hideable="true"> で、ESC はこの
    -- hideable なフレームを閉じるため。notice_on_pc は hideable="false" なので消えない。
    -- update_frames の毎フレーム復帰は当てにできない。ESC の隠し方は IsVisible() に
    -- 反映されず、討伐やアイテム取得で再描画が走るまで戻らないため。ここを戻さないこと。
    local monster_kill_count =
        ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "monster_kill_count", 0, 0, 0, 0)
    AUTO_CAST(monster_kill_count)
    monster_kill_count:SetSkinName("shadow_box")
    monster_kill_count:SetTitleBarSkin("None")
    monster_kill_count:EnableHitTest(1)
    monster_kill_count:EnableMove(1)
    monster_kill_count:SetAlpha(80)
    monster_kill_count:SetLayerLevel(31)
    monster_kill_count:SetEventScript(ui.LBUTTONUP, "Monster_kill_count_pos")
    local map_frame = ui.GetFrame("map")
    local width = map_frame:GetWidth()
    local x = g.mkc_settings.frame_x
    if g.mkc_settings.frame_x > 1920 and width <= 1920 then
        local offset = g.mkc_settings.frame_x - 1920
        x = 1920 - offset
    end
    monster_kill_count:SetPos(x, g.mkc_settings.frame_y)
    local count_text = monster_kill_count:CreateOrGetControl("richtext", "count_text", 10, 10, 170, 30)
    AUTO_CAST(count_text)
    count_text:SetText(string.format("{ol}{s16}Count : %d{/}", g.mkc_count or 0))
    local map_name = GetClassByType("Map", g.map_id).Name
    local map_text = monster_kill_count:CreateOrGetControl("richtext", "map_text", 10, 35, 170, 30)
    AUTO_CAST(map_text)
    map_text:SetText(string.format("{ol}{s16}%s{/}", map_name))
    local w = 170
    if map_text:GetWidth() + 15 > 170 then
        w = map_text:GetWidth() + 15
    end
    local timer_text = monster_kill_count:CreateOrGetControl("richtext", "timer_text", 90, 60, 200, 30)
    AUTO_CAST(timer_text)
    timer_text:SetGravity(ui.RIGHT, ui.BOTTOM)
    local rect = timer_text:GetMargin()
    timer_text:SetMargin(rect.left, rect.top, rect.right + 15, rect.bottom + 15)
    monster_kill_count:Resize(w, 95)
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    local monster_kill_count_timer = _nexus_addons_p:CreateOrGetControl("timer", "monster_kill_count_timer", 0, 0)
    AUTO_CAST(monster_kill_count_timer)
    monster_kill_count_timer:SetUpdateScript("Monster_kill_count_time_update")
    monster_kill_count_timer:Start(1.0)
end

function Monster_kill_count_time_update(_nexus_addons_p)
    local monster_kill_count = ui.GetFrame(addon_name_lower .. "monster_kill_count")
    if g.settings.monster_kill_count.use == 1 then
        monster_kill_count:ShowWindow(1)
    else
        ui.DestroyFrame(addon_name_lower .. "monster_kill_count")
    end
    local now_ms = imcTime.GetAppTimeMS()
    g.mkc_diff_ms = now_ms - g.mkc_start_time
    local total_sec = math.floor(g.mkc_diff_ms / 1000)
    local h = math.floor(total_sec / 3600)
    local m = math.floor((total_sec % 3600) / 60)
    local s = (total_sec % 60)
    local timer_text = GET_CHILD(monster_kill_count, "timer_text")
    AUTO_CAST(timer_text)
    timer_text:SetText(string.format("{ol}{s16}%02d:%02d:%02d{/}", h, m, s))
    g.mkc_autosave_counter = g.mkc_autosave_counter + 1
    local delta_ms = now_ms - g.mkc_last_tick_ms
    if delta_ms < 0 then
        delta_ms = 0
    end
    g.mkc_last_tick_ms = now_ms
    g.mkc_map_data.stay_time = g.mkc_map_data.stay_time + delta_ms
    if g.mkc_autosave_counter >= 60 then
        local map_file_path = string.format("../addons/%s/%s/%s/%s.json", addon_name_lower, g.active_id,
            "monster_kill_count", g.map_id)
        g.save_json(map_file_path, g.mkc_map_data)
        g.mkc_autosave_counter = 0
    end
end

function Monster_kill_count_pos(monster_kill_count)
    g.mkc_settings.frame_x = monster_kill_count:GetX()
    g.mkc_settings.frame_y = monster_kill_count:GetY()
    Monster_kill_count_save_settings()
end

function Monster_kill_count_information_context()
    local context = ui.CreateContextMenu("monster_kill_count_context", "{ol}Map Info", 0, 0, 200, 0)
    local sorted_map_ids = {}
    for _, map_id in ipairs(g.mkc_settings.map_ids) do
        table.insert(sorted_map_ids, tonumber(map_id))
    end
    table.sort(sorted_map_ids, function(a, b)
        return a < b
    end)
    for i = 1, #sorted_map_ids do
        local map_id = sorted_map_ids[i]
        local map_id_str = tostring(map_id)
        local map_file_path = Monster_kill_count_get_map_filepath(map_id_str)
        local map_data = g.load_json(map_file_path)
        -- get_items が無い形式のファイルが残っていると next(nil) で落ち、
        -- コンテキストメニューが一切開かなくなる(= 設定ボタンが無反応に見える)ので、
        -- 中身の有無ではなくキーの有無から確認する。
        if not map_data or type(map_data.get_items) ~= "table" or not next(map_data.get_items) then
            local map_cls = GetClassByType("Map", map_id)
            map_data = {
                map_name = map_cls and map_cls.ClassName,
                stay_time = 0,
                kill_count = 0,
                get_items = {}
            }
            g.save_json(map_file_path, map_data)
        else
            local display_text = map_id .. " " .. GetClassByType("Map", map_id).Name
            ui.AddContextMenuItem(context, display_text, string.format("Monster_kill_count_map_information(%d)", map_id))
        end
    end
    ui.OpenContextMenu(context)
end

function Monster_kill_count_map_information_close(map_info)
    if map_info then
        ui.DestroyFrame(map_info:GetName())
    end
end

function Monster_kill_count_map_information(map_id)
    local map_file_path = Monster_kill_count_get_map_filepath(map_id)
    local map_data = g.load_json(map_file_path)
    local frame_name = addon_name_lower .. "mkc_map_info"
    local map_info = ui.CreateNewFrame("notice_on_pc", frame_name, 0, 0, 0, 0)
    AUTO_CAST(map_info)
    map_info:SetPos(1000, 30)
    map_info:SetSkinName("test_frame_low")
    local close_btn = map_info:CreateOrGetControl("button", "close_button", 0, 0, 30, 30)
    AUTO_CAST(close_btn)
    close_btn:SetImage("testclose_button")
    close_btn:SetGravity(ui.RIGHT, ui.TOP)
    close_btn:SetEventScript(ui.LBUTTONUP, "Monster_kill_count_map_information_close")
    local map_name_label = map_info:CreateOrGetControl("richtext", "map_name_text", 20, 10, 50, 20)
    AUTO_CAST(map_name_label)
    map_name_label:SetText("{ol}" .. GetClassByType("Map", map_id).Name)
    local info_box = map_info:CreateOrGetControl("groupbox", "info_gbox", 10, 40, 0, 0)
    AUTO_CAST(info_box)
    info_box:RemoveAllChild()
    info_box:SetSkinName("bg")
    local total_sec = (map_data.stay_time or 0) / 1000
    local h = math.floor(total_sec / 3600)
    local m = math.floor((total_sec % 3600) / 60)
    local s = math.floor(total_sec % 60)
    local kill_count_val = map_data.kill_count or 0
    local stay_label = info_box:CreateOrGetControl("richtext", "stay_time", 10, 10, 50, 20)
    AUTO_CAST(stay_label)
    stay_label:SetText(string.format("{ol}%s : %02d:%02d:%02d", g.lang == "Japanese" and "滞在時間" or "Stay Time",
        h, m, s))
    local kill_label = info_box:CreateOrGetControl("richtext", "kill_count", 10, 35, 50, 20)
    AUTO_CAST(kill_label)
    kill_label:SetText(
        string.format("{ol}%s : %d", g.lang == "Japanese" and "討伐数" or "Kill Count", kill_count_val))
    local kill_per_hour_label = info_box:CreateOrGetControl("richtext", "kill_count_hour", kill_label:GetWidth() + 20,
        35, 50, 20)
    AUTO_CAST(kill_per_hour_label)
    if total_sec > 0 then
        local kills_ph_val = math.floor(kill_count_val / total_sec * 3600)
        kill_per_hour_label:SetText(string.format("{ol}(%s %d %s)", total_sec >= 3600 and "実績" or "予測",
            kills_ph_val, "体/時"))
    else
        kill_per_hour_label:SetText("{ol}(N/A)")
    end
    local item_keys = {}
    local total_item_num = 0
    if map_data.get_items then
        for item_id_str, count_val in pairs(map_data.get_items) do
            table.insert(item_keys, tonumber(item_id_str))
            total_item_num = total_item_num + count_val
        end
    end
    table.sort(item_keys)
    local total_items_label = info_box:CreateOrGetControl("richtext", "total_items_text", 10, 60, 50, 20)
    AUTO_CAST(total_items_label)
    total_items_label:SetText(string.format("{ol}%s : %d",
        g.lang == "Japanese" and "総獲得アイテム数" or "Total Items", total_item_num))
    local current_y = 0
    local max_x = 0
    for _, item_id_num in ipairs(item_keys) do
        local item_id_str_key = tostring(item_id_num)
        local item_cls = GetClassByType("Item", item_id_num)
        if item_cls and map_data.get_items[item_id_str_key] then
            local item_get_count = map_data.get_items[item_id_str_key]
            local item_disp_str1 = string.format("{ol}{img %s 24 24}  %s : %d %s", item_cls.Icon, item_cls.Name,
                item_get_count, g.lang == "Japanese" and "個" or "pcs")
            local item_label1 = info_box:CreateOrGetControl("richtext", "display_text" .. item_id_str_key, 10,
                95 + current_y, 50, 20)
            AUTO_CAST(item_label1)
            item_label1:SetText(item_disp_str1)
            max_x = math.max(max_x, item_label1:GetWidth() + 10)
            local kc_percent = kill_count_val > 0 and item_get_count / kill_count_val * 100 or 0
            local ti_percent = total_item_num > 0 and item_get_count / total_item_num * 100 or 0
            local sec_per_item = item_get_count > 0 and total_sec / item_get_count or 0
            local item_disp_str2 = string.format("        %.1f%% (%s)   %.1f%% (%s)   %.1f %s", kc_percent, "対討伐",
                ti_percent, "対総数", sec_per_item, "秒/個")
            local item_label2 = info_box:CreateOrGetControl("richtext", "display_text2" .. item_id_str_key, 10,
                120 + current_y, 50, 20)
            AUTO_CAST(item_label2)
            item_label2:SetText("{ol}" .. item_disp_str2)
            max_x = math.max(max_x, item_label2:GetWidth() + 10)
            current_y = current_y + 55
        end
    end
    local reset_btn = map_info:CreateOrGetControl("button", "reset_button", map_name_label:GetWidth() + 30, 5, 80, 30)
    AUTO_CAST(reset_btn)
    reset_btn:SetSkinName("test_red_button")
    reset_btn:SetText("{ol}Map Reset")
    reset_btn:SetEventScript(ui.LBUTTONUP, "Monster_kill_count_map_reset_reserve")
    reset_btn:SetEventScriptArgNumber(ui.LBUTTONUP, map_id)
    map_info:Resize(math.max(max_x + 40, 250), math.min(160 + current_y, 1000))
    info_box:Resize(map_info:GetWidth() - 20, map_info:GetHeight() - 55)
    map_info:SetLayerLevel(999)
    map_info:ShowWindow(1)
end

function Monster_kill_count_map_reset_reserve(frame, ctrl, str, map_id)
    ui.MsgBox("Map Reset?", string.format("Monster_kill_count_map_reset(%d)", map_id), "None")
end

function Monster_kill_count_map_reset(map_id)
    local map_file_path = Monster_kill_count_get_map_filepath(map_id)
    os.remove(map_file_path)
    local map_info = ui.GetFrame(addon_name_lower .. "mkc_map_info")
    Monster_kill_count_map_information_close(map_info)
end
-- monster_kill_count ここまで

