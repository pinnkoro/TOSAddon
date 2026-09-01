# レベル上限が解放されたときの対応手順

Lv 上限が上がると、**新しい女神・新しいレイド・新しいチャレンジの段**が増える。
そのたびに同じ場所を触ることになるので、手順と罠をここにまとめる。
2026-09 の Lv560（サウレ / 偽りの輝翼 / 堕落した審判の翼 / 共鳴の聖所）で実際に踏んだ内容が元。

---

## 0. 前提: ID はどこから取るか

**upstream の `_client/**` を当てにしないこと。** norisan さんが取り込んだ時点のスナップショットで、
新パッチのデータは入っていない（2026-09-01 時点で `indun.ies` が 730 止まり、`job.ies` が 3112 止まり）。

**一次資料はローカルのゲーム本体**。

```
C:\Program Files (x86)\Steam\steamapps\common\Tree of Savior (Japanese Ver.)
```

`TosSukillSimulator/tools/tos_extract.py` が `data/` と `patch/` を新しい順にマージして
`.ies` を JSON 行で吐く。python.org 版 Python で実行すること（uv 同梱ビルドは避ける。個人メモ参照）。

```bash
cd /c/Users/pinnk/Documents/ToS/TosSukillSimulator/tools
PY="C:/Users/pinnk/AppData/Local/Programs/Python/Python312/python.exe"
"$PY" tos_extract.py indun.ies > indun.json
```

`read_table("<name>.ies")` を import して使うほうが速い。`.ies` 以外（素の UI の `.lua` / `.xml`）も
`_find_footer` / `_entries` / `_extract` を直に呼べば取り出せる。**素の挙動を推測せず、必ずこれで確かめること。**

* **アイテムは 1 枚の表ではない。** `item.ies` / `item_ep13.ies` / `item_event.ies` … に分かれている。
  目当てが見つからないときは全 `item*.ies` を舐める。
* **ゲーム起動中は `data/` のアドオン `.ipf` だけロックされる**（素のクライアントの `.ipf` は読める）。
  ロックされたものは PowerShell の `[System.IO.File]::Open(..., FileShare::ReadWrite)` で複製すれば読める。

---

## 1. 調べること（表と、そこから取る値）

| 表 | 取る値 |
| --- | --- |
| `indun.ies` | 新ダンジョンの ClassID。`ClassName` / `Level` / `DungeonType` / `SubType` / `RaidType` / `TicketingType` / `CheckCountName` / `PlayPerResetType` |
| `buff.ies` | 掃討バフ（`*_Auto_ClearBuff`）の ClassID |
| `item*.ies` | 入場券（`Ticket_*_Enter` / `_NoTrade` / `_LimitTime`）、緊急修理キット（`QuestReward_repairPotion_<Lv>`）、女神コイン（`<女神>CertificateCoin_*` と `dummy_<女神>Certificate`） |
| `monster.ies` | ボスの ClassID と `Icon`、`RaceType`（ポーションの系統） |
| `itemtradeshop.ies` | ショップの取引名（`<女神>Certificate_*` / `EVENT_TOS_WHOLE_SHOP_*` / `PVP_MINE_*`）と `TargetItem` |
| `job.ies` / `skill.ies` | 新クラスの `ClassName` / `EngName`、スキルの `ClassName` 接頭辞 |

**レイドは 1 コンテンツで 3 つの indun ID を持つ**（例: ズメイ = Auto 729 / Solo 730 / Party 731）。
`ClassName` の末尾 `_Auto` / `_Solo` / `_Party` で見分ける。

---

## 2. 触るファイル

### `addons/indun_panel/indun_panel.lua`

| 場所 | 足すもの |
| --- | --- |
| `induns` | 行の定義。レイドは `a`(Auto) / `s`(Solo) / `h`(Hard) / `ac`(掃討バフ) / `jp` / `icon` |
| `indun_keys`（`Indun_panel_load_settings`） | 行のキー。**足し忘れると設定が毎回消える** |
| 描画の振り分け（`Indun_panel_frame_contents`） | レイドなら onsweep の分岐へキーを追加 |
| `raid_tbl` | 入場券 3 種。並びは **`{7日, 取引不可, 通常}`**（期限付き優先） |
| `buff_ids` | Auto の indun ID → 掃討バフ ID |
| `DUNGEON_TICKET_CONFIG` | 入場券型のパーティダンジョン（アシャーク / 共鳴の聖所）だけ |
| `CHALLENGE_CONFIG` / `CHALLENGE_TIERS` | チャレンジの段 |
| `SINGULARITY_CONFIG` / `SINGULARITY_TIERS` | 分裂の段 |
| ショートカットの `button_keys`（2 か所）/ 描画分岐 / 設定チェック / `shop_props` ほか | 新しい女神ショップ |
| `cols` の既定とバックフィル | 新しいショートカットのキー |
| `vlog_new_induns` の `targets` | 新しい ID（実機で引けたか確かめる用） |

### そのほか

| ファイル | 足すもの |
| --- | --- |
| `addons/indun_list_viewer/indun_list_viewer.lua` | `ilv_RAID_KEYS` / `ilv_RAID_INFO`（`icon` は `icon_item_misc_boss_<ボス>`）。**`ver` を繰り上げる** |
| `addons/quickslot_operate/quickslot_operate.lua` | `quickslot_operate_raid_list` の該当 `RaceType` へ indun ID |
| `addons/auto_repair/auto_repair.lua` | `g.auto_repair` の 3 つ（キットの ClassID / 取引名 / 商店の種別）を**セットで** |
| `addons/mini_addons/settings/definitions.lua` | `COIN_ITEM` に新しい女神のコイン **8 個ひと組**（1p〜1000000p の 7 個 + `dummy_*`） |
| `core/10_registry.lua` | `updated` / `updated_note_jp` / `updated_note_en`（`g.VER_NEXT` を書く） |
| `nexus_addons_p/README.md` | 更新履歴の `（次回リリース）` へ追記 |
| 各アドオンの `README.md` | 対応表・ID・alt テキスト |

---

## 3. 罠（全部このリポジトリで実際に踏んだもの）

* **ID は増えるだけでなく消える。** Lv560 で `1005`（540 チャレンジの PT）が**データごと削除**された。
  古い ID を残すと「押しても何も起きないボタン」になる。**既存の ID も生きているか毎回確かめること。**
* **ショップの売り物が差し替わる。** `PVP_MINE_40/41/42` の `TargetItem` が 540 用から 560 用の
  入場券へ変わっていた。取引名を据え置くと「新しい券を買って古い段へ入ろうとする」。
  **`itemtradeshop.ies` の `TargetItem` を必ず見ること。**
* **Hard が後から来ることがある。** 偽りの輝翼 / 堕落した審判の翼は Solo と Auto だけで実装され、
  Party の ID（735 / 738）が欠番だった。`Indun_panel_create_frame_onsweep` は **`h` があるときだけ**
  HARD ボタンを作る。後から `h = 735` を足すだけで出る。
* **ボスのアイコンが使い回されることがある。** Uriel 系はモンスター 9 体すべて `Icon = "boss_uriel"` で、
  ボス画像にすると 2 行が同じ絵になる。**見分けが付かないときは入場券のアイコンを使う。**
* **新しい女神のショップボタン画像は無いことがある。** `baseskinset` の `goddess*_shop_btn` は 5 枚で、
  素の `minimized_certificate_shop_button` は**アウステヤの絵のままサウレの商店を開いて**いる。
  真似ると隣同士で同じ絵になるので、コインの画像（`icon_item_season_coin_<女神>`）を使う。
* **既存ユーザーへのバックフィルが要る。** 保存済みの設定に新しいキーが無いと、
  ダンジョンの行もショートカットも**誰にも表示されない**。`indun_keys` と `cols` の両方に
  「無ければ既定 ON」のループがある。`indun_list_viewer` は `ver` の繰り上げで補完が走る。
* **`GET_CURRENT_ENTERANCE_COUNT` の第 2 引数。** 素は `ClassName` が `Challenge_` か
  `SanctuartyResonance_` で始まるときだけ使う。`Entrance_Ticket` でも `DemonLair_*` などは
  この分岐に載らない（素の induninfo も同じ）。**素に無い読み方を自前で足さないこと。**
* **`bundle_from_src.py --bless` は bundle を書き出さない。** golden sha だけ更新して抜けるので、
  **必ず引数なしでもう一度実行**して `wrote ... (CHANGED)` を確認する。忘れると古い bundle を
  `.ipf` に詰めたまま、後続のチェックも `sha256 OK` と言って素通りする。
* **新クラスはたいてい何もしなくてよい。** クラス一覧は `GetClassList("Job")` から引いている。
  確認が要るのは `skill_gem_tooltip` の `job_name_fix_map` だけで、
  **スキルの `ClassName` の接頭辞が Job の `EngName` と食い違うクラスだけ**登録する。
  `skill.ies` の全 `ClassName` を Job の `EngName` 集合と突き合わせれば機械的に出せる。

---

## 4. 検証

```bash
PY="C:/Users/pinnk/AppData/Local/Programs/Python/Python312/python.exe"
"$PY" docs/bundle_from_src.py --bless     # golden 更新
"$PY" docs/bundle_from_src.py             # ← 必ずこれも。wrote (CHANGED) を確認
"$PY" docs/check_forward_refs.py
"$PY" docs/check_frame_hittest.py
"$PY" docs/check_version_freeze.py
wsl -d Ubuntu -- bash -lc "cd /mnt/c/.../TOSAddon && luajit -e \"assert(loadfile('nexus_addons_p/_nexus_addons_p/_nexus_addons_p.lua'))\""
# docs/tests/test_*.lua も luajit で回す
```

実機テスト用の `.ipf` は **`-dev` 付き**で作り、`data/` 直下の nexus 系が **1 本だけ**になるようにする
（2 本あると二重読み込み）。**クライアントが起動していると置き換えられない**ので先に終了させる。

置いたら**中身を検証すること**（古い bundle を詰めた事故が実際にあった）。

```python
# .ipf から lua を取り出して bundle とバイト比較 + 平文コンテナの CRC32 照合
ipf_crypt._check_bodies(ipf_crypt.decrypt(open(placed,'rb').read()))
```

**実機では詳細ログで確かめる。** 設定で「詳細なログをシステムに出力する」を ON にし、
`../addons/_nexus_addons_p/verbose_log.txt` に `vlog_new_induns` の行が出ているか、
「引けない」が無いかを見る。

---

## 5. リリースのとき

版数は**上げない**（`main` 向けの PR では先行採番の禁止）。README の見出しは `（次回リリース）` のまま、
`since` / `updated` には `g.VER_NEXT` を書く。採番は `release-prep/vX.Y.Z` で行い、
そこで `g.VER_NEXT` を実際の版へ置き換える。詳細は [CLAUDE.md](../CLAUDE.md) を参照。

**見た目が変わるので、スクリーンショット撮り直しの Issue を立てること**（画像はゲームを起動しないと撮れない）。
対象は `indun_panel/images/01-panel.png` `02-set.png` と `indun_list_viewer/images/01-list.png`。
