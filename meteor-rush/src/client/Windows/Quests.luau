-- Misiones diarias.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Quests = require(Shared:WaitForChild("Quests"))
local Format = require(Shared:WaitForChild("Format"))
local RewardInfo = require(Shared:WaitForChild("RewardInfo"))

local Modules = script.Parent.Parent.Modules
local UI = require(Modules.UI)
local State = require(Modules.State)

local Notifications = require(script.Parent.Parent.Controllers.Notifications)

local QuestsWindow = {
	Title = "📜 DAILY QUESTS",
	Color = UI.Colors.Yellow,
	Size = UDim2.fromOffset(640, 470),
}

type Row = { Title: TextLabel, Fill: Frame, Progress: TextLabel, Button: TextButton, Label: TextLabel, Reward: TextLabel }

local rows: { Row } = {}
local resetLabel: TextLabel
local bonusButton: TextButton
local bonusLabel: TextLabel

local function act(name: string, payload: { [string]: any }?)
	local ok, message = State.Action(name, payload)
	if message then
		Notifications.Show(message, if ok then "Success" else "Error")
	end
end

function QuestsWindow.Build(window)
	local content = window.Content
	resetLabel = UI.Text({ Name = "Reset", Text = "", Size = UDim2.new(1, 0, 0, 26), TextColor3 = UI.Colors.SubText, Parent = content })
	for i = 1, Quests.PerDay do
		local frame = UI.Panel({ Name = "Quest" .. i, Color = UI.Colors.PanelLight, Size = UDim2.new(1, 0, 0, 92), Position = UDim2.new(0, 0, 0, 32 + (i - 1) * 100), Parent = content })
		local title = UI.Text({ Name = "QuestTitle", Text = "", Size = UDim2.new(1, -210, 0, 30), Position = UDim2.new(0, 14, 0, 8), TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
		local bar = UI.Panel({ Name = "Bar", Color = UI.Colors.PanelDark, Size = UDim2.new(1, -210, 0, 26), Position = UDim2.new(0, 14, 0, 46), CornerRadius = 10, Parent = frame })
		local fill = UI.New("Frame", { Name = "Fill", BackgroundColor3 = UI.Colors.Green, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Parent = bar }, { UI.Corner(10) })
		local progress = UI.Text({ Name = "ProgressText", Text = "", Size = UDim2.new(1, -10, 0.8, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3, Parent = bar })
		local reward = UI.Text({ Name = "Reward", Text = "", Size = UDim2.fromOffset(170, 22), Position = UDim2.new(1, -14, 0, 8), AnchorPoint = Vector2.new(1, 0), TextColor3 = Color3.fromRGB(255, 225, 100), Parent = frame })
		local button, label = UI.Button({
			Name = "Claim",
			Text = "",
			Color = UI.Colors.Gray,
			Size = UDim2.fromOffset(170, 44),
			Position = UDim2.new(1, -14, 1, -10),
			AnchorPoint = Vector2.new(1, 1),
			OnClick = function()
				act("ClaimQuest", { Index = i })
			end,
			Parent = frame,
		})
		rows[i] = { Title = title, Fill = fill, Progress = progress, Button = button, Label = label, Reward = reward }
	end
	bonusButton, bonusLabel = UI.Button({
		Name = "Bonus",
		Text = "",
		Color = UI.Colors.Gray,
		Size = UDim2.fromOffset(380, 56),
		Position = UDim2.new(0.5, 0, 1, -4),
		AnchorPoint = Vector2.new(0.5, 1),
		OnClick = function()
			act("ClaimQuestBonus")
		end,
		Parent = content,
	})
end

function QuestsWindow.Refresh(data)
	local quests = data.Quests
	if not quests or not quests.List then
		return
	end
	local allClaimed = true
	for i, row in rows do
		local quest = quests.List[i]
		if quest then
			row.Title.Text = Quests.Describe(quest.Kind, quest.Target)
			row.Fill.Size = UDim2.fromScale(math.clamp(quest.Progress / quest.Target, 0, 1), 1)
			row.Progress.Text = ("%s / %s"):format(Format.Abbreviate(quest.Progress), Format.Abbreviate(quest.Target))
			row.Reward.Text = "+" .. Format.Abbreviate(math.floor((data.RewardBase or 1) * quest.RewardMeteors)) .. " ⭐"
			if quest.Claimed then
				row.Label.Text = "✅ DONE"
				UI.SetButtonColor(row.Button, UI.Colors.Gray)
			elseif quest.Progress >= quest.Target then
				row.Label.Text = "CLAIM!"
				UI.SetButtonColor(row.Button, UI.Colors.Green)
			else
				row.Label.Text = "In progress"
				UI.SetButtonColor(row.Button, UI.Colors.PanelDark)
			end
			allClaimed = allClaimed and quest.Claimed
		end
	end
	local _, bonusText = RewardInfo.Describe(Quests.Bonus, data.RewardBase or 1)
	if quests.BonusClaimed then
		bonusLabel.Text = "🏆 Bonus claimed! Come back tomorrow"
		UI.SetButtonColor(bonusButton, UI.Colors.Gray)
	elseif allClaimed then
		bonusLabel.Text = "🏆 CLAIM BONUS: " .. bonusText
		UI.SetButtonColor(bonusButton, UI.Colors.Green)
	else
		bonusLabel.Text = "🏆 Finish all 3: " .. bonusText
		UI.SetButtonColor(bonusButton, UI.Colors.PanelDark)
	end
	QuestsWindow.Tick()
end

function QuestsWindow.Tick()
	local data = State.Data
	if data and resetLabel then
		resetLabel.Text = "New quests in " .. Format.Clock((data.QuestsResetAt or 0) - Workspace:GetServerTimeNow())
	end
end

return QuestsWindow
