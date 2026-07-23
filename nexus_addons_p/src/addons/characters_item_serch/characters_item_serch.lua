-- characters_item_serch ここから
g.characters_item_serch = g.characters_item_serch or {}

-- OFF のときは倉庫/インベントリの収集を一切走らせない。
--
-- on_init は ON/OFF によらず全アドオン分呼ばれる(core/20_lifecycle.lua)ので、
-- OFF のままでも WAREHOUSE_CLOSE などのフックは張られる。以前はそれでも黙って
-- .dat を書くだけだったが、取得できないアイテムがあると中止をチャットに知らせる
-- ようにした結果、OFF の利用者にも倉庫を閉じるたび [CIS] のメッセージが出ていた。
-- フックの解除は仕組み上できないので、入口側で止める。
local function characters_item_serch_enabled()
    local setting = g.settings and g.settings.characters_item_serch
    return setting ~= nil and setting.use == 1
end

-- 実体(IES)を引けなかったアイテムを、クラス定義の名前だけで記録するための代替。
--
-- 倉庫には iesid が 0 で返るアイテムが混じることがあり、それは GetObjectByGuid では
-- 引けない(実機ログ: チーム倉庫 298 件のうち 1 件)。v1.0.2 は 1 件でも引けなければ
-- 保存ごと中止するので、**その 1 件の巻き添えで倉庫まるごと記録されなくなっていた**。
-- それ以前は黙って捨てていたので、その 1 件だけが検索に出ていなかった。
--
-- .dat の検索は行の文字列一致で、表示に使うのはクラス ID と個数だけなので、
-- 個体名(強化値や付与)が落ちてもアイテム名さえ入っていれば検索としては成立する。
-- 実体を引けたものは従来どおり実体の名前を使うので、粗くなるのは代替に落ちた分だけ。
local function characters_item_serch_class_name(clsid)
    if not clsid or clsid == 0 then
        return nil
    end
    local item_cls = GetClassByType('Item', clsid)
    if not item_cls or not item_cls.Name then
        return nil
    end
    return string.lower(dictionary.ReplaceDicIDInCompStr(item_cls.Name))
end

function Characters_item_serch_save_settings()
    g.save_json(g.characters_item_serch_path, g.characters_item_serch_settings)
end

function Characters_item_serch_load_settings()
    g.characters_item_serch_path = string.format("../addons/%s/%s/characters_item_serch.json", addon_name_lower,
        g.active_id)
    g.characters_item_serch_dat_tbl = {string.format("../addons/%s/%s/characters_item_serch_warehouse.dat",
        addon_name_lower, g.active_id),
                                       string.format("../addons/%s/%s/characters_item_serch_inventory.dat",
        addon_name_lower, g.active_id),
                                       string.format("../addons/%s/%s/characters_item_serch_equips.dat",
        addon_name_lower, g.active_id),
                                       string.format("../addons/%s/%s/characters_item_serch_accountwarehouse.dat",
        addon_name_lower, g.active_id)}
    g.characters_item_serch_old_dat_tbl = {string.format("../addons/%s/%s/warehouse.dat", "characters_item_serch",
        g.active_id), string.format("../addons/%s/%s/inventory.dat", "characters_item_serch", g.active_id),
                                           string.format("../addons/%s/%s/equips.dat", "characters_item_serch",
        g.active_id)}

    local settings = g.load_json(g.characters_item_serch_path)
    if not settings then
        settings = {
            chars = {}
        }
    end
    g.characters_item_serch_settings = settings
    Characters_item_serch_save_settings()
    for i = 1, #g.characters_item_serch_dat_tbl - 1 do
        local new_path = g.characters_item_serch_dat_tbl[i]
        local old_path = g.characters_item_serch_old_dat_tbl[i]
        local new_file = io.open(new_path, "r")
        if not new_file then
            local content_to_write = ""
            if old_path then
                local old_file = io.open(old_path, "r")
                if old_file then
                    content_to_write = old_file:read("*all")
                    old_file:close()
                end
            end
            local file_to_write = io.open(new_path, "w")
            if file_to_write then
                file_to_write:write(content_to_write)
                file_to_write:close()
            end
        else
            new_file:close()
        end
    end
end

function characters_item_serch_on_init()
    if _G["BARRACK_CHARLIST_ON_INIT"] and _G["current_layer"] then
        g.characters_item_serch.layer = _G["current_layer"] or 1
    end
    if not g.characters_item_serch_settings then
        Characters_item_serch_load_settings()
    end
    local old_func = g.settings.characters_item_serch.old_init_func
    if _G[old_func] then
        return
    end
    g.setup_hook_and_event(g.addon, "APPS_TRY_LEAVE", "Characters_item_serch_APPS_TRY_LEAVE", true)
    g.setup_hook_and_event(g.addon, "INVENTORY_CLOSE", "Characters_item_serch_INVENTORY_CLOSE", true)
    g.setup_hook_and_event(g.addon, "ACCOUNTWAREHOUSE_CLOSE", "Characters_item_serch_ACCOUNTWAREHOUSE_CLOSE", true)
    g.setup_hook_and_event(g.addon, "WAREHOUSE_CLOSE", "Characters_item_serch_WAREHOUSE_CLOSE", true)
    local sysmenu = ui.GetFrame("sysmenu")
    local inven = GET_CHILD(sysmenu, "inven")
    AUTO_CAST(inven)
    inven:SetEventScript(ui.RBUTTONUP, "Characters_item_serch_toggle_frame")
    local function get_localized_tooltip(lang)
        if lang == "Japanese" then
            return "{@st59}インベントリ (F2){nl}右クリック: Characters Item Serch"
        elseif lang == "kr" then
            return "{@st59}인벤토리 (F2){nl}Right click: Characters Item Serch"
        else
            return "{@st59}Inventory (F2){nl}Right click: Characters Item Serch"
        end
    end
    local tooltip = get_localized_tooltip(g.lang)
    inven:SetTextTooltip(tooltip)
    Characters_item_serch_char_data()
end

function Characters_item_serch_toggle_frame()
    if g.settings.characters_item_serch.use == 0 then
        return
    end
    local characters_item_serch = ui.GetFrame(addon_name_lower .. "characters_item_serch")
    if not characters_item_serch then
        Characters_item_serch_frame_init(nil, nil, g.login_name, 0)
    elseif characters_item_serch and characters_item_serch:IsVisible() == 0 then
        Characters_item_serch_frame_init(nil, nil, g.login_name, 0)
    elseif characters_item_serch:IsVisible() == 1 then
        Characters_item_serch_close(characters_item_serch)
    end
end

function Characters_item_serch_char_data()
    local chars = g.characters_item_serch_settings["chars"]
    local acc_info = session.barrack.GetMyAccount()
    local pc_count = acc_info:GetPCCount()
    for i = 0, pc_count - 1 do
        local pc_info = acc_info:GetPCByIndex(i)
        if pc_info then
            local pc_cid = pc_info:GetCID()
            local pc_apc = pc_info:GetApc()
            if pc_apc then
                local pc_name = pc_apc:GetName()
                chars[pc_name] = {
                    name = pc_name,
                    layer = g.characters_item_serch.layer,
                    order = i,
                    cid = pc_cid
                }
            end
        end
    end
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
        for char_name, _ in pairs(chars) do
            if not barrack_chars[char_name] then
                table.insert(chars_to_delete, char_name)
            end
        end
        if #chars_to_delete > 0 then
            for _, char_name in ipairs(chars_to_delete) do
                chars[char_name] = nil
            end
        end
    end
    Characters_item_serch_save_settings()
end

function Characters_item_serch_APPS_TRY_LEAVE(my_frame, my_msg)
    local type = g.get_event_args(my_msg)
    if type == "Exit" or type == "Logout" or type == "Barrack" then
        Characters_item_serch_inventory_save_list()
    end
end

function Characters_item_serch_INVENTORY_CLOSE()
    Characters_item_serch_inventory_save_list()
end

-- 倉庫の保存を中止したことを利用者に伝える。
--
-- 中止すると .dat は前回のまま残るので、取り出したアイテムが検索結果に出続ける等、
-- 内容が実際の倉庫とズレたままになる。詳細ログは既定 OFF なので、それだけだと
-- 気付く手段が無く「検索がおかしい」としか見えない。倉庫を閉じたときにしか
-- 呼ばれない = 連呼にはならないので、その都度チャットに出す。
--
-- 欠けたまま上書きせず前回を残すという方針自体は変えない(欠落した .dat で
-- 上書きするより実害が小さい)。知らせるところだけを足している。
--
-- ここへ来るのは、実体もクラス定義も引けずアイテム名がまったく作れなかったときだけ。
-- 「実体を引けない」だけなら上のクラス定義での代替で拾うので、通常は呼ばれない。
function Characters_item_serch_notify_save_abort(is_account, iesid)
    local ja = g.lang == "Japanese"
    local where
    if is_account then
        where = ja and "チーム倉庫" or "Account Warehouse"
    else
        where = ja and "個人倉庫" or "Warehouse"
    end
    g.vlog("characters_item_serch: %s のアイテムを引けないため保存を中止 iesid=%s", where, tostring(iesid))
    if ja then
        ui.SysMsg("{ol}{#FF6347}[CIS]{/} " .. where ..
                      "のアイテム情報を取得できなかったため、今回の保存を中止しました{nl}検索結果は前回のままです")
    else
        ui.SysMsg("{ol}{#FF6347}[CIS]{/} Could not read " .. where ..
                      " items, so this save was aborted{nl}Search results remain from the previous scan")
    end
end

function Characters_item_serch_ACCOUNTWAREHOUSE_CLOSE()
    if not characters_item_serch_enabled() then
        return
    end
    local item_list = session.GetEtcItemList(IT_ACCOUNT_WAREHOUSE)
    local sorted_guid_list = item_list:GetSortedGuidList()
    local count = sorted_guid_list:Count()
    local items_to_save = {}
    local by_class = 0
    local by_class_clsid
    for i = 0, count - 1 do
        local guid = sorted_guid_list:Get(i)
        local aw_item = item_list:GetItemByGuid(guid)
        if aw_item then
            local clsid = aw_item.type
            local iesid = aw_item:GetIESID()
            -- 実体を引けたら個体名を使い、駄目ならクラス定義の名前で代用する
            -- (大半は実体を引ける。iesid が 0 で返る個体がまれに混じる)。
            local obj = GetObjectByGuid(iesid)
            local item_name
            if obj then
                item_name = string.lower(dictionary.ReplaceDicIDInCompStr(obj.Name))
            else
                item_name = characters_item_serch_class_name(clsid)
                by_class = by_class + 1
                by_class_clsid = by_class_clsid or clsid
            end
            -- 名前がどうしても取れないもの(クラス定義すら引けない)は検索に出しようがない。
            -- ここは is_overwrite=true で .dat を丸ごと置き換えるので、落として保存すると
            -- 検索から消える。欠けたまま上書きせず前回を残す。
            if not item_name then
                Characters_item_serch_notify_save_abort(true, iesid)
                return
            end
            local item_count = aw_item.count
            local item_cls = GetClassByType('Item', clsid)
            local category = "false"
            if item_cls and item_cls.MarketCategory ~= "None" then
                category = item_cls.MarketCategory:match("^(.-)_")
            end
            table.insert(items_to_save,
                {g.lang == "Japanese" and "チーム倉庫" or "Account Warehouse", iesid, clsid, item_count, item_name,
                 "accountwarehouse", category})
        end
    end
    -- 倉庫を閉じたときにしか通らないので、1 回の開閉につき 1 行。件数を出すのは
    -- 「代替の名前で記録できた」のか「そもそも 0 件しか拾えていない」のかを
    -- ログだけで見分けるため(この経路が壊れると検索結果が黙って空になる)。
    -- 代替に落ちた個体は clsid も出す。実体を引けないのが特定のアイテムに
    -- 偏るのかどうかを、利用者から送られたログだけで確かめられるようにする。
    g.vlog("characters_item_serch: チーム倉庫 %d/%d 件を保存(うち %d 件はクラス定義の名前 clsid=%s)",
        #items_to_save, count, by_class, tostring(by_class_clsid))
    local dat_file_path = g.characters_item_serch_dat_tbl[4]
    Characters_item_serch_save_item_list_to_dat(dat_file_path, items_to_save, true)
end

function Characters_item_serch_save_item_list_to_dat(dat_path, items_to_save, is_overwrite)
    local lines = {}
    if not is_overwrite then
        local file_read = io.open(dat_path, "r")
        if file_read then
            for line in file_read:lines() do
                if line:match("^(.-):::") ~= g.login_name then
                    table.insert(lines, line)
                end
            end
            file_read:close()
        end
    end
    for _, item in ipairs(items_to_save) do
        table.insert(lines, table.concat(item, ":::"))
    end
    local file = io.open(dat_path, "w")
    if file then
        file:write(table.concat(lines, "\n"))
        file:close()
    end
end

function Characters_item_serch_inventory_save_list()
    if not characters_item_serch_enabled() then
        return
    end
    local inv_item_list = session.GetInvItemList()
    local inv_guid_list = inv_item_list:GetGuidList()
    local cnt = inv_guid_list:Count()
    -- inventory save
    local items = {}
    for i = 0, cnt - 1 do
        local guid = inv_guid_list:Get(i)
        local inv_Item = inv_item_list:GetItemByGuid(guid)
        local inv_obj = GetIES(inv_Item:GetObject())
        local inv_clsid = inv_obj.ClassID
        local inv_count = inv_Item.count
        local item_cls = GetClassByType('Item', inv_clsid)
        local category = "false"
        if item_cls ~= nil and item_cls.MarketCategory ~= "None" then
            category = item_cls.MarketCategory:match("^(.-)_")
        end
        local item_name = string.lower(dictionary.ReplaceDicIDInCompStr(inv_obj.Name))
        table.insert(items, {g.login_name, guid, inv_clsid, inv_count, item_name, "inventory", category})
    end
    local inventory_dat = g.characters_item_serch_dat_tbl[2]
    Characters_item_serch_save_item_list_to_dat(inventory_dat, items)
    -- equips save
    local items = {}
    local equiplist = session.GetEquipItemList()
    for i = 0, equiplist:Count() - 1 do
        local equip_item = equiplist:GetEquipItemByIndex(i)
        local obj = GetIES(equip_item:GetObject())
        if obj ~= nil then
            local iesid = equip_item:GetIESID()
            if iesid ~= "0" then
                local clsid = obj.ClassID
                local item_cls = GetClassByType('Item', clsid)
                local category = "false"
                if item_cls ~= nil and item_cls.MarketCategory ~= "None" then
                    category = item_cls.MarketCategory:match("^(.-)_")
                end
                local item_name = string.lower(dictionary.ReplaceDicIDInCompStr(obj.Name))
                table.insert(items, {g.login_name, iesid, clsid, 1, item_name, "equips", category})
            end
        end
    end
    local mc_frame = ui.GetFrame("monstercardslot")
    for i = 1, 14 do
        local card_info = equipcard.GetCardInfo(i)
        if card_info then
            local clsid = card_info:GetCardID()
            local item_cls = GetClassByType("Item", clsid)
            local item_name = string.lower(dictionary.ReplaceDicIDInCompStr(item_cls.Name))
            local category = "false"
            if item_cls ~= nil and item_cls.MarketCategory ~= "None" then
                category = item_cls.MarketCategory:match("^(.-)_")
            end
            table.insert(items, {g.login_name, "None" .. i, clsid, 1, item_name, "equips", category})
        end
    end
    local equips_dat = g.characters_item_serch_dat_tbl[3]
    Characters_item_serch_save_item_list_to_dat(equips_dat, items)
end

function Characters_item_serch_WAREHOUSE_CLOSE()
    if not characters_item_serch_enabled() then
        return
    end
    local warehouse = ui.GetFrame('warehouse')
    if not warehouse then
        return
    end
    local gbox = warehouse:GetChild("gbox")
    local slotset = gbox and gbox:GetChild("slotset")
    if not slotset then
        return
    end
    AUTO_CAST(slotset)
    local items = {}
    local by_class = 0
    local by_class_clsid
    for i = 0, slotset:GetSlotCount() - 1 do
        local slot = slotset:GetSlotByIndex(i)
        local icon = slot:GetIcon()
        if icon then
            local icon_info = icon:GetInfo()
            local iesid = icon_info:GetIESID()
            -- guid からオブジェクトを引けないことがあるので nil ガード。
            -- 引けたときは従来どおり実体を使い、駄目ならスロットが持つクラス ID から
            -- 代替の名前を作る(チーム倉庫側と同じ扱い)。
            local obj = GetObjectByGuid(iesid)
            local clsid, item_name
            if obj then
                clsid = obj.ClassID
                item_name = string.lower(dictionary.ReplaceDicIDInCompStr(obj.Name))
            else
                clsid = icon_info.type
                item_name = characters_item_serch_class_name(clsid)
                by_class = by_class + 1
                by_class_clsid = by_class_clsid or clsid
            end
            -- 名前もクラス ID も取れないものは検索に出しようがない。保存はこのキャラの
            -- 倉庫行を全部書き換えるので、黙って落とすと検索結果から消える。
            -- 中止して前回の .dat を残す(欠落したまま上書きするより実害が小さい)。
            if not clsid or not item_name then
                Characters_item_serch_notify_save_abort(false, iesid)
                return
            end
            local item_cls = GetClassByType('Item', clsid)
            local category = "false"
            if item_cls and item_cls.MarketCategory ~= "None" then
                category = item_cls.MarketCategory:match("^(.-)_")
            end
            table.insert(items, {g.login_name, iesid, clsid, icon_info.count, item_name, "warehouse", category})
        end
    end
    g.vlog("characters_item_serch: 個人倉庫 %d 件を保存(うち %d 件はクラス定義の名前 clsid=%s)", #items, by_class,
        tostring(by_class_clsid))
    local warehouse_dat = g.characters_item_serch_dat_tbl[1]
    Characters_item_serch_save_item_list_to_dat(warehouse_dat, items)
end

function Characters_item_serch_load_data(select_name, search_mode, search_text)
    local dat_tbl = {}
    for i = 1, #g.characters_item_serch_dat_tbl - 1 do
        table.insert(dat_tbl, g.characters_item_serch_dat_tbl[i])
    end
    local items = {}
    local target_name = (select_name == "") and g.login_name or select_name
    if search_mode == "ITEM_SEARCH" then
        table.insert(dat_tbl, g.characters_item_serch_dat_tbl[4])
    end
    local valid_chars = g.characters_item_serch_settings["chars"]
    for _, dat_file_path in ipairs(dat_tbl) do
        local file = io.open(dat_file_path, "r")
        if file then
            local content = file:read("*all")
            file:close()
            for line in content:gmatch("([^\n]+)") do
                local is_match = false
                if search_mode == "ITEM_SEARCH" then
                    if string.find(string.lower(line), string.lower(search_text)) then
                        is_match = true
                    end
                else
                    if line:find(target_name, 1, true) == 1 then
                        is_match = true
                    end
                end
                if is_match then
                    local parts = {}
                    for part in (line .. ":::"):gmatch("(.-):::") do
                        table.insert(parts, part)
                    end
                    if #parts > 0 and parts[#parts] == "" then
                        table.remove(parts)
                    end
                    local char_name = parts[1]
                    local is_valid_char = false
                    if valid_chars[char_name] or char_name == "チーム倉庫" or char_name == "Account Warehouse" then
                        is_valid_char = true
                    end
                    if is_valid_char then
                        if search_mode == "ITEM_SEARCH" then
                            parts[3] = tonumber(parts[3]) or 0
                        else
                            table.remove(parts, 1)
                            if #parts > 0 then
                                parts[2] = tonumber(parts[2]) or 0
                            end
                        end
                        if #parts > 0 then
                            table.insert(items, parts)
                        end
                    end
                end
            end
        end
    end
    if search_mode == "ITEM_SEARCH" then
        table.sort(items, function(a, b)
            local a_is_warehouse = (a[1] == "チーム倉庫" or a[1] == "Account Warehouse")
            local b_is_warehouse = (b[1] == "チーム倉庫" or b[1] == "Account Warehouse")
            if a_is_warehouse and not b_is_warehouse then
                return false
            elseif not a_is_warehouse and b_is_warehouse then
                return true
            else
                return a[3] < b[3]
            end
        end)
    else
        table.sort(items, function(a, b)
            return a[2] < b[2]
        end)
    end
    return items
end

function Characters_item_serch_item_search(my_frame, ctrl, str, num)
    local characters_item_serch = ctrl:GetTopParentFrame()
    local search_edit = GET_CHILD(characters_item_serch, "search_edit")
    AUTO_CAST(search_edit)
    local search_text = search_edit:GetText()
    if search_text == "" then
        Characters_item_serch_frame_init(nil, nil, g.login_name, 0)
        return
    end
    local gb = GET_CHILD(characters_item_serch, "gb")
    gb:RemoveAllChild()
    local tree = gb:CreateOrGetControl("tree", 'name_tree', 0, 0, 0, 0)
    AUTO_CAST(tree)
    tree:Clear()
    tree:EnableDrawFrame(false)
    tree:SetFitToChild(true, 10)
    tree:SetFontName("white_16_ol")
    local items = Characters_item_serch_load_data("", "ITEM_SEARCH", search_text)
    local names = {}
    for i = 1, #items do
        local item = items[i]
        local name = item[1]
        if not names[name] then
            names[name] = true
            local slot_set = Characters_item_serch_make_inven_slotset(tree, name)
            tree:Add(name)
            tree:Add(slot_set, name)
        end
    end
    for i = 1, #items do
        local item = items[i]
        local name = item[1]
        local clsid = item[3]
        local item_count = item[4]
        local slot_set = GET_CHILD(tree, name)
        Characters_item_serch_insert_item_to_tree(slot_set, clsid, item_count)
    end
    tree:Resize(characters_item_serch:GetWidth() - 40, characters_item_serch:GetHeight() - 135)
    tree:OpenNodeAll()
end

function Characters_item_serch_get_sorted_sub_categories(items)
    local subcategories = {}
    local subcategory_list = {}
    local subcategory_order = {
        ["false"] = 1,
        ["equips"] = 2,
        ["warehouse"] = 3,
        ["Weapon"] = 4,
        ["Armor"] = 5,
        ["HairAcc"] = 6,
        ["Accessory"] = 7,
        ["nil"] = 8,
        ["Premium"] = 9,
        ["Look"] = 10,
        ["ChangeEquip"] = 11,
        ["Misc"] = 12,
        ["Consume"] = 13,
        ["Recipe"] = 14,
        ["Card"] = 15,
        ["Gem"] = 16,
        ["Ancient"] = 17,
        ["OPTMisc"] = 18,
        ["PHousing"] = 19
    }
    local function get_order(name)
        return subcategory_order[name] or 100
    end
    for i = 1, #items do
        local item = items[i]
        local category = item[5]
        local sub_category = item[6]
        local target_category = (category == "inventory") and sub_category or category
        if not subcategories[target_category] then
            subcategories[target_category] = true
            table.insert(subcategory_list, target_category)
        end
    end
    table.sort(subcategory_list, function(a, b)
        return get_order(a) < get_order(b)
    end)
    return subcategory_list
end

function Characters_item_serch_frame_init(frame, ctrl, select_name, num)
    local list_frame = ui.GetFrame(addon_name_lower .. "list_frame")
    if not list_frame then
        list_frame = _nexus_addons_p_frame_init()
        list_frame:ShowWindow(0)
    end
    local characters_item_serch = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "characters_item_serch", 0, 0,
        70, 30)
    AUTO_CAST(characters_item_serch)
    characters_item_serch:SetSkinName("test_frame_low")
    characters_item_serch:Resize(670, 1080)
    characters_item_serch:SetPos(list_frame:GetX() + list_frame:GetWidth(), 0)
    characters_item_serch:EnableMove(0)
    characters_item_serch:SetLayerLevel(999)
    characters_item_serch:SetTitleBarSkin("None")
    characters_item_serch:RemoveAllChild()
    characters_item_serch:ShowWindow(1)
    local title_gb = characters_item_serch:CreateOrGetControl("groupbox", "title_gb", 0, 0,
        characters_item_serch:GetWidth(), 55)
    title_gb:SetSkinName("test_frame_top")
    AUTO_CAST(title_gb)
    local title_text = title_gb:CreateOrGetControl("richtext", "title_text", 0, 0, ui.CENTER_HORZ, ui.TOP, 0, 15, 0, 0)
    AUTO_CAST(title_text)
    title_text:SetText('{ol}{s26}Characters Item Serch')
    local close = characters_item_serch:CreateOrGetControl("button", "close", 0, 0, 25, 25)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Characters_item_serch_close")
    local login_name = characters_item_serch:CreateOrGetControl("richtext", "login_name", 20, 60, 0, 0)
    AUTO_CAST(login_name)
    login_name:SetText(select_name == "" and '{ol}{s18}' .. g.login_name or '{ol}{s18}' .. select_name)
    local char_switch = characters_item_serch:CreateOrGetControl("button", "char_switch", 20, 85, 150, 30)
    AUTO_CAST(char_switch)
    char_switch:SetText(g.lang == "Japanese" and "{ol}キャラクター切替" or "{ol}character switch")
    char_switch:SetSkinName("test_pvp_btn")
    char_switch:SetEventScript(ui.LBUTTONUP, "Characters_item_serch_context")
    local search_edit = characters_item_serch:CreateOrGetControl("edit", "search_edit", 200, 80, 250, 40)
    AUTO_CAST(search_edit)
    search_edit:SetFontName("white_18_ol")
    search_edit:SetTextAlign("left", "center")
    search_edit:SetSkinName("inventory_serch")
    search_edit:SetEventScript(ui.ENTERKEY, "Characters_item_serch_item_search")
    local search_btn = search_edit:CreateOrGetControl("button", "search_btn", 0, 0, 60, 38)
    AUTO_CAST(search_btn)
    search_btn:SetImage("inven_s")
    search_btn:SetGravity(ui.RIGHT, ui.TOP)
    search_btn:SetEventScript(ui.LBUTTONUP, "Characters_item_serch_item_search")
    local gb = characters_item_serch:CreateOrGetControl("groupbox", "gb", 20, 120,
        characters_item_serch:GetWidth() - 40, characters_item_serch:GetHeight() - 135)
    gb:SetSkinName("test_frame_midle")
    AUTO_CAST(gb)
    gb:RemoveAllChild()
    local tree = gb:CreateOrGetControl("tree", 'tree', 0, 0, 0, 0)
    AUTO_CAST(tree)
    tree:Clear()
    tree:EnableDrawFrame(false)
    tree:SetFitToChild(true, 10)
    tree:SetFontName("white_16_ol")
    -- tree:SetTabWidth(80)
    Characters_item_serch_build_tree(characters_item_serch, tree, select_name)
end

function Characters_item_serch_close(characters_item_serch)
    ui.DestroyFrame(characters_item_serch:GetName())
end

function Characters_item_serch_context()
    local chars = g.characters_item_serch_settings["chars"]
    local sorted_chars = {}
    for name, data in pairs(chars) do
        table.insert(sorted_chars, {
            name = name,
            data = data
        })
    end
    table.sort(sorted_chars, function(a, b)
        return a.data.layer < b.data.layer or (a.data.layer == b.data.layer and a.data.order < b.data.order)
    end)
    local context = ui.CreateContextMenu("Characters_item_serch_context", "{ol}Characters", 0, 0, 120, 0)
    ui.AddContextMenuItem(context, "-----")
    for _, char_data in ipairs(sorted_chars) do
        local char_name = char_data.name
        local escaped_name = string.gsub(char_name, "'", "\\'")
        local str_scp = string.format("Characters_item_serch_frame_init(nil,nil,'%s', 0)", escaped_name)
        ui.AddContextMenuItem(context, char_name, str_scp)
    end
    ui.OpenContextMenu(context)
end

function Characters_item_serch_build_tree(characters_item_serch, tree, select_name)
    local items = Characters_item_serch_load_data(select_name)
    local sub_category_list = Characters_item_serch_get_sorted_sub_categories(items)
    local category_display_names = {
        warehouse = g.lang == "Japanese" and "倉庫" or "Warehouse",
        equips = g.lang == "Japanese" and "装備中" or "Equips",
        Ancient = g.lang == "Japanese" and "アシスター" or "Ancient",
        ["nil"] = g.lang == "Japanese" and "レリック" or "Relic",
        PHousing = g.lang == "Japanese" and "家具" or "Housing"
    }
    local silver = 0
    for i = 1, #items do
        if items[i][3] == 900011 then
            silver = items[i][4]
            break
        end
    end
    local categorized_items = {}
    for _, item in ipairs(items) do
        local category = item[5]
        local sub_category = item[6]
        local target_category = (category == "inventory") and sub_category or category
        if not categorized_items[target_category] then
            categorized_items[target_category] = {}
        end
        table.insert(categorized_items[target_category], item)
    end
    local iesids = {}
    for i = 1, #sub_category_list do
        local category = sub_category_list[i]
        local disp_category
        if category == "false" then
            disp_category = "     " .. "{img icon_item_silver 20 20}" .. " " .. GET_COMMAED_STRING(tonumber(silver))
            tree:Add(disp_category)
        else
            disp_category = category_display_names[category] or ClMsg(category)
            local new_slots = Characters_item_serch_make_inven_slotset(tree, category)
            tree:Add(disp_category)
            tree:Add(new_slots, category)
            local items_in_category = categorized_items[category] or {}
            for _, item in ipairs(items_in_category) do
                local iesid, clsid, item_count = item[1], item[2], item[3]
                if not iesids[iesid] then
                    iesids[iesid] = true
                    Characters_item_serch_insert_item_to_tree(new_slots, clsid, item_count)
                end
            end
        end
    end
    tree:Resize(characters_item_serch:GetWidth() - 40, characters_item_serch:GetHeight() - 135)
    tree:OpenNodeAll()
end

function Characters_item_serch_make_inven_slotset(tree, name)
    local slotset = tree:CreateOrGetControl('slotset', name, 20, 0, 0, 0)
    AUTO_CAST(slotset)
    slotset:EnablePop(0)
    slotset:EnableDrag(0)
    slotset:EnableDrop(0)
    slotset:SetMaxSelectionCount(999)
    slotset:SetSlotSize(40, 40)
    slotset:SetColRow(15, 1)
    slotset:SetSpc(0, 0)
    slotset:SetSkinName('invenslot')
    slotset:EnableSelection(0)
    slotset:CreateSlots()
    return slotset
end

function Characters_item_serch_insert_item_to_tree(new_slots, clsid, item_count)
    local slot_count = new_slots:GetSlotCount()
    local count = new_slots:GetUserIValue("SLOT_ITEM_COUNT") or 0
    while slot_count <= count do
        new_slots:ExpandRow()
        slot_count = new_slots:GetSlotCount()
    end
    local slot = new_slots:GetSlotByIndex(count)
    count = count + 1
    new_slots:SetUserValue("SLOT_ITEM_COUNT", count)
    slot:ShowWindow(1)
    local item_cls = GetClassByType('Item', clsid)
    if item_cls then
        slot:SetSkinName('invenslot2')
        SET_SLOT_ITEM_CLS(slot, item_cls)
        SET_SLOT_BG_BY_ITEMGRADE(slot, item_cls)
        if tonumber(item_count) > 1 then
            SET_SLOT_COUNT_TEXT(slot, item_count, "{ol}{s14}")
        end
    end
end
-- characters_item_serch ここまで

