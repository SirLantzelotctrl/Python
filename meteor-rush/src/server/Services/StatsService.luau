-- Estadísticas derivadas de cada jugador (daño por golpe, multiplicadores, suerte...)
-- con caché. Cualquier cambio relevante llama a StatsService.Invalidate(player).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Gear = require(Shared.Gear)

local Registry = require(script.Parent.Parent.Registry)
local Net = require(script.Parent.Parent.Net)

local StatsService = {}

type Stats = {
	CritterBonus: number,
	DamageMultiplier: number,
	DamageBreakdown: { any },
	StardustMultiplier: number,
	StardustBreakdown: { any },
	Pickaxe: string,
	HitDamage: number,
	Cooldown: number,
	CritChance: number,
	HatchLuck: number,
	RewardBase: number,
	SlotCount: number,
}

local cache: { [Player]: Stats } = {}

local function compute(player: Player): Stats?
	local data = Registry.DataService.Get(player)
	if not data then
		return nil
	end
	local passes = Registry.MonetizationService.GetOwnedPasses(player)
	local critterBonus = if Registry.CritterService then Registry.CritterService.GetEquippedBonus(player) else 0
	local damageMultiplier, damageBreakdown = Economy.GetDamageMultiplier({
		CritterBonus = critterBonus,
		Rebirths = data.Rebirths,
		VIP = passes.VIP == true,
		DamageBoost = (data.Boosts.Damage or 0) > 0,
	})
	local playerService = Registry.PlayerService
	local stardustMultiplier, stardustBreakdown = Economy.GetStardustMultiplier({
		Rebirths = data.Rebirths,
		Friends = if playerService then playerService.GetFriendCount(player) else 0,
		VIP = passes.VIP == true,
		Premium = player.MembershipType == Enum.MembershipType.Premium,
		InGroup = if playerService then playerService.IsInGroup(player) else false,
		DoubleStardust = passes.DoubleStardust == true,
		Boost = (data.Boosts.Stardust or 0) > 0,
		EventMultiplier = Registry.EventService.GetStardustMultiplier(),
	})
	local pickaxeId = data.Pickaxe
	local pick = Gear.GetPickaxe(pickaxeId)
	if not pick or (pick.GamePass and passes[pick.GamePass] ~= true) then
		pickaxeId = "Rusty"
		pick = Gear.GetPickaxe("Rusty")
	end
	return {
		CritterBonus = critterBonus,
		DamageMultiplier = damageMultiplier,
		DamageBreakdown = damageBreakdown,
		StardustMultiplier = stardustMultiplier,
		StardustBreakdown = stardustBreakdown,
		Pickaxe = pickaxeId,
		HitDamage = Economy.GetHitDamage(pickaxeId, damageMultiplier),
		Cooldown = (pick :: Gear.PickaxeDef).Cooldown,
		CritChance = Economy.GetCritChance(data.Upgrades.Crit or 0),
		HatchLuck = Economy.GetHatchLuck(data.Upgrades.Luck or 0, passes.LuckyHatch == true),
		RewardBase = Economy.GetRewardBase(data.Zone, stardustMultiplier),
		SlotCount = Economy.GetSlotCount(data.Rebirths, passes.ExtraSlots == true),
	}
end

function StatsService.Get(player: Player): Stats?
	local stats = cache[player]
	if not stats then
		stats = compute(player)
		cache[player] = stats
		if stats then
			player:SetAttribute("HitDamage", stats.HitDamage)
		end
	end
	return stats
end

function StatsService.Invalidate(player: Player)
	cache[player] = nil
	StatsService.Get(player)
	Registry.DataService.MarkDirty(player)
end

function StatsService.InvalidateAll()
	for _, player in Players:GetPlayers() do
		StatsService.Invalidate(player)
	end
end

function StatsService.GetHitDamage(player: Player): number
	local stats = StatsService.Get(player)
	return if stats then stats.HitDamage else 1
end

function StatsService.GetCooldown(player: Player): number
	local stats = StatsService.Get(player)
	return if stats then stats.Cooldown else 0.4
end

function StatsService.GetCritChance(player: Player): number
	local stats = StatsService.Get(player)
	return if stats then stats.CritChance else 0
end

function StatsService.GetStardustMultiplier(player: Player): number
	local stats = StatsService.Get(player)
	return if stats then stats.StardustMultiplier else 1
end

function StatsService.GetRewardBase(player: Player): number
	local stats = StatsService.Get(player)
	return if stats then stats.RewardBase else 1
end

function StatsService.GetHatchLuck(player: Player): number
	local stats = StatsService.Get(player)
	return if stats then stats.HatchLuck else 1
end

function StatsService.GetSlotCount(player: Player): number
	local stats = StatsService.Get(player)
	return if stats then stats.SlotCount else Config.Critters.BaseSlots
end

-- Daño por segundo estimado (para dimensionar el cometa)
function StatsService.EstimateDps(player: Player): number
	local stats = StatsService.Get(player)
	if not stats then
		return 0
	end
	local data = Registry.DataService.Get(player)
	local helpers = if data then #data.Equipped else 0
	local crit = 1 + stats.CritChance * (Config.Mining.CritMultiplier - 1)
	return stats.HitDamage / stats.Cooldown * crit * 0.7 + stats.HitDamage * Config.Mining.HelperDpsFactor * helpers
end

function StatsService.FillView(player: Player, view: { [string]: any })
	local stats = StatsService.Get(player)
	if not stats then
		return
	end
	local data = Registry.DataService.Get(player)
	view.DamageMultiplier = stats.DamageMultiplier
	view.DamageBreakdown = stats.DamageBreakdown
	view.StardustMultiplier = stats.StardustMultiplier
	view.StardustBreakdown = stats.StardustBreakdown
	view.HitDamage = stats.HitDamage
	view.ActivePickaxe = stats.Pickaxe
	view.CritChance = stats.CritChance
	view.HatchLuck = stats.HatchLuck
	view.RewardBase = stats.RewardBase
	view.SlotCount = stats.SlotCount
	view.RebirthCost = Economy.GetRebirthCost(if data then data.Rebirths else 0)
end

function StatsService.Start()
	-- Contadores de boosts y tiempo jugado
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local data = Registry.DataService.Get(player)
				if data then
					data.Stats.Playtime += 1
					for _, key in { "Stardust", "Damage" } do
						if (data.Boosts[key] or 0) > 0 then
							data.Boosts[key] = math.max(0, data.Boosts[key] - 1)
							player:SetAttribute("Boost" .. key, data.Boosts[key])
							if data.Boosts[key] == 0 then
								StatsService.Invalidate(player)
								Net.Notify(player, (if key == "Damage" then "⚔️ Damage" else "⏫ Stardust") .. " boost ended", "Info")
							end
						end
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		cache[player] = nil
	end)
end

function StatsService.AddBoost(player: Player, key: string, seconds: number)
	local data = Registry.DataService.Get(player)
	if not data then
		return
	end
	data.Boosts[key] = (data.Boosts[key] or 0) + seconds
	player:SetAttribute("Boost" .. key, data.Boosts[key])
	StatsService.Invalidate(player)
end

return StatsService
