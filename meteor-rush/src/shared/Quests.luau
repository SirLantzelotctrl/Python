-- Misiones diarias: 3 al día, distintas para cada jugador, con premio final.

export type QuestTemplate = {
	Kind: string,
	Text: string, -- "%d" = objetivo
	Targets: { number },
	RewardMeteors: number,
}

local Quests = {}

Quests.Pool = {
	{ Kind = "BreakMeteors", Text = "Break %d meteors", Targets = { 15, 25, 40 }, RewardMeteors = 30 },
	{ Kind = "BreakRare", Text = "Break %d Rare+ meteors", Targets = { 3, 5, 8 }, RewardMeteors = 45 },
	{ Kind = "Swings", Text = "Swing your pickaxe %d times", Targets = { 250, 500, 800 }, RewardMeteors = 25 },
	{ Kind = "HatchEggs", Text = "Hatch %d eggs", Targets = { 3, 6, 10 }, RewardMeteors = 35 },
	{ Kind = "BeMVP", Text = "Be the MVP of %d meteors", Targets = { 3, 6, 10 }, RewardMeteors = 50 },
	{ Kind = "Crits", Text = "Land %d critical hits", Targets = { 30, 60, 100 }, RewardMeteors = 30 },
} :: { QuestTemplate }

Quests.PerDay = 3
-- Premio por completar las 3
Quests.Bonus = { CritterRarity = "Epic", Boost = 15 * 60 }

local byKind: { [string]: QuestTemplate } = {}
for _, template in Quests.Pool do
	byKind[template.Kind] = template
end

function Quests.GetTemplate(kind: string): QuestTemplate?
	return byKind[kind]
end

function Quests.Describe(kind: string, target: number): string
	local template = byKind[kind]
	if not template then
		return kind
	end
	return string.format(template.Text, target)
end

-- Genera las misiones del día de forma determinista (mismo día + mismo jugador = mismas misiones)
function Quests.Generate(day: number, userId: number): { { Kind: string, Target: number, Progress: number, Claimed: boolean, RewardMeteors: number } }
	local rng = Random.new(day * 7919 + (userId % 100000) * 31)
	local indices = {}
	for i = 1, #Quests.Pool do
		indices[i] = i
	end
	-- Fisher-Yates
	for i = #indices, 2, -1 do
		local j = rng:NextInteger(1, i)
		indices[i], indices[j] = indices[j], indices[i]
	end
	local list = {}
	for i = 1, Quests.PerDay do
		local template = Quests.Pool[indices[i]]
		local tier = rng:NextInteger(1, #template.Targets)
		table.insert(list, {
			Kind = template.Kind,
			Target = template.Targets[tier],
			Progress = 0,
			Claimed = false,
			RewardMeteors = template.RewardMeteors * (0.8 + tier * 0.2),
		})
	end
	return list
end

return Quests
