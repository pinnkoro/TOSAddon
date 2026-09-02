-- 装備錬成を自動化
function Mini_addons_COMMON_EQUIP_UPGRADE_OPEN(my_frame, my_msg)
    local frame = ui.GetFrame("common_equip_upgrade")
    if g.settings.status_upgrade == 0 then
        local target_status_text = GET_CHILD_RECURSIVELY(frame, "target_status_text")
        if target_status_text ~= nil then
            AUTO_CAST(target_status_text)
            target_status_text:ShowWindow(0)
        end
        local target_status_edit = GET_CHILD_RECURSIVELY(frame, "target_status_edit")
        if target_status_edit ~= nil then
            AUTO_CAST(target_status_edit)
            target_status_edit:ShowWindow(0)
        end
    else
        local target_status_text = frame:CreateOrGetControl("richtext", "target_status_text", 20, 650, 80, 30)
        AUTO_CAST(target_status_text)
        target_status_text:SetFontName("white_18_ol")
        target_status_text:SetText("Target Status")
        target_status_text:ShowWindow(1)
        if g.settings.target_status_value == nil then
            g.settings.target_status_value = 20
            Mini_addons_save_settings()
        end
        local target_status_edit = frame:CreateOrGetControl("edit", "target_status_edit", 30, 680, 80, 25)
        AUTO_CAST(target_status_edit)
        target_status_edit:SetTextAlign("center", "center")
        target_status_edit:SetFontName("white_18_ol")
        target_status_edit:SetSkinName("test_weight_skin")
        target_status_edit:SetText(g.settings.target_status_value)
        target_status_edit:SetTextTooltip(g.lang == "Japanese" and "1~20の間で設定" or "Set between 1~20")
        target_status_edit:SetEventScript(ui.ENTERKEY, "Mini_addons_EQUIP_UPGRADE_SET")
        target_status_edit:ShowWindow(1)
    end
end

function Mini_addons_EQUIP_UPGRADE_SET(frame, ctrl, str, num)
    if not tonumber(ctrl:GetText()) then
        ui.SysMsg("Invalid value")
        return
    elseif tonumber(ctrl:GetText()) > 20 or tonumber(ctrl:GetText()) < 1 then
        ui.SysMsg("Invalid value")
        return
    else
        g.settings.target_status_value = tonumber(ctrl:GetText())
        ui.SysMsg("Set target value")
        Mini_addons_save_settings()
    end
end

-- 自動継続を打ち切る条件。**目標ランクに届くこと以外にも終わり方が要る。**
-- 素材が尽きるとランクは上がらないが、こちらは 2 秒おきに UPGRADE_EQUIP を送り続ける。
-- ReserveScript には取り消しが無いので、止まるのは窓を閉じたときだけになってしまう。
local EQUIP_UPGRADE_STALL_LIMIT = 5   -- ランクが変わらない回数（2 秒間隔なので 10 秒）
local EQUIP_UPGRADE_TRY_LIMIT = 200   -- 念のための総回数の上限

local function equip_upgrade_stop(reason_jp, reason_en)
    g.equip_upgrade_run = nil
    if reason_jp then
        ui.SysMsg(g.lang == "Japanese" and reason_jp or reason_en)
    end
end

function Mini_addons_COMMON_EQUIP_UPGRADE_PROGRESS(parent, ctrl, str, nym)
    if g.settings.status_upgrade == 0 then
        g.FUNCS["COMMON_EQUIP_UPGRADE_PROGRESS"](parent, ctrl, str, nym)
        return
    end
    local frame = parent:GetTopParentFrame()
    local slot = GET_CHILD_RECURSIVELY(frame, "slot")
    local guid = slot:GetUserValue("SET_ID")
    pc.ReqExecuteTx_Item("UPGRADE_EQUIP", guid)
    local inv_item = session.GetInvItemByGuid(guid)
    if inv_item == nil then
        equip_upgrade_stop()
        return
    end
    local item_obj = GetIES(inv_item:GetObject())
    COMMON_EQUIP_UPGRADE_MAT_NUM_SET(frame, item_obj)
    local cur_rank = tonumber(TryGetProp(item_obj, "UpgradeRank", 0)) or 0

    -- 別のアイテムに差し替えられたら数え直す。
    local run = g.equip_upgrade_run
    if run == nil or run.guid ~= guid then
        run = {guid = guid, rank = cur_rank, stall = 0, tries = 0}
        g.equip_upgrade_run = run
    end
    run.tries = run.tries + 1
    if cur_rank > run.rank then
        run.stall = 0
        run.rank = cur_rank
    else
        run.stall = run.stall + 1
    end

    if cur_rank >= g.settings.target_status_value then
        core_g.vlog("mini_addons: 装備錬成が目標に到達 rank=%d target=%d 試行 %d 回",
                    cur_rank, g.settings.target_status_value, run.tries)
        equip_upgrade_stop()
        return
    end
    if run.stall >= EQUIP_UPGRADE_STALL_LIMIT then
        core_g.vlog("mini_addons: 装備錬成が進まないので打ち切る rank=%d target=%d 連続 %d 回",
                    cur_rank, g.settings.target_status_value, run.stall)
        equip_upgrade_stop("錬成が進まないので自動継続を止めました（素材切れ？）",
                           "Stopped auto-upgrading: the rank is not going up (out of materials?)")
        return
    end
    if run.tries >= EQUIP_UPGRADE_TRY_LIMIT then
        core_g.vlog("mini_addons: 装備錬成の試行回数が上限に達した rank=%d target=%d 試行 %d 回",
                    cur_rank, g.settings.target_status_value, run.tries)
        equip_upgrade_stop("錬成の自動継続が長すぎるので止めました",
                           "Stopped auto-upgrading: too many attempts")
        return
    end
    ReserveScript("Mini_addons_COMMON_EQUIP_UPGRADE_PROGRESS_CONTINUE()", 2.0)
end

function Mini_addons_COMMON_EQUIP_UPGRADE_PROGRESS_CONTINUE()
    local parent = ui.GetFrame("common_equip_upgrade")
    if parent == nil or parent:IsVisible() == 0 then
        -- 窓を閉じたら終わり。次に開いたときは 1 から数え直す。
        equip_upgrade_stop()
        return
    end
    Mini_addons_COMMON_EQUIP_UPGRADE_PROGRESS(parent, nil, nil, nil)
end
