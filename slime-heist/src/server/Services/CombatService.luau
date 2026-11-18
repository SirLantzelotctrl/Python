-- Bates: todos los jugadores llevan uno. Golpear a un ladrón le hace soltar el slime.
-- La detección del golpe es en el servidor; el empujón (knockback) lo aplica el cliente golpeado.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Gear = require(Shared.Gear)
local Remotes = require(Shared.Remotes)

local Registry = require(script.Parent.Parent.Registry)

local CombatService = {}

local lastSwing: { [Player]: number } = {}

local function playSound(parent: Instance, soundName: string, volume: number?)
	local id = Config.Sounds[soundName]
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.6
	sound.RollOffMaxDistance = 80
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 3)
end

local function buildBat(def: Gear.BatDef): Tool
	local tool = Instance.new("Tool")
	tool.Name = def.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = "Hit thieves to make them drop your slime!"
	tool.Grip = CFrame.fromMatrix(Vector3.new(0, 0, -1.6), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1))
	tool:SetAttribute("BatId", def.Id)
	CollectionService:AddTag(tool, "BatTool")

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.45, 0.45, 4.4)
	handle.Color = def.Color
	handle.Material = def.Material
	handle.CanCollide = false
	handle.Massless = true
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	local head = Instance.new("Part")
	head.Name = "BatHead"
	head.Shape = Enum.PartType.Cylinder
	head.Size = Vector3.new(2.4, 0.95, 0.95)
	head.CFrame = handle.CFrame * CFrame.new(0, 0, 1.5) * CFrame.Angles(0, math.pi / 2, 0)
	head.Color = def.Color
	head.Material = def.Material
	head.CanCollide = false
	head.Massless = true
	head.Parent = tool
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	weld.Parent = head

	if def.Id == "Galaxy" or def.Id == "Diamond" then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Color = ColorSequence.new(def.Color, Color3.fromRGB(255, 255, 255))
		sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
		sparkles.Lifetime = NumberRange.new(0.4, 0.8)
		sparkles.Rate = 12
		sparkles.Speed = NumberRange.new(0.5, 1.5)
		sparkles.LightEmission = 1
		sparkles.Parent = head
	end
	return tool
end

local function swing(player: Player, tool: Tool, def: Gear.BatDef)
	local now = os.clock()
	if (lastSwing[player] or 0) + def.Cooldown > now then
		return
	end
	lastSwing[player] = now
	local character = player.Character
	if not character or tool.Parent ~= character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return
	end

	-- Animación clásica de espada (la reproduce el script Animate por defecto)
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool
	Debris:AddItem(anim, 1)
	playSound(root, "Swing", 0.5)

	local hits = 0
	for _, other in Players:GetPlayers() do
		if other ~= player and hits < 3 then
			local otherCharacter = other.Character
			local otherRoot = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart")
			local otherHumanoid = otherCharacter and otherCharacter:FindFirstChildOfClass("Humanoid")
			if otherRoot and otherRoot:IsA("BasePart") and otherHumanoid and otherHumanoid.Health > 0 then
				local offset = otherRoot.Position - root.Position
				local distance = offset.Magnitude
				if distance <= def.Range then
					local flat = Vector3.new(offset.X, 0, offset.Z)
					local dir = if flat.Magnitude > 0.1 then flat.Unit else root.CFrame.LookVector
					local facing = root.CFrame.LookVector:Dot(dir)
					if facing > 0.15 or distance < 4 then
						hits += 1
						CombatService.Hit(player, other, dir, def)
					end
				end
			end
		end
	end
end

function CombatService.Hit(attacker: Player, victim: Player, dir: Vector3, def: Gear.BatDef)
	local character = victim.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	-- Bonus: si la víctima lleva un slime robado, el golpe es más fuerte
	local power = def.Knockback * (if Registry.StealService.IsCarrying(victim) then 1.25 else 1)
	local velocity = dir * power + Vector3.new(0, power * 0.45, 0)
	Remotes.Event("Knockback"):FireClient(victim, velocity)
	Registry.StealService.OnHit(victim)
	if root then
		playSound(root, "Hit", 0.7)
	end
	local _ = attacker
end

function CombatService.GiveBat(player: Player)
	local data = Registry.DataService.Get(player)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not data or not backpack then
		return
	end
	-- Quitamos bates anteriores
	for _, container in { backpack, character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and CollectionService:HasTag(child, "BatTool") then
					child:Destroy()
				end
			end
		end
	end

	local def = Gear.GetBat(data.EquippedBat) or Gear.Bats[1]
	if def.GamePass and not Registry.MonetizationService.OwnsPass(player, def.GamePass) then
		def = Gear.Bats[1]
	end
	local tool = buildBat(def)
	tool.Activated:Connect(function()
		swing(player, tool, def)
	end)
	tool.Parent = backpack
end

function CombatService.OnPlayerRemoving(player: Player)
	lastSwing[player] = nil
end

return CombatService
