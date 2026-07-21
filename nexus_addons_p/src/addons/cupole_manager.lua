-- Cupole Manager ここから
function Cupole_manager_save_settings()
    g.save_json(g.cupole_manager_path, g.cupole_manager_settings)
end

function Cupole_manager_load_settings()
    g.cupole_manager_path = string.format("../addons/%s/%s/cupole_manager.json", addon_name_lower, g.active_id)
    g.cupole_manager_old_path = string.format("../addons/%s/%s/settings.json", "cupole_manager", g.active_id)
    local changed = false
    local settings = g.load_json(g.cupole_manager_path)
    if not settings then
        local old_settings = g.load_json(g.cupole_manager_old_path)
        settings = {}
        if old_settings then
            for key, value in pairs(old_settings) do
                if tonumber(key) and string.len(key) > 3 then
                    settings[key] = value
                end
            end
        end
        changed = true
    end
    if not settings.default then
        settings.default = {}
        changed = true
    end
    g.cupole_manager_settings = settings
    if changed then
        Cupole_manager_save_settings()
    end
end

function cupole_manager_on_init()
    if not g.cupole_manager_settings then
        Cupole_manager_load_settings()
    end
    local old_func = g.settings.cupole_manager.old_init_func
    if _G[old_func] then
        return
    end
    if not g.cupole_manager_settings[g.cid] then
        g.cupole_manager_settings[g.cid] = {}
        Cupole_manager_save_settings()
    end
    if g.get_map_type() == "City" then
        local equip_cupole_list = GET_EQUIP_CUPOLE_LIST()
        for i = 1, 3 do
            if equip_cupole_list[i] == "-1" then
                Cupole_manager_SET_CUPOLE_SLOTS()
                break
            end
        end
        g.setup_hook_and_event(g.addon, "CLOSE_CUPOLE_ITEM", "Cupole_manager_CLOSE_CUPOLE_ITEM", true)
        g.setup_hook_and_event(g.addon, "OPEN_CUPOLE_ITEM", "Cupole_manager_OPEN_CUPOLE_ITEM", true)
    end
end

function Cupole_manager_OPEN_CUPOLE_ITEM()
    if g.settings.cupole_manager.use == 0 then
        return
    end
    local cupole_item = ui.GetFrame("cupole_item")
    if not cupole_item then
        return
    end
    local manageBG = GET_CHILD_RECURSIVELY(cupole_item, "manageBG")
    local save_btn = manageBG:CreateOrGetControl("button", "save_btn", 1400, 730, 135, 45)
    AUTO_CAST(save_btn)
    save_btn:SetSkinName("cupole_border_btn")
    save_btn:SetText(g.lang == "Japanese" and "{ol}{s15}デフォルト変更" or "{ol}{s15}Change Default")
    save_btn:SetTextTooltip(g.lang == "Japanese" and "{ol}現在のセットをデフォルトに変更します" or
                                "{ol}Change the current set to the default")
    save_btn:SetEventScript(ui.LBUTTONUP, "Cupole_manager_save_default_settings")
end

function Cupole_manager_CLOSE_CUPOLE_ITEM(parent, ctrl)
    if g.settings.cupole_manager.use == 0 then
        return
    end
    local equip_cupole_list = GET_EQUIP_CUPOLE_LIST()
    for i = 1, 3 do
        local cupole_cls = GET_CUPOLE_BY_INDEX_IN_CLASSLIST(equip_cupole_list[i])
        local cupole_class_name = TryGetProp(cupole_cls, "ClassName", "None")
        if equip_cupole_list[i] ~= "-1" then
            g.cupole_manager_settings[g.cid][tostring(i)] = {
                id = equip_cupole_list[i],
                name = cupole_class_name
            }
            if not g.cupole_manager_settings["default"][tostring(i)] then
                g.cupole_manager_settings["default"][tostring(i)] = {
                    id = equip_cupole_list[i],
                    name = cupole_class_name
                }
            end
        end
    end
    Cupole_manager_save_settings()
end

function Cupole_manager_save_default_settings()
    local equip_cupole_list = GET_EQUIP_CUPOLE_LIST()
    for i = 1, 3 do
        if equip_cupole_list[i] == "-1" then
            ui.SysMsg(g.lang == "Japanese" and "クポルが3体登録されていません" or
                          "3 Cupoles are not registered")
            return
        end
    end
    for i = 1, 3 do
        local cupole_cls = GET_CUPOLE_BY_INDEX_IN_CLASSLIST(equip_cupole_list[i])
        local cupole_class_name = TryGetProp(cupole_cls, "ClassName", "None")
        g.cupole_manager_settings["default"][tostring(i)] = {
            id = equip_cupole_list[i],
            name = cupole_class_name
        }
    end
    Cupole_manager_save_settings()
    ui.SysMsg(g.lang == "Japanese" and "現在のセットをデフォルトとして保存しました" or
                  "Saved the current set as default")
end

function Cupole_manager_SET_CUPOLE_SLOTS(frame)
    if g.settings.cupole_manager.use == 0 then
        return
    end
    local frame = ui.GetFrame("cupole_item")
    local bg = GET_CHILD_RECURSIVELY_NAME(frame, "managerTab/manageBG/bg")
    local function is_valid_set(settings)
        if not settings or not settings["1"] or not settings["2"] or not settings["3"] then
            return false
        end
        if settings["1"].id == "-1" or settings["2"].id == "-1" or settings["3"].id == "-1" then
            return false
        end
        return true
    end
    local cid_settings = g.cupole_manager_settings[g.cid]
    local default_settings = g.cupole_manager_settings["default"]
    if is_valid_set(cid_settings) then
        g.cupole_manager_tbl = cid_settings
    else
        if is_valid_set(default_settings) then
            if next(cid_settings) then
                ui.SysMsg(g.lang == "Japanese" and "デフォルトのクポルセットを適用します" or
                              "Applying the default Cupole set")
            end
            g.cupole_manager_tbl = default_settings
        else
            ui.SysMsg(g.lang == "Japanese" and "デフォルトのクポルセット未登録" or
                          "Default Cupole set is not registered")
            return
        end
    end
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    g.cupole_manager_num = 0
    _nexus_addons_p:RunUpdateScript("Cupole_manager_summon_cupole", 1.0)
end

function Cupole_manager_summon_cupole(_nexus_addons_p)
    if g.cupole_manager_num == 3 then
        _nexus_addons_p:StopUpdateScript("Cupole_manager_summon_cupole")
        return 0
    end
    SummonCupole(tonumber(g.cupole_manager_tbl[tostring(g.cupole_manager_num + 1)].id), g.cupole_manager_num)
    g.cupole_manager_num = g.cupole_manager_num + 1
    return 1
end
-- Cupole Manager ここまで

