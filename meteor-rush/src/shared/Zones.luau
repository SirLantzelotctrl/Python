-- Zonas del mapa (en fila). Cada una tiene meteoritos más duros y con más botín.

export type Zone = {
	Index: number,
	Id: string,
	Name: string,
	Icon: string,
	Cost: number,
	BaseHP: number,
	BaseLoot: number,
	GroundColor: Color3,
	GroundMaterial: Enum.Material,
	RockColor: Color3,
	AccentColor: Color3,
	Decor: string,
	LowGravity: boolean,
	Ambient: { ClockTime: number, Brightness: number, Ambient: Color3, Fog: Color3 },
}

local Zones = {}

Zones.List = {
	{
		Index = 1, Id = "Meadow", Name = "Meadow Crater", Icon = "🌿", Cost = 0, BaseHP = 15, BaseLoot = 8,
		GroundColor = Color3.fromRGB(105, 185, 85), GroundMaterial = Enum.Material.Grass,
		RockColor = Color3.fromRGB(95, 85, 80), AccentColor = Color3.fromRGB(120, 255, 140), Decor = "Trees", LowGravity = false,
		Ambient = { ClockTime = 14.5, Brightness = 2.2, Ambient = Color3.fromRGB(100, 100, 115), Fog = Color3.fromRGB(200, 225, 255) },
	},
	{
		Index = 2, Id = "Dunes", Name = "Dune Desert", Icon = "🏜️", Cost = 2_500, BaseHP = 260, BaseLoot = 55,
		GroundColor = Color3.fromRGB(232, 200, 140), GroundMaterial = Enum.Material.Sand,
		RockColor = Color3.fromRGB(120, 85, 60), AccentColor = Color3.fromRGB(255, 200, 90), Decor = "Cacti", LowGravity = false,
		Ambient = { ClockTime = 15.5, Brightness = 2.6, Ambient = Color3.fromRGB(125, 105, 85), Fog = Color3.fromRGB(255, 225, 180) },
	},
	{
		Index = 3, Id = "Tundra", Name = "Frost Tundra", Icon = "❄️", Cost = 40_000, BaseHP = 3_800, BaseLoot = 600,
		GroundColor = Color3.fromRGB(228, 240, 255), GroundMaterial = Enum.Material.Snow,
		RockColor = Color3.fromRGB(80, 95, 120), AccentColor = Color3.fromRGB(140, 220, 255), Decor = "Pines", LowGravity = false,
		Ambient = { ClockTime = 13, Brightness = 2, Ambient = Color3.fromRGB(110, 125, 150), Fog = Color3.fromRGB(215, 235, 255) },
	},
	{
		Index = 4, Id = "Magma", Name = "Magma Fields", Icon = "🌋", Cost = 650_000, BaseHP = 52_000, BaseLoot = 7_000,
		GroundColor = Color3.fromRGB(62, 48, 46), GroundMaterial = Enum.Material.Basalt,
		RockColor = Color3.fromRGB(35, 28, 28), AccentColor = Color3.fromRGB(255, 110, 30), Decor = "Lava", LowGravity = false,
		Ambient = { ClockTime = 18, Brightness = 1.6, Ambient = Color3.fromRGB(130, 70, 50), Fog = Color3.fromRGB(150, 70, 40) },
	},
	{
		Index = 5, Id = "Moon", Name = "Moon Plateau", Icon = "🌙", Cost = 11_000_000, BaseHP = 750_000, BaseLoot = 85_000,
		GroundColor = Color3.fromRGB(175, 175, 185), GroundMaterial = Enum.Material.Slate,
		RockColor = Color3.fromRGB(70, 70, 82), AccentColor = Color3.fromRGB(200, 220, 255), Decor = "Craters", LowGravity = true,
		Ambient = { ClockTime = 0, Brightness = 1.2, Ambient = Color3.fromRGB(110, 115, 140), Fog = Color3.fromRGB(20, 22, 40) },
	},
	{
		Index = 6, Id = "Nebula", Name = "Nebula Rift", Icon = "🌌", Cost = 220_000_000, BaseHP = 11_000_000, BaseLoot = 1_100_000,
		GroundColor = Color3.fromRGB(50, 30, 80), GroundMaterial = Enum.Material.SmoothPlastic,
		RockColor = Color3.fromRGB(30, 20, 55), AccentColor = Color3.fromRGB(230, 110, 255), Decor = "Crystals", LowGravity = false,
		Ambient = { ClockTime = 0, Brightness = 1, Ambient = Color3.fromRGB(120, 80, 160), Fog = Color3.fromRGB(60, 30, 90) },
	},
} :: { Zone }

function Zones.Get(index: number): Zone
	return Zones.List[math.clamp(index, 1, #Zones.List)]
end

function Zones.Count(): number
	return #Zones.List
end

return Zones
