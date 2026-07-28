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
-- **素で g.detect_origin_addon() と書かないこと。** このファイルは main と conclude の
-- 両方に連結されるが、**conclude が main より先に読まれることがある**(実機で確認)。
-- その場合 detect_origin_addon はまだ定義されておらず、素で呼ぶと nil を呼んで
-- **チャンクの読み込みがここで止まり、conclude 側のアドオンが丸ごと消える**。
-- main は無事なので他の 49 個は普通に動き、「一部のアドオンだけ無反応」だけが残る。
--
-- 読み込み順は同居するアドオンの顔ぶれで変わる。実際、84 バイトの別アドオン
-- (autoacceptduels)を入れただけで順序が入れ替わり、再現した。
-- **conclude 側は「main が読み込み済み」を前提にしてはいけない。**
-- 無ければ同じ判定をその場で行って読み込みを続ける。
local origin_present_at_load
if type(g.detect_origin_addon) == "function" then
    origin_present_at_load = g.detect_origin_addon()
else
    local addons = _G["ADDONS"]
    origin_present_at_load = type(_G["_NEXUS_ADDONS_ON_INIT"]) == "function" or
                                 (type(addons) == "table" and type(addons["norisan"]) == "table" and
                                     type(addons["norisan"]["_NEXUS_ADDONS"]) == "table")
    g.detect_origin_fallback = true
end
g.origin_present_at_load = origin_present_at_load
if not origin_present_at_load then
