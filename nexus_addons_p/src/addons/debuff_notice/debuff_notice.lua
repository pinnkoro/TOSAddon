-- debuff_notice ここから
function debuff_notice_on_init()
    g.debuff_notice = {
        slot_table = {},
        highlander = false
    }
    local map_name = session.GetMapName()
    if map_name == "c_highlander" then
        g.debuff_notice.highlander = true
    end
    if type(_G["COMMON_BUFF_MSG_OLD"]) == "function" then
        g.setup_hook_and_event(g.addon, "COMMON_BUFF_MSG_OLD", "Debuff_notice_COMMON_BUFF_MSG", true)
    else
        g.setup_hook_and_event(g.addon, "COMMON_BUFF_MSG", "Debuff_notice_COMMON_BUFF_MSG", true)
    end
    if g.get_map_type() ~= "City" or g.debuff_notice.highlander then
        Debuff_notice_frame_init()
    end
end

function Debuff_notice_COMMON_BUFF_MSG(my_frame, my_msg)
    if g.settings.debuff_notice.use == 0 then
        return
    end
    if g.get_map_type() == "City" and not g.debuff_notice.highlander then
        return
    end
    local frame, msg, buff_id, handle, buff_ui, buff_index = g.get_event_args(my_msg)
    local debuff_notice = ui.GetFrame(addon_name_lower .. "debuff_notice")
    if not debuff_notice then
        return
    end
    if msg == "CLEAR" then
        if g.debuff_notice.slot_table[handle] then
            g.debuff_notice.slot_table[handle] = nil
            Debuff_notice_frame_redraw(debuff_notice, handle)
        end
        return
    end
    if msg == "SET" then
        return
    end
    buff_id = tonumber(buff_id)
    local buff_cls = GetClassByType('Buff', buff_id)
    if not buff_cls or (buff_cls.Group1 ~= "Debuff" and buff_cls.Group1 ~= "Deuff") or buff_cls.ShowIcon == "FALSE" then
        return
    end
    local image_name = GET_BUFF_ICON_NAME(buff_cls)
    if image_name == "icon_None" then
        return
    end
    if msg ~= 'REMOVE' then
        local buff = info.GetBuff(handle, buff_id, buff_index)
        if not buff or buff:GetHandle() ~= session.GetMyHandle() then
            return
        end
    end
    local actor = world.GetActor(handle)
    if not actor then
        return
    end
    local mon_cls = GetClassByType("Monster", actor:GetType())
    if TryGetProp(mon_cls, "MonRank", "None") ~= "Boss" and not g.debuff_notice.highlander then
        return
    end
    if not g.debuff_notice.slot_table[handle] then
        g.debuff_notice.slot_table[handle] = {}
    end
    if msg == 'ADD' or msg == "UPDATE" then
        g.debuff_notice.slot_table[handle][buff_id] = {
            buff_index = buff_index,
            image_name = image_name
        }
    elseif msg == 'REMOVE' then
        g.debuff_notice.slot_table[handle][buff_id] = nil
    end
    Debuff_notice_frame_redraw(debuff_notice, handle)
end

function Debuff_notice_frame_init()
    local frame_name = addon_name_lower .. "debuff_notice"
    local debuff_notice = ui.CreateNewFrame("notice_on_pc", frame_name, 0, 0, 0, 0)
    debuff_notice:SetSkinName("None")
    debuff_notice:SetTitleBarSkin("None")
    debuff_notice:Resize(0, 0)
    debuff_notice:SetPos(Debuff_notice_pos())
    local debuff_slotset = debuff_notice:CreateOrGetControl("slotset", "debuff_slotset", 0, 0, 415, 50)
    AUTO_CAST(debuff_slotset)
    debuff_slotset:SetColRow(8, 1)
    debuff_slotset:SetSlotSize(50, 50)
    debuff_slotset:SetSpc(0, 0)
    debuff_slotset:EnablePop(0)
    debuff_slotset:EnableDrag(0)
    debuff_slotset:EnableDrop(0)
    debuff_slotset:CreateSlots()
    debuff_notice:ShowWindow(1)
    debuff_notice:RunUpdateScript("Debuff_notice_update_and_cleanup", 0.1)
    return debuff_notice
end

function Debuff_notice_frame_redraw(debuff_notice, handle)
    local debuff_slotset = GET_CHILD(debuff_notice, "debuff_slotset")
    AUTO_CAST(debuff_slotset)
    debuff_notice:SetUserValue("HANDLE", handle)
    local buffs_to_display = {}
    if g.debuff_notice.slot_table[handle] then
        for buff_id, buff_data in pairs(g.debuff_notice.slot_table[handle]) do
            table.insert(buffs_to_display, {
                id = buff_id,
                index = buff_data.buff_index,
                image = buff_data.image_name
            })
        end
    end
    table.sort(buffs_to_display, function(a, b)
        return tonumber(a.index) < tonumber(b.index)
    end)
    if #buffs_to_display > 0 then
        debuff_notice:Resize(#buffs_to_display * 50, 50)
    else
        debuff_notice:Resize(0, 0)
    end
    for i = 1, debuff_slotset:GetSlotCount() do
        local slot = GET_CHILD(debuff_slotset, "slot" .. i)
        AUTO_CAST(slot)
        local buff_data = buffs_to_display[i]
        if buff_data then
            local icon = slot:GetIcon()
            if not icon then
                icon = CreateIcon(slot)
            end
            AUTO_CAST(icon)
            icon:Set(buff_data.image, 'BUFF', buff_data.id, 0)
            icon:SetTooltipType('buff')
            icon:SetTooltipArg(handle, buff_data.id, buff_data.index)
            icon:SetUserValue("BuffIndex", buff_data.index)
            slot:CreateOrGetControl('richtext', "time_text", 10, 35, 20, 20)
            slot:CreateOrGetControl('richtext', "count_text", 5, 0, 40, 35)
        else
            slot:ClearIcon()
        end
    end
end

function Debuff_notice_update_and_cleanup(debuff_notice)
    local handle = debuff_notice:GetUserIValue("HANDLE")
    if not handle or handle == 0 then
        debuff_notice:Resize(0, 0)
        return 1
    end
    local actor = world.GetActor(handle)
    if not actor then
        debuff_notice:Resize(0, 0)
        return 1
    end
    local debuff_slotset = GET_CHILD(debuff_notice, "debuff_slotset")
    local need_redraw = false
    for i = 1, debuff_slotset:GetSlotCount() do
        local slot = GET_CHILD(debuff_slotset, "slot" .. i)
        local icon = slot:GetIcon()
        if icon then
            local icon_info = icon:GetInfo()
            local buff_id = icon_info.type
            local buff_index = icon:GetUserIValue("BuffIndex")
            local buff = info.GetBuff(handle, buff_id, buff_index)
            if buff then
                local time_text = GET_CHILD(slot, "time_text")
                local count_text = GET_CHILD(slot, "count_text")
                time_text:SetText(buff.time > 0 and "{ol}{s15}{#FFFF00}" .. string.format("%.1fs", buff.time / 1000) or
                                      "")
                count_text:SetText(buff.over > 0 and "{ol}{s35}{#FFFF00}" .. tostring(buff.over) or "")
            else
                if g.debuff_notice.slot_table[handle] and g.debuff_notice.slot_table[handle][buff_id] then
                    g.debuff_notice.slot_table[handle][buff_id] = nil
                    need_redraw = true
                end
            end
        end
    end
    if need_redraw then
        Debuff_notice_frame_redraw(debuff_notice, handle)
    end
    return 1
end
-- 表示位置。x / y が 0 のまま(一度も動かしていない)なら従来どおり targetbuff の右下に置く
function Debuff_notice_pos()
    local x = g.settings.debuff_notice.x or 0
    local y = g.settings.debuff_notice.y or 0
    if x ~= 0 or y ~= 0 then
        return x, y
    end
    local targetbuff = ui.GetFrame("targetbuff")
    return targetbuff:GetX() + 100, targetbuff:GetY() + targetbuff:GetHeight() + 50
end

-- 位置合わせ用の窓を出す(アドオン一覧の歯車から)。
-- 本体はデバフが無いと大きさ 0 で掴めず、出るのもボス戦の最中だけなので、
-- 本体は動かさずに同じ大きさ(8 枠 = 400x50)の別の窓を置き、閉じるときに位置を移す。
function Debuff_notice_move_frame()
    if not g.debuff_notice then
        return
    end
    local frame_name = addon_name_lower .. "debuff_notice_move"
    if ui.GetFrame(frame_name) then
        return
    end
    local ja = g.lang == "Japanese"
    local move = ui.CreateNewFrame("notice_on_pc", frame_name, 0, 0, 0, 0)
    AUTO_CAST(move)
    move:SetSkinName("bg")
    move:SetTitleBarSkin("None")
    move:Resize(400, 50)
    move:SetPos(Debuff_notice_pos())
    g.block_click_through(move)
    move:EnableMove(1)
    move:SetLayerLevel(999)
    move:SetEventScript(ui.LBUTTONUP, "Debuff_notice_move_save")
    move:SetEventScript(ui.RBUTTONUP, "Debuff_notice_move_close")
    local text = move:CreateOrGetControl("richtext", "text", 10, 6, 300, 40)
    AUTO_CAST(text)
    text:EnableHitTest(0)
    text:SetText(ja and "{ol}{s14}Debuff Notice の表示位置{nl}ドラッグで移動・右クリックか ESC で閉じる" or
                     "{ol}{s14}Debuff Notice position{nl}Drag to move, right-click or ESC to close")
    local reset = move:CreateOrGetControl("button", "reset", 0, 0, 70, 30)
    AUTO_CAST(reset)
    reset:SetSkinName("test_gray_button")
    reset:SetGravity(ui.RIGHT, ui.CENTER_VERT)
    reset:SetMargin(0, 0, 8, 0)
    reset:SetText(ja and "{ol}{s14}初期位置" or "{ol}{s14}Reset")
    reset:SetEventScript(ui.LBUTTONUP, "Debuff_notice_move_reset")
    move:ShowWindow(1)
    g.esc_register_destroy(frame_name)
    g.vlog("debuff_notice: 位置合わせを開いた x=%s y=%s", tostring(move:GetX()), tostring(move:GetY()))
end

-- 本体を窓と同じ位置へ移す。LBUTTONUP は動かさないクリックでも来るので、変わっていなければ保存しない
function Debuff_notice_move_save(move)
    local x, y = move:GetX(), move:GetY()
    local debuff_notice = ui.GetFrame(addon_name_lower .. "debuff_notice")
    if debuff_notice then
        debuff_notice:SetPos(x, y)
    end
    if g.settings.debuff_notice.x == x and g.settings.debuff_notice.y == y then
        return
    end
    g.settings.debuff_notice.x = x
    g.settings.debuff_notice.y = y
    _nexus_addons_p_save_settings()
    g.vlog("debuff_notice: 位置を保存 x=%s y=%s", tostring(x), tostring(y))
end

function Debuff_notice_move_close()
    ui.DestroyFrame(addon_name_lower .. "debuff_notice_move")
end

-- 0 / 0 に戻すと Debuff_notice_pos が targetbuff 基準の位置を返す
function Debuff_notice_move_reset(frame, ctrl)
    g.settings.debuff_notice.x = 0
    g.settings.debuff_notice.y = 0
    _nexus_addons_p_save_settings()
    local x, y = Debuff_notice_pos()
    frame:SetPos(x, y)
    local debuff_notice = ui.GetFrame(addon_name_lower .. "debuff_notice")
    if debuff_notice then
        debuff_notice:SetPos(x, y)
    end
    g.vlog("debuff_notice: 位置を初期化 x=%s y=%s", tostring(x), tostring(y))
end
-- debuff_notice ここまで

