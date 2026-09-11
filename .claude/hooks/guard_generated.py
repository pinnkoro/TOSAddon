#!/usr/bin/env python3
"""生成物への直接編集を PreToolUse で拒否する。

CLAUDE.md / .claude/rules/generated-files.md は「生成物を直接編集しない」と書いているが、
指示は強制ではない。ここで止めないと、編集は次の生成で黙って消え、生成元との食い違いにも
気付けない（古い bundle がディスクに居座り .ipf に詰まる事故を実際に踏んでいる）。

終了コード 2 で stderr をモデルへ返し、ツール呼び出しそのものを阻止する。
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# 生成物 -> 代わりにすること
GENERATED = {
    "nexus_addons_p/_nexus_addons_p/_nexus_addons_p.lua":
        "nexus_addons_p/src/** を編集してから `python docs/bundle_from_src.py` で作り直すこと。",
    "nexus_addons_p/src/core/92_icon_names.lua":
        "`git fetch upstream` の後 `python docs/gen_icon_names.py` で作り直すこと。",
    "docs/vanilla_api.json":
        "`python docs/vanilla_api.py --verify-client` を流した後 `--update` で作り直すこと。"
        " 除外リストを足すなら JSON ではなく docs/vanilla_api.py を編集する。",
}


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0  # 入力が読めないときは素通しする（編集を妨げない）

    path = (payload.get("tool_input") or {}).get("file_path")
    if not path:
        return 0

    try:
        rel = os.path.relpath(os.path.abspath(path), ROOT).replace(os.sep, "/")
    except ValueError:
        return 0  # 別ドライブ = リポジトリ外

    hint = GENERATED.get(rel)
    if hint is None:
        return 0

    sys.stderr.write(
        "%s は生成物なので直接編集できません。%s\n"
        "詳細は .claude/rules/generated-files.md。\n" % (rel, hint)
    )
    return 2


if __name__ == "__main__":
    sys.exit(main())
