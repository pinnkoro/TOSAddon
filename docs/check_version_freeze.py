# -*- coding: utf-8 -*-
"""main 上のバージョン情報を「リリース時にだけ動かす」ことを機械的に保証する。

■ なぜ必要か（実際に起きた事故）

アドオンマネージャーは **main の `addons.json`** を読み、その `fileVersion` から
アセット名 `<file>-<fileVersion>.ipf` を組み立てて Release から取得する。
一方 Release のアセットは `main -> release` をマージして初めて差し替わる。

つまり機能 PR の時点で main だけ先に採番すると、公開までの間ずっと

    main の addons.json : v1.0.3  →  取りに行くアセット nexus_addons_p-v1.0.3.ipf
    配布中の Release    : v1.0.2  →  そんなアセットは無い（404）

となり、**その間は利用者が新規インストールも更新もできなくなる**。
「先に採番しても 3 箇所が揃っていれば問題ない」は、この経路を見落としていた。

そこで main への PR ではバージョン情報の変更を禁止し、公開直前の
`release-prep/**` ブランチでだけ採番する（採番 PR をマージしたら、続けて
main -> release の PR を出して公開する。ズレる時間を分単位に抑えるのが狙い）。

■ 見る対象（= `addons.json` の全エントリ × 版数が散っている 3 箇所）

    <addon>/src/**/00_header.lua の ver
    addons.json の fileVersion
    <addon>/ 直下の .ipf のファイル名

対象の一覧は [addon_targets.py](addon_targets.py) が `addons.json` から導く。
**`addons.json` へのエントリの追加 / 削除そのものも変更として検出する**。
エントリだけ先に main へ入れると、Release がまだ無いのにマネージャーの一覧へ並び、
押した利用者が 404 を踏むため（= 上と同じ事故）。新しいアドオンの初公開も
`release-prep/**` で `.ipf` と一緒に入れること。

■ 比較の基準は「base ブランチの現在の先端」ではなく merge-base

base の先端と比べると、採番後の main を取り込んだだけの機能ブランチが
「バージョンを変えた」と誤検出される（取り込む前は base=v1.0.3 / head=v1.0.2、
取り込んだ後は両方 v1.0.3 という具合に、ブランチ自身は何もしていないのに差が出る）。
merge-base（= そのブランチが分岐した地点）と比べれば、見えるのは
**そのブランチ自身が加えた変更だけ**になる。

使い方:
    python docs/check_version_freeze.py                     # 手元（現在のブランチ）を検査
    python docs/check_version_freeze.py --head-branch release-prep/icor-planner-v1.0.0
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
sys.path.insert(0, HERE)

import addon_targets  # noqa: E402

ADDONS_JSON = "addons.json"

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


def versions_at(ref):
    """ref 時点の版数を {file: (lua_ver, json_ver, ipf ファイル名のタプル)} で返す。

    対象は**その ref の `addons.json` に載っているエントリ**。今の作業ツリーの一覧で
    固定すると、エントリの追加 / 削除そのものを見逃す。
    """
    src = git("show", f"{ref}:{ADDONS_JSON}")
    try:
        entries = json.loads(src) if src is not None else []
    except ValueError:
        entries = []

    result = {}
    for entry in entries:
        file_id = entry.get("file")
        if not file_id:
            continue
        json_ver = entry.get("fileVersion")
        json_ver = addon_targets.norm_version(json_ver) if json_ver else None

        lua_ver = None
        header_rel = addon_targets.HEADER_LUA.get(file_id)
        if header_rel:
            text = git("show", f"{ref}:{header_rel}")
            if text is not None:
                m = re.search(r'^local\s+ver\s*=\s*"([^"]+)"', text, re.M)
                if m:
                    lua_ver = addon_targets.norm_version(m.group(1))

        # .ipf は「ファイル名そのもの」を見る。旧版を _old/ へ移し忘れて 2 個並ぶのも
        # 変更として検出したいので、集合ではなく並びごと比較する。
        # -z は必須。配布 .ipf の名前は ⛄(U+26C4) を含み、既定の core.quotepath では
        # "..\342\233\204.." とクォートされて .ipf 判定を素通りしてしまう。
        names = git("ls-tree", "-z", "--name-only", ref, f"{file_id}/") or ""
        ipfs = tuple(sorted(os.path.basename(n) for n in names.split("\0")
                            if n.endswith(".ipf")))
        result[file_id] = (lua_ver, json_ver, ipfs)
    return result


def describe(v):
    if v is None:
        return "(addons.json に無し)"
    lua_ver, json_ver, ipfs = v
    return (f"00_header.lua ver={lua_ver} / addons.json={json_ver} / "
            f".ipf={', '.join(ipfs) if ipfs else '(無し)'}")


def changed_ids(before, after):
    return sorted({k for k in set(before) | set(after)
                   if before.get(k) != after.get(k)})


def check_bump_is_complete(file_id, head):
    """採番ブランチ側の 3 箇所が揃っているかを見る（.ipf の中身は ipf ジョブが見る）。"""
    if head is None:
        # エントリを消した = そのアドオンの配布をやめた。揃えるものが無いので素通りさせる
        # （Release 側の後始末は手作業なので、ここでは止めない）。
        print(f"[freeze] {file_id}: addons.json から削除（配布終了）")
        return True

    lua_ver, json_ver, ipfs = head
    if file_id not in addon_targets.HEADER_LUA:
        print(f"[freeze] {file_id}: docs/addon_targets.py の HEADER_LUA に未登録"
              "（00_header.lua の場所を登録しないと版数を検査できない）")
        return False
    if len(ipfs) != 1:
        print(f"[freeze] {file_id}: {file_id}/ 直下の .ipf が {len(ipfs)} 個ある"
              "（最新版 1 個だけにし、旧版は _old/ へ移すこと）")
        return False
    m = re.search(r"-(v\d+\.\d+\.\d+)\.ipf$", ipfs[0])
    ipf_ver = m.group(1) if m else None
    if lua_ver == json_ver == ipf_ver and lua_ver is not None:
        print(f"[freeze] {file_id}: 採番 OK: {lua_ver}（3 箇所一致）")
        return True
    print(f"[freeze] {file_id}: 採番が揃っていない。3 箇所すべてを同じ版に揃えること:\n"
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
    for file_id in sorted(set(before) | set(after)):
        print(f"[freeze] {file_id}")
        print(f"    分岐点 {merge_base[:9]}: {describe(before.get(file_id))}")
        print(f"    変更後 {args.head[:9]}: {describe(after.get(file_id))}")

    changed = changed_ids(before, after)
    if not changed:
        print("[freeze] OK: バージョン情報は変更されていない")
        return 0

    if head_branch.startswith(BUMP_BRANCH_PREFIX):
        print(f"[freeze] 採番ブランチ（{BUMP_BRANCH_PREFIX}**）なので変更を許可する: "
              + ", ".join(changed))
        ok = True
        for file_id in changed:
            ok &= check_bump_is_complete(file_id, after.get(file_id))
        return 0 if ok else 1

    print(
        "\n[freeze] main 向けの PR でバージョン情報を変更している。禁止:\n"
        f"    変更されたアドオン: {', '.join(changed)}\n"
        "    アドオンマネージャーは main の addons.json の fileVersion から\n"
        "    アセット名 <file>-<fileVersion>.ipf を組み立てて Release を引く。\n"
        "    先に採番すると、公開されるまでの間そのアセットが存在せず、\n"
        "    利用者が新規インストールも更新もできなくなる。\n"
        "    （新しいアドオンのエントリ追加も同じ。Release がまだ無い状態で一覧に並ぶ）\n"
        "  → この PR からは版数の変更を落とし、公開するときに\n"
        f"     {BUMP_BRANCH_PREFIX}<名前> ブランチで次をまとめて行うこと:\n"
        "       1. 00_header.lua の ver / addons.json の fileVersion / .ipf のファイル名\n"
        "       2. .ipf の再ビルド（docs/BUILD_IPF.md 方式B）と旧版の _old/ 退避\n"
        "       3. README の更新履歴の見出しを確定（「次回リリース」→ vX.Y.Z）\n"
        "     マージしたら続けて main -> release の PR を出して公開する。")
    return 1


if __name__ == "__main__":
    sys.exit(main())
