-- another_warehouse ここから
function Another_warehouse_save_settings()
    g.save_lua(g.another_warehouse_path, g.awh_settings)
end

function Another_warehouse_load_settings()
    g.another_warehouse_path = string.format("../addons/%s/%s/another_warehouse.lua", addon_name_lower, g.active_id)
    local json_path = string.format("../addons/%s/%s/another_warehouse.json", addon_name_lower, g.active_id)
    g.another_warehouse_old_path = string.format("../addons/%s/%s/settings.json", "another_warehouse", g.active_id)
    local settings = g.load_lua(g.another_warehouse_path)
    local need_save = false
    local ver = 1.1 -- ■ バージョン定義
    if not settings then
        settings = g.load_json(json_path)
        if settings then
            need_save = true
        end
    end
    if not settings then
        local old_settings = g.load_json(g.another_warehouse_old_path)
        if old_settings then
            local new_take_set = {}
            local old_items_map = old_settings.setitems or {}
            local old_names_list = old_settings.handlelist or {}
            for i, name in ipairs(old_names_list) do
                local index_str = tostring(i)
                local items = old_items_map[index_str]
                if items then
                    table.insert(new_take_set, {
                        name = name,
                        items = items
                    })
                end
            end
            settings = {
                chars = {},
                etc = {
                    display_change = 0,
                    leave_item = 0,
                    auto_silver = 0
                },
                take_list = new_take_set,
                items = old_settings.items or {},
                ver = ver
            }
        else
            local new_take_set = {}
            for i = 1, 10 do
                table.insert(new_take_set, {
                    name = "Take Items " .. i,
                    items = {}
                })
            end
            settings = {
                chars = {},
                etc = {
                    display_change = 0,
                    leave_item = 0,
                    auto_silver = 0
                },
                take_list = new_take_set,
                items = {},
                ver = ver
            }
        end
        need_save = true
    end
    if not settings.ver or settings.ver < ver then
        if not settings.take_list then
            settings.take_list = {}
        end
        while #settings.take_list < 10 do
            local next_num = #settings.take_list + 1
            table.insert(settings.take_list, {
                name = "Take Items " .. next_num,
                items = {}
            })
        end
        settings.ver = ver
        need_save = true
    end
    g.awh_settings = settings
    if need_save then
        Another_warehouse_save_settings()
    end
end

function Another_warehouse_load_cid_settings()
    local json_path = string.format("../addons/%s/%s/another_warehouse.json", addon_name_lower, g.active_id)
    local json_settings = g.load_json(json_path)
    if json_settings and json_settings.chars and json_settings.chars[g.cid] then
        g.awh_settings.chars[g.cid] = json_settings.chars[g.cid]
    else
        local old_settings = g.load_json(g.another_warehouse_old_path)
        if old_settings and old_settings[g.cid] then
            g.awh_settings.chars[g.cid] = old_settings[g.cid]
            local char_data = g.awh_settings.chars[g.cid]
            if char_data.transfer then
                char_data.transfer = nil
            end
            if char_data.maney_check then
                char_data.money_check = char_data.maney_check
                char_data.maney_check = nil
            end
        else
            g.awh_settings.chars[g.cid] = {
                money_check = 0,
                name = g.login_name,
                item_check = 0,
                items = {}
            }
        end
    end
    Another_warehouse_save_settings()
end

function another_warehouse_on_init()
    if not g.awh_settings then
        Another_warehouse_load_settings()
    end
    if not g.awh_settings.chars[g.cid] then
        Another_warehouse_load_cid_settings()
    end
    local old_func = g.settings.another_warehouse.old_init_func
    if _G[old_func] then
        return
    end
    g.setup_hook_and_event(g.addon, 'ACCOUNT_WAREHOUSE_UPDATE_VIS_LOG',
        "Another_warehouse_ACCOUNT_WAREHOUSE_UPDATE_VIS_LOG", true)
    g.setup_hook_and_event(g.addon, 'ACCOUNTWAREHOUSE_CLOSE', "Another_warehouse_ACCOUNTWAREHOUSE_CLOSE", true)
    g.addon:RegisterMsg("OPEN_DLG_ACCOUNTWAREHOUSE", "Another_warehouse_OPEN_DLG_ACCOUNTWAREHOUSE")
    if g.settings.another_warehouse.use == 0 then
        Another_warehouse_frame_close()
        return
    end
    if g.get_map_type() == "City" then
        Another_warehouse_accountwarehouse_init()
    end
end

function Another_warehouse_accountwarehouse_init()
    g.another_warehouse_func = false
    if g.settings.another_warehouse.use == 0 then
        Another_warehouse_frame_close()
        return
    end
    g.addon:RegisterMsg("ACCOUNT_WAREHOUSE_ITEM_LIST", "Another_warehouse_on_msg")
    g.addon:RegisterMsg("ACCOUNT_WAREHOUSE_ITEM_ADD", "Another_warehouse_on_msg")
    g.addon:RegisterMsg("ACCOUNT_WAREHOUSE_ITEM_REMOVE", "Another_warehouse_on_msg")
    g.addon:RegisterMsg("ACCOUNT_WAREHOUSE_ITEM_CHANGE_COUNT", "Another_warehouse_on_msg")
    g.addon:RegisterMsg("ACCOUNT_WAREHOUSE_ITEM_IN", "Another_warehouse_on_msg")
    if type(_G["YAACCOUNTINVENTORY_ON_INIT"]) == "function" then
        _G["YAACCOUNTINVENTORY_ON_INIT"] = nil
    end
    local functionName = "WAREHOUSEMANAGER_ON_INIT"
    if type(_G["WAREHOUSEMANAGER_ON_INIT"]) == "function" then
        _G["WAREHOUSEMANAGER_ON_INIT"] = nil
    end
    g.awh_new_stack_add_item = {}
end

function Another_warehouse_on_msg(frame, msg, str, num)
    if g.settings.another_warehouse.use == 0 then
        return
    end
    local awh = ui.GetFrame(addon_name_lower .. "awh")
    local gb = GET_CHILD(awh, "gb")
    AUTO_CAST(gb)
    local cur_pos = gb:GetScrollCurPos()
    awh:SetUserValue("SCROLL_POS", cur_pos)
    if msg == 'ACCOUNT_WAREHOUSE_ITEM_REMOVE' then
        Another_warehouse_remove_recurse_guid(awh, str)
        awh:RunUpdateScript("Another_warehouse_frame_update_remove", 3.0)
        return
    end
    local index = awh:GetUserIValue("TAB_INDEX")
    Another_warehouse_frame_update(awh, gb, "", index)
end

function Another_warehouse_frame_update_remove(awh)
    awh:StopUpdateScript("Another_warehouse_frame_update_remove")
    local gb = GET_CHILD(awh, "gb")
    AUTO_CAST(gb)
    local index = awh:GetUserIValue("TAB_INDEX")
    Another_warehouse_frame_update(awh, gb, "", index)
    return 0
end

function Another_warehouse_remove_recurse_guid(awh, guid)
    local slot = ui.GetFocusObject()
    if not slot then
        return
    end
    local icon = slot:GetIcon()
    if icon then
        local icon_info = icon:GetInfo()
        if icon_info:GetIESID() == guid then
            slot:ClearIcon()
            slot:SetSkinName("invenslot2")
            slot:SetText("")
            slot:RemoveAllChild()
        end
    end
end

function Another_warehouse_ACCOUNT_WAREHOUSE_UPDATE_VIS_LOG(my_frame, my_msg)
    if g.settings.another_warehouse.use == 0 then
        Another_warehouse_frame_close()
        return
    end
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    local visgBox = GET_CHILD_RECURSIVELY(accountwarehouse, 'visgBox')
    local cnt = session.AccountWarehouse.GetCount()
    for i = cnt - 1, 0, -1 do
        local log = session.AccountWarehouse.GetByIndex(i)
        local ctrl_set = GET_CHILD(visgBox, "CTRLSET_" .. i)
        local inputVis = ctrl_set:GetChild('inputVis')
        inputVis:ShowWindow(0)
        local new_input = ctrl_set:CreateOrGetControl("richtext", " new_input", 220, i, 50, 24)
        AUTO_CAST(new_input)
        new_input:SetGravity(ui.RIGHT, ui.CENTER_VERT)
        new_input:SetMargin(0, 0, 330, 0)
        new_input:SetTextAlign("right", "center")
        if not string.find(inputVis:GetText(), "ZZZZZ") then
            new_input:SetText(inputVis:GetText())
        end
    end
end

function Another_warehouse_ACCOUNTWAREHOUSE_CLOSE()
    local inventory = ui.GetFrame("inventory")
    SET_INV_LBTN_FUNC(inventory, "None")
    INVENTORY_SET_CUSTOM_RBTNDOWN("None")
    local monstercardslot = ui.GetFrame("monstercardslot")
    monstercardslot:SetLayerLevel(96)
    ui.DestroyFrame(addon_name_lower .. "awh")
    ui.DestroyFrame(addon_name_lower .. "awh_setting")
    if g.settings.another_warehouse.use == 0 then
        return
    end
    Another_warehouse_set_item_close()
end

function Another_warehouse_frame_close(parent, ctrl)
    Another_warehouse_ACCOUNTWAREHOUSE_CLOSE()
    local accountwarehouse = ui.GetFrame('accountwarehouse')
    if accountwarehouse:IsVisible() == 1 then
        INVENTORY_SET_CUSTOM_RBTNDOWN("ACCOUNT_WAREHOUSE_INV_RBTN")
    else
        INVENTORY_SET_CUSTOM_RBTNDOWN("None")
    end
    ui.DestroyFrame(addon_name_lower .. "awh")
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    local accountwarehousefilter = GET_CHILD_RECURSIVELY(accountwarehouse, "accountwarehousefilter")
    accountwarehousefilter:ShowWindow(1)
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    local accountwarehouse_tab = GET_CHILD_RECURSIVELY(accountwarehouse, "accountwarehouse_tab")
    accountwarehouse_tab:ShowWindow(1)
    local richtext_1 = GET_CHILD_RECURSIVELY(accountwarehouse, "richtext_1")
    richtext_1:ShowWindow(1)
    local itemcnt = GET_CHILD_RECURSIVELY(accountwarehouse, "itemcnt")
    itemcnt:ShowWindow(1)
    local slotgbox = GET_CHILD_RECURSIVELY(accountwarehouse, "slotgbox")
    slotgbox:ShowWindow(1)
    local richtext_3 = GET_CHILD_RECURSIVELY(accountwarehouse, "richtext_3")
    richtext_3:ShowWindow(1)
    local DepositSkin = accountwarehouse:GetChildRecursively("DepositSkin")
    AUTO_CAST(DepositSkin)
    DepositSkin:Resize(DepositSkin:GetWidth(), 35)
    local buttons = {"cancel", "m1", "m5", "m10", "m50", "m100", "allout", "allin"}
    for _, name in ipairs(buttons) do
        DepositSkin:RemoveChild(name)
    end
    local gbox = GET_CHILD_RECURSIVELY(accountwarehouse, "gbox")
    DESTROY_CHILD_BYNAME(gbox, "awh_search_edit")
    DESTROY_CHILD_BYNAME(gbox, "awh_setting")
    DESTROY_CHILD_BYNAME(gbox, "awh_help")
    DESTROY_CHILD_BYNAME(gbox, "awh_leave")
    DESTROY_CHILD_BYNAME(gbox, "awh_display_change")
    DESTROY_CHILD_BYNAME(gbox, "awh_take")
    DESTROY_CHILD_BYNAME(gbox, "awh_count_text")
    DESTROY_CHILD_BYNAME(gbox, "awh_close")
    DESTROY_CHILD_BYNAME(gbox, "awh_name_text")
end

function Another_warehouse_OPEN_DLG_ACCOUNTWAREHOUSE()
    if g.settings.another_warehouse.use == 0 then
        local accountwarehouse = ui.GetFrame('accountwarehouse')
        if accountwarehouse:IsVisible() == 1 then
            INVENTORY_SET_CUSTOM_RBTNDOWN("ACCOUNT_WAREHOUSE_INV_RBTN")
        else
            INVENTORY_SET_CUSTOM_RBTNDOWN("None")
        end
        return
    end
    local monstercardslot = ui.GetFrame("monstercardslot")
    monstercardslot:SetLayerLevel(98)
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    local accountwarehousefilter = GET_CHILD_RECURSIVELY(accountwarehouse, "accountwarehousefilter")
    accountwarehousefilter:ShowWindow(0)
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    local accountwarehouse_tab = GET_CHILD_RECURSIVELY(accountwarehouse, "accountwarehouse_tab")
    accountwarehouse_tab:ShowWindow(0)
    local richtext_1 = GET_CHILD_RECURSIVELY(accountwarehouse, "richtext_1")
    richtext_1:ShowWindow(0)
    local itemcnt = GET_CHILD_RECURSIVELY(accountwarehouse, "itemcnt")
    itemcnt:ShowWindow(0)
    local slotgbox = GET_CHILD_RECURSIVELY(accountwarehouse, "slotgbox")
    slotgbox:ShowWindow(0)
    local richtext_3 = GET_CHILD_RECURSIVELY(accountwarehouse, "richtext_3")
    richtext_3:ShowWindow(0)
    local gbox = GET_CHILD_RECURSIVELY(accountwarehouse, "gbox")
    gbox:RemoveChild("awh_search_edit")
    local search_edit = gbox:CreateOrGetControl("edit", "awh_search_edit", 0, 0, 295, 35)
    AUTO_CAST(search_edit)
    search_edit:SetFontName("white_18_ol")
    search_edit:SetTextAlign("left", "center")
    search_edit:SetSkinName("inventory_serch")
    local margin = search_edit:GetMargin()
    search_edit:SetMargin(margin.left + 115, margin.top + 20, margin.right, margin.bottom)
    search_edit:SetEventScript(ui.ENTERKEY, "Another_warehouse_search")
    local search_btn = search_edit:CreateOrGetControl("button", "search_btn", 0, 0, 60, 38)
    AUTO_CAST(search_btn)
    search_btn:SetImage("inven_s")
    search_btn:SetGravity(ui.RIGHT, ui.TOP)
    search_btn:SetEventScript(ui.LBUTTONUP, "Another_warehouse_search")
    local awsetting = gbox:CreateOrGetControl("button", "awh_setting", 0, 0, 30, 43)
    AUTO_CAST(awsetting)
    awsetting:SetText("{img config_button_normal 27 27}")
    awsetting:SetEventScript(ui.LBUTTONUP, "Another_warehouse_setting_frame_init")
    awsetting:SetMargin(145, 60, 0, 0)
    awsetting:SetSkinName("None")
    awsetting:SetTextTooltip(g.lang == "Japanese" and "{ol}[AWH]{nl}自動倉庫設定" or
                                 "{ol}[AWH]{nl}Automatic warehousing setup")
    local help = gbox:CreateOrGetControl('button', "awh_help", 0, 0, 30, 30)
    AUTO_CAST(help);
    help:SetText("{ol}{img question_mark 20 20}")
    help:SetMargin(115, 67, 0, 0)
    help:SetTextTooltip("{ol}[AWH] HELP")
    help:SetSkinName("test_pvp_btn")
    help:SetEventScript(ui.LBUTTONUP, "Another_warehouse_help")
    local leave = gbox:CreateOrGetControl('checkbox', "awh_leave", 0, 0, 30, 30)
    AUTO_CAST(leave);
    leave:SetCheck(g.awh_settings.etc.leave_item)
    leave:SetMargin(180, 67, 0, 0)
    leave:SetEventScript(ui.LBUTTONUP, "Another_warehouse_setting_check")
    local tooltip_text = g.lang == "Japanese" and "{ol}チェックすると倉庫に1個残します" or
                             "{ol}Check leaves one in the warehouse"
    leave:SetTextTooltip(tooltip_text)
    local display_change = gbox:CreateOrGetControl('checkbox', "awh_display_change", 0, 0, 30, 30)
    AUTO_CAST(display_change);
    display_change:SetCheck(g.awh_settings.etc.display_change or 0)
    display_change:SetMargin(215, 67, 0, 0)
    display_change:SetEventScript(ui.LBUTTONUP, "Another_warehouse_setting_check")
    local tooltip_text = g.lang == "Japanese" and "{ol}チェックすると表示切替" or
                             "{ol}Check to switch display"
    display_change:SetTextTooltip(tooltip_text)
    display_change:ShowWindow(1)
    local take = gbox:CreateOrGetControl("button", "awh_take", 10, 0, 100, 43)
    AUTO_CAST(take)
    take:SetText("{@st66b}TAKE SET")
    take:SetEventScript(ui.LBUTTONUP, "Another_warehouse_take_context")
    take:SetEventScript(ui.RBUTTONUP, "Another_warehouse_setting_context")
    take:SetMargin(310, 60, 0, 0)
    take:SetSkinName("test_pvp_btn")
    take:SetTextTooltip(g.lang == "Japanese" and
                            "{ol}左クリック: 倉庫からセットで搬出します{nl}右クリック: セット設定を呼び出します" or
                            "{ol}left-click: Move set from warehouse{nl}Right-click: Call up set settings")
    local max_count = Another_warehouse_get_maxcount()
    local item_count = Another_warehouse_item_count()
    local count_text = gbox:CreateOrGetControl("richtext", "awh_count_text", 0, 0, 200, 24)
    AUTO_CAST(count_text)
    count_text:SetMargin(420, 73, 0, 0)
    count_text:SetText("{@st42}" .. item_count .. "/" .. max_count .. "{/}")
    count_text:SetFontName("white_16_ol")
    local awclose = gbox:CreateOrGetControl("button", "awh_close", 10, 0, 100, 43)
    AUTO_CAST(awclose)
    awclose:SetText("{@st66b}AW CLOSE")
    awclose:SetEventScript(ui.LBUTTONUP, "Another_warehouse_frame_close")
    awclose:SetMargin(10, 60, 0, 0)
    awclose:SetSkinName("test_pvp_btn")
    local name_text = gbox:CreateOrGetControl("richtext", "awh_name_text", 15, 0, 200, 24)
    AUTO_CAST(name_text)
    name_text:SetMargin(10, 10, 0, 0)
    name_text:SetText("{#000000}{s18}" .. g.login_name .. "{/}")
    Another_warehouse_frame_over_lap()
    Another_warehouse_money_input_btn(accountwarehouse)
end

function Another_warehouse_money_input_btn(accountwarehouse)
    local DepositSkin = accountwarehouse:GetChildRecursively("DepositSkin")
    AUTO_CAST(DepositSkin)
    DepositSkin:Resize(DepositSkin:GetWidth(), 45)
    local moneyInput = accountwarehouse:GetChildRecursively("moneyInput")
    AUTO_CAST(moneyInput)
    moneyInput:SetText("0")
    local buttons = {{
        name = "cancel",
        text = "C",
        val = 0
    }, {
        name = "m1",
        text = "1M",
        val = 1000000
    }, {
        name = "m5",
        text = "5M",
        val = 5000000
    }, {
        name = "m10",
        text = "10M",
        val = 10000000
    }, {
        name = "m50",
        text = "50M",
        val = 50000000
    }, {
        name = "m100",
        text = "100M",
        val = 100000000
    }, {
        name = "allout",
        text = "{img chul_arrow 10 10}ALL",
        val = nil
    }, {
        name = "allin",
        text = "{img in_arrow 10 10}ALL",
        val = nil
    }}
    local text_style = "{@st66b}{s12}"
    for i, data in ipairs(buttons) do
        local x_offset = i * 50
        local btn = DepositSkin:CreateOrGetControl("button", data.name, DepositSkin:GetWidth() - x_offset,
            DepositSkin:GetHeight() - 23, 50, 25)
        AUTO_CAST(btn)
        btn:SetText(text_style .. data.text)
        btn:SetSkinName("test_pvp_btn")
        btn:SetEventScript(ui.LBUTTONUP, "Another_warehouse_money_input_lbtn")
        if data.val ~= nil then
            btn:SetEventScriptArgNumber(ui.LBUTTONUP, data.val)
            btn:SetEventScript(ui.RBUTTONUP, "Another_warehouse_money_input_rbtn")
            btn:SetEventScriptArgNumber(ui.RBUTTONUP, data.val)
        end
    end
end

function Another_warehouse_money_input_lbtn(parent, ctrl, str, num)
    local accountwarehouse = ctrl:GetTopParentFrame()
    local moneyInput = accountwarehouse:GetChildRecursively("moneyInput")
    AUTO_CAST(moneyInput)
    local handle = accountwarehouse:GetUserIValue('HANDLE')
    if ctrl:GetName() == "allout" then
        local item_list = session.GetEtcItemList(IT_ACCOUNT_WAREHOUSE)
        local guid_list = item_list:GetGuidList()
        local sorted_guid_list = item_list:GetSortedGuidList()
        local sorted_cnt = sorted_guid_list:Count()
        local iesid
        for i = 0, sorted_cnt - 1 do
            local guid = sorted_guid_list:Get(i)
            local inv_item = item_list:GetItemByGuid(guid)
            local obj = GetIES(inv_item:GetObject());
            if obj.ClassName == MONEY_NAME then
                moneyInput:SetText(GET_COMMAED_STRING(inv_item:GetAmountStr()))
                return
            end
        end
        moneyInput:SetText("0")
    elseif ctrl:GetName() == "allin" then
        local silver = session.GetInvItemByName(MONEY_NAME)
        if silver then
            moneyInput:SetText(GET_COMMAED_STRING(silver:GetAmountStr()))
        else
            moneyInput:SetText("0")
        end
    elseif ctrl:GetName() == "cancel" then
        moneyInput:SetText("0")
    else
        local current_val_str = string.gsub(moneyInput:GetText(), ",", "")
        local current_val = tonumber(current_val_str) or 0
        moneyInput:SetText(GET_COMMAED_STRING(SumForBigNumberInt64(current_val, "+" .. num)))
    end
end

function Another_warehouse_money_input_rbtn(parent, ctrl, str, num)
    local accountwarehouse = ctrl:GetTopParentFrame()
    local moneyInput = accountwarehouse:GetChildRecursively("moneyInput")
    AUTO_CAST(moneyInput)
    if ctrl:GetName() == "cancel" then
        moneyInput:SetText("0")
        return
    end
    local current_val_str = string.gsub(moneyInput:GetText(), ",", "")
    local current_val = tonumber(current_val_str) or 0
    if (current_val - num) > 0 then
        moneyInput:SetText(GET_COMMAED_STRING(SumForBigNumberInt64(current_val, "-" .. num)))
    else
        moneyInput:SetText("0")
    end
end

function Another_warehouse_frame_over_lap()
    local awh = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "awh", 0, 0, 670, 570)
    AUTO_CAST(awh)
    awh:SetGravity(ui.LEFT, ui.TOP)
    awh:MoveFrame(0, 0)
    awh:SetOffset(0, 205)
    awh:SetSkinName("None")
    awh:EnableMove(0)
    awh:EnableHittestFrame(1)
    awh:SetLayerLevel(97)
    awh:RemoveAllChild()
    local gb = awh:CreateOrGetControl("groupbox", "gb", 45, 0, 0, 0)
    AUTO_CAST(gb)
    gb:EnableScrollBar(1)
    gb:SetSkinName("test_frame_midle")
    awh:Resize(670, 570)
    gb:Resize(613, 560)
    awh:ShowWindow(1)
    local inventory = ui.GetFrame("inventory")
    INVENTORY_SET_CUSTOM_RBTNDOWN("Another_warehouse_inv_rbtn")
    SET_INV_LBTN_FUNC(inventory, "Another_warehouse_inv_lbtn")
    Another_warehouse_tab_change(awh, gb, "", 0)
    Another_warehouse_auto_func_start(awh)
end

function Another_warehouse_tab_change(awh, ctrl, search_text, index)
    local tab_index = awh:GetUserIValue("TAB_INDEX")
    if tab_index ~= index then
        local accountwarehouse = ui.GetFrame("accountwarehouse")
        local search_edit = GET_CHILD_RECURSIVELY(accountwarehouse, "awh_search_edit")
        search_edit:SetText("")
    end
    local tab_tbl = {"inventory_main", "inventory_equip", "inventory_supplies", "inventory_recipe", "inventory_card",
                     "inventory_material", "inventory_gem", "inventory_premium", "inventory_housing", "alchemy_item_tab"}
    for i, image in ipairs(tab_tbl) do
        local tab = awh:CreateOrGetControl("picture", "tab" .. image, 5, (i - 1) * 55, 40, 60)
        AUTO_CAST(tab)
        tab:SetClickSound("inven_arrange")
        tab:SetEventScript(ui.LBUTTONDOWN, "Another_warehouse_tab_change")
        tab:SetEventScriptArgNumber(ui.LBUTTONDOWN, i)
        if i == index then
            tab:SetImage(image .. "_clicked")
            awh:SetUserValue("TAB_INDEX", index)
        else
            tab:SetImage(image)
        end
        tab:SetEnableStretch(1)
    end
    if index == 0 then
        local tab = GET_CHILD(awh, "tab" .. tab_tbl[1])
        tab:SetImage(tab_tbl[1] .. "_clicked")
        awh:SetUserValue("TAB_INDEX", 1)
    end
    local gb = GET_CHILD(awh, "gb")
    AUTO_CAST(gb)
    gb:RemoveAllChild()
    Another_warehouse_frame_update(awh, gb, search_text, index)
end

function Another_warehouse_frame_update(awh, gb, search_text, index)
    local tree = gb:CreateOrGetControl("tree", "inventory_tree", 5, 10, 0, 0)
    AUTO_CAST(tree)
    tree:Clear()
    tree:InvalidateTree()
    tree:EnableDrawFrame(false)
    tree:EnableDrawTreeLine(false)
    tree:SetFitToChild(true, 20) -- 下の余白
    tree:SetFontName("white_20_ol")
    tree:SetTabWidth("15")
    tree:Resize(600, 0)
    local item_list = session.GetEtcItemList(IT_ACCOUNT_WAREHOUSE)
    local sorted_guid_list = item_list:GetSortedGuidList()
    local warehouse_item_list = {}
    local group_counts = {}
    local slotset_counts = {}
    local tab_filter_map = {nil, {
        ["EquipGroup"] = true
    }, {
        ["NonEquipGroup"] = true,
        ["Cube"] = true
    }, {
        ["Recipe"] = true
    }, {
        ["Card"] = true
    }, {
        ["Material"] = true
    }, {
        ["Gem"] = true
    }, {
        ["Premium"] = true
    }, {
        ["Housing"] = true
    }, {
        ["Ancient"] = true,
        ["HiiddenAbility"] = true
    }}
    local current_filter = tab_filter_map[index]
    for i = 0, sorted_guid_list:Count() - 1 do
        local warehouse_item = item_list:GetItemByGuid(sorted_guid_list:Get(i))
        if warehouse_item then
            local item_cls = GetIES(warehouse_item:GetObject())
            local baseid_cls = INV_GET_INVEN_BASEIDCLS_BY_ITEMGUID(warehouse_item:GetIESID())
            if baseid_cls then
                local type_str = GET_INVENTORY_TREEGROUP(baseid_cls)
                if type_str ~= 'Quest' and baseid_cls.ClassName ~= 'Unused' then
                    local make_slot = Another_warehouse_check_search_and_filter(warehouse_item, item_cls, search_text)
                    if make_slot and warehouse_item.count > 0 then
                        local group_name = baseid_cls.TreeGroup
                        local is_visible = (current_filter == nil) or (current_filter[group_name] == true)
                        if is_visible then
                            table.insert(warehouse_item_list, warehouse_item)
                            local group_name = baseid_cls.TreeGroup
                            group_counts[group_name] = (group_counts[group_name] or 0) + 1
                            local className = baseid_cls.ClassName
                            if baseid_cls.MergedTreeTitle ~= "NO" then
                                className = baseid_cls.MergedTreeTitle
                            end
                            local slotset_name = 'sset_' .. className
                            slotset_counts[slotset_name] = (slotset_counts[slotset_name] or 0) + 1
                        end
                    end
                end
            end
        end
    end
    --[[local fix_sort_addon = _G["ADDONS"]["weizlogy"]["fixinventorysort"]

    if fix_sort_addon and type(fix_sort_addon) == "function" then
        local sort_worker = fix_sort_addon()
        if sort_worker and type(sort_worker.Sort) == "function" then
            warehouse_item_list = sort_worker:Sort(warehouse_item_list, false)
        end
    else]]
    table.sort(warehouse_item_list, Another_warehouse_INVENTORY_SORT_BY_NAME)
    local created_groups = {}
    local created_slotsets = {}
    local group_order = {"Premium", "EquipGroup", "NonEquipGroup", "Cube", "Gem", "Card", "Recipe", "Material",
                         "HiiddenAbility", "Ancient"}
    local group_caption_map = {}
    local baseid_list, cnt = GetClassList("inven_baseid")
    for i = 0, cnt - 1 do
        local cls = GetClassByIndexFromList(baseid_list, i)
        if cls.TreeGroup ~= "None" then
            group_caption_map[cls.TreeGroup] = cls.TreeGroupCaption
        end
    end
    for _, group_name in ipairs(group_order) do
        local count = group_counts[group_name]
        local is_visible = (current_filter == nil) or (current_filter[group_name] == true)
        if is_visible and count and count > 0 then
            local caption = group_caption_map[group_name]
            if caption then
                local title_with_count = string.format("%s (%d)", caption, count)
                local tree_group = tree:Add(title_with_count, group_name)
                created_groups[group_name] = tree_group
            end
        end
    end
    for i = 0, cnt - 1 do
        local baseid_cls = GetClassByIndexFromList(baseid_list, i)
        local className = baseid_cls.ClassName
        if baseid_cls.MergedTreeTitle ~= "NO" then
            className = baseid_cls.MergedTreeTitle
        end
        local slotset_name = 'sset_' .. className
        local count = slotset_counts[slotset_name]
        local tree_group_name = baseid_cls.TreeGroup
        local is_visible = (current_filter == nil) or (current_filter[tree_group_name] == true)
        if is_visible and count and count > 0 and not created_slotsets[slotset_name] then
            local tree_group = created_groups[tree_group_name]
            if not tree_group then
                local caption = baseid_cls.TreeGroupCaption
                local group_count = group_counts[tree_group_name] or 0
                local title_with_count = string.format("%s (%d)", caption, group_count)
                tree_group = tree:Add(title_with_count, tree_group_name)
                created_groups[tree_group_name] = tree_group
            end
            local margin_height = 5
            local margin_name = "margin_top_" .. slotset_name
            local margin = tree:CreateOrGetControl('richtext', margin_name, 0, 0, 400, margin_height)
            AUTO_CAST(margin)
            margin:EnableResizeByText(0)
            margin:SetText("")
            tree:Add(tree_group, margin, margin_name)
            local slotset_title_value = slotset_name .. "_title"
            local title_with_count = string.format("{s18}%s (%d)", baseid_cls.TreeSSetTitle, count)
            local slotset_node = tree:Add(tree_group, title_with_count, slotset_title_value)
            local new_slot_set = Another_warehouse_make_inven_slotset(tree, slotset_name)
            tree:Add(slotset_node, new_slot_set, slotset_name)
            created_slotsets[slotset_name] = new_slot_set
        end
    end
    for _, inv_item in ipairs(warehouse_item_list) do
        local item_cls = GetIES(inv_item:GetObject())
        local baseid_cls = INV_GET_INVEN_BASEIDCLS_BY_ITEMGUID(inv_item:GetIESID())
        local className = baseid_cls.ClassName
        if baseid_cls.MergedTreeTitle ~= "NO" then
            className = baseid_cls.MergedTreeTitle
        end
        local slotset_name = 'sset_' .. className
        local new_slot_set = created_slotsets[slotset_name]
        if new_slot_set then
            AUTO_CAST(new_slot_set)
            local slot_count = new_slot_set:GetSlotCount()
            local count = new_slot_set:GetUserIValue("SLOT_ITEM_COUNT")
            while slot_count <= count do
                new_slot_set:ExpandRow()
                slot_count = new_slot_set:GetSlotCount()
            end
            local slot = new_slot_set:GetSlotByIndex(count)
            count = count + 1
            new_slot_set:SetUserValue("SLOT_ITEM_COUNT", count)
            slot:ShowWindow(1)
            Another_warehouse_insert_item_to_tree(gb, tree, slot, inv_item, item_cls, slotset_name, baseid_cls)
        end
    end
    for _, slotset in pairs(created_slotsets) do
        local row = math.ceil(slotset:GetSlotCount() / slotset:GetCol())
        local height = row * 54
        slotset:Resize(slotset:GetWidth(), height)
    end
    local bottom_margin = 10 -- 隙間の高
    for _, group_name in ipairs(group_order) do
        local tree_group = created_groups[group_name]
        if tree_group and tree:GetChildCount(tree_group) > 0 then
            local margin_name = 'margin_' .. group_name
            local margin = tree:CreateOrGetControl('richtext', margin_name, 0, 0, 400, bottom_margin)
            AUTO_CAST(margin)
            margin:EnableResizeByText(0)
            margin:SetText("")
            tree:Add(tree_group, margin, margin_name)
        end
    end
    tree:OpenNodeAll()
    local max_count = Another_warehouse_get_maxcount()
    local item_count = Another_warehouse_item_count()
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    local count_text = GET_CHILD_RECURSIVELY(accountwarehouse, "awh_count_text")
    AUTO_CAST(count_text)
    count_text:SetText("{@st42}" .. item_count .. "/" .. max_count .. "{/}")
    count_text:SetFontName("white_16_ol")
    awh:RunUpdateScript("Another_warehouse_set_scroll_pos")
end

function Another_warehouse_INVENTORY_SORT_BY_NAME(a, b)
    local item_cls_a = GetIES(a:GetObject())
    local item_cls_b = GetIES(b:GetObject())
    local item_name_a = dic.getTranslatedStr(item_cls_a.Name)
    local item_name_b = dic.getTranslatedStr(item_cls_b.Name)
    return item_name_a < item_name_b
end

function Another_warehouse_set_scroll_pos(awh)
    awh:StopUpdateScript("Another_warehouse_set_scroll_pos")
    local saved_pos = awh:GetUserIValue("SCROLL_POS")
    local gb = GET_CHILD(awh, "gb")
    AUTO_CAST(gb)
    gb:SetScrollPos(saved_pos)
    gb:InvalidateScrollBar()
    return 0
end

function Another_warehouse_make_inven_slotset(tree, name)
    local slotset = tree:CreateOrGetControl('slotset', name, 0, 0, 0, 0)
    AUTO_CAST(slotset)
    slotset:EnablePop(0)
    slotset:EnableDrag(0)
    slotset:EnableDrop(0)
    slotset:SetMaxSelectionCount(999)
    slotset:SetSlotSize(54, 54)
    slotset:SetColRow(10, 1)
    slotset:SetSpc(0, 0)
    slotset:SetSkinName('invenslot')
    slotset:EnableSelection(0)
    slotset:CreateSlots()
    return slotset
end

function Another_warehouse_insert_item_to_tree(gb, tree, slot, inv_item, item_cls, slotset_name, baseid_cls)
    local slot_set = GET_CHILD_RECURSIVELY(gb, slotset_name)
    UPDATE_INVENTORY_SLOT(slot, inv_item, item_cls)
    slot:SetSkinName('invenslot2')
    local item_cls = GetIES(inv_item:GetObject())
    local iconImg = GET_ITEM_ICON_IMAGE(item_cls)
    if geItemTable.IsStack(item_cls.ClassID) == 1 and Another_warehouse_is_stack_new_item(item_cls.ClassID) then
        slot:SetHeaderImage('new_inventory_icon')
    elseif geItemTable.IsStack(item_cls.ClassID) == 0 and
        Another_warehouse_is_stack_new_item(item_cls.ClassID .. "_" .. inv_item:GetIESID()) then
        slot:SetHeaderImage('new_inventory_icon')
    else
        slot:SetHeaderImage('None')
    end
    SET_SLOT_IMG(slot, iconImg)
    SET_SLOT_COUNT(slot, inv_item.count)
    SET_SLOT_STYLESET(slot, item_cls)
    SET_SLOT_IESID(slot, inv_item:GetIESID())
    SET_SLOT_ITEM_TEXT_USE_INVCOUNT(slot, inv_item, item_cls, nil)
    slot:SetMaxSelectCount(inv_item.count);
    local icon = slot:GetIcon()
    icon:SetTooltipArg("accountwarehouse", inv_item.type, inv_item:GetIESID())
    SET_ITEM_TOOLTIP_TYPE(icon, item_cls.ClassID, item_cls, "accountwarehouse")
    SET_SLOT_ICOR_CATEGORY(slot, item_cls)
    if inv_item.hasLifeTime == true or TryGetProp(item_cls, 'ExpireDateTime', 'None') ~= 'None' then
        ICON_SET_ITEM_REMAIN_LIFETIME(icon, IT_ACCOUNT_WAREHOUSE)
        slot:SetFrontImage('clock_inven')
    else
        CLEAR_ICON_REMAIN_LIFETIME(slot, icon)
    end
    if string.find(item_cls.ClassName, "GoddessIcor") and string.find(item_cls.ClassName, "high") then
        local item_obj = GetIES(inv_item:GetObject())
        SET_SLOT_STAR_TEXT(slot, item_obj)
    end
    slot:SetEventScript(ui.LBUTTONUP, "Another_warehouse_on_lbutton") -- inv_item:GetIESID()
    slot:SetEventScriptArgString(ui.LBUTTONUP, inv_item:GetIESID())
    slot:SetEventScript(ui.RBUTTONUP, "Another_warehouse_on_rbutton")
    slot:SetEventScriptArgString(ui.RBUTTONUP, inv_item:GetIESID())
    if g.awh_settings.etc.display_change == 1 then
        if baseid_cls.TreeGroup == "Material" and slotset_name == "sset_Misc_Special" then
            if string.find(item_cls.ClassName, "GoddessIcor") and not string.find(item_cls.ClassName, "EP17") then
                slot:SetSkinName("invenslot_rare")
            end
        end
        if baseid_cls.TreeGroup == "Recipe" then -- Material
            local recipe_cls = GetClass('Recipe', item_cls.ClassName);
            if recipe_cls ~= nil then
                local taget_item = GetClass("Item", recipe_cls.TargetItem);
                if taget_item then
                    local image = GET_ITEM_ICON_IMAGE(taget_item)
                    local recipe_pic = slot:CreateOrGetControl('picture', 'recipe_pic' .. inv_item:GetIESID(), 0, 0, 25,
                        25)
                    AUTO_CAST(recipe_pic)
                    recipe_pic:SetEnableStretch(1)
                    recipe_pic:SetGravity(ui.LEFT, ui.TOP)
                    recipe_pic:SetImage(image)
                    recipe_pic:SetTooltipArg("accountwarehouse", inv_item.type, inv_item:GetIESID())
                    SET_ITEM_TOOLTIP_TYPE(recipe_pic, taget_item.ClassID, taget_item, "accountwarehouse")
                end
            end
        end
        if string.find(baseid_cls.ClassName, "Card") and not string.find(baseid_cls.ClassName, "Summon") and
            not string.find(baseid_cls.ClassName, "CardAddExp") then
            local image = TryGetProp(item_cls, "TooltipImage", "None")
            if image ~= "None" then
                icon:Set(image, 'Item', inv_item.type, inv_item.invIndex, inv_item:GetIESID(), inv_item.count)
            end
        end
        if baseid_cls.ClassName == "Gem_GemSkill" then
            for i = 1, 4 do
                if TryGetProp(item_cls, 'RandomOption_' .. i, 'None') ~= 'None' and
                    TryGetProp(item_cls, 'RandomOptionValue_' .. i, 0) > 0 then
                    local star_pic =
                        slot:CreateOrGetControl('richtext', 'star_pic' .. inv_item:GetIESID(), 0, 0, 18, 18)
                    star_pic:SetText("{img star_mark 18 18}")
                    star_pic:SetGravity(ui.RIGHT, ui.TOP)
                end
            end
            local skill_cls = GetClass("Skill", TryGetProp(item_cls, 'SkillName', 'None'))
            if skill_cls then
                local image = "icon_" .. GET_ITEM_ICON_IMAGE(skill_cls)
                icon:Set(image, 'Item', inv_item.type, inv_item.invIndex, inv_item:GetIESID(), inv_item.count)
                local skill_pic = slot:CreateOrGetControl('picture', 'skill_pic' .. inv_item:GetIESID(), 0, 0, 25, 25)
                AUTO_CAST(skill_pic)
                local image = GET_ITEM_ICON_IMAGE(item_cls)
                skill_pic:SetEnableStretch(1)
                skill_pic:SetGravity(ui.LEFT, ui.TOP)
                skill_pic:SetImage(image)
                SET_ITEM_TOOLTIP_TYPE(skill_pic, item_cls.ClassID, item_cls, "accountwarehouse")
            end
        elseif baseid_cls.ClassName == "Gem_High_Color" then
            local cls_name = item_cls.ClassName
            if string.find(cls_name, "540") then
                slot:SetSkinName("invenslot_pic_goddess")
            elseif string.find(cls_name, "520") then
                slot:SetSkinName("invenslot_legend")
            elseif string.find(cls_name, "500") then
                slot:SetSkinName("invenslot_unique")
            elseif string.find(cls_name, "480") then
                slot:SetSkinName("invenslot_rare")
            else
                slot:SetSkinName("invenslot_nomal")
            end
        end
        if string.find(baseid_cls.ClassName, "OPTMisc_GoddessIcor") then
            local cls_name = item_cls.ClassName
            local is_special = string.find(cls_name, "EP17") or string.find(cls_name, "Weapon2") or
                                   string.find(cls_name, "Armor2")
            if not is_special then
                slot:SetSkinName("invenslot_rare")
            end
        elseif string.find(baseid_cls.ClassName, "Armor") then
            local cls_name = item_cls.ClassName
            local is_special = string.find(cls_name, "EP17") or
                                   (string.find(cls_name, "EP16") and string.find(cls_name, "high")) or
                                   (string.find(cls_name, "EP13") and string.find(cls_name, "high2"))
            if not is_special and (string.find(cls_name, "belt") or string.find(cls_name, "shoulder")) then
                slot:SetSkinName("invenslot_rare")
            end
        end
    end
end

function Another_warehouse_is_stack_new_item(class_id)
    for k, v in pairs(g.awh_new_stack_add_item) do
        if v == class_id then
            return true
        end
    end
    return false
end

function Another_warehouse_check_search_and_filter(inv_item, item_cls, search_text)
    if search_text == "" then
        return true
    end
    local temp_cap = string.lower(search_text)
    local item_name = string.lower(dictionary.ReplaceDicIDInCompStr(item_cls.Name))
    if string.find(item_name, temp_cap) then
        return true
    end
    local prefix_class_name = TryGetProp(item_cls, "LegendPrefix")
    if prefix_class_name and prefix_class_name ~= "None" then
        local prefix_cls = GetClass('LegendSetItem', prefix_class_name)
        if prefix_cls then
            local prefix_name = string.lower(dictionary.ReplaceDicIDInCompStr(prefix_cls.Name))
            if string.find(prefix_name .. " " .. item_name, temp_cap) then
                return true
            end
        end
    end
    if TryGetProp(item_cls, 'GroupName', 'None') == 'Earring' then
        local max_option_count = shared_item_earring.get_max_special_option_count(TryGetProp(item_cls, 'UseLv', 1))
        for i = 1, max_option_count do
            local option_name = 'EarringSpecialOption_' .. i
            local job_id = TryGetProp(item_cls, option_name, 'None')
            if job_id ~= 'None' then
                local job_cls = GetClass('Job', job_id)
                if job_cls and string.find(string.lower(dictionary.ReplaceDicIDInCompStr(job_cls.Name)), temp_cap) then
                    return true
                end
            end
        end
    end
    if TryGetProp(item_cls, 'GroupName', 'None') == 'Icor' then
        local item = GetIES(inv_item:GetObject())
        for i = 1, 5 do
            local option = TryGetProp(item, 'RandomOption_' .. i, 'None')
            if option and option ~= "None" and
                string.find(string.lower(dictionary.ReplaceDicIDInCompStr(ClMsg(option))), temp_cap) then
                return true
            end
        end
    end
    return false
end

function Another_warehouse_get_maxcount()
    local acc_obj = GetMyAccountObj()
    local token_bonus = 0
    local my_handle = session.GetMyHandle()
    local buff = info.GetBuff(my_handle, 70002)
    if buff then
        token_bonus = ADDITIONAL_SLOT_COUNT_BY_TOKEN + 280
    end
    local max_cnt = acc_obj.BasicAccountWarehouseSlotCount + acc_obj.MaxAccountWarehouseCount +
                        acc_obj.AccountWareHouseExtend + acc_obj.AccountWareHouseExtendByItem + token_bonus
    return max_cnt
end
-- 900011
function Another_warehouse_item_count()
    local item_list = session.GetEtcItemList(IT_ACCOUNT_WAREHOUSE)
    local guid_list = item_list:GetSortedGuidList()
    local cnt = item_list:Count()
    local return_cnt = 0
    for i = 0, cnt - 1 do
        local guid = guid_list:Get(i);
        local inv_item = item_list:GetItemByGuid(guid)
        if inv_item then
            local item_obj = GetIES(inv_item:GetObject())
            if item_obj.ClassID ~= 900011 then -- 900011 Vis シルバー
                return_cnt = return_cnt + 1
            end
        end
    end
    return return_cnt
end

function Another_warehouse_get_goal_index()
    local acc_obj = GetMyAccountObj()
    local base_count = acc_obj.BasicAccountWarehouseSlotCount + acc_obj.MaxAccountWarehouseCount +
                           acc_obj.AccountWareHouseExtend + acc_obj.AccountWareHouseExtendByItem
    local tab_index = {4, 3, 2, 1, 0}
    local accountwarehouse = ui.GetFrame('accountwarehouse')
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
                return ((i - 1) * 70) + base_count + left + 1
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

function Another_warehouse_check_valid(inv_item)
    local item_count = Another_warehouse_item_count()
    local max_count = Another_warehouse_get_maxcount()
    if max_count <= item_count then
        ui.SysMsg(ClMsg('CannotPutBecauseMaxSlot'))
        return false
    end
    if true == inv_item.isLockState then
        ui.SysMsg(ClMsg("MaterialItemIsLock"))
        return false
    end
    local obj = GetIES(inv_item:GetObject())
    local item_cls = GetClassByType("Item", obj.ClassID)
    if item_cls.ItemType == 'Quest' then
        ui.MsgBox(ScpArgMsg("IT_ISNT_REINFORCEABLE_ITEM"))
        return false
    end
    local enable_team_trade = TryGetProp(item_cls, "TeamTrade")
    if enable_team_trade and enable_team_trade == "NO" then
        ui.SysMsg(ClMsg("ItemIsNotTradable"))
        return false
    end
    if TryGetProp(obj, 'CharacterBelonging', 0) == 1 then
        ui.SysMsg(ClMsg("ItemIsNotTradable"))
        return false
    end
    return true
end

function Another_warehouse_search(frame, ctrl, str, num)
    local awh = ui.GetFrame(addon_name_lower .. "awh")
    local gb = GET_CHILD(awh, "gb")
    AUTO_CAST(gb)
    local search_text = ctrl:GetText()
    local tab = GET_CHILD(awh, "tab" .. "inventory_main")
    Another_warehouse_tab_change(awh, tab, search_text, 1)
end

function Another_warehouse_inv_lbtn(frame, inv_item, dumm)
    if not Another_warehouse_check_valid(inv_item) then
        return
    end
    local iesid = inv_item:GetIESID()
    if keyboard.IsKeyPressed("LSHIFT") == 1 then
        local count = math.min(10, inv_item.count)
        Another_warehouse_putitem(inv_item, iesid, count)
    else
        Another_warehouse_putitem(inv_item, iesid, 1)
    end
end

function Another_warehouse_inv_rbtn(item_obj, slot)
    if g.settings.cc_helper.use == 1 then
        local cch_setting = ui.GetFrame(addon_name_lower .. "cch_setting")
        if cch_setting and cch_setting:IsVisible() == 1 then
            INVENTORY_SET_CUSTOM_RBTNDOWN("Cc_helper_inv_rbtn")
            return
        end
    end
    local icon = slot:GetIcon()
    local icon_info = icon:GetInfo()
    local iesid = icon_info:GetIESID()
    local inv_item = GET_PC_ITEM_BY_GUID(iesid)
    if not inv_item then
        return
    end
    -- ui.AlarmMsg(TryGetProp(GetIES(inv_item:GetObject()), 'BelongingCount', 0))
    if not Another_warehouse_check_valid(inv_item) then
        return
    end
    if keyboard.IsKeyPressed("LSHIFT") == 1 then
        local accountwarehouse = ui.GetFrame("accountwarehouse")
        local obj = GetIES(inv_item:GetObject())
        local max_cnt = inv_item.count
        local belonging_count = TryGetProp(obj, 'BelongingCount', 0)
        if belonging_count > 0 then
            max_cnt = inv_item.count - obj.BelongingCount
            if max_cnt <= 0 then
                max_cnt = 0
            end
        end
        if inv_item.count > 1 or geItemTable.IsStack(obj.ClassID) == 1 then
            INPUT_NUMBER_BOX(accountwarehouse, ScpArgMsg("InputCount"), "EXEC_PUT_ITEM_TO_ACCOUNT_WAREHOUSE", max_cnt,
                1, max_cnt, nil, iesid)
        else
            Another_warehouse_putitem(inv_item, iesid, inv_item.count)
        end
    else
        Another_warehouse_putitem(inv_item, iesid, inv_item.count)
    end
end

function Another_warehouse_on_lbutton(parent, slot, iesid, num)
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    local inv_item = session.GetEtcItemByGuid(IT_ACCOUNT_WAREHOUSE, iesid)
    local obj = GetIES(inv_item:GetObject())
    if keyboard.IsKeyPressed("LSHIFT") == 1 then
        local count = math.min(10, inv_item.count)
        Another_warehouse_takeitem(accountwarehouse, iesid, count)
    else
        Another_warehouse_takeitem(accountwarehouse, iesid, 1)
    end
end

function Another_warehouse_on_rbutton(frame, slot, iesid, argnum)
    if g.settings.cc_helper.use == 1 then
        local cch_setting = ui.GetFrame(addon_name_lower .. "cch_setting")
        if cch_setting and cch_setting:IsVisible() == 1 then
            local slot = ui.GetFocusObject()
            if not slot then
                return
            end
            local icon = slot:GetIcon()
            if icon then
                local icon_info = icon:GetInfo()
                local iesid = icon_info:GetIESID()
                local awh_item = session.GetEtcItemByGuid(IT_ACCOUNT_WAREHOUSE, iesid)
                if not awh_item then
                    return
                end
                local item_obj = GetIES(awh_item:GetObject())
                Cc_helper_inv_rbtn(item_obj, slot, iesid, awh_item)
            end
            return
        end
    end
    local awh_setting = ui.GetFrame(addon_name_lower .. "awh_setting")
    if awh_setting and awh_setting:IsVisible() == 1 then
        AUTO_CAST(awh_setting)
        local inv_item = session.GetEtcItemByGuid(IT_ACCOUNT_WAREHOUSE, iesid)
        if not inv_item then
            return
        end
        local obj = GetIES(inv_item:GetObject())
        local cls_id = obj.ClassID
        local item_cls = GetClassByType("Item", cls_id)
        if inv_item.isLockState then
            ui.SysMsg(ClMsg("MaterialItemIsLock"))
            return
        end
        if item_cls.ItemType == 'Quest' then
            ui.MsgBox(ScpArgMsg("IT_ISNT_REINFORCEABLE_ITEM"));
            return
        end
        local enable_team_trade = TryGetProp(item_cls, "TeamTrade")
        if enable_team_trade and enable_team_trade == "NO" then
            ui.SysMsg(ClMsg("ItemIsNotTradable"))
            return
        end
        local belonging_count = TryGetProp(obj, 'BelongingCount', 0)
        if belonging_count > 0 and belonging_count >= inv_item.count then
            ui.SysMsg(ClMsg("ItemIsNotTradable"))
            return
        end
        if TryGetProp(obj, 'CharacterBelonging', 0) == 1 then
            ui.SysMsg(ClMsg("ItemIsNotTradable"))
            return
        end
        local items = {}
        local slotset_name = ""
        if keyboard.IsKeyPressed("LSHIFT") == 1 then
            items = g.awh_settings.chars[g.cid].items
            slotset_name = "char_slotset"
        else
            items = g.awh_settings.items
            slotset_name = "team_slotset"
        end
        for key, value in pairs(items) do
            if value.clsid == cls_id then
                ui.SysMsg(g.lang == "Japanese" and "既に登録済です" or "Already registered")
                return
            end
        end
        local awh_setting = ui.GetFrame(addon_name_lower .. "awh_setting")
        local target_slotset = GET_CHILD_RECURSIVELY(awh_setting, slotset_name)
        local slotcount = target_slotset:GetSlotCount()
        local index = 1
        for i = 1, slotcount do
            local awslot = GET_CHILD_RECURSIVELY(target_slotset, "slot" .. i)
            local slot_icon = awslot:GetIcon()
            if slot_icon == nil then
                index = i
                break
            end
        end
        local ctrl = GET_CHILD_RECURSIVELY(target_slotset, "slot" .. index)
        if tonumber(item_cls.MaxStack) > 1 then
            awh_setting:SetUserValue("SLOT_NAME", ctrl:GetParent():GetName())
            local msg = g.lang == "Japanese" and "インベントリに残す数を入力" or
                            "Enter the number to be left in the inventory"
            INPUT_NUMBER_BOX(awh_setting, msg, "Another_warehouse_setting_item_count", 0, 0,
                tonumber(item_cls.MaxStack), cls_id, tostring(index), nil)
        else
            items[tostring(index)] = {
                clsid = cls_id,
                count = 0
            }
            SET_SLOT_ITEM_CLS(ctrl, item_cls)
            Another_warehouse_save_settings()
        end
        return
    end
    local awh_set_items = ui.GetFrame(addon_name_lower .. "awh_set_items")
    if awh_set_items and awh_set_items:IsVisible() == 1 then
        AUTO_CAST(awh_set_items)
        local name_edit = GET_CHILD(awh_set_items, "name_edit")
        local name_text = string.gsub(name_edit:GetText(), "{ol}", "")
        local index = 0
        for i, data in ipairs(g.awh_settings.take_list) do
            local name = data.name
            if name == name_text then
                index = i
            end
        end
        local set_slotset = GET_CHILD_RECURSIVELY(awh_set_items, 'set_slotset')
        AUTO_CAST(set_slotset)
        local slotcount = set_slotset:GetSlotCount()
        for i = 1, slotcount do
            local slot = GET_CHILD(set_slotset, "slot" .. i)
            AUTO_CAST(slot)
            local slot_index = string.gsub(slot:GetName(), "slot", "")
            local icon = slot:GetIcon()
            if not icon then
                local inv_item = session.GetEtcItemByGuid(IT_ACCOUNT_WAREHOUSE, iesid)
                local obj = GetIES(inv_item:GetObject())
                g.awh_settings.take_list[index].items[slot_index] = obj.ClassID
                break
            end
        end
        Another_warehouse_save_settings()
        Another_warehouse_set_items_setting(index, name_text)
        return
    end
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    local inv_item = session.GetEtcItemByGuid(IT_ACCOUNT_WAREHOUSE, iesid)
    local obj = GetIES(inv_item:GetObject())
    local count = inv_item.count
    if keyboard.IsKeyPressed("LSHIFT") == 1 then
        local belonging_count = TryGetProp(obj, 'BelongingCount', 0)
        local max_cnt = inv_item.count
        if belonging_count > 0 then
            max_cnt = count - obj.BelongingCount
            if max_cnt <= 0 then
                max_cnt = 0
            end
        end
        if count > 1 or geItemTable.IsStack(obj.ClassID) == 1 then
            INPUT_NUMBER_BOX(accountwarehouse, ScpArgMsg("InputCount"), "Another_warehouse_take_item_from_warehouse",
                max_cnt, 1, max_cnt, nil, iesid)
        else
            Another_warehouse_takeitem(accountwarehouse, iesid, 1)
        end
    else
        if count > 1 or geItemTable.IsStack(obj.ClassID) == 1 then
            if g.awh_settings.etc.leave_item == 1 then
                count = count - 1
            end
            Another_warehouse_takeitem(accountwarehouse, iesid, count)
        else
            Another_warehouse_takeitem(accountwarehouse, iesid, 1)
        end
    end
end

function Another_warehouse_take_item_from_warehouse(accountwarehouse, count, input_frame)
    input_frame:ShowWindow(0)
    local iesid = input_frame:GetUserValue("ArgString")
    session.ResetItemList()
    session.AddItemID(iesid, count)
    local handle = accountwarehouse:GetUserIValue("HANDLE")
    item.TakeItemFromWarehouse_List(IT_ACCOUNT_WAREHOUSE, session.GetItemIDList(), handle)
end

function Another_warehouse_putitem(inv_item, iesid, count)
    local item_obj = GetIES(inv_item:GetObject())
    local goal_index = Another_warehouse_get_goal_index()
    if Another_warehouse_check_valid(inv_item) then
        local accountwarehouse = ui.GetFrame("accountwarehouse")
        local handle = accountwarehouse:GetUserIValue("HANDLE")
        item.PutItemToWarehouse(IT_ACCOUNT_WAREHOUSE, iesid, tostring(count), handle, goal_index)
        local awh = ui.GetFrame(addon_name_lower .. "awh")
        AUTO_CAST(awh)
        awh:SetUserValue("TOOLTIP_COUNT", 0)
        Another_warehouse_item_put_to(awh, iesid, count, item_obj.ClassID)
        if geItemTable.IsStack(item_obj.ClassID) == 1 then
            table.insert(g.awh_new_stack_add_item, item_obj.ClassID)
        elseif geItemTable.IsStack(item_obj.ClassID) == 0 then
            table.insert(g.awh_new_stack_add_item, item_obj.ClassID .. "_" .. iesid)
        end
        local gbox_warehouse = GET_CHILD_RECURSIVELY(accountwarehouse, "gbox_warehouse")
        if gbox_warehouse then
            gbox_warehouse:UpdateData()
            accountwarehouse:Invalidate()
        end
    end
end

function Another_warehouse_takeitem(accountwarehouse, iesid, count)
    session.ResetItemList()
    session.AddItemID(iesid, count)
    local handle = accountwarehouse:GetUserIValue("HANDLE")
    item.TakeItemFromWarehouse_List(IT_ACCOUNT_WAREHOUSE, session.GetItemIDList(), handle)
end

function Another_warehouse_auto_func_start(awh)
    local auto_money = g.awh_settings.chars[g.cid].money_check
    local my_handle = session.GetMyHandle()
    local buff = info.GetBuff(my_handle, 70002)
    if not buff then
        if auto_money == 1 then
            Another_warehouse_silver(awh)
        end
        ui.SysMsg(g.lang == "Japanese" and "[AWH]トークンがないため自動処理を停止します" or
                      "[AWH]Auto function stopped due to no token")
        return
    end
    local auto_item = g.awh_settings.chars[g.cid].item_check
    if auto_item == 0 and auto_money == 0 then
        return
    end
    g.another_warehouse_func = true
    if auto_item == 1 then
        Another_warehouse_auto_item_start(awh)
        return
    end
    if auto_money == 1 then
        Another_warehouse_silver(awh)
        return
    end
    Another_warehouse_end(awh)
end

function Another_warehouse_retry(frame)
    Another_warehouse_auto_item_start(frame, true)
    return 0
end

function Another_warehouse_auto_item_start(awh, is_retry)
    local status, err = pcall(Another_warehouse_auto_item_start_logic, awh, is_retry)
    if not status then
        local msg = "{#FF0000}[AWH Error] " .. tostring(err)
        ui.SysMsg(msg)
    end
end

function Another_warehouse_auto_item_start_logic(awh, is_retry)
    if not is_retry then
        g.awh_retry_count = 0
    end
    local accountwarehouse = ui.GetFrame('accountwarehouse')
    local item_list = session.GetEtcItemList(IT_ACCOUNT_WAREHOUSE)
    local sorted_guid_list = item_list:GetSortedGuidList()
    local sorted_cnt = sorted_guid_list:Count()

    if sorted_cnt == 0 then
        if accountwarehouse:IsVisible() == 1 then
            if g.awh_retry_count < 5 then
                g.awh_retry_count = g.awh_retry_count + 1
                accountwarehouse:StopUpdateScript("Another_warehouse_retry")
                accountwarehouse:RunUpdateScript("Another_warehouse_retry", 0.1)
                return
            else
                local msg = g.lang == "Japanese" and
                                "倉庫情報の取得に失敗しました{nl}アイテム自動取得をスキップします" or
                                "Failed to retrieve warehouse info{nl}Auto-take skipped"
                ui.SysMsg(msg)
            end
        end
    end
    g.awh_take_items = {}
    g.awh_put_items = {}
    local function get_target_count(cls_id)
        local target_count = 0
        local is_target = false
        if g.awh_settings.chars[g.cid] and g.awh_settings.chars[g.cid].items then
            for _, item in pairs(g.awh_settings.chars[g.cid].items) do
                if item.clsid == cls_id then
                    target_count = item.count
                    is_target = true
                    break
                end
            end
        end
        if not is_target and g.awh_settings.items then
            for _, item in pairs(g.awh_settings.items) do
                if item.clsid == cls_id then
                    target_count = item.count
                    is_target = true
                    break
                end
            end
        end
        return target_count, is_target
    end
    local current_inv_counts = {}
    local inv_item_list = session.GetInvItemList()
    local inv_guid_list = inv_item_list:GetGuidList()
    local inv_cnt = inv_guid_list:Count()
    for i = 0, inv_cnt - 1 do
        local guid = inv_guid_list:Get(i)
        local inv_item = inv_item_list:GetItemByGuid(guid)
        if inv_item then
            local inv_obj = GetIES(inv_item:GetObject())
            local cls_id = inv_obj.ClassID
            if cls_id ~= 900011 then
                current_inv_counts[cls_id] = (current_inv_counts[cls_id] or 0) + inv_item.count
            end
        end
    end
    for i = 0, sorted_cnt - 1 do
        local guid = sorted_guid_list:Get(i)
        local wh_item = item_list:GetItemByGuid(guid)
        local cls_id = wh_item.type
        if cls_id ~= 900011 then
            local target_count, is_target = get_target_count(cls_id)
            if is_target then
                local wh_available = g.awh_settings.etc.leave_item == 1 and wh_item.count - 1 or wh_item.count
                if wh_available > 0 then
                    local current_count = current_inv_counts[cls_id] or 0
                    local need_count = target_count - current_count
                    if need_count > 0 then
                        local take_amount = math.min(wh_available, need_count)
                        g.awh_take_items[guid] = {
                            iesid = guid,
                            count = take_amount,
                            clsid = cls_id
                        }
                        current_inv_counts[cls_id] = current_count + take_amount
                    end
                end
            end
        end
    end
    current_inv_counts = {}
    for i = 0, inv_cnt - 1 do
        local guid = inv_guid_list:Get(i)
        local inv_item = inv_item_list:GetItemByGuid(guid)
        if inv_item then
            local inv_obj = GetIES(inv_item:GetObject())
            local cls_id = inv_obj.ClassID
            if cls_id ~= 900011 then
                current_inv_counts[cls_id] = (current_inv_counts[cls_id] or 0) + inv_item.count
            end
        end
    end
    for i = 0, inv_cnt - 1 do
        local guid = inv_guid_list:Get(i)
        local inv_item = inv_item_list:GetItemByGuid(guid)
        if inv_item then
            local inv_obj = GetIES(inv_item:GetObject())
            local cls_id = inv_obj.ClassID
            if cls_id ~= 900011 then
                local target_count, is_target = get_target_count(cls_id)
                if is_target then
                    local current_total = current_inv_counts[cls_id] or 0
                    local surplus = current_total - target_count -- 過剰分
                    if surplus > 0 then
                        local put_amount = math.min(inv_item.count, surplus)
                        g.awh_put_items[guid] = {
                            iesid = guid,
                            count = put_amount,
                            clsid = cls_id,
                            invcount = inv_item.count,
                            initial_count = inv_item.count
                        }
                        current_inv_counts[cls_id] = current_total - put_amount
                    end
                end
            end
        end
    end
    local take_clsids = {}
    for _, data in pairs(g.awh_take_items) do
        take_clsids[data.clsid] = true
    end
    for guid, data in pairs(g.awh_put_items) do
        if take_clsids[data.clsid] then
            g.awh_put_items[guid] = nil
        end
    end
    Another_warehouse_item_take(awh)
end

function Another_warehouse_item_take(awh)
    if awh:GetUserIValue("IS_TAKING") == 0 then
        local item_list = session.GetEtcItemList(IT_ACCOUNT_WAREHOUSE)
        session.ResetItemList()
        local take_count_total = 0
        for guid, items in pairs(g.awh_take_items) do
            local wh_item = item_list:GetItemByGuid(guid)
            if wh_item then
                local count = math.min(items.count, wh_item.count)
                if count > 0 then
                    session.AddItemID(guid, count)
                    take_count_total = take_count_total + 1
                end
            end
        end
        if take_count_total == 0 then
            awh:RunUpdateScript("Another_warehouse_item_put", 0.1)
            return 0
        end
        local accountwarehouse = ui.GetFrame('accountwarehouse')
        local handle = accountwarehouse:GetUserIValue('HANDLE')
        item.TakeItemFromWarehouse_List(IT_ACCOUNT_WAREHOUSE, session.GetItemIDList(), handle)
        awh:SetUserValue("IS_TAKING", 1)
        awh:SetUserValue("TAKE_START_TIME", imcTime.GetAppTimeMS())
        awh:StopUpdateScript("Another_warehouse_item_take")
        awh:RunUpdateScript("Another_warehouse_item_take", 0.1)
        return 1
    end
    local all_arrived = true
    for guid, items in pairs(g.awh_take_items) do
        local inv_item = session.GetInvItemByGuid(guid)
        if not inv_item then
            all_arrived = false
            break
        end
    end
    local start_time = awh:GetUserIValue("TAKE_START_TIME")
    local now = imcTime.GetAppTimeMS()
    if all_arrived or (now - start_time > 1000) then
        awh:SetUserValue("IS_TAKING", 0)
        awh:SetUserValue("TOOLTIP_COUNT", 0)
        awh:RunUpdateScript("Another_warehouse_item_put", 0.1)
        return 0
    end
    return 1
end

function Another_warehouse_item_put(awh)
    local accountwarehouse = ui.GetFrame('accountwarehouse')
    if accountwarehouse:IsVisible() == 0 then
        awh:StopUpdateScript("Another_warehouse_item_put")
        return 0
    end
    local next_guid, item_data = next(g.awh_put_items)
    if not next_guid then
        if g.awh_settings.chars[g.cid].money_check == 1 then
            Another_warehouse_silver(awh)
        else
            Another_warehouse_end(awh)
        end
        return 0
    end
    local is_finished = false
    local inv_item = session.GetInvItemByGuid(item_data.iesid)
    if not inv_item then
        is_finished = true
    elseif item_data.is_putting then
        if inv_item.count < item_data.initial_count then
            is_finished = true
        else
            return 1 -- まだ処理中
        end
    end
    if is_finished then
        local count = item_data.real_put_count or item_data.count
        Another_warehouse_item_put_to(awh, item_data.iesid, count, item_data.clsid)
        if geItemTable.IsStack(item_data.clsid) == 1 then
            table.insert(g.awh_new_stack_add_item, item_data.clsid)
        elseif geItemTable.IsStack(item_data.clsid) == 0 then
            table.insert(g.awh_new_stack_add_item, item_data.clsid .. "_" .. item_data.iesid)
        end
        g.awh_put_items[next_guid] = nil
        if not next(g.awh_put_items) then
            if g.awh_settings.chars[g.cid].money_check == 1 then
                Another_warehouse_silver(awh)
            else
                Another_warehouse_end(awh)
            end
            return 0
        end
        return 1
    end
    if not Another_warehouse_check_valid(inv_item) then
        awh:StopUpdateScript("Another_warehouse_item_put")
        return 0
    end
    local handle = accountwarehouse:GetUserIValue("HANDLE")
    local goal_index = Another_warehouse_get_goal_index()
    local put_count = item_data.count
    if put_count > inv_item.count then
        put_count = inv_item.count
    end
    item_data.initial_count = inv_item.count
    item.PutItemToWarehouse(IT_ACCOUNT_WAREHOUSE, item_data.iesid, tostring(put_count), handle, goal_index)
    item_data.is_putting = true
    item_data.real_put_count = put_count
    return 1
end

function Another_warehouse_item_put_to(awh, guid, count, cls_id)
    local item_cls = GetClassByType('Item', cls_id)
    local icon_name = GET_ITEM_ICON_IMAGE(item_cls)
    local item_name = item_cls.Name
    local tooltip_count = awh:GetUserIValue("TOOLTIP_COUNT")
    if tooltip_count >= 4 then
        awh:SetUserValue("TOOLTIP_COUNT", 0)
    else
        awh:SetUserValue("TOOLTIP_COUNT", tooltip_count + 1)
    end
    Another_warehouse_item_tooltip(item_name, icon_name, count, tooltip_count)
    local msg = g.lang == "Japanese" and "倉庫に格納しました" .. "：[" .. "{#EE82EE}" .. item_name ..
                    "{#FFFF00}]×" .. "{#EE82EE}" .. count or "Item to warehousing" .. "：[" .. "{#EE82EE}" ..
                    item_name .. "{#FFFF00}]×" .. "{#EE82EE}" .. count
    CHAT_SYSTEM(msg)
end

function Another_warehouse_item_tooltip(item_name, icon_name, count, tooltip_count)
    local awh_tooltip =
        ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "awh_tooltip" .. tooltip_count, 0, 0, 0, 0)
    AUTO_CAST(awh_tooltip)
    awh_tooltip:SetSkinName("None")
    awh_tooltip:SetPos(680, 300 + tooltip_count * 55)
    awh_tooltip:SetLayerLevel(100)
    awh_tooltip:Resize(350, 64)
    local tooltip_gb = awh_tooltip:CreateOrGetControl("groupbox", "tooltip_gb", 0, 0, 350, 64)
    AUTO_CAST(tooltip_gb)
    tooltip_gb:SetSkinName("item_show_tootip")
    tooltip_gb:Resize(350, 64)
    local tooltip_slot = tooltip_gb:CreateOrGetControl("slot", "tooltip_slot", 20, 10, 45, 45)
    AUTO_CAST(tooltip_slot)
    local tooltip_text = tooltip_gb:CreateOrGetControl("richtext", "tooltip_text", 75, 15, 265, 22)
    AUTO_CAST(tooltip_text)
    tooltip_text:Resize(265, 22)
    tooltip_text:SetText("{ol}" .. item_name)
    local tooltip_count = tooltip_gb:CreateOrGetControl("richtext", "tooltip_count", 75, 37, 265, 22)
    AUTO_CAST(tooltip_count)
    tooltip_count:Resize(265, 22)
    local msg = g.lang == "Japanese" and count .. " 個搬入しました" or count .. " Pieces in warehouse"
    tooltip_count:SetText("{ol}" .. msg)
    SET_SLOT_ICON(tooltip_slot, icon_name)
    awh_tooltip:ShowWindow(1)
    awh_tooltip:RunUpdateScript("Another_warehouse_item_tooltip_close", 2.0)
end

function Another_warehouse_item_tooltip_close(awh_tooltip)
    ui.DestroyFrame(awh_tooltip:GetName())
end

function Another_warehouse_silver(awh)
    local silver = session.GetInvItemByType(900011)
    local accountwarehouse = ui.GetFrame('accountwarehouse')
    local handle = accountwarehouse:GetUserIValue('HANDLE')
    local char_silver = 0
    if silver then
        char_silver = tonumber(silver:GetAmountStr())
    end
    char_silver = char_silver - g.awh_settings.etc.auto_silver
    if char_silver > 0 then
        item.PutItemToWarehouse(IT_ACCOUNT_WAREHOUSE, silver:GetIESID(), tostring(char_silver), handle)
    elseif char_silver <= 0 then
        session.ResetItemList()
        session.AddItemIDWithAmount("0", tostring(-char_silver))
        item.TakeItemFromWarehouse_List(IT_ACCOUNT_WAREHOUSE, session.GetItemIDList(), handle)
    end
    Another_warehouse_end(awh)
end

function Another_warehouse_end(awh)
    g.another_warehouse_func = false
    ui.SysMsg("[AWH]End of Operation")
    imcSound.PlaySoundEvent('sys_cube_open_normal')
    local awh = ui.GetFrame(addon_name_lower .. "awh")
    local gb = GET_CHILD(awh, "gb")
    AUTO_CAST(gb)
    local index = awh:GetUserIValue("TAB_INDEX")
    Another_warehouse_frame_update(awh, gb, "", index)
end

function Another_warehouse_setting_frame_init(frame, ctrl, str, num)
    local inventory = ui.GetFrame('inventory')
    inventory:ShowWindow(1)
    INVENTORY_SET_CUSTOM_RBTNDOWN("None")
    INVENTORY_SET_CUSTOM_RBTNDOWN("Another_warehouse_setting_rbtn")
    local setting = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "awh_setting", 0, 0, 0, 0)
    AUTO_CAST(setting)
    setting:RemoveAllChild()
    setting:SetPos(670, 10)
    setting:Resize(740, 1060)
    setting:SetLayerLevel(96)
    setting:SetSkinName("test_frame_low")
    local title_gb = setting:CreateOrGetControl("groupbox", "title_gb", 0, 0, setting:GetWidth(), 55)
    title_gb:SetSkinName("test_frame_top")
    AUTO_CAST(title_gb)
    local title_text = title_gb:CreateOrGetControl("richtext", "title_text", 0, 0, ui.CENTER_HORZ, ui.TOP, 0, 15, 0, 0)
    AUTO_CAST(title_text)
    title_text:SetText('{ol}{s26}Another Warehouse Setting')
    local close = setting:CreateOrGetControl("button", "close", 0, 0, 25, 25)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetOffset(680, 15)
    close:SetEventScript(ui.LBUTTONUP, "Another_warehouse_setting_close")
    local money_check = setting:CreateOrGetControl('checkbox', 'money_check', 25, 65, 25, 25)
    AUTO_CAST(money_check)
    money_check:SetEventScript(ui.LBUTTONUP, "Another_warehouse_setting_check")
    money_check:SetCheck(g.awh_settings.chars[g.cid].money_check)
    money_check:SetText(g.lang == "Japanese" and "{ol}自動入出金" or "{ol}automatic deposit and withdrawal")
    money_check:SetTextTooltip(g.lang == "Japanese" and
                                   "{ol}チェックをすると、自動入出金有効化 各キャラクター毎に設定" or
                                   "{ol}If checked, activate silver auto-deposit/withdrawal{nl}configured per character")
    local item_check = setting:CreateOrGetControl('checkbox', 'item_check', 25, 95, 25, 25)
    AUTO_CAST(item_check)
    item_check:SetEventScript(ui.LBUTTONUP, "Another_warehouse_setting_check")
    item_check:SetCheck(g.awh_settings.chars[g.cid].item_check)
    item_check:SetText(g.lang == "Japanese" and "{ol}自動搬出入" or "{ol}Automatic item receipt and dispatch")
    item_check:SetTextTooltip(g.lang == "Japanese" and
                                  "{ol}チェックをすると、自動搬出入有効化 各キャラクター毎に設定" or
                                  "{ol}If checked, activate item auto-deposit/withdrawal{nl}configured per character")
    local help = setting:CreateOrGetControl('button', "awh_help", 695, 65, 25, 25)
    AUTO_CAST(help)
    help:SetText("{img question_mark 15 15}")
    help:SetTextTooltip("HELP")
    help:SetEventScript(ui.LBUTTONUP, "Another_warehouse_setting_help")
    local amount_text = setting:CreateOrGetControl("richtext", "amount_text", 400, 65, 0, 30)
    AUTO_CAST(amount_text)
    amount_text:SetText(g.lang == "Japanese" and "{ol}自動入出金 金額設定" or "{ol}Auto Transfer Amount Config")
    local amount_edit = setting:CreateOrGetControl('edit', 'amount_edit', 400, 90, 150, 35)
    AUTO_CAST(amount_edit)
    amount_edit:SetFontName("white_18_ol")
    amount_edit:SetTextAlign("center", "center")
    amount_edit:SetText(GET_COMMAED_STRING(g.awh_settings.etc.auto_silver or 0))
    amount_edit:SetNumberMode(1)
    amount_edit:SetEventScript(ui.ENTERKEY, 'Another_warehouse_setting_edit')
    local team_text = setting:CreateOrGetControl("richtext", "team_text", 25, 125, 0, 0)
    AUTO_CAST(team_text);
    team_text:SetText(g.lang == "Japanese" and "{ol}チーム倉庫の共通設定" or
                          "{ol}Team Storage Common Settings")
    local char_text = setting:CreateOrGetControl("richtext", "char_text", 25, 695, 0, 0)
    AUTO_CAST(char_text)
    char_text:SetText(g.lang == "Japanese" and "{ol}チーム倉庫のキャラクター個別設定" or
                          "{ol}Team Storage Character Settings")
    local team_gb = setting:CreateOrGetControl("groupbox", "team_gb", 20, 145, setting:GetWidth() - 25, 540)
    team_gb:SetSkinName("test_frame_low")
    AUTO_CAST(team_gb)
    Another_warehouse_setting_slot_set(team_gb, 'team_slotset')
    local char_gb = setting:CreateOrGetControl("groupbox", "char_gb", 20, 715, setting:GetWidth() - 25, 330)
    char_gb:SetSkinName("test_frame_low")
    AUTO_CAST(char_gb)
    Another_warehouse_setting_slot_set(char_gb, 'char_slotset')
    setting:ShowWindow(1)
end

function Another_warehouse_setting_close(setting)
    ui.DestroyFrame(setting:GetName())
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    ACCOUNTWAREHOUSE_CLOSE(accountwarehouse)
end

function Another_warehouse_setting_check(frame, ctrl)
    local ischeck = ctrl:IsChecked()
    local ctrl_name = ctrl:GetName()
    if ctrl_name == "awh_leave" then -- 
        g.awh_settings.etc.leave_item = ischeck
    elseif ctrl_name == "awh_display_change" then
        g.awh_settings.etc.display_change = ischeck
    elseif ctrl_name == "money_check" then
        g.awh_settings.chars[g.cid].money_check = ischeck
    elseif ctrl_name == "item_check" then
        g.awh_settings.chars[g.cid].item_check = ischeck
    end
    Another_warehouse_save_settings()
    local awh = ui.GetFrame(addon_name_lower .. "awh")
    local gb = GET_CHILD(awh, "gb")
    AUTO_CAST(gb)
    local tab_index = awh:GetUserIValue("TAB_INDEX")
    Another_warehouse_frame_update(awh, gb, "", tab_index)
end

function Another_warehouse_setting_edit(frame, ctrl)
    local text = ctrl:GetText()
    local clean_text = string.gsub(text, ",", "") -- カンマを空文字に置換
    local ctrl_num = tonumber(clean_text) or 0
    if ctrl:GetName() == "amount_edit" then
        g.awh_settings.etc.auto_silver = ctrl_num
        ctrl:SetText(GET_COMMAED_STRING(g.awh_settings.etc.auto_silver))
    end
    Another_warehouse_save_settings()
end

function Another_warehouse_setting_help()
    local context = ui.CreateContextMenu("awh_setting_help_context", "{ol}[AWH] HELP", 30, 0, 100, 100)
    local msg =
        g.lang == "Japanese" and "インベントリ:マウス右クリックでチームのアイテム設定" or
            "Inventory: right mouse click to set team items"
    ui.AddContextMenuItem(context, "{ol}" .. msg, "None")
    msg = g.lang == "Japanese" and
              "インベントリ:左SHIFT+マウス右クリックで各キャラのアイテム設定" or
              "Inventory: left SHIFT+mouse right click to set items for each character"
    ui.AddContextMenuItem(context, "{ol}" .. msg, "None")
    msg = g.lang == "Japanese" and "設定スロット:左SHIFT+マウス右クリックで設定個数変更" or
              "Setting slot: left SHIFT+right mouse click to change the number of setting pieces"
    ui.AddContextMenuItem(context, "{ol}" .. msg, "None")
    msg = g.lang == "Japanese" and "設定スロット:マウス右クリックで設定消去" or
              "Setting slot: right mouse click to clear settings"
    ui.AddContextMenuItem(context, "{ol}" .. msg, "None")
    ui.OpenContextMenu(context)
end

function Another_warehouse_setting_slot_set(parent, slot_set_name)
    local slotset = parent:CreateOrGetControl('slotset', slot_set_name, 10, 10, 0, 0)
    AUTO_CAST(slotset)
    slotset:SetSlotSize(40, 40)
    slotset:EnablePop(1)
    slotset:EnableDrag(1)
    slotset:EnableDrop(1)
    slotset:SetColRow(17, 58)
    slotset:SetSpc(0, 0)
    slotset:SetSkinName('slot')
    slotset:SetEventScript(ui.DROP, "Another_warehouse_setting_swap_item")
    slotset:SetEventScript(ui.RBUTTONUP, "Another_warehouse_setting_icon_clear")
    slotset:CreateSlots()
    local slotcount = slotset:GetSlotCount()
    local items = {}
    if slot_set_name == 'team_slotset' then
        items = g.awh_settings.items
    elseif slot_set_name == 'char_slotset' then
        items = g.awh_settings.chars[g.cid].items
    end
    for i = 1, slotcount do
        local slot = GET_CHILD(slotset, "slot" .. i)
        local str_index = tostring(i)
        for key, value in pairs(items) do
            if key == str_index then
                local clsid = value.clsid
                local count = value.count
                local itemcls = GetClassByType("Item", clsid)
                slot:SetUserValue("ITEM_CLSID", clsid)
                SET_SLOT_ITEM_CLS(slot, itemcls)
                if count ~= 0 then
                    SET_SLOT_COUNT_TEXT(slot, count)
                end
            end
        end
    end
end

function Another_warehouse_setting_swap_item(parent, slot, str, num)
    local frame = parent:GetTopParentFrame()
    if frame:GetName() ~= addon_name_lower .. "awh_setting" then
        return
    end
    local items = {}
    local slot_set_name = parent:GetName()
    if slot_set_name == 'team_slotset' then
        items = g.awh_settings.items
    elseif slot_set_name == 'char_slotset' then
        items = g.awh_settings.chars[g.cid].items
    end
    local lift_icon = ui.GetLiftIcon()
    local from_slot = lift_icon:GetParent()
    local from_items = {}
    local from_slot_set_name = from_slot:GetParent():GetName()
    if from_slot_set_name == 'team_slotset' then
        from_items = g.awh_settings.items
    elseif from_slot_set_name == 'char_slotset' then
        from_items = g.awh_settings.chars[g.cid].items
    end
    local from_index = string.gsub(from_slot:GetName(), "slot", "")
    local from_data = from_items[from_index] -- データテーブルそのものを取得
    local to_index = string.gsub(slot:GetName(), "slot", "")
    local to_icon = slot:GetIcon()
    if not to_icon then
        from_items[from_index] = nil
        items[to_index] = from_data
    else
        local to_data = items[to_index]
        from_items[from_index] = to_data
        items[to_index] = from_data
    end
    Another_warehouse_save_settings()
    Another_warehouse_setting_frame_init(nil, nil, str, num)
end

function Another_warehouse_setting_icon_clear(parent, ctrl, str, num)
    if keyboard.IsKeyPressed("LSHIFT") == 1 then
        Another_warehouse_setting_count_change(parent, ctrl, str, num)
        return
    end
    local items = {}
    if parent:GetName() == 'team_slotset' then
        items = g.awh_settings.items
    elseif parent:GetName() == 'char_slotset' then
        items = g.awh_settings.chars[g.cid].items
    end
    local str_index = string.gsub(ctrl:GetName(), "slot", "")
    for key, value in pairs(items) do
        if key == str_index then
            ctrl:ClearIcon()
            ctrl:ClearText()
            items[str_index] = nil
            Another_warehouse_save_settings()
            break
        end
    end
end

function Another_warehouse_setting_count_change(frame, ctrl, strr, num)
    local slot_index = tonumber(string.gsub(ctrl:GetName(), "slot", ""))
    if slot_index then
        local cls_id = ctrl:GetUserIValue("ITEM_CLSID")
        local itemcls = GetClassByType("Item", cls_id)
        local awh_setting = ui.GetFrame(addon_name_lower .. "awh_setting")
        awh_setting:SetUserValue("SLOT_NAME", ctrl:GetParent():GetName())
        local msg = g.lang == "Japanese" and "インベントリに残す数を入力" or
                        "Enter the number to be left in the inventory"
        INPUT_NUMBER_BOX(awh_setting, msg, "Another_warehouse_setting_item_count", 0, 0, tonumber(itemcls.MaxStack),
            cls_id, tostring(slot_index), nil)
    end
end

function Another_warehouse_setting_item_count(awh_setting, count, input_frame)
    local clsid = input_frame:GetValue()
    local index = input_frame:GetUserValue("ArgString")
    local item_cls = GetClassByType("Item", clsid)
    local user_value = awh_setting:GetUserValue("SLOT_NAME")
    local items = {}
    if user_value == "char_slotset" then
        items = g.awh_settings.chars[g.cid].items
    else
        items = g.awh_settings.items
    end
    local slotset = GET_CHILD_RECURSIVELY(awh_setting, user_value)
    local slot = GET_CHILD_RECURSIVELY(slotset, "slot" .. index)
    items[tostring(index)] = {
        clsid = clsid,
        count = tonumber(count)
    }
    SET_SLOT_ITEM_CLS(slot, item_cls)
    if tonumber(count) ~= 0 then
        SET_SLOT_COUNT_TEXT(slot, tonumber(count))
    end
    Another_warehouse_save_settings()
    input_frame:ShowWindow(0)
end

function Another_warehouse_setting_rbtn(item_obj, slot)
    local icon = slot:GetIcon()
    local icon_info = icon:GetInfo()
    local iesid = icon_info:GetIESID()
    local inv_item = GET_PC_ITEM_BY_GUID(iesid)
    if not inv_item then
        return
    end
    local cls_id = icon_info.type
    local item_cls = GetClassByType("Item", cls_id)
    local obj = GetIES(inv_item:GetObject())
    if inv_item.isLockState then
        ui.SysMsg(ClMsg("MaterialItemIsLock"))
        return
    end
    if item_cls.ItemType == 'Quest' then
        ui.MsgBox(ScpArgMsg("IT_ISNT_REINFORCEABLE_ITEM"));
        return
    end
    local enable_team_trade = TryGetProp(item_cls, "TeamTrade")
    if enable_team_trade and enable_team_trade == "NO" then
        ui.SysMsg(ClMsg("ItemIsNotTradable"))
        return
    end
    local belonging_count = TryGetProp(obj, 'BelongingCount', 0)
    if belonging_count > 0 and belonging_count >= inv_item.count then
        ui.SysMsg(ClMsg("ItemIsNotTradable"))
        return
    end
    if TryGetProp(obj, 'CharacterBelonging', 0) == 1 then
        ui.SysMsg(ClMsg("ItemIsNotTradable"))
        return
    end
    local items = {}
    local slotset_name = ""
    if keyboard.IsKeyPressed("LSHIFT") == 1 then
        items = g.awh_settings.chars[g.cid].items
        slotset_name = "char_slotset"
    else
        items = g.awh_settings.items
        slotset_name = 'team_slotset'
    end
    for key, value in pairs(items) do
        if value.clsid == cls_id then
            ui.SysMsg(g.lang == "Japanese" and "既に登録済です" or "Already registered")
            return
        end
    end
    local awh_setting = ui.GetFrame(addon_name_lower .. "awh_setting")
    local slotset = GET_CHILD_RECURSIVELY(awh_setting, slotset_name)
    local slotcount = slotset:GetSlotCount()
    local index = 1
    for i = 1, slotcount do
        local awslot = GET_CHILD_RECURSIVELY(slotset, "slot" .. i)
        local slot_icon = awslot:GetIcon()
        if slot_icon == nil then
            index = i
            break
        end
    end
    local ctrl = GET_CHILD_RECURSIVELY(slotset, "slot" .. index)
    if tonumber(item_cls.MaxStack) > 1 then
        awh_setting:SetUserValue("SLOT_NAME", ctrl:GetParent():GetName())
        local msg = g.lang == "Japanese" and "インベントリに残す数を入力" or
                        "Enter the number to be left in the inventory"
        INPUT_NUMBER_BOX(awh_setting, msg, "Another_warehouse_setting_item_count", 0, 0, tonumber(item_cls.MaxStack),
            cls_id, tostring(index), nil)
    else
        items[tostring(index)] = {
            clsid = cls_id,
            count = 0
        }
        SET_SLOT_ITEM_CLS(ctrl, item_cls)
        Another_warehouse_save_settings()
    end
end

function Another_warehouse_setting_context(frame, ctrl, str, num)
    local context = ui.CreateContextMenu("awh_TAKE_SETTING", "{ol}{#FF0000}Slot Setting", 0, 20, 100, 100)
    for i, data in ipairs(g.awh_settings.take_list) do
        local name = data.name
        local scp = string.format("Another_warehouse_set_items_setting(%d,'%s')", i, name)
        ui.AddContextMenuItem(context, "{ol}{#FF0000}" .. name, scp)
    end
    ui.OpenContextMenu(context)
end

function Another_warehouse_set_items_setting(index, name)
    local awh_set_items = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "awh_set_items", 0, 0, 0, 0)
    AUTO_CAST(awh_set_items)
    awh_set_items:SetSkinName("test_frame_low")
    awh_set_items:SetPos(680, 170)
    awh_set_items:SetLayerLevel(100)
    awh_set_items:Resize(320, 608)
    awh_set_items:RemoveAllChild()
    local close = awh_set_items:CreateOrGetControl("button", "close", 0, 0, 25, 25)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Another_warehouse_set_item_close")
    local set_gb = awh_set_items:CreateOrGetControl("groupbox", "set_gb", 10, 50, 380, 380)
    AUTO_CAST(set_gb)
    set_gb:SetSkinName("test_frame_midle_light")
    set_gb:Resize(300, 500)
    awh_set_items:ShowWindow(1)
    local name_edit = awh_set_items:CreateOrGetControl("edit", "name_edit", 10, 13, 210, 30)
    AUTO_CAST(name_edit)
    name_edit:SetFontName("white_16_ol")
    name_edit:SetTextAlign("center", "center")
    name_edit:SetText("{ol}" .. name)
    name_edit:SetEventScript(ui.ENTERKEY, "Another_warehouse_set_name_edit")
    name_edit:SetEventScriptArgString(ui.ENTERKEY, name)
    name_edit:SetEventScriptArgNumber(ui.ENTERKEY, index)
    local set_slotset = set_gb:CreateOrGetControl('slotset', 'set_slotset', 0, 0, 0, 0)
    AUTO_CAST(set_slotset)
    set_slotset:SetSlotSize(50, 50)
    set_slotset:EnablePop(1)
    set_slotset:EnableDrag(1)
    set_slotset:EnableDrop(1)
    set_slotset:SetEventScript(ui.DROP, "Another_warehouse_set_swap_item")
    set_slotset:SetEventScriptArgString(ui.DROP, name)
    set_slotset:SetEventScriptArgNumber(ui.DROP, index)
    set_slotset:SetColRow(6, 10)
    set_slotset:SetSpc(0, 0)
    set_slotset:SetSkinName('slot')
    set_slotset:CreateSlots()
    local target_set = g.awh_settings.take_list[index]
    local items_map = target_set.items
    local slotcount = set_slotset:GetSlotCount()
    for i = 1, slotcount do
        local slot = GET_CHILD(set_slotset, "slot" .. i)
        AUTO_CAST(slot)
        local icon = slot:GetIcon()
        if not icon then
            slot:SetTextTooltip(g.lang == "Japanese" and "{ol}倉庫アイテム右クリックで設定" or
                                    "{ol}Warehouse items right-click to setting")
        end
        local saved_clsid = items_map[tostring(i)]
        if saved_clsid then
            local item_cls = GetClassByType("Item", saved_clsid)
            if item_cls then
                SET_SLOT_ITEM_CLS(slot, item_cls)
                slot:SetEventScript(ui.RBUTTONUP, "Another_warehouse_set_clear_item")
                slot:SetEventScriptArgNumber(ui.RBUTTONUP, index)
                slot:SetEventScriptArgString(ui.RBUTTONUP, name)
            end
        end
    end
    local init = awh_set_items:CreateOrGetControl("button", "init", 0, 0, 100, 43)
    AUTO_CAST(init)
    init:SetText(g.lang == "Japanese" and "{@st66b}初期化" or "{@st66b}Initialize")
    init:SetMargin(210, 555, 0, 0)
    init:SetSkinName("test_pvp_btn")
    init:SetEventScript(ui.LBUTTONUP, "Another_warehouse_setslot_init")
    init:SetEventScriptArgString(ui.LBUTTONUP, name)
    init:SetEventScriptArgNumber(ui.LBUTTONUP, index)
    local take = awh_set_items:CreateOrGetControl("button", "awh_take", 0, 0, 100, 43)
    AUTO_CAST(take)
    take:SetText(g.lang == "Japanese" and "{@st66b}取出し" or "{@st66b}Withdrawal")
    take:SetMargin(10, 555, 0, 0)
    take:SetSkinName("test_pvp_btn")
    take:SetEventScript(ui.LBUTTONUP, "Another_warehouse_set_item_take_reserve")
    take:SetEventScriptArgString(ui.LBUTTONUP, name)
end

function Another_warehouse_set_item_take_reserve(frame, ctrl, name)
    Another_warehouse_set_item_take(name)
end

function Another_warehouse_set_clear_item(frame, ctrl, name, index)
    local slot_index = string.gsub(ctrl:GetName(), "slot", "")
    g.awh_settings.take_list[index].items[slot_index] = nil
    Another_warehouse_save_settings()
    Another_warehouse_set_items_setting(index, name)
end

function Another_warehouse_set_swap_item(parent, slot, name, index)
    if parent:GetTopParentFrame():GetName() ~= addon_name_lower .. "awh_set_items" then
        return
    end
    local lift_icon = ui.GetLiftIcon()
    local from_slot = lift_icon:GetParent()
    local from_index = string.gsub(from_slot:GetName(), "slot", "")
    local from_clsid = g.awh_settings.take_list[index].items[from_index]
    local to_index = string.gsub(slot:GetName(), "slot", "")
    local to_icon = slot:GetIcon()
    if not to_icon then
        g.awh_settings.take_list[index].items[from_index] = nil
        g.awh_settings.take_list[index].items[to_index] = from_clsid
    else
        local to_clsid = g.awh_settings.take_list[index].items[to_index]
        g.awh_settings.take_list[index].items[from_index] = to_clsid
        g.awh_settings.take_list[index].items[to_index] = from_clsid
    end
    Another_warehouse_save_settings()
    Another_warehouse_set_items_setting(index, name)
end

function Another_warehouse_set_name_edit(frame, ctrl, name, index)
    local new_name = string.gsub(ctrl:GetText(), "{ol}", "")
    if new_name == "" then
        ui.SysMsg(g.lang == "Japanese" and "文字を入れてください" or "Please enter the text")
        return
    end
    for i, data in ipairs(g.awh_settings.take_list) do
        if new_name == data.name then
            ui.SysMsg(g.lang == "Japanese" and "既に登録済の名前です" or "Name already registered")
            return
        end
    end
    g.awh_settings.take_list[index].name = new_name
    Another_warehouse_save_settings()
    Another_warehouse_set_items_setting(index, new_name)
end

function Another_warehouse_set_item_close(frame)
    ui.DestroyFrame(addon_name_lower .. "awh_set_items")
end

function Another_warehouse_setslot_init(frame, init, name, index)
    local yes_scp = string.format("Another_warehouse_setslot_init_ok('%s',%d)", name, index)
    local msg = g.lang == "Japanese" and "{ol}{#FFFFFF}セット初期化しますか？" or
                    "{ol}{#FFFFFF}Initialize this set?"
    local msgbox = ui.MsgBox(msg, yes_scp, 'None')
end

function Another_warehouse_setslot_init_ok(name, index)
    g.awh_settings.take_list[index] = {
        name = "Take Items " .. index,
        items = {}
    }
    ui.SysMsg(g.lang == "Japanese" and "{ol}初期化しました" or "{ol}Initialized")
    Another_warehouse_save_settings()
    local new_name = "Take Items " .. index
    Another_warehouse_set_items_setting(index, new_name)
end

function Another_warehouse_take_context(frame, ctrl, str, num)
    local context = ui.CreateContextMenu("TAKE_SETTING", "{ol}Take items", 0, 20, 100, 100)
    for i, data in ipairs(g.awh_settings.take_list) do
        local name = data.name
        local scp = string.format("Another_warehouse_set_item_take('%s')", name)
        ui.AddContextMenuItem(context, name, scp)
    end
    ui.OpenContextMenu(context)
end

function Another_warehouse_set_item_take(name)
    local accountwarehouse = ui.GetFrame('accountwarehouse')
    local handle = accountwarehouse:GetUserIValue("HANDLE")
    local item_list = session.GetEtcItemList(IT_ACCOUNT_WAREHOUSE)
    session.ResetItemList()
    local sorted_guid_list = item_list:GetSortedGuidList()
    local sorted_cnt = sorted_guid_list:Count()
    local take_count = 0
    local target_items_map = {}
    if g.awh_settings.take_list then
        for i, set_data in ipairs(g.awh_settings.take_list) do
            if set_data.name == name then
                for key, item_id in pairs(set_data.items) do
                    target_items_map[tonumber(item_id)] = true
                end
                break
            end
        end
    end
    for j = 0, sorted_cnt - 1 do
        local guid = sorted_guid_list:Get(j)
        local inv_item = item_list:GetItemByGuid(guid)
        local cls_id = inv_item.type
        if target_items_map[cls_id] then
            local count = inv_item.count
            if g.awh_settings.etc.leave_item == 1 then
                count = count - 1
            end
            if count > 0 then
                session.AddItemID(guid, count)
                take_count = take_count + 1
            end
        end
    end
    if take_count > 0 then
        item.TakeItemFromWarehouse_List(IT_ACCOUNT_WAREHOUSE, session.GetItemIDList(), handle)
    end
    local awh = ui.GetFrame(addon_name_lower .. "awh")
    local gb = GET_CHILD(awh, "gb")
    AUTO_CAST(gb)
    local index = awh:GetUserIValue("TAB_INDEX")
    Another_warehouse_frame_update(awh, gb, "", index)
end

function Another_warehouse_help()
    local context = ui.CreateContextMenu("awh_help_context", "{ol}[AWH] HELP", 30, 0, 100, 100)
    local msg = g.lang == "Japanese" and "インベントリ:アイコン右クリックで全数搬入" or
                    "Inventory: right mouse click to Carry in all items"
    ui.AddContextMenuItem(context, "{ol}" .. msg, "None")
    msg = g.lang == "Japanese" and "インベントリ:アイコン左クリックで1個搬入" or
              "Inventory: left mouse click to Carry in 1 items"
    ui.AddContextMenuItem(context, "{ol}" .. msg, "None")
    msg = g.lang == "Japanese" and "インベントリ:左SHIFT+アイコン右クリックで入力数量搬入" or
              "Inventory: left SHIFT+mouse right click to Carry in Input quantity items"
    ui.AddContextMenuItem(context, "{ol}" .. msg, "None")
    msg = g.lang == "Japanese" and "インベントリ:左SHIFT+アイコン左クリックで10個搬入" or
              "Inventory: left SHIFT+mouse left click to Carry in 10 items"
    ui.AddContextMenuItem(context, "{ol}" .. msg, "None")
    ui.AddContextMenuItem(context, "----------", "None")
    msg = g.lang == "Japanese" and "チーム倉庫:アイコン右クリックで全数搬出" or
              "Warehouse: right mouse click to Carry out all items"
    ui.AddContextMenuItem(context, "{ol}" .. msg, "None")
    msg = g.lang == "Japanese" and "チーム倉庫:アイコン左クリックで1個搬出" or
              "Warehouse: left mouse click to Carry out 1 items"
    ui.AddContextMenuItem(context, "{ol}" .. msg, "None")
    msg = g.lang == "Japanese" and "チーム倉庫:左SHIFT+アイコン右クリックで入力数量搬出" or
              "Warehouse: left SHIFT+mouse right click to Carry out Input quantity items"
    ui.AddContextMenuItem(context, "{ol}" .. msg, "None")
    msg = g.lang == "Japanese" and "チーム倉庫:左SHIFT+アイコン左クリックで10個搬出" or
              "Warehouse: left SHIFT+mouse left click to Carry out 10 items"
    ui.AddContextMenuItem(context, "{ol}" .. msg, "None")
    ui.OpenContextMenu(context)
end
-- another_warehouse ここまで

