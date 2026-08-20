-- Addons Menu のショートカットに使うアイコンを選ぶウィンドウ。
--
-- **クライアントにある UI 画像の一覧は Lua から列挙できない**(画像名は ui.ipf の xml に
-- 定義されていて、実行時に舐める手段が無い)。そのため選び方をタブで 3 つ用意する。
--
--   定型     … こちらで用意した候補。**このリポジトリのどこかで実際に使っている名前**だけを
--              並べてある。実在しない名前を書いてもエラーにはならず空白になるだけなので、
--              候補を足すときは必ず使用実績のある名前にすること
--   スキル   … GetClassList("Skill") の Icon から選ぶ。数千種類あるので事実上何でも選べる。
--              **全件走査なので打鍵検索にはしない**(CLAUDE.md の検索欄の節。空文字で
--              全件に当たる検索は g.setup_enter_search を使う)
--   直接入力 … 画像名を直接打つ。実在しない名前は空白になるだけなので、プレビューで
--              確かめられるようにしてある
--
-- 選んだ結果は g.menu_shortcut_set(key, "icon", name) へ書く。反映は
-- addons_menu_refresh_open(開いているメニュー)と設定画面の組み立て直し。
--
-- **このファイルは読み込み時ガードの外**(core/90_addons_menu.lua と同じ)。
-- 本家が同居していても設定画面は開けるので、そこから呼ばれるここも定義しておく必要がある。
local ICON_PICKER_FRAME = "addons_menu_icon_picker"
local ICON_PICKER_TABS = {{
    key = "preset",
    ja = "定型",
    etc = "Presets"
}, {
    key = "skill",
    ja = "スキル",
    etc = "Skills"
}, {
    key = "manual",
    ja = "直接入力",
    etc = "By name"
}}

-- 定型タブの候補。**実在を確かめてある名前だけ**を並べること(冒頭のコメント参照)。
local ICON_PICKER_PRESETS = {"sysmenu_sys", "sysmenu_inv", "sysmenu_skill", "sysmenu_coll", "sysmenu_jal",
                             "config_button_normal", "calendar_button_normal", "barrack_button_normal",
                             "market_shortcut_btn02", "compen_btn", "friend_party", "btn_partyshare", "chat_color",
                             "questmap", "questinfo_return", "quest_detail_pic2", "indun_season_tap",
                             "worldmap2_token_gold", "inven_s", "inven_lock2", "icon_item_silver",
                             "icon_item_ancient_card", "icon_item_box", "icon_fullscreen_menu_letica",
                             "icon_fullscreen_menu_equipment_processing", "equipment_info_btn_mark2", "monsterbtn_image",
                             "monster_card_starmark", "mon_legendstar", "star_mark", "question_mark", "unique_card",
                             "legend_card", "rare_card", "normal_card", "goddess_shop_btn", "goddess2_shop_btn",
                             "goddess3_shop_btn", "goddess4_shop_btn", "goddess5_shop_btn", "pvpmine_shop_btn_total",
                             "alch_gemlos_arrow"}

-- スキルタブで一度に作るアイコンの上限。**上限を黙って切らないこと**なので、
-- 打ち切ったときは画面にもその旨を出す。
local ICON_PICKER_SKILL_LIMIT = 200

local ICON_PICKER_W = 470
local ICON_PICKER_H = 430
local ICON_PICKER_TAB_H = 72 -- タブの行 + 対象の名前

local function icon_picker_ml(ja, etc)
    return (_G["norisan"]["MENU"].lang == "Japanese") and ja or etc
end

local function icon_picker_tab()
    local tab = g.icon_picker_tab
    for _, def in ipairs(ICON_PICKER_TABS) do
        if def.key == tab then
            return tab
        end
    end
    return "preset"
end

-- 候補 1 つ分のボタン。押すと決定する。
local function icon_picker_cell(parent, name, image, x, y, size)
    local btn = parent:CreateOrGetControl("picture", name, x, y, size, size)
    AUTO_CAST(btn)
    btn:SetImage(image)
    btn:SetEnableStretch(1)
    btn:EnableHitTest(1)
    btn:SetTextTooltip("{ol}" .. image)
    btn:SetEventScript(ui.LBUTTONUP, "addons_menu_icon_picker_pick")
    btn:SetEventScriptArgString(ui.LBUTTONUP, image)
    return btn
end

-- 候補を格子に並べる。定型タブとスキルタブで同じ見た目にしたいので共通化する。
local function icon_picker_fill_grid(gb, images, prefix, width)
    local size, pitch = 40, 46
    local per_row = math.max(1, math.floor((width - 20) / pitch))
    for idx, image in ipairs(images) do
        local col = (idx - 1) % per_row
        local row = math.floor((idx - 1) / per_row)
        icon_picker_cell(gb, prefix .. idx, image, 10 + col * pitch, 8 + row * pitch, size)
    end
    return math.ceil(#images / per_row)
end

local function icon_picker_build_preset(body, w, h)
    local gb = body:CreateOrGetControl("groupbox", "icon_gb", 5, 5, w - 10, h - 10)
    AUTO_CAST(gb)
    gb:SetSkinName("bg")
    gb:RemoveAllChild()
    gb:EnableScrollBar(1)
    icon_picker_fill_grid(gb, ICON_PICKER_PRESETS, "preset_", w - 10)
    pcall(function()
        gb:InvalidateScrollBar()
    end)
end

-- スキルアイコンの検索。**全件走査なので Enter / 虫眼鏡でだけ走らせる**
-- (空文字だと string.find が必ず真になり、数千件を毎打鍵で組み立てることになる)。
-- 検索語は ctrl:GetText() ではなく検索欄を名前で引いて読む(虫眼鏡ボタンからも来るため)。
function _G.addons_menu_icon_search(frame, ctrl, str, num)
    local picker = ui.GetFrame(ICON_PICKER_FRAME)
    if not picker then
        return
    end
    local edit = GET_CHILD_RECURSIVELY(picker, "icon_search_edit")
    g.icon_picker_query = edit and edit:GetText() or ""
    -- **検索欄ごと作り直さないこと**(CLAUDE.md の検索欄の節)。作り直すと入力位置と
    -- 文字が消え、フォーカスを戻すと今度は ESC の 1 回目を食う。結果の枠だけ入れ替える。
    _G.addons_menu_icon_fill_results(picker)
end

-- 「×」から呼ばれる。**空文字で検索し直すのではなく、検索前の姿へ戻す**
-- (結果を捨てて案内文だけの状態にする)。窓の位置や大きさはここで戻さないこと。
function _G.addons_menu_icon_search_clear(frame, ctrl, str, num)
    g.icon_picker_query = nil
    local picker = ui.GetFrame(ICON_PICKER_FRAME)
    if picker then
        _G.addons_menu_icon_fill_results(picker)
    end
end

-- 検索語に当たるスキルのアイコン名を集める。同じ絵が何度も並ばないよう名前で重複を落とす。
local function icon_picker_skill_images(query)
    local images = {}
    local seen = {}
    local truncated = false
    local cls_list, count = GetClassList("Skill")
    if not cls_list then
        return images, false
    end
    for i = 0, count - 1 do
        local cls = GetClassByIndexFromList(cls_list, i)
        local icon = cls and cls.Icon
        if icon and icon ~= "" then
            local name = dictionary.ReplaceDicIDInCompStr(cls.Name or "")
            if query == "" or (name and string.find(name, query, 1, true)) then
                local image = "icon_" .. icon
                if not seen[image] then
                    seen[image] = true
                    if #images >= ICON_PICKER_SKILL_LIMIT then
                        truncated = true
                        break
                    end
                    images[#images + 1] = image
                end
            end
        end
    end
    return images, truncated
end

-- 検索結果の枠だけを作り直す。**検索欄には触らない**(上のコメント参照)。
function _G.addons_menu_icon_fill_results(picker)
    local gb = GET_CHILD_RECURSIVELY(picker, "icon_gb")
    if not gb then
        return
    end
    AUTO_CAST(gb)
    gb:RemoveAllChild()
    local width = gb:GetWidth()
    if g.icon_picker_query == nil then
        local hint = gb:CreateOrGetControl("richtext", "hint", 12, 10, 10, 20)
        AUTO_CAST(hint)
        hint:SetText(icon_picker_ml("{ol}{#CCCCCC}スキル名を入れて Enter を押すと候補が出ます",
            "{ol}{#CCCCCC}Type a skill name and press Enter"))
        return
    end
    local images, truncated = icon_picker_skill_images(g.icon_picker_query)
    local rows = icon_picker_fill_grid(gb, images, "skill_", width)
    if #images == 0 then
        local empty = gb:CreateOrGetControl("richtext", "empty", 12, 10, 10, 20)
        AUTO_CAST(empty)
        empty:SetText(icon_picker_ml("{ol}{#FFA500}見つかりませんでした", "{ol}{#FFA500}No matching skills"))
    elseif truncated then
        -- 打ち切ったことを黙らない(全部出たと誤解させない)。
        local note = gb:CreateOrGetControl("richtext", "trunc", 12, 8 + rows * 46, 10, 20)
        AUTO_CAST(note)
        note:SetText(string.format(icon_picker_ml("{ol}{#FF9933}上限 %d 件まで表示しています。絞り込んでください",
            "{ol}{#FF9933}Showing the first %d icons. Narrow the search"), ICON_PICKER_SKILL_LIMIT))
    end
    g.vlog("icon_picker: スキル検索 %q 件数=%d 打ち切り=%s", tostring(g.icon_picker_query), #images,
        tostring(truncated))
    pcall(function()
        gb:InvalidateScrollBar()
    end)
end

local function icon_picker_build_skill(body, w, h)
    local search_edit = body:CreateOrGetControl("edit", "icon_search_edit", 10, 6, w - 60, 30)
    AUTO_CAST(search_edit)
    search_edit:SetFontName("white_16_ol")
    search_edit:SetTextAlign("left", "center")
    search_edit:SetSkinName("inventory_serch")
    search_edit:SetTextTooltip(icon_picker_ml("{ol}スキル名で検索(Enter で実行)",
        "{ol}Search skills by name (press Enter)"))
    search_edit:SetEventScript(ui.ENTERKEY, "addons_menu_icon_search")
    -- 全件を走査して当たったぶんだけ作る検索なので Enter 方式(CLAUDE.md の検索欄の節)。
    g.setup_enter_search(search_edit, "addons_menu_icon_search_clear")
    local search_btn = search_edit:CreateOrGetControl("button", "search_btn", 0, 0, 30, 30)
    AUTO_CAST(search_btn)
    search_btn:SetImage("inven_s")
    search_btn:SetGravity(ui.RIGHT, ui.TOP)
    search_btn:SetEventScript(ui.LBUTTONUP, "addons_menu_icon_search")
    -- タブを開き直したときに前の検索語を戻す。コードから文字を入れたので
    -- 「×」の出し入れと前回の検索語の記録も合わせる(g.search_clear_sync)。
    search_edit:SetText(g.icon_picker_query or "")
    g.search_clear_sync(search_edit)
    local gb = body:CreateOrGetControl("groupbox", "icon_gb", 5, 44, w - 10, h - 50)
    AUTO_CAST(gb)
    gb:SetSkinName("bg")
    gb:EnableScrollBar(1)
    _G.addons_menu_icon_fill_results(ui.GetFrame(ICON_PICKER_FRAME))
end

-- 直接入力タブ。入れた名前をその場で描いて、実在するかを目で確かめられるようにする
-- (存在しない名前でもエラーにはならず空白になるだけなので、これしか確かめる手段が無い)。
function _G.addons_menu_icon_manual_preview(frame, ctrl, str, num)
    local picker = ui.GetFrame(ICON_PICKER_FRAME)
    if not picker then
        return
    end
    local edit = GET_CHILD_RECURSIVELY(picker, "icon_manual_edit")
    g.icon_picker_manual = edit and edit:GetText() or ""
    -- ここも入力欄は作り直さない。プレビューの中身だけ入れ替える。
    local box = GET_CHILD_RECURSIVELY(picker, "manual_box")
    if box then
        AUTO_CAST(box)
        _G.addons_menu_icon_manual_fill(box)
    end
end

-- プレビューの中身。実在しない名前を入れても空になるだけなので、
-- 「出たら実在する」という確かめ方ができるようにしてある。
function _G.addons_menu_icon_manual_fill(box)
    box:RemoveAllChild()
    if g.icon_picker_manual and g.icon_picker_manual ~= "" then
        local pic = box:CreateOrGetControl("picture", "manual_pic", 20, 20, 80, 80)
        AUTO_CAST(pic)
        pic:SetImage(g.icon_picker_manual)
        pic:SetEnableStretch(1)
    end
end

function _G.addons_menu_icon_manual_apply(frame, ctrl, str, num)
    local picker = ui.GetFrame(ICON_PICKER_FRAME)
    if not picker then
        return
    end
    local edit = GET_CHILD_RECURSIVELY(picker, "icon_manual_edit")
    local name = edit and edit:GetText() or ""
    if name == "" then
        return
    end
    _G.addons_menu_icon_picker_pick(nil, nil, name)
end

local function icon_picker_build_manual(body, w, h)
    local label = body:CreateOrGetControl("richtext", "manual_label", 10, 8, 10, 20)
    AUTO_CAST(label)
    label:SetText(icon_picker_ml("{ol}画像名を入れて Enter(下に出れば実在します)",
        "{ol}Type an image name and press Enter (a preview means it exists)"))
    local edit = body:CreateOrGetControl("edit", "icon_manual_edit", 10, 36, w - 40, 30)
    AUTO_CAST(edit)
    edit:SetFontName("white_16_ol")
    edit:SetTextAlign("left", "center")
    edit:SetSkinName("inventory_serch")
    edit:SetEventScript(ui.ENTERKEY, "addons_menu_icon_manual_preview")
    edit:SetText(g.icon_picker_manual or "")
    local preview_box = body:CreateOrGetControl("groupbox", "manual_box", 10, 80, 120, 120)
    AUTO_CAST(preview_box)
    preview_box:SetSkinName("bg")
    _G.addons_menu_icon_manual_fill(preview_box)
    -- 決定ボタンは**右端に置かない**。ボタンの文字は枠より広く描かれることがあり、
    -- 右端に寄せると窓の外へはみ出して読めなくなる(実機で「このアイコンに…」で切れていた)。
    -- プレビューの下へ左詰めで置けば、窓幅や翻訳の長さに関係なく収まる。
    local apply = body:CreateOrGetControl("button", "manual_apply", 10, 212, 200, 30)
    AUTO_CAST(apply)
    apply:SetSkinName("test_pvp_btn")
    apply:SetText(icon_picker_ml("{ol}このアイコンにする", "{ol}Use this icon"))
    apply:SetTextTooltip(icon_picker_ml("{ol}入れた画像名をこの項目のアイコンにします",
        "{ol}Use the image name above for this item"))
    apply:SetEventScript(ui.LBUTTONUP, "addons_menu_icon_manual_apply")
end

-- 中身を作り直す。開いていなければ何もしない(この関数から窓は開かない)。
function _G.addons_menu_icon_picker_build()
    local picker = ui.GetFrame(ICON_PICKER_FRAME)
    if not picker then
        return
    end
    AUTO_CAST(picker)
    local tab = icon_picker_tab()
    local title = picker:CreateOrGetControl("richtext", "picker_title", 10, 44, 10, 20)
    AUTO_CAST(title)
    title:SetText(string.format(icon_picker_ml("{ol}{s16}{#FFCC33}%s{#FFFFFF} のアイコン",
        "{ol}{s16}Icon for {#FFCC33}%s"), tostring(g.icon_picker_label or "")))
    local close = picker:CreateOrGetControl("button", "picker_close", 0, 0, 30, 30)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "addons_menu_icon_picker_close")
    for i, def in ipairs(ICON_PICKER_TABS) do
        local btn = picker:CreateOrGetControl("button", "picker_tab_" .. def.key, 10 + (i - 1) * 100, 8, 96, 26)
        AUTO_CAST(btn)
        btn:SetSkinName(def.key == tab and "test_pvp_btn" or "test_gray_button")
        btn:SetText("{ol}{s16}" .. icon_picker_ml(def.ja, def.etc))
        btn:SetEventScript(ui.LBUTTONUP, "addons_menu_icon_picker_tab_ctrl")
        btn:SetEventScriptArgString(ui.LBUTTONUP, def.key)
    end
    local body = picker:CreateOrGetControl("groupbox", "picker_body", 0, ICON_PICKER_TAB_H, ICON_PICKER_W,
        ICON_PICKER_H - ICON_PICKER_TAB_H)
    AUTO_CAST(body)
    body:SetSkinName("None")
    body:EnableScrollBar(0)
    body:RemoveAllChild()
    local bw, bh = ICON_PICKER_W, ICON_PICKER_H - ICON_PICKER_TAB_H
    if tab == "skill" then
        icon_picker_build_skill(body, bw, bh)
    elseif tab == "manual" then
        icon_picker_build_manual(body, bw, bh)
    else
        icon_picker_build_preset(body, bw, bh)
    end
end

function _G.addons_menu_icon_picker_tab_ctrl(frame, ctrl, tab_key, num)
    g.icon_picker_tab = tab_key
    _G.addons_menu_icon_picker_build()
end

function _G.addons_menu_icon_picker_close()
    ui.DestroyFrame(ICON_PICKER_FRAME)
end

-- 選んだアイコンを保存して閉じる。
function _G.addons_menu_icon_picker_pick(frame, ctrl, image, num)
    local target = g.icon_picker_target
    if not (target and image and image ~= "") then
        return
    end
    if not g.menu_shortcut_set(target, "icon", image) then
        return
    end
    g.vlog("icon_picker: %s のアイコンを %s にした", tostring(target), tostring(image))
    _G.addons_menu_icon_picker_close()
    if type(_G["addons_menu_refresh_open"]) == "function" then
        pcall(_G["addons_menu_refresh_open"])
    end
    -- 設定画面のショートカットタブと、アドオン一覧の☆を出し直す(開いているときだけ)。
    local setting = ui.GetFrame("addons_menu_setting")
    if setting and setting:IsVisible() == 1 and type(_G["addons_menu_setting_tab_ctrl"]) == "function" then
        pcall(_G["addons_menu_setting_tab_ctrl"], setting, nil, g.addons_menu_setting_tab or "shortcut", 0)
    end
    ui.SysMsg(icon_picker_ml("{ol}アイコンを変更しました", "{ol}Icon changed"))
end

-- 入口。target は g.menu_shortcut_key で作ったキー、label は画面に出す名前。
function _G.addons_menu_icon_picker_open(target, label)
    g.icon_picker_target = target
    g.icon_picker_label = label
    -- 検索と直接入力の入力内容は対象ごとに持ち越さない(前の対象の残りが出ると紛らわしい)。
    g.icon_picker_query = nil
    g.icon_picker_manual = nil
    -- 作り直したいので、残っていれば先に壊す。
    ui.DestroyFrame(ICON_PICKER_FRAME)
    -- ESC で消えない土台で作り、ESC は下の esc_register_destroy に任せる
    -- (× ボタンも DestroyFrame だけなので、閉じ方は同じになる)。
    local picker = g.create_persistent_frame(ICON_PICKER_FRAME)
    AUTO_CAST(picker)
    picker:RemoveAllChild()
    picker:SetSkinName("test_frame_low")
    picker:SetTitleBarSkin("None")
    picker:Resize(ICON_PICKER_W, ICON_PICKER_H)
    picker:SetLayerLevel(999)
    picker:EnableHitTest(1)
    picker:EnableHittestFrame(1)
    picker:EnableMove(1)
    -- 設定画面の隣に出す。はみ出す側には置かない(設定画面と同じ考え方)。
    local map_ui = ui.GetFrame("map")
    local screen_w = (map_ui and map_ui:GetWidth()) or 1920
    local screen_h = (map_ui and map_ui:GetHeight()) or 1080
    local setting = ui.GetFrame("addons_menu_setting")
    local base_x = setting and setting:GetX() or math.floor(screen_w / 2)
    local base_y = setting and setting:GetY() or math.floor(screen_h / 4)
    local pos_x = base_x - ICON_PICKER_W - 10
    if pos_x < 0 then
        pos_x = base_x + ((setting and setting:GetWidth()) or 0) + 10
    end
    if pos_x + ICON_PICKER_W > screen_w then
        pos_x = screen_w - ICON_PICKER_W
    end
    if pos_x < 0 then
        pos_x = 0
    end
    local pos_y = base_y
    if pos_y + ICON_PICKER_H > screen_h then
        pos_y = screen_h - ICON_PICKER_H
    end
    if pos_y < 0 then
        pos_y = 0
    end
    picker:SetPos(pos_x, pos_y)
    picker:ShowWindow(1)
    _G.addons_menu_icon_picker_build()
    -- **開いた直後に検索欄へ Focus() しないこと。** 入力欄にフォーカスがあると ESC の
    -- 1 回目が「入力欄から抜ける」に使われ、窓が閉じない(CLAUDE.md の ESC の節)。
    g.esc_register_destroy(ICON_PICKER_FRAME)
    g.vlog("icon_picker: 開いた target=%s 位置=%d,%d", tostring(target), pos_x, pos_y)
end
