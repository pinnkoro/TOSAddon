# リリースとブランチ運用

更新履歴の追記・版番号の凍結・ブランチルール・公開フロー。ビルド手順そのものは [BUILD_IPF.md](BUILD_IPF.md)。入口は [CLAUDE.md](../CLAUDE.md)。

## 配布物は 1 本ではない

このリポジトリは `addons.json` のエントリぶんを**それぞれ独立に**配っている。

| `file`（永続 ID） | 置き場 | 移動タグ | アセット名 | 保存用タグ |
| --- | --- | --- | --- | --- |
| `nexus_addons_p` | [nexus_addons_p/](../nexus_addons_p/) | `nexus_addons_p` | `nexus_addons_p-vX.Y.Z.ipf` | `nexus_addons_p-vX.Y.Z` |
| `icor_planner` | [icor_planner/](../icor_planner/) | `icor_planner` | `icor_planner-vX.Y.Z.ipf` | `icor_planner-vX.Y.Z` |

* **タグ名・アセット名・`.ipf` のファイル名を手で組み立てない。** 正は
  [addon_targets.py](addon_targets.py)（`addons.json` から導く）。ワークフローも検証スクリプトも
  ここを通すので、名前の食い違いで 404 になる経路がそもそも無い。
* **保存用タグに `<file>-` を付けるのは衝突を避けるため。** 版番号だけ（`v1.0.0`）にすると
  2 本目のアドオンの初版とぶつかる。`v1.0.0`〜`v2.10.0` の既存タグは Nexus Addons P の
  過去の記録なので、そのまま残してある（今後の採番だけ新しい形になる）。
* **公開されるのは「版が変わったアドオン」だけ。** 判定は
  [plan_release.py](plan_release.py) が「移動タグの Release に付いているアセット名」と
  「`addons.json` の `fileVersion` から組み立てた名前」を比べて行う。
  手元でも `python docs/plan_release.py` で同じ判定を確かめられる。
  * こうしないと、片方だけ直した回でも**もう片方のリリースが作り直され**、
    リリースノートが無関係な内容に差し替わり、アドオンマネージャーが
    `commits/<移動タグ>.atom` から取る**更新日まで動く**（利用者には「更新された
    はずなのに中身が同じ」に見える）。
* **新しいアドオンを配り始めるときも `release-prep/**` で行う。** `addons.json` への
  エントリ追加だけを先に `main` へ入れると、Release がまだ無いのにマネージャーの一覧に
  並び、押した利用者が 404 を踏む（後述の先行採番と同じ事故）。

## PR を出すときは README の更新履歴を必ず更新する

アドオンのソースやリリースビルド（`.ipf`）を変更して PR を作成するときは、
**同じ PR の中に更新履歴への追記を必ず含める**こと。

* **追記場所**: **そのアドオンの README**（[nexus_addons_p/README.md](../nexus_addons_p/README.md) /
  [icor_planner/README.md](../icor_planner/README.md)）の更新履歴ブロック内、
  既存エントリの**先頭**（最新版が一番上）。
  ※ ルートの README.md はリポジトリ全体の説明で、アドオンの更新履歴は置かない。
  ※ 共通部品（[shared/src/](../shared/)）を直したときは、**影響したアドオンすべて**に書く。
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
  この見出しを実際の `vX.Y.Z` に確定させるのは、公開直前の `release-prep/**` ブランチ
  （ブランチ名は `release-prep/v2.11.0` / `release-prep/icor-planner-v1.0.0` のように、
  何を採番するか分かる名前にする。検査が見るのは `release-prep/` の接頭辞だけ）。
  ※ 見出しが既に `（次回リリース）` で存在するなら、新しい見出しを作らずそこへ追記する。

## リリースビルドの慣習

* **`.ipf` の再ビルドと採番は公開直前（`release-prep/**`）にまとめて行う。**
  通常の `main` 向け PR では `src` の変更と bundle の再生成までにとどめ、
  `.ipf` もバージョンも触らない（後述の「バージョン情報はリリース時にだけ上げる」）。
* 最新版を `<アドオン>/_<file>-⛄-vX.Y.Z.ipf`（⛄ = U+26C4）に置き、旧版は `<アドオン>/_old/` へ移動する
  （例: `icor_planner/_icor_planner-⛄-v1.0.0.ipf` / `icor_planner/_old/`）。
* `addons.json` の `fileVersion` も更新する。
* ビルド手順は [docs/BUILD_IPF.md](BUILD_IPF.md) を参照。ソースを変更したら
  `python docs/bundle_from_src.py --bless` で golden sha を更新してから bundle を再生成する。
* Lua の構文チェックは WSL の luajit で行える:
  `luajit -e "assert(loadfile('.../_nexus_addons_p.lua'))"`
* ビルドしたら `python docs/verify_ipf.py` で「`.ipf` の中身が現 src と一致するか」と
  「バージョンの三者一致（`ver` / `fileVersion` / `.ipf` ファイル名）」を確認する。
  **`addons.json` の全エントリが対象**で、1 本でも `.ipf` が欠けていれば落ちる
  （`--addon <file>` で 1 本だけに絞れる）。
  復号は不要（`.ipf` のファイルテーブルは平文で、平文 CRC32 を持っているため）。
  このチェックは release 経路の CI でも自動実行される。

## バージョン情報はリリース時にだけ上げる（先行採番の禁止）

**機能追加や不具合修正の PR で版数を上げてはいけない。** 採番は公開の直前だけ。

アドオンマネージャーは **`main` の `addons.json`** を読み、その `fileVersion` から
アセット名 `<file>-<fileVersion>.ipf` を組み立てて Release から取得する。
一方 Release のアセットが差し替わるのは `main` → `release` をマージした後。
よって `main` だけ先に採番すると、公開までの間ずっと

```
main の addons.json : v1.0.3  →  取りに行く  nexus_addons_p-v1.0.3.ipf
配布中の Release    : v1.0.2  →  そんなアセットは無い（取得失敗）
```

となり、**その間は利用者が新規インストールも更新もできなくなる**（実際に発生した）。
「3 箇所が揃っていれば先に採番してもよい」は、この経路を見落としていたので撤回。

* 機械的な担保として、`main` への PR では [ci.yml](../.github/workflows/ci.yml) の
  `version-freeze` ジョブ（[docs/check_version_freeze.py](check_version_freeze.py)）が
  版数 3 箇所と `.ipf` のファイル名の変更を、**`addons.json` の全エントリについて**
  検出して落とす（エントリの追加・削除そのものも変更として見る）。手元でも
  `python docs/check_version_freeze.py` で同じ判定ができる。
* `addons.json` の形そのもの（`releaseTag` / `unicode` / `fileVersion` の書式など、
  マネージャーが URL とファイル名に埋める値）は、毎回の PR で `bundle` ジョブの
  [docs/check_addons_json.py](check_addons_json.py) が見る。
* 比較の基準は base の先端ではなく **merge-base**。採番後の `main` を取り込んだだけの
  ブランチを誤検出しないため。
* **例外は `release-prep/**` ブランチだけ**。ここでのみ採番を許し、3 箇所が揃っているか、
  `.ipf` が現 `src` から作られているかまで併せて検査する（`ipf` ジョブも走る）。

## ブランチ運用とリリース公開フロー

* **通常の開発**: 機能ごとに新規ブランチを切り、**`main` に直接マージ**する（PR 経由）。
  バージョンと `.ipf` は触らない。更新履歴は `（次回リリース）` 見出しに足す。
* **配布リリース**: 次の 2 本の PR を**続けて**出す。間が空くほど、上に書いた不整合の窓が広がる。
  1. **採番 PR**: `release-prep/**` → **`main`**。**公開するアドオンについて**
     版番号 3 箇所（そのアドオンの `00_header.lua` の `ver` / `addons.json` の
     `fileVersion` / `.ipf` のファイル名）を揃え、`.ipf` を再ビルドし、旧版を `_old/` へ移し、
     README の `（次回リリース）` 見出しを `vX.Y.Z` に確定させる。
     **触らないアドオンの版数は据え置く**（据え置いたものは公開もされない）。
     **あわせて `since` / `updated` の `g.VER_NEXT` を実際の版へ置き換える**
     （上の「更新のお知らせ」）。
     このブランチでは `ipf` ジョブも走るので、**古い `.ipf` のまま採番するのを止められる**。
  2. **公開 PR**: `main` → **`release`**（下記テンプレート必須）。マージで公開される。
  * main→release の PR でも `ipf` ジョブが再度検証して、**古い `.ipf` のまま公開するのを止める**。
  * `release` への push を GitHub Actions（[.github/workflows/release.yml](../.github/workflows/release.yml)）が
    検知し、**版が変わったアドオンについて**移動タグの GitHub Release を作り直して、
    そのアドオンの直下の `.ipf` を `<file>-<version>.ipf` として添付する
    （`<version>` は `addons.json` の `fileVersion`）。何を公開するかの判定は
    `plan` ジョブ（[docs/plan_release.py](plan_release.py)）がログに出す。
  * **リリースノートは `main` → `release` のマージ元 PR の本文**がそのまま使われる。
    公開時は main→release の PR を作り、その説明にリリースノートを書くこと。
    テンプレートは [.github/PULL_REQUEST_TEMPLATE/](../.github/PULL_REQUEST_TEMPLATE/) に置いてあるが、
    **ディレクトリ形式のテンプレートは自動適用されず、`?template=` を付けた URL からしか入らない**。
    素で PR を作ると本文が空のまま公開まで通ってしまうので、次の URL から作ること:
    * リリース (main→release): <https://github.com/pinnkoro/TOSAddon/compare/release...main?template=release.md&expand=1>
    * 通常の開発 (→main): `https://github.com/pinnkoro/TOSAddon/compare/main...<branch>?template=feature.md&expand=1`
    * `gh pr create --template <file>` でも同じテンプレートを使える。
* アドオンマネージャーは `addons.json` の `releaseTag`（= `file`）の Release から `.ipf` を取得する。
  タグはバージョンごとに変えず、**同じ移動タグのアセットを毎回差し替える**（移動タグ運用）。
* **保存用に、`<file>-vX.Y.Z` タグの Release も併せて作る**。
  移動タグの Release は毎回タグごと削除して作り直すため、前回のリリースノートと配布した `.ipf` が消える。
  それを残すのが目的で、アドオンマネージャーからは参照されない（`releaseTag` は移動タグ固定）。
  * 保存用は必ず `--latest=false` で作る。**Latest は移動タグ（= 配布用）のどれか**になり、
    素で Releases を開いたときに配布中の版が出る。アドオンが複数あるので
    「どのアドオンが Latest か」は最後に公開したもの次第で、そこに意味は無い
    （マネージャーは `releaseTag` で引くので Latest を見ない）。
  * **同じ版が Releases 一覧に 2 本並ぶのは正常**（配布中の版は移動タグと保存用の両方に載る）。
    見分けが付くよう、移動タグ側のタイトルだけ `＜アドオン名＞ vX.Y.Z — 配布用（最新）` にしてある。
    保存用はアドオン名 + 版番号のみ。**採番タイミングによらず最新版の固定リンクが常に存在する**のが、この方式の利点。
  * 同じ版のまま再実行すると、保存用 Release はノートとアセットが上書きされる（タグの位置は動かない）。
* 手動で公開をやり直したいときは `gh workflow run release.yml --ref release`。
  **版が変わっていないアドオンは据え置かれる**ので、公開済みの版を作り直したいときは
  `-f addons=icor_planner`（カンマ区切り）で明示する。

### リリースノートに画像を載せる

見た目を変えた PR では、動作確認のときに撮った画像を `images/` に commit して同じ PR で差し替えている。
**リリースノートには撮り直さずにその画像を載せる。**

* 前回の版から変わった画像の一覧:
  `git diff --name-status <前回の版のタグ>..main -- 'nexus_addons_p/*images/*'`
  * **`**/images/*` と書かない。** git の pathspec では `**/` が空に縮まず、`nexus_addons_p/images/` 直下
    （Addons Menu の画像）だけが一覧から漏れる。`*images/*` なら直下も `src/addons/<key>/images/` も出る。
  * 他のアドオンも同じ形（`icor_planner/*images/*`）。前回の版のタグは、保存用タグの
    新しい形（`<file>-vX.Y.Z`）か、Nexus Addons P の v2.10.0 以前なら版番号だけのタグ。
* 書き方（項目の下へ 1 行。alt はその言語で書く。パスは一覧に出たものをそのまま）:
  `![＜何の画面か＞](https://raw.githubusercontent.com/pinnkoro/TOSAddon/<file>-vX.Y.Z/＜一覧に出たパス＞)`
* **URL の版は今回の保存用タグ（`<file>-vX.Y.Z`）にする。** 例:
  `.../TOSAddon/nexus_addons_p-v2.11.0/nexus_addons_p/images/menu.png`。
  **版番号だけのタグ（`v2.11.0`）はもう作られない**ので、そう書くと画像が全部 404 になる
  （v2.10.0 以前の Nexus Addons P の記録だけが版番号だけのタグ）。
  `main` を指すのも駄目で、後で同じファイル名で撮り直したときに
  **過去のリリースノートの画像まで新しい画面に差し替わる**。タグは公開と同時に作られるので、
  PR のプレビューでは表示されない（公開後に Release のページで確かめる）。
* **相対パスと、PR にドラッグで貼った画像（`github.com/user-attachments/...`）は使わない。**
  相対パスは Release のページで表示されず、Discord へも送れない。ドラッグで貼った画像は
  Discord が取りに行けるか保証が無い。
* 日本語セクションの画像は、Discord にも本文の後ろへ画像だけのメッセージで流れる（下記）。

### Discord への投稿

公開が済むと、同じワークフローが**リリースノートの日本語セクションだけ**を Discord のチャンネルへ
投稿する（[docs/post_release_discord.py](post_release_discord.py)）。送り先は、リポジトリの Secret
`DISCORD_WEBHOOK_URL` に登録したチャンネルの Webhook。
**投稿は公開したアドオンごとに 1 回**なので、2 本同時に公開した回は同じ本文が 2 通流れる
（リンク先だけがそれぞれの保存用 Release になる）。1 通で済ませたいなら、公開の回を分ける。

* 切り出すのは、先頭の `#` 1 つの見出し（タイトル）と、`## 🇯🇵` から最初の `---` まで。**テンプレートの見出しを
  変えると切り出せなくなる**（切り出せないときはジョブが赤くなる。配布は済んでいる）。
  * **`### 📥 導入方法` の節は Discord には流さない。** 毎回同じ文面でチャンネルでは情報にならないため。
    Release のページには残る（新しく入れる人はそちらから辿ってくる）。
* **自動で投稿されるのは、その版を初めて公開したときだけ**（保存用タグ `<file>-vX.Y.Z` の
  Release がまだ無いとき）。同じ版で公開をやり直しても、お知らせは重ねて流れない。
  * 送り直したい / 投稿だけ失敗したときは、手動実行で `discord` を ON にする:
    `gh workflow run release.yml --ref release -f addons=<file> -f discord=true`
    （ジョブの Re-run では投稿されない。その時点で保存用 Release があるため。
    `addons` を指定しないと、版が変わっていないアドオンは公開対象から外れて何も起きない）。
* Discord は 1 メッセージ 2000 文字まで。超えたら段落の区切りで複数に分けて送る。
* **本文の画像（`![alt](url)` / `<img>`）は Discord では文字のまま出てしまう**ので、本文からは抜き取り、
  本文を送り終えてから画像だけのメッセージ（1 通 10 枚まで）で送る。絶対 URL でない画像は警告を出して飛ばす。
* 公開前に文面を確かめるには、PR 本文をファイルに保存して
  `python docs/post_release_discord.py notes.md --dry-run`（送らずに分割結果を表示する）。
* 公開済みの版を手元から送り直すなら `python3 docs/post_release_discord.py --release v2.8.0`
  （本文とリンクを GitHub から取ってくる。`DISCORD_WEBHOOK_URL` を環境変数に入れ、WSL で実行する）。

### ブランチルール（GitHub ruleset で機械的に強制している）

上の運用は口約束だと守れないので、`main` / `release` に ruleset を設定して GitHub 側で止めている。
定義は [.github/rulesets/](../.github/rulesets/) に置いてあり、これが**適用済みの内容の写し**。
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
* **タグの ruleset は作っていない**。移動タグ（`nexus_addons_p` / `icor_planner`）の
  「タグごと削除して作り直す」処理と、保存用タグ（`<file>-vX.Y.Z`）の作成が、どちらも
  ワークフローの既定の権限のまま通る必要があるため。ここに tag ルールを足すと公開が壊れる。

## アドオンマネージャーへの登録（登録済み）

[MizukiBelhi/Addon-Manager](https://github.com/MizukiBelhi/Addon-Manager) は
`JTosAddon/Addons` の `managers.json` を 2 つ読む（`Source/AddonManager/MainWindow.xaml.cs`）。

* **JToS タブ** → `master` ブランチ ← **こちらが正**。本家 `ajinorisan/TOSAddon-public` も master に登録されている。
* IToS タブ → `itos` ブランチ（国際版向け。近年マージ実績が乏しい）

`{"repo": "pinnkoro/TOSAddon"}` を `sources` の**末尾に追記**する PR を master 宛に提出し、
2026-07-21 にマージされて**登録済み**: [JTosAddon/Addons#100](https://github.com/JTosAddon/Addons/pull/100)。

`file`（= `nexus_addons_p` / `icor_planner`）は一度登録したら変更してはいけない永続 ID。

### 1 リポジトリに複数のアドオンを並べてよい（実装で確認済み）

登録は**リポジトリ単位**で、マネージャーは `addons.json` を `List<AddonsObject>` として
読み、**エントリごとに 1 アドオンとして一覧へ並べる**（`TabManager.cs` の
`LoadRepo` → `foreach (AddonsObject addon in addons)`）。別リポジトリに分ける必要は無い。

マネージャーが `addons.json` の値から組み立てるもの（`DownloadManager.cs`）:

| 用途 | 組み立てる形 | このリポジトリでの例・注意 |
| --- | --- | --- |
| 一覧 | `https://raw.githubusercontent.com/{repo}/master/addons.json` | `master` は既定ブランチ（`main`）へ解決される |
| 更新日 | `https://github.com/{repo}/commits/{releaseTag}.atom` | **移動タグが git の ref として実在すること**が要る |
| 取得 | `.../releases/download/{releaseTag}/{file}-{fileVersion}.{extension}` | `.../download/icor_planner/icor_planner-v1.0.0.ipf` |
| 保存名 | `_{file}-{unicode}-{fileVersion}.{extension}` | `_icor_planner-⛄-v1.0.0.ipf` |
| 導入判定 | `data\*.ipf` を `_(.*)-(.*)-(v\d+.\d+.\d+.*).ipf` で解析 | `file` と `unicode` に `-` を入れないこと |

* README は `https://raw.githubusercontent.com/{repo}/master/{name の小文字}/README.md` を
  先に試し、取れなければリポジトリ直下の `README.md` を出す。`name` は表示名（`Icor Planner`）で
  フォルダ名（`icor_planner`）とは違うので、**マネージャー上ではルートの README が出る**。
  ルートの README に収録アドオンを並べてあるのはそのため。
* ここで挙げた形は [docs/check_addons_json.py](check_addons_json.py) が毎回の PR で検査する。
