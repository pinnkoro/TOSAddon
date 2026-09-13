#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""素のテーブルへ値を書き込んでいる箇所を見つける。

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

そこで「素のテーブルへの代入は既定で NG」とし、通すものは ALLOW へ**理由付きで**
並べる。ここへ足すときの基準は 2 つ。

1. **その値が何を守っているのかを確かめたか。** 守りの実体が Lua の外
   （ネイティブ / サーバー）にあるなら、書き換えても制約は消えない。
2. **外した門番を自分で持ち直したか。** 横取りなら必ず元へ戻す、上限を上げたなら
   その上限を自分で守る、が書けているか。

check_frame_hittest.py の ALLOW と同じ考え方で、残骸（該当の代入が無いキー）が
残っていても落とす。
"""
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "nexus_addons_p" / "src"
API = ROOT / "docs" / "vanilla_api.json"

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

# `名前.フィールド = `（`==` は除く）。`a.b.c = ` のような深い形も拾う。
ASSIGN = re.compile(r"^\s*([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)+)\s*=\s*(?!=)")
# 同じファイルで `local <名前>` / `for ... <名前>` / 仮引数として使われていたら、
# 素のテーブルではなく自前の変数。market_favorite_rebuild の `for _, item in ...` が
# 素の `item` テーブルと同じ名前を持つのが実例。
SHADOW = re.compile(
    r"\blocal\s+(?:[\w\s,]*\b)?{name}\b"
    r"|\bfor\s+[\w\s,]*\b{name}\b\s*(?:=|in\b)"
    r"|\bfunction\s*[\w.:]*\s*\([^)]*\b{name}\b"
)


def vanilla_tables():
    """素の API 一覧から、テーブル名（`a.b` の前半）と完全名の集合を作る。"""
    data = json.loads(API.read_text(encoding="utf-8"))
    names = set(data.get("symbols", {}))
    tables = {n.split(".")[0] for n in names if "." in n}
    return names, tables


def shadowed(text: str, head: str) -> bool:
    return re.search(SHADOW.pattern.format(name=re.escape(head)), text) is not None


def main() -> int:
    if not API.is_file():
        print(f"NG {API} が無い。先に python docs/vanilla_api.py --update を流すこと")
        return 1
    names, tables = vanilla_tables()

    found = []
    seen = set()
    for path in sorted(SRC.rglob("*.lua")):
        rel = str(path.relative_to(SRC)).replace(os.sep, "/")
        text = path.read_text(encoding="utf-8")
        for i, line in enumerate(text.splitlines(), 1):
            m = ASSIGN.match(line)
            if not m:
                continue
            name = m.group(1)
            head = name.split(".")[0]
            if head not in tables and name not in names:
                continue
            if shadowed(text, head):
                continue  # 同名の自前の変数
            key = f"{rel}:{name}"
            if key in ALLOW:
                seen.add(key)
                continue
            found.append((rel, i, name, line.strip()))

    stale = sorted(set(ALLOW) - seen)

    for rel, line, name, code in found:
        print(f"NG {rel}:{line} 素のテーブルへ書き込んでいる … {code}")
        print(f"   → その値が何を守っているのかを確かめること。守りの実体が Lua の外"
              f"（ネイティブ / サーバー）なら、書き換えても制約は消えない。"
              f"承知のうえなら docs/check_vanilla_writes.py の ALLOW へ"
              f"「{rel}:{name}」を理由付きで足す")
    for key in stale:
        print(f"NG ALLOW に残骸: {key} … 該当の書き込みが無い。消すこと")

    if found or stale:
        return 1
    print(f"  OK 素のテーブルへの書き込み: 意図したもの {len(ALLOW)} 件のみ")
    return 0


if __name__ == "__main__":
    sys.exit(main())
