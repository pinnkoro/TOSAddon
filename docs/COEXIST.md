# 本家との共存対策（壊さないこと）

本家 [Nexus Addons](https://github.com/ajinorisan/TOSAddon-public) と同時にインストールされても
互いを壊さないための仕組みと、触るときの注意。入口は [CLAUDE.md](../CLAUDE.md)。

## 本家との共存対策（壊さないこと）

本家と同名のグローバル関数（`Always_status_*` / `Indun_panel_*` など）は**意図的にリネームしていない**。
そのため両方インストールされていると、後から読み込まれた側が先の側を上書きして壊す。これを次の 2 段構えで防いでいる。

* **読み込み時ガード** — `nexus_addons_p/src/guard_open.lua` / `guard_close.lua` が
  `addons/**` 全体を `if not g.detect_origin_addon() then ... end` で囲む。本家が先に読み込まれていれば
  アドオン本体を一切定義しない。build_manifest の連結順に依存しているので、順序を触るときは注意。
* **起動時ガード(A)** — `core/20_lifecycle.lua` の `_NEXUS_ADDONS_P_ON_INIT` / `_nexus_addons_p_GAME_START` が
  本家を検出したら全初期化をスキップし、削除を促すメッセージだけ出す。

**設定引き継ぎ(B)** は `core/00_header.lua` の `g.migrate_from_origin()`。
実行条件は「自分側に `settings.json` が無い」= 実質初回起動時のみ。
既に自分の設定があるときに走らせると本家の古い設定で上書きしてしまうので、この条件は必ず守ること。

### 例外: アドオンメニューボタン（`core/90_addons_menu.lua`）

このファイルは連結順で `guard_close.lua` の**後**＝読み込み時ガードの外にあり、本家が居ても定義される。
そのため同名グローバルだと確実にぶつかるので、ここだけは関数名を `addons_menu_*` に**リネームしてある**。
設定も `../addons/_nexus_addons_p/<AID>/addons_menu.json` に移し、旧 `../addons/norisan_menu/settings.json`
からは初回のみ引き継ぐ（条件は上の (B) と同じ「自分側に無いときだけ」）。

ただし次の 2 つは**リネームしてはいけない**。norisan さんの他アドオンが 1 つのメニューボタンに
相乗りするための待ち合わせ名で、変えると相手の項目が出なくなる／互いにフレームを壊し合う。

* `_G["norisan"]["MENU"]` … メニュー項目の共有登録先（`{name, func, icon}` を入れる）
* フレーム名 `"norisan_menu_frame"` … `core/20_lifecycle.lua` にも同名の分岐がある

### 設定画面の位置は `g.settings_frame_pos` で決める

各アドオンの設定画面は「アドオン一覧（`list_frame`）の右隣」に置く作りが多いが、
**Addons Menu のショートカットから開くと一覧は開いていない**。素で
`list_frame:GetX()` を呼ぶとそこで落ち、**窓は既に作った後なので中身が空の窓が出る**
（実機で Auto Repair / Boss Direction で発生。同じ書き方が 11 アドオンにあった）。

* 位置は `g.settings_frame_pos(width, height)`（[core/00_header.lua](../nexus_addons_p/src/core/00_header.lua)）を使う。
  一覧が開いていればその右隣、開いていなければ画面中央へ置き、画面からはみ出さないよう丸める。
* **位置を読むためだけに一覧を開いて隠す、をしないこと。** `characters_item_serch` が
  そうしていたが、この「出ていない登録」が ESC のスタックに残り、後で一覧を開き直しても
  手前に来ない原因になる（ESC の節を参照）。

### Addons Menu へ並べる項目（ショートカット）

一覧の行の☆と設定画面の「ショートカット」タブで、**各アドオンの設定画面を Addons Menu へ
出せる**。集めているのは `addons_menu_collect_items`（[core/90_addons_menu.lua](../nexus_addons_p/src/core/90_addons_menu.lua)）
1 箇所で、出どころは 3 つ（相乗り項目 / registry の `config_func` / 設定を開く歯車）。

* **`_G["norisan"]["MENU"] を書き換えないこと`**。アイコンの上書きは表示用の写しに対して行う。
  共有テーブルを直接いじると本家側のメニューの見た目まで変わる。
* **既定は出どころで違う**。相乗り項目は「出す」（既定を非表示にすると他アドオンの項目が
  黙って消える）、registry の設定画面は「出さない」。
* **`pairs` の順で並べない**。起動ごとに順番が変わる。相乗りはキー順、registry は登録順。
  利用者が▲▼で並べ替えた分は `menu_shortcuts` の `order`。**`order` を持たない項目は末尾へ回す**
  （相乗り項目は起動ごとに顔ぶれが変わるので、知らない項目が並びの真ん中へ割り込まないように）。
  `table.sort` は安定ではないので、元の位置を最後の決め手にすること。
  並べ替えは一覧全体へ番号を振り直す（隣と入れ替えるだけだと、番号を持たない項目が混ざったとき
  「押しても動かない」組み合わせが残る）。まとめ書きは `g.menu_shortcut_set(..., defer)` で
  溜めて、最後に 1 回だけ保存する。
* 設定の保存先は `settings.json` の `menu_shortcuts`（`g.menu_shortcut_*`）。
  **トップレベルなので `valid_keys` への追加が要る**（書き忘れると毎回プルーニングで消える）。
* 並べ方（向き・折り返す数）は `addons_menu.json`。**`addons_menu_save_json` は書き出すキーを
  列挙している**ので、設定を足したらそこと「デフォルトに戻す」（`def_setting`）の両方に書く。
  読むより先に保存する経路があると設定が消えるので、`addons_menu_create_frame` は
  `addons_menu_load_layout()` を保存より前に呼んでいる。
* アイコン選択（[core/91_icon_picker.lua](../nexus_addons_p/src/core/91_icon_picker.lua)）の「検索」タブが引く
  画像名の表は **生成物**。[core/92_icon_names.lua](../nexus_addons_p/src/core/92_icon_names.lua) を手で編集せず、
  `git fetch upstream` してから `python docs/gen_icon_names.py` で作り直すこと
  （素のクライアント `_client/jp/**` の `image="..."` / `SetImage("...")` / `{img ...}` から抜いている）。
  **Lua には画像名を列挙する手段が無い**ので、同梱する以外に「名前で探す」を実現する方法は無い。
* 収集の結果は [docs/tests/test_addons_menu.lua](tests/test_addons_menu.lua) が検査する
  （並び順・既定・アイコンの上書きが共有テーブルを汚さないこと）。
