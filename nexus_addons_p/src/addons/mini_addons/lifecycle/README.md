# 初期化と定期処理（lifecycle）

> 起動・マップ移動のたびに走る初期化と、フレームの更新スクリプト

| 項目 | 内容 |
| --- | --- |
| ソース | [init.lua](init.lua) / [update.lua](update.lua) |
| 設定画面 | なし（各機能の ON/OFF はここから配る） |

## ファイル

| ファイル | 内容 |
| --- | --- |
| [init.lua](init.lua) | `Mini_addons_ON_INIT` / `Mini_addons_GAME_START` / `Mini_addons_GAME_START_3SEC`。フックとイベントの登録は**ほぼ全てここに集まっている** |
| [update.lua](update.lua) | `Mini_addons_FPS_UPDATE`（毎フレーム）・`Mini_addons_make_menu`（アドオンメニューへの相乗り）・`Mini_addons_runupdate_5` |

## しくみ

* 機能の掛け外しは `GAME_START_3SEC` の一度きりで、**マップ移動のたびに張り直します**。
  ここで落ちると、その後ろの登録（エフェクト設定の復元・ヴァカリネ通知・チャンネル一覧など）が
  **丸ごと道連れ**になります。触る対象は必ず nil を見てから使うこと。
* フレームはマップ移動でクライアントが破棄し、作り直すのはまとめ版の init_addons（GAME_START の
  約 2 秒後）です。そのため素の `ui.GetFrame` ではなく `g.get_frame()`（無ければ作る）を使います。

## 注意

* **`Mini_addons_FPS_UPDATE` から `g.vlog` を呼ばないこと。** 毎フレーム走るので、ログが流れて
  肝心の行が埋もれます（CLAUDE.md「出しすぎない」）。
* メニューへの相乗り名 `_G["norisan"]["MENU"]` と `"norisan_menu_frame"` は**改名しないこと**。
  norisan さんの他アドオンとの待ち合わせ名です。
