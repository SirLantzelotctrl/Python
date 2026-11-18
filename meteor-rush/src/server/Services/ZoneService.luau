-- Zonas: desbloquear con Stardust, teletransporte, y control anti-trampas
-- (si alguien entra en una zona que no tiene, vuelve a la suya).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Zones = require(Shared.Zones)
local Format = require(Shared.Format)

local Registry = require(script.Parent.Parent.Registry)
local Actions = require(script.Parent.Parent.Actions)
local Layout = require(script.Parent.Parent.Layout)
local Net = require(script.Parent.Parent.Net)

local ZoneService = {}

local teleportCooldown: { [Player]: number } = {}

function ZoneService.GetUnlocked(player: Player): number
	local data = Registry.DataService.Get(player)
	return if data then data.Zone else 1
end

function ZoneService.GetCurrentZone(player: Player): number
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return 0
	end
	return Layout.ZoneAt(root.Position)
end

function ZoneService.Teleport(player: Player, zoneIndex: number): boolean
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return false
	end
	character:PivotTo(Layout.ZoneSpawn(zoneIndex) + Vector3.new(math.random(-4, 4), 0, math.random(-6, 6)))
	return true
end

function ZoneService.Unlock(player: Player, zoneIndex: number): (boolean, string?)
	local data = Registry.DataService.Get(player)
	local zone = Zones.List[zoneIndex]
	if not data or not zone then
		return false, "Invalid zone"
	end
	if data.Zone >= zoneIndex then
		return false, "Already unlocked"
	end
	if zoneIndex ~= data.Zone + 1 then
		return false, "Unlock " .. Zones.Get(data.Zone + 1).Name .. " first"
	end
	if not Registry.DataService.SpendStardust(player, zone.Cost) then
		return false, ("You need %s ⭐"):format(Format.Abbreviate(zone.Cost))
	end
	data.Zone = zoneIndex
	Registry.StatsService.Invalidate(player)
	Registry.DataService.MarkDirty(player)
	Net.Effect(player, "Sound", { Name = "Buy" })
	Net.Effect(player, "Confetti", {})
	Net.Announce(("%s %s unlocked %s!"):format(zone.Icon, player.DisplayName, zone.Name), zone.AccentColor, 3)
	return true, zone.Icon .. " " .. zone.Name .. " unlocked!"
end

function ZoneService.Init()
	Actions.Register("UnlockZone", function(player, payload)
		return ZoneService.Unlock(player, tonumber(payload.Zone) or 0)
	end)
	Actions.Register("TeleportZone", function(player, payload)
		local index = tonumber(payload.Zone) or 0
		if index < 1 or index > ZoneService.GetUnlocked(player) then
			return false, "Zone locked"
		end
		local now = os.clock()
		if (teleportCooldown[player] or 0) > now then
			return false, "Wait a moment..."
		end
		teleportCooldown[player] = now + 2
		return ZoneService.Teleport(player, index), nil
	end)
end

function ZoneService.Start()
	-- Prompts de las puertas
	for zoneIndex, gate in Registry.MapService.Gates do
		local zone = Zones.Get(zoneIndex)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "UnlockPrompt"
		prompt.ActionText = "Unlock " .. Format.Abbreviate(zone.Cost) .. " ⭐"
		prompt.ObjectText = zone.Name
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("Zone", zoneIndex)
		prompt.Parent = gate
		prompt.Triggered:Connect(function(player)
			local ok, message = ZoneService.Unlock(player, zoneIndex)
			if message then
				Net.Notify(player, message, if ok then "Success" else "Error")
			end
		end)
	end

	-- Actualiza la zona actual de cada jugador y expulsa de zonas no desbloqueadas
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				local current = ZoneService.GetCurrentZone(player)
				if current > 0 then
					if player:GetAttribute("Zone") ~= current then
						player:SetAttribute("Zone", current)
					end
					local unlocked = ZoneService.GetUnlocked(player)
					if current > unlocked and Registry.DataService.Get(player) then
						ZoneService.Teleport(player, unlocked)
						Net.Notify(player, "🔒 Unlock " .. Zones.Get(current).Name .. " first!", "Error")
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		teleportCooldown[player] = nil
	end)
end

return ZoneService
