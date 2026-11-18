-- Rarezas compartidas por meteoritos y criaturas.

export type Rarity = {
	Name: string,
	Order: number,
	Color: Color3,
	StrokeColor: Color3,
	Weight: number, -- peso de aparición de meteoritos
	HpMult: number,
	LootMult: number,
	EggChance: number, -- probabilidad de que el MVP reciba un huevo de meteorito
	Size: number, -- radio del meteorito en studs
	Announce: boolean,
	Animated: boolean,
}

local Rarities = {}

Rarities.List = {
	{ Name = "Common", Order = 1, Color = Color3.fromRGB(205, 205, 210), StrokeColor = Color3.fromRGB(35, 35, 40), Weight = 56, HpMult = 1, LootMult = 1, EggChance = 0, Size = 3, Announce = false, Animated = false },
	{ Name = "Uncommon", Order = 2, Color = Color3.fromRGB(85, 225, 95), StrokeColor = Color3.fromRGB(10, 60, 20), Weight = 25, HpMult = 2, LootMult = 2.5, EggChance = 0, Size = 3.5, Announce = false, Animated = false },
	{ Name = "Rare", Order = 3, Color = Color3.fromRGB(70, 155, 255), StrokeColor = Color3.fromRGB(10, 30, 80), Weight = 12, HpMult = 4, LootMult = 6, EggChance = 0.04, Size = 4, Announce = false, Animated = false },
	{ Name = "Epic", Order = 4, Color = Color3.fromRGB(180, 90, 255), StrokeColor = Color3.fromRGB(45, 10, 80), Weight = 4.5, HpMult = 8, LootMult = 15, EggChance = 0.15, Size = 4.8, Announce = false, Animated = false },
	{ Name = "Legendary", Order = 5, Color = Color3.fromRGB(255, 185, 30), StrokeColor = Color3.fromRGB(90, 50, 0), Weight = 1.8, HpMult = 18, LootMult = 45, EggChance = 0.5, Size = 5.6, Announce = true, Animated = false },
	{ Name = "Mythic", Order = 6, Color = Color3.fromRGB(255, 60, 95), StrokeColor = Color3.fromRGB(80, 0, 20), Weight = 0.55, HpMult = 40, LootMult = 140, EggChance = 1, Size = 6.5, Announce = true, Animated = false },
	{ Name = "Cosmic", Order = 7, Color = Color3.fromRGB(120, 245, 255), StrokeColor = Color3.fromRGB(20, 0, 60), Weight = 0.15, HpMult = 90, LootMult = 450, EggChance = 1, Size = 7.5, Announce = true, Animated = true },
} :: { Rarity }

local byName: { [string]: Rarity } = {}
for _, rarity in Rarities.List do
	byName[rarity.Name] = rarity
end

function Rarities.Get(name: string): Rarity
	return byName[name] or Rarities.List[1]
end

function Rarities.Exists(name: string): boolean
	return byName[name] ~= nil
end

function Rarities.Order(name: string): number
	local rarity = byName[name]
	return if rarity then rarity.Order else 0
end

-- Botín medio de un meteorito (para escalar recompensas al progreso del jugador)
function Rarities.AverageLootMult(): number
	local totalWeight, total = 0, 0
	for _, rarity in Rarities.List do
		totalWeight += rarity.Weight
		total += rarity.Weight * rarity.LootMult
	end
	return total / totalWeight
end

-- Color "visible" (Cosmic usa un color claro para textos y luces)
function Rarities.DisplayColor(name: string): Color3
	return Rarities.Get(name).Color
end

return Rarities
