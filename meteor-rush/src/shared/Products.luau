-- =====================================================================
--  MONETIZACIÓN: crea los Passes / Developer Products en el Creator
--  Dashboard y pega aquí sus IDs (Id = 0 = sin configurar).
-- =====================================================================

export type PassDef = { Key: string, Id: number, Name: string, Icon: string, Description: string, PriceHint: number }
export type ProductDef = { Key: string, Id: number, Name: string, Icon: string, Description: string, PriceHint: number, Kind: string, [string]: any }

local Products = {}

Products.GamePasses = {
	DoubleStardust = { Key = "DoubleStardust", Id = 0, Name = "2x Stardust", Icon = "⭐", Description = "Double ALL stardust forever!", PriceHint = 299 },
	VIP = { Key = "VIP", Id = 0, Name = "VIP", Icon = "👑", Description = "+20% stardust, +10% damage & VIP tag", PriceHint = 199 },
	AutoMine = { Key = "AutoMine", Id = 0, Name = "Auto Mine", Icon = "🤖", Description = "Mine automatically near meteors", PriceHint = 249 },
	ExtraSlots = { Key = "ExtraSlots", Id = 0, Name = "+2 Critter Slots", Icon = "🐾", Description = "Equip 2 more critters", PriceHint = 199 },
	TripleHatch = { Key = "TripleHatch", Id = 0, Name = "Triple Hatch", Icon = "🥚", Description = "Hatch 3 eggs at once", PriceHint = 249 },
	LuckyHatch = { Key = "LuckyHatch", Id = 0, Name = "Lucky Hatch", Icon = "🍀", Description = "x1.5 luck on every egg", PriceHint = 299 },
	RocketBoots = { Key = "RocketBoots", Id = 0, Name = "Rocket Boots", Icon = "🚀", Description = "+10 speed & higher jumps. Arrive first!", PriceHint = 149 },
	GalaxyHammer = { Key = "GalaxyHammer", Id = 0, Name = "Galaxy Hammer", Icon = "🔨", Description = "6,000 damage per hit", PriceHint = 399 },
} :: { [string]: PassDef }

Products.PassOrder = { "DoubleStardust", "AutoMine", "VIP", "TripleHatch", "LuckyHatch", "ExtraSlots", "RocketBoots", "GalaxyHammer" }

Products.DevProducts = {
	CallComet = { Key = "CallComet", Id = 0, Name = "Call the Comet", Icon = "☄️", Description = "A giant COMET crashes NOW for the whole server", PriceHint = 199, Kind = "Comet" },
	SummonMeteor = { Key = "SummonMeteor", Id = 0, Name = "Summon Meteor", Icon = "🌠", Description = "A Legendary+ meteor falls next to you (yours for 15s)", PriceHint = 79, Kind = "Summon" },
	ServerLuck = { Key = "ServerLuck", Id = 0, Name = "Server Luck x2", Icon = "🍀", Description = "2x meteor luck for EVERYONE for 15 min", PriceHint = 99, Kind = "ServerLuck", Seconds = 900 },
	SuperEgg = { Key = "SuperEgg", Id = 0, Name = "Super Egg", Icon = "🥚", Description = "Guaranteed Legendary+ critter from your best egg", PriceHint = 299, Kind = "SuperEgg" },
	PowerBoost = { Key = "PowerBoost", Id = 0, Name = "Power Boost", Icon = "⚡", Description = "x2 damage AND x2 stardust for 20 min", PriceHint = 49, Kind = "PowerBoost", Seconds = 1_200 },
	StardustSmall = { Key = "StardustSmall", Id = 0, Name = "Stardust Pouch", Icon = "✨", Description = "Worth 50 meteors of your best zone", PriceHint = 25, Kind = "Stardust", Meteors = 50, Minimum = 500 },
	StardustMedium = { Key = "StardustMedium", Id = 0, Name = "Stardust Sack", Icon = "💰", Description = "Worth 400 meteors of your best zone", PriceHint = 99, Kind = "Stardust", Meteors = 400, Minimum = 5_000 },
	StardustLarge = { Key = "StardustLarge", Id = 0, Name = "Stardust Vault", Icon = "🏦", Description = "Worth 2,500 meteors of your best zone", PriceHint = 349, Kind = "Stardust", Meteors = 2_500, Minimum = 50_000 },
} :: { [string]: ProductDef }

Products.ProductOrder = { "CallComet", "SummonMeteor", "ServerLuck", "SuperEgg", "PowerBoost", "StardustSmall", "StardustMedium", "StardustLarge" }

function Products.FindPassById(id: number): PassDef?
	if id == 0 then
		return nil
	end
	for _, def in Products.GamePasses do
		if def.Id == id then
			return def
		end
	end
	return nil
end

function Products.FindProductById(id: number): ProductDef?
	if id == 0 then
		return nil
	end
	for _, def in Products.DevProducts do
		if def.Id == id then
			return def
		end
	end
	return nil
end

return Products
