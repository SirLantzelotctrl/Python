-- Tienda con Stardust: picos (en orden) y mejoras permanentes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Gear = require(Shared.Gear)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)

local Registry = require(script.Parent.Parent.Registry)
local Actions = require(script.Parent.Parent.Actions)
local Net = require(script.Parent.Parent.Net)

local ShopService = {}

local function bestOwnedTier(data: any): number
	local best = 1
	for id in data.OwnedPickaxes do
		local pick = Gear.GetPickaxe(id)
		if pick and not pick.GamePass then
			best = math.max(best, Gear.GetTier(id))
		end
	end
	return best
end

function ShopService.Init()
	Actions.Register("BuyPickaxe", function(player, payload)
		local data = Registry.DataService.Get(player)
		local pick = Gear.GetPickaxe(tostring(payload.Id))
		if not data or not pick then
			return false, "Invalid pickaxe"
		end
		if pick.GamePass then
			return false, "This one is a Game Pass"
		end
		if data.OwnedPickaxes[pick.Id] then
			return false, "Already owned"
		end
		if Gear.GetTier(pick.Id) > bestOwnedTier(data) + 1 then
			return false, "Buy the previous pickaxe first"
		end
		if not Registry.DataService.SpendStardust(player, pick.Price) then
			return false, ("You need %s ⭐"):format(Format.Abbreviate(pick.Price))
		end
		data.OwnedPickaxes[pick.Id] = true
		data.Pickaxe = pick.Id
		Registry.StatsService.Invalidate(player)
		Registry.MiningService.GivePickaxe(player)
		Net.Effect(player, "Sound", { Name = "Buy" })
		return true, "Bought " .. pick.Name .. "!"
	end)

	Actions.Register("EquipPickaxe", function(player, payload)
		local data = Registry.DataService.Get(player)
		local pick = Gear.GetPickaxe(tostring(payload.Id))
		if not data or not pick then
			return false, "Invalid pickaxe"
		end
		local owned = if pick.GamePass then Registry.MonetizationService.OwnsPass(player, pick.GamePass) else data.OwnedPickaxes[pick.Id] == true
		if not owned then
			return false, "You don't own this pickaxe"
		end
		data.Pickaxe = pick.Id
		Registry.StatsService.Invalidate(player)
		Registry.MiningService.GivePickaxe(player)
		return true, "Equipped " .. pick.Name
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
		if not Registry.DataService.SpendStardust(player, cost) then
			return false, ("You need %s ⭐"):format(Format.Abbreviate(cost))
		end
		data.Upgrades[key] = level + 1
		Registry.StatsService.Invalidate(player)
		if key == "Speed" then
			Registry.PlayerService.UpdateMovement(player)
		end
		Net.Effect(player, "Sound", { Name = "Buy" })
		return true, ("%s → level %d!"):format(def.Name, level + 1)
	end)
end

function ShopService.Start()
	-- Puestos físicos: abren las ventanas de la interfaz
	local shop = Registry.MapService.ShopStand
	local altar = Registry.MapService.Altar
	for _, entry in { { shop, "Shop", "Open Shop" }, { altar, "Rebirth", "Supernova" } } do
		local stand = entry[1]
		if stand then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "OpenPrompt"
			prompt.ActionText = entry[3]
			prompt.ObjectText = ""
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.Parent = stand
			prompt.Triggered:Connect(function(player)
				Net.Effect(player, "OpenWindow", { Name = entry[2] })
			end)
		end
	end
end

return ShopService
