local ServerStorage = game:GetService("ServerStorage")

_G.MCRE = _G.MCRE or {}
local MCRE = _G.MCRE

local blocks = ServerStorage:WaitForChild("blcStorage")
local blcGrass = blocks:WaitForChild("GrassBlock")
local blcCobblestone = blocks:WaitForChild("CobblestoneBlock") 
local blcWater = blocks:WaitForChild("WaterBlock")
local blcLava = blocks:WaitForChild("LavaBlock")
 
local BLOCK_SIZE = blcGrass.Size.X

local LIQUIDS = {
	blcWater = {
		MaxSpread = 12,
		UpdateInterval = 0.35,
		MaxNewPerTick = 8,
	},
	blcLava = {
		MaxSpread = 8,
		UpdateInterval = 0.7,
		MaxNewPerTick = 4,
	},
}

local function gridKey(x, y, z)
	return tostring(x) .. "|" .. tostring(y) .. "|" .. tostring(z)
end

local function positionToGrid(position)
	return
		math.floor(position.X / BLOCK_SIZE + 0.5),
		math.floor(position.Y / BLOCK_SIZE + 0.5),
		math.floor(position.Z / BLOCK_SIZE + 0.5)
end

local function gridToPosition(x, y, z)
	return Vector3.new(x * BLOCK_SIZE, y * BLOCK_SIZE, z * BLOCK_SIZE)
end

local function getWorldFolder()
	return workspace:FindFirstChild("WorldBlocks")
end

local function getAllParts(folder)
	local result = {}
	for _, obj in ipairs(folder:GetDescendants()) do
		if obj:IsA("BasePart") then
			table.insert(result, obj)
		end
	end
	return result
end

local function buildIndex(folder)
	if MCRE.BlockIndex then
		return MCRE.BlockIndex
	end

	local index = {}
	for _, part in ipairs(getAllParts(folder)) do
		local x, y, z = positionToGrid(part.Position)
		index[gridKey(x, y, z)] = part
	end
	return index
end

local function isLiquid(name)
	return LIQUIDS[name] ~= nil
end

local function isSolid(part)
	return part ~= nil and not isLiquid(part.Name)
end

local function getCell(index, x, y, z)
	local key = gridKey(x, y, z)
	local part = index[key]
	if part and part.Parent then
		return part
	end
	index[key] = nil
	return nil
end

local function hasSolidAt(index, x, y, z)
	local part = getCell(index, x, y, z)
	if part then
		return isSolid(part)
	end

	if MCRE.HasSolidBlockAtGrid then
		return MCRE.HasSolidBlockAtGrid(x, y, z)
	end

	return false
end

local function replaceWithCobblestone(folder, index, x, y, z)
	local key = gridKey(x, y, z)
	local old = index[key]
	if old then
		old:Destroy()
		index[key] = nil
	end

	local part = blcCobblestone:Clone()
	part.Name = "blcCobblestone"
	part.Anchored = true
	part.Position = gridToPosition(x, y, z)
	part.Parent = folder
	index[key] = part
	if MCRE.RegisterBlock then
		MCRE.RegisterBlock(part)
	end
end

local function createLiquid(folder, index, liquidName, x, y, z, flowDistance, sourceY, isSource)
	local key = gridKey(x, y, z)
	local existing = getCell(index, x, y, z)

	if existing then
		if existing.Name == liquidName then
			return nil
		end

		if existing.Name == "blcWater" or existing.Name == "blcLava" then
			if existing.Name ~= liquidName then
				replaceWithCobblestone(folder, index, x, y, z)
			end
			return nil
		end

		return nil
	end

	local template = liquidName == "blcWater" and blcWater or blcLava
	local part = template:Clone()
	part.Name = liquidName
	part.Anchored = true
	part.CanCollide = false
	part.Position = gridToPosition(x, y, z)
	part:SetAttribute("LiquidType", liquidName)
	part:SetAttribute("IsLiquidSource", isSource == true)
	part:SetAttribute("IsStaticLiquid", false)
	part:SetAttribute("FlowDistance", flowDistance)
	part:SetAttribute("SourceY", sourceY)
	part.Parent = folder

	index[key] = part
	if MCRE.RegisterBlock then
		MCRE.RegisterBlock(part)
	end
	return part
end

local function cleanupOrphans(folder, liquidName)
	local index = buildIndex(folder)

	local all = {}
	local sources = {}

	for key, part in pairs(index) do
		if part and part.Parent and part.Name == liquidName and part:GetAttribute("IsStaticLiquid") ~= true then
			all[key] = part
			if part:GetAttribute("IsLiquidSource") == true then
				local x, y, z = positionToGrid(part.Position)
				table.insert(sources, { x = x, y = y, z = z, key = key })
			end
		end
	end

	local seen = {}
	local queue = {}
	local head = 1

	for _, src in ipairs(sources) do
		seen[src.key] = true
		table.insert(queue, src)
	end

	local dirs = {
		{ 1, 0, 0 },
		{ -1, 0, 0 },
		{ 0, 1, 0 },
		{ 0, -1, 0 },
		{ 0, 0, 1 },
		{ 0, 0, -1 },
	}

	while head <= #queue do
		local node = queue[head]
		head += 1

		for _, d in ipairs(dirs) do
			local nx = node.x + d[1]
			local ny = node.y + d[2]
			local nz = node.z + d[3]
			local key = gridKey(nx, ny, nz)

			if not seen[key] and all[key] then
				seen[key] = true
				table.insert(queue, { x = nx, y = ny, z = nz, key = key })
			end
		end
	end

	for key, part in pairs(all) do
		if not seen[key] then
			local x, y, z = positionToGrid(part.Position)
			part:Destroy()
			if MCRE.UnregisterBlockAtGrid then
				MCRE.UnregisterBlockAtGrid(x, y, z)
			else
				index[key] = nil
			end
		end
	end
end

local function updateLiquid(liquidName)
	local folder = getWorldFolder()
	if not folder then
		return
	end

	local config = LIQUIDS[liquidName]
	local index = buildIndex(folder)

	local candidates = {}
	for _, part in pairs(index) do
		if part and part.Parent and part.Name == liquidName and part:GetAttribute("IsStaticLiquid") ~= true then
			table.insert(candidates, part)
		end
	end

	table.sort(candidates, function(a, b)
		local ad = a:GetAttribute("FlowDistance") or 0
		local bd = b:GetAttribute("FlowDistance") or 0
		local as = a:GetAttribute("IsLiquidSource") == true
		local bs = b:GetAttribute("IsLiquidSource") == true

		if as ~= bs then
			return as
		end
		return ad < bd
	end)

	local createdCount = 0

	for _, part in ipairs(candidates) do
		if createdCount >= config.MaxNewPerTick then
			break
		end

		if not part.Parent then
			continue
		end

		local x, y, z = positionToGrid(part.Position)
		local flowDistance = part:GetAttribute("FlowDistance") or 0
		local sourceY = part:GetAttribute("SourceY") or y

		local below = getCell(index, x, y - 1, z)

		if y > 0 and not hasSolidAt(index, x, y - 1, z) then
			if below == nil then
				local created = createLiquid(folder, index, liquidName, x, y - 1, z, flowDistance, sourceY, false)
				if created then
					createdCount += 1
				end
			elseif below and below.Name ~= liquidName and isLiquid(below.Name) then
				replaceWithCobblestone(folder, index, x, y - 1, z)
				createdCount += 1
			end
		else
			if flowDistance < config.MaxSpread then
				local dirs = {
					{ 1, 0 },
					{ -1, 0 },
					{ 0, 1 },
					{ 0, -1 },
				}

				for _, d in ipairs(dirs) do
					if createdCount >= config.MaxNewPerTick then
						break
					end

					local nx = x + d[1]
					local nz = z + d[2]
					local targetY = y

					if targetY > sourceY then
						continue
					end

					local side = getCell(index, nx, targetY, nz)
					local under = getCell(index, nx, targetY - 1, nz)

					if side == nil and not hasSolidAt(index, nx, targetY, nz) then
						if hasSolidAt(index, nx, targetY - 1, nz) then
							local created = createLiquid(folder, index, liquidName, nx, targetY, nz, flowDistance + 1, sourceY, false)
							if created then
								createdCount += 1
							end
						elseif under and isLiquid(under.Name) then
							local created = createLiquid(folder, index, liquidName, nx, targetY, nz, flowDistance + 1, sourceY, false)
							if created then
								createdCount += 1
							end
						end
					elseif side and isLiquid(side.Name) and side.Name ~= liquidName then
						replaceWithCobblestone(folder, index, nx, targetY, nz)
						createdCount += 1
					end
				end
			end
		end
	end
end

local timers = {
	blcWater = 0,
	blcLava = 0,
}

local cleanupTimer = 0

task.spawn(function()
	while true do
		task.wait(0.05)

		local now = os.clock()

		for liquidName, config in pairs(LIQUIDS) do
			if now - timers[liquidName] >= config.UpdateInterval then
				updateLiquid(liquidName)
				timers[liquidName] = now
			end
		end

		if now - cleanupTimer >= 2.0 then
			local folder = getWorldFolder()
			if folder then
				cleanupOrphans(folder, "blcWater")
				cleanupOrphans(folder, "blcLava")
			end
			cleanupTimer = now
		end
	end
end)
