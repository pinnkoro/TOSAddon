-- cc_helper ここから
g.cc_helper_item_keys = {"seal", "ark", "leg", "god", "hair1", "hair2", "hair3", "gem1", "gem2", "gem3", "gem4", "pet",
                         "core", "relic"}
function Cc_helper_save_settings()
    g.save_lua(g.cc_helper_path, g.cc_helper_settings)
end

g.cc_helper_set_count = 3

-- Ensure the multi-set structure exists and keep char_data.items as a live
-- alias to the currently selected set's items (minimizes changes elsewhere).
function Cc_helper_ensure_sets(char_data)
    if not char_data.sets then
        char_data.sets = {}
        -- migrate legacy single-set data into set 1
        if char_data.items and next(char_data.items) then
            char_data.sets[1] = {
                items = char_data.items
            }
        end
    end
    for s = 1, g.cc_helper_set_count do
        if not char_data.sets[s] then
            char_data.sets[s] = {
                items = {}
            }
        end
        if not char_data.sets[s].items then
            char_data.sets[s].items = {}
        end
        for _, key in ipairs(g.cc_helper_item_keys) do
            if not char_data.sets[s].items[key] then
                char_data.sets[s].items[key] = {
                    iesid = "",
                    clsid = 0,
                    option = "",
                    rank = "",
                    image = ""
                }
            end
        end
    end
    if not char_data.current or char_data.current < 1 or char_data.current > g.cc_helper_set_count then
        char_data.current = 1
    end
    -- live alias so existing `[cid].items` reads/writes target the current set
    char_data.items = char_data.sets[char_data.current].items
end

function Cc_helper_missing_char_data(char_data)
    char_data.agm = char_data.agm or 0
    char_data.agm_check = char_data.agm_check or 0
    char_data.mcc = char_data.mcc or 0
    if not char_data.name then
        char_data.name = "Unknown"
    end
    Cc_helper_ensure_sets(char_data)
end

function Cc_helper_load_settings()
    g.cc_helper_path = string.format("../addons/%s/%s/cc_helper.lua", addon_name_lower, g.active_id)
    local json_path = string.format("../addons/%s/%s/cc_helper.json", addon_name_lower, g.active_id)
    local settings = g.load_lua(g.cc_helper_path)
    local need_save = false
    local ver = 1.3
    if not settings then
        settings = g.load_json(json_path)
        if settings then
            need_save = true -- JSONから移行したので保存が必要
        end
    end
    if not settings then
        settings = {
            etc = {
                eco = 0,
                agm_stop = 0,
                wh_close = 0,
                copys = {}
            },
            ver = ver
        }
        local old_copy_path = string.format("../addons/%s/%s/%s_copy.json", "cc_helper", g.active_id, g.active_id)
        local copy_settings = g.load_json(old_copy_path)
        if copy_settings then
            local item_key_map = {}
            for _, key in ipairs(g.cc_helper_item_keys) do
                item_key_map[key] = true
            end
            for cid, char_data in pairs(copy_settings) do
                if type(char_data) == "table" and next(char_data) then
                    if not settings.etc.copys[cid] then
                        settings.etc.copys[cid] = {
                            items = {}
                        }
                    end
                    for key, value in pairs(char_data) do
                        if type(value) == "table" then
                            if item_key_map[key] then
                                settings.etc.copys[cid].items[key] = {}
                                for k, v in pairs(value) do
                                    if k == "memo" then
                                        local result = StringSplit(v, ":::")
                                        if #result > 0 then
                                            if string.find(key, "hair") then
                                                settings.etc.copys[cid].items[key].rank = result[#result]
                                                table.remove(result, #result)
                                                settings.etc.copys[cid].items[key].option = table.concat(result, ":::")
                                            elseif key == "pet" then
                                                settings.etc.copys[cid].items[key].option = result[#result]
                                            end
                                        end
                                    elseif k ~= "skin" then
                                        settings.etc.copys[cid].items[key][k] = v
                                    end
                                end
                            end
                        else
                            settings.etc.copys[cid][key] = value
                        end
                    end
                    Cc_helper_missing_char_data(settings.etc.copys[cid])
                end
            end
        end
        need_save = true
    end
    if not settings.ver or settings.ver < ver then
        settings.ver = ver
        need_save = true
    end
    if not settings.etc then
        settings.etc = {}
    end
    if settings.etc.eco == nil then
        settings.etc.eco = 0
    end
    if settings.etc.agm_stop == nil then
        settings.etc.agm_stop = 0
    end
    if settings.etc.wh_close == nil then
        settings.etc.wh_close = 0
    end
    if not settings.etc.copys then
        settings.etc.copys = {}
    end
    for key, val in pairs(settings) do
        if tonumber(key) and type(val) == "table" then
            Cc_helper_missing_char_data(val)
        end
    end
    -- normalize copy sources to single-set entries keyed as "<cid>_set<N>".
    -- legacy entries (plain cid key, no setnum, possibly whole-char with .sets)
    -- are collapsed to one item set and re-keyed under "<cid>_set1".
    local copys = settings.etc.copys
    local legacy_keys = {}
    for k, val in pairs(copys) do
        if type(val) == "table" then
            if not val.setnum then
                -- legacy: derive a single item set, drop multi-set structure
                if not val.items or not next(val.items) then
                    if val.sets then
                        local sc = val.current or 1
                        local sset = val.sets[sc] or val.sets[1]
                        val.items = (sset and sset.items) or {}
                    end
                end
                val.items = val.items or {}
                val.sets = nil
                val.current = nil
                val.setnum = 1
                if not string.find(tostring(k), "_set") then
                    legacy_keys[#legacy_keys + 1] = k
                end
            else
                -- new-format entry: keep it single-set (drop any stale .sets)
                val.sets = nil
                val.current = nil
                val.items = val.items or {}
            end
        end
    end
    for _, k in ipairs(legacy_keys) do
        local newk = tostring(k) .. "_set1"
        if not copys[newk] then
            -- 移行先が未使用のときだけ再キーして旧キーを削除する。
            -- 既に "<cid>_set1" が存在する場合は旧エントリを消すと衝突で
            -- データを失うため、そのまま残す。
            copys[newk] = copys[k]
            copys[k] = nil
            need_save = true
        end
    end
    g.cc_helper_settings = settings
    if need_save then
        Cc_helper_save_settings()
    end
end

function Cc_helper_char_load_settings()
    local settings = g.cc_helper_settings
    if not settings[g.cid] then
        settings[g.cid] = {
            agm = 0,
            agm_check = 0,
            mcc = 0,
            items = {},
            name = g.login_name
        }
    end
    Cc_helper_missing_char_data(settings[g.cid])
    Cc_helper_save_settings()
end

function Cc_helper_ensure_settings_loaded()
    if not g.cc_helper_settings then
        Cc_helper_load_settings()
    end
    if not g.cc_helper_settings[g.cid] then
        Cc_helper_char_load_settings()
    end
end

-- Switch the active equipment set (re-points the items alias) and persist.
function Cc_helper_switch_set(n)
    local cd = g.cc_helper_settings and g.cc_helper_settings[g.cid]
    if not cd then
        return
    end
    Cc_helper_ensure_sets(cd) -- sets/current/items alias が無いキャラでも安全に
    if n < 1 or n > g.cc_helper_set_count then
        n = 1
    end
    cd.current = n
    cd.items = cd.sets[n].items
    Cc_helper_save_settings()
end

-- Right-click on the "take out (equip)" button: choose which set to equip.
function Cc_helper_take_item_context(frame, ctrl)
    local title = g.lang == "Japanese" and "{ol}セット選択" or "{ol}Select Set"
    local context = ui.CreateContextMenu("cc_helper_set_context", title, 0, 0, 0, 0)
    local cd = g.cc_helper_settings and g.cc_helper_settings[g.cid]
    if not cd then
        return
    end
    Cc_helper_ensure_sets(cd) -- current/sets が未構築でも nil index を避ける
    local cur = cd.current or 1
    for n = 1, g.cc_helper_set_count do
        local mark = (n == cur) and " {#00FF00}<<" or ""
        local text = string.format("{ol}Set %d%s", n, mark)
        ui.AddContextMenuItem(context, text, string.format("Cc_helper_take_item_set(%d)", n))
    end
    ui.OpenContextMenu(context)
end

-- Switch to set n, then run the normal equip (take from warehouse) flow.
function Cc_helper_take_item_set(n)
    Cc_helper_switch_set(n)
    local cch_setting = ui.GetFrame(addon_name_lower .. "cch_setting")
    if cch_setting and cch_setting:IsVisible() == 1 then
        Cc_helper_setting_frame_init()
    end
    local out_btn = GET_CHILD(ui.GetFrame("accountwarehouse"), "cch_out_btn")
    if not out_btn or out_btn:IsVisible() == 0 then
        out_btn = GET_CHILD(ui.GetFrame("inventory"), "cch_out_btn")
    end
    if out_btn then
        Cc_helper_take_item(nil, out_btn, nil, 0)
    end
end

-- Set tab in the config frame: switch active set and refresh the slots.
function Cc_helper_setting_switch_set(frame, ctrl, argstr, n)
    Cc_helper_switch_set(n)
    Cc_helper_setting_frame_init()
end

-- Config-frame "Store" button: unequip current set and deposit to warehouse.
-- Reuses the warehouse in_btn control so the async operation survives.
function Cc_helper_setting_deposit()
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    if not accountwarehouse or accountwarehouse:IsVisible() == 0 then
        ui.SysMsg(g.lang == "Japanese" and "倉庫を開いてください" or "Open the warehouse first")
        return
    end
    local in_btn = GET_CHILD(accountwarehouse, "cch_in_btn")
    if in_btn then
        Cc_helper_putitem(nil, in_btn, nil, 0)
    end
end

-- Config-frame "Equip" button: equip the currently shown set from the warehouse.
function Cc_helper_setting_equip()
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    if not accountwarehouse or accountwarehouse:IsVisible() == 0 then
        ui.SysMsg(g.lang == "Japanese" and "倉庫を開いてください" or "Open the warehouse first")
        return
    end
    local out_btn = GET_CHILD(accountwarehouse, "cch_out_btn")
    if out_btn then
        Cc_helper_take_item(nil, out_btn, nil, 0)
    end
end

function cc_helper_on_init()
    Cc_helper_ensure_settings_loaded()
    g.setup_hook_and_event(g.addon, "INVENTORY_OPEN", "Cc_helper_INVENTORY_OPEN", true)
    g.setup_hook_and_event(g.addon, "ACCOUNTWAREHOUSE_CLOSE", "Cc_helper_ACCOUNTWAREHOUSE_CLOSE", true)
    g.setup_hook_and_event(g.addon, "INVENTORY_CLOSE", "Cc_helper_INVENTORY_CLOSE", true)
    if g.get_map_type() == "City" then
        Cc_helper_frame_init()
        g.addon:RegisterMsg("OPEN_DLG_ACCOUNTWAREHOUSE", "Cc_helper_frame_init")
    end
    if g.settings.cc_helper.use == 0 then
        Cc_helper_ACCOUNTWAREHOUSE_CLOSE(nil, nil)
        return
    end
end

function Cc_helper_ACCOUNTWAREHOUSE_CLOSE(my_frame, my_msg)
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    accountwarehouse:RemoveChild("cch_in_btn")
    accountwarehouse:RemoveChild("cch_out_btn")
    accountwarehouse:RemoveChild("cch_auto_close")
    local inventory = ui.GetFrame("inventory")
    inventory:RemoveChild("cch_in_btn") -- "setting"
    inventory:RemoveChild("cch_out_btn")
    inventory:RemoveChild("cch_setting")
    local cch_setting = ui.GetFrame(addon_name_lower .. "cch_setting")
    if cch_setting then
        Cc_helper_setting_frame_close(cch_setting)
    end
end

function Cc_helper_INVENTORY_OPEN(my_frame, my_msg)
    if g.settings.cc_helper.use == 0 then
        return
    end
    local inventory = ui.GetFrame("inventory")
    inventory:SetUserValue("CCH_BTN_RETRY", 0)
    inventory:RunUpdateScript("Cc_helper_inventory_btn_init_delayed", 0.1)
end

function Cc_helper_inventory_btn_init_delayed(inventory)
    local in_btn = GET_CHILD(inventory, "cch_in_btn")
    if in_btn then
        return 0
    end
    if inventory:IsVisible() == 1 then
        Cc_helper_frame_init()
        return 0
    end
    local retry = inventory:GetUserIValue("CCH_BTN_RETRY")
    if retry > 10 then
        return 0
    end
    inventory:SetUserValue("CCH_BTN_RETRY", retry + 1)
    return 1
end

function Cc_helper_INVENTORY_CLOSE()
    local cch_setting = ui.GetFrame(addon_name_lower .. "cch_setting")
    if cch_setting then
        Cc_helper_setting_frame_close(cch_setting)
    end
end

function Cc_helper_frame_init()
    if g.settings.cc_helper.use == 0 then
        return
    end
    Cc_helper_accountwarehouse_btn_init()
    Cc_helper_inventory_btn_init()
end

function Cc_helper_accountwarehouse_btn_init()
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    local in_btn = accountwarehouse:CreateOrGetControl("button", "cch_in_btn", 565, 120, 30, 30)
    AUTO_CAST(in_btn)
    in_btn:SetText("{img in_arrow 20 20}")
    in_btn:SetEventScript(ui.LBUTTONUP, "Cc_helper_putitem")
    in_btn:SetSkinName("test_pvp_btn")
    in_btn:SetTextTooltip(g.lang == "Japanese" and "{ol}[CCH]{nl}装備を外して倉庫へ搬入します" or
                              "{ol}[CCH]{nl}The equipment is removed{nl}and brought into the warehouse")
    in_btn:ShowWindow(1)
    local out_btn = accountwarehouse:CreateOrGetControl("button", "cch_out_btn", 595, 120, 30, 30)
    AUTO_CAST(out_btn)
    out_btn:SetText("{@st66b}{img chul_arrow 20 20}")
    out_btn:SetEventScript(ui.LBUTTONUP, "Cc_helper_take_item")
    out_btn:SetEventScript(ui.RBUTTONUP, "Cc_helper_take_item_context")
    out_btn:SetSkinName("test_pvp_btn")
    out_btn:SetTextTooltip(g.lang == "Japanese" and
                               "{ol}[CCH]{nl}倉庫から搬出して装備します{nl}左クリック: 現在のセット / 右クリック: セット選択" or
                               "{ol}[CCH]{nl}It is carried out from the warehouse and equipped{nl}Left: current set / Right: choose set")
    out_btn:ShowWindow(1)
    local auto_close = accountwarehouse:CreateOrGetControl("checkbox", "cch_auto_close", 540, 120, 30, 30)
    AUTO_CAST(auto_close)
    auto_close:ShowWindow(1)
    auto_close:SetTextTooltip(g.lang == "Japanese" and
                                  "{ol}[CCH]{nl}動作終了後倉庫とインベントリーを閉じます" or
                                  "{ol}[CCH]{nl}Closes storage and inventory after the operation is complete")
    auto_close:SetEventScript(ui.LBUTTONUP, "Cc_helper_check_settings")
    auto_close:SetCheck(g.cc_helper_settings.etc.wh_close)
    auto_close:ShowWindow(1)
end

function Cc_helper_inventory_btn_init()
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
    local setting = inventory:CreateOrGetControl("button", "cch_setting", 205, 345, 30, 30)
    AUTO_CAST(setting)
    setting:SetSkinName("None")
    setting:SetText("{img config_button_normal 30 30}")
    setting:SetEventScript(ui.LBUTTONUP, "Cc_helper_setting_frame_init")
    setting:SetEventScript(ui.RBUTTONUP, "Cc_helper_toggle_settings")
    setting:SetTextTooltip(g.lang == "Japanese" and
                               "{ol}[CCH]{nl}左クリック: 設定{nl}右クリック: エコモード切替" or
                               "{ol}[CCH]{nl}Left Click: Settings{nl}Right Click: Eco Mode Toggle")
    setting:ShowWindow(1)
    local eco = setting:CreateOrGetControl("richtext", "eco", 7, 7, 30, 30)
    AUTO_CAST(eco)
    eco:SetText(g.cc_helper_settings.etc.eco == 1 and "{ol}{s10}{#FF0000}eco" or "")
    eco:SetEventScript(ui.LBUTTONUP, "Cc_helper_setting_frame_init")
    eco:SetEventScript(ui.RBUTTONUP, "Cc_helper_toggle_settings")
    eco:SetTextTooltip(g.lang == "Japanese" and
                           "{ol}[CCH]{nl}左クリック: 設定{nl}右クリック: エコモード切替" or
                           "{ol}[CCH]{nl}Left Click: Settings{nl}Right Click: Eco Mode Toggle")
    eco:ShowWindow(1)
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    if accountwarehouse:IsVisible() == 1 then
        local in_btn = inventory:CreateOrGetControl("button", "cch_in_btn", 235, 345, 30, 30)
        AUTO_CAST(in_btn)
        in_btn:SetText("{img in_arrow 20 20}")
        in_btn:SetEventScript(ui.LBUTTONUP, "Cc_helper_putitem")
        in_btn:SetSkinName("test_pvp_btn")
        in_btn:SetTextTooltip(g.lang == "Japanese" and "{ol}[CCH]{nl}装備を外して倉庫へ搬入します" or
                                  "{ol}[CCH]{nl}The equipment is removed{nl}and brought into the warehouse")
        in_btn:ShowWindow(1)
        local out_btn = inventory:CreateOrGetControl("button", "cch_out_btn", 265, 345, 30, 30)
        AUTO_CAST(out_btn)
        out_btn:SetText("{@st66b}{img chul_arrow 20 20}")
        out_btn:SetEventScript(ui.LBUTTONUP, "Cc_helper_take_item")
        out_btn:SetEventScript(ui.RBUTTONUP, "Cc_helper_take_item_context")
        out_btn:SetSkinName("test_pvp_btn")
        out_btn:SetTextTooltip(g.lang == "Japanese" and
                                   "{ol}[CCH]{nl}倉庫から搬出して装備します{nl}左クリック: 現在のセット / 右クリック: セット選択" or
                                   "{ol}[CCH]{nl}It is carried out from the warehouse and equipped{nl}Left: current set / Right: choose set")
        out_btn:ShowWindow(1)
    end
end

function Cc_helper_setting_tab_create(cch_setting)
    local cur = g.cc_helper_settings[g.cid].current or 1
    for n = 1, g.cc_helper_set_count do
        local tab = cch_setting:CreateOrGetControl("button", "cch_set_tab_" .. n, 110 + (n - 1) * 48, 13, 46, 26)
        AUTO_CAST(tab)
        tab:SetText(string.format("{ol}Set%d", n))
        tab:SetSkinName(n == cur and "test_pvp_btn" or "test_gray_button")
        tab:SetEventScript(ui.LBUTTONUP, "Cc_helper_setting_switch_set")
        tab:SetEventScriptArgNumber(ui.LBUTTONUP, n)
        tab:SetTextTooltip(g.lang == "Japanese" and "{ol}編集するセットを選択" or "{ol}Select set to edit")
    end
end

function Cc_helper_setting_frame_init(frame)
    local cch_setting = ui.GetFrame(addon_name_lower .. "cch_setting")
    if frame and cch_setting and cch_setting:IsVisible() == 1 then
        Cc_helper_setting_frame_close(cch_setting)
        return
    end
    Cc_helper_update_hair_stats()
    INVENTORY_SET_CUSTOM_RBTNDOWN("Cc_helper_inv_rbtn")
    cch_setting = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "cch_setting", 0, 0, 0, 0)
    AUTO_CAST(cch_setting)
    cch_setting:RemoveAllChild()
    cch_setting:SetSkinName("test_frame_low")
    cch_setting:SetLayerLevel(93)
    cch_setting:SetGravity(ui.RIGHT, ui.TOP)
    local rect = cch_setting:GetMargin()
    cch_setting:SetMargin(rect.left - rect.left, rect.top - rect.top + 370,
        rect.right == 0 and rect.right + 510 or rect.right, rect.bottom)
    cch_setting:Resize(310, 520)
    cch_setting:SetTitleBarSkin("None")
    cch_setting:EnableHittestFrame(1)
    local title_text = cch_setting:CreateOrGetControl("richtext", "title_text", 20, 15, 50, 30)
    AUTO_CAST(title_text)
    title_text:SetText("{ol}CCH config")
    Cc_helper_setting_tab_create(cch_setting)
    local close = cch_setting:CreateOrGetControl("button", "close", 0, 0, 30, 30)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Cc_helper_setting_frame_close")
    local gbox = cch_setting:CreateOrGetControl("groupbox", "gbox", 10, 40, 0, 0)
    AUTO_CAST(gbox)
    gbox:SetSkinName("test_frame_midle_light")
    local deposit = gbox:CreateOrGetControl("button", "cch_set_deposit", 4, 10, 54, 30)
    AUTO_CAST(deposit)
    deposit:SetText(g.lang == "Japanese" and "{ol}収納" or "{ol}Store")
    deposit:SetSkinName("test_pvp_btn")
    deposit:SetEventScript(ui.LBUTTONUP, "Cc_helper_setting_deposit")
    deposit:SetTextTooltip(g.lang == "Japanese" and "{ol}装備を外して倉庫へ搬入します" or
                               "{ol}Unequip and store into the warehouse")
    local save_delete = gbox:CreateOrGetControl("button", "save_delete", 61, 10, 54, 30)
    AUTO_CAST(save_delete)
    save_delete:SetText("{ol}delete")
    save_delete:SetEventScript(ui.LBUTTONUP, "Cc_helper_setting_delete")
    save_delete:SetTextTooltip(g.lang == "Japanese" and "{ol}コピー用の設定を削除します" or
                                   "{ol}Delete settings for copying")
    local save = gbox:CreateOrGetControl("button", "save", 118, 10, 54, 30)
    AUTO_CAST(save)
    save:SetText("{ol}save")
    save:SetEventScript(ui.LBUTTONUP, "Cc_helper_setting_save")
    save:SetTextTooltip(g.lang == "Japanese" and "{ol}このキャラの設定をコピー用に保存します" or
                            "{ol}Save this character settings for copying")
    local copy = gbox:CreateOrGetControl("button", "copy", 175, 10, 54, 30)
    AUTO_CAST(copy)
    copy:SetText("{ol}copy")
    copy:SetEventScript(ui.LBUTTONUP, "Cc_helper_setting_copy")
    copy:SetTextTooltip(g.lang == "Japanese" and "{ol}コピー用の設定を適用します" or
                            "{ol}Applies the settings for copying")
    local equip = gbox:CreateOrGetControl("button", "cch_set_equip", 232, 10, 54, 30)
    AUTO_CAST(equip)
    equip:SetText(g.lang == "Japanese" and "{ol}装着" or "{ol}Equip")
    equip:SetSkinName("test_pvp_btn")
    equip:SetEventScript(ui.LBUTTONUP, "Cc_helper_setting_equip")
    equip:SetTextTooltip(g.lang == "Japanese" and "{ol}表示中のセットを装着します" or
                             "{ol}Equip the currently shown set")
    if g.settings.monster_card_changer.use == 1 then
        local mccuse = gbox:CreateOrGetControl("checkbox", "mccuse", 10, 375, 25, 25)
        AUTO_CAST(mccuse)
        mccuse:SetText(g.lang == "Japanese" and "{ol}MCC 連携" or "{ol}MCC Linkage")
        mccuse:SetTextTooltip(g.lang == "Japanese" and
                                  "{ol}チェックを入れると[Monster Card Changer]と連携します{nl}各キャラクター個別設定" or
                                  "{ol}If checked, it will work with [Monster Card Changer]{nl}Individual Character Settings")
        mccuse:SetCheck(g.cc_helper_settings[g.cid].mcc)
        mccuse:SetEventScript(ui.LBUTTONUP, "Cc_helper_check_settings")
    else
        g.cc_helper_settings[g.cid].mcc = 0
    end
    local agmuse = gbox:CreateOrGetControl("checkbox", "agmuse", 10, 405, 25, 25)
    AUTO_CAST(agmuse)
    agmuse:SetText(g.lang == "Japanese" and "{ol}エーテルジェム" or "{ol}Aether Gem")
    agmuse:SetTextTooltip(g.lang == "Japanese" and
                              "{ol}チェックを入れるとエーテルジェムも着脱します{nl}各キャラクター個別設定" or
                              "{ol}If checked, Aethergems will also be equipped/unequipped{nl}Individual Character Settings")
    agmuse:SetEventScript(ui.LBUTTONUP, "Cc_helper_check_settings")
    agmuse:SetCheck(g.cc_helper_settings[g.cid].agm)
    local agm_on_off = gbox:CreateOrGetControl("picture", "use_toggle", agmuse:GetWidth() + 10, 405, 60, 25)
    AUTO_CAST(agm_on_off)
    agm_on_off:SetImage(g.cc_helper_settings[g.cid].agm_check == 1 and "test_com_ability_on" or "test_com_ability_off")
    agm_on_off:SetEnableStretch(1)
    agm_on_off:EnableHitTest(1)
    local tooltip_text =
        g.lang == "Japanese" and "{ol}ONにするとエーテルジェム着脱時に確認します" or
            "{ol}If ON, confirmation will be required{nl}when equipping/unequipping Aethergems"
    agm_on_off:SetTextTooltip(tooltip_text)
    agm_on_off:SetEventScript(ui.LBUTTONUP, "Cc_helper_toggle_settings")
    local all_agm = gbox:CreateOrGetControl("checkbox", "all_agm", 10, 435, 25, 25)
    AUTO_CAST(all_agm)
    all_agm:SetText(g.lang == "Japanese" and "{ol}エーテルジェム 全体停止" or "{ol}Aether Gem All Stop")
    all_agm:SetTextTooltip(g.lang == "Japanese" and
                               "{ol}チェックを入れると、全てのキャラの{nl}エーテルジェム関係の動作をストップします" or
                               "{ol}If checked, stops all ether gem-related actions for all characters")
    all_agm:SetEventScript(ui.LBUTTONUP, "Cc_helper_check_settings")
    all_agm:SetCheck(g.cc_helper_settings.etc.agm_stop) --
    local pet_select = gbox:CreateOrGetControl("button", "pet_select", 180, 375, 100, 30)
    AUTO_CAST(pet_select)
    pet_select:SetText("{ol}pet select")
    pet_select:SetEventScript(ui.LBUTTONUP, "Cc_helper_context_pet")
    gbox:Resize(cch_setting:GetWidth() - 20, cch_setting:GetHeight() - 50)
    cch_setting:ShowWindow(1)
    Cc_helper_slot_create_reserve(cch_setting, gbox)
end

function Cc_helper_slot_create_reserve(cch_setting, gbox)
    local slot_info = {
        ["seal"] = {
            x = 35,
            y = 210,
            text = "{ol}{s14}SEAL"
        },
        ["ark"] = {
            x = 90,
            y = 210,
            text = "{ol}{s14}ARK"
        },
        ["core"] = {
            x = 145,
            y = 210,
            text = "{ol}{s14}CORE"
        },
        ["relic"] = {
            x = 200,
            y = 210,
            text = "{ol}{s14}RELIC"
        },
        ["gem1"] = {
            x = 35,
            y = 320,
            text = "{ol}{s12}AETHER{nl}GEM1"
        },
        ["gem2"] = {
            x = 90,
            y = 320,
            text = "{ol}{s12}AETHER{nl}GEM2"
        },
        ["gem3"] = {
            x = 145,
            y = 320,
            text = "{ol}{s12}AETHER{nl}GEM3"
        },
        ["gem4"] = {
            x = 200,
            y = 320,
            text = "{ol}{s12}AETHER{nl}GEM4"
        },
        ["leg"] = {
            x = 30,
            y = 45,
            text = "{ol}{s14}LEGEND{nl}CARD"
        },
        ["god"] = {
            x = 140,
            y = 45,
            text = "{ol}{s14}GODDESS{nl}CARD"
        },
        ["hair1"] = {
            x = 35,
            y = 265,
            text = "{ol}{s14}HAIR1"
        },
        ["hair2"] = {
            x = 90,
            y = 265,
            text = "{ol}{s14}HAIR2"
        },
        ["hair3"] = {
            x = 145,
            y = 265,
            text = "{ol}{s14}HAIR3"
        },
        ["pet"] = {
            x = 220,
            y = 410,
            text = "{ol}{s14}PET"
        }
    }
    for key, value in pairs(slot_info) do
        for k, v in pairs(g.cc_helper_settings[g.cid].items) do
            if key == k then
                local width = 50
                local height = 50
                if key == "leg" then
                    width = 105 -- 9:13
                    height = 160
                end
                if key == "god" then
                    width = 120 -- 3:4
                    height = 160
                end
                local skin = "invenslot2"
                if key == "leg" then
                    skin = "legendopen_cardslot"
                elseif key == "god" then
                    skin = "goddess_card__activation"
                end
                Cc_helper_slot_create(gbox, key, value.x, value.y, width, height, skin, value.text, v.clsid, v.iesid,
                    v.option, v.rank, v.image)
                break
            end
        end
    end
end

function Cc_helper_slot_create(gbox, name, x, y, width, height, skin, text, clsid, iesid, option, rank, image)
    local slot = GET_CHILD(gbox, name)
    if not slot then
        slot = gbox:CreateOrGetControl("slot", name, x, y, width, height)
        AUTO_CAST(slot)
        slot:SetSkinName(skin)
        slot:SetText(text)
        slot:EnablePop(1)
        slot:EnableDrag(1)
        slot:EnableDrop(1)
    end
    AUTO_CAST(slot)
    slot:SetEventScript(ui.DROP, "Cc_helper_frame_drop")
    slot:SetEventScript(ui.RBUTTONDOWN, "Cc_helper_cancel")
    local item_cls = GetClassByType("Item", clsid)
    if not item_cls then
        item_cls = GetClassByType("Monster", clsid)
        if not item_cls then
            return
        end
        image = item_cls.Icon
    end
    if not string.find(name, "gem") then
        SET_SLOT_ITEM_CLS(slot, item_cls)
        SET_SLOT_IMG(slot, image)
        SET_SLOT_IESID(slot, iesid)
        if name ~= "leg" and name ~= "god" then
            SET_SLOT_BG_BY_ITEMGRADE(slot, item_cls)
        end
        if string.find(name, "hair") then
            if rank == "A" then
                slot:SetSkinName("invenslot_pic_goddess")
            elseif rank == "B" then
                slot:SetSkinName("invenslot_legend")
            elseif rank == "C" then
                slot:SetSkinName("invenslot_unique")
            end
        end
        local icon = slot:GetIcon()
        if not icon and item_cls then
            icon = CreateIcon(slot)
        end
        if clsid ~= 0 then
            if string.find(name, "hair") then
                if string.find(option, ":::") then
                    local text = "{ol}Rank: " .. rank .. "{nl}"
                    local result = StringSplit(option, ":::")
                    if not string.find(option, "#@!") then
                        for i = 1, 3 do
                            local op_tbl = StringSplit(result[i], "/")
                            local op_name = op_tbl[1]
                            op_name = ScpArgMsg(op_name)
                            local op_value = op_tbl[2]
                            text = text .. op_name .. ScpArgMsg("PropUp") .. GET_COMMAED_STRING(op_value) .. "{nl}"
                        end
                    else
                        text = text .. table.concat(result, "{nl}")

                    end
                    icon:SetTextTooltip(text)
                end
            elseif name == "pet" then
                icon:SetTextTooltip(option)
            else
                icon:SetTooltipType("wholeitem")
                icon:SetTooltipArg("None", clsid, iesid)
            end
        end
    end
    if string.find(name, "gem") then
        -- gem slots always show as placeholders (equip/unequip behavior is still
        -- gated by the Aether Gem checkbox in putitem/take_item, not visibility)
        slot:ShowWindow(1)
        local gem_name = item_cls.ClassName
        local icon = slot:GetIcon()
        if not icon then
            icon = CreateIcon(slot)
        end
        SET_SLOT_ITEM_CLS(slot, item_cls)
        local lv_text = slot:CreateOrGetControl("richtext", "lv_text", 0, 30, 25, 25)
        AUTO_CAST(lv_text)
        if string.find(gem_name, "480") then
            lv_text:SetText("{ol}{s14}LV480")
            slot:SetSkinName("invenslot_rare")
        elseif string.find(gem_name, "500") then
            lv_text:SetText("{ol}{s14}LV500")
            slot:SetSkinName("invenslot_unique")
        elseif string.find(gem_name, "520") then
            lv_text:SetText("{ol}{s14}LV520")
            slot:SetSkinName("invenslot_legend")
        elseif string.find(gem_name, "540") then
            lv_text:SetText("{ol}{s14}LV540")
            slot:SetSkinName("invenslot_pic_goddess")
        else
            lv_text:SetText("{ol}{s14}LV460")
        end
    end
end

function Cc_helper_check_settings(frame, ctrl)
    local ctrl_name = ctrl:GetName()
    if ctrl_name == "cch_auto_close" then
        g.cc_helper_settings.etc.wh_close = ctrl:IsChecked()
    elseif ctrl_name == "mccuse" then
        g.cc_helper_settings[g.cid].mcc = ctrl:IsChecked()
    elseif ctrl_name == "agmuse" then
        g.cc_helper_settings[g.cid].agm = ctrl:IsChecked()
        Cc_helper_setting_frame_init()
    elseif ctrl_name == "all_agm" then
        g.cc_helper_settings.etc.agm_stop = 1 - g.cc_helper_settings.etc.agm_stop
    end
    Cc_helper_save_settings()
end

function Cc_helper_toggle_settings(frame, ctrl)
    local ctrl_name = ctrl:GetName()
    if ctrl_name == "eco" or ctrl_name == "cch_setting" then
        local eco = GET_CHILD_RECURSIVELY(frame, "eco")
        if g.cc_helper_settings.etc.eco == 0 then
            g.cc_helper_settings.etc.eco = 1
            eco:SetText("{ol}{s10}{#FF0000}eco")
        else
            g.cc_helper_settings.etc.eco = 0
            eco:SetText("")
        end
    elseif ctrl_name == "use_toggle" then
        g.cc_helper_settings[g.cid].agm_check = 1 - g.cc_helper_settings[g.cid].agm_check
        Cc_helper_setting_frame_init()
    end
    Cc_helper_save_settings()
end

function Cc_helper_setting_frame_close(cch_setting)
    INVENTORY_SET_CUSTOM_RBTNDOWN("None")
    ui.DestroyFrame(cch_setting:GetName())
    if g.settings.another_warehouse.use == 1 then
        local awh = ui.GetFrame(addon_name_lower .. "awh")
        if awh and awh:IsVisible() == 1 then
            INVENTORY_SET_CUSTOM_RBTNDOWN("Another_warehouse_inv_rbtn")
            return
        end
    else
        local accountwarehouse = ui.GetFrame("accountwarehouse")
        if accountwarehouse:IsVisible() == 1 then
            INVENTORY_SET_CUSTOM_RBTNDOWN("ACCOUNT_WAREHOUSE_INV_RBTN")
        else
            INVENTORY_SET_CUSTOM_RBTNDOWN("None")
        end
    end
end

function Cc_helper_setting_copy()
    local title = g.lang == "Japanese" and "{ol}コピー元選択" or "{ol}Select Copy Source"
    local context = ui.CreateContextMenu("cc_helper_copy_context", title, 0, 0, 0, 0)
    ui.AddContextMenuItem(context, "{ol}" .. "-----", "")
    for cid, char_data in pairs(g.cc_helper_settings.etc.copys) do
        local job_cls = GetClassByType("Job", char_data.jobid)
        local job_name = GET_JOB_NAME(job_cls, char_data.gender)
        local name = char_data.name
        local setnum = char_data.setnum or 1 -- legacy entries without a set show as Set 1
        local text = name .. " (" .. job_name .. ") Set " .. setnum
        local scp = ui.AddContextMenuItem(context, text, string.format("Cc_helper_load_copy('%s')", cid))
    end
    ui.OpenContextMenu(context)
end

function Cc_helper_load_copy(cid)
    local src = g.cc_helper_settings.etc.copys[cid]
    local cd = g.cc_helper_settings[g.cid]
    Cc_helper_ensure_sets(cd) -- make sure sets/current/items alias are valid
    -- source items: new per-set source has .items; legacy whole-char source
    -- (has .sets) -> take its current set
    local src_items
    if src.items then
        src_items = src.items
    elseif src.sets then
        local scur = src.current or 1
        local sset = src.sets[scur] or src.sets[1]
        src_items = sset and sset.items
    end
    if src_items then
        -- copy into the currently shown set only; leave other sets intact
        cd.sets[cd.current].items = json.decode(json.encode(src_items))
        Cc_helper_ensure_sets(cd) -- fill any missing item keys, re-point items alias
    end
    if src.mcc ~= nil then
        cd.mcc = src.mcc
    end
    if src.agm ~= nil then
        cd.agm = src.agm
    end
    if src.agm_check ~= nil then
        cd.agm_check = src.agm_check
    end
    cd.name = g.login_name
    Cc_helper_save_settings()
    ui.SysMsg(g.lang == "Japanese" and "設定をコピーしました" or "Settings copied")
    Cc_helper_setting_frame_init()
end

function Cc_helper_setting_delete(frame, ctrl)
    local title = g.lang == "Japanese" and "削除データ選択" or "Select Data to Delete"
    local context = ui.CreateContextMenu("cc_helper_delete_context", "{ol}{#FF0000}" .. title, 0, 0, 0, 0)
    ui.AddContextMenuItem(context, "{ol}{#FF0000}" .. "-----", "")
    for cid, char_data in pairs(g.cc_helper_settings.etc.copys) do
        local job_cls = GetClassByType("Job", char_data.jobid)
        local job_name = GET_JOB_NAME(job_cls, char_data.gender)
        local name = char_data.name
        local setnum = char_data.setnum or 1 -- legacy entries without a set show as Set 1
        local text = "{ol}{#FF0000}" .. name .. " (" .. job_name .. ") Set " .. setnum
        local scp = ui.AddContextMenuItem(context, text, string.format("Cc_helper_setting_delete_('%s')", cid))
    end
    ui.OpenContextMenu(context)
end

function Cc_helper_setting_delete_(cid)
    g.cc_helper_settings.etc.copys[cid] = nil
    ui.SysMsg(g.lang == "Japanese" and "設定を削除しました" or "Settings deleted")
    Cc_helper_save_settings()
end

function Cc_helper_setting_save(frame, ctrl)
    local cd = g.cc_helper_settings[g.cid]
    Cc_helper_ensure_sets(cd)
    -- save only the currently shown set as the copy source, keyed per (char, set)
    -- so each set is a distinct entry (does not overwrite other sets)
    local key = tostring(g.cid) .. "_set" .. cd.current
    local new_copy_data = {
        items = json.decode(json.encode(cd.sets[cd.current].items)),
        setnum = cd.current,
        agm = cd.agm,
        agm_check = cd.agm_check,
        mcc = cd.mcc,
        name = cd.name or g.login_name
    }
    local pc_info = session.barrack.GetMyAccount():GetByStrCID(g.cid)
    local pc_apc = pc_info:GetApc()
    local jobid = pc_info:GetRepID() or pc_apc:GetJob()
    local gender = pc_apc:GetGender()
    new_copy_data.jobid = jobid
    new_copy_data.gender = gender
    g.cc_helper_settings.etc.copys[key] = new_copy_data
    ui.SysMsg(g.lang == "Japanese" and "設定を保存しました" or "Settings saved")
    Cc_helper_save_settings()
end

function Cc_helper_context_pet()
    local pet_list = session.pet.GetPetInfoVec()
    local context = ui.CreateContextMenu("PET_SELECT", "{ol}Pet Select", 400, 0, -400, 0)
    for i = 0, pet_list:size() - 1 do
        local info = pet_list:at(i)
        local obj = GetIES(info:GetObject())
        local name = info:GetName()
        local pet_iesid = info:GetStrGuid()
        local cls_name = obj.ClassName
        local cls_id = obj.ClassID
        local sin_name = obj.Name
        local cls_list, list_cnt = GetClassList("Companion")
        for index = 0, list_cnt - 1 do
            local companion_ies = GetClassByIndexFromList(cls_list, index)
            local ies_cls_name = companion_ies.ClassName
            if cls_name == ies_cls_name then
                local job_id = tonumber(companion_ies.JobID)
                if job_id ~= 3014 then
                    local option = "{ol}[LV:" .. obj.Lv .. "] " .. name .. " ( " .. dic.getTranslatedStr(obj.Name) ..
                                       " ) "
                    local companion_cls = GetClass("Companion", TryGetProp(obj, "ClassName", "None"))
                    local pet_buff = TryGetProp(companion_cls, "PetBuff", "None")
                    local buff_cls = GetClass("Buff", pet_buff)
                    if buff_cls then
                        local tool_tip = TryGetProp(buff_cls, "ToolTip", "None")
                        if tool_tip ~= "None" then
                            option = option .. "{nl}" .. dic.getTranslatedStr(tool_tip)
                        end
                    end
                    local scp = string.format("Cc_helper_context_pet_set(%d,'%s','%s')", cls_id, pet_iesid, option)
                    ui.AddContextMenuItem(context,
                        "{img " .. obj.Icon .. " 20 20}" .. "{ol} [LV:" .. obj.Lv .. "] " .. name .. " ( " ..
                            dic.getTranslatedStr(obj.Name) .. " ) ", scp)
                    break
                end
            end
        end
    end
    ui.OpenContextMenu(context)
end

function Cc_helper_context_pet_set(cls_id, pet_iesid, option)
    local mon_cls = GetClassByType("Monster", cls_id)
    local cch_setting = ui.GetFrame(addon_name_lower .. "cch_setting")
    local slot = GET_CHILD_RECURSIVELY(cch_setting, "pet")
    AUTO_CAST(slot)
    local image = mon_cls.Icon
    SET_SLOT_ITEM_CLS(slot, mon_cls)
    SET_SLOT_IMG(slot, image)
    SET_SLOT_IESID(slot, pet_iesid)
    g.cc_helper_settings[g.cid].items.pet.iesid = pet_iesid
    g.cc_helper_settings[g.cid].items.pet.clsid = cls_id
    g.cc_helper_settings[g.cid].items.pet.image = image
    g.cc_helper_settings[g.cid].items.pet.option = option
    Cc_helper_save_settings()
end

function Cc_helper_cancel(frame, slot)
    slot:ClearIcon()
    slot:RemoveAllChild()
    for key, value in pairs(g.cc_helper_settings[g.cid].items) do
        if slot:GetName() == key then
            value.image = ""
            value.iesid = ""
            value.clsid = 0
            value.option = ""
            if not string.find(key, "god") and not string.find(key, "leg") then
                slot:SetSkinName("invenslot2")
            end
            break
        end
    end
    Cc_helper_save_settings()
end

function Cc_helper_frame_drop(frame, ctrl)
    local lift_icon = ui.GetLiftIcon()
    local slot = lift_icon:GetParent()
    local icon_info = lift_icon:GetInfo()
    local iesid = icon_info:GetIESID()
    local inv_item = session.GetInvItemByGuid(iesid)
    local item_obj = GetIES(inv_item:GetObject())
    Cc_helper_inv_rbtn(item_obj, slot, iesid)
end

function Cc_helper_inv_rbtn(item_obj, slot, iesid, awh_item)
    local cch_setting = ui.GetFrame(addon_name_lower .. "cch_setting")
    if not cch_setting or cch_setting:IsVisible() == 0 then
        return
    end
    if not g.cc_helper_settings or not g.cc_helper_settings[g.cid] or not g.cc_helper_settings[g.cid].items then
        return
    end
    local gbox = GET_CHILD(cch_setting, "gbox")
    if not iesid then
        local icon = slot:GetIcon()
        local icon_info = icon:GetInfo()
        iesid = icon_info:GetIESID()
    end
    local inv_item = awh_item or session.GetInvItemByGuid(iesid)
    if not inv_item then
        return
    end
    local image = TryGetProp(item_obj, "TooltipImage", "None")
    local clsid = item_obj.ClassID
    local type = item_obj.ClassType
    local gem_type = GET_EQUIP_GEM_TYPE(item_obj)
    local parent_name = slot:GetParent():GetName()
    local char_belonging = TryGetProp(item_obj, "CharacterBelonging", 0)
    local temp_tbl = {
        ["Seal"] = "seal",
        ["Ark"] = "ark",
        ["LEG"] = "leg",
        ["GODDESS"] = "god",
        ["sset_HairAcc_Acc1"] = "hair1",
        ["sset_HairAcc_Acc2"] = "hair2",
        ["sset_HairAcc_Acc3"] = "hair3",
        ["CORE"] = "core",
        ["Relic"] = "relic",
        ["aether"] = "gem"
    }
    for key, value in pairs(temp_tbl) do
        local target_item_setting = g.cc_helper_settings[g.cid].items[value]
        if target_item_setting then
            if key == "Seal" and key == type and clsid ~= 614001 then
                target_item_setting.clsid = clsid
                target_item_setting.iesid = iesid
                target_item_setting.image = image
                Cc_helper_slot_create(gbox, value, nil, nil, nil, nil, nil, nil, clsid, iesid, nil, nil, image)
                break
            elseif key == "Ark" and key == type and char_belonging ~= 1 then
                target_item_setting.clsid = clsid
                target_item_setting.iesid = iesid
                target_item_setting.image = image
                Cc_helper_slot_create(gbox, value, nil, nil, nil, nil, nil, nil, clsid, iesid, nil, nil, image)
                break
            elseif key == "CORE" and key == type then
                target_item_setting.clsid = clsid
                target_item_setting.iesid = iesid
                target_item_setting.image = image
                Cc_helper_slot_create(gbox, value, nil, nil, nil, nil, nil, nil, clsid, iesid, nil, nil, image)
                break
            elseif key == "Relic" and key == type then
                target_item_setting.clsid = clsid
                target_item_setting.iesid = iesid
                target_item_setting.image = image
                Cc_helper_slot_create(gbox, value, nil, nil, nil, nil, nil, nil, clsid, iesid, nil, nil, image)
                break
            elseif key == "LEG" and key == item_obj.CardGroupName then
                target_item_setting.clsid = clsid
                target_item_setting.iesid = iesid
                target_item_setting.image = image
                Cc_helper_slot_create(gbox, value, nil, nil, nil, nil, nil, nil, clsid, iesid, nil, nil, image)
                break
            elseif key == "GODDESS" and key == item_obj.CardGroupName then
                target_item_setting.clsid = clsid
                target_item_setting.iesid = iesid
                target_item_setting.image = image
                Cc_helper_slot_create(gbox, value, nil, nil, nil, nil, nil, nil, clsid, iesid, nil, nil, image)
                break
            elseif key == "sset_HairAcc_Acc1" and key == parent_name then
                local option, rank = Cc_helper_hair_option(item_obj)
                target_item_setting.rank = rank
                target_item_setting.option = option
                target_item_setting.clsid = clsid
                target_item_setting.iesid = iesid
                target_item_setting.image = image
                Cc_helper_slot_create(gbox, value, nil, nil, nil, nil, nil, nil, clsid, iesid, option, rank, image)
                break
            elseif key == "sset_HairAcc_Acc2" and key == parent_name then
                local option, rank = Cc_helper_hair_option(item_obj)
                target_item_setting.rank = rank
                target_item_setting.option = option
                target_item_setting.clsid = clsid
                target_item_setting.iesid = iesid
                target_item_setting.image = image
                Cc_helper_slot_create(gbox, value, nil, nil, nil, nil, nil, nil, clsid, iesid, option, rank, image)
                break
            elseif key == "sset_HairAcc_Acc3" and key == parent_name then
                local option, rank = Cc_helper_hair_option(item_obj)
                target_item_setting.rank = rank
                target_item_setting.option = option
                target_item_setting.clsid = clsid
                target_item_setting.iesid = iesid
                target_item_setting.image = image
                Cc_helper_slot_create(gbox, value, nil, nil, nil, nil, nil, nil, clsid, iesid, option, rank, image)
                break
            end
        end
        if gem_type == "aether" and key == "aether" then
            if g.cc_helper_settings[g.cid].agm == 0 then
                return
            end
            for i = 1, 4 do
                local slot_name = "gem" .. i
                local slot = GET_CHILD(gbox, slot_name)
                if slot then
                    local icon = slot:GetIcon()
                    if not icon then
                        if g.cc_helper_settings[g.cid].items[slot_name] then
                            g.cc_helper_settings[g.cid].items[slot_name].clsid = clsid
                            Cc_helper_slot_create(gbox, slot_name, nil, nil, nil, nil, nil, nil, clsid, iesid, nil, nil,
                                image)
                        end
                        break
                    end
                end
            end
        end
    end
    Cc_helper_save_settings()
end
-- putitem
function Cc_helper_putitem(frame, in_btn, str, step)
    if g.another_warehouse_func == true then
        ui.SysMsg(g.lang == "Japanese" and "[AWH]が作動中です" or "[AWH]is currently operating")
        return
    end
    if step == 0 then
        in_btn:SetUserValue("STEP", 0)
        local monstercardslot = ui.GetFrame("monstercardslot")
        if monstercardslot:IsVisible() == 0 then
            MONSTERCARDSLOT_FRAME_OPEN()
            in_btn:RunUpdateScript("Cc_helper_unequip_card_god", 0.1)
            return
        end
    elseif step == 1 then
        g.cc_helper_unequip_queue = nil
        in_btn:SetUserValue("STEP", step)
        in_btn:RunUpdateScript("Cc_helper_in_btn_start", 0.1)
        return
    elseif step == 2 then
        local eco = g.cc_helper_settings.etc.eco or 0
        in_btn:SetUserValue("STEP", step)
        if eco == 0 then
            in_btn:RunUpdateScript("Cc_helper_unequip_card_leg", 0.1)
        else
            Cc_helper_putitem(nil, in_btn, nil, 3)
        end
        return
    elseif step == 3 then
        in_btn:SetUserValue("STEP", step)
        Cc_helper_inv_to_warehouse(in_btn)
        in_btn:RunUpdateScript("Cc_helper_inv_to_warehouse", 0.2)
        return
    elseif step == 4 then
        in_btn:SetUserValue("STEP", 4)
        Cc_helper_in_btn_aethergem_mgr(in_btn)
    elseif step == 5 then
        in_btn:SetUserValue("STEP", 5)
        in_btn:RunUpdateScript("Cc_helper_gem_inv_to_warehouse", 0.1)
        return
    elseif step == 6 then
        in_btn:SetUserValue("STEP", 6)
        if g.cc_helper_settings[g.cid].mcc == 1 then
            Monster_card_changer_monstercardpreset_open(1)
            in_btn:RunUpdateScript("Cc_helper_mcc_operation", 0.1)
        else
            Cc_helper_putitem(nil, in_btn, nil, 7)
        end
    elseif step == 7 then
        in_btn:SetUserValue("STEP", 7)
        Cc_helper_end_of_operation(in_btn)
    end
end

function Cc_helper_unequip_card_god(in_btn)
    local try = in_btn:GetUserIValue("TRY")
    local target_key = "god"
    local slot_index = 14
    local setting_item = g.cc_helper_settings[g.cid].items["god"]
    local save_clsid = setting_item.clsid
    local save_iesid = setting_item.iesid
    if save_clsid ~= 0 then
        local card_info = equipcard.GetCardInfo(slot_index)
        local is_equipped = (card_info and card_info:GetCardID() == save_clsid)
        if is_equipped then
            local arg_str = string.format("%d 1", slot_index - 1)
            pc.ReqExecuteTx_NumArgs("SCR_TX_UNEQUIP_CARD_SLOT", arg_str)
            return 1
        end
        if try < 2 then
            local inv_item = session.GetInvItemByGuid(save_iesid)
            if inv_item == nil then
                in_btn:SetUserValue("TRY", try + 1)
                return 1
            end
        end
    end
    in_btn:SetUserValue("TRY", 0)
    in_btn:StopUpdateScript("Cc_helper_unequip_card_god")
    Cc_helper_putitem(nil, in_btn, nil, 1)
end

function Cc_helper_in_btn_start(in_btn)
    local inventory = ui.GetFrame("inventory")
    if true == BEING_TRADING_STATE() then
        return 0
    end
    local is_empty_slot = false
    if session.GetInvItemList():Count() < MAX_INV_COUNT then
        is_empty_slot = true
    end
    if is_empty_slot == true then
        in_btn:StopUpdateScript("Cc_helper_in_btn_start")
        in_btn:RunUpdateScript("Cc_helper_unequip", 0.1)
        return 0
    else
        ui.SysMsg(ScpArgMsg("Auto_inBenToLie_Bin_SeulLosi_PilyoHapNiDa."))
        return 0
    end
end

function Cc_helper_unequip(in_btn)
    local inventory = ui.GetFrame("inventory")
    local eqp_tab = GET_CHILD_RECURSIVELY(inventory, "inventype_Tab")
    eqp_tab:SelectTab(1)
    if not g.cc_helper_unequip_queue then
        g.cc_helper_unequip_queue = {}
        local equip_tbl = {0, 20, 1, 25, 27, 29, 35}
        local temp_tbl = {"hair1", "hair2", "hair3", "seal", "ark", "relic", "core"}
        local equip_item_list = session.GetEquipItemList()
        for i, equip_index in ipairs(equip_tbl) do
            local equip_item = equip_item_list:GetEquipItemByIndex(equip_index)
            if equip_item then
                local iesid = equip_item:GetIESID()
                local key = temp_tbl[i]
                local setting_data = g.cc_helper_settings[g.cid].items[key]
                if iesid ~= "0" and setting_data and setting_data.iesid == iesid then
                    table.insert(g.cc_helper_unequip_queue, {
                        slot_index = equip_index,
                        iesid = iesid,
                        req_time = 0
                    })
                end
            end
        end
        if #g.cc_helper_unequip_queue == 0 then
            g.cc_helper_unequip_queue = nil
            in_btn:StopUpdateScript("Cc_helper_unequip")
            Cc_helper_putitem(nil, in_btn, nil, 2)
            return 0
        end
        return 1
    end
    local target = g.cc_helper_unequip_queue[1]
    if not target then
        g.cc_helper_unequip_queue = nil
        in_btn:StopUpdateScript("Cc_helper_unequip")
        Cc_helper_putitem(nil, in_btn, nil, 2)
        return 0
    end
    local inv_item = session.GetInvItemByGuid(target.iesid)
    if inv_item then
        table.remove(g.cc_helper_unequip_queue, 1)
        return 1
    end
    local equip_item = session.GetEquipItemByGuid(target.iesid)
    if equip_item then
        local now = imcTime.GetAppTime()
        if target.req_time == 0 or (now - target.req_time > 3.0) then
            item.UnEquip(target.slot_index)
            target.req_time = now
        end
        return 1 -- 待機
    else
        if target.req_time > 0 and (imcTime.GetAppTime() - target.req_time > 5.0) then
            ui.SysMsg("{#FF0000}Unequip timeout or item missing.")
            table.remove(g.cc_helper_unequip_queue, 1)
        end
        return 1
    end
end

function Cc_helper_unequip_card_leg(in_btn)
    local try = in_btn:GetUserIValue("TRY")
    local target_key = "leg"
    local slot_index = 13
    local setting_item = g.cc_helper_settings[g.cid].items["leg"]
    local save_clsid = setting_item.clsid
    local save_iesid = setting_item.iesid
    if save_clsid ~= 0 then
        local card_info = equipcard.GetCardInfo(slot_index)
        local is_equipped = (card_info and card_info:GetCardID() == save_clsid)
        if is_equipped then
            local arg_str = string.format("%d 1", slot_index - 1)
            pc.ReqExecuteTx_NumArgs("SCR_TX_UNEQUIP_CARD_SLOT", arg_str)
            return 1
        end
        if try < 2 then
            local inv_item = session.GetInvItemByGuid(save_iesid)
            if inv_item == nil then
                in_btn:SetUserValue("TRY", try + 1)
                return 1
            end
        end
    end
    in_btn:StopUpdateScript("Cc_helper_unequip_card_leg")
    in_btn:SetUserValue("TRY", 0)
    Cc_helper_putitem(nil, in_btn, nil, 3)
    return 0
end

function Cc_helper_inv_to_warehouse(in_btn)
    local temp_tbl = {{
        key = "seal",
        value = "sset_Accessory_Seal"
    }, {
        key = "ark",
        value = "sset_Accessory_Ark"
    }, {
        key = "core",
        value = "sset_Accessory_Core"
    }, {
        key = "relic",
        value = "sset_Relic"
    }, {
        key = "hair1",
        value = "sset_HairAcc_Acc1"
    }, {
        key = "hair2",
        value = "sset_HairAcc_Acc2"
    }, {
        key = "hair3",
        value = "sset_HairAcc_Acc3"
    }, {
        key = "leg",
        value = "sset_Card_CardLeg"
    }, {
        key = "god",
        value = "sset_Card_CardGoddess"
    }}
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    if accountwarehouse:IsVisible() == 1 then
        local handle = accountwarehouse:GetUserIValue("HANDLE")
        local inventory = ui.GetFrame("inventory")
        local inventype_Tab = GET_CHILD_RECURSIVELY(inventory, "inventype_Tab")
        for i, data in ipairs(temp_tbl) do
            local key = data.key
            local value = data.value
            local iesid = g.cc_helper_settings[g.cid].items[key].iesid
            local inv_item = session.GetInvItemByGuid(iesid)
            if inv_item then
                if i <= 5 then
                    inventype_Tab:SelectTab(1)
                    local inventree_Equip = GET_CHILD_RECURSIVELY(inventory, "inventree_Equip")
                    local child_count = inventree_Equip:GetChildCount()
                    for j = 0, child_count - 1 do
                        local child = inventree_Equip:GetChildByIndex(j)
                        local child_name = child:GetName()
                        if child_name == value then
                            local child_y = child:GetY()
                            local treeGbox_Equip = GET_CHILD_RECURSIVELY(inventory, "treeGbox_Equip")
                            treeGbox_Equip:SetScrollPos(tonumber(child_y))
                            break
                        end
                    end
                else
                    inventype_Tab:SelectTab(4)
                    local inventree_Card = GET_CHILD_RECURSIVELY(inventory, "inventree_Card")
                    local child_count = inventree_Card:GetChildCount()
                    for j = 0, child_count - 1 do
                        local child = inventree_Card:GetChildByIndex(j)
                        local child_name = child:GetName()
                        if child_name == value then
                            local child_y = child:GetY()
                            local treeGbox_Card = GET_CHILD_RECURSIVELY(inventory, "treeGbox_Card")
                            treeGbox_Card:SetScrollPos(tonumber(child_y))
                            break
                        end
                    end
                end
                if Cc_helper_checkvalid(inv_item) then
                    local goal_index = Cc_helper_get_goal_index()
                    local item_cls = GetClassByType("Item", g.cc_helper_settings[g.cid].items[key].clsid)
                    local item_name = item_cls.Name
                    local log = g.lang == "Japanese" and "倉庫に格納しました" .. "：[" .. "{#EE82EE}" ..
                                    item_name .. "{#FFFF00}]×" .. "{#EE82EE}1" or "Item to warehousing" .. "：[" ..
                                    "{#EE82EE}" .. item_name .. "{#FFFF00}]×" .. "{#EE82EE}1"
                    CHAT_SYSTEM(log)
                    item.PutItemToWarehouse(IT_ACCOUNT_WAREHOUSE, iesid, 1, handle, goal_index)
                    imcSound.PlaySoundEvent("sys_jam_slot_equip")
                    return 1
                end
            end
        end
        in_btn:StopUpdateScript("Cc_helper_inv_to_warehouse")
        Cc_helper_putitem(nil, in_btn, nil, 4)
        return 0
    end
    in_btn:StopUpdateScript("Cc_helper_inv_to_warehouse")
    return 0
end

function Cc_helper_in_btn_aethergem_mgr(in_btn)
    local inventory = ui.GetFrame("inventory")
    local equip_slots = {"RH", "LH", "RH_SUB", "LH_SUB"}
    local eco = g.cc_helper_settings.etc.eco or 0
    local agm_stop = g.cc_helper_settings.etc.agm_stop or 0
    local agm = g.cc_helper_settings[g.cid].agm
    if eco == 0 and agm_stop == 0 and agm == 1 then
        local eq_count = 0
        local has_target_gem = false
        g.cc_helper_guids = {}
        for _, slot_name in ipairs(equip_slots) do
            local equip_slot = GET_CHILD_RECURSIVELY(inventory, slot_name)
            local icon = equip_slot:GetIcon()
            if icon then
                local icon_info = icon:GetInfo()
                local iesid = icon_info:GetIESID()
                g.cc_helper_guids[slot_name] = iesid
                eq_count = eq_count + 1
                if not has_target_gem then
                    local equip_item = session.GetEquipItemByGuid(iesid)
                    if equip_item then
                        local gem_id = equip_item:GetEquipGemID(2) -- 2 = Aether Gem
                        for i = 1, 4 do
                            local gem_key = "gem" .. i
                            if gem_id == g.cc_helper_settings[g.cid].items[gem_key].clsid then
                                has_target_gem = true
                                break
                            end
                        end
                    end
                end
            end
        end
        if has_target_gem then
            if eq_count == 4 then
                Cc_helper_msgbox_frame(in_btn)
                return
            else
                local msg = g.lang == "Japanese" and "{ol}武器4ヶ所着けてください" or
                                "{ol}Please equip weapons in 4 slots"
                ui.SysMsg(msg)
                Cc_helper_putitem(nil, in_btn, nil, 6)
                return
            end
        else
            Cc_helper_putitem(nil, in_btn, nil, 6)
            return
        end
    end
    Cc_helper_putitem(nil, in_btn, nil, 6)
end

function Cc_helper_msgbox_frame(in_btn)
    if g.cc_helper_settings[g.cid].agm_check == 1 then
        local top_frame = in_btn:GetTopParentFrame()
        local msg = g.lang == "Japanese" and "{ol}{#FFFFFF}エーテルジェムを付替えますか？" or
                        "{ol}{#FFFFFF}Would you like to swap Aether Gems?"
        local yes_scp = string.format("Cc_helper_start_agm_reserve('%s')", top_frame:GetName())
        local no_scp = string.format("Cc_helper_start_agm_reserve('%s',%d)", top_frame:GetName(), 1)
        ui.MsgBox(msg, yes_scp, no_scp)
    else
        Cc_helper_start_agm(in_btn)
    end
end

function Cc_helper_start_agm_reserve(frame_name, no_scp)
    local top_frame = ui.GetFrame(frame_name)
    local in_btn = GET_CHILD_RECURSIVELY(top_frame, "cch_in_btn")
    if not no_scp then
        Cc_helper_start_agm(in_btn)
    else
        Cc_helper_putitem(nil, in_btn, nil, 6)
    end
end

function Cc_helper_start_agm(btn)
    local goddess_equip_manager = ui.GetFrame("goddess_equip_manager") -- layerlevel="92"
    if goddess_equip_manager:IsVisible() == 0 then
        help.RequestAddHelp("TUTO_GODDESSEQUIP_1")
        goddess_equip_manager:ShowWindow(1)
        goddess_equip_manager:SetLayerLevel(100)
        local main_tab = GET_CHILD_RECURSIVELY(goddess_equip_manager, "main_tab")
        main_tab:SelectTab(2)
        GODDESS_MGR_SOCKET_OPEN(goddess_equip_manager)
        GODDESS_EQUIP_UI_TUTORIAL_CHECK(goddess_equip_manager)
        if btn:GetName() == "cch_in_btn" then
            btn:SetUserValue("AG_STEP", 1)
            btn:RunUpdateScript("Cc_helper_in_btn_agm", 0.1)
        else
            btn:SetUserValue("AG_STEP", 1)
            btn:RunUpdateScript("Cc_helper_out_btn_agm", 0.1)
        end
    end
end

function Cc_helper_in_btn_agm(in_btn)
    local inventory = ui.GetFrame("inventory")
    if inventory:IsVisible() == 0 then
        in_btn:StopUpdateScript("Cc_helper_in_btn_agm")
        return 0
    end
    local ag_step = in_btn:GetUserIValue("AG_STEP")
    local goddess_equip_manager = ui.GetFrame("goddess_equip_manager")
    local spot_nums = {8, 9, 30}
    local equips = {"RH", "LH", "RH_SUB", "LH_SUB"}
    if ag_step <= 3 then
        local guid = g.cc_helper_guids[equips[ag_step]]
        local equip_item = session.GetEquipItemByGuid(guid)
        if ag_step == 3 then
            DO_WEAPON_SLOT_CHANGE(inventory, 2)
        end
        if not equip_item then
            in_btn:SetUserValue("AG_STEP", ag_step + 1)
        else
            item.UnEquip(spot_nums[ag_step])
        end
        return 1
    end
    if ag_step >= 4 and ag_step <= 7 then
        local gem_index = 2 -- エーテルジェムは2
        local guid = g.cc_helper_guids[equips[ag_step - 3]]
        local inv_item = session.GetInvItemByGuid(guid)
        if inv_item then
            local item_obj = GetIES(inv_item:GetObject())
            GODDESS_MGR_SOCKET_REG_ITEM(goddess_equip_manager, inv_item, item_obj)
            local gem_id = inv_item:GetEquipGemID(gem_index)
            if not gem_id or gem_id ~= 0 then
                _GODDESS_MGR_SOCKET_REQ_GEM_REMOVE(gem_index)
            else
                local spot_name = equips[ag_step - 3]
                if ag_step == 4 then
                    DO_WEAPON_SLOT_CHANGE(inventory, 1)
                elseif ag_step == 6 then
                    DO_WEAPON_SLOT_CHANGE(inventory, 2)
                end
                ITEM_EQUIP(inv_item.invIndex, spot_name)
            end
            return 1
        else
            in_btn:SetUserValue("AG_STEP", ag_step + 1)
        end
        return 1
    end
    g.cc_helper_guids = nil
    goddess_equip_manager:SetLayerLevel(92)
    Cc_helper_putitem(nil, in_btn, nil, 5)
end

function Cc_helper_gem_inv_to_warehouse(in_btn)
    local inventory = ui.GetFrame("inventory")
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    if inventory:IsVisible() == 0 or accountwarehouse:IsVisible() == 0 then
        in_btn:StopUpdateScript("Cc_helper_gem_inv_to_warehouse")
        return 0
    end
    if not g.cc_helper_gem_queue then
        local gem_tab = GET_CHILD_RECURSIVELY(inventory, "inventype_Tab")
        gem_tab:SelectTab(6)
        local required_counts = {}
        for i = 1, 4 do
            local item_data = g.cc_helper_settings[g.cid].items["gem" .. i]
            if item_data and item_data.clsid ~= 0 then
                local id = item_data.clsid
                required_counts[id] = (required_counts[id] or 0) + 1
            end
        end
        local candidates = {}
        local inv_list = session.GetInvItemList()
        local guid_list = inv_list:GetGuidList()
        local cnt = guid_list:Count()
        for i = 0, cnt - 1 do
            local guid = guid_list:Get(i)
            local inv_item = inv_list:GetItemByGuid(guid)
            local obj = GetIES(inv_item:GetObject())
            local id = obj.ClassID
            if required_counts[id] and Cc_helper_checkvalid(inv_item) then
                local level = get_current_aether_gem_level(obj)
                table.insert(candidates, {
                    level = tonumber(level) or 0,
                    iesid = guid,
                    clsid = id,
                    name = obj.Name,
                    inv_item = inv_item
                })
            end
        end
        table.sort(candidates, function(a, b)
            return a.level > b.level
        end)
        local queue = {}
        local added_counts = {}
        for _, gem in ipairs(candidates) do
            local id = gem.clsid
            local limit = required_counts[id] or 0
            local current = added_counts[id] or 0
            if current < limit then
                table.insert(queue, gem)
                added_counts[id] = current + 1
            end
        end
        g.cc_helper_gem_queue = queue
    end
    if #g.cc_helper_gem_queue > 0 then
        local gem_data = g.cc_helper_gem_queue[1]
        local handle = accountwarehouse:GetUserIValue("HANDLE")
        local inv_item = session.GetInvItemByGuid(gem_data.iesid)
        if inv_item then
            local goal_index = Cc_helper_get_goal_index()
            local log = g.lang == "Japanese" and "倉庫に格納しました：[{#EE82EE}" .. gem_data.name ..
                            "{#FFFF00}]×{#EE82EE}1" or "Item to warehousing：[{#EE82EE}" .. gem_data.name ..
                            "{#FFFF00}]×{#EE82EE}1"
            CHAT_SYSTEM(log)
            session.ResetItemList()
            session.AddItemID(gem_data.iesid, 1)
            item.PutItemToWarehouse(IT_ACCOUNT_WAREHOUSE, gem_data.iesid, 1, handle, goal_index)
            return 1
        else
            table.remove(g.cc_helper_gem_queue, 1)
            return 1
        end
    end
    g.cc_helper_gem_queue = nil
    in_btn:StopUpdateScript("Cc_helper_gem_inv_to_warehouse")
    Cc_helper_putitem(nil, in_btn, nil, 6)
    return 0
end

function Cc_helper_mcc_operation(in_btn)
    local monstercardpreset = ui.GetFrame("monstercardpreset")
    if not g.monster_card_changer_ready then
        return 1
    elseif g.monster_card_changer_ready == 1 then
        g.monster_card_changer_ready = 2
        Monster_card_changer_remove(monstercardpreset)
    elseif g.monster_card_changer_ready == 2 then
        return 1
    elseif g.monster_card_changer_ready == 3 then
        g.monster_card_changer_ready = nil
        in_btn:StopUpdateScript("Cc_helper_mcc_operation")
        Cc_helper_putitem(nil, in_btn, nil, 7)
        return 0
    end
    return 1
end
-- takeitem
function Cc_helper_take_item(frame, out_btn, str, step)
    if g.another_warehouse_func == true then
        ui.SysMsg(g.lang == "Japanese" and "[AWH]が作動中です" or "[AWH] is currently operating")
        return
    end
    if step == 0 then
        out_btn:SetUserValue("STEP", 0)
        out_btn:RunUpdateScript("Cc_helper_equip_take_warehouse_item", 0.1)
    elseif step == 1 then
        out_btn:SetUserValue("TRY", 0)
        out_btn:SetUserValue("STEP", 1)
        out_btn:RunUpdateScript("Cc_helper_equip_card", 0.1)
    elseif step == 2 then
        out_btn:SetUserValue("STEP", 2)
        Cc_helper_equips_reserve(out_btn)
    elseif step == 3 then
        out_btn:SetUserValue("TRY", 0)
        out_btn:SetUserValue("STEP", 3)
        out_btn:RunUpdateScript("Cc_helper_equip_card", 0.1)
    elseif step == 4 then
        out_btn:SetUserValue("STEP", 4)
        out_btn:RunUpdateScript("Cc_helper_take_agm_reserve", 0.1)
    elseif step == 5 then
        out_btn:SetUserValue("STEP", 5)
        out_btn:RunUpdateScript("Cc_helper_out_btn_agm_reserve", 0.1)
    elseif step == 6 then
        out_btn:SetUserValue("STEP", 6)
        if g.cc_helper_settings[g.cid].mcc == 1 then
            Cc_helper_end_of_operation(out_btn, 1)
            return
        else
            Cc_helper_take_item(nil, out_btn, nil, 7)
        end
    elseif step == 7 then
        out_btn:SetUserValue("STEP", 7)
        Cc_helper_end_of_operation(out_btn)
    end
end

function Cc_helper_equip_take_warehouse_item(out_btn)
    local req_time = out_btn:GetUserIValue("REQ_TIME")
    if req_time == 0 then
        g.cc_helper_take_guids = {} -- 必ず初期化
        local equip_keys = {"seal", "ark", "relic", "core", "leg", "god", "hair1", "hair2", "hair3"}
        local is_eco = (g.cc_helper_settings.etc.eco == 1)
        local wh_list = session.GetEtcItemList(IT_ACCOUNT_WAREHOUSE)
        session.ResetItemList()
        for _, key in ipairs(equip_keys) do
            if not (is_eco and key == "leg") then
                local item_data = g.cc_helper_settings[g.cid].items[key]
                local iesid = item_data and item_data.iesid or ""
                if iesid ~= "" then
                    if wh_list:GetItemByGuid(iesid) and not session.GetInvItemByGuid(iesid) then
                        session.AddItemID(iesid, 1)
                        table.insert(g.cc_helper_take_guids, iesid)
                    end
                end
            end
        end
        if #g.cc_helper_take_guids == 0 then
            return Cc_helper_equip_take_finish(out_btn)
        end
        local handle = ui.GetFrame("accountwarehouse"):GetUserIValue("HANDLE")
        item.TakeItemFromWarehouse_List(IT_ACCOUNT_WAREHOUSE, session.GetItemIDList(), handle)
        out_btn:SetUserValue("REQ_TIME", imcTime.GetAppTime())
        return 1
    end
    if not g.cc_helper_take_guids or #g.cc_helper_take_guids == 0 then
        ui.SysMsg("{#FF0000}Data Error: Item list lost.")
        return Cc_helper_equip_take_finish(out_btn)
    end
    for _, guid in ipairs(g.cc_helper_take_guids) do
        if not session.GetInvItemByGuid(guid) then
            local elapsed = imcTime.GetAppTime() - req_time
            if elapsed > 3.0 then
                ui.SysMsg(g.lang == "Japanese" and "{#FF0000}倉庫取り出しタイムアウト" or
                              "{#FF0000}Warehouse take timeout")
                return Cc_helper_equip_take_finish(out_btn) -- タイムアウト強制終了
            end
            return 1
        end
    end
    return Cc_helper_equip_take_finish(out_btn)
end

function Cc_helper_equip_take_finish(out_btn)
    out_btn:StopUpdateScript("Cc_helper_equip_take_warehouse_item")
    out_btn:SetUserValue("REQ_TIME", 0)
    g.cc_helper_take_guids = nil
    Cc_helper_update_hair_stats()
    Cc_helper_take_item(nil, out_btn, nil, 1) -- 次のステップへ
    return 0
end

function Cc_helper_equip_card(out_btn)
    local inventory = ui.GetFrame("inventory")
    local monstercardslot = ui.GetFrame("monstercardslot")
    local step = out_btn:GetUserIValue("STEP")
    local try = out_btn:GetUserIValue("TRY")
    local key, card_index, next_step, is_eco_check
    if step == 1 then
        key = "god"
        card_index = 13
        next_step = 2
        is_eco_check = false
    elseif step == 3 then
        key = "leg"
        card_index = 12
        next_step = 4
        is_eco_check = true
    end
    if is_eco_check and g.cc_helper_settings.etc.eco == 1 then
        out_btn:StopUpdateScript("Cc_helper_equip_card")
        Cc_helper_take_item(nil, out_btn, nil, next_step)
        return 0
    end
    local card_id = GETMYCARD_INFO(card_index)
    if card_id == 0 then
        local iesid = g.cc_helper_settings[g.cid].items[key].iesid
        if iesid ~= "" then
            local inv_item = session.GetInvItemByGuid(iesid)
            if inv_item then
                local inv_tab = GET_CHILD_RECURSIVELY(inventory, "inventype_Tab")
                inv_tab:SelectTab(4)
                MONSTERCARDSLOT_FRAME_OPEN()
                local arg_str = string.format("%d#%s", card_index, tostring(iesid))
                pc.ReqExecuteTx("SCR_TX_EQUIP_CARD_SLOT", arg_str)
                return 1
            elseif not inv_item and try <= 4 then
                out_btn:SetUserValue("TRY", try + 1)
                return 1
            end
        end
    end
    out_btn:StopUpdateScript("cc_helper_equip_card")
    Cc_helper_take_item(nil, out_btn, nil, next_step)
    return 0
end

function Cc_helper_equips_reserve(out_btn)
    g.cc_helper_tbl = {{
        ["HAT"] = "hair1"
    }, {
        ["HAT_T"] = "hair2"
    }, {
        ["HAT_L"] = "hair3"
    }, {
        ["SEAL"] = "seal"
    }, {
        ["ARK"] = "ark"
    }, {
        ["RELIC"] = "relic"
    }, {
        ["CORE"] = "core"
    }}
    out_btn:RunUpdateScript("Cc_helper_equips", 0.1)
end

function Cc_helper_equips(out_btn)
    local inventory = ui.GetFrame("inventory")
    local inventype_Tab = GET_CHILD_RECURSIVELY(inventory, "inventype_Tab")
    inventype_Tab:SelectTab(1)
    local function IsEquipable(cls_id)
        local lv = GETMYPCLEVEL()
        local job = GETMYPCJOB()
        local gender = GETMYPCGENDER()
        local prop = geItemTable.GetProp(cls_id)
        if not prop then
            return false
        end
        return prop:CheckEquip(lv, job, gender) == 'OK' and true or false
    end
    for i, data in ipairs(g.cc_helper_tbl) do
        for spot, equip_key in pairs(data) do
            local item_data = g.cc_helper_settings[g.cid].items[equip_key]
            local guid = item_data and item_data.iesid
            if guid and guid ~= "" and guid ~= "0" then
                local is_equipped = session.GetEquipItemByGuid(guid)
                if not is_equipped then
                    local inv_item = session.GetInvItemByGuid(guid)
                    if inv_item then
                        local item_obj = GetIES(inv_item:GetObject())
                        local cls_id = item_obj.ClassID
                        if IsEquipable(cls_id) then
                            ITEM_EQUIP(inv_item.invIndex, spot)
                            return 1
                        end
                    end
                end
            end
        end
    end
    out_btn:StopUpdateScript("Cc_helper_equips")
    Cc_helper_take_item(nil, out_btn, nil, 3)
end

function Cc_helper_take_agm_reserve(out_btn)
    local inventory = ui.GetFrame("inventory")
    local equips = {"RH", "LH", "RH_SUB", "LH_SUB"}
    for _, slot_name in ipairs(equips) do
        local equip_slot = GET_CHILD_RECURSIVELY(inventory, slot_name)
        local icon = equip_slot:GetIcon()
        if icon then
            local icon_info = icon:GetInfo()
            local guid = icon_info:GetIESID()
            local equip_item = session.GetEquipItemByGuid(guid)
            local available = equip_item:IsAvailableSocket(2)
            if not available then
                out_btn:StopUpdateScript("Cc_helper_take_agm_reserve")
                Cc_helper_take_item(nil, out_btn, nil, 6)
                return 0
            end
        end
    end
    local eco = g.cc_helper_settings.etc.eco or 0
    local agm_stop = g.cc_helper_settings.etc.agm_stop or 0
    local agm = g.cc_helper_settings[g.cid].agm
    if eco == 0 and agm_stop == 0 and agm == 1 then
        local equipSlots = {"RH", "LH", "RH_SUB", "LH_SUB"}
        local found_count = 0
        local inventory = ui.GetFrame("inventory")
        for _, slot_name in ipairs(equipSlots) do
            local equipSlot = GET_CHILD_RECURSIVELY(inventory, slot_name)
            local icon = equipSlot:GetIcon()
            if icon then
                local icon_info = icon:GetInfo()
                local guid = icon_info:GetIESID()
                local equip_item = session.GetEquipItemByGuid(guid)
                local gem_id = equip_item:GetEquipGemID(2)
                if gem_id == 0 then
                    found_count = found_count + 1
                end
            end
        end
        if found_count == 4 then
            if g.cc_helper_settings[g.cid].agm_check == 1 then
                local top_frame = out_btn:GetTopParentFrame()
                local msg = g.lang == "Japanese" and "{ol}{#FFFFFF}エーテルジェムを付替えますか？" or
                                "{ol}{#FFFFFF}Would you like to swap Aether Gems?"
                local yes_scp = string.format("Cc_helper_take_msg_func('%s','%s')", top_frame:GetName(),
                    out_btn:GetName())
                local no_scp = string.format("Cc_helper_take_msg_func('%s','%s',%d)", top_frame:GetName(),
                    out_btn:GetName(), 1)
                ui.MsgBox(msg, yes_scp, no_scp)
                return
            else
                out_btn:StopUpdateScript("Cc_helper_take_agm_reserve")
                Cc_helper_take_agm(out_btn)
                return 0
            end
        end
    end
    out_btn:StopUpdateScript("Cc_helper_take_agm_reserve")
    Cc_helper_take_item(nil, out_btn, nil, 6)
    return 0
end

function Cc_helper_take_msg_func(top_frame_name, out_btn_name, is_no_scp)
    local top_frame = ui.GetFrame(top_frame_name)
    local out_btn = GET_CHILD(top_frame, "cch_out_btn")
    if not is_no_scp then
        Cc_helper_take_agm(out_btn)
    else
        Cc_helper_take_item(nil, out_btn, nil, 6)
    end
end

function Cc_helper_take_agm(out_btn)
    local inventory = ui.GetFrame("inventory")
    local inv_tab = GET_CHILD_RECURSIVELY(inventory, "inventype_Tab")
    inv_tab:SelectTab(6)
    local gems = {}
    for i = 1, 4 do
        local clsid = g.cc_helper_settings[g.cid].items["gem" .. i].clsid
        if clsid ~= 0 then
            gems[clsid] = true
        end
    end
    g.cc_helper_take_gems = {}
    local item_list = session.GetEtcItemList(IT_ACCOUNT_WAREHOUSE)
    local sorted_guid_list = item_list:GetSortedGuidList()
    local sorted_cnt = sorted_guid_list:Count()
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    local handle = accountwarehouse:GetUserIValue("HANDLE")
    for i = 0, sorted_cnt - 1 do
        local iesid = sorted_guid_list:Get(i)
        local awh_item = item_list:GetItemByGuid(iesid)
        local type = awh_item.type
        local obj = GetIES(awh_item:GetObject())
        if gems[type] then
            local level = get_current_aether_gem_level(obj)
            table.insert(g.cc_helper_take_gems, {
                level = tonumber(level) or 0,
                iesid = iesid,
                clsid = type,
                loc = "warehouse"
            })
        end
    end
    local inv_item_list = session.GetInvItemList()
    local guid_list = inv_item_list:GetGuidList()
    local cnt = guid_list:Count()
    for i = 0, cnt - 1 do
        local guid = guid_list:Get(i)
        local inv_item = inv_item_list:GetItemByGuid(guid)
        local item_obj = GetIES(inv_item:GetObject())
        local cls_id = item_obj.ClassID
        if gems[cls_id] then
            local level = get_current_aether_gem_level(item_obj)
            table.insert(g.cc_helper_take_gems, {
                level = tonumber(level) or 0,
                iesid = guid,
                clsid = cls_id,
                loc = "inventory"
            })
        end
    end
    table.sort(g.cc_helper_take_gems, function(a, b)
        return a.level > b.level
    end)
    if #g.cc_helper_take_gems < 4 then
        local msg = g.lang == "Japanese" and "{ol}指定のエーテルジェムが4個ありません" or
                        "{ol}You don't have 4 of the Aether Gems"
        ui.SysMsg(msg)
        Cc_helper_take_item(nil, out_btn, nil, 6)
        return
    end
    session.ResetItemList()
    local take_count = 0
    for i = 1, 4 do
        if g.cc_helper_take_gems[i].loc == "warehouse" then
            session.AddItemID(g.cc_helper_take_gems[i].iesid, 1)
            take_count = take_count + 1
        end
    end
    if take_count > 0 then
        item.TakeItemFromWarehouse_List(IT_ACCOUNT_WAREHOUSE, session.GetItemIDList(), handle)
    end
    Cc_helper_take_item(nil, out_btn, nil, 5)
end

function Cc_helper_out_btn_agm_reserve(out_btn)
    g.Cc_helper_gem_guids = {}
    local eq_count = 0
    local equips = {"RH_SUB", "LH_SUB", "RH", "LH"}
    local inventory = ui.GetFrame("inventory")
    for _, slot_name in ipairs(equips) do
        local equip_slot = GET_CHILD_RECURSIVELY(inventory, slot_name)
        local icon = equip_slot:GetIcon()
        if icon then
            local icon_info = icon:GetInfo()
            local iesid = icon_info:GetIESID()
            if not g.Cc_helper_gem_guids[slot_name] then
                g.Cc_helper_gem_guids[slot_name] = iesid
                eq_count = eq_count + 1
            end
        end
    end
    if eq_count == 4 then
        out_btn:StopUpdateScript("Cc_helper_out_btn_agm_reserve")
        Cc_helper_start_agm(out_btn)
        return 0
    end
    local msg = g.lang == "Japanese" and "{ol}武器4ヶ所着けてください" or
                    "{ol}Please equip weapons in 4 slots"
    ui.SysMsg(msg)
    out_btn:StopUpdateScript("Cc_helper_out_btn_agm_reserve")
    cc_helper_take_item(nil, out_btn, nil, 6)
    return 0
end

function Cc_helper_out_btn_agm(out_btn)
    local inventory = ui.GetFrame("inventory")
    if inventory:IsVisible() == 0 then
        out_btn:StopUpdateScript("Cc_helper_out_btn_agm")
        return 0
    end
    local ag_step = out_btn:GetUserIValue("AG_STEP")
    local goddess_equip_manager = ui.GetFrame("goddess_equip_manager")
    local spot_nums = {8, 9, 30}
    local equips = {"RH", "LH", "RH_SUB", "LH_SUB"}
    if ag_step <= 3 then
        local guid = g.Cc_helper_gem_guids[equips[ag_step]]
        local equip_item = session.GetEquipItemByGuid(guid)
        if ag_step == 3 then
            DO_WEAPON_SLOT_CHANGE(inventory, 2)
        end
        if not equip_item then
            out_btn:SetUserValue("AG_STEP", ag_step + 1)
        else
            item.UnEquip(spot_nums[ag_step])
        end
        return 1
    end
    local msg = g.lang == "Japanese" and "エーテルジェムソケットが空いていません" or
                    "The Aether Gem socket is unavailable"
    if ag_step >= 4 and ag_step <= 7 then
        local guid = g.Cc_helper_gem_guids[equips[ag_step - 3]]
        local inv_item = session.GetInvItemByGuid(guid)
        local gem_guid = g.cc_helper_take_gems[ag_step - 3].iesid
        local inv_item = session.GetInvItemByGuid(guid)
        if inv_item then
            local item_obj = GetIES(inv_item:GetObject())
            GODDESS_MGR_SOCKET_REG_ITEM(goddess_equip_manager, inv_item, item_obj)
            local gem_item = session.GetInvItemByGuid(gem_guid)
            if gem_item then
                local gem_obj = GetIES(gem_item:GetObject())
                local ctrl_set = GET_CHILD_RECURSIVELY(goddess_equip_manager, "AETHER_CSET_0")
                local gem_id = ctrl_set:GetUserIValue("GEM_ID")
                if gem_id == 0 then
                    local gem_slot = GET_CHILD(ctrl_set, "gem_slot")
                    GODDESS_MGR_SOCKET_AETHER_GEM_EQUIP(ctrl_set, gem_slot, gem_item, gem_obj)
                end
                return 1
            else
                local spot_name = equips[ag_step - 3]
                if ag_step == 4 then
                    DO_WEAPON_SLOT_CHANGE(inventory, 1)
                elseif ag_step == 6 then
                    DO_WEAPON_SLOT_CHANGE(inventory, 2)
                end
                ITEM_EQUIP(inv_item.invIndex, spot_name)
                return 1
            end
        else
            out_btn:SetUserValue("AG_STEP", ag_step + 1)
            return 1
        end
    end
    out_btn:StopUpdateScript("Cc_helper_out_btn_agm")
    Cc_helper_take_item(nil, out_btn, nil, 6)
    return 0
end

function Cc_helper_change_summoned_pet(companionlist)
    local save_iesid = g.cc_helper_settings[g.cid].items["pet"].iesid
    local save_clsid = g.cc_helper_settings[g.cid].items["pet"].clsid
    local state = companionlist:GetUserValue("FUNCTION_")
    local pet_list = session.pet.GetPetInfoVec()
    for i = 0, pet_list:size() - 1 do
        local info = pet_list:at(i)
        local obj = GetIES(info:GetObject())
        local id = obj.ClassID
        local set_name = "_CTRLSET_" .. i
        local ctrlset = GET_CHILD_RECURSIVELY(companionlist, set_name)
        if ctrlset then
            local slot = GET_CHILD_RECURSIVELY(ctrlset, "slot")
            local icon = slot:GetIcon()
            if icon then
                local icon_info = icon:GetInfo()
                local pet_guid = icon_info:GetIESID()
                if state == "not" then
                    if pet_guid == save_iesid then
                        ICON_USE(icon)
                        break
                    end
                elseif state == "different" then
                    local summoned_pet = session.pet.GetSummonedPet()
                    local summoned_iesid = summoned_pet:GetStrGuid()
                    if pet_guid == summoned_iesid then
                        companionlist:SetUserValue("FUNCTION_", "not")
                        control.SummonPet(0, 0, 0)
                        return 1
                    end
                end
            end
        end
    end
    local function USE_COMPANION_ICON_AFTER_ACTION()
        local can_close = false
        local pet_info = ui.GetFrame("pet_info")
        if pet_info then
            if pet_info:IsVisible() == 0 then
                can_close = true
            end
        else
            can_close = true
        end
        if can_close == true then
            CLOSE_COMPANIONLIST()
            CLOSE_PETLIST()
        end
    end
    USE_COMPANION_ICON_AFTER_ACTION()
    companionlist:Resize(305, 335)
    return 0
end

function Cc_helper_end_of_operation(btn, is_mcc)
    local inventory = ui.GetFrame("inventory")
    local inventype_Tab = GET_CHILD_RECURSIVELY(inventory, "inventype_Tab")
    if inventype_Tab then
        inventype_Tab:SelectTab(0)
    end
    ui.SysMsg("{ol}[CCH]End of Operation")
    local goddess_equip_manager = ui.GetFrame("goddess_equip_manager")
    goddess_equip_manager:ShowWindow(0)
    local monstercardslot = ui.GetFrame("monstercardslot")
    if monstercardslot:IsVisible() == 1 and not is_mcc then
        monstercardslot:RunUpdateScript("MONSTERCARDSLOT_CLOSE", 0.5)
    end
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    if g.cc_helper_settings.etc.wh_close == 1 and not is_mcc then
        ACCOUNTWAREHOUSE_CLOSE()
    elseif is_mcc == 1 then
        Monster_card_changer_monstercardpreset_open(1)
    end
    local btn_name = btn:GetName()
    if btn_name == "cch_out_btn" then
        local save_clsid = g.cc_helper_settings[g.cid].items["pet"].clsid
        if save_clsid ~= 0 then
            local companionlist = ui.GetFrame("companionlist")
            companionlist:Resize(0, 0)
            local summoned_pet = session.pet.GetSummonedPet()
            if not summoned_pet then
                ON_OPEN_COMPANIONLIST()
                companionlist:SetUserValue("FUNCTION_", "not")
                companionlist:RunUpdateScript("Cc_helper_change_summoned_pet", 0.5)
            else -- Different
                local summoned_iesid = summoned_pet:GetStrGuid()
                local save_iesid = g.cc_helper_settings[g.cid].items["pet"].iesid
                if summoned_iesid ~= save_iesid then
                    ON_OPEN_COMPANIONLIST()
                    companionlist:SetUserValue("FUNCTION_", "different")
                    companionlist:RunUpdateScript("Cc_helper_change_summoned_pet", 0.5)
                end
            end
        end
    end
    return 0
end

function Cc_helper_hair_option(item_obj)
    local str = ""
    local rank = shared_enchant_special_option.get_item_rank(item_obj)
    for i = 1, 3 do
        local prop_name = "HatPropName_" .. i
        local prop_value = "HatPropValue_" .. i
        if item_obj[prop_value] ~= 0 and item_obj[prop_name] ~= "None" then
            if not string.find(item_obj[prop_name], "ALLSKILL_") then
                str = str .. item_obj[prop_name] .. "/" .. item_obj[prop_value]
            else
                local job = StringSplit(item_obj[prop_name], "_")[2]
                if job == "ShadowMancer" then
                    job = "Shadowmancer"
                end
                str = str .. job
            end
            str = str .. ":::"
        end
    end
    str = str:gsub(" - ", "")
    str = str:gsub("-", "")
    return str, rank
end

function Cc_helper_update_hair_stats()
    local hairs = {"hair1", "hair2", "hair3"}
    local is_updated = false
    local copys = g.cc_helper_settings.etc and g.cc_helper_settings.etc.copys
    for _, key in ipairs(hairs) do
        local item_data = g.cc_helper_settings[g.cid].items[key]
        if item_data and item_data.iesid ~= "" then
            local guid = item_data.iesid
            local inv_item = session.GetInvItemByGuid(item_data.iesid)
            if not inv_item then
                inv_item = session.GetEquipItemByGuid(guid)
            end
            if not inv_item then
                local accountwarehouse = ui.GetFrame("accountwarehouse")
                if accountwarehouse and accountwarehouse:IsVisible() == 1 then
                    inv_item = session.GetEtcItemByGuid(IT_ACCOUNT_WAREHOUSE, guid)
                end
            end
            if inv_item then
                local obj = GetIES(inv_item:GetObject())
                local option, rank = Cc_helper_hair_option(obj)
                if item_data.option ~= option or item_data.rank ~= rank then
                    item_data.option = option
                    item_data.rank = rank
                    is_updated = true
                end
                if copys then
                    for cid, char_data in pairs(copys) do
                        if char_data.items then
                            for copy_key, copy_item_data in pairs(char_data.items) do
                                if copy_item_data.iesid == guid then
                                    if copy_item_data.option ~= option or copy_item_data.rank ~= rank then
                                        copy_item_data.option = option
                                        copy_item_data.rank = rank
                                        is_updated = true
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if is_updated then
        Cc_helper_save_settings()
    end
end

function Cc_helper_checkvalid(inv_item)
    local acc_obj = GetMyAccountObj()
    local max_count = acc_obj.BasicAccountWarehouseSlotCount + acc_obj.MaxAccountWarehouseCount +
                          acc_obj.AccountWareHouseExtend + acc_obj.AccountWareHouseExtendByItem
    if session.loginInfo.IsPremiumState(ITEM_TOKEN) then
        max_count = max_count + ADDITIONAL_SLOT_COUNT_BY_TOKEN + 280
    end
    local item_list = session.GetEtcItemList(IT_ACCOUNT_WAREHOUSE)
    local item_count = item_list:GetSortedGuidList():Count()
    if max_count <= item_count then
        ui.SysMsg(ClMsg("CannotPutBecauseMaxSlot"))
        return false
    end
    if true == inv_item.isLockState then
        ui.SysMsg(ClMsg("MaterialItemIsLock"))
        return false
    end
    local obj = GetIES(inv_item:GetObject())
    local item_cls = GetClassByType("Item", obj.ClassID)
    if item_cls.ItemType == "Quest" then
        ui.MsgBox(ScpArgMsg("IT_ISNT_REINFORCEABLE_ITEM"))
        return false
    end
    local enable_team_trade = TryGetProp(item_cls, "TeamTrade")
    if not enable_team_trade and enable_team_trade == "NO" then
        ui.SysMsg(ClMsg("ItemIsNotTradable"))
        return false
    end
    if TryGetProp(obj, "CharacterBelonging", 0) == 1 then
        ui.SysMsg(ClMsg("ItemIsNotTradable"))
        return false
    end
    return true
end

function Cc_helper_get_goal_index()
    local acc_obj = GetMyAccountObj()
    local base_count = acc_obj.BasicAccountWarehouseSlotCount + acc_obj.MaxAccountWarehouseCount +
                           acc_obj.AccountWareHouseExtend + acc_obj.AccountWareHouseExtendByItem
    local tab_index = {4, 3, 2, 1, 0}
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    local tab = GET_CHILD(accountwarehouse, "accountwarehouse_tab")
    local slotset = GET_CHILD_RECURSIVELY(accountwarehouse, "slotset")
    for index = 1, #tab_index do
        local i = tab_index[index]
        tab:SelectTab(i)
        if i > 0 and session.loginInfo.IsPremiumState(ITEM_TOKEN) then
            local itemcnt = GET_CHILD_RECURSIVELY(accountwarehouse, "itemcnt")
            local num_str = string.match(itemcnt:GetText(), "{@st42}(%d+)/")
            local left = tonumber(num_str)
            if left < 70 then
                return ((i - 1) * 70) + base_count + ADDITIONAL_SLOT_COUNT_BY_TOKEN + left + 1
            end
        else
            for j = 1, base_count do
                local slot = slotset:GetSlotByIndex(j)
                AUTO_CAST(slot)
                if slot:GetIcon() == nil then
                    return j
                end
            end
        end
    end
end
-- cc_helper ここまで

