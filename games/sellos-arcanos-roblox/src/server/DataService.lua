-- Perfiles de jugador en DataStore: carga con bloqueo de sesión (evita
-- duplicar progreso al cambiar de servidor), autoguardado y guardado al salir.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local GameData = require(Shared.GameData)
local Net = require(Shared.Net)

local DataService = {}

local store = nil
local okStore = pcall(function()
	store = DataStoreService:GetDataStore(Config.DataStoreName)
end)
if not okStore then
	warn("[Sellos Arcanos] DataStore no disponible (activa «Studio Access to API Services» para probar el guardado en Studio).")
end

local profiles = {}
local dirty = {}
local LOCK_SECONDS = 1800
local jobId = game.JobId ~= "" and game.JobId or "studio"

local function today()
	return os.date("!%Y-%m-%d")
end
DataService.today = today

local function fresh()
	local bestiary = {}
	for _, c in ipairs(GameData.Creatures) do
		bestiary[c.id] = { seen = false, forms = { false, false, false } }
	end
	return {
		v = 1,
		created = os.time(),
		starterChosen = false,
		rankXp = 0,
		essence = 300,
		crystals = 0,
		ink = Config.InkMax,
		inkTs = os.time(),
		fragments = {},
		creatures = {}, -- id -> {form, level, xp, bond, bondXp, tint}
		team = {},
		bestiary = bestiary,
		islands = { unlocked = 1, cleared = {} },
		cosmetics = { tints = {}, seals = { "propio" }, effects = { "anillo" }, seal = "propio", effect = "anillo" },
		daily = { day = 0, last = "" },
		contracts = { date = "", list = {} },
		pass = { season = 1, xp = 0, premium = false, free = {}, prem = {} },
		purchases = { receipts = {}, founder = false },
		perks = { lastPremiumGift = "", lastVipGift = "", group = false },
		codes = {}, -- código -> fecha en que se canjeó
		stats = { seals = 0, perfect = 0, kills = 0, bosses = 0, ults = 0 },
		titles = {},
		milestones = {},
		settings = { music = 0.5, sfx = 0.8 },
	}
end
DataService.fresh = fresh

-- completa campos nuevos sin perder los existentes
local function reconcile(data, template)
	for k, v in pairs(template) do
		if data[k] == nil then
			data[k] = v
		elseif type(v) == "table" and type(data[k]) == "table" and #v == 0 and next(v) ~= nil then
			reconcile(data[k], v)
		end
	end
	return data
end

local function key(player)
	return "u_" .. player.UserId
end

function DataService.tickInk(p)
	local now = os.time()
	if p.ink >= Config.InkMax then
		p.inkTs = now
		return
	end
	local gained = math.floor((now - p.inkTs) / Config.InkSeconds)
	if gained > 0 then
		p.ink = math.min(Config.InkMax, p.ink + gained)
		p.inkTs = p.inkTs + gained * Config.InkSeconds
		if p.ink >= Config.InkMax then
			p.inkTs = now
		end
	end
end

function DataService.load(player)
	local data = nil
	if store then
		for attempt = 1, 4 do
			local ok, err = pcall(function()
				store:UpdateAsync(key(player), function(old)
					old = old or { data = nil, lock = nil }
					if old.lock and old.lock.job ~= jobId and os.time() - old.lock.t < LOCK_SECONDS and attempt < 4 then
						-- otro servidor lo tiene abierto: reintentamos más tarde
						data = "locked"
						return nil
					end
					data = old.data
					old.lock = { job = jobId, t = os.time() }
					return old
				end)
			end)
			if ok and data ~= "locked" then
				break
			end
			if not ok then
				warn("[Sellos Arcanos] error al cargar", err)
			end
			data = nil
			task.wait(2 * attempt)
		end
	end
	if data == "locked" then
		data = nil
	end
	local profile = reconcile(type(data) == "table" and data or fresh(), fresh())
	DataService.tickInk(profile)
	profiles[player] = profile
	return profile
end

function DataService.save(player, release)
	local profile = profiles[player]
	if not profile or not store then
		return
	end
	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function(old)
			old = old or {}
			old.data = profile
			if release then
				old.lock = nil
			else
				old.lock = { job = jobId, t = os.time() }
			end
			return old
		end)
	end)
	if not ok then
		warn("[Sellos Arcanos] error al guardar", err)
	end
	dirty[player] = nil
end

function DataService.get(player)
	return profiles[player]
end

-- Envía al cliente el perfil (o la parte que necesita la interfaz).
function DataService.sync(player)
	local p = profiles[player]
	if p then
		dirty[player] = true
		Net.get("ProfileSync"):FireClient(player, p)
	end
end

function DataService.release(player)
	DataService.save(player, true)
	profiles[player] = nil
end

function DataService.init()
	-- autoguardado cada 60 s y recarga de Tinta
	task.spawn(function()
		while true do
			task.wait(60)
			for player, p in pairs(profiles) do
				local before = p.ink
				DataService.tickInk(p)
				if p.ink ~= before then
					DataService.sync(player)
				end
				if dirty[player] then
					task.spawn(DataService.save, player, false)
				end
			end
		end
	end)
	game:BindToClose(function()
		local list = {}
		for player in pairs(profiles) do
			table.insert(list, player)
		end
		for _, player in ipairs(list) do
			task.spawn(DataService.save, player, true)
		end
		task.wait(3)
	end)
end

DataService.Players = Players
return DataService
