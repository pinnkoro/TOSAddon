#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""素のクライアント API の使用一覧を作り、想定と食い違っていないかを検査する。

■ 何のためのものか

このリポジトリのアドオンは、素のクライアントが持つ Lua 関数（`GET_CHILD_RECURSIVELY`
など）とネイティブ API（`ui.GetFrame` / `session.GetMyHandle` など）に寄りかかって
動いている。IMC 側のパッチで**関数が消える・引数の数が変わる**と、こちらのコードは
構文としては正しいままなので CI も Lua の構文チェックも通り、**実機でその機能を
触った瞬間にだけ落ちる**。しかも落ちるのは利用者の環境なので、こちらは気付けない。

そこで「どの素の API を、どう使っているか」を docs/vanilla_api.json に固定し、
次の 2 段構えで見る。

    --check          … 素のクライアント不要。CI / PR で毎回走る。
                       src の使い方が固定した一覧と一致するかだけを見る。
                       「新しい素の API を使い始めたのに一覧を更新していない」
                       「使うのをやめたのに一覧に残っている」「引数の数を変えた」を落とす。

    --verify-client  … **ローカル専用**（ゲーム本体が要る）。導入先の .ipf から
                       素の Lua を取り出し、一覧に記録した事実（定義の有無・仮引数・
                       素の側での使用実績）と突き合わせる。
                       パッチで素が変わったときに気付けるのはこれだけ。

    --update         … 一覧を作り直す。ゲーム本体があれば素の事実ごと、
                       無ければ src 側の事実だけ（既知の記号に限る）を更新する。
                       **書き換える前に必ず突き合わせる**（--verify-client と同じ判定）。
                       素が変わっているときは一覧を書き換えずに止まるので、
                       「--update で黙って飲み込む」ことは起きない。承知のうえで
                       取り込むときだけ --accept-client-changes を付ける。

■ なぜ CI では素のクライアントを見られないのか

素の Lua はゲームの導入先にしか無く（`data/*.ipf` / `patch/*.ipf`）、再配布もできない。
GitHub Actions のランナーにゲームは入らないので、素との突き合わせは原理的にローカルで
しかできない。一覧を JSON で固定してリポジトリへ入れているのはこのためで、CI では
「一覧と src の食い違い」だけを見る。**素が変わったかどうかは、手元で --verify-client を
流したときにだけ分かる。**

■ 判定できること / できないこと

    できる   … 素の Lua で定義された関数の有無・仮引数、渡す引数が多すぎないか、
               ネイティブ API 名が素の Lua から今も呼ばれているか（消えた API の検出）、
               素での呼び出し引数の数の集合
    できない … ネイティブ API の本当の signature（C 側なので Lua からは読めない）と、
               戻り値・副作用の変化。ここは素での使われ方から推測するしかない

使い方（リポジトリルートから）:
    python docs/vanilla_api.py --check
    python docs/vanilla_api.py --verify-client
    python docs/vanilla_api.py --update

終了コード: 0 = 一致 / 1 = 食い違いあり / 2 = 実行できなかった
"""
import argparse
import bisect
import glob
import hashlib
import json
import os
import re
import struct
import sys
import zlib
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ipf_crypt  # noqa: E402  （PKware 復号とファイルテーブルの読み方を共有する）

REPO = Path(__file__).resolve().parent.parent
SRC = REPO / "nexus_addons_p" / "src"
LOCK = Path(__file__).resolve().parent / "vanilla_api.json"

# ゲーム本体の導入先。環境変数で上書きできるようにしておく（Steam ライブラリの位置は
# 環境ごとに違うので、決め打ちだけにすると他の環境で流せない）。
DEFAULT_CLIENT_ROOT = (
    r"C:\Program Files (x86)\Steam\steamapps\common\Tree of Savior (Japanese Ver.)"
)

# Lua の予約語。`if (` のような形で呼び出しに見えるものを弾く。
LUA_KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto",
    "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true",
    "until", "while",
}
LUA_STD = {
    "assert", "collectgarbage", "dofile", "error", "getfenv", "getmetatable", "ipairs",
    "load", "loadfile", "loadstring", "next", "pairs", "pcall", "print", "rawequal",
    "rawget", "rawlen", "rawset", "require", "select", "setfenv", "setmetatable",
    "tonumber", "tostring", "type", "unpack", "xpcall",
}
LUA_STD_NS = {"string", "table", "math", "io", "os", "coroutine", "debug", "bit", "json", "package"}
# こちらのチャンクローカルの入れ物。素の API ではない。
OWN_NS = {"g", "core_g", "self", "_G"}

# 素の Lua に定義も呼び出しも見当たらないが、**それでよいと分かっている**名前。
# ここへ理由付きで並べる（check_frame_hittest.py の ALLOW と同じ考え方）。
# 素の Lua から辿れない = 実在しないとは限らない。ネイティブ（C 側）にだけ在る関数と、
# 他所のアドオンが定義するものがこれに当たる。
EXPECTED_NOT_IN_CLIENT = {
    "imcAddOn.BroadMsg":
        "アドオン向けのネイティブ API。素の Lua はアドオンではないので呼ばない",
    "app.BarrackToLogin":
        "ネイティブ API。素はバラック画面から別経路で戻るため Lua には現れない",
    "utf8.codes": "素も utf8 ライブラリを使う（cupole_item.lua の utf8.len）。"
                  "codes / offset は素が使っていないだけで、ライブラリは在る",
    "utf8.offset": "同上",
    "indun_panel_always_init":
        "**本家 Nexus Addons** の indun_panel が定義するグローバル。"
        "_G[\"INDUN_PANEL_ON_INIT\"] を見てから呼ぶので、本家が居ないときは呼ばない",
    "COMMON_BUFF_MSG_OLD":
        "素が旧版のバフ表示を残していたときの関数。今の素には無い。"
        "type(_G[\"COMMON_BUFF_MSG_OLD\"]) == \"function\" を見てから使うので、"
        "無ければ新しい方（COMMON_BUFF_MSG）へ落ちる",
}

# 素に見当たらず、**こちら側で対応が要る**もの（書き間違い、実機で確かめないと
# 決められないもの）。--verify-client では「既知」として報告するが落とさない
# ＝新しく出たものと区別するための控え。片付いたらここから消すこと。
# 「素に無くてよい」と結論が出たものは EXPECTED_NOT_IN_CLIENT へ移す。
KNOWN_ISSUES = {
    "info.GetMonsterClassName":
        "boss_direction.lua:167。素の Lua は geMonsterTable.GetMonsterClassNameByType しか"
        "持たず、この名前は素のどこにも現れない。実在するネイティブかどうかは実機でしか"
        "確かめられないので、確認するまでここに置く（矢印のボス名が出るかを見る）",
}

# 素を呼ばずに**中身を書き写している**置換方式フック。Issue #94。
#
# CLAUDE.md「素の関数を書き写さない」に反する形だが、素の途中で表示を絞る作りのため
# 「素を呼んでから加工」に素直に落ちない。**書き換えるまでの間、素が変わったことに
# 気付けるようにするのがここの役目。**
#
# vanilla_api.py の本来の検査（名前と仮引数）はこれらを守れない。**呼んでいないから**で、
# 素の中身だけが変わっても名前も引数も変わらず素通りする。そこで写し元の**本文の
# ハッシュ**を記録して --verify-client で照合する。
#
# **本文そのものを持たないこと。** 素の Lua は再配布できないので、記録するのは
# ハッシュと行数だけにする（#53 のときは client_snapshots/*.lua を置いたが、
# 書き写しを解消したときに丸ごと消している）。
#
# 素が変わったら --verify-client が落ちる。そのとき初めて「写しを直す」か
# 「素を呼ぶ形へ書き換える」かを判断すればよい。
#   our     … こちらの関数名（src の中の定義）
#   vanilla … 写し元の素の関数名
#   src     … こちらの定義があるファイル（nexus_addons_p/src/ からの相対）
COPIES = {
    "Mini_addons_ON_PARTYINFO_BUFFLIST_UPDATE": {
        "vanilla": "ON_PARTYINFO_BUFFLIST_UPDATE",
        "src": "addons/mini_addons/buff_list/buff_list.lua",
    },
    "Mini_addons_ON_UPDATE_QUESTINFOSET_2": {
        "vanilla": "ON_UPDATE_QUESTINFOSET_2",
        "src": "addons/mini_addons/quest/quest.lua",
    },
    "Mini_addons_INDUNENTER_REQ_UNDERSTAFF_ENTER_ALLOW": {
        "vanilla": "INDUNENTER_REQ_UNDERSTAFF_ENTER_ALLOW",
        "src": "addons/mini_addons/misc/indun_enter.lua",
    },
    "Goddess_icor_manager__GODDESS_MGR_RANDOMOPTION_ENGRAVE_ICOR_EXEC": {
        "vanilla": "_GODDESS_MGR_RANDOMOPTION_ENGRAVE_ICOR_EXEC",
        "src": "addons/goddess_icor_manager/goddess_icor_manager.lua",
    },
}


# ===== Lua の下ごしらえ =====

STR_FILLER = "~"  # 文字列リテラルの埋め草。下記のとおり空白にはしないこと


def strip_lua(text, keep_strings=False):
    """コメントを空白へ、文字列リテラルを埋め草（`~`）へ潰す。

    名前を正規表現で拾う前に必ず通すこと。文字列の中の `ui.GetFrame(` や、
    コメントアウトした古い実装まで「使っている」と数えてしまうため。
    長さを変えないので、位置の対応はそのまま残る。

    **文字列を空白にしないこと。** 空白にすると `ClMsg("hello")` の括弧の中が
    空白だけになり、count_args が「引数 0 個」と数えてしまう。文字列だけを渡す
    呼び出しは山ほどあるので、まさに見たい「引数の数の変化」を取り逃がす。
    埋め草は識別子にも括弧にもカンマにもならない文字にする（`.` はネームスペース
    呼び出しの正規表現に引っかかるので使わない）。

    `keep_strings=True` はコメントだけを落とす。フックの登録
    （`g.setup_hook(f, "ORIGIN")`）のように、**素の関数名が文字列として
    書かれている**ものを拾うときに使う。
    """
    out = list(text)
    i, n = 0, len(text)

    def blank(a, b, fill=" "):
        for k in range(a, b):
            if out[k] != "\n":
                out[k] = fill

    while i < n:
        c = text[i]
        # 長括弧 [[ ]] / [=[ ]=]（文字列とコメントの両方で使う）
        comment = re.match(r"--\[(=*)\[", text[i:])
        m = comment or re.match(r"\[(=*)\[", text[i:])
        if m:
            close = "]" + m.group(1) + "]"
            end = text.find(close, i + m.end())
            end = n if end < 0 else end + len(close)
            blank(i, end, " " if comment else STR_FILLER)
            i = end
            continue
        if text.startswith("--", i):
            end = text.find("\n", i)
            end = n if end < 0 else end
            blank(i, end)
            i = end
            continue
        if c in "'\"":
            j = i + 1
            while j < n:
                if text[j] == "\\":
                    j += 2
                    continue
                if text[j] == c or text[j] == "\n":
                    j += 1
                    break
                j += 1
            # keep_strings のときも**文字列の中は読み飛ばす**。中の `--` を
            # コメントの始まりと誤解すると、その行の後半（フックの登録など）を
            # 丸ごと落としてしまう。
            if not keep_strings:
                blank(i, min(j, n), STR_FILLER)
            i = j
            continue
        i += 1
    return "".join(out)


def count_args(text, open_paren):
    """`f(` の `(` の位置から実引数の数を数える。

    入れ子の呼び出し・テーブルの中のカンマは数えない。閉じ括弧が見つからない
    ときは None を返す。渡すのは strip_lua を通した文字列なので、文字列の中の
    カンマは考えなくてよい。

    `seen`（= 引数が 1 つでも在るか）は**開き括弧でも立てる**こと。`f({1, 2})` の
    ように括弧で始まる引数だけを渡すと、深さ 1 に括弧以外が現れず「0 個」に
    なってしまう。文字列だけの引数は strip_lua の埋め草が受け持つ。
    """
    depth = 0
    args = 0
    seen = False
    i = open_paren
    n = len(text)
    while i < n:
        c = text[i]
        if c in "([{":
            if depth >= 1:
                seen = True
            depth += 1
        elif c in ")]}":
            depth -= 1
            if depth == 0:
                return args + 1 if seen else 0
        elif depth == 1 and c == ",":
            args += 1
        elif depth == 1 and not c.isspace():
            seen = True
        i += 1
    return None


# ===== 素のクライアントを読む =====

def _find_footer(f):
    """末尾の footer を探す。

    通常は最後の 24 バイトだが、そうでないパッチ .ipf が実在する（手元の
    392404_001001.ipf / 400769_001001.ipf）。後ろから magic を探し直す。

    **.ipf を丸ごと読み込まないこと。** `data/` には数 GB の .ipf（bg_hi3 など）が
    並んでいるので、全部メモリへ載せると数分かかる。footer と、必要なデータの
    範囲だけを seek で読む。
    """
    size = f.seek(0, os.SEEK_END)
    want = min(0x10000, size)
    f.seek(size - want)
    tail = f.read(want)
    base = size - want
    data_len = size
    idx = tail.rfind(ipf_crypt.SIG)
    while idx >= 0:
        start = base + idx - 12
        if start >= 0 and start + 24 <= data_len:
            f.seek(start)
            head = f.read(24)
            count, table_off, _z, _l = struct.unpack("<HIHI", head[:12])
            new_version = struct.unpack("<I", head[20:24])[0]
            if 0 < table_off <= data_len:
                return count, table_off, new_version
        idx = tail.rfind(ipf_crypt.SIG, 0, idx)
    return None


def _entries(f, count, table_off):
    """ファイルテーブルを読む。テーブルは末尾に固まっているのでそこだけ読む。"""
    f.seek(table_off)
    data = f.read()
    off = 0
    out = []
    for _ in range(count):
        if off + 24 > len(data):
            break
        (path_len,) = struct.unpack_from("<H", data, off)
        off += 2
        _crc, comp, uncomp, data_off = struct.unpack_from("<IIII", data, off)
        off += 16
        (pack_len,) = struct.unpack_from("<H", data, off)
        off += 2 + pack_len
        rel = data[off:off + path_len].decode("ascii", "replace").replace("\\", "/")
        off += path_len
        out.append((rel.lower(), data_off, comp, uncomp))
    return out


def _extract(f, data_off, comp, uncomp, new_version):
    f.seek(data_off)
    raw = f.read(comp)
    if comp == uncomp:
        return raw
    if new_version > 11000 or new_version == 0:
        raw = ipf_crypt._transform(raw, True)
    try:
        return zlib.decompress(raw, -zlib.MAX_WBITS)
    except zlib.error:
        return raw


def _patch_rank(path):
    m = re.match(r"(\d+)", os.path.basename(path))
    return int(m.group(1)) if m else -1


def read_client_lua(root):
    """導入先から素の Lua を取り出して {内部パス: 中身} を返す。

    * `data/` と `patch/` を**古い順に**処理し、後から当たったパッチで上書きする
      （同じパスが複数の .ipf に入っていて、新しい方が正）。
    * **`_` で始まる .ipf は読まない。** アドオンの .ipf（自分の
      `_nexus_addons_p-⛄-*.ipf` や他所の `_joystickplus-*.ipf`）が同じ場所に
      置かれているので、混ぜると自分のコードを「素の API」として数えてしまう。
    """
    root = Path(root)
    if not root.is_dir():
        raise FileNotFoundError(f"ゲームの導入先が見つからない: {root}")
    candidates = (glob.glob(str(root / "data" / "*.ipf"))
                  + glob.glob(str(root / "patch" / "*.ipf")))
    ipfs = sorted((p for p in candidates if not os.path.basename(p).startswith("_")),
                  key=lambda p: (_patch_rank(p), p))
    if not ipfs:
        raise FileNotFoundError(f"{root} に .ipf が無い（data/ と patch/ を見ている）")

    found = {}
    for path in ipfs:
        with open(path, "rb") as f:
            foot = _find_footer(f)
            if not foot:
                continue
            count, table_off, new_version = foot
            for rel, data_off, comp, uncomp in _entries(f, count, table_off):
                if rel.endswith(".lua"):
                    found[rel] = (path, data_off, comp, uncomp, new_version)

    # 取り出しは .ipf ごとにまとめる（同じアーカイブを開き直さないため）。
    by_archive = {}
    for rel, hit in found.items():
        by_archive.setdefault(hit[0], []).append((rel, hit))
    files = {}
    for path, items in by_archive.items():
        with open(path, "rb") as f:
            for rel, (_p, data_off, comp, uncomp, new_version) in items:
                body = _extract(f, data_off, comp, uncomp, new_version)
                files[rel] = body.decode("utf-8", "replace")
    return files


# 素の Lua を毎回読み直すと遅いので 1 実行に 1 回だけ。
_CLIENT_CACHE = {}


def client_lua(root):
    root = str(root)
    if root not in _CLIENT_CACHE:
        _CLIENT_CACHE[root] = read_client_lua(root)
    return _CLIENT_CACHE[root]


DEF_FUNC = re.compile(r"^[ \t]*function[ \t]+([A-Za-z_]\w*)[ \t]*\(([^)]*)\)", re.M)
DEF_ASSIGN = re.compile(r"^[ \t]*([A-Za-z_]\w*)[ \t]*=[ \t]*function[ \t]*\(([^)]*)\)", re.M)
DEF_LOCAL = re.compile(r"^[ \t]*local[ \t]+function[ \t]+([A-Za-z_]\w*)", re.M)
# `function shared_common_skill_enchant.get_skill_list(...)` の形。素は共有スクリプトを
# こう置いており、こちらもそれを呼んでいるので、素の Lua 関数として扱う。
DEF_DOTTED = re.compile(
    r"^[ \t]*function[ \t]+([A-Za-z_]\w*)([.:])([A-Za-z_]\w*)[ \t]*\(([^)]*)\)", re.M)
DEF_DOTTED_ASSIGN = re.compile(
    r"^[ \t]*([A-Za-z_]\w*)\.([A-Za-z_]\w*)[ \t]*=[ \t]*function[ \t]*\(([^)]*)\)", re.M)
NS_CALL = re.compile(r"(?<![\w.:])([A-Za-z_]\w*)\.([A-Za-z_]\w*)\s*\(")
BARE_CALL = re.compile(r"(?<![\w.:])([A-Za-z_]\w*)\s*\(")
# 字下げ 0 の function ... end を「関数 1 つ」とみなすための目印。ローカルの見える範囲を
# ここで区切る（check_frame_hittest.py も同じ切り方をしている）。
# `Xxx = function()` の形（mini_addons に実在）も関数の始まりとして拾う。
FUNC = re.compile(r"^(?:(?:local\s+)?function\b|[\w.:]+\s*=\s*function\b)")
FUNC_END = re.compile(r"^end\b")


def scan_client(root, wanted=None):
    """素の Lua を舐めて、照合に使う事実だけを取り出す。

    globals … 素が定義している関数 {名前: {"params": [...], "file": "..."}}
    natives … 素の側での使用実績
              {"ui.GetFrame": {"calls": n, "arities": [...], "mentions": n}}
              ネイティブ API は Lua に定義が無いので、**素自身が使っているか**しか
              手掛かりが無い。消えた API の検出はここで行う。
              `mentions` は文字列も含めた素の Lua 全体での出現数。素は
              `ReserveScript("AnsGiveUpPrevPlayingIndun(1)")` のように**文字列の中から
              呼ぶ**ことがあり、呼び出しとしては数えられないため。

    `wanted` を渡すと、引数の数を数えるのはその名前だけにする（こちらが使っていない
    数万件の呼び出しまで数えると 1 分以上かかるので、既定では省く）。
    """
    files = client_lua(root)
    globals_ = {}
    natives = {}

    def note(key, body, end):
        rec = natives.setdefault(key, {"calls": 0, "arities": set(), "mentions": 0})
        rec["calls"] += 1
        if wanted is not None and key not in wanted:
            return
        n = count_args(body, end)
        if n is not None:
            rec["arities"].add(n)

    for rel in sorted(files):
        raw = files[rel]
        body = strip_lua(raw)
        local_defs = set(DEF_LOCAL.findall(body))
        for pat in (DEF_FUNC, DEF_ASSIGN):
            for m in pat.finditer(body):
                name, params = m.group(1), m.group(2)
                if name in local_defs or name in LUA_KEYWORDS:
                    continue
                plist = [p.strip() for p in params.split(",") if p.strip()]
                # 同名が複数あるときは最初に当たったものを採る（素にも重複定義がある）。
                globals_.setdefault(name, {"params": plist, "file": rel})
        for m in DEF_DOTTED.finditer(body):
            ns, sep, name, params = m.group(1), m.group(2), m.group(3), m.group(4)
            if ns in local_defs:
                continue
            plist = [p.strip() for p in params.split(",") if p.strip()]
            if sep == ":":
                plist = ["self"] + plist  # `:` 定義は self が隠れ引数として増える
            globals_.setdefault(f"{ns}.{name}", {"params": plist, "file": rel})
        for m in DEF_DOTTED_ASSIGN.finditer(body):
            ns, name, params = m.group(1), m.group(2), m.group(3)
            if ns in local_defs:
                continue
            plist = [p.strip() for p in params.split(",") if p.strip()]
            globals_.setdefault(f"{ns}.{name}", {"params": plist, "file": rel})
        for m in NS_CALL.finditer(body):
            note(f"{m.group(1)}.{m.group(2)}", body, m.end() - 1)
        for m in BARE_CALL.finditer(body):
            if m.group(1) in LUA_KEYWORDS:
                continue
            note(m.group(1), body, m.end() - 1)
        # 文字列の中も含めた出現数。名前ごとに全文検索すると遅いので、
        # 語の切り出しを 1 回だけ行って数える。
        if wanted:
            words = Counter(re.findall(r"(?<![\w.:])[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)?", raw))
            for word, cnt in words.items():
                if word in wanted:
                    rec = natives.setdefault(
                        word, {"calls": 0, "arities": set(), "mentions": 0})
                    rec["mentions"] += cnt

    for rec in natives.values():
        rec["arities"] = sorted(rec["arities"])
    return globals_, natives


# ===== こちら側（src）を読む =====

HOOK_RE = re.compile(
    r"(?:core_)?g\.setup_hook\s*\(\s*[^,]+,\s*[\"']([A-Za-z_]\w*)[\"']"
)
HOOK_EVENT_RE = re.compile(
    r"(?:core_)?g\.setup_hook_and_event\s*\(\s*[^,]+,\s*[\"']([A-Za-z_]\w*)[\"']"
)


def src_files():
    return sorted(SRC.rglob("*.lua"), key=lambda p: p.as_posix())


def scan_src():
    """src 側の「素の API に触っている箇所」を集める。

    自分が定義したグローバル・ローカル・Lua 標準を除くと、残りが
    「素のクライアントに在ることを当てにしている名前」になる。
    """
    bodies = {}
    with_strings = {}
    line_index = {}      # ファイル -> 各行の先頭位置（呼び出し位置から行番号を引くため）
    own_globals = set()
    # **ローカルは「見える範囲」で判定すること。** src 全体の和集合にすると、どこか
    # 1 ファイルの `local item = items[i]` が別ファイルの本物の `item.UnEquip(...)` まで
    # 落とす。ファイル単位にしても足りず、同じファイルの**別の関数**にある
    # `local item` / `local market` / `local info` が、そのファイル全体の
    # `item.Equip` / `market.ReqRegisterItem` / `info.GetPositionInMap` を隠していた。
    # 一覧から漏れた API は --verify-client の照合対象にすらならないので、
    # 防ぎたい事故をツール自身が起こすことになる。
    #
    # そこで**字下げ 0 の function ... end を 1 つの入れ物**とみなし、その中で宣言した
    # ローカルは「同じ入れ物の、宣言行より後ろ」だけで効かせる。Lua の本当のブロック
    # スコープより広いが（入れ子の関数で宣言したものが、その関数の残りにも効く）、
    # 隠しすぎる向きの誤差が 1 関数の中に収まる。
    block_locals = {}    # ファイル -> [{名前: 宣言行}]。0 番はチャンク直下
    block_of_line = {}   # ファイル -> [行 -> 入れ物の番号]
    # bundle は全ファイルを 1 チャンクへ連結するので、**字下げ 0 の local は後続の
    # ファイルからも見える**。こちらだけは全体で共有する（mini_addons の hair_enchant /
    # skill_reroll がファイルをまたいで呼び合っている）。
    chunk_locals = set()

    def add_local(blocks, bid, name, line):
        if name in LUA_KEYWORDS:
            return
        cur = blocks[bid].get(name)
        if cur is None or line < cur:
            blocks[bid][name] = line

    for path in src_files():
        rel = path.relative_to(SRC).as_posix()
        text = path.read_text(encoding="utf-8")
        body = strip_lua(text)
        bodies[rel] = body
        with_strings[rel] = strip_lua(text, keep_strings=True)
        line_index[rel] = [0] + [m.end() for m in re.finditer("\n", body)]
        for m in DEF_FUNC.finditer(body):
            own_globals.add(m.group(1))
        for m in DEF_ASSIGN.finditer(body):
            own_globals.add(m.group(1))
        for m in re.finditer(r"function[ \t]+_G\.([A-Za-z_]\w*)", body):
            own_globals.add(m.group(1))
        # **こちらは文字列を残した方を見る。** `_G["INSTANTCC_ON_INIT"] = ...` の名前は
        # 文字列なので、埋め草へ潰した body には残っていない（拾えないまま「素の API を
        # 使っている」と誤検出することになる）。
        for m in re.finditer(r"_G\[\s*[\"']?([A-Za-z_]\w*)[\"']?\s*\]?\s*=",
                             with_strings[rel]):
            own_globals.add(m.group(1))

        blocks = [{}]          # 0 番 = チャンク直下
        owner = []             # 行ごとの入れ物の番号
        bid = 0
        for i, line in enumerate(body.split("\n")):
            # 字下げ 0 の function で入れ物が始まり、字下げ 0 の end で閉じる。
            # `Xxx = function()`（mini_addons に実在）も関数の始まりとして扱う。
            if FUNC.match(line):
                blocks.append({})
                bid = len(blocks) - 1
            owner.append(bid)
            m = re.match(r"([ \t]*)local[ \t]+(?:function[ \t]+)?([A-Za-z_][\w \t,]*)", line)
            if m:
                for nm in m.group(2).split(","):
                    nm = nm.strip()
                    if re.fullmatch(r"[A-Za-z_]\w*", nm):
                        add_local(blocks, bid, nm, i)
                        if m.group(1) == "" and nm not in LUA_KEYWORDS:
                            chunk_locals.add(nm)
            # 仮引数もローカル扱い（`function f(ctrl)` の ctrl を呼ぶ形がある）。
            for pm in re.finditer(r"function[^(\n]*\(([^)]*)\)", line):
                for nm in pm.group(1).split(","):
                    nm = nm.strip()
                    if re.fullmatch(r"[A-Za-z_]\w*", nm):
                        add_local(blocks, bid, nm, i)
            if bid != 0 and FUNC_END.match(line):
                bid = 0
        block_locals[rel] = blocks
        block_of_line[rel] = owner

    hooks = {}
    uses = {}

    def add(key, rel, nargs):
        rec = uses.setdefault(key, {"files": set(), "arities": set()})
        rec["files"].add(rel)
        if nargs is not None:
            rec["arities"].add(nargs)

    for rel, body in bodies.items():
        starts = line_index[rel]
        blocks = block_locals[rel]
        owner = block_of_line[rel]

        def shadowed(name, pos, starts=starts, blocks=blocks, owner=owner):
            """その呼び出し位置から、その名前のローカルが見えているか。

            見えているなら素の API ではない（同名のローカルを呼んでいる）。
            **入れ物と宣言行の両方を見ること。** 同じファイルの別の関数にある
            `local item` で、こちらの `item.Equip(...)` を消してはいけない。
            """
            if name in chunk_locals:
                return True
            line = bisect.bisect_right(starts, pos) - 1
            bid = owner[line] if line < len(owner) else 0
            decl = blocks[bid].get(name)
            return decl is not None and decl <= line

        for pat in (HOOK_RE, HOOK_EVENT_RE):
            for m in pat.finditer(with_strings[rel]):
                hooks.setdefault(m.group(1), set()).add(rel)
        for m in NS_CALL.finditer(body):
            ns, name = m.group(1), m.group(2)
            if ns in OWN_NS or ns in LUA_STD_NS or ns in own_globals:
                continue
            if shadowed(ns, m.start()):
                continue
            add(f"{ns}.{name}", rel, count_args(body, m.end() - 1))
        for m in BARE_CALL.finditer(body):
            name = m.group(1)
            if (name in own_globals or name in LUA_STD
                    or name in LUA_STD_NS or name in OWN_NS or name in LUA_KEYWORDS):
                continue
            if shadowed(name, m.start()):
                continue
            add(name, rel, count_args(body, m.end() - 1))

    # フックしている素の関数は、呼んでいなくても「在ること」を当てにしている。
    for name, files in hooks.items():
        rec = uses.setdefault(name, {"files": set(), "arities": set()})
        rec["files"] |= files

    return uses, hooks


# ===== 一覧（lock）の組み立てと比較 =====

FUNC_BODY_END = re.compile(r"^end[ \t]*$", re.M)


def function_body(text, name):
    """`function name(` から対応する行頭 end までを返す。見つからなければ None。

    **コメントは落とし、文字列は残す**(strip_lua の keep_strings)。素のコメントが
    増えただけで「変わった」と騒ぐと、本当の変化のときに信用されなくなる。逆に
    文字列は表示や判定に効くので落とさない。
    """
    # **先に改行を正規化すること。** 素の Lua は CRLF なので、`^end[ \t]*$` は
    # 行末の \r に阻まれて一致しない。素のままだと関数の終わりを取り違えて、
    # ずっと先の(たまたま \r の無い)行まで拾う(実際 28 行の関数が 2234 行になった)。
    # ハッシュが改行コードに左右されなくなる利点もある。
    body = strip_lua(text.replace("\r\n", "\n").replace("\r", "\n"), keep_strings=True)
    m = re.search(r"^[ \t]*function[ \t]+" + re.escape(name) + r"[ \t]*\(", body, re.M)
    if not m:
        return None
    m2 = FUNC_BODY_END.search(body, m.end())
    if not m2:
        return None
    chunk = body[m.start():m2.end()]
    # 字下げと空行の揺れは無視する
    return "\n".join(line.strip() for line in chunk.split("\n") if line.strip())


def scan_client_copies(root, client_globals):
    """COPIES の写し元について、今の素の本文のハッシュと行数を返す。"""
    files = client_lua(root)
    out = {}
    for our, spec in COPIES.items():
        name = spec["vanilla"]
        info = client_globals.get(name)
        rec = {"vanilla": name}
        text = files.get(info["file"]) if info else None
        chunk = function_body(text, name) if text else None
        if chunk is None:
            rec["missing"] = True
        else:
            rec["defined_in"] = info["file"]
            rec["lines"] = len(chunk.split("\n"))
            rec["sha256"] = hashlib.sha256(chunk.encode("utf-8")).hexdigest()
        out[our] = rec
    return out


def compare_copies(lock, client_copies, require_record=True):
    """記録した写し元のハッシュと、今の素を突き合わせる。戻り値は problems。

    `require_record=False` は「記録がまだ無い」を問題にしない。**--update から
    呼ぶときはこちら**。記録を作るのが --update の仕事なので、無いことを理由に
    止めると初回に自分の初期化を拒む(実際そうなった)。
    """
    problems = []
    old = lock.get("copies") or {}
    for our, spec in COPIES.items():
        cur = client_copies.get(our) or {}
        rec = old.get(our)
        if rec is None:
            if require_record:
                problems.append(
                    f"{our}: 写し元({spec['vanilla']})の記録が一覧に無い。--update で作ること")
            continue
        if cur.get("missing"):
            problems.append(
                f"{our}: 写し元の {spec['vanilla']} が素から消えている"
                f"({spec['src']} の写しは呼ばれ続けるので、素の変更に追随できない)")
            continue
        if rec.get("sha256") != cur.get("sha256"):
            problems.append(
                f"{our}: **写し元の {spec['vanilla']} が変わっている**"
                f"({rec.get('lines')} 行 → {cur.get('lines')} 行 / "
                f"{str(rec.get('sha256'))[:12]} → {str(cur.get('sha256'))[:12]})。"
                f"{spec['src']} の写しを素へ合わせるか、素を呼ぶ形へ書き換えること(Issue #94)")
    return problems


def build_lock(uses, hooks, client_globals=None, client_natives=None, previous=None,
               client_copies=None):
    prev_symbols = (previous or {}).get("symbols", {})
    symbols = {}
    for key in sorted(uses):
        rec = uses[key]
        prev = prev_symbols.get(key, {})
        entry = {
            "used_by": sorted(rec["files"]),
            "our_arities": sorted(rec["arities"]),
        }
        if key in hooks:
            entry["hooked"] = True
        if client_globals is not None:
            if key in client_globals:
                entry["kind"] = "client_lua"
                entry["params"] = client_globals[key]["params"]
                entry["defined_in"] = client_globals[key]["file"]
            else:
                cn = (client_natives or {}).get(key) or {}
                calls = cn.get("calls", 0)
                mentions = cn.get("mentions", 0)
                if calls or mentions:
                    entry["kind"] = "native"
                elif key in EXPECTED_NOT_IN_CLIENT or key in KNOWN_ISSUES:
                    entry["kind"] = "external"
                else:
                    entry["kind"] = "unknown"
                entry["vanilla_calls"] = calls
                entry["vanilla_mentions"] = mentions
                entry["vanilla_arities"] = cn.get("arities", [])
        else:
            # 素のクライアントを見ていないときは、前回の事実をそのまま持ち越す。
            for k in ("kind", "params", "defined_in", "vanilla_calls", "vanilla_mentions",
                      "vanilla_arities"):
                if k in prev:
                    entry[k] = prev[k]
        symbols[key] = entry
    # 写し元(COPIES)の記録。素を見ていないときは前回の記録をそのまま持ち越す。
    if client_copies is not None:
        copies = {k: client_copies[k] for k in sorted(client_copies)}
    else:
        copies = dict((previous or {}).get("copies") or {})
    return {
        "_readme": "docs/vanilla_api.py が作る一覧。手で編集せず --update で作り直すこと。",
        "symbols": symbols,
        "copies": copies,
    }


def load_lock():
    if not LOCK.exists():
        return None
    return json.loads(LOCK.read_text(encoding="utf-8"))


def save_lock(lock):
    """1 記号 1 行で書き出す。

    素直に indent=2 で書くと 1 記号が 10 行以上になり、使い方を 1 箇所直しただけで
    差分が数十行に膨らんで**何が変わったのか読めなくなる**。行と記号を 1 対 1 に
    しておくと、diff がそのまま「どの API の扱いが変わったか」の一覧になる。
    """
    lines = ["{", f'  "_readme": {json.dumps(lock["_readme"], ensure_ascii=False)},',
             '  "symbols": {']
    items = list(lock["symbols"].items())
    for i, (key, entry) in enumerate(items):
        tail = "" if i == len(items) - 1 else ","
        lines.append(f'    {json.dumps(key, ensure_ascii=False)}: '
                     f'{json.dumps(entry, ensure_ascii=False)}{tail}')
    lines += ["  },"]
    # 写し元の記録(Issue #94)。1 件 1 行。
    lines.append('  "copies": {')
    citems = list((lock.get("copies") or {}).items())
    for i, (key, entry) in enumerate(citems):
        tail = "" if i == len(citems) - 1 else ","
        lines.append(f'    {json.dumps(key, ensure_ascii=False)}: '
                     f'{json.dumps(entry, ensure_ascii=False)}{tail}')
    lines += ["  }", "}"]
    LOCK.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


# 一覧に載せない名前。素の API ではないと分かっているもの（素の側にも同名が
# 定義されていないため、突き合わせても情報が増えない）はここで落とす。
# 下ごしらえと引数の数え方の自己検査。**ここが静かに壊れると、一覧は「全部一致」の
# まま中身が嘘になる**（実際、文字列だけの引数を 0 個と数えていた）。--check の頭で
# 毎回走らせて、CI でも必ず通るようにしておく。
SELF_TEST_CASES = [
    ('ClMsg("hello")', 1),          # 文字列だけの引数（埋め草が無いと 0 になる）
    ('f("a", "b")', 2),
    ("f()", 0),
    ("f({1,2})", 1),                # 括弧で始まる引数（seen を括弧でも立てる）
    ('f({1,2}, "x")', 2),
    ("f(a, g(b, c))", 2),           # 入れ子のカンマは数えない
    ('f("a--b", c)', 2),            # 文字列の中の -- をコメントと誤解しない
    ("f([[x]], y)", 2),             # 長括弧の文字列
    ("f(a) --[[ f(b, c) ]]", 1),    # コメントの中は数えない
]


def self_test():
    bad = []
    for src, want in SELF_TEST_CASES:
        body = strip_lua(src)
        got = count_args(body, body.index("("))
        if got != want:
            bad.append(f"{src} → {got}（期待 {want}） / 下ごしらえ後: {body}")
    return bad


def cmd_check(args):
    """ゲーム本体なしで走る検査。src と一覧の食い違いだけを見る。"""
    bad = self_test()
    if bad:
        print(f"NG: 引数の数え方が壊れている: {len(bad)} 件")
        for b in bad:
            print("  -", b)
        return 2
    lock = load_lock()
    if lock is None:
        print(f"NG: {LOCK.name} が無い。`python docs/vanilla_api.py --update` で作ること")
        return 2
    uses, hooks = scan_src()
    fresh = build_lock(uses, hooks)["symbols"]
    old = lock["symbols"]
    problems = []

    for key in sorted(set(fresh) - set(old)):
        problems.append(
            f"一覧に無い素の API を使っている: {key}"
            f"（{', '.join(fresh[key]['used_by'])}）")
    # 素に定義も使用も見当たらないまま一覧へ入った記号は、ここでも落とす。
    # --update の側でも止めているが、CI は素を見られないぶん一覧が唯一の頼りなので、
    # 「素と照らして結論が出ていない記号が混じったまま」を通さない。
    for key in sorted(set(old) & set(fresh)):
        kind = old[key].get("kind")
        if kind in (None, "unknown"):
            problems.append(
                f"{key}: 素と照らした結論が一覧に無い（kind={kind}）。"
                f"ゲームのある環境で --update を流し直すこと")
    for key in sorted(set(old) - set(fresh)):
        problems.append(f"一覧に残っているが src から消えている: {key}")
    # 書き写しフック(COPIES)。素は見られないので、**こちら側の定義が在るか**と
    # **写し元の記録が在るか**だけを見る。素を呼ぶ形へ書き換えたなら COPIES から
    # 外すこと(外し忘れると、もう存在しない写しを見張り続ける)。
    recorded = lock.get("copies") or {}
    for our, spec in COPIES.items():
        path = SRC / spec["src"]
        if not path.is_file():
            problems.append(f"{our}: 写しのファイルが無い（{spec['src']}）")
        elif not re.search(r"^[ 	]*function[ 	]+" + re.escape(our) + r"[ 	]*\(",
                           path.read_text(encoding="utf-8"), re.M):
            problems.append(
                f"{our}: 写しの定義が {spec['src']} に無い。"
                f"素を呼ぶ形へ書き換えたなら COPIES から外すこと（Issue #94）")
        if our not in recorded:
            problems.append(
                f"{our}: 写し元（{spec['vanilla']}）の記録が一覧に無い。"
                f"ゲームのある環境で --update を流すこと")
    for key in sorted(set(old) & set(fresh)):
        for field, label in (("used_by", "使っている場所"),
                             ("our_arities", "渡している引数の数"),
                             ("hooked", "フックの有無")):
            a, b = old[key].get(field), fresh[key].get(field)
            if a != b:
                problems.append(f"{key}: {label}が変わっている（一覧 {a} → src {b}）")

    if problems:
        print(f"NG: 素の API の一覧（{LOCK.name}）が src と食い違っている: {len(problems)} 件")
        for p in problems:
            print("  -", p)
        print()
        print("直し方: ゲームを導入した環境で `python docs/vanilla_api.py --update` を流し、")
        print("        併せて `--verify-client` で素が変わっていないかを確かめてから commit する。")
        return 1
    print(f"OK: 素の API {len(fresh)} 件、一覧と一致（書き写しの見張り {len(COPIES)} 件）")
    return 0


def compare_with_client(lock, cg, cn):
    """一覧に記録した素の事実と、今のクライアントを突き合わせる。

    戻り値は (problems, notices, known)。**--update からも呼ぶこと。**
    --update は記録を今のクライアントで上書きするので、先に突き合わせておかないと
    素の変化を黙って飲み込んでしまう（それでは検査にならない）。
    """
    problems = []   # 実機で壊れる（落とす）
    notices = []    # 素の変化の手掛かり（落とさない）
    known = []      # KNOWN_ISSUES に控えてある既知の不具合（落とさない）
    for key, entry in sorted(lock["symbols"].items()):
        kind = entry.get("kind")
        if key in KNOWN_ISSUES:
            known.append(f"{key}: {KNOWN_ISSUES[key]}")
            continue
        if kind == "client_lua":
            now = cg.get(key)
            if now is None:
                problems.append(
                    f"{key}: 素の Lua から定義が消えた（{entry.get('defined_in')} に在ったもの）"
                    f" / 使用箇所 {', '.join(entry['used_by'])}")
                continue
            if now["params"] != entry.get("params"):
                problems.append(
                    f"{key}: 仮引数が変わった {entry.get('params')} → {now['params']}"
                    f"（{now['file']}） / 使用箇所 {', '.join(entry['used_by'])}")
            elif now["file"] != entry.get("defined_in"):
                notices.append(
                    f"{key}: 定義位置が移った {entry.get('defined_in')} → {now['file']}")
            # 渡す引数が仮引数より多い。**Lua では余った実引数は捨てられるだけ**なので、
            # それ自体は落ちない。素が引数を減らした跡（＝こちらの想定が古い）の
            # 手掛かりとして出すだけに留める。
            params = now["params"]
            if not (params and params[-1] == "..."):
                over = [n for n in entry.get("our_arities", []) if n > len(params)]
                if over:
                    notices.append(
                        f"{key}: 素の仮引数は {len(params)} 個だが {over} 個渡している"
                        f"（{len(entry['used_by'])} ファイル）")
        elif kind == "native":
            # 素の Lua に定義は無い（C 側）。素自身が使い続けているかだけを見る。
            now = cn.get(key, {"calls": 0, "arities": [], "mentions": 0})
            was = entry.get("vanilla_calls", 0) + entry.get("vanilla_mentions", 0)
            if was > 0 and now["calls"] == 0 and now["mentions"] == 0:
                problems.append(
                    f"{key}: 素の Lua がどこからも使わなくなった（以前 {was} 箇所）"
                    f" / 使用箇所 {', '.join(entry['used_by'])}")
            elif now["arities"] and entry.get("vanilla_arities") and \
                    now["arities"] != entry["vanilla_arities"]:
                problems.append(
                    f"{key}: 素での引数の数が変わった {entry['vanilla_arities']} → {now['arities']}"
                    f" / こちらは {entry.get('our_arities')} で呼んでいる")
        elif kind == "external":
            reason = EXPECTED_NOT_IN_CLIENT.get(key)
            if reason is None:
                problems.append(
                    f"{key}: 素に見当たらないのに理由が書かれていない"
                    f"（EXPECTED_NOT_IN_CLIENT か KNOWN_ISSUES へ理由付きで足すこと）")
            elif key in cg or (cn.get(key, {}).get("calls") or cn.get(key, {}).get("mentions")):
                problems.append(
                    f"{key}: 素の側に現れるようになった。EXPECTED_NOT_IN_CLIENT の"
                    f"「{reason}」がもう当たらない可能性がある")
        else:
            problems.append(
                f"{key}: 素の Lua に定義も使用も見当たらない"
                f"（{', '.join(entry['used_by'])}）。"
                f"素の API なら綴りを、そうでないなら EXPECTED_NOT_IN_CLIENT / "
                f"KNOWN_ISSUES へ理由付きで足すこと")

    return problems, notices, known


def report(problems, notices, known):
    if known:
        print(f"既知（KNOWN_ISSUES / 直したら消すこと）: {len(known)} 件")
        for k in known:
            print("  -", k)
        print()
    if notices:
        print(f"注意（落とさない。素の変化の手掛かり）: {len(notices)} 件")
        for k in notices:
            print("  -", k)
        print()
    if problems:
        print(f"素のクライアントと食い違っている: {len(problems)} 件")
        for p in problems:
            print("  -", p)
        print()
        print("見方: 「定義が消えた」「仮引数が変わった」は実機で確実に壊れる。")
        print("      「使わなくなった」は素の作りが変わった合図で、まだ動く場合もある。")


def cmd_verify_client(args):
    """ローカル専用。記録した素の事実が今のクライアントと合っているかを見る。"""
    lock = load_lock()
    if lock is None:
        print(f"NG: {LOCK.name} が無い。--update で作ること")
        return 2
    try:
        cg, cn = scan_client(args.client_root, wanted=set(lock["symbols"]))
    except FileNotFoundError as e:
        print(f"NG: {e}")
        print("    --client-root か環境変数 TOS_CLIENT_ROOT で導入先を指定できる。")
        return 2

    problems, notices, known = compare_with_client(lock, cg, cn)
    # 写し元(COPIES)の本文が変わっていないか。**呼んでいる API の検査では守れない**ので
    # 別立てで見る(詳しくは COPIES のコメント)。
    problems = problems + compare_copies(lock, scan_client_copies(args.client_root, cg))
    report(problems, notices, known)
    if problems:
        print("      確かめたうえで src を直し、--update で一覧を作り直すこと。")
        return 1
    print(f"OK: 素のクライアント（{args.client_root}）と一致。"
          f"{len(lock['symbols'])} 件 + 写し元 {len(COPIES)} 件を照合")
    return 0


def cmd_update(args):
    uses, hooks = scan_src()
    previous = load_lock()
    cg = cn = None
    try:
        cg, cn = scan_client(args.client_root, wanted=set(uses) | set(
            (previous or {}).get("symbols", {})))
    except FileNotFoundError as e:
        if previous is None:
            print(f"NG: 一覧が無く、素のクライアントも読めない: {e}")
            return 2
        unknown = [k for k in uses if k not in previous.get("symbols", {})]
        if unknown:
            print("NG: 一覧に無い素の API があるので、素のクライアントが要る:")
            for k in sorted(unknown):
                print("  -", k)
            print(f"    ({e})")
            return 2
        print(f"! 素のクライアントを読めないので、src 側の事実だけ更新する（{e}）")

    # **書き換える前に突き合わせること。** --update は記録を今のクライアントで
    # 上書きするので、黙って上書きすると「素が変わった」という一番知りたい事実が
    # 消える（json の差分には出るが、検査としては素通りしてしまう）。
    # 実機で壊れる種類の食い違いが在るときは、--accept-client-changes を明示しない限り
    # 書き換えない。
    if previous is not None and cg is not None:
        # **もう使っていない記号は見ない。** 呼び出しをやめた（＝書き間違いを直した）
        # ものまで照合すると、直した本人が --update できなくなる。ここで見たいのは
        # 「今も使っている素の API が変わっていないか」だけ。
        still_used = {"symbols": {k: v for k, v in previous["symbols"].items() if k in uses}}
        # 既知（KNOWN_ISSUES）はここでは出さない。--update のたびに毎回並ぶと、
        # 今回の更新で新しく出た食い違いが埋もれる。
        problems, notices, _known = compare_with_client(still_used, cg, cn)
        if problems or notices:
            print("書き換える前に、今のクライアントと突き合わせた結果:")
            print()
            report(problems, notices, [])
        # 写し元(COPIES)も同じ扱いで先に見る。ここを飛ばすと、素の本文が変わったのに
        # ハッシュだけ黙って上書きされ、**一番知りたい事実が消える**。
        copy_problems = compare_copies(previous, scan_client_copies(args.client_root, cg),
                                       require_record=False)
        if copy_problems:
            print("書き写しの元が変わっている:")
            print()
            for cp in copy_problems:
                print("  -", cp)
            print()
            problems = problems + copy_problems
        if problems and not args.accept_client_changes:
            print("一覧は書き換えなかった。まず上の食い違いを確かめて src を直すこと。")
            print("素の変化を承知のうえで取り込むなら --accept-client-changes を付ける。")
            return 1

    client_copies = scan_client_copies(args.client_root, cg) if cg is not None else None
    lock = build_lock(uses, hooks, cg, cn, previous, client_copies)

    # **作った一覧そのものも突き合わせること。** 上の突き合わせは previous（= commit 済みの
    # 一覧）しか見ないので、**今回はじめて出てきた記号は 1 度も判定を通らない**。
    # 素の API 名を打ち間違えた呼び出しを足して --update すると、kind: "unknown" のまま
    # 保存されて OK が返る、という一番まずい抜け方をしていた（KNOWN_ISSUES に控えてある
    # 既存の打ち間違いは、まさにこの種類）。
    if cg is not None:
        problems, _notices, _known = compare_with_client(lock, cg, cn)
        added = [p for p in problems if p.split(":")[0] not in (previous or {}).get("symbols", {})]
        if added and not args.accept_client_changes:
            print("新しく使い始めた素の API に食い違いがある:")
            print()
            for p in added:
                print("  -", p)
            print()
            print("一覧は書き換えなかった。綴りを確かめるか、素に無くてよいものなら")
            print("EXPECTED_NOT_IN_CLIENT / KNOWN_ISSUES へ理由付きで足すこと。")
            return 1

    save_lock(lock)
    n_lua = sum(1 for v in lock["symbols"].values() if v.get("kind") == "client_lua")
    n_nat = sum(1 for v in lock["symbols"].values() if v.get("kind") == "native")
    print(f"OK: {LOCK.name} を更新（素の Lua 関数 {n_lua} 件 / ネイティブ {n_nat} 件）")
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--check", action="store_true", help="src と一覧の一致だけを見る（CI 用）")
    ap.add_argument("--verify-client", action="store_true",
                    help="素のクライアントと突き合わせる（ローカル専用）")
    ap.add_argument("--update", action="store_true", help="一覧を作り直す")
    ap.add_argument("--accept-client-changes", action="store_true",
                    help="--update で、素が変わっていても承知のうえで取り込む")
    ap.add_argument("--client-root",
                    default=os.environ.get("TOS_CLIENT_ROOT", DEFAULT_CLIENT_ROOT),
                    help="ゲームの導入先（既定は Steam の標準の場所 / 環境変数 TOS_CLIENT_ROOT）")
    args = ap.parse_args(argv)
    if args.update:
        return cmd_update(args)
    if args.verify_client:
        return cmd_verify_client(args)
    return cmd_check(args)


if __name__ == "__main__":
    sys.exit(main())
