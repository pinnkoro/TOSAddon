-- スキル・アイテム連打音消す
--
-- 素の ICON_USE は、クールタイム中に押されると「使えない」音(skill_cooltime)を鳴らす。
--   * スキル … control.Skill(ネイティブ)の中で鳴る。Lua からは鳴らす/鳴らさないを選べないので、
--              クールタイム中は素を呼ばずに戻る。
--   * アイテム … 素の ICON_USE が Lua で item.GetCoolDown を見て、鳴らしてすぐ戻る。
--              戻るだけなので、素を呼ばなくても音以外は何も変わらない。
-- アイテムは当初対象外で、quickslot_operate がダンジョンごとにポーションを差し替えるキャラだけ
-- 鳴り続けていた(連打キーにポーションが入っているかどうかで「人によって鳴る」ように見えた)。
-- 装備品は素がクールタイムを見ずに着替えるだけなので止めない。

-- 押された内容と判断の材料をログへ出す。
-- 連打ツールは 1 秒に何度も押すので、同じスロットの同じ状態は 2 秒に 1 行へ絞る。
-- 音はネイティブ側でも鳴り、Lua からは鳴ったかどうかが取れないので、どのカテゴリの何が
-- どの状態で押されたかを残す(実機の切り分けで、ポーションが原因だと分かったのはこのログ)。
-- ここで落ちてスキルが使えなくなると本末転倒なので pcall で受ける(詳細ログ OFF なら何もしない)。
function Mini_addons_log_icon_use(icon, cooldown, blocked)
    if not core_g.settings or core_g.settings.verbose_log ~= 1 or not icon then
        return
    end
    local ok, err = pcall(function()
        local icon_info = icon:GetInfo()
        local category = icon_info:GetCategory()
        local icon_type = icon_info.type
        local name, detail, state
        if category == "Skill" then
            local cls = GetClassByType("Skill", icon_type)
            local usable = control.IsSkillIconUsable(icon_type)
            name = cls and cls.ClassName or "?"
            detail = string.format("cooldown=%s usable=%s", tostring(cooldown), tostring(usable))
            state = tostring(cooldown and cooldown > 0) .. "/" .. tostring(usable)
        elseif category == "Item" then
            -- cooldown が nil なのは装備品(クールタイムを見ていない)
            local cls = GetClassByType("Item", icon_type)
            name = cls and cls.ClassName or "?"
            detail = string.format("item_cooldown=%s", tostring(cooldown))
            state = tostring(cooldown ~= nil and cooldown ~= 0)
        else
            name = "-"
            detail = "-"
            state = "-"
        end
        g.icon_use_log = g.icon_use_log or {}
        local key = category .. ":" .. tostring(icon_type)
        local now = imcTime.GetAppTime()
        local last = g.icon_use_log[key]
        state = state .. "/" .. tostring(blocked)
        if last and last.state == state and now - last.time < 2 then
            return
        end
        g.icon_use_log[key] = {state = state, time = now}
        core_g.vlog("mini_addons: ICON_USE %s %s(%s) %s setting=%s blocked=%s", tostring(category), name,
            tostring(icon_type), detail, tostring(g.settings.skill_cool_sound), tostring(blocked))
    end)
    if not ok then
        core_g.vlog("{#FF6347}mini_addons: ICON_USE のログで失敗{/} %s", tostring(err))
    end
end

function Mini_addons_ICON_USE(object, re_action)
    local original_func = g.FUNCS["ICON_USE"]
    local icon = object and tolua.cast(object, "ui::CIcon") or nil
    local cooldown = nil
    local blocked = false
    if icon then
        local icon_info = icon:GetInfo()
        local category = icon_info:GetCategory()
        local enabled = g.settings.skill_cool_sound ~= 0
        if category == "Skill" then
            cooldown = ICON_UPDATE_SKILL_COOLDOWN(icon)
            blocked = enabled and cooldown > 0
        elseif category == "Item" then
            local cls = GetClassByType("Item", icon_info.type)
            if cls and IS_EQUIP(cls) ~= true then
                cooldown = item.GetCoolDown(icon_info.type)
                blocked = enabled and cooldown ~= 0
            end
        end
    end
    Mini_addons_log_icon_use(icon, cooldown, blocked)
    if blocked then
        return
    end
    if original_func then
        original_func(object, re_action)
    end
end
