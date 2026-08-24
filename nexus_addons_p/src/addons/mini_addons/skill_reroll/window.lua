-- スキル錬成の「高度な設定」窓。希望スキル(と最低レベル)・リピート回数・プリセットを持つ。
--
-- **画面から呼ぶグローバル関数の名前は addon_name_lower から組み立てている。**
-- SetEventScript / 項目のスクリプトは文字列で名前を渡すので、ここの定義名
-- (mini_addons_p_...)と呼び出し側の組み立てが必ず揃っていること
-- (ヘアエンチャントを移したときにここだけ食い違い、チェックが一切拾われずに
--  「希望のものが出ても止まらない」形で出たことがある)。

-- プリセットの入れ物。**配列**(1 始まり)で、枠数は決めない
skill_reroll.presets = function()
    local presets = g.settings.skill_reroll_presets
    if type(presets) ~= "table" then
        presets = {}
        g.settings.skill_reroll_presets = presets
    end
    return presets
end

-- 組み立て中の SelectItem が項目のスクリプトを走らせても読み込みに行かせないための印。
-- 読み込むと窓を組み直すので、抑えないと止まらなくなる
skill_reroll.suppress_preset_sel = false

-- 窓を組み直して、プリセット一覧やチェックの状態を今の設定に合わせる
skill_reroll.rebuild = function()
    local adv = ui.GetFrame(addon_name_lower .. "skill_reroll")
    if adv == nil then
        return
    end
    local guid, obj = skill_reroll.item()
    if guid == nil then
        return
    end
    skill_reroll.build_body(adv, guid, obj)
end

-- ドロップリストで選んだプリセット(1 始まり。0 は「プリセットなし」)。
-- **選んだらその場で読み込む**(読込ボタンは置いていない)
function mini_addons_p_skill_reroll_preset_sel(index)
    local adv = ui.GetFrame(addon_name_lower .. "skill_reroll")
    if adv == nil then
        return
    end
    adv:SetUserValue("PRESET_SEL", tostring(index))
    if skill_reroll.suppress_preset_sel or index == 0 then
        return
    end
    -- **この場で読み込まないこと。** 読み込むと窓を組み直す = 今このスクリプトを
    -- 走らせているドロップリスト自身を RemoveAllChild で壊すことになる。1 拍遅らせる
    ReserveScript(string.format("%s_skill_reroll_preset_load_deferred()", addon_name_lower), 0.1)
end

function mini_addons_p_skill_reroll_preset_load_deferred()
    Mini_addons_skill_reroll_preset_load()
end

-- 保存。名前を訊くポップアップ(素の inputstring)を出す。
-- 選択中のプリセットがあればその名前を初期値にするので、そのまま決定すれば上書きになる
function Mini_addons_skill_reroll_preset_save_open(parent, ctrl)
    local adv = ui.GetFrame(addon_name_lower .. "skill_reroll")
    if adv == nil then
        return
    end
    local presets = skill_reroll.presets()
    local sel = tonumber(adv:GetUserValue("PRESET_SEL")) or 0
    local inputstring = ui.GetFrame("inputstring")
    if inputstring == nil then
        core_g.vlog("mini_addons: スキル錬成 inputstring が無いのでプリセット名を訊けない")
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
    confirm:SetEventScript(ui.LBUTTONUP, "Mini_addons_skill_reroll_preset_save_do")
    edit:SetEventScript(ui.ENTERKEY, "Mini_addons_skill_reroll_preset_save_do")
    inputstring:ShowWindow(1)
    inputstring:SetEnable(1)
    edit:AcquireFocus()
end

-- ポップアップで決定された。今の窓の状態を、その名前で保存する。
-- **希望スキルはクラス名で持つ**(理由は core.lua の g.skill_reroll_wanted のコメント)
function Mini_addons_skill_reroll_preset_save_do(frame, ctrl)
    if frame == nil or frame:GetName() ~= "inputstring" then
        return
    end
    local adv = ui.GetFrame(addon_name_lower .. "skill_reroll")
    if adv == nil then
        frame:ShowWindow(0)
        return
    end
    local name = GET_INPUT_STRING_TXT(frame)
    if name == nil or name == "" then
        ui.SysMsg(g.lang == "Japanese" and "プリセットの名前を入力してください" or "Enter a preset name")
        return
    end
    -- 保存する前に画面を写し直す(画面のチェックがそのまま保存されるように)
    skill_reroll.sync_from_screen()
    local skills = {}
    for class_name, want in pairs(g.skill_reroll_wanted or {}) do
        -- **チェックの入っているものだけ保存する。** 表にはチェックを外した行も
        -- (最低レベルを覚えるために)残っているので、そのまま書くと外したはずの
        -- スキルが復活する
        if want.is_check == 1 then
            table.insert(skills, {
                class = class_name,
                min_lv = tonumber(want.min_lv) or 0
            })
        end
    end
    -- 保存のたびに並びが変わると差分が読みにくいので固定する
    table.sort(skills, function(a, b)
        return a.class < b.class
    end)
    local repeat_count = GET_CHILD_RECURSIVELY(adv, "repeat_count")
    local entry = {
        name = name,
        skills = skills,
        repeat_count = repeat_count ~= nil and tonumber(repeat_count:GetText()) or nil
    }
    local presets = skill_reroll.presets()
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
    adv:SetUserValue("PRESET_SEL", tostring(at))
    Mini_addons_save_settings()
    core_g.vlog("mini_addons: スキル錬成 プリセット「%s」を%s(希望スキル %d 件)", name,
        at == #presets and "追加" or "上書き", #skills)
    ui.SysMsg(string.format(g.lang == "Japanese" and "プリセット「%s」を保存しました" or "Saved preset \"%s\"",
        name))
    frame:ShowWindow(0)
    skill_reroll.rebuild()
end

-- 読込。**保存内容が真**なので、今のチェックは捨ててから入れ直す
function Mini_addons_skill_reroll_preset_load()
    local adv = ui.GetFrame(addon_name_lower .. "skill_reroll")
    if adv == nil then
        return
    end
    local presets = skill_reroll.presets()
    local preset = presets[tonumber(adv:GetUserValue("PRESET_SEL")) or 0]
    if preset == nil then
        return
    end
    g.skill_reroll_wanted = {}
    for _, entry in ipairs(preset.skills or {}) do
        if type(entry) == "table" and entry.class ~= nil then
            local min_lv = tonumber(entry.min_lv) or 1
            if min_lv < 1 then
                min_lv = 1 -- 旧い設定(0 = レベル不問)を今の表し方へ寄せる
            end
            g.skill_reroll_wanted[entry.class] = {
                is_check = 1,
                min_lv = min_lv
            }
        end
    end
    if preset.repeat_count ~= nil then
        local want = tonumber(preset.repeat_count) or 0
        if want > skill_reroll.REPEAT_MAX then
            want = skill_reroll.REPEAT_MAX
        end
        adv:SetUserValue("REPEAT_TEXT", tostring(want))
    end
    core_g.vlog("mini_addons: スキル錬成 プリセット「%s」を読込(希望スキル %d 件 / リピート回数 %s)",
        tostring(preset.name), #(preset.skills or {}), tostring(preset.repeat_count))
    skill_reroll.rebuild()
end

function mini_addons_p_skill_reroll_preset_delete_do()
    local adv = ui.GetFrame(addon_name_lower .. "skill_reroll")
    if adv == nil then
        return
    end
    local presets = skill_reroll.presets()
    local sel = tonumber(adv:GetUserValue("PRESET_SEL")) or 0
    local preset = presets[sel]
    if preset == nil then
        return
    end
    table.remove(presets, sel)
    -- 消した後は「--」へ戻す。詰めた結果の別のプリセットが選ばれた状態にすると、
    -- 名前は出ているのにチェックはさっきのまま、という食い違いになる
    adv:SetUserValue("PRESET_SEL", "0")
    Mini_addons_save_settings()
    core_g.vlog("mini_addons: スキル錬成 プリセット「%s」を削除(残り %d 件)", tostring(preset.name), #presets)
    skill_reroll.rebuild()
end

-- 削除。押し間違いで消えると戻せないので確認を挟む
function Mini_addons_skill_reroll_preset_delete(parent, ctrl)
    local adv = ui.GetFrame(addon_name_lower .. "skill_reroll")
    if adv == nil then
        return
    end
    local presets = skill_reroll.presets()
    local preset = presets[tonumber(adv:GetUserValue("PRESET_SEL")) or 0]
    if preset == nil then
        return
    end
    ui.MsgBox(string.format(g.lang == "Japanese" and "{#FFFFFF}{ol}プリセット「%s」を削除しますか？" or
                                "{#FFFFFF}{ol}Delete preset \"%s\"?", tostring(preset.name)),
        string.format("%s_skill_reroll_preset_delete_do()", addon_name_lower), "None")
end

-- 希望スキルの 1 件を引く(無ければ作る)。**チェックを外しても行は消さない**ので、
-- 最低レベルの入力値はそのまま残る(判定に使うのは is_check だけ。core.lua を参照)
skill_reroll.want = function(class_name)
    local want = g.skill_reroll_wanted[class_name]
    if want == nil then
        want = {
            is_check = 0,
            -- **既定は 1(= レベルを問わない)。** スキルのレベルは 1 から始まるので、
            -- 「1 以上で止まる」と「レベル不問」は同じ意味になる。0 を既定にすると
            -- 「0 は何を指すのか」を説明しないと分からない値が画面に出る
            min_lv = 1
        }
        g.skill_reroll_wanted[class_name] = want
    end
    return want
end

-- 希望スキルのチェック。
--
-- **渡ってくる ctrl を当てにしないこと。** 実機で、押した行とは別の行のコントロールが
-- イベントを受け取ることがあった(アインソフを押したのに
-- 「Common_Chronomancer_Pass = OFF」が届き、画面はアインソフにチェックが付いたまま)。
-- 名前から希望スキルを決めていたため、**画面に入っているのに表には無い**チェックができ、
-- 全解除の件数が合わないうえ、当たっても止まらない状態になっていた。
-- 一覧全体を画面から読み直せば、どのコントロールがイベントを受けても結果は同じになる
-- (48 行の読み取りは押したときだけなので、これで十分軽い)
function mini_addons_p_skill_reroll_wanted_check(gbox, ctrl)
    skill_reroll.sync_from_screen(true)
    -- チェックの数で「全解除」の押せる / 押せないが変わる
    skill_reroll.sync_clear_btn()
end

-- 最低レベルの入力。**チェックが入っていないときも覚えておくこと。**
-- ここで捨てると、先にレベルを打ってからチェックを入れる順のときに、
-- 窓の組み直しで打った値が黙って 0 へ戻る
-- 最低レベルのボタン。**数値入力にしないこと。** 取りうる値は 1〜5(一部 1〜3)しかなく、
-- そのために桁を打たせるのは手間が勝つ。押すたびに 1 つ動かし、上限まで行ったら
-- 1 へ戻る(右クリックは逆回り)。素にスライダー(slidebar)はあるが、**上限 / 下限は
-- どれも XML の maxlevel / minlevel で決めていて Lua から設定している箇所が
-- クライアント全体に無い**ため、プログラム生成では 1〜5 に絞れる保証が無い。
-- 上限はスキルごとに違うので、ボタンの引数ではなく表から引き直すこと
skill_reroll.lv_step = function(ctrl, step)
    AUTO_CAST(ctrl)
    -- **名前ではなく、作るときに持たせたクラス名を使う**(上のチェックと同じ理由で、
    -- コントロールの名前から決める作りは当てにできない)
    local class_name = ctrl:GetUserValue("CLASS")
    if class_name == nil or class_name == "None" then
        class_name = string.sub(ctrl:GetName(), 4) -- 念のための保険。"lv_" を落とす
    end
    local want = skill_reroll.want(class_name)
    local max_lv = tonumber(ctrl:GetUserValue("MAX_LV")) or 1
    local now = tonumber(want.min_lv) or 1
    if now < 1 then
        now = 1 -- 旧い設定(0 = レベル不問)を今の表し方へ寄せる
    end
    now = now + step
    if now > max_lv then
        now = 1
    elseif now < 1 then
        now = max_lv
    end
    want.min_lv = now
    ctrl:SetText(string.format("{ol}Lv%d", now))
    core_g.vlog("mini_addons: スキル錬成 希望スキル %s の最低レベル = %d(上限 %d)", tostring(class_name), now,
        max_lv)
end

function mini_addons_p_skill_reroll_lv_up(gbox, ctrl)
    skill_reroll.lv_step(ctrl, 1)
end

function mini_addons_p_skill_reroll_lv_down(gbox, ctrl)
    skill_reroll.lv_step(ctrl, -1)
end

-- **画面のチェックを表(g.skill_reroll_wanted)へ写し直す。**
--
-- 表を更新しているのはチェックのイベント(mini_addons_p_skill_reroll_wanted_check)だが、
-- **画面には入っているのに表に無い**ことが実際に起きた(6 件チェックしたのに
-- 全解除の確認は 4 件)。表に無い希望は停止判定でも見に行かないので、当たっても
-- 止まらないことになる。**画面を正**として、数える前・回し始める前・保存する前に
-- ここを通す。イベントが取りこぼされていても、押した通りに効く。
--
-- 食い違いが見つかったら中身をログに出す(何が取りこぼされているのかを実機で追うため)。
-- 食い違いが無いときは何も出さない(毎回通る経路なのでログを流さないこと)
-- from_click … チェックを押した流れから呼んだか。押したときは**その 1 件が動くのが正常**
-- なので普通のログにし、それ以外(件数を数える前・回し始める前・保存する前)の変化と、
-- 押したのに 1 件も動かない / 2 件以上動いたときだけ警告として出す
skill_reroll.sync_from_screen = function(from_click)
    local adv = ui.GetFrame(addon_name_lower .. "skill_reroll")
    if adv == nil then
        return
    end
    local fixed = {}
    for _, class_name in ipairs(g.skill_reroll_shown or {}) do
        local check = GET_CHILD_RECURSIVELY(adv, "want_" .. class_name)
        if check ~= nil then
            AUTO_CAST(check)
            local on = check:IsChecked() == 1 and 1 or 0
            local want = skill_reroll.want(class_name)
            if want.is_check ~= on then
                want.is_check = on
                table.insert(fixed, string.format("%s=%s", class_name, on == 1 and "ON" or "OFF"))
            end
        end
    end
    if from_click and #fixed == 1 then
        -- 押した 1 件が動いた = 正常
        core_g.vlog("mini_addons: スキル錬成 希望スキル %s", fixed[1])
    elseif from_click and #fixed == 0 then
        -- 押したのに画面も表も変わっていない。取りこぼしの目印になる
        core_g.vlog("{#FF6347}mini_addons: スキル錬成 チェックを押したのに変化が無い{/}")
    elseif #fixed > 0 then
        core_g.vlog("{#FF6347}mini_addons: スキル錬成 画面のチェックと表が食い違っていたので画面に合わせた(%d 件): %s{/}",
            #fixed, table.concat(fixed, ", "))
    end
    return #fixed
end

-- チェックの入っている希望スキルの数。**表にはチェックを外した行も残る**
-- (最低レベルを覚えるため)ので、数えるときは必ず is_check を見ること
skill_reroll.wanted_count = function()
    local n = 0
    for _, want in pairs(g.skill_reroll_wanted or {}) do
        if want.is_check == 1 then
            n = n + 1
        end
    end
    return n
end

-- 「全解除」の有効 / 無効を今のチェック数に合わせる。
-- **チェックを入れ切りするたびに呼ぶこと。** 組み立てのときだけ決めていたため、
-- チェックを入れても押せないままだった(組み直しは走らないので誰も揃え直さない)
skill_reroll.sync_clear_btn = function()
    local adv = ui.GetFrame(addon_name_lower .. "skill_reroll")
    if adv == nil then
        return
    end
    local clear_btn = GET_CHILD_RECURSIVELY(adv, "wanted_clear")
    if clear_btn == nil then
        return
    end
    AUTO_CAST(clear_btn)
    local on = skill_reroll.wanted_count() > 0
    clear_btn:SetEnable(on and 1 or 0)
    clear_btn:EnableHitTest(on and 1 or 0)
end

-- 一括 OFF。**最低レベルは消さない**(もう一度チェックを入れたときに、前に決めた
-- レベルがそのまま戻る方が手間が少ない)。プリセットとは別物なので設定は保存しない
function mini_addons_p_skill_reroll_clear_do()
    local cleared = 0
    for _, want in pairs(g.skill_reroll_wanted or {}) do
        if want.is_check == 1 then
            want.is_check = 0
            cleared = cleared + 1
        end
    end
    core_g.vlog("mini_addons: スキル錬成 希望スキルのチェックを %d 件まとめて外した", cleared)
    ui.SysMsg(string.format(g.lang == "Japanese" and "希望スキルのチェックを %d 件外しました" or
                                "Cleared %d wanted skills", cleared))
    skill_reroll.rebuild()
end

-- 全解除ボタン。**確認を挟む。** 10 件近く入れた後の押し間違いは戻すのが面倒で、
-- 戻せるのは(保存してあれば)プリセットの読み直しだけになる
function Mini_addons_skill_reroll_clear(parent, ctrl)
    -- 数える前に画面を写し直す(件数と画面が食い違わないように)
    skill_reroll.sync_from_screen()
    local names, classes = {}, {}
    for class_name, want in pairs(g.skill_reroll_wanted or {}) do
        if want.is_check == 1 then
            -- 画面へ出す名前は素の辞書 ID(@dicID_…)で、解決するのはクライアント側。
            -- **ログにはクラス名を出すこと**(辞書 ID のままだと後から読めない)
            table.insert(names, skill_reroll.skill_name(class_name))
            table.insert(classes, class_name)
        end
    end
    if #names < 1 then
        return
    end
    -- **何を外すのか名前で見せる。** 一覧はスクロールするので、画面に出ていない行の
    -- チェックまで数に入る。件数だけ出すと「数が合わない」と見える
    table.sort(names)
    local shown = names
    local rest = 0
    local LIST_MAX = 10
    if #names > LIST_MAX then
        shown = {}
        for i = 1, LIST_MAX do
            table.insert(shown, names[i])
        end
        rest = #names - LIST_MAX
    end
    local list = table.concat(shown, "{nl}・")
    if rest > 0 then
        list = list .. string.format(g.lang == "Japanese" and "{nl}ほか %d 件" or "{nl}and %d more", rest)
    end
    table.sort(classes)
    core_g.vlog("mini_addons: スキル錬成 全解除の確認(%d 件): %s", #names, table.concat(classes, ", "))
    ui.MsgBox(string.format(g.lang == "Japanese" and
                                "{#FFFFFF}{ol}次の %d 件のチェックを外しますか？{nl}・%s" or
                                "{#FFFFFF}{ol}Clear these %d wanted skills?{nl}- %s", #names, list),
        string.format("%s_skill_reroll_clear_do()", addon_name_lower), "None")
end

-- アイテムを乗せたら自動で開く設定。アドオンの設定ファイルへ保存する
function mini_addons_p_skill_reroll_auto_open(gbox, ctrl)
    g.settings.skill_reroll_auto_open = ctrl:IsChecked() == 1 and 1 or 0
    Mini_addons_save_settings()
    core_g.vlog("mini_addons: スキル錬成 自動で開く = %s", g.settings.skill_reroll_auto_open == 1 and "ON" or "OFF")
end

-- リピート回数の入力。上限で丸める
function mini_addons_p_skill_reroll_repeat(gbox, ctrl)
    local count = tonumber(ctrl:GetText())
    if count == nil or count < 0 then
        return
    end
    if count > skill_reroll.REPEAT_MAX then
        ctrl:SetText(tostring(skill_reroll.REPEAT_MAX))
    end
end

-- ALL ボタン。**手持ちの素材で回せる回数**を入れる(素材の少ない方に合わせる)。
-- 窓を開いたときの初期値は 0(= 1 回)なので、全部使うのはここを押したときだけ
function Mini_addons_skill_reroll_repeat_all(parent, ctrl)
    local adv = ui.GetFrame(addon_name_lower .. "skill_reroll")
    if adv == nil then
        return
    end
    local guid, obj = skill_reroll.item()
    if guid == nil then
        return
    end
    local repeat_count = GET_CHILD_RECURSIVELY(adv, "repeat_count")
    if repeat_count == nil then
        return
    end
    local can = skill_reroll.affordable(obj)
    if can == nil or can < 1 then
        can = 1
    end
    if can > skill_reroll.REPEAT_MAX then
        can = skill_reroll.REPEAT_MAX
    end
    repeat_count:SetText(tostring(can))
    core_g.vlog("mini_addons: スキル錬成 ALL でリピート回数に %d(手持ちの素材で回せる回数)を入れた", can)
end

-- 実行状況の 1 行を書き換える。回していないときは素材の残りを出す
function Mini_addons_skill_reroll_status(text)
    local adv = ui.GetFrame(addon_name_lower .. "skill_reroll")
    if adv == nil then
        return
    end
    local status = GET_CHILD_RECURSIVELY(adv, "status_text")
    if status == nil then
        return
    end
    status:SetText("{ol}" .. tostring(text))
end

skill_reroll.open_advanced = function()
    local frame = ui.GetFrame("common_skill_enchant")
    if frame == nil or frame:IsVisible() == 0 then
        return
    end
    local guid, obj = skill_reroll.item()
    if guid == nil then
        -- アイテムが乗っていないと、出うるスキルも素材の数も決まらない
        core_g.vlog("mini_addons: スキル錬成 高度な設定を開けない(アイテムが乗っていない)")
        return
    end
    core_g.vlog("mini_addons: スキル錬成 高度な設定を開く")
    local adv = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "skill_reroll", 0, 0, 0, 0)
    AUTO_CAST(adv)
    adv:SetSkinName("test_Item_tooltip_equip")
    adv:SetGravity(ui.LEFT, ui.TOP)
    adv:SetLayerLevel(100)
    -- **窓の余白でクリックが素通りしないようにする。** これが無いと、コントロールの
    -- 載っていない所を押したときにクリックが後ろへ抜けて、背後のものが反応してしまう
    adv:EnableHittestFrame(1)
    -- gbox とその中身は skill_reroll.build_body が作る(装備を差し替えたらそこだけ
    -- 組み直すため)。close ボタンは gbox の外なので組み直しの対象外
    local close = adv:CreateOrGetControl("button", "close", 0, 0, 30, 30)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.LEFT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Mini_addons_skill_reroll_adv_close")
    skill_reroll.build_body(adv, guid, obj)
    adv:ShowWindow(1)
    -- 素の窓の位置へ寄せる。以降は監視スクリプトが追随する
    Mini_addons_skill_reroll_watch(adv)
    adv:RunUpdateScript("Mini_addons_skill_reroll_watch", 0.3)
end

-- 窓の中身(プリセット / 自動で開く / 希望スキル一覧 / リピート回数 / 実行状況)を組む。
-- 組み直しても壊れないように、次の 2 つは引き継ぐこと:
--   * 希望スキルのチェックと最低レベル … g.skill_reroll_wanted(Lua 側の表)から戻す
--   * リピート回数の入力値             … 停止判定が読んでいる。消すと止まらなくなる
skill_reroll.build_body = function(adv, guid, obj)
    local jp = g.lang == "Japanese"
    local gbox = adv:CreateOrGetControl("groupbox", "gbox", 0, 40, 0, 0)
    AUTO_CAST(gbox)
    gbox:SetSkinName("None")
    -- 組み直す前に、消えると困る入力値を控える。プリセットの読込で入れ直したいときは
    -- UserValue "REPEAT_TEXT" に置かれているので、そちらを優先する
    local prev_repeat = GET_CHILD_RECURSIVELY(gbox, "repeat_count")
    local prev_repeat_text = prev_repeat ~= nil and prev_repeat:GetText() or nil
    local forced_repeat = adv:GetUserValue("REPEAT_TEXT")
    if forced_repeat ~= nil and forced_repeat ~= "None" and forced_repeat ~= "" then
        prev_repeat_text = forced_repeat
        adv:SetUserValue("REPEAT_TEXT", "None")
    end
    gbox:RemoveAllChild()

    local y = 5
    -- プリセットは 1 行にまとめる(ドロップリスト + 保存 + 削除)。**縦を食わないこと**を
    -- 優先している(希望スキルの一覧を押し下げないため)
    local presets = skill_reroll.presets()
    local sel = tonumber(adv:GetUserValue("PRESET_SEL")) or 0
    if presets[sel] == nil then
        sel = 0
    end
    adv:SetUserValue("PRESET_SEL", tostring(sel))
    local preset_list = gbox:CreateOrGetControl("droplist", "preset_list", 10, y + 2, 245, 20)
    AUTO_CAST(preset_list)
    preset_list:SetSkinName("droplist_normal")
    preset_list:EnableHitTest(1)
    preset_list:SetTextAlign("center", "center")
    preset_list:SetTextTooltip(jp and "{ol}選ぶとその場で読み込みます" or "{ol}Selecting one loads it right away")
    -- **先頭は常に「--」(未選択)。** 先頭を 1 件目のプリセットにすると、窓を開いた直後に
    -- 「プリセット名が出ているのにチェックは入っていない」という食い違った見え方になる
    preset_list:AddItem(0, "{ol}" .. (#presets == 0 and (jp and "-- プリセットなし --" or "-- No presets --") or "--"),
        0, string.format("%s_skill_reroll_preset_sel(0)", addon_name_lower))
    for i, preset in ipairs(presets) do
        preset_list:AddItem(i, "{ol}" .. tostring(preset.name), 0,
            string.format("%s_skill_reroll_preset_sel(%d)", addon_name_lower, i))
    end
    -- **SelectItem は項目のスクリプトを走らせうる。** 選んだら読み込む作りなので、
    -- 組み立て中に走ると「読込 → 組み直し → SelectItem → 読込」で止まらなくなる
    skill_reroll.suppress_preset_sel = true
    preset_list:SelectItem(sel)
    skill_reroll.suppress_preset_sel = false
    local save_btn = gbox:CreateOrGetControl("button", "preset_save", 265, y, 65, 25)
    AUTO_CAST(save_btn)
    save_btn:SetSkinName("test_pvp_btn")
    save_btn:SetText("{ol}" .. (jp and "保存" or "Save"))
    -- **項目を増減したら、ここと Mini_addons_skill_reroll_preset_save_do の中身を
    -- 必ず揃えること**(説明だけ古くなると、入っているつもりの設定が入らない)
    save_btn:SetTextTooltip(jp and
                                "{ol}今の設定に名前を付けて保存します{nl}保存する内容:{nl}・希望スキルのチェックと最低レベル{nl}・リピート回数{nl}同じ名前があれば上書きします" or
                                "{ol}Save the current settings under a name{nl}What is saved:{nl}- Wanted skills and their minimum level{nl}- Repeat count{nl}Overwrites if the name exists")
    save_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_skill_reroll_preset_save_open")
    local del_btn = gbox:CreateOrGetControl("button", "preset_delete", 340, y, 65, 25)
    AUTO_CAST(del_btn)
    del_btn:SetSkinName("test_red_button")
    del_btn:SetText("{ol}" .. (jp and "削除" or "Delete"))
    del_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_skill_reroll_preset_delete")
    -- 消す対象が決まっていないと押せない(「--」を選んでいるときは何も消せない)
    del_btn:SetEnable(presets[sel] ~= nil and 1 or 0)
    y = y + 30

    local auto_open = gbox:CreateOrGetControl("checkbox", "auto_open", 10, y, 0, 20)
    AUTO_CAST(auto_open)
    auto_open:SetText("{ol}" .. (jp and "アイテムを乗せたら自動で開く" or "Open automatically when an item is placed"))
    auto_open:SetTextTooltip(jp and "{ol}スキル錬成の窓にアイテムを乗せた時点でこの窓を開きます{nl}この設定は保存されます" or
                                 "{ol}Opens this window once an item is placed{nl}This setting is saved")
    auto_open:SetEventScript(ui.LBUTTONUP, (addon_name_lower .. "_skill_reroll_auto_open"))
    auto_open:SetCheck(g.settings.skill_reroll_auto_open == 1 and 1 or 0)
    y = y + 28

    local head = gbox:CreateOrGetControl("richtext", "wanted_head", 10, y, 0, 20)
    -- **右端の「全解除」ボタン(x=340)と重ならない長さにすること。** 見出しは幅 0 =
    -- 文字なりに伸びるので、説明を足すならツールチップ側へ回す
    head:SetText("{ol}" .. (jp and "希望スキル(右＝最低レベル)" or "Wanted skills (right = min level)"))
    head:SetTextTooltip(jp and
                            "{ol}チェックを入れたスキルが出たら止まります{nl}右のボタンは最低レベル(左クリックで上げ、右クリックで下げ){nl}Lv1 はレベルを問いません" or
                            "{ol}Stops when a checked skill shows up{nl}The button on the right is the minimum level (left click steps up, right click steps down){nl}Lv1 means any level")
    local clear_btn = gbox:CreateOrGetControl("button", "wanted_clear", 340, y - 3, 70, 24)
    AUTO_CAST(clear_btn)
    clear_btn:SetSkinName("test_red_button")
    clear_btn:SetText("{ol}" .. (jp and "全解除" or "Clear"))
    clear_btn:SetTextTooltip(jp and "{ol}チェックの入っている希望スキルをまとめて外します{nl}最低レベルの設定は残ります" or
                                 "{ol}Clear every checked skill at once{nl}The minimum levels are kept")
    clear_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_skill_reroll_clear")
    -- 外す対象が無いときは押せない(押しても何も起きないボタンを押させない)。
    -- 以降はチェックを入れ切りするたびに同じ関数で揃え直す
    skill_reroll.sync_clear_btn()
    y = y + 22

    -- **希望スキルはスクロール枠へ入れる。** 一覧は数十件あり、そのまま縦に積むと
    -- 窓が画面の高さを超えて、下のリピート回数が画面外へ出てしまう。
    -- 枠の高さは画面から決める(窓全体が画面の 8 割に収まるように残りを割り当てる)
    local max_box_height = math.floor(ui.GetClientInitialHeight() * 0.8) - y - skill_reroll.BOTTOM_HEIGHT
    if max_box_height < 120 then
        max_box_height = 120 -- 極端に低い解像度でも、数行は見えるようにする
    end
    local option_box = gbox:CreateOrGetControl("groupbox", "option_box", 5, y, 415, max_box_height)
    AUTO_CAST(option_box)
    option_box:SetSkinName("test_frame_midle_light")
    local skills = skill_reroll.skill_list(obj)
    local oy = 5
    for _, skill in ipairs(skills) do
        -- **コントロール名にクラス名をそのまま使う。** 並びは表示名順なので、番号で
        -- 名前を付けると辞書が変わっただけで別のスキルの設定を読むことになる
        -- **行の送り(skill_reroll.ROW_STEP)より低い高さで作ること。** 押した行とは別の行の
        -- コントロールがイベントを受け取る事象があり、当たり判定が縦に重なっているのが
        -- 疑わしいため、隙間を広めに取っている(実寸はスキン任せで測れないので、
        -- 指定できる分だけ離す)。狭めるときは実機で必ず確かめること
        local check = option_box:CreateOrGetControl("checkbox", "want_" .. skill.class_name, 5, oy, 0, 22)
        AUTO_CAST(check)
        check:SetText("{ol}" .. skill.name)
        check:SetEventScript(ui.LBUTTONUP, (addon_name_lower .. "_skill_reroll_wanted_check"))
        local want = g.skill_reroll_wanted[skill.class_name]
        check:SetCheck((want ~= nil and want.is_check == 1) and 1 or 0)
        local max_lv = skill.max_lv > 0 and skill.max_lv or 5
        local min_lv = (want ~= nil and tonumber(want.min_lv)) or 1
        if min_lv < 1 then
            min_lv = 1 -- 旧い設定(0 = レベル不問)
        end
        if min_lv > max_lv then
            min_lv = max_lv -- 上限が下がった / 別のスキルから引き継いだ値への保険
        end
        local lv_btn = option_box:CreateOrGetControl("button", "lv_" .. skill.class_name, 330, oy - 1, 55, 24)
        AUTO_CAST(lv_btn)
        lv_btn:SetSkinName("test_pvp_btn")
        lv_btn:SetText(string.format("{ol}Lv%d", min_lv))
        -- 上限はスキルごとに違う。押されたときに引き直せるよう、コントロールに持たせる
        lv_btn:SetUserValue("MAX_LV", tostring(max_lv))
        lv_btn:SetUserValue("CLASS", skill.class_name)
        lv_btn:SetEventScript(ui.LBUTTONUP, (addon_name_lower .. "_skill_reroll_lv_up"))
        lv_btn:SetEventScript(ui.RBUTTONUP, (addon_name_lower .. "_skill_reroll_lv_down"))
        lv_btn:SetTextTooltip(jp and
                                  string.format("{ol}このレベル以上で止まります(1〜%d){nl}左クリックで 1 つ上げ、%d の次は 1 に戻ります{nl}右クリックで 1 つ下げます{nl}Lv1 はレベルを問いません",
                max_lv, max_lv) or
                                  string.format("{ol}Stops at this level or above (1-%d){nl}Left click steps up (wraps at %d){nl}Right click steps down{nl}Lv1 means any level",
                max_lv, max_lv))
        oy = oy + skill_reroll.ROW_STEP
    end
    -- **画面に出したクラス名を控え、表に残っている余りを落とす。**
    -- 件数を数えるのは表(g.skill_reroll_wanted)なのに、チェックは画面から組み立てた
    -- 別物なので、画面に出ないクラスが表に残っていると
    -- 「全解除で出る件数と、チェックが入っている数が合わない」になる。
    -- 表に残りうるのは、素の候補表が変わった後のプリセットや、旧い版で保存した設定
    -- (窓は今の候補表からしか作らないので、そこに無いクラスは二度と画面へ出ない)
    local shown = {}
    -- 画面に出したクラス名の並び。**sync_from_screen がここを回って画面を読み直す。**
    -- Lua にはコントロールを列挙する手段が無いので、名前は自分で持つしかない
    g.skill_reroll_shown = {}
    for _, skill in ipairs(skills) do
        shown[skill.class_name] = true
        table.insert(g.skill_reroll_shown, skill.class_name)
    end
    local dropped, dropped_checked = {}, 0
    for class_name, want in pairs(g.skill_reroll_wanted or {}) do
        if not shown[class_name] then
            if want.is_check == 1 then
                dropped_checked = dropped_checked + 1
            end
            table.insert(dropped, class_name)
        end
    end
    for _, class_name in ipairs(dropped) do
        g.skill_reroll_wanted[class_name] = nil
    end
    if #dropped > 0 then
        core_g.vlog("mini_addons: スキル錬成 画面に出ない希望スキル %d 件を表から落とした(うちチェック済み %d 件): %s",
            #dropped, dropped_checked, table.concat(dropped, ", "))
        if dropped_checked > 0 then
            -- 黙って消すと「チェックしたのに止まらない」になるので知らせる
            ui.SysMsg(string.format(jp and "このアイテムでは出ない希望スキル %d 件を外しました" or
                                        "Dropped %d wanted skills that cannot appear on this item",
                dropped_checked))
        end
    end
    -- 中身より枠が高いときに余白を作らないよう、実際の高さに合わせて縮める
    local option_box_height = math.min(max_box_height, oy + 5)
    option_box:Resize(415, option_box_height)
    option_box:EnableScrollBar(1)
    option_box:SetScrollPos(0)
    y = y + option_box_height + 8

    local repeat_label = gbox:CreateOrGetControl("richtext", "repeat_label", 10, y + 6, 0, 20)
    repeat_label:SetText("{ol}" .. (jp and "リピート回数" or "Repeat count"))
    local all_btn = gbox:CreateOrGetControl("button", "repeat_all", 280, y, 60, 30)
    AUTO_CAST(all_btn)
    all_btn:SetSkinName("test_pvp_btn")
    all_btn:SetText("{ol}ALL")
    all_btn:SetTextTooltip(jp and "{ol}手持ちの素材で回せる回数を入れます" or
                               "{ol}Fill in how many times your materials allow")
    all_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_skill_reroll_repeat_all")
    local repeat_count = gbox:CreateOrGetControl("edit", "repeat_count", 350, y, 60, 30)
    AUTO_CAST(repeat_count)
    repeat_count:SetFontName("white_16_ol")
    repeat_count:SetTextAlign("center", "center")
    repeat_count:SetNumberMode(1)
    repeat_count:SetMinNumber(0)
    repeat_count:SetMaxNumber(skill_reroll.REPEAT_MAX)
    repeat_count:SetMaxLen(string.len(tostring(skill_reroll.REPEAT_MAX)))
    repeat_count:SetTypingScp((addon_name_lower .. "_skill_reroll_repeat"))
    repeat_count:SetTextTooltip(jp and
                                    string.format("{ol}リピート回数を入力(0〜%d){nl}0 は 1 回だけ",
            skill_reroll.REPEAT_MAX) or
                                    string.format("{ol}Enter the repeat count (0-%d){nl}0 means once",
            skill_reroll.REPEAT_MAX))
    if prev_repeat_text ~= nil then
        -- 組み直し。停止判定が読む上限値なので、初期値へ戻さず入力済みの値を引き継ぐ
        repeat_count:SetText(prev_repeat_text)
    else
        -- **初期値に手持ちの素材の数を入れないこと。** 何気なく押しただけで全部溶ける形になる。
        -- 全部使いたいときは隣の ALL ボタンで明示的に入れる
        repeat_count:SetText("0")
    end
    y = y + 34

    local status = gbox:CreateOrGetControl("richtext", "status_text", 10, y, 400, 20)
    local can = skill_reroll.affordable(obj)
    status:SetText("{ol}" ..
                       (can == nil and "" or
                           string.format(jp and "手持ちの素材で回せる回数: %d" or "Materials allow %d attempts", can)))
    y = y + 26

    adv:Resize(430, y + 45)
    gbox:Resize(adv:GetWidth(), adv:GetHeight() - 40)
    -- 「何を元に組んだか」を最後に記録する。これが skill_reroll.refresh_if_changed の
    -- 比較対象になるので、組み直したら必ず更新すること(忘れると毎回組み直し続ける)
    adv:SetUserValue("BUILD_SIG", string.format("%s/%s", tostring(guid), tostring(TryGetProp(obj, "UseLv", 0))))
    core_g.vlog("mini_addons: スキル錬成 高度な設定を組んだ(候補 %d 件 / 希望 %d 件)", #skills,
        skill_reroll.wanted_count())
end

-- 素のスキル錬成の窓が開かれた。素のフレームへ「高度な設定」ボタンを足す。
-- タイトルの × ボタン(右余白 27 / 幅 34)の左隣に並べる。
-- CreateOrGetControl なので開くたびに呼んでも二重にはならない
function Mini_addons_COMMON_SKILL_ENCHANT_OPEN(my_frame, my_msg)
    local frame = ui.GetFrame("common_skill_enchant")
    if frame == nil then
        return
    end
    local title = GET_CHILD_RECURSIVELY(frame, "title")
    if title == nil then
        return
    end
    local adv_btn = title:CreateOrGetControl("button", "mini_addons_adv_setting", 0, 0, 110, 32)
    AUTO_CAST(adv_btn)
    adv_btn:SetGravity(ui.RIGHT, ui.TOP)
    local margin = adv_btn:GetMargin()
    adv_btn:SetMargin(margin.left, 12, 70, margin.bottom)
    adv_btn:SetSkinName("test_pvp_btn")
    adv_btn:SetText("{@st66}{s16}" .. (g.lang == "Japanese" and "高度な設定" or "Advanced"))
    adv_btn:SetTextTooltip(g.lang == "Japanese" and
                               "{ol}希望スキルを決めて、出るまで錬成を繰り返します{nl}回している間は下の「スキル錬成」が「停止」になります" or
                               "{ol}Keep re-rolling until one of your wanted skills shows up{nl}While running, the button below turns into Stop")
    adv_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_skill_reroll_adv_btn")
    -- 機能 OFF のときはボタンごと隠す(押しても何もしないボタンを見せない)
    adv_btn:ShowWindow(g.settings.skill_reroll == 1 and 1 or 0)
    -- 残り回数の 1 行。**素にはこれを出す場所が無い**ので、素の錬成ボタン
    -- (下中央 / 高さ 50 / 下余白 10)のすぐ上へ置く。回している間だけ出す
    local remain = frame:CreateOrGetControl("richtext", "mini_addons_repeat_text", 0, 0, 300, 24)
    AUTO_CAST(remain)
    remain:SetGravity(ui.CENTER_HORZ, ui.BOTTOM)
    local remain_margin = remain:GetMargin()
    remain:SetMargin(remain_margin.left, remain_margin.top, remain_margin.right, 64)
    remain:SetTextAlign("center", "center")
    remain:ShowWindow(0)
    core_g.vlog("mini_addons: スキル錬成 高度な設定ボタンを用意した(機能=%s)",
        g.settings.skill_reroll == 1 and "ON" or "OFF")
end

-- アイテムがスロットへ乗った。ここで初めて出うるスキルと素材の数が決まるので、
-- 「自動で開く」はこの時点で効かせる。既に開いていれば監視スクリプトが組み直す
function Mini_addons_COMMON_SKILL_ENCHANT_SET_TARGET_ITEM(my_frame, my_msg)
    if g.settings.skill_reroll == 0 and not skill_reroll.do_is_stop then
        return
    end
    -- 回している間は錬成ボタンを「停止」として押せる状態に保つ(素はここで
    -- 候補が出ている状態だと素材の一覧を組み直さないので、誰も戻さない)。
    -- 機能 OFF でも、書き換えた文言が残っていればここで戻す
    skill_reroll.sync_do_button()
    if g.settings.skill_reroll == 0 then
        return
    end
    if g.settings.skill_reroll_auto_open ~= 1 then
        return
    end
    if ui.GetFrame(addon_name_lower .. "skill_reroll") ~= nil then
        return
    end
    if skill_reroll.item() == nil then
        return
    end
    core_g.vlog("mini_addons: スキル錬成 自動で開く設定が ON なので高度な設定を開く")
    skill_reroll.open_advanced()
end

-- 素の窓が閉じた。自前の窓も一緒に畳む。
-- **素が閉じられなかったとき(HoldUI 中は素も return する)は畳まないこと。**
-- 相手が残っているのにこちらだけ消えると「押したら高度な設定だけ消えた」になる
function Mini_addons_COMMON_SKILL_ENCHANT_CLOSE(my_frame, my_msg)
    local frame = ui.GetFrame("common_skill_enchant")
    if frame ~= nil and frame:IsVisible() == 1 then
        return
    end
    if skill_reroll.close_advanced() then
        core_g.vlog("mini_addons: スキル錬成 素の窓が閉じたので高度な設定を畳んだ")
    end
end

-- 素が結果のたびに呼ぶ画面のリセット。**回している間は錬成ボタンを押せる状態へ戻す。**
-- 素の REFRESH_COMMON_SKILL_ENCHANT は最後に do_enchant:SetEnable(0) を掛けるので、
-- ここで戻さないと「停止」と書いてあるのに押せない時間ができる
function Mini_addons_REFRESH_COMMON_SKILL_ENCHANT(my_frame, my_msg)
    -- **機能 OFF でも、こちらが「停止」に書き換えた文言が残っていれば戻すこと。**
    -- 回している最中に素の窓を閉じ、そのあと OFF にされると、戻す経路がここしか無くなる
    if g.settings.skill_reroll == 0 and not skill_reroll.do_is_stop then
        return
    end
    skill_reroll.sync_do_button()
end
