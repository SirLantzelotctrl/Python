-- Misiones diarias (3 por día) con premio extra al completar todas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Quests = require(Shared.Quests)
local Format = require(Shared.Format)

local Registry = require(script.Parent.Parent.Registry)
local Actions = require(script.Parent.Parent.Actions)
local Net = require(script.Parent.Parent.Net)

local QuestService = {}

local function today(): number
	return math.floor(os.time() / 86400)
end

function QuestService.EnsureToday(player: Player): any?
	local data = Registry.DataService.Get(player)
	if not data then
		return nil
	end
	local day = today()
	if data.Quests.Day ~= day or #data.Quests.List == 0 then
		data.Quests = { Day = day, List = Quests.Generate(day, player.UserId), BonusClaimed = false }
		Registry.DataService.MarkDirty(player)
	end
	return data.Quests
end

function QuestService.Progress(player: Player, kind: string, amount: number)
	local quests = QuestService.EnsureToday(player)
	if not quests then
		return
	end
	for _, quest in quests.List do
		if quest.Kind == kind and quest.Progress < quest.Target then
			quest.Progress = math.min(quest.Target, quest.Progress + amount)
			if quest.Progress >= quest.Target then
				Net.Notify(player, "✅ Quest complete: " .. Quests.Describe(quest.Kind, quest.Target) .. "! Claim it in Quests.", "Success")
				Net.Effect(player, "Sound", { Name = "Buy" })
			end
			Registry.DataService.MarkDirty(player)
		end
	end
end

function QuestService.FillView(player: Player, view: { [string]: any })
	local quests = QuestService.EnsureToday(player)
	if quests then
		view.Quests = quests
		view.QuestsResetAt = (today() + 1) * 86400
	end
end

function QuestService.Init()
	Actions.Register("ClaimQuest", function(player, payload)
		local quests = QuestService.EnsureToday(player)
		local index = tonumber(payload.Index)
		local quest = quests and index and quests.List[index]
		if not quest then
			return false, "Invalid quest"
		end
		if quest.Claimed then
			return false, "Already claimed"
		end
		if quest.Progress < quest.Target then
			return false, "Not finished yet"
		end
		quest.Claimed = true
		local reward = math.floor(Registry.StatsService.GetRewardBase(player) * quest.RewardMeteors)
		Registry.DataService.AddStardust(player, reward)
		Registry.DataService.MarkDirty(player)
		Net.Effect(player, "Sound", { Name = "Stardust" })
		return true, ("+%s ⭐"):format(Format.Abbreviate(reward))
	end)

	Actions.Register("ClaimQuestBonus", function(player)
		local quests = QuestService.EnsureToday(player)
		if not quests then
			return false, nil
		end
		if quests.BonusClaimed then
			return false, "Already claimed"
		end
		for _, quest in quests.List do
			if not quest.Claimed then
				return false, "Claim all 3 quests first"
			end
		end
		quests.BonusClaimed = true
		local description = Registry.RewardService.Grant(player, Quests.Bonus)
		return true, "🏆 " .. description
	end)
end

return QuestService
