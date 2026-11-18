-- Efectos que pide el servidor: botín, números de daño, impactos, roturas,
-- sonidos, confeti, supernova, abrir ventanas y pedir compras.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Format = require(Shared:WaitForChild("Format"))
local Rarities = require(Shared:WaitForChild("Rarities"))

local Modules = script.Parent.Parent.Modules
local UI = require(Modules.UI)
local Sound = require(Modules.Sound)
local Purchase = require(Modules.Purchase)

local Windows = require(script.Parent.Windows)
local Notifications = require(script.Parent.Notifications)
local Hatch = require(script.Parent.Hatch)

local Effects = {}

local player = Players.LocalPlayer
local effectsRoot: Frame
local CONFETTI = {
	Color3.fromRGB(255, 90, 90),
	Color3.fromRGB(255, 220, 80),
	Color3.fromRGB(90, 255, 140),
	Color3.fromRGB(90, 180, 255),
	Color3.fromRGB(220, 110, 255),
}

function Effects.FloatingText(position: Vector3, text: string, color: Color3?, size: number?)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position + Vector3.new(math.random(-15, 15) / 10, 0, math.random(-15, 15) / 10)
	attachment.Parent = Workspace.Terrain
	local scale = size or 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(5 * scale, 0, 1.4 * scale, 0)
	gui.StudsOffset = Vector3.new(0, 1, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = attachment
	local label = UI.Text({ Text = text, TextColor3 = color or Color3.fromRGB(255, 230, 110), StrokeThickness = 3, Parent = gui })
	UI.Tween(gui, 0.9, { StudsOffset = Vector3.new(0, 5, 0) })
	task.delay(0.45, function()
		UI.Tween(label, 0.45, { TextTransparency = 1 })
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			UI.Tween(stroke, 0.45, { Transparency = 1 })
		end
	end)
	Debris:AddItem(attachment, 1)
end

function Effects.Confetti(amount: number?)
	for _ = 1, amount or 45 do
		local size = math.random(10, 18)
		local piece = UI.New("Frame", {
			BackgroundColor3 = CONFETTI[math.random(1, #CONFETTI)],
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(size, size * 0.6),
			Position = UDim2.new(math.random(), 0, 0, -20),
			Rotation = math.random(0, 360),
			Parent = effectsRoot,
		})
		local duration = 1.6 + math.random() * 1.2
		UI.Tween(piece, duration, { Position = UDim2.new(piece.Position.X.Scale + (math.random() - 0.5) * 0.2, 0, 1, 40), Rotation = piece.Rotation + math.random(-360, 360) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(duration, function()
			piece:Destroy()
		end)
	end
end

function Effects.Flash(color: Color3, strength: number?)
	local flash = UI.New("Frame", { BackgroundColor3 = color, BackgroundTransparency = 1 - (strength or 0.8), Size = UDim2.fromScale(1, 1), Parent = effectsRoot })
	UI.Tween(flash, 0.7, { BackgroundTransparency = 1 })
	task.delay(0.75, function()
		flash:Destroy()
	end)
end

-- Temblor de cámara (desplaza la cámara del humanoide)
function Effects.Shake(intensity: number, duration: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration do
			local falloff = 1 - elapsed / duration
			humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * intensity * falloff, (math.random() - 0.5) * intensity * falloff, 0)
			elapsed += task.wait()
		end
		humanoid.CameraOffset = Vector3.zero
	end)
end

-- Trozos de roca que salen volando (solo local)
function Effects.Debris(position: Vector3, color: Color3, count: number, size: number)
	for _ = 1, count do
		local piece = Instance.new("Part")
		piece.Size = Vector3.one * size * (0.5 + math.random())
		piece.Color = if math.random() < 0.5 then color else Color3.fromRGB(80, 75, 85)
		piece.Material = if math.random() < 0.5 then Enum.Material.Neon else Enum.Material.Slate
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.Anchored = true
		piece.CFrame = CFrame.new(position + Vector3.new(0, size * 2, 0))
		piece.Parent = Workspace.Terrain
		local target = position + Vector3.new((math.random() - 0.5) * 30, math.random() * 14 + 2, (math.random() - 0.5) * 30)
		UI.Tween(piece, 0.8, { CFrame = CFrame.new(target) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), Transparency = 1, Size = piece.Size * 0.3 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		Debris:AddItem(piece, 0.9)
	end
end

local function distanceTo(position: Vector3): number
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return (root.Position - position).Magnitude
	end
	return math.huge
end

local handlers: { [string]: (payload: { [string]: any }) -> () } = {}

handlers.Sound = function(payload)
	if typeof(payload.Name) == "string" then
		Sound.Play(payload.Name, 0.5)
	end
end

handlers.Hit = function(payload)
	if typeof(payload.Position) ~= "Vector3" then
		return
	end
	Sound.Play(if payload.Crit then "Crit" else "Hit", 0.35)
	local amount = Format.Abbreviate(payload.Amount or 0)
	if payload.Crit then
		Effects.FloatingText(payload.Position, "💥" .. amount, Color3.fromRGB(255, 150, 60), 1.4)
	else
		Effects.FloatingText(payload.Position, amount, Color3.fromRGB(255, 255, 255), 1)
	end
end

handlers.Loot = function(payload)
	Sound.Play("Stardust", 0.6)
	if typeof(payload.Position) == "Vector3" then
		Effects.FloatingText(payload.Position + Vector3.new(0, 6, 0), "+" .. Format.Abbreviate(payload.Amount or 0) .. " ⭐", Color3.fromRGB(255, 225, 90), 1.8)
	end
	if payload.MVP then
		Notifications.Announce("🏅 MVP! +25% stardust", Color3.fromRGB(255, 215, 70), 2)
	end
end

handlers.Impact = function(payload)
	if typeof(payload.Position) ~= "Vector3" then
		return
	end
	local distance = distanceTo(payload.Position)
	local rarity = Rarities.Get(payload.Rarity or "Common")
	local color = if payload.Comet then Color3.fromRGB(140, 230, 255) else rarity.Color
	if distance < 160 then
		Sound.Play("Impact", math.clamp(1 - distance / 160, 0.15, 0.8))
		Effects.Shake(if payload.Comet then 3 else 1.2, if payload.Comet then 1 else 0.45)
		Effects.Debris(payload.Position, color, if payload.Comet then 30 else 12, (payload.Radius or 3) * 0.25)
	end
	if distance < 40 or payload.Comet then
		Effects.Flash(color, if payload.Comet then 0.5 else 0.25)
	end
end

handlers.Break = function(payload)
	if typeof(payload.Position) ~= "Vector3" then
		return
	end
	if distanceTo(payload.Position) < 200 then
		local rarity = Rarities.Get(payload.Rarity or "Common")
		Sound.Play("Break", 0.5)
		Effects.Debris(payload.Position, if payload.Comet then Color3.fromRGB(140, 230, 255) else rarity.Color, if payload.Comet then 40 else 18, (payload.Radius or 3) * 0.3)
	end
end

handlers.Confetti = function()
	Effects.Confetti()
end

handlers.Supernova = function(payload)
	Sound.Play("Supernova", 0.8)
	Effects.Flash(Color3.fromRGB(255, 220, 255), 0.9)
	Effects.Confetti(80)
	Notifications.Announce(("🌟 SUPERNOVA %d!"):format(payload.Rebirths or 1), Color3.fromRGB(255, 150, 230), 4)
end

handlers.OpenWindow = function(payload)
	if typeof(payload.Name) == "string" then
		Windows.Open(payload.Name)
	end
end

handlers.PromptPass = function(payload)
	if typeof(payload.Key) == "string" then
		Purchase.PromptPass(payload.Key)
	end
end

handlers.Hatch = function(payload)
	if typeof(payload.Results) == "table" then
		Hatch.Play(tonumber(payload.Egg) or 1, payload.Results)
	end
end

handlers.DailyAvailable = function()
	Notifications.Show("📅 Your daily reward is ready! Open Daily.", "Success")
end

handlers.CometIncoming = function()
	Sound.Play("Announce", 0.7)
end

function Effects.Init()
	local _, root = UI.Screen("MeteorRushEffects", 25)
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
end

return Effects
