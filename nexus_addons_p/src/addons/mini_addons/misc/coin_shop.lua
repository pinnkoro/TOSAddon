-- コインショップの数値を拡張
function Mini_addons_EARTHTOWERSHOP_CHANGECOUNT_NUM_CHANGE(ctrlset, change)
    if g.settings.coin_count ~= 1 then
        if g.FUNCS["EARTHTOWERSHOP_CHANGECOUNT_NUM_CHANGE"] then
            g.FUNCS["EARTHTOWERSHOP_CHANGECOUNT_NUM_CHANGE"](ctrlset, change)
        end
        return
    end
    local recipe_cls = GetClass("ItemTradeShop", ctrlset:GetName())
    local edit_item_count = GET_CHILD_RECURSIVELY(ctrlset, "itemcount")
    local count_text = tonumber(edit_item_count:GetText()) or 0
    count_text = count_text + change
    local target_acc = TryGetProp(recipe_cls, "TargetAccountProperty", "None")
    local max_target_acc = TryGetProp(recipe_cls, "MaxTargetAccountProperty", 99999)
    if target_acc ~= "None" then
        local now = TryGetProp(GetMyAccountObj(), target_acc, 0)
        if now + count_text > max_target_acc then
            count_text = math.max(0, max_target_acc - now)
        end
    end
    if count_text < 0 then
        count_text = 0
    elseif count_text > 99999 then
        count_text = 99999
    end
    if recipe_cls.NeedProperty ~= "None" then
        local s_obj = GetSessionObject(GetMyPCObject(), "ssn_shop")
        local s_count = TryGetProp(s_obj, recipe_cls.NeedProperty)
        if s_count < count_text then
            count_text = s_count
        end
    end
    if recipe_cls.AccountNeedProperty ~= "None" then
        local a_obj = GetMyAccountObj()
        local s_count = TryGetProp(a_obj, recipe_cls.AccountNeedProperty)
        local frame = ui.GetFrame("earthtowershop")
        local shop_type = frame:GetUserValue("SHOP_TYPE")
        if IS_OVERBUY_ITEM(shop_type, recipe_cls, a_obj) == true then
            s_count = count_text
            if IS_EXCEED_OVERBUY_COUNT(shop_type, a_obj, recipe_cls, 1) == true then
                s_count = 0
            end
            local max_over_buy = TryGetProp(recipe_cls, "MaxOverBuyCount", 100)
            local current_over_buy = TryGetProp(a_obj, TryGetProp(recipe_cls, "OverBuyProperty", "None"), 0)
            count_text = max_over_buy - current_over_buy
        end
        if s_count < count_text then
            count_text = s_count
        end
    end
    edit_item_count:SetText(count_text)
    return count_text
end
