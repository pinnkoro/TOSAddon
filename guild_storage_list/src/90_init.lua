-- 単体版の入口。
--
-- **初期化関数の名前はアドオン名を大文字にしたもの**(`_guild_storage_list` なら
-- `_GUILD_STORAGE_LIST_ON_INIT`)。先頭の `_` を落とすと呼ばれず、何も出ない。
--
-- ゲームからのメッセージは自分で購読する(Nexus Addons P の共通基盤は使えない)。
--   GAME_START      … ログイン / マップ移動のたびに来る。ここで組み立て直す
--   ESCAPE_PRESSED  … ESC。中身は共通部品の g.esc_on_escape()
function _GUILD_STORAGE_LIST_ON_INIT(addon, frame)
    g.frame = frame
    g.addon = addon
    addon:RegisterMsg("GAME_START", "_GUILD_STORAGE_LIST_GAME_START")
    -- **ESC の購読はこの 1 か所だけ。** 開いた窓は g.esc_register で積み、
    -- 閉じるのは一番手前の 1 枚だけにする(shared/src/40_esc.lua)
    addon:RegisterMsg("ESCAPE_PRESSED", "_GUILD_STORAGE_LIST_ESCAPE_PRESSED")
end

function _GUILD_STORAGE_LIST_ESCAPE_PRESSED()
    g.esc_on_escape()
end

-- ログイン後に 1 回、その後はマップ移動のたびに呼ばれる。
-- **毎回通る前提で書くこと**(フックは g.setup_hook が 1 回だけにする)。
function _GUILD_STORAGE_LIST_GAME_START()
    g.lang = option.GetCurrentCountry()
    g.cid = session.GetMySession():GetCID()
    g.active_id = session.loginInfo.GetAID()
    -- 設定の置き場所。配布のルールはアカウントごと、出席データなどの書き出しは直下
    g.create_folder(string.format("../addons/%s", "_guild_storage_list"),
        string.format("../addons/%s/mkdir.txt", "_guild_storage_list"))
    g.create_folder(string.format("../addons/%s/%s", "_guild_storage_list", g.active_id),
        string.format("../addons/%s/%s/mkdir.txt", "_guild_storage_list", g.active_id))
    g.load_core_settings()
    -- **ESC の割り込み先を入れ直す。** マップ移動で落ちることがあるので、
    -- 覚えている状態を無視して必ず設定し直す(Nexus Addons P の GAME_START と同じ作法)
    g.esc_sync_scp(true)
    if g.nexus_has_guild_storage_list() then
        return
    end
    g.migrate_from_nexus()
    local ok, err = pcall(guild_storage_list_on_init)
    if not ok then
        ui.SysMsg("{ol}{#FF6347}[GSL]{/} 初期化に失敗しました: " .. tostring(err))
        return
    end
    g.register_menu_item()
    -- × ボタンで窓を閉じたときも ESC の割り込み先を戻せるよう、0.5 秒ごとに表示と合わせる
    -- (Nexus Addons P は FPS_UPDATE で、Icor Planner はマーケットの見回りでやっている)
    if g.frame ~= nil then
        g.frame:RunUpdateScript("Guild_storage_list_watch", 0.5)
    end
    g.vlog("guild_storage_list: 初期化した v%s (lang=%s aid=%s cid=%s)", g.ver, tostring(g.lang),
        tostring(g.active_id), tostring(g.cid))
end

function Guild_storage_list_watch()
    if #g.esc_stack > 0 or g.esc_scp_set then
        g.esc_sync_scp()
    end
    g.check_hooks()
    return 1
end

-- Nexus Addons P v2.13.x(Guild Storage List を同梱していた版)が一緒に入っているか。
--
-- **入っていたら何もしない。** 本体の関数(Guild_storage_list_*)はグローバルなので、
-- 後から読まれた方が上書きし、窓や送付窓のフックが両方の g を行き来して壊れる
-- (送付窓への入力が二重に走る・設定が片方にしか保存されない)。
-- あちらの本体テーブルに Guild Storage List の定数が居るかで判定する(v2.14.0 で外した)。
function g.nexus_has_guild_storage_list()
    local nexus = _G["ADDONS"] and _G["ADDONS"]["norisan"] and _G["ADDONS"]["norisan"]["_NEXUS_ADDONS_P"]
    if type(nexus) ~= "table" or nexus.guild_storage_list_const == nil then
        return false
    end
    if not g.nexus_conflict_warned then
        g.nexus_conflict_warned = true
        ui.SysMsg("{ol}{#FF6347}[GSL]{/} Guild Storage List を同梱した古い Nexus Addons P が入っています。" ..
                      "Nexus Addons P を v2.14.0 以降へ更新してください(それまでこちらは動きません)")
    end
    g.vlog("{#FF6347}guild_storage_list: 古い Nexus Addons P と同居しているので初期化しない{/}")
    return true
end

-- Nexus Addons P に入っていた頃の設定と出席データを引き継ぐ。
--
-- **自分側にまだ無いときだけ**写す(初回起動のとき)。既に自分の設定があるのに走らせると、
-- あちらの古い内容で上書きしてしまう(Icor Planner と同じ作法)。
-- 写すだけで、あちら側は消さない。
function g.migrate_from_nexus()
    local pairs_to_copy = {{
        mine = string.format("../addons/_guild_storage_list/%s/guild_storage_list.json", g.active_id),
        theirs = string.format("../addons/_nexus_addons_p/%s/guild_storage_list.json", g.active_id)
    }, {
        mine = "../addons/_guild_storage_list/link.txt",
        theirs = "../addons/_nexus_addons_p/guild_storage_list/link.txt"
    }}
    local copied, failed = 0, 0
    for _, p in ipairs(pairs_to_copy) do
        local file = io.open(p.mine, "r")
        if file then
            file:close()
        else
            local src = io.open(p.theirs, "r")
            if src then
                src:close()
                if g.copy_file(p.theirs, p.mine) then
                    copied = copied + 1
                    g.vlog("guild_storage_list: 引き継いだ %s -> %s", p.theirs, p.mine)
                else
                    failed = failed + 1
                    g.vlog("{#FF6347}guild_storage_list: 引き継ぎに失敗した %s{/}", p.theirs)
                end
            end
        end
    end
    -- **黙って引き継がないこと。** 配るもののルールが入った状態で開くので、
    -- どこから来た設定なのかが分からないと混乱する
    if copied > 0 then
        ui.SysMsg("{ol}{#00BFFF}[GSL]{/} Nexus Addons P の Guild Storage List の設定を引き継ぎました")
    end
    if failed > 0 then
        ui.SysMsg("{ol}{#FF6347}[GSL]{/} Nexus Addons P の設定の引き継ぎに失敗しました(手で写してください)")
    end
end

-- Addons Menu(norisan さん系のメニューボタン)へ相乗りする。
--
-- **_G["norisan"]["MENU"] は共有の待ち合わせ場所**で、ここへ {name, func, icon} を入れると
-- メニューを持っているアドオン(Nexus Addons P など)が拾って並べてくれる。
-- 持っていない環境でも、ギルド情報の「保管箱」タブの「文字で一覧」ボタンから開ける。
function g.register_menu_item()
    _G["norisan"] = _G["norisan"] or {}
    _G["norisan"]["MENU"] = _G["norisan"]["MENU"] or {}
    _G["norisan"]["MENU"]["Guild Storage List"] = {
        name = "Guild Storage List",
        func = "Guild_storage_list_open",
        -- **素に在る画像名を使うこと。** 無い名前だと絵が出ない(利用者は
        -- Addons Menu の設定から好きなアイコンへ変えられる)
        icon = "sysmenu_guild"
    }
end
