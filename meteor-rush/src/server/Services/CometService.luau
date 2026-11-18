-- ☄️ Cometa jefe: cada 20 min (o al comprarlo) cae un cometa gigante en la plaza.
-- Su vida se ajusta al daño del servidor y todos los que participan ganan premio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local Registry = require(script.Parent.Parent.Registry)
local Layout = require(script.Parent.Parent.Layout)
local Net = require(script.Parent.Parent.Net)

local CometService = {}

local active = false
local queued = 0
local nextCometAt = 0
local rng = Random.new()

local function now(): number
	return workspace:GetServerTimeNow()
end

local function setNext(at: number)
	nextCometAt = at
	workspace:SetAttribute("CometAt", at)
end

function CometService.IsActive(): boolean
	return active
end

function CometService.Launch(caller: Player?): boolean
	if active then
		queued += 1
		return false
	end
	active = true
	workspace:SetAttribute("CometActive", true)
	local totalDps = 0
	for _, player in Players:GetPlayers() do
		totalDps += Registry.StatsService.EstimateDps(player)
	end
	local hp = math.max(Config.Comet.MinHP, math.floor(totalDps * Config.Comet.TargetSeconds))
	local meteor = Registry.MeteorService.Spawn(1, "Mythic", {
		Position = Layout.PlazaCenter,
		Comet = true,
		HP = hp,
		WarningTime = Config.Comet.WarningTime,
	})
	if not meteor then
		active = false
		workspace:SetAttribute("CometActive", false)
		return false
	end
	local text = if caller then ("☄️ %s CALLED THE GIANT COMET! Go to the plaza!"):format(caller.DisplayName) else "☄️ A GIANT COMET is crashing into the plaza! Everyone go!"
	Net.Announce(text, Color3.fromRGB(140, 230, 255), 6)
	Net.EffectAll("Sound", { Name = "Announce" })
	Net.EffectAll("CometIncoming", { ImpactAt = meteor.ImpactAt })

	-- Si nadie lo rompe a tiempo, se va
	task.delay(Config.Comet.WarningTime + Config.Comet.Lifetime, function()
		if not meteor.Dead then
			Registry.MeteorService.Expire(meteor)
			Net.Announce("☄️ The comet flew away... be faster next time!", Color3.fromRGB(180, 180, 200), 4)
			CometService.Finish()
		end
	end)
	return true
end

function CometService.Finish()
	active = false
	workspace:SetAttribute("CometActive", false)
	if queued > 0 then
		queued -= 1
		setNext(now() + 30)
	elseif nextCometAt < now() + 60 then
		setNext(now() + Config.Comet.Interval)
	end
end

-- Recompensas al romperlo
function CometService.OnBroken(meteor: any, list: { { Player: Player, Damage: number } }, total: number)
	local count = #list
	for rank, entry in list do
		local player = entry.Player
		local data = Registry.DataService.Get(player)
		if player.Parent == Players and data then
			local share = entry.Damage / math.max(total, 1)
			local relative = math.clamp(share * count, Config.Comet.MinRewardShare, 3)
			local loot = math.floor(Registry.StatsService.GetRewardBase(player) * Config.Comet.RewardMeteors * relative)
			Registry.DataService.AddStardust(player, loot)
			data.Stats.Comets += 1
			Registry.DataService.MarkDirty(player)
			Net.Effect(player, "Loot", { Amount = loot, Position = meteor.Position, MVP = rank == 1, Share = share })
			Net.Notify(player, ("☄️ Comet reward: +%s ⭐ (#%d)"):format(Format.Abbreviate(loot), rank), "Success")
			if rank == 1 then
				Registry.CritterService.GiveCritterOfRarity(player, "Legendary", data.Zone, rng:NextNumber() < 0.2, "comet")
			elseif rank <= 3 then
				Registry.CritterService.GiveCritterOfRarity(player, "Epic", data.Zone, false, "comet")
			end
		end
	end
	local mvp = list[1] and list[1].Player
	if mvp then
		Net.Announce(("☄️ COMET DESTROYED! MVP: %s"):format(mvp.DisplayName), Color3.fromRGB(140, 230, 255), 5)
	end
	Net.EffectAll("Confetti", {})
	CometService.Finish()
end

function CometService.Start()
	setNext(now() + Config.Comet.FirstDelay)
	task.spawn(function()
		local warned = false
		while true do
			task.wait(1)
			local remaining = nextCometAt - now()
			if not active and remaining <= 60 and remaining > 50 and not warned then
				warned = true
				Net.Announce("☄️ The GIANT COMET arrives in 1 minute! Get ready at the plaza!", Color3.fromRGB(140, 230, 255), 5)
			end
			if not active and remaining <= 0 and #Players:GetPlayers() > 0 then
				warned = false
				setNext(now() + Config.Comet.Interval)
				CometService.Launch(nil)
			end
		end
	end)
end

return CometService
