local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

Players.CharacterAutoLoads = false

_G.MCRE = _G.MCRE or {}
local MCRE = _G.MCRE

MCRE.Version = "Alpha 0.0.8a"
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

local blocksFolder = ServerStorage:WaitForChild("blcStorage")
local grassBlock = blocksFolder:WaitForChild("blcGrass")

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
		return "Medium", 128, 128
	elseif sizeName == "Large" then
		return "Large", 256, 256
	end
	return "Small", 64, 64
end

local function normalizeWorldType(worldType)
	worldType = tostring(worldType or "Normal")
	if worldType == "Superflat" then
		return "Superflat"
	end
	return "Normal"
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

	MCRE.BuildWorld(runtime.WorldData)
	runtime.WorldLoaded = true
	return true
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
	player:LoadCharacter()
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

	local booted = false
	if not MCRE.Runtime.IsWorldServer then
		booted = bootWorldServerFromJoin(player)
	end

	if booted or MCRE.Runtime.IsWorldServer then
		setLoadingState(player, MCRE.Runtime.SlotId)
		player:SetAttribute("WorldLoadProgress", 10)

		if not MCRE.Runtime.WorldLoaded then
			local ok = buildRuntimeWorld()
			if ok then
				player:SetAttribute("WorldLoadProgress", 90)
				MCRE.Runtime.WorldLoaded = true
			end
		end

		if MCRE.Runtime.OwnerUserId == player.UserId and MCRE.Runtime.HostSettings and MCRE.Runtime.HostSettings.Enabled then
			beginHostedState(player.UserId)
		end

		player:LoadCharacter()
		setLoadedState(player, MCRE.Runtime.SlotId)
	else
		setLobbyState(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
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
