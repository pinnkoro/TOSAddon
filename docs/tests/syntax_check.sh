#!/bin/sh
# 連結後 bundle の Lua 構文チェック。src 単体では guard_open.lua が `if ... then` を
# 開いたまま終わるなど構文的に不完全なため、必ず bundle に対して行う。
# loadfile はロードのみで実行しないので、ゲーム API が無い環境でも使える。
#
# 対象は manifest の targets から引く。ここにファイル名を直書きすると、bundle の
# 構成を変えたときに置き去りになる（実際に _nexus_addons_p_conclude.lua を廃止した
# 後も、存在しないファイルを開こうとして「開けない」とだけ出していた）。
set -eu
py=$(command -v python3 || command -v python)
targets=$($py -c "import json;print(' '.join(json.load(open('nexus_addons_p/src/build_manifest.json'))['targets']))")
# 空なら「1 つも検査していない」= 素通り。set -e はコマンド置換の失敗を拾わないので、
# ここで明示的に落とす（黙って 0 件成功するのが一番危ない）。
if [ -z "$targets" ]; then
    echo "targets を manifest から取得できない" >&2
    exit 1
fi
for t in $targets; do
    f="nexus_addons_p/_nexus_addons_p/$t"
    luajit -e "local c, e = loadfile('$f'); if not c then io.stderr:write(e, '\n'); os.exit(1) end"
    echo "  syntax OK: $f"
done
