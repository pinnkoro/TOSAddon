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
"""
import re
import sys
from pathlib import Path

SRC = Path(__file__).resolve().parent.parent / "nexus_addons_p" / "src"

CREATE = re.compile(
    r"(?:local\s+)?([A-Za-z_]\w*)\s*=\s*(?:ui\.CreateNewFrame\(|(?:core_)?g\.create_persistent_frame\()"
)
ENABLE = re.compile(r"([A-Za-z_]\w*)\s*:\s*EnableHittestFrame\(")
BLOCK = re.compile(r"(?:core_)?g\.block_click_through\(\s*([A-Za-z_]\w*)\s*\)")

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


def main() -> int:
    missing = []
    seen_keys = set()
    for path in sorted(SRC.rglob("*.lua")):
        rel = path.relative_to(SRC).as_posix()
        lines = path.read_text(encoding="utf-8").split("\n")
        enabled = {m.group(1) for line in lines for m in [ENABLE.search(line)] if m}
        enabled |= {m.group(1) for line in lines for m in [BLOCK.search(line)] if m}
        for i, line in enumerate(lines, 1):
            m = CREATE.search(line)
            if not m:
                continue
            var = m.group(1)
            key = f"{rel}:{var}"
            if key in ALLOW:
                seen_keys.add(key)
                continue
            if var not in enabled:
                missing.append((rel, i, var))

    stale = sorted(set(ALLOW) - seen_keys)
    for rel, line, var in missing:
        print(f"NG {rel}:{line} {var} … g.block_click_through({var}) を呼ぶこと"
              f"（裏に通したい HUD なら docs/check_frame_hittest.py の ALLOW へ理由付きで足す）")
    for key in stale:
        print(f"NG ALLOW に残骸: {key} … 該当のフレーム生成が無い。ALLOW から消すこと")

    if missing or stale:
        return 1
    print("  OK 窓の当たり判定: 生成しているフレームはすべて塞いでいる"
          f"（ALLOW で意図的に通しているもの {len(ALLOW)} 件）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
