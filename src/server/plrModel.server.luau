local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

_G.MCRE = _G.MCRE or {}
local MCRE = _G.MCRE

local rmtGame = ReplicatedStorage:WaitForChild("rmtGame")
local BreakBlock = rmtGame:WaitForChild("BreakBlock")
local PlaceBlock = rmtGame:WaitForChild("PlaceBlock")

local blocksFolder = ServerStorage:WaitForChild("blcStorage")

local BLOCKS = {
	blcGrass = blocksFolder:WaitForChild("blcGrass"),
	blcDirt = blocksFolder:WaitForChild("blcDirt"),
	blcStone = blocksFolder:WaitForChild("blcStone"),
	blcCobblestone = blocksFolder:WaitForChild("blcCobblestone"),
	blcLog = blocksFolder:WaitForChild("blcLog"),
	blcLeaves = blocksFolder:WaitForChild("blcLeaves"),
	blcSand = blocksFolder:WaitForChild("blcSand"),
	blcGravel = blocksFolder:WaitForChild("blcGravel"),
	blcWater = blocksFolder:WaitForChild("blcWater"),
	blcLava = blocksFolder:WaitForChild("blcLava"),
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

local function allParts()
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
	for _, part in ipairs(allParts()) do
		if (part.Position - position).Magnitude < 0.1 then
			return part
		end
	end
	return nil
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

local function settleFallingBlock(runtimeData, part)
	if not part or not part.Parent or not FALLING[part.Name] then
		return
	end

	local px, py, pz = toGrid(part.Position)
	local finalY = py

	while finalY > 0 do
		local under = getPartAt(Vector3.new(px * BLOCK_SIZE, (finalY - 1) * BLOCK_SIZE, pz * BLOCK_SIZE))
		if under then
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

	part.Anchored = false
	part.AssemblyLinearVelocity = Vector3.new(0, -35, 0)

	task.delay(0.08, function()
		if not part or not part.Parent then
			return
		end

		part.AssemblyLinearVelocity = Vector3.zero
		part.Position = Vector3.new(px * BLOCK_SIZE, finalY * BLOCK_SIZE, pz * BLOCK_SIZE)
		part.Anchored = true
	end)
end

local function settleAbove(runtimeData, position)
	local above = getPartAt(position + Vector3.new(0, BLOCK_SIZE, 0))
	if above and FALLING[above.Name] then
		settleFallingBlock(runtimeData, above)
	end
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

	if getPartAt(snapped) then
		return
	end

	if not LIQUID[blockName] and characterIntersects(character, snapped) then
		return
	end

	local folder = worldFolder()
	if not folder then
		return
	end

	local part = template:Clone()
	part.Name = blockName
	part.Anchored = true
	part.CanCollide = not LIQUID[blockName]
	part.Position = snapped

	if LIQUID[blockName] then
		local _, sourceY = toGrid(snapped)
		part:SetAttribute("LiquidType", blockName)
		part:SetAttribute("IsLiquidSource", true)
		part:SetAttribute("IsStaticLiquid", false)
		part:SetAttribute("FlowDistance", 0)
		part:SetAttribute("SourceY", sourceY)
	end

	part.Parent = folder

	local runtime = MCRE.Runtime
	local x, y, z = toGrid(snapped)
	if runtime and runtime.WorldData and runtime.WorldData.Changes then
		runtime.WorldData.Changes[gridKey(x, y, z)] = blockName
	end

	if FALLING[blockName] then
		task.defer(function()
			settleFallingBlock(runtime and runtime.WorldData, part)
		end)
	end
end)