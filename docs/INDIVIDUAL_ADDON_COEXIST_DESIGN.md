# 個別アドオンとの共存 + 設定引き継ぎ — 設計メモ

まとめ版 Nexus Addons P に入っている各アドオンは、**個別アドオンとしても配布されている**
（本家リポジトリの `_replaced/` に 39 個が現存）。両方インストールされた場合に

1. 競合を検出して**エラー文を出し、該当アドオンの初期化を止める**
2. 個別版の設定ファイルがあれば、**初期化時に引き継ぐ**

という共通基盤を用意する。併せて、まだ同梱していない
`market_favorite_rebuild` / `mini_addons` の 2 つを同梱する。

## 決定事項

| 項目 | 決定 | 根拠 |
| --- | --- | --- |
| 競合検出の仕組み | **既存の `old_init_func` を使う。新機構は作らない** | 46 アドオン分が宣言済みで、検出・無効化・UI ブロックまで実装済み（§1-2） |
| 読み込み時ガード | **作らない** | 同梱版と個別版でグローバル名が衝突しないことを実測で確認（§1-3） |
| 設定引き継ぎ | **新規に共通関数を作る**（宣言テーブル駆動） | 保存先の形が本家と違うため `migrate_from_origin` を流用できない（§1-4） |
| 新規 2 アドオンの取り込み方 | **自己完結のまま同梱 + private グローバルをリネーム** | 共有フレームワーク（`g`/registry）に依存しない作りのため（§1-5） |
| ride-along 名 | `_G["norisan"]["MENU"]` / `norisan_menu_frame` は**リネームしない** | CLAUDE.md の既存ルール。変えると他アドオンの項目が出なくなる |

結論を先に書くと、**当初の想定より必要な作業は小さい**。
競合検出は既に動いており、新規に作るのは設定引き継ぎと新規 2 アドオンの取り込みだけ。

---

## 1. 調査で確定した現状（事実）

### 1-1. 個別版は実在し、識別子が不統一

本家リポジトリ `_replaced/` に 39 個の個別版がある。まとめ版のキーとは一致しない。

| 同梱版のキー | 個別版フォルダ | 個別版の `addon_name` | `author` |
| --- | --- | --- | --- |
| `monster_kill_count` | `klcount` | `KLCOUNT` | `norisan` |
| `continue_reinforce` | `continuerf` | `CONTINUERF` | `norisan` |
| `muteki` | `muteki2ex` | `muteki2ex` | **`WRIT`** |
| `instant_cc` | `instantcc` | `INSTANTCC` | **`ebisuke`** |
| `easy_buff` | `easybuff` | `EASYBUFF` | **`Kiicchan`** |
| `dungeon_rp_charger` | `dungeonrpcharger` | （要確認） | **`meldavy`** |
| `no_check` | `nocheck` | `NOCHECK` | `norisan` |
| `guild_event_warp` | `guildeventwarp` | `GUILDEVENTWARP` | `norisan` |

* **`author` は `norisan` だけではない**（`WRIT` / `ebisuke` / `Kiicchan` / `meldavy`）。
* 大文字・小文字も不統一（`ARCHEOLOGY_HELPER` と `always_status` が混在）。
* 39 個中 13 個ほどは `local addon_name =` の書式が違い機械抽出できなかった。
  **設定引き継ぎのパスを確定するときは個別に中身を読むこと。**

→ 検出・引き継ぎの情報は**宣言テーブルで持つしかない**（推測で導出できない）。

### 1-2. 競合検出と無効化は「既に実装済み」

[core/10_registry.lua](../nexus_addons_p/src/core/10_registry.lua) が全アドオンに
`old_init_func`（＝個別版の `ON_INIT` グローバル名）を持っている。**46 個が宣言済み**。

[core/20_lifecycle.lua:218-244](../nexus_addons_p/src/core/20_lifecycle.lua#L218-L244) が
`g.loaded` が偽のとき（＝初回）に全登録アドオンを走査し、`_G[old_init_func]` が
存在すれば次を行う。

1. 二言語のエラー文を `g.pending_messages` に積む
   （「競合する古いアドオン '%s' が検出されました / '%s' を無効化しました /
   dataフォルダから、古いアドオンのipfファイルを削除してください」）
2. `g.settings[key].use = 1` なら **`0` にして保存**（＝初期化されなくなる）

さらに [同 451-476](../nexus_addons_p/src/core/20_lifecycle.lua#L451-L476) の
`_nexus_addons_p_toggle_addons` が、**設定 UI から手動で再有効化するのもブロック**する
（`imcAddOn.BroadMsg` で通知）。

→ **ご要望の「エラー文と初期化停止」は、この経路で既に成立している。**
　 新規 2 アドオンも、登録リストに `old_init_func` を書けば同じ経路に乗る。

**注意点（既存の癖）**

* 無効化は `settings.json` に**永続化**される。利用者が後から個別版の `.ipf` を消しても
  `use = 0` のままなので、**設定 UI で明示的に有効化し直す必要がある**。
  検出が消えれば再有効化はブロックされないので操作自体は可能。
* 検出は `g.loaded` が偽のとき（初回のみ）に走る。

### 1-3. グローバル名は衝突しない（実測）

同梱時に norisan さんが既にリネームしており、**同梱版は先頭大文字**
（`Always_status_frame_init`）、**個別版は小文字**（`always_status_frame_init`）になっている。

16 組を実測した結果:

| 検査した組 | 衝突数 |
| --- | --- |
| always_status / auto_repair / bulk_sales / cc_helper 以外の 15 組 | **0** |
| `cc_helper` ↔ `cc_helper` | **1**（`Cc_helper_equip_card`） |

→ **読み込み時ガード（guard_open 相当のアドオン単位版）は不要**。
　 本家 `_NEXUS_ADDONS` に対して必要だったのは、本家と P が**同名**のグローバルを
　 定義するためであり、個別版はその前提に当てはまらない。
　 初期化時の停止だけで、個別版・同梱版のどちらも壊れない。

* 唯一の例外 `Cc_helper_equip_card` は、読み込み順で後勝ちになる潜在的な衝突。
  ただし同梱版側は `use = 0` で初期化されないため、実害は
  「個別版の `Cc_helper_equip_card` が同梱版の実装に差し替わる」ケースに限られる。
  **未検証。実機で cc_helper 個別版との併用を確認するときに併せて見ること。**

### 1-4. 設定の保存先の「形」が違う

```
個別版   : ../addons/always_status/settings.json          ← キャラ別フォルダ無し。ルート = その設定そのもの
同梱版   : ../addons/_nexus_addons_p/<AID>/settings.json  ← キャラ別。g.settings["always_status"] が該当箇所
本家     : ../addons/_nexus_addons/<AID>/settings.json    ← 同梱版と同一スキーマ
```

本家からの引き継ぎ [`g.migrate_from_origin`](../nexus_addons_p/src/core/00_header.lua#L134)
がフォルダ丸ごと `xcopy` で済むのは**本家とスキーマが同一だから**。個別版は

* キャラ別フォルダが無いものが多い
* ルート直下がそのアドオンの設定（同梱版の `g.settings[<key>]` に相当）
* フレームワークの `use` フラグを持たない
* 同梱後に追加・改名されたフィールドがある可能性がある

ため、**単純コピーでは移せない**。

### 1-5. 新規 2 アドオンは自己完結型

| | 行数 | `author` | `addon_name` | 個別版の入口 |
| --- | --- | --- | --- | --- |
| `market_favorite_rebuild` | 2,861 | `ebisuke` | `MARKET_FAVORITE_REBUILD` | `MARKET_FAVORITE_REBUILD_ON_INIT` |
| `mini_addons` | 7,225 | `norisan` | `MINI_ADDONS` | `MINI_ADDONS_ON_INIT` |

既存 48 アドオンと違い、**共有フレームワークを一切使わない**。
それぞれが自前で `local g = _G['ADDONS'][author][addon_name]` / `require('json')` /
`local ts` / 自分の XML フレーム / 自分の設定ファイルを持つ。

* `mini_addons` は **`norisan_menu_*` 共有メニューを自前で丸ごと実装している**
  （`_G["norisan"]["MENU"]`、`norisan_menu_frame`、`norisan_menu_frame_open` 等）。
  これは CLAUDE.md が「リネームしてはいけない」としている ride-along の待ち合わせ名そのもの。
* `market_favorite_rebuild` は `OPEN_DLG_MARKET` を掴み、マーケットの開閉自体を操作する。

---

## 2. 設計方針

### 2-1. 競合検出は既存経路に乗せる（新規実装なし）

新規 2 アドオンを登録リストに追加し、`old_init_func` に個別版の入口名を書く。

```lua
{ key = "market_favorite_rebuild",
  data = { use = 0, name = "Market Favorite Rebuild", frame_use = false,
           config_func = "", old_init_func = "MARKET_FAVORITE_REBUILD_ON_INIT" } },
{ key = "mini_addons",
  data = { use = 0, name = "Mini Addons", frame_use = false,
           config_func = "", old_init_func = "MINI_ADDONS_ON_INIT" } },
```

これだけで §1-2 の検出・エラー文・無効化・UI ブロックがそのまま効く。

**自己検出しないことの確認**: 同梱版のアドオンは大文字の `*_ON_INIT` を
**1 つも定義していない**（`grep -rE "^function [A-Z_]+_ON_INIT" src/addons/` が 0 件）。
入口は小文字の `<key>_on_init`。よって `_G["MINI_ADDONS_ON_INIT"]` が真になるのは
**個別版が実在するときだけ**。新規 2 アドオンを取り込むときは、
**個別版の入口名をそのまま残してはいけない**（§2-2 のリネーム対象に必ず含める）。

### 2-2. 新規 2 アドオンの取り込み方

**自己完結のまま同梱する。** 共有フレームワークへの書き換えはしない（約 1 万行の全面改修になり、
不具合リスクが見合わない）。

**リネームするもの（private）**

| 対象 | 変更 | 理由 |
| --- | --- | --- |
| `local addon_name` | `MARKET_FAVORITE_REBUILD` → `MARKET_FAVORITE_REBUILD_P` | 名前空間・設定パス・フレーム名が芋づるで分かれる |
| 入口 | `*_ON_INIT` → 同梱版の規約 `<key>_on_init` | §2-1 の自己検出回避。フレームワークから呼ばれるようにする |
| グローバル関数 | `market_favorite_rebuild_*` → 先頭大文字化など既存同梱版と同じ流儀 | 個別版との衝突回避 |
| XML の `*Scp` 参照名 | 上記リネームに追従 | 参照が切れるとボタンが無反応になる |

**リネームしないもの（ride-along）**

* `_G["norisan"]["MENU"]`
* フレーム名 `"norisan_menu_frame"`

`mini_addons` が持つ `norisan_menu_*` の**実装本体は削除する**。
まとめ版は [core/90_addons_menu.lua](../nexus_addons_p/src/core/90_addons_menu.lua) で
同じ役割を `addons_menu_*` として既に持っており、二重定義になるため。
`mini_addons` は自分の設定項目を `_G["norisan"]["MENU"]` に登録するだけにする。

**`.lua` の置き場**

> **【この節は撤回済み — 現在の方針は「配布 `.lua` は 1 本だけ」】**
> 下の既定方針（conclude へ連結）は、engine が `.lua` を**必ず main → conclude の順で
> 読む**という前提に立っていた。実際には読み込み順は同居する他アドオンの顔ぶれで変わり、
> conclude 側が読まれずに `mini_addons` / `market_favorite_rebuild` /
> `ancient_monster_bookshelf` の 3 つだけが丸ごと無効になる事故が起きた。
> このため `_nexus_addons_p_conclude.lua` は**ターゲットごと廃止**し、
> [conclude_scope_open.lua](../nexus_addons_p/src/conclude_scope_open.lua) /
> `conclude_scope_close.lua` で `do ... end` を作って `_nexus_addons_p.lua` 1 本に
> 取り込んである（詳細は [BUILD_IPF.md](BUILD_IPF.md#L24)）。
> **新しいアドオンも `_nexus_addons_p.lua` に連結すること。** 配布 `.lua` を
> 増やすと同じ事故が再発する。以下は当時の判断の記録として残す。

engine が配布パック内の `.lua` をどう読むかは確定していない。
[REFACTOR_SPLIT_DESIGN.md:23](REFACTOR_SPLIT_DESIGN.md#L23) は
「`_conclude.lua` は engine 規約で main の後に自動ロードされる」と書いているが、
**任意のファイル名を増やしても読まれるかは不明**。したがって:

* **既定方針**（撤回済み）: 新規 target を増やさず、実績のある
  `_nexus_addons_p_conclude.lua` に連結する。各アドオンは `do ... end` で囲み、
  ファイルスコープの `local`（`g` / `json` / `addon_name` / `ts`）を隔離する。
  囲んでもグローバル関数の定義には影響しない。
* 新規 `.lua` を増やす案は、**実機で読み込まれることを確認できてから**にする。

※ `do ... end` で `local` を隔離する部分だけは現在も有効で、1 本化した後も
そのまま使っている（隔離しないと `local` が 200 個上限に当たる）。

**XML は同梱しない（フレームはプログラム生成に変換する）** — 確定

個別版は全て `<addon>.lua` + `<addon>.xml` の 2 ファイル構成だが（`_replaced/` の 39 個すべて）、
**まとめ版のパックに入っている XML は `_nexus_addons_p.xml` 1 つだけ**で、
既存 48 アドオンは自分の XML を持っていない。取り込み時に

```lua
ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "<suffix>", x, y, w, h)
```

というプログラム生成に変換されている（`always_status` / `sub_map` / `indun_panel` で確認）。
新規 2 アドオンも同じ方式に変換する。利点は 2 つ:

* engine が複数 XML を読むかという**未確定事項を回避できる**（実例が存在しない）
* フレーム名に `addon_name_lower`（= `_nexus_addons_p`）接頭辞が付くため、
  **個別版のフレームと衝突しない**

変換対象:

| 元 XML | 内容 | 変換 |
| --- | --- | --- |
| `mini_addons.xml` | 空のホストフレームのみ | フレーム生成 1 行に置換 |
| `market_favorite_rebuild.xml` | 380x610 の実ウィンドウ（`headerBox` / `xBtn` / `headerText`） | コントロールもプログラム生成に起こす |

なお `market_favorite_rebuild.xml` の `xBtn` は `LBtnUpScp="MARKETFAVORITE_CLOSE"` を参照するが、
**この関数は lua 側に存在しない**（upstream 由来の壊れた参照＝閉じるボタンが無反応）。
P 側で直すかはこの設計の範囲外とし、**現状の挙動を変えない**。

### 2-3. 設定引き継ぎ（新規に作る部分）

登録リストに個別版の設定情報を宣言し、共通関数で引き継ぐ。

```lua
old_settings = {
    path = "../addons/always_status/settings.json",  -- 個別版の保存先
    per_char = false,                                -- キャラ別フォルダの有無
    adapter = "",                                    -- スキーマがずれている場合のみ指定
}
```

**引き継ぎ手順**

1. 引き継ぎ済みマーカーが無いときだけ動く。マーカーは**同梱版の `settings.json`
   （キャラ別）に持つ**ので、キャラごとに 1 回だけ走る。
2. 宣言された個別版のパスを読む。無ければ何もしない。
3. **既定値の上にマージする**（丸ごと差し替えない）。同梱版で後から増えたフィールドが
   既定値のまま残るようにするため。
4. フレームワーク側のフィールド（`use` など）は**同梱版の値を優先**する。
   個別版は `use` を持たないので、これを上書きさせると意図せず無効化されうる。
5. 結果をマーカーとともに保存する。

**設計上の要点**

* **既存の設定を絶対に壊さない。** 条件は CLAUDE.md の本家引き継ぎ (B) と同じ思想
  （「自分側に無いときだけ」）。マーカー方式にするのは、同梱版の `g.settings[<key>]` が
  登録リストの既定値で**常に存在してしまう**ため、「無い」で判定できないから。
* 個別版はキャラ別でないものが多いため、**1 つのファイルが全キャラの初期値になる**。
  種として使う分には妥当と判断する。
* 個別版の `.ipf` を消しても**設定ファイルは残る**。よって
  「個別版を消す → 同梱版を有効化」の流れでも引き継ぎが効く。むしろこれが主経路。
* `_nexus_addons_p_load_settings` は未知キーを刈るので、
  **マージは同梱版の既定スキーマに存在するキーだけ**に限定する。

### 2-4. ログ

CLAUDE.md の方針どおり `g.vlog` に判断材料を出す。

* 個別版を検出したか（検出したキー名と、真になった `old_init_func`）
* 引き継ぎを実行したか／スキップしたか（マーカー有無・ソースファイルの有無）
* マージしたキー数

毎フレーム走る経路ではないので、絞り込みは不要。

---

## 3. 段階計画

### フェーズ 1 — 共通基盤 + 新規 2 アドオン

当初はフェーズ 2 で「読み込み時ガード + ビルド改造」を予定していたが、
§1-3 の実測により**不要と判明したため取り下げる**。

1. `market_favorite_rebuild` / `mini_addons` を `src/addons/<key>/` に配置し、§2-2 のリネームを行う
2. 登録リストにエントリを追加（`old_init_func` 込み）
3. `build_manifest.json` の `_nexus_addons_p.lua` に `do ... end` で囲んで追加
   （当時は conclude 側に足していたが、conclude は廃止済み。§2-2 の枠を参照）
4. 設定引き継ぎの共通関数と宣言を実装（まず新規 2 アドオンに適用）
5. bundle 再生成（`--bless`）→ 構文チェック（WSL luajit）
6. **実機確認**: `verbose_log.txt` で「個別版検出」「引き継ぎ」の分岐を確認

### フェーズ 2 — 既存 39 アドオンへ設定引き継ぎを展開

1. 個別版 39 個の `addon_name` / 保存先を**個別に読んで確定**（§1-1 の未確定 13 個を含む）
2. 登録リストに `old_settings` を追記
3. スキーマがずれているものだけ adapter を書く
4. 実機確認

競合検出（エラー文 + 初期化停止）は既存実装で全 46 アドオン分が既に効いているため、
フェーズ 2 の対象は**設定引き継ぎのみ**。

---

## 4. リスク・未決事項

### リスク

| # | 内容 | 対応 |
| --- | --- | --- |
| 1 | engine が任意名の `.lua` を読むか不明 | ~~conclude に連結する既定方針で回避~~ → **顕在化した**。順序も保証されず conclude 側が読まれない事故が起きたため、配布 `.lua` を 1 本に統合して解消（§2-2 の枠） |
| 2 | `mini_addons` の `norisan_menu_*` 二重定義 | 実装本体を削除し登録のみにする（§2-2）。**ride-along 名は変えない** |
| 3 | `Cc_helper_equip_card` の名前衝突 | 実害は限定的だが未検証。cc_helper 個別版併用時に確認（§1-3） |
| 4 | 引き継ぎで既存設定を壊す | マーカー方式 + 既定値へのマージ + `use` は同梱版優先（§2-3） |
| 5 | 約 1 万行の新規取り込みによる不具合 | 自己完結のまま入れて改修を最小化。実機ログで経路確認 |

### 未決事項

* ~~engine の `.lua` ロード規約（実機で確認する）。
  ただし §2-2 の既定方針（conclude へ連結）を採る限り**着手の前提にはならない**。~~
  → **解決**: 実機で「複数 `.lua` は読まれるが順序が保証されない」ことが判明した。
  配布 `.lua` を 1 本にしたので、この規約に依存する箇所は無くなった。
* `mini_addons` の各機能を設定 UI にどう出すか（自前の設定フレームを持つため、
  まとめ版の一覧に 1 項目として出すのか、機能ごとに出すのか）

### 解決済み（調査で確定）

| 事項 | 結論 |
| --- | --- |
| XML フレームの扱い | **同梱しない**。`ui.CreateNewFrame` に変換する（§2-2） |
| 個別版とのグローバル名衝突 | 実測で**ほぼゼロ**。読み込み時ガードは不要（§1-3） |
| 競合検出の実装要否 | **既に実装済み**。新規 2 アドオンは登録するだけ（§1-2、§2-1） |
