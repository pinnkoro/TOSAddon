#!/usr/bin/env python3
"""nexus_addons_p/src/** の .lua を編集した直後に、機械で見られる事故だけ潰す。

見るのは 3 つ。どれも**構文チェックを通り抜けて実機でだけ落ちる**ので、手元では
PR まで気付けない（CI の bundle ジョブと同じ検査を、編集した時点へ前倒ししている）。

  1. build_manifest.json 未登録 … ビルドから黙って脱落する（bundle 生成が検出する）
  2. local function の前方参照  … nil のグローバル呼び出しになり、押した瞬間に落ちる
  3. 窓の当たり判定の塞ぎ忘れ   … 窓の余白を押した入力が 3D 画面へ抜ける

**bundle 生成は --no-verify で呼ぶこと。** 素で呼ぶと golden sha を照合するが、src を
1 文字でも触れば当然ずれるので、編集直後は必ず失敗する。それを「落ちた」と扱うと
毎回の誤報になり、後続の 2 つが一度も走らない（PR #174 のレビューで指摘されて直した）。
golden sha の更新（--bless）は編集のたびではなく、PR を出す前に人がまとめて行うもの。

通ったときは何も出さない（編集のたびに出すとログが流れて肝心の行が埋もれる）。
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WATCHED = "nexus_addons_p/src/"


def run(args):
    """(成功したか, 出力) を返す。"""
    proc = subprocess.run(
        [sys.executable] + args, cwd=ROOT,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    return proc.returncode == 0, proc.stdout.decode("utf-8", "replace").strip()


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

    # 前方参照は**連結後の bundle** を見る（ファイル単位では前後関係が分からない）ので、
    # 先に bundle を作る。作れなかった＝manifest 未登録などのときは後続を飛ばす。
    ok, out = run(["docs/bundle_from_src.py", "--no-verify"])
    if ok:
        ok, out = run(["docs/check_forward_refs.py"])
        if not ok:
            failures.append("[local function の前方参照]\n%s" % out)
    else:
        failures.append("[bundle の生成 (manifest 未登録の検出)]\n%s" % out)

    # 当たり判定は src を直接読むので、bundle を作れなくても走らせる。
    ok, out = run(["docs/check_frame_hittest.py"])
    if not ok:
        failures.append("[窓の当たり判定]\n%s" % out)

    if not failures:
        return 0

    sys.stderr.write(
        "%s の編集後チェックが落ちました。直してから次へ進んでください。\n\n%s\n"
        % (rel, "\n\n".join(failures))
    )
    return 2


if __name__ == "__main__":
    sys.exit(main())
