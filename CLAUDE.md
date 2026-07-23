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
