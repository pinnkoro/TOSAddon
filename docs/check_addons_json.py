# -*- coding: utf-8 -*-
r"""`addons.json` が「アドオンマネージャーが取りに行ける形」かを検査する。

■ なぜ必要か

アドオンマネージャー（[MizukiBelhi/Addon-Manager](https://github.com/MizukiBelhi/Addon-Manager)）は
`addons.json` の**値をそのまま文字列に埋めて** URL とファイル名を組み立てる。
どのフィールドも「書き間違えると 404 になるだけで、リポジトリ側は何も壊れない」ため、
**間違いは利用者の「インストールできない」という形でしか表に出ない**。ここで止める。

組み立てられるもの（`Source/AddonManager/` の実装より）:

    一覧      https://raw.githubusercontent.com/{repo}/master/addons.json
              → List<AddonsObject> として読む。**1 リポジトリに複数エントリを並べてよい**
    更新日    https://github.com/{repo}/commits/{releaseTag}.atom
              → **移動タグが git の ref として存在していること**が要る
    取得      https://github.com/{repo}/releases/download/{releaseTag}/{file}-{fileVersion}.{extension}
    保存名    _{file}-{unicode}-{fileVersion}.{extension}
              → data\ へこの名前で置かれる。⛄ が無いとゲームが読み込まない
    導入判定  data\*.ipf を `_(.*)-(.*)-(v\d+.\d+.\d+.*).ipf` で解析して file / unicode / version を得る
              → file と unicode に `-` があると解析が崩れる

■ ここで見ないもの

`.ipf` の中身と版数の三者一致は [verify_ipf.py](verify_ipf.py)（release 経路）、
先行採番は [check_version_freeze.py](check_version_freeze.py)（main への PR）が見る。
このスクリプトは **`addons.json` の形だけ**を、毎回の PR で見る。

使い方:
    python docs/check_addons_json.py

終了コード: 0 = OK / 1 = 違反
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import addon_targets  # noqa: E402

REPO = addon_targets.REPO
REQUIRED_KEYS = ("name", "file", "extension", "fileVersion", "releaseTag",
                 "unicode", "description", "tags")

# ゲームがアドオンの .ipf として読み込む条件。名前に無いと**黙って読まれない**。
SNOWMAN = "⛄"
# マネージャーは fileVersion の先頭 1 文字を落として SemVersion.Parse へ渡す（AddonObject.cs）。
VERSION_RE = re.compile(r"^v\d+\.\d+\.\d+$")
# URL とディレクトリ名の両方になるので、記号は `_` だけに限る。
FILE_ID_RE = re.compile(r"^[a-z0-9_]+$")


def check_entry(entry, index, seen, problems):
    where = f"addons.json[{index}]"

    missing = [k for k in REQUIRED_KEYS if not entry.get(k)]
    if missing:
        problems.append(f"{where}: 必須キーが空 / 無い: {', '.join(missing)}")
        return None

    file_id = entry["file"]
    if not FILE_ID_RE.match(file_id):
        problems.append(
            f'{where}: file = "{file_id}" に使えない文字がある'
            "（小文字・数字・`_` のみ。URL とディレクトリ名の両方になる）")
    if file_id in seen:
        problems.append(f'{where}: file = "{file_id}" が重複している（永続 ID なので一意）')
    seen.add(file_id)

    if entry["extension"] != "ipf":
        problems.append(f'{where}: extension は "ipf" 固定（{entry["extension"]!r}）')

    if not VERSION_RE.match(entry["fileVersion"]):
        problems.append(
            f'{where}: fileVersion = "{entry["fileVersion"]}" が vX.Y.Z の形でない'
            "（マネージャーは先頭の v を落として SemVersion.Parse へ渡す）")

    if entry["releaseTag"] != file_id:
        problems.append(
            f'{where}: releaseTag = "{entry["releaseTag"]}" が file と違う'
            "（このリポジトリでは移動タグ名 = file に揃える。リリースの自動化が"
            " この前提で回っている）")

    if entry["unicode"] != SNOWMAN:
        problems.append(
            f'{where}: unicode が ⛄(U+26C4) でない（{entry["unicode"]!r}）。'
            "保存名 _<file>-<unicode>-<version>.ipf に入るので、違うとゲームが読み込まない")

    for key in ("file", "unicode"):
        if "-" in entry[key]:
            problems.append(
                f"{where}: {key} に `-` が入っている。マネージャーは導入済みの .ipf を"
                r" `_(.*)-(.*)-(v\d+.\d+.\d+.*).ipf` で解析するので、名前が崩れる")

    if not isinstance(entry["tags"], list) or not all(
            isinstance(t, str) for t in entry["tags"]):
        problems.append(f"{where}: tags は文字列の配列であること")

    return file_id


def check_layout(target, problems):
    """リポジトリ側の置き場が規約どおりか（ディレクトリ名 = file / .ipf の名前）。"""
    if not os.path.isdir(target.dir):
        problems.append(
            f"{target.id}: リポジトリ直下に {target.dir_rel}/ が無い"
            "（ディレクトリ名は file と同じにする。リリース基盤がここから .ipf を探す）")
        return

    ipfs = sorted(n for n in os.listdir(target.dir) if n.endswith(".ipf"))
    if not ipfs:
        # 初回リリース前はまだ .ipf が無い（採番 PR で置く）。release 経路では
        # verify_ipf.py が「無い」を失敗として止めるので、ここでは通す。
        print(f"  {target.id}: {target.dir_rel}/ に .ipf が無い（未リリース）")
        return
    if len(ipfs) > 1:
        problems.append(
            f"{target.id}: {target.dir_rel}/ 直下に .ipf が {len(ipfs)} 個ある"
            f"（最新版 1 個だけにし、旧版は _old/ へ移すこと）: {', '.join(ipfs)}")
        return
    if ipfs[0] != target.ipf_name:
        problems.append(
            f"{target.id}: .ipf の名前が addons.json と揃っていない\n"
            f"      在るもの   : {ipfs[0]}\n"
            f"      期待する形 : {target.ipf_name}")


def main():
    problems = []
    seen = set()
    for i, entry in enumerate(addon_targets.load_entries()):
        check_entry(entry, i, seen, problems)

    if problems:
        print("[addons.json] マネージャーが取りに行けない形になっている:")
        for p in problems:
            print(f"    - {p}")
        return 1

    # 形が通ってから Target にする（HEADER_LUA の未登録もここで落ちる）。
    print("[addons.json] マネージャーが組み立てる URL / ファイル名:")
    for target in addon_targets.targets():
        print(f"  {target.id} ({target.title}) {target.version}")
        print(f"    取得   https://github.com/pinnkoro/TOSAddon/releases/download/"
              f"{target.release_tag}/{target.asset_name}")
        print(f"    更新日 https://github.com/pinnkoro/TOSAddon/commits/"
              f"{target.release_tag}.atom")
        print(f"    保存名 {target.ipf_name}")
        check_layout(target, problems)

    if problems:
        print("\n[addons.json] リポジトリ側の置き場が規約と合っていない:")
        for p in problems:
            print(f"    - {p}")
        return 1

    print("[addons.json] OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
