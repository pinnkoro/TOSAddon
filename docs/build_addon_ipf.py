#!/usr/bin/env python3
"""
Tree of Savior アドオン .ipf の「平文(decrypted)コンテナ」を生成するパッカー。

配布用 .ipf は 2 層構造:
    1. 平文コンテナ  … 各ファイルを raw deflate 圧縮して 1 つにまとめたもの
    2. PKware 暗号化 … 上を暗号化したもの(= 配布形式)

本スクリプトは 1 の平文コンテナのみを生成する。2 の暗号化は実績のある
`ipf_unpack.exe <file> encrypt`(TOSAddon_Tools/workspace)で行うこと。

コンテナ書式(_nexus_addons_p-⛄-v1.1.6.ipf を解析して確定):
    各ファイル : raw deflate(zlib level 6 = IPFSuite と同一バイト)
    テーブル項目 : path_len(u16) checksum(u32=平文のCRC32) comp(u32)
                   uncomp(u32) data_off(u32) packname_len(u16) packname path
    packname   : 常に b"addon_d.ipf"
    footer(24B): file_count(u16) table_off(u32) 0(u16)
                 最終ファイルのdata_off(u32) "PK\\x05\\x06" 0(u32) 0(u32)

使い方:
    python build_addon_ipf.py <addon_source_dir> <addon_name> <out.ipf>
                              [--require <内部パス[,内部パス...]>]
例:
    python build_addon_ipf.py ./nexus_addons_p _nexus_addons_p ./_nexus_addons_p.ipf
    ( ./nexus_addons_p/_nexus_addons_p/ 配下の全ファイルを詰める )

--require:
    コンテナに必ず含まれていなければならない内部パスを指定する（複数可 / カンマ区切り可）。
    nexus_addons_p の bundle .lua は .gitignore 済みの生成物なので、bundle_from_src.py を
    先に走らせ忘れると本体を欠いた .ipf が「成功」表示で作られてしまう。それを防ぐため、
    生成物を必須指定して不在なら失敗させる:
        --require _nexus_addons_p/_nexus_addons_p.lua,_nexus_addons_p/_nexus_addons_p_conclude.lua
"""
import os
import sys
import zlib
import struct
import binascii

PACKNAME = b"addon_d.ipf"


def deflate(data: bytes) -> bytes:
    # level 6 = stock zlib 既定。IPFSuite の deflate 出力とバイト一致する。
    co = zlib.compressobj(6, zlib.DEFLATED, -15)  # raw deflate (wbits=-15)
    return co.compress(data) + co.flush()


def collect_files(src_dir: str, addon: str):
    """<src_dir>/<addon>/ 配下を再帰的に集め、(内部パス, bytes) を内部パス昇順で返す。

    内部パスは "addon/相対パス"(区切りは "/")。昇順ソートで元 ipf と同じ並びを
    再現する(例: _nexus_addons_p.lua → .xml → _conclude.lua)。
    """
    root = os.path.join(src_dir, addon)
    if not os.path.isdir(root):
        raise SystemExit(f"アドオンフォルダが無い: {root}")
    items = []
    for dirpath, _dirs, names in os.walk(root):
        for name in names:
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, src_dir).replace("\\", "/")
            with open(full, "rb") as f:
                items.append((rel, f.read()))
    items.sort(key=lambda x: x[0])
    return items


def build_ipf(files, out_path: str) -> str:
    """files: [(内部パス, 平文bytes), ...] を平文コンテナにして書き出す。"""
    body = bytearray()
    entries = []
    for path, plain in files:
        comp = deflate(plain)
        data_off = len(body)
        body += comp
        entries.append((path, plain, comp, data_off))

    table_off = len(body)
    last_data_off = entries[-1][3]

    table = bytearray()
    for path, plain, comp, data_off in entries:
        pb = path.encode("ascii")
        crc = binascii.crc32(plain) & 0xFFFFFFFF
        table += struct.pack("<H", len(pb))
        table += struct.pack("<I", crc)
        table += struct.pack("<I", len(comp))
        table += struct.pack("<I", len(plain))
        table += struct.pack("<I", data_off)
        table += struct.pack("<H", len(PACKNAME))
        table += PACKNAME
        table += pb

    footer = struct.pack("<H", len(entries))
    footer += struct.pack("<I", table_off)
    footer += struct.pack("<H", 0)
    footer += struct.pack("<I", last_data_off)
    footer += b"\x50\x4b\x05\x06"
    footer += struct.pack("<I", 0)
    footer += struct.pack("<I", 0)

    with open(out_path, "wb") as f:
        f.write(bytes(body) + bytes(table) + footer)
    return out_path


def parse_args(argv):
    """(positional, required_paths) を返す。--require は複数/カンマ区切り可。"""
    positional, required = [], []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--require":
            i += 1
            if i >= len(argv):
                raise SystemExit("--require には内部パスの指定が必要")
            required += [p for p in argv[i].split(",") if p]
        elif a.startswith("--require="):
            required += [p for p in a[len("--require="):].split(",") if p]
        else:
            positional.append(a)
        i += 1
    return positional, required


def main():
    positional, required = parse_args(sys.argv[1:])
    if len(positional) != 3:
        print(__doc__)
        raise SystemExit(2)
    src_dir, addon, out = positional
    files = collect_files(src_dir, addon)
    # bundle 未生成のまま詰めて壊れた .ipf を黙って出すのを防ぐ。
    if not files:
        raise SystemExit(f"アドオンフォルダが空: {os.path.join(src_dir, addon)}")
    present = {p for p, _ in files}
    missing = [r for r in required if r not in present]
    if missing:
        raise SystemExit(
            "[ipf] 必須ファイルがコンテナに含まれない（bundle 未生成の可能性）:\n  "
            + "\n  ".join(missing)
            + "\n  → 先に `python docs/bundle_from_src.py` を実行すること。")
    build_ipf(files, out)
    print(f"built(plain): {out}  ({len(files)} files)")
    for p, b in files:
        print(f"  - {p}  ({len(b)} bytes)")
    print("次に暗号化: ipf_unpack.exe", out, "encrypt")


if __name__ == "__main__":
    main()
