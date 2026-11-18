-- Fórmulas de economía (puras, sin efectos secundarios). Las usan servidor y cliente.

local Config = require(script.Parent.Config)
local Rarities = require(script.Parent.Rarities)
local Mutations = require(script.Parent.Mutations)
local Slimes = require(script.Parent.Slimes)
local Gear = require(script.Parent.Gear)

local Economy = {}

export type MultiplierContext = {
	Rebirths: number,
	IndexCount: number,
	DoubleCash: boolean,
	VIP: boolean,
	Friends: number,
	Premium: boolean,
	InGroup: boolean,
	Boost: boolean,
	EventMultiplier: number,
}

-- ---------------------------------------------------------------------
-- Slimes
-- ---------------------------------------------------------------------
function Economy.GetSlimePrice(slimeId: string, mutation: string?): number
	local def = Slimes.Get(slimeId)
	if not def then
		return 0
	end
	return def.Price * Mutations.Get(mutation).Multiplier
end

function Economy.GetSlimeIncome(slimeId: string, mutation: string?): number
	local def = Slimes.Get(slimeId)
	if not def then
		return 0
	end
	return def.Income * Mutations.Get(mutation).Multiplier
end

function Economy.GetSellPrice(slimeId: string, mutation: string?): number
	return math.floor(Economy.GetSlimePrice(slimeId, mutation) * Config.Sell.Ratio)
end

-- ---------------------------------------------------------------------
-- Progresión
-- ---------------------------------------------------------------------
function Economy.GetRebirthCost(rebirths: number): number
	return Config.Rebirth.BaseCost * (Config.Rebirth.CostGrowth ^ rebirths)
end

function Economy.GetMaxPhysicalSlots(): number
	return Config.Plots.Columns * Config.Plots.Rows
end

function Economy.GetSlotCount(rebirths: number, hasExtraSlotsPass: boolean): number
	local slots = math.min(Config.Slots.Base + rebirths * Config.Slots.PerRebirth, Config.Slots.MaxFromRebirths)
	if hasExtraSlotsPass then
		slots += Config.Slots.ExtraFromPass
	end
	return math.min(slots, Economy.GetMaxPhysicalSlots())
end

function Economy.GetLockDuration(rebirths: number, lockLevel: number, hasLongerLockPass: boolean): number
	local duration = Config.Lock.BaseDuration + rebirths * Config.Lock.PerRebirth + lockLevel * Config.Lock.PerUpgradeLevel
	if hasLongerLockPass then
		duration += Config.Lock.PassBonus
	end
	return duration
end

function Economy.GetWalkSpeed(speedLevel: number, hasSpeedPass: boolean): number
	local speed = Config.Player.BaseWalkSpeed + speedLevel * Gear.SpeedPerLevel
	if hasSpeedPass then
		speed += Config.Player.SpeedPassBonus
	end
	return speed
end

function Economy.GetUpgradeCost(upgradeKey: string, level: number): number
	local def = Gear.Upgrades[upgradeKey]
	if not def then
		return math.huge
	end
	return math.floor(def.BaseCost * (def.CostGrowth ^ level))
end

-- ---------------------------------------------------------------------
-- Multiplicador de ingresos
-- ---------------------------------------------------------------------
function Economy.GetIncomeMultiplier(ctx: MultiplierContext): (number, { { Label: string, Value: string } })
	local breakdown = {}
	local additive = 1

	if ctx.Rebirths > 0 then
		local bonus = ctx.Rebirths * Config.Rebirth.IncomeBonus
		additive += bonus
		table.insert(breakdown, { Label = "Rebirths", Value = "+" .. math.floor(bonus * 100 + 0.5) .. "%" })
	end
	if ctx.IndexCount > 0 then
		local bonus = ctx.IndexCount * Config.Income.IndexBonusPerEntry
		additive += bonus
		table.insert(breakdown, { Label = "Index", Value = "+" .. string.format("%.1f", bonus * 100) .. "%" })
	end
	if ctx.Friends > 0 then
		local bonus = math.min(ctx.Friends * Config.Income.FriendBonus, Config.Income.MaxFriendBonus)
		additive += bonus
		table.insert(breakdown, { Label = "Friends", Value = "+" .. math.floor(bonus * 100 + 0.5) .. "%" })
	end
	if ctx.VIP then
		additive += Config.Income.VipBonus
		table.insert(breakdown, { Label = "VIP", Value = "+" .. math.floor(Config.Income.VipBonus * 100 + 0.5) .. "%" })
	end
	if ctx.Premium then
		additive += Config.Income.PremiumBonus
		table.insert(breakdown, { Label = "Premium", Value = "+" .. math.floor(Config.Income.PremiumBonus * 100 + 0.5) .. "%" })
	end
	if ctx.InGroup then
		additive += Config.Income.GroupBonus
		table.insert(breakdown, { Label = "Group", Value = "+" .. math.floor(Config.Income.GroupBonus * 100 + 0.5) .. "%" })
	end

	local total = additive
	if ctx.DoubleCash then
		total *= Config.Income.DoubleCash
		table.insert(breakdown, { Label = "2x Cash Pass", Value = "x" .. Config.Income.DoubleCash })
	end
	if ctx.Boost then
		total *= Config.Income.BoostMultiplier
		table.insert(breakdown, { Label = "Cash Boost", Value = "x" .. Config.Income.BoostMultiplier })
	end
	if ctx.EventMultiplier ~= 1 then
		total *= ctx.EventMultiplier
		table.insert(breakdown, { Label = "Event", Value = "x" .. ctx.EventMultiplier })
	end
	return total, breakdown
end

-- ---------------------------------------------------------------------
-- Tiradas aleatorias (rng = Random)
-- ---------------------------------------------------------------------
function Economy.GetRarityWeights(luck: number): { { Name: string, Weight: number } }
	local weights = {}
	for _, rarity in Rarities.List do
		local exponent = (rarity.Order - 1) / 3
		table.insert(weights, { Name = rarity.Name, Weight = rarity.Weight * (luck ^ exponent) })
	end
	return weights
end

function Economy.GetRarityChances(luck: number): { [string]: number }
	local weights = Economy.GetRarityWeights(luck)
	local total = 0
	for _, entry in weights do
		total += entry.Weight
	end
	local chances = {}
	for _, entry in weights do
		chances[entry.Name] = entry.Weight / total
	end
	return chances
end

function Economy.RollRarity(rng: Random, luck: number): string
	local weights = Economy.GetRarityWeights(luck)
	local total = 0
	for _, entry in weights do
		total += entry.Weight
	end
	local roll = rng:NextNumber() * total
	for _, entry in weights do
		roll -= entry.Weight
		if roll <= 0 then
			return entry.Name
		end
	end
	return weights[1].Name
end

-- Dentro de una rareza, los slimes más baratos salen más a menudo.
function Economy.PickSlimeOfRarity(rng: Random, rarityName: string): string
	local list = Slimes.ByRarity[rarityName]
	if not list or #list == 0 then
		return Slimes.List[1].Id
	end
	local total = 0
	for index = 1, #list do
		total += (#list - index + 1)
	end
	local roll = rng:NextNumber() * total
	for index, def in list do
		roll -= (#list - index + 1)
		if roll <= 0 then
			return def.Id
		end
	end
	return list[#list].Id
end

function Economy.RollMutation(rng: Random, mutationLuck: number): string
	local roll = rng:NextNumber()
	local cumulative = 0
	for _, mutation in Mutations.List do
		cumulative += mutation.Chance * mutationLuck
		if roll < cumulative then
			return mutation.Name
		end
	end
	return "Normal"
end

-- ---------------------------------------------------------------------
-- Index
-- ---------------------------------------------------------------------
function Economy.CountIndex(index: { [string]: { [string]: boolean } }?): number
	local count = 0
	if not index then
		return 0
	end
	for slimeId, mutations in index do
		if Slimes.Exists(slimeId) then
			for mutationName, discovered in mutations do
				if discovered and (mutationName == "Normal" or Mutations.Exists(mutationName)) then
					count += 1
				end
			end
		end
	end
	return count
end

function Economy.GetIndexTotal(): number
	return #Slimes.List * (#Mutations.List + 1)
end

-- ---------------------------------------------------------------------
-- Recompensas que escalan con tus ingresos (siguen siendo útiles en late game)
-- ---------------------------------------------------------------------
function Economy.ScaleReward(minimum: number?, incomePerSecond: number, seconds: number?): number
	local base = minimum or 0
	local scaled = if seconds then incomePerSecond * seconds else 0
	return math.floor(math.max(base, scaled))
end

-- OrderedDataStore solo acepta enteros: guardamos log10 para soportar números enormes.
function Economy.EncodeScore(value: number): number
	if value <= 0 then
		return 0
	end
	return math.floor(math.log10(value + 1) * 1e10)
end

function Economy.DecodeScore(encoded: number): number
	if encoded <= 0 then
		return 0
	end
	return math.max(0, 10 ^ (encoded / 1e10) - 1)
end

return Economy
