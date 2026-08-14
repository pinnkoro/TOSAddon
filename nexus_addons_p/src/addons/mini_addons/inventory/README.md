# インベントリ（inventory）

> インベントリの改造・イコルステータス検索・コインの自動使用

| 項目 | 内容 |
| --- | --- |
| 設定キー | `inventory_mod` / `icor_status_search` / `coin_use` |
| ソース | 下表 |
| 設定画面 | 「フレーム関連」「自動処理関連」セクション |

## ファイル

| ファイル | 設定キー | 内容 |
| --- | --- | --- |
| [inventory_op_pop.lua](inventory_op_pop.lua) | `chat_new_btn` | アイテムを掴んだときにチャットへアイテムリンクを貼る。チャットが出ていないとき・CTRL 押下中は何もしない |
| [ikor_search.lua](ikor_search.lua) | `icor_status_search` | `INVENTORY_TOTAL_LIST_GET` を差し替え、イコルのステータスで絞り込む。**半角スペース区切りで OR 検索** |
| [coin_auto_use.lua](coin_auto_use.lua) | `coin_use` | 傭兵団コイン・女神コイン・王国再建団コインなどを取得時に自動で使う（対象は `COIN_ITEM`） |
| [inventory_open.lua](inventory_open.lua) | `inventory_mod` | インベントリを開いたときのスロットまわりの改造 |

## 注意

* `ikor_search.lua` 冒頭の `inven_title_name` / `_inven_sort_type_option` は**この断片で共有している
  トップレベルの local** です。宣言より前へ利用側を動かすと nil になり、エラーを出さずに壊れます。
* コインの自動使用は**街でだけ**動き、女神ガチャ中は使いません（v1.0.6 / v1.0.7）。
