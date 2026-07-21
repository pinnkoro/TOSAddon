--  Guild Event Warp ここから
function Guild_event_warp_save_settings()
    g.save_json(g.guild_event_warp_path, g.guild_event_warp_settings)
end

function Guild_event_warp_load_settings()
    g.guild_event_warp_path = string.format("../addons/%s/%s/guild_event_warp.json", addon_name_lower, g.active_id)
    local changed = false
    local settings = g.load_json(g.guild_event_warp_path)
    if not settings then
        settings = {
            open = true
        }
        changed = true
    end
    g.guild_event_warp_settings = settings
    if changed then
        Guild_event_warp_save_settings()
    end
end

function guild_event_warp_on_init()
    if not g.guild_event_warp_settings then
        Guild_event_warp_load_settings()
    end
    local old_func = g.settings.guild_event_warp.old_init_func
    if _G[old_func] then
        return
    end
    if g.settings.guild_event_warp.use == 0 then
        ui.DestroyFrame(addon_name_lower .. "guild_event_warp")
        return
    end
    Guild_event_warp_frame_init()
    if g.guild_event_warp_channnel_change then
        Guild_event_warp_channel_change()
    end
end

function Guild_event_warp_frame_init()
    g.guild_event_warp_info = {{
        name = "dragoon",
        event_id = 500,
        monster = "guild_boss_dragoon_ex",
        tooltip = g.lang == "Japanese" and "{ol}ギルドイベント、ドラグーンのマップに移動します" or
            "{ol}Guild event move to the Dragoon map"
    }, {
        name = "veliora",
        monster = "boss_Veliora_GMission",
        event_id = 501,
        tooltip = g.lang == "Japanese" and
            "{ol}ギルドイベント、アラクネ姉妹のマップに移動します" or
            "{ol}Guild event move to the Arachne Sisters map"
    }, {
        name = "baubas",
        monster = "GuildEvent_npc_baubas2",
        event_id = 502,
        tooltip = g.lang == "Japanese" and "{ol}ギルドイベント、バウバスのマップに移動します" or
            "{ol}Guild event move to the Baubus map"
    }}
    local guild_event_warp = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "guild_event_warp", 0, 0, 0, 0)
    AUTO_CAST(guild_event_warp)
    guild_event_warp:SetSkinName("None")
    guild_event_warp:SetTitleBarSkin("None")
    guild_event_warp:SetGravity(ui.RIGHT, ui.TOP)
    local rect = guild_event_warp:GetMargin()
    guild_event_warp:SetMargin(rect.left - rect.left, rect.top - rect.top + 4, rect.right, rect.bottom)
    local icon_size = 28
    local icon_space = 33
    local x = 0
    for _, info in ipairs(g.guild_event_warp_info) do
        local slot_name = info.name .. "_slot"
        local slot = guild_event_warp:CreateOrGetControl("slot", slot_name, x, 0, icon_size, icon_size)
        AUTO_CAST(slot)
        slot:EnablePop(0)
        slot:EnableDrop(0)
        slot:EnableDrag(0)
        slot:SetEventScript(ui.LBUTTONUP, "Guild_event_warp_move_to_guild_event")
        slot:SetEventScriptArgString(ui.LBUTTONUP, tostring(info.event_id))
        local mon_cls = GetClass("Monster", info.monster)
        if mon_cls then
            local icon = CreateIcon(slot)
            AUTO_CAST(icon)
            icon:SetImage(mon_cls.Icon)
            icon:SetTextTooltip(info.tooltip)
        end
        if g.guild_event_warp_settings.open == true then
            slot:ShowWindow(1)
        else
            slot:ShowWindow(0)
        end
        x = x + icon_space
    end
    local open = guild_event_warp:CreateOrGetControl('picture', "open", x, 0, 20, 20)
    AUTO_CAST(open)
    if g.guild_event_warp_settings.open == true then
        open:SetImage("quest_arrow_r_btn")
    else
        open:SetImage("quest_arrow_l_btn")
    end
    open:SetEnableStretch(1)
    open:SetEventScript(ui.LBUTTONUP, "Guild_event_warp_toggle_frame")
    x = x + icon_space
    guild_event_warp:Resize(x - (icon_space - icon_size), icon_size)
    guild_event_warp:ShowWindow(1)
end

function Guild_event_warp_toggle_frame(frame, ctrl, str, num)
    local show_window
    local new_image_name
    local new_open_state
    if g.guild_event_warp_settings.open == true then
        show_window = 0
        new_image_name = "quest_arrow_l_btn"
        new_open_state = false
    else
        show_window = 1
        new_image_name = "quest_arrow_r_btn"
        new_open_state = true
    end
    for _, info in ipairs(g.guild_event_warp_info) do
        local slot_name = info.name .. "_slot"
        local slot = GET_CHILD(frame, slot_name)
        AUTO_CAST(slot)
        slot:ShowWindow(show_window)
    end
    ctrl:SetImage(new_image_name)
    g.guild_event_warp_settings.open = new_open_state
    Guild_event_warp_save_settings()
end

-- guild_activity_ui の EXEC_GUILD_ACTIVITY_DETAIL_BLOCKADE_RANK_MOVE と同じ
-- 移動可否チェック。マッチングダンジョン/PVP/レイヤー変更中/ダンジョン/レイド地域
-- では移動不可(不可なら ThisLocalUseNot を表示して false を返す)。
function g.guild_event_warp_can_move()
    -- グローバル pc(pc.ReqExecuteTx… 等)を隠さないよう別名で受ける。
    local my_pc = GetMyPCObject()
    if session.world.IsIntegrateServer() == true or IsPVPField(my_pc) == 1 or IsPVPServer(my_pc) == 1 then
        ui.SysMsg(ScpArgMsg("ThisLocalUseNot"))
        return false
    end
    if world.GetLayer() ~= 0 then
        ui.SysMsg(ScpArgMsg("ThisLocalUseNot"))
        return false
    end
    if g.get_map_type() == "Dungeon" then
        ui.SysMsg(ScpArgMsg("ThisLocalUseNot"))
        return false
    end
    local cur_map = GetClass("Map", session.GetMapName())
    if cur_map then
        local zone_keyword = TryGetProp(cur_map, "Keyword", "None")
        local keyword_table = StringSplit(zone_keyword, "")
        if table.find(keyword_table, "IsRaidField") > 0 or table.find(keyword_table, "WeeklyBossMap") > 0 then
            ui.SysMsg(ScpArgMsg("ThisLocalUseNot"))
            return false
        end
    end
    return true
end

function Guild_event_warp_move_to_guild_event(_, _, event_id)
    -- 旧クライアントの _BORUTA_ZONE_MOVE_CLICK は削除されたため、
    -- guild_activity_ui の封鎖線ランキング「移動」ボタンと同じ処理に置き換え。
    -- (event_id 500/501/502 = 封鎖線タブ 0/1/2 のイベントタイプ)
    local event_type = tonumber(event_id)
    if event_type == nil then
        return
    end
    -- guild_activity_ui の移動ボタンと同じ移動可否チェックを行う
    if not g.guild_event_warp_can_move() then
        return
    end
    g.guild_event_warp_channnel_change = true
    control.CustomCommand("MOVE_TO_ENTER_NPC", event_type, 1, 0)
end

function Guild_event_warp_channel_change()
    if g.current_channel ~= 0 then
        RUN_GAMEEXIT_TIMER("Channel", 0)
    end
    g.guild_event_warp_channnel_change = false
end
--  Guild Event Warp ここまで

