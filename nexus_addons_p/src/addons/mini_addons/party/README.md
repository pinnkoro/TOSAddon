# パーティー（party）

> PT 情報フレームのリサイズと、メンバーの現在地表示

| 項目 | 内容 |
| --- | --- |
| 設定キー | `pt_info` / `party_info` |
| ソース | [member_map.lua](member_map.lua) / [party_info.lua](party_info.lua) |
| 設定画面 | 「フレーム関連」セクション |

## ファイル

| ファイル | 設定キー | 内容 |
| --- | --- | --- |
| [member_map.lua](member_map.lua) | `pt_info` | PT 情報にメンバーの居るマップ名を足す |
| [party_info.lua](party_info.lua) | `party_info` | パーティー情報フレームをバフの数に合わせて小さくする（`PARTY_BUFFLIST_UPDATE`） |

## 注意

* PT メンバーのバフ一覧の取得は、他アドオンと取り合いになったことがあります（v1.5.6）。
  バフの表示 / 非表示そのものは [buff_list/](../buff_list/) 側です。
