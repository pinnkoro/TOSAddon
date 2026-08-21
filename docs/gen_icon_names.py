# -*- coding: utf-8 -*-
"""クライアントの UI 画像名を抜き出して nexus_addons_p/src/core/92_icon_names.lua を生成する。

**Lua からは画像名を列挙できない**（画像は ui.ipf の xml で定義されていて、実行時に
一覧を取る API が無い）。そのため「名前で探してアイコンを選ぶ」を実現するには、
ビルド時にクライアントから名前を抜いて同梱するしかない。

抜き出し元は upstream（本家 TOSAddon-public）が同梱している素のクライアント:

    _client/jp/**/*.xml   … image="..." / Image="..."
    _client/jp/**/*.lua   … SetImage("...") と {img ...}

使い方（リポジトリルートから）:

    git fetch upstream                 # 素のクライアントを持ってくる
    python docs/gen_icon_names.py      # 既定で upstream/main から生成
    python docs/gen_icon_names.py <commit>

生成後は bundle を作り直すこと（golden sha が変わる）:

    python docs/bundle_from_src.py --bless

**手で 92_icon_names.lua を編集しないこと。** クライアントが更新されたらここから作り直す。
"""
import re
import subprocess
import sys
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
OUT = os.path.join(REPO, "nexus_addons_p", "src", "core", "92_icon_names.lua")

# 定型タブに出す並び。ここに当たる名前は候補の先頭へまとめる。
PRESET_PATTERNS = (
    re.compile(r"^sysmenu_"),
    re.compile(r"_button_normal$"),
)

PATTERNS = (
    re.compile(rb'(?:image|Image)="([A-Za-z0-9_]+)"'),
    re.compile(rb'SetImage\("([A-Za-z0-9_]+)"\)'),
    re.compile(rb'\{img ([A-Za-z0-9_]+)'),
)


def git(*args):
    return subprocess.run(["git"] + list(args), cwd=REPO, check=True,
                          stdout=subprocess.PIPE).stdout


def collect(commit):
    files = git("ls-tree", "-r", commit, "--name-only", "--", "_client").decode("utf-8").split("\n")
    files = [f for f in files if f.endswith((".xml", ".lua"))]
    if not files:
        raise SystemExit(
            f"[gen_icon_names] {commit} に _client が無い。`git fetch upstream` を先に実行すること")
    names = set()
    for path in files:
        blob = git("show", f"{commit}:{path}")
        for pat in PATTERNS:
            for m in pat.findall(blob):
                names.add(m.decode("utf-8"))
    # 1 文字だけの名前や数字始まりは画像名ではない紛れ込み。落としても実害が無いので弾く。
    return sorted(n for n in names if len(n) > 2 and not n[0].isdigit())


def lua_list(names, indent="    "):
    """1 行 4 個で並べた Lua の配列リテラルを返す（差分が読める形にする）。"""
    lines = []
    for i in range(0, len(names), 4):
        chunk = ", ".join('"%s"' % n for n in names[i:i + 4])
        lines.append(indent + chunk + ",")
    if lines:
        lines[-1] = lines[-1].rstrip(",")
    return "\n".join(lines)


def main():
    commit = sys.argv[1] if len(sys.argv) > 1 else "upstream/main"
    names = collect(commit)
    presets = [n for n in names if any(p.search(n) for p in PRESET_PATTERNS)]
    body = f'''-- クライアントの UI 画像名の一覧。**手で編集しないこと。**
-- docs/gen_icon_names.py が素のクライアント（upstream の _client/jp/**）から生成する。
--
-- Lua には画像名を列挙する手段が無いので、アイコン選択ウィンドウ
-- （core/91_icon_picker.lua）の「検索」タブはこの表を引く。ここに載っていない名前も
-- 「直接入力」タブから使える（表は素のクライアントに出てくる名前だけで、全部ではない）。
--
-- 作り直し方:
--     git fetch upstream
--     python docs/gen_icon_names.py
--     python docs/bundle_from_src.py --bless

-- 定型タブに並べる候補（sysmenu_* と *_button_normal）。
g.ICON_PRESET_NAMES = {{
{lua_list(presets)}
}}

-- 検索タブが引く一覧（{len(names)} 件）。
g.ICON_NAMES = {{
{lua_list(names)}
}}
'''
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(body)
    print(f"[gen_icon_names] {commit} から {len(names)} 件（定型 {len(presets)} 件）→ {OUT}")


if __name__ == "__main__":
    main()
