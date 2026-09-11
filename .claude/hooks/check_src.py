#!/usr/bin/env python3
"""nexus_addons_p/src/** の .lua を編集した直後に、機械で見られる事故だけ潰す。

見るのは 3 つ。どれも**構文チェックを通り抜けて実機でだけ落ちる**ので、手元では
PR まで気付けない（CI の bundle ジョブと同じ検査を、編集した時点へ前倒ししている）。

  1. build_manifest.json 未登録 … ビルドから黙って脱落する（bundle 生成が検出する）
  2. local function の前方参照  … nil のグローバル呼び出しになり、押した瞬間に落ちる
  3. 窓の当たり判定の塞ぎ忘れ   … 窓の余白を押した入力が 3D 画面へ抜ける

通ったときは何も出さない（編集のたびに出すとログが流れて肝心の行が埋もれる）。
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WATCHED = "nexus_addons_p/src/"

CHECKS = [
    # (表示名, 引数) — bundle は連結してからでないと前後関係が見えないので最初に作る
    ("bundle の生成 (manifest 未登録の検出)", ["docs/bundle_from_src.py"]),
    ("local function の前方参照", ["docs/check_forward_refs.py"]),
    ("窓の当たり判定", ["docs/check_frame_hittest.py"]),
]


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0

    path = (payload.get("tool_input") or {}).get("file_path")
    if not path:
        return 0

    try:
        rel = os.path.relpath(os.path.abspath(path), ROOT).replace(os.sep, "/")
    except ValueError:
        return 0

    if not (rel.startswith(WATCHED) and rel.endswith(".lua")):
        return 0

    failures = []
    for label, args in CHECKS:
        proc = subprocess.run(
            [sys.executable] + args, cwd=ROOT,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        )
        if proc.returncode != 0:
            out = proc.stdout.decode("utf-8", "replace").strip()
            failures.append("[%s]\n%s" % (label, out))
            break  # bundle を作れていなければ後続は見る意味がない

    if not failures:
        return 0

    sys.stderr.write(
        "%s の編集後チェックが落ちました。直してから次へ進んでください。\n\n%s\n"
        % (rel, "\n\n".join(failures))
    )
    return 2


if __name__ == "__main__":
    sys.exit(main())
