# インベントリ（inventory）

> インベントリの改造・イコルステータス／遺物効果の検索・コインの自動使用

| 項目 | 内容 |
| --- | --- |
| 設定キー | `inventory_mod` / `icor_status_search` / `coin_use` |
| ソース | 下表 |
| 設定画面 | 「フレーム関連」「自動処理関連」セクション |

## ファイル

| ファイル | 設定キー | 内容 |
| --- | --- | --- |
| [inventory_op_pop.lua](inventory_op_pop.lua) | `chat_new_btn` | アイテムを掴んだときにチャットへアイテムリンクを貼る。チャットが出ていないとき・CTRL 押下中は何もしない |
| [ikor_search.lua](ikor_search.lua) | `icor_status_search` | 素の `INVENTORY_TOTAL_LIST_GET` を呼び、検索中だけ一覧を絞って、イコルのステータス・遺物（`Arc_`）の効果名でも当てる。**半角スペース区切りで OR 検索** |
| [coin_auto_use.lua](coin_auto_use.lua) | `coin_use` | 傭兵団コイン・女神コイン・王国再建団コインなどを取得時に自動で使う（対象は `COIN_ITEM`） |
| [inventory_open.lua](inventory_open.lua) | `inventory_mod` | インベントリを開いたときのスロットまわりの改造 |

## 注意

* `ikor_search.lua` は素を書き写さず、検索中だけ `session.GetInvItemSortedList` / 入力欄の取得 /
  `EMPTY_TREE_INVENTORY_OPTION_TEXT` を同期実行の間だけ横取りします。素の本文が変わると
  `docs/vanilla_api.py --verify-client` が落ちるので、そのときはここを見直してください。
* コインの自動使用は**街でだけ**動き、女神ガチャ中は使いません（v1.0.6 / v1.0.7）。
