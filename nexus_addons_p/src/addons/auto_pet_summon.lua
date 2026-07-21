-- Auto Pet Summon ここから
function Auto_pet_summon_save_settings()
    g.save_json(g.auto_pet_summon_path, g.auto_pet_summon_settings)
end

function Auto_pet_summon_load_settings()
    g.auto_pet_summon_path = string.format("../addons/%s/%s/auto_pet_summon.json", addon_name_lower, g.active_id)
    local settings = g.load_json(g.auto_pet_summon_path)
    local changed = false
    if not settings then
        settings = {}
        changed = true
    end
    if not settings[g.cid] then
        settings[g.cid] = {
            iesid = "",
            clsid = 0
        }
        changed = true
    end
    g.auto_pet_summon_settings = settings
    if changed then
        Auto_pet_summon_save_settings()
    end
end

function auto_pet_summon_on_init()
    local cid = session.GetMySession():GetCID()
    if g.get_map_type() == "City" and (not g.auto_pet_summon_cid or cid ~= g.auto_pet_summon_cid) then
        g.auto_pet_summon_cid = cid
        -- 判定に g.cid のエントリまで含めるのは必須。g はキャラチェンジをまたいで
        -- 生き残る一方、settings[cid] を作るのは Auto_pet_summon_load_settings だけなので、
        -- テーブルの有無だけで判定すると「初めて使うキャラへ CC」でエントリが作られず、
        -- 以降 g.auto_pet_summon_settings[g.cid] が nil のまま参照される。
        if not g.auto_pet_summon_settings or not g.auto_pet_summon_settings[g.cid] then
            Auto_pet_summon_load_settings()
        end
        local old_func = g.settings.auto_pet_summon.old_init_func
        if _G[old_func] then
            return
        end
        Auto_pet_summon_companion()
    end
end

function Auto_pet_summon_companion()
    if g.settings.auto_pet_summon.use == 1 then
        if g.auto_pet_summon_settings[g.cid].clsid ~= 0 then
            control.SummonPet(g.auto_pet_summon_settings[g.cid].clsid, g.auto_pet_summon_settings[g.cid].iesid, 0)
        else
            local text = g.lang == "Japanese" and "{ol}[APS]{#FFFFFF} " .. g.login_name .. " {/}ペット未登録" or
                             "{ol}[APS]{#FFFFFF} " .. g.login_name .. " {/}is not registered pet"
            ui.SysMsg(text)
        end
    end
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    if _nexus_addons_p then
        _nexus_addons_p:SetVisible(1)
        local auto_pet_summon_timer = _nexus_addons_p:CreateOrGetControl("timer", "auto_pet_summon_timer", 0, 0)
        AUTO_CAST(auto_pet_summon_timer)
        auto_pet_summon_timer:SetUpdateScript("Auto_pet_summon_save_reserve")
        auto_pet_summon_timer:Start(1.0)
    end
end

function Auto_pet_summon_save_reserve(_nexus_addons_p, auto_pet_summon_timer)
    local summoned_pet = session.pet.GetSummonedPet()
    local pet_is_summoned = (summoned_pet ~= nil)
    local pet_is_saved = (g.auto_pet_summon_settings[g.cid].clsid ~= 0)
    if pet_is_summoned == pet_is_saved then
        return
    end
    if pet_is_summoned then
        local iesid = tostring(summoned_pet:GetStrGuid())
        local pet_obj = summoned_pet:GetObject()
        local clsid = GetIES(pet_obj).ClassID
        g.auto_pet_summon_settings[g.cid].iesid = iesid
        g.auto_pet_summon_settings[g.cid].clsid = clsid
    else
        g.auto_pet_summon_settings[g.cid].iesid = ""
        g.auto_pet_summon_settings[g.cid].clsid = 0
    end
    Auto_pet_summon_save_settings()
end
-- Auto Pet Summon ここまで

