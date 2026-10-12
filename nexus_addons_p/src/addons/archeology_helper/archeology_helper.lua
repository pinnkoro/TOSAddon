-- archeology_helper ここから
-- 2026-10 のアーキオロジー刷新(パッチ 407247)で、素の作りが次のように変わった。
-- * 調べた結果は ARCHE_SEARCH_RESULT メッセージで「調べた座標・距離・輪の大きさ・対象の地点」が届き、
--   素の全体マップが直近 3 回ぶんの輪を描く(addon.ipf/map/map.lua の ON_ARCHE_SEARCH_RESULT)。
--   距離のチャット文言は 7 段階に増え、日本語辞書で拾っていた旧 ID は使われなくなった
--   (ETC_20220210_065695 / 065696 / 065693 が IsUse="0")ので、チャットではなくこのメッセージを拾う。
-- * Lv530 以上の依頼は対象マップが 1 つ・地点が 4 つ(shared_archeology.get_active_map_count /
--   get_point_count)。試行回数はアカウントの archeology_try_count に入り、上限は 70 回 + オプション。
-- * 依頼の受諾に要るのは遺物探査許可証(Archeology_Dig_Permit)。
-- 素の数値は shared_archeology から引き、無ければ旧仕様の値へ倒す。
g.aoh = {
    permit_item = "Archeology_Dig_Permit",
    -- 依頼の NPC(アイリーネ)はクラペダにしか居ない。トークンワープは次の対象マップへ飛ぶのに
    -- 取っておきたいので、クラペダへ戻るときはクエストワープかワープスクロールを使う。
    home_map = "c_Klaipe",
    home_item = 640073, -- Scroll_Warp_Klaipe(クラペダ ワープスクロール)
    -- クラペダに着いたら依頼の NPC の前へ移動する。素の Indun Panel の「レティーシャへ移動」と同じ
    -- FullScreenMenuMoveNpc を使う。ダイアログ名は gentype_c_Klaipe.ies の
    -- 「[마지막 제단] 고고학자 아이리네」(パッチ 407247 で確認)。
    -- 依頼のウィンドウ(archeology_mission)は NPC と話したときにサーバーが候補マップ付きで
    -- 開くもので、こちらからは開けない。話しかけるのは利用者に任せる。
    home_npc_dialog = "KLAPEDA_AIRINE",
    -- 「クラペダへ」を押してから何秒以内にクラペダへ着いたら NPC へ移動するか。
    -- クエストワープの確認を断ったまま、後で別の手段でクラペダへ入ったときに勝手に動かないようにする。
    home_npc_wait = 60,
    -- クエストワープに使えるクエスト(Lets Go Home と同じ判定)。state は GET_QUEST_NPC_STATE の値で、
    -- Start = 受注可能(開始 NPC へ飛ぶ)、End = 完了可能(完了 NPC へ飛ぶ)。どちらの NPC もクラペダに居る。
    home_quests = {{
        quest_id = 91055, -- TOSHERO_TUTO_01
        result = "POSSIBLE",
        state = "Start"
    }, {
        quest_id = 72165, -- MASTER_QUARRELSHOOTER1
        result = "SUCCESS",
        state = "End"
    }},
    -- 距離の段階(shared_archeology.get_survey_distance_message_key の戻り値)ごとの色
    dist_colors = {
        ArcheologyRelicTooFarAway = "FFFF0000",
        ArcheologyRelicVeryFarAway = "FFFF6A00",
        ArcheologyRelicFarAway = "FFFFA500",
        ArcheologyRelicSlightlyFarAway = "FFFFD700",
        ArcheologyRelicNear = "FFFFFF00",
        ArcheologyRelicVeryClose = "FF00FFFF",
        ArcheologyRelicImmediate = "FFFFFFFF"
    },
    default_color = "FFFFA500",
    -- 遺物を飾る展示のスロット(3 つ)の番号と色。遺物の種類(archeology_base_list.ies の ExhibitSlotType)で決まる。
    -- 素の archeology_exhibition.lua の ARCEX_SLOT_INFO_BY_TYPE と同じ並びだが、向こうは local で引けないので持つ。
    -- 1 = 聖物と祭礼 / 2 = 生活と技術 / 3 = 戦争と災難(パッチ 407247)
    exhibit_slots = {
        ForgottenGoddess = {
            index = 1,
            color = "9fd8ff"
        },
        NamelessAncestor = {
            index = 2,
            color = "d8bd62"
        },
        Unreturned = {
            index = 3,
            color = "ff9b57"
        }
    },
    marker_ver = 2,
    -- 設定の窓のチェック(上から順に並ぶ)。key = 設定のキー = チェックの名前
    setting_checks = {{
        key = "home_item",
        jp = "クエストワープが使えないときはクラペダ ワープスクロールを使う",
        en = "Use a Klaipeda warp scroll when no quest warp is available"
    }, {
        key = "home_npc",
        jp = "クラペダに着いたら依頼の NPC(アイリーネ)の前へ移動する",
        en = "Move to the mission NPC (Airine) after arriving in Klaipeda"
    }, {
        key = "end_ask",
        jp = "全地点を掘り終えたらクラペダへ戻るか聞く",
        en = "Ask to return to Klaipeda when all points are dug"
    }, {
        key = "accept_warp",
        jp = "依頼を受けたら対象マップへトークンワープする",
        en = "Token warp to the target map after accepting a mission"
    }, {
        key = "relic_slot",
        jp = "インベントリの遺物に展示スロットの番号を出す",
        en = "Show the exhibition slot number on relics in the inventory"
    }, {
        key = "relic_sort",
        jp = "インベントリの遺物を レア度 → 効果 → 数値 の順に並べる",
        en = "Sort relics in the inventory by rarity, effect, then value"
    }, {
        key = "relic_new",
        jp = "新しく入った遺物に NEW の印(N)を付ける(次の依頼を受けると消える)",
        en = "Mark newly obtained relics as new (N) until the next mission"
    }, {
        key = "relic_section",
        jp = "インベントリの遺物を展示スロット(1 / 2 / 3)ごとのセクションに分ける",
        en = "Split relics in the inventory into sections by exhibition slot (1 / 2 / 3)"
    }, {
        key = "exhibit_focus",
        jp = "最後の祭壇・探査ポータルの入場画面を開いたら、インベントリをアーキオロジーだけにする",
        en = "Show only Archeology in the inventory while the altar or portal entry window is open"
    }, {
        key = "denter_last",
        jp = "探査ポータルの入場画面を「最近の設定」で開く",
        en = "Open the portal entry window with the last settings"
    }, {
        key = "mob_display",
        jp = "地図に敵を表示する",
        en = "Show monsters on the map"
    }},
    -- 設定の窓のチェックを切り替えた後の処理(Archeology_helper_setting_check)
    setting_after = {
        relic_slot = "refresh",
        relic_sort = "refresh",
        relic_section = "refresh",
        relic_new = "redraw"
    },
    -- インベントリの遺物の並べ替え。等級は ClassName の末尾(_N / _M / _R)で決まる。
    relic_rarity_rank = {
        _R = 3,
        _M = 2,
        _N = 1
    },
    -- 効果の並び。素の展示画面の効果一覧と同じく「大分類 → 効果ごとの重み → 効果のキー」の順。
    -- 大分類の重み(ARCEX_EFFECT_CATEGORY_INFO)と効果の重み(GET_EFFECT_SORT_WEIGHT)は
    -- 素の archeology_exhibition.lua の local なので、ここに写す(パッチ 407247)。
    relic_category_weight = {
        Arch = 10,
        Combat = 20,
        Special = 30
    },
    relic_effect_weight = {
        ARCHEOLOGY_RARE_CHANCE = 10,
        ARCHEOLOGY_DETECTING = 20,
        ARCHEOLOGY_COIN_GAIN = 30,
        ARCHEOLOGY_SPECIAL_REWARD = 40,
        ARCHEOLOGY_MON_FIND = 50,
        ARCHEOLOGY_DOUBLE_DROP = 60,
        ARCHEOLOGY_MON_DROP_RATE = 70,
        ARCHEOLOGY_HP_BONUS = 100,
        ARCHEOLOGY_DEF_BONUS = 110,
        ARCHEOLOGY_MDEF_BONUS = 120,
        ARCHEOLOGY_DODGE = 130,
        ARCHEOLOGY_CRIT_RES = 140,
        ARCHEOLOGY_BLOCK_PEN = 150,
        ARCHEOLOGY_HP_ON_KILL = 160,
        ARCHEOLOGY_MOVE_SPEED = 165,
        ARCHEOLOGY_PORTAL_MOVE_SPEED = 166,
        ARCHEOLOGY_DMG_REDUCE = 210
    }
}

-- Archeology Helper が ON か。**掛けたフックとメッセージはセッション中ずっと残る**(OFF にしても
-- 外れない)ので、フックとメッセージの受け口は最初にこれを見て、OFF なら素の動きだけにする
function Archeology_helper_active()
    return g.settings ~= nil and g.settings.archeology_helper ~= nil and g.settings.archeology_helper.use == 1 and
               g.aoh_settings ~= nil
end

function Archeology_helper_save_settings()
    g.save_json(g.aoh_settings_path, g.aoh_settings)
end

function Archeology_helper_load_settings()
    g.aoh_settings_path = string.format("../addons/%s/%s/archeology_helper.json", addon_name_lower, g.active_id)
    local settings = g.load_json(g.aoh_settings_path)
    if not settings then
        settings = {
            count = 0,
            is_archeology = false,
            map_info = {},
            x = 670,
            y = 70
        }
    end
    -- 旧版のマーカーは 198x200 の絵の上の画素座標で持っていた。今はワールド座標で持つので、
    -- 旧形式は描けない。刷新前の依頼の記録でもあるので捨てる。
    if (settings.marker_ver or 1) < g.aoh.marker_ver then
        settings.map_info = {}
        settings.count = 0
        settings.marker_ver = g.aoh.marker_ver
    end
    settings.map_info = settings.map_info or {}
    -- 旧版(end_ver 無し)は「地点に触れた回数」で依頼の終わりを決めていて、途中で聞いてしまうことがあった。
    -- そのとき立てた「聞いた」印(end_asked)が残ると今の依頼の本当の終わりで聞かなくなるので、一度だけ下ろす
    -- 以前はセクションの畳んだ状態をキャラごとに保存していた。今はセッションの間だけなので、一度だけ消す
    if settings.section_ver ~= 1 then
        for _, char in pairs(settings) do
            if type(char) == "table" then
                char.section_folded = nil
            end
        end
        settings.section_ver = 1
    end
    if settings.end_ver ~= 2 then
        settings.end_pending = nil
        settings.end_asked = nil
        settings.end_result = nil
        settings.end_ver = 2
    end
    g.aoh_settings = settings
    Archeology_helper_save_settings()
end

function archeology_helper_on_init()
    if not g.aoh_settings then
        Archeology_helper_load_settings()
    end
    if not g.aoh_settings[g.cid] then
        g.aoh_settings[g.cid] = {
            sta_check = 0
        }
        Archeology_helper_save_settings()
    end
    local old_func = g.settings.archeology_helper.old_init_func
    if _G[old_func] then
        return
    end
    if g.settings.archeology_helper.use == 0 then
        ui.DestroyFrame(addon_name_lower .. "au_map")
        -- ON の間にインベントリを並べ替え・セクション分けしていたら、素の並びへ組み立て直す
        -- (フックは OFF を見て素の動きだけになるので、組み立て直せば元に戻る)
        if g.aoh_inventory_touched then
            g.aoh_inventory_touched = nil
            local inventory = ui.GetFrame("inventory")
            if inventory then
                INVENTORY_TOTAL_LIST_GET(inventory)
            end
        end
        return
    end
    Archeology_helper_start()
    g.setup_hook_and_event(g.addon, "TARGETSPACE_PRECHECK", "Archeology_helper_TARGETSPACE_PRECHECK", true)
    g.setup_hook(Archeology_helper_INV_ICON_SETINFO, "INV_ICON_SETINFO")
    -- インベントリはログイン時(この初期化より前)に組み立てられ、開くだけでは描き直されないので、
    -- 掛けた後に一度描き直して番号を出す
    -- 2 回目以降のマップの読み込みでは、フックが掛かったまま素が組み立てるので要らない
    if not g.aoh_relic_refreshed_once then
        g.aoh_relic_refreshed_once = true
        ReserveScript("Archeology_helper_relic_refresh()", 1.0)
    end
    -- 遺物の並べ替え。インベントリの組み立て直しは INSERT_ITEM_TO_TREE(下)で見分け、アイテムの増減は
    -- メッセージで受けて並べ直す。INVENTORY_TOTAL_LIST_GET には掛けない(Mini Addons が置換方式で掛けていて、
    -- 掛ける順番しだいでこちらの受け口が外れ、マップを移った後に並べ直されなかった)
    g.register_msg("INV_ITEM_ADD", "Archeology_helper_relic_item_msg")
    g.register_msg("INV_ITEM_REMOVE", "Archeology_helper_relic_item_msg")
    -- 1 個ずつの更新(プロパティ・個数・ロック)。素は元の「遺物」の区切りしか探さないので、
    -- セクション 2 / 3 / その他へ移した遺物はこちらで描き直す
    g.register_msg("ITEM_PROP_UPDATE", "Archeology_helper_relic_item_update")
    g.register_msg("INV_ITEM_CHANGE_COUNT", "Archeology_helper_relic_item_update")
    g.register_msg("UPDATE_LOCK_STATE", "Archeology_helper_relic_item_update")
    -- 鑑定した遺物の NEW の印(鑑定の結果は素の archeology_identify と同じメッセージで受ける)
    g.register_msg("ARCHEOLOGY_IDENTIFY_FINISHED", "Archeology_helper_IDENTIFY_FINISHED")
    g.register_msg("SUCCESS_ARCH_IDENTIFY", "Archeology_helper_IDENTIFY_SUCCESS")
    g.register_msg("INV_ITEM_REMOVE", "Archeology_helper_relic_new_remove")
    -- 祭壇ランク上昇の投入数を、使える最大数で始める
    g.setup_hook(Archeology_helper_EXCUTE_EXHIBITION_RANKUP, "EXCUTE_EXHIBITION_RANKUP")
    g.setup_hook(Archeology_helper_INSERT_ITEM_TO_TREE, "INSERT_ITEM_TO_TREE")
    -- 遺物のツールチップの効果が長いと 1 行に収まらず切れるので折り返す
    g.setup_hook(Archeology_helper_DRAW_ARCHEOLOGY_OPTIONS_TOOLTIP, "DRAW_ARCHEOLOGY_OPTIONS_TOOLTIP")
    -- 探査ポータル(インスタンスダンジョン)の入場画面を、最近の設定で開く
    g.setup_hook(Archeology_helper_ARCH_DENTER_ON_OPEN, "ARCH_DENTER_ON_OPEN")
    -- 探査ポータルの入場画面を閉じたら、インベントリを元に戻す(閉じ方はどれもここを通る)
    g.setup_hook(Archeology_helper_ARCH_DENTER_CLOSE_UI, "ARCH_DENTER_CLOSE_UI")
    -- 遺物分解の「所持 / 獲得予定 / 分解後」が「%s %s個」のまま出るのを直す
    g.setup_hook(Archeology_helper_ARCH_DECOMP_REWARD_SUMMARY, "ARCH_DECOMP_REWARD_SUMMARY")
    -- 最後の祭壇(展示画面)を開いている間は、インベントリをアーキオロジーだけにする
    g.setup_hook(Archeology_helper_ARCHEOLOGY_EXHIBITION_OPEN, "ARCHEOLOGY_EXHIBITION_OPEN")
    g.setup_hook(Archeology_helper_ARCHEOLOGY_EXHIBITION_CLOSE, "ARCHEOLOGY_EXHIBITION_CLOSE")
    Archeology_helper_arrive_home()
    Archeology_helper_try_ask_end("map")
end

function Archeology_helper_start()
    if g.get_map_type() == "City" and g.aoh_settings[g.cid].sta_check == 1 then
        local inv_item = session.GetInvItemByType(640009)
        if inv_item then
            if inv_item.count <= 10 then
                local msg = g.lang == "Japanese" and "スタミナ錠が残り少ないです" or
                                "Stamina pills are running low"
                imcAddOn.BroadMsg("NOTICE_Dm_!", msg, 10)
            end
        end
    end
    g.register_msg("MAP_CHARACTER_UPDATE", "Archeology_helper_MAP_CHARACTER_UPDATE")
    -- 依頼の開始は受諾の結果で拾う。_ARCHEOLOGY_MISSION_EXECUTE は「対象マップを変えますか」の
    -- 確認を出すだけで戻る経路ができたので、そこで記録を消すと取り消したときにも消えてしまう。
    g.register_msg("ARCHEOLOGY_MISSION_ACCEPT_RESULT", "Archeology_helper_MISSION_ACCEPT_RESULT")
    g.register_msg("ARCHE_SEARCH_RESULT", "Archeology_helper_ARCHE_SEARCH_RESULT")
    g.register_msg("ARCHE_SEARCH_RESET", "Archeology_helper_ARCHE_SEARCH_RESET")
    -- 地点を見つけると開くポータルのインスタンスダンジョンの結果と、その表示が閉じたとき
    -- (addon.ipf/archeology_portal_tracker の ON_ARCHEOLOGY_PORTAL_TRACKER_RESULT / _CLOSE と同じメッセージ)
    g.register_msg("ARCHEOLOGY_PORTAL_TRACKER_RESULT", "Archeology_helper_PORTAL_RESULT")
    g.register_msg("ARCHEOLOGY_PORTAL_TRACKER_CLOSE", "Archeology_helper_PORTAL_CLOSE")
    -- 敵の位置。素のミニマップ・全体マップと同じメッセージ(addon.ipf/map/map_monpos.lua の MAP_MON_MINIMAP)
    g.register_msg("MON_MINIMAP", "Archeology_helper_MON_MINIMAP")
    g.register_msg("MON_MINIMAP_END", "Archeology_helper_MON_MINIMAP_END")
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    _nexus_addons_p:RunUpdateScript("Archeology_helper_stamina_update", 2.0)
    Archeology_helper_frame_init()
end

function Archeology_helper_stamina_update(_nexus_addons_p)
    local my_handle = session.GetMyHandle()
    if g.aoh_settings[g.cid].sta_check == 1 then
        local sta_item = 640009
        local stat = info.GetStat(my_handle)
        local sta_num = math.floor(stat.Stamina / 1000)
        if sta_num <= 1 then
            local now = imcTime.GetAppTime()
            if not g.ah_last_sta_time or (now - g.ah_last_sta_time >= 10.0) then
                local inv_item = session.GetInvItemByType(sta_item)
                if inv_item then
                    INV_ICON_USE(inv_item)
                    g.ah_last_sta_time = now
                end
            end
        end
    end
    return 1
end

-- 今の依頼の対象マップ。{ index, name, complete } の並び。
function Archeology_helper_active_maps()
    local list = {}
    local acc_obj = GetMyAccountObj()
    if not acc_obj then
        return list
    end
    local count = max_archeology_map_count or 3
    if shared_archeology and shared_archeology.get_active_map_count then
        count = shared_archeology.get_active_map_count(acc_obj)
    end
    for i = 1, count do
        local map_name = TryGetProp(acc_obj, "archeology_map_" .. i, "None")
        if map_name ~= "None" and GetClass("Map", map_name) then
            list[#list + 1] = {
                index = i,
                name = map_name,
                complete = tonumber(TryGetProp(acc_obj, "archeology_map_" .. i .. "_complete", 0)) == 1
            }
        end
    end
    return list
end

-- 1 マップあたりの発掘地点の数(Lv530 以上は 4、旧 Lv470 の依頼は 3)
function Archeology_helper_point_count()
    local acc_obj = GetMyAccountObj()
    if acc_obj and shared_archeology and shared_archeology.get_point_count then
        return shared_archeology.get_point_count(acc_obj)
    end
    return max_archeology_point or 3
end

-- 試行回数と上限。上限は素の世界地図と同じく、基本値 + 探査回数のオプション。
function Archeology_helper_try_info()
    local acc_obj = GetMyAccountObj()
    local tries = acc_obj and tonumber(TryGetProp(acc_obj, "archeology_try_count", 0)) or 0
    local max_tries = 50
    if shared_archeology and shared_archeology.get_max_archeology_try_count then
        max_tries = shared_archeology.get_max_archeology_try_count()
        -- 展示のオプションを集計する重めの処理なので、転んでも基本値で表示を続ける
        if GET_CURRENT_APPLY_EFFECT_LIST then
            local ok, options = pcall(function()
                return GET_CURRENT_APPLY_EFFECT_LIST()
            end)
            if ok and type(options) == "table" then
                max_tries = max_tries + math.max(0, math.floor(tonumber(options.ARCHEOLOGY_SURVEY_ATTEMPT) or 0))
            end
        end
    end
    return tries, max_tries
end

function Archeology_helper_is_map_done(map)
    local info = g.aoh_settings.map_info[map.name]
    return map.complete or (info and (info.get_count or 0) >= Archeology_helper_point_count())
end

function Archeology_helper_in_progress()
    local maps = Archeology_helper_active_maps()
    if #maps == 0 then
        return false
    end
    local tries, max_tries = Archeology_helper_try_info()
    if tries >= max_tries then
        return false
    end
    for _, map in ipairs(maps) do
        if not Archeology_helper_is_map_done(map) then
            return true
        end
    end
    return false
end

function Archeology_helper_dist_color(dist)
    if not dist or not (shared_archeology and shared_archeology.get_survey_distance_message_key) then
        return g.aoh.default_color
    end
    local key = shared_archeology.get_survey_distance_message_key(dist)
    return g.aoh.dist_colors[key] or g.aoh.default_color
end

-- argStr は「x,y,z,距離,?,輪の大きさ,対象の地点」(素の ON_ARCHE_SEARCH_RESULT が読む並び)。
-- 空の欄で添字がずれないよう、gmatch で "[^,]+" を使わずに区切る。
function Archeology_helper_ARCHE_SEARCH_RESULT(frame, msg, arg_str, arg_num)
    if not g.aoh_settings then
        return
    end
    local fields = {}
    for field in string.gmatch((arg_str or "") .. ",", "([^,]*),") do
        fields[#fields + 1] = field
    end
    g.vlog("archeology_helper: ARCHE_SEARCH_RESULT arg_str=%s arg_num=%s", tostring(arg_str), tostring(arg_num))
    local wx, wz = tonumber(fields[1]), tonumber(fields[3])
    local dist = tonumber(fields[4])
    local draw = tonumber(fields[6]) or dist
    local target_key = fields[7] or "None"
    if target_key == "" then
        target_key = "None"
    end
    if not wx or not wz or not draw then
        g.vlog("{#FF6347}archeology_helper: 座標か距離が読めないので記録しない{/}")
        return
    end
    local map_name = session.GetMapName()
    local map_info = g.aoh_settings.map_info[map_name]
    if not map_info then
        map_info = {
            get_count = 0
        }
        g.aoh_settings.map_info[map_name] = map_info
    end
    map_info.markers = map_info.markers or {}
    -- 対象の地点が変わった = 前の地点は掘り終えた。前の地点を探した印は邪魔になるので消す。
    if map_info.target_key and map_info.target_key ~= "None" and target_key ~= "None" and map_info.target_key ~=
        target_key then
        g.vlog("archeology_helper: 対象の地点が変わった %s -> %s。%s の印 %d 個を消す", map_info.target_key,
            target_key, map_name, #map_info.markers)
        map_info.markers = {}
    end
    map_info.target_key = target_key
    -- 対象の地点は "archeology_map_1_pos_4:<時刻>" の形で届く。4 番目を探している = 3 つは掘り終えた。
    -- 地点に触れたことの検出(TARGETSPACE_PRECHECK)を取りこぼしても、ここで追い付く。
    local pos_index = tonumber(string.match(target_key, "_pos_(%d+)"))
    if pos_index and pos_index - 1 > (map_info.get_count or 0) then
        g.vlog("archeology_helper: %s の発掘数を対象の地点から補正 %d -> %d", map_name, map_info.get_count or 0,
            pos_index - 1)
        map_info.get_count = pos_index - 1
    end
    g.aoh_settings.count = (g.aoh_settings.count or 0) + 1
    local color = Archeology_helper_dist_color(dist or draw)
    table.insert(map_info.markers, {
        wx = wx,
        wz = wz,
        draw = draw,
        color = color,
        count = g.aoh_settings.count
    })
    g.aoh_settings.is_archeology = true
    g.vlog("archeology_helper: %s に印 #%d (x=%s z=%s 距離=%s 輪=%s 色=%s)", map_name, g.aoh_settings.count,
        tostring(wx), tostring(wz), tostring(dist), tostring(draw), color)
    Archeology_helper_save_settings()
    Archeology_helper_frame_init()
end

-- 依頼を終えた後、次の依頼を受けにクラペダへ戻るか聞く。試行回数(n/70)の上限では聞かない。
-- **地点を見つけた時点では聞かない。** 地点に触れるとポータルのダンジョンが始まり、依頼が終わるのはそれを終えたとき。
-- 依頼が終わったかは**ゲームの記録(アカウントの archeology_map_<n>_complete)**で見る。素の全体マップも
-- これを見ている。地点に触れた回数を数える方法は、1 つの地点で TARGETSPACE_PRECHECK が何度も来るので
-- 早く 4 に届いてしまい、途中のダンジョンの後で聞いてしまった(2026-10-12 の実機)。流れは次の 3 段:
--   1. ダンジョンの結果が届いた(ARCHEOLOGY_PORTAL_TRACKER_RESULT) → end_result にそのマップ名を控える
--   2. フィールドへ戻った(マップの読み込み)か、フィールド(レイヤー 0)で結果の表示が閉じた
--   3. 全ての対象マップが完了になっていれば聞く。なっていなければ(途中のダンジョン)控えを消して聞かない
-- 2 でフィールドかを見るのは、ダンジョンの中でクラペダへ戻ろうとしても飛べないため。
function Archeology_helper_PORTAL_RESULT(frame, msg, arg_str, arg_num)
    if not Archeology_helper_active() then
        return
    end
    g.vlog("archeology_helper: ARCHEOLOGY_PORTAL_TRACKER_RESULT arg_str=%s map=%s layer=%d end_asked=%s",
        tostring(arg_str), session.GetMapName(), world.GetLayer(), tostring(g.aoh_settings.end_asked))
    -- この依頼で既に聞いた後(次の依頼を受ける前にポータルをもう一度回したなど)は、完了の処理をやり直さない
    if g.aoh_settings.end_asked then
        return
    end
    Archeology_helper_end_wait_start()
    g.aoh_settings.end_result = session.GetMapName()
    Archeology_helper_save_settings()
end

-- 依頼の終わりの見直しを始める(控えを立てた時点)。完了の記録の遅れは時間で待ち、レイヤーは回数で待つ
function Archeology_helper_end_wait_start()
    g.aoh_end_deadline = imcTime.GetAppTime() + 4.0
    g.aoh_layer_wait = 0
end

-- 見直しの予約は 1 本だけにする。結果の表示が閉じた側(close)とマップの読み込み側(map)が
-- 別々に予約すると、待つ回数が半分の時間で尽きた
function Archeology_helper_try_ask_end_later(from, delay)
    if g.aoh_end_retry_pending then
        return
    end
    g.aoh_end_retry_pending = true
    ReserveScript(string.format("Archeology_helper_try_ask_end_retry('%s')", from), delay)
end

function Archeology_helper_try_ask_end_retry(from)
    g.aoh_end_retry_pending = nil
    Archeology_helper_try_ask_end(from)
end

-- 依頼の対象マップが全部「完了」になっているか(ゲームの記録で見る)。
-- 対象マップが空のときは完了にしない。マップの読み込み直後はアカウントの情報がまだ届いておらず空に見えるので、
-- 空を完了とすると途中のダンジョンの後で依頼を終えたことにしてしまう(完了しても対象マップは残る)
function Archeology_helper_mission_complete()
    local maps = Archeology_helper_active_maps()
    if #maps == 0 then
        return false
    end
    for _, map in ipairs(maps) do
        if not map.complete then
            return false
        end
    end
    return true
end

-- 最後の地点のダンジョンでは結果(RESULT)が届かず、表示が閉じる(CLOSE)だけだった(2026-10-12 の実機)。
-- そのため、結果を受けていなくても、閉じた時点で依頼が完了になっていれば聞く流れに乗せる
function Archeology_helper_PORTAL_CLOSE(frame, msg, arg_str, arg_num)
    if not Archeology_helper_active() then
        return
    end
    local complete = Archeology_helper_mission_complete()
    g.vlog("archeology_helper: ARCHEOLOGY_PORTAL_TRACKER_CLOSE map=%s layer=%d 完了=%s end_result=%s",
        session.GetMapName(), world.GetLayer(), tostring(complete), tostring(g.aoh_settings.end_result))
    if not g.aoh_settings.end_result and complete and not g.aoh_settings.end_asked then
        Archeology_helper_end_wait_start()
        g.aoh_settings.end_result = session.GetMapName()
        Archeology_helper_save_settings()
    end
    Archeology_helper_try_ask_end("close")
end

-- from = "map"(マップの読み込み)/ "close"(結果の表示が閉じた)
function Archeology_helper_try_ask_end(from)
    local pending = g.aoh_settings and g.aoh_settings.end_result
    if type(pending) ~= "string" then
        return
    end
    local map_name = session.GetMapName()
    -- 聞くのはフィールドか街に居るときだけ。控え(end_result)は結果を受けたマップ名なので、ダンジョンが
    -- 別マップだとダンジョンのマップ名が入り、それと比べるだけではダンジョンの中で聞いてしまう。
    -- 依頼の対象マップに居るか、マップの種類が Field / City かで見る
    local in_field = g.get_map_type() == "City" or g.get_map_type() == "Field"
    for _, map in ipairs(Archeology_helper_active_maps()) do
        in_field = in_field or map.name == map_name
    end
    if not in_field then
        g.vlog("archeology_helper: ダンジョンの結果は出たが、まだ %s(%s)に居るので聞かない", map_name,
            tostring(g.get_map_type()))
        return
    end
    -- 同じマップのままダンジョンがレイヤーで分かれている場合は、出るまで 2 秒ごとに見直す
    -- (マップを移ったら上の判定で止まり、読み込みの側で聞く)
    -- 見直しは 1 分(30 回)まで。それより長く別のレイヤーに居るなら諦め、控え(end_result)は残して
    -- マップを移ったとき(読み込みの側)に聞く
    if from ~= "map" and world.GetLayer() ~= 0 then
        g.aoh_layer_wait = (g.aoh_layer_wait or 0) + 1
        if g.aoh_layer_wait > 30 then
            g.vlog("archeology_helper: レイヤー %d から出ないので、レイヤーの見直しをやめる", world.GetLayer())
            return
        end
        g.vlog("archeology_helper: ダンジョンの結果は出たが、まだレイヤー %d に居るので待つ", world.GetLayer())
        Archeology_helper_try_ask_end_later("close", 2.0)
        return
    end
    -- 完了の記録はダンジョンの結果より少し遅れて届くことがあるので、控えを立ててから 4 秒までは 1 秒おきに見直す。
    -- マップの読み込みの側でも同じ(別マップのダンジョンから戻った直後や、ログインし直した直後)
    if not Archeology_helper_mission_complete() then
        local now = imcTime.GetAppTime()
        if not g.aoh_end_deadline then
            g.aoh_end_deadline = now + 4.0
        end
        if now < g.aoh_end_deadline then
            Archeology_helper_try_ask_end_later(from, 1.0)
            return
        end
        g.vlog("archeology_helper: ダンジョンを終えたが、依頼はまだ終わっていない(%s, map=%s)", from, map_name)
        g.aoh_settings.end_result = nil
        g.aoh_end_deadline = nil
        Archeology_helper_save_settings()
        return
    end
    g.vlog("archeology_helper: 依頼の最後のダンジョンを終えた(%s, map=%s)", from, map_name)
    g.aoh_settings.end_result = nil
    g.aoh_end_deadline = nil
    g.aoh_settings.is_archeology = false
    g.aoh_settings.count = 0
    g.aoh_settings.map_info = {}
    ui.SysMsg(g.lang == "Japanese" and "全てのMAPの発掘が完了しました" or "Archeology completed for all maps")
    Archeology_helper_save_settings()
    -- マップの読み込み直後は、確認の窓を出しても描き直しで消えることがあるので少し待つ
    ReserveScript("Archeology_helper_ask_go_home()", from == "map" and 1.5 or 0.1)
end

-- 次の依頼を受けにクラペダへ戻るか聞く。聞くのは 1 つの依頼につき 1 回だけ(end_asked。次の依頼を受けたら下ろす)。
function Archeology_helper_ask_go_home()
    if (g.aoh_settings.end_ask or 1) ~= 1 or g.aoh_settings.end_asked then
        g.vlog("archeology_helper: 全地点を掘り終えたが聞かない(end_ask=%s end_asked=%s)",
            tostring(g.aoh_settings.end_ask), tostring(g.aoh_settings.end_asked))
        return
    end
    g.vlog("archeology_helper: 全地点を掘り終えたのでクラペダへ戻るか聞く")
    g.aoh_settings.end_asked = true
    Archeology_helper_save_settings()
    local msg = g.lang == "Japanese" and "全ての地点の発掘が完了しました{nl}再度依頼を受けにクラペダへ戻りますか？" or
                    "All excavation points are done{nl}Return to Klaipeda to take the next mission?"
    ui.MsgBox(msg, "Archeology_helper_go_home()", "None")
end

-- 敵を表示するか(既定は表示する)
function Archeology_helper_mon_enabled()
    return (g.aoh_settings.mob_display or 1) == 1
end

function Archeology_helper_current_map_pic()
    local au_map = ui.GetFrame(addon_name_lower .. "au_map")
    if not au_map or not g.map_name then
        return nil
    end
    local map_pic = GET_CHILD_RECURSIVELY(au_map, "map_pic" .. g.map_name)
    if map_pic then
        AUTO_CAST(map_pic)
    end
    return map_pic
end

-- 敵 1 体を地図に置く。絵は素の全体マップと同じ選び方(GET_MAP_MON_MINIMAP_IMAGENAME)にする。
-- 小さい点(isDot)は雑魚、アイコン付きはボスなど。
function Archeology_helper_draw_mon(map_pic, handle, mon)
    local size = mon.is_dot and 6 or 16
    local mon_pic = map_pic:CreateOrGetControl("picture", "_MONPOS_" .. handle, 0, 0, size, size)
    AUTO_CAST(mon_pic)
    mon_pic:SetImage(mon.image)
    mon_pic:SetEnableStretch(1)
    mon_pic:EnableHitTest(0)
    local map_prop = session.GetCurrentMapProp()
    local pos = map_prop:WorldPosToMinimapPos(mon.x, mon.z, map_pic:GetWidth(), map_pic:GetHeight())
    mon_pic:SetOffset(pos.x - size / 2, pos.y - size / 2)
    mon_pic:ShowWindow(1)
end

function Archeology_helper_MON_MINIMAP(frame, msg, arg_str, arg_num, info)
    if not info or not g.aoh_settings or not Archeology_helper_mon_enabled() then
        return
    end
    -- type 0 はプレイヤー。対象マップ以外に居るときは描く先が無い
    if info.type == 0 then
        return
    end
    local map_pic = Archeology_helper_current_map_pic()
    if not map_pic then
        return
    end
    g.aoh_mons = g.aoh_mons or {}
    local handle = tostring(info.handle)
    local mon = g.aoh_mons[handle]
    if not mon then
        local image = "fullred"
        if GET_MAP_MON_MINIMAP_IMAGENAME then
            local ok, name = pcall(function()
                return GET_MAP_MON_MINIMAP_IMAGENAME(info)
            end)
            if ok and type(name) == "string" and name ~= "" and name ~= "None" then
                image = name
            end
        end
        if not g.aoh_mon_logged and
            g.vlog("archeology_helper: MON_MINIMAP handle=%s type=%s isDot=%s image=%s", handle,
                tostring(info.type), tostring(info.isDot), image) then
            g.aoh_mon_logged = true
        end
        mon = {
            image = image,
            is_dot = info.isDot == true
        }
        g.aoh_mons[handle] = mon
    end
    mon.x, mon.z = info.x, info.z
    Archeology_helper_draw_mon(map_pic, handle, mon)
end

function Archeology_helper_MON_MINIMAP_END(frame, msg, arg_str, handle)
    if not g.aoh_mons then
        return
    end
    handle = tostring(handle)
    g.aoh_mons[handle] = nil
    local map_pic = Archeology_helper_current_map_pic()
    if map_pic and GET_CHILD(map_pic, "_MONPOS_" .. handle) then
        map_pic:RemoveChild("_MONPOS_" .. handle)
        map_pic:Invalidate()
    end
end

-- 位置の追従と、END を取りこぼした敵の掃除(素の _MONPIC_AUTOUPDATE と同じ役)
function Archeology_helper_mon_update(map_pic)
    if not g.aoh_mons then
        return 1
    end
    local map_prop = session.GetCurrentMapProp()
    for handle, mon in pairs(g.aoh_mons) do
        local actor = world.GetActor(tonumber(handle))
        if not actor or not Archeology_helper_mon_enabled() then
            g.aoh_mons[handle] = nil
            map_pic:RemoveChild("_MONPOS_" .. handle)
        else
            local mon_pic = GET_CHILD(map_pic, "_MONPOS_" .. handle)
            if mon_pic then
                -- 位置の取り方は sub_map の Sub_map_monpic_auto_update と同じ(座標の入れ物をそのまま渡す)
                local pos = map_prop:WorldPosToMinimapPos(actor:GetPos(), map_pic:GetWidth(), map_pic:GetHeight())
                mon_pic:SetOffset(pos.x - mon_pic:GetWidth() / 2, pos.y - mon_pic:GetHeight() / 2)
            end
        end
    end
    return 1
end

-- いつ届くのかが分かっていないので、記録は消さずにログだけ出す(素は全体マップの輪を消している)。
function Archeology_helper_ARCHE_SEARCH_RESET(frame, msg, arg_str, arg_num)
    g.vlog("archeology_helper: ARCHE_SEARCH_RESET arg_str=%s arg_num=%s map=%s", tostring(arg_str),
        tostring(arg_num), session.GetMapName())
end

function Archeology_helper_TARGETSPACE_PRECHECK(my_frame, my_msg)
    local handle = g.get_event_args(my_msg)
    local actor = world.GetActor(handle)
    if not actor then
        return
    end
    local map_name = session.GetMapName()
    if not g.aoh_settings.map_info[map_name] then
        return
    end
    g.vlog("archeology_helper: TARGETSPACE_PRECHECK %s で ActorType=%s", map_name, tostring(actor:GetType()))
    if actor:GetType() == 155003 then
        local map_info = g.aoh_settings.map_info[map_name]
        map_info.markers = {}
        -- 1 つの地点で何度も来るので、回数を足さずに「いま探している地点の番号」(調査結果の target_key の
        -- _pos_<n>)へそろえる。足していたころは 2 つ目の地点で 4 に届き、途中で完了扱いになった
        local pos_index = tonumber(string.match(map_info.target_key or "", "_pos_(%d+)"))
        if pos_index and pos_index > (map_info.get_count or 0) then
            map_info.get_count = pos_index
        end
        g.vlog("archeology_helper: %s の地点に触れた (%d/%d)", map_name, map_info.get_count or 0,
            Archeology_helper_point_count())
        Archeology_helper_save_settings()
        Archeology_helper_frame_init()
        -- 依頼が終わったか(と「全てのMAPの発掘が完了しました」)は、ダンジョンを終えた後にゲームの記録で決める
        -- (Archeology_helper_try_ask_end)
    end
end

function Archeology_helper_MAP_CHARACTER_UPDATE()
    local au_map = ui.GetFrame(addon_name_lower .. "au_map")
    if not au_map then
        return
    end
    local map_pic = GET_CHILD_RECURSIVELY(au_map, "map_pic" .. g.map_name)
    local my = GET_CHILD_RECURSIVELY(au_map, "my")
    if not map_pic or not my then
        return
    end
    AUTO_CAST(map_pic)
    AUTO_CAST(my)
    Archeology_helper_char_update(my, map_pic)
end

function Archeology_helper_MISSION_ACCEPT_RESULT(frame, msg, arg_str, arg_num)
    if not Archeology_helper_active() then
        return
    end
    g.vlog("archeology_helper: ARCHEOLOGY_MISSION_ACCEPT_RESULT arg_str=%s arg_num=%s", tostring(arg_str),
        tostring(arg_num))
    if arg_str ~= "SUCCESS" then
        return
    end
    g.aoh_settings.count = 0
    g.aoh_settings.is_archeology = true
    g.aoh_settings.map_info = {}
    g.aoh_settings.end_asked = nil
    g.aoh_settings.end_pending = nil -- 旧版の控え(今は使わない)
    g.aoh_settings.end_result = nil
    -- 鑑定した遺物の NEW の印は、次の依頼を受けた時点で「もう見た」ものとして下ろす
    if next(g.aoh_settings.relic_new_guids or {}) then
        g.aoh_settings.relic_new_guids = {}
        Archeology_helper_relic_redraw_request()
    end
    Archeology_helper_save_settings()
    g.aoh_display = 0
    ui.DestroyFrame(addon_name_lower .. "au_map")
    -- 対象マップはアカウントのプロパティに後から入るので、少し待ってから描く
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    _nexus_addons_p:RunUpdateScript("Archeology_helper_frame_init", 1.0)
    -- 対象マップへのトークンワープ。素の WORLDMAP2_TOKEN_WARP が確認を出すので、こちらでは聞かない。
    -- 対象マップが入るのを待つため、パネルを描き直すより少し後にする。
    if (g.aoh_settings.accept_warp or 1) == 1 then
        ReserveScript("Archeology_helper_accept_tokenwarp()", 1.5)
    end
end

-- 依頼を受けた直後に、まだ掘り終えていない最初の対象マップへトークンワープする。
-- トークンが無い利用者だと素の WORLDMAP2_TOKEN_WARP が毎回「トークン利用者だけ」と出すので、
-- 素と同じ条件(IsPremiumState(ITEM_TOKEN) / Premium_Nexon)で先に見て、黙って抜ける
function Archeology_helper_accept_tokenwarp()
    if session.loginInfo.IsPremiumState(ITEM_TOKEN) == false and
        IsBuffApplied(GetMyPCObject(), "Premium_Nexon") ~= "YES" then
        g.vlog("archeology_helper: トークンが無いので依頼の対象マップへトークンワープしない")
        return
    end
    for _, map in ipairs(Archeology_helper_active_maps()) do
        if not Archeology_helper_is_map_done(map) then
            g.vlog("archeology_helper: 依頼を受けたので %s へトークンワープする(CD=%s)", map.name,
                tostring(GET_TOKEN_WARP_COOLDOWN()))
            WORLDMAP2_TOKEN_WARP(map.name)
            return
        end
    end
    g.vlog("{#FF6347}archeology_helper: 依頼を受けたが対象マップがまだ入っていないのでトークンワープしない{/}")
end

function Archeology_helper_frame_init(_nexus_addons_p)
    g.map_name = session.GetMapName()
    -- 敵の控えは今いるマップのものだけ。マップを移ったら前のマップの敵は捨てる
    if g.aoh_mons_map ~= g.map_name then
        g.aoh_mons = {}
        g.aoh_mons_map = g.map_name
    end
    local maps = Archeology_helper_active_maps()
    g.aoh_settings.is_archeology = Archeology_helper_in_progress()
    -- 自動で畳むのは、起動して最初に描くときに依頼が無かった場合だけ。
    -- 依頼が終わった瞬間には畳まない(終わったら「クラペダへ」を押すので、畳むと開き直す手間が要る)。
    -- 描き直すたびに畳むと、開き直したパネルがマップを移るたびに勝手に閉じてしまう。
    if g.aoh_drawn_once == nil then
        g.aoh_drawn_once = true
        if not g.aoh_settings.is_archeology then
            local tries, max_tries = Archeology_helper_try_info()
            g.vlog("archeology_helper: 依頼が無いので畳んで始める(対象マップ=%d 試行=%d/%d)", #maps, tries, max_tries)
            g.aoh_display = 1
        end
    end
    -- 対象マップが 1 つの依頼(Lv530 以上)は地図を大きく出す
    -- 幅は地図に合わせる(上の 2 段の表示とボタンは地図の幅に収める)。
    -- 1 段目: ＋/− とトークンワープの CD、右端に「クラペダへ」「Base」
    -- 2 段目: 試行回数・許可証・状態
    local cell = #maps == 1 and 320 or 198
    local top = 44
    g.aoh_panel_w = math.max(#maps * (cell + 2) - 2, 320)
    g.aoh_panel_h = top + cell + 20
    local au_map = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "au_map", 0, 0, 0, 0)
    AUTO_CAST(au_map)
    au_map:SetSkinName("None")
    au_map:SetLayerLevel(94)
    au_map:EnableHittestFrame(1)
    au_map:EnableMove(1)
    au_map:ShowTitleBar(0)
    au_map:RemoveAllChild()
    au_map:SetPos(g.aoh_settings.x or 670, g.aoh_settings.y or 70)
    au_map:SetEventScript(ui.LBUTTONUP, "Archeology_helper_frame_save")
    -- 上の 2 段の下敷き。地図と同じ色で、地図と同じ幅にして 1 枚のパネルに見せる
    local header_bg = au_map:CreateOrGetControl("picture", "header_bg", 0, 0, g.aoh_panel_w, top)
    AUTO_CAST(header_bg)
    header_bg:SetImage("fullwhite")
    header_bg:SetEnableStretch(1)
    header_bg:SetColorTone("AA696969")
    header_bg:SetAlpha(50)
    header_bg:EnableHitTest(0)
    local point_count = Archeology_helper_point_count()
    local my_handle = session.GetMyHandle()
    for disp_count, map in ipairs(maps) do
        local map_name = map.name
        local map_cls = GetClass("Map", map_name)
        if not g.aoh_settings.map_info[map_name] then
            g.aoh_settings.map_info[map_name] = {
                get_count = 0
            }
        end
        local map_info = g.aoh_settings.map_info[map_name]
        local gbox = au_map:CreateOrGetControl("picture", "gbox" .. map_name, (disp_count - 1) * (cell + 2), top, cell,
            cell + 20)
        AUTO_CAST(gbox)
        gbox:SetImage("fullwhite")
        gbox:SetEnableStretch(1)
        gbox:SetColorTone("AA696969")
        gbox:SetAlpha(50)
        local title = gbox:CreateOrGetControl("richtext", "title", 5, 5)
        AUTO_CAST(title)
        title:SetText("{ol}{s13}" .. map_cls.Name)
        local got = map.complete and point_count or math.min(map_info.get_count or 0, point_count)
        for j = 0, point_count - 1 do
            local mark = gbox:CreateOrGetControl("richtext", "mark" .. j, title:GetWidth() + 15 + j * 15, 5)
            AUTO_CAST(mark)
            if got > j then
                mark:SetText("{ol}{#00FF00}●")
            else
                mark:SetText("{ol}{#808080}●")
            end
        end
        -- 輪は地図より大きくなることがある(遠いほど大きい)ので、groupbox で切り取る
        local clip = gbox:CreateOrGetControl("groupbox", "clip" .. map_name, 0, 20, cell, cell)
        AUTO_CAST(clip)
        clip:SetSkinName("None")
        clip:EnableScrollBar(0)
        clip:EnableHitTest(0)
        local map_pic = clip:CreateOrGetControl("picture", "map_pic" .. map_name, 0, 0, cell, cell)
        AUTO_CAST(map_pic)
        map_pic:SetEnableStretch(1)
        map_pic:EnableHitTest(0)
        Archeology_helper_set_minimap(map_pic, map_name)
        Archeology_helper_draw_markers(map_pic, map_name)
        if g.map_name == map_name then
            -- RemoveAllChild で消えた敵を控えから描き直し、位置の追従と消え残りの掃除を回す
            for handle, mon in pairs(g.aoh_mons or {}) do
                Archeology_helper_draw_mon(map_pic, handle, mon)
            end
            map_pic:RunUpdateScript("Archeology_helper_mon_update", 0.5)
        end
        if g.map_name == map_name then
            local my = map_pic:CreateOrGetControl("picture", "my", 0, 0, 15, 15)
            AUTO_CAST(my)
            my:ShowWindow(0)
            my:SetImage("minimap_leader")
            my:SetEnableStretch(1)
            Archeology_helper_char_update(my, map_pic)
        end
        local buff_info = info.GetBuff(my_handle, 70002)
        local image_name = ""
        if buff_info and GET_TOKEN_WARP_COOLDOWN() == 0 then
            image_name = "{img worldmap2_token_gold 30 30} {@st101lightbrown_16}"
        else
            image_name = "{img worldmap2_token_gray 30 30} {@st101lightbrown_16}"
        end
        local token = gbox:CreateOrGetControl("button", "token" .. disp_count, 0, 0, 30, 30)
        AUTO_CAST(token)
        token:SetGravity(ui.RIGHT, ui.TOP)
        token:SetSkinName("None")
        token:SetText(image_name)
        token:SetUserValue("MAP_NAME", map_name)
        token:SetEventScript(ui.LBUTTONUP, "Archeology_helper_tokenwarp")
    end
    local display = au_map:CreateOrGetControl("picture", "display", 0, 0, 20, 20)
    AUTO_CAST(display)
    display:SetEnableStretch(1)
    display:EnableHitTest(1)
    local image = ""
    if not g.aoh_display or g.aoh_display == 0 then
        g.aoh_display = 0
        au_map:Resize(g.aoh_panel_w, g.aoh_panel_h)
        au_map:SetLayerLevel(94)
        image = "btn_minus"
    elseif g.aoh_display == 1 then
        image = "btn_plus"
        au_map:Resize(20, 20)
        au_map:SetLayerLevel(11)
    end
    display:SetImage(image)
    display:SetEventScript(ui.LBUTTONDOWN, "Archeology_helper_display_down")
    display:SetEventScript(ui.LBUTTONUP, "Archeology_helper_frame_toggle")
    display:SetEventScript(ui.RBUTTONUP, "Archeology_helper_setting_frame")
    display:SetTextTooltip("{ol}left-click: Display / hide{nl}right-click: settings")
    local cool_down = au_map:CreateOrGetControl("richtext", "cool_down", 20, 0)
    AUTO_CAST(cool_down)
    local cd = GET_TOKEN_WARP_COOLDOWN()
    local minutes = math.floor(cd / 60)
    local seconds = cd % 60
    local timer = string.format("%d:%02d", minutes, seconds)
    cool_down:SetText("{ol}{#FFFFFF}TokenWarp CD: " .. timer)
    cool_down:RunUpdateScript("Archeology_helper_tokenwarp_cd", 1.0)
    local tries, max_tries = Archeology_helper_try_info()
    local count_text = au_map:CreateOrGetControl("richtext", "count_text", 0, 22)
    AUTO_CAST(count_text)
    count_text:SetText("{ol}" .. tries .. "/" .. max_tries)
    local x = count_text:GetWidth()
    local slot = au_map:CreateOrGetControl('slot', 'slot', x + 10, 22, 20, 20)
    AUTO_CAST(slot)
    local item_cls = GetClass('Item', g.aoh.permit_item)
    if item_cls then
        SET_SLOT_ITEM_CLS(slot, item_cls)
    end
    local item_count = au_map:CreateOrGetControl("richtext", "item_count", x + 35, 22)
    AUTO_CAST(item_count)
    local arc_text = au_map:CreateOrGetControl("richtext", "arc_text", x + 100, 22)
    AUTO_CAST(arc_text)
    local msg = ""
    if g.aoh_settings.is_archeology == true then
        msg = g.lang == "Japanese" and "{ol}{#FF0000}※進行中" or "{ol}{#FF0000}In Progress"
    else
        msg = g.lang == "Japanese" and "{ol}{#FF0000}※終了" or "{ol}{#FF0000}Ended"
    end
    arc_text:SetText(msg)
    local home_btn = au_map:CreateOrGetControl("button", "home_btn", g.aoh_panel_w - 117, 0, 65, 20)
    AUTO_CAST(home_btn)
    home_btn:SetText(g.lang == "Japanese" and "{ol}{s12}クラペダへ" or "{ol}{s12}Klaipeda")
    home_btn:SetTextTooltip(g.lang == "Japanese" and
                                "{ol}依頼の NPC が居るクラペダへ戻ります{nl}トークンワープは使いません(クエストワープ / ワープスクロール){nl}着いたら NPC の前へ移動します(クラペダに居るときは NPC の前へ移動だけ){nl}使うクエスト・NPC への移動は設定で選べます" or
                                "{ol}Return to Klaipeda, where the mission NPC is{nl}Does not use token warp (quest warp / warp scroll){nl}Moves to the NPC on arrival (only moves to the NPC if already in Klaipeda){nl}Quest and NPC move are configurable in settings")
    home_btn:SetEventScript(ui.LBUTTONUP, "Archeology_helper_go_home")
    local base_btn = au_map:CreateOrGetControl("button", "base_btn", g.aoh_panel_w - 50, 0, 50, 20)
    AUTO_CAST(base_btn)
    base_btn:SetText("{ol}{s12}Base")
    base_btn:SetEventScript(ui.LBUTTONUP, "Archeology_helper_frame_base_pos")
    Archeology_helper_save_settings()
    au_map:ShowWindow(1)
    return 0
end

-- 地図は霧の掛かっていない全体図(<マップ名>)を出す。"<マップ名>_fog" は踏破した所しか描かれず、
-- 行ったことのない所が抜ける。全体図は素の依頼の窓(archeology_mission.lua)と同じく
-- world.PreloadMinimap(名前, 512, false) で読み込む。読み込みは後から終わることがあるので、
-- 間に合わなければ霧の図を仮に出して、少し後に差し替える。
function Archeology_helper_set_minimap(map_pic, map_name)
    if ui.IsImageExist(map_name) == true then
        map_pic:SetImage(map_name)
        return
    end
    world.PreloadMinimap(map_name, 512, false)
    if ui.IsImageExist(map_name) == true then
        map_pic:SetImage(map_name)
        return
    end
    g.vlog("archeology_helper: %s の全体図が未読み込み。霧の図で仮に出して読み込みを待つ", map_name)
    map_pic:SetImage(map_name .. "_fog")
    map_pic:SetUserValue("AOH_MAP_NAME", map_name)
    map_pic:SetUserValue("AOH_RETRY", 0)
    map_pic:RunUpdateScript("Archeology_helper_minimap_retry", 0.3)
end

function Archeology_helper_minimap_retry(map_pic)
    local map_name = map_pic:GetUserValue("AOH_MAP_NAME")
    if ui.IsImageExist(map_name) == true then
        map_pic:SetImage(map_name)
        g.vlog("archeology_helper: %s の全体図に差し替えた", map_name)
        return 0
    end
    local retry = map_pic:GetUserIValue("AOH_RETRY") + 1
    map_pic:SetUserValue("AOH_RETRY", retry)
    if retry >= 10 then
        g.vlog("{#FF6347}archeology_helper: %s の全体図が読み込めなかった。霧の図のまま{/}", map_name)
        return 0
    end
    return 1
end

-- クラペダへ戻るときに試すクエストの並び。設定 home_quest が "auto" なら全部を順に、
-- クエスト ID なら そのクエストだけ、"none" ならクエストワープを使わない。
function Archeology_helper_home_quest_candidates()
    local setting = g.aoh_settings.home_quest or "auto"
    local list = {}
    for _, quest in ipairs(g.aoh.home_quests) do
        if setting == "auto" or tostring(quest.quest_id) == tostring(setting) then
            list[#list + 1] = quest
        end
    end
    return list
end

-- 依頼の NPC の前へ移動する。クラペダに居るときだけ。
function Archeology_helper_move_npc()
    if session.GetMapName() ~= g.aoh.home_map then
        g.vlog("archeology_helper: NPC へ移動しない(クラペダではない map=%s)", session.GetMapName())
        return
    end
    if world.GetLayer() ~= 0 then
        g.vlog("archeology_helper: NPC へ移動しない(レイヤー %d)", world.GetLayer())
        ui.SysMsg(ScpArgMsg("ThisLocalUseNot"))
        return
    end
    local name = g.lang == "Japanese" and "考古学者アイリーネ" or "Archeologist Airine"
    g.vlog("archeology_helper: NPC へ移動する dialog=%s", g.aoh.home_npc_dialog)
    FullScreenMenuMoveNpc(name, "NO", g.aoh.home_map, g.aoh.home_npc_dialog, "None", "YES")
end

-- マップを読み込むたびに呼ぶ。「クラペダへ」で出発してクラペダに着いたときだけ NPC へ移動する。
-- 着いた場所に関係なく印は 1 回で消す(途中で別のマップへ寄ったら、もう NPC へは動かさない)。
function Archeology_helper_arrive_home()
    local pending = g.aoh_npc_pending
    if not pending then
        return
    end
    g.aoh_npc_pending = nil
    local elapsed = imcTime.GetAppTime() - pending
    local map_name = session.GetMapName()
    g.vlog("archeology_helper: 「クラペダへ」の後のマップ読み込み map=%s 経過=%.1f 秒", map_name, elapsed)
    if map_name ~= g.aoh.home_map or elapsed > g.aoh.home_npc_wait then
        return
    end
    -- 読み込み直後はまだ移動を受け付けないことがあるので少し待つ
    ReserveScript("Archeology_helper_move_npc()", 1.5)
end

function Archeology_helper_go_home()
    local to_npc = (g.aoh_settings.home_npc or 1) == 1
    if session.GetMapName() == g.aoh.home_map then
        if to_npc then
            Archeology_helper_move_npc()
            return
        end
        ui.SysMsg(g.lang == "Japanese" and "既にクラペダに居ます" or "You are already in Klaipeda")
        return
    end
    local pc = GetMyPCObject()
    if ENABLE_WARP_CHECK(pc) == false then
        ui.SysMsg(ScpArgMsg("WarpBanBountyHunt"))
        return
    end
    for _, quest in ipairs(Archeology_helper_home_quest_candidates()) do
        local quest_cls = GetClassByType("QuestProgressCheck", quest.quest_id)
        if quest_cls then
            local result = SCR_QUEST_CHECK_C(pc, quest_cls.ClassName)
            local state = GET_QUEST_NPC_STATE(quest_cls, result)
            g.vlog("archeology_helper: クラペダへ クエスト %d result=%s state=%s", quest.quest_id, tostring(result),
                tostring(state))
            if result == quest.result and state == quest.state then
                g.aoh_npc_pending = to_npc and imcTime.GetAppTime() or nil
                QUESTION_QUEST_WARP(nil, nil, nil, quest.quest_id)
                return
            end
        end
    end
    if (g.aoh_settings.home_item or 1) == 1 then
        local inv_item = session.GetInvItemByType(g.aoh.home_item)
        if inv_item then
            local item_obj = GetIES(inv_item:GetObject())
            g.vlog("archeology_helper: クラペダへ ワープスクロールを使う(残り %d)", inv_item.count)
            g.aoh_npc_pending = to_npc and imcTime.GetAppTime() or nil
            if TRY_TO_USE_WARP_ITEM(inv_item, item_obj) ~= 1 then
                INV_ICON_USE(inv_item)
            end
            return
        end
    end
    ui.SysMsg(g.lang == "Japanese" and "トークン以外でクラペダへ戻る方法がありません" or
                  "There is no way to return to Klaipeda without token warp")
end

function Archeology_helper_home_quest_setting(value)
    g.aoh_settings.home_quest = value
    Archeology_helper_save_settings()
end

-- 設定の窓のチェック(アカウント共通の ON/OFF)。チェックの名前 = 設定のキー。
-- 切り替えた後にインベントリへ反映が要るものだけ、表(g.aoh.setting_after)で後処理を引く
--   refresh = 組み立て直す(番号・並び・セクションを付け直す / OFF なら素の並びへ戻す)
--   redraw  = 遺物の表示だけ描き直す(NEW の印)
function Archeology_helper_setting_check(frame, ctrl)
    local key = ctrl:GetName()
    g.aoh_settings[key] = ctrl:IsChecked()
    Archeology_helper_save_settings()
    local after = g.aoh.setting_after[key]
    if after == "refresh" then
        Archeology_helper_relic_refresh(true)
    elseif after == "redraw" then
        Archeology_helper_relic_redraw_request()
    end
end

-- インベントリを描き直して、遺物の番号を付け直す(描き直しで INV_ICON_SETINFO を通す)。
-- force = 設定を切り替えたとき(OFF にしたときも、出ている番号を消すために描き直す)
function Archeology_helper_relic_refresh(force)
    -- 番号・NEW の印・並べ替え・セクション分けのどれも OFF なら、ログイン直後に組み立て直す必要は無い
    if not force and (g.aoh_settings.relic_slot or 1) ~= 1 and (g.aoh_settings.relic_new or 1) ~= 1 and
        not Archeology_helper_relic_layout_enabled() then
        return
    end
    local inventory = ui.GetFrame("inventory")
    if not inventory then
        return
    end
    g.vlog("archeology_helper: 遺物の表示のためにインベントリを描き直す")
    INVENTORY_TOTAL_LIST_GET(inventory)
    Archeology_helper_relic_sort_request(true)
end

function Archeology_helper_setting_frame(au_map, display)
    local setting = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "archeology_helper_setting", 0, 0, 0, 0)
    setting:SetSkinName("test_frame_low")
    setting:EnableHittestFrame(1)
    setting:EnableHitTest(1)
    setting:SetLayerLevel(999)
    setting:RemoveAllChild()
    local title_text = setting:CreateOrGetControl('richtext', 'title_text', 20, 15, 50, 30)
    AUTO_CAST(title_text)
    title_text:SetText("{ol}Archeology Helper Config")
    local close = setting:CreateOrGetControl("button", "close", 0, 0, 20, 20)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Archeology_helper_setting_frame_close")
    local gbox = setting:CreateOrGetControl("groupbox", "gbox", 10, 40, setting:GetWidth() - 20,
        setting:GetHeight() - 50) -- 945
    AUTO_CAST(gbox)
    gbox:EnableScrollBar(0)
    gbox:SetSkinName("test_frame_midle_light")
    local sta_check = gbox:CreateOrGetControl('checkbox', "sta_check", 10, 10, 30, 30)
    AUTO_CAST(sta_check)
    if not g.aoh_settings[g.cid] then
        g.aoh_settings[g.cid] = {
            sta_check = 0
        }
        Archeology_helper_save_settings()
    end
    sta_check:SetCheck(g.aoh_settings[g.cid].sta_check)
    sta_check:SetText(g.lang == "Japanese" and
                          "{ol}チェックするとスタミナ錠自動使用{nl}設定はキャラ毎です" or
                          "{ol}If checked, it will automatically use stamina pills{nl}Settings are per character")
    sta_check:SetEventScript(ui.LBUTTONUP, "Archeology_helper_setting_change")
    -- クラペダへ戻るときのクエストワープ
    local home_text = gbox:CreateOrGetControl('richtext', 'home_text', 10, 60)
    AUTO_CAST(home_text)
    home_text:SetText(g.lang == "Japanese" and "{ol}「クラペダへ」で使うクエストワープ" or
                          "{ol}Quest warp for the Klaipeda button")
    local home_list = gbox:CreateOrGetControl('droplist', 'home_list', 10, 85, 330, 20)
    AUTO_CAST(home_list)
    home_list:SetSkinName('droplist_normal')
    home_list:EnableHitTest(1)
    home_list:SetTextAlign("center", "center")
    local selected = 0
    home_list:AddItem(0, g.lang == "Japanese" and "{ol}自動(使えるものを順に)" or "{ol}Auto (first usable)", 0,
        "Archeology_helper_home_quest_setting('auto')")
    for i, quest in ipairs(g.aoh.home_quests) do
        local quest_cls = GetClassByType("QuestProgressCheck", quest.quest_id)
        local name = quest_cls and quest_cls.Name or tostring(quest.quest_id)
        local when = quest.state == "Start" and (g.lang == "Japanese" and "受注可能なとき" or "when acceptable") or
                         (g.lang == "Japanese" and "完了可能なとき" or "when completable")
        home_list:AddItem(i, "{ol}" .. name .. " (" .. when .. ")", 0,
            string.format("Archeology_helper_home_quest_setting('%d')", quest.quest_id))
        if tostring(g.aoh_settings.home_quest) == tostring(quest.quest_id) then
            selected = i
        end
    end
    local none_index = #g.aoh.home_quests + 1
    home_list:AddItem(none_index, g.lang == "Japanese" and "{ol}使わない" or "{ol}Do not use", 0,
        "Archeology_helper_home_quest_setting('none')")
    if g.aoh_settings.home_quest == "none" then
        selected = none_index
    end
    home_list:SelectItem(selected)
    -- アカウント共通の ON/OFF(既定はどれも ON)。名前 = 設定のキー。切り替えは Archeology_helper_setting_check
    local width = math.max(sta_check:GetWidth(), 330)
    local y = 115
    for _, def in ipairs(g.aoh.setting_checks) do
        local check = gbox:CreateOrGetControl('checkbox', def.key, 10, y, 30, 30)
        AUTO_CAST(check)
        check:SetCheck(g.aoh_settings[def.key] or 1)
        check:SetText("{ol}" .. (g.lang == "Japanese" and def.jp or def.en))
        check:SetEventScript(ui.LBUTTONUP, "Archeology_helper_setting_check")
        width = math.max(width, check:GetWidth())
        y = y + 35
    end
    setting:Resize(width + 50, y + 60)
    gbox:Resize(setting:GetWidth() - 20, y + 10)
    setting:SetPos(g.settings_frame_pos(setting:GetWidth(), setting:GetHeight()))
    setting:ShowWindow(1)
    g.block_click_through(setting)
    g.esc_register_destroy(addon_name_lower .. "archeology_helper_setting")
end

function Archeology_helper_setting_change()
    g.aoh_settings[g.cid].sta_check = 1 - g.aoh_settings[g.cid].sta_check
    Archeology_helper_save_settings()
end

function Archeology_helper_setting_frame_close(setting)
    ui.DestroyFrame(setting:GetName())
end

function Archeology_helper_display_down(au_map, display)
    g.aoh_down_x, g.aoh_down_y = au_map:GetX(), au_map:GetY()
end

function Archeology_helper_frame_toggle(au_map, display)
    -- ＋/− をつかんでパネルを動かしたときも、離した瞬間にここへ来る。動いていたら移動として扱い、
    -- 開閉はしない(つかんで動かすと畳まれてしまう)。
    if g.aoh_down_x and (au_map:GetX() ~= g.aoh_down_x or au_map:GetY() ~= g.aoh_down_y) then
        g.vlog("archeology_helper: ＋/− をつかんで動かしただけなので開閉しない")
        g.aoh_down_x, g.aoh_down_y = nil, nil
        Archeology_helper_frame_save(au_map)
        return
    end
    g.aoh_down_x, g.aoh_down_y = nil, nil
    g.vlog("archeology_helper: ＋/− を押した(%s)", (not g.aoh_display or g.aoh_display == 1) and "開く" or "畳む")
    if not g.aoh_display or g.aoh_display == 1 then
        display:SetImage("btn_minus")
        g.aoh_display = 0
        au_map:Resize(g.aoh_panel_w or 620, g.aoh_panel_h or 240)
    else
        display:SetImage("btn_plus")
        g.aoh_display = 1
        au_map:Resize(20, 20)
    end
end

function Archeology_helper_frame_save(au_map)
    g.aoh_settings.x = au_map:GetX()
    g.aoh_settings.y = au_map:GetY()
    Archeology_helper_save_settings()
end

function Archeology_helper_frame_base_pos(au_map, base_btn)
    g.aoh_settings.x = 670
    g.aoh_settings.y = 70
    Archeology_helper_save_settings()
    Archeology_helper_frame_init()
end

-- 輪の絵は素の全体マップと同じもの(大きさに応じて解像度を選ぶ)。無いクライアントでは旧来の丸。
function Archeology_helper_ring_image(size)
    local name = "archeology_survey_ring_1024"
    if size <= 128 then
        name = "archeology_survey_ring_128"
    elseif size <= 256 then
        name = "archeology_survey_ring_256"
    elseif size <= 512 then
        name = "archeology_survey_ring_512"
    end
    if ui.IsImageExist(name) == false then
        return "questmap"
    end
    return name
end

-- 調べた位置を中心に、素の全体マップと同じ大きさの輪を描く
-- (直径 = 輪の大きさ * MINIMAP_LOC_MULTI * 地図の幅 / WORLD_SIZE。map.lua の DRAW_ARCHEOLOGY_SURVEY_CIRCLES)。
function Archeology_helper_draw_markers(map_pic, map_name)
    local map_info = g.aoh_settings.map_info[map_name]
    local markers = map_info and map_info.markers or {}
    if #markers == 0 then
        return
    end
    local map_prop = geMapTable.GetMapProp(map_name)
    if not map_prop then
        return
    end
    local w, h = map_pic:GetWidth(), map_pic:GetHeight()
    local loc_multi = MINIMAP_LOC_MULTI or 4
    local world_size = WORLD_SIZE or 10240
    for _, m in ipairs(markers) do
        if m.wx and m.wz and m.draw then
            local pos = map_prop:WorldPosToMinimapPos(m.wx, m.wz, w, h)
            local range_x = m.draw * loc_multi * w / world_size
            local range_y = m.draw * loc_multi * h / world_size
            local ring = map_pic:CreateOrGetControl('picture', "circle" .. m.count, pos.x - range_x / 2,
                pos.y - range_y / 2, range_x, range_y)
            AUTO_CAST(ring)
            ring:SetImage(Archeology_helper_ring_image(math.max(range_x, range_y)))
            ring:SetEnableStretch(1)
            ring:SetColorTone(m.color)
            ring:SetAlpha(65)
            ring:EnableHitTest(0)
            ring:ShowWindow(1)
            local text_color = string.sub(m.color, 3)
            local marker_text = map_pic:CreateOrGetControl('richtext', "text" .. m.count, 0, 0)
            AUTO_CAST(marker_text)
            marker_text:SetText("{ol}{#" .. text_color .. "}{s14}" .. m.count)
            marker_text:SetOffset(pos.x - (marker_text:GetWidth() / 2), pos.y - (marker_text:GetHeight() / 2))
            marker_text:EnableHitTest(0)
        end
    end
end

-- 依頼の状態(各マップの完了・試行回数)を 1 つの文字列にする。サーバーが後から書き換えるので、
-- 変わったら描き直すための比較に使う。
function Archeology_helper_state_key()
    local acc_obj = GetMyAccountObj()
    if not acc_obj then
        return ""
    end
    local parts = {tostring(TryGetProp(acc_obj, "archeology_try_count", 0))}
    for _, map in ipairs(Archeology_helper_active_maps()) do
        parts[#parts + 1] = map.name .. "=" .. (map.complete and "1" or "0")
    end
    return table.concat(parts, ";")
end

function Archeology_helper_tokenwarp_cd(cool_down)
    -- 最後の地点を掘ったときなど、完了の印はサーバーから少し遅れて届く。届いたら描き直す
    -- (この更新処理の持ち主ごと作り直すので、その場では呼ばずに予約する)。
    local state_key = Archeology_helper_state_key()
    if g.aoh_state_key and g.aoh_state_key ~= state_key then
        g.vlog("archeology_helper: 依頼の状態が変わった %s -> %s。描き直す", g.aoh_state_key, state_key)
        g.aoh_state_key = state_key
        ReserveScript("Archeology_helper_frame_init()", 0.01)
        return 0
    end
    g.aoh_state_key = state_key
    local cd = GET_TOKEN_WARP_COOLDOWN()
    local minutes = math.floor(cd / 60)
    local seconds = cd % 60
    local timer = string.format("%d:%02d", minutes, seconds)
    cool_down:SetText("{ol}{#FFFFFF}TokenWarp CD: " .. timer)
    local my_handle = session.GetMyHandle()
    local au_map = cool_down:GetTopParentFrame()
    for i = 1, (max_archeology_map_count or 3) do
        local buff_info = info.GetBuff(my_handle, 70002)
        local image_name = ""
        if buff_info and GET_TOKEN_WARP_COOLDOWN() == 0 then
            image_name = "{img worldmap2_token_gold 30 30} {@st101lightbrown_16}"
        else
            image_name = "{img worldmap2_token_gray 30 30} {@st101lightbrown_16}"
        end
        local token = GET_CHILD_RECURSIVELY(au_map, "token" .. i)
        if token then
            AUTO_CAST(token)
            token:SetText(image_name)
        end
    end
    local slot = GET_CHILD(au_map, "slot")
    local icon = slot:GetIcon()
    if not icon then
        icon = CreateIcon(slot)
    end
    local item_count = GET_CHILD(au_map, "item_count")
    local inv_item = session.GetInvItemByName(g.aoh.permit_item)
    if inv_item then
        icon:SetColorTone('FFFFFFFF')
        item_count:SetText("{ol}(" .. inv_item.count .. ")")
    else
        icon:SetColorTone('FFFF0000')
        item_count:SetText("{ol}(0)")
    end
    return 1
end

function Archeology_helper_char_update(my, map_pic)
    local my_handle = session.GetMyHandle()
    local pos = info.GetPositionInMap(my_handle, map_pic:GetWidth(), map_pic:GetHeight())
    my:SetOffset(pos.x - my:GetWidth() / 2, pos.y - my:GetHeight() / 2)
    local map_prop = session.GetCurrentMapProp()
    local angle = info.GetAngle(my_handle) - map_prop.RotateAngle
    my:SetAngle(angle)
    my:ShowWindow(1)
    map_pic:Invalidate()
end

function Archeology_helper_tokenwarp(frame, ctrl)
    local map_name = ctrl:GetUserValue("MAP_NAME")
    if map_name ~= "None" then
        WORLDMAP2_TOKEN_WARP(map_name)
    end
end
-- 遺物 1 つが入る展示のスロット(g.aoh.exhibit_slots の 1 件)。遺物でなければ nil。
-- 遺物の ClassName は「系統名 + 等級(_N / _M / _R)」で、系統名から archeology_base_list の行を引く
-- (素の GET_ARCEX_SLOT_INFO_BY_ITEM_CLASS と同じ引き方)。
function Archeology_helper_relic_slot_of(class_name)
    if type(class_name) ~= "string" or string.sub(class_name, 1, 4) ~= "Arc_" then
        return nil
    end
    if not (shared_archeology and shared_archeology.get_base_profile and GET_ARCHEOLOGY_RELIC_FAMILY_CLASS_NAME) then
        return nil
    end
    local profile = shared_archeology.get_base_profile(GET_ARCHEOLOGY_RELIC_FAMILY_CLASS_NAME(class_name))
    return profile and g.aoh.exhibit_slots[profile.exhibitSlotType or "None"]
end

-- 鑑定した遺物の左上に NEW の印(N)を出す。番号と同じく、使い回されたスロットでは消す。
function Archeology_helper_relic_new_label(slot, inv_item)
    local name = "aoh_relic_new"
    local is_new = (g.aoh_settings.relic_new or 1) == 1 and inv_item and
                       (g.aoh_settings.relic_new_guids or {})[inv_item:GetIESID()]
    if not is_new then
        if GET_CHILD(slot, name) then
            DESTROY_CHILD_BYNAME(slot, name)
        end
        return
    end
    local label = slot:CreateOrGetControl("richtext", name, 0, 0, 16, 16)
    AUTO_CAST(label)
    label:SetGravity(ui.LEFT, ui.TOP)
    label:SetMargin(4, 2, 0, 0)
    label:EnableHitTest(0) -- 掴む・右クリックはスロットへ通す
    label:SetText("{ol}{s16}{#FFFF33}N")
    g.aoh_inventory_touched = true
end

-- 鑑定が終わった遺物(素の ON_ARCHEOLOGY_IDENTIFY_FINISHED と同じく、3 つ目に GUID が来る)。
-- 鑑定はアイテムを作り直さず同じ GUID の遺物に効果を足すので、GUID で覚える
function Archeology_helper_IDENTIFY_FINISHED(frame, msg, guid)
    if not Archeology_helper_active() then
        return
    end
    g.vlog("archeology_helper: ARCHEOLOGY_IDENTIFY_FINISHED guid=%s", tostring(guid))
    if type(guid) ~= "string" or guid == "" or guid == "None" then
        return
    end
    g.aoh_settings.relic_new_guids = g.aoh_settings.relic_new_guids or {}
    if not g.aoh_settings.relic_new_guids[guid] then
        g.aoh_settings.relic_new_guids[guid] = true
        Archeology_helper_save_settings()
    end
    Archeology_helper_relic_redraw_request()
end

-- 鑑定の成功(素の ON_SUCCESS_ARCH_IDENTIFY と同じメッセージ)。GUID は載らないので、
-- 鑑定の窓に置いている遺物(素が ITEM_GUID に控えている)を印の対象にする。
-- ARCHEOLOGY_IDENTIFY_FINISHED だけでは実機で一度も届かなかったので、こちらでも拾う
function Archeology_helper_IDENTIFY_SUCCESS(frame, msg, arg_str, arg_num)
    if not Archeology_helper_active() then
        return
    end
    local identify = ui.GetFrame("archeology_identify")
    local guid = identify and identify:GetUserValue("ITEM_GUID")
    g.vlog("archeology_helper: SUCCESS_ARCH_IDENTIFY guid=%s", tostring(guid))
    Archeology_helper_IDENTIFY_FINISHED(frame, msg, guid)
end

-- 展示・分解・売却などでインベントリから無くなった遺物は印の控えからも消す
function Archeology_helper_relic_new_remove(frame, msg, guid)
    if not Archeology_helper_active() then
        return
    end
    local guids = g.aoh_settings.relic_new_guids
    if guids and type(guid) == "string" and guids[guid] then
        guids[guid] = nil
        Archeology_helper_save_settings()
    end
end

-- 遺物の表示(番号・NEW の印・並び)を描き直す。鑑定は続けて行うので、まとめて 1 回にする
function Archeology_helper_relic_redraw_request()
    if g.aoh_relic_redraw_pending then
        return
    end
    g.aoh_relic_redraw_pending = true
    ReserveScript("Archeology_helper_relic_redraw()", 0.5)
end

function Archeology_helper_relic_redraw()
    g.aoh_relic_redraw_pending = nil
    if Archeology_helper_relic_layout_enabled() then
        g.aoh_relic_force = true
        Archeology_helper_relic_sort() -- 遺物のスロットを全部置き直すので、印も付け直される
    else
        Archeology_helper_relic_refresh(true)
    end
end

-- 祭壇ランク上昇の窓は、使用数を 1 で開く(素の EXCUTE_EXHIBITION_RANKUP)。素が開いた後に、
-- 素が窓に出した「使用可能数: 1〜<最大>」(rankup_range の max)を読んで入れ直す。
-- 式やコインのアイテム ID を写すと、パッチで変わったときに黙って効かなくなるので、素の計算結果を使う
function Archeology_helper_EXCUTE_EXHIBITION_RANKUP(frame, ctrl, arg_str, arg_num)
    local results = {g.FUNCS["EXCUTE_EXHIBITION_RANKUP"](frame, ctrl, arg_str, arg_num)}
    if not Archeology_helper_active() then
        return table.unpack(results)
    end
    local ok, err = pcall(function()
        local exhibition = ui.GetFrame("archeology_exhibition")
        local dialog = exhibition and GET_CHILD_RECURSIVELY(exhibition, "rankup_overlay")
        if not dialog or dialog:IsVisible() == 0 then
            return
        end
        local range = GET_CHILD_RECURSIVELY(dialog, "rankup_range")
        local maximum = range and range:IsVisible() == 1 and tonumber(range:GetTextByKey("max")) or 0
        g.vlog("archeology_helper: 祭壇ランク上昇の使用数を最大へ → %s", tostring(maximum))
        if maximum < 1 then
            return
        end
        local count = GET_CHILD_RECURSIVELY(dialog, "rankup_count")
        -- 素は SetTextByKey で書式の控えを入れ直しているが、それでは欄の表示は変わらない
        -- (実機で 0 のままだった)。素の EXHIBITION_RANKUP_UPDATE は欄の GetText を読むので、欄へ直接書く
        count:SetTextByKey("count", "")
        count:SetTextByKey("count", tostring(maximum))
        AUTO_CAST(count)
        count:SetText(tostring(maximum))
        g.vlog("archeology_helper: 祭壇ランク上昇の欄 = %s", tostring(count:GetText()))
        EXHIBITION_RANKUP_UPDATE()
    end)
    if not ok then
        g.vlog("{#FF6347}archeology_helper: 祭壇ランク上昇の使用数を入れられなかった %s{/}", tostring(err))
    end
    return table.unpack(results)
end

-- インベントリのスロットの右上に、遺物が入る展示スロットの番号を出す。
-- スロットは別のアイテムへ使い回されるので、遺物でないときは前の番号を消す。
function Archeology_helper_relic_label(slot, inv_item)
    Archeology_helper_relic_new_label(slot, inv_item)
    local name = "aoh_relic_slot"
    local exhibit = nil
    if (g.aoh_settings.relic_slot or 1) == 1 and inv_item then
        local item_cls = GetClassByType("Item", inv_item.type)
        local class_name = item_cls and item_cls.ClassName
        exhibit = Archeology_helper_relic_slot_of(class_name)
        -- 判断材料は 1 回ずつだけ出す(インベントリの全スロットぶん通るので)
        if exhibit and not g.aoh_relic_logged then
            g.aoh_relic_logged = true
            g.vlog("archeology_helper: 遺物に番号を付けた 例 %s → %d", class_name, exhibit.index)
        elseif not exhibit and type(class_name) == "string" and string.sub(class_name, 1, 4) == "Arc_" and
            not g.aoh_relic_miss_logged then
            g.aoh_relic_miss_logged = true
            g.vlog("archeology_helper: Arc_ だが展示スロットが引けなかった 例 %s", class_name)
        end
    end
    if not exhibit then
        if GET_CHILD(slot, name) then
            DESTROY_CHILD_BYNAME(slot, name)
        end
        return
    end
    local label = slot:CreateOrGetControl("richtext", name, 0, 0, 16, 16)
    AUTO_CAST(label)
    label:SetGravity(ui.RIGHT, ui.TOP)
    label:SetMargin(0, 2, 4, 0)
    label:EnableHitTest(0) -- 掴む・右クリックはスロットへ通す
    label:SetText(string.format("{ol}{s16}{#%s}%d", exhibit.color, exhibit.index))
    g.aoh_inventory_touched = true
end

-- 素の INV_ICON_SETINFO(インベントリの 1 スロットにアイテムを置く)の後に番号を足す。
-- インベントリを描くたびに全スロットぶん通るので、遺物でなければ ClassName の先頭だけ見て抜ける。
-- こちらで転ぶとインベントリの描画ごと止まるので pcall で包む。
function Archeology_helper_INV_ICON_SETINFO(frame, slot, inv_item, custom_func, script_arg, count)
    local results = {g.FUNCS["INV_ICON_SETINFO"](frame, slot, inv_item, custom_func, script_arg, count)}
    if not Archeology_helper_active() then
        return table.unpack(results)
    end
    local ok, err = pcall(Archeology_helper_relic_label, slot, inv_item)
    if not ok and not g.aoh_relic_label_err then
        g.aoh_relic_label_err = true -- スロットの数だけ出ないよう 1 回だけ
        g.vlog("{#FF6347}archeology_helper: 遺物のスロット番号を出せなかった %s{/}", tostring(err))
    end
    return table.unpack(results)
end
-- ===== インベントリの遺物の並べ替え(見た目だけ) =====
-- 素のインベントリはアイテムを「インベントリ上の位置(invIndex)」のスロットへ置く。位置そのものを
-- 入れ替えるにはサーバーへ 1 つずつ送るしかないので、**表示だけ**並べ替える。素の検索中と同じく、
-- 遺物の入る slotset のスロットへ並べ替えた順に置き直す。素の 1 個ずつの更新は GUID でスロットを探すが、
-- 元の区切りの中しか探さないので、セクションへ移した遺物は Archeology_helper_relic_item_update で描き直す。
-- 素がインベントリを組み立て直したり 1 個だけ足し引きしたりすると位置どおりに戻るので、そのたびに並べ直す。

-- 遺物 1 つの並びの鍵。rank = 等級(高いほど前)、opts = 効果の並び(1 つ目から)
function Archeology_helper_relic_sort_key(inv_item)
    local obj = GetIES(inv_item:GetObject())
    local class_name = TryGetProp(obj, "ClassName", "None")
    local key = {
        rank = 0,
        opts = {},
        name = class_name,
        index = inv_item.invIndex
    }
    if string.sub(class_name, 1, 4) ~= "Arc_" then
        return key
    end
    key.rank = g.aoh.relic_rarity_rank[string.sub(class_name, -2)] or 0
    -- 効果は接頭(Arc_Prefix)→ 接尾(Arc_Suffix)の順。素のツールチップと同じ並び
    local metas = {}
    for _, prop in ipairs({"Arc_Prefix", "Arc_Suffix"}) do
        local meta = TryGetProp(obj, prop, "None")
        if meta ~= nil and meta ~= "" and meta ~= "None" then
            metas[#metas + 1] = meta
        end
    end
    if #metas == 0 or not GET_ARCHEOLOGY_OPTION_INFO then
        return key
    end
    for _, opt in ipairs(GET_ARCHEOLOGY_OPTION_INFO(table.concat(metas, ",")) or {}) do
        local category = GET_ARCHEOLOGY_EXHIBITION_EFFECT_CATEGORY_KEY and
                             GET_ARCHEOLOGY_EXHIBITION_EFFECT_CATEGORY_KEY(opt.tag) or "Combat"
        key.opts[#key.opts + 1] = {
            category = g.aoh.relic_category_weight[category] or 99,
            weight = g.aoh.relic_effect_weight[opt.tag] or 999,
            tag = tostring(opt.tag),
            value = tonumber(opt.value) or 0
        }
    end
    return key
end

-- 等級の高い順 → 効果(1 つ目から順に、種類 → 数値の高い順) → ClassName → 位置
function Archeology_helper_relic_sort_less(a, b)
    if a.rank ~= b.rank then
        return a.rank > b.rank
    end
    for i = 1, math.max(#a.opts, #b.opts) do
        local x, y = a.opts[i], b.opts[i]
        if not x or not y then
            return x ~= nil -- 効果の多いほうを前へ
        end
        if x.category ~= y.category then
            return x.category < y.category
        end
        if x.weight ~= y.weight then
            return x.weight < y.weight
        end
        if x.tag ~= y.tag then
            return x.tag < y.tag
        end
        if x.value ~= y.value then
            return x.value > y.value
        end
    end
    if a.name ~= b.name then
        return a.name < b.name
    end
    return a.index < b.index
end

-- インベントリのタブごとの tree。{ {type_str = "All", tree = ...}, ... }
function Archeology_helper_inventory_trees(inventory)
    local list = {}
    local group = inventory and GET_CHILD_RECURSIVELY(inventory, "inventoryGbox")
    if not group then
        return list
    end
    for _, type_str in ipairs(g_invenTypeStrList or {}) do
        local tree_box = GET_CHILD_RECURSIVELY(group, "treeGbox_" .. type_str)
        local tree = tree_box and GET_CHILD_RECURSIVELY(tree_box, "inventree_" .. type_str)
        if tree then
            list[#list + 1] = {
                type_str = type_str,
                tree = tree
            }
        end
    end
    return list
end

-- 並べ直しの依頼。組み立て直しや足し引きは続けて来るので、まとめて 1 回にする。
-- force = 中身が前回と同じでも置き直す(組み立て直しで区切りが作り直された・印が変わったとき)
function Archeology_helper_relic_sort_request(force)
    if not Archeology_helper_active() then
        return
    end
    if force then
        g.aoh_relic_force = true
    end
    -- 足し引きの結果が一覧へ反映されるのが遅れることがあるので、1.5 秒後にもう 1 回だけ並べ直す
    if not g.aoh_relic_followup_pending then
        g.aoh_relic_followup_pending = true
        ReserveScript("Archeology_helper_relic_followup()", 1.5)
    end
    if g.aoh_relic_sort_pending then
        return
    end
    g.aoh_relic_sort_pending = true
    ReserveScript("Archeology_helper_relic_update()", 0.3)
end

-- アイテムの増減(INV_ITEM_ADD は 4 つ目に位置、INV_ITEM_REMOVE は 3 つ目に GUID)。
-- 遺物と関係ないアイテムの増減では並べ直さない(拾う・使うたびに全部を作り直すとカクつく)
function Archeology_helper_relic_item_msg(frame, msg, arg_str, arg_num)
    if not Archeology_helper_active() then
        return
    end
    local relevant = false
    if msg == "INV_ITEM_ADD" then
        local base_cls = tonumber(arg_num) and GET_BASEID_CLS_BY_INVINDEX(tonumber(arg_num))
        relevant = base_cls ~= nil and base_cls.TreeGroup == "Archeology"
    else
        local char = g.aoh_settings[g.cid]
        relevant = (g.aoh_relic_laid_guids or {})[arg_str] ~= nil or
                       (char and type(char.relic_known) == "table" and char.relic_known[arg_str] ~= nil)
    end
    if relevant then
        Archeology_helper_relic_sort_request()
    end
end

-- 1 個ずつの更新(ITEM_PROP_UPDATE / INV_ITEM_CHANGE_COUNT / UPDATE_LOCK_STATE。3 つ目が GUID)。
-- 素(INV_GET_SLOT_BY_ITEMGUID)は元の「遺物」の区切りしか探さないので、セクション 2 / 3 / その他に
-- 置いた遺物はこちらで描き直す(INV_SLOT_UPDATE がロックの印も付け直す)
function Archeology_helper_relic_item_update(frame, msg, guid, lock_state)
    if not Archeology_helper_active() or type(guid) ~= "string" or not (g.aoh_relic_laid_guids or {})[guid] then
        return
    end
    local inventory = ui.GetFrame("inventory")
    local inv_item = session.GetInvItemByGuid(guid)
    if not inventory or not inv_item then
        return
    end
    for _, entry in ipairs(Archeology_helper_inventory_trees(inventory)) do
        for set_name in pairs(g.aoh_relic_section_sets or {}) do
            for _, k in ipairs({2, 3, 0}) do
                local slotset = GET_CHILD_RECURSIVELY(entry.tree, set_name .. "_aoh" .. k, "ui::CSlotSet")
                local slot = slotset and GET_SLOT_BY_ITEMID(slotset, guid)
                if slot then
                    INV_SLOT_UPDATE(inventory, inv_item, slot)
                    if msg == "UPDATE_LOCK_STATE" and tonumber(lock_state) then
                        -- ロックは一覧より先に届くことがあるので、素の _UPDATE_LOCK_STATE と同じく印を直接出し入れする
                        local lock = slot:CreateOrGetControlSet("inv_itemlock", "itemlock", 0, 0)
                        lock:SetGravity(ui.RIGHT, ui.TOP)
                        lock:ShowWindow(tonumber(lock_state))
                    end
                end
            end
        end
    end
end

function Archeology_helper_relic_followup()
    g.aoh_relic_followup_pending = nil
    if not g.aoh_relic_sort_pending then
        Archeology_helper_relic_update()
    end
end

-- 組み立て直し・足し引きの後の処理。新しく増えた遺物に NEW の印を付けてから、並べ替える。
-- ReserveScript から呼ばれるので、転んでもエラーが見えない。**1 つ転ぶと後ろが全部止まる**
-- (セクションが作られたまま空で残った。2026-10-12 の実機)ので、段ごとに pcall で包んでログへ出す
function Archeology_helper_relic_update()
    g.aoh_relic_sort_pending = nil
    local function step(label, func, ...)
        local ok, result = pcall(func, ...)
        if not ok then
            g.vlog("{#FF6347}archeology_helper: %s で失敗 %s{/}", label, tostring(result))
            return nil
        end
        return result
    end
    -- アイテムの一覧は 1 回だけ作り、NEW の印と並べ替えで使い回す
    session.BuildInvItemSortedList()
    local list = session.GetInvItemSortedList()
    local found_new = step("NEW の印", Archeology_helper_relic_detect_new, list)
    if found_new then
        g.aoh_relic_force = true -- 印が増えたので、中身が同じでも置き直す
    end
    if Archeology_helper_relic_layout_enabled() then
        step("遺物の並べ替え", Archeology_helper_relic_sort, list) -- 遺物のスロットを全部置き直すので、印もここで付く
    elseif found_new then
        step("描き直し", function()
            Archeology_helper_relic_refresh(true)
        end)
    end
    -- 祭壇を開いている間に素が組み立て直すと(OpenNodeAll で)カテゴリが全部開くので、畳み直す
    if g.aoh_exhibit_saved then
        step("アーキオロジーだけにする", Archeology_helper_exhibit_focus)
    end
end

-- 素のインベントリが表示するアイテムか(素の INVENTORY_TOTAL_LIST_GET と同じ条件:
-- MarketCategory が None でない・個数が 1 以上)。祭壇に展示した遺物は一覧に個数 0 で残ることがあり、
-- これを数えると展示した遺物がインベントリに出たままになった(2026-10-12 の実機)
function Archeology_helper_inv_item_shown(inv_item)
    if not inv_item or (inv_item.count or 0) <= 0 then
        return false
    end
    local obj = GetIES(inv_item:GetObject())
    return obj ~= nil and TryGetProp(obj, "MarketCategory", "None") ~= "None"
end

-- 新しくインベントリへ入った遺物を NEW にする。
-- 遺物はダンジョンの報酬として保管され、街へ戻ったときの精算でインベントリへ届く
-- (archeology_reward_vault)。精算のメッセージには GUID が無いので、**前に見た遺物の GUID の控え**
-- (キャラごとの relic_known)と比べて、無かったものを新しい遺物とする。
-- 控えが無い最初の 1 回は、今ある遺物を控えるだけで印は付けない(全部 NEW になってしまうので)。
function Archeology_helper_relic_detect_new(list)
    local char = g.aoh_settings[g.cid]
    if not char then
        return false
    end
    if not list then
        session.BuildInvItemSortedList()
        list = session.GetInvItemSortedList()
    end
    local now = {}
    for i = 0, list:size() - 1 do
        local inv_item = list:at(i)
        if Archeology_helper_inv_item_shown(inv_item) then
            local obj = GetIES(inv_item:GetObject())
            local class_name = TryGetProp(obj, "ClassName", "None")
            if string.sub(class_name, 1, 4) == "Arc_" and GetClass("archeology_exhibition_item", class_name) then
                now[inv_item:GetIESID()] = true
            end
        end
    end
    local known = char.relic_known
    local added = 0
    -- 祭壇を開いている間に入ったものは、展示から外して戻った遺物(戻るときに GUID が変わる)なので印を付けない
    local exhibition = ui.GetFrame("archeology_exhibition")
    local from_exhibition = exhibition ~= nil and exhibition:IsVisible() == 1
    if type(known) == "table" and (g.aoh_settings.relic_new or 1) == 1 and not from_exhibition then
        g.aoh_settings.relic_new_guids = g.aoh_settings.relic_new_guids or {}
        for guid in pairs(now) do
            if not known[guid] and not g.aoh_settings.relic_new_guids[guid] then
                g.aoh_settings.relic_new_guids[guid] = true
                added = added + 1
            end
        end
    end
    -- 控えに足す遺物(控えに無い = 初めて見た)。控えは消えた遺物も残すので、消えた側は
    -- このセッションで前に見たインベントリ(g.aoh_relic_prev_now)と比べてログにだけ出す
    local plus = {}
    if type(known) == "table" then
        for guid in pairs(now) do
            if not known[guid] then
                plus[#plus + 1] = guid
            end
        end
    end
    local changed = type(known) ~= "table" or #plus > 0
    local prev = g.aoh_relic_prev_now
    if prev then
        local appeared, gone = {}, {}
        for guid in pairs(now) do
            if not prev[guid] then
                appeared[#appeared + 1] = guid
            end
        end
        for guid in pairs(prev) do
            if not now[guid] then
                gone[#gone + 1] = guid
            end
        end
        if #appeared > 0 or #gone > 0 then
            g.vlog("archeology_helper: 遺物の増減 +%d [%s] -%d [%s] 祭壇=%s", #appeared, table.concat(appeared, " "),
                #gone, table.concat(gone, " "), tostring(from_exhibition))
        end
    end
    g.aoh_relic_prev_now = now
    -- 控えには、無くなった遺物も残す(倉庫・取引・郵便から同じ GUID で戻ったときに NEW にしないため)。
    -- 増え続けないよう、2000 件を超えたら今ある遺物だけに戻す
    if changed then
        local merged = now
        if type(known) == "table" then
            merged = {}
            local size = 0
            for guid in pairs(known) do
                merged[guid] = true
                size = size + 1
            end
            for guid in pairs(now) do
                if not merged[guid] then
                    merged[guid] = true
                    size = size + 1
                end
            end
            if size > 2000 then
                merged = now
            end
        end
        char.relic_known = merged
        Archeology_helper_save_settings()
    end
    if added > 0 then
        g.vlog("archeology_helper: 新しく入った遺物 %d 個に NEW の印を付けた", added)
    end
    return added > 0
end

-- 空いたスロットを素の INVENTORY_SLOTSET_INIT と同じ形へ戻す
function Archeology_helper_relic_clear_slot(slot)
    INIT_INVEN_SLOT(slot)
    slot:SetText(' ', 'count', ui.RIGHT, ui.BOTTOM, -2, 1)
    slot:ClearIcon()
    slot:SetFrontImage('None')
    DESTROY_CHILD_BYNAME(slot, "styleset_")
    DESTROY_CHILD_BYNAME(slot, "itemlock")
    DESTROY_CHILD_BYNAME(slot, "aoh_relic_slot")
    DESTROY_CHILD_BYNAME(slot, "aoh_relic_new")
    -- 前に置いていたアイテムの位置を指したままにしない(右クリックで使われないように)
    slot:SetEventScriptArgNumber(ui.RBUTTONDOWN, 0)
    slot:SetEventScriptArgNumber(ui.RBUTTONDBLCLICK, 0)
    slot:SetEventScriptArgNumber(ui.LBUTTONDOWN, 0)
end

-- 並べ替え・セクション分けのどちらかが ON なら置き直す(並べ替えが OFF なら元の位置の順のまま)
function Archeology_helper_relic_layout_enabled()
    return (g.aoh_settings.relic_sort or 1) == 1 or (g.aoh_settings.relic_section or 1) == 1
end

function Archeology_helper_relic_sort(list)
    g.aoh_relic_sort_pending = nil
    if not Archeology_helper_relic_layout_enabled() then
        return
    end
    local inventory = ui.GetFrame("inventory")
    if not inventory then
        return
    end
    -- 検索中は素が絞り込んだ結果を詰めて並べているので触らない
    local search = GET_CHILD_RECURSIVELY(inventory, "ItemSearch")
    if search and search:GetText() ~= "" then
        g.vlog("archeology_helper: 検索欄に「%s」があるので遺物を並べ替えない", tostring(search:GetText()))
        return
    end
    -- 遺物の入る slotset ごとに、そこへ入るアイテムを**全部**集める(遺物以外も落とさない)。
    -- 見るのはアーキオロジーの区分(inven_baseid の TreeGroup)だけ。区分は invIndex の 5000 ごとに決まるので控える
    if not list then
        session.BuildInvItemSortedList()
        list = session.GetInvItemSortedList()
    end
    local block_group = {}
    local sets = {}
    local has_relic = {}
    local hidden = 0
    -- 展示の出し入れの直後は、同じ遺物(GUID)が一覧に 2 回入っていることがある(2026-10-12 の実機で
    -- 展示しても遺物が残って見えた)ので、GUID で 1 つにまとめる
    local seen = {}
    local dup = {}
    for i = 0, list:size() - 1 do
        local inv_item = list:at(i)
        local shown = Archeology_helper_inv_item_shown(inv_item)
        if inv_item and not shown then
            hidden = hidden + 1
        end
        if shown then
            local guid = inv_item:GetIESID()
            if seen[guid] then
                dup[#dup + 1] = string.format("%s(%d/%d)", guid, seen[guid], inv_item.invIndex)
                shown = false
            else
                seen[guid] = inv_item.invIndex
            end
        end
        if shown then
            local block = math.floor((inv_item.invIndex - 1) / 5000)
            if block_group[block] == nil then
                local base_cls = GET_BASEID_CLS_BY_INVINDEX(inv_item.invIndex)
                block_group[block] = base_cls ~= nil and base_cls.TreeGroup == "Archeology"
            end
            shown = block_group[block]
        end
        if shown then
            -- ここでは軽いものだけ(ClassName と等級)。効果を引く並びの鍵は、置き直すと決まってから作る
            local set_name = GET_SLOTSET_NAME(inv_item.invIndex)
            local class_name = TryGetProp(GetIES(inv_item:GetObject()), "ClassName", "None")
            local rank = string.sub(class_name, 1, 4) == "Arc_" and
                             (g.aoh.relic_rarity_rank[string.sub(class_name, -2)] or 0) or 0
            sets[set_name] = sets[set_name] or {}
            table.insert(sets[set_name], {
                item = inv_item,
                name = class_name
            })
            if rank > 0 then
                has_relic[set_name] = true
            end
        end
    end
    if #dup > 0 then
        g.vlog("{#FF6347}archeology_helper: 一覧に同じアイテムが重なっていた %d 件 %s{/}", #dup, table.concat(dup, " "))
    end
    if g.aoh_relic_hidden ~= hidden then
        g.aoh_relic_hidden = hidden
        g.vlog("archeology_helper: 一覧にあるが表示しないアイテム(個数 0 など) %d 個", hidden)
    end
    local trees = Archeology_helper_inventory_trees(inventory)
    if #trees == 0 then
        return
    end
    local sectioned = (g.aoh_settings.relic_section or 1) == 1
    -- セクションを作った区切りは、遺物が 1 個も無くなっても並べ直す(古い中身が残らないように)
    if sectioned then
        for set_name in pairs(g.aoh_relic_section_sets or {}) do
            has_relic[set_name] = true
            sets[set_name] = sets[set_name] or {}
        end
    end
    -- 中身(GUID・個数)と設定が前回と同じなら置き直さない(1.5 秒後のもう 1 回など)
    local parts = {tostring(sectioned), tostring(g.aoh_settings.relic_sort or 1)}
    for set_name in pairs(has_relic) do
        for _, entry in ipairs(sets[set_name]) do
            parts[#parts + 1] = entry.item:GetIESID() .. ":" .. tostring(entry.item.count)
        end
    end
    table.sort(parts)
    local signature = table.concat(parts, ",")
    if not g.aoh_relic_force and signature == g.aoh_relic_signature then
        return
    end
    g.aoh_relic_force = nil
    g.aoh_relic_signature = signature
    g.aoh_inventory_touched = true
    g.aoh_relic_laid_guids = {}
    local sorted = (g.aoh_settings.relic_sort or 1) == 1
    for set_name in pairs(has_relic) do
        local entries = sets[set_name]
        for _, entry in ipairs(entries) do
            g.aoh_relic_laid_guids[entry.item:GetIESID()] = true
            -- 並べ替えが OFF なら効果は引かない(位置の順に並べるだけ)
            entry.sort_key = sorted and Archeology_helper_relic_sort_key(entry.item) or {
                rank = 0,
                opts = {},
                name = entry.name,
                index = entry.item.invIndex
            }
        end
        table.sort(entries, function(a, b)
            if not sorted then
                return a.sort_key.index < b.sort_key.index
            end
            return Archeology_helper_relic_sort_less(a.sort_key, b.sort_key)
        end)
        local placed = 0
        for _, tree_entry in ipairs(trees) do
            local tree = tree_entry.tree
            local slotset = GET_CHILD_RECURSIVELY(tree, set_name, "ui::CSlotSet")
            if slotset then
                AUTO_CAST(slotset)
                if sectioned then
                    Archeology_helper_relic_lay_sections(inventory, tree, set_name, entries)
                else
                    Archeology_helper_relic_fill_slotset(inventory, slotset, entries)
                end
                placed = placed + 1
            elseif sectioned and GET_CHILD_RECURSIVELY(tree, set_name .. "_aoh2", "ui::CSlotSet") then
                -- 元の区切りが無くても(遺物が全部無くなった)、足したセクションは空にする
                Archeology_helper_relic_lay_sections(inventory, tree, set_name, entries)
            end
        end
        -- 展示の出し入れで置き直しが効かない不具合を追うため、毎回出す(足し引きのときだけ通る経路)
        g.vlog("archeology_helper: 遺物を置き直した %s (%d 個 / %d か所)", set_name, #entries, placed)
        -- 素が遺物を 1 個抜いた(展示した)後は、元の「遺物」の区切りがどの tree にも見つからなくなり
        -- (0 か所)、足したセクションが古いまま残って、展示した遺物が出たままになった(2026-10-12 の実機)。
        -- そのときは組み立て直して、区切りごと作り直す。組み立て直しは並べ直しを頼む
        -- (Archeology_helper_INSERT_ITEM_TO_TREE)ので、見つからないままだと繰り返す。5 秒に 1 回まで
        -- 組み立て直しても見つからないときは繰り返さない(続けて 2 回で打ち切り、見つかったら数え直す)
        if placed > 0 then
            g.aoh_relic_rebuild_fail = 0
        elseif #entries > 0 then
            local now = imcTime.GetAppTime()
            g.aoh_relic_rebuild_fail = (g.aoh_relic_rebuild_fail or 0) + 1
            if g.aoh_relic_rebuild_fail > 2 then
                if g.aoh_relic_rebuild_fail == 3 then
                    g.vlog("{#FF6347}archeology_helper: 組み立て直しても %s が見つからないので諦める{/}", set_name)
                end
            elseif not g.aoh_relic_rebuild_at or now - g.aoh_relic_rebuild_at > 5.0 then
                g.aoh_relic_rebuild_at = now
                g.vlog("archeology_helper: %s が見つからないのでインベントリを組み立て直す", set_name)
                INVENTORY_TOTAL_LIST_GET(inventory)
            end
        end
    end
end
-- slotset のスロットへ entries の順にアイテムを置き、余ったスロットは空にする
function Archeology_helper_relic_fill_slotset(inventory, slotset, entries)
    while slotset:GetSlotCount() < #entries do
        slotset:ExpandRow(true)
    end
    for i = 0, slotset:GetSlotCount() - 1 do
        local slot = slotset:GetSlotByIndex(i)
        local entry = entries[i + 1]
        if entry then
            slot:ShowWindow(1)
            INV_SLOT_UPDATE(inventory, entry.item, slot)
        elseif slot:GetIcon() then
            Archeology_helper_relic_clear_slot(slot)
        end
    end
    slotset:MakeSelectionList()
end

-- ===== 遺物を展示スロットごとのセクションに分ける(見た目だけ) =====
-- 元の「遺物」の区切り(見出しの richtext + slotset)を「遺物 1スロット」として使い、2 / 3 / その他は
-- 素の MAKE_INVEN_SLOTSET / MAKE_INVEN_SLOTSET_NAME で足す(素の MAKE_INVEN_SLOTSET_AND_TITLE と同じ作り)。
-- 名前は「元の名前 + _aoh<番号>」。**tree は足した順に並べるだけ**(素の GET_SLOTSET_SORT_SCORE を広げても
-- 並びは変わらず、後から足すと「発掘材料」の下に付いた。2026-10-12 の実機)ので、素が組み立て直すときに
-- 元の区切りを作った直後(INSERT_ITEM_TO_TREE)で 2 / 3 / その他を足し、元の区切りのすぐ下に並べる。
-- 組み立て直し(tree:Clear)で消えるので、そのたびに作り直される。
-- 番号 0 は展示スロットに入らないもの(増幅用・ボスの鍵など)。
-- **元の区切りを空にして残す形は、空のスロットを隠しても行の高さが残り、大きな空白になった**(2026-10-12 の実機)
-- ので、どの区切りも中身の行数ぶんの高さへ作り直す
function Archeology_helper_relic_lay_sections(inventory, tree, set_name, entries)
    local base_name = string.sub(set_name, string.len("sset_") + 1)
    local tree_group = (g.aoh_relic_section_sets or {})[set_name]
    if type(tree_group) ~= "string" then
        local base_cls = GetClass("inven_baseid", base_name)
        tree_group = base_cls and base_cls.TreeGroup
    end
    if not tree_group then
        return
    end
    local treegroup = tree:FindByValue(tree_group)
    if tree:IsExist(treegroup) == 0 then
        return
    end
    local buckets = {
        [0] = {},
        [1] = {},
        [2] = {},
        [3] = {}
    }
    for _, entry in ipairs(entries) do
        local exhibit = Archeology_helper_relic_slot_of(entry.sort_key.name)
        table.insert(buckets[exhibit and exhibit.index or 0], entry)
    end
    local created = false
    for _, k in ipairs({1, 2, 3, 0}) do
        -- 1 は元の区切りをそのまま使う(見出しの文言だけ変える)
        local key = k == 1 and base_name or (base_name .. "_aoh" .. k)
        local section_name = "sset_" .. key
        local title_name = "ssettitle_" .. key
        local title_text = Archeology_helper_relic_section_title(k)
        local section = GET_CHILD_RECURSIVELY(tree, section_name, "ui::CSlotSet")
        if not section and #buckets[k] > 0 then
            -- 通常は素の組み立て直しの途中で作ってある(Archeology_helper_INSERT_ITEM_TO_TREE)。
            -- 無いのは設定を途中で ON にしたときなどで、ここで足すとカテゴリの末尾に付く
            section = Archeology_helper_relic_make_section(tree, treegroup, base_name, k)
            created = true
        end
        if section then
            AUTO_CAST(section)
            local title = GET_CHILD_RECURSIVELY(tree, title_name, "ui::CRichText")
            -- 畳んでいる区切りは畳んだまま。1 は素の区切り(素が畳んで見出しを btn_plus にする)、
            -- 足したセクションは作り直すと見出しも作り直されるので、こちらの控え(キャラごと)で見る
            local folded
            if k == 1 then
                folded = title and string.find(title:GetText(), "btn_plus", 1, true) ~= nil
            else
                folded = Archeology_helper_section_folded()[key] == true
            end
            -- 最後の祭壇を開いている間は、どのセクションも開いて出す(畳んだ状態は覚えたまま、閉じた後に戻る)。
            -- 展示の出し入れで並べ直すと、1 だけ開いて 2 / 3 が畳まれた状態になって揃わなかった(2026-10-12 の実機)
            local exhibition = ui.GetFrame("archeology_exhibition")
            local altar_open = exhibition ~= nil and exhibition:IsVisible() == 1
            local forced_key = tree:GetName() .. ":" .. key
            g.aoh_forced_open = g.aoh_forced_open or {}
            if folded and altar_open then
                folded = false
                -- 1 は素の区切りで、畳んだ状態を素が控えている(_invenCatOpenOption)。見た目だけ開くと、
                -- 祭壇で見出しを押したときに素の控えが逆向きに切り替わるので、素の控えも「開いている」に合わせ、
                -- 祭壇を閉じたら畳み直す(g.aoh_forced_open)
                if k == 1 then
                    INVENTORY_CATEGORY_OPENOPTION_CHANGE(tree, nil, key)
                    g.aoh_forced_open[forced_key] = true
                end
            elseif k == 1 and not altar_open and g.aoh_forced_open[forced_key] then
                g.aoh_forced_open[forced_key] = nil
                INVENTORY_CATEGORY_OPENOPTION_CHANGE(tree, nil, key)
                folded = true
            end
            Archeology_helper_relic_rebuild_slotset(inventory, section, buckets[k], folded)
            -- 空のセクションは見出しごと高さ 0 にして見せない(1 スロットは元の区切りなので消さない)
            if title and k ~= 1 then
                local title_height = title:GetUserIValue("AOH_HEIGHT")
                if #buckets[k] == 0 then
                    title:Resize(title:GetWidth(), 0)
                    title:ShowWindow(0)
                elseif title_height > 0 then
                    title:Resize(title:GetWidth(), title_height)
                    title:ShowWindow(1)
                end
            end
            if title then
                -- 素の SET_SLOTSETTITLE_COUNT と同じ書式。押すと畳む / 開く。
                -- 1 は素の区切りなので素の SET_INVENTORY_SLOTSET_OPEN。足したセクションは素の処理に渡さない
                -- (素は畳んだ状態を区切りの名前で覚え、その区切りが無い tree では INVENTORY_CATEGORY_OPENCHECK が
                --  途中で抜けて、他のカテゴリの畳み状態まで戻らなくなる)
                title:SetText(string.format("{img %s 20 20} %s (%d)", folded and "btn_plus" or "btn_minus",
                    title_text, #buckets[k]))
                title:SetEventScript(ui.LBUTTONUP, k == 1 and "Archeology_helper_section1_toggle" or
                    "Archeology_helper_section_toggle")
                title:SetEventScript(ui.DROP, "INVENTORY_ON_DROP")
                title:SetEventScriptArgString(ui.LBUTTONUP, key)
            end
        end
    end
    g.aoh_relic_section_sets = g.aoh_relic_section_sets or {}
    g.aoh_relic_section_sets[set_name] = tree_group
    if created then
        -- 素の INVENTORY_TOTAL_LIST_GET の締めと同じ。足した区切りを開き、利用者が畳んだカテゴリは畳み直す
        tree:OpenNodeAll()
        INVENTORY_CATEGORY_OPENCHECK(inventory, tree)
    end
    tree:InvalidateTree()
    -- 数が変わったときだけ出す(足し引きのたびに通るので)
    local counts = string.format("%s 1=%d 2=%d 3=%d その他=%d 作った=%s", tree:GetName(), #buckets[1], #buckets[2],
        #buckets[3], #buckets[0], tostring(created))
    g.aoh_relic_section_counts = g.aoh_relic_section_counts or {}
    if g.aoh_relic_section_counts[tree:GetName()] ~= counts then
        g.aoh_relic_section_counts[tree:GetName()] = counts
        g.vlog("archeology_helper: 遺物をセクションに分けた %s", counts)
    end
end

-- セクション k の見出しの文言(0 = その他)
function Archeology_helper_relic_section_title(k)
    local is_jp = g.lang == "Japanese"
    if k == 0 then
        return is_jp and "遺物 その他" or "Relics - Other"
    end
    return is_jp and string.format("遺物 %dスロット", k) or string.format("Relics - Slot %d", k)
end

-- 1 スロット(素の区切り)の見出しを押したとき。素の SET_INVENTORY_SLOTSET_OPEN をそのまま呼ぶが、
-- 祭壇で開いて出していた区切りなら、利用者が自分で切り替えたので「祭壇を閉じたら畳み直す」をやめる
function Archeology_helper_section1_toggle(parent, ctrl, key, num)
    if g.aoh_forced_open and parent then
        g.aoh_forced_open[parent:GetName() .. ":" .. tostring(key)] = nil
    end
    return SET_INVENTORY_SLOTSET_OPEN(parent, ctrl, key, num)
end

-- 足したセクションの見出しを押したときに畳む / 開く。素の SET_INVENTORY_SLOTSET_OPEN と同じく
-- 高さを 0 にして控えた高さへ戻すが、畳んだ状態は素の控え(_invenCatOpenOption)へ書かない
function Archeology_helper_section_toggle(parent, ctrl, key)
    local slotset = GET_CHILD_RECURSIVELY(parent, "sset_" .. tostring(key))
    if not slotset or not ctrl then
        return
    end
    local text = ctrl:GetText()
    local folded = Archeology_helper_section_folded()
    if slotset:GetHeight() ~= 0 then
        slotset:SetUserValue("width", slotset:GetWidth())
        slotset:SetUserValue("height", slotset:GetHeight())
        slotset:Resize(0, 0)
        ctrl:SetText((string.gsub(text, "btn_minus", "btn_plus")))
        folded[tostring(key)] = true
    else
        slotset:Resize(slotset:GetUserIValue("width"), slotset:GetUserIValue("height"))
        ctrl:SetText((string.gsub(text, "btn_plus", "btn_minus")))
        folded[tostring(key)] = nil
    end
end

-- 足したセクションの畳んだ状態。key = 区切りの名前から sset_ を除いたもの。
-- 素の区切り(1 スロット)と揃えて、覚えるのはこのセッションの間だけ(ログインし直すと開く)。
-- 保存すると、ログインし直した後に 1 だけ開いて 2 / 3 が畳まれたままになり、揃わなかった
function Archeology_helper_section_folded()
    g.aoh_section_folded = g.aoh_section_folded or {}
    return g.aoh_section_folded
end

-- セクション k(2 / 3 / 0)の見出しと slotset を作り、treegroup の末尾へ足す
function Archeology_helper_relic_make_section(tree, treegroup, base_name, k)
    local key = base_name .. "_aoh" .. k
    local title = MAKE_INVEN_SLOTSET_NAME(tree, "ssettitle_" .. key, Archeology_helper_relic_section_title(k))
    -- 空のときに高さ 0 へ畳むので、戻す高さを控える。中身を置くまでは畳んでおく
    -- (検索中は並べ直さないので、空の見出しだけが出てしまう)
    title:SetUserValue("AOH_HEIGHT", title:GetHeight())
    title:Resize(title:GetWidth(), 0)
    title:ShowWindow(0)
    local new_section = MAKE_INVEN_SLOTSET(tree, "sset_" .. key)
    tree:Add(treegroup, title, "ssettitle_" .. key)
    local handle = tree:Add(treegroup, new_section, "sset_" .. key)
    local node = tree:GetNodeByTreeItem(handle)
    if node then
        node:SetUserValue("IS_ITEM_SLOTSET", 1)
    end
    return GET_CHILD_RECURSIVELY(tree, "sset_" .. key, "ui::CSlotSet")
end

-- 区切りのスロットを作り直して items を詰めて置き、高さを中身の行数ぶんにする。
-- 素が検索中に行うのと同じく、RemoveAllChild の後に ExpandRow で行を足す
function Archeology_helper_relic_rebuild_slotset(inventory, slotset, items, folded)
    slotset:RemoveAllChild()
    while slotset:GetSlotCount() < #items do
        slotset:ExpandRow(true)
    end
    local slot_height = 0
    for i = 0, slotset:GetSlotCount() - 1 do
        local slot = slotset:GetSlotByIndex(i)
        INIT_INVEN_SLOT(slot)
        slot:SetText(' ', 'count', ui.RIGHT, ui.BOTTOM, -2, 1)
        slot_height = slot:GetHeight()
        local entry = items[i + 1]
        if entry then
            slot:ShowWindow(1)
            INV_SLOT_UPDATE(inventory, entry.item, slot)
        else
            slot:ShowWindow(0)
        end
    end
    slotset:MakeSelectionList()
    -- 1 行の数とスロットの大きさは素の MAKE_INVEN_SLOTSET と同じ設定(TREE_COL_COUNT / TREE_SLOT_SIZE)。
    -- 幅は今の幅から取らない(畳んで幅 0 になっている区切りだと 0 を控え、開いても中身が見えなくなる)
    local cols = math.max(1, tonumber(inventory:GetUserConfig("TREE_COL_COUNT")) or 1)
    local slot_size = tonumber(inventory:GetUserConfig("TREE_SLOT_SIZE")) or slot_height
    if slot_height <= 0 then
        slot_height = slot_size
    end
    local width = cols * slot_size
    local height = math.ceil(#items / cols) * slot_height
    if folded then
        -- 畳んだまま。開いたときに戻る大きさだけ今の中身に合わせる(素は "width" / "height" に控えた大きさへ戻す)
        slotset:SetUserValue("width", width)
        slotset:SetUserValue("height", height)
        slotset:Resize(0, 0)
    else
        slotset:Resize(width, height)
    end
end

-- 素の INSERT_ITEM_TO_TREE。素はスロットを位置(invIndex)ではなく区切りの個数で取り、足りなければ自分で
-- 行を増やす(素の `cap == ""` の分岐は、cap が素のどこでも代入されないグローバルなので通らない)。
-- そのため、こちらで詰めて行を減らした区切りへ足されても落ちない。増えた行は 0.3 秒後の並べ直しで詰め直す
function Archeology_helper_INSERT_ITEM_TO_TREE(frame, tree, inv_item, item_cls, baseidcls)
    if not Archeology_helper_active() then
        return g.FUNCS["INSERT_ITEM_TO_TREE"](frame, tree, inv_item, item_cls, baseidcls)
    end
    -- 素がこの呼び出しで元の「遺物」の区切りを初めて作るなら、その直後に 2 / 3 / その他を足して
    -- すぐ下に並べる(後の区切り「遺物管理」などは、この後に素が足すので下に来る)
    -- 元の「遺物」の区切りがまだ無い = 素がインベントリを組み立て直している途中。並べ直しもここで頼む。
    -- (INVENTORY_TOTAL_LIST_GET の後のメッセージでは、Mini Addons の置換フックと掛ける順番しだいで
    --  届かなくなり、マップを移った後に並べ直されなかった。2026-10-12 の実機)
    -- 区切りの名前は素の INSERT_ITEM_TO_TREE と同じく GET_SLOTSET_NAME から取る(MergedTreeTitle が付くと
    -- ClassName ではなくそちらが名前になる)
    local first_relic = false
    local set_name = nil
    if baseidcls and baseidcls.ClassName == "Archeology_ArcRelic" then
        local ok, exists = pcall(function()
            set_name = GET_SLOTSET_NAME(inv_item.invIndex)
            return GET_CHILD_RECURSIVELY(tree, set_name, "ui::CSlotSet") ~= nil
        end)
        first_relic = ok and not exists and set_name ~= nil
    end
    local make_sections = first_relic and (g.aoh_settings.relic_section or 1) == 1
    if first_relic then
        Archeology_helper_relic_sort_request(true)
    end
    local results = {g.FUNCS["INSERT_ITEM_TO_TREE"](frame, tree, inv_item, item_cls, baseidcls)}
    if make_sections then
        local ok, err = pcall(function()
            local treegroup = tree:FindByValue(baseidcls.TreeGroup)
            local key = string.sub(set_name, string.len("sset_") + 1)
            for _, k in ipairs({2, 3, 0}) do
                Archeology_helper_relic_make_section(tree, treegroup, key, k)
            end
            -- 区切りの名前 → カテゴリ(TreeGroup)。lay_sections がカテゴリを引くのに使う
            g.aoh_relic_section_sets = g.aoh_relic_section_sets or {}
            g.aoh_relic_section_sets[set_name] = baseidcls.TreeGroup
        end)
        if not ok then
            g.vlog("{#FF6347}archeology_helper: 遺物のセクションを作れなかった %s{/}", tostring(err))
        end
    end
    return table.unpack(results)
end

-- ===== 遺物のツールチップの効果を折り返す =====
-- 素の DRAW_ARCHEOLOGY_OPTIONS_TOOLTIP は効果を 1 行ずつ controlset(archeology_tooltip_option_row)に
-- 入れるが、折り返さないので長い効果(「探査ポータルクリア時、色褪せた記録の破片の追加獲得…」など)が
-- ツールチップの端で切れる。素の旧版(DRAW_ARCHEOLOGY_LEGACY_OPTIONS_TOOLTIP の前身)は SetTextFixWidth(1) で
-- 折り返していたので、素が描いた後に同じく折り返し、行を詰め直して、増えた高さを返り値の ypos に足す
-- (素の ITEM_TOOLTIP_ARCHEOLOGY が返り値でツールチップの高さを決める)
function Archeology_helper_DRAW_ARCHEOLOGY_OPTIONS_TOOLTIP(tooltipframe, invitem, ypos, mainframename)
    local end_y = g.FUNCS["DRAW_ARCHEOLOGY_OPTIONS_TOOLTIP"](tooltipframe, invitem, ypos, mainframename)
    if not Archeology_helper_active() or type(end_y) ~= "number" then
        return end_y
    end
    local ok, result = pcall(function()
        local gbox = GET_CHILD(tooltipframe, mainframename, "ui::CGroupBox")
        if not gbox then
            return end_y
        end
        local y = nil
        local old_bottom = nil
        -- 名前は使い回されるので、今回描いた範囲(ypos 〜 end_y)にある行だけを見る
        for i = 1, 20 do
            local row = GET_CHILD(gbox, "archeology_option_text_" .. i)
            if row and row:GetY() >= ypos and row:GetY() < end_y then
                local text = GET_CHILD_RECURSIVELY(row, "text")
                if text then
                    AUTO_CAST(text)
                    y = y or row:GetY()
                    old_bottom = row:GetY() + row:GetHeight()
                    local width = gbox:GetWidth() - row:GetX() - text:GetX() - 10
                    row:Resize(gbox:GetWidth() - row:GetX() - 10, row:GetHeight())
                    text:SetTextFixWidth(1)
                    text:SetMaxWidth(width)
                    text:Resize(width, text:GetHeight())
                    text:SetText(text:GetText()) -- 折り返しの幅で測り直す
                    local height = math.max(row:GetHeight(), text:GetY() + text:GetHeight() + 2)
                    row:SetOffset(row:GetX(), y)
                    row:Resize(row:GetWidth(), height)
                    y = y + height
                end
            end
        end
        if not y or not old_bottom then
            return end_y
        end
        local delta = y - old_bottom
        -- 今回の範囲で行より下にある他の部品(区切り線など)も、伸びたぶんだけ下げる
        if delta ~= 0 then
            for i = 0, gbox:GetChildCount() - 1 do
                local child = gbox:GetChildByIndex(i)
                if child and not string.find(child:GetName(), "archeology_option_text_", 1, true) and
                    child:GetY() >= old_bottom and child:GetY() < end_y then
                    child:SetOffset(child:GetX(), child:GetY() + delta)
                end
            end
        end
        return end_y + delta
    end)
    if not ok then
        g.vlog("{#FF6347}archeology_helper: 遺物のツールチップを折り返せなかった %s{/}", tostring(result))
        return end_y
    end
    return result
end

-- ===== 探査ポータルの入場画面を「最近の設定」で開く =====
-- 素の入場画面(archeology_dungeon_enter)は、入場するたびに難易度と入れたアイテムを config の
-- ARCHEOLOGY_DUNGEON_ENTER_LAST_SETTING に控え、「最近の設定」ボタン(素の ARCH_DENTER_APPLY_LAST)で戻せる。
-- 開いた直後にそのボタンと同じ処理を呼ぶ。控えが無いと素が「最近の設定がありません」と出すので、
-- 控えがあるときだけ呼ぶ(アイテムが足りないときの「一部だけ入れた」の通知は素のまま出る)
function Archeology_helper_ARCH_DENTER_ON_OPEN(frame, msg, arg_str, arg_num)
    local results = {g.FUNCS["ARCH_DENTER_ON_OPEN"](frame, msg, arg_str, arg_num)}
    -- 素はこの中でインベントリを開くので、祭壇と同じくアーキオロジーだけにする
    if Archeology_helper_active() and (g.aoh_settings.exhibit_focus or 1) == 1 then
        ReserveScript("Archeology_helper_exhibit_focus()", 0.3)
    end
    if not Archeology_helper_active() or (g.aoh_settings.denter_last or 1) ~= 1 then
        return table.unpack(results)
    end
    local ok, err = pcall(function()
        local saved = config.GetConfig("ARCHEOLOGY_DUNGEON_ENTER_LAST_SETTING", "")
        g.vlog("archeology_helper: 探査ポータルの入場画面を開いた 最近の設定=%s", tostring(saved))
        if saved == nil or saved == "" or saved == "None" then
            return
        end
        -- 素はボタンの親から GetTopParentFrame で入場画面を引くので、入場画面そのものを渡せばよい
        ARCH_DENTER_APPLY_LAST(frame, nil)
    end)
    if not ok then
        g.vlog("{#FF6347}archeology_helper: 最近の設定を入れられなかった %s{/}", tostring(err))
    end
    return table.unpack(results)
end

-- ===== 遺物分解の「所持 / 獲得予定 / 分解後」を正しく出す =====
-- 素の ARCH_DECOMP_REWARD_SUMMARY は窓の userconfig(REWARD_LINE_FORMAT = "%s %s개")を string.format に渡すが、
-- 日本語版ではこの値が**翻訳辞書の ID のまま**返るので %s が埋まらず、表示のときに訳されて
-- 「%s %s個」がそのまま出る(2026-10-12 の実機)。素を呼ぶ前に、窓の userconfig を
-- dictionary.ReplaceDicIDInCompStr で訳した文に置き換えておく(素の処理はそのまま)。
-- 確認の窓の CONFIRM_REWARDS も同じ作りなので一緒に直す
function Archeology_helper_ARCH_DECOMP_REWARD_SUMMARY(frame, rewards, mode)
    if Archeology_helper_active() and frame and frame:GetUserValue("AOH_CONFIG_FIXED") ~= "YES" then
        local ok, err = pcall(function()
            for _, key in ipairs({"REWARD_LINE_FORMAT", "REWARD_LINE_SEPARATOR", "CONFIRM_REWARDS"}) do
                local raw = frame:GetUserConfig(key)
                local text = dictionary.ReplaceDicIDInCompStr(raw)
                if type(text) == "string" and text ~= "" and text ~= raw then
                    frame:SetUserConfig(key, text)
                    g.vlog("archeology_helper: 遺物分解の %s を訳した文へ置き換えた %s → %s", key, tostring(raw), text)
                else
                    g.vlog("archeology_helper: 遺物分解の %s は置き換えなし(%s)", key, tostring(raw))
                end
            end
            frame:SetUserValue("AOH_CONFIG_FIXED", "YES")
        end)
        if not ok then
            g.vlog("{#FF6347}archeology_helper: 遺物分解の書式を直せなかった %s{/}", tostring(err))
        end
    end
    return g.FUNCS["ARCH_DECOMP_REWARD_SUMMARY"](frame, rewards, mode)
end

-- 探査ポータルの入場画面を閉じたとき(素の ARCH_DENTER_CLOSE_UI。× / ESC / 入場 / ポータルが消えたとき)
function Archeology_helper_ARCH_DENTER_CLOSE_UI(keep_confirm)
    local results = {g.FUNCS["ARCH_DENTER_CLOSE_UI"](keep_confirm)}
    local ok, err = pcall(Archeology_helper_exhibit_unfocus)
    if not ok then
        g.vlog("{#FF6347}archeology_helper: インベントリを元に戻せなかった %s{/}", tostring(err))
    end
    return table.unpack(results)
end

-- アーキオロジーだけにする窓(最後の祭壇か、探査ポータルの入場画面)が開いているか
function Archeology_helper_focus_window_open()
    for _, name in ipairs({"archeology_exhibition", "archeology_dungeon_enter"}) do
        local frame = ui.GetFrame(name)
        if frame and frame:IsVisible() == 1 then
            return true
        end
    end
    return false
end

-- ===== 最後の祭壇・探査ポータルの入場画面を開いている間は、インベントリをアーキオロジーだけにする =====
-- インベントリに「アーキオロジー」のタブは無く、アーキオロジーの区分は「その他」タブの中にある
-- (inven_baseid の InvenTabName = Etc)。そこで祭壇を開いたら「その他」タブへ切り替え、
-- アーキオロジー以外のカテゴリを畳む。閉じたら、切り替える前のタブと、こちらが畳んだカテゴリを戻す。
-- 畳む・開くは素と同じ tree:OpenNode(node, 開く?, true)。
function Archeology_helper_ARCHEOLOGY_EXHIBITION_OPEN(frame)
    local results = {g.FUNCS["ARCHEOLOGY_EXHIBITION_OPEN"](frame)}
    if Archeology_helper_active() and (g.aoh_settings.exhibit_focus or 1) == 1 then
        -- 素はこの中でインベントリを開くので、開き終わってから切り替える
        ReserveScript("Archeology_helper_exhibit_focus()", 0.3)
    end
    -- 祭壇を開いている間はセクションをどれも開いて出すので、開き終わってから置き直す。
    -- 素がインベントリを開いた時点ではまだ祭壇が見えておらず、畳んだまま並べてしまうことがあった
    Archeology_helper_relic_sort_request(true)
    return table.unpack(results)
end

function Archeology_helper_ARCHEOLOGY_EXHIBITION_CLOSE(frame)
    local results = {g.FUNCS["ARCHEOLOGY_EXHIBITION_CLOSE"](frame)}
    local ok, err = pcall(Archeology_helper_exhibit_unfocus)
    if not ok then
        g.vlog("{#FF6347}archeology_helper: インベントリを元に戻せなかった %s{/}", tostring(err))
    end
    -- 閉じたら、利用者が畳んだセクションを畳み直す
    Archeology_helper_relic_sort_request(true)
    return table.unpack(results)
end

-- 「その他」タブの tree(アーキオロジーの区分が入るタブ)
function Archeology_helper_exhibit_tree(inventory)
    for _, entry in ipairs(Archeology_helper_inventory_trees(inventory)) do
        if entry.type_str == "Etc" then
            return entry.tree
        end
    end
    return nil
end

function Archeology_helper_exhibit_focus()
    local inventory = ui.GetFrame("inventory")
    if not Archeology_helper_focus_window_open() or not inventory or inventory:IsVisible() == 0 then
        return
    end
    local tab = GET_CHILD_RECURSIVELY(inventory, "inventype_Tab")
    local tree = Archeology_helper_exhibit_tree(inventory)
    if not tab or not tree then
        return
    end
    AUTO_CAST(tab)
    AUTO_CAST(tree)
    local etc_index = nil
    for i, type_str in ipairs(g_invenTypeStrList or {}) do
        if type_str == "Etc" then
            etc_index = i - 1
        end
    end
    if not etc_index then
        return
    end
    -- 戻す先は最初に切り替えたときだけ控える(組み立て直しの後に畳み直すときは控え直さない)
    if not g.aoh_exhibit_saved then
        g.aoh_exhibit_saved = {
            tab = tab:GetSelectItemIndex(),
            closed = {}
        }
    end
    -- 既に「その他」なら選び直さない(選び直すと素が組み立て直し、それを受けてまたここへ来る)
    if tab:GetSelectItemIndex() ~= etc_index then
        tab:SelectTab(etc_index)
    end
    local closed = 0
    for i = 1, ui.inventory.GetInvenGroupNameCount() do
        local group_name = ui.inventory.GetInvenGroupNameByIndex(i - 1)
        local treegroup = tree:FindByValue(group_name)
        local node = treegroup and tree:IsExist(treegroup) == 1 and tree:GetNodeByTreeItem(treegroup)
        if node then
            if group_name == "Archeology" then
                tree:OpenNode(node, true, true)
            elseif node:GetIsOpen() then
                tree:OpenNode(node, false, true)
                g.aoh_exhibit_saved.closed[group_name] = true
                closed = closed + 1
            end
        end
    end
    g.vlog("archeology_helper: 祭壇か入場画面を開いたのでインベントリをアーキオロジーだけにした(タブ %d → %d、畳んだカテゴリ %d)",
        g.aoh_exhibit_saved.tab, etc_index, closed)
end

function Archeology_helper_exhibit_unfocus()
    local saved = g.aoh_exhibit_saved
    g.aoh_exhibit_saved = nil
    if not saved then
        return
    end
    local inventory = ui.GetFrame("inventory")
    if not inventory then
        return
    end
    local tree = Archeology_helper_exhibit_tree(inventory)
    if tree then
        AUTO_CAST(tree)
        for group_name in pairs(saved.closed) do
            local treegroup = tree:FindByValue(group_name)
            local node = treegroup and tree:IsExist(treegroup) == 1 and tree:GetNodeByTreeItem(treegroup)
            if node then
                tree:OpenNode(node, true, true)
            end
        end
    end
    local tab = GET_CHILD_RECURSIVELY(inventory, "inventype_Tab")
    if tab then
        AUTO_CAST(tab)
        tab:SelectTab(saved.tab)
    end
    g.vlog("archeology_helper: 祭壇か入場画面を閉じたのでインベントリを戻した(タブ %d)", saved.tab)
end
-- archeology_helper ここまで

