# チャット（chat）

> チャットフレームの改造・グループチャット・システムメッセージの間引き

| 項目 | 内容 |
| --- | --- |
| 設定キー | `chat_system` / `chat_new_btn` / `chat_width` / `group_chat` / `chat_recv` / `chat_frame` |
| ソース | 下表 |
| 設定画面 | 「チャット関連」セクション |

## ファイル

| ファイル | 設定キー | 内容 |
| --- | --- | --- |
| [chat_system.lua](chat_system.lua) | `chat_system` | `CHAT_SYSTEM` を差し替え、パーフェクト / ブラックマーケットのお知らせをチャットへ出さない |
| [chat_frame.lua](chat_frame.lua) | `chat_new_btn` / `chat_width` | チャット入力フレームへボタンを 3 つ足す（現在地リンク / パーティー招待リンク / インベントリの開閉）。入力バーを指定の幅だけ広げる（`chat_width.px`）。フレームの位置を `chat_xy` に覚える |
| [group_chat.lua](group_chat.lua) | `group_chat` | グループチャットの宛先をチャットフレームから選ぶ。表示名の変更・右クリックメニュー |
| [death_notice.lua](death_notice.lua) | `chat_recv` | PT メンバーの死亡と復活を `NICO_CHAT` で流す（`DRAW_CHAT_MSG`） |
| [chat_move.lua](chat_move.lua) | `chat_frame` | ワイドモニターで追加チャットフレームの移動が制限されるのを解除 |

## 注意

* `death_notice.lua` の `last_time` / `cd_time` は**同じ断片の先頭で宣言している連投の抑制**です。
  この宣言より前へ利用側を動かすとグローバル読み（= nil）になり、**エラーにならず**壊れます。
* チャットエクステンド系のアドオンが有効なときは、チャット機能を OFF にする作りです
  （v1.7.8.7 の変更）。
* `chat` フレームを `Resize` すると、素の `minheight="150"` で**高さが 36 → 150 へ丸め上げられ**、
  入力バーの下に透明な帯が出ます（避けられない）。`chat_width` で幅を変えるときは
  `Mini_addons_chat_update_hittest` が背景の当たり判定を切り（`EnableHittestFrame(0)`）、帯がクリックを
  吸わないようにしています（#172）。
  背景を切ると入力バーを掴めなくなるので、右端の取っ手（`nexus_chat_grip`）と `edit_bg` を掴んだときに
  自前で動かします（`Mini_addons_chat_drag_start`）。ボタン追加だけのときは幅を素の 500 のまま使います。
