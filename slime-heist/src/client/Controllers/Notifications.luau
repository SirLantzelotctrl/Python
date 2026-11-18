-- Notificaciones (toasts abajo) y anuncios grandes (arriba, para rarezas/eventos).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local Modules = script.Parent.Parent.Modules
local UI = require(Modules.UI)
local Sound = require(Modules.Sound)

local Notifications = {}

local KIND_COLORS = {
	Info = UI.Colors.Blue,
	Success = UI.Colors.Green,
	Error = UI.Colors.Red,
	Warning = UI.Colors.Orange,
	Cash = Color3.fromRGB(70, 200, 110),
}

local toastContainer: Frame
local announceContainer: Frame
local MAX_TOASTS = 5
local toastOrder = 0

function Notifications.Show(text: string, kind: string?)
	local color = KIND_COLORS[kind or "Info"] or UI.Colors.Blue
	toastOrder += 1
	local toast = UI.Panel({
		Name = "Toast",
		Color = UI.Darken(color, 0.15),
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = toastOrder,
		BackgroundTransparency = 0.05,
		CornerRadius = 12,
		Parent = toastContainer,
	})
	UI.Gradient(Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 205, 205)).Parent = toast
	local label = UI.Text({
		Text = text,
		Size = UDim2.new(1, -20, 0.72, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = toast,
	})
	local scale = UI.New("UIScale", { Scale = 0.6, Parent = toast })
	UI.Tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)

	if kind == "Error" then
		Sound.Play("Error", 0.4)
	end

	local toasts = {}
	for _, child in toastContainer:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts > MAX_TOASTS then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		for i = 1, #toasts - MAX_TOASTS do
			toasts[i]:Destroy()
		end
	end

	task.delay(3.6, function()
		if toast.Parent then
			UI.Tween(toast, 0.35, { BackgroundTransparency = 1 })
			UI.Tween(label, 0.35, { TextTransparency = 1 })
			local stroke = label:FindFirstChildOfClass("UIStroke")
			if stroke then
				UI.Tween(stroke, 0.35, { Transparency = 1 })
			end
			local border = toast:FindFirstChildOfClass("UIStroke")
			if border then
				UI.Tween(border, 0.35, { Transparency = 1 })
			end
			task.wait(0.4)
			toast:Destroy()
		end
	end)
end

function Notifications.Announce(text: string, color: Color3?, duration: number?)
	announceContainer:ClearAllChildren()
	local label = UI.Text({
		Name = "Announcement",
		Text = text,
		TextColor3 = color or UI.Colors.Text,
		Size = UDim2.fromScale(1, 1),
		StrokeThickness = 3,
		Parent = announceContainer,
	})
	local scale = UI.New("UIScale", { Scale = 0.3, Parent = label })
	UI.Tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(duration or 4, function()
		if label.Parent then
			UI.Tween(label, 0.4, { TextTransparency = 1 })
			local stroke = label:FindFirstChildOfClass("UIStroke")
			if stroke then
				UI.Tween(stroke, 0.4, { Transparency = 1 })
			end
			task.wait(0.45)
			label:Destroy()
		end
	end)
end

function Notifications.Init()
	local _, root = UI.Screen("SlimeHeistNotifications", 30)

	toastContainer = UI.New("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -100),
		Size = UDim2.fromOffset(560, 260),
		Parent = root,
	})
	UI.List(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom).Parent = toastContainer

	announceContainer = UI.New("Frame", {
		Name = "Announcements",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 175),
		Size = UDim2.new(0.8, 0, 0, 48),
		Parent = root,
	})

	Remotes.Event("Notify").OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" and typeof(payload.Text) == "string" then
			Notifications.Show(payload.Text, payload.Kind)
		end
	end)
	Remotes.Event("Announce").OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" and typeof(payload.Text) == "string" then
			Notifications.Announce(payload.Text, payload.Color, payload.Duration)
		end
	end)
end

return Notifications
