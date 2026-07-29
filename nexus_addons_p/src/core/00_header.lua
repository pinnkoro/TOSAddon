-- Nexus Addons P
-- norisan さんの Nexus Addons (v1.1.13 時点) を元にした派生版。
-- アドオン名 / 保存フォルダ / グローバル関数名をすべて `_nexus_addons_p` 系にリネームし、
-- 本家とは別系列として配布する。バージョンは本家と独立して 1.0.0 から採番する。
-- 本家の更新履歴は https://github.com/ajinorisan/TOSAddon-public を参照。
--
-- 1.0.0 本家 v1.1.13 からフォーク。本家と同時インストール時は自動で全機能を停止し、
--       本家の設定(../addons/_nexus_addons/<AID>/)を自分側へ引き継ぐ処理を追加。
local addon_name = "_NEXUS_ADDONS_P"
local addon_name_lower = string.lower(addon_name)
local author = "norisan"
local ver = "1.5.0"

_G["ADDONS"] = _G["ADDONS"] or {}
_G["ADDONS"][author] = _G["ADDONS"][author] or {}
_G["ADDONS"][author][addon_name] = _G["ADDONS"][author][addon_name] or {}
local g = _G["ADDONS"][author][addon_name]
-- 素の名前でも本体テーブルを引けるようにしておく。
--
-- **_G["ADDONS"] は全アドオン共有なので、他アドオンに作り直されうる。** 作法は
-- `_G["ADDONS"] = _G["ADDONS"] or {}` だが、素で `= {}` と書くアドオンや、
-- 再読み込み機能を持つアドオンが居ると、ここに入れた本体テーブルごと失われる。
-- そうなると **後から読まれる _nexus_addons_p_conclude.lua が別の空テーブルを掴み**、
-- そこに入っている mini_addons / market_favorite_rebuild が丸ごと動かなくなる
-- (詳細は conclude_header.lua)。main 側はこの local g を上位値として持ち続けるので
-- 気付けず、「一部のアドオンだけ無反応」という分かりにくい形だけが残る。
_G["_nexus_addons_p_core_g"] = g
local json = require("json")

local function ts(...)
    local num_args = select('#', ...)
    if num_args == 0 then
        print("ts() -- 引数がありません")
        return
    end
    local string_parts = {}
    for i = 1, num_args do
        local arg = select(i, ...)
        local arg_type = type(arg)
        local is_success, value_str = pcall(tostring, arg)
        if not is_success then
            value_str = "[tostringでエラー発生]"
        end
        table.insert(string_parts, string.format("(%s) %s", arg_type, value_str))
    end
    print(table.concat(string_parts, "   |   "))
end

local function print_all_child(ctrl, prefix)
    prefix = prefix or ""
    local count = ctrl:GetChildCount()
    for i = 0, count - 1 do
        local child = ctrl:GetChildByIndex(i)
        local name = child:GetName()
        local class_name = child:GetClassName()
        local w = child:GetWidth()
        local h = child:GetHeight()
        print(string.format("%sName: %s | Class: %s | Size: %dx%d", prefix, name, class_name, w, h))
        if child:GetChildCount() > 0 then
            print_all_child(child, prefix .. "  ")
        end
    end
end

-- フォルダを作る。作成済みを示すマーカーファイルが読めるときは何もしない。
-- os.execute は cmd.exe を同期起動する(コンソール窓が一瞬出ることもある)ので、
-- 起動のたびに空振りさせないためのガード。フォルダを作る箇所はすべてここを通すこと。
--
-- folder_path はそのまま cmd へ渡す。区切り文字の扱いは呼び出し側の既存挙動を
-- 変えないよう、こちらでは正規化しない(monster_kill_count はバックスラッシュ、
-- mkdir_new_folder はスラッシュのまま渡してきた)。
function g.create_folder(folder_path, marker_path)
    local file = io.open(marker_path, "r")
    if file then
        file:close()
        return
    end
    os.execute('mkdir "' .. folder_path .. '"')
    file = io.open(marker_path, "w")
    if file then
        file:write("A new file has been created")
        file:close()
    end
end

function g.mkdir_new_folder()
    g.create_folder(string.format("../addons/%s", addon_name_lower),
        string.format("../addons/%s/mkdir.txt", addon_name_lower))
    g.create_folder(string.format("../addons/%s/%s", addon_name_lower, g.active_id),
        string.format("../addons/%s/%s/mkdir.txt", addon_name_lower, g.active_id))
end

-- ===== 本家 Nexus Addons(_nexus_addons)との関係 =====
-- 本アドオンは本家をリネームした派生版なので、両方が同時にインストールされていると
-- 同じフレームが二重に出たり、同じバニラ関数を両方がフックして壊れる。そこで起動時に
--   A: 本家を検出したら自分の機能を一切初期化せず、削除を促すメッセージだけ出す
--   B: 自分側の設定がまだ無く本家の設定が残っていれば、それを丸ごと引き継ぐ
-- の 2 つを行う(呼び出しは core/20_lifecycle.lua の ON_INIT / GAME_START)。
local origin_name = "_NEXUS_ADDONS"
local origin_name_lower = string.lower(origin_name)

-- A: 本家 bundle が読み込まれているか。
-- ON_INIT の呼び出し順は保証されないため、ON_INIT で初めて存在する _ON_INIT 関数だけでなく、
-- bundle のファイル読み込み時点で作られる _G.ADDONS[author][origin_name] も判定材料にする。
function g.detect_origin_addon()
    if type(_G[origin_name .. "_ON_INIT"]) == "function" then
        return true
    end
    local addons = _G["ADDONS"]
    if type(addons) == "table" and type(addons[author]) == "table" and type(addons[author][origin_name]) == "table" then
        return true
    end
    return false
end

-- 1 ファイルをバイナリコピーする。xcopy が使えなかったときの最後の手段として、
-- 本家からの引き継ぎ(下)と設定のバックアップ/復元(core/30_maintenance.lua)から使う。
function g.copy_file(src_path, dst_path)
    local src_file = io.open(src_path, "rb")
    if not src_file then
        return false
    end
    local data = src_file:read("*all")
    src_file:close()
    if not data then
        return false
    end
    local dst_file = io.open(dst_path, "wb")
    if not dst_file then
        return false
    end
    local ok = dst_file:write(data)
    dst_file:close()
    return ok and true or false
end

-- 利用者へ 1 行チャットで知らせる。**vlog だけで済ませてよいのは調査用の情報だけ。**
-- 詳細ログは既定 OFF なので、設定の引き継ぎ失敗のように「黙って既定値に戻ったように
-- 見える」ことは、これで必ず表に出すこと。
-- 表示役は 1 通ずつ取り出して流す更新スクリプト(20_lifecycle.lua の
-- _nexus_addons_p_chat_system)。空になると 0 を返して自分で外れるので、掛け直しても増えない。
function g.queue_message(text)
    g.pending_messages = g.pending_messages or {}
    table.insert(g.pending_messages, text)
    local frame = g.frame or ui.GetFrame(addon_name_lower)
    if frame then
        frame:RunUpdateScript("_nexus_addons_p_chat_system", 0.5)
    end
end

-- B: 本家(_nexus_addons)の設定を引き継ぐ。戻り値は "copied" / "partial" / "failed" / nil(何もしない)。
-- 引き継ぎ単位は AID フォルダ丸ごと。
--
-- コピーは xcopy ではなく io で 1 ファイルずつ行う(core/30_maintenance.lua のバックアップと
-- 同じ方針。os.execute は GUI プロセスから呼ぶと必ずコンソール窓を作るため)。
-- 何をコピーするかはバックアップと同じ g.settings_file_names() から取る。本家は
-- このアドオンのフォーク元なので設定ファイルの名前は同じで、可変名の
-- monster_kill_count/<map_id>.json も同じ手(コピー元の monster_kill_count.json が持つ
-- map_ids から組み立てる)で拾える。一覧に無いファイルは引き継がれないが、その一覧は
-- docs/tests/test_core.lua [17] が bundle 内のパス文字列と突き合わせて守っている。
--
-- 実行条件は「自分側に settings.json が無い」= 実質初回起動時のみ。既に自分の設定が
-- あるときに走らせると本家の古い設定で上書きしてしまうため、この条件は必ず守ること。
function g.migrate_from_origin()
    local dst_dir = string.format("../addons/%s/%s", addon_name_lower, g.active_id)
    local dst_settings = dst_dir .. "/settings.json"
    local dst_file = io.open(dst_settings, "r")
    if dst_file then
        dst_file:close()
        return nil
    end
    local src_dir = string.format("../addons/%s/%s", origin_name_lower, g.active_id)
    local src_settings = src_dir .. "/settings.json"
    local src_file = io.open(src_settings, "r")
    if not src_file then
        return nil
    end
    src_file:close()
    local names = g.settings_file_names(src_dir)
    -- 引き継ぐマップ記録があるときだけサブフォルダを作りに行く(cmd が出るのはここだけ)
    g.ensure_settings_subfolder(dst_dir, names)
    local copied, failed = g.copy_settings_files(src_dir, dst_dir, names)
    -- 結果は文字列にして持ち越し、GAME_START で vlog へ出す。ここは ON_INIT の中で、
    -- 設定を読む前なので g.vlog がまだ黙る(g.settings が無い)。
    g.migrate_summary = string.format("migrate_from_origin: %s -> %s (%d 件, 失敗 %d 件)", src_dir, dst_dir,
        copied, failed)
    if copied == 0 then
        g.migrate_summary = "{#FF6347}" .. g.migrate_summary .. " 1 件もコピーできなかった{/}"
        return "failed"
    end
    -- 主たる設定が入ったかどうかで copied / partial を分ける
    -- (g.migrate_individual_addon_settings と同じ考え方)。
    local main_ok = io.open(dst_settings, "r")
    if main_ok then
        main_ok:close()
    end
    if not main_ok or failed > 0 then
        return "partial"
    end
    return "copied"
end

-- 個別配布版アドオンの設定を、同梱版の保存先へ引き継ぐ。
--
-- 同梱にあたって addon_name に _P を付けた結果、保存先が個別版と別フォルダに分かれる
-- （例: ../addons/mini_addons/ → ../addons/mini_addons_p/）。放っておくと、個別版から
-- 乗り換えた利用者の設定が全部消えたように見えるので、初回だけ中身を引き継ぐ。
--
-- **実行条件は「自分側にまだ無いとき」だけ**。これは g.migrate_from_origin と同じ思想で、
-- 既に自分の設定があるときに走らせると個別版の古い設定で上書きしてしまう。必ず守ること。
--
-- 個別版と同梱版はコードが同一なので設定のスキーマも同一。よってフォルダを丸ごと
-- コピーすれば済む（キーの詰め替えは要らない）。ここが、スキーマの器が異なる
-- 既存 39 アドオンの引き継ぎ（docs/INDIVIDUAL_ADDON_COEXIST_DESIGN.md §2-3）と違う点。
--
-- files には {src = ..., dst = ...} を並べる。
--   src … 個別版のフォルダ(../addons/<individual_lower>/)からの相対パス
--   dst … まとめ版の AID フォルダ(../addons/_nexus_addons_p/<AID>/)からの相対パス
-- **1 つ目は主たる設定ファイルにすること**。引き継ぎ済みかの判定にこれを使う。
-- src と dst で名前が変わるのは、個別版の置き方がばらばら（mini_addons は "<AID>_1.json"、
-- market_favorite_rebuild は "<AID>/settings.json"）なのに対し、同梱版では他の 48 アドオンと
-- 同じ "<アドオン名>.json" に揃えているため。
--
-- コピーは xcopy ではなく io で 1 ファイルずつ行う。os.execute は GUI プロセスから
-- 呼ぶと必ずコンソール窓を作り、ゲーム画面が一瞬点滅するため（CLAUDE.md「CMD をなるべく
-- 出さない」/ core/30_maintenance.lua のバックアップと同じ方針）。
-- その代償として「何をコピーするか」を呼び出し側が知っている必要がある。Lua には
-- ディレクトリ列挙が無く、列挙する唯一の手段が cmd だからここは避けられない。
--
-- コピー先のフォルダは、個別版由来のコード自身が読み込み時に作っている前提。
-- 無ければ io.open が失敗するだけで、設定は次回に持ち越される（実害は無い）。
-- 戻り値: nil=何もしなかった / "copied" / "partial" / "failed"
-- 結果は**呼び出し側が戻り値を捨てても伝わるよう、この中でチャットへも出す**。
-- display_name は案内に出す表示名(省略時は individual_lower)。
-- 「引き継ぎ元が見つからない」を報告済みかどうか。個別版を使っていない人では
-- 見つからないのが普通なので、アドオンごとに 1 回だけ出す(この関数はマップ移動の
-- たびに呼ばれる)。
g.migrate_probe_logged = g.migrate_probe_logged or {}

-- **"<名前>_p" のフォルダを引き継ぎ元にしてはいけない。**
-- 例えば ../addons/mini_addons_p/ は個別版のものではなく、**まとめ版自身が作る**
-- フォルダ(同梱 mini_addons の addon_name_lower が "MINI_ADDONS_P" で、
-- create_folder と log.dat がここを使う)。個別版は "mini_addons" のまま。
-- ここを引き継ぎ元に含めると、自分が置いた古いファイルを個別版の設定と誤認して
-- 取り込むことになる。探すのは個別版のフォルダ名だけにすること。
function g.migrate_individual_addon_settings(individual_lower, files, display_name)
    display_name = display_name or individual_lower
    local dst_dir = string.format("../addons/%s/%s", addon_name_lower, g.active_id)
    local dst_main = string.format("%s/%s", dst_dir, files[1].dst)
    local dst_file = io.open(dst_main, "r")
    if dst_file then
        dst_file:close()
        return nil
    end
    -- **見つからなかったことを黙って返さないこと。** 引き継ぎ元のフォルダ名が
    -- 想定と違うと、ここで何も言わずに抜けて既定値で始まる。利用者から見ると
    -- 「設定が引き継がれない」だけで、原因を追う手掛かりが一切残らない
    -- (実際に mini_addons のフォルダ名違いで発生した)。探した先まで残す。
    local src_dir = string.format("../addons/%s", individual_lower)
    local src_main = string.format("%s/%s", src_dir, files[1].src)
    local src_file = io.open(src_main, "r")
    if not src_file then
        if not g.migrate_probe_logged[individual_lower] and
            g.vlog("migrate: %s の個別版設定が見つからないので引き継がない (%s)", individual_lower, src_main) then
            g.migrate_probe_logged[individual_lower] = true
        end
        return nil
    end
    src_file:close()

    local copied, found = 0, 0
    for _, entry in ipairs(files) do
        local src_path = string.format("%s/%s", src_dir, entry.src)
        local probe = io.open(src_path, "r")
        if probe then
            probe:close()
            found = found + 1
            if g.copy_file(src_path, string.format("%s/%s", dst_dir, entry.dst)) then
                copied = copied + 1
            end
        end
    end

    if copied == 0 then
        g.vlog("{#FF6347}migrate: %s FAILED{/}", individual_lower)
        g.queue_message(g.lang == "Japanese" and
            string.format("{ol}{#FF6347}[Nexus Addons P] %s: 個別版の設定を引き継げませんでした（既定の設定で始めます）",
                display_name) or
            string.format("{ol}{#FF6347}[Nexus Addons P] %s: Could not carry over the standalone settings (starting from defaults)",
                display_name))
        return "failed"
    end
    -- 主たる設定が入ったかどうかで copied / partial を分ける。副次ファイル
    -- (mini_addons の buffs.json など)が元から無いのは正常なので partial にしない。
    local main_ok = io.open(dst_main, "r")
    if not main_ok then
        g.vlog("migrate: %s (partial, %d files)", individual_lower, copied)
        g.queue_message(g.lang == "Japanese" and
            string.format("{ol}{#FF6347}[Nexus Addons P] %s: 個別版の設定を一部しか引き継げませんでした", display_name) or
            string.format("{ol}{#FF6347}[Nexus Addons P] %s: Only part of the standalone settings could be carried over",
                display_name))
        return "partial"
    end
    main_ok:close()
    g.vlog("migrate: %s -> %s/ (copied, %d/%d files)", src_dir, addon_name_lower, copied, found)
    g.queue_message(g.lang == "Japanese" and
        string.format("{ol}{#00BFFF}[Nexus Addons P] %s: 個別版の設定を引き継ぎました", display_name) or
        string.format("{ol}{#00BFFF}[Nexus Addons P] %s: Settings were carried over from the standalone version",
            display_name))
    return "copied"
end

-- ===== メッセージの多重配信(ここから) =====
--
-- addon:RegisterMsg は **1 メッセージにつき 1 ハンドラしか持てない**。まとめ版は 1 つの
-- addon オブジェクトを全アドオンで共有しているので、同じメッセージを 2 か所から登録すると
-- 後勝ちで潰し合い、負けた側の機能が黙って死ぬ。エラーも出ないので気付けない。
--
-- 実際 mini_addons を同梱したときに GAME_START / GAME_START_3SEC / FPS_UPDATE /
-- BUFF_ADD / BUFF_UPDATE / DIALOG_CHANGE_SELECT / REQ_PLAYER_CONTENTS_RECORD の
-- 7 種が衝突し、mini_addons の初期化(登録とフック 72 個)がまるごと走っていなかった。
--
-- そこで購読はメッセージごとに 1 本だけにして、配信役から登録済みの各ハンドラへ配る。
--
-- **アドオン側で addon:RegisterMsg を直接呼ばないこと。必ず g.register_msg を通すこと。**
-- 直接呼ぶと配信役の購読ごと潰してしまい、そのメッセージに登録した全アドオンが停止する。
-- (自己完結型として同梱している mini_addons / market_favorite_rebuild は自分の g を
--  持っているので、そちらからは core_g.register_msg を呼ぶ)
g.msg_handlers = g.msg_handlers or {}
-- 今回の ON_INIT でもう購読を張ったメッセージ。ON_INIT ごとに 20_lifecycle.lua が空にする。
g.msg_registered_cycle = g.msg_registered_cycle or {}
-- 直近に購読を張ったときの addon オブジェクト(差し替わったときにログを出すためだけ)
g.msg_registered_addon = g.msg_registered_addon or {}
-- 配信で転んだ (メッセージ, ハンドラ) の組。同じ組を何度も報告しないための印。
g.msg_failed = g.msg_failed or {}
-- on_init が見つからなかったアドオン。報告済みの印(初期化はマップ移動のたびに走るので、
-- 絞らないと同じ行が毎回流れる)。詳細は core/20_lifecycle.lua の safe_call。
g.missing_init_logged = g.missing_init_logged or {}

function g.register_msg(msg, func_name)
    if type(msg) ~= "string" or type(func_name) ~= "string" then
        return
    end
    -- 配信役はメッセージごとに 1 つだけ作る。RegisterMsg はグローバル関数の「名前」を
    -- 取る仕様なので、名前を持つ実体をここで作ってから登録する。
    local dispatch_name = "_nexus_addons_p_msg_" .. msg
    local list = g.msg_handlers[msg]
    if not list then
        list = {}
        g.msg_handlers[msg] = list
        _G[dispatch_name] = function(frame, recv_msg, str, num)
            -- 実行中に register_msg が呼ばれても壊れないよう、その都度引き直す。
            for _, name in ipairs(g.msg_handlers[msg] or {}) do
                local func = _G[name]
                if type(func) == "function" then
                    -- 1 つが転んでも後続へ配り続ける。潰し合いを直すのが目的なので、
                    -- ここで巻き添えにしては元も子もない。
                    local ok, err = pcall(func, frame, recv_msg, str, num)
                    if not ok then
                        -- 報告は on_init の safe_call と同じ 3 経路。vlog だけだと既定 OFF の
                        -- 利用者には無音で、不具合報告用の debug_log.txt にも残らない。
                        -- ただし FPS_UPDATE のように毎フレーム来る経路があるので、同じ
                        -- (メッセージ, ハンドラ)の組では 1 回だけにする(CLAUDE.md「出しすぎない」)。
                        local failed_key = msg .. "/" .. name
                        if not g.msg_failed[failed_key] then
                            g.msg_failed[failed_key] = true
                            local err_msg = string.format("Error during msg '%s' of '%s': %s", msg, name,
                                tostring(err))
                            ts(err_msg)
                            g.log_to_file(err_msg)
                            g.vlog("{#FF6347}msg %s: %s FAILED{/} %s (以降このハンドラの失敗は出さない)", msg,
                                name, tostring(err))
                        end
                    end
                end
            end
        end
    end
    -- 購読はハンドラ登録とは別に、ON_INIT ごとに 1 メッセージ 1 回ずつ張り直す。
    -- 置き換える前は各呼び出し元が ON_INIT のたびに addon:RegisterMsg を打ち直していて、
    -- g.REGISTER を ON_INIT ごとに空にしているのもそのためだった。ここで「初回だけ」に
    -- してしまうと、g.addon が別物に差し替わったときに購読が死んだオブジェクトへ
    -- 残り続け、そのメッセージが以降一切届かなくなる。
    if g.addon then
        if not g.msg_registered_cycle[msg] then
            g.msg_registered_cycle[msg] = true
            g.addon:RegisterMsg(msg, dispatch_name)
            -- 張り直しは毎回のことなので黙って行う。**前に張った addon と別物だったとき**
            -- だけは「前回の購読が死んでいた」ことになるので、判断材料として残す。
            -- 初回(前回値が無い)は死んだ購読が存在しないので出さない。出すと起動のたびに
            -- メッセージの数だけ(実測 129 行)流れて、肝心の行が埋もれる。
            local prev_addon = g.msg_registered_addon[msg]
            g.msg_registered_addon[msg] = g.addon
            if prev_addon ~= nil and prev_addon ~= g.addon then
                g.vlog("register_msg: %s を新しい addon で購読し直した", msg)
            end
        end
    else
        -- g.addon は ON_INIT の 1 行目で入るので、通常ここには来ない。
        g.vlog("{#FF6347}register_msg: g.addon がまだ無い (%s){/}", msg)
    end
    -- on_init は ON/OFF 切り替えや再初期化で何度も呼ばれるので、二重登録を弾く。
    for _, name in ipairs(list) do
        if name == func_name then
            return
        end
    end
    table.insert(list, func_name)
    -- 潰し合いが直ったかを実機で確かめるための材料。どのメッセージに何本ぶら下がったかを出す。
    -- 起動時に 1 回ずつしか通らない経路なので、毎フレーム流れる心配はない。
    g.vlog("register_msg: %s <- %s (%d本目)", msg, func_name, #list)
end

-- 名前の頭が一致するハンドラを配信先からすべて外す。機能 OFF にされたアドオンが
-- 自分の購読を畳むために使う(ハンドラ名をアドオンごとの接頭辞で揃えてあるので、
-- 一覧を持たなくても自分の分だけを外せる)。
-- 購読(addon:RegisterMsg)自体は残す。他のアドオンが同じメッセージに乗っているし、
-- 配信先が空でも配信役が何もせず返るだけで害がないため。
function g.unregister_msg_by_prefix(prefix)
    local removed = 0
    for _, list in pairs(g.msg_handlers) do
        for i = #list, 1, -1 do
            if string.sub(list[i], 1, string.len(prefix)) == prefix then
                table.remove(list, i)
                removed = removed + 1
            end
        end
    end
    -- setup_hook_and_event の「登録済み」印も落とす。ここを残すと、同じ ON_INIT の中で
    -- もう一度 ON にされたとき(設定画面のトグル)に register_msg が呼ばれず、外した購読が
    -- 次のマップ移動まで戻らない。印のキーは グローバル名 .. ハンドラ名 なので接頭辞で引く。
    for key in pairs(g.REGISTER or {}) do
        if string.find(key, prefix, 1, true) then
            g.REGISTER[key] = nil
        end
    end
    g.vlog("unregister_msg: %s* を %d 本外した", prefix, removed)
    return removed
end
-- ===== メッセージの多重配信(ここまで) =====

-- ===== フックの管理表 =====
-- g.hook_owner[グローバル名]  … そのグローバルへ自分たち(まとめ版と同梱アドオン)が
--                               入れた置換方式フックを、掛けた順の並びで持つ。
--                               「今 _G に居るのは味方か」の判定に使う。味方なら、
--                               そいつは自分のラッパを呼ぶ形で連鎖している。
--   **単一スロットにしてはいけない。** 同じグローバルに味方が 2 つ乗る場合がある
--   (CHAT_SYSTEM = まとめ版 + mini_addons)。単一スロットだと後から掛けた側しか覚えられず、
--   知らない誰かの割り込みからまとめ版が復帰したときスロットがまとめ版で埋まり、手前に
--   居た mini_addons が「味方が手前に居る」と誤判定して張り直しを飛ばす。結果 mini 側の
--   フックがチェーンから外れたまま黙って死ぬ(CHAT_SYSTEM のフィルタが効かなくなる)。
--   並びで持てば「current は自分より後に掛けた=手前の味方か」を正しく判定できる。
--   掛けた順が連鎖の順でもある(控えは一度きりなので、後から掛けた方が必ず手前)。
-- g.core_hooks[グローバル名]  … まとめ版自身が入れた置換方式のフック(入れ済みかの判定用)
-- g.EVENT_HOOKS[グローバル名] … 掛け済みのイベント用ラッパ
g.hook_owner = g.hook_owner or {}
g.core_hooks = g.core_hooks or {}
g.EVENT_HOOKS = g.EVENT_HOOKS or {}
g.EVENT_HOOK_BOOL = g.EVENT_HOOK_BOOL or {}

-- func をそのグローバルの味方一覧の末尾へ足す(既に居れば触らない=掛けた順を保つ)。
function g.hook_owner_add(origin_func_name, func)
    local list = g.hook_owner[origin_func_name]
    if not list then
        list = {}
        g.hook_owner[origin_func_name] = list
    end
    for i = 1, #list do
        if list[i] == func then
            return
        end
    end
    list[#list + 1] = func
end

-- func が味方一覧の何番目か(掛けた順)。居なければ nil。
function g.hook_owner_index(origin_func_name, func)
    local list = g.hook_owner[origin_func_name]
    if not list then
        return nil
    end
    for i = 1, #list do
        if list[i] == func then
            return i
        end
    end
    return nil
end

-- current が my_func の「手前の味方」か。手前 = 掛けた順が後(index が大きい)。
-- current が味方でない/自分より先に掛けた側なら false(連鎖が切れているので張り直す)。
function g.hook_owner_in_front(origin_func_name, current, my_func)
    local ci = g.hook_owner_index(origin_func_name, current)
    if not ci then
        return false
    end
    local mi = g.hook_owner_index(origin_func_name, my_func)
    if not mi then
        return false
    end
    return ci > mi
end

-- func を味方一覧から外す(機能 OFF の後始末で使う)。
function g.hook_owner_remove(origin_func_name, func)
    local list = g.hook_owner[origin_func_name]
    if not list then
        return
    end
    for i = #list, 1, -1 do
        if list[i] == func then
            table.remove(list, i)
        end
    end
end

-- グローバル関数をラップして、呼ばれたら同名メッセージを配信する。
--
-- ラッパを掛け直すかどうかは、今 _G に入っているものを見て決める。
--   * 自分のラッパのまま         → 何もしない(掛け直す意味がない)
--   * 自分たちの置換方式フックが手前 → 触らない。掛け直すと相手を落としてしまう。
--     相手は自分のラッパを呼ぶ形で連鎖しているので、これで両方生きている。
--     (設定画面でどれか 1 つを ON にしただけで、無関係なアドオンのフックが次の
--      マップ移動まで外れる、という形で出ていた)
--   * それ以外(知らない誰かが差し替えた) → 連鎖が切れているので掛け直す
-- 連鎖の相手(元の関数)は「掛けた時点で _G に入っていた実体」。置換方式のフックが先に
-- 掛かっていればそれを呼ぶので、両方式が同じグローバルに乗っても潰し合わない。
function g.setup_hook_and_event(my_addon, origin_func_name, my_func_name, bool)
    g.FUNCS = g.FUNCS or {}
    local installed = g.EVENT_HOOKS[origin_func_name]
    local current = _G[origin_func_name]
    -- 自分のラッパのまま、または自分たちの置換方式フックが手前に居るなら触らない。
    -- 知らない誰か(クライアント側の再定義など)に差し替えられていたら連鎖が切れているので、
    -- 従来どおり掛け直す。
    local keep = installed ~= nil and
        (current == installed or g.hook_owner_index(origin_func_name, current) ~= nil)
    if not keep then
        if installed then
            g.vlog("{#FF6347}setup_hook_and_event: %s のラッパが外れていたので掛け直す{/}", origin_func_name)
        end
        local origin_func = current
        if not g.FUNCS[origin_func_name] then
            g.FUNCS[origin_func_name] = origin_func
        end
        local function hooked_function(...)
            local original_results
            if bool == true then
                original_results = {origin_func(...)}
            end
            g.ARGS = g.ARGS or {}
            g.ARGS[origin_func_name] = {...}
            imcAddOn.BroadMsg(origin_func_name)
            if original_results then
                return table.unpack(original_results)
            else
                return
            end
        end
        g.EVENT_HOOKS[origin_func_name] = hooked_function
        g.EVENT_HOOK_BOOL[origin_func_name] = bool
        _G[origin_func_name] = hooked_function
    else
        if g.EVENT_HOOK_BOOL[origin_func_name] ~= bool then
            -- 元の関数を呼ぶ/呼ばないが呼び出し元で食い違っている。今の実装では
            -- 先に掛けた側の指定が残る。現状そんな組み合わせは無いが、増えたら気付けるように。
            g.vlog("{#FF6347}setup_hook_and_event: %s の bool が食い違う(先の %s を維持){/}", origin_func_name,
                tostring(g.EVENT_HOOK_BOOL[origin_func_name]))
        end
        if current ~= installed then
            -- 自分たちの置換方式フックが手前に居る。張り直すとそれを落とすので触らない。
            g.vlog("setup_hook_and_event: %s は手前に別のフックが居るので張り直さない", origin_func_name)
        end
    end
    if not g.REGISTER[origin_func_name .. my_func_name] then -- g.REGISTERはON_INIT内で都度初期化
        g.REGISTER[origin_func_name .. my_func_name] = true
        g.register_msg(origin_func_name, my_func_name)
    end
end

function g.get_event_args(origin_func_name)
    local args = g.ARGS[origin_func_name]
    if args then
        return table.unpack(args)
    end
    return nil
end

-- 控えを取り終えたグローバル名(replace_name)の印。
-- **「_G[replace_name] が nil かどうか」で判定してはいけない。** 掛けようとしたグローバルが
-- 走っているクライアントに存在しないと(IMC の改名など)控えは nil のままになり、次の
-- ON_INIT で「まだ控えていない」と見えてしまう。そのとき _G[origin] に入っているのは
-- **自分のラッパ**なので、それを元の関数として控えることになり、g.FUNCS[origin] 経由の
-- 呼び出しが自分自身へ戻って無限再帰する。控えたかどうかは値と別に持つこと。
g.hook_captured = g.hook_captured or {}

-- 置換方式のフック。my_func を _G へ直接入れ、元の実体は g.FUNCS から呼べるようにする。
-- 戻り値は控えた元の実体(呼び出し元が自分の g.FUNCS へ写すのに使う)。
--
-- 掛け直すかどうかは、今 _G に入っているものを見て決める(setup_hook_and_event と同じ規則)。
--   * 自分のラッパのまま           → 何もしない
--   * 自分たちのフックが手前に居る  → 触らない。相手は自分を呼ぶ形で連鎖しているので両方生きている。
--   * それ以外(知らない誰かが連鎖しない形で差し替えた) → 連鎖が切れているので掛け直す
-- 3 つ目を「掛け済みなら何もしない」で済ませていたため、他アドオンに上書きされると
-- セッション中ずっと外れたままになっていた(CHAT_SYSTEM のフィルタが黙って死ぬ等)。
--
-- owner は呼び出し元ごとの管理表。同梱アドオン(mini_addons)が同じ規則を自前で書き写すと
-- 直しを 2 箇所へ入れることになるので、実装はここ 1 本にして表だけ差し替える。
--   owner.installed … 掛けた実体の控え(まとめ版は g.core_hooks)
--   owner.funcs     … 元の実体を書き戻す先(呼び出し元の g.FUNCS)。**まとめ版のものを
--                     共有してはいけない**。まとめ版が先に掛けていると、まとめ版の
--                     g.FUNCS[origin] がまとめ版自身のラッパになり無限再帰する。
--   owner.prefix    … 控えのグローバル名の接頭辞。ここを共有すると、どちらが先に掛けたかで
--                     相手のフックを落としてしまうので必ず分けること。
--   owner.label     … ログの頭
function g.setup_hook(my_func, origin_func_name, owner)
    g.FUNCS = g.FUNCS or {}
    local installed_map = (owner and owner.installed) or g.core_hooks
    local funcs_map = (owner and owner.funcs) or g.FUNCS
    local prefix = (owner and owner.prefix) or string.upper(addon_name)
    local label = (owner and owner.label) or "setup_hook"
    local replace_name = prefix .. "_REPLACE_" .. origin_func_name
    if not g.hook_captured[replace_name] then
        g.hook_captured[replace_name] = true
        _G[replace_name] = _G[origin_func_name]
    end
    local origin_func = _G[replace_name]
    funcs_map[origin_func_name] = origin_func
    local current = _G[origin_func_name]
    if current == my_func then
        g.hook_owner_add(origin_func_name, my_func)
        return origin_func
    end
    if installed_map[origin_func_name] == my_func then
        -- 掛け済み。今 _G に居るのが「自分より後に掛けた味方(=手前で自分を呼ぶ)」か、
        -- イベント用ラッパなら、相手が自分を呼ぶ形で連鎖しているので触らない。
        -- **単一スロット比較にしてはいけない**(理由は g.hook_owner の宣言コメント)。
        -- 自分より先に掛けた味方が手前に居るのは連鎖が壊れた印なので、張り直しへ回す。
        if g.hook_owner_in_front(origin_func_name, current, my_func) or
            current == g.EVENT_HOOKS[origin_func_name] then
            g.vlog("%s: %s は手前に別のフックが居るので張り直さない", label, origin_func_name)
            return origin_func
        end
        g.vlog("{#FF6347}%s: %s が知らない誰かに差し替えられていたので掛け直す{/}", label, origin_func_name)
    end
    _G[origin_func_name] = my_func
    installed_map[origin_func_name] = my_func
    g.hook_owner_add(origin_func_name, my_func)
    return origin_func
end

-- tmp を path へ差し替える(remove→rename)。成功可否を返す。
-- 厳密なアトミック差し替えではない: remove と rename の間でクラッシュすると path は
-- 消えるが、tmp に完全な内容が残るため次回 load の .tmp リカバリで復旧できる。この
-- tmp リカバリと対で実効的な原子性(=設定を失わない)を担保する。
-- Windows の os.rename は移動先が存在すると失敗するため先に remove する。
-- rename 失敗時は path が remove 済みのまま false を返す(呼び出し側が検知して報告)。
function g.atomic_replace(tmp_path, path)
    os.remove(path)
    local ok, err = os.rename(tmp_path, path)
    if not ok then
        return false, err
    end
    return true
end

function g.save_lua(path, tbl)
    local function serialize(o)
        if type(o) == "number" then
            return tostring(o)
        elseif type(o) == "string" then
            return string.format("%q", o)
        elseif type(o) == "boolean" then
            return tostring(o)
        elseif type(o) == "table" then
            local parts = {"{\n"}
            for k, v in pairs(o) do
                parts[#parts + 1] = "[" .. serialize(k) .. "]=" .. serialize(v) .. ",\n"
            end
            parts[#parts + 1] = "}"
            return table.concat(parts)
        else
            return "nil"
        end
    end
    local ok_s, content = pcall(function() return "return " .. serialize(tbl) end)
    if not ok_s or not content then
        if ts then ts("Save Lua Serialize Error:", tostring(content)) end
        return
    end
    local tmp_path = path .. ".tmp"
    local file, err = io.open(tmp_path, "w")
    if file then
        local ok_w, w_err = file:write(content)
        file:close()
        if ok_w then
            local ok_r, r_err = g.atomic_replace(tmp_path, path)
            if not ok_r and ts then ts("Save Lua Rename Error:", tostring(r_err)) end
        else
            if ts then ts("Save Lua Write Error:", tostring(w_err)) end
        end
    else
        if ts then ts("Save Lua Error:", err) end
    end
end

function g.load_lua(path)
    local chunk, err = loadfile(path)
    if chunk then
        local status, result = pcall(chunk)
        if status then
            return result
        end
    end
    local tmp_path = path .. ".tmp"
    local tmp_chunk = loadfile(tmp_path)
    if tmp_chunk then
        local status, result = pcall(tmp_chunk)
        if status then
            g.atomic_replace(tmp_path, path)
            return result
        end
    end
    return nil
end

-- path の .tmp をデコード成功時のみ path へ昇格し、(true, 値) を返す。
-- 壊れた/空/不在の .tmp は昇格させず(リカバリ元を失わないため) false を返す。
-- 本体ファイルが開けない/空の 2 経路で共通のリカバリ手順。
local function load_json_recover_from_tmp(path)
    local tmp_file = io.open(path .. ".tmp", "r")
    if not tmp_file then
        return false
    end
    local tmp_content = tmp_file:read("*all")
    tmp_file:close()
    if not tmp_content or tmp_content == "" then
        return false
    end
    local s, r = pcall(json.decode, tmp_content)
    if not s then
        return false
    end
    g.atomic_replace(path .. ".tmp", path)
    return true, r
end

function g.load_json(path)
    local file = io.open(path, "r")
    if not file then
        local ok, recovered = load_json_recover_from_tmp(path)
        if ok then
            return recovered, nil
        end
        return nil, "Error opening file: " .. path
    end
    local content = file:read("*all")
    file:close()
    if not content or content == "" then
        local ok, recovered = load_json_recover_from_tmp(path)
        if ok then
            return recovered, nil
        end
        return nil, "File content is empty or could not be read: " .. path
    end
    if string.sub(content, 1, 3) == "\239\187\191" then
        content = string.sub(content, 4)
    end
    local success, result = pcall(json.decode, content)
    if success then
        return result, nil
    else
        return nil, result
    end
end

function g.save_json(path, tbl)
    -- 先にエンコードしてから書き込む。エンコード失敗時に本体ファイルを
    -- 空に潰さないよう、まず tmp に書いてから rename でアトミックに差し替える。
    -- (load_json の .tmp リカバリと対になる)
    local success, str = pcall(json.encode, tbl)
    if not success then
        print(string.format("[g.save_json] JSON Encode Error in '%s': %s", tostring(path), tostring(str)))
        return false
    end
    local tmp_path = path .. ".tmp"
    local file, err = io.open(tmp_path, "w")
    if not file then
        print(string.format("[g.save_json] Error opening file for write: %s (Error: %s)", tostring(tmp_path), tostring(err)))
        return false
    end
    local ok_w, w_err = file:write(str)
    file:close()
    if not ok_w then
        print(string.format("[g.save_json] Write Error in '%s': %s", tostring(tmp_path), tostring(w_err)))
        return false
    end
    local ok_r, r_err = g.atomic_replace(tmp_path, path)
    if not ok_r then
        print(string.format("[g.save_json] Rename Error in '%s': %s", tostring(path), tostring(r_err)))
        return false
    end
    return true
end

-- 詳細ログ。アドオンメニューボタン右クリックの設定画面にある
-- 「詳細なログをシステムに出力する」が ON のときだけ、チャットのシステムメッセージへ出す。
-- 既定は OFF なので、通常の利用者のチャットは今までどおり静かなまま。
--
-- 保存先は g.settings(= ../addons/_nexus_addons_p/<AID>/settings.json)。
-- UI を出している 90_addons_menu.lua 側の addons_menu.json はメニューの位置と
-- 表示設定だけを持つので、アドオン全体の設定であるこれは置かない(詳細は 90 側のコメント)。
--
-- 初期化前(g.settings がまだ nil)や、本家検出で初期化を止めた場合も黙って何もしない。
-- 書式化の失敗でデバッグ用のログが本体を巻き込んで落とすことがないよう pcall で包む。
--
-- チャットは流れてしまい後から読み返せないので、同じ内容をファイルにも残す。
-- 不具合報告用に「そのまま送れる」ことを狙っており、
--   * 出力先は debug_log.txt とは別。あちらはエラーの履歴を追記し続ける用途で、
--     詳細ログを混ぜると際限なく育ち、必要な部分も探しにくくなる。
--   * 作り直すのはクライアント起動後の最初の 1 行だけ(下の vlog_write)。
--   * 色やタグ({ol} 等)は読みづらいだけなので、ファイル側では外す。
local vlog_file_path = string.format('../addons/%s/verbose_log.txt', addon_name_lower)
-- 行数の上限。マップ移動のたびに全アドオンの init 行(50 行前後)が出るため、
-- 1 回のプレイでも積み上がる。到達したら取り直して際限なく育たないようにする。
local vlog_max_lines = 20000

local function vlog_write(line)
    local mode, notice = "a", nil
    if not g.vlog_started then
        -- 作り直すのはここだけ。GAME_START はマップ移動のたびに来るので、
        -- そこで毎回作り直すと直前のマップのログ(初期化エラーを含む)が消える。
        -- g はクライアント起動中ずっと生きるので、1 回のプレイで 1 ファイルになる。
        mode = "w"
    elseif g.vlog_lines >= vlog_max_lines then
        mode = "w"
        notice = "===== 行数が上限に達したのでここから取り直し ====="
    end
    local file = io.open(vlog_file_path, mode)
    if not file then
        -- 開けなかったときは状態を進めない。ここで vlog_started を立ててしまうと、
        -- 作り直しに失敗したまま次回から追記モードになり、前回起動分のログに
        -- 書き足す形になる(「中身は常に今回の起動分だけ」が崩れ、報告用に使えない)。
        -- 上限到達時も同じで、取り直せていないのに行数だけ 0 に戻すと以後伸び続ける。
        return
    end
    g.vlog_started = true
    if mode == "w" then
        g.vlog_lines = 0
    end
    local stamp = os.date("[%H:%M:%S] ")
    if notice then
        file:write(stamp .. notice .. "\n")
        g.vlog_lines = g.vlog_lines + 1
    end
    file:write(stamp .. line .. "\n")
    file:close()
    g.vlog_lines = g.vlog_lines + 1
end

-- 実際に出力したときだけ true を返す。
--
-- 「同じ行を 1 回だけ出す」ために印を立てる呼び出し側が幾つかあるが、印を先に立てると
-- **既定 OFF の間に印だけ消費され、後から ON にしても二度と出ない**。特に
-- ログイン直後の非同期初期化はログを ON にする前に走り切るので、一番知りたい
-- 起動時の 1 回が必ず消える(実機で発生)。印は必ずこの戻り値で立てること:
--     if not g.foo_logged and g.vlog("...") then g.foo_logged = true end
function g.vlog(fmt, ...)
    if not g.settings or g.settings.verbose_log ~= 1 then
        return false
    end
    local ok, msg = pcall(string.format, fmt, ...)
    if not ok then
        msg = tostring(fmt)
    end
    ui.SysMsg("{ol}{#00BFFF}[NAP]{/} " .. msg)
    local plain = msg:gsub("{[^}]*}", "")
    vlog_write(plain)
    return true
end

-- 呼び出し箇所が 50 を超えており、FPS_UPDATE 経由で毎フレーム走る経路もある。
-- GetClass は IES 引きで重い一方、MapType は同じマップなら不変なので、
-- マップ名をキーにメモ化する。マップが変われば引き直すので意味は変わらない。
--
-- キャッシュするのは引けたときだけ。nil を覚えると、ロード中などに一度でも nil を
-- 掴んだ時点でそのマップに居る間ずっと nil が返り続け(無効化する契機が無い)、
-- guild_event_warp の移動可否チェックが素通りする等、呼び出し側の判定が全部壊れる。
-- 引けなかったマップは毎回引き直す = メモ化前と同じ挙動なので、退行にはならない。
function g.get_map_type()
    local map_name = session.GetMapName()
    if g.map_type_cache_name == map_name then
        return g.map_type_cache
    end
    local map_cls = GetClass("Map", map_name)
    -- 未知/インスタンスマップでは GetClass が nil を返しうるので nil ガード。
    -- 呼び出し側はいずれも文字列比較(== "Dungeon" 等)なので nil で問題ない。
    if not map_cls then
        -- 失敗はキャッシュしない = 毎フレームここへ来るので、ログはマップごとに 1 回だけ。
        -- (絞らないと FPS_UPDATE 経由でシステムメッセージが毎フレーム流れる)
        -- 印は出力できたときだけ立てる(g.vlog のコメント参照)。OFF の間に立ててしまうと
        -- 後からログを ON にしても、そのマップに居る限りこの行が出ない。
        if g.map_type_failed_name ~= map_name and
            g.vlog("MapType 取得失敗: %s (キャッシュせず次回引き直す)", tostring(map_name)) then
            g.map_type_failed_name = map_name
        end
        return nil
    end
    local map_type = map_cls.MapType
    if map_type == nil or map_type == "" then
        -- クラスは引けたが MapType が空。これも「引けなかった」と同じ扱いにする。
        -- ここでキャッシュすると無効化する契機が無く、そのマップに居る間ずっと
        -- nil が返り続けてしまう(上のコメントと同じ理由)。
        if g.map_type_failed_name ~= map_name and
            g.vlog("MapType が空: %s (キャッシュせず次回引き直す)", tostring(map_name)) then
            g.map_type_failed_name = map_name
        end
        return nil
    end
    g.map_type_failed_name = nil
    g.map_type_cache_name = map_name
    g.map_type_cache = map_type
    -- ここを通るのは「マップが変わった」ときだけなので、移動のたびに 1 行出る。
    g.vlog("MapType: %s = %s", tostring(map_name), tostring(map_type))
    return map_type
end

-- 何度も直値で出てくるマップ ID。同じ ID が 4 アドオン 6 箇所に散っていて、
-- 説明のコメント(-- 11244 聖域3F ...)まで丸ごとコピーされていた。名前を付けて 1 箇所に集める。
g.MAP_SANCTUARY_3F = 11244 -- 未知の聖域3F
g.MAP_SPLIT = 11227 -- 分裂
g.MAP_VELNIKE = 8022 -- ヴェルニケ

-- 現在のマップの Keyword に、指定のキーワードが含まれるか。
--   true  … 含まれる
--   false … 含まれない
--   nil   … Map クラスを引けなかった(= 判定できなかった)
-- **false と nil を混ぜないこと。** 「該当しない」と「引けなかった」を同じ false で
-- 返すと、呼び出し側は判定できなかったことに気付けず、ログにも差が出ないので
-- 「なぜ動かないのか」を実機ログから追えなくなる(g.get_map_type と同じ理由)。
--
-- Keyword は ";" 区切りの並び。素の string.find だと "WeeklyBossMapEntrance" のような
-- 別キーワードにも部分一致してしまうので、前後を ";" で挟んでトークン単位で当てる。
-- GetClass は IES 引きで重いのでマップ名でメモ化する。失敗はキャッシュしない
-- = 次回引き直す(g.get_map_type と同じ理由)。
function g.map_has_keyword(keyword)
    local map_name = session.GetMapName()
    if g.map_keyword_cache_name ~= map_name then
        local map_cls = GetClass("Map", map_name)
        local kw = map_cls and TryGetProp(map_cls, "Keyword", "None")
        if type(kw) ~= "string" then
            if g.map_keyword_failed_name ~= map_name and
                g.vlog("Map Keyword 取得失敗: %s (キャッシュせず次回引き直す)", tostring(map_name)) then
                g.map_keyword_failed_name = map_name
            end
            return nil
        end
        g.map_keyword_failed_name = nil
        g.map_keyword_cache_name = map_name
        g.map_keyword_cache = ";" .. kw .. ";"
        g.vlog("Map Keyword: %s = %s", tostring(map_name), kw)
    end
    return string.find(g.map_keyword_cache, ";" .. keyword .. ";", 1, true) ~= nil
end

-- 共有フレーム(_nexus_addons_p)に載せたタイマーを止める。
--
-- 一度 Start したタイマーは、明示的に Stop しない限りそのマップに居る間ずっと
-- 回り続ける。止め忘れは実際に何度も出ており
-- (dungeon_rp_charger / boss_direction / party_marker)、各アドオンが
-- 「GetFrame → GET_CHILD → AUTO_CAST → Stop」を手で書くと nil ガードや AUTO_CAST の
-- 抜けが毎回入り込む。止める経路は必ずここを通すこと。
--
-- 止める判定は g 側のフラグに頼らない。フラグが落ちていてもタイマーは生きている
-- ことがある(タイマーはフレームに載っているので g より寿命が長い)ため、
-- 見つけたら必ず Stop する。
--
-- 戻り値は 3 通り。**"止めた/止めていない" の 2 値にしないこと。**
--   true      … 見つけて止めた
--   false     … 共有フレームは在るが、そのタイマーは載っていなかった
--   nil       … 共有フレームそのものが無い
-- false と nil を混ぜると「タイマーが元から無い」のか「フレームごと作り直された」のかが
-- 実機ログから切り分けられない。**この 2 つは意味がまるで違う**。
--
-- ===== 実機で確認した事実(2026-07-29) — 同じ調査を繰り返さないこと =====
-- **共有フレームの子タイマーはマップ移動をまたがない。**
--   * フィールドで boss_direction_timer を Start した 8〜11 秒後に街へ移動すると、
--     街の on_init での g.stop_timer が **false**(= フレームは在るがタイマーは無い)を返す。
--     これが 3 回のマップ移動で毎回再現した。
--   * 一方、同じマップ内では確実に止まる: quickslot_operate のマップ監視は
--     打ち切りログが**マップごとに 1 行**しか出ない。止まっていなければ 3 秒ごとに
--     出続けるので、GET_CHILD + Stop 自体は効いている。
-- つまり「一度 Start すると**クライアントを落とすまで**回り続ける」は誤り。
-- 正しくは「**そのマップに居る間は**回り続ける」。マップを離れれば道連れに消える。
-- したがって各アドオンの Stop が効くのは、
--   * 同じマップに居るまま設定を OFF にした / 条件が変わった …… **意味がある**
--   * マップを移動した …………………………………………………… 念のための保険
-- という位置づけになる。前者は実在するので Stop は残すこと。
function g.stop_timer(timer_name)
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    if not _nexus_addons_p then
        return nil
    end
    local timer = GET_CHILD(_nexus_addons_p, timer_name)
    if not timer then
        return false
    end
    AUTO_CAST(timer)
    timer:Stop()
    return true
end

-- 同じエラーを何度も出さないログ。周期タイマーの中で落ちると、そのままでは
-- 同じ行が毎秒何本も流れて肝心の行が埋もれる(CLAUDE.md「出しすぎない」)。
--   key … アドオンごとの識別子。この単位で「直前と同じか」を憶える
--   msg … 出す本文
-- vlog は既定 OFF なので利用者の手元には何も残らない。debug_log.txt にも出す。
-- 直前と違うメッセージなら出し直すので、原因が変わったことには気付ける。
-- 成功したら g.clear_error_once(key) を呼んで印を落とすこと(次の失敗をまた出せる)。
g.error_logged = g.error_logged or {}

function g.log_error_once(key, msg)
    if g.error_logged[key] == msg then
        return false
    end
    g.error_logged[key] = msg
    g.vlog("%s", msg)
    g.log_to_file(msg)
    return true
end

function g.clear_error_once(key)
    g.error_logged[key] = nil
end

-- ESC で消えない常時表示フレームを作る。常時出しておきたいフレームは必ずこれを使うこと。
--
-- ゲーム側の chat_memberlist.xml は <option hideable="true"> で、ESC はこの hideable な
-- フレームを閉じる。notice_on_pc は hideable="false" なので消えない。
-- ESC による非表示は IsVisible() に反映されないため、_nexus_addons_p_update_frames の
-- 毎フレーム復帰では検出も復旧もできない。土台の選択で防ぐしかない。
function g.create_persistent_frame(frame_name)
    return ui.CreateNewFrame("notice_on_pc", frame_name, 0, 0, 0, 0)
end

-- ESC で閉じる自作フレームの重なり(開いた順)スタック。
--
-- 土台が notice_on_pc のフレームはゲーム側の ESC では消えない(上のコメント参照)ので、
-- ESC で閉じているのは各アドオンが購読した ESCAPE_PRESSED のハンドラ。これはゲームから
-- 登録済みハンドラ全部へ一斉に配られるため、各自が素直に自分のフレームを閉じると
-- 「開いている自作ウィンドウが 1 回の ESC で全部消える」。
-- そこで開いたフレームをここへ積んでおき、閉じるのは一番手前(= 最後に開いた)1 枚だけにする。
--
-- 判定と close 呼び出しは core/20_lifecycle.lua の _nexus_addons_p_ESCAPE_PRESSED に集約する。
-- アドオンごとに ESCAPE_PRESSED を購読したままだと、先に閉じた側でスタックの中身が変わり、
-- 後から呼ばれたハンドラが「今度は自分が一番手前」と判断して結局まとめて消えてしまう。
g.esc_stack = g.esc_stack or {}

-- ESC で閉じたいフレームを開いたときに呼ぶ。
--   frame_name: ui.GetFrame に渡すフレーム名
--   close_func: 閉じるグローバル関数の名前(引数無しで呼べること)
-- 開き直しは積み直し = 最前面扱いにする。
-- **フレームを作って ShowWindow(1) した後で呼ぶこと**。まだ出ていない状態で呼ぶと、
-- 直後の同期で「閉じ終わった登録」と見なされてその場で捨てられる。
function g.esc_register(frame_name, close_func)
    for i = #g.esc_stack, 1, -1 do
        if g.esc_stack[i].frame == frame_name then
            table.remove(g.esc_stack, i)
        end
    end
    table.insert(g.esc_stack, {
        frame = frame_name,
        close = close_func
    })
    g.esc_sync_scp()
end

-- 生きている(存在して表示中の)中で一番手前の登録を、外さずに返す。
-- × ボタンで閉じた分は登録解除されないまま残るので、ここで一緒に捨てる。
-- 戻り値の 2 つ目はスタック上の位置(esc_pop_top が外すのに使う)。
function g.esc_top()
    for i = #g.esc_stack, 1, -1 do
        local entry = g.esc_stack[i]
        local frame = ui.GetFrame(entry.frame)
        if frame ~= nil and frame:IsVisible() == 1 then
            return entry, i
        end
        -- 捨てた理由を残す。「開いているのに ESC で閉じられない」「開いた直後に
        -- 登録が消える」を追うとき、フレームが無いのか表示扱いでないのかで原因が別。
        -- 捨てるときしか出ないので、毎フレーム呼ばれてもログは流れない。
        g.vlog("esc_stack: %s を捨てた(frame=%s visible=%s)", tostring(entry.frame), frame and "有" or "無",
            frame and tostring(frame:IsVisible()) or "-")
        table.remove(g.esc_stack, i)
    end
    return nil
end

-- 一番手前の登録を 1 つ取り出す(閉じた後に開き直せば esc_register で積み直される)。
function g.esc_pop_top()
    local entry, index = g.esc_top()
    if entry then
        table.remove(g.esc_stack, index)
    end
    return entry
end

-- 1 回の押下を 2 度処理しないための間隔(ms)。ESC の届く経路は 2 つあり(g.esc_sync_scp 参照)、
-- その 2 経路の配信間隔は 1 フレーム未満なので、ここはそれを吸収できる最小限で十分。
-- 長くすると 2 つ実害が出る:
--   (1) 意図した ESC 連打(手前を閉じてすぐ下を閉じる)を握り潰す = esc_is_reentry
--   (2) 最後の 1 枚を閉じた後、この時間だけ esc_taken() が true を返し続け、
--       indun_panel の ESC トグルを無効化する = esc_taken
-- 60fps の 1 フレーム≒16ms に対しフレーム落ちの余裕を見て 50ms とする
-- (旧値 200ms は上記 2 つをはっきり踏むほど長すぎた)。
local ESC_DEDUP_MS = 50

-- 「今回の ESC はスタック側(= 手前の自作ウィンドウ)が使ったか」の問い合わせ。
--
-- ESCAPE_PRESSED はスタックに積めないものからも購読されている(indun_panel は常時表示の
-- パネルで、積むと ESC を常に横取りしてシステムメニューが開けなくなる)。そちら側が
-- 「手前にウィンドウがあるときは何もしない」を判断するのに使う。
-- ハンドラの呼ばれる順番はゲーム任せなので、次のどちらかなら true にする:
--   * まだ手前に生きているウィンドウがある      … 自分より後にそれが閉じられる
--   * この押下で 1 枚閉じた直後                  … 自分より先に閉じられていた
function g.esc_taken()
    if g.esc_top() then
        return true
    end
    return g.esc_closed_ms ~= nil and imcTime.GetAppTimeMS() - g.esc_closed_ms < ESC_DEDUP_MS
end

-- 同じ押下での再入(2 経路)を捨てるための判定。閉じた側は g.esc_closed_ms を更新する。
function g.esc_is_reentry()
    return g.esc_last_ms ~= nil and imcTime.GetAppTimeMS() - g.esc_last_ms < ESC_DEDUP_MS
end

-- 自作ウィンドウが開いている間だけ、ESC をこちらへ回してもらう。
--
-- ui.SetEscapeScp はゲーム側の「この ESC はこれを実行する」を差し替える口で、素の ESC
-- (チャットなど hideable なフレームを閉じる / システムメニューを開く)の代わりに走る。
-- これを設定しないと、自作ウィンドウを閉じるついでにチャットが消えたりシステムメニューが
-- 開いたりする。クライアントの uiscp/enchantchip.lua・uiscp/moru.lua・
-- fixframe/deletewarningbox/deletewarningbox.lua が「開いている間だけ設定し、
-- 閉じたら "" に戻す」使い方をしているので、それに倣う。
--
-- 現在値を読む API はクライアントに無い(SetEscapeScp だけ)ので、自分が設定したかどうかを
-- 覚えて、状態が変わったときだけ呼ぶ。毎フレーム呼ぶとゲーム側が設定した分を潰してしまう。
-- 閉じ忘れると ESC でシステムメニューが二度と開かなくなるため、× で閉じた場合も拾えるよう
-- _nexus_addons_p_update_frames(FPS_UPDATE)からも呼んで実際の表示状態に合わせ続ける。
-- force=true のときは「覚えている状態」を無視して必ず設定し直す。
-- 記憶(g.esc_scp_set)はこちらが最後に書いた値でしかなく、クライアント側の実際の値とは
-- ずれうる。特に g.esc_scp_set を nil に戻した直後は want=false と「記憶なし(=false 扱い)」が
-- 一致してしまい、こちらが割り込み先を握ったままでも clear が一度も飛ばない。
-- こうなると ESC はすべてこちらへ来て、閉じるものが無いので何も起きない
-- = 利用者から見ると「ESC でシステムメニューが開かない」になる(実機で発生)。
function g.esc_sync_scp(force)
    local want = g.esc_top() ~= nil
    if not force and want == (g.esc_scp_set or false) then
        return
    end
    g.esc_scp_set = want
    g.vlog("esc_scp: %s (stack=%d force=%s)", want and "set" or "clear", #g.esc_stack, tostring(force or false))
    -- 古いクライアントに SetEscapeScp が無くても、ここで巻き込んで落とさない
    -- (その場合は ESCAPE_PRESSED の一斉配信だけで従来どおり動く)。
    pcall(ui.SetEscapeScp, want and "_nexus_addons_p_ESCAPE_PRESSED()" or "")
end

-- ===== 調査用: ESC で開くシステムメニューの正体を掴む =====
--
-- ESC のシステムメニューへ Addons Menu の導線を足せるかを判断するには、
--   (1) そのフレーム名は何か
--   (2) 子コントロールは何という名前で、どの種類か(= イベントを付けられるか)
-- が要る。クライアントにフレームを列挙する API は無い(ui.GetFrame は名前引きのみ)ので、
-- 候補名を総当たりして「実在したもの」だけ出す。当たらなかったときのために、
-- グローバルに居る ESC/メニュー系の名前も併せて出して次の候補のヒントにする。
--
-- 右上のアイコン列 "sysmenu" とは別物なので混同しないこと(あちらは実在確認済み)。
-- 候補が当たったらこの一覧を実名 1 つに絞れる。調査が終わってもこの経路のログは
-- 残す方針だが、候補総当たりの部分は絞ってよい。
-- 実機の調査で確定: ESC のシステムメニューは **フレーム "apps"**。
-- 右上アイコン列 sysmenu の "system" ボタン(コレクションの右隣)が
-- ui.ToggleFrame('apps') を呼んでおり、ESC で開くものと同じ。
-- 総当たりしていた候補名(mainmenu / systemmenu / …)はすべて外れだったので消した。
-- APPS_TRY_LEAVE を購読している characters_item_serch と同じ "apps" のこと。
g.esc_probe_candidates = {"apps"}
-- 1 起動あたりの実行回数。1 回で 30 行以上出るうえ、vlog は 1 行ごとに
-- ファイル書き込みとチャットへのシステムメッセージを行う。ESC のたびに走らせていたときは
-- それだけで ESC の反応が悪くなったので、起動後 1 回に絞る(CLAUDE.md「出しすぎない」)。
g.esc_probe_max = 1

-- 子ツリーを深さ制限付きで出す。GetX/GetY はコントロール種別によって
-- 持っていないことがあるので、print_all_child と同じく名前/種別/サイズだけにする。
local function esc_probe_dump_children(ctrl, prefix, depth)
    if depth > 3 then
        return
    end
    local count = ctrl:GetChildCount()
    if not count or count <= 0 then
        return
    end
    for i = 0, count - 1 do
        local child = ctrl:GetChildByIndex(i)
        if child then
            -- GetWidth/GetHeight を持たない種別で転んでも残りを出し続けられるよう、
            -- esc_probe_dump_sysmenu の pos と同じく個別に握る(probe 全体が pcall の中なので、
            -- 握らないと途中で打ち切られ、g.esc_probe_max = 1 の一発を空振りで消費する)。
            local ok_size, size = pcall(function()
                return string.format("%dx%d", child:GetWidth(), child:GetHeight())
            end)
            g.vlog("%s%s | class=%s | size=%s", prefix, tostring(child:GetName()), tostring(child:GetClassName()),
                ok_size and size or "?")
            esc_probe_dump_children(child, prefix .. "  ", depth + 1)
        end
    end
end

-- グローバル名の総当たり出力(esc_probe_dump_globals)は、フレーム名 "apps" を
-- 突き止めるのに使って役目を終えたので消した。1 回あたり 5 行 x 20 件出るうえ、
-- 得られる情報は「クライアントにこの関数が居る」だけで、毎回見る価値がない。
-- 同じ手が要るときは pairs(_G) を名前で絞って出すだけなので、書き直しは容易。

-- 右上のアイコン列 sysmenu を出す。ESC のシステムメニューは
-- 「コレクション(F11)の右隣のボタン」から開くものと同じなので、その子ボタンが
-- 何という名前で、どのクライアント関数を呼んでいるかが分かれば、開く先のフレーム名を
-- 手繰れる。イベントスクリプト名を読む API は名前が定かでないので、
-- 在りそうなものを順に pcall で試して、通ったものだけ出す。
local function esc_probe_dump_sysmenu()
    local sysmenu = ui.GetFrame("sysmenu")
    if not sysmenu then
        g.vlog("esc_probe: sysmenu が取れない")
        return
    end
    g.vlog("esc_probe: sysmenu visible=%s size=%dx%d child=%d", tostring(sysmenu:IsVisible()), sysmenu:GetWidth(),
        sysmenu:GetHeight(), sysmenu:GetChildCount())
    for i = 0, sysmenu:GetChildCount() - 1 do
        local child = sysmenu:GetChildByIndex(i)
        if child then
            local script = nil
            for _, getter in ipairs({"GetEventScriptName", "GetEventScript", "GetEventScriptArgString"}) do
                local ok, value = pcall(function()
                    return child[getter](child, ui.LBUTTONUP)
                end)
                if ok and value and value ~= "" then
                    script = string.format("%s=%s", getter, tostring(value))
                    break
                end
            end
            -- GetX/GetY を持たないコントロール種別があるので、ここで転んでも
            -- 残りの子を出し続けられるよう個別に握る(probe 全体が pcall の中なので、
            -- 握らないと途中で打ち切られて肝心の子が出ない)。
            local ok_pos, pos = pcall(function()
                return string.format("%d,%d", child:GetX(), child:GetY())
            end)
            g.vlog("  sysmenu[%d] %s | class=%s | pos=%s | %s", i, tostring(child:GetName()),
                tostring(child:GetClassName()), ok_pos and pos or "?", script or "script=読めない")
        end
    end
end

-- 開閉音の名前を実機から読む調査(esc_probe_dump_sounds)は消した。
-- GetPushSound / GetSound / GetUserConfig のいずれでも読めないことが確認できたため
-- (実機ログ: esc_probe: sound sysmenu/system -> 読めない)。同じ調査を繰り返さないこと。
-- 音の名前が要るときは、クライアントのデータを直接見るほうが速い:
--   * 使えるイベント名の一覧 … sound.ipf の R1.txt
--   * フレームが鳴らす音     … ui.ipf の fixframe/<名前>/<名前>.xml の <sound .../>
--   * Lua で作られるボタン   … 定義ファイルが無いので、候補を鳴らして選ぶしかない

function g.probe_esc_menu()
    -- 詳細ログ OFF のときは vlog が黙るだけでツリー走査は走ってしまうので、ここで止める。
    if not g.settings or g.settings.verbose_log ~= 1 then
        return
    end
    g.esc_probe_count = (g.esc_probe_count or 0) + 1
    if g.esc_probe_count > g.esc_probe_max then
        return
    end
    g.vlog("===== esc_probe [%d/%d] ESC 後のフレームを調べる =====", g.esc_probe_count, g.esc_probe_max)
    local found = 0
    for _, name in ipairs(g.esc_probe_candidates) do
        local frame = ui.GetFrame(name)
        if frame then
            found = found + 1
            -- IsVisible() は ESC による非表示を反映しないことがある(g.esc_sync_scp のコメント参照)。
            -- 実在するかどうかの判断材料であって、開いているかの証明ではない点に注意。
            g.vlog("esc_probe: frame '%s' visible=%s size=%dx%d", name, tostring(frame:IsVisible()),
                frame:GetWidth(), frame:GetHeight())
            esc_probe_dump_children(frame, "  ", 1)
        end
    end
    g.vlog("esc_probe: 候補 %d 件中 %d 件が実在", #g.esc_probe_candidates, found)
    -- sysmenu 側も出す。"apps" を開いているのがどのボタンかは、ここの
    -- GetEventScript(= ui.ToggleFrame('apps')) を見れば確認できる。
    -- 他アドオンがボタンを足すと並びも中身も変わるので、実機で毎回見られるようにしておく。
    pcall(esc_probe_dump_sysmenu)
end

function g.debug_print_table(tbl, indent)
    indent = indent or ""
    for key, value in pairs(tbl) do
        local key_str = indent .. "[" .. tostring(key) .. "] ="
        if type(value) == "table" then
            print(key_str .. "{")
            g.debug_print_table(value, indent .. "  ")
            print(indent .. "}")
        else
            print(key_str .. tostring(value))
        end
    end
end

function g.log_to_file(message)
    local log_file_path = string.format('../addons/%s/debug_log.txt', addon_name_lower)
    local file, err = io.open(log_file_path, "a")
    if file then
        local timestamp = os.date("[%Y-%m-%d %H:%M:%S] ")
        file:write(timestamp .. tostring(message) .. "\n")
        file:close()
    end
end

