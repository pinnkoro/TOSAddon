# -*- coding: utf-8 -*-
"""公開が要るアドオンを選ぶ（[.github/workflows/release.yml](../.github/workflows/release.yml) の plan ジョブ）。

■ なぜ「全部作り直す」ではいけないか

このリポジトリは 1 本の `.ipf` ではなく、`addons.json` のエントリぶん（Nexus Addons P /
Icor Planner）を配っている。一方 `main -> release` のマージは 1 回なので、素直に全部
作り直すと**何も変えていないアドオンのリリースまで作り直される**。移動タグの Release は
毎回タグごと消して作り直す運用なので、そうなると

  * 無関係なアドオンのリリースノートが、今回の PR 本文に差し替わる
  * 移動タグが今回のコミットへ動く = アドオンマネージャーが `commits/<tag>.atom` から
    取る**更新日**が動き、利用者には「更新されたらしいが中身は同じ」に見える

という実害が出る。

■ 何と比べるか

**公開済みの実物**と比べる。移動タグの Release に付いているアセット名の中に、
`addons.json` の `fileVersion` から組み立てた名前（`<file>-<fileVersion>.ipf`）が
あれば「この版は公開済み」。git の差分と違い、取りこぼしも二重公開も起きない
（公開に失敗した回があっても、次の実行で拾い直せる）。

手動実行で `--force <file>[,<file>]` を渡したものは、版が同じでも作り直す
（リリースノートを直したい / 公開そのものをやり直したいとき）。

使い方:
    python docs/plan_release.py                     # 判定結果を表示するだけ
    python docs/plan_release.py --force icor_planner
    GITHUB_OUTPUT=... python docs/plan_release.py   # matrix / any を出力に書く

終了コード: 0 = 判定できた / 1 = gh の実行に失敗した（公開対象 0 件は 0 で返す）
"""
import argparse
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import addon_targets  # noqa: E402


def published_assets(tag):
    """移動タグの Release に付いているアセット名。Release が無ければ空。

    「Release が無い」と「gh が動かない」を取り違えると、前者を後者として落とすか、
    後者を「未公開」として全部作り直すかのどちらかになる。gh は Release が無いとき
    exit != 0 かつ stderr に "release not found" を出すので、それで切り分ける。
    """
    proc = subprocess.run(
        ["gh", "release", "view", tag, "--json", "assets"],
        capture_output=True)
    if proc.returncode != 0:
        err = proc.stderr.decode("utf-8", "replace").strip()
        if "not found" in err.lower():
            return []
        raise SystemExit(f"[plan] gh release view {tag} に失敗: {err}")
    data = json.loads(proc.stdout.decode("utf-8"))
    return [a.get("name", "") for a in data.get("assets") or []]


def plan(force_ids):
    selected = []
    for target in addon_targets.targets():
        if target.id in force_ids:
            print(f"  {target.id}: 手動指定のため公開する")
        else:
            if target.asset_name in published_assets(target.release_tag):
                print(f"  {target.id}: {target.asset_name} は公開済みのため据え置き")
                continue
            print(f"  {target.id}: {target.asset_name} が未公開のため公開する")
        selected.append(addon_targets.as_dict(target))
    return selected


def parse_force(raw):
    return {s for s in (p.strip() for p in (raw or "").split(",")) if s}


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--force", default=os.environ.get("FORCE_ADDONS", ""),
                   help="版が同じでも公開し直す file をカンマ区切りで")
    args = p.parse_args()

    force_ids = parse_force(args.force)
    known = {t.id for t in addon_targets.targets()}
    unknown = sorted(force_ids - known)
    if unknown:
        raise SystemExit(
            f"[plan] addons.json に無い file を指定している: {', '.join(unknown)}\n"
            f"  指定できるのは: {', '.join(sorted(known))}")

    print("[plan] 配布ターゲット:")
    for target in addon_targets.targets():
        print(f"  {target.id} {target.version} -> "
              f"{target.release_tag} / {target.asset_name}")

    print("[plan] 判定:")
    selected = plan(force_ids)
    print(f"[plan] 公開対象: {len(selected)} 件"
          + ("（" + ", ".join(s["id"] for s in selected) + "）" if selected else ""))

    out = os.environ.get("GITHUB_OUTPUT")
    if out:
        with open(out, "a", encoding="utf-8") as f:
            f.write("matrix=" + json.dumps({"include": selected}) + "\n")
            f.write("any=" + ("true" if selected else "false") + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
