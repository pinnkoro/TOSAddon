# 素のクライアント API の使用一覧と検査

このリポジトリのアドオンは、素のクライアントが持つ Lua 関数（`GET_CHILD_RECURSIVELY` など）と
ネイティブ API（`ui.GetFrame` / `session.GetMyHandle` など）に寄りかかって動いている。
IMC 側のパッチで**関数が消える・引数の数が変わる**と、こちらのコードは構文としては正しいままなので
CI も Lua の構文チェックも通り、**実機でその機能を触った瞬間にだけ落ちる**。しかも落ちるのは
利用者の環境なので、こちらは気付けない。

そこで「どの素の API を、どう使っているか」を [vanilla_api.json](vanilla_api.json) に固定し、
[vanilla_api.py](vanilla_api.py) で 2 段構えで見る。

| コマンド | ゲーム本体 | いつ走るか | 何を見るか |
| --- | --- | --- | --- |
| `python docs/vanilla_api.py --check` | 不要 | **CI（`bundle` ジョブ）で毎回** | src の使い方が一覧と一致するか |
| `python docs/vanilla_api.py --verify-client` | **要る** | **手元で。PR を出す前** | 一覧に記録した素の事実が、今のクライアントと合っているか |
| `python docs/vanilla_api.py --update` | 素の事実を更新するなら要る | 一覧を作り直すとき | — |

## なぜ CI では素のクライアントを見られないのか

素の Lua はゲームの導入先（`data/*.ipf` / `patch/*.ipf`）にしか無く、再配布もできない。
GitHub Actions のランナーにゲームは入らないので、**素との突き合わせは原理的にローカルでしかできない**。
一覧を JSON にしてリポジトリへ入れているのはこのためで、CI では「一覧と src の食い違い」だけを見る。

## PR を出すときの手順

1. `python docs/vanilla_api.py --verify-client`
   **先にこれ**。一覧に記録した素の事実と、今のクライアントを突き合わせる。
   `NG` が出たら**素が変わっている**ので、直してから出す。
2. `python docs/vanilla_api.py --update`
   新しく使い始めた素の API を一覧へ取り込む（ゲームがあれば素の事実ごと更新する）。
3. 差分に出た `docs/vanilla_api.json` も一緒に commit する。

**`--update` は判定しません。** 記録を今のクライアントで上書きするだけなので、
素が変わっていても飲み込んでしまう…… となると検査にならないため、`--update` は
**書き換える前に `--verify-client` と同じ判定を行い、実機で壊れる食い違いが在れば
一覧を書き換えずに止まります**（承知のうえで取り込むときだけ `--accept-client-changes`）。
順番を間違えても素の変化を見落とさないようにするための作りで、
「素が変わったか」を見る道具はあくまで `--verify-client` です。

一覧は**1 記号 1 行**で書いてあるので、差分がそのまま「どの API の扱いが変わったか」の一覧になる。

## 判定できること / できないこと

* できる
  * 素の Lua で定義された関数が**まだ在るか**、**仮引数が変わっていないか**
  * ネイティブ API 名が**素の Lua から今も使われているか**（消えた API の検出）
  * 素での呼び出し引数の数の集合
  * こちらが**一覧に無い素の API を使い始めていないか**（CI）
* できない
  * ネイティブ API の本当の signature。**C 側なので Lua からは読めない**。
    素の Lua での使われ方から推測するしかない
  * 戻り値・副作用の変化。ここは実機で確かめるしかない（`g.vlog` で詳細ログを出す）

## 出力の 3 段階

`--verify-client` の報告は落とす/落とさないで分かれている。

* **NG**（落とす）… 定義が消えた / 仮引数が変わった / 素が使わなくなった / 素に見当たらない
* **注意**（落とさない）… 定義位置が移った、素の仮引数より多く渡している。
  **Lua では余った実引数は捨てられるだけ**なので、それ自体では落ちない。
  素が引数を減らした跡（＝こちらの想定が古い）の手掛かりとして出している
  （例: `GET_CHILD_RECURSIVELY(frame, name, "ui::CSlotSet")` の第 3 引数は素にもう無い）
* **既知**（落とさない）… `KNOWN_ISSUES` に控えてある、こちら側の書き間違い。直したら消す

## 2 つの表（[vanilla_api.py](vanilla_api.py) 内）

素の Lua に定義も使用も見当たらない名前は、既定では **NG** になる。実在しないとは限らない
（ネイティブにだけ在る関数、他所のアドオンが定義するもの）ので、確かめたうえで
**理由付きで**どちらかへ足すこと。`check_frame_hittest.py` の `ALLOW` と同じ考え方。

* `EXPECTED_NOT_IN_CLIENT` … 素に見当たらないが、それでよいと分かっているもの
  （`imcAddOn.BroadMsg` などのネイティブ API、本家 Nexus Addons が定義するもの）
* `KNOWN_ISSUES` … こちら側で対応が要るもの（書き間違い、実機で確かめないと決められない
  もの）。報告はするが落とさない。**片付いたらここから消す**。
  「素に無くてよい」と結論が出たものは `EXPECTED_NOT_IN_CLIENT` へ移す

## 記録している事実

| キー | 意味 |
| --- | --- |
| `kind` | `client_lua`（素の Lua が定義）/ `native`（C 側。素も使っている）/ `external`（上の表で理由を付けたもの）/ `unknown` |
| `params` / `defined_in` | 素での仮引数と定義ファイル（`client_lua` のみ） |
| `vanilla_calls` / `vanilla_mentions` | 素の Lua での呼び出し数と、文字列も含めた出現数。素は `ReserveScript("AnsGiveUpPrevPlayingIndun(1)")` のように**文字列の中から呼ぶ**ことがあるので、両方を持つ |
| `vanilla_arities` | 素での呼び出し引数の数 |
| `used_by` / `our_arities` | こちらの使用箇所と、渡している引数の数 |
| `hooked` | `g.setup_hook` / `g.setup_hook_and_event` で置き換えている（素が変わったときの影響が一番大きい） |

## ゲームの導入先

既定は `C:\Program Files (x86)\Steam\steamapps\common\Tree of Savior (Japanese Ver.)`。
別の場所なら `--client-root` か環境変数 `TOS_CLIENT_ROOT` で指定する。

`data/` と `patch/` の `.ipf` を古い順に読み、後のパッチで上書きする（同じパスが複数の
アーカイブに入っていて、新しい方が正）。**`_` で始まる `.ipf` は読まない** —
アドオンの `.ipf`（自分の `_nexus_addons_p-⛄-*.ipf` や他所の `_joystickplus-*.ipf`）が
同じ場所に置かれているので、混ぜると自分のコードを「素の API」として数えてしまう。

素の Lua を読む手段としては [upstream の `_client/jp/**`](../CLAUDE.md) もあるが、あちらは
取り込み時点のスナップショットで追従が遅れる。**「素が変わったか」を見るのが目的なので、
必ず導入先の `.ipf` を一次資料にすること。**
