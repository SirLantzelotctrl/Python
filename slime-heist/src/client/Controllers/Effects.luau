-- Efectos visuales y de sonido que pide el servidor (remote "Effect").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Format = require(Shared:WaitForChild("Format"))

local Modules = script.Parent.Parent.Modules
local UI = require(Modules.UI)
local Sound = require(Modules.Sound)

local Windows = require(script.Parent.Windows)
local HUD = require(script.Parent.HUD)
local Notifications = require(script.Parent.Notifications)

local Effects = {}

local effectsRoot: Frame
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 90, 90),
	Color3.fromRGB(255, 220, 80),
	Color3.fromRGB(90, 255, 140),
	Color3.fromRGB(90, 180, 255),
	Color3.fromRGB(220, 110, 255),
}

function Effects.FloatingText(position: Vector3, text: string, color: Color3?)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = Workspace.Terrain
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(6, 0, 1.6, 0)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = attachment
	local label = UI.Text({ Text = text, TextColor3 = color or UI.Colors.Cash, StrokeThickness = 3, Parent = gui })
	UI.Tween(gui, 1, { StudsOffset = Vector3.new(0, 6, 0) })
	task.delay(0.5, function()
		UI.Tween(label, 0.5, { TextTransparency = 1 })
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			UI.Tween(stroke, 0.5, { Transparency = 1 })
		end
	end)
	task.delay(1.1, function()
		attachment:Destroy()
	end)
end

function Effects.Confetti(amount: number?)
	local count = amount or 45
	for _ = 1, count do
		local size = math.random(10, 18)
		local piece = UI.New("Frame", {
			BackgroundColor3 = CONFETTI_COLORS[math.random(1, #CONFETTI_COLORS)],
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(size, size * 0.6),
			Position = UDim2.new(math.random(), 0, 0, -20),
			Rotation = math.random(0, 360),
			Parent = effectsRoot,
		})
		local duration = 1.6 + math.random() * 1.2
		UI.Tween(piece, duration, {
			Position = UDim2.new(piece.Position.X.Scale + (math.random() - 0.5) * 0.2, 0, 1, 40),
			Rotation = piece.Rotation + math.random(-360, 360),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(duration, function()
			piece:Destroy()
		end)
	end
end

function Effects.Flash(color: Color3)
	local flash = UI.New("Frame", {
		BackgroundColor3 = color,
		BackgroundTransparency = 0.2,
		Size = UDim2.fromScale(1, 1),
		Parent = effectsRoot,
	})
	UI.Tween(flash, 0.8, { BackgroundTransparency = 1 })
	task.delay(0.85, function()
		flash:Destroy()
	end)
end

local handlers: { [string]: (payload: { [string]: any }) -> () } = {}

handlers.Sound = function(payload)
	if typeof(payload.Name) == "string" then
		Sound.Play(payload.Name, 0.5)
	end
end

handlers.Collect = function(payload)
	Sound.Play("Cash", 0.45)
	if typeof(payload.Position) == "Vector3" and typeof(payload.Amount) == "number" then
		Effects.FloatingText(payload.Position, "+" .. Format.Money(payload.Amount))
	end
end

handlers.Confetti = function()
	Effects.Confetti()
end

handlers.Rebirth = function(payload)
	Sound.Play("Rebirth", 0.7)
	Effects.Flash(Color3.fromRGB(255, 240, 180))
	Effects.Confetti(70)
	Notifications.Announce(("♻️ REBIRTH %d!"):format(payload.Rebirths or 1), UI.Colors.Yellow, 4)
end

handlers.Offline = function(payload)
	local amount = payload.Amount or 0
	local seconds = payload.Seconds or 0
	task.delay(1.5, function()
		Windows.ShowMessage("💤 WELCOME BACK!", ("While you were away (%s) your slimes made\n%s!"):format(Format.Duration(seconds), Format.Money(amount)), "Collect!", UI.Colors.Green, function()
			Sound.Play("Cash", 0.6)
			Effects.Confetti(30)
		end)
	end)
end

handlers.DailyAvailable = function()
	Notifications.Show("📅 Your daily reward is ready! Open Daily.", "Success")
end

handlers.StealAlarm = function(payload)
	HUD.ShowAlarm(tostring(payload.Thief or "Someone"), tostring(payload.Slime or "slime"))
end

handlers.StealResolved = function()
	HUD.HideAlarm()
end

function Effects.Init()
	local _, root = UI.Screen("SlimeHeistEffects", 25)
	effectsRoot = root
	Remotes.Event("Effect").OnClientEvent:Connect(function(name, payload)
		local handler = handlers[name]
		if handler then
			local ok, err = pcall(handler, if typeof(payload) == "table" then payload else {})
			if not ok then
				warn("[Effects] " .. tostring(err))
			end
		end
	end)
	local _ = Players
end

return Effects
