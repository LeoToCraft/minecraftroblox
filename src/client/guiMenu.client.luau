local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local rmtGame = ReplicatedStorage:WaitForChild("rmtGame")
local guiAssets = ReplicatedStorage:WaitForChild("guiAssets")

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
local CommandFeedback = rmtGame:WaitForChild("CommandFeedback", 5)

local versionText = "0.0.14a"

local backgroundAsset = guiAssets:WaitForChild("gui"):WaitForChild("gui_menu")

local function getImage(asset)
	if asset:IsA("ImageLabel") or asset:IsA("ImageButton") then
		return asset.Image
	end
	if asset:IsA("Decal") or asset:IsA("Texture") then
		return asset.Texture
	end
	local dec = asset:FindFirstChildWhichIsA("Decal", true)
	if dec then
		return dec.Texture
	end 
	local tex = asset:FindFirstChildWhichIsA("Texture", true)
	if tex then
		return tex.Texture
	end
	return ""
end

local screen = Instance.new("ScreenGui")
screen.Name = "guiMenuUI"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.Parent = playerGui

local root = Instance.new("Frame")
root.Size = UDim2.new(1, 0, 1, 0)
root.BackgroundTransparency = 1
root.Parent = screen

if CommandFeedback then
	CommandFeedback.OnClientEvent:Connect(function(message)
		task.defer(function()
			pcall(function()
				StarterGui:SetCore("ChatMakeSystemMessage", {
					Text = tostring(message),
					Color = Color3.fromRGB(235, 235, 235),
					Font = Enum.Font.Arcade,
					TextSize = 18,
				})
			end)
		end)
	end)
end

local bg = Instance.new("ImageLabel")
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundTransparency = 1
bg.ScaleType = Enum.ScaleType.Stretch
bg.Image = getImage(backgroundAsset)
bg.Parent = root

local shade = Instance.new("Frame")
shade.Size = UDim2.new(1, 0, 1, 0)
shade.BackgroundColor3 = Color3.new(0, 0, 0)
shade.BackgroundTransparency = 0.35
shade.BorderSizePixel = 0
shade.Parent = root

local function corner(instance, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 0)
	c.Parent = instance
	return c
end

local function stroke(instance, color, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(235, 235, 235)
	s.Transparency = transparency or 0.35
	s.Thickness = thickness or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = instance
	return s
end

local function text(parent, value, size, position, textSize, alignX)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = size
	t.Position = position
	t.Text = value
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeColor3 = Color3.new(0, 0, 0)
	t.TextStrokeTransparency = 0.35
	t.Font = Enum.Font.Arcade
	t.TextSize = textSize
	t.TextXAlignment = alignX or Enum.TextXAlignment.Center
	t.TextWrapped = true
	t.Parent = parent
	return t
end

local function button(parent, value, size, position)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = position
	b.BackgroundColor3 = Color3.fromRGB(118, 118, 118)
	b.BorderSizePixel = 0
	b.Text = value
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextStrokeColor3 = Color3.new(0, 0, 0)
	b.TextStrokeTransparency = 0.2
	b.Font = Enum.Font.Arcade
	b.TextSize = 20
	b.TextWrapped = true
	b:SetAttribute("BaseColor", b.BackgroundColor3)
	b.Parent = parent
	corner(b, 0)
	stroke(b, Color3.fromRGB(15, 15, 15), 0, 2)
	b.MouseEnter:Connect(function()
		if b.Active ~= false then
			b.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
		end
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = b:GetAttribute("BaseColor") or Color3.fromRGB(118, 118, 118)
	end)
	return b
end

local function setButtonBaseColor(buttonObject, color)
	buttonObject.BackgroundColor3 = color
	buttonObject:SetAttribute("BaseColor", color)
end

local function panel(parent, size, position)
	local p = Instance.new("Frame")
	p.Size = size
	p.Position = position
	p.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
	p.BackgroundTransparency = 1
	p.BorderSizePixel = 0
	p.Visible = false
	p.Parent = parent
	corner(p, 0)
	return p
end

local title = text(root, "Minecraft: Roblox Edition", UDim2.new(0, 760, 0, 80), UDim2.new(0.5, -380, 0, 40), 40)
local version = text(root, versionText, UDim2.new(0, 240, 0, 24), UDim2.new(1, -250, 1, -35), 18, Enum.TextXAlignment.Right)

local homeFrame = Instance.new("Frame")
homeFrame.Size = UDim2.new(0, 380, 0, 200)
homeFrame.Position = UDim2.new(0.5, -190, 0, 150)
homeFrame.BackgroundTransparency = 1
homeFrame.Parent = root

local btnSingle = button(homeFrame, "Singleplayer", UDim2.new(0, 360, 0, 40), UDim2.new(0.5, -180, 0, 0))
local btnMulti = button(homeFrame, "Multiplayer", UDim2.new(0, 360, 0, 40), UDim2.new(0.5, -180, 0, 58))
local btnSettings = button(homeFrame, "Settings", UDim2.new(0, 360, 0, 40), UDim2.new(0.5, -180, 0, 116))

local worldsPanel = panel(root, UDim2.new(0, 860, 0, 500), UDim2.new(0.5, -430, 0, 130))
local multiPanel = panel(root, UDim2.new(0, 860, 0, 500), UDim2.new(0.5, -430, 0, 130))
local settingsPanel = panel(root, UDim2.new(0, 860, 0, 400), UDim2.new(0.5, -430, 0, 150))
local loadingPanel = panel(root, UDim2.new(0, 760, 0, 230), UDim2.new(0.5, -380, 0.5, -115))
loadingPanel.Visible = false

local pauseRoot = Instance.new("Frame")
pauseRoot.Size = UDim2.new(1, 0, 1, 0)
pauseRoot.BackgroundColor3 = Color3.new(0, 0, 0)
pauseRoot.BackgroundTransparency = 0.35
pauseRoot.BorderSizePixel = 0
pauseRoot.Visible = false
pauseRoot.Parent = screen

local pausePanel = panel(pauseRoot, UDim2.new(0, 460, 0, 280), UDim2.new(0.5, -230, 0.5, -140))
pausePanel.Visible = true

local debugLabel = Instance.new("TextLabel")
debugLabel.Size = UDim2.new(0, 260, 0, 60)
debugLabel.Position = UDim2.new(0, 10, 1, -70)
debugLabel.BackgroundTransparency = 1
debugLabel.TextColor3 = Color3.new(1, 1, 1)
debugLabel.TextStrokeTransparency = 0.65
debugLabel.TextXAlignment = Enum.TextXAlignment.Left
debugLabel.TextYAlignment = Enum.TextYAlignment.Bottom
debugLabel.Font = Enum.Font.SourceSansBold
debugLabel.TextSize = 18
debugLabel.Visible = false
debugLabel.Parent = screen

text(pausePanel, "Game menu", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 16), 28)
local pauseBack = button(pausePanel, "Back to game", UDim2.new(0, 320, 0, 36), UDim2.new(0.5, -160, 0, 70))
local pauseSettings = button(pausePanel, "Settings", UDim2.new(0, 320, 0, 36), UDim2.new(0.5, -160, 0, 118))
local pauseHost = button(pausePanel, "Host server", UDim2.new(0, 320, 0, 36), UDim2.new(0.5, -160, 0, 166))
local pauseQuit = button(pausePanel, "Save world and quit", UDim2.new(0, 320, 0, 36), UDim2.new(0.5, -160, 0, 214))

text(worldsPanel, "Worlds", UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 0, 20), 30)
local worldsJoin = button(worldsPanel, "Join to world", UDim2.new(0, 150, 0, 38), UDim2.new(0, 40, 0, 438))
local worldsCreate = button(worldsPanel, "Create new world", UDim2.new(0, 160, 0, 38), UDim2.new(0, 205, 0, 438))
local worldsRecreate = button(worldsPanel, "Re-create world", UDim2.new(0, 160, 0, 38), UDim2.new(0, 380, 0, 438))
local worldsRename = button(worldsPanel, "Rename world", UDim2.new(0, 130, 0, 38), UDim2.new(0, 555, 0, 438))
local worldsDelete = button(worldsPanel, "Delete world", UDim2.new(0, 130, 0, 38), UDim2.new(0, 700, 0, 438))
local worldsBack = button(worldsPanel, "Back", UDim2.new(0, 120, 0, 38), UDim2.new(1, -160, 0, 394))

local renameBox = Instance.new("TextBox")
renameBox.Size = UDim2.new(0, 220, 0, 36)
renameBox.Position = UDim2.new(1, -260, 0, 394)
renameBox.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
renameBox.TextColor3 = Color3.new(1, 1, 1)
renameBox.BorderSizePixel = 0
renameBox.Font = Enum.Font.Arcade
renameBox.TextSize = 20
renameBox.ClearTextOnFocus = false
renameBox.PlaceholderText = "New name"
renameBox.PlaceholderColor3 = Color3.fromRGB(170, 170, 170)
renameBox.Parent = worldsPanel
corner(renameBox, 0)
stroke(renameBox, Color3.fromRGB(0, 0, 0), 0, 2)

local createPanel = panel(worldsPanel, UDim2.new(0, 780, 0, 300), UDim2.new(0, 40, 0, 74))
createPanel.Visible = false
text(createPanel, "Create world", UDim2.new(1, 0, 0, 34), UDim2.new(0, 0, 0, 12), 26)
text(createPanel, "Name", UDim2.new(0, 160, 0, 28), UDim2.new(0, 50, 0, 66), 18, Enum.TextXAlignment.Left)
text(createPanel, "Seed", UDim2.new(0, 160, 0, 28), UDim2.new(0, 50, 0, 118), 18, Enum.TextXAlignment.Left)

local createNameBox = Instance.new("TextBox")
createNameBox.Size = UDim2.new(0, 420, 0, 34)
createNameBox.Position = UDim2.new(0, 200, 0, 62)
createNameBox.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
createNameBox.TextColor3 = Color3.new(1, 1, 1)
createNameBox.BorderSizePixel = 0
createNameBox.Font = Enum.Font.Arcade
createNameBox.TextSize = 18
createNameBox.ClearTextOnFocus = false
createNameBox.PlaceholderText = "New World"
createNameBox.PlaceholderColor3 = Color3.fromRGB(170, 170, 170)
createNameBox.Parent = createPanel
stroke(createNameBox, Color3.fromRGB(0, 0, 0), 0, 2)

local createSeedBox = Instance.new("TextBox")
createSeedBox.Size = UDim2.new(0, 420, 0, 34)
createSeedBox.Position = UDim2.new(0, 200, 0, 114)
createSeedBox.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
createSeedBox.TextColor3 = Color3.new(1, 1, 1)
createSeedBox.BorderSizePixel = 0
createSeedBox.Font = Enum.Font.Arcade
createSeedBox.TextSize = 18
createSeedBox.ClearTextOnFocus = false
createSeedBox.PlaceholderText = "Random"
createSeedBox.PlaceholderColor3 = Color3.fromRGB(170, 170, 170)
createSeedBox.Parent = createPanel
stroke(createSeedBox, Color3.fromRGB(0, 0, 0), 0, 2)

local worldSizeButton = button(createPanel, "Size: Large", UDim2.new(0, 180, 0, 36), UDim2.new(0, 200, 0, 166))
local worldTypeButton = button(createPanel, "Type: Normal", UDim2.new(0, 180, 0, 36), UDim2.new(0, 400, 0, 166))
local createConfirm = button(createPanel, "Create", UDim2.new(0, 170, 0, 38), UDim2.new(0, 200, 0, 232))
local createCancel = button(createPanel, "Cancel", UDim2.new(0, 170, 0, 38), UDim2.new(0, 410, 0, 232))

text(multiPanel, "Multiplayer", UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 0, 20), 30)
local multiBack = button(multiPanel, "Back", UDim2.new(0, 120, 0, 38), UDim2.new(1, -160, 0, 438))
local multiJoin = button(multiPanel, "Join", UDim2.new(0, 200, 0, 38), UDim2.new(0, 40, 0, 438))

text(settingsPanel, "Settings", UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 0, 20), 30)
local settingsBack = button(settingsPanel, "Back", UDim2.new(0, 120, 0, 38), UDim2.new(0.5, -60, 0, 330))
local graphicsMinus = button(settingsPanel, "-", UDim2.new(0, 60, 0, 40), UDim2.new(0, 50, 0, 130))
local graphicsPlus = button(settingsPanel, "+", UDim2.new(0, 60, 0, 40), UDim2.new(0, 126, 0, 130))
local debugToggle = button(settingsPanel, "ON", UDim2.new(0, 140, 0, 40), UDim2.new(1, -190, 0, 220))
text(settingsPanel, "Graphics", UDim2.new(0, 400, 0, 40), UDim2.new(0, 50, 0, 80), 28, Enum.TextXAlignment.Left)
local graphicsValue = text(settingsPanel, "Medium", UDim2.new(0, 160, 0, 40), UDim2.new(0, 620, 0, 80), 24, Enum.TextXAlignment.Right)
text(settingsPanel, "DEBUG-UI", UDim2.new(0, 400, 0, 40), UDim2.new(0, 50, 0, 220), 28, Enum.TextXAlignment.Left)

local barBg = Instance.new("Frame")
barBg.Size = UDim2.new(0, 520, 0, 28)
barBg.Position = UDim2.new(0.5, -260, 0, 70)
barBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
barBg.BorderSizePixel = 0
barBg.Parent = loadingPanel
corner(barBg, 0)
stroke(barBg, Color3.fromRGB(0, 0, 0), 0, 2)

local barFill = Instance.new("Frame")
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(128, 255, 128)
barFill.BorderSizePixel = 0
barFill.Parent = barBg
corner(barFill, 0)

local percentText = text(loadingPanel, "0%", UDim2.new(0, 520, 0, 34), UDim2.new(0.5, -260, 0, 112), 30)
text(loadingPanel, "Loading World", UDim2.new(0, 520, 0, 30), UDim2.new(0.5, -260, 0, 152), 24)

local selectedWorldSlot = nil
local selectedServer = nil
local worldButtons = {}
local serverButtons = {}
local cachedWorlds = {}
local cachedServers = {}
local selectedWorldSize = "Large"
local selectedWorldType = "Normal"
local createTargetSlot = nil
local createOverwrite = false
local currentGraphics = 2
local currentShowDebug = true
local fpsFrames = 0
local fpsLast = tick()
local fpsValue = 0

local function setPercent(value)
	value = math.clamp(math.floor(value + 0.5), 0, 100)
	barFill.Size = UDim2.new(value / 100, 0, 1, 0)
	percentText.Text = tostring(value) .. "%"
end

local function freeMouse()
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

local closeCreateWorld

local function showHome()
	if closeCreateWorld then
		closeCreateWorld()
	end
	root.Visible = true
	homeFrame.Visible = true
	worldsPanel.Visible = false
	multiPanel.Visible = false
	settingsPanel.Visible = false
	loadingPanel.Visible = false
	pauseRoot.Visible = false
	freeMouse()
end

local function showWorlds()
	root.Visible = true
	homeFrame.Visible = false
	worldsPanel.Visible = true
	multiPanel.Visible = false
	settingsPanel.Visible = false
	loadingPanel.Visible = false
	pauseRoot.Visible = false
	freeMouse()
end

local function showMulti()
	if closeCreateWorld then
		closeCreateWorld()
	end
	root.Visible = true
	homeFrame.Visible = false
	worldsPanel.Visible = false
	multiPanel.Visible = true
	settingsPanel.Visible = false
	loadingPanel.Visible = false
	pauseRoot.Visible = false
	freeMouse()
end

local function showSettings(fromPause)
	if closeCreateWorld then
		closeCreateWorld()
	end
	root.Visible = true
	homeFrame.Visible = false
	worldsPanel.Visible = false
	multiPanel.Visible = false
	settingsPanel.Visible = true
	loadingPanel.Visible = false
	pauseRoot.Visible = false
	settingsPanel:SetAttribute("FromPause", fromPause == true)
	freeMouse()
end

local function showLoading()
	root.Visible = true
	homeFrame.Visible = false
	worldsPanel.Visible = false
	multiPanel.Visible = false
	settingsPanel.Visible = false
	loadingPanel.Visible = true
	pauseRoot.Visible = false
	freeMouse()
end

local function hideAllMenu()
	root.Visible = false
	pauseRoot.Visible = false
end

local function syncWorldScreen()
	if player:GetAttribute("WorldLoading") == true then
		showLoading()
		setPercent(player:GetAttribute("WorldLoadProgress") or 0)
	elseif player:GetAttribute("WorldLoaded") == true and player:GetAttribute("InMenu") ~= true then
		hideAllMenu()
	elseif player:GetAttribute("InMenu") == true then
		showHome()
	end
end

local function showPause()
	if player:GetAttribute("WorldLoaded") ~= true then
		return
	end
	player:SetAttribute("Paused", true)
	pauseRoot.Visible = true
	root.Visible = false
	freeMouse()
end

local function closePause()
	player:SetAttribute("Paused", false)
	hideAllMenu()
end

local function refreshSettingsText()
	if currentGraphics <= 1 then
		graphicsValue.Text = "Low"
	elseif currentGraphics == 2 then
		graphicsValue.Text = "Medium"
	else
		graphicsValue.Text = "High"
	end

	debugToggle.Text = currentShowDebug and "ON" or "OFF"
end

local worldSizeOrder = { "Small", "Medium", "Large", "Huge" }
local worldTypeOrder = { "Normal", "Superflat" }

local function refreshWorldSizeText()
	worldSizeButton.Text = "Size: " .. selectedWorldSize
end

local function refreshWorldTypeText()
	worldTypeButton.Text = "Type: " .. selectedWorldType
end

local function cycleWorldSize()
	for index, sizeName in ipairs(worldSizeOrder) do
		if sizeName == selectedWorldSize then
			selectedWorldSize = worldSizeOrder[(index % #worldSizeOrder) + 1]
			refreshWorldSizeText()
			return
		end
	end

	selectedWorldSize = "Large"
	refreshWorldSizeText()
end

local function cycleWorldType()
	for index, typeName in ipairs(worldTypeOrder) do
		if typeName == selectedWorldType then
			selectedWorldType = worldTypeOrder[(index % #worldTypeOrder) + 1]
			refreshWorldTypeText()
			return
		end
	end

	selectedWorldType = "Normal"
	refreshWorldTypeText()
end

local function setWorldButtonState(buttonObject, enabled)
	buttonObject.Active = enabled
	buttonObject.AutoButtonColor = enabled
	setButtonBaseColor(buttonObject, enabled and Color3.fromRGB(118, 118, 118) or Color3.fromRGB(54, 54, 54))
end

local function refreshWorldActionButtons()
	local hasSelection = selectedWorldSlot ~= nil
	local data = hasSelection and cachedWorlds[selectedWorldSlot] or nil
	local createOpen = createPanel.Visible == true

	worldsJoin.Visible = not createOpen
	worldsCreate.Visible = not createOpen
	worldsRecreate.Visible = not createOpen
	worldsRename.Visible = not createOpen
	worldsDelete.Visible = not createOpen
	worldsBack.Visible = not createOpen
	renameBox.Visible = not createOpen and data ~= nil

	setWorldButtonState(worldsJoin, not createOpen and data ~= nil)
	setWorldButtonState(worldsCreate, not createOpen and hasSelection)
	setWorldButtonState(worldsRecreate, not createOpen and data ~= nil)
	setWorldButtonState(worldsRename, not createOpen and data ~= nil)
	setWorldButtonState(worldsDelete, not createOpen and data ~= nil)

	for _, buttonObject in pairs(worldButtons) do
		buttonObject.Visible = not createOpen
	end
end

local function openCreateWorld(overwrite)
	if not selectedWorldSlot then
		return
	end

	createTargetSlot = selectedWorldSlot
	createOverwrite = overwrite == true
	local data = cachedWorlds[selectedWorldSlot]
	createNameBox.Text = data and tostring(data.Name) or "New World"
	createSeedBox.Text = ""
	createConfirm.Text = createOverwrite and "Re-create" or "Create"
	createPanel.Visible = true
	refreshWorldActionButtons()
end

closeCreateWorld = function()
	createPanel.Visible = false
	createTargetSlot = nil
	createOverwrite = false
	refreshWorldActionButtons()
end

local function clearDynamic(container, fixed)
	for _, obj in ipairs(container:GetChildren()) do
		if not fixed[obj] then
			obj:Destroy()
		end
	end
end

local worldsFixed = {
	[renameBox] = true,
}
for _, obj in ipairs(worldsPanel:GetChildren()) do
	worldsFixed[obj] = true
end

local multiFixed = {}
for _, obj in ipairs(multiPanel:GetChildren()) do
	multiFixed[obj] = true
end

local function rebuildWorldList()
	clearDynamic(worldsPanel, worldsFixed)
	worldButtons = {}

	for slot = 1, 3 do
		local data = cachedWorlds[slot]
		local y = 74 + (slot - 1) * 96
		local titleText = "Empty"

		if data then
			titleText = string.format("%s [%sx%s | %s]", tostring(data.Name), tostring(data.Width), tostring(data.Depth), tostring(data.WorldType))
		end

		local btn = button(worldsPanel, titleText, UDim2.new(0, 780, 0, 64), UDim2.new(0, 40, 0, y))
		btn.TextSize = 22
		setButtonBaseColor(btn, selectedWorldSlot == slot and Color3.fromRGB(165, 165, 165) or Color3.fromRGB(100, 100, 100))

		btn.MouseButton1Click:Connect(function()
			if selectedWorldSlot == slot and data then
				showLoading()
				setPercent(10)
				local result = LoadWorld:InvokeServer(slot)
				if result and result.Success then
					setPercent(100)
				else
					showWorlds()
				end
				return
			end

			selectedWorldSlot = slot
			renameBox.Text = data and tostring(data.Name) or ""
			closeCreateWorld()
			rebuildWorldList()
		end)

		worldButtons[slot] = btn
	end

	refreshWorldActionButtons()
end

local function rebuildServerList()
	clearDynamic(multiPanel, multiFixed)
	serverButtons = {}

	for index, data in ipairs(cachedServers) do
		local y = 74 + (index - 1) * 72
		local labelText = tostring(data.ServerName) .. " - " .. tostring(data.OwnerName)
		if data.HasPassword then
			labelText = labelText .. " [Password]"
		end

		local btn = button(multiPanel, labelText, UDim2.new(0, 780, 0, 56), UDim2.new(0, 40, 0, y))
		btn.TextSize = 22
		setButtonBaseColor(btn, selectedServer == index and Color3.fromRGB(165, 165, 165) or Color3.fromRGB(100, 100, 100))

		btn.MouseButton1Click:Connect(function()
			selectedServer = index
			rebuildServerList()
		end)

		serverButtons[index] = btn
	end
end

local function refreshWorldData()
	local response = RequestWorldList:InvokeServer()
	cachedWorlds = response and response.Worlds or {}
	local settings = response and response.Settings or {}
	currentGraphics = tonumber(settings.Graphics) or 2
	currentShowDebug = settings.ShowDebugUI ~= false
	refreshSettingsText()
	rebuildWorldList()
end

local function refreshServers()
	local response = RequestServerList:InvokeServer()
	cachedServers = response and response.Servers or {}
	selectedServer = nil
	rebuildServerList()
end

btnSingle.MouseButton1Click:Connect(function()
	refreshWorldData()
	showWorlds()
end)

btnMulti.MouseButton1Click:Connect(function()
	refreshServers()
	showMulti()
end)

btnSettings.MouseButton1Click:Connect(function()
	refreshWorldData()
	showSettings(false)
end)

worldsBack.MouseButton1Click:Connect(function()
	showHome()
end)

multiBack.MouseButton1Click:Connect(function()
	showHome()
end)

settingsBack.MouseButton1Click:Connect(function()
	local fromPause = settingsPanel:GetAttribute("FromPause") == true
	if fromPause then
		showPause()
	else
		showHome()
	end
end)

worldsJoin.MouseButton1Click:Connect(function()
	if not selectedWorldSlot or not cachedWorlds[selectedWorldSlot] then
		return
	end

	showLoading()
	setPercent(10)
	local result = LoadWorld:InvokeServer(selectedWorldSlot)
	if result and result.Success then
		setPercent(100)
	else
		showWorlds()
	end
end)

worldsCreate.MouseButton1Click:Connect(function()
	if not selectedWorldSlot then
		return
	end
	openCreateWorld(false)
end)

worldsRecreate.MouseButton1Click:Connect(function()
	if not selectedWorldSlot or not cachedWorlds[selectedWorldSlot] then
		return
	end
	openCreateWorld(true)
end)

worldSizeButton.MouseButton1Click:Connect(function()
	cycleWorldSize()
end)

worldTypeButton.MouseButton1Click:Connect(function()
	cycleWorldType()
end)

createConfirm.MouseButton1Click:Connect(function()
	if not createTargetSlot then
		return
	end

	local worldName = createNameBox.Text
	if worldName == "" then
		worldName = "New World"
	end

	CreateWorld:InvokeServer(createTargetSlot, worldName, selectedWorldSize, selectedWorldType, createSeedBox.Text)
	selectedWorldSlot = createTargetSlot
	closeCreateWorld()
	refreshWorldData()
end)

createCancel.MouseButton1Click:Connect(function()
	closeCreateWorld()
end)

worldsDelete.MouseButton1Click:Connect(function()
	if not selectedWorldSlot then
		return
	end
	DeleteWorld:InvokeServer(selectedWorldSlot)
	selectedWorldSlot = nil
	renameBox.Text = ""
	refreshWorldData()
end)

worldsRename.MouseButton1Click:Connect(function()
	if not selectedWorldSlot then
		return
	end
	RenameWorld:InvokeServer(selectedWorldSlot, renameBox.Text)
	refreshWorldData()
end)

multiJoin.MouseButton1Click:Connect(function()
	if not selectedServer then
		return
	end

	local data = cachedServers[selectedServer]
	if not data then
		return
	end

	showLoading()
	setPercent(10)
	local result = JoinHostedServer:InvokeServer(data.OwnerUserId, "")
	if result and result.Success then
		setPercent(100)
	else
		showMulti()
	end
end)

graphicsMinus.MouseButton1Click:Connect(function()
	currentGraphics = math.max(1, currentGraphics - 1)
	UpdateSettings:InvokeServer(currentGraphics, currentShowDebug)
	refreshSettingsText()
end)

graphicsPlus.MouseButton1Click:Connect(function()
	currentGraphics = math.min(3, currentGraphics + 1)
	UpdateSettings:InvokeServer(currentGraphics, currentShowDebug)
	refreshSettingsText()
end)

debugToggle.MouseButton1Click:Connect(function()
	currentShowDebug = not currentShowDebug
	UpdateSettings:InvokeServer(currentGraphics, currentShowDebug)
	refreshSettingsText()
end)

pauseBack.MouseButton1Click:Connect(function()
	closePause()
end)

pauseSettings.MouseButton1Click:Connect(function()
	refreshWorldData()
	showSettings(true)
end)

pauseHost.MouseButton1Click:Connect(function()
	HostCurrentWorld:InvokeServer()
end)

pauseQuit.MouseButton1Click:Connect(function()
	local result = SaveAndQuitWorld:InvokeServer()
	if result and result.Success then
		showHome()
	end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then
		return
	end

	if input.KeyCode == Enum.KeyCode.CapsLock then
		if player:GetAttribute("InMenu") == true then
			return
		end

		if player:GetAttribute("Paused") == true then
			closePause()
		else
			showPause()
		end
	end
end)

player:GetAttributeChangedSignal("WorldLoaded"):Connect(function()
	syncWorldScreen()
end)

player:GetAttributeChangedSignal("WorldLoading"):Connect(function()
	syncWorldScreen()
end)

player:GetAttributeChangedSignal("InMenu"):Connect(function()
	syncWorldScreen()
end)

player:GetAttributeChangedSignal("WorldLoadProgress"):Connect(function()
	if player:GetAttribute("WorldLoading") == true then
		setPercent(player:GetAttribute("WorldLoadProgress") or 0)
	end
end)

task.spawn(function()
	for _ = 1, 20 do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)
		task.wait(0.25)
	end
end)

RunService.RenderStepped:Connect(function()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)

	local debugEnabled = player:GetAttribute("ShowDebugUI") ~= false
	local inWorld = player:GetAttribute("WorldLoaded") == true
	debugLabel.Visible = debugEnabled and inWorld

	fpsFrames += 1
	if tick() - fpsLast >= 1 then
		fpsValue = fpsFrames
		fpsFrames = 0
		fpsLast = tick()
	end

	debugLabel.Text = "FPS: " .. tostring(fpsValue) .. "\n" .. versionText
end)

refreshWorldData()

syncWorldScreen()
