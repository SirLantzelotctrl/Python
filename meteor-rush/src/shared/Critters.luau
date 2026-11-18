-- Criaturas cósmicas (mascotas) y huevos. Cada zona tiene su huevo con 6 criaturas.
-- Power = bonus de daño que da al equiparla (0.5 = +50%). Shiny = x2.

local Rarities = require(script.Parent.Rarities)

export type CritterDef = {
	Id: string,
	Name: string,
	Rarity: string,
	Egg: number,
	Power: number,
	Color: Color3,
	Body: string?, -- "Round" | "Bean" | "Wide" | "Drop"
	Features: { string },
	Material: Enum.Material?,
}

export type EggDef = {
	Index: number,
	Name: string,
	Cost: number,
	Color: Color3,
	SpotColor: Color3,
}

local Critters = {}

-- Probabilidad base de cada rareza dentro de un huevo
Critters.RarityChances = {
	Common = 0.55,
	Uncommon = 0.28,
	Rare = 0.12,
	Epic = 0.04,
	Legendary = 0.009,
	Mythic = 0.001,
}

Critters.Eggs = {
	{ Index = 1, Name = "Meadow Egg", Cost = 150, Color = Color3.fromRGB(140, 220, 120), SpotColor = Color3.fromRGB(255, 255, 255) },
	{ Index = 2, Name = "Desert Egg", Cost = 2_000, Color = Color3.fromRGB(240, 200, 120), SpotColor = Color3.fromRGB(200, 120, 60) },
	{ Index = 3, Name = "Frost Egg", Cost = 25_000, Color = Color3.fromRGB(190, 230, 255), SpotColor = Color3.fromRGB(100, 160, 255) },
	{ Index = 4, Name = "Magma Egg", Cost = 350_000, Color = Color3.fromRGB(60, 40, 40), SpotColor = Color3.fromRGB(255, 120, 30) },
	{ Index = 5, Name = "Moon Egg", Cost = 5_000_000, Color = Color3.fromRGB(215, 220, 235), SpotColor = Color3.fromRGB(150, 150, 175) },
	{ Index = 6, Name = "Nebula Egg", Cost = 80_000_000, Color = Color3.fromRGB(70, 40, 120), SpotColor = Color3.fromRGB(255, 160, 255) },
} :: { EggDef }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

Critters.List = {
	-- 🌿 MEADOW ---------------------------------------------------------
	{ Id = "pebblit", Name = "Pebblit", Rarity = "Common", Egg = 1, Power = 0.1, Color = rgb(150, 140, 125), Features = { "TinyLeaf" }, Material = Enum.Material.Slate },
	{ Id = "sproutling", Name = "Sproutling", Rarity = "Uncommon", Egg = 1, Power = 0.18, Color = rgb(120, 210, 90), Body = "Bean", Features = { "Sprout" } },
	{ Id = "dewdrop", Name = "Dewdrop", Rarity = "Rare", Egg = 1, Power = 0.32, Color = rgb(120, 200, 255), Body = "Drop", Features = {}, Material = Enum.Material.Glass },
	{ Id = "buzzby", Name = "Buzzby", Rarity = "Epic", Egg = 1, Power = 0.6, Color = rgb(255, 215, 60), Features = { "Stripes", "BugWings", "Antennae" } },
	{ Id = "glimmerfox", Name = "Glimmerfox", Rarity = "Legendary", Egg = 1, Power = 1.2, Color = rgb(255, 140, 60), Body = "Bean", Features = { "PointyEars", "FluffyTail", "Sparkle" } },
	{ Id = "starfawn", Name = "Starfawn", Rarity = "Mythic", Egg = 1, Power = 2.5, Color = rgb(255, 232, 200), Body = "Bean", Features = { "Antlers", "StarSpots", "Halo" } },

	-- 🏜️ DESERT ---------------------------------------------------------
	{ Id = "sandmite", Name = "Sandmite", Rarity = "Common", Egg = 2, Power = 0.35, Color = rgb(220, 190, 130), Body = "Wide", Features = { "Mandibles" } },
	{ Id = "cactopup", Name = "Cactopup", Rarity = "Uncommon", Egg = 2, Power = 0.6, Color = rgb(90, 170, 90), Body = "Bean", Features = { "CactusArms", "Flower" } },
	{ Id = "dunebug", Name = "Dune Beetle", Rarity = "Rare", Egg = 2, Power = 1, Color = rgb(140, 90, 50), Body = "Wide", Features = { "Shell", "Horn" } },
	{ Id = "mirage_gecko", Name = "Mirage Gecko", Rarity = "Epic", Egg = 2, Power = 1.9, Color = rgb(80, 220, 200), Features = { "Frill", "LongTail" } },
	{ Id = "sun_scarab", Name = "Sun Scarab", Rarity = "Legendary", Egg = 2, Power = 3.8, Color = rgb(255, 190, 40), Body = "Wide", Features = { "Shell", "SunDisc", "Sparkle" }, Material = Enum.Material.Metal },
	{ Id = "sphinxlet", Name = "Sphinxlet", Rarity = "Mythic", Egg = 2, Power = 8, Color = rgb(230, 190, 120), Features = { "PointyEars", "Headdress", "Halo" } },

	-- ❄️ FROST ----------------------------------------------------------
	{ Id = "snowpuff", Name = "Snowpuff", Rarity = "Common", Egg = 3, Power = 1.1, Color = rgb(245, 250, 255), Features = { "Fluff" } },
	{ Id = "frostfin", Name = "Frostfin", Rarity = "Uncommon", Egg = 3, Power = 1.9, Color = rgb(120, 190, 255), Body = "Wide", Features = { "Fins" } },
	{ Id = "icicub", Name = "Icicub", Rarity = "Rare", Egg = 3, Power = 3.2, Color = rgb(200, 235, 255), Features = { "RoundEars", "IceSpikes" } },
	{ Id = "aurora_owl", Name = "Aurora Owl", Rarity = "Epic", Egg = 3, Power = 6, Color = rgb(150, 120, 255), Body = "Bean", Features = { "OwlTufts", "BirdWings" } },
	{ Id = "glacier_golem", Name = "Glacier Golem", Rarity = "Legendary", Egg = 3, Power = 12, Color = rgb(150, 210, 240), Body = "Wide", Features = { "IceSpikes", "Crystals" }, Material = Enum.Material.Glass },
	{ Id = "frostwyrm", Name = "Frostwyrm", Rarity = "Mythic", Egg = 3, Power = 25, Color = rgb(190, 240, 255), Features = { "Horns", "BatWings", "LongTail" } },

	-- 🌋 MAGMA ----------------------------------------------------------
	{ Id = "emberling", Name = "Emberling", Rarity = "Common", Egg = 4, Power = 3.5, Color = rgb(255, 120, 40), Body = "Drop", Features = { "Flame" } },
	{ Id = "lava_slug", Name = "Lava Slug", Rarity = "Uncommon", Egg = 4, Power = 6, Color = rgb(230, 80, 40), Body = "Wide", Features = { "Antennae", "LavaCracks" } },
	{ Id = "cinderbat", Name = "Cinderbat", Rarity = "Rare", Egg = 4, Power = 10, Color = rgb(60, 40, 45), Features = { "BatWings", "PointyEars" } },
	{ Id = "magmole", Name = "Magmole", Rarity = "Epic", Egg = 4, Power = 19, Color = rgb(140, 70, 50), Body = "Bean", Features = { "Goggles", "Claws" } },
	{ Id = "phoenix_chick", Name = "Phoenix Chick", Rarity = "Legendary", Egg = 4, Power = 38, Color = rgb(255, 150, 40), Features = { "Crest", "BirdWings", "Flame" } },
	{ Id = "obsidian_drake", Name = "Obsidian Drake", Rarity = "Mythic", Egg = 4, Power = 80, Color = rgb(40, 30, 45), Features = { "Horns", "BatWings", "LavaCracks" } },

	-- 🌙 MOON -----------------------------------------------------------
	{ Id = "moonbun", Name = "Moonbun", Rarity = "Common", Egg = 5, Power = 11, Color = rgb(235, 235, 250), Features = { "BunnyEars" } },
	{ Id = "craterpup", Name = "Craterpup", Rarity = "Uncommon", Egg = 5, Power = 19, Color = rgb(160, 160, 175), Features = { "FloppyEars", "Craters" } },
	{ Id = "orbit_owl", Name = "Orbit Owl", Rarity = "Rare", Egg = 5, Power = 32, Color = rgb(90, 110, 180), Body = "Bean", Features = { "OwlTufts", "OrbitRing" } },
	{ Id = "lunar_jelly", Name = "Lunar Jelly", Rarity = "Epic", Egg = 5, Power = 60, Color = rgb(200, 180, 255), Body = "Drop", Features = { "Tentacles", "Glow" }, Material = Enum.Material.Glass },
	{ Id = "astro_axolotl", Name = "Astro Axolotl", Rarity = "Legendary", Egg = 5, Power = 120, Color = rgb(255, 160, 200), Body = "Wide", Features = { "Gills", "Helmet" } },
	{ Id = "moon_dragon", Name = "Moon Dragon", Rarity = "Mythic", Egg = 5, Power = 250, Color = rgb(220, 225, 255), Features = { "Horns", "BatWings", "Crescent" } },

	-- 🌌 NEBULA ---------------------------------------------------------
	{ Id = "stardrop", Name = "Stardrop", Rarity = "Common", Egg = 6, Power = 35, Color = rgb(255, 240, 150), Body = "Drop", Features = { "Sparkle" }, Material = Enum.Material.Neon },
	{ Id = "nebulisk", Name = "Nebulisk", Rarity = "Uncommon", Egg = 6, Power = 60, Color = rgb(150, 90, 220), Features = { "Antennae", "StarSpots" } },
	{ Id = "void_kitten", Name = "Void Kitten", Rarity = "Rare", Egg = 6, Power = 100, Color = rgb(30, 20, 45), Features = { "PointyEars", "LongTail", "Glow" } },
	{ Id = "comet_ray", Name = "Comet Ray", Rarity = "Epic", Egg = 6, Power = 190, Color = rgb(90, 200, 255), Body = "Wide", Features = { "Fins", "CometTail" } },
	{ Id = "galaxy_whale", Name = "Galaxy Whale", Rarity = "Legendary", Egg = 6, Power = 380, Color = rgb(60, 50, 140), Body = "Wide", Features = { "Fins", "StarSpots", "OrbitRing" } },
	{ Id = "celestial_phoenix", Name = "Celestial Phoenix", Rarity = "Mythic", Egg = 6, Power = 800, Color = rgb(255, 230, 255), Features = { "Crest", "BirdWings", "Halo", "Glow" } },
} :: { CritterDef }

local byId: { [string]: CritterDef } = {}
Critters.ByEgg = {} :: { [number]: { CritterDef } }
for index, def in Critters.List do
	assert(byId[def.Id] == nil, "Criatura duplicada: " .. def.Id)
	assert(Critters.RarityChances[def.Rarity], "Rareza sin probabilidad: " .. def.Rarity)
	byId[def.Id] = def
	Critters.ByEgg[def.Egg] = Critters.ByEgg[def.Egg] or {}
	table.insert(Critters.ByEgg[def.Egg], def)
	;(def :: any).CatalogIndex = index
end

function Critters.Get(id: string): CritterDef?
	return byId[id]
end

function Critters.Exists(id: string): boolean
	return byId[id] ~= nil
end

function Critters.GetEgg(index: number): EggDef?
	return Critters.Eggs[index]
end

function Critters.GetPower(id: string, shiny: boolean?): number
	local def = byId[id]
	if not def then
		return 0
	end
	return def.Power * (if shiny then 2 else 1)
end

-- Probabilidades del huevo con suerte aplicada (las rarezas altas suben)
function Critters.GetEggChances(eggIndex: number, luck: number): { { Id: string, Chance: number } }
	local list = Critters.ByEgg[eggIndex] or {}
	local weights = {}
	local total = 0
	for _, def in list do
		local order = Rarities.Order(def.Rarity)
		local boost = if order >= 3 then luck ^ ((order - 2) / 2) else 1
		local weight = Critters.RarityChances[def.Rarity] * boost
		table.insert(weights, { Id = def.Id, Chance = weight })
		total += weight
	end
	for _, entry in weights do
		entry.Chance /= total
	end
	return weights
end

function Critters.Roll(rng: Random, eggIndex: number, luck: number): string
	local chances = Critters.GetEggChances(eggIndex, luck)
	local roll = rng:NextNumber()
	for _, entry in chances do
		roll -= entry.Chance
		if roll <= 0 then
			return entry.Id
		end
	end
	return chances[1].Id
end

function Critters.OfRarity(eggIndex: number, rarity: string): string?
	for _, def in Critters.ByEgg[eggIndex] or {} do
		if def.Rarity == rarity then
			return def.Id
		end
	end
	return nil
end

function Critters.Count(): number
	return #Critters.List
end

return Critters
