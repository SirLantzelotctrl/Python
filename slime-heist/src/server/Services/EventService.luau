-- Eventos del servidor: suerte de servidor (producto Robux), eventos automáticos
-- (Lucky Storm, Golden Hour, Slime Frenzy, Cash Party, Money Rain) y monedas que caen.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)

local Registry = require(script.Parent.Parent.Registry)
local Layout = require(script.Parent.Parent.Layout)
local Net = require(script.Parent.Parent.Net)

local EventService = {}

export type EventDef = { Title: string, Description: string, Color: Color3 }

EventService.Events = {
	LuckyStorm = { Title = "🍀 LUCKY STORM", Description = "2x luck for everyone!", Color = Color3.fromRGB(90, 255, 120) },
	GoldenHour = { Title = "⭐ GOLDEN HOUR", Description = "3x mutation chance!", Color = Color3.fromRGB(255, 210, 60) },
	SlimeFrenzy = { Title = "⚡ SLIME FRENZY", Description = "Slimes spawn way faster!", Color = Color3.fromRGB(90, 220, 255) },
	CashParty = { Title = "🎉 CASH PARTY", Description = "2x cash for everyone!", Color = Color3.fromRGB(255, 120, 220) },
	MoneyRain = { Title = "💸 MONEY RAIN", Description = "Grab the falling coins!", Color = Color3.fromRGB(120, 255, 160) },
} :: { [string]: EventDef }

local EVENT_ORDER = { "LuckyStorm", "GoldenHour", "SlimeFrenzy", "CashParty", "MoneyRain" }

local serverLuckUntil = 0
local adminLuck = 1
local adminLuckUntil = 0
local current: { Name: string, EndsAt: number }? = nil
local coinsFolder: Folder

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
	if isActive("LuckyStorm") then
		luck *= Config.Events.LuckMultiplier
	end
	if adminLuckUntil > now() then
		luck *= adminLuck
	end
	return luck
end

function EventService.GetMutationLuck(): number
	return if isActive("GoldenHour") then Config.Events.MutationMultiplier else 1
end

function EventService.GetSpawnRateMultiplier(): number
	return if isActive("SlimeFrenzy") then Config.Events.FrenzySpawnMultiplier else 1
end

function EventService.GetCashMultiplier(): number
	return if isActive("CashParty") then 2 else 1
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

-- ---------------------------------------------------------------------
-- Lluvia de dinero
-- ---------------------------------------------------------------------
local function spawnCoin()
	local rng = Random.new()
	local x = rng:NextNumber(Layout.RunwayStart.X + 10, Layout.RunwayEnd.X - 10)
	local z = rng:NextNumber(-17, 17)
	if math.abs(z) < Layout.RunwayWidth / 2 + 1 then
		z = (if z < 0 then -1 else 1) * (Layout.RunwayWidth / 2 + rng:NextNumber(2, 8))
	end
	local target = CFrame.new(x, 3, z)
	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.5, 3, 3)
	coin.Color = Color3.fromRGB(255, 205, 40)
	coin.Material = Enum.Material.Metal
	coin.Reflectance = 0.2
	coin.Anchored = true
	coin.CanCollide = false
	coin.CFrame = target + Vector3.new(0, 45, 0)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 80)
	light.Range = 8
	light.Brightness = 1.5
	light.Parent = coin
	CollectionService:AddTag(coin, "Coin")
	coin.Parent = coinsFolder
	TweenService:Create(coin, TweenInfo.new(1.6, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { CFrame = target }):Play()

	local taken = false
	coin.Touched:Connect(function(hit)
		if taken then
			return
		end
		local model = hit:FindFirstAncestorOfClass("Model")
		local player = model and Players:GetPlayerFromCharacter(model)
		if not player or not Registry.DataService.Get(player) then
			return
		end
		taken = true
		local amount = Economy.ScaleReward(250, Registry.SlimeService.GetIncomePerSecond(player), 20)
		Registry.DataService.AddCash(player, amount)
		Net.Effect(player, "Collect", { Amount = amount, Position = coin.Position })
		coin:Destroy()
	end)
end

local function moneyRain(duration: number)
	local count = Config.Events.MoneyRainCoins
	local interval = (duration * 0.8) / count
	for _ = 1, count do
		if not isActive("MoneyRain") then
			break
		end
		spawnCoin()
		task.wait(interval)
	end
end

-- ---------------------------------------------------------------------
-- Eventos
-- ---------------------------------------------------------------------
function EventService.StartEvent(name: string, duration: number?)
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
	if name == "CashParty" then
		Registry.SlimeService.InvalidateAll()
	elseif name == "MoneyRain" then
		task.spawn(moneyRain, length)
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
	if name == "CashParty" then
		Registry.SlimeService.InvalidateAll()
	end
	if name == "MoneyRain" then
		coinsFolder:ClearAllChildren()
	end
end

function EventService.GetEventNames(): { string }
	return EVENT_ORDER
end

function EventService.Start()
	coinsFolder = Instance.new("Folder")
	coinsFolder.Name = "Coins"
	coinsFolder.Parent = workspace:WaitForChild("Effects")
	publishLuck()

	task.spawn(function()
		task.wait(Config.Events.FirstDelay)
		local lastName = nil
		while true do
			local name
			repeat
				name = EVENT_ORDER[math.random(1, #EVENT_ORDER)]
			until name ~= lastName or #EVENT_ORDER == 1
			lastName = name
			if not current then
				EventService.StartEvent(name)
			end
			task.wait(Config.Events.Interval)
		end
	end)

	-- Mantiene el atributo de suerte actualizado cuando caducan los boosts
	task.spawn(function()
		while true do
			task.wait(5)
			publishLuck()
		end
	end)
end

return EventService
