-- easy_buff ここから
-- 装備メンテナンスの部位。素の itembuffopen.lua の enable_slot_list と同じ並び
-- (向こうは local なので読めない。素の窓の子は 'ITEMBUFF_CTRL_' .. 部位 で引ける)
g.easy_buff_maint_slots = {"RH", "LH", "RH_SUB", "LH_SUB", "SHIRT", "PANTS", "GLOVES", "BOOTS"}
g.easy_buff_maint_labels = {
    RH = {"右手", "RH"},
    LH = {"左手", "LH"},
    RH_SUB = {"右手(サブ)", "RH sub"},
    LH_SUB = {"左手(サブ)", "LH sub"},
    SHIRT = {"上着", "Top"},
    PANTS = {"下衣", "Bottom"},
    GLOVES = {"手袋", "Gloves"},
    BOOTS = {"靴", "Boots"}
}
g.easy_buff_maint_preset_count = 5

-- 2.13.0〜2.15.0 のキャラごとの部位(char_maint_check = {[cid] = {[部位] = 0/1}})をプリセットへ移す。
-- 全部選択 → プリセット 1 / 全部外す → 0(自動実行しない) / それ以外 → 同じ中身のプリセット、
-- 無ければ空いているプリセット(2〜5)へ書き込む。空きが尽きたらプリセット 1 に寄せる。
-- 移したら char_maint_check は消す(2 回目以降は何もしない)。設定を書き換えたら true
function Easy_buff_migrate_maint(settings)
    local old = settings.char_maint_check
    if type(old) ~= "table" then
        return false
    end
    local next_free = 2
    -- cid の並びを固定する(pairs の順は実行ごとに変わりうるので、どのキャラが空きを取るかを決める)
    local cids = {}
    for cid in pairs(old) do
        table.insert(cids, cid)
    end
    table.sort(cids, function(a, b)
        return tostring(a) < tostring(b)
    end)
    for _, cid in ipairs(cids) do
        local char_check = old[cid]
        local checks, on_count = {}, 0
        for _, slot_name in ipairs(g.easy_buff_maint_slots) do
            local v = (type(char_check) == "table" and char_check[slot_name] == 0) and 0 or 1
            checks[slot_name] = v
            on_count = on_count + v
        end
        local preset
        if on_count == #g.easy_buff_maint_slots then
            preset = 1
        elseif on_count == 0 then
            preset = 0
        else
            for i = 2, next_free - 1 do
                local same = true
                for _, slot_name in ipairs(g.easy_buff_maint_slots) do
                    if settings.maint_presets_check[tostring(i)][slot_name] ~= checks[slot_name] then
                        same = false
                    end
                end
                if same then
                    preset = i
                    break
                end
            end
            if not preset and next_free <= g.easy_buff_maint_preset_count then
                preset = next_free
                settings.maint_presets_check[tostring(preset)] = checks
                next_free = next_free + 1
            end
            if not preset then
                preset = 1
            end
        end
        if settings.char_maint_preset[cid] == nil then
            settings.char_maint_preset[cid] = preset
        end
        g.vlog("easy_buff: 装備メンテナンスの部位(cid=%s %d 部位)をプリセット %d へ移した", tostring(cid),
            on_count, preset)
    end
    settings.char_maint_check = nil
    return true
end

function Easy_buff_save_settings()
    g.save_json(g.easy_buff_path, g.easy_buff_settings)
end

function Easy_buff_load_settings()
    g.easy_buff_path = string.format("../addons/%s/%s/easy_buff.json", addon_name_lower, g.active_id)
    local settings = g.load_json(g.easy_buff_path)
    if not settings then
        settings = {}
    end
    local defaults = {
        food_presets_name = {},
        food_presets_check = {},
        food_check = 1,
        -- 店を開いたときに自動実行するプリセットのキャラごとの選択({[cid] = 0〜4})。
        -- 無いキャラは food_check(アカウント共通の既定)に従う。プリセットの中身は共通のまま
        char_food_check = {},
        -- 他人の装備メンテナンスのプリセット。メシ屋と同じく、名前と部位は全キャラ共通で、
        -- どれを自動実行するかだけキャラごと({[cid] = 0〜5}。無いキャラは 1 = 既定の「すべて選択」)
        maint_presets_name = {},
        maint_presets_check = {},
        char_maint_preset = {},
        confirm_check = 0,
        repair_check = 0
    }
    for k, v in pairs(defaults) do
        if settings[k] == nil then
            settings[k] = v
        end
    end
    local changed = false
    for i = 1, 4 do
        local str_i = tostring(i)
        if not settings.food_presets_name[str_i] then
            settings.food_presets_name[str_i] = "preset " .. i
            changed = true
        end
        if not settings.food_presets_check[str_i] then
            settings.food_presets_check[str_i] = {}
            changed = true
        end
        for check_index = 1, 6 do
            local str_index = tostring(check_index)
            if not settings.food_presets_check[str_i][str_index] then
                settings.food_presets_check[str_i][str_index] = 1
                changed = true
            end
        end
    end
    for i = 1, g.easy_buff_maint_preset_count do
        local str_i = tostring(i)
        if not settings.maint_presets_name[str_i] then
            settings.maint_presets_name[str_i] = "preset " .. i
            changed = true
        end
        if not settings.maint_presets_check[str_i] then
            settings.maint_presets_check[str_i] = {}
            changed = true
        end
        for _, slot_name in ipairs(g.easy_buff_maint_slots) do
            if settings.maint_presets_check[str_i][slot_name] == nil then
                settings.maint_presets_check[str_i][slot_name] = 1
                changed = true
            end
        end
    end
    if Easy_buff_migrate_maint(settings) then
        changed = true
    end
    g.easy_buff_settings = settings
    if changed then
        Easy_buff_save_settings()
    end
end

-- このキャラで自動実行するプリセット(0 = 自動実行しない)。
-- 設定はアカウントで 1 回しか読まないが、g.cid はキャラチェンジのたびに入れ替わるので毎回引く
function Easy_buff_auto_preset()
    local value = g.easy_buff_settings.char_food_check[g.cid]
    if value == nil then
        value = g.easy_buff_settings.food_check
    end
    return value
end

-- このキャラで自動実行する装備メンテナンスのプリセット(0 = 自動実行しない)。g.cid はキャラチェンジで入れ替わるので毎回引く
function Easy_buff_maint_preset()
    local value = g.easy_buff_settings.char_maint_preset[g.cid]
    if value == nil then
        value = 1
    end
    return value
end

-- このキャラが装備メンテナンスで選ぶ部位か(1 / 0)
function Easy_buff_maint_selected(slot_name)
    local preset = Easy_buff_maint_preset()
    local checks = g.easy_buff_settings.maint_presets_check[tostring(preset)]
    if not checks then
        return 0
    end
    return checks[slot_name] == 0 and 0 or 1
end

function easy_buff_on_init()
    if not g.easy_buff_settings then
        Easy_buff_load_settings()
    end
    local old_func = g.settings.easy_buff.old_init_func
    if _G[old_func] then
        return
    end
    g.setup_hook_and_event(g.addon, "OPEN_FOOD_TABLE_UI", "Easy_buff_OPEN_FOOD_TABLE_UI", true)
    g.setup_hook_and_event(g.addon, "ITEMBUFF_REPAIR_UI_COMMON", "Easy_buff_ITEMBUFF_REPAIR_UI_COMMON", true)
    g.setup_hook_and_event(g.addon, "SQUIRE_BUFF_EQUIP_CTRL", "Easy_buff_SQUIRE_BUFF_EQUIP_CTRL", true)
    g.setup_hook_and_event(g.addon, "TARGET_BUFF_AUTOSELL_LIST", "Easy_buff_TARGET_BUFF_AUTOSELL_LIST", true)
    g.easy_buff_first = true
end
-- 設定フレーム
function Easy_buff_config_frame()
    local frame_name = addon_name_lower .. "easy_buff"
    local easy_buff = ui.CreateNewFrame("notice_on_pc", frame_name, 0, 0, 0, 0)
    easy_buff:RemoveAllChild()
    easy_buff:SetSkinName("test_frame_low")
    easy_buff:SetLayerLevel(999)
    local frame_w, frame_h = 580, 820
    easy_buff:Resize(frame_w, frame_h)
    -- 位置は g.settings_frame_pos に任せる(一覧が開いていなければ画面中央)。
    -- **素で list_frame:GetX() を呼ばないこと。** Addons Menu のショートカットから
    -- 開くと一覧は開いておらず nil で落ちる = 空の窓が出る(g.settings_frame_pos のコメント)。
    easy_buff:SetPos(g.settings_frame_pos(frame_w, frame_h))
    easy_buff:SetTitleBarSkin("None")
    easy_buff:EnableHittestFrame(1)
    easy_buff:EnableHitTest(1)
    easy_buff:ShowWindow(1)
    g.esc_register_destroy(frame_name)
    local title_text = easy_buff:CreateOrGetControl('richtext', 'title_text', 20, 15, 50, 30)
    AUTO_CAST(title_text)
    title_text:SetText("{ol}Easy Buff Config")
    -- 左のチェック(自動実行するプリセット)だけがキャラごと。誰の設定を触っているかを見せる
    local char_text = easy_buff:CreateOrGetControl('richtext', 'char_text', 180, 18, 280, 20)
    AUTO_CAST(char_text)
    char_text:SetText((g.lang == "Japanese" and "{ol}{s14}自動実行はキャラごと: " or "{ol}{s14}Auto-run per character: ") ..
                          tostring(g.login_name))
    char_text:SetTextTooltip(g.lang == "Japanese" and
                                 "{ol}左端のチェック(店を開いたら自動実行するプリセット)は{nl}キャラごとに覚えます。プリセットの名前・料理・部位は全キャラ共通です" or
                                 "{ol}The leftmost check (preset auto-run on opening the shop){nl}is saved per character. Preset names, foods and slots are shared")
    local close = easy_buff:CreateOrGetControl("button", "close", 0, 0, 20, 20)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Easy_buff_config_frame_close")
    local gbox = easy_buff:CreateOrGetControl("groupbox", "gbox", 10, 40, easy_buff:GetWidth() - 20,
        easy_buff:GetHeight() - 50)
    AUTO_CAST(gbox)
    gbox:SetSkinName("test_frame_midle_light")
    local icons = {"icon_item_sandwich", "icon_item_soup", "icon_item_yogurt", "icon_item_salad", "icon_item_BBQ",
                   "icon_item_champagne"}
    local x_offsets = {5, 75, 145, 215, 285, 355}
    local food_text = gbox:CreateOrGetControl('richtext', "food_text", 10, 5, 450, 20)
    AUTO_CAST(food_text)
    food_text:SetText(g.lang == "Japanese" and "{ol}メシ屋のプリセット" or "{ol}Food shop presets")
    local y = 30
    local auto_preset = Easy_buff_auto_preset()
    for i = 1, 4 do
        local str_i = tostring(i)
        local title_edit = gbox:CreateOrGetControl('edit', "preset_title_" .. i, 10, y + 5, 80, 20)
        AUTO_CAST(title_edit)
        title_edit:SetFontName('white_14_ol')
        title_edit:SetSkinName('test_weight_skin')
        title_edit:SetTextAlign('center', 'center')
        title_edit:SetText("{ol}" .. g.easy_buff_settings.food_presets_name[str_i])
        -- **ここで Focus() を呼ばないこと。**
        -- 開いた瞬間にプリセット 1 の名前欄へキーボードフォーカスが入ると、
        -- ESC の 1 回目がクライアント側の「入力欄から抜ける」処理に使われ、
        -- ESCAPE_PRESSED がこちらへ届かない(実機の verbose_log に行が 1 つも出ない)。
        -- 利用者から見ると「ESC を 2 回押さないと閉じない」になる。横取りする手段は無いので、
        -- フォーカスを取らないことでしか直せない。
        -- この設定画面はチェックのたびに組み立て直されるため、
        -- 残しておくと操作のたびにフォーカスを奪い返す点でも都合が悪かった。
        title_edit:SetEventScript(ui.ENTERKEY, "Easy_buff_config_presetname_change")
        local food_check = gbox:CreateOrGetControl('checkbox', "food_check" .. i, 10, y + 35, 30, 30)
        AUTO_CAST(food_check)
        food_check:SetTextTooltip(g.lang == "Japanese" and "{ol}チェックすると食事バフ自動化" or
                                      "{ol}Checked: Automate food buff")
        food_check:SetEventScript(ui.LBUTTONUP, "Easy_buff_config_check_toggle")
        food_check:SetEventScriptArgNumber(ui.LBUTTONUP, i)
        food_check:SetCheck(i == auto_preset and 1 or 0)
        local preset_gbox = gbox:CreateOrGetControl("groupbox", "preset_gbox_" .. i, 40, y + 30, gbox:GetWidth() - 50,
            40)
        AUTO_CAST(preset_gbox)
        preset_gbox:SetSkinName("test_frame_midle_light")
        for check_index = 1, #icons do
            local str_index = tostring(check_index)
            local icon_name = icons[check_index]
            local checkbox_x = x_offsets[check_index]
            local checkbox_name = "check_" .. i .. "_" .. check_index
            local checkbox_ctrl = preset_gbox:CreateOrGetControl('checkbox', checkbox_name, checkbox_x, 5, 30, 30)
            AUTO_CAST(checkbox_ctrl)
            checkbox_ctrl:SetText("{img " .. icon_name .. " 30 30}")
            checkbox_ctrl:SetCheck(g.easy_buff_settings.food_presets_check[str_i][str_index])
            checkbox_ctrl:SetEventScript(ui.LBUTTONUP, "Easy_buff_config_check_toggle")
        end
        y = y + 70
    end
    -- 他人の装備メンテナンスのプリセット。メシ屋と同じ並び(名前 / 自動実行のチェック / 中身)
    local maint_text = gbox:CreateOrGetControl('richtext', "maint_text", 10, y + 5, 450, 20)
    AUTO_CAST(maint_text)
    maint_text:SetText(g.lang == "Japanese" and "{ol}装備メンテナンスのプリセット(他人の店)" or
                           "{ol}Equipment maintenance presets (other players' shops)")
    maint_text:SetTextTooltip(g.lang == "Japanese" and
                                  "{ol}他人の装備メンテナンスを開いたとき、左端でチェックしたプリセットの部位だけを選んで実行します{nl}全部外すと自動実行しません" or
                                  "{ol}On another player's maintenance shop, only the slots of the checked preset are selected and run{nl}Uncheck all to disable auto-run")
    y = y + 30
    local maint_preset = Easy_buff_maint_preset()
    for i = 1, g.easy_buff_maint_preset_count do
        local str_i = tostring(i)
        local title_edit = gbox:CreateOrGetControl('edit', "maint_title_" .. i, 10, y + 5, 80, 20)
        AUTO_CAST(title_edit)
        title_edit:SetFontName('white_14_ol')
        title_edit:SetSkinName('test_weight_skin')
        title_edit:SetTextAlign('center', 'center')
        title_edit:SetText("{ol}" .. g.easy_buff_settings.maint_presets_name[str_i])
        -- Focus() を呼ばない理由はメシ屋の名前欄と同じ
        title_edit:SetEventScript(ui.ENTERKEY, "Easy_buff_config_presetname_change")
        local auto_check = gbox:CreateOrGetControl('checkbox', "maint_auto_" .. i, 10, y + 35, 30, 30)
        AUTO_CAST(auto_check)
        auto_check:SetTextTooltip(g.lang == "Japanese" and "{ol}チェックすると装備メンテナンス自動化" or
                                      "{ol}Checked: Automate equipment maintenance")
        auto_check:SetEventScript(ui.LBUTTONUP, "Easy_buff_config_check_toggle")
        auto_check:SetEventScriptArgNumber(ui.LBUTTONUP, i)
        auto_check:SetCheck(i == maint_preset and 1 or 0)
        local preset_gbox = gbox:CreateOrGetControl("groupbox", "maint_gbox_" .. i, 100, y + 3, 450, 64)
        AUTO_CAST(preset_gbox)
        preset_gbox:SetSkinName("test_frame_midle_light")
        local checks = g.easy_buff_settings.maint_presets_check[str_i]
        for index, slot_name in ipairs(g.easy_buff_maint_slots) do
            local col = (index - 1) % 4
            local row = math.floor((index - 1) / 4)
            local slot_check = preset_gbox:CreateOrGetControl('checkbox', "mcheck_" .. i .. "_" .. slot_name,
                5 + col * 110, 2 + row * 30, 30, 30)
            AUTO_CAST(slot_check)
            local label = g.easy_buff_maint_labels[slot_name]
            slot_check:SetText("{ol}" .. (g.lang == "Japanese" and label[1] or label[2]))
            slot_check:SetEventScript(ui.LBUTTONUP, "Easy_buff_config_check_toggle")
            slot_check:SetCheck(checks[slot_name] == 0 and 0 or 1)
        end
        y = y + 70
    end
    local confirm_check = gbox:CreateOrGetControl('checkbox', "confirm_check", 10, y + 10, 30, 30)
    AUTO_CAST(confirm_check)
    confirm_check:SetText(g.lang == "Japanese" and
                              "{ol}チェックするとバフ掛け直し確認(残り1時間以上)" or
                              "{ol}Check to Confirm Re-buffing (remaining over 1h)")
    confirm_check:SetEventScript(ui.LBUTTONUP, "Easy_buff_config_check_toggle")
    confirm_check:SetCheck(g.easy_buff_settings.confirm_check)
    -- repair_check
    local repair_check = gbox:CreateOrGetControl('checkbox', "repair_check", 10, y + 45, 30, 30)
    AUTO_CAST(repair_check)
    repair_check:SetText(g.lang == "Japanese" and
                             "{ol}チェックすると修理屋フレームを自動で閉じます" or
                             "{ol}Check to Auto-close Repair Shop Frame")
    repair_check:SetEventScript(ui.LBUTTONUP, "Easy_buff_config_check_toggle")
    repair_check:SetCheck(g.easy_buff_settings.repair_check)
end

function Easy_buff_config_frame_close(frame)
    ui.DestroyFrame(frame:GetName())
end

-- 名前欄の Enter。**ここで設定画面を作り直さないこと**(押した入力欄が消えて Enter がチャット入力欄へ抜ける。
-- docs/UI_RULES.md「入力欄の Enter で一覧を作り直さない」)。入力欄には打った文字がそのまま残っている
function Easy_buff_config_presetname_change(frame, ctrl)
    local ctrl_name = ctrl:GetName()
    local kind, index = string.match(ctrl_name, "^(%a+)_title_(%d+)$")
    local names = kind == "maint" and g.easy_buff_settings.maint_presets_name or
                      g.easy_buff_settings.food_presets_name
    local text = ctrl:GetText()
    local msg = g.lang == "Japanese" and text .. "{ol} 設定しました" or "{ol} Set up"
    ui.SysMsg(msg)
    names[index] = text
    g.vlog("easy_buff: %s のプリセット %s の名前を変えた", tostring(kind), tostring(index))
    Easy_buff_save_settings()
end

function Easy_buff_config_check_toggle(parent, ctrl, str, num)
    local ctrl_name = ctrl:GetName()
    local is_check = ctrl:IsChecked()
    if string.find(ctrl_name, "food_check") then
        -- このキャラの分だけ書く。food_check(共通の既定)は、まだ選んでいないキャラのために残す
        local preset = is_check == 1 and num or 0
        g.easy_buff_settings.char_food_check[g.cid] = preset
        g.vlog("easy_buff: 自動実行のプリセットを %d にした(cid=%s %s)", preset, tostring(g.cid),
            tostring(g.login_name))
    elseif ctrl_name == "confirm_check" then
        g.easy_buff_settings.confirm_check = is_check
    elseif ctrl_name == "repair_check" then
        g.easy_buff_settings.repair_check = is_check
    elseif string.find(ctrl_name, "^maint_auto_") then
        local preset = is_check == 1 and num or 0
        g.easy_buff_settings.char_maint_preset[g.cid] = preset
        g.vlog("easy_buff: 装備メンテナンスの自動実行のプリセットを %d にした(cid=%s %s)", preset, tostring(g.cid),
            tostring(g.login_name))
    elseif string.find(ctrl_name, "^mcheck_") then
        local preset_str, slot_name = string.match(ctrl_name, "^mcheck_(%d+)_(.+)$")
        g.easy_buff_settings.maint_presets_check[preset_str][slot_name] = is_check
    else
        local preset_str, check_str = string.match(ctrl_name, "^check_(%d)_(%d)$")
        g.easy_buff_settings.food_presets_check[preset_str][check_str] = is_check
    end
    Easy_buff_save_settings()
    Easy_buff_config_frame()
end
-- メシ屋
function Easy_buff_OPEN_FOOD_TABLE_UI(my_frame, my_msg)
    if g.settings.easy_buff.use == 0 then
        return
    end
    local group_name, sell_type, handle, seller_cid, shared = g.get_event_args(my_msg)
    local foodtable_ui = ui.GetFrame("foodtable_ui")
    local actor = world.GetActor(handle)
    local apc = actor:GetPCApc()
    local aid = apc:GetAID()
    local info = session.party.GetPartyMemberInfoByAID(PARTY_GUILD, aid)
    if not info and shared == 1 then
        local msg = g.lang == "Japanese" and "ギルドメンバーのみに食事提供のお店です" or
                        "This shop provides food exclusively to guild members"
        ui.SysMsg(msg)
        foodtable_ui:ShowWindow(0)
        return
    end
    local x = 300
    local y = 60
    local btn
    local auto_preset = Easy_buff_auto_preset()
    for i = 1, 4 do
        local str_i = tostring(i)
        btn = foodtable_ui:CreateOrGetControl("button", "btn" .. i, x, y, 85, 30)
        AUTO_CAST(btn)
        btn:SetSkinName(i == auto_preset and "test_red_button" or "test_gray_button")
        local text = g.easy_buff_settings.food_presets_name[str_i] or "{ol}preset " .. i
        btn:SetText("{ol}" .. text)
        btn:SetEventScript(ui.LBUTTONUP, "Easy_buff_clear_food_buff_timer")
        btn:SetEventScriptArgNumber(ui.LBUTTONUP, i)
        if btn:GetWidth() >= 85 then
            btn:Resize(85, 30)
        end
        if i == 1 then
            x = x + 80
        elseif i == 2 then
            x = 300
            y = 90
        elseif i == 3 then
            x = x + 80
        end
    end
    g.vlog("easy_buff: メシ屋を開いた 自動実行=%d first=%s (cid=%s)", auto_preset, tostring(g.easy_buff_first),
        tostring(g.cid))
    if auto_preset ~= 0 and g.easy_buff_first then
        Easy_buff_clear_food_buff_timer(nil, btn, "", auto_preset)
        g.easy_buff_first = false
    end
end

-- preset はどのプリセットを食べるか。ボタンからは押したボタンの番号が来る
-- (以前は自動実行のプリセットを選んでいると、どのボタンを押してもそちらを食べていた)
function Easy_buff_clear_food_buff_timer(frame, btn, str, preset)
    g.easy_buff_run_preset = preset
    btn:RunUpdateScript("Easy_buff_clear_food_buff", 0.1)
end

function Easy_buff_clear_food_buff(btn)
    local food_buffs = {4021, 4022, 4023, 4024, 4087, 4136}
    local my_handle = session.GetMyHandle()
    for _, buff_id in ipairs(food_buffs) do
        local buff = info.GetBuff(my_handle, buff_id)
        if buff then
            packet.ReqRemoveBuff(buff_id)
            return 1
        end
    end
    btn:StopUpdateScript("Easy_buff_clear_food_buff")
    Easy_buff_set_food_buff(btn)
    return 0
end

function Easy_buff_set_food_buff(btn)
    local preset_index_str = tostring(g.easy_buff_run_preset)
    if not btn or not g.easy_buff_settings.food_presets_check[preset_index_str] then
        return
    end
    g.vlog("easy_buff: プリセット %s を食べる", preset_index_str)
    g.easy_buff_temp_food = {}
    for key, value in pairs(g.easy_buff_settings.food_presets_check[preset_index_str]) do
        if value == 1 then
            local num_key = tonumber(key)
            if num_key then
                table.insert(g.easy_buff_temp_food, num_key - 1)
            end
        end
    end
    table.sort(g.easy_buff_temp_food, function(a, b)
        return a > b
    end)
    if #g.easy_buff_temp_food > 0 then
        Easy_buff_eat_food(btn)
        btn:RunUpdateScript("Easy_buff_eat_food", 0.6)
    end
end

function Easy_buff_eat_food(btn)
    local foodtable_ui = ui.GetFrame("foodtable_ui")
    if foodtable_ui:IsVisible() == 0 then
        g.easy_buff_first = true
        return 0
    end
    local handle = foodtable_ui:GetUserIValue("HANDLE")
    local sell_type = foodtable_ui:GetUserIValue("SELLTYPE")
    if #g.easy_buff_temp_food > 0 then
        session.autoSeller.Buy(handle, g.easy_buff_temp_food[#g.easy_buff_temp_food], 1, sell_type)
        table.remove(g.easy_buff_temp_food, #g.easy_buff_temp_food)
        imcSound.PlaySoundEvent('system_craft_potion_succes')
        return 1
    else
        g.easy_buff_first = true
        foodtable_ui:ShowWindow(0)
        return 0
    end
end
-- バフ屋
function Easy_buff_TARGET_BUFF_AUTOSELL_LIST(my_frame, my_msg)
    if g.settings.easy_buff.use == 0 then
        return
    end
    local group_name, sell_type, handle = g.get_event_args(my_msg)
    if sell_type ~= 0 then
        return
    end
    local buffseller_target = ui.GetFrame("buffseller_target")
    if buffseller_target:HaveUpdateScript("Easy_buff_buy_buffs_update") == true or
        buffseller_target:HaveUpdateScript("Easy_buff_end_process") == true then
        return
    end
    local item_count = session.autoSeller.GetCount(group_name)
    for i = 0, item_count - 1 do
        local item_info = session.autoSeller.GetByIndex(group_name, i)
        if not item_info then
            ui.SysMsg(g.lang == "Japanese" and "お店のバフアイテムが足りません" or
                          "Insufficient buff items at the shop")
            return
        end
    end
    local my_handle = session.GetMyHandle()
    local buff_ids_to_check = {358, 359, 360, 370}
    local needs_rebuff = false
    for _, buff_id in ipairs(buff_ids_to_check) do
        local buff = info.GetBuff(my_handle, buff_id)
        -- バフが無い、または残り時間が60分以下なら購入対象
        if not buff then
            needs_rebuff = true
            break
        end
        if buff.time <= 3600000 then -- 60分 (ms)
            needs_rebuff = true
            break
        end
    end
    if needs_rebuff then
        Easy_buff_buy_buffs(handle)
        return
    else
        if g.easy_buff_settings.confirm_check == 1 then
            local msg_text = g.lang == "Japanese" and "{#FFFFFF}{ol}バフをかけ直しますか？" or
                                 "{#FFFFFF}{ol}Do you want to reapply the buff?"
            local yes_script = string.format("Easy_buff_buy_buffs(%d)", handle)
            local no_script = "Easy_buff_end_process()"
            ui.MsgBox(msg_text, yes_script, no_script)
        else
            Easy_buff_buy_buffs(handle)
            return
        end
    end
end

function Easy_buff_buy_buffs(handle)
    local buffseller_target = ui.GetFrame("buffseller_target")
    buffseller_target:SetUserValue("HANDLE", handle)
    buffseller_target:SetUserValue("BUFF_INDEX", 0)
    buffseller_target:SetUserValue("RETRY_COUNT", 0)
    buffseller_target:RunUpdateScript("Easy_buff_buy_buffs_update", 0.6)
end

function Easy_buff_buy_buffs_update(buffseller_target)
    local buff_index = buffseller_target:GetUserIValue("BUFF_INDEX")
    if buff_index <= 3 then
        local handle = buffseller_target:GetUserIValue("HANDLE")
        session.autoSeller.Buy(handle, buff_index, 1, 0)
        buffseller_target:SetUserValue("BUFF_INDEX", buff_index + 1)
        return 1
    else
        buffseller_target:RunUpdateScript("Easy_buff_end_process", 0.6)
        return 0
    end
end

function Easy_buff_end_process(buffseller_target)
    if not buffseller_target then
        buffseller_target = ui.GetFrame("buffseller_target")
    end
    local my_handle = session.GetMyHandle()
    local buff_check = {358, 359, 360, 370}
    local retry_count = buffseller_target:GetUserIValue("RETRY_COUNT")
    for i, buff_id in ipairs(buff_check) do
        local buff = info.GetBuff(my_handle, buff_id)
        if not buff or buff.time <= 3540000 then
            if retry_count < 3 then
                local handle = buffseller_target:GetUserIValue("HANDLE")
                session.autoSeller.Buy(handle, i - 1, 1, 0)
                buffseller_target:SetUserValue("RETRY_COUNT", retry_count + 1)
                return 1 -- 再チェックへ
            else
                ui.SysMsg(g.lang == "Japanese" and "バフの購入に失敗しました" or "Failed to purchase buff")
                break
            end
        end
    end
    buffseller_target:ShowWindow(0)
    return 0
end
-- 修理
function Easy_buff_ITEMBUFF_REPAIR_UI_COMMON(my_frame, my_msg)
    if g.settings.easy_buff.use == 0 then
        return
    end
    local itembuffrepair = ui.GetFrame("itembuffrepair")
    session.ResetItemList()
    local handle = itembuffrepair:GetUserValue("HANDLE")
    local skill_name = itembuffrepair:GetUserValue("SKILLNAME")
    local slot_set = GET_CHILD_RECURSIVELY(itembuffrepair, "slotlist", "ui::CSlotSet")
    local slot_count = slot_set:GetSlotCount()
    local cheapest = nil
    local price = 0
    local iesid = ""
    for i = 0, slot_count - 1 do
        local slot = slot_set:GetSlotByIndex(i)
        if slot:GetIcon() then
            local icon = slot:GetIcon()
            local icon_info = icon:GetInfo()
            local inv_item = GET_ITEM_BY_GUID(icon_info:GetIESID())
            if inv_item then
                local item_obj = GetIES(inv_item:GetObject())
                local need_item, need_count = ITEMBUFF_NEEDITEM_Squire_Repair(GetMyPCObject(), item_obj)
                if need_count < price or price == 0 then
                    cheapest = slot
                    price = need_count
                    iesid = icon_info:GetIESID()
                end
            end
        end
    end
    if cheapest then
        session.AddItemID(iesid)
        local auto_sell_index = 2 -- 元コードのAUTO_SELL_SQUIRE_BUFFが2
        session.autoSeller.BuyItems(handle, auto_sell_index, session.GetItemIDList(), skill_name)
        imcSound.PlaySoundEvent('system_craft_potion_succes')
    end
    itembuffrepair:RunUpdateScript("Easy_buff_repair_msg", 1.5)
end

function Easy_buff_repair_msg(itembuffrepair)
    local repair_buffs = {3127, 3128, 3129} -- 3127魔法 3128機敏 3129防御
    local my_handle = session.GetMyHandle()
    for _, buff_id in ipairs(repair_buffs) do
        local buff = info.GetBuff(my_handle, buff_id)
        if buff then
            local format_string
            if g.lang == "Japanese" then
                format_string = "%s バフを有効化"
            else
                format_string = "%s Activate Buff"
            end
            local buff_cls = GetClassByType("Buff", buff_id)
            local msg = string.format(format_string, buff_cls.Name)
            imcAddOn.BroadMsg("NOTICE_Dm_Bell", msg, 2.5)
            CHAT_SYSTEM(msg)
        end
    end
    if g.easy_buff_settings.repair_check == 1 then
        itembuffrepair:ShowWindow(0)
        local inventory = ui.GetFrame("inventory")
        if inventory:IsVisible() == 1 then
            ui.ToggleFrame('inventory')
        end
    end
end
-- メンテ処理
function Easy_buff_SQUIRE_BUFF_EQUIP_CTRL(my_frame, my_msg)
    if g.settings.easy_buff.use == 0 then
        return
    end
    local itembuffopen = ui.GetFrame("itembuffopen")
    itembuffopen:StopUpdateScript("Easy_buff_squire_frame_close")
    itembuffopen:RunUpdateScript("Easy_buff_squire_buff_equip_ctrl_update", 0.5)
    return
end

function Easy_buff_squire_buff_equip_ctrl_update(itembuffopen)
    if session.GetMyHandle() == itembuffopen:GetUserIValue("HANDLE") then
        return
    end
    local maint_preset = Easy_buff_maint_preset()
    g.vlog("easy_buff: 他人の装備メンテナンスを開いた プリセット=%d (cid=%s)", maint_preset, tostring(g.cid))
    if maint_preset == 0 then
        -- 自動実行のプリセットを選んでいない(メシ屋で全部外したときと同じ)。素の窓には触らない
        itembuffopen:StopUpdateScript("Easy_buff_squire_buff_equip_ctrl_update")
        return 0
    end
    local close = GET_CHILD_RECURSIVELY(itembuffopen, 'close')
    AUTO_CAST(close)
    close:SetEventScript(ui.LBUTTONUP, "Easy_buff_squire_timestop_frame_close")
    -- 「すべて選択」ではなく、このキャラで選んだプリセットの部位だけにチェックを入れる。
    -- 1 つずつの選択は素の SQUIRE_BUFF_EQUIP_SELECT_ALL と同じ呼び方(by_checkall = true で費用の再計算は最後に 1 回)
    local listed, selected = 0, 0
    for _, slot_name in ipairs(g.easy_buff_maint_slots) do
        local ctrlset = GET_CHILD_RECURSIVELY(itembuffopen, 'ITEMBUFF_CTRL_' .. slot_name)
        if ctrlset then
            listed = listed + 1
            local checkbox = GET_CHILD(ctrlset, 'checkbox')
            AUTO_CAST(checkbox)
            local check = Easy_buff_maint_selected(slot_name)
            checkbox:SetCheck(check)
            SQUIRE_BUFF_EQUIP_SELECT(ctrlset, checkbox, '', 0, true)
            -- 素の SQUIRE_BUFF_EQUIP_SELECT は装備が外れていればチェックを戻すので、結果の方を数える
            if checkbox:IsChecked() == 1 then
                selected = selected + 1
            end
        end
    end
    SQUIRE_BUFF_COST_UPDATE(itembuffopen)
    local checkall = GET_CHILD_RECURSIVELY(itembuffopen, 'checkall')
    AUTO_CAST(checkall)
    checkall:SetCheck((listed > 0 and selected == listed) and 1 or 0)
    g.vlog("easy_buff: 装備メンテナンス 対象 %d 部位のうち %d 部位を選択(cid=%s)", listed, selected, tostring(g.cid))
    itembuffopen:StopUpdateScript("Easy_buff_squire_buff_equip_ctrl_update")
    if selected == 0 then
        local any_on = false
        for _, slot_name in ipairs(g.easy_buff_maint_slots) do
            if Easy_buff_maint_selected(slot_name) == 1 then
                any_on = true
            end
        end
        if not any_on then
            -- 選んだプリセットの部位が全部外れている = 自動実行しない
            return 0
        end
        -- 実行すると素が「アイテムを選択してください」の MsgBox を出すので、押さずに知らせるだけにする
        ui.SysMsg(g.lang == "Japanese" and "{ol}Easy Buff: 装備メンテナンスで選ぶ部位がこの店にありません" or
                      "{ol}Easy Buff: none of the selected slots can be maintained here")
        return 0
    end
    local btn_excute = GET_CHILD_RECURSIVELY(itembuffopen, "btn_excute")
    SQUIRE_BUFF_EXCUTE(itembuffopen, btn_excute)
    local str = g.lang == "Japanese" and
                    "{ol}装備メンテナンス自動付与中{nl}フレームを閉じればキャンセルします" or
                    "{ol}Equipment maintenance automatic grant is in progress{nl}Canceled when frame is closed"
    ui.SysMsg(str)
    itembuffopen:RunUpdateScript("Easy_buff_squire_frame_close", 5.5)
end

function Easy_buff_squire_timestop_frame_close()
    packet.StopTimeAction(1)
    ui.CloseFrame("itembuffopen")
end

function Easy_buff_squire_frame_close(itembuffopen)
    itembuffopen:ShowWindow(0)
    return 0
end
-- easy_buff ここまで

