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

