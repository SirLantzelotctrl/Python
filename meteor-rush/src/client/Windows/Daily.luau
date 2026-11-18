-- Recompensa diaria con racha de 7 días.

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

local Daily = {
	Title = "📅 DAILY REWARDS",
	Color = UI.Colors.Blue,
	Size = UDim2.fromOffset(720, 400),
}

type Cell = { Frame: Frame, Icon: TextLabel, Reward: TextLabel, Status: TextLabel }

local cells: { Cell } = {}
local streakLabel: TextLabel
local claimButton: TextButton
local claimLabel: TextLabel

function Daily.Build(window)
	local content = window.Content
	streakLabel = UI.Text({ Name = "Streak", Text = "", Size = UDim2.new(1, 0, 0, 32), TextColor3 = UI.Colors.Orange, StrokeThickness = 3, Parent = content })
	local row = UI.New("Frame", { Name = "Days", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 170), Position = UDim2.new(0, 0, 0, 44), Parent = content })
	UI.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center).Parent = row
	for day, _ in Config.DailyRewards do
		local frame = UI.Panel({ Name = "Day" .. day, Color = UI.Colors.PanelLight, Size = UDim2.fromOffset(88, 160), LayoutOrder = day, Parent = row })
		UI.Text({ Name = "DayLabel", Text = "Day " .. day, Size = UDim2.new(1, -8, 0, 24), Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0), Parent = frame })
		local icon = UI.Text({ Name = "Icon", Text = "🎁", Size = UDim2.new(1, 0, 0, 44), Position = UDim2.new(0, 0, 0, 34), StrokeThickness = 0, Parent = frame })
		local reward = UI.Text({ Name = "Reward", Text = "", Size = UDim2.new(1, -8, 0, 36), Position = UDim2.new(0.5, 0, 0, 82), AnchorPoint = Vector2.new(0.5, 0), TextWrapped = true, Parent = frame })
		local status = UI.Text({ Name = "Status", Text = "", Size = UDim2.new(1, -8, 0, 22), Position = UDim2.new(0.5, 0, 1, -6), AnchorPoint = Vector2.new(0.5, 1), Parent = frame })
		cells[day] = { Frame = frame, Icon = icon, Reward = reward, Status = status }
	end
	claimButton, claimLabel = UI.Button({
		Name = "Claim",
		Text = "",
		Color = UI.Colors.Gray,
		Size = UDim2.fromOffset(300, 62),
		Position = UDim2.new(0.5, 0, 1, -4),
		AnchorPoint = Vector2.new(0.5, 1),
		OnClick = function()
			local ok, message = State.Action("ClaimDaily")
			if message then
				Notifications.Show(message, if ok then "Success" else "Error")
			end
		end,
		Parent = content,
	})
end

function Daily.Refresh(data)
	local income = data.RewardBase or 1
	local nextIndex = data.DailyNextIndex or 1
	local available = data.DailyAvailable == true
	-- Días ya reclamados dentro del ciclo actual de 7
	local claimedInCycle = if available then nextIndex - 1 else ((data.DailyStreak or 0) - 1) % #Config.DailyRewards + 1
	if (data.DailyStreak or 0) == 0 then
		claimedInCycle = 0
	end
	streakLabel.Text = ("🔥 Streak: %d day%s"):format(data.DailyStreak or 0, if (data.DailyStreak or 0) == 1 then "" else "s")
	for day, reward in Config.DailyRewards do
		local cell = cells[day]
		if cell then
			local icon, text, color = RewardInfo.Describe(reward, income)
			cell.Icon.Text = icon
			cell.Reward.Text = text
			cell.Reward.TextColor3 = color
			local stroke = cell.Frame:FindFirstChildOfClass("UIStroke")
			if day <= claimedInCycle then
				cell.Status.Text = "✅"
				cell.Frame.BackgroundColor3 = UI.Colors.PanelDark
			elseif available and day == nextIndex then
				cell.Status.Text = "TODAY!"
				cell.Frame.BackgroundColor3 = UI.Darken(UI.Colors.Green, 0.35)
			else
				cell.Status.Text = ""
				cell.Frame.BackgroundColor3 = UI.Colors.PanelLight
			end
			if stroke then
				stroke.Color = if available and day == nextIndex then UI.Colors.Yellow else UI.Colors.Stroke
			end
		end
	end
	Daily.Tick()
end

function Daily.Tick()
	local data = State.Data
	if not data or not claimButton then
		return
	end
	if data.DailyAvailable then
		claimLabel.Text = "🎁 CLAIM!"
		UI.SetButtonColor(claimButton, UI.Colors.Green)
	else
		local remaining = (data.DailyResetAt or 0) - Workspace:GetServerTimeNow()
		claimLabel.Text = "Next in " .. Format.Clock(math.max(0, remaining))
		UI.SetButtonColor(claimButton, UI.Colors.Gray)
		if remaining <= 0 then
			State.Action("RequestSync")
		end
	end
end

return Daily
