function CHAT_RBTN_POPUP(frame, chatCtrl)
	local topFrame = frame:GetTopParentFrame()
	local parentFrame = frame:GetParent()
	local topFrame_Name = topFrame:GetName()
	local parentFrame_Name = parentFrame:GetName()

	if session.world.IsIntegrateServer() == true then
		ui.SysMsg(ScpArgMsg("CantUseThisInIntegrateServer"))
		return
	end

	
	local targetName = chatCtrl:GetUserValue("TARGET_NAME")
	local targetTxt = chatCtrl:GetUserValue("SENTENCE")
	if targetName == "" or GETMYFAMILYNAME() == targetName then
		return
	end
	local context = ui.CreateContextMenu("CONTEXT_CHAT_RBTN", targetName, 0, 0, 170, 100)
	ui.AddContextMenuItem(context, ScpArgMsg("WHISPER"), string.format("ui.WhisperTo('%s')", targetName))	
	local strRequestAddFriendScp = string.format("friends.RequestRegister('%s')", targetName)
	ui.AddContextMenuItem(context, ScpArgMsg("ReqAddFriend"), strRequestAddFriendScp)
	local partyinviteScp = string.format("PARTY_INVITE(\"%s\")", targetName)
	ui.AddContextMenuItem(context, ScpArgMsg("PARTY_INVITE"), partyinviteScp)

	-- translate Menu
	local txt = chatCtrl:GetTextByKey("text")
	local ctrlName = frame:GetName()
	if GET_PRIVATE_CHANNEL_ACTIVE_STATE() == true then
		local translateScp  = string.format("REQ_TRANSLATE_TEXT('%s','%s','%s')",topFrame_Name,parentFrame_Name,ctrlName)
		ui.AddContextMenuItem(context, ScpArgMsg("TRANSLATE"),translateScp)
	end
	local copyPcId = string.format("COPY_PC_ID('%s')",targetName)
	ui.AddContextMenuItem(context, ScpArgMsg("CopyPcId"),copyPcId)

	local copyPcSentence = string.format("COPY_PC_SENTENCE('%s')",targetTxt)
	ui.AddContextMenuItem(context, ScpArgMsg("CopyPcSentence"),copyPcSentence)

	
	local blockScp = string.format("CHAT_BLOCK_MSG('%s')", targetName )
	ui.AddContextMenuItem(context, ScpArgMsg("FriendBlock"), blockScp)
	ui.AddContextMenuItem(context, ScpArgMsg("Report_AutoBot"), string.format("REPORT_AUTOBOT_MSGBOX(\"%s\")", targetName))


	ui.AddContextMenuItem(context, ScpArgMsg("Cancel"), "None")
	ui.OpenContextMenu(context)
end
