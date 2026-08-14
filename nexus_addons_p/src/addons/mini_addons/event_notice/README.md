# お知らせ（event_notice）

> イベントのグローバルシャウト・バウバス登場・追加報酬券などのお知らせ

| 項目 | 内容 |
| --- | --- |
| 設定キー | `event_shout` / `baubas_call` / `multiple_item` / `chat_system` |
| ソース | [reward_token.lua](reward_token.lua) / [notice_msg.lua](notice_msg.lua) / [event_shout.lua](event_shout.lua) |
| 設定画面 | 「チャット関連」「その他」セクション |

## ファイル

| ファイル | 設定キー | 内容 |
| --- | --- | --- |
| [reward_token.lua](reward_token.lua) | `multiple_item` | 最初のイベントバナーのレイヤーを下げる。メレジナハード以降のハードレイドで追加報酬券をお知らせ（`REQ_PLAYER_CONTENTS_RECORD`） |
| [notice_msg.lua](notice_msg.lua) | `baubas_call` / `chat_system` | バウバス登場のお知らせ（ギルド通知の併用可）。ブラックマーケットのお知らせの間引き。`CHAT_TEXT_LINKCHAR_FONTSET` で消したいメッセージだけ落とす |
| [event_shout.lua](event_shout.lua) | `event_shout` | イベントのグローバルシャウトをチャットへ残し、専用の一覧フレームに溜める。トークンワープや使用ボタンを添える |

## しくみ

* `notice_msg.lua` の `CHAT_TEXT_LINKCHAR_FONTSET` は**素をそのまま呼びます**。素は「整形した
  文字列を返す」だけなので書き写す必要がなく、素が変わっても自動で追随します（Issue #53）。
  ここでやるのは「消したいメッセージなら nil を返す」判定だけです。
* お知らせの ON/OFF ボタンは、押されたボタン自身の表示だけを切り替えます。設定画面を
  作り直すと、検索で絞り込んだ状態が消えてしまうためです。

## 注意

* `event_shout.lua` の一覧フレーム（`event_frame`）は、機能 OFF のときに片付ける対象として
  [footer.lua](../footer.lua) の `g.frame_suffixes` に載っています。フレームを増やしたら
  そちらへも足すこと（Lua にフレームの列挙手段が無いため、固定名で並べています）。
