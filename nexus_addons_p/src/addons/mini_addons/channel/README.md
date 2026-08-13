# チャンネル（channel）

> チャンネル切替フレームと、チャンネル表示のズレ修正

| 項目 | 内容 |
| --- | --- |
| 設定キー | `channel_info` / `channel_display` |
| ソース | [channel_frame.lua](channel_frame.lua) / [channel_traffic.lua](channel_traffic.lua) |
| 設定画面 | 「フレーム関連」セクション |

## ファイル

| ファイル | 設定キー | 内容 |
| --- | --- | --- |
| [channel_frame.lua](channel_frame.lua) | `channel_info` | チャンネル一覧のフレームを出す。今いるチャンネルの強調・混み具合の表示・クリックで移動・サイズ変更と位置の保存 |
| [channel_traffic.lua](channel_traffic.lua) | `channel_display` | 日本語版でチャンネル表示がズレるのを直す（`UPDATE_CURRENT_CHANNEL_TRAFFIC`） |

## 注意

* このフレームは**常時表示の HUD** なので、**ESC のスタックへ積まないこと**。積むと ESC を
  常に横取りしてシステムメニューが開けなくなります（CLAUDE.md「積んではいけないもの」）。
* レイドなど、チャンネルの概念がない場所では出しません（v1.3.7）。
