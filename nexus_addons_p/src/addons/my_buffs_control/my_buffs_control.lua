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
    -- .dat には**非表示にしたバフ(0)だけ**を書く。表は「非表示リスト」なので、
    -- 表示するバフは表に載せない(載っていない = 表示)。
    --
    -- **表示を 1 として書き戻さないこと。** 以前は判定が「== 1 なら表示」= 許可リストで、
    -- 表示するバフ全部を持つ必要があった。そのため起動時に GetClassList("Buff") を全件
    -- 舐めて 1 を入れており、.dat は実測 3816 行 / 40KB(2026-08 の JP クライアント)。
    -- 未登録のバフを受けるたびに 1 を足して書き直す経路まで生えていた。
    -- 非表示リストなら、書く量は利用者が実際に隠したぶん(普通は数件〜数十件)で済む。
    -- mini_addons のバフ一覧が json のままで 5 秒かかっていた前例があるので
    -- (settings/storage.lua の Mini_addons_load_buffs のコメント)、
    -- 「表を全件書き直す」形そのものを持たないのが一番効く。
    local t0 = My_buffs_control_now_ms()
    local file = io.open(g.my_buffs_control_dat_path, "w")
    if file then
        local lines = {}
        for id, val in pairs(g.my_buffs_control_settings.buffs) do
            -- 0 以外(= 表示)が紛れ込んでいても書かない。表に残っていても意味を持たない
            if val == 0 then
                table.insert(lines, tostring(id) .. ":::0")
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
    -- **移行のために ver を上げないこと。** ver を上げると need_init が立ち、
    -- settings ごと既定値へ差し替わるので、利用者の lock と窓位置まで初期化される。
    -- 非表示リストへの移行は .dat の中身(表示の行が在るか)で自分で気付ける
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
    -- 表は「非表示リスト」。載っていない = 表示なので、**表示するバフは入れない。**
    -- ここで無条件に GetClassList("Buff") を全件舐めて 1 を入れてはいけない(それが 3816 行の元)。
    --
    -- ただし**許可リスト時代の .dat からの移行のときだけ**は全件舐める必要がある。
    -- 当時の「非表示」は 0 の行ではなく**行が無いこと**だったため(v2.2.1 の
    -- My_buffs_control_buff_toggle は非表示に nil を入れ、書き出しは nil の行を書かない)。
    -- **0 の行だけ拾う移行にすると、利用者が隠したバフを一件残らず捨てることになる。**
    local shown, hidden_n, legacy_n = {}, 0, 0
    local file = io.open(g.my_buffs_control_dat_path, "r")
    if file then
        for line in file:lines() do
            local id, val = string.match(line, "^(.-):::(.*)$")
            if id and val then
                if tonumber(val) == 0 then
                    -- 非表示リスト形式の行。そのまま採用する
                    settings.buffs[id] = 0
                    hidden_n = hidden_n + 1
                else
                    -- 許可リスト形式の行(表示)。表には入れず、「表示だった」ことだけ控える
                    shown[id] = true
                    legacy_n = legacy_n + 1
                end
            end
        end
        file:close()
    end
    -- 許可リスト形式の行が在った = 移行が要る。**「表示」に載っていないバフが当時の非表示。**
    -- 走るのは移行の 1 回だけで、以降は legacy_n == 0 なのでここへ入らない
    if legacy_n > 0 then
        local cls_list, count = GetClassList("Buff")
        for i = 0, count - 1 do
            local buff_cls = GetClassByIndexFromList(cls_list, i)
            if buff_cls and buff_cls.Group1 ~= 'Debuff' and buff_cls.Group1 ~= 'Deuff' then
                local buff_id = tostring(buff_cls.ClassID)
                if not shown[buff_id] and settings.buffs[buff_id] == nil then
                    settings.buffs[buff_id] = 0
                    hidden_n = hidden_n + 1
                end
            end
        end
        need_init = true
        g.vlog("my_buffs_control: 許可リスト形式の .dat を移行(表示 %d 件 -> 非表示 %d 件を書き出す)",
            legacy_n, hidden_n)
    end
    if need_init then
        local old_settings = g.load_json(g.my_buffs_control_old_path)
        if old_settings and old_settings.buffs then
            for id, is_visible in pairs(old_settings.buffs) do
                -- 旧 json は真偽値。非表示(false)だけを引き継ぐ
                if is_visible ~= true then
                    settings.buffs[tostring(id)] = 0
                end
            end
        end
    end
    g.my_buffs_control_settings = settings
    -- 件数と所要時間はここでしか分からない。**この行を消さないこと。**
    -- 非表示リストにしてからは、ここが「利用者が隠したバフの数」になる
    -- (許可リストだった頃は表示するバフ全部で、実測 3816 件だった)。
    -- 桁が戻っていたら移行に失敗している。走るのはセッション中 1 回だけ。
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
    -- **BUFF_ADD は購読しない。** 表が非表示リストになったので「初めて見たバフ」を
    -- 表へ足す必要が無い(載っていない = 表示)。許可リストだった頃は、未登録のバフを
    -- 受けるたびに 1 を足して is_change を立て、次のマップ移動で .dat を全件
    -- 書き直していた。その経路ごと消してある
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
                -- **アイコンの有無を見てから呼ぶこと。** 素の CLEAR_BUFF_SLOT は
                -- slot:GetIcon():GetInfo() をノーガードで引く。素はこれを表示中の
                -- スロットにしか呼ばないが、こちらは未使用ぶんを含む全スロットへ掛ける
                -- (不可視スロットに残った iconInfo.type を消すのがこの関数の目的なので、
                --  「表示中だけ」に絞ると OnlyOneBuff が元の位置へ復活する不具合が戻る)。
                -- アイコンが無いスロットは古い type も持たないので、飛ばして正しい。
                -- 素も、全スロットを走査する get_exist_debuff_in_slotlist では
                -- icon と iconInfo の両方を nil ガードしている。
                if slot and slot:GetIcon() ~= nil then
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
            -- 表は非表示リスト。**載っていない(nil) = 表示**なので ~= 0 で見ること
            if is_debuff or g.my_buffs_control_settings.buffs[tostring(buff.buffID)] ~= 0 then
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
    -- **have_n == 0 のときは帰らないこと。** built_sig はセッション中ずっと残るので、
    -- マップ移動でバフ欄が空になったのに顔ぶれが前のマップと同じだと、
    -- extra == 0 かつ sig 一致で「変化なし」と見えて**一つも描かないまま終わる**。
    -- この関数はまさにその取りこぼしを埋めるためにあるので、空なら必ず組み立てる。
    if extra == 0 and have_n > 0 and g.my_buffs_control_built_sig == want_sig then
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
-- 出ていれば true と**そのアイコンの BuffIndex**を返す。
-- index を返すのは、素の "REMOVE" が iconInfo.type と BuffIndex の**両方一致**で
-- 探すため。届いたメッセージ側の index をそのまま渡すと、居残りアイコンの index と
-- 違ったときに消えず、以後その ID の通知ごとにフル再配置の空振りを払い続ける。
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
                        return true, icon:GetUserIValue("BuffIndex")
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
    -- 表は非表示リスト。載っていない(nil) = 表示なので、そのまま素へ渡す
    if g.my_buffs_control_settings.buffs[tostring(argNum)] ~= 0 then
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
    -- 消すのは**居残りアイコンが持っている BuffIndex**。届いた argStr ではない(上のコメント)
    local displayed, shown_index = My_buffs_control_is_displayed(argNum)
    if displayed then
        My_buffs_control_stat_bump("removed")
        return origin(frame, "BUFF_REMOVE", shown_index or argStr, argNum)
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
    My_buffs_control_buff_list_open(my_buffs_control, ctrl, My_buffs_control_buff_list_filter_text(my_buffs_control),
        num)
end

-- 一覧に出すバフを列挙する。**表示と一括操作で必ずこれを共有すること。**
-- 条件(デバフ除外 / 検索語 / アイコンや名前が無いものの除外)が 2 箇所に分かれると、
-- 「見えているものと一括操作の対象」が食い違って、出ていないバフまで勝手に切り替わる
-- (mini_addons の Mini_addons_buff_list_each と同じ理由)。
--
-- ついでにデバフのエントリを表から取り除き、消した件数を返す。デバフは設定の対象外なので、
-- 過去に混入したぶんが残っていても意味を持たない。
function My_buffs_control_buff_list_each(filter_text, func)
    local cls_list, count = GetClassList("Buff")
    local pruned = 0
    for i = 0, count - 1 do
        local buff_cls = GetClassByIndexFromList(cls_list, i)
        if buff_cls then
            if buff_cls.Group1 ~= 'Debuff' and buff_cls.Group1 ~= 'Deuff' then
                local buff_name = dictionary.ReplaceDicIDInCompStr(buff_cls.Name)
                if not filter_text or filter_text == "" or string.find(buff_name, filter_text) then
                    local image_name = GET_BUFF_ICON_NAME(buff_cls)
                    if image_name ~= "icon_None" and buff_name ~= "None" then
                        func(buff_cls, buff_name, image_name)
                    end
                end
            else
                -- **判定は ~= nil で書くこと。** 見たいのは「表に在るか」であって
                -- 値の真偽ではない(Lua では 0 も真なので、not で書くと意図が消える)。
                local key = tostring(buff_cls.ClassID)
                if g.my_buffs_control_settings.buffs[key] ~= nil then
                    g.my_buffs_control_settings.buffs[key] = nil
                    pruned = pruned + 1
                end
            end
        end
    end
    return pruned
end

-- いま検索欄に入っている絞り込み。一括操作の対象を「見えている分」に合わせるために使う。
-- **ctrl:GetText() で読まないこと。** 同じ関数を虫眼鏡ボタンにも割り当てているので、
-- ctrl がボタンのときに空文字を検索語にしてしまう(CLAUDE.md「検索欄は名前で引いて読む」)。
function My_buffs_control_buff_list_filter_text(my_buffs_control)
    local search_edit = my_buffs_control and GET_CHILD_RECURSIVELY(my_buffs_control, "search_edit")
    return search_edit and search_edit:GetText() or ""
end

-- 一覧に出ているバフをまとめて表示 / 非表示にする(num: 1=表示, 0=非表示)。
-- 対象は**いま一覧に出ているぶんだけ**。検索で絞っていればその分だけが変わる。
function My_buffs_control_buff_list_set_all(frame, ctrl, str, num)
    local hide = num ~= 1
    local filter_text = My_buffs_control_buff_list_filter_text(frame)
    local changed = 0
    My_buffs_control_buff_list_each(filter_text, function(buff_cls)
        local key = tostring(buff_cls.ClassID)
        -- 表は「非表示リスト」。載っていない = 表示なので、表示に戻すときは nil にする。
        local now_hidden = g.my_buffs_control_settings.buffs[key] == 0
        if now_hidden ~= hide then
            g.my_buffs_control_settings.buffs[key] = hide and 0 or nil
            changed = changed + 1
        end
    end)
    My_buffs_control_save_settings()
    g.vlog("my_buffs_control: バフ一覧を一括変更 表示=%s 変更 %d 件 filter=%s", tostring(not hide), changed,
        tostring(filter_text))
    ui.SysMsg(g.lang == "Japanese" and
                  string.format("{ol}{#00BFFF}[Nexus Addons P] バフ表示を %d 件 %s にしました", changed,
            hide and "非表示" or "表示") or
                  string.format("{ol}{#00BFFF}[Nexus Addons P] Set %d buff(s) to %s", changed,
            hide and "hidden" or "shown"))
    -- 変えた結果をその場でバフ欄へ反映する。置換方式のフックは「次に通知が来たとき」しか
    -- 効かないので、これが無いと一括で切り替えても画面が変わらず、効いていないように見える。
    -- 街は全表示が仕様なので触らない(on_init も街では突き合わせを呼ばない)。
    if changed > 0 and g.get_map_type() ~= 'City' then
        My_buffs_control_common_buff_msg()
    end
    My_buffs_control_buff_list_open(frame, ctrl, filter_text, num)
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
        local title_text = my_buffs_control:CreateOrGetControl('richtext', 'title_text', 15, 15, 10, 30)
        AUTO_CAST(title_text)
        title_text:SetText("{#000000}{s20}Buff List")
        local search_edit = my_buffs_control:CreateOrGetControl("edit", "search_edit", title_text:GetWidth() + 30, 10,
            305, 38)
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
        -- 一括操作のボタン列。文言と並びは mini_addons のバフ一覧に揃える。
        local ja = g.lang == "Japanese"
        local buttons = {{
            name = "all_on_btn",
            text = ja and "{ol}全部表示" or "{ol}Show all",
            tooltip = ja and
                "{ol}いま一覧に出ているバフを全部「表示」にします{nl}検索で絞り込んでいるときは、その分だけが対象です" or
                "{ol}Show every buff currently listed{nl}Only the filtered ones while searching",
            script = "My_buffs_control_buff_list_set_all",
            arg = 1
        }, {
            name = "all_off_btn",
            text = ja and "{ol}全部非表示" or "{ol}Hide all",
            tooltip = ja and
                "{ol}いま一覧に出ているバフを全部「非表示」にします{nl}検索で絞り込んでいるときは、その分だけが対象です{nl} {nl}{#FF0000}絞り込まずに押すと全部消えます" or
                "{ol}Hide every buff currently listed{nl}Only the filtered ones while searching{nl} {nl}{#FF0000}Hides everything if pressed without a filter",
            script = "My_buffs_control_buff_list_set_all",
            arg = 0
        }}
        local btn_x = 10
        for _, spec in ipairs(buttons) do
            local btn = my_buffs_control:CreateOrGetControl("button", spec.name, btn_x, 50, 115, 30)
            AUTO_CAST(btn)
            btn:SetText(spec.text)
            btn:SetTextTooltip(spec.tooltip)
            btn:SetEventScript(ui.LBUTTONUP, spec.script)
            btn:SetEventScriptArgNumber(ui.LBUTTONUP, spec.arg)
            btn_x = btn_x + 120
        end
    end
    -- ボタン列のぶん下げる
    local buff_list_gb = my_buffs_control:CreateOrGetControl("groupbox", "buff_list_gb", 10, 85, 480,
        my_buffs_control:GetHeight() - 95)
    AUTO_CAST(buff_list_gb)
    buff_list_gb:SetSkinName("bg")
    buff_list_gb:RemoveAllChild()
    local all_buffs = {}
    local pruned = My_buffs_control_buff_list_each(ctrl_text or "", function(buff_cls, buff_name, image_name)
        table.insert(all_buffs, {
            cls = buff_cls,
            name = buff_name,
            image = image_name,
            is_checked = g.my_buffs_control_settings.buffs[tostring(buff_cls.ClassID)] ~= 0
        })
    end)
    -- **掃除で実際に消したときだけ保存すること。** この関数は一覧を開く入口であると同時に、
    -- 検索の実行関数でもある(g.setup_incremental_search から My_buffs_control_buff_list_search
    -- 経由で呼ばれる)。無条件に保存すると**打鍵のたびに .dat を書き直す**ことになる
    -- (実機で、設定画面を 30 秒触った間に 9 回)。
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
    -- 設定画面から開くサブ画面なので、設定画面と同じく ESC で閉じられるようにする。
    -- × は ui.DestroyFrame だけなので esc_register_destroy でよい。
    -- 検索し直すとこの関数がもう一度呼ばれるが、esc_register は同じフレームの古い登録を
    -- 外してから積み直すので二重には積まれない(この窓自身の開き直しなので最前面で正しい)。
    g.esc_register_destroy(addon_name_lower .. "my_buffs_control")
end

-- 表は非表示リスト。**非表示は 0 で持ち、表示へ戻すときは行ごと消す。**
-- 表示を 1 として持つと、表示するバフ全部を持つ許可リストへ逆戻りする
-- (それが .dat 3816 行の元だった。理由は My_buffs_control_save_settings のコメント)。
function My_buffs_control_buff_toggle(frame, ctrl, str_buff_id, num)
    local is_check = ctrl:IsChecked()
    if is_check == 1 then
        g.my_buffs_control_settings.buffs[str_buff_id] = nil
    else
        g.my_buffs_control_settings.buffs[str_buff_id] = 0
    end
    My_buffs_control_save_settings()
end

-- my_buffs_control ここまで

