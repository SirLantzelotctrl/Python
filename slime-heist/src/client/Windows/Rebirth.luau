-- Ventana de Rebirth: muestra ventajas, coste y progreso.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Economy = require(Shared:WaitForChild("Economy"))
local Format = require(Shared:WaitForChild("Format"))

local Modules = script.Parent.Parent.Modules
local UI = require(Modules.UI)
local State = require(Modules.State)

local Notifications = require(script.Parent.Parent.Controllers.Notifications)

local Rebirth = {
	Title = "♻️ REBIRTH",
	Color = UI.Colors.Yellow,
	Size = UDim2.fromOffset(600, 470),
}

local headline: TextLabel
local perkLabels: { TextLabel } = {}
local progressFill: Frame
local progressText: TextLabel
local rebirthButton: TextButton
local rebirthLabel: TextLabel

function Rebirth.Build(window)
	local content = window.Content
	headline = UI.Text({ Name = "Headline", Text = "", Size = UDim2.new(1, 0, 0, 44), StrokeThickness = 3, Parent = content })

	local perks = UI.Panel({ Name = "Perks", Color = UI.Colors.PanelDark, Size = UDim2.new(1, 0, 0, 170), Position = UDim2.new(0, 0, 0, 52), Parent = content })
	UI.List(Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center).Parent = perks
	UI.Padding(8, 16, 8, 16).Parent = perks
	for i = 1, 5 do
		perkLabels[i] = UI.Text({ Name = "Perk" .. i, Text = "", Size = UDim2.new(1, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i, Parent = perks })
	end

	UI.Text({
		Name = "Warning",
		Text = "⚠️ Rebirth resets your cash and slimes!",
		TextColor3 = Color3.fromRGB(255, 140, 120),
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.new(0, 0, 0, 230),
		Parent = content,
	})

	local bar = UI.Panel({ Name = "Progress", Color = UI.Colors.PanelDark, Size = UDim2.new(1, -20, 0, 38), Position = UDim2.new(0.5, 0, 0, 266), AnchorPoint = Vector2.new(0.5, 0), Parent = content })
	progressFill = UI.New("Frame", {
		Name = "Fill",
		BackgroundColor3 = UI.Colors.Green,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = bar,
	}, { UI.Corner(12), UI.Gradient(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 190)) })
	progressText = UI.Text({ Name = "Text", Text = "", Size = UDim2.new(1, -16, 0.75, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3, Parent = bar })

	rebirthButton, rebirthLabel = UI.Button({
		Name = "RebirthButton",
		Text = "REBIRTH",
		Color = UI.Colors.Gray,
		Size = UDim2.fromOffset(260, 62),
		Position = UDim2.new(0.5, 0, 1, -4),
		AnchorPoint = Vector2.new(0.5, 1),
		OnClick = function()
			local ok, message = State.Action("Rebirth")
			if message then
				Notifications.Show(message, if ok then "Success" else "Error")
			end
		end,
		Parent = content,
	})
end

function Rebirth.Refresh(data)
	local rebirths = data.Rebirths or 0
	local passes = data.Passes or {}
	local cost = data.RebirthCost or Economy.GetRebirthCost(rebirths)
	headline.Text = ("Rebirth %d  ➜  %d"):format(rebirths, rebirths + 1)

	local bonusNow = math.floor(rebirths * Config.Rebirth.IncomeBonus * 100 + 0.5)
	local bonusNext = math.floor((rebirths + 1) * Config.Rebirth.IncomeBonus * 100 + 0.5)
	local slotsNow = Economy.GetSlotCount(rebirths, passes.ExtraSlots == true)
	local slotsNext = Economy.GetSlotCount(rebirths + 1, passes.ExtraSlots == true)
	local lockLevel = (data.Upgrades and data.Upgrades.Lock) or 0
	local lockNow = Economy.GetLockDuration(rebirths, lockLevel, passes.LongerLock == true)
	local lockNext = Economy.GetLockDuration(rebirths + 1, lockLevel, passes.LongerLock == true)

	perkLabels[1].Text = ("💵 Income bonus: +%d%%  ➜  +%d%%"):format(bonusNow, bonusNext)
	perkLabels[2].Text = ("📦 Slime slots: %d  ➜  %d"):format(slotsNow, slotsNext)
	perkLabels[3].Text = ("🔒 Lock time: %ds  ➜  %ds"):format(lockNow, lockNext)
	perkLabels[4].Text = "🏏 Unlocks stronger bats in the Shop"
	perkLabels[5].Text = "♻️ Shows off your rebirth above your head"

	Rebirth.Tick()
	local _ = cost
end

function Rebirth.Tick()
	local data = State.Data
	if not data or not progressFill then
		return
	end
	local cost = data.RebirthCost or math.huge
	local cash = State.Cash()
	local progress = math.clamp(cash / cost, 0, 1)
	progressFill.Size = UDim2.fromScale(progress, 1)
	progressText.Text = ("%s / %s"):format(Format.Money(cash), Format.Money(cost))
	local ready = cash >= cost
	UI.SetButtonColor(rebirthButton, if ready then UI.Colors.Green else UI.Colors.Gray)
	rebirthLabel.Text = if ready then "♻️ REBIRTH!" else "Need " .. Format.Money(math.max(0, cost - cash))
end

return Rebirth
