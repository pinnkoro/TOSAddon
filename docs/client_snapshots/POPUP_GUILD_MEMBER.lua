function POPUP_GUILD_MEMBER(parent, ctrl)
	local aid = parent:GetUserValue("AID");
	if aid == "None" then
		aid = ctrl:GetUserValue("AID");
	end
	
	local memberInfo = session.party.GetPartyMemberInfoByAID(PARTY_GUILD, aid);
	local isLeader = AM_I_LEADER(PARTY_GUILD);
	local myAid = session.loginInfo.GetAID();

	local name = memberInfo:GetName();

	local contextMenuCtrlName = string.format("{@st41}%s{/}", name);
    local context = ui.CreateContextMenu("PC_CONTEXT_MENU", name, 0, 0, 170, 100);
    
    if isLeader == 1 or HAS_KICK_CLAIM() then
        ui.AddContextMenuItem(context, ScpArgMsg("Ban"), string.format("GUILD_BAN('%s')", aid));        
    end

	if isLeader == 1 and aid ~= myAid then
		local mapName = session.GetMapName();
		if mapName == 'guild_agit_1' or mapName == 'guild_agit_extension' then
			ui.AddContextMenuItem(context, ScpArgMsg("GiveGuildLeaderPermission"), string.format("SEND_REQ_GUILD_MASTER('%s')", name));
		end
	end

	if isLeader == 1 then
        local count = session.party.GetAllMemberCount(PARTY_GUILD);
		if count == 1 then
			ui.AddContextMenuItem(context, ScpArgMsg("Disband"), "DESTROY_GUILD()");            
		end
	else
		if aid == myAid then
			ui.AddContextMenuItem(context, ScpArgMsg("GULID_OUT"), "OUT_GUILD_CHECK()");
		end
    end
    
    if isLeader == 1 and aid ~= myAid then
        local summonSkl = GetClass('Skill', 'Templer_SummonGuildMember');
        ui.AddContextMenuItem(context, summonSkl.Name, string.format("SUMMON_GUILD_MEMBER('%s')", aid));
    end

    if isLeader == 1 and aid ~= myAid then
        local goSkl = GetClass('Skill', 'Templer_WarpToGuildMember');
        ui.AddContextMenuItem(context, goSkl.Name, string.format("WARP_GUILD_MEMBER('%s')", aid));
    end

	ui.AddContextMenuItem(context, ScpArgMsg("WHISPER"), string.format("ui.WhisperTo('%s')", name));
	ui.AddContextMenuItem(context, ScpArgMsg("Cancel"), "None");
	ui.OpenContextMenu(context);

end
