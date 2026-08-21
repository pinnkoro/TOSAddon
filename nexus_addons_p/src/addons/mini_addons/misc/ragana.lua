-- 街のラガナを非表示
function Mini_addons_ragana_remove_timer()
    if g.settings.goodbye_ragana == 0 then
        return
    end
    local mini_addons = g.get_frame()
    mini_addons:RunUpdateScript("Mini_addons_ragana_remove", 1.0)
end

-- 消す相手は ClassName で見る。**表示名で判定しないこと。**
-- 以前は韓国語の表示名との完全一致だけを見ていたので、名前が訳されるクライアントでは
-- 一度も当たらなかった(Issue #68)。ClassName はどの言語でも同じ。
--   ies.ipf/monster_npc.ies: ClassName="npc_Ragana_shop" / Name="마신 라가나의 환영"
local RAGANA_CLASS_NAME = "npc_Ragana_shop"
-- 韓国語クライアントで実際に一致していた表示名。ClassName を引けないときの保険に残す
-- (NPC に info.GetMonsterClassName が使えるかは実機でしか確かめられないため)。
local RAGANA_KR_NAME = "[마신의 유혹]{nl}마신 라가나의 환영"

function Mini_addons_ragana_remove(mini_addons)
    local selected_objects, selected_objects_count = SelectObject(GetMyPCObject(), 1000, "ALL")
    for i = 1, selected_objects_count do
        local handle = GetHandle(selected_objects[i])
        if handle then
            if info.IsPC(handle) ~= 1 then
                -- 引けないことがあるので pcall で包む(NPC に対して使えるかは環境依存)。
                local ok, class_name = pcall(info.GetMonsterClassName, handle)
                local matched = (ok and class_name == RAGANA_CLASS_NAME)
                if not matched then
                    local actor = world.GetActor(handle)
                    local npc_name = actor and actor:GetName()
                    if npc_name == RAGANA_KR_NAME then
                        matched = true
                        -- 名前でしか当てられなかった = ClassName が引けていない。
                        -- 実機で切り分けられるよう 1 回だけ残す。
                        core_g.log_error_once("ragana_class_name",
                            "mini_addons: ラガナの幻影を表示名で判定した(ClassName=" .. tostring(class_name) .. ")")
                    end
                end
                if matched then
                    world.Leave(handle, 0.0)
                    return 0
                end
            end
        end
    end
    return 1
end
