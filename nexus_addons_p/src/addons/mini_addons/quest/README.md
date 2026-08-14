# クエスト（quest）

> クエストリストの非表示・デイリークエストの別窓表示・トークンワープのクールダウン表示

| 項目 | 内容 |
| --- | --- |
| 設定キー | `quest_hide` / `daily_quest` |
| ソース | [quest.lua](quest.lua) / [token_warp.lua](token_warp.lua) |
| 設定画面 | 「フレーム関連」セクション |

## ファイル

| ファイル | 内容 |
| --- | --- |
| [quest.lua](quest.lua) | `ON_UPDATE_QUESTINFOSET_2` を差し替えてクエストリストを畳む（`quest_hide`）。お使いクエストを別窓に出す（`daily_quest`）。行き先マップの表示 |
| [token_warp.lua](token_warp.lua) | ワールドマップのトークンワープボタンに、残りクールダウンを `M:SS` で表示する |

## しくみ

* クエストリストの非表示は、インベントリを開いたときに出てしまう経路も塞いであります（v1.1.0）。
* トークンワープの表示は `worldmap2_minimap` に `RunUpdateScript` を 1.0 秒間隔で載せます。
  ワールドマップを開いている間だけ回ります。
