-- Boss Direction ここから
function Boss_direction_save_settings()
    g.save_json(g.boss_direction_path, g.boss_direction_settings)
end

function Boss_direction_load_settings()
    g.boss_direction_path = string.format("../addons/%s/%s/boss_direction.json", addon_name_lower, g.active_id)
    local changed = false
    local settings = g.load_json(g.boss_direction_path)
    if not settings then
        settings = {
            layer = 29
        }
        changed = true
    end
    g.boss_direction_settings = settings
    if changed then
        Boss_direction_save_settings()
    end
end

function boss_direction_on_init()
    if not g.boss_direction_settings then
        Boss_direction_load_settings()
    end
    local old_func = g.settings.boss_direction.old_init_func
    if _G[old_func] then
        return
    end
    g.boss_direction_handls = {}
    if g.get_map_type() ~= "City" then
        Boss_direction_handle_check_reserve()
    end
end

function Boss_direction_settings_frame_init()
    local boss_direction_settings = ui.CreateNewFrame("chat_memberlist", addon_name_lower .. "boss_direction_settings")
    AUTO_CAST(boss_direction_settings)
    local list_frame = ui.GetFrame(addon_name_lower .. "list_frame")
    boss_direction_settings:SetPos(list_frame:GetX() + list_frame:GetWidth(), list_frame:GetY())
    boss_direction_settings:EnableHitTest(1)
    boss_direction_settings:SetLayerLevel(999)
    boss_direction_settings:SetSkinName("test_frame_low")
    local width = 0
    local title = boss_direction_settings:CreateOrGetControl('richtext', 'title', 20, 10, 10, 30)
    AUTO_CAST(title)
    title:SetText("{#000000}{s20}Boss Direction Settings")
    width = width + 20 + title:GetWidth() + 40
    local close = boss_direction_settings:CreateOrGetControl('button', 'close', 0, 0, 20, 20)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Boss_direction_setting_frame_close")
    local boss_direction_gb = boss_direction_settings:CreateOrGetControl("groupbox", "boss_direction_gb", 10, 40, 100,
        100)
    AUTO_CAST(boss_direction_gb)
    boss_direction_gb:SetSkinName("bg")
    boss_direction_gb:RemoveAllChild()
    local layer = boss_direction_gb:CreateOrGetControl('richtext', 'layer', 10, 10)
    AUTO_CAST(layer)
    layer:SetText(g.lang ~= "Japanese" and "{ol}フレームレイヤー設定" or "{ol}Frame Layer Settings")
    local layer_edit = boss_direction_gb:CreateOrGetControl('edit', 'layer_edit', layer:GetWidth() + 20, 5, 60, 30)
    AUTO_CAST(layer_edit)
    layer_edit:SetText("{ol}" .. g.boss_direction_settings.layer)
    layer_edit:SetFontName("white_16_ol")
    layer_edit:SetTextAlign("center", "center")
    layer_edit:SetNumberMode(1)
    layer_edit:SetEventScript(ui.ENTERKEY, "Boss_direction_setting")
    layer_edit:SetTextTooltip(g.lang == "Japanese" and "{ol}エンターキー押下で登録" or
                                  "{ol}Register by pressing enter key")
    boss_direction_settings:Resize(width, 90)
    boss_direction_gb:Resize(boss_direction_settings:GetWidth() - 20, 40)
    boss_direction_settings:ShowWindow(1)
end

function Boss_direction_setting_frame_close(frame)
    local frame_name = addon_name_lower .. "boss_direction_settings"
    ui.DestroyFrame(frame_name)
end

function Boss_direction_setting(frame, ctrl)
    local ctrl_name = ctrl:GetName()
    local layer = tonumber(ctrl:GetText())
    if not layer then
        return
    end
    if tonumber(layer) ~= tonumber(g.boss_direction_settings.layer) then
        ui.SysMsg(g.lang == "Japanese" and "フレームレイヤーを " .. layer .. " に設定しました" or
                      "Frame Layer set to " .. layer)
        g.boss_direction_settings.layer = layer
    end
    Boss_direction_save_settings()
end

function Boss_direction_handle_check_reserve()
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    if _nexus_addons_p then
        _nexus_addons_p:SetVisible(1)
        local boss_direction_timer = GET_CHILD(_nexus_addons_p, "boss_direction_timer")
        if not boss_direction_timer then
            boss_direction_timer = _nexus_addons_p:CreateOrGetControl("timer", "boss_direction_timer", 0, 0)
        end
        AUTO_CAST(boss_direction_timer)
        boss_direction_timer:SetUpdateScript("Boss_direction_handle_check")
        boss_direction_timer:Start(0.5)
    end
end

function Boss_direction_handle_check(_nexus_addons_p, Boss_direction_timer)
    if g.settings.boss_direction.use == 0 then
        Boss_direction_timer:Stop()
        return
    end
    local visible_bosses = {}
    local selected_objects, selected_objects_count = SelectObject(GetMyPCObject(), 500, "ENEMY")
    for i = 1, selected_objects_count do
        local handle = GetHandle(selected_objects[i])
        local target_info = info.GetTargetInfo(handle)
        if target_info.isBoss == 1 then
            local cls_name = info.GetMonsterClassName(handle)
            local mon_cls = GetClass("Monster", cls_name)
            local icon_name = mon_cls.Icon
            if icon_name ~= "icon_item_nothing" then
                visible_bosses[handle] = true
                local frame = ui.GetFrame("boss_direction" .. "_" .. handle)
                if not frame then
                    frame = ui.CreateNewFrame("notice_on_pc", "boss_direction_" .. handle, 0, 0, 0, 0)
                    frame:SetSkinName("None")
                    frame:SetTitleBarSkin("None")
                    frame:Resize(120, 120)
                    frame:SetLayerLevel(g.boss_direction_settings.layer or 29)
                    local arrow = frame:CreateOrGetControl("picture", "arrow", 0, 0, 70, 70)
                    AUTO_CAST(arrow)
                    arrow:SetImage("class_tree_arrow")
                    arrow:SetEnableStretch(1)
                    arrow:EnableHitTest(0)
                    arrow:SetGravity(ui.CENTER_HORZ, ui.CENTER_VERT)
                    arrow:Resize(60, 60)
                    arrow:SetColorTone("FFFF0000")
                end
                AUTO_CAST(frame)
                if not g.boss_direction_handls[handle] then
                    g.boss_direction_handls[handle] = frame:GetName()
                end
                local arrow = GET_CHILD(frame, "arrow")
                arrow:SetAngle(info.GetAngle(handle) - 23)
                FRAME_AUTO_POS_TO_OBJ(frame, handle, -frame:GetWidth() / 2, -frame:GetHeight() / 2, 0, 0)
                local stat = target_info.stat
                if stat.HP == 0 then
                    frame:ShowWindow(0)
                else
                    frame:ShowWindow(1)
                end
                if string.find(g.map_name, "Raid_Redania") and not string.find(string.upper(cls_name), "ILLUSION") then
                    arrow:SetColorTone("FFFFFF00")
                end
            end
        end
    end
    for handle, frame_name in pairs(g.boss_direction_handls) do
        if not visible_bosses[handle] then
            ui.DestroyFrame(frame_name)
            g.boss_direction_handls[handle] = nil
        end
    end
end
-- Boss Direction ここまで

