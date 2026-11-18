-- Canjear códigos promocionales.

local Modules = script.Parent.Parent.Modules
local UI = require(Modules.UI)
local State = require(Modules.State)

local Notifications = require(script.Parent.Parent.Controllers.Notifications)

local Codes = {
	Title = "🎟️ CODES",
	Color = UI.Colors.Cyan,
	Size = UDim2.fromOffset(520, 330),
}

local input: TextBox
local result: TextLabel

local function redeem()
	local code = input.Text
	if #code == 0 then
		return
	end
	local ok, message = State.Action("RedeemCode", { Code = code })
	result.Text = message or ""
	result.TextColor3 = if ok then UI.Colors.Cash else Color3.fromRGB(255, 120, 120)
	if ok then
		input.Text = ""
		Notifications.Show(message or "Code redeemed!", "Success")
	end
end

function Codes.Build(window)
	local content = window.Content
	UI.Text({ Name = "Hint", Text = "Like the game & join the group for new codes!", Size = UDim2.new(1, 0, 0, 28), TextColor3 = UI.Colors.SubText, Parent = content })
	local box = UI.Panel({ Name = "InputBox", Color = UI.Colors.PanelDark, Size = UDim2.new(1, -40, 0, 60), Position = UDim2.new(0.5, 0, 0, 44), AnchorPoint = Vector2.new(0.5, 0), Parent = content })
	input = UI.New("TextBox", {
		Name = "Input",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -24, 1, -12),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = UI.Font,
		TextScaled = true,
		Text = "",
		PlaceholderText = "ENTER CODE",
		PlaceholderColor3 = UI.Colors.Gray,
		TextColor3 = UI.Colors.Text,
		ClearTextOnFocus = false,
		Parent = box,
	})
	input.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			redeem()
		end
	end)
	UI.Button({
		Name = "Redeem",
		Text = "REDEEM",
		Color = UI.Colors.Green,
		Size = UDim2.fromOffset(220, 58),
		Position = UDim2.new(0.5, 0, 0, 120),
		AnchorPoint = Vector2.new(0.5, 0),
		OnClick = redeem,
		Parent = content,
	})
	result = UI.Text({ Name = "Result", Text = "", Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0.5, 0, 0, 192), AnchorPoint = Vector2.new(0.5, 0), Parent = content })
end

return Codes
