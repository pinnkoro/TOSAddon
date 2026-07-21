-- tavern_of_soul ここから
function tavern_of_soul_on_init()
    if g.settings.tavern_of_soul.use == 0 then
        ui.DestroyFrame(addon_name_lower .. "tos_btn")
        return
    end
    Tavern_of_soul_frame_init()
end

function Tavern_of_soul_frame_init()
    local tos_btn = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "tos_btn", 0, 0, 0, 0)
    AUTO_CAST(tos_btn)
    tos_btn:SetSkinName("None")
    tos_btn:Resize(30, 30)
    tos_btn:SetLayerLevel(30)
    tos_btn:SetGravity(ui.RIGHT, ui.TOP)
    local rect = tos_btn:GetMargin()
    tos_btn:SetMargin(rect.left, rect.top - 60, rect.right + 277, rect.bottom)
    tos_btn:SetTitleBarSkin("None")
    local open_btn = tos_btn:CreateOrGetControl('button', 'open_btn', 0, 0, 30, 30)
    AUTO_CAST(open_btn)
    open_btn:SetText("{ol}{s20}D")
    open_btn:SetTextTooltip("{ol}Tavern of Soul")
    open_btn:SetEventScript(ui.LBUTTONUP, "Tavern_of_soul_main_frame_init")
    tos_btn:ShowWindow(1)
end

function Tavern_of_soul_main_frame_init()
    if g.settings.tavern_of_soul.use == 0 then
        return
    end
    local tos_main = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "tos_main", 0, 0, 0, 0)
    AUTO_CAST(tos_main)
    tos_main:RemoveAllChild()
    local map_frame = ui.GetFrame("map")
    local width = map_frame:GetWidth()
    local height = map_frame:GetHeight()
    tos_main:SetSkinName("test_frame_low")
    tos_main:Resize(300, 120)
    tos_main:SetLayerLevel(999)
    tos_main:SetPos(500, 100)
    g.tos_mode = g.tos_mode or "Item"
    local title = tos_main:CreateOrGetControl('richtext', 'title', 10, 10, 100, 30)
    title:SetText("{ol}Tavern of Soul")
    local close_btn = tos_main:CreateOrGetControl('button', 'close_btn', 0, 0, 30, 30)
    AUTO_CAST(close_btn)
    close_btn:SetImage("testclose_button")
    close_btn:SetGravity(ui.RIGHT, ui.TOP)
    close_btn:SetEventScript(ui.LBUTTONUP, "Tavern_of_soul_frame_close")
    local search_edit = tos_main:CreateOrGetControl("edit", "search_edit", 10, 35, 280, 40)
    AUTO_CAST(search_edit)
    search_edit:SetFontName("white_18_ol")
    search_edit:SetTextAlign("left", "center")
    search_edit:SetSkinName("inventory_serch")
    search_edit:SetEventScript(ui.ENTERKEY, "Tavern_of_soul_search_enter")
    search_edit:Focus()
    local modes = {"Item", "Buff", "Skill", "Monster"}
    local btn_w = 65
    local btn_x = 10
    for i, mode in ipairs(modes) do
        local btn = tos_main:CreateOrGetControl("button", "btn_" .. mode, btn_x, 80, btn_w, 30)
        AUTO_CAST(btn)
        btn:SetText("{ol}{s14}" .. mode)
        if mode == g.tos_mode then
            btn:SetSkinName("test_red_button")
        else
            btn:SetSkinName("test_gray_button")
        end
        btn:SetEventScript(ui.LBUTTONUP, "Tavern_of_soul_mode_click")
        btn:SetEventScriptArgString(ui.LBUTTONUP, mode)
        btn_x = btn_x + btn_w + 5
    end
    local gbox = tos_main:CreateOrGetControl("groupbox", "gbox", 10, 120, 280, 30)
    AUTO_CAST(gbox)
    gbox:SetSkinName("bg")
    gbox:ShowWindow(0)
    tos_main:ShowWindow(1)
end

function Tavern_of_soul_search_enter(parent, ctrl)
    local tos_main = parent:GetTopParentFrame()
    local mode = g.tos_mode or "Item"
    Tavern_of_soul_get_data(tos_main, ctrl, mode)
end

function Tavern_of_soul_mode_click(parent, ctrl, mode, num)
    local tos_main = parent:GetTopParentFrame()
    local search_edit = GET_CHILD(tos_main, "search_edit")
    g.tos_mode = mode
    local modes = {"Item", "Buff", "Skill", "Monster"}
    for _, m in ipairs(modes) do
        local btn = GET_CHILD(tos_main, "btn_" .. m)
        if btn then
            if m == mode then
                btn:SetSkinName("test_red_button")
            else
                btn:SetSkinName("test_gray_button")
            end
        end
    end
    search_edit:SetText("")
    local gbox = GET_CHILD(tos_main, "gbox")
    gbox:RemoveAllChild()
    gbox:ShowWindow(0)
    tos_main:Resize(300, 120)
    local map_frame = ui.GetFrame("map")
    local width = map_frame:GetWidth()
    tos_main:SetPos(500, 100)
    search_edit:Focus()
end

function Tavern_of_soul_get_data(tos_main, search_edit, mode)
    if not mode or mode == "" then
        mode = "Item"
    end
    local clslist, cnt = GetClassList(mode)
    local edit_text = search_edit:GetText()
    if tos_main:GetChild("gbox") then
        tos_main:RemoveChild("gbox")
    end
    local gbox = tos_main:CreateOrGetControl("groupbox", "gbox", 10, 120, 280, 30)
    AUTO_CAST(gbox)
    gbox:SetSkinName("bg")
    gbox:ShowWindow(1)
    local min_width = 300
    local x = min_width
    local index = 0
    for i = 0, cnt - 1 do
        local cls = GetClassByIndexFromList(clslist, i)
        local raw_name = TryGetProp(cls, "Name", "None")
        if raw_name ~= "None" then
            local name = dictionary.ReplaceDicIDInCompStr(raw_name)
            if string.find(name, edit_text, 1, true) then
                local icon_name = "None"
                if mode == "Buff" then
                    icon_name = GET_BUFF_ICON_NAME(cls)
                else
                    icon_name = TryGetProp(cls, "Icon", "None")
                end
                if icon_name ~= "None" and icon_name ~= "ui_CreateMonster" then
                    --[[if icon_name ~= "None" and icon_name ~= "" and icon_name ~= "ui_CreateMonster" and icon_name ~=
                    "icon_item_nothing" then]]
                    local icon_picture = gbox:CreateOrGetControl('picture', "icon_picture" .. index, 10, index * 30, 25,
                        25)
                    AUTO_CAST(icon_picture)
                    local status, err = pcall(function()
                        if mode == "Skill" then
                            if not string.find(icon_name, "icon_") then
                                icon_name = "icon_" .. icon_name
                            end
                        end
                        icon_picture:SetImage(icon_name)
                    end)
                    if not status then
                        icon_picture:SetImage("question_mark")
                    end
                    icon_picture:SetEnableStretch(1)
                    local cls_id = cls.ClassID
                    local cls_name = cls.ClassName
                    local text = gbox:CreateOrGetControl('richtext', 'text' .. index, 40, index * 30 + 5, 20, 20)
                    text:SetText("{ol}( " .. cls_id .. " ) {#FF0000}" .. name .. "{/}{/}{ol} ( " .. cls_name .. " )")
                    if x < text:GetWidth() + 80 then
                        x = text:GetWidth() + 80
                    end
                    index = index + 1
                end
            end
        end
    end
    if index == 0 then
        tos_main:Resize(min_width, 120)
        gbox:ShowWindow(0)
    else
        local content_height = index * 30
        local map_frame = ui.GetFrame("map")
        local max_height = map_frame:GetHeight() - 150
        if max_height > 900 then
            max_height = 900
        end
        local frame_height = 120 + content_height + 20
        if frame_height > max_height then
            frame_height = max_height
        end
        if frame_height < 160 then
            frame_height = 160
        end
        tos_main:Resize(x, frame_height)
        gbox:Resize(x - 20, frame_height - 130)
        gbox:ShowWindow(1)
        gbox:SetScrollPos(0)
    end
end

function Tavern_of_soul_frame_close(frame, ctrl)
    ui.DestroyFrame(frame:GetName())
end
-- tavern_of_soul ここまで

