-- Guardado de datos con DataStore + bloqueo de sesión (evita duplicar slimes
-- si un jugador entra en otro servidor antes de que el anterior guarde).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Economy = require(Shared.Economy)
local Slimes = require(Shared.Slimes)
local Mutations = require(Shared.Mutations)
local Gear = require(Shared.Gear)
local Remotes = require(Shared.Remotes)

local Registry = require(script.Parent.Parent.Registry)

local DataService = {}

local SESSION_TIMEOUT = 10 * 60
local LOAD_ATTEMPTS = 6
local AUTOSAVE_INTERVAL = 120
local MAX_RECEIPTS = 60

local DEFAULT_DATA = {
	Cash = Config.StartingCash,
	TotalEarned = 0,
	Rebirths = 0,
	Slimes = {}, -- ["1"] = { Id = "blobby", Mutation = "Normal" }
	Index = {}, -- [slimeId] = { [mutation] = true }
	OwnedBats = { Wood = true },
	EquippedBat = "Wood",
	Upgrades = { Speed = 0, Lock = 0 },
	Daily = { LastDay = 0, Streak = 0 },
	Codes = {},
	Boosts = { CashX2 = 0 },
	Stats = { Steals = 0, TimesRobbed = 0, Bought = 0, Playtime = 0, Sold = 0 },
	ReceiptIds = {},
	LastOnline = 0,
	Version = 1,
}

local profiles: { [Player]: any } = {}
local saving: { [Player]: boolean } = {}
local dirty: { [Player]: boolean } = {}
local store: DataStore? = nil
local persistent = false

local function deepCopy<T>(value: T): T
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value :: any do
		copy[key] = deepCopy(child)
	end
	return copy :: any
end

local function reconcile(target: { [any]: any }, template: { [any]: any })
	for key, value in template do
		if target[key] == nil then
			target[key] = deepCopy(value)
		elseif typeof(value) == "table" and typeof(target[key]) == "table" and next(value) ~= nil then
			reconcile(target[key], value)
		end
	end
end

local function sanitize(data: any)
	if typeof(data.Cash) ~= "number" or data.Cash ~= data.Cash then
		data.Cash = Config.StartingCash
	end
	data.Rebirths = math.clamp(math.floor(tonumber(data.Rebirths) or 0), 0, Config.Rebirth.MaxRebirths)
	local maxSlots = Economy.GetMaxPhysicalSlots()
	for key, entry in data.Slimes do
		local slot = tonumber(key)
		if typeof(entry) ~= "table" or not slot or slot < 1 or slot > maxSlots or not Slimes.Exists(entry.Id) then
			data.Slimes[key] = nil
		elseif not Mutations.Exists(entry.Mutation or "Normal") then
			entry.Mutation = "Normal"
		end
	end
	if not Gear.GetBat(data.EquippedBat) then
		data.EquippedBat = "Wood"
	end
	data.OwnedBats.Wood = true
end

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

local function setupLeaderstats(player: Player, data: any)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Value = Format.Money(data.Cash)
	cash.Parent = folder
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = data.Rebirths
	rebirths.Parent = folder
	local steals = Instance.new("IntValue")
	steals.Name = "Steals"
	steals.Value = data.Stats.Steals
	steals.Parent = folder
	folder.Parent = player
end

-- ---------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------
function DataService.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok and result then
		local probeOk, probeError = pcall(function()
			return result:GetAsync("__probe")
		end)
		if probeOk then
			store = result
			persistent = true
		else
			warn("[DataService] DataStore no disponible (¿publicaste el juego y activaste 'Enable Studio Access to API Services'?). Los datos NO se guardarán en esta sesión. " .. tostring(probeError))
		end
	else
		warn("[DataService] No se pudo abrir el DataStore: " .. tostring(result))
	end
end

function DataService.Start()
	local syncEvent = Remotes.Event("Sync")
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.2 then
			return
		end
		elapsed = 0
		for player in dirty do
			dirty[player] = nil
			if profiles[player] and player.Parent == Players then
				local ok, view = pcall(DataService.BuildView, player)
				if ok then
					syncEvent:FireClient(player, view)
				else
					warn("[DataService] Error construyendo la vista: " .. tostring(view))
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				task.spawn(DataService.Save, player, false)
			end
		end
	end)

	game:BindToClose(function()
		if not persistent then
			return
		end
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataService.Save(player, true)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.2)
		end
	end)
end

function DataService.IsPersistent(): boolean
	return persistent
end

function DataService.Load(player: Player): any?
	local data: any = nil
	if store then
		local key = keyFor(player)
		for attempt = 1, LOAD_ATTEMPTS do
			if player.Parent ~= Players then
				return nil
			end
			local wasLocked = false
			local ok, result = pcall(function()
				return (store :: DataStore):UpdateAsync(key, function(old)
					local now = os.time()
					local session = if typeof(old) == "table" then old._Session else nil
					if typeof(session) == "table" and session.JobId ~= game.JobId and now - (session.Time or 0) < SESSION_TIMEOUT and attempt < LOAD_ATTEMPTS then
						wasLocked = true
						return nil
					end
					local value = if typeof(old) == "table" then old else {}
					value._Session = { JobId = game.JobId, Time = now }
					return value
				end)
			end)
			if ok and typeof(result) == "table" then
				data = result
				break
			end
			if not ok then
				warn(("[DataService] Error cargando %s (intento %d): %s"):format(player.Name, attempt, tostring(result)))
			end
			task.wait(if wasLocked then 5 else 2)
		end
		if not data then
			player:Kick("We couldn't load your data. Please rejoin in a moment!")
			return nil
		end
	else
		data = {}
	end

	if player.Parent ~= Players then
		-- Se fue mientras cargábamos: liberamos el bloqueo de sesión
		if store then
			task.spawn(function()
				pcall(function()
					(store :: DataStore):UpdateAsync(keyFor(player), function(old)
						if typeof(old) == "table" and typeof(old._Session) == "table" and old._Session.JobId == game.JobId then
							old._Session = nil
							return old
						end
						return nil
					end)
				end)
			end)
		end
		return nil
	end

	data._Session = nil
	reconcile(data, DEFAULT_DATA)
	sanitize(data)
	profiles[player] = data

	setupLeaderstats(player, data)
	player:SetAttribute("Cash", data.Cash)
	player:SetAttribute("Rebirths", data.Rebirths)
	return data
end

function DataService.Save(player: Player, release: boolean): boolean
	local data = profiles[player]
	if not data or not store then
		return true
	end
	while saving[player] do
		task.wait(0.1)
	end
	saving[player] = true
	data.LastOnline = os.time()
	local snapshot = deepCopy(data)
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function(old)
			local session = if typeof(old) == "table" then old._Session else nil
			if typeof(session) == "table" and session.JobId ~= game.JobId and os.time() - (session.Time or 0) < SESSION_TIMEOUT then
				warn("[DataService] Otro servidor tiene la sesión de " .. player.Name .. "; no se sobrescribe.")
				return nil
			end
			snapshot._Session = if release then nil else { JobId = game.JobId, Time = os.time() }
			return snapshot
		end)
	end)
	saving[player] = nil
	if not ok then
		warn("[DataService] Error guardando " .. player.Name .. ": " .. tostring(err))
	end
	return ok
end

function DataService.Release(player: Player)
	if not profiles[player] then
		return
	end
	DataService.Save(player, true)
	profiles[player] = nil
	dirty[player] = nil
end

-- ---------------------------------------------------------------------
-- Acceso a datos
-- ---------------------------------------------------------------------
function DataService.Get(player: Player): any?
	return profiles[player]
end

function DataService.GetLoadedPlayers(): { Player }
	local list = {}
	for player in profiles do
		table.insert(list, player)
	end
	return list
end

function DataService.MarkDirty(player: Player)
	if profiles[player] then
		dirty[player] = true
	end
end

function DataService.UpdateCashDisplay(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	player:SetAttribute("Cash", data.Cash)
	local leaderstats = player:FindFirstChild("leaderstats")
	local cashValue = leaderstats and leaderstats:FindFirstChild("Cash")
	if cashValue and cashValue:IsA("StringValue") then
		cashValue.Value = Format.Money(data.Cash)
	end
end

function DataService.UpdateStatsDisplay(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	player:SetAttribute("Rebirths", data.Rebirths)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	local rebirths = leaderstats:FindFirstChild("Rebirths")
	if rebirths and rebirths:IsA("IntValue") then
		rebirths.Value = data.Rebirths
	end
	local steals = leaderstats:FindFirstChild("Steals")
	if steals and steals:IsA("IntValue") then
		steals.Value = data.Stats.Steals
	end
end

function DataService.AddCash(player: Player, amount: number, countsAsEarned: boolean?)
	local data = profiles[player]
	if not data or amount ~= amount or amount <= 0 or amount == math.huge then
		return
	end
	data.Cash += amount
	if countsAsEarned ~= false then
		data.TotalEarned += amount
	end
	DataService.UpdateCashDisplay(player)
end

function DataService.SpendCash(player: Player, amount: number): boolean
	local data = profiles[player]
	if not data or amount ~= amount or amount < 0 then
		return false
	end
	if data.Cash < amount then
		return false
	end
	data.Cash -= amount
	DataService.UpdateCashDisplay(player)
	return true
end

function DataService.HasReceipt(player: Player, receiptId: string): boolean
	local data = profiles[player]
	return data ~= nil and table.find(data.ReceiptIds, receiptId) ~= nil
end

function DataService.AddReceipt(player: Player, receiptId: string)
	local data = profiles[player]
	if not data then
		return
	end
	table.insert(data.ReceiptIds, receiptId)
	while #data.ReceiptIds > MAX_RECEIPTS do
		table.remove(data.ReceiptIds, 1)
	end
end

function DataService.Discover(player: Player, slimeId: string, mutation: string): boolean
	local data = profiles[player]
	if not data then
		return false
	end
	data.Index[slimeId] = data.Index[slimeId] or {}
	if data.Index[slimeId][mutation] then
		return false
	end
	data.Index[slimeId][mutation] = true
	return true
end

function DataService.ResetData(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	local receipts = data.ReceiptIds
	for key in data do
		data[key] = nil
	end
	reconcile(data, DEFAULT_DATA)
	data.ReceiptIds = receipts
	DataService.UpdateCashDisplay(player)
	DataService.UpdateStatsDisplay(player)
	DataService.MarkDirty(player)
end

-- ---------------------------------------------------------------------
-- Vista para el cliente
-- ---------------------------------------------------------------------
function DataService.BuildView(player: Player): { [string]: any }
	local data = profiles[player]
	if not data then
		return {}
	end
	local Monetization = Registry.MonetizationService
	local SlimeService = Registry.SlimeService
	local RewardService = Registry.RewardService

	local passes = if Monetization then Monetization.GetOwnedPasses(player) else {}
	local slotCount = Economy.GetSlotCount(data.Rebirths, passes.ExtraSlots == true)
	local used = 0
	for _ in data.Slimes do
		used += 1
	end

	local view = {
		Cash = data.Cash,
		TotalEarned = data.TotalEarned,
		Rebirths = data.Rebirths,
		Slimes = data.Slimes,
		Index = data.Index,
		OwnedBats = data.OwnedBats,
		EquippedBat = data.EquippedBat,
		Upgrades = data.Upgrades,
		Stats = data.Stats,
		Boosts = data.Boosts,
		Codes = data.Codes,
		Passes = passes,
		SlotCount = slotCount,
		UsedSlots = used,
		RebirthCost = Economy.GetRebirthCost(data.Rebirths),
		LockDuration = Economy.GetLockDuration(data.Rebirths, data.Upgrades.Lock, passes.LongerLock == true),
		IndexCount = Economy.CountIndex(data.Index),
		IndexTotal = Economy.GetIndexTotal(),
		PlotIndex = player:GetAttribute("PlotIndex"),
		IsStudio = RunService:IsStudio(),
		SimulatePurchases = RunService:IsStudio() and Config.SimulatePurchasesInStudio,
		Persistent = persistent,
	}

	if SlimeService then
		local multiplier, breakdown = SlimeService.GetMultiplier(player)
		view.Multiplier = multiplier
		view.MultiplierBreakdown = breakdown
		view.Income = SlimeService.GetIncomePerSecond(player)
	end
	if RewardService then
		RewardService.FillView(player, view)
	end
	return view
end

return DataService
