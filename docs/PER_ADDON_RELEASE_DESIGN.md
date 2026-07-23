# 個別アドオン化 + まとめ版の二本立て配布 — 検討メモ

各アドオンを 1 フォルダ = 1 配布単位にし、
**個別アドオンの `.ipf`** と **まとめ版 `nexus_addons_p` の `.ipf`** を
それぞれ独立にリリースする構成を検討する。

## 決定事項

| 項目 | 決定 | 根拠 |
| --- | --- | --- |
| グローバル関数名の `_p` 化 | **個別版のビルド時にだけ**機械的に付ける。src は本家と同形のまま | 938 個を src で改名すると upstream マージが事実上不可能になる（§2-3） |
| 個別化の範囲 | **仕組みは 49 個ぶん作り、公開は需要のあるものから段階的に** | `addons.json` に載せた分だけが公開されるので、保守コストを抑えつつ後から広げられる |
| リポジトリ配置 | **`addons/<name>_p/` 配下**（ルート直下には並べない） | 機能差は無く、ルートの見通しを保てる（§3-1） |
| 設定データ | **まとめ版と共有**（`../addons/_nexus_addons_p/<AID>/`） | 個別版 ⇄ まとめ版の乗り換えで設定が保たれる（§2-5） |

結論を先に書くと **実現可能。ただしフォルダを移して `.ipf` を 50 個作るだけでは済まない**。
実作業の本体は次の 4 つで、いずれも今の作りの前提を変える必要がある。

| # | やらないと成立しないこと | なぜ |
| --- | --- | --- |
| 1 | ~~`.ipf` 暗号化のスクリプト化~~ **完了**（§3-6） | リポジトリ外の Windows exe を手動実行していた。50 個は回らない |
| 2 | core → アドオンの逆依存を断つ | core が特定アドオン名を直書きしており、単体で切り出せない |
| 3 | 個別版のグローバル名に接尾辞を付ける | 938 個のグローバル関数がまとめ版と衝突する |
| 4 | リリース基盤の N 個対応 | タグ・採番・検証・CI が全部 1 アドオン固定 |

---

## 1. 調査で確定した現状（事実）

### 1-1. 配布単位

* 配布実体は `.ipf` 1 個。中身は `_nexus_addons_p/` フォルダに 3 ファイル
  （`_nexus_addons_p.lua` / `_nexus_addons_p.xml` / `_nexus_addons_p_conclude.lua`）。
* `.lua` 2 つは `nexus_addons_p/src/**` を manifest 順に**生連結**した生成物
  （[bundle_from_src.py](bundle_from_src.py)、golden sha で再現性を固定）。
* アドオンは **49 個**（main 側 48 + conclude 側 `ancient_monster_bookshelf` 1）。
  `src/addons/<key>/<key>.lua` に 1 アドオン 1 フォルダで分割済み。合計 29,131 行。

### 1-2. アドオン → core の依存

全 48 アドオンが `g.settings` を参照する。ほかにも core の共有ヘルパへ広く依存している。

| 種別 | 具体例 |
| --- | --- |
| I/O | `g.save_json` / `g.load_json` / `g.save_lua` / `g.load_lua` / `g.atomic_replace` |
| フック | `g.setup_hook` / `g.setup_hook_and_event` / `g.get_event_args` / `g.FUNCS` |
| セッション状態 | `g.lang` / `g.cid` / `g.active_id` / `g.map_name` / `g.map_id` / `g.pc` / `g.addon` / `g.frame` |
| ユーティリティ | `g.get_map_type` / `g.vlog` / `g.log_to_file` / `g.mkdir_new_folder` / `g.create_persistent_frame` |
| 設定 | `g.settings[<key>].use`（ON/OFF 判定。**48 アドオン全部**が見る） |

→ **アドオン単体の `.lua` を切り出しても、そのままでは 1 行も動かない。**
　 個別版には core を同梱するしかない（§3-1）。

### 1-3. core → アドオンの逆依存（分割の一番の障害）

core 側が特定アドオンの名前を**直書き**している箇所が 5 つある。

| 場所 | 内容 |
| --- | --- |
| `10_registry.lua` | 49 件の登録リスト（`name` / `frame_use` / `config_func` / `old_init_func`）+ 多言語ヘルプ `_trans` |
| `20_lifecycle.lua` `_nexus_addons_p_fast_func` | `Separate_buff_custom_frame_move` / `Quickslot_operate_redraw_slots` / `Indun_panel_frame_init` / `another_warehouse_on_init` を直接呼ぶ |
| 同 `update_check_frames` | 常時表示を維持するフレーム名 15 個をリテラルで持つ |
| 同 `_nexus_addons_p_list_close` | 一括で閉じる設定フレーム名 19 個をリテラルで持つ |
| 同 `_nexus_addons_p_APPS_TRY_MOVE_BARRACK` | `Other_character_skill_list_save_enchant` / `Indun_list_viewer_save_current_char_counts` / `Instant_cc_APPS_TRY_LEAVE_` / `Indun_list_viewer_CHECK_ALERT` |

→ このままだと「アドオンを 1 個抜く」たびに core が壊れる。
　 **アドオン側が自分を登録する形（登録 API）へ反転させる**必要がある（§3-2）。

### 1-4. アドオン同士の依存

相互参照は **8 箇所だけ**（想定より少ない）。ただし一部は無防備な直呼び。

| 呼ぶ側 | 呼ぶ先 | 防御 |
| --- | --- | --- |
| `another_warehouse` | `Cc_helper_inv_rbtn` | 無し（直呼び） |
| `cc_helper` | `Another_warehouse_inv_rbtn` | 無し |
| `cc_helper` | `Monster_card_changer_monstercardpreset_open` / `_remove` | 無し（3 箇所） |
| `indun_panel` | `Indun_list_viewer_save_current_char_counts` | 無し |
| `instant_cc` | `Indun_list_viewer_CHECK_ALERT` | 無し |
| `other_character_skill_list` | `Instant_cc_save_char_data` / `indun_list_viewer_on_init` | `type(_G[...]) == "function"` で防御済 |

まとめ版では「OFF のアドオンでも関数定義だけは存在する」ため直呼びでも落ちない。
個別版では相手が存在しないので、**無防備な 6 箇所は `_G[...]` 経由の存在確認に直す**必要がある。

### 1-5. グローバル関数名

* アドオン群が定義するグローバル関数は **938 個**（`Always_status_*` / `Indun_panel_*` 等）。
* これらは**本家 Nexus Addons と同名のまま**。だから今は
  「本家が居たらアドオン本体を一切定義しない」という全か無かのガード
  （`guard_open.lua` / `guard_close.lua`）で回避している。
* 名前は `SetEventScript(ui.LBUTTONUP, "Always_status_checkbox")` のように
  **文字列でも参照される**（登録リストの `config_func` も同様）。単純な識別子置換では足りない。

### 1-6. `.ipf` のビルド

* 平文コンテナ生成は Python 化済み（[build_addon_ipf.py](build_addon_ipf.py)）。
* **暗号化だけがリポジトリ外の Windows exe（`ipf_unpack.exe encrypt`）の手動実行**。
* 検証（[verify_ipf.py](verify_ipf.py)）は暗号化後でも通る。ファイルテーブルが平文で
  平文 CRC32 を持つため。

### 1-7. リリース基盤

* [release-nexus.yml](../.github/workflows/release-nexus.yml) は `file == "nexus_addons_p"` 決め打ち、
  `.ipf` は `nexus_addons_p/*.ipf` の 1 個決め打ち。
* タグは移動タグ `nexus_addons_p` + 保存用の版番号タグ `v1.0.2`。
  **保存用タグ名が版番号そのもの**なので、49 アドオンが各々 `v1.0.0` を持つと衝突する。
* [check_version_freeze.py](check_version_freeze.py) / [verify_ipf.py](verify_ipf.py) も
  「版数は 3 箇所」（`00_header.lua` の `ver` / `addons.json` の `fileVersion` / `.ipf` ファイル名）固定。

---

## 2. 設計方針

### 2-1. 個別版は「core 同梱の自己完結型」にする（推奨）

| 案 | 内容 | 判定 |
| --- | --- | --- |
| **A. 自己完結**（推奨） | 個別 `.ipf` = 縮小 core + 対象アドオン 1 個 | ○ 依存解決が不要。アドオンマネージャーに依存関係の仕組みが無い以上、これしか堅い形が無い |
| B. 共有 core アドオン | `_nexus_addons_p_core.ipf` を別途入れてもらう | × core を入れ忘れた利用者に対して「入れたのに何も起きない」が起きる。`.ipf` 間のロード順も保証が無い |

core の重複は 1 アドオンあたり数十 KB。`.ipf` はどれも小さいので実害は無い。

### 2-2. core を登録 API に反転させる

`10_registry.lua` の静的テーブルと `20_lifecycle.lua` の直書きリストを廃し、
各アドオンファイルの先頭で自己申告させる。

```lua
-- addons/always_status/always_status.lua の先頭
g.register("always_status", {
    name = "Always Status",
    frame_use = true,
    config_func = "Always_status_info_setting",
    old_init_func = "ALWAYS_STATUS_ON_INIT",
    p_init_func = "ALWAYS_STATUS_P_ON_INIT",   -- 個別版の検出用（§2-4）
    keep_visible_frames = { "always_status" },  -- update_check_frames へ
    close_with_list    = { "always_status_settings" }, -- list_close へ
    on_fast_func       = "Always_status_fast",  -- 任意
    on_leave_barrack   = "Always_status_save",  -- 任意
    trans = { ja = "...", etc = "...", kr = "..." }
})
```

* core は登録された内容だけを見る = **アドオンが 1 個でも 49 個でも同じコードで動く**。
* まとめ版の挙動は変わらない（登録順 = 連結順 = 現行の出現順を維持すれば同一）。
* この作業は個別化と切り離して**単独で先に入れられる**。まとめ版だけでの回帰検証で済むので、
  リスクを段階的に潰せる（§4 Phase 3）。

### 2-3. 個別版のグローバル名はビルド時に機械的にリネームする

src は 1 本のまま、**まとめ版はそのまま / 個別版は接尾辞付き**の 2 通りを生成する。

```
src/addons/always_status/always_status.lua
   ├─ まとめ版へ連結 … Always_status_checkbox     （現状のまま）
   └─ 個別版へ連結   … Always_status_p_checkbox   （ビルド時に置換）
```

* 置換対象は「そのアドオンが定義するグローバル関数名」の閉じた集合（そのファイルの `^function X`）。
  識別子と**文字列リテラルの両方**を語境界付きで一括置換する。
* 置換件数をビルド時に出し、0 件のシンボルがあれば失敗させる（取りこぼしの検出）。
* 生成後に luajit で構文チェック（既存 CI と同じ）。
* **src を直接リネームしない理由**: 938 個の改名は本家からの `upstream` マージを事実上不可能にする。
  ビルド時変換ならソースは本家と同形のまま保てる。

これにより **まとめ版と個別版が同時に入っていても、グローバルは衝突しない**
（＝ロード順に依存しない）。表示が二重になるのは §2-4 で止める。

### 2-4. 共存ルール（優先順位）

同時に存在し得るものは 4 種類ある。

1. 本家 Nexus Addons（まとめ版）
2. Nexus Addons P（まとめ版）
3. 個別 P アドオン（N 個）
4. 本家の旧・個別アドオン（`old_init_func` が示すもの）

| 状況 | 動くもの | 実現方法 |
| --- | --- | --- |
| 1 が居る | 1 のみ | 現行の読み込み時ガード（変更なし） |
| 2 + 3 | **2 のみ**（個別版が黙って止まる） | 個別版が ON_INIT で `_NEXUS_ADDONS_P_ON_INIT` の有無を見て停止 + 案内 |
| 3 + 4 | 3 のみ | 個別版でも `old_init_func` 検出を行う（既存ロジックを流用） |
| 2 + 4 | 2（該当アドオンだけ OFF） | 現行のまま |

* まとめ版を優先するのは、まとめ版が個別版の上位互換だから。
* 判定は ON_INIT / GAME_START 時点で行う（ロード順に依存しない）。
  §2-3 でシンボルが分かれているので、**判定前に壊れることが無い**のがこの設計の要点。

### 2-5. 設定データの置き場は共有する（推奨）

個別版でも保存先を `../addons/_nexus_addons_p/<AID>/` に固定する。

* 個別版 ⇄ まとめ版を乗り換えても設定が保たれる。
* `g.settings` は個別版では `{ <key> = { use = 1, ... } }` だけを持つスタブにする
  （「入れた = 有効」。ON/OFF 一覧 UI は個別版には出さない）。
* まとめ版の `settings.json` を個別版が読むと未知キーが刈られる問題がある
  （`_nexus_addons_p_load_settings` のプルーニング）。
  → **個別版は `settings.json` を書き換えない**（`use` は常に 1 とみなす）ことで回避する。
  アドオン固有の設定ファイル（`always_status.json` 等）は従来どおり読み書きする。

### 2-6. メニューボタン

個別版でも `_G["norisan"]["MENU"]` への相乗り機構をそのまま使う。
自分の 1 項目（設定フレームを開く）だけ登録すれば、複数の個別版を入れても
1 つのメニューボタンに項目が並ぶ。`core/90_addons_menu.lua` は個別版にも同梱する。

---

## 3. リポジトリ配置とリリース基盤

### 3-1. 配置

```
addons/                        ← 個別アドオン（1 アドオン 1 フォルダ）
    always_status_p/
        addon.json             ← このアドオンのメタデータ（唯一の正）
        always_status.lua      ← ソース（まとめ版もここを参照）
        README.md
        always_status_p-⛄-v1.0.0.ipf
        _old/
    indun_panel_p/
        ...
nexus_addons_p/                ← まとめ版
    addon.json
    src/core/**                ← core（個別版もここを参照）
    src/guard_open.lua / guard_close.lua / conclude_header.lua
    build_manifest.json
    _nexus_addons_p-⛄-v1.0.3.ipf
    _old/
addons.json                    ← 生成物（各 addon.json から組み立て / CI で一致検査）
docs/ .github/ ...
```

* 各アドオンの `.lua` を**まとめ版と個別版の両方が参照する**（コピーは作らない）。
  まとめ版の `build_manifest.json` は `../addons/<name>_p/<key>.lua` を参照する形になる。
* `addons/`（複数形・個別アドオン置き場）と `addons.json`（マネージャー用の生成物）は
  別物なので混同しないこと。

### 3-2. メタデータを 1 箇所に集約する

版数の重複管理が 50 倍になるので、`<addon>/addon.json` を単一の正にする。

```jsonc
{
  "file": "always_status_p",        // 永続 ID。一度決めたら変更不可
  "name": "Always Status P",
  "version": "v1.0.0",
  "unicode": "⛄",
  "releaseTag": "always_status_p",
  "description": "...",
  "tags": ["..."],
  "in_bundle": true                  // まとめ版にも収録するか
}
```

* ルートの `addons.json` は**これらを連結した生成物**にする（`--check` で CI 検査）。
* 個別版の `.lua` ヘッダの `ver` はビルド時にここから注入する（手書きの三重管理をやめる）。
* まとめ版の `00_header.lua` の `ver` は生連結の都合で手書きのまま残し、
  `addon.json` と一致するかを CI で検査する。

### 3-3. タグ設計

| 用途 | 現行 | 変更後 |
| --- | --- | --- |
| 移動タグ（マネージャー参照先） | `nexus_addons_p` | 各 `addon.json` の `releaseTag`（= `file`）。例 `always_status_p` |
| 保存用タグ | `v1.0.2` | **`<file>-<version>`**。例 `always_status_p-v1.0.0` / `nexus_addons_p-v1.0.3` |
| アセット名 | `nexus_addons_p-v1.0.2.ipf` | `<file>-<version>.ipf`（マネージャーの慣習どおり） |

保存用タグを `<file>-` 付きに変えるのは必須（`v1.0.0` が 50 個ぶつかるため）。
既存の `v1.0.0`〜`v1.0.2` はそのまま残す（過去の記録なので触らない）。

### 3-4. リリースワークフロー

`release-nexus.yml` を「`addons.json` の全エントリをループする」形に一般化する。

* 各エントリについて、移動タグの Release に付いているアセット名と
  `addons.json` の `fileVersion` を比較し、**違うものだけ**作り直す。
  git の差分ではなく「公開済みの版」と比較するので、取りこぼしも二重公開も起きない。
* リリースノートは現行どおり main→release のマージ元 PR 本文を流用する。
  50 個のうち更新されたものだけに同じノートが付く形になる。

### 3-5. 採番ルール

* 現行の「main では版を上げない / `release-prep/**` でだけ採番」を **50 エントリに一般化**する。
  `check_version_freeze.py` は全 `addon.json` + `addons.json` + 全 `.ipf` ファイル名を見る。
* **アドオンを 1 個直したら、そのアドオンとまとめ版の両方を採番する**
  （まとめ版の中身も変わるため）。この連動を CI で検査する。

### 3-6. `.ipf` 暗号化のスクリプト化 — **完了（Phase 1）**

50 個の `.ipf` を毎回手で暗号化するのは現実的でないため、外部ツール
（`ipf_unpack.exe <file> encrypt`）への依存を外した。実装は [ipf_crypt.py](ipf_crypt.py)。

* 中身は PKware（ZIP 伝統暗号）そのもので、変種は 2 点だけだった:
  1. 各ファイルのデータ本体のうち、**ファイル先頭からの相対位置が偶数**のバイトにのみ適用
     （奇数位置は素通り。鍵更新も偶数位置のぶんしか回さない）
  2. **鍵はファイルごとに初期化し直す**（コンテナ全体で連続させない）
  固定パスワードは既存の読み取りツール（TosSukillSimulator の `tools/tos_extract.py`）が
  持っていた値と同じ。
* **正しさの根拠**: 配布中の `_nexus_addons_p-⛄-v1.0.2.ipf` を現 src から
  `bundle_from_src.py` → `build_addon_ipf.py --encrypt` で再生成すると
  **259,788 バイト全一致**する。外部ツールの出力と区別が付かない。
* `build_addon_ipf.py --encrypt` で **src → 配布形式まで 1 コマンド**になった。
* CI（`bundle` ジョブ）で `ipf_crypt.py --self-test` が、リポジトリ内の全 `.ipf` について
  「復号 → raw deflate 展開 → テーブル記載の平文 CRC32 と一致する」を常時検査する。
  テーブルは暗号化されないので、暗号実装を経由しない独立オラクルになる。
  併走させている「復号 → 再暗号化で元に戻る」は**単体では暗号の検査にならない**
  （暗号側も復号側も同じ鍵ストリームを作るので、PW でもマスクでも偶数位置の判定でも
  何を壊しても往復は成立する。実際に改変して素通りすることを確認済み）。

> 副産物: `.ipf` を CI 上で生成できるようになったので、[verify_ipf.py](verify_ipf.py) の
> 「テーブルの CRC32 で中身を照合」を**バイト単位の完全一致**に強化できる。
> 検証の強化は独立した変更なので Phase 6 に回す。

---

## 4. 段階計画

| Phase | 内容 | 検証手段 | 依存 |
| --- | --- | --- | --- |
| ~~1~~ | ~~`.ipf` 暗号化の Python 実装~~ **完了** | 現行 `.ipf` とバイト一致（済） | — |
| 2 | メタデータ集約（`addon.json` / `addons.json` 生成 + CI 検査） | CI | — |
| 3 | core の登録 API 化（逆依存 5 箇所の解消 + 相互参照 6 箇所の防御） | まとめ版のみで実機回帰 | — |
| 4 | 個別ビルド系の試作（縮小 core + 改名変換）を **1 アドオンだけ**で | 実機（まとめ版との同時インストール含む） | 1,3 |
| 5 | 配置をルートへ移動 + manifest 再設計 | まとめ版のバイト一致（連結順を維持すれば不変） | 3 |
| 6 | リリース基盤の N 対応（ワークフロー / 採番 / 検証 / CI）+ `verify_ipf.py` をバイト一致検査へ強化 | `release-prep` での空撃ち | 2,5 |
| 7 | 個別版を段階公開（需要のあるものから数個ずつ） | 実機 | 全部 |

Phase 1〜3 は**個別化しなくても単体で価値がある**（ビルドの自動化と core の疎結合化）ので、
ここまでを先に入れて、Phase 4 の試作結果を見てから残りを判断するのが安全。

---

## 5. リスク・未決事項

### リスク

| リスク | 影響 | 緩和 |
| --- | --- | --- |
| ビルド時リネームの取りこぼし | 個別版だけ実機で壊れる。文字列参照は静的に追い切れない | 置換 0 件のシンボルを失敗扱い / 個別版の全関数名を luajit で定義確認 / 段階公開 |
| 実機検証が 49 倍 | 現実的に全数は無理 | まとめ版は現行どおり全体で確認、個別版は「core 同梱部分の共通検証 + 公開するアドオンだけ実機」 |
| core 登録 API 化でまとめ版が退行 | 全利用者に影響 | golden sha は必ずズレるので、**実機での重点確認が必須**。`g.vlog` で登録内容を出す |
| 利用者の混乱（まとめ版と個別版が両方並ぶ） | 二重インストール | `description` に明記 + §2-4 の案内メッセージ |
| 保守コストが 50 倍 | 継続的な負担 | 公開する個別版を絞る（仕組みは 49 個ぶん作るが、`addons.json` に載せた分だけが公開される） |

### 未決事項（Phase を進める中で決める）

1. **`in_bundle = false` を許すか**
   個別版でだけ配り、まとめ版には入れないアドオンを認めるか。認めるなら
   `build_manifest.json` の生成をメタデータ駆動にする必要がある。
2. **個別版の `unicode`（アイコン絵文字）**
   まとめ版と同じ ⛄ で揃えるか、アドオンごとに変えるか。
   マネージャーの一覧での見分けやすさの問題で、機能には影響しない。
3. **`_old/` の扱い**
   50 フォルダぶんの旧版 `.ipf` をリポジトリに残し続けるとサイズが効いてくる。
   保存用タグの Release に残るので、`_old/` は数世代で打ち切る案がある。
4. **個別版の README をどう保つか**
   現状の `src/addons/<key>/README.md` をそのまま流用するが、
   個別版では「まとめ版と同時に入れない」旨の追記が要る。
