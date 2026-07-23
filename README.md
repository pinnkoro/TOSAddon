# TOSAddon (pinnkoro)

Tree of Savior 用アドオンの配布リポジトリ。

**[重要] 利用規約・免責事項**

* 本リポジトリで配布しているアドオンを使用したことにより生じるいかなる損害についても、理由の如何に関わらず作者は責任を負いません。
* アドオンのご利用は、**すべて自己責任**でお願いいたします。
* 個人が作成・配布しているものであり、所属組織とは一切関係ありません。
* 元アドオン(`author = "norisan"`)は改変・再配布自由という方針のもとで派生させています。元コードの作者様で問題がある場合はご連絡ください。

---

## 収録アドオン

| アドオン | 概要 | 説明 |
| --- | --- | --- |
| **Nexus Addons P** | 40種類以上のアドオンの詰合せ。norisan さんの [Nexus Addons](https://github.com/ajinorisan/TOSAddon-public) を元にした派生版 | **[nexus_addons_p/README.md](nexus_addons_p/README.md)** |

> ⚠️ **Nexus Addons P は本家 Nexus Addons と同時に使えません。**
> 本家がインストールされている間は Nexus Addons P 側が全機能を停止します。設定は初回起動時に自動で引き継がれます。
> 乗り換え手順は [nexus_addons_p/README.md](nexus_addons_p/README.md) を参照してください。

---

## インストール

アドオンマネージャー（[MizukiBelhi/Addon-Manager](https://github.com/MizukiBelhi/Addon-Manager)）から
インストールできます。

* **アドオンマネージャー登録済み**（[JTosAddon/Addons#100](https://github.com/JTosAddon/Addons/pull/100) マージ済み）

<details>
<summary>アドオンマネージャーへの登録の仕組み</summary>

[MizukiBelhi/Addon-Manager](https://github.com/MizukiBelhi/Addon-Manager#submitting-addons) の仕組みでは、
[JTosAddon/Addons](https://github.com/JTosAddon/Addons) の `managers.json` に
`{"repo": "pinnkoro/TOSAddon"}` を追加する PR を出すことで、このリポジトリの
[addons.json](addons.json) がアドオンマネージャーから参照されるようになる。

マネージャーは `managers.json` を 2 つ読む（`Source/AddonManager/MainWindow.xaml.cs`）。
本家 `ajinorisan/TOSAddon-public` と同じ **JToS タブ = `master` ブランチ**が宛先で、
`itos` ブランチは国際版タブ用。登録 PR: [JTosAddon/Addons#100](https://github.com/JTosAddon/Addons/pull/100)（マージ済み）

`file`（= `nexus_addons_p`）は一度登録したら**変更してはいけない**永続 ID。

</details>

---

## リポジトリ構成

| パス | 内容 |
| --- | --- |
| [nexus_addons_p/](nexus_addons_p/) | Nexus Addons P 本体（ソース・配布 `.ipf`）。説明は [README](nexus_addons_p/README.md) |
| [addons.json](addons.json) | アドオンマネージャー向けのメタデータ（配布バージョンはここが正） |
| [docs/](docs/) | ビルドスクリプトと開発ドキュメント |
| [.github/workflows/](.github/workflows/) | CI とリリース公開の自動化 |

---

## 開発

* `.ipf` のビルド手順: [docs/BUILD_IPF.md](docs/BUILD_IPF.md)
* ソース分割の設計: [docs/REFACTOR_SPLIT_DESIGN.md](docs/REFACTOR_SPLIT_DESIGN.md)
* source of truth は `nexus_addons_p/src/**`。配布 bundle（`_nexus_addons_p.lua` /
  `_nexus_addons_p_conclude.lua`）は生成物なので直接編集しない。

### CI

[.github/workflows/ci.yml](.github/workflows/ci.yml) が次を検証する。

| 検査 | 走るタイミング |
| --- | --- |
| bundle の再現性（golden sha 照合 / manifest 未登録 src の検出） | `main` / `release` |
| 連結後 bundle の Lua 構文チェック | `main` / `release` |
| core のロジック回帰テスト（[docs/tests/test_core.lua](docs/tests/test_core.lua)） | `main` / `release` |
| リリース前の先行採番の検出（[docs/check_version_freeze.py](docs/check_version_freeze.py)） | `main` への PR |
| `.ipf` が現 src から作られたものかの検証 + バージョンの三者一致 | `release` 経路 / `release-prep/**` |

最後の 1 つは、通常の `main` の PR では `.ipf` を作り直さない運用（採番はリリース時に
まとめて行う）のため、採番を行う経路でのみ効かせている。
手元では `python docs/verify_ipf.py` / `python docs/check_version_freeze.py` で同じ検査ができる。

### ブランチ運用とリリース公開フロー

* **通常の開発**: 機能ごとに新規ブランチを切り、PR 経由で `main` にマージする。
  **バージョンと `.ipf` はここでは触らない**（CI が変更を検出して落とす）。
* **配布リリース**: 採番 PR（`release-prep/vX.Y.Z` → `main`）と公開 PR（`main` → `release`）を
  続けて出す。
  * 採番（`00_header.lua` の `ver` / `addons.json` の `fileVersion` / `.ipf` のファイル名）と
    `.ipf` の再ビルドは、採番 PR でまとめて行う。
  * 先に `main` だけ採番すると、アドオンマネージャーが `main` の `fileVersion` から組み立てる
    アセット名（`nexus_addons_p-<fileVersion>.ipf`）が Release 側にまだ無く、公開までの間
    **利用者がインストールも更新もできなくなる**。そのため採番は公開直前に限っている。
  * `release` への push を [.github/workflows/release-nexus.yml](.github/workflows/release-nexus.yml) が検知し、
    移動タグ `nexus_addons_p` の GitHub Release を作り直して、`nexus_addons_p/` 直下の `.ipf` を
    `nexus_addons_p-<version>.ipf` として添付する（`<version>` は `addons.json` の `fileVersion`）。
  * **リリースノートは `main` → `release` のマージ元 PR の本文**がそのまま使われる。
* 手動で公開をやり直すときは `gh workflow run release-nexus.yml --ref release`。

---

## クレジット

* 元アドオン: [Nexus Addons](https://github.com/ajinorisan/TOSAddon-public) (norisan)
* 一部の修正の取り込み元: [yoma16/tos-addon](https://github.com/yoma16/tos-addon)
* 個別アドオンの原作者は、ゲーム内ヘルプおよび元リポジトリの記載を参照してください。
