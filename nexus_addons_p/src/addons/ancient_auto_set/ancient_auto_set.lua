-- Ancient Auto Set ここから
function Ancient_auto_set_save_settings()
    g.save_json(g.ancient_auto_set_path, g.ancient_auto_set_settings)
end

function Ancient_auto_set_load_settings()
    g.ancient_auto_set_path = string.format("../addons/%s/%s/ancient_auto_set.json", addon_name_lower, g.active_id)
    g.ancient_auto_set_old_path = string.format("../addons/%s/%s/settings.json", "ancient_autoset", g.active_id)
    local settings = g.load_json(g.ancient_auto_set_path)
    local changed = false
    local ver = 1.1
    if not settings or not settings.ver or settings.ver < ver then
        settings = {
            priset = {},
            ver = ver
        }
        local old_settings = g.load_json(g.ancient_auto_set_old_path)
        if old_settings then
            for key, data in pairs(old_settings) do
                if type(data) == "table" and tonumber(key) and string.len(key) > 10 then
                    local new_char_data = {
                        guids = {},
                        name = ""
                    }
                    for i = 0, 3 do
                        local guid = data[tostring(i)]
                        if guid then
                            table.insert(new_char_data.guids, {guid, "Unknown"})
                        end
                    end
                    settings[key] = new_char_data
                end
            end
            if old_settings.presets then
                local old_names = old_settings.presets_name or {}
                for p_id, p_data in pairs(old_settings.presets) do
                    local p_name = old_names[p_id] or ("Preset " .. p_id)
                    settings.priset[p_id] = {
                        name = p_name
                    }
                    for i = 0, 3 do
                        local guid = p_data[tostring(i)]
                        if guid then
                            settings.priset[p_id][tostring(i)] = guid
                        end
                    end
                end
            end
            changed = true
        end
    end
    if not settings[g.cid] then
        settings[g.cid] = {
            guids = {},
            name = g.login_name or ""
        }
        changed = true
    end
    g.ancient_auto_set_settings = settings
    if changed then
        Ancient_auto_set_save_settings()
    end
end

function ancient_auto_set_on_init()
    if not g.ancient_auto_set_settings then
        Ancient_auto_set_load_settings()
    end
    local old_func = g.settings.ancient_auto_set.old_init_func
    if _G[old_func] then
        return
    end
    if not g.ancient_auto_set_settings[g.cid] then
        g.ancient_auto_set_settings[g.cid] = {
            guids = {},
            name = g.login_name or ""
        }
        Ancient_auto_set_save_settings()
    end
    if g.ancient_auto_set_settings[g.cid].name == "" then
        g.ancient_auto_set_settings[g.cid].name = g.login_name or ""
        Ancient_auto_set_save_settings()
    end
    if g.get_map_type() == "City" then
        Ancient_auto_set_change_set_reserve()
    end
    Ancient_auto_set_frame_init()
    g.setup_hook_and_event(g.addon, "ANCIENT_CARD_LIST_OPEN", "Ancient_auto_set_ANCIENT_CARD_LIST_OPEN", true)
    g.setup_hook_and_event(g.addon, "ANCIENT_CARD_LIST_CLOSE", "Ancient_auto_set_ANCIENT_CARD_LIST_CLOSE", true)
end

function Ancient_auto_set_ANCIENT_CARD_LIST_OPEN()
    if g.settings.ancient_auto_set.use == 0 then
        return
    end
    local ancient_card_list = ui.GetFrame("ancient_card_list")
    local frame_name = addon_name_lower .. "_ancient_auto_set_priset_frame"
    local priset_frame = ui.CreateNewFrame("notice_on_pc", frame_name, 0, 0, 0, 0)
    AUTO_CAST(priset_frame)
    priset_frame:RemoveAllChild()
    priset_frame:SetLayerLevel(92)
    priset_frame:SetSkinName('None')
    priset_frame:SetTitleBarSkin("None")
    priset_frame:SetPos(ancient_card_list:GetX() + 710, ancient_card_list:GetY() + 322)
    priset_frame:Resize(707, 400)
    priset_frame:ShowWindow(1)
    priset_frame:SetAnimation("frameOpenAnim", "chat_balloon_start")
    priset_frame:SetAnimation("frameCloseAnim", "chat_balloon_end")
    local bg = priset_frame:CreateOrGetControl("groupbox", "bg", 705, 360, ui.LEFT, ui.TOP, 0, 40, 0, 0)
    AUTO_CAST(bg)
    bg:SetSkinName("test_frame_low")
    bg:EnableHittestGroupBox(false)
    local title_bg = priset_frame:CreateOrGetControl("groupbox", "title_bg", 705, 61, ui.LEFT, ui.TOP, 0, 0, 0, 0)
    AUTO_CAST(title_bg)
    title_bg:SetSkinName("test_frame_top")
    title_bg:EnableHittestGroupBox(false)
    local title = priset_frame:CreateOrGetControl("richtext", "title", 100, 30, ui.CENTER_HORZ, ui.TOP, 0, 18, 0, 0)
    title:SetText("{@st43}{s22}Assister Preset Setting{/}")
    title:EnableHitTest(false)
    local close = priset_frame:CreateOrGetControl("button", "close", 44, 44, ui.RIGHT, ui.TOP, 0, 20, 17, 0)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    -- close:SetTextTooltip("{ol}Close the Assister Preset window")
    close:SetEventScript(ui.LBUTTONUP, "Ancient_auto_set_ANCIENT_CARD_LIST_CLOSE")
    local topbg = priset_frame:CreateOrGetControl("groupbox", "topbg", 665, 315, ui.LEFT, ui.TOP, 20, 100, 0, 0)
    AUTO_CAST(topbg)
    topbg:EnableHittestGroupBox(false)
    local ancient_card_slot_gbox = topbg:CreateOrGetControl("groupbox", "ancient_card_slot_gbox", 665, 275, ui.LEFT,
        ui.TOP, 0, 0, 0, 0)
    AUTO_CAST(ancient_card_slot_gbox)
    ancient_card_slot_gbox:EnableHittestGroupBox(false)
    ancient_card_slot_gbox:SetSkinName("test_frame_midle")
    local tab = priset_frame:CreateOrGetControl("tab", "tab", 664, 40, ui.LEFT, ui.TOP, 22, 65, 0, 0)
    AUTO_CAST(tab)
    tab:SetEventScript(ui.LBUTTONUP, "Ancient_auto_set_tab_change")
    tab:SetSkinName("tab2")
    for i = 1, 10 do
        tab:AddItem("{@st66b}{s16}Set " .. i, true, "", "", "", "", "", false)
    end
    tab:SetItemsFixWidth(66)
    tab:SetItemsAdjustFontSizeByWidth(66)
    local swap = priset_frame:CreateOrGetControl("button", "swap", 100, 45, ui.RIGHT, ui.TOP, 0, 325, 30, 0)
    swap:SetSkinName("test_pvp_btn")
    swap:SetText("{@st42}{s18}Change")
    swap:SetEventScript(ui.LBUTTONUP, "Ancient_auto_set_card_change")
    local name_edit = priset_frame:CreateOrGetControl("edit", "name_edit", 420, 330, 150, 36)
    AUTO_CAST(name_edit)
    name_edit:SetFontName("white_16_ol")
    name_edit:SetTextAlign("left", "center")
    name_edit:SetSkinName("inventory_serch")
    name_edit:SetTextTooltip(g.lang == "Japanese" and "{ol}セット名入力" or "{ol}Set Name Input")
    name_edit:SetEventScript(ui.ENTERKEY, "Ancient_auto_set_tab_name_save")
    priset_frame:ShowWindow(1)
    Ancient_auto_set_tab_change(priset_frame)
end

function Ancient_auto_set_ANCIENT_CARD_LIST_CLOSE()
    local frame_name = addon_name_lower .. "_ancient_auto_set_priset_frame"
    local priset_frame = ui.GetFrame(frame_name)
    if priset_frame then
        priset_frame:ShowWindow(0)
    end
end

function Ancient_auto_set_tab_change(priset_frame)
    local tab = GET_CHILD(priset_frame, "tab")
    AUTO_CAST(tab)
    local tab_index = tab:GetSelectItemIndex()
    local set_name = priset_frame:CreateOrGetControl("richtext", "set_name", 50, 340, 320, 30)
    AUTO_CAST(set_name)
    set_name:SetFontName("white_18_ol")
    if g.ancient_auto_set_settings.priset and g.ancient_auto_set_settings.priset[tostring(tab_index)] then
        local current_set_name = g.ancient_auto_set_settings.priset[tostring(tab_index)].name
        if current_set_name and current_set_name ~= "" then
            set_name:SetText("{ol}Set Name: " .. current_set_name)
        else
            set_name:SetText("{ol}Set Name:")
        end
    else
        set_name:SetText("{ol}Set Name:")
    end
    Ancient_auto_set_load_slots(priset_frame, tab_index)
end

function Ancient_auto_set_load_slots(priset_frame, tab_index)
    local gbox = GET_CHILD_RECURSIVELY(priset_frame, 'ancient_card_slot_gbox')
    gbox:RemoveAllChild()
    local width = 4
    for index = 0, 3 do
        local ctrlSet = gbox:CreateControlSet("ancient_card_item_slot", "SLOT_" .. index, width, 4)
        width = width + ctrlSet:GetWidth() + 2
        local ancient_card_gbox = GET_CHILD(ctrlSet, "ancient_card_gbox")
        ancient_card_gbox:SetVisible(0)
        ctrlSet:SetUserValue("INDEX", index)
        ctrlSet:EnableHitTest(1)
        local slot = GET_CHILD_RECURSIVELY(ctrlSet, "ancient_card_slot")
        AUTO_CAST(slot)
        local icon = CreateIcon(slot)
        slot:EnableHitTest(1)
        ctrlSet:SetEventScript(ui.DROP, 'Ancient_auto_set_frame_drop')
        ctrlSet:SetEventScript(ui.RBUTTONDOWN, 'Ancient_auto_set_delete_data')
        if index == 0 then
            local gold_border = GET_CHILD_RECURSIVELY(ctrlSet, "gold_border")
            AUTO_CAST(gold_border)
            gold_border:SetImage('monster_card_g_frame_02')
        end
        if g.ancient_auto_set_settings and g.ancient_auto_set_settings.priset and
            g.ancient_auto_set_settings.priset[tostring(tab_index)] then
            local preset_data = g.ancient_auto_set_settings.priset[tostring(tab_index)]
            if preset_data[tostring(index)] then
                local guid = preset_data[tostring(index)]
                if guid then
                    local card = session.ancient.GetAncientCardByGuid(guid)
                    if card then
                        SET_ANCIENT_CARD_SLOT(ctrlSet, card)
                    end
                end
            end
        end
        local default_image = GET_CHILD_RECURSIVELY(ctrlSet, "default_image")
        AUTO_CAST(default_image)
        default_image:SetImage("socket_slot_bg")
    end
end

function Ancient_auto_set_card_change(priset_frame, ctrl)
    if IS_ANCIENT_ENABLE_MAP() == "YES" then
        imcAddOn.BroadMsg("NOTICE_Dm_!", ClMsg("ImpossibleInCurrentMap"), 3)
        return
    end
    local tab = GET_CHILD(priset_frame, "tab")
    AUTO_CAST(tab)
    local tab_index = tab:GetSelectItemIndex()
    if not g.ancient_auto_set_settings.priset[tostring(tab_index)] then
        return
    end
    priset_frame:SetUserValue("TAB_INDEX", tab_index)
    priset_frame:SetUserValue("SLOT_INDEX", 0)
    priset_frame:RunUpdateScript("Ancient_auto_set_put_card_slot", 0.3)
end

function Ancient_auto_set_put_card_slot(priset_frame)
    local tab_index = priset_frame:GetUserIValue("TAB_INDEX")
    local slot_index = priset_frame:GetUserIValue("SLOT_INDEX")
    local target_guid = g.ancient_auto_set_settings.priset[tostring(tab_index)][tostring(slot_index)]
    if slot_index <= 3 then
        if target_guid then
            local card = session.ancient.GetAncientCardBySlot(g.slot_index)
            if card then
                local guid = card:GetGuid()
                if target_guid ~= guid then
                    ReqSwapAncientCard(target_guid, slot_index)
                    imcSound.PlaySoundEvent("sys_card_battle_rival_slot_show")
                end
            else
                ReqSwapAncientCard(target_guid, slot_index)
                imcSound.PlaySoundEvent("sys_card_battle_rival_slot_show")
            end
        end
        priset_frame:SetUserValue("SLOT_INDEX", slot_index + 1)
        return 1
    end
    priset_frame:SetUserValue("TAB_INDEX", "None")
    priset_frame:SetUserValue("SLOT_INDEX", "None")
    return 0
end

function Ancient_auto_set_tab_name_save(priset_frame, ctrl)
    local set_name = ctrl:GetText()
    local tab = GET_CHILD(priset_frame, "tab")
    AUTO_CAST(tab)
    local tab_index = tab:GetSelectItemIndex()
    if not g.ancient_auto_set_settings.priset then
        g.ancient_auto_set_settings.priset = {}
    end
    g.ancient_auto_set_settings.priset[tostring(tab_index)].name = set_name
    Ancient_auto_set_save_settings()
    priset_frame:RunUpdateScript("Ancient_auto_set_ANCIENT_CARD_LIST_OPEN", 0.1)
end

function Ancient_auto_set_frame_drop(parent, ctrl, str, num)
    local to_index = ctrl:GetUserIValue("INDEX")
    local ancient_card_list = ui.GetFrame("ancient_card_list")
    local priset_frame = parent:GetTopParentFrame()
    local tab = GET_CHILD(priset_frame, "tab")
    AUTO_CAST(tab)
    local tab_index = tab:GetSelectItemIndex()
    if not g.ancient_auto_set_settings.priset then
        g.ancient_auto_set_settings.priset = {}
    end
    if not g.ancient_auto_set_settings.priset[tostring(tab_index)] then
        g.ancient_auto_set_settings.priset[tostring(tab_index)] = {}
    end
    local lifted_guid = ancient_card_list:GetUserValue("LIFTED_GUID")
    g.ancient_auto_set_settings.priset[tostring(tab_index)][tostring(to_index)] = lifted_guid
    Ancient_auto_set_save_settings()
    Ancient_auto_set_tab_change(priset_frame)
    ancient_card_list:SetUserValue("LIFTED_GUID", "None")
end

function Ancient_auto_set_delete_data(parent, ctrl, str, num)
    local to_index = ctrl:GetUserIValue("INDEX")
    local priset_frame = parent:GetTopParentFrame()
    local tab = GET_CHILD(frame, "tab")
    AUTO_CAST(tab)
    local tab_index = tab:GetSelectItemIndex()
    if not (g.ancient_auto_set_settings.priset and g.ancient_auto_set_settings.priset[tostring(tab_index)]) then
        return
    end
    g.ancient_auto_set_settings.priset[tostring(tab_index)][tostring(to_index)] = "None"
    Ancient_auto_set_save_settings()
    Ancient_auto_set_tab_change(priset_frame)
end

function Ancient_auto_set_frame_init()
    local ancient_card_list = ui.GetFrame("ancient_card_list")
    local topbg = GET_CHILD_RECURSIVELY(ancient_card_list, "topbg")
    if g.settings.ancient_auto_set.use == 0 then
        local btn_aas = GET_CHILD(topbg, "btn_aas")
        if btn_aas then
            DESTROY_CHILD_BYNAME(topbg, "btn_aas")
        end
        return
    end
    local btn_aas = topbg:CreateOrGetControl("button", "btn_aas", 465, 285, 30, 30)
    AUTO_CAST(btn_aas)
    btn_aas:SetSkinName("None")
    btn_aas:SetImage("config_button_normal")
    btn_aas:Resize(30, 30)
    btn_aas:SetEventScript(ui.LBUTTONUP, "Ancient_auto_set_reg")
    btn_aas:SetEventScript(ui.RBUTTONUP, "Ancient_auto_set_release")
    btn_aas:SetTextTooltip(g.lang == "Japanese" and
                               "{ol}[AAS]{nl}左クリック: 登録{nl}右クリック: 登録解除" or
                               "{ol}[AAS]{nl}Left-click: Setting Register{nl}Right-click: Setting Release")
end

function Ancient_auto_set_release(frame, ctrl)
    local ancient_card_list = ui.GetFrame("ancient_card_list")
    local tab = ancient_card_list:GetChild("tab")
    AUTO_CAST(tab)
    tab:SelectTab(0)
    if not g.ancient_auto_set_settings[g.cid] then
        g.ancient_auto_set_settings[g.cid] = {}
        Ancient_auto_set_save_settings()
    end
    g.ancient_auto_set_settings[g.cid].guids = {}
    local msg = g.lang == "Japanese" and "[AAS]登録解除しました" or "[AAS]Setting released"
    ui.SysMsg(msg)
    Ancient_auto_set_save_settings()
end

function Ancient_auto_set_reg(frame, ctrl)
    local ancient_card_list = ui.GetFrame("ancient_card_list")
    local tab = ancient_card_list:GetChild("tab")
    AUTO_CAST(tab)
    tab:SelectTab(0)
    g.ancient_auto_set_settings[g.cid] = {
        name = g.login_name,
        guids = {}
    }
    for index = 0, 3 do
        local card = session.ancient.GetAncientCardBySlot(index)
        if card then
            local guid = card:GetGuid()
            table.insert(g.ancient_auto_set_settings[g.cid].guids, {guid, card:GetClassName()})
        end
    end
    local msg = g.lang == "Japanese" and "[AAS]登録しました" or "[AAS]Setting Registered"
    ui.SysMsg(msg)
    Ancient_auto_set_save_settings()
end

function Ancient_auto_set_change_set_reserve()
    if g.settings.ancient_auto_set.use == 0 then
        return
    end
    if not (g.ancient_auto_set_settings[g.cid] and g.ancient_auto_set_settings[g.cid].guids and
        next(g.ancient_auto_set_settings[g.cid].guids)) then
        local text = g.lang == "Japanese" and "{ol}[AAS]{#FFFFFF} " .. g.login_name .. " {/}アシスター未登録" or
                         "{ol}[APS]{#FFFFFF} " .. g.login_name .. " {/}is not registered assister"
        ui.SysMsg(text)
        return
    end
    local changed = false
    local guids = g.ancient_auto_set_settings[g.cid].guids
    for i, row_data in ipairs(guids) do
        if row_data[2] == "Unknown" then
            local target_guid = row_data[1]
            local new_name = nil
            local card = session.ancient.GetAncientCardBySlot(i - 1)
            if card and card:GetGuid() == target_guid then
                new_name = card:GetClassName()
            end
            if new_name then
                row_data[2] = new_name
                changed = true
            end
        end
    end
    if changed then
        Ancient_auto_set_save_settings()
    end
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    local ancient_auto_set_timer = _nexus_addons_p:CreateOrGetControl("timer", "ancient_auto_set_timer", 0, 0)
    AUTO_CAST(ancient_auto_set_timer)
    ancient_auto_set_timer:Stop()
    local needs_change = false
    for i, row_data in ipairs(g.ancient_auto_set_settings[g.cid].guids) do
        local save_guid = row_data[1]
        local card = session.ancient.GetAncientCardBySlot(i - 1)
        local current_guid = card and card:GetGuid() or nil
        if save_guid ~= current_guid then
            needs_change = true
            break
        end
    end
    if needs_change then
        _nexus_addons_p:SetUserValue("ANCIENT_INDEX", 0)
        ancient_auto_set_timer:SetUpdateScript("Ancient_auto_set_change_set")
        ancient_auto_set_timer:Start(0.3)
    end
end

function Ancient_auto_set_change_set(_nexus_addons_p, ancient_auto_set_timer)
    local index = _nexus_addons_p:GetUserIValue("ANCIENT_INDEX")
    if index <= 3 then
        local card_guid = g.ancient_auto_set_settings[g.cid].guids[index + 1][1]
        if card_guid then
            local card = session.ancient.GetAncientCardBySlot(index)
            local current_guid = card and card:GetGuid() or nil
            if card_guid ~= current_guid then
                ReqSwapAncientCard(card_guid, index)
            end
        end
        _nexus_addons_p:SetUserValue("ANCIENT_INDEX", index + 1)
        return 1
    end
    return 0
end
-- Ancient Auto Set ここまで

