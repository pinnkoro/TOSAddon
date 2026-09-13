# CLAUDE.md — TOSAddon (Nexus Addons P)

Tree of Savior のアドオン集 **Nexus Addons P** の配布リポジトリ。norisan さんの
[Nexus Addons](https://github.com/ajinorisan/TOSAddon-public) の派生版で、アドオン名・保存フォルダ・
グローバル関数名を `_nexus_addons_p` 系にリネームし、バージョンは本家と独立して採番する。

コードはゲームクライアント上でしか動かない。**機械で検証できるのは `docs/tests/` の純ロジックだけ**
なので、書いたコードが効いているかは詳細ログを出して実機のログで確かめる（[docs/DEBUGGING.md](docs/DEBUGGING.md)）。

## よく使うコマンド

```bash
python docs/bundle_from_src.py              # src/** を連結して bundle を生成（編集後は毎回）
python docs/bundle_from_src.py --check      # golden sha / manifest 脱落の検証（CI と同じ）
python docs/bundle_from_src.py --bless      # 配布物を変える意図があるとき golden sha を更新
                                            #   → --bless は bundle を書き出さないので、続けて引数なしで再実行する
sh docs/tests/syntax_check.sh               # 連結後の Lua 構文チェック（WSL の luajit）
python docs/check_forward_refs.py           # local function の前方参照
python docs/check_frame_hittest.py          # 窓の当たり判定の塞ぎ忘れ
python docs/vanilla_api.py --verify-client  # 素のクライアントとの突き合わせ（ローカル専用・PR 前に必ず）
python docs/vanilla_api.py --update         # 素の API 一覧を更新（--verify-client の後に流す）
python docs/verify_ipf.py                   # .ipf の中身と版番号の三者一致
python docs/check_version_freeze.py         # 先行採番の検出（main への PR）
luajit docs/tests/test_core.lua             # ロジックテスト（他のテストも CI の一覧にある）
```

* **テストの成否は終了コードではなく出力の最終行で見る。** WSL の luajit は落ちていても 0 を返す。
* **動作確認の段になったら、こちらでビルドして `data\` へ置き換える**（聞かずに実施）。
  手順は [docs/BUILD_IPF.md](docs/BUILD_IPF.md)。テスト配置の `.ipf` は `-dev` 付きにし、`data\` 直下は常に 1 本だけにする。
* CI の全ジョブと、それぞれが何を止めているかは [.github/workflows/ci.yml](.github/workflows/ci.yml) の冒頭コメント。

## アーキテクチャ

* **source of truth は `nexus_addons_p/src/**`。** 連結後の bundle は生成物なので直接編集しない。
  連結順は `src/build_manifest.json` が決める（**未登録のファイルはビルドから黙って脱落する**）。
* `src/core/**` … 共通基盤。`00_header.lua`（グローバル `g` と共通部品）/ `10_registry.lua`（アドオン一覧の定義）/
  `20_lifecycle.lua`（初期化・ESC）/ `30_maintenance.lua`（バックアップ）/ `90_addons_menu.lua`（メニューボタン）。
* `src/addons/**` … アドオン本体。`guard_open.lua` / `guard_close.lua` に挟まれ、
  **本家が先に読み込まれていれば一切定義されない**（[docs/COEXIST.md](docs/COEXIST.md)）。
* 設定は `../addons/_nexus_addons_p/<AID>/settings.json`。**トップレベルのキーは `valid_keys` にも足す**
  （書き忘れると毎回プルーニングで消える）。
* 本家の修正を取り込むときは upstream を足してマージし、取り込み後に `src/**` 側へリネームを反映する
  （`_nexus_addons` → `_nexus_addons_p`、`_NEXUS_ADDONS` → `_NEXUS_ADDONS_P`）。

  ```bash
  git remote add upstream https://github.com/ajinorisan/TOSAddon-public.git
  ```

* 素のクライアント実装も upstream にある。**素の関数の挙動や戻り値を推測しないこと** —
  `git show upstream/main:_client/jp/...` で実物を読める。新パッチの ID だけはローカルのゲーム本体から取る。

## コードを書くときの決まり

どれも **構文チェックを通り抜けて、実機でその機能を触った瞬間にだけ落ちる** 種類のもの。
根拠と過去に踏んだ実例は [docs/CODING_RULES.md](docs/CODING_RULES.md) と [docs/UI_RULES.md](docs/UI_RULES.md)。

* **`local function` は呼び出しより前で定義する。** 後ろだと nil のグローバル呼び出しになる。
* **素の関数を書き写さない。** 置換方式フック（`g.setup_hook`）は必ず素を呼び、その結果へ足す。
  素にある項目を、機能が OFF のときに消してはいけない。
* **素の API を新しく使い始めたら `docs/vanilla_api.py --update` を流して一覧も一緒に commit する。**
* **自作ウィンドウを開いたら `g.block_click_through(frame)` を呼ぶ**（HUD・マーカー・ツールチップは除く）。
* **自作ウィンドウを開いたら `g.esc_register` 系でスタックへ積む。** ESC は × ボタンと同じ後始末を通す。
  積むのは `ShowWindow(1)` の後。HUD とゲーム窓の付属パネルには積まない。
* **設定画面の位置は `g.settings_frame_pos(width, height)` で決める。** `list_frame:GetX()` を素で呼ぶと、
  Addons Menu から開いたときに中身が空の窓が出る。
* **検索欄は `g.setup_incremental_search` か `g.setup_enter_search` のどちらかを使う。**
  選ぶ基準は「空文字で検索関数を呼んだとき何が起きるか」（全件に当たるなら後者）。
* **`os.execute` を避ける。** GUI プロセスから呼ぶと必ずコンソール窓が点滅する。
  ファイルのコピーは `g.copy_file`、フォルダ作成だけは代替が無いので `g.create_folder` を通す。
* **修正したら `g.vlog` で判断材料になった値を出し、`verbose_log.txt` で期待した分岐を通っているか確かめる。**
  調査が終わってもログは消さない。ただし毎フレーム走る経路では絞る。

## 作業の進め方

* **コードレビューの指摘は日本語で書く。** このリポジトリはコメント・コミットメッセージ・PR・README を
  すべて日本語で書いている。手元の `/code-review` でも、PR で走る
  [Claude Code Review](.github/workflows/claude-review.yml) でも同じ。
  識別子・ファイルパス・ログやコードの引用は**原文のまま**（訳すと検索できなくなる）。
  「なぜ問題か」「どう直すか」を日本語で書く、という意味。CLAUDE.md 由来の指摘は根拠にした箇所を引用する。
* **不具合の相談を受けたら、調べ始める前に「開発者本人の手元で再現したものか、利用者からの報告か」を聞く。**
  手元の設定 JSON やログは**この PC の記録でしかなく**、他人の環境の事象を否定する証拠にならない
  （[docs/DEBUGGING.md](docs/DEBUGGING.md)）。
* **機能を足した / 直したら、registry の定義に `since` / `updated` と `updated_note_jp` を 1 行足す**
  （[docs/UPDATE_BADGE.md](docs/UPDATE_BADGE.md)）。書くのは `g.VER_NEXT`。
* **PR には README の更新履歴への追記を必ず含める**（[docs/RELEASE.md](docs/RELEASE.md)）。
  見出しは `* **（次回リリース）**`。例外は「利用者から見て何も変わらない変更」だけで、
  その判断と根拠を PR 本文に書く。
* **版番号は上げない。** 採番は `release-prep/vX.Y.Z` ブランチだけ。main で先に採番すると、
  公開までの間ずっと利用者がインストールも更新もできなくなる（[docs/RELEASE.md](docs/RELEASE.md)）。
* **PR は `?template=` 付きの URL から作る**（ディレクトリ形式のテンプレートは自動適用されない）。
  通常の開発: `https://github.com/pinnkoro/TOSAddon/compare/main...<branch>?template=feature.md&expand=1`
* **PR レビューの指摘は、差分外に当たるとインラインではなくコメント欄に出る。**
  `issues/<n>/comments` も毎回見る。

### 画面の見た目を変えたらスクリーンショットの撮り直し Issue を作る

[nexus_addons_p/README.md](nexus_addons_p/README.md) は [nexus_addons_p/images/](nexus_addons_p/images/) の画像で
使い方を説明しているが、**画像はゲームを起動しないと撮れず、Claude Code の側では撮れない**。
放っておくと説明と実際の画面が食い違ったまま配布されることになる。

* **作るタイミング**: 見た目を変える PR と同じタイミング。PR 本文にも Issue 番号を書く。
* **Issue に書くこと**: 撮り直す画像のファイル名 / 何が変わったのか / 撮る手順（どこを開き、どの設定を ON にするか） /
  README のどの行から参照されているか。
* **alt テキストは Issue ではなく PR の中で直す**（画像が無くてもできる）。
* **見た目を変えていない PR では作らない。** 内部実装だけの変更は対象外。

## タスク別の手順

| やること | 読むもの |
| --- | --- |
| アドオンを 1 本追加する | [docs/NEW_ADDON.md](docs/NEW_ADDON.md)（スキル `new-addon`）— registry / build_manifest / README など **5 か所**の登録が要る |
| Lv 上限の解放に追従する | [docs/LEVEL_CAP_UPDATE.md](docs/LEVEL_CAP_UPDATE.md)（スキル `lv-cap-update`） |
| 本家との共存まわりを触る | [docs/COEXIST.md](docs/COEXIST.md) |
| 窓・検索欄を作る／直す | [docs/UI_RULES.md](docs/UI_RULES.md) |
| 素の API まわりを触る | [docs/VANILLA_API.md](docs/VANILLA_API.md) |
| `.ipf` をビルドする | [docs/BUILD_IPF.md](docs/BUILD_IPF.md) |
| リリースを公開する | [docs/RELEASE.md](docs/RELEASE.md) |

`.claude/skills/` は **skills だけ追跡している**（`.claude/` の他のファイルは個人設定なので無視のまま）。

## 指示ファイルの構成

守らせ方を 3 層に分けている。**このファイルに全部書かない。**

| 層 | 置き場所 | 役割 |
| --- | --- | --- |
| 指示（常時ロード） | この CLAUDE.md（200 行以内） | 毎回効いてほしい事実と、docs へのポインタ |
| 指示（条件ロード） | [.claude/rules/](.claude/rules/) | `paths:` で該当ファイルを開いたときだけ載る。中身は**ポインタだけ**にして docs と二重管理にしない |
| 強制（決定論的） | CI + GitHub ruleset + [.claude/hooks/](.claude/hooks/) | 選ばせずに止める。指示と違い、無視できない |
| 手続き（オンデマンド） | [.claude/skills/](.claude/skills/) | 呼ばれるまでトークンを消費しない作業手順 |

* **hooks は [.claude/settings.json](.claude/settings.json) で登録している。**
  * `PreToolUse` … 生成物（bundle / `92_icon_names.lua` / `vanilla_api.json`）への書き込みを拒否
  * `PostToolUse` … `src/**` の `.lua` を編集したら bundle 生成・前方参照・当たり判定を走らせる
  * **hook を足したら必ず手で叩いて確かめる**: `echo '{"tool_name":"Edit","tool_input":{"file_path":"..."}}' | python .claude/hooks/<name>.py`
* `.claude/` は個人設定が入るので `.gitignore` で無視しつつ、
  **skills / rules / hooks と settings.json だけ追跡している**（`settings.local.json` は追跡しない）。
* **`AGENTS.md` は置いていない。** Claude Code は `AGENTS.md` を読まず、このリポジトリの
  指示ファイルの消費者は Claude Code と [claude-review.yml](.github/workflows/claude-review.yml) の
  2 つだけなので、置いても `@AGENTS.md` を書いた CLAUDE.md が残るだけで得が無い。
  Cursor や Copilot を併用し始めたら、`AGENTS.md` を正本にして CLAUDE.md から import する。


## 環境のクセ

* **外部 HTTPS を叩くコード（terraform / az / Python の requests 等）は WSL で実行する。**
  Windows ホストはノートン 360 が HTTPS を MITM しており、ホスト側では原理的に直せない。
* **Lua の構文チェックも WSL の luajit で行う。** ただし終了コードは当てにならない（上記）。
* **`AddonManager` が起動しないときは `ja.json` のキー欠落を疑う。** 翻訳 API を同期で叩いて失敗すると起動不能になる。
* **アドオンの `.ipf` は `⛄`（U+26C4）付きのファイル名でないと読み込まれない。** 読まれないときはまず名前を疑う。
