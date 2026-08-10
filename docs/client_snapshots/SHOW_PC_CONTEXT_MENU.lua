function SHOW_PC_CONTEXT_MENU(handle)
	if world.IsPVPMap() == true or session.colonywar.GetIsColonyWarMap() == true or IS_IN_EVENT_MAP() == true then
		return;
	end

	local pcObj = world.GetActor(handle);
	if pcObj == nil then
		return;
	end

	local targetInfo= info.GetTargetInfo(handle);
	if targetInfo.IsDummyPC == 1 then
		--유체이탈 or 환영 클릭해도 아무반응 없도록 한다.
		local is_enable = true;
		local cid = info.GetCID(handle);
		if cid ~= nil and cid ~= "" and cid ~= "None" then
			local ies_obj = GetPCObjectByCID(cid);
			if ies_obj ~= nil then
				if IsBuffApplied(ies_obj, "Illusion_Buff") == "YES" then
					is_enable = false;
				end
			end
		end
		if targetInfo.isSkillObj == 0 and is_enable == true then 
			POPUP_DUMMY(handle, targetInfo);
		end
		return
	end

	if pcObj:IsMyPC() == 1 then
		if 1 == session.IsGM() then
			local contextMenuCtrlName = string.format("{@st41}%s (%d){/}", pcObj:GetPCApc():GetFamilyName(), handle);
			local context = ui.CreateContextMenu("PC_CONTEXT_MENU", pcObj:GetPCApc():GetFamilyName(), 0, 0, 100, 100);

			local strscp = string.format("ui.Chat(\"//runscp TEST_SERVPOS %d\")", handle);
			ui.AddContextMenuItem(context, ScpArgMsg("Auto_{@st42b}SeoBeowiChiBoKi{/}"), strscp);

			strscp = string.format("debug.TestNode(%d)", handle);
			ui.AddContextMenuItem(context, ScpArgMsg("Auto_{@st42b}NodeBoKi{/}"), strscp);

			strscp = string.format("debug.CheckModelFilePath(%d)", handle);
			ui.AddContextMenuItem(context, ScpArgMsg("Auto_{@st42b}XACTegSeuChyeoKyeongLo{/}"), strscp);

			strscp = string.format("debug.TestSnapTexture(%d)", handle);
			ui.AddContextMenuItem(context, "{@st42b}SnapTexture{/}", strscp);

			strscp = string.format("debug.TestShowBoundingBox(%d)", handle);
			ui.AddContextMenuItem(context, ScpArgMsg("Auto_{@st42b}BaunDingBagSeuBoKi{/}"), strscp);
			
            strscp = string.format("SCR_OPER_RELOAD_HOTKEY(%d)", handle);
			ui.AddContextMenuItem(context, "ReloadHotKey", strscp);
			
			strscp = string.format("SCR_CLIENTTESTSCP(%d)", handle);
			ui.AddContextMenuItem(context, "ClientTestScp", strscp);
			
			ui.OpenContextMenu(context);

			return context;
		end

		
	end
	
	local partyinfo = session.party.GetPartyInfo();
	local accountObj = GetMyAccountObj();
	if pcObj:IsMyPC() == 0 and info.IsPC(pcObj:GetHandleVal()) == 1 then
		if targetInfo.IsDummyPC == 1 then
			packet.DummyPCDialog(handle);
			return  context;
		end
			
		local contextMenuCtrlName = string.format("{@st41}%s (%d){/}", pcObj:GetPCApc():GetFamilyName(), handle);
		local context = ui.CreateContextMenu("PC_CONTEXT_MENU", pcObj:GetPCApc():GetFamilyName(), 0, 0, 270, 100);

		-- 여기에 캐릭터 정보보기, 로그아웃PC관련 메뉴 추가하면됨
		if session.world.IsIntegrateServer() == false then
			local strScp = string.format("exchange.RequestChange(%d)", pcObj:GetHandleVal());
			ui.AddContextMenuItem(context, "{img context_transaction 18 18} "..ClMsg("Exchange"), strScp);
		
			local strWhisperScp = string.format("ui.WhisperTo('%s')", pcObj:GetPCApc():GetFamilyName());
			ui.AddContextMenuItem(context, "{img context_whisper 18 17} "..ClMsg("WHISPER"), strWhisperScp);
			strScp = string.format("PARTY_INVITE(\"%s\")", pcObj:GetPCApc():GetFamilyName());
			ui.AddContextMenuItem(context, "{img context_party_invitation 18 17} "..ClMsg("PARTY_INVITE"), strScp);
                        
            --[[
			if AM_I_LEADER(PARTY_GUILD) == 1 or IS_GUILD_AUTHORITY(1, session.loginInfo.GetAID()) == 1 then
				strScp = string.format("GUILD_INVITE(\"%s\")", pcObj:GetPCApc():GetFamilyName());
				ui.AddContextMenuItem(context, ClMsg("GUILD_INVITE"), strScp);
			end
			--]]
			if session.party.GetPartyInfo(PARTY_GUILD) ~= nil and targetInfo.hasGuild == false then
				strScp = string.format("GUILD_INVITE(\"%s\")", pcObj:GetPCApc():GetFamilyName());
				ui.AddContextMenuItem(context, "{img context_guild_invitation 18 17} "..ClMsg("GUILD_INVITE"), strScp);
			end

			strscp = string.format("barrackNormal.Visit(%d)", handle);
			ui.AddContextMenuItem(context, "{img context_lodging_visit 16 17} "..ScpArgMsg("VisitBarrack"), strscp);
			strscp = string.format("ui.ToggleHeaderText(%d)", handle);
			if pcObj:GetHeaderText() ~= nil and string.len(pcObj:GetHeaderText()) ~= 0 then
				if pcObj:IsHeaderTextVisible() == true  then			
					ui.AddContextMenuItem(context, "{img context_preface_block 18 17} "..ClMsg("BlockTitleText"), strscp);
				else
					ui.AddContextMenuItem(context, "{img context_preface_remove 18 17} "..ClMsg("UnblockTitleText"), strscp);
				end
			end
		end

		strscp = string.format("PROPERTY_COMPARE(%d)", handle);
		ui.AddContextMenuItem(context, "{img context_look_into 18 17} "..ScpArgMsg("Auto_SalPyeoBoKi"), strscp);
			
		if session.world.IsIntegrateServer() == false then
			local strRequestAddFriendScp = string.format("friends.RequestRegister('%s')", pcObj:GetPCApc():GetFamilyName());
			ui.AddContextMenuItem(context, "{img context_friend_application 18 13} "..ScpArgMsg("ReqAddFriend"), strRequestAddFriendScp);
		end

		ui.AddContextMenuItem(context, "{img context_friendly_match 18 17} "..ScpArgMsg("RequestFriendlyFight"), string.format("REQUEST_FIGHT(\"%d\")", pcObj:GetHandleVal()));
		-- ui.AddContextMenuItem(context, ScpArgMsg("RequestFriendlyAncientFight"), string.format("REQUEST_ANCIENT_FIGHT(\"%d\")", pcObj:GetHandleVal()));
		
		local mapprop = session.GetCurrentMapProp();
    	local mapCls = GetClassByType("Map", mapprop.type);	
		if IS_TOWN_MAP(mapCls) == true then
			ui.AddContextMenuItem(context, "{img context_personal_housing 18 17} "..ScpArgMsg("PH_SEL_DLG_2"), string.format("REQUEST_PERSONAL_HOUSING_WARP(\"%s\")", pcObj:GetPCApc():GetAID()));
		end

		local familyname = pcObj:GetPCApc():GetFamilyName()
		local otherpcinfo = session.otherPC.GetByFamilyName(familyname);
		
		if session.world.IsIntegrateServer() == false then
			local strRequestLikeItScp = string.format("SEND_PC_INFO(%d)", handle);
			if session.likeit.AmILikeYou(familyname) == true then
				ui.AddContextMenuItem(context, "{img context_like 18 17} "..ScpArgMsg("ReqUnlikeIt"), strRequestLikeItScp);
			else
				ui.AddContextMenuItem(context, "{img context_like 18 17} "..ScpArgMsg("ReqLikeIt"), strRequestLikeItScp);
			end
		end

		ui.AddContextMenuItem(context, "{img context_automatic_suspicion 16 17} "..ScpArgMsg("Report_AutoBot"), string.format("REPORT_AUTOBOT_MSGBOX(\"%s\")", pcObj:GetPCApc():GetFamilyName()));

        -- report guild emblem
        if  pcObj:IsGuildExist() == true then
            ui.AddContextMenuItem(context, "{img context_inappropriate_emblem 17 17} "..ScpArgMsg("Report_GuildEmblem"), string.format("REPORT_GUILDEMBLEM_MSGBOX(\"%s\")", pcObj:GetPCApc():GetFamilyName()));        
        end

		-- 보호모드, 강제킥
		if 1 == session.IsGM() then
			ui.AddContextMenuItem(context, ScpArgMsg("GM_Order_Protected"), string.format("REQUEST_GM_ORDER_PROTECTED(\"%s\")", pcObj:GetPCApc():GetFamilyName()));
			ui.AddContextMenuItem(context, ScpArgMsg("GM_Order_Kick"), string.format("REQUEST_GM_ORDER_KICK(\"%s\")", pcObj:GetPCApc():GetFamilyName()));
		end
		
		if session.world.IsDungeon() and session.world.IsIntegrateIndunServer() == true then
			local aid = pcObj:GetPCApc():GetAID();
			local serverName = GetServerNameByGroupID(GetServerGroupID());
			local playerName = pcObj:GetPCApc():GetFamilyName();
			local scp = string.format("SHOW_INDUN_BADPLAYER_REPORT(\"%s\", \"%s\", \"%s\")", aid, serverName, playerName);
			ui.AddContextMenuItem(context, ScpArgMsg("IndunBadPlayerReport"), scp);
		end

		ui.AddContextMenuItem(context, "{img context_cancel 18 17} "..ClMsg("Cancel"), "None");
		ui.OpenContextMenu(context);
		return  context;
	end
end
