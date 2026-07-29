function _nexus_addons_p_save_settings()
    g.save_json(g.settings_path, g.settings)
end

function _nexus_addons_p_load_settings()
    local settings = g.load_json(g.settings_path)
    if not settings then
        settings = {}
    end
    local changed = false
    local valid_keys = {}
    for _, entry in ipairs(g._nexus_addons_p) do
        valid_keys[entry.key] = true
    end
    -- アドオン登録キー以外のトップレベル設定はここに列挙する。書き忘れると
    -- すぐ下のプルーニングで毎回消され、設定を保存しても復元できない。
    valid_keys.verbose_log = true
    for key, _ in pairs(settings) do
        if not valid_keys[key] then
            settings[key] = nil
            changed = true
        end
    end
    local force_update_keys = {
        name = true,
        config_func = true,
        frame_use = true,
        old_init_func = true
    }
    for _, entry in ipairs(g._nexus_addons_p) do
        local key = entry.key
        local default_data = entry.data
        if not settings[key] then
            settings[key] = {}
            for k, v in pairs(default_data) do
                settings[key][k] = v
            end
            changed = true
        elseif type(settings[key]) == "table" then
            for k, v in pairs(default_data) do
                if settings[key][k] == nil then
                    settings[key][k] = v
                    changed = true
                elseif force_update_keys[k] and settings[key][k] ~= v then
                    settings[key][k] = v
                    changed = true
                end
            end
            for k, v in pairs(settings[key]) do
                if default_data[k] == nil then
                    settings[key][k] = nil
                    changed = true
                end
            end
        end
    end
    if settings.verbose_log == nil then
        settings.verbose_log = 0 -- 既定は OFF（普段のチャットを埋めない）
        changed = true
    end
    g.settings = settings
    if changed then
        _nexus_addons_p_save_settings()
    end
end

function _NEXUS_ADDONS_P_ON_INIT(addon, frame)
    g.addon = addon
    g.frame = frame
    -- 購読(addon:RegisterMsg)は ON_INIT ごとに張り直す。ここで空にすることで、この後の
    -- register_msg がメッセージごとに 1 回ずつ打ち直す(詳細は g.register_msg)。
    -- 本家検出で下の early return に入る経路も購読を張るので、判定より前に置く。
    g.msg_registered_cycle = {}
    -- 返るのは「国UI名」で、日本語は "Japanese"、韓国語は "Korean" ではなく "kr"。
    -- 言語名と2文字コードが混在するのはゲーム側の仕様で、こちらの typo ではない。
    -- 根拠: クライアントの systemoption.lua / barrack_charlist.lua が言語ドロップダウンを
    -- 組む際に lanUIString ~= "kr" と lanUIString ~= "Japanese" を並べて比較している。
    -- (norisan さんの native_lang アドオンも {Japanese="ja", kr="ko"} で対応付けている)
    -- "kr" を "Korean" に直すと韓国語表示が全滅するので触らないこと。
    g.lang = option.GetCurrentCountry()
    g.cid = session.GetMySession():GetCID()
    g.active_id = session.loginInfo.GetAID()
    g.settings_path = string.format("../addons/%s/%s/settings.json", addon_name_lower, g.active_id)
    if not g.folders_created then
        g.mkdir_new_folder()
        g.folders_created = true
    end
    -- B: 本家の設定引き継ぎ。フォルダ作成後・設定ロード(GAME_START)前に済ませる必要がある。
    -- セッション中に何度 ON_INIT が呼ばれても実行は 1 回でよいので結果をキャッシュする。
    if g.migrate_result == nil then
        g.migrate_result = g.migrate_from_origin() or false
    end
    -- A: 本家と同時インストールされている場合は共存できないので何も初期化しない。
    -- 告知だけは出したいので GAME_START(全アドオンのロード完了後)にだけ入る。
    if g.detect_origin_addon() then
        g.origin_conflict = true
        g.register_msg('GAME_START', '_nexus_addons_p_GAME_START')
        return
    end
    g.login_name = session.GetMySession():GetPCApc():GetName()
    g.map_name = session.GetMapName()
    g.map_id = session.GetMapID()
    g.current_channel = session.loginInfo.GetChannel() -- 0が1ch
    g.pc = GetMyPCObject()
    g.REGISTER = {}
    g.register_msg('GAME_START', '_nexus_addons_p_GAME_START')
    g.register_msg('GAME_START_3SEC', '_nexus_addons_p_GAME_START_3SEC')
    -- ESC はここ 1 箇所だけで受ける(アドオン側で個別に購読しないこと。理由は g.esc_register)
    g.register_msg('ESCAPE_PRESSED', '_nexus_addons_p_ESCAPE_PRESSED')
    g.setup_hook(_nexus_addons_p_CHAT_SYSTEM, "CHAT_SYSTEM")
end

-- ESC の直後にシステムメニューを調べる予約。ESC を受けたその場では、まだ
-- ゲーム側がメニューを開いていない可能性があるので、更新スクリプトで一拍置く。
-- 1 を返すと回り続けるので、1 回調べたら必ず 0 を返して外れること。
function _nexus_addons_p_probe_esc_menu_tick()
    pcall(g.probe_esc_menu)
    return 0
end

function _nexus_addons_p_schedule_esc_probe(reason)
    -- ツリー走査は安くないので、詳細ログ ON のときだけ予約する
    -- (g.probe_esc_menu 側でも同じ判定をするが、そこまで行かせない)。
    if not g.settings or g.settings.verbose_log ~= 1 then
        return
    end
    -- g.frame は実機で nil になることがある(ON_INIT の frame 引数を当てにできない)。
    -- g.queue_message と同じフォールバックで引き直し、それでも取れなければ
    -- 予約を諦めてその場で調べる。以前は nil で即 return していたため、
    -- 実機では調査そのものが一度も走っていなかった。
    local frame = g.frame or ui.GetFrame(addon_name_lower)
    if not frame then
        g.vlog("esc_probe: フレームが取れないので即時実行 reason=%s", tostring(reason))
        pcall(g.probe_esc_menu)
        return
    end
    -- ESC 連打で同じ更新スクリプトを積み直さない。
    -- HaveUpdateScript が false ではなく nil を返すことがあるので `== false` では見ない
    -- (それだと条件が常に偽になり、予約が一度も走らない)。
    local ok, have = pcall(function()
        return frame:HaveUpdateScript("_nexus_addons_p_probe_esc_menu_tick")
    end)
    if ok and have then
        g.vlog("esc_probe: 予約済みなので積み直さない reason=%s", tostring(reason))
        return
    end
    local scheduled, err = pcall(function()
        frame:RunUpdateScript("_nexus_addons_p_probe_esc_menu_tick", 0.3)
    end)
    g.vlog("esc_probe: 予約 %s reason=%s have=%s%s", scheduled and "OK" or "FAILED", tostring(reason), tostring(have),
        scheduled and "" or (" err=" .. tostring(err)))
    if not scheduled then
        -- 更新スクリプトが使えない環境だと一生調べられないので、その場で直接調べる
        -- (システムメニューが開く前の状態かもしれないが、候補名の実在は分かる)。
        pcall(g.probe_esc_menu)
    end
end

-- ESC で閉じるのは、開いている自作ウィンドウのうち一番手前の 1 枚だけ。
-- 登録は各アドオンがフレームを開いたところで g.esc_register する(詳細は core/00_header.lua)。
function _nexus_addons_p_ESCAPE_PRESSED()
    -- ESC は 2 経路で届きうる: g.esc_sync_scp が仕込む ui.SetEscapeScp と、
    -- ゲームからアドオンへ一斉配信される ESCAPE_PRESSED。どちらが来る(あるいは両方来る)かは
    -- クライアント任せなので、同じ押下で二重に閉じないよう直後の再入は捨てる。
    if g.esc_is_reentry() then
        return
    end
    g.esc_last_ms = imcTime.GetAppTimeMS()
    -- ゲーム側の ESC は chat_memberlist 由来のフレームを「隠す」が、それは IsVisible() に
    -- 出ない。こちらの開閉判定と食い違うので、この押下に合わせて畳んでおく
    -- (詳細は core/90_addons_menu.lua の addons_menu_on_escape)。
    pcall(addons_menu_on_escape)
    -- 押下ごとのログはここでは出さない。**ESC の反応が悪くなるため**(実機で確認)。
    -- g.vlog は 1 行ごとに ui.SysMsg とファイルの open/write/close を行うので、
    -- 押すたびに必ず走る経路に置くと、その分だけ入力の処理が重くなる。
    -- 実際に閉じたときは下で 1 行出るし、割り込み先の出し入れは esc_scp の行で追える。
    -- ここを一時的に戻すのは「ESC がこちらへ届いているか」を疑うときだけにすること。
    local entry = g.esc_pop_top()
    if not entry then
        -- 閉じるものが無いのに ESC が回ってきた = SetEscapeScp を戻し損ねている。
        -- そのままだとシステムメニューが開けなくなるので、ここで必ず戻す。
        -- ここは force を付けない。押下のたびに SetEscapeScp("") を撃つと、
        -- ゲーム側が自分の都合で入れた割り込み先(開いているダイアログを閉じる等)まで
        -- 消してしまい、次の 1 回が空振りする = ESC の効きが悪くなる。
        -- こちらが握ったままの状態は GAME_START の force 同期で必ず解ける。
        g.esc_sync_scp()
        -- 右クリックの付け直しもここではやらない。ESC は押すたびに必ず通る経路なので、
        -- 毎回 UI を触る処理を積むほど反応が鈍る(ログで実証済み。上のコメント参照)。
        -- 付け直しは GAME_START(マップ移動のたび)に任せる。もし移動を挟まずに
        -- 外れる事例が出たら、mini_addons が sysmenu へ掛けているような
        -- 数秒周期の更新スクリプトで直すこと。ESC の経路には戻さない。
        -- ここで esc_probe を回していたが、押下のたびに 30 行以上の vlog(ファイル書き込み +
        -- チャットへのシステムメッセージ)が走り、ESC の反応を悪くしていた。
        -- 調べたかったこと(システムメニュー = フレーム "apps")は分かったので、
        -- 定期的な調査は起動後 1 回(GAME_START)だけにする。
        return
    end
    local close_func = _G[entry.close]
    if type(close_func) ~= "function" then
        g.vlog("ESCAPE_PRESSED: close func not found frame=%s func=%s", tostring(entry.frame), tostring(entry.close))
        g.esc_sync_scp()
        return
    end
    g.vlog("ESCAPE_PRESSED: close %s (残り %d)", tostring(entry.frame), #g.esc_stack)
    -- 閉じる処理が転んでもゲーム側の ESC 処理を巻き込まないよう握る
    local ok, err = pcall(close_func)
    if ok then
        -- ESCAPE_PRESSED を購読している側(indun_panel)が「この押下は使われた」と
        -- 判断できるよう、実際に閉じられたときだけ印を置く。転んだ押下(まだ表示が
        -- 残っているかもしれない)や閉じるものが無かった押下は「使っていない」扱いにし、
        -- 購読側/ゲーム側へそのまま渡す。ここで無条件に印を置くと、閉じ損ねているのに
        -- indun_panel のトグルを無効化してしまう。
        g.esc_closed_ms = imcTime.GetAppTimeMS()
    else
        g.vlog("ESCAPE_PRESSED: close failed frame=%s err=%s", tostring(entry.frame), tostring(err))
    end
    -- 最後の 1 枚を閉じたら ESC をゲームへ返す
    g.esc_sync_scp()
end

-- A: 本家が同居している間は機能を止め、削除を促すメッセージだけ出す。
-- CHAT_SYSTEM は GAME_START 直後だと流れてしまうことがあるため、
-- 既存の pending_messages と同じく UpdateScript 経由で遅延表示する。
function _nexus_addons_p_origin_conflict_notice(frame)
    if g.conflict_notified then
        return
    end
    g.conflict_notified = true
    g.pending_messages = {}
    local notice, migrated
    if g.lang == "Japanese" then
        notice =
            "{ol}{#FF6347}[Nexus Addons P] 本家 Nexus Addons が同時にインストールされています{nl}競合するため Nexus Addons P の機能はすべて停止しました{nl}dataフォルダから本家の _nexus_addons-⛄-*.ipf を削除して、ゲームを再起動してください"
        migrated =
            "{ol}{#00BFFF}[Nexus Addons P] 本家の設定を引き継ぎました。本家を削除して再起動すれば、そのままの設定で使えます"
    else
        notice =
            "{ol}{#FF6347}[Nexus Addons P] The original Nexus Addons is installed at the same time{nl}All Nexus Addons P features are disabled to avoid conflicts{nl}Please remove _nexus_addons-⛄-*.ipf from your data folder and restart the game"
        migrated =
            "{ol}{#00BFFF}[Nexus Addons P] Your settings were copied from the original. They will be used once you remove it and restart"
    end
    table.insert(g.pending_messages, notice)
    if g.migrate_result == "copied" or g.migrate_result == "partial" then
        table.insert(g.pending_messages, migrated)
    end
    frame:RunUpdateScript("_nexus_addons_p_chat_system", 0.5)
end

function _nexus_addons_p_CHAT_SYSTEM(msg, color)
    if msg == "None" then
        return
    end
    g.FUNCS["CHAT_SYSTEM"](msg, color)
end

-- 成功した init の詳細ログ。ON のアドオンだけに絞る。
-- on_init は ON/OFF によらず全アドオン分呼ばれる(<key>_on_teardown を定義していない
-- アドオンは、OFF 側でもフレームの後始末に on_init を使う)ため、
-- 絞らないとマップ移動のたびに 48 行流れて、肝心の行が埋もれる。
-- 失敗(FAILED)は OFF でも知りたいので、そちらは絞らずそのまま出す。
function _nexus_addons_p_vlog_init(name, duration)
    local setting = g.settings and g.settings[name]
    if not setting or setting.use ~= 1 then
        return
    end
    g.vlog("init: %s (%dms)", name, duration)
end

-- 登録されているのに on_init が見つからなかったときの報告。
--
-- **黙って飛ばしてはいけない。** 呼び出し元は type(func) == "function" のときだけ
-- 動くので、定義そのものが失われていると成功も失敗もログに出ず、
-- 「そのアドオンだけ何も起きない」という一番分かりにくい形になる。実際に
-- mini_addons と market_favorite_rebuild が揃って無反応になった報告があり、
-- この 2 つは配布 .lua のうち _nexus_addons_p_conclude.lua 側にだけ入っているため、
-- 「片方のファイルが読み込まれていない」を疑う手掛かりがここしか無かった。
--
-- OFF のときは <key>_on_teardown 側の「teardown:」行、または各アドオンの on_init 自身が
-- 出す「use=0 のため初期化しない」が出るので、この行が出るのは**定義が届いていない**
-- ときだけ。両者を混同しないこと。
-- 初期化はマップ移動のたびに走るため、報告はアドオンごとに 1 回だけにする。
-- **印を立てるのは実際に出力できたときだけ**(g.vlog の戻り値で判定する)。既定は
-- OFF なので、先に印を立てるとログインの初回パスで黙って消費され、後からログを
-- ON にしてもこの行が二度と出ない = 塞ぎたかった死角がそのまま残る。
function _nexus_addons_p_vlog_missing_init(name)
    if g.missing_init_logged[name] then
        return
    end
    if g.vlog("{#FF6347}init: %s の on_init が見つからない{/} (定義が読み込まれていない可能性)", name) then
        g.missing_init_logged[name] = true
    end
end

-- 機能 OFF のアドオンの後始末を、ここ 1 箇所で振り分ける。
--
-- on_init は ON/OFF によらず呼ばれる契約なので、「OFF なら畳む」を各アドオンが
-- 自前で書く必要があった。**この規約はコメントにしか無く、実際に守り漏れていた**
-- (登録済み 51 本のうち 18 本が on_init で use を見ておらず、party_marker と
--  boss_direction は OFF のままタイマーを回し続けていた)。
--
-- そこで <key>_on_teardown を定義したアドオンだけ、use == 0 のとき on_init の
-- 代わりにそちらを呼ぶ。**opt-in にしてあるのが要点**で、定義していないアドオンは
-- 従来どおり on_init が呼ばれる。OFF でもフック張りなどで on_init を通す必要がある
-- アドオン(market_voucher / characters_item_serch)を壊さないため。
--
-- 畳むのは OFF になった 1 回だけ。on_init はマップ移動のたびに全アドオン分走るので、
-- 毎回呼ぶと OFF に固定している人のマップ移動で購読表の全走査が延々と繰り返される。
-- 一度畳めば on_init を呼ばない = 何も作られないので、もう一度畳む必要は無い。
g.addon_torn_down = g.addon_torn_down or {}

-- 戻り値: 呼ぶべき関数, 種別("init" / "teardown" / "skip")
function _nexus_addons_p_resolve_init_func(key)
    local setting = g.settings and g.settings[key]
    local teardown_func = _G[key .. "_on_teardown"]
    if setting and setting.use == 0 and type(teardown_func) == "function" then
        if g.addon_torn_down[key] then
            return nil, "skip"
        end
        g.addon_torn_down[key] = true
        return teardown_func, "teardown"
    end
    -- ON に戻った(あるいは teardown を持たない)ときは印を落とす。落とさないと
    -- 次に OFF にしたとき「畳み済み」と誤判定して後始末が走らない。
    g.addon_torn_down[key] = nil
    return _G[key .. "_on_init"], "init"
end

function _nexus_addons_p_init_addons(is_toggle, toggled_addon_name, _nexus_addons_p)
    g.error_count = 0
    local function safe_call(name)
        local func, mode = _nexus_addons_p_resolve_init_func(name)
        if mode == "skip" then
            return
        end
        if type(func) == "function" then
            local func_start = imcTime.GetAppTimeMS()
            local success, err = pcall(func)
            local func_end = imcTime.GetAppTimeMS()
            local duration = func_end - func_start
            if not success then
                g.error_count = g.error_count + 1
                local label = mode == "teardown" and "on_teardown" or "on_init"
                local err_msg = string.format("Error during %s of '%s': %s", label, name, tostring(err))
                ts(err_msg)
                g.log_to_file(err_msg)
                g.vlog("{#FF6347}%s: %s FAILED{/} %s", mode, name, tostring(err))
            elseif mode == "teardown" then
                -- OFF になった 1 回だけなので流れない。「OFF にしたのにまだ動く」の
                -- 報告で、畳めたのかどうかがここで分かる。
                g.vlog("teardown: %s (機能 OFF のため畳んだ)", name)
            else
                _nexus_addons_p_vlog_init(name, duration)
            end
        else
            _nexus_addons_p_vlog_missing_init(name)
        end
    end
    if not g.loaded then
        -- GAME_START で積んだ引き継ぎ通知を消さないよう、既存があればそのまま使う
        g.pending_messages = g.pending_messages or {}
        for _, entry in ipairs(g._nexus_addons_p) do
            local key = entry.key
            local old_init_func_name = entry.data.old_init_func
            if old_init_func_name and old_init_func_name ~= "" and _G[old_init_func_name] then
                local message
                old_init_func_name = string.lower(string.gsub(old_init_func_name, "_ON_INIT", ""))
                old_init_func_name = string.gsub(old_init_func_name, "_", " ")
                if g.lang == "Japanese" then
                    message = string.format(
                        "{ol}{#FF6347}[Nexus Addons P] 競合する古いアドオン '%s' が検出されました{nl}'%s' を無効化しました{nl}dataフォルダから、古いアドオンのipfファイルを削除してください",
                        old_init_func_name, key)
                else
                    message = string.format(
                        "{ol}{#FF6347}[Nexus Addons P] Conflicting old addon '%s' detected{nl}Disabled '%s'{nl}Please remove the old addon's ipf file from your data folders",
                        old_init_func_name, key)
                end
                table.insert(g.pending_messages, message)
                if g.settings[key] then
                    if g.settings[key].use == 1 then
                        g.settings[key].use = 0
                        _nexus_addons_p_save_settings()
                    end
                else
                    ts(string.format("[Nexus Addons P] Error: Settings for '%s' not found.", key))
                end
            end
        end
    end
    if not g.loaded then
        _nexus_addons_p:SetUserValue("FUNC_INDEX", 1)
        _nexus_addons_p:RunUpdateScript("_nexus_addons_p_async_safe_call", 0.1)
        return
    else
        for _, entry in ipairs(g._nexus_addons_p) do
            local key = entry.key
            if is_toggle then
                if key == toggled_addon_name then
                    safe_call(key)
                end
            else
                safe_call(key)
            end
        end
    end
    if not is_toggle then
        if g.error_count == 0 then
            ts("All add-ons initialized successfully.")
        else
            ts(string.format("%d add-on(s) failed to initialize...", g.error_count))
        end
    end
end

function _nexus_addons_p_async_safe_call(_nexus_addons_p)
    local start_time = imcTime.GetAppTimeMS()
    local time_limit = 6
    local process_count = 0
    local max_process_per_frame = 2
    while true do
        local func_index = _nexus_addons_p:GetUserIValue("FUNC_INDEX")
        local entry = g._nexus_addons_p[func_index]
        if not entry then
            if #g.pending_messages > 0 and not g.loaded then
                _nexus_addons_p:RunUpdateScript("_nexus_addons_p_chat_system", 0.5)
            end
            g.loaded = true
            -- 初回ロードが最後まで届いたことをログに残す。**この行が出ていなければ、
            -- 途中で止まっている**(更新スクリプトが外れた / どれかの on_init が返って
            -- こない)。止まると FUNC_INDEX 以降のアドオンは初期化されず、g.loaded も
            -- false のままなので次の GAME_START_3SEC で 1 件目からやり直しになる。
            -- 分割実行は 0.1 秒ごとに 2 件ずつなので、登録の末尾にあるアドオンほど
            -- 遅れて有効になる(実測で GAME_START の 5 秒後)。「あのアドオンだけ効かない」
            -- という報告では、まずこの行と当該アドオンの init 行の有無を見ること。
            g.vlog("非同期の初期化が完了(%d 件 / 失敗 %d 件)", func_index - 1, g.error_count or 0)
            if g.error_count == 0 then
                ts("All add-ons initialized successfully.")
            else
                ts(string.format("%d add-on(s) failed to initialize...", g.error_count))
            end
            return 0
        end
        local func_name = entry.key
        -- 初回ロードもマップ移動時と同じ振り分けを通す(_nexus_addons_p_resolve_init_func)。
        -- ここを素の on_init のままにすると、OFF で起動した人だけ後始末が走らない。
        local init_func, mode = _nexus_addons_p_resolve_init_func(func_name)
        if mode == "skip" then
            init_func = nil
        end
        if type(init_func) == "function" then
            local func_start = imcTime.GetAppTimeMS()
            local success, err = pcall(init_func)
            local func_end = imcTime.GetAppTimeMS()
            local duration = func_end - func_start
            ts(string.format("init ADDON: %s (%d ms)", func_name, duration))
            if not success then
                g.error_count = g.error_count + 1
                local label = mode == "teardown" and "on_teardown" or "on_init"
                local err_msg = string.format("Error during %s of '%s': %s", label, func_name, tostring(err))
                ts(err_msg)
                g.log_to_file(err_msg)
                g.vlog("{#FF6347}%s: %s FAILED{/} %s", mode, func_name, tostring(err))
            elseif mode == "teardown" then
                g.vlog("teardown: %s (機能 OFF のため畳んだ)", func_name)
            else
                _nexus_addons_p_vlog_init(func_name, duration)
            end
        elseif mode ~= "skip" then
            _nexus_addons_p_vlog_missing_init(func_name)
        end
        _nexus_addons_p:SetUserValue("FUNC_INDEX", func_index + 1)
        process_count = process_count + 1
        if (imcTime.GetAppTimeMS() - start_time) >= time_limit or process_count >= max_process_per_frame then
            return 1
        end
    end
end

function _nexus_addons_p_chat_system(_nexus_addons_p)
    if #g.pending_messages > 0 then
        local msg = table.remove(g.pending_messages, 1)
        CHAT_SYSTEM(msg)
        return 1
    end
    return 0
end

function _nexus_addons_p_frame_init()
    local list_frame_name = addon_name_lower .. "list_frame"
    local list_frame = ui.CreateNewFrame("notice_on_pc", list_frame_name, 0, 0, 10, 10)
    AUTO_CAST(list_frame)
    list_frame:RemoveAllChild()
    list_frame:SetSkinName("test_frame_low")
    list_frame:EnableHittestFrame(1)
    list_frame:SetTitleBarSkin("None")
    list_frame:SetLayerLevel(92)
    local title = list_frame:CreateOrGetControl('richtext', 'title', 20, 10, 10, 30)
    AUTO_CAST(title)
    title:SetText("{#000000}{s25}Nexus Addons P" .. " {s15}ver " .. ver)
    local close_button = list_frame:CreateOrGetControl('button', 'close_button', 0, 0, 20, 20)
    AUTO_CAST(close_button)
    close_button:SetImage("testclose_button")
    close_button:SetGravity(ui.RIGHT, ui.TOP)
    close_button:SetEventScript(ui.LBUTTONUP, "_nexus_addons_p_list_close")
    local list_gb = list_frame:CreateOrGetControl("groupbox", "list_gb", 10, 40, 0, 0)
    AUTO_CAST(list_gb)
    list_gb:SetSkinName("bg")
    list_gb:RemoveAllChild()
    list_gb:EnableHitTest(1)
    list_frame:ShowWindow(1)
    local base_num = 25
    local col1_x = 20
    local row_height = 35
    local max_width1 = 0
    local max_width2 = 0
    for i, entry in ipairs(g._nexus_addons_p) do
        local name = entry.data.name
        local current_y = (i <= base_num) and (i - 1) * row_height or (i - (base_num + 1)) * row_height
        local name_text = list_gb:CreateOrGetControl('richtext', 'name_text' .. i, col1_x, current_y + 10, 10, 30)
        AUTO_CAST(name_text)
        name_text:SetText("{ol}{s20}" .. name)
        if i <= base_num then
            max_width1 = math.max(max_width1, name_text:GetWidth())
        else
            max_width2 = math.max(max_width2, name_text:GetWidth())
        end
    end
    local col2_x = col1_x + max_width1 + 180
    for i, entry in ipairs(g._nexus_addons_p) do
        local child_addon_name = entry.key
        local data = entry.data
        local use = g.settings[child_addon_name].use
        local buttons_x, current_y
        if i <= base_num then
            buttons_x = col1_x + max_width1 + 25
            current_y = (i - 1) * row_height
        else
            local name_text = GET_CHILD(list_gb, 'name_text' .. i)
            name_text:SetPos(col2_x, name_text:GetY())
            buttons_x = col2_x + max_width2 + 25
            current_y = (i - (base_num + 1)) * row_height
        end
        local use_toggle = list_gb:CreateOrGetControl('picture', "use_toggle" .. i, buttons_x, current_y + 10, 60, 25)
        AUTO_CAST(use_toggle)
        use_toggle:SetImage(use == 1 and "test_com_ability_on" or "test_com_ability_off")
        use_toggle:SetEnableStretch(1)
        use_toggle:EnableHitTest(1)
        use_toggle:SetTextTooltip("{ol}ON/OFF")
        use_toggle:SetEventScript(ui.LBUTTONUP, "_nexus_addons_p_toggle_addons")
        use_toggle:SetEventScriptArgString(ui.LBUTTONUP, child_addon_name)
        if data.frame_use then
            local config_btn = list_gb:CreateOrGetControl('button', 'config_btn' .. i, buttons_x + 65, current_y + 10,
                25, 25)
            AUTO_CAST(config_btn)
            config_btn:SetSkinName("None")
            config_btn:SetTextTooltip(g.lang == "Japanese" and "{ol}設定フレーム呼出し" or
                                          "Call Settings Frame")
            config_btn:SetText("{img config_button_normal 25 25}")
            if data.config_func and data.config_func ~= "" then
                config_btn:SetEventScript(ui.LBUTTONUP, data.config_func)
            end
        end
        local help_btn = list_gb:CreateOrGetControl('button', 'help_btn' .. i, buttons_x + 100, current_y + 5, 40, 30)
        AUTO_CAST(help_btn)
        help_btn:SetText("{ol}{img question_mark 20 15}")
        -- 登録リストに追加したのに翻訳を書き忘れると、ここの index で一覧フレームごと
        -- 落ちる(この関数は pcall の外)。説明が無いだけで一覧は開けるようにしておく。
        local trans = g._nexus_addons_p_trans[child_addon_name] or {}
        local tooltip_text
        if g.lang == "Japanese" then
            tooltip_text = trans.ja
        elseif g.lang == "kr" then
            tooltip_text = trans.kr
        else
            tooltip_text = trans.etc
        end
        tooltip_text = tooltip_text or ("{ol}" .. data.name)
        help_btn:SetTextTooltip(tooltip_text)
        help_btn:SetSkinName("test_pvp_btn")
    end
    local total_width = col2_x + max_width2 + 200
    -- タイトル行の右側に一括操作ボタン(全て OFF / バックアップ / 復元)を並べるので、
    -- タイトルと重ならない幅を確保する。幅はアドオン名の長さで決まり、翻訳やフォントで
    -- 変わりうるため、固定値ではなく実際のタイトル幅から計算する。
    total_width = math.max(total_width, title:GetWidth() + 40 + g.maintenance_buttons_width())
    local total_height = base_num * row_height + 70
    list_frame:Resize(total_width, total_height)
    list_gb:Resize(list_frame:GetWidth() - 20, list_frame:GetHeight() - 50)
    g.create_maintenance_buttons(list_frame, total_width)
    list_frame:SetPos(310, 100)
    return list_frame
end

function _nexus_addons_p_list_close(frame)
    local frame_to_close = {"boss_direction_settings", "auto_repair_settings", "instant_cc_settings",
                            "my_buffs_control_setting", "revival_timer_setting", "vakarine_equip_config_frame",
                            "easy_buff", "always_status_settings", "lets_go_home_setting", "characters_item_serch",
                            "sub_map_setting_frame", "separate_buff_custom_buff_list", "save_quest_setting",
                            "sub_slotset_setting", "Battle_ritual_setting", "Battle_ritual_skill_list",
                            "Battle_ritual_buff_list", "get_event_msg_setting", "archeology_helper_setting"}
    for _, suffix in ipairs(frame_to_close) do
        local frame_name = addon_name_lower .. suffix
        local frame_to_close = ui.GetFrame(frame_name)
        if frame_to_close then
            ui.DestroyFrame(frame_name)
        end
    end
    ui.DestroyFrame(frame:GetName())
end

-- メニューから呼ぶ入口。開いていれば閉じる。
-- _nexus_addons_p_frame_init を直接メニューに割り当てないのは、あちらが
-- 「ON/OFF を切り替えた後に一覧を作り直す」用途でも呼ばれるため。あそこをトグルにすると、
-- アドオンを 1 つ切り替えるたびに一覧が閉じてしまう。
function _nexus_addons_p_list_toggle()
    local frame = ui.GetFrame(addon_name_lower .. "list_frame")
    if frame and frame:IsVisible() == 1 then
        _nexus_addons_p_list_close(frame)
        return
    end
    _nexus_addons_p_frame_init()
end

function _nexus_addons_p_toggle_addons(list_gb, use_toggle, child_addon_name, num)
    local old_init_func_name = nil
    for _, entry in ipairs(g._nexus_addons_p) do
        if entry.key == child_addon_name then
            old_init_func_name = entry.data.old_init_func
            break
        end
    end
    if old_init_func_name and old_init_func_name ~= "" and _G[old_init_func_name] and
        not (old_init_func_name == "INSTANTCC_ON_INIT" and _G["instant_cc_on_init"]) then
        local message = nil
        old_init_func_name = string.lower(string.gsub(old_init_func_name, "_ON_INIT", ""))
        old_init_func_name = string.gsub(old_init_func_name, "_", " ")
        if g.lang == "Japanese" then
            message = string.format(
                "[Nexus Addons P] 競合する古いアドオン '%s' が検出されました '%s' を有効化できません{nl}dataフォルダから、古いアドオンのipfファイルを削除してください",
                old_init_func_name, child_addon_name)
        else
            message = string.format(
                "[Nexus Addons P] Conflicting old addon '%s' detected Cannot enable '%s'{nl}Please remove the old addon's ipf file from your data folders",
                old_init_func_name, child_addon_name)
        end
        if message then
            imcAddOn.BroadMsg("NOTICE_Dm_!", message, 5.0)
        end
        return
    end
    if g.settings[child_addon_name].use == 1 then
        g.settings[child_addon_name].use = 0
        local msg = g.lang == "Japanese" and g.settings[child_addon_name].name .. " 無効にしました" or
                        g.settings[child_addon_name].name .. " Disabled"
        imcAddOn.BroadMsg("NOTICE_Dm_!", msg, 5.0)
    else
        g.settings[child_addon_name].use = 1
        local msg = g.lang == "Japanese" and g.settings[child_addon_name].name .. " 有効にしました" or
                        g.settings[child_addon_name].name .. " Enabled"
        imcAddOn.BroadMsg("NOTICE_Dm_Bell", msg, 5.0)
    end
    _nexus_addons_p_init_addons(true, child_addon_name)
    _nexus_addons_p_save_settings()
    _nexus_addons_p_frame_init()
end

function _nexus_addons_p_GAME_START(_nexus_addons_p, msg)
    -- A: ON_INIT の時点ではまだ本家が読み込まれていない可能性があるため、
    -- 全アドオンのロードが終わっているここで必ず再判定する。
    if g.origin_conflict or g.detect_origin_addon() then
        g.origin_conflict = true
        _nexus_addons_p_origin_conflict_notice(_nexus_addons_p)
        return
    end
    -- if not g.settings then
    _nexus_addons_p_load_settings()
    -- end
    -- マップ移動でゲーム側が ESC の割り込み先を戻している可能性があるので、
    -- 「設定済み」の記憶を捨てて次の同期で入れ直させる(g.esc_sync_scp 参照)。
    -- 捨てるだけでは足りない。記憶が無い状態(false 扱い)と「開いている窓が無い(want=false)」が
    -- 一致するため、こちらが握ったままでも clear が飛ばず ESC を飲み続ける。
    -- ここで force 付きの同期を 1 回だけ入れて、実際の値をこちらの意図に合わせ直す。
    g.esc_scp_set = nil
    g.esc_sync_scp(true)
    -- 以降の init ログを読むときの起点。ここより前は g.settings が無く vlog も黙る。
    -- GAME_START はマップ移動のたびに来るので、この行はマップごとの区切りにもなる
    -- (ログファイルはここでは作り直さない。詳細は 00_header.lua の vlog_write)。
    g.vlog("===== GAME_START v%s lang=%s map=%s(%s) cid=%s", tostring(ver), tostring(g.lang),
        tostring(session.GetMapName()), tostring(g.get_map_type()), tostring(g.cid))
    -- 取り込み部分(mini_addons / market_favorite_rebuild / ancient_monster_bookshelf)まで
    -- 読み込みが届いたか。この 3 つは連結の**末尾**にあるので、ここが欠けていれば
    -- 「どこかで落ちて、そこから後ろが全部消えている」ことを意味する。
    -- 配布 .lua が 2 本だった頃はこの 3 つだけが落ちる形だったが、1 本化した今は
    -- **落ちた地点より後ろが全部無い**(core かもしれないし、途中のアドオンかもしれない)。
    -- どこまで届いたかは stage で見る。読み方:
    --   conclude=無      … 取り込み部分が実行されていない
    --   defs=無          … 実行されたが定義に届いていない(stage がどこまで進んだかを示す)
    --   fallback=有      … 本家検出をその場判定で代用した。**異常ではない**
    --   require=...      … 読み込み時の require に失敗した(空なら正常)
    --
    -- **判定材料は必ずこの 1 行に載せること。** 以前は fallback と require を別行にして
    -- 「セッション中 1 回だけ」に絞っていたため、途中から取ったログでは出力済みだと消えて
    -- しまい、**出ていないことを根拠に誤った原因を組み立てた**(実際に 1 回やった)。
    -- GAME_START ごとに 1 行なら流れないので、状態は毎回まとめて出す。
    -- **問題が起きていなくても出す**(正常時の見え方が分からないと異常だと判断できないため)。
    local defs_ok = type(_G["market_favorite_rebuild_on_init"]) == "function"
    local status = string.format("conclude=%s defs=%s stage=%s fallback=%s require=%s",
        g.conclude_loaded and "有" or "無", defs_ok and "有" or "無", tostring(g.conclude_stage),
        g.detect_origin_fallback and "有" or "無", g.conclude_require_failed or "なし")
    if g.conclude_loaded and defs_ok then
        g.vlog("%s", status)
    else
        g.vlog("{#FF6347}%s{/} (読み込みが最後まで届いていません)", status)
        -- **詳細ログ(既定 OFF)だけで済ませない。** この状態は一覧に項目が並び、ON にもできるのに
        -- 押しても何も起きないという、利用者から見て最も分かりにくい壊れ方をする。
        -- 起動ごとに 1 回だけ知らせる(マップ移動のたびに出すと鬱陶しい)。
        --
        -- **stage をこのメッセージにも載せること。** 1 本化した今、この状態は
        -- 「読み込みが途中で落ちた」以外を意味しない。落ちた地点を示す値は stage しか
        -- 無いのに、それが詳細ログ(既定 OFF)にしか出ないと、報告を受けても
        -- 「ログを ON にして再現してください」から始めることになる。1 行載せておけば
        -- 画面のコピーだけで切り分けの起点が手に入る。
        --
        -- 逆に「.ipf が 1 つだけか確認してください」はもう書かない。2 本立ての頃の
        -- 案内で、今は既に満たしている条件を確認させるだけになり、利用者の次の手を奪う。
        if not g.conclude_notified then
            g.conclude_notified = true
            g.queue_message(g.lang == "Japanese" and
                string.format(
                    "{ol}{#FF6347}[Nexus Addons P] 読み込みが途中で止まりました (stage=%s){nl}一部のアドオンが一覧に出ない・押しても反応しない状態です。お手数ですが、この行をそのまま添えてご報告ください",
                    tostring(g.conclude_stage)) or
                string.format(
                    "{ol}{#FF6347}[Nexus Addons P] Loading stopped partway (stage=%s){nl}Some addons will be missing from the list or unresponsive. Please report this message as-is",
                    tostring(g.conclude_stage)))
        end
    end
    -- 他アドオンが _G["ADDONS"] を作り直していた形跡。繋ぎ直して救えた場合も残す
    -- (詳細は conclude_header.lua)。滅多に立たないので、こちらは 1 回だけでよい。
    -- 印は出力できたときだけ立てる(_nexus_addons_p_vlog_missing_init と同じ理由)。
    if g.addons_table_rebuilt and not g.addons_table_rebuilt_logged then
        if g.vlog("{#FF6347}_G.ADDONS が他アドオンに作り直されていた{/} (conclude 側で本体を繋ぎ直した)") then
            g.addons_table_rebuilt_logged = true
        end
    end
    -- 調査: ESC 経由が届かない環境でも候補名の実在だけは分かるよう、起動後 1 回は
    -- ここからも調べる。ゲーム側のフレームは表示していなくても実体があることが多いので、
    -- システムメニューを開かなくても名前は当たりうる。マップ移動のたびに走らせると
    -- 実行回数の上限(g.esc_probe_max)を移動だけで使い切ってしまうため、1 回だけにする。
    -- 印を立てるのは「実際に調べられるとき」だけにする。詳細ログはログイン後に
    -- ON にすることが多く、無条件に立てると『GAME_START では OFF だったので
    -- 飛ばしたのに、印だけ立っていて二度と調べられない』状態になる(実機で発生)。
    -- この条件なら、ログを ON にしてマップを移動すれば調べ直せる。
    if not g.esc_probe_did_boot and g.settings and g.settings.verbose_log == 1 then
        g.esc_probe_did_boot = true
        _nexus_addons_p_schedule_esc_probe("game_start")
    end
    -- 本家からの引き継ぎは ON_INIT(設定を読む前)で走るので、そのときは vlog が黙る。
    -- 何件コピーできたかはここまで持ち越して出す(g.migrate_from_origin)。
    if g.migrate_summary then
        g.vlog("%s", g.migrate_summary)
        g.migrate_summary = nil
    end
    if g.migrate_result == "copied" or g.migrate_result == "partial" then
        g.migrate_result = false
        g.pending_messages = g.pending_messages or {}
        table.insert(g.pending_messages, g.lang == "Japanese" and
            "{ol}{#00BFFF}[Nexus Addons P] 本家 Nexus Addons の設定を引き継ぎました" or
            "{ol}{#00BFFF}[Nexus Addons P] Settings were carried over from the original Nexus Addons")
        _nexus_addons_p:RunUpdateScript("_nexus_addons_p_chat_system", 0.5)
    end
    _G["norisan"] = _G["norisan"] or {}
    _G["norisan"]["MENU"] = _G["norisan"]["MENU"] or {}
    local menu_data = {
        name = "Nexus Addons P",
        -- アイコンは置き場所ごとに変える(core/90_addons_menu.lua の collect_items 参照)。
        --   icon         … 右上のフローティングメニュー側。従来どおり sysmenu 系の画像
        --   icon_sysmenu … 右下のシステムメニュー(右クリック)側。周りが apps のボタン群
        --                  なので、そこに合わせて「出席報酬確認」と同じ画像を使う。
        --                  定義は ui.ipf の fixframe/apps/apps.xml:
        --                    <button name="attendanceBtn" ... image="calendar_button_normal" .../>
        icon = "sysmenu_coll",
        icon_sysmenu = "calendar_button_normal",
        -- システムメニュー側のセルは apps のボタンと同寸(44)なので、実寸で描けば揃う。
        icon_inflate_sysmenu = 0,
        -- もう一度押したら閉じられるよう、直接 frame_init ではなくトグル側を割り当てる
        func = "_nexus_addons_p_list_toggle",
        image = ""
    }
    _G["norisan"]["MENU"][addon_name] = menu_data
    -- 相乗り側が別名でメニューを作っていたら壊してから、こちらの名前で作り直す。
    -- frame_name を入れるのは相乗り側なので、まだ誰も入れていなければ nil。
    -- 初回ログインは常にこの状態なので、nil を ui.GetFrame へ渡さないよう
    -- 名前がある場合だけ引く(順序を入れ替えただけで、壊す条件は変えていない)。
    local frame_name = _G["norisan"]["MENU"].frame_name
    if frame_name and frame_name ~= "norisan_menu_frame" and ui.GetFrame(frame_name) then
        ui.DestroyFrame(frame_name)
    end
    frame_name = "norisan_menu_frame"
    local menu_frame = ui.GetFrame(frame_name)
    -- norisan_menu_frame という名前は他の norisan 系アドオンと共有していて、向こうが
    -- 先に旧定義(chat_memberlist 由来 = ESC で閉じられる)で作っていることがある。
    -- その場合はここで消えない自前の定義(notice_on_pc 由来)へ作り替える。
    --
    -- 「ESC で消えたら直す」方式は成立しない。ESC による非表示は IsVisible() に
    -- 反映されないので、隠れたことを検出する手段が無いため。土台を先に置き換える。
    if not menu_frame or not g.addons_menu_frame_owned then
        _G["norisan"]["MENU"].frame_name = frame_name
        addons_menu_create_frame()
    end
    -- 表示するかどうかは設定(sysmenu_only)で決まるので、ここでは無条件に ShowWindow(1)
    -- しない。以前はここで出し直していたため、設定で消してもマップ移動で復活していた。
    pcall(addons_menu_apply_visibility)
    -- システムメニュー(sysmenu の "system" ボタン)の右クリックに Addons Menu を割り当てる。
    -- ゲーム側が sysmenu を作り直すと外れるので、マップ移動のたびに付け直す
    -- (core/90_addons_menu.lua の addons_menu_attach_to_sysmenu)。
    pcall(addons_menu_attach_to_sysmenu)
    g.setup_hook(_nexus_addons_p_APPS_TRY_MOVE_BARRACK, "APPS_TRY_MOVE_BARRACK")
    _nexus_addons_p_fast_func()
end

function _nexus_addons_p_GAME_START_3SEC(_nexus_addons_p, msg)
    -- A: GAME_START で初めて競合が判明した場合、ここは ON_INIT で既に登録済みなので止める
    if g.origin_conflict then
        return
    end
    _nexus_addons_p_init_addons(false, nil, _nexus_addons_p)
    g.register_msg('FPS_UPDATE', '_nexus_addons_p_update_frames')
end

function _nexus_addons_p_fast_func(_nexus_addons_p)
    if g.separate_buff_custom_settings and g.settings.separate_buff_custom.use == 1 and
        g.separate_buff_custom_settings.tracking == 1 then
        Separate_buff_custom_frame_move()
    end
    if g.quickslot_operate_settings and g.quickslot_operate_settings.straight then
        Quickslot_operate_redraw_slots()
    end --
    if g.indun_panel_settings and g.settings.indun_panel.use == 1 then
        Indun_panel_frame_init()
    end
    if g.awh_settings then
        another_warehouse_on_init()
    end
end

-- _nexus_addons_p_update_frames は FPS_UPDATE = 毎フレーム呼ばれる。以前は毎フレーム
-- この 15 要素のテーブルを作り直し、そのつど addon_name_lower との連結でフレーム名を
-- 組み立てていたので、読み込み時に一度だけ組み立てて使い回す。
-- (要素の追加・削除はここだけ触ればよい。city_hidden は街/インスタンスで出さない印)
local update_check_frames = {}
do
    local frame_keys = {"always_status", "pick_item_tracker", "monster_kill_count", "debuff_notice",
                        "guild_event_warp", "lets_go_home", "relic_change", "vakarine_equip", "sub_map",
                        "save_quest", "indun_panel", "Battle_ritual", "muteki", "au_map", "tos_btn"}
    for i, frame_key in ipairs(frame_keys) do
        update_check_frames[i] = {
            name = addon_name_lower .. frame_key,
            city_hidden = (frame_key == "pick_item_tracker")
        }
    end
end

function _nexus_addons_p_update_frames()
    local root_frame = ui.GetFrame("_nexus_addons_p")
    if root_frame and root_frame:IsVisible() == 0 then
        root_frame:ShowWindow(1)
    end
    -- マップ種別の取得は g.get_map_type() 側でマップ単位にメモ化済みなので、
    -- ここで重ねてキャッシュしない(以前は同じ行で 2 回呼んでいた分だけが無駄だった)。
    for _, entry in ipairs(update_check_frames) do
        local frame = ui.GetFrame(entry.name)
        if frame and frame:IsVisible() == 0 then
            if entry.city_hidden then
                local map_type = g.get_map_type()
                if map_type ~= "City" and map_type ~= "Instance" then
                    AUTO_CAST(frame)
                    frame:ShowWindow(1)
                end
            else
                AUTO_CAST(frame)
                frame:ShowWindow(1)
            end
        end
    end
    -- × ボタンで閉じた場合はどこからも通知が来ないので、ここで実際の表示状態に合わせる。
    -- ただしスタックが空(= ESC 対象を 1 枚も開いていない)なら見るものが無いので、
    -- 毎フレーム esc_top() でスタックを walk する無駄を省いて呼ばない。× ボタンで
    -- 閉じても登録は解除されずスタックに残る(esc_top が死んだ登録として掃除する)ため、
    -- 「閉じ忘れの検出」はスタックが空でない限り従来どおり効く。
    if #g.esc_stack > 0 then
        g.esc_sync_scp()
    end
end

function _nexus_addons_p_APPS_TRY_MOVE_BARRACK()
    Other_character_skill_list_save_enchant()
    Indun_list_viewer_save_current_char_counts()
    if g.settings.instant_cc and g.settings.instant_cc.use == 1 then
        if Instant_cc_APPS_TRY_LEAVE_ then
            Instant_cc_APPS_TRY_LEAVE_("Barrack")
            return
        end
    end
    if g.settings.indun_list_viewer and g.settings.indun_list_viewer.use == 1 then
        if Indun_list_viewer_CHECK_ALERT and Indun_list_viewer_CHECK_ALERT("Barrack") then
            return
        end
    end
    APPS_TRY_LEAVE("Barrack")
end
