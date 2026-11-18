-- Rarezas: orden, color, peso de aparición en la pasarela y escala visual.

export type Rarity = {
	Name: string,
	Order: number,
	Color: Color3,
	StrokeColor: Color3,
	Weight: number,
	Scale: number,
	Announce: boolean,
	Animated: boolean,
}

local Rarities = {}

Rarities.List = {
	{ Name = "Common", Order = 1, Color = Color3.fromRGB(215, 215, 215), StrokeColor = Color3.fromRGB(40, 40, 40), Weight = 50, Scale = 1.0, Announce = false, Animated = false },
	{ Name = "Uncommon", Order = 2, Color = Color3.fromRGB(85, 225, 95), StrokeColor = Color3.fromRGB(10, 60, 20), Weight = 25, Scale = 1.08, Announce = false, Animated = false },
	{ Name = "Rare", Order = 3, Color = Color3.fromRGB(70, 155, 255), StrokeColor = Color3.fromRGB(10, 30, 80), Weight = 13, Scale = 1.16, Announce = false, Animated = false },
	{ Name = "Epic", Order = 4, Color = Color3.fromRGB(180, 90, 255), StrokeColor = Color3.fromRGB(45, 10, 80), Weight = 7, Scale = 1.26, Announce = false, Animated = false },
	{ Name = "Legendary", Order = 5, Color = Color3.fromRGB(255, 185, 30), StrokeColor = Color3.fromRGB(90, 50, 0), Weight = 3.2, Scale = 1.38, Announce = true, Animated = false },
	{ Name = "Mythic", Order = 6, Color = Color3.fromRGB(255, 60, 95), StrokeColor = Color3.fromRGB(80, 0, 20), Weight = 1.3, Scale = 1.5, Announce = true, Animated = false },
	{ Name = "Divine", Order = 7, Color = Color3.fromRGB(120, 245, 255), StrokeColor = Color3.fromRGB(0, 60, 90), Weight = 0.4, Scale = 1.65, Announce = true, Animated = true },
	{ Name = "Secret", Order = 8, Color = Color3.fromRGB(25, 25, 25), StrokeColor = Color3.fromRGB(255, 255, 255), Weight = 0.1, Scale = 1.85, Announce = true, Animated = true },
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

return Rarities
