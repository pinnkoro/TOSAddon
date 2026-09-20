---
paths:
  - "addons.json"
  - "nexus_addons_p/README.md"
  - "nexus_addons_p/*.ipf"
  - "icor_planner/README.md"
  - "icor_planner/*.ipf"
---

# 配布まわりのファイルを触るとき

* **配布物は 1 本ではない。** `addons.json` のエントリぶん（Nexus Addons P / Icor Planner）を
  それぞれ独立に配っている。検査スクリプトが見る対象の一覧は
  [docs/addon_targets.py](../../docs/addon_targets.py) が `addons.json` から導く。
* **版番号を上げるのは `release-prep/**` ブランチだけ。**
  `main` だけ先に採番すると、アドオンマネージャーが `addons.json` の `fileVersion` から
  組み立てたアセット名が Release 側に存在せず、**公開までの間だれもインストールも更新も
  できなくなる**（実際に発生）。CI の `version-freeze` ジョブが検出して落とす。
  版番号は 3 箇所（そのアドオンの `00_header.lua` の `ver` / `addons.json` の `fileVersion` /
  `.ipf` のファイル名）を同時に揃える。
  **`addons.json` へのエントリの追加（新しいアドオンの初公開）も同じ扱い**
  （Release がまだ無いのに一覧へ並ぶため）。
* **PR にはそのアドオンの README の更新履歴への追記を必ず含める。**
  追記先の見出しは `* **（次回リリース）**`（既にあればそこへ足す）。
  例外は「利用者から見て何も変わらない変更」だけで、その判断と根拠を PR 本文に書く。
* **`.ipf` の再ビルドも公開直前にまとめて行う。** 通常の `main` 向け PR では `src` の変更と
  bundle の再生成までにとどめる。
* **画面の見た目を変えたら、動作確認のときにスクリーンショットも撮ってもらい、同じ PR で差し替える**
  （画像はゲームを起動しないと撮れない）。alt テキストも PR の中で直す。
  その PR の中で撮れないときだけ Issue にする（CLAUDE.md「画面の見た目を変えたら」）。

手順の全文は **[docs/RELEASE.md](../../docs/RELEASE.md)** / **[docs/BUILD_IPF.md](../../docs/BUILD_IPF.md)**。
