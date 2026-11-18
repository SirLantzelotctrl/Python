-- Picar: cada jugador lleva un pico (Tool). Los golpes se validan en el servidor.
-- Las criaturas equipadas ayudan (daño por segundo) y Auto Mine golpea solo.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Gear = require(Shared.Gear)

local Registry = require(script.Parent.Parent.Registry)
local Net = require(script.Parent.Parent.Net)

local MiningService = {}

local lastSwing: { [Player]: number } = {}
local lastTarget: { [Player]: number } = {}
local rng = Random.new()

local function buildPickaxe(def: Gear.PickaxeDef): Tool
	local tool = Instance.new("Tool")
	tool.Name = def.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = "Click near a meteor to mine it!"
	tool.Grip = CFrame.fromMatrix(Vector3.new(0, 0, -1.5), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1))
	tool:SetAttribute("PickaxeId", def.Id)
	CollectionService:AddTag(tool, "PickaxeTool")

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, 0.35, 4.2)
	handle.Color = def.Color
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local function attach(part: BasePart)
		part.CanCollide = false
		part.Massless = true
		part.Color = def.HeadColor
		part.Material = def.Material
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
		part.Parent = tool
	end

	if def.Id == "Galaxy" then
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Shape = Enum.PartType.Cylinder
		head.Size = Vector3.new(2.6, 1.6, 1.6)
		head.CFrame = handle.CFrame * CFrame.new(0, 0, 2)
		attach(head)
	else
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(3.2, 0.5, 0.6)
		head.CFrame = handle.CFrame * CFrame.new(0, 0, 1.85)
		attach(head)
		for _, side in { -1, 1 } do
			local tip = Instance.new("Part")
			tip.Name = "Tip"
			tip.Size = Vector3.new(0.9, 0.35, 0.45)
			tip.CFrame = head.CFrame * CFrame.new(side * 1.85, 0, -0.15) * CFrame.Angles(0, side * math.rad(25), 0)
			attach(tip)
		end
	end
	if def.Material == Enum.Material.Neon then
		local glow = Instance.new("PointLight")
		glow.Color = def.HeadColor
		glow.Range = 8
		glow.Brightness = 1.2
		glow.Parent = handle
	end
	return tool
end

function MiningService.GivePickaxe(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	if not backpack then
		return
	end
	for _, container in { backpack, character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and CollectionService:HasTag(child, "PickaxeTool") then
					child:Destroy()
				end
			end
		end
	end
	local stats = Registry.StatsService.Get(player)
	local def = Gear.GetPickaxe(if stats then stats.Pickaxe else "Rusty") or Gear.Pickaxes[1]
	local tool = buildPickaxe(def)
	tool.Activated:Connect(function()
		if tool.Parent == player.Character then
			MiningService.Swing(player, true)
		end
	end)
	tool.Parent = backpack
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid:EquipTool(tool)
	end
end

local function setTarget(player: Player, meteorId: number?)
	if meteorId then
		lastTarget[player] = os.clock()
		if player:GetAttribute("Target") ~= meteorId then
			player:SetAttribute("Target", meteorId)
		end
	elseif player:GetAttribute("Target") ~= nil and os.clock() - (lastTarget[player] or 0) > 2 then
		player:SetAttribute("Target", nil)
	end
end

-- Un golpe del jugador. animate = mostrar animación de la herramienta.
function MiningService.Swing(player: Player, animate: boolean): boolean
	local data = Registry.DataService.Get(player)
	if not data then
		return false
	end
	local cooldown = Registry.StatsService.GetCooldown(player)
	local t = os.clock()
	if (lastSwing[player] or 0) + cooldown * 0.9 > t then
		return false
	end
	lastSwing[player] = t

	if animate then
		local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
		if tool then
			local anim = Instance.new("StringValue")
			anim.Name = "toolanim"
			anim.Value = "Slash"
			anim.Parent = tool
			Debris:AddItem(anim, 1)
		end
	end

	local meteor = Registry.MeteorService.FindTarget(player)
	if not meteor then
		return false
	end
	local damage = Registry.StatsService.GetHitDamage(player)
	local crit = rng:NextNumber() < Registry.StatsService.GetCritChance(player)
	if crit then
		damage *= Config.Mining.CritMultiplier
	end
	local dealt = Registry.MeteorService.Damage(player, meteor, damage)
	if dealt <= 0 then
		return false
	end
	data.Stats.Swings += 1
	Registry.QuestService.Progress(player, "Swings", 1)
	if crit then
		data.Stats.Crits += 1
		Registry.QuestService.Progress(player, "Crits", 1)
	end
	setTarget(player, meteor.Id)
	Net.Effect(player, "Hit", { Position = meteor.Position + Vector3.new(0, meteor.Radius * 1.3, 0), Amount = damage, Crit = crit })
	return true
end

function MiningService.Start()
	-- Auto Mine (gamepass)
	task.spawn(function()
		while true do
			task.wait(Config.Mining.AutoMineInterval)
			for _, player in Players:GetPlayers() do
				if Registry.MonetizationService.OwnsPass(player, "AutoMine") then
					MiningService.Swing(player, true)
				end
			end
		end
	end)

	-- Criaturas que ayudan a picar
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local data = Registry.DataService.Get(player)
				if data then
					local helpers = #data.Equipped
					local meteor = if helpers > 0 then Registry.MeteorService.FindTarget(player, Config.Mining.HelperRange) else nil
					if meteor then
						local damage = Registry.StatsService.GetHitDamage(player) * Config.Mining.HelperDpsFactor * helpers
						if Registry.MeteorService.Damage(player, meteor, damage) > 0 then
							setTarget(player, meteor.Id)
						end
					else
						setTarget(player, nil)
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
		lastTarget[player] = nil
	end)
end

return MiningService
