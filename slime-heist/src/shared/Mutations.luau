-- Mutaciones: multiplican precio e ingresos y cambian el aspecto del slime.

export type Mutation = {
	Name: string,
	Multiplier: number,
	Chance: number,
	Color: Color3,
	Icon: string,
}

local Mutations = {}

-- Ordenadas de más rara a menos rara (importante para la tirada)
Mutations.List = {
	{ Name = "Galaxy", Multiplier = 8, Chance = 0.004, Color = Color3.fromRGB(170, 90, 255), Icon = "🌌" },
	{ Name = "Rainbow", Multiplier = 4, Chance = 0.01, Color = Color3.fromRGB(255, 120, 200), Icon = "🌈" },
	{ Name = "Diamond", Multiplier = 2, Chance = 0.025, Color = Color3.fromRGB(130, 230, 255), Icon = "💎" },
	{ Name = "Gold", Multiplier = 1.5, Chance = 0.06, Color = Color3.fromRGB(255, 205, 40), Icon = "🪙" },
} :: { Mutation }

Mutations.Normal = { Name = "Normal", Multiplier = 1, Chance = 0, Color = Color3.fromRGB(255, 255, 255), Icon = "" } :: Mutation

-- Orden de visualización en el Index (Normal primero)
Mutations.DisplayOrder = { "Normal", "Gold", "Diamond", "Rainbow", "Galaxy" }

local byName: { [string]: Mutation } = { Normal = Mutations.Normal }
for _, mutation in Mutations.List do
	byName[mutation.Name] = mutation
end

function Mutations.Get(name: string?): Mutation
	if name == nil then
		return Mutations.Normal
	end
	return byName[name] or Mutations.Normal
end

function Mutations.Exists(name: string): boolean
	return byName[name] ~= nil
end

return Mutations
