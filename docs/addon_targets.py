# -*- coding: utf-8 -*-
"""配布ターゲット（= `addons.json` の 1 エントリ = 配布 `.ipf` 1 本）の定義。

リリース基盤のスクリプト（[verify_ipf.py](verify_ipf.py) /
[check_version_freeze.py](check_version_freeze.py) / [check_addons_json.py](check_addons_json.py)）は
**ここを通して**各アドオンを見る。1 アドオン固定の決め打ちを各スクリプトに散らすと、
2 本目を足したときに「片方だけ検査されない」が静かに起きるため。

■ 正は `addons.json`

アドオンマネージャーが読むのは main の `addons.json` なので、配布ターゲットの一覧
（何を配るか / 版数 / タグ / 絵文字）もそこを正とする。このモジュールが自分で持つのは
**`addons.json` から導けないものだけ**で、今は `00_header.lua` の置き場所しかない。

■ 命名の規約（`addons.json` の `file` から導く）

    file = "icor_planner" のとき

        リポジトリ内の置き場    icor_planner/
        bundle の出力先         icor_planner/_icor_planner/
        src                     icor_planner/src/
        リポジトリ内の .ipf     icor_planner/_icor_planner-⛄-v1.0.0.ipf
        Release のアセット名    icor_planner-v1.0.0.ipf      ← マネージャーが組み立てる名前
        移動タグ                icor_planner                  ← releaseTag
        保存用タグ              icor_planner-v1.0.0

`file` は一度決めたら変えられない永続 ID（README のとおり）。**ディレクトリ名も
それに揃える**ことで、ここの導出が成立している。

新しい配布ターゲットを足すときは `HEADER_LUA` に 1 行足す（足さないと、その
アドオンの版数だけ検査されないまま通るので、未登録は失敗させている）。
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
ADDONS_JSON = os.path.join(REPO, "addons.json")

# `local ver = "X.Y.Z"` が書いてある場所。ここだけは `file` から導けない
# （まとめ版は core/ の下、単体アドオンは src 直下、と分割の都合で位置が違う）。
HEADER_LUA = {
    "nexus_addons_p": "nexus_addons_p/src/core/00_header.lua",
    "icor_planner": "icor_planner/src/00_header.lua",
}


class Target(object):
    """`addons.json` の 1 エントリ + そこから導いたパスとタグ。"""

    def __init__(self, entry):
        self.entry = entry
        self.id = entry["file"]
        self.title = entry.get("name") or self.id
        self.unicode = entry.get("unicode") or ""
        self.version = norm_version(entry.get("fileVersion") or "")
        self.extension = entry.get("extension") or ""
        self.release_tag = entry.get("releaseTag") or ""

        rel = HEADER_LUA.get(self.id)
        if rel is None:
            raise SystemExit(
                f'[targets] addons.json の file == "{self.id}" が '
                "docs/addon_targets.py の HEADER_LUA に無い\n"
                "  → 配布ターゲットを足したら、その 00_header.lua の場所をここへ登録すること"
                "（登録しないと版数の検査から漏れる）")
        self.header_lua_rel = rel
        self.header_lua = os.path.join(REPO, *rel.split("/"))

        self.dir_rel = self.id                     # リポジトリ内の置き場 = 永続 ID
        self.dir = os.path.join(REPO, self.id)
        self.addon_folder = "_" + self.id          # .ipf 内部のフォルダ名
        self.bundle_dir_rel = f"{self.id}/_{self.id}"
        self.bundle_dir = os.path.join(REPO, self.id, self.addon_folder)
        self.src_rel = f"{self.id}/src"
        self.src = os.path.join(REPO, self.id, "src")

    @property
    def ipf_name(self):
        """リポジトリに置く .ipf のファイル名（⛄ 付き。付いていないとゲームが読まない）。"""
        return f"{self.addon_folder}-{self.unicode}-{self.version}.{self.extension}"

    @property
    def asset_name(self):
        """Release に添付するアセット名。**マネージャーが組み立てる名前と同じ**にする。

        Addon-Manager の DownloadManager.cs:
            https://github.com/{repo}/releases/download/{releaseTag}/{file}-{fileVersion}.{extension}
        """
        return f"{self.id}-{self.version}.{self.extension}"

    @property
    def archive_tag(self):
        """保存用（記録用）タグ。版番号だけだと 2 本目以降で衝突するので `<file>-` を付ける。"""
        return f"{self.id}-{self.version}"

    def __repr__(self):
        return f"<Target {self.id} {self.version}>"


def norm_version(v):
    return v if v.startswith("v") else "v" + v


def load_entries(path=None):
    with open(path or ADDONS_JSON, encoding="utf-8") as f:
        return json.load(f)


def targets(path=None):
    """`addons.json` の並び順で Target を返す。"""
    return [Target(e) for e in load_entries(path)]


def target_by_id(addon_id, path=None):
    found = [t for t in targets(path) if t.id == addon_id]
    if len(found) != 1:
        raise SystemExit(
            f'[targets] addons.json の file == "{addon_id}" のエントリが {len(found)} 件'
            "（ちょうど 1 件であること）")
    return found[0]


def as_dict(target):
    """ワークフローへ渡す形（.github/workflows/release.yml の matrix 1 件）。"""
    return {
        "id": target.id,
        "title": target.title,
        "version": target.version,
        "dir": target.dir_rel,
        "ipf": target.ipf_name,
        "asset": target.asset_name,
        "tag": target.release_tag,
        "archive_tag": target.archive_tag,
    }


if __name__ == "__main__":
    import sys

    if sys.argv[1:] != ["--json"]:
        raise SystemExit("  使い方: python docs/addon_targets.py --json")
    # ensure_ascii=False にしない（GitHub Actions の出力に載るので ASCII で揃える）
    print(json.dumps([as_dict(t) for t in targets()]))
