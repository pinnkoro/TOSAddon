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

## PR を出すときは README の更新履歴を必ず更新する

アドオンのソースやリリースビルド（`.ipf`）を変更して PR を作成するときは、
**同じ PR の中に README.md の更新履歴への追記を必ず含める**こと。

* **追記場所**: README.md の `<summary>更新履歴 (Nexus Addons P)</summary>` ブロック内、
  既存エントリの**先頭**（最新版が一番上）。
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

## ブランチ運用とリリース公開フロー

* **通常の開発**: 機能ごとに新規ブランチを切り、**`main` に直接マージ**する（PR 経由）。
* **配布リリース**: 公開したいタイミングで **`main` → `release` にマージ**する。
  * `release` への push を GitHub Actions（[.github/workflows/release-nexus.yml](.github/workflows/release-nexus.yml)）が
    検知し、移動タグ `nexus_addons_p` の GitHub Release を作り直して、`nexus_addons_p/` 直下の `.ipf` を
    `nexus_addons_p-<version>.ipf` として添付する（`<version>` は `addons.json` の `fileVersion`）。
  * **リリースノートは `main` → `release` のマージ元 PR の本文**がそのまま使われる。
    公開時は main→release の PR を作り、その説明にリリースノートを書くこと。
* アドオンマネージャーは `addons.json` の `releaseTag`（= `nexus_addons_p`）の Release から `.ipf` を取得する。
  タグはバージョンごとに変えず、**同じ `nexus_addons_p` タグのアセットを毎回差し替える**（移動タグ運用）。
* 手動で公開をやり直したいときは `gh workflow run release-nexus.yml --ref release`。

## アドオンマネージャーへの登録（PR 提出済み・マージ待ち）

[MizukiBelhi/Addon-Manager](https://github.com/MizukiBelhi/Addon-Manager) は
`JTosAddon/Addons` の `managers.json` を 2 つ読む（`Source/AddonManager/MainWindow.xaml.cs`）。

* **JToS タブ** → `master` ブランチ ← **こちらが正**。本家 `ajinorisan/TOSAddon-public` も master に登録されている。
* IToS タブ → `itos` ブランチ（国際版向け。近年マージ実績が乏しい）

`{"repo": "pinnkoro/TOSAddon"}` を `sources` の**末尾に追記**する PR を master 宛に提出済み:
[JTosAddon/Addons#100](https://github.com/JTosAddon/Addons/pull/100)。マージされたら本節を「登録済み」に更新すること。

`file`（= `nexus_addons_p`）は一度登録したら変更してはいけない永続 ID。
