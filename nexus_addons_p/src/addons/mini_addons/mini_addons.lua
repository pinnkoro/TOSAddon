-- mini_addons ここから
--
-- 個別版(norisan さん作)を Nexus Addons P へ同梱したもの。自己完結型なので共有
-- フレームワークへは書き換えず、そのまま同梱している。
-- 詳細は docs/INDIVIDUAL_ADDON_COEXIST_DESIGN.md を参照。
--
-- 同梱にあたって変えた点:
--   1. グローバル関数を先頭大文字へ改名(個別版は小文字のままなので衝突しなくなる)
--   2. addon_name に _P を付与(名前空間・設定パス・フレーム名がまとめて分かれる)
--   3. 自前 XML フレームをプログラム生成へ変換(下の create_frame)
--   4. 個別版が抱えていた norisan_menu 実装本体(359 行)を削除。まとめ版は
--      core/90_addons_menu.lua が同じものを addons_menu_* として持っており、
--      二重定義になるため。**ただし _G["norisan"]["MENU"] と "norisan_menu_frame"
--      という待ち合わせ名は ride-along の要なので、絶対に改名しないこと。**
--
-- do ... end で囲む理由は market_favorite_rebuild 側のコメントと同じ。
do
local core_g = g -- まとめ版の g。この直後に個別版自身の local g が影を作るので先に退避する
local core_addon_name_lower = addon_name_lower -- 同上("_nexus_addons_p")。設定の保存先に使う
-- v1.0.0 freefromtrivialsttresからの焼き直し。オートキャスティングをキャラ毎に。機能の有効化無効化を選択出来る様に。
-- v1.0.1 チェック外したら機能しない様に。各キャラ毎のオートキャスティングを直したと思う
-- v1.0.2 ADDONSに表示されない人がいるのでMINIMAP左下ボタンに変更
-- v1.0.3 バフ一覧設定がテレコになっていたのを修正。センスのないボタンを変更
-- v1.0.4 パーティーバフ非表示機能
-- v1.0.5 コインアイテムを取得時に自動使用機能追加
-- v1.0.6 コインアイテム自動使用を街だけに。女神ガチャ時は使用しない様に。レイド入場時装備チェック機能。
-- v1.0.7 女神ガチャ時は使用しない様にしたつもりが出来てなかったのを修正。
-- v1.0.8 ブラックマーケットのお知らせ削除
-- v1.0.9 クエストリスト非表示機能。オートマッチ中のフレームのレイヤー下げる機能。
-- v1.1.0 クエストリスト非表示機能。インベントリ開けたら表示されていたのを修正。
-- v1.1.1 左上の名前をキャラクター名に変更
-- v1.1.2 GAME_START_3SECが重すぎる様になったので3.5SECに
-- v1.1.3 メレジナダイアログ制御。おまけで死んだときに出るダイアログで「近くで復活」にマウスが合うように
-- v1.1.4 チャンネルインフォを作った。
-- v1.1.5 チャンネルインフォのバグ修正。フレーム作る前にrunupdateしてた。
-- v1.1.6 チャンネルインフォ昨日1chだと動かなかったの修正。
-- v1.1.7 メレジナのダイアログ直した。
-- v1.1.8 他人のエフェクトの設定がバグっているらしいので、直した気もする。
-- v1.1.9 チャンネルインフォの表示バグの原因っぽいところを修正。
-- v1.2.0 英語圏のstrの取得方法間違ってたの修正。今いるチャンネルが分かる様にした。
-- v1.2.1 英語版の再修正。これで無理ならもう無理や。
-- v1.2.2 バフリスト表示されないバグ修正。
-- v1.2.3 女神ガチャ自動化。錬成アイテム装備入れたら嵌まる様に。
-- v1.2.4 女神ガチャ機能デフォルトONをOFFに変更
-- v1.2.5 女神ガチャ制御強化
-- v1.2.6 女神ガチャ切り替え後にCCしないと、自動ガチャ機能OFFにならなかったの修正。
-- v1.2.7 女神ガチャフルベットボタンつけた。女神ガチャ中CCやチャンネル移動でフレーム表示されてたの1回目のみに修正。
-- v1.2.8 パーティーインフォフレームの表示切替
-- v1.2.9 パーティーインフォフレーム。いつものバグ修正
-- v1.3.1 プレイヤーゲージにレリック追加。スロガウピニス回ってる時の確認機能。
-- v1.3.2 キャラ毎のオートキャスティング修正。ペットフレーム呼び出し機能OFF
-- v1.3.3 女神証商店のコインの限界値を99999に変更。スロガウピニスのお知らせを派手に。
-- v1.3.4 クローズボタンの場所修正。TP商店開いた時にフレーム消えてたの修正。
-- v1.3.5 BGMプレイヤー。割とガチで10曲目イカレてる。
-- v1.3.6 小さいBGMプレイヤー出さない様に変更
-- v1.3.7 チャンネルインフォフレームをレイドなどでは表示しない様に。マーケット出店時の数量バグ修正。
-- v1.3.8 マーケット出店時の数量バグ修正のバグ修正。
-- v1.3.9 サウンドミュート機能。説明を韓国語版に翻訳。
-- v1.4.0 ユラテコインも自動使用。バフリストバグってたの修正。
-- v1.4.1 自分のエフェクト調整機能追加
-- v1.4.2 ユラテコイン自動使用のバグ修正。装備忘れメッセージを520環境まで拡張。
-- v1.4.3 トークンワープ画面でクールダウン時間表示するように。
-- v1.4.4 ヴァカリネ装備をレイド時に他人に知らせる機能
-- v1.4.5 週ボス報酬を自動で受け取る機能。不安定かも。
-- v1.4.6 テスト用。
-- v1.4.7 死んだときのフレーム制御ミスってたの修正
-- v1.4.8 週ボスのダメージ累計報酬を先週分か今週分か切替出来る様に
-- v1.4.9 ワイドスクリーンだとSetPosおかしいらしい。アドオンの前提が色々崩れそう。コワイヨ
-- v1.5.0 クポルポーションのフレームを非表示に
-- v1.5.1 PTメンバーの希望の啓示見えるように
-- v1.5.2 ラガナを非表示に
-- v1.5.3 インベントリでイコルステータス検索出来る様に。装備錬成の武器防具ステータス付与自動化
-- v1.5.4 ヴェルニケ階数覚える様に、クポルポーション改修、セパレートフレームのスキン消した、チャンネルの混み具合直した。
-- v1.5.5 JSON作るとこバグってたので直した。。。
-- v1.5.6 パーティーバフリスト取るとこが他のアドオンと喧嘩してるらしいので直した。韓国語を教えてもらった。
-- v1.5.7 グループチャットをチャットフレームから選択出来る様にした。
-- v1.5.8 グループチャットバグ修正
-- v1.5.9 どこでもmemberinfo出来る様に。
-- v1.6.0 デバフ表示バグってたの修正
-- v1.6.1 チャンネルインフォのサイズ変更。ちょっとバグ修正。
-- v1.6.2 EP13ショップを街で開けられる様に。
-- v1.6.3 バウバスのお知らせ
-- v1.6.4 多分グルチャ直った。IMCに勝ったかも
-- v1.6.5 ウルトラワイドモードから通常に戻した時にフレーム消えたの修正
-- v1.6.6 ウルトラワイドで位置保存機能バグってたの修正。
-- v1.6.7 ウルトラワイドを再修正。クエストフレームの挙動を追加
-- v1.6.8 チャンネルフレームの初期場所修正。セッティングファイルバグ修正
-- v1.6.9 ボスのエフェクト調整。FPSの手入力。ブラックマーケットのお知らせ修正。ヴェルニケ報酬自動受け取り
-- v1.7.0 週間ボス報酬系修正。いつでもメンバーチャット修正。
-- v1.7.1 エフェクト関係のバグ修正。NOTICE_ON_MSGのバグ修正。
-- v1.7.2 アドオンボタン回り修正。どこでもメンバーインフォ修正。バフリスト検索機能
-- v1.7.3 PTメンバーの死亡をニコチャットでお知らせ機能
-- v1.7.4 フレームの分類分け、ペットリング非表示、コロニーの街へ移動のタイマー修正（IMCが直せよ）
-- v1.7.5 コロニーの街へ移動のタイマー再修正、追加チャットフレームの移動制限削除、デイリクエストを別窓表示。グルチャ系を直したつもり
-- v1.7.6 250902大型アプデ対応。アウステヤコイン。indunpanelからオートズーム機能移行、RP補充補完機能、スキルクール音消去、インベントリいじった、
-- v1.7.7 ペット呼び出しバグ修正。オプション数値の常時表示
-- v1.7.8 オプション数値のテキスト消えなかったの修正
-- v1.7.8.1 傭兵クエストの諦めるボタン、EP13ショップの製造書の種類表示
-- v1.7.8.2 ヘアエンチャントロールを便利に
-- v1.7.8.3 グルチャ直した
-- v1.7.8.5 グルチャ再修正
-- v1.7.8.6 ヘアエンチャントのバグ修正、チャットに機能追加、スキル錬成にツールチップ追加
-- v1.7.8.7 チャットエクステンド有効の場合はチャット機能OFF、ボスレランキング機能、製造自動セット、場所表示バグ修正
-- v1.7.8.8 ボスレランキングソードマン系統タブから取得しないと正常に動かないの修正、恩恵付きイコルの場合に数値表出ないバグ修正、レイドレコードの計算修正、読込遅い問題修正
-- v1.7.8.9 ボスレダメージランキング報酬にちょい残しボタンを追加
-- v1.7.9 追加報酬券お知らせ機能
-- v1.7.9.1 イベントシャウトチャット機能、インベントリor検索
-- v1.7.9.2 コード見直し。書き直し。acutil排除
-- v1.8.0 チャットフレーム改造のバグ修正
-- v1.8.1 ダイアログ制御最速化。ブラックマーケットお知らせ修正。
local addon_name = "MINI_ADDONS_P"
local addon_name_lower = string.lower(addon_name)
local author = "norisan"
local ver = "1.8.1"

_G["ADDONS"] = _G["ADDONS"] or {}
_G["ADDONS"][author] = _G["ADDONS"][author] or {}
_G["ADDONS"][author][addon_name] = _G["ADDONS"][author][addon_name] or {}
local g = _G["ADDONS"][author][addon_name]

-- **読み込み時の require を素で書かないこと。** ここは conclude チャンクの途中で、
-- 例外が出るとそこから後ろの定義が丸ごと失われる(mini_addons の残りと
-- market_favorite_rebuild が全部消える)。しかも読み込み時の例外はどこにも残らないので、
-- 「特定のアドオンだけ無反応」という一番分かりにくい形でしか表に出ない。
-- 引けなかったモジュールは nil のまま進め、使う側で落ちてもらう方が被害が小さい
-- (そちらは pcall の内側なのでログに残る)。
local function safe_require(name)
    local ok, mod = pcall(require, name)
    if ok then
        return mod
    end
    core_g.conclude_require_failed = (core_g.conclude_require_failed or "") .. name .. " "
    return nil
end

-- os は require しなくても最初から居る標準ライブラリなので、**引けなくても
-- グローバルの os へ必ず落とすこと**。ここを nil のままにすると、読み込み時の
-- 1 回の中断で済むはずの失敗が、os.date / os.time を使う 15 箇所へ散らばった
-- 実行時エラーに化ける(しかも発生箇所と原因が離れて追いにくい)。
local os = safe_require("os") or os
-- 個別版にあった json / json_imc の require は削除した。**どちらもこのファイルで
-- 使っていない**うえ、json_imc は src 全体でここでしか require しておらず、
-- 解決できないと毎セッション core_g.conclude_require_failed が立つ。すると
-- GAME_START の状態行が恒久的に `require=json_imc` を報告し続け、**健全性を見るための
-- 1 行が偽の警告で埋まる**。json の読み書きは core_g.load_json / save_json 経由。

local function ts(...)
    local num_args = select("#", ...)
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

-- 保存先はまとめ版に揃える(../addons/_nexus_addons_p/<AID>/<アドオン名>.json)。
-- 個別版は ../addons/mini_addons/<AID>_1.json に置いていたが、同梱版では他の 48 アドオンと
-- 同じ場所・同じ命名にする。この場所へ置くことで core/30_maintenance.lua のバックアップ/
-- 復元の対象にもなる(対象は固定名の一覧 g.backup_files なので、そちらへの追加が必須)。
--
-- AID の取得と組み立ては ON_INIT まで遅らせる。個別版はチャンク読み込み時に取っていたが、
-- 同梱版では 1 本の .lua に他アドオンが後ろへ連結されているため、ここで AID が取れないと
-- string.format(..., nil) が投げるエラーで**この後ろの定義がまるごと失われる**
-- (直後に連結される market_favorite_rebuild が丸ごと消える)。まとめ版も AID は ON_INIT で
-- 取っている(core/00_header.lua の g.active_id)ので、それに揃える。
function g.update_paths()
    local active_id = core_g.active_id or session.loginInfo.GetAID()
    g.active_id = active_id
    g.settings_path = string.format("../addons/%s/%s/mini_addons.json", core_addon_name_lower, active_id)
    -- バフ一覧だけ .lua で持つ。**json に戻してはいけない。**
    -- クライアントの json.decode は 1 つのオブジェクトのキー数に対して二次で、この
    -- ファイルはバフ ID をキーにした平坦なテーブル = ゲーム内の全バフ数まで育つ。
    -- 実機で 2806 キー / 26KB のとき **読み込みだけで 5247ms**(同じテーブルの書き戻しは
    -- 5ms なので、遅いのはデコードだけ)。これが初回ログイン時の数秒フリーズの正体で、
    -- mini_addons の on_init 5419ms のうち 5254ms を占めていた。
    -- .lua は loadfile = クライアント同梱の LuaJIT の構文解析器を通るので線形。
    -- always_status も同じ理由で先に .lua へ移してある(g.load_lua / g.save_lua)。
    -- 一括 OFF を押すと全バフぶんの 0 が並ぶので、「普通に使うと必ず膨らむ」形。
    g.buffs_path = string.format("../addons/%s/%s/mini_addons_buffs.lua", core_addon_name_lower, active_id)
    -- 旧 json。読み込み時に 1 回だけ変換元として見る(Mini_addons_load_buffs)。
    -- 本家個別版からの引き継ぎ(migrate_individual_addon_settings)も json を置くので、
    -- この経路は「昔の自分」と「個別版から来た人」の両方の入口になる。
    g.buffs_json_path = string.format("../addons/%s/%s/mini_addons_buffs.json", core_addon_name_lower, active_id)
    -- バフ一覧の「バックアップ」用。1 世代だけ持つ(まとめ版の設定バックアップとは別で、
    -- バフ一覧だけを一括で切り替える前に自分で控えるためのもの)。
    -- 中身は buffs と同じテーブルなので、こちらも .lua(復元時に同じデコードを通るため)。
    g.buffs_backup_path = string.format("../addons/%s/%s/mini_addons_buffs_backup.lua", core_addon_name_lower,
        active_id)
    g.buffs_backup_json_path = string.format("../addons/%s/%s/mini_addons_buffs_backup.json", core_addon_name_lower,
        active_id)
    -- AID を取り違えると設定が別フォルダに作られて「設定が消えた」ように見えるので、
    -- 確定した保存先を残す。ON_INIT はマップ移動のたびに走るので、変わったときだけ出す。
    -- 印は出力できたときだけ立てる(core の g.vlog のコメント参照)。先に立てると
    -- ログ OFF の初回で消費され、後から ON にしても保存先が分からないままになる。
    if g.logged_settings_path ~= g.settings_path and
        core_g.vlog("mini_addons: 保存先 %s", tostring(g.settings_path)) then
        g.logged_settings_path = g.settings_path
    end
end

-- 自分のフレームを取る。無ければ作る。
-- マップ移動でクライアントがフレームを破棄する一方、作り直すのはまとめ版の init_addons
-- (実測で GAME_START の約 2 秒後)。GAME_START やゲームイベントの購読はそれより先に
-- 呼ばれるので、素の ui.GetFrame をそのまま使うと nil を触って落ちる。
-- (実機ログで確認: マップ移動のたびに Mini_addons_GAME_START が
--  "attempt to index a nil value (local 'mini_addons')" で落ちていた)
function g.get_frame()
    local frame = ui.GetFrame(addon_name_lower)
    if frame then
        return frame
    end
    core_g.vlog("mini_addons: フレームが無いので作り直す")
    return Mini_addons_create_frame()
end

-- 置換方式のフック。**実装はまとめ版の core_g.setup_hook 1 本**に寄せてある。
-- 以前はここに同じ 15 行を書き写していたが、掛け直しの規則を直すたびに 2 箇所へ
-- 反映する必要があり、実際に食い違いが出た(片方だけが「差し替えられていたら掛け直す」に
-- なっていた)。渡すのは自分側の表と控えの接頭辞だけ。
--   * 控えの名前(MINI_ADDONS_P_REPLACE_*)を分ける … 共有すると、どちらが先に掛けたかで
--     相手のフックを落としてしまう。
--   * g.FUNCS を分ける … まとめ版のものを共有すると、まとめ版が先に掛けている
--     グローバル(CHAT_SYSTEM など)で、まとめ版の g.FUNCS が自分自身を指して無限再帰する。
--   * g.hook_installed … 入れた実体の控え(機能 OFF のときに戻すのに使う)。
-- 「今 _G に居るのは味方」をまとめ版へ伝えるのは core_g.setup_hook がやる
-- (無いと、まとめ版の setup_hook_and_event がここで入れたフックを落とす)。
g.hook_installed = g.hook_installed or {}

function g.setup_hook(my_func, origin_func_name)
    g.FUNCS = g.FUNCS or {}
    core_g.setup_hook(my_func, origin_func_name, {
        installed = g.hook_installed,
        funcs = g.FUNCS,
        prefix = string.upper(addon_name),
        label = "mini_addons"
    })
end

-- 個別版はここで自分のフォルダを os.execute('mkdir') で作っていたが、同梱版は保存先を
-- まとめ版の ../addons/_nexus_addons_p/<AID>/ に移したので不要になったため削除した。
-- そのフォルダは core 側が作る。os.execute は GUI プロセスから呼ぶと必ずコンソール窓を
-- 出すので、消せるものは消す(CLAUDE.md「CMD をなるべく出さない」)。

-- JSON の読み書きとマップ種別の取得はまとめ版のものを使う(戻り値は個別版と同じ)。
-- 個別版と同じ実装をここに置いても増えるのは差異だけで、まとめ版側は .tmp 経由の
-- アトミック保存(=途中で落ちても設定を失わない)と MapType の nil ガードを持っている。
function g.save_json(path, tbl)
    return core_g.save_json(path, tbl)
end

function g.load_json(path)
    return core_g.load_json(path)
end

-- .lua 形式の読み書き(バフ一覧の保存先。理由は g.update_paths のコメント)。
-- **ラッパを置くのを忘れないこと。** ここは個別版由来の自分の g で、まとめ版の g とは
-- 別物。core_g にしかない関数を g. で呼ぶと nil を呼んで on_init が丸ごと落ち、
-- mini_addons が何一つ動かなくなる(実機で発生: バフ一覧が出なくなり、初期化が
-- 最初の load_buffs で中断していたのを「速くなった」と読み違えかけた)。
function g.save_lua(path, tbl)
    return core_g.save_lua(path, tbl)
end

function g.load_lua(path)
    return core_g.load_lua(path)
end

function g.get_map_type()
    return core_g.get_map_type()
end

-- イベント方式のフックはまとめ版へ丸投げする(登録簿 g.FUNCS / g.ARGS / g.REGISTER も
-- まとめ版のものを使う)。個別版と同じ実装をここに持つと、まとめ版が既にラップした
-- グローバルをもう一段ラップすることになり、1 回の呼び出しで imcAddOn.BroadMsg が
-- 2 回飛ぶ = そのメッセージの購読者が全員 2 回走る。
-- 例: INVENTORY_OPEN は cc_helper と other_character_skill_list も、DRAW_CHAT_MSG は
-- archeology_helper も、SHOW_INDUNENTER_DIALOG は quickslot_operate も購読している。
-- まとめ版の実装は同じグローバルに何度掛けても控えを取り直さないので、二重にはならない。
function g.setup_hook_and_event(my_addon, origin_func_name, my_func_name, bool)
    core_g.setup_hook_and_event(my_addon, origin_func_name, my_func_name, bool)
    -- 個別版のコードは元の関数を g.FUNCS[...] から直接呼ぶので、まとめ版が退避した実体を写す。
    -- 既に値があるときは触らない: g.setup_hook(置換方式)で控えた実体を上書きすると、
    -- 自分自身を呼んで無限再帰になる(NOTICE_ON_MSG は置換とイベントの両方を掛けている)。
    g.FUNCS = g.FUNCS or {}
    if g.FUNCS[origin_func_name] == nil then
        g.FUNCS[origin_func_name] = core_g.FUNCS[origin_func_name]
    elseif g.hook_installed[origin_func_name] then
        -- 両方式が同じグローバルに掛かった数少ない箇所(NOTICE_ON_MSG)。無限再帰と
        -- 紙一重なので必ず残す。同じグローバルへ 2 回イベント方式を掛けただけのとき
        -- (WEEKLY_BOSS_RANK_UPDATE)はここに来ないよう、置換済みかどうかで絞る。
        core_g.vlog("mini_addons: %s は置換方式の控えを維持する", origin_func_name)
    end
end

function g.get_event_args(origin_func_name)
    return core_g.get_event_args(origin_func_name)
end

function g.split(input_str, separator)
    local parts = {}
    local start_pos = 1
    while true do
        local sep_start, sep_end = string.find(input_str, separator, start_pos, true)
        if not sep_start then
            table.insert(parts, string.sub(input_str, start_pos))
            break
        end
        table.insert(parts, string.sub(input_str, start_pos, sep_start - 1))
        start_pos = sep_end + 1
    end
    return parts
end

function g.load_dat(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end
    local content = file:read("*all")
    file:close()
    if content == "" or content == nil then
        return {}
    end
    local records = {}
    for line in content:gmatch("([^\n]+)") do
        if line ~= "" then
            local parts = g.split(line, ":::")
            if #parts == 7 then
                table.insert(records, parts)
            end
        end
    end
    return records
end

-- !追加の度に更新
local DEFAULT_SETTINGS = {
    reword_x = 1100,
    reword_y = 100,
    allcall = 0,
    under_staff = 0,
    raid_record = 0,
    party_buff = 0,
    chat_system = 0,
    channel_display = 0,
    channel_info = 0,
    mini_btn = 0,
    market_display = 0,
    restart_move = 0,
    pet_init = 0,
    dialog_ctrl = 0,
    auto_cast = 0,
    auto_casting = {},
    coin_use = 0,
    equip_info = 0,
    automatch_layer = 0,
    quest_hide = 0,
    pc_name = 0,
    auto_gacha = 0,
    auto_gacha_start = 0,
    skill_enchant = 0,
    party_info = 0,
    relic_gauge = 0,
    raid_check = 0,
    coin_count = 0,
    bgm = 0,
    my_effect = 0,
    other_effect = 0,
    boss_effect = 0,
    vakarine = 0,
    weekly_boss_reward = 0,
    solodun_reward = 0,
    cupole_portion = {
        use = 0,
        x = 0,
        y = 0,
        def_x = 0,
        def_y = 0
    },
    goodbye_ragana = 0,
    -- 決闘の申し込みを自動で受ける。既定は 0(OFF)。**既定を 1 にしないこと。**
    -- 断る自由を黙って奪うことになるので、明示的に ON にした人だけに効かせる。
    auto_accept_duel = 0,
    status_upgrade = 0,
    icor_status_search = 0,
    velnice = {
        use = 0,
        level = ""
    },
    separated_buff = 0,
    group_name = {},
    group_chat = 0,
    memberinfo = 0,
    baubas_call = {
        use = 0,
        guild_notice = 0
    },
    chat_recv = 0,
    pet_ring = 0,
    daily_quest = 0,
    chat_frame = 0,
    restart_colony = 0,
    auto_zoom = {
        use = 0,
        zoom = 336
    },
    rp_charge = 0,
    skill_cool_sound = 0,
    inventory_mod = 0,
    reroll_option = 0,
    hair_enchant = 0,
    -- ヘアエンチャントの「高度な設定」窓を、素材を乗せた時点で自動で開くか
    hair_enchant_auto_open = 0,
    -- 高度な設定のプリセット。**配列**(1 始まり)で枠数は決めない。1 件の中身は
    --   {name = 表示名, options = {オプションのクラス名, ...}, rank = "B"/"None",
    --    repeat_count = 数, fast = 0/1}
    -- **オプションはクラス名で持つこと。** 画面のチェックの名前(option_text<番号>)は
    -- enchant_special_option の並び順に依存し、出る項目もランクで変わるため、
    -- 番号で保存すると別のオプションを復元しかねない
    hair_enchant_presets = {},
    new_groups = {},
    chat_new_btn = 0,
    chat_xy = {},
    pt_info = 0,
    enchant_tooltip = 0,
    boss_rank = 0,
    auto_craft = 0,
    keep_first = 0,
    multiple_item = 0,
    event_shout = {
        use = 0,
        guild_notice = 0
    },
    select_bgm = "",
    -- 設定画面のセクションを畳んでいるか（キーは SETTING_SECTIONS の name、1 で折りたたみ）
    section_collapsed = {}
}

local SETTINGS_NAME = {"other_effect", "my_effect", "boss_effect", "channel_info", "pc_name", "quest_hide",
                       "automatch_layer", "equip_info", "under_staff", "raid_record", "party_buff", "chat_system",
                       "channel_display", "mini_btn", "market_display", "restart_move", "pet_init", "dialog_ctrl",
                       "auto_cast", "coin_use", "auto_gacha", "skill_enchant", "party_info", "relic_gauge",
                       "raid_check", "coin_count", "bgm", "vakarine", "weekly_boss_reward", "solodun_reward",
                       "cupole_portion", "goodbye_ragana", "status_upgrade", "icor_status_search", "velnice",
                       "separated_buff", "group_chat", "memberinfo", "baubas_call", "pt_buff", "chat_recv", "pet_ring",
                       "daily_quest", "chat_frame", "restart_colony", "auto_zoom", "rp_charge", "skill_cool_sound",
                       "inventory_mod", "reroll_option", "hair_enchant", "chat_new_btn", "pt_info", "enchant_tooltip",
                       "boss_rank", "auto_craft", "keep_first", "multiple_item", "event_shout", "auto_accept_duel"}

local COIN_ITEM = {869001, 11200350, 11200303, 11200302, 11200301, 11200300, 11200299, 11200298, 11200297, 11200161,
                   11200160, 11200159, 11200158, 11200157, 11200156, 11200155, 11030215, 11030214, 11030213, 11030212,
                   11030211, 11030210, 11030201, 11035673, 11035670, 11035668, 11030394, 11030240, 646076, 11035672,
                   11035669, 11035667, 11035457, 11035426, 11035409, 11201239, 11201238, 11201237, 11201236, 11201235,
                   11201234, 11201233, 11201232, 11202008, 11202007, 11202006, 11202005, 11202004, 11202003, 11202002,
                   11202001}

-- 設定項目の文言定義（その 1）。上流では設定画面の先頭に並べていた分。
-- どのセクションに出すかは SETTING_SECTIONS 側で決めるので、ここの並びは表示順ではない
local MAIN_FRAME_SETTINGS = {{
    name = "event_shout",
    text_jp = "イベントグローバルシャウトをチャットに表示",
    text_kr = "이벤트 글로벌 샤우트를 채팅에 표시",
    text_en = "Displays Event Global Shouts in the chat"
}, {
    name = "multiple_item",
    text_jp = "メレジナハード以降のハードレイドで追加報酬券お知らせ",
    text_kr = "메레지나 하드 이후의 하드 레이드에서 추가 보상권 알림",
    text_en = "Merregina Hard & above Hard Raids: Bonus Ticket Notice"
}, {
    name = "keep_first",
    text_jp = "週ボスダメージ報酬の1段目を残すボタンを作成",
    text_kr = "주간 보스 보상 첫 번째 유지 컨트롤 생성",
    text_en = "Create Weekly Boss Damage Reward 1st Keep Control"
}, {
    name = "auto_craft",
    text_jp = "アイテム製造時 自動でセットします",
    text_kr = "아이템 제조 시 자동으로 세트됩니다",
    text_en = "Automatically set during item crafting"
}, {
    name = "boss_rank",
    text_jp = "ボスレイドのビルドランキング作成",
    text_kr = "보스 레이드 빌드 랭킹 생성",
    text_en = "Create the build ranking for boss raids"
}, {
    name = "enchant_tooltip",
    text_jp = "スキル錬成スロットにツールチップ追加",
    text_kr = "스킬 인챈트 슬롯에 툴팁을 추가했습니다",
    text_en = "Added tooltips to the skill enchantment slots"
}, {
    name = "pt_info",
    text_jp = "PT情報にメンバーの場所追加",
    text_kr = "PT 정보에 멤버 위치를 추가했습니다",
    text_en = "Added member locations to PT information"
}, {
    name = "chat_new_btn",
    text_jp = "チャット入力フレームにボタン追加",
    text_kr = "채팅 입력 창에 버튼을 추가했습니다",
    text_en = "Added a button to the chat input frame"
}, {
    name = "hair_enchant",
    text_jp = "ヘアアクセサリーのエンチャント自動付与を使いやすく",
    text_kr = "헤어 액세서리 자동 인챈트 사용성 개선",
    text_en = "Hair Accessory Auto-Enchant UX improved"
}, {
    name = "reroll_option",
    text_jp = "オプション設定の数値表を常に表示",
    text_kr = "옵션 설정의 수치 표를 항상 표시합니다",
    text_en = "Always display the numerical table for option settings"
}, {
    name = "inventory_mod",
    text_jp = "インベントリのスロットを少し改造",
    text_kr = "인벤토리 슬롯을 약간 개조했습니다",
    text_en = "Slightly modified the inventory slots"
}, {
    name = "auto_zoom",
    text_jp = "マップ切り替え時に自動でズーム",
    text_kr = "맵 이동 시 자동으로 지도를 확대합니다",
    text_en = "Automatically zooms the map when changing maps"
}, {
    name = "restart_colony",
    text_jp = "コロニー死亡時の30秒タイマーを修正",
    text_kr = "콜로니 사망 시 30초 타이머 수정",
    text_en = "Fixed the 30-second timer on death in Colonies"
}, {
    name = "under_staff",
    text_jp = "4人以下の入場確認をスキップ",
    text_kr = "4인 이하 입장 확인 건너뛰기",
    text_en = "Skip confirmation for admission of 4 or fewer people"
}, {
    name = "party_buff",
    text_jp = "PTメンバーのバフを非表示",
    text_kr = "파티원 버프 숨기기",
    text_en = "Hide buffs for party members"
}, {
    name = "channel_display",
    text_jp = "チャンネル表示のズレを修正(日本語版)",
    text_kr = "채널 표시 오류 수정(일본어)",
    text_en = "Fixed channel display misalignment for Japanese ver"
}, {
    name = "coin_count",
    text_jp = "各商店のコイン上限を99999に",
    text_kr = "각 상점 코인 상한을 99999로",
    text_en = "Raise coin limit to 99999 for each shop"
}, {
    name = "bgm",
    text_jp = "街でBGMプレイヤーを常にオンにする",
    text_kr = "도시에서는 항상 BGM 플레이어를 재생합니다",
    text_en = "Always play BGM in the city"
}, {
    name = "icor_status_search",
    text_jp = "インベントリでイコルのステータスを検索 半角スペースでor検索",
    text_kr = "인벤토리에서 아이커 능력치 검색 반각 공백으로 OR 검색",
    text_en = "Search Icor status in Inventory OR search using half-width spaces"
}, {
    name = "velnice",
    text_jp = "ヴェルニケの以前の階層を覚える",
    text_kr = "벨니케의 이전 레벨을 기억하다",
    text_en = "Remember Velnice's previous level"
}, {
    name = "memberinfo",
    text_jp = "各種右クリックメニューにメンバーインフォを追加",
    text_kr = "각종 오른쪽 클릭 메뉴에 멤버 정보 추가",
    text_en = "Add member info to various right-click menus"
}}
-- 設定項目の文言定義（その 2）。上流ではカテゴリ別のサブウィンドウに出していた分。
-- こちらもキーは由来を示すだけで、表示先は SETTING_SECTIONS が決める
local SUB_FRAME_SETTINGS = {
    chats = {{
        name = "chat_system",
        text_jp = "パーフェクトとブラックマーケットのお知らせをチャットに表示しません",
        text_kr = "완벽함 메시지 및 블랙 마켓 공지를 채팅에 표시 하지 않습니다",
        text_en = "Perfect and Black Market notices not displayed in chat"
    }, {
        name = "group_chat",
        text_jp = "グループチャットをチャットフレームから選択出来ます",
        text_kr = "채팅 프레임에서 그룹 채팅을 선택할 수 있습니다",
        text_en = "Group chats can be selected from chat frame"
    }, {
        name = "baubas_call",
        text_jp = "バウバス登場をお知らせ",
        text_kr = "바우버스 등장 소식",
        text_en = "Announcing the arrival of Baubas"
    }, {
        name = "chat_recv",
        text_jp = "PTメンバーの死亡をニコチャットで表示",
        text_kr = "PT 멤버의 사망을 니코챗으로 표시하기",
        text_en = "Death of a PT member is indicated in Nicochat"
    }, {
        name = "chat_frame",
        text_jp = "ワイドモニターの追加チャットフレームの移動制限解除",
        text_kr = "와이드 모니터에서 추가 채팅창의 이동 제한 해제",
        text_en = "Freely move additional chat frames on wide monitors"
    }},
    chars = {{
        name = "my_effect",
        text_jp = "自分のエフェクトを調整します(1~100)",
        text_kr = "나만의 효과를 조정합니다(1~100)",
        text_en = "Adjust my effects(1~100)"
    }, {
        name = "other_effect",
        text_jp = "他人のエフェクトを調整します(1~100)",
        text_kr = "다른 사람의 효과를 조정합니다(1~100)",
        text_en = "Adjust other people's effects(1~100)"
    }, {
        name = "boss_effect",
        text_jp = "ボスのエフェクトを調整します(1~100)",
        text_kr = "보스 효과를 조정합니다(1~100)",
        text_en = "Adjust boss effects(1~100)"
    }, {
        name = "auto_cast",
        text_jp = "オートキャスティングをキャラ毎に設定",
        text_kr = "캐릭터별로 자동 시전 설정",
        text_en = "Set auto casting per character"
    }, {
        name = "pc_name",
        text_jp = "左上の名前をキャラクター名に変更します",
        text_kr = "좌측 상단의 이름을 캐릭터 이름으로 변경합니다",
        text_en = "Change the name in the top left to your character's name"
    }, {
        name = "relic_gauge",
        text_jp = "キャラクターゲージにレリックを追加します",
        text_kr = "캐릭터 게이지에 유물을 추가합니다",
        text_en = "Add a Relic to the character's gauge"
    }, {
        name = "equip_info",
        text_jp = "アーク/エンブレム装備忘れ通知",
        text_kr = "아크/엠블렘 장비 미착용 알림",
        text_en = "Notification for unequipped Ark/Emblem"
    }, {
        name = "vakarine",
        text_jp = "レイドでヴァカリネ装備を通知",
        text_kr = "레이드에서 바카리네 장비 알림",
        text_en = "Vakarine Equipment Notification in Raids"
    }, {
        name = "skill_cool_sound",
        text_jp = "スキル連打時のクールタイムの音を消去",
        text_kr = "스킬 연타 시의 재사용 대기시간(쿨타임) 효과음을 삭제했습니다",
        text_en = "Removed the cooldown sound when a skill is spammed"
    }},
    frames = {{
        name = "raid_record",
        text_jp = "レイドレコードを移動可能にしてサイズを変更",
        text_kr = "레이드 기록의 이동이 가능하고, 크기 조절을 할 수 있습니다",
        text_en = "Raid records movable and resizable"
    }, {
        name = "mini_btn",
        text_jp = "レイド時右上のミニボタン非表示",
        text_kr = "레이드 중 오른쪽 상단의 미니 버튼을 숨깁니다",
        text_en = "Hide minibutton in upper right corner during raid"
    }, {
        name = "market_display",
        text_jp = "街では、右上の商店一覧を常に表示します",
        text_kr = "도시 이동 시 상점 목록을 항상 열어둡니다",
        text_en = "Keep shop list open when moving to city"
    }, {
        name = "restart_move",
        text_jp = "リスタート時の選択肢フレームを動かせる様にします",
        text_kr = "재시작 시 선택 프레임을 이동할 수 있게 합니다",
        text_en = "Allow moving selection frame on restart"
    }, {
        name = "automatch_layer",
        text_jp = "オートマッチ時のフレームのレイヤーレベルを下げます",
        text_kr = "자동 매칭 시 프레임 레이어 레벨을 낮춥니다",
        text_en = "Lower frame layer level during auto match"
    }, {
        name = "quest_hide",
        text_jp = "クエストリストを非表示にします",
        text_kr = "퀘스트 목록을 숨깁니다",
        text_en = "Hide the quest list"
    }, {
        name = "channel_info",
        text_jp = "チャンネル切替フレームを表示します",
        text_kr = "채널 전환 프레임을 표시합니다",
        text_en = "Displays the channel switching frame"
    }, {
        name = "auto_gacha",
        text_jp = "女神の加護ガチャフレーム表示を自動化します",
        text_kr = "여신의 가호 가챠 프레임 표시를 자동화합니다",
        text_en = "Automate the display of the Goddess Protection gacha frame"
    }, {
        name = "party_info",
        text_jp = "パーティー情報フレームをバフ数に合わせてリサイズ",
        text_kr = "파티 정보 프레임을 버프 수에 맞춰 리사이즈",
        text_en = "Resized the party information frame to match the number of buffs"
    }, {
        name = "cupole_portion",
        text_jp = "クポルのポーションフレームを非表示に。OFFでもフレームの位置記憶",
        text_kr = "큐폴의 포션 프레임을 숨기고, OFF 상태에서도 프레임 위치를 기억합니다",
        text_en = "Hide the potion frame of the cupole.Memorizes frame position even when OFF"
    }, {
        name = "separated_buff",
        text_jp = "セパレートバフフレームの周りを綺麗にします",
        text_kr = "분리형 버프 프레임 주변을 없앱니다",
        text_en = "Eliminate around separate buff frame"
    }, {
        name = "pet_ring",
        text_jp = "ペットリングフレームを非表示にします",
        text_kr = "펫 링 프레임을 숨깁니다",
        text_en = "Hides the pet ring frame"
    }, {
        name = "daily_quest",
        text_jp = "デイリークエストを別窓で表示",
        text_kr = "일일 퀘스트를 별도 창에 표시합니다",
        text_en = "Display the daily quest in a separate window"
    }},
    autos = {{
        name = "coin_use",
        text_jp = "各種コインを取得時に自動で使用します",
        text_kr = "각종 코인 획득 시 자동 사용",
        text_en = "Automatically use various coins upon acquisition"
    }, {
        name = "skill_enchant",
        text_jp = "スキル錬成のアイテムを自動でセットします",
        text_kr = "스킬 연성을 위한 아이템을 자동으로 설정합니다",
        text_en = "Automatically sets items for skill refining"
    }, {
        name = "weekly_boss_reward",
        text_jp = "週間ボスレイド報酬を自動で受け取り",
        text_kr = "주간 보스 레이드 보상을 자동으로 수령",
        text_en = "Receive weekly boss reward automatically"
    }, {
        name = "solodun_reward",
        text_jp = "ヴェルニケダンジョン報酬を自動で受け取り",
        text_kr = "벨니체 던전 보상 자동 받기",
        text_en = "Receive Velnice dungeon reward automatically"
    }, {
        name = "status_upgrade",
        text_jp = "装備錬成、武器防具ステータス付与を自動化",
        text_kr = "장비 연성, 무기 방어구 스테이터스 부여 자동화",
        text_en = "Equip Refining, Automate weapon/armor enhancement"
    }, {
        name = "dialog_ctrl",
        text_jp = "各種ダイアログを制御",
        text_kr = "각종 다이얼로그 제어",
        text_en = "Controls various dialogs"
    }, {
        name = "auto_accept_duel",
        text_jp = "決闘の申し込みを自動で受ける",
        text_kr = "결투 신청을 자동으로 수락",
        text_en = "Automatically accept duel requests"
    }, {
        name = "goodbye_ragana",
        text_jp = "街でラガナを非表示",
        text_kr = "마을에서 라가나 숨기기",
        text_en = "Hide Ragana in city"
    }, {
        name = "rp_charge",
        text_jp = "レリック自動補充を補完",
        text_kr = "레릭 자동 보충 기능에 보완(복구) 기능이 추가되었습니다",
        text_en = "Relic auto-replenishment now includes a recovery function"
    }}
}

-- 設定画面のセクション定義。以前はカテゴリのボタンを押して別ウィンドウ(sub_frame)を
-- 開いていたが、検索でまとめて絞り込めるよう 1 枚のスクロールする一覧に統合し、
-- ここの見出しで区切って並べる。順序はそのまま表示順になる。
--
-- 中身は文言の定義そのものではなく **設定名の並び** で持つ。上の
-- MAIN_FRAME_SETTINGS / SUB_FRAME_SETTINGS は上流由来でどちらに書かれているかが
-- 分類と一致していないので、「どこに出すか」はここだけ見れば分かる形に分けてある
-- （項目を別のセクションへ移すときに、文言のブロックを動かさなくて済む）。
local SETTING_SECTIONS = {{
    name = "chats",
    names = {"chat_system", "group_chat", "baubas_call", "chat_recv", "chat_frame", "event_shout", "multiple_item",
             "chat_new_btn"},
    text_jp = "チャット関連",
    text_kr = "채팅 관련",
    text_en = "Chat-related"
}, {
    name = "chars",
    names = {"my_effect", "other_effect", "boss_effect", "auto_cast", "pc_name", "relic_gauge", "equip_info",
             "vakarine", "skill_cool_sound"},
    text_jp = "キャラクター関連",
    text_kr = "캐릭터 관련",
    text_en = "Character-related"
}, {
    name = "frames",
    names = {"raid_record", "mini_btn", "market_display", "restart_move", "restart_colony", "automatch_layer",
             "quest_hide", "channel_info", "channel_display", "auto_gacha", "party_info", "pt_info", "party_buff",
             "cupole_portion", "separated_buff", "pet_ring", "daily_quest", "inventory_mod", "icor_status_search",
             "reroll_option", "enchant_tooltip", "keep_first", "boss_rank", "memberinfo"},
    text_jp = "フレーム関連",
    text_kr = "프레임 관련",
    text_en = "Frame-related"
}, {
    name = "autos",
    names = {"coin_use", "skill_enchant", "weekly_boss_reward", "solodun_reward", "status_upgrade", "dialog_ctrl",
             "under_staff", "auto_accept_duel", "goodbye_ragana", "rp_charge", "auto_craft", "hair_enchant",
             "auto_zoom", "velnice"},
    text_jp = "自動処理関連",
    text_kr = "자동 처리 관련",
    text_en = "Automation-related"
}, {
    -- どのセクションにも当てはまらないものの受け皿。必ず最後に置くこと
    -- （下の振り分けで、名前を書き忘れた項目もここへ落とすため）
    name = "etc",
    names = {"coin_count", "bgm"},
    text_jp = "その他",
    text_kr = "기타",
    text_en = "Other"
}}

-- 上の names を実際の定義（文言）に解決して section.items に詰める。
-- 名前を書き忘れた項目は最後のセクション(その他)へ回す。定義に足しただけで
-- 画面から黙って消えるのを防ぐため。
do
    local defs = {}
    local order = {}
    local sources = {MAIN_FRAME_SETTINGS, SUB_FRAME_SETTINGS.chats, SUB_FRAME_SETTINGS.chars, SUB_FRAME_SETTINGS.frames,
                     SUB_FRAME_SETTINGS.autos}
    for _, list in ipairs(sources) do
        for _, def in ipairs(list) do
            if not defs[def.name] then
                defs[def.name] = def
                order[#order + 1] = def.name
            end
        end
    end
    local placed = {}
    for _, section in ipairs(SETTING_SECTIONS) do
        section.items = {}
        for _, name in ipairs(section.names) do
            if defs[name] and not placed[name] then
                placed[name] = true
                section.items[#section.items + 1] = defs[name]
            end
        end
    end
    local last = SETTING_SECTIONS[#SETTING_SECTIONS].items
    for _, name in ipairs(order) do
        if not placed[name] then
            last[#last + 1] = defs[name]
        end
    end
end

-- 表示言語に合わせた文言を返す（定義側は text_jp / text_kr / text_en を持つ）
local function localized_text(def)
    if g.lang == "Japanese" then
        return def.text_jp
    elseif g.lang == "kr" then
        return def.text_kr
    end
    return def.text_en
end

-- 検索の一致判定。表示言語だけでなく他言語の文言と設定名も対象にする
-- （英語名で覚えている人が居るのと、日本語版で "auto" などと打てるようにするため）。
-- string.find は第 4 引数 true でプレーン検索にする。記号を打たれてもパターンとして
-- 解釈されて落ちないようにするため。
local function setting_matches(setting, needle)
    if needle == "" then
        return true
    end
    local haystack = string.lower(setting.name .. " " .. (setting.text_jp or "") .. " " .. (setting.text_kr or "") ..
                                      " " .. (setting.text_en or ""))
    return string.find(haystack, needle, 1, true) ~= nil
end

-- .use を持つ入れ子の設定。チェック状態の読み出し先がここだけ 1 段深い
local NESTED_USE_SETTINGS = {
    cupole_portion = true,
    baubas_call = true,
    velnice = true,
    auto_zoom = true,
    event_shout = true
}

-- 設定 1 行（チェックボックスと、項目によっては隣に付く操作 UI）を作る。
-- 統合前はメイン画面とサブ画面にほぼ同じ処理が二重にあったので、ここへ寄せた。
-- 戻り値は行の右端 x。フレーム幅の算出に使う。
local function create_setting_row(gbox, setting, y)
    local check_value
    if NESTED_USE_SETTINGS[setting.name] then
        check_value = g.settings[setting.name] and g.settings[setting.name].use or 0
    else
        check_value = g.settings[setting.name] or 0
    end
    local checkbox = gbox:CreateOrGetControl("checkbox", setting.name, 10, y, 25, 25)
    AUTO_CAST(checkbox)
    checkbox:SetCheck(check_value)
    checkbox:SetEventScript(ui.LBUTTONUP, "Mini_addons_ISCHECK")
    checkbox:SetText("{ol}" .. localized_text(setting))
    local tooltip_text = g.lang == "Japanese" and "{ol}チェックすると有効化" or g.lang == "kr" and
                             "{ol}체크 시 활성화" or "{ol}Check to enable"
    checkbox:SetTextTooltip(tooltip_text)
    local text_width = checkbox:GetWidth()
    local right = 10 + text_width
    if setting.name == "baubas_call" then -- チェックボックスの隣に特殊なUIを追加する処理
        local baubas_call_btn = gbox:CreateOrGetControl("button", "baubas_call_btn", right + 15, y - 5, 50, 30)
        AUTO_CAST(baubas_call_btn)
        if g.settings.baubas_call.guild_notice == 0 or not g.settings.baubas_call.guild_notice then
            baubas_call_btn:SetText("{ol}{#FFFFFF}OFF")
            baubas_call_btn:SetSkinName("test_gray_button")
            -- 保存は「値がまだ無い」ときだけ。一覧は検索や折りたたみのたびに作り直されるので、
            -- 既に 0 のときも保存すると、何も変わっていないのに settings.json を書き続ける
            if not g.settings.baubas_call.guild_notice then
                g.settings.baubas_call.guild_notice = 0
                Mini_addons_save_settings()
            end
        else
            baubas_call_btn:SetText("{ol}{#FFFFFF}ON")
            baubas_call_btn:SetSkinName("test_red_button")
        end
        local btn_tooltip = g.lang == "Japanese" and "{ol}ギルドチャットへのお知らせ切替え" or g.lang == "kr" and
                                "{ol}길드 채팅으로 알림 전환" or "{ol}Notification switch to guild chat"
        baubas_call_btn:SetTextTooltip(btn_tooltip)
        baubas_call_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_baubas_call_switch")
        right = right + 15 + baubas_call_btn:GetWidth()
    elseif setting.name == "other_effect" or setting.name == "my_effect" or setting.name == "boss_effect" then
        local edit_name = setting.name .. "_edit"
        local edit_ctrl = gbox:CreateOrGetControl("edit", edit_name, right + 15, y, 60, 25)
        AUTO_CAST(edit_ctrl)
        local event_name = "Mini_addons_" .. string.upper(setting.name) .. "_EDIT"
        edit_ctrl:SetEventScript(ui.ENTERKEY, event_name)
        edit_ctrl:SetTextTooltip("{ol}1~100")
        edit_ctrl:SetFontName("white_16_ol")
        edit_ctrl:SetTextAlign("center", "center")
        local transparency_value
        if setting.name == "other_effect" then
            transparency_value = config.GetOtherEffectTransparency()
        elseif setting.name == "my_effect" then
            transparency_value = config.GetMyEffectTransparency()
        elseif setting.name == "boss_effect" then
            transparency_value = config.GetBossMonsterEffectTransparency()
        end
        local num_value = math.floor(transparency_value * 0.392156862745 + 0.5)
        edit_ctrl:SetText("{ol}" .. num_value)
        right = right + 15 + 60
    elseif setting.name == "auto_gacha" then
        local auto_gacha_btn = gbox:CreateOrGetControl("button", "auto_gacha_btn", right + 15, y - 5, 50, 30)
        AUTO_CAST(auto_gacha_btn)
        if g.settings.auto_gacha_start == 0 then
            auto_gacha_btn:SetText("{ol}{#FFFFFF}OFF")
            auto_gacha_btn:SetSkinName("test_gray_button")
        else
            auto_gacha_btn:SetText("{ol}{#FFFFFF}ON")
            auto_gacha_btn:SetSkinName("test_red_button")
        end
        local btn_tooltip = g.lang == "Japanese" and "{ol}ONにすると自動でガチャスタートします" or
                                g.lang == "kr" and "{ol}ON으로 설정하면 자동으로 가챠가 시작됩니다" or
                                "{ol}When turned on, the gacha starts automatically"
        auto_gacha_btn:SetTextTooltip(btn_tooltip)
        auto_gacha_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_GP_AUTOSTART_OPERATION")
        right = right + 15 + 50
    elseif setting.name == "weekly_boss_reward" then
        if not g.settings.reward_switch then
            g.settings.reward_switch = 1
            Mini_addons_save_settings()
        end
        local switch_btn = gbox:CreateOrGetControl("button", "switch", right + 15, y, 80, 25)
        AUTO_CAST(switch_btn)
        if g.settings.reward_switch == 1 then
            switch_btn:SetText(g.lang == "Japanese" and "{ol}先週分" or g.lang == "kr" and "{ol}지난 주분" or
                                   "{ol}last week")
        else
            switch_btn:SetText(g.lang == "Japanese" and "{ol}今週分" or g.lang == "kr" and "{ol}이번 주분" or
                                   "{ol}this week")
        end
        switch_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_WEEKLY_BOSS_REWARD_SWITCH")
        local btn_tooltip = g.lang == "Japanese" and "{ol}ダメージ報酬受取り週切替" or g.lang == "kr" and
                                "{ol}데미지 보상 수령 주차 변경" or "{ol}Switch Damage Reward Receipt Week"
        switch_btn:SetTextTooltip(btn_tooltip)
        right = right + 15 + 80
    elseif setting.name == "party_buff" then
        local party_buff_btn = gbox:CreateOrGetControl("button", "party_buff_btn", right + 15, y - 5, 80, 30)
        AUTO_CAST(party_buff_btn)
        party_buff_btn:SetText("{ol}{#FFFFFF}bufflist")
        local btn_tooltip = g.lang == "Japanese" and "表示するバフを選択できます" or g.lang == "kr" and
                                "표시할 버프를 선택할 수 있습니다" or "You can choose which buffs to display"
        party_buff_btn:SetTextTooltip(btn_tooltip)
        party_buff_btn:SetSkinName("test_red_button")
        party_buff_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_buff_list_open")
        right = right + 15 + 80
    elseif setting.name == "auto_zoom" then
        local edit_ctrl = gbox:CreateOrGetControl("edit", "auto_zoom_edit", right + 15, y, 60, 25)
        AUTO_CAST(edit_ctrl)
        edit_ctrl:SetEventScript(ui.ENTERKEY, "Mini_addons_autozoom_edit")
        edit_ctrl:SetTextTooltip("{ol}1~700 Default 336")
        edit_ctrl:SetFontName("white_16_ol")
        edit_ctrl:SetTextAlign("center", "center")
        edit_ctrl:SetText("{ol}" .. g.settings.auto_zoom.zoom)
        right = right + 15 + 60
    elseif setting.name == "event_shout" then
        local event_shout_btn = gbox:CreateOrGetControl("button", "event_shout_btn", right + 15, y - 5, 50, 30)
        AUTO_CAST(event_shout_btn)
        if g.settings.event_shout.guild_notice == 0 or not g.settings.event_shout.guild_notice then
            event_shout_btn:SetText("{ol}{#FFFFFF}OFF")
            event_shout_btn:SetSkinName("test_gray_button")
            -- baubas_call と同じ理由で、保存は値がまだ無いときだけ
            if not g.settings.event_shout.guild_notice then
                g.settings.event_shout.guild_notice = 0
                Mini_addons_save_settings()
            end
        else
            event_shout_btn:SetText("{ol}{#FFFFFF}ON")
            event_shout_btn:SetSkinName("test_red_button")
        end
        local btn_tooltip = g.lang == "Japanese" and "{ol}ギルドチャットへのお知らせ切替え" or g.lang == "kr" and
                                "{ol}길드 채팅으로 알림 전환" or "{ol}Notification switch to guild chat"
        event_shout_btn:SetTextTooltip(btn_tooltip)
        event_shout_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_event_shout_switch")
        right = right + 15 + event_shout_btn:GetWidth()
    end
    return right
end

-- 一覧の中身を作り直す。検索のたびに呼ばれるので、フレーム側の枠(タイトル・検索窓・✕)は
-- 触らず gbox の中だけを組み直す。filter_text が空なら全件。
function Mini_addons_setting_build(setting, filter_text, keep_pos)
    local needle = string.lower(filter_text or "")
    local gbox = setting:CreateOrGetControl("groupbox", "gbox", 10, 80, 0, 0)
    AUTO_CAST(gbox)
    gbox:SetSkinName("bg")
    -- 折りたたみの開閉でも作り直すので、スクロール位置を引き継げるなら引き継ぐ。
    -- GetScrollPos があるかはクライアント側の実装次第なので pcall で試すだけにする
    -- (取れなくても先頭に戻るだけで、機能は壊れない)。RemoveAllChild より前に読むこと。
    local prev_scroll = 0
    if keep_pos then
        local ok, pos = pcall(function()
            return gbox:GetScrollPos()
        end)
        if ok and type(pos) == "number" then
            prev_scroll = pos
        end
    end
    gbox:RemoveAllChild()
    g.settings.section_collapsed = g.settings.section_collapsed or {}
    local y = 10
    local x = 0
    local hit = 0
    -- セクションごとに枠(groupbox)を作り、その中に項目を入れて束ねる。
    -- 枠の幅は全項目を作り終えるまで決まらないので、ここでは高さだけ決めて
    -- 参照を溜めておき、最後にまとめて同じ幅へ揃える。
    local section_boxes = {}
    for _, section in ipairs(SETTING_SECTIONS) do
        local matched = {}
        for _, item in ipairs(section.items) do
            if setting_matches(item, needle) then
                matched[#matched + 1] = item
            end
        end
        if #matched > 0 then
            -- 検索中は折りたたみを無視して開く。絞り込んだ結果が畳まれた中に隠れていると
            -- 「ヒットしたのに何も出ない」ように見えるため。
            -- あわせて検索中は開閉そのものを受け付けない。押しても見た目が変わらないのに
            -- 保存だけ進み、検索を消した瞬間に畳まれている、という分かりにくい挙動になるため
            local searching = needle ~= ""
            local collapsed = not searching and g.settings.section_collapsed[section.name] == 1
            -- 開閉マークは幅を固定した別コントロールに分ける。見出しの文字列に
            -- "[+] " / "[-] " を含めると、+ と - の字幅の差だけ見出しが左右にズレる
            local marker = gbox:CreateOrGetControl("button", "section_mark_" .. section.name, 12, y, 20, 26)
            AUTO_CAST(marker)
            marker:SetSkinName("None")
            marker:SetTextAlign("center", "center")
            marker:SetText(searching and "" or ("{ol}{s18}{#FFCC33}" .. (collapsed and "+" or "-")))
            -- 見出しはクリックで開閉できるよう button にする（枠なしなので見た目は文字のまま）。
            -- 暗い背景に埋もれないよう縁取り付きの黄色
            -- ({@st66b18} は黒に近く、項目の文字と見分けが付かなかった)
            local header = gbox:CreateOrGetControl("button", "section_" .. section.name, 34, y, 0, 26)
            AUTO_CAST(header)
            header:SetSkinName("None")
            header:SetTextAlign("left", "center")
            header:SetText("{ol}{s18}{#FFCC33}" .. localized_text(section))
            if searching then
                header:SetTextTooltip(g.lang == "Japanese" and "{ol}検索中は折りたたみできません" or
                                          g.lang == "kr" and "{ol}검색 중에는 접을 수 없습니다" or
                                          "{ol}Cannot collapse while filtering")
            else
                for _, btn in ipairs({marker, header}) do
                    btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_section_toggle")
                    btn:SetEventScriptArgString(ui.LBUTTONUP, section.name)
                    btn:SetTextTooltip(g.lang == "Japanese" and "{ol}クリックで折りたたみ" or g.lang == "kr" and
                                           "{ol}클릭하면 접기/펼치기" or "{ol}Click to collapse or expand")
                end
            end
            if x < 34 + header:GetWidth() then
                x = 34 + header:GetWidth()
            end
            y = y + 26
            if collapsed then
                y = y + 8
            else
                local box = gbox:CreateOrGetControl("groupbox", "sec_box_" .. section.name, 10, y, 100, 100)
                AUTO_CAST(box)
                box:SetSkinName("test_frame_midle_light")
                box:EnableScrollBar(0)
                box:RemoveAllChild()
                local by = 8
                for _, item in ipairs(matched) do
                    local right = create_setting_row(box, item, by)
                    if x < right + 10 then -- 枠の左端(10)ぶんを足して gbox 内の座標に直す
                        x = right + 10
                    end
                    by = by + 30
                end
                local box_height = by + 4
                box:Resize(box:GetWidth(), box_height)
                section_boxes[#section_boxes + 1] = box
                y = y + box_height + 14
            end
            hit = hit + #matched
        end
    end
    if hit == 0 then
        local empty = gbox:CreateOrGetControl("richtext", "empty", 10, y)
        AUTO_CAST(empty)
        empty:SetText(g.lang == "Japanese" and "{ol}{#FFA500}該当する設定はありません" or g.lang == "kr" and
                          "{ol}{#FFA500}해당하는 설정이 없습니다" or "{ol}{#FFA500}No matching settings")
        if x < 10 + empty:GetWidth() then
            x = 10 + empty:GetWidth()
        end
        y = y + 30
    end
    local description = gbox:CreateOrGetControl("richtext", "description", 10, y + 5)
    AUTO_CAST(description)
    local temp_text = g.lang == "Japanese" and
                          "{ol}{#FFA500}※一部機能の有効/無効の切替はキャラクターチェンジが必要です" or
                          g.lang == "kr" and
                          "{ol}{#FFA500}※일부 기능의 활성화/비활성화 전환은 캐릭터 변경이 필요합니다" or
                          "{ol}{#FFA500}※Character change is required to enable or disable some functions"
    description:SetText(temp_text)
    if x < 10 + description:GetWidth() then
        x = 10 + description:GetWidth()
    end
    y = y + 40
    -- スクロールバーの分(25)を足す。足さないと右端の文字がバーに隠れる
    local width = x + 25 + 30
    if width < 460 then -- タイトルと検索窓が収まる最低幅
        width = 460
    end
    -- セクションの枠を最終的な幅へ揃える(高さは各枠が既に持っている)。
    -- width から左右の余白(gbox の 10 + 枠の 10 = 計 30)とスクロールバー(25)を引いた分
    local box_width = width - 30 - 25
    for _, box in ipairs(section_boxes) do
        box:Resize(box_width, box:GetHeight())
    end
    local screen_width = ui.GetClientInitialWidth()
    local screen_height = ui.GetClientInitialHeight()
    -- 全件だと画面に収まらない高さになるので、画面の 8 割で頭打ちにしてスクロールさせる
    local max_height = math.floor(screen_height * 0.8)
    local height = y + 95
    if height > max_height then
        height = max_height
    end
    local prev_x, prev_y = setting:GetX(), setting:GetY()
    setting:Resize(width, height)
    gbox:Resize(setting:GetWidth() - 20, setting:GetHeight() - 90)
    gbox:EnableScrollBar(1)
    -- 畳んで中身が縮んだときに、縮む前の位置をそのまま戻すと末尾より下へ飛ぶ。
    -- 新しい中身の高さ(y)と表示領域の差を上限にする
    local scroll_max = y - gbox:GetHeight()
    if scroll_max < 0 then
        scroll_max = 0
    end
    if prev_scroll > scroll_max then
        prev_scroll = scroll_max
    end
    -- GetScrollPos と同じ理由で、SetScrollPos も無い可能性を見て pcall で呼ぶ。
    -- 片方だけ素で呼ぶと、無かったときにここで一覧の構築ごと落ちる
    pcall(function()
        gbox:SetScrollPos(prev_scroll)
    end)
    if keep_pos then
        -- 展開やフィルタ解除で背が伸びると、元の左上のままでは画面外へはみ出す。
        -- この窓はタイトルバーが無く掴み直しづらいので、画面内へ押し戻しておく
        local max_x = screen_width - setting:GetWidth()
        local max_y = screen_height - setting:GetHeight()
        if prev_x > max_x then
            prev_x = max_x
        end
        if prev_y > max_y then
            prev_y = max_y
        end
        if prev_x < 0 then
            prev_x = 0
        end
        if prev_y < 0 then
            prev_y = 0
        end
        setting:SetPos(prev_x, prev_y)
    else
        setting:SetPos((screen_width - setting:GetWidth()) / 2, (screen_height - setting:GetHeight()) / 2)
    end
    -- 実際にこの一覧を作ったときの絞り込み。折りたたみの可否は検索窓の「今の文字」ではなく
    -- こちらで判定する(未確定の入力で見出しが無反応になるのを防ぐ)
    g.setting_applied_filter = filter_text or ""
    core_g.vlog("mini_addons: 設定画面を構築 filter=" .. tostring(filter_text or "") .. " hit=" .. hit)
end

-- セクション見出しのクリック。その配下の枠を畳む / 開く。
-- 状態は settings に持たせて、開き直しても保つ
function Mini_addons_section_toggle(frame, ctrl, section_name, num)
    local setting = ui.GetFrame(addon_name_lower .. "setting")
    if not setting or not section_name then
        return
    end
    -- 見るのは検索窓の「今の文字」ではなく、今表示されている一覧を作ったときの絞り込み。
    -- 打っただけで確定していない文字で弾くと、全件表示のまま見出しを押しても
    -- 何の反応も無い(押せない理由も出ない)状態になる
    local filter_text = g.setting_applied_filter or ""
    -- 検索中は畳めない(理由は Mini_addons_setting_build 側のコメント)。
    -- 検索中の見出しにはそもそもこの関数を繋いでいないが、押せてしまったときの保険
    if filter_text ~= "" then
        return
    end
    g.settings.section_collapsed = g.settings.section_collapsed or {}
    if g.settings.section_collapsed[section_name] == 1 then
        g.settings.section_collapsed[section_name] = 0
    else
        g.settings.section_collapsed[section_name] = 1
    end
    Mini_addons_save_settings()
    core_g.vlog("mini_addons: セクション開閉 " .. section_name .. " collapsed=" ..
                    tostring(g.settings.section_collapsed[section_name]))
    Mini_addons_setting_build(setting, filter_text, true)
end

-- 検索窓の入口。ENTERKEY と虫眼鏡ボタンの両方から来る
function Mini_addons_setting_search(frame, ctrl, str, num)
    local setting = ui.GetFrame(addon_name_lower .. "setting")
    if not setting then
        return
    end
    local search_edit = GET_CHILD_RECURSIVELY(setting, "search_edit")
    Mini_addons_setting_build(setting, search_edit and search_edit:GetText() or "", true)
end

function Mini_addons_SETTING_FRAME_INIT(frame_arg, ctrl_arg, str_arg, num_arg)
    -- 機能 OFF のときは Mini_addons_ON_INIT が走らず g.settings がまだ無い。一覧の歯車は
    -- ON/OFF によらず押せる(core/20_lifecycle.lua が frame_use だけを見て付ける)ので、
    -- ここで受け止めないと下の g.settings.velnice.use で落ち、空のフレームだけが残る。
    -- 既定が use=0 なので、新規導入直後に歯車を押すと必ず踏んでいた。
    -- g.lang も ON_INIT で入るため、案内はまとめ版の言語設定で出す。
    if not g.settings then
        local msg = core_g.lang == "Japanese" and
                        "{ol}[Mini Addons] まだ有効になっていません。一覧の ON/OFF を ON にしてから開いてください" or
                        "{ol}[Mini Addons] Not enabled yet. Turn it ON in the list first"
        ui.SysMsg(msg)
        core_g.vlog("mini_addons: 設定画面を開こうとしたが未初期化(use=0)")
        return
    end
    local setting = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "setting", 0, 0, 10, 10)
    AUTO_CAST(setting)
    if setting:GetWidth() > 100 and str_arg == "false" then
        setting:Resize(0, 0)
        setting:ShowWindow(0)
        return
    end
    setting:SetSkinName("test_frame_low")
    setting:SetLayerLevel(93)
    setting:EnableHittestFrame(1)
    -- 上流は EnableMove を呼んでおらず動かせなかったので P 側で足した
    -- (位置の保存はしないため、開き直すと既定位置に戻る)
    setting:EnableMove(1)
    setting:ShowTitleBar(0)
    setting:RemoveAllChild()
    setting:SetEventScript(ui.RBUTTONUP, "Mini_addons_FRAME_CLOSE")
    local title = setting:CreateOrGetControl("richtext", "title", 30, 10)
    AUTO_CAST(title)
    title:SetText("{@st66b18}Mini Addons")
    local close = setting:CreateOrGetControl("button", "close", 0, 5, 30, 30)
    AUTO_CAST(close)
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetImage("testclose_button")
    close:SetEventScript(ui.LBUTTONUP, "Mini_addons_FRAME_CLOSE")
    -- 検索窓。ここだけは検索のたびに作り直さない(消えると打ち直しになる)ので、
    -- 一覧の中身だけを組み立てる Mini_addons_setting_build と分けてある。
    local search_edit = setting:CreateOrGetControl("edit", "search_edit", 15, 42, 300, 32)
    AUTO_CAST(search_edit)
    search_edit:SetFontName("white_16_ol")
    search_edit:SetTextAlign("left", "center")
    search_edit:SetSkinName("inventory_serch")
    search_edit:SetEventScript(ui.ENTERKEY, "Mini_addons_setting_search")
    search_edit:SetTextTooltip(g.lang == "Japanese" and "{ol}設定名や説明で絞り込み(空で全件)" or g.lang == "kr" and
                                   "{ol}설정 이름으로 검색(비우면 전체)" or
                                   "{ol}Filter settings by text (empty shows all)")
    local search_btn = search_edit:CreateOrGetControl("button", "search_btn", 0, 0, 32, 32)
    AUTO_CAST(search_btn)
    search_btn:SetImage("inven_s")
    search_btn:SetGravity(ui.RIGHT, ui.TOP)
    search_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_setting_search")
    Mini_addons_setting_build(setting, "", false)
    setting:ShowWindow(1)
    core_g.esc_register(addon_name_lower .. "setting", "Mini_addons_setting_ESCAPE_PRESSED")
end

-- ESC 用の入口。esc_register の close_func は引数無しで呼ばれるが、
-- Mini_addons_FRAME_CLOSE は ✕ ボタン経由でフレームを受け取る前提で
-- setting:GetName() を呼ぶため、ここで拾って渡さないと落ちる。
function Mini_addons_setting_ESCAPE_PRESSED()
    local setting = ui.GetFrame(addon_name_lower .. "setting")
    if setting then
        Mini_addons_FRAME_CLOSE(setting)
    end
end

function Mini_addons_FRAME_CLOSE(setting)
    ui.DestroyFrame(setting:GetName())
end

function Mini_addons_ISCHECK(frame, ctrl, argStr, argNum)
    local is_checked = ctrl:IsChecked()
    local ctrl_name = ctrl:GetName()
    for _, setting_name in ipairs(SETTINGS_NAME) do
        if ctrl_name == setting_name then
            if setting_name == "cupole_portion" or setting_name == "velnice" or setting_name == "baubas_call" or
                setting_name == "auto_zoom" or setting_name == "event_shout" then
                g.settings[setting_name] = g.settings[setting_name] or {}
                g.settings[setting_name].use = is_checked
            else
                g.settings[setting_name] = is_checked
            end
            if setting_name == "bgm" then -- 特定の機能に対する即時処理
                if is_checked == 0 then
                    local max_frame = ui.GetFrame("bgmplayer")
                    local play_btn = GET_CHILD_RECURSIVELY(max_frame, "playStart_btn")
                    BGMPLAYER_PLAY(max_frame, play_btn)
                end
            elseif setting_name == "daily_quest" then
                local q7quest = ui.GetFrame((addon_name_lower .. "_q7quest"))
                if is_checked == 0 then
                    if q7quest then
                        ui.DestroyFrame((addon_name_lower .. "_q7quest"))
                    end
                else
                    if q7quest then
                        ui.DestroyFrame((addon_name_lower .. "_q7quest"))
                    end
                    Mini_addons_quest_update()
                end
            elseif setting_name == "inventory_mod" then
                local inventory = ui.GetFrame("inventory")
                local tab = GET_CHILD_RECURSIVELY(inventory, "inventype_Tab")
                tab:SelectTab(0)
                local tab_index = tab:GetSelectItemIndex()
                inventory:SetUserValue("TRY", 0)
                g.inven_tbl = {}
                Mini_addons_INVENTORY_OPEN_logic(inventory)
            elseif setting_name == "chat_new_btn" then
                Mini_addons_update_chat_frame()
            end
            break
        end
    end
    Mini_addons_save_settings()
end

-- 経過時間の物差し。imcTime が無い環境でも落ちないよう pcall で包み、取れなければ
-- 0 を返す(その場合は計測値が全部 0 になるだけで、本体の処理には影響しない)。
local function now_ms()
    local ok, ms = pcall(function()
        return imcTime.GetAppTimeMS()
    end)
    if ok and type(ms) == "number" then
        return ms
    end
    return 0
end

-- テーブルのキー数。**計測ログの判断材料にしか使わない。** 所要時間だけ出しても
-- 「そのファイルがどれだけ大きかったか」が分からず、他の環境のログと比べられない。
local function count_keys(tbl)
    if type(tbl) ~= "table" then
        return -1
    end
    local n = 0
    for _ in pairs(tbl) do
        n = n + 1
    end
    return n
end

-- 初回ログインで mini_addons の on_init だけが 5813ms 掛かる(他 49 本は最大 63ms)
-- 事象の切り分け用。**読み込みと書き戻しを分けて出すこと。** 合計だけだと
-- 「json.decode が重いのか、書き戻し(encode + tmp 書き + rename)が重いのか」が
-- 区別できず、直す先を選べない。
-- 走るのはセッション中 1 回だけ(呼び元が if not g.settings で囲っている)なので、
-- 毎フレーム流れる心配はない(CLAUDE.md「出しすぎない」)。
function Mini_addons_load_settings()
    local t0 = now_ms()
    local settings = g.load_json(g.settings_path)
    local t_load = now_ms()
    if not settings then
        settings = DEFAULT_SETTINGS
    else
        for key, value in pairs(DEFAULT_SETTINGS) do
            if settings[key] == nil then
                settings[key] = value
            end
        end
    end
    g.settings = settings
    local t_merge = now_ms()
    Mini_addons_save_settings()
    local t_save = now_ms()
    core_g.vlog("mini_addons: 計測 load_settings 読込=%dms 既定補完=%dms 書戻=%dms キー=%d", t_load - t0,
        t_merge - t_load, t_save - t_merge, count_keys(g.settings))
end

function Mini_addons_save_settings()
    g.save_json(g.settings_path, g.settings)
end

-- バフ一覧の保存。**必ずここを通すこと**(g.save_json を直接呼ばない)。
-- 保存先が .lua なのは g.update_paths のコメントを参照。書き込み側が 1 箇所でも
-- json のまま残ると、次の読み込みが .lua を見つけられずに旧 json へ落ちて、
-- せっかく直した 5 秒がそのまま戻る。
function Mini_addons_save_buffs()
    g.save_lua(g.buffs_path, g.buffs)
end

-- 計測はそのまま残す。**これが無いと同じ不具合を二度追うことになる**
-- (5 秒フリーズの切り分けで、この行が無いせいで「ON_INIT のどこか」までしか
--  絞れなかった)。走るのはセッション中 1 回だけ。
function Mini_addons_load_buffs()
    local t0 = now_ms()
    local buffs = g.load_lua(g.buffs_path)
    local lua_ok = buffs ~= nil
    local migrated = false
    if not buffs then
        -- 旧 json からの移行。**変換は 1 回だけで、この回だけは従来どおり遅い**
        -- (2806 キーで約 5 秒)。避けるには生の JSON を自前で舐めることになり、
        -- 割に合わないので受け入れる。次回以降は .lua だけを読む。
        -- 本家個別版から引き継いだ人も、初回はここを通る。
        buffs = g.load_json(g.buffs_json_path)
        migrated = buffs ~= nil
    end
    local t_load = now_ms()
    if not buffs then
        buffs = {}
    end
    g.buffs = buffs
    -- 書き戻すのは .lua がまだ無いときだけ(移行の回と、まっさらな初回)。
    -- .lua を読めたときは読んだ内容と同じものを書くだけなので省く。
    if not lua_ok then
        Mini_addons_save_buffs()
    end
    local t_save = now_ms()
    -- 変換できたら旧 json は消す。**残すと恒久的な「古い代替」になる**。
    -- .lua の読み込みが一度でも失敗した回に変換当日の内容へ巻き戻り、それをそのまま
    -- .lua へ書き戻すので、以降のバフ設定の変更が黙って消える。
    -- 消す前に .lua が本当に出来ているかを確かめること(書けていない状態で消すと全部失う)。
    if migrated then
        local written = io.open(g.buffs_path, "rb")
        if written then
            written:close()
            local removed = os.remove(g.buffs_json_path)
            core_g.vlog("mini_addons: バフ一覧を .lua へ変換したので旧 json を%s (%s)",
                removed and "削除した" or "{#FF6347}削除できなかった{/}", tostring(g.buffs_json_path))
        else
            core_g.vlog("{#FF6347}mini_addons: バフ一覧の .lua を書き出せていないので旧 json は残す{/} (%s)",
                tostring(g.buffs_path))
        end
    end
    core_g.vlog("mini_addons: 計測 load_buffs 読込=%dms 書戻=%dms キー=%d 旧json移行=%s", t_load - t0,
        t_save - t_load, count_keys(g.buffs), tostring(migrated))
end

function Mini_addons_ON_INIT(addon, frame)
    g.addon = addon
    g.frame = frame
    -- 設定を読む前に保存先を確定させる(AID はここで初めて確実に取れる)
    g.update_paths()
    -- ここから下の内訳を計測する。**この 4 ステップの間に vlog が 1 行も無かったため、
    -- 「6 秒がこの範囲のどこか」までしか絞れなかった**(実機ログ 21:47:26 -> 21:47:32)。
    -- 個々の所要は load_settings / load_buffs 側でも出しているので、ここは
    -- 「どのステップが支配的か」を 1 行で見るための合計。
    local t0 = now_ms()
    g.cid = info.GetCID(session.GetMyHandle())
    g.lang = option.GetCurrentCountry()
    g.load_time = os.clock()
    g.last_inventory_open_time = 0
    local t_session = now_ms()
    if not g.settings then
        Mini_addons_load_settings()
    end
    local t_settings = now_ms()
    if not g.buffs then -- PTバフの準備
        Mini_addons_load_buffs()
    end
    local t_buffs = now_ms()
    g.setup_hook(Mini_addons_CHAT_SYSTEM, "CHAT_SYSTEM")
    -- スキル連打音消す
    g.setup_hook(Mini_addons_ICON_USE, "ICON_USE")
    local t_hooks = now_ms()
    core_g.vlog("mini_addons: 計測 ON_INIT session=%dms settings=%dms buffs=%dms hooks=%dms 合計=%dms",
        t_session - t0, t_settings - t_session, t_buffs - t_settings, t_hooks - t_buffs, t_hooks - t0)
    core_g.register_msg("GAME_START", "Mini_addons_GAME_START")
    core_g.register_msg("GAME_START_3SEC", "Mini_addons_GAME_START_3SEC")
end

function Mini_addons_GAME_START(frame, msg, str, num)
    -- マップ移動直後はフレームがまだ無いので g.get_frame を通す(理由はそちらのコメント)
    local mini_addons = g.get_frame()
    mini_addons:RunUpdateScript("Mini_addons_runupdate_5", 0.5)
    -- AUTOMAPCHANGEに付けていたオートズーム機能を殺す
    if _G["AUTOMAPCHANGE_CAMERA_ZOOM"] and type(_G["AUTOMAPCHANGE_CAMERA_ZOOM"]) == "function" then
        _G["AUTOMAPCHANGE_CAMERA_ZOOM"] = nil
    end
    core_g.register_msg("FPS_UPDATE", "Mini_addons_FPS_UPDATE")
    -- クエストインフォを隠す
    Mini_addons_ON_UPDATE_QUESTINFOSET_2(nil)
    g.setup_hook(Mini_addons_ON_UPDATE_QUESTINFOSET_2, "ON_UPDATE_QUESTINFOSET_2")
    -- ブラックマーケット削除
    g.setup_hook(Mini_addons_NOTICE_ON_MSG, "NOTICE_ON_MSG")
    g.setup_hook(Mini_addons_CHAT_TEXT_LINKCHAR_FONTSET, "CHAT_TEXT_LINKCHAR_FONTSET")
    -- ダイアログ制御系
    core_g.register_msg("DIALOG_CHANGE_SELECT", "Mini_addons_DIALOG_CHANGE_SELECT")
    -- 最初回のイベントバナーのレイヤー下げる
    core_g.register_msg("DO_OPEN_EVENTBANNER_UI", "Mini_addons_event_banner_layer")
    core_g.register_msg("EVENTBANNER_SOLODUNGEON", "Mini_addons_event_banner_layer")
    -- 追加報酬券チェック
    core_g.register_msg("REQ_PLAYER_CONTENTS_RECORD", "Mini_addons_REQ_PLAYER_CONTENTS_RECORD")
    -- お使いクエストフレーム
    core_g.register_msg("QUEST_UPDATE", "Mini_addons_quest_update")
    core_g.register_msg("QUEST_UPDATE_", "Mini_addons_quest_update")
    core_g.register_msg("GET_NEW_QUEST", "Mini_addons_quest_update")
    Mini_addons_quest_update()
    -- クポルポーションフレームの移動と非表示。
    -- cupole 系は別配布のアドオンなので、入れていない利用者では nil になる。
    -- ここで落ちると呼び出し元(補完実行)の残りが走らないため、必ず nil を見る。
    local cupole_external_addon = ui.GetFrame("cupole_external_addon")
    if cupole_external_addon then
        cupole_external_addon:SetEventScript(ui.LBUTTONUP, "Mini_addons_cupole_portion_frame_save")
    else
        core_g.vlog("mini_addons: cupole_external_addon が無いので飛ばす")
    end
end

function Mini_addons_GAME_START_3SEC(frame, msg, str, num)
    core_g.vlog("mini_addons: GAME_START_3SEC 開始")
    -- EP13ショップを街で開ける
    Mini_addons_REPUTATION_SHOP_OPEN()
    -- 町でBGMPLAYERを常に動かす
    Mini_addons_BGM_PLAY()
    -- 小さいボタンをレイドで非表示
    Mini_addons_MINIMIZED_CLOSE()
    -- ボタン右クリックでサウンドオフ
    Mini_addons_toggle_sound_set()
    -- 自分のエフェクト設定を戻すIMCのバグ修正
    Mini_addons_MY_EFFECT_SETTING()
    -- ボスのエフェクト設定を戻すIMCのバグ修正
    Mini_addons_BOSS_EFFECT_SETTING()
    -- その他のエフェクト設定を戻すIMCのバグ修正
    Mini_addons_OTHER_EFFECT_SETTING()
    -- パーティーメンバーの場所表示
    Mini_addons_partymember_get_map()
    -- ヴァカリネを伝える
    Mini_addons_vakarine_notice()
    -- チャンネル切替フレーム
    Mini_addons_GAME_START_CHANNEL_LIST()
    -- イベントグローバルシャウトをチャットに残す
    Mini_addons_event_frame()
    core_g.register_msg("NOTICE_Dm_Global_Shout", "Mini_addons_event_NOTICE_ON_MSG")
    core_g.register_msg("INV_ITEM_ADD", "Mini_addons_event_frame")
    core_g.register_msg("INV_ITEM_REMOVE", "Mini_addons_event_frame")
    -- バウバスお知らせ
    g.setup_hook_and_event(g.addon, "NOTICE_ON_MSG", "Mini_addons_NOTICE_ON_MSG_baubas", true)
    -- どこでもメンバーインフォ
    g.setup_hook(Mini_addons_CHAT_RBTN_POPUP, "CHAT_RBTN_POPUP")
    g.setup_hook(Mini_addons_POPUP_GUILD_MEMBER, "POPUP_GUILD_MEMBER")
    g.setup_hook(Mini_addons_CONTEXT_PARTY, "CONTEXT_PARTY")
    g.setup_hook(Mini_addons_SHOW_PC_CONTEXT_MENU, "SHOW_PC_CONTEXT_MENU")
    -- POPUP_DUMMY(露店キャラ)は素のままでよいので掛けない。以前は素を書き写して
    -- 「見比べる」を memberinfo が ON のときだけ出しており、既定の OFF で消えていた
    g.setup_hook(Mini_addons_POPUP_FRIEND_COMPLETE_CTRLSET, "POPUP_FRIEND_COMPLETE_CTRLSET")
    -- コインショップの数値を拡張
    g.setup_hook(Mini_addons_EARTHTOWERSHOP_CHANGECOUNT_NUM_CHANGE, "EARTHTOWERSHOP_CHANGECOUNT_NUM_CHANGE")
    -- 4人以下の入場確認スキップ
    g.setup_hook(Mini_addons_INDUNENTER_REQ_UNDERSTAFF_ENTER_ALLOW, "INDUNENTER_REQ_UNDERSTAFF_ENTER_ALLOW")
    -- ヴェルニケ階数を覚える
    g.setup_hook(Mini_addons_INDUN_EDITMSGBOX_FRAME_OPEN, "INDUN_EDITMSGBOX_FRAME_OPEN")
    core_g.register_msg("SOLO_D_TIMER_TEXT_GAUGE_UPDATE", "Mini_addons_SOLO_D_TIMER_UPDATE_TEXT_GAUGE")
    -- PTバフの表示非表示切り替え
    g.setup_hook(Mini_addons_ON_PARTYINFO_BUFFLIST_UPDATE, "ON_PARTYINFO_BUFFLIST_UPDATE")
    -- チャンネルのズレを直す
    g.setup_hook(Mini_addons_UPDATE_CURRENT_CHANNEL_TRAFFIC, "UPDATE_CURRENT_CHANNEL_TRAFFIC")
    -- インベントリイコル検索
    g.setup_hook(Mini_addons_INVENTORY_TOTAL_LIST_GET, "INVENTORY_TOTAL_LIST_GET")
    -- コロニー死んだ時に30秒タイマー動かないバグ修正
    g.setup_hook(Mini_addons_RESTART_ON_MSG, "RESTART_ON_MSG")
    -- 決闘の申し込みを自動で受ける(設定 auto_accept_duel。OFF なら元の確認ダイアログのまま)
    g.setup_hook(Mini_addons_ASKED_FRIENDLY_FIGHT, "ASKED_FRIENDLY_FIGHT")
    g.setup_hook(Mini_addons_ASKED_ANCIENT_FRIENDLY_FIGHT, "ASKED_ANCIENT_FRIENDLY_FIGHT")
    -- 装備錬成を自動化
    g.setup_hook(Mini_addons_COMMON_EQUIP_UPGRADE_PROGRESS, "COMMON_EQUIP_UPGRADE_PROGRESS")
    g.setup_hook_and_event(g.addon, "COMMON_EQUIP_UPGRADE_OPEN", "Mini_addons_COMMON_EQUIP_UPGRADE_OPEN", true)
    -- パーティー情報フレームを小さくする
    core_g.register_msg("PARTY_BUFFLIST_UPDATE", "Mini_addons_PARTY_BUFFLIST_UPDATE")
    -- インベントリを改造
    core_g.register_msg("INV_ITEM_ADD", "Mini_addons_inventory_open_func")
    core_g.register_msg("INV_ITEM_REMOVE", "Mini_addons_inventory_open_func")
    g.setup_hook_and_event(g.addon, "INVENTORY_OPEN", "Mini_addons_INVENTORY_OPEN", true)
    -- ファミリーネームからログインネームへ変換
    core_g.register_msg("BUFF_ADD", "Mini_addons_PCNAME_REPLACE")
    core_g.register_msg("BUFF_UPDATE", "Mini_addons_PCNAME_REPLACE")
    -- レイドレコードの2度呼ばれるバグ修正
    core_g.register_msg("REQ_PLAYER_CONTENTS_RECORD", "Mini_addons__REQ_PLAYER_CONTENTS_RECORD")
    -- 死んだ時の選択肢を動かす
    core_g.register_msg("RESTART_HERE", "Mini_addons_RESTART_HERE")
    core_g.register_msg("RESTART_CONTENTS_HERE", "Mini_addons_RESTART_HERE")
    -- チャットフレーム改造
    if type(_G["ZCHATEXTENDS_ON_INIT"]) ~= "function" then
        Mini_addons_update_chat_frame()
        g.setup_hook_and_event(g.addon, "INVENTORY_OP_POP", "Mini_addons_INVENTORY_OP_POP", true)
    elseif g.settings.chat_new_btn == 1 then
        g.settings.chat_new_btn = 0
        Mini_addons_save_settings()
    end
    -- ちょい残しボタンcuervoexから移植
    g.setup_hook_and_event(g.addon, "WEEKLYBOSSREWARD_REWARD_OPEN", "Mini_addons_WEEKLYBOSSREWARD_REWARD_OPEN", true)
    -- スキル錬成のスロットにツールチップ
    g.setup_hook_and_event(g.addon, "COMMON_SKILL_ENCHANT_SET_GB", "Mini_addons_COMMON_SKILL_ENCHANT_SET_GB", true)
    -- グループチャット機能
    if g.settings.group_chat == 1 then
        g.setup_hook_and_event(g.addon, "CHAT_GROUPLIST_SELECT_LISTTYPE", "Mini_addons_CHAT_GROUPLIST_SELECT_LISTTYPE_",
            true)
        frame:RunUpdateScript("Mini_addons_CHAT_GROUPLIST_SELECT_LISTTYPE", 1.0)
        g.setup_hook_and_event(g.addon, "CHAT_GROUPLIST_OPTION_OK", "Mini_addons_CHAT_GROUPLIST_OPTION_OK", true)
        g.setup_hook_and_event(g.addon, "CHAT_SET_TO_TITLENAME", "Mini_addons_CHAT_SET_TO_TITLENAME", true)
    end
    -- ボスレランキング
    core_g.register_msg("WEEKLY_BOSS_UI_UPDATE", "Mini_addons_WEEKLYBOSS_PATTERNINFO_UI_UPDATE")
    g.setup_hook_and_event(g.addon, "WEEKLY_BOSS_RANK_UPDATE", "Mini_addons_WEEKLY_BOSS_RANK_UPDATE", true)
    g.setup_hook_and_event(g.addon, "INDUNINFO_UI_CLOSE", "Mini_addons_INDUNINFO_UI_CLOSE", true)
    -- 製造自動セット
    g.setup_hook_and_event(g.addon, "CRAFT_RECIPE_FOCUS", "Mini_addons_CRAFT_RECIPE_FOCUS", true)
    g.setup_hook_and_event(g.addon, "CRAFT_START_CRAFT", "Mini_addons_CRAFT_START_CRAFT", true)
    -- PTメンバーの死亡と復活をNICO_CHATで流す
    g.setup_hook_and_event(g.addon, "DRAW_CHAT_MSG", "Mini_addons_DRAW_CHAT_MSG", true)
    -- ワールドマップにトークンワープのクールダウンを表示
    g.setup_hook_and_event(g.addon, "OPEN_WORLDMAP2_MINIMAP", "Mini_addons_OPEN_WORLDMAP2_MINIMAP", true)
    -- FPS設定を手動入力
    g.setup_hook_and_event(g.addon, "SYS_OPTION_OPEN", "Mini_addons_SYS_OPTION_OPEN", true)
    -- ボスレランキングにメンバーインフォ
    g.setup_hook_and_event(g.addon, "WEEKLY_BOSS_RANK_UPDATE", "Mini_addons_WEEKLY_BOSS_RANK_UPDATE_", true)
    -- ヘアエンチャント関係
    -- 素の「設定」ボタン。**素の処理は乗っ取らない**(bool=true で元の関数をそのまま
    -- 呼び、標準のオプション窓は素の判断で開く)。こちらは開いたのを見て自前の窓を
    -- 畳むだけ。自前の窓を開く役目は「高度な設定」ボタン(下で足す)が持つ
    g.setup_hook_and_event(g.addon, "HIGH_ENCHANT_OPTION_OPEN_BTN", "Mini_addons_HIGH_ENCHANT_OPTION_OPEN_BTN", true)
    --
    -- 付与ウィンドウが開かれる入口。ここで「高度な設定」ボタンを足す
    g.setup_hook_and_event(g.addon, "CLIENT_ENCHANTCHIP", "Mini_addons_CLIENT_ENCHANTCHIP", true)
    -- 素材(ヘアアクセ)がスロットへ乗った所。自動で開く設定はここで効かせる
    -- (窓を組むにはアイテムとスクロールの両方が要るので、付与ウィンドウを開いた
    --  時点ではまだ組めない)
    g.setup_hook_and_event(g.addon, "HIGH_HAIRENCHANT_DRAW_HIRE_ITEM", "Mini_addons_HIGH_HAIRENCHANT_DRAW_HIRE_ITEM",
        true)
    g.setup_hook_and_event(g.addon, "HIGH_HAIRENCHANT_CLOSE_BTN", "Mini_addons_HIGH_HAIRENCHANT_CLOSE_BTN", true)
    g.setup_hook_and_event(g.addon, "HIGH_HAIRENCHANT_OK_BTN", "Mini_addons_HIGH_HAIRENCHANT_OK_BTN", false)
    -- 付与ボタンの押下。回している最中は「停止」として受ける(素は呼ばない)ので bool=false
    g.setup_hook_and_event(g.addon, "HIGH_HAIRENCHANT_SEND_BTN", "Mini_addons_HIGH_HAIRENCHANT_SEND_BTN", false)
    -- 連続付与を「時間が来たら撃つ」から「結果が返ったら撃つ」へ切り替えるための合図。
    -- 素は結果を受けると HIGH_HAIRENCHANT_UIEFFECT で HoldUI を掛け、EFFECT_DURATION(0.5秒)後に
    -- この関数を ReserveScript して解除する。**演出の終わり**を合図にするので素と重ならない
    g.setup_hook_and_event(g.addon, "_HIGH_HAIRENCHANT_SUCCESS", "Mini_addons__HIGH_HAIRENCHANT_SUCCESS", true)
    -- 「演出を待たずに実行」を ON にしたときだけ使う、ひとつ手前の合図。
    -- アイテムの実データが更新される SUCEECD 側を使う(SUCEECD_RESULT ではない。理由は実装側)
    g.setup_hook_and_event(g.addon, "HIGH_HAIRENCHANT_SUCEECD", "Mini_addons_HIGH_HAIRENCHANT_SUCEECD", true)
    -- チャットフレーム移動のワイドモニター制限解除
    g.setup_hook_and_event(g.addon, "_PROCESS_MOVE_MAIN_POPUPCHAT_FRAME",
        "Mini_addons__PROCESS_MOVE_MAIN_POPUPCHAT_FRAME", false)
    -- マーケット販売時に持ってる最大値を自動入力
    g.setup_hook_and_event(g.addon, "MARKET_SELL_UPDATE_REG_SLOT_ITEM", "Mini_addons_MARKET_SELL_UPDATE_REG_SLOT_ITEM",
        true)
    -- レイドレコードのサイズ、位置変更
    g.setup_hook_and_event(g.addon, "RAID_RECORD_INIT", "Mini_addons_RAID_RECORD_INIT", true)
    -- エンブレム、アークの着け忘れお知らせ
    g.setup_hook_and_event(g.addon, "SHOW_INDUNENTER_DIALOG", "Mini_addons_SHOW_INDUNENTER_DIALOG", true)
    -- 自動マッチのレイヤーを下げる
    g.setup_hook_and_event(g.addon, "INDUNENTER_AUTOMATCH_TYPE", "Mini_addons_INDUNENTER_AUTOMATCH_TYPE", true)
    -- 死んだ時のマウス位置制御
    g.setup_hook_and_event(g.addon, "RESTART_CONTENTS_ON_HERE", "Mini_addons_RESTART_CONTENTS_ON_HERE", true)
    -- オートキャスティングをキャラ毎に設定
    g.setup_hook_and_event(g.addon, "CONFIG_ENABLE_AUTO_CASTING", "Mini_addons_CONFIG_ENABLE_AUTO_CASTING", true)
    Mini_addons_SET_ENABLE_AUTO_CASTING()
    -- ペットコマンド制御
    g.setup_hook_and_event(g.addon, "SHOW_PET_RINGCOMMAND", "Mini_addons_SHOW_PET_RINGCOMMAND", false)
    -- レリックゲージ
    local map_name = session.GetMapName()
    local colony_cls_list, cnt = GetClassList("guild_colony")
    for i = 0, cnt - 1 do
        local colonyCls = GetClassByIndexFromList(colony_cls_list, i)
        local check_word = "GuildColony_"
        if not string.find(map_name, check_word) then
            Mini_addons_CHARBASE_RELIC()
            core_g.register_msg("RP_UPDATE", "Mini_addons_CHARBASE_RELIC")
        end
    end
    if g.get_map_type() == "City" then
        -- ヴェルニケ自動受取り
        Mini_addons_SOLODUNGEON_RANKINGPAGE_GET_REWARD()
        -- ボスレ報酬自動受取り
        Mini_addons_WEEKLY_BOSS_REWARD()
        -- 街のラガナを非表示
        Mini_addons_ragana_remove_timer()
        -- RPチャージを補完
        Mini_addons_rp_check()
        -- 町でマーケットボタンを常に表示
        Mini_addons_MINIMIZED_TOTAL_SHOP_BUTTON_CLICK()
        -- 傭兵団コイン、女神コイン、王国再建団コインを取得時、自動で使用
        Mini_addons_INV_ICON_USE()
        -- 錬成時に自動でアイテムセット
        g.setup_hook_and_event(g.addon, "COMMON_SKILL_ENCHANT_MAT_SET", "Mini_addons_COMMON_SKILL_ENCHANT_MAT_SET", true)
        g.setup_hook_and_event(g.addon, "SUCCESS_COMMON_SKILL_ENCHANT", "Mini_addons_SUCCESS_COMMON_SKILL_ENCHANT", true)
        -- 自動女神ガチャ
        Mini_addons_GP_FULL_BET()
        core_g.register_msg("FIELD_BOSS_WORLD_EVENT_START", "Mini_addons_GP_DO_OPEN")
        core_g.register_msg("FIELD_BOSS_WORLD_EVENT_END", "Mini_addons_FIELD_BOSS_WORLD_EVENT_END")
        -- オプションリロールの表を横に表示
        core_g.register_msg("OPEN_DLG_REROLL_ITEM", "Mini_addons_OPEN_DLG_REROLL_ITEM")
    end
    -- 細かい修正
    Mini_addons_minor_fixes()
    core_g.vlog("mini_addons: GAME_START_3SEC 完了")
    -- 個別版はここで sysmenu:RunUpdateScript("Mini_addons_make_menu", 2.0) を仕込み、
    -- アドオンメニューのボタンに自分の項目(アイコン)を並べていた。同梱版では
    -- **Nexus Addons P のアドオン一覧から開ければ十分**なので、登録しないことにした。
    -- 一覧側の入口は core/10_registry.lua の config_func = "Mini_addons_SETTING_FRAME_INIT"。
    --
    -- Mini_addons_make_menu 自体は残してあるが、どこからも呼ばれない。
    -- 中で norisan_menu_frame を作る処理も持っており、これは core/90_addons_menu.lua と
    -- 二重になるため、復活させるなら登録部分だけを呼ぶこと。
end
-- 細かい修正
function Mini_addons_minor_fixes()
    -- ノーマルジェムはめる時の修正
    g.setup_hook_and_event(g.addon, "GODDESS_MGR_SOCKET_INV_RBTN", "Mini_addons_GODDESS_MGR_SOCKET_INV_RBTN", true)
    -- カード強化とかジェム強化のインプット最適化
    g.setup_hook_and_event(g.addon, "INPUT_NUMBER_BOX", "Mini_addons_INPUT_NUMBER_BOX", true)
    -- ジェムロースティング屋の最適化
    g.setup_hook_and_event(g.addon, "GEMROASTING_TARGET_UI_CENCEL", "Mini_addons_GEMROASTING_TARGET_UI_CENCEL", true)
    g.setup_hook_and_event(g.addon, "ITEMBUFFGEMROASTING_UI_COMMON", "Mini_addons_ITEMBUFFGEMROASTING_UI_COMMON", true)
    -- 昔の装備ダメージフレーム消す
    -- Mini_addons_durnotify_hide()
end
-- ノーマルジェムはめる時の修正
function Mini_addons_GODDESS_MGR_SOCKET_INV_RBTN(my_frame, my_msg)
    local item_obj, slot, guid = g.get_event_args(my_msg)
    local inv_item = session.GetInvItemByGuid(guid)
    local gem_type = GET_EQUIP_GEM_TYPE(item_obj)
    local frame = ui.GetFrame('goddess_equip_manager')
    local normal_inner_bg = GET_CHILD_RECURSIVELY(frame, 'normal_inner_bg')
    local equip_item = session.GetInvItemByGuid(guid)
    local equip_obj = GetIES(equip_item:GetObject())
    local use_lv = TryGetProp(equip_obj, 'UseLv', 0)
    local max_socket_cnt = GET_MAX_GODDESS_NORMAL_SOCKET_COUNT(use_lv)
    for i = 0, max_socket_cnt - 1 do
        local ctrlset = GET_CHILD(normal_inner_bg, 'NORMAL_CSET_' .. i)
        AUTO_CAST(ctrlset)
        local gem_id = ctrlset:GetUserIValue('GEM_ID')
        if gem_id == 0 then
            local gem_slot = GET_CHILD(ctrlset, 'gem_slot')
            AUTO_CAST(gem_slot)
            GODDESS_MGR_SOCKET_NORMAL_GEM_EQUIP(ctrlset, gem_slot, inv_item, item_obj)
            break
        end
    end
end
-- カード強化とかジェム強化のインプット最適化
function Mini_addons_INPUT_NUMBER_BOX()
    local reinforce_by_mix = ui.GetFrame("reinforce_by_mix")
    if reinforce_by_mix:IsVisible() == 1 then
        local title = GET_CHILD_RECURSIVELY(reinforce_by_mix, "title")
        local titleValue = title:GetTextByKey("value")
        if titleValue == "@dicID_^*$ETC_20150317_001699$*^" or titleValue == "@dicID_^*$ETC_20150323_010016$*^" then
            local newframe = ui.GetFrame("inputstring")
            local edit = GET_CHILD(newframe, 'input', "ui::CEditControl")
            edit:SetEnableEditTag(1)
            edit:SetText("1")
        end
    end
end
-- ジェムロースティング屋の最適化
function Mini_addons_GEMROASTING_TARGET_UI_CENCEL()
    INVENTORY_SET_CUSTOM_RBTNDOWN("None")
end

function Mini_addons_ITEMBUFFGEMROASTING_UI_COMMON(frame, msg)
    INVENTORY_SET_CUSTOM_RBTNDOWN("Mini_addons_gem_roasting_rbtn")
end

function Mini_addons_gem_roasting_rbtn(item_obj, slot)
    local icon = slot:GetIcon()
    local icon_info = icon:GetInfo()
    local iesid = icon_info:GetIESID()
    local inv_item = GET_PC_ITEM_BY_GUID(iesid)
    if not inv_item then
        return
    end
    local type = icon_info.type
    local item_cls = GetClassByType("Item", type)
    local pc = GetMyPCObject()
    local obj = GetIES(inv_item:GetObject())
    local itembuffgemroasting = ui.GetFrame("itembuffgemroasting")
    local target_slot = GET_CHILD_RECURSIVELY(itembuffgemroasting, "slot")
    if obj.GemRoastingLv >= itembuffgemroasting:GetUserIValue("SKILLLEVEL") then
        ui.SysMsg(ClMsg("CannontDropGam"))
        return
    end
    local check_item = _G["ITEMBUFF_CHECK_" .. itembuffgemroasting:GetUserValue("SKILLNAME")]
    if check_item(pc, obj) ~= 1 then
        ui.SysMsg(ClMsg("WrongDropItem"))
        return
    end
    local check_func = _G["ITEMBUFF_NEEDITEM_" .. itembuffgemroasting:GetUserValue("SKILLNAME")]
    local name, cnt = check_func(pc, obj)
    SET_SLOT_ITEM_IMAGE(target_slot, inv_item)
    target_slot:SetUserValue("GEM_IESID", icon_info:GetIESID())
    local roasting = itembuffgemroasting:GetChild("roasting")
    local slotName = roasting:GetChild("slotName")
    slotName:SetTextByKey("txt", obj.Name)
    local effectGbox = GET_CHILD(roasting, "effectGbox")
    AUTO_CAST(effectGbox)
    effectGbox:RemoveChild('tooltip_gem_property')
    local y_pos = 100
    local tooltip_gem_property = effectGbox:CreateOrGetControlSet('tooltip_gem_property', 'tooltip_gem_property', 0,
        y_pos)
    AUTO_CAST(tooltip_gem_property)
    local gem_property_gbox = GET_CHILD(tooltip_gem_property, 'gem_property_gbox')
    AUTO_CAST(gem_property_gbox)
    local inner_y_pos = 0
    local inner_cset = nil
    local inner_prop_count = 0
    local inner_prop_y_pos = 0
    local lv = GET_ITEM_LEVEL_EXP(obj, obj.ItemExp) - itembuffgemroasting:GetUserIValue("SKILLLEVEL")
    if lv < 1 then
        lv = 0
    end
    local gem_prop = geItemTable.GetProp(obj.ClassID)
    local socket_penalty_prop = gem_prop:GetSocketPropertyByLevel(lv)
    local prop_index = 0
    local prop_name_list = GET_ITEM_PROP_NAME_LIST(obj)
    for i = 1, #prop_name_list do
        local title = prop_name_list[i]["Title"]
        local prop_name = prop_name_list[i]["PropName"]
        local prop_value = prop_name_list[i]["PropValue"]
        local use_operator = prop_name_list[i]["UseOperator"]
        if title then
            inner_cset = gem_property_gbox:CreateOrGetControlSet('tooltip_each_gem_property', title, 0, inner_y_pos)
            AUTO_CAST(inner_cset)
            local type_text = GET_CHILD(inner_cset, 'type_text')
            AUTO_CAST(type_text)
            type_text:SetText(ScpArgMsg(title))
            local type_icon = GET_CHILD(inner_cset, 'type_icon')
            AUTO_CAST(type_icon)
            local img_name = GET_ICONNAME_BY_WHENEQUIPSTR(tooltip_gem_property, title)
            type_icon:SetImage(img_name)
            inner_prop_count = 0
            inner_prop_y_pos = type_text:GetHeight() + type_text:GetY()
            inner_cset:GetChild("labelline"):ShowWindow(0)
        else
            if inner_cset then
                local inner_inner_cset = inner_cset:CreateOrGetControlSet('tooltip_each_gem_property_each_text',
                    'proptext' .. inner_prop_count, 0, inner_prop_y_pos)
                AUTO_CAST(inner_inner_cset)
                local real_text = nil
                local penalty_text = nil
                if use_operator and prop_value > 0 then
                    real_text = ScpArgMsg(prop_name) .. " : " .. "{img green_up_arrow 16 16}" .. prop_value
                else
                    local prop_penalty_add = socket_penalty_prop:GetPropPenaltyAddByIndex(prop_index, 0)
                    if nil == prop_penalty_add then
                        ui.SysMsg(ClMsg("WrongDropItem"))
                        GEMROASTING_UI_RESET(itembuffgemroasting)
                        return
                    end
                    prop_index = prop_index + 1
                    real_text = ScpArgMsg(prop_name) .. " : " .. "{img red_down_arrow 16 16}" .. prop_value
                    penalty_text =
                        string.format("   {img alch_gemlos_arrow %d %d}   ", 80, 18) .. ScpArgMsg('PropDown') ..
                            prop_penalty_add.value
                end
                local prop_text = GET_CHILD(inner_inner_cset, 'prop_text')
                AUTO_CAST(prop_text)
                prop_text:SetText(real_text)
                local prop_penalty_text = GET_CHILD(inner_inner_cset, 'prop_text2')
                AUTO_CAST(prop_penalty_text)
                prop_penalty_text:SetText(penalty_text)
                prop_penalty_text:SetMargin(210, 0, 0, 0)
                inner_prop_count = inner_prop_count + 1
                AUTO_CAST(inner_cset)
                inner_prop_y_pos = inner_inner_cset:GetY() + inner_inner_cset:GetHeight()
                inner_cset:Resize(inner_cset:GetOriginalWidth(),
                    inner_inner_cset:GetY() + inner_inner_cset:GetHeight() + 10)
                inner_y_pos = inner_cset:GetY() + inner_cset:GetHeight()
            end
        end
    end
    gem_property_gbox:Resize(gem_property_gbox:GetOriginalWidth(), inner_y_pos)
    tooltip_gem_property:Resize(tooltip_gem_property:GetWidth(), tooltip_gem_property:GetHeight() +
        gem_property_gbox:GetHeight() + gem_property_gbox:GetY() + 10)
    GEMROASTING_UPDATE_MATERIAL(itembuffgemroasting, cnt, icon_info:GetIESID())
    GEMROASTING_VIEW(itembuffgemroasting)
    if itembuffgemroasting:GetUserIValue("HANDLE") ~= session.GetMyHandle() then
        local reqitemMoney = roasting:GetChild("reqitemMoney")
        reqitemMoney:SetTextByKey("txt", cnt * itembuffgemroasting:GetUserIValue("PRICE"))
    end
end
-- 昔の装備ダメージフレーム消す
function Mini_addons_durnotify_hide()
    local durnotify = ui.GetFrame("durnotify")
    if durnotify and durnotify:IsVisible() == 1 then
        durnotify:Resize(0, 0)
    end
end

function Mini_addons_FPS_UPDATE()
    -- オートズーム
    Mini_addons_autozoom()
    -- 傭兵団コイン獲得フレームを表示
    if g.get_map_type() == "City" then
        local coin_get_gauge = ui.GetFrame("coin_get_gauge")
        if config.GetXMLStrConfig("ShowCoinGetGauge") ~= "0" and coin_get_gauge:IsVisible() == 0 then
            coin_get_gauge:ShowWindow(1)
        end
    end
    -- ESC などで隠れたメニューボタンを出し直す。ただし
    -- 「システムメニューの右クリックのみにする」(core/90_addons_menu.lua の sysmenu_only)を
    -- 選んでいるときは、意図して隠しているので出し直さない。
    -- ここは毎フレーム走るので、設定を見ないと消した直後に必ず復活する(実機で発生)。
    if _G["norisan"] and _G["norisan"]["MENU"] and _G["norisan"]["MENU"].sysmenu_only == 1 then
        return
    end
    local norisan_menu_frame = ui.GetFrame("norisan_menu_frame")
    if norisan_menu_frame and norisan_menu_frame:IsVisible() == 0 then
        norisan_menu_frame:ShowWindow(1)
    end
end

function Mini_addons_make_menu(frame)
    _G["norisan"] = _G["norisan"] or {}
    _G["norisan"]["MENU"] = _G["norisan"]["MENU"] or {}
    local menu_data = {
        name = "Mini Addons",
        icon = "sysmenu_jal",
        func = "Mini_addons_SETTING_FRAME_INIT",
        image = ""
    }
    _G["norisan"]["MENU"][addon_name] = menu_data
    core_g.vlog("mini_addons: メニューへ登録 key=%s", tostring(addon_name))
    local frame_name = _G["norisan"]["MENU"].frame_name
    local menu_frame = ui.GetFrame(frame_name)
    if menu_frame and frame_name ~= "norisan_menu_frame" then
        ui.DestroyFrame(frame_name)
    end
    frame_name = "norisan_menu_frame"
    menu_frame = ui.GetFrame(frame_name)
    -- sysmenu_only のときは「隠れている」が正常なので作り直さない
    -- (作り直すと create_frame 側が非表示で作るため、毎回作り直し続けることになる)。
    if _G["norisan"]["MENU"].sysmenu_only == 1 then
        return 0
    end
    if not menu_frame or menu_frame:IsVisible() == 0 then
        _G["norisan"]["MENU"].frame_name = frame_name
        _G.addons_menu_create_frame()
        return 1
    end
    return 0
end

function Mini_addons_runupdate_5(mini_addons)
    -- セパレートバフフレームの周りを綺麗に
    Mini_addons_buff_separatedlist()
    -- クポルポーションフレームの移動と非表示
    Mini_addons_cupole_portion_frame()
    -- パーティーメンバーの場所表示
    Mini_addons_partymember_get_map()
    local restart = ui.GetFrame("restart")
    if restart:IsVisible() == 0 then
        restart:SetUserValue("COLONY_TIMER_RUNNING", 0)
    end
    local mini_addons_channel = ui.GetFrame((addon_name_lower .. "_channel"))
    if g.zone_insts and mini_addons_channel and mini_addons_channel:IsVisible() == 0 then
        mini_addons_channel:ShowWindow(1)
    end
    -- 町でマーケットボタンを常に表示
    Mini_addons_MINIMIZED_TOTAL_SHOP_BUTTON_CLICK()
    -- 傭兵団コイン、女神コイン、王国再建団コインを取得時、自動で使用
    Mini_addons_INV_ICON_USE()
    -- 町でBGMPLAYERを常に動かす
    Mini_addons_BGM_PLAY_LIST()
    -- パーティー情報フレームを小さくする
    Mini_addons_PARTY_BUFFLIST_UPDATE()
    return 1
end

function Mini_addons_CHAT_SYSTEM(msg, color)
    if msg and g.settings.chat_system == 1 then
        if msg == "&lt완벽함&gt 효과가 사라졌습니다." or msg ==
            "&lt완벽함&gt 효과가 발동되었습니다." or msg == "@dicID_^*$ETC_20220830_069434$*^" or msg ==
            "@dicID_^*$ETC_20220830_069435$*^" or msg == "[__m2util] is loaded" or msg == "[adjustlayer] is loaded" or
            msg == "[extendcharinfo] is loaded" or msg == "[ICC]Attempt to CC." or
            -- string.find は既定でパターン照合なので、必ず plain(第 4 引数 true)で呼ぶこと。
            -- "[__m2util] is loaded" をそのまま渡すと "[...]" が文字クラスと解釈され、
            -- 「_ m 2 u t i l のどれか 1 文字 + ' is loaded'」に化けて、無関係な
            -- システムメッセージ("t is loaded" 等)まで握り潰していた。
            string.find(msg, "StartBlackMarketBetween", 1, true) or
            string.find(msg, "[__m2util] is loaded", 1, true) or
            string.find(msg, "[adjustlayer] is loaded", 1, true) or string.find(msg, "MapMate", 1, true) then
            return
        end
    end
    -- 色は呼び出し元の指定をそのまま渡す。個別版はここで "FFFF00" 固定にしていたが、
    -- まとめ版では同じ CHAT_SYSTEM に他アドオンも乗るため、赤いエラー文も本家検出の
    -- {#FF6347} の告知も、他アドオンの色付きメッセージも全部黄色になってしまう。
    g.FUNCS["CHAT_SYSTEM"](msg, color)
end
-- オートズーム
function Mini_addons_autozoom_edit(frame, ctrl)
    local value = tonumber(ctrl:GetText())
    if value < 1 or value > 700 then
        local errorMsg =
            g.lang == "Japanese" and "無効な値です。1から700の間で設定してください。" or
                "Invalid value please set between 1 and 700"
        ui.SysMsg(errorMsg)
        ctrl:SetText("336")
        g.settings.auto_zoom.zoom = 336
    else
        if value ~= g.settings.auto_zoom.zoom then
            ui.SysMsg("Auto Zoom setting set to " .. value)
            g.settings.auto_zoom.zoom = value
        end
    end
    Mini_addons_save_settings()
    ctrl:RunUpdateScript("Mini_addons_autozoom", 1.0)
end

function Mini_addons_autozoom(ctrl)
    if g.settings.auto_zoom.use == 1 then
        camera.CustomZoom(tonumber(g.settings.auto_zoom.zoom))
    end
end
-- セパレートバフフレームの周りを綺麗に
function Mini_addons_buff_separatedlist()
    local buff_separatedlist = ui.GetFrame("buff_separatedlist")
    local gbox = GET_CHILD_RECURSIVELY(buff_separatedlist, "gbox")
    AUTO_CAST(gbox)
    if g.settings.separated_buff == 1 then
        gbox:SetSkinName("None")
    else
        gbox:SetSkinName("chat_window")
    end
end
-- クポルポーションフレームの移動と非表示
function Mini_addons_cupole_portion_frame_save(cupole_external_addon)
    g.settings.cupole_portion.x = cupole_external_addon:GetX()
    g.settings.cupole_portion.y = cupole_external_addon:GetY()
    Mini_addons_save_settings()
end

function Mini_addons_cupole_portion_frame()
    local cupole_external_addon = ui.GetFrame("cupole_external_addon")
    if g.settings.cupole_portion.x == 0 and g.settings.cupole_portion.y == 0 then
        local cur_x = cupole_external_addon:GetX()
        local cur_y = cupole_external_addon:GetY()
        if g.settings.cupole_portion.def_x ~= cur_x or g.settings.cupole_portion.def_y ~= cur_y then
            g.settings.cupole_portion.def_x = cur_x
            g.settings.cupole_portion.def_y = cur_y
            Mini_addons_save_settings()
        end
    end
    if g.settings.cupole_portion.use == 1 then
        cupole_external_addon:ShowWindow(0)
    else
        if g.settings.cupole_portion.x == 0 and g.settings.cupole_portion.y == 0 then
            cupole_external_addon:SetPos(g.settings.cupole_portion.def_x, g.settings.cupole_portion.def_y)
        else
            cupole_external_addon:SetPos(g.settings.cupole_portion.x, g.settings.cupole_portion.y)
        end
        cupole_external_addon:ShowWindow(1)
    end
end
-- クエストインフォを隠す
function Mini_addons_ON_UPDATE_QUESTINFOSET_2(questinfoset_2, msg, check, update_quest_id)
    local chase_info = ui.GetFrame("chaseinfo")
    local open_mark_quest = GET_CHILD_RECURSIVELY(chase_info, "openMark_quest")
    AUTO_CAST(open_mark_quest)
    open_mark_quest:ShowWindow(1)
    open_mark_quest:SetEventScript(ui.RBUTTONUP, "Mini_addons_questinfo_toggle")
    local notice =
        g.lang == "Japanese" and "{ol}Mini Addons{nl}右クリック: クエストの表示/非表示切替" or
            "{ol}Mini Addons{nl}Right-click: Show/hide quests"
    open_mark_quest:SetTextTooltip(notice)
    if not questinfoset_2 then
        questinfoset_2 = ui.GetFrame("questinfoset_2")
    end
    if g.settings.quest_hide == 1 then
        questinfoset_2:ShowWindow(0)
        return
    end
    if CHASEINFO_IS_SHOW() == 0 then
        CHASEINFO_CLOSE_FRAME()
        return
    end
    CHASEINFO_SHOW_QUEST_TOGGLE(QUESTINFOSET_2_IS_DRAW())
    CHASEINFO_SHOW_ACHIEVE_TOGGLE(ACHIEVEINFOSET_IS_DRAW())
    if QUESTINFOSET_2_IS_DRAW() == 0 then
        questinfoset_2:ShowWindow(0)
        return
    else
        if ACHIEVEINFOSET_IS_DRAW() == 1 then
            if CHASEINFO_IS_ACHIEVE_FOLD() == 0 then
                CHASEINFO_SET_QUEST_INFOSET_FOLD(1)
            else
                if CHASEINFO_IS_QUEST_FOLD() == 1 then
                    CHASEINFO_SET_QUEST_INFOSET_FOLD(1)
                else
                    CHASEINFO_SET_QUEST_INFOSET_FOLD(0)
                end
            end
        else
            CHASEINFO_SET_QUEST_INFOSET_FOLD(0)
        end
    end
    if ACHIEVEINFOSET_IS_VALID_ACHIEVE() == 1 and CHASEINFO_IS_ACHIEVE_FOLD() == 0 then
        questinfoset_2:ShowWindow(0)
        return
    elseif CHASEINFO_IS_QUEST_FOLD() == 1 then
        questinfoset_2:ShowWindow(0)
        return
    else
        questinfoset_2:ShowWindow(1)
    end
    if update_quest_id ~= nil and update_quest_id > 0 then
        local group_ctrl = GET_CHILD(questinfoset_2, "member", "ui::CGroupBox")
        UPDATE_QUESTINFOSET_2_BY_TYPE(group_ctrl, msg, update_quest_id)
        QUESTINFOSET_2_AUTO_ALIGN(questinfoset_2, group_ctrl)
        return
    end
    if msg == "GAME_START" then
        PC_ENTER_QUESTINFO(questinfoset_2)
    end
    local group_ctrl = GET_CHILD(questinfoset_2, "member", "ui::CGroupBox")
    group_ctrl:DeleteAllControl()
    local quest_custom = GET_CHILD(questinfoset_2, "quest_custom")
    local quest_custom_size = quest_custom:GetMargin().top + quest_custom:GetHeight()
    local y = quest_custom_size
    local custom_option = GET_CHILD(questinfoset_2, "quest_custom", "ui::CCheckBox")
    if custom_option:IsChecked() == 0 then
        local cnt = QUESTINFOSET_2_GET_QUEST_NUM()
        for i = 0, cnt - 1 do
            local quest_id = quest.GetCheckQuest(i)
            local quest_cls = GetClassByType("QuestProgressCheck", quest_id)
            local ctrl_set = MAKE_QUEST_INFO_C(group_ctrl, quest_cls, msg)
            if ctrl_set ~= nil then
                y = y + ctrl_set:GetHeight()
            end
        end
    end
    local value = custom_option:GetUserIValue("is_quest_custom_draw")
    local custom_cnt = QUESTINFOSET_2_GET_CUSTOM_QUEST_NUM()
    if custom_cnt > 0 and (value ~= -1 or custom_option:IsChecked() == 1) then
        local ctrl_set = QUESTINFOSET_2_MAKE_CUSTOM(questinfoset_2, true)
        if ctrl_set ~= nil then
            y = y + ctrl_set:GetHeight()
        end
    end
    QUESTINFOSET_2_AUTO_ALIGN(questinfoset_2, group_ctrl)
    if custom_option:IsChecked() == 0 then
        QUEST_PARTY_MEMBER_PROP_UPDATE(questinfoset_2)
    end
end

function Mini_addons_questinfo_toggle(parent, openMark_quest)
    g.settings.quest_hide = 1 - g.settings.quest_hide
    Mini_addons_save_settings()
    Mini_addons_ON_UPDATE_QUESTINFOSET_2(nil)
end
-- お使いクエストフレーム
function Mini_addons_quest_update(frame, msg)
    if g.settings.daily_quest == 0 then
        ui.DestroyFrame((addon_name_lower .. "_q7quest"))
        return
    end
    local questinfoset_2 = ui.GetFrame("questinfoset_2")
    local _Q_7 = GET_CHILD_RECURSIVELY(questinfoset_2, "_Q_7")
    if _Q_7 then
        local color = "{#FFFFFF}"
        local extracted_content
        local MON_1 = GET_CHILD(_Q_7, "MON_1")
        if MON_1 then
            local text = MON_1:GetText()
            local pattern = "%((.-)%)"
            extracted_content = text:match(pattern)
            extracted_content = color .. extracted_content
        else
            color = "{#FF0000}"
            extracted_content = color .. "150/150"
        end
        local QUESTINFOMAP = GET_CHILD(_Q_7, "QUESTINFOMAP")
        local last_part
        if QUESTINFOMAP then
            local text = QUESTINFOMAP:GetText()
            last_part = text:match(".*{nl}(.-)$") or ""
        end
        if last_part == "" then
            local q7quest = ui.GetFrame((addon_name_lower .. "_q7quest"))
            if q7quest then
                AUTO_CAST(q7quest)
                q7quest:ShowWindow(0)
                return
            end
        end
        local groupQuest_title = GET_CHILD(_Q_7, "groupQuest_title")
        local text = groupQuest_title:GetText()
        local pattern = "{#ffe792}(.-) %-"
        local extracted_text = text:match(pattern) or "Quest"
        local q7quest = ui.GetFrame((addon_name_lower .. "_q7quest"))
        if not q7quest then
            q7quest = ui.CreateNewFrame("notice_on_pc", (addon_name_lower .. "_q7quest"), 0, 0, 0, 0)
            AUTO_CAST(q7quest)
        end
        if not msg then
            q7quest:RemoveAllChild()
        end
        q7quest:SetSkinName("bg2")
        q7quest:Resize(200, 85)
        local current_frame_w = q7quest:GetWidth()
        local map_frame = ui.GetFrame("map")
        local map_width = map_frame:GetWidth()
        q7quest:SetPos((map_width - current_frame_w) / 2, 130)
        q7quest:SetLayerLevel(100)
        if _G["INDUN_PANEL_ON_INIT"] and type(_G["INDUN_PANEL_ON_INIT"]) == "function" then
            local indun_panel = ui.GetFrame("indun_panel")
            if indun_panel then
                indun_panel_always_init(indun_panel, nil, nil)
            end
        end
        if _G["indun_panel_on_init"] and type(_G["indun_panel_on_init"]) == "function" then
            -- 自分側の indun_panel。フレーム名は core の addon_name_lower("_nexus_addons_p")
            -- が前に付く。ここを直書きにすると P へのリネームで食い違う
            local indun_panel = ui.GetFrame(core_addon_name_lower .. "indun_panel")
            if indun_panel then
                Indun_panel_always_init(indun_panel, nil, nil)
            end
        end
        local quest_name = q7quest:CreateOrGetControl("richtext", "quest_name", 10, 5, 180, 25)
        AUTO_CAST(quest_name)
        quest_name:SetTextAlign("center", "center")
        quest_name:SetText("{ol}{s16}" .. extracted_text)
        quest_name:EnableTextOmitByWidth(1)
        local map_name = q7quest:CreateOrGetControl("richtext", "map_name", 10, 30, 180, 25)
        AUTO_CAST(map_name)
        map_name:SetTextAlign("center", "center")
        map_name:SetText("{ol}{s16}" .. last_part)
        map_name:EnableTextOmitByWidth(1)
        local kill_count = q7quest:CreateOrGetControl("richtext", "kill_count", 10, 55, 180, 25)
        AUTO_CAST(kill_count)
        kill_count:SetTextAlign("center", "center")
        kill_count:SetText("{ol}{s18}" .. extracted_content)
        local token_warp = q7quest:CreateOrGetControl("button", "token_warp", 5, 48, 40, 40)
        AUTO_CAST(token_warp)
        token_warp:SetSkinName("None")
        local is_token_state = session.loginInfo.IsPremiumState(ITEM_TOKEN)
        local image_name = ""
        if is_token_state == true and GET_TOKEN_WARP_COOLDOWN() == 0 then
            image_name = "{img worldmap2_token_gold 35 35} {@st101lightbrown_16}"
        else
            image_name = "{img worldmap2_token_gray 35 35} {@st101lightbrown_16}"
        end
        token_warp:SetText(image_name)
        token_warp:SetTextTooltip("{ol}" .. last_part)
        token_warp:SetEventScript(ui.LBUTTONUP, "Mini_addons_quest_token_warp")
        q7quest:ShowWindow(1)
        local abandon = q7quest:CreateOrGetControl("button", "abandon", 165, 53, 30, 30)
        AUTO_CAST(abandon)
        abandon:SetSkinName("test_gray_button")
        abandon:SetText("×")
        abandon:SetEventScript(ui.LBUTTONUP, "SCR_QUEST_ABANDON_SELECT")
        abandon:SetEventScriptArgNumber(ui.LBUTTONUP, 7)
    else
        ui.DestroyFrame((addon_name_lower .. "_q7quest"))
    end
end

function Mini_addons_quest_token_warp()
    local target_map = Mini_addons_quest_get_map()
    if target_map then
        WORLDMAP2_TOKEN_WARP(target_map)
    end
end

function Mini_addons_quest_get_map()
    local quest_ies = GetClassByType("QuestProgressCheck", 7)
    local pc = SCR_QUESTINFO_GET_PC()
    local quest_max_mon_check = 6
    if quest_ies.Quest_SSN ~= "None" then
        local s_obj_quest = GetSessionObject(pc, quest_ies.Quest_SSN)
        if s_obj_quest and s_obj_quest.SSNMonKill ~= "None" then
            local mon_list = SCR_STRING_CUT(s_obj_quest.SSNMonKill, ":")
            if mon_list[1] == "ZONEMONKILL" then
                for i = 1, quest_max_mon_check do
                    if #mon_list - 1 >= i then
                        local index = i + 1
                        local zone_mon_info = SCR_STRING_CUT(mon_list[index])
                        local target_map = tostring(zone_mon_info[1])
                        return target_map
                    end
                end
            end
        end
    end
    return nil
end
-- 最初回のイベントバナーのレイヤー下げる
function Mini_addons_event_banner_layer()
    local ingameeventbanner = ui.GetFrame("ingameeventbanner")
    if ingameeventbanner and ingameeventbanner:IsVisible() == 1 then
        AUTO_CAST(ingameeventbanner)
        ingameeventbanner:SetLayerLevel(99)
    end
end
-- 追加報酬券チェック ここから
local multiple_tokens = {
    ["Goddess_Raid_DespairIsland_Party"] = {11200361, 11200362},
    ["Goddess_Raid_BlackRevelation_Party"] = {11200387, 11200388},
    ["Goddess_Raid_CollapsingMine_Party"] = {11200395, 11200396},
    ["Goddess_Raid_Redania_Party"] = {11200403, 11200404},
    ["Goddess_Raid_Laimara_Party"] = {11200434, 11200435},
    ["Goddess_Raid_Veliora_Party"] = {11200438, 11200439}
}
function Mini_addons_REQ_PLAYER_CONTENTS_RECORD(frame, msg)
    if g.settings.multiple_item == 0 then
        return
    end
    local current_raid_name = session.mgame.GetCurrentMGameName()
    local target_tokens = multiple_tokens[current_raid_name]
    if not target_tokens then
        return
    end
    local function has_inv_item(target_cls_id)
        local inv_item_list = session.GetInvItemList()
        local guid_list = inv_item_list:GetGuidList()
        local cnt = guid_list:Count()
        for i = 0, cnt - 1 do
            local guid = guid_list:Get(i)
            local inv_item = inv_item_list:GetItemByGuid(guid)
            if inv_item and inv_item.type == target_cls_id then
                return true
            end
        end
        return false
    end
    for _, token_id in ipairs(target_tokens) do
        if has_inv_item(token_id) then
            local msg = g.lang == "Japanese" and "追加報酬券持ってるで！！" or
                            "I've got Additional Reward Tickets!"
            _G.imcAddOn.BroadMsg("NOTICE_Dm_Global_Shout", "{st55_a}{#FF8C00}" .. msg, 10)
            if _G["NICO_CHAT"] then
                for j = 1, 10 do
                    NICO_CHAT(string.format("{@st55_a}%s", msg))
                end
            end
            return 0
        end
    end
end
-- チャットフレーム改造
function Mini_addons_chat_frame_drop(chat)
    g.settings.chat_xy.x = chat:GetX()
    g.settings.chat_xy.y = chat:GetY()
    Mini_addons_save_settings()
end

function Mini_addons_my_pos()
    local map_frame = ui.GetFrame("map")
    local map_pic = GET_CHILD(map_frame, "map")
    local my_pos = GET_CHILD(map_frame, "my")
    local x, y = GET_C_XY(my_pos)
    x = x + (my_pos:GetWidth() / 2) - map_pic:GetX()
    y = y + (my_pos:GetHeight() / 2) - map_pic:GetY()
    local map_name = session.GetMapName()
    local map_prop = geMapTable.GetMapProp(map_name)
    local worldPos = map_prop:MinimapPosToWorldPos(x, y, map_pic:GetWidth(), map_pic:GetHeight())
    LINK_MAP_POS(map_name, worldPos.x, worldPos.y)
end

function Mini_addons_toggle_inventory()
    ui.ToggleFrame("inventory")
end

function Mini_addons_update_chat_frame()
    local chat = ui.GetFrame("chat")
    local mainchat = GET_CHILD(chat, "mainchat")
    local edit_bg = GET_CHILD(chat, "edit_bg")
    local edit_to_bg = GET_CHILD(chat, "edit_to_bg")
    AUTO_CAST(mainchat)
    AUTO_CAST(edit_bg)
    AUTO_CAST(edit_to_bg)
    chat:RemoveChild("pos_btn")
    chat:RemoveChild("party_btn")
    chat:RemoveChild("item_btn")
    chat:SetEventScript(ui.LBUTTONUP, "Mini_addons_chat_frame_drop")
    if g.settings.chat_new_btn == 0 then
        chat:Resize(chat:GetOriginalWidth(), chat:GetOriginalHeight())
        mainchat:SetGravity(ui.LEFT, ui.TOP)
        chat:SetPos(g.settings.chat_xy.x or chat:GetX(), g.settings.chat_xy.y or chat:GetY())
        return
    end
    chat:Resize(585, chat:GetOriginalHeight())
    edit_bg:Resize(567, 36)
    mainchat:Resize(585, mainchat:GetOriginalHeight())
    mainchat:SetGravity(ui.LEFT, ui.TOP)
    edit_to_bg:SetGravity(ui.LEFT, ui.TOP)
    local button_emo = GET_CHILD(chat, "button_emo")
    local base_x = button_emo:GetX() - 35
    local function create_btn(name, x_offset, img, script, w, h)
        local btn = chat:CreateOrGetControl("button", name, 0, 0, 0, 0)
        AUTO_CAST(btn)
        btn:SetPos(base_x + x_offset, 0)
        btn:SetClickSound("button_click")
        btn:SetOverSound("button_cursor_over_2")
        btn:SetAnimation("MouseOnAnim", "btn_mouseover")
        btn:SetAnimation("MouseOffAnim", "btn_mouseoff")
        btn:SetEventScript(ui.LBUTTONDOWN, script)
        if img:find("{") then
            btn:SetText(img)
            btn:SetSkinName("textbutton")
        else
            btn:SetImage(img)
        end
        btn:Resize(w, h)
        return btn
    end
    create_btn("pos_btn", 0, "button_pos_img", "Mini_addons_my_pos", 39, 39)
    create_btn("party_btn", -32, "btn_partyshare", "LINK_PARTY_INVITE", 36, 36)
    create_btn("item_btn", -70, "{img sysmenu_inv 42 42}", "Mini_addons_toggle_inventory", 40, 37)
    chat:SetPos(g.settings.chat_xy.x or chat:GetX(), g.settings.chat_xy.y or chat:GetY())
    chat:Invalidate()
end

function Mini_addons_INVENTORY_OP_POP(my_frame, my_msg)
    if g.settings.chat_new_btn == 0 then
        return
    end
    local chat = ui.GetFrame("chat")
    if chat:IsVisible() == 0 then
        return
    end
    if keyboard.IsKeyPressed("LCTRL") == 1 then
        return
    end
    local frame, slot, str, num = g.get_event_args(my_msg)
    local icon = slot:GetIcon()
    local icon_info = icon:GetInfo()
    local iesid = icon_info:GetIESID()
    local inv_item = session.GetInvItemByGuid(iesid)
    if inv_item then
        LINK_ITEM_TEXT(inv_item)
    end
end
-- ちょい残し　ここから
local reward_map = {"125000", "2000000", "5000000", "10000000", "18750000", "25000000", "37500000", "50000000",
                    "125000000", "175000000", "250000000", "300000000", "375000000", "625000000", "750000000",
                    "1250000000", "1750000000"}
function Mini_addons_WEEKLYBOSSREWARD_REWARD_OPEN(my_frame, my_msg)
    local index = g.get_event_args(my_msg)
    local weeklyboss_reward = ui.GetFrame("weeklyboss_reward")
    local btn_reward = GET_CHILD(weeklyboss_reward, "btn_reward")
    if g.settings.keep_first == 0 or index ~= 1 or btn_reward:IsEnable() == 0 then
        local my_btn = GET_CHILD(weeklyboss_reward, "my_btn")
        if my_btn then
            weeklyboss_reward:StopUpdateScript("Mini_addons_get_damage_reward")
            weeklyboss_reward:RemoveChild("my_btn")
        end
        return
    end
    local close = GET_CHILD(weeklyboss_reward, "closeBtn")
    AUTO_CAST(close)
    close:SetEventScript(ui.LBUTTONDOWN, "Mini_addons_start_get_reward_stop")
    local my_btn = weeklyboss_reward:CreateOrGetControl("button", "my_btn", 315, 655, 120, 40)
    AUTO_CAST(my_btn)
    my_btn:SetText("{ol}keep first")
    my_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_start_get_reward")
    local max_index = #reward_map
    my_btn:SetEventScriptArgString(ui.LBUTTONUP, reward_map[max_index])
    my_btn:SetEventScriptArgNumber(ui.LBUTTONUP, max_index)
end

function Mini_addons_start_get_reward_stop(weeklyboss_reward)
    local my_btn = GET_CHILD(weeklyboss_reward, "my_btn")
    my_btn:StopUpdateScript("Mini_addons_get_damage_reward")
end

function Mini_addons_start_get_reward(weeklyboss_reward, my_btn, amount_str, index_num)
    local reward = GET_CHILD_RECURSIVELY(weeklyboss_reward, "REWARD_" .. index_num)
    local attr_btn = GET_CHILD(reward, "attr_btn")
    if attr_btn and attr_btn:IsEnable() == 1 then
        local week_num = weeklyboss_reward:GetUserValue("WEEK_NUM")
        weekly_boss.RequestAcceptAbsoluteReward(week_num, amount_str)
    end
    my_btn:SetUserValue("REWARD_INDEX", index_num - 1) -- 最大値から開始
    my_btn:SetUserValue("LAST_REQ_INDEX", 0)
    my_btn:RunUpdateScript("Mini_addons_get_damage_reward", 0.3)
end

function Mini_addons_get_damage_reward(my_btn)
    local index = my_btn:GetUserIValue("REWARD_INDEX")
    if not index or index < 2 then
        return 0
    end
    local weeklyboss_reward = my_btn:GetParent()
    local reward = GET_CHILD_RECURSIVELY(weeklyboss_reward, "REWARD_" .. index)
    if reward then
        local attr_btn = GET_CHILD(reward, "attr_btn")
        if attr_btn:IsEnable() == 1 then
            local week_num = weeklyboss_reward:GetUserValue("WEEK_NUM")
            weekly_boss.RequestAcceptAbsoluteReward(week_num, reward_map[index])
            return 1
        else
            my_btn:SetUserValue("REWARD_INDEX", index - 1)
            return 1
        end
        return 1
    end
    return 0
end
-- スキル錬成のスロットにツールチップ
function Mini_addons_COMMON_SKILL_ENCHANT_SET_GB(my_frame, my_msg)
    if g.settings.enchant_tooltip == 0 then
        return
    end
    local gb, index, argStr1, argStr2 = g.get_event_args(my_msg)
    AUTO_CAST(gb)
    local cls_list, count = GetClassList("Skill")
    for i = 1, 2 do
        local mat_slot = GET_CHILD_RECURSIVELY(gb, "mat_slot" .. index)
        local text = GET_CHILD_RECURSIVELY(gb, "mat_name" .. index)
        if text:IsVisible() == 1 then
            local icon = mat_slot:GetIcon()
            if icon then
                AUTO_CAST(mat_slot)
                mat_slot:EnableHitTest(1)
                for j = 0, count - 1 do
                    AUTO_CAST(icon)
                    local skill_cls = GetClassByIndexFromList(cls_list, j)
                    if skill_cls then
                        local skill_cls_name = skill_cls.ClassName
                        if tostring(skill_cls_name) == tostring(argStr1) then
                            local skill_id = skill_cls.ClassID
                            SET_SLOT_SKILL_BY_LEVEL(mat_slot, skill_id, tonumber(argStr2))
                            break
                        end
                    end
                end
            end
        end
    end
end
-- グループチャット機能
function Mini_addons_CHAT_GROUPLIST_SELECT_LISTTYPE_(my_frame, my_msg)
    local type = g.get_event_args(my_msg)
    if type ~= 3 then
        return
    end
    Mini_addons_CHAT_GROUPLIST_SELECT_LISTTYPE(nil)
end

function Mini_addons_CHAT_GROUPLIST_SELECT_LISTTYPE(mini_addons)
    local chat_grouplist = ui.GetFrame("chat_grouplist")
    local listbtn_group = GET_CHILD_RECURSIVELY(chat_grouplist, "listbtn_group")
    local group_str = string.gsub(listbtn_group:GetText(), "{@st66b}", "")
    if not g.settings.group_caption then
        g.settings.group_caption = group_str
        Mini_addons_save_settings()
    end
    local chatlist_group = GET_CHILD_RECURSIVELY(chat_grouplist, "chatlist_group")
    local child_count = chatlist_group:GetChildCount()
    local delete_ids = {}
    for room_id, _ in pairs(g.settings.new_groups) do
        delete_ids[room_id] = true
    end
    local default_name = session.chat.GetNewGroupChatDefName()
    local pattern = "%s*%d+$"
    default_name = string.gsub(default_name, pattern, "")
    local chat = ui.GetFrame("chat")
    local groups = g.settings.new_groups
    if not groups then
        return
    end
    local changed = false
    local index = 1
    for i = 0, child_count - 1 do
        local child = chatlist_group:GetChildByIndex(i)
        local child_name = child:GetName()
        if string.find(child_name, "btn_") then
            local room_id = string.gsub(child_name, "btn_", "")
            if delete_ids[room_id] then
                delete_ids[room_id] = nil
            end
            local info = session.chat.GetByStringID(room_id)
            local title = GET_CHILD(child, "title")
            AUTO_CAST(title)
            local title_text = title:GetText()
            title_text = string.gsub(title_text, "%s*%[.-%]", "")
            local def_name = string.gsub(session.chat.GetNewGroupChatDefName(), "%s*%d+$", "")
            if string.find(title_text, def_name) then
                title_text = def_name .. index
                index = index + 1
            end
            local text = GET_CHILD_RECURSIVELY(child, "text")
            AUTO_CAST(text)
            local text_str = text:GetText()
            local color_code = "ffffff"
            if mini_addons and not text_str then
                return 1
            end
            if not string.find(text_str, "%{img ") then
                color_code = string.match(text_str, "%{#(%x+)%}")
            end
            if mini_addons and not color_code then
                return 1
            end
            if not groups[room_id] then
                groups[room_id] = {
                    name = title_text,
                    color = color_code,
                    room_id = room_id,
                    now = 0
                }
                changed = true
            end
            local name = groups[room_id].name
            title_text = ScpArgMsg("GroupChatTitleWithMemCnt", "Text", name, "Cnt", tostring(info:GetMemberCount()))
            title:SetText(title_text)
        end
    end
    if next(delete_ids) then
        for delete_room_id, _ in pairs(delete_ids) do
            g.settings.new_groups[delete_room_id] = nil
            changed = true
        end
    end
    if changed then
        Mini_addons_save_settings()
    end
    local is_start = chat_grouplist:GetUserValue("IS_START")
    if is_start == "None" then
        local active_room_id = ""
        for room_id, data in pairs(g.settings.new_groups) do
            active_room_id = room_id
            if data.now == 1 then
                active_room_id = room_id
                break
            end
        end
        Mini_addons_group_chat_setting(chat, active_room_id)
        chat_grouplist:SetUserValue("IS_START", "start")
    end
    local selected_chat_str = chat:GetUserValue("CHAT_TYPE_SELECTED_VALUE")
    local selected_chat_num = 0
    if selected_chat_str then
        if selected_chat_str == "None" then
            chat:SetUserValue("CHAT_TYPE_SELECTED_VALUE", "0")
        else
            selected_chat_num = tonumber(selected_chat_str) - 1
        end
        ui.SetChatType(selected_chat_num)
    end
    return 0
end

function Mini_addons_CHAT_GROUPLIST_OPTION_OK()
    local chat_grouplist_option = ui.GetFrame("chat_grouplist_option")
    local room_id = chat_grouplist_option:GetUserValue("ROOMID")
    local info = session.chat.GetByStringID(room_id)
    if not info then
        return
    end
    if info:GetRoomType() ~= 3 then
        return
    end
    local color_num = tonumber(chat_grouplist_option:GetUserValue("SelectedColor"))
    if color_num == 0 then
        local vmark = GET_CHILD_RECURSIVELY(chat_grouplist_option, "vmark")
        local x = vmark:GetX()
        color_num = x / 25 + 100
    end
    local color_cls = GetClassByType("ChatColorStyle", color_num)
    if color_cls then
        g.settings.new_groups[room_id].color = color_cls.TextColor
    end
    local groupname_edit = GET_CHILD_RECURSIVELY(chat_grouplist_option, "groupname_edit")
    local new_title = groupname_edit:GetText()
    g.settings.new_groups[room_id].name = new_title
    Mini_addons_now_chat_setting(room_id)
    Mini_addons_save_settings()
    CHAT_GROUPLIST_SELECT_LISTTYPE(3)
end

function Mini_addons_now_chat_setting(target_id)
    local target_group = g.settings.new_groups[target_id]
    if target_group and target_group.now ~= 1 then
        g.settings.new_groups[target_id].now = 1
        for room_id, data in pairs(g.settings.new_groups) do
            if room_id ~= target_id then
                data.now = 0
            end
        end
        Mini_addons_save_settings()
    end
end

function Mini_addons_group_chat_setting(chat, target_id)
    local group_data = g.settings.new_groups[target_id]
    if not group_data then
        return
    end
    local chat = ui.GetFrame("chat")
    AUTO_CAST(chat)
    local mainchat = chat:GetChild("mainchat")
    AUTO_CAST(mainchat)
    local edit_bg = GET_CHILD(chat, "edit_bg")
    AUTO_CAST(edit_bg)
    local button_type = GET_CHILD(chat, "button_type")
    AUTO_CAST(button_type)
    local edit_to_bg = GET_CHILD(chat, "edit_to_bg")
    AUTO_CAST(edit_to_bg)
    local title_to = GET_CHILD(edit_to_bg, "title_to")
    AUTO_CAST(title_to)
    ui.SetGroupChatTargetID(target_id)
    local btn_text = g.settings.group_caption
    local color = "{#" .. group_data.color .. "}"
    btn_text = color .. btn_text
    button_type:SetText("{ol}{s18}" .. color .. btn_text)
    local color_tone = "FF" .. group_data.color
    title_to:SetText(group_data.name)
    title_to:SetColorTone(color_tone)
    button_type:SetColorTone(color_tone)
    edit_to_bg:SetSkinName("bg")
    edit_to_bg:SetOffset(button_type:GetOriginalWidth(), edit_to_bg:GetOriginalY())
    local offset_x = button_type:GetOriginalWidth()
    title_to:SetEventScript(ui.LBUTTONUP, "Mini_addons_chat_group_context")
    title_to:SetEventScriptArgString(ui.LBUTTONUP, group_data.name)
    edit_to_bg:Resize(title_to:GetWidth() + 20, edit_to_bg:GetOriginalHeight())
    edit_to_bg:SetVisible(1)
    offset_x = offset_x + edit_to_bg:GetWidth()
    local width = mainchat:GetOriginalWidth() - edit_to_bg:GetWidth() - button_type:GetWidth()
    mainchat:Resize(width, mainchat:GetOriginalHeight())
    mainchat:SetOffset(offset_x, mainchat:GetOriginalY())
end

function Mini_addons_CHAT_SET_TO_TITLENAME_(chat)
    local target_id = chat:GetUserValue("ROOM_ID")
    Mini_addons_now_chat_setting(target_id)
    Mini_addons_group_chat_setting(chat, target_id)
end

function Mini_addons_CHAT_SET_TO_TITLENAME(my_frame, my_msg)
    local chat_type, target_id = g.get_event_args(my_msg) -- グルチャはchat_type=5 強調も何故か5
    local chat = ui.GetFrame("chat")
    local edit_to_bg = GET_CHILD(chat, "edit_to_bg")
    local title_to = GET_CHILD(edit_to_bg, "title_to")
    AUTO_CAST(title_to)
    if string.find(title_to:GetText(), "To.") then
        title_to:SetFontName("white_16_ol")
        title_to:SetColorTone("FFFFFFFF")
        edit_to_bg:SetSkinName("bg")
        title_to:SetEventScript(ui.LBUTTONUP, "")
        title_to:SetEventScriptArgString(ui.LBUTTONUP, "None")
        return
    end
    if chat_type ~= 5 then
        return
    end
    local selected_chat_str = chat:GetUserValue("CHAT_TYPE_SELECTED_VALUE")
    if selected_chat_str ~= "5" then
        return
    end
    local group_data = g.settings.new_groups[target_id]
    if not group_data or not next(group_data) then
        return
    end
    title_to:SetEventScript(ui.LBUTTONUP, "Mini_addons_chat_group_context")
    title_to:SetEventScriptArgString(ui.LBUTTONUP, group_data.name)
    chat:SetUserValue("ROOM_ID", target_id)
    edit_to_bg:SetVisible(0)
    chat:RunUpdateScript("Mini_addons_CHAT_SET_TO_TITLENAME_", 0.05)
end

function Mini_addons_change_title_name(target_id)
    local chat = ui.GetFrame("chat")
    Mini_addons_now_chat_setting(target_id)
    Mini_addons_group_chat_setting(chat, target_id)
end

function Mini_addons_chat_group_context(parent, title_to, target_name, num)
    local context = ui.CreateContextMenu("select_group", "{ol}GROUP SELECT", 0, 0, 0, 0)
    for room_id, data in pairs(g.settings.new_groups) do
        local color = data.color
        color = "{#" .. data.color .. "}"
        local name = data.name
        if name ~= target_name then
            local scp = string.format("Mini_addons_change_title_name('%s')", room_id)
            ui.AddContextMenuItem(context, color .. name, scp)
        end
    end
    ui.OpenContextMenu(context)
end
-- ボスレランキング ここから
local base_jobids = {1001, 2001, 3001, 4001, 5001}
local processed_job_ids = {}
local result_tbl = {}
local existing_data_check = {}
local start_time = 0
function Mini_addons_INDUNINFO_UI_CLOSE()
    local induninfo = ui.GetFrame("induninfo")
    local rankListBox = GET_CHILD_RECURSIVELY(induninfo, "rankListBox")
    AUTO_CAST(rankListBox)
    if rankListBox:HaveUpdateScript("Mini_addons_get_weekly_boss_data") == false then
        return
    end
    rankListBox:StopUpdateScript("Mini_addons_get_weekly_boss_data")
    rankListBox:StopUpdateScript("Mini_addons_get_weekly_boss_damage")
    local induninfo_class_selector = ui.GetFrame("induninfo_class_selector")
    induninfo_class_selector:SetEnable(1)
    local msg = g.lang == "Japanese" and
                    "データ取得処理を終了します{nl}データは保存出来ていません" or
                    "Data acquisition process terminated{nl}The data could not be saved"
    imcAddOn.BroadMsg("NOTICE_Dm_!", msg, 3.0)
end

function Mini_addons_WEEKLYBOSS_PATTERNINFO_UI_UPDATE(frame, msg, str, num)
    if g.settings.boss_rank == 0 then
        return
    end
    local induninfo = ui.GetFrame("induninfo")
    local rank_gb = GET_CHILD_RECURSIVELY(induninfo, "rank_gb")
    local data_btn = rank_gb:CreateOrGetControl("button", "data_btn", -4, 300, 52, 52)
    AUTO_CAST(data_btn)
    data_btn:SetSkinName("None")
    data_btn:SetText("{img indun_season_tap 52 52}")
    local tooltip = g.lang == "Japanese" and "{ol}データ取得" or "{ol}Data Acquisition"
    data_btn:SetTextTooltip(tooltip)
    local data_btn_text = data_btn:CreateOrGetControl("richtext", "data_btn_text", 10, 15, 0, 20)
    AUTO_CAST(data_btn_text)
    data_btn_text:SetText("{ol}data")
    data_btn_text:SetTextTooltip(tooltip)
    data_btn_text:SetEventScript(ui.LBUTTONUP, "Mini_addons_get_weekly_boss_data_context")
    data_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_get_weekly_boss_data_context")
    local rank_btn = rank_gb:CreateOrGetControl("button", "rank_btn", -4, 354, 52, 52)
    AUTO_CAST(rank_btn)
    rank_btn:SetSkinName("None")
    rank_btn:SetText("{img indun_season_tap 52 52}") -- tab2
    local tooltip = g.lang == "Japanese" and "{ol}ランキング表示" or "{ol}Show Leaderboard"
    rank_btn:SetTextTooltip(tooltip)
    local rank_btn_text = rank_btn:CreateOrGetControl("richtext", "rank_btn_text", 10, 15, 0, 20)
    AUTO_CAST(rank_btn_text)
    rank_btn_text:SetText("{ol}rank")
    rank_btn_text:SetTextTooltip(tooltip)
    rank_btn_text:SetEventScript(ui.LBUTTONUP, "Mini_addons_create_ranking_data")
    rank_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_create_ranking_data")
end

function Mini_addons_create_ranking_data()
    local induninfo = ui.GetFrame("induninfo")
    local file_path = string.format("../addons/%s/log.dat", addon_name_lower)
    local log_data = g.load_dat(file_path)
    if not log_data then
        local msg = g.lang == "Japanese" and
                        "ランキングデータが未取得です{nl}ランキングデータを取得してください" or
                        "Ranking data has not been acquired{nl}Please acquire the ranking data"
        ui.SysMsg(msg)
        return
    end
    local week_num = session.weeklyboss.GetNowWeekNum()
    local season_tab = GET_CHILD_RECURSIVELY(induninfo, "season_tab")
    local season_index = season_tab:GetSelectItemIndex()
    local season = week_num - season_index
    local is_save = true
    local checked_jobs = {}
    local all_derived_jobs = {}
    local function get_base_jobid_local(job_cls_id)
        if not job_cls_id then
            return nil
        end
        return job_cls_id - (job_cls_id % 1000) + 1
    end
    for _, base_id in ipairs(base_jobids) do
        local job_list = GET_JOB_LIST(base_id)
        for _, job_cls in ipairs(job_list) do
            local job_id = TryGetProp(job_cls, "ClassID", 0)
            if job_id ~= 0 and job_id % 100 ~= 1 then
                all_derived_jobs[job_id] = false -- チェックリストをfalseで初期化
            end
        end
    end
    for _, record in ipairs(log_data) do
        local week_num_ = tonumber(record[1])
        if week_num_ == season then
            local job_id = tonumber(record[2])
            local is_confirmed_str = record[7]
            if is_confirmed_str == "false" then
                is_save = false
                break
            end
            if all_derived_jobs[job_id] ~= nil then
                all_derived_jobs[job_id] = true
            end
        end
    end
    if is_save then
        for job_id, checked in pairs(all_derived_jobs) do
            if not checked then
                is_save = false
                break
            end
        end
    end
    local player_data = {}
    for _, record in ipairs(log_data) do
        local week_num_ = tonumber(record[1])
        if week_num_ == season then
            local job_id = tonumber(record[2])
            local name = record[4]
            local damage = tonumber(record[5])
            if not player_data[name] then
                player_data[name] = {
                    all_jobs = {},
                    max_damage = 0
                }
            end
            if #player_data[name].all_jobs < 4 then
                local found = false
                for _, existing_id in ipairs(player_data[name].all_jobs) do
                    if existing_id == job_id then
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(player_data[name].all_jobs, job_id)
                end
            end
            if damage > player_data[name].max_damage then
                player_data[name].max_damage = damage
            end
        end
    end
    local ranking_list = {}
    for name, data in pairs(player_data) do
        table.insert(ranking_list, {
            name = name,
            damage = data.max_damage,
            all_jobs = data.all_jobs
        })
    end
    table.sort(ranking_list, function(a, b)
        return a.damage > b.damage
    end)
    local display_data_list = {}
    for i, data in ipairs(ranking_list) do
        if i > 100 then
            break
        end
        local base_job_id = nil
        local derived_jobs = {}
        local base_id_counts = {}
        for _, job_id in ipairs(data.all_jobs) do
            if job_id % 100 == 1 then
                base_job_id = job_id
            else
                table.insert(derived_jobs, job_id)
                local b_id = get_base_jobid_local(job_id)
                if b_id then
                    base_id_counts[b_id] = (base_id_counts[b_id] or 0) + 1
                end
            end
        end
        if not base_job_id and #derived_jobs > 0 then
            local max_count = 0
            for b_id, count in pairs(base_id_counts) do
                if count > max_count then
                    max_count = count
                    base_job_id = b_id
                end
            end
        end
        local build_parts = {}
        if base_job_id then
            table.insert(build_parts, base_job_id)
        end
        for _, job_id in ipairs(derived_jobs) do
            table.insert(build_parts, job_id)
        end
        table.insert(display_data_list, {
            season = season,
            rank = i,
            name = data.name,
            damage = data.damage,
            build = build_parts
        })
        local build_str = table.concat(build_parts, ", ")
    end
    Mini_addons_create_ranking_data_frame(display_data_list, is_save)
end

-- ESC 用の入口。理由は Mini_addons_setting_ESCAPE_PRESSED と同じ。
function Mini_addons_ranking_ESCAPE_PRESSED()
    local rank_frame = ui.GetFrame(addon_name_lower .. "rank_frame")
    if rank_frame then
        Mini_addons_ranking_close(rank_frame)
    end
end

function Mini_addons_ranking_close(frame)
    local frame_name = frame:GetName()
    ui.DestroyFrame(frame_name)
end

function Mini_addons_create_ranking_data_frame(ranking_data, is_save)
    if not ranking_data or #ranking_data == 0 then
        local msg = g.lang == "Japanese" and
                        "ランキングデータが未取得です{nl}ランキングデータを取得してください" or
                        "Ranking data has not been acquired{nl}Please acquire the ranking data"
        ui.SysMsg(msg)
        return
    end
    local induninfo = ui.GetFrame("induninfo")
    local rank_frame = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "rank_frame", 0, 0, 0, 0)
    AUTO_CAST(rank_frame)
    rank_frame:SetSkinName("test_frame_low")
    rank_frame:SetLayerLevel(102)
    rank_frame:EnableHittestFrame(1)
    -- 上流は EnableMove を呼んでおらず動かせなかったので P 側で足した
    -- (位置の保存はしないため、開き直すと既定位置に戻る)
    rank_frame:EnableMove(1)
    rank_frame:ShowTitleBar(0)
    rank_frame:RemoveAllChild()
    local season = ranking_data[1].season
    local status_text = ""
    if is_save == false then
        status_text = " (Unconfirmed)"
    else
        status_text = " (Confirmed)"
    end
    local title = rank_frame:CreateOrGetControl("richtext", "title", 30, 10)
    AUTO_CAST(title)
    title:SetText("{@st66b18}Weekly Ranking [" .. season .. "] week" .. status_text)
    local gbox = rank_frame:CreateOrGetControl("groupbox", "gbox", 10, 30, 0, 0)
    AUTO_CAST(gbox)
    gbox:SetSkinName("bg")
    local close = rank_frame:CreateOrGetControl("button", "close", 0, 0, 30, 30)
    AUTO_CAST(close)
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetImage("testclose_button")
    close:SetEventScript(ui.LBUTTONUP, "Mini_addons_ranking_close")
    local y = 10
    local max_rank_width = 0
    local max_name_width = 0
    local max_damage_width = 0
    local temp_rank_text = gbox:CreateOrGetControl("richtext", "temp_rank", 0, 0)
    temp_rank_text:SetText("100.")
    max_rank_width = temp_rank_text:GetWidth()
    temp_rank_text:ShowWindow(0)
    for i, data in ipairs(ranking_data) do
        local temp_name_text = gbox:CreateOrGetControl("richtext", "temp_name_" .. i, 0, 0)
        temp_name_text:SetText("{ol}" .. data.name)
        if temp_name_text:GetWidth() > max_name_width then
            max_name_width = temp_name_text:GetWidth()
        end
        temp_name_text:ShowWindow(0)
        local temp_damage_text = gbox:CreateOrGetControl("richtext", "temp_damage_" .. i, 0, 0)
        temp_damage_text:SetText(string.format("Damage: %d", data.damage))
        if temp_damage_text:GetWidth() > max_damage_width then
            max_damage_width = temp_damage_text:GetWidth()
        end
        temp_damage_text:ShowWindow(0)
    end
    local rank_col_x = 10
    local name_col_x = rank_col_x + max_rank_width
    local icon_col_x = name_col_x + max_name_width
    local damage_col_x = icon_col_x + (4 * 25) - 10
    for i, data in ipairs(ranking_data) do
        local rank_text = gbox:CreateOrGetControl("richtext", "rank_" .. i, rank_col_x, y)
        AUTO_CAST(rank_text)
        rank_text:SetText("{ol}" .. string.format("%d.", data.rank))
        local name_text = gbox:CreateOrGetControl("richtext", "name_" .. i, name_col_x, y)
        AUTO_CAST(name_text)
        name_text:SetText("{ol}" .. data.name)
        local icon_x = icon_col_x
        for j, job_id in ipairs(data.build) do
            if j > 4 then
                break
            end
            local job_cls = GetClassByType("Job", job_id)
            if job_cls then
                local job_icon = gbox:CreateOrGetControl("picture", "job_icon_" .. i .. "_" .. j, icon_x, y - 5, 25, 25)
                AUTO_CAST(job_icon)
                job_icon:SetImage(job_cls.Icon)
                job_icon:SetEnableStretch(1)
                job_icon:EnableHitTest(1)
                job_icon:SetTooltipType("adventure_book_job_info")
                job_icon:SetTooltipArg(job_id, 0, 0)
                icon_x = icon_x + 25
            end
        end
        local damage_text = gbox:CreateOrGetControl("richtext", "damage_" .. i, damage_col_x, y)
        AUTO_CAST(damage_text)
        damage_text:SetText("{ol}" .. GET_COMMAED_STRING(data.damage))
        local text_width = damage_text:GetWidth()
        local centered_x = damage_col_x + (max_damage_width - text_width) / 2
        damage_text:SetPos(centered_x, y)
        y = y + 30
    end
    local max_x = damage_col_x + max_damage_width
    rank_frame:SetPos(induninfo:GetX() + 20, induninfo:GetY() + 20)
    rank_frame:Resize(max_x + 20, 550)
    gbox:Resize(rank_frame:GetWidth() - 20, rank_frame:GetHeight() - 40)
    gbox:EnableScrollBar(1)
    gbox:SetScrollPos(0)
    rank_frame:ShowWindow(1)
    core_g.esc_register(addon_name_lower .. "rank_frame", "Mini_addons_ranking_ESCAPE_PRESSED")
end

function Mini_addons_get_weekly_boss_data_context(frame, ctrl, str, num)
    local context = ui.CreateContextMenu("weekly_boss_data", "{ol}WEEKLY BOSS DATA", 0, 0, 0, 0)
    ui.AddContextMenuItem(context, "four weeks", "None")
    for i = 1, #base_jobids do
        local scp = string.format("Mini_addons_get_weekly_boss_data_reserve(%d, 1)", base_jobids[i])
        local job_cls = GetClassByType("Job", base_jobids[i])
        ui.AddContextMenuItem(context, job_cls.Name .. " (Data takes about 120 sec)", scp)
    end
    local scp_all_four = string.format("Mini_addons_get_weekly_boss_data_reserve(1, 1)")
    ui.AddContextMenuItem(context, "data for all classes (Data takes about 600 sec)", scp_all_four)
    ui.AddContextMenuItem(context, "This week", "None")
    for i = 1, #base_jobids do
        local scp = string.format("Mini_addons_get_weekly_boss_data_reserve(%d, 0)", base_jobids[i])
        local job_cls = GetClassByType("Job", base_jobids[i])
        ui.AddContextMenuItem(context, job_cls.Name .. " (Data takes about 30 sec)", scp)
    end
    local scp_all_this = string.format("Mini_addons_get_weekly_boss_data_reserve(0, 0)")
    ui.AddContextMenuItem(context, "data for all classes (Data takes about 150 sec)", scp_all_this)
    ui.OpenContextMenu(context)
end

function Mini_addons_save_log()
    local file_path = string.format("../addons/%s/log.dat", addon_name_lower)
    local existing_records = g.load_dat(file_path) or {}
    local new_records_check = {}
    for _, new_record in ipairs(result_tbl) do
        local week_str = tostring(new_record[1])
        local job_id_str = tostring(new_record[2])
        if not new_records_check[week_str] then
            new_records_check[week_str] = {}
        end
        new_records_check[week_str][job_id_str] = true
    end
    local final_records_to_save = {}
    if #existing_records > 0 then
        for _, old_record in ipairs(existing_records) do
            local old_week_str, old_job_id_str = old_record[1], old_record[2]
            if not (new_records_check[old_week_str] and new_records_check[old_week_str][old_job_id_str]) then
                table.insert(final_records_to_save, old_record)
            end
        end
    end
    for _, new_record in ipairs(result_tbl) do
        table.insert(final_records_to_save, new_record)
    end
    local lines_to_write = {}
    for _, record in ipairs(final_records_to_save) do
        table.insert(lines_to_write, table.concat(record, ":::"))
    end
    local content_to_write = table.concat(lines_to_write, "\n")
    local file = io.open(file_path, "w")
    if file then
        file:write(content_to_write)
        file:close()
    end
end

function Mini_addons_get_weekly_boss_data_reserve(base_job_id, is_four_weeks)
    result_tbl = {}
    processed_job_ids = {}
    local induninfo = ui.GetFrame("induninfo")
    local rankListBox = GET_CHILD_RECURSIVELY(induninfo, "rankListBox")
    AUTO_CAST(rankListBox)
    rankListBox:SetUserValue("MODE_BASE_ID", base_job_id)
    rankListBox:SetUserValue("MODE_IS_4W", is_four_weeks)
    rankListBox:SetUserValue("B_IDX", 1)
    rankListBox:SetUserValue("C_IDX", 1)
    rankListBox:SetUserValue("W_IDX", 0)
    rankListBox:SetUserValue("SHOULD_SAVE", 0)
    local classtype_tab = GET_CHILD_RECURSIVELY(induninfo, "classtype_tab")
    classtype_tab:SelectTab(0)
    start_time = os.clock()
    local file_path = string.format("../addons/%s/log.dat", addon_name_lower)
    local loaded_data = g.load_dat(file_path)
    if loaded_data then
        for _, record in ipairs(loaded_data) do
            local week_str = record[1]
            local job_id_str = record[2]
            local is_confirmed_str = record[7]
            if is_confirmed_str == "true" then
                processed_job_ids[week_str .. job_id_str] = true
            end
        end
    end
    local induninfo_class_selector = ui.GetFrame("induninfo_class_selector")
    induninfo_class_selector:SetEnable(0)
    local msg = g.lang == "Japanese" and
                    "データ取得を開始します{nl}フレームを閉じずに暫くお待ちください" or
                    "Starting data acquisition{nl}Please wait a moment without closing the frame"
    imcAddOn.BroadMsg("NOTICE_Dm_!", msg, 3.0)
    Mini_addons_get_weekly_boss_data(rankListBox)
    rankListBox:RunUpdateScript("Mini_addons_get_weekly_boss_data", 1.2)
end

function Mini_addons_get_weekly_boss_data(rankListBox)
    local mode_base_id = rankListBox:GetUserIValue("MODE_BASE_ID")
    local mode_is_4w = rankListBox:GetUserIValue("MODE_IS_4W")
    local b_idx = rankListBox:GetUserIValue("B_IDX")
    local c_idx = rankListBox:GetUserIValue("C_IDX")
    local w_idx = rankListBox:GetUserIValue("W_IDX")
    if w_idx == 0 and b_idx == 1 and c_idx == 1 then
        local induninfo = ui.GetFrame("induninfo")
        local season_tab = GET_CHILD_RECURSIVELY(induninfo, "season_tab")
        season_tab:SelectTab(0)
        rankListBox:SetUserValue("CURRENT_WEEK_NUM", WEEKLY_BOSS_RANK_WEEKNUM_NUMBER())
    end
    local current_week_num = rankListBox:GetUserIValue("CURRENT_WEEK_NUM")
    local target_base_jobids
    local is_all_classes_mode = false
    if mode_base_id == 0 or mode_base_id == 1 then
        target_base_jobids = base_jobids
        is_all_classes_mode = true
    else
        target_base_jobids = {mode_base_id}
    end
    local num_weeks = (mode_base_id == 1 or mode_is_4w == 1) and 4 or 1
    if w_idx >= num_weeks then
        local induninfo_class_selector = ui.GetFrame("induninfo_class_selector")
        if induninfo_class_selector:IsVisible() == 1 then
            local classList = GET_CHILD_RECURSIVELY(induninfo_class_selector, "classList")
            if classList then
                AUTO_CAST(classList)
                classList:SetScrollPos(0)
            end
            INDUNINFO_CLASS_SELECTOR_UI_CLOSE(induninfo_class_selector)
        end
        induninfo_class_selector:SetEnable(1)
        local end_time = os.clock()
        local elapsed_time = end_time - start_time
        local msg = g.lang == "Japanese" and
                        string.format("処理が完了しました。所要時間: %.2f 秒", elapsed_time) or
                        string.format("The process is complete. Time elapsed: %.2f seconds", elapsed_time)
        ui.SysMsg(msg)
        return 0
    end
    local current_base_jobid = target_base_jobids[b_idx]
    local job_list = GET_JOB_LIST(current_base_jobid)
    local job_cls = job_list[c_idx]
    local next_b_idx, next_c_idx, next_w_idx = b_idx, c_idx + 1, w_idx
    local should_save_flag = 0
    if next_c_idx > #job_list then
        next_c_idx = 1
        next_b_idx = b_idx + 1
        if is_all_classes_mode then
            should_save_flag = 1
        end
    end
    if next_b_idx > #target_base_jobids then
        next_b_idx = 1
        next_c_idx = 1
        next_w_idx = w_idx + 1
        if not is_all_classes_mode then
            should_save_flag = 1
        end
    end
    if job_cls then
        local job_cls_id = TryGetProp(job_cls, "ClassID", 0)
        local week_offset = (num_weeks == 4) and (3 - w_idx) or 0
        local week_num = current_week_num - week_offset
        local key_to_check = tostring(week_num) .. tostring(job_cls_id)
        if job_cls_id ~= 0 and not processed_job_ids[key_to_check] then
            local induninfo = ui.GetFrame("induninfo")
            local induninfo_class_selector = ui.GetFrame("induninfo_class_selector")
            ui.OpenFrame("induninfo_class_selector")
            local season_tab = GET_CHILD_RECURSIVELY(induninfo, "season_tab")
            season_tab:SelectTab(week_offset)
            local classtype_tab = GET_CHILD_RECURSIVELY(induninfo, "classtype_tab")
            for k = 1, #base_jobids do
                if base_jobids[k] == current_base_jobid then
                    classtype_tab:SelectTab(k - 1)
                    break
                end
            end
            INDUNINFO_CLASS_SELECTOR_FILL_CLASS(current_base_jobid)
            weekly_boss.RequestWeeklyBossRankingInfoList(week_num, job_cls_id)
            local classList = GET_CHILD_RECURSIVELY(induninfo_class_selector, "classList")
            AUTO_CAST(classList)
            local pos = 0
            if c_idx > 18 then
                pos = 180
            elseif c_idx > 12 then
                pos = 120
            elseif c_idx > 6 then
                pos = 60
            end
            classList:SetScrollPos(pos)
            for i = 1, #job_list do
                local list_job = GET_CHILD_RECURSIVELY(induninfo_class_selector, "list_job_" .. i)
                if list_job then
                    local icon = GET_CHILD(list_job, "icon_pic")
                    if icon then
                        AUTO_CAST(icon)
                        if i == c_idx then
                            icon:SetColorTone("FFFFFFFF")
                        else
                            icon:SetColorTone("FF444444")
                        end
                    end
                end
            end
            rankListBox:SetUserValue("JOB_ID", job_cls_id)
            rankListBox:SetUserValue("WEEK_NUM", week_num)
            rankListBox:SetUserValue("SHOULD_SAVE", should_save_flag)
            rankListBox:RunUpdateScript("Mini_addons_get_weekly_boss_damage", 0.2)
            processed_job_ids[key_to_check] = true
            rankListBox:SetUserValue("B_IDX", next_b_idx)
            rankListBox:SetUserValue("C_IDX", next_c_idx)
            rankListBox:SetUserValue("W_IDX", next_w_idx)
            rankListBox:StopUpdateScript("Mini_addons_get_weekly_boss_data")
            rankListBox:RunUpdateScript("Mini_addons_get_weekly_boss_data", 1.2)
            return 0
        end
    end
    rankListBox:SetUserValue("B_IDX", next_b_idx)
    rankListBox:SetUserValue("C_IDX", next_c_idx)
    rankListBox:SetUserValue("W_IDX", next_w_idx)
    rankListBox:StopUpdateScript("Mini_addons_get_weekly_boss_data")
    rankListBox:RunUpdateScript("Mini_addons_get_weekly_boss_data", 0)
    return 0
end

function Mini_addons_get_weekly_boss_damage(rankListBox)
    local induninfo = ui.GetFrame("induninfo")
    local rankListBox = GET_CHILD_RECURSIVELY(induninfo, "rankListBox")
    AUTO_CAST(rankListBox)
    local job_id = rankListBox:GetUserValue("JOB_ID")
    local week_num = tonumber(rankListBox:GetUserValue("WEEK_NUM"))
    if not job_id or not week_num then
        return 0
    end
    local current_week_num = tonumber(rankListBox:GetUserIValue("CURRENT_WEEK_NUM"))
    local is_confirmed = (week_num < current_week_num) and "true" or "false"
    for i = 1, 20 do
        local ctrlset = GET_CHILD(rankListBox, "CTRLSET_" .. i)
        if ctrlset then
            AUTO_CAST(ctrlset)
            local name_ctrl = GET_CHILD(ctrlset, "attr_name_text", "ui::CRichText")
            local name = name_ctrl:GetTextByKey("value")
            local damage = session.weeklyboss.GetRankInfoDamage(i - 1)
            damage = string.gsub(damage, ",", "")
            damage = tonumber(damage)
            local job_cls = GetClassByType("Job", tonumber(job_id))
            local job_name = dic.getTranslatedStr(job_cls.Name)
            local msg = g.lang == "Japanese" and job_name .. " データを取得しました" or job_name ..
                            " Data obtained"
            imcAddOn.BroadMsg("NOTICE_Dm_quest_complete", msg, 1.2)
            local result_data = {week_num, job_id, i, name, damage, job_name, is_confirmed}
            table.insert(result_tbl, result_data)
        else
            if i == 1 then
                local job_cls = GetClassByType("Job", tonumber(job_id))
                local job_name = dic.getTranslatedStr(job_cls.Name)
                local result_data = {week_num, job_id, i, "None", "0", job_name, is_confirmed}
                table.insert(result_tbl, result_data)
            end
            break
        end
    end
    if rankListBox:GetUserIValue("SHOULD_SAVE") == 1 then
        local base_id = tonumber(job_id) - (tonumber(job_id) % 1000) + 1
        local job_cls = GetClassByType("Job", tonumber(base_id))
        local job_name = dic.getTranslatedStr(job_cls.Name)
        local msg = g.lang == "Japanese" and "[" .. week_num .. "] 週の " .. job_name ..
                        " クラスのデータを保存しました" or "Saved data for the [" .. week_num ..
                        "] week's " .. job_name .. " class"
        ui.SysMsg(msg)
        Mini_addons_save_log()
        rankListBox:SetUserValue("SHOULD_SAVE", 0)
    end
    return 0
end

function Mini_addons_rebuild_log_file(induninfo)
    local file_path = string.format("../addons/%s/log.dat", addon_name_lower)
    local log_data = g.load_dat(file_path)
    if not log_data then
        return 0
    end
    local classtype_tab = GET_CHILD_RECURSIVELY(induninfo, "classtype_tab")
    AUTO_CAST(classtype_tab)
    local cls_index = classtype_tab:GetSelectItemIndex()
    local base_job = base_jobids[cls_index + 1]
    local week_num = session.weeklyboss.GetNowWeekNum()
    local season_tab = GET_CHILD_RECURSIVELY(induninfo, "season_tab")
    AUTO_CAST(season_tab)
    local season_index = season_tab:GetSelectItemIndex()
    local season = week_num - season_index
    local rebuilt_table = {}
    for _, record in ipairs(log_data) do
        local week_num_ = tonumber(record[1])
        local job_id = tonumber(record[2])
        local name = record[4]
        if week_num_ == season and (job_id > base_job and job_id < base_job + 1000) then
            if not rebuilt_table[name] then
                rebuilt_table[name] = {}
            end
            table.insert(rebuilt_table[name], job_id)
        end
    end
    local rankListBox = GET_CHILD_RECURSIVELY(induninfo, "rankListBox")
    AUTO_CAST(rankListBox)
    for i = 1, 20 do
        local ctrlset = GET_CHILD(rankListBox, "CTRLSET_" .. i)
        if ctrlset then
            AUTO_CAST(ctrlset)
            local attr_name_text = GET_CHILD(ctrlset, "attr_name_text")
            if attr_name_text then
                AUTO_CAST(attr_name_text)
                local raw_name = attr_name_text:GetText()
                local job_ids = rebuilt_table[raw_name]
                for j = 1, 3 do
                    local icon = GET_CHILD(ctrlset, "job_icon" .. j)
                    if icon then
                        icon:ShowWindow(0)
                    end
                end
                local nodata = GET_CHILD(ctrlset, "nodata_" .. i)
                if nodata then
                    nodata:ShowWindow(0)
                end
                if job_ids then
                    local rect = attr_name_text:GetMargin()
                    attr_name_text:SetMargin(rect.left, rect.top + 4, rect.right, rect.bottom)
                    for j = 1, 3 do
                        local job_id = job_ids[j]
                        if job_id then
                            local job_cls = GetClassByType("Job", job_id)
                            if job_cls then
                                local job_icon = ctrlset:CreateOrGetControl("picture", "job_icon" .. j,
                                    (attr_name_text:GetWidth() + ((j - 1) * 30)), 5, 30, 30)
                                AUTO_CAST(job_icon)
                                job_icon:SetImage(job_cls.Icon)
                                job_icon:SetEnableStretch(1)
                                job_icon:EnableHitTest(1)
                                ctrlset:EnableHitTest(1)
                                job_icon:SetTooltipType("adventure_book_job_info")
                                job_icon:SetTooltipArg(job_id, 0, 0)
                                job_icon:ShowWindow(1)
                            end
                        end
                    end
                else
                    local nodata = ctrlset:CreateOrGetControl("richtext", "nodata_" .. i, attr_name_text:GetWidth(), 10,
                        30, 30)
                    AUTO_CAST(nodata)
                    nodata:SetText("{#000000}No data")
                    nodata:ShowWindow(1)
                end
            end
        end
    end
    return 0
end

function Mini_addons_WEEKLY_BOSS_RANK_UPDATE()
    if g.settings.boss_rank == 0 then
        return
    end
    local induninfo = ui.GetFrame("induninfo")
    local rankListBox = GET_CHILD_RECURSIVELY(induninfo, "rankListBox")
    AUTO_CAST(rankListBox)
    if rankListBox:HaveUpdateScript("Mini_addons_get_weekly_boss_data") == false then
        Mini_addons_rebuild_log_file(induninfo)
    end
end
-- 製造自動セット
function Mini_addons_itemcraft_item_set(item_set, slot, recipe_item_cnt_str, cls_id, current_make_count)
    imcSound.PlaySoundEvent("inven_equip")
    AUTO_CAST(slot)
    local need_count = tonumber(recipe_item_cnt_str)
    local item_name = item_set:GetUserValue("ClassName")
    local inv_item = session.GetInvItemByName(item_name)
    if true == inv_item.isLockState then
        ui.SysMsg(ClMsg("MaterialItemIsLock"))
        return 0
    end
    local next_make_count = current_make_count
    if inv_item.type == cls_id and inv_item.count >= need_count then
        local possible_count = math.floor(inv_item.count / need_count)
        if next_make_count ~= 0 then
            if next_make_count == nil or next_make_count > possible_count then
                next_make_count = possible_count
            end
        end
        session.AddItemID(inv_item:GetIESID(), need_count)
        local icon = slot:GetIcon()
        icon:SetColorTone("FFFFFFFF")
        item_set:SetUserValue("MATERIAL_IS_SELECTED", "selected")
        local number = slot:CreateOrGetControl("richtext", "number", 0, 0, slot:GetWidth(), 20)
        AUTO_CAST(number)
        number:SetText("{ol}" .. inv_item.count)
    else
        next_make_count = 0
    end
    local btn = GET_CHILD(item_set, "btn", "ui::CButton")
    if btn then
        AUTO_CAST(btn)
        btn:ShowWindow(0)
    end
    local inv_frame = ui.GetFrame("inventory")
    INVENTORY_UPDATE_ICONS(inv_frame)
    return next_make_count
end

function Mini_addons_CRAFT_RECIPE_FOCUS(frame, msg)
    if g.settings.auto_craft == 0 then
        return
    end
    local page, ctrl_set = g.get_event_args(msg)
    local make_count = nil
    for i = 1, 5 do
        local item_set = GET_CHILD(ctrl_set, "EACHMATERIALITEM_" .. i)
        if not item_set then
            break
        end
        AUTO_CAST(item_set)
        local slot = GET_CHILD(item_set, "slot")
        AUTO_CAST(slot)
        DESTROY_CHILD_BYNAME(slot, "number")
        local top_frame = page:GetTopParentFrame()
        local id_space = top_frame:GetUserValue("IDSPACE")
        local recipe_cls = GetClass(id_space, ctrl_set:GetName())
        local recipe_item_cnt, inv_item_cnt, drag_recipe_item, inv_item, recipe_item_lv, inv_item_list =
            GET_RECIPE_MATERIAL_INFO(recipe_cls, i)
        local recipe_item_cnt_str = tostring(recipe_item_cnt)
        local cls_id = drag_recipe_item.ClassID
        make_count = Mini_addons_itemcraft_item_set(item_set, slot, recipe_item_cnt_str, cls_id, make_count)
    end
    local top_frame = page:GetTopParentFrame()
    local up_down = GET_CHILD_RECURSIVELY(top_frame, "upDown", "ui::CNumUpDown")
    up_down:SetNumberValue(make_count or 0)
end

function Mini_addons_CRAFT_START_CRAFT(frame, msg)
    if g.settings.auto_craft == 0 then
        return
    end
    local item_craft = ui.GetFrame("itemcraft")
    if item_craft then
        item_craft:RunUpdateScript("CREATE_CRAFT_ARTICLE", 8.2)
    end
end
-- パーティーメンバーの場所表示
function Mini_addons_partymember_get_map()
    if g.settings.pt_info == 0 then
        return
    end
    local list = session.party.GetPartyMemberList(PARTY_NORMAL)
    local count = list:Count()
    if count == 1 then
        return
    end
    local party_info = ui.GetFrame("partyinfo")
    if not party_info then
        return
    end
    for i = 0, count - 1 do
        local party_member_info = list:Element(i)
        if party_member_info and party_member_info:GetMapID() > 0 then
            local map_cls = GetClassByType("Map", party_member_info:GetMapID())
            if map_cls then
                local party_info_ctrl_set = party_info:GetChild("PTINFO_" .. party_member_info:GetAID())
                if party_info_ctrl_set then
                    local location = party_info_ctrl_set:CreateOrGetControl("richtext", "location" .. i, 0, 0, 0, 0)
                    AUTO_CAST(location)
                    location:SetText("")
                    location:SetText(string.format("{s12}{ol}[%s-%d]", map_cls.Name, party_member_info:GetChannel() + 1))
                    location:Resize(100, 20)
                    location:SetOffset(10, 0)
                    location:ShowWindow(1)
                    local lv_box = party_info_ctrl_set:GetChild("lvbox")
                    local name_text = party_info_ctrl_set:GetChild("name_text")
                    if lv_box and name_text then
                        AUTO_CAST(lv_box)
                        AUTO_CAST(name_text)
                        local name_x = lv_box:GetX() + lv_box:GetWidth()
                        name_text:SetPos(name_x, -12)
                    end
                end
            end
        end
    end
end
-- PTメンバーの死亡と復活をNICO_CHATで流す
local last_time = 0
local cd_time = 0.5
function Mini_addons_DRAW_CHAT_MSG(my_frame, my_msg)
    if g.settings.chat_recv == 0 then
        return
    end
    local now = os.clock()
    if (now - last_time) < cd_time then
        return
    end
    local groupboxname, startindex, frame = g.get_event_args(my_msg)
    local size = session.ui.GetMsgInfoSize(groupboxname)
    local chat = session.ui.GetChatMsgInfo(groupboxname, size - 1)
    local msg_type = chat:GetMsgType()
    if msg_type ~= "Battle" then
        return
    end
    local chat_option = ui.GetFrame("chat_option")
    local resurrectCheck_party = GET_CHILD_RECURSIVELY(chat_option, "resurrectCheck_party")
    AUTO_CAST(resurrectCheck_party)
    resurrectCheck_party:SetCheck(1)
    local msg = chat:GetMsg()
    if string.find(msg, "!@#$Dead{MEMBER}$*$MEMBER$*$", 1, true) then
        local pattern = "^!@#%$Dead%{MEMBER%}%$%*%$MEMBER%$%*%$(.-)#@!$"
        local rep_msg = string.match(msg, pattern)
        if rep_msg then
            rep_msg = "[ " .. rep_msg .. " ]"
            rep_msg = g.lang == "Japanese" and rep_msg .. " が死亡" or rep_msg .. " died"
            NICO_CHAT(tostring("{ol}{#FF0000}{s40}" .. rep_msg))
        end
    elseif string.find(msg, "!@#$Resurrect{MEMBER}$*$MEMBER$*$", 1, true) then
        local pattern = "^!@#%$Resurrect{MEMBER}%$%*%$MEMBER%$%*%$(.-)#@!$"
        local rep_msg = string.match(msg, pattern)
        if rep_msg then
            rep_msg = "[ " .. rep_msg .. " ]"
            rep_msg = g.lang == "Japanese" and rep_msg .. " が復活" or rep_msg .. " revived"
            NICO_CHAT(tostring("{ol}{#00BFFF}{s40}" .. rep_msg))
        end
    end
    last_time = os.clock()
end
-- ワールドマップにトークンワープのクールダウンを表示
function Mini_addons_OPEN_WORLDMAP2_MINIMAP(my_frame, my_msg)
    local worldmap2_minimap = ui.GetFrame("worldmap2_minimap")
    Mini_addons_TOKEN_WARP_COOLDOWN(worldmap2_minimap)
    worldmap2_minimap:RunUpdateScript("Mini_addons_TOKEN_WARP_COOLDOWN", 1.0)
end

function Mini_addons_TOKEN_WARP_COOLDOWN(worldmap2_minimap)
    local minimap_token_btn = GET_CHILD_RECURSIVELY(worldmap2_minimap, "minimap_token_btn")
    AUTO_CAST(minimap_token_btn)
    local is_token_state = session.loginInfo.IsPremiumState(ITEM_TOKEN)
    local image_name = ""
    local cd = GET_TOKEN_WARP_COOLDOWN()
    if is_token_state == true and cd == 0 then
        image_name = "{img worldmap2_token_gold 38 38} {@st101lightbrown_16}"
    else
        image_name = "{img worldmap2_token_gray 38 38} {@st101lightbrown_16}"
    end
    minimap_token_btn:SetText(image_name .. ScpArgMsg("TokenWarp"))
    local cdtext = worldmap2_minimap:CreateOrGetControl("richtext", "cdtext", 50, 820)
    AUTO_CAST(cdtext)
    local minutes = math.floor(cd / 60)
    local seconds = cd % 60
    local cdtimer = string.format("%d:%02d", minutes, seconds)
    cdtext:SetText("{ol}{#FFFFFF}TokenWarp CD: " .. cdtimer)
    return 1
end
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
        if opts.drop and type(caption) == "string" and string.find(caption, opts.drop, 1, true) then
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

-- バウバスお知らせ
function Mini_addons_NOTICE_ON_MSG_baubas(frame, msg)
    local _, _, str, _ = g.get_event_args(msg)
    if g.settings.baubas_call.use ~= 1 then
        return
    end
    local name_text = dictionary.ReplaceDicIDInCompStr("@dicID_^*$ETC_20221117_069848$*^")
    if string.find(str, "AppearFieldBoss_ep14_2_d_castle_3{name}") then
        local current_time = os.time()
        if g.last_baubas_time and (current_time - g.last_baubas_time < 60) then
            return
        end
        g.last_baubas_time = current_time
        imcSound.PlaySoundEvent("sys_tp_box_4")
        local fmt = "마법 결사의 의사당에 필드 보스[{name}]가 등장하였습니다."
        local readable_str = dictionary.ReplaceDicIDInCompStr(fmt)
        local clean_str = string.gsub(readable_str, "{name}", name_text)
        NICO_CHAT(string.format("{@st55_a}%s", clean_str))
        CHAT_SYSTEM(clean_str)
        Mini_addons_NOTICE_ON_MSG_GUILD(clean_str)
    elseif string.find(str, "{name}DisappearFieldBoss") and string.find(str, "맹화의 바우바") then
        local fmt = "필드 보스[{name}]가 처치되었습니다."
        local readable_str = dictionary.ReplaceDicIDInCompStr(fmt)
        local clean_str = string.gsub(readable_str, "{name}", name_text)
        CHAT_SYSTEM(clean_str)
        Mini_addons_NOTICE_ON_MSG_GUILD(clean_str)
    end
end

function Mini_addons_NOTICE_ON_MSG_GUILD(clean_str)
    if g.settings.baubas_call.guild_notice == 0 then
        return
    end
    ui.Chat("/g " .. clean_str)
end

-- 押されたボタン自身の表示だけを切り替える。以前は設定画面を作り直していたが、
-- 検索で絞り込んだ状態が消えてしまうので、Mini_addons_GP_AUTOSTART_OPERATION と同じやり方に揃えた。
function Mini_addons_baubas_call_switch(frame, ctrl, str)
    AUTO_CAST(ctrl)
    if g.settings.baubas_call.guild_notice == 0 then
        g.settings.baubas_call.guild_notice = 1
        ctrl:SetText("{ol}{#FFFFFF}ON")
        ctrl:SetSkinName("test_red_button")
    else
        g.settings.baubas_call.guild_notice = 0
        ctrl:SetText("{ol}{#FFFFFF}OFF")
        ctrl:SetSkinName("test_gray_button")
    end
    Mini_addons_save_settings()
end
-- ブラックマーケットのお知らせ
function Mini_addons_NOTICE_ON_MSG(frame, msg, str, num)
    -- str の nil ガード。個別版ではこの関数は 3SEC の NOTICE_ON_MSG フックに上書きされて
    -- 実際には呼ばれていなかったが、登録簿をまとめ版へ寄せたことで連鎖の中に入り、
    -- 毎回のお知らせで通るようになった。ここで落とすとお知らせ表示ごと巻き込む。
    if g.settings.chat_system == 1 and str then
        if string.find(str, "StartBlackMarketBetween") then
            return
        end
    end
    g.FUNCS["NOTICE_ON_MSG"](frame, msg, str, num)
end

-- 素の CHAT_TEXT_LINKCHAR_FONTSET は「整形した文字列を返す」だけなので、素をそのまま
-- 呼べる。書き写す必要が無いので持たない(素が変わっても自動で追随する。Issue #53)。
-- ここでやるのは「消したいメッセージなら nil を返して表示させない」判定だけ。
function Mini_addons_CHAT_TEXT_LINKCHAR_FONTSET(frame, msg)
    if not msg then
        return
    end
    if g.settings.chat_system == 1 then
        if string.find(msg, "StartBlackMarketBetween") then
            return
        end
    end
    local origin = g.FUNCS["CHAT_TEXT_LINKCHAR_FONTSET"]
    if origin then
        return origin(frame, msg)
    end
    -- 控えが無い = 素へ戻せない。整形は諦めて元の文字列をそのまま出す(消すよりまし)。
    -- ここはチャットが 1 行来るたびに通り、origin は setup_hook のときに確定して
    -- セッション中変わらない。絞らないと同じ 1 行で verbose_log.txt が埋まる
    -- (CLAUDE.md「出しすぎない」)。状況は変わらないのでセッション中 1 回でよい。
    -- 印は出力できたときだけ立てる(core の g.vlog のコメント参照)。先に立てると
    -- ログ OFF の間に消費され、後から ON にしてもこの行が出ないままになる。
    if not g.logged_linkchar_origin_missing and
        core_g.vlog("mini_addons: CHAT_TEXT_LINKCHAR_FONTSET の素の実装が控えに無い") then
        g.logged_linkchar_origin_missing = true
    end
    return msg
end
-- FPS設定を手動入力
function Mini_addons_SYS_OPTION_OPEN(frame, msg)
    local systemoption = ui.GetFrame("systemoption")
    local perfBox = GET_CHILD_RECURSIVELY(systemoption, "perfBox")
    local fps_edit = perfBox:CreateOrGetControl("edit", "fps_edit", 20, 200, 60, 25)
    AUTO_CAST(fps_edit)
    fps_edit:SetEventScript(ui.ENTERKEY, "Mini_addons_fps_edit")
    fps_edit:SetTextTooltip("{ol}1~240")
    fps_edit:SetFontName("white_16_ol")
    fps_edit:SetTextAlign("center", "center")
    fps_edit:SetNumberMode(1)
    local fps_config_lv = config.GetPerformanceLimit()
    fps_edit:SetText("{ol}" .. fps_config_lv)
end

function Mini_addons_fps_edit(parent, ctrl)
    local fps_num = tonumber(ctrl:GetText())
    local performance_limit_text = GET_CHILD(parent, "performance_limit_text")
    AUTO_CAST(performance_limit_text)
    performance_limit_text:SetTextByKey("opValue", fps_num)
    local performance_limit_slide = GET_CHILD(parent, "performance_limit_slide")
    AUTO_CAST(performance_limit_slide)
    config.SetPerformanceLimit(fps_num)
    performance_limit_slide:SetLevel(fps_num)
end
-- ボスレランキングにメンバーインフォ
function Mini_addons_WEEKLY_BOSS_RANK_UPDATE_()
    if type(_G["native_lang_WEEKLY_BOSS_RANK_UPDATE"]) == "function" then
        return
    end
    local induninfo = ui.GetFrame("induninfo")
    local rankListBox = GET_CHILD_RECURSIVELY(induninfo, "rankListBox", "ui::CGroupBox")
    local cnt = session.weeklyboss.GetRankInfoListSize()
    if cnt == 0 then
        return
    end
    for i = 1, cnt do
        local ctrl_set = GET_CHILD_RECURSIVELY(rankListBox, "CTRLSET_" .. i)
        if ctrl_set then
            AUTO_CAST(ctrl_set)
            local name = GET_CHILD(ctrl_set, "attr_name_text", "ui::CRichText")
            local teamname = session.weeklyboss.GetRankInfoTeamName(i - 1)
            local info_btn = rankListBox:CreateOrGetControl("button", "info_btn_" .. i, name:GetX(), (i - 1) * 73 + 50,
                50, 25)
            AUTO_CAST(info_btn)
            info_btn:SetText("{ol}Info")
            info_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_MEMBERINFO_ONCLICK")
            info_btn:SetEventScriptArgString(ui.LBUTTONUP, teamname)
            local txtGs = GET_CHILD(rankListBox, "txtGs_" .. i)
            if txtGs then
                rankListBox:RemoveChild("txtGs_" .. i)
            end
        end
    end
end

function Mini_addons_MEMBERINFO_ONCLICK(frame, ctrl, teamname, num)
    ui.Chat("/memberinfo " .. teamname)
    local compare = ui.GetFrame("compare")
    compare:SetLayerLevel(102)
end
-- ヘアエンチャント
-- 素の「ランクアップ時に停止」チェックの有効 / 無効を切り替える。目標ランクを
-- 指定している間はこちらの判定を見に行かない(そちらが優先)ので、押せるまま残すと
-- 「チェックしたのに止まらない」不具合に見える。
--
-- **これは素のフレームの持ち物なので、必ず元へ戻すこと。** 戻し忘れると、この機能を
-- OFF にしても素の窓のチェックが押せないまま残る。戻す経路は
--   * 目標ランクを「指定なし」へ戻したとき(mini_addons_p_hair_enchant_rank_until)
--   * 自前の窓を畳むとき(この下の CLOSE_BTN と、機能 OFF で畳む経路)
--
-- **灰色にしていないときは一切触らないこと。** 戻す側も呼び出し口が多く
-- (窓を組むたびに「指定なし」として通る)、素通りのつもりで毎回掛けていた。
--
-- **SetColorTone は使わないこと。** 一度設定するとそのコントロールは以降 ColorTone
-- 経由で描かれ、色として中立の "FFFFFFFF" を入れ直しても**文字の影が戻らない**
-- (実機で確認済み。picture では FFFFFFFF がリセットとして使えるが、キャプションを
-- 持つコントロールでは戻らない)。素の定義は fontname="black_16_b" で ColorTone を
-- 持たないので、こちらが一度でも掛けると元の見た目に戻せなくなる。
-- 代わりに素のキャプションを控えて、色タグ付きの文字列と入れ替える。戻すのは
-- 控えた文字列を書き戻すだけなので、確実に元へ戻る
local hair_enchant_rank_up_disabled = false
local hair_enchant_rank_up_caption = nil

local function hair_enchant_set_rank_up_enabled(enabled)
    if enabled == not hair_enchant_rank_up_disabled then
        -- 既にその状態。素のコントロールには触らない
        return
    end
    local high_hairenchant = ui.GetFrame("high_hairenchant")
    local rank_up = high_hairenchant and GET_CHILD_RECURSIVELY(high_hairenchant, "rank_up")
    if rank_up == nil then
        -- 素の窓ごと消えている。次に灰色にするときの起点が狂わないよう印だけ戻す
        hair_enchant_rank_up_disabled = false
        return
    end
    AUTO_CAST(rank_up)
    if hair_enchant_rank_up_caption == nil then
        -- 初回だけ素のキャプションを控える。読めない土台なら空文字にして、
        -- 以降は文字を触らず SetEnable だけで済ませる(見た目は変わらないが壊さない)
        local ok, caption = pcall(function()
            return rank_up:GetText()
        end)
        hair_enchant_rank_up_caption = (ok and type(caption) == "string") and caption or ""
        core_g.vlog("mini_addons: ヘアエンチャント 素のランクアップ停止チェックの文言を控えた(%s)",
            hair_enchant_rank_up_caption == "" and "読めなかったので文字は触らない" or
                hair_enchant_rank_up_caption)
    end
    rank_up:SetEnable(enabled and 1 or 0)
    rank_up:EnableHitTest(enabled and 1 or 0)
    if hair_enchant_rank_up_caption ~= "" then
        rank_up:SetText(enabled and hair_enchant_rank_up_caption or
                            ("{#888888}" .. hair_enchant_rank_up_caption))
    end
    hair_enchant_rank_up_disabled = not enabled
    core_g.vlog("mini_addons: ヘアエンチャント 素のランクアップ停止チェックを%s",
        enabled and "元に戻した" or "灰色にした")
end

function Mini_addons_HIGH_HAIRENCHANT_CLOSE_BTN(my_frame, my_msg)
    local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
    if reroll_option then
        local high_hairenchant = ui.GetFrame("high_hairenchant")
        local bodyGbox1_1 = GET_CHILD_RECURSIVELY(high_hairenchant, "bodyGbox1_1")
        AUTO_CAST(bodyGbox1_1)
        bodyGbox1_1:RemoveAllChild()
        SET_REPEAT_COUNT_TEXT(0)
        RESET_HIGH_ENCHANT()
        high_hairenchant:StopUpdateScript("Mini_addons_HIGH_HAIRENCHANT_OK_BTN_")
        hair_enchant_set_rank_up_enabled(true)
        ui.DestroyFrame(reroll_option:GetName())
    end
end

-- 連続付与の刻み。**これは「撃つ間隔」ではなく「結果が返ったかを見にいく間隔」**。
-- 実際に次を撃つのは素の結果が返ってからなので、ここを小さくしても撃つ速さは
-- サーバの応答より速くならない(＝空撃ちしない)。上限の待ち時間だけが縮む
local HAIR_ENCHANT_TICK = 0.1
-- 希望オプションのスクロール枠より下に置くもの(「演出を待たずに実行」の行 +
-- 目標ランク / Cancel / リピート回数の行 + 窓の下余白)の高さ。
-- 枠の高さを画面から逆算するのに使うので、下の行を増減したらここも合わせること
local HAIR_ENCHANT_BOTTOM_HEIGHT = 110
-- 結果が返らないまま何秒たったら諦めて止めるか。要求が落ちた / サーバに弾かれたときに
-- 黙って止まったように見えるのを避けるための保険で、**撃ち直しはしない**
-- (理由は使う側のコメント)。撃たずに止めるだけなので、応答が遅い環境で
-- 早々に打ち切らないよう長めに取る。os.time() は秒単位なので、実際の発動は
-- ここから最大 1 秒早まりうる
local HAIR_ENCHANT_WATCHDOG = 10

-- ランクの並び。素の shared_enchant_special_option.get_item_rank が返すのは
-- EnchantItemRank(0~3) を写した文字列 "D"/"C"/"B"/"A" なので、そのまま比較しても
-- 上下は分からない。「指定したランクへ届いたか」を見るために順序を持つ
local hair_enchant_rank_order = {"D", "C", "B", "A"}

local function hair_enchant_rank_index(rank)
    for i, name in ipairs(hair_enchant_rank_order) do
        if name == rank then
            return i
        end
    end
    return nil
end

-- アイテムに今付いているオプションの指紋。付与するたびに必ず振り直されるので、
-- これが変わっていなければ「まだ前の結果のまま」と判断できる。
-- 合図(READY)がアイテムの更新より先に来る可能性への歯止めに使う
local function hair_enchant_option_fingerprint(itemIES)
    local invItem = session.GetInvItemByGuid(itemIES)
    if invItem == nil then
        return "none"
    end
    local obj = GetIES(invItem:GetObject())
    if obj == nil then
        return "none"
    end
    local parts = {}
    for i = 1, 3 do
        table.insert(parts, tostring(obj["HatPropName_" .. i]) .. "=" .. tostring(obj["HatPropValue_" .. i]))
    end
    return table.concat(parts, ";")
end

local function get_current_enchant_item_grade_and_rank()
    local hairenchant = ui.GetFrame("high_hairenchant")
    if hairenchant == nil then
        return
    end
    local enchantGuid = hairenchant:GetUserValue("Enchant")
    local itemIES = hairenchant:GetUserValue("itemIES")
    if enchantGuid == "None" or itemIES == "None" then
        return
    end
    local item = session.GetInvItemByGuid(itemIES)
    local enchant_item = session.GetInvItemByGuid(enchantGuid)
    if enchant_item == nil or item == nil then
        return
    end
    enchant_item = GetIES(enchant_item:GetObject())
    item = GetIES(item:GetObject())
    local item_grade = shared_enchant_special_option.get_enchant_item_grade(enchant_item)
    local item_rank = shared_enchant_special_option.get_item_rank(item)
    return item_grade, item_rank
end

-- 実体は下。ローカルのまま前方宣言しておく。グローバルにすると本家や他アドオンと
-- 名前で衝突しうる
local hair_enchant_build_reroll_body
local hair_enchant_open_advanced
local hair_enchant_presets
-- 実体は hair_enchant_build_reroll_body の中(ドロップリストの項目から呼ぶ版と
-- 組み立てから呼ぶ版を分けるため)
local hair_enchant_apply_rank_until

-- プリセットを読み込んだ後、手で設定を変えたか。**変えていればプリセットの
-- 入れ直しをしない。** 入れ直しは「低いランクで落ちたチェックを、上のランクへ
-- 替えたときに戻す」ためのものなので、手で変えた内容まで保存値へ巻き戻すのは行き過ぎ
-- (ランクアップやスクロールのスタック切り替えでも入れ直しは走る)
local hair_enchant_preset_dirty = false

local function hair_enchant_mark_dirty()
    hair_enchant_preset_dirty = true
end

-- 監視スクリプト(Mini_addons_hair_enchant_watch)から呼ぶが、実体はその下にある。
-- **前方宣言を忘れるとグローバル参照になって nil。** 0.3 秒ごとに
-- attempt to call a nil value になり、監視そのものが死ぬ
local hair_enchant_sync_send_button

-- 「今の中身は何を元に組んだか」の印。ヘアアクセや魔法付与スクロールを差し替えると
-- 選べるオプションもランクも変わるので、これが変わったら組み直す
local function hair_enchant_build_signature(item_grade, item_rank)
    local high_hairenchant = ui.GetFrame("high_hairenchant")
    if high_hairenchant == nil then
        return nil
    end
    return string.format("%s/%s/%s/%s", high_hairenchant:GetUserValue("itemIES"),
        high_hairenchant:GetUserValue("Enchant"), tostring(item_grade), tostring(item_rank))
end

-- 組んだときと今とで対象が変わっていたら組み直す。変わっていなければ何もしない。
-- ランクアップで続行するときと、窓を開いたまま装備を入れ替えたときの両方から通る
local function hair_enchant_refresh_if_changed(reroll_option)
    if reroll_option == nil then
        return false
    end
    local item_grade, item_rank = get_current_enchant_item_grade_and_rank()
    if item_grade == nil or item_rank == nil then
        -- スロットが空(入れ替えの途中など)。この状態では組みようがないので触らない。
        -- 次の品が入れば印が変わるので、そこで組み直される
        return false
    end
    local sig = hair_enchant_build_signature(item_grade, item_rank)
    if sig == nil or sig == reroll_option:GetUserValue("BUILD_SIG") then
        return false
    end
    core_g.vlog("mini_addons: ヘアエンチャント 対象が変わったので組み直す(%s → %s)",
        tostring(reroll_option:GetUserValue("BUILD_SIG")), tostring(sig))
    -- **プリセットを選んでいるなら、保存内容から入れ直す。**
    -- 低いランクのアクセで読み込むと、そのランクで出ないオプションは g.need_options から
    -- 落ちる。そのまま組み直すと「落ちた後の状態」が元になるので、ランクの高いアクセに
    -- 替えても抜けたチェックが戻らない(実際にそうなった)。保存内容が真なので、
    -- 対象が変わるたびにそこから入れ直す
    local presets = hair_enchant_presets()
    local preset = presets[tonumber(reroll_option:GetUserValue("PRESET_SEL")) or 0]
    if preset ~= nil and not hair_enchant_preset_dirty then
        core_g.vlog("mini_addons: ヘアエンチャント プリセット「%s」を新しい対象に合わせて入れ直す",
            tostring(preset.name))
        -- 自動の入れ直しなのでリピート回数は今の値のまま(false)
        Mini_addons_hair_enchant_preset_load(false)
        return true
    end
    if preset ~= nil then
        -- 読み込んだ後に手で変えている。保存値へ巻き戻さず、今の内容のまま組み直す
        core_g.vlog("mini_addons: ヘアエンチャント プリセット「%s」は読込後に手で変えられているので入れ直さない",
            tostring(preset.name))
    end
    hair_enchant_build_reroll_body(reroll_option, item_grade, item_rank)
    return true
end

-- 「アイテムを乗せてください」まわりの表示を、スロットの実際の状態に合わせ直す。
--
-- 素は HIGH_HAIRENCHANT_DRAW_HIRE_ITEM で隠し、CLEAR_ENCHANT_OPTION_ITEM_DATA_UI で
-- 出す作りだが、アイテムを乗せた後も出たままになることがある(何が出し直しているのか
-- 素のコードからは特定できなかった)。**押しても直せない案内文が残るのは分かりにくい**ので、
-- itemIES が入っているかどうかから毎回決め直す。素と同じ判断なので取り合いにはならない。
-- 変わったときだけ触る(毎フレーム ShowWindow を叩かない / ログも流さない)
local function hair_enchant_sync_slot_guide()
    local frame = ui.GetFrame("high_hairenchant")
    if frame == nil or frame:IsVisible() == 0 then
        return
    end
    local has_item = frame:GetUserValue("itemIES") ~= "None"
    local changed = nil
    -- 素の DRAW / CLEAR が触る 4 つを、そのまま同じ向きに揃える
    for _, name in ipairs({"groupbox_1", "groupbox_2", "slot_bg_image"}) do
        local ctrl = GET_CHILD_RECURSIVELY(frame, name)
        if ctrl ~= nil then
            local want = has_item and 0 or 1
            if ctrl:IsVisible() ~= want then
                ctrl:ShowWindow(want)
                changed = (changed and (changed .. ",") or "") .. name
            end
        end
    end
    local rank_up = GET_CHILD_RECURSIVELY(frame, "rank_up")
    if rank_up ~= nil then
        local want = has_item and 1 or 0
        if rank_up:IsVisible() ~= want then
            rank_up:ShowWindow(want)
            changed = (changed and (changed .. ",") or "") .. "rank_up"
        end
    end
    if changed ~= nil then
        core_g.vlog("mini_addons: ヘアエンチャント 案内表示を実態に合わせ直した(アイテム=%s / %s)",
            has_item and "あり" or "無し", changed)
    end
end

-- 自前の窓が開いている間だけ回して、対象の入れ替えに追随する。素の側には
-- 「差し替わった」を知らせてくれる仕組みが無く、差し替えの経路も複数
-- (ドロップ / 右クリックで外す / RESET_HIGH_ENCHANT)あるため、
-- それぞれにフックを掛けるより印を見て比べる方が漏れがない。
-- 比較だけなので、変化が無いときは何も出さない(ログを流さないこと)
function Mini_addons_hair_enchant_watch(frame)
    if frame == nil then
        frame = ui.GetFrame(addon_name_lower .. "reroll_option")
    end
    if frame == nil then
        return 0
    end
    hair_enchant_refresh_if_changed(frame)
    hair_enchant_sync_slot_guide()
    -- 上限に達して止まったときなど、窓を開いたまま終わる経路もあるので毎回見る
    hair_enchant_sync_send_button()
    return 1
end

-- 連続付与を回している最中か。更新スクリプトが載っているかで見る
-- (STATUS は 1 回目が成功してから立つので、押した直後の判定には使えない)
local function hair_enchant_is_running()
    local frame = ui.GetFrame("high_hairenchant")
    if frame == nil then
        return false
    end
    if frame:HaveUpdateScript("Mini_addons_HIGH_HAIRENCHANT_OK_BTN_") == true then
        return true
    end
    -- 希望オプションが付いて「続けますか？」を出している間も回している扱いにする。
    -- ここで「魔法付与」へ戻すと、返事を待っているだけなのに終わったように見えるうえ、
    -- そのボタンを押せると連続付与が二重に走り出す
    local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
    return reroll_option ~= nil and reroll_option:GetUserValue("ASKING") == "yes"
end

-- 素の「마법 부여」ボタンを、回している間だけ「停止」の見た目と状態にする。
--
-- **auto_run は立てないこと。** 素は auto_run == 1 だと HIGH_HAIRENCHANT_SUCEECD_RESULT
-- の中で自前の連続処理を始めてしまう(結果のたびに HIGH_HAIRENCHANT_OK_BTN を呼ぶので
-- こちらのループと二重に撃つ。目標未設定だと match_count >= goal_count が 0 >= 0 で
-- 成立して毎回 RESET_HIGH_ENCHANT まで走る)。
-- ここで欲しいのはボタンの表示と State だけなので、素の
-- HIGH_ENCHANT_CHANGE_BUTTON_STATE を呼ぶ間だけ auto_run を立てて、すぐ戻す。
-- こうしておけば表示文言(ClMsg)や State の決め方が素で変わっても付いていける
hair_enchant_sync_send_button = function()
    local frame = ui.GetFrame("high_hairenchant")
    if frame == nil or frame:IsVisible() == 0 then
        return
    end
    local send_ok = GET_CHILD_RECURSIVELY(frame, "send_ok")
    if send_ok == nil then
        return
    end
    local running = hair_enchant_is_running()
    local want = running and 0 or 1
    if send_ok:GetUserIValue("State") == want then
        return
    end
    if running then
        local keep = frame:GetUserIValue("auto_run")
        frame:SetUserValue("auto_run", 1)
        HIGH_ENCHANT_CHANGE_BUTTON_STATE(frame, 0)
        frame:SetUserValue("auto_run", keep or 0)
    else
        HIGH_ENCHANT_CHANGE_BUTTON_STATE(frame, 1)
    end
    core_g.vlog("mini_addons: ヘアエンチャント 付与ボタンを「%s」にした", running and "停止" or "魔法付与")
end

-- 自前の窓を畳む(素の窓や設定には触らない)。機能 OFF になったときや、
-- 「高度な設定」ボタンをもう一度押したときに使う
local function hair_enchant_close_advanced()
    local stale = ui.GetFrame(addon_name_lower .. "reroll_option")
    if stale == nil then
        return false
    end
    local high_hairenchant = ui.GetFrame("high_hairenchant")
    if high_hairenchant then
        high_hairenchant:StopUpdateScript("Mini_addons_HIGH_HAIRENCHANT_OK_BTN_")
    end
    -- 目標ランク指定で灰色にしていたら戻す(戻し先は素のフレームなので必須)
    hair_enchant_set_rank_up_enabled(true)
    ui.DestroyFrame(stale:GetName())
    -- 付与ボタンも「停止」から戻す。窓を畳むと監視スクリプトも止まるので、
    -- ここで戻さないと「停止」表示のまま取り残される。
    -- **必ず DestroyFrame の後に呼ぶこと。** 先に呼ぶと、確認ダイアログの返事待ち
    -- (ASKING == "yes")の最中に閉じたときに「まだ回している」と判定されてしまい、
    -- 「停止」表示のまま誰も戻せなくなる
    hair_enchant_sync_send_button()
    return true
end

-- × ボタン。**自前の窓だけ畳む。** 素の RESET_HIGH_ENCHANT までは走らせない
-- (素の「設定」で入れたオプション指定を、こちらを閉じただけで消さないため)。
-- 連続付与を強制的に止めたいときは Cancel ボタン(素の CLOSE_BTN)を使う
function Mini_addons_hair_enchant_adv_close(parent, ctrl)
    SET_REPEAT_COUNT_TEXT(0)
    hair_enchant_close_advanced()
end

-- 「高度な設定」ボタン。素の「設定」とは別物で、素の hairenchant_option には触らない
-- (閉じも開きもしない)。押すたびに自前の窓を開く / 畳むのトグル
function Mini_addons_hair_enchant_adv_btn(parent, ctrl)
    if g.settings.hair_enchant == 0 then
        core_g.vlog("mini_addons: ヘアエンチャント 機能 OFF なので高度な設定は開かない(自前の窓=%s)",
            hair_enchant_close_advanced() and "残っていたので畳んだ" or "無し")
        return
    end
    if hair_enchant_close_advanced() then
        core_g.vlog("mini_addons: ヘアエンチャント 高度な設定を畳んだ(もう一度押された)")
        return
    end
    hair_enchant_open_advanced()
end

hair_enchant_open_advanced = function()
    local high_hairenchant = ui.GetFrame("high_hairenchant")
    if high_hairenchant == nil then
        return
    end
    local enchantGuid = high_hairenchant:GetUserValue("Enchant")
    local itemIES = high_hairenchant:GetUserValue("itemIES")
    if enchantGuid == "None" or itemIES == "None" then
        -- 素材かスクロールが揃っていないと、出せるオプションもランクも決まらない
        core_g.vlog("mini_addons: ヘアエンチャント 高度な設定を開けない(アイテム=%s / スクロール=%s)",
            itemIES == "None" and "未設定" or "あり", enchantGuid == "None" and "未設定" or "あり")
        return
    end
    core_g.vlog("mini_addons: ヘアエンチャント 高度な設定を開く")
    -- 素のオプション設定とは**どちらか一方だけ**。ほぼ同じ位置に重なるので、
    -- 両方出ていると手前がどちらか分からなくなる。開くときに相手を閉じる
    -- (逆向きは Mini_addons_HIGH_ENCHANT_OPTION_OPEN_BTN でやっている)
    ui.CloseFrame("hairenchant_option")
    local reroll_option = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "reroll_option", 0, 0, 0, 0)
    AUTO_CAST(reroll_option)
    reroll_option:SetSkinName("test_Item_tooltip_equip")
    reroll_option:SetGravity(ui.RIGHT, ui.TOP) -- ui.GetClientInitialWidth() 1920が取れるui.GetSceneWidt()今の横幅 結構nilになったりする。信頼性低いui.GetRatioWidth()=ui.GetSceneWidth()/ui.GetClientInitialWidth()
    local margin = reroll_option:GetMargin()
    reroll_option:SetMargin(margin.left, margin.top, margin.right + 905, margin.bottom)
    reroll_option:SetPos(reroll_option:GetX(), high_hairenchant:GetY())
    reroll_option:SetLayerLevel(100)
    -- **窓の余白(タイトル部分)でクリックが素通りしないようにする。**
    -- これが無いと、コントロールの載っていない所を押したときにクリックが後ろへ抜けて、
    -- 露店や地面など背後のものが反応してしまう。同じ土台で作っている rank_frame も
    -- 同様に立てている
    reroll_option:EnableHittestFrame(1)
    -- gbox とその中身は hair_enchant_build_reroll_body が作る(ランクが上がったら
    -- そこだけ組み直すため)。close ボタンは gbox の外なので組み直しの対象外
    local close = reroll_option:CreateOrGetControl("button", "close", 0, 0, 30, 30)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.LEFT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Mini_addons_hair_enchant_adv_close")
    local item_grade, item_rank = get_current_enchant_item_grade_and_rank()
    if item_grade == nil or item_rank == nil then
        -- **作りかけのフレームを残さないこと。** 非表示の空フレームが居座ると、
        -- 「高度な設定」ボタンは畳むだけ(1 回目の押下が空振り)になり、
        -- 自動で開く経路も「もう開いている」と判断して二度と開かなくなる
        core_g.vlog("mini_addons: ヘアエンチャント 等級 / ランクを引けないので高度な設定を開けない")
        ui.DestroyFrame(reroll_option:GetName())
        return
    end
    g.need_options = {}
    hair_enchant_build_reroll_body(reroll_option, item_grade, item_rank)
    reroll_option:ShowWindow(1)
    -- 窓を開いたままヘアアクセやスクロールを差し替えられても追随できるようにする。
    -- 窓を畳めば一緒に止まる(フレームごと破棄するため)
    reroll_option:RunUpdateScript("Mini_addons_hair_enchant_watch", 0.3)
end


-- 指定した等級 / ランクで**実際に出るオプション**の「クラス名 → チェックの名前」表を作る。
--
-- **g.hair_enchant_option_by_class を当てにしないこと。** あれは窓を組んだ時点の
-- ランクのものなので、アクセを差し替えた直後(まだ組み直していない)に引くと古い。
-- D のアクセで読み込んだ後 A へ替えても A 専用のオプションが「出ない」と判定され、
-- チェックが戻らなかった。ここは毎回ランクから引き直す。
-- チェックの名前は enchant_special_option の並び順そのもの(ランクで変わらない)
local function hair_enchant_option_map(item_grade, item_rank)
    local by_class = {}
    local OptionList, cnt = GetClassList("enchant_special_option")
    for i = 0, cnt - 1 do
        local cls = GetClassByIndexFromList(OptionList, i)
        if cls == nil then
            break
        end
        local range = shared_enchant_special_option.get_value_range(cls.ClassName, item_grade, item_rank, 1)
        if range[1] ~= 0 and range[2] ~= 0 then
            by_class[cls.ClassName] = "option_text" .. i
        end
    end
    return by_class
end

-- 組み立て中に SelectItem が項目のスクリプトを走らせても読み込みに行かせないための印。
-- 読み込むと窓を組み直すので、抑えないと止まらなくなる
local hair_enchant_suppress_preset_sel = false

-- プリセットの入れ物。**配列**(1 始まり)で、枠数は決めない。
-- 途中まで「1」〜「4」を鍵にした表で持っていた時期があるので、その形が残っていたら
-- 配列へ移し替える(dev ビルドで保存したものを消さないため)
hair_enchant_presets = function()
    local presets = g.settings.hair_enchant_presets
    if type(presets) ~= "table" then
        presets = {}
        g.settings.hair_enchant_presets = presets
    end
    if #presets == 0 then
        local moved = 0
        for slot = 1, 4 do
            local old = presets[tostring(slot)]
            if type(old) == "table" then
                table.insert(presets, old)
                presets[tostring(slot)] = nil
                moved = moved + 1
            end
        end
        if moved > 0 then
            Mini_addons_save_settings()
            core_g.vlog("mini_addons: ヘアエンチャント 旧形式(枠固定)のプリセット %d 件を引き継いだ", moved)
        end
    end
    return presets
end

-- 窓を組み直して、プリセット一覧やチェックの状態を今の設定に合わせる
local function hair_enchant_rebuild()
    local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
    if reroll_option == nil then
        return
    end
    local item_grade, item_rank = get_current_enchant_item_grade_and_rank()
    if item_grade == nil or item_rank == nil then
        return
    end
    hair_enchant_build_reroll_body(reroll_option, item_grade, item_rank)
end

-- ドロップリストで選んだプリセット(1 始まり。0 は「プリセットなし」)。
-- **選んだらその場で読み込む**(読込ボタンは置いていない)。
-- ただし組み立て中の SelectItem から来たときは記録だけ(理由は呼び出し側のコメント)
function mini_addons_p_hair_enchant_preset_sel(index)
    local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
    if reroll_option == nil then
        return
    end
    reroll_option:SetUserValue("PRESET_SEL", tostring(index))
    if hair_enchant_suppress_preset_sel or index == 0 then
        return
    end
    -- **この場で読み込まないこと。** 読み込むと窓を組み直す = 今このスクリプトを
    -- 走らせているドロップリスト自身を RemoveAllChild で壊すことになる。1 拍遅らせる
    -- (always_status の設定画面も、同じ理由で ReserveScript を挟んでいる)
    ReserveScript(string.format("%s_hair_enchant_preset_load_deferred()", addon_name_lower), 0.1)
end

function mini_addons_p_hair_enchant_preset_load_deferred()
    -- ドロップリストで選んだ = 明示的な読込。リピート回数もプリセットの値にする
    Mini_addons_hair_enchant_preset_load(true)
end

-- 保存。名前を訊くポップアップ(素の inputstring)を出す。
-- 選択中のプリセットがあればその名前を初期値にするので、そのまま決定すれば上書きになる
function Mini_addons_hair_enchant_preset_save_open(parent, ctrl)
    local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
    if reroll_option == nil then
        return
    end
    local presets = hair_enchant_presets()
    local sel = tonumber(reroll_option:GetUserValue("PRESET_SEL")) or 0
    local inputstring = ui.GetFrame("inputstring")
    if inputstring == nil then
        core_g.vlog("mini_addons: ヘアエンチャント inputstring が無いのでプリセット名を訊けない")
        return
    end
    inputstring:Resize(500, 220)
    inputstring:SetLayerLevel(999)
    local edit = GET_CHILD(inputstring, "input", "ui::CEditControl")
    edit:SetNumberMode(0)
    edit:SetMaxLen(64)
    edit:SetText(presets[sel] ~= nil and presets[sel].name or "")
    local title = inputstring:GetChild("title")
    AUTO_CAST(title)
    title:SetText(g.lang == "Japanese" and "{ol}{#FFFFFF}プリセットの名前を入力してください" or
                      "{ol}{#FFFFFF}Enter a preset name")
    local confirm = inputstring:GetChild("confirm")
    confirm:SetEventScript(ui.LBUTTONUP, "Mini_addons_hair_enchant_preset_save_do")
    edit:SetEventScript(ui.ENTERKEY, "Mini_addons_hair_enchant_preset_save_do")
    inputstring:ShowWindow(1)
    inputstring:SetEnable(1)
    edit:AcquireFocus()
end

-- ポップアップで決定された。今の窓の状態を、その名前で保存する。
-- **オプションはクラス名で持つ**(理由は DEFAULT_SETTINGS のコメント)
function Mini_addons_hair_enchant_preset_save_do(frame, ctrl)
    if frame == nil or frame:GetName() ~= "inputstring" then
        return
    end
    local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
    if reroll_option == nil then
        frame:ShowWindow(0)
        return
    end
    local name = GET_INPUT_STRING_TXT(frame)
    if name == nil or name == "" then
        ui.SysMsg(g.lang == "Japanese" and "プリセットの名前を入力してください" or "Enter a preset name")
        return
    end
    local options = {}
    for option_name, value in pairs(g.need_options or {}) do
        local class_name = (g.hair_enchant_option_classes or {})[option_name]
        if value.is_check == 1 and class_name ~= nil then
            table.insert(options, class_name)
        end
    end
    table.sort(options) -- 保存のたびに並びが変わると差分が読みにくいので固定する
    local repeat_count = GET_CHILD_RECURSIVELY(reroll_option, "repeat_count")
    local entry = {
        name = name,
        options = options,
        rank = reroll_option:GetUserValue("RANK_UNTIL"),
        repeat_count = repeat_count ~= nil and tonumber(repeat_count:GetText()) or nil,
        fast = reroll_option:GetUserValue("FAST") == "yes" and 1 or 0
    }
    local presets = hair_enchant_presets()
    local at = nil
    for i, preset in ipairs(presets) do
        if preset.name == name then
            at = i
            break
        end
    end
    if at ~= nil then
        presets[at] = entry
    else
        table.insert(presets, entry)
        at = #presets
    end
    reroll_option:SetUserValue("PRESET_SEL", tostring(at))
    Mini_addons_save_settings()
    core_g.vlog("mini_addons: ヘアエンチャント プリセット「%s」を%s(オプション %d 件 / 目標ランク %s)", name,
        at == #presets and "追加" or "上書き", #options, tostring(entry.rank))
    ui.SysMsg(string.format(g.lang == "Japanese" and "プリセット「%s」を保存しました" or "Saved preset \"%s\"",
        name))
    frame:ShowWindow(0)
    -- 保存した = 今の内容が保存値そのもの
    hair_enchant_preset_dirty = false
    hair_enchant_rebuild()
end

-- 読込。今のランクで出ないオプションは飛ばす(保存したときよりランクが低いと、
-- B・A でしか出ないものが一覧に無い)
-- apply_repeat: リピート回数まで反映するか。
-- **ドロップリストで選んだときだけ true。** アクセの差し替え・ランクアップ・
-- 確認ダイアログを挟んだ入れ直しといった「自動の入れ直し」では今の値を維持する。
-- 回している最中に上限が勝手に書き換わると、いつ止まるのか読めなくなるため。
-- 「自分で選んだときだけ変わる」と覚えれば済むよう、回している最中かどうかでは分けない
function Mini_addons_hair_enchant_preset_load(apply_repeat)
    local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
    if reroll_option == nil then
        return
    end
    local presets = hair_enchant_presets()
    local preset = presets[tonumber(reroll_option:GetUserValue("PRESET_SEL")) or 0]
    if preset == nil then
        return
    end
    local item_grade, item_rank = get_current_enchant_item_grade_and_rank()
    if item_grade == nil or item_rank == nil then
        return
    end
    local applied, skipped = 0, {}
    -- 対応表は今の等級 / ランクから引き直す(古い表を使うと、差し替えたばかりの
    -- アクセで出るはずのオプションを取りこぼす。理由は hair_enchant_option_map)
    local by_class = hair_enchant_option_map(item_grade, item_rank)
    g.need_options = {}
    for _, class_name in ipairs(preset.options or {}) do
        local option_name = by_class[class_name]
        if option_name ~= nil then
            g.need_options[option_name] = {
                is_check = 1,
                text = ScpArgMsg(class_name)
            }
            applied = applied + 1
        else
            table.insert(skipped, class_name)
        end
    end
    -- 目標ランクは今のランクより上でなければ意味を成さないので、そのときは指定なしへ
    local rank = preset.rank
    local rank_index = hair_enchant_rank_index(rank)
    local now_index = hair_enchant_rank_index(item_rank)
    if rank_index == nil or now_index == nil or rank_index <= now_index then
        rank = "None"
    end
    reroll_option:SetUserValue("RANK_UNTIL", rank)
    reroll_option:SetUserValue("FAST", preset.fast == 1 and "yes" or "no")
    hair_enchant_build_reroll_body(reroll_option, item_grade, item_rank)
    -- リピート回数は組み直しが前の値を引き継ぐので、反映するときだけ後から上書きする
    if apply_repeat and preset.repeat_count ~= nil then
        local repeat_count = GET_CHILD_RECURSIVELY(reroll_option, "repeat_count")
        if repeat_count ~= nil then
            repeat_count:SetText(tostring(preset.repeat_count))
        end
    end
    core_g.vlog(
        "mini_addons: ヘアエンチャント プリセット「%s」を読込(オプション %d 件適用 / %d 件は %s ランクで出ないので飛ばした%s / 目標ランク %s / リピート回数は%s)",
        tostring(preset.name), applied, #skipped, tostring(item_rank),
        #skipped > 0 and (": " .. table.concat(skipped, ", ")) or "", tostring(rank),
        apply_repeat and "プリセットの値を反映" or "今の値を維持")
    -- 今の内容 = 保存値。ここから手で変えられるまでは入れ直してよい
    hair_enchant_preset_dirty = false
    if #skipped > 0 then
        ui.SysMsg(string.format(g.lang == "Japanese" and
                                    "プリセット「%s」を読み込みました(%d 件は今のランクでは付かないので除外)" or
                                    "Loaded preset \"%s\" (%d entries dropped: not available at this rank)",
            tostring(preset.name), #skipped))
    end
end

function mini_addons_p_hair_enchant_preset_delete_do()
    local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
    if reroll_option == nil then
        return
    end
    local presets = hair_enchant_presets()
    local sel = tonumber(reroll_option:GetUserValue("PRESET_SEL")) or 0
    local preset = presets[sel]
    if preset == nil then
        return
    end
    table.remove(presets, sel)
    -- 消した後は「--」へ戻す。詰めた結果の別のプリセットが選ばれた状態にすると、
    -- 名前は出ているのにチェックはさっきのまま、という食い違いになる
    reroll_option:SetUserValue("PRESET_SEL", "0")
    Mini_addons_save_settings()
    core_g.vlog("mini_addons: ヘアエンチャント プリセット「%s」を削除(残り %d 件)", tostring(preset.name),
        #presets)
    hair_enchant_rebuild()
end

-- 削除。押し間違いで消えると戻せないので確認を挟む
function Mini_addons_hair_enchant_preset_delete(parent, ctrl)
    local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
    if reroll_option == nil then
        return
    end
    local presets = hair_enchant_presets()
    local preset = presets[tonumber(reroll_option:GetUserValue("PRESET_SEL")) or 0]
    if preset == nil then
        return
    end
    ui.MsgBox(string.format(g.lang == "Japanese" and "{#FFFFFF}{ol}プリセット「%s」を削除しますか？" or
                                "{#FFFFFF}{ol}Delete preset \"%s\"?", tostring(preset.name)),
        string.format("%s_hair_enchant_preset_delete_do()", addon_name_lower), "None")
end

-- 素の「設定」が押された。**素の動きには手を出さない**(このフックは元の関数を
-- 先に呼ぶ設定で、標準のオプション窓は既に開いている)。こちらは自前の窓を畳むだけ。
-- ほぼ同じ位置に重なるので、両方出ていると手前がどちらか分からなくなる。
--
-- 素が途中で return したとき(アイテム未設定・等級が None など)は標準の窓が開かない。
-- そのときに畳むと「設定を押したら高度な設定だけ消えた」になるので、
-- **本当に開いたかを確かめてから**畳むこと
function Mini_addons_HIGH_ENCHANT_OPTION_OPEN_BTN(my_frame, my_msg)
    local hairenchant_option = ui.GetFrame("hairenchant_option")
    if hairenchant_option == nil or hairenchant_option:IsVisible() == 0 then
        return
    end
    if hair_enchant_close_advanced() then
        core_g.vlog("mini_addons: ヘアエンチャント 標準のオプション設定が開いたので高度な設定を畳んだ")
    end
end

-- 付与ウィンドウが開かれた。素のフレームへ「高度な設定」ボタンを足す。
-- 素の「設定」(select_before)は bodyGbox1 の右上 90x35 なので、その左隣に並べる。
-- CreateOrGetControl なので開くたびに呼んでも二重にはならない
function Mini_addons_CLIENT_ENCHANTCHIP(my_frame, my_msg)
    local high_hairenchant = ui.GetFrame("high_hairenchant")
    if high_hairenchant == nil or high_hairenchant:IsVisible() == 0 then
        -- 低級のスクロールは素が hairenchant の方を開く。こちらは対象外だが、
        -- **自前の窓が残っていたら畳むこと。** 素の CLIENT_ENCHANTCHIP は冒頭で
        -- HIGH_HAIRENCHANT_UI_RESET() を呼んで高級側を閉じるので、放っておくと
        -- 相手のいない高度な設定が更新スクリプトごと画面に取り残される
        if hair_enchant_close_advanced() then
            core_g.vlog("mini_addons: ヘアエンチャント 高級の付与ウィンドウが閉じたので高度な設定を畳んだ")
        end
        return
    end
    local bodyGbox1 = GET_CHILD_RECURSIVELY(high_hairenchant, "bodyGbox1")
    if bodyGbox1 == nil then
        return
    end
    local adv = bodyGbox1:CreateOrGetControl("button", "mini_addons_adv_setting", 0, 0, 100, 35)
    AUTO_CAST(adv)
    adv:SetGravity(ui.RIGHT, ui.TOP)
    local margin = adv:GetMargin()
    adv:SetMargin(margin.left, margin.top, 95, margin.bottom) -- 素の「設定」(幅 90)の左隣
    adv:SetSkinName("test_pvp_btn")
    adv:SetText("{@st66}{s16}" .. (g.lang == "Japanese" and "高度な設定" or "Advanced"))
    adv:SetTextTooltip(g.lang == "Japanese" and
                           "{ol}希望オプション・目標ランク・プリセットを設定します{nl}隣の「設定」はゲーム標準のままです" or
                           "{ol}Set target options, target rank and presets{nl}The button next to it stays vanilla")
    adv:SetEventScript(ui.LBUTTONUP, "Mini_addons_hair_enchant_adv_btn")
    -- 機能 OFF のときはボタンごと隠す(押しても何もしないボタンを見せない)
    adv:ShowWindow(g.settings.hair_enchant == 1 and 1 or 0)
    core_g.vlog("mini_addons: ヘアエンチャント 高度な設定ボタンを用意した(機能=%s)",
        g.settings.hair_enchant == 1 and "ON" or "OFF")
end

-- 素材(ヘアアクセ)がスロットへ乗った。ここで初めてランクとオプション一覧が決まるので、
-- 「自動で開く」はこの時点で効かせる。既に開いていれば監視スクリプトが組み直す
function Mini_addons_HIGH_HAIRENCHANT_DRAW_HIRE_ITEM(my_frame, my_msg)
    if g.settings.hair_enchant == 0 then
        return
    end
    -- 乗せたのに「アイテムを乗せてください」が残ることがあるので、ここでも合わせ直す
    hair_enchant_sync_slot_guide()
    if g.settings.hair_enchant_auto_open ~= 1 then
        return
    end
    if ui.GetFrame(addon_name_lower .. "reroll_option") ~= nil then
        return
    end
    core_g.vlog("mini_addons: ヘアエンチャント 自動で開く設定が ON なので高度な設定を開く")
    hair_enchant_open_advanced()
end

-- reroll_option の中身(希望オプションのチェック / 目標ランク / リピート回数 / Cancel)を組む。
-- **ランクが上がったら組み直す。** 選べるオプションもその数値範囲もランクごとに違い
-- (`enchant_special_option_ratio.ies` の `AppearRatio_<rank>` が 0 のものは出ない。
-- 実データでは ALLSKILL / MSPD / walking_recover_sta / reduce_rsp_time /
-- secret_medicine_time / ignore_deadremove の 6 つが B・A でしか出ない)、
-- 一覧を作ったときのランクのまま置いておくと、上がった後は**古いランクの一覧**を
-- 見せ続けることになる。以前はランクアップで必ず止めて窓ごと畳んでいたので表に出て
-- いなかったが、止めずに続けられるようにした以上、ここで追随させる必要がある。
--
-- 組み直しても壊れないように、次の 3 つは引き継ぐこと:
--   * 希望オプションのチェック … g.need_options(Lua 側の表)から SetCheck で戻す
--   * リピート回数の入力値     … 停止判定が set_repeat_num として読んでいる。消すと止まらなくなる
--   * 目標ランク               … reroll_option の UserValue "RANK_UNTIL"(コントロールではないので残る)
hair_enchant_build_reroll_body = function(reroll_option, item_grade, item_rank)
    local high_hairenchant = ui.GetFrame("high_hairenchant")
    local gbox = reroll_option:CreateOrGetControl("groupbox", "gbox", 0, 40, 0, 0)
    AUTO_CAST(gbox)
    gbox:SetSkinName("None")
    -- 組み直す前に、消えると困る入力値を控える
    local prev_repeat = GET_CHILD_RECURSIVELY(gbox, "repeat_count")
    local prev_repeat_text = prev_repeat ~= nil and prev_repeat:GetText() or nil
    gbox:RemoveAllChild()
    -- 名前は呼び出し側(SetEventScript)が addon_name_lower から組み立てるので、必ず揃えること。
    -- 本家から移す際にここだけ "mini_addons_" のままにしてしまい、チェックが一切拾われず
    -- 「希望のオプションが出ても止まらない」形で出ていた
    function mini_addons_p_reroll_option_check(gbox, ctrl, str)
        g.need_options[ctrl:GetName()] = {
            is_check = ctrl:IsChecked(),
            text = str
        }
        hair_enchant_mark_dirty()
        core_g.vlog("mini_addons: ヘアエンチャント 希望オプション %s = %s", tostring(str),
            ctrl:IsChecked() == 1 and "ON" or "OFF")
        local bodyGbox1 = GET_CHILD_RECURSIVELY(high_hairenchant, "bodyGbox1")
        local dest = bodyGbox1:GetUserValue("DESTROY")
        local bodyGbox1_1 = GET_CHILD_RECURSIVELY(high_hairenchant, "bodyGbox1_1")
        if dest == "None" then
            bodyGbox1:SetUserValue("DESTROY", "destroy")
            DESTROY_CHILD_BYNAME(bodyGbox1, "bodyGbox1_1")
        end
        local bodyGbox1_1 = bodyGbox1:CreateOrGetControl("groupbox", "bodyGbox1_1", 5, 35, 370, 135)
        AUTO_CAST(bodyGbox1_1)
        bodyGbox1_1:RemoveAllChild()
        bodyGbox1_1:SetSkinName("None")
        bodyGbox1_1:SetGravity(ui.LEFT, ui.TOP)
        local ypos = 10
        for key, value in pairs(g.need_options) do
            if value.is_check == 1 then
                local op_name = string.format("%s %s", ClMsg("ItemRandomOptionGroupSTAT"), "{ol}" .. value.text)
                local property_text = bodyGbox1_1:CreateOrGetControl("richtext", "property_text" .. key, 5, ypos, 0, 20)
                property_text:SetText(op_name)
                ypos = ypos + 25
            end
        end
    end
    local y = 5
    -- プリセットは 1 行にまとめる(ドロップリスト + 読込 / 保存 / 削除)。
    -- 枠数は固定しない。保存を押すと名前を訊くポップアップが出て、同じ名前があれば
    -- 上書き、無ければ足す。**縦を食わないこと**を優先してこの形にしてある
    -- (以前は 4 行並べていて、オプション一覧を押し下げていた)
    local presets = hair_enchant_presets()
    local sel = tonumber(reroll_option:GetUserValue("PRESET_SEL")) or 0
    if presets[sel] == nil then
        -- 消された / まだ何も選んでいない。1 件目へ寄せたりせず「--」のままにする
        sel = 0
    end
    reroll_option:SetUserValue("PRESET_SEL", tostring(sel))
    local preset_list = gbox:CreateOrGetControl("droplist", "preset_list", 10, y + 2, 235, 20)
    AUTO_CAST(preset_list)
    preset_list:SetSkinName("droplist_normal")
    preset_list:EnableHitTest(1)
    preset_list:SetTextAlign("center", "center")
    preset_list:SetTextTooltip(g.lang == "Japanese" and
                                   "{ol}選ぶとその場で読み込みます{nl}リピート回数が変わるのはここで選んだときだけです{nl}(アクセの差し替えなどで入れ直すときは今の値のまま)" or
                                   "{ol}Selecting one loads it right away{nl}The repeat count only changes when you pick one here{nl}(automatic reloads keep the current value)")
    -- **先頭は常に「--」(未選択)。** プリセットは 1 番目以降。
    -- 先頭を 1 件目のプリセットにすると、窓を開いた直後に「プリセット名が出ているのに
    -- チェックは入っていない」という食い違った見え方になる。読み込んだとき / 保存した
    -- ときだけ、その名前が選ばれている状態にする
    preset_list:AddItem(0, "{ol}" .. (#presets == 0 and
        (g.lang == "Japanese" and "-- プリセットなし --" or "-- No presets --") or "--"), 0,
        string.format("%s_hair_enchant_preset_sel(0)", addon_name_lower))
    for i, preset in ipairs(presets) do
        preset_list:AddItem(i, "{ol}" .. tostring(preset.name), 0,
            string.format("%s_hair_enchant_preset_sel(%d)", addon_name_lower, i))
    end
    -- **SelectItem は項目のスクリプトを走らせうる。** 選んだら読み込む作りなので、
    -- 組み立て中に走ると「読込 → 組み直し → SelectItem → 読込」で止まらなくなる。
    -- 組み立ての間は選択を記録するだけにする
    hair_enchant_suppress_preset_sel = true
    preset_list:SelectItem(sel)
    hair_enchant_suppress_preset_sel = false
    local save_btn = gbox:CreateOrGetControl("button", "preset_save", 250, y, 65, 25)
    AUTO_CAST(save_btn)
    save_btn:SetSkinName("test_pvp_btn")
    save_btn:SetText("{ol}" .. (g.lang == "Japanese" and "保存" or "Save"))
    -- 何が保存されるのかは押す前に知りたいので、対象を並べておく。
    -- **項目を増減したら、ここと Mini_addons_hair_enchant_preset_save_do の中身を
    -- 必ず揃えること**(説明だけ古くなると、入っているつもりの設定が入らない)
    save_btn:SetTextTooltip(g.lang == "Japanese" and
                                "{ol}今の設定に名前を付けて保存します{nl}保存する内容:{nl}・希望オプションのチェック{nl}・目標ランク{nl}・リピート回数{nl}・演出を待たずに実行{nl}同じ名前があれば上書きします" or
                                "{ol}Save the current settings under a name{nl}What is saved:{nl}- Target option checkboxes{nl}- Target rank{nl}- Repeat count{nl}- Run without waiting for the effect{nl}Overwrites if the name exists")
    save_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_hair_enchant_preset_save_open")
    local del_btn = gbox:CreateOrGetControl("button", "preset_delete", 320, y, 65, 25)
    AUTO_CAST(del_btn)
    del_btn:SetSkinName("test_red_button")
    del_btn:SetText("{ol}" .. (g.lang == "Japanese" and "削除" or "Delete"))
    del_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_hair_enchant_preset_delete")
    -- 消す対象が決まっていないと押せない(「--」を選んでいるときは何も消せない)
    del_btn:SetEnable(presets[sel] ~= nil and 1 or 0)
    y = y + 30

    -- 自動で開く設定。プリセットと同じくアドオンの設定ファイルへ保存する
    -- 名前の揃え方は mini_addons_p_reroll_option_check のコメントと同じ
    function mini_addons_p_hair_enchant_auto_open(gbox, ctrl)
        g.settings.hair_enchant_auto_open = ctrl:IsChecked() == 1 and 1 or 0
        Mini_addons_save_settings()
        core_g.vlog("mini_addons: ヘアエンチャント 自動で開く = %s",
            g.settings.hair_enchant_auto_open == 1 and "ON" or "OFF")
    end
    local auto_open = gbox:CreateOrGetControl("checkbox", "auto_open", 10, y, 0, 20)
    AUTO_CAST(auto_open)
    auto_open:SetText("{ol}" ..
                          (g.lang == "Japanese" and "ヘアアクセを乗せたら自動で開く" or
                              "Open automatically when an item is placed"))
    auto_open:SetTextTooltip(g.lang == "Japanese" and
                                 "{ol}付与ウィンドウにヘアアクセを乗せた時点でこの窓を開きます{nl}この設定は保存されます" or
                                 "{ol}Opens this window once an item is placed{nl}This setting is saved")
    auto_open:SetEventScript(ui.LBUTTONUP, (addon_name_lower .. "_hair_enchant_auto_open"))
    auto_open:SetCheck(g.settings.hair_enchant_auto_open == 1 and 1 or 0)
    y = y + 30

    -- **希望オプションはスクロール枠へ入れる。** 一覧は 30 件を超えることがあり
    -- (ランクが上がるとさらに増える)、そのまま縦に積むと窓が画面の高さを超えて
    -- 下のリピート回数や Cancel が画面外へ出てしまう。枠の高さは固定にして、
    -- はみ出したぶんはスクロールで見せる
    -- 枠の高さは画面から決める。窓全体(上のプリセット等 + 枠 + 下の行 + 余白)が
    -- 画面の 8 割に収まるように残りを割り当てる。設定画面(Mini_addons_settings_frame)も
    -- 同じ考え方で頭打ちにしている
    local max_box_height = math.floor(ui.GetClientInitialHeight() * 0.8) - y - HAIR_ENCHANT_BOTTOM_HEIGHT
    if max_box_height < 120 then
        max_box_height = 120 -- 極端に低い解像度でも、数行は見えるようにする
    end
    local option_box = gbox:CreateOrGetControl("groupbox", "option_box", 5, y, 385, max_box_height)
    AUTO_CAST(option_box)
    option_box:SetSkinName("test_frame_midle_light")
    local OptionList, cnt = GetClassList("enchant_special_option")
    -- 目標ランクを選んだときに灰色にして無効化するため、作ったチェックの名前と
    -- 元の表示文字列を控える。表示は SetText で色タグごと差し替えるので、
    -- 戻すには元の文字列が要る(コントロール側からは読み直せない)
    g.hair_enchant_option_names = {}
    g.hair_enchant_option_labels = {}
    -- プリセットの保存でクラス名が要るので、チェック名 → クラス名だけ控える。
    -- **逆向き(クラス名 → チェック名)はここに持たないこと。** 組んだ時点のランクの
    -- ものになるため、差し替え直後に引くと古い。読込側は hair_enchant_option_map で
    -- そのつど引き直す
    g.hair_enchant_option_classes = {}
    local oy = 5
    for i = 0, cnt - 1 do
        local cls = GetClassByIndexFromList(OptionList, i)
        if cls == nil then
            break
        end
        local RangeTable = shared_enchant_special_option.get_value_range(cls.ClassName, item_grade, item_rank, 1)
        if RangeTable[1] ~= 0 and RangeTable[2] ~= 0 then
            local OptionString = string.format("%s %d~%d", ScpArgMsg(cls.ClassName), RangeTable[1], RangeTable[2])
            -- 名前は "option_text" .. (enchant_special_option の並び順)。この並びは
            -- ランクで変わらないので、組み直しても同じオプションは同じ名前になる。
            -- g.need_options もこの名前を鍵にしているため、チェックをそのまま戻せる
            local option_name = "option_text" .. i
            local option_text = option_box:CreateOrGetControl("checkbox", option_name, 5, oy, 0, 20)
            AUTO_CAST(option_text)
            option_text:SetText("{ol}" .. OptionString)
            option_text:SetEventScript(ui.LBUTTONUP, (addon_name_lower .. "_reroll_option_check"))
            option_text:SetEventScriptArgString(ui.LBUTTONUP, ScpArgMsg(cls.ClassName))
            local prev = g.need_options[option_name]
            if prev ~= nil and prev.is_check == 1 then
                option_text:SetCheck(1)
            end
            table.insert(g.hair_enchant_option_names, option_name)
            g.hair_enchant_option_labels[option_name] = OptionString
            g.hair_enchant_option_classes[option_name] = cls.ClassName
            oy = oy + 25
        end
    end
    -- 中身より枠が高いときに余白を作らないよう、実際の高さに合わせて縮める
    local option_box_height = math.min(max_box_height, oy + 5)
    option_box:Resize(385, option_box_height)
    option_box:EnableScrollBar(1)
    option_box:SetScrollPos(0)
    y = y + option_box_height + 8
    -- 組み直しで消えたオプション(上がったランクでは出なくなったもの)のチェックは、
    -- 画面に無い以上ここで落とす。残すと外せないチェックで止まり続ける
    for option_name in pairs(g.need_options) do
        if g.hair_enchant_option_labels[option_name] == nil then
            core_g.vlog("mini_addons: ヘアエンチャント %s ランクでは出ないオプションのチェックを外す(%s)",
                tostring(item_rank), tostring(g.need_options[option_name].text))
            g.need_options[option_name] = nil
        end
    end

    -- 素の演出(EFFECT_DURATION 0.5秒)を待たずに、結果が返った時点で次を撃つ。
    -- 1 回あたり 0.5 秒縮むが、素の演出と HoldUI が重なるので既定は OFF。
    -- **判定が古い状態を見る心配は無い**(結果が返ってから撃つことに変わりはない)。
    -- 崩れるのは見た目だけなので、承知のうえで使う人向けに UI から選べるようにしてある。
    -- 保存はしない。ウィンドウを開くたび OFF に戻す(付けっぱなしを忘れて
    -- 「演出が変」と後から悩まないようにするため)
    -- 名前の揃え方は mini_addons_p_reroll_option_check のコメントと同じ
    function mini_addons_p_hair_enchant_fast(gbox, ctrl)
        local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
        if reroll_option == nil then
            return
        end
        local on = ctrl:IsChecked() == 1
        reroll_option:SetUserValue("FAST", on and "yes" or "no")
        hair_enchant_mark_dirty()
        core_g.vlog("mini_addons: ヘアエンチャント 演出を待たずに実行 = %s", on and "ON" or "OFF")
    end
    y = y + 8
    local fast = gbox:CreateOrGetControl("checkbox", "fast_enchant", 10, y, 0, 20)
    AUTO_CAST(fast)
    fast:SetText("{ol}{#FF9900}" ..
                     (g.lang == "Japanese" and "演出を待たずに実行" or
                         "Run without waiting for the effect"))
    fast:SetTextTooltip(g.lang == "Japanese" and
                            "{ol}1 回あたり 0.5 秒ほど速くなります{nl}素の演出と重なるので見た目が乱れます{nl}希望オプションの判定は変わりません" or
                            "{ol}About 0.5s faster per attempt{nl}It overlaps the game's effect, so the animation looks rough{nl}Option matching is unaffected")
    fast:SetEventScript(ui.LBUTTONUP, (addon_name_lower .. "_hair_enchant_fast"))
    if reroll_option:GetUserValue("FAST") == "yes" then
        fast:SetCheck(1)
    end
    y = y + 27

    -- 名前の揃え方は mini_addons_p_reroll_option_check のコメントと同じ
    function mini_addons_p_hair_enchant_repeat(gbox, repeat_count)
        local count = tonumber(repeat_count:GetText())
        if count == nil then
            count = 0
        end
        if count < 0 then
            count = 0
        end
        SET_REPEAT_COUNT_TEXT(count)
    end
    local repeat_count = gbox:CreateOrGetControl("edit", "repeat_count", 330, y, 60, 30)
    AUTO_CAST(repeat_count)
    repeat_count:SetTypingScp((addon_name_lower .. "_hair_enchant_repeat"))
    repeat_count:SetTextTooltip(g.lang == "Japanese" and "{ol}リピート回数を入力" or
                                    "{ol}Enter the repeat count")
    repeat_count:SetFontName("white_16_ol")
    repeat_count:SetTextAlign("center", "center")
    repeat_count:SetNumberMode(1)
    if prev_repeat_text ~= nil then
        -- 組み直し。停止判定が読む上限値なので、初期値へ戻さず入力済みの値を引き継ぐ
        repeat_count:SetText(prev_repeat_text)
    else
        -- **初期値に手持ちのスクロール数を入れないこと。** 何気なく押しただけで
        -- 全部溶ける形になる。全部使いたいときは隣の ALL ボタンで明示的に入れる。
        -- 0 は素に合わせた値。素の入力欄(hairenchant_option の repeatCnt)も
        -- INI_REPEAT_COUNT が 0 を入れており、素のループも 0 と 1 はどちらも
        -- 「1 回だけ」(cnt > 1 のときだけ続行)。こちらも 0 は 1 回として扱う
        repeat_count:SetText(0)
    end

    -- 手持ちのスクロール数を入れるボタン(以前 Cancel を置いていた場所)。
    -- 止める手段は素の付与ボタン(回している間は「停止」になる)と、この窓の × で足りる
    local all_btn = gbox:CreateOrGetControl("button", "repeat_all", 260, y, 60, 30)
    AUTO_CAST(all_btn)
    all_btn:SetSkinName("test_pvp_btn")
    all_btn:SetText("{ol}ALL")
    all_btn:SetTextTooltip(g.lang == "Japanese" and "{ol}手持ちの魔法付与スクロールの数を入れます" or
                               "{ol}Fill in the number of scrolls you have")
    all_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_hair_enchant_repeat_all")

    -- 「指定したランクまで回し続ける」。希望オプションのチェックの列に混ぜると
    -- 「オプションの 1 つ」に見えるので、リピート回数と同じ行の左の空きに
    -- ドロップリストとして置く(見た目でも役割が別だと分かるようにする)。
    --
    -- 選べるのは**今のランクより上だけ**。既に届いているランクを選べると、
    -- 止まる条件が最初から満たされていて意味を成さない(A のときは選択肢が
    -- 「指定なし」だけになる)。
    --
    -- 保存はしない(素の rank_up と同じく、窓を開くたび「指定なし」に戻る)。
    -- 選択は reroll_option の UserValue "RANK_UNTIL" に入れる。窓を作り直すたび
    -- 消えるので、既定は素の GetUserValue が返す "None" = 指定なし
    -- 名前の揃え方は mini_addons_p_reroll_option_check のコメントと同じ
    -- ドロップリストの項目から呼ばれる版。**手で選んだときだけ dirty を立てる**
    -- (組み立て末尾からの呼び直しは hair_enchant_apply_rank_until を直に使う)
    function mini_addons_p_hair_enchant_rank_until(rank)
        hair_enchant_mark_dirty()
        hair_enchant_apply_rank_until(rank)
    end
    hair_enchant_apply_rank_until = function(rank)
        local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
        if reroll_option == nil then
            return
        end
        reroll_option:SetUserValue("RANK_UNTIL", rank)
        -- ランクを指定している間、希望オプションは見に行かない(下の停止判定を参照)ので、
        -- 押せるまま残すと「チェックしたのに止まらない」不具合に見える。灰色にして塞ぐ。
        -- 「ランク指定なし」へ戻したら元の表示に戻す。チェックの入り切り自体は
        -- 触らないので、戻したときに選び直す必要はない
        local disabled = hair_enchant_rank_index(rank) ~= nil
        local gbox = GET_CHILD_RECURSIVELY(reroll_option, "gbox")
        for _, option_name in ipairs(g.hair_enchant_option_names or {}) do
            local option_text = gbox and GET_CHILD_RECURSIVELY(gbox, option_name)
            if option_text ~= nil then
                AUTO_CAST(option_text)
                option_text:SetEnable(disabled and 0 or 1)
                option_text:EnableHitTest(disabled and 0 or 1)
                local label = g.hair_enchant_option_labels[option_name]
                if label ~= nil then
                    -- SetEnable(0) だけではキャプションの色が変わらない土台があるので、
                    -- 色タグでも灰色にしておく
                    option_text:SetText((disabled and "{ol}{#888888}" or "{ol}") .. label)
                end
            end
        end
        -- 素の「ランクアップ時に停止」も、目標ランク指定中は見に行かないので灰色にする
        hair_enchant_set_rank_up_enabled(not disabled)
        core_g.vlog("mini_addons: ヘアエンチャント 目標ランク = %s(希望オプションのチェック %d 件と素のランクアップ停止を%s)",
            rank == "None" and "指定なし" or rank, #(g.hair_enchant_option_names or {}),
            disabled and "無効化" or "有効化")
    end
    local rank_until = gbox:CreateOrGetControl("droplist", "rank_until", 10, y + 5, 240, 20)
    AUTO_CAST(rank_until)
    rank_until:SetSkinName("droplist_normal")
    rank_until:EnableHitTest(1)
    rank_until:SetTextAlign("center", "center")
    rank_until:SetTextTooltip(g.lang == "Japanese" and
                                  "{ol}ランクを選ぶと、そのランクへ届くまで回し続けます{nl}(希望オプションが付いても止めません)" or
                                  "{ol}Pick a rank to keep going until the item reaches it{nl}(desired options will not stop it)")
    rank_until:AddItem(0, "{ol}" .. (g.lang == "Japanese" and "ランク指定なし" or "No target rank"), 0,
        string.format("%s_hair_enchant_rank_until('None')", addon_name_lower))
    local now_index = hair_enchant_rank_index(item_rank)
    -- 組み直しのときは選んでいた目標ランクを選び直す。ランクが上がると選択肢が減る
    -- (今のランク以下は出さない)ので、番号ではなくランク名で照合すること
    local keep_rank = reroll_option:GetUserValue("RANK_UNTIL")
    local keep_index = 0
    if now_index ~= nil then
        for i = now_index + 1, #hair_enchant_rank_order do
            local target = hair_enchant_rank_order[i]
            rank_until:AddItem(i - now_index, "{ol}" ..
                string.format(g.lang == "Japanese" and "%s ランクまで回す" or "Until rank %s", target), 0,
                string.format("%s_hair_enchant_rank_until('%s')", addon_name_lower, target))
            if target == keep_rank then
                keep_index = i - now_index
            end
        end
    end
    rank_until:SelectItem(keep_index)
    -- 選択に合わせて希望オプションの有効 / 無効(灰色)も揃える。SelectItem が
    -- 項目のスクリプトを走らせるかは土台任せなので、ここで必ず 1 回通しておく。
    -- 引き継げなかった(選択肢から消えた)ときは "None" に落として指定なしへ戻す。
    -- **組み立ての一部なので dirty は立てない版を呼ぶこと**(立てると、組み直しただけで
    -- 「手で変えた」扱いになり、プリセットの入れ直しが効かなくなる)
    hair_enchant_apply_rank_until(keep_index == 0 and "None" or keep_rank)

    y = y + 30
    reroll_option:Resize(400, y + 45)
    gbox:Resize(reroll_option:GetWidth(), reroll_option:GetHeight() - 40)
    -- 高さが決まってから、下がはみ出さない位置へ寄せる。組み直しで背が伸びることも
    -- あるので、開いたときだけでなくここで毎回見ること
    local max_y = ui.GetClientInitialHeight() - reroll_option:GetHeight()
    if max_y < 0 then
        max_y = 0
    end
    if reroll_option:GetY() > max_y then
        reroll_option:SetPos(reroll_option:GetX(), max_y)
    end
    -- 「何を元に組んだか」を最後に記録する。これが hair_enchant_refresh_if_changed の
    -- 比較対象になるので、組み直したら必ず更新すること(忘れると毎回組み直し続ける)
    reroll_option:SetUserValue("BUILD_SIG", hair_enchant_build_signature(item_grade, item_rank))
end

-- ALL ボタン。手持ちの魔法付与スクロールの数をリピート回数へ入れる。
-- 窓を開いたときの初期値は 1 にしてあるので、全部使うのはここを押したときだけ
function Mini_addons_hair_enchant_repeat_all(parent, ctrl)
    local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
    local high_hairenchant = ui.GetFrame("high_hairenchant")
    if reroll_option == nil or high_hairenchant == nil then
        return
    end
    local repeat_count = GET_CHILD_RECURSIVELY(reroll_option, "repeat_count")
    if repeat_count == nil then
        return
    end
    local scroll = session.GetInvItemByGuid(high_hairenchant:GetUserValue("Enchant"))
    local count = (scroll ~= nil and scroll.count and scroll.count > 0) and scroll.count or 1
    repeat_count:SetText(tostring(count))
    -- 手で打ったときと同じく、素のリピート表示も合わせる
    SET_REPEAT_COUNT_TEXT(count)
    core_g.vlog("mini_addons: ヘアエンチャント ALL でリピート回数に手持ちのスクロール数 %d を入れた", count)
end

-- 素の「마법 부여」ボタン。**回している最中は「停止」として働かせる。**
-- 素の SEND_BTN は State が 0 のときに止める作りだが、その State が 0 になるのは
-- auto_run == 1 のときだけで、こちらのループでは立てられない(上のコメント参照)。
-- そこで押下をここで受けて、回っていれば止める。回っていなければ素へそのまま流す
function Mini_addons_HIGH_HAIRENCHANT_SEND_BTN(my_frame, my_msg)
    local frame, ctrl = g.get_event_args(my_msg)
    if g.settings.hair_enchant == 1 and hair_enchant_is_running() then
        core_g.vlog("mini_addons: ヘアエンチャント 付与ボタン(停止)が押されたので連続付与を止める")
        SET_REPEAT_COUNT_TEXT(0)
        hair_enchant_close_advanced()
        return
    end
    g.FUNCS["HIGH_HAIRENCHANT_SEND_BTN"](frame, ctrl)
end

function Mini_addons_HIGH_HAIRENCHANT_OK_BTN(my_frame, my_msg)
    local frame, ctrl = g.get_event_args(my_msg)
    -- 掛けたフックが bool=false(元の関数を呼ばない)なので、元の処理はここで自分で呼ぶ。
    -- **return を忘れないこと。** 素の HIGH_HAIRENCHANT_OK_BTN は確認ダイアログを挟まず
    -- その場で item.DoPremiumItemEnchantchip() を投げるため、下の else へ抜けると
    -- 1 回の押下で 2 回付与してしまう(この機能が OFF = 既定のときに必ず通る経路)
    if g.settings.hair_enchant == 0 then
        g.FUNCS["HIGH_HAIRENCHANT_OK_BTN"](frame, ctrl)
        return
    end
    local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
    if reroll_option and reroll_option:IsVisible() == 1 then
        -- 停止条件は後から追いにくいので、回し始めに 1 回だけ両方の設定を出す
        local high_hairenchant = ui.GetFrame("high_hairenchant")
        local rank_up = high_hairenchant and GET_CHILD_RECURSIVELY(high_hairenchant, "rank_up")
        local rank_until = reroll_option:GetUserValue("RANK_UNTIL")
        -- 連続で回すかどうかは**設定画面(この自前の窓)を開いたかどうか**で決める。
        -- 開いていなければ下の else で素をそのまま呼ぶ(＝1 回だけ)。
        -- 窓を開いた時点で連続付与の意思表示とみなすので、希望オプションも目標ランクも
        -- 未設定のまま回すこともできる(そのときはリピート回数だけが止める条件になる。
        -- 既定値は 0(＝1 回)なので、何もしなければ 1 回で終わる。全部使うのは
        --  ALL ボタンを押したときだけ)
        core_g.vlog(
            "mini_addons: ヘアエンチャント 開始(ランクアップ時に停止=%s / 目標ランク=%s / 演出を待たずに実行=%s)",
            (rank_up ~= nil and rank_up:IsChecked() == 1) and "ON" or "OFF",
            hair_enchant_rank_index(rank_until) == nil and "指定なし" or rank_until,
            reroll_option:GetUserValue("FAST") == "yes" and "ON" or "OFF")
        -- 1 回目はすぐ撃つ。以降は結果が返るまで下の関門で待つ
        reroll_option:SetUserValue("READY", "yes")
        frame:RunUpdateScript("Mini_addons_HIGH_HAIRENCHANT_OK_BTN_", HAIR_ENCHANT_TICK)
        -- 素の付与ボタンを「停止」に変える(押されたら止められるように)
        hair_enchant_sync_send_button()
    else
        core_g.vlog("mini_addons: ヘアエンチャント 設定画面を開いていないので素のまま 1 回だけ実行する")
        g.FUNCS["HIGH_HAIRENCHANT_OK_BTN"](frame, ctrl)
    end
end

-- 連続付与を回している最中かどうか。合図を受ける 2 つのフックで共通に使う
local function hair_enchant_running_frame()
    if g.settings.hair_enchant == 0 then
        return nil
    end
    local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
    if reroll_option == nil or reroll_option:IsVisible() == 0 then
        return nil
    end
    -- 手で 1 回だけ付与したときは何もしない
    if reroll_option:GetUserValue("STATUS") ~= "is_repeat" then
        return nil
    end
    return reroll_option
end

-- 結果を受けた時点の合図。**「演出を待たずに実行」が ON のときだけ**使う。
--
-- **HIGH_HAIRENCHANT_SUCEECD_RESULT ではなく SUCEECD の方を使うこと。**
-- こちらの停止判定はアイテムの実データ(obj["HatPropName_1..3"])を読むので、
-- それが更新される前に合図を出すと、古い状態を見て「まだ付いていない」と誤判定し、
-- 当たりを潰してもう 1 回撃つ。SUCEECD は HIGH_HAIRENCHANT_UPDATE_ITEM_OPTION を
-- 通す側なので、ここまで来ていればアイテムの状態は新しいと分かる。
-- (SUCEECD_RESULT は表示用の値を引数で受け取るだけで、実データの更新とは別)
function Mini_addons_HIGH_HAIRENCHANT_SUCEECD(my_frame, my_msg)
    local reroll_option = hair_enchant_running_frame()
    if reroll_option == nil or reroll_option:GetUserValue("FAST") ~= "yes" then
        return
    end
    reroll_option:SetUserValue("READY", "yes")
end

-- 素の演出が終わって HoldUI が解けた合図。ここで「次を撃ってよい」を立てる。
-- 素より先に撃つと演出と HoldUI が重なるので、結果受信(HIGH_HAIRENCHANT_SUCEECD_RESULT)
-- ではなくここを使っている。1 回あたり EFFECT_DURATION(0.5秒)ぶん譲る代わりに、
-- 素の見た目を一切崩さない
function Mini_addons__HIGH_HAIRENCHANT_SUCCESS(my_frame, my_msg)
    local reroll_option = hair_enchant_running_frame()
    if reroll_option == nil then
        return
    end
    -- 「演出を待たずに実行」が ON なら、ひとつ手前の合図で既に立っている(二重でも害は無い)
    reroll_option:SetUserValue("READY", "yes")
end

function Mini_addons_HIGH_HAIRENCHANT_OK_BTN_(frame, ctrl)
    if frame == nil then
        frame = ui.GetFrame("high_hairenchant")
    end
    frame = frame:GetTopParentFrame()
    local enchantGuid = frame:GetUserValue("Enchant")
    local itemIES = frame:GetUserValue("itemIES")
    if "None" == itemIES or "None" == enchantGuid then
        return 0
    end
    local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
    if not reroll_option and reroll_option:IsVisible() == 0 and reroll_option:GetUserValue("STATUS") == "None" then
        item.DoPremiumItemEnchantchip(itemIES, enchantGuid)
        return 0
    end
    -- ここから下は「1 回分」の処理。**前の結果が返るまで通さない。**
    -- 判定は obj["HatPropName_1..3"](アイテムの今のオプション)を読むので、結果より先に
    -- 進むと古い状態を見て「まだ付いていない」と誤判定し、当たったロールを潰して
    -- もう 1 回撃つことになる。以前は 1.0 秒固定で撃っていたため、応答がそれより
    -- 遅い環境では実際にこれが起きうる作りだった。
    -- 合図は Mini_addons__HIGH_HAIRENCHANT_SUCCESS(素の演出が終わる所)が立てる
    -- 前の結果が届くのを待つ関門。待つ理由は 2 つあり、**どちらも同じ見張りタイマーに
    -- 掛けること**(片方だけ先に return すると、見張りへ辿り着けず永久に空回りする)。
    --
    -- (1) 合図(READY)がまだ来ていない
    -- (2) 「演出を待たずに実行」で、合図は来たがアイテムの中身が前のまま。
    --     このモードは素の演出を待たずに合図を受けるぶん、実データの更新より合図が
    --     先に来る余地がある。そのまま進むと古い状態で「まだ付いていない」と誤判定し、
    --     当たりを潰してもう 1 回撃つ(実際に報告された)。指紋が変わるまで待てば、
    --     合図の順序が実際どうであっても成立する
    local waiting = nil
    if reroll_option:GetUserValue("READY") ~= "yes" then
        waiting = "結果の合図が来ない"
    elseif reroll_option:GetUserValue("FAST") == "yes" and
        hair_enchant_option_fingerprint(itemIES) == reroll_option:GetUserValue("FIRED_FP") then
        -- 振り直しで偶然まったく同じ 3 つが出たときもここに入るが、下の見張りが
        -- 止めるので当たりを潰すことはない(止まるだけ)
        waiting = "オプションが前のまま変わらない"
    end
    if waiting ~= nil then
        local fired_at = tonumber(reroll_option:GetUserValue("FIRED_AT")) or 0
        if os.time() - fired_at < HAIR_ENCHANT_WATCHDOG then
            return 1
        end
        -- **ここで撃ち直さないこと。**
        -- 応答が遅れているだけだと、まだ飛んでいる 1 発と重ねて撃つことになる。
        -- そうなると「希望オプションが付いた結果」が届いて確認ダイアログを出した直後に、
        -- 余分な 1 発の結果が届いて振り直され、当たりが消える(実際に報告された)。
        -- 黙って止まるのを避けるのが目的なので、**撃たずに止めて知らせる**方に倒す。
        -- 続けたければもう一度押せばよく、素材も当たりも失わない
        core_g.vlog("mini_addons: ヘアエンチャント 停止(%s まま %s 秒経過 / 撃ち直しはしない)", waiting,
            tostring(HAIR_ENCHANT_WATCHDOG))
        ui.SysMsg(g.lang == "Japanese" and
                      "魔法付与の結果が返らないため連続付与を止めました。もう一度お試しください" or
                      "Stopped: no result came back from the server. Please try again")
        reroll_option:SetUserValue("REPERT", "None")
        reroll_option:SetUserValue("STATUS", "None")
        return 0
    end
    reroll_option:SetUserValue("READY", "no")
    reroll_option:SetUserValue("FIRED_AT", tostring(os.time()))
    local repeatCount = GET_CHILD_RECURSIVELY(frame, "repeatCount")
    local repeat_count = GET_CHILD_RECURSIVELY(reroll_option, "repeat_count")
    local set_repeat_num = tonumber(repeat_count:GetText())
    -- **空欄を放置しないこと。** tonumber("") は nil なので、下の上限判定
    -- (count >= set_repeat_num)が常に偽になって止まらなくなるうえ、
    -- 表示の set_repeat_num - count が nil の引き算で落ちる。
    -- 0 以下は「1 回だけ」として扱う。素も 0 と 1 を区別しない(cnt > 1 のときだけ続行)
    -- ので、初期値の 0 をそのまま押したら 1 回、という素と同じ動きになる。
    -- **空欄は入力欄にも 0 を書き戻す。** 空欄のままだと、いくつで止まるのか
    -- 画面から読み取れない(以前は手持ちのスクロール数と解釈していたが、
    -- うっかり全部溶ける側に倒れるのでやめた。全部使いたいときは ALL ボタン)
    if set_repeat_num == nil then
        repeat_count:SetText("0")
        core_g.vlog("mini_addons: ヘアエンチャント リピート回数が空だったので 0(＝1 回)を入れた")
    end
    if set_repeat_num == nil or set_repeat_num < 1 then
        set_repeat_num = 1
    end
    local count = reroll_option:GetUserIValue("REPERT")
    -- == ではなく >=。回している最中に入力欄の数字を今の回数より小さくされると、
    -- == では一致する瞬間が来ずに止まらなくなる
    if count >= set_repeat_num then
        core_g.vlog("mini_addons: ヘアエンチャント 停止(リピート上限 %s 回)", tostring(set_repeat_num))
        repeatCount:SetTextByKey("value", string.format("%s : %d", ClMsg("REPEAT"), set_repeat_num - count))
        reroll_option:SetUserValue("REPERT", "None")
        reroll_option:SetUserValue("STATUS", "None")
        return 0
    end
    -- **スクロールを使い切ったら、上限に届いていなくてもここで終わり。**
    -- 素は 1 スタック使い切ると HIGH_HAIRENCHANT_SUCEECD で Enchant を次のスタックへ
    -- 差し替える。それでも引けない = 本当に在庫が尽きたとき。
    -- 放っておくと引けない GUID のまま撃ち続け、結果が返らないまま見張りタイマーの
    -- 「結果が返らない」で止まることになり、何が起きたのか分からない
    -- (リピート回数に手持ちより多い数を入れたときや、その数を保存したプリセットを
    --  読み込んだときに必ず通る経路)
    if session.GetInvItemByGuid(enchantGuid) == nil then
        core_g.vlog("mini_addons: ヘアエンチャント 停止(魔法付与スクロールを使い切った / %d 回実施)", count)
        repeatCount:SetTextByKey("value", string.format("%s : %d", ClMsg("REPEAT"), 0))
        reroll_option:SetUserValue("REPERT", "None")
        reroll_option:SetUserValue("STATUS", "None")
        ui.SysMsg(g.lang == "Japanese" and "魔法付与スクロールを使い切ったので連続付与を終了しました" or
                      "Stopped: you have run out of enchant scrolls")
        return 0
    end
    local invItem = session.GetInvItemByGuid(itemIES)
    if nil == invItem then
        return
    end
    local obj = GetIES(invItem:GetObject())
    local item_grade, item_rank = get_current_enchant_item_grade_and_rank()
    local befor_rank = reroll_option:GetUserValue("RANK")
    local rank_up = GET_CHILD_RECURSIVELY(frame, "rank_up")
    -- 素の "ランクアップ時に停止"。素は HIGH_HAIRENCHANT_SUCEECD_RESULT で
    -- GET_CHECKBOX_STATE() を見て判定しているが、自前のループを回している間は
    -- そちらが実質発火しない(素の判定は hairenchant_option 側のリピート数を見るが、
    -- この機能が ON のときはその窓を閉じている)ので、ここで見て同じ挙動にする。
    -- **条件に入れ忘れると、チェックの ON / OFF に関わらず必ず止まる**
    -- (実際にそうなっていて「チェックボックスが効かない」と報告された)
    local rank_check = rank_up ~= nil and rank_up:IsChecked() == 1
    -- 目標ランク(ドロップリスト)。指定があるときはそちらが優先で、素のチェックは見ない。
    -- 「A まで回す」と言っているのに途中の D → C で止まっては指定した意味が無いため
    local rank_until = reroll_option:GetUserValue("RANK_UNTIL")
    local rank_until_index = hair_enchant_rank_index(rank_until)
    local now_index = hair_enchant_rank_index(item_rank)
    local ranked_up = befor_rank ~= "None" and item_rank ~= befor_rank
    if rank_until_index ~= nil then
        if now_index ~= nil and now_index >= rank_until_index then
            core_g.vlog("mini_addons: ヘアエンチャント 停止(目標ランク %s へ到達 %s → %s)",
                tostring(rank_until), tostring(befor_rank), tostring(item_rank))
            imcAddOn.BroadMsg("NOTICE_Dm_TrapPlus", "{st41b}" .. ClMsg("MagicAutoRankUpMessage"), 5.0)
            imcSound.PlaySoundEvent("sys_transcend_success")
            reroll_option:SetUserValue("REPERT", "None")
            reroll_option:SetUserValue("STATUS", "None")
            Mini_addons_HIGH_HAIRENCHANT_CLOSE_BTN(nil, "")
            return 0
        end
        if ranked_up then
            core_g.vlog("mini_addons: ヘアエンチャント ランクアップ %s → %s(目標 %s には未到達なので続行)",
                tostring(befor_rank), tostring(item_rank), tostring(rank_until))
        end
    elseif ranked_up then
        if rank_check then
            core_g.vlog("mini_addons: ヘアエンチャント 停止(ランクアップ %s → %s / 素のランクアップ時に停止)",
                tostring(befor_rank), tostring(item_rank))
            imcAddOn.BroadMsg("NOTICE_Dm_TrapPlus", "{st41b}" .. ClMsg("MagicAutoRankUpMessage"), 5.0)
            imcSound.PlaySoundEvent("sys_transcend_success")
            reroll_option:SetUserValue("REPERT", "None")
            reroll_option:SetUserValue("STATUS", "None")
            Mini_addons_HIGH_HAIRENCHANT_CLOSE_BTN(nil, "")
            return 0
        end
        core_g.vlog("mini_addons: ヘアエンチャント ランクアップ %s → %s したが停止設定が OFF なので続行",
            tostring(befor_rank), tostring(item_rank))
    end
    if ranked_up then
        -- 止めずに続けるので、上がったランクで一覧を組み直す(組み直す理由は
        -- hair_enchant_build_reroll_body のコメントを参照)。ここを飛ばすと、
        -- 上のランクでしか出ないオプション(ALLSKILL / MSPD など)を選べないまま
        -- 古い数値範囲を見せ続けることになる。
        -- 印で比べる方(監視スクリプトと同じ経路)を通すので、先に組み直されていれば空振りする
        hair_enchant_refresh_if_changed(reroll_option)
    end
    reroll_option:SetUserValue("RANK", item_rank)
    function mini_addons_hair_enchant_msgbox(boolean, frame_name, itemIES, enchantGuid)
        local frame = ui.GetFrame(frame_name)
        frame:StopUpdateScript("Mini_addons_HIGH_HAIRENCHANT_OK_BTN_")
        local reroll_option = ui.GetFrame(addon_name_lower .. "reroll_option")
        if reroll_option == nil then
            -- 返事を待っている間に窓が畳まれた(停止ボタン / × / 素の窓を閉じた)。
            -- 「続ける」でも、もう回すものが無いので何もしない。
            -- ここを見ずに進むと reroll_option が nil のまま触って落ちる
            core_g.vlog("mini_addons: ヘアエンチャント 確認の返事(%s)が来たが窓が無いので何もしない",
                tostring(boolean))
            return
        end
        reroll_option:SetUserValue("ASKING", "None")
        if boolean == "YES" then
            reroll_option:SetUserValue("FIRED_FP", hair_enchant_option_fingerprint(itemIES))
            item.DoPremiumItemEnchantchip(itemIES, enchantGuid)
            reroll_option:SetUserValue("REPERT", reroll_option:GetUserIValue("REPERT") + 1)
            Mini_addons_HIGH_HAIRENCHANT_OK_BTN(nil, "HIGH_HAIRENCHANT_OK_BTN")
            -- ここでは既に 1 回撃っている。OK_BTN が「1 回目はすぐ撃つ」ために立てた
            -- READY を倒して、この結果が返るまで待たせること(倒さないと結果を待たずに
            -- 次を撃ち、判定が古いオプションを見る)
            reroll_option:SetUserValue("READY", "no")
            reroll_option:SetUserValue("FIRED_AT", tostring(os.time()))
        else
            Mini_addons_HIGH_HAIRENCHANT_CLOSE_BTN(nil, "")
        end
    end
    local margin = reroll_option:GetMargin()
    reroll_option:SetMargin(margin.left, margin.top, 905, margin.bottom)
    local map_frame = ui.GetFrame("map")
    local width = map_frame:GetWidth()
    local retio = width / ui.GetClientInitialWidth()
    -- 目標ランクを指定しているときは希望オプションで止めない。
    -- 全スキル系(下の ALLSKILL_ 分岐)も同じく素通りさせる
    for key, value in pairs(g.need_options) do
        if rank_until_index == nil and value.is_check == 1 then
            local target_text = value.text
            for i = 1, 3 do
                local propName = "HatPropName_" .. i
                local propValue = "HatPropValue_" .. i
                if obj[propValue] ~= 0 and obj[propName] ~= "None" then
                    local yes_scp = string.format("mini_addons_hair_enchant_msgbox('%s','%s','%s','%s')", "YES",
                        frame:GetName(), itemIES, enchantGuid)
                    local no_scp = string.format("mini_addons_hair_enchant_msgbox('%s','%s','%s','%s')", "NO",
                        frame:GetName(), itemIES, enchantGuid)
                    local msg = string.format(g.lang == "Japanese" and "{#FFFFFF}{ol}続けますか？" or
                                                  "{#FFFFFF}{ol}Do you want to continue? ")
                    if string.find(obj[propName], "ALLSKILL_") == nil then
                        if target_text == ScpArgMsg(obj[propName]) then
                            core_g.vlog("mini_addons: ヘアエンチャント 停止(希望オプション %s が付いた)",
                                tostring(target_text))
                            if margin.right == 905 then
                                reroll_option:SetMargin(margin.left, margin.top, 1150 * retio, margin.bottom)
                            end
                            repeatCount:SetTextByKey("value",
                                string.format("%s : %d", ClMsg("REPEAT"), set_repeat_num - count))
                            local befor_rank = reroll_option:GetUserValue("RANK")
                            reroll_option:SetUserValue("ASKING", "yes")
                            ui.MsgBox(msg, yes_scp, no_scp)
                            return 0
                        end
                    else
                        -- 全スキル系は付く名前が ALLSKILL_<職業> で、チェックボックス側の
                        -- クラス名 ALLSKILL とは一致しない。そのため本家から「チェックの
                        -- 有無に関わらず止める」挙動をそのまま引き継いでいる
                        core_g.vlog("mini_addons: ヘアエンチャント 停止(全スキル系 %s が付いた)",
                            tostring(obj[propName]))
                        if margin.right == 905 then
                            reroll_option:SetMargin(margin.left, margin.top, 1150 * retio, margin.bottom)
                        end
                        repeatCount:SetTextByKey("value",
                            string.format("%s : %d", ClMsg("REPEAT"), set_repeat_num - count))
                        reroll_option:SetUserValue("ASKING", "yes")
                        ui.MsgBox(msg, yes_scp, no_scp)
                        return 0
                    end
                end
            end
        end
    end
    reroll_option:SetGravity(ui.RIGHT, ui.TOP)
    local margin = reroll_option:GetMargin()
    reroll_option:SetMargin(margin.left, margin.top, 905, margin.bottom)
    reroll_option:SetPos(reroll_option:GetX(), frame:GetY())
    -- 撃つ前の中身を控える。次の回でこれと同じなら結果がまだ届いていない
    reroll_option:SetUserValue("FIRED_FP", hair_enchant_option_fingerprint(itemIES))
    item.DoPremiumItemEnchantchip(itemIES, enchantGuid)
    repeatCount:SetTextByKey("value", string.format("%s : %d", ClMsg("REPEAT"), set_repeat_num - count))
    reroll_option:SetUserValue("REPERT", reroll_option:GetUserIValue("REPERT") + 1)
    reroll_option:SetUserValue("STATUS", "is_repeat")
    return 1
end
-- チャットフレーム移動のワイドモニター制限解除
function Mini_addons__PROCESS_MOVE_MAIN_POPUPCHAT_FRAME(my_frame, my_msg)
    local frame = g.get_event_args(my_msg)
    frame:RunUpdateScript("Mini_addons_PROCESS_MOVE_MAIN_POPUPCHAT_FRAME", 0.1)
end

function Mini_addons_PROCESS_MOVE_MAIN_POPUPCHAT_FRAME(frame)
    if mouse.IsLBtnPressed() == 0 then
        MOVE_FRAME_MAIN_POPUP_CHAT_END(frame)
        return 0
    end
    local ratio = option.GetClientHeight() / option.GetClientWidth()
    local limit_offset = 10
    local limit_max_w
    local limit_max_h
    if g.settings.chat_frame == 1 then
        limit_max_w = ui.GetSceneWidth() - limit_offset
        limit_max_h = limit_max_w * ratio - limit_offset
    else
        limit_max_w = ui.GetSceneWidth() / ui.GetRatioWidth() - limit_offset
        limit_max_h = limit_max_w * ratio - limit_offset * 12
    end
    local mx, my = GET_MOUSE_POS()
    mx = mx / ui.GetRatioWidth()
    my = my / ui.GetRatioHeight()
    local prev_mouse_x = frame:GetUserIValue("MOUSE_X")
    local prev_mouse_y = frame:GetUserIValue("MOUSE_Y")
    local diff_x = (mx - prev_mouse_x)
    local diff_y = (my - prev_mouse_y)
    local new_x = frame:GetUserIValue("BEFORE_W")
    local new_y = frame:GetUserIValue("BEFORE_H")
    new_x = new_x + diff_x
    new_y = new_y + diff_y
    if new_x < limit_offset then
        new_x = limit_offset
    end
    if new_y < limit_offset then
        new_y = limit_offset
    end
    local frame_w = frame:GetWidth()
    local frame_h = frame:GetHeight()
    if (new_x + frame_w) > limit_max_w then
        new_x = limit_max_w - frame_w
    end
    if (new_y + frame_h) > limit_max_h then
        new_y = (limit_max_h - frame_h)
    end
    frame:SetOffset(new_x, new_y)
    return 1
end
-- ヴァカリネを伝える
function Mini_addons_vakarine_notice()
    if g.settings.vakarine == 0 then
        return
    end
    local map_name = session.GetMapName()
    local map_cls = GetClass("Map", map_name)
    local keyword = TryGetProp(map_cls, "Keyword", "None")
    local keyword_table = StringSplit(keyword, ";")
    if table.find(keyword_table, "IsRaidField") == 0 then
        return
    end
    local equip_item_list = session.GetEquipItemList()
    local equip_guid_list = equip_item_list:GetGuidList()
    local count = equip_guid_list:Count()
    local vakarine_count = 0
    local max_option = MAX_OPTION_EXTRACT_COUNT or 6
    for i = 0, count - 1 do
        local guid = equip_guid_list:Get(i)
        if guid ~= "0" then
            local equip_item = equip_item_list:GetItemByGuid(guid)
            if equip_item and equip_item:GetObject() then
                local item = GetIES(equip_item:GetObject())
                for j = 1, max_option do
                    local prop_name = "RandomOption_" .. j
                    local cls_msg = ScpArgMsg(item[prop_name])
                    if string.find(cls_msg, "vakarine_bless") then
                        vakarine_count = vakarine_count + 1
                    end
                end
            end
        end
    end
    if vakarine_count >= 5 then
        ui.Chat("!! " .. "vakarine")
    end
end
-- スキル連打音消す
function Mini_addons_ICON_USE(object, re_action)
    local original_func = g.FUNCS["ICON_USE"]
    if g.settings.skill_cool_sound == 0 then
        if original_func then
            original_func(object, re_action)
        end
        return
    end
    if object then
        local icon = tolua.cast(object, "ui::CIcon")
        local icon_info = icon:GetInfo()
        local category = icon_info:GetCategory()
        if category == "Skill" then
            if ICON_UPDATE_SKILL_COOLDOWN(icon) > 0 then
                return
            end
        end
    end
    if original_func then
        original_func(object, re_action)
    end
end
-- コインショップの数値を拡張
function Mini_addons_EARTHTOWERSHOP_CHANGECOUNT_NUM_CHANGE(ctrlset, change)
    if g.settings.coin_count ~= 1 then
        if g.FUNCS["EARTHTOWERSHOP_CHANGECOUNT_NUM_CHANGE"] then
            g.FUNCS["EARTHTOWERSHOP_CHANGECOUNT_NUM_CHANGE"](ctrlset, change)
        end
        return
    end
    local recipe_cls = GetClass("ItemTradeShop", ctrlset:GetName())
    local edit_item_count = GET_CHILD_RECURSIVELY(ctrlset, "itemcount")
    local count_text = tonumber(edit_item_count:GetText()) or 0
    count_text = count_text + change
    local target_acc = TryGetProp(recipe_cls, "TargetAccountProperty", "None")
    local max_target_acc = TryGetProp(recipe_cls, "MaxTargetAccountProperty", 99999)
    if target_acc ~= "None" then
        local now = TryGetProp(GetMyAccountObj(), target_acc, 0)
        if now + count_text > max_target_acc then
            count_text = math.max(0, max_target_acc - now)
        end
    end
    if count_text < 0 then
        count_text = 0
    elseif count_text > 99999 then
        count_text = 99999
    end
    if recipe_cls.NeedProperty ~= "None" then
        local s_obj = GetSessionObject(GetMyPCObject(), "ssn_shop")
        local s_count = TryGetProp(s_obj, recipe_cls.NeedProperty)
        if s_count < count_text then
            count_text = s_count
        end
    end
    if recipe_cls.AccountNeedProperty ~= "None" then
        local a_obj = GetMyAccountObj()
        local s_count = TryGetProp(a_obj, recipe_cls.AccountNeedProperty)
        local frame = ui.GetFrame("earthtowershop")
        local shop_type = frame:GetUserValue("SHOP_TYPE")
        if IS_OVERBUY_ITEM(shop_type, recipe_cls, a_obj) == true then
            s_count = count_text
            if IS_EXCEED_OVERBUY_COUNT(shop_type, a_obj, recipe_cls, 1) == true then
                s_count = 0
            end
            local max_over_buy = TryGetProp(recipe_cls, "MaxOverBuyCount", 100)
            local current_over_buy = TryGetProp(a_obj, TryGetProp(recipe_cls, "OverBuyProperty", "None"), 0)
            count_text = max_over_buy - current_over_buy
        end
        if s_count < count_text then
            count_text = s_count
        end
    end
    edit_item_count:SetText(count_text)
    return count_text
end
-- 4人以下の入場確認スキップ
function Mini_addons_INDUNENTER_REQ_UNDERSTAFF_ENTER_ALLOW(parent, ctrl)
    local top_frame = parent:GetTopParentFrame()
    local use_count = tonumber(top_frame:GetUserValue("multipleCount"))
    if use_count > 0 then
        local multiple_item_list = GET_INDUN_MULTIPLE_ITEM_LIST()
        for i = 1, #multiple_item_list do
            local item_name = multiple_item_list[i]
            local inv_item = session.GetInvItemByName(item_name)
            if inv_item ~= nil and inv_item.isLockState then
                ui.SysMsg(ClMsg("MaterialItemIsLock"))
                return
            end
        end
    end
    local with_match_mode = top_frame:GetUserValue("WITHMATCH_MODE")
    if top_frame:GetUserValue("AUTOMATCH_MODE") ~= "YES" and with_match_mode == "NO" then
        ui.SysMsg(ScpArgMsg("EnableWhenAutoMatching"))
        return
    end
    local indun_type = top_frame:GetUserIValue("INDUN_TYPE")
    local indun_cls = GetClassByType("Indun", indun_type)
    local min_member = TryGetProp(indun_cls, "UnderstaffEnterAllowMinMember")
    if min_member == nil then
        return
    end
    local yes_scp_str = "_INDUNENTER_REQ_UNDERSTAFF_ENTER_ALLOW()"
    local client_msg = ScpArgMsg("ReallyAllowUnderstaffMatchingWith{MIN_MEMBER}?", "MIN_MEMBER", min_member)
    if INDUNENTER_CHECK_UNDERSTAFF_MODE_WITH_PARTY(top_frame) == true then
        client_msg = ClMsg("CancelUnderstaffMatching")
    end
    if with_match_mode == "YES" then
        yes_scp_str = "ReqUnderstaffEnterAllowModeWithParty(" .. indun_type .. ")"
    end
    if g.settings.under_staff == 1 then
        if with_match_mode == "NO" then
            _INDUNENTER_REQ_UNDERSTAFF_ENTER_ALLOW()
            return
        end
    end
    ui.MsgBox(client_msg, yes_scp_str, "None")
end
-- ヴェルニケ階数を覚える
function Mini_addons_INDUN_EDITMSGBOX_FRAME_OPEN(type, clmsg, desc, yes_scp, no_scp, min_number, max_number,
    default_number)
    if g.settings.velnice.use == 0 then
        if g.FUNCS["INDUN_EDITMSGBOX_FRAME_OPEN"] then
            g.FUNCS["INDUN_EDITMSGBOX_FRAME_OPEN"](type, clmsg, desc, yes_scp, no_scp, min_number, max_number,
                default_number)
        end
        return
    end
    default_number = g.settings.velnice.level
    ui.OpenFrame("indun_editmsgbox")
    local frame = ui.GetFrame("indun_editmsgbox")
    frame:EnableHide(1)
    frame:SetUserValue("user_value", type)
    local text = GET_CHILD_RECURSIVELY(frame, "text")
    text:SetText(clmsg)
    local text_desc = GET_CHILD_RECURSIVELY(frame, "text_desc")
    text_desc:SetText(desc)
    local edit = GET_CHILD_RECURSIVELY(frame, "edit")
    edit:SetText(default_number)
    edit:SetNumberMode(1)
    edit:SetMaxNumber(max_number)
    edit:SetMinNumber(min_number)
    edit:AcquireFocus()
    local yes_btn = GET_CHILD_RECURSIVELY(frame, "yesBtn", "ui::CButton")
    yes_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_INDUN_EDITMSGBOX_FRAME_OPEN_YES")
    yes_btn:SetEventScriptArgString(ui.LBUTTONUP, yes_scp)
    local no_btn = GET_CHILD_RECURSIVELY(frame, "noBtn", "ui::CButton")
    no_btn:SetEventScript(ui.LBUTTONUP, "_INDUN_EDITMSGBOX_FRAME_OPEN_NO")
    no_btn:SetEventScriptArgString(ui.LBUTTONUP, no_scp)
    yes_btn:ShowWindow(1)
    no_btn:ShowWindow(1)
end

function Mini_addons_SOLO_D_TIMER_UPDATE_TEXT_GAUGE(frame, msg, arg_str)
    if g.settings.velnice.use == 0 then
        return
    end
    local argument_list = StringSplit(arg_str, ";")
    local current_wave = tonumber(argument_list[3])
    local timer_frame = ui.GetFrame("solo_d_timer")
    local last_wave = timer_frame:GetUserIValue("LAST_WAVE")
    if last_wave ~= current_wave and current_wave ~= 1 then
        local remain_time_value = GET_CHILD_RECURSIVELY(timer_frame, "remaintimeValue")
        local min = remain_time_value:GetTextByKey("min")
        local sec = string.format("%02d", tonumber(remain_time_value:GetTextByKey("sec")))
        imcAddOn.BroadMsg("NOTICE_Dm_stage_start",
            string.format("{nl} {nl} {nl} {nl} {nl} {nl} {nl}{@st55_a}Round %s / 8 Fight{nl}{@st64}Remain Time %s : %s",
                current_wave - 1, min, sec), 2.0)
        timer_frame:SetUserValue("LAST_WAVE", current_wave)
    end
end

function Mini_addons_INDUN_EDITMSGBOX_FRAME_OPEN_YES(parent, ctrl, arg_str, arg_num)
    local edit = GET_CHILD_RECURSIVELY(parent, "edit")
    local text = edit:GetText()
    g.settings.velnice.level = tonumber(text)
    Mini_addons_save_settings()
    local scp = _G[arg_str]
    if scp ~= nil then
        local user_value = tonumber(parent:GetUserValue("user_value"))
        scp(user_value, text)
    end
    ui.CloseFrame("indun_editmsgbox")
end
-- PTバフの表示非表示切り替え
-- 一覧に出すバフを列挙する。**表示と一括操作で必ずこれを共有すること。**
-- 条件(Group1 / ShowIcon / TeamLevel 除外 / 検索語 / アイコン無しの除外)が 2 箇所に
-- 分かれると、「見えているものと一括操作の対象」が食い違って、出ていないバフまで
-- 勝手に切り替わる。
function Mini_addons_buff_list_each(filter_text, func)
    local cls_list, count = GetClassList("Buff")
    for i = 0, count - 1 do
        local buff_cls = GetClassByIndexFromList(cls_list, i)
        if buff_cls and buff_cls.Group1 == "Buff" and IS_PARTY_INFO_SHOWICON(buff_cls.ShowIcon) == true and
            buff_cls.ClassName ~= "TeamLevel" then
            local buff_name = dictionary.ReplaceDicIDInCompStr(buff_cls.Name)
            if filter_text == "" or string.find(buff_name, filter_text) then
                local image_name = GET_BUFF_ICON_NAME(buff_cls)
                if buff_name ~= "None" and image_name ~= "icon_None" then
                    func(i, buff_cls, buff_name, image_name)
                end
            end
        end
    end
end

-- いま検索欄に入っている絞り込み。一括操作の対象を「見えている分」に合わせるために使う。
function Mini_addons_buff_list_filter_text(buff_list)
    local search_edit = GET_CHILD_RECURSIVELY(buff_list, "search_edit")
    return search_edit and search_edit:GetText() or ""
end

-- 一覧に出ているバフをまとめて ON / OFF にする(num: 1=ON, 0=OFF)。
function Mini_addons_buff_list_set_all(frame, ctrl, str, num)
    local value = num == 1 and 1 or 0
    local filter_text = Mini_addons_buff_list_filter_text(frame)
    local changed = 0
    g.buffs = g.buffs or {}
    Mini_addons_buff_list_each(filter_text, function(_, buff_cls)
        local key = tostring(buff_cls.ClassID)
        -- 未設定は「表示する(1)」扱い。既定値と同じ値を入れても変更にはしない。
        if (g.buffs[key] or 1) ~= value then
            g.buffs[key] = value
            changed = changed + 1
        end
    end)
    Mini_addons_save_buffs()
    core_g.vlog("mini_addons: バフ一覧を一括変更 value=%d 変更 %d 件 filter=%s", value, changed, tostring(filter_text))
    ui.SysMsg(g.lang == "Japanese" and
                  string.format("{ol}{#00BFFF}[Nexus Addons P] バフ表示を %d 件 %s にしました", changed,
            value == 1 and "ON" or "OFF") or
                  string.format("{ol}{#00BFFF}[Nexus Addons P] Turned %s %d buff(s)", value == 1 and "ON" or "OFF",
            changed))
    Mini_addons_buff_list_open(frame, ctrl, filter_text, num)
end

-- いまのチェック状態を控える。控えは 1 つだけで、押すたびに上書きする。
function Mini_addons_buff_list_backup(frame, ctrl, str, num)
    g.buffs = g.buffs or {}
    -- 控えも .lua。json のままにすると、復元のたびに 5 秒の json.decode を通る
    -- (中身は buffs と同じ、バフ ID をキーにした平坦なテーブルなので条件が同じ)。
    g.save_lua(g.buffs_backup_path, g.buffs)
    -- 新しい控えを .lua で書けたら、旧 json の控えは消す。Mini_addons_buff_list_restore は
    -- .lua が読めなかったときだけ json へ落ちるので、残しておくと「今日取った控え」の
    -- つもりで移行前の控えが戻ってくる経路が恒久的に残る(load_buffs の旧 json と同じ話)。
    local written = io.open(g.buffs_backup_path, "rb")
    if written then
        written:close()
        os.remove(g.buffs_backup_json_path)
    end
    core_g.vlog("mini_addons: バフ一覧をバックアップした (%s)", tostring(g.buffs_backup_path))
    ui.SysMsg(g.lang == "Japanese" and "{ol}{#00BFFF}[Nexus Addons P] バフ一覧をバックアップしました" or
                  "{ol}{#00BFFF}[Nexus Addons P] Backed up the buff list")
end

-- 控えたチェック状態へ戻す。控えが無いときは何もしない(黙って空で上書きしないこと)。
function Mini_addons_buff_list_restore(frame, ctrl, str, num)
    -- .lua を先に見て、無ければ旧 json の控えへ落ちる(移行前に取った控えを失わないため)。
    local backup = g.load_lua(g.buffs_backup_path) or g.load_json(g.buffs_backup_json_path)
    if type(backup) ~= "table" then
        core_g.vlog("mini_addons: バフ一覧の控えが無い (%s)", tostring(g.buffs_backup_path))
        ui.SysMsg(g.lang == "Japanese" and "{ol}{#FF6347}[Nexus Addons P] バフ一覧のバックアップがありません" or
                      "{ol}{#FF6347}[Nexus Addons P] No buff list backup")
        return
    end
    g.buffs = backup
    Mini_addons_save_buffs()
    core_g.vlog("mini_addons: バフ一覧を復元した")
    ui.SysMsg(g.lang == "Japanese" and "{ol}{#00BFFF}[Nexus Addons P] バフ一覧を復元しました" or
                  "{ol}{#00BFFF}[Nexus Addons P] Restored the buff list")
    Mini_addons_buff_list_open(frame, ctrl, Mini_addons_buff_list_filter_text(frame), num)
end

function Mini_addons_buff_list_open(frame, ctrl, ctrl_text, num)
    local buff_list = ui.GetFrame(addon_name_lower .. "buff_list")
    if not buff_list then
        buff_list = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "buff_list", 0, 0, 10, 10)
        AUTO_CAST(buff_list)
        buff_list:SetSkinName("test_frame_low")
        buff_list:Resize(500, 1005)
        buff_list:SetPos(20, 30)
        buff_list:SetLayerLevel(999)
        local title_text = buff_list:CreateOrGetControl('richtext', 'title_text', 15, 15, 10, 30)
        AUTO_CAST(title_text)
        title_text:SetText("{#000000}{s20}Buff List")
        local search_edit = buff_list:CreateOrGetControl("edit", "search_edit", title_text:GetWidth() + 30, 10, 305, 38)
        AUTO_CAST(search_edit)
        search_edit:SetFontName("white_18_ol")
        search_edit:SetTextAlign("left", "center")
        search_edit:SetSkinName("inventory_serch")
        search_edit:SetEventScript(ui.ENTERKEY, "Mini_addons_buff_list_search")
        local search_btn = search_edit:CreateOrGetControl("button", "search_btn", 0, 0, 40, 38)
        AUTO_CAST(search_btn)
        search_btn:SetImage("inven_s")
        search_btn:SetGravity(ui.RIGHT, ui.TOP)
        search_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_buff_list_search")
        local close_button = buff_list:CreateOrGetControl('button', 'close_button', 0, 0, 20, 20)
        AUTO_CAST(close_button)
        close_button:SetImage("testclose_button")
        close_button:SetGravity(ui.RIGHT, ui.TOP)
        close_button:SetEventScript(ui.LBUTTONUP, "Mini_addons_buff_list_frame_close")
        -- 一括操作のボタン列。文言はまとめ版の設定バックアップと揃える(バックアップ/復元)。
        local ja = g.lang == "Japanese"
        local buttons = {{
            name = "all_on_btn",
            text = ja and "{ol}全部ON" or "{ol}All ON",
            tooltip = ja and "{ol}いま一覧に出ているバフを全部 ON にします{nl}検索で絞り込んでいるときは、その分だけが対象です" or
                "{ol}Turn ON every buff currently listed{nl}Only the filtered ones while searching",
            script = "Mini_addons_buff_list_set_all",
            arg = 1
        }, {
            name = "all_off_btn",
            text = ja and "{ol}全部OFF" or "{ol}All OFF",
            tooltip = ja and "{ol}いま一覧に出ているバフを全部 OFF にします{nl}検索で絞り込んでいるときは、その分だけが対象です" or
                "{ol}Turn OFF every buff currently listed{nl}Only the filtered ones while searching",
            script = "Mini_addons_buff_list_set_all",
            arg = 0
        }, {
            name = "backup_btn",
            text = ja and "{ol}バックアップ" or "{ol}Backup",
            tooltip = ja and "{ol}いまのチェック状態を控えます{nl}控えは 1 つだけで、押すたびに上書きします" or
                "{ol}Save the current checks{nl}Only one copy is kept; each press overwrites it",
            script = "Mini_addons_buff_list_backup",
            arg = 0
        }, {
            name = "restore_btn",
            text = ja and "{ol}復元" or "{ol}Restore",
            tooltip = ja and "{ol}控えたチェック状態に戻します{nl}いまの状態は上書きされます" or
                "{ol}Restore the saved checks{nl}The current state is overwritten",
            script = "Mini_addons_buff_list_restore",
            arg = 0
        }}
        local btn_x = 10
        for _, spec in ipairs(buttons) do
            local btn = buff_list:CreateOrGetControl("button", spec.name, btn_x, 50, 115, 30)
            AUTO_CAST(btn)
            btn:SetText(spec.text)
            btn:SetTextTooltip(spec.tooltip)
            btn:SetEventScript(ui.LBUTTONUP, spec.script)
            btn:SetEventScriptArgNumber(ui.LBUTTONUP, spec.arg)
            btn_x = btn_x + 120
        end
    end
    -- ボタン列のぶん下げる
    local buff_list_gb = buff_list:CreateOrGetControl("groupbox", "buff_list_gb", 10, 85, 480,
        buff_list:GetHeight() - 95)
    AUTO_CAST(buff_list_gb)
    buff_list_gb:SetSkinName("bg")
    buff_list_gb:RemoveAllChild()
    local y = 0
    Mini_addons_buff_list_each(ctrl_text or "", function(i, buff_cls, buff_name, image_name)
        local buff_id = buff_cls.ClassID
        local buff_slot = buff_list_gb:CreateOrGetControl('slot', 'buffslot' .. i, 10, y + 5, 30, 30)
        AUTO_CAST(buff_slot)
        SET_SLOT_IMG(buff_slot, image_name)
        local icon = CreateIcon(buff_slot)
        AUTO_CAST(icon)
        icon:SetTooltipType('buff')
        icon:SetTooltipArg(buff_name, buff_id, 0)
        local buffcheck = buff_list_gb:CreateOrGetControl("checkbox", "buffcheck" .. buff_id, 45, y + 5, 30, 30)
        AUTO_CAST(buffcheck)
        buffcheck:SetCheck(g.buffs[tostring(buff_id)] or 1)
        buffcheck:SetEventScript(ui.LBUTTONUP, "Mini_addons_buff_check")
        buffcheck:SetEventScriptArgNumber(ui.LBUTTONUP, buff_id)
        buffcheck:SetText("{ol}" .. buff_cls.Name)
        buffcheck:SetTextTooltip(g.lang == "Japanese" and "{ol}" .. buff_id .. "{nl}チェックするとパーティーバフ表示" or
                                     "{ol}" .. buff_id .. "{nl}Party buff display when checked")
        buffcheck:AdjustFontSizeByWidth(380)
        y = y + 35
    end)
    buff_list:ShowWindow(1)
    -- 設定画面の「パーティーバフ」から開くサブ画面なので、設定画面と同じく ESC で閉じられる
    -- ようにする。検索し直すとこの関数がもう一度呼ばれるが、esc_register は同じフレームの
    -- 古い登録を外してから積み直すので二重には積まれない。
    core_g.esc_register(addon_name_lower .. "buff_list", "Mini_addons_buff_list_ESCAPE_PRESSED")
end

-- ESC 用の入口。理由は Mini_addons_setting_ESCAPE_PRESSED と同じ
-- (esc_register は引数無しで呼ぶが、閉じる側はフレームを受け取る前提のため)。
function Mini_addons_buff_list_ESCAPE_PRESSED()
    local buff_list = ui.GetFrame(addon_name_lower .. "buff_list")
    if buff_list then
        Mini_addons_buff_list_frame_close(buff_list)
    end
end

function Mini_addons_buff_list_frame_close(buff_list)
    ui.DestroyFrame(buff_list:GetName())
end

function Mini_addons_buff_list_search(frame, ctrl, str, num)
    Mini_addons_buff_list_open(frame, ctrl, Mini_addons_buff_list_filter_text(frame), num)
end

function Mini_addons_buff_check(frame, ctrl, str, buff_id)
    local check = ctrl:IsChecked()
    local buff_id_str = tostring(buff_id)
    g.buffs[buff_id_str] = check
    Mini_addons_save_buffs()
end

function Mini_addons_ON_PARTYINFO_BUFFLIST_UPDATE(partyinfo)
    local partyinfo = ui.GetFrame("partyinfo")
    if not partyinfo then
        return
    end
    local pc_party = session.party.GetPartyInfo()
    if pc_party == nil then
        DESTROY_CHILD_BYNAME(partyinfo, "PTINFO_")
        partyinfo:ShowWindow(0)
        return
    end
    local list = session.party.GetPartyMemberList(0)
    local count = list:Count()
    local my_info = session.party.GetMyPartyObj()
    for i = 0, count - 1 do
        local party_member_info = list:Element(i)
        if geMapTable.GetMapName(party_member_info:GetMapID()) ~= "None" then
            local buff_count = party_member_info:GetBuffCount()
            local party_info_ctrl_set = partyinfo:GetChild("PTINFO_" .. party_member_info:GetAID())
            if party_info_ctrl_set then
                local buff_list_slot_set = GET_CHILD(party_info_ctrl_set, "buffList", "ui::CSlotSet")
                local debuff_list_slot_set = GET_CHILD(party_info_ctrl_set, "debuffList", "ui::CSlotSet")
                for j = 0, buff_list_slot_set:GetSlotCount() - 1 do
                    local slot = buff_list_slot_set:GetSlotByIndex(j)
                    if not slot then
                        break
                    end
                    slot:SetKeyboardSelectable(false)
                    slot:ShowWindow(0)
                end
                for j = 0, debuff_list_slot_set:GetSlotCount() - 1 do
                    local slot = debuff_list_slot_set:GetSlotByIndex(j)
                    if not slot then
                        break
                    end
                    slot:ShowWindow(0)
                end
                if buff_count <= 0 then
                    party_member_info:ResetBuff()
                    buff_count = party_member_info:GetBuffCount()
                end
                if buff_count > 0 then
                    local buff_index = 0
                    local debuff_index = 0
                    for j = 0, buff_count - 1 do
                        local buff_id = party_member_info:GetBuffIDByIndex(j)
                        local cls = GetClassByType("Buff", buff_id)
                        if cls and IS_PARTY_INFO_SHOWICON(cls.ShowIcon) == true and cls.ClassName ~= "TeamLevel" then
                            local buff_over = party_member_info:GetBuffOverByIndex(j)
                            local buff_time = party_member_info:GetBuffTimeByIndex(j)
                            local slot = nil
                            if cls.Group1 == "Buff" then
                                if g.settings.party_buff == 1 then
                                    if g.buffs[tostring(buff_id)] == 1 then
                                        slot = buff_list_slot_set:GetSlotByIndex(buff_index)
                                        buff_index = buff_index + 1
                                    end
                                else
                                    slot = buff_list_slot_set:GetSlotByIndex(buff_index)
                                    buff_index = buff_index + 1
                                end
                            elseif cls.Group1 == "Debuff" then
                                slot = debuff_list_slot_set:GetSlotByIndex(debuff_index)
                                debuff_index = debuff_index + 1
                            end
                            if slot then
                                local icon = slot:GetIcon()
                                if not icon then
                                    icon = CreateIcon(slot)
                                end
                                local handle = 0
                                if my_info then
                                    if my_info:GetMapID() == party_member_info:GetMapID() and my_info:GetChannel() ==
                                        party_member_info:GetChannel() then
                                        handle = party_member_info:GetHandle()
                                    end
                                end
                                icon:SetDrawCoolTimeText(math.floor(buff_time / 1000))
                                icon:SetTooltipType("buff")
                                icon:SetTooltipArg(tostring(handle), buff_id, "")
                                local image_name = "icon_" .. TryGetProp(cls, "Icon", "None")
                                if image_name ~= "icon_None" then
                                    icon:Set(image_name, "BUFF", buff_id, 0)
                                end
                                if buff_over > 1 then
                                    slot:SetText("{s13}{ol}{b}" .. buff_over, "count", ui.RIGHT, ui.BOTTOM, 1, 2)
                                else
                                    slot:SetText("")
                                end
                                slot:ShowWindow(1)
                            end
                        end
                    end
                end
            end
        end
    end
end
-- チャンネルのズレを直す
function Mini_addons_UPDATE_CURRENT_CHANNEL_TRAFFIC(frame)
    -- 置換方式のフックなので、OFF のときは素の実装へ回す。
    -- ここで自前の分岐へ落とすとチャンネル欄が空になる
    if g.settings.channel_display ~= 1 then
        if g.FUNCS["UPDATE_CURRENT_CHANNEL_TRAFFIC"] then
            return g.FUNCS["UPDATE_CURRENT_CHANNEL_TRAFFIC"](frame)
        end
        -- 控えが無い = 素の実装へ戻せない。チャンネル欄が空のままになるので知らせる
        core_g.vlog("mini_addons: UPDATE_CURRENT_CHANNEL_TRAFFIC の素の実装が控えに無い")
        return
    end
    local curchannel = frame:GetChild("curchannel")
    local channel = session.loginInfo.GetChannel()
    local zone_inst = session.serverState.GetZoneInst(channel)
    local function set_channel_text(str, state_string)
        local spacing = (g.lang == "Japanese") and "                      " or "                                  "
        curchannel:SetTextByKey("value", str .. spacing .. state_string)
    end
    if zone_inst then
        local str, state_string
        if GET_PRIVATE_CHANNEL_ACTIVE_STATE() == false then
            str, state_string = GET_CHANNEL_STRING(zone_inst)
        else
            local suffix = GET_SUFFIX_PRIVATE_CHANNEL(zone_inst.mapID, zone_inst.channel + 1)
            str, state_string = GET_CHANNEL_STRING(zone_inst, suffix)
        end
        set_channel_text(str, state_string)
    else
        curchannel:SetTextByKey("value", "")
    end
end
-- インベントリイコル検索
local inven_title_name = nil
local _inven_sort_type_option = {}
local function mini_addons_is_match_or(text, keyword_list)
    if text == nil then
        return false
    end
    for _, word in ipairs(keyword_list) do
        if string.find(text, word) then
            return true
        end
    end
    return false
end

function Mini_addons_INVENTORY_TOTAL_LIST_GET(frame, set_pos, is_ignore_lift_icon, inven_type_str)
    if g.settings.icor_status_search == 0 then
        if g.FUNCS["INVENTORY_TOTAL_LIST_GET"] then
            g.FUNCS["INVENTORY_TOTAL_LIST_GET"](frame, set_pos, is_ignore_lift_icon, inven_type_str)
        end
        return
    end
    local inv_frame = ui.GetFrame("inventory")
    if not inv_frame then
        return
    end
    local lift_icon = ui.GetLiftIcon()
    if not is_ignore_lift_icon then
        is_ignore_lift_icon = "NO"
    end
    if is_ignore_lift_icon ~= "NO" and lift_icon ~= nil then
        return
    end
    local my_session = session.GetMySession()
    local cid = my_session:GetCID()
    local sort_type = _inven_sort_type_option[cid] or 0
    session.BuildInvItemSortedList()
    local sorted_list = session.GetInvItemSortedList()
    local inv_item_count = sorted_list:size()
    local group = GET_CHILD_RECURSIVELY(inv_frame, "inventoryGbox", "ui::CGroupBox")
    for type_no = 1, #g_invenTypeStrList do
        if inven_type_str == nil or inven_type_str == g_invenTypeStrList[type_no] or type_no == 1 then
            local tree_box = GET_CHILD_RECURSIVELY(group, "treeGbox_" .. g_invenTypeStrList[type_no], "ui::CGroupBox")
            local tree =
                GET_CHILD_RECURSIVELY(tree_box, "inventree_" .. g_invenTypeStrList[type_no], "ui::CTreeControl")
            local group_font_name = inv_frame:GetUserConfig("TREE_GROUP_FONT")
            local tab_width = inv_frame:GetUserConfig("TREE_TAB_WIDTH")
            tree:Clear()
            tree:EnableDrawFrame(false)
            tree:SetFitToChild(true, 60)
            tree:SetFontName(group_font_name)
            tree:SetTabWidth(tab_width)
            local slot_set_name_list_cnt = ui.inventory.GetInvenSlotSetNameCount()
            for i = 1, slot_set_name_list_cnt do
                local slot_set_name = ui.inventory.GetInvenSlotSetNameByIndex(i - 1)
                ui.inventory.RemoveInvenSlotSetName(slot_set_name)
            end
            local group_name_list_cnt = ui.inventory.GetInvenGroupNameCount()
            for i = 1, group_name_list_cnt do
                local group_name = ui.inventory.GetInvenGroupNameByIndex(i - 1)
                ui.inventory.RemoveInvenGroupName(group_name)
            end
        end
    end
    local search_gbox = group:GetChild("searchGbox")
    local search_skin = GET_CHILD_RECURSIVELY(search_gbox, "searchSkin", "ui::CGroupBox")
    local edit = GET_CHILD_RECURSIVELY(search_skin, "ItemSearch", "ui::CEditControl")
    local cap = edit:GetText()
    local search_keywords = {}
    local is_searching = false
    if cap ~= "" then
        local query = string.lower(cap)
        for word in string.gmatch(query, "%S+") do
            table.insert(search_keywords, word)
        end
        if #search_keywords > 0 then
            is_searching = true
        end
    end
    local inv_item_list = {}
    local index_count = 1
    for i = 0, inv_item_count - 1 do
        local inv_item = sorted_list:at(i)
        if inv_item ~= nil then
            inv_item_list[index_count] = inv_item
            index_count = index_count + 1
        end
    end
    if sort_type == 1 then
        table.sort(inv_item_list, INVENTORY_SORT_BY_GRADE)
    elseif sort_type == 2 then
        table.sort(inv_item_list, INVENTORY_SORT_BY_WEIGHT)
    elseif sort_type == 3 then
        table.sort(inv_item_list, INVENTORY_SORT_BY_NAME)
    elseif sort_type == 4 then
        table.sort(inv_item_list, INVENTORY_SORT_BY_COUNT)
    else
        table.sort(inv_item_list, INVENTORY_SORT_BY_NAME)
    end
    if inven_title_name == nil then
        inven_title_name = {}
        local base_id_cls_list, base_id_cnt = GetClassList("inven_baseid")
        for i = 1, base_id_cnt do
            local base_id_cls = GetClassByIndexFromList(base_id_cls_list, i - 1)
            local temp_title = base_id_cls.ClassName
            if base_id_cls.MergedTreeTitle ~= "NO" then
                temp_title = base_id_cls.MergedTreeTitle
            end
            if table.find(inven_title_name, temp_title) == 0 then
                inven_title_name[#inven_title_name + 1] = temp_title
            end
        end
    end
    local cls_inv_index = {}
    for i = 1, #inven_title_name do
        local category = inven_title_name[i]
        for j = 1, #inv_item_list do
            local inv_item = inv_item_list[j]
            if inv_item ~= nil then
                local item_cls = GetIES(inv_item:GetObject())
                if item_cls.MarketCategory ~= "None" then
                    local base_id_cls = nil
                    if cls_inv_index[inv_item.invIndex] == nil then
                        base_id_cls = GET_BASEID_CLS_BY_INVINDEX(inv_item.invIndex)
                        cls_inv_index[inv_item.invIndex] = base_id_cls
                    else
                        base_id_cls = cls_inv_index[inv_item.invIndex]
                    end
                    local title_name = base_id_cls.ClassName
                    if base_id_cls.MergedTreeTitle ~= "NO" then
                        title_name = base_id_cls.MergedTreeTitle
                    end
                    if category == title_name then
                        local type_str = GET_INVENTORY_TREEGROUP(base_id_cls)
                        if item_cls ~= nil then
                            local make_slot = true
                            if is_searching then
                                make_slot = false
                                local item_name = string.lower(dictionary.ReplaceDicIDInCompStr(item_cls.Name))
                                local prefix_class_name = TryGetProp(item_cls, "LegendPrefix")
                                if prefix_class_name ~= nil and prefix_class_name ~= "None" then
                                    local prefix_cls = GetClass("LegendSetItem", prefix_class_name)
                                    local prefix_name = string.lower(dictionary.ReplaceDicIDInCompStr(prefix_cls.Name))
                                    item_name = prefix_name .. " " .. item_name
                                end
                                if mini_addons_is_match_or(item_name, search_keywords) then
                                    make_slot = true
                                else
                                    if TryGetProp(item_cls, "GroupName", "None") == "Earring" then
                                        local max_option_count =
                                            shared_item_earring.get_max_special_option_count(TryGetProp(item_cls,
                                                "UseLv", 1))
                                        for ii = 1, max_option_count do
                                            local option_name = "EarringSpecialOption_" .. ii
                                            local job = TryGetProp(item_cls, option_name, "None")
                                            if job ~= "None" then
                                                local job_cls = GetClass("Job", job)
                                                if job_cls ~= nil then
                                                    item_name = string.lower(
                                                        dictionary.ReplaceDicIDInCompStr(job_cls.Name))
                                                    if mini_addons_is_match_or(item_name, search_keywords) then
                                                        make_slot = true
                                                        break
                                                    end
                                                end
                                            end
                                        end
                                    elseif TryGetProp(item_cls, "GroupName", "None") == "Icor" then
                                        local max_option = 5
                                        for iii = 1, max_option do
                                            local item = GetIES(inv_item:GetObject())
                                            local option_name = "RandomOption_" .. iii
                                            local option = TryGetProp(item, option_name, "None")
                                            if option ~= "None" and option ~= nil then
                                                item_name =
                                                    string.lower(dictionary.ReplaceDicIDInCompStr(ClMsg(option)))
                                                if mini_addons_is_match_or(item_name, search_keywords) then
                                                    make_slot = true
                                                    break
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            local view_option_check = 1
                            if type_str == "Equip" then
                                view_option_check = CHECK_INVENTORY_OPTION_EQUIP(item_cls)
                            elseif type_str == "Card" then
                                view_option_check = CHECK_INVENTORY_OPTION_CARD(item_cls)
                            elseif type_str == "Etc" then
                                view_option_check = CHECK_INVENTORY_OPTION_ETC(item_cls)
                            elseif type_str == "Gem" then
                                view_option_check = CHECK_INVENTORY_OPTION_GEM(item_cls)
                            end
                            if make_slot == true and view_option_check == 1 then
                                if inv_item.count > 0 and base_id_cls.ClassName ~= "Unused" then
                                    if inven_type_str == nil or inven_type_str == type_str then
                                        local tree_box = GET_CHILD_RECURSIVELY(group, "treeGbox_" .. type_str,
                                            "ui::CGroupBox")
                                        local tree = GET_CHILD_RECURSIVELY(tree_box, "inventree_" .. type_str,
                                            "ui::CTreeControl")
                                        INSERT_ITEM_TO_TREE(inv_frame, tree, inv_item, item_cls, base_id_cls)
                                    end
                                    if type_str ~= "Quest" then
                                        local tree_box_all =
                                            GET_CHILD_RECURSIVELY(group, "treeGbox_All", "ui::CGroupBox")
                                        local tree_all = GET_CHILD_RECURSIVELY(tree_box_all, "inventree_All",
                                            "ui::CTreeControl")
                                        INSERT_ITEM_TO_TREE(inv_frame, tree_all, inv_item, item_cls, base_id_cls)
                                    end
                                end
                            else
                                local is_option_applied = CHECK_INVENTORY_OPTION_APPLIED(base_id_cls)
                                if is_option_applied == 1 and cap == "" then
                                    if inven_type_str == nil or inven_type_str == type_str then
                                        local tree_box = GET_CHILD_RECURSIVELY(group, "treeGbox_" .. type_str,
                                            "ui::CGroupBox")
                                        local tree = GET_CHILD_RECURSIVELY(tree_box, "inventree_" .. type_str,
                                            "ui::CTreeControl")
                                        EMPTY_TREE_INVENTORY_OPTION_TEXT(base_id_cls, tree)
                                    end
                                    if type_str ~= "Quest" then
                                        local tree_box_all =
                                            GET_CHILD_RECURSIVELY(group, "treeGbox_All", "ui::CGroupBox")
                                        local tree_all = GET_CHILD_RECURSIVELY(tree_box_all, "inventree_All",
                                            "ui::CTreeControl")
                                        EMPTY_TREE_INVENTORY_OPTION_TEXT(base_id_cls, tree_all)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    for type_no = 1, #g_invenTypeStrList do
        local tree_box = GET_CHILD_RECURSIVELY(group, "treeGbox_" .. g_invenTypeStrList[type_no], "ui::CGroupBox")
        local tree = GET_CHILD_RECURSIVELY(tree_box, "inventree_" .. g_invenTypeStrList[type_no], "ui::CTreeControl")
        local slot_set_name_list_cnt = ui.inventory.GetInvenSlotSetNameCount()
        for i = 1, slot_set_name_list_cnt do
            local get_slot_set_name = ui.inventory.GetInvenSlotSetNameByIndex(i - 1)
            local slot_set = GET_CHILD_RECURSIVELY(tree, get_slot_set_name, "ui::CSlotSet")
            if slot_set ~= nil then
                ui.InventoryHideEmptySlotBySlotSet(slot_set)
            end
        end
        ADD_GROUP_BOTTOM_MARGIN(inv_frame, tree)
        tree:OpenNodeAll()
        tree:SetEventScript(ui.LBUTTONDOWN, "INVENTORY_TREE_OPENOPTION_CHANGE")
        INVENTORY_CATEGORY_OPENCHECK(inv_frame, tree)
        for i = 1, slot_set_name_list_cnt do
            if set_pos == "setpos" then
                local saved_pos = inv_frame:GetUserValue("INVENTORY_CUR_SCROLL_POS")
                if saved_pos == "None" then
                    saved_pos = 0
                end
                tree_box:SetScrollPos(tonumber(saved_pos))
            end
        end
    end
end
-- イベントグローバルシャウトをチャットに残す
function Mini_addons_event_NOTICE_ON_MSG(frame, msg, str, num)
    if string.find(str, "StartBlackMarketBetween") then
        return
    end
    local current_time = os.clock()
    if not g.mini_addons_event_notice_time or (current_time - g.mini_addons_event_notice_time < 1800) then
        g.event_maps = g.event_maps or {} -- nilガード
    else
        g.event_maps = {}
    end
    if g.mini_addons_event_notice_time and (current_time - g.mini_addons_event_notice_time < 1.0) then
        if g.mini_addons_event_last_notice_str == str then
            return
        end
    end
    local is_appear = string.find(str, "{name}AppearFieldBoss{map}")
    local is_disappear = string.find(str, "{name}DisappearFieldBoss{map}")
    if not is_appear and not is_disappear then
        return
    end
    g.mini_addons_event_notice_time = current_time
    g.mini_addons_event_last_notice_str = str
    g.event_maps = g.event_maps or {}
    local clean_str = str
    local args_part = str:match("%$%*%$(.*)#%$|#@!")
    args_part = string.gsub(args_part, "%$%*%$|%$#", ":::")
    args_part = string.gsub(args_part, "#%$|%$%*%$", ":::")
    local name, map = "", ""
    if args_part then
        _, name, _, map = args_part:match("^(.-):::(.-):::(.-):::(.*)$")
    end
    local class_name
    local map_list, cnt = GetClassList("Map")
    for i = 0, cnt - 1 do
        local map_cls = GetClassByIndexFromList(map_list, i)
        if map_cls then
            local map_name = map_cls.Name
            if dictionary.ReplaceDicIDInCompStr(map_name) == dictionary.ReplaceDicIDInCompStr(map) then
                class_name = map_cls.ClassName
                break
            end
        end
    end
    name = dictionary.ReplaceDicIDInCompStr(name)
    map = dictionary.ReplaceDicIDInCompStr(map)
    if is_appear then
        table.insert(g.event_maps, {map, class_name, name, os.time()})
    elseif is_disappear then
        for i = #g.event_maps, 1, -1 do
            if g.event_maps[i][2] == class_name then
                table.remove(g.event_maps, i)
                break
            end
        end
    end
    local fmt = ""
    if is_appear then
        fmt = "[{map}]에 필드 보스[{name}]가 등장하였습니다."
    elseif is_disappear then
        fmt = "[{map}]에 필드 보스[{name}]가 처치되었습니다."
    else
        return
    end
    clean_str = dictionary.ReplaceDicIDInCompStr(fmt)
    clean_str = string.gsub(clean_str, "{name}", name)
    clean_str = string.gsub(clean_str, "{map}", map)
    CHAT_SYSTEM(clean_str)
    if g.settings.event_shout.guild_notice == 1 then
        ui.Chat("/g " .. clean_str)
    end
    Mini_addons_event_frame()
end

function Mini_addons_event_frame()
    if not g.event_maps or #g.event_maps == 0 then
        ui.DestroyFrame(addon_name_lower .. "event_frame")
        return
    end
    local event_frame = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "event_frame", 0, 0, 0, 0)
    AUTO_CAST(event_frame)
    event_frame:SetSkinName("None")
    event_frame:RunUpdateScript("Mini_addons_event_check_time", 5.0)
    local gbox = event_frame:CreateOrGetControl("groupbox", "gbox", 0, 0, 0, 0)
    AUTO_CAST(gbox)
    gbox:SetSkinName("bg2")
    gbox:RemoveAllChild()
    local close = gbox:CreateOrGetControl("button", "close", 0, 0, 30, 30)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:EnableHitTest(1)
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Mini_addons_event_frame_close")
    local name_text = gbox:CreateOrGetControl("richtext", "name_text", 20, 5, 10, 20)
    AUTO_CAST(name_text)
    name_text:SetText("{ol}" .. g.event_maps[#g.event_maps][3])
    local x = name_text:GetWidth() + 60
    local y = 30
    for i, data in ipairs(g.event_maps) do
        local icon = gbox:CreateOrGetControl("picture", "icon_" .. i, 10, y, 20, 20)
        AUTO_CAST(icon)
        icon:SetImage("questinfo_return") -- GET_TOKEN_WARP_COOLDOWN() == 0 then
        icon:SetTextTooltip(g.lang == "Japanese" and "{ol}トークンワープ" or "{ol}token warp")
        icon:SetEventScript(ui.LBUTTONUP, "Mini_addons_event_tokenwarp")
        icon:SetEventScriptArgString(ui.LBUTTONUP, data[2])
        icon:EnableHitTest(1)
        icon:SetAngleLoop(-3)
        icon:SetEnableStretch(1)
        local text = gbox:CreateOrGetControl("richtext", "text_" .. i, 35, y, 0, 0)
        AUTO_CAST(text)
        text:SetText("{ol}" .. data[1])
        text:EnableHitTest(0)
        y = y + 25
        local temp_x = 30 + text:GetWidth()
        if x < temp_x then
            x = temp_x
        end
    end
    local slot = gbox:CreateOrGetControl("picture", "slot", 30, y, 30, 30)
    AUTO_CAST(slot)
    local item_cls = GetClassByType('Item', 11202062)
    slot:SetImage(item_cls.Icon)
    slot:EnableHitTest(1)
    slot:SetEnableStretch(1)
    local slot_text = slot:CreateOrGetControl("richtext", "slot_text", 0, 0, 10, 10)
    AUTO_CAST(slot_text)
    slot_text:SetGravity(ui.RIGHT, ui.BOTTOM)
    slot:RunUpdateScript("Mini_addons_event_check_count_change", 0.1)
    slot:SetEventScript(ui.LBUTTONUP, "Mini_addons_event_check_itemuse")
    slot:SetEventScript(ui.RBUTTONUP, "Mini_addons_event_check_itemuse")
    slot_text:SetEventScript(ui.LBUTTONUP, "Mini_addons_event_check_itemuse")
    slot_text:SetEventScript(ui.RBUTTONUP, "Mini_addons_event_check_itemuse")
    slot:SetTextTooltip(g.lang == "Japanese" and "{ol}アイテム使用" or "{ol}Item use")
    y = y + 30
    local screen_width = ui.GetClientInitialWidth()
    event_frame:SetPos(screen_width / 2 + 200, 20)
    event_frame:Resize(x, y + 10)
    gbox:Resize(x, y + 10)
    event_frame:ShowWindow(1)
end

function Mini_addons_event_check_count_change(slot)
    local slot_text = GET_CHILD(slot, "slot_text")
    local inv_item = session.GetInvItemByType(11202062)
    if inv_item then
        slot_text:SetText("{ol}{s10}" .. inv_item.count)
    else
        slot_text:SetText("{ol}{s10}0")
        slot:SetColorTone("FF990000")
    end
    return 0
end

function Mini_addons_event_check_itemuse(frame, ctrl)
    local inv_item_list = session.GetInvItemList()
    local guid_list = inv_item_list:GetGuidList()
    local cnt = guid_list:Count()
    for i = 0, cnt - 1 do
        local guid = guid_list:Get(i)
        local inv_item = inv_item_list:GetItemByGuid(guid)
        local item_obj = GetIES(inv_item:GetObject())
        if item_obj and item_obj.ClassID == 11202062 then
            Mini_addons_event_frame()
            item.UseByGUID(guid)
            break
        end
    end
end

function Mini_addons_event_check_time(frame)
    if not g.event_maps or #g.event_maps == 0 then
        ui.DestroyFrame(addon_name_lower .. "event_frame")
        return 0
    end
    local current_time = os.time()
    local changed = false
    for i = #g.event_maps, 1, -1 do
        local data = g.event_maps[i]
        if data[4] and (current_time - data[4] >= 1800) then
            table.remove(g.event_maps, i)
            changed = true
        end
    end
    if changed then
        Mini_addons_event_frame()
    end
    return 1
end

function Mini_addons_event_tokenwarp(frame, ctrl, class_name)
    if class_name then
        WORLDMAP2_TOKEN_WARP(class_name)
    end
end

function Mini_addons_event_frame_close(frame, ctrl)
    ui.DestroyFrame(addon_name_lower .. "event_frame")
    g.event_maps = {}
end

-- 表示の切り替えだけ行う（理由は Mini_addons_baubas_call_switch と同じ）
function Mini_addons_event_shout_switch(frame, ctrl, str)
    AUTO_CAST(ctrl)
    if g.settings.event_shout.guild_notice == 0 then
        g.settings.event_shout.guild_notice = 1
        ctrl:SetText("{ol}{#FFFFFF}ON")
        ctrl:SetSkinName("test_red_button")
    else
        g.settings.event_shout.guild_notice = 0
        ctrl:SetText("{ol}{#FFFFFF}OFF")
        ctrl:SetSkinName("test_gray_button")
    end
    Mini_addons_save_settings()
end

function Mini_addons_event_NOTICE_ON_MSG_test()
    local appear =
        {"!@#${name}AppearFieldBoss{map}$*$name$*$|$#(10주년) 황금 개복치#$|$*$map$*$|$#제단로#$|#@!",
         "!@#${name}AppearFieldBoss{map}$*$name$*$|$#(10주년) 황금 개복치#$|$*$map$*$|$#마법사의 탑 1층#$|#@!",
         "!@#${name}AppearFieldBoss{map}$*$name$*$|$#(10주년) 황금 개복치#$|$*$map$*$|$#라우키메 저습지#$|#@!",
         "!@#${name}AppearFieldBoss{map}$*$name$*$|$#(10주년) 황금 개복치#$|$*$map$*$|$#왕의 고원#$|#@!",
         "!@#${name}AppearFieldBoss{map}$*$name$*$|$#(10주년) 황금 개복치#$|$*$map$*$|$#미르키티 농장#$|#@!"}
    for _, str in ipairs(appear) do
        Mini_addons_event_NOTICE_ON_MSG(nil, nil, str, nil)
    end
    --[[local disappear =
        {"!@#${name}DisappearFieldBoss{map}$*$name$*$|$#(10주년) 황금 개복치#$|$*$map$*$|$#왕의 고원#$|#@!",
         "!@#${name}DisappearFieldBoss{map}$*$name$*$|$#(10주년) 황금 개복치#$|$*$map$*$|$#마법사의 탑 1층#$|#@!",
         "!@#${name}DisappearFieldBoss{map}$*$name$*$|$#(10주년) 황금 개복치#$|$*$map$*$|$#미르키티 농장#$|#@!",
         "!@#${name}DisappearFieldBoss{map}$*$name$*$|$#(10주년) 황금 개복치#$|$*$map$*$|$#라우키메 저습지#$|#@!",
         "!@#${name}DisappearFieldBoss{map}$*$name$*$|$#(10주년) 황금 개복치#$|$*$map$*$|$#제단로#$|#@!"}
    for _, str in ipairs(disappear) do
        Mini_addons_event_NOTICE_ON_MSG(nil, nil, str, nil)
    end]]
end
-- Mini_addons_event_NOTICE_ON_MSG_test()
-- 装備錬成を自動化
function Mini_addons_COMMON_EQUIP_UPGRADE_OPEN(my_frame, my_msg)
    local frame = ui.GetFrame("common_equip_upgrade")
    if g.settings.status_upgrade == 0 then
        local target_status_text = GET_CHILD_RECURSIVELY(frame, "target_status_text")
        if target_status_text ~= nil then
            AUTO_CAST(target_status_text)
            target_status_text:ShowWindow(0)
        end
        local target_status_edit = GET_CHILD_RECURSIVELY(frame, "target_status_edit")
        if target_status_edit ~= nil then
            AUTO_CAST(target_status_edit)
            target_status_edit:ShowWindow(0)
        end
    else
        local target_status_text = frame:CreateOrGetControl("richtext", "target_status_text", 20, 650, 80, 30)
        AUTO_CAST(target_status_text)
        target_status_text:SetFontName("white_18_ol")
        target_status_text:SetText("Target Status")
        target_status_text:ShowWindow(1)
        if g.settings.target_status_value == nil then
            g.settings.target_status_value = 20
            Mini_addons_save_settings()
        end
        local target_status_edit = frame:CreateOrGetControl("edit", "target_status_edit", 30, 680, 80, 25)
        AUTO_CAST(target_status_edit)
        target_status_edit:SetTextAlign("center", "center")
        target_status_edit:SetFontName("white_18_ol")
        target_status_edit:SetSkinName("test_weight_skin")
        target_status_edit:SetText(g.settings.target_status_value)
        target_status_edit:SetTextTooltip(g.lang == "Japanese" and "1~20の間で設定" or "Set between 1~20")
        target_status_edit:SetEventScript(ui.ENTERKEY, "Mini_addons_EQUIP_UPGRADE_SET")
        target_status_edit:ShowWindow(1)
    end
end

function Mini_addons_EQUIP_UPGRADE_SET(frame, ctrl, str, num)
    if not tonumber(ctrl:GetText()) then
        ui.SysMsg("Invalid value")
        return
    elseif tonumber(ctrl:GetText()) > 20 or tonumber(ctrl:GetText()) < 1 then
        ui.SysMsg("Invalid value")
        return
    else
        g.settings.target_status_value = tonumber(ctrl:GetText())
        ui.SysMsg("Set target value")
        Mini_addons_save_settings()
    end
end

function Mini_addons_COMMON_EQUIP_UPGRADE_PROGRESS(parent, ctrl, str, nym)
    if g.settings.status_upgrade == 0 then
        g.FUNCS["COMMON_EQUIP_UPGRADE_PROGRESS"](parent, ctrl, str, nym)
        return
    end
    local frame = parent:GetTopParentFrame()
    local slot = GET_CHILD_RECURSIVELY(frame, "slot")
    local guid = slot:GetUserValue("SET_ID")
    pc.ReqExecuteTx_Item("UPGRADE_EQUIP", guid)
    local inv_item = session.GetInvItemByGuid(guid)
    if inv_item == nil then
        return
    end
    local item_obj = GetIES(inv_item:GetObject())
    COMMON_EQUIP_UPGRADE_MAT_NUM_SET(frame, item_obj)
    local cur_rank = TryGetProp(item_obj, "UpgradeRank", 0)
    if tonumber(cur_rank) < g.settings.target_status_value then
        ReserveScript("Mini_addons_COMMON_EQUIP_UPGRADE_PROGRESS_CONTINUE()", 2.0)
        return
    end
end

function Mini_addons_COMMON_EQUIP_UPGRADE_PROGRESS_CONTINUE()
    local parent = ui.GetFrame("common_equip_upgrade")
    if parent:IsVisible() == 0 then
        return
    end
    mini_addons_COMMON_EQUIP_UPGRADE_PROGRESS_(parent, nil, nil, nil)
end
-- マーケット販売時に持ってる最大値を自動入力
function Mini_addons_MARKET_SELL_UPDATE_REG_SLOT_ITEM(frame, msg)
    local market_sell = ui.GetFrame("market_sell")
    local edit_count = GET_CHILD_RECURSIVELY(market_sell, "edit_count")
    AUTO_CAST(edit_count)
    local slot = GET_CHILD_RECURSIVELY(market_sell, "slot_item")
    local icon = slot:GetIcon()
    if icon then
        local info = icon:GetInfo()
        local iesid = info:GetIESID()
        local inv_item = session.GetInvItemByGuid(iesid)
        if inv_item then
            edit_count:SetText(inv_item.count)
        end
    end
end
-- レイドレコードの2度呼ばれるバグ修正。正確に測れる
function Mini_addons__REQ_PLAYER_CONTENTS_RECORD(frame, msg, arg_str, state)
    g.raid_msg = g.raid_msg or {}
    if g.raid_msg[msg] then
        return
    end
    g.raid_msg[msg] = true
    frame:SetUserValue("MA_arg_str", arg_str)
    frame:RunUpdateScript("Mini_addons_REQ_PLAYER_CONTENTS_RECORD_", 0.3)
end

function Mini_addons_REQ_PLAYER_CONTENTS_RECORD_(frame)
    local arg_str = frame:GetUserValue("MA_arg_str")
    local raid_record = ui.GetFrame("raid_record")
    if not raid_record then
        g.raid_msg = {}
        return
    end
    local token = StringSplit(arg_str, ";")
    if not token or not token[1] or not token[2] or not token[3] then
        g.raid_msg = {}
        return
    end
    local name = token[1]
    local before_str = token[2]
    local record_str = token[3]
    local function time_to_milliseconds(time_str)
        if type(time_str) ~= "string" then
            return nil
        end
        local min_str, sec_str, ms_str = time_str:match("(%d+):(%d+)%.(%d+)")
        if min_str and sec_str and ms_str then
            local ms_num = tonumber(ms_str)
            if not ms_num then
                return nil
            end
            if string.len(ms_str) == 1 then
                ms_num = ms_num * 100
            elseif string.len(ms_str) == 2 then
                ms_num = ms_num * 10
            end
            local minutes = tonumber(min_str)
            local seconds = tonumber(sec_str)
            return (minutes * 60 * 1000) + (seconds * 1000) + ms_num
        end
        return nil
    end
    local before_ms = time_to_milliseconds(before_str)
    local record_ms = time_to_milliseconds(record_str)
    if not before_ms or not record_ms then
        g.raid_msg = {}
        return
    end
    local record_time = GET_CHILD_RECURSIVELY(raid_record, "textRecord")
    local my_info = GET_CHILD_RECURSIVELY(raid_record, "myInfo")
    local time = GET_CHILD_RECURSIVELY(my_info, "time")
    record_time:SetTextByKey("value", record_str)
    if before_ms >= record_ms then
        local text_new_record = GET_CHILD_RECURSIVELY(raid_record, "textNewRecord")
        text_new_record:ShowWindow(1)
        local effect_name = raid_record:GetUserConfig("DO_NEWRECORD_EFFECT")
        local effect_scale = tonumber(raid_record:GetUserConfig("NEWRECORD_EFFECT_SCALE"))
        local effect_duration = tonumber(raid_record:GetUserConfig("NEWRECORD_EFFECT_DURATION"))
        local effect_bg = GET_CHILD_RECURSIVELY(raid_record, "success_effect_bg")
        if effect_bg then
            effect_bg:PlayUIEffect(effect_name, effect_scale, "DoNewRecordEffect")
            raid_record:RunUpdateScript("_RAID_NEWRECORD_EFFECT", effect_duration)
        end
        time:SetTextByKey("value", before_str .. "→" .. record_str)
    else
        time:SetTextByKey("value", before_str)
    end
    g.raid_msg = {}
    GetPlayerRecord("callback_get_player_current_record", name)
    return 0
end
-- レイドレコードのサイズ、位置変更
function Mini_addons_RAID_RECORD_INIT(my_frame, my_msg)
    if g.settings.raid_record == 0 then
        return
    end
    local raid_record = ui.GetFrame("raid_record")
    raid_record:SetSkinName("shadow_box")
    raid_record:SetEventScript(ui.LBUTTONUP, "Mini_addons_raid_record_loc_save")
    raid_record:SetLayerLevel(5)
    raid_record:SetTitleBarSkin("None")
    raid_record:ShowTitleBar(0)
    raid_record:Resize(550, 260)
    raid_record:SetOffset(g.settings.reword_x, g.settings.reword_y)
    local widget_list = {{
        name = "myInfo",
        font = "white_16_ol"
    }, {
        name = "friendInfo1",
        font = "white_16_ol"
    }, {
        name = "friendInfo2",
        font = "white_16_ol"
    }, {
        name = "friendInfo3",
        font = "white_16_ol"
    }}
    for i, data in ipairs(widget_list) do
        local widget = GET_CHILD_RECURSIVELY(raid_record, data.name)
        local name = GET_CHILD_RECURSIVELY(widget, "name")
        local time = GET_CHILD_RECURSIVELY(widget, "time")
        name:SetFontName(data.font)
        time:SetFontName(data.font)
    end
end

function Mini_addons_raid_record_loc_save(raid_record)
    g.settings.reword_x = raid_record:GetX()
    g.settings.reword_y = raid_record:GetY()
    Mini_addons_save_settings()
end
-- 自分のエフェクト設定を戻すIMCのバグ修正
function Mini_addons_MY_EFFECT_SETTING()
    if g.settings.my_effect == 0 then
        return
    end
    local systemoption = ui.GetFrame("systemoption")
    local slide = GET_CHILD_RECURSIVELY(systemoption, "effect_transparency_my_value", "ui::CSlideBar")
    if g.settings.my_effect_value then
        config.SetMyEffectTransparency(g.settings.my_effect_value)
        slide:SetLevel(g.settings.my_effect_value)
    else
        local my_effect = config.GetMyEffectTransparency()
        config.SetMyEffectTransparency(my_effect)
    end
end

function Mini_addons_MY_EFFECT_EDIT(frame, ctrl)
    local my_effect = tonumber(ctrl:GetText())
    if my_effect <= 100 and my_effect >= 1 then
        local num = math.floor(my_effect / 0.392156862745 + 0.5)
        g.settings.my_effect_value = num
        Mini_addons_save_settings()
        config.SetMyEffectTransparency(num)
        ui.SysMsg("my effect changed.")
    else
        ui.SysMsg("Not a valid value.")
        return
    end
end
-- ボスのエフェクト設定を戻すIMCのバグ修正
function Mini_addons_BOSS_EFFECT_SETTING()
    if g.settings.boss_effect == 0 then
        return
    end
    local systemoption = ui.GetFrame("systemoption")
    local slide = GET_CHILD_RECURSIVELY(systemoption, "effect_transparency_boss_monster_value", "ui::CSlideBar")
    if g.settings.boss_effect_value then
        config.SetBossMonsterEffectTransparency(g.settings.boss_effect_value)
        slide:SetLevel(g.settings.boss_effect_value)
    else
        local boss_effect = config.GetBossMonsterEffectTransparency()
        config.SetBossMonsterEffectTransparency(boss_effect)
    end
end

function Mini_addons_BOSS_EFFECT_EDIT(frame, ctrl)
    local boss_effect = tonumber(ctrl:GetText())
    if boss_effect <= 100 and boss_effect >= 1 then
        local num = math.floor(boss_effect / 0.392156862745 + 0.5)
        g.settings.boss_effect_value = num
        Mini_addons_save_settings()
        config.SetBossMonsterEffectTransparency(num)
        ui.SysMsg("boss effect changed.")
    else
        ui.SysMsg("Not a valid value.")
        return
    end
end
-- その他のエフェクト設定を戻すIMCのバグ修正
function Mini_addons_OTHER_EFFECT_SETTING()
    if g.settings.other_effect == 0 then
        return
    end
    local frame = ui.GetFrame("systemoption")
    local slide = GET_CHILD_RECURSIVELY(frame, "effect_transparency_other_value", "ui::CSlideBar")
    if g.settings.other_effect_value then
        config.SetOtherEffectTransparency(g.settings.other_effect_value)
        slide:SetLevel(g.settings.other_effect_value)
    else
        local other_effect = config.GetOtherEffectTransparency()
        config.SetOtherEffectTransparency(other_effect)
    end
end

function Mini_addons_OTHER_EFFECT_EDIT(frame, ctrl)
    local other_effect = tonumber(ctrl:GetText())
    if other_effect <= 100 and other_effect >= 1 then
        local num = math.floor(other_effect / 0.392156862745 + 0.5)
        g.settings.other_effect_value = num
        Mini_addons_save_settings()
        config.SetOtherEffectTransparency(num)
        ui.SysMsg("other effect changed.")
    else
        ui.SysMsg("Not a valid value.")
        return
    end
end
-- エンブレム、アークの着け忘れお知らせ
function Mini_addons_SHOW_INDUNENTER_DIALOG(my_frame, my_msg)
    local current_time = os.clock()
    if g.last_indun_check_time and (current_time - g.last_indun_check_time < 1.0) then
        return
    end
    g.last_indun_check_time = current_time
    if g.settings.equip_info == 0 then
        return
    end
    local indun_frame = ui.GetFrame("indunenter")
    local indun_type = indun_frame:GetUserValue("INDUN_TYPE")
    local target_indun_list = {665, 670, 675, 678, 681, 628, 687, 690, 697, 709, 712, 718, 724, 727}
    local is_target = false
    for i = 1, #target_indun_list do
        if tostring(target_indun_list[i]) == tostring(indun_type) then
            is_target = true
            break
        end
    end
    if not is_target then
        return
    end
    local equip_item_list = session.GetEquipItemList()
    local cnt = equip_item_list:Count()
    for i = 0, cnt - 1 do
        local equip_item = equip_item_list:GetEquipItemByIndex(i)
        local spot_name = item.GetEquipSpotName(equip_item.equipSpot)
        local iesid = tostring(equip_item:GetIESID())
        if tostring(spot_name) == "SEAL" and tonumber(iesid) == 0 then
            if g.lang == "Japanese" then
                imcAddOn.BroadMsg("NOTICE_Dm_Global_Shout",
                    "{st55_a}{#FF8C00}エンブレム装備してないけど{nl}ええんか？", 3.0)
            else -- You don't have an emblem equipped. {nl} Is this okay?
                imcAddOn.BroadMsg("NOTICE_Dm_Global_Shout",
                    "{st55_a}{#FF8C00}You don't have an emblem equipped{nl}Is this okay?", 3.0)
            end
            break
        elseif tostring(spot_name) == "ARK" and tonumber(iesid) == 0 then
            if g.lang == "Japanese" then
                imcAddOn.BroadMsg("NOTICE_Dm_Global_Shout",
                    "{st55_a}{#FF8C00}アーク装備してないけど{nl}ええんか？", 3.0)
            else
                imcAddOn.BroadMsg("NOTICE_Dm_Global_Shout",
                    "{st55_a}{#FF8C00}You don't have an ark equipped{nl}Is this okay?", 3.0)
            end
            break
        end
    end
end
-- 自動マッチのレイヤーを下げる
function Mini_addons_INDUNENTER_AUTOMATCH_TYPE(my_frame, my_msg)
    local indunenter = ui.GetFrame("indunenter")
    if g.settings.automatch_layer == 1 then
        indunenter:SetLayerLevel(97)
    elseif g.settings.automatch_layer == 0 then
        indunenter:SetLayerLevel(100)
    end
end
-- 死んだ時の選択肢を動かす
function Mini_addons_RESTART_HERE()
    if g.settings.restart_move == 0 then
        return
    end
    local restart_contents = ui.GetFrame("restart_contents")
    if restart_contents:IsVisible() == 1 then
        restart_contents:EnableHittestFrame(1)
        restart_contents:EnableMove(1)
    end
    local restart = ui.GetFrame("restart")
    if restart:IsVisible() == 1 then
        restart:EnableHittestFrame(1)
        restart:EnableMove(1)
    end
end
-- 死んだ時のマウス位置制御
function Mini_addons_RESTART_CONTENTS_ON_HERE(my_frame, my_msg)
    if g.settings.restart_move == 0 then
        return
    end
    local restart_contents = ui.GetFrame("restart_contents")
    local btn_restart = GET_CHILD_RECURSIVELY(restart_contents, "btn_restart_" .. 1)
    local item_width = btn_restart:GetWidth()
    local item_height = btn_restart:GetHeight()
    local x, y = GET_SCREEN_XY(btn_restart + item_width / 2, btn_restart + item_height / 2)
    mouse.SetPos(x, y)
end
-- コロニー死んだ時に30秒タイマー動かないバグ修正
-- 決闘の申し込みを自動で受ける。
--
-- クライアントの ASKED_FRIENDLY_FIGHT / ASKED_ANCIENT_FRIENDLY_FIGHT(ui.ipf の
-- uiscp/community.lua)は確認ダイアログを出し、「はい」で ACK_*_FRIENDLY_FIGHT を呼ぶ。
-- ここではその ACK を直接呼んで、ダイアログを飛ばす。
--
-- **自前でパケットを送らず ACK を経由すること。** ACK_FRIENDLY_FIGHT は楽器バフ中に
-- 申し込みを弾く判定(packet.RequestFriendlyFight を呼ばず SysMsg を出す)を持っている。
-- ここを迂回すると、その判定ごと無くなる。
--
-- 通常の決闘と古代の決闘は別の関数なので、両方に同じ処理を掛ける
-- (利用者から見ればどちらも「決闘の申し込み」で、片方だけ自動だと分かりにくい)。
--
-- **フックは設定に関係なく全利用者に掛かる**(掛け外しは GAME_START_3SEC の一度きり)。
-- そのため、自動で受けない経路は元の関数へ**素通し**でなければならない。引数を
-- (handle, family_name) に固定して受け直すと、クライアントが 3 つ目以降を渡すように
-- なったときに黙って落ち、戻り値も握り潰す。機能を OFF にしている利用者まで巻き込むので、
-- ここは可変長(...)で受けてそのまま渡し、戻り値も返すこと。
local function Mini_addons_auto_accept_duel(ack_func_name, origin_func_name, ...)
    local handle, family_name = ...
    if g.settings and g.settings.auto_accept_duel == 1 and handle ~= nil then
        -- **成功ログは ACK を呼べたときだけ出す。** 存在チェックより前に出すと、
        -- ACK が無いときに「自動で受けた」と下の「戻す」が並んで出て、ログから
        -- どちらが起きたのか読めなくなる。
        local ack = _G[ack_func_name]
        if type(ack) == "function" then
            core_g.vlog("mini_addons: 決闘の申し込みを自動で受けた (%s / 相手 %s)", ack_func_name,
                tostring(family_name))
            return ack(handle)
        end
        -- ACK が居ない = クライアント側の作りが変わった。黙って握ると
        -- 「自動で受ける設定にしたのに何も起きない」になるので、元の確認ダイアログへ回す。
        core_g.vlog("{#FF6347}mini_addons: %s が見つからないので確認ダイアログに戻す{/}", ack_func_name)
    end
    local origin = g.FUNCS[origin_func_name]
    if origin then
        return origin(...)
    end
end

function Mini_addons_ASKED_FRIENDLY_FIGHT(...)
    return Mini_addons_auto_accept_duel("ACK_FRIENDLY_FIGHT", "ASKED_FRIENDLY_FIGHT", ...)
end

function Mini_addons_ASKED_ANCIENT_FRIENDLY_FIGHT(...)
    return Mini_addons_auto_accept_duel("ACK_ANCIENT_FRIENDLY_FIGHT", "ASKED_ANCIENT_FRIENDLY_FIGHT", ...)
end

function Mini_addons_RESTART_ON_MSG(frame, msg, str, num)
    if not g.settings.restart_colony or g.settings.restart_colony ~= 1 or msg ~= "RESTART_HERE" or
        (BitGet(num, 12) ~= 1 and BitGet(num, 14) ~= 1) then
        if g.FUNCS["RESTART_ON_MSG"] then
            g.FUNCS["RESTART_ON_MSG"](frame, msg, str, num)
        end
        return
    end
    local restart = ui.GetFrame("restart")
    restart:ShowWindow(1)
    for i = 1, 5 do
        local res_btn = GET_CHILD(restart, "restart" .. i .. "btn", "ui::CButton")
        if res_btn then
            res_btn:ShowWindow(BitGet(num, i))
        end
    end
    local mystic_btn = GET_CHILD(restart, "restart8btn", "ui::CButton")
    if mystic_btn then
        if BitGet(num, 14) == 1 then
            mystic_btn:ShowWindow(1)
        else
            mystic_btn:ShowWindow(0)
        end
    end
    if restart:GetUserIValue("COLONY_TIMER_RUNNING") ~= 1 then
        restart:SetUserValue("COLONY_TIMER_RUNNING", 1) -- 実行中フラグを立てる
        local res_btn_6 = GET_CHILD(restart, "restart6btn", "ui::CButton")
        if res_btn_6 then
            res_btn_6:ShowWindow(1)
            local text = "{@st66b}" .. ScpArgMsg("ReturnCity{SEC}", "SEC", 30) .. "{/}"
            res_btn_6:SetText(text)
        end
        g.colony_wait_time = 30
        restart:RunUpdateScript("Mini_addons_COLONY_WAR_RESTART_UPDATE", 1)
        AUTORESIZE_RESTART(restart)
        local res_btn_9 = GET_CHILD(restart, "restart9btn", "ui::CButton")
        if res_btn_9 then
            res_btn_9:ShowWindow(0)
        end
        local res_btn_10 = GET_CHILD(restart, "restart10btn", "ui::CButton")
        if res_btn_10 then
            res_btn_10:ShowWindow(0)
        end
        local restart_wait = GET_CHILD(restart, "restart_wait")
        if restart_wait then
            AUTO_CAST(restart_wait)
            restart_wait:ShowWindow(0)
        end
        restart:ShowWindow(1)
    end
end

function Mini_addons_COLONY_WAR_RESTART_UPDATE(restart)
    local res_btn = GET_CHILD(restart, "restart6btn", "ui::CButton")
    if not res_btn then
        return 0
    end
    g.colony_wait_time = g.colony_wait_time - 1
    if g.colony_wait_time < 0 then
        g.colony_wait_time = 0
    end
    local text = "{@st66b}" .. ScpArgMsg("ReturnCity{SEC}", "SEC", g.colony_wait_time) .. "{/}"
    res_btn:SetText(text)
    if g.colony_wait_time <= 0 then
        restart:SetUserValue("COLONY_TIMER_RUNNING", 0)
        return 0
    end
    if _G["COLONY_WAR_RESTART_BY_MYSTIC_UPDATE"] then
        COLONY_WAR_RESTART_BY_MYSTIC_UPDATE(restart)
    end
    return 1
end
-- ダイアログ制御系
function Mini_addons_DIALOG_CHANGE_SELECT(frame, msg, str, num)
    if g.settings.dialog_ctrl == 0 then
        return
    end
    local dialogselect = ui.GetFrame("dialogselect")
    if str == "WAREHOUSE_DLG" or str == "ORSHA_WAREHOUSE_DLG" or str == "WAREHOUSE_FEDIMIAN_DLG" and msg ==
        "DIALOG_CHANGE_SELECT" then -- 倉庫
        session.SetSelectDlgList()
        ui.OpenFrame("dialogselect")
        DialogSelect_index = 2
        local btn2 = GET_CHILD_RECURSIVELY(dialogselect, "item2Btn")
        local x, y = GET_SCREEN_XY(btn2)
        mouse.SetPos(x + 190, y)
        return
    end
    if str == "NPC_PERSONAL_HOUSING_MANAGER_DLG_2" then -- 住居クポル
        session.SetSelectDlgList()
        ui.OpenFrame("dialogselect")
        control.DialogItemSelect(1)
    elseif string.find(str, "PERSONAL_HOUSING_POINT_CHECK_MSG_1") then
        session.SetSelectDlgList()
        ui.OpenFrame("dialogselect")
        control.DialogItemSelect(1)
    elseif string.find(str, "PH_POINT_SHOP_DLG_SEL_1") then
        session.SetSelectDlgList()
        ui.CloseFrame("dialog")
        ui.OpenFrame("dialogselect")
        DialogSelect_index = 3
        local btn = GET_CHILD_RECURSIVELY(dialogselect, "item3Btn")
        local x, y = GET_SCREEN_XY(btn)
        mouse.SetPos(x + 190, y)
        return
    end
    if str == "Goddess_Raid_Rozethemiserable_Start_Npc_Dlg" or str == "Goddess_Raid_Spreader_Start_Npc_DLG1" or str ==
        "Goddess_Raid_Jellyzele_Start_Npc_DLG1" or str == "EP14_Raid_Delmore_NPC_DLG1" or str ==
        "Goddess_Raid_DespairIsland_Start_Npc_Dlg" then
        session.SetSelectDlgList()
        ui.CloseFrame("dialog")
        ui.OpenFrame("dialogselect")
        DialogSelect_index = 2
        local btn = GET_CHILD_RECURSIVELY(dialogselect, "item2Btn")
        local x, y = GET_SCREEN_XY(btn)
        mouse.SetPos(x + 190, y)
        return
    end
    local pc = GetMyPCObject()
    local cur_map = GetZoneName(pc)
    if (str == "Legend_Raid_Giltine_ENTER_MSG" and cur_map == "raid_dcapital_108") then
        session.SetSelectDlgList()
        ui.CloseFrame("dialog")
        ui.OpenFrame("dialogselect")
        DialogSelect_index = 2
        local btn = GET_CHILD_RECURSIVELY(dialogselect, "item2Btn")
        local x, y = GET_SCREEN_XY(btn)
        mouse.SetPos(x + 190, y)
        return
    end
end
-- ファミリーネームからログインネームへ変換
function Mini_addons_PCNAME_REPLACE(frame, msg)
    if g.settings.pc_name == 0 then
        return
    end
    local headsupdisplay = ui.GetFrame("headsupdisplay")
    local name_text = GET_CHILD_RECURSIVELY(headsupdisplay, "name_text")
    local login_name = session.GetMySession():GetPCApc():GetName()
    if name_text:GetText() ~= "{@st41}" .. tostring(login_name) then
        name_text:SetText("{@st41}" .. tostring(login_name))
    end
end
-- オートキャスティングをキャラ毎に設定
function Mini_addons_CONFIG_ENABLE_AUTO_CASTING(my_frame, my_msg)
    local parent, ctrl = g.get_event_args(my_msg)
    local enable = ctrl:IsChecked()
    g.settings.auto_casting[g.cid] = enable
    Mini_addons_save_settings()
end

function Mini_addons_SET_ENABLE_AUTO_CASTING()
    if g.settings.auto_cast == 0 then
        return
    end
    local systemoption = ui.GetFrame("systemoption")
    local Check_EnableAutoCasting = GET_CHILD_RECURSIVELY(systemoption, "Check_EnableAutoCasting", "ui::CCheckBox")
    Check_EnableAutoCasting:SetCheck(g.settings.auto_casting[g.cid] or 1)
    config.SetEnableAutoCasting(g.settings.auto_casting[g.cid] or 1)
    config.SaveConfig()
end
-- チャンネル切替フレーム
function Mini_addons_GAME_START_CHANNEL_LIST()
    if g.settings.channel_info == 0 then
        return
    end
    Mini_addons_POPUP_CHANNEL_LIST()
    local sysmenu = ui.GetFrame("sysmenu")
    if sysmenu then
        local system = GET_CHILD(sysmenu, "system")
        if system then
            if system:HaveUpdateScript("Mini_addons_POPUP_CHANNEL_LIST") == false then
                system:RunUpdateScript("Mini_addons_POPUP_CHANNEL_LIST", 2)
            end
        end
    end
end

function Mini_addons_POPUP_CHANNEL_LIST()
    local zone_insts = session.serverState.GetMap()
    local frame_name = (addon_name_lower .. "_channel")
    -- この関数は sysmenu/system(自分のフレームではない)へ 2 秒周期の更新スクリプトとして
    -- 掛かっており、1 を返す限り走り続ける。Mini_addons_teardown は自分のフレームしか
    -- 畳めないので、機能 OFF にしてもここが生き残り、2 秒後にフレームを作り直していた。
    -- 0 を返すと更新スクリプトが外れるので、OFF はここで止める。再び ON にすれば
    -- Mini_addons_GAME_START_CHANNEL_LIST が HaveUpdateScript を見て掛け直す。
    -- チャンネル表示だけ OFF にした場合も同じ経路で片付く。
    if not core_g.settings or not core_g.settings.mini_addons or core_g.settings.mini_addons.use ~= 1 or
        not g.settings or g.settings.channel_info == 0 then
        ui.DestroyFrame(frame_name)
        core_g.vlog("mini_addons: チャンネル窓の更新を止めた(機能 OFF)")
        return 0
    end
    if not zone_insts then
        local frame = ui.GetFrame(frame_name)
        if frame then
            frame:ShowWindow(0)
        end
        g.zone_insts = false
        return 0
    else
        g.zone_insts = true
    end
    local frame = ui.CreateNewFrame("notice_on_pc", frame_name, 10, 10, 10, 10)
    AUTO_CAST(frame)
    frame:RemoveAllChild()
    frame:SetSkinName("None")
    frame:SetTitleBarSkin("None")
    frame:EnableHittestFrame(1)
    frame:EnableMove(1)
    if not g.settings.frame_X then
        g.settings.frame_X = 1500
        g.settings.frame_Y = 385
        Mini_addons_save_settings()
    end
    if not g.settings.ch_frame_size then
        g.settings.ch_frame_size = 40
        Mini_addons_save_settings()
    end
    local map_frame = ui.GetFrame("map")
    local screen_width = map_frame:GetWidth()
    local x = g.settings.frame_X
    local y = g.settings.frame_Y
    if x > 1920 and screen_width <= 1920 then
        x = 1500
        y = 385
    end
    frame:SetPos(x, y)
    frame:SetEventScript(ui.LBUTTONUP, "Mini_addons_channelframe_move")
    frame:SetEventScript(ui.RBUTTONUP, "Mini_addons_ch_frame_resize")
    local title = frame:CreateOrGetControl("richtext", "title", 5, 0)
    title:SetText("{ol}{s12}channel info")
    if zone_insts:NeedToCheckUpdate() == true then
        app.RequestChannelTraffics()
    end
    local cnt = zone_insts:GetZoneInstCount()
    local current_channel = session.loginInfo.GetChannel()
    local size = g.settings.ch_frame_size
    for i = 0, cnt - 1 do
        local zone_inst = zone_insts:GetZoneInstByIndex(i)
        local pc_count = zone_inst.pcCount
        local btn = frame:CreateOrGetControl("button", "slot" .. i, i * size + 5, 15, size, size)
        AUTO_CAST(btn)
        btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_ch_change")
        btn:SetEventScriptArgString(ui.LBUTTONUP, i)
        if i == current_channel then
            btn:SetSkinName("test_pvp_btn")
        end
        local color_tag = ""
        if tonumber(pc_count) >= 50 then
            color_tag = "{#FF0000}" -- 赤
        elseif tonumber(pc_count) >= 20 then
            color_tag = "{#FFCC33}" -- 黄
        else
            color_tag = "" -- デフォルト(白)
        end
        local text = string.format("{ol}{s12}ch%d{nl}{s16}%s%d", i + 1, color_tag, pc_count)
        btn:SetText(text)
    end
    frame:Resize(cnt * size + 20, 60)
    frame:ShowWindow(1)
    return 1
end

function Mini_addons_channelframe_move(frame)
    g.settings.frame_X = frame:GetX()
    g.settings.frame_Y = frame:GetY()
    Mini_addons_save_settings()
end

function Mini_addons_ch_frame_resize(frame, btn, str, num)
    if g.settings.ch_frame_size == 40 then
        g.settings.ch_frame_size = 50
    else
        g.settings.ch_frame_size = 40
    end
    Mini_addons_save_settings()
    Mini_addons_POPUP_CHANNEL_LIST()
end

function Mini_addons_ch_change(frame, ctrl, str, num)
    local channel = tonumber(str) -- 0が1chらしい
    RUN_GAMEEXIT_TIMER("Channel", str)
end
-- ペットコマンド制御
function Mini_addons_SHOW_PET_RINGCOMMAND(my_frame, my_msg)
    local actor = g.get_event_args(my_msg)
    if g.settings.pet_ring == 1 then
        return
    else
        g.FUNCS["SHOW_PET_RINGCOMMAND"](actor)
    end
end
-- レリックゲージ
function Mini_addons_CHARBASE_RELIC()
    if g.settings.relic_gauge == 0 then
        return
    end
    if HEADSUPDISPLAY_OPTION.relic_equip == 0 then
        return
    end
    local charbaseinfo1_my = ui.GetFrame("charbaseinfo1_my")
    local pcRelicGauge = charbaseinfo1_my:CreateOrGetControl("gauge", "pcRelicGauge", -1, 54, 104, 11)
    AUTO_CAST(pcRelicGauge)
    local pcRelic_text = pcRelicGauge:CreateOrGetControl("richtext", "pcRelic_text", 0, 0, 50, 0)
    AUTO_CAST(pcRelic_text)
    pcRelicGauge:SetGravity(ui.CENTER_HORZ, ui.TOP)
    pcRelicGauge:EnableHitTest(0)
    pcRelicGauge:SetSkinName("pcinfo_gauge_rp_relic")
    pcRelicGauge:StopTimeProcess()
    local pc = GetMyPCObject()
    local cur_rp, max_rp = shared_item_relic.get_rp(pc)
    pcRelic_text:SetGravity(ui.CENTER_HORZ, ui.CENTER_VERT)
    pcRelic_text:SetText("{ol}{s12}" .. cur_rp)
    pcRelicGauge:SetPoint(cur_rp / 10, max_rp / 10)
end
-- パーティー情報フレームを小さくする
function Mini_addons_PARTY_BUFFLIST_UPDATE(frame, msg)
    local party_info = ui.GetFrame("partyinfo")
    local list = session.party.GetPartyMemberList(PARTY_NORMAL)
    local member_count = list:Count()
    local display_count = member_count - 1
    if display_count < 0 then
        display_count = 0
    end
    if g.settings.party_info == 0 then
        -- OFF のときは素の見た目へ戻すだけにする。幅 560 は素の値ではないので、
        -- partyinfo.xml と同じ値(= GetOriginalWidth / layerlevel 50)へ戻す。
        -- 高さは素の PARTY_BUFFLIST_UPDATE が自分で計算するので触らない
        party_info:Resize(party_info:GetOriginalWidth(), party_info:GetHeight())
        party_info:SetLayerLevel(50)
        return
    end
    local max_buff_width = 0
    local slot_size = 25 -- スロット1つの幅
    for i = 0, member_count - 1 do
        local party_member_info = list:Element(i)
        local party_info_ctrl_set = party_info:GetChild('PTINFO_' .. party_member_info:GetAID())
        if party_info_ctrl_set then
            local current_member_buffs = 0
            local buff_list = GET_CHILD(party_info_ctrl_set, "buffList", "ui::CSlotSet")
            if buff_list then
                for j = 0, buff_list:GetSlotCount() - 1 do
                    local slot = buff_list:GetSlotByIndex(j)
                    if slot and slot:IsVisible() == 1 then
                        local icon = slot:GetIcon()
                        if icon then
                            current_member_buffs = current_member_buffs + 1
                        end
                    end
                end
            end
            local debuff_list = GET_CHILD(party_info_ctrl_set, "debuffList", "ui::CSlotSet")
            if debuff_list then
                for j = 0, debuff_list:GetSlotCount() - 1 do
                    local slot = debuff_list:GetSlotByIndex(j)
                    if slot and slot:IsVisible() == 1 then
                        local icon = slot:GetIcon()
                        if icon then
                            current_member_buffs = current_member_buffs + 1
                        end
                    end
                end
            end
            local needed_width = current_member_buffs * slot_size
            if needed_width > max_buff_width then
                max_buff_width = needed_width
            end
        end
    end
    party_info:Resize(250 + max_buff_width, display_count * 100 + 60)
    party_info:SetLayerLevel(0)
end

--[[function mini_addons_partyinfo_resize(partyinfo, ctrl, str, num)
    local list = session.party.GetPartyMemberList(PARTY_NORMAL)
    local count = list:Count() - 1
    if count < 0 then
        count = 0
    end
    if partyinfo:GetWidth() == 80 then
        partyinfo:Resize(560, count * 100 + 60)
    else
        partyinfo:Resize(80, count * 100 + 60)
    end
end]]
-- EP13ショップを街で開ける
function Mini_addons_REPUTATION_SHOP_OPEN()
    local inventory = ui.GetFrame("inventory")
    local inventory_accpropinv = GET_CHILD_RECURSIVELY(inventory, "inventory_accpropinv")
    AUTO_CAST(inventory_accpropinv)
    if g.get_map_type() == "City" then
        inventory_accpropinv:SetEventScript(ui.RBUTTONUP, "Mini_addons_REPUTATION_SHOP_OPEN_context")
        inventory_accpropinv:SetEventScript(ui.RBUTTONDOWN, "Mini_addons_reputation_shop_close")
    else
        inventory_accpropinv:SetEventScript(ui.RBUTTONUP, "None")
        inventory_accpropinv:SetEventScript(ui.RBUTTONDOWN, "None")
    end
end

function Mini_addons_ON_REQUEST_REPUTATION_SHOP_OPEN(shop_type)
    REPUTATION_SHOP_SET_SHOPTYPE(shop_type)
    ui.OpenFrame("reputation_shop")
end

function Mini_addons_REPUTATION_SHOP_OPEN_context(frame, ctrl, str, num)
    local context = ui.CreateContextMenu("select_shop", "EP13 Shop List ", 0, -200, 0, 0)
    local shop_tbl = {{
        name = "REPUTATION_ep13_f_siauliai_1",
        id = 11209,
        text = ClMsg("MonInfo_RaceType_Velnias"),
        box = ""
    }, {
        name = "REPUTATION_ep13_f_siauliai_2",
        id = 11210,
        text = ClMsg("MonInfo_RaceType_Widling"),
        box = ""
    }, {
        name = "REPUTATION_ep13_f_siauliai_3",
        id = 11211,
        text = ClMsg("MonInfo_RaceType_Klaida"),
        box = GetClassByType("Item", 640530).Name
    }, {
        name = "REPUTATION_ep13_f_siauliai_4",
        id = 11212,
        text = ClMsg("MonInfo_RaceType_Paramune"),
        box = GetClassByType("Item", 640531).Name
    }, {
        name = "REPUTATION_ep13_f_siauliai_5",
        id = 11213,
        text = ClMsg("MonInfo_RaceType_Forester"),
        box = ""
    }}
    for index, shop in ipairs(shop_tbl) do
        local shop_name = shop.name
        local id = shop.id
        local map_name = GetClassByType("Map", id).Name
        local box = shop.box
        local text = g.lang == "Japanese" and
                         string.gsub(dic.getTranslatedStr(shop.text), "型", " 憤怒ポーション ") ..
                         "製造書 : " .. box or shop.text .. " Recipe : " .. box
        ui.AddContextMenuItem(context, map_name .. " (" .. text .. ") ",
            string.format("Mini_addons_ON_REQUEST_REPUTATION_SHOP_OPEN('%s')", shop_name))
    end
    ui.OpenContextMenu(context)
end

function Mini_addons_reputation_shop_close()
    local shopframe = ui.GetFrame("reputation_shop")
    if shopframe:IsVisible() == 1 then
        ui.CloseFrame("reputation_shop")
        ui.ToggleFrame("inventory")
    end
end
-- ヴェルニケ自動受取り
function Mini_addons_SOLODUNGEON_RANKINGPAGE_GET_REWARD()
    if g.settings.solodun_reward == 0 then
        return
    end
    if g.solodun_reward then
        return
    end
    soloDungeonClient.ReqSoloDungeonReward()
    g.solodun_reward = true
end
-- ボスレ報酬自動受取り
function Mini_addons_WEEKLY_BOSS_REWARD()
    if g.settings.weekly_boss_reward == 0 then
        return
    end
    if session.weeklyboss.GetNowWeekNum() == 0 then
        weekly_boss.RequestWeeklyBossNowWeekNum()
    end
    local week_num = WEEKLY_BOSS_RANK_WEEKNUM_NUMBER()
    if g.settings.reward_switch == 1 then
        week_num = WEEKLY_BOSS_RANK_WEEKNUM_NUMBER() - 1
    end
    if week_num ~= 0 then
        weekly_boss.RequestAcceptAbsoluteRewardAll(week_num)
        if not g.wbreward then
            local indun_info = ui.GetFrame("induninfo")
            indun_info:Resize(0, 0)
            indun_info:ShowWindow(1)
            TOGGLE_INDUNINFO(indun_info, 3)
            local tab = GET_CHILD_RECURSIVELY(indun_info, "tab")
            AUTO_CAST(tab)
            tab:SelectTab(3)
            INDUNINFO_TAB_CHANGE(tab, tab)
            local season_tab = GET_CHILD_RECURSIVELY(indun_info, "season_tab")
            AUTO_CAST(season_tab)
            season_tab:SelectTab(1)
            g.index = 0
            indun_info:RunUpdateScript("Mini_addons_WEEKLY_BOSS_RANK_REWARD", 1.5)
        end
    end
end

function Mini_addons_WEEKLY_BOSS_RANK_REWARD(indun_info)
    local classtype_tab = GET_CHILD_RECURSIVELY(indun_info, "classtype_tab")
    AUTO_CAST(classtype_tab)
    classtype_tab:SelectTab(g.index)
    if g.index <= 4 then
        WEEKLY_BOSS_DATA_REUQEST()
        classtype_tab:RunUpdateScript("Mini_addons_WEEKLY_BOSS_RANK_GET_REWARD", 1.0)
        return 1
    else
        indun_info:ShowWindow(0)
        indun_info:Resize(1095, 610)
        indun_info:StopUpdateScript("Mini_addons_WEEKLY_BOSS_RANK_REWARD")
        g.wbreward = true
        return 0
    end
end

function Mini_addons_WEEKLY_BOSS_RANK_GET_REWARD(classtype_tab)
    local week_num = WEEKLY_BOSS_RANK_WEEKNUM_NUMBER()
    local myrank = session.weeklyboss.GetMyRankInfo(week_num)
    local indun_info = ui.GetFrame("induninfo")
    local classtype_tab = GET_CHILD_RECURSIVELY(indun_info, "classtype_tab")
    AUTO_CAST(classtype_tab)
    if myrank ~= 0 and myrank <= 100 then
        weekly_boss.RequestAccpetRankingReward(week_num, myrank)
        indun_info:ShowWindow(0)
        indun_info:Resize(1095, 610)
        indun_info:StopUpdateScript("Mini_addons_WEEKLY_BOSS_RANK_REWARD")
        classtype_tab:StopUpdateScript("Mini_addons_WEEKLY_BOSS_RANK_GET_REWARD")
        g.wbreward = true
        return
    elseif myrank ~= 0 and myrank > 100 then
        indun_info:ShowWindow(0)
        indun_info:Resize(1095, 610)
        indun_info:StopUpdateScript("Mini_addons_WEEKLY_BOSS_RANK_REWARD")
        classtype_tab:StopUpdateScript("Mini_addons_WEEKLY_BOSS_RANK_GET_REWARD")
        g.wbreward = true
        return
    end
    g.index = g.index + 1
end

function Mini_addons_WEEKLY_BOSS_REWARD_SWITCH(frame, ctrl, str, num)
    if g.settings.reward_switch == 1 then
        g.settings.reward_switch = 0
        ctrl:SetText(g.lang == "Japanese" and "{ol}今週分" or "{ol}this week")
    else
        g.settings.reward_switch = 1
        ctrl:SetText(g.lang == "Japanese" and "{ol}先週分" or "{ol}last week")
    end
    Mini_addons_save_settings()
end
-- 街のラガナを非表示
function Mini_addons_ragana_remove_timer()
    if g.settings.goodbye_ragana == 0 then
        return
    end
    local mini_addons = g.get_frame()
    mini_addons:RunUpdateScript("Mini_addons_ragana_remove", 1.0)
end

function Mini_addons_ragana_remove(mini_addons)
    local selected_objects, selected_objects_count = SelectObject(GetMyPCObject(), 1000, "ALL")
    for i = 1, selected_objects_count do
        local handle = GetHandle(selected_objects[i])
        if handle then
            if info.IsPC(handle) ~= 1 then
                local npc_name = world.GetActor(handle):GetName()
                if npc_name == "[마신의 유혹]{nl}마신 라가나의 환영" then
                    world.Leave(handle, 0.0)
                    return 0
                end

            end
        end
    end
    return 1
end
-- RPチャージを補完
function Mini_addons_rp_check()
    if g.settings.rp_charge == 0 then
        return
    end
    local openingameshopbtn = ui.GetFrame("openingameshopbtn")
    local open_openingameshopbtn = GET_CHILD(openingameshopbtn, "open_openingameshopbtn")
    AUTO_CAST(open_openingameshopbtn)
    open_openingameshopbtn:RunUpdateScript("Mini_addons_rp_check_", 0.1)
end

function Mini_addons_rp_check_(frame)
    local indunenter = ui.GetFrame("indunenter")
    if not indunenter then
        return 1
    end
    if indunenter:IsVisible() == 0 then
        return 1
    end
    local pc = GetMyPCObject()
    local cur_rp, max_rp = shared_item_relic.get_rp(pc)
    if cur_rp == max_rp then
        return 1
    end
    local item_count = 0
    local item_names = {"misc_Ectonite", "misc_Ectonite_Care"}
    for _, item_name in ipairs(item_names) do
        local item = session.GetInvItemByName(item_name)
        if item and item.count > 0 then
            item_count = item_count + item.count
        end
    end
    if item_count == 0 then
        ui.SysMsg(g.lang == "Japanese" and
                      "エクトナイトを持っていません{nl}自動補充監視を終了します" or
                      "You don't have an Ectonite{nl}Automatic replenishment monitoring will be terminated")
        return 0
    end
    session.ResetItemList()
    for _, item_name in ipairs(item_names) do
        local item = session.GetInvItemByName(item_name)
        if item and not item.isLockState then
            session.AddItemID(item:GetIESID(), item.count)
        end
    end
    local result_list = session.GetItemIDList()
    item.DialogTransaction("RELIC_CHARGE_RP", result_list)
    frame:StopUpdateScript("Mini_addons_rp_check_")
    frame:RunUpdateScript("Mini_addons_rp_check_end", 0.1)
    return 0
end

function Mini_addons_rp_check_end(frame)
    local pc = GetMyPCObject()
    local cur_rp, max_rp = shared_item_relic.get_rp(pc)
    if cur_rp == max_rp then
        ui.SysMsg(g.lang == "Japanese" and "レリック自動補充完了" or "Relic auto-replenishment complete")
    elseif cur_rp < max_rp then
        ui.SysMsg(g.lang == "Japanese" and "レリック自動補充完了出来ませんでした" or
                      "Relic auto-replenishment failed")
    end
end
-- 町でマーケットボタンを常に表示
function Mini_addons_MINIMIZED_TOTAL_SHOP_BUTTON_CLICK()
    local market_button = ui.GetFrame("minimized_market_button")
    if g.settings.market_display == 1 and market_button:IsVisible() == 0 then
        MINIMIZED_TOTAL_SHOP_BUTTON_CLICK()
    end
end
-- 傭兵団コイン、女神コイン、王国再建団コインを取得時、自動で使用
function Mini_addons_INV_ICON_USE(mini_addons)
    if g.settings.coin_use == 0 then
        return
    end
    if g.get_map_type() ~= "City" then
        return
    end
    local god_protection = ui.GetFrame("godprotection")
    if god_protection:IsVisible() == 1 then
        return
    end
    local inv_item_list = session.GetInvItemList()
    local guid_list = inv_item_list:GetGuidList()
    local cnt = guid_list:Count()
    for i = 0, cnt - 1 do
        local guid = guid_list:Get(i)
        local inv_item = inv_item_list:GetItemByGuid(guid)
        local item_obj = GetIES(inv_item:GetObject())
        for _, coin_id in ipairs(COIN_ITEM) do
            if item_obj.ClassID == coin_id then
                item.UseByGUID(guid)
                return
            end
        end
    end
end
-- 錬成時に自動でアイテムセット
function Mini_addons_SUCCESS_COMMON_SKILL_ENCHANT(frame, msg)
    if g.settings.skill_enchant == 0 then
        return
    end
    ReserveScript("Mini_addons_COMMON_SKILL_ENCHANT_ADD_MAT()", 0.9)
    return
end

function Mini_addons_COMMON_SKILL_ENCHANT_MAT_SET(my_frame, my_msg)
    if g.settings.skill_enchant == 0 then
        return
    end
    ReserveScript("Mini_addons_COMMON_SKILL_ENCHANT_ADD_MAT()", 0.2)
    return
end

function Mini_addons_COMMON_SKILL_ENCHANT_ADD_MAT(parent, ctrl)
    local common_skill_enchant = ui.GetFrame("common_skill_enchant")
    if not common_skill_enchant then
        return
    end
    local bottom_bg = GET_CHILD_RECURSIVELY(common_skill_enchant, "bottom_Bg")
    local cnt = bottom_bg:GetChildCount()
    local set_ready_count = 0
    for i = 1, cnt - 1 do
        local ctrl_set = bottom_bg:GetChildByIndex(i)
        local mat_slot = GET_CHILD_RECURSIVELY(ctrl_set, "mat_slot")
        local plus = GET_CHILD_RECURSIVELY(ctrl_set, "plus")
        plus:ShowWindow(1)
        local mat_name = GET_CHILD_RECURSIVELY(ctrl_set, "mat_name")
        local cnt_in_my_bag = GET_CHILD_RECURSIVELY(ctrl_set, "cnt_in_my_bag")
        local val_1 = GET_NOT_COMMAED_NUMBER(mat_name:GetTextByKey("value2"))
        local val_2 = GET_NOT_COMMAED_NUMBER(cnt_in_my_bag:GetTextByKey("value"))
        val_1 = tonumber(val_1)
        val_2 = tonumber(val_2)
        if val_1 <= val_2 then
            local icon = mat_slot:GetIcon()
            if icon then
                icon:SetColorTone("FFFFFFFF")
            end
            plus:ShowWindow(0)
            set_ready_count = set_ready_count + 1
        else
            local msg = string.format("<%s> %s", mat_name:GetTextByKey("value"), ClMsg("NotEnoughMaterial"))
            ui.SysMsg(msg)
        end
    end
    if set_ready_count == (cnt - 1) then
        common_skill_enchant:SetUserValue("IS_READY", "TRUE")
        GET_CHILD_RECURSIVELY(common_skill_enchant, "do_enchant"):SetEnable(1)
    else
        common_skill_enchant:SetUserValue("IS_READY", "FALSE")
    end
end
-- 自動女神ガチャ
function Mini_addons_GP_FULL_BET()
    local godprotection = ui.GetFrame("godprotection")
    local auto_gb = GET_CHILD_RECURSIVELY(godprotection, "auto_gb")
    if g.settings.auto_gacha == 1 then
        local fbbtn = auto_gb:CreateOrGetControl("button", "fbbtn", 200, 30, 100, 40)
        AUTO_CAST(fbbtn)
        fbbtn:SetSkinName("None")
        fbbtn:SetText("{img login_test_button 95 35}")
        local fbtext = fbbtn:CreateOrGetControl("button", "fbtext", 0, 0, 100, 40)
        fbtext:SetSkinName("None")
        fbtext:SetText("{ol}  Full Bet")
        fbtext:SetAnimation("MouseOnAnim", "btn_mouseover")
        fbtext:SetEventScript(ui.LBUTTONUP, "Mini_addons_GP_FULL_BET_START")
    else
        auto_gb:RemoveChild("fbbtn")
    end
end

function Mini_addons_GP_DO_OPEN()
    if g.settings.auto_gacha == 0 then
        g.first = nil
        return
    end
    if not g.first then
        g.first = true
        GODPROTECTION_DO_OPEN()
        if g.settings.auto_gacha_start == 1 then
            local mini_addons = g.get_frame()
            mini_addons:RunUpdateScript("Mini_addons_GP_FULL_BET_START", 2.0)
        end
    end
end

function Mini_addons_GP_FULL_BET_START(mini_addons)
    local godprotection = ui.GetFrame("godprotection")
    local multiple_count = 20
    local multiple_count_edit = GET_CHILD_RECURSIVELY(godprotection, "multiple_count_edit")
    multiple_count_edit:SetText(multiple_count)
    local edit = GET_CHILD_RECURSIVELY(godprotection, "auto_edit")
    local count = 99999999
    local next_count = count - 1
    edit:SetText(next_count)
    local auto_text = GET_CHILD_RECURSIVELY(godprotection, "auto_text")
    auto_text:ShowWindow(0)
    local parent = GET_CHILD_RECURSIVELY(godprotection, "auto_gb")
    local auto_btn = GET_CHILD_RECURSIVELY(godprotection, "auto_btn")
    GODPROTECTION_AUTO_START_BTN_CLICK(parent, auto_btn)
    return 0
end

function Mini_addons_FIELD_BOSS_WORLD_EVENT_END(frame)
    local godprotection = ui.GetFrame("godprotection")
    godprotection:ShowWindow(0)
    g.first = nil
end

function Mini_addons_GP_AUTOSTART_OPERATION(frame, ctrl)
    AUTO_CAST(ctrl)
    if g.settings.auto_gacha_start == 0 then
        g.settings.auto_gacha_start = 1
        ctrl:SetText("{ol}{#FFFFFF}ON")
        ctrl:SetSkinName("test_red_button")
    else
        g.settings.auto_gacha_start = 0
        ctrl:SetText("{ol}{#FFFFFF}OFF")
        ctrl:SetSkinName("test_gray_button")
    end
    Mini_addons_save_settings()
end
-- 町でBGMPLAYERを常に動かす
function Mini_addons_BGM_PLAY()
    if g.get_map_type() ~= "City" then
        ui.CloseFrame("bgmplayer_reduction")
        local bgm_player = ui.GetFrame("bgmplayer")
        local play_btn = GET_CHILD_RECURSIVELY(bgm_player, "playStart_btn")
        Mini_addons_BGMPLAYER_PLAY(bgm_player, play_btn)
        return
    end
    if g.settings.bgm == 0 then
        return
    end
    BGMPLAYER_OPEN_UI(nil, nil)
    local bgm_player = ui.GetFrame("bgmplayer")
    local player_controller_gb = GET_CHILD_RECURSIVELY(bgm_player, "playercontroler_gb")
    local play_start_btn = GET_CHILD_RECURSIVELY(bgm_player, "playStart_btn")
    local mode = tonumber(bgm_player:GetUserValue("MODE_ALL_LIST"))
    local option = tonumber(bgm_player:GetUserValue("MODE_FAVO_LIST"))
    local play_random = tonumber(bgm_player:GetUserConfig("PLAY_RANDOM"))
    local bgm_music_title_text = GET_CHILD_RECURSIVELY(bgm_player, "bgm_music_title")
    if bgm_music_title_text then
        local title = bgm_music_title_text:GetTextByKey("value")
        if title then
            local halt_image_name = bgm_player:GetUserConfig("PLAY_HALT_BTN_IMAGE_NAME")
            local start_image_name = bgm_player:GetUserConfig("PLAY_START_BTN_IMAGE_NAME")
            local select_ctrl_set_name = g.settings.select_bgm
            if not select_ctrl_set_name then
                return
            end
            local select_ctrl_set = GET_CHILD_RECURSIVELY(bgm_player, select_ctrl_set_name)
            local title_text = nil
            if select_ctrl_set then
                local parent = select_ctrl_set:GetParent()
                if parent ~= nil then
                    BGMPLAYER_SET_MUSIC_TITLE(bgm_player, parent, select_ctrl_set)
                end
                title_text = GET_CHILD_RECURSIVELY(select_ctrl_set, "musictitle_text")
            end
            if title_text == nil then
                return
            end
            local music_title = title_text:GetTextByKey("value")
            if music_title then
                local music_title_parts = StringSplit(music_title, ". ")
                local index_str = music_title_parts[1]
                if string.find(index_str, "{#ffc03a}") ~= nil then
                    local find_start, find_end = string.find(index_str, "{#ffc03a}")
                    if find_start ~= nil and find_end ~= nil then
                        index_str = string.sub(index_str, find_end + 1, string.len(index_str))
                    end
                end
                local index = tonumber(index_str)
                local bgm_type = GET_BGMPLAYER_MODE(bgm_player, mode, option)
                if bgm_type == 1 then
                    SetBgmCurIndex(index, play_random)
                elseif bgm_type == 0 then
                    SetBgmCurFVIndex(index, play_random)
                end
                title = bgm_music_title_text:GetTextByKey("value")
                PlayBgm(title, select_ctrl_set_name)
                BGMPLAYER_REDUCTION_SET_PLAYBTN(true)
                BGMPLAYER_REDUCTION_SET_TITLE(title)
                local total_time = GetPlayBgmTotalTime()
                total_time = total_time / 1000
                local start_time = 0
                if GetBgmPauseTime() > 0 then
                    start_time = GetBgmPauseTime() / 1000
                    SetPauseTime(0)
                end
                BGMPLAYER_PLAYTIME_GAUGE(start_time, total_time)
            end
            if play_start_btn:GetImageName() == start_image_name then
                play_start_btn:SetImage(halt_image_name)
                play_start_btn:SetTooltipArg(ScpArgMsg("BgmPlayer_HaltBtnToolTip"))
            else
                play_start_btn:SetImage(start_image_name)
                play_start_btn:SetTooltipArg(ScpArgMsg("BgmPlayer_StartBtnToolTip"))
            end
            BGMPLAYER_CLOSE_UI()
        end
    end
end

function Mini_addons_BGMPLAYER_PLAY(bgm_player, play_btn)
    local bgm_music_title_text = GET_CHILD_RECURSIVELY(bgm_player, "bgm_music_title")
    if bgm_music_title_text then
        local title = bgm_music_title_text:GetTextByKey("value")
        local delay_time = 0
        StopBgm(title, delay_time)
        BGMPLAYER_REDUCTION_SET_PLAYBTN(false)
        return
    end
end

function Mini_addons_BGM_PLAY_LIST()
    if g.settings.bgm == 0 then
        return
    end
    local bgm_player = ui.GetFrame("bgmplayer")
    if not bgm_player then
        return
    end
    if not g.settings.select_bgm or g.settings.select_bgm == "" or g.settings.select_bgm == "None" then
        g.settings.select_bgm = "MUSICINFO_1"
        Mini_addons_save_settings()
    end
    local current_sel = bgm_player:GetUserValue("CTRLSET_NAME_SELECTED")
    if bgm_player:IsVisible() == 0 and current_sel == "None" then
        bgm_player:SetUserValue("CTRLSET_NAME_SELECTED", g.settings.select_bgm)
        current_sel = g.settings.select_bgm
    end
    if current_sel ~= "None" and g.settings.select_bgm ~= current_sel then
        g.settings.select_bgm = current_sel
        Mini_addons_save_settings()
    end
end
-- 小さいボタンをレイドで非表示
function Mini_addons_MINIMIZED_CLOSE()
    if g.settings.mini_btn == 0 then
        return
    end
    if g.get_map_type() ~= "Instance" then
        return
    end
    local tp_button = ui.GetFrame("openingameshopbtn") -- TP受け取りボタン
    if tp_button and tp_button:IsVisible() == 1 then
        tp_button:ShowWindow(0)
    end
    local pilgrim_mode = ui.GetFrame("minimized_pilgrim_mode") -- ピルグリムボタン
    if pilgrim_mode and pilgrim_mode:IsVisible() == 1 then
        pilgrim_mode:ShowWindow(0)
    end
    local total_shop_button = ui.GetFrame("minimized_total_shop_button") -- マーケットとかのボタン
    if total_shop_button and total_shop_button:IsVisible() == 1 then
        total_shop_button:ShowWindow(0)
    end
    local total_party_button = ui.GetFrame("minimized_total_party_button") -- パーティー募集ボタン
    if total_party_button and total_party_button:IsVisible() == 1 then
        total_party_button:ShowWindow(0)
    end
    local tpshop_button = ui.GetFrame("minimized_tp_button") -- TPショップボタン
    if tpshop_button and tpshop_button:IsVisible() == 1 then
        tpshop_button:ShowWindow(0)
    end
    local total_bord = ui.GetFrame("minimized_total_board_button") -- 掲示板
    if total_bord and total_bord:IsVisible() == 1 then
        total_bord:ShowWindow(0)
    end
    local guidequest = ui.GetFrame("minimized_guidequest_button") -- なんか冒険者ガイドのやつ
    if guidequest and guidequest:IsVisible() == 1 then
        guidequest:ShowWindow(0)
    end
    local menu = ui.GetFrame("minimized_fullscreen_navigation_menu_button") -- menu
    if menu and menu:IsVisible() == 1 then
        menu:ShowWindow(0)
    end
end
-- ボタン右クリックでサウンドオフ
--
-- ここは GAME_START_3SEC から毎回呼ばれる(マップ移動のたびに張り直す)。
-- 以前は minimap_outsidebutton / BGM_PLAYER の nil を見ておらず、片方でも無いと
-- ここで落ちて GAME_START_3SEC の**残り全部**(エフェクト設定の復元・ヴァカリネ通知・
-- チャンネル一覧など)が道連れになっていた。必ず nil を見てから触ること。
function Mini_addons_toggle_sound_set()
    local minimap_outsidebutton = ui.GetFrame("minimap_outsidebutton")
    if not minimap_outsidebutton then
        core_g.vlog("mini_addons: minimap_outsidebutton が無いので音量トグルを張らない")
        return
    end
    -- 直下に居なければ孫まで探す(クライアント側の階層が変わっても拾えるように)。
    local BGM_PLAYER = GET_CHILD(minimap_outsidebutton, "BGM_PLAYER") or
                           GET_CHILD_RECURSIVELY(minimap_outsidebutton, "BGM_PLAYER")
    if not BGM_PLAYER then
        core_g.vlog("mini_addons: minimap_outsidebutton に BGM_PLAYER が無いので音量トグルを張らない")
        return
    end
    AUTO_CAST(BGM_PLAYER)
    BGM_PLAYER:SetEventScript(ui.RBUTTONUP, "Mini_addons_SOUND_TOGGLE")
    local tooltip = g.lang == "Japanese" and "{@st59}BGMプレイヤー{nl}右クリック: Sound Play/Mute{/}" or
                        g.lang == "kr" and "{@st59}BGM 플레이어{nl}우클릭: 소리 켜기/끄기{/}" or
                        "{@st59}BGM Player{nl}Right-click: Sound Play/Mute{/}"
    BGM_PLAYER:SetTextTooltip(tooltip)
    -- 音量 API がクライアントに在るか。**トグルが無反応のときの一次切り分けはここ。**
    -- 張るところまでは成功していても、押した先で config.* が nil なら何も起きない。
    -- 毎マップ出すと流れるので、判定が変わったときだけ 1 行出す。
    local api = type(config) == "table" and
                    (type(config.GetTotalVolume) == "function" and type(config.SetTotalVolume) == "function")
    if g.sound_toggle_api ~= api and
        core_g.vlog("mini_addons: 音量トグルを設定 (config.GetTotalVolume/SetTotalVolume=%s)", tostring(api)) then
        g.sound_toggle_api = api
    end
end

-- 右クリックでミュート ⇔ 復帰。
--
-- **イベントスクリプトの中で落ちてもどこにも記録が残らない**(debug_log.txt に載るのは
-- メッセージハンドラだけ)ので、pcall で受けて vlog に出す。実際、利用者の設定ファイルに
-- volume キーが一度も書かれていなかった = ここが最後まで走ったことが無かった。
--
-- 以前の判定は `g.settings.volume == nil or volume ~= 0` で、**記憶が 0 のときに詰む**:
-- ゲーム側で音量 0 にしている状態で最初に押すと volume=0 を記憶してしまい、以後は
-- 「復帰」に回っても SetTotalVolume(0) を書くだけになって、二度と音が戻らなかった。
-- 記憶するのは 0 より大きい値だけにする。
function Mini_addons_SOUND_TOGGLE(frame, ctrl, str, num)
    local ok, err = pcall(function()
        if type(config) ~= "table" or type(config.GetTotalVolume) ~= "function" or
            type(config.SetTotalVolume) ~= "function" then
            error("config.GetTotalVolume/SetTotalVolume がこのクライアントに無い", 0)
        end
        local volume = tonumber(config.GetTotalVolume()) or 0
        core_g.vlog("mini_addons: 音量トグル 現在=%s 記憶=%s", tostring(volume), tostring(g.settings.volume))
        if volume > 0 then
            g.settings.volume = volume
            Mini_addons_save_settings()
            config.SetTotalVolume(0)
        else
            local restore = tonumber(g.settings.volume) or 0
            if restore <= 0 then
                -- 記憶が無い(ミュート状態で初めて押した)。ここで勝手な値を書くと
                -- 音量を上書きすることになるので、戻す先はゲームの設定で決めてもらう。
                core_g.vlog("mini_addons: 音量トグル 記憶が無いので復帰できない(先に音量を上げてから使う)")
                ui.SysMsg(g.lang == "Japanese" and
                              "{ol}{#FF6347}[MiniAddons]{/} 元の音量を記憶していません。ゲームの設定で音量を上げてから右クリックしてください" or
                              "{ol}{#FF6347}[MiniAddons]{/} No previous volume stored. Raise the volume in the game options first.")
                return
            end
            config.SetTotalVolume(restore)
        end
        core_g.vlog("mini_addons: 音量トグル後=%s", tostring(config.GetTotalVolume()))
    end)
    if not ok then
        core_g.log_error_once("mini_addons_sound_toggle", "MiniAddons 音量トグルでエラー: " .. tostring(err))
    end
end
-- オプションリロールの表を横に表示
function Mini_addons_OPEN_DLG_REROLL_ITEM()
    local reroll_item = ui.GetFrame("reroll_item")
    for i = 1, MAX_RANDOM_OPTION_COUNT do
        local op = GET_CHILD_RECURSIVELY(reroll_item, "op" .. i)
        if op then
            AUTO_CAST(op)
            DESTROY_CHILD_BYNAME(reroll_item, op:GetName())
        end
    end
    if g.settings.reroll_option == 0 then
        reroll_item:StopUpdateScript("Mini_addons_REROLL_ITEM_OPTION_LIST")
        return
    end
    if reroll_item and reroll_item:IsVisible() == 1 and g.settings.reroll_option == 1 then
        reroll_item:RunUpdateScript("Mini_addons_REROLL_ITEM_OPTION_LIST", 0.2)
    end
end

function Mini_addons_REROLL_ITEM_OPTION_LIST(reroll_frame)
    local reroll_item_option = ui.GetFrame("reroll_item_option")
    local reroll_frame = ui.GetFrame("reroll_item")
    if reroll_frame == nil or reroll_frame:IsVisible() ~= 1 then
        ui.CloseFrame("reroll_item_option")
        return 1
    end
    local slot = GET_CHILD_RECURSIVELY(reroll_frame, "slot")
    local inv_item = GET_SLOT_ITEM(slot)
    if inv_item == nil then
        for i = 1, MAX_RANDOM_OPTION_COUNT do
            local op = GET_CHILD_RECURSIVELY(reroll_frame, "op" .. i)
            if op then
                AUTO_CAST(op)
                DESTROY_CHILD_BYNAME(reroll_frame, op:GetName())
            end
        end
        ui.CloseFrame("reroll_item_option")
        return 1
    end
    if reroll_item_option:IsVisible() == 1 then
        return 1
    end
    local img_tbl = {
        ["ATK"] = "{img tooltip_attribute1}",
        ["DEF"] = "{img tooltip_attribute2}",
        ["UTIL_ARMOR"] = "{img tooltip_attribute3}",
        ["STAT"] = "{img tooltip_attribute4}",
        ["SPECIAL"] = "{img tooltip_attribute5}"
    }
    local item_obj = GetIES(inv_item:GetObject())
    local group = TryGetProp(item_obj, "GroupName", "None")
    for i = 1, MAX_RANDOM_OPTION_COUNT do
        local group_name = "RandomOptionGroup_" .. i
        local prop_name = "RandomOption_" .. i
        local prop_value = "RandomOptionValue_" .. i
        local min, max = 0, 0
        if group == "BELT" then
            min, max = shared_item_belt.get_option_value_range_equip(item_obj, item_obj[prop_name])
        elseif group == "SHOULDER" then
            min, max = shared_item_shoulder.get_option_value_range_equip(item_obj, item_obj[prop_name])
        elseif group == "Icor" then
            min, max = shared_item_goddess_icor.get_option_value_range_icor(item_obj, item_obj[prop_name])
        end
        reroll_frame:RemoveChild("op" .. i)
        local op = reroll_frame:CreateOrGetControl("richtext", "op" .. i, 60, i * 20 + 75, 20, 160)
        AUTO_CAST(op)
        local op_value = item_obj[prop_value]
        if op_value > max then
            op_value = "{/}{s16}{#9932CC}" .. GET_COMMAED_STRING(op_value)
        elseif op_value == max then
            op_value = "{/}{s16}{#98FB98}" .. GET_COMMAED_STRING(op_value)
        end
        if item_obj[group_name] ~= "SPECIAL" then
            op_value = GET_COMMAED_STRING(op_value) .. " {#98FB98}(" .. GET_COMMAED_STRING(max) .. ")" ..
                           "{@st43b}{s16}"
        else
            op_value = GET_COMMAED_STRING(op_value) .. "{@st43b}{s16}"
        end
        if item_obj[prop_name] ~= "None" then
            local op_text = img_tbl[item_obj[group_name]] .. "{@st43b}{s16}" .. " " .. op_value .. " " ..
                                ScpArgMsg(item_obj[prop_name])
            op:SetText(op_text)
        end
    end
    local cur_index = reroll_frame:GetUserValue("CURRENT_INDEX")
    if cur_index == "None" then
        cur_index = 1
    end
    if cur_index == nil or cur_index == "None" then
        return 1
    end
    local reroll_index = TryGetProp(item_obj, "RerollIndex", 0)
    if reroll_index <= 0 then
        reroll_index = tonumber(cur_index)
    end
    local candidate_option_list = nil
    local group_name = TryGetProp(item_obj, "GroupName", "None")
    if group_name == "BELT" then
        candidate_option_list = shared_item_belt.get_option_list_by_index(item_obj, reroll_index)
    elseif group_name == "SHOULDER" then
        candidate_option_list = shared_item_shoulder.get_option_list_by_index(item_obj, reroll_index)
    elseif group_name == "Icor" then
        candidate_option_list = shared_item_goddess_icor.get_random_option_list(item_obj, false)
    end
    if candidate_option_list == nil or #candidate_option_list == 0 then
        return 1
    end
    local max_random_option_count = 0
    if group_name == "BELT" then
        max_random_option_count = shared_item_belt.get_max_random_option_count(item_obj)
    elseif group_name == "SHOULDER" then
        max_random_option_count = shared_item_shoulder.get_max_random_option_count(item_obj)
    elseif group_name == "Icor" then
        max_random_option_count = shared_item_goddess_icor.get_max_option_count()
    end
    if max_random_option_count == nil then
        return 1
    end
    local optionGbox = GET_CHILD_RECURSIVELY(reroll_item_option, "optionGbox")
    optionGbox:RemoveAllChild()
    local op_count = 0
    local function _MAKE_PROPERTY_MIN_MAX_DESC(desc, min, max)
        return string.format(" %s " .. ScpArgMsg("PropUp") .. "%d" .. " ~ " .. ScpArgMsg("PropUp") .. "%d", desc,
            math.abs(min), math.abs(max))
    end
    for i = 1, #candidate_option_list do
        local prop_name = candidate_option_list[i]
        if group_name == "BELT" then
            if shared_item_belt.is_valid_reroll_option(item_obj, reroll_index, prop_name, max_random_option_count) ==
                true then
                op_count = op_count + 1
                local group_name = shared_item_belt.get_option_group_name(prop_name)
                local clmsg = GET_CLMSG_BY_OPTION_GROUP(group_name)
                local min, max = shared_item_belt.get_option_value_range_equip(item_obj, prop_name)
                local op_name = string.format("%s %s", ClMsg(clmsg), ScpArgMsg(prop_name))
                local info_str = _MAKE_PROPERTY_MIN_MAX_DESC(op_name, min, max)
                local option_ctrlset = optionGbox:CreateOrGetControlSet("eachproperty_in_reroll_item",
                    "PROPERTY_CSET_" .. op_count, 0, 0)
                option_ctrlset = AUTO_CAST(option_ctrlset)
                local pos_y = option_ctrlset:GetUserConfig("POS_Y")
                option_ctrlset:Move(0, (op_count - 1) * pos_y)
                local property_name = GET_CHILD_RECURSIVELY(option_ctrlset, "property_name", "ui::CRichText")
                property_name:SetEventScript(ui.LBUTTONUP, "None")
                property_name:SetText(info_str)
                local help_pic = GET_CHILD_RECURSIVELY(option_ctrlset, "help_pic")
                help_pic:ShowWindow(0)
            end
        elseif group_name == "SHOULDER" then
            if shared_item_shoulder.is_valid_reroll_option(item_obj, reroll_index, prop_name, max_random_option_count) ==
                true then
                op_count = op_count + 1
                local group_name = shared_item_shoulder.get_option_group_name(prop_name)
                local clmsg = GET_CLMSG_BY_OPTION_GROUP(group_name)
                local min, max = shared_item_shoulder.get_option_value_range_equip(item_obj, prop_name)
                local op_name = string.format("%s %s", ClMsg(clmsg), ScpArgMsg(prop_name))
                local info_str = _MAKE_PROPERTY_MIN_MAX_DESC(op_name, min, max)
                local option_ctrlset = optionGbox:CreateOrGetControlSet("eachproperty_in_reroll_item",
                    "PROPERTY_CSET_" .. op_count, 0, 0)
                option_ctrlset = AUTO_CAST(option_ctrlset)
                local pos_y = option_ctrlset:GetUserConfig("POS_Y")
                option_ctrlset:Move(0, (op_count - 1) * pos_y)
                local property_name = GET_CHILD_RECURSIVELY(option_ctrlset, "property_name", "ui::CRichText")
                property_name:SetEventScript(ui.LBUTTONUP, "None")
                property_name:SetText(info_str)
                local help_pic = GET_CHILD_RECURSIVELY(option_ctrlset, "help_pic")
                help_pic:ShowWindow(0)
            end
        elseif group_name == "Icor" then
            if shared_item_goddess_icor.is_valid_reroll_option(item_obj, reroll_index, prop_name) == true then
                op_count = op_count + 1
                local group_name = shared_item_goddess_icor.get_option_group_name(prop_name)
                local clmsg = GET_CLMSG_BY_OPTION_GROUP(group_name)
                local min, max = shared_item_goddess_icor.get_option_value_range_icor(item_obj, prop_name)
                local op_name = string.format("%s %s", ClMsg(clmsg), ScpArgMsg(prop_name))
                local info_str = _MAKE_PROPERTY_MIN_MAX_DESC(op_name, min, max)
                local option_ctrlset = optionGbox:CreateOrGetControlSet("eachproperty_in_reroll_item",
                    "PROPERTY_CSET_" .. op_count, 0, 0)
                option_ctrlset = AUTO_CAST(option_ctrlset)
                local pos_y = option_ctrlset:GetUserConfig("POS_Y")
                option_ctrlset:Move(0, (op_count - 1) * pos_y)
                local property_name = GET_CHILD_RECURSIVELY(option_ctrlset, "property_name", "ui::CRichText")
                property_name:SetEventScript(ui.LBUTTONUP, "None")
                property_name:SetText(info_str)
                local help_pic = GET_CHILD_RECURSIVELY(option_ctrlset, "help_pic")
                help_pic:ShowWindow(0)
            end
        end
    end
    reroll_item_option:Resize(500, 970)
    reroll_item_option:SetSkinName("None")
    local bg = GET_CHILD(reroll_item_option, "bg")
    bg:Resize(470, reroll_item_option:GetHeight())
    local optionGbox = GET_CHILD(reroll_item_option, "optionGbox")
    optionGbox:Resize(430, bg:GetHeight() - 100)
    reroll_item_option:ShowWindow(1)
    return 1
end
-- インベントリを改造
function Mini_addons_inventory_open_func(frame, msg)
    g.inven_tbl = g.inven_tbl or {}
    local inventory = ui.GetFrame("inventory")
    local tab = GET_CHILD_RECURSIVELY(inventory, "inventype_Tab")
    if not tab then
        return 1
    end
    local tab_index = tab:GetSelectItemIndex()
    if tab_index ~= 0 and tab_index ~= 3 and tab_index ~= 5 and tab_index ~= 1 and tab_index ~= 2 and tab_index ~= 4 and
        tab_index ~= 6 then
        return 1
    end
    local group = GET_CHILD_RECURSIVELY(inventory, "inventoryGbox", "ui::CGroupBox")
    if not group then
        return 1
    end
    local trees_to_process = {}
    if tab_index == 0 then
        for i = 1, #g_invenTypeStrList do
            local tab_name = g_invenTypeStrList[i]
            local tree_box = GET_CHILD_RECURSIVELY(group, "treeGbox_" .. tab_name, "ui::CGroupBox")
            if tree_box then
                local tree = GET_CHILD_RECURSIVELY(tree_box, "inventree_" .. tab_name, "ui::CTreeControl")
                if tree then
                    table.insert(trees_to_process, tree)
                end
            end
        end
    else
        local tab_name = g_invenTypeStrList[tab_index + 1]
        if tab_name then
            local tree_box = GET_CHILD_RECURSIVELY(group, "treeGbox_" .. tab_name, "ui::CGroupBox")
            if tree_box then
                local tree = GET_CHILD_RECURSIVELY(tree_box, "inventree_" .. tab_name, "ui::CTreeControl")
                if tree then
                    table.insert(trees_to_process, tree)
                end
            end
        end
    end
    for _, tree in ipairs(trees_to_process) do
        local recipe_ssets = {}
        for i = 0, tree:GetChildCount() - 1 do
            local child = tree:GetChildByIndex(i)
            if child and string.find(child:GetName(), "sset_Recipe", 1, true) then
                table.insert(recipe_ssets, child)
            end
        end
        for _, recipe_slot_set in ipairs(recipe_ssets) do
            local child_count = recipe_slot_set:GetChildCount()
            for i = 0, child_count - 1 do
                local slot = recipe_slot_set:GetChildByIndex(i)
                if slot then
                    AUTO_CAST(slot)
                    local icon = slot:GetIcon()
                    if icon then
                        local info = icon:GetInfo()
                        local iesid = info:GetIESID()
                        local inv_item = GET_ITEM_BY_GUID(iesid)
                        local inv_index = inv_item.invIndex
                        local unique_key = iesid .. "_" .. inv_index
                        if not g.inven_tbl[unique_key] or msg ~= "INV_ITEM_ADD" then
                            g.inven_tbl[unique_key] = true
                            if inv_item then
                                local item_obj = GetIES(inv_item:GetObject())
                                local item_cls = GetClassByType("Item", item_obj.ClassID)
                                if item_cls then
                                    local recipe_cls = GetClass("Recipe", item_cls.ClassName)
                                    if recipe_cls then
                                        local target_item_cls = GetClass("Item", recipe_cls.TargetItem)
                                        if target_item_cls then
                                            local image = nil
                                            if g.settings.inventory_mod == 1 then
                                                local image = GET_ITEM_ICON_IMAGE(target_item_cls)
                                                local recipe_pic =
                                                    slot:CreateOrGetControl("picture", "recipe_pic" .. i, 0, 0, 25, 25)
                                                AUTO_CAST(recipe_pic)
                                                recipe_pic:SetEnableStretch(1)
                                                recipe_pic:SetGravity(ui.RIGHT, ui.TOP)
                                                recipe_pic:SetImage(image)
                                                SET_ITEM_TOOLTIP_TYPE(recipe_pic, target_item_cls.ClassID,
                                                    target_item_cls, "accountwarehouse")
                                            else
                                                local recipe_pic = GET_CHILD(slot, "recipe_pic" .. i)
                                                if recipe_pic then
                                                    DESTROY_CHILD_BYNAME(slot, "recipe_pic" .. i)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        local card_ssets = {}
        for i = 0, tree:GetChildCount() - 1 do
            local child = tree:GetChildByIndex(i)
            if child and string.find(child:GetName(), "^sset_Card") and not string.find(child:GetName(), "Summon") then
                table.insert(card_ssets, child)
            end
        end
        for _, card_slot_set in ipairs(card_ssets) do
            local child_count = card_slot_set:GetChildCount()
            for i = 0, child_count - 1 do
                local slot = card_slot_set:GetChildByIndex(i)
                if slot then
                    AUTO_CAST(slot)
                    local icon = slot:GetIcon()
                    if icon then
                        local info = icon:GetInfo()
                        local iesid = info:GetIESID()
                        local inv_item = GET_ITEM_BY_GUID(iesid)
                        local inv_index = inv_item.invIndex
                        local unique_key = iesid .. "_" .. inv_index
                        if not g.inven_tbl[unique_key] or msg ~= "INV_ITEM_ADD" then
                            g.inven_tbl[unique_key] = true
                            if inv_item then
                                local item_obj = GetIES(inv_item:GetObject())
                                local item_cls = GetClassByType("Item", item_obj.ClassID)
                                local image = nil
                                if g.settings.inventory_mod == 1 then
                                    image = TryGetProp(item_obj, "TooltipImage", "None")
                                else
                                    image = GET_ITEM_ICON_IMAGE(item_cls)
                                end
                                if item_cls then
                                    icon:Set(image, "Item", inv_item.type, inv_item.invIndex, inv_item:GetIESID(),
                                        inv_item.count)
                                end
                            end
                        end
                    end
                end
            end
        end
        local gem_skill_slotset = GET_CHILD_RECURSIVELY(tree, "sset_Gem_GemSkill", "ui::CSlotSet")
        if gem_skill_slotset then
            local child_count = gem_skill_slotset:GetChildCount()
            for i = 0, child_count - 1 do
                local slot = gem_skill_slotset:GetChildByIndex(i)
                if slot then
                    AUTO_CAST(slot)
                    local icon = slot:GetIcon()
                    if icon then
                        local info = icon:GetInfo()
                        local iesid = info:GetIESID()
                        local inv_item = GET_ITEM_BY_GUID(iesid)
                        local inv_index = inv_item.invIndex
                        local unique_key = iesid .. "_" .. inv_index
                        if not g.inven_tbl[unique_key] or msg ~= "INV_ITEM_ADD" then
                            g.inven_tbl[unique_key] = true
                            if inv_item then
                                local item_obj = GetIES(inv_item:GetObject())
                                local item_cls = GetClassByType("Item", item_obj.ClassID)
                                if item_cls then
                                    local cls_name = item_cls.ClassName
                                    local image = GET_ITEM_ICON_IMAGE(item_cls)
                                    if g.settings.inventory_mod == 1 then
                                        local skill_name = TryGetProp(item_cls, "SkillName", "None")
                                        local skill_cls = GetClass("Skill", skill_name)
                                        local skill_pic = slot:CreateOrGetControl("picture", "skill_pic" .. i, 0, 0, 35,
                                            35)
                                        AUTO_CAST(skill_pic)
                                        skill_pic:SetEnableStretch(1)
                                        skill_pic:SetGravity(ui.LEFT, ui.TOP)
                                        skill_pic:SetImage(image)
                                        SET_ITEM_TOOLTIP_TYPE(skill_pic, item_cls.ClassID, item_cls, "accountwarehouse")
                                        image = "icon_" .. GET_ITEM_ICON_IMAGE(skill_cls)
                                    else
                                        local trade = GET_CHILD(slot, "skill_pic" .. i)
                                        if trade then
                                            DESTROY_CHILD_BYNAME(slot, "skill_pic" .. i)
                                        end
                                    end
                                    if item_cls then
                                        icon:Set(image, "Item", inv_item.type, inv_item.invIndex, inv_item:GetIESID(),
                                            inv_item.count)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        local Gem_High_Color_slotset = GET_CHILD_RECURSIVELY(tree, "sset_Gem_High_Color", "ui::CSlotSet")
        if Gem_High_Color_slotset then
            local child_count = Gem_High_Color_slotset:GetChildCount()
            for i = 0, child_count - 1 do
                local slot = Gem_High_Color_slotset:GetChildByIndex(i)
                if slot then
                    AUTO_CAST(slot)
                    local icon = slot:GetIcon()
                    if icon then
                        local info = icon:GetInfo()
                        local iesid = info:GetIESID()
                        local inv_item = GET_ITEM_BY_GUID(iesid)
                        local inv_index = inv_item.invIndex
                        local unique_key = iesid .. "_" .. inv_index
                        if not g.inven_tbl[unique_key] or msg ~= "INV_ITEM_ADD" then
                            g.inven_tbl[unique_key] = true
                            if inv_item then
                                local item_obj = GetIES(inv_item:GetObject())
                                local item_cls = GetClassByType("Item", item_obj.ClassID)
                                if item_cls then
                                    if g.settings.inventory_mod == 1 then
                                        local cls_name = item_cls.ClassName
                                        if string.find(cls_name, 540) then
                                            slot:SetSkinName("invenslot_pic_goddess")
                                        elseif string.find(cls_name, 520) then
                                            slot:SetSkinName("invenslot_legend")
                                        elseif string.find(cls_name, 500) then
                                            slot:SetSkinName("invenslot_unique")
                                        elseif string.find(cls_name, 480) then
                                            slot:SetSkinName("invenslot_rare")
                                        else
                                            slot:SetSkinName("invenslot_nomal")
                                        end
                                    else
                                        slot:SetSkinName("invenslot_nomal")
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        local sset_Ancient_Card = GET_CHILD_RECURSIVELY(tree, "sset_Ancient_Card", "ui::CSlotSet")
        if sset_Ancient_Card then
            local child_count = sset_Ancient_Card:GetChildCount()
            for i = 0, child_count - 1 do
                local slot = sset_Ancient_Card:GetChildByIndex(i)
                if slot then
                    AUTO_CAST(slot)
                    local icon = slot:GetIcon()
                    if icon then
                        local info = icon:GetInfo()
                        local inv_item = GET_ITEM_BY_GUID(info:GetIESID())
                        if inv_item then
                            local item_obj = GetIES(inv_item:GetObject())
                            local item_cls = GetClassByType("Item", item_obj.ClassID)
                            local name = string.gsub(item_obj.ClassName, "Ancient_Card_", "Ancient_")
                            local mon_cls = GetClass("Monster", name)
                            local icon_name = TryGetProp(mon_cls, "Icon", "None")
                            if g.settings.inventory_mod == 1 then
                                local ancient_pic = slot:CreateOrGetControl("picture", "ancient_pic" .. i, 0, 0, 25, 25)
                                AUTO_CAST(ancient_pic)
                                ancient_pic:SetEnableStretch(1)
                                ancient_pic:SetGravity(ui.LEFT, ui.TOP)
                                ancient_pic:SetImage(icon_name)
                                SET_ITEM_TOOLTIP_TYPE(ancient_pic, item_cls.ClassID, item_cls, "accountwarehouse")
                            else
                                local trade = GET_CHILD(slot, "ancient_pic" .. i)
                                if trade then
                                    DESTROY_CHILD_BYNAME(slot, "ancient_pic" .. i)
                                end
                            end
                        end

                    end
                end
            end
        end
        local icor_slot_set = GET_CHILD_RECURSIVELY(tree, "sset_Icor", "ui::CSlotSet")
        if icor_slot_set then
            local child_count = icor_slot_set:GetChildCount()
            for i = 0, child_count - 1 do
                local slot = icor_slot_set:GetChildByIndex(i)
                if slot then
                    AUTO_CAST(slot)
                    local icon = slot:GetIcon()
                    if icon then
                        local info = icon:GetInfo()
                        local iesid = info:GetIESID()
                        local inv_item = GET_ITEM_BY_GUID(iesid)
                        local inv_index = inv_item.invIndex
                        local unique_key = iesid .. "_" .. inv_index
                        if not g.inven_tbl[unique_key] or msg ~= "INV_ITEM_ADD" then
                            g.inven_tbl[unique_key] = true
                            if inv_item then
                                local item_obj = GetIES(inv_item:GetObject())
                                local item_cls = GetClassByType("Item", item_obj.ClassID)
                                if item_cls then
                                    local cls_name = item_cls.ClassName
                                    if g.settings.inventory_mod == 1 then
                                        local is_special_item =
                                            string.find(cls_name, "EP17") or string.find(cls_name, "Weapon2") or
                                                string.find(cls_name, "Armor2")
                                        if not is_special_item then
                                            slot:SetSkinName("invenslot_rare")
                                        end
                                        local market_trade = TryGetProp(item_cls, "MarketTrade")
                                        if market_trade == "NO" then
                                            local trade = slot:CreateOrGetControl("richtext", "trade" .. i, 5, 40, 30,
                                                10)
                                            AUTO_CAST(trade)
                                            trade:SetText("{ol}{s10}NoTrade")
                                        end
                                    else
                                        local trade = GET_CHILD(slot, "trade" .. i)
                                        if trade then
                                            DESTROY_CHILD_BYNAME(slot, "trade" .. i)
                                        end
                                        slot:SetSkinName("invenslot_pic_goddess")
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        local armor_slot_set = GET_CHILD_RECURSIVELY(tree, "sset_Armor", "ui::CSlotSet")
        if armor_slot_set then
            local child_count = armor_slot_set:GetChildCount()
            for i = 0, child_count - 1 do
                local slot = armor_slot_set:GetChildByIndex(i)
                if slot then
                    AUTO_CAST(slot)
                    local icon = slot:GetIcon()
                    if icon then
                        local info = icon:GetInfo()
                        local iesid = info:GetIESID()
                        local inv_item = GET_ITEM_BY_GUID(iesid)
                        local inv_index = inv_item.invIndex
                        local unique_key = iesid .. "_" .. inv_index
                        if not g.inven_tbl[unique_key] or msg ~= "INV_ITEM_ADD" then
                            g.inven_tbl[unique_key] = true
                            if inv_item then
                                local item_obj = GetIES(inv_item:GetObject())
                                local item_cls = GetClassByType("Item", item_obj.ClassID)
                                if item_cls then
                                    if g.settings.inventory_mod == 1 then
                                        local cls_name = item_cls.ClassName
                                        local is_special_item =
                                            string.find(cls_name, "EP17") or
                                                (string.find(cls_name, "EP16") and string.find(cls_name, "high")) or
                                                (string.find(cls_name, "EP13") and string.find(cls_name, "high2"))
                                        if not is_special_item and
                                            (string.find(cls_name, "belt") or string.find(cls_name, "shoulder")) then
                                            slot:SetSkinName("invenslot_rare")
                                        end
                                    else
                                        slot:SetSkinName("invenslot_pic_goddess")
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    inventory:Invalidate()
    local try = inventory:GetUserIValue("TRY")
    if (msg == "INV_ITEM_REMOVE" or msg == "INV_ITEM_ADD") and try < 2 then
        try = try + 1
        inventory:SetUserValue("TRY", try)
        inventory:StopUpdateScript("Mini_addons_inventory_open_func")
        inventory:RunUpdateScript("Mini_addons_INVENTORY_OPEN_logic", 1.0)
        return 1
    elseif (msg == "INV_ITEM_REMOVE" or msg == "INV_ITEM_ADD") and try >= 2 then
        inventory:SetUserValue("TRY", 0)
        inventory:StopUpdateScript("Mini_addons_inventory_open_func")
        inventory:StopUpdateScript("Mini_addons_INVENTORY_OPEN_logic")

    elseif try >= 2 then
        inventory:SetUserValue("TRY", 0)
        return 0
    else
        try = try + 1
        inventory:SetUserValue("TRY", try)
        return 1 -- スクリプトを継続
    end
end

function Mini_addons_INVENTORY_OPEN_logic(frame)
    if frame:IsVisible() == 1 then
        frame:StopUpdateScript("Mini_addons_inventory_open_func")
        frame:RunUpdateScript("Mini_addons_inventory_open_func", 1.0)
    else
        frame:StopUpdateScript("Mini_addons_inventory_open_func")
    end
    return 0
end

function Mini_addons_INVENTORY_OPEN(my_frame, my_msg)
    local frame = g.get_event_args(my_msg)
    if not frame then
        return
    end
    local inventory = ui.GetFrame("inventory")
    if not inventory then
        return
    end
    if (os.clock() - (g.last_inventory_open_time or 0)) < 1.0 then
        return
    end
    g.last_inventory_open_time = os.clock()
    inventory:SetUserValue("TRY", 0)
    g.inven_tbl = {}
    local elapsed_time = os.clock() - (g.load_time or 0)
    if elapsed_time < 5.0 then
        local delay = 5.0 - elapsed_time
        local delay_str = tostring(delay)
        local truncated_str = string.sub(delay_str, 1, 3)
        local final_delay = tonumber(truncated_str)
        final_delay = math.max(final_delay, 0.1)
        inventory:RunUpdateScript("Mini_addons_INVENTORY_OPEN_logic", final_delay)
    else
        Mini_addons_INVENTORY_OPEN_logic(inventory)
    end
end
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
g.frame_suffixes = {"", "setting", "rank_frame", "buff_list", "event_frame", "reroll_option", "_q7quest", "_channel"}

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
