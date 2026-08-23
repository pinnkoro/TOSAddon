-- スキル錬成(素の common_skill_enchant)を、希望スキルが出るまで回せるようにする。
--
-- 素の流れは 3 状態しかない(素の COMMON_SKILL_ENCHANT_CHECK_EQUIP_STATE):
--   0 … スキルがまだ付いていない。「スキル錬成」で 1 つ付く(候補は出ない)
--   1 … スキルが付いていて候補が無い。「スキル錬成」で素材を使い、候補が出る
--   2 … 候補が出ている。「維持」(今のまま)か「変更」(候補にする)を選ぶまで進めない
-- つまり振り直しは **「撃つ → 候補を見る → 要らなければ維持で捨てる → また撃つ」**
-- の繰り返しで、1 周につきサーバとのやり取りが 2 回ある。
--
-- **素の関数をそのまま呼ぶこと。** 撃つのは素の COMMON_SKILL_ENCHANT_DO、候補を捨てるのは
-- 素の COMMON_SKILL_ENCHANT_SELECT_BTN_LEFT。ReqExecuteTx_Item を自分で組み立てると、
-- 引数(現状 "1 1" / "1 2")が素で変わったときに黙って古いままになる
-- (CLAUDE.md「素の関数を書き写さない」)。
--
-- 判定に使う値の出どころ:
--   候補         … obj["CommonSkillStr"]("スキル名/Lv/枠")を
--                   shared_common_skill_enchant.get_canidate_skill が割る
--   今のスキル   … obj["EnchantSkillName_1"] / obj["EnchantSkillLevel_1"]
--   候補の顔ぶれ … shared_common_skill_enchant.get_skill_list(アイテムの UseLv)

-- **この機能の内部関数と定数は、この 1 つのテーブルにまとめている。**
-- Lua(LuaJIT)の 1 つの関数で持てるローカル変数は 200 個までで、bundle 全体が
-- 1 つのチャンクとして読まれるためここは既にその上限際にある。機能ごとに
-- local を並べると、**関係の無い所で「main function has more than 200 local
-- variables」で丸ごと読み込めなくなる**(実際にこの機能を足したときに踏んだ)。
-- テーブルの中身は実行時に引くので、前方宣言も要らない。
-- **グローバルにはしないこと**(本家や他アドオンと名前で衝突しうる)
local skill_reroll = {}

-- 結果が返ったかを見にいく間隔。**「撃つ間隔」ではない**(次を撃つのは結果が返ってから)
skill_reroll.TICK = 0.1
-- リピート回数の上限。ヘアエンチャント側(素の入力欄に合わせた 9999)と揃えてある
skill_reroll.REPEAT_MAX = 9999
-- 結果が返らないまま何秒たったら諦めて止めるか。**撃ち直しはしない**
-- (遅れているだけのときに重ねて撃つと、当たった候補を次の結果で潰すため)。
-- 1 周につき「撃つ」と「維持」の 2 往復あるぶん、ヘアエンチャント(10 秒)より長めに取る
skill_reroll.WATCHDOG = 15
-- 希望スキルの一覧の行の送り。**チェックボックスの高さ(22)より広く取ること。**
-- 押した行とは別の行のコントロールがイベントを受け取る事象があり、当たり判定が縦に
-- 重なっているのが疑わしい。実寸はスキン任せで測れないので、指定できる分だけ離してある
-- (画面から読み直す skill_reroll.sync_from_screen は残す。こちらは起きにくくするだけ)
skill_reroll.ROW_STEP = 32

-- 希望スキルの一覧より下に置くもの(リピート回数の行 + 実行状況の行 + 窓の下余白)の高さ。
-- 一覧の高さを画面から逆算するのに使うので、下の行を増減したらここも合わせること
skill_reroll.BOTTOM_HEIGHT = 96

skill_reroll.jp = function()
    return g.lang == "Japanese"
end

skill_reroll.frame = function()
    return ui.GetFrame(addon_name_lower .. "skill_reroll")
end

-- 素の窓のスロットに乗っているアイテム。guid と IES を返す(乗っていなければ nil)
skill_reroll.item = function()
    local frame = ui.GetFrame("common_skill_enchant")
    if frame == nil then
        return nil
    end
    local slot = GET_CHILD_RECURSIVELY(frame, "slot")
    if slot == nil then
        return nil
    end
    local guid = slot:GetUserValue("SET_ID")
    if guid == nil or guid == "None" then
        return nil
    end
    local inv_item = session.GetInvItemByGuid(guid)
    if inv_item == nil then
        return nil
    end
    local obj = GetIES(inv_item:GetObject())
    if obj == nil then
        return nil
    end
    return guid, obj
end

-- 素の状態判定(0/1/2)。**素の関数を呼ぶこと**(条件は素で変わりうる)。
-- 走っているクライアントに無ければ nil を返し、呼び出し側は回すのをやめる。
-- 報告は 1 回だけ(毎 tick 通る経路なのでログが流れる。CLAUDE.md「出しすぎない」)
skill_reroll.state_warned = false

skill_reroll.state = function(obj)
    if type(_G["COMMON_SKILL_ENCHANT_CHECK_EQUIP_STATE"]) ~= "function" then
        if not skill_reroll.state_warned then
            skill_reroll.state_warned = true
            core_g.vlog("{#FF6347}mini_addons: スキル錬成 素の COMMON_SKILL_ENCHANT_CHECK_EQUIP_STATE が無い{/}")
        end
        return nil
    end
    local ok, state = pcall(_G["COMMON_SKILL_ENCHANT_CHECK_EQUIP_STATE"], obj)
    if not ok or type(state) ~= "number" then
        if not skill_reroll.state_warned then
            skill_reroll.state_warned = true
            core_g.vlog("{#FF6347}mini_addons: スキル錬成 状態判定に失敗した(%s){/}", tostring(state))
        end
        return nil
    end
    return state
end

-- 今出ている候補。無ければ nil
skill_reroll.candidate = function(obj)
    if shared_common_skill_enchant == nil or shared_common_skill_enchant.get_canidate_skill == nil then
        return nil
    end
    local name, lv = shared_common_skill_enchant.get_canidate_skill(obj)
    if name == nil or name == "None" then
        return nil
    end
    return name, tonumber(lv) or 0
end

-- 今アイテムに付いているスキル。無ければ nil
skill_reroll.enchanted = function(obj)
    if shared_common_skill_enchant == nil or shared_common_skill_enchant.get_enchanted_skill == nil then
        return nil
    end
    local name, lv = shared_common_skill_enchant.get_enchanted_skill(obj, 1)
    if name == nil or name == "None" then
        return nil
    end
    return name, tonumber(lv) or 0
end

-- アイテムの今の中身の指紋。撃つ / 捨てるのたびに必ず変わる
-- (候補が出る → 候補が消える、の繰り返しなので、同じ候補を続けて引いても直前とは違う)。
-- 「結果の合図は来たが、アイテムの更新がまだ」を見分けるために使う
skill_reroll.fingerprint = function(obj)
    local name, lv = skill_reroll.enchanted(obj)
    return string.format("%s/%s/%s", tostring(TryGetProp(obj, "CommonSkillStr", "None")), tostring(name),
        tostring(lv))
end

-- スキルの表示名。引けなければクラス名をそのまま出す(名前が空の行を作らないため)
skill_reroll.skill_name = function(class_name)
    local cls = GetClass("Skill", class_name)
    local name = cls ~= nil and TryGetProp(cls, "Name", "None") or "None"
    if name == nil or name == "None" then
        return class_name
    end
    return name
end

-- このアイテムで出うるスキルの一覧。{class_name, name, max_lv} を表示名順で返す。
-- 素の表(shared_common_skill_enchant.get_skill_list)を引く。引けないときだけ
-- enchant_skill_list から直に組む(素の表はアイテムの UseLv を鍵にしているので、
-- 想定外の装備レベルだと nil が返る)
skill_reroll.skill_list = function(obj)
    local list = {}
    local use_lv = TryGetProp(obj, "UseLv", 480)
    local by_class = nil
    if shared_common_skill_enchant ~= nil and shared_common_skill_enchant.get_skill_list ~= nil then
        by_class = shared_common_skill_enchant.get_skill_list(use_lv)
    end
    if type(by_class) == "table" then
        for class_name, range in pairs(by_class) do
            table.insert(list, {
                class_name = class_name,
                name = skill_reroll.skill_name(class_name),
                max_lv = (type(range) == "table" and tonumber(range[2])) or 0
            })
        end
    else
        core_g.vlog("mini_addons: スキル錬成 素の候補表を引けない(UseLv=%s)ので enchant_skill_list から組む",
            tostring(use_lv))
        local cls_list, cnt = GetClassList("enchant_skill_list")
        for i = 0, cnt - 1 do
            local cls = GetClassByIndexFromList(cls_list, i)
            if cls == nil then
                break
            end
            local max_lv = TryGetProp(cls, "MaxLevel", 0)
            if TryGetProp(cls, "Tier", 0) > 0 and max_lv > 0 then
                table.insert(list, {
                    class_name = cls.ClassName,
                    name = skill_reroll.skill_name(cls.ClassName),
                    max_lv = max_lv
                })
            end
        end
    end
    -- **並びを pairs 任せにしないこと。** 起動ごとに順番が変わると、目で探せないうえ
    -- スクロール位置も毎回変わる(CLAUDE.md「pairs の順で並べない」と同じ理由)
    table.sort(list, function(a, b)
        if a.name == b.name then
            return a.class_name < b.class_name
        end
        return a.name < b.name
    end)
    return list
end

-- 希望スキルの表。鍵はスキルの**クラス名**で、値は {is_check = 0/1, min_lv = 数}。
-- **チェックを外しても行は消さない。** 最低レベルの入力値を覚えておくためで、
-- 「希望しているか」は is_check だけで決める。
-- **表示名や番号で持たないこと。** 画面の並びは表示名順なので、番号だと
-- 辞書や言語が変わっただけで別のスキルを指しかねない(プリセットの保存先も同じ理由)
g.skill_reroll_wanted = g.skill_reroll_wanted or {}

-- 出たスキルが希望に当たるか。min_lv は「そのレベル以上なら当たり」(0 = レベル不問)。
-- **is_check を必ず見ること。** チェックを外しても最低レベルの入力値は覚えておく作り
-- (先にレベルを打ってからチェックを入れる順があるため)なので、表に居ること自体は
-- 「希望している」を意味しない
skill_reroll.is_wanted = function(class_name, lv)
    local want = g.skill_reroll_wanted[class_name]
    if want == nil or want.is_check ~= 1 then
        return false
    end
    local min_lv = tonumber(want.min_lv) or 0
    if min_lv > 0 and (tonumber(lv) or 0) < min_lv then
        return false
    end
    return true
end

-- あと何回撃てるか(素材の少ない方に合わせる)。素の必要量表から数えるので、
-- 素材の種類や量が素で変わっても付いていける。引けなければ nil
skill_reroll.affordable = function(obj)
    if shared_common_skill_enchant == nil or shared_common_skill_enchant.get_cost == nil then
        return nil
    end
    local cost = shared_common_skill_enchant.get_cost(obj)
    if type(cost) ~= "table" then
        return nil
    end
    local account = GetMyAccountObj()
    local least = nil
    for class_name, need_count in pairs(cost) do
        local need = tonumber(need_count) or 0
        if need > 0 then
            local have = 0
            if IS_STRING_COIN(class_name) == true then
                have = TryGetProp(account, class_name, 0)
            else
                have = GET_INV_ITEM_COUNT_BY_PROPERTY({{
                    Name = "ClassName",
                    Value = class_name
                }}, false)
            end
            local can = math.floor((tonumber(have) or 0) / need)
            if least == nil or can < least then
                least = can
            end
        end
    end
    return least
end

-- 連続実行を回している最中か。更新スクリプトが載っているかで見る。
-- 「続けますか？」の返事待ちも回している扱いにする。ここで素のボタンを「スキル錬成」へ
-- 戻すと、返事を待っているだけなのに終わったように見えるうえ、そのボタンを押せると
-- 連続実行が二重に走り出す
skill_reroll.is_running = function()
    local frame = ui.GetFrame("common_skill_enchant")
    if frame == nil then
        return false
    end
    if frame:HaveUpdateScript("Mini_addons_skill_reroll_tick") == true then
        return true
    end
    local adv = skill_reroll.frame()
    return adv ~= nil and adv:GetUserValue("ASKING") == "yes"
end

-- 素の「スキル錬成」ボタンを、回している間だけ「停止」にする。
--
-- **SetColorTone は使わないこと**(キャプションを持つコントロールでは元の見た目へ戻せない。
-- 実機で確かめた顛末はヘアエンチャント側の core.lua にある)。文言を控えて入れ替える。
-- 素は結果のたびに REFRESH_COMMON_SKILL_ENCHANT で do_enchant を無効化するので、
-- 回している間は毎回 SetEnable(1) で押せる状態へ戻す(押せないと止められない)
skill_reroll.do_caption = nil
skill_reroll.do_is_stop = false

skill_reroll.sync_do_button = function()
    local frame = ui.GetFrame("common_skill_enchant")
    if frame == nil or frame:IsVisible() == 0 then
        return
    end
    local do_enchant = GET_CHILD_RECURSIVELY(frame, "do_enchant")
    if do_enchant == nil then
        return
    end
    AUTO_CAST(do_enchant)
    local running = skill_reroll.is_running()
    if running then
        -- **回している間は必ず押せる状態へ戻すこと。** 素は結果のたびに
        -- REFRESH_COMMON_SKILL_ENCHANT で do_enchant:SetEnable(0) を掛け、そのあと
        -- 候補が出た状態(state 2)では素材の一覧を組み直さない = 誰も 1 へ戻さない。
        -- 見張り(0.3 秒)任せにしていたため、1 周ごとに「押せない時間」ができていた
        -- (利用者から「押せたり押せなくなったりする」と報告された)。
        -- 今は tick(0.1 秒)と素の REFRESH のフックからも通している
        do_enchant:SetEnable(1)
        do_enchant:EnableHitTest(1)
    end
    if running == skill_reroll.do_is_stop then
        return
    end
    if skill_reroll.do_caption == nil then
        -- 初回だけ素の文言を控える。読めない土台なら空文字にして、以降は文字を触らず
        -- 済ませる(見た目は変わらないが壊さない)
        local ok, caption = pcall(function()
            return do_enchant:GetText()
        end)
        skill_reroll.do_caption = (ok and type(caption) == "string") and caption or ""
        core_g.vlog("mini_addons: スキル錬成 素の錬成ボタンの文言を控えた(%s)",
            skill_reroll.do_caption == "" and "読めなかったので文字は触らない" or skill_reroll.do_caption)
    end
    if skill_reroll.do_caption ~= "" then
        do_enchant:SetText(running and ("{@st66d}{s20}" .. (skill_reroll.jp() and "停止" or "Stop")) or
                               skill_reroll.do_caption)
    end
    skill_reroll.do_is_stop = running
    core_g.vlog("mini_addons: スキル錬成 錬成ボタンを「%s」にした", running and "停止" or "錬成")
end

-- 素の窓へ出す「残り n 回」。ヘアエンチャントは素が repeatCount を持っていてそこへ書けたが、
-- スキル錬成の窓には**残り回数を出す場所が素に無い**ので、こちらで 1 行足す
-- (作るのは Mini_addons_COMMON_SKILL_ENCHANT_OPEN。錬成ボタンのすぐ上)。
-- text が nil なら畳む。回していないときに古い数字が残らないよう、停止時に必ず nil で呼ぶこと
skill_reroll.set_remain = function(text)
    local frame = ui.GetFrame("common_skill_enchant")
    if frame == nil then
        return
    end
    local remain = GET_CHILD_RECURSIVELY(frame, "mini_addons_repeat_text")
    if remain == nil then
        return
    end
    if text == nil then
        remain:ShowWindow(0)
        return
    end
    remain:SetText("{@st41b}{s18}{ol}" .. tostring(text))
    remain:ShowWindow(1)
end

-- 回すのをやめる。**素のボタンの文言を必ず戻すこと**(戻し忘れると「停止」表示のまま
-- 取り残される)。順番も大事で、更新スクリプトを止めてから見た目を合わせ直す
skill_reroll.stop = function(reason)
    local frame = ui.GetFrame("common_skill_enchant")
    -- **止める前に「回していたか」を控えること。** 下の HoldUI の後始末は、
    -- 自分が撃った結果を待っている最中だけに絞るための条件に使う
    local was_running = frame ~= nil and frame:HaveUpdateScript("Mini_addons_skill_reroll_tick") == true
    if frame ~= nil then
        frame:StopUpdateScript("Mini_addons_skill_reroll_tick")
    end
    local adv = skill_reroll.frame()
    if adv ~= nil then
        -- **撃った結果を待っている途中で止めるときは HoldUI を解くこと。**
        -- HoldUI を掛けるのは素(COMMON_SKILL_ENCHANT_DO / SELECT_BTN_LEFT)で、解くのは
        -- 素の SUCCESS / FAILED だけ。結果が返らないまま止めるとどちらも走らないので、
        -- 掛かりっぱなしになる。そうなると素の CLOSE / REFRESH / SET_TARGET_ITEM が
        -- 揃って ui.CheckHoldedUI() で即 return するため、**やり直すことも窓を閉じることも
        -- できなくなる**(「もう一度お試しください」と出しておきながら何もできない)。
        -- 条件を「結果待ちだったとき」に絞るのは、他の窓が掛けた HoldUI を横から
        -- 解かないため
        if was_running and adv:GetUserValue("READY") ~= "yes" and ui.CheckHoldedUI() == true then
            ui.SetHoldUI(false)
            core_g.vlog("mini_addons: スキル錬成 結果待ちのまま止めたので HoldUI を解いた")
        end
        adv:SetUserValue("ASKING", "None")
        adv:SetUserValue("READY", "no")
    end
    -- 残り回数は畳む(回していないのに数字が残ると、まだ動いているように見える)
    skill_reroll.set_remain(nil)
    skill_reroll.sync_do_button()
    core_g.vlog("mini_addons: スキル錬成 停止(%s)", tostring(reason))
end

-- 自前の窓を畳む(素の窓や素の設定には触らない)
skill_reroll.close_advanced = function()
    local adv = skill_reroll.frame()
    if adv == nil then
        return false
    end
    -- **先に止めること。** 回している途中で畳まれることがあり(× / 素の窓を閉じた /
    -- 機能 OFF)、更新スクリプトの停止と HoldUI の後始末はどちらも skill_reroll.stop が持つ
    skill_reroll.stop("高度な設定を畳んだ")
    ui.DestroyFrame(adv:GetName())
    -- **必ず DestroyFrame の後に呼ぶこと。** 先に呼ぶと、返事待ち(ASKING == "yes")の
    -- 最中に閉じたときに「まだ回している」と判定され、「停止」表示のまま誰も戻せなくなる
    skill_reroll.sync_do_button()
    return true
end

-- × ボタン
function Mini_addons_skill_reroll_adv_close(parent, ctrl)
    skill_reroll.close_advanced()
end

-- 「高度な設定」ボタン。押すたびに自前の窓を開く / 畳むのトグル
function Mini_addons_skill_reroll_adv_btn(parent, ctrl)
    if g.settings.skill_reroll == 0 then
        core_g.vlog("mini_addons: スキル錬成 機能 OFF なので高度な設定は開かない(自前の窓=%s)",
            skill_reroll.close_advanced() and "残っていたので畳んだ" or "無し")
        return
    end
    if skill_reroll.close_advanced() then
        core_g.vlog("mini_addons: スキル錬成 高度な設定を畳んだ(もう一度押された)")
        return
    end
    skill_reroll.open_advanced()
end

-- 「今の中身は何を元に組んだか」の印。装備を差し替えると出うるスキルの顔ぶれが
-- 変わりうるので、これが変わったら組み直す。**候補やスキルの変化では組み直さないこと**
-- (回している最中は毎周変わるので、組み直し続けて入力中のリピート回数まで作り直してしまう)
skill_reroll.build_signature = function(guid, obj)
    return string.format("%s/%s", tostring(guid), tostring(TryGetProp(obj, "UseLv", 0)))
end

skill_reroll.refresh_if_changed = function(adv)
    if adv == nil then
        return false
    end
    local guid, obj = skill_reroll.item()
    if guid == nil then
        -- スロットが空(差し替えの途中など)。この状態では組みようがないので触らない。
        -- 次の品が乗れば印が変わるので、そこで組み直される
        return false
    end
    local sig = skill_reroll.build_signature(guid, obj)
    if sig == adv:GetUserValue("BUILD_SIG") then
        return false
    end
    core_g.vlog("mini_addons: スキル錬成 対象が変わったので組み直す(%s → %s)",
        tostring(adv:GetUserValue("BUILD_SIG")), tostring(sig))
    skill_reroll.build_body(adv, guid, obj)
    return true
end

-- 自前の窓が開いている間だけ回す。素の窓は動かせる(moveable="true")ので位置に追随し、
-- 素の窓が閉じたら一緒に畳む。
--
-- **この窓は g.esc_register で積まないこと。** CLAUDE.md の「ゲーム側のウィンドウに
-- 貼り付いている付属パネルは積んではいけない」に当たる。素の COMMON_SKILL_ENCHANT_CLOSE は
-- HoldUI 中は閉じない・インベントリの右クリック割り当て(INVENTORY_SET_CUSTOM_RBTNDOWN)を
-- 戻す、といった後始末を持っているので、ESC をこちらが横取りすると素の窓が開いたまま
-- 取り残される。畳む手段は × と「高度な設定」ボタン、素の窓を閉じる操作で足りる。
--
-- 比較だけなので、変化が無いときは何も出さない(ログを流さないこと)
function Mini_addons_skill_reroll_watch(frame)
    local adv = frame
    if adv == nil then
        adv = skill_reroll.frame()
    end
    if adv == nil then
        return 0
    end
    if g.settings.skill_reroll == 0 then
        -- 開いたまま設定画面で OFF にされた。押しても何もしない窓を残さない
        core_g.vlog("mini_addons: スキル錬成 機能が OFF にされたので高度な設定を畳んだ")
        skill_reroll.close_advanced()
        return 0
    end
    local vanilla = ui.GetFrame("common_skill_enchant")
    if vanilla == nil or vanilla:IsVisible() == 0 then
        core_g.vlog("mini_addons: スキル錬成 素の窓が閉じたので高度な設定を畳んだ")
        skill_reroll.close_advanced()
        return 0
    end
    -- 素の窓の**左隣**。右は素がインベントリを開く側(素の COMMON_SKILL_ENCHANT_OPEN が
    -- ui.OpenFrame('inventory') を呼ぶ)なので、既定では重ならない左へ置く。
    -- 左に入らないときだけ右隣へ回し、それも入らなければ画面内へ丸める
    local x = vanilla:GetX() - adv:GetWidth() - 5
    if x < 0 then
        x = vanilla:GetX() + vanilla:GetWidth() + 5
        local max_x = ui.GetClientInitialWidth() - adv:GetWidth()
        if x > max_x then
            x = max_x
        end
        if x < 0 then
            x = 0
        end
    end
    local y = vanilla:GetY()
    local max_y = ui.GetClientInitialHeight() - adv:GetHeight()
    if max_y < 0 then
        max_y = 0
    end
    if y > max_y then
        y = max_y
    end
    if adv:GetX() ~= x or adv:GetY() ~= y then
        adv:SetPos(x, y)
    end
    skill_reroll.refresh_if_changed(adv)
    -- 上限に達して止まったときなど、窓を開いたまま終わる経路もあるので毎回見る
    skill_reroll.sync_do_button()
    return 1
end
