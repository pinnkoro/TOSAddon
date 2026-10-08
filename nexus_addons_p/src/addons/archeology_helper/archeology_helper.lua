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
    marker_ver = 2
}

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
        return
    end
    Archeology_helper_start()
    g.setup_hook_and_event(g.addon, "TARGETSPACE_PRECHECK", "Archeology_helper_TARGETSPACE_PRECHECK", true)
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

function Archeology_helper_mob_display_setting(frame, ctrl)
    g.aoh_settings.mob_display = ctrl:IsChecked()
    Archeology_helper_save_settings()
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
        map_info.get_count = (map_info.get_count or 0) + 1
        local is_all_complete = true
        for _, map in ipairs(Archeology_helper_active_maps()) do
            if not Archeology_helper_is_map_done(map) then
                is_all_complete = false
                break
            end
        end
        g.vlog("archeology_helper: %s の地点を掘った (%d/%d) 全マップ完了=%s", map_name, map_info.get_count,
            Archeology_helper_point_count(), tostring(is_all_complete))
        if is_all_complete then
            g.aoh_settings.is_archeology = false
            g.aoh_settings.count = 0
            g.aoh_settings.map_info = {}
            ui.SysMsg(g.lang == "Japanese" and "全てのMAPの発掘が完了しました" or "Archeology completed for all maps")
        end
        Archeology_helper_save_settings()
        Archeology_helper_frame_init()
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
    g.vlog("archeology_helper: ARCHEOLOGY_MISSION_ACCEPT_RESULT arg_str=%s arg_num=%s", tostring(arg_str),
        tostring(arg_num))
    if arg_str ~= "SUCCESS" then
        return
    end
    g.aoh_settings.count = 0
    g.aoh_settings.is_archeology = true
    g.aoh_settings.map_info = {}
    Archeology_helper_save_settings()
    g.aoh_display = 0
    ui.DestroyFrame(addon_name_lower .. "au_map")
    -- 対象マップはアカウントのプロパティに後から入るので、少し待ってから描く
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    _nexus_addons_p:RunUpdateScript("Archeology_helper_frame_init", 1.0)
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
                                "{ol}依頼の NPC が居るクラペダへ戻ります{nl}トークンワープは使いません(クエストワープ / ワープスクロール){nl}使うクエストは設定で選べます" or
                                "{ol}Return to Klaipeda, where the mission NPC is{nl}Does not use token warp (quest warp / warp scroll){nl}Choose the quest in settings")
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

function Archeology_helper_go_home()
    if session.GetMapName() == g.aoh.home_map then
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

function Archeology_helper_home_item_setting(frame, ctrl)
    g.aoh_settings.home_item = ctrl:IsChecked()
    Archeology_helper_save_settings()
end

function Archeology_helper_setting_frame(au_map, display)
    local setting = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "archeology_helper_setting", 0, 0, 0, 0)
    setting:SetPos(1220, 100)
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
    local home_item = gbox:CreateOrGetControl('checkbox', "home_item", 10, 115, 30, 30)
    AUTO_CAST(home_item)
    home_item:SetCheck(g.aoh_settings.home_item or 1)
    home_item:SetText(g.lang == "Japanese" and
                          "{ol}クエストワープが使えないときはクラペダ ワープスクロールを使う" or
                          "{ol}Use a Klaipeda warp scroll when no quest warp is available")
    home_item:SetEventScript(ui.LBUTTONUP, "Archeology_helper_home_item_setting")
    local mob_display = gbox:CreateOrGetControl('checkbox', "mob_display", 10, 150, 30, 30)
    AUTO_CAST(mob_display)
    mob_display:SetCheck(g.aoh_settings.mob_display or 1)
    mob_display:SetText(g.lang == "Japanese" and "{ol}地図に敵を表示する" or "{ol}Show monsters on the map")
    mob_display:SetEventScript(ui.LBUTTONUP, "Archeology_helper_mob_display_setting")
    setting:Resize(math.max(sta_check:GetWidth(), home_item:GetWidth(), 330) + 50, 245)
    gbox:Resize(setting:GetWidth() - 20, 195)
    setting:ShowWindow(1)
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
-- archeology_helper ここまで
