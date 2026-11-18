-- Mundo local: bolas de fuego que caen, cuenta atrás de impacto, puertas abiertas
-- para tus zonas, ambiente por zona, gravedad lunar y animaciones de etiquetas.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Models = require(Shared:WaitForChild("Models"))
local Zones = require(Shared:WaitForChild("Zones"))
local Config = require(Shared:WaitForChild("Config"))

local Modules = script.Parent.Parent.Modules
local UI = require(Modules.UI)
local State = require(Modules.State)

local World = {}

local player = Players.LocalPlayer

type Fall = { Marker: BasePart, Fireball: Model, Start: Vector3, Target: Vector3, StartTime: number, ImpactAt: number, Countdown: TextLabel? }

local falls: { [BasePart]: Fall } = {}
local rainbowParts: { [BasePart]: number } = {}
local gradients: { [UIGradient]: boolean } = {}
local spinners: { [BasePart]: CFrame } = {}
local fxFolder: Folder
local gravityForce: VectorForce? = nil

-- ---------------------------------------------------------------------
-- Meteoritos que caen
-- ---------------------------------------------------------------------
local function onMarker(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local impactAt = instance:GetAttribute("ImpactAt")
	if typeof(impactAt) ~= "number" then
		return
	end
	local comet = instance:GetAttribute("Comet") == true
	local fireball = Models.BuildFireball((instance:GetAttribute("Rarity") :: string?) or "Common", comet)
	local target = instance.Position
	local start = target + Vector3.new(-90, 280, 70) * (if comet then 1.6 else 1)
	fireball:PivotTo(CFrame.new(start))
	fireball.Parent = fxFolder
	local gui = instance:FindFirstChild("Warning")
	local countdown = gui and gui:FindFirstChild("Countdown")
	falls[instance] = {
		Marker = instance,
		Fireball = fireball,
		Start = start,
		Target = target,
		StartTime = Workspace:GetServerTimeNow(),
		ImpactAt = impactAt,
		Countdown = if countdown and countdown:IsA("TextLabel") then countdown else nil,
	}
end

local function onMarkerRemoved(instance: Instance)
	local fall = falls[instance :: BasePart]
	if fall then
		fall.Fireball:Destroy()
		falls[instance :: BasePart] = nil
	end
end

-- ---------------------------------------------------------------------
-- Puertas
-- ---------------------------------------------------------------------
local function updateGates()
	local data = State.Data
	local unlocked = if data then data.Zone or 1 else 1
	local map = Workspace:FindFirstChild("Map")
	if not map then
		return
	end
	for _, zone in Zones.List do
		local folder = map:FindFirstChild(zone.Id)
		local gate = folder and folder:FindFirstChild("Gate" .. zone.Index)
		if gate and gate:IsA("BasePart") then
			local open = zone.Index <= unlocked
			if gate.CanCollide == open then
				gate.CanCollide = not open
			end
			gate.Transparency = if open then 0.85 else 0
			local prompt = gate:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Enabled = not open and zone.Index == unlocked + 1
			end
			local sign = folder:FindFirstChild("GateSign")
			if sign then
				for _, gui in sign:GetChildren() do
					local price = gui:FindFirstChild("Price")
					if price and price:IsA("TextLabel") then
						price.Text = if open then "✅ UNLOCKED" else (if zone.Index == unlocked + 1 then "🔒 " else "🔒🔒 ") .. require(Shared:WaitForChild("Format")).Abbreviate(zone.Cost) .. " ⭐"
					end
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------
-- Ambiente por zona + gravedad lunar
-- ---------------------------------------------------------------------
local function applyAmbience()
	local zone = Zones.Get(player:GetAttribute("Zone") or 1)
	local bloodMoon = Workspace:GetAttribute("EventName") == "BloodMoon"
	UI.Tween(Lighting, 1.5, {
		ClockTime = if bloodMoon then 0 else zone.Ambient.ClockTime,
		Brightness = zone.Ambient.Brightness,
		Ambient = if bloodMoon then Color3.fromRGB(150, 50, 50) else zone.Ambient.Ambient,
		OutdoorAmbient = if bloodMoon then Color3.fromRGB(160, 60, 60) else zone.Ambient.Ambient:Lerp(Color3.new(1, 1, 1), 0.2),
	})
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		UI.Tween(atmosphere, 1.5, { Color = if bloodMoon then Color3.fromRGB(200, 60, 60) else zone.Ambient.Fog })
	end
	local correction = Lighting:FindFirstChild("ZoneColor")
	if correction and correction:IsA("ColorCorrectionEffect") then
		UI.Tween(correction, 1.5, { TintColor = if bloodMoon then Color3.fromRGB(255, 170, 170) else Color3.fromRGB(255, 255, 255) })
	end
end

local function updateGravity()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local zone = Zones.Get(player:GetAttribute("Zone") or 1)
	if not root or not root:IsA("BasePart") then
		return
	end
	if zone.LowGravity then
		if not gravityForce or gravityForce.Parent ~= root then
			local attachment = root:FindFirstChild("GravityAttachment") or Instance.new("Attachment")
			attachment.Name = "GravityAttachment"
			attachment.Parent = root
			local force = Instance.new("VectorForce")
			force.Name = "MoonGravity"
			force.Attachment0 = attachment :: Attachment
			force.RelativeTo = Enum.ActuatorRelativeTo.World
			force.ApplyAtCenterOfMass = true
			force.Parent = root
			gravityForce = force
		end
		local mass = root.AssemblyMass
		;(gravityForce :: VectorForce).Force = Vector3.new(0, mass * Workspace.Gravity * (1 - Config.Player.MoonGravityFactor), 0)
	elseif gravityForce then
		gravityForce:Destroy()
		gravityForce = nil
	end
end

-- ---------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------
local function track(tag: string, added: (Instance) -> (), removed: (Instance) -> ())
	CollectionService:GetInstanceAddedSignal(tag):Connect(added)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(removed)
	for _, instance in CollectionService:GetTagged(tag) do
		added(instance)
	end
end

function World.Init()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "LocalFX"
	fxFolder.Parent = Workspace

	track("MeteorMarker", onMarker, onMarkerRemoved)
	track("RainbowPart", function(instance)
		if instance:IsA("BasePart") then
			rainbowParts[instance] = math.random()
		end
	end, function(instance)
		rainbowParts[instance :: BasePart] = nil
	end)
	track("RainbowGradient", function(instance)
		if instance:IsA("UIGradient") then
			gradients[instance] = true
		end
	end, function(instance)
		gradients[instance :: UIGradient] = nil
	end)
	track("Spin", function(instance)
		if instance:IsA("BasePart") then
			spinners[instance] = instance.CFrame
		end
	end, function(instance)
		spinners[instance :: BasePart] = nil
	end)

	RunService.RenderStepped:Connect(function()
		local now = Workspace:GetServerTimeNow()
		local t = os.clock()
		for marker, fall in falls do
			if marker.Parent == nil then
				onMarkerRemoved(marker)
			else
				local total = math.max(0.1, fall.ImpactAt - fall.StartTime)
				local progress = math.clamp(1 - (fall.ImpactAt - now) / total, 0, 1)
				local position = fall.Start:Lerp(fall.Target, progress ^ 1.7)
				fall.Fireball:PivotTo(CFrame.new(position))
				if fall.Countdown then
					fall.Countdown.Text = tostring(math.max(0, math.ceil(fall.ImpactAt - now)))
				end
				marker.Transparency = 0.25 + math.abs(math.sin(t * 6)) * 0.4
			end
		end
		for part, offset in rainbowParts do
			if part.Parent == nil then
				rainbowParts[part] = nil
			else
				part.Color = Color3.fromHSV((t * 0.3 + offset) % 1, 0.6, 1)
			end
		end
		for gradient in gradients do
			if gradient.Parent == nil then
				gradients[gradient] = nil
			else
				gradient.Offset = Vector2.new(((t * 0.6) % 2) - 1, 0)
			end
		end
		for part, base in spinners do
			if part.Parent == nil then
				spinners[part] = nil
			else
				part.CFrame = base * CFrame.new(0, math.sin(t * 2) * 0.4, 0) * CFrame.Angles(0, t * 0.8, 0)
			end
		end
	end)

	State.Changed:Connect(updateGates)
	player:GetAttributeChangedSignal("Zone"):Connect(function()
		applyAmbience()
		updateGravity()
	end)
	Workspace:GetAttributeChangedSignal("EventName"):Connect(applyAmbience)
	player.CharacterAdded:Connect(function()
		gravityForce = nil
		task.wait(1)
		updateGravity()
	end)
	task.spawn(function()
		while true do
			pcall(updateGates)
			pcall(updateGravity)
			task.wait(2)
		end
	end)
	applyAmbience()
end

return World
