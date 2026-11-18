-- Regalos por tiempo jugado en la sesión.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local RewardInfo = require(Shared:WaitForChild("RewardInfo"))

local Modules = script.Parent.Parent.Modules
local UI = require(Modules.UI)
local State = require(Modules.State)

local Notifications = require(script.Parent.Parent.Controllers.Notifications)

local Gifts = {
	Title = "🎁 FREE GIFTS",
	Color = UI.Colors.Orange,
	Size = UDim2.fromOffset(700, 500),
}

type Cell = { Frame: Frame, Icon: TextLabel, Reward: TextLabel, Button: TextButton, Label: TextLabel }

local cells: { Cell } = {}

function Gifts.Build(window)
	UI.Text({ Name = "Hint", Text = "Stay in the game to unlock more gifts!", Size = UDim2.new(1, 0, 0, 26), TextColor3 = UI.Colors.SubText, Parent = window.Content })
	local holder = UI.New("Frame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 34),
		Size = UDim2.new(1, 0, 1, -34),
		Parent = window.Content,
	})
	UI.Grid(UDim2.fromOffset(150, 120), 10).Parent = holder
	for index, gift in Config.PlaytimeGifts do
		local frame = UI.Panel({ Name = "Gift" .. index, Color = UI.Colors.PanelLight, LayoutOrder = index, Parent = holder })
		local icon = UI.Text({ Name = "Icon", Text = "🎁", Size = UDim2.new(1, 0, 0, 36), Position = UDim2.new(0, 0, 0, 4), StrokeThickness = 0, Parent = frame })
		local reward = UI.Text({ Name = "Reward", Text = "", Size = UDim2.new(1, -10, 0, 24), Position = UDim2.new(0.5, 0, 0, 42), AnchorPoint = Vector2.new(0.5, 0), Parent = frame })
		local button, label = UI.Button({
			Name = "Claim",
			Text = "",
			Color = UI.Colors.Gray,
			Size = UDim2.new(1, -16, 0, 38),
			Position = UDim2.new(0.5, 0, 1, -8),
			AnchorPoint = Vector2.new(0.5, 1),
			OnClick = function()
				local ok, message = State.Action("ClaimGift", { Index = index })
				if message then
					Notifications.Show(message, if ok then "Success" else "Error")
				end
			end,
			Parent = frame,
		})
		cells[index] = { Frame = frame, Icon = icon, Reward = reward, Button = button, Label = label }
		local _ = gift
	end
end

function Gifts.Refresh(data)
	local income = data.Income or 0
	for index, gift in Config.PlaytimeGifts do
		local cell = cells[index]
		if cell then
			local icon, text, color = RewardInfo.Describe(gift, income)
			cell.Icon.Text = icon
			cell.Reward.Text = text
			cell.Reward.TextColor3 = color
		end
	end
	Gifts.Tick()
end

function Gifts.Tick()
	local data = State.Data
	if not data then
		return
	end
	local elapsed = Workspace:GetServerTimeNow() - (data.SessionStart or Workspace:GetServerTimeNow())
	for index, gift in Config.PlaytimeGifts do
		local cell = cells[index]
		if cell then
			local claimed = data.GiftsClaimed and data.GiftsClaimed[tostring(index)]
			local remaining = gift.Minutes * 60 - elapsed
			if claimed then
				cell.Label.Text = "✅ CLAIMED"
				UI.SetButtonColor(cell.Button, UI.Colors.Gray)
			elseif remaining <= 0 then
				cell.Label.Text = "CLAIM!"
				UI.SetButtonColor(cell.Button, UI.Colors.Green)
			else
				cell.Label.Text = Format.Clock(remaining)
				UI.SetButtonColor(cell.Button, UI.Colors.PanelDark)
			end
		end
	end
end

return Gifts
