-- RPチャージを補完
function Mini_addons_rp_check()
    if g.settings.rp_charge == 0 then
        return
    end
    local openingameshopbtn = ui.GetFrame("openingameshopbtn")
    local open_openingameshopbtn = GET_CHILD(openingameshopbtn, "open_openingameshopbtn")
    AUTO_CAST(open_openingameshopbtn)
    open_openingameshopbtn:RunUpdateScript("Mini_addons_rp_check_", 0.1)
end

function Mini_addons_rp_check_(frame)
    local indunenter = ui.GetFrame("indunenter")
    if not indunenter then
        return 1
    end
    if indunenter:IsVisible() == 0 then
        return 1
    end
    local pc = GetMyPCObject()
    local cur_rp, max_rp = shared_item_relic.get_rp(pc)
    if cur_rp == max_rp then
        return 1
    end
    local item_count = 0
    local item_names = {"misc_Ectonite", "misc_Ectonite_Care"}
    for _, item_name in ipairs(item_names) do
        local item = session.GetInvItemByName(item_name)
        if item and item.count > 0 then
            item_count = item_count + item.count
        end
    end
    if item_count == 0 then
        ui.SysMsg(g.lang == "Japanese" and
                      "エクトナイトを持っていません{nl}自動補充監視を終了します" or
                      "You don't have an Ectonite{nl}Automatic replenishment monitoring will be terminated")
        return 0
    end
    session.ResetItemList()
    for _, item_name in ipairs(item_names) do
        local item = session.GetInvItemByName(item_name)
        if item and not item.isLockState then
            session.AddItemID(item:GetIESID(), item.count)
        end
    end
    local result_list = session.GetItemIDList()
    item.DialogTransaction("RELIC_CHARGE_RP", result_list)
    frame:StopUpdateScript("Mini_addons_rp_check_")
    frame:RunUpdateScript("Mini_addons_rp_check_end", 0.1)
    return 0
end

function Mini_addons_rp_check_end(frame)
    local pc = GetMyPCObject()
    local cur_rp, max_rp = shared_item_relic.get_rp(pc)
    if cur_rp == max_rp then
        ui.SysMsg(g.lang == "Japanese" and "レリック自動補充完了" or "Relic auto-replenishment complete")
    elseif cur_rp < max_rp then
        ui.SysMsg(g.lang == "Japanese" and "レリック自動補充完了出来ませんでした" or
                      "Relic auto-replenishment failed")
    end
end
