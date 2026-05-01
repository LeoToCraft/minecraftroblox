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
local InventorySync = rmtGame:WaitForChild("InventorySync", 5)

local guiAssets = ReplicatedStorage:WaitForChild("guiAssets")
local itemsFolder = guiAssets:WaitForChild("items")

local BLOCK_SIZE = 3

local inventory = {
	{ blockName = "blcGrass", iconName = "grass_block_item", title = "Grass" },
	{ blockName = "blcDirt", iconName = "dirt_item", title = "Dirt" },
	{ blockName = "blcStone", iconName = "stone_item", title = "Stone" },
	{ blockName = "blcCobblestone", iconName = "cobblestone_item", title = "Cobble" },
	{ blockName = "blcBricks", iconName = "bricks_item", title = "Bricks" },
	{ blockName = "blcPlanks", iconName = "planks_item", title = "Planks" },
	{ blockName = "blcGlass", iconName = "glass_item", title = "Glass" },
	{ blockName = "blcLog", iconName = "log_item", title = "Log" },
	{ blockName = "blcLeaves", iconName = "leaves_item", title = "Leaves" },
	{ blockName = "blcSand", iconName = "sand_item", title = "Sand" },
	{ blockName = "blcGravel", iconName = "gravel_item", title = "Gravel" },
	{ blockName = "blcWater", iconName = "water_item", title = "Water" },
	{ blockName = "blcLava", iconName = "lava_item", title = "Lava" },
}

local BLOCK_NAME_LOOKUP = {}
local INVENTORY_BY_BLOCK = {}
for _, item in ipairs(inventory) do
	BLOCK_NAME_LOOKUP[item.blockName] = true
	INVENTORY_BY_BLOCK[item.blockName] = item
end

local BLOCK_ICON_COLORS = {
	blcGrass = Color3.fromRGB(82, 170, 72),
	blcDirt = Color3.fromRGB(105, 76, 52),
	blcStone = Color3.fromRGB(118, 126, 132),
	blcCobblestone = Color3.fromRGB(96, 104, 112),
	blcBricks = Color3.fromRGB(150, 82, 66),
	blcPlanks = Color3.fromRGB(165, 116, 62),
	blcGlass = Color3.fromRGB(150, 205, 225),
	blcLog = Color3.fromRGB(116, 78, 40),
	blcLeaves = Color3.fromRGB(58, 132, 62),
	blcSand = Color3.fromRGB(214, 202, 142),
	blcGravel = Color3.fromRGB(128, 136, 144),
	blcWater = Color3.fromRGB(58, 116, 210),
	blcLava = Color3.fromRGB(230, 92, 28),
}

local selected = 1
local HOTBAR_SLOT_COUNT = 10
local isCrouching = false
local inventoryOpen = false
local swimUpHeld = false
local activeLiquid = nil

local normalWalkSpeed = 16
local crouchWalkSpeed = 7
local crouchJumpPower = 0
local normalJumpHeight = BLOCK_SIZE * 1.5
local normalJumpPower = math.sqrt(2 * Workspace.Gravity * normalJumpHeight)

local LIQUID_BLOCKS = {
	blcWater = true,
	blcLava = true,
}

local SWIM_SPEEDS = {
	blcWater = 12,
	blcLava = 7,
}

local SWIM_RISE_SPEEDS = {
	blcWater = 18,
	blcLava = 14,
}

local SWIM_FLOAT_SPEEDS = {
	blcWater = 2.5,
	blcLava = 1.5,
}

local highlight = Instance.new("SelectionBox")
highlight.Name = "BlockHighlight"
highlight.LineThickness = 0.05
highlight.SurfaceTransparency = 0.8
highlight.Color3 = Color3.fromRGB(255, 255, 255)
highlight.Visible = false
highlight.Parent = workspace

local hiddenLocalWater = {}

local ui = Instance.new("ScreenGui")
ui.Name = "ctrSettingsUI"
ui.ResetOnSpawn = false
ui.IgnoreGuiInset = true
ui.Parent = playerGui

local waterOverlay = Instance.new("Frame")
waterOverlay.Size = UDim2.new(1, 0, 1, 0)
waterOverlay.BackgroundColor3 = Color3.fromRGB(38, 105, 220)
waterOverlay.BackgroundTransparency = 0.68
waterOverlay.BorderSizePixel = 0
waterOverlay.Visible = false
waterOverlay.ZIndex = 0
waterOverlay.Parent = ui

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
hotbar.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
hotbar.BackgroundTransparency = 0.12
hotbar.BorderSizePixel = 0
hotbar.Parent = ui
corner(hotbar, 0)
stroke(hotbar, Color3.fromRGB(12, 12, 12), 0, 2)

local heartBar = Instance.new("Frame")
heartBar.Size = UDim2.new(0, 300, 0, 28)
heartBar.AnchorPoint = Vector2.new(0.5, 1)
heartBar.Position = UDim2.new(0.5, -125, 1, -82)
heartBar.BackgroundTransparency = 1
heartBar.Visible = false
heartBar.Parent = ui

local hearts = {}
for i = 1, 10 do
	local heart = Instance.new("TextLabel")
	heart.Size = UDim2.new(0, 26, 0, 26)
	heart.Position = UDim2.new(0, (i - 1) * 28, 0, 0)
	heart.BackgroundTransparency = 1
	heart.Text = utf8.char(9829)
	heart.TextColor3 = Color3.fromRGB(210, 28, 28)
	heart.TextStrokeColor3 = Color3.fromRGB(55, 0, 0)
	heart.TextStrokeTransparency = 0.15
	heart.Font = Enum.Font.Arcade
	heart.TextSize = 22
	heart.Parent = heartBar
	hearts[i] = heart
end

local inventoryFrame = Instance.new("Frame")
inventoryFrame.Size = UDim2.new(0, 660, 0, 370)
inventoryFrame.AnchorPoint = Vector2.new(0.5, 0.5)
inventoryFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
inventoryFrame.BackgroundColor3 = Color3.fromRGB(198, 198, 198)
inventoryFrame.BackgroundTransparency = 0
inventoryFrame.BorderSizePixel = 0
inventoryFrame.Visible = false
inventoryFrame.Parent = ui
corner(inventoryFrame, 0)
stroke(inventoryFrame, Color3.fromRGB(60, 60, 60), 0, 3)

local inventoryTitle = Instance.new("TextLabel")
inventoryTitle.Size = UDim2.new(1, 0, 0, 42)
inventoryTitle.BackgroundTransparency = 1
inventoryTitle.Text = "Inventory"
inventoryTitle.TextColor3 = Color3.fromRGB(55, 55, 55)
inventoryTitle.Font = Enum.Font.Arcade
inventoryTitle.TextSize = 28
inventoryTitle.Parent = inventoryFrame

local inventoryGrid = Instance.new("ScrollingFrame")
inventoryGrid.Size = UDim2.new(1, -40, 1, -70)
inventoryGrid.Position = UDim2.new(0, 20, 0, 50)
inventoryGrid.BackgroundTransparency = 1
inventoryGrid.BorderSizePixel = 0
inventoryGrid.CanvasSize = UDim2.new(0, 0, 0, 0)
inventoryGrid.ScrollBarThickness = 8
inventoryGrid.ScrollingDirection = Enum.ScrollingDirection.Y
inventoryGrid.Parent = inventoryFrame

local inventoryLayout = Instance.new("UIGridLayout")
inventoryLayout.CellSize = UDim2.new(0, 108, 0, 108)
inventoryLayout.CellPadding = UDim2.new(0, 12, 0, 12)
inventoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
inventoryLayout.Parent = inventoryGrid

local hotbarSlots = {}
local inventoryButtons = {}
local hotbarAssignments = {}
local ownedCounts = {}

local function controlsEnabled()
	return player:GetAttribute("WorldLoaded") == true
		and player:GetAttribute("InMenu") ~= true
		and player:GetAttribute("Paused") ~= true
end

local function isBlockTarget(part)
	if not part or not part:IsA("BasePart") then
		return false
	end

	return BLOCK_NAME_LOOKUP[part.Name] == true
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

	local image = asset:FindFirstChildWhichIsA("ImageLabel", true) or asset:FindFirstChildWhichIsA("ImageButton", true)
	if image and image.Image ~= "" then
		return image.Image
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

local function applyItemIcon(image, item)
	if not item then
		image.Image = ""
		image.ImageTransparency = 1
		image.BackgroundTransparency = 1
		return
	end

	local texture = getItemImage(item.iconName)
	image.Image = texture
	if texture == "" then
		image.ImageTransparency = 1
		image.BackgroundTransparency = 0
		image.BackgroundColor3 = BLOCK_ICON_COLORS[item.blockName] or Color3.fromRGB(120, 120, 120)
	else
		image.ImageTransparency = 0
		image.BackgroundTransparency = 1
	end
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

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid
end

local function applyJumpSettings(humanoid, jumpPower, jumpHeight)
	if not humanoid then
		return
	end

	pcall(function()
		humanoid.UseJumpPower = true
	end)
	humanoid.JumpPower = jumpPower
	pcall(function()
		humanoid.JumpHeight = jumpHeight
	end)
end

local function attachCamera(character)
	camera = Workspace.CurrentCamera
	local target = getCameraTarget(character)
	if not target or not camera then
		return false
	end

	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = target
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 0.5
	return true
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
		applyJumpSettings(humanoid, crouchJumpPower, 0)
	else
		humanoid.WalkSpeed = normalWalkSpeed
		applyJumpSettings(humanoid, normalJumpPower, normalJumpHeight)
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
		applyCrouch()
		return false
	end

	local liquidType = liquidInfo.Type
	local swimSpeed = SWIM_SPEEDS[liquidType] or 10
	local riseSpeed = SWIM_RISE_SPEEDS[liquidType] or 8
	local floatSpeed = SWIM_FLOAT_SPEEDS[liquidType] or 3
	local moveDirection = humanoid.MoveDirection

	humanoid.WalkSpeed = swimSpeed
	applyJumpSettings(humanoid, normalJumpPower, normalJumpHeight)

	local velocity = hrp.AssemblyLinearVelocity
	local targetY = nil
	if swimUpHeld then
		targetY = riseSpeed
	elseif isCrouching then
		targetY = -riseSpeed * 0.7
	elseif liquidInfo.HeadSubmerged then
		targetY = floatSpeed
	elseif velocity.Y < -3 then
		targetY = -1
	end

	if moveDirection.Magnitude > 0.05 then
		humanoid:Move(moveDirection, true)
	end

	if targetY then
		local smoothedY = velocity.Y + (targetY - velocity.Y) * 0.16
		hrp.AssemblyLinearVelocity = Vector3.new(velocity.X, smoothedY, velocity.Z)
	end
	return true
end

local function updateLocalWaterVisibility(character, hrp, liquidInfo)
	local keepHidden = {}

	if liquidInfo and liquidInfo.Type == "blcWater" and character and hrp then
		liquidOverlapParams.FilterDescendantsInstances = { character }
		local nearby = Workspace:GetPartBoundsInBox(
			CFrame.new(hrp.Position),
			Vector3.new(BLOCK_SIZE * 5, BLOCK_SIZE * 4, BLOCK_SIZE * 5),
			liquidOverlapParams
		)

		for _, part in ipairs(nearby) do
			if part.Name == "blcWater" then
				part.LocalTransparencyModifier = 1
				keepHidden[part] = true
				hiddenLocalWater[part] = true
			end
		end
	end

	for part in pairs(hiddenLocalWater) do
		if not keepHidden[part] then
			if part and part.Parent then
				part.LocalTransparencyModifier = 0
			end
			hiddenLocalWater[part] = nil
		end
	end

	waterOverlay.Visible = liquidInfo ~= nil
	if liquidInfo and liquidInfo.Type == "blcLava" then
		waterOverlay.BackgroundColor3 = Color3.fromRGB(230, 80, 22)
		waterOverlay.BackgroundTransparency = 0.58
	else
		waterOverlay.BackgroundColor3 = Color3.fromRGB(38, 105, 220)
		waterOverlay.BackgroundTransparency = 0.68
	end
end

local function updateSlotVisual(index)
	local slot = hotbarSlots[index]
	if not slot then
		return
	end

	slot.BackgroundColor3 = index == selected and Color3.fromRGB(235, 235, 235) or Color3.fromRGB(95, 95, 95)
	applyItemIcon(slot.Image, hotbarAssignments[index])
	slot.Number.Text = tostring(index % 10)
end

local function updateInventoryVisuals()
	local selectedItem = hotbarAssignments[selected]
	local anyVisible = false

	for i, buttonObject in ipairs(inventoryButtons) do
		local item = inventory[i]
		local count = ownedCounts[item.blockName] or 0
		local visible = count > 0
		buttonObject.Visible = visible
		anyVisible = anyVisible or visible
		buttonObject.BackgroundColor3 = selectedItem and item.blockName == selectedItem.blockName
			and Color3.fromRGB(238, 238, 238)
			or Color3.fromRGB(138, 138, 138)

		local label = buttonObject:FindFirstChild("Label")
		if label then
			label.Text = string.format("%s x%d", item.title, count)
		end
	end

	inventoryTitle.Text = anyVisible and "Inventory" or "Inventory is empty"
end

local function assignBlockToHotbar(blockName)
	local item = INVENTORY_BY_BLOCK[blockName]
	if not item then
		return
	end

	for _, assigned in pairs(hotbarAssignments) do
		if assigned and assigned.blockName == blockName then
			return
		end
	end

	for i = 1, HOTBAR_SLOT_COUNT do
		if not hotbarAssignments[i] then
			hotbarAssignments[i] = item
			if not hotbarAssignments[selected] then
				selected = i
			end
			return
		end
	end
end

local function refreshUI()
	for slotIndex, item in pairs(hotbarAssignments) do
		if item and (ownedCounts[item.blockName] or 0) <= 0 then
			hotbarAssignments[slotIndex] = nil
		end
	end

	for i = 1, HOTBAR_SLOT_COUNT do
		updateSlotVisual(i)
	end
	updateInventoryVisuals()
end

local function updateHearts(humanoid)
	if not humanoid then
		for _, heart in ipairs(hearts) do
			heart.TextColor3 = Color3.fromRGB(55, 55, 55)
			heart.TextStrokeColor3 = Color3.fromRGB(10, 10, 10)
		end
		return
	end

	local maxHealth = math.max(1, humanoid.MaxHealth)
	local filled = math.ceil(math.clamp(humanoid.Health / maxHealth, 0, 1) * #hearts)
	for i, heart in ipairs(hearts) do
		if i <= filled then
			heart.TextColor3 = Color3.fromRGB(210, 28, 28)
			heart.TextStrokeColor3 = Color3.fromRGB(55, 0, 0)
		else
			heart.TextColor3 = Color3.fromRGB(55, 55, 55)
			heart.TextStrokeColor3 = Color3.fromRGB(10, 10, 10)
		end
	end
end

local function setSelected(index)
	if index >= 1 and index <= HOTBAR_SLOT_COUNT then
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
	for i = 1, HOTBAR_SLOT_COUNT do
		local slot = Instance.new("Frame")
		slot.Size = UDim2.new(0, 50, 0, 50)
		slot.Position = UDim2.new(0, 5 + (i - 1) * 55, 0, 5)
		slot.BorderSizePixel = 0
		slot.Parent = hotbar
		corner(slot, 0)
		stroke(slot, Color3.fromRGB(28, 28, 28), 0, 2)

		local image = Instance.new("ImageLabel")
		image.Name = "Image"
		image.Size = UDim2.new(1, -10, 1, -10)
		image.Position = UDim2.new(0, 5, 0, 5)
		image.BackgroundTransparency = 1
		image.ScaleType = Enum.ScaleType.Fit
		image.BorderSizePixel = 0
		image.Parent = slot

		local num = Instance.new("TextLabel")
		num.Name = "Number"
		num.Size = UDim2.new(0, 16, 0, 16)
		num.Position = UDim2.new(0, 2, 0, 0)
		num.BackgroundTransparency = 1
		num.TextColor3 = Color3.new(1, 1, 1)
		num.Font = Enum.Font.Arcade
		num.TextSize = 14
		num.Parent = slot

		hotbarSlots[i] = slot
	end
end

local function buildInventory()
	for i, item in ipairs(inventory) do
		local btn = Instance.new("TextButton")
		btn.LayoutOrder = i
		btn.BorderSizePixel = 0
		btn.BackgroundColor3 = Color3.fromRGB(138, 138, 138)
		btn.Text = ""
		btn.Parent = inventoryGrid
		corner(btn, 0)
		stroke(btn, Color3.fromRGB(65, 65, 65), 0, 2)

		local image = Instance.new("ImageLabel")
		image.Size = UDim2.new(1, -16, 1, -34)
		image.Position = UDim2.new(0, 8, 0, 6)
		image.BackgroundTransparency = 1
		image.ScaleType = Enum.ScaleType.Fit
		image.BorderSizePixel = 0
		applyItemIcon(image, item)
		image.Parent = btn

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.new(1, -8, 0, 22)
		label.Position = UDim2.new(0, 4, 1, -24)
		label.BackgroundTransparency = 1
		label.Text = item.title
		label.TextColor3 = Color3.fromRGB(40, 40, 40)
		label.Font = Enum.Font.Arcade
		label.TextSize = 16
		label.TextWrapped = true
		label.Parent = btn

		btn.MouseButton1Click:Connect(function()
			if (ownedCounts[item.blockName] or 0) <= 0 then
				return
			end

			hotbarAssignments[selected] = item
			refreshUI()
		end)

		inventoryButtons[i] = btn
	end
end

inventoryLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	local size = inventoryLayout.AbsoluteContentSize
	inventoryGrid.CanvasSize = UDim2.new(0, 0, 0, size.Y + 12)
end)

if InventorySync then
	InventorySync.OnClientEvent:Connect(function(counts, changedBlockName)
		ownedCounts = {}
		if type(counts) == "table" then
			for blockName, count in pairs(counts) do
				if INVENTORY_BY_BLOCK[blockName] and type(count) == "number" and count > 0 then
					ownedCounts[blockName] = math.floor(count)
				end
			end
		end
		if changedBlockName and (ownedCounts[changedBlockName] or 0) > 0 then
			assignBlockToHotbar(changedBlockName)
		end
		refreshUI()
	end)
end

buildHotbar()
buildInventory()
refreshUI()

if player.Character then
	clearCharacterSounds(player.Character)
end

player.CharacterAdded:Connect(function(character)
	clearCharacterSounds(character)

	character:WaitForChild("Humanoid", 5)
	character:WaitForChild("HumanoidRootPart", 5)
	attachCamera(character)
end)

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	if player.Character then
		attachCamera(player.Character)
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
	elseif input.KeyCode == Enum.KeyCode.Backspace then
		if controlsEnabled() then
			hotbarAssignments[selected] = nil
			refreshUI()
		end
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

	local item = hotbarAssignments[selected]
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
		heartBar.Visible = false
		inventoryFrame.Visible = false
		inventoryOpen = false
		swimUpHeld = false
		activeLiquid = nil
		updateLocalWaterVisibility(player.Character, hrp, nil)
		player:SetAttribute("InventoryOpen", false)
		UserInputService.MouseIconEnabled = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 12

		if isCrouching then
			isCrouching = false
			SetCrouchState:FireServer(false)
		end

		if humanoid then
			humanoid.WalkSpeed = normalWalkSpeed
			applyJumpSettings(humanoid, normalJumpPower, normalJumpHeight)
		end

		return
	end

	hotbar.Visible = true
	heartBar.Visible = true
	crosshair.Visible = not inventoryOpen
	inventoryFrame.Visible = inventoryOpen
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 0.5

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
		updateHearts(humanoid)

		if not camera or camera ~= Workspace.CurrentCamera or camera.CameraSubject ~= humanoid or camera.CameraType ~= Enum.CameraType.Custom then
			attachCamera(player.Character)
		end
	else
		updateHearts(nil)
	end

	if humanoid and hrp then
		local liquidInfo = getCharacterLiquid(player.Character, hrp)
		local isSwimming = applySwimming(humanoid, hrp, liquidInfo)
		updateLocalWaterVisibility(player.Character, hrp, liquidInfo)

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
