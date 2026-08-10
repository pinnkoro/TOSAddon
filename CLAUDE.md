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

**取り込むときは併せて次を流すこと**（本家は素のクライアント実装 `_client/jp/**` を同梱しており、
`mini_addons` にはそれを書き写して差し替えている箇所が 6 つある。素が変わっても
エラーにならず静かに古い実装のままになるので、機械で見る）:

```
python docs/check_client_copies.py --against upstream/main
```

差分が出たら `mini_addons.lua` の該当ハンドラを新しい素の実装で書き直し（自分の追加分は残す）、
`--bless` を付けて控えを更新する。**控えだけ更新して本体を直さないこと**（アラームを消すだけになる）。
登録簿は [docs/client_copies.json](docs/client_copies.json)、控えは `docs/client_snapshots/`。
なお素にある項目を「機能が ON のとき」だけ差し替えるのはよいが、**OFF のときに消してはいけない**
（実際に既定 OFF で素の項目が消えていた箇所が 2 つあった）。

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

## PR を出すときは README の更新履歴を必ず更新する

アドオンのソースやリリースビルド（`.ipf`）を変更して PR を作成するときは、
**同じ PR の中に更新履歴への追記を必ず含める**こと。

* **追記場所**: [nexus_addons_p/README.md](nexus_addons_p/README.md) の
  `<summary>更新履歴 (Nexus Addons P)</summary>` ブロック内、
  既存エントリの**先頭**（最新版が一番上）。
  ※ ルートの README.md はリポジトリ全体の説明で、アドオンの更新履歴は置かない。
* **例外**: 挙動が変わらないコメントのみの変更は追記しなくてよい
  （利用者向けの履歴なので、ノイズになる）。
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
