-- Picos (más daño) y mejoras permanentes compradas con Stardust.

export type PickaxeDef = {
	Id: string,
	Name: string,
	Damage: number,
	Cooldown: number,
	Price: number,
	GamePass: string?,
	Color: Color3,
	HeadColor: Color3,
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

Gear.Pickaxes = {
	{ Id = "Rusty", Name = "Rusty Pick", Damage = 1, Cooldown = 0.4, Price = 0, Color = Color3.fromRGB(120, 85, 55), HeadColor = Color3.fromRGB(150, 95, 70), Material = Enum.Material.Wood, Icon = "⛏️" },
	{ Id = "Stone", Name = "Stone Pick", Damage = 3, Cooldown = 0.4, Price = 60, Color = Color3.fromRGB(120, 85, 55), HeadColor = Color3.fromRGB(140, 140, 145), Material = Enum.Material.Slate, Icon = "🪨" },
	{ Id = "Iron", Name = "Iron Pick", Damage = 8, Cooldown = 0.38, Price = 600, Color = Color3.fromRGB(90, 70, 50), HeadColor = Color3.fromRGB(190, 195, 205), Material = Enum.Material.Metal, Icon = "⚙️" },
	{ Id = "Gold", Name = "Golden Pick", Damage = 20, Cooldown = 0.36, Price = 4_000, Color = Color3.fromRGB(90, 70, 50), HeadColor = Color3.fromRGB(255, 205, 50), Material = Enum.Material.Metal, Icon = "🏆" },
	{ Id = "Crystal", Name = "Crystal Pick", Damage = 55, Cooldown = 0.34, Price = 30_000, Color = Color3.fromRGB(60, 70, 90), HeadColor = Color3.fromRGB(130, 230, 255), Material = Enum.Material.Glass, Icon = "💎" },
	{ Id = "Magma", Name = "Magma Pick", Damage = 150, Cooldown = 0.32, Price = 250_000, Color = Color3.fromRGB(40, 30, 30), HeadColor = Color3.fromRGB(255, 100, 30), Material = Enum.Material.Neon, Icon = "🔥" },
	{ Id = "Lunar", Name = "Lunar Pick", Damage = 420, Cooldown = 0.3, Price = 2_500_000, Color = Color3.fromRGB(70, 75, 95), HeadColor = Color3.fromRGB(220, 230, 255), Material = Enum.Material.Neon, Icon = "🌙" },
	{ Id = "Plasma", Name = "Plasma Pick", Damage = 1_200, Cooldown = 0.28, Price = 25_000_000, Color = Color3.fromRGB(30, 30, 40), HeadColor = Color3.fromRGB(80, 255, 200), Material = Enum.Material.Neon, Icon = "⚡" },
	{ Id = "Nebula", Name = "Nebula Pick", Damage = 3_500, Cooldown = 0.26, Price = 300_000_000, Color = Color3.fromRGB(30, 20, 50), HeadColor = Color3.fromRGB(220, 110, 255), Material = Enum.Material.Neon, Icon = "🌌" },
	{ Id = "Galaxy", Name = "Galaxy Hammer", Damage = 6_000, Cooldown = 0.25, Price = 0, GamePass = "GalaxyHammer", Color = Color3.fromRGB(20, 20, 30), HeadColor = Color3.fromRGB(150, 80, 255), Material = Enum.Material.Neon, Icon = "🔨" },
} :: { PickaxeDef }

Gear.Upgrades = {
	Speed = { Key = "Speed", Name = "Rocket Legs", Icon = "👟", Description = "+1.5 walk speed per level", MaxLevel = 10, BaseCost = 300, CostGrowth = 3 },
	Crit = { Key = "Crit", Name = "Critical Hits", Icon = "💥", Description = "+2% critical hit chance per level", MaxLevel = 10, BaseCost = 500, CostGrowth = 3.2 },
	Luck = { Key = "Luck", Name = "Hatch Luck", Icon = "🍀", Description = "+10% rare critter chance per level", MaxLevel = 8, BaseCost = 1_000, CostGrowth = 3.4 },
} :: { [string]: UpgradeDef }

Gear.UpgradeOrder = { "Speed", "Crit", "Luck" }

local byId: { [string]: PickaxeDef } = {}
local tierById: { [string]: number } = {}
for index, pick in Gear.Pickaxes do
	byId[pick.Id] = pick
	tierById[pick.Id] = index
end

function Gear.GetPickaxe(id: string): PickaxeDef?
	return byId[id]
end

function Gear.GetTier(id: string): number
	return tierById[id] or 1
end

return Gear
