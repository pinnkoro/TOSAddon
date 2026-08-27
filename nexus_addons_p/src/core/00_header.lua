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
local ver = "2.1.0"

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
        -- 受けた引数は数を決め打ちせず、そのまま流す。ゲーム側には 5 個目以降を渡す
        -- メッセージがある(MON_MINIMAP は 5 個目に info を渡し、素の
        -- MAP_MON_MINIMAP(frame, msg, argStr, argNum, info) が info.handle / info.x を使う)。
        -- 4 個で決め打ちすると、そこを使うハンドラが nil 参照で転び、下の pcall が握るので
        -- 「静かに機能だけ死ぬ」形になる(sub_map のボス表示がこれで出なくなった)。
        _G[dispatch_name] = function(...)
            -- 実行中に register_msg が呼ばれても壊れないよう、その都度引き直す。
            for _, name in ipairs(g.msg_handlers[msg] or {}) do
                local func = _G[name]
                if type(func) == "function" then
                    -- 1 つが転んでも後続へ配り続ける。潰し合いを直すのが目的なので、
                    -- ここで巻き添えにしては元も子もない。
                    local ok, err = pcall(func, ...)
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

-- スクロールできる groupbox の、今のスクロール位置を返す。
--
-- **GetScrollPos ではない。あれはクライアントに無い。**
-- 素のクライアント(`_client/jp/**`)での使用は GetScrollPos が 0 件、SetScrollPos が 71 件。
-- 対になっていると思い込みやすく、しかも無い関数を pcall で握ると黙って 0 が返るので、
-- 「作り直すたびに一覧の先頭へ戻る」という形でしか表に出ない(実際に一度踏んだ)。
-- 正しくは GetScrollCurPos(素のクライアントも another_warehouse もこちらを使う)。
--
-- pcall で包むのは残すが、**黙って 0 を返さない**。使えなかったことを verbose_log へ
-- 1 回だけ出して、次に同じ症状が出たときログから切り分けられるようにする。
--
-- 中身を作り直した後に位置を戻すときは、**先に InvalidateScrollBar() を呼ぶこと**。
-- 順番が逆だと、作り直す前の範囲で丸められて先頭に貼り付く。
function g.scroll_cur_pos(gbox)
    local ok, pos = pcall(function()
        return gbox:GetScrollCurPos()
    end)
    if ok and type(pos) == "number" then
        return pos
    end
    if not g.scroll_api_failed then
        g.scroll_api_failed = true
        g.vlog("GetScrollCurPos が使えない(%s)。スクロール位置は引き継げない", tostring(pos))
    end
    return 0
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
--   close_func: 閉じ方。次のどちらでもよい
--     * グローバル関数の**名前**(引数無しで呼べること) … 既存の閉じる処理を使い回すとき
--     * 関数そのもの(引数無しで呼ばれる)               … その場の無名関数で足りるとき
--   後者を許すのは、閉じる処理がフレーム名を引数に取る作りのアドオンが多く、
--   そのたびに引数無しのラッパをグローバルへ足していると名前が増えるだけだから。
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

-- 既に積んである登録は動かさずに積む。**中身を作り直す初期化関数から積むときはこちら**。
--
-- esc_register は「開き直し = 最前面」なので、同じフレームをもう一度積むと一番上へ来る。
-- 検索し直しのように「その窓自身を開き直した」ときはそれで正しいが、
-- **子の一覧を開いたまま親の設定画面を組み立て直す**作り(battle_ritual / muteki は
-- スキルやバフを足すたびに設定画面の初期化関数を呼び直す)でこれを使うと、
-- 親が子より手前に積み直され、ESC 1 回で親の close が走って子まで道連れになる
-- = スタックが防ぐはずの「まとめて消える」がそのまま出る。
--
-- **ここで「その登録が生きているか」を見ても意味が無い。** 呼ばれる時点ではフレームを
-- 作って ShowWindow(1) した直後なので、開き直した場合でも必ず生きていると出る。
-- 「閉じた窓の登録が下に残っている」状態を作らせないのは esc_top の掃除の役目
-- (毎フレームの esc_sync_scp から呼ばれる)。そちらを参照。
function g.esc_register_keep(frame_name, close_func)
    for _, entry in ipairs(g.esc_stack) do
        if entry.frame == frame_name then
            -- 位置は動かさず、閉じ方だけ最新にする
            entry.close = close_func
            g.esc_sync_scp()
            return
        end
    end
    g.esc_register(frame_name, close_func)
end

-- 「ESC で破棄する」だけの窓のための短縮形。閉じるときに保存などの後始末が要らない、
-- ui.DestroyFrame するだけの窓はこれで足りる(自作ウィンドウの大半がこれ)。
function g.esc_register_destroy(frame_name)
    g.esc_register(frame_name, function()
        ui.DestroyFrame(frame_name)
    end)
end

-- 「ESC で隠す」だけの窓のための短縮形。作り直せない土台(chat_memberlist など)や、
-- 破棄すると持っている参照が無効になる窓はこちらを使う。
function g.esc_register_hide(frame_name)
    g.esc_register(frame_name, function()
        local frame = ui.GetFrame(frame_name)
        if frame then
            AUTO_CAST(frame)
            frame:ShowWindow(0)
        end
    end)
end

-- 生きている(存在して表示中の)中で一番手前の登録を、外さずに返す。
-- × ボタンで閉じた分は登録解除されないまま残るので、ここで一緒に捨てる。
-- 戻り値の 2 つ目はスタック上の位置(esc_pop_top が外すのに使う)。
--
-- **掃除は「一番手前の生きた登録」で打ち切らず、スタック全体に対して行うこと。**
-- 途中で止めると、下に沈んだ死んだ登録が永久に残る。そうなると esc_register_keep が
-- それを掴んで位置を据え置き、**閉じた窓を開き直しても手前に来ない**:
--   一覧を開く → 別の窓を開く(一覧の上) → 一覧を × で閉じる(登録は下に残る)
--   → 一覧を開き直す → 据え置かれて下のまま → ESC が別の窓を先に閉じる
-- 全体を見ても、スタックに載るのは開いている自作ウィンドウだけ(実測で数枚)なので、
-- 毎フレーム呼ばれても走査は数回の ui.GetFrame で済む。
function g.esc_top()
    for i = #g.esc_stack, 1, -1 do
        local entry = g.esc_stack[i]
        local frame = ui.GetFrame(entry.frame)
        if frame == nil or frame:IsVisible() ~= 1 then
            -- 捨てた理由を残す。「開いているのに ESC で閉じられない」「開いた直後に
            -- 登録が消える」を追うとき、フレームが無いのか表示扱いでないのかで原因が別。
            -- 捨てるときしか出ないので、毎フレーム呼ばれてもログは流れない。
            g.vlog("esc_stack: %s を捨てた(frame=%s visible=%s)", tostring(entry.frame), frame and "有" or "無",
                frame and tostring(frame:IsVisible()) or "-")
            -- 下から順に詰めるので、i より下の位置は動かない(上向きに走査しているため安全)。
            table.remove(g.esc_stack, i)
        end
    end
    local top = #g.esc_stack
    if top == 0 then
        return nil
    end
    return g.esc_stack[top], top
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

-- ===== 検索欄のインクリメンタル検索と「×」 =====
--
-- 素のクライアントの検索欄は、打鍵のたびに 0.3 秒遅らせて検索し直す作りになっている。
--   inventory.xml : <edit name="ItemSearch" ... typingscp="SEARCH_ITEM_INVENTORY_KEY"/>
--   inventory.lua : SEARCH_ITEM_INVENTORY_KEY が CancelReserveScript / ReserveScript(0.3) で先送りする
-- ワールドマップの検索欄(worldmap2_mainmap.xml)も同じ。**素には検索欄をクリアするボタンが
-- どこにも無い**が、これは「文字を消せばその場で戻るので要らない」というだけで、
-- 消す手段そのものを否定しているわけではない。こちらは素に合わせて打鍵で検索し直す
-- ようにしたうえで、入力があるときだけ「×」を出す(一般的な検索窓と同じ)。
--
-- 素は frame:CancelReserveScript で前の予約を取り消すが、**グローバルの ReserveScript には
-- 取り消しが無い**(素もフレーム側でしか呼んでいない)。フレーム側の予約は「フレームごとに
-- 関数名 1 つ」なので、同じフレームに検索欄が複数ある作り(battle_ritual など)だと
-- 打ち消し合ってしまう。そこで検索欄ごとに世代番号を持ち、**最後の打鍵の分だけ実行して
-- 残りは捨てる**。捨てる側は数値比較で戻るだけなので、余分に起きても実害が無い。
g.search_typing_delay = 0.3

-- 「×」ボタンの名前。検索欄の子として作るので、検索欄ごとに 1 つ。
g.search_clear_name = "nap_search_clear"

-- 打鍵から検索関数を呼んでいる間だけ真。**その検索がキーボード操作から来たのかを
-- アドオン側で見分けるためのもの。** 見分けが要るのは Focus() の扱いで、一覧の作り直しで
-- 検索欄ごと作り直す作り(characters_item_serch)が、入力位置を戻してよいかの判断に使う。
--
-- **「打鍵以外を弾く」向きにすること。** 検索関数には打鍵のほかに Enter・虫眼鏡ボタン・
-- 「×」から入ってくる。マウス操作(虫眼鏡 /「×」)では入力位置がそもそも無いので、
-- 戻すと ESC の 1 回目を食って窓が閉じなくなる。「×から来たか」だけを見る作りにすると
-- 虫眼鏡ボタン経由を取りこぼす(レビューで実際に指摘された)。
g.search_typing_running = false

-- [key] = {frame=, name=, handler=, arg_num=, delay=, seq=, last=, incremental=}
-- key は handler 名と引数の組。**検索欄そのものを持たない**のは、打鍵から実行までの
-- 0.3 秒の間に × ボタンで窓を閉じられると、破棄済みのコントロールを掴んだままになるため。
-- 実行時に名前から引き直す(素も esc_top も同じやり方)。
g.search_typing = g.search_typing or {}

-- 検索欄の入力を消す「×」の出し入れだけを行う。**打鍵のたびに呼ばれる**ので、
-- ここでは表示以外の状態を触らないこと(g.search_clear_sync の注意書きを参照)。
--
-- **位置決めを作成時ではなく最初に出すときに行う。** 虫眼鏡ボタン(search_btn)は
-- どのアドオンでも検索欄より後に作られる = 登録を呼ぶ時点ではまだ幅を読めないため。
-- 出すのは利用者が 1 文字打った後なので、そのときには必ず在る。
local function search_clear_btn_sync(edit)
    if edit == nil then
        return
    end
    local ok, err = pcall(function()
        local btn = GET_CHILD_RECURSIVELY(edit, g.search_clear_name)
        if btn == nil then
            return
        end
        AUTO_CAST(btn)
        local text = edit:GetText() or ""
        if text == "" then
            btn:ShowWindow(0)
            return
        end
        if btn:GetUserValue("NAP_PLACED") ~= "1" then
            -- **虫眼鏡ボタンがまだ無いうちは位置を確定させない。** ここは検索欄の文字を
            -- コードから入れた直後(まだ虫眼鏡ボタンを作っていない)にも通るので、
            -- 確定させてしまうと左隣ではなく右端に置いたまま固定される。
            local search_btn = GET_CHILD_RECURSIVELY(edit, "search_btn")
            if search_btn ~= nil then
                btn:SetMargin(0, 0, search_btn:GetWidth() + 4, 0)
                btn:SetUserValue("NAP_PLACED", "1")
            end
        end
        btn:ShowWindow(1)
    end)
    if not ok then
        -- 打鍵のたびに通るが、log_error_once が同じ内容を 1 回だけに絞るので流れない。
        g.log_error_once("search_clear_btn_sync",
            string.format("incremental_search: 「×」の出し入れに失敗(%s)", tostring(err)))
    end
end

-- **検索欄の文字をコードから変えたときに呼ぶ。**「×」の出し入れを合わせ、あわせて
-- 「前回この語で検索した」の記録(entry.last)を捨てる。
--
-- **記録を捨てるのを忘れないこと。** _nexus_addons_p_search_fire は entry.last と同じ語なら
-- 検索を飛ばすので、捨てないと「コードで空へ戻す → 利用者が同じ語を打ち直す」経路で
-- 検索が一度も走らなくなる(another_warehouse でタブを切り替えてから同じ語を入れると再現した)。
-- 打鍵のたびに走る側から呼ぶのは search_clear_btn_sync のほう。こちらを毎打鍵で呼ぶと
-- 重複除外が常に無効になる。
function g.search_clear_sync(edit)
    if edit == nil then
        return
    end
    search_clear_btn_sync(edit)
    pcall(function()
        local key = edit:GetUserValue("NAP_SEARCH_KEY")
        local entry = key ~= nil and g.search_typing[key] or nil
        if entry ~= nil then
            entry.last = nil
            -- **世代番号も進めること。** 予約済みの検索を無効にする手段はこれしかない
            -- (グローバルの ReserveScript に取り消しが無い)。進めないと、打鍵から
            -- 実行までの間にコードが検索欄を空へ戻した場合でも古い予約がそのまま発火する。
            -- 実例: another_warehouse は打鍵の 0.5 秒以内にタブを切り替えると、後から
            -- 発火した検索が Another_warehouse_tab_change をタブ 1 固定で呼び直し、
            -- 利用者が選んだタブを無言で巻き戻していた。
            entry.seq = entry.seq + 1
        end
    end)
end

-- 検索欄に打鍵の受け取りと「×」を仕込む共通処理。
--   incremental が true なら打鍵のたびに検索し直す。false のときは「×」を出すためだけに
--   打鍵を受け取り、検索は Enter と虫眼鏡ボタンのままにする(tavern_of_soul のように
--   全件を走査する検索は 1 文字ごとに走らせられないため)。
local function setup_search_edit(edit, handler, arg_num, delay, incremental)
    if edit == nil or handler == nil or handler == "" then
        return
    end
    local key = string.format("%s#%s", handler, tostring(arg_num or 0))
    local ok, err = pcall(function()
        local frame = edit:GetTopParentFrame()
        local entry = g.search_typing[key] or {}
        entry.frame = frame:GetName()
        entry.name = edit:GetName()
        entry.handler = handler
        entry.arg_num = arg_num or 0
        entry.delay = delay or g.search_typing_delay
        entry.incremental = incremental and true or false
        entry.seq = entry.seq or 0
        -- 窓を開き直したときに前回の検索語を引きずらない(引きずると、同じ語を打ち直しても
        -- 「変わっていない」と見なして検索が走らない)。
        entry.last = nil
        g.search_typing[key] = entry
        edit:SetUserValue("NAP_SEARCH_KEY", key)
        edit:SetTypingScp("_nexus_addons_p_search_typing")

        local clear_btn = edit:CreateOrGetControl("button", g.search_clear_name, 0, 0, 22, 22)
        AUTO_CAST(clear_btn)
        clear_btn:SetImage("testclose_button")
        clear_btn:SetGravity(ui.RIGHT, ui.CENTER_VERT)
        clear_btn:SetTextTooltip(g.lang == "Japanese" and "{ol}入力を消して元の一覧に戻す" or g.lang == "kr" and
                                     "{ol}입력을 지우고 원래 목록으로" or "{ol}Clear the search box")
        clear_btn:SetEventScript(ui.LBUTTONUP, "_nexus_addons_p_search_clear")
        -- 作り直した窓では「置いた」印も作り直させる(虫眼鏡ボタンの幅を測り直すため)。
        clear_btn:SetUserValue("NAP_PLACED", "0")
        clear_btn:ShowWindow(0)
        g.search_clear_sync(edit)
    end)
    if not ok then
        -- 打鍵を受け取れないクライアントに当たっても、ENTERKEY と虫眼鏡ボタンは
        -- そのまま残るので検索自体は使える。1 回だけ残して以後は黙る。
        g.log_error_once("search_typing:" .. key,
            string.format("incremental_search: %s の打鍵登録に失敗(%s)", key, tostring(err)))
    end
end

-- 検索欄を素と同じインクリメンタル検索にし、入力中は「×」を出す。
-- **ui.ENTERKEY の割り当ての直後に呼ぶこと。**
--   edit    : 検索欄(AUTO_CAST 済みの ui::CEditControl)
--   handler : ui.ENTERKEY に割り当てたのと同じグローバル関数名
--   arg_num : ui.ENTERKEY へ SetEventScriptArgNumber で渡しているのと同じ値(無ければ省略)
--   delay   : 打鍵から検索までの秒数(省略時 g.search_typing_delay)。一覧の作り直しが
--             重いものはここを伸ばす
-- ENTERKEY と虫眼鏡ボタンは**そのまま残すこと**。押しても同じ検索がもう一度走るだけで
-- 害が無く、「Enter で検索する」と思っている利用者の手を止めないため。
function g.setup_incremental_search(edit, handler, arg_num, delay)
    setup_search_edit(edit, handler, arg_num, delay, true)
end

-- 検索は Enter と虫眼鏡ボタンのままにし、「×」だけを付ける。
-- **全件を走査して一致したぶんだけコントロールを作る検索**は 1 文字ごとに走らせられない
-- (空文字や 1 文字で数千〜数万件に当たる)ので、そういう検索はこちらを使う。
--   reset_handler : 「×」を押したときに呼ぶグローバル関数名。**空文字で検索し直す処理では
--                   なく、検索前の姿へ戻す(中身を捨てて畳む)処理を渡すこと。**
--                   呼び出しの並びは検索関数と同じ (frame, ctrl, argStr, argNum)。
function g.setup_enter_search(edit, reset_handler, arg_num)
    setup_search_edit(edit, reset_handler, arg_num, nil, false)
end

-- 打鍵のたびに呼ばれる(SetTypingScp の呼び出し規約は素の CHECK_EDIT_LENGTH と同じ (parent, ctrl))。
-- 「×」の出し入れはここで即座に行い、検索そのものは _nexus_addons_p_search_fire へ先送りする。
function _nexus_addons_p_search_typing(parent, ctrl)
    local ok, err = pcall(function()
        local key = ctrl:GetUserValue("NAP_SEARCH_KEY")
        local entry = key ~= nil and g.search_typing[key] or nil
        if entry == nil then
            return
        end
        search_clear_btn_sync(ctrl)
        if not entry.incremental then
            return
        end
        entry.seq = entry.seq + 1
        ReserveScript(string.format("_nexus_addons_p_search_fire(%q, %d)", key, entry.seq), entry.delay)
    end)
    if not ok then
        g.log_error_once("search_typing_reserve",
            string.format("incremental_search: 打鍵の予約に失敗(%s)", tostring(err)))
    end
end

-- 検索欄と登録を名前から引き直す。**参照を持ち回さない**理由は g.search_typing のコメント参照。
-- 窓が閉じていれば nil を返す(ここで作り直すと、閉じたはずの窓が打鍵の残りで開き直る)。
local function search_edit_of(entry)
    local frame = ui.GetFrame(entry.frame)
    if frame == nil or frame:IsVisible() ~= 1 then
        return nil, nil
    end
    local edit = GET_CHILD_RECURSIVELY(frame, entry.name)
    if edit == nil then
        return nil, nil
    end
    AUTO_CAST(edit)
    return frame, edit
end

-- 登録した検索関数を、ui.ENTERKEY から呼ばれるときと同じ並び (frame, ctrl, argStr, argNum) で呼ぶ。
local function search_run(entry, frame, edit, text)
    local func = _G[entry.handler]
    if type(func) ~= "function" then
        g.log_error_once("search_typing_func:" .. tostring(entry.handler),
            string.format("incremental_search: %s が見つからない", tostring(entry.handler)))
        return
    end
    entry.last = text
    func(frame, edit, text, entry.arg_num)
    g.vlog("incremental_search: %s(frame=%s text=%q arg=%s)", entry.handler, entry.frame, text,
        tostring(entry.arg_num))
end

-- 予約した検索を実行する。seq が最新でなければ、続けて打鍵された分なので捨てる。
function _nexus_addons_p_search_fire(key, seq)
    local entry = g.search_typing[key]
    if entry == nil or entry.seq ~= seq then
        return
    end
    local ok, err = pcall(function()
        local frame, edit = search_edit_of(entry)
        if edit == nil then
            return
        end
        local text = edit:GetText() or ""
        if entry.last == text then
            return
        end
        g.search_typing_running = true
        search_run(entry, frame, edit, text)
    end)
    -- pcall が失敗した経路でも必ず戻す(戻し忘れると以後ずっと「打鍵から来た」扱いになる)。
    g.search_typing_running = false
    if not ok then
        g.log_error_once("search_typing_fire:" .. key,
            string.format("incremental_search: %s の実行に失敗(%s)", key, tostring(err)))
    end
end

-- 「×」を押したとき。入力を消して、登録した検索関数を空文字で呼ぶ = 元の一覧へ戻す。
-- **入力欄へ Focus() は戻さない。** キーボードフォーカスが入力欄にあると ESC の 1 回目が
-- 「入力欄から抜ける」に使われて窓が閉じなくなるため(CLAUDE.md の ESC の節を参照)。
function _nexus_addons_p_search_clear(parent, ctrl)
    local ok, err = pcall(function()
        local edit = ctrl:GetParent()
        if edit == nil then
            return
        end
        AUTO_CAST(edit)
        local key = edit:GetUserValue("NAP_SEARCH_KEY")
        local entry = key ~= nil and g.search_typing[key] or nil
        if entry == nil then
            return
        end
        edit:SetText("")
        -- 打鍵で予約済みの検索の無効化(世代番号を進める)も search_clear_sync が行う。
        g.search_clear_sync(edit)
        local frame, live_edit = search_edit_of(entry)
        if live_edit == nil then
            return
        end
        search_run(entry, frame, live_edit, "")
    end)
    if not ok then
        g.log_error_once("search_clear", string.format("incremental_search: × の処理に失敗(%s)", tostring(err)))
    end
end

-- ===== 初回ロードの分割実行(スロットル) =====
--
-- ログイン直後は、登録されている全アドオンの on_init を **1 tick あたり数個ずつ**に
-- 割って走らせる(core/20_lifecycle.lua の _nexus_addons_p_async_safe_call)。
-- その「1 回あたりの件数」を利用者が変えられるようにしたのがここ。設定画面
-- (Addons Menu の設定 → 共通タブ)の「初期化の速さ」から入る。
--
-- **待ち時間は処理の重さと無関係に積む。** 従来は 0.1 秒ごとに 2 件だったので、
-- 51 個なら実際の処理が 0 秒でも 2.5 秒かかる。登録の末尾に来るアドオンほど遅れて
-- 有効になり、market_favorite_rebuild は実測で GAME_START の 5 秒後だった
-- (addons/market_favorite_rebuild のコメント参照)。
-- そこで tick 間隔は 0.05 秒に固定し、**件数だけ**を可変にする。
-- 件数 1 なら従来と同じ約 2.5 秒、既定の 4 で約 0.65 秒、上限 12 で約 0.2 秒。
--
-- **tick 間隔を 0.01 秒(素の作法)まで詰めないこと。** 素のクライアントは「止めずに
-- できるだけ速く」を 0.01 か 0(毎フレーム)で書く(_PROCESS_MOVE_FRAME /
-- _PROCESS_RESIZE_FRAME / UPDATE_TABKEY_VISIBLE など 23 箇所)。ただし 0.01 は
-- フレーム時間(60fps で 16.7ms)で頭打ちになるので、実質「毎フレーム N 件」= fps 依存に
-- なる。設定画面に所要秒数を出している以上、fps で倍違うのは説明と食い違う。
-- 0.05 なら 20fps でも表示どおりの wall-clock になる。
--
-- **大きくするほど 1 フレームの取り分が増える**ので上限を置く。時間予算(time_limit)も
-- 件数に連れて上げるが、こちらは **16ms = 60fps の 1 フレーム**で頭打ちにする。
-- 素のクライアントには「1 フレームの時間予算」という考え方が無く
-- (imcTime.GetAppTimeMS() は全体で 6 ファイル、どれも経過時間の表示)、意図して
-- 1 フレーム以上を使う処理も見当たらない。1 フレーム分で切り上げるのが素の感覚に沿う。
-- 予算を見るのは「次の 1 件へ進む前」だけなので、1 件で 100ms かかるアドオンは
-- どの設定でもその tick を丸ごと使う。予算は軽い init をどこまで詰め込むかの上限でしかない。
g.INIT_BATCH_MIN = 1
g.INIT_BATCH_MAX = 12
g.INIT_BATCH_DEFAULT = 4
g.INIT_TICK_SEC = 0.05
-- 1 tick の時間予算の上限(ms)。60fps の 1 フレーム分。
g.INIT_TIME_LIMIT_MAX = 16

-- 設定値から、実際に使う (件数, 時間予算 ms) を出す。
-- **数字でない / 範囲外は既定とクランプで正す。** 設定ファイルは利用者が手で書き
-- 換えられるので、0 や負数が入ると while が 1 件も進まないまま毎 tick 回り続ける
-- (初期化が永久に終わらない)。ここを通す限りその形にはならない。
-- 純ロジックなので docs/tests/test_core.lua から検査できる。
function g.init_throttle(batch)
    batch = tonumber(batch)
    if not batch then
        batch = g.INIT_BATCH_DEFAULT
    end
    batch = math.floor(batch)
    if batch < g.INIT_BATCH_MIN then
        batch = g.INIT_BATCH_MIN
    elseif batch > g.INIT_BATCH_MAX then
        batch = g.INIT_BATCH_MAX
    end
    -- 従来は 2 件 / 6ms = 1 件あたり 3ms。同じ比で伸ばし、16ms(60fps の 1 フレーム)で止める。
    local time_limit = batch * 3
    if time_limit < 6 then
        time_limit = 6
    elseif time_limit > g.INIT_TIME_LIMIT_MAX then
        time_limit = g.INIT_TIME_LIMIT_MAX
    end
    return batch, time_limit
end

-- 件数 count のアドオンを初期化し終えるまでの目安(秒)。設定画面の説明文で使う。
function g.init_estimate_sec(count, batch)
    local per_tick = (g.init_throttle(batch))
    count = tonumber(count) or 0
    if count <= 0 then
        return 0
    end
    return math.ceil(count / per_tick) * g.INIT_TICK_SEC
end

-- アドオンの設定画面を置く位置を返す。
--
-- 従来はどの設定画面も「アドオン一覧(list_frame)の右隣」に決め打ちしていたが、
-- **Addons Menu のショートカットから開くと一覧は開いていない**。そのとき
-- ui.GetFrame は nil を返し、素で :GetX() を呼ぶとそこで落ちる。**窓は既に作った後**なので、
-- 利用者からは中身が何も無い空の窓が出るように見える
-- (実機で Auto Repair / Boss Direction で発生。同じ書き方が 11 アドオンにあった)。
--
-- 一覧が開いていればこれまでどおり右隣、開いていなければ画面の中央へ置く。
-- width / height は分かっていれば渡すこと(中央寄せと、画面からはみ出さないための丸めに使う)。
function g.settings_frame_pos(width, height)
    local list = ui.GetFrame(addon_name_lower .. "list_frame")
    local map_ui = ui.GetFrame("map")
    local screen_w = (map_ui and map_ui:GetWidth()) or 1920
    local screen_h = (map_ui and map_ui:GetHeight()) or 1080
    width = width or 400
    height = height or 400
    local x, y
    if list then
        x, y = list:GetX() + list:GetWidth(), list:GetY()
    else
        x, y = math.floor((screen_w - width) / 2), math.floor((screen_h - height) / 2)
    end
    if x + width > screen_w then
        x = screen_w - width
    end
    if y + height > screen_h then
        y = screen_h - height
    end
    if x < 0 then
        x = 0
    end
    if y < 0 then
        y = 0
    end
    return x, y
end

-- ===== Addons Menu のショートカット設定 =====
--
-- アドオン一覧の行に置く☆(core/20_lifecycle.lua)と、Addons Menu の一覧
-- (core/90_addons_menu.lua)の両方が読み書きするので、触り方をここへ集約する。
-- **90_addons_menu.lua は読み込み時ガードの外に居る**ので、あちらから呼べるように
-- 置き場所はこのファイル(ガードの外)であること。
--
-- 保存先は settings.json のトップレベル menu_shortcuts。
--   menu_shortcuts = { ["addon:another_warehouse"] = { show = 1, icon = "..." }, ... }
--
-- **キーは名前空間を分けること。** Nexus Addons P のアドオン(registry のキー)と、
-- 他アドオンが相乗りで入れてくる項目(_G["norisan"]["MENU"] のキー)は別の出どころで、
-- 綴りがぶつかる保証が無い。前者は "addon:"、後者は "menu:" を付けて区別する。
--
-- **知らないキーを消さないこと。** 相乗り側は自分の GAME_START で登録するので、
-- そのアドオンを外している起動ではキーが存在しない。掃除すると入れ直したときに
-- 設定が失われるので、「今のテーブルに無いものは出さない」だけにする。
g.MENU_SHORTCUT_DEFAULT_ICON = "config_button_normal"

function g.menu_shortcut_key(kind, key)
    return tostring(kind) .. ":" .. tostring(key)
end

-- 設定を読む。無ければ nil(既定値の判断は呼び元が行う。既定は出どころで違う:
-- registry のアドオンは「出さない」、相乗り項目は「出す」)。
function g.menu_shortcut_cfg(key)
    if not (g.settings and g.settings.menu_shortcuts) then
        return nil
    end
    local cfg = g.settings.menu_shortcuts[key]
    if type(cfg) ~= "table" then
        return nil
    end
    return cfg
end

-- 出すかどうか。default_show は設定がまだ無いときの既定。
function g.menu_shortcut_shown(key, default_show)
    local cfg = g.menu_shortcut_cfg(key)
    if cfg == nil or cfg.show == nil then
        return default_show and true or false
    end
    return cfg.show == 1
end

-- 設定を書いて保存する。value が nil のときはその項目だけ消す
-- (アイコンを既定へ戻すときに使う。エントリ自体は show を持つので残す)。
--
-- defer = true のときは保存しない。**まとめて書き換える処理はこれを使うこと**
-- (並べ替えは一覧全体へ番号を振り直すので、そのまま呼ぶと 1 回の押下で
--  設定ファイルを項目数ぶん書くことになる)。呼び元が最後に 1 回保存すること。
function g.menu_shortcut_set(key, field, value, defer)
    if not g.settings then
        return false
    end
    g.settings.menu_shortcuts = g.settings.menu_shortcuts or {}
    local cfg = g.settings.menu_shortcuts[key]
    if type(cfg) ~= "table" then
        cfg = {}
        g.settings.menu_shortcuts[key] = cfg
    end
    cfg[field] = value
    if not defer and type(_G["_nexus_addons_p_save_settings"]) == "function" then
        _nexus_addons_p_save_settings()
    end
    g.vlog("menu_shortcut: %s の %s を %s にした", tostring(key), tostring(field), tostring(value))
    return true
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


-- ===== 更新のお知らせ(NEW / Update の印) =====
--
-- 「機能を足したのに気付かれない」を減らすための仕掛け。出口は 2 つ。
--   * 一覧(core/20_lifecycle.lua)の行と Mini Addons の設定行に付く NEW / Update の印
--   * 印のツールチップ(何が変わったか。updated_note_jp / _en)
--
-- **更新内容そのものはゲーム内に持たない。** 全文は README の更新履歴が持っており、
-- ゲーム内に二重に持つと必ず食い違う(かつては帯 + 全文の窓を出していたが、
-- README と同じ内容を長々と並べるだけになったので畳んだ)。印は「どこが変わったか」を
-- 指すところまでを受け持つ。
--
-- 既読の記録は settings.json のトップレベル 2 つ。**valid_keys への追加が要る**
-- (書き忘れると毎回プルーニングで消える。_nexus_addons_p_load_settings 参照)。
--   seen_ver        …… 印を出す基準。「この版までは知っている」
--   list_opened_ver …… アドオン一覧を開いた版
--
-- **一覧を開いた瞬間に seen_ver を進めないこと。** 印は「どこが新しいのか探す」ための
-- ものなので、開いた瞬間に全部消えると探しに行けない(そもそも印が出る前に消える)。
-- 開いた版は list_opened_ver に控えるだけにして、seen_ver を進めるのは**次の起動**
-- (_nexus_addons_p_load_settings)。つまり「一度一覧を開いたら、次の起動で消える」。
--
-- **seen_ver が無いときは 0.0.0 扱い**にする(= since / updated が付いている項目は全部出る)。
-- 既に使っている人が更新したときにここが空になるので、ver で埋めてしまうと
-- 「印を導入した版の新着が誰にも出ない」ことになる。初回インストールのときだけ ver を入れる。

-- まだ採番していない版を指す印。**main へ入れる PR では版を上げない**(CLAUDE.md の
-- 「バージョン情報はリリース時にだけ上げる」)ので、開発中の since / updated はこれを書く。
-- どの版よりも新しいものとして扱われるため、採番するまでは必ず印が出る。
-- release-prep/vX.Y.Z で実際の版へ置き換える(置き換え忘れは docs/verify_ipf.py が落とす)。
g.VER_NEXT = "next"

-- "2.1.0" のような版を数値の並びにする。VER_NEXT と数字を含まない文字列は nil を返し、
-- 呼び元(g.ver_cmp)がそれぞれ「無限大」「0.0.0」として扱う。
local function ver_parts(v)
    if v == g.VER_NEXT then
        return nil
    end
    local parts = {}
    for n in string.gmatch(tostring(v or ""), "%d+") do
        parts[#parts + 1] = tonumber(n)
    end
    return parts
end

-- 版の比較。a < b なら -1、同じなら 0、a > b なら 1。
-- 桁数が違っても比べられる("2.1" と "2.1.0" は同じ)。数字が 1 つも無いものは 0.0.0 扱い
-- (設定ファイルは手で書き換えられるので、変な値が入っても比較が壊れないようにする)。
function g.ver_cmp(a, b)
    local pa, pb = ver_parts(a), ver_parts(b)
    if pa == nil or pb == nil then
        if pa == nil and pb == nil then
            return 0
        end
        return (pa == nil) and 1 or -1
    end
    local n = math.max(#pa, #pb)
    for i = 1, n do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then
            return (x < y) and -1 or 1
        end
    end
    return 0
end

-- 行に出す印を決める。def は since / updated を持つテーブルなら何でもよい
-- (core/10_registry.lua のエントリでも、mini_addons の設定定義でも同じ形で使う)。
-- 戻り値は "new" / "upd" / nil。
--
-- **NEW を優先する。** 追加した版で中身も直したときに両方出ると読み手が混乱するので、
-- 「追加された」ほうだけを見せる(そもそも追加時に updated は書かない運用)。
function g.badge_of(def)
    if type(def) ~= "table" then
        return nil
    end
    local seen = g.settings and g.settings.seen_ver
    if def.since ~= nil and g.ver_cmp(def.since, seen) > 0 then
        return "new"
    end
    if def.updated ~= nil and g.ver_cmp(def.updated, seen) > 0 then
        return "upd"
    end
    return nil
end

-- 印の表示文字列。**言語によらず英字にする。** 一覧に並ぶアドオン名がすべて英字なので、
-- そこだけ「更新」と混ざると行の中で浮く。
function g.badge_text(badge)
    if badge == "new" then
        return "{ol}{s14}{#FF6347}NEW"
    elseif badge == "upd" then
        return "{ol}{s14}{#FFCC33}Update"
    end
    return nil
end

-- 印のツールチップ。**「この版で変わりました」のような前置きを付けないこと。**
-- 印が出ている時点で「変わった」ことは伝わっているので前置きは何も足さないうえ、
-- 印は seen_ver より新しいものを全部出す = **今の版とは限らない**ので、
-- 「この版で」と書くと嘘になる(v2.0.1 の項目にも出て実際に食い違った)。
-- 出すのは updated_note だけにする。
function g.badge_tooltip(def, badge)
    local ja = g.lang == "Japanese"
    if badge == "new" then
        return ja and "{ol}新しく追加されました" or "{ol}Newly added"
    end
    local note = ja and def.updated_note_jp or def.updated_note_en or def.updated_note_jp
    if note and note ~= "" then
        return "{ol}" .. note
    end
    -- 注記の書き忘れ。**印だけ出して中身が無い**状態なので、そうと分かる形にしておく
    -- (CLAUDE.md は updated_note_jp を省かないことにしている)。
    return ja and "{ol}更新されました" or "{ol}Updated"
end
