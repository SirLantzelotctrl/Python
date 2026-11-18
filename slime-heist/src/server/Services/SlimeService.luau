-- Slimes que posee cada jugador: modelos en los pedestales, ingresos por segundo,
-- recoger dinero, vender y multiplicadores.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Slimes = require(Shared.Slimes)
local Rarities = require(Shared.Rarities)
local Mutations = require(Shared.Mutations)
local SlimeBuilder = require(Shared.SlimeBuilder)

local Registry = require(script.Parent.Parent.Registry)
local Net = require(script.Parent.Parent.Net)

local SlimeService = {}

type PlayerSlimes = {
	Models: { [number]: Model },
	Stored: { [number]: number },
	Arriving: { [number]: Model },
	Hidden: { [number]: boolean },
	Multiplier: number,
	Breakdown: { any },
	MultiplierDirty: boolean,
	IndexCount: number,
}

local states: { [Player]: PlayerSlimes } = {}
local folder: Folder

local function slotKey(slot: number): string
	return tostring(slot)
end

local function getState(player: Player): PlayerSlimes?
	return states[player]
end

-- ---------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------
function SlimeService.Start()
	folder = Instance.new("Folder")
	folder.Name = "Owned"
	folder.Parent = workspace:WaitForChild("Slimes")

	task.spawn(function()
		while true do
			task.wait(1)
			for player in states do
				local ok, err = pcall(SlimeService.Tick, player)
				if not ok then
					warn("[SlimeService] Tick error: " .. tostring(err))
				end
			end
		end
	end)
end

function SlimeService.SetupPlayer(player: Player)
	local data = Registry.DataService.Get(player)
	states[player] = {
		Models = {},
		Stored = {},
		Arriving = {},
		Hidden = {},
		Multiplier = 1,
		Breakdown = {},
		MultiplierDirty = true,
		IndexCount = if data then Economy.CountIndex(data.Index) else 0,
	}
	SlimeService.RefreshAll(player)
end

function SlimeService.OnPlayerRemoving(player: Player)
	local state = states[player]
	if not state then
		return
	end
	-- El dinero sin recoger pasa a la cartera antes de guardar
	local total = 0
	for _, amount in state.Stored do
		total += amount
	end
	if total > 0 then
		Registry.DataService.AddCash(player, total, false)
	end
	for _, model in state.Models do
		model:Destroy()
	end
	for _, model in state.Arriving do
		model:Destroy()
	end
	states[player] = nil
end

-- ---------------------------------------------------------------------
-- Modelos
-- ---------------------------------------------------------------------
local function createPrompt(parent: Instance, name: string, actionText: string, objectText: string, hold: number, key: Enum.KeyCode, role: string, ownerId: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = hold
	prompt.KeyboardKeyCode = key
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt:SetAttribute("Role", role)
	prompt:SetAttribute("OwnerUserId", ownerId)
	CollectionService:AddTag(prompt, "RolePrompt")
	prompt.Parent = parent
	return prompt
end

function SlimeService.SpawnSlotModel(player: Player, slot: number)
	local state = states[player]
	local data = Registry.DataService.Get(player)
	if not state or not data then
		return
	end
	SlimeService.RemoveSlotModel(player, slot)
	local entry = data.Slimes[slotKey(slot)]
	if not entry or state.Arriving[slot] or state.Hidden[slot] then
		return
	end
	local cframe = Registry.PlotService.GetSlotCFrame(player, slot)
	if not cframe then
		return
	end

	local def = Slimes.Get(entry.Id)
	if not def then
		return
	end
	local model = SlimeBuilder.Build(entry.Id, entry.Mutation)
	model:PivotTo(cframe)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Slot", slot)
	CollectionService:AddTag(model, "OwnedSlime")

	local income = Economy.GetSlimeIncome(entry.Id, entry.Mutation) * state.Multiplier
	SlimeBuilder.CreateBillboard(model, { Income = income })

	local root = model.PrimaryPart :: BasePart
	local sellPrice = Economy.GetSellPrice(entry.Id, entry.Mutation)
	local sellPrompt = createPrompt(root, "SellPrompt", "Sell " .. Format.Money(sellPrice), def.Name, 1.2, Enum.KeyCode.F, "Owner", player.UserId)
	local stealPrompt = createPrompt(root, "StealPrompt", "Steal", def.Name, Config.Steal.HoldDuration, Enum.KeyCode.E, "Thief", player.UserId)

	sellPrompt.Triggered:Connect(function(who)
		if who == player then
			SlimeService.SellSlot(player, slot)
		end
	end)
	stealPrompt.Triggered:Connect(function(who)
		if who ~= player then
			Registry.StealService.TryStart(who, player, slot)
		end
	end)

	model.Parent = folder
	state.Models[slot] = model
	Registry.PlotService.SetSlotGlow(player, slot, Rarities.Get(def.Rarity).Color)
end

function SlimeService.RemoveSlotModel(player: Player, slot: number)
	local state = states[player]
	if not state then
		return
	end
	local model = state.Models[slot]
	if model then
		model:Destroy()
		state.Models[slot] = nil
	end
	Registry.PlotService.SetSlotGlow(player, slot, nil)
end

function SlimeService.RefreshAll(player: Player)
	local state = states[player]
	local data = Registry.DataService.Get(player)
	if not state or not data then
		return
	end
	state.MultiplierDirty = true
	SlimeService.GetMultiplier(player)
	Registry.PlotService.UpdateSlotCount(player, SlimeService.GetSlotCount(player))
	for slot = 1, Economy.GetMaxPhysicalSlots() do
		if data.Slimes[slotKey(slot)] then
			if not state.Arriving[slot] and not state.Hidden[slot] then
				SlimeService.SpawnSlotModel(player, slot)
			end
		else
			SlimeService.RemoveSlotModel(player, slot)
			state.Stored[slot] = nil
			Registry.PlotService.SetStoredText(player, slot, 0)
		end
	end
	Registry.DataService.MarkDirty(player)
end

-- Borra todos los modelos y estado temporal (rebirth / reset de datos) y reconstruye
function SlimeService.ResetPlayer(player: Player)
	local state = states[player]
	if not state then
		return
	end
	for _, model in state.Models do
		model:Destroy()
	end
	for _, model in state.Arriving do
		model:Destroy()
	end
	table.clear(state.Models)
	table.clear(state.Arriving)
	table.clear(state.Stored)
	table.clear(state.Hidden)
	local data = Registry.DataService.Get(player)
	state.IndexCount = if data then Economy.CountIndex(data.Index) else 0
	for slot = 1, Economy.GetMaxPhysicalSlots() do
		Registry.PlotService.SetStoredText(player, slot, 0)
		Registry.PlotService.SetSlotGlow(player, slot, nil)
	end
	SlimeService.RefreshAll(player)
	SlimeService.RefreshIncomeLabels(player)
end

-- Actualiza los textos $/s de los carteles cuando cambia el multiplicador
function SlimeService.RefreshIncomeLabels(player: Player)
	local state = states[player]
	if not state then
		return
	end
	for _, model in state.Models do
		local gui = model.PrimaryPart and model.PrimaryPart:FindFirstChild("Info")
		local incomeLabel = gui and gui:FindFirstChild("Income")
		if incomeLabel and incomeLabel:IsA("TextLabel") then
			local income = Economy.GetSlimeIncome(model:GetAttribute("SlimeId"), model:GetAttribute("Mutation")) * state.Multiplier
			incomeLabel.Text = Format.PerSecond(income)
		end
	end
end

-- ---------------------------------------------------------------------
-- Slots
-- ---------------------------------------------------------------------
function SlimeService.GetSlotCount(player: Player): number
	local data = Registry.DataService.Get(player)
	if not data then
		return 0
	end
	local passes = Registry.MonetizationService.GetOwnedPasses(player)
	return Economy.GetSlotCount(data.Rebirths, passes.ExtraSlots == true)
end

function SlimeService.GetFreeSlot(player: Player): number?
	local data = Registry.DataService.Get(player)
	local state = states[player]
	if not data or not state then
		return nil
	end
	for slot = 1, SlimeService.GetSlotCount(player) do
		if data.Slimes[slotKey(slot)] == nil and state.Arriving[slot] == nil then
			return slot
		end
	end
	return nil
end

function SlimeService.GetEntry(player: Player, slot: number): { Id: string, Mutation: string }?
	local data = Registry.DataService.Get(player)
	return data and data.Slimes[slotKey(slot)]
end

-- Añade un slime al primer slot libre. options.Arriving = el modelo llega andando (lo gestiona otro servicio)
function SlimeService.AddSlime(player: Player, slimeId: string, mutation: string, options: { Arriving: Model?, Slot: number? }?): number?
	local data = Registry.DataService.Get(player)
	local state = states[player]
	if not data or not state or not Slimes.Exists(slimeId) then
		return nil
	end
	local slot = (options and options.Slot) or SlimeService.GetFreeSlot(player)
	if not slot or data.Slimes[slotKey(slot)] ~= nil then
		return nil
	end
	data.Slimes[slotKey(slot)] = { Id = slimeId, Mutation = mutation }
	state.Stored[slot] = 0
	local isNew = Registry.DataService.Discover(player, slimeId, mutation)
	if isNew then
		state.IndexCount = Economy.CountIndex(data.Index)
		state.MultiplierDirty = true
		local def = Slimes.Get(slimeId)
		local mutationDef = Mutations.Get(mutation)
		local name = if mutation ~= "Normal" then mutationDef.Name .. " " .. (def and def.Name or slimeId) else (def and def.Name or slimeId)
		Net.Notify(player, "📖 New Index entry: " .. name .. "!", "Success")
	end
	if options and options.Arriving then
		state.Arriving[slot] = options.Arriving
	else
		SlimeService.SpawnSlotModel(player, slot)
	end
	if state.MultiplierDirty then
		SlimeService.GetMultiplier(player)
		SlimeService.RefreshIncomeLabels(player)
	end
	Registry.DataService.MarkDirty(player)
	return slot
end

function SlimeService.FinishArrival(player: Player, slot: number, walker: Model)
	local state = states[player]
	if walker then
		walker:Destroy()
	end
	if not state then
		return
	end
	if state.Arriving[slot] == walker then
		state.Arriving[slot] = nil
	end
	SlimeService.SpawnSlotModel(player, slot)
end

function SlimeService.RemoveSlime(player: Player, slot: number): { Id: string, Mutation: string }?
	local data = Registry.DataService.Get(player)
	local state = states[player]
	if not data or not state then
		return nil
	end
	local entry = data.Slimes[slotKey(slot)]
	if not entry then
		return nil
	end
	data.Slimes[slotKey(slot)] = nil
	-- El dinero acumulado se queda con el dueño
	local stored = state.Stored[slot] or 0
	if stored > 0 then
		Registry.DataService.AddCash(player, stored, false)
	end
	state.Stored[slot] = nil
	state.Hidden[slot] = nil
	SlimeService.RemoveSlotModel(player, slot)
	Registry.PlotService.SetStoredText(player, slot, 0)
	Registry.DataService.MarkDirty(player)
	return entry
end

-- Oculta/muestra un slime mientras lo están robando
function SlimeService.SetHidden(player: Player, slot: number, hidden: boolean)
	local state = states[player]
	if not state then
		return
	end
	state.Hidden[slot] = if hidden then true else nil
	if hidden then
		SlimeService.RemoveSlotModel(player, slot)
	else
		SlimeService.SpawnSlotModel(player, slot)
	end
end

function SlimeService.IsSlotBusy(player: Player, slot: number): boolean
	local state = states[player]
	return state == nil or state.Hidden[slot] == true or state.Arriving[slot] ~= nil
end

function SlimeService.SellSlot(player: Player, slot: number): boolean
	if SlimeService.IsSlotBusy(player, slot) then
		return false
	end
	local entry = SlimeService.GetEntry(player, slot)
	if not entry then
		return false
	end
	local price = Economy.GetSellPrice(entry.Id, entry.Mutation)
	SlimeService.RemoveSlime(player, slot)
	Registry.DataService.AddCash(player, price, false)
	local data = Registry.DataService.Get(player)
	if data then
		data.Stats.Sold += 1
	end
	local def = Slimes.Get(entry.Id)
	Net.Notify(player, ("Sold %s for %s"):format(def and def.Name or "slime", Format.Money(price)), "Cash")
	Net.Effect(player, "Sound", { Name = "Cash" })
	return true
end

-- ---------------------------------------------------------------------
-- Ingresos
-- ---------------------------------------------------------------------
function SlimeService.InvalidateMultiplier(player: Player)
	local state = states[player]
	if state then
		state.MultiplierDirty = true
		SlimeService.GetMultiplier(player)
		SlimeService.RefreshIncomeLabels(player)
		Registry.DataService.MarkDirty(player)
	end
end

function SlimeService.GetMultiplier(player: Player): (number, { any })
	local state = states[player]
	local data = Registry.DataService.Get(player)
	if not state or not data then
		return 1, {}
	end
	if state.MultiplierDirty then
		local passes = Registry.MonetizationService.GetOwnedPasses(player)
		local playerService = Registry.PlayerService
		local multiplier, breakdown = Economy.GetIncomeMultiplier({
			Rebirths = data.Rebirths,
			IndexCount = state.IndexCount,
			DoubleCash = passes.DoubleCash == true,
			VIP = passes.VIP == true,
			Friends = if playerService then playerService.GetFriendCount(player) else 0,
			Premium = player.MembershipType == Enum.MembershipType.Premium,
			InGroup = if playerService then playerService.IsInGroup(player) else false,
			Boost = (data.Boosts.CashX2 or 0) > 0,
			EventMultiplier = Registry.EventService.GetCashMultiplier(),
		})
		state.Multiplier = multiplier
		state.Breakdown = breakdown
		state.MultiplierDirty = false
	end
	return state.Multiplier, state.Breakdown
end

function SlimeService.InvalidateAll()
	for player in states do
		SlimeService.InvalidateMultiplier(player)
	end
end

function SlimeService.GetBaseIncome(player: Player): number
	local data = Registry.DataService.Get(player)
	if not data then
		return 0
	end
	local total = 0
	for _, entry in data.Slimes do
		total += Economy.GetSlimeIncome(entry.Id, entry.Mutation)
	end
	return total
end

function SlimeService.GetIncomePerSecond(player: Player): number
	local multiplier = SlimeService.GetMultiplier(player)
	return SlimeService.GetBaseIncome(player) * multiplier
end

function SlimeService.Tick(player: Player)
	local state = states[player]
	local data = Registry.DataService.Get(player)
	if not state or not data then
		return
	end

	-- Boost temporal x2
	if (data.Boosts.CashX2 or 0) > 0 then
		data.Boosts.CashX2 = math.max(0, data.Boosts.CashX2 - 1)
		player:SetAttribute("BoostCashX2", data.Boosts.CashX2)
		if data.Boosts.CashX2 == 0 then
			SlimeService.InvalidateMultiplier(player)
			Net.Notify(player, "⏫ Your 2x Cash boost ended", "Info")
		end
	end
	data.Stats.Playtime += 1

	local multiplier = SlimeService.GetMultiplier(player)
	local autoCollect = Registry.MonetizationService.OwnsPass(player, "AutoCollect")
	local direct = 0
	local total = 0
	for key, entry in data.Slimes do
		local slot = tonumber(key) :: number
		if not state.Hidden[slot] then
			local amount = Economy.GetSlimeIncome(entry.Id, entry.Mutation) * multiplier
			total += amount
			if autoCollect then
				direct += amount
			else
				state.Stored[slot] = (state.Stored[slot] or 0) + amount
				Registry.PlotService.SetStoredText(player, slot, state.Stored[slot])
			end
		end
	end
	if direct > 0 then
		Registry.DataService.AddCash(player, direct)
	end
	player:SetAttribute("Income", total)
	Registry.PlotService.SetSignIncome(player, total)
end

function SlimeService.CollectSlot(player: Player, slot: number)
	local state = states[player]
	if not state then
		return
	end
	local amount = state.Stored[slot] or 0
	if amount < 1 then
		return
	end
	state.Stored[slot] = 0
	Registry.DataService.AddCash(player, amount)
	Registry.PlotService.SetStoredText(player, slot, 0)
	local slotData = Registry.PlotService.GetSlot(player, slot)
	Net.Effect(player, "Collect", { Amount = amount, Position = if slotData then slotData.Pad.Position else nil })
end

function SlimeService.CollectAll(player: Player): number
	local state = states[player]
	if not state then
		return 0
	end
	local total = 0
	for slot, amount in state.Stored do
		total += amount
		state.Stored[slot] = 0
		Registry.PlotService.SetStoredText(player, slot, 0)
	end
	if total > 0 then
		Registry.DataService.AddCash(player, total)
	end
	return total
end

-- Slime aleatorio de una rareza (regalos, códigos, productos)
function SlimeService.GiveRandomOfRarity(player: Player, rarity: string, mutationLuck: number?): (boolean, string?)
	local rng = Random.new()
	local slimeId = Economy.PickSlimeOfRarity(rng, rarity)
	local mutation = Economy.RollMutation(rng, mutationLuck or 1)
	local def = Slimes.Get(slimeId)
	local slot = SlimeService.GetFreeSlot(player)
	if not slot then
		-- Sin espacio: se compensa con dinero
		local value = Economy.GetSlimePrice(slimeId, mutation)
		Registry.DataService.AddCash(player, value)
		Net.Notify(player, ("Base full! Got %s instead of %s"):format(Format.Money(value), def and def.Name or "a slime"), "Warning")
		return false, slimeId
	end
	Registry.ConveyorService.SendToBase(player, slimeId, mutation, slot, nil)
	return true, slimeId
end

return SlimeService
