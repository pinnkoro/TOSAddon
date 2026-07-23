# -*- coding: utf-8 -*-
"""IPF コンテナの PKware 暗号化 / 復号（配布形式への変換）。

配布 .ipf は「平文コンテナ → PKware 暗号化」の 2 層。従来この 2 層目だけは
リポジトリ外の Windows 実行ファイル（`ipf_unpack.exe <file> encrypt`）を手で
叩くしかなく、ビルドを最後まで自動化できなかった。アドオンを個別配布する
（= 1 リリースで .ipf を何十個も作る）には手作業が残っていると回らないので、
ここで Python 実装に置き換える。

■ 方式（実測で確定）

    暗号化されるのは各ファイルの *データ本体* だけ。末尾のファイルテーブルと
    footer は平文のまま残る（だから復号鍵なしで docs/verify_ipf.py が中身を
    照合できる）。

    アルゴリズムは PKware(ZIP 伝統暗号)そのもので、次の 2 点だけが変種:

      1. 各ファイルのデータを *ファイル先頭からの相対位置が偶数* のバイトにだけ
         適用する（奇数位置は素通り。鍵更新も偶数位置のぶんしか回さない）
      2. 鍵はファイルごとに初期化し直す（コンテナ全体で連続させない）

    パスワードは固定の PW（下記）。クライアントが読む以上どこかに固定値がある
    種類のもので、秘密ではない。

■ 正しさの根拠

    配布中の `_nexus_addons_p-⛄-v1.0.2.ipf` を、現 src から組み立てた平文コンテナに
    この実装を適用して再生成すると **バイト単位で完全一致**する（259,788 バイト）。
    つまり `ipf_unpack.exe encrypt` の出力と区別が付かない。

    `--self-test` はこれを常時検査するが、**往復（復号 → 再暗号化）だけでは足りない**。
    暗号化と復号は同じ鍵ストリームを生成するので、`encrypt(decrypt(x)) == x` は
    PW もマスクも偶数位置の判定も何を壊しても成立する恒等式でしかない。
    実際に効かせている検査は「復号したデータ本体を raw deflate 展開して、
    テーブル記載の平文 CRC32 と一致するか」の方（テーブルは暗号化されないので、
    この実装を経由しない独立オラクルになる）。

使い方:
    python docs/ipf_crypt.py encrypt <in.ipf> <out.ipf>
    python docs/ipf_crypt.py decrypt <in.ipf> <out.ipf>
    python docs/ipf_crypt.py --self-test [<ipf>...]   # 既定はリポジトリ内の全 .ipf

終了コード: 0 = 成功 / 1 = 失敗
"""
import glob
import os
import struct
import sys
import zlib

# 固定パスワード。ToS クライアント側の IPF リーダーが持っている値で、
# 既存の読み取りツール（TosSukillSimulator の tools/tos_extract.py など）と同じ。
PW = b"ofO1a0ueXA? [\xffs h %?"

SIG = b"PK\x05\x06"
FOOTER_LEN = 24

_CRC = []
for _i in range(256):
    _c = _i
    for _ in range(8):
        _c = (_c >> 1) ^ 0xEDB88320 if _c & 1 else _c >> 1
    _CRC.append(_c & 0xFFFFFFFF)


def _transform(data: bytes, decrypt: bool) -> bytes:
    """1 ファイル分のデータ本体を変換する。

    PKware は鍵の更新に *平文* のバイトを使う自己同期式なので、暗号化と復号は
    「XOR したあとどちらの値で鍵を回すか」だけが違う。どちらも平文で回す。
    """
    keys = [0x12345678, 0x23456789, 0x34567890]

    def upd(v):
        keys[0] = (_CRC[(keys[0] ^ v) & 0xFF] ^ (keys[0] >> 8)) & 0xFFFFFFFF
        keys[1] = ((keys[1] + (keys[0] & 0xFF)) * 0x08088405 + 1) & 0xFFFFFFFF
        keys[2] = (_CRC[(keys[2] ^ ((keys[1] >> 24) & 0xFF)) & 0xFF] ^ (keys[2] >> 8)) & 0xFFFFFFFF

    for b in PW:
        upd(b)

    out = bytearray(data)
    for i in range(0, len(data), 2):  # 偶数位置のみ
        t = (keys[2] & 0xFFFF) | 2
        out[i] = data[i] ^ (((t * (t ^ 1)) >> 8) & 0xFF)
        # 鍵は常に平文で回す（暗号化なら入力、復号なら出力が平文）
        upd(data[i] if not decrypt else out[i])
    return bytes(out)


def parse_entries(data: bytes):
    """ファイルテーブルを読んで [(内部パス, data_off, comp_len, 平文 CRC32, 元サイズ), ...] を返す。

    テーブルと footer は暗号化されないので、暗号化済み .ipf でもそのまま読める。
    CRC32 と元サイズは復号結果の照合（_check_bodies）に使う。
    """
    if len(data) < FOOTER_LEN:
        raise ValueError(f".ipf が小さすぎる（{len(data)} バイト）")
    footer = data[-FOOTER_LEN:]
    count, table_off, _zero, _last_off = struct.unpack("<HIHI", footer[:12])
    if footer[12:16] != SIG:
        raise ValueError("footer の magic が PK\\x05\\x06 でない（想定外の .ipf 形式）")
    if not 0 < table_off <= len(data) - FOOTER_LEN:
        raise ValueError(f"footer の table_off が範囲外: {table_off}")

    entries = []
    off = table_off
    for _ in range(count):
        (path_len,) = struct.unpack_from("<H", data, off)
        off += 2
        crc, comp, uncomp, data_off = struct.unpack_from("<IIII", data, off)
        off += 16
        (pack_len,) = struct.unpack_from("<H", data, off)
        off += 2 + pack_len
        path = data[off:off + path_len].decode("ascii")
        off += path_len
        if data_off + comp > table_off:
            raise ValueError(f"{path}: データ範囲がテーブルへ食い込んでいる")
        entries.append((path, data_off, comp, crc, uncomp))
    if len(entries) != count:
        raise ValueError(f"テーブルの項目数が footer と合わない: {len(entries)} != {count}")
    return entries


def _apply(container: bytes, decrypt: bool) -> bytes:
    out = bytearray(container)
    for _path, data_off, comp, _crc, _uncomp in parse_entries(container):
        out[data_off:data_off + comp] = _transform(container[data_off:data_off + comp], decrypt)
    return bytes(out)


def encrypt(container: bytes) -> bytes:
    """平文コンテナ → 配布形式。"""
    return _apply(container, decrypt=False)


def decrypt(container: bytes) -> bytes:
    """配布形式 → 平文コンテナ。"""
    return _apply(container, decrypt=True)


def _check_bodies(container: bytes):
    """平文コンテナの各データ本体を raw deflate 展開し、テーブルの値と突き合わせる。

    テーブル（平文 CRC32 / 元サイズ）は暗号化されない = この実装を一切経由しないので、
    復号結果に対する **独立オラクル**になる。復号が 1 バイトでも狂えば deflate が
    壊れるか CRC32 が合わなくなる。

    往復（encrypt(decrypt(x)) == x）はこれの代わりにならない。暗号化も復号も
    「平文で鍵を回す」同じ実装を共有していて、鍵ストリームは常に一致するため、
    PW・生成多項式・`| 2` マスク・偶数位置の判定・鍵の初期値のどれを壊しても
    往復は成立してしまう（実際に各所を改変して素通りすることを確認済み）。
    """
    for path, data_off, comp, crc, uncomp in parse_entries(container):
        try:
            plain = zlib.decompress(container[data_off:data_off + comp], -15)  # raw deflate
        except zlib.error as exc:
            raise ValueError(f"{path}: raw deflate として展開できない（{exc}）")
        if len(plain) != uncomp:
            raise ValueError(f"{path}: 展開後のサイズがテーブルと違う（{len(plain)} != {uncomp}）")
        actual = zlib.crc32(plain) & 0xFFFFFFFF
        if actual != crc:
            raise ValueError(f"{path}: 平文 CRC32 がテーブルと違う（{actual:08x} != {crc:08x}）")


def _check_container(container: bytes) -> str:
    """コンテナの中身を検査し、"暗号化済み" / "平文" のどちらだったかを返す。

    リポジトリに置くのは配布形式（暗号化済み）だが、手元で `decrypt` した平文コンテナを
    渡されても検査できるようにしておく。暗号化が壊れていれば「復号しても駄目・
    そのままでも駄目」となって、どちらの経路でも NG になる。
    """
    try:
        _check_bodies(decrypt(container))
        return "暗号化済み"
    except ValueError as exc:
        try:
            _check_bodies(container)
        except ValueError:
            raise exc  # 平文としても読めない = 復号側の失敗を報告する
        return "平文"


def self_test(paths):
    """各 .ipf の中身が正しく復号できるか（+ 往復で元に戻るか）を確かめる。

    実際に配布したファイルを材料にするので、外部ツールが無い CI でも意味のある
    検査になる。検査は 2 本立て:

      1. 復号 → raw deflate 展開 → テーブルの平文 CRC32 と照合（_check_bodies）
         … 暗号アルゴリズム（PW / 鍵更新 / 偶数位置）の回帰を検出する本体
      2. 復号 → 再暗号化で元に戻る … 恒等式なので単体では暗号の検査にならないが、
         テーブル解析の範囲指定が壊れて「触っていない領域がある」状態は拾える
    """
    if not paths:
        print("[ipf_crypt] 検査対象の .ipf が無い")
        return 1
    failed = 0
    for path in paths:
        with open(path, "rb") as f:
            data = f.read()
        try:
            entries = parse_entries(data)
            kind = _check_container(data)
            if encrypt(decrypt(data)) != data:
                raise ValueError("復号 → 再暗号化で元に戻らない")
        except (ValueError, struct.error) as exc:
            print(f"  NG  {os.path.basename(path)}: {exc}")
            failed += 1
            continue
        print(f"  OK  {os.path.basename(path)}  "
              f"({len(data)} バイト / {len(entries)} ファイル / {kind})")
    if failed:
        print(f"[ipf_crypt] {failed} 件失敗")
        return 1
    print(f"[ipf_crypt] 検証 OK（{len(paths)} 件）")
    return 0


def repo_ipfs():
    """リポジトリ内の .ipf をすべて集める（配布中 + _old/ の旧版）。"""
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return sorted(glob.glob(os.path.join(repo, "**", "*.ipf"), recursive=True))


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    if argv[0] == "--self-test":
        return self_test(argv[1:] or repo_ipfs())
    if argv[0] in ("encrypt", "decrypt") and len(argv) == 3:
        with open(argv[1], "rb") as f:
            data = f.read()
        result = encrypt(data) if argv[0] == "encrypt" else decrypt(data)
        with open(argv[2], "wb") as f:
            f.write(result)
        print(f"{argv[0]}: {argv[1]} -> {argv[2]}  ({len(result)} バイト)")
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
