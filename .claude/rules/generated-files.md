---
paths:
  - "nexus_addons_p/_nexus_addons_p/_nexus_addons_p.lua"
  - "nexus_addons_p/src/core/92_icon_names.lua"
  - "docs/vanilla_api.json"
---

# このファイルは生成物

**直接編集しないこと。** 編集しても次の生成で消えるうえ、生成元との食い違いに気付けない。
PreToolUse フック（[.claude/hooks/guard_generated.py](../hooks/guard_generated.py)）が
書き込みを拒否する。

| ファイル | 生成元 | 作り直し方 |
| --- | --- | --- |
| `nexus_addons_p/_nexus_addons_p/_nexus_addons_p.lua` | `nexus_addons_p/src/**` | `python docs/bundle_from_src.py` |
| `nexus_addons_p/src/core/92_icon_names.lua` | 素のクライアント `_client/jp/**` | `git fetch upstream` の後 `python docs/gen_icon_names.py` |
| `docs/vanilla_api.json` | `nexus_addons_p/src/**` の使用箇所 | `python docs/vanilla_api.py --verify-client` の後 `--update` |

`vanilla_api.json` の除外リスト（`EXPECTED_NOT_IN_CLIENT` / `KNOWN_ISSUES`）を足すときは、
JSON ではなく **`docs/vanilla_api.py`** を理由付きで編集してから `--update` を流す。
