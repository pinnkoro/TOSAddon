# Nexus Addons ソース分割リファクタ設計（方式A：ソース分割＋ビルド時連結）

## 0. 方針（3行）

- 49 アドオンを **1 アドオン = 1 ファイル**に分割する。`_replaced/` は対象外。
- 配布実体（`.ipf` 内の bundle 2 ファイル）は**現状と完全同一（byte-identical）を維持**する。実行時のロード挙動・初期化順序は一切変えない。
- 変えるのは「人間が編集するソースの物理配置」だけ。ビルド時に現行の 2 ファイルへ**単純連結**して生成する。

---

## 1. 現状構造（調査で確定した事実）

配布実体は 2 つのコードファイル：

| ファイル | 行数 | 内容 |
| --- | --- | --- |
| `nexus_addons_p/_nexus_addons_p/_nexus_addons_p.lua` | 29,760 | コア + 48 アドオン + 共有メニュー |
| `nexus_addons_p/_nexus_addons_p/_nexus_addons_p_conclude.lua` | 998 | ヘッダ + `ancient_monster_bookshelf` 1 アドオン |
| `nexus_addons_p/_nexus_addons_p/_nexus_addons_p.xml` | 8 | フレーム定義（分割対象外） |

分割が成立する根拠（既に実証済み）：

1. **engine は複数 lua を読む**。`_conclude.lua` は engine 規約で main の後に自動ロードされる。実際 `ancient_monster_bookshelf` が 1 アドオンまるごと conclude に入っており、登録リストからは**グローバル名で参照**されている。＝「1 アドオン = 別ファイル」は既に本番稼働中。
2. **アドオンは疎結合**。登録リスト `g._nexus_addons_p` に `key` を列挙するだけ。実処理はグローバル関数 `<key>_on_init` を `_G[key.."_on_init"]` で名前引き（[_nexus_addons_p.lua:1167-1177](../nexus_addons_p/_nexus_addons_p/_nexus_addons_p.lua#L1167-L1177)）。連携は共有 `g` テーブルとグローバル関数経由のみ。
3. **境界が既にマーカーで明示されている**。main には `-- <name> ここから` / `-- <name> ここまで` が **48 組**存在し、各アドオンブロックを完全に区切っている。conclude 側も `ancient_monster_bookshelf ここから/ここまで` あり。

### main の内訳（行範囲）

| 区分 | 行 | 内容 |
| --- | --- | --- |
| コア先頭 | 1–337 | ヘッダコメント / `addon_name`・`g`・`json` / `ts`・`print_all_child` / `g.*` 基盤ヘルパ（mkdir, save/load_lua/json, get_map_type, log_to_file 等） |
| 登録データ | 338–1027 | `g._nexus_addons_p`（登録リスト 338–780）+ `g._nexus_addons_p_trans`（多言語ヘルプ 781–1027） |
| ライフサイクル | 1028–1488 | save/load settings, `_NEXUS_ADDONS_P_ON_INIT`, `init_addons`, async, frame_init/list/toggle, `GAME_START`, `update_frames`, `APPS_TRY_MOVE_BARRACK` |
| アドオン 48 ブロック | 1489–29401 | 各 `ここから`〜`ここまで`。出現順：always_status, indun_panel, cc_helper, …, bulk_sales |
| コア末尾 | 29403–29760 | `norisan_menu` 共有メニューシステム（登録アドオンではない） |

### conclude の内訳

| 区分 | 行 | 内容 |
| --- | --- | --- |
| ヘッダ | 1–27 | `addon_name`・`g`・`json`・`ts` の**再宣言**（別ファイル＝別スコープのため必須） |
| アドオン | 28–998 | `ancient_monster_bookshelf` |

---

## 2. 目標ファイルレイアウト

```
nexus_addons_p/
  _nexus_addons_p/                       ← ビルド成果物置き場（.ipf に入るのはここ）
    _nexus_addons_p.lua                  (生成 ← .gitignore)
    _nexus_addons_p_conclude.lua         (生成 ← .gitignore)
    _nexus_addons_p.xml                  (手書き／追跡継続・分割対象外)
  src/                                 ← 新設。今後の編集はここだけ
    core/
      00_header.lua                    (main 1–337)
      10_registry.lua                  (main 338–1027)
      20_lifecycle.lua                 (main 1028–1488)
      90_norisan_menu.lua              (main 29403–29760)
    addons/
      always_status.lua                (main 1489–2511)
      indun_panel.lua                  (main 2512–…)
      cc_helper.lua
      …  ← 48 ファイル（main 由来、ここから〜ここまで を含めて切り出す）
      ancient_monster_bookshelf.lua    (conclude 28–998)
    conclude_header.lua                (conclude 1–27)
  build_manifest.json                  ← 連結順を明示
```

### git 追跡ポリシー（確定）

- **無視する（生成物）**：`nexus_addons_p/_nexus_addons_p/_nexus_addons_p.lua`、`nexus_addons_p/_nexus_addons_p/_nexus_addons_p_conclude.lua` の 2 ファイルのみ。
- **追跡を継続**：`nexus_addons_p/_nexus_addons_p/_nexus_addons_p.xml`（手書き）、配布 `.ipf`（`nexus_addons_p/_nexus_addons_p-⛄-*.ipf` および `etc/`）、`nexus_addons_p/src/**`、`build_manifest.json`。
- `.gitignore` 追記例：
  ```gitignore
  /nexus_addons_p/_nexus_addons_p/_nexus_addons_p.lua
  /nexus_addons_p/_nexus_addons_p/_nexus_addons_p_conclude.lua
  ```
  ワイルドカード（`*.lua`）は使わない — `.xml` を巻き込まず、生成 2 ファイルだけをピンポイントで無視する。
- 移行時に一度 `git rm --cached` で追跡から外す（ワーキングツリーには残す。ビルドで再生成される）。
- **本リファクタ後の "source of truth" は `nexus_addons_p/src/**`**（従来は bundle `_nexus_addons_p.lua`）。関連メモの更新が必要（[[nexus-addons-source-of-truth]]）。

---

## 3. ビルド（連結）設計

新スクリプト `docs/bundle_nexus_src.py`（仮）：

1. `build_manifest.json` の順に `src/**/*.lua` を読む。
2. **各ファイルの中身をそのまま（マーカーコメント込み）改行区切りで連結**し、`_nexus_addons_p.lua` を生成。
3. 同様に conclude 側（`conclude_header.lua` + `ancient_monster_bookshelf.lua`）を連結し `_nexus_addons_p_conclude.lua` を生成。
4. 生成後、**現行 bundle と `cmp` でバイト一致**を検証（§6）。
5. 一致したら既存の `build_addon_ipf.py` で `.ipf` 化。

連結順（manifest）：

```jsonc
{
  "targets": {
    "_nexus_addons_p.lua": [
      "core/00_header.lua",
      "core/10_registry.lua",
      "core/20_lifecycle.lua",
      "addons/always_status.lua",
      "addons/indun_panel.lua",
      "…(現在の出現順で 48 個)…",
      "addons/bulk_sales.lua",
      "core/90_norisan_menu.lua"
    ],
    "_nexus_addons_p_conclude.lua": [
      "conclude_header.lua",
      "addons/ancient_monster_bookshelf.lua"
    ]
  },
  // 各ターゲットの golden ハッシュ。連結結果がこれと一致しなければ生成/検証を失敗
  // させる（CRLF 混入・src 誤編集の検知）。意図した変更時は --bless で更新する。
  "sha256": {
    "_nexus_addons_p.lua": "…",
    "_nexus_addons_p_conclude.lua": "…"
  }
}
```

**アドオンの連結順は現状の出現順を厳守**する（初回のバイト一致検証を通すため）。連結は「切り出した断片を元位置に戻す」だけなので、原理的に元ファイルと一致する。

---

## 4. スコープ／preamble の扱い（重要）

- **main 側は連結後に 1 ファイルへ戻る**ため、各 `addons/*.lua` に preamble は**不要**。`local g` / `ts` / `addon_name` / `json` は `00_header.lua` 由来のスコープを全体で共有する（現状と完全に同一）。
- ただし src 上で `addons/xxx.lua` 単体を開くと `local` 参照が宙に浮いて見える（lint 上のエラー）。これは「**連結前提の断片**」であることを設計として明記する。各アドオンファイル単体では構文的に閉じていない（＝これは仕様）。
- **conclude 側は engine が別ファイルとしてロードする＝別スコープ**なので、`conclude_header.lua` に `local` 再宣言（現状の 1–27 行）を必ず残す。ここだけは連結後もスコープが独立する。

---

## 5. 分割アルゴリズム（1 回限りの切り出しもスクリプト化）

手作業でコピペしない。可逆性を担保するため**分割もスクリプト**で行う：

- 入力：現行 `_nexus_addons_p.lua` / `_conclude.lua`。
- 規則：
  - 先頭〜最初の `ここから`（1489 直前）→ `core/00_header` + `10_registry` + `20_lifecycle` に規定行で分割（境界 337 / 1027 / 1488 は固定値）。
  - `-- <name> ここから` 〜 対応する `-- <name> ここまで`（マーカー行を含む）→ `addons/<name>.lua`。ファイル名は登録リストの `key` に正規化（マーカー表記ゆれ `Instant CC` / `ndun_list_viewer` 等は key 対応表で吸収）。
  - 共有メニュー先頭アンカー行（`-- アドオンメニューボタン`、bundle 内で一意）以降 → `core/90_norisan_menu.lua`。行番号ではなくこの行内容から境界を導出する（bundle が伸縮しても追従。旧版では 29403 行目）。
  - conclude：1–27 → `conclude_header.lua`、28–998 → `addons/ancient_monster_bookshelf.lua`。
- 逆変換（§3 の連結）で **cmp 一致するまで境界を調整**。一致した時点で分割ロジックの正しさが機械的に証明される。

> マーカー表記ゆれ（例：`-- Instant CC ここから` ↔ key `instant_cc`、`-- ndun_list_viewer`（誤字）↔ `indun_list_viewer`、全角スペース混在）は分割スクリプト内の key 対応表で吸収する。表記自体は**書き換えない**（バイト一致維持のため）。

---

## 6. 検証（受け入れ条件）

1. **byte-identical rebuild（必須・初回）**：`src → 連結` で生成した `_nexus_addons_p.lua` / `_conclude.lua` が、リファクタ前の bundle と `cmp` で完全一致すること。
   - 一致 ⇒ 分割は無損失（境界ミス・行の欠落／重複・改行差は即検出）。これが本リファクタ唯一かつ十分な正しさ証明。
   - **以降の恒常ガード**：この一致時のハッシュを `build_manifest.json` の `sha256` に固定し、`bundle_from_src.py` が生成/`--check` のたびに照合する。旧 bundle は `.gitignore`（＝リポジトリに golden が残らない）ため、`--check` は既存 bundle ではなくこの sha を正とする。CRLF 混入・src 誤編集で sha がズレたら失敗。**改行は `.gitattributes` の `*.lua text eol=lf` で LF 固定**。意図した変更のときだけ `python docs/bundle_from_src.py --bless` で sha を更新する。
   - **脱落ガード**：`src/**` の実 `.lua` 集合と manifest の parts 集合が一致しなければ失敗（新規追加を manifest に書き忘れると黙ってビルドから消えるのを防ぐ）。
2. `.ipf` 化後、既存の往復検証（復号 → extract → `cmp`、[BUILD_IPF.md](BUILD_IPF.md) §4）を通す。
3. Lua 構文は処理系が無いため実機テスト（現状と同じ）。ただし §6-1 が通れば「生成物は現行とバイト同一」なので、リファクタ自体による退行はロジック上あり得ない。

---

## 7. 移行手順（初回）

1. `src/` 骨組みと `build_manifest.json` を作成。
2. 分割スクリプトで現行 bundle を `src/**/*.lua` へ切り出す（§5）。
3. 連結スクリプトで再結合 → **cmp 一致を確認**（ズレたら §5 の境界を修正）。
4. 一致確定後、`.ipf` を再ビルドして往復検証（§6-2）。バージョンは据え置き（ロジック変更なしのため）か、体制変更を示す軽微 bump かは運用判断。
5. 以降の編集は `src/` のみ。リリース時フロー：`src 編集 → 連結 → ipf 化 → 検証 → addons.json fileVersion 更新 → nexus_addons_p/README.md の更新履歴追記`（[CLAUDE.md](../CLAUDE.md) 規約）。

---

## 8. リスク・留意点

- **`.ipf` の byte 一致（level 6）は維持**：連結結果が現 bundle と同一 ⇒ `build_addon_ipf.py` の入力も同一 ⇒ 出力 `.ipf` も同一。
- **新規アドオン追加時**：`src/addons/<key>.lua` を追加 + `core/10_registry.lua` に登録 + `build_manifest.json` の `targets` に追記（脱落ガードにより追記漏れは即エラー）。挙動が変わるので初回のバイト一致制約からは解放されるが、恒常ガードの sha はズレるため `python docs/bundle_from_src.py --bless` で golden を更新すること。
- **conclude を使う理由の温存**：`ancient_monster_bookshelf` を conclude 側に残すか main に取り込むかは、現状の load 順依存があるため**現状維持**（conclude のまま）を推奨。動かす場合は別途実機検証が要る。
- **xml は分割しない**。
- **CI 化余地**：`分割検証 → 連結 → ipf 化 → 往復検証` をワンショット化できる。

---

## 9. 決定事項

- [x] **アドオン数 = 49**（48 in main + 1 in conclude）で進める。
- [x] 生成物 `_nexus_addons_p.lua` / `_nexus_addons_p_conclude.lua` は **`.gitignore`**（§2「git 追跡ポリシー」）。
- [x] `src/` の配置は **`nexus_addons_p/src/`**。
- [x] アドオンファイル名は登録 `key`（例 `indun_panel.lua`）で統一。
- [x] 分割/連結スクリプトは **Python**（既存 `docs/build_addon_ipf.py` に合わせる）。
