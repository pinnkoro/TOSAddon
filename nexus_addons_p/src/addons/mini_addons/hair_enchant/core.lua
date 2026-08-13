-- ヘアエンチャント
-- 素の「ランクアップ時に停止」チェックの有効 / 無効を切り替える。目標ランクを
-- 指定している間はこちらの判定を見に行かない(そちらが優先)ので、押せるまま残すと
-- 「チェックしたのに止まらない」不具合に見える。
--
-- **これは素のフレームの持ち物なので、必ず元へ戻すこと。** 戻し忘れると、この機能を
-- OFF にしても素の窓のチェックが押せないまま残る。戻す経路は
--   * 目標ランクを「指定なし」へ戻したとき(mini_addons_p_hair_enchant_rank_until)
--   * 自前の窓を畳むとき(この下の CLOSE_BTN と、機能 OFF で畳む経路)
--
-- **灰色にしていないときは一切触らないこと。** 戻す側も呼び出し口が多く
-- (窓を組むたびに「指定なし」として通る)、素通りのつもりで毎回掛けていた。
--
-- **SetColorTone は使わないこと。** 一度設定するとそのコントロールは以降 ColorTone
-- 経由で描かれ、色として中立の "FFFFFFFF" を入れ直しても**文字の影が戻らない**
-- (実機で確認済み。picture では FFFFFFFF がリセットとして使えるが、キャプションを
-- 持つコントロールでは戻らない)。素の定義は fontname="black_16_b" で ColorTone を
-- 持たないので、こちらが一度でも掛けると元の見た目に戻せなくなる。
-- 代わりに素のキャプションを控えて、色タグ付きの文字列と入れ替える。戻すのは
-- 控えた文字列を書き戻すだけなので、確実に元へ戻る
local hair_enchant_rank_up_disabled = false
local hair_enchant_rank_up_caption = nil

local function hair_enchant_set_rank_up_enabled(enabled)
    if enabled == not hair_enchant_rank_up_disabled then
        -- 既にその状態。素のコントロールには触らない
        return
    end
    local high_hairenchant = ui.GetFrame("high_hairenchant")
    local rank_up = high_hairenchant and GET_CHILD_RECURSIVELY(high_hairenchant, "rank_up")
    if rank_up == nil then
        -- 素の窓ごと消えている。次に灰色にするときの起点が狂わないよう印だけ戻す
        hair_enchant_rank_up_disabled = false
        return
    end
    AUTO_CAST(rank_up)
    if hair_enchant_rank_up_caption == nil then
        -- 初回だけ素のキャプションを控える。読めない土台なら空文字にして、
        -- 以降は文字を触らず SetEnable だけで済ませる(見た目は変わらないが壊さない)
        local ok, caption = pcall(function()
            return rank_up:GetText()
        end)
        hair_enchant_rank_up_caption = (ok and type(caption) == "string") and caption or ""
        core_g.vlog("mini_addons: ヘアエンチャント 素のランクアップ停止チェックの文言を控えた(%s)",
            hair_enchant_rank_up_caption == "" and "読めなかったので文字は触らない" or
                hair_enchant_rank_up_caption)
    end
    rank_up:SetEnable(enabled and 1 or 0)
    rank_up:EnableHitTest(enabled and 1 or 0)
    if hair_enchant_rank_up_caption ~= "" then
        rank_up:SetText(enabled and hair_enchant_rank_up_caption or
                            ("{#888888}" .. hair_enchant_rank_up_caption))
    end
    hair_enchant_rank_up_disabled = not enabled
    core_g.vlog("mini_addons: ヘアエンチャント 素のランクアップ停止チェックを%s",
        enabled and "元に戻した" or "灰色にした")
end

function Mini_addons_HIGH_HAIRENCHANT_CLOSE_BTN(my_frame, my_msg)
    local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
    if reroll_option then
        local high_hairenchant = ui.GetFrame("high_hairenchant")
        local bodyGbox1_1 = GET_CHILD_RECURSIVELY(high_hairenchant, "bodyGbox1_1")
        AUTO_CAST(bodyGbox1_1)
        bodyGbox1_1:RemoveAllChild()
        SET_REPEAT_COUNT_TEXT(0)
        RESET_HIGH_ENCHANT()
        high_hairenchant:StopUpdateScript("Mini_addons_HIGH_HAIRENCHANT_OK_BTN_")
        hair_enchant_set_rank_up_enabled(true)
        ui.DestroyFrame(reroll_option:GetName())
    end
end

-- 連続付与の刻み。**これは「撃つ間隔」ではなく「結果が返ったかを見にいく間隔」**。
-- 実際に次を撃つのは素の結果が返ってからなので、ここを小さくしても撃つ速さは
-- サーバの応答より速くならない(＝空撃ちしない)。上限の待ち時間だけが縮む
local HAIR_ENCHANT_TICK = 0.1
-- リピート回数の上限。**素の入力欄と同じ値に揃えてある**
-- (hairenchant_option の INI_REPEAT_COUNT が SetMaxNumber(9999) / SetMinNumber(0))。
-- 桁数を制限しないと、極端な値を入れたときに停止判定の表示
-- (string.format("%d", set_repeat_num - count))が扱えない大きさになって止まる
local HAIR_ENCHANT_REPEAT_MAX = 9999

-- 希望オプションのスクロール枠より下に置くもの(「演出を待たずに実行」の行 +
-- 目標ランク / Cancel / リピート回数の行 + 窓の下余白)の高さ。
-- 枠の高さを画面から逆算するのに使うので、下の行を増減したらここも合わせること
local HAIR_ENCHANT_BOTTOM_HEIGHT = 110
-- 結果が返らないまま何秒たったら諦めて止めるか。要求が落ちた / サーバに弾かれたときに
-- 黙って止まったように見えるのを避けるための保険で、**撃ち直しはしない**
-- (理由は使う側のコメント)。撃たずに止めるだけなので、応答が遅い環境で
-- 早々に打ち切らないよう長めに取る。os.time() は秒単位なので、実際の発動は
-- ここから最大 1 秒早まりうる
local HAIR_ENCHANT_WATCHDOG = 10

-- ランクの並び。素の shared_enchant_special_option.get_item_rank が返すのは
-- EnchantItemRank(0~3) を写した文字列 "D"/"C"/"B"/"A" なので、そのまま比較しても
-- 上下は分からない。「指定したランクへ届いたか」を見るために順序を持つ
local hair_enchant_rank_order = {"D", "C", "B", "A"}

local function hair_enchant_rank_index(rank)
    for i, name in ipairs(hair_enchant_rank_order) do
        if name == rank then
            return i
        end
    end
    return nil
end

-- アイテムに今付いているオプションの指紋。付与するたびに必ず振り直されるので、
-- これが変わっていなければ「まだ前の結果のまま」と判断できる。
-- 合図(READY)がアイテムの更新より先に来る可能性への歯止めに使う
local function hair_enchant_option_fingerprint(itemIES)
    local invItem = session.GetInvItemByGuid(itemIES)
    if invItem == nil then
        return "none"
    end
    local obj = GetIES(invItem:GetObject())
    if obj == nil then
        return "none"
    end
    local parts = {}
    for i = 1, 3 do
        table.insert(parts, tostring(obj["HatPropName_" .. i]) .. "=" .. tostring(obj["HatPropValue_" .. i]))
    end
    return table.concat(parts, ";")
end

local function get_current_enchant_item_grade_and_rank()
    local hairenchant = ui.GetFrame("high_hairenchant")
    if hairenchant == nil then
        return
    end
    local enchantGuid = hairenchant:GetUserValue("Enchant")
    local itemIES = hairenchant:GetUserValue("itemIES")
    if enchantGuid == "None" or itemIES == "None" then
        return
    end
    local item = session.GetInvItemByGuid(itemIES)
    local enchant_item = session.GetInvItemByGuid(enchantGuid)
    if enchant_item == nil or item == nil then
        return
    end
    enchant_item = GetIES(enchant_item:GetObject())
    item = GetIES(item:GetObject())
    local item_grade = shared_enchant_special_option.get_enchant_item_grade(enchant_item)
    local item_rank = shared_enchant_special_option.get_item_rank(item)
    return item_grade, item_rank
end

-- 実体は下。ローカルのまま前方宣言しておく。グローバルにすると本家や他アドオンと
-- 名前で衝突しうる
local hair_enchant_build_reroll_body
local hair_enchant_open_advanced
local hair_enchant_presets
-- 実体は hair_enchant_build_reroll_body の中(ドロップリストの項目から呼ぶ版と
-- 組み立てから呼ぶ版を分けるため)
local hair_enchant_apply_rank_until

-- プリセットを読み込んだ後、手で設定を変えたか。**変えていればプリセットの
-- 入れ直しをしない。** 入れ直しは「低いランクで落ちたチェックを、上のランクへ
-- 替えたときに戻す」ためのものなので、手で変えた内容まで保存値へ巻き戻すのは行き過ぎ
-- (ランクアップやスクロールのスタック切り替えでも入れ直しは走る)
local hair_enchant_preset_dirty = false

-- 組み立て中の SelectItem など、利用者の操作でない経路から印が立つのを抑えるための札
local hair_enchant_suppress_dirty = false

local function hair_enchant_mark_dirty()
    if hair_enchant_suppress_dirty then
        return
    end
    hair_enchant_preset_dirty = true
end

-- 監視スクリプト(Mini_addons_hair_enchant_watch)から呼ぶが、実体はその下にある。
-- **前方宣言を忘れるとグローバル参照になって nil。** 0.3 秒ごとに
-- attempt to call a nil value になり、監視そのものが死ぬ
local hair_enchant_sync_send_button

-- 「今の中身は何を元に組んだか」の印。ヘアアクセや魔法付与スクロールを差し替えると
-- 選べるオプションもランクも変わるので、これが変わったら組み直す
local function hair_enchant_build_signature(item_grade, item_rank)
    local high_hairenchant = ui.GetFrame("high_hairenchant")
    if high_hairenchant == nil then
        return nil
    end
    return string.format("%s/%s/%s/%s", high_hairenchant:GetUserValue("itemIES"),
        high_hairenchant:GetUserValue("Enchant"), tostring(item_grade), tostring(item_rank))
end

-- 組んだときと今とで対象が変わっていたら組み直す。変わっていなければ何もしない。
-- ランクアップで続行するときと、窓を開いたまま装備を入れ替えたときの両方から通る
local function hair_enchant_refresh_if_changed(reroll_option)
    if reroll_option == nil then
        return false
    end
    local item_grade, item_rank = get_current_enchant_item_grade_and_rank()
    if item_grade == nil or item_rank == nil then
        -- スロットが空(入れ替えの途中など)。この状態では組みようがないので触らない。
        -- 次の品が入れば印が変わるので、そこで組み直される
        return false
    end
    local sig = hair_enchant_build_signature(item_grade, item_rank)
    if sig == nil or sig == reroll_option:GetUserValue("BUILD_SIG") then
        return false
    end
    core_g.vlog("mini_addons: ヘアエンチャント 対象が変わったので組み直す(%s → %s)",
        tostring(reroll_option:GetUserValue("BUILD_SIG")), tostring(sig))
    -- **プリセットを選んでいるなら、保存内容から入れ直す。**
    -- 低いランクのアクセで読み込むと、そのランクで出ないオプションは g.need_options から
    -- 落ちる。そのまま組み直すと「落ちた後の状態」が元になるので、ランクの高いアクセに
    -- 替えても抜けたチェックが戻らない(実際にそうなった)。保存内容が真なので、
    -- 対象が変わるたびにそこから入れ直す
    local presets = hair_enchant_presets()
    local preset = presets[tonumber(reroll_option:GetUserValue("PRESET_SEL")) or 0]
    if preset ~= nil and not hair_enchant_preset_dirty then
        core_g.vlog("mini_addons: ヘアエンチャント プリセット「%s」を新しい対象に合わせて入れ直す",
            tostring(preset.name))
        -- 自動の入れ直しなのでリピート回数は今の値のまま(false)
        Mini_addons_hair_enchant_preset_load(false)
        return true
    end
    if preset ~= nil then
        -- 読み込んだ後に手で変えている。保存値へ巻き戻さず、今の内容のまま組み直す
        core_g.vlog("mini_addons: ヘアエンチャント プリセット「%s」は読込後に手で変えられているので入れ直さない",
            tostring(preset.name))
    end
    hair_enchant_build_reroll_body(reroll_option, item_grade, item_rank)
    return true
end

-- 「アイテムを乗せてください」まわりの表示を、スロットの実際の状態に合わせ直す。
--
-- 素は HIGH_HAIRENCHANT_DRAW_HIRE_ITEM で隠し、CLEAR_ENCHANT_OPTION_ITEM_DATA_UI で
-- 出す作りだが、アイテムを乗せた後も出たままになることがある(何が出し直しているのか
-- 素のコードからは特定できなかった)。**押しても直せない案内文が残るのは分かりにくい**ので、
-- itemIES が入っているかどうかから毎回決め直す。素と同じ判断なので取り合いにはならない。
-- 変わったときだけ触る(毎フレーム ShowWindow を叩かない / ログも流さない)
local function hair_enchant_sync_slot_guide()
    local frame = ui.GetFrame("high_hairenchant")
    if frame == nil or frame:IsVisible() == 0 then
        return
    end
    local has_item = frame:GetUserValue("itemIES") ~= "None"
    local changed = nil
    -- 素の DRAW / CLEAR が触る 4 つを、そのまま同じ向きに揃える
    for _, name in ipairs({"groupbox_1", "groupbox_2", "slot_bg_image"}) do
        local ctrl = GET_CHILD_RECURSIVELY(frame, name)
        if ctrl ~= nil then
            local want = has_item and 0 or 1
            if ctrl:IsVisible() ~= want then
                ctrl:ShowWindow(want)
                changed = (changed and (changed .. ",") or "") .. name
            end
        end
    end
    local rank_up = GET_CHILD_RECURSIVELY(frame, "rank_up")
    if rank_up ~= nil then
        local want = has_item and 1 or 0
        if rank_up:IsVisible() ~= want then
            rank_up:ShowWindow(want)
            changed = (changed and (changed .. ",") or "") .. "rank_up"
        end
    end
    if changed ~= nil then
        core_g.vlog("mini_addons: ヘアエンチャント 案内表示を実態に合わせ直した(アイテム=%s / %s)",
            has_item and "あり" or "無し", changed)
    end
end

-- 自前の窓が開いている間だけ回して、対象の入れ替えに追随する。素の側には
-- 「差し替わった」を知らせてくれる仕組みが無く、差し替えの経路も複数
-- (ドロップ / 右クリックで外す / RESET_HIGH_ENCHANT)あるため、
-- それぞれにフックを掛けるより印を見て比べる方が漏れがない。
-- 比較だけなので、変化が無いときは何も出さない(ログを流さないこと)
function Mini_addons_hair_enchant_watch(frame)
    if frame == nil then
        frame = ui.GetFrame(addon_name_lower .. "reroll_option")
    end
    if frame == nil then
        return 0
    end
    hair_enchant_refresh_if_changed(frame)
    hair_enchant_sync_slot_guide()
    -- 上限に達して止まったときなど、窓を開いたまま終わる経路もあるので毎回見る
    hair_enchant_sync_send_button()
    return 1
end

-- 連続付与を回している最中か。更新スクリプトが載っているかで見る
-- (STATUS は 1 回目が成功してから立つので、押した直後の判定には使えない)
local function hair_enchant_is_running()
    local frame = ui.GetFrame("high_hairenchant")
    if frame == nil then
        return false
    end
    if frame:HaveUpdateScript("Mini_addons_HIGH_HAIRENCHANT_OK_BTN_") == true then
        return true
    end
    -- 希望オプションが付いて「続けますか？」を出している間も回している扱いにする。
    -- ここで「魔法付与」へ戻すと、返事を待っているだけなのに終わったように見えるうえ、
    -- そのボタンを押せると連続付与が二重に走り出す
    local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
    return reroll_option ~= nil and reroll_option:GetUserValue("ASKING") == "yes"
end

-- 素の「마법 부여」ボタンを、回している間だけ「停止」の見た目と状態にする。
--
-- **auto_run は立てないこと。** 素は auto_run == 1 だと HIGH_HAIRENCHANT_SUCEECD_RESULT
-- の中で自前の連続処理を始めてしまう(結果のたびに HIGH_HAIRENCHANT_OK_BTN を呼ぶので
-- こちらのループと二重に撃つ。目標未設定だと match_count >= goal_count が 0 >= 0 で
-- 成立して毎回 RESET_HIGH_ENCHANT まで走る)。
-- ここで欲しいのはボタンの表示と State だけなので、素の
-- HIGH_ENCHANT_CHANGE_BUTTON_STATE を呼ぶ間だけ auto_run を立てて、すぐ戻す。
-- こうしておけば表示文言(ClMsg)や State の決め方が素で変わっても付いていける
hair_enchant_sync_send_button = function()
    local frame = ui.GetFrame("high_hairenchant")
    if frame == nil or frame:IsVisible() == 0 then
        return
    end
    local send_ok = GET_CHILD_RECURSIVELY(frame, "send_ok")
    if send_ok == nil then
        return
    end
    local running = hair_enchant_is_running()
    local want = running and 0 or 1
    if send_ok:GetUserIValue("State") == want then
        return
    end
    if running then
        local keep = frame:GetUserIValue("auto_run")
        frame:SetUserValue("auto_run", 1)
        HIGH_ENCHANT_CHANGE_BUTTON_STATE(frame, 0)
        frame:SetUserValue("auto_run", keep or 0)
    else
        HIGH_ENCHANT_CHANGE_BUTTON_STATE(frame, 1)
    end
    core_g.vlog("mini_addons: ヘアエンチャント 付与ボタンを「%s」にした", running and "停止" or "魔法付与")
end

-- 自前の窓を畳む(素の窓や設定には触らない)。機能 OFF になったときや、
-- 「高度な設定」ボタンをもう一度押したときに使う
local function hair_enchant_close_advanced()
    local stale = ui.GetFrame(addon_name_lower .. "reroll_option")
    if stale == nil then
        return false
    end
    local high_hairenchant = ui.GetFrame("high_hairenchant")
    if high_hairenchant then
        high_hairenchant:StopUpdateScript("Mini_addons_HIGH_HAIRENCHANT_OK_BTN_")
    end
    -- 目標ランク指定で灰色にしていたら戻す(戻し先は素のフレームなので必須)
    hair_enchant_set_rank_up_enabled(true)
    ui.DestroyFrame(stale:GetName())
    -- 付与ボタンも「停止」から戻す。窓を畳むと監視スクリプトも止まるので、
    -- ここで戻さないと「停止」表示のまま取り残される。
    -- **必ず DestroyFrame の後に呼ぶこと。** 先に呼ぶと、確認ダイアログの返事待ち
    -- (ASKING == "yes")の最中に閉じたときに「まだ回している」と判定されてしまい、
    -- 「停止」表示のまま誰も戻せなくなる
    hair_enchant_sync_send_button()
    return true
end

-- × ボタン。**自前の窓だけ畳む。** 素の RESET_HIGH_ENCHANT までは走らせない
-- (素の「設定」で入れたオプション指定を、こちらを閉じただけで消さないため)。
-- 連続付与を強制的に止めたいときは Cancel ボタン(素の CLOSE_BTN)を使う
function Mini_addons_hair_enchant_adv_close(parent, ctrl)
    SET_REPEAT_COUNT_TEXT(0)
    hair_enchant_close_advanced()
end

-- 「高度な設定」ボタン。素の「設定」とは別物で、素の hairenchant_option には触らない
-- (閉じも開きもしない)。押すたびに自前の窓を開く / 畳むのトグル
function Mini_addons_hair_enchant_adv_btn(parent, ctrl)
    if g.settings.hair_enchant == 0 then
        core_g.vlog("mini_addons: ヘアエンチャント 機能 OFF なので高度な設定は開かない(自前の窓=%s)",
            hair_enchant_close_advanced() and "残っていたので畳んだ" or "無し")
        return
    end
    if hair_enchant_close_advanced() then
        core_g.vlog("mini_addons: ヘアエンチャント 高度な設定を畳んだ(もう一度押された)")
        return
    end
    hair_enchant_open_advanced()
end

