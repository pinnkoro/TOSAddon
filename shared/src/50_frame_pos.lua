-- 共通部品: 設定画面を置く位置
--
-- 詳しくは 10_json.lua の冒頭。

-- アドオンの設定画面を置く位置を返す。
--
-- 従来はどの設定画面も「アドオン一覧(list_frame)の右隣」に決め打ちしていたが、
-- **Addons Menu のショートカットから開くと一覧は開いていない**。そのとき
-- ui.GetFrame は nil を返し、素で :GetX() を呼ぶとそこで落ちる。**窓は既に作った後**なので、
-- 利用者からは中身が何も無い空の窓が出るように見える
-- (実機で Auto Repair / Boss Direction で発生。同じ書き方が 11 アドオンにあった)。
--
-- 一覧が開いていればこれまでどおり右隣、開いていなければ画面の中央へ置く。
-- width / height は分かっていれば渡すこと(中央寄せと、画面からはみ出さないための丸めに使う)。
function g.settings_frame_pos(width, height)
    local list = ui.GetFrame(addon_name_lower .. "list_frame")
    local map_ui = ui.GetFrame("map")
    local screen_w = (map_ui and map_ui:GetWidth()) or 1920
    local screen_h = (map_ui and map_ui:GetHeight()) or 1080
    width = width or 400
    height = height or 400
    local x, y
    if list then
        x, y = list:GetX() + list:GetWidth(), list:GetY()
    else
        x, y = math.floor((screen_w - width) / 2), math.floor((screen_h - height) / 2)
    end
    if x + width > screen_w then
        x = screen_w - width
    end
    if y + height > screen_h then
        y = screen_h - height
    end
    if x < 0 then
        x = 0
    end
    if y < 0 then
        y = 0
    end
    return x, y
end
