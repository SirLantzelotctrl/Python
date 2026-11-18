-- Recompensas de retención: diaria con racha, regalos por tiempo jugado, códigos y ganancias offline.

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

-- Entrega una recompensa (tabla con Cash / IncomeSeconds / Boost / SlimeRarity)
function RewardService.Grant(player: Player, reward: { [string]: any }): string
	local data = Registry.DataService.Get(player)
	if not data then
		return ""
	end
	local parts = {}
	if reward.Cash or reward.IncomeSeconds then
		local income = Registry.SlimeService.GetIncomePerSecond(player)
		local amount = Economy.ScaleReward(reward.Cash, income, reward.IncomeSeconds)
		if amount > 0 then
			Registry.DataService.AddCash(player, amount)
			table.insert(parts, Format.Money(amount))
			Net.Effect(player, "Sound", { Name = "Cash" })
		end
	end
	if reward.Boost then
		data.Boosts.CashX2 = (data.Boosts.CashX2 or 0) + reward.Boost
		player:SetAttribute("BoostCashX2", data.Boosts.CashX2)
		Registry.SlimeService.InvalidateMultiplier(player)
		table.insert(parts, "2x Cash for " .. Format.Duration(reward.Boost))
	end
	if reward.SlimeRarity then
		local given = Registry.SlimeService.GiveRandomOfRarity(player, reward.SlimeRarity, 1)
		table.insert(parts, (if given then "a " else "cash for a ") .. reward.SlimeRarity .. " slime")
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
	player:SetAttribute("BoostCashX2", data.Boosts.CashX2 or 0)

	-- Ganancias offline
	if data.LastOnline > 0 then
		local seconds = math.min(os.time() - data.LastOnline, Config.Offline.MaxSeconds)
		if seconds >= Config.Offline.MinSeconds then
			local amount = math.floor(Registry.SlimeService.GetIncomePerSecond(player) * seconds * Config.Offline.Rate)
			if amount > 0 then
				Registry.DataService.AddCash(player, amount)
				Net.Effect(player, "Offline", { Amount = amount, Seconds = seconds })
			end
		end
	end
	data.LastOnline = os.time()

	if data.Daily.LastDay < today() then
		task.delay(4, function()
			if player.Parent then
				Net.Effect(player, "DailyAvailable", {})
			end
		end)
	end
	Registry.DataService.MarkDirty(player)
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
	local nextStreak
	if lastDay == t then
		nextStreak = streak + 1
	elseif lastDay == t - 1 then
		nextStreak = streak + 1
	else
		nextStreak = 1
	end
	view.DailyAvailable = lastDay < t
	view.DailyStreak = if lastDay >= t - 1 then streak else 0
	view.DailyNextStreak = nextStreak
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
		local description = RewardService.Grant(player, reward)
		return true, ("📅 Day %d reward: %s"):format(streak, description)
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
		local elapsed = workspace:GetServerTimeNow() - session.Start
		if elapsed < gift.Minutes * 60 - 2 then
			return false, "Not ready yet"
		end
		session.Claimed[key] = true
		local description = RewardService.Grant(player, gift)
		return true, "🎁 " .. description
	end)

	Actions.Register("RedeemCode", function(player, payload)
		local data = Registry.DataService.Get(player)
		if not data then
			return false, "Data not loaded"
		end
		local raw = tostring(payload.Code or "")
		local code = string.upper((string.gsub(raw, "%s", "")))
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
		local description = RewardService.Grant(player, reward)
		return true, "✅ " .. description
	end)
end

return RewardService
