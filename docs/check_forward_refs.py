# -*- coding: utf-8 -*-
"""連結後 bundle で「`local function` を定義より前で呼んでいる」箇所を検出する。

Lua の `local function f` は**宣言行より後ろからしか見えない**。前で呼ぶと同名の
グローバル（= nil）を呼ぶことになり、**構文チェックは通るのに実行時にだけ落ちる**。
落ちるのはボタンを押した瞬間なので、実機で踏むまで気付けない。

実際に踏んだ例（Issue: Addons Menu の設定画面）:
    addons_menu_apply_frame_settings() を定義より前の
    addons_menu_setting_frame_ctrl から呼んでいて、
    「レイヤー設定 / デフォルトに戻す / 上へ開く」の 3 操作が無反応になっていた。

src を分割している都合上、**この検査は連結後の bundle に対して行う**こと
（ファイル単位では前後関係が分からない）。

使い方（リポジトリルートから）:
    python docs/bundle_from_src.py      # 先に bundle を生成する
    python docs/check_forward_refs.py
"""
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
MANIFEST = os.path.join(REPO, "nexus_addons_p", "src", "build_manifest.json")
BUNDLE_DIR = os.path.join(REPO, "nexus_addons_p", "_nexus_addons_p")

DEF_RE = re.compile(r"\s*local function ([A-Za-z_][A-Za-z0-9_]*)")


def strip_comment(line):
    """行コメントを落とす。文字列中の -- まで気にしない（誤検出しても定義行は拾わない）。"""
    return line.split("--", 1)[0]


def check(path):
    with io.open(path, encoding="utf-8") as f:
        lines = f.read().split("\n")
    # 同名の local function が複数あるときは最初の定義を採る（それより前で呼べば必ず nil）。
    defs = {}
    for i, line in enumerate(lines):
        m = DEF_RE.match(line)
        if m and m.group(1) not in defs:
            defs[m.group(1)] = i
    findings = []
    for name, def_line in defs.items():
        # `name(` の呼び出しだけを見る。foo.name( / foo:name( / "name(" は別物なので除く。
        pat = re.compile(r"(?<![\w.:\"'])" + re.escape(name) + r"\s*\(")
        for i in range(def_line):
            if pat.search(strip_comment(lines[i])):
                findings.append((name, i + 1, def_line + 1, lines[i].strip()[:100]))
                break
    return findings


def main():
    with io.open(MANIFEST, encoding="utf-8") as f:
        targets = json.load(f)["targets"]
    total = 0
    for target in targets:
        path = os.path.join(BUNDLE_DIR, target)
        if not os.path.isfile(path):
            raise SystemExit(
                f"[forward-refs] bundle が無い: {path}\n"
                "  先に python docs/bundle_from_src.py を実行すること")
        findings = check(path)
        for name, use_line, def_line, text in findings:
            print(f"  NG {target}:{use_line} {name}() を定義({def_line} 行)より前で呼んでいる\n"
                  f"      {text}")
        total += len(findings)
        if not findings:
            print(f"  OK {target}: 前方参照なし")
    if total:
        print(f"[forward-refs] {total} 件。local function を呼び出しより前へ移すか、"
              "ファイル先頭で `local <name>` と前方宣言すること")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
