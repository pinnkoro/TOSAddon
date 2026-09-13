---
paths:
  - "nexus_addons_p/src/addons/**/*.lua"
---

# アドオン本体を書くとき

このリポジトリのコードはゲームクライアント上でしか動かず、**構文チェックを通り抜けて
実機でその機能を触った瞬間にだけ落ちる**種類の事故が多い。下は実際に踏んだものだけを挙げている。

* **自作ウィンドウを開いたら `g.block_click_through(frame)` を呼ぶ**（HUD・マーカー・
  ツールチップは除く）。呼ばないと窓の余白を押した入力が 3D 画面へ抜ける。
* **自作ウィンドウを開いたら `g.esc_register` 系でスタックへ積む**（`ShowWindow(1)` の後）。
  ESC は × ボタンと同じ後始末を通すこと。
* **設定画面の位置は `g.settings_frame_pos(width, height)`**。`list_frame:GetX()` を素で呼ぶと
  Addons Menu から開いたときに中身が空の窓が出る。
* **検索欄は `g.setup_incremental_search` か `g.setup_enter_search`** のどちらかを使う。
  → 判断基準と過去の実例は **[docs/UI_RULES.md](../../docs/UI_RULES.md)**（窓を作る／直す前に読む）
* **`local function` は呼び出しより前で定義する。** 後ろだと nil のグローバル呼び出しになる。
* **素の関数を書き写さない。** `g.setup_hook` は必ず素を呼び、その結果へ足す。
  素にある項目を、機能が OFF のときに消してはいけない。
* **`os.execute` を避ける**（GUI プロセスから呼ぶとコンソール窓が点滅する）。
  → **[docs/CODING_RULES.md](../../docs/CODING_RULES.md)**
* **機能を足した／直したら registry の定義に `since` / `updated` / `updated_note_jp` を書く**
  （`g.VER_NEXT` を使う）。→ **[docs/UPDATE_BADGE.md](../../docs/UPDATE_BADGE.md)**
* 本家と同名のグローバルを扱うとき → **[docs/COEXIST.md](../../docs/COEXIST.md)**

**新しいファイルを足したら `nexus_addons_p/src/build_manifest.json` へ登録する。**
未登録のファイルはビルドから黙って脱落する。
