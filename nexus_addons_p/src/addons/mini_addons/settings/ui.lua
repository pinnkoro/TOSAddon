-- 表示言語に合わせた文言を返す（定義側は text_jp / text_kr / text_en を持つ）
local function localized_text(def)
    if g.lang == "Japanese" then
        return def.text_jp
    elseif g.lang == "kr" then
        return def.text_kr
    end
    return def.text_en
end

-- 検索の一致判定。表示言語だけでなく他言語の文言と設定名も対象にする
-- （英語名で覚えている人が居るのと、日本語版で "auto" などと打てるようにするため）。
-- string.find は第 4 引数 true でプレーン検索にする。記号を打たれてもパターンとして
-- 解釈されて落ちないようにするため。
local function setting_matches(setting, needle)
    if needle == "" then
        return true
    end
    local haystack = string.lower(setting.name .. " " .. (setting.text_jp or "") .. " " .. (setting.text_kr or "") ..
                                      " " .. (setting.text_en or ""))
    return string.find(haystack, needle, 1, true) ~= nil
end

-- .use を持つ入れ子の設定。チェック状態の読み出し先がここだけ 1 段深い
local NESTED_USE_SETTINGS = {
    cupole_portion = true,
    baubas_call = true,
    velnice = true,
    auto_zoom = true,
    event_shout = true
}

-- 設定 1 行（チェックボックスと、項目によっては隣に付く操作 UI）を作る。
-- 統合前はメイン画面とサブ画面にほぼ同じ処理が二重にあったので、ここへ寄せた。
-- 戻り値は行の右端 x。フレーム幅の算出に使う。
local function create_setting_row(gbox, setting, y)
    local check_value
    if NESTED_USE_SETTINGS[setting.name] then
        check_value = g.settings[setting.name] and g.settings[setting.name].use or 0
    else
        check_value = g.settings[setting.name] or 0
    end
    local checkbox = gbox:CreateOrGetControl("checkbox", setting.name, 10, y, 25, 25)
    AUTO_CAST(checkbox)
    checkbox:SetCheck(check_value)
    checkbox:SetEventScript(ui.LBUTTONUP, "Mini_addons_ISCHECK")
    checkbox:SetText("{ol}" .. localized_text(setting))
    local tooltip_text = g.lang == "Japanese" and "{ol}チェックすると有効化" or g.lang == "kr" and
                             "{ol}체크 시 활성화" or "{ol}Check to enable"
    checkbox:SetTextTooltip(tooltip_text)
    local text_width = checkbox:GetWidth()
    local right = 10 + text_width
    if setting.name == "baubas_call" then -- チェックボックスの隣に特殊なUIを追加する処理
        local baubas_call_btn = gbox:CreateOrGetControl("button", "baubas_call_btn", right + 15, y - 5, 50, 30)
        AUTO_CAST(baubas_call_btn)
        if g.settings.baubas_call.guild_notice == 0 or not g.settings.baubas_call.guild_notice then
            baubas_call_btn:SetText("{ol}{#FFFFFF}OFF")
            baubas_call_btn:SetSkinName("test_gray_button")
            -- 保存は「値がまだ無い」ときだけ。一覧は検索や折りたたみのたびに作り直されるので、
            -- 既に 0 のときも保存すると、何も変わっていないのに settings.json を書き続ける
            if not g.settings.baubas_call.guild_notice then
                g.settings.baubas_call.guild_notice = 0
                Mini_addons_save_settings()
            end
        else
            baubas_call_btn:SetText("{ol}{#FFFFFF}ON")
            baubas_call_btn:SetSkinName("test_red_button")
        end
        local btn_tooltip = g.lang == "Japanese" and "{ol}ギルドチャットへのお知らせ切替え" or g.lang == "kr" and
                                "{ol}길드 채팅으로 알림 전환" or "{ol}Notification switch to guild chat"
        baubas_call_btn:SetTextTooltip(btn_tooltip)
        baubas_call_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_baubas_call_switch")
        right = right + 15 + baubas_call_btn:GetWidth()
    elseif setting.name == "other_effect" or setting.name == "my_effect" or setting.name == "boss_effect" then
        local edit_name = setting.name .. "_edit"
        local edit_ctrl = gbox:CreateOrGetControl("edit", edit_name, right + 15, y, 60, 25)
        AUTO_CAST(edit_ctrl)
        local event_name = "Mini_addons_" .. string.upper(setting.name) .. "_EDIT"
        edit_ctrl:SetEventScript(ui.ENTERKEY, event_name)
        edit_ctrl:SetTextTooltip("{ol}1~100")
        edit_ctrl:SetFontName("white_16_ol")
        edit_ctrl:SetTextAlign("center", "center")
        local transparency_value
        if setting.name == "other_effect" then
            transparency_value = config.GetOtherEffectTransparency()
        elseif setting.name == "my_effect" then
            transparency_value = config.GetMyEffectTransparency()
        elseif setting.name == "boss_effect" then
            transparency_value = config.GetBossMonsterEffectTransparency()
        end
        local num_value = math.floor(transparency_value * 0.392156862745 + 0.5)
        edit_ctrl:SetText("{ol}" .. num_value)
        right = right + 15 + 60
    elseif setting.name == "auto_gacha" then
        local auto_gacha_btn = gbox:CreateOrGetControl("button", "auto_gacha_btn", right + 15, y - 5, 50, 30)
        AUTO_CAST(auto_gacha_btn)
        if g.settings.auto_gacha_start == 0 then
            auto_gacha_btn:SetText("{ol}{#FFFFFF}OFF")
            auto_gacha_btn:SetSkinName("test_gray_button")
        else
            auto_gacha_btn:SetText("{ol}{#FFFFFF}ON")
            auto_gacha_btn:SetSkinName("test_red_button")
        end
        local btn_tooltip = g.lang == "Japanese" and "{ol}ONにすると自動でガチャスタートします" or
                                g.lang == "kr" and "{ol}ON으로 설정하면 자동으로 가챠가 시작됩니다" or
                                "{ol}When turned on, the gacha starts automatically"
        auto_gacha_btn:SetTextTooltip(btn_tooltip)
        auto_gacha_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_GP_AUTOSTART_OPERATION")
        right = right + 15 + 50
    elseif setting.name == "weekly_boss_reward" then
        if not g.settings.reward_switch then
            g.settings.reward_switch = 1
            Mini_addons_save_settings()
        end
        local switch_btn = gbox:CreateOrGetControl("button", "switch", right + 15, y, 80, 25)
        AUTO_CAST(switch_btn)
        if g.settings.reward_switch == 1 then
            switch_btn:SetText(g.lang == "Japanese" and "{ol}先週分" or g.lang == "kr" and "{ol}지난 주분" or
                                   "{ol}last week")
        else
            switch_btn:SetText(g.lang == "Japanese" and "{ol}今週分" or g.lang == "kr" and "{ol}이번 주분" or
                                   "{ol}this week")
        end
        switch_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_WEEKLY_BOSS_REWARD_SWITCH")
        local btn_tooltip = g.lang == "Japanese" and "{ol}ダメージ報酬受取り週切替" or g.lang == "kr" and
                                "{ol}데미지 보상 수령 주차 변경" or "{ol}Switch Damage Reward Receipt Week"
        switch_btn:SetTextTooltip(btn_tooltip)
        right = right + 15 + 80
    elseif setting.name == "party_buff" then
        local party_buff_btn = gbox:CreateOrGetControl("button", "party_buff_btn", right + 15, y - 5, 80, 30)
        AUTO_CAST(party_buff_btn)
        party_buff_btn:SetText("{ol}{#FFFFFF}bufflist")
        local btn_tooltip = g.lang == "Japanese" and "表示するバフを選択できます" or g.lang == "kr" and
                                "표시할 버프를 선택할 수 있습니다" or "You can choose which buffs to display"
        party_buff_btn:SetTextTooltip(btn_tooltip)
        party_buff_btn:SetSkinName("test_red_button")
        party_buff_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_buff_list_open")
        right = right + 15 + 80
    elseif setting.name == "auto_zoom" then
        local edit_ctrl = gbox:CreateOrGetControl("edit", "auto_zoom_edit", right + 15, y, 60, 25)
        AUTO_CAST(edit_ctrl)
        edit_ctrl:SetEventScript(ui.ENTERKEY, "Mini_addons_autozoom_edit")
        edit_ctrl:SetTextTooltip("{ol}1~700 Default 336")
        edit_ctrl:SetFontName("white_16_ol")
        edit_ctrl:SetTextAlign("center", "center")
        edit_ctrl:SetText("{ol}" .. g.settings.auto_zoom.zoom)
        right = right + 15 + 60
    elseif setting.name == "event_shout" then
        local event_shout_btn = gbox:CreateOrGetControl("button", "event_shout_btn", right + 15, y - 5, 50, 30)
        AUTO_CAST(event_shout_btn)
        if g.settings.event_shout.guild_notice == 0 or not g.settings.event_shout.guild_notice then
            event_shout_btn:SetText("{ol}{#FFFFFF}OFF")
            event_shout_btn:SetSkinName("test_gray_button")
            -- baubas_call と同じ理由で、保存は値がまだ無いときだけ
            if not g.settings.event_shout.guild_notice then
                g.settings.event_shout.guild_notice = 0
                Mini_addons_save_settings()
            end
        else
            event_shout_btn:SetText("{ol}{#FFFFFF}ON")
            event_shout_btn:SetSkinName("test_red_button")
        end
        local btn_tooltip = g.lang == "Japanese" and "{ol}ギルドチャットへのお知らせ切替え" or g.lang == "kr" and
                                "{ol}길드 채팅으로 알림 전환" or "{ol}Notification switch to guild chat"
        event_shout_btn:SetTextTooltip(btn_tooltip)
        event_shout_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_event_shout_switch")
        right = right + 15 + event_shout_btn:GetWidth()
    end
    return right
end

-- 一覧の中身を作り直す。検索のたびに呼ばれるので、フレーム側の枠(タイトル・検索窓・✕)は
-- 触らず gbox の中だけを組み直す。filter_text が空なら全件。
function Mini_addons_setting_build(setting, filter_text, keep_pos)
    local needle = string.lower(filter_text or "")
    local gbox = setting:CreateOrGetControl("groupbox", "gbox", 10, 80, 0, 0)
    AUTO_CAST(gbox)
    gbox:SetSkinName("bg")
    -- 折りたたみの開閉でも作り直すので、スクロール位置を引き継げるなら引き継ぐ。
    -- GetScrollPos があるかはクライアント側の実装次第なので pcall で試すだけにする
    -- (取れなくても先頭に戻るだけで、機能は壊れない)。RemoveAllChild より前に読むこと。
    local prev_scroll = 0
    if keep_pos then
        local ok, pos = pcall(function()
            return gbox:GetScrollPos()
        end)
        if ok and type(pos) == "number" then
            prev_scroll = pos
        end
    end
    gbox:RemoveAllChild()
    g.settings.section_collapsed = g.settings.section_collapsed or {}
    local y = 10
    local x = 0
    local hit = 0
    -- セクションごとに枠(groupbox)を作り、その中に項目を入れて束ねる。
    -- 枠の幅は全項目を作り終えるまで決まらないので、ここでは高さだけ決めて
    -- 参照を溜めておき、最後にまとめて同じ幅へ揃える。
    local section_boxes = {}
    for _, section in ipairs(SETTING_SECTIONS) do
        local matched = {}
        for _, item in ipairs(section.items) do
            if setting_matches(item, needle) then
                matched[#matched + 1] = item
            end
        end
        if #matched > 0 then
            -- 検索中は折りたたみを無視して開く。絞り込んだ結果が畳まれた中に隠れていると
            -- 「ヒットしたのに何も出ない」ように見えるため。
            -- あわせて検索中は開閉そのものを受け付けない。押しても見た目が変わらないのに
            -- 保存だけ進み、検索を消した瞬間に畳まれている、という分かりにくい挙動になるため
            local searching = needle ~= ""
            local collapsed = not searching and g.settings.section_collapsed[section.name] == 1
            -- 開閉マークは幅を固定した別コントロールに分ける。見出しの文字列に
            -- "[+] " / "[-] " を含めると、+ と - の字幅の差だけ見出しが左右にズレる
            local marker = gbox:CreateOrGetControl("button", "section_mark_" .. section.name, 12, y, 20, 26)
            AUTO_CAST(marker)
            marker:SetSkinName("None")
            marker:SetTextAlign("center", "center")
            marker:SetText(searching and "" or ("{ol}{s18}{#FFCC33}" .. (collapsed and "+" or "-")))
            -- 見出しはクリックで開閉できるよう button にする（枠なしなので見た目は文字のまま）。
            -- 暗い背景に埋もれないよう縁取り付きの黄色
            -- ({@st66b18} は黒に近く、項目の文字と見分けが付かなかった)
            local header = gbox:CreateOrGetControl("button", "section_" .. section.name, 34, y, 0, 26)
            AUTO_CAST(header)
            header:SetSkinName("None")
            header:SetTextAlign("left", "center")
            header:SetText("{ol}{s18}{#FFCC33}" .. localized_text(section))
            if searching then
                header:SetTextTooltip(g.lang == "Japanese" and "{ol}検索中は折りたたみできません" or
                                          g.lang == "kr" and "{ol}검색 중에는 접을 수 없습니다" or
                                          "{ol}Cannot collapse while filtering")
            else
                for _, btn in ipairs({marker, header}) do
                    btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_section_toggle")
                    btn:SetEventScriptArgString(ui.LBUTTONUP, section.name)
                    btn:SetTextTooltip(g.lang == "Japanese" and "{ol}クリックで折りたたみ" or g.lang == "kr" and
                                           "{ol}클릭하면 접기/펼치기" or "{ol}Click to collapse or expand")
                end
            end
            if x < 34 + header:GetWidth() then
                x = 34 + header:GetWidth()
            end
            y = y + 26
            if collapsed then
                y = y + 8
            else
                local box = gbox:CreateOrGetControl("groupbox", "sec_box_" .. section.name, 10, y, 100, 100)
                AUTO_CAST(box)
                box:SetSkinName("test_frame_midle_light")
                box:EnableScrollBar(0)
                box:RemoveAllChild()
                local by = 8
                for _, item in ipairs(matched) do
                    local right = create_setting_row(box, item, by)
                    if x < right + 10 then -- 枠の左端(10)ぶんを足して gbox 内の座標に直す
                        x = right + 10
                    end
                    by = by + 30
                end
                local box_height = by + 4
                box:Resize(box:GetWidth(), box_height)
                section_boxes[#section_boxes + 1] = box
                y = y + box_height + 14
            end
            hit = hit + #matched
        end
    end
    if hit == 0 then
        local empty = gbox:CreateOrGetControl("richtext", "empty", 10, y)
        AUTO_CAST(empty)
        empty:SetText(g.lang == "Japanese" and "{ol}{#FFA500}該当する設定はありません" or g.lang == "kr" and
                          "{ol}{#FFA500}해당하는 설정이 없습니다" or "{ol}{#FFA500}No matching settings")
        if x < 10 + empty:GetWidth() then
            x = 10 + empty:GetWidth()
        end
        y = y + 30
    end
    local description = gbox:CreateOrGetControl("richtext", "description", 10, y + 5)
    AUTO_CAST(description)
    local temp_text = g.lang == "Japanese" and
                          "{ol}{#FFA500}※一部機能の有効/無効の切替はキャラクターチェンジが必要です" or
                          g.lang == "kr" and
                          "{ol}{#FFA500}※일부 기능의 활성화/비활성화 전환은 캐릭터 변경이 필요합니다" or
                          "{ol}{#FFA500}※Character change is required to enable or disable some functions"
    description:SetText(temp_text)
    if x < 10 + description:GetWidth() then
        x = 10 + description:GetWidth()
    end
    y = y + 40
    -- スクロールバーの分(25)を足す。足さないと右端の文字がバーに隠れる
    local width = x + 25 + 30
    if width < 460 then -- タイトルと検索窓が収まる最低幅
        width = 460
    end
    -- セクションの枠を最終的な幅へ揃える(高さは各枠が既に持っている)。
    -- width から左右の余白(gbox の 10 + 枠の 10 = 計 30)とスクロールバー(25)を引いた分
    local box_width = width - 30 - 25
    for _, box in ipairs(section_boxes) do
        box:Resize(box_width, box:GetHeight())
    end
    local screen_width = ui.GetClientInitialWidth()
    local screen_height = ui.GetClientInitialHeight()
    -- 全件だと画面に収まらない高さになるので、画面の 8 割で頭打ちにしてスクロールさせる
    local max_height = math.floor(screen_height * 0.8)
    local height = y + 95
    if height > max_height then
        height = max_height
    end
    local prev_x, prev_y = setting:GetX(), setting:GetY()
    setting:Resize(width, height)
    gbox:Resize(setting:GetWidth() - 20, setting:GetHeight() - 90)
    gbox:EnableScrollBar(1)
    -- 畳んで中身が縮んだときに、縮む前の位置をそのまま戻すと末尾より下へ飛ぶ。
    -- 新しい中身の高さ(y)と表示領域の差を上限にする
    local scroll_max = y - gbox:GetHeight()
    if scroll_max < 0 then
        scroll_max = 0
    end
    if prev_scroll > scroll_max then
        prev_scroll = scroll_max
    end
    -- GetScrollPos と同じ理由で、SetScrollPos も無い可能性を見て pcall で呼ぶ。
    -- 片方だけ素で呼ぶと、無かったときにここで一覧の構築ごと落ちる
    pcall(function()
        gbox:SetScrollPos(prev_scroll)
    end)
    if keep_pos then
        -- 展開やフィルタ解除で背が伸びると、元の左上のままでは画面外へはみ出す。
        -- この窓はタイトルバーが無く掴み直しづらいので、画面内へ押し戻しておく
        local max_x = screen_width - setting:GetWidth()
        local max_y = screen_height - setting:GetHeight()
        if prev_x > max_x then
            prev_x = max_x
        end
        if prev_y > max_y then
            prev_y = max_y
        end
        if prev_x < 0 then
            prev_x = 0
        end
        if prev_y < 0 then
            prev_y = 0
        end
        setting:SetPos(prev_x, prev_y)
    else
        setting:SetPos((screen_width - setting:GetWidth()) / 2, (screen_height - setting:GetHeight()) / 2)
    end
    -- 実際にこの一覧を作ったときの絞り込み。折りたたみの可否は検索窓の「今の文字」ではなく
    -- こちらで判定する(未確定の入力で見出しが無反応になるのを防ぐ)
    g.setting_applied_filter = filter_text or ""
    core_g.vlog("mini_addons: 設定画面を構築 filter=" .. tostring(filter_text or "") .. " hit=" .. hit)
end

-- セクション見出しのクリック。その配下の枠を畳む / 開く。
-- 状態は settings に持たせて、開き直しても保つ
function Mini_addons_section_toggle(frame, ctrl, section_name, num)
    local setting = ui.GetFrame(addon_name_lower .. "setting")
    if not setting or not section_name then
        return
    end
    -- 見るのは検索窓の「今の文字」ではなく、今表示されている一覧を作ったときの絞り込み。
    -- 打っただけで確定していない文字で弾くと、全件表示のまま見出しを押しても
    -- 何の反応も無い(押せない理由も出ない)状態になる
    local filter_text = g.setting_applied_filter or ""
    -- 検索中は畳めない(理由は Mini_addons_setting_build 側のコメント)。
    -- 検索中の見出しにはそもそもこの関数を繋いでいないが、押せてしまったときの保険
    if filter_text ~= "" then
        return
    end
    g.settings.section_collapsed = g.settings.section_collapsed or {}
    if g.settings.section_collapsed[section_name] == 1 then
        g.settings.section_collapsed[section_name] = 0
    else
        g.settings.section_collapsed[section_name] = 1
    end
    Mini_addons_save_settings()
    core_g.vlog("mini_addons: セクション開閉 " .. section_name .. " collapsed=" ..
                    tostring(g.settings.section_collapsed[section_name]))
    Mini_addons_setting_build(setting, filter_text, true)
end

-- 検索窓の入口。ENTERKEY と虫眼鏡ボタンの両方から来る
function Mini_addons_setting_search(frame, ctrl, str, num)
    local setting = ui.GetFrame(addon_name_lower .. "setting")
    if not setting then
        return
    end
    local search_edit = GET_CHILD_RECURSIVELY(setting, "search_edit")
    Mini_addons_setting_build(setting, search_edit and search_edit:GetText() or "", true)
end

function Mini_addons_SETTING_FRAME_INIT(frame_arg, ctrl_arg, str_arg, num_arg)
    -- 機能 OFF のときは Mini_addons_ON_INIT が走らず g.settings がまだ無い。一覧の歯車は
    -- ON/OFF によらず押せる(core/20_lifecycle.lua が frame_use だけを見て付ける)ので、
    -- ここで受け止めないと下の g.settings.velnice.use で落ち、空のフレームだけが残る。
    -- 既定が use=0 なので、新規導入直後に歯車を押すと必ず踏んでいた。
    -- g.lang も ON_INIT で入るため、案内はまとめ版の言語設定で出す。
    if not g.settings then
        local msg = core_g.lang == "Japanese" and
                        "{ol}[Mini Addons] まだ有効になっていません。一覧の ON/OFF を ON にしてから開いてください" or
                        "{ol}[Mini Addons] Not enabled yet. Turn it ON in the list first"
        ui.SysMsg(msg)
        core_g.vlog("mini_addons: 設定画面を開こうとしたが未初期化(use=0)")
        return
    end
    local setting = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "setting", 0, 0, 10, 10)
    AUTO_CAST(setting)
    if setting:GetWidth() > 100 and str_arg == "false" then
        setting:Resize(0, 0)
        setting:ShowWindow(0)
        return
    end
    setting:SetSkinName("test_frame_low")
    setting:SetLayerLevel(93)
    setting:EnableHittestFrame(1)
    -- 上流は EnableMove を呼んでおらず動かせなかったので P 側で足した
    -- (位置の保存はしないため、開き直すと既定位置に戻る)
    setting:EnableMove(1)
    setting:ShowTitleBar(0)
    setting:RemoveAllChild()
    setting:SetEventScript(ui.RBUTTONUP, "Mini_addons_FRAME_CLOSE")
    local title = setting:CreateOrGetControl("richtext", "title", 30, 10)
    AUTO_CAST(title)
    title:SetText("{@st66b18}Mini Addons")
    local close = setting:CreateOrGetControl("button", "close", 0, 5, 30, 30)
    AUTO_CAST(close)
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetImage("testclose_button")
    close:SetEventScript(ui.LBUTTONUP, "Mini_addons_FRAME_CLOSE")
    -- 検索窓。ここだけは検索のたびに作り直さない(消えると打ち直しになる)ので、
    -- 一覧の中身だけを組み立てる Mini_addons_setting_build と分けてある。
    local search_edit = setting:CreateOrGetControl("edit", "search_edit", 15, 42, 300, 32)
    AUTO_CAST(search_edit)
    search_edit:SetFontName("white_16_ol")
    search_edit:SetTextAlign("left", "center")
    search_edit:SetSkinName("inventory_serch")
    search_edit:SetEventScript(ui.ENTERKEY, "Mini_addons_setting_search")
    search_edit:SetTextTooltip(g.lang == "Japanese" and "{ol}設定名や説明で絞り込み(空で全件)" or g.lang == "kr" and
                                   "{ol}설정 이름으로 검색(비우면 전체)" or
                                   "{ol}Filter settings by text (empty shows all)")
    local search_btn = search_edit:CreateOrGetControl("button", "search_btn", 0, 0, 32, 32)
    AUTO_CAST(search_btn)
    search_btn:SetImage("inven_s")
    search_btn:SetGravity(ui.RIGHT, ui.TOP)
    search_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_setting_search")
    Mini_addons_setting_build(setting, "", false)
    setting:ShowWindow(1)
    core_g.esc_register(addon_name_lower .. "setting", "Mini_addons_setting_ESCAPE_PRESSED")
end

-- ESC 用の入口。esc_register の close_func は引数無しで呼ばれるが、
-- Mini_addons_FRAME_CLOSE は ✕ ボタン経由でフレームを受け取る前提で
-- setting:GetName() を呼ぶため、ここで拾って渡さないと落ちる。
function Mini_addons_setting_ESCAPE_PRESSED()
    local setting = ui.GetFrame(addon_name_lower .. "setting")
    if setting then
        Mini_addons_FRAME_CLOSE(setting)
    end
end

function Mini_addons_FRAME_CLOSE(setting)
    ui.DestroyFrame(setting:GetName())
end

function Mini_addons_ISCHECK(frame, ctrl, argStr, argNum)
    local is_checked = ctrl:IsChecked()
    local ctrl_name = ctrl:GetName()
    for _, setting_name in ipairs(SETTINGS_NAME) do
        if ctrl_name == setting_name then
            if setting_name == "cupole_portion" or setting_name == "velnice" or setting_name == "baubas_call" or
                setting_name == "auto_zoom" or setting_name == "event_shout" then
                g.settings[setting_name] = g.settings[setting_name] or {}
                g.settings[setting_name].use = is_checked
            else
                g.settings[setting_name] = is_checked
            end
            if setting_name == "bgm" then -- 特定の機能に対する即時処理
                if is_checked == 0 then
                    local max_frame = ui.GetFrame("bgmplayer")
                    local play_btn = GET_CHILD_RECURSIVELY(max_frame, "playStart_btn")
                    BGMPLAYER_PLAY(max_frame, play_btn)
                end
            elseif setting_name == "daily_quest" then
                local q7quest = ui.GetFrame((addon_name_lower .. "_q7quest"))
                if is_checked == 0 then
                    if q7quest then
                        ui.DestroyFrame((addon_name_lower .. "_q7quest"))
                    end
                else
                    if q7quest then
                        ui.DestroyFrame((addon_name_lower .. "_q7quest"))
                    end
                    Mini_addons_quest_update()
                end
            elseif setting_name == "inventory_mod" then
                local inventory = ui.GetFrame("inventory")
                local tab = GET_CHILD_RECURSIVELY(inventory, "inventype_Tab")
                tab:SelectTab(0)
                local tab_index = tab:GetSelectItemIndex()
                inventory:SetUserValue("TRY", 0)
                g.inven_tbl = {}
                Mini_addons_INVENTORY_OPEN_logic(inventory)
            elseif setting_name == "chat_new_btn" then
                Mini_addons_update_chat_frame()
            end
            break
        end
    end
    Mini_addons_save_settings()
end

