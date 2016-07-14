VFS.Include(LIB_LOBBY_DIRNAME .. "lobby.lua")

LOG_SECTION = "liblobby"

if not Spring.GetConfigInt("LuaSocketEnabled", 0) == 1 then
	Spring.Log(LOG_SECTION, LOG.ERROR, "LuaSocketEnabled is disabled")
	return false
end

Interface = Lobby:extends{}

function Interface:init()
-- dumpConfig()
	self.messagesSentCount = 0
	self.lastSentSeconds = Spring.GetGameSeconds()
	self.status = "offline"
	self.finishedConnecting = false
	self.listeners = {}
	self.duplicateMessageTimes = {} -- how do I give interface_zerok it's own init?
	-- timeout (in seconds) until first message is received from server before disconnect is assumed
	self.connectionTimeout = 50

	-- private
	self.buffer = ""

	self:super("init")
end

function Interface:Connect(host, port)
	self:super("Connect", host, port)
	self.client = socket.tcp()
	self.client:settimeout(0)
	self._startedConnectingTime = os.clock()
	local res, err = self.client:connect(host, port)
	if res == nil and err == "host not found" then
		self:_OnDisconnected("Host not found")
		-- The socket is expected to return "timeout" immediately since timeout time is set  to 0
	elseif not (res == nil and err == "timeout") then 
		Spring.Log(LOG_SECTION, LOG.ERROR, "Error in connect: " .. err)
    else
        self.status = "connecting"
    end
	return true
end

function Interface:Disconnect()
	self.status = "offline"
	self.finishedConnecting = false
	self.client:close()
	self:_OnDisconnected()
end

function Interface:_SendCommand(command, sendMessageCount)
	if sendMessageCount then
		self.messagesSentCount = self.messagesSentCount + 1
		command = "#" .. self.messagesSentCount .. " " .. command
	end
	if command[#command] ~= "\n" then
		command = command .. "\n"
	end
	self.client:send(command)
	self:_CallListeners("OnCommandSent", command:sub(1, #command-1))
	self.lastSentSeconds = Spring.GetGameSeconds()
end

function Interface:SendCustomCommand(command)
	self:_SendCommand(command, false)
end


function Interface:_OnDisconnected()
	self:_CallListeners("OnDisconnected")
end

function Interface:CommandReceived(command)
	local cmdId, cmdName, arguments
	if command:sub(1,1) == "#" then
		i = command:find(" ")
		cmdId = command:sub(2, i - 1)
		j = command:find(" ", i + 1)
		if j ~= nil then
			cmdName = command:sub(i + 1, j - 1)
			arguments = command:sub(j + 1)
		else
			cmdName = command:sub(i + 1)
		end
	else
		i = command:find(" ")
		if i ~= nil then
			cmdName = command:sub(1, i - 1)
			arguments = command:sub(i + 1)
		else
			cmdName = command
		end
	end

	self:_OnCommandReceived(cmdName, arguments, cmdId)
end

function Interface:_GetCommandPattern(cmdName)
	return Interface.commandPattern[cmdName]
end

function Interface:_GetCommandFunction(cmdName)
	return Interface.commands[cmdName], Interface.commandPattern[cmdName]
end

function Interface:_GetJsonCommandFunction(cmdName)
	return Interface.jsonCommands[cmdName]
end

-- status can be one of: "offline", "connected", "connected" and "disconnected"
function Interface:GetConnectionStatus()
	return self.status
end

function Interface:_OnCommandReceived(cmdName, arguments, cmdId)
	local commandFunction, pattern = self:_GetCommandFunction(cmdName)
	local fullCmd
	if arguments ~= nil then
		fullCmd = cmdName .. " " .. arguments
	else
		fullCmd = cmdName
	end

	if commandFunction ~= nil then
		local pattern = self:_GetCommandPattern(cmdName)
		if pattern then
			local funArgs = {arguments:match(pattern)}
			if #funArgs ~= 0 then
				commandFunction(self, unpack(funArgs))
			else
				Spring.Log(LOG_SECTION, LOG.ERROR, "Failed to match command: ", cmdName, ", args: " .. tostring(arguments) .. " with pattern: ", pattern)
			end
		else
			--Spring.Echo("No pattern for command: " .. cmdName)
			commandFunction(self)
		end
	else
		local jsonCommandFunction = self:_GetJsonCommandFunction(cmdName)
		if jsonCommandFunction ~= nil then
			local success, obj = pcall(json.decode, arguments)
			if not success then
				Spring.Log(LOG_SECTION, LOG.ERROR, "Failed to parse JSON: " .. tostring(arguments))
			end
			jsonCommandFunction(self, obj)
		else
			Spring.Log(LOG_SECTION, LOG.ERROR, "No such function: " .. cmdName .. ", for command: " .. fullCmd)
		end
	end
	self:_CallListeners("OnCommandReceived", fullCmd)
end

function Interface:_SocketUpdate()
	if self.client == nil then
		return
	end
	-- get sockets ready for read
	local readable, writeable, err = socket.select({self.client}, {self.client}, 0)
	local host, port = self.client:getpeername()
--	if host == nil then
--		self.client:shutdown()
--		self.client = nil
--		self:_OnDisconnected("Cannot resolve host.")
--		return
--	end
	local brec, bsent, age = self.client:getstats()
	if err ~= nil then
		-- some error happened in select
		if err == "timeout" then
			-- we've received no data after connecting for a while. assume connection cannot be established
			if brec == 0 and os.clock() - self._startedConnectingTime > self.connectionTimeout then
				self.client:shutdown()
				self.client = nil
				self:_OnDisconnected("No response from host.")
			end
			-- nothing to do, return
			return
		end
		Spring.Log(LOG_SECTION, LOG.ERROR, "Error in select: " .. error)
	end
	for _, input in ipairs(readable) do
		local s, status, commandsStr = input:receive('*a') --try to read all data
		if (status == "timeout" or status == nil) and commandsStr ~= nil and commandsStr ~= "" then
			Spring.Log(LOG_SECTION, LOG.DEBUG, commandsStr)
			local commands = explode("\n", commandsStr)
			commands[1] = self.buffer .. commands[1]
			for i = 1, #commands-1 do
				local command = commands[i]
				if command ~= nil then
					self:CommandReceived(command)
				end
			end
			self.buffer = commands[#commands]
		elseif status == "closed" then
			Spring.Log(LOG_SECTION, LOG.INFO, "Disconnected from server.")
			input:close()
			-- if status is "offline", user initiated the disconnection
			if self.status ~= "offline" then
				self.status = "disconnected"
			end
			self:_OnDisconnected()
		end
	end
end

function Interface:SafeUpdate()
	self:super("SafeUpdate")
	self:_SocketUpdate()
	-- prevent timeout with PING
	if self.status == "connected" then
		local nowSeconds = Spring.GetGameSeconds()
		if nowSeconds - self.lastSentSeconds > 30 then
			self:Ping()
		end
	end
end

function Interface:Update()
	xpcall(function() self:SafeUpdate() end,
		function(err) self:_PrintError(err) end )
end
