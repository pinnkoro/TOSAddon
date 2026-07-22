-- skill_gem_tooltip ここから
function skill_gem_tooltip_on_init()
    local old_func = g.settings.skill_gem_tooltip.old_init_func
    if _G[old_func] then
        return
    end
    g.setup_hook_and_event(g.addon, "UPDATE_ITEM_TOOLTIP", "Skill_gem_tooltip_UPDATE_ITEM_TOOLTIP", true)
end

function Skill_gem_tooltip_UPDATE_ITEM_TOOLTIP(my_frame, my_msg)
    if g.settings.skill_gem_tooltip.use == 0 then
        return
    end
    local tooltip_frame, str_arg, class_id, item_guid, user_data, arg_6, arg_7 = g.get_event_args(my_msg)
    local rect = tooltip_frame:GetMargin()
    local skill_name
    if str_arg == "inven" then
        local item_obj, is_read_obj = GET_TOOLTIP_ITEM_OBJECT(str_arg, item_guid, class_id)
        class_id = item_obj.ClassID
    end
    local item_cls = GetClassByType('Item', class_id)
    if not item_cls or TryGetProp(item_cls, 'StringArg', 'None') ~= 'SkillGem' then
        return
    end
    local skill_name = TryGetProp(item_cls, 'SkillName', 'None')
    if skill_name == 'None' then
        return
    end
    local skill_cls = GetClass('Skill', skill_name)
    if not skill_cls then
        return
    end
    local sub_frame_name = addon_name_lower .. "skill_gem_sub_tooltip"
    local sub_frame = ui.GetFrame(sub_frame_name)
    if not sub_frame then
        sub_frame = ui.CreateNewFrame("notice_on_pc", sub_frame_name, 0, 0, 0, 0)
        AUTO_CAST(sub_frame)
    end
    local template_frame = ui.GetTooltipFrame("skill")
    sub_frame:CloneFrom(template_frame)
    sub_frame:Resize(template_frame:GetWidth(), template_frame:GetHeight())
    sub_frame:RemoveAllChild()
    local function clone_child(src, dest)
        for i = 0, src:GetChildCount() - 1 do
            local child_src = src:GetChildByIndex(i)
            local child_dest = dest:CreateOrGetControl(child_src:GetClassName(), child_src:GetName(), child_src:GetX(),
                child_src:GetY(), child_src:GetWidth(), child_src:GetHeight())
            AUTO_CAST(child_dest)
            child_dest:CloneFrom(child_src)
            if child_src:GetChildCount() > 0 then
                clone_child(child_src, child_dest)
            end
        end
    end
    clone_child(template_frame, sub_frame)
    UPDATE_SKILL_TOOLTIP(sub_frame, str_arg, skill_cls.ClassID, 1, nil, nil)
    local skill_desc = sub_frame:GetChild("skill_desc")
    if skill_desc then
        AUTO_CAST(skill_desc)
        local skill_full_name = TryGetProp(item_cls, 'SkillName', 'None')
        local parts = StringSplit(skill_full_name, '_')
        local job_eng_name = parts[1]
        local suffix_key = parts[3]
        local job_suffix_map = {
            ["Archer"] = "[A]",
            ["Scout"] = "[T]",
            ["Cleric"] = "[C]",
            ["Swordman"] = "[S]",
            ["Wizard"] = "[W]"
        }
        local suffix = job_suffix_map[suffix_key] or ""
        local job_name_fix_map = {
            ["Outlaw"] = "OutLaw",
            ["FrostMage"] = "Cryomancer",
            ["Lancer"] = "Rancer",
            ["FireMage"] = "Pyromancer",
            ["Warrior"] = "Swordman",
            ["Templar"] = "Templer"
        }
        job_eng_name = job_name_fix_map[job_eng_name] or job_eng_name
        local list, cnt = GetClassList("Job")
        for i = 0, cnt - 1 do
            local job_cls = GetClassByIndexFromList(list, i)
            if job_cls then
                local eng_name = job_name_fix_map[job_cls.EngName] or job_cls.EngName
                if eng_name == job_eng_name then
                    local display_name = GET_JOB_NAME(job_cls, GETMYPCGENDER())
                    display_name = string.gsub(dic.getTranslatedStr(display_name), "%[.-%]", "") .. suffix
                    local mark_text = skill_desc:CreateOrGetControl("richtext", "mark_skillgem", 0, 0, 200, 20)
                    mark_text:SetText(string.format("{ol}{#999999}Skill Gem Tooltip{/}{nl}{s18}%s", display_name))
                    mark_text:SetOffset(20, 10)
                    mark_text:SetGravity(ui.LEFT, ui.TOP)
                    local rect = tooltip_frame:GetMargin()
                    if str_arg == "inven" then
                        sub_frame:SetGravity(ui.RIGHT, ui.TOP)
                        sub_frame:SetOffset(rect.right - 250 + tooltip_frame:GetWidth(), 190)
                    elseif str_arg == "char_belonging" then
                        sub_frame:SetGravity(ui.RIGHT, ui.TOP)
                        sub_frame:SetOffset(rect.right - 270 + tooltip_frame:GetWidth(), 255)
                    else
                        sub_frame:SetGravity(ui.LEFT, ui.TOP)
                        sub_frame:SetOffset(rect.left + tooltip_frame:GetWidth(), 255)
                    end
                    sub_frame:SetLayerLevel(tooltip_frame:GetLayerLevel() + 10)
                    sub_frame:RunUpdateScript("Skill_gem_tooltip_close", 0.1)
                    sub_frame:SetUserValue("FLAME_NAME", tooltip_frame:GetName())
                    sub_frame:ShowWindow(1)
                    return
                end
            end
        end
    end
end

function Skill_gem_tooltip_close(sub_frame)
    local obj = ui.GetFocusObject()
    if not obj then
        ui.DestroyFrame(addon_name_lower .. "skill_gem_sub_tooltip")
        return 0
    elseif obj:GetClassName() ~= "slot" then
        ui.DestroyFrame(addon_name_lower .. "skill_gem_sub_tooltip")
        return 0
    end
    return 1
end
-- skill_gem_tooltip ここまで

