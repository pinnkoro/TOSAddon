# パーティー（party）

> PT 情報フレームのリサイズと、メンバーの現在地表示、バフアイコンへの重ね置き

| 項目 | 内容 |
| --- | --- |
| 設定キー | `pt_info` / `party_info` / `party_free_move` |
| ソース | [member_map.lua](member_map.lua) / [party_info.lua](party_info.lua) |
| 設定画面 | 「フレーム関連」セクション |

## ファイル

| ファイル | 設定キー | 内容 |
| --- | --- | --- |
| [member_map.lua](member_map.lua) | `pt_info` | PT 情報にメンバーの居るマップ名を足す |
| [party_info.lua](party_info.lua) | `party_info` / `party_free_move` | パーティー情報フレームをバフの数に合わせて小さくする（`PARTY_BUFFLIST_UPDATE`）。`party_free_move` が ON のときは素の `PARTYINFO_AVOID_BUFF_OVERLAP`（バフアイコンに重なると下へ押し出す。2026-11-24 のパッチで追加）を呼ばない |

## 注意

* PT メンバーのバフ一覧の取得は、他アドオンと取り合いになったことがあります（v1.5.6）。
  バフの表示 / 非表示そのものは [buff_list/](../buff_list/) 側です。
* `party_free_move` で止めている素の押し出しは、窓（`hittestframe="true"`）がバフアイコンを覆って
  右クリックでバフを消せなくなるのを避けるためのものです。ON にした人にはその副作用が出ます（既定は OFF）。
  素の関数が無いクライアントではフックを掛けません（[lifecycle/init.lua](../lifecycle/init.lua)）。
