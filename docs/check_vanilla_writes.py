#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""自分たちが作っていないテーブルへ値を書き込んでいる箇所を見つける。

**これは「素の関数を書き写さない」の、データ版の見張り。**

置換方式フック（`g.setup_hook`）には控えを持って必ず素を呼ぶ仕組みがあり、使った素の
API は `docs/vanilla_api.json` が見張っている。一方、**素のテーブルに値を書き込む**
（`shared_item_earring.MAX_SLOT_CNT = ...` のような形）のは、どの検査も素通りしていた。

危ないのは「素の定数は、たいてい**その先にある本当の制約を守るための門番**でしかない」
ため。書き換えると門番だけが外れ、制約はそのまま残る。

実例（v2.8.0 で修正 / 利用者からの報告）:

    -- 素 shared_item_earring.lua
    shared_item_earring.MAX_SLOT_CNT = 25          -- ただの数値。ここが上限ではない
    -- 素 fragmentation.lua
    if slotCnt > shared_item_earring.MAX_SLOT_CNT then return end   -- これが門番
    ...
    item.DialogTransaction("FRAGMENTATION_BUNDLE_ITEMS", ...)       -- 本当の制約はこの先

破片化の枠を広げる機能が、素の実行ボタンを動かすために MAX_SLOT_CNT を col*row へ
書き換えた。門番は外れたがその先の制約は変わっておらず、100 件を送ると**素の Lua は
最後まで通ったうえでネイティブごとクライアントが落ちた**（pcall でも捕まらず、
ボタンのイベントスクリプトなので debug_log.txt にも残らない）。

## 判定の考え方

**「素のテーブルの一覧」を持たない。** 最初は `docs/vanilla_api.json` に載っている名前から
テーブル名を割り出していたが、あれは **src が既に呼んだ API** の記録なので、
`shared_item_bracelet` のようにまだ触っていないテーブルへの書き込みは拾えなかった。
`shared_item_earring` を拾えていたのも「たまたま同じテーブルの別の関数を呼んでいたから」
でしかない（PR #178 のレビューで指摘）。

そこで逆にする。**自分たちが作ったもの以外への書き込みを全部出す。** 自分たちのものは

* その場のスコープで `local` 宣言した変数（`frag` / `settings` など）
* 共通テーブル `g` / `core_g` と、グローバルを名前で置く `_G`

の 3 つだけで、それ以外は素か、素のふりをした何かなので、書く前に一度考えるべきもの。
通すものは ALLOW へ**理由付きで**並べる。足すときの基準は 2 つ。

1. **その値が何を守っているのかを確かめたか。** 守りの実体が Lua の外
   （ネイティブ / サーバー）にあるなら、書き換えても制約は消えない。
2. **外した門番を自分で持ち直したか。** 横取りなら必ず元へ戻す、上限を上げたなら
   その上限を自分で守る、が書けているか。

check_frame_hittest.py の ALLOW と同じ考え方で、残骸（該当の代入が無いキー）が
残っていても落とす。

## 見落としを作らないための約束

PR #178 のレビューで、初版が素通りさせていた穴が 4 つ見つかっている。同じ穴を開け直さ
ないよう、いずれも `--self-test` で固定してある（CI でも走る）。

* **コメントと文字列を先に潰す。** `-- local session = 1` や、`type(config.X) == "function"`
  の `"function"` が仮引数リストに見えるせいで、本物の書き込みを見逃していた。
* **代入は行頭だけを見ない。** `if cond then t.X = 1 end` / `t["X"] = 1` / `t.X, y = 1, 2`
  のどれも同じ書き込み。
* **`local` の判定は 1 行の中で閉じる。** `\\s` は改行を含むので、初期化子の無い前方宣言を
  1 行足すだけで素通りできていた。
* **スコープを見る。** ファイルのどこか 1 か所に同名の仮引数があるだけで、そのファイル
  全体の書き込みが消えていた（`function(item)` が `item.X = 1` を無効化していた）。
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "nexus_addons_p" / "src"
MANIFEST = SRC / "build_manifest.json"

# 自分たちのグローバル。ここへの書き込みは見張らない。
OURS = {"g", "core_g", "_G"}

# 通してよい書き込み。キーは「<src からの相対パス>:<書き込む名前>」。
# **値には理由を書くこと**（何を守っている値なのか / 外した門番をどう持ち直したか）。
ALLOW = {
    "addons/mini_addons/misc/fragmentation.lua:shared_item_earring.MAX_SLOT_CNT":
        "素の実行ボタンは「枠より多い枚数は実行させない」ためにこれを見る。枠を広げる"
        "間だけ枚数へ合わせ、外した門番は frag.guard_execute が持ち直す（一度に送るのは"
        "素が持っていた値まで＝既定 25 個。超過分は控えて次の回へ回す）。OFF に戻すときは"
        "控えておいた素の値へ戻す",
    "addons/mini_addons/misc/fragmentation.lua:shared_item_earring.is_able_to_fragmetation":
        "素の並べ替えを呼んでいる同期実行の間だけ横取りして、自前のフィルタで落とす。"
        "pcall が失敗した経路も含めて必ず元へ戻す",
    "addons/mini_addons/context_menu/context_menu.lua:ui.AddContextMenuItem":
        "素のコンテキストメニューは CreateContextMenu → OpenContextMenu で完結するので、"
        "素を呼んだ後からは項目を足せない。素の同期実行の間だけ横取りし、必ず元へ戻す",
    "addons/mini_addons/context_menu/context_menu.lua:ui.OpenContextMenu":
        "同上。メニューが開く前に項目を足す／落とすための横取り。必ず元へ戻す",
}

# 代入の見つけ方。**入れ子の繰り返しを持つ正規表現で 1 発に書かないこと。**
# `(TARGET)(?:\s*,\s*(?:TARGET|name))*\s*=` の形にしたところ、長い行で破滅的な
# バックトラックを起こし、連結後の 6 万行を 3 分かけても終わらなくなった。
#
# 代わりに「`=`（`==` `~=` `<=` `>=` は除く）を探す → その手前の、代入の左辺に
# なりうる並び（英数字・ドット・カンマ・角括弧・空白）だけを切り出す →
# その中のドット / 角括弧付きの名前を拾う」という素直な手順にする。
# これで `if cond then t.X = 1 end`（`then` の手前で切れる）も
# `t.a, x = 1, 2`（多重代入）も同じように拾える。
EQ = re.compile(r"(?<![=~<>])=(?!=)")
LHS_TAIL = re.compile(r"[\w\s.,\[\]\"']+$")
TARGET = re.compile(r"[A-Za-z_]\w*(?:\.[A-Za-z_]\w*|\[[^\]\n]*\])+")
HEAD = re.compile(r"[A-Za-z_]\w*")


def targets_in(line: str):
    """その行が書き込んでいる先（`t.a` / `t["a"]`）を返す。"""
    m = EQ.search(line)
    if not m:
        return []
    tail = LHS_TAIL.search(line[:m.start()])
    if not tail:
        return []
    return [t.group(0) for t in TARGET.finditer(tail.group(0))]

# 名前を持ち込む書き方。**どれも 1 行の中で閉じて判定すること。**
DECL_LOCAL = re.compile(r"\blocal\b([^=\n]*)")
DECL_FOR = re.compile(r"\bfor\b([^\n]*?)\b(?:in\b|=)")
DECL_PARAM = re.compile(r"\bfunction\b[^(\n]*\(([^)\n]*)\)")
KEYWORDS = {"function", "in", "do", "then", "end", "local"}

# 字下げ 0 の function ... end を「関数の単位」として扱う（check_frame_hittest.py と同じ）。
FUNC = re.compile(r"^(?:(?:local\s+)?function\b|[\w.:]+\s*=\s*function\b)")
FUNC_END = re.compile(r"^end\b")


# コメント / 文字列の始まり。**1 文字ずつ進めないこと。**
# 最初は 1 文字ごとに `re.match(..., text[i:])` していたが、これは毎回 2.5MB の
# スライスを作るので、連結後の src では 90 秒たっても終わらなかった。
# 次の「始まり」へ一気に飛ぶ。
NEXT_TOKEN = re.compile(r"--|[\"']|\[=*\[")
LONG_OPEN = re.compile(r"\[(=*)\[")
NOT_LF = re.compile(r"[^\n]")


def strip_lua(text: str) -> str:
    """コメントと文字列リテラルを空白へ潰す（行番号と桁を保つ）。

    **先に潰さないと見落とす。** コメントアウトされた `-- local session = 1` が
    宣言に見えたり、`type(config.X) == "function"` の文字列が仮引数リストに見えたりして、
    同じファイルの本物の書き込みが「自前の変数」と誤判定されていた（PR #178 の指摘）。
    """
    out = []
    i, n = 0, len(text)
    while i < n:
        m = NEXT_TOKEN.search(text, i)
        if not m:
            out.append(text[i:])
            break
        out.append(text[i:m.start()])
        start, tok = m.start(), m.group(0)
        if tok == "--":
            long_open = LONG_OPEN.match(text, start + 2)
            if long_open:  # 長コメント
                close = "]" + long_open.group(1) + "]"
                j = text.find(close, start)
                j = n if j < 0 else j + len(close)
            else:
                j = text.find("\n", start)
                j = n if j < 0 else j
        elif tok in ("\"", "'"):
            j = start + 1
            while j < n and text[j] != tok and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
            j = min(j + 1, n)
        else:  # 長い文字列 [[ ... ]]
            close = "]" + tok[1:-1] + "]"
            j = text.find(close, start)
            j = n if j < 0 else j + len(close)
        out.append(NOT_LF.sub(" ", text[start:j]))
        i = j
    return "".join(out)


def names_in(line: str) -> set:
    """その行が持ち込む名前（local 宣言 / for の変数 / 仮引数）。"""
    found = set()
    for pat in (DECL_LOCAL, DECL_FOR, DECL_PARAM):
        for m in pat.finditer(line):
            for n in HEAD.findall(m.group(1)):
                if n not in KEYWORDS:
                    found.add(n)
    return found


def func_spans(lines: list) -> list:
    """字下げ 0 の function ... end の範囲（開始行, 終了行）を返す（1 始まり）。"""
    spans = []
    start = None
    for i, line in enumerate(lines, 1):
        if start is None:
            if FUNC.match(line):
                start = i
        elif FUNC_END.match(line):
            spans.append((start, i))
            start = None
    if start is not None:
        spans.append((start, len(lines)))
    return spans


class Scope:
    """どの行から、どの名前が自前の変数として見えているか。

    **まとめて見ないこと。** 同名の仮引数がどこか 1 か所にあるだけで、無関係な場所の
    書き込みまで見逃していた（PR #178 の指摘）。チャンク直下で前に宣言されたものと、
    その行を含む関数の中で前に宣言されたものだけを見る。

    連結後は 6 万行を超えるので、行ごとに集合を作ると終わらない。
    「名前 → 最初に宣言された行」を 1 回のなぞりで作り、引くのは添字 1 回にする。
    """

    def __init__(self, lines: list, spans: list):
        self.span_at = {}
        for idx, (a, b) in enumerate(spans):
            for i in range(a, b + 1):
                self.span_at[i] = idx
        self.outer = {}
        self.inner = [dict() for _ in spans]
        for i, line in enumerate(lines, 1):
            here = names_in(line)
            if not here:
                continue
            idx = self.span_at.get(i)
            target = self.outer if idx is None else self.inner[idx]
            for name in here:
                target.setdefault(name, i)

    def mine(self, head: str, at: int) -> bool:
        first = self.outer.get(head)
        if first is not None and first <= at:
            return True
        idx = self.span_at.get(at)
        if idx is not None:
            first = self.inner[idx].get(head)
            if first is not None and first <= at:
                return True
        return False


def concat():
    """manifest の順に連結した中身と、行 → src ファイルの対応を返す。

    **ファイル単位で見てはいけない。** bundle は src をメインチャンクの直下へ並べるので、
    あるファイルの先頭で `local skill_reroll = {}` と書けば**後ろのファイルからも見える**。
    ファイルごとに切って見ると、それが自前の変数だと分からず素のテーブル扱いになる
    （check_forward_refs.py が「連結後の bundle に対して行う」としているのと同じ理由）。
    """
    targets = json.loads(MANIFEST.read_text(encoding="utf-8"))["targets"]
    chunks = []
    for _target, rels in targets.items():
        lines = []
        owner = []  # 1 始まりの行 → src の相対パス
        for rel in rels:
            # 連結の規則は bundle_from_src.build と同じ（src は末尾 LF 前提）。
            text = (SRC / rel).read_text(encoding="utf-8")
            part = text.splitlines()
            lines.extend(part)
            owner.extend([rel] * len(part))
        chunks.append((lines, owner))
    return chunks


def scan():
    found = []
    seen_allow = set()
    for raw_lines, owner in concat():
        lines = strip_lua("\n".join(raw_lines)).splitlines()
        scope = Scope(lines, func_spans(lines))
        for i, line in enumerate(lines, 1):
            for target in targets_in(line):
                head = HEAD.match(target).group(0)
                if head in OURS:
                    continue
                if scope.mine(head, i):
                    continue  # 自分たちが作った変数
                rel = owner[i - 1]
                key = f"{rel}:{target}"
                if key in ALLOW:
                    seen_allow.add(key)
                    continue
                found.append((rel, i, target, line.strip()))
    return found, sorted(set(ALLOW) - seen_allow)


def self_test() -> int:
    """PR #178 で見つかった 4 つの穴を固定する。"""
    cases = [
        # (説明, Lua, 見つかってほしいか)
        ("素のテーブルへの代入", "shared_item_earring.MAX_SLOT_CNT = 100\n", True),
        ("まだ呼んでいない素のテーブル", "shared_item_bracelet.MAX_SLOT_CNT = 100\n", True),
        ("インデックス表記", 'shared_item_earring["MAX_SLOT_CNT"] = 100\n', True),
        ("行の途中", "if cond then shared_item_earring.MAX = 1 end\n", True),
        ("多重代入", "shared_item_earring.MAX, other = 1, 2\n", True),
        ("初期化子の無い前方宣言では隠れない", "local handle\nshared_item_earring.MAX = 1\n", True),
        ("コメントの宣言では隠れない", "-- local shared_item_earring = 1\nshared_item_earring.MAX = 1\n", True),
        ("文字列の function では隠れない",
         'if type(config.SetTotalVolume) == "function" then end\nconfig.FOO = 1\n', True),
        ("別の関数の仮引数では隠れない",
         "function a(item)\n    return item\nend\n\nfunction b()\n    item.X = 1\nend\n", True),
        ("同じ関数の仮引数なら隠れる", "function a(item)\n    item.X = 1\nend\n", False),
        ("自前の local なら隠れる", "local frag = {}\nfrag.X = 1\n", False),
        ("for の変数なら隠れる", "for _, item in ipairs(t) do\n    item.X = 1\nend\n", False),
        ("自分たちのグローバル", "g.settings = {}\ncore_g.x = 1\n_G[\"foo\"] = 1\n", False),
        ("比較は代入ではない", "if shared_item_earring.MAX == 1 then end\n", False),
    ]
    bad = 0
    for label, src, want in cases:
        lines = strip_lua(src).splitlines()
        scope = Scope(lines, func_spans(lines))
        hit = False
        for i, line in enumerate(lines, 1):
            for target in targets_in(line):
                head = HEAD.match(target).group(0)
                if head in OURS or scope.mine(head, i):
                    continue
                hit = True
        if hit != want:
            bad += 1
            print(f"NG self-test: {label} … 期待 {want} / 実際 {hit}\n{src}")
    if bad:
        return 1
    print(f"  OK self-test: {len(cases)} 件")
    return 0


def main() -> int:
    if "--self-test" in sys.argv:
        return self_test()

    found, stale = scan()
    for rel, line, target, code in found:
        print(f"NG {rel}:{line} 自分たちが作っていないテーブルへ書き込んでいる … {code}")
        print(f"   → その値が何を守っているのかを確かめること。守りの実体が Lua の外"
              f"（ネイティブ / サーバー）なら、書き換えても制約は消えない。"
              f"承知のうえなら docs/check_vanilla_writes.py の ALLOW へ"
              f"「{rel}:{target}」を理由付きで足す")
    for key in stale:
        print(f"NG ALLOW に残骸: {key} … 該当の書き込みが無い。消すこと")

    if found or stale:
        return 1
    print(f"  OK 素のテーブルへの書き込み: 意図したもの {len(ALLOW)} 件のみ")
    return 0


if __name__ == "__main__":
    sys.exit(main())
