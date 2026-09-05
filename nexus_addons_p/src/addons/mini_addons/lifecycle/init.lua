function Mini_addons_ON_INIT(addon, frame)
    g.addon = addon
    g.frame = frame
    -- 設定を読む前に保存先を確定させる(AID はここで初めて確実に取れる)
    g.update_paths()
    -- ここから下の内訳を計測する。**この 4 ステップの間に vlog が 1 行も無かったため、
    -- 「6 秒がこの範囲のどこか」までしか絞れなかった**(実機ログ 21:47:26 -> 21:47:32)。
    -- 個々の所要は load_settings / load_buffs 側でも出しているので、ここは
    -- 「どのステップが支配的か」を 1 行で見るための合計。
    local t0 = now_ms()
    g.cid = info.GetCID(session.GetMyHandle())
    g.lang = option.GetCurrentCountry()
    g.load_time = os.clock()
    g.last_inventory_open_time = 0
    local t_session = now_ms()
    if not g.settings then
        Mini_addons_load_settings()
    end
    local t_settings = now_ms()
    if not g.buffs then -- PTバフの準備
        Mini_addons_load_buffs()
    end
    local t_buffs = now_ms()
    g.setup_hook(Mini_addons_CHAT_SYSTEM, "CHAT_SYSTEM")
    -- スキル連打音消す
    g.setup_hook(Mini_addons_ICON_USE, "ICON_USE")
    local t_hooks = now_ms()
    core_g.vlog("mini_addons: 計測 ON_INIT session=%dms settings=%dms buffs=%dms hooks=%dms 合計=%dms",
        t_session - t0, t_settings - t_session, t_buffs - t_settings, t_hooks - t_buffs, t_hooks - t0)
    core_g.register_msg("GAME_START", "Mini_addons_GAME_START")
    core_g.register_msg("GAME_START_3SEC", "Mini_addons_GAME_START_3SEC")
end

function Mini_addons_GAME_START(frame, msg, str, num)
    -- マップ移動直後はフレームがまだ無いので g.get_frame を通す(理由はそちらのコメント)
    local mini_addons = g.get_frame()
    mini_addons:RunUpdateScript("Mini_addons_runupdate_5", 0.5)
    -- AUTOMAPCHANGEに付けていたオートズーム機能を殺す
    if _G["AUTOMAPCHANGE_CAMERA_ZOOM"] and type(_G["AUTOMAPCHANGE_CAMERA_ZOOM"]) == "function" then
        _G["AUTOMAPCHANGE_CAMERA_ZOOM"] = nil
    end
    core_g.register_msg("FPS_UPDATE", "Mini_addons_FPS_UPDATE")
    -- クエストインフォを隠す
    Mini_addons_ON_UPDATE_QUESTINFOSET_2(nil)
    g.setup_hook(Mini_addons_ON_UPDATE_QUESTINFOSET_2, "ON_UPDATE_QUESTINFOSET_2")
    -- ブラックマーケット削除
    g.setup_hook(Mini_addons_NOTICE_ON_MSG, "NOTICE_ON_MSG")
    g.setup_hook(Mini_addons_CHAT_TEXT_LINKCHAR_FONTSET, "CHAT_TEXT_LINKCHAR_FONTSET")
    -- ダイアログ制御系
    core_g.register_msg("DIALOG_CHANGE_SELECT", "Mini_addons_DIALOG_CHANGE_SELECT")
    -- 最初回のイベントバナーのレイヤー下げる
    core_g.register_msg("DO_OPEN_EVENTBANNER_UI", "Mini_addons_event_banner_layer")
    core_g.register_msg("EVENTBANNER_SOLODUNGEON", "Mini_addons_event_banner_layer")
    -- 追加報酬券チェック
    core_g.register_msg("REQ_PLAYER_CONTENTS_RECORD", "Mini_addons_REQ_PLAYER_CONTENTS_RECORD")
    -- お使いクエストフレーム
    core_g.register_msg("QUEST_UPDATE", "Mini_addons_quest_update")
    core_g.register_msg("QUEST_UPDATE_", "Mini_addons_quest_update")
    core_g.register_msg("GET_NEW_QUEST", "Mini_addons_quest_update")
    Mini_addons_quest_update()
    -- クポルポーションフレームの移動と非表示。
    -- cupole 系は別配布のアドオンなので、入れていない利用者では nil になる。
    -- ここで落ちると呼び出し元(補完実行)の残りが走らないため、必ず nil を見る。
    local cupole_external_addon = ui.GetFrame("cupole_external_addon")
    if cupole_external_addon then
        cupole_external_addon:SetEventScript(ui.LBUTTONUP, "Mini_addons_cupole_portion_frame_save")
    else
        core_g.vlog("mini_addons: cupole_external_addon が無いので飛ばす")
    end
end

function Mini_addons_GAME_START_3SEC(frame, msg, str, num)
    core_g.vlog("mini_addons: GAME_START_3SEC 開始")
    -- EP13ショップを街で開ける
    Mini_addons_REPUTATION_SHOP_OPEN()
    -- 町でBGMPLAYERを常に動かす
    Mini_addons_BGM_PLAY()
    -- 小さいボタンをレイドで非表示
    Mini_addons_MINIMIZED_CLOSE()
    -- ボタン右クリックでサウンドオフ
    Mini_addons_toggle_sound_set()
    -- 自分のエフェクト設定を戻すIMCのバグ修正
    Mini_addons_MY_EFFECT_SETTING()
    -- ボスのエフェクト設定を戻すIMCのバグ修正
    Mini_addons_BOSS_EFFECT_SETTING()
    -- その他のエフェクト設定を戻すIMCのバグ修正
    Mini_addons_OTHER_EFFECT_SETTING()
    -- パーティーメンバーの場所表示
    Mini_addons_partymember_get_map()
    -- ヴァカリネを伝える
    Mini_addons_vakarine_notice()
    -- チャンネル切替フレーム
    Mini_addons_GAME_START_CHANNEL_LIST()
    -- イベントグローバルシャウトをチャットに残す
    Mini_addons_event_frame()
    core_g.register_msg("NOTICE_Dm_Global_Shout", "Mini_addons_event_NOTICE_ON_MSG")
    core_g.register_msg("INV_ITEM_ADD", "Mini_addons_event_frame")
    core_g.register_msg("INV_ITEM_REMOVE", "Mini_addons_event_frame")
    -- バウバスお知らせ
    g.setup_hook_and_event(g.addon, "NOTICE_ON_MSG", "Mini_addons_NOTICE_ON_MSG_baubas", true)
    -- どこでもメンバーインフォ
    g.setup_hook(Mini_addons_CHAT_RBTN_POPUP, "CHAT_RBTN_POPUP")
    g.setup_hook(Mini_addons_POPUP_GUILD_MEMBER, "POPUP_GUILD_MEMBER")
    g.setup_hook(Mini_addons_CONTEXT_PARTY, "CONTEXT_PARTY")
    g.setup_hook(Mini_addons_SHOW_PC_CONTEXT_MENU, "SHOW_PC_CONTEXT_MENU")
    -- POPUP_DUMMY(露店キャラ)は素のままでよいので掛けない。以前は素を書き写して
    -- 「見比べる」を memberinfo が ON のときだけ出しており、既定の OFF で消えていた
    g.setup_hook(Mini_addons_POPUP_FRIEND_COMPLETE_CTRLSET, "POPUP_FRIEND_COMPLETE_CTRLSET")
    -- コインショップの数値を拡張
    g.setup_hook(Mini_addons_EARTHTOWERSHOP_CHANGECOUNT_NUM_CHANGE, "EARTHTOWERSHOP_CHANGECOUNT_NUM_CHANGE")
    -- 4人以下の入場確認スキップ
    g.setup_hook(Mini_addons_INDUNENTER_REQ_UNDERSTAFF_ENTER_ALLOW, "INDUNENTER_REQ_UNDERSTAFF_ENTER_ALLOW")
    -- ヴェルニケ階数を覚える
    g.setup_hook(Mini_addons_INDUN_EDITMSGBOX_FRAME_OPEN, "INDUN_EDITMSGBOX_FRAME_OPEN")
    core_g.register_msg("SOLO_D_TIMER_TEXT_GAUGE_UPDATE", "Mini_addons_SOLO_D_TIMER_UPDATE_TEXT_GAUGE")
    -- PTバフの表示非表示切り替え
    g.setup_hook(Mini_addons_ON_PARTYINFO_BUFFLIST_UPDATE, "ON_PARTYINFO_BUFFLIST_UPDATE")
    -- チャンネルのズレを直す
    g.setup_hook(Mini_addons_UPDATE_CURRENT_CHANNEL_TRAFFIC, "UPDATE_CURRENT_CHANNEL_TRAFFIC")
    -- インベントリイコル検索
    g.setup_hook(Mini_addons_INVENTORY_TOTAL_LIST_GET, "INVENTORY_TOTAL_LIST_GET")
    -- コロニー死んだ時に30秒タイマー動かないバグ修正
    g.setup_hook(Mini_addons_RESTART_ON_MSG, "RESTART_ON_MSG")
    -- 決闘の申し込みを自動で受ける(設定 auto_accept_duel。OFF なら元の確認ダイアログのまま)
    g.setup_hook(Mini_addons_ASKED_FRIENDLY_FIGHT, "ASKED_FRIENDLY_FIGHT")
    g.setup_hook(Mini_addons_ASKED_ANCIENT_FRIENDLY_FIGHT, "ASKED_ANCIENT_FRIENDLY_FIGHT")
    -- 特性をスキル順に並べる(設定 ability_sort。OFF と Common タブは素のまま)
    g.setup_hook(Mini_addons_SKILLABILITY_FILL_ABILITY_GB, "SKILLABILITY_FILL_ABILITY_GB")
    -- アイテム破片化の枠を拡張(設定 fragmentation。OFF なら素のまま)
    Mini_addons_frag_setup()
    -- 装備錬成を自動化
    g.setup_hook(Mini_addons_COMMON_EQUIP_UPGRADE_PROGRESS, "COMMON_EQUIP_UPGRADE_PROGRESS")
    g.setup_hook_and_event(g.addon, "COMMON_EQUIP_UPGRADE_OPEN", "Mini_addons_COMMON_EQUIP_UPGRADE_OPEN", true)
    -- パーティー情報フレームを小さくする
    core_g.register_msg("PARTY_BUFFLIST_UPDATE", "Mini_addons_PARTY_BUFFLIST_UPDATE")
    -- インベントリを改造
    core_g.register_msg("INV_ITEM_ADD", "Mini_addons_inventory_open_func")
    core_g.register_msg("INV_ITEM_REMOVE", "Mini_addons_inventory_open_func")
    g.setup_hook_and_event(g.addon, "INVENTORY_OPEN", "Mini_addons_INVENTORY_OPEN", true)
    -- ファミリーネームからログインネームへ変換
    core_g.register_msg("BUFF_ADD", "Mini_addons_PCNAME_REPLACE")
    core_g.register_msg("BUFF_UPDATE", "Mini_addons_PCNAME_REPLACE")
    -- レイドレコードの2度呼ばれるバグ修正
    core_g.register_msg("REQ_PLAYER_CONTENTS_RECORD", "Mini_addons__REQ_PLAYER_CONTENTS_RECORD")
    -- 死んだ時の選択肢を動かす
    core_g.register_msg("RESTART_HERE", "Mini_addons_RESTART_HERE")
    core_g.register_msg("RESTART_CONTENTS_HERE", "Mini_addons_RESTART_HERE")
    -- チャットフレーム改造
    if type(_G["ZCHATEXTENDS_ON_INIT"]) ~= "function" then
        Mini_addons_update_chat_frame()
        g.setup_hook_and_event(g.addon, "INVENTORY_OP_POP", "Mini_addons_INVENTORY_OP_POP", true)
    elseif g.settings.chat_new_btn == 1 then
        g.settings.chat_new_btn = 0
        Mini_addons_save_settings()
    end
    -- ちょい残しボタンcuervoexから移植
    g.setup_hook_and_event(g.addon, "WEEKLYBOSSREWARD_REWARD_OPEN", "Mini_addons_WEEKLYBOSSREWARD_REWARD_OPEN", true)
    -- スキル錬成のスロットにツールチップ
    g.setup_hook_and_event(g.addon, "COMMON_SKILL_ENCHANT_SET_GB", "Mini_addons_COMMON_SKILL_ENCHANT_SET_GB", true)
    -- グループチャット機能
    if g.settings.group_chat == 1 then
        g.setup_hook_and_event(g.addon, "CHAT_GROUPLIST_SELECT_LISTTYPE", "Mini_addons_CHAT_GROUPLIST_SELECT_LISTTYPE_",
            true)
        frame:RunUpdateScript("Mini_addons_CHAT_GROUPLIST_SELECT_LISTTYPE", 1.0)
        g.setup_hook_and_event(g.addon, "CHAT_GROUPLIST_OPTION_OK", "Mini_addons_CHAT_GROUPLIST_OPTION_OK", true)
        g.setup_hook_and_event(g.addon, "CHAT_SET_TO_TITLENAME", "Mini_addons_CHAT_SET_TO_TITLENAME", true)
    end
    -- ボスレランキング
    core_g.register_msg("WEEKLY_BOSS_UI_UPDATE", "Mini_addons_WEEKLYBOSS_PATTERNINFO_UI_UPDATE")
    g.setup_hook_and_event(g.addon, "WEEKLY_BOSS_RANK_UPDATE", "Mini_addons_WEEKLY_BOSS_RANK_UPDATE", true)
    g.setup_hook_and_event(g.addon, "INDUNINFO_UI_CLOSE", "Mini_addons_INDUNINFO_UI_CLOSE", true)
    -- 製造自動セット
    g.setup_hook_and_event(g.addon, "CRAFT_RECIPE_FOCUS", "Mini_addons_CRAFT_RECIPE_FOCUS", true)
    g.setup_hook_and_event(g.addon, "CRAFT_START_CRAFT", "Mini_addons_CRAFT_START_CRAFT", true)
    -- PTメンバーの死亡と復活をNICO_CHATで流す
    g.setup_hook_and_event(g.addon, "DRAW_CHAT_MSG", "Mini_addons_DRAW_CHAT_MSG", true)
    -- ワールドマップにトークンワープのクールダウンを表示
    g.setup_hook_and_event(g.addon, "OPEN_WORLDMAP2_MINIMAP", "Mini_addons_OPEN_WORLDMAP2_MINIMAP", true)
    -- FPS設定を手動入力
    g.setup_hook_and_event(g.addon, "SYS_OPTION_OPEN", "Mini_addons_SYS_OPTION_OPEN", true)
    -- ボスレランキングにメンバーインフォ
    g.setup_hook_and_event(g.addon, "WEEKLY_BOSS_RANK_UPDATE", "Mini_addons_WEEKLY_BOSS_RANK_UPDATE_", true)
    -- ヘアエンチャント関係
    -- 素の「設定」ボタン。**素の処理は乗っ取らない**(bool=true で元の関数をそのまま
    -- 呼び、標準のオプション窓は素の判断で開く)。こちらは開いたのを見て自前の窓を
    -- 畳むだけ。自前の窓を開く役目は「高度な設定」ボタン(下で足す)が持つ
    g.setup_hook_and_event(g.addon, "HIGH_ENCHANT_OPTION_OPEN_BTN", "Mini_addons_HIGH_ENCHANT_OPTION_OPEN_BTN", true)
    --
    -- 付与ウィンドウが開かれる入口。ここで「高度な設定」ボタンを足す
    g.setup_hook_and_event(g.addon, "CLIENT_ENCHANTCHIP", "Mini_addons_CLIENT_ENCHANTCHIP", true)
    -- 素材(ヘアアクセ)がスロットへ乗った所。自動で開く設定はここで効かせる
    -- (窓を組むにはアイテムとスクロールの両方が要るので、付与ウィンドウを開いた
    --  時点ではまだ組めない)
    g.setup_hook_and_event(g.addon, "HIGH_HAIRENCHANT_DRAW_HIRE_ITEM", "Mini_addons_HIGH_HAIRENCHANT_DRAW_HIRE_ITEM",
        true)
    g.setup_hook_and_event(g.addon, "HIGH_HAIRENCHANT_CLOSE_BTN", "Mini_addons_HIGH_HAIRENCHANT_CLOSE_BTN", true)
    g.setup_hook_and_event(g.addon, "HIGH_HAIRENCHANT_OK_BTN", "Mini_addons_HIGH_HAIRENCHANT_OK_BTN", false)
    -- 付与ボタンの押下。回している最中は「停止」として受ける(素は呼ばない)ので bool=false
    g.setup_hook_and_event(g.addon, "HIGH_HAIRENCHANT_SEND_BTN", "Mini_addons_HIGH_HAIRENCHANT_SEND_BTN", false)
    -- 連続付与を「時間が来たら撃つ」から「結果が返ったら撃つ」へ切り替えるための合図。
    -- 素は結果を受けると HIGH_HAIRENCHANT_UIEFFECT で HoldUI を掛け、EFFECT_DURATION(0.5秒)後に
    -- この関数を ReserveScript して解除する。**演出の終わり**を合図にするので素と重ならない
    g.setup_hook_and_event(g.addon, "_HIGH_HAIRENCHANT_SUCCESS", "Mini_addons__HIGH_HAIRENCHANT_SUCCESS", true)
    -- 「演出を待たずに実行」を ON にしたときだけ使う、ひとつ手前の合図。
    -- アイテムの実データが更新される SUCEECD 側を使う(SUCEECD_RESULT ではない。理由は実装側)
    g.setup_hook_and_event(g.addon, "HIGH_HAIRENCHANT_SUCEECD", "Mini_addons_HIGH_HAIRENCHANT_SUCEECD", true)
    -- スキル錬成(common_skill_enchant)を希望スキルが出るまで回す
    -- 素の窓が開かれる入口。ここで「高度な設定」ボタンを足す
    g.setup_hook_and_event(g.addon, "COMMON_SKILL_ENCHANT_OPEN", "Mini_addons_COMMON_SKILL_ENCHANT_OPEN", true)
    -- アイテムがスロットへ乗った所。自動で開く設定はここで効かせる
    g.setup_hook_and_event(g.addon, "COMMON_SKILL_ENCHANT_SET_TARGET_ITEM",
        "Mini_addons_COMMON_SKILL_ENCHANT_SET_TARGET_ITEM", true)
    -- 素が結果のたびに呼ぶ画面のリセット。回している間は錬成ボタンを押せる状態へ戻す
    -- (素はここで do_enchant:SetEnable(0) を掛ける)
    g.setup_hook_and_event(g.addon, "REFRESH_COMMON_SKILL_ENCHANT", "Mini_addons_REFRESH_COMMON_SKILL_ENCHANT", true)
    -- 素の窓が閉じたら自前の窓も畳む
    g.setup_hook_and_event(g.addon, "COMMON_SKILL_ENCHANT_CLOSE", "Mini_addons_COMMON_SKILL_ENCHANT_CLOSE", true)
    -- 錬成ボタンの押下。回している最中は「停止」として受けるので素は呼ばない。
    -- **ここだけ置換方式(g.setup_hook)にすること。** イベント方式の bool=false だと、
    -- 機能を OFF にしたとき Mini_addons_teardown が購読だけ外してラッパを _G に残すため、
    -- 素の「スキル錬成」ボタンが誰も呼ばない no-op になる(置換方式は g.hook_installed から
    -- 元の関数へ戻す)
    g.setup_hook(Mini_addons_COMMON_SKILL_ENCHANT_DO, "COMMON_SKILL_ENCHANT_DO")
    -- 結果の合図。**素の演出(0.8 秒)の終わりを待つ**ので、次を撃つ合図は END の方で立てる
    -- (SUCCESS 側は「維持」= 演出を出さずに返る経路だけを拾う。理由は run.lua)
    g.setup_hook_and_event(g.addon, "SUCCESS_COMMON_SKILL_ENCHANT", "Mini_addons_skill_reroll_SUCCESS", true)
    g.setup_hook_and_event(g.addon, "COMMON_SKILL_ENCHANT_END", "Mini_addons_skill_reroll_END", true)
    g.setup_hook_and_event(g.addon, "FAILED_COMMON_SKILL_ENCHANT", "Mini_addons_skill_reroll_FAILED", true)
    -- チャットフレーム移動のワイドモニター制限解除
    g.setup_hook_and_event(g.addon, "_PROCESS_MOVE_MAIN_POPUPCHAT_FRAME",
        "Mini_addons__PROCESS_MOVE_MAIN_POPUPCHAT_FRAME", false)
    -- マーケット販売時に持ってる最大値を自動入力
    g.setup_hook_and_event(g.addon, "MARKET_SELL_UPDATE_REG_SLOT_ITEM", "Mini_addons_MARKET_SELL_UPDATE_REG_SLOT_ITEM",
        true)
    -- レイドレコードのサイズ、位置変更
    g.setup_hook_and_event(g.addon, "RAID_RECORD_INIT", "Mini_addons_RAID_RECORD_INIT", true)
    -- エンブレム、アークの着け忘れお知らせ
    g.setup_hook_and_event(g.addon, "SHOW_INDUNENTER_DIALOG", "Mini_addons_SHOW_INDUNENTER_DIALOG", true)
    -- 自動マッチのレイヤーを下げる
    g.setup_hook_and_event(g.addon, "INDUNENTER_AUTOMATCH_TYPE", "Mini_addons_INDUNENTER_AUTOMATCH_TYPE", true)
    -- 死んだ時のマウス位置制御
    g.setup_hook_and_event(g.addon, "RESTART_CONTENTS_ON_HERE", "Mini_addons_RESTART_CONTENTS_ON_HERE", true)
    -- オートキャスティングをキャラ毎に設定
    g.setup_hook_and_event(g.addon, "CONFIG_ENABLE_AUTO_CASTING", "Mini_addons_CONFIG_ENABLE_AUTO_CASTING", true)
    Mini_addons_SET_ENABLE_AUTO_CASTING()
    -- ペットコマンド制御
    g.setup_hook_and_event(g.addon, "SHOW_PET_RINGCOMMAND", "Mini_addons_SHOW_PET_RINGCOMMAND", false)
    -- レリックゲージ
    local map_name = session.GetMapName()
    local colony_cls_list, cnt = GetClassList("guild_colony")
    for i = 0, cnt - 1 do
        local colonyCls = GetClassByIndexFromList(colony_cls_list, i)
        local check_word = "GuildColony_"
        if not string.find(map_name, check_word) then
            Mini_addons_CHARBASE_RELIC()
            core_g.register_msg("RP_UPDATE", "Mini_addons_CHARBASE_RELIC")
        end
    end
    if g.get_map_type() == "City" then
        -- ヴェルニケ自動受取り
        Mini_addons_SOLODUNGEON_RANKINGPAGE_GET_REWARD()
        -- ボスレ報酬自動受取り
        Mini_addons_WEEKLY_BOSS_REWARD()
        -- 街のラガナを非表示
        Mini_addons_ragana_remove_timer()
        -- RPチャージを補完
        Mini_addons_rp_check()
        -- 町でマーケットボタンを常に表示
        Mini_addons_MINIMIZED_TOTAL_SHOP_BUTTON_CLICK()
        -- 傭兵団コイン、女神コイン、王国再建団コインを取得時、自動で使用
        Mini_addons_INV_ICON_USE()
        -- 錬成時に自動でアイテムセット
        g.setup_hook_and_event(g.addon, "COMMON_SKILL_ENCHANT_MAT_SET", "Mini_addons_COMMON_SKILL_ENCHANT_MAT_SET", true)
        g.setup_hook_and_event(g.addon, "SUCCESS_COMMON_SKILL_ENCHANT", "Mini_addons_SUCCESS_COMMON_SKILL_ENCHANT", true)
        -- 自動女神ガチャ
        Mini_addons_GP_FULL_BET()
        core_g.register_msg("FIELD_BOSS_WORLD_EVENT_START", "Mini_addons_GP_DO_OPEN")
        core_g.register_msg("FIELD_BOSS_WORLD_EVENT_END", "Mini_addons_FIELD_BOSS_WORLD_EVENT_END")
        -- オプションリロールの表を横に表示
        core_g.register_msg("OPEN_DLG_REROLL_ITEM", "Mini_addons_OPEN_DLG_REROLL_ITEM")
    end
    -- 細かい修正
    Mini_addons_minor_fixes()
    core_g.vlog("mini_addons: GAME_START_3SEC 完了")
    -- 個別版はここで sysmenu:RunUpdateScript("Mini_addons_make_menu", 2.0) を仕込み、
    -- アドオンメニューのボタンに自分の項目(アイコン)を並べていた。同梱版では
    -- **Nexus Addons P のアドオン一覧から開ければ十分**なので、登録しないことにした。
    -- 一覧側の入口は core/10_registry.lua の config_func = "Mini_addons_SETTING_FRAME_INIT"。
    --
    -- Mini_addons_make_menu 自体は残してあるが、どこからも呼ばれない。
    -- 中で norisan_menu_frame を作る処理も持っており、これは core/90_addons_menu.lua と
    -- 二重になるため、復活させるなら登録部分だけを呼ぶこと。
end
