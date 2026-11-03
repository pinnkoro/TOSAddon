-- インベントリイコル検索
--
-- **素の INVENTORY_TOTAL_LIST_GET を書き写さない。** 以前は丸ごと写していて、素が 409316 のパッチで
-- 組み立ての最後に INV_TITLE_FLUSH を呼ぶ作りへ変わったとき、写しだけ古いまま残った。見出しの個数が
-- (0) のままになり、個数の控えが組み立て直しをまたいで増え続けるので、スロットが下へずれて空白だらけになった。
--
-- 検索語が空なら素をそのまま呼ぶ。検索中は素を呼び、その同期実行の間だけ次の 2 つを横取りする(抜けるときは必ず戻す)。
--   * session.GetInvItemSortedList … 検索に当たったアイテムだけの一覧を返す
--   * GET_CHILD_RECURSIVELY の "ItemSearch" … 空文字を返す入力欄を返す(素の名前の絞り込みを通さない)
local function mini_addons_is_match_or(text, keyword_list)
    if text == nil then
        return false
    end
    for _, word in ipairs(keyword_list) do
        -- 検索語は文字どおりに探す(パターン扱いだと「(」「%」でエラー、「-」「.」で誤ヒットする)
        if string.find(text, word, 1, true) then
            return true
        end
    end
    return false
end

-- 名前・接頭辞に加えて、イヤリングの職業・イコルのステータス・遺物の効果でも当てる
local function mini_addons_inv_item_matches(item_cls, search_keywords, relic_stats)
    local item_name = string.lower(dictionary.ReplaceDicIDInCompStr(item_cls.Name))
    local prefix_class_name = TryGetProp(item_cls, "LegendPrefix")
    if prefix_class_name ~= nil and prefix_class_name ~= "None" then
        local prefix_cls = GetClass("LegendSetItem", prefix_class_name)
        local prefix_name = string.lower(dictionary.ReplaceDicIDInCompStr(prefix_cls.Name))
        item_name = prefix_name .. " " .. item_name
    end
    if mini_addons_is_match_or(item_name, search_keywords) then
        return true
    end
    if TryGetProp(item_cls, "GroupName", "None") == "Earring" then
        local max_option_count = shared_item_earring.get_max_special_option_count(TryGetProp(item_cls, "UseLv", 1))
        for ii = 1, max_option_count do
            local option_name = "EarringSpecialOption_" .. ii
            local job = TryGetProp(item_cls, option_name, "None")
            if job ~= "None" then
                local job_cls = GetClass("Job", job)
                if job_cls ~= nil then
                    item_name = string.lower(dictionary.ReplaceDicIDInCompStr(job_cls.Name))
                    if mini_addons_is_match_or(item_name, search_keywords) then
                        return true
                    end
                end
            end
        end
    elseif TryGetProp(item_cls, "GroupName", "None") == "Icor" then
        local max_option = 5
        for iii = 1, max_option do
            local option_name = "RandomOption_" .. iii
            local option = TryGetProp(item_cls, option_name, "None")
            if option ~= "None" and option ~= nil then
                item_name = string.lower(dictionary.ReplaceDicIDInCompStr(ClMsg(option)))
                if mini_addons_is_match_or(item_name, search_keywords) then
                    return true
                end
            end
        end
    elseif string.sub(TryGetProp(item_cls, "ClassName", "None"), 1, 4) == "Arc_" and GET_ARCHEOLOGY_OPTION_INFO then
        -- 遺物は効果名で当てる。効果は接頭(Arc_Prefix)→ 接尾(Arc_Suffix)。
        -- 文字列は素のツールチップと同じ GET_ARCHEOLOGY_STAT_DESC から色の記法を
        -- 外したもの。今のクライアントは効果名を displayNameMsg から引き、種類の文言も付けるので
        -- ClMsg(tag) では画面の表示と食い違う(isLegacy は数値の書式にしか効かない)
        local metas = {}
        for _, prop in ipairs({"Arc_Prefix", "Arc_Suffix"}) do
            local meta = TryGetProp(item_cls, prop, "None")
            if meta ~= nil and meta ~= "" and meta ~= "None" then
                metas[#metas + 1] = meta
            end
        end
        local opts = #metas > 0 and GET_ARCHEOLOGY_OPTION_INFO(table.concat(metas, ",")) or {}
        local hit = false
        for _, opt in ipairs(opts) do
            local desc
            if GET_ARCHEOLOGY_STAT_DESC then
                desc = string.gsub(GET_ARCHEOLOGY_STAT_DESC(opt.tag, tonumber(opt.value) or 0) or "", "{[^}]*}", "")
            else
                desc = ClMsg(tostring(opt.tag))
            end
            item_name = string.lower(dictionary.ReplaceDicIDInCompStr(desc))
            if mini_addons_is_match_or(item_name, search_keywords) then
                hit = true
                break
            end
        end
        relic_stats.checked = relic_stats.checked + 1
        if #opts == 0 then
            relic_stats.no_opts = relic_stats.no_opts + 1
        end
        if hit then
            relic_stats.hit = relic_stats.hit + 1
        end
        return hit
    end
    return false
end

function Mini_addons_INVENTORY_TOTAL_LIST_GET(frame, set_pos, is_ignore_lift_icon, inven_type_str)
    local origin = g.FUNCS["INVENTORY_TOTAL_LIST_GET"]
    if not origin then
        return
    end
    local cap = ""
    if g.settings.icor_status_search ~= 0 then
        local inv_frame = ui.GetFrame("inventory")
        local search_skin = inv_frame and GET_CHILD_RECURSIVELY(inv_frame, "searchSkin")
        local edit = search_skin and GET_CHILD_RECURSIVELY(search_skin, "ItemSearch")
        if edit then
            AUTO_CAST(edit)
            cap = edit:GetText()
        end
    end
    if cap == "" then
        return origin(frame, set_pos, is_ignore_lift_icon, inven_type_str)
    end

    local search_keywords = {}
    for word in string.gmatch(string.lower(cap), "%S+") do
        table.insert(search_keywords, word)
    end
    -- 遺物の効果検索の件数(1 回の組み立てで 1 行だけログに出す)
    local relic_stats = {checked = 0, no_opts = 0, hit = 0}
    local total_count, hit_count = 0, 0

    local saved_get_list = session.GetInvItemSortedList
    local saved_get_child = GET_CHILD_RECURSIVELY
    local function filtered_list()
        local sorted_list = saved_get_list()
        local items = {}
        for i = 0, sorted_list:size() - 1 do
            local inv_item = sorted_list:at(i)
            if inv_item ~= nil then
                total_count = total_count + 1
                local item_cls = GetIES(inv_item:GetObject())
                if item_cls.MarketCategory ~= "None" and
                    mini_addons_inv_item_matches(item_cls, search_keywords, relic_stats) then
                    items[#items + 1] = inv_item
                end
            end
        end
        hit_count = #items
        return {
            size = function()
                return #items
            end,
            at = function(_, index)
                return items[index + 1]
            end
        }
    end
    local empty_edit = {
        GetText = function()
            return ""
        end
    }

    -- 空白だけのときは語が無いので、一覧は絞らず全部を出す
    if #search_keywords > 0 then
        pcall(function()
            session.GetInvItemSortedList = filtered_list
        end)
        if not rawequal(session.GetInvItemSortedList, filtered_list) then
            core_g.vlog("{#FF6347}mini_addons: session.GetInvItemSortedList を差し替えられないので、素の検索にする{/}")
            return origin(frame, set_pos, is_ignore_lift_icon, inven_type_str)
        end
    end
    GET_CHILD_RECURSIVELY = function(parent, name, ...)
        if name == "ItemSearch" then
            return empty_edit
        end
        return saved_get_child(parent, name, ...)
    end
    local ok, err = pcall(origin, frame, set_pos, is_ignore_lift_icon, inven_type_str)
    GET_CHILD_RECURSIVELY = saved_get_child
    if #search_keywords > 0 then
        session.GetInvItemSortedList = saved_get_list
    end
    if not ok then
        core_g.vlog("{#FF6347}mini_addons: インベントリの検索に失敗: %s{/}", tostring(err))
        return
    end
    core_g.vlog("mini_addons: インベントリ検索 keywords=%s 当たり=%d / %d", cap, hit_count, total_count)
    if relic_stats.checked > 0 then
        core_g.vlog("mini_addons: 遺物の効果検索 keywords=%s 照合=%d 当たり=%d 効果なし=%d", cap, relic_stats.checked,
            relic_stats.hit, relic_stats.no_opts)
    end
end
