--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name      = "Queue List Window",
		desc      = "Handles matchMaking queue list display.",
		author    = "GoogleFrog",
		date      = "11 September 2016",
		license   = "GNU LGPL, v2.1 or later",
		layer     = -100000,
		enabled   = true  --  loaded by default?
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Variables

local requiredResources = {}
local requiredResourceCount = 0

local panelInterface

local function HaveRightEngineVersion()
	local engineVersion = WG.LibLobby.lobby:GetSuggestedEngineVersion()
	return (not engineVersion) or WG.Chobby.Configuration:IsValidEngineVersion(engineVersion)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Initialization

local function MakeQueueControl(parentControl, queueName, queueDescription, players, waiting)
	local Configuration = WG.Chobby.Configuration
	
	local btnLeave, btnJoin
	
	btnJoin = Button:New {
		x = 0,
		y = 0,
		width = 80,
		bottom = 0,
		caption = i18n("join"),
		font = Configuration:GetFont(3),
		classname = "option_button",
		OnClick = {
			function(obj)
				if not HaveRightEngineVersion() then
					WG.Chobby.InformationPopup("Game engine update required, restart the menu to apply.")
					return
				end
				if requiredResourceCount ~= 0 then
					WG.Chobby.InformationPopup("All required maps and games must be downloaded before you can join matchmaking.")
					return
				end
			
				WG.LibLobby.lobby:JoinMatchMaking(queueName)
				obj:SetVisibility(false)
				btnLeave:SetVisibility(true)
			end
		},
		parent = parentControl
	}
	
	btnLeave = Button:New {
		x = 0,
		y = 0,
		width = 80,
		bottom = 0,
		caption = i18n("leave"),
		font = Configuration:GetFont(3),
		classname = "action_button",
		OnClick = {
			function(obj)
				WG.LibLobby.lobby:LeaveMatchMaking(queueName)
				obj:SetVisibility(false)
				btnJoin:SetVisibility(true)
			end
		},
		parent = parentControl
	}
	btnLeave:SetVisibility(false)
	
	local lblTitle = TextBox:New {
		x = 90,
		y = 15,
		width = 120,
		height = 33,
		fontsize = Configuration:GetFont(3).size,
		text = queueName,
		parent = parentControl
	}
	
	local lblDescription = TextBox:New {
		x = 180,
		y = 8,
		width = 120,
		height = 22,
		right = 5,
		align = "bottom",
		fontsize = Configuration:GetFont(1).size,
		text = queueDescription,
		parent = parentControl
	}
	
	local lblPlayers = TextBox:New {
		x = 180,
		y = 30,
		width = 120,
		height = 22,
		right = 5,
		align = "bottom",
		fontsize = Configuration:GetFont(1).size,
		text = "Playing: " .. players,
		parent = parentControl
	}
	
	local lblWaiting = TextBox:New {
		x = 280,
		y = 30,
		width = 120,
		height = 22,
		right = 5,
		align = "bottom",
		fontsize = Configuration:GetFont(1).size,
		text = "Waiting: " .. waiting,
		parent = parentControl
	}
	
	local externalFunctionsAndData = {}
	
	externalFunctionsAndData.inQueue = false
	
	function externalFunctionsAndData.SetInQueue(inQueue)
		btnJoin:SetVisibility(not inQueue)
		btnLeave:SetVisibility(inQueue)
	end
	
	function externalFunctionsAndData.UpdateQueueInformation(newName, newDescription, newPlayers, newWaiting)
		if newName then
			lblTitle:SetText(newName)
		end
		if newDescription then
			lblDescription:SetText(newDescription)
		end
		if newPlayers then
			lblPlayers:SetText("Playing: " .. newPlayers)
		end
		if newWaiting then
			lblWaiting:SetText("Waiting: " .. newWaiting)
		end
	end
	
	return externalFunctionsAndData
end

local function InitializeControls(window)
	local Configuration = WG.Chobby.Configuration
	local lobby = WG.LibLobby.lobby
	
	local banStart
	local banDuration
	
	local lblTitle = Label:New {
		x = 20,
		right = 5,
		y = 16,
		height = 20,
		font = Configuration:GetFont(3),
		caption = "Queues",
		parent = window
	}

	local btnClose = Button:New {
		right = 7,
		y = 5,
		width = 80,
		height = 45,
		caption = i18n("close"),
		font = Configuration:GetFont(3),
		classname = "negative_button",
		OnClick = {
			function()
				window:Hide()
			end
		},
		parent = window
	}

	local listPanel = ScrollPanel:New {
		x = 5,
		right = 5,
		y = 55,
		height = 200,
		borderColor = {0,0,0,0},
		horizontalScrollbar = false,
		parent = window
	}
	
	local statusText = TextBox:New {
		x = 5,
		right = 5,
		y = 270,
		height = 200,
		fontsize = Configuration:GetFont(2).size,
		text = "",
		parent = window
	}
	
	local requirementText = TextBox:New {
		x = 5,
		right = 5,
		y = 350,
		height = 200,
		fontsize = Configuration:GetFont(2).size,
		text = "",
		parent = window
	}
	
	local queues = 0
	local queueHolders = {}
	local function AddQueue(_, queueName, queueDescription, mapNames)
		local queueData = lobby:GetQueue(queueName) or {}
		if queueHolders[queueName] then
			queueHolders[queueName].UpdateQueueInformation(queueName, queueDescription, queueData.playersIngame or "?", queueData.playersWaiting or "?")
			return
		end
	
		local queueHolder = Control:New {
			x = 10,
			y = queues*55 + 15,
			right = 0,
			height = 45,
			caption = "", -- Status Window
			parent = listPanel,
			resizable = false,
			draggable = false,
			padding = {0, 0, 0, 0},
		}
		queueHolders[queueName] = MakeQueueControl(queueHolder, queueName, queueDescription, queueData.playersIngame or "?", queueData.playersWaiting or "?")
		queues = queues + 1
	end
	
	local possibleQueues = lobby:GetQueues()
	for name, data in pairs(possibleQueues) do
		AddQueue(_, data.name, data.description, data.mapNames)
	end
	
	local function UpdateQueueStatus(listener, inMatchMaking, joinedQueueList, queueCounts, ingameCounts, _, _, _, bannedTime)
		if joinedQueueList then
			for i = 1, #joinedQueueList do
				local queueName = joinedQueueList[i]
				if queueHolders[queueName] then
					queueHolders[queueName].inQueue = true
				end
			end
		end
		
		for queueName, waitingCount in pairs(queueCounts) do
			queueHolders[queueName].UpdateQueueInformation(nil, nil, ingameCounts and ingameCounts[queueName], waitingCount)
		end
		
		for name, queueHolder in pairs(queueHolders) do
			queueHolder.SetInQueue(queueHolder.inQueue)
			queueHolder.inQueue = false
		end
		
		if bannedTime then
			statusText:SetText("You are banned from matchmaking for " .. bannedTime .. " seconds")
			banStart = Spring.GetTimer()
			banDuration = bannedTime
		end
	end
	
	if lobby.matchMakerBannedTime then
		statusText:SetText("You are banned from matchmaking for " .. lobby.matchMakerBannedTime .. " seconds")
		banStart = Spring.GetTimer()
		banDuration = lobby.matchMakerBannedTime
	end
	
	lobby:AddListener("OnQueueOpened", AddQueue)
	lobby:AddListener("OnMatchMakerStatus", UpdateQueueStatus)
	
	local externalFunctions = {}
		
	function externalFunctions.UpdateBanTimer()
		if not banStart then
			return
		end
		local timeRemaining = banDuration - math.ceil(Spring.DiffTimers(Spring.GetTimer(), banStart))
		if timeRemaining < 0 then
			banStart = false
			statusText:SetText("")
			return
		end
		statusText:SetText("You are banned from matchmaking for " .. timeRemaining .. " seconds")
	end
	
	function externalFunctions.UpdateRequirementText()
		local newText = ""
		local firstEntry = true
		for name,_ in pairs(requiredResources) do
			if firstEntry then
				newText = "Required resources: "
			else
				newText = newText .. ", "
			end
			firstEntry = false
			newText = newText .. name
		end
		
		if not HaveRightEngineVersion() then
			if firstEntry then
				newText = "Game engine update required, restart the menu to apply."
			else
				newText = "\nGame engine update required, restart the menu to apply."
			end
		end
		requirementText:SetText(newText)
	end
	
	externalFunctions.UpdateRequirementText()
	
	return externalFunctions
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- External Interface

local QueueListWindow = {}

function QueueListWindow.HaveMatchMakerResources()
	return requiredResourceCount == 0 and HaveRightEngineVersion()
end

function QueueListWindow.GetControl()

	local window = Control:New {
		x = "0%",
		y = "0%",
		width = "100%",
		height = "100%",
		padding = {0, 0, 0, 0},
		OnParent = {
			function(obj)
				if obj:IsEmpty() then
					panelInterface = InitializeControls(obj)
				end
			end
		},
	}
	
	return window
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Widget Interface

function widget:Update()
	if panelInterface then
		panelInterface.UpdateBanTimer()
	end
end

function widget:DownloadFinished()
	for resourceName,_ in pairs(requiredResources) do
		local haveResource = VFS.HasArchive(resourceName)
		if haveResource then
			requiredResources[resourceName] = nil
			requiredResourceCount = requiredResourceCount - 1
		end
	end
	
	if panelInterface then
		panelInterface.UpdateRequirementText()
	end
end

function widget:Initialize()
	CHOBBY_DIR = LUA_DIRNAME .. "widgets/chobby/"
	VFS.Include(LUA_DIRNAME .. "widgets/chobby/headers/exports.lua", nil, VFS.RAW_FIRST)

	local function AddQueue(_, queueName, queueDescription, mapNames, maxPartSize, gameNames)
		for i = 1, #mapNames do
			local mapName = mapNames[i]
			if not requiredResources[mapName] then
				local haveMap = VFS.HasArchive(mapName)
				if not haveMap then
					requiredResources[mapName] = true
					requiredResourceCount = requiredResourceCount + 1
					
					VFS.DownloadArchive(mapName, "map")
				end
			end
		end
		
		for i = 1, #gameNames do
			local gameName = gameNames[i]
			if not requiredResources[gameName] then
				local haveGame = VFS.HasArchive(gameName)
				if not haveGame then
					requiredResources[gameName] = true
					requiredResourceCount = requiredResourceCount + 1
					
					VFS.DownloadArchive(gameName, "game")
				end
			end
		end
		
		if panelInterface then
			panelInterface.UpdateRequirementText()
		end
	end
	
	WG.LibLobby.lobby:AddListener("OnQueueOpened", AddQueue)
	
	WG.QueueListWindow = QueueListWindow
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------