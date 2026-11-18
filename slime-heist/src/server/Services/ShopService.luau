-- Tienda con cash: bates y mejoras permanentes (velocidad y duración del candado).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Gear = require(Shared.Gear)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)

local Registry = require(script.Parent.Parent.Registry)
local Actions = require(script.Parent.Parent.Actions)
local Net = require(script.Parent.Parent.Net)

local ShopService = {}

function ShopService.Init()
	Actions.Register("BuyBat", function(player, payload)
		local data = Registry.DataService.Get(player)
		local def = Gear.GetBat(tostring(payload.Id))
		if not data or not def then
			return false, "Invalid bat"
		end
		if data.OwnedBats[def.Id] then
			return false, "Already owned"
		end
		if def.GamePass then
			return false, "This bat is a Game Pass"
		end
		if data.Rebirths < def.RebirthRequired then
			return false, ("Requires Rebirth %d"):format(def.RebirthRequired)
		end
		if not Registry.DataService.SpendCash(player, def.Price) then
			return false, "Not enough cash"
		end
		data.OwnedBats[def.Id] = true
		data.EquippedBat = def.Id
		Registry.CombatService.GiveBat(player)
		Registry.DataService.MarkDirty(player)
		Net.Effect(player, "Sound", { Name = "Buy" })
		return true, "Bought " .. def.Name .. "!"
	end)

	Actions.Register("EquipBat", function(player, payload)
		local data = Registry.DataService.Get(player)
		local def = Gear.GetBat(tostring(payload.Id))
		if not data or not def then
			return false, "Invalid bat"
		end
		local owned = data.OwnedBats[def.Id] == true
		if def.GamePass then
			owned = Registry.MonetizationService.OwnsPass(player, def.GamePass)
		end
		if not owned then
			return false, "You don't own this bat"
		end
		data.EquippedBat = def.Id
		Registry.CombatService.GiveBat(player)
		Registry.DataService.MarkDirty(player)
		return true, "Equipped " .. def.Name
	end)

	Actions.Register("BuyUpgrade", function(player, payload)
		local data = Registry.DataService.Get(player)
		local key = tostring(payload.Key)
		local def = Gear.Upgrades[key]
		if not data or not def then
			return false, "Invalid upgrade"
		end
		local level = data.Upgrades[key] or 0
		if level >= def.MaxLevel then
			return false, "Max level!"
		end
		local cost = Economy.GetUpgradeCost(key, level)
		if not Registry.DataService.SpendCash(player, cost) then
			return false, ("Not enough cash (%s)"):format(Format.Money(cost))
		end
		data.Upgrades[key] = level + 1
		if key == "Speed" then
			Registry.PlayerService.UpdateWalkSpeed(player)
		end
		Registry.DataService.MarkDirty(player)
		Net.Effect(player, "Sound", { Name = "Buy" })
		return true, ("%s upgraded to level %d!"):format(def.Name, level + 1)
	end)
end

return ShopService
