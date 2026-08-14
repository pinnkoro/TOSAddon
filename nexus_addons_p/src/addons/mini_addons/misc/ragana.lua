-- 街のラガナを非表示
function Mini_addons_ragana_remove_timer()
    if g.settings.goodbye_ragana == 0 then
        return
    end
    local mini_addons = g.get_frame()
    mini_addons:RunUpdateScript("Mini_addons_ragana_remove", 1.0)
end

function Mini_addons_ragana_remove(mini_addons)
    local selected_objects, selected_objects_count = SelectObject(GetMyPCObject(), 1000, "ALL")
    for i = 1, selected_objects_count do
        local handle = GetHandle(selected_objects[i])
        if handle then
            if info.IsPC(handle) ~= 1 then
                local npc_name = world.GetActor(handle):GetName()
                if npc_name == "[마신의 유혹]{nl}마신 라가나의 환영" then
                    world.Leave(handle, 0.0)
                    return 0
                end

            end
        end
    end
    return 1
end
