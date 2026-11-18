-- =====================================================================
--  MONETIZACIÓN
--  1) Crea los Game Passes y Developer Products en el Creator Dashboard.
--  2) Pega aquí sus IDs (Id = 0 significa "no configurado").
--  PriceHint solo se usa para mostrar un precio si aún no hay Id.
-- =====================================================================

export type PassDef = {
	Key: string,
	Id: number,
	Name: string,
	Icon: string,
	Description: string,
	PriceHint: number,
}

export type ProductDef = {
	Key: string,
	Id: number,
	Name: string,
	Icon: string,
	Description: string,
	PriceHint: number,
	Kind: string,
	[string]: any,
}

local Products = {}

Products.GamePasses = {
	VIP = { Key = "VIP", Id = 0, Name = "VIP", Icon = "⭐", Description = "+25% cash forever, VIP tag & golden name", PriceHint = 199 },
	DoubleCash = { Key = "DoubleCash", Id = 0, Name = "2x Cash", Icon = "💵", Description = "Double ALL cash forever!", PriceHint = 299 },
	AutoCollect = { Key = "AutoCollect", Id = 0, Name = "Auto Collect", Icon = "🧲", Description = "Cash goes straight to your wallet", PriceHint = 149 },
	ExtraSlots = { Key = "ExtraSlots", Id = 0, Name = "+6 Slots", Icon = "📦", Description = "6 extra slime slots in your base", PriceHint = 249 },
	LongerLock = { Key = "LongerLock", Id = 0, Name = "Longer Lock", Icon = "🔒", Description = "+30 seconds every time you lock", PriceHint = 99 },
	SpeedBoost = { Key = "SpeedBoost", Id = 0, Name = "Speed Boost", Icon = "⚡", Description = "+8 walk speed. Escape thieves!", PriceHint = 149 },
	GalaxyBat = { Key = "GalaxyBat", Id = 0, Name = "Galaxy Bat", Icon = "🌌", Description = "The strongest bat. MASSIVE knockback", PriceHint = 399 },
} :: { [string]: PassDef }

Products.PassOrder = { "DoubleCash", "VIP", "AutoCollect", "ExtraSlots", "SpeedBoost", "LongerLock", "GalaxyBat" }

Products.DevProducts = {
	CashSmall = { Key = "CashSmall", Id = 0, Name = "Pile of Cash", Icon = "💵", Description = "10 minutes of income", PriceHint = 25, Kind = "Cash", Seconds = 600, Minimum = 2_500 },
	CashMedium = { Key = "CashMedium", Id = 0, Name = "Bag of Cash", Icon = "💰", Description = "1 hour of income", PriceHint = 99, Kind = "Cash", Seconds = 3_600, Minimum = 25_000 },
	CashLarge = { Key = "CashLarge", Id = 0, Name = "Vault of Cash", Icon = "🏦", Description = "5 hours of income", PriceHint = 349, Kind = "Cash", Seconds = 18_000, Minimum = 250_000 },
	ServerLuck = { Key = "ServerLuck", Id = 0, Name = "Server Luck x2", Icon = "🍀", Description = "2x luck for EVERYONE for 15 min", PriceHint = 99, Kind = "ServerLuck", Seconds = 900 },
	CashBoost = { Key = "CashBoost", Id = 0, Name = "2x Cash 30m", Icon = "⏫", Description = "Double cash for 30 minutes", PriceHint = 49, Kind = "Boost", Seconds = 1_800 },
	SummonMythic = { Key = "SummonMythic", Id = 0, Name = "Mythic Slime", Icon = "🔥", Description = "A random MYTHIC slime walks into your base", PriceHint = 149, Kind = "Summon", Rarity = "Mythic" },
	SummonSecret = { Key = "SummonSecret", Id = 0, Name = "Secret Slime", Icon = "🔮", Description = "A random SECRET slime walks into your base", PriceHint = 799, Kind = "Summon", Rarity = "Secret" },
	InstantLock = { Key = "InstantLock", Id = 0, Name = "Instant Lock", Icon = "🛡️", Description = "Lock your base NOW, skip the cooldown", PriceHint = 19, Kind = "InstantLock" },
} :: { [string]: ProductDef }

Products.ProductOrder = { "ServerLuck", "SummonSecret", "SummonMythic", "CashBoost", "CashSmall", "CashMedium", "CashLarge", "InstantLock" }

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
