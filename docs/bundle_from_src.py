# -*- coding: utf-8 -*-
"""nexus_addons_p/src/**  を連結して配布用 bundle（2 ファイル）を生成する。

これがビルド時の正の入口。manifest の順に src ファイルの中身を raw 連結して
    nexus_addons_p/_nexus_addons_p/_nexus_addons_p.lua
    nexus_addons_p/_nexus_addons_p/_nexus_addons_p_conclude.lua
を書き出す（この 2 ファイルは .gitignore 済みの生成物）。

再現性ガード:
    - manifest["sha256"] に各ターゲットの golden ハッシュを持つ。連結結果がこれと
      一致しなければ生成/検証を失敗させる（CRLF 混入や src の誤編集を検知）。
    - manifest["targets"] の parts 集合と src/** の実 .lua 集合が一致しなければ失敗
      させる（manifest 追記漏れ＝ビルドからの黙った脱落を検知）。
    意図した変更で golden を更新するときは --bless を使う。

使い方:
    python docs/bundle_from_src.py           # src -> bundle を生成（+ 上記ガード）
    python docs/bundle_from_src.py --check    # 生成せず、再現性ガードのみ実行
                                              #（既存 bundle の有無に依存しない）
    python docs/bundle_from_src.py --bless     # 現 src の連結結果で golden sha を更新

生成後、この bundle を docs/build_addon_ipf.py に渡して .ipf 化する。
"""
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
SRC = os.path.join(REPO, "nexus_addons_p", "src")
MANIFEST = os.path.join(SRC, "build_manifest.json")
BUNDLE_DIR = os.path.join(REPO, "nexus_addons_p", "_nexus_addons_p")


def load_manifest():
    with open(MANIFEST, encoding="utf-8") as f:
        return json.load(f)


def all_src_lua():
    """src/** 配下の実 .lua を manifest 表記（"/" 区切りの相対パス）の集合で返す。"""
    found = set()
    for dirpath, _dirs, names in os.walk(SRC):
        for name in names:
            if name.endswith(".lua"):
                full = os.path.join(dirpath, name)
                found.add(os.path.relpath(full, SRC).replace("\\", "/"))
    return found


def build(manifest):
    """{target: bytes} を返す。src 欠落・orphan があれば SystemExit。"""
    targets = manifest["targets"]

    referenced = set()
    out = {}
    for target, rels in targets.items():
        parts = []
        for rel in rels:
            referenced.add(rel)
            path = os.path.join(SRC, rel)
            if not os.path.isfile(path):
                raise SystemExit(f"[bundle] src が無い: {rel}")
            with open(path, "rb") as f:
                data = f.read()
            # part 間には必ず改行境界を入れる。末尾改行を欠く src があっても、直前ファイルの
            # 最終トークンと次ファイル先頭トークンが結合(例: end + function → endfunction)して
            # 壊れた bundle が黙って生成されるのを防ぐ。既に改行で終わる part には足さないので、
            # 全 src が末尾 LF の現状では連結結果は不変(golden sha も変わらない)。
            if parts and not parts[-1].endswith(b"\n"):
                parts.append(b"\n")
            parts.append(data)
        out[target] = b"".join(parts)

    # manifest に未登録の src .lua があれば黙って脱落するので失敗させる。
    orphans = sorted(all_src_lua() - referenced)
    if orphans:
        raise SystemExit(
            "[bundle] manifest 未登録の src ファイル（ビルドから脱落）:\n  "
            + "\n  ".join(orphans))
    return out


def verify_sha(manifest, out):
    """連結結果を golden sha256 と照合。全一致なら True。"""
    expected = manifest.get("sha256", {})
    ok = True
    for target, data in out.items():
        got = hashlib.sha256(data).hexdigest()
        exp = expected.get(target)
        same = (exp == got)
        ok = ok and same
        if same:
            print(f"  {target}: sha256 OK ({len(data)}B)")
        else:
            print(f"  {target}: sha256 MISMATCH ({len(data)}B)\n"
                  f"      expected {exp}\n      got      {got}")
    if not ok:
        print("  → 意図した変更なら `python docs/bundle_from_src.py --bless` "
              "で golden を更新すること。")
    return ok


def main():
    manifest = load_manifest()

    if "--bless" in sys.argv:
        out = build(manifest)
        manifest.setdefault("sha256", {})
        for target, data in out.items():
            manifest["sha256"][target] = hashlib.sha256(data).hexdigest()
        # newline="\n": Windows でも LF 固定（CRLF になると git が毎回差分検出する）。
        with open(MANIFEST, "w", encoding="utf-8", newline="\n") as f:
            json.dump(manifest, f, ensure_ascii=False, indent=2)
            f.write("\n")
        for target, data in out.items():
            print(f"  blessed {target}: {manifest['sha256'][target]}")
        sys.exit(0)

    check_only = "--check" in sys.argv
    out = build(manifest)

    if check_only:
        print("[bundle --check] 既存 bundle に依存せず再現性を検証")
        sys.exit(0 if verify_sha(manifest, out) else 1)

    if not verify_sha(manifest, out):
        sys.exit(1)

    for target, data in out.items():
        dst = os.path.join(BUNDLE_DIR, target)
        old = open(dst, "rb").read() if os.path.isfile(dst) else None
        with open(dst, "wb") as f:
            f.write(data)
        note = "" if old is None else (
            " (unchanged)" if old == data else " (CHANGED)")
        print(f"  wrote {target}: {len(data)}B{note}")
    sys.exit(0)


if __name__ == "__main__":
    main()
