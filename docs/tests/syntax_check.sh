#!/bin/sh
# 連結後 bundle の Lua 構文チェック。src 単体では guard_open.lua が `if ... then` を
# 開いたまま終わるなど構文的に不完全なため、必ず bundle に対して行う。
# loadfile はロードのみで実行しないので、ゲーム API が無い環境でも使える。
set -eu
for f in nexus_addons_p/_nexus_addons_p/_nexus_addons_p.lua \
         nexus_addons_p/_nexus_addons_p/_nexus_addons_p_conclude.lua; do
    luajit -e "local c, e = loadfile('$f'); if not c then io.stderr:write(e, '\n'); os.exit(1) end"
    echo "  syntax OK: $f"
done
