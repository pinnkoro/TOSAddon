-- my_buffs_control ここから

-- 経過時間の物差し。imcTime が無い環境でも落ちないよう pcall で包み、取れなければ 0 を返す
-- (その場合は計測値が全部 0 になるだけで、本体の処理には影響しない)。
function My_buffs_control_now_ms()
    local ok, ms = pcall(function()
        return imcTime.GetAppTimeMS()
    end)
    if ok and type(ms) == "number" then
        return ms
    end
    return 0
end

function My_buffs_control_save_settings()
    local json_data = {
        lock = g.my_buffs_control_settings.lock,
        default_x = g.my_buffs_control_settings.default_x,
        default_y = g.my_buffs_control_settings.default_y,
        custom_x = g.my_buffs_control_settings.custom_x,
        custom_y = g.my_buffs_control_settings.custom_y,
        ver = g.my_buffs_control_settings.ver
    }
    g.save_json(g.my_buffs_control_path, json_data)
    -- .dat は毎回まるごと書き直す。件数は GetClassList("Buff") のデバフ以外ほぼ全件で、
    -- 実測 3816 行 / 40KB(2026-08 の JP クライアント)。**呼び出し元を増やすときは、
    -- 必ずこの計測を実機で見ること。** mini_addons のバフ一覧が json のままで 5 秒
    -- かかっていた前例がある(settings/storage.lua の Mini_addons_load_buffs のコメント)。
    -- あちらは 2806 キーの json.decode で、こちらは行単位の .dat なので桁が違うが、
    -- 「表を全件書き直す」形は同じなので、呼ぶ回数が増えれば同じ問題になる。
    local t0 = My_buffs_control_now_ms()
    local file = io.open(g.my_buffs_control_dat_path, "w")
    if file then
        local lines = {}
        for id, val in pairs(g.my_buffs_control_settings.buffs) do
            if val ~= nil then
                table.insert(lines, tostring(id) .. ":::" .. tostring(val))
            end
        end
        if #lines > 0 then
            file:write(table.concat(lines, "\n"))
        end
        file:close()
        g.vlog("my_buffs_control: .dat 書き出し %d 件 %dms", #lines, My_buffs_control_now_ms() - t0)
    else
        g.vlog("{#FF6347}my_buffs_control: .dat を開けない{/} (%s)", tostring(g.my_buffs_control_dat_path))
    end
end

function My_buffs_control_load_settings()
    g.my_buffs_control_path = string.format("../addons/%s/%s/my_buffs_control.json", addon_name_lower, g.active_id)
    g.my_buffs_control_dat_path = string.format("../addons/%s/%s/my_buffs_control.dat", addon_name_lower, g.active_id)
    g.my_buffs_control_old_path = string.format("../addons/%s/settings_2503.json", "my_buffs")
    local t0 = My_buffs_control_now_ms()
    local settings = g.load_json(g.my_buffs_control_path)
    local ver = 1.2
    local need_init = false
    if not settings or not settings.ver or settings.ver < ver then
        settings = {
            lock = true,
            default_x = 20,
            default_y = 130,
            custom_x = 20,
            custom_y = 130,
            ver = ver,
            buffs = {}
        }
        need_init = true
    end
    if not settings.buffs then
        settings.buffs = {}
    end
    if need_init then
        local old_settings = g.load_json(g.my_buffs_control_old_path)
        if old_settings and old_settings.buffs then
            for id, is_visible in pairs(old_settings.buffs) do
                settings.buffs[tostring(id)] = (is_visible == true) and 1 or 0
            end
        end
        local cls_list, count = GetClassList("Buff")
        for i = 0, count - 1 do
            local buff_cls = GetClassByIndexFromList(cls_list, i)
            if buff_cls then
                if buff_cls.Group1 ~= 'Debuff' and buff_cls.Group1 ~= 'Deuff' then
                    local buff_id = tostring(buff_cls.ClassID)
                    -- 既に設定がある(移行された)場合は上書きしない
                    if settings.buffs[buff_id] == nil then
                        settings.buffs[buff_id] = 1
                    end
                end
            end
        end
    else
        local file = io.open(g.my_buffs_control_dat_path, "r")
        if file then
            for line in file:lines() do
                local id, val = string.match(line, "^(.-):::(.*)$")
                if id and val then
                    settings.buffs[id] = tonumber(val)
                end
            end
            file:close()
        end
    end
    g.my_buffs_control_settings = settings
    -- 件数と所要時間はここでしか分からない。**この行を消さないこと。**
    -- 「レイドで重い」の切り分けでは、まずこの件数(実測 3816 件)と、上の
    -- .dat 書き出しの ms を突き合わせる。走るのはセッション中 1 回だけ。
    local buff_count = 0
    for _ in pairs(settings.buffs) do
        buff_count = buff_count + 1
    end
    g.vlog("my_buffs_control: 設定読込 %dms バフ表 %d 件 初期化=%s", My_buffs_control_now_ms() - t0,
        buff_count, tostring(need_init))
    if need_init then
        My_buffs_control_save_settings()
    end
end

-- BUFF_ON_MSG で受けた通知の内訳。**1 件ごとに vlog を出さないこと。**
-- レイドでは他人がけバフとデバフで通知が集中するので、1 件 1 行にすると
-- 肝心の行が埋もれる(CLAUDE.md「出しすぎない」)。ここに溜めて、マップ移動の
-- たびに on_init が 1 行だけ吐く。
function My_buffs_control_stat_bump(key)
    g.my_buffs_control_stat = g.my_buffs_control_stat or {}
    g.my_buffs_control_stat[key] = (g.my_buffs_control_stat[key] or 0) + 1
end

-- 直前のマップぶんの内訳を出して数え直す。
-- 「描かせず」が隠すバフのぶん = 素の再配置を丸ごと省けた回数。
-- 「取り消し」は、既に出ていたものを消しに行った回数(設定を切り替えた直後など)。
-- ここが常に 0 に近ければ、後追いの取り消しはもう起きていない。
function My_buffs_control_stat_flush()
    local st = g.my_buffs_control_stat
    if st and (st.msg or 0) > 0 then
        local msg = st.msg or 0
        local blocked, removed, skip_remove = st.blocked or 0, st.removed or 0, st.skip_remove or 0
        g.vlog(
            "my_buffs_control: 前のマップの BUFF_ON_MSG 内訳 受信=%d 素へ通した=%d 描かせず=%d 取り消し=%d 未表示のREMOVEを捨てた=%d",
            msg, msg - blocked - removed - skip_remove, blocked, removed, skip_remove)
    end
    g.my_buffs_control_stat = {}
end

function my_buffs_control_on_init()
    My_buffs_control_stat_flush()
    if not g.my_buffs_control_settings then
        My_buffs_control_load_settings()
    end
    local old_func = g.settings.my_buffs_control.old_init_func
    if _G[old_func] then
        return
    end
    if g.settings.my_buffs_control.use == 1 then
        My_buffs_control_frame()
    else
        My_buffs_control_reset_ui()
    end
    if g.my_buffs_control_is_change then
        My_buffs_control_save_settings()
        g.my_buffs_control_is_change = false
    end
    if g.get_map_type() == 'City' then
        return
    end
    -- **置換方式(g.setup_hook)であること。** 以前は g.setup_hook_and_event(bool=true)、
    -- つまり「素に描かせてから、自分が COMMON_BUFF_MSG("REMOVE") で取り消す」作りだった。
    -- 自分のバフ欄は素が状態を積み上げて描く(ADD は空きスロットへ入れ、REMOVE は後ろを
    -- 繰り上げる)ので「並べるところで飛ばす」入口が無く、後追いで消すしかなかったため。
    -- その結果、隠すバフ 1 個につき素の再配置(ARRANGE_BUFF_SLOT)が 2 回走っていた。
    -- 置換方式なら**素を呼ぶかどうかを手前で決められる**ので、隠すバフは最初から描かれない。
    -- 素の中身は 1 行も写していない(CLAUDE.md「素の関数を書き写さない」)。
    g.setup_hook(My_buffs_control_BUFF_ON_MSG, "BUFF_ON_MSG")
    g.register_msg("BUFF_ADD", "My_buffs_control_BUFF_ADD")
    My_buffs_control_common_buff_msg()
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    _nexus_addons_p:RunUpdateScript("My_buffs_control_delayed_init", 1.0)
end

function My_buffs_control_delayed_init(_nexus_addons_p)
    My_buffs_control_common_buff_msg()
    return 0
end

-- バフ欄のスロットを全部空にする。
--
-- **COMMON_BUFF_MSG("CLEAR") を使わないこと。** あちらは slot:ShowWindow(0) するだけで
-- アイコンの iconInfo.type を戻さない。素の "ADD" は OnlyOneBuff のバフについて
-- get_exist_debuff_in_slotlist で「同じ type のスロット」を**可視・不可視を問わず**探し、
-- 見つかるとそこへ復活させるので、古い type が残っていると詰め直したはずのバフが
-- 元の位置へ戻され、並びに隙間が空く(実機で確認)。
-- 素の "REMOVE" が使う CLEAR_BUFF_SLOT は iconInfo.type = 0 まで戻すので、そちらを使う。
-- 素の関数をそのまま呼ぶだけで、中身は写していない。
function My_buffs_control_clear_slots(buff_frame)
    for group_index = 0, s_buff_ui["buff_group_cnt"] do
        local slotlist = s_buff_ui["slotlist"][group_index]
        local captionlist = s_buff_ui["captionlist"][group_index]
        local slotcount = s_buff_ui["slotcount"][group_index]
        if slotlist and slotcount then
            for i = 0, slotcount - 1 do
                local slot = slotlist[i]
                if slot then
                    CLEAR_BUFF_SLOT(slot, captionlist and captionlist[i])
                end
            end
        end
    end
    buff_frame:Invalidate()
end

-- バフ欄の中身を「あるべき姿」に合わせ直す。on_init と、その 1 秒後に呼ばれる。
--
-- **1 件ずつ引き算しないこと。** 以前は「出ているのに隠すもの」を 1 件ずつ
-- COMMON_BUFF_MSG("REMOVE") で落としていたが、素の REMOVE は 1 回ごとに
-- ARRANGE_BUFF_SLOT まで通る(COMMON_BUFF_MSG を包んでいる debuff_notice への
-- BroadMsg も 1 回ずつ乗る)。街では全部表示するので、レイドへ入った瞬間の
-- 「出ているのに隠すもの」は**非表示指定にしているバフ全部**になり、
-- 「非表示の数 × フル再配置 × 2 回(on_init と 1 秒後)」が一気に走っていた。
-- 一度 CLEAR してから表示するものだけ並べ直せば、再配置は表示するバフの数で済み、
-- 街から持ち込んだ非表示バフが一瞬映ることも無くなる。
function My_buffs_control_common_buff_msg()
    local buff_frame = ui.GetFrame("buff")
    if not buff_frame or not s_buff_ui or not s_buff_ui["slotlist"] then
        return
    end
    local my_handle = session.GetMyHandle()
    local buff_count = info.GetBuffCount(my_handle)
    if g.settings.my_buffs_control.use == 0 then
        My_buffs_control_clear_slots(buff_frame)
        for i = 0, buff_count - 1 do
            local buff = info.GetBuffIndexed(my_handle, i)
            if buff then
                g.FUNCS["BUFF_ON_MSG"](buff_frame, "BUFF_ADD", tostring(buff.index), buff.buffID)
            end
        end
        return
    end
    -- (1) あるべき姿。デバフと、表示指定のバフだけを並べる。
    local want, want_n, want_count, sig = {}, 0, {}, {}
    for i = 0, buff_count - 1 do
        local buff = info.GetBuffIndexed(my_handle, i)
        if buff and BUFF_CHECK_SEPARATELIST(buff.buffID) ~= true then
            local cls = GetClassByType('Buff', buff.buffID)
            local is_debuff = cls and (cls.Group1 == 'Debuff' or cls.Group1 == 'Deuff')
            if is_debuff or g.my_buffs_control_settings.buffs[tostring(buff.buffID)] == 1 then
                want_n = want_n + 1
                want[want_n] = {
                    id = buff.buffID,
                    index = buff.index
                }
                want_count[buff.buffID] = (want_count[buff.buffID] or 0) + 1
                sig[want_n] = tostring(buff.buffID) .. ":" .. tostring(buff.index)
            end
        end
    end
    -- 顔ぶれの印。GetBuffIndexed の並びは付け外しで変わるので、並べ替えてから繋ぐ。
    table.sort(sig)
    local want_sig = table.concat(sig, ",")
    -- (2) 今の姿。**同じ ID が複数出ることがある**(buffIndex 違い)ので、数まで数える。
    local have_count, have_n = {}, 0
    for group_index = 0, s_buff_ui["buff_group_cnt"] do
        local slotlist = s_buff_ui["slotlist"][group_index]
        local slotcount = s_buff_ui["slotcount"][group_index]
        if slotlist and slotcount then
            for i = 0, slotcount - 1 do
                local slot = slotlist[i]
                if slot and slot:IsVisible() == 1 then
                    local icon = slot:GetIcon()
                    local icon_info = icon and icon:GetInfo()
                    if icon_info then
                        local id = tonumber(icon_info.type)
                        have_count[id] = (have_count[id] or 0) + 1
                        have_n = have_n + 1
                    end
                end
            end
        end
    end
    -- (3) 何もしなくてよいかを決める。**件数の一致で判定してはいけない。**
    -- 素は「並べたいもの」を全部描くとは限らない(COMMON_BUFF_MSG は class.ShowIcon が
    -- "FALSE" なら何もせず帰り、SET_BUFF_SLOT も info.GetBuff が nil ならスロットを
    -- 出さずに帰る)。その条件をこちらで数え直すのは素の判定を写すことになるし、
    -- 実際に食い違って**毎回組み立て直しになっていた**(実機で「23 件 -> 23 件」の直後に
    -- 「10 件 -> 23 件」)。素が何を描くかは予想せず、次の 2 つだけを見る。
    --
    --   * 出したくないものが出ていないか(= want に無いものが表示されている)
    --   * 前回組み立てたときから、並べたい顔ぶれが変わっていないか
    --
    -- 「表示したいのに出ていない」ぶんは、素が描かないと決めたものかもしれないので
    -- 件数では判定しない。顔ぶれが同じなら組み立て直しても結果は同じになる。
    local extra = 0
    for id, n in pairs(have_count) do
        local w = want_count[id] or 0
        if n > w then
            extra = extra + (n - w)
        end
    end
    if extra == 0 and g.my_buffs_control_built_sig == want_sig then
        g.vlog("my_buffs_control: 突き合わせ 変化なし (表示 %d 件 / 並べたい %d 件)", have_n, want_n)
        return
    end
    -- (4) 一度消して、表示するものだけ並べ直す。
    local t0 = My_buffs_control_now_ms()
    local use_old = type(_G["COMMON_BUFF_MSG_OLD"]) == "function"
    My_buffs_control_clear_slots(buff_frame)
    for i = 1, want_n do
        local b = want[i]
        if use_old then
            COMMON_BUFF_MSG_OLD(buff_frame, "ADD", b.id, my_handle, s_buff_ui, b.index)
        else
            COMMON_BUFF_MSG(buff_frame, "ADD", b.id, my_handle, s_buff_ui, b.index)
        end
    end
    -- 高さは素の BUFF_ON_MSG が末尾で合わせているぶんなので、組み立て直したら 1 回だけ掛ける。
    BUFF_RESIZE(buff_frame, s_buff_ui)
    g.my_buffs_control_built_sig = want_sig
    g.vlog("my_buffs_control: 突き合わせ 組み立て直し 表示 %d 件(うち出したくないもの %d 件) -> 並べたい %d 件 %dms",
        have_n, extra, want_n, My_buffs_control_now_ms() - t0)
end

-- そのバフが「いまバフ欄のスロットに出ているか」。
--
-- 置換方式にした今、隠すバフは最初から描かれないので、普段ここは false を返す。
-- **それでも要る**のは、隠す前に出ていたぶんの後始末があるため。レイド中に設定画面で
-- チェックを外すと、既に出ているアイコンはそのまま残る(過去のメッセージは戻ってこない)。
--
-- **出ていないなら素を呼ばないこと。** 素の COMMON_BUFF_MSG は "REMOVE" の対象が
-- 見つからなくても、末尾で必ず REMOVE_BUFF_COUNT_SLOT_SUB → ARRANGE_BUFF_SLOT →
-- COLONY_BATTLE_INFO_DRAW_BUFF_ICON まで通る(git show upstream/main:_client/jp/addon.ipf/buff/buff.lua)。
-- ARRANGE_BUFF_SLOT は GET_CHILD_RECURSIVELY を 4 回叩き、SET_BUFF_CAPTION_OFFSET で
-- 全スロットを回すので、空振りでもバフ欄のフル再配置ぶんの費用を払うことになる。
--
-- **見えていないスロットに当たっても打ち切らないこと。** 普段は詰めて並ぶ
-- (ADD は最初の空きへ入れ、REMOVE は PULL_BUFF_SLOT_LIST で後ろを繰り上げる)が、
-- COMMON_BUFF_MSG の "CLEAR" は ShowWindow(0) するだけで iconInfo.type を戻さないため、
-- そのあと OnlyOneBuff のバフが get_exist_debuff_in_slotlist 経由で飛び飛びの位置に
-- 復活しうる。打ち切ると、その先に出ているバフを「出ていない」と誤判定する。
-- 全走査でもスロット数は 4 グループ合わせて 70 個ほど(buff.xml の col)で、
-- ここで避けている ARRANGE_BUFF_SLOT や MY_BUFF_TIME_UPDATE より十分軽い。
--
-- 判断できないとき(s_buff_ui がまだ無い)は true を返して従来どおり消しに行く。
-- 見落として「非表示にしたのに出る」になるより、無駄に 1 回働く方が実害が小さい。
function My_buffs_control_is_displayed(buff_id)
    if not s_buff_ui or not s_buff_ui["slotlist"] then
        return true
    end
    local target = tonumber(buff_id)
    for group_index = 0, s_buff_ui["buff_group_cnt"] do
        local slotlist = s_buff_ui["slotlist"][group_index]
        local slotcount = s_buff_ui["slotcount"][group_index]
        if slotlist and slotcount then
            for i = 0, slotcount - 1 do
                local slot = slotlist[i]
                if slot and slot:IsVisible() == 1 then
                    local icon = slot:GetIcon()
                    local icon_info = icon and icon:GetInfo()
                    if icon_info and tonumber(icon_info.type) == target then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- 素の BUFF_ON_MSG(frame, msg, argStr, argNum) の置き換え。**引数の並びは素と同じにすること。**
-- msg は "BUFF_ADD" / "BUFF_REMOVE" / "BUFF_UPDATE" のいずれか(buff.lua の BUFF_ON_INIT が
-- 3 つとも同じ関数に登録している)。argStr がバフの index、argNum がバフ ID。
--
-- **判断だけをここで行い、描画は必ず素へ任せること。** 表示するバフは素をそのまま呼び、
-- 隠すバフは素を呼ばない。素の中身を写して条件を足すと、IMC がバフ欄の描き方を変えたとき
-- 設定の ON / OFF に関わらず古い実装のまま取り残される(CLAUDE.md「素の関数を書き写さない」)。
function My_buffs_control_BUFF_ON_MSG(frame, msg, argStr, argNum)
    local origin = g.FUNCS and g.FUNCS["BUFF_ON_MSG"]
    if type(origin) ~= "function" then
        -- 控えを取れていない。ここで握り潰すとバフ欄が一切更新されなくなるので、何もしない。
        return
    end
    -- OFF と街は素の挙動そのもの。**先に返すこと**(下の設定表参照は OFF のとき未初期化でありうる)。
    if g.settings.my_buffs_control.use == 0 then
        return origin(frame, msg, argStr, argNum)
    end
    if g.get_map_type() == 'City' then
        return origin(frame, msg, argStr, argNum)
    end
    My_buffs_control_stat_bump("msg")
    -- **「隠すバフか」を先に見ること。** 通知の大半は隠さないバフで、それらは素へ流すだけ。
    -- セパレートバフ欄の判定(BUFF_CHECK_SEPARATELIST = ui.buff.IsBuffSeparate)を手前に置くと、
    -- 素も同じ判定をするので、通知 1 件ごとに 2 度引くことになる(レイドで実測 1 秒 10 件超)。
    --
    -- デバフは設定に関わらず常に表示する。クラスを引けないときも素へ通す
    -- (素は GetClassByType の nil ガードを持たないが、それは素の責任範囲。
    --  こちらが勝手に握り潰すと、隠す設定でもないバフが黙って出なくなる)。
    local cls = GetClassByType('Buff', argNum)
    if not cls or cls.Group1 == 'Debuff' or cls.Group1 == 'Deuff' then
        return origin(frame, msg, argStr, argNum)
    end
    if g.my_buffs_control_settings.buffs[tostring(argNum)] == 1 then
        return origin(frame, msg, argStr, argNum)
    end
    -- セパレートバフ欄行きは素が自分で弾く。判定を写さず素へ任せる。
    if BUFF_CHECK_SEPARATELIST(argNum) == true then
        return origin(frame, msg, argStr, argNum)
    end

    -- ここから「隠すバフ」。素を呼ばない = そもそもバフ欄に描かれない。
    --
    -- ただし**隠す前から出ていたぶん**は残っている(レイド中に設定画面でチェックを外した
    -- 場合。過去のメッセージは戻ってこないので、出ているものは自分で消すしかない)。
    -- 出ているときだけ、素に "BUFF_REMOVE" として処理させる。
    if My_buffs_control_is_displayed(argNum) then
        My_buffs_control_stat_bump("removed")
        return origin(frame, "BUFF_REMOVE", argStr, argNum)
    end
    -- 出ていない REMOVE は消す相手が居ないので捨てる。**ここを素へ通してはいけない。**
    -- 素の REMOVE は対象が無くても末尾の再配置まで通るので、丸ごと空振りになる。
    if msg == "BUFF_REMOVE" then
        My_buffs_control_stat_bump("skip_remove")
        return
    end
    My_buffs_control_stat_bump("blocked")
end

function My_buffs_control_reset_ui()
    local buff = ui.GetFrame("buff")
    if buff then
        AUTO_CAST(buff)
        buff:SetPos(g.my_buffs_control_settings.default_x, g.my_buffs_control_settings.default_y)
        buff:RemoveChild("lock_slot")
        g.my_buffs_control_settings.lock = true
        buff:EnableHittestFrame(0)
        buff:EnableMove(0)
        buff:SetEventScript(ui.LBUTTONUP, "None")
    end
end

function My_buffs_control_frame()
    if g.settings.my_buffs_control.use == 0 then
        My_buffs_control_reset_ui()
        return
    end
    local buff = ui.GetFrame("buff")
    AUTO_CAST(buff)
    buff:SetEventScript(ui.LBUTTONUP, "My_buffs_control_end_drag")
    if g.get_map_type() ~= 'City' then
        buff:SetPos(g.my_buffs_control_settings.custom_x, g.my_buffs_control_settings.custom_y)
    else
        buff:SetPos(g.my_buffs_control_settings.default_x, g.my_buffs_control_settings.default_y)
    end
    buff:SetLayerLevel(61)
    buff:RemoveChild("lock_slot")
    local lock_slot = buff:CreateOrGetControl('slot', "lock_slot", 0, 0, 20, 30)
    AUTO_CAST(lock_slot)
    lock_slot:SetTextTooltip(g.lang == "Japanese" and
                                 "{ol}[MBC]{nl}左クリック:フレームを動かせる様に{nl} {nl}{#FF0000}街では全て表示します" or
                                 "{ol}[MBC]{nl}Left Click: Make frame movable{nl} {nl}{#FF0000}Show all in town")
    lock_slot:SetEventScript(ui.LBUTTONUP, "My_buffs_control_frame_lock")
    local lock = lock_slot:CreateOrGetControlSet('inv_itemlock', "lock", 0, 0)
    AUTO_CAST(lock)
    lock:SetGravity(ui.LEFT, ui.TOP)
    if g.my_buffs_control_settings.lock then
        lock:SetGrayStyle(0)
    else
        lock:SetGrayStyle(1)
    end
end

function My_buffs_control_end_drag(buff, ctrl, str, num)
    g.my_buffs_control_settings.custom_x = buff:GetX()
    g.my_buffs_control_settings.custom_y = buff:GetY()
    My_buffs_control_save_settings()
end

function My_buffs_control_frame_lock(buff, lock_slot)
    local lock = GET_CHILD(lock_slot, "lock")
    if g.my_buffs_control_settings.lock then
        g.my_buffs_control_settings.lock = false
        lock:SetGrayStyle(1)
        buff:EnableHittestFrame(1)
        buff:EnableMove(1)
    else
        g.my_buffs_control_settings.lock = true
        lock:SetGrayStyle(0)
        buff:EnableHittestFrame(0)
        buff:EnableMove(0)
    end
    My_buffs_control_save_settings()
end

function My_buffs_control_setting_menu()
    local my_buffs_control_setting = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "my_buffs_control_setting",
        0, 0, 0, 0)
    my_buffs_control_setting:Resize(250, 180)
    -- 位置は g.settings_frame_pos に任せる(一覧が開いていなければ画面中央)。
    -- **素で list_frame:GetX() を呼ばないこと。** Addons Menu のショートカットから
    -- 開くと一覧は開いておらず nil で落ちる = 空の窓が出る(g.settings_frame_pos のコメント)。
    my_buffs_control_setting:SetPos(g.settings_frame_pos(250, 180))
    my_buffs_control_setting:SetSkinName("test_frame_low")
    my_buffs_control_setting:EnableHittestFrame(1)
    my_buffs_control_setting:EnableHitTest(1)
    my_buffs_control_setting:ShowWindow(1)
    my_buffs_control_setting:SetLayerLevel(999)
    local title_text = my_buffs_control_setting:CreateOrGetControl('richtext', 'title_text', 20, 15, 50, 30)
    AUTO_CAST(title_text)
    title_text:SetText("{ol}My Buffs Control Config")
    local close = my_buffs_control_setting:CreateOrGetControl("button", "close", 0, 0, 20, 20)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "My_buffs_control_frame_close")
    local gbox = my_buffs_control_setting:CreateOrGetControl("groupbox", "gbox", 10, 40,
        my_buffs_control_setting:GetWidth() - 20, my_buffs_control_setting:GetHeight() - 50)
    AUTO_CAST(gbox)
    gbox:SetSkinName("test_frame_midle_light")
    local list_open_btn = gbox:CreateOrGetControl('button', 'list_open_btn', 10, 10, 130, 30)
    AUTO_CAST(list_open_btn)
    list_open_btn:SetText("{ol}Buff list")
    list_open_btn:SetTextTooltip(g.lang == "Japanese" and "{ol}バフリスト表示" or "{ol}Buff list Open")
    list_open_btn:SetEventScript(ui.LBUTTONUP, "My_buffs_control_buff_list_open")
    local org_pos = gbox:CreateOrGetControl('button', 'org_pos', 10, 50, 130, 30)
    AUTO_CAST(org_pos)
    org_pos:SetText("Default Pos")
    org_pos:SetTextTooltip(g.lang == "Japanese" and "{ol}バフ欄の位置を元に戻します" or
                               "{ol}Restore the buff frame position to default")
    org_pos:SetEventScript(ui.LBUTTONUP, "My_buffs_control_original_position")
    local text = gbox:CreateOrGetControl('richtext', 'text', 10, 100, 150, 30)
    AUTO_CAST(text)
    text:SetText(g.lang == "Japanese" and "{ol}{#FF0000}※街では全て表示します" or
                     "{ol}{#FF0000}※Show all in town")
    g.esc_register_destroy(addon_name_lower .. "my_buffs_control_setting")
end

function My_buffs_control_original_position()
    local buff = ui.GetFrame("buff")
    buff:SetPos(g.my_buffs_control_settings.default_x, g.my_buffs_control_settings.default_y)
    g.my_buffs_control_settings.custom_x = g.my_buffs_control_settings.default_x
    g.my_buffs_control_settings.custom_y = g.my_buffs_control_settings.default_y
    My_buffs_control_save_settings()
end

function My_buffs_control_frame_close(frame, ctrl, str, num)
    ui.DestroyFrame(frame:GetName())
end

function My_buffs_control_buff_list_search(my_buffs_control, ctrl, ctrl_text, num)
    local search_edit = GET_CHILD_RECURSIVELY(my_buffs_control, "search_edit")
    local ctrl_text = search_edit:GetText()
    if ctrl_text ~= "" then
        My_buffs_control_buff_list_open(my_buffs_control, ctrl, ctrl_text)
    else
        My_buffs_control_buff_list_open(my_buffs_control, ctrl, "")
    end
end

function My_buffs_control_buff_list_open(frame, ctrl, ctrl_text, num)
    local my_buffs_control = ui.GetFrame(addon_name_lower .. "my_buffs_control")
    if not my_buffs_control then
        my_buffs_control = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "my_buffs_control", 0, 0, 0, 0)
        AUTO_CAST(my_buffs_control)
        g.block_click_through(my_buffs_control)
        my_buffs_control:SetSkinName("test_frame_low")
        my_buffs_control:Resize(500, 1060)
        my_buffs_control:SetPos(150, 10)
        my_buffs_control:SetLayerLevel(121)
        local search_edit = my_buffs_control:CreateOrGetControl("edit", "search_edit", 40, 10, 305, 38)
        AUTO_CAST(search_edit)
        search_edit:SetFontName("white_18_ol")
        search_edit:SetTextAlign("left", "center")
        search_edit:SetSkinName("inventory_serch")
        search_edit:SetEventScript(ui.ENTERKEY, "My_buffs_control_buff_list_search")
        g.setup_incremental_search(search_edit, "My_buffs_control_buff_list_search")
        local search_btn = search_edit:CreateOrGetControl("button", "search_btn", 0, 0, 40, 38)
        AUTO_CAST(search_btn)
        search_btn:SetImage("inven_s")
        search_btn:SetGravity(ui.RIGHT, ui.TOP)
        search_btn:SetEventScript(ui.LBUTTONUP, "My_buffs_control_buff_list_search")
        local close = my_buffs_control:CreateOrGetControl('button', 'close', 0, 0, 20, 20)
        AUTO_CAST(close)
        close:SetImage("testclose_button")
        close:SetGravity(ui.RIGHT, ui.TOP)
        close:SetEventScript(ui.LBUTTONUP, "My_buffs_control_frame_close")
    end
    local buff_list_gb = my_buffs_control:CreateOrGetControl("groupbox", "buff_list_gb", 10, 50, 480,
        my_buffs_control:GetHeight() - 60)
    AUTO_CAST(buff_list_gb)
    buff_list_gb:SetSkinName("bg")
    buff_list_gb:RemoveAllChild()
    local cls_list, count = GetClassList("Buff")
    local all_buffs = {}
    local pruned = 0
    for i = 0, count - 1 do
        local buff_cls = GetClassByIndexFromList(cls_list, i)
        if buff_cls then
            if buff_cls.Group1 ~= 'Debuff' and buff_cls.Group1 ~= 'Deuff' then
                local buff_name = dictionary.ReplaceDicIDInCompStr(buff_cls.Name)
                if not ctrl_text or ctrl_text == "" or string.find(buff_name, ctrl_text) then
                    local image_name = GET_BUFF_ICON_NAME(buff_cls)
                    if image_name ~= "icon_None" and buff_name ~= "None" then
                        local is_checked = g.my_buffs_control_settings.buffs[tostring(buff_cls.ClassID)] == 1
                        table.insert(all_buffs, {
                            cls = buff_cls,
                            name = buff_name,
                            image = image_name,
                            is_checked = is_checked
                        })
                    end
                end
            else
                -- デバフは設定の対象外。過去に混入したぶんを表から取り除く。
                -- **判定は ~= nil で書くこと。** 非表示を 0 で持つようになったので、
                -- 真偽で書くと 0 のエントリも「在る」と見えて数え方が変わる。
                local key = tostring(buff_cls.ClassID)
                if g.my_buffs_control_settings.buffs[key] ~= nil then
                    g.my_buffs_control_settings.buffs[key] = nil
                    pruned = pruned + 1
                end
            end
        end
    end
    -- **掃除で実際に消したときだけ保存すること。** この関数は一覧を開く入口であると同時に、
    -- 検索の実行関数でもある(g.setup_incremental_search から My_buffs_control_buff_list_search
    -- 経由で呼ばれる)。無条件に保存すると**打鍵のたびに .dat を全件書き直す**ことになる
    -- (実機で、設定画面を 30 秒触った間に 9 回。1 回あたり 1〜3ms)。
    -- 掃除は初回に効けば以降は何も変わらないので、変化が無ければ書かない。
    if pruned > 0 then
        g.vlog("my_buffs_control: バフ表からデバフ %d 件を取り除いた", pruned)
        My_buffs_control_save_settings()
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
        buff_check:SetTextTooltip(g.lang == "Japanese" and "チェックを外すとバフを非表示にします" or
                                      "Unchecking hides the buff")
        buff_check:SetCheck(buff_data.is_checked and 1 or 0)
        buff_check:SetEventScript(ui.LBUTTONUP, "My_buffs_control_buff_toggle")
        buff_check:SetEventScriptArgString(ui.LBUTTONUP, buff_id)
        y = y + 35
    end
    my_buffs_control:ShowWindow(1)
end

-- **非表示は nil ではなく 0 で持つこと。** nil にすると .dat から行ごと消えるので、
-- 次にそのバフを受けたとき My_buffs_control_BUFF_ADD が「知らないバフ」と見なして
-- 1(表示)へ戻し、そのうえ is_change を立てて次のマップ移動で .dat を全件書き直す。
-- 非表示のバフを常用している人ほど、マップ移動のたびに全件(実測 3816 行)の
-- 書き出しを踏むことになる。
function My_buffs_control_buff_toggle(frame, ctrl, str_buff_id, num)
    local is_check = ctrl:IsChecked()
    if is_check == 1 then
        g.my_buffs_control_settings.buffs[str_buff_id] = 1
    else
        g.my_buffs_control_settings.buffs[str_buff_id] = 0
    end
    My_buffs_control_save_settings()
end

-- 初めて見たバフを「表示」で表へ足す。**判定は == nil で書くこと。**
-- 非表示は 0 で持つので、not で書くと Lua では 0 が真になるぶん今は動くが、
-- 「未登録かどうか」を見ている意図が消えて、0 を false に変えた途端に
-- 非表示のバフが毎回 1 へ戻る形へ壊れる。
function My_buffs_control_BUFF_ADD(frame, ctrl, str, buff_id)
    local str_buff_id = tostring(buff_id)
    local buff_cls = GetClassByType("Buff", buff_id)
    -- クラスを引けないバフ ID が来ることがある。素の COMMON_BUFF_MSG は nil ガードを
    -- 持たないので、ここで弾かないと後段まで nil が流れる。
    if not buff_cls then
        return
    end
    if buff_cls.Group1 ~= 'Debuff' and buff_cls.Group1 ~= 'Deuff' then
        if g.my_buffs_control_settings.buffs[str_buff_id] == nil then
            g.my_buffs_control_settings.buffs[str_buff_id] = 1
            g.my_buffs_control_is_change = true
            g.vlog("my_buffs_control: 未登録のバフを表示で追加 id=%s (次のマップ移動で .dat を書き直す)",
                str_buff_id)
        end
    end
end
-- my_buffs_control ここまで

