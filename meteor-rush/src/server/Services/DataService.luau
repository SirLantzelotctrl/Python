-- Guardado con DataStore + bloqueo de sesión (evita duplicar criaturas entre servidores).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Gear = require(Shared.Gear)
local Zones = require(Shared.Zones)
local Critters = require(Shared.Critters)
local Remotes = require(Shared.Remotes)

local Registry = require(script.Parent.Parent.Registry)

local DataService = {}

local SESSION_TIMEOUT = 10 * 60
local LOAD_ATTEMPTS = 6
local AUTOSAVE_INTERVAL = 120
local MAX_RECEIPTS = 60

local DEFAULT_DATA = {
	Stardust = Config.StartingStardust,
	TotalStardust = 0,
	Rebirths = 0,
	Pickaxe = "Rusty",
	OwnedPickaxes = { Rusty = true },
	Zone = 1, -- zona más alta desbloqueada
	Critters = {}, -- ["c1"] = { Id = "pebblit", Shiny = false }
	NextCritter = 1,
	Equipped = {}, -- { "c1", "c4" }
	Index = {}, -- [critterId] = { Normal = true, Shiny = true }
	Upgrades = { Speed = 0, Crit = 0, Luck = 0 },
	Daily = { LastDay = 0, Streak = 0 },
	Codes = {},
	Boosts = { Stardust = 0, Damage = 0 },
	Quests = { Day = 0, List = {}, BonusClaimed = false },
	Stats = { Meteors = 0, RareMeteors = 0, MVPs = 0, Hatched = 0, Swings = 0, Crits = 0, Comets = 0, Playtime = 0 },
	Settings = { AutoDeleteCommon = false },
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
		elseif typeof(value) == "table" and typeof(target[key]) == "table" and next(value) ~= nil and #value == 0 then
			reconcile(target[key], value)
		end
	end
end

local function sanitize(data: any)
	if typeof(data.Stardust) ~= "number" or data.Stardust ~= data.Stardust then
		data.Stardust = Config.StartingStardust
	end
	data.Rebirths = math.clamp(math.floor(tonumber(data.Rebirths) or 0), 0, Config.Rebirth.MaxRebirths)
	data.Zone = math.clamp(math.floor(tonumber(data.Zone) or 1), 1, Zones.Count())
	data.OwnedPickaxes.Rusty = true
	if not Gear.GetPickaxe(data.Pickaxe) then
		data.Pickaxe = "Rusty"
	end
	for uid, entry in data.Critters do
		if typeof(entry) ~= "table" or not Critters.Exists(entry.Id) then
			data.Critters[uid] = nil
		end
	end
	local seen = {}
	local equipped = {}
	for _, uid in data.Equipped do
		if typeof(uid) == "string" and data.Critters[uid] and not seen[uid] then
			seen[uid] = true
			table.insert(equipped, uid)
		end
	end
	data.Equipped = equipped
	data.NextCritter = math.max(1, math.floor(tonumber(data.NextCritter) or 1))
end

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

local function setupLeaderstats(player: Player, data: any)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local stardust = Instance.new("StringValue")
	stardust.Name = "Stardust"
	stardust.Value = Format.Abbreviate(data.Stardust)
	stardust.Parent = folder
	local meteors = Instance.new("IntValue")
	meteors.Name = "Meteors"
	meteors.Value = data.Stats.Meteors
	meteors.Parent = folder
	local supernovas = Instance.new("IntValue")
	supernovas.Name = "Supernovas"
	supernovas.Value = data.Rebirths
	supernovas.Parent = folder
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
			warn("[DataService] DataStore no disponible (publica el juego y activa 'Enable Studio Access to API Services'). Los datos NO se guardarán. " .. tostring(probeError))
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
	player:SetAttribute("Stardust", data.Stardust)
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
-- Acceso
-- ---------------------------------------------------------------------
function DataService.Get(player: Player): any?
	return profiles[player]
end

function DataService.MarkDirty(player: Player)
	if profiles[player] then
		dirty[player] = true
	end
end

function DataService.UpdateDisplay(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	player:SetAttribute("Stardust", data.Stardust)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	local stardust = leaderstats:FindFirstChild("Stardust")
	if stardust and stardust:IsA("StringValue") then
		stardust.Value = Format.Abbreviate(data.Stardust)
	end
	local meteors = leaderstats:FindFirstChild("Meteors")
	if meteors and meteors:IsA("IntValue") then
		meteors.Value = data.Stats.Meteors
	end
	local supernovas = leaderstats:FindFirstChild("Supernovas")
	if supernovas and supernovas:IsA("IntValue") then
		supernovas.Value = data.Rebirths
	end
end

function DataService.AddStardust(player: Player, amount: number, countsAsEarned: boolean?)
	local data = profiles[player]
	if not data or amount ~= amount or amount <= 0 or amount == math.huge then
		return
	end
	data.Stardust += amount
	if countsAsEarned ~= false then
		data.TotalStardust += amount
	end
	DataService.UpdateDisplay(player)
end

function DataService.SpendStardust(player: Player, amount: number): boolean
	local data = profiles[player]
	if not data or amount ~= amount or amount < 0 or data.Stardust < amount then
		return false
	end
	data.Stardust -= amount
	DataService.UpdateDisplay(player)
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
	DataService.UpdateDisplay(player)
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
	local view: { [string]: any } = {
		Stardust = data.Stardust,
		TotalStardust = data.TotalStardust,
		Rebirths = data.Rebirths,
		Pickaxe = data.Pickaxe,
		OwnedPickaxes = data.OwnedPickaxes,
		Zone = data.Zone,
		Critters = data.Critters,
		Equipped = data.Equipped,
		Index = data.Index,
		Upgrades = data.Upgrades,
		Stats = data.Stats,
		Boosts = data.Boosts,
		Codes = data.Codes,
		Settings = data.Settings,
		InventoryLimit = Config.Critters.InventoryLimit,
		IsStudio = RunService:IsStudio(),
		SimulatePurchases = RunService:IsStudio() and Config.SimulatePurchasesInStudio,
		Persistent = persistent,
	}
	for _, name in { "MonetizationService", "StatsService", "CritterService", "QuestService", "RewardService" } do
		local service = Registry[name]
		if service and service.FillView then
			service.FillView(player, view)
		end
	end
	return view
end

return DataService
