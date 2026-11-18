-- Catálogo de slimes. Price = coste en la pasarela, Income = $/s base.
-- Accessories: piezas decorativas que construye SlimeBuilder (ver lista allí).

export type SlimeDef = {
	Id: string,
	Name: string,
	Rarity: string,
	Price: number,
	Income: number,
	Color: Color3,
	Accessories: { string },
	EyeScale: number?,
	Material: Enum.Material?,
}

local Slimes = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

Slimes.List = {
	-- COMMON ------------------------------------------------------------
	{ Id = "blobby", Name = "Blobby", Rarity = "Common", Price = 25, Income = 1, Color = rgb(120, 220, 120), Accessories = {} },
	{ Id = "puddle_pal", Name = "Puddle Pal", Rarity = "Common", Price = 60, Income = 2, Color = rgb(90, 170, 255), Accessories = { "Bow" } },
	{ Id = "gloop_jr", Name = "Gloop Jr.", Rarity = "Common", Price = 120, Income = 4, Color = rgb(255, 150, 60), Accessories = { "Cap" } },
	{ Id = "wobblet", Name = "Wobblet", Rarity = "Common", Price = 250, Income = 8, Color = rgb(255, 130, 200), Accessories = {}, EyeScale = 1.45 },

	-- UNCOMMON ----------------------------------------------------------
	{ Id = "mossy_mo", Name = "Mossy Mo", Rarity = "Uncommon", Price = 500, Income = 15, Color = rgb(95, 145, 60), Accessories = { "Moss", "Sprout" } },
	{ Id = "bubble_bob", Name = "Bubble Bob", Rarity = "Uncommon", Price = 900, Income = 28, Color = rgb(120, 220, 255), Accessories = { "Bubbles" } },
	{ Id = "minty_squish", Name = "Minty Squish", Rarity = "Uncommon", Price = 1_500, Income = 45, Color = rgb(150, 255, 200), Accessories = { "MintLeaf" } },
	{ Id = "pebble_plop", Name = "Pebble Plop", Rarity = "Uncommon", Price = 2_400, Income = 75, Color = rgb(160, 150, 140), Accessories = { "Pebbles" } },

	-- RARE --------------------------------------------------------------
	{ Id = "frosty_flop", Name = "Frosty Flop", Rarity = "Rare", Price = 4_000, Income = 115, Color = rgb(185, 235, 255), Accessories = { "IceCrystals" } },
	{ Id = "lava_lump", Name = "Lava Lump", Rarity = "Rare", Price = 6_500, Income = 180, Color = rgb(230, 70, 30), Accessories = { "Flame" } },
	{ Id = "zappy_zorp", Name = "Zappy Zorp", Rarity = "Rare", Price = 10_000, Income = 280, Color = rgb(255, 235, 60), Accessories = { "Antennae", "Sparkle" } },
	{ Id = "sir_jiggles", Name = "Sir Jiggles", Rarity = "Rare", Price = 16_000, Income = 450, Color = rgb(175, 175, 195), Accessories = { "KnightHelmet" } },

	-- EPIC --------------------------------------------------------------
	{ Id = "ninja_nugget", Name = "Ninja Nugget", Rarity = "Epic", Price = 25_000, Income = 650, Color = rgb(45, 45, 55), Accessories = { "Headband" } },
	{ Id = "disco_drip", Name = "Disco Drip", Rarity = "Epic", Price = 40_000, Income = 1_000, Color = rgb(200, 80, 255), Accessories = { "Shades", "Sparkle" } },
	{ Id = "pirate_plap", Name = "Pirate Plap", Rarity = "Epic", Price = 65_000, Income = 1_600, Color = rgb(100, 200, 140), Accessories = { "PirateHat", "EyePatch" } },
	{ Id = "witchy_wub", Name = "Witchy Wub", Rarity = "Epic", Price = 100_000, Income = 2_500, Color = rgb(135, 95, 205), Accessories = { "WitchHat" } },

	-- LEGENDARY ---------------------------------------------------------
	{ Id = "king_gooberius", Name = "King Gooberius", Rarity = "Legendary", Price = 160_000, Income = 3_600, Color = rgb(255, 90, 90), Accessories = { "Crown", "Cape", "Mustache" } },
	{ Id = "dragoo", Name = "Dragoo", Rarity = "Legendary", Price = 260_000, Income = 5_800, Color = rgb(80, 200, 90), Accessories = { "Horns", "Spikes", "SmallWings" } },
	{ Id = "astro_blob", Name = "Astro Blob", Rarity = "Legendary", Price = 420_000, Income = 9_300, Color = rgb(240, 240, 255), Accessories = { "AstroHelmet", "Antennae" } },
	{ Id = "samurai_splash", Name = "Samurai Splash", Rarity = "Legendary", Price = 680_000, Income = 15_000, Color = rgb(60, 120, 220), Accessories = { "SamuraiHelmet" } },

	-- MYTHIC ------------------------------------------------------------
	{ Id = "cyber_gloop", Name = "Cyber Gloop 3000", Rarity = "Mythic", Price = 1_100_000, Income = 22_000, Color = rgb(45, 65, 85), Accessories = { "Visor", "Antennae" } },
	{ Id = "phoenix_puddle", Name = "Phoenix Puddle", Rarity = "Mythic", Price = 1_800_000, Income = 36_000, Color = rgb(255, 120, 30), Accessories = { "Flame", "Wings" } },
	{ Id = "kraken_jelly", Name = "Kraken Jelly", Rarity = "Mythic", Price = 3_000_000, Income = 60_000, Color = rgb(220, 60, 150), Accessories = { "Tentacles" } },
	{ Id = "pharaoh_plasm", Name = "Pharaoh Plasm", Rarity = "Mythic", Price = 5_000_000, Income = 100_000, Color = rgb(60, 90, 200), Accessories = { "Nemes" } },

	-- DIVINE ------------------------------------------------------------
	{ Id = "angel_ooze", Name = "Angel Ooze", Rarity = "Divine", Price = 8_000_000, Income = 135_000, Color = rgb(255, 250, 230), Accessories = { "Halo", "Wings" } },
	{ Id = "thunder_titan", Name = "Thunder Titan", Rarity = "Divine", Price = 13_000_000, Income = 220_000, Color = rgb(70, 80, 165), Accessories = { "Lightning", "Crown" } },
	{ Id = "celestia_goo", Name = "Celestia Goo", Rarity = "Divine", Price = 21_000_000, Income = 350_000, Color = rgb(255, 200, 255), Accessories = { "StarCrown", "Stars" } },
	{ Id = "chrono_blob", Name = "Chrono Blob", Rarity = "Divine", Price = 35_000_000, Income = 580_000, Color = rgb(205, 175, 95), Accessories = { "Clock" } },

	-- SECRET ------------------------------------------------------------
	{ Id = "the_glitch", Name = "The Glitch", Rarity = "Secret", Price = 60_000_000, Income = 850_000, Color = rgb(0, 255, 120), Accessories = { "GlitchCubes" }, Material = Enum.Material.Neon },
	{ Id = "void_emperor", Name = "Void Emperor", Rarity = "Secret", Price = 100_000_000, Income = 1_400_000, Color = rgb(30, 12, 45), Accessories = { "DarkCrown", "Aura" } },
	{ Id = "galactic_gooliath", Name = "Galactic Gooliath", Rarity = "Secret", Price = 175_000_000, Income = 2_500_000, Color = rgb(70, 35, 150), Accessories = { "Rings", "Stars" } },
	{ Id = "omega_slime", Name = "Omega Slime", Rarity = "Secret", Price = 300_000_000, Income = 4_300_000, Color = rgb(255, 255, 255), Accessories = { "Halo", "Wings", "Crown", "Aura" } },
} :: { SlimeDef }

local byId: { [string]: SlimeDef } = {}
Slimes.ByRarity = {} :: { [string]: { SlimeDef } }

for index, def in Slimes.List do
	assert(byId[def.Id] == nil, "Slime duplicado: " .. def.Id)
	byId[def.Id] = def
	Slimes.ByRarity[def.Rarity] = Slimes.ByRarity[def.Rarity] or {}
	table.insert(Slimes.ByRarity[def.Rarity], def)
	;(def :: any).CatalogIndex = index
end

function Slimes.Get(id: string): SlimeDef?
	return byId[id]
end

function Slimes.Exists(id: string): boolean
	return byId[id] ~= nil
end

function Slimes.Count(): number
	return #Slimes.List
end

return Slimes
