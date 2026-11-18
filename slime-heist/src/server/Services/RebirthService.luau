-- Rebirth: reinicia cash y slimes a cambio de +ingresos, +slots y +tiempo de candado permanentes.

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
		return false, "Max rebirths reached!"
	end
	if Registry.StealService.IsCarrying(player) then
		return false, "You can't rebirth while carrying a slime"
	end
	local cost = Economy.GetRebirthCost(data.Rebirths)
	if data.Cash < cost then
		return false, ("You need %s"):format(Format.Money(cost))
	end

	Registry.StealService.CancelAllFor(player)
	Registry.SlimeService.CollectAll(player)

	data.Rebirths += 1
	data.Cash = Config.StartingCash
	table.clear(data.Slimes)

	Registry.SlimeService.ResetPlayer(player)
	Registry.DataService.UpdateCashDisplay(player)
	Registry.DataService.UpdateStatsDisplay(player)
	Registry.SlimeService.InvalidateMultiplier(player)
	Registry.PlayerService.UpdateOverhead(player)
	Registry.DataService.MarkDirty(player)

	Net.Effect(player, "Rebirth", { Rebirths = data.Rebirths })
	Net.Announce(("♻️ %s reached REBIRTH %d!"):format(player.DisplayName, data.Rebirths), Color3.fromRGB(255, 210, 70), 4)
	task.spawn(Registry.DataService.Save, player, false)
	return true, ("Rebirth %d! Income x%s"):format(data.Rebirths, tostring(1 + data.Rebirths * Config.Rebirth.IncomeBonus))
end

function RebirthService.Init()
	Actions.Register("Rebirth", function(player)
		return RebirthService.DoRebirth(player)
	end)
end

return RebirthService
