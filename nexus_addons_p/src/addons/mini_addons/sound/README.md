# サウンド（sound）

> BGM プレイヤー・ミュートの切り替え・スキル連打音の抑制

| 項目 | 内容 |
| --- | --- |
| 設定キー | `bgm` / `select_bgm` / `skill_cool_sound` / `volume`（記憶用） |
| ソース | [bgm.lua](bgm.lua) / [toggle.lua](toggle.lua) / [skill_sound.lua](skill_sound.lua) |
| 設定画面 | 「その他」セクション |

## ファイル

| ファイル | 設定キー | 内容 |
| --- | --- | --- |
| [bgm.lua](bgm.lua) | `bgm` / `select_bgm` | 街で BGM プレイヤーを常に動かす。選んだ曲を覚える |
| [toggle.lua](toggle.lua) | — | ミニマップ左下ボタンの**右クリックでミュート ⇔ 復帰**。直前の音量を `volume` に覚える |
| [skill_sound.lua](skill_sound.lua) | `skill_cool_sound` | スキル連打時のクールタイム音を鳴らさない（`ICON_USE`） |

## 注意（toggle.lua）

* **記憶するのは 0 より大きい音量だけ。** 以前は 0 も覚えてしまい、ゲーム側で音量 0 の状態で
  最初に押すと「復帰」しても `SetTotalVolume(0)` を書くだけになり、**二度と音が戻りません**でした。
* **イベントスクリプトの中で落ちてもどこにも記録が残りません**（`debug_log.txt` に載るのは
  メッセージハンドラだけ）。そのため `pcall` で受けて `g.vlog` へ出しています。この記録は消さないこと。
* 張り直しは `GAME_START_3SEC` から毎回走ります。`minimap_outsidebutton` / `BGM_PLAYER` は
  **必ず nil を見てから触ること**。ここで落ちると `GAME_START_3SEC` の残り全部が道連れになります。
