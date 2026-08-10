function CONTEXT_PARTY(frame, ctrl, aid)	
	local myAid = session.loginInfo.GetAID();
	local pcparty = session.party.GetPartyInfo();
	local iamLeader = false;
	if pcparty.info:GetLeaderAID() == myAid then
		iamLeader = true;
	end

	local myInfo = session.party.GetPartyMemberInfoByAID(PARTY_NORMAL, myAid);	
	local memberInfo = session.party.GetPartyMemberInfoByAID(PARTY_NORMAL, aid);	
	local context = ui.CreateContextMenu("CONTEXT_PARTY", "", 0, 0, 170, 100);
	if session.world.IsIntegrateServer() == true and session.world.IsIntegrateIndunServer() == false then
		local actor = GetMyActor();
		local execScp = string.format("ui.Chat(\"/changePVPObserveTarget %d 0\")", memberInfo:GetHandle());
		ui.AddContextMenuItem(context, ScpArgMsg("Observe{PC}", 'PC',memberInfo:GetName() ), execScp);
		ui.OpenContextMenu(context);
		return;
	end

	if aid == myAid then
		-- 1. 누구든 자기 자신.
		ui.AddContextMenuItem(context, ScpArgMsg("WithdrawParty"), "OUT_PARTY()");			
	elseif iamLeader == true then
		-- 2. 파티장이 파티원 우클릭
		-- 대화하기. 세부정보보기. 파티장 위임. 추방.
		ui.AddContextMenuItem(context, ScpArgMsg("WHISPER"), string.format("ui.WhisperTo('%s')", memberInfo:GetName()));	
		local strRequestAddFriendScp = string.format("friends.RequestRegister('%s')", memberInfo:GetName());
		ui.AddContextMenuItem(context, ScpArgMsg("ReqAddFriend"), strRequestAddFriendScp);
		ui.AddContextMenuItem(context, ScpArgMsg("ShowInfomation"), string.format("OPEN_PARTY_MEMBER_INFO(%d)", memberInfo:GetHandle()));	
		ui.AddContextMenuItem(context, ScpArgMsg("GiveLeaderPermission"), string.format("GIVE_PARTY_LEADER(\"%s\")", memberInfo:GetName()));	
		ui.AddContextMenuItem(context, ScpArgMsg("Ban"), string.format("BAN_PARTY_MEMBER(\"%s\")", memberInfo:GetName()));	
		
		if session.world.IsDungeon() and session.world.IsIntegrateIndunServer() == true then
			local aid = memberInfo:GetAID();
			local serverName = GetServerNameByGroupID(GetServerGroupID());
			local playerName = memberInfo:GetName();
			local scp = string.format("SHOW_INDUN_BADPLAYER_REPORT(\"%s\", \"%s\", \"%s\")", aid, serverName, playerName);
			ui.AddContextMenuItem(context, ScpArgMsg("IndunBadPlayerReport"), scp);
		end
	else
		-- 3. 파티원이 파티원 우클릭
		-- 대화하기. 세부 정보 보기.
		ui.AddContextMenuItem(context, ScpArgMsg("WHISPER"), string.format("ui.WhisperTo('%s')", memberInfo:GetName()));	
		local strRequestAddFriendScp = string.format("friends.RequestRegister('%s')", memberInfo:GetName());
		ui.AddContextMenuItem(context, ScpArgMsg("ReqAddFriend"), strRequestAddFriendScp);
		ui.AddContextMenuItem(context, ScpArgMsg("ShowInfomation"), string.format("OPEN_PARTY_MEMBER_INFO(%d)", memberInfo:GetHandle()));				
		
		if session.world.IsDungeon() and session.world.IsIntegrateIndunServer() == true then
			local aid = memberInfo:GetAID();
			local serverName = GetServerNameByGroupID(GetServerGroupID());
			local playerName = memberInfo:GetName();
			local scp = string.format("SHOW_INDUN_BADPLAYER_REPORT(\"%s\", \"%s\", \"%s\")", aid, serverName, playerName);
			ui.AddContextMenuItem(context, ScpArgMsg("IndunBadPlayerReport"), scp);
		end
	end
	
	ui.AddContextMenuItem(context, ScpArgMsg("Cancel"), "None");
	ui.OpenContextMenu(context);
end
