-- PTバフの表示非表示切り替え
-- 一覧に出すバフを列挙する。**表示と一括操作で必ずこれを共有すること。**
-- 条件(Group1 / ShowIcon / TeamLevel 除外 / 検索語 / アイコン無しの除外)が 2 箇所に
-- 分かれると、「見えているものと一括操作の対象」が食い違って、出ていないバフまで
-- 勝手に切り替わる。
function Mini_addons_buff_list_each(filter_text, func)
    local cls_list, count = GetClassList("Buff")
    for i = 0, count - 1 do
        local buff_cls = GetClassByIndexFromList(cls_list, i)
        if buff_cls and buff_cls.Group1 == "Buff" and IS_PARTY_INFO_SHOWICON(buff_cls.ShowIcon) == true and
            buff_cls.ClassName ~= "TeamLevel" then
            local buff_name = dictionary.ReplaceDicIDInCompStr(buff_cls.Name)
            if filter_text == "" or string.find(buff_name, filter_text) then
                local image_name = GET_BUFF_ICON_NAME(buff_cls)
                if buff_name ~= "None" and image_name ~= "icon_None" then
                    func(i, buff_cls, buff_name, image_name)
                end
            end
        end
    end
end

-- いま検索欄に入っている絞り込み。一括操作の対象を「見えている分」に合わせるために使う。
function Mini_addons_buff_list_filter_text(buff_list)
    local search_edit = GET_CHILD_RECURSIVELY(buff_list, "search_edit")
    return search_edit and search_edit:GetText() or ""
end

-- 一覧に出ているバフをまとめて ON / OFF にする(num: 1=ON, 0=OFF)。
function Mini_addons_buff_list_set_all(frame, ctrl, str, num)
    local value = num == 1 and 1 or 0
    local filter_text = Mini_addons_buff_list_filter_text(frame)
    local changed = 0
    g.buffs = g.buffs or {}
    Mini_addons_buff_list_each(filter_text, function(_, buff_cls)
        local key = tostring(buff_cls.ClassID)
        -- 未設定は「表示する(1)」扱い。既定値と同じ値を入れても変更にはしない。
        if (g.buffs[key] or 1) ~= value then
            g.buffs[key] = value
            changed = changed + 1
        end
    end)
    Mini_addons_save_buffs()
    core_g.vlog("mini_addons: バフ一覧を一括変更 value=%d 変更 %d 件 filter=%s", value, changed, tostring(filter_text))
    ui.SysMsg(g.lang == "Japanese" and
                  string.format("{ol}{#00BFFF}[Nexus Addons P] バフ表示を %d 件 %s にしました", changed,
            value == 1 and "ON" or "OFF") or
                  string.format("{ol}{#00BFFF}[Nexus Addons P] Turned %s %d buff(s)", value == 1 and "ON" or "OFF",
            changed))
    Mini_addons_buff_list_open(frame, ctrl, filter_text, num)
end

-- いまのチェック状態を控える。控えは 1 つだけで、押すたびに上書きする。
function Mini_addons_buff_list_backup(frame, ctrl, str, num)
    g.buffs = g.buffs or {}
    -- 控えも .lua。json のままにすると、復元のたびに 5 秒の json.decode を通る
    -- (中身は buffs と同じ、バフ ID をキーにした平坦なテーブルなので条件が同じ)。
    g.save_lua(g.buffs_backup_path, g.buffs)
    -- 新しい控えを .lua で書けたら、旧 json の控えは消す。Mini_addons_buff_list_restore は
    -- .lua が読めなかったときだけ json へ落ちるので、残しておくと「今日取った控え」の
    -- つもりで移行前の控えが戻ってくる経路が恒久的に残る(load_buffs の旧 json と同じ話)。
    local written = io.open(g.buffs_backup_path, "rb")
    if written then
        written:close()
        os.remove(g.buffs_backup_json_path)
    end
    core_g.vlog("mini_addons: バフ一覧をバックアップした (%s)", tostring(g.buffs_backup_path))
    ui.SysMsg(g.lang == "Japanese" and "{ol}{#00BFFF}[Nexus Addons P] バフ一覧をバックアップしました" or
                  "{ol}{#00BFFF}[Nexus Addons P] Backed up the buff list")
end

-- 控えたチェック状態へ戻す。控えが無いときは何もしない(黙って空で上書きしないこと)。
function Mini_addons_buff_list_restore(frame, ctrl, str, num)
    -- .lua を先に見て、無ければ旧 json の控えへ落ちる(移行前に取った控えを失わないため)。
    local backup = g.load_lua(g.buffs_backup_path) or g.load_json(g.buffs_backup_json_path)
    if type(backup) ~= "table" then
        core_g.vlog("mini_addons: バフ一覧の控えが無い (%s)", tostring(g.buffs_backup_path))
        ui.SysMsg(g.lang == "Japanese" and "{ol}{#FF6347}[Nexus Addons P] バフ一覧のバックアップがありません" or
                      "{ol}{#FF6347}[Nexus Addons P] No buff list backup")
        return
    end
    g.buffs = backup
    Mini_addons_save_buffs()
    core_g.vlog("mini_addons: バフ一覧を復元した")
    ui.SysMsg(g.lang == "Japanese" and "{ol}{#00BFFF}[Nexus Addons P] バフ一覧を復元しました" or
                  "{ol}{#00BFFF}[Nexus Addons P] Restored the buff list")
    Mini_addons_buff_list_open(frame, ctrl, Mini_addons_buff_list_filter_text(frame), num)
end

function Mini_addons_buff_list_open(frame, ctrl, ctrl_text, num)
    local buff_list = ui.GetFrame(addon_name_lower .. "buff_list")
    if not buff_list then
        buff_list = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "buff_list", 0, 0, 10, 10)
        AUTO_CAST(buff_list)
        buff_list:SetSkinName("test_frame_low")
        buff_list:Resize(500, 1005)
        buff_list:SetPos(20, 30)
        buff_list:SetLayerLevel(999)
        local title_text = buff_list:CreateOrGetControl('richtext', 'title_text', 15, 15, 10, 30)
        AUTO_CAST(title_text)
        title_text:SetText("{#000000}{s20}Buff List")
        local search_edit = buff_list:CreateOrGetControl("edit", "search_edit", title_text:GetWidth() + 30, 10, 305, 38)
        AUTO_CAST(search_edit)
        search_edit:SetFontName("white_18_ol")
        search_edit:SetTextAlign("left", "center")
        search_edit:SetSkinName("inventory_serch")
        search_edit:SetEventScript(ui.ENTERKEY, "Mini_addons_buff_list_search")
        local search_btn = search_edit:CreateOrGetControl("button", "search_btn", 0, 0, 40, 38)
        AUTO_CAST(search_btn)
        search_btn:SetImage("inven_s")
        search_btn:SetGravity(ui.RIGHT, ui.TOP)
        search_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_buff_list_search")
        local close_button = buff_list:CreateOrGetControl('button', 'close_button', 0, 0, 20, 20)
        AUTO_CAST(close_button)
        close_button:SetImage("testclose_button")
        close_button:SetGravity(ui.RIGHT, ui.TOP)
        close_button:SetEventScript(ui.LBUTTONUP, "Mini_addons_buff_list_frame_close")
        -- 一括操作のボタン列。文言はまとめ版の設定バックアップと揃える(バックアップ/復元)。
        local ja = g.lang == "Japanese"
        local buttons = {{
            name = "all_on_btn",
            text = ja and "{ol}全部ON" or "{ol}All ON",
            tooltip = ja and "{ol}いま一覧に出ているバフを全部 ON にします{nl}検索で絞り込んでいるときは、その分だけが対象です" or
                "{ol}Turn ON every buff currently listed{nl}Only the filtered ones while searching",
            script = "Mini_addons_buff_list_set_all",
            arg = 1
        }, {
            name = "all_off_btn",
            text = ja and "{ol}全部OFF" or "{ol}All OFF",
            tooltip = ja and "{ol}いま一覧に出ているバフを全部 OFF にします{nl}検索で絞り込んでいるときは、その分だけが対象です" or
                "{ol}Turn OFF every buff currently listed{nl}Only the filtered ones while searching",
            script = "Mini_addons_buff_list_set_all",
            arg = 0
        }, {
            name = "backup_btn",
            text = ja and "{ol}バックアップ" or "{ol}Backup",
            tooltip = ja and "{ol}いまのチェック状態を控えます{nl}控えは 1 つだけで、押すたびに上書きします" or
                "{ol}Save the current checks{nl}Only one copy is kept; each press overwrites it",
            script = "Mini_addons_buff_list_backup",
            arg = 0
        }, {
            name = "restore_btn",
            text = ja and "{ol}復元" or "{ol}Restore",
            tooltip = ja and "{ol}控えたチェック状態に戻します{nl}いまの状態は上書きされます" or
                "{ol}Restore the saved checks{nl}The current state is overwritten",
            script = "Mini_addons_buff_list_restore",
            arg = 0
        }}
        local btn_x = 10
        for _, spec in ipairs(buttons) do
            local btn = buff_list:CreateOrGetControl("button", spec.name, btn_x, 50, 115, 30)
            AUTO_CAST(btn)
            btn:SetText(spec.text)
            btn:SetTextTooltip(spec.tooltip)
            btn:SetEventScript(ui.LBUTTONUP, spec.script)
            btn:SetEventScriptArgNumber(ui.LBUTTONUP, spec.arg)
            btn_x = btn_x + 120
        end
    end
    -- ボタン列のぶん下げる
    local buff_list_gb = buff_list:CreateOrGetControl("groupbox", "buff_list_gb", 10, 85, 480,
        buff_list:GetHeight() - 95)
    AUTO_CAST(buff_list_gb)
    buff_list_gb:SetSkinName("bg")
    buff_list_gb:RemoveAllChild()
    local y = 0
    Mini_addons_buff_list_each(ctrl_text or "", function(i, buff_cls, buff_name, image_name)
        local buff_id = buff_cls.ClassID
        local buff_slot = buff_list_gb:CreateOrGetControl('slot', 'buffslot' .. i, 10, y + 5, 30, 30)
        AUTO_CAST(buff_slot)
        SET_SLOT_IMG(buff_slot, image_name)
        local icon = CreateIcon(buff_slot)
        AUTO_CAST(icon)
        icon:SetTooltipType('buff')
        icon:SetTooltipArg(buff_name, buff_id, 0)
        local buffcheck = buff_list_gb:CreateOrGetControl("checkbox", "buffcheck" .. buff_id, 45, y + 5, 30, 30)
        AUTO_CAST(buffcheck)
        buffcheck:SetCheck(g.buffs[tostring(buff_id)] or 1)
        buffcheck:SetEventScript(ui.LBUTTONUP, "Mini_addons_buff_check")
        buffcheck:SetEventScriptArgNumber(ui.LBUTTONUP, buff_id)
        buffcheck:SetText("{ol}" .. buff_cls.Name)
        buffcheck:SetTextTooltip(g.lang == "Japanese" and "{ol}" .. buff_id .. "{nl}チェックするとパーティーバフ表示" or
                                     "{ol}" .. buff_id .. "{nl}Party buff display when checked")
        buffcheck:AdjustFontSizeByWidth(380)
        y = y + 35
    end)
    buff_list:ShowWindow(1)
    -- 設定画面の「パーティーバフ」から開くサブ画面なので、設定画面と同じく ESC で閉じられる
    -- ようにする。検索し直すとこの関数がもう一度呼ばれるが、esc_register は同じフレームの
    -- 古い登録を外してから積み直すので二重には積まれない。
    core_g.esc_register(addon_name_lower .. "buff_list", "Mini_addons_buff_list_ESCAPE_PRESSED")
end

-- ESC 用の入口。理由は Mini_addons_setting_ESCAPE_PRESSED と同じ
-- (esc_register は引数無しで呼ぶが、閉じる側はフレームを受け取る前提のため)。
function Mini_addons_buff_list_ESCAPE_PRESSED()
    local buff_list = ui.GetFrame(addon_name_lower .. "buff_list")
    if buff_list then
        Mini_addons_buff_list_frame_close(buff_list)
    end
end

function Mini_addons_buff_list_frame_close(buff_list)
    ui.DestroyFrame(buff_list:GetName())
end

function Mini_addons_buff_list_search(frame, ctrl, str, num)
    Mini_addons_buff_list_open(frame, ctrl, Mini_addons_buff_list_filter_text(frame), num)
end

function Mini_addons_buff_check(frame, ctrl, str, buff_id)
    local check = ctrl:IsChecked()
    local buff_id_str = tostring(buff_id)
    g.buffs[buff_id_str] = check
    Mini_addons_save_buffs()
end

function Mini_addons_ON_PARTYINFO_BUFFLIST_UPDATE(partyinfo)
    local partyinfo = ui.GetFrame("partyinfo")
    if not partyinfo then
        return
    end
    local pc_party = session.party.GetPartyInfo()
    if pc_party == nil then
        DESTROY_CHILD_BYNAME(partyinfo, "PTINFO_")
        partyinfo:ShowWindow(0)
        return
    end
    local list = session.party.GetPartyMemberList(0)
    local count = list:Count()
    local my_info = session.party.GetMyPartyObj()
    for i = 0, count - 1 do
        local party_member_info = list:Element(i)
        if geMapTable.GetMapName(party_member_info:GetMapID()) ~= "None" then
            local buff_count = party_member_info:GetBuffCount()
            local party_info_ctrl_set = partyinfo:GetChild("PTINFO_" .. party_member_info:GetAID())
            if party_info_ctrl_set then
                local buff_list_slot_set = GET_CHILD(party_info_ctrl_set, "buffList", "ui::CSlotSet")
                local debuff_list_slot_set = GET_CHILD(party_info_ctrl_set, "debuffList", "ui::CSlotSet")
                for j = 0, buff_list_slot_set:GetSlotCount() - 1 do
                    local slot = buff_list_slot_set:GetSlotByIndex(j)
                    if not slot then
                        break
                    end
                    slot:SetKeyboardSelectable(false)
                    slot:ShowWindow(0)
                end
                for j = 0, debuff_list_slot_set:GetSlotCount() - 1 do
                    local slot = debuff_list_slot_set:GetSlotByIndex(j)
                    if not slot then
                        break
                    end
                    slot:ShowWindow(0)
                end
                if buff_count <= 0 then
                    party_member_info:ResetBuff()
                    buff_count = party_member_info:GetBuffCount()
                end
                if buff_count > 0 then
                    local buff_index = 0
                    local debuff_index = 0
                    for j = 0, buff_count - 1 do
                        local buff_id = party_member_info:GetBuffIDByIndex(j)
                        local cls = GetClassByType("Buff", buff_id)
                        if cls and IS_PARTY_INFO_SHOWICON(cls.ShowIcon) == true and cls.ClassName ~= "TeamLevel" then
                            local buff_over = party_member_info:GetBuffOverByIndex(j)
                            local buff_time = party_member_info:GetBuffTimeByIndex(j)
                            local slot = nil
                            if cls.Group1 == "Buff" then
                                if g.settings.party_buff == 1 then
                                    if g.buffs[tostring(buff_id)] == 1 then
                                        slot = buff_list_slot_set:GetSlotByIndex(buff_index)
                                        buff_index = buff_index + 1
                                    end
                                else
                                    slot = buff_list_slot_set:GetSlotByIndex(buff_index)
                                    buff_index = buff_index + 1
                                end
                            elseif cls.Group1 == "Debuff" then
                                slot = debuff_list_slot_set:GetSlotByIndex(debuff_index)
                                debuff_index = debuff_index + 1
                            end
                            if slot then
                                local icon = slot:GetIcon()
                                if not icon then
                                    icon = CreateIcon(slot)
                                end
                                local handle = 0
                                if my_info then
                                    if my_info:GetMapID() == party_member_info:GetMapID() and my_info:GetChannel() ==
                                        party_member_info:GetChannel() then
                                        handle = party_member_info:GetHandle()
                                    end
                                end
                                icon:SetDrawCoolTimeText(math.floor(buff_time / 1000))
                                icon:SetTooltipType("buff")
                                icon:SetTooltipArg(tostring(handle), buff_id, "")
                                local image_name = "icon_" .. TryGetProp(cls, "Icon", "None")
                                if image_name ~= "icon_None" then
                                    icon:Set(image_name, "BUFF", buff_id, 0)
                                end
                                if buff_over > 1 then
                                    slot:SetText("{s13}{ol}{b}" .. buff_over, "count", ui.RIGHT, ui.BOTTOM, 1, 2)
                                else
                                    slot:SetText("")
                                end
                                slot:ShowWindow(1)
                            end
                        end
                    end
                end
            end
        end
    end
end
