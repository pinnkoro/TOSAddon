# -*- coding: utf-8 -*-
"""配布 .ipf が現在の src から作られたものかを検証する（リリース前チェック）。

`bundle_from_src.py --check` は「src と golden sha」の一致しか見ないので、
「src を直したが .ipf を再ビルドしていない」を検出できない。.ipf は暗号化された
バイナリで git 上は不透明なため、そのまま release に流すと**中身が旧版のまま
新バージョンとして配布される**。それを止めるのがこのスクリプト。

■ なぜ復号せずに照合できるか

配布 .ipf は「平文コンテナ → PKware 暗号化」の 2 層だが、`ipf_unpack.exe encrypt`
が暗号化するのは**各ファイルのデータ本体だけ**で、末尾のファイルテーブルと footer は
平文のまま残る。テーブルには各ファイルの

    checksum(u32) = 平文の CRC32 / uncomp(u32) = 平文の byte 数

が入っている（docs/build_addon_ipf.py が書き込んでいる値そのもの）。よって
src から期待される中身を組み立てて (長さ, CRC32) を突き合わせれば、復号鍵なしで
「この .ipf の中身は現 src と同じか」を判定できる。

    ※ CRC32 は 32bit なので暗号学的な完全性保証ではない。ここで欲しいのは
      「再ビルドし忘れ」の検出であり、長さ一致と併せれば十分に目的を満たす。
      悪意ある改竄の検出用途には使わないこと。

■ 併せてバージョンの三者一致も見る

    nexus_addons_p/src/core/00_header.lua の ver
    addons.json の fileVersion
    nexus_addons_p/*.ipf のファイル名

は手書きで 3 箇所に散っており、ズレたまま公開すると配布物とアドオンマネージャーの
表示が食い違う。

使い方:
    python docs/verify_ipf.py          # 中身 + バージョンの両方を検証
    python docs/verify_ipf.py --version-only
    python docs/verify_ipf.py --content-only

終了コード: 0 = 全一致 / 1 = 不一致（メッセージに再ビルド手順を出す）
"""
import binascii
import glob
import json
import os
import re
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, HERE)

import bundle_from_src  # noqa: E402  (同ディレクトリのビルド定義を正として再利用)

ADDON = "_nexus_addons_p"
ADDON_ID = "nexus_addons_p"  # addons.json の file（一度決めたら変えられない永続 ID）
PACK_ROOT = os.path.join(REPO, "nexus_addons_p")  # .ipf 内部パスはここからの相対
BUNDLE_DIR = os.path.join(REPO, "nexus_addons_p", ADDON)
ADDONS_JSON = os.path.join(REPO, "addons.json")
HEADER_LUA = os.path.join(REPO, "nexus_addons_p", "src", "core", "00_header.lua")
IPF_GLOB = os.path.join(REPO, "nexus_addons_p", "*.ipf")

REBUILD_HINT = (
    "  → src を変更したら .ipf を作り直すこと（docs/BUILD_IPF.md 方式B）:\n"
    "       python docs/bundle_from_src.py\n"
    "       python docs/build_addon_ipf.py ./nexus_addons_p _nexus_addons_p "
    "./_nexus_addons_p-plain.ipf \\\n"
    "           --require _nexus_addons_p/_nexus_addons_p.lua,"
    "_nexus_addons_p/_nexus_addons_p_conclude.lua\n"
    '       "$TOOLS_DIR/ipf_unpack.exe" ./_nexus_addons_p-plain.ipf encrypt')


def find_ipf():
    """nexus_addons_p 直下の配布 .ipf を 1 個だけ特定する。"""
    found = sorted(glob.glob(IPF_GLOB))
    if not found:
        raise SystemExit("[verify] nexus_addons_p 直下に .ipf が無い")
    if len(found) > 1:
        names = "\n  ".join(os.path.basename(p) for p in found)
        raise SystemExit(
            "[verify] nexus_addons_p 直下に .ipf が複数ある（旧版は _old/ へ移すこと）:\n  "
            + names)
    return found[0]


def read_ipf_table(path):
    """{内部パス: (uncomp_len, crc32)} を返す。データ本体は復号しない。"""
    with open(path, "rb") as f:
        data = f.read()
    if len(data) < 24:
        raise SystemExit(f"[verify] .ipf が小さすぎる: {path}")
    footer = data[-24:]
    count, table_off, _zero, _last_off = struct.unpack("<HIHI", footer[:12])
    if footer[12:16] != b"PK\x05\x06":
        raise SystemExit(
            "[verify] footer の magic が PK\\x05\\x06 でない。"
            "想定外の .ipf 形式（docs/BUILD_IPF.md の書式を参照）")
    if not 0 < table_off < len(data):
        raise SystemExit("[verify] footer の table_off が範囲外")

    entries = {}
    off = table_off
    for _ in range(count):
        (path_len,) = struct.unpack_from("<H", data, off); off += 2
        crc, _comp, uncomp, _doff = struct.unpack_from("<IIII", data, off); off += 16
        (pack_len,) = struct.unpack_from("<H", data, off); off += 2 + pack_len
        name = data[off:off + path_len].decode("ascii"); off += path_len
        entries[name] = (uncomp, crc)
    return entries


def tracked_bundle_files():
    """bundle ディレクトリ配下の *追跡されている* ファイルを内部パスで返す。

    ディスクを walk して集めると、未追跡の作業ファイル（.bak / .orig / 手で展開した
    残骸）まで期待値に混ざる。build_addon_ipf.py も同じくディスクを walk して詰めるので、
    手元では「.ipf にも期待値にも在る」ので通ってしまい、追跡ファイルしか無い CI で
    初めて落ちる。しかもメッセージは「.ipf にだけ在る」となり原因を指さない。
    追跡ファイルを正とすれば、手元と CI で同じ判定になる。
    """
    try:
        out = subprocess.run(["git", "ls-files", "-z", "--", BUNDLE_DIR],
                             cwd=REPO, check=True, capture_output=True).stdout
    except (OSError, subprocess.CalledProcessError) as exc:
        raise SystemExit(f"[verify] git ls-files を実行できない: {exc}")
    repo_rels = [p for p in out.decode("utf-8").split("\0") if p]
    return {
        os.path.relpath(os.path.join(REPO, p), PACK_ROOT).replace("\\", "/"): os.path.join(REPO, p)
        for p in repo_rels
    }


def stray_untracked(built):
    """bundle ディレクトリに在る未追跡ファイル（生成物 .lua を除く）を返す。"""
    known = set(tracked_bundle_files())
    known |= {f"{ADDON}/{target}" for target in built}
    strays = []
    for dirpath, _dirs, names in os.walk(BUNDLE_DIR):
        for name in names:
            rel = os.path.relpath(os.path.join(dirpath, name), PACK_ROOT).replace("\\", "/")
            if rel not in known:
                strays.append(rel)
    return sorted(strays)


def expected_contents(built):
    """{内部パス: 平文bytes} を組み立てる。

    bundle の .lua は .gitignore 済みなので、ディスクではなく manifest から
    その場で連結して作る（CI の素のチェックアウトでも動くようにするため）。
    それ以外（.xml）は *追跡されている* 実ファイルを正とする。
    """
    out = {}
    for rel, full in tracked_bundle_files().items():
        with open(full, "rb") as f:
            out[rel] = f.read()
    # 生成物はディスクの内容（古いかもしれない）ではなく src 連結結果で上書きする
    for target, data in built.items():
        out[f"{ADDON}/{target}"] = data
    return out


def check_content(ipf_path):
    manifest = bundle_from_src.load_manifest()
    built = bundle_from_src.build(manifest)  # manifest 脱落チェックもここで走る
    expected = expected_contents(built)
    actual = read_ipf_table(ipf_path)

    problems = []
    for name in stray_untracked(built):
        problems.append(
            f"{name}: bundle ディレクトリに未追跡ファイルが在る"
            "（build_addon_ipf.py はこれも .ipf に詰めてしまう。削除するか commit すること）")
    missing = sorted(set(expected) - set(actual))
    extra = sorted(set(actual) - set(expected))
    for name in missing:
        problems.append(f"{name}: .ipf に入っていない")
    for name in extra:
        problems.append(f"{name}: .ipf にだけ在る（src 側に対応が無い）")

    for name in sorted(set(expected) & set(actual)):
        want = expected[name]
        want_len, want_crc = len(want), binascii.crc32(want) & 0xFFFFFFFF
        got_len, got_crc = actual[name]
        if (want_len, want_crc) == (got_len, got_crc):
            print(f"  {name}: 一致 ({got_len}B crc={got_crc:08x})")
        else:
            problems.append(
                f"{name}: 中身が違う\n"
                f"      src から期待 : {want_len}B crc={want_crc:08x}\n"
                f"      .ipf の中身  : {got_len}B crc={got_crc:08x}")

    if problems:
        print("\n[verify] .ipf が現在の src と一致しない:")
        for p in problems:
            print(f"    - {p}")
        print(REBUILD_HINT)
        return False
    return True


def check_version(ipf_path):
    """ver / fileVersion / .ipf ファイル名 の三者一致。表記は 'vX.Y.Z' に正規化。"""
    def norm(v):
        return v if v.startswith("v") else "v" + v

    with open(HEADER_LUA, encoding="utf-8") as f:
        m = re.search(r'^local\s+ver\s*=\s*"([^"]+)"', f.read(), re.M)
    if not m:
        raise SystemExit(f"[verify] {HEADER_LUA} から ver を読めない")
    lua_ver = norm(m.group(1))

    # 位置（[0]）ではなく永続 ID の file で引く。このリポジトリは複数アドオンを
    # 収録しうるので、先頭決め打ちだと別アドオンの版数と突き合わせてしまう。
    with open(ADDONS_JSON, encoding="utf-8") as f:
        entries = json.load(f)
    matched = [e for e in entries if e.get("file") == ADDON_ID]
    if len(matched) != 1:
        raise SystemExit(
            f'[verify] addons.json の file == "{ADDON_ID}" のエントリが {len(matched)} 件'
            "（ちょうど 1 件であること）")
    json_ver = norm(matched[0]["fileVersion"])

    base = os.path.basename(ipf_path)
    m = re.search(r"-(v\d+\.\d+\.\d+)\.ipf$", base)
    if not m:
        raise SystemExit(
            f"[verify] .ipf のファイル名からバージョンを読めない: {base}\n"
            "  想定形式: _nexus_addons_p-⛄-vX.Y.Z.ipf")
    ipf_ver = m.group(1)

    print(f"  00_header.lua ver : {lua_ver}")
    print(f"  addons.json       : {json_ver}")
    print(f"  .ipf ファイル名   : {ipf_ver}")
    if lua_ver == json_ver == ipf_ver:
        return True
    print("\n[verify] バージョンが一致しない。3 箇所すべてを揃えること:\n"
          "    nexus_addons_p/src/core/00_header.lua の ver\n"
          "    addons.json の fileVersion\n"
          "    nexus_addons_p/*.ipf のファイル名")
    return False


USAGE = "  使い方: python docs/verify_ipf.py [--version-only | --content-only]"


def main():
    # リリースを止めるためのゲートなので、「何も検証しないまま成功」だけは作らない。
    # 未知の引数と、両方指定（= 全分岐スキップ）はここで弾く。
    args = sys.argv[1:]
    unknown = [a for a in args if a not in ("--version-only", "--content-only")]
    if unknown:
        raise SystemExit("[verify] 未知の引数: " + " ".join(unknown) + "\n" + USAGE)
    version_only = "--version-only" in args
    content_only = "--content-only" in args
    if version_only and content_only:
        raise SystemExit(
            "[verify] --version-only と --content-only は同時に指定できない"
            "（何も検証しないまま成功扱いになるため）\n" + USAGE)
    ipf_path = find_ipf()
    print(f"[verify] 対象 .ipf: {os.path.relpath(ipf_path, REPO)}")

    ok = True
    if not version_only:
        print("[verify] .ipf の中身と src の照合（テーブルの CRC32/長さで比較）")
        ok &= check_content(ipf_path)
    if not content_only:
        print("[verify] バージョンの三者一致")
        ok &= check_version(ipf_path)

    print("[verify] OK" if ok else "[verify] NG")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
