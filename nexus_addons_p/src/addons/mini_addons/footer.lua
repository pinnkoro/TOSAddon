-- ===== Nexus Addons P 用のフレーム生成とアダプタ(ここから) =====
--
-- 個別版の mini_addons.xml は「幅 0 / 高さ 0 / visible=true」の入れ物フレームだけで、
-- 中身のコントロールは持っていなかった。Mini_addons_GAME_START が
-- frame:RunUpdateScript(...) の土台として使うだけなので、同じものを生成する。
-- RunUpdateScript は表示状態のフレームで回るため、元 XML と同じく visible にする
-- (サイズ 0 かつスキン None なので画面には出ない)。
function Mini_addons_create_frame()
    local frame = ui.GetFrame(addon_name_lower)
    if not frame then
        frame = ui.CreateNewFrame("notice_on_pc", addon_name_lower, 0, 0, 0, 0)
    end
    AUTO_CAST(frame)
    frame:SetSkinName("None")
    frame:SetTitleBarSkin("None")
    frame:Resize(0, 0)
    frame:ShowWindow(1)
    return frame
end

-- 機能 OFF のときに片付けるフレーム(addon_name_lower に続く接尾辞)。
-- Lua にはフレームの列挙手段が無いので固定名で並べる。フレームを増やしたらここへも足すこと。
g.frame_suffixes = {"", "setting", "rank_frame", "buff_list", "event_frame", "reroll_option", "skill_reroll",
                    "_q7quest", "_channel", "frag_keep"}

-- 機能 OFF にされたときの後始末。
-- ゲーム側の UI へ加えた変更(チャット枠の改造やエフェクト設定など)は元に戻せないので、
-- 「反応しなくなり、自分のウィンドウが消える」ところまで。完全に戻すには再起動が要る。
function Mini_addons_teardown()
    -- 置換したグローバルを戻す。自分が今 _G に入っている分だけ戻す
    -- (手前に別のフックが居るときに戻すと、そのフックごと落としてしまう)。
    local restored, kept = 0, 0
    for name, my_func in pairs(g.hook_installed) do
        if _G[name] == my_func then
            _G[name] = g.FUNCS[name]
            g.hook_installed[name] = nil
            core_g.hook_owner_remove(name, my_func)
            restored = restored + 1
        else
            kept = kept + 1
        end
    end
    -- 配信役から自分のハンドラを外す。自分の関数はすべて Mini_addons_ 始まりで揃っている。
    local removed = core_g.unregister_msg_by_prefix("Mini_addons_")
    for _, suffix in ipairs(g.frame_suffixes) do
        ui.DestroyFrame(addon_name_lower .. suffix)
    end
    -- メニューボタンの相乗り項目も下ろす(登録先は norisan さんとの待ち合わせ名なので消さない)
    if _G["norisan"] and _G["norisan"]["MENU"] then
        _G["norisan"]["MENU"][addon_name] = nil
    end
    -- 再び ON にされたら GAME_START の補完からやり直す。ここを戻さないと、フック 72 個を
    -- 掛ける GAME_START_3SEC が次のマップ移動まで走らない。
    g.game_start_catch_up = false
    core_g.vlog("mini_addons: OFF のため後始末(フック戻し %d / 手前に別フック %d / 購読 %d 本)", restored, kept,
        removed)
end

-- 登録リストから呼ばれる入口。詳細は market_favorite_rebuild 側のコメントと同じ。
function mini_addons_on_init()
    if not core_g.settings or not core_g.settings.mini_addons or
        core_g.settings.mini_addons.use ~= 1 then
        -- on_init は ON/OFF によらず全アドオン分呼ばれ、OFF 側は後始末に使う契約
        -- (core/20_lifecycle.lua)。動いていたものを畳むのはここだけ。
        if g.initialized then
            g.initialized = false
            Mini_addons_teardown()
        else
            core_g.vlog("mini_addons: use=0 のため初期化しない")
        end
        return
    end
    -- 設定の引き継ぎは必ず ON_INIT より前に行う（理由は market_favorite_rebuild 側と同じ）。
    -- 個別版が持つのは設定とパーティーバフの 2 ファイル。列挙できないので直接並べる
    -- （buffs.json はパーティーバフ未設定なら存在しないが、その場合は黙って飛ばされる）。
    -- 結果(copied / partial / failed)は migrate 側がチャットへ出すので、ここでは受けない。
    core_g.migrate_individual_addon_settings("mini_addons", {
        {src = tostring(core_g.active_id) .. "_1.json", dst = "mini_addons.json"},
        {src = "buffs.json", dst = "mini_addons_buffs.json"}
    }, "Mini Addons")
    local frame = Mini_addons_create_frame()
    core_g.vlog("mini_addons: init frame=%s", tostring(frame ~= nil))
    Mini_addons_ON_INIT(core_g.addon, frame)
    -- ここで GAME_START / GAME_START_3SEC を自分で呼ぶ。
    --
    -- 個別版はアドオンの読み込み直後に ON_INIT が走るので、この 2 つの購読が
    -- イベント発生前に間に合っていた。同梱版では ON_INIT がまとめ版の init_addons まで
    -- 遅れる（実測で GAME_START から 5 秒後）ため、**今回ぶんの GAME_START と
    -- GAME_START_3SEC を両方とも取り逃がす**。その結果 mini_addons の初期化本体
    -- （登録とフック 72 個。メニュー項目の登録もここ）が丸ごと走らなかった。
    --
    -- 購読自体は残してあるので、次のマップ移動以降は通常どおりイベントで呼ばれる。
    -- ここは取り逃がした初回ぶんの穴埋めなので、セッション中 1 回だけでよい。
    --
    -- 「済んだ」印は**両方が成功してから**置く。先に置くと、GAME_START の途中で転んだとき
    -- (別配布アドオンのフレームが無い等)に GAME_START_3SEC = 初期化本体が走らないまま
    -- 二度と再試行されない。呼び出し元 safe_call の pcall が握るので気付けもしない。
    if not g.game_start_catch_up then
        core_g.vlog("mini_addons: 取り逃がした GAME_START を補完する")
        local ok_start, err_start = pcall(Mini_addons_GAME_START, frame)
        if not ok_start then
            core_g.vlog("{#FF6347}mini_addons: GAME_START の補完 FAILED{/} %s", tostring(err_start))
        end
        local ok_3sec, err_3sec = pcall(Mini_addons_GAME_START_3SEC, frame)
        if not ok_3sec then
            core_g.vlog("{#FF6347}mini_addons: GAME_START_3SEC の補完 FAILED{/} %s", tostring(err_3sec))
        end
        -- 転んだときは印を置かない = 次の on_init(マップ移動や ON/OFF)でもう一度試す。
        g.game_start_catch_up = ok_start and ok_3sec
    end
    g.initialized = true
end
-- ===== Nexus Addons P 用のフレーム生成とアダプタ(ここまで) =====
-- ここまで読めた印(詳細は conclude_header.lua)。do...end の中なので g は
-- mini_addons 自身のものになっている。まとめ版の g は core_g で参照する。
core_g.conclude_stage = "mini_addons"
end
-- mini_addons ここまで
