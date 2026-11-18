-- Game Passes y Developer Products. ProcessReceipt es idempotente (cada compra se
-- registra en los datos del jugador). En Studio se pueden simular las compras.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Products = require(Shared.Products)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)

local Registry = require(script.Parent.Parent.Registry)
local Actions = require(script.Parent.Parent.Actions)
local Net = require(script.Parent.Parent.Net)

local MonetizationService = {}

local owned: { [Player]: { [string]: boolean } } = {}
local EMPTY = table.freeze({})
local rng = Random.new()

local function applyPassEffects(player: Player, key: string)
	if key == "VIP" then
		Registry.PlayerService.UpdateOverhead(player)
	end
	if key == "RocketBoots" then
		Registry.PlayerService.UpdateMovement(player)
	end
	if key == "GalaxyHammer" then
		local data = Registry.DataService.Get(player)
		if data then
			data.Pickaxe = "Galaxy"
		end
	end
	Registry.StatsService.Invalidate(player)
	if key == "GalaxyHammer" then
		Registry.MiningService.GivePickaxe(player)
	end
	if key == "ExtraSlots" then
		Registry.CritterService.EquipBest(player)
	end
end

function MonetizationService.GrantPass(player: Player, key: string, announce: boolean)
	local def = Products.GamePasses[key]
	if not def then
		return
	end
	owned[player] = owned[player] or {}
	if owned[player][key] then
		return
	end
	owned[player][key] = true
	applyPassEffects(player, key)
	if announce then
		Net.Announce(("👑 %s bought %s %s!"):format(player.DisplayName, def.Icon, def.Name), Color3.fromRGB(255, 215, 70), 4)
		Net.Effect(player, "Confetti", {})
	end
end

function MonetizationService.ApplyProduct(player: Player, key: string): (boolean, string?)
	local def = Products.DevProducts[key]
	local data = Registry.DataService.Get(player)
	if not def or not data then
		return false, "Invalid product"
	end
	if def.Kind == "Stardust" then
		local amount = Economy.ScaleReward(def.Minimum, Registry.StatsService.GetRewardBase(player), def.Meteors)
		Registry.DataService.AddStardust(player, amount)
		Net.Effect(player, "Confetti", {})
		Net.Effect(player, "Sound", { Name = "Stardust" })
		return true, "+" .. Format.Abbreviate(amount) .. " ⭐"
	elseif def.Kind == "ServerLuck" then
		Registry.EventService.AddServerLuck(def.Seconds, player)
		return true, "Server Luck activated!"
	elseif def.Kind == "PowerBoost" then
		Registry.StatsService.AddBoost(player, "Damage", def.Seconds)
		Registry.StatsService.AddBoost(player, "Stardust", def.Seconds)
		return true, "x2 damage & stardust!"
	elseif def.Kind == "Summon" then
		local meteor = Registry.MeteorService.SummonFor(player)
		if not meteor then
			-- No había hueco: se compensa
			local amount = math.floor(Registry.StatsService.GetRewardBase(player) * 40)
			Registry.DataService.AddStardust(player, amount)
			return true, "No space for a meteor, got +" .. Format.Abbreviate(amount) .. " ⭐"
		end
		return true, "A meteor is falling next to you!"
	elseif def.Kind == "Comet" then
		local launched = Registry.CometService.Launch(player)
		return true, if launched then "The comet is coming!" else "Comet queued after the current one!"
	elseif def.Kind == "SuperEgg" then
		local rarity = if rng:NextNumber() < 0.15 then "Mythic" else "Legendary"
		Registry.CritterService.GiveCritterOfRarity(player, rarity, data.Zone, false, "product")
		return true, "Super Egg opened!"
	end
	return false, "Unknown product"
end

local function processReceipt(receiptInfo): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = Registry.DataService.Get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receiptKey = tostring(receiptInfo.PurchaseId)
	if Registry.DataService.HasReceipt(player, receiptKey) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local def = Products.FindProductById(receiptInfo.ProductId)
	if not def then
		warn("[Monetization] Producto desconocido: " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, success, message = pcall(MonetizationService.ApplyProduct, player, def.Key)
	if not ok or not success then
		warn("[Monetization] Error aplicando " .. def.Key .. ": " .. tostring(if ok then message else success))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Registry.DataService.AddReceipt(player, receiptKey)
	Registry.DataService.MarkDirty(player)
	task.spawn(Registry.DataService.Save, player, false)
	Net.Notify(player, ("💎 Thanks! %s: %s"):format(def.Name, message or ""), "Success")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Init()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then
			local def = Products.FindPassById(passId)
			if def then
				MonetizationService.GrantPass(player, def.Key, true)
			end
		end
	end)
	Actions.Register("SimulatePurchase", function(player, payload)
		if not (RunService:IsStudio() and Config.SimulatePurchasesInStudio) then
			return false, "Purchases are not configured yet"
		end
		local key = tostring(payload.Key)
		if payload.Kind == "Pass" then
			local def = Products.GamePasses[key]
			if not def then
				return false, "Invalid pass"
			end
			MonetizationService.GrantPass(player, key, true)
			return true, "[Studio] Simulated pass: " .. def.Name
		elseif payload.Kind == "Product" then
			local ok, message = MonetizationService.ApplyProduct(player, key)
			return ok, "[Studio] " .. tostring(message)
		end
		return false, "Invalid purchase"
	end)
end

function MonetizationService.LoadPlayer(player: Player)
	owned[player] = owned[player] or {}
	local pending = 0
	for key, def in Products.GamePasses do
		if def.Id ~= 0 then
			pending += 1
			task.spawn(function()
				local ok, has = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, def.Id)
				end)
				if ok and has and owned[player] then
					owned[player][key] = true
				end
				pending -= 1
			end)
		end
	end
	local started = os.clock()
	while pending > 0 and os.clock() - started < 10 do
		task.wait(0.1)
	end
end

function MonetizationService.OnPlayerRemoving(player: Player)
	owned[player] = nil
end

function MonetizationService.GetOwnedPasses(player: Player): { [string]: boolean }
	return owned[player] or EMPTY :: any
end

function MonetizationService.OwnsPass(player: Player, key: string): boolean
	local passes = owned[player]
	return passes ~= nil and passes[key] == true
end

function MonetizationService.FillView(player: Player, view: { [string]: any })
	view.Passes = MonetizationService.GetOwnedPasses(player)
end

return MonetizationService
