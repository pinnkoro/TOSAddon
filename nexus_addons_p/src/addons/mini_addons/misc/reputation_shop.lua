-- EP13ショップを街で開ける
function Mini_addons_REPUTATION_SHOP_OPEN()
    local inventory = ui.GetFrame("inventory")
    local inventory_accpropinv = GET_CHILD_RECURSIVELY(inventory, "inventory_accpropinv")
    AUTO_CAST(inventory_accpropinv)
    if g.get_map_type() == "City" then
        inventory_accpropinv:SetEventScript(ui.RBUTTONUP, "Mini_addons_REPUTATION_SHOP_OPEN_context")
        inventory_accpropinv:SetEventScript(ui.RBUTTONDOWN, "Mini_addons_reputation_shop_close")
    else
        inventory_accpropinv:SetEventScript(ui.RBUTTONUP, "None")
        inventory_accpropinv:SetEventScript(ui.RBUTTONDOWN, "None")
    end
end

function Mini_addons_ON_REQUEST_REPUTATION_SHOP_OPEN(shop_type)
    REPUTATION_SHOP_SET_SHOPTYPE(shop_type)
    ui.OpenFrame("reputation_shop")
end

function Mini_addons_REPUTATION_SHOP_OPEN_context(frame, ctrl, str, num)
    local context = ui.CreateContextMenu("select_shop", "EP13 Shop List ", 0, -200, 0, 0)
    local shop_tbl = {{
        name = "REPUTATION_ep13_f_siauliai_1",
        id = 11209,
        text = ClMsg("MonInfo_RaceType_Velnias"),
        box = ""
    }, {
        name = "REPUTATION_ep13_f_siauliai_2",
        id = 11210,
        text = ClMsg("MonInfo_RaceType_Widling"),
        box = ""
    }, {
        name = "REPUTATION_ep13_f_siauliai_3",
        id = 11211,
        text = ClMsg("MonInfo_RaceType_Klaida"),
        box = GetClassByType("Item", 640530).Name
    }, {
        name = "REPUTATION_ep13_f_siauliai_4",
        id = 11212,
        text = ClMsg("MonInfo_RaceType_Paramune"),
        box = GetClassByType("Item", 640531).Name
    }, {
        name = "REPUTATION_ep13_f_siauliai_5",
        id = 11213,
        text = ClMsg("MonInfo_RaceType_Forester"),
        box = ""
    }}
    for index, shop in ipairs(shop_tbl) do
        local shop_name = shop.name
        local id = shop.id
        local map_name = GetClassByType("Map", id).Name
        local box = shop.box
        -- 文言は言語ごとに出し分ける。**「製造書」は日本語分岐にしか無かった**ので、
        -- 韓国語クライアントでも英語の "Recipe" が出ていた(Issue #68)。
        -- 「型」→「憤怒ポーション」の差し替えは日本語の訳文にだけ要る整形なので、そのまま残す。
        local text
        if g.lang == "Japanese" then
            text = string.gsub(dic.getTranslatedStr(shop.text), "型", " 憤怒ポーション ") .. "製造書 : " .. box
        elseif g.lang == "kr" then
            text = shop.text .. " 제조서 : " .. box
        else
            text = shop.text .. " Recipe : " .. box
        end
        ui.AddContextMenuItem(context, map_name .. " (" .. text .. ") ",
            string.format("Mini_addons_ON_REQUEST_REPUTATION_SHOP_OPEN('%s')", shop_name))
    end
    ui.OpenContextMenu(context)
end

function Mini_addons_reputation_shop_close()
    local shopframe = ui.GetFrame("reputation_shop")
    if shopframe:IsVisible() == 1 then
        ui.CloseFrame("reputation_shop")
        ui.ToggleFrame("inventory")
    end
end
