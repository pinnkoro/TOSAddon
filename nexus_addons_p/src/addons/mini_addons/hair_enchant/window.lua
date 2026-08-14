hair_enchant_open_advanced = function()
    local high_hairenchant = ui.GetFrame("high_hairenchant")
    if high_hairenchant == nil then
        return
    end
    local enchantGuid = high_hairenchant:GetUserValue("Enchant")
    local itemIES = high_hairenchant:GetUserValue("itemIES")
    if enchantGuid == "None" or itemIES == "None" then
        -- 素材かスクロールが揃っていないと、出せるオプションもランクも決まらない
        core_g.vlog("mini_addons: ヘアエンチャント 高度な設定を開けない(アイテム=%s / スクロール=%s)",
            itemIES == "None" and "未設定" or "あり", enchantGuid == "None" and "未設定" or "あり")
        return
    end
    core_g.vlog("mini_addons: ヘアエンチャント 高度な設定を開く")
    -- 素のオプション設定とは**どちらか一方だけ**。ほぼ同じ位置に重なるので、
    -- 両方出ていると手前がどちらか分からなくなる。開くときに相手を閉じる
    -- (逆向きは Mini_addons_HIGH_ENCHANT_OPTION_OPEN_BTN でやっている)
    ui.CloseFrame("hairenchant_option")
    local reroll_option = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "reroll_option", 0, 0, 0, 0)
    AUTO_CAST(reroll_option)
    reroll_option:SetSkinName("test_Item_tooltip_equip")
    reroll_option:SetGravity(ui.RIGHT, ui.TOP) -- ui.GetClientInitialWidth() 1920が取れるui.GetSceneWidt()今の横幅 結構nilになったりする。信頼性低いui.GetRatioWidth()=ui.GetSceneWidth()/ui.GetClientInitialWidth()
    local margin = reroll_option:GetMargin()
    reroll_option:SetMargin(margin.left, margin.top, margin.right + 905, margin.bottom)
    reroll_option:SetPos(reroll_option:GetX(), high_hairenchant:GetY())
    reroll_option:SetLayerLevel(100)
    -- **窓の余白(タイトル部分)でクリックが素通りしないようにする。**
    -- これが無いと、コントロールの載っていない所を押したときにクリックが後ろへ抜けて、
    -- 露店や地面など背後のものが反応してしまう。同じ土台で作っている rank_frame も
    -- 同様に立てている
    reroll_option:EnableHittestFrame(1)
    -- gbox とその中身は hair_enchant_build_reroll_body が作る(ランクが上がったら
    -- そこだけ組み直すため)。close ボタンは gbox の外なので組み直しの対象外
    local close = reroll_option:CreateOrGetControl("button", "close", 0, 0, 30, 30)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.LEFT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Mini_addons_hair_enchant_adv_close")
    local item_grade, item_rank = get_current_enchant_item_grade_and_rank()
    if item_grade == nil or item_rank == nil then
        -- **作りかけのフレームを残さないこと。** 非表示の空フレームが居座ると、
        -- 「高度な設定」ボタンは畳むだけ(1 回目の押下が空振り)になり、
        -- 自動で開く経路も「もう開いている」と判断して二度と開かなくなる
        core_g.vlog("mini_addons: ヘアエンチャント 等級 / ランクを引けないので高度な設定を開けない")
        ui.DestroyFrame(reroll_option:GetName())
        return
    end
    g.need_options = {}
    hair_enchant_build_reroll_body(reroll_option, item_grade, item_rank)
    reroll_option:ShowWindow(1)
    -- **この窓は g.esc_register で積まないこと。** CLAUDE.md の
    -- 「ウィンドウを開いたら ESC で閉じられるようにする」には
    -- 「ゲーム側のウィンドウに貼り付いている付属パネルは積んではいけない」という例外があり、
    -- これはそれに当たる(high_hairenchant に位置を合わせ、あちらが閉じれば一緒に畳まれる)。
    --
    -- ここで積むと実害が出る。素は魔法付与を始めるときに
    -- ui.SetEscapeScp("CANCEL_ENCHANTCHIP()") で ESC を握っている(enchantchip.lua)。
    -- g.esc_sync_scp は積むと "_nexus_addons_p_ESCAPE_PRESSED()" で上書きし、
    -- スタックが空になると **"" に戻す**(元の値を覚えていない)。つまり畳んだ後に
    -- CANCEL_ENCHANTCHIP が呼ばれなくなり、その中の SET_SLOT_APPLY_FUNC(inv,"None") /
    -- INVENTORY_SET_CUSTOM_RBTNDOWN("None") / RESET_MOUSE_CURSOR() が走らないまま、
    -- インベントリが素材選択モードのまま取り残される
    -- (cc_helper で実際に起きた「ESC で閉じると右クリックが割り当てられたまま残る」と同型)。
    -- 窓を閉じる手段は × と「高度な設定」ボタン、素の付与ウィンドウを閉じる操作で足りる
    --
    -- 窓を開いたままヘアアクセやスクロールを差し替えられても追随できるようにする。
    -- 窓を畳めば一緒に止まる(フレームごと破棄するため)
    reroll_option:RunUpdateScript("Mini_addons_hair_enchant_watch", 0.3)
end


-- 指定した等級 / ランクで**実際に出るオプション**の「クラス名 → チェックの名前」表を作る。
--
-- **g.hair_enchant_option_by_class を当てにしないこと。** あれは窓を組んだ時点の
-- ランクのものなので、アクセを差し替えた直後(まだ組み直していない)に引くと古い。
-- D のアクセで読み込んだ後 A へ替えても A 専用のオプションが「出ない」と判定され、
-- チェックが戻らなかった。ここは毎回ランクから引き直す。
-- チェックの名前は enchant_special_option の並び順そのもの(ランクで変わらない)
local function hair_enchant_option_map(item_grade, item_rank)
    local by_class = {}
    local OptionList, cnt = GetClassList("enchant_special_option")
    for i = 0, cnt - 1 do
        local cls = GetClassByIndexFromList(OptionList, i)
        if cls == nil then
            break
        end
        local range = shared_enchant_special_option.get_value_range(cls.ClassName, item_grade, item_rank, 1)
        if range[1] ~= 0 and range[2] ~= 0 then
            by_class[cls.ClassName] = "option_text" .. i
        end
    end
    return by_class
end

-- 組み立て中に SelectItem が項目のスクリプトを走らせても読み込みに行かせないための印。
-- 読み込むと窓を組み直すので、抑えないと止まらなくなる
local hair_enchant_suppress_preset_sel = false

-- プリセットの入れ物。**配列**(1 始まり)で、枠数は決めない。
-- 途中まで「1」〜「4」を鍵にした表で持っていた時期があるので、その形が残っていたら
-- 配列へ移し替える(dev ビルドで保存したものを消さないため)
hair_enchant_presets = function()
    local presets = g.settings.hair_enchant_presets
    if type(presets) ~= "table" then
        presets = {}
        g.settings.hair_enchant_presets = presets
    end
    if #presets == 0 then
        local moved = 0
        for slot = 1, 4 do
            local old = presets[tostring(slot)]
            if type(old) == "table" then
                table.insert(presets, old)
                presets[tostring(slot)] = nil
                moved = moved + 1
            end
        end
        if moved > 0 then
            Mini_addons_save_settings()
            core_g.vlog("mini_addons: ヘアエンチャント 旧形式(枠固定)のプリセット %d 件を引き継いだ", moved)
        end
    end
    return presets
end

-- 窓を組み直して、プリセット一覧やチェックの状態を今の設定に合わせる
local function hair_enchant_rebuild()
    local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
    if reroll_option == nil then
        return
    end
    local item_grade, item_rank = get_current_enchant_item_grade_and_rank()
    if item_grade == nil or item_rank == nil then
        return
    end
    hair_enchant_build_reroll_body(reroll_option, item_grade, item_rank)
end

-- ドロップリストで選んだプリセット(1 始まり。0 は「プリセットなし」)。
-- **選んだらその場で読み込む**(読込ボタンは置いていない)。
-- ただし組み立て中の SelectItem から来たときは記録だけ(理由は呼び出し側のコメント)
function mini_addons_p_hair_enchant_preset_sel(index)
    local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
    if reroll_option == nil then
        return
    end
    reroll_option:SetUserValue("PRESET_SEL", tostring(index))
    if hair_enchant_suppress_preset_sel or index == 0 then
        return
    end
    -- **この場で読み込まないこと。** 読み込むと窓を組み直す = 今このスクリプトを
    -- 走らせているドロップリスト自身を RemoveAllChild で壊すことになる。1 拍遅らせる
    -- (always_status の設定画面も、同じ理由で ReserveScript を挟んでいる)
    ReserveScript(string.format("%s_hair_enchant_preset_load_deferred()", addon_name_lower), 0.1)
end

function mini_addons_p_hair_enchant_preset_load_deferred()
    -- ドロップリストで選んだ = 明示的な読込。リピート回数もプリセットの値にする
    Mini_addons_hair_enchant_preset_load(true)
end

-- 保存。名前を訊くポップアップ(素の inputstring)を出す。
-- 選択中のプリセットがあればその名前を初期値にするので、そのまま決定すれば上書きになる
function Mini_addons_hair_enchant_preset_save_open(parent, ctrl)
    local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
    if reroll_option == nil then
        return
    end
    local presets = hair_enchant_presets()
    local sel = tonumber(reroll_option:GetUserValue("PRESET_SEL")) or 0
    local inputstring = ui.GetFrame("inputstring")
    if inputstring == nil then
        core_g.vlog("mini_addons: ヘアエンチャント inputstring が無いのでプリセット名を訊けない")
        return
    end
    inputstring:Resize(500, 220)
    inputstring:SetLayerLevel(999)
    local edit = GET_CHILD(inputstring, "input", "ui::CEditControl")
    edit:SetNumberMode(0)
    edit:SetMaxLen(64)
    edit:SetText(presets[sel] ~= nil and presets[sel].name or "")
    local title = inputstring:GetChild("title")
    AUTO_CAST(title)
    title:SetText(g.lang == "Japanese" and "{ol}{#FFFFFF}プリセットの名前を入力してください" or
                      "{ol}{#FFFFFF}Enter a preset name")
    local confirm = inputstring:GetChild("confirm")
    confirm:SetEventScript(ui.LBUTTONUP, "Mini_addons_hair_enchant_preset_save_do")
    edit:SetEventScript(ui.ENTERKEY, "Mini_addons_hair_enchant_preset_save_do")
    inputstring:ShowWindow(1)
    inputstring:SetEnable(1)
    edit:AcquireFocus()
end

-- ポップアップで決定された。今の窓の状態を、その名前で保存する。
-- **オプションはクラス名で持つ**(理由は DEFAULT_SETTINGS のコメント)
function Mini_addons_hair_enchant_preset_save_do(frame, ctrl)
    if frame == nil or frame:GetName() ~= "inputstring" then
        return
    end
    local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
    if reroll_option == nil then
        frame:ShowWindow(0)
        return
    end
    local name = GET_INPUT_STRING_TXT(frame)
    if name == nil or name == "" then
        ui.SysMsg(g.lang == "Japanese" and "プリセットの名前を入力してください" or "Enter a preset name")
        return
    end
    local options = {}
    for option_name, value in pairs(g.need_options or {}) do
        local class_name = (g.hair_enchant_option_classes or {})[option_name]
        if value.is_check == 1 and class_name ~= nil then
            table.insert(options, class_name)
        end
    end
    table.sort(options) -- 保存のたびに並びが変わると差分が読みにくいので固定する
    local repeat_count = GET_CHILD_RECURSIVELY(reroll_option, "repeat_count")
    local entry = {
        name = name,
        options = options,
        rank = reroll_option:GetUserValue("RANK_UNTIL"),
        repeat_count = repeat_count ~= nil and tonumber(repeat_count:GetText()) or nil,
        fast = reroll_option:GetUserValue("FAST") == "yes" and 1 or 0
    }
    local presets = hair_enchant_presets()
    local at = nil
    for i, preset in ipairs(presets) do
        if preset.name == name then
            at = i
            break
        end
    end
    if at ~= nil then
        presets[at] = entry
    else
        table.insert(presets, entry)
        at = #presets
    end
    reroll_option:SetUserValue("PRESET_SEL", tostring(at))
    Mini_addons_save_settings()
    core_g.vlog("mini_addons: ヘアエンチャント プリセット「%s」を%s(オプション %d 件 / 目標ランク %s)", name,
        at == #presets and "追加" or "上書き", #options, tostring(entry.rank))
    ui.SysMsg(string.format(g.lang == "Japanese" and "プリセット「%s」を保存しました" or "Saved preset \"%s\"",
        name))
    frame:ShowWindow(0)
    -- 保存した = 今の内容が保存値そのもの
    hair_enchant_preset_dirty = false
    hair_enchant_rebuild()
end

-- 読込。今のランクで出ないオプションは飛ばす(保存したときよりランクが低いと、
-- B・A でしか出ないものが一覧に無い)
-- apply_repeat: リピート回数まで反映するか。
-- **ドロップリストで選んだときだけ true。** アクセの差し替え・ランクアップ・
-- 確認ダイアログを挟んだ入れ直しといった「自動の入れ直し」では今の値を維持する。
-- 回している最中に上限が勝手に書き換わると、いつ止まるのか読めなくなるため。
-- 「自分で選んだときだけ変わる」と覚えれば済むよう、回している最中かどうかでは分けない
function Mini_addons_hair_enchant_preset_load(apply_repeat)
    local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
    if reroll_option == nil then
        return
    end
    local presets = hair_enchant_presets()
    local preset = presets[tonumber(reroll_option:GetUserValue("PRESET_SEL")) or 0]
    if preset == nil then
        return
    end
    local item_grade, item_rank = get_current_enchant_item_grade_and_rank()
    if item_grade == nil or item_rank == nil then
        return
    end
    local applied, skipped = 0, {}
    -- 対応表は今の等級 / ランクから引き直す(古い表を使うと、差し替えたばかりの
    -- アクセで出るはずのオプションを取りこぼす。理由は hair_enchant_option_map)
    local by_class = hair_enchant_option_map(item_grade, item_rank)
    g.need_options = {}
    for _, class_name in ipairs(preset.options or {}) do
        local option_name = by_class[class_name]
        if option_name ~= nil then
            g.need_options[option_name] = {
                is_check = 1,
                text = ScpArgMsg(class_name)
            }
            applied = applied + 1
        else
            table.insert(skipped, class_name)
        end
    end
    -- 目標ランクは今のランクより上でなければ意味を成さないので、そのときは指定なしへ
    local rank = preset.rank
    local rank_index = hair_enchant_rank_index(rank)
    local now_index = hair_enchant_rank_index(item_rank)
    if rank_index == nil or now_index == nil or rank_index <= now_index then
        rank = "None"
    end
    reroll_option:SetUserValue("RANK_UNTIL", rank)
    reroll_option:SetUserValue("FAST", preset.fast == 1 and "yes" or "no")
    hair_enchant_build_reroll_body(reroll_option, item_grade, item_rank)
    -- リピート回数は組み直しが前の値を引き継ぐので、反映するときだけ後から上書きする
    if apply_repeat and preset.repeat_count ~= nil then
        local repeat_count = GET_CHILD_RECURSIVELY(reroll_option, "repeat_count")
        if repeat_count ~= nil then
            local want = preset.repeat_count
            if want > HAIR_ENCHANT_REPEAT_MAX then
                want = HAIR_ENCHANT_REPEAT_MAX
            end
            repeat_count:SetText(tostring(want))
        end
    end
    core_g.vlog(
        "mini_addons: ヘアエンチャント プリセット「%s」を読込(オプション %d 件適用 / %d 件は %s ランクで出ないので飛ばした%s / 目標ランク %s / リピート回数は%s)",
        tostring(preset.name), applied, #skipped, tostring(item_rank),
        #skipped > 0 and (": " .. table.concat(skipped, ", ")) or "", tostring(rank),
        apply_repeat and "プリセットの値を反映" or "今の値を維持")
    -- 今の内容 = 保存値。ここから手で変えられるまでは入れ直してよい
    hair_enchant_preset_dirty = false
    if #skipped > 0 then
        ui.SysMsg(string.format(g.lang == "Japanese" and
                                    "プリセット「%s」を読み込みました(%d 件は今のランクでは付かないので除外)" or
                                    "Loaded preset \"%s\" (%d entries dropped: not available at this rank)",
            tostring(preset.name), #skipped))
    end
end

function mini_addons_p_hair_enchant_preset_delete_do()
    local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
    if reroll_option == nil then
        return
    end
    local presets = hair_enchant_presets()
    local sel = tonumber(reroll_option:GetUserValue("PRESET_SEL")) or 0
    local preset = presets[sel]
    if preset == nil then
        return
    end
    table.remove(presets, sel)
    -- 消した後は「--」へ戻す。詰めた結果の別のプリセットが選ばれた状態にすると、
    -- 名前は出ているのにチェックはさっきのまま、という食い違いになる
    reroll_option:SetUserValue("PRESET_SEL", "0")
    Mini_addons_save_settings()
    core_g.vlog("mini_addons: ヘアエンチャント プリセット「%s」を削除(残り %d 件)", tostring(preset.name),
        #presets)
    hair_enchant_rebuild()
end

-- 削除。押し間違いで消えると戻せないので確認を挟む
function Mini_addons_hair_enchant_preset_delete(parent, ctrl)
    local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
    if reroll_option == nil then
        return
    end
    local presets = hair_enchant_presets()
    local preset = presets[tonumber(reroll_option:GetUserValue("PRESET_SEL")) or 0]
    if preset == nil then
        return
    end
    ui.MsgBox(string.format(g.lang == "Japanese" and "{#FFFFFF}{ol}プリセット「%s」を削除しますか？" or
                                "{#FFFFFF}{ol}Delete preset \"%s\"?", tostring(preset.name)),
        string.format("%s_hair_enchant_preset_delete_do()", addon_name_lower), "None")
end

-- 素の「設定」が押された。**素の動きには手を出さない**(このフックは元の関数を
-- 先に呼ぶ設定で、標準のオプション窓は既に開いている)。こちらは自前の窓を畳むだけ。
-- ほぼ同じ位置に重なるので、両方出ていると手前がどちらか分からなくなる。
--
-- 素が途中で return したとき(アイテム未設定・等級が None など)は標準の窓が開かない。
-- そのときに畳むと「設定を押したら高度な設定だけ消えた」になるので、
-- **本当に開いたかを確かめてから**畳むこと
function Mini_addons_HIGH_ENCHANT_OPTION_OPEN_BTN(my_frame, my_msg)
    local hairenchant_option = ui.GetFrame("hairenchant_option")
    if hairenchant_option == nil or hairenchant_option:IsVisible() == 0 then
        return
    end
    if hair_enchant_close_advanced() then
        core_g.vlog("mini_addons: ヘアエンチャント 標準のオプション設定が開いたので高度な設定を畳んだ")
    end
end

-- 付与ウィンドウが開かれた。素のフレームへ「高度な設定」ボタンを足す。
-- 素の「設定」(select_before)は bodyGbox1 の右上 90x35 なので、その左隣に並べる。
-- CreateOrGetControl なので開くたびに呼んでも二重にはならない
function Mini_addons_CLIENT_ENCHANTCHIP(my_frame, my_msg)
    local high_hairenchant = ui.GetFrame("high_hairenchant")
    if high_hairenchant == nil or high_hairenchant:IsVisible() == 0 then
        -- 低級のスクロールは素が hairenchant の方を開く。こちらは対象外だが、
        -- **自前の窓が残っていたら畳むこと。** 素の CLIENT_ENCHANTCHIP は冒頭で
        -- HIGH_HAIRENCHANT_UI_RESET() を呼んで高級側を閉じるので、放っておくと
        -- 相手のいない高度な設定が更新スクリプトごと画面に取り残される
        if hair_enchant_close_advanced() then
            core_g.vlog("mini_addons: ヘアエンチャント 高級の付与ウィンドウが閉じたので高度な設定を畳んだ")
        end
        return
    end
    local bodyGbox1 = GET_CHILD_RECURSIVELY(high_hairenchant, "bodyGbox1")
    if bodyGbox1 == nil then
        return
    end
    local adv = bodyGbox1:CreateOrGetControl("button", "mini_addons_adv_setting", 0, 0, 100, 35)
    AUTO_CAST(adv)
    adv:SetGravity(ui.RIGHT, ui.TOP)
    local margin = adv:GetMargin()
    adv:SetMargin(margin.left, margin.top, 95, margin.bottom) -- 素の「設定」(幅 90)の左隣
    adv:SetSkinName("test_pvp_btn")
    adv:SetText("{@st66}{s16}" .. (g.lang == "Japanese" and "高度な設定" or "Advanced"))
    adv:SetTextTooltip(g.lang == "Japanese" and
                           "{ol}希望オプション・目標ランク・プリセットを設定します{nl}隣の「設定」はゲーム標準のままです" or
                           "{ol}Set target options, target rank and presets{nl}The button next to it stays vanilla")
    adv:SetEventScript(ui.LBUTTONUP, "Mini_addons_hair_enchant_adv_btn")
    -- 機能 OFF のときはボタンごと隠す(押しても何もしないボタンを見せない)
    adv:ShowWindow(g.settings.hair_enchant == 1 and 1 or 0)
    core_g.vlog("mini_addons: ヘアエンチャント 高度な設定ボタンを用意した(機能=%s)",
        g.settings.hair_enchant == 1 and "ON" or "OFF")
end

-- 素材(ヘアアクセ)がスロットへ乗った。ここで初めてランクとオプション一覧が決まるので、
-- 「自動で開く」はこの時点で効かせる。既に開いていれば監視スクリプトが組み直す
function Mini_addons_HIGH_HAIRENCHANT_DRAW_HIRE_ITEM(my_frame, my_msg)
    if g.settings.hair_enchant == 0 then
        return
    end
    -- 乗せたのに「アイテムを乗せてください」が残ることがあるので、ここでも合わせ直す
    hair_enchant_sync_slot_guide()
    if g.settings.hair_enchant_auto_open ~= 1 then
        return
    end
    if ui.GetFrame(addon_name_lower .. "reroll_option") ~= nil then
        return
    end
    core_g.vlog("mini_addons: ヘアエンチャント 自動で開く設定が ON なので高度な設定を開く")
    hair_enchant_open_advanced()
end

-- reroll_option の中身(希望オプションのチェック / 目標ランク / リピート回数 / Cancel)を組む。
-- **ランクが上がったら組み直す。** 選べるオプションもその数値範囲もランクごとに違い
-- (`enchant_special_option_ratio.ies` の `AppearRatio_<rank>` が 0 のものは出ない。
-- 実データでは ALLSKILL / MSPD / walking_recover_sta / reduce_rsp_time /
-- secret_medicine_time / ignore_deadremove の 6 つが B・A でしか出ない)、
-- 一覧を作ったときのランクのまま置いておくと、上がった後は**古いランクの一覧**を
-- 見せ続けることになる。以前はランクアップで必ず止めて窓ごと畳んでいたので表に出て
-- いなかったが、止めずに続けられるようにした以上、ここで追随させる必要がある。
--
-- 組み直しても壊れないように、次の 3 つは引き継ぐこと:
--   * 希望オプションのチェック … g.need_options(Lua 側の表)から SetCheck で戻す
--   * リピート回数の入力値     … 停止判定が set_repeat_num として読んでいる。消すと止まらなくなる
--   * 目標ランク               … reroll_option の UserValue "RANK_UNTIL"(コントロールではないので残る)
hair_enchant_build_reroll_body = function(reroll_option, item_grade, item_rank)
    local high_hairenchant = ui.GetFrame("high_hairenchant")
    local gbox = reroll_option:CreateOrGetControl("groupbox", "gbox", 0, 40, 0, 0)
    AUTO_CAST(gbox)
    gbox:SetSkinName("None")
    -- 組み直す前に、消えると困る入力値を控える
    local prev_repeat = GET_CHILD_RECURSIVELY(gbox, "repeat_count")
    local prev_repeat_text = prev_repeat ~= nil and prev_repeat:GetText() or nil
    gbox:RemoveAllChild()
    -- 名前は呼び出し側(SetEventScript)が addon_name_lower から組み立てるので、必ず揃えること。
    -- 本家から移す際にここだけ "mini_addons_" のままにしてしまい、チェックが一切拾われず
    -- 「希望のオプションが出ても止まらない」形で出ていた
    function mini_addons_p_reroll_option_check(gbox, ctrl, str)
        g.need_options[ctrl:GetName()] = {
            is_check = ctrl:IsChecked(),
            text = str
        }
        hair_enchant_mark_dirty()
        core_g.vlog("mini_addons: ヘアエンチャント 希望オプション %s = %s", tostring(str),
            ctrl:IsChecked() == 1 and "ON" or "OFF")
        local bodyGbox1 = GET_CHILD_RECURSIVELY(high_hairenchant, "bodyGbox1")
        local dest = bodyGbox1:GetUserValue("DESTROY")
        local bodyGbox1_1 = GET_CHILD_RECURSIVELY(high_hairenchant, "bodyGbox1_1")
        if dest == "None" then
            bodyGbox1:SetUserValue("DESTROY", "destroy")
            DESTROY_CHILD_BYNAME(bodyGbox1, "bodyGbox1_1")
        end
        local bodyGbox1_1 = bodyGbox1:CreateOrGetControl("groupbox", "bodyGbox1_1", 5, 35, 370, 135)
        AUTO_CAST(bodyGbox1_1)
        bodyGbox1_1:RemoveAllChild()
        bodyGbox1_1:SetSkinName("None")
        bodyGbox1_1:SetGravity(ui.LEFT, ui.TOP)
        local ypos = 10
        for key, value in pairs(g.need_options) do
            if value.is_check == 1 then
                local op_name = string.format("%s %s", ClMsg("ItemRandomOptionGroupSTAT"), "{ol}" .. value.text)
                local property_text = bodyGbox1_1:CreateOrGetControl("richtext", "property_text" .. key, 5, ypos, 0, 20)
                property_text:SetText(op_name)
                ypos = ypos + 25
            end
        end
    end
    local y = 5
    -- プリセットは 1 行にまとめる(ドロップリスト + 読込 / 保存 / 削除)。
    -- 枠数は固定しない。保存を押すと名前を訊くポップアップが出て、同じ名前があれば
    -- 上書き、無ければ足す。**縦を食わないこと**を優先してこの形にしてある
    -- (以前は 4 行並べていて、オプション一覧を押し下げていた)
    local presets = hair_enchant_presets()
    local sel = tonumber(reroll_option:GetUserValue("PRESET_SEL")) or 0
    if presets[sel] == nil then
        -- 消された / まだ何も選んでいない。1 件目へ寄せたりせず「--」のままにする
        sel = 0
    end
    reroll_option:SetUserValue("PRESET_SEL", tostring(sel))
    local preset_list = gbox:CreateOrGetControl("droplist", "preset_list", 10, y + 2, 235, 20)
    AUTO_CAST(preset_list)
    preset_list:SetSkinName("droplist_normal")
    preset_list:EnableHitTest(1)
    preset_list:SetTextAlign("center", "center")
    preset_list:SetTextTooltip(g.lang == "Japanese" and
                                   "{ol}選ぶとその場で読み込みます{nl}リピート回数が変わるのはここで選んだときだけです{nl}(アクセの差し替えなどで入れ直すときは今の値のまま)" or
                                   "{ol}Selecting one loads it right away{nl}The repeat count only changes when you pick one here{nl}(automatic reloads keep the current value)")
    -- **先頭は常に「--」(未選択)。** プリセットは 1 番目以降。
    -- 先頭を 1 件目のプリセットにすると、窓を開いた直後に「プリセット名が出ているのに
    -- チェックは入っていない」という食い違った見え方になる。読み込んだとき / 保存した
    -- ときだけ、その名前が選ばれている状態にする
    preset_list:AddItem(0, "{ol}" .. (#presets == 0 and
        (g.lang == "Japanese" and "-- プリセットなし --" or "-- No presets --") or "--"), 0,
        string.format("%s_hair_enchant_preset_sel(0)", addon_name_lower))
    for i, preset in ipairs(presets) do
        preset_list:AddItem(i, "{ol}" .. tostring(preset.name), 0,
            string.format("%s_hair_enchant_preset_sel(%d)", addon_name_lower, i))
    end
    -- **SelectItem は項目のスクリプトを走らせうる。** 選んだら読み込む作りなので、
    -- 組み立て中に走ると「読込 → 組み直し → SelectItem → 読込」で止まらなくなる。
    -- 組み立ての間は選択を記録するだけにする
    hair_enchant_suppress_preset_sel = true
    preset_list:SelectItem(sel)
    hair_enchant_suppress_preset_sel = false
    local save_btn = gbox:CreateOrGetControl("button", "preset_save", 250, y, 65, 25)
    AUTO_CAST(save_btn)
    save_btn:SetSkinName("test_pvp_btn")
    save_btn:SetText("{ol}" .. (g.lang == "Japanese" and "保存" or "Save"))
    -- 何が保存されるのかは押す前に知りたいので、対象を並べておく。
    -- **項目を増減したら、ここと Mini_addons_hair_enchant_preset_save_do の中身を
    -- 必ず揃えること**(説明だけ古くなると、入っているつもりの設定が入らない)
    save_btn:SetTextTooltip(g.lang == "Japanese" and
                                "{ol}今の設定に名前を付けて保存します{nl}保存する内容:{nl}・希望オプションのチェック{nl}・目標ランク{nl}・リピート回数{nl}・演出を待たずに実行{nl}同じ名前があれば上書きします" or
                                "{ol}Save the current settings under a name{nl}What is saved:{nl}- Target option checkboxes{nl}- Target rank{nl}- Repeat count{nl}- Run without waiting for the effect{nl}Overwrites if the name exists")
    save_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_hair_enchant_preset_save_open")
    local del_btn = gbox:CreateOrGetControl("button", "preset_delete", 320, y, 65, 25)
    AUTO_CAST(del_btn)
    del_btn:SetSkinName("test_red_button")
    del_btn:SetText("{ol}" .. (g.lang == "Japanese" and "削除" or "Delete"))
    del_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_hair_enchant_preset_delete")
    -- 消す対象が決まっていないと押せない(「--」を選んでいるときは何も消せない)
    del_btn:SetEnable(presets[sel] ~= nil and 1 or 0)
    y = y + 30

    -- 自動で開く設定。プリセットと同じくアドオンの設定ファイルへ保存する
    -- 名前の揃え方は mini_addons_p_reroll_option_check のコメントと同じ
    function mini_addons_p_hair_enchant_auto_open(gbox, ctrl)
        g.settings.hair_enchant_auto_open = ctrl:IsChecked() == 1 and 1 or 0
        Mini_addons_save_settings()
        core_g.vlog("mini_addons: ヘアエンチャント 自動で開く = %s",
            g.settings.hair_enchant_auto_open == 1 and "ON" or "OFF")
    end
    local auto_open = gbox:CreateOrGetControl("checkbox", "auto_open", 10, y, 0, 20)
    AUTO_CAST(auto_open)
    auto_open:SetText("{ol}" ..
                          (g.lang == "Japanese" and "ヘアアクセを乗せたら自動で開く" or
                              "Open automatically when an item is placed"))
    auto_open:SetTextTooltip(g.lang == "Japanese" and
                                 "{ol}付与ウィンドウにヘアアクセを乗せた時点でこの窓を開きます{nl}この設定は保存されます" or
                                 "{ol}Opens this window once an item is placed{nl}This setting is saved")
    auto_open:SetEventScript(ui.LBUTTONUP, (addon_name_lower .. "_hair_enchant_auto_open"))
    auto_open:SetCheck(g.settings.hair_enchant_auto_open == 1 and 1 or 0)
    y = y + 30

    -- **希望オプションはスクロール枠へ入れる。** 一覧は 30 件を超えることがあり
    -- (ランクが上がるとさらに増える)、そのまま縦に積むと窓が画面の高さを超えて
    -- 下のリピート回数や Cancel が画面外へ出てしまう。枠の高さは固定にして、
    -- はみ出したぶんはスクロールで見せる
    -- 枠の高さは画面から決める。窓全体(上のプリセット等 + 枠 + 下の行 + 余白)が
    -- 画面の 8 割に収まるように残りを割り当てる。設定画面(Mini_addons_settings_frame)も
    -- 同じ考え方で頭打ちにしている
    local max_box_height = math.floor(ui.GetClientInitialHeight() * 0.8) - y - HAIR_ENCHANT_BOTTOM_HEIGHT
    if max_box_height < 120 then
        max_box_height = 120 -- 極端に低い解像度でも、数行は見えるようにする
    end
    local option_box = gbox:CreateOrGetControl("groupbox", "option_box", 5, y, 385, max_box_height)
    AUTO_CAST(option_box)
    option_box:SetSkinName("test_frame_midle_light")
    local OptionList, cnt = GetClassList("enchant_special_option")
    -- 目標ランクを選んだときに灰色にして無効化するため、作ったチェックの名前と
    -- 元の表示文字列を控える。表示は SetText で色タグごと差し替えるので、
    -- 戻すには元の文字列が要る(コントロール側からは読み直せない)
    g.hair_enchant_option_names = {}
    g.hair_enchant_option_labels = {}
    -- プリセットの保存でクラス名が要るので、チェック名 → クラス名だけ控える。
    -- **逆向き(クラス名 → チェック名)はここに持たないこと。** 組んだ時点のランクの
    -- ものになるため、差し替え直後に引くと古い。読込側は hair_enchant_option_map で
    -- そのつど引き直す
    g.hair_enchant_option_classes = {}
    local oy = 5
    for i = 0, cnt - 1 do
        local cls = GetClassByIndexFromList(OptionList, i)
        if cls == nil then
            break
        end
        local RangeTable = shared_enchant_special_option.get_value_range(cls.ClassName, item_grade, item_rank, 1)
        if RangeTable[1] ~= 0 and RangeTable[2] ~= 0 then
            local OptionString = string.format("%s %d~%d", ScpArgMsg(cls.ClassName), RangeTable[1], RangeTable[2])
            -- 名前は "option_text" .. (enchant_special_option の並び順)。この並びは
            -- ランクで変わらないので、組み直しても同じオプションは同じ名前になる。
            -- g.need_options もこの名前を鍵にしているため、チェックをそのまま戻せる
            local option_name = "option_text" .. i
            local option_text = option_box:CreateOrGetControl("checkbox", option_name, 5, oy, 0, 20)
            AUTO_CAST(option_text)
            option_text:SetText("{ol}" .. OptionString)
            option_text:SetEventScript(ui.LBUTTONUP, (addon_name_lower .. "_reroll_option_check"))
            option_text:SetEventScriptArgString(ui.LBUTTONUP, ScpArgMsg(cls.ClassName))
            local prev = g.need_options[option_name]
            if prev ~= nil and prev.is_check == 1 then
                option_text:SetCheck(1)
            end
            table.insert(g.hair_enchant_option_names, option_name)
            g.hair_enchant_option_labels[option_name] = OptionString
            g.hair_enchant_option_classes[option_name] = cls.ClassName
            oy = oy + 25
        end
    end
    -- 中身より枠が高いときに余白を作らないよう、実際の高さに合わせて縮める
    local option_box_height = math.min(max_box_height, oy + 5)
    option_box:Resize(385, option_box_height)
    option_box:EnableScrollBar(1)
    option_box:SetScrollPos(0)
    y = y + option_box_height + 8
    -- 組み直しで消えたオプション(上がったランクでは出なくなったもの)のチェックは、
    -- 画面に無い以上ここで落とす。残すと外せないチェックで止まり続ける
    for option_name in pairs(g.need_options) do
        if g.hair_enchant_option_labels[option_name] == nil then
            core_g.vlog("mini_addons: ヘアエンチャント %s ランクでは出ないオプションのチェックを外す(%s)",
                tostring(item_rank), tostring(g.need_options[option_name].text))
            g.need_options[option_name] = nil
        end
    end

    -- 素の演出(EFFECT_DURATION 0.5秒)を待たずに、結果が返った時点で次を撃つ。
    -- 1 回あたり 0.5 秒縮むが、素の演出と HoldUI が重なるので既定は OFF。
    -- **判定が古い状態を見る心配は無い**(結果が返ってから撃つことに変わりはない)。
    -- 崩れるのは見た目だけなので、承知のうえで使う人向けに UI から選べるようにしてある。
    -- 保存はしない。ウィンドウを開くたび OFF に戻す(付けっぱなしを忘れて
    -- 「演出が変」と後から悩まないようにするため)
    -- 名前の揃え方は mini_addons_p_reroll_option_check のコメントと同じ
    function mini_addons_p_hair_enchant_fast(gbox, ctrl)
        local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
        if reroll_option == nil then
            return
        end
        local on = ctrl:IsChecked() == 1
        reroll_option:SetUserValue("FAST", on and "yes" or "no")
        hair_enchant_mark_dirty()
        core_g.vlog("mini_addons: ヘアエンチャント 演出を待たずに実行 = %s", on and "ON" or "OFF")
    end
    y = y + 8
    local fast = gbox:CreateOrGetControl("checkbox", "fast_enchant", 10, y, 0, 20)
    AUTO_CAST(fast)
    fast:SetText("{ol}{#FF9900}" ..
                     (g.lang == "Japanese" and "演出を待たずに実行" or
                         "Run without waiting for the effect"))
    fast:SetTextTooltip(g.lang == "Japanese" and
                            "{ol}1 回あたり 0.5 秒ほど速くなります{nl}素の演出と重なるので見た目が乱れます{nl}希望オプションの判定は変わりません" or
                            "{ol}About 0.5s faster per attempt{nl}It overlaps the game's effect, so the animation looks rough{nl}Option matching is unaffected")
    fast:SetEventScript(ui.LBUTTONUP, (addon_name_lower .. "_hair_enchant_fast"))
    if reroll_option:GetUserValue("FAST") == "yes" then
        fast:SetCheck(1)
    end
    y = y + 27

    -- 名前の揃え方は mini_addons_p_reroll_option_check のコメントと同じ
    function mini_addons_p_hair_enchant_repeat(gbox, repeat_count)
        local count = tonumber(repeat_count:GetText())
        if count == nil then
            count = 0
        end
        if count < 0 then
            count = 0
        end
        if count > HAIR_ENCHANT_REPEAT_MAX then
            count = HAIR_ENCHANT_REPEAT_MAX
            repeat_count:SetText(tostring(count))
        end
        SET_REPEAT_COUNT_TEXT(count)
    end
    local repeat_count = gbox:CreateOrGetControl("edit", "repeat_count", 330, y, 60, 30)
    AUTO_CAST(repeat_count)
    repeat_count:SetTypingScp((addon_name_lower .. "_hair_enchant_repeat"))
    repeat_count:SetTextTooltip(g.lang == "Japanese" and
                                    string.format("{ol}リピート回数を入力(0〜%d){nl}0 は 1 回だけ",
            HAIR_ENCHANT_REPEAT_MAX) or
                                    string.format("{ol}Enter the repeat count (0-%d){nl}0 means once",
            HAIR_ENCHANT_REPEAT_MAX))
    repeat_count:SetFontName("white_16_ol")
    repeat_count:SetTextAlign("center", "center")
    repeat_count:SetNumberMode(1)
    -- 素の入力欄と同じ上限。入力の時点で止めるのが一番確実(下の判定でも念のため丸める)
    repeat_count:SetMinNumber(0)
    repeat_count:SetMaxNumber(HAIR_ENCHANT_REPEAT_MAX)
    repeat_count:SetMaxLen(string.len(tostring(HAIR_ENCHANT_REPEAT_MAX)))
    if prev_repeat_text ~= nil then
        -- 組み直し。停止判定が読む上限値なので、初期値へ戻さず入力済みの値を引き継ぐ
        repeat_count:SetText(prev_repeat_text)
    else
        -- **初期値に手持ちのスクロール数を入れないこと。** 何気なく押しただけで
        -- 全部溶ける形になる。全部使いたいときは隣の ALL ボタンで明示的に入れる。
        -- 0 は素に合わせた値。素の入力欄(hairenchant_option の repeatCnt)も
        -- INI_REPEAT_COUNT が 0 を入れており、素のループも 0 と 1 はどちらも
        -- 「1 回だけ」(cnt > 1 のときだけ続行)。こちらも 0 は 1 回として扱う
        repeat_count:SetText(0)
    end

    -- 手持ちのスクロール数を入れるボタン(以前 Cancel を置いていた場所)。
    -- 止める手段は素の付与ボタン(回している間は「停止」になる)と、この窓の × で足りる
    local all_btn = gbox:CreateOrGetControl("button", "repeat_all", 260, y, 60, 30)
    AUTO_CAST(all_btn)
    all_btn:SetSkinName("test_pvp_btn")
    all_btn:SetText("{ol}ALL")
    all_btn:SetTextTooltip(g.lang == "Japanese" and "{ol}手持ちの魔法付与スクロールの数を入れます" or
                               "{ol}Fill in the number of scrolls you have")
    all_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_hair_enchant_repeat_all")

    -- 「指定したランクまで回し続ける」。希望オプションのチェックの列に混ぜると
    -- 「オプションの 1 つ」に見えるので、リピート回数と同じ行の左の空きに
    -- ドロップリストとして置く(見た目でも役割が別だと分かるようにする)。
    --
    -- 選べるのは**今のランクより上だけ**。既に届いているランクを選べると、
    -- 止まる条件が最初から満たされていて意味を成さない(A のときは選択肢が
    -- 「指定なし」だけになる)。
    --
    -- 保存はしない(素の rank_up と同じく、窓を開くたび「指定なし」に戻る)。
    -- 選択は reroll_option の UserValue "RANK_UNTIL" に入れる。窓を作り直すたび
    -- 消えるので、既定は素の GetUserValue が返す "None" = 指定なし
    -- 名前の揃え方は mini_addons_p_reroll_option_check のコメントと同じ
    -- ドロップリストの項目から呼ばれる版。**手で選んだときだけ dirty を立てる**
    -- (組み立て末尾からの呼び直しは hair_enchant_apply_rank_until を直に使う)
    function mini_addons_p_hair_enchant_rank_until(rank)
        hair_enchant_mark_dirty()
        -- 手で選び直したときは、回している最中でも目標を差し替える
        -- (組み直しによる "None" 落ちと違い、これは利用者の意思表示)
        local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
        if reroll_option ~= nil then
            reroll_option:SetUserValue("RANK_GOAL", rank)
        end
        hair_enchant_apply_rank_until(rank)
    end
    hair_enchant_apply_rank_until = function(rank)
        local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
        if reroll_option == nil then
            return
        end
        reroll_option:SetUserValue("RANK_UNTIL", rank)
        -- ランクを指定している間、希望オプションは見に行かない(下の停止判定を参照)ので、
        -- 押せるまま残すと「チェックしたのに止まらない」不具合に見える。灰色にして塞ぐ。
        -- 「ランク指定なし」へ戻したら元の表示に戻す。チェックの入り切り自体は
        -- 触らないので、戻したときに選び直す必要はない
        local disabled = hair_enchant_rank_index(rank) ~= nil
        local gbox = GET_CHILD_RECURSIVELY(reroll_option, "gbox")
        for _, option_name in ipairs(g.hair_enchant_option_names or {}) do
            local option_text = gbox and GET_CHILD_RECURSIVELY(gbox, option_name)
            if option_text ~= nil then
                AUTO_CAST(option_text)
                option_text:SetEnable(disabled and 0 or 1)
                option_text:EnableHitTest(disabled and 0 or 1)
                local label = g.hair_enchant_option_labels[option_name]
                if label ~= nil then
                    -- SetEnable(0) だけではキャプションの色が変わらない土台があるので、
                    -- 色タグでも灰色にしておく
                    option_text:SetText((disabled and "{ol}{#888888}" or "{ol}") .. label)
                end
            end
        end
        -- 素の「ランクアップ時に停止」も、目標ランク指定中は見に行かないので灰色にする
        hair_enchant_set_rank_up_enabled(not disabled)
        core_g.vlog("mini_addons: ヘアエンチャント 目標ランク = %s(希望オプションのチェック %d 件と素のランクアップ停止を%s)",
            rank == "None" and "指定なし" or rank, #(g.hair_enchant_option_names or {}),
            disabled and "無効化" or "有効化")
    end
    local rank_until = gbox:CreateOrGetControl("droplist", "rank_until", 10, y + 5, 240, 20)
    AUTO_CAST(rank_until)
    rank_until:SetSkinName("droplist_normal")
    rank_until:EnableHitTest(1)
    rank_until:SetTextAlign("center", "center")
    rank_until:SetTextTooltip(g.lang == "Japanese" and
                                  "{ol}ランクを選ぶと、そのランクへ届くまで回し続けます{nl}(希望オプションが付いても止めません)" or
                                  "{ol}Pick a rank to keep going until the item reaches it{nl}(desired options will not stop it)")
    rank_until:AddItem(0, "{ol}" .. (g.lang == "Japanese" and "ランク指定なし" or "No target rank"), 0,
        string.format("%s_hair_enchant_rank_until('None')", addon_name_lower))
    local now_index = hair_enchant_rank_index(item_rank)
    -- 組み直しのときは選んでいた目標ランクを選び直す。ランクが上がると選択肢が減る
    -- (今のランク以下は出さない)ので、番号ではなくランク名で照合すること
    local keep_rank = reroll_option:GetUserValue("RANK_UNTIL")
    local keep_index = 0
    if now_index ~= nil then
        for i = now_index + 1, #hair_enchant_rank_order do
            local target = hair_enchant_rank_order[i]
            rank_until:AddItem(i - now_index, "{ol}" ..
                string.format(g.lang == "Japanese" and "%s ランクまで回す" or "Until rank %s", target), 0,
                string.format("%s_hair_enchant_rank_until('%s')", addon_name_lower, target))
            if target == keep_rank then
                keep_index = i - now_index
            end
        end
    end
    -- **preset_list と同じく、SelectItem が項目のスクリプトを走らせうる。**
    -- rank_until の項目スクリプトは先頭で dirty を立てるので、抑えずに呼ぶと
    -- 組み直すたびに「手で変えた」扱いになり、プリセットの入れ直し
    -- (低いランクで落ちたチェックを上のランクで戻す)が二度と効かなくなる
    hair_enchant_suppress_dirty = true
    rank_until:SelectItem(keep_index)
    hair_enchant_suppress_dirty = false
    -- 選択に合わせて希望オプションの有効 / 無効(灰色)も揃える。SelectItem が
    -- 項目のスクリプトを走らせるかは土台任せなので、ここで必ず 1 回通しておく。
    -- 引き継げなかった(選択肢から消えた)ときは "None" に落として指定なしへ戻す。
    -- **組み立ての一部なので dirty は立てない版を呼ぶこと**(立てると、組み直しただけで
    -- 「手で変えた」扱いになり、プリセットの入れ直しが効かなくなる)
    hair_enchant_apply_rank_until(keep_index == 0 and "None" or keep_rank)

    y = y + 30
    reroll_option:Resize(400, y + 45)
    gbox:Resize(reroll_option:GetWidth(), reroll_option:GetHeight() - 40)
    -- 高さが決まってから、下がはみ出さない位置へ寄せる。組み直しで背が伸びることも
    -- あるので、開いたときだけでなくここで毎回見ること
    local max_y = ui.GetClientInitialHeight() - reroll_option:GetHeight()
    if max_y < 0 then
        max_y = 0
    end
    if reroll_option:GetY() > max_y then
        reroll_option:SetPos(reroll_option:GetX(), max_y)
    end
    -- 「何を元に組んだか」を最後に記録する。これが hair_enchant_refresh_if_changed の
    -- 比較対象になるので、組み直したら必ず更新すること(忘れると毎回組み直し続ける)
    reroll_option:SetUserValue("BUILD_SIG", hair_enchant_build_signature(item_grade, item_rank))
end

