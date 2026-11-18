-- Pasarela central: aparecen slimes aleatorios, avanzan y se pueden comprar.
-- Al comprar, el slime camina hasta la base del jugador.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Slimes = require(Shared.Slimes)
local Rarities = require(Shared.Rarities)
local Mutations = require(Shared.Mutations)
local SlimeBuilder = require(Shared.SlimeBuilder)

local Registry = require(script.Parent.Parent.Registry)
local Layout = require(script.Parent.Parent.Layout)
local Net = require(script.Parent.Parent.Net)

local ConveyorService = {}

type Entry = {
	SlimeId: string,
	Mutation: string,
	Model: Model,
	Root: BasePart,
	Distance: number,
	Sold: boolean,
}

local belt: { Entry } = {}
local rng = Random.new()
local beltFolder: Folder
local walkingFolder: Folder

local startPos = Layout.RunwayStart
local endPos = Layout.RunwayEnd
local direction = (endPos - startPos).Unit
local length = (endPos - startPos).Magnitude

local function cframeAt(distance: number): CFrame
	local position = startPos + direction * distance
	return CFrame.lookAt(position, position + direction)
end

function ConveyorService.Start()
	local slimesFolder = workspace:WaitForChild("Slimes")
	beltFolder = Instance.new("Folder")
	beltFolder.Name = "Belt"
	beltFolder.Parent = slimesFolder
	walkingFolder = Instance.new("Folder")
	walkingFolder.Name = "Walking"
	walkingFolder.Parent = slimesFolder

	-- Llenamos la pasarela al arrancar para que no esté vacía
	local spacing = Config.Conveyor.Speed * Config.Conveyor.SpawnInterval
	local distance = length - spacing
	while distance > 0 do
		ConveyorService.SpawnRandom(distance)
		distance -= spacing
	end

	task.spawn(function()
		while true do
			local interval = Config.Conveyor.SpawnInterval / Registry.EventService.GetSpawnRateMultiplier()
			task.wait(interval)
			local ok, err = pcall(ConveyorService.SpawnRandom, 0)
			if not ok then
				warn("[ConveyorService] Error al crear slime: " .. tostring(err))
			end
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local speed = Config.Conveyor.Speed
		for index = #belt, 1, -1 do
			local entry = belt[index]
			entry.Distance += speed * dt
			if entry.Distance >= length or entry.Model.Parent == nil then
				table.remove(belt, index)
				if entry.Model.Parent then
					entry.Model:Destroy()
				end
			else
				entry.Root.CFrame = cframeAt(entry.Distance)
			end
		end
	end)
end

function ConveyorService.SpawnRandom(distance: number?)
	local rarity = Economy.RollRarity(rng, Registry.EventService.GetLuck())
	local slimeId = Economy.PickSlimeOfRarity(rng, rarity)
	local mutation = Economy.RollMutation(rng, Registry.EventService.GetMutationLuck())
	ConveyorService.Spawn(slimeId, mutation, distance, distance == nil or distance == 0)
end

function ConveyorService.Spawn(slimeId: string, mutation: string, distance: number?, announce: boolean?): Model?
	local def = Slimes.Get(slimeId)
	if not def then
		return nil
	end
	local rarity = Rarities.Get(def.Rarity)
	local price = Economy.GetSlimePrice(slimeId, mutation)

	local model = SlimeBuilder.Build(slimeId, mutation)
	SlimeBuilder.CreateBillboard(model, { Income = Economy.GetSlimeIncome(slimeId, mutation), Price = price })
	local root = model.PrimaryPart :: BasePart
	root.CFrame = cframeAt(distance or 0)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "Buy " .. Format.Money(price)
	prompt.ObjectText = def.Name
	prompt.HoldDuration = Config.Conveyor.BuyHoldDuration
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	local entry: Entry = {
		SlimeId = slimeId,
		Mutation = mutation,
		Model = model,
		Root = root,
		Distance = distance or 0,
		Sold = false,
	}
	prompt.Triggered:Connect(function(player)
		ConveyorService.TryBuy(player, entry)
	end)
	model.Parent = beltFolder
	table.insert(belt, entry)

	local mutationDef = Mutations.Get(mutation)
	if announce and (rarity.Announce or mutationDef.Multiplier >= 4) then
		local name = (if mutation ~= "Normal" then mutationDef.Name .. " " else "") .. def.Name
		Net.Announce(("%s %s appeared on the runway!"):format(string.upper(rarity.Name), name), if rarity.Name == "Secret" then Color3.fromRGB(255, 255, 255) else rarity.Color, 5)
		Net.EffectAll("Sound", { Name = "Announce" })
	end
	return model
end

function ConveyorService.TryBuy(player: Player, entry: Entry)
	if entry.Sold or not table.find(belt, entry) then
		return
	end
	local data = Registry.DataService.Get(player)
	if not data or not Registry.PlotService.GetPlot(player) then
		return
	end
	local slot = Registry.SlimeService.GetFreeSlot(player)
	if not slot then
		Net.Notify(player, "Your base is full! Sell a slime or Rebirth for more slots.", "Error")
		Net.Effect(player, "Sound", { Name = "Error" })
		return
	end
	local price = Economy.GetSlimePrice(entry.SlimeId, entry.Mutation)
	if not Registry.DataService.SpendCash(player, price) then
		Net.Notify(player, ("Not enough cash! You need %s"):format(Format.Money(price)), "Error")
		Net.Effect(player, "Sound", { Name = "Error" })
		return
	end

	entry.Sold = true
	local index = table.find(belt, entry)
	if index then
		table.remove(belt, index)
	end
	data.Stats.Bought += 1

	local def = Slimes.Get(entry.SlimeId)
	Net.Notify(player, ("Bought %s for %s!"):format(def and def.Name or "slime", Format.Money(price)), "Success")
	Net.Effect(player, "Sound", { Name = "Buy" })
	ConveyorService.SendToBase(player, entry.SlimeId, entry.Mutation, slot, entry.Model)
end

-- Hace caminar un slime hasta la base del jugador y lo registra en sus datos.
-- Si existingModel es nil, el slime sale del portal.
function ConveyorService.SendToBase(player: Player, slimeId: string, mutation: string, slot: number, existingModel: Model?): boolean
	local walker = existingModel
	if not walker then
		walker = SlimeBuilder.Build(slimeId, mutation)
		;(walker.PrimaryPart :: BasePart).CFrame = cframeAt(0)
	end
	local model = walker :: Model
	local root = model.PrimaryPart :: BasePart

	local prompt = root:FindFirstChild("BuyPrompt")
	if prompt then
		prompt:Destroy()
	end
	local oldInfo = root:FindFirstChild("Info")
	if oldInfo then
		oldInfo:Destroy()
	end
	SlimeBuilder.CreateBillboard(model, { Extra = player.DisplayName .. "'s", ExtraColor = Color3.fromRGB(120, 255, 140) })
	model.Parent = walkingFolder

	local addedSlot = Registry.SlimeService.AddSlime(player, slimeId, mutation, { Arriving = model, Slot = slot })
	if not addedSlot then
		model:Destroy()
		return false
	end

	task.spawn(function()
		local path = Registry.PlotService.GetEntrancePath(player, slot)
		for index, target in path do
			if model.Parent == nil then
				return
			end
			local current = root.Position
			local goal = target.Position
			local flat = Vector3.new(goal.X - current.X, 0, goal.Z - current.Z)
			local goalCFrame
			if index == #path then
				goalCFrame = target
			elseif flat.Magnitude > 0.05 then
				goalCFrame = CFrame.lookAt(goal, goal + flat.Unit)
			else
				goalCFrame = CFrame.new(goal) * root.CFrame.Rotation
			end
			if flat.Magnitude > 0.05 then
				root.CFrame = CFrame.lookAt(current, current + flat.Unit)
			end
			local duration = math.max(0.05, (goal - current).Magnitude / Config.Conveyor.WalkSpeed)
			local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = goalCFrame })
			tween:Play()
			task.wait(duration)
		end
		Registry.SlimeService.FinishArrival(player, slot, model)
	end)
	return true
end

return ConveyorService
