# その他の細かい機能（misc）

> 1 つの機能が数十行で収まるものの置き場。**1 ファイル 1 機能**を目安に分けている

| 項目 | 内容 |
| --- | --- |
| 設定画面 | 各セクション（ファイルごとに異なる） |

## ファイル

| ファイル | 設定キー | 内容 |
| --- | --- | --- |
| [ui_tweaks.lua](ui_tweaks.lua) | — | 細かい修正のまとめ。ノーマルジェムをはめるとき / カード・ジェム強化の数値入力 / ジェムロースティング屋の操作を減らす。古い装備ダメージフレームを消す |
| [frame_tweaks.lua](frame_tweaks.lua) | `auto_zoom` / `separated_buff` / `cupole_portion` | マップ切り替え時の自動ズーム。セパレートバフフレームの周りを綺麗にする。クポルのポーションフレームの移動と非表示 |
| [skill_enchant_tooltip.lua](skill_enchant_tooltip.lua) | `enchant_tooltip` | スキル錬成のスロットにツールチップを足す |
| [craft.lua](craft.lua) | `auto_craft` | アイテム製造時に材料を自動でセットする |
| [fps_option.lua](fps_option.lua) | — | システムオプションの FPS を手入力できるようにする |
| [vakarine_notice.lua](vakarine_notice.lua) | `vakarine` | レイドでヴァカリネ装備を他人に知らせる |
| [coin_shop.lua](coin_shop.lua) | `coin_count` | 各コイン商店の購入数上限を 99999 まで広げる |
| [indun_enter.lua](indun_enter.lua) | `under_staff` / `velnice` | 4 人以下の入場確認をスキップ。ヴェルニケの前回の階層を覚える |
| [equip_upgrade.lua](equip_upgrade.lua) | `status_upgrade` | 装備錬成（武器防具のステータス付与）を自動化する |
| [ability_sort.lua](ability_sort.lua) | `ability_sort` | スキルと特性のウィンドウで、特性をスキル順に並べ直す（素が作った行を `SetPos` で動かすだけ） |
| [market_sell.lua](market_sell.lua) | — | マーケット出店時に、持っている最大数を自動で入れる |
| [raid_record.lua](raid_record.lua) | `raid_record` | レイドレコードが 2 度呼ばれる不具合を直し、サイズと位置を変えられるようにする |
| [effect_settings.lua](effect_settings.lua) | `my_effect` / `other_effect` / `boss_effect` | 自分 / 他人 / ボスのエフェクト量（1〜100）を覚えて戻す |
| [indun_dialog.lua](indun_dialog.lua) | `equip_info` / `automatch_layer` / `restart_move` | アーク・エンブレムの着け忘れ通知。オートマッチ中のフレームのレイヤーを下げる。死亡時の選択肢フレームの移動とマウス位置 |
| [duel_and_restart.lua](duel_and_restart.lua) | `auto_accept_duel` / `restart_colony` | 決闘の申し込みを自動で受ける。コロニー死亡時の 30 秒タイマーの修正 |
| [dialog.lua](dialog.lua) | `dialog_ctrl` | 各種ダイアログの選択を進める |
| [pc_name.lua](pc_name.lua) | `pc_name` | 左上の名前をファミリーネームからキャラクター名へ |
| [auto_casting.lua](auto_casting.lua) | `auto_cast` / `auto_casting` | オートキャスティングの ON/OFF をキャラごとに覚える |
| [pet_and_relic.lua](pet_and_relic.lua) | `pet_ring` / `relic_gauge` | ペットリングフレームの非表示。キャラクターゲージへレリックを追加 |
| [reputation_shop.lua](reputation_shop.lua) | — | EP13 ショップを街で開けるようにする |
| [ragana.lua](ragana.lua) | `goodbye_ragana` | 街のラガナを消す |
| [rp_check.lua](rp_check.lua) | `rp_charge` | レリックの自動補充を補完する |
| [market_button.lua](market_button.lua) | `market_display` | 街では右上の商店一覧ボタンを常に出す |
| [skill_enchant_auto.lua](skill_enchant_auto.lua) | `skill_enchant` | スキル錬成の材料を自動でセットする |
| [goddess_gacha.lua](goddess_gacha.lua) | `auto_gacha` / `auto_gacha_start` | 女神の加護ガチャのフレーム表示と進行を自動化。フルベットボタン |
| [minimized_close.lua](minimized_close.lua) | `mini_btn` | レイド中は右上のミニボタンを隠す |
| [reroll_option.lua](reroll_option.lua) | `reroll_option` | オプションリロールの数値表を横に常時表示する |

## 注意

* **素の関数の中身を書き写さないこと。** 置換方式のフック（`g.setup_hook`）では必ず素を呼び、
  足りない分だけ足します。書き写すと、IMC 側が素を変えたときに**設定の ON / OFF に関わらず
  古い実装のまま**になり、エラーも出ません（CLAUDE.md / Issue #53）。
* **素にある項目を、機能が OFF のときに消さないこと。** 差し替えてよいのは ON のときだけです。
* ここに置くのは「1 ファイルに収まる小さな機能」だけです。育ってきたら専用のフォルダへ切り出し、
  [../README.md](../README.md) と manifest の並び、[docs/tests/test_core.lua](../../../../../docs/tests/test_core.lua)
  の `[25]` を一緒に直します。
