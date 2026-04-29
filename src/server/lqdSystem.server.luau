local ServerStorage = game:GetService("ServerStorage")

_G.MCRE = _G.MCRE or {}
local MCRE = _G.MCRE

local blocks = ServerStorage:WaitForChild("blcStorage")

local blcGrass = blocks:WaitForChild("GrassBlock")
local blcDirt = blocks:WaitForChild("DirtBlock")
local blcStone = blocks:WaitForChild("StoneBlock")
local blcCobblestone = blocks:WaitForChild("CobblestoneBlock")
local blcLog = blocks:WaitForChild("LogBlock")
local blcLeaves = blocks:WaitForChild("LeavesBlock")
local blcSand = blocks:WaitForChild("SandBlock")
local blcGravel = blocks:WaitForChild("GravelBlock") 
local blcWater = blocks:WaitForChild("WaterBlock")
local blcLava = blocks:WaitForChild("LavaBlock")

local BLOCK_SIZE = blcGrass.Size.X
local WORLD_HEIGHT = 96
local DEFAULT_WATER_LEVEL = 18

local BLOCK_TEMPLATES = {
	blcGrass = blcGrass,
	blcDirt = blcDirt,
	blcStone = blcStone,
	blcCobblestone = blcCobblestone,
	blcLog = blcLog,
	blcLeaves = blcLeaves,
	blcSand = blcSand,
	blcGravel = blcGravel,
	blcWater = blcWater,
	blcLava = blcLava,
}

local LIQUID_BLOCKS = {
	blcWater = true,
	blcLava = true,
}

local function snapSeed(seedText)
	seedText = tostring(seedText or "")
	if seedText == "" then
		seedText = "default"
	end

	local hash = 0
	for i = 1, #seedText do
		hash = (hash * 131 + string.byte(seedText, i)) % 2147483647
	end
	if hash == 0 then
		hash = 1337
	end
	return hash
end

local function blockPos(x, y, z)
	return Vector3.new(x * BLOCK_SIZE, y * BLOCK_SIZE, z * BLOCK_SIZE)
end

local function gridKey(x, y, z)
	return tostring(x) .. "|" .. tostring(y) .. "|" .. tostring(z)
end

local function parseGridKey(key)
	local x, y, z = string.match(tostring(key), "^(-?%d+)|(-?%d+)|(-?%d+)$")
	if not x then
		return nil
	end
	return tonumber(x), tonumber(y), tonumber(z)
end

local function positionToGrid(position)
	return
		math.floor(position.X / BLOCK_SIZE + 0.5),
		math.floor(position.Y / BLOCK_SIZE + 0.5),
		math.floor(position.Z / BLOCK_SIZE + 0.5)
end

local function registerBlock(part, x, y, z)
	if not part then
		return
	end

	if not x or not y or not z then
		local gx, gy, gz = positionToGrid(part.Position)
		x = x or gx
		y = y or gy
		z = z or gz
	end

	local key = gridKey(x, y, z)
	MCRE.BlockIndex = MCRE.BlockIndex or {}
	MCRE.BlockIndex[key] = part
	part:SetAttribute("GridKey", key)
end

local function unregisterBlockAt(x, y, z)
	if MCRE.BlockIndex then
		MCRE.BlockIndex[gridKey(x, y, z)] = nil
	end
end

local function clearWorld()
	local old = workspace:FindFirstChild("WorldBlocks")
	if old then
		old:Destroy()
	end

	MCRE.WorldFolder = nil
	MCRE.BlockIndex = {}
	MCRE.HeightAt = nil
	MCRE.GetBlockAtGrid = nil
	MCRE.GetBlockAtPosition = nil
	MCRE.GetLogicalBlockName = nil
	MCRE.HasSolidBlockAtGrid = nil
	MCRE.CreateWorldBlock = nil
	MCRE.RegisterBlock = nil
	MCRE.UnregisterBlockAtGrid = nil
	MCRE.RevealBlockAt = nil
	MCRE.RevealNeighborsAround = nil
end

local function createWorldFolder()
	local folder = Instance.new("Folder")
	folder.Name = "WorldBlocks"
	folder.Parent = workspace
	return folder
end

local function createBlock(template, name, x, y, z, parent)
	if MCRE.BlockIndex and MCRE.BlockIndex[gridKey(x, y, z)] then
		return MCRE.BlockIndex[gridKey(x, y, z)]
	end

	local part = template:Clone()
	part.Name = name
	part.Anchored = true
	part.Position = blockPos(x, y, z)
	part.Parent = parent
	registerBlock(part, x, y, z)
	return part
end

local function setLiquidState(part, liquidName, isSource, staticLiquid, flowDistance, sourceY)
	part.CanCollide = false
	part:SetAttribute("LiquidType", liquidName)
	part:SetAttribute("IsLiquidSource", isSource == true)
	part:SetAttribute("IsStaticLiquid", staticLiquid == true)
	part:SetAttribute("FlowDistance", flowDistance or 0)
	part:SetAttribute("SourceY", sourceY or 0)
end

local function getSeedOffsets(seed)
	return {
		a = seed * 0.00173,
		b = seed * 0.00219,
		c = seed * 0.00311,
		d = seed * 0.00407,
		e = seed * 0.00521,
		f = seed * 0.00613,
		g = seed * 0.00731,
		h = seed * 0.00803,
	}
end

local function makeHeightFunction(worldData)
	local seed = snapSeed(worldData.Seed)
	local o = getSeedOffsets(seed)
	local waterLevel = DEFAULT_WATER_LEVEL

	local terrainCache = {}
	local isSuperflat = tostring(worldData.WorldType or "Normal") == "Superflat"

	local function riverField(x, z)
		local n1 = math.noise((x + o.a * 100) * 0.007, (z + o.b * 100) * 0.007)
		local n2 = math.noise((x + o.c * 100) * 0.014, (z + o.d * 100) * 0.014)
		return math.abs(n1 * 0.78 + n2 * 0.22)
	end

	local function lakeField(x, z)
		return math.noise((x + o.e * 100) * 0.018, (z + o.f * 100) * 0.018)
	end

	local function mountainField(x, z)
		local mass = math.max(0, math.noise((x + o.g) * 0.008, (z + o.h) * 0.008))
		local peaks = math.max(0, math.noise((x + o.a * 13) * 0.018, (z + o.b * 13) * 0.018))
		return math.clamp(mass * 0.85 + peaks * 0.45, 0, 1.35)
	end

	local function cliffField(x, z)
		local ridge = 1 - math.abs(math.noise((x + o.c * 9) * 0.016, (z + o.d * 9) * 0.016))
		local sharp = math.max(0, math.noise((x + o.e * 7) * 0.038, (z + o.f * 7) * 0.038))
		return math.clamp((ridge ^ 2.6) * (0.55 + sharp), 0, 1.25)
	end

	local function lavaLakeField(x, z)
		local n1 = math.noise((x + o.g * 120) * 0.022, (z + o.h * 120) * 0.022)
		local n2 = math.noise((x + o.a * 70) * 0.05, (z + o.b * 70) * 0.05) * 0.5
		return n1 * 0.75 + n2 * 0.25
	end

	local function getTerrain(x, z)
		local key = tostring(x) .. "|" .. tostring(z)
		if terrainCache[key] then
			return terrainCache[key]
		end

		if isSuperflat then
			local flat = {
				Height = 8,
				IsRiver = false,
				IsLake = false,
				IsMountain = false,
				IsCliff = false,
				IsLavaLake = false,
				RiverSurfaceY = waterLevel,
				LavaSurfaceY = nil,
			}
			terrainCache[key] = flat
			return flat
		end

		local base = 18
		local hills = math.noise((x + o.a) * 0.026, (z + o.b) * 0.026) * 7
		local detail = math.noise((x + o.c) * 0.085, (z + o.d) * 0.085) * 3.2
		local mountainMask = mountainField(x, z)
		local mountainRise = (mountainMask ^ 2) * 30
		local cliffMask = cliffField(x, z)
		local cliffs = cliffMask * (4 + mountainMask * 12)
		local river = riverField(x, z)
		local riverBand = math.clamp((0.085 - river) / 0.085, 0, 1)
		local riverCut = (riverBand ^ 1.4) * (8 + mountainMask * 6)
		local lake = lakeField(x, z)
		local lakeMask = math.clamp((lake - 0.6) / 0.4, 0, 1)
		local lakeCut = (lakeMask ^ 1.8) * 10
		local lavaLakeNoise = lavaLakeField(x, z)
		local lavaLakeMask = math.clamp((lavaLakeNoise - 0.66) / 0.34, 0, 1)
		local lavaEligible = mountainMask > 0.42 and riverBand < 0.22
		local lavaLakeCut = 0

		if lavaEligible and lavaLakeMask > 0 then
			lavaLakeCut = (lavaLakeMask ^ 1.7) * (6 + mountainMask * 7)
		end

		local h = base + hills + detail + mountainRise + cliffs - riverCut - lakeCut - lavaLakeCut
		h = math.floor(math.clamp(h, 4, WORLD_HEIGHT))

		local riverSurfaceY = math.floor(math.clamp(waterLevel + mountainMask * 4, waterLevel, waterLevel + 4))
		local lavaSurfaceY = nil

		if lavaEligible and lavaLakeMask > 0.3 and h >= waterLevel + 8 then
			lavaSurfaceY = math.floor(math.clamp(h + 1 + lavaLakeMask * 3, waterLevel + 8, WORLD_HEIGHT - 2))
		end

		local info = {
			Height = h,
			IsRiver = riverBand > 0.42,
			IsLake = lakeMask > 0.38 and h <= waterLevel + 3,
			IsMountain = mountainMask > 0.38 or h >= waterLevel + 18,
			IsCliff = cliffMask > 0.45,
			IsLavaLake = lavaSurfaceY ~= nil,
			RiverSurfaceY = riverSurfaceY,
			LavaSurfaceY = lavaSurfaceY,
		}

		terrainCache[key] = info
		return info
	end

	local function heightAt(x, z)
		return getTerrain(x, z).Height
	end

	local function isRiver(x, z)
		local info = getTerrain(x, z)
		return info.IsRiver and info.Height <= info.RiverSurfaceY
	end

	local function isLake(x, z)
		return getTerrain(x, z).IsLake
	end

	local function getShoreDistance(x, z)
		local minD = 999
		for dx = -3, 3 do
			for dz = -3, 3 do
				if isRiver(x + dx, z + dz) or isLake(x + dx, z + dz) then
					local d = math.abs(dx) + math.abs(dz)
					if d < minD then
						minD = d
					end
				end
			end
		end
		return minD
	end

	return {
		WaterLevel = waterLevel,
		HeightAt = heightAt,
		GetTerrain = getTerrain,
		IsRiver = isRiver,
		IsLake = isLake,
		IsMountain = function(x, z)
			return getTerrain(x, z).IsMountain
		end,
		IsCliff = function(x, z)
			return getTerrain(x, z).IsCliff
		end,
		IsLavaLake = function(x, z)
			return getTerrain(x, z).IsLavaLake
		end,
		GetWaterSurfaceY = function(x, z)
			local info = getTerrain(x, z)
			if info.IsLavaLake then
				return nil
			end
			if info.IsLake then
				return waterLevel
			end
			if info.IsRiver and info.Height <= info.RiverSurfaceY then
				return info.RiverSurfaceY
			end
			if info.Height < waterLevel then
				return waterLevel
			end
			return nil
		end,
		GetLavaSurfaceY = function(x, z)
			return getTerrain(x, z).LavaSurfaceY
		end,
		GetShoreDistance = getShoreDistance,
		Seed = seed,
	}
end

local function getSteepness(heightFn, x, z)
	local h = heightFn.HeightAt(x, z)
	local d1 = math.abs(h - heightFn.HeightAt(x + 1, z))
	local d2 = math.abs(h - heightFn.HeightAt(x - 1, z))
	local d3 = math.abs(h - heightFn.HeightAt(x, z + 1))
	local d4 = math.abs(h - heightFn.HeightAt(x, z - 1))
	return math.max(d1, d2, d3, d4)
end

local function shouldCarveCave(seed, x, y, z, surfaceHeight)
	if y <= 2 or y >= surfaceHeight - 2 then
		return false
	end

	local s = seed * 0.001
	local cave = math.noise((x + s * 53) * 0.07, (y + s * 29) * 0.09, (z + s * 71) * 0.07)
	local tunnel = math.noise((x + s * 113) * 0.14, (y + s * 97) * 0.14, (z + s * 131) * 0.14)

	return cave > 0.57 or (cave > 0.47 and tunnel < -0.15)
end

local function chooseTopMaterial(heightFn, x, z, h)
	local shoreDistance = heightFn.GetShoreDistance(x, z)
	local steepness = getSteepness(heightFn, x, z)

	if heightFn.IsLavaLake(x, z) then
		return "Stone"
	end

	if heightFn.IsRiver(x, z) or heightFn.IsLake(x, z) or h <= heightFn.WaterLevel then
		if math.noise((x + 9) * 0.15, (z + 9) * 0.15) > 0 then
			return "Sand"
		else
			return "Gravel"
		end
	end

	if shoreDistance <= 1 then
		if math.noise((x + 19) * 0.2, (z + 19) * 0.2) > 0 then
			return "Sand"
		else
			return "Gravel"
		end
	end

	if heightFn.IsCliff(x, z) or (steepness >= 6 and h > heightFn.WaterLevel + 8) then
		return "Stone"
	end

	return "Grass"
end

local function materialToBlockName(material)
	if material == "Grass" then
		return "blcGrass"
	elseif material == "Sand" then
		return "blcSand"
	elseif material == "Gravel" then
		return "blcGravel"
	end
	return "blcStone"
end

local function getGeneratedBlockName(heightFn, x, y, z)
	if y < 0 then
		return nil
	end

	local surfaceY = heightFn.HeightAt(x, z)
	if y > surfaceY then
		return nil
	end

	if shouldCarveCave(heightFn.Seed, x, y, z, surfaceY) then
		return nil
	end

	local top = chooseTopMaterial(heightFn, x, z, surfaceY)
	if y == surfaceY then
		return materialToBlockName(top)
	elseif y >= surfaceY - 3 then
		if top == "Stone" then
			return "blcStone"
		end
		return "blcDirt"
	end

	return "blcStone"
end

local function getWorldBlockName(heightFn, changes, x, y, z, width, depth)
	local key = gridKey(x, y, z)
	local changed = changes[key]

	if changed == false then
		return nil
	elseif type(changed) == "string" and BLOCK_TEMPLATES[changed] then
		return changed
	end

	if width and (x < 0 or x >= width) then
		return nil
	end
	if depth and (z < 0 or z >= depth) then
		return nil
	end

	return getGeneratedBlockName(heightFn, x, y, z)
end

local function isExposedBlock(heightFn, changes, x, y, z, width, depth)
	if not getWorldBlockName(heightFn, changes, x, y, z, width, depth) then
		return false
	end

	local directions = {
		{ 1, 0, 0 },
		{ -1, 0, 0 },
		{ 0, 1, 0 },
		{ 0, -1, 0 },
		{ 0, 0, 1 },
		{ 0, 0, -1 },
	}

	for _, d in ipairs(directions) do
		local neighbor = getWorldBlockName(heightFn, changes, x + d[1], y + d[2], z + d[3], width, depth)
		if not neighbor or LIQUID_BLOCKS[neighbor] then
			return true
		end
	end

	return false
end

local function createNamedBlock(folder, blockName, x, y, z)
	local template = BLOCK_TEMPLATES[blockName]
	if not template then
		return nil
	end

	local part = createBlock(template, blockName, x, y, z, folder)
	if LIQUID_BLOCKS[blockName] then
		part.CanCollide = false
	end
	return part
end

local function maybePlaceTree(folder, heightFn, x, z, surfaceY)
	if chooseTopMaterial(heightFn, x, z, surfaceY) ~= "Grass" then
		return
	end

	if surfaceY <= heightFn.WaterLevel + 2 then
		return
	end

	if heightFn.IsMountain(x, z) or getSteepness(heightFn, x, z) >= 4 then
		return
	end

	local n = math.noise((x + heightFn.Seed * 0.001) * 0.11, (z + heightFn.Seed * 0.001) * 0.11)
	if n < 0.58 then
		return
	end

	local trunkHeight = 4 + math.floor(math.abs(math.noise((x + 1000) * 0.21, (z + 1000) * 0.21)) * 2)

	for i = 1, trunkHeight do
		createBlock(blcLog, "blcLog", x, surfaceY + i, z, folder)
	end

	local crownY = surfaceY + trunkHeight

	for lx = -2, 2 do
		for lz = -2, 2 do
			for ly = 0, 2 do
				if math.abs(lx) + math.abs(lz) + ly <= 4 then
					if not (lx == 0 and lz == 0 and ly <= 1) then
						createBlock(blcLeaves, "blcLeaves", x + lx, crownY + ly, z + lz, folder)
					end
				end
			end
		end
	end

	createBlock(blcLeaves, "blcLeaves", x, crownY + 3, z, folder)
end

local function maybePlaceLavaSource(folder, heightFn, x, z, surfaceY)
	if heightFn.IsLavaLake(x, z) then
		return
	end

	if surfaceY < heightFn.WaterLevel + 12 then
		return
	end

	if getSteepness(heightFn, x, z) < 7 then
		return
	end

	local n = math.noise((x + heightFn.Seed * 0.002) * 0.045, (z + heightFn.Seed * 0.002) * 0.045)
	if n < 0.82 then
		return
	end

	local part = createBlock(blcLava, "blcLava", x, surfaceY + 1, z, folder)
	setLiquidState(part, "blcLava", true, false, 0, surfaceY + 1)
end

local function buildWorld(worldData)
	clearWorld()

	local folder = createWorldFolder()
	local width = tonumber(worldData.Width) or 64
	local depth = tonumber(worldData.Depth) or 64
	local changes = worldData.Changes or {}

	local heightFn = makeHeightFunction(worldData)

	MCRE.WorldFolder = folder
	MCRE.BlockIndex = {}
	MCRE.HeightAt = function(x, z)
		return heightFn.HeightAt(x, z)
	end
	MCRE.WaterLevel = heightFn.WaterLevel
	MCRE.BlockSize = BLOCK_SIZE
	MCRE.WorldWidth = width
	MCRE.WorldDepth = depth

	MCRE.RegisterBlock = function(part)
		if part and part:IsA("BasePart") then
			local x, y, z = positionToGrid(part.Position)
			registerBlock(part, x, y, z)
		end
	end

	MCRE.UnregisterBlockAtGrid = function(x, y, z)
		unregisterBlockAt(x, y, z)
	end

	MCRE.GetBlockAtGrid = function(x, y, z)
		local part = MCRE.BlockIndex and MCRE.BlockIndex[gridKey(x, y, z)] or nil
		if part and part.Parent then
			return part
		end
		unregisterBlockAt(x, y, z)
		return nil
	end

	MCRE.GetBlockAtPosition = function(position)
		local x, y, z = positionToGrid(position)
		return MCRE.GetBlockAtGrid(x, y, z)
	end

	MCRE.GetLogicalBlockName = function(x, y, z)
		local part = MCRE.GetBlockAtGrid(x, y, z)
		if part then
			return part.Name
		end
		return getWorldBlockName(heightFn, changes, x, y, z, width, depth)
	end

	MCRE.HasSolidBlockAtGrid = function(x, y, z)
		local name = MCRE.GetLogicalBlockName(x, y, z)
		return name ~= nil and not LIQUID_BLOCKS[name]
	end

	MCRE.CreateWorldBlock = function(blockName, x, y, z, attributes)
		local part = createNamedBlock(folder, blockName, x, y, z)
		if part and attributes then
			for name, value in pairs(attributes) do
				part:SetAttribute(name, value)
			end
		end
		return part
	end

	MCRE.RevealBlockAt = function(x, y, z)
		if MCRE.GetBlockAtGrid(x, y, z) then
			return nil
		end

		local blockName = getWorldBlockName(heightFn, changes, x, y, z, width, depth)
		if not blockName or LIQUID_BLOCKS[blockName] then
			return nil
		end

		return createNamedBlock(folder, blockName, x, y, z)
	end

	MCRE.RevealNeighborsAround = function(x, y, z)
		local directions = {
			{ 1, 0, 0 },
			{ -1, 0, 0 },
			{ 0, 1, 0 },
			{ 0, -1, 0 },
			{ 0, 0, 1 },
			{ 0, 0, -1 },
		}

		for _, d in ipairs(directions) do
			MCRE.RevealBlockAt(x + d[1], y + d[2], z + d[3])
		end
	end

	local placed = 0

	for x = 0, width - 1 do
		for z = 0, depth - 1 do
			local surfaceY = heightFn.HeightAt(x, z)

			for y = 0, surfaceY do
				if isExposedBlock(heightFn, changes, x, y, z, width, depth) then
					createNamedBlock(folder, getWorldBlockName(heightFn, changes, x, y, z, width, depth), x, y, z)
				end

				placed += 1
				if placed % 1800 == 0 then
					task.wait()
				end
			end

			local lavaSurfaceY = heightFn.GetLavaSurfaceY(x, z)
			if lavaSurfaceY and surfaceY < lavaSurfaceY then
				for y = surfaceY + 1, lavaSurfaceY do
					local key = gridKey(x, y, z)
					if changes[key] ~= false then
						local part = createBlock(blcLava, "blcLava", x, y, z, folder)
						setLiquidState(part, "blcLava", false, true, 0, lavaSurfaceY)
					end
				end
			else
				local waterSurfaceY = heightFn.GetWaterSurfaceY(x, z)
				if waterSurfaceY and surfaceY < waterSurfaceY then
					for y = surfaceY + 1, waterSurfaceY do
						local key = gridKey(x, y, z)
						if changes[key] ~= false then
							local part = createBlock(blcWater, "blcWater", x, y, z, folder)
							setLiquidState(part, "blcWater", false, true, 0, waterSurfaceY)
						end
					end
				end
			end
		end
	end

	for key, blockName in pairs(changes) do
		if type(blockName) == "string" and BLOCK_TEMPLATES[blockName] then
			local x, y, z = parseGridKey(key)
			if x and not MCRE.GetBlockAtGrid(x, y, z) then
				local part = createNamedBlock(folder, blockName, x, y, z)
				if part and LIQUID_BLOCKS[blockName] then
					setLiquidState(part, blockName, true, false, 0, y)
				end
			end
		end
	end

	for x = 0, width - 1 do
		for z = 0, depth - 1 do
			local y = heightFn.HeightAt(x, z)
			maybePlaceTree(folder, heightFn, x, z, y)
			maybePlaceLavaSource(folder, heightFn, x, z, y)
		end
	end
end

MCRE.ClearWorld = clearWorld
MCRE.BuildWorld = buildWorld
MCRE.GetBlockSize = function()
	return BLOCK_SIZE
end
