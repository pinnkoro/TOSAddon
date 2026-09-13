---
paths:
  - "nexus_addons_p/src/core/**/*.lua"
  - "nexus_addons_p/src/guard_*.lua"
---

# core / ガードを触るとき

ここは全アドオンの土台なので、壊すと 1 本ではなく全部が落ちる。

* **`guard_open.lua` / `guard_close.lua` の連結順に依存している。**
  `addons/**` 全体を `if not g.detect_origin_addon() then ... end` で囲む作りなので、
  `build_manifest.json` の順序を触るときは必ず **[docs/COEXIST.md](../../docs/COEXIST.md)** を読む。
* **`core/90_addons_menu.lua` はガードの外**（本家が居ても定義される）。ここだけ関数名を
  `addons_menu_*` にリネームしてある。ただし `_G["norisan"]["MENU"]` と
  フレーム名 `"norisan_menu_frame"` は**リネームしてはいけない**（他アドオンとの待ち合わせ名）。
* **`settings.json` のトップレベルにキーを足したら `valid_keys` にも足す。**
  書き忘れると毎回プルーニングで消える。
* **`g.migrate_from_origin()` は「自分側に settings.json が無いとき」だけ走らせる。**
  条件を緩めると既存の設定を本家の古い設定で上書きする。
* **`core/92_icon_names.lua` は生成物**。手で編集せず `python docs/gen_icon_names.py` で作り直す。
* **`local function` は呼び出しより前で定義する** → **[docs/CODING_RULES.md](../../docs/CODING_RULES.md)**

`00_header.lua` の `ver` は**リリース時（`release-prep/**` ブランチ）にしか上げない**
→ **[docs/RELEASE.md](../../docs/RELEASE.md)**
