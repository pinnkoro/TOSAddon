-- ギルド保管箱を 1 日 1 回、自動で更新する
--
-- ギルド情報「保管箱」タブの右上にある更新ボタン(素の updateBtn2、ツールチップ
-- 「ギルド保管箱を更新します。」)を、その日の最初のログインで 1 回だけ代わりに押す。
-- 素のボタンがしていることは guildinfo_info.lua の GUILDINFO_INFO_UPDATE_WAREHOUSE の
--     party.RequestReloadInventory(PARTY_GUILD)
-- だけなので、窓は開かずにこれを同じように呼ぶ(素の関数を呼ばないのは、引数の ctrl に
-- ボタンが要り、DISABLE_BUTTON_DOUBLECLICK が guildinfo の窓を触るため)。
--
-- 「1 日」の区切りはゲームの日替わり(朝 6:00)に合わせる。押した日は g.settings の
-- guild_storage_reload_day に控える(アカウントごと。保管箱はギルドで 1 つなので、
-- 同じ日にキャラを替えても押し直さない)。
--
-- **local は増やさない**(mini_addons の断片はメインチャンク直下へ連結され、1 関数 200 個の枠を食う)。

-- 日替わり(6:00)で区切った今日の日付。6:00 より前は前の日として扱う
function Mini_addons_guild_storage_reload_day()
    return os.date("%Y-%m-%d", os.time() - 6 * 3600)
end

-- GAME_START_3SEC(マップ移動のたび)から呼ぶ。押すのはその日の最初の 1 回だけ
function Mini_addons_guild_storage_reload()
    if g.settings.guild_storage_reload ~= 1 then
        return
    end
    local today = Mini_addons_guild_storage_reload_day()
    if g.settings.guild_storage_reload_day == today then
        return
    end
    -- ギルドに入っていない(またはまだ情報が届いていない)ときは押さずに、日付も控えない。
    -- 次のマップ移動でもう一度見る
    if session.party.GetPartyInfo(PARTY_GUILD) == nil then
        core_g.vlog("mini_addons: ギルド保管箱の更新 ギルドの情報が無いので見送り(%s)", today)
        return
    end
    party.RequestReloadInventory(PARTY_GUILD)
    core_g.vlog("mini_addons: ギルド保管箱を更新した(前回 %s → %s)", tostring(g.settings.guild_storage_reload_day),
        today)
    g.settings.guild_storage_reload_day = today
    Mini_addons_save_settings()
end
