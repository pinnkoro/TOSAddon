# コードを書くときの決まり

構文チェックを通り抜けて実機でだけ落ちる書き方と、その避け方。入口は [CLAUDE.md](../CLAUDE.md)。

## `local function` は呼び出しより前で定義する

Lua の `local function f` は**宣言行より後ろからしか見えない**。前で呼ぶと同名の
グローバル（= nil）を呼ぶことになり、**構文チェックは通るのに、そのボタンを押した
瞬間だけ落ちる**。src を分割しているぶん前後関係が見えづらく、実際に踏んだ
（Addons Menu の設定画面で「レイヤー設定 / デフォルトに戻す / 上へ開く」が無反応になった）。

* 検出は [docs/check_forward_refs.py](check_forward_refs.py)。**連結後の bundle に対して**行う
  （ファイル単位では前後関係が分からない）。CI の `bundle` ジョブでも走る。
* 直し方は「定義を呼び出しより前へ移す」か「ファイル先頭で `local <name>` と前方宣言する」。
* グローバル（`function _G.foo`）は実行時に引くので前後関係を気にしなくてよい。
  ただし読み込み時ガードの外から呼ぶものは `type(_G["foo"]) == "function"` で見てから呼ぶこと。

## 素の API を使ったら一覧を更新する

素のクライアント API（`GET_CHILD_RECURSIVELY` などの Lua 関数と `ui.GetFrame` などの
ネイティブ）の使い方は [docs/vanilla_api.json](vanilla_api.json) に固定してある。
IMC 側のパッチで関数が消える・引数が変わっても**構文チェックは通り、実機でその機能を
触った瞬間にだけ落ちる**ので、機械で見られるようにしたもの。手順は
[docs/VANILLA_API.md](VANILLA_API.md)。

* **CI（`bundle` ジョブ）で走るのは `python docs/vanilla_api.py --check` だけ**。
  src の使い方が一覧と一致するかを見る。素の API を新しく使い始めたら、
  **手元で `--update` を流して一覧も一緒に commit すること**（忘れると CI が落ちる）。
* **素そのものとの突き合わせ（`--verify-client`）はローカル専用**。素の Lua は
  ゲームの導入先にしかなく再配布もできないので、ランナーでは原理的に走らせられない。
  **PR を出す前に、`--update` より先に流すこと。** 素が変わったかどうかはこれでしか
  分からない。**`--update` は判定しない**（記録を今のクライアントで上書きするだけ）。
  順番を間違えても飲み込まないよう、`--update` も書き換える前に同じ判定を行い、
  実機で壊れる食い違いが在れば書き換えずに止まる（承知のうえで取り込むときだけ
  `--accept-client-changes`）。
* 素に見当たらない名前は既定で NG。実在しないとは限らない（ネイティブにだけ在る関数、
  本家アドオンが定義するもの）ので、確かめたうえで `EXPECTED_NOT_IN_CLIENT` か
  `KNOWN_ISSUES` へ**理由付きで**足す。`check_frame_hittest.py` の `ALLOW` と同じ考え方。
* **素の仮引数より多く渡している**のは NG ではない（Lua は余った実引数を捨てる）。
  素が引数を減らした跡として「注意」に出るだけ。

## 素の関数を書き写さない（置換方式フックは必ず素を呼ぶ）

置換方式フック（`g.setup_hook`）で**素の関数の中身を書き写して自分の処理を足すこと**は
してはいけない。今は素と同じ動きでも、IMC 側が素を変更したとき**設定の ON / OFF に
関わらず古い実装のまま**になる。エラーにならず静かに古い挙動になるので気付けない。

* 実際に `mini_addons` の 7 箇所がこの作りで、次の食い違いが溜まっていた（Issue #53）。
  素にある項目を**機能が OFF のときに消していた**のが 2 件、素の判定が落ちていたのが 2 件。
  * `POPUP_DUMMY` の「見比べる」／`CONTEXT_PARTY` の「詳細情報を見る」が、
    既定 OFF で消えていた
  * `SHOW_PC_CONTEXT_MENU` の幻影（`Illusion_Buff`）判定と、
    `POPUP_GUILD_MEMBER` の拡張ギルドアジト判定が落ちていた
* **素にある項目を「機能が ON のとき」だけ差し替えるのはよいが、OFF のときに消してはいけない。**

**まだ書き写しのまま残っている 4 件がある**（Issue #94）。**うち 2 件**
（`ON_PARTYINFO_BUFFLIST_UPDATE` / `ON_UPDATE_QUESTINFOSET_2`）は素の途中で表示を絞る作りで、
「素を呼んでから加工」に素直に落ちない。**残る 2 件は構造的に書き換え不能というわけではなく**、
1 件ずつ確認しながら進める必要があるだけ。書き換えるまでの間、素が変わったことに
気付けるよう、**写し元の本文のハッシュを `docs/vanilla_api.json` の `copies` に記録して
`--verify-client` で照合している**（[docs/VANILLA_API.md](VANILLA_API.md) の
「書き写しの見張り」）。**新しく書き写しを増やさないこと。** どうしても要るなら
`docs/vanilla_api.py` の `COPIES` へ足して見張りに載せる。

### コンテキストメニューへ項目を足すとき

`ui.CreateContextMenu` → `ui.OpenContextMenu` で完結するので、素を呼んだ後からでは足せない。
`mini_addons_menu_hook`（[context_menu.lua](../nexus_addons_p/src/addons/mini_addons/context_menu/context_menu.lua)）を使う。
**素を呼び、その同期実行の間だけ `ui.AddContextMenuItem` / `ui.OpenContextMenu` を横取りして**、
メニューが開く前に項目を足す・落とす。

* 横取りは必ず元へ戻す（`pcall` が失敗した経路も含めて）。戻し忘れると全ての
  右クリックメニューを巻き込む。
* 素の戻り値はそのまま返すこと。`SHOW_PC_CONTEXT_MENU` は context を返し、
  呼び元の `_SHOW_PC_CONTEXT_MENU` が位置合わせに使っている。
* `ui.*` を差し替えられないクライアントに当たったら横取りを諦め、素をそのまま呼ぶ
  （追加項目は出ないが標準のメニューは壊れない）。可否は `verbose_log.txt` に 1 回だけ出す。


## CMD(コンソール窓)をなるべく出さない

`os.execute` は **GUI プロセスから呼ぶと必ず cmd.exe のコンソール窓を作る**。ゲーム画面が
一瞬点滅するので、利用者から見ると「アドオンが何か変なことをしている」ように見える。
`io.popen` も同じうえ、GUI アプリでは動作が不安定。

**新しくコードを書くときは、まず `os.execute` を使わずに済ませられないか検討すること。**

* **ファイルのコピーは `io` で 1 ファイルずつ行う**(`g.copy_file`)。`xcopy` は使わない。
  実例は [core/30_maintenance.lua](../nexus_addons_p/src/core/30_maintenance.lua) のバックアップ/復元。
  本家からの引き継ぎ(`g.migrate_from_origin`)も、同じ `g.settings_file_names` /
  `g.copy_settings_files` を使う。
* 代わりに「何をコピーするか」を自前で持つ必要がある。**Lua にディレクトリ列挙が無く、
  列挙する唯一の手段が cmd だから**、ここを避けるとファイル名は自分で列挙するしかない。
  固定名は `g.backup_files` のように定数で持ち、追加漏れは
  [docs/tests/test_core.lua](tests/test_core.lua) の検査で落とす。
* **フォルダ作成(`mkdir`)だけは代わりが無い**ので残る。ただし `g.create_folder` が
  マーカーファイルで空振りを防ぐので、窓が出るのは初回の 1 回だけ。
  フォルダを作る箇所は必ずここを通すこと。
  * `io.open` はフォルダを作らない（親が無ければ `No such file or directory` で失敗するだけ）。
  * **LuaFileSystem(`lfs`)はクライアントに入っていない**。実機で確認済み:
    `require('lfs')` は失敗し、`_G` にそれらしい名前は `CreateSlotFolderIcon` /
    `OpenUploadEmblemFolder`（どちらもギルドエンブレムの UI 関数）しか無い。
    **同じ調査を繰り返さないこと。**

現在 `os.execute` が残っているのは次の箇所。**減らせないか継続して検討する**。

| 箇所 | 用途 | 備考 |
| --- | --- | --- |
| `core/00_header.lua` `g.create_folder` | `mkdir` | 代替なし。マーカーで初回のみ |
| `addons/monster_kill_count` | `dir` でファイル列挙 | 可変名のファイルを列挙する唯一の手段 |
