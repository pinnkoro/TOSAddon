# -*- coding: utf-8 -*-
"""配布 .ipf が現在の src から作られたものかを検証する（リリース前チェック）。

`bundle_from_src.py --check` は「src と golden sha」の一致しか見ないので、
「src を直したが .ipf を再ビルドしていない」を検出できない。.ipf は暗号化された
バイナリで git 上は不透明なため、そのまま release に流すと**中身が旧版のまま
新バージョンとして配布される**。それを止めるのがこのスクリプト。

■ 検証するのは `addons.json` の全エントリ

配布物は 1 本ではない（Nexus Addons P と Icor Planner）。対象の一覧と置き場所は
[addon_targets.py](addon_targets.py) が `addons.json` から導く。ここで 1 本決め打ちに
すると、**もう片方だけ古い .ipf のまま公開される**（検査を素通りする）。

■ なぜ復号せずに照合できるか

配布 .ipf は「平文コンテナ → PKware 暗号化」の 2 層だが、暗号化されるのは**各ファイルの
データ本体だけ**で、末尾のファイルテーブルと footer は平文のまま残る。テーブルには
各ファイルの

    checksum(u32) = 平文の CRC32 / uncomp(u32) = 平文の byte 数

が入っている（docs/build_addon_ipf.py が書き込んでいる値そのもの）。よって
src から期待される中身を組み立てて (長さ, CRC32) を突き合わせれば、復号鍵なしで
「この .ipf の中身は現 src と同じか」を判定できる。

    ※ CRC32 は 32bit なので暗号学的な完全性保証ではない。ここで欲しいのは
      「再ビルドし忘れ」の検出であり、長さ一致と併せれば十分に目的を満たす。
      悪意ある改竄の検出用途には使わないこと。

■ 併せてバージョンの三者一致も見る

    <addon>/src/**/00_header.lua の ver
    addons.json の fileVersion
    <addon>/*.ipf のファイル名

は手書きで 3 箇所に散っており、ズレたまま公開すると配布物とアドオンマネージャーの
表示が食い違う。

使い方:
    python docs/verify_ipf.py                  # 全エントリの中身 + バージョン
    python docs/verify_ipf.py --addon icor_planner
    python docs/verify_ipf.py --version-only
    python docs/verify_ipf.py --content-only

終了コード: 0 = 全一致 / 1 = 不一致（メッセージに再ビルド手順を出す）
"""
import binascii
import glob
import os
import re
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, HERE)

import addon_targets  # noqa: E402
import bundle_from_src  # noqa: E402  (同ディレクトリのビルド定義を正として再利用)

SHARED_SRC = os.path.join(REPO, "shared", "src")


def rebuild_hint(target):
    return (
        f"  → src を変更したら .ipf を作り直すこと（docs/BUILD_IPF.md 方式B）:\n"
        f"       python docs/bundle_from_src.py\n"
        f"       python docs/build_addon_ipf.py ./{target.dir_rel} {target.addon_folder} \\\n"
        f'           "{target.dir_rel}/{target.ipf_name}" \\\n'
        f"           --require {target.addon_folder}/{target.addon_folder}.lua \\\n"
        f"           --encrypt")


def find_ipf(target):
    """そのアドオンの直下にある配布 .ipf を 1 個だけ特定する。"""
    found = sorted(glob.glob(os.path.join(target.dir, "*.ipf")))
    if not found:
        raise SystemExit(
            f"[verify] {target.dir_rel} 直下に .ipf が無い\n"
            "  addons.json に載せた版は Release から取りに行かれるので、"
            "配布する .ipf を commit すること")
    if len(found) > 1:
        names = "\n  ".join(os.path.basename(p) for p in found)
        raise SystemExit(
            f"[verify] {target.dir_rel} 直下に .ipf が複数ある（旧版は _old/ へ移すこと）:\n  "
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


def tracked_bundle_files(target):
    """bundle ディレクトリ配下の *追跡されている* ファイルを内部パスで返す。

    ディスクを walk して集めると、未追跡の作業ファイル（.bak / .orig / 手で展開した
    残骸）まで期待値に混ざる。build_addon_ipf.py も同じくディスクを walk して詰めるので、
    手元では「.ipf にも期待値にも在る」ので通ってしまい、追跡ファイルしか無い CI で
    初めて落ちる。しかもメッセージは「.ipf にだけ在る」となり原因を指さない。
    追跡ファイルを正とすれば、手元と CI で同じ判定になる。
    """
    try:
        out = subprocess.run(["git", "ls-files", "-z", "--", target.bundle_dir],
                             cwd=REPO, check=True, capture_output=True).stdout
    except (OSError, subprocess.CalledProcessError) as exc:
        raise SystemExit(f"[verify] git ls-files を実行できない: {exc}")
    repo_rels = [p for p in out.decode("utf-8").split("\0") if p]
    return {
        os.path.relpath(os.path.join(REPO, p), target.dir).replace("\\", "/"): os.path.join(REPO, p)
        for p in repo_rels
    }


def stray_untracked(target, built):
    """bundle ディレクトリに在る未追跡ファイル（生成物 .lua を除く）を返す。"""
    known = set(tracked_bundle_files(target))
    known |= {f"{target.addon_folder}/{name}" for name in built}
    strays = []
    for dirpath, _dirs, names in os.walk(target.bundle_dir):
        for name in names:
            rel = os.path.relpath(os.path.join(dirpath, name), target.dir).replace("\\", "/")
            if rel not in known:
                strays.append(rel)
    return sorted(strays)


def pack_targets(manifest, built, target):
    """この .ipf に詰まる生成物だけを返す。

    build_manifest.json は 1 本で複数のアドオンの bundle を組み立てる
    （icor_planner を足したときからそうなった）。manifest の outputs が指す出力先が
    このアドオンの bundle ディレクトリでないものは、この .ipf には入らない。
    ここで絞らないと「_nexus_addons_p/_icor_planner.lua が .ipf に入っていない」という
    的外れな不一致になり、release 経路の ipf ジョブが常に落ちる。
    """
    want_dir = os.path.normpath(target.bundle_dir)
    keep = {}
    for name, data in built.items():
        # 出力先の正本は bundle_from_src.bundle_dir_for。**未指定の既定はまとめ版行き**
        # なので、ここで自前に判定を書くと「未指定だから対象外」と逆に取りかねない
        # （docs/check_forward_refs.py / docs/tests/syntax_check.sh も既定はまとめ版行き）。
        if os.path.normpath(bundle_from_src.bundle_dir_for(manifest, name)) == want_dir:
            keep[name] = data
    return keep


def expected_contents(target, built):
    """{内部パス: 平文bytes} を組み立てる。

    bundle の .lua は .gitignore 済みなので、ディスクではなく manifest から
    その場で連結して作る（CI の素のチェックアウトでも動くようにするため）。
    それ以外（.xml）は *追跡されている* 実ファイルを正とする。
    """
    out = {}
    for rel, full in tracked_bundle_files(target).items():
        with open(full, "rb") as f:
            out[rel] = f.read()
    # 生成物はディスクの内容（古いかもしれない）ではなく src 連結結果で上書きする
    for name, data in built.items():
        out[f"{target.addon_folder}/{name}"] = data
    return out


def check_content(target, ipf_path, manifest, all_built):
    # 詰めるのはこの .ipf 向けの生成物だけ
    built = pack_targets(manifest, all_built, target)
    if not built:
        print(f"\n[verify] {target.id}: build_manifest.json に "
              f"{target.bundle_dir_rel} へ出力するターゲットが無い"
              "（outputs の登録漏れ。この .ipf には本体が入らない）")
        return False
    expected = expected_contents(target, built)
    actual = read_ipf_table(ipf_path)

    problems = []
    for name in stray_untracked(target, built):
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
        print(f"\n[verify] {target.id}: .ipf が現在の src と一致しない:")
        for p in problems:
            print(f"    - {p}")
        print(rebuild_hint(target))
        return False
    return True


def check_version(target, ipf_path):
    """ver / fileVersion / .ipf ファイル名 の三者一致。表記は 'vX.Y.Z' に正規化。"""
    with open(target.header_lua, encoding="utf-8") as f:
        m = re.search(r'^local\s+ver\s*=\s*"([^"]+)"', f.read(), re.M)
    if not m:
        raise SystemExit(f"[verify] {target.header_lua_rel} から ver を読めない")
    lua_ver = addon_targets.norm_version(m.group(1))

    # addons.json 側は位置（[0]）ではなく永続 ID の file で引いてある（addon_targets.py）。
    json_ver = target.version

    base = os.path.basename(ipf_path)
    m = re.search(r"-(v\d+\.\d+\.\d+)\.ipf$", base)
    if not m:
        raise SystemExit(
            f"[verify] .ipf のファイル名からバージョンを読めない: {base}\n"
            f"  想定形式: {target.addon_folder}-⛄-vX.Y.Z.ipf")
    ipf_ver = m.group(1)

    print(f"  ver         : {lua_ver}  ({target.header_lua_rel})")
    print(f"  fileVersion : {json_ver}  (addons.json)")
    print(f"  .ipf の名前 : {ipf_ver}  ({base})")
    if lua_ver == json_ver == ipf_ver:
        return True
    print(f"\n[verify] {target.id}: バージョンが一致しない。3 箇所すべてを揃えること:\n"
          f"    {target.header_lua_rel} の ver\n"
          f"    addons.json の fileVersion（file == \"{target.id}\"）\n"
          f"    {target.dir_rel}/*.ipf のファイル名")
    return False


def check_next_placeholder(targets):
    """更新のお知らせの since / updated に "next"（未採番の印）が残っていないか。

    main へ入れる PR では版を上げない（先行採番の禁止）ので、開発中の since / updated には
    g.VER_NEXT = "next" を書く。これは**どの版よりも新しいもの**として扱われるため、
    置き換えを忘れたまま配布すると NEW / 更新 の印が永久に消えない。
    release-prep / release でしか走らない検査なので、開発中に引っかかることはない。

    共通部品（shared/src）は全アドオンの .ipf に入るので、対象の一覧へ必ず含める。
    """
    next_re = re.compile(r"^\s*(?:since|updated)\s*=\s*(?:core_)?g\.VER_NEXT", re.M)
    roots = [t.src for t in targets] + [SHARED_SRC]
    ng = []
    for root in roots:
        for dirpath, _dirs, files in os.walk(root):
            for name in sorted(files):
                if not name.endswith(".lua"):
                    continue
                path = os.path.join(dirpath, name)
                with open(path, encoding="utf-8") as f:
                    text = f.read()
                if next_re.search(text):
                    ng.append(f"{os.path.relpath(path, REPO)}: "
                              "since / updated が未採番（g.VER_NEXT）のまま")
    if not ng:
        print("  未採番（g.VER_NEXT）の残りなし")
        return True
    print("\n[verify] 未採番の印が残っている。実際の版へ置き換えること:")
    for line in sorted(set(ng)):
        print(f"    {line}")
    print("    ※ README の更新履歴の見出しを vX.Y.Z に確定させるのと同じ PR で置き換えること")
    return False


USAGE = ("  使い方: python docs/verify_ipf.py "
         "[--version-only | --content-only] [--addon <id>]")


def parse_args(args):
    """引数を (version_only, content_only, addon_id) にする。

    リリースを止めるためのゲートなので、「何も検証しないまま成功」だけは作らない。
    未知の引数と、両方指定（= 全分岐スキップ）はここで弾く。
    """
    version_only = content_only = False
    addon_id = None
    rest = list(args)
    while rest:
        a = rest.pop(0)
        if a == "--version-only":
            version_only = True
        elif a == "--content-only":
            content_only = True
        elif a == "--addon":
            if not rest:
                raise SystemExit("[verify] --addon にアドオン ID が無い\n" + USAGE)
            addon_id = rest.pop(0)
        elif a.startswith("--addon="):
            addon_id = a.split("=", 1)[1]
        else:
            raise SystemExit("[verify] 未知の引数: " + a + "\n" + USAGE)
    if version_only and content_only:
        raise SystemExit(
            "[verify] --version-only と --content-only は同時に指定できない"
            "（何も検証しないまま成功扱いになるため）\n" + USAGE)
    return version_only, content_only, addon_id


def main():
    version_only, content_only, addon_id = parse_args(sys.argv[1:])

    if addon_id:
        targets = [addon_targets.target_by_id(addon_id)]
    else:
        targets = addon_targets.targets()
    print("[verify] 対象: " + ", ".join(t.id for t in targets))

    manifest = bundle_from_src.load_manifest()
    # manifest 脱落チェックもここで走る（build() 内）。全ターゲットを 1 回だけ組み立て、
    # 各 .ipf へはそれぞれの出力先のぶんだけ詰める。
    all_built = bundle_from_src.build(manifest) if not version_only else {}

    ok = True
    for target in targets:
        ipf_path = find_ipf(target)
        print(f"\n[verify] {target.id}: {os.path.relpath(ipf_path, REPO)}")
        if not version_only:
            print("[verify] .ipf の中身と src の照合（テーブルの CRC32/長さで比較）")
            ok &= check_content(target, ipf_path, manifest, all_built)
        if not content_only:
            print("[verify] バージョンの三者一致")
            ok &= check_version(target, ipf_path)

    if not content_only:
        print("\n[verify] 更新のお知らせの未採番チェック")
        ok &= check_next_placeholder(targets)

    print("[verify] OK" if ok else "[verify] NG")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
