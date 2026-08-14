-- ワールドマップにトークンワープのクールダウンを表示
function Mini_addons_OPEN_WORLDMAP2_MINIMAP(my_frame, my_msg)
    local worldmap2_minimap = ui.GetFrame("worldmap2_minimap")
    Mini_addons_TOKEN_WARP_COOLDOWN(worldmap2_minimap)
    worldmap2_minimap:RunUpdateScript("Mini_addons_TOKEN_WARP_COOLDOWN", 1.0)
end

function Mini_addons_TOKEN_WARP_COOLDOWN(worldmap2_minimap)
    local minimap_token_btn = GET_CHILD_RECURSIVELY(worldmap2_minimap, "minimap_token_btn")
    AUTO_CAST(minimap_token_btn)
    local is_token_state = session.loginInfo.IsPremiumState(ITEM_TOKEN)
    local image_name = ""
    local cd = GET_TOKEN_WARP_COOLDOWN()
    if is_token_state == true and cd == 0 then
        image_name = "{img worldmap2_token_gold 38 38} {@st101lightbrown_16}"
    else
        image_name = "{img worldmap2_token_gray 38 38} {@st101lightbrown_16}"
    end
    minimap_token_btn:SetText(image_name .. ScpArgMsg("TokenWarp"))
    local cdtext = worldmap2_minimap:CreateOrGetControl("richtext", "cdtext", 50, 820)
    AUTO_CAST(cdtext)
    local minutes = math.floor(cd / 60)
    local seconds = cd % 60
    local cdtimer = string.format("%d:%02d", minutes, seconds)
    cdtext:SetText("{ol}{#FFFFFF}TokenWarp CD: " .. cdtimer)
    return 1
end
