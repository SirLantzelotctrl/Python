-- HUD principal: dinero, ingresos, botones del menú, estado del candado, eventos,
-- aviso de robo y guía (rayo) hacia tu base cuando llevas un slime robado.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Config = require(Shared:WaitForChild("Config"))

local Modules = script.Parent.Parent.Modules
local UI = require(Modules.UI)
local State = require(Modules.State)
local Sound = require(Modules.Sound)

local Windows = require(script.Parent.Windows)

local HUD = {}

local player = Players.LocalPlayer

local cashLabel: TextLabel
local incomeLabel: TextLabel
local boostLabel: TextLabel
local eventFrame: Frame
local eventLabels: { TextLabel } = {}
local lockLabel: TextLabel
local carryBanner: Frame
local carryLabel: TextLabel
local alarmFrame: Frame
local alarmLabel: TextLabel
local badges: { [string]: Frame } = {}

local hintPanel: Frame
local hintLabel: TextLabel
local displayedCash = 0
local stealHintUntil = 0
local alarmActive = false
local homeBeam: Beam? = nil
local beamAttachments: { Attachment } = {}

local MENU_BUTTONS = {
	{ Name = "Shop", Icon = "🛒", Label = "Shop", Color = UI.Colors.Green },
	{ Name = "Store", Icon = "💎", Label = "Store", Color = UI.Colors.Pink },
	{ Name = "Rebirth", Icon = "♻️", Label = "Rebirth", Color = UI.Colors.Yellow },
	{ Name = "Index", Icon = "📖", Label = "Index", Color = UI.Colors.Purple },
	{ Name = "Gifts", Icon = "🎁", Label = "Gifts", Color = UI.Colors.Orange },
	{ Name = "Daily", Icon = "📅", Label = "Daily", Color = UI.Colors.Blue },
	{ Name = "Codes", Icon = "🎟️", Label = "Codes", Color = UI.Colors.Cyan },
}

local function menuButton(parent: Instance, def: { [string]: any }, order: number)
	local button = UI.Button({
		Name = def.Name,
		Text = "",
		Color = def.Color,
		Size = UDim2.fromOffset(84, 84),
		LayoutOrder = order,
		OnClick = function()
			Windows.Toggle(def.Name)
		end,
		Parent = parent,
	})
	UI.Text({ Name = "Icon", Text = def.Icon, Size = UDim2.new(1, 0, 0.55, 0), Position = UDim2.fromScale(0, 0.06), StrokeThickness = 0, Parent = button })
	UI.Text({ Name = "Caption", Text = def.Label, Size = UDim2.new(1, -6, 0.3, 0), Position = UDim2.new(0, 3, 0.64, 0), Parent = button })

	local badge = UI.Panel({
		Name = "Badge",
		Color = UI.Colors.Red,
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, 6, 0, -6),
		AnchorPoint = Vector2.new(1, 0),
		CornerRadius = 14,
		Visible = false,
		ZIndex = 3,
		Parent = button,
	})
	UI.Text({ Name = "Count", Text = "!", Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 4, Parent = badge })
	badges[def.Name] = badge
end

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

-- ---------------------------------------------------------------------
-- Construcción
-- ---------------------------------------------------------------------
local function buildCashPanel(root: Frame)
	local panel = UI.Panel({
		Name = "CashPanel",
		Color = UI.Colors.PanelDark,
		Size = UDim2.fromOffset(330, 92),
		Position = UDim2.new(0.5, 0, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		CornerRadius = 18,
		BackgroundTransparency = 0.15,
		Parent = root,
	})
	cashLabel = UI.Text({ Name = "Cash", Text = "$0", Size = UDim2.new(1, -20, 0, 48), Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0), TextColor3 = UI.Colors.Cash, StrokeThickness = 3, Parent = panel })
	incomeLabel = UI.Text({ Name = "Income", Text = "+$0/s", Size = UDim2.new(0.6, 0, 0, 26), Position = UDim2.new(0.5, 0, 0, 56), AnchorPoint = Vector2.new(0.5, 0), TextColor3 = Color3.fromRGB(255, 255, 255), Parent = panel })
	boostLabel = UI.Text({ Name = "Boost", Text = "", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0.5, 0, 1, 6), AnchorPoint = Vector2.new(0.5, 0), TextColor3 = UI.Colors.Yellow, Visible = false, Parent = panel })
end

local function buildEventFrame(root: Frame)
	eventFrame = UI.New("Frame", {
		Name = "Events",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(460, 64),
		Position = UDim2.new(0.5, 0, 0, 132),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = root,
	})
	UI.List(Enum.FillDirection.Vertical, 2).Parent = eventFrame
	for i = 1, 3 do
		local label = UI.Text({ Name = "Event" .. i, Text = "", Size = UDim2.new(1, 0, 0, 22), LayoutOrder = i, Visible = false, Parent = eventFrame })
		eventLabels[i] = label
	end
end

local function buildMenu(root: Frame)
	local menu = UI.New("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(186, 380),
		Position = UDim2.new(0, 14, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = root,
	})
	local grid = UI.Grid(UDim2.fromOffset(84, 84), 12)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	grid.Parent = menu
	for index, def in MENU_BUTTONS do
		menuButton(menu, def, index)
	end
end

local function buildRightSide(root: Frame)
	local side = UI.New("Frame", {
		Name = "Right",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(190, 160),
		Position = UDim2.new(1, -14, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = root,
	})
	UI.List(Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Right).Parent = side
	UI.Button({
		Name = "Home",
		Text = "🏠 Home",
		Color = UI.Colors.Blue,
		Size = UDim2.fromOffset(170, 58),
		LayoutOrder = 1,
		OnClick = function()
			local ok, message = State.Action("Home")
			if not ok and message then
				require(script.Parent.Notifications).Show(message, "Error")
			end
		end,
		Parent = side,
	})
	local lockPanel = UI.Panel({ Name = "LockStatus", Color = UI.Colors.PanelDark, Size = UDim2.fromOffset(170, 50), LayoutOrder = 2, BackgroundTransparency = 0.15, Parent = side })
	lockLabel = UI.Text({ Text = "🔓 Base open", Size = UDim2.new(1, -16, 0.7, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = lockPanel })
end

local function buildCarryBanner(root: Frame)
	carryBanner = UI.Panel({
		Name = "Carry",
		Color = Color3.fromRGB(200, 40, 60),
		Size = UDim2.fromOffset(520, 56),
		Position = UDim2.new(0.5, 0, 0, 210),
		AnchorPoint = Vector2.new(0.5, 0),
		Visible = false,
		Parent = root,
	})
	carryLabel = UI.Text({ Text = "", Size = UDim2.new(1, -20, 0.7, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = carryBanner })
end

local function buildAlarm(root: Frame)
	alarmFrame = UI.New("Frame", {
		Name = "Alarm",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = root,
	})
	local border = UI.Stroke(18, Color3.fromRGB(255, 30, 50), true)
	border.Parent = alarmFrame
	alarmLabel = UI.Text({
		Text = "",
		TextColor3 = Color3.fromRGB(255, 90, 90),
		Size = UDim2.new(0.8, 0, 0, 46),
		Position = UDim2.new(0.5, 0, 0, 262),
		AnchorPoint = Vector2.new(0.5, 0),
		StrokeThickness = 3,
		Parent = alarmFrame,
	})
end

local function buildHint(root: Frame)
	hintPanel = UI.Panel({
		Name = "Hint",
		Color = UI.Colors.PanelDark,
		Size = UDim2.fromOffset(620, 54),
		Position = UDim2.new(0.5, 0, 1, -36),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = root,
	})
	hintLabel = UI.Text({ Text = "", Size = UDim2.new(1, -24, 0.7, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), TextColor3 = UI.Colors.Yellow, Parent = hintPanel })
end

-- Pistas para jugadores nuevos (se ocultan solas al completar cada paso)
local function updateHint(now: number)
	local data = State.Data
	local text: string? = nil
	if data and data.Stats then
		local bought = data.Stats.Bought or 0
		if bought == 0 and (data.Rebirths or 0) == 0 then
			text = "👉 Go to the runway and press E on a slime to BUY it!"
		elseif bought <= 2 and (data.TotalEarned or 0) < 60 and (data.Rebirths or 0) == 0 then
			text = "💵 Step on the GREEN pad in front of your slime to collect cash!"
		elseif bought >= 3 and (data.Stats.Steals or 0) == 0 and (data.Rebirths or 0) == 0 then
			if stealHintUntil == 0 then
				stealHintUntil = now + 25
			end
			if now < stealHintUntil then
				text = "😈 Steal slimes from other bases! 🔒 Step on your red button to lock yours."
			end
		end
	end
	hintPanel.Visible = text ~= nil and player:GetAttribute("Carrying") == nil
	if text then
		hintLabel.Text = text
	end
end

-- ---------------------------------------------------------------------
-- Rayo guía hacia tu base
-- ---------------------------------------------------------------------
local function clearBeam()
	if homeBeam then
		homeBeam:Destroy()
		homeBeam = nil
	end
	for _, attachment in beamAttachments do
		attachment:Destroy()
	end
	table.clear(beamAttachments)
end

local function showBeam()
	clearBeam()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local plotIndex = player:GetAttribute("PlotIndex")
	local map = Workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild("Plot" .. tostring(plotIndex))
	local floor = plot and plot:FindFirstChild("Floor")
	if not root or not floor then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 3, 0)
	a1.Parent = floor
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 1.2
	beam.Width1 = 1.2
	beam.FaceCamera = true
	beam.Color = ColorSequence.new(Color3.fromRGB(90, 255, 120))
	beam.Transparency = NumberSequence.new(0.25)
	beam.LightEmission = 1
	beam.Segments = 1
	beam.Parent = a0
	homeBeam = beam
	beamAttachments = { a0, a1 }
end

-- ---------------------------------------------------------------------
-- Actualizaciones
-- ---------------------------------------------------------------------
local function updateCarry()
	local carrying = player:GetAttribute("Carrying")
	if typeof(carrying) == "string" then
		carryBanner.Visible = true
		carryLabel.Text = "😈 RUN TO YOUR BASE! Carrying " .. carrying
		showBeam()
	else
		carryBanner.Visible = false
		clearBeam()
	end
end

function HUD.ShowAlarm(thief: string, slime: string)
	alarmActive = true
	alarmFrame.Visible = true
	alarmLabel.Text = ("⚠️ %s IS STEALING YOUR %s!"):format(string.upper(thief), string.upper(slime))
	task.spawn(function()
		while alarmActive do
			Sound.Play("Alarm", 0.5)
			local border = alarmFrame:FindFirstChildOfClass("UIStroke")
			if border then
				border.Transparency = 0
				UI.Tween(border, 0.5, { Transparency = 0.7 })
			end
			task.wait(0.6)
		end
	end)
end

function HUD.HideAlarm()
	alarmActive = false
	alarmFrame.Visible = false
end

local function updateTimers()
	local now = Workspace:GetServerTimeNow()

	-- Candado
	local lockEnds = player:GetAttribute("LockEndsAt") or 0
	local cooldownEnds = player:GetAttribute("LockCooldownEndsAt") or 0
	if lockEnds > now then
		lockLabel.Text = ("🔒 Locked %ds"):format(math.ceil(lockEnds - now))
		lockLabel.TextColor3 = UI.Colors.Cash
	elseif cooldownEnds > now then
		lockLabel.Text = ("⏳ Lock in %ds"):format(math.ceil(cooldownEnds - now))
		lockLabel.TextColor3 = UI.Colors.Yellow
	else
		lockLabel.Text = "🔓 Base open"
		lockLabel.TextColor3 = Color3.fromRGB(255, 140, 140)
	end

	-- Boost
	local boost = player:GetAttribute("BoostCashX2") or 0
	boostLabel.Visible = boost > 0
	if boost > 0 then
		boostLabel.Text = "⏫ 2x CASH " .. Format.Clock(boost)
	end

	-- Eventos
	local lines = {}
	local luckEnds = Workspace:GetAttribute("ServerLuckEndsAt") or 0
	if luckEnds > now then
		table.insert(lines, { Text = ("🍀 SERVER LUCK x%d  •  %s"):format(Config.ServerLuck.Multiplier, Format.Clock(luckEnds - now)), Color = Color3.fromRGB(110, 255, 140) })
	end
	local adminEnds = Workspace:GetAttribute("AdminLuckEndsAt") or 0
	if adminEnds > now then
		table.insert(lines, { Text = ("👑 ADMIN LUCK x%s  •  %s"):format(tostring(Workspace:GetAttribute("AdminLuck") or 1), Format.Clock(adminEnds - now)), Color = Color3.fromRGB(255, 130, 230) })
	end
	local eventTitle = Workspace:GetAttribute("EventTitle")
	local eventEnds = Workspace:GetAttribute("EventEndsAt") or 0
	if typeof(eventTitle) == "string" and eventEnds > now then
		table.insert(lines, { Text = ("%s  •  %s"):format(eventTitle, Format.Clock(eventEnds - now)), Color = Color3.fromRGB(255, 225, 90) })
	end
	for i, label in eventLabels do
		local line = lines[i]
		label.Visible = line ~= nil
		if line then
			label.Text = line.Text
			label.TextColor3 = line.Color
		end
	end

	updateHint(now)

	-- Insignias
	local data = State.Data
	if data then
		local ready = 0
		local elapsed = now - (data.SessionStart or now)
		for index, gift in Config.PlaytimeGifts do
			if not (data.GiftsClaimed and data.GiftsClaimed[tostring(index)]) and elapsed >= gift.Minutes * 60 then
				ready += 1
			end
		end
		HUD.SetBadge("Gifts", if ready > 0 then tostring(ready) else nil)
		HUD.SetBadge("Daily", if data.DailyAvailable then "!" else nil)
		local cost = data.RebirthCost or math.huge
		HUD.SetBadge("Rebirth", if State.Cash() >= cost then "!" else nil)
	end
end

function HUD.Init()
	local _, root = UI.Screen("SlimeHeistHUD", 5)
	buildCashPanel(root)
	buildEventFrame(root)
	buildMenu(root)
	buildRightSide(root)
	buildCarryBanner(root)
	buildAlarm(root)
	buildHint(root)

	player:GetAttributeChangedSignal("Income"):Connect(function()
		incomeLabel.Text = "+" .. Format.PerSecond(player:GetAttribute("Income") or 0)
	end)
	player:GetAttributeChangedSignal("Carrying"):Connect(updateCarry)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		updateCarry()
	end)

	-- Contador de dinero animado
	displayedCash = State.Cash()
	RunService.RenderStepped:Connect(function(dt)
		local target = State.Cash()
		if math.abs(target - displayedCash) < 1 then
			displayedCash = target
		else
			displayedCash += (target - displayedCash) * math.clamp(dt * 10, 0, 1)
		end
		cashLabel.Text = Format.Money(displayedCash)
	end)

	State.Observe(function(data)
		incomeLabel.Text = "+" .. Format.PerSecond(data.Income or 0)
	end)

	task.spawn(function()
		while true do
			local ok, err = pcall(updateTimers)
			if not ok then
				warn("[HUD] " .. tostring(err))
			end
			task.wait(0.25)
		end
	end)
end

return HUD
