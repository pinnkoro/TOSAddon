# -*- coding: utf-8 -*-
"""「素の関数を書き写して差し替えている箇所」がクライアント更新に置き去りにされるのを検出する。

■ なぜ必要か

`mini_addons` の置換方式フック（`g.setup_hook`）のうち数個は、**素の関数を呼ばず、
中身をそのまま書き写したうえで自分の処理を足す**作りになっている。
コンテキストメニューは `ui.CreateContextMenu` → `ui.OpenContextMenu` で完結するため、
素を呼んだ後から項目を足せず、こう作らざるを得なかった（詳細は Issue #53）。

この作りは今は素と同じ動きをするが、**IMC 側が素の関数を変更したとき、設定の ON / OFF に
関わらず古い実装のまま**になる。エラーにはならず、静かに古い挙動になるだけなので
気付けない。追加された項目や、素側で入った修正が失われる。

そこで「書き写した当時の素の実装」を `docs/client_snapshots/` に控えておき、

    1. 控えが壊れていないか（CI で毎回）        … `python docs/check_client_copies.py`
    2. 控えと今のクライアントが同じか（手動）   … `--against upstream/main`

の 2 段で見る。2 は本家（upstream）が同梱しているクライアント実装
`_client/jp/**` と突き合わせる。**本家を取り込む（マージする）ときに必ず流すこと**
（CLAUDE.md「本家の修正を取り込みたい場合」の項目に手順がある）。

■ 差分が出たときにやること

素の実装が変わったということなので、`nexus_addons_p/src/addons/mini_addons/mini_addons.lua`
の該当ハンドラを新しい素の実装で書き直し（自分の追加分は残す）、

    python docs/check_client_copies.py --against upstream/main --bless

で控えを更新する。**控えだけ更新して本体を直さないこと**（アラームを消すだけになる）。

■ 控えの限界

`_client/jp/**` は本家リポジトリが持つクライアントの写しなので、本家が更新しない限り
古いままになる。つまりこの検査は「クライアントが変わった瞬間」ではなく
「本家の写しが更新された時点」で鳴る。それでも、静かに古くなるよりはよい。

使い方:
    python docs/check_client_copies.py                          # 控えの整合性だけ見る（CI と同じ）
    python docs/check_client_copies.py --against upstream/main  # 今のクライアントと突き合わせる
    python docs/check_client_copies.py --against upstream/main --bless   # 控えを更新する
    python docs/check_client_copies.py --against-dir path/to/_client/..  # 手元の展開物と比較
"""
import argparse
import difflib
import hashlib
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "docs", "client_copies.json")
ADDON_SRC = os.path.join(
    ROOT, "nexus_addons_p", "src", "addons", "mini_addons", "mini_addons.lua")


def load_manifest():
    with open(MANIFEST, encoding="utf-8") as f:
        return json.load(f)


def sha256(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def read_client_file(entry, ref, client_dir):
    """クライアント実装を 1 ファイル読む。ref 指定なら git、そうでなければファイルから。"""
    path = entry["client_file"]
    if client_dir:
        full = os.path.join(client_dir, path)
        if not os.path.isfile(full):
            return None, "%s が無い" % full
        with open(full, encoding="utf-8-sig") as f:
            return f.read(), None
    try:
        raw = subprocess.check_output(
            ["git", "show", "%s:%s" % (ref, path)], cwd=ROOT,
            stderr=subprocess.PIPE)
    except subprocess.CalledProcessError as e:
        return None, "git show %s:%s に失敗（%s を fetch 済みか確認する）: %s" % (
            ref, path, ref, e.stderr.decode("utf-8", "replace").strip())
    return raw.decode("utf-8-sig"), None


def extract_function(text, name):
    """トップレベルの `function NAME(...)` を 1 個切り出す。

    クライアントの Lua はトップレベル関数の `end` を必ず桁 0 に置いているので、
    「桁 0 の end」までを本体とみなす。ネストしたブロックの end は必ず字下げされる
    ため取り違えない。切り出せなければ None を返す（呼び側でエラーにする）。
    """
    lines = text.split("\n")
    start = None
    head = re.compile(r"^function\s+%s\s*\(" % re.escape(name))
    for i, line in enumerate(lines):
        if head.match(line):
            if start is not None:
                return None, "%s の定義が複数ある" % name
            start = i
    if start is None:
        return None, "%s の定義が見つからない" % name
    for i in range(start + 1, len(lines)):
        if lines[i].rstrip() == "end":
            body = "\n".join(lines[start:i + 1])
            # 末尾の改行を必ず 1 個にして、控えの差分が改行だけで出ないようにする。
            return body.rstrip("\n") + "\n", None
    return None, "%s の終端（桁 0 の end）が見つからない" % name


def check_snapshots_intact(manifest):
    """控えファイルと登録内容そのものが壊れていないかを見る（クライアント不要）。"""
    ok = True
    with open(ADDON_SRC, encoding="utf-8") as f:
        addon_src = f.read()
    for entry in manifest["entries"]:
        snap_path = os.path.join(ROOT, entry["snapshot"])
        if not os.path.isfile(snap_path):
            print("  NG  控えが無い: %s" % entry["snapshot"])
            ok = False
            continue
        with open(snap_path, encoding="utf-8") as f:
            snap = f.read()
        got = sha256(snap)
        if got != entry["sha256"]:
            print("  NG  控えの sha256 不一致: %s" % entry["snapshot"])
            print("        expected %s" % entry["sha256"])
            print("        got      %s" % got)
            ok = False
            continue
        # 控えだけ残ってハンドラが消えている（＝この登録が無意味になっている）のを検出する。
        if not re.search(r"^function\s+%s\s*\(" % re.escape(entry["handler"]),
                         addon_src, re.M):
            print("  NG  %s が mini_addons.lua に無い（登録を消すか直す）" % entry["handler"])
            ok = False
            continue
        print("  ok  %s  <- %s" % (entry["handler"], entry["origin"]))
    return ok


def check_against_client(manifest, ref, client_dir, bless):
    """控えと、今のクライアント実装を突き合わせる。bless なら控えを更新する。"""
    ok = True
    for entry in manifest["entries"]:
        text, err = read_client_file(entry, ref, client_dir)
        if err:
            print("  NG  %s: %s" % (entry["origin"], err))
            ok = False
            continue
        current, err = extract_function(text, entry["origin"])
        if err:
            print("  NG  %s: %s" % (entry["client_file"], err))
            ok = False
            continue
        snap_path = os.path.join(ROOT, entry["snapshot"])
        old = None
        if os.path.isfile(snap_path):
            with open(snap_path, encoding="utf-8") as f:
                old = f.read()
        if bless:
            os.makedirs(os.path.dirname(snap_path), exist_ok=True)
            # newline="\n": Windows でも LF 固定（CRLF になると毎回差分が出る）。
            with open(snap_path, "w", encoding="utf-8", newline="\n") as f:
                f.write(current)
            entry["sha256"] = sha256(current)
            print("  blessed %s: %s%s" % (
                entry["snapshot"], entry["sha256"],
                "" if old == current else "  (CHANGED)"))
            continue
        if old is None:
            print("  NG  控えが無い: %s（--bless で作る）" % entry["snapshot"])
            ok = False
            continue
        if old != current:
            print("  NG  素の %s が控えと違う（mini_addons.lua の %s を追随させる）" % (
                entry["origin"], entry["handler"]))
            diff = difflib.unified_diff(
                old.split("\n"), current.split("\n"),
                fromfile="控え " + entry["snapshot"],
                tofile="現在 " + entry["client_file"], lineterm="")
            for line in diff:
                print("      " + line)
            ok = False
            continue
        print("  ok  %s は控えと同じ" % entry["origin"])
    if bless:
        with open(MANIFEST, "w", encoding="utf-8", newline="\n") as f:
            json.dump(manifest, f, ensure_ascii=False, indent=2)
            f.write("\n")
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--against", metavar="REF",
                    help="突き合わせ先の git ref（例: upstream/main）")
    ap.add_argument("--against-dir", metavar="DIR",
                    help="突き合わせ先を手元のディレクトリにする（_client の親）")
    ap.add_argument("--bless", action="store_true",
                    help="控えを今のクライアント実装で更新する")
    args = ap.parse_args()

    manifest = load_manifest()

    if args.bless and not (args.against or args.against_dir):
        print("[client-copies] --bless には --against / --against-dir が要る")
        sys.exit(2)

    if args.against or args.against_dir:
        print("[client-copies] 控えと今のクライアント実装を突き合わせる")
        ok = check_against_client(
            manifest, args.against, args.against_dir, args.bless)
    else:
        print("[client-copies] 控えの整合性を検査（クライアントとの突き合わせは "
              "--against upstream/main）")
        ok = check_snapshots_intact(manifest)

    if not ok:
        print("[client-copies] NG")
        sys.exit(1)
    print("[client-copies] OK")


if __name__ == "__main__":
    main()
