local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local terrain = Workspace:FindFirstChildOfClass("Terrain")

Lighting.Brightness = 2.2
Lighting.ClockTime = 13.5
Lighting.GeographicLatitude = 18
Lighting.Ambient = Color3.fromRGB(104, 118, 138)
Lighting.OutdoorAmbient = Color3.fromRGB(138, 154, 176)
Lighting.FogColor = Color3.fromRGB(188, 210, 224)
Lighting.FogStart = 130
Lighting.FogEnd = 520

local atmosphere = Lighting:FindFirstChild("AlphaAtmosphere")
if not atmosphere then
	atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "AlphaAtmosphere"
	atmosphere.Parent = Lighting
end

atmosphere.Density = 0.24
atmosphere.Offset = 0.08
atmosphere.Color = Color3.fromRGB(205, 224, 236)
atmosphere.Decay = Color3.fromRGB(110, 138, 190)
atmosphere.Glare = 0.08
atmosphere.Haze = 1.45

if terrain then
	local clouds = terrain:FindFirstChild("AlphaClouds")
	if not clouds then
		clouds = Instance.new("Clouds")
		clouds.Name = "AlphaClouds"
		clouds.Parent = terrain
	end

	clouds.Cover = 0.42
	clouds.Density = 0.18
	clouds.Color = Color3.fromRGB(244, 246, 248)
end
