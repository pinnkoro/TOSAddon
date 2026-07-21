-- ===== 本家 Nexus Addons と同名グローバルの衝突回避(ここから) =====
-- この下で定義される addons/** の関数は Always_status_* / Indun_panel_* のように
-- 本家 Nexus Addons と同名のグローバル関数(意図的にリネームしていない)。両方が
-- インストールされていると、後から読み込まれた側の定義が先の側を丸ごと上書きし、
-- 先に読み込まれた側のボタンやイベントが「別インスタンスの g」を掴んで壊れる。
--
-- そこで本家が先に読み込まれている場合はアドオン本体を一切定義しない。この場合
-- core/20_lifecycle.lua の _NEXUS_ADDONS_P_ON_INIT が競合を検出して何もせず終了し、
-- 本家がそのまま正常動作する。逆に本家より先に読み込まれた場合は普通に定義し、
-- 後から本家の定義が上書きするのでやはり本家が正常動作する。
-- どちらの読み込み順でも本家を壊さない。
local origin_present_at_load = g.detect_origin_addon()
g.origin_present_at_load = origin_present_at_load
if not origin_present_at_load then
