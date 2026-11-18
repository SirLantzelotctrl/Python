-- Describe recompensas para mostrarlas en la UI antes de reclamarlas.

local Economy = require(script.Parent.Economy)
local Format = require(script.Parent.Format)
local Rarities = require(script.Parent.Rarities)

local RewardInfo = {}

-- Devuelve icono, texto corto y color. rewardBase = valor de un meteorito medio para el jugador.
function RewardInfo.Describe(reward: { [string]: any }, rewardBase: number): (string, string, Color3)
	if reward.CritterRarity then
		local rarity = Rarities.Get(reward.CritterRarity)
		local text = reward.CritterRarity .. " Critter"
		if reward.Boost or reward.DamageBoost then
			text ..= " + Boost"
		end
		return "🐾", text, rarity.Color
	end
	if reward.Stardust or reward.Meteors then
		return "⭐", Format.Abbreviate(Economy.ScaleReward(reward.Stardust, rewardBase, reward.Meteors)), Color3.fromRGB(255, 230, 110)
	end
	if reward.DamageBoost then
		return "⚔️", "2x Damage " .. Format.Duration(reward.DamageBoost), Color3.fromRGB(255, 130, 110)
	end
	if reward.Boost then
		return "⏫", "2x Stardust " .. Format.Duration(reward.Boost), Color3.fromRGB(120, 230, 255)
	end
	return "🎁", "Reward", Color3.fromRGB(255, 255, 255)
end

return RewardInfo
