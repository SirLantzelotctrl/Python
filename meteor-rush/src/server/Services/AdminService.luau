-- Comandos de administrador por chat (prefijo "!"). En Studio todos son admin.
--   !help                      lista de comandos
--   !stardust 1m               darte stardust (acepta k, m, b, t)
--   !meteor cosmic [zona]      hacer caer un meteorito (rareza) cerca de ti
--   !comet                     lanzar el cometa gigante ahora
--   !event BloodMoon [seg]     evento (MeteorShower, BloodMoon, GoldenHour)
--   !luck 5 10                 suerte x5 durante 10 min ("admin abuse")
--   !critter mythic [shiny]    darte una criatura de esa rareza (o id)
--   !zones                     desbloquear todas las zonas
--   !rebirth                   +1 supernova gratis
--   !reset                     BORRA tus datos

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Rarities = require(Shared.Rarities)
local Critters = require(Shared.Critters)
local Zones = require(Shared.Zones)

local Registry = require(script.Parent.Parent.Registry)
local Net = require(script.Parent.Parent.Net)

local AdminService = {}

local SUFFIXES = { k = 1e3, m = 1e6, b = 1e9, t = 1e12, qa = 1e15, qi = 1e18 }

local function parseAmount(text: string?): number?
	if not text then
		return nil
	end
	local number, suffix = string.match(string.lower(text), "^([%d%.e%+]+)(%a*)$")
	local value = tonumber(number)
	if not value then
		return nil
	end
	if suffix and suffix ~= "" then
		local mult = SUFFIXES[suffix]
		if not mult then
			return nil
		end
		value *= mult
	end
	return value
end

local function capitalize(text: string): string
	return string.upper(string.sub(text, 1, 1)) .. string.lower(string.sub(text, 2))
end

function AdminService.IsAdmin(player: Player): boolean
	if RunService:IsStudio() or table.find(Config.Admins, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(function()
		return player:GetRankInGroup(game.CreatorId)
	end)
	return ok and rank >= 254
end

local commands: { [string]: (Player, { string }) -> string? } = {}

commands.help = function()
	return "!stardust <n>, !meteor <rarity> [zone], !comet, !event <name> [sec], !luck <x> <min>, !critter <rarity|id> [shiny], !zones, !rebirth, !reset"
end

commands.stardust = function(player, args)
	local amount = parseAmount(args[1])
	if not amount or amount <= 0 then
		return "Usage: !stardust 1m"
	end
	Registry.DataService.AddStardust(player, amount, false)
	return "Gave " .. Format.Abbreviate(amount) .. " ⭐"
end

commands.meteor = function(player, args)
	local rarity = capitalize(args[1] or "legendary")
	if not Rarities.Exists(rarity) then
		return "Rarities: Common, Uncommon, Rare, Epic, Legendary, Mythic, Cosmic"
	end
	local data = Registry.DataService.Get(player)
	local zone = math.clamp(tonumber(args[2]) or math.max(1, Registry.ZoneService.GetCurrentZone(player)), 1, Zones.Count())
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local near = if root and root:IsA("BasePart") and Registry.ZoneService.GetCurrentZone(player) == zone then root.Position else nil
	local meteor = Registry.MeteorService.Spawn(zone, rarity, { Near = near })
	local _ = data
	return if meteor then ("%s meteor falling in zone %d"):format(rarity, zone) else "No space for a meteor"
end

commands.comet = function()
	return if Registry.CometService.Launch(nil) then "Comet launched!" else "A comet is already active (queued)"
end

commands.event = function(_player, args)
	local wanted = string.lower(args[1] or "")
	for _, name in Registry.EventService.GetEventNames() do
		if string.lower(name) == wanted then
			Registry.EventService.StartEvent(name, tonumber(args[2]))
			return "Started " .. name
		end
	end
	return "Events: " .. table.concat(Registry.EventService.GetEventNames(), ", ")
end

commands.luck = function(_player, args)
	local multiplier = tonumber(args[1]) or 5
	local minutes = tonumber(args[2]) or 10
	Registry.EventService.SetAdminLuck(multiplier, minutes * 60)
	return ("Luck x%s for %d min"):format(tostring(multiplier), minutes)
end

commands.critter = function(player, args)
	local arg = string.lower(args[1] or "legendary")
	local shiny = args[2] ~= nil and string.lower(args[2]) == "shiny"
	if Critters.Exists(arg) then
		Registry.CritterService.AddCritter(player, arg, shiny)
		return "Gave " .. arg
	end
	local rarity = capitalize(arg)
	if Rarities.Exists(rarity) then
		Registry.CritterService.GiveCritterOfRarity(player, rarity, nil, shiny, "admin")
		return "Gave a " .. rarity .. " critter"
	end
	return "Usage: !critter <rarity|id> [shiny]"
end

commands.zones = function(player)
	local data = Registry.DataService.Get(player)
	if data then
		data.Zone = Zones.Count()
		Registry.StatsService.Invalidate(player)
	end
	return "All zones unlocked"
end

commands.rebirth = function(player)
	local data = Registry.DataService.Get(player)
	if not data then
		return nil
	end
	data.Rebirths = math.min(data.Rebirths + 1, Config.Rebirth.MaxRebirths)
	Registry.StatsService.Invalidate(player)
	Registry.DataService.UpdateDisplay(player)
	Registry.PlayerService.UpdateOverhead(player)
	return "Supernovas: " .. data.Rebirths
end

commands.reset = function(player)
	Registry.DataService.ResetData(player)
	Registry.StatsService.Invalidate(player)
	Registry.CritterService.UpdateFollowers(player)
	Registry.MiningService.GivePickaxe(player)
	Registry.PlayerService.UpdateMovement(player)
	Registry.PlayerService.UpdateOverhead(player)
	Registry.ZoneService.Teleport(player, 1)
	return "Your data was reset"
end

function AdminService.Handle(player: Player, message: string)
	if string.sub(message, 1, 1) ~= "!" or not AdminService.IsAdmin(player) then
		return
	end
	local args = string.split(string.sub(message, 2), " ")
	local name = string.lower(table.remove(args, 1) or "")
	local command = commands[name]
	if not command then
		return
	end
	local ok, result = pcall(command, player, args)
	if ok then
		if result then
			Net.Notify(player, "[Admin] " .. result, "Info")
		end
	else
		Net.Notify(player, "[Admin] Error: " .. tostring(result), "Error")
	end
end

function AdminService.SetupPlayer(player: Player)
	player.Chatted:Connect(function(message)
		AdminService.Handle(player, message)
	end)
end

return AdminService
