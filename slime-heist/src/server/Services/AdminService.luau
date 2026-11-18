-- Comandos de administrador por chat (prefijo "!"). En Studio todos son admin.
--   !help                     lista de comandos
--   !cash 1m                  darte dinero
--   !spawn secret [galaxy]    hacer aparecer un slime (rareza o id) en la pasarela
--   !give omega_slime [gold]  mandar un slime directo a tu base
--   !event LuckyStorm [seg]   iniciar evento (LuckyStorm, GoldenHour, SlimeFrenzy, CashParty, MoneyRain)
--   !luck 5 10                suerte x5 durante 10 minutos ("admin abuse")
--   !rebirth                  +1 rebirth gratis
--   !lock                     bloquear tu base ya
--   !reset                    BORRA tus datos

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Slimes = require(Shared.Slimes)
local Rarities = require(Shared.Rarities)
local Mutations = require(Shared.Mutations)

local Registry = require(script.Parent.Parent.Registry)
local Net = require(script.Parent.Parent.Net)

local AdminService = {}

local SUFFIX_MULTIPLIERS = { k = 1e3, m = 1e6, b = 1e9, t = 1e12, qa = 1e15, qi = 1e18 }

local function parseAmount(text: string?): number?
	if not text then
		return nil
	end
	local lower = string.lower(text)
	local number, suffix = string.match(lower, "^([%d%.e%+]+)(%a*)$")
	local value = tonumber(number)
	if not value then
		return nil
	end
	if suffix and suffix ~= "" then
		local mult = SUFFIX_MULTIPLIERS[suffix]
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

local function resolveSlime(arg: string?): string?
	if not arg then
		return nil
	end
	local lower = string.lower(arg)
	if Slimes.Exists(lower) then
		return lower
	end
	local rarityName = capitalize(lower)
	if Rarities.Exists(rarityName) then
		return Economy.PickSlimeOfRarity(Random.new(), rarityName)
	end
	return nil
end

local function resolveMutation(arg: string?): string
	if not arg then
		return "Normal"
	end
	local name = capitalize(arg)
	return if Mutations.Exists(name) then name else "Normal"
end

function AdminService.IsAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if table.find(Config.Admins, player.UserId) then
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
	return "!cash <amt>, !spawn <rarity|id> [mut], !give <rarity|id> [mut], !event <name> [sec], !luck <x> <min>, !rebirth, !lock, !reset"
end

commands.cash = function(player, args)
	local amount = parseAmount(args[1])
	if not amount or amount <= 0 then
		return "Usage: !cash 1m"
	end
	Registry.DataService.AddCash(player, amount, false)
	return "Gave " .. Format.Money(amount)
end

commands.spawn = function(_player, args)
	local slimeId = resolveSlime(args[1])
	if not slimeId then
		return "Usage: !spawn <rarity|slime_id> [mutation]"
	end
	local mutation = resolveMutation(args[2])
	Registry.ConveyorService.Spawn(slimeId, mutation, 0, true)
	return "Spawned " .. slimeId .. " (" .. mutation .. ")"
end

commands.give = function(player, args)
	local slimeId = resolveSlime(args[1])
	if not slimeId then
		return "Usage: !give <rarity|slime_id> [mutation]"
	end
	local slot = Registry.SlimeService.GetFreeSlot(player)
	if not slot then
		return "Your base is full"
	end
	Registry.ConveyorService.SendToBase(player, slimeId, resolveMutation(args[2]), slot, nil)
	return "Sending " .. slimeId .. " to your base"
end

commands.event = function(_player, args)
	local wanted = args[1] and string.lower(args[1]) or ""
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

commands.rebirth = function(player)
	local data = Registry.DataService.Get(player)
	if not data then
		return nil
	end
	data.Rebirths = math.min(data.Rebirths + 1, Config.Rebirth.MaxRebirths)
	Registry.DataService.UpdateStatsDisplay(player)
	Registry.SlimeService.RefreshAll(player)
	Registry.SlimeService.InvalidateMultiplier(player)
	Registry.PlayerService.UpdateOverhead(player)
	return "Rebirths: " .. data.Rebirths
end

commands.lock = function(player)
	Registry.PlotService.TryLock(player, true)
	return "Locked"
end

commands.reset = function(player)
	Registry.StealService.CancelAllFor(player)
	Registry.DataService.ResetData(player)
	Registry.SlimeService.ResetPlayer(player)
	Registry.SlimeService.InvalidateMultiplier(player)
	Registry.CombatService.GiveBat(player)
	Registry.PlayerService.UpdateWalkSpeed(player)
	Registry.PlayerService.UpdateOverhead(player)
	return "Your data was reset"
end

function AdminService.Handle(player: Player, message: string)
	if string.sub(message, 1, 1) ~= "!" then
		return
	end
	if not AdminService.IsAdmin(player) then
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

function AdminService.Start()
	local _ = Players
end

return AdminService
