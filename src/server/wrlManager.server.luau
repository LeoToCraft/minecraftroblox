local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

Players.CharacterAutoLoads = false

_G.MCRE = _G.MCRE or {}
local MCRE = _G.MCRE

MCRE.Version = "0.0.16a"
MCRE.Runtime = MCRE.Runtime or {
	IsWorldServer = false,
	WorldLoaded = false,
	OwnerUserId = nil,
	SlotId = nil,
	WorldData = nil,
	ReservedAccessCode = nil,
	PrivateServerId = nil,
	HostSettings = nil,
}

local rmtGame = ReplicatedStorage:WaitForChild("rmtGame")

local RequestWorldList = rmtGame:WaitForChild("RequestWorldList")
local CreateWorld = rmtGame:WaitForChild("CreateWorld")
local LoadWorld = rmtGame:WaitForChild("LoadWorld")
local SaveAndQuitWorld = rmtGame:WaitForChild("SaveAndQuitWorld")
local UpdateSettings = rmtGame:WaitForChild("UpdateSettings")
local DeleteWorld = rmtGame:WaitForChild("DeleteWorld")
local RenameWorld = rmtGame:WaitForChild("RenameWorld")
local RequestServerList = rmtGame:WaitForChild("RequestServerList")
local UpdateHostSettings = rmtGame:WaitForChild("UpdateHostSettings")
local HostCurrentWorld = rmtGame:WaitForChild("HostCurrentWorld")
local JoinHostedServer = rmtGame:WaitForChild("JoinHostedServer")
local CommandFeedback = rmtGame:FindFirstChild("CommandFeedback")

if not CommandFeedback then
	CommandFeedback = Instance.new("RemoteEvent")
	CommandFeedback.Name = "CommandFeedback"
	CommandFeedback.Parent = rmtGame
end

local blocksFolder = ServerStorage:WaitForChild("blcStorage")

local function getBlockTemplate(blockName, alternateName)
	local template = blocksFolder:FindFirstChild(blockName) or blocksFolder:FindFirstChild(alternateName)
	if template then
		return template
	end

	error(string.format("Missing block template %s in ServerStorage.blcStorage.", blockName))
end

local grassBlock = getBlockTemplate("blcGrass", "GrassBlock")

local WORLDS_STORE = DataStoreService:GetDataStore("MCRE_W_Alpha_0_0_7")
local SETTINGS_STORE = DataStoreService:GetDataStore("MCRE_S_Alpha_0_0_7")
local HOST_STORE = DataStoreService:GetDataStore("MCRE_H_Alpha_0_0_7")
local HOST_MAP = MemoryStoreService:GetSortedMap("MCRE_Hosted_Alpha_0_0_7")

local BLOCK_SIZE = grassBlock.Size.X
local PLACE_ID = game.PlaceId

local DEFAULT_SETTINGS = {
	Graphics = 2,
	ShowDebugUI = true,
}

local DEFAULT_HOST_SETTINGS = {
	Enabled = false,
	ServerName = "My Server",
	Password = "",
}

local studioWorldLists = {}
local studioWorldData = {}
local studioSettings = {}
local studioHostSettings = {}
local studioHosted = {}

local function worldListKey(userId)
	return "list_" .. tostring(userId)
end

local function worldDataKey(userId, slotId)
	return "world_" .. tostring(userId) .. "_" .. tostring(slotId)
end

local function settingsKey(userId)
	return "settings_" .. tostring(userId)
end

local function hostKey(userId)
	return "host_" .. tostring(userId)
end

local function safeGet(store, key, fallback)
	local ok, result = pcall(function()
		return store:GetAsync(key)
	end)
	if ok then
		if result == nil then
			return fallback
		end
		return result
	end
	return fallback
end

local function safeSet(store, key, value)
	pcall(function()
		store:SetAsync(key, value)
	end)
end

local function safeRemove(store, key)
	pcall(function()
		store:RemoveAsync(key)
	end)
end

local function normalizeWorldSize(sizeName)
	sizeName = tostring(sizeName or "Small")
	if sizeName == "Medium" then
		return "Medium", 192, 192
	elseif sizeName == "Large" then
		return "Large", 320, 320
	elseif sizeName == "Huge" then
		return "Huge", 512, 512
	end
	return "Small", 96, 96
end

local function normalizeWorldType(worldType)
	worldType = tostring(worldType or "Normal")
	if worldType == "Superflat" then
		return "Superflat"
	end
	return "Normal"
end

local function makeRandomSeed(player, slotId)
	local stamp = math.floor(os.clock() * 1000000)
	local rng = Random.new(os.time() + player.UserId + (slotId or 0) * 101 + stamp)
	return string.format("%d-%d-%d", player.UserId, os.time(), rng:NextInteger(1, 2147483646))
end

local function getWorldList(userId)
	local key = worldListKey(userId)

	if RunService:IsStudio() then
		if not studioWorldLists[key] then
			studioWorldLists[key] = {
				[1] = nil,
				[2] = nil,
				[3] = nil,
			}
		end
		return studioWorldLists[key]
	end

	local data = safeGet(WORLDS_STORE, key, nil)
	if type(data) == "table" then
		return data
	end

	return {
		[1] = nil,
		[2] = nil,
		[3] = nil,
	}
end

local function saveWorldList(userId, list)
	local key = worldListKey(userId)

	if RunService:IsStudio() then
		studioWorldLists[key] = list
		return
	end

	safeSet(WORLDS_STORE, key, list)
end

local function getWorldData(userId, slotId)
	local key = worldDataKey(userId, slotId)

	if RunService:IsStudio() then
		return studioWorldData[key]
	end

	local data = safeGet(WORLDS_STORE, key, nil)
	if type(data) == "table" then
		return data
	end
	return nil
end

local function saveWorldData(userId, slotId, data)
	local key = worldDataKey(userId, slotId)

	if RunService:IsStudio() then
		studioWorldData[key] = data
		return
	end

	safeSet(WORLDS_STORE, key, data)
end

local function removeWorldData(userId, slotId)
	local key = worldDataKey(userId, slotId)

	if RunService:IsStudio() then
		studioWorldData[key] = nil
		return
	end

	safeRemove(WORLDS_STORE, key)
end

local function getPlayerSettings(userId)
	local key = settingsKey(userId)

	if RunService:IsStudio() then
		return studioSettings[key] or {
			Graphics = DEFAULT_SETTINGS.Graphics,
			ShowDebugUI = DEFAULT_SETTINGS.ShowDebugUI,
		}
	end

	local data = safeGet(SETTINGS_STORE, key, nil)
	if type(data) == "table" then
		return {
			Graphics = tonumber(data.Graphics) or DEFAULT_SETTINGS.Graphics,
			ShowDebugUI = data.ShowDebugUI ~= false,
		}
	end

	return {
		Graphics = DEFAULT_SETTINGS.Graphics,
		ShowDebugUI = DEFAULT_SETTINGS.ShowDebugUI,
	}
end

local function savePlayerSettings(userId, settings)
	local key = settingsKey(userId)

	if RunService:IsStudio() then
		studioSettings[key] = settings
		return
	end

	safeSet(SETTINGS_STORE, key, settings)
end

local function getHostSettings(userId)
	local key = hostKey(userId)

	if RunService:IsStudio() then
		return studioHostSettings[key] or {
			Enabled = DEFAULT_HOST_SETTINGS.Enabled,
			ServerName = DEFAULT_HOST_SETTINGS.ServerName,
			Password = DEFAULT_HOST_SETTINGS.Password,
		}
	end

	local data = safeGet(HOST_STORE, key, nil)
	if type(data) == "table" then
		return {
			Enabled = data.Enabled == true,
			ServerName = tostring(data.ServerName or DEFAULT_HOST_SETTINGS.ServerName),
			Password = tostring(data.Password or DEFAULT_HOST_SETTINGS.Password),
		}
	end

	return {
		Enabled = DEFAULT_HOST_SETTINGS.Enabled,
		ServerName = DEFAULT_HOST_SETTINGS.ServerName,
		Password = DEFAULT_HOST_SETTINGS.Password,
	}
end

local function saveHostSettings(userId, settings)
	local key = hostKey(userId)

	if RunService:IsStudio() then
		studioHostSettings[key] = settings
		return
	end

	safeSet(HOST_STORE, key, settings)
end

local function setLobbyState(player)
	player:SetAttribute("GameVersion", MCRE.Version)
	player:SetAttribute("InMenu", true)
	player:SetAttribute("Paused", false)
	player:SetAttribute("WorldLoaded", false)
	player:SetAttribute("WorldLoading", false)
	player:SetAttribute("WorldLoadProgress", 0)
	player:SetAttribute("CurrentWorldSlot", 0)
	player:SetAttribute("InventoryOpen", false)

	if player.Character then
		player.Character:Destroy()
	end
end

local function setLoadingState(player, slotId)
	player:SetAttribute("GameVersion", MCRE.Version)
	player:SetAttribute("InMenu", false)
	player:SetAttribute("WorldLoaded", false)
	player:SetAttribute("WorldLoading", true)
	player:SetAttribute("WorldLoadProgress", 0)
	player:SetAttribute("CurrentWorldSlot", slotId or 0)
	player:SetAttribute("InventoryOpen", false)
end

local function setLoadedState(player, slotId)
	player:SetAttribute("GameVersion", MCRE.Version)
	player:SetAttribute("InMenu", false)
	player:SetAttribute("WorldLoaded", true)
	player:SetAttribute("WorldLoading", false)
	player:SetAttribute("WorldLoadProgress", 100)
	player:SetAttribute("CurrentWorldSlot", slotId or 0)
	player:SetAttribute("InventoryOpen", false)
end

local function applySettingsAttributes(player)
	local settings = getPlayerSettings(player.UserId)
	player:SetAttribute("Graphics", settings.Graphics)
	player:SetAttribute("ShowDebugUI", settings.ShowDebugUI)
end

local function beginHostedState(ownerUserId)
	local runtime = MCRE.Runtime
	local hostSettings = runtime.HostSettings
	if not hostSettings or hostSettings.Enabled ~= true then
		return
	end

	local ownerName = "Unknown"
	local ok, result = pcall(function()
		return Players:GetNameFromUserIdAsync(ownerUserId)
	end)
	if ok and result then
		ownerName = result
	end

	local payload = {
		OwnerUserId = ownerUserId,
		OwnerName = ownerName,
		SlotId = runtime.SlotId,
		ServerName = hostSettings.ServerName,
		Password = hostSettings.Password,
		HasPassword = hostSettings.Password ~= "",
		ReservedAccessCode = runtime.ReservedAccessCode,
		PrivateServerId = runtime.PrivateServerId,
		UpdatedAt = os.time(),
	}

	if RunService:IsStudio() then
		studioHosted[tostring(ownerUserId)] = payload
		return
	end

	pcall(function()
		HOST_MAP:SetAsync(tostring(ownerUserId), payload, 3600, payload.UpdatedAt)
	end)
end

local function removeHostedState(ownerUserId)
	if not ownerUserId then
		return
	end

	if RunService:IsStudio() then
		studioHosted[tostring(ownerUserId)] = nil
		return
	end

	pcall(function()
		HOST_MAP:RemoveAsync(tostring(ownerUserId))
	end)
end

local function getHostedList(excludeUserId)
	if RunService:IsStudio() then
		local list = {}
		for _, payload in pairs(studioHosted) do
			if payload.OwnerUserId ~= excludeUserId then
				table.insert(list, payload)
			end
		end
		return list
	end

	local ok, items = pcall(function()
		return HOST_MAP:GetRangeAsync(Enum.SortDirection.Descending, 50)
	end)

	if not ok or type(items) ~= "table" then
		return {}
	end

	local result = {}
	for _, item in ipairs(items) do
		if type(item.value) == "table" and item.value.OwnerUserId ~= excludeUserId then
			table.insert(result, item.value)
		end
	end
	return result
end

local function getHostedInfo(ownerUserId)
	if RunService:IsStudio() then
		return studioHosted[tostring(ownerUserId)]
	end

	local ok, item = pcall(function()
		return HOST_MAP:GetAsync(tostring(ownerUserId))
	end)

	if ok then
		return item
	end
	return nil
end

local function bootWorldServerFromJoin(player)
	local joinData = player:GetJoinData()
	local teleportData = joinData and joinData.TeleportData

	if type(teleportData) ~= "table" then
		return false
	end

	local mode = tostring(teleportData.Mode or "")
	if mode ~= "WORLD_SERVER" and mode ~= "JOIN_HOSTED_WORLD" then
		return false
	end

	local ownerUserId = tonumber(teleportData.OwnerUserId)
	local slotId = tonumber(teleportData.SlotId)

	if not ownerUserId or not slotId then
		return false
	end

	local worldData = getWorldData(ownerUserId, slotId)
	if not worldData then
		return false
	end

	MCRE.Runtime.IsWorldServer = true
	MCRE.Runtime.WorldLoaded = false
	MCRE.Runtime.OwnerUserId = ownerUserId
	MCRE.Runtime.SlotId = slotId
	MCRE.Runtime.WorldData = worldData
	MCRE.Runtime.ReservedAccessCode = tostring(teleportData.ReservedAccessCode or "")
	MCRE.Runtime.PrivateServerId = tostring(teleportData.PrivateServerId or "")
	MCRE.Runtime.HostSettings = getHostSettings(ownerUserId)

	return true
end

local function saveRuntimeWorld()
	local runtime = MCRE.Runtime
	if runtime.OwnerUserId and runtime.SlotId and runtime.WorldData then
		runtime.WorldData.LastPlayedAt = os.time()
		saveWorldData(runtime.OwnerUserId, runtime.SlotId, runtime.WorldData)
	end
end

local function buildRuntimeWorld()
	if not MCRE.BuildWorld then
		return false, "World generation not loaded"
	end

	local runtime = MCRE.Runtime
	if not runtime.WorldData then
		return false, "No world data"
	end

	local ok, err = pcall(function()
		MCRE.BuildWorld(runtime.WorldData)
	end)
	if not ok then
		return false, tostring(err)
	end

	runtime.WorldLoaded = true
	return true
end

local respawnScheduled = {}

local function getSafeSpawnCFrame()
	local worldData = MCRE.Runtime.WorldData or {}
	local width = tonumber(worldData.Width) or MCRE.WorldWidth or 64
	local depth = tonumber(worldData.Depth) or MCRE.WorldDepth or 64
	local gridX = MCRE.SpawnGridX or math.max(1, math.floor(width * 0.5))
	local gridZ = MCRE.SpawnGridZ or math.max(1, math.floor(depth * 0.5))
	local surfaceY = 20

	if MCRE.HeightAt then
		local ok, result = pcall(function()
			return MCRE.HeightAt(gridX, gridZ)
		end)
		if ok and type(result) == "number" then
			surfaceY = result
		end
	end

	return CFrame.new(gridX * BLOCK_SIZE, (surfaceY + 4) * BLOCK_SIZE, gridZ * BLOCK_SIZE)
end

local function moveCharacterToSafeSpawn(character)
	local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 6)
	if root then
		character:PivotTo(getSafeSpawnCFrame())
	end
end

local function spawnWorldCharacter(player)
	if not player.Parent or not MCRE.Runtime.WorldLoaded then
		return
	end

	player:LoadCharacter()
	local character = player.Character or player.CharacterAdded:Wait()
	moveCharacterToSafeSpawn(character)
end

local function scheduleWorldRespawn(player, delaySeconds)
	if respawnScheduled[player] then
		return
	end

	respawnScheduled[player] = true
	task.delay(delaySeconds or 0, function()
		respawnScheduled[player] = nil
		if player.Parent and MCRE.Runtime.IsWorldServer and MCRE.Runtime.WorldLoaded then
			spawnWorldCharacter(player)
		end
	end)
end

local function watchWorldCharacter(player, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 8)
	if humanoid then
		humanoid.MaxHealth = 20
		humanoid.Health = humanoid.MaxHealth
		humanoid.Died:Connect(function()
			scheduleWorldRespawn(player, 1.5)
		end)
	end

	task.spawn(function()
		while player.Parent and character.Parent and MCRE.Runtime.IsWorldServer and MCRE.Runtime.WorldLoaded do
			local root = character:FindFirstChild("HumanoidRootPart")
			if root and root.Position.Y < -80 then
				scheduleWorldRespawn(player, 0)
				return
			end
			task.wait(0.35)
		end
	end)
end

local function splitWords(text)
	local words = {}
	for word in string.gmatch(tostring(text or ""), "%S+") do
		table.insert(words, word)
	end
	return words
end

local function countMapEntries(map)
	local total = 0
	if type(map) ~= "table" then
		return total
	end
	for _ in pairs(map) do
		total += 1
	end
	return total
end

local function sendCommandFeedback(player, message)
	local line = "[MCRE] " .. tostring(message)
	print(line)
	if player and player.Parent then
		CommandFeedback:FireClient(player, line)
	end
	return line
end

local function canRunCommand(player)
	if RunService:IsStudio() then
		return true
	end
	return player ~= nil and (MCRE.Runtime.OwnerUserId == nil or MCRE.Runtime.OwnerUserId == player.UserId)
end

local function getCharacterRoot(player)
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function runMcreCommand(player, commandText)
	if not canRunCommand(player) then
		return sendCommandFeedback(player, "Command denied. Only the world owner can use MCRE commands in published servers.")
	end

	local args = splitWords(commandText)
	local command = string.lower(args[1] or "help")

	if command == "help" then
		return sendCommandFeedback(player, "Commands: help, status, version, seed, pos, chunks, water, spawn, tp <x> <y> <z>.")
	end

	if command == "version" then
		return sendCommandFeedback(player, "Version " .. MCRE.Version)
	end

	if command == "seed" then
		local worldData = MCRE.Runtime.WorldData or {}
		return sendCommandFeedback(player, "Seed: " .. tostring(worldData.Seed or "none"))
	end

	if command == "status" then
		local worldData = MCRE.Runtime.WorldData or {}
		local folder = Workspace:FindFirstChild("WorldBlocks")
		local blocks = folder and #folder:GetChildren() or 0
		local chunks = countMapEntries(MCRE.LoadedChunks)
		return sendCommandFeedback(player, string.format(
			"WorldLoaded=%s, Size=%sx%s, Type=%s, Blocks=%s, Chunks=%s",
			tostring(MCRE.Runtime.WorldLoaded),
			tostring(worldData.Width or MCRE.WorldWidth or "?"),
			tostring(worldData.Depth or MCRE.WorldDepth or "?"),
			tostring(worldData.WorldType or "Normal"),
			tostring(blocks),
			tostring(chunks)
		))
	end

	if command == "chunks" then
		return sendCommandFeedback(player, string.format(
			"Loaded chunks=%s, loaded columns=%s, indexed blocks=%s",
			tostring(countMapEntries(MCRE.LoadedChunks)),
			tostring(countMapEntries(MCRE.LoadedColumns)),
			tostring(countMapEntries(MCRE.BlockIndex))
		))
	end

	if command == "water" then
		return sendCommandFeedback(player, "WaterLevel=" .. tostring(MCRE.WaterLevel or "unknown"))
	end

	if command == "pos" then
		local root = getCharacterRoot(player)
		if not root then
			return sendCommandFeedback(player, "No character position.")
		end
		local gridX = math.floor(root.Position.X / BLOCK_SIZE + 0.5)
		local gridY = math.floor(root.Position.Y / BLOCK_SIZE + 0.5)
		local gridZ = math.floor(root.Position.Z / BLOCK_SIZE + 0.5)
		return sendCommandFeedback(player, string.format("Position studs=(%.1f, %.1f, %.1f), grid=(%d, %d, %d)", root.Position.X, root.Position.Y, root.Position.Z, gridX, gridY, gridZ))
	end

	if command == "spawn" then
		if player then
			spawnWorldCharacter(player)
			return sendCommandFeedback(player, "Respawned at the safe world spawn.")
		end
		return sendCommandFeedback(player, "Run spawn with a player in Studio: _G.MCRE.RunCommand(player, \"spawn\")")
	end

	if command == "tp" then
		if not player then
			return sendCommandFeedback(player, "Run tp with a player in Studio: _G.MCRE.RunCommand(player, \"tp 32 24 32\")")
		end
		local x = tonumber(args[2])
		local y = tonumber(args[3])
		local z = tonumber(args[4])
		if not x or not y or not z then
			return sendCommandFeedback(player, "Usage: tp <gridX> <gridY> <gridZ>")
		end
		local character = player.Character
		if character then
			character:PivotTo(CFrame.new(x * BLOCK_SIZE, y * BLOCK_SIZE, z * BLOCK_SIZE))
			return sendCommandFeedback(player, string.format("Teleported to grid=(%d, %d, %d)", math.floor(x), math.floor(y), math.floor(z)))
		end
		return sendCommandFeedback(player, "No character to teleport.")
	end

	return sendCommandFeedback(player, "Unknown command. Use /mcre help.")
end

MCRE.RunCommand = function(playerOrCommand, maybeCommand)
	if typeof(playerOrCommand) == "Instance" and playerOrCommand:IsA("Player") then
		return runMcreCommand(playerOrCommand, maybeCommand or "help")
	end

	if type(playerOrCommand) == "string" and maybeCommand ~= nil then
		local matchedPlayer = Players:FindFirstChild(playerOrCommand)
		return runMcreCommand(matchedPlayer, maybeCommand)
	end

	return runMcreCommand(Players:GetPlayers()[1], playerOrCommand or "help")
end

local function startStudioWorld(player, slotId, worldData)
	MCRE.Runtime.IsWorldServer = true
	MCRE.Runtime.WorldLoaded = false
	MCRE.Runtime.OwnerUserId = player.UserId
	MCRE.Runtime.SlotId = slotId
	MCRE.Runtime.WorldData = worldData
	MCRE.Runtime.ReservedAccessCode = "STUDIO"
	MCRE.Runtime.PrivateServerId = "STUDIO"
	MCRE.Runtime.HostSettings = getHostSettings(player.UserId)

	setLoadingState(player, slotId)
	player:SetAttribute("WorldLoadProgress", 10)

	local ok, err = buildRuntimeWorld()
	if not ok then
		return { Success = false, Message = tostring(err) }
	end

	player:SetAttribute("WorldLoadProgress", 90)
	spawnWorldCharacter(player)
	setLoadedState(player, slotId)
	return { Success = true }
end

RequestWorldList.OnServerInvoke = function(player)
	applySettingsAttributes(player)

	return {
		Version = MCRE.Version,
		Worlds = getWorldList(player.UserId),
		Settings = getPlayerSettings(player.UserId),
		Host = getHostSettings(player.UserId),
	}
end

CreateWorld.OnServerInvoke = function(player, slotId, worldName, worldSize, worldType, seedText)
	slotId = tonumber(slotId)
	if slotId ~= 1 and slotId ~= 2 and slotId ~= 3 then
		return { Success = false, Message = "Invalid slot" }
	end

	local sizeName, width, depth = normalizeWorldSize(worldSize)
	local normalizedType = normalizeWorldType(worldType)

	worldName = tostring(worldName or "")
	if worldName == "" then
		worldName = "New World"
	end

	seedText = tostring(seedText or "")
	if seedText == "" then
		seedText = makeRandomSeed(player, slotId)
	end

	local list = getWorldList(player.UserId)
	list[slotId] = {
		Name = worldName,
		Width = width,
		Depth = depth,
		WorldSize = sizeName,
		WorldType = normalizedType,
		Seed = seedText,
		CreatedAt = os.time(),
		LastPlayedAt = os.time(),
	}
	saveWorldList(player.UserId, list)

	saveWorldData(player.UserId, slotId, {
		Name = worldName,
		Width = width,
		Depth = depth,
		WorldSize = sizeName,
		WorldType = normalizedType,
		Seed = seedText,
		CreatedAt = os.time(),
		LastPlayedAt = os.time(),
		Changes = {},
	})

	return { Success = true }
end

DeleteWorld.OnServerInvoke = function(player, slotId)
	slotId = tonumber(slotId)
	if slotId ~= 1 and slotId ~= 2 and slotId ~= 3 then
		return { Success = false, Message = "Invalid slot" }
	end

	local list = getWorldList(player.UserId)
	list[slotId] = nil
	saveWorldList(player.UserId, list)
	removeWorldData(player.UserId, slotId)

	return { Success = true }
end

RenameWorld.OnServerInvoke = function(player, slotId, newName)
	slotId = tonumber(slotId)
	newName = tostring(newName or "")

	if slotId ~= 1 and slotId ~= 2 and slotId ~= 3 then
		return { Success = false, Message = "Invalid slot" }
	end

	if newName == "" then
		return { Success = false, Message = "Empty name" }
	end

	local list = getWorldList(player.UserId)
	if not list[slotId] then
		return { Success = false, Message = "World not found" }
	end

	list[slotId].Name = newName
	saveWorldList(player.UserId, list)

	local data = getWorldData(player.UserId, slotId)
	if data then
		data.Name = newName
		saveWorldData(player.UserId, slotId, data)
	end

	return { Success = true }
end

UpdateSettings.OnServerInvoke = function(player, graphics, showDebugUI)
	local settings = {
		Graphics = math.clamp(tonumber(graphics) or 2, 1, 3),
		ShowDebugUI = showDebugUI ~= false,
	}
	savePlayerSettings(player.UserId, settings)
	applySettingsAttributes(player)
	return { Success = true }
end

UpdateHostSettings.OnServerInvoke = function(player, enabled, serverName, password)
	local host = {
		Enabled = enabled == true,
		ServerName = tostring(serverName or DEFAULT_HOST_SETTINGS.ServerName),
		Password = tostring(password or ""),
	}

	if host.ServerName == "" then
		host.ServerName = DEFAULT_HOST_SETTINGS.ServerName
	end

	saveHostSettings(player.UserId, host)

	if MCRE.Runtime.IsWorldServer and MCRE.Runtime.OwnerUserId == player.UserId then
		MCRE.Runtime.HostSettings = host
		if host.Enabled then
			beginHostedState(player.UserId)
		else
			removeHostedState(player.UserId)
		end
	end

	return {
		Success = true,
		Host = host,
	}
end

HostCurrentWorld.OnServerInvoke = function(player)
	if not MCRE.Runtime.IsWorldServer then
		return { Success = false, Message = "Not in world server" }
	end

	if MCRE.Runtime.OwnerUserId ~= player.UserId then
		return { Success = false, Message = "Only owner can host" }
	end

	local host = getHostSettings(player.UserId)
	MCRE.Runtime.HostSettings = host

	if host.Enabled then
		beginHostedState(player.UserId)
		return { Success = true }
	end

	return { Success = false, Message = "Hosting disabled in settings" }
end

RequestServerList.OnServerInvoke = function(player)
	local list = getHostedList(player.UserId)
	table.sort(list, function(a, b)
		return tostring(a.ServerName) < tostring(b.ServerName)
	end)

	return {
		Success = true,
		Servers = list,
	}
end

JoinHostedServer.OnServerInvoke = function(player, ownerUserId, password)
	if RunService:IsStudio() then
		return { Success = false, Message = "Studio join disabled" }
	end

	ownerUserId = tonumber(ownerUserId)
	password = tostring(password or "")

	if not ownerUserId then
		return { Success = false, Message = "Invalid owner" }
	end

	local payload = getHostedInfo(ownerUserId)
	if type(payload) ~= "table" then
		return { Success = false, Message = "Server not found" }
	end

	if tostring(payload.Password or "") ~= "" and tostring(payload.Password or "") ~= password then
		return { Success = false, Message = "Wrong password" }
	end

	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = payload.ReservedAccessCode
	options:SetTeleportData({
		Mode = "JOIN_HOSTED_WORLD",
		OwnerUserId = payload.OwnerUserId,
		SlotId = payload.SlotId,
		ReservedAccessCode = payload.ReservedAccessCode,
		PrivateServerId = payload.PrivateServerId,
	})

	local ok, err = pcall(function()
		TeleportService:TeleportAsync(PLACE_ID, { player }, options)
	end)

	if ok then
		return { Success = true }
	end

	return { Success = false, Message = tostring(err) }
end

LoadWorld.OnServerInvoke = function(player, slotId)
	slotId = tonumber(slotId)
	if slotId ~= 1 and slotId ~= 2 and slotId ~= 3 then
		return { Success = false, Message = "Invalid slot" }
	end

	local list = getWorldList(player.UserId)
	if not list[slotId] then
		return { Success = false, Message = "World not found" }
	end

	local worldData = getWorldData(player.UserId, slotId)
	if not worldData then
		return { Success = false, Message = "World data not found" }
	end

	if RunService:IsStudio() then
		return startStudioWorld(player, slotId, worldData)
	end

	local accessCode, privateServerId = TeleportService:ReserveServer(PLACE_ID)
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode
	options:SetTeleportData({
		Mode = "WORLD_SERVER",
		OwnerUserId = player.UserId,
		SlotId = slotId,
		ReservedAccessCode = accessCode,
		PrivateServerId = privateServerId,
	})

	local ok, err = pcall(function()
		TeleportService:TeleportAsync(PLACE_ID, { player }, options)
	end)

	if ok then
		return { Success = true }
	end

	return { Success = false, Message = tostring(err) }
end

SaveAndQuitWorld.OnServerInvoke = function(player)
	if RunService:IsStudio() and MCRE.Runtime.IsWorldServer and MCRE.Runtime.OwnerUserId == player.UserId then
		saveRuntimeWorld()
		removeHostedState(player.UserId)

		if MCRE.ClearWorld then
			MCRE.ClearWorld()
		end

		MCRE.Runtime.IsWorldServer = false
		MCRE.Runtime.WorldLoaded = false
		MCRE.Runtime.OwnerUserId = nil
		MCRE.Runtime.SlotId = nil
		MCRE.Runtime.WorldData = nil
		MCRE.Runtime.ReservedAccessCode = nil
		MCRE.Runtime.PrivateServerId = nil
		MCRE.Runtime.HostSettings = nil

		setLobbyState(player)
		return { Success = true }
	end

	if not MCRE.Runtime.IsWorldServer then
		setLobbyState(player)
		return { Success = true }
	end

	saveRuntimeWorld()

	if MCRE.Runtime.OwnerUserId == player.UserId then
		removeHostedState(player.UserId)
	end

	local ok, err = pcall(function()
		TeleportService:TeleportAsync(PLACE_ID, { player })
	end)

	if ok then
		return { Success = true }
	end

	return { Success = false, Message = tostring(err) }
end

Players.PlayerAdded:Connect(function(player)
	applySettingsAttributes(player)
	player:SetAttribute("Paused", false)
	player:SetAttribute("InventoryOpen", false)
	player:SetAttribute("GameVersion", MCRE.Version)

	player.CharacterAdded:Connect(function(character)
		watchWorldCharacter(player, character)
	end)

	player.Chatted:Connect(function(message)
		local text = tostring(message or "")
		if string.lower(string.sub(text, 1, 5)) == "/mcre" then
			runMcreCommand(player, string.sub(text, 6))
		end
	end)

	local booted = false
	if not MCRE.Runtime.IsWorldServer then
		booted = bootWorldServerFromJoin(player)
	end

	if booted or MCRE.Runtime.IsWorldServer then
		setLoadingState(player, MCRE.Runtime.SlotId)
		player:SetAttribute("WorldLoadProgress", 10)

		if not MCRE.Runtime.WorldLoaded then
			local ok, err = buildRuntimeWorld()
			if ok then
				player:SetAttribute("WorldLoadProgress", 90)
				MCRE.Runtime.WorldLoaded = true
			else
				warn("[MCRE] World generation failed: " .. tostring(err))
				setLobbyState(player)
				return
			end
		end

		if MCRE.Runtime.OwnerUserId == player.UserId and MCRE.Runtime.HostSettings and MCRE.Runtime.HostSettings.Enabled then
			beginHostedState(player.UserId)
		end

		spawnWorldCharacter(player)
		setLoadedState(player, MCRE.Runtime.SlotId)
	else
		setLobbyState(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	respawnScheduled[player] = nil

	if MCRE.Runtime.IsWorldServer and MCRE.Runtime.OwnerUserId == player.UserId then
		saveRuntimeWorld()
		removeHostedState(player.UserId)
	end
end)

game:BindToClose(function()
	if MCRE.Runtime.IsWorldServer and MCRE.Runtime.OwnerUserId then
		saveRuntimeWorld()
		removeHostedState(MCRE.Runtime.OwnerUserId)
	end
end)

task.spawn(function()
	while true do
		task.wait(30)
		if MCRE.Runtime.IsWorldServer and MCRE.Runtime.OwnerUserId and MCRE.Runtime.HostSettings and MCRE.Runtime.HostSettings.Enabled then
			beginHostedState(MCRE.Runtime.OwnerUserId)
		end
	end
end)
