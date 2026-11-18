-- Eventos del servidor: Lluvia de meteoritos, Luna de sangre, Hora dorada,
-- suerte de servidor (producto) y suerte de admin.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local Registry = require(script.Parent.Parent.Registry)
local Net = require(script.Parent.Parent.Net)

local EventService = {}

export type EventDef = { Title: string, Description: string, Color: Color3 }

EventService.Events = {
	MeteorShower = { Title = "🌠 METEOR SHOWER", Description = "Meteors fall 3x faster!", Color = Color3.fromRGB(255, 180, 90) },
	BloodMoon = { Title = "🌕 BLOOD MOON", Description = "3x luck: rare meteors everywhere!", Color = Color3.fromRGB(255, 70, 70) },
	GoldenHour = { Title = "✨ GOLDEN HOUR", Description = "2x stardust for everyone!", Color = Color3.fromRGB(255, 215, 70) },
} :: { [string]: EventDef }

local EVENT_ORDER = { "MeteorShower", "BloodMoon", "GoldenHour" }

local serverLuckUntil = 0
local adminLuck = 1
local adminLuckUntil = 0
local current: { Name: string, EndsAt: number }? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

local function isActive(name: string): boolean
	return current ~= nil and current.Name == name and current.EndsAt > now()
end

function EventService.GetLuck(): number
	local luck = 1
	if serverLuckUntil > now() then
		luck *= Config.ServerLuck.Multiplier
	end
	if isActive("BloodMoon") then
		luck *= Config.Events.BloodMoonLuck
	end
	if adminLuckUntil > now() then
		luck *= adminLuck
	end
	return luck
end

function EventService.GetSpawnRateMultiplier(): number
	return if isActive("MeteorShower") then Config.Events.ShowerMultiplier else 1
end

function EventService.GetStardustMultiplier(): number
	return if isActive("GoldenHour") then Config.Events.GoldenMultiplier else 1
end

local function publishLuck()
	workspace:SetAttribute("Luck", EventService.GetLuck())
end

function EventService.AddServerLuck(seconds: number, buyer: Player?)
	local t = now()
	serverLuckUntil = math.min(math.max(serverLuckUntil, t) + seconds, t + Config.ServerLuck.MaxStackSeconds)
	workspace:SetAttribute("ServerLuckEndsAt", serverLuckUntil)
	publishLuck()
	if buyer then
		Net.Announce(("🍀 %s activated SERVER LUCK x%d for everyone!"):format(buyer.DisplayName, Config.ServerLuck.Multiplier), Color3.fromRGB(90, 255, 120), 5)
		Net.EffectAll("Confetti", {})
	end
end

function EventService.SetAdminLuck(multiplier: number, seconds: number)
	adminLuck = math.max(1, multiplier)
	adminLuckUntil = now() + seconds
	workspace:SetAttribute("AdminLuck", adminLuck)
	workspace:SetAttribute("AdminLuckEndsAt", adminLuckUntil)
	publishLuck()
	Net.Announce(("👑 ADMIN LUCK x%s for %s!"):format(tostring(adminLuck), Format.Duration(seconds)), Color3.fromRGB(255, 120, 220), 5)
end

function EventService.StartEvent(name: string, duration: number?): boolean
	local def = EventService.Events[name]
	if not def then
		return false
	end
	if current then
		EventService.EndEvent()
	end
	local length = duration or Config.Events.Duration
	local endsAt = now() + length
	current = { Name = name, EndsAt = endsAt }
	workspace:SetAttribute("EventName", name)
	workspace:SetAttribute("EventTitle", def.Title)
	workspace:SetAttribute("EventEndsAt", endsAt)
	publishLuck()
	Net.Announce(def.Title .. " — " .. def.Description, def.Color, 6)
	Net.EffectAll("Sound", { Name = "Announce" })
	if name == "GoldenHour" then
		Registry.StatsService.InvalidateAll()
	end
	task.delay(length, function()
		if current and current.Name == name and current.EndsAt == endsAt then
			EventService.EndEvent()
		end
	end)
	return true
end

function EventService.EndEvent()
	if not current then
		return
	end
	local name = current.Name
	current = nil
	workspace:SetAttribute("EventName", nil)
	workspace:SetAttribute("EventTitle", nil)
	workspace:SetAttribute("EventEndsAt", nil)
	publishLuck()
	if name == "GoldenHour" then
		Registry.StatsService.InvalidateAll()
	end
end

function EventService.GetEventNames(): { string }
	return EVENT_ORDER
end

function EventService.Start()
	publishLuck()
	task.spawn(function()
		task.wait(Config.Events.FirstDelay)
		local lastName = nil
		while true do
			local name
			repeat
				name = EVENT_ORDER[math.random(1, #EVENT_ORDER)]
			until name ~= lastName
			lastName = name
			if not current then
				EventService.StartEvent(name)
			end
			task.wait(Config.Events.Interval)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(5)
			publishLuck()
		end
	end)
end

return EventService
