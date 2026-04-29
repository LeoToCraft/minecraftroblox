local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

_G.MCRE = _G.MCRE or {}
local MCRE = _G.MCRE

local rmtGame = ReplicatedStorage:WaitForChild("rmtGame")
local BreakBlock = rmtGame:WaitForChild("BreakBlock")
local PlaceBlock = rmtGame:WaitForChild("PlaceBlock")

local blocksFolder = ServerStorage:WaitForChild("blcStorage")

local BLOCKS = {
	blcGrass = blocksFolder:WaitForChild("GrassBlock"),
	blcDirt = blocksFolder:WaitForChild("DirtBlock"),
	blcStone = blocksFolder:WaitForChild("StoneBlock"),
	blcCobblestone = blocksFolder:WaitForChild("CobblestoneBlock"),
	blcLog = blocksFolder:WaitForChild("LogBlock"),
	blcLeaves = blocksFolder:WaitForChild("LeavesBlock"),
	blcSand = blocksFolder:WaitForChild("SandBlock"),
	blcGravel = blocksFolder:WaitForChild("GravelBlock"),
	blcWater = blocksFolder:WaitForChild("WaterBlock"),
	blcLava = blocksFolder:WaitForChild("LavaBlock"),
}

local BLOCK_SIZE = BLOCKS.blcGrass.Size.X
local MAX_DISTANCE = 20

local FALLING = {
	blcSand = true,
	blcGravel = true,
}

local LIQUID = {
	blcWater = true,
	blcLava = true,
}

local function snapToGrid(position)
	return Vector3.new(
		math.floor(position.X / BLOCK_SIZE + 0.5) * BLOCK_SIZE,
		math.floor(position.Y / BLOCK_SIZE + 0.5) * BLOCK_SIZE,
		math.floor(position.Z / BLOCK_SIZE + 0.5) * BLOCK_SIZE
	)
end

local function toGrid(position)
	return
		math.floor(position.X / BLOCK_SIZE + 0.5),
		math.floor(position.Y / BLOCK_SIZE + 0.5),
		math.floor(position.Z / BLOCK_SIZE + 0.5)
end

local function gridKey(x, y, z)
	return tostring(x) .. "|" .. tostring(y) .. "|" .. tostring(z)
end

local function worldFolder()
	return workspace:FindFirstChild("WorldBlocks")
end

local function fallbackAllParts()
	local folder = worldFolder()
	if not folder then
		return {}
	end

	local result = {}
	for _, obj in ipairs(folder:GetDescendants()) do
		if obj:IsA("BasePart") then
			table.insert(result, obj)
		end
	end
	return result
end

local function getPartAt(position)
	if MCRE.GetBlockAtPosition then
		return MCRE.GetBlockAtPosition(position)
	end

	for _, part in ipairs(fallbackAllParts()) do
		if (part.Position - position).Magnitude < 0.1 then
			return part
		end
	end
	return nil
end

local function hasSolidBlockAt(x, y, z)
	if MCRE.HasSolidBlockAtGrid then
		return MCRE.HasSolidBlockAtGrid(x, y, z)
	end

	local part = getPartAt(Vector3.new(x * BLOCK_SIZE, y * BLOCK_SIZE, z * BLOCK_SIZE))
	return part ~= nil and not LIQUID[part.Name]
end

local function isManagedBlock(part)
	if not part or not part:IsA("BasePart") then
		return false
	end
	return BLOCKS[part.Name] ~= nil and part:IsDescendantOf(worldFolder())
end

local function characterIntersects(character, position)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { character }

	local found = workspace:GetPartBoundsInBox(
		CFrame.new(position),
		Vector3.new(BLOCK_SIZE * 0.95, BLOCK_SIZE * 0.95, BLOCK_SIZE * 0.95),
		overlapParams
	)

	for _, part in ipairs(found) do
		if part:IsDescendantOf(character) then
			return true
		end
	end
	return false
end

local fallingQueue = {}
local fallingQueued = {}
local fallingWorkerRunning = false
local MAX_FALLS_PER_STEP = 12

local function settleFallingBlock(runtimeData, part)
	if not part or not part.Parent or not FALLING[part.Name] then
		return
	end

	local px, py, pz = toGrid(part.Position)
	local finalY = py

	while finalY > 0 do
		if hasSolidBlockAt(px, finalY - 1, pz) then
			break
		end
		finalY -= 1
	end

	if finalY == py then
		return
	end

	if runtimeData and runtimeData.Changes then
		runtimeData.Changes[gridKey(px, py, pz)] = false
		runtimeData.Changes[gridKey(px, finalY, pz)] = part.Name
	end

	if MCRE.UnregisterBlockAtGrid then
		MCRE.UnregisterBlockAtGrid(px, py, pz)
	end

	part.Anchored = false
	part.AssemblyLinearVelocity = Vector3.new(0, -35, 0)

	task.delay(0.08, function()
		if not part or not part.Parent then
			return
		end

		part.AssemblyLinearVelocity = Vector3.zero
		part.Position = Vector3.new(px * BLOCK_SIZE, finalY * BLOCK_SIZE, pz * BLOCK_SIZE)
		part.Anchored = true
		if MCRE.RegisterBlock then
			MCRE.RegisterBlock(part)
		end
	end)

	local above = getPartAt(Vector3.new(px * BLOCK_SIZE, (py + 1) * BLOCK_SIZE, pz * BLOCK_SIZE))
	if above and FALLING[above.Name] and not fallingQueued[above] then
		fallingQueued[above] = true
		table.insert(fallingQueue, { RuntimeData = runtimeData, Part = above })
	end
end

local function runFallingWorker()
	if fallingWorkerRunning then
		return
	end

	fallingWorkerRunning = true
	task.spawn(function()
		while #fallingQueue > 0 do
			local processed = 0

			while processed < MAX_FALLS_PER_STEP and #fallingQueue > 0 do
				local item = table.remove(fallingQueue, 1)
				local part = item.Part
				fallingQueued[part] = nil
				settleFallingBlock(item.RuntimeData, part)
				processed += 1
			end

			task.wait()
		end

		fallingWorkerRunning = false
	end)
end

local function enqueueFallingBlock(runtimeData, part)
	if not part or not part.Parent or not FALLING[part.Name] or fallingQueued[part] then
		return
	end

	fallingQueued[part] = true
	table.insert(fallingQueue, { RuntimeData = runtimeData, Part = part })
	runFallingWorker()
end

local function settleAbove(runtimeData, position)
	local above = getPartAt(position + Vector3.new(0, BLOCK_SIZE, 0))
	enqueueFallingBlock(runtimeData, above)
end

BreakBlock.OnServerEvent:Connect(function(player, target)
	if player:GetAttribute("WorldLoaded") ~= true then
		return
	end

	if not isManagedBlock(target) then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	if (hrp.Position - target.Position).Magnitude > MAX_DISTANCE then
		return
	end

	local runtime = MCRE.Runtime
	local x, y, z = toGrid(target.Position)

	if runtime and runtime.WorldData and runtime.WorldData.Changes then
		runtime.WorldData.Changes[gridKey(x, y, z)] = false
	end

	local snapped = snapToGrid(target.Position)
	target:Destroy()
	if MCRE.UnregisterBlockAtGrid then
		MCRE.UnregisterBlockAtGrid(x, y, z)
	end
	if MCRE.RevealNeighborsAround then
		MCRE.RevealNeighborsAround(x, y, z)
	end
	settleAbove(runtime and runtime.WorldData, snapped)
end)

PlaceBlock.OnServerEvent:Connect(function(player, position, blockName)
	if player:GetAttribute("WorldLoaded") ~= true then
		return
	end

	if typeof(position) ~= "Vector3" then
		return
	end

	local template = BLOCKS[tostring(blockName or "")]
	if not template then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	local snapped = snapToGrid(position)

	if (hrp.Position - snapped).Magnitude > MAX_DISTANCE then
		return
	end

	local x, y, z = toGrid(snapped)

	if getPartAt(snapped) then
		return
	end

	if MCRE.GetLogicalBlockName and MCRE.GetLogicalBlockName(x, y, z) then
		return
	end

	if not LIQUID[blockName] and characterIntersects(character, snapped) then
		return
	end

	local folder = worldFolder()
	if not folder then
		return
	end

	local attributes = nil

	if LIQUID[blockName] then
		attributes = {
			LiquidType = blockName,
			IsLiquidSource = true,
			IsStaticLiquid = false,
			FlowDistance = 0,
			SourceY = y,
		}
	end

	local part
	if MCRE.CreateWorldBlock then
		part = MCRE.CreateWorldBlock(blockName, x, y, z, attributes)
	else
		part = template:Clone()
		part.Name = blockName
		part.Anchored = true
		part.Position = snapped
		part.Parent = folder
		if attributes then
			for name, value in pairs(attributes) do
				part:SetAttribute(name, value)
			end
		end
	end

	if not part then
		return
	end

	part.CanCollide = not LIQUID[blockName]

	local runtime = MCRE.Runtime
	if runtime and runtime.WorldData and runtime.WorldData.Changes then
		runtime.WorldData.Changes[gridKey(x, y, z)] = blockName
	end

	if FALLING[blockName] then
		enqueueFallingBlock(runtime and runtime.WorldData, part)
	end
end)
