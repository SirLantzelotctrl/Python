-- Compras con Robux: productos para desarrolladores (Cristales Arcanos y
-- Pack del Fundador) y pases del juego (Pase Arcano Premium, Sellador VIP).
-- ProcessReceipt es idempotente: cada recibo se concede una sola vez y solo se
-- confirma a Roblox cuando el perfil ya está guardado.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local DataService = require(script.Parent.DataService)
local Progression = require(script.Parent.ProgressionService)

local Shop = {}
local passCache = {} -- player -> {passKey = bool}

local productById = {}
for _, prod in ipairs(Config.Products) do
	if prod.id and prod.id ~= 0 then
		productById[prod.id] = prod
	end
end

function Shop.ownsPass(player, key)
	local c = passCache[player]
	return c and c[key] == true
end

local function applyPass(player, key)
	local p = DataService.get(player)
	if not p then
		return
	end
	if key == "pase_premium" then
		p.pass.premium = true
	elseif key == "vip" then
		if not table.find(p.cosmetics.seals, "eclipse") then
			table.insert(p.cosmetics.seals, "eclipse")
		end
		player:SetAttribute("VIP", true)
	end
	DataService.sync(player)
end

function Shop.loadPasses(player)
	passCache[player] = {}
	for key, pass in pairs(Config.GamePasses) do
		if pass.id and pass.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok and owns then
				passCache[player][key] = true
				applyPass(player, key)
			end
		end
	end
end

local function grantProduct(player, prod, p)
	if prod.once and prod.founder and p.purchases.founder then
		-- ya lo tenía: se convierte en cristales para no perder la compra
		p.crystals = p.crystals + prod.crystals
		return
	end
	p.crystals = p.crystals + (prod.crystals or 0)
	if prod.founder then
		p.purchases.founder = true
		-- tinte Prisma para la primera criatura, Corona Solar y Lluvia de estrellas
		local first = p.team[1]
		if first then
			local tid = first .. "_prisma"
			if not table.find(p.cosmetics.tints, tid) then
				table.insert(p.cosmetics.tints, tid)
			end
			if p.creatures[first] then
				p.creatures[first].tint = tid
			end
		end
		if not table.find(p.cosmetics.seals, "corona") then
			table.insert(p.cosmetics.seals, "corona")
		end
		if not table.find(p.cosmetics.effects, "estrellas") then
			table.insert(p.cosmetics.effects, "estrellas")
		end
	end
end

local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local p = DataService.get(player)
	if not p then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receipts = p.purchases.receipts
	if table.find(receipts, info.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local prod = productById[info.ProductId]
	if not prod then
		warn("[Sellos Arcanos] producto desconocido", info.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	grantProduct(player, prod, p)
	table.insert(receipts, info.PurchaseId)
	-- guardamos solo los últimos 200 recibos
	while #receipts > 200 do
		table.remove(receipts, 1)
	end
	DataService.save(player, false)
	DataService.sync(player)
	Progression.toast(player, "purchaseDone", { key = prod.key }, "gold")
	if Shop.onGranted then
		Shop.onGranted(player)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Shop.init()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for key, pass in pairs(Config.GamePasses) do
			if pass.id == passId then
				passCache[player] = passCache[player] or {}
				passCache[player][key] = true
				applyPass(player, key)
				Progression.toast(player, "purchaseDone", { key = key }, "gold")
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		passCache[player] = nil
	end)
end

return Shop
