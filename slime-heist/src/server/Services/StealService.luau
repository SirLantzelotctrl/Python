-- Robos: coger el slime de otra base, llevarlo encima de la cabeza y llegar a tu base.
-- El slime NO cambia de dueño en los datos hasta que el robo termina (sin duplicados).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Slimes = require(Shared.Slimes)
local Rarities = require(Shared.Rarities)
local Mutations = require(Shared.Mutations)
local SlimeBuilder = require(Shared.SlimeBuilder)

local Registry = require(script.Parent.Parent.Registry)
local Net = require(script.Parent.Parent.Net)

local StealService = {}

type Theft = {
	Thief: Player,
	Victim: Player,
	Slot: number,
	SlimeId: string,
	Mutation: string,
	Model: Model,
	Started: number,
	StartPosition: Vector3,
}

local thefts: { [Player]: Theft } = {}
local cooldowns: { [Player]: number } = {}
local carriedFolder: Folder

local function slimeName(slimeId: string, mutation: string): string
	local def = Slimes.Get(slimeId)
	local name = def and def.Name or slimeId
	if mutation ~= "Normal" then
		name = Mutations.Get(mutation).Name .. " " .. name
	end
	return name
end

local function getRoot(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil, nil
end

function StealService.Start()
	carriedFolder = Instance.new("Folder")
	carriedFolder.Name = "Carried"
	carriedFolder.Parent = workspace:WaitForChild("Slimes")

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.1 then
			return
		end
		elapsed = 0
		for thief, theft in thefts do
			local ok, err = pcall(StealService.Check, thief, theft)
			if not ok then
				warn("[StealService] " .. tostring(err))
				StealService.Cancel(thief, "error")
			end
		end
	end)
end

function StealService.IsCarrying(player: Player): boolean
	return thefts[player] ~= nil
end

function StealService.GetVictim(thief: Player): Player?
	local theft = thefts[thief]
	return theft and theft.Victim
end

function StealService.IsBeingStolen(victim: Player, slot: number): boolean
	for _, theft in thefts do
		if theft.Victim == victim and theft.Slot == slot then
			return true
		end
	end
	return false
end

function StealService.TryStart(thief: Player, victim: Player, slot: number)
	if thief == victim or thefts[thief] then
		if thefts[thief] then
			Net.Notify(thief, "You're already carrying a slime!", "Error")
		end
		return
	end
	if (cooldowns[thief] or 0) > os.clock() then
		return
	end
	local victimPlot = Registry.PlotService.GetPlot(victim)
	local thiefPlot = Registry.PlotService.GetPlot(thief)
	if not victimPlot or not thiefPlot then
		return
	end
	if Registry.PlotService.IsLocked(victimPlot) then
		Net.Notify(thief, "🔒 That base is locked!", "Error")
		return
	end
	if Registry.SlimeService.IsSlotBusy(victim, slot) or StealService.IsBeingStolen(victim, slot) then
		return
	end
	local entry = Registry.SlimeService.GetEntry(victim, slot)
	if not entry then
		return
	end
	if not Registry.SlimeService.GetFreeSlot(thief) then
		Net.Notify(thief, "Your base is full! Sell a slime first.", "Error")
		Net.Effect(thief, "Sound", { Name = "Error" })
		return
	end
	local root = getRoot(thief)
	local slotCFrame = Registry.PlotService.GetSlotCFrame(victim, slot)
	if not root or not slotCFrame or (root.Position - slotCFrame.Position).Magnitude > 16 then
		return
	end

	-- Construimos el slime que va encima de la cabeza
	local model = SlimeBuilder.Build(entry.Id, entry.Mutation, { Scale = 0.75 })
	local modelRoot = model.PrimaryPart :: BasePart
	modelRoot.CFrame = root.CFrame * CFrame.new(0, 2.7, 0)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.Massless = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = modelRoot
	weld.Parent = modelRoot
	SlimeBuilder.CreateBillboard(model, { Extra = "😈 STOLEN!", ExtraColor = Color3.fromRGB(255, 80, 80) })
	model.Parent = carriedFolder

	Registry.SlimeService.SetHidden(victim, slot, true)

	thefts[thief] = {
		Thief = thief,
		Victim = victim,
		Slot = slot,
		SlimeId = entry.Id,
		Mutation = entry.Mutation,
		Model = model,
		Started = os.clock(),
		StartPosition = root.Position,
	}

	local name = slimeName(entry.Id, entry.Mutation)
	thief:SetAttribute("Carrying", name)
	Registry.PlayerService.UpdateWalkSpeed(thief)
	Net.Notify(thief, ("😈 You grabbed %s! Run back to YOUR base!"):format(name), "Warning")
	Net.Effect(thief, "Sound", { Name = "Steal" })
	Net.Effect(victim, "StealAlarm", { Thief = thief.DisplayName, Slime = name })
	Net.Notify(victim, ("⚠️ %s is stealing your %s! Hit them with your bat!"):format(thief.DisplayName, name), "Error")
end

function StealService.Check(thief: Player, theft: Theft)
	if thief.Parent ~= Players or theft.Victim.Parent ~= Players then
		StealService.Cancel(thief, "left")
		return
	end
	local root = getRoot(thief)
	if not root then
		StealService.Cancel(thief, "died")
		return
	end
	if theft.Model.Parent == nil then
		StealService.Cancel(thief, "lost")
		return
	end
	if os.clock() - theft.Started > Config.Steal.Timeout then
		StealService.Cancel(thief, "timeout")
		return
	end
	local thiefPlot = Registry.PlotService.GetPlot(thief)
	if thiefPlot and Registry.PlotService.Contains(thiefPlot, root.Position) then
		-- Anti-teleport: no se puede llegar más rápido de lo que permite la velocidad de andar
		local humanoid = thief.Character and thief.Character:FindFirstChildOfClass("Humanoid")
		local speed = math.max(humanoid and humanoid.WalkSpeed or 16, 16)
		local distance = (root.Position - theft.StartPosition).Magnitude
		local minimumTime = distance / (speed * 1.6 + 6)
		if os.clock() - theft.Started < minimumTime then
			warn(("[StealService] Robo sospechoso de %s (%.0f studs en %.1fs)"):format(thief.Name, distance, os.clock() - theft.Started))
			StealService.Cancel(thief, "suspicious")
			return
		end
		StealService.Complete(thief)
	end
end

local function cleanupThief(thief: Player, theft: Theft)
	thefts[thief] = nil
	if theft.Model then
		theft.Model:Destroy()
	end
	if thief.Parent == Players then
		thief:SetAttribute("Carrying", nil)
		Registry.PlayerService.UpdateWalkSpeed(thief)
	end
end

function StealService.Complete(thief: Player)
	local theft = thefts[thief]
	if not theft then
		return
	end
	cleanupThief(thief, theft)
	local victim = theft.Victim

	local entry = Registry.SlimeService.GetEntry(victim, theft.Slot)
	if not entry or entry.Id ~= theft.SlimeId or entry.Mutation ~= theft.Mutation then
		Registry.SlimeService.SetHidden(victim, theft.Slot, false)
		return
	end
	local freeSlot = Registry.SlimeService.GetFreeSlot(thief)
	if not freeSlot then
		Registry.SlimeService.SetHidden(victim, theft.Slot, false)
		Net.Notify(thief, "Your base is full! The slime ran back home.", "Error")
		Net.Effect(victim, "StealResolved", { Stolen = false })
		return
	end

	-- Transferencia atómica (sin yields entre quitar y dar)
	Registry.SlimeService.RemoveSlime(victim, theft.Slot)
	Registry.SlimeService.AddSlime(thief, theft.SlimeId, theft.Mutation, { Slot = freeSlot })

	local thiefData = Registry.DataService.Get(thief)
	local victimData = Registry.DataService.Get(victim)
	if thiefData then
		thiefData.Stats.Steals += 1
		Registry.DataService.UpdateStatsDisplay(thief)
	end
	if victimData then
		victimData.Stats.TimesRobbed += 1
	end

	local name = slimeName(theft.SlimeId, theft.Mutation)
	Net.Notify(thief, ("💰 You stole %s from %s!"):format(name, victim.DisplayName), "Success")
	Net.Effect(thief, "Sound", { Name = "Cash" })
	Net.Effect(thief, "Confetti", {})
	Net.Notify(victim, ("😭 %s stole your %s!"):format(thief.DisplayName, name), "Error")
	Net.Effect(victim, "StealResolved", { Stolen = true })

	local def = Slimes.Get(theft.SlimeId)
	local rarity = def and Rarities.Get(def.Rarity)
	if rarity and rarity.Order >= Config.Steal.AnnounceMinRarityOrder then
		Net.Announce(("😈 %s stole a %s %s from %s!"):format(thief.DisplayName, string.upper(rarity.Name), name, victim.DisplayName), if rarity.Name == "Secret" then Color3.fromRGB(255, 255, 255) else rarity.Color, 5)
	end
	Registry.DataService.MarkDirty(thief)
	Registry.DataService.MarkDirty(victim)
end

function StealService.Cancel(thief: Player, reason: string)
	local theft = thefts[thief]
	if not theft then
		return
	end
	cleanupThief(thief, theft)
	cooldowns[thief] = os.clock() + Config.Steal.FailCooldown
	local victim = theft.Victim
	if victim.Parent == Players then
		Registry.SlimeService.SetHidden(victim, theft.Slot, false)
		Net.Effect(victim, "StealResolved", { Stolen = false })
		if reason ~= "left" then
			Net.Notify(victim, ("🛡️ Your %s is back home!"):format(slimeName(theft.SlimeId, theft.Mutation)), "Success")
		end
	end
	if thief.Parent == Players then
		local message = if reason == "hit"
			then "💥 You got hit and dropped the slime!"
			elseif reason == "timeout" then "⏱️ Too slow! The slime escaped."
			elseif reason == "locked" then "🔒 The base locked! The slime ran back home."
			elseif reason == "died" then "The slime escaped!"
			else nil
		if message then
			Net.Notify(thief, message, "Error")
		end
	end
end

function StealService.OnHit(target: Player)
	if thefts[target] then
		StealService.Cancel(target, "hit")
	end
end

function StealService.OnDeath(player: Player)
	if thefts[player] then
		StealService.Cancel(player, "died")
	end
end

function StealService.OnPlayerRemoving(player: Player)
	if thefts[player] then
		StealService.Cancel(player, "left")
	end
	for thief, theft in thefts do
		if theft.Victim == player then
			StealService.Cancel(thief, "left")
			Net.Notify(thief, "The owner left. The slime vanished!", "Error")
		end
	end
	cooldowns[player] = nil
end

-- Cancela robos de un jugador concreto (p.ej. al hacer rebirth)
function StealService.CancelAllFor(victim: Player)
	for thief, theft in thefts do
		if theft.Victim == victim then
			StealService.Cancel(thief, "reset")
		end
	end
end

return StealService
