-- monster_card_changer ここから
-- カードスロットは 12 枠で、3 枠ずつ色(カードグループ)が決まっている。
-- 0-2=ATK(赤) / 3-5=DEF(青) / 6-8=UTIL(紫) / 9-11=STAT(緑)
-- (素の CARD_SLOT_GET_GROUP_NAME / CARD_SLOTS_CREATE と同じ並び)
g.monster_card_changer_slot_count = 12
g.monster_card_changer_slot_colors = {"red", "red", "red", "blue", "blue", "blue", "purple", "purple", "purple",
                                      "green", "green", "green"}
g.monster_card_changer_colors = {"red", "blue", "purple", "green"}
-- 着脱はゲーム側のプリセットを 1 枠だけ作業用に借りて行う(素に空き番号が無いため)。
-- 借りるのは EQUIP / REMOVE を押したときだけで、画面を開いただけでは書き込まない。
g.monster_card_changer_scratch_page = 0

function Monster_card_changer_save_settings()
    g.save_json(g.monster_card_changer_path, g.monster_card_changer_settings)
end

function Monster_card_changer_load_settings()
    g.monster_card_changer_path = string.format("../addons/%s/%s/monster_card_changer.json", addon_name_lower,
        g.active_id)
    local settings = g.load_json(g.monster_card_changer_path)
    if not settings then
        settings = {
            presets = {}
        }
    end
    local changed = false
    for i = 1, 10 do
        if not settings.presets[i] then
            local title = ScpArgMsg('CardPresetNumber{index}', 'index', i)
            settings.presets[i] = {
                name = title,
                slots = {}
            }
            changed = true
        end
        if not settings.presets[i].slots or #settings.presets[i].slots < g.monster_card_changer_slot_count then
            local slots = settings.presets[i].slots or {}
            for j = 1, g.monster_card_changer_slot_count do
                if not slots[j] then
                    slots[j] = {
                        card_id = 0,
                        card_exp = 0,
                        card_lv = 0
                    }
                end
            end
            settings.presets[i].slots = slots
            changed = true
        end
    end
    g.monster_card_changer_settings = settings
    if changed then
        Monster_card_changer_save_settings()
    end
end

-- 色ごとの保護設定(キャラごと)。未設定なら 0 で埋めて返す
function Monster_card_changer_get_color_settings()
    local settings = g.monster_card_changer_settings
    if not settings[g.login_name] then
        settings[g.login_name] = {}
    end
    local colors = settings[g.login_name]
    for _, color in ipairs(g.monster_card_changer_colors) do
        if colors[color] == nil then
            colors[color] = 0
        end
    end
    return colors
end

-- slot_no は 1〜12
function Monster_card_changer_is_protected(slot_no)
    local color = g.monster_card_changer_slot_colors[slot_no]
    if not color then
        return false
    end
    return Monster_card_changer_get_color_settings()[color] == 1
end

-- カードレベルは exp から引き直す。素も GETMYCARD_INFO の戻り値をそのまま使わず
-- prop:GetLevel(exp) で計算し直している(EQUIP_CARDSLOT_INFO_OPEN / _GETMYCARD_INFO)ので、
-- 倉庫やインベントリのアイテムの Level と突き合わせるときはこちらを使うこと。
function Monster_card_changer_card_level(cls_id, card_exp)
    if not cls_id or cls_id == 0 then
        return 0
    end
    local prop = geItemTable.GetProp(cls_id)
    if not prop then
        return 0
    end
    local ok, lv = pcall(function()
        return prop:GetLevel(card_exp or 0)
    end)
    if ok and lv then
        return tonumber(lv) or 0
    end
    return 0
end

-- 今選んでいるプリセット番号(0 起点)。
-- drop_list:GetSelItemKey() ではなくフレームの PAGE を正とする。
-- PAGE は Monster_card_changer_select_preset が押下のたびに必ず書くので、
-- ドロップリスト側の選択状態がずれていてもプリセットを取り違えない。
function Monster_card_changer_current_page()
    local monster_card_changer = ui.GetFrame(addon_name_lower .. "monster_card_changer")
    if monster_card_changer then
        local page = monster_card_changer:GetUserIValue("PAGE")
        if page and page >= 0 and page < #g.monster_card_changer_settings.presets then
            return page
        end
    end
    local monstercardpreset = ui.GetFrame("monstercardpreset")
    local drop_list = monstercardpreset and GET_CHILD(monstercardpreset, "drop_list")
    if drop_list then
        local page = tonumber(drop_list:GetSelItemKey())
        if page then
            return page
        end
    end
    return 0
end

function monster_card_changer_on_init()
    if not g.monster_card_changer_settings then
        Monster_card_changer_load_settings()
    end
    local old_func = g.settings.monster_card_changer.old_init_func
    if _G[old_func] then
        return
    end
    if g.settings.monster_card_changer.use == 0 then
        Monster_card_changer_not_use()
        return
    end
    if g.get_map_type() == "City" then
        Monster_card_changer_inventory_frame_init()
        g.setup_hook_and_event(g.addon, "CARD_PRESET_CHANGE_NAME_EXEC",
            "Monster_card_changer_CARD_PRESET_CHANGE_NAME_EXEC", false)
    end
end

function Monster_card_changer_not_use()
    local inventory = ui.GetFrame('inventory')
    local mcc = GET_CHILD(inventory, "mcc")
    if mcc then
        DESTROY_CHILD_BYNAME(inventory, "mcc")
    end
    local monster_card_changer = ui.GetFrame(addon_name_lower .. "monster_card_changer")
    if monster_card_changer then
        ui.DestroyFrame(monster_card_changer:GetName())
    end
    local monstercardslot = ui.GetFrame("monstercardslot")
    local applyBtn = GET_CHILD(monstercardslot, "applyBtn")
    if applyBtn then
        applyBtn:SetEventScript(ui.LBUTTONUP, "MONSTERCARDPRESET_FRAME_OPEN")
    end
    local monstercardpreset = ui.GetFrame('monstercardpreset')
    local preset_list = GET_CHILD_RECURSIVELY(monstercardpreset, "preset_list")
    preset_list:ShowWindow(1)
    local saveBtn = GET_CHILD_RECURSIVELY(monstercardpreset, "saveBtn")
    saveBtn:ShowWindow(1)
    local applyBtn = GET_CHILD_RECURSIVELY(monstercardpreset, "applyBtn")
    applyBtn:ShowWindow(1)
    local drop_list = GET_CHILD(monstercardpreset, 'drop_list')
    if drop_list then
        monstercardpreset:RemoveChild("drop_list")
    end
    local save_btn = GET_CHILD(monstercardpreset, 'save_btn')
    if save_btn then
        monstercardpreset:RemoveChild("save_btn")
    end
    local unequip = GET_CHILD(monstercardpreset, 'unequip')
    if unequip then
        monstercardpreset:RemoveChild("unequip")
    end
    local equip = GET_CHILD(monstercardpreset, 'equip')
    if equip then
        monstercardpreset:RemoveChild("equip")
    end
    local monstercardslot = ui.GetFrame('monstercardslot')
    for _, color in ipairs(g.monster_card_changer_colors) do
        local check_box = GET_CHILD(monstercardslot, color)
        if check_box then
            monstercardslot:RemoveChild(color)
        end
    end
end

function Monster_card_changer_CARD_PRESET_CHANGE_NAME_EXEC(my_frame, my_msg)
    local input_frame, ctrl = g.get_event_args(my_msg)
    if g.settings.monster_card_changer.use == 0 then
        g.FUNCS["CARD_PRESET_CHANGE_NAME_EXEC"](input_frame, ctrl)
        return
    end
    local new_name = GET_INPUT_STRING_TXT(input_frame)
    local name_str = TRIM_STRING_WITH_SPACING(new_name)
    if name_str == '' then
        ui.SysMsg(ClMsg('InvalidStringOrUnderMinLen'))
        return
    end
    local page = Monster_card_changer_current_page()
    g.monster_card_changer_settings.presets[page + 1].name = name_str
    Monster_card_changer_save_settings()
    _DISABLE_CARD_PRESET_CHANGE_NAME_BTN()
    input_frame:ShowWindow(0)
    local monster_card_changer = ui.GetFrame(addon_name_lower .. "monster_card_changer")
    AUTO_CAST(monster_card_changer)
    monster_card_changer:SetUserValue("PAGE", page)
    Monster_card_changer_preset_open(monster_card_changer)
end

function Monster_card_changer_inventory_frame_init()
    local inventory = ui.GetFrame('inventory')
    local mcc = inventory:CreateOrGetControl("button", "mcc", 3, 345, 30, 30)
    AUTO_CAST(mcc)
    mcc:SetSkinName("test_red_button")
    mcc:SetTextAlign("right", "center")
    mcc:SetText("{img monsterbtn_image 28 23}{/}")
    mcc:SetTextTooltip(g.lang == "Japanese" and "{ol}カード自動搬出入、自動着脱{/}" or
                           "{ol}Automatic card loading/unloading, automatic insertion/removal{nl}")
    mcc:SetEventScript(ui.LBUTTONUP, "Monster_card_changer_monstercardpreset_open")
    local monstercardslot = ui.GetFrame("monstercardslot")
    local applyBtn = GET_CHILD(monstercardslot, "applyBtn")
    AUTO_CAST(applyBtn)
    applyBtn:SetEventScript(ui.LBUTTONUP, "Monster_card_changer_monstercardpreset_open")
end

function Monster_card_changer_monstercardpreset_open(is_cc_helper)
    local monstercardpreset = ui.GetFrame('monstercardpreset')
    if monstercardpreset:IsVisible() == 1 and is_cc_helper ~= 1 then
        MONSTERCARDSLOT_CLOSE()
        return
    end
    MONSTERCARDSLOT_FRAME_OPEN()
    local monster_card_changer = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "monster_card_changer", 0, 0, 0,
        0)
    AUTO_CAST(monster_card_changer)
    monster_card_changer:SetSkinName("None")
    monster_card_changer:SetVisible(1)
    Monster_card_changer_preset_open(monster_card_changer)
end

function Monster_card_changer_preset_open(monster_card_changer)
    local monstercardpreset = ui.GetFrame('monstercardpreset')
    -- 前回の動作が残した ready を持ち越さない。CC Helper 連携は ready == 1 を合図に
    -- REMOVE を始めるので、古い値のまま開くと画面が整う前に動き出す。
    g.monster_card_changer_ready = nil
    CARD_PRESET_CLEAR_SLOT(monstercardpreset)
    monstercardpreset:RemoveChild("drop_list")
    local drop_list = monstercardpreset:CreateOrGetControl('droplist', 'drop_list', 45, 66, 178, 20)
    AUTO_CAST(drop_list)
    drop_list:SetSkinName('droplist_normal')
    drop_list:EnableHitTest(1)
    drop_list:SetTextAlign("center", "center")
    for i, preset_data in ipairs(g.monster_card_changer_settings.presets) do
        local preset_name = "{ol}" .. preset_data.name
        local scp = string.format("Monster_card_changer_select_preset(%d)", i - 1)
        drop_list:AddItem(i - 1, preset_name, 0, scp)
    end
    local item_num = monster_card_changer:GetUserIValue("PAGE")
    drop_list:SelectItem(item_num)
    local preset_list = GET_CHILD_RECURSIVELY(monstercardpreset, "preset_list")
    preset_list:ShowWindow(0)
    local saveBtn = GET_CHILD_RECURSIVELY(monstercardpreset, "saveBtn")
    saveBtn:ShowWindow(0)
    local save_btn = monstercardpreset:CreateOrGetControl("button", "save_btn", 340, 57, 70, 38)
    AUTO_CAST(save_btn)
    save_btn:SetText("{@st66b}SAVE")
    save_btn:SetSkinName("test_pvp_btn")
    save_btn:SetTextTooltip(g.lang == "Japanese" and
                                "{ol}現在装備中のカード情報を、現在のプリセットに呼び出します" or
                                "{ol}Load currently equipped card information{nl}into the current preset")
    save_btn:SetEventScript(ui.LBUTTONUP, "Monster_card_changer_msgbox")
    local unequip = monstercardpreset:CreateOrGetControl("button", "unequip", 480, 57, 70, 38)
    AUTO_CAST(unequip)
    unequip:SetText("{@st66b}REMOVE")
    unequip:SetSkinName("test_pvp_btn")
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    if accountwarehouse:IsVisible() == 1 then
        unequip:SetTextTooltip(g.lang == "Japanese" and
                                   "{ol}現在装備中のカードを取り外し、倉庫へ搬入します{nl}保護した色はそのまま残します" or
                                   "{ol}Unequip currently equipped cards{nl}and transfer them to the warehouse{nl}Protected colors are kept")
    else
        unequip:SetTextTooltip(g.lang == "Japanese" and
                                   "{ol}現在装備中のカードを取り外します{nl}保護した色はそのまま残します" or
                                   "{ol}Unequip currently equipped cards{nl}Protected colors are kept")
    end
    unequip:SetEventScript(ui.LBUTTONUP, "Monster_card_changer_remove")
    local applyBtn = GET_CHILD_RECURSIVELY(monstercardpreset, "applyBtn")
    applyBtn:ShowWindow(0)
    local equip = monstercardpreset:CreateOrGetControl("button", "equip", 410, 57, 70, 38)
    AUTO_CAST(equip)
    equip:SetText("{@st66b}EQUIP")
    equip:SetSkinName("test_pvp_btn")
    equip:SetTextTooltip(
        g.lang == "Japanese" and
            "{ol}現在のプリセットへ、装備カードを変更します{nl}保護した色はそのまま残します" or
            "{ol}Change equipped cards to the current preset{nl}Protected colors are kept")
    equip:SetEventScript(ui.LBUTTONUP, "Monster_card_changer_equip_get_presetinfo")
    local monstercardslot = ui.GetFrame('monstercardslot')
    local color_settings = Monster_card_changer_get_color_settings()
    local card_colors = {{
        name = "red",
        x = 50,
        y = 70
    }, {
        name = "blue",
        x = 365,
        y = 70
    }, {
        name = "purple",
        x = 50,
        y = 210
    }, {
        name = "green",
        x = 365,
        y = 210
    }}
    for _, color_info in ipairs(card_colors) do
        local color_name = color_info.name
        local checkbox = monstercardslot:CreateOrGetControl('checkbox', color_name, color_info.x, color_info.y, 25, 25)
        AUTO_CAST(checkbox)
        checkbox:SetEventScript(ui.LBUTTONUP, "Monster_card_changer_color_save")
        checkbox:SetEventScriptArgString(ui.LBUTTONUP, color_name)
        checkbox:SetCheck(color_settings[color_name])
        checkbox:SetTextTooltip(g.lang == "Japanese" and
                                    "{ol}チェックを入れると該当の色のカードを外しません{nl}EQUIP でも上書きしません" or
                                    "{ol}checked, cards of the specified color will not be unequipped{nl}EQUIP does not overwrite them either")
    end
    Monster_card_changer_save_settings()
    monster_card_changer:RunUpdateScript("Monster_card_changer_preset_card_set", 1.0)
    return 0
end

-- 選択中のプリセットの中身を画面へ描くだけ。**サーバーへは書き込まない。**
-- 以前はここで SetCardPreset(0, ...) を呼んでいたが、これは素の SAVE ボタンと同じ
-- サーバー保存なので、画面を開いたりプリセットを選び直すたびにゲーム標準のプリセットを
-- 潰していた。書き込むのは EQUIP / REMOVE を押したときだけにする。
function Monster_card_changer_preset_card_set(monster_card_changer)
    local monstercardpreset = ui.GetFrame("monstercardpreset")
    -- 素の MONSTERCARDPRESET_FRAME_OPEN は呼ばない。あれは preset_list を 0 番へ選び直して
    -- RequestCardPreset(0) まで走るので、こちらが描いた内容を上書きしてしまう。
    -- 窓を出すのに要るのは ui.OpenFrame だけ（_CARD_PRESET_SLOT_EQUIP は窓が出ていないと
    -- 何もせずに戻る）。
    ui.OpenFrame("monstercardpreset")
    monstercardpreset:ShowWindow(1)
    CARD_PRESET_CLEAR_SLOT(monstercardpreset)
    local page = Monster_card_changer_current_page()
    local preset = g.monster_card_changer_settings.presets[page + 1]
    if preset and preset.slots then
        for i = 1, g.monster_card_changer_slot_count do
            local slot_data = preset.slots[i]
            local card_id = slot_data and slot_data.card_id or 0
            if card_id ~= 0 then
                local card_exp = slot_data.card_exp or 0
                local card_lv = Monster_card_changer_card_level(card_id, card_exp)
                if card_lv == 0 then
                    card_lv = tonumber(slot_data.card_lv) or 1
                end
                _CARD_PRESET_SLOT_EQUIP(i, card_id, card_lv, card_exp)
            end
        end
    end
    g.monster_card_changer_ready = 1
    return 0
end

function Monster_card_changer_select_preset(page)
    local monster_card_changer = ui.GetFrame(addon_name_lower .. "monster_card_changer")
    AUTO_CAST(monster_card_changer)
    monster_card_changer:SetUserValue("PAGE", page)
    monster_card_changer:RunUpdateScript("Monster_card_changer_preset_card_set", 0.1)
end

function Monster_card_changer_msgbox()
    local msg = g.lang == "Japanese" and
                    "現在装備中のカード情報を、プリセットに登録しますか？" or
                    "Do you want to save the currently equipped cards to the preset?"
    local yes_scp = string.format("Monster_card_changer_save_preset()")
    ui.MsgBox(msg, yes_scp, "None")
end

function Monster_card_changer_save_preset()
    local page = Monster_card_changer_current_page()
    local preset = g.monster_card_changer_settings.presets[page + 1]
    if not preset then
        return
    end
    local monstercardpreset = ui.GetFrame("monstercardpreset")
    CARD_PRESET_CLEAR_SLOT(monstercardpreset)
    local slots_settings = preset.slots
    for i = 1, g.monster_card_changer_slot_count do
        local card_id, card_lv, card_exp = GETMYCARD_INFO(i - 1)
        local level = Monster_card_changer_card_level(card_id, card_exp)
        if level == 0 then
            level = card_lv or 0
        end
        if slots_settings[i] then
            slots_settings[i].card_id = card_id
            slots_settings[i].card_exp = card_exp
            slots_settings[i].card_lv = level
        end
        if card_id ~= 0 then
            _CARD_PRESET_SLOT_EQUIP(i, card_id, level, card_exp)
        end
    end
    g.vlog("[MCC] SAVE: プリセット %d へ保存", page + 1)
    Monster_card_changer_save_settings()
end

function Monster_card_changer_color_save(monstercardslot, checkbox, check_name)
    local is_check = checkbox:IsChecked()
    Monster_card_changer_get_color_settings()[check_name] = is_check
    g.vlog("[MCC] 色の保護 %s=%s", tostring(check_name), tostring(is_check))
    Monster_card_changer_save_settings()
end

-- 適用するプリセットの中身を組み立てる。
--
-- **空き枠にも 0 を入れて必ず 12 要素にすること。** 素の CARD_PRESET_GET_CARD_EXP_LIST と
-- 同じで、リストの位置がそのままスロット番号になる。詰めると後ろのカードが前の色の枠へ
-- ずれ込み、紫のカードが赤の枠へ入る。
--
-- mode = "remove" … 保護色以外を空にする
-- mode = "equip"  … 保護色以外をプリセットの内容にする
--
-- どちらも保護色の枠には「今装備しているカード」を書き戻す。SCR_TX_APPLY_CARD_PRESET は
-- 12 枠を丸ごと差し替える命令で、一部の枠だけ適用する手段は素にも無いため、現状を
-- 書き戻すことでしか保護は成立しない。色チェックを外す側のリストにだけ効かせても、
-- 適用そのものは全枠を対象にするので保護色まで外れてしまう。
function Monster_card_changer_build_preset(mode, page)
    local card_list = {}
    local exp_list = {}
    local slots = nil
    if mode == "equip" then
        local preset = g.monster_card_changer_settings.presets[page + 1]
        slots = preset and preset.slots
    end
    for i = 1, g.monster_card_changer_slot_count do
        local card_id = 0
        local card_exp = 0
        if Monster_card_changer_is_protected(i) then
            local id, lv, exp = GETMYCARD_INFO(i - 1)
            card_id = id or 0
            card_exp = exp or 0
        elseif slots and slots[i] then
            card_id = slots[i].card_id or 0
            card_exp = slots[i].card_exp or 0
        end
        card_list[i] = card_id
        exp_list[i] = card_exp
    end
    return card_list, exp_list
end

-- 書き込んだ内容がサーバー側に載ったかを見る
function Monster_card_changer_preset_matches(card_list)
    local info = equipcard.GetCardPresetInfo(g.monster_card_changer_scratch_page)
    local seen = {}
    if info ~= nil then
        local count = info:Count()
        for i = 0, count - 1 do
            local element = info:Element(i)
            local slot_no = element.slot_idx
            -- 12 枠の外は見なかったことにする。ここで false を返す作りにすると、
            -- 想定外の枠が 1 つ返るだけで**永久に一致せず機能ごと使えなくなる**。
            if slot_no and slot_no >= 1 and slot_no <= g.monster_card_changer_slot_count then
                if card_list[slot_no] ~= element.class_id then
                    return false
                end
                seen[slot_no] = true
            end
        end
    end
    for i = 1, g.monster_card_changer_slot_count do
        if card_list[i] ~= 0 and not seen[i] then
            return false
        end
    end
    return true
end

-- 作業用プリセットへ書き込み、**サーバーに載ったのを確かめてから**次へ進む。
-- 以前は書き込みの 1 秒後に適用していたため、間に合わないと 1 つ前に選んでいた
-- プリセットがそのまま適用されていた。プリセット 1 のままだと中身が変わらず
-- 気付けないので、「2 番目以降を選ぶと反映されない」という形で出ていた。
function Monster_card_changer_write_preset(card_list, exp_list, next_func)
    g.monster_card_changer_pending = {
        list = card_list,
        next_func = next_func,
        deadline = imcTime.GetAppTime() + 5.0,
        requested = 0
    }
    local monster_card_changer = ui.GetFrame(addon_name_lower .. "monster_card_changer")
    if not monster_card_changer then
        -- 窓を閉じられた後。書き込みも適用もせずに終わる（中途半端に適用しない）
        g.monster_card_changer_pending = nil
        g.vlog("[MCC] 作業用フレームが無いので中止")
        return
    end
    SetCardPreset(g.monster_card_changer_scratch_page, card_list, exp_list)
    monster_card_changer:RunUpdateScript("Monster_card_changer_confirm_preset", 0.1)
end

function Monster_card_changer_confirm_preset(monster_card_changer)
    local pending = g.monster_card_changer_pending
    if not pending then
        monster_card_changer:StopUpdateScript("Monster_card_changer_confirm_preset")
        return 0
    end
    if pending.requested == 0 then
        -- サーバーへ問い合わせ直す。手元のキャッシュだけを見て判断すると
        -- 「書いたつもり」のまま先へ進んでしまう。
        pending.requested = 1
        RequestCardPreset(g.monster_card_changer_scratch_page)
        return 1
    end
    if Monster_card_changer_preset_matches(pending.list) then
        local next_func = pending.next_func
        g.monster_card_changer_pending = nil
        monster_card_changer:StopUpdateScript("Monster_card_changer_confirm_preset")
        g.vlog("[MCC] 作業用プリセット %d への書き込みを確認", g.monster_card_changer_scratch_page)
        _G[next_func](monster_card_changer)
        return 0
    end
    if imcTime.GetAppTime() > pending.deadline then
        g.monster_card_changer_pending = nil
        monster_card_changer:StopUpdateScript("Monster_card_changer_confirm_preset")
        g.vlog("[MCC] 作業用プリセットの書き込みを確認できずに中止")
        ui.SysMsg(g.lang == "Japanese" and
                      "{#FF0000}[MCC]プリセットの書き込みに失敗しました。やり直してください" or
                      "{#FF0000}[MCC]Failed to write the preset. Please try again")
        Monster_card_changer_end_of_operation(monster_card_changer)
        return 0
    end
    return 1
end

-- 手元のインベントリを走査して、まだ guid が決まっていないカードに割り当てる。
-- レベルまで一致するものを先に押さえ、余ったぶんは ClassID だけで拾う
-- (カードレベルの取得元が食い違っていても「1 枚も拾えない」で止まらないようにするため)。
function Monster_card_changer_resolve_guids()
    local used = {}
    local rest = 0
    for _, data in ipairs(g.monster_card_changer_cardlist) do
        if data.guid then
            used[data.guid] = true
        else
            rest = rest + 1
        end
    end
    if rest == 0 then
        return 0
    end
    local pool = {}
    local inv_list = session.GetInvItemList()
    local guid_list = inv_list:GetGuidList()
    local cnt = guid_list:Count()
    for i = 0, cnt - 1 do
        local guid = guid_list:Get(i)
        if not used[guid] then
            local inv_item = inv_list:GetItemByGuid(guid)
            local item_obj = inv_item and GetIES(inv_item:GetObject())
            if item_obj then
                pool[#pool + 1] = {
                    guid = guid,
                    cls_id = item_obj.ClassID,
                    lv = tonumber(TryGetProp(item_obj, "Level", 0)) or 0
                }
            end
        end
    end
    local resolved = 0
    for _, pass in ipairs({"exact", "class"}) do
        for _, data in ipairs(g.monster_card_changer_cardlist) do
            if not data.guid then
                for _, candidate in ipairs(pool) do
                    if not used[candidate.guid] and candidate.cls_id == data.cls_id and
                        (pass == "class" or candidate.lv == data.lv) then
                        data.guid = candidate.guid
                        used[candidate.guid] = true
                        resolved = resolved + 1
                        if pass == "class" then
                            g.vlog("[MCC] レベル不一致のまま照合 cls=%s 期待lv=%s 実lv=%s",
                                tostring(data.cls_id), tostring(data.lv), tostring(candidate.lv))
                        end
                        break
                    end
                end
            end
        end
    end
    return resolved
end

function Monster_card_changer_notice()
    local msg = g.lang == "Japanese" and
                    "{ol}{#CCCC22}[MCC]動作中。バグ防止の為他の動作は行わないでください" or
                    "{ol}{#CCCC22}[MCC]Operating. Please do not perform other operations to prevent bugs"
    imcAddOn.BroadMsg("NOTICE_Dm_Bell", msg, 2.5)
end

-- REMOVE: 保護していない色のカードだけ外し、倉庫が開いていれば預ける。
-- 引数は使わないが、ボタンの LBUTTONUP と CC Helper の Cc_helper_mcc_operation の
-- どちらからも monstercardpreset を渡して呼ばれるので受け取っておく。
function Monster_card_changer_remove(monstercardpreset)
    g.monster_card_changer_cardlist = {}
    for i = 1, g.monster_card_changer_slot_count do
        if not Monster_card_changer_is_protected(i) then
            local cls_id, card_lv, card_exp = GETMYCARD_INFO(i - 1)
            if cls_id and cls_id ~= 0 then
                local level = Monster_card_changer_card_level(cls_id, card_exp)
                if level == 0 then
                    level = card_lv or 0
                end
                table.insert(g.monster_card_changer_cardlist, {
                    cls_id = cls_id,
                    lv = level,
                    guid = nil
                })
            end
        end
    end
    g.vlog("[MCC] REMOVE: 外す枚数=%d", #g.monster_card_changer_cardlist)
    local card_list, exp_list = Monster_card_changer_build_preset("remove")
    Monster_card_changer_write_preset(card_list, exp_list, "Monster_card_changer_remove_apply")
end

function Monster_card_changer_remove_apply(monster_card_changer)
    pc.ReqExecuteTx_NumArgs("SCR_TX_APPLY_CARD_PRESET", g.monster_card_changer_scratch_page)
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    if accountwarehouse:IsVisible() ~= 1 or #g.monster_card_changer_cardlist == 0 then
        Monster_card_changer_end_of_operation(monster_card_changer)
        return
    end
    Monster_card_changer_notice()
    local inventory = ui.GetFrame("inventory")
    local inventype_Tab = GET_CHILD_RECURSIVELY(inventory, "inventype_Tab")
    if inventype_Tab then
        inventype_Tab:SelectTab(4)
    end
    g.monster_card_changer_deadline = imcTime.GetAppTime() + 10.0
    monster_card_changer:RunUpdateScript("Monster_card_changer_put_inv_to_warehouse", 0.2)
end

-- 外したカードが手元へ戻るのを待ちながら、1 枚ずつ倉庫へ預ける。
-- 以前は取り外し要求の 1 秒後に 1 回だけ走査していたため、サーバーからの戻りが
-- 間に合わないと guid を拾えず、そのまま 1 枚も預けずに終わっていた。
function Monster_card_changer_put_inv_to_warehouse(monster_card_changer)
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    local inventory = ui.GetFrame("inventory")
    if accountwarehouse:IsVisible() ~= 1 or inventory:IsVisible() ~= 1 then
        monster_card_changer:StopUpdateScript("Monster_card_changer_put_inv_to_warehouse")
        g.vlog("[MCC] 倉庫かインベントリが閉じたので搬入を中断(残り %d 枚)",
            #g.monster_card_changer_cardlist)
        Monster_card_changer_end_of_operation(monster_card_changer)
        return 0
    end
    if #g.monster_card_changer_cardlist == 0 then
        monster_card_changer:StopUpdateScript("Monster_card_changer_put_inv_to_warehouse")
        Monster_card_changer_end_of_operation(monster_card_changer)
        return 0
    end
    if Monster_card_changer_resolve_guids() > 0 then
        -- 手元へ戻ってきたぶんが増えたので、待ち時間を延ばす
        g.monster_card_changer_deadline = imcTime.GetAppTime() + 10.0
    end
    local data = g.monster_card_changer_cardlist[1]
    if data.guid then
        local inv_item = session.GetInvItemByGuid(data.guid)
        if inv_item then
            item.PutItemToWarehouse(IT_ACCOUNT_WAREHOUSE, data.guid, 1,
                accountwarehouse:GetUserIValue("HANDLE"), nil)
            return 1
        end
        -- 倉庫へ入ったので次のカードへ
        table.remove(g.monster_card_changer_cardlist, 1)
        g.monster_card_changer_deadline = imcTime.GetAppTime() + 10.0
        return 1
    end
    if imcTime.GetAppTime() > g.monster_card_changer_deadline then
        monster_card_changer:StopUpdateScript("Monster_card_changer_put_inv_to_warehouse")
        g.vlog("[MCC] 手元に見つからないカードが %d 枚あるため搬入を打ち切り",
            #g.monster_card_changer_cardlist)
        ui.SysMsg(g.lang == "Japanese" and
                      "{#FF0000}[MCC]倉庫へ入れられなかったカードがあります" or
                      "{#FF0000}[MCC]Some cards could not be stored in the warehouse")
        Monster_card_changer_end_of_operation(monster_card_changer)
        return 0
    end
    return 1
end

-- EQUIP: 必要なカードを揃えてから、保護色以外をプリセットの内容へ差し替える。
-- 何を揃えるかは**設定ファイルの 12 枠から直接**決める。以前は素の _GETMYCARD_INFO を
-- 使っていたが、あれは素の preset_list の選択キーを見るので、MCC が足した drop_list の
-- 選択とずれることがあり、空のプリセットを読んで「倉庫から何も出さずに適用」になっていた。
function Monster_card_changer_equip_get_presetinfo()
    local page = Monster_card_changer_current_page()
    local preset = g.monster_card_changer_settings.presets[page + 1]
    if not preset or not preset.slots then
        return
    end
    g.monster_card_changer_cardlist = {}
    for i = 1, g.monster_card_changer_slot_count do
        if not Monster_card_changer_is_protected(i) then
            local slot_data = preset.slots[i]
            local cls_id = slot_data and slot_data.card_id or 0
            if cls_id ~= 0 then
                local level = Monster_card_changer_card_level(cls_id, slot_data.card_exp or 0)
                if level == 0 then
                    level = tonumber(slot_data.card_lv) or 0
                end
                table.insert(g.monster_card_changer_cardlist, {
                    cls_id = cls_id,
                    lv = level,
                    guid = nil
                })
            end
        end
    end
    g.vlog("[MCC] EQUIP: プリセット %d / 必要枚数=%d", page + 1, #g.monster_card_changer_cardlist)
    local monster_card_changer = ui.GetFrame(addon_name_lower .. "monster_card_changer")
    local accountwarehouse = ui.GetFrame("accountwarehouse")
    if accountwarehouse:IsVisible() == 1 and #g.monster_card_changer_cardlist > 0 then
        Monster_card_changer_take_from_warehouse(monster_card_changer, accountwarehouse)
    else
        Monster_card_changer_equip_apply(monster_card_changer)
    end
end

function Monster_card_changer_take_from_warehouse(monster_card_changer, accountwarehouse)
    Monster_card_changer_notice()
    local inventory = ui.GetFrame("inventory")
    local inventype_Tab = GET_CHILD_RECURSIVELY(inventory, "inventype_Tab")
    if inventype_Tab then
        inventype_Tab:SelectTab(4)
    end
    -- 手元にあるぶんを先に押さえる
    Monster_card_changer_resolve_guids()
    local used = {}
    for _, data in ipairs(g.monster_card_changer_cardlist) do
        if data.guid then
            used[data.guid] = true
        end
    end
    local pool = {}
    local item_list = session.GetEtcItemList(IT_ACCOUNT_WAREHOUSE)
    local guid_list = item_list:GetGuidList()
    local cnt = guid_list:Count()
    for i = 0, cnt - 1 do
        local guid = guid_list:Get(i)
        if not used[guid] then
            local acw_item = item_list:GetItemByGuid(guid)
            local item_obj = acw_item and GetIES(acw_item:GetObject())
            if item_obj then
                pool[#pool + 1] = {
                    guid = guid,
                    cls_id = acw_item.type,
                    lv = tonumber(TryGetProp(item_obj, "Level", 0)) or 0
                }
            end
        end
    end
    local take_list = {}
    for _, pass in ipairs({"exact", "class"}) do
        for _, data in ipairs(g.monster_card_changer_cardlist) do
            if not data.guid then
                for _, candidate in ipairs(pool) do
                    if not used[candidate.guid] and candidate.cls_id == data.cls_id and
                        (pass == "class" or candidate.lv == data.lv) then
                        data.guid = candidate.guid
                        used[candidate.guid] = true
                        take_list[candidate.guid] = 1
                        break
                    end
                end
            end
        end
    end
    local take_count = 0
    session.ResetItemList()
    for guid, count in pairs(take_list) do
        session.AddItemID(tonumber(guid), count)
        take_count = take_count + 1
    end
    g.vlog("[MCC] 倉庫から取り出す枚数=%d", take_count)
    if take_count == 0 then
        Monster_card_changer_equip_apply(monster_card_changer)
        return
    end
    item.TakeItemFromWarehouse_List(IT_ACCOUNT_WAREHOUSE, session.GetItemIDList(),
        accountwarehouse:GetUserIValue("HANDLE"))
    g.monster_card_changer_deadline = imcTime.GetAppTime() + 10.0
    monster_card_changer:RunUpdateScript("Monster_card_changer_wait_take", 0.2)
end

function Monster_card_changer_wait_take(monster_card_changer)
    local rest = 0
    for _, data in ipairs(g.monster_card_changer_cardlist) do
        if data.guid and not session.GetInvItemByGuid(data.guid) then
            rest = rest + 1
        end
    end
    if rest == 0 then
        monster_card_changer:StopUpdateScript("Monster_card_changer_wait_take")
        Monster_card_changer_equip_apply(monster_card_changer)
        return 0
    end
    if imcTime.GetAppTime() > g.monster_card_changer_deadline then
        monster_card_changer:StopUpdateScript("Monster_card_changer_wait_take")
        g.vlog("[MCC] 倉庫から取り出せていないカードが %d 枚あるまま装備へ進む", rest)
        ui.SysMsg(g.lang == "Japanese" and
                      "{#FF0000}[MCC]倉庫から取り出せなかったカードがあります" or
                      "{#FF0000}[MCC]Some cards could not be taken from the warehouse")
        Monster_card_changer_equip_apply(monster_card_changer)
        return 0
    end
    return 1
end

function Monster_card_changer_equip_apply(monster_card_changer)
    local page = Monster_card_changer_current_page()
    local card_list, exp_list = Monster_card_changer_build_preset("equip", page)
    Monster_card_changer_write_preset(card_list, exp_list, "Monster_card_changer_apply_card_preset")
end

function Monster_card_changer_apply_card_preset(monster_card_changer)
    pc.ReqExecuteTx_NumArgs("SCR_TX_APPLY_CARD_PRESET", g.monster_card_changer_scratch_page)
    Monster_card_changer_end_of_operation(monster_card_changer)
end

function Monster_card_changer_end_of_operation(monster_card_changer)
    g.monster_card_changer_ready = 3
    if not monster_card_changer then
        monster_card_changer = ui.GetFrame(addon_name_lower .. "monster_card_changer")
    end
    if not monster_card_changer then
        return
    end
    g.monster_card_changer_cardlist = nil
    g.monster_card_changer_pending = nil
    ui.SysMsg("[MCC]End of Operation")
    monster_card_changer:RunUpdateScript("Monster_card_changer_preset_card_set", 1.0)
    monster_card_changer:RunUpdateScript("MONSTERCARDPRESET_FRAME_CLOSE", 3.0)
    monster_card_changer:RunUpdateScript("MONSTERCARDSLOT_CLOSE", 3.0)
end
-- monster_card_changer ここまで
