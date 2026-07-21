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
* **バージョン番号**は `nexus_addons_p/src/core/00_header.lua` の `ver` および
  `addons.json` の `fileVersion` と一致させる。

## リリースビルドの慣習

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

## ブランチ運用とリリース公開フロー

* **通常の開発**: 機能ごとに新規ブランチを切り、**`main` に直接マージ**する（PR 経由）。
* **配布リリース**: 公開したいタイミングで **`main` → `release` にマージ**する。
  * 版番号は 3 箇所（`00_header.lua` の `ver` / `addons.json` の `fileVersion` /
    `.ipf` のファイル名）に散っているので、**採番するときは 3 箇所を揃え、同時に `.ipf` も再ビルドする**。
    `main` は `.ipf` を毎回作り直さない運用なので、まとめて release 直前に行うのが既定。
    ただし PR 側で採番してしまっても、3 箇所 + `.ipf` が揃っていれば問題ない
    （更新履歴に「未リリース」のような仮の見出しを残さずに済む分、そちらが望ましい）。
    main→release の PR では [ci.yml](.github/workflows/ci.yml) の `ipf` ジョブが
    採番のタイミングによらずこれを検証して、**古い `.ipf` のまま公開するのを止める**。
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
* 手動で公開をやり直したいときは `gh workflow run release-nexus.yml --ref release`。

### ブランチルール（GitHub ruleset で機械的に強制している）

上の運用は口約束だと守れないので、`main` / `release` に ruleset を設定して GitHub 側で止めている。
定義は [.github/rulesets/](.github/rulesets/) に置いてあり、これが**適用済みの内容の写し**。
変更するときはファイルを直して `gh api repos/pinnkoro/TOSAddon/rulesets/<id> -X PUT --input <file>` で反映し、
GitHub 画面だけで直して写しを置き去りにしないこと。

| | `main` | `release` |
| --- | --- | --- |
| 直接 push | 不可（PR 必須・承認は 0 件でよい） | 不可（PR 必須） |
| 必須ステータス | `bundle` | `bundle` + `ipf` |
| マージ方法 | merge / squash | **merge のみ** |
| force push・ブランチ削除 | 禁止 | 禁止 |

* **承認レビューは 0 件必須**。ソロ開発で自分の PR を承認できないため、1 件以上にすると詰む。
  PR を通す手順そのものを残すのが目的で、レビュアーを増やすのが目的ではない。
* **`release` は merge のみ**。squash すると `release` が `main` と別履歴になり、以降のマージが
  毎回コンフリクトする。また merge 元 PR が辿れなくなると、リリースノートの流用（上記）も壊れる。
* **`ipf` を必須にするのは `release` だけ**。`main` では `ipf` ジョブがそもそも起動しないので、
  必須にすると永久に待ち状態になる（`ci.yml` 冒頭のコメントと同じ理由）。
* 移動タグ `nexus_addons_p` は tag ruleset を作っていないので、release ワークフローの
  「タグごと削除して作り直す」処理はそのまま通る。ここに tag ルールを足すと公開が壊れる。

## アドオンマネージャーへの登録（登録済み）

[MizukiBelhi/Addon-Manager](https://github.com/MizukiBelhi/Addon-Manager) は
`JTosAddon/Addons` の `managers.json` を 2 つ読む（`Source/AddonManager/MainWindow.xaml.cs`）。

* **JToS タブ** → `master` ブランチ ← **こちらが正**。本家 `ajinorisan/TOSAddon-public` も master に登録されている。
* IToS タブ → `itos` ブランチ（国際版向け。近年マージ実績が乏しい）

`{"repo": "pinnkoro/TOSAddon"}` を `sources` の**末尾に追記**する PR を master 宛に提出し、
2026-07-21 にマージされて**登録済み**: [JTosAddon/Addons#100](https://github.com/JTosAddon/Addons/pull/100)。

`file`（= `nexus_addons_p`）は一度登録したら変更してはいけない永続 ID。
