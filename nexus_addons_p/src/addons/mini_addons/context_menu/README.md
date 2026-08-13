# 右クリックメニュー（context_menu）

> 素のコンテキストメニューへ「メンバーインフォ」「決闘の申し込み」を足す仕掛け

| 項目 | 内容 |
| --- | --- |
| 設定キー | `memberinfo` / `auto_accept_duel`（後者は [misc/duel_and_restart.lua](../misc/duel_and_restart.lua)） |
| ソース | [context_menu.lua](context_menu.lua) |
| 設定画面 | 「その他」セクション |
| テスト | [docs/tests/test_mini_addons_menu.lua](../../../../../docs/tests/test_mini_addons_menu.lua) |

## 対象のメニュー

`CHAT_RBTN_POPUP` / `POPUP_GUILD_MEMBER` / `CONTEXT_PARTY` / `SHOW_PC_CONTEXT_MENU` /
`POPUP_FRIEND_COMPLETE_CTRLSET`

## しくみ

`ui.CreateContextMenu` → `ui.OpenContextMenu` で完結するため、素を呼んだ後からでは項目を足せません。
そこで `mini_addons_menu_hook` が、**素を呼び、その同期実行の間だけ `ui.AddContextMenuItem` /
`ui.OpenContextMenu` を横取り**して、メニューが開く前に項目を足す・落とします。

* `opts.drop` … この文字列を含む素の項目を落とす（素の項目を自分のものへ差し替えるとき）
* `opts.insert` … `function(context, add)` で項目を足す。`add` は**素の** `ui.AddContextMenuItem`
  （自分が足したものが `drop` に食われないようにするため）。キャンセルの手前へ差し込み、
  見つからなければ開く直前に足す

## 注意

* **横取りは必ず元へ戻すこと**（`pcall` が失敗した経路も含む）。戻し忘れると、ゲーム中の
  **全ての右クリックメニュー**を巻き込みます。
* **素の戻り値はそのまま返すこと。** `SHOW_PC_CONTEXT_MENU` は context を返し、呼び元の
  `_SHOW_PC_CONTEXT_MENU` が位置合わせに使います。
* `ui.*` を差し替えられないクライアントでは横取りを諦め、素をそのまま呼びます（追加項目は
  出ませんが標準のメニューは壊れません）。可否は `verbose_log.txt` へ 1 回だけ出します。
* **素にある項目を、機能が OFF のときに消さないこと**（Issue #53）。差し替えてよいのは ON のときだけです。
