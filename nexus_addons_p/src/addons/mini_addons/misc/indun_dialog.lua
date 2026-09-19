-- エンブレム、アークの着け忘れお知らせ
function Mini_addons_SHOW_INDUNENTER_DIALOG(my_frame, my_msg)
    local current_time = os.clock()
    if g.last_indun_check_time and (current_time - g.last_indun_check_time < 1.0) then
        return
    end
    g.last_indun_check_time = current_time
    if g.settings.equip_info == 0 then
        return
    end
    local indun_frame = ui.GetFrame("indunenter")
    local indun_type = indun_frame:GetUserValue("INDUN_TYPE")
    -- レイドの Hard(パーティ)。731 = ズメイ、735 / 738 = 偽りの輝翼 / 堕落した審判の翼
    local target_indun_list = {665, 670, 675, 678, 681, 628, 687, 690, 697, 709, 712, 718, 724, 727, 731, 735, 738}
    local is_target = false
    for i = 1, #target_indun_list do
        if tostring(target_indun_list[i]) == tostring(indun_type) then
            is_target = true
            break
        end
    end
    if not is_target then
        return
    end
    local equip_item_list = session.GetEquipItemList()
    local cnt = equip_item_list:Count()
    for i = 0, cnt - 1 do
        local equip_item = equip_item_list:GetEquipItemByIndex(i)
        local spot_name = item.GetEquipSpotName(equip_item.equipSpot)
        local iesid = tostring(equip_item:GetIESID())
        if tostring(spot_name) == "SEAL" and tonumber(iesid) == 0 then
            if g.lang == "Japanese" then
                imcAddOn.BroadMsg("NOTICE_Dm_Global_Shout",
                    "{st55_a}{#FF8C00}エンブレム装備してないけど{nl}ええんか？", 3.0)
            else -- You don't have an emblem equipped. {nl} Is this okay?
                imcAddOn.BroadMsg("NOTICE_Dm_Global_Shout",
                    "{st55_a}{#FF8C00}You don't have an emblem equipped{nl}Is this okay?", 3.0)
            end
            break
        elseif tostring(spot_name) == "ARK" and tonumber(iesid) == 0 then
            if g.lang == "Japanese" then
                imcAddOn.BroadMsg("NOTICE_Dm_Global_Shout",
                    "{st55_a}{#FF8C00}アーク装備してないけど{nl}ええんか？", 3.0)
            else
                imcAddOn.BroadMsg("NOTICE_Dm_Global_Shout",
                    "{st55_a}{#FF8C00}You don't have an ark equipped{nl}Is this okay?", 3.0)
            end
            break
        end
    end
end
-- 自動マッチのレイヤーを下げる
function Mini_addons_INDUNENTER_AUTOMATCH_TYPE(my_frame, my_msg)
    local indunenter = ui.GetFrame("indunenter")
    if g.settings.automatch_layer == 1 then
        indunenter:SetLayerLevel(97)
    elseif g.settings.automatch_layer == 0 then
        indunenter:SetLayerLevel(100)
    end
end
-- 死んだ時の選択肢を動かす
function Mini_addons_RESTART_HERE()
    if g.settings.restart_move == 0 then
        return
    end
    local restart_contents = ui.GetFrame("restart_contents")
    if restart_contents:IsVisible() == 1 then
        restart_contents:EnableHittestFrame(1)
        restart_contents:EnableMove(1)
    end
    local restart = ui.GetFrame("restart")
    if restart:IsVisible() == 1 then
        restart:EnableHittestFrame(1)
        restart:EnableMove(1)
    end
end
-- 死んだ時のマウス位置制御
function Mini_addons_RESTART_CONTENTS_ON_HERE(my_frame, my_msg)
    if g.settings.restart_move == 0 then
        return
    end
    local restart_contents = ui.GetFrame("restart_contents")
    local btn_restart = GET_CHILD_RECURSIVELY(restart_contents, "btn_restart_" .. 1)
    local item_width = btn_restart:GetWidth()
    local item_height = btn_restart:GetHeight()
    local x, y = GET_SCREEN_XY(btn_restart + item_width / 2, btn_restart + item_height / 2)
    mouse.SetPos(x, y)
end
-- 入場ウィンドウの枠を縮める前の大きさを控えておく鍵(素のフレームの UserValue)。
-- 名前がぶつからないよう印を付ける
local FIT_KEEP_W, FIT_KEEP_H = "NEXUS_FIT_KEEP_W", "NEXUS_FIT_KEEP_H"

-- 入場ウィンドウの右側に残る、見えないクリック判定を消す(設定 indun_enter_fit)
--
-- 素の indunenter は枠が 1100x800 で `hittestframe="true"`(= 枠の矩形まるごとがクリックを受ける)。
-- ところが実際に描くのは bigmode 1020x700 の中の mainBox 730x650 だけで、右の 300px は倍数モードの
-- 箱(multiBox)。**レイドでは INDUNENTER_MAKE_MULTI_BOX が multiBox:ShowWindow(0) で消すのに、枠は
-- 1100 のまま**なので、消えた箱のぶんがクリックを飲み続ける(後ろの 3D 画面を触れない)。
--
-- **EnableHittestFrame(0) で判定を切ってはいけない。** この窓はタイトルバーを描かず
-- moveintitlebar="false" なので、枠の判定がドラッグ移動そのもの。切ると窓を動かせなくなる上、
-- 見えている部分のクリックが 3D 画面へ抜けてキャラクターが歩き出す。
-- 代わりに枠を中身ぴったりへ詰め直す。素自身が INDUNENTER_SMALL で
-- topFrame:Resize(bigmode の大きさ) → INDUNENTER_AMEND_OFFSET(topFrame) をしているので、同じ手順。
function Mini_addons_indunenter_fit_frame()
    local indunenter = ui.GetFrame("indunenter")
    if not indunenter or indunenter:IsVisible() == 0 then
        return
    end
    -- 小さいモード(自動マッチ中)は素が smallmode の大きさへ縮めている。ここで触ると喧嘩になる
    if indunenter:GetUserValue("FRAME_MODE") ~= "BIG" then
        return
    end
    if g.settings.indun_enter_fit == 0 then
        -- OFF へ戻した人のために、**自分が縮めたときだけ**元の大きさへ返す。
        --
        -- **「XML 宣言値(1100x800)と違う = 自分が縮めた」と見なしてはいけない。**
        -- 素は小さいモードから大きいモードへ戻すとき、枠を bigmode の大きさ(1020x700)へ
        -- resize する(indunenter.lua の INDUNENTER_SMALL)。宣言値と比べると、
        -- **一度も ON にしていない利用者の往復まで「縮んでいる」と誤判定して 1100x800 へ
        -- 広げてしまい、死角が素より広くなる**。縮める前の大きさを控えておいて、
        -- 控えがあるときだけ返す。
        local kept_w = indunenter:GetUserIValue(FIT_KEEP_W)
        local kept_h = indunenter:GetUserIValue(FIT_KEEP_H)
        if kept_w > 0 and kept_h > 0 then
            indunenter:SetUserValue(FIT_KEEP_W, 0)
            indunenter:SetUserValue(FIT_KEEP_H, 0)
            indunenter:Resize(kept_w, kept_h)
            INDUNENTER_AMEND_OFFSET(indunenter)
            core_g.vlog("mini_addons: 入場ウィンドウを元の大きさへ返した %dx%d", kept_w, kept_h)
        end
        return
    end
    local bigmode = GET_CHILD_RECURSIVELY(indunenter, "bigmode")
    local main_box = GET_CHILD_RECURSIVELY(indunenter, "mainBox")
    local multi_box = GET_CHILD_RECURSIVELY(indunenter, "multiBox")
    if not bigmode or not main_box or not multi_box then
        return
    end
    -- 倍数モードの箱が出ているダンジョンでは bigmode の幅が要る(素が大きいモードへ戻すときと同じ値)。
    -- 消えているレイドでは mainBox の幅で足りる(bottomBox 708 も etcInfoGbox 728 も mainBox の中に収まる)
    local width = bigmode:GetWidth()
    if multi_box:IsVisible() == 0 then
        width = main_box:GetWidth()
    end
    -- 縮める前の大きさを控える(OFF へ戻したときの戻り先)。控えるのは最初の 1 回だけで、
    -- 2 回目以降は自分が縮めた後の大きさなので上書きしない
    if indunenter:GetUserIValue(FIT_KEEP_W) <= 0 then
        indunenter:SetUserValue(FIT_KEEP_W, indunenter:GetWidth())
        indunenter:SetUserValue(FIT_KEEP_H, indunenter:GetHeight())
    end
    core_g.vlog("mini_addons: 入場ウィンドウを詰める %dx%d → %dx%d (multiBox 表示=%d)", indunenter:GetWidth(),
        indunenter:GetHeight(), width, bigmode:GetHeight(), multi_box:IsVisible())
    indunenter:Resize(width, bigmode:GetHeight())
    INDUNENTER_AMEND_OFFSET(indunenter)
end
