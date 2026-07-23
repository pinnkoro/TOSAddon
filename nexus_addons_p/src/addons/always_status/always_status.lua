-- always_status ここから
local always_status_group_colors = {
    base = "{#00FF00}",
    atk1 = "{#FF6600}",
    atk2 = "{#FF4040}",
    def = "{#66B3FF}"
}
local always_status_master_list =
    { -- { key = "プログラム上の名前", group = "色グループ", on = デフォルト表示(1=ON), jp = "日本語短縮名" }
    -- 基本ステータス
    {
        key = "STR",
        group = "base",
        on = 1
    }, {
        key = "INT",
        group = "base",
        on = 1
    }, {
        key = "CON",
        group = "base",
        on = 0
    }, {
        key = "MNA",
        group = "base",
        on = 0
    }, {
        key = "DEX",
        group = "base",
        on = 0
    }, {
        key = "gear_score",
        group = "base",
        on = 1
    }, {
        key = "ability_point_score",
        group = "base",
        on = 1
    }, {
        key = "RHP",
        group = "atk1",
        on = 1
    }, {
        key = "RSP",
        group = "atk1",
        on = 0
    }, {
        key = "PATK",
        group = "atk1",
        on = 1
    }, {
        key = "MATK",
        group = "atk1",
        on = 1
    }, {
        key = "HEAL_PWR",
        group = "atk1",
        on = 0
    }, {
        key = "SR",
        group = "atk1",
        on = 0
    }, {
        key = "HR",
        group = "atk1",
        on = 1
    }, {
        key = "BLK_BREAK",
        group = "atk1",
        on = 1
    }, {
        key = "CRTATK",
        group = "atk1",
        on = 1,
        jp = "物理クリ攻撃"
    }, {
        key = "CRTMATK",
        group = "atk1",
        on = 1,
        jp = "魔法クリ攻撃"
    }, {
        key = "CRTHR",
        group = "atk1",
        on = 1,
        jp = "クリ発生"
    }, {
        key = "DEF",
        group = "def",
        on = 0
    }, {
        key = "MDEF",
        group = "def",
        on = 0
    }, {
        key = "SDR",
        group = "def",
        on = 0
    }, {
        key = "DR",
        group = "def",
        on = 1
    }, {
        key = "BLK",
        group = "def",
        on = 0
    }, {
        key = "CRTDR",
        group = "def",
        on = 1,
        jp = "クリ抵抗"
    }, {
        key = "MSPD",
        group = "atk1",
        on = 1
    }, {
        key = "CastingSpeed",
        group = "atk1",
        on = 1,
        jp = "キャス時間比率"
    }, {
        key = "Add_Damage_Atk",
        group = "atk2",
        on = 0
    }, {
        key = "ResAdd_Damage",
        group = "def",
        on = 0,
        jp = "追加ダメ抵抗"
    }, {
        key = "Aries_Atk",
        group = "atk2",
        on = 0,
        jp = "突アップ"
    }, {
        key = "Slash_Atk",
        group = "atk2",
        on = 0,
        jp = "斬アップ"
    }, {
        key = "Strike_Atk",
        group = "atk2",
        on = 0,
        jp = "打アップ"
    }, {
        key = "Arrow_Atk",
        group = "atk2",
        on = 0,
        jp = "弓アップ"
    }, {
        key = "Cannon_Atk",
        group = "atk2",
        on = 0,
        jp = "キャノンアップ"
    }, {
        key = "Gun_Atk",
        group = "atk2",
        on = 0,
        jp = "銃器アップ"
    }, {
        key = "Magic_Melee_Atk",
        group = "atk2",
        on = 0,
        jp = "無属性アップ"
    }, {
        key = "Magic_Fire_Atk",
        group = "atk2",
        on = 0,
        jp = "炎属性アップ"
    }, {
        key = "Magic_Ice_Atk",
        group = "atk2",
        on = 0,
        jp = "氷属性アップ"
    }, {
        key = "Magic_Lightning_Atk",
        group = "atk2",
        on = 0,
        jp = "雷属性アップ"
    }, {
        key = "Magic_Earth_Atk",
        group = "atk2",
        on = 0,
        jp = "地属性アップ"
    }, {
        key = "Magic_Poison_Atk",
        group = "atk2",
        on = 0,
        jp = "毒属性アップ"
    }, {
        key = "Magic_Dark_Atk",
        group = "atk2",
        on = 0,
        jp = "闇属性アップ"
    }, {
        key = "Magic_Holy_Atk",
        group = "atk2",
        on = 0,
        jp = "聖属性アップ"
    }, {
        key = "Magic_Soul_Atk",
        group = "atk2",
        on = 0,
        jp = "念属性アップ"
    }, {
        key = "BOSS_ATK",
        group = "atk2",
        on = 1,
        jp = "ボス対象攻撃力"
    }, {
        key = "Cloth_Atk",
        group = "atk2",
        on = 0,
        jp = "クロース対象"
    }, {
        key = "Leather_Atk",
        group = "atk2",
        on = 0,
        jp = "レザー対象"
    }, {
        key = "Iron_Atk",
        group = "atk2",
        on = 0,
        jp = "プレート対象"
    }, {
        key = "Ghost_Atk",
        group = "atk2",
        on = 0,
        jp = "アストラル対象"
    }, {
        key = "MiddleSize_Def",
        group = "def",
        on = 1,
        jp = "中型相殺"
    }, {
        key = "Cloth_Def",
        group = "def",
        on = 0,
        jp = "クロース相殺"
    }, {
        key = "Leather_Def",
        group = "def",
        on = 1,
        jp = "レザー相殺"
    }, {
        key = "Iron_Def",
        group = "def",
        on = 0,
        jp = "プレート相殺"
    }, {
        key = "stun_res",
        group = "def",
        on = 0
    }, {
        key = "high_fire_res",
        group = "def",
        on = 0
    }, {
        key = "high_freezing_res",
        group = "def",
        on = 0
    }, {
        key = "high_lighting_res",
        group = "def",
        on = 0
    }, {
        key = "high_poison_res",
        group = "def",
        on = 0,
        jp = "極：猛毒抵抗"
    }, {
        key = "high_laceration_res",
        group = "def",
        on = 0
    }, {
        key = "portion_expansion",
        group = "def",
        on = 0,
        jp = "エリクサー広域"
    }, {
        key = "Forester_Atk",
        group = "atk2",
        on = 0,
        jp = "植物対象攻撃力"
    }, {
        key = "Widling_Atk",
        group = "atk2",
        on = 0,
        jp = "野獣対象攻撃力"
    }, {
        key = "Klaida_Atk",
        group = "atk2",
        on = 0,
        jp = "昆虫対象攻撃力"
    }, {
        key = "Paramune_Atk",
        group = "atk2",
        on = 0,
        jp = "変異対象攻撃力"
    }, {
        key = "Velnias_Atk",
        group = "atk2",
        on = 0,
        jp = "悪魔対象攻撃力"
    }, {
        key = "perfection",
        group = "atk2",
        on = 1,
        jp = "パーフェクト"
    }, {
        key = "revenge",
        group = "atk2",
        on = 0,
        jp = "復讐"
    }}

function Always_status_save_settings()
    g.save_lua(g.always_status_path, g.always_status_settings)
end

function Always_status_load_settings()
    g.always_status_path = string.format("../addons/%s/%s/always_status.lua", addon_name_lower, g.active_id)
    local json_path = string.format("../addons/%s/%s/always_status.json", addon_name_lower, g.active_id)
    g.always_status_old_path = string.format("../addons/%s/settings.json", "always_status")
    local settings = g.load_lua(g.always_status_path)
    if not settings then
        settings = g.load_json(json_path)
    end
    if not settings then
        settings = g.load_json(g.always_status_old_path)
    end
    local ver = 1.2
    if not settings then
        settings = {
            ver = ver,
            base = {
                frame_X = 0,
                frame_Y = 0,
                enable = 1,
                color = {},
                abbr = {}
            },
            chars = {}
        }
        for _, status_info in ipairs(always_status_master_list) do
            settings.base.color[status_info.key] = always_status_group_colors[status_info.group] or "{#FFFFFF}"
            settings.base.abbr[status_info.key] = status_info.key
        end
        for i = 1, 10 do
            local set_num = tostring(i)
            settings[set_num] = {
                memo = "free memo " .. i
            }
            for _, status_info in ipairs(always_status_master_list) do
                settings[set_num][status_info.key] = status_info.on or 0
            end
        end
    else
        if not settings.base or not settings.ver or settings.ver < ver then
            if not settings.base then
                local new_settings = {
                    ver = ver,
                    base = {
                        frame_X = 0,
                        frame_Y = 0,
                        enable = settings.enable or 0,
                        color = settings.color or {},
                        abbr = {}
                    },
                    chars = {}
                }
                for k, v in pairs(settings) do
                    local num = tonumber(k)
                    if num then
                        if num >= 1 and num <= 10 then
                            local set_key = tostring(k)
                            new_settings[set_key] = v
                        elseif num > 100 then
                            new_settings.chars[tostring(k)] = {
                                on = v.use or 1,
                                use_set = v.key or 1
                            }
                        end
                    end
                end
                settings = new_settings
            end
            settings.ver = ver
        end
    end
    if not settings.base then
        settings.base = {}
    end
    if not settings.base.color then
        settings.base.color = {}
    end
    if not settings.base.abbr then
        settings.base.abbr = {}
    end
    for _, status_info in ipairs(always_status_master_list) do
        if not settings.base.color[status_info.key] then
            settings.base.color[status_info.key] = always_status_group_colors[status_info.group] or "{#FFFFFF}"
        end
        if not settings.base.abbr[status_info.key] then
            settings.base.abbr[status_info.key] = status_info.key
        end
    end
    for i = 1, 10 do
        local set_num = tostring(i)
        if not settings[set_num] then
            settings[set_num] = {
                memo = "free memo " .. i
            }
        end
        for _, status_info in ipairs(always_status_master_list) do
            if settings[set_num][status_info.key] == nil then
                settings[set_num][status_info.key] = status_info.on or 0
            end
        end
    end
    g.always_status_settings = settings
    local cid_str = tostring(g.cid)
    if not g.always_status_settings.chars[cid_str] then
        g.always_status_settings.chars[cid_str] = {
            use_set = 1,
            on = 1
        }
    end
    Always_status_save_settings()
end

function Always_status_char_load_settings()
    g.always_status_settings.chars[g.cid] = {
        use_set = 1,
        on = 1
    }
    Always_status_save_settings()
end

function always_status_on_init()
    if not g.always_status_settings then
        Always_status_load_settings()
    end
    if g.settings.always_status.use == 0 then
        local always_status = ui.GetFrame(addon_name_lower .. "always_status")
        if always_status then
            ui.DestroyFrame(always_status:GetName())
        end
        local settings_frame = ui.GetFrame(addon_name_lower .. "always_status_settings")
        if settings_frame then
            ui.DestroyFrame(settings_frame:GetName())
        end
        return
    end
    if not g.always_status_settings.chars[g.cid] then
        Always_status_char_load_settings()
    end
    local old_func = g.settings.always_status.old_init_func
    if _G[old_func] then
        return
    end
    Always_status_frame_init()
end

function Always_status_lazy_start(frame)
    if not g.always_status_settings then
        Always_status_load_settings()
    end
    local old_func = g.settings.always_status.old_init_func
    if _G[old_func] then
        return
    end
    if g.always_status_settings and g.settings.always_status.use == 1 then
        Always_status_frame_init()
    end
    return 0
end

--[[function Always_status_calc_all_atk_status(pc, attribute_name, value)
    if attribute_name == 'SmallSize_Atk' or attribute_name == 'MiddleSize_Atk' or attribute_name == 'LargeSize_Atk' then
        value = value + TryGetProp(pc, 'AllSize_Atk', 0)
    elseif attribute_name == 'Cloth_Atk' or attribute_name == 'Leather_Atk' or attribute_name == 'Iron_Atk' or
        attribute_name == 'Ghost_Atk' then
        value = value + TryGetProp(pc, 'AllMaterialType_Atk', 0)
    elseif attribute_name == 'Cloth_Def' or attribute_name == 'Leather_Def' or attribute_name == 'Iron_Def' then
        value = value + TryGetProp(pc, 'AllMaterialType_Def', 0)
    elseif attribute_name == 'Forester_Atk' or attribute_name == 'Widling_Atk' or attribute_name == 'Klaida_Atk' or
        attribute_name == 'Paramune_Atk' or attribute_name == 'Velnias_Atk' then
        value = value + TryGetProp(pc, 'AllRace_Atk', 0)
    end
    return value
end]]

function Always_status_calc_all_atk_status(pc, attribute_name, value)
    local is_target = false -- 計算対象かどうかのフラグ
    if attribute_name == 'SmallSize_Atk' or attribute_name == 'MiddleSize_Atk' or attribute_name == 'LargeSize_Atk' then
        value = value + TryGetProp(pc, 'AllSize_Atk', 0)
        is_target = true
    elseif attribute_name == 'Cloth_Atk' or attribute_name == 'Leather_Atk' or attribute_name == 'Iron_Atk' or
        attribute_name == 'Ghost_Atk' then
        value = value + TryGetProp(pc, 'AllMaterialType_Atk', 0)
        is_target = true
    elseif attribute_name == 'Cloth_Def' or attribute_name == 'Leather_Def' or attribute_name == 'Iron_Def' or
        attribute_name == "MiddleSize_Def" then -- "MiddleSize_Def"
        value = value + TryGetProp(pc, 'AllMaterialType_Def', 0)
        is_target = true
    elseif attribute_name == 'Forester_Atk' or attribute_name == 'Widling_Atk' or attribute_name == 'Klaida_Atk' or
        attribute_name == 'Paramune_Atk' or attribute_name == 'Velnias_Atk' then
        value = value + TryGetProp(pc, 'AllRace_Atk', 0)
        is_target = true
    end
    if not is_target then
        return value
    end
    local level = info.GetLevel(session.GetMyHandle())
    local max_cap = level * 30
    local percent = 0
    if max_cap > 0 then
        percent = (value / max_cap) * 100
    end
    return string.format("%d (%.0f%%)", value, percent)
end

function Always_status_calc_special_opt(pc, name)
    local value = 0
    local equip_item_list = session.GetEquipItemList();
    local equip_guid_list = equip_item_list:GetGuidList();
    local count = equip_guid_list:Count()
    for i = 0, count - 1 do
        local guid = equip_guid_list:Get(i)
        if guid ~= '0' then
            local equip_item = equip_item_list:GetItemByGuid(guid);
            if equip_item ~= nil and equip_item:GetObject() ~= nil then
                local item = GetIES(equip_item:GetObject())
                for j = 1, 6 do
                    local _name = 'RandomOption_' .. j
                    local _value = 'RandomOptionValue_' .. j
                    if TryGetProp(item, _name, 'None') == name then
                        value = value + TryGetProp(item, _value, 0)
                    end
                end
            end
        end
    end
    value = value + GetExProp(pc, name .. '_BM')
    return value
end

function Always_status_get_status_text(pc, status)
    local special_opts = {
        perfection = 1,
        revenge = 1,
        stun_res = 1,
        high_fire_res = 1,
        high_freezing_res = 1,
        high_lighting_res = 1,
        high_poison_res = 1,
        high_laceration_res = 1,
        portion_expansion = 1
    }
    if special_opts[status] then
        local val = Always_status_calc_special_opt(pc, status)
        return tostring(val)
    end
    if status == "STR" or status == "INT" or status == "CON" or status == "MNA" or status == "DEX" then
        local total_value = pc[status] + session.GetUserConfig(status .. "_UP")
        return tostring(total_value)
    end
    if status == "gear_score" then
        return tostring(GET_PLAYER_GEAR_SCORE(pc))
    end
    if status == "ability_point_score" then
        return tostring(GET_PLAYER_ABILITY_SCORE(pc)) .. "%"
    end
    if status == "PATK" or status == "MATK" then
        local min = pc["MIN" .. status]
        local max = pc["MAX" .. status]
        if GetExProp(pc, 'event_atk') > 0 then
            local event_atk = GetExProp(pc, 'event_atk')
            min = event_atk
            max = event_atk
        end
        return string.format("%d~%d", min, max)
    end
    if status == "HEAL_PWR" then
        return tostring(GET_SHOW_HEAL_PWR(pc, pc.HEAL_PWR))
    end
    if status == "CastingSpeed" then
        local val = TryGetProp(pc, status, 0)
        return tostring(val) .. "%"
    end
    local value = TryGetProp(pc, status, 0)
    value = Always_status_calc_all_atk_status(pc, status, value)
    return tostring(value)
end

function Always_status_frame_init()
    local function _logic()
        local always_status = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "always_status", 0, 0, 70, 30)
        AUTO_CAST(always_status)
        local base = g.always_status_settings["base"]
        always_status:RemoveAllChild()
        always_status:EnableHittestFrame(base.enable)
        always_status:EnableMove(base.enable)
        always_status:SetGravity(ui.RIGHT, ui.TOP)
        local rect = always_status:GetMargin()
        always_status:SetMargin(rect.left - rect.left, rect.top - rect.top + 500,
            rect.right == 0 and rect.right + 400 or rect.right, rect.bottom)
        always_status:SetTitleBarSkin("None")
        always_status:SetSkinName("None")
        always_status:SetLayerLevel(11)
        always_status:SetEventScript(ui.LBUTTONUP, "Always_status_frame_move")
        always_status:SetEventScript(ui.RBUTTONDOWN, "Always_status_info_setting")
        local as_text = always_status:CreateOrGetControl("richtext", "as_text", 20, 5)
        AUTO_CAST(as_text)
        as_text:SetText("{ol}{S10}Always Status")
        as_text:SetEventScript(ui.RBUTTONDOWN, "Always_status_info_setting")
        local tooltip = g.lang == "Japanese" and "{ol}右クリックで表示設定" or
                            "{ol}Right-click to set display"
        as_text:SetTextTooltip(tooltip)
        local char = g.always_status_settings["chars"][g.cid]
        tooltip = g.lang == "Japanese" and "{ol}キャラクター毎に表示非表示を切り替えます" or
                      "{ol}Display and hide for each character"
        if char.on ~= 1 then
            local plus_pic = always_status:CreateOrGetControl("picture", "plus_pic", 0, 3, 15, 15)
            AUTO_CAST(plus_pic)
            plus_pic:SetEventScript(ui.LBUTTONUP, "Always_status_frame_toggle")
            plus_pic:SetImage("btn_plus")
            plus_pic:SetTextTooltip(tooltip)
            plus_pic:SetEnableStretch(1)
            always_status:Resize(150, 20)
            always_status:ShowWindow(1)
            return
        else
            local minus_pic = always_status:CreateOrGetControl("picture", "minus_pic", 0, 3, 15, 15)
            AUTO_CAST(minus_pic)
            minus_pic:SetEventScript(ui.LBUTTONUP, "Always_status_frame_toggle")
            minus_pic:SetImage("btn_minus")
            minus_pic:SetTextTooltip(tooltip)
            minus_pic:SetEnableStretch(1)
            local y = 20
            local pc = GetMyPCObject()
            local use_set_str = tostring(char.use_set)
            for _, data in ipairs(always_status_master_list) do
                local status = data.key
                local display = g.always_status_settings[use_set_str]
                if display and display[status] == 1 then
                    local color = g.always_status_settings["base"]["color"][status]
                    local title = always_status:CreateOrGetControl("richtext", "title" .. status, 10, y)
                    AUTO_CAST(title)
                    local stat = always_status:CreateOrGetControl("richtext", "stat" .. status, 165, y)
                    AUTO_CAST(stat)
                    local title_text = ""
                    local abbr_text = g.always_status_settings.base.abbr and g.always_status_settings.base.abbr[status]
                    if abbr_text and abbr_text ~= "" and abbr_text ~= status then
                        title_text = abbr_text
                    else
                        local message_id = ""
                        if status == "gear_score" then
                            message_id = "EquipedItemGearScore"
                            title_text = ScpArgMsg(message_id)
                        elseif status == "ability_point_score" then
                            message_id = "AbilityPointScore"
                            title_text = ScpArgMsg(message_id)
                        elseif status == "STR" or status == "INT" or status == "CON" or status == "MNA" or status ==
                            "DEX" then
                            title_text = ClMsg(status)
                        else
                            message_id = status
                            title_text = ScpArgMsg(message_id)
                        end
                        local match_result = string.match(title_text, "!@#%$([^#]+)")
                        if match_result then
                            title_text = dic.getTranslatedStr(ClMsg(match_result))
                        end
                        if g.lang == "Japanese" and data.jp then
                            title_text = data.jp
                        end
                    end
                    title:SetText("{ol}{s16}" .. color .. title_text)
                    local text = Always_status_get_status_text(pc, status)
                    if string.find(text, "~") == nil and string.find(text, "%%") == nil then
                        local pure_number_str = text:gsub("[^0-9]", "")
                        if #pure_number_str > 0 then
                            text = pure_number_str
                        else
                            text = "0"
                        end
                    end
                    stat:SetText(color .. "{ol}{s16}: " .. text)
                    if g.lang == "Japanese" then
                        stat:SetPos(125, y)
                    end
                    title:AdjustFontSizeByWidth(150)
                    if g.lang ~= "Japanese" then
                        stat:AdjustFontSizeByWidth(135)
                    end
                    y = y + 20
                end
            end
            if g.lang == "Japanese" then
                always_status:Resize(260, y + 10)
            else
                always_status:Resize(310, y + 10)
            end
            always_status:ShowWindow(1)
            always_status:RunUpdateScript("Always_status_update", 0.1)
        end
    end
    local result, err = pcall(_logic)
    if not result then
        local always_status = ui.GetFrame(addon_name_lower .. "always_status")
        always_status:RunUpdateScript("Always_status_frame_init", 0.5)
    end
end

function Always_status_update(always_status)
    local pc = GetMyPCObject()
    if pc == nil then
        return 1
    end
    for _, data in ipairs(always_status_master_list) do
        local status = data.key
        local always_status_stat = GET_CHILD_RECURSIVELY(always_status, "stat" .. status)
        if always_status_stat then
            local text = Always_status_get_status_text(pc, status)
            if string.find(text, "~") == nil and string.find(text, "%%") == nil then
                local pure_number_str = text:gsub("[^0-9]", "")
                if #pure_number_str > 0 then
                    text = pure_number_str
                else
                    text = "0"
                end
            end
            local color = g.always_status_settings["base"]["color"][status]
            always_status_stat:SetText(color .. "{ol}{s16}: " .. text)
        end
    end
    local base = g.always_status_settings["base"]
    if base.frame_X ~= 0 and base.frame_Y ~= 0 then
        always_status:SetPos(base.frame_X, base.frame_Y)
    end
    return 1
end

function Always_status_frame_move(always_status)
    g.always_status_settings["base"].frame_X = always_status:GetX()
    g.always_status_settings["base"].frame_Y = always_status:GetY()
    Always_status_save_settings()
end

function Always_status_info_setting()
    local settings_frame = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "always_status_settings", 0, 0, 70, 30)
    AUTO_CAST(settings_frame)
    settings_frame:EnableHittestFrame(1)
    settings_frame:EnableHitTest(1)
    settings_frame:Resize(555, 900)
    local list_frame = ui.GetFrame(addon_name_lower .. "list_frame")
    if list_frame then
        settings_frame:SetPos(list_frame:GetX() + list_frame:GetWidth(), list_frame:GetY())
    else
        settings_frame:SetPos(1220, 100)
    end
    settings_frame:SetLayerLevel(999)
    settings_frame:RemoveAllChild()
    local gb = settings_frame:CreateOrGetControl("groupbox", "gb", 10, 10, settings_frame:GetWidth() - 10,
        settings_frame:GetHeight() - 10)
    AUTO_CAST(gb)
    gb:SetSkinName("test_frame_low")
    local title = gb:CreateOrGetControl("richtext", "title", 30, 40)
    AUTO_CAST(title)
    local text = g.lang == "Japanese" and "{ol}表示設定" or "{ol}Display Setting"
    title:SetText("{s18}{ol}{#FFFFFF}" .. text)
    local close = gb:CreateOrGetControl("button", "close", 0, 0, 20, 20)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Always_status_frame_close")
    local drop_list = gb:CreateOrGetControl('droplist', 'setting_DropList', 100, 10, 200, 20)
    AUTO_CAST(drop_list)
    drop_list:SetSkinName('droplist_normal')
    drop_list:EnableHitTest(1)
    drop_list:SetTextAlign("center", "center")
    for i = 1, 10 do
        local display = g.always_status_settings[tostring(i)]
        local scp = "Always_status_info_setting_load(" .. i .. ")"
        if display.memo == "free memo " .. i then
            drop_list:AddItem(i - 1, tostring("Data ") .. i, 0, scp)
        else
            drop_list:AddItem(i - 1, display.memo, 0, scp)
        end
    end
    local use_set = tonumber(g.always_status_settings["chars"][g.cid].use_set)
    drop_list:SelectItem(use_set - 1)
    local base_pos = gb:CreateOrGetControl('button', 'base_pos', 350, 5, 120, 30)
    AUTO_CAST(base_pos)
    base_pos:SetText(g.lang == "Japanese" and "{ol}フレーム初期位置" or "{ol}Init frame pos")
    base_pos:SetEventScript(ui.LBUTTONUP, "Always_status_init_pos")
    local reset_abbr_btn = gb:CreateOrGetControl('button', 'reset_abbr_btn', 350, 35, 120, 30)
    AUTO_CAST(reset_abbr_btn)
    reset_abbr_btn:SetText(g.lang == "Japanese" and "{ol}表示名リセット" or "{ol}Reset Names")
    reset_abbr_btn:SetEventScript(ui.LBUTTONUP, "Always_status_reset_all_abbr")
    reset_abbr_btn:SetTextTooltip(g.lang == "Japanese" and
                                      "{ol}全ての項目の表示名カスタマイズを初期化します" or
                                      "{ol}Reset all custom display names")
    local memo = gb:CreateOrGetControl('edit', 'memo', 215, 35, 130, 30) -- 幅を少し調整
    AUTO_CAST(memo)
    memo:SetEventScript(ui.ENTERKEY, "Always_status_memo_save")
    memo:SetEventScriptArgNumber(ui.ENTERKEY, use_set)
    memo:SetFontName("white_16_ol")
    memo:SetTextAlign("center", "center")
    local enable_check = gb:CreateOrGetControl("checkbox", "enablecheck", 510, 40, 20, 20)
    AUTO_CAST(enable_check)
    enable_check:SetEventScript(ui.LBUTTONUP, "Always_status_checkbox")
    text = g.lang == "Japanese" and "{ol}チェックするとフレームが固定されます" or
               "{ol}If checked, the frame is fixed"
    enable_check:SetTextTooltip(text)
    local base = g.always_status_settings["base"]
    if base.enable == 0 then
        enable_check:SetCheck(1)
    else
        enable_check:SetCheck(0)
    end
    settings_frame:ShowWindow(1)
    Always_status_info_setting_load(use_set)
end

function Always_status_init_pos()
    g.always_status_settings["base"].frame_X = 0
    g.always_status_settings["base"].frame_Y = 0
    Always_status_save_settings()
    ui.DestroyFrame(addon_name_lower .. "always_status")
    ReserveScript("Always_status_frame_init()", 0.1)
end

function Always_status_info_setting_load(use_set)
    local settings_frame = ui.GetFrame(addon_name_lower .. "always_status_settings")
    local gb = GET_CHILD_RECURSIVELY(settings_frame, "gb")
    AUTO_CAST(gb)
    local old_setting_gb = GET_CHILD(gb, "setting_gb")
    if old_setting_gb then
        gb:RemoveChild("setting_gb")
    end
    local setting_gb = gb:CreateOrGetControl("groupbox", "setting_gb", 10, 70, gb:GetWidth() - 20, gb:GetHeight() - 80)
    AUTO_CAST(setting_gb)
    setting_gb:SetSkinName("test_frame_midle_light")
    local display = g.always_status_settings[tostring(use_set)]
    local memo = GET_CHILD_RECURSIVELY(settings_frame, "memo")
    if memo then
        AUTO_CAST(memo)
        memo:SetText(display.memo)
        memo:SetEventScriptArgNumber(ui.ENTERKEY, use_set) -- メモ保存先のセット番号も更新
    end
    settings_frame:SetLayerLevel(999)
    local y = 10
    for _, data in ipairs(always_status_master_list) do
        local status = data.key
        local check = setting_gb:CreateOrGetControl("checkbox", "check" .. status, 475, y, 20, 20)
        AUTO_CAST(check)
        check:SetEventScript(ui.LBUTTONUP, "Always_status_checkbox")
        check:SetEventScriptArgString(ui.LBUTTONUP, status)
        check:SetEventScriptArgNumber(ui.LBUTTONUP, use_set)
        check:SetCheck(display[status])
        local color_box = setting_gb:CreateOrGetControl('groupbox', "colorbox" .. status, 250, y, 220, 20)
        AUTO_CAST(color_box)
        local color_table = {"FFFFFF", "FF6600", "FF4040", '66B3FF', "00FFFF", '00FF00', 'FF0000', 'FF00FF', "A566FF",
                             'FFFF00', "ADFF2F"}
        for j = 1, 11 do
            local color_str = color_table[j]
            local color_pic = color_box:CreateOrGetControl("picture", "color" .. j, 20 * (j - 1), 0, 20, 20)
            AUTO_CAST(color_pic)
            color_pic:SetImage("chat_color")
            color_pic:SetColorTone("FF" .. color_str)
            color_pic:SetEventScript(ui.LBUTTONUP, "Always_status_color_select")
            color_pic:SetEventScriptArgString(ui.LBUTTONUP, color_str)
        end
        local control = setting_gb:CreateOrGetControl("richtext", status, 20, y)
        AUTO_CAST(control)
        control:SetEventScript(ui.LBUTTONUP, "Always_status_open_abbr_input")
        control:SetEventScriptArgString(ui.LBUTTONUP, status)
        control:SetTextTooltip(g.lang == "Japanese" and "{ol}左クリックで表示名変更" or "{ol}L-Click: rename")
        local color = g.always_status_settings["base"]["color"][status]
        local display_text = ""
        local saved_abbr = g.always_status_settings.base.abbr and g.always_status_settings.base.abbr[status]
        if saved_abbr and saved_abbr ~= "" and saved_abbr ~= status then
            display_text = saved_abbr
        else
            if status == "STR" or status == "INT" or status == "CON" or status == "MNA" or status == "DEX" then
                display_text = ClMsg(status)
            elseif status == "gear_score" then
                display_text = ScpArgMsg("EquipedItemGearScore")
            elseif status == "ability_point_score" then
                display_text = ScpArgMsg("AbilityPointScore")
            else
                display_text = ScpArgMsg(status)
            end
        end
        control:SetText(color .. "{s16}{ol}" .. display_text)
        control:AdjustFontSizeByWidth(250)
        y = y + 25
    end
    g.always_status_settings["chars"][g.cid].use_set = use_set
    Always_status_save_settings()
    Always_status_frame_init()
end

function Always_status_reset_all_abbr(frame, ctrl)
    local yes_scp = "Always_status_reset_all_abbr_exec()"
    local msg = g.lang == "Japanese" and "全ての表示名を初期化しますか？" or "Reset all display names?"
    ui.MsgBox(msg, yes_scp, "None")
end

function Always_status_reset_all_abbr_exec()
    g.always_status_settings.base.abbr = {}
    Always_status_save_settings()
    local use_set = g.always_status_settings["chars"][g.cid].use_set
    Always_status_info_setting_load(use_set)
    ui.SysMsg(g.lang == "Japanese" and "表示名をリセットしました" or "Display names reset")
end

function Always_status_open_abbr_input(frame, ctrl, status, num)
    local settings_frame = ui.GetFrame(addon_name_lower .. "always_status_settings")
    settings_frame:SetUserValue("TARGET_STATUS", status)
    settings_frame:SetLayerLevel(97)
    local current_abbr = g.always_status_settings.base.abbr[status] or ""
    Always_status_INPUT_STRING_BOX(frame, ctrl, current_abbr, num)
    -- INPUT_STRING_BOX(title, "Always_status_save_abbr", current_abbr, 0, 0)
end

function Always_status_INPUT_STRING_BOX(frame, ctrl, current_abbr, num)
    local inputstring = ui.GetFrame("inputstring")
    inputstring:Resize(500, 220)
    inputstring:SetLayerLevel(999)
    local edit = GET_CHILD(inputstring, 'input', "ui::CEditControl")
    edit:SetNumberMode(0)
    edit:SetMaxLen(999)
    edit:SetText("")
    inputstring:ShowWindow(1)
    inputstring:SetEnable(1)
    local title = inputstring:GetChild("title")
    AUTO_CAST(title)
    local text = g.lang == "Japanese" and "{ol}{#FFFFFF}表示名を入力してください" or
                     "{ol}{#FFFFFF}Enter display name"
    title:SetText(text)
    local confirm = inputstring:GetChild("confirm")
    confirm:SetEventScript(ui.LBUTTONUP, "Always_status_save_abbr")
    -- confirm:SetEventScriptArgString(ui.LBUTTONUP, ctrl_name)
    edit:SetEventScript(ui.ENTERKEY, "Always_status_save_abbr")
    -- edit:SetEventScriptArgString(ui.ENTERKEY, ctrl_name)
    edit:AcquireFocus()
end

function Always_status_save_abbr(frame, ctrl)
    if frame:GetName() == "inputstring" then
        local input_text = GET_INPUT_STRING_TXT(frame)
        local settings_frame = ui.GetFrame(addon_name_lower .. "always_status_settings")
        local status = settings_frame:GetUserValue("TARGET_STATUS")
        if status and status ~= "None" then
            if not g.always_status_settings.base.abbr then
                g.always_status_settings.base.abbr = {}
            end
            g.always_status_settings.base.abbr[status] = input_text
            Always_status_save_settings()
            local use_set = g.always_status_settings["chars"][g.cid].use_set
            Always_status_info_setting_load(use_set)
            frame:ShowWindow(0)
        end
    end
end

function Always_status_frame_toggle(frame, ctrl)
    if g.always_status_settings["chars"][g.cid].on == 1 then
        g.always_status_settings["chars"][g.cid].on = 0
    else
        g.always_status_settings["chars"][g.cid].on = 1
    end
    Always_status_save_settings()
    Always_status_frame_init()
end

function Always_status_frame_close()
    local settings_frame = ui.GetFrame(addon_name_lower .. "always_status_settings")
    if settings_frame then
        ui.DestroyFrame(settings_frame:GetName())
    end
end

function Always_status_memo_save(frame, ctrl, str, use_set)
    local text = ctrl:GetText()
    g.always_status_settings[tostring(use_set)].memo = text
    ui.SysMsg(g.lang == "Japanese" and "タイトルを変更しました" or "The title has been changed")
    Always_status_save_settings()
    Always_status_info_setting()
end

function Always_status_checkbox(frame, ctrl, status, use_set)
    local is_check = ctrl:IsChecked()
    local name = ctrl:GetName()
    if name == "enablecheck" then
        local always_status = ui.GetFrame(addon_name_lower .. "always_status")
        if is_check == 1 then
            g.always_status_settings["base"].enable = 0
            always_status:EnableMove(0)
        else
            g.always_status_settings["base"].enable = 1
            always_status:EnableMove(1)
        end
    else
        g.always_status_settings[tostring(use_set)][status] = is_check
    end
    Always_status_save_settings()
    Always_status_frame_init()
    -- always_status_info_setting_load(use_set)
end

function Always_status_color_select(parent, ctrl, color_str, num)
    local status_name = string.gsub(parent:GetName(), "colorbox", "")
    g.always_status_settings["base"]["color"][status_name] = "{#" .. color_str .. "}"
    Always_status_save_settings()
    Always_status_info_setting()
    Always_status_frame_init()
end
-- always_status ここまで

