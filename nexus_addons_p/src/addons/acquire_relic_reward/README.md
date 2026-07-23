# Acquire Relic Reward

> 自動でレリッククエスト報酬を受け取ります

| 項目 | 内容 |
| --- | --- |
| キー | `acquire_relic_reward` |
| ソース | [acquire_relic_reward.lua](acquire_relic_reward.lua) |
| 設定画面 | なし（アドオン一覧の ON/OFF のみ） |
| 原作者 | ebisuke さん |

## 使い方

ON にして、**クレイペダ / フェディミアン / オルシャのいずれか**へ入るだけです。
受け取り待ちのレリッククエスト報酬があれば、順に自動で受領します。
受け取るものが無くなった時点で処理は止まります。

操作は不要で、UI も出ません。

## しくみ

`acquire_relic_reward_on_init` の時点でマップが
`c_Klaipe` / `c_fedimian` / `c_orsha` のときだけ、1.0 秒間隔の更新スクリプトを回します。

更新のたびに `Relic_Quest` クラスを全走査し、`QuestType` が `None` でないものについて
`SCR_RELIC_QUEST_CHECK` を呼び、結果が `Reward`（受領可能）なら
`SCR_TX_RELIC_QUEST_REWARD` を実行して、その回はそこで打ち切ります（1 回につき 1 件）。
受領可能なものが 1 件も無ければ更新スクリプトを止めます。

## 保存先

なし（ON/OFF は `../addons/_nexus_addons_p/<アカウントID>/settings.json` に入ります）。

## 注意

* **動くのは上の 3 都市に入った直後だけ**です。フィールドで報酬が発生しても、
  いったん都市へ移動しないと受け取りません。
* 派生版では、マップ切替時などにゲームがクラッシュする不具合を修正済みです。
