-- Equipamiento comprable con cash: bates (para golpear ladrones) y mejoras permanentes.

export type BatDef = {
	Id: string,
	Name: string,
	Price: number,
	RebirthRequired: number,
	GamePass: string?,
	Knockback: number,
	Cooldown: number,
	Range: number,
	Color: Color3,
	Material: Enum.Material,
	Icon: string,
}

export type UpgradeDef = {
	Key: string,
	Name: string,
	Icon: string,
	Description: string,
	MaxLevel: number,
	BaseCost: number,
	CostGrowth: number,
}

local Gear = {}

Gear.Bats = {
	{ Id = "Wood", Name = "Wooden Bat", Price = 0, RebirthRequired = 0, Knockback = 55, Cooldown = 1.0, Range = 9, Color = Color3.fromRGB(160, 110, 60), Material = Enum.Material.Wood, Icon = "🪵" },
	{ Id = "Iron", Name = "Iron Bat", Price = 15_000, RebirthRequired = 0, Knockback = 75, Cooldown = 0.85, Range = 10, Color = Color3.fromRGB(150, 155, 165), Material = Enum.Material.Metal, Icon = "⚙️" },
	{ Id = "Gold", Name = "Golden Bat", Price = 750_000, RebirthRequired = 1, Knockback = 95, Cooldown = 0.7, Range = 11, Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Metal, Icon = "🏆" },
	{ Id = "Diamond", Name = "Diamond Bat", Price = 25_000_000, RebirthRequired = 3, Knockback = 120, Cooldown = 0.6, Range = 12, Color = Color3.fromRGB(120, 230, 255), Material = Enum.Material.Glass, Icon = "💎" },
	{ Id = "Galaxy", Name = "Galaxy Bat", Price = 0, RebirthRequired = 0, GamePass = "GalaxyBat", Knockback = 160, Cooldown = 0.5, Range = 13, Color = Color3.fromRGB(150, 70, 255), Material = Enum.Material.Neon, Icon = "🌌" },
} :: { BatDef }

Gear.Upgrades = {
	Speed = { Key = "Speed", Name = "Walk Speed", Icon = "👟", Description = "+1.5 walk speed per level", MaxLevel = 10, BaseCost = 2_000, CostGrowth = 3.2 },
	Lock = { Key = "Lock", Name = "Lock Time", Icon = "🔒", Description = "+5s base lock per level", MaxLevel = 10, BaseCost = 5_000, CostGrowth = 3.4 },
} :: { [string]: UpgradeDef }

Gear.UpgradeOrder = { "Speed", "Lock" }

Gear.SpeedPerLevel = 1.5

local batById: { [string]: BatDef } = {}
for index, bat in Gear.Bats do
	batById[bat.Id] = bat
	;(bat :: any).Tier = index
end

function Gear.GetBat(id: string): BatDef?
	return batById[id]
end

return Gear
