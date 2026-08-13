# 設定（settings）

> 設定項目の定義・設定画面・設定ファイルの読み書き

| 項目 | 内容 |
| --- | --- |
| ソース | [definitions.lua](definitions.lua) / [ui.lua](ui.lua) / [storage.lua](storage.lua) |
| 設定画面 | ミニマップ左下のボタン（`Mini_addons_SETTING_FRAME_INIT`） |
| 保存先 | `../addons/_nexus_addons_p/<アカウントID>/mini_addons.json` |

## ファイル

| ファイル | 内容 |
| --- | --- |
| [definitions.lua](definitions.lua) | `DEFAULT_SETTINGS` / `SETTINGS_NAME` / `COIN_ITEM` / `MAIN_FRAME_SETTINGS` / `SUB_FRAME_SETTINGS` / `SETTING_SECTIONS` と、名前を文言へ解決する処理 |
| [ui.lua](ui.lua) | 設定画面の組み立て（`Mini_addons_setting_build`）・検索・セクションの折りたたみ・チェックの反映（`Mini_addons_ISCHECK`） |
| [storage.lua](storage.lua) | 設定とバフ一覧の読み書き（`Mini_addons_load_settings` / `Mini_addons_save_settings` / `Mini_addons_load_buffs` / `Mini_addons_save_buffs`）と、その所要時間の計測 |

## 使い方

設定画面は **1 枚のスクロールする一覧**で、`SETTING_SECTIONS` の見出しで区切られています。
見出しをクリックすると、その配下を畳む / 開くができ、状態は `section_collapsed` に保存されます。
上部の検索窓（虫眼鏡ボタン / ENTER）で絞り込めます。一致判定は表示言語の文言だけでなく、
**他言語の文言と設定名（英字のキー）**も対象です。

## しくみ

* 項目の**文言の定義**は `MAIN_FRAME_SETTINGS` / `SUB_FRAME_SETTINGS` にあります。これは上流で
  「メイン画面」「サブ画面」に分かれていた名残で、**どちらに書いてあるかは表示先と無関係**です。
* **どのセクションへ出すか**は `SETTING_SECTIONS` が設定名の並びで持ちます。項目を移すときは
  ここだけを直せば済みます。`SETTING_SECTIONS` に書き忘れた項目は、黙って消えないよう
  最後のセクション（その他）へ回ります。
* 設定の追加は `DEFAULT_SETTINGS`（既定値）と `SETTINGS_NAME`（機能の ON/OFF として扱うもの）の
  両方に足します。`.use` を持つ入れ子の設定は `NESTED_USE_SETTINGS` にも載せます。

## 注意

* **設定画面を開いた直後に入力欄へ `Focus()` しないこと。** ESC の 1 回目がクライアント側の
  「入力欄から抜ける」に使われ、こちらへ届かなくなります（CLAUDE.md「ウィンドウを開いたら ESC で
  閉じられるようにする」）。ESC の入口は `Mini_addons_setting_ESCAPE_PRESSED` です。
* `Mini_addons_load_settings` / `Mini_addons_load_buffs` の計測ログ（`g.vlog`）は消さないこと。
  初回ログインで on_init が 5 秒掛かる不具合の切り分けに使ったもので、走るのは 1 セッション 1 回です。
