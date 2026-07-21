# Nexus Addons P

Tree of Savior 用アドオン **Nexus Addons P** の配布リポジトリ。

norisan さんの [Nexus Addons](https://github.com/ajinorisan/TOSAddon-public) を元にした派生版です。
本家 v1.1.6 以降に加えた不具合修正・新レイド対応をまとめ、**別アドオンとして独立配布**します。

**[重要] 利用規約・免責事項**

* 本リポジトリで配布しているアドオンを使用したことにより生じるいかなる損害についても、理由の如何に関わらず作者は責任を負いません。
* アドオンのご利用は、**すべて自己責任**でお願いいたします。
* 個人が作成・配布しているものであり、所属組織とは一切関係ありません。
* 元アドオン(`author = "norisan"`)は改変・再配布自由という方針のもとで派生させています。元コードの作者様で問題がある場合はご連絡ください。

---

## ⚠️ 本家 Nexus Addons とは同時に使えません

Nexus Addons P は本家をリネームした派生版のため、**両方を同時にインストールすると競合します**。
そのため次の動作が入っています。

* **本家を検出したら、Nexus Addons P は全機能を停止します。**
  チャットに赤字で「本家を削除してください」と表示されるので、`data` フォルダから
  本家の `_nexus_addons-⛄-*.ipf` を削除して、クライアントを**再起動**してください。
  （この間、本家側は今までどおり動作します）
* **設定は自動で引き継がれます。**
  Nexus Addons P 側の設定がまだ無い状態で本家の設定が残っていれば、
  `addons/_nexus_addons/<アカウントID>/` の中身を `addons/_nexus_addons_p/<アカウントID>/` へ
  丸ごとコピーします（各アドオンの設定・Another Warehouse・討伐カウントなどを含む）。
  引き継ぎは**初回1回だけ**なので、本家を削除する前に一度ログインしておけば、
  そのままの設定で移行できます。

### 乗り換え手順

1. アドオンマネージャーから **Nexus Addons P** をインストールする（本家はまだ消さない）
2. ゲームを起動してログインする → 設定が引き継がれ、「本家を削除してください」と表示される
3. `data` フォルダから本家の `_nexus_addons-⛄-*.ipf` を削除する
4. クライアントを再起動する → 引き継いだ設定のまま Nexus Addons P が動作する

---

## アドオン紹介

### Nexus Addons P

40種類以上のアドオンの詰合せ。各機能の説明はゲーム内のヘルプ（`?` ボタン）を参照。

* **アドオンマネージャー登録申請中**（[JTosAddon/Addons#100](https://github.com/JTosAddon/Addons/pull/100)）

<details>
<summary>更新履歴 (Nexus Addons P)</summary>

* **v1.0.0**
  * 本家 Nexus Addons から独立した派生版として、`nexus_addons_p` の名前で配布を開始。
    アドオン名・保存フォルダ・グローバル関数名をすべて `_nexus_addons_p` 系にリネームし、
    バージョンは本家と独立して v1.0.0 から採番。
  * 本家と同時にインストールされている場合、Nexus Addons P 側の機能をすべて停止して
    本家を優先し、チャットで本家の削除を案内するようにした（本家側の動作は壊さない）。
  * 初回起動時、Nexus Addons P 側の設定が無く本家の設定が残っていれば自動で引き継ぐようにした。

  以下は本家 v1.1.6 以降に加えた変更（本家でいう v1.1.7〜v1.1.13）をまとめたもの。

  * Indun Panel / Indun List Viewer / Quickslot Operate: 新レイド「ズメイ」対応。
  * Indun Panel: ログイン時に採掘場(傭兵団)ショップを開いて PVP_MINE 購入可能数を同期していた処理を、
    **パネル展開時の遅延同期**に変更（セッション中1回・完了後に再描画）。これにより、機能を OFF にしていても・
    使っていても**ログイン時に一瞬ウィンドウが開いてインベントリが閉じる不具合**を解消。
    同期でインベントリが閉じた場合は自動復元。
  * Indun Panel: パネルをドラッグで移動しても、閉じる/展開/再ログインで**位置が初期位置に戻る不具合**を修正
    （位置保存ハンドラが「固定」側の分岐に付いていたのを「移動可」側に修正）。
  * Indun List Viewer: 掃討バフお知らせにズメイを追加。新規／旧設定移行ユーザーでレイドが表示されない不具合を修正。
  * Indun List Viewer: ハードモードを持たないレイド向けに nil ガードを追加（新ダンジョンでハードモード不在時のエラーを防止）。
  * Indun List Viewer: ハードモードのないレイド構成で「Hard」ラベルの位置がずれる不具合を修正。
  * Other Character Skill List: 都市入場毎にキャラが消える不具合を修正し、表示をバラック1/2/3ごとにグループ化
    （各バラック内はバラックの並び順どおり）。従来の system_option 基準ではなくバラック名簿基準で整理
    （yoma16版 new_nexus_addons v1.0.6 由来）。※順番の記録には各バラック(1,2,3)へ一度ずつログインが必要。
  * Other Character Skill List: 都市外から設定フレームを開いた際に開けない不具合を修正
    （データ遅延ロード＋描画を pcall で保護。yoma16版 v1.0.5 由来）。
  * Character Change Helper: 装備セットプリセット（3セット）を追加し、コピー/保存をセット単位に刷新
    （yoma16版 v1.0.3/v1.0.4 由来）。
  * Character Change Helper: セット構造が未初期化のキャラでセット切替/セット選択メニューがエラーになる不具合を修正。
    コピー設定の移行時にキー衝突でデータを失う不具合を修正。
  * Guild Event Warp: 画面右上のボタン（ドラグーン／アラクネ姉妹／バウバス）からボスマップへ移動できない不具合を修正
    （削除済みの内部関数呼び出しを、封鎖線ランキングの「移動」と同じ処理に置換）。
  * Guild Event Warp: ボスマップへのワープに移動可否チェックを追加（PVP／レイヤー変更／ダンジョン／レイド地域では不可）。
  * Guild Event Warp: 未知/インスタンスマップでワープ可否チェックがエラーになりワープ機能全体が止まる不具合を修正
    （マップ種別取得の nil ガード）。
  * Auto Repair: 修理キットのアイテム ID 修正（Lv.540→Lv.550）。キットが検出されず繰り返し購入する不具合を修正。
  * Another Warehouse: 設定変更が保存されない不具合を修正。
  * Aethergem Manager: `settings.set` の nil ガードを追加（yoma16版 v1.0.2 由来）。
  * 内部処理: 設定ファイルの保存/読み込みを堅牢化。書き込みをテンポラリファイル経由（tmp + rename）にして破損耐性を向上し、
    保存時の差し替え（rename）失敗を検知して成功と誤報しないよう修正。読み込み時は `.tmp` の内容をデコード成功後に
    差し替えるよう順序を修正し、壊れた一時ファイルを正規ファイルへ昇格させて設定を失う不具合を防止
    （差し替え処理を `atomic_replace` に共通化）。
  * 内部処理: ソースを機能ごとに `nexus_addons_p/src/**` へ分割し、`docs/bundle_from_src.py` で連結ビルドする方式に移行。

</details>

---

## アドオンマネージャーへの登録

[MizukiBelhi/Addon-Manager](https://github.com/MizukiBelhi/Addon-Manager#submitting-addons) の仕組みでは、
[JTosAddon/Addons](https://github.com/JTosAddon/Addons) の `managers.json` に
`{"repo": "pinnkoro/TOSAddon"}` を追加する PR を出すことで、このリポジトリの
[addons.json](addons.json) がアドオンマネージャーから参照されるようになる。

マネージャーは `managers.json` を 2 つ読む（`Source/AddonManager/MainWindow.xaml.cs`）。
本家 `ajinorisan/TOSAddon-public` と同じ **JToS タブ = `master` ブランチ**が宛先で、
`itos` ブランチは国際版タブ用。申請 PR: [JTosAddon/Addons#100](https://github.com/JTosAddon/Addons/pull/100)

`file`（= `nexus_addons_p`）は一度登録したら**変更してはいけない**永続 ID。

---

## 開発

* `.ipf` のビルド手順: [docs/BUILD_IPF.md](docs/BUILD_IPF.md)
* ソース分割の設計: [docs/REFACTOR_SPLIT_DESIGN.md](docs/REFACTOR_SPLIT_DESIGN.md)
* source of truth は `nexus_addons_p/src/**`。配布 bundle（`_nexus_addons_p.lua` /
  `_nexus_addons_p_conclude.lua`）は生成物なので直接編集しない。

### ブランチ運用とリリース公開フロー

* **通常の開発**: 機能ごとに新規ブランチを切り、PR 経由で `main` にマージする。
* **配布リリース**: 公開したいタイミングで `main` → `release` にマージする。
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
