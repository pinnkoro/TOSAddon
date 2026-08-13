-- どこでもメンバーインフォ機能
-- add は素の ui.AddContextMenuItem。横取り中に呼ばれるので、自分が足す項目まで
-- 差し替え対象(opts.drop)に引っかからないよう、素の方を通す。
function Mini_addons_add_memberinfo_menu(context, target_name, add)
    add = add or ui.AddContextMenuItem
    if g.settings.memberinfo == 1 and target_name and target_name ~= "" then
        add(context, "-----", "None")
        add(context, ScpArgMsg("ShowInfomation"), string.format("ui.Chat('/memberinfo %s')", target_name))
    end
end

-- ===== 素のコンテキストメニューへ項目を足す仕掛け(Issue #53) =====
--
-- 以前はここで **素の関数の中身をそのまま書き写して** メンバーインフォ項目を足していた。
-- 素が変わってもエラーにならず、静かに古い実装のままになるのが問題だった。
--
-- 今は「素を呼び、その最中の ui.AddContextMenuItem / ui.OpenContextMenu を一時的に
-- 横取りする」形にしてある。差し替えも追加も **メニューが開く前** に済むので、
-- 「開いた後から項目を足せるか」というクライアント依存の挙動に頼らない。
--
-- **横取りは素の関数を呼んでいる同期実行の間だけ**。Lua は単一スレッドなので、
-- この間に他のメニューが割り込むことはなく、抜けるときは必ず元へ戻す(pcall の失敗時も)。
-- ui.* を書き換えられないクライアントでは横取りを諦めて素をそのまま呼ぶ。
-- そのときは追加項目が出ないが、ゲーム標準のメニューは壊れない。可否は verbose_log に出す。
local mini_addons_ui_patchable = nil

local function mini_addons_can_patch_ui()
    if mini_addons_ui_patchable == nil then
        local saved = ui.OpenContextMenu
        local probe = function()
        end
        pcall(function()
            ui.OpenContextMenu = probe
        end)
        mini_addons_ui_patchable = rawequal(ui.OpenContextMenu, probe)
        pcall(function()
            ui.OpenContextMenu = saved
        end)
        -- 実機で最初にメニューを開いたときに 1 回だけ出る。false なら
        -- 「どこでもメンバーインフォ」の項目が出ないので、ここを見れば切り分けられる。
        core_g.vlog("mini_addons: ui.* の差し替え可否 = %s", tostring(mini_addons_ui_patchable))
    end
    return mini_addons_ui_patchable
end

-- 「キャンセル」項目の表示名。素のメニューはどれも最後がキャンセルなので、その手前へ
-- 自分の項目を差し込む。ClMsg と ScpArgMsg のどちらで引いているかは関数ごとに違う。
local function mini_addons_cancel_captions()
    local list = {}
    local seen = {}
    for _, f in ipairs({ScpArgMsg, ClMsg}) do
        local ok, caption = pcall(f, "Cancel")
        if ok and type(caption) == "string" and caption ~= "" and not seen[caption] then
            seen[caption] = true
            table.insert(list, caption)
        end
    end
    return list
end

-- 素の origin_func_name を呼び、その最中のメニュー組み立てへ割り込む。
--   opts.drop   … この文字列を含む項目を落とす(素の項目を自分のものへ差し替えるとき)
--   opts.insert … function(context, add) で項目を足す。add は素の ui.AddContextMenuItem
--                 (自分が足したものが opts.drop に引っかからないよう、素の方を渡す)。
--                 キャンセルの手前へ差し込み、見つからなければ開く直前に足す
-- 戻り値は素の戻り値をそのまま返す(SHOW_PC_CONTEXT_MENU は context を返し、
-- 呼び元の _SHOW_PC_CONTEXT_MENU が位置合わせに使う)。
local function mini_addons_menu_hook(origin_func_name, opts, ...)
    local origin = g.FUNCS[origin_func_name]
    if not origin then
        core_g.vlog("mini_addons: %s の素の実装が控えに無い", origin_func_name)
        return
    end
    if not mini_addons_can_patch_ui() then
        return origin(...)
    end
    local saved_add = ui.AddContextMenuItem
    local saved_open = ui.OpenContextMenu
    local cancels = mini_addons_cancel_captions()
    local pending = opts.insert
    local restored = false
    local function restore()
        if not restored then
            restored = true
            ui.AddContextMenuItem = saved_add
            ui.OpenContextMenu = saved_open
        end
    end
    local function flush(context)
        if pending then
            local add_items = pending
            pending = nil
            local ok, err = pcall(add_items, context, saved_add)
            if not ok then
                core_g.vlog("mini_addons: %s への項目追加で失敗: %s", origin_func_name, tostring(err))
            end
        end
    end
    ui.AddContextMenuItem = function(context, caption, ...)
        -- **opts.drop が空文字でないことを確かめること。** string.find(caption, "", 1, true) は
        -- 常に 1 を返すので、空文字だと Cancel まで含めて素の項目が全部消える
        -- (ScpArgMsg が引けずに "" を返した場合に起きる。cancels 側も同じ理由で
        --  caption ~= "" を見ている)
        if opts.drop and opts.drop ~= "" and type(caption) == "string" and
            string.find(caption, opts.drop, 1, true) then
            return
        end
        if pending and type(caption) == "string" then
            for _, cancel in ipairs(cancels) do
                if string.find(caption, cancel, 1, true) then
                    flush(context)
                    break
                end
            end
        end
        return saved_add(context, caption, ...)
    end
    ui.OpenContextMenu = function(context)
        -- 開く前に戻しておく。この先で素が別のメニューを開いても横取りしない
        -- (SHOW_PC_CONTEXT_MENU が露店キャラで POPUP_DUMMY を呼ぶような経路)。
        restore()
        flush(context)
        return saved_open(context)
    end
    local ok, ret = pcall(origin, ...)
    restore()
    if not ok then
        core_g.vlog("mini_addons: 素の %s の呼び出しで失敗: %s", origin_func_name, tostring(ret))
        return
    end
    return ret
end

function Mini_addons_CHAT_RBTN_POPUP(frame, chat_ctrl)
    local target_name = chat_ctrl:GetUserValue("TARGET_NAME")
    return mini_addons_menu_hook("CHAT_RBTN_POPUP", {
        insert = function(context, add)
            Mini_addons_add_memberinfo_menu(context, target_name, add)
        end
    }, frame, chat_ctrl)
end

function Mini_addons_POPUP_GUILD_MEMBER(parent, ctrl)
    local aid = parent:GetUserValue("AID")
    if aid == "None" then
        aid = ctrl:GetUserValue("AID")
    end
    local member_info = session.party.GetPartyMemberInfoByAID(PARTY_GUILD, aid)
    local name = member_info and member_info:GetName()
    return mini_addons_menu_hook("POPUP_GUILD_MEMBER", {
        insert = function(context, add)
            Mini_addons_add_memberinfo_menu(context, name, add)
        end
    }, parent, ctrl)
end

function Mini_addons_CONTEXT_PARTY(frame, ctrl, aid)
    -- 統合サーバの観戦メニューは、素が項目 1 つを足してその場で開いて終わる。
    -- キャンセルも無いので、ここへは何も足さずそのまま回す。
    if session.world.IsIntegrateServer() == true and session.world.IsIntegrateIndunServer() == false then
        local origin = g.FUNCS["CONTEXT_PARTY"]
        if origin then
            return origin(frame, ctrl, aid)
        end
        return
    end
    local member_info = session.party.GetPartyMemberInfoByAID(PARTY_NORMAL, aid)
    local name = member_info and member_info:GetName()
    local handle = member_info and member_info:GetHandle()
    return mini_addons_menu_hook("CONTEXT_PARTY", {
        -- ON のときは素の「詳細情報を見る」を、同じ表示名の /memberinfo 項目へ差し替える。
        -- **OFF のときは落とさない**(素の項目が消えてしまう)。
        drop = (g.settings.memberinfo == 1) and ScpArgMsg("ShowInfomation") or nil,
        insert = function(context, add)
            if handle then
                add(context, "----", "None")
                add(context, ScpArgMsg("RequestFriendlyFight"), string.format("REQUEST_FIGHT(%d)", handle))
            end
            Mini_addons_add_memberinfo_menu(context, name, add)
        end
    }, frame, ctrl, aid)
end

function Mini_addons_SHOW_PC_CONTEXT_MENU(handle)
    local pc_obj = world.GetActor(handle)
    local target_info = info.GetTargetInfo(handle)
    -- 足すのは「他人の PC のメニュー」だけ。露店キャラ(素が POPUP_DUMMY へ回す)と
    -- 自分自身(GM 用のデバッグメニュー)には足さないので、そのまま素へ回す。
    -- 判定は素と同じものを使う。
    if pc_obj == nil or target_info == nil or target_info.IsDummyPC == 1 or pc_obj:IsMyPC() == 1 or
        info.IsPC(pc_obj:GetHandleVal()) ~= 1 then
        local origin = g.FUNCS["SHOW_PC_CONTEXT_MENU"]
        if origin then
            return origin(handle)
        end
        return
    end
    local family_name = pc_obj:GetPCApc():GetFamilyName()
    return mini_addons_menu_hook("SHOW_PC_CONTEXT_MENU", {
        -- ON のときは素の「見比べる」を /memberinfo へ差し替える(表示は別物だが役割が同じ)。
        drop = (g.settings.memberinfo == 1) and ScpArgMsg("Auto_SalPyeoBoKi") or nil,
        insert = function(context, add)
            Mini_addons_add_memberinfo_menu(context, family_name, add)
        end
    }, handle)
end

function Mini_addons_POPUP_FRIEND_COMPLETE_CTRLSET(parent, ctrlset)
    local aid = ctrlset:GetUserValue("AID")
    local name
    if aid ~= "" then
        local f = session.friends.GetFriendByAID(FRIEND_LIST_COMPLETE, aid)
        if f then
            name = f:GetInfo():GetFamilyName()
        end
    end
    return mini_addons_menu_hook("POPUP_FRIEND_COMPLETE_CTRLSET", {
        insert = function(context, add)
            Mini_addons_add_memberinfo_menu(context, name, add)
        end
    }, parent, ctrlset)
end

