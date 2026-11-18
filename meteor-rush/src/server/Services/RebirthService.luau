-- 🌟 Supernova (rebirth): reinicia Stardust, picos y zonas a cambio de
-- +50% stardust, +25% daño y +1 hueco de criatura permanentes. Las criaturas se conservan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)

local Registry = require(script.Parent.Parent.Registry)
local Actions = require(script.Parent.Parent.Actions)
local Net = require(script.Parent.Parent.Net)

local RebirthService = {}

function RebirthService.DoRebirth(player: Player): (boolean, string?)
	local data = Registry.DataService.Get(player)
	if not data then
		return false, "Data not loaded"
	end
	if data.Rebirths >= Config.Rebirth.MaxRebirths then
		return false, "Max supernovas reached!"
	end
	local cost = Economy.GetRebirthCost(data.Rebirths)
	if data.Stardust < cost then
		return false, ("You need %s ⭐"):format(Format.Abbreviate(cost))
	end
	data.Rebirths += 1
	data.Stardust = Config.StartingStardust
	data.OwnedPickaxes = { Rusty = true }
	if not (data.Pickaxe == "Galaxy" and Registry.MonetizationService.OwnsPass(player, "GalaxyHammer")) then
		data.Pickaxe = "Rusty"
	end
	data.Zone = 1

	Registry.StatsService.Invalidate(player)
	Registry.DataService.UpdateDisplay(player)
	Registry.MiningService.GivePickaxe(player)
	Registry.ZoneService.Teleport(player, 1)
	Registry.PlayerService.UpdateOverhead(player)
	Registry.DataService.MarkDirty(player)

	Net.Effect(player, "Supernova", { Rebirths = data.Rebirths })
	Net.Announce(("🌟 %s went SUPERNOVA %d!"):format(player.DisplayName, data.Rebirths), Color3.fromRGB(255, 140, 220), 4)
	task.spawn(Registry.DataService.Save, player, false)
	return true, ("Supernova %d! Permanent bonuses unlocked"):format(data.Rebirths)
end

function RebirthService.Init()
	Actions.Register("Rebirth", function(player)
		return RebirthService.DoRebirth(player)
	end)
end

return RebirthService
