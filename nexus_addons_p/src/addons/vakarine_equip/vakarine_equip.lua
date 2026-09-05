-- vakarine_equip ここから
-- 着脱対象になりうる部位と、その装備スロット番号。
-- キャラ設定の初期化・設定画面のチェックボックス・チェック有無の判定・実際の着脱、
-- **この 4 箇所すべてがここだけを見る**。以前は名前の一覧と番号の対応表が別々にあり、
-- 部位を 1 つ足すとチェックボックスは増えるのに着脱の対象表には載らない、という
-- 半端な壊れ方をしていた(設定画面には出るのに何も脱がない)。
g.vakarine_equip_spots = {{
    name = "RH",
    index = 8
}, {
    name = "LH",
    index = 9
}, {
    name = "RH_SUB",
    index = 30
}, {
    name = "LH_SUB",
    index = 31
}, {
    name = "RING1",
    index = 17
}, {
    name = "RING2",
    index = 18
}, {
    name = "SHIRT",
    index = 3
}, {
    name = "PANTS",
    index = 14
}, {
    name = "GLOVES",
    index = 4
}, {
    name = "BOOTS",
    index = 5
}, {
    name = "SHOULDER",
    index = 34
}, {
    name = "BELT",
    index = 33
}, {
    name = "NECK",
    index = 19
}}

-- 自動起動の対象にするマップ種別。設定画面のチェックと判定で共有する。
--
-- **既定値は「この項目を入れる前の動作」をそのまま再現している。**
-- インスタンス系は作動、フィールドと分裂とその他ダンジョンは対象外。
-- 以前は「JSR で作動」の 1 個だけで、しかもボス協同戦は MapType が Instance のため
-- チェックの ON/OFF に関わらず作動していた(= 何も効いていなかった)。
--
-- 判定材料は実機で確認済み(2026-07-29)。同じ調査を繰り返さないこと:
--   ボス協同戦     field_d_cathedral_78_1     (11219, Instance) = FieldBossMap
--   週間ボスレイド weekly_d_underfortress_68_1 (11205, Instance) = WeeklyBossMap
--   通常レイド     Raid_Zmei                  (11291, Instance) = IsRaidField;NoTrade;NoWarp;HealControl
--   ヴェルニケ     d_solo_dungeon             (8022,  Dungeon)  = solo_dungeon
--   フィールド     ep13_f_siauliai_1          (11209, Field)    = None
-- ボス協同戦と週間ボスレイドは**別のキーワード**で、どちらも MapType は Instance。
-- 通常レイドは IsRaidField なので、この 2 つとは区別できる。
g.vakarine_equip_map_kinds = {{
    key = "jsr",
    default = 1,
    ja = "JSR（ボス協同戦）",
    en = "JSR (boss co-op)"
}, {
    key = "wbr",
    default = 1,
    ja = "WBR（週間ボスレイド）",
    en = "WBR (weekly boss raid)"
}, {
    key = "instance",
    default = 1,
    ja = "インスタンスダンジョン（レイド/ミッション）",
    en = "Instanced dungeon (raid/mission)"
}, {
    key = "velnike",
    default = 1,
    ja = "ヴェルニケ",
    en = "Velnice"
}, {
    key = "sanctuary",
    default = 1,
    ja = "未知の聖域3F",
    en = "Unknown Sanctuary 3F"
}, {
    key = "split",
    default = 0,
    ja = "分裂",
    en = "Split"
}, {
    key = "field",
    default = 0,
    ja = "フィールド",
    en = "Field"
}, {
    key = "dungeon",
    default = 0,
    ja = "その他のダンジョン",
    en = "Other dungeons"
}}

function Vakarine_equip_save_settings()
    g.save_json(g.vakarine_equip_path, g.vakarine_equip_settings)
end

function Vakarine_equip_load_settings()
    g.vakarine_equip_path = string.format("../addons/%s/%s/vakarine_equip.json", addon_name_lower, g.active_id)
    local settings = g.load_json(g.vakarine_equip_path)
    if not settings then
        settings = {
            buffid = {},
            delay = 0.1,
            x = 0,
            y = 0,
            move = 1,
            chars = {},
            auto_remove = 0,
            open_inventory = 1
        }
    end
    -- 作動するマップ種別。**キー単位で既定値を補うこと。** 項目を後から足すので、
    -- 「maps が在るかどうか」だけで見ると、増えた分が nil のまま判定に来る。
    -- 旧 settings の jsr は引き継がない。ボス協同戦は MapType が Instance で、
    -- あの設定は ON/OFF どちらでも作動していた = 引き継ぐ意味のある値ではない。
    if type(settings.maps) ~= "table" then
        settings.maps = {}
    end
    for _, kind in ipairs(g.vakarine_equip_map_kinds) do
        if settings.maps[kind.key] == nil then
            settings.maps[kind.key] = kind.default
        end
    end
    -- 着脱のときにインベントリを開くか。**既定は開く(1) = 従来どおりの動き。**
    -- 開かなくても装備できることは実機で確認済み(素の ITEM_EQUIP はインベントリの
    -- フレームに触れない)。一方で開くとアイテム 1 個につき枠を 1 つ作るため、
    -- 所持 1900 個の環境では着脱が始まる前に 2218ms を食っていた。
    -- **速くしたい人が 0 にする**という向きにしてある(既定を変えると、これまで
    -- 開いていた人にとっては挙動が変わるため)。
    -- **キー単位で補うこと。** 既に settings.json がある人は、この行が無いと nil のまま来る。
    if settings.open_inventory == nil then
        settings.open_inventory = 1
    end
    -- 以前は「チェックを外した」印に false を書いていた。読む側にとっては「無い」と
    -- 同じなので、読み込みのついでに落とす。放っておくと触ったバフの数だけ残り続け、
    -- バフ通知ごとに引く表を無駄に太らせる。
    if type(settings.buffid) == "table" then
        local dropped = 0
        for id_str, val in pairs(settings.buffid) do
            if not val then
                settings.buffid[id_str] = nil
                dropped = dropped + 1
            end
        end
        if dropped > 0 then
            g.vlog("vakarine_equip: 自動削除リストから意味のない行を %d 件落とした", dropped)
        end
    end
    g.vakarine_equip_settings = settings
    Vakarine_equip_save_settings()
end

-- 設定とこのキャラの枠を用意する。**OFF のときも必ず通すこと。**
-- 設定ボタンは use に関係なくアドオン一覧に出るので、chars[g.cid] が無いまま
-- Vakarine_equip_config_frame_open が呼ばれると nil を index して落ちる
-- (既定は OFF なので、入れて最初に設定を開いた人が必ず踏む)。
function Vakarine_equip_ensure_settings()
    if not g.vakarine_equip_settings then
        Vakarine_equip_load_settings()
    end
    if not g.vakarine_equip_settings.chars[g.cid] then
        Vakarine_equip_chrs_settings()
    end
end

function vakarine_equip_on_init()
    ui.SetHoldUI(false)
    Vakarine_equip_ensure_settings()
    -- 保険。OFF のときは core が on_init ではなく vakarine_equip_on_teardown を呼ぶ。
    if g.settings.vakarine_equip.use == 0 then
        vakarine_equip_on_teardown()
        return
    end
    g.register_msg('STAT_UPDATE', 'Vakarine_equip_stat_update')
    g.register_msg('TAKE_DAMAGE', 'Vakarine_equip_stat_update')
    g.register_msg('TAKE_HEAL', 'Vakarine_equip_stat_update')
    g.register_msg('BUFF_ADD', 'Vakarine_equip_BUFF_ON_MSG')
    g.register_msg('BUFF_UPDATE', 'Vakarine_equip_BUFF_ON_MSG')
    Vakarine_equip_frame_init()
    if g.get_map_type() ~= "City" then
        Vakarine_equip_start_operation()
    end
end

-- 機能 OFF にされたときの後始末(core/20_lifecycle.lua が use==0 のとき on_init の
-- 代わりに呼ぶ)。フレームを消すだけでなく購読も外す。外さないと OFF でも
-- STAT_UPDATE / TAKE_DAMAGE / BUFF_ADD が届き続け、消したフレームを触りに行く。
function vakarine_equip_on_teardown()
    -- 設定は OFF でも読んでおく(以前は on_init が OFF でも呼ばれていたので読まれていた)。
    -- chars[g.cid] まで作るのは、OFF のまま設定画面を開けるため(上のコメント参照)。
    Vakarine_equip_ensure_settings()
    ui.SetHoldUI(false)
    g.unregister_msg_by_prefix("Vakarine_equip_")
    ui.DestroyFrame(addon_name_lower .. "vakarine_equip")
end

function Vakarine_equip_chrs_settings()
    g.vakarine_equip_settings.chars[g.cid] = {
        use = 0
    }
    for _, spot in ipairs(g.vakarine_equip_spots) do
        g.vakarine_equip_settings.chars[g.cid][spot.name] = 0
    end
    Vakarine_equip_save_settings()
end

function Vakarine_equip_frame_init()
    local vakarine_equip = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "vakarine_equip", 0, 0, 0, 0)
    AUTO_CAST(vakarine_equip)
    vakarine_equip:SetSkinName("None")
    vakarine_equip:SetTitleBarSkin("None")
    vakarine_equip:Resize(40, 30)
    vakarine_equip:SetGravity(ui.RIGHT, ui.TOP)
    vakarine_equip:EnableMove(g.vakarine_equip_settings.move == 1 and 0 or 1)
    vakarine_equip:EnableHittestFrame(1)
    local rect = vakarine_equip:GetMargin()
    vakarine_equip:SetMargin(rect.left - rect.left, rect.top - rect.top + 300,
        rect.right == 0 and rect.right + 10 or rect.right, rect.bottom)
    if g.vakarine_equip_settings.x ~= 0 and g.vakarine_equip_settings.y ~= 0 then
        vakarine_equip:SetPos(g.vakarine_equip_settings.x, g.vakarine_equip_settings.y)
    end
    vakarine_equip:SetEventScript(ui.LBUTTONUP, "Vakarine_equip_location_save")
    local vaka_pic = vakarine_equip:CreateOrGetControl("picture", "vaka_pic", 0, 0, 30, 30)
    AUTO_CAST(vaka_pic)
    vaka_pic:SetImage("bakarine_emotion68") -- vaka_pic:SetImage("bakarine_emotion61") vaka_pic:SetImage("emoticon_0024")
    vaka_pic:SetColorTone("FFFFFFFF")
    vaka_pic:SetEnableStretch(1)
    vaka_pic:EnableHitTest(1)
    vaka_pic:SetGravity(ui.LEFT, ui.TOP)
    vaka_pic:SetTextTooltip(g.lang == "Japanese" and
                                "{ol}Vakarine Equip{nl} {nl}左クリック{nl}街: 設定{nl}街以外: 手動起動{nl} {nl}右クリック{nl}自動起動ON/OFF" or
                                "{ol}Vakarine Equip{nl} {nl}Left click{nl}City: Setup{nl}Outside City: Manual activation{nl} {nl}Right click: Auto-activation ON/OFF")
    if g.vakarine_equip_settings.chars[g.cid].use == 0 then
        vaka_pic:SetColorTone("FF555555")
    else
        vaka_pic:SetColorTone("FFFFFFFF")
    end
    vaka_pic:SetEventScript(ui.RBUTTONUP, "Vakarine_equip_onoff_switch")
    vaka_pic:SetEventScript(ui.LBUTTONUP, "Vakarine_equip_config_or_startup")
    vakarine_equip:ShowWindow(1)
    if g.vakarine_equip_animas_iesid and g.get_map_type() == "City" then
        vakarine_equip:RunUpdateScript("Vakarine_equip_animas_equip", 1.0)
    end
end

function Vakarine_equip_location_save(frame, ctrl)
    if frame:GetName() == addon_name_lower .. "vakarine_equip" then
        g.vakarine_equip_settings.x = frame:GetX()
        g.vakarine_equip_settings.y = frame:GetY()
    elseif ctrl:GetName() == "default_btn" then
        g.vakarine_equip_settings.x = 0
        g.vakarine_equip_settings.y = 0
        ui.DestroyFrame(addon_name_lower .. "vakarine_equip")
        ReserveScript("Vakarine_equip_frame_init()", 0.1)
    end
    Vakarine_equip_save_settings()
end

function Vakarine_equip_onoff_switch(vakarine_equip, vaka_pic)
    if g.vakarine_equip_settings.chars[g.cid].use == 0 then
        g.vakarine_equip_settings.chars[g.cid].use = 1
        vaka_pic:SetColorTone("FFFFFFFF")
    else
        vaka_pic:SetColorTone("FF555555")
        g.vakarine_equip_settings.chars[g.cid].use = 0
    end
    Vakarine_equip_save_settings()
    if keyboard.IsKeyPressed("LSHIFT") == 1 then
        Vakarine_equip_buff_list(nil, nil, "")
        return
    end
end

function Vakarine_equip_animas_equip(vakarine_equip)
    local equip_item_list = session.GetEquipItemList()
    local equip_item = equip_item_list:GetEquipItemByIndex(19)
    if equip_item then
        local iesid = equip_item:GetIESID()
        local try = vakarine_equip:GetUserIValue("TRY")
        if iesid ~= g.vakarine_equip_animas_iesid and try < 3 then
            local equip_item = session.GetInvItemByGuid(g.vakarine_equip_animas_iesid)
            item.Equip(equip_item.invIndex)
            vakarine_equip:GetUserIValue("TRY", try + 1)
            return 1
        end
    end
    vakarine_equip:GetUserIValue("TRY", 0)
    g.vakarine_equip_animas_iesid = nil
    return 0
end

function Vakarine_equip_config_or_startup(frame, ctrl)
    if g.get_map_type() == "City" then
        Vakarine_equip_config_frame_open()
    else
        Vakarine_equip_start_operation(true)
    end
end

-- ボス協同戦(JSR)のマップかどうか。マップ ID の直書きだと運営側でマップが
-- 追加されたときに漏れるので、マップの Keyword で見る。
--
-- **キーワードは "FieldBossMap"。** 実機で確認した対応は次のとおり(2026-07-29):
--   ボス協同戦 field_d_cathedral_78_1 (11219, Instance) = FieldBossMap
--   通常レイド Raid_Zmei             (11291, Instance) = IsRaidField;NoTrade;NoWarp;HealControl
--   ヴェルニケ d_solo_dungeon        (8022,  Dungeon)  = solo_dungeon
--   フィールド ep13_f_siauliai_1     (11209, Field)    = None
-- 通常レイドは IsRaidField で、FieldBossMap は付かない = この 1 語で区別できる。
--
-- **"WeeklyBossMap" ではない。** 当初そちらで実装したが、実機では 1 度も一致しない。
-- あれは週間ボスレイド用で、ボス協同戦(FIELD_BOSS_JOIN で入るコンテンツ)とは
-- 別物だった。同じ調査を繰り返さないこと。
--
-- 判定は g.map_has_keyword に寄せてある(";" 区切りのトークン一致)。
-- 引けなかったときは false ではなく nil が返る。呼び出し側で区別すること。
function Vakarine_equip_is_field_boss_map()
    return g.map_has_keyword("FieldBossMap")
end

-- いま居るマップがどの種別に当たるか。g.vakarine_equip_map_kinds のキーを返す
-- (どれにも当たらなければ nil)。
--
-- **細かいものから順に見ること。** ボス協同戦も週間ボスレイドも MapType は Instance
-- なので、先に Keyword で拾わないと「インスタンスダンジョン」の設定に飲み込まれて、
-- 個別のチェックが何も効かなくなる(以前の「JSR で作動」がまさにその状態だった)。
--
-- ID で持っている 3 つ(ヴェルニケ/聖域3F/分裂)を先に見るのは、そちらの方が具体的で、
-- かつヴェルニケと聖域3F は MapType が Dungeon で Keyword からは辿れないため。
function Vakarine_equip_map_kind()
    if g.map_id == g.MAP_VELNIKE then
        return "velnike"
    end
    if g.map_id == g.MAP_SANCTUARY_3F then
        return "sanctuary"
    end
    if g.map_id == g.MAP_SPLIT then
        return "split"
    end
    if Vakarine_equip_is_field_boss_map() == true then
        return "jsr"
    end
    if g.map_has_keyword("WeeklyBossMap") == true then
        return "wbr"
    end
    local map_type = g.get_map_type()
    if map_type == "Instance" then
        return "instance"
    end
    if map_type == "Field" then
        return "field"
    end
    if map_type == "Dungeon" then
        return "dungeon"
    end
    return nil
end

-- 設定でチェックされている部位が 1 つでもあるか。インベントリを開く前に見て、
-- 0 個ならそもそも開かない(開いてから空で return すると開きっぱなしになる)。
function Vakarine_equip_has_checked_spot(char_settings)
    if not char_settings then
        return false
    end
    for _, spot in ipairs(g.vakarine_equip_spots) do
        if char_settings[spot.name] == 1 then
            return true
        end
    end
    return false
end

function Vakarine_equip_start_operation(is_manual)
    if not is_manual then
        local char_data = g.vakarine_equip_settings.chars[g.cid]
        if not char_data or char_data.use == 0 then
            return
        end
    end
    -- **同期部分の所要時間を計測する。** 自動起動は on_init の中から呼ばれるので、
    -- ここで使った時間はそのまま `init: vakarine_equip (Nms)` に出る。
    -- 実際に 2218ms(利用者の verbose_log.txt / 所持 1900 個)という報告があり、
    -- tick の待ち時間とは別に、着脱が始まる前へ丸ごと乗っていた。
    -- どの段が重いのかは持ち物の量で変わるので、段ごとに残して切り分けられるようにする。
    local t0 = imcTime.GetAppTimeMS()
    local is_vakarine = Vakarine_equip_is_vakarine()
    local t_vakarine = imcTime.GetAppTimeMS()
    if not is_vakarine and not is_manual then
        return
    end
    -- 作動するかは「このマップの種別」と「その種別のチェック」だけで決まる。
    -- 以前は「JSR で作動」の 1 個しか無く、しかも `or jsr == 1` が ON のとき
    -- マップ判定を丸ごと素通りしていたため、フィールドや旧ダンジョンを含む
    -- 都市以外の全マップで着脱が走っていた。そのうえボス協同戦は MapType が
    -- Instance なので **OFF にしても作動しており、チェックは飾りだった**。
    is_manual = is_manual and true or false
    local map_type = g.get_map_type()
    local kind = Vakarine_equip_map_kind()
    local is_valid_map = kind ~= nil and g.vakarine_equip_settings.maps[kind] == 1
    -- 「どの種別と判定したか」を必ず残す。ここが分からないと、作動した/しなかった
    -- 理由を利用者の verbose_log.txt から説明できない。
    local will_run = is_valid_map or is_manual
    g.vlog("VakarineEquip 起動判定: map_id=%s type=%s 種別=%s 設定=%s manual=%s -> %s", tostring(g.map_id),
        tostring(map_type), tostring(kind or "該当なし"),
        kind and tostring(g.vakarine_equip_settings.maps[kind]) or "-", tostring(is_manual),
        tostring(will_run))
    if will_run then
        local char_settings = g.vakarine_equip_settings.chars[g.cid]
        if not Vakarine_equip_has_checked_spot(char_settings) then
            -- 既定は全部位チェック無しなので、初めて手動で呼んだ人は必ずここを通る。
            -- 黙って return するとアドオンが壊れているようにしか見えないため、
            -- 手動のときだけ理由を伝える(自動は毎マップ出てしまうので出さない)。
            if is_manual then
                ui.SysMsg(g.lang == "Japanese" and
                    "{ol}{#FF6347}[女神の像]{/} 着脱する部位が 1 つも選択されていません。設定画面で部位を選んでください" or
                    "{ol}{#FF6347}[Vakarine]{/} No equipment slot is selected. Please choose slots in the settings.")
            end
            g.vlog("VakarineEquip 中止: 対象部位が 1 つもチェックされていない (manual=%s)", tostring(is_manual))
            return
        end
        local inventory = ui.GetFrame("inventory")
        -- **既定ではインベントリを開かない(設定で開くようにもできる)。**
        -- 以前は必ず inventory:ShowWindow(1) していたが、**着脱には要らない**。
        -- 素の ITEM_EQUIP は session.GetInvItem -> ITEM_EQUIP_MSG -> item.Equip と
        -- 辿るだけで、インベントリのフレームには一切触れない(素の game.lua を確認)。
        -- 一方、開くとアイテム 1 個につきスロットを 1 つ作るので、持ち物が多いほど重い。
        -- 所持 1900 個の利用者から「着脱前の同期処理だけで 2218ms」の報告があり
        -- (verbose_log.txt の `init: vakarine_equip (2218ms)`)、原因はこれだった。
        --
        -- **「実は開かないと装備できない」場合の保険は下の equip 段にある。**
        -- 着ける処理が進まないときだけ開いて続行し、その旨を vlog へ出す。
        -- 開いたかどうかは g.vakarine_equip_opened_inventory で持ち回し、
        -- **自分で開いたときだけ閉じる**(利用者が自分で開いていた窓を勝手に閉じない)。
        -- **計測はここから。** 開く処理を計測の外に置くと、設定を ON にした人の
        -- ログで「窓を開くのに何 ms 掛かったか」が分からなくなる(それが分からないと
        -- 遅さの相談を受けたときに切り分けられない)。
        local t_before_inv = imcTime.GetAppTimeMS()
        g.vakarine_equip_opened_inventory = false
        if g.vakarine_equip_settings.open_inventory == 1 and inventory:IsVisible() ~= 1 then
            g.vakarine_equip_opened_inventory = true
            inventory:ShowWindow(1)
        end
        -- 武器スワップの表示と CURRENT_WEAPON_INDEX を 1 側へ揃える。中身は画像の
        -- 差し替えと UserValue の設定だけなので、窓が見えている必要はない(素を確認)。
        DO_WEAPON_SLOT_CHANGE(inventory, 1)
        local t_inv = imcTime.GetAppTimeMS()
        ui.SetHoldUI(true)
        local vakarine_equip = ui.GetFrame(addon_name_lower .. "vakarine_equip")
        -- **HoldUI を掛けたら、その場で解除の保険を仕掛けること。**
        -- 一度これを「実際に着脱を始めると決めてから」まで後ろへ動かしたが、
        -- 間の処理(装備一覧の取得やキューの組み立て)で落ちると **UI ロックが
        -- 掛かりっぱなしになり、掲示板もインベントリも何も開けなくなる**
        -- (次のマップ移動で on_init が SetHoldUI(false) するまで戻らない)。実機で発生。
        -- 早い段階で仕掛けても実害は無い: 途中で抜ける経路は自分で SetHoldUI(false) を
        -- 呼ぶので、10 秒後の解除は「もう解除済みのものをもう一度解除する」だけになる。
        vakarine_equip:RunUpdateScript("Vakarine_equip_holdui_release", 10.0)
        g.vakarine_equip_queue = {}
        local checked_count = 0
        local equip_item_list = session.GetEquipItemList()
        for _, spot in ipairs(g.vakarine_equip_spots) do
            if char_settings[spot.name] == 1 then
                checked_count = checked_count + 1
                local current_item = equip_item_list:GetEquipItemByIndex(spot.index)
                if current_item then
                    table.insert(g.vakarine_equip_queue, {
                        spot = spot.name,
                        index = spot.index,
                        iesid = current_item:GetIESID()
                    })
                end
            end
        end
        local t_queue = imcTime.GetAppTimeMS()
        -- **ここが第 2 容疑者。** アニマス(首飾り)を持っているかは名前でしか引けず、
        -- カバンの中を探すことになる。装備欄を見ても、着けていないものは見つからない。
        local animas_item = session.GetInvItemByName("NECK04_103")
        g.vakarine_equip_animas_iesid = animas_item and animas_item:GetIESID() or nil
        local t_animas = imcTime.GetAppTimeMS()
        g.vlog("VakarineEquip 準備の内訳: 合計=%dms (祝福判定=%d 窓と武器欄=%d キュー=%d アニマス探し=%d) 部位=%d",
            t_animas - t0, t_vakarine - t0, t_inv - t_before_inv, t_queue - t_inv, t_animas - t_queue,
            #g.vakarine_equip_queue)
        if #g.vakarine_equip_queue == 0 then
            -- チェックはあるが該当部位を装備していない場合。判断材料になるのは
            -- 「何部位チェックされていたか」で、0 なら上で弾かれているはずなので、
            -- ここに来た時点で「チェックはあるが装備していない」が確定する。
            g.vlog("VakarineEquip 中止: チェックした %d 部位をどれも装備していない (manual=%s)", checked_count,
                tostring(is_manual))
            ui.SetHoldUI(false)
            return
        end
        for i, data in ipairs(g.vakarine_equip_queue) do
            if data.spot == "RH_SUB" then
                item.UnEquip(data.index)
                break
            end
        end
        -- 所要時間の計測。改善の前後を利用者の verbose_log.txt で比べられるよう、
        -- ms と tick 数の両方を残す。tick 数が無いと「delay が長いのか、
        -- サーバの往復待ちが長いのか」を切り分けられない。
        g.vakarine_equip_start_ms = imcTime.GetAppTimeMS()
        g.vakarine_equip_ticks = 0
        g.vakarine_equip_sent = 0
        g.vakarine_equip_lookup_ms = 0
        g.vakarine_equip_lookup_count = 0
        g.vakarine_equip_equip_start_ms = nil
        g.vakarine_equip_process_step = "unequip"
        vakarine_equip:RunUpdateScript("Vakarine_equip_main_loop", g.vakarine_equip_settings.delay)
    end
end

-- IESID からインベントリの添字を引く。**計測付きの薄い包み。**
-- 素の ITEM_EQUIP は「インベントリの添字」を要求するのに、こちらが控えているのは
-- IESID(アイテム個体の ID)なので、着けるたびに引き直すことになる。1 tick に 1 回、
-- 1 回の着脱で 30〜40 回。**インベントリの量に効きうる箇所は、開くのをやめた今、
-- ここと アニマス探し(GetInvItemByName)だけ。** 所持 1900 個の環境で効いているかは
-- 未計測なので、回数と合計 ms を残して完了ログに出す。
-- 合計が 0 のまま回数だけ増えるなら、1 回あたり 1ms 未満 = 無視してよいということ。
function Vakarine_equip_find_inv_item(iesid)
    local started = imcTime.GetAppTimeMS()
    local inv_item = session.GetInvItemByGuid(iesid)
    g.vakarine_equip_lookup_ms = (g.vakarine_equip_lookup_ms or 0) + (imcTime.GetAppTimeMS() - started)
    g.vakarine_equip_lookup_count = (g.vakarine_equip_lookup_count or 0) + 1
    return inv_item
end

function Vakarine_equip_main_loop(vakarine_equip)
    local equip_item_list = session.GetEquipItemList()
    if g.vakarine_equip_process_step == "unequip" then
        g.vakarine_equip_ticks = (g.vakarine_equip_ticks or 0) + 1
        -- **外す要求は 1 tick に 1 部位。まとめて投げないこと。**
        -- 「13 部位ぶんを 1 tick でまとめて投げれば一括で脱げる」を実機で試したところ、
        -- **1 回のまとめ投げにつき 1 部位しか外れなかった**(残り 12 件は捨てられる)。
        -- 外れるのを待って投げ直す作りにしたため、13 部位で 28.6 秒かかった
        -- (2026-09-04 の verbose_log.txt で実測。1 部位ずつのときより桁違いに遅い)。
        -- 装備の変更は同時に 1 件しか受け付けられないと考えられる。
        --
        -- 部位を選べる一括の関数も素には無い。外す手段は item.UnEquip(部位 1 つ)と
        -- session.job.ReqUnEquipItemAll(引数なし = 全装備固定)の 2 つだけで、
        -- 後者は「チェックした部位だけ」というこのアドオンの作りと噛み合わない
        -- (チェック外の部位まで外れ、控えが無いので外れっぱなしになる)。
        --
        -- したがってここは「まだ外れていない先頭の 1 部位へ投げて次の tick を待つ」形。
        -- 反映が返るまで同じ部位へ投げ直すことになるが、**この投げ直しは無駄ではない**。
        -- 要求は実際に落ちるので、これが落ちた分を素早く埋め直している。
        --
        -- **「見に行く間隔(0.03 秒)と投げる間隔を分ける」を試したが、効果は無かった。**
        -- 反映に気付くのが早くなるぶん速くなるはずだったが、13 部位の実測は
        --   変更前(毎 tick 投げ直す)   2047 / 2535 / 2589 ms          平均 2390
        --   投げ直し 1.0 秒            2312〜6575 ms                  平均 5104
        --   投げ直し 0.3 秒            1798〜3336 ms                  平均 2666
        --   投げ直し 0.15 秒(11 回)    1827〜3012 ms                  平均 2588
        -- と、**どう詰めても変更前を上回らなかった**(送信回数だけ増えた)。
        -- 待ち時間を決めているのはサーバの往復で、しかも 1 部位に 1 秒以上かかることが
        -- ある。こちらから詰められる余地は無い。**同じことを試さないこと。**
        for _, data in ipairs(g.vakarine_equip_queue) do
            local current_item = equip_item_list:GetEquipItemByIndex(data.index)
            if current_item and current_item:GetIESID() ~= "0" then
                item.UnEquip(data.index)
                g.vakarine_equip_sent = (g.vakarine_equip_sent or 0) + 1
                return 1
            end
        end
        -- ここまで来た = 対象の部位が 1 つも残っていない。
        g.vlog("VakarineEquip 脱ぎ終わり: %d 部位 / 送信 %d 回 / %d 回見た / %d ms", #g.vakarine_equip_queue,
            g.vakarine_equip_sent or 0, g.vakarine_equip_ticks,
            imcTime.GetAppTimeMS() - (g.vakarine_equip_start_ms or 0))
        g.vakarine_equip_process_step = "equip"
        return 1
    elseif g.vakarine_equip_process_step == "equip" then
        g.vakarine_equip_ticks = (g.vakarine_equip_ticks or 0) + 1
        local now = imcTime.GetAppTimeMS()
        if not g.vakarine_equip_equip_start_ms then
            g.vakarine_equip_equip_start_ms = now
        end
        -- **「インベントリを開かないと装備できない」場合の保険。**
        -- 1 部位につき settings.delay ぶん掛かるので、それに 3 秒の余裕を足しても
        -- 終わらないなら、開かなかったことが原因である可能性を疑って開き直す。
        -- **tick 数ではなく経過時間で測ること。** ループの間隔は settings.delay で
        -- 利用者が変えられるので、回数で測ると設定次第で誤判定する。
        -- 一度きりで、開いたことは必ず vlog へ残す(この行が出るなら仮説が外れている)。
        -- 既に出ているときは何もしない(設定 ON で自分が開いた場合と、利用者が自分で
        -- 開いていた場合。どちらも「開いていないせい」ではないので、この行を出すと
        -- 仮説が外れた合図として誤って読まれる)。
        if not g.vakarine_equip_opened_inventory and ui.GetFrame("inventory"):IsVisible() ~= 1 and
            now - g.vakarine_equip_equip_start_ms >
            #g.vakarine_equip_queue * g.vakarine_equip_settings.delay * 1000 + 3000 then
            g.vakarine_equip_opened_inventory = true
            ui.GetFrame("inventory"):ShowWindow(1)
            g.vlog("{#FF6347}VakarineEquip: 着ける処理が %d ms 進まないのでインベントリを開いて続ける" ..
                       "(開かずに装備できるという前提が外れている){/}",
                now - g.vakarine_equip_equip_start_ms)
        end
        local weapon_order = {"RH", "LH", "RH_SUB", "LH_SUB"}
        for _, spot_name in ipairs(weapon_order) do
            for _, data in ipairs(g.vakarine_equip_queue) do
                if data.spot == spot_name then
                    local current_item = equip_item_list:GetEquipItemByIndex(data.index)
                    if not current_item or current_item:GetIESID() ~= data.iesid then
                        local inv_item = Vakarine_equip_find_inv_item(data.iesid)
                        if inv_item then
                            g.vakarine_equip_sent = (g.vakarine_equip_sent or 0) + 1
                            ITEM_EQUIP(inv_item.invIndex, data.spot)
                            return 1
                        end
                    end
                    break
                end
            end
        end
        for _, data in ipairs(g.vakarine_equip_queue) do
            local spot_name = data.spot
            if spot_name ~= "RH" and spot_name ~= "LH" and spot_name ~= "RH_SUB" and spot_name ~= "LH_SUB" and spot_name ~=
                "NECK" then
                local current_item = equip_item_list:GetEquipItemByIndex(data.index)
                if not current_item or current_item:GetIESID() ~= data.iesid then
                    local inv_item = Vakarine_equip_find_inv_item(data.iesid)
                    if inv_item then
                        g.vakarine_equip_sent = (g.vakarine_equip_sent or 0) + 1
                        ITEM_EQUIP(inv_item.invIndex, data.spot)
                        return 1
                    end
                end
            end
        end
        for _, data in ipairs(g.vakarine_equip_queue) do
            if data.spot == "NECK" then
                local iesid_to_equip = g.vakarine_equip_animas_iesid or data.iesid
                local current_item = equip_item_list:GetEquipItemByIndex(data.index)
                local current_iesid = current_item and current_item:GetIESID() or "0"
                if current_iesid ~= iesid_to_equip then
                    local inv_item = Vakarine_equip_find_inv_item(iesid_to_equip)
                    if inv_item then
                        g.vakarine_equip_sent = (g.vakarine_equip_sent or 0) + 1
                        ITEM_EQUIP(inv_item.invIndex, data.spot)
                        return 1
                    end
                end
                break
            end
        end
        -- **自分で開いたときだけ閉じる。** 通常は開いていないので何もしない。
        -- 無条件に閉じると、利用者が自分で開いていたインベントリまで畳んでしまう。
        if g.vakarine_equip_opened_inventory then
            ui.GetFrame("inventory"):ShowWindow(0)
            g.vakarine_equip_opened_inventory = false
        end
        imcAddOn.BroadMsg("NOTICE_Dm_stage_start", "[VE]End of Operation", 3)
        ui.SetHoldUI(false)
        g.vlog("VakarineEquip 完了: %d 部位 / 送信 %d 回 / %d 回見た / %d ms (delay=%.2f 添字引き %d 回 %d ms)",
            #g.vakarine_equip_queue, g.vakarine_equip_sent or 0, g.vakarine_equip_ticks or 0,
            imcTime.GetAppTimeMS() - (g.vakarine_equip_start_ms or 0), g.vakarine_equip_settings.delay,
            g.vakarine_equip_lookup_count or 0, g.vakarine_equip_lookup_ms or 0)
        return 0
    end
    return 1
end

function Vakarine_equip_is_vakarine()
    local equip_item_list = session.GetEquipItemList()
    local equip_guid_list = equip_item_list:GetGuidList()
    local count = equip_guid_list:Count()
    local vakarine_count = 0
    for i = 0, count - 1 do
        local guid = equip_guid_list:Get(i)
        if guid ~= '0' then
            local equip_item = equip_item_list:GetItemByGuid(guid)
            local item = GetIES(equip_item:GetObject())
            for j = 1, MAX_OPTION_EXTRACT_COUNT do
                local prop_name = "RandomOption_" .. j
                local cls_msg = ScpArgMsg(item[prop_name])
                if string.find(cls_msg, "vakarine_bless") then
                    vakarine_count = vakarine_count + 1
                    break
                end
            end
        end
    end
    if vakarine_count >= 5 then
        return true
    elseif vakarine_count == 4 then
        return false
    else
        return false
    end
end

function Vakarine_equip_holdui_release(frame)
    ui.SetHoldUI(false)
    return 0
end

function Vakarine_equip_config_frame_open()
    local config = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "vakarine_equip_config_frame", 0, 0, 0, 0)
    AUTO_CAST(config)
    g.block_click_through(config)
    config:RemoveAllChild()
    config:SetLayerLevel(999)
    config:SetSkinName("test_frame_low")
    local title_text = config:CreateOrGetControl("richtext", "title_text", 10, 10)
    AUTO_CAST(title_text)
    title_text:SetText("{ol}Vakarine Equip")
    local config_gb = config:CreateOrGetControl("groupbox", "config_gb", 10, 40, 0, 0)
    AUTO_CAST(config_gb)
    config_gb:SetSkinName("bg")
    local close = config:CreateOrGetControl("button", "close", 0, 0, 20, 20)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Vakarine_equip_frame_close")
    -- 自動起動するマップ種別。以前は「チェックするとJSRで作動」の 1 個だけで、
    -- それがどこに効くのかが分からないうえ、実際には効いてもいなかった
    -- (Vakarine_equip_map_kind のコメント参照)。種別ごとに並べて、
    -- 「チェックしたところだけで作動する」を見たままにする。
    local x = 0
    local y = 5
    local maps_label = config_gb:CreateOrGetControl("richtext", "maps_label", 10, y)
    AUTO_CAST(maps_label)
    maps_label:SetText(g.lang == "Japanese" and "{ol}自動で作動する場所" or "{ol}Where it runs automatically")
    if x < maps_label:GetWidth() then
        x = maps_label:GetWidth()
    end
    y = y + 25
    for i, kind in ipairs(g.vakarine_equip_map_kinds) do
        local map_check = config_gb:CreateOrGetControl('checkbox', "map_check" .. i, 10, y, 30, 30)
        AUTO_CAST(map_check)
        -- `or 0` を外さないこと。項目を後から足すと、保存済みの設定にそのキーが無い。
        -- nil を SetCheck に渡すと落ちて、json を消すまで設定画面が開かなくなる。
        map_check:SetCheck(g.vakarine_equip_settings.maps[kind.key] or 0)
        map_check:SetText("{ol}" .. (g.lang == "Japanese" and kind.ja or kind.en))
        map_check:SetTextTooltip(g.lang == "Japanese" and "{ol}チェックした場所でだけ自動で着脱します" or
                                     "{ol}Runs automatically only where checked")
        map_check:SetEventScript(ui.LBUTTONUP, "Vakarine_equip_check_switch")
        map_check:SetEventScriptArgString(ui.LBUTTONUP, kind.key)
        if x < map_check:GetWidth() then
            x = map_check:GetWidth()
        end
        y = y + 30
    end
    local spots_label = config_gb:CreateOrGetControl("richtext", "spots_label", 10, y + 5)
    AUTO_CAST(spots_label)
    spots_label:SetText(g.lang == "Japanese" and "{ol}着脱する部位" or "{ol}Slots to swap")
    if x < spots_label:GetWidth() then
        x = spots_label:GetWidth()
    end
    y = y + 35
    for i, spot in ipairs(g.vakarine_equip_spots) do
        local equip_name = spot.name
        local check_box = config_gb:CreateOrGetControl('checkbox', "check_box" .. i, 20, y, 30, 30)
        AUTO_CAST(check_box)
        -- `or 0` を外さないこと。既存キャラの設定は Vakarine_equip_chrs_settings が
        -- **キャラ設定がまだ無いときにしか作らない**ので、後から部位を足すと
        -- 保存済みのキャラにはそのキーが無い。nil のまま SetCheck に渡すと落ちて、
        -- json を消すまで設定画面が二度と開かなくなる。
        check_box:SetCheck(g.vakarine_equip_settings.chars[g.cid][equip_name] or 0)
        check_box:SetTextTooltip(g.lang == "Japanese" and "{ol}チェックした装備を脱着します" or
                                     "{ol}Remove and detach checked equipment")
        check_box:SetEventScript(ui.LBUTTONUP, "Vakarine_equip_check_switch")
        check_box:SetEventScriptArgString(ui.LBUTTONUP, equip_name)
        if equip_name == "RING1" then
            equip_name = "Ring1"
        elseif equip_name == "RING2" then
            equip_name = "Ring2"
        elseif equip_name == "SHIRT" then
            equip_name = "Shirt"
        elseif equip_name == "PANTS" then
            equip_name = "Pants"
        end
        check_box:SetText("{ol}" .. ClMsg(equip_name))
        y = y + 30
    end
    y = y + 10
    local move_check = config_gb:CreateOrGetControl('checkbox', "move_check", 10, y, 30, 30)
    AUTO_CAST(move_check)
    move_check:SetCheck(g.vakarine_equip_settings.move)
    move_check:SetText(g.lang == "Japanese" and "{ol}チェックするとフレーム固定" or
                           "{ol}If checked, the frame is fixed")
    move_check:SetEventScript(ui.LBUTTONUP, "Vakarine_equip_check_switch")
    y = y + 30
    -- 着脱のときにインベントリを開くか。**既定は開かない。**
    -- 開かなくても装備できることは実機で確認済みだが、開いて確認したい人も居るので
    -- 選べるようにしてある(持ち物が多いほど開く分だけ待たされる点は下の説明に出す)。
    local open_inv_check = config_gb:CreateOrGetControl('checkbox', "open_inv_check", 10, y, 30, 30)
    AUTO_CAST(open_inv_check)
    open_inv_check:SetCheck(g.vakarine_equip_settings.open_inventory)
    open_inv_check:SetText(g.lang == "Japanese" and "{ol}着脱中にインベントリを開く" or
                               "{ol}Open the inventory while swapping")
    open_inv_check:SetTextTooltip(g.lang == "Japanese" and
                                      "{ol}着脱そのものには必要ありません{nl}持ち物が多いほど、開く分だけ着脱の開始が遅くなります" or
                                      "{ol}Not required for swapping{nl}The more items you carry, the longer the swap takes to start")
    open_inv_check:SetEventScript(ui.LBUTTONUP, "Vakarine_equip_check_switch")
    y = y + 40
    local default_btn = config_gb:CreateOrGetControl("button", "default_btn", 20, y, 120, 30)
    AUTO_CAST(default_btn)
    default_btn:SetText(g.lang == "Japanese" and "{ol}フレーム初期位置" or "{ol}Init frame pos")
    default_btn:SetEventScript(ui.LBUTTONUP, "Vakarine_equip_location_save")
    y = y + 30
    config:Resize(x + 70, y + 60)
    config_gb:Resize(x + 50, y + 10)
    local list_frame = ui.GetFrame(addon_name_lower .. "list_frame")
    if list_frame then
        config:SetPos(list_frame:GetX() + list_frame:GetWidth(), list_frame:GetY())
    else
        local map_frame = ui.GetFrame("map")
        local width = map_frame:GetWidth()
        config:SetPos(width / 2 - config:GetWidth() / 2 or 1165, 105)
    end
    config:ShowWindow(1)
    -- この関数はチェックボックスを押すたびに呼び直されるので、積み直さない形で積む
    -- (積み直すと、開いたままのバフ一覧より設定画面が手前になる)。
    local config_name = addon_name_lower .. "vakarine_equip_config_frame"
    g.esc_register_keep(config_name, function()
        ui.DestroyFrame(config_name)
    end)
end

function Vakarine_equip_check_switch(config, ctrl, equip_name, num)
    local ischeck = ctrl:IsChecked()
    if string.find(ctrl:GetName(), "map_check") then
        -- equip_name には g.vakarine_equip_map_kinds のキーが入っている
        g.vakarine_equip_settings.maps[equip_name] = ischeck
    elseif ctrl:GetName() == "move_check" then
        g.vakarine_equip_settings.move = ischeck
        Vakarine_equip_frame_init()
    elseif ctrl:GetName() == "open_inv_check" then
        g.vakarine_equip_settings.open_inventory = ischeck
    elseif string.find(ctrl:GetName(), "check_box") then
        g.vakarine_equip_settings.chars[g.cid][equip_name] = ischeck
        if equip_name == "RH_SUB" then
            g.vakarine_equip_settings.chars[g.cid]["LH_SUB"] = ischeck
        elseif equip_name == "LH_SUB" then
            g.vakarine_equip_settings.chars[g.cid]["RH_SUB"] = ischeck
        end
        Vakarine_equip_config_frame_open()
    end
    Vakarine_equip_save_settings()
end

function Vakarine_equip_stat_update()
    if g.settings.vakarine_equip.use == 0 then
        return
    end
    g.vakarine_equip_is_vakarine = Vakarine_equip_is_vakarine()
    local charbaseinfo1_my = ui.GetFrame("charbaseinfo1_my")
    if not charbaseinfo1_my then
        return
    end
    local hp = GET_CHILD(charbaseinfo1_my, "pcHpGauge")
    AUTO_CAST(hp)
    local handle = session.GetMyHandle()
    local stat = info.GetStat(handle)
    local hp_now = (stat.HP * 100) / stat.maxHP
    local status = ''
    local color = ""
    if (hp_now == 100) then
        color = '#00EC00'
        status = 'Perfect'
    elseif g.vakarine_equip_is_vakarine and (hp_now <= 45) then
        color = '#EA0000'
        status = 'Revenge'
    elseif not g.vakarine_equip_is_vakarine and (hp_now <= 35) then
        color = '#EA0000'
        status = 'Revenge'
    elseif hp_now == 0 then
        color = '#FFFFFF'
    else
        color = '#FFFFFF'
    end
    local effecttext =
        charbaseinfo1_my:CreateOrGetControl("richtext", "effecttext", 0, 0, hp:GetWidth(), hp:GetHeight())
    effecttext:SetText(string.format('{ol}{%s}{%s}%s', "s15", color, status))
    effecttext:SetGravity(ui.RIGHT, ui.TOP)
    effecttext:SetOffset(hp:GetX(), hp:GetY() - 25 - (15 - 15))
    local hptext = charbaseinfo1_my:CreateOrGetControl("richtext", "hptext", 0, 0, hp:GetWidth(), hp:GetHeight())
    hptext:SetText(string.format('{%s}{ol}{%s}%d%%', "s15", color, hp_now))
    hptext:SetGravity(ui.RIGHT, ui.TOP)
    hptext:SetOffset(hp:GetX(), hp:GetY() - 10 - (15 - 15))
end

-- **表を pairs で舐めないこと。** ここは BUFF_ADD / BUFF_UPDATE のたびに通る。
-- レイドではバフの通知が集中し、実測で 1 秒あたり 10 件を超える
-- (my_buffs_control の調査で計測。addons/my_buffs_control を参照)。
-- 表の件数ぶん tonumber と比較を回すと、指定を増やした人ほど重くなる。
-- キーは登録側(Vakarine_equip_buff_toggle)が SetEventScriptArgString で受けた
-- ClassID の文字列なので、tostring(buff_id) で一発引きできる。
--
-- 値は真偽で見る。**== true で見ないこと。** 旧い設定には「チェックを外した」印として
-- false が入っており、それを拾うと指定なしのバフまで解除しに行くことになる。
function Vakarine_equip_BUFF_ON_MSG(frame, msg, str, buff_id)
    if g.settings.vakarine_equip.use == 0 then
        return
    end
    local settings = g.vakarine_equip_settings
    if not settings or settings.auto_remove ~= 1 or not g.vakarine_equip_is_vakarine then
        return
    end
    local buffid = settings["buffid"]
    if buffid and buffid[tostring(buff_id)] then
        packet.ReqRemoveBuff(buff_id) -- 良くないね
    end
end

function Vakarine_equip_buff_list(buff_list, ctrl, ctrl_text)
    local buff_list = ui.GetFrame(addon_name_lower .. "Vakarine_equip_buff_list")
    if not buff_list then
        buff_list = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "vakarine_equip_buff_list", 0, 0, 0, 0)
        AUTO_CAST(buff_list)
        g.block_click_through(buff_list)
        buff_list:SetSkinName("test_frame_low")
        buff_list:Resize(500, 1060)
        buff_list:SetPos(150, 10)
        buff_list:SetLayerLevel(121)
        local search_edit = buff_list:CreateOrGetControl("edit", "search_edit", 40, 10, 305, 38)
        AUTO_CAST(search_edit)
        search_edit:SetFontName("white_18_ol")
        search_edit:SetTextAlign("left", "center")
        search_edit:SetSkinName("inventory_serch")
        search_edit:SetEventScript(ui.ENTERKEY, "Vakarine_equip_buff_list_search")
        g.setup_incremental_search(search_edit, "Vakarine_equip_buff_list_search")
        local search_btn = search_edit:CreateOrGetControl("button", "search_btn", 0, 0, 40, 38)
        AUTO_CAST(search_btn)
        search_btn:SetImage("inven_s")
        search_btn:SetGravity(ui.RIGHT, ui.TOP)
        search_btn:SetEventScript(ui.LBUTTONUP, "Vakarine_equip_buff_list_search")
        local func_toggle = buff_list:CreateOrGetControl('checkbox', 'func_toggle', 415, 15, 25, 25)
        AUTO_CAST(func_toggle)
        func_toggle:SetTextTooltip(g.lang == "Japanese" and "{ol}チェックすると自動バフ削除有効化" or
                                       "{ol}Check to enable auto buff removal")
        func_toggle:SetEventScript(ui.LBUTTONUP, "Vakarine_equip_buff_aoto_remove")
        func_toggle:SetCheck(g.vakarine_equip_settings.auto_remove or 0)
        local close = buff_list:CreateOrGetControl('button', 'close', 0, 0, 20, 20)
        AUTO_CAST(close)
        close:SetImage("testclose_button")
        close:SetGravity(ui.RIGHT, ui.TOP)
        close:SetEventScript(ui.LBUTTONUP, "Vakarine_equip_frame_close")
    end
    local buff_list_gb = buff_list:CreateOrGetControl("groupbox", "buff_list_gb", 10, 50, 480,
        buff_list:GetHeight() - 60)
    AUTO_CAST(buff_list_gb)
    buff_list_gb:SetSkinName("bg")
    buff_list_gb:RemoveAllChild()
    local cls_list, count = GetClassList("Buff")
    local all_buffs = {}
    for i = 0, count - 1 do
        local buff_cls = GetClassByIndexFromList(cls_list, i)
        if buff_cls then
            if buff_cls.Group1 ~= 'Debuff' and buff_cls.Group1 ~= 'Deuff' then
                local buff_name = dictionary.ReplaceDicIDInCompStr(buff_cls.Name)
                if not ctrl_text or ctrl_text == "" or string.find(buff_name, ctrl_text) then
                    local image_name = GET_BUFF_ICON_NAME(buff_cls)
                    if image_name ~= "icon_None" and buff_name ~= "None" then
                        local is_checked = g.vakarine_equip_settings["buffid"][tostring(buff_cls.ClassID)] == true
                        table.insert(all_buffs, {
                            cls = buff_cls,
                            name = buff_name,
                            image = image_name,
                            is_checked = is_checked
                        })
                    end
                end
            end
        end
    end
    table.sort(all_buffs, function(a, b)
        if a.is_checked and not b.is_checked then
            return true
        elseif not a.is_checked and b.is_checked then
            return false
        else
            return a.cls.ClassID < b.cls.ClassID
        end
    end)
    local y = 0
    for _, buff_data in ipairs(all_buffs) do
        local buff_cls = buff_data.cls
        local buff_id = buff_cls.ClassID
        local buff_slot = buff_list_gb:CreateOrGetControl('slot', 'buffslot' .. buff_id, 10, y + 5, 30, 30)
        AUTO_CAST(buff_slot)
        SET_SLOT_IMG(buff_slot, buff_data.image)
        local icon = CreateIcon(buff_slot)
        AUTO_CAST(icon)
        icon:SetTooltipType('buff')
        icon:SetTooltipArg(buff_data.name, buff_id, 0)
        local buff_check = buff_list_gb:CreateOrGetControl('checkbox', 'buff_check' .. buff_id, 50, y + 10, 200, 30)
        AUTO_CAST(buff_check)
        buff_check:SetText("{ol}" .. buff_id .. " : " .. buff_data.name)
        buff_check:SetTextTooltip(g.lang == "Japanese" and "{ol}チェックすると自動でバフ削除" or
                                      "{ol}Check to automatically remove buff")
        buff_check:SetCheck(buff_data.is_checked and 1 or 0)
        buff_check:SetEventScript(ui.LBUTTONUP, "Vakarine_equip_buff_toggle")
        buff_check:SetEventScriptArgString(ui.LBUTTONUP, buff_id)
        y = y + 35
    end
    buff_list:ShowWindow(1)
    g.esc_register_destroy(addon_name_lower .. "vakarine_equip_buff_list")
end

function Vakarine_equip_buff_list_search(buff_list, ctrl, ctrl_text, num)
    local search_edit = GET_CHILD_RECURSIVELY(buff_list, "search_edit")
    local ctrl_text = search_edit:GetText()
    if ctrl_text ~= "" then
        Vakarine_equip_buff_list(buff_list, ctrl, ctrl_text)
    else
        Vakarine_equip_buff_list(buff_list, ctrl, "")
    end
end

function Vakarine_equip_buff_aoto_remove()
    if g.vakarine_equip_settings.auto_remove == 0 then
        g.vakarine_equip_settings.auto_remove = 1
    else
        g.vakarine_equip_settings.auto_remove = 0
    end
    Vakarine_equip_save_settings()
end

-- **外したときは false ではなく nil にすること。** 読む側は真偽で見ているので
-- false は「無い」と全く同じ意味しか持たない。false を書くと、触ったバフの数だけ
-- 意味のない行が設定ファイルに残り続ける。
function Vakarine_equip_buff_toggle(frame, ctrl, str_buff_id, num)
    local is_check = ctrl:IsChecked()
    if is_check == 1 then
        g.vakarine_equip_settings["buffid"][str_buff_id] = true
    else
        g.vakarine_equip_settings["buffid"][str_buff_id] = nil
    end
    Vakarine_equip_save_settings()
end

function Vakarine_equip_frame_close(frame, ctrl, str, num)
    ui.DestroyFrame(frame:GetName())
end
-- vakarine_equip ここまで

