local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

_G.MCRE = _G.MCRE or {}
local MCRE = _G.MCRE

local mobStorage = ServerStorage:WaitForChild("plrStorage")

local MOB_DEFS = {
	{
		Name = "Chicken",
		Template = "mdlChicken",
		Passive = true,
		MaxCount = 8,
		SpawnChance = 0.42,
		Health = 4,
		FaceYawOffset = math.pi,
	},
	{
		Name = "Pig",
		Template = "mdlPig",
		Passive = true,
		MaxCount = 6,
		SpawnChance = 0.35,
		Health = 10,
		FaceYawOffset = math.pi,
	},
	{
		Name = "Zombie",
		Template = "mdlZombie",
		Passive = false,
		MaxCount = 5,
		SpawnChance = 0.26,
		Health = 20,
		Damage = 4,
		FaceYawOffset = math.pi,
	},
}

local SPAWN_INTERVAL = 3.5
local MIN_PLAYER_DISTANCE = 24
local MAX_PLAYER_DISTANCE = 72
local DESPAWN_DISTANCE = 150

local rng = Random.new()

local function getMobFolder()
	local folder = Workspace:FindFirstChild("Mobs")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Mobs"
		folder.Parent = Workspace
	end
	return folder
end

local function getRoot(model)
	if not model or not model:IsA("Model") then
		return nil
	end

	local root = model.PrimaryPart
		or model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChild("Torso")
		or model:FindFirstChildWhichIsA("BasePart", true)

	if root and not model.PrimaryPart then
		pcall(function()
			model.PrimaryPart = root
		end)
	end

	return root
end

local function hasJointBetween(a, b)
	for _, obj in ipairs(a:GetDescendants()) do
		if obj:IsA("JointInstance") or obj:IsA("WeldConstraint") then
			if (obj.Part0 == a and obj.Part1 == b) or (obj.Part0 == b and obj.Part1 == a) then
				return true
			end
		end
	end

	for _, obj in ipairs(b:GetDescendants()) do
		if obj:IsA("JointInstance") or obj:IsA("WeldConstraint") then
			if (obj.Part0 == a and obj.Part1 == b) or (obj.Part0 == b and obj.Part1 == a) then
				return true
			end
		end
	end

	return false
end

local function weldModelToRoot(model, root)
	if not root then
		return
	end

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Massless = part ~= root
			part.CanCollide = part == root
			pcall(function()
				part:SetNetworkOwner(nil)
			end)

			if part ~= root and not hasJointBetween(root, part) then
				local weld = Instance.new("WeldConstraint")
				weld.Name = "MCREMobWeld"
				weld.Part0 = root
				weld.Part1 = part
				weld.Parent = root
			end
		end
	end
end

local function faceDirection(model, root, direction, yawOffset)
	if not root or not direction then
		return
	end

	local flatDirection = Vector3.new(direction.X, 0, direction.Z)
	if flatDirection.Magnitude < 0.1 then
		return
	end

	local pivot = model:GetPivot()
	model:PivotTo(CFrame.lookAt(pivot.Position, pivot.Position + flatDirection.Unit) * CFrame.Angles(0, yawOffset or 0, 0))
end

local function faceTarget(model, root, target, yawOffset)
	if not root or not target then
		return
	end

	local flatTarget = Vector3.new(target.X, root.Position.Y, target.Z)
	faceDirection(model, root, flatTarget - root.Position, yawOffset)
end

local function prepareModel(model, def)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = def.Health or humanoid.MaxHealth
		humanoid.Health = humanoid.MaxHealth
		humanoid.WalkSpeed = def.Passive and 6 or 11
		humanoid.AutoRotate = false
	end

	weldModelToRoot(model, getRoot(model))
end

local function countMobs(folder, def)
	local count = 0
	for _, mob in ipairs(folder:GetChildren()) do
		if mob:GetAttribute("MobType") == def.Name then
			count += 1
		end
	end
	return count
end

local function nearestPlayer(position, maxDistance)
	local nearest = nil
	local nearestDistance = maxDistance or math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("WorldLoaded") == true then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 then
				local distance = (root.Position - position).Magnitude
				if distance < nearestDistance then
					nearest = player
					nearestDistance = distance
				end
			end
		end
	end

	return nearest, nearestDistance
end

local function isSpawnableColumn(x, z, def)
	if not MCRE.HeightAt or not MCRE.GetBlockAtGrid or not MCRE.WaterLevel then
		return nil
	end

	if MCRE.WorldWidth and (x < 1 or x >= MCRE.WorldWidth - 1) then
		return nil
	end
	if MCRE.WorldDepth and (z < 1 or z >= MCRE.WorldDepth - 1) then
		return nil
	end

	local y = MCRE.HeightAt(x, z)
	if not y or y <= MCRE.WaterLevel + 1 then
		return nil
	end

	local ground = MCRE.GetBlockAtGrid(x, y, z)
	if not ground or not ground.Parent then
		return nil
	end

	if def.Passive and ground.Name ~= "blcGrass" then
		return nil
	end

	local above = MCRE.GetBlockAtGrid(x, y + 1, z)
	if above then
		return nil
	end

	return y
end

local function chooseSpawn(def)
	local players = Players:GetPlayers()
	if #players == 0 then
		return nil
	end

	for _ = 1, 18 do
		local player = players[rng:NextInteger(1, #players)]
		if player:GetAttribute("WorldLoaded") == true then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and MCRE.BlockSize then
				local angle = rng:NextNumber(0, math.pi * 2)
				local distance = rng:NextNumber(MIN_PLAYER_DISTANCE, MAX_PLAYER_DISTANCE)
				local x = math.floor((root.Position.X + math.cos(angle) * distance) / MCRE.BlockSize + 0.5)
				local z = math.floor((root.Position.Z + math.sin(angle) * distance) / MCRE.BlockSize + 0.5)
				local y = isSpawnableColumn(x, z, def)
				if y then
					return Vector3.new(x * MCRE.BlockSize, (y + 2) * MCRE.BlockSize, z * MCRE.BlockSize)
				end
			end
		end
	end

	return nil
end

local function addZombieDamage(model, def)
	local root = getRoot(model)
	if not root or def.Passive then
		return
	end

	local lastHit = {}
	root.Touched:Connect(function(hit)
		local character = hit and hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		local now = os.clock()
		if lastHit[player] and now - lastHit[player] < 1.1 then
			return
		end
		lastHit[player] = now

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:TakeDamage(def.Damage or 3)
		end
	end)
end

local function runMobBrain(model, def)
	task.spawn(function()
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = getRoot(model)
		if not root then
			model:Destroy()
			return
		end

		task.spawn(function()
			while model.Parent and root.Parent do
				local velocity = root.AssemblyLinearVelocity
				if Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 0.75 then
					faceDirection(model, root, velocity, def.FaceYawOffset)
				end
				task.wait(0.12)
			end
		end)

		while model.Parent and root.Parent do
			local nearest, distance = nearestPlayer(root.Position, DESPAWN_DISTANCE)
			if not nearest then
				model:Destroy()
				return
			end

			if humanoid then
				if def.Passive then
					local angle = rng:NextNumber(0, math.pi * 2)
					local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(8, 18)
					local target = root.Position + offset
					faceTarget(model, root, target, def.FaceYawOffset)
					humanoid:MoveTo(target)
					task.wait(rng:NextNumber(2.0, 4.5))
				else
					local targetRoot = nearest.Character and nearest.Character:FindFirstChild("HumanoidRootPart")
					if targetRoot then
						faceTarget(model, root, targetRoot.Position, def.FaceYawOffset)
						humanoid:MoveTo(targetRoot.Position)
					end
					task.wait(0.55)
				end
			else
				task.wait(def.Passive and 3 or 1)
			end
		end
	end)
end

local function spawnMob(folder, def)
	local template = mobStorage:FindFirstChild(def.Template)
	if not template then
		return
	end

	local position = chooseSpawn(def)
	if not position then
		return
	end

	local model = template:Clone()
	model.Name = def.Name
	model:SetAttribute("MobType", def.Name)
	model.Parent = folder
	prepareModel(model, def)
	model:PivotTo(CFrame.new(position))
	addZombieDamage(model, def)
	runMobBrain(model, def)
end

task.spawn(function()
	while true do
		task.wait(SPAWN_INTERVAL)

		if not MCRE.Runtime or MCRE.Runtime.WorldLoaded ~= true then
			continue
		end

		local folder = getMobFolder()
		for _, def in ipairs(MOB_DEFS) do
			if countMobs(folder, def) < def.MaxCount and rng:NextNumber() <= def.SpawnChance then
				spawnMob(folder, def)
			end
		end
	end
end)
