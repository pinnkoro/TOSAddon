-- 共通部品: 詳細ログ
--
-- 取り込む側が先に用意するもの: g / addon_name_lower / g.vlog_tag(チャットに出す印)。
-- 詳しくは 10_json.lua の冒頭。

-- 詳細ログ。アドオンメニューボタン右クリックの設定画面にある
-- 「詳細なログをシステムに出力する」が ON のときだけ、チャットのシステムメッセージへ出す。
-- 既定は OFF なので、通常の利用者のチャットは今までどおり静かなまま。
--
-- 保存先は g.settings(= ../addons/_nexus_addons_p/<AID>/settings.json)。
-- UI を出している 90_addons_menu.lua 側の addons_menu.json はメニューの位置と
-- 表示設定だけを持つので、アドオン全体の設定であるこれは置かない(詳細は 90 側のコメント)。
--
-- 初期化前(g.settings がまだ nil)や、本家検出で初期化を止めた場合も黙って何もしない。
-- 書式化の失敗でデバッグ用のログが本体を巻き込んで落とすことがないよう pcall で包む。
--
-- チャットは流れてしまい後から読み返せないので、同じ内容をファイルにも残す。
-- 不具合報告用に「そのまま送れる」ことを狙っており、
--   * 出力先は debug_log.txt とは別。あちらはエラーの履歴を追記し続ける用途で、
--     詳細ログを混ぜると際限なく育ち、必要な部分も探しにくくなる。
--   * 作り直すのはクライアント起動後の最初の 1 行だけ(下の vlog_write)。
--   * 色やタグ({ol} 等)は読みづらいだけなので、ファイル側では外す。
local vlog_file_path = string.format('../addons/%s/verbose_log.txt', addon_name_lower)
-- チャットへ出すときの印。取り込む側が g.vlog_tag で決める(既定はアドオン名の頭文字)
local vlog_tag = g.vlog_tag or "LOG"
-- 行数の上限。マップ移動のたびに全アドオンの init 行(50 行前後)が出るため、
-- 1 回のプレイでも積み上がる。到達したら取り直して際限なく育たないようにする。
local vlog_max_lines = 20000

local function vlog_write(line)
    local mode, notice = "a", nil
    if not g.vlog_started then
        -- 作り直すのはここだけ。GAME_START はマップ移動のたびに来るので、
        -- そこで毎回作り直すと直前のマップのログ(初期化エラーを含む)が消える。
        -- g はクライアント起動中ずっと生きるので、1 回のプレイで 1 ファイルになる。
        mode = "w"
    elseif g.vlog_lines >= vlog_max_lines then
        mode = "w"
        notice = "===== 行数が上限に達したのでここから取り直し ====="
    end
    local file = io.open(vlog_file_path, mode)
    if not file then
        -- 開けなかったときは状態を進めない。ここで vlog_started を立ててしまうと、
        -- 作り直しに失敗したまま次回から追記モードになり、前回起動分のログに
        -- 書き足す形になる(「中身は常に今回の起動分だけ」が崩れ、報告用に使えない)。
        -- 上限到達時も同じで、取り直せていないのに行数だけ 0 に戻すと以後伸び続ける。
        return
    end
    g.vlog_started = true
    if mode == "w" then
        g.vlog_lines = 0
    end
    local stamp = os.date("[%H:%M:%S] ")
    if notice then
        file:write(stamp .. notice .. "\n")
        g.vlog_lines = g.vlog_lines + 1
    end
    file:write(stamp .. line .. "\n")
    file:close()
    g.vlog_lines = g.vlog_lines + 1
end

-- 実際に出力したときだけ true を返す。
--
-- 「同じ行を 1 回だけ出す」ために印を立てる呼び出し側が幾つかあるが、印を先に立てると
-- **既定 OFF の間に印だけ消費され、後から ON にしても二度と出ない**。特に
-- ログイン直後の非同期初期化はログを ON にする前に走り切るので、一番知りたい
-- 起動時の 1 回が必ず消える(実機で発生)。印は必ずこの戻り値で立てること:
--     if not g.foo_logged and g.vlog("...") then g.foo_logged = true end
function g.vlog(fmt, ...)
    if not g.settings or g.settings.verbose_log ~= 1 then
        return false
    end
    local ok, msg = pcall(string.format, fmt, ...)
    if not ok then
        msg = tostring(fmt)
    end
    ui.SysMsg("{ol}{#00BFFF}[" .. vlog_tag .. "]{/} " .. msg)
    local plain = msg:gsub("{[^}]*}", "")
    vlog_write(plain)
    return true
end
