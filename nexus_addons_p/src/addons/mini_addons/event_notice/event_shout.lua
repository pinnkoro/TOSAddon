-- イベントグローバルシャウトをチャットに残す
function Mini_addons_event_NOTICE_ON_MSG(frame, msg, str, num)
    if string.find(str, "StartBlackMarketBetween") then
        return
    end
    local current_time = os.clock()
    if not g.mini_addons_event_notice_time or (current_time - g.mini_addons_event_notice_time < 1800) then
        g.event_maps = g.event_maps or {} -- nilガード
    else
        g.event_maps = {}
    end
    if g.mini_addons_event_notice_time and (current_time - g.mini_addons_event_notice_time < 1.0) then
        if g.mini_addons_event_last_notice_str == str then
            return
        end
    end
    local is_appear = string.find(str, "{name}AppearFieldBoss{map}")
    local is_disappear = string.find(str, "{name}DisappearFieldBoss{map}")
    if not is_appear and not is_disappear then
        return
    end
    g.mini_addons_event_notice_time = current_time
    g.mini_addons_event_last_notice_str = str
    g.event_maps = g.event_maps or {}
    local clean_str = str
    local args_part = str:match("%$%*%$(.*)#%$|#@!")
    args_part = string.gsub(args_part, "%$%*%$|%$#", ":::")
    args_part = string.gsub(args_part, "#%$|%$%*%$", ":::")
    local name, map = "", ""
    if args_part then
        _, name, _, map = args_part:match("^(.-):::(.-):::(.-):::(.*)$")
    end
    local class_name
    local map_list, cnt = GetClassList("Map")
    for i = 0, cnt - 1 do
        local map_cls = GetClassByIndexFromList(map_list, i)
        if map_cls then
            local map_name = map_cls.Name
            if dictionary.ReplaceDicIDInCompStr(map_name) == dictionary.ReplaceDicIDInCompStr(map) then
                class_name = map_cls.ClassName
                break
            end
        end
    end
    name = dictionary.ReplaceDicIDInCompStr(name)
    map = dictionary.ReplaceDicIDInCompStr(map)
    if is_appear then
        table.insert(g.event_maps, {map, class_name, name, os.time()})
    elseif is_disappear then
        for i = #g.event_maps, 1, -1 do
            if g.event_maps[i][2] == class_name then
                table.remove(g.event_maps, i)
                break
            end
        end
    end
    -- **素の韓国語文を ReplaceDicIDInCompStr へ渡しても訳されない。**
    -- あれは compstr 中の dicID を差し替える関数で、dicID を含まない文には効かないため、
    -- 以前は言語を問わず韓国語でチャットに出ていた(Issue #68。バウバスのお知らせと同じ形)。
    -- 名前とマップ名は上で訳してあるので、ここでは文だけ言語で出し分ける。
    if not is_appear and not is_disappear then
        return
    end
    if g.lang == "Japanese" then
        clean_str = is_appear and string.format("[%s]にフィールドボス[%s]が出現しました。", map, name) or
                        string.format("[%s]のフィールドボス[%s]が討伐されました。", map, name)
    elseif g.lang == "kr" then
        clean_str = is_appear and string.format("[%s]에 필드 보스[%s]가 등장하였습니다.", map, name) or
                        string.format("[%s]에 필드 보스[%s]가 처치되었습니다.", map, name)
    else
        clean_str = is_appear and string.format("Field boss [%s] has appeared in [%s].", name, map) or
                        string.format("Field boss [%s] in [%s] has been defeated.", name, map)
    end
    CHAT_SYSTEM(clean_str)
    if g.settings.event_shout.guild_notice == 1 then
        ui.Chat("/g " .. clean_str)
    end
    Mini_addons_event_frame()
end

function Mini_addons_event_frame()
    if not g.event_maps or #g.event_maps == 0 then
        ui.DestroyFrame(addon_name_lower .. "event_frame")
        return
    end
    local event_frame = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "event_frame", 0, 0, 0, 0)
    AUTO_CAST(event_frame)
    event_frame:SetSkinName("None")
    event_frame:RunUpdateScript("Mini_addons_event_check_time", 5.0)
    local gbox = event_frame:CreateOrGetControl("groupbox", "gbox", 0, 0, 0, 0)
    AUTO_CAST(gbox)
    gbox:SetSkinName("bg2")
    gbox:RemoveAllChild()
    local close = gbox:CreateOrGetControl("button", "close", 0, 0, 30, 30)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:EnableHitTest(1)
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Mini_addons_event_frame_close")
    local name_text = gbox:CreateOrGetControl("richtext", "name_text", 20, 5, 10, 20)
    AUTO_CAST(name_text)
    name_text:SetText("{ol}" .. g.event_maps[#g.event_maps][3])
    local x = name_text:GetWidth() + 60
    local y = 30
    for i, data in ipairs(g.event_maps) do
        local icon = gbox:CreateOrGetControl("picture", "icon_" .. i, 10, y, 20, 20)
        AUTO_CAST(icon)
        icon:SetImage("questinfo_return") -- GET_TOKEN_WARP_COOLDOWN() == 0 then
        icon:SetTextTooltip(g.lang == "Japanese" and "{ol}トークンワープ" or "{ol}token warp")
        icon:SetEventScript(ui.LBUTTONUP, "Mini_addons_event_tokenwarp")
        icon:SetEventScriptArgString(ui.LBUTTONUP, data[2])
        icon:EnableHitTest(1)
        icon:SetAngleLoop(-3)
        icon:SetEnableStretch(1)
        local text = gbox:CreateOrGetControl("richtext", "text_" .. i, 35, y, 0, 0)
        AUTO_CAST(text)
        text:SetText("{ol}" .. data[1])
        text:EnableHitTest(0)
        y = y + 25
        local temp_x = 30 + text:GetWidth()
        if x < temp_x then
            x = temp_x
        end
    end
    local slot = gbox:CreateOrGetControl("picture", "slot", 30, y, 30, 30)
    AUTO_CAST(slot)
    local item_cls = GetClassByType('Item', 11202062)
    slot:SetImage(item_cls.Icon)
    slot:EnableHitTest(1)
    slot:SetEnableStretch(1)
    local slot_text = slot:CreateOrGetControl("richtext", "slot_text", 0, 0, 10, 10)
    AUTO_CAST(slot_text)
    slot_text:SetGravity(ui.RIGHT, ui.BOTTOM)
    slot:RunUpdateScript("Mini_addons_event_check_count_change", 0.1)
    slot:SetEventScript(ui.LBUTTONUP, "Mini_addons_event_check_itemuse")
    slot:SetEventScript(ui.RBUTTONUP, "Mini_addons_event_check_itemuse")
    slot_text:SetEventScript(ui.LBUTTONUP, "Mini_addons_event_check_itemuse")
    slot_text:SetEventScript(ui.RBUTTONUP, "Mini_addons_event_check_itemuse")
    slot:SetTextTooltip(g.lang == "Japanese" and "{ol}アイテム使用" or "{ol}Item use")
    y = y + 30
    local screen_width = ui.GetClientInitialWidth()
    event_frame:SetPos(screen_width / 2 + 200, 20)
    event_frame:Resize(x, y + 10)
    gbox:Resize(x, y + 10)
    event_frame:ShowWindow(1)
end

function Mini_addons_event_check_count_change(slot)
    local slot_text = GET_CHILD(slot, "slot_text")
    local inv_item = session.GetInvItemByType(11202062)
    if inv_item then
        slot_text:SetText("{ol}{s10}" .. inv_item.count)
    else
        slot_text:SetText("{ol}{s10}0")
        slot:SetColorTone("FF990000")
    end
    return 0
end

function Mini_addons_event_check_itemuse(frame, ctrl)
    local inv_item_list = session.GetInvItemList()
    local guid_list = inv_item_list:GetGuidList()
    local cnt = guid_list:Count()
    for i = 0, cnt - 1 do
        local guid = guid_list:Get(i)
        local inv_item = inv_item_list:GetItemByGuid(guid)
        local item_obj = GetIES(inv_item:GetObject())
        if item_obj and item_obj.ClassID == 11202062 then
            Mini_addons_event_frame()
            item.UseByGUID(guid)
            break
        end
    end
end

function Mini_addons_event_check_time(frame)
    if not g.event_maps or #g.event_maps == 0 then
        ui.DestroyFrame(addon_name_lower .. "event_frame")
        return 0
    end
    local current_time = os.time()
    local changed = false
    for i = #g.event_maps, 1, -1 do
        local data = g.event_maps[i]
        if data[4] and (current_time - data[4] >= 1800) then
            table.remove(g.event_maps, i)
            changed = true
        end
    end
    if changed then
        Mini_addons_event_frame()
    end
    return 1
end

function Mini_addons_event_tokenwarp(frame, ctrl, class_name)
    if class_name then
        WORLDMAP2_TOKEN_WARP(class_name)
    end
end

function Mini_addons_event_frame_close(frame, ctrl)
    ui.DestroyFrame(addon_name_lower .. "event_frame")
    g.event_maps = {}
end

-- 表示の切り替えだけ行う（理由は Mini_addons_baubas_call_switch と同じ）
function Mini_addons_event_shout_switch(frame, ctrl, str)
    AUTO_CAST(ctrl)
    if g.settings.event_shout.guild_notice == 0 then
        g.settings.event_shout.guild_notice = 1
        ctrl:SetText("{ol}{#FFFFFF}ON")
        ctrl:SetSkinName("test_red_button")
    else
        g.settings.event_shout.guild_notice = 0
        ctrl:SetText("{ol}{#FFFFFF}OFF")
        ctrl:SetSkinName("test_gray_button")
    end
    Mini_addons_save_settings()
end

function Mini_addons_event_NOTICE_ON_MSG_test()
    local appear =
        {"!@#${name}AppearFieldBoss{map}$*$name$*$|$#(10주년) 황금 개복치#$|$*$map$*$|$#제단로#$|#@!",
         "!@#${name}AppearFieldBoss{map}$*$name$*$|$#(10주년) 황금 개복치#$|$*$map$*$|$#마법사의 탑 1층#$|#@!",
         "!@#${name}AppearFieldBoss{map}$*$name$*$|$#(10주년) 황금 개복치#$|$*$map$*$|$#라우키메 저습지#$|#@!",
         "!@#${name}AppearFieldBoss{map}$*$name$*$|$#(10주년) 황금 개복치#$|$*$map$*$|$#왕의 고원#$|#@!",
         "!@#${name}AppearFieldBoss{map}$*$name$*$|$#(10주년) 황금 개복치#$|$*$map$*$|$#미르키티 농장#$|#@!"}
    for _, str in ipairs(appear) do
        Mini_addons_event_NOTICE_ON_MSG(nil, nil, str, nil)
    end
    --[[local disappear =
        {"!@#${name}DisappearFieldBoss{map}$*$name$*$|$#(10주년) 황금 개복치#$|$*$map$*$|$#왕의 고원#$|#@!",
         "!@#${name}DisappearFieldBoss{map}$*$name$*$|$#(10주년) 황금 개복치#$|$*$map$*$|$#마법사의 탑 1층#$|#@!",
         "!@#${name}DisappearFieldBoss{map}$*$name$*$|$#(10주년) 황금 개복치#$|$*$map$*$|$#미르키티 농장#$|#@!",
         "!@#${name}DisappearFieldBoss{map}$*$name$*$|$#(10주년) 황금 개복치#$|$*$map$*$|$#라우키메 저습지#$|#@!",
         "!@#${name}DisappearFieldBoss{map}$*$name$*$|$#(10주년) 황금 개복치#$|$*$map$*$|$#제단로#$|#@!"}
    for _, str in ipairs(disappear) do
        Mini_addons_event_NOTICE_ON_MSG(nil, nil, str, nil)
    end]]
end
-- Mini_addons_event_NOTICE_ON_MSG_test()
