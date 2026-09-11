---
paths:
  - "addons.json"
  - "nexus_addons_p/README.md"
  - "nexus_addons_p/*.ipf"
---

# 配布まわりのファイルを触るとき

* **版番号を上げるのは `release-prep/vX.Y.Z` ブランチだけ。**
  `main` だけ先に採番すると、アドオンマネージャーが `addons.json` の `fileVersion` から
  組み立てたアセット名が Release 側に存在せず、**公開までの間だれもインストールも更新も
  できなくなる**（実際に発生）。CI の `version-freeze` ジョブが検出して落とす。
  版番号は 3 箇所（`core/00_header.lua` の `ver` / `addons.json` の `fileVersion` /
  `.ipf` のファイル名）を同時に揃える。
* **PR には `nexus_addons_p/README.md` の更新履歴への追記を必ず含める。**
  追記先の見出しは `* **（次回リリース）**`（既にあればそこへ足す）。
  例外は「利用者から見て何も変わらない変更」だけで、その判断と根拠を PR 本文に書く。
* **`.ipf` の再ビルドも公開直前にまとめて行う。** 通常の `main` 向け PR では `src` の変更と
  bundle の再生成までにとどめる。
* **画面の見た目を変えたらスクリーンショット撮り直しの Issue を作る**
  （画像はゲームを起動しないと撮れない）。alt テキストは PR の中で直す。

手順の全文は **[docs/RELEASE.md](../../docs/RELEASE.md)** / **[docs/BUILD_IPF.md](../../docs/BUILD_IPF.md)**。
