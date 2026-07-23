# Silent Velnice Ranking

> ヴェルニケのランキングを非表示にします（TAB キー押下で表示）

| 項目 | 内容 |
| --- | --- |
| キー | `silent_velnice_ranking` |
| ソース | [silent_velnice_ranking.lua](silent_velnice_ranking.lua) |
| 設定画面 | なし（アドオン一覧の ON/OFF のみ） |
| 原作者 | ebisuke さん |

## 使い方

ON にして**ヴェルニケ（マップ ID `8022`）**へ入ると、
戦闘中に勝手に開くスコアボード（ランキング）が自動で閉じられ、画面が塞がらなくなります。

見たくなったら **TAB キー**を押してください。その場でスコアボードが開き、
以降は自動で閉じなくなります（そのマップに居る間は再び抑止されません）。

## しくみ

マップ ID が `8022` のときだけ `DO_SOLODUNGEON_SCOREBOARD_OPEN` を購読します。
スコアボードが開かれると 0.2 秒間隔のタイマーを起動し、
`solodungeonscoreboard` フレームが表示されていれば毎回 `ShowWindow(0)` で閉じ続けます。

TAB が押された時点で `SOLODUNGEON_SCOREBOARD_OPEN` を明示的に呼んでスコアボードを開き、
タイマーを停止します。

## 保存先

なし（ON/OFF は `../addons/_nexus_addons_p/<アカウントID>/settings.json` に入ります）。

## 注意

* **対象はヴェルニケ（`8022`）のみ**です。他のソロダンジョンのスコアボードには効きません。
* 一度 TAB で開くと抑止が終わります。もう一度抑止したい場合はマップに入り直してください。
