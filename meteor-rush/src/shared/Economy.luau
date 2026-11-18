-- Fórmulas de economía (puras). Las usan servidor y cliente.

local Config = require(script.Parent.Config)
local Rarities = require(script.Parent.Rarities)
local Zones = require(script.Parent.Zones)
local Gear = require(script.Parent.Gear)
local Critters = require(script.Parent.Critters)

local Economy = {}

export type StardustContext = {
	Rebirths: number,
	Friends: number,
	VIP: boolean,
	Premium: boolean,
	InGroup: boolean,
	DoubleStardust: boolean,
	Boost: boolean,
	EventMultiplier: number,
}

export type DamageContext = {
	CritterBonus: number,
	Rebirths: number,
	VIP: boolean,
	DamageBoost: boolean,
}

type Breakdown = { { Label: string, Value: string } }

local function pct(value: number): string
	return "+" .. tostring(math.floor(value * 100 + 0.5)) .. "%"
end

-- ---------------------------------------------------------------------
-- Meteoritos
-- ---------------------------------------------------------------------
function Economy.GetMeteorHP(zoneIndex: number, rarity: string): number
	return math.floor(Zones.Get(zoneIndex).BaseHP * Rarities.Get(rarity).HpMult)
end

function Economy.GetMeteorLoot(zoneIndex: number, rarity: string): number
	return Zones.Get(zoneIndex).BaseLoot * Rarities.Get(rarity).LootMult
end

function Economy.GetRarityWeights(luck: number): { { Name: string, Weight: number } }
	local list = {}
	for _, rarity in Rarities.List do
		table.insert(list, { Name = rarity.Name, Weight = rarity.Weight * (luck ^ ((rarity.Order - 1) / 3)) })
	end
	return list
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

function Economy.RollMeteorRarity(rng: Random, luck: number): string
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

-- ---------------------------------------------------------------------
-- Progresión
-- ---------------------------------------------------------------------
function Economy.GetRebirthCost(rebirths: number): number
	return Config.Rebirth.BaseCost * (Config.Rebirth.CostGrowth ^ rebirths)
end

function Economy.GetSlotCount(rebirths: number, hasExtraSlots: boolean): number
	local slots = Config.Critters.BaseSlots + math.min(rebirths * Config.Critters.SlotsPerRebirth, Config.Critters.MaxSlotsFromRebirth)
	if hasExtraSlots then
		slots += Config.Critters.PassSlots
	end
	return slots
end

function Economy.GetWalkSpeed(speedLevel: number, hasBoots: boolean): number
	local speed = Config.Player.BaseWalkSpeed + speedLevel * Config.Player.SpeedPerLevel
	if hasBoots then
		speed += Config.Player.BootsSpeed
	end
	return speed
end

function Economy.GetUpgradeCost(key: string, level: number): number
	local def = Gear.Upgrades[key]
	if not def then
		return math.huge
	end
	return math.floor(def.BaseCost * (def.CostGrowth ^ level))
end

function Economy.GetCritChance(level: number): number
	return Config.Mining.BaseCritChance + level * Config.Mining.CritPerLevel
end

function Economy.GetHatchLuck(level: number, hasLuckyPass: boolean): number
	local luck = 1 + level * Config.Critters.LuckPerLevel
	if hasLuckyPass then
		luck *= Config.Critters.LuckyPassMultiplier
	end
	return luck
end

-- ---------------------------------------------------------------------
-- Multiplicadores
-- ---------------------------------------------------------------------
function Economy.GetStardustMultiplier(ctx: StardustContext): (number, Breakdown)
	local breakdown = {}
	local additive = 1
	if ctx.Rebirths > 0 then
		local bonus = ctx.Rebirths * Config.Rebirth.StardustBonus
		additive += bonus
		table.insert(breakdown, { Label = "Supernovas", Value = pct(bonus) })
	end
	if ctx.Friends > 0 then
		local bonus = math.min(ctx.Friends * Config.Income.FriendBonus, Config.Income.MaxFriendBonus)
		additive += bonus
		table.insert(breakdown, { Label = "Friends", Value = pct(bonus) })
	end
	if ctx.VIP then
		additive += Config.Income.VipStardust
		table.insert(breakdown, { Label = "VIP", Value = pct(Config.Income.VipStardust) })
	end
	if ctx.Premium then
		additive += Config.Income.PremiumBonus
		table.insert(breakdown, { Label = "Premium", Value = pct(Config.Income.PremiumBonus) })
	end
	if ctx.InGroup then
		additive += Config.Income.GroupBonus
		table.insert(breakdown, { Label = "Group", Value = pct(Config.Income.GroupBonus) })
	end
	local total = additive
	if ctx.DoubleStardust then
		total *= Config.Income.DoubleStardust
		table.insert(breakdown, { Label = "2x Stardust", Value = "x" .. Config.Income.DoubleStardust })
	end
	if ctx.Boost then
		total *= Config.Income.BoostMultiplier
		table.insert(breakdown, { Label = "Stardust Boost", Value = "x" .. Config.Income.BoostMultiplier })
	end
	if ctx.EventMultiplier ~= 1 then
		total *= ctx.EventMultiplier
		table.insert(breakdown, { Label = "Event", Value = "x" .. ctx.EventMultiplier })
	end
	return total, breakdown
end

function Economy.GetDamageMultiplier(ctx: DamageContext): (number, Breakdown)
	local breakdown = {}
	local total = 1 + ctx.CritterBonus
	if ctx.CritterBonus > 0 then
		table.insert(breakdown, { Label = "Critters", Value = pct(ctx.CritterBonus) })
	end
	if ctx.Rebirths > 0 then
		local bonus = ctx.Rebirths * Config.Rebirth.DamageBonus
		total *= 1 + bonus
		table.insert(breakdown, { Label = "Supernovas", Value = pct(bonus) })
	end
	if ctx.VIP then
		total *= 1 + Config.Income.VipDamage
		table.insert(breakdown, { Label = "VIP", Value = pct(Config.Income.VipDamage) })
	end
	if ctx.DamageBoost then
		total *= Config.Income.BoostMultiplier
		table.insert(breakdown, { Label = "Damage Boost", Value = "x" .. Config.Income.BoostMultiplier })
	end
	return total, breakdown
end

function Economy.GetHitDamage(pickaxeId: string, damageMultiplier: number): number
	local pick = Gear.GetPickaxe(pickaxeId) or Gear.Pickaxes[1]
	return pick.Damage * damageMultiplier
end

-- Suma de poder de las criaturas equipadas
function Economy.GetCritterBonus(equipped: { { Id: string, Shiny: boolean? } }): number
	local total = 0
	for _, entry in equipped do
		total += Critters.GetPower(entry.Id, entry.Shiny)
	end
	return total
end

-- ---------------------------------------------------------------------
-- Recompensas que escalan con el progreso (valor de N meteoritos medios)
-- ---------------------------------------------------------------------
local AVERAGE_LOOT = Rarities.AverageLootMult()

function Economy.GetRewardBase(bestZone: number, stardustMultiplier: number): number
	return Zones.Get(bestZone).BaseLoot * AVERAGE_LOOT * stardustMultiplier
end

function Economy.ScaleReward(minimum: number?, rewardBase: number, meteors: number?): number
	local scaled = if meteors then rewardBase * meteors else 0
	return math.floor(math.max(minimum or 0, scaled))
end

-- ---------------------------------------------------------------------
-- Index / clasificaciones
-- ---------------------------------------------------------------------
function Economy.CountIndex(index: { [string]: { [string]: boolean } }?): number
	local count = 0
	if not index then
		return 0
	end
	for critterId, variants in index do
		if Critters.Exists(critterId) then
			if variants.Normal then
				count += 1
			end
			if variants.Shiny then
				count += 1
			end
		end
	end
	return count
end

function Economy.GetIndexTotal(): number
	return Critters.Count() * 2
end

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
