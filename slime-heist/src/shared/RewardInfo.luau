-- Describe recompensas (para mostrarlas en la UI antes de reclamarlas).

local Economy = require(script.Parent.Economy)
local Format = require(script.Parent.Format)
local Rarities = require(script.Parent.Rarities)

local RewardInfo = {}

-- Devuelve icono, texto corto y color
function RewardInfo.Describe(reward: { [string]: any }, incomePerSecond: number): (string, string, Color3)
	if reward.SlimeRarity then
		local rarity = Rarities.Get(reward.SlimeRarity)
		local color = if rarity.Name == "Secret" then Color3.fromRGB(255, 255, 255) else rarity.Color
		local text = reward.SlimeRarity .. " Slime"
		if reward.Boost then
			text ..= " + 2x"
		end
		return "🧪", text, color
	end
	if reward.Cash or reward.IncomeSeconds then
		local amount = Economy.ScaleReward(reward.Cash, incomePerSecond, reward.IncomeSeconds)
		return "💵", Format.Money(amount), Color3.fromRGB(120, 255, 140)
	end
	if reward.Boost then
		return "⏫", "2x Cash " .. Format.Duration(reward.Boost), Color3.fromRGB(255, 210, 70)
	end
	return "🎁", "Reward", Color3.fromRGB(255, 255, 255)
end

return RewardInfo
