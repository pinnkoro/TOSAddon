# -*- coding: utf-8 -*-
"""main 上のバージョン情報を「リリース時にだけ動かす」ことを機械的に保証する。

■ なぜ必要か（実際に起きた事故）

アドオンマネージャーは **main の `addons.json`** を読み、その `fileVersion` から
アセット名 `nexus_addons_p-<fileVersion>.ipf` を組み立てて Release から取得する。
一方 Release のアセットは `main -> release` をマージして初めて差し替わる。

つまり機能 PR の時点で main だけ先に採番すると、公開までの間ずっと

    main の addons.json : v1.0.3  →  取りに行くアセット nexus_addons_p-v1.0.3.ipf
    配布中の Release    : v1.0.2  →  そんなアセットは無い（404）

となり、**その間は利用者が新規インストールも更新もできなくなる**。
「先に採番しても 3 箇所が揃っていれば問題ない」は、この経路を見落としていた。

そこで main への PR ではバージョン情報の変更を禁止し、公開直前の
`release-prep/**` ブランチでだけ採番する（採番 PR をマージしたら、続けて
main -> release の PR を出して公開する。ズレる時間を分単位に抑えるのが狙い）。

■ 見る対象（= 版数が散っている 3 箇所）

    nexus_addons_p/src/core/00_header.lua の ver
    addons.json の fileVersion
    nexus_addons_p/ 直下の .ipf のファイル名

■ 比較の基準は「base ブランチの現在の先端」ではなく merge-base

base の先端と比べると、採番後の main を取り込んだだけの機能ブランチが
「バージョンを変えた」と誤検出される（取り込む前は base=v1.0.3 / head=v1.0.2、
取り込んだ後は両方 v1.0.3 という具合に、ブランチ自身は何もしていないのに差が出る）。
merge-base（= そのブランチが分岐した地点）と比べれば、見えるのは
**そのブランチ自身が加えた変更だけ**になる。

使い方:
    python docs/check_version_freeze.py                     # 手元（現在のブランチ）を検査
    python docs/check_version_freeze.py --head-branch release-prep/v1.0.3
    python docs/check_version_freeze.py --base origin/main --head <sha> \
        --base-branch main --head-branch <branch>

終了コード: 0 = 変更なし（または採番が許される経路）/ 1 = 違反
"""
import argparse
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)

ADDON_ID = "nexus_addons_p"  # addons.json の file（永続 ID）
ADDONS_JSON = "addons.json"
HEADER_LUA = "nexus_addons_p/src/core/00_header.lua"
IPF_DIR = "nexus_addons_p"

# 採番を許すブランチ。ここでだけ 3 箇所 + .ipf をまとめて更新し、
# マージしたらすぐ main -> release の PR を出して公開する。
BUMP_BRANCH_PREFIX = "release-prep/"


def git(*args):
    """git の標準出力を返す。失敗は None（ファイルが無い ref など）。"""
    try:
        out = subprocess.run(("git",) + args, cwd=REPO, check=True,
                             capture_output=True)
    except (OSError, subprocess.CalledProcessError):
        return None
    return out.stdout.decode("utf-8", "replace")


def git_or_die(*args):
    out = git(*args)
    if out is None:
        raise SystemExit("[freeze] git コマンドに失敗: git " + " ".join(args))
    return out


def norm(v):
    return v if v.startswith("v") else "v" + v


def versions_at(ref):
    """ref 時点の版数 3 箇所を (lua, json, ipf のタプル) で返す。読めない箇所は None。"""
    lua_ver = None
    src = git("show", f"{ref}:{HEADER_LUA}")
    if src is not None:
        m = re.search(r'^local\s+ver\s*=\s*"([^"]+)"', src, re.M)
        if m:
            lua_ver = norm(m.group(1))

    json_ver = None
    src = git("show", f"{ref}:{ADDONS_JSON}")
    if src is not None:
        try:
            matched = [e for e in json.loads(src) if e.get("file") == ADDON_ID]
        except ValueError:
            matched = []
        if len(matched) == 1 and matched[0].get("fileVersion"):
            json_ver = norm(matched[0]["fileVersion"])

    # .ipf は「ファイル名そのもの」を見る。旧版を _old/ へ移し忘れて 2 個並ぶのも
    # 変更として検出したいので、集合ではなく並びごと比較する。
    # -z は必須。配布 .ipf の名前は ⛄(U+26C4) を含み、既定の core.quotepath では
    # "..\342\233\204.." とクォートされて .ipf 判定を素通りしてしまう。
    names = git("ls-tree", "-z", "--name-only", ref, f"{IPF_DIR}/") or ""
    ipfs = tuple(sorted(os.path.basename(n) for n in names.split("\0")
                        if n.endswith(".ipf")))
    return (lua_ver, json_ver, ipfs)


def describe(v):
    lua_ver, json_ver, ipfs = v
    return (f"00_header.lua ver={lua_ver} / addons.json={json_ver} / "
            f".ipf={', '.join(ipfs) if ipfs else '(無し)'}")


def check_bump_is_complete(head):
    """採番ブランチ側の 3 箇所が揃っているかを見る（.ipf の中身は ipf ジョブが見る）。"""
    lua_ver, json_ver, ipfs = head
    if len(ipfs) != 1:
        print(f"[freeze] nexus_addons_p 直下の .ipf が {len(ipfs)} 個ある"
              "（最新版 1 個だけにし、旧版は _old/ へ移すこと）")
        return False
    m = re.search(r"-(v\d+\.\d+\.\d+)\.ipf$", ipfs[0])
    ipf_ver = m.group(1) if m else None
    if lua_ver == json_ver == ipf_ver and lua_ver is not None:
        print(f"[freeze] 採番 OK: {lua_ver}（3 箇所一致）")
        return True
    print("[freeze] 採番が揃っていない。3 箇所すべてを同じ版に揃えること:\n"
          f"    {describe(head)}")
    return False


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--base", default="origin/main",
                   help="比較の相手（既定: origin/main）。merge-base を取る")
    p.add_argument("--head", default="HEAD", help="検査対象の ref（既定: HEAD）")
    p.add_argument("--base-branch", default="main", help="PR のマージ先ブランチ名")
    p.add_argument("--head-branch", default=None,
                   help="PR のブランチ名（既定: 現在のブランチ）")
    args = p.parse_args()

    head_branch = args.head_branch
    if head_branch is None:
        head_branch = (git("rev-parse", "--abbrev-ref", "HEAD") or "").strip()

    # main -> release の PR は採番済みのものが流れてくる経路なので対象外。
    # そちらは ipf ジョブ（verify_ipf.py）が三者一致と .ipf の中身まで見る。
    if args.base_branch == "release":
        print("[freeze] マージ先が release のため対象外（ipf ジョブが検証する）")
        return 0

    base_ref = args.base
    merge_base = git("merge-base", base_ref, args.head)
    if merge_base is None:
        raise SystemExit(
            f"[freeze] merge-base を取れない: {base_ref} と {args.head}\n"
            "  （CI では checkout の fetch-depth: 0 と base ブランチの fetch が必要）")
    merge_base = merge_base.strip()

    before = versions_at(merge_base)
    after = versions_at(args.head)
    print(f"[freeze] 分岐点 {merge_base[:9]}: {describe(before)}")
    print(f"[freeze] 変更後 {args.head[:9]}: {describe(after)}")

    if before == after:
        print("[freeze] OK: バージョン情報は変更されていない")
        return 0

    if head_branch.startswith(BUMP_BRANCH_PREFIX):
        print(f"[freeze] 採番ブランチ（{BUMP_BRANCH_PREFIX}**）なので変更を許可する")
        return 0 if check_bump_is_complete(after) else 1

    print(
        "\n[freeze] main 向けの PR でバージョン情報を変更している。禁止:\n"
        "    アドオンマネージャーは main の addons.json の fileVersion から\n"
        "    アセット名 nexus_addons_p-<fileVersion>.ipf を組み立てて Release を引く。\n"
        "    先に採番すると、公開されるまでの間そのアセットが存在せず、\n"
        "    利用者が新規インストールも更新もできなくなる。\n"
        "  → この PR からは版数の変更を落とし、公開するときに\n"
        f"     {BUMP_BRANCH_PREFIX}vX.Y.Z ブランチで次をまとめて行うこと:\n"
        "       1. 00_header.lua の ver / addons.json の fileVersion / .ipf のファイル名\n"
        "       2. .ipf の再ビルド（docs/BUILD_IPF.md 方式B）と旧版の _old/ 退避\n"
        "       3. README の更新履歴の見出しを確定（「次回リリース」→ vX.Y.Z）\n"
        "     マージしたら続けて main -> release の PR を出して公開する。")
    return 1


if __name__ == "__main__":
    sys.exit(main())
