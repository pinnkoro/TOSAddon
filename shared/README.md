# shared — 複数のアドオンで使う共通部品

`shared/src/**` は **1 つのソースを、複数のアドオンの `.ipf` へ入れるための置き場**です。
今は次の 2 つが取り込んでいます。

| アドオン | 取り込み方 |
| --- | --- |
| [Nexus Addons P](../nexus_addons_p/) | `nexus_addons_p/src/build_manifest.json` の `targets` |
| Icor Planner | 同じ manifest の 2 つ目の `targets` |

## なぜビルド時に配るのか

**ゲーム内では `.ipf` 同士で関数を共有できません。** 読み込み順は決められず、
片方だけ入れている利用者も居るので、実行時に相手の関数を当てにすると壊れます。
そこで**リポジトリ上のソースは 1 か所**にし、`docs/bundle_from_src.py` が連結の段で
それぞれの `.ipf` の中へ同じ中身を入れます（二重管理にならない）。

## 書くときの決まり

* **特定のアドオンの名前・設定を直接見ないこと。** 使ってよいのは、取り込む側が
  先に用意する `g`（本体テーブル）/ `addon_name_lower` / `json` と、`g.vlog_tag` のような
  取り込む側が決める値だけです。
* **連結順は取り込む側の manifest が決めます。** `g` や `addon_name_lower` を定義する
  ファイルより後ろに並べること。
* 検査（`docs/check_frame_hittest.py` / `docs/check_vanilla_writes.py` / `docs/vanilla_api.py`）は
  `shared/src/**` も `nexus_addons_p/src/**` と同じように見ます。表記は `shared/xxx.lua` です。
* `docs/tests/*.lua` は core を手で連結しているので、**共通部品を足したらテスト側の一覧にも足す**こと。

## 中身

| ファイル | 中身 |
| --- | --- |
| `10_json.lua` | 設定ファイルの読み書き（`g.load_json` / `g.save_json` / `g.atomic_replace`） |
| `20_vlog.lua` | 詳細ログ（`g.vlog`。チャットの印は `g.vlog_tag`） |
| `30_frame.lua` | ウィンドウの土台（`g.create_persistent_frame`）と裏クリックの遮断（`g.block_click_through`） |
| `40_esc.lua` | ESC で閉じるフレームのスタックと、ESC を受けたときの中身（`g.esc_on_escape`） |
| `50_frame_pos.lua` | 設定画面を置く位置（`g.settings_frame_pos`） |
