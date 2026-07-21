-- Instant CC ここから
g.instant_cc = {
    retry = nil,
    do_cc = nil,
    layer = 1
}
function Instant_cc_save_settings()
    g.save_json(g.instant_cc_path, g.instant_cc_settings)
end

function Instant_cc_load_settings()
    g.instant_cc_path = string.format("../addons/%s/%s/instant_cc.json", addon_name_lower, g.active_id)
    local changed = false
    local settings = g.load_json(g.instant_cc_path)
    if not settings then
        settings = {
            characters = {},
            per_barracks = false
        }
        changed = true
    end
    g.instant_cc_settings = settings
    if changed then
        Instant_cc_save_settings()
    end
end

function instant_cc_on_init()
    if not g.instant_cc_settings then
        Instant_cc_load_settings()
    end
    g.instant_cc.do_cc = nil
    g.instant_cc.retry = nil
    _G["norisan"] = _G["norisan"] or {}
    _G["norisan"]["HOOKS"] = _G["norisan"]["HOOKS"] or {}
    if not _G["norisan"]["HOOKS"]["BARRACK_START_FRAME_OPEN"] then
        _G["norisan"]["HOOKS"]["BARRACK_START_FRAME_OPEN"] = addon_name
        Instant_cc_hook_BARRACK_START_FRAME_OPEN()
    end
    if _G["BARRACK_CHARLIST_ON_INIT"] and _G["current_layer"] then
        g.instant_cc.layer = _G["current_layer"]
    end
    _G["INSTANTCC_ON_INIT"] = instant_cc_on_init
    if g.settings.instant_cc.use == 0 then
        _G["INSTANTCC_DO_CC"] = nil
        _G["INSTANTCC_APPS_TRY_MOVE_BARRACK"] = nil
        return
    else
        _G["INSTANTCC_DO_CC"] = Instant_cc_do_cc
        _G["INSTANTCC_APPS_TRY_MOVE_BARRACK"] = Instant_cc_APPS_TRY_MOVE_BARRACK_
    end
    local acc_info = session.barrack.GetMyAccount()
    local barrack_count = acc_info:GetBarrackPCCount() -- ゲーム起動直後はtonumber(0)
    Instant_cc_save_char_data(acc_info, barrack_count)
end

function Instant_cc_APPS_TRY_LEAVE_(type)
    if g.instant_cc.do_cc or g.get_map_type() ~= "City" then
        APPS_TRY_LEAVE("Barrack")
        return
    end
    Instant_cc_APPS_TRY_MOVE_BARRACK_(nil, nil, nil, 0)
end

function Instant_cc_APPS_TRY_MOVE_BARRACK_(frame, msg, str, barrack_layer)
    if barrack_layer == 0 then
        barrack_layer = g.instant_cc.layer
    end
    local context = ui.CreateContextMenu("instant_cc_select_character", "{ol}Barrack Charactor List", 0, 0, 0, 0)
    ui.AddContextMenuItem(context, "Return To Barrack", "Instant_cc_do_cc()")
    if not g.instant_cc_settings.per_barracks then
        for i = 1, #g.instant_cc_sorted_list do
            local info = g.instant_cc_sorted_list[i]
            local pc_name = info.name
            local job_cls = GetClassByType("Job", info.jobid)
            local job_name = GET_JOB_NAME(job_cls, info.gender)
            job_name = string.gsub(dic.getTranslatedStr(job_name), "{s18}", "")
            local str = "Lv" .. info.level .. " " .. pc_name .. " (" .. job_name .. ")          "
            ui.AddContextMenuItem(context, str, string.format("Instant_cc_do_cc('%s',%d)", info.cid, info.layer))
        end
    else
        ui.AddContextMenuItem(context, "Barrack 1",
            string.format("Instant_cc_APPS_TRY_MOVE_BARRACK_(nil, nil, nil, %d)", 1))
        ui.AddContextMenuItem(context, "Barrack 2",
            string.format("Instant_cc_APPS_TRY_MOVE_BARRACK_(nil, nil, nil, %d)", 2))
        ui.AddContextMenuItem(context, "Barrack 3",
            string.format("Instant_cc_APPS_TRY_MOVE_BARRACK_(nil, nil, nil, %d)", 3))
        for i = 1, #g.instant_cc_sorted_list do
            local info = g.instant_cc_sorted_list[i]
            local layer = info.layer
            if barrack_layer == layer then
                local pc_name = info.name
                local job_cls = GetClassByType("Job", info.jobid)
                local job_name = GET_JOB_NAME(job_cls, info.gender)
                job_name = string.gsub(dic.getTranslatedStr(job_name), "{s18}", "")
                local str = "Lv" .. info.level .. " " .. pc_name .. " (" .. job_name .. ")          "
                ui.AddContextMenuItem(context, str, string.format("Instant_cc_do_cc('%s',%d)", info.cid, info.layer))
            end
        end
    end
    ui.OpenContextMenu(context)
end

function Instant_cc_do_cc(cid, layer)
    if cid then
        g.instant_cc.do_cc = {
            cid = cid,
            layer = layer
        }
    end
    if Indun_list_viewer_CHECK_ALERT("Barrack") then
        return
    end
    APPS_TRY_LEAVE("Barrack")
end

function Instant_cc_settings_frame_init()
    local list_frame = ui.GetFrame(addon_name_lower .. "list_frame")
    local settings = ui.CreateNewFrame("chat_memberlist", addon_name_lower .. "instant_cc_settings")
    AUTO_CAST(settings)
    settings:SetPos(list_frame:GetX() + list_frame:GetWidth(), list_frame:GetY())
    settings:EnableHitTest(1)
    settings:SetLayerLevel(999)
    settings:SetSkinName("test_frame_low")
    local width = 0
    local title = settings:CreateOrGetControl("richtext", "title", 20, 10, 10, 30)
    AUTO_CAST(title)
    title:SetText("{#000000}{s20}instant CC Settings")
    width = width + 20 + title:GetWidth() + 40
    local close = settings:CreateOrGetControl("button", "close", 0, 0, 20, 20)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Instant_cc_settings_frame_close")
    local gb = settings:CreateOrGetControl("groupbox", "gb", 10, 40, 100, 100)
    AUTO_CAST(gb)
    gb:SetSkinName("bg")
    gb:RemoveAllChild()
    local per_barracks = gb:CreateOrGetControl("checkbox", "per_barracks", 10, 5, 100, 30)
    AUTO_CAST(per_barracks)
    per_barracks:SetText(g.lang == "Japanese" and "{ol}チェックするとバラックごとに表示" or
                             "{ol}Check to display per barracks")
    per_barracks:SetCheck(g.instant_cc_settings.per_barracks and 1 or 0)
    per_barracks:SetEventScript(ui.LBUTTONUP, "Instant_cc_setting")
    width = per_barracks:GetWidth() + 40
    settings:Resize(width, 90)
    gb:Resize(settings:GetWidth() - 20, 40)
    settings:ShowWindow(1)
end

function Instant_cc_settings_frame_close(frame)
    local frame_name = addon_name_lower .. "instant_cc_settings"
    ui.DestroyFrame(frame_name)
end

function Instant_cc_setting(frame, ctrl)
    local is_check = ctrl:IsChecked()
    if is_check == 1 then
        g.instant_cc_settings.per_barracks = true
    else
        g.instant_cc_settings.per_barracks = false
    end
    Instant_cc_save_settings()
end

function Instant_cc_save_char_data(acc_info, barrack_count)
    local characters = g.instant_cc_settings.characters
    local pc_count = acc_info:GetPCCount() -- 毎回同じレイヤーのキャラは順番を取得
    for i = 0, pc_count - 1 do
        local pc_info = acc_info:GetPCByIndex(i)
        if pc_info then
            local pc_cid = pc_info:GetCID()
            local pc_apc = pc_info:GetApc()
            if pc_apc then
                local pc_name = pc_apc:GetName()
                characters[pc_name] = {
                    name = pc_name,
                    layer = g.instant_cc.layer,
                    order = i,
                    jobid = (acc_info:GetByStrCID(pc_cid) and acc_info:GetByStrCID(pc_cid):GetRepID()) or
                        pc_apc:GetJob(),
                    gender = pc_apc:GetGender(),
                    level = pc_apc:GetLv(),
                    cid = pc_cid
                }
            end
        end
    end
    if barrack_count > 0 then -- ゲーム起動直後はカウント0なので、2回目以降動かす
        local barrack_chars = {}
        for i = 0, barrack_count - 1 do
            local pc_info = acc_info:GetBarrackPCByIndex(i)
            if pc_info then
                barrack_chars[pc_info:GetName()] = true
            end
        end
        local chars_to_delete = {}
        for char_name, _ in pairs(characters) do
            if not barrack_chars[char_name] then
                table.insert(chars_to_delete, char_name)
            end
        end
        if #chars_to_delete > 0 then
            for _, char_name in ipairs(chars_to_delete) do
                characters[char_name] = nil
            end
        end
    end
    Instant_cc_save_settings()
    Instant_cc_sort_char_data()
end

function Instant_cc_sort_char_data()
    g.instant_cc_sorted_list = {}
    for _, char_data in pairs(g.instant_cc_settings.characters) do
        table.insert(g.instant_cc_sorted_list, char_data)
    end
    local function dabble_sort(a, b)
        if a.layer == b.layer then
            return a.order < b.order
        else
            return a.layer < b.layer
        end
    end
    table.sort(g.instant_cc_sorted_list, dabble_sort)
end

function Instant_cc_hook_BARRACK_START_FRAME_OPEN()
    g.FUNCS = g.FUNCS or {}
    local origin_func_name = "BARRACK_START_FRAME_OPEN"
    if _G[origin_func_name] then
        if not g.FUNCS[origin_func_name] then
            g.FUNCS[origin_func_name] = _G[origin_func_name]
        end
        _G[origin_func_name] = Instant_cc_BARRACK_START_FRAME_OPEN
    end
end

function Instant_cc_BARRACK_START_FRAME_OPEN(...)
    local frame = select(1, ...)
    if not frame then
        return
    end
    local original_func = g.FUNCS["BARRACK_START_FRAME_OPEN"]
    local result
    if original_func then
        result = original_func(...)
    end
    local barrack_gamestart = ui.GetFrame("barrack_gamestart")
    local hidelogin = GET_CHILD_RECURSIVELY(barrack_gamestart, "hidelogin")
    hidelogin:SetCheck(1)
    if g.instant_cc.do_cc and not g.instant_cc.retry then
        g.instant_cc.retry = 0
        barrack_gamestart:RunUpdateScript("Instant_cc_start", 0.2)
    end
    return result
end

function Instant_cc_start()
    barrack.SelectBarrackLayer(g.instant_cc.do_cc.layer)
    barrack.SelectCharacterByCID(g.instant_cc.do_cc.cid)
    local barrack_gamestart = ui.GetFrame("barrack_gamestart")
    barrack_gamestart:StopUpdateScript("Instant_cc_to_game")
    barrack_gamestart:RunUpdateScript("Instant_cc_to_game", 0.2)
end

function Instant_cc_retry()
    g.instant_cc.retry = g.instant_cc.retry + 1
    if g.instant_cc.retry > #g.instant_cc_sorted_list then
        app.BarrackToLogin()
        ui.SysMsg(g.lang == "Japanese" and
                      "キャラクターの自動取得に失敗しました{nl}手動で選択してください" or
                      "Failed to automatically retrieve the character{nl}Please select manually")
        return
    end
    Instant_cc_start()
end

function Instant_cc_to_game(barrack_gamestart)
    local barrack_pc_info = barrack.GetBarrackPCInfoByCID(g.instant_cc.do_cc.cid)
    if not barrack_pc_info then
        Instant_cc_retry()
        return
    end
    local barrack_start_char = barrack.GetGameStartAccount()
    if not barrack_start_char or barrack_start_char:GetCID() ~= g.instant_cc.do_cc.cid then
        Instant_cc_retry()
        return
    end
    BARRACK_TO_GAME()
    return 0
end
-- Instant CC ここまで

