-- other_character_skill_list ここから
function Other_character_skill_list_save_settings()
    g.save_lua(g.ocsl_path, g.ocsl_settings)
end

function Other_character_skill_list_load_settings()
    g.ocsl_path = string.format("../addons/%s/%s/other_character_skill_list.lua", addon_name_lower, g.active_id)
    local json_path = string.format("../addons/%s/%s/other_character_skill_list.json", addon_name_lower, g.active_id)
    local settings = g.load_lua(g.ocsl_path)
    local need_save = false
    local ver = 1.1
    if not settings then
        settings = g.load_json(json_path)
        if settings then
            need_save = true
        end
    end
    if not settings then
        settings = {
            chars = {},
            ver = ver
        }
        need_save = true
    end
    if not settings.ver or settings.ver < ver then
        if settings.chars then
            for char_name, char_data in pairs(settings.chars) do
                if char_data.equips and char_data.equips.EARRING then
                    local earring = char_data.equips.EARRING
                    if earring.lv and type(earring.lv) == "string" then
                        earring.lv = nil
                    end
                end
            end
        end
        settings.ver = ver
        need_save = true
    end
    if not settings.hide then
        settings.hide = 0
        need_save = true
    end
    g.ocsl_settings = settings
    if need_save then
        Other_character_skill_list_save_settings()
    end
end

function Other_character_skill_list_char_load_settings()
    local acc_info = session.barrack.GetMyAccount()
    if acc_info then
        -- 現在選択中のバラックレイヤーのキャラを登録/更新する。GetPCByIndexで
        -- 列挙できるのは現レイヤーのみ。
        local layer_pc_count = acc_info:GetPCCount()
        for order = 0, layer_pc_count - 1 do
            local pc_info = acc_info:GetPCByIndex(order)
            if pc_info then
                local pc_apc = pc_info:GetApc()
                if pc_apc then
                    local pc_name = pc_apc:GetName()
                    local char_data = g.ocsl_settings.chars[pc_name] or {}
                    char_data.name = pc_name
                    char_data.cid = char_data.cid or pc_info:GetCID()
                    char_data.layer = g.ocsl_layer or char_data.layer or 9
                    char_data.order = order
                    char_data.hide = char_data.hide or 0
                    char_data.equips = char_data.equips or {}
                    char_data.gear_score = char_data.gear_score or 0
                    g.ocsl_settings.chars[pc_name] = char_data
                end
            end
        end
        -- 実際にアカウントから消えたキャラのみを除去する。バラック名簿
        -- (GetBarrackPCByIndex)は全キャラの正となる一覧だが、ゲーム起動直後は
        -- 空なので count > 0 でガードし、名簿ロード前にリストを消さない。
        -- InstantCC(Instant_cc_save_char_data)と同じ安全パターン。
        local barrack_all = acc_info:GetBarrackPCCount()
        if barrack_all > 0 then
            local barrack_chars = {}
            for i = 0, barrack_all - 1 do
                local pc_info = acc_info:GetBarrackPCByIndex(i)
                if pc_info then
                    barrack_chars[pc_info:GetName()] = true
                end
            end
            local chars_to_delete = {}
            for char_name, _ in pairs(g.ocsl_settings.chars) do
                if not barrack_chars[char_name] then
                    table.insert(chars_to_delete, char_name)
                end
            end
            for _, char_name in ipairs(chars_to_delete) do
                g.ocsl_settings.chars[char_name] = nil
            end
        end
    end
    -- バラックデータがまだ無くても、ログイン中キャラは必ず存在させる(prune後に
    -- 残るよう最後に追加。名簿未反映の新規作成キャラ対策)。
    local my_handle = session.GetMyHandle()
    if my_handle then
        local my_name = info.GetName(my_handle)
        local char_data = g.ocsl_settings.chars[my_name] or {}
        char_data.name = my_name
        char_data.cid = char_data.cid or info.GetCID(my_handle)
        char_data.layer = char_data.layer or g.ocsl_layer or 1
        char_data.order = char_data.order or 0
        char_data.hide = char_data.hide or 0
        char_data.equips = char_data.equips or {}
        char_data.gear_score = char_data.gear_score or 0
        g.ocsl_settings.chars[my_name] = char_data
    end
    Other_character_skill_list_save_settings()
end

function other_character_skill_list_on_init()
    local old_func = g.settings.other_character_skill_list.old_init_func
    if _G[old_func] then
        return
    end
    if _G["BARRACK_CHARLIST_ON_INIT"] and _G["current_layer"] then
        g.ocsl_layer = _G["current_layer"]
    end
    if g.settings.other_character_skill_list.use == 0 then
        if _G["other_character_skill_list_frame_open"] == _G["Other_character_skill_list_frame_open"] then
            _G["other_character_skill_list_frame_open"] = nil
        end
    else
        if type(_G["Other_character_skill_list_frame_open"]) == "function" then
            if type(_G["other_character_skill_list_frame_open"]) ~= "function" then
                _G["other_character_skill_list_frame_open"] = _G["Other_character_skill_list_frame_open"]
            end
        end
    end
    if not g.ocsl_settings then
        Other_character_skill_list_load_settings()
    end
    if g.get_map_type() == "City" then
        Other_character_skill_list_char_load_settings()
        Other_character_skill_list_sort()
    end
    g.setup_hook_and_event(g.addon, "INVENTORY_OPEN", "Other_character_skill_list_save_enchant", true)
    g.setup_hook_and_event(g.addon, "INVENTORY_CLOSE", "Other_character_skill_list_save_enchant", true)
    -- ESC は core 側でまとめて受ける(ここで購読すると他のウィンドウも一緒に閉じる)
end

function Other_character_skill_list_save_enchant()
    if g.get_map_type() ~= "City" then
        return
    end
    local current_time = os.time()
    if g.ocsl_last_save_time and current_time - g.ocsl_last_save_time < 0.5 then
        return
    end
    g.ocsl_last_save_time = current_time
    local inventory = ui.GetFrame("inventory")
    local inventory_btns = {"moncard_btn", "helper_btn", "cabinet_btn", "goddess_mgr_btn"}
    if inventory then
        for _, btn_name in ipairs(inventory_btns) do
            local btn = GET_CHILD_RECURSIVELY(inventory, btn_name)
            if btn and btn:IsVisible() == 0 then
                btn:ShowWindow(1)
            end
        end
    end
    local pc_name = session.GetMySession():GetPCApc():GetName()
    local equip_item_list = session.GetEquipItemList()
    local count = equip_item_list:Count()
    local cid = session.GetMySession():GetCID()
    local data = g.ocsl_settings.chars[pc_name].equips
    local score = 0
    for i = 0, count - 1 do
        local equip_item = equip_item_list:GetEquipItemByIndex(i)
        local spot_name = item.GetEquipSpotName(equip_item.equipSpot)
        local spot_item = session.GetEquipItemBySpot(item.GetEquipSpotNum(spot_name))
        local obj = GetIES(spot_item:GetObject())
        if obj.ClassName ~= "NoRing" then
            score = GET_GEAR_SCORE(obj) + score
        end
        local lv = TryGetProp(obj, "Reinforce_2", 0)
        if spot_name == "SHIRT" or spot_name == "PANTS" or spot_name == "GLOVES" or spot_name == "BOOTS" then
            local slot = GET_CHILD_RECURSIVELY(inventory, spot_name)
            local icon = slot:GetIcon()
            if icon then
                local name, skill_lv = shared_skill_enchant.get_enchanted_skill(obj, 1)
                data[spot_name] = {
                    clsid = obj.ClassID,
                    lv = lv,
                    skill_name = name,
                    skill_lv = skill_lv
                }
            else
                data[spot_name] = {}
            end
        elseif spot_name == "RH" or spot_name == "LH" or spot_name == "RH_SUB" or spot_name == "LH_SUB" or spot_name ==
            "RING1" or spot_name == "RING2" or spot_name == "NECK" then
            local slot = GET_CHILD_RECURSIVELY(inventory, spot_name)
            local icon = slot:GetIcon()
            if icon then
                data[spot_name] = {
                    clsid = obj.ClassID,
                    lv = lv
                }
            else
                data[spot_name] = {}
            end
        elseif spot_name == "SEAL" or spot_name == "ARK" or spot_name == "RELIC" then
            local slot = GET_CHILD_RECURSIVELY(inventory, spot_name)
            local icon = slot:GetIcon()
            if spot_name == "SEAL" then
                lv = GET_CURRENT_SEAL_LEVEL(obj)
            elseif spot_name == "ARK" then
                lv = TryGetProp(obj, 'ArkLevel', 1)
            elseif spot_name == "RELIC" then
                lv = TryGetProp(obj, 'Relic_LV', 1)
            end
            if icon then
                data[spot_name] = {
                    clsid = obj.ClassID,
                    lv = lv
                }
            else
                data[spot_name] = {}
            end
        elseif spot_name == "EARRING" then
            local slot = GET_CHILD_RECURSIVELY(inventory, spot_name)
            local icon = slot:GetIcon()
            local option_texts = {}
            if icon then
                local max_option_count = shared_item_earring.get_max_special_option_count(TryGetProp(obj, 'UseLv', 1))
                for i = 1, max_option_count do
                    local option_name = 'EarringSpecialOption_' .. i
                    local job = TryGetProp(obj, option_name, 'None')
                    if job ~= 'None' then
                        local job_cls = GetClass('Job', job)
                        if job_cls ~= nil then
                            local item_name = dictionary.ReplaceDicIDInCompStr(job_cls.Name)
                            local rank = TryGetProp(obj, 'EarringSpecialOptionRankValue_' .. i, 0)
                            local skill_lv = TryGetProp(obj, 'EarringSpecialOptionLevelValue_' .. i, 0)
                            local temp_text = ScpArgMsg('EarringSpecialOption{ctrl}{rank}{lv}', 'ctrl', item_name,
                                'rank', rank, 'lv', skill_lv)
                            table.insert(option_texts, temp_text)
                        end
                    end
                end
            end
            local final_text = table.concat(option_texts, ":::")
            if icon then
                data[spot_name] = {
                    clsid = obj.ClassID,
                    lv = final_text
                }
            else
                data[spot_name] = {}
            end
        elseif spot_name == "CORE" then -- ！
            local slot = GET_CHILD_RECURSIVELY(inventory, spot_name)
            local icon = slot:GetIcon()
            if icon then
                data[spot_name] = {
                    clsid = obj.ClassID,
                    lv = lv
                }
            else
                data[spot_name] = {}
            end
        end
    end
    local info = equipcard.GetCardInfo(13)
    if info then
        data["LEG"] = {
            clsid = info:GetCardID(),
            lv = info.cardLv
        }
    else
        data["LEG"] = {}
    end
    local info = equipcard.GetCardInfo(14)
    if info then
        data["GOD"] = {
            clsid = info:GetCardID(),
            lv = info.cardLv
        }
    else
        data["GOD"] = {}
    end
    g.ocsl_settings.chars[pc_name].gear_score = score
    Other_character_skill_list_save_settings()
end

function Other_character_skill_list_sort()
    -- バラック(layer:1/2/3)でグループ化し、その中は各バラック内の順番(order)で並べる
    local function sort_layer_order(a, b)
        if a.layer ~= b.layer then
            return a.layer < b.layer
        else
            return a.order < b.order
        end
    end
    local char_list = {}
    for _, char_data in pairs(g.ocsl_settings.chars) do
        table.insert(char_list, char_data)
    end
    table.sort(char_list, sort_layer_order)
    g.ocsl_sorted_chars = char_list
end

function Other_character_skill_list_split_earring_options(earring_data_string)
    if not earring_data_string or earring_data_string == "" then
        return {}
    end
    local options_list = {}
    for option_part in earring_data_string:gmatch("([^:]+)") do
        table.insert(options_list, option_part)
    end
    return options_list
end

function Other_character_skill_list_frame_open()
    if g.settings.other_character_skill_list.use == 0 then
        return
    end
    -- Lazy-load: the settings frame can be opened from anywhere (e.g. Nexus
    -- Addons management list), but char data is normally only loaded/sorted on
    -- city entry. Ensure data exists before use so the frame does not silently
    -- fail with a nil error.
    if not g.ocsl_settings then
        Other_character_skill_list_load_settings()
    end
    if not g.ocsl_sorted_chars or #g.ocsl_sorted_chars == 0 then
        Other_character_skill_list_char_load_settings()
        Other_character_skill_list_sort()
    end
    -- save_enchant indexes inventory equip slots and can raise if the inventory
    -- UI is not built yet; it is only a refresh, so never let it block the frame.
    pcall(Other_character_skill_list_save_enchant)
    if not g.ocsl_sorted_chars or #g.ocsl_sorted_chars == 0 then
        local msg = g.lang == "Japanese" and
            "[Nexus Addons P] 表示できるキャラクター情報がありません。都市でキャラクターを切り替えると記録されます" or
            "[Nexus Addons P] No character data to display. Info is recorded when you switch characters in a city."
        imcAddOn.BroadMsg("NOTICE_Dm_!", msg, 5.0)
        return
    end
    local ok, err = pcall(Other_character_skill_list_render_frame)
    if not ok then
        local m = "[Nexus Addons P] OCSL open error: " .. tostring(err)
        imcAddOn.BroadMsg("NOTICE_Dm_!", m, 10.0)
        pcall(g.log_to_file, m)
    end
end

function Other_character_skill_list_render_frame()
    local ocsl = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "ocsl", 0, 0, 70, 30)
    AUTO_CAST(ocsl)
    ocsl:SetSkinName("test_frame_midle_light")
    ocsl:SetLayerLevel(99)
    local title_box = Other_character_skill_create_title_bar(ocsl)
    local main_gbox = ocsl:CreateOrGetControl("groupbox", "gbox", 5, 35, 1070, 280)
    AUTO_CAST(main_gbox)
    main_gbox:RemoveAllChild()
    main_gbox:SetSkinName("bg2")
    main_gbox:EnableScrollBar(0)
    local all_skills = GetClassList("Skill")
    local y_pos = 10
    local char_count = 0
    local last_etc_x = 0
    for i, char_info in ipairs(g.ocsl_sorted_chars) do
        local char_settings = g.ocsl_settings.chars[char_info.name]
        if char_settings.hide ~= 1 or g.ocsl_settings.hide == 0 then
            local job_list, level, last_job_id = GetJobListFromAdventureBookCharData(char_info.name)
            if type(_G["INDUN_LIST_VIEWER_ON_INIT"]) == "function" then
                local ilv = _G["ADDONS"]["norisan"]["indun_list_viewer"]
                local ilv_settings = ilv and ilv.settings
                if ilv_settings and ilv_settings[char_info.name] then
                    if ilv_settings[char_info.name].president_jobid ~= "" then
                        last_job_id = ilv_settings[char_info.name].president_jobid
                    end
                end
            elseif type(_G["indun_list_viewer_on_init"]) == "function" then
                local ilv_settings = _G["ADDONS"]["norisan"]["_NEXUS_ADDONS_P"].ilv_settings
                if ilv_settings and ilv_settings.chars and ilv_settings.chars[char_info.name] then
                    if ilv_settings.chars[char_info.name].president_jobid ~= "" then
                        last_job_id = ilv_settings.chars[char_info.name].president_jobid
                    end
                end
            end
            local last_job_class = GetClassByType("Job", last_job_id)
            local last_job_icon = TryGetProp(last_job_class, "Icon")
            local job_slot = main_gbox:CreateOrGetControl("slot", "jobslot" .. i, 0, y_pos - 3, 25, 25)
            AUTO_CAST(job_slot)
            job_slot:SetSkinName("None")
            job_slot:EnableHitTest(1)
            job_slot:EnablePop(0)
            local job_icon = CreateIcon(job_slot)
            job_icon:SetImage(last_job_icon)
            local name_lbl = main_gbox:CreateOrGetControl("richtext", "name_text" .. i, 25, y_pos, 195, 20)
            AUTO_CAST(name_lbl)
            name_lbl:SetText("{ol}" .. char_info.name)
            name_lbl:AdjustFontSizeByWidth(195)
            name_lbl:SetEventScript(ui.RBUTTONUP, "Other_character_skill_list_char_report")
            name_lbl:SetEventScriptArgString(ui.RBUTTONUP, char_info.name)
            local gs_str = char_settings.gear_score ~= 0 and tostring(char_settings.gear_score) or "NoData"
            if type(_G["INSTANTCC_ON_INIT"]) == "function" and g.settings.instant_cc.use == 1 then
                name_lbl:SetEventScript(ui.LBUTTONDOWN, "Other_character_skill_list_save_enchant")
                name_lbl:SetEventScript(ui.LBUTTONUP, "Other_character_skill_list_INSTANTCC_DO_CC")
                name_lbl:SetEventScriptArgString(ui.LBUTTONUP, char_info.cid)
                name_lbl:SetEventScriptArgNumber(ui.LBUTTONUP, char_info.layer)
                name_lbl:SetTextTooltip(g.lang == "Japanese" and "{ol}GearScore: " .. gs_str .. "{nl} {nl}" ..
                                            "右クリック: 各キャラ装備詳細{nl}左クリック：キャラクターチェンジ" or
                                            "{ol}GearScore: " .. gs_str .. "{nl} {nl}" ..
                                            "Right click: Details of each character's equipment{nl}Left click: Character change")
            else
                name_lbl:SetTextTooltip(g.lang == "Japanese" and "{ol}GearScore: " .. gs_str .. "{nl} {nl}" ..
                                            "右クリック: 各キャラ装備詳細" or "{ol}GearScore: " .. gs_str ..
                                            "{nl} {nl}" .. "Right-click: Details of each character's equipment")
            end
            local equips = {"SHIRT", "PANTS", "GLOVES", "BOOTS", "LEG", "GOD", "SEAL", "ARK", "RELIC", "EARRING",
                            "CORE", "RH", "LH", "RH_SUB", "LH_SUB", "RING1", "RING2", "NECK"}
            Other_character_skill_list_create_weapon_slots(main_gbox, char_settings.equips, equips, i, y_pos)
            Other_character_skill_list_create_armor_slots(main_gbox, char_settings.equips, equips, all_skills, i, y_pos)
            last_etc_x = Other_character_skill_list_create_etc_slots(main_gbox, char_settings.equips, equips, i, y_pos)
            local hide_check_char = main_gbox:CreateOrGetControl('checkbox', "hide_check" .. i, last_etc_x, y_pos, 25,
                25)
            AUTO_CAST(hide_check_char)
            hide_check_char:SetCheck(char_settings.hide)
            hide_check_char:SetEventScript(ui.LBUTTONDOWN, 'Other_character_skill_list_display_check')
            hide_check_char:SetEventScriptArgString(ui.LBUTTONDOWN, char_info.name)
            hide_check_char:SetTextTooltip(g.lang == "Japanese" and "{ol}チェックすると非表示" or
                                               "{ol}Check to hide")
            y_pos = y_pos + 25
            char_count = char_count + 1
        end
    end
    local frame_height = char_count * 25
    ocsl:Resize(last_etc_x + 40, frame_height + 60)
    title_box:Resize(last_etc_x + 30, 40)
    main_gbox:Resize(last_etc_x + 30, frame_height + 20)
    local current_frame_w = ocsl:GetWidth()
    local map_frame = ui.GetFrame("map")
    local map_width = map_frame:GetWidth()
    ocsl:SetPos((map_width - current_frame_w) / 2, 0)
    ocsl:ShowWindow(1)
    g.esc_register(addon_name_lower .. "ocsl", "Other_character_skill_list_ESCAPE_PRESSED")
end

function Other_character_skill_create_title_bar(ocsl)
    local title_box = ocsl:CreateOrGetControl("groupbox", "title", 0, 0, 1070, 40)
    AUTO_CAST(title_box)
    title_box:SetSkinName("None")
    title_box:EnableScrollBar(0)
    local close_btn = title_box:CreateOrGetControl("button", "close", 0, 0, 20, 20)
    AUTO_CAST(close_btn)
    close_btn:SetImage("testclose_button")
    close_btn:SetGravity(ui.RIGHT, ui.TOP)
    close_btn:SetEventScript(ui.LBUTTONUP, "Other_character_skill_list_frame_close")
    local help_btn = title_box:CreateOrGetControl('button', "help", 40, 0, 35, 35)
    AUTO_CAST(help_btn)
    help_btn:SetText("{ol}{img question_mark 20 20}")
    help_btn:SetSkinName("test_pvp_btn")
    local ccbtn = title_box:CreateOrGetControl('button', 'ccbtn', 75, 0, 35, 35)
    AUTO_CAST(ccbtn)
    ccbtn:SetSkinName("None")
    ccbtn:SetText("{ol}{img barrack_button_normal 35 35}")
    ccbtn:SetEventScript(ui.LBUTTONUP, "APPS_TRY_MOVE_BARRACK")
    ccbtn:SetTextTooltip(g.lang == "Japanese" and "{ol}バラックに戻ります" or "{ol}Return to Barracks")
    local hide_check = title_box:CreateOrGetControl('checkbox', 'hide_check', 120, 0, 35, 35)
    AUTO_CAST(hide_check)
    hide_check:SetEventScript(ui.LBUTTONUP, 'Other_character_skill_list_display_check')
    hide_check:SetTextTooltip(g.lang == "Japanese" and "{ol}チェックしたキャラを非表示" or
                                  "{ol}Hide Checked Characters")
    hide_check:SetCheck(g.ocsl_settings.hide)
    help_btn:SetTextTooltip(g.lang == "Japanese" and
                                "{ol}バラック1/2/3の順にグループ表示します。順番に並ばない場合は、各バラック(1,2,3)に一度ずつログインして順番を記録してください。{nl}" ..
                                "{ol}名前部分を押すと、ログインキャラと同一バラックの各キャラの装備詳細が見れます。" or
                                "{ol}Characters are grouped by barrack (1/2/3).{nl}" ..
                                "If they do not sort in order, log in once from each barrack (1,2,3) to record the order.{nl}" ..
                                "{ol}Press the name section to see the equipment details of each character{nl}in the same barrack as the login character.")
    local weapon_lbl = title_box:CreateOrGetControl("richtext", "weapon", 160, 10, 100, 20)
    weapon_lbl:SetText(g.lang == "Japanese" and "{ol}" .. "武器" or "{ol}" .. "weapons")
    weapon_lbl:AdjustFontSizeByWidth(100)
    local acc_lbl = title_box:CreateOrGetControl("richtext", "Accessory", 290, 10, 100, 20)
    acc_lbl:SetText(g.lang == "Japanese" and "{ol}" .. "アクセ" or "{ol}" .. "Accessory")
    local equip_x = 390
    local equip_labels = {ClMsg("Shirt"), ClMsg("Pants"), ClMsg("GLOVES"), ClMsg("BOOTS"),
                          (g.lang == "Japanese" and "その他" or "etc.")}
    for i = 0, 4 do
        local equip_lbl = title_box:CreateOrGetControl("richtext", "equip_text" .. i, equip_x, 10, 100, 20)
        equip_lbl:SetText("{ol}" .. equip_labels[i + 1])
        equip_lbl:AdjustFontSizeByWidth(100)
        equip_x = equip_x + 225
    end
    return title_box
end

function Other_character_skill_list_create_weapon_slots(parent_gbox, char_equips, equips, i, y_pos)
    for j = 12, #equips do
        local equip_type = equips[j]
        local equip_data_entry = char_equips[equip_type]
        local weapon_slot_x = 155 + 30 * (j - 12)
        if j >= 16 then
            weapon_slot_x = weapon_slot_x + 10
        end
        local weapon_slot = parent_gbox:CreateOrGetControl("slot", "slot" .. equip_type .. i, weapon_slot_x, y_pos, 25,
            24)
        AUTO_CAST(weapon_slot)
        weapon_slot:SetSkinName('invenslot2')
        if equip_data_entry then
            local clsid = equip_data_entry.clsid
            if clsid and clsid ~= 0 then
                local lv = equip_data_entry.lv
                local item_cls = GetClassByType("Item", clsid)
                if item_cls then
                    SET_SLOT_ICON(weapon_slot, item_cls.Icon)
                    SET_SLOT_BG_BY_ITEMGRADE(weapon_slot, item_cls)
                    weapon_slot:SetText('{s12}{ol}{#FFFF00}+' .. lv, 'count', ui.RIGHT, ui.BOTTOM, 0, 0)
                    local icon = weapon_slot:GetIcon()
                    if icon then
                        icon:SetTextTooltip("{ol}" .. item_cls.Name)
                    end
                end
            end
        end
    end
end

function Other_character_skill_list_create_armor_slots(parent_gbox, char_equips, equips, all_skills, i, y_pos)
    local equip_grp_x = 385
    for j = 1, 4 do
        local equip_type = equips[j]
        local equip_data_entry = char_equips[equip_type]
        local skill_slot = parent_gbox:CreateOrGetControl("slot", "slot" .. equip_type .. i,
            equip_grp_x + (225 * (j - 1)) + 30, y_pos, 25, 24)
        AUTO_CAST(skill_slot)
        skill_slot:SetSkinName('invenslot2')
        local item_slot = parent_gbox:CreateOrGetControl("slot", "equip" .. equip_type .. i,
            equip_grp_x + (225 * (j - 1)), y_pos, 25, 24)
        AUTO_CAST(item_slot)
        item_slot:SetSkinName('invenslot2')
        if equip_data_entry then
            local clsid = equip_data_entry.clsid
            local item_cls = GetClassByType("Item", clsid)
            if item_cls then
                SET_SLOT_ICON(item_slot, item_cls.Icon)
                SET_SLOT_BG_BY_ITEMGRADE(item_slot, item_cls)
                item_slot:SetText('{s12}{ol}{#FFFF00}+' .. equip_data_entry.lv, 'count', ui.RIGHT, ui.BOTTOM, 0, 0)
                local icon = item_slot:GetIcon()
                if icon then
                    icon:SetTextTooltip("{ol}" .. item_cls.Name)
                end
            end
            local skill = GetClassByNameFromList(all_skills, equip_data_entry.skill_name)
            if skill then
                SET_SLOT_ICON(skill_slot, 'icon_' .. skill.Icon)
                skill_slot:SetText('{s14}{ol}{#FFFF00}' .. equip_data_entry.skill_lv, 'count', ui.RIGHT, ui.BOTTOM, -2,
                    -2)
                local icon = skill_slot:GetIcon()
                if icon then
                    icon:SetTooltipType('skill')
                    icon:SetTooltipArg("Level", skill.ClassID, equip_data_entry.skill_lv)
                end
                local skill_name_lbl = parent_gbox:CreateOrGetControl("richtext", "skill_name" .. equip_type .. i,
                    equip_grp_x + 60 + (225 * (j - 1)), y_pos, 140, 20)
                skill_name_lbl:SetText("{ol}{s16}" .. skill.Name)
                skill_name_lbl:AdjustFontSizeByWidth(160)
            end
        end
    end
end

function Other_character_skill_list_create_etc_slots(parent_gbox, char_equips, equips, i, y_pos)
    local etc_x_offset = 0
    local equip_grp_x = 385
    local last_x = equip_grp_x + 225 * 4
    for j = 5, 11 do
        local equip_type = equips[j]
        local equip_data_entry = char_equips[equip_type]
        local current_x = equip_grp_x + 225 * 4 + etc_x_offset
        local etc_slot = parent_gbox:CreateOrGetControl("slot", "etc_slot" .. equip_type .. i, current_x, y_pos, 25, 24)
        AUTO_CAST(etc_slot)
        etc_slot:SetSkinName('invenslot2')
        if equip_data_entry and equip_data_entry.clsid then
            local text_prefix = (j >= 5 and j <= 6) and "{s12}{ol}{#FFFF00}{img mon_legendstar 10 10}{nl}" or
                                    "{s12}{ol}{#FFFF00}+"
            local item_cls = GetClassByType("Item", equip_data_entry.clsid)
            if item_cls then
                SET_SLOT_ICON(etc_slot, item_cls.Icon)
                local icon = etc_slot:GetIcon()
                if icon then
                    local tooltip = item_cls.Name
                    if j == 10 then -- Earring
                        local earring_str = Other_character_skill_list_split_earring_options(equip_data_entry.lv)
                        for _, option_str in ipairs(earring_str) do
                            tooltip = "{ol}" .. tooltip .. "{nl}" .. option_str
                        end
                    elseif j ~= 11 then -- Ark
                        etc_slot:SetText(text_prefix .. equip_data_entry.lv, 'count', ui.RIGHT, ui.BOTTOM, 0, 0)
                    end
                    icon:SetTextTooltip(tooltip)
                end
            end
        end
        etc_x_offset = etc_x_offset + 30
        last_x = current_x
    end
    return last_x + 30
end

function Other_character_skill_list_char_report(ocsl, ctrl, char_name_str, num)
    local report = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "ocsl_report", 5, 40, 0, 0)
    AUTO_CAST(report)
    report:RemoveAllChild()
    report:SetLayerLevel(104)
    report:SetSkinName("None")
    report:Resize(410, 480)
    local cid = g.ocsl_settings.chars[char_name_str].cid
    local current_cid = report:GetUserValue("CID")
    if current_cid ~= "None" and current_cid ~= cid then
        DESTROY_CHILD_BYNAME(report, "char_" .. current_cid)
    else
        local char_frame = GET_CHILD_RECURSIVELY(report, "char_" .. current_cid)
        if char_frame then
            char_frame:ShowWindow(1)
        end
    end
    local bpc_info = barrack.GetBarrackPCInfoByCID(cid)
    if not bpc_info then
        local language = option.GetCurrentCountry()
        ui.SysMsg(language == "Japanese" and
                      "{ol}詳細表示は、ログイン中のキャラと同一バラックのキャラのみ対応しています" or
                      "{ol}Detailed view is supported only for characters{nl}in the same barracks as the currently logged-in character")
        Other_character_skill_list_frame_open()
        return
    end
    local char_ctrl = report:CreateOrGetControlSet('barrack_charlist', 'char_' .. cid, 10, 10)
    AUTO_CAST(char_ctrl)
    report:SetUserValue("CID", cid)
    local main_box = GET_CHILD(char_ctrl, 'mainBox')
    AUTO_CAST(main_box)
    local btn = main_box:GetChild("btn")
    btn:SetSkinName('character_off')
    btn:SetSValue(char_name_str)
    btn:SetOverSound('button_over')
    btn:SetClickSound('button_click_2')
    local indun_btn = main_box:GetChild("indunBtn")
    AUTO_CAST(indun_btn)
    indun_btn:SetImage("testclose_button")
    indun_btn:SetEventScript(ui.LBUTTONUP, "Other_character_skill_list_char_report_close")
    btn:ShowWindow(1)
    local apc = bpc_info:GetApc()
    local gender = apc:GetGender()
    local job_id = apc:GetJob()
    local level = apc:GetLv()
    local pic = GET_CHILD(main_box, "char_icon")
    AUTO_CAST(pic)
    local head_icon = ui.CaptureModelHeadImageByApperance(apc)
    pic:SetImage(head_icon)
    local name_label = GET_CHILD(main_box, "name")
    AUTO_CAST(name_label)
    name_label:SetText("{@st42b}{b}" .. char_name_str)
    local barrack_pc = session.barrack.GetMyAccount():GetByStrCID(cid)
    if barrack_pc ~= nil and barrack_pc:GetRepID() ~= 0 then
        job_id = barrack_pc:GetRepID()
    end
    local job_cls = GetClassByType("Job", job_id)
    local job_label = GET_CHILD(main_box, "job")
    AUTO_CAST(job_label)
    job_label:SetText("{@st42b}" .. GET_JOB_NAME(job_cls, gender))
    local level_label = GET_CHILD(main_box, "level")
    AUTO_CAST(level_label)
    level_label:SetText("{@st42b}Lv." .. level)
    local detail_box = GET_CHILD(char_ctrl, 'detailBox')
    AUTO_CAST(detail_box)
    local rh_sub_slot = detail_box:CreateOrGetControl("slot", "RH_SUB", 138, 214, 55, 55)
    local lh_sub_slot = detail_box:CreateOrGetControl("slot", "LH_SUB", 198, 214, 55, 55)
    local map_label = GET_CHILD(detail_box, 'mapName')
    AUTO_CAST(map_label)
    local map_cls = GetClassByType("Map", apc.mapID)
    if map_cls ~= nil then
        local map_name = map_cls.Name
        map_label:SetText("{@st66b}" .. map_name)
    end
    local spot_count = item.GetEquipSpotCount() - 1
    local skin_list = {}
    for i = 0, spot_count do
        local equip_obj = bpc_info:GetEquipObj(i)
        local spot_name = item.GetEquipSpotName(i)
        if equip_obj then
            local ies_obj = GetIES(equip_obj)
            local equip_type = TryGet_Str(ies_obj, "EqpType")
            if equip_type == "HELMET" then
                if item.IsNoneItem(ies_obj.ClassID) == 0 then
                    spot_name = "HAIR"
                end
            end
            if spot_name == "TRINKET" and item.IsNoneItem(ies_obj.ClassID) == 0 then
                spot_name = "LH"
            end
        end
        local slot_ctrl = GET_CHILD(detail_box, spot_name)
        AUTO_CAST(slot_ctrl)
        if slot_ctrl then
            if slot_ctrl:GetName() == "SHIRT" then
                slot_ctrl:SetMargin(-120, 150, 0, 0)
            elseif slot_ctrl:GetName() == "PANTS" then
                slot_ctrl:SetMargin(-60, 150, 0, 0)
            elseif slot_ctrl:GetName() == "GLOVES" then
                slot_ctrl:SetMargin(0, 150, 0, 0)
            elseif slot_ctrl:GetName() == "BOOTS" then
                slot_ctrl:SetMargin(60, 150, 0, 0)
            elseif slot_ctrl:GetName() == "RH" then
                slot_ctrl:SetMargin(-120, 214, 0, 0)
            elseif slot_ctrl:GetName() == "LH" then
                slot_ctrl:SetMargin(-60, 214, 0, 0)
            elseif slot_ctrl:GetName() == "ARK" then
                slot_ctrl:SetMargin(120, 150, 0, 0)
            elseif slot_ctrl:GetName() == "RELIC" then
                slot_ctrl:SetMargin(120, 214, 0, 0)
            end
            if skin_list[spot_name] == nil then
                skin_list[spot_name] = slot_ctrl:GetSkinName()
            end
            slot_ctrl:EnableDrag(0)
            if not equip_obj then
                CLEAR_SLOT_ITEM_INFO(slot_ctrl)
            else
                local ies_item = GetIES(equip_obj)
                local refresh_scp = ies_item.RefreshScp
                if refresh_scp ~= "None" then
                    local scp_func = _G[refresh_scp]
                    scp_func(ies_item)
                end
                if 0 == item.IsNoneItem(ies_item.ClassID) then
                    CLEAR_SLOT_ITEM_INFO(slot_ctrl)
                    SET_SLOT_ITEM_OBJ(slot_ctrl, ies_item, gender, 1)
                else
                    local current_skin = skin_list[spot_name]
                    if current_skin ~= nil then
                        slot_ctrl:SetSkinName(current_skin)
                    end
                    SET_SLOT_TRANSCEND_LEVEL(slot_ctrl, 0)
                    SET_SLOT_REINFORCE_LEVEL(slot_ctrl, 0)
                    CLEAR_SLOT_ITEM_INFO(slot_ctrl)
                end
            end
        end
    end
    char_ctrl:Resize(400, 430)
    local map_frame = ui.GetFrame("map")
    local map_width = map_frame:GetWidth()
    report:SetPos((map_width) / 2 - 410 * 1.5, 40)
    report:ShowWindow(1)
    -- OCSL 本体より後に積むので、ESC は詳細フレーム → 本体の順で 1 枚ずつ閉じる
    g.esc_register(addon_name_lower .. "ocsl_report", "Other_character_skill_list_char_report_close")
end

function Other_character_skill_list_ESCAPE_PRESSED()
    local ocsl = ui.GetFrame(addon_name_lower .. "ocsl")
    Other_character_skill_list_frame_close(ocsl)
end

function Other_character_skill_list_frame_close(parent)
    local ocsl = parent:GetTopParentFrame()
    ui.DestroyFrame(ocsl:GetName())
    Other_character_skill_list_char_report_close()
end

function Other_character_skill_list_char_report_close(parent, ctrl, str, num)
    -- 閉じるボタンからは parent が来るが、OCSL 本体を閉じたときと ESC からは引数無しで
    -- 呼ばれる。その場合はフレーム名から引く(以前はここで parent が nil のまま
    -- GetTopParentFrame を呼んでいて、詳細フレームが閉じずにエラーになっていた)。
    local report = parent and parent:GetTopParentFrame() or ui.GetFrame(addon_name_lower .. "ocsl_report")
    if not report then
        return
    end
    ui.DestroyFrame(report:GetName())
end

function Other_character_skill_list_display_check(parent, ctrl, char_name, num)
    local ischeck = ctrl:IsChecked()
    if char_name == "" then
        g.ocsl_settings.hide = ischeck
    else
        g.ocsl_settings.chars[char_name].hide = ischeck
    end
    Other_character_skill_list_save_settings()
    Other_character_skill_list_frame_open()
end

function Other_character_skill_list_INSTANTCC_DO_CC(frame, ctrl, cid, layer)
    if _G["INSTANTCC_DO_CC"] then
        _G["INSTANTCC_DO_CC"](cid, layer)
    end
end
-- other_character_skill_list ここまで

