local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

local rmtGame = ReplicatedStorage:WaitForChild("rmtGame")
local BreakBlock = rmtGame:WaitForChild("BreakBlock")
local PlaceBlock = rmtGame:WaitForChild("PlaceBlock") 
local SetCrouchState = rmtGame:WaitForChild("SetCrouchState")

local guiAssets = ReplicatedStorage:WaitForChild("guiAssets")
local itemsFolder = guiAssets:WaitForChild("items")

local BLOCK_SIZE = 3

local inventory = {
	{ blockName = "blcGrass", iconName = "itm_grass_block", title = "Grass" },
	{ blockName = "blcDirt", iconName = "itm_dirt", title = "Dirt" },
	{ blockName = "blcStone", iconName = "itm_stone", title = "Stone" },
	{ blockName = "blcCobblestone", iconName = "itm_cobblestone", title = "Cobble" },
	{ blockName = "blcLog", iconName = "itm_log", title = "Log" },
	{ blockName = "blcLeaves", iconName = "itm_leaves", title = "Leaves" },
	{ blockName = "blcSand", iconName = "itm_sand", title = "Sand" },
	{ blockName = "blcGravel", iconName = "itm_gravel", title = "Gravel" },
	{ blockName = "blcWater", iconName = "itm_water", title = "Water" },
	{ blockName = "blcLava", iconName = "itm_lava", title = "Lava" },
}

local selected = 1
local isCrouching = false
local inventoryOpen = false
local swimUpHeld = false
local activeLiquid = nil

local normalWalkSpeed = 16
local crouchWalkSpeed = 7
local crouchJumpPower = 0
local normalJumpPower = 42

local LIQUID_BLOCKS = {
	blcWater = true,
	blcLava = true,
}

local SWIM_SPEEDS = {
	blcWater = 12,
	blcLava = 8,
}

local SWIM_RISE_SPEEDS = {
	blcWater = 12,
	blcLava = 8,
}

local SWIM_FLOAT_SPEEDS = {
	blcWater = 4,
	blcLava = 2.5,
}

local highlight = Instance.new("SelectionBox")
highlight.Name = "BlockHighlight"
highlight.LineThickness = 0.05
highlight.SurfaceTransparency = 0.8
highlight.Color3 = Color3.fromRGB(255, 255, 255)
highlight.Visible = false
highlight.Parent = workspace

local ui = Instance.new("ScreenGui")
ui.Name = "ctrSettingsUI"
ui.ResetOnSpawn = false
ui.IgnoreGuiInset = true
ui.Parent = playerGui

local function corner(instance, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = instance
	return c
end

local function stroke(instance, color, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(230, 230, 220)
	s.Transparency = transparency or 0.42
	s.Thickness = thickness or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = instance
	return s
end

local crosshair = Instance.new("Frame")
crosshair.Size = UDim2.new(0, 20, 0, 20)
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.Position = UDim2.new(0.5, 0, 0.5, 0)
crosshair.BackgroundTransparency = 1
crosshair.Parent = ui

local vLine = Instance.new("Frame")
vLine.Size = UDim2.new(0, 2, 0, 16)
vLine.AnchorPoint = Vector2.new(0.5, 0.5)
vLine.Position = UDim2.new(0.5, 0, 0.5, 0)
vLine.BorderSizePixel = 0
vLine.BackgroundColor3 = Color3.new(1, 1, 1)
vLine.Parent = crosshair

local hLine = Instance.new("Frame")
hLine.Size = UDim2.new(0, 16, 0, 2)
hLine.AnchorPoint = Vector2.new(0.5, 0.5)
hLine.Position = UDim2.new(0.5, 0, 0.5, 0)
hLine.BorderSizePixel = 0
hLine.BackgroundColor3 = Color3.new(1, 1, 1)
hLine.Parent = crosshair

local hotbar = Instance.new("Frame")
hotbar.Size = UDim2.new(0, 560, 0, 60)
hotbar.AnchorPoint = Vector2.new(0.5, 1)
hotbar.Position = UDim2.new(0.5, 0, 1, -18)
hotbar.BackgroundColor3 = Color3.fromRGB(16, 19, 19)
hotbar.BackgroundTransparency = 0.28
hotbar.BorderSizePixel = 0
hotbar.Parent = ui
corner(hotbar, 8)
stroke(hotbar, Color3.fromRGB(232, 230, 210), 0.62, 1)

local inventoryFrame = Instance.new("Frame")
inventoryFrame.Size = UDim2.new(0, 660, 0, 370)
inventoryFrame.AnchorPoint = Vector2.new(0.5, 0.5)
inventoryFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
inventoryFrame.BackgroundColor3 = Color3.fromRGB(18, 24, 25)
inventoryFrame.BackgroundTransparency = 0.08
inventoryFrame.BorderSizePixel = 0
inventoryFrame.Visible = false
inventoryFrame.Parent = ui
corner(inventoryFrame, 8)
stroke(inventoryFrame, Color3.fromRGB(232, 230, 210), 0.56, 1)

local inventoryTitle = Instance.new("TextLabel")
inventoryTitle.Size = UDim2.new(1, 0, 0, 42)
inventoryTitle.BackgroundTransparency = 1
inventoryTitle.Text = "Inventory"
inventoryTitle.TextColor3 = Color3.new(1, 1, 1)
inventoryTitle.Font = Enum.Font.GothamBold
inventoryTitle.TextSize = 28
inventoryTitle.Parent = inventoryFrame

local inventoryGrid = Instance.new("Frame")
inventoryGrid.Size = UDim2.new(1, -40, 1, -70)
inventoryGrid.Position = UDim2.new(0, 20, 0, 50)
inventoryGrid.BackgroundTransparency = 1
inventoryGrid.Parent = inventoryFrame

local hotbarSlots = {}
local inventoryButtons = {}

local function controlsEnabled()
	return player:GetAttribute("WorldLoaded") == true
		and player:GetAttribute("InMenu") ~= true
		and player:GetAttribute("Paused") ~= true
end

local function isBlockTarget(part)
	if not part or not part:IsA("BasePart") then
		return false
	end

	for _, item in ipairs(inventory) do
		if part.Name == item.blockName then
			return true
		end
	end

	return false
end

local function getItemImage(name)
	local asset = itemsFolder:FindFirstChild(name)
	if not asset then
		return ""
	end

	if asset:IsA("ImageLabel") or asset:IsA("ImageButton") then
		return asset.Image
	end

	if asset:IsA("Decal") or asset:IsA("Texture") then
		return asset.Texture
	end

	local decal = asset:FindFirstChildWhichIsA("Decal", true)
	if decal then
		return decal.Texture
	end

	local tex = asset:FindFirstChildWhichIsA("Texture", true)
	if tex then
		return tex.Texture
	end

	return ""
end

local function getHumanoidAndRoot()
	local character = player.Character
	if not character then
		return nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	return humanoid, hrp
end

local function getCameraTarget(character)
	if not character then
		return nil
	end

	local head = character:FindFirstChild("Head")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return head or humanoid
end

local function clearCharacterSounds(character)
	for _, obj in ipairs(character:GetDescendants()) do
		if obj:IsA("Sound") then
			obj:Destroy()
		end
	end

	character.DescendantAdded:Connect(function(obj)
		if obj:IsA("Sound") then
			obj:Destroy()
		end
	end)
end

local function applyCrouch()
	local humanoid = getHumanoidAndRoot()
	if not humanoid then
		return
	end

	if activeLiquid then
		return
	end

	if isCrouching then
		humanoid.WalkSpeed = crouchWalkSpeed
		humanoid.JumpPower = crouchJumpPower
	else
		humanoid.WalkSpeed = normalWalkSpeed
		humanoid.JumpPower = normalJumpPower
	end
end

local liquidOverlapParams = OverlapParams.new()
liquidOverlapParams.FilterType = Enum.RaycastFilterType.Exclude

local function getCharacterLiquid(character, hrp)
	if not character or not hrp then
		return nil
	end

	liquidOverlapParams.FilterDescendantsInstances = { character }

	local bodyParts = Workspace:GetPartBoundsInBox(
		CFrame.new(hrp.Position + Vector3.new(0, BLOCK_SIZE * 0.2, 0)),
		Vector3.new(BLOCK_SIZE * 0.7, BLOCK_SIZE * 1.8, BLOCK_SIZE * 0.7),
		liquidOverlapParams
	)

	local liquidType = nil
	for _, part in ipairs(bodyParts) do
		if LIQUID_BLOCKS[part.Name] then
			if part.Name == "blcLava" then
				liquidType = "blcLava"
				break
			end

			liquidType = liquidType or "blcWater"
		end
	end

	if not liquidType then
		return nil
	end

	local headSubmerged = false
	local head = character:FindFirstChild("Head")
	if head then
		local headParts = Workspace:GetPartBoundsInBox(
			CFrame.new(head.Position),
			Vector3.new(1.5, 1.5, 1.5),
			liquidOverlapParams
		)

		for _, part in ipairs(headParts) do
			if part.Name == liquidType or (liquidType == "blcWater" and part.Name == "blcLava") then
				if part.Name == "blcLava" then
					liquidType = "blcLava"
				end
				headSubmerged = true
				break
			end
		end
	end

	return {
		Type = liquidType,
		HeadSubmerged = headSubmerged,
	}
end

local function applySwimming(humanoid, hrp, liquidInfo)
	activeLiquid = liquidInfo and liquidInfo.Type or nil

	if not liquidInfo then
		if humanoid:GetState() == Enum.HumanoidStateType.Swimming then
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
		applyCrouch()
		return false
	end

	local liquidType = liquidInfo.Type
	local swimSpeed = SWIM_SPEEDS[liquidType] or 10
	local riseSpeed = SWIM_RISE_SPEEDS[liquidType] or 8
	local floatSpeed = SWIM_FLOAT_SPEEDS[liquidType] or 3
	local moveDirection = humanoid.MoveDirection

	humanoid.WalkSpeed = swimSpeed
	humanoid.JumpPower = 0
	humanoid:ChangeState(Enum.HumanoidStateType.Swimming)

	local targetY = floatSpeed
	if swimUpHeld then
		targetY = riseSpeed
	elseif isCrouching then
		targetY = -riseSpeed * 0.7
	elseif liquidInfo.HeadSubmerged then
		targetY = floatSpeed * 0.45
	end

	local targetVelocity = Vector3.new(moveDirection.X * swimSpeed, targetY, moveDirection.Z * swimSpeed)
	hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity:Lerp(targetVelocity, 0.18)
	return true
end

local function updateSlotVisual(index)
	local slot = hotbarSlots[index]
	if not slot then
		return
	end

	slot.BackgroundColor3 = index == selected and Color3.fromRGB(215, 205, 158) or Color3.fromRGB(54, 64, 58)
	slot.Image.Image = getItemImage(inventory[index].iconName)
	slot.Number.Text = tostring(index % 10)

	if inventoryButtons[index] then
		inventoryButtons[index].BackgroundColor3 = index == selected and Color3.fromRGB(92, 122, 92) or Color3.fromRGB(49, 58, 54)
	end
end

local function refreshUI()
	for i = 1, #inventory do
		updateSlotVisual(i)
	end
end

local function setSelected(index)
	if index >= 1 and index <= #inventory then
		selected = index
		refreshUI()
	end
end

local function setInventoryOpen(state)
	inventoryOpen = state == true
	inventoryFrame.Visible = inventoryOpen
	player:SetAttribute("InventoryOpen", inventoryOpen)

	if inventoryOpen then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	end
end

local function buildHotbar()
	for i = 1, #inventory do
		local slot = Instance.new("Frame")
		slot.Size = UDim2.new(0, 50, 0, 50)
		slot.Position = UDim2.new(0, 5 + (i - 1) * 55, 0, 5)
		slot.BorderSizePixel = 0
		slot.Parent = hotbar
		corner(slot, 6)
		stroke(slot, Color3.fromRGB(238, 235, 215), 0.6, 1)

		local image = Instance.new("ImageLabel")
		image.Name = "Image"
		image.Size = UDim2.new(1, -10, 1, -10)
		image.Position = UDim2.new(0, 5, 0, 5)
		image.BackgroundTransparency = 1
		image.ScaleType = Enum.ScaleType.Fit
		image.Parent = slot

		local num = Instance.new("TextLabel")
		num.Name = "Number"
		num.Size = UDim2.new(0, 16, 0, 16)
		num.Position = UDim2.new(0, 2, 0, 0)
		num.BackgroundTransparency = 1
		num.TextColor3 = Color3.new(1, 1, 1)
		num.Font = Enum.Font.GothamBold
		num.TextSize = 14
		num.Parent = slot

		hotbarSlots[i] = slot
	end
end

local function buildInventory()
	local columns = 5
	local cell = 108
	local gap = 12

	for i, item in ipairs(inventory) do
		local row = math.floor((i - 1) / columns)
		local col = (i - 1) % columns

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, cell, 0, cell)
		btn.Position = UDim2.new(0, col * (cell + gap), 0, row * (cell + gap))
		btn.BorderSizePixel = 0
		btn.BackgroundColor3 = Color3.fromRGB(49, 58, 54)
		btn.Text = ""
		btn.Parent = inventoryGrid
		corner(btn, 6)
		stroke(btn, Color3.fromRGB(235, 232, 210), 0.58, 1)

		local image = Instance.new("ImageLabel")
		image.Size = UDim2.new(1, -16, 1, -34)
		image.Position = UDim2.new(0, 8, 0, 6)
		image.BackgroundTransparency = 1
		image.ScaleType = Enum.ScaleType.Fit
		image.Image = getItemImage(item.iconName)
		image.Parent = btn

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -8, 0, 22)
		label.Position = UDim2.new(0, 4, 1, -24)
		label.BackgroundTransparency = 1
		label.Text = item.title
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 16
		label.TextWrapped = true
		label.Parent = btn

		btn.MouseButton1Click:Connect(function()
			setSelected(i)
			setInventoryOpen(false)
		end)

		inventoryButtons[i] = btn
	end
end

buildHotbar()
buildInventory()
refreshUI()

if player.Character then
	clearCharacterSounds(player.Character)
end

player.CharacterAdded:Connect(function(character)
	camera = Workspace.CurrentCamera
	clearCharacterSounds(character)
	task.wait(0.2)

	local target = getCameraTarget(character)
	if target and camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = target
	end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then
		return
	end

	if input.KeyCode == Enum.KeyCode.E then
		if controlsEnabled() then
			setInventoryOpen(not inventoryOpen)
		end
		return
	end

	if input.KeyCode == Enum.KeyCode.One then
		setSelected(1)
	elseif input.KeyCode == Enum.KeyCode.Two then
		setSelected(2)
	elseif input.KeyCode == Enum.KeyCode.Three then
		setSelected(3)
	elseif input.KeyCode == Enum.KeyCode.Four then
		setSelected(4)
	elseif input.KeyCode == Enum.KeyCode.Five then
		setSelected(5)
	elseif input.KeyCode == Enum.KeyCode.Six then
		setSelected(6)
	elseif input.KeyCode == Enum.KeyCode.Seven then
		setSelected(7)
	elseif input.KeyCode == Enum.KeyCode.Eight then
		setSelected(8)
	elseif input.KeyCode == Enum.KeyCode.Nine then
		setSelected(9)
	elseif input.KeyCode == Enum.KeyCode.Zero then
		setSelected(10)
	elseif input.KeyCode == Enum.KeyCode.Space then
		swimUpHeld = true
	elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		isCrouching = true
		SetCrouchState:FireServer(true)
		applyCrouch()
	end
end)

UserInputService.InputEnded:Connect(function(input, gpe)
	if gpe then
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		isCrouching = false
		SetCrouchState:FireServer(false)
		applyCrouch()
	elseif input.KeyCode == Enum.KeyCode.Space then
		swimUpHeld = false
	end
end)

mouse.Button1Down:Connect(function()
	if not controlsEnabled() or inventoryOpen then
		return
	end

	if mouse.Target and isBlockTarget(mouse.Target) then
		BreakBlock:FireServer(mouse.Target)
	end
end)

mouse.Button2Down:Connect(function()
	if not controlsEnabled() or inventoryOpen then
		return
	end

	if not mouse.Target or not isBlockTarget(mouse.Target) then
		return
	end

	local item = inventory[selected]
	if not item then
		return
	end

	local target = mouse.Target
	local normal = mouse.TargetSurface
	local offset = Vector3.FromNormalId(normal)
	local newPosition = target.Position + offset * target.Size.X

	PlaceBlock:FireServer(newPosition, item.blockName)
end)

RunService.RenderStepped:Connect(function()
	local enabled = controlsEnabled()
	local humanoid, hrp = getHumanoidAndRoot()

	if not enabled then
		highlight.Adornee = nil
		highlight.Visible = false
		crosshair.Visible = false
		hotbar.Visible = false
		inventoryFrame.Visible = false
		inventoryOpen = false
		swimUpHeld = false
		activeLiquid = nil
		player:SetAttribute("InventoryOpen", false)
		UserInputService.MouseIconEnabled = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default

		if isCrouching then
			isCrouching = false
			SetCrouchState:FireServer(false)
		end

		if humanoid then
			humanoid.WalkSpeed = normalWalkSpeed
			humanoid.JumpPower = normalJumpPower
		end

		return
	end

	hotbar.Visible = true
	crosshair.Visible = not inventoryOpen
	inventoryFrame.Visible = inventoryOpen

	if inventoryOpen then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	end

	local target = mouse.Target
	if not inventoryOpen and target and isBlockTarget(target) then
		highlight.Adornee = target
		highlight.Visible = true
	else
		highlight.Adornee = nil
		highlight.Visible = false
	end

	if humanoid and hrp then
		camera = Workspace.CurrentCamera
		local cameraTarget = getCameraTarget(player.Character)
		if camera and cameraTarget then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = cameraTarget
		end

		local liquidInfo = getCharacterLiquid(player.Character, hrp)
		local isSwimming = applySwimming(humanoid, hrp, liquidInfo)

		if isCrouching and not isSwimming then
			local moveDirection = humanoid.MoveDirection
			if moveDirection.Magnitude > 0.05 then
				local ahead = hrp.Position + moveDirection.Unit * (BLOCK_SIZE * 0.8)
				local origin = ahead + Vector3.new(0, 1, 0)
				local direction = Vector3.new(0, -4, 0)

				local rayParams = RaycastParams.new()
				rayParams.FilterType = Enum.RaycastFilterType.Exclude
				rayParams.FilterDescendantsInstances = { player.Character }

				local result = Workspace:Raycast(origin, direction, rayParams)
				if not result or not isBlockTarget(result.Instance) then
					humanoid:Move(Vector3.zero, true)
					local velocity = hrp.AssemblyLinearVelocity
					hrp.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
				end
			end
		end
	end
end)
