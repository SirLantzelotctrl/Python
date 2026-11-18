-- Compras con Robux desde el cliente (con simulación en Studio si el Id es 0).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Products = require(Shared:WaitForChild("Products"))

local State = require(script.Parent.State)

local Purchase = {}

local player = Players.LocalPlayer
local priceCache: { [string]: number } = {}
local pending: { [string]: boolean } = {}

-- Se asigna desde Main para poder mostrar mensajes sin dependencias circulares
Purchase.Notify = nil :: ((text: string, kind: string?) -> ())?

local function notify(text: string, kind: string?)
	if Purchase.Notify then
		Purchase.Notify(text, kind)
	end
end

function Purchase.PromptPass(key: string)
	local def = Products.GamePasses[key]
	if not def then
		return
	end
	if def.Id ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, def.Id)
	elseif State.Data and State.Data.SimulatePurchases then
		local ok, message = State.Action("SimulatePurchase", { Kind = "Pass", Key = key })
		notify(message or "Done", if ok then "Success" else "Error")
	else
		notify("Coming soon!", "Info")
	end
end

function Purchase.PromptProduct(key: string)
	local def = Products.DevProducts[key]
	if not def then
		return
	end
	if def.Id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, def.Id)
	elseif State.Data and State.Data.SimulatePurchases then
		local ok, message = State.Action("SimulatePurchase", { Kind = "Product", Key = key })
		notify(message or "Done", if ok then "Success" else "Error")
	else
		notify("Coming soon!", "Info")
	end
end

-- Precio en Robux (real si hay Id, si no el PriceHint). Llama a callback cuando lo sabe.
function Purchase.GetPrice(kind: string, key: string, callback: (price: number) -> ())
	local def: any = if kind == "Pass" then Products.GamePasses[key] else Products.DevProducts[key]
	if not def then
		return
	end
	local cacheKey = kind .. key
	if priceCache[cacheKey] then
		callback(priceCache[cacheKey])
		return
	end
	callback(def.PriceHint)
	if def.Id == 0 or pending[cacheKey] then
		return
	end
	pending[cacheKey] = true
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(def.Id, if kind == "Pass" then Enum.InfoType.GamePass else Enum.InfoType.Product)
		end)
		if ok and info and typeof(info.PriceInRobux) == "number" then
			priceCache[cacheKey] = info.PriceInRobux
			callback(info.PriceInRobux)
		end
	end)
end

return Purchase
