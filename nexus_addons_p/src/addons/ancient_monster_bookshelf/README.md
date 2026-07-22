# Ancient Monster Bookshelf

> アシスターカード整理アドオン

| 項目 | 内容 |
| --- | --- |
| キー | `ancient_monster_bookshelf` |
| ソース | [ancient_monster_bookshelf.lua](ancient_monster_bookshelf.lua) |
| 状態 | **無効（未完成のため意図的に停止中）** |
| 原作者 | ebisuke さん |

## ⚠️ このアドオンは動きません

**アドオン一覧にも出ず、初期化もされません。**
[core/10_registry.lua](../../core/10_registry.lua) の登録エントリと説明文が
どちらもコメントアウトされているため、`ancient_monster_bookshelf_on_init` は
一度も呼ばれません。

ただし [build_manifest.json](../../build_manifest.json) の
`_nexus_addons_p_conclude.lua` 側には入っているので、**配布 `.ipf` には同梱されます**
（conclude bundle の中身は実質このファイル 1 本です）。

この状態は本家 Nexus Addons 由来で、履歴を遡れる最古の版（v1.1.5 / 2026-01）の時点で
すでにコメントアウト済みでした。**Nexus Addons P 側で止めたものではないので、
upstream を取り込むときもこの状態のままにしてください。**

## 本来の機能

アシスターカード一覧（`ancient_card_list`）に `AMB` ボタンを追加し、
**同じレアリティのカード 3 枚を選んでまとめて合成する**画面を開くものです。

* 左に「Assister Box」（保管箱と装備中のカード）、右に「Inventory」を並べて表示
* カードをクリックして選択し、`Combine` で合成
* インベントリのカードは**自動で保管箱へ登録してから**合成する
* 同じ種類が 3 枚そろわないよう組み合わせを選び、合成結果を次の合成に**使い回して連鎖**する
* 合成が返ってこないときはウォッチドッグで**最大 5 回まで再試行**する

## 有効化するなら必要なこと

コードのコメントに書かれている、最低限の作業は次のとおりです。

1. **`ts()` のデバッグ出力が 28 箇所そのまま残っています**（`ts("1")` のような書き捨てを含む）。
   有効化すると合成のたびにチャット欄が埋まります。
2. `Ancient_monster_bookshelf_btn_init` が `ui.GetFrame("ancient_card_list")` を
   **nil ガードなしで参照**しています。このフレームはアシスターカード UI を開くまで
   存在しないため、`on_init` のタイミング次第で必ずエラーになります
   （`pcall` に包まれているのでログに出るだけですが、ボタンは付きません）。
3. **合成はカードを消費する破壊的操作**です。実機での動作確認が必須です。
4. `Ancient_monster_bookshelf_get_selected_cards` の中で、定義されていない
   グローバル関数 `deepcopy` を呼んでいます
   （このファイル内の実装は `Ancient_monster_bookshelf_deepcopy`）。

## 保存先

なし（設定を持ちません）。
