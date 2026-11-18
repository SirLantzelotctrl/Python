-- Recompensas de retención: diaria con racha, regalos por tiempo jugado y códigos.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)

local Registry = require(script.Parent.Parent.Registry)
local Actions = require(script.Parent.Parent.Actions)
local Net = require(script.Parent.Parent.Net)

local RewardService = {}

type Session = { Start: number, Claimed: { [string]: boolean } }

local sessions: { [Player]: Session } = {}

local function today(): number
	return math.floor(os.time() / 86400)
end

-- Entrega una recompensa (Stardust / Meteors / Boost / DamageBoost / CritterRarity)
function RewardService.Grant(player: Player, reward: { [string]: any }): string
	local data = Registry.DataService.Get(player)
	if not data then
		return ""
	end
	local parts = {}
	if reward.Stardust or reward.Meteors then
		local amount = Economy.ScaleReward(reward.Stardust, Registry.StatsService.GetRewardBase(player), reward.Meteors)
		if amount > 0 then
			Registry.DataService.AddStardust(player, amount)
			table.insert(parts, Format.Abbreviate(amount) .. " ⭐")
			Net.Effect(player, "Sound", { Name = "Stardust" })
		end
	end
	if reward.Boost then
		Registry.StatsService.AddBoost(player, "Stardust", reward.Boost)
		table.insert(parts, "2x Stardust " .. Format.Duration(reward.Boost))
	end
	if reward.DamageBoost then
		Registry.StatsService.AddBoost(player, "Damage", reward.DamageBoost)
		table.insert(parts, "2x Damage " .. Format.Duration(reward.DamageBoost))
	end
	if reward.CritterRarity then
		local uid = Registry.CritterService.GiveCritterOfRarity(player, reward.CritterRarity, nil, false, "reward")
		table.insert(parts, (if uid then "a " else "stardust for a ") .. reward.CritterRarity .. " critter")
	end
	Net.Effect(player, "Confetti", {})
	Registry.DataService.MarkDirty(player)
	return table.concat(parts, " + ")
end

function RewardService.OnJoin(player: Player)
	sessions[player] = { Start = workspace:GetServerTimeNow(), Claimed = {} }
	local data = Registry.DataService.Get(player)
	if not data then
		return
	end
	player:SetAttribute("BoostStardust", data.Boosts.Stardust or 0)
	player:SetAttribute("BoostDamage", data.Boosts.Damage or 0)
	data.LastOnline = os.time()
	if data.Daily.LastDay < today() then
		task.delay(5, function()
			if player.Parent then
				Net.Effect(player, "DailyAvailable", {})
			end
		end)
	end
end

function RewardService.OnPlayerRemoving(player: Player)
	sessions[player] = nil
end

function RewardService.FillView(player: Player, view: { [string]: any })
	local data = Registry.DataService.Get(player)
	local session = sessions[player]
	view.SessionStart = if session then session.Start else workspace:GetServerTimeNow()
	view.GiftsClaimed = if session then session.Claimed else {}
	if not data then
		return
	end
	local t = today()
	local lastDay = data.Daily.LastDay
	local streak = data.Daily.Streak
	local nextStreak = if lastDay >= t - 1 then streak + 1 else 1
	view.DailyAvailable = lastDay < t
	view.DailyStreak = if lastDay >= t - 1 then streak else 0
	view.DailyNextIndex = ((nextStreak - 1) % #Config.DailyRewards) + 1
	view.DailyResetAt = (t + 1) * 86400
end

function RewardService.Init()
	Actions.Register("ClaimDaily", function(player)
		local data = Registry.DataService.Get(player)
		if not data then
			return false, "Data not loaded"
		end
		local t = today()
		if data.Daily.LastDay >= t then
			return false, "Come back tomorrow!"
		end
		local streak = if data.Daily.LastDay == t - 1 then data.Daily.Streak + 1 else 1
		data.Daily.LastDay = t
		data.Daily.Streak = streak
		local reward = Config.DailyRewards[((streak - 1) % #Config.DailyRewards) + 1]
		return true, ("📅 Day %d: %s"):format(streak, RewardService.Grant(player, reward))
	end)

	Actions.Register("ClaimGift", function(player, payload)
		local session = sessions[player]
		local index = tonumber(payload.Index)
		local gift = index and Config.PlaytimeGifts[index]
		if not session or not gift or not index then
			return false, "Invalid gift"
		end
		local key = tostring(index)
		if session.Claimed[key] then
			return false, "Already claimed"
		end
		if workspace:GetServerTimeNow() - session.Start < gift.Minutes * 60 - 2 then
			return false, "Not ready yet"
		end
		session.Claimed[key] = true
		return true, "🎁 " .. RewardService.Grant(player, gift)
	end)

	Actions.Register("RedeemCode", function(player, payload)
		local data = Registry.DataService.Get(player)
		if not data then
			return false, "Data not loaded"
		end
		local code = string.upper((string.gsub(tostring(payload.Code or ""), "%s", "")))
		if #code == 0 or #code > 30 then
			return false, "Enter a code"
		end
		local reward = Config.Codes[code]
		if not reward then
			return false, "Invalid code"
		end
		if data.Codes[code] then
			return false, "Code already redeemed"
		end
		data.Codes[code] = true
		return true, "✅ " .. RewardService.Grant(player, reward)
	end)
end

return RewardService
