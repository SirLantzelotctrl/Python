-- HUD: Stardust, daño por golpe, zona actual, menú, radar de meteoritos,
-- cuenta atrás del cometa, eventos, boosts y pistas para jugadores nuevos.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Config = require(Shared:WaitForChild("Config"))
local Zones = require(Shared:WaitForChild("Zones"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local Critters = require(Shared:WaitForChild("Critters"))
local Economy = require(Shared:WaitForChild("Economy"))

local Modules = script.Parent.Parent.Modules
local UI = require(Modules.UI)
local State = require(Modules.State)

local Windows = require(script.Parent.Windows)

local HUD = {}

local player = Players.LocalPlayer

local stardustLabel: TextLabel
local damageLabel: TextLabel
local zoneLabel: TextLabel
local infoLabels: { TextLabel } = {}
local radarRows: { { Frame: Frame, Arrow: TextLabel, Text: TextLabel } } = {}
local hintPanel: Frame
local hintLabel: TextLabel
local badges: { [string]: Frame } = {}
local displayed = 0

local MENU = {
	{ Name = "Shop", Icon = "⛏️", Label = "Shop", Color = UI.Colors.Green },
	{ Name = "Critters", Icon = "🐾", Label = "Critters", Color = UI.Colors.Orange },
	{ Name = "Zones", Icon = "🗺️", Label = "Zones", Color = UI.Colors.Blue },
	{ Name = "Quests", Icon = "📜", Label = "Quests", Color = UI.Colors.Yellow },
	{ Name = "Rebirth", Icon = "🌟", Label = "Supernova", Color = UI.Colors.Pink },
	{ Name = "Index", Icon = "📖", Label = "Index", Color = UI.Colors.Purple },
	{ Name = "Store", Icon = "💎", Label = "Store", Color = Color3.fromRGB(255, 80, 150) },
	{ Name = "Gifts", Icon = "🎁", Label = "Gifts", Color = Color3.fromRGB(255, 120, 60) },
	{ Name = "Daily", Icon = "📅", Label = "Daily", Color = UI.Colors.Cyan },
	{ Name = "Codes", Icon = "🎟️", Label = "Codes", Color = Color3.fromRGB(120, 130, 255) },
}

function HUD.SetBadge(name: string, text: string?)
	local badge = badges[name]
	if not badge then
		return
	end
	badge.Visible = text ~= nil
	local count = badge:FindFirstChild("Count")
	if count and count:IsA("TextLabel") and text then
		count.Text = text
	end
end

local function buildTop(root: Frame)
	local panel = UI.Panel({
		Name = "StardustPanel",
		Color = UI.Colors.PanelDark,
		Size = UDim2.fromOffset(340, 96),
		Position = UDim2.new(0.5, 0, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		CornerRadius = 18,
		BackgroundTransparency = 0.15,
		Parent = root,
	})
	stardustLabel = UI.Text({ Name = "Stardust", Text = "⭐ 0", Size = UDim2.new(1, -20, 0, 48), Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0), TextColor3 = Color3.fromRGB(255, 225, 100), StrokeThickness = 3, Parent = panel })
	damageLabel = UI.Text({ Name = "Damage", Text = "⚔️ 1 / hit", Size = UDim2.new(0.48, 0, 0, 26), Position = UDim2.new(0.02, 0, 0, 60), TextColor3 = Color3.fromRGB(255, 160, 140), Parent = panel })
	zoneLabel = UI.Text({ Name = "Zone", Text = "", Size = UDim2.new(0.48, 0, 0, 26), Position = UDim2.new(0.5, 0, 0, 60), TextColor3 = Color3.fromRGB(170, 230, 255), Parent = panel })

	local info = UI.New("Frame", { Name = "Info", BackgroundTransparency = 1, Size = UDim2.fromOffset(520, 120), Position = UDim2.new(0.5, 0, 0, 112), AnchorPoint = Vector2.new(0.5, 0), Parent = root })
	UI.List(Enum.FillDirection.Vertical, 2).Parent = info
	for i = 1, 5 do
		infoLabels[i] = UI.Text({ Name = "Line" .. i, Text = "", Size = UDim2.new(1, 0, 0, 22), LayoutOrder = i, Visible = false, Parent = info })
	end
end

local function buildMenu(root: Frame)
	local menu = UI.New("Frame", { Name = "Menu", BackgroundTransparency = 1, Size = UDim2.fromOffset(184, 470), Position = UDim2.new(0, 14, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = root })
	local grid = UI.Grid(UDim2.fromOffset(84, 84), 10)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	grid.Parent = menu
	for order, def in MENU do
		local button = UI.Button({
			Name = def.Name,
			Text = "",
			Color = def.Color,
			Size = UDim2.fromOffset(84, 84),
			LayoutOrder = order,
			OnClick = function()
				Windows.Toggle(def.Name)
			end,
			Parent = menu,
		})
		UI.Text({ Name = "Icon", Text = def.Icon, Size = UDim2.new(1, 0, 0.55, 0), Position = UDim2.fromScale(0, 0.06), StrokeThickness = 0, Parent = button })
		UI.Text({ Name = "Caption", Text = def.Label, Size = UDim2.new(1, -6, 0.28, 0), Position = UDim2.new(0, 3, 0.66, 0), Parent = button })
		local badge = UI.Panel({ Name = "Badge", Color = UI.Colors.Red, Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, 6, 0, -6), AnchorPoint = Vector2.new(1, 0), CornerRadius = 14, Visible = false, ZIndex = 3, Parent = button })
		UI.Text({ Name = "Count", Text = "!", Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 4, Parent = badge })
		badges[def.Name] = badge
	end
end

local function buildRadar(root: Frame)
	local panel = UI.Panel({ Name = "Radar", Color = UI.Colors.PanelDark, Size = UDim2.fromOffset(230, 168), Position = UDim2.new(1, -14, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 0.2, Parent = root })
	UI.Text({ Name = "Title", Text = "📡 METEOR RADAR", Size = UDim2.new(1, -16, 0, 26), Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0), TextColor3 = UI.Colors.Cyan, Parent = panel })
	for i = 1, 4 do
		local row = UI.New("Frame", { Name = "Row" .. i, BackgroundTransparency = 1, Size = UDim2.new(1, -16, 0, 30), Position = UDim2.new(0, 8, 0, 34 + (i - 1) * 32), Parent = panel })
		local arrow = UI.Text({ Name = "Arrow", Text = "➤", Size = UDim2.fromOffset(28, 28), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = row })
		local text = UI.Text({ Name = "Text", Text = "", Size = UDim2.new(1, -36, 0.85, 0), Position = UDim2.new(0, 34, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		radarRows[i] = { Frame = row, Arrow = arrow, Text = text }
	end
end

local function buildHint(root: Frame)
	hintPanel = UI.Panel({ Name = "Hint", Color = UI.Colors.PanelDark, Size = UDim2.fromOffset(640, 54), Position = UDim2.new(0.5, 0, 1, -36), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 0.1, Visible = false, Parent = root })
	hintLabel = UI.Text({ Text = "", Size = UDim2.new(1, -24, 0.7, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), TextColor3 = UI.Colors.Yellow, Parent = hintPanel })
end

-- ---------------------------------------------------------------------
-- Actualizaciones
-- ---------------------------------------------------------------------
local function updateRadar()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	local folder = Workspace:FindFirstChild("Meteors")
	local zone = player:GetAttribute("Zone") or 1
	local list = {}
	if root and root:IsA("BasePart") and camera and folder then
		for _, child in folder:GetChildren() do
			local isMeteor = child:IsA("Model") and child:GetAttribute("MeteorId") ~= nil
			local isMarker = child:IsA("BasePart") and child:GetAttribute("ImpactAt") ~= nil
			if isMeteor or isMarker then
				local position = if child:IsA("Model") then child:GetPivot().Position else (child :: BasePart).Position
				local comet = child:GetAttribute("Comet") == true
				local childZone = if child:IsA("Model") then child:GetAttribute("Zone") else nil
				if comet or childZone == nil or childZone == zone or (math.abs(position.X - root.Position.X) < 120) then
					local rarity = child:GetAttribute("Rarity") or "Common"
					table.insert(list, {
						Position = position,
						Rarity = rarity,
						Order = if comet then 99 else Rarities.Order(rarity),
						Distance = (position - root.Position).Magnitude,
						Incoming = isMarker,
						Comet = comet,
					})
				end
			end
		end
	end
	table.sort(list, function(a, b)
		if a.Order ~= b.Order then
			return a.Order > b.Order
		end
		return a.Distance < b.Distance
	end)
	for i, row in radarRows do
		local entry = list[i]
		row.Frame.Visible = entry ~= nil
		if entry and camera and root then
			local look = camera.CFrame.LookVector
			local toTarget = entry.Position - (root :: BasePart).Position
			local angle = math.atan2(toTarget.X, toTarget.Z) - math.atan2(look.X, look.Z)
			row.Arrow.Rotation = -math.deg(angle) - 90
			local color = if entry.Comet then Color3.fromRGB(140, 230, 255) else Rarities.Get(entry.Rarity).Color
			row.Arrow.TextColor3 = color
			row.Text.TextColor3 = color
			row.Text.Text = ("%s%s  %dm"):format(if entry.Incoming then "⚠️ " else "", if entry.Comet then "COMET" else string.upper(entry.Rarity), math.floor(entry.Distance))
		end
	end
end

local function updateHint(data: { [string]: any })
	local stats = data.Stats or {}
	local stardust = State.Stardust()
	local text: string? = nil
	if (data.Rebirths or 0) == 0 then
		if (stats.Meteors or 0) == 0 then
			text = "☄️ Run to a meteor and CLICK to mine it! (follow the radar ➤)"
		elseif data.Pickaxe == "Rusty" and stardust >= 60 then
			text = "⛏️ Buy a better pickaxe in the Shop!"
		elseif (stats.Hatched or 0) == 0 and stardust >= Critters.Eggs[1].Cost then
			text = "🥚 Hatch an egg at the egg stand — critters mine WITH you!"
		elseif (data.Zone or 1) == 1 and stardust >= Zones.Get(2).Cost then
			text = "🏜️ You can unlock the Dune Desert! Go to the gate."
		end
	end
	hintPanel.Visible = text ~= nil
	if text then
		hintLabel.Text = text
	end
end

local function updateInfo(now: number)
	local lines = {}
	local cometAt = Workspace:GetAttribute("CometAt") or 0
	if Workspace:GetAttribute("CometActive") == true then
		table.insert(lines, { "☄️ GIANT COMET AT THE PLAZA! GO GO GO!", Color3.fromRGB(140, 230, 255) })
	elseif cometAt > now then
		table.insert(lines, { "☄️ Giant Comet in " .. Format.Clock(cometAt - now), Color3.fromRGB(170, 220, 255) })
	end
	local luckEnds = Workspace:GetAttribute("ServerLuckEndsAt") or 0
	if luckEnds > now then
		table.insert(lines, { ("🍀 SERVER LUCK x%d  •  %s"):format(Config.ServerLuck.Multiplier, Format.Clock(luckEnds - now)), Color3.fromRGB(110, 255, 140) })
	end
	local adminEnds = Workspace:GetAttribute("AdminLuckEndsAt") or 0
	if adminEnds > now then
		table.insert(lines, { ("👑 ADMIN LUCK x%s  •  %s"):format(tostring(Workspace:GetAttribute("AdminLuck") or 1), Format.Clock(adminEnds - now)), Color3.fromRGB(255, 130, 230) })
	end
	local eventTitle = Workspace:GetAttribute("EventTitle")
	local eventEnds = Workspace:GetAttribute("EventEndsAt") or 0
	if typeof(eventTitle) == "string" and eventEnds > now then
		table.insert(lines, { ("%s  •  %s"):format(eventTitle, Format.Clock(eventEnds - now)), Color3.fromRGB(255, 220, 100) })
	end
	local boostStardust = player:GetAttribute("BoostStardust") or 0
	if boostStardust > 0 then
		table.insert(lines, { "⏫ 2x Stardust " .. Format.Clock(boostStardust), Color3.fromRGB(120, 230, 255) })
	end
	local boostDamage = player:GetAttribute("BoostDamage") or 0
	if boostDamage > 0 then
		table.insert(lines, { "⚔️ 2x Damage " .. Format.Clock(boostDamage), Color3.fromRGB(255, 150, 130) })
	end
	for i, label in infoLabels do
		local line = lines[i]
		label.Visible = line ~= nil
		if line then
			label.Text = line[1]
			label.TextColor3 = line[2]
		end
	end
end

local function updateBadges(data: { [string]: any }, now: number)
	local ready = 0
	local elapsed = now - (data.SessionStart or now)
	for index, gift in Config.PlaytimeGifts do
		if not (data.GiftsClaimed and data.GiftsClaimed[tostring(index)]) and elapsed >= gift.Minutes * 60 then
			ready += 1
		end
	end
	HUD.SetBadge("Gifts", if ready > 0 then tostring(ready) else nil)
	HUD.SetBadge("Daily", if data.DailyAvailable then "!" else nil)
	local questsReady = 0
	if data.Quests and data.Quests.List then
		for _, quest in data.Quests.List do
			if quest.Progress >= quest.Target and not quest.Claimed then
				questsReady += 1
			end
		end
	end
	HUD.SetBadge("Quests", if questsReady > 0 then tostring(questsReady) else nil)
	local stardust = State.Stardust()
	HUD.SetBadge("Rebirth", if stardust >= (data.RebirthCost or math.huge) then "!" else nil)
	local nextZone = Zones.List[(data.Zone or 1) + 1]
	HUD.SetBadge("Zones", if nextZone and stardust >= nextZone.Cost then "!" else nil)
	local _ = Economy
end

function HUD.Init()
	local _, root = UI.Screen("MeteorRushHUD", 5)
	buildTop(root)
	buildMenu(root)
	buildRadar(root)
	buildHint(root)

	displayed = State.Stardust()
	RunService.RenderStepped:Connect(function(dt)
		local target = State.Stardust()
		if math.abs(target - displayed) < 1 then
			displayed = target
		else
			displayed += (target - displayed) * math.clamp(dt * 10, 0, 1)
		end
		stardustLabel.Text = "⭐ " .. Format.Abbreviate(displayed)
	end)

	local function refreshStatic()
		local hit = player:GetAttribute("HitDamage")
		damageLabel.Text = "⚔️ " .. Format.Abbreviate(if typeof(hit) == "number" then hit else 1) .. " / hit"
		local zone = Zones.Get(player:GetAttribute("Zone") or 1)
		zoneLabel.Text = zone.Icon .. " " .. zone.Name
		zoneLabel.TextColor3 = zone.AccentColor
	end
	player:GetAttributeChangedSignal("HitDamage"):Connect(refreshStatic)
	player:GetAttributeChangedSignal("Zone"):Connect(refreshStatic)
	refreshStatic()

	task.spawn(function()
		while true do
			local now = Workspace:GetServerTimeNow()
			local ok, err = pcall(function()
				updateInfo(now)
				updateRadar()
				if State.Data then
					updateHint(State.Data)
					updateBadges(State.Data, now)
				end
			end)
			if not ok then
				warn("[HUD] " .. tostring(err))
			end
			task.wait(0.2)
		end
	end)
end

return HUD
