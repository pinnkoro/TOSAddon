#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""窓の裏をクリックできてしまうフレームを見つける。

土台にしている notice_on_pc.xml は `<input ... hittestframe="false"/>` なので、
既定ではフレーム自身の背景（コントロールが乗っていない部分）が当たり判定を持たない。
そこを押した入力は下の 3D 画面へ抜け、窓の上を押したつもりでキャラクターが歩き出す。
子のボタンやスロットは各自の EnableHitTest で受けるため、**窓の余白を押したときだけ
裏に通る**という分かりにくい出方をする。

そこで「フレームを作ったら g.block_click_through(frame)（= EnableHittestFrame(1)）を
呼ぶ」を既定とし、呼んでいないものをここで落とす。

逆に**通したいもの**（常時表示の HUD・マーカー・ツールチップ・大きさ 0 の入れ物）は
ALLOW に理由付きで並べる。ここへ足すときは「利用者が窓と認識しないか」を基準にすること。

照合は**同じ関数の中**で行う。ファイル単位で変数名だけを見ると、同じファイルの
無関係な別関数が同じ変数名を使っているだけで通ってしまう（indun_panel.lua は
Indun_panel_setup_frame と Indun_panel_setting_frame_open の両方が indun_panel という
変数を持つので、前者の塞ぎを消しても後者のおかげで素通りしていた）。
"""
import re
import sys
from pathlib import Path

SRC = Path(__file__).resolve().parent.parent / "nexus_addons_p" / "src"

CREATE = re.compile(
    r"(?:local\s+)?([A-Za-z_]\w*)\s*=\s*(?:ui\.CreateNewFrame\(|(?:core_)?g\.create_persistent_frame\()"
)
# **引数まで見ること。** EnableHittestFrame(0) は「裏に通す」設定なので、呼んでいる
# だけで対応済みと見なすと、通す側の書き方をそのまま見逃す。
ENABLE = re.compile(r"([A-Za-z_]\w*)\s*:\s*EnableHittestFrame\(\s*1\s*\)")
BLOCK = re.compile(r"(?:core_)?g\.block_click_through\(\s*([A-Za-z_]\w*)\s*\)")
# 字下げ 0 の function ... end を関数の単位として扱う。
# `Xxx = function()` の形（mini_addons に実在）も関数の始まりとして拾う。
FUNC = re.compile(r"^(?:(?:local\s+)?function\b|[\w.:]+\s*=\s*function\b)")
FUNC_END = re.compile(r"^end\b")
FUNC_NAME = re.compile(r"function\s+([\w.:]+)|^([\w.:]+)\s*=\s*function\b")
# コメントアウトされた古い実装（sub_map.lua の Sub_map_frame_init など）を数えないため。
LONG_COMMENT = re.compile(r"--\[(=*)\[.*?\]\1\]", re.S)

# 当たり判定を持たせない（＝裏に通してよい）フレーム。キーは「src からの相対パス:変数名」。
ALLOW = {
    "addons/always_status/always_status.lua:always_status":
        "常時表示の HUD。利用者の「固定」設定で通す/通さないを切り替える",
    "addons/muteki/muteki.lua:muteki":
        "常時表示の HUD。lock 設定で通す/通さないを切り替える",
    "addons/boss_direction/boss_direction.lua:frame":
        "ボスの方向を指す矢印。画面に重ねるだけのマーカー",
    "addons/party_marker/party_marker.lua:party_marker":
        "パーティメンバーの頭上に出すマーカー",
    "addons/debuff_notice/debuff_notice.lua:debuff_notice":
        "デバフ表示の HUD。大きさ 0 でスロットだけを重ねる",
    "addons/skill_gem_tooltip/skill_gem_tooltip.lua:sub_frame":
        "ツールチップ。利用者が「閉じるもの」と認識しない",
    "addons/monster_kill_count/monster_kill_count.lua:monster_kill_count":
        "常時表示の討伐数 HUD",
    "addons/guild_event_warp/guild_event_warp.lua:guild_event_warp":
        "画面右上に並べるアイコンボタンだけの HUD",
    "addons/tavern_of_soul/tavern_of_soul.lua:tos_btn":
        "窓を開くためのボタンだけの HUD（本体は tos_main）",
    "addons/mini_addons/footer.lua:frame":
        "RunUpdateScript の土台に使うだけの大きさ 0 の入れ物",
    "addons/mini_addons/quest/quest.lua:q7quest":
        "クエスト進行を画面上部に出す HUD",
    "addons/mini_addons/event_notice/event_shout.lua:event_frame":
        "イベント告知の HUD。中身は groupbox 側が受ける",
    "addons/monster_card_changer/monster_card_changer.lua:monster_card_changer":
        "状態を持つだけのフレーム。コントロールはゲーム側の monstercardpreset に足す",
}

# 生成した関数ではなく、**フレームを渡した先の関数**が塞いでいるもの。
# 値は塞ぐ側の関数名。名前を書くだけでは素通りさせず、(1) その関数が本当に
# block_click_through を呼んでいるか (2) 生成側がその関数へフレームを渡しているか
# の両方を見る。
DELEGATE = {
    "addons/indun_panel/indun_panel.lua:indun_panel": "Indun_panel_setup_frame",
}


def strip_comments(text):
    """コメントを取り除く（行番号は変えない）。

    コメントアウトされた古い実装が残っていることがある（sub_map.lua の
    Sub_map_frame_init など）。そのまま数えると、その中のフレーム生成を
    「関数の外で作っている」と誤検出する。
    """
    def blank(m):
        return re.sub(r"[^\n]", " ", m.group(0))

    text = LONG_COMMENT.sub(blank, text)
    return "\n".join(line.split("--")[0] for line in text.split("\n"))


def blocks(lines):
    """字下げ 0 の function ... end を (開始行, 終了行) で返す（1-based・終端を含む）。"""
    out = []
    start = None
    for i, line in enumerate(lines, 1):
        if start is None:
            if FUNC.match(line):
                start = i
        elif FUNC_END.match(line):
            out.append((start, i))
            start = None
    if start is not None:
        out.append((start, len(lines)))
    return out


def enclosing(spans, line):
    for a, b in spans:
        if a <= line <= b:
            return a, b
    return None


def main() -> int:
    missing = []
    bad_delegate = []
    seen_allow = set()
    seen_delegate = set()

    for path in sorted(SRC.rglob("*.lua")):
        rel = path.relative_to(SRC).as_posix()
        lines = strip_comments(path.read_text(encoding="utf-8")).split("\n")
        spans = blocks(lines)

        blocked_funcs = {}
        for a, b in spans:
            name = FUNC_NAME.search(lines[a - 1])
            if name:
                fname = name.group(1) or name.group(2)
                blocked_funcs[fname] = bool(BLOCK.search("\n".join(lines[a - 1:b])))

        for i, line in enumerate(lines, 1):
            m = CREATE.search(line)
            if not m:
                continue
            var = m.group(1)
            key = f"{rel}:{var}"

            if key in ALLOW:
                seen_allow.add(key)
                continue

            span = enclosing(spans, i)
            body = "\n".join(lines[span[0] - 1:span[1]]) if span else ""

            if key in DELEGATE:
                seen_delegate.add(key)
                func = DELEGATE[key]
                if not blocked_funcs.get(func):
                    bad_delegate.append((key, f"{func} が block_click_through を呼んでいない"))
                elif not re.search(rf"{re.escape(func)}\(\s*{re.escape(var)}\b", body):
                    bad_delegate.append((key, f"生成側が {func}({var}) を呼んでいない"))
                continue

            if span is None:
                missing.append((rel, i, var, "関数の外でフレームを作っている"))
                continue

            ok = any(mm.group(1) == var for mm in ENABLE.finditer(body)) or \
                 any(mm.group(1) == var for mm in BLOCK.finditer(body))
            if not ok:
                missing.append((rel, i, var, None))

    stale = sorted((set(ALLOW) - seen_allow) | (set(DELEGATE) - seen_delegate))

    for rel, line, var, why in missing:
        extra = f"（{why}）" if why else ""
        print(f"NG {rel}:{line} {var}{extra} … 同じ関数の中で g.block_click_through({var}) を"
              f"呼ぶこと（裏に通したい HUD なら ALLOW へ、渡した先で塞ぐなら DELEGATE へ"
              f"理由付きで足す）")
    for key, why in bad_delegate:
        print(f"NG DELEGATE が成立していない: {key} … {why}")
    for key in stale:
        print(f"NG ALLOW / DELEGATE に残骸: {key} … 該当のフレーム生成が無い。消すこと")

    if missing or bad_delegate or stale:
        return 1
    print("  OK 窓の当たり判定: 生成しているフレームはすべて塞いでいる"
          f"（意図的に通しているもの {len(ALLOW)} 件 / 渡した先で塞ぐもの {len(DELEGATE)} 件）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
