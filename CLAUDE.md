# CLAUDE.md — TOSAddon (Nexus Addons P) 作業ルール

## このリポジトリについて

norisan さんの [Nexus Addons](https://github.com/ajinorisan/TOSAddon-public) を元にした派生版
**Nexus Addons P** の配布リポジトリ。アドオン名・保存フォルダ・グローバル関数名はすべて
`_nexus_addons_p` 系にリネームしてあり、バージョンは本家と独立して採番する。

本家の修正を取り込みたい場合は、本家を upstream として追加してマージする:

```
git remote add upstream https://github.com/ajinorisan/TOSAddon-public.git
```

取り込み後は `nexus_addons_p/src/**` 側にリネームを反映すること
（`_nexus_addons` → `_nexus_addons_p`、`_NEXUS_ADDONS` → `_NEXUS_ADDONS_P`）。

本家は素のクライアント実装（`_client/jp/**`）も同梱している。**素の関数の挙動や戻り値を
推測しないこと**。`git show upstream/main:_client/jp/...` で実物を読めば確かめられる。

## 本家との共存対策（壊さないこと）

本家と同名のグローバル関数（`Always_status_*` / `Indun_panel_*` など）は**意図的にリネームしていない**。
そのため両方インストールされていると、後から読み込まれた側が先の側を上書きして壊す。これを次の 2 段構えで防いでいる。

* **読み込み時ガード** — `nexus_addons_p/src/guard_open.lua` / `guard_close.lua` が
  `addons/**` 全体を `if not g.detect_origin_addon() then ... end` で囲む。本家が先に読み込まれていれば
  アドオン本体を一切定義しない。build_manifest の連結順に依存しているので、順序を触るときは注意。
* **起動時ガード(A)** — `core/20_lifecycle.lua` の `_NEXUS_ADDONS_P_ON_INIT` / `_nexus_addons_p_GAME_START` が
  本家を検出したら全初期化をスキップし、削除を促すメッセージだけ出す。

**設定引き継ぎ(B)** は `core/00_header.lua` の `g.migrate_from_origin()`。
実行条件は「自分側に `settings.json` が無い」= 実質初回起動時のみ。
既に自分の設定があるときに走らせると本家の古い設定で上書きしてしまうので、この条件は必ず守ること。

### 例外: アドオンメニューボタン（`core/90_addons_menu.lua`）

このファイルは連結順で `guard_close.lua` の**後**＝読み込み時ガードの外にあり、本家が居ても定義される。
そのため同名グローバルだと確実にぶつかるので、ここだけは関数名を `addons_menu_*` に**リネームしてある**。
設定も `../addons/_nexus_addons_p/<AID>/addons_menu.json` に移し、旧 `../addons/norisan_menu/settings.json`
からは初回のみ引き継ぐ（条件は上の (B) と同じ「自分側に無いときだけ」）。

ただし次の 2 つは**リネームしてはいけない**。norisan さんの他アドオンが 1 つのメニューボタンに
相乗りするための待ち合わせ名で、変えると相手の項目が出なくなる／互いにフレームを壊し合う。

* `_G["norisan"]["MENU"]` … メニュー項目の共有登録先（`{name, func, icon}` を入れる）
* フレーム名 `"norisan_menu_frame"` … `core/20_lifecycle.lua` にも同名の分岐がある

### 設定画面の位置は `g.settings_frame_pos` で決める

各アドオンの設定画面は「アドオン一覧（`list_frame`）の右隣」に置く作りが多いが、
**Addons Menu のショートカットから開くと一覧は開いていない**。素で
`list_frame:GetX()` を呼ぶとそこで落ち、**窓は既に作った後なので中身が空の窓が出る**
（実機で Auto Repair / Boss Direction で発生。同じ書き方が 11 アドオンにあった）。

* 位置は `g.settings_frame_pos(width, height)`（[core/00_header.lua](nexus_addons_p/src/core/00_header.lua)）を使う。
  一覧が開いていればその右隣、開いていなければ画面中央へ置き、画面からはみ出さないよう丸める。
* **位置を読むためだけに一覧を開いて隠す、をしないこと。** `characters_item_serch` が
  そうしていたが、この「出ていない登録」が ESC のスタックに残り、後で一覧を開き直しても
  手前に来ない原因になる（ESC の節を参照）。

### Addons Menu へ並べる項目（ショートカット）

一覧の行の☆と設定画面の「ショートカット」タブで、**各アドオンの設定画面を Addons Menu へ
出せる**。集めているのは `addons_menu_collect_items`（[core/90_addons_menu.lua](nexus_addons_p/src/core/90_addons_menu.lua)）
1 箇所で、出どころは 3 つ（相乗り項目 / registry の `config_func` / 設定を開く歯車）。

* **`_G["norisan"]["MENU"] を書き換えないこと`**。アイコンの上書きは表示用の写しに対して行う。
  共有テーブルを直接いじると本家側のメニューの見た目まで変わる。
* **既定は出どころで違う**。相乗り項目は「出す」（既定を非表示にすると他アドオンの項目が
  黙って消える）、registry の設定画面は「出さない」。
* **`pairs` の順で並べない**。起動ごとに順番が変わる。相乗りはキー順、registry は登録順。
  利用者が▲▼で並べ替えた分は `menu_shortcuts` の `order`。**`order` を持たない項目は末尾へ回す**
  （相乗り項目は起動ごとに顔ぶれが変わるので、知らない項目が並びの真ん中へ割り込まないように）。
  `table.sort` は安定ではないので、元の位置を最後の決め手にすること。
  並べ替えは一覧全体へ番号を振り直す（隣と入れ替えるだけだと、番号を持たない項目が混ざったとき
  「押しても動かない」組み合わせが残る）。まとめ書きは `g.menu_shortcut_set(..., defer)` で
  溜めて、最後に 1 回だけ保存する。
* 設定の保存先は `settings.json` の `menu_shortcuts`（`g.menu_shortcut_*`）。
  **トップレベルなので `valid_keys` への追加が要る**（書き忘れると毎回プルーニングで消える）。
* 並べ方（向き・折り返す数）は `addons_menu.json`。**`addons_menu_save_json` は書き出すキーを
  列挙している**ので、設定を足したらそこと「デフォルトに戻す」（`def_setting`）の両方に書く。
  読むより先に保存する経路があると設定が消えるので、`addons_menu_create_frame` は
  `addons_menu_load_layout()` を保存より前に呼んでいる。
* アイコン選択（[core/91_icon_picker.lua](nexus_addons_p/src/core/91_icon_picker.lua)）の「検索」タブが引く
  画像名の表は **生成物**。[core/92_icon_names.lua](nexus_addons_p/src/core/92_icon_names.lua) を手で編集せず、
  `git fetch upstream` してから `python docs/gen_icon_names.py` で作り直すこと
  （素のクライアント `_client/jp/**` の `image="..."` / `SetImage("...")` / `{img ...}` から抜いている）。
  **Lua には画像名を列挙する手段が無い**ので、同梱する以外に「名前で探す」を実現する方法は無い。
* 収集の結果は [docs/tests/test_addons_menu.lua](docs/tests/test_addons_menu.lua) が検査する
  （並び順・既定・アイコンの上書きが共有テーブルを汚さないこと）。

## 不具合の話が出たら「誰の環境で起きたか」を最初に確認する

不具合の相談を受けたら、調べ始める前に**開発者本人の手元で再現したものか、
利用者からの報告か**を聞くこと。推測で決めてはいけない。ここを取り違えると、
調査の土台そのものが崩れる。

* **手元の環境のファイルは、他人の環境の事象の証拠にならない。**
  `../addons/_nexus_addons_p/**` の設定 JSON・`verbose_log.txt`・`debug_log.txt` は
  すべて**この PC の、このアカウントの**記録でしかない。他人の環境で起きた事象を
  これで「起きていない」と否定するのは誤り。
  * 実例: 「音量トグルが効かない」の調査で、手元の `mini_addons.json` に `volume` キーが
    無いことを根拠に「一度も実行されていない」と断定した。実際は別の利用者の報告で、
    手元は単にその機能を使っていなかっただけだった。
* **利用者からの報告のとき**は、手元で再現を試すより先に**コードから成立しうる経路を
  洗う**。「その状態になり得るか」を設定ファイルの実データではなくロジックで確かめること。
  そのうえで、必要なら `verbose_log.txt` を送ってもらう（そのためのログを普段から残す）。
* **手元で再現したとき**だけ、上記のファイルを一次資料として使ってよい。

## 修正したら詳細ログを出して、実機のログで確認する

このリポジトリのコードはゲームクライアント上でしか動かず、機械で検証できるのは
`docs/tests/` に置いた純ロジック（ゲーム API をスタブ化できる範囲）に限られる。
**直した箇所が実際に効いているかは、詳細ログを出して実機のログから確かめること**を推奨する。

* **出し方**: `g.vlog(fmt, ...)`（[core/00_header.lua](nexus_addons_p/src/core/00_header.lua)）を呼ぶ。
  設定画面（メニューボタン右クリック）の「詳細なログをシステムに出力する」が ON のときだけ、
  チャットのシステムメッセージと `../addons/_nexus_addons_p/verbose_log.txt` の両方に出る。
  既定は OFF なので、普通の利用者のチャットを埋める心配はしなくてよい。
  書式化の失敗は `pcall` で握るので、ログが本体を巻き込んで落とすこともない。
* **確認の手順**:
  1. 設定画面で「詳細なログをシステムに出力する」を ON にする
  2. 直した機能を実際に動かし、その修正の経路を通す（マップ移動・倉庫の開閉など）
  3. `../addons/_nexus_addons_p/verbose_log.txt` を読み、**期待した分岐を通っているか**と
     **期待しない失敗ログが出ていないか**を見る。このファイルはクライアント起動ごとに
     作り直されるので、中身は常に今回の起動分だけになる
     （エラー履歴を追記し続ける `debug_log.txt` とは別物。混ぜないこと）
* **何を出すか**: 「ここを通った」ではなく**判断の材料になった値**を出す。
  例: `g.get_map_type()` は取得できたマップ種別と、取得に失敗したマップ名を出している。
* **出しすぎない**: FPS_UPDATE 経由など毎フレーム走る経路をそのまま出すと、ログが流れて
  肝心の行が埋もれる。既存の実装が絞っている例:
  * `g.get_map_type()` の取得失敗ログは `g.map_type_failed_name` でマップごとに 1 回にする
  * init の成功ログは `_nexus_addons_p_vlog_init` が有効なアドオンだけに絞る
    （失敗は無効なアドオンでも知りたいので絞らない）
* **調査が終わっても消さない**: その修正の経路を後から追える最低限のログは残すこと。
  同じ不具合が再発したときと、利用者に `verbose_log.txt` をそのまま送ってもらう
  不具合報告のときに効く。

## `local function` は呼び出しより前で定義する

Lua の `local function f` は**宣言行より後ろからしか見えない**。前で呼ぶと同名の
グローバル（= nil）を呼ぶことになり、**構文チェックは通るのに、そのボタンを押した
瞬間だけ落ちる**。src を分割しているぶん前後関係が見えづらく、実際に踏んだ
（Addons Menu の設定画面で「レイヤー設定 / デフォルトに戻す / 上へ開く」が無反応になった）。

* 検出は [docs/check_forward_refs.py](docs/check_forward_refs.py)。**連結後の bundle に対して**行う
  （ファイル単位では前後関係が分からない）。CI の `bundle` ジョブでも走る。
* 直し方は「定義を呼び出しより前へ移す」か「ファイル先頭で `local <name>` と前方宣言する」。
* グローバル（`function _G.foo`）は実行時に引くので前後関係を気にしなくてよい。
  ただし読み込み時ガードの外から呼ぶものは `type(_G["foo"]) == "function"` で見てから呼ぶこと。

## 素の関数を書き写さない（置換方式フックは必ず素を呼ぶ）

置換方式フック（`g.setup_hook`）で**素の関数の中身を書き写して自分の処理を足すこと**は
してはいけない。今は素と同じ動きでも、IMC 側が素を変更したとき**設定の ON / OFF に
関わらず古い実装のまま**になる。エラーにならず静かに古い挙動になるので気付けない。

* 実際に `mini_addons` の 7 箇所がこの作りで、次の食い違いが溜まっていた（Issue #53）。
  素にある項目を**機能が OFF のときに消していた**のが 2 件、素の判定が落ちていたのが 2 件。
  * `POPUP_DUMMY` の「見比べる」／`CONTEXT_PARTY` の「詳細情報を見る」が、
    既定 OFF で消えていた
  * `SHOW_PC_CONTEXT_MENU` の幻影（`Illusion_Buff`）判定と、
    `POPUP_GUILD_MEMBER` の拡張ギルドアジト判定が落ちていた
* **素にある項目を「機能が ON のとき」だけ差し替えるのはよいが、OFF のときに消してはいけない。**

### コンテキストメニューへ項目を足すとき

`ui.CreateContextMenu` → `ui.OpenContextMenu` で完結するので、素を呼んだ後からでは足せない。
`mini_addons_menu_hook`（[context_menu.lua](nexus_addons_p/src/addons/mini_addons/context_menu/context_menu.lua)）を使う。
**素を呼び、その同期実行の間だけ `ui.AddContextMenuItem` / `ui.OpenContextMenu` を横取りして**、
メニューが開く前に項目を足す・落とす。

* 横取りは必ず元へ戻す（`pcall` が失敗した経路も含めて）。戻し忘れると全ての
  右クリックメニューを巻き込む。
* 素の戻り値はそのまま返すこと。`SHOW_PC_CONTEXT_MENU` は context を返し、
  呼び元の `_SHOW_PC_CONTEXT_MENU` が位置合わせに使っている。
* `ui.*` を差し替えられないクライアントに当たったら横取りを諦め、素をそのまま呼ぶ
  （追加項目は出ないが標準のメニューは壊れない）。可否は `verbose_log.txt` に 1 回だけ出す。

## ウィンドウを開いたら裏をクリックできないようにする

**自作ウィンドウを開くコードを書いたら、必ず `g.block_click_through(frame)` を呼ぶこと**
（[core/00_header.lua](nexus_addons_p/src/core/00_header.lua)。中身は `EnableHittestFrame(1)`）。

土台の `notice_on_pc.xml` は `<input ... hittestframe="false"/>` なので、**既定ではフレーム
自身の背景（コントロールが乗っていない余白）が当たり判定を持たない**。そこを押した入力は
下の 3D 画面へ抜け、窓の上を押したつもりでキャラクターが歩き出す・敵を選ぶ、という動きになる。
子のボタンやスロットは各自の `EnableHitTest` で受けるので、**余白を押したときだけ裏に通る**
という一番分かりにくい形で出る（実際に 44 アドオン中 26 個の窓がこの作りだった）。

* **`EnableMove` と相乗りさせないこと。** 「フレームを固定」は**動かさない**だけの設定で、
  当たり判定まで捨てる意味はない。`indun_panel` が `EnableHittestFrame(enable)` と
  `EnableMove(enable)` を同じ変数で切り替えており、**固定にした利用者だけ**展開表示
  （横 600px 以上）の上を押すと裏へ抜けていた。
* **呼んではいけないもの**（塞ぐと画面の一部が押せなくなる）
  * 常時表示の HUD（`always_status` / `muteki` / `monster_kill_count` のように、
    利用者の「固定」「ロック」設定で通す/通さないを切り替える作りのもの）
  * マーカー（`party_marker` / `boss_direction` の矢印）、ツールチップ
  * 大きさ 0 の入れ物フレーム（`mini_addons` の `RunUpdateScript` 用の土台など）
* 呼び忘れは [docs/check_frame_hittest.py](docs/check_frame_hittest.py) が落とす（CI の
  `bundle` ジョブでも走る）。上の「通したいもの」はスクリプトの `ALLOW` へ**理由付きで**
  足すこと。ALLOW に残骸（該当のフレーム生成が無いキー）が残っていても落ちる。

## ウィンドウを開いたら ESC で閉じられるようにする

**自作ウィンドウを開くコードを書いたら、必ず `g.esc_register` 系でスタックへ積むこと。**
土台に使っている `notice_on_pc`（`g.create_persistent_frame` も同じ）はゲーム側の ESC では
消えないので、積み忘れたウィンドウは**ESC が完全に無反応**になる。利用者から見ると
「閉じるものと閉じないものがある」という一番分かりにくい形で出る（実際に 44 アドオン中
4 つしか積んでいない時期があり、設定画面のほとんどが ESC で閉じなかった）。

* **まず × ボタンの中身を読むこと。** 選ぶ基準は土台ではなく**× が何をしているか**。
  * `g.esc_register(frame_name, close)` … × が破棄以外の後始末もしているとき。
    `close` はグローバル関数の**名前**（引数無しで呼べること）でも**関数そのもの**でもよい。
    閉じる処理がフレームを引数に取る作りなら、無名関数で包んで渡す
  * `g.esc_register_destroy(frame_name)` … × も `ui.DestroyFrame` だけのとき
  * `g.esc_register_hide(frame_name)` … × も破棄せず隠すとき（`CreateNewFrame` で
    作り直せない土台、参照を持ち回しているウィンドウ）
  * `g.esc_register_keep(frame_name, close)` … 下記「作り直す初期化関数から積むとき」
  * 実装は [core/00_header.lua](nexus_addons_p/src/core/00_header.lua)
* **ESC は × ボタンと同じ挙動にする。** × が保存やインベントリの右クリック割り当ての
  復帰までやっているなら、ESC からも同じ関数を通すこと。片方だけ後始末が抜けると、
  「× なら直るのに ESC だと壊れる」という追いにくい差になる。
  * 実例: `cc_helper` の × は `INVENTORY_SET_CUSTOM_RBTNDOWN` を状況に応じて戻している。
    ここを `esc_register_destroy` にすると、ESC で閉じた後もインベントリの右クリックが
    そのアドオンに割り当てられたまま残る（レビューで指摘されて直した）。
* **開いた直後に入力欄へ `Focus()` しないこと。** キーボードフォーカスが入力欄にあると、
  ESC の 1 回目はクライアント側の「入力欄から抜ける」処理に使われ、`ESCAPE_PRESSED` が
  **こちらへ届かない**（`verbose_log.txt` に行が 1 つも出ないので、押下が届いていないことは
  ログで確かめられる）。利用者から見ると「2 回押さないと閉じない」になる。横取りする手段は
  無いので、フォーカスを取らないことでしか直せない。
  * 実例: `easy_buff` の設定画面はプリセット 1 の名前欄へ `Focus()` していて、この形で出た。
  * 検索窓のように**入力が主目的の窓**だけは、利便性を取って残してよい（`tavern_of_soul`）。
    その場合 ESC が 2 回要ることは承知のうえで残すこと。
* **呼ぶのは `ShowWindow(1)` の後。** まだ出ていない状態で積むと、直後の同期で
  「閉じ終わった登録」と見なされてその場で捨てられる。
  * 「開いたら必ず通る」場所であることも確かめる。`ShowWindow(1)` の直後でも、
    そこを通らずに窓が出る経路があれば積み漏れる（`market_favorite_rebuild` の
    自動表示は `TOGGLE_FRAME("true")` の後に呼び元が `ShowWindow(1)` する）。
* **中身を作り直す初期化関数から積むときは `g.esc_register_keep`。**
  `esc_register` は「開き直し = 最前面」なので、**子の一覧を開いたまま親の設定画面を
  組み立て直す**作り（`battle_ritual` / `muteki` はスキルやバフを足すたびに設定画面の
  初期化関数を呼び直す）でこれを使うと、親が子より手前へ積み直され、ESC 1 回で
  親の close が走って子まで道連れになる。積むのは**窓そのものを開く関数**に置き、
  行やタブを作るような**繰り返し呼ばれる関数の中に入れないこと**。
* **積んではいけないもの**（積むと ESC を常に横取りしてシステムメニューが開けなくなる）
  * 常時表示の HUD（`indun_panel` / `always_status` / ボタン類、`_nexus_addons_p_update_frames`
    の `update_check_frames` に載っているフレームは毎フレーム復帰させるので特にだめ）
  * ツールチップ、マーカーなど利用者が「閉じる」と認識しないもの
  * **ゲーム側のウィンドウに貼り付いている付属パネル**（`bulk_sales` は shop、
    `ancient_auto_set` は ancient_card_list、`another_warehouse` の本体は accountwarehouse に
    連動して開閉する）。ここで ESC を横取りすると、本来閉じるべきゲーム側の窓が
    開いたまま残る。親のゲーム窓が閉じるときに一緒に畳まれる作りにしておくこと
* 判定と close の呼び出しは `_nexus_addons_p_ESCAPE_PRESSED`（[core/20_lifecycle.lua](nexus_addons_p/src/core/20_lifecycle.lua)）
  1 箇所に集約してある。**アドオン側で `ESCAPE_PRESSED` を個別に購読しないこと**
  （各自が自分のフレームを閉じると、1 回の ESC で開いている自作ウィンドウが全部消える）。

## 検索欄は 2 つの共通部品のどちらかを使う

**検索欄を作ったら、必ず次のどちらかを呼ぶこと**（[core/00_header.lua](nexus_addons_p/src/core/00_header.lua)）。
`ui.ENTERKEY` の割り当ての直後に置く。どちらを使っても、
**入力があるときだけ虫眼鏡ボタンの左隣に「×」が出る**（登録すれば自動で付くので、
アドオン側でボタンを作らないこと）。ENTERKEY と虫眼鏡ボタンはどちらの場合も残す。

| | `g.setup_incremental_search` | `g.setup_enter_search` |
| --- | --- | --- |
| 検索するきっかけ | **打鍵のたび**（+ Enter / 虫眼鏡） | **Enter / 虫眼鏡だけ** |
| 「×」を押したとき | 検索関数を**空文字で呼ぶ**（= 全件へ戻す） | 渡した**初期化関数**を呼ぶ（= 検索前の姿へ畳む） |
| 使う場面 | **既に手元にある一覧を絞る**検索 | **全件を走査して当たったぶんだけ作る**検索 |

### 選び方

判断の基準はひとつだけ。**空文字で検索関数を呼んだときに何が起きるか**を見る。

* **空文字 = 元の一覧が出るだけ**なら `g.setup_incremental_search`。
  絞り込みなので 1 文字ごとに走らせても作る量は増えず、消せば戻る。
* **空文字 = 全件に当たってしまう**なら `g.setup_enter_search`。
  `string.find(name, "", 1, true)` は必ず真なので、`GetClassList` の全件を回して
  一致したぶんだけコントロールを作る作りだと、**空でも 1 文字でも数千〜数万件を組み立てる**。
  打鍵検索も「×で空文字検索」も成立しないので、こちらを使う。
  * 実例: `tavern_of_soul` の `Tavern_of_soul_get_data`。件数の上限も無い。

### 使い方

```lua
-- (1) 一覧を絞る検索
search_edit:SetEventScript(ui.ENTERKEY, "Xxx_search")
search_edit:SetEventScriptArgNumber(ui.ENTERKEY, index)   -- 無ければ省略
g.setup_incremental_search(search_edit, "Xxx_search", index)
--   第 4 引数で打鍵から検索までの秒数を伸ばせる（既定 0.3 秒。`another_warehouse` は 0.5 秒）

-- (2) 全件を走査する検索
search_edit:SetEventScript(ui.ENTERKEY, "Xxx_search")
g.setup_enter_search(search_edit, "Xxx_clear")
--   Xxx_clear は **空文字で検索し直す処理ではなく**、検索前の姿へ戻す処理にすること
--   （入力を消す・結果を捨てる・窓の大きさを戻す）。呼び出しの並びは検索関数と同じ
```

### 共通の注意

* **検索欄の文字をコードから変えたら `g.search_clear_sync(edit)` を呼ぶこと。** 理由は 2 つある。
  1. 「×」の出し入れは打鍵でしか起きないので、呼ばないと空なのに「×」が残る／文字があるのに出ない
  2. 「前回この語で検索した」の記録を捨てる。打鍵検索は同じ語なら検索を飛ばすので、捨てないと
     **コードで空へ戻した後に利用者が同じ語を打ち直しても検索が走らない**
  タブ切り替えで空へ戻す `another_warehouse`、組み立て直しで入れ直す `separate_buff_custom`、
  一覧を作り直す `_nexus_addons_p_frame_init` がこれに当たる。
* **今と同じ文字列を `SetText` で入れ直さないこと。** 同じ文字列でも入力位置が戻るので、
  打っている最中にカーソルが飛び、日本語変換も壊れる。Lua では `""` も真なので
  `if ctrl_text then SetText(ctrl_text) end` は常に成立する点に注意
  （`separate_buff_custom` が実際にこの形で、打鍵のたびにカーソルが飛んでいた）。
* **一覧を畳む／初期化する処理に窓の位置戻しを混ぜないこと。** 「×」からも呼ばれるので、
  利用者が動かした窓が押すたびに初期位置へ飛ぶ（`tavern_of_soul` で実際にそうなっていた）。
* **「×」から `Focus()` を戻さないこと。** 入力欄にキーボードフォーカスがあると ESC の
  1 回目が「入力欄から抜ける」に使われ、窓が閉じなくなる（下記 ESC の節と同じ理由）。
  打鍵で空になった経路だけ `Focus()` を戻したいときは `g.search_typing_running` を見る
  （打鍵から検索関数を呼んでいる間だけ真）。**「打鍵以外を弾く」向きに書くこと。**
  検索関数には打鍵のほかに Enter・虫眼鏡ボタン・「×」から入ってくるので、
  「×から来たか」だけを見る書き方だと虫眼鏡ボタン経由を取りこぼす。
* **検索語は `ctrl:GetText()` ではなく検索欄を名前で引いて読むこと。** 同じ関数を虫眼鏡ボタンにも
  割り当てているので、`ctrl` がボタンのときは空文字を検索語にしてしまう
  （`another_warehouse` が実際にこの形で「押すと検索が解除される」不具合になっていた）。
* **一覧の作り直しで検索欄そのものを壊さないこと。** 検索欄は `if not frame` の中で 1 回だけ作り、
  検索のたびに作り直すのは中身の groupbox だけにする。検索欄ごと作り直すと、打鍵の途中で
  入力位置と文字が消えて打ち直しになる。やむを得ず作り直す経路（`characters_item_serch` は
  空に戻したとき `frame_init` を通る）では、作り直した検索欄へ `Focus()` を戻すこと。

### 素のクライアントはどうなっているか（調査済み・繰り返さないこと）

`_client/jp/addon.ipf/**/*.xml` の `<edit>` を全部数えた結果。**素は Enter 方式が多数派**で、
打鍵のたびに検索するのは一部だけ。「素がそうだから」を理由に一方へ寄せないこと。

* **打鍵のたびに検索（`typingscp` あり）… 9 個** — inventory / item_cabinet の `ItemSearch`、
  worldmap2_mainmap・worldmap2_submap の `search_edit`、guildinfo の `memberSearch`、
  housing_shop、bgmplayer、party_search_board、colony_tax_distribute
* **Enter だけ … 32 個** — adventure_book（8 個）/ quest / collection / friend / tpitem（5 個）/
  cheatlist / worldmap（旧）/ guild_dress_room / halloffame / status の名声検索 など

**素には「検索欄をクリアするボタン」が無い。**「×」はこちらで足したもので、素に倣ったものではない
（一般的な検索窓の作法に寄せている）。`market_reset*_btn` というリセット用のアイコンは在るが、
使われているのは一覧の再取得と `inventoryoption` のフィルタ条件のリセットで、検索文字列のクリアではない。

**虫眼鏡ボタンの意味は場所による。**

* inventory では、ボタン・Enter・打鍵が**同じ `SEARCH_ITEM_INVENTORY` を呼ぶ**。中で数えている
  `searchEnterCount`（同じ語で押した回数）は**クライアント全体のどこからも読まれていない**ので、
  現行では死んだコード＝ボタンは打鍵と同じことをするだけ。
* worldmap2 では**別物**。打鍵の `WORLDMAP2_SEARCH_UPDATE` は候補一覧を出すだけ、
  Enter の `WORLDMAP2_SEARCH` は最初に一致したマップへ実際に飛ぶ（3 文字以下は無視）。
  「絞り込み」と「決定」で役割が分かれている作りが要るときは、こちらを参考にする。

実物は次で読める。**同じ調査を繰り返さないこと。**

```
git show upstream/main:_client/jp/addon.ipf/inventory/inventory.xml     # typingscp="SEARCH_ITEM_INVENTORY_KEY"
git show upstream/main:_client/jp/addon.ipf/inventory/inventory.lua     # CancelReserveScript / ReserveScript(0.3)
git show upstream/main:_client/jp/ui.ipf/uiscp/worldmap2_uiscp_search.lua
```

### 実装側のメモ

* グローバルの `ReserveScript(式文字列, 秒)` には**取り消しが無い**（素は `frame:CancelReserveScript`
  を使うが、フレーム側の予約は「フレームごとに関数名 1 つ」なので、同じフレームに検索欄が
  複数ある作り（`battle_ritual`）だと打ち消し合う）。そのため検索欄ごとに世代番号を持ち、
  最後の打鍵の分だけ実行して残りは捨てている。
* 打鍵から実行までの間に × ボタンで窓を閉じられることがあるので、**検索欄の参照を持ち回さず**
  フレーム名とコントロール名から引き直す。
* 「×」の位置決めは**作成時ではなく最初に表示するとき**に行う。虫眼鏡ボタン（`search_btn`）は
  どのアドオンでも検索欄より後に作られ、登録時点では幅を読めないため。

## CMD(コンソール窓)をなるべく出さない

`os.execute` は **GUI プロセスから呼ぶと必ず cmd.exe のコンソール窓を作る**。ゲーム画面が
一瞬点滅するので、利用者から見ると「アドオンが何か変なことをしている」ように見える。
`io.popen` も同じうえ、GUI アプリでは動作が不安定。

**新しくコードを書くときは、まず `os.execute` を使わずに済ませられないか検討すること。**

* **ファイルのコピーは `io` で 1 ファイルずつ行う**(`g.copy_file`)。`xcopy` は使わない。
  実例は [core/30_maintenance.lua](nexus_addons_p/src/core/30_maintenance.lua) のバックアップ/復元。
  本家からの引き継ぎ(`g.migrate_from_origin`)も、同じ `g.settings_file_names` /
  `g.copy_settings_files` を使う。
* 代わりに「何をコピーするか」を自前で持つ必要がある。**Lua にディレクトリ列挙が無く、
  列挙する唯一の手段が cmd だから**、ここを避けるとファイル名は自分で列挙するしかない。
  固定名は `g.backup_files` のように定数で持ち、追加漏れは
  [docs/tests/test_core.lua](docs/tests/test_core.lua) の検査で落とす。
* **フォルダ作成(`mkdir`)だけは代わりが無い**ので残る。ただし `g.create_folder` が
  マーカーファイルで空振りを防ぐので、窓が出るのは初回の 1 回だけ。
  フォルダを作る箇所は必ずここを通すこと。
  * `io.open` はフォルダを作らない（親が無ければ `No such file or directory` で失敗するだけ）。
  * **LuaFileSystem(`lfs`)はクライアントに入っていない**。実機で確認済み:
    `require('lfs')` は失敗し、`_G` にそれらしい名前は `CreateSlotFolderIcon` /
    `OpenUploadEmblemFolder`（どちらもギルドエンブレムの UI 関数）しか無い。
    **同じ調査を繰り返さないこと。**

現在 `os.execute` が残っているのは次の箇所。**減らせないか継続して検討する**。

| 箇所 | 用途 | 備考 |
| --- | --- | --- |
| `core/00_header.lua` `g.create_folder` | `mkdir` | 代替なし。マーカーで初回のみ |
| `addons/monster_kill_count` | `dir` でファイル列挙 | 可変名のファイルを列挙する唯一の手段 |

## コードレビューの指摘は日本語で書く

このリポジトリはコメント・コミットメッセージ・PR・README をすべて日本語で書いている。
**コードレビューの指摘も日本語で出すこと**。手元で `/code-review` を流すときも、
PR で自動的に走る [Claude Code Review](.github/workflows/claude-review.yml) でも同じ。

* 識別子・関数名・ファイルパス・ログやコードの引用は**原文のまま**でよい。
  訳すと検索できなくなるので、むしろ訳さないこと。
* 「なぜそれが問題か」「どう直すか」の説明を日本語で書く、という意味。
* CLAUDE.md 由来の指摘は、根拠にした箇所を引用して示すこと（既にそうなっている）。

## 画面の見た目を変えたらスクリーンショットの撮り直し Issue を作る

[nexus_addons_p/README.md](nexus_addons_p/README.md) は
[nexus_addons_p/images/](nexus_addons_p/images/) の画像で使い方を説明している。
**画像はゲームを起動しないと撮れず、Claude Code の側では撮れない。**
そのため、見た目を変える PR では**撮り直しを Issue に残す**こと。放っておくと、
README の説明と実際の画面が食い違ったまま配布されることになる（利用者が最初に見る場所）。

* **作るタイミング**: 見た目を変える PR と同じタイミング。PR 本文にも Issue 番号を書く。
  実機で確認できる人（＝リポジトリの持ち主）が後から撮って差し替えられるようにするのが目的。
* **Issue に書くこと**（これだけあれば後から撮れる）:
  * 撮り直す画像のファイル名（`images/04-addons-menu-settings.png` のように）
  * **何が変わったのか**（タブが増えた／行にボタンが増えた など）
  * **撮る手順**（どこを開くか、どの設定を ON にするか）
  * README のどの行から参照されているか（alt テキストも直す必要があるため）
* **alt テキストも一緒に直す**。画像の中身を説明した文になっているので、
  見た目が変われば文も古くなる。**alt の更新は Issue ではなく PR の中で行うこと**
  （こちらは画像が無くてもできる）。
* **見た目を変えていない PR では作らない**。ノイズにしかならない。
  「行が 1 つ増えた」程度でも画像に写るなら対象、内部実装だけなら対象外。

## PR を出すときは README の更新履歴を必ず更新する

アドオンのソースやリリースビルド（`.ipf`）を変更して PR を作成するときは、
**同じ PR の中に更新履歴への追記を必ず含める**こと。

* **追記場所**: [nexus_addons_p/README.md](nexus_addons_p/README.md) の
  `<summary>更新履歴 (Nexus Addons P)</summary>` ブロック内、
  既存エントリの**先頭**（最新版が一番上）。
  ※ ルートの README.md はリポジトリ全体の説明で、アドオンの更新履歴は置かない。
* **例外**: **利用者から見て何も変わらない変更**は追記しなくてよい
  （利用者向けの履歴なので、ノイズになる）。次のどちらかに当たるもの:
  * コメント / ドキュメントのみの変更
  * **配布物が変わらないリファクタ**。`python docs/bundle_from_src.py --check` が
    **golden sha を更新せずに通る**（= 連結後の bundle が従来とバイト一致）ことで示せるもの。
    ソースファイルの分割・移動がこれに当たる（実例: Issue #69 の mini_addons 分割）。
    **バイト一致を示せないなら例外にはならない**。「動作は変えていないつもり」は理由にならず、
    その場合は追記すること。
  * 例外で通すときは、**その判断と根拠を PR 本文に書く**こと（レビューが同じ指摘を
    繰り返さずに済む）。
* **書式**:
  ```
  * **v1.0.1**
    * ＜アドオン名＞: ＜変更内容の要約＞。
  ```
* **見出しの版番号は、まだ採番しない**。`main` へ入れる PR では版数を上げてはいけない
  （後述の「バージョン情報はリリース時にだけ上げる」）ので、追記先の見出しは
  `* **（次回リリース）**` とし、そこに項目を足していく。
  この見出しを実際の `vX.Y.Z` に確定させるのは、公開直前の `release-prep/vX.Y.Z` ブランチ。
  ※ 見出しが既に `（次回リリース）` で存在するなら、新しい見出しを作らずそこへ追記する。

## 更新のお知らせ（NEW / Update の印）

利用者が「いつの間にか機能が増えていた」に気付けるようにする仕掛け。出口は 2 つ。

* **NEW / Update の印** — アドオン一覧の行と、Mini Addons の設定行に付く
* **印のツールチップ** — 何が変わったか（`updated_note_jp` / `updated_note_en`）
* **新着の件数** — アドオン一覧と Mini Addons の設定の、カテゴリ見出しに出る

### 行の中身の新着は、行の印へ集約する

**Mini Addons は 1 行の裏に 80 以上の設定項目を抱えている。** 設定を 1 つ足しても
一覧の行の見た目は変わらないので、一覧しか見ていない人には増えたことが伝わらない。
そこで子の定義を `core_g.badge_children["mini_addons"]` へ預け、`g.badge_row(entry)` が
行の印へ集約する（ツールチップにはどの設定かを名前で並べる。件数だけでは 80 以上から
探すことになるため）。

* **預けるのは子を持つ側**（[settings/definitions.lua](nexus_addons_p/src/addons/mini_addons/settings/definitions.lua)）。
  core から子を見に行かないこと。あちらは conclude スコープの local で見えないし、
  本家が居るときは定義そのものが存在しない。
* **`core_g.badge_children = core_g.badge_children or {}` を必ず通すこと。**
  預ける処理はチャンクの読み込み中に走るので、入れ物が無いまま添字を引くと
  **そこで読み込みが止まり、後ろの定義がまるごと失われる**。

**更新内容の全文はゲーム内に持たない。** README の更新履歴が唯一の出どころで、
ゲーム内に写しを置くと必ず食い違う。かつては一覧に帯を出して全文の窓を開く作りにしたが、
README と同じ内容を長々と並べるだけになったので畳んだ（Issue #116 の経緯）。
**印は「どこが変わったか」を指すところまで**を受け持つ。

### 機能を足した / 直したら、定義に 1 行足す

* **追加したとき**: `since = g.VER_NEXT`（Mini Addons 側は `core_g.VER_NEXT`）
* **直したとき**: `updated = g.VER_NEXT` と `updated_note_jp` / `updated_note_en`

```lua
-- core/10_registry.lua（**data の中ではなくエントリ側**に書く。data はそのまま
-- settings.json へ写され、既定に無いキーはプルーニングで消えるため）
key = "another_warehouse",
category = "storage",
updated = g.VER_NEXT,
updated_note_jp = "アイテムを取り出した後に一覧が更新されないことがあったのを修正しました",
```

* **`since` は一度書いたら触らない。** 触ると「追加」と「改修」の区別が付かなくなる。
* **`updated` は上書きしていく。** 履歴は README の更新履歴が持つ。
* **`updated_note_jp` を省かない。** 全文の窓を畳んだので、**何が変わったかを伝える経路は
  このツールチップだけ**になった。省くと印が「何かが変わった」としか言わなくなる。
* **`g.VER_NEXT`（= `"next"`）を書くこと。** main へ入れる PR では版を上げない
  （下の「バージョン情報はリリース時にだけ上げる」）ので、ここに具体的な版を書くと
  先行採番になる。`next` はどの版よりも新しいものとして扱われるので、採番するまでは必ず印が出る。
* **古くなった `updated` は 2〜3 版で消す。** 残すと一覧が印だらけになって意味を失う
  （`since` は消さない。新しく入れた人にはずっと意味がある）。

### 既読の管理

判定は `g.badge_of(def)`（[core/00_header.lua](nexus_addons_p/src/core/00_header.lua)）1 箇所。
記録は `settings.json` のトップレベル 2 つで、**どちらも `valid_keys` への追加が要る**。

| キー | 意味 |
| --- | --- |
| `seen_ver` | 印を出す基準。「この版までは知っている」 |
| `list_opened_ver` | アドオン一覧を開いた版 |

* **一覧を開いた瞬間に `seen_ver` を進めないこと。** 印は「どこが新しいのか探す」ための
  ものなので、開いた瞬間に消えると**印が出る前に消える**ことになる。進めるのは**次の起動**で
  1 回だけ（`_nexus_addons_p_load_settings`）。つまり「一度開いたら、次の起動で消える」。
* **`seen_ver` が無いときは `0.0.0` 扱い**にする。既に使っている人が更新した直後は
  このキーが無いので、`ver` で埋めると「印を導入した版の新着が誰にも出ない」ことになる。
  `ver` を入れるのは**初回インストールのときだけ**。

### リリースのときにやること

`release-prep/vX.Y.Z` で、README の `（次回リリース）` 見出しを `vX.Y.Z` に確定させるのと
**同じ PR で、`since` / `updated` の `g.VER_NEXT` を `"X.Y.Z"` に置き換える**。
置き換え忘れは `python docs/verify_ipf.py` が落とす（CI では `ipf` ジョブ）。
**忘れると NEW / Update の印が永久に消えない**（`next` はどの版よりも新しいため）。

## リリースビルドの慣習

* **`.ipf` の再ビルドと採番は公開直前（`release-prep/vX.Y.Z`）にまとめて行う。**
  通常の `main` 向け PR では `src` の変更と bundle の再生成までにとどめ、
  `.ipf` もバージョンも触らない（後述の「バージョン情報はリリース時にだけ上げる」）。
* 最新版を `nexus_addons_p/_nexus_addons_p-⛄-vX.Y.Z.ipf`（⛄ = U+26C4）に置き、旧版は `nexus_addons_p/_old/` へ移動する。
* `addons.json` の `fileVersion` も更新する。
* ビルド手順は [docs/BUILD_IPF.md](docs/BUILD_IPF.md) を参照。ソースを変更したら
  `python docs/bundle_from_src.py --bless` で golden sha を更新してから bundle を再生成する。
* Lua の構文チェックは WSL の luajit で行える:
  `luajit -e "assert(loadfile('.../_nexus_addons_p.lua'))"`
* ビルドしたら `python docs/verify_ipf.py` で「`.ipf` の中身が現 src と一致するか」と
  「バージョンの三者一致（`ver` / `fileVersion` / `.ipf` ファイル名）」を確認する。
  復号は不要（`.ipf` のファイルテーブルは平文で、平文 CRC32 を持っているため）。
  このチェックは release 経路の CI でも自動実行される。

## バージョン情報はリリース時にだけ上げる（先行採番の禁止）

**機能追加や不具合修正の PR で版数を上げてはいけない。** 採番は公開の直前だけ。

アドオンマネージャーは **`main` の `addons.json`** を読み、その `fileVersion` から
アセット名 `nexus_addons_p-<fileVersion>.ipf` を組み立てて Release から取得する。
一方 Release のアセットが差し替わるのは `main` → `release` をマージした後。
よって `main` だけ先に採番すると、公開までの間ずっと

```
main の addons.json : v1.0.3  →  取りに行く  nexus_addons_p-v1.0.3.ipf
配布中の Release    : v1.0.2  →  そんなアセットは無い（取得失敗）
```

となり、**その間は利用者が新規インストールも更新もできなくなる**（実際に発生した）。
「3 箇所が揃っていれば先に採番してもよい」は、この経路を見落としていたので撤回。

* 機械的な担保として、`main` への PR では [ci.yml](.github/workflows/ci.yml) の
  `version-freeze` ジョブ（[docs/check_version_freeze.py](docs/check_version_freeze.py)）が
  版数 3 箇所と `.ipf` のファイル名の変更を検出して落とす。手元でも
  `python docs/check_version_freeze.py` で同じ判定ができる。
* 比較の基準は base の先端ではなく **merge-base**。採番後の `main` を取り込んだだけの
  ブランチを誤検出しないため。
* **例外は `release-prep/**` ブランチだけ**。ここでのみ採番を許し、3 箇所が揃っているか、
  `.ipf` が現 `src` から作られているかまで併せて検査する（`ipf` ジョブも走る）。

## ブランチ運用とリリース公開フロー

* **通常の開発**: 機能ごとに新規ブランチを切り、**`main` に直接マージ**する（PR 経由）。
  バージョンと `.ipf` は触らない。更新履歴は `（次回リリース）` 見出しに足す。
* **配布リリース**: 次の 2 本の PR を**続けて**出す。間が空くほど、上に書いた不整合の窓が広がる。
  1. **採番 PR**: `release-prep/vX.Y.Z` → **`main`**。ここで
     版番号 3 箇所（`00_header.lua` の `ver` / `addons.json` の `fileVersion` /
     `.ipf` のファイル名）を揃え、`.ipf` を再ビルドし、旧版を `_old/` へ移し、
     README の `（次回リリース）` 見出しを `vX.Y.Z` に確定させる。
     **あわせて `since` / `updated` の `g.VER_NEXT` を実際の版へ置き換える**
     （上の「更新のお知らせ」）。
     このブランチでは `ipf` ジョブも走るので、**古い `.ipf` のまま採番するのを止められる**。
  2. **公開 PR**: `main` → **`release`**（下記テンプレート必須）。マージで公開される。
  * main→release の PR でも `ipf` ジョブが再度検証して、**古い `.ipf` のまま公開するのを止める**。
  * `release` への push を GitHub Actions（[.github/workflows/release-nexus.yml](.github/workflows/release-nexus.yml)）が
    検知し、移動タグ `nexus_addons_p` の GitHub Release を作り直して、`nexus_addons_p/` 直下の `.ipf` を
    `nexus_addons_p-<version>.ipf` として添付する（`<version>` は `addons.json` の `fileVersion`）。
  * **リリースノートは `main` → `release` のマージ元 PR の本文**がそのまま使われる。
    公開時は main→release の PR を作り、その説明にリリースノートを書くこと。
    テンプレートは [.github/PULL_REQUEST_TEMPLATE/](.github/PULL_REQUEST_TEMPLATE/) に置いてあるが、
    **ディレクトリ形式のテンプレートは自動適用されず、`?template=` を付けた URL からしか入らない**。
    素で PR を作ると本文が空のまま公開まで通ってしまうので、次の URL から作ること:
    * リリース (main→release): <https://github.com/pinnkoro/TOSAddon/compare/release...main?template=release.md&expand=1>
    * 通常の開発 (→main): `https://github.com/pinnkoro/TOSAddon/compare/main...<branch>?template=feature.md&expand=1`
    * `gh pr create --template <file>` でも同じテンプレートを使える。
* アドオンマネージャーは `addons.json` の `releaseTag`（= `nexus_addons_p`）の Release から `.ipf` を取得する。
  タグはバージョンごとに変えず、**同じ `nexus_addons_p` タグのアセットを毎回差し替える**（移動タグ運用）。
* **保存用に、版番号タグ（`v1.0.1` 形式 = `addons.json` の `fileVersion` そのまま）の Release も併せて作る**。
  移動タグの Release は毎回タグごと削除して作り直すため、前回のリリースノートと配布した `.ipf` が消える。
  それを残すのが目的で、アドオンマネージャーからは参照されない（`releaseTag` は移動タグ固定）。
  * Latest は移動タグ側に固定してある（保存用は `--latest=false`）。素で Releases を開いたときに
    配布中の版が出るようにするため。
  * **同じ版が Releases 一覧に 2 本並ぶのは正常**（配布中の版は移動タグと保存用の両方に載る）。
    見分けが付くよう、移動タグ側のタイトルだけ `Nexus Addons P vX.Y.Z — 配布用（最新）` にしてある。
    保存用は版番号のみ。**採番タイミングによらず最新版の固定リンクが常に存在する**のが、この方式の利点。
  * 同じ版のまま再実行すると、保存用 Release はノートとアセットが上書きされる（タグの位置は動かない）。
* 手動で公開をやり直したいときは `gh workflow run release-nexus.yml --ref release`。

### ブランチルール（GitHub ruleset で機械的に強制している）

上の運用は口約束だと守れないので、`main` / `release` に ruleset を設定して GitHub 側で止めている。
定義は [.github/rulesets/](.github/rulesets/) に置いてあり、これが**適用済みの内容の写し**。
変更するときはファイルを直して `gh api repos/pinnkoro/TOSAddon/rulesets/<id> -X PUT --input <file>` で反映し、
GitHub 画面だけで直して写しを置き去りにしないこと。

| | `main` | `release` |
| --- | --- | --- |
| 直接 push | 不可（PR 必須・承認は 0 件でよい） | 不可（PR 必須） |
| 必須ステータス | `bundle` + `version-freeze` | `bundle` + `ipf` |
| マージ方法 | merge / squash | **merge のみ** |
| force push・ブランチ削除 | 禁止 | 禁止 |

* **承認レビューは 0 件必須**。ソロ開発で自分の PR を承認できないため、1 件以上にすると詰む。
  PR を通す手順そのものを残すのが目的で、レビュアーを増やすのが目的ではない。
* **`release` は merge のみ**。squash すると `release` が `main` と別履歴になり、以降のマージが
  毎回コンフリクトする。また merge 元 PR が辿れなくなると、リリースノートの流用（上記）も壊れる。
* **`ipf` を必須にするのは `release` だけ**。通常の `main` の PR では `ipf` ジョブが
  そもそも起動しないので、必須にすると永久に待ち状態になる（`ci.yml` 冒頭のコメントと同じ理由）。
  `release-prep/**` の PR では起動するが、必須にできるのは「そのブランチだけ」ではなく
  `main` 全体なので、ここは ruleset ではなく運用（採番 PR は赤ければマージしない）で担保する。
* **`version-freeze` は job 単位の `if` を持たせない**。上と同じ理由で、条件付きで起動しない
  ジョブを必須にすると待ち続けてしまう。PR 以外で素通りさせる判定はステップ側の `if` で行い、
  ジョブは常に走って必ず報告する。
* **タグの ruleset は作っていない**。移動タグ `nexus_addons_p` の「タグごと削除して作り直す」処理と、
  保存用の版番号タグ（`v*`）の作成が、どちらも GITHUB_TOKEN のまま通る必要があるため。
  ここに tag ルールを足すと公開が壊れる。

## アドオンマネージャーへの登録（登録済み）

[MizukiBelhi/Addon-Manager](https://github.com/MizukiBelhi/Addon-Manager) は
`JTosAddon/Addons` の `managers.json` を 2 つ読む（`Source/AddonManager/MainWindow.xaml.cs`）。

* **JToS タブ** → `master` ブランチ ← **こちらが正**。本家 `ajinorisan/TOSAddon-public` も master に登録されている。
* IToS タブ → `itos` ブランチ（国際版向け。近年マージ実績が乏しい）

`{"repo": "pinnkoro/TOSAddon"}` を `sources` の**末尾に追記**する PR を master 宛に提出し、
2026-07-21 にマージされて**登録済み**: [JTosAddon/Addons#100](https://github.com/JTosAddon/Addons/pull/100)。

`file`（= `nexus_addons_p`）は一度登録したら変更してはいけない永続 ID。
