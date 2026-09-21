# 週間ボスレイド（weekly_boss）

> ダメージ報酬のちょい残し・ビルドランキング・報酬の自動受け取り

| 項目 | 内容 |
| --- | --- |
| 設定キー | `keep_first` / `boss_rank` / `weekly_boss_reward` / `solodun_reward` |
| ソース | 下表 |
| 設定画面 | 「自動処理関連」セクション |

## ファイル

| ファイル | 設定キー | 内容 |
| --- | --- | --- |
| [reward_partial.lua](reward_partial.lua) | `keep_first` | ダメージ累計報酬の受け取り画面に「1 段目を残す」ボタンを足す |
| [ranking.lua](ranking.lua) | `boss_rank` | 職業タブを順に開いてランキングを集め、自前の一覧を作る。ログファイルへの保存・作り直し |
| [rank_memberinfo.lua](rank_memberinfo.lua) | — | 素のランキング一覧の各行へ `Info` ボタンを足し、`/memberinfo` を引けるようにする（`WEEKLY_BOSS_RANK_UPDATE` のフック。個別版が居るときは何もしない） |
| [reward_auto.lua](reward_auto.lua) | `weekly_boss_reward` / `solodun_reward` | 週間ボスレイド報酬とヴェルニケダンジョン報酬を自動で受け取る |

## しくみ

* ランキングは**ソードマン系統のタブから取得しないと正常に動かない**という制約があり、
  `base_jobids`（`{1001, 2001, 3001, 4001, 5001}`）を順に処理します（v1.7.8.8）。
* 収集の途中経過は `processed_job_ids` / `result_tbl` / `existing_data_check` /
  `start_time` に持ちます。これらは [ranking.lua](ranking.lua) 冒頭で宣言している
  **トップレベルの local** なので、利用側をこの宣言より前へ動かさないこと。
* 取得結果は `../addons/_nexus_addons_p/<AID>/mini_addons_log.dat`（`g.boss_rank_log_path`）に
  保存します。以前の `../addons/mini_addons_p/log.dat` は、フォルダを作る処理が無いため開発者の PC 以外では
  保存に失敗していました。旧パスと個別版（`../addons/mini_addons/log.dat`）からは
  `Mini_addons_migrate_boss_rank_log` が初回だけ写します。
* 保存データに上限はありません。設定 `boss_rank_prune`（既定 0。data ボタンのメニュー最下段で切り替え）が
  1 のときだけ、保存のたびに今週を含めて 4 週より古い週を落とします（`Mini_addons_prune_boss_rank_records`）。
* 自前の一覧ウィンドウは ESC で閉じられます（入口は `Mini_addons_ranking_ESCAPE_PRESSED`）。
