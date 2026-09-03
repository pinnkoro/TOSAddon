# 新しいアドオンを追加する手順

アドオンを 1 本足すと、**コードのほかに 5 か所へ登録が要る**。どれか 1 つ抜けると
「一覧に出ない」「毎回設定が消える」という形になり、**大半は実機で触るまで気付けない**
（機械で止まるのは manifest の登録漏れだけ。§1-4）。手順と、実際に踏んだ罠をここにまとめる。

2026-09-03 に `party_icon_only` を追加したときの流れが元。

---

## 0. 最初に決めること

| 決めるもの | 制約 |
| --- | --- |
| **キー** (`party_icon_only`) | 小文字 + `_`。**設定 JSON のキーであり、フォルダ名であり、関数名の接頭辞**。後から変えると利用者の設定が消えるので、**一度決めたら変えない** |
| **表示名** (`Party Icon Only`) | 一覧に出る名前。英字。カテゴリ内はこの名前のアルファベット順に並ぶ |
| **カテゴリ** | `g._nexus_addons_p_sections` の `name` のどれか（`storage` / `gear` / `battle` / `content` / `char` / `misc`） |
| **設定画面を持つか** | 持つなら `config_func` に関数名、持たないなら `""` |

---

## 1. 触るファイル（5 か所 + コード）

### 1-1. `nexus_addons_p/src/addons/<key>/<key>.lua` — 本体

`function <key>_on_init()` が入口。**core が全アドオン分を呼ぶ契約**で、
マップ移動のたびに走る。

```lua
function party_icon_only_on_init()
    if g.settings.party_icon_only.use == 0 then
        return
    end
    ...
end
```

* **`on_init` は ON / OFF によらず呼ばれる。** OFF のときの後始末を
  `function <key>_on_teardown()` に書くと、`use == 0` のとき core が
  `on_init` の代わりにそちらを呼ぶ（[core/20_lifecycle.lua](../nexus_addons_p/src/core/20_lifecycle.lua)
  の `_nexus_addons_p_resolve_init_func`）。opt-in なので、定義しなければ従来どおり
  `on_init` が呼ばれる。
* **`on_teardown` は「一度も ON にしていない利用者」にも 1 回呼ばれる**（§3 の罠を参照）。

### 1-2. `nexus_addons_p/src/addons/<key>/README.md` — 利用者向け

**必須**。配布 README の一覧から `src/addons/<key>/README.md` へリンクするので、
無いとリンク切れになる。既存のもの（[party_icon_only](../nexus_addons_p/src/addons/party_icon_only/README.md)
が一番新しい）に倣って、次を書く。

`# 表示名` / 一行の説明 / 諸元の表（キー・ソース・設定画面の有無・原作者）/
`## 使い方` / `## しくみ` / `## 保存先` / `## 注意`

### 1-3. `nexus_addons_p/src/core/10_registry.lua` — 登録（2 か所）

**エントリ**（`g._nexus_addons_p`）:

```lua
    key = "party_icon_only",
    category = "battle",
    since = g.VER_NEXT,          -- NEW の印。**採番するまでは g.VER_NEXT**
    data = {
        use = 0,                 -- 既定は OFF
        name = "Party Icon Only",
        frame_use = false,       -- 一覧に「窓を開く」ボタンを出すか
        config_func = "",        -- 設定画面の関数名。無ければ ""
        old_init_func = ""       -- 競合する旧個別版アドオンの ON_INIT 名。新規は ""
    }
```

* `since` / `updated` は **`data` の中ではなくエントリ側**に書く。`data` はそのまま
  `settings.json` へ写され、既定に無いキーはプルーニングで消える。
* `old_init_func` は「**個別配布されている旧版**が同じ名前を公開していたら自分を無効化する」
  判定に使う（`core/20_lifecycle.lua` の `_nexus_addons_p_origin_addon_present`）。
  **本家の検出はこれとは別経路**で、`guard_open.lua` / `guard_close.lua` の
  `g.detect_origin_addon()` と `_NEXUS_ADDONS_P_ON_INIT` が担う（CLAUDE.md の
  「本家との共存対策」）。**新規アドオンには対応する旧版が無いので `""`**。

**説明**（`g._nexus_addons_p_trans`）: `ja` / `etc` / `kr` の 3 言語。改行は `{nl}`。

### 1-4. `nexus_addons_p/src/build_manifest.json` — 連結順

`targets` の `_nexus_addons_p.lua` の配列へ 1 行足す。**`guard_open.lua` と
`guard_close.lua` の間**（他のアドオンが並んでいるところ）。

* **足し忘れは機械で止まる。** `bundle_from_src.py` が「manifest 未登録の src ファイル」を
  検出して失敗する（CI の `bundle` ジョブでも走る）。この 5 か所のうち、**抜けをその場で
  教えてくれるのはここだけ**。
* `mini_addons` / `market_favorite_rebuild` は conclude スコープ（後ろのブロック）に
  居る。**普通の新規アドオンは前のブロックへ**。

### 1-5. `nexus_addons_p/README.md` — 一覧と更新履歴（2 か所）

* **アドオン一覧**の、カテゴリに対応する `###` 見出しの下へ 1 行:
  `| [表示名](src/addons/<key>/README.md) | 概要 |`
  **[docs/tests/test_core.lua](tests/test_core.lua) の [27] が検査する**ので、
  節を間違えるとテストが落ちる。
* **更新履歴**の `* **（次回リリース）**` へ追記（CLAUDE.md のルール）。

---

## 2. 窓を作るなら（共通部品）

新しく UI を出すときは、**必ず**次を通す。どれも忘れると実機でしか分からない壊れ方をする。

| やること | 呼ぶもの | 忘れるとどうなるか |
| --- | --- | --- |
| 裏抜け防止 | `g.block_click_through(frame)` | 窓の余白を押すとキャラが歩き出す。[check_frame_hittest.py](check_frame_hittest.py) が検出 |
| ESC で閉じる | `g.esc_register` 系 | ESC が完全に無反応。**× ボタンと同じ後始末を通すこと** |
| 位置決め | `g.settings_frame_pos(w, h)` | 素で `list_frame:GetX()` を呼ぶと、Addons Menu から開いたとき nil で落ちて空の窓が出る |
| 検索欄 | `g.setup_incremental_search` / `g.setup_enter_search` | 「×」が出ない・打鍵で全件を組み立てて固まる |

詳細は [CLAUDE.md](../CLAUDE.md) の各節に判断基準まで書いてある。

---

## 3. 罠（このリポジトリで実際に踏んだもの）

### `<key>_on_teardown` は「一度も ON にしていない利用者」にも 1 回呼ばれる

`use == 0` のときセッションに 1 回必ず呼ばれる契約なので、**既定 OFF のまま使っていない
利用者の環境でも走る**。素の UI を戻す処理をそのまま書くと、関係の無い人の画面を
毎セッション 1 回いじることになる。

**「自分が実際に手を入れたか」の印を持ち、立っていなければ何もしないこと。**

```lua
function Party_icon_only_restore()
    if not g.party_icon_only_folded then
        return
    end
    ...
```

### `local` は宣言行より後ろからしか見えない

src を分割しているぶん前後関係が見えづらい。設定の読み込み関数がファイル後方の
定義テーブルを引きたい、というのはよく起きる。**ファイル上部で前方宣言して、
下で代入する**（`local A, B` → 後で `A = {...}`）。

グローバル関数（`function Foo()`）は実行時に引くので前後を気にしなくてよい。
検出は [check_forward_refs.py](check_forward_refs.py)（**連結後の bundle に対して**行う）。

### 同じ素の関数へ複数のアドオンからフックを重ねない

`g.setup_hook` の控え（`_REPLACE_<名前>`）は**名前ごとに 1 つ**。同じ素の関数に
2 本目を掛けると、後から掛けた側も「素」を控えることになり、**先に掛けていた
アドオンの処理が黙って落ちる**。

掛ける前に `grep -rn "setup_hook.*<関数名>" nexus_addons_p/src/` で先客を確かめる。
先客が居るなら、別のフック先を探すか、素の別経路（メッセージ）を使う。

### 素のフレームを他のアドオンと取り合わない

`partyinfo` のように**複数のアドオンが同じ素のフレームを触る**ことがある。
`mini_addons` は 5 秒ごとの更新から `partyinfo` の大きさを戻すので、
こちらが畳んでもすぐ広げ直されていた。

* 取り合いになる相手が同梱アドオンなら、**相手側に「こちらが ON なら何もしない」
  分岐を入れる**のが一番確実（`core_g.settings.<key>.use == 1` で見られる）。
* 素の関数が値を書き戻す経路（`Resize` など）は、**置換方式フックで同期に**畳み直す。
  メッセージ経由だと配信の順によっては素の書き戻しより先に来る。

### フレームを破棄する経路は 1 つとは限らない

窓を 2 枚（本体 + 設定など）持つと、**片方を破棄する経路すべてでもう片方も畳む**
必要がある。`indun_panel` は 3 か所（アドオン OFF / フィールドで非表示 / 挑戦マップの検出）
あり、2 か所しか直していなくて設定ウィンドウだけが画面に残った。

破棄する箇所を増やしたら、**コメントに「全部で n か所」と書いておく**。

### 設定 JSON のキーに数字だけの文字列を使わない

`"520"` のようなキーは、実装によっては配列と取り違えられる。`lv520` のように
接頭辞を付ける。

---

## 4. 検証（コミット前に全部通す）

```bash
# bundle を作り直す（--bless は golden sha を更新するだけで書き出さないので、必ず 2 回）
python docs/bundle_from_src.py --bless
python docs/bundle_from_src.py            # "wrote ... (CHANGED)" を確認

python docs/check_forward_refs.py         # 連結後の前方参照
python docs/check_frame_hittest.py        # 窓の裏抜け
python docs/check_version_freeze.py       # 版を上げていないこと
python docs/vanilla_api.py --check        # 素の API の使い方が一覧と一致するか

# 素の API を新しく使い始めたら
#   **クライアントを終了してから流すこと。** vanilla_api.py は data/ の素の .ipf を
#   素の open() で読むが、ゲーム起動中は data/addon.ipf がロックされていて
#   PermissionError で止まる（2026-09-03 に実測。--verify-client / --update の両方）
python docs/vanilla_api.py --verify-client   # **先にこれ**
python docs/vanilla_api.py --update

# Lua の構文と純ロジックのテスト（WSL の luajit）
luajit -e "assert(loadfile('nexus_addons_p/_nexus_addons_p/_nexus_addons_p.lua'))"
for f in docs/tests/test_*.lua; do luajit "$f" | tail -1; done
```

### 実機で試す

```bash
python docs/build_addon_ipf.py ./nexus_addons_p _nexus_addons_p \
    "<スクラッチ>/_nexus_addons_p-⛄-vX.Y.Z-dev.ipf" \
    --require _nexus_addons_p/_nexus_addons_p.lua --encrypt
```

* **ファイル名に `-⛄-`（⛄ = U+26C4）が入っていないと読み込まれない。**
  2026-08-21 に実測: 中身が同じでも `test_addon-dev.ipf` は読み込まれず（初期化のチャットも
  出ない）、`test_addon-⛄-v1.0.0.ipf` へ改名したらそのまま読み込まれた。
  配布物は `<名前>-⛄-vX.Y.Z.ipf`、テスト用は**その後ろへ** `-dev` を足す
  （`_nexus_addons_p-⛄-v2.3.1-dev.ipf`）。`-dev` を足しても `-⛄-` は残るので読み込まれる。
* ゲームの `data\` 直下へコピーする。**nexus 系は常に 1 本だけ**にする
  （2 本あると二重に読み込まれる）。
* **コピー前にクライアントを終了する**（起動中はロックされて失敗する）。
* 詰めた `.lua` を取り出して bundle とバイト比較すること。`--bless` だけで
  bundle を作り直し忘れると、**古い中身が入った .ipf を気付かず配ることになる**。

**直した経路を実機のログで確かめる。** `g.vlog(fmt, ...)` を仕込み、設定画面の
「詳細なログをシステムに出力する」を ON にして `../addons/_nexus_addons_p/verbose_log.txt`
を読む。調査が終わってもログは消さない（CLAUDE.md の該当節）。

---

## 5. PR を出す

* テンプレート付きの URL から作る（素で作ると本文が空のまま通る）:
  `https://github.com/pinnkoro/TOSAddon/compare/main...<branch>?template=feature.md&expand=1`
* **版番号は上げない。** 採番は公開直前の `release-prep/vX.Y.Z` だけ。
* 見た目を変えたなら**スクリーンショット撮り直しの Issue** を作り、
  **PR 本文に番号を書く**。alt テキストの更新は PR の中で行う。
* レビューの指摘は**インラインコメントと PR 本体のコメント欄の両方**を見る。
  差分に無い行への指摘はコメント欄にしか出ない。

---

## 6. 早見表

新規アドオン 1 本で触るもの:

```
nexus_addons_p/src/addons/<key>/<key>.lua      新規
nexus_addons_p/src/addons/<key>/README.md      新規
nexus_addons_p/src/core/10_registry.lua        エントリ + 説明(3 言語)
nexus_addons_p/src/build_manifest.json         連結順に 1 行
nexus_addons_p/README.md                       一覧に 1 行 + 更新履歴
docs/vanilla_api.json                          素の API を使い始めたら
```
