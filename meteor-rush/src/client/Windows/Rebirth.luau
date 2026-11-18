-- 🌟 Supernova (rebirth): ventajas, coste y progreso.

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
	Title = "🌟 SUPERNOVA",
	Color = UI.Colors.Pink,
	Size = UDim2.fromOffset(600, 480),
}

local headline: TextLabel
local perkLabels: { TextLabel } = {}
local progressFill: Frame
local progressText: TextLabel
local button: TextButton
local buttonLabel: TextLabel

function Rebirth.Build(window)
	local content = window.Content
	headline = UI.Text({ Name = "Headline", Text = "", Size = UDim2.new(1, 0, 0, 44), StrokeThickness = 3, Parent = content })
	local perks = UI.Panel({ Name = "Perks", Color = UI.Colors.PanelDark, Size = UDim2.new(1, 0, 0, 170), Position = UDim2.new(0, 0, 0, 52), Parent = content })
	UI.List(Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center).Parent = perks
	UI.Padding(8, 16, 8, 16).Parent = perks
	for i = 1, 5 do
		perkLabels[i] = UI.Text({ Name = "Perk" .. i, Text = "", Size = UDim2.new(1, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i, Parent = perks })
	end
	UI.Text({ Name = "Warning", Text = "⚠️ Resets stardust, pickaxes & zones. You KEEP your critters!", TextColor3 = Color3.fromRGB(255, 160, 140), Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 0, 230), Parent = content })
	local bar = UI.Panel({ Name = "Progress", Color = UI.Colors.PanelDark, Size = UDim2.new(1, -20, 0, 38), Position = UDim2.new(0.5, 0, 0, 266), AnchorPoint = Vector2.new(0.5, 0), Parent = content })
	progressFill = UI.New("Frame", { Name = "Fill", BackgroundColor3 = UI.Colors.Pink, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Parent = bar }, { UI.Corner(12) })
	progressText = UI.Text({ Name = "Text", Text = "", Size = UDim2.new(1, -16, 0.75, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3, Parent = bar })
	button, buttonLabel = UI.Button({
		Name = "Supernova",
		Text = "SUPERNOVA",
		Color = UI.Colors.Gray,
		Size = UDim2.fromOffset(280, 62),
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
	headline.Text = ("Supernova %d  ➜  %d"):format(rebirths, rebirths + 1)
	perkLabels[1].Text = ("⭐ Stardust bonus: +%d%%  ➜  +%d%%"):format(math.floor(rebirths * Config.Rebirth.StardustBonus * 100 + 0.5), math.floor((rebirths + 1) * Config.Rebirth.StardustBonus * 100 + 0.5))
	perkLabels[2].Text = ("⚔️ Damage bonus: +%d%%  ➜  +%d%%"):format(math.floor(rebirths * Config.Rebirth.DamageBonus * 100 + 0.5), math.floor((rebirths + 1) * Config.Rebirth.DamageBonus * 100 + 0.5))
	perkLabels[3].Text = ("🐾 Critter slots: %d  ➜  %d"):format(Economy.GetSlotCount(rebirths, passes.ExtraSlots == true), Economy.GetSlotCount(rebirths + 1, passes.ExtraSlots == true))
	perkLabels[4].Text = "🌟 Supernova tag above your head"
	perkLabels[5].Text = "🐾 Your critters, upgrades & index stay!"
	Rebirth.Tick()
end

function Rebirth.Tick()
	local data = State.Data
	if not data or not progressFill then
		return
	end
	local cost = data.RebirthCost or math.huge
	local stardust = State.Stardust()
	progressFill.Size = UDim2.fromScale(math.clamp(stardust / cost, 0, 1), 1)
	progressText.Text = ("%s / %s ⭐"):format(Format.Abbreviate(stardust), Format.Abbreviate(cost))
	local ready = stardust >= cost
	UI.SetButtonColor(button, if ready then UI.Colors.Pink else UI.Colors.Gray)
	buttonLabel.Text = if ready then "🌟 GO SUPERNOVA!" else "Need " .. Format.Abbreviate(math.max(0, cost - stardust)) .. " ⭐"
end

return Rebirth
