-- Meteoritos: aviso en el suelo -> impacto con onda expansiva -> roca con vida que
-- todos pueden picar -> al romperse, botín repartido según el daño de cada uno.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Rarities = require(Shared.Rarities)
local Zones = require(Shared.Zones)
local Models = require(Shared.Models)
local Remotes = require(Shared.Remotes)

local Registry = require(script.Parent.Parent.Registry)
local Layout = require(script.Parent.Parent.Layout)
local Net = require(script.Parent.Parent.Net)

local MeteorService = {}

export type Meteor = {
	Id: number,
	Zone: number,
	Rarity: string,
	HP: number,
	MaxHP: number,
	Position: Vector3,
	Radius: number,
	Damage: { [Player]: number },
	Landed: boolean,
	Dead: boolean,
	Comet: boolean,
	ImpactAt: number,
	LandedAt: number,
	ReservedFor: Player?,
	ReservedUntil: number,
	Model: Model?,
	Marker: BasePart?,
	HpFill: Frame?,
	HpText: TextLabel?,
	TopText: TextLabel?,
	BillboardDirty: boolean,
}

local meteors: { [number]: Meteor } = {}
local nextId = 0
local rng = Random.new()
local folder: Folder
local zoneTimers: { [number]: number } = {}
local reservedNotice: { [Player]: number } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(255, 255, 255)
	for key, value in props do
		(l :: any)[key] = value
	end
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(10, 10, 20)
	stroke.Parent = l
	l.Parent = parent
	return l
end

local function displayName(meteor: Meteor): string
	if meteor.Comet then
		return "☄️ GIANT COMET"
	end
	return string.upper(meteor.Rarity) .. " METEOR"
end

local function rarityColor(meteor: Meteor): Color3
	if meteor.Comet then
		return Color3.fromRGB(140, 230, 255)
	end
	return Rarities.Get(meteor.Rarity).Color
end

-- ---------------------------------------------------------------------
-- Consultas
-- ---------------------------------------------------------------------
function MeteorService.Get(id: number): Meteor?
	return meteors[id]
end

function MeteorService.GetAll(): { [number]: Meteor }
	return meteors
end

function MeteorService.CountActive(zoneIndex: number): number
	local count = 0
	for _, meteor in meteors do
		if meteor.Zone == zoneIndex and not meteor.Comet then
			count += 1
		end
	end
	return count
end

-- Meteorito aterrizado más cercano al alcance del jugador
function MeteorService.FindTarget(player: Player, reach: number?): Meteor?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local data = Registry.DataService.Get(player)
	local unlocked = if data then data.Zone else 1
	local best, bestDistance = nil, math.huge
	for _, meteor in meteors do
		if meteor.Landed and not meteor.Dead and (meteor.Comet or meteor.Zone <= unlocked) then
			local flat = Vector3.new(root.Position.X - meteor.Position.X, 0, root.Position.Z - meteor.Position.Z)
			local distance = flat.Magnitude - meteor.Radius
			if distance <= (reach or Config.Meteors.MiningReach) and distance < bestDistance then
				best, bestDistance = meteor, distance
			end
		end
	end
	return best
end

-- ---------------------------------------------------------------------
-- Aparición
-- ---------------------------------------------------------------------
local function findSpot(zoneIndex: number, radius: number, near: Vector3?): Vector3?
	local minX, maxX, maxZ = Layout.MeteorArea(zoneIndex)
	for _ = 1, 30 do
		local position
		if near then
			local angle = rng:NextNumber(0, math.pi * 2)
			local distance = rng:NextNumber(radius + 8, radius + 18)
			position = near + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
			position = Vector3.new(math.clamp(position.X, minX, maxX), 0, math.clamp(position.Z, -maxZ, maxZ))
		else
			position = Vector3.new(rng:NextNumber(minX, maxX), 0, rng:NextNumber(-maxZ, maxZ))
		end
		local ok = Registry.MapService.IsClear(position, radius)
		if ok then
			for _, other in meteors do
				local flat = Vector3.new(position.X - other.Position.X, 0, position.Z - other.Position.Z)
				if flat.Magnitude < radius + other.Radius + 8 then
					ok = false
					break
				end
			end
		end
		if ok then
			return position
		end
	end
	return nil
end

export type SpawnOptions = {
	Position: Vector3?,
	Near: Vector3?,
	ReservedFor: Player?,
	Comet: boolean?,
	HP: number?,
	WarningTime: number?,
}

function MeteorService.Spawn(zoneIndex: number, rarityName: string?, options: SpawnOptions?): Meteor?
	local opts: SpawnOptions = options or {}
	local rarity = rarityName or Economy.RollMeteorRarity(rng, Registry.EventService.GetLuck())
	local radius = if opts.Comet then 13 else Rarities.Get(rarity).Size
	local position = opts.Position or findSpot(zoneIndex, radius, opts.Near)
	if not position then
		return nil
	end
	nextId += 1
	local hp = opts.HP or Economy.GetMeteorHP(zoneIndex, rarity)
	local warning = opts.WarningTime or Config.Meteors.WarningTime
	local meteor: Meteor = {
		Id = nextId,
		Zone = zoneIndex,
		Rarity = rarity,
		HP = hp,
		MaxHP = hp,
		Position = position,
		Radius = radius,
		Damage = {},
		Landed = false,
		Dead = false,
		Comet = opts.Comet == true,
		ImpactAt = now() + warning,
		LandedAt = 0,
		ReservedFor = opts.ReservedFor,
		ReservedUntil = 0,
		Model = nil,
		Marker = nil,
		HpFill = nil,
		HpText = nil,
		TopText = nil,
		BillboardDirty = true,
	}
	meteors[meteor.Id] = meteor

	-- Círculo de aviso en el suelo (el cliente dibuja la bola de fuego que cae)
	local color = rarityColor(meteor)
	local marker = Instance.new("Part")
	marker.Name = "Incoming"
	marker.Shape = Enum.PartType.Cylinder
	marker.Size = Vector3.new(0.3, radius * 2.8, radius * 2.8)
	marker.CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	marker.Color = color
	marker.Material = Enum.Material.Neon
	marker.Transparency = 0.35
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker:SetAttribute("MeteorId", meteor.Id)
	marker:SetAttribute("Rarity", rarity)
	marker:SetAttribute("ImpactAt", meteor.ImpactAt)
	marker:SetAttribute("Comet", meteor.Comet)
	marker:SetAttribute("Radius", radius)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Warning"
	gui.Size = UDim2.new(12, 0, 3, 0)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	gui.AlwaysOnTop = true
	label(gui, { Name = "Title", Size = UDim2.fromScale(1, 0.55), Text = "⚠️ " .. displayName(meteor), TextColor3 = color })
	label(gui, { Name = "Countdown", Size = UDim2.fromScale(1, 0.45), Position = UDim2.fromScale(0, 0.55), Text = tostring(math.ceil(warning)), TextColor3 = Color3.fromRGB(255, 255, 255) })
	gui.Parent = marker
	CollectionService:AddTag(marker, "MeteorMarker")
	marker.Parent = folder
	meteor.Marker = marker

	local rarityDef = Rarities.Get(rarity)
	if not meteor.Comet and rarityDef.Announce then
		Net.Announce(("☄️ A %s meteor is falling in %s!"):format(string.upper(rarity), Zones.Get(zoneIndex).Name), rarityDef.Color, 4)
		Net.EffectAll("Sound", { Name = "Announce" })
	end

	task.delay(warning, function()
		MeteorService.Land(meteor)
	end)
	return meteor
end

function MeteorService.Land(meteor: Meteor)
	if meteor.Dead or meteor.Landed then
		return
	end
	if meteor.Marker then
		meteor.Marker:Destroy()
		meteor.Marker = nil
	end
	local model = Models.BuildMeteor(meteor.Rarity, meteor.Zone, { Comet = meteor.Comet })
	model:PivotTo(CFrame.new(meteor.Position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model:SetAttribute("MeteorId", meteor.Id)
	model:SetAttribute("Zone", meteor.Zone)
	model:SetAttribute("Comet", meteor.Comet)
	CollectionService:AddTag(model, "Meteor")

	-- Cartel con la vida
	local root = model.PrimaryPart :: BasePart
	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Size = UDim2.new(if meteor.Comet then 20 else 11, 0, if meteor.Comet then 5 else 3.4, 0)
	gui.StudsOffsetWorldSpace = Vector3.new(0, meteor.Radius * 1.9 + 3, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = if meteor.Comet then 500 else 160
	label(gui, { Name = "Title", Size = UDim2.fromScale(1, 0.32), Text = displayName(meteor), TextColor3 = rarityColor(meteor) })
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	bar.BorderSizePixel = 0
	bar.Size = UDim2.fromScale(1, 0.3)
	bar.Position = UDim2.fromScale(0, 0.34)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = bar
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = rarityColor(meteor)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.5, 0)
	fillCorner.Parent = fill
	fill.Parent = bar
	local hpText = label(bar, { Name = "HP", Size = UDim2.fromScale(1, 0.9), Position = UDim2.fromScale(0, 0.05), Text = "", ZIndex = 2 })
	bar.Parent = gui
	local topText = label(gui, { Name = "Top", Size = UDim2.fromScale(1, 0.3), Position = UDim2.fromScale(0, 0.68), Text = "", TextColor3 = Color3.fromRGB(255, 230, 140) })
	gui.Parent = root

	model.Parent = folder
	meteor.Model = model
	meteor.HpFill = fill
	meteor.HpText = hpText
	meteor.TopText = topText
	meteor.Landed = true
	meteor.LandedAt = now()
	meteor.BillboardDirty = true
	if meteor.ReservedFor then
		meteor.ReservedUntil = now() + Config.Meteors.ReservedSeconds
	end

	-- Onda expansiva: los jugadores cercanos salen volando
	local knockback = Remotes.Event("Knockback")
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			local offset = hrp.Position - meteor.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			if flat.Magnitude < Config.Meteors.ImpactRadius + meteor.Radius then
				local dir = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(1, 0, 0)
				knockback:FireClient(player, dir * Config.Meteors.ImpactKnockback + Vector3.new(0, Config.Meteors.ImpactKnockback * 0.7, 0))
			end
		end
	end
	Net.EffectAll("Impact", { Position = meteor.Position, Rarity = meteor.Rarity, Comet = meteor.Comet, Radius = meteor.Radius })
end

-- ---------------------------------------------------------------------
-- Daño y rotura
-- ---------------------------------------------------------------------
function MeteorService.Damage(player: Player, meteor: Meteor, amount: number): number
	if meteor.Dead or not meteor.Landed or amount <= 0 or amount ~= amount then
		return 0
	end
	if meteor.ReservedFor and meteor.ReservedFor ~= player and now() < meteor.ReservedUntil then
		if (reservedNotice[player] or 0) < os.clock() then
			reservedNotice[player] = os.clock() + 3
			Net.Notify(player, ("🔒 Reserved for %s for %ds"):format(meteor.ReservedFor.DisplayName, math.ceil(meteor.ReservedUntil - now())), "Error")
		end
		return 0
	end
	local dealt = math.min(amount, meteor.HP)
	meteor.HP -= dealt
	meteor.Damage[player] = (meteor.Damage[player] or 0) + dealt
	meteor.BillboardDirty = true
	if meteor.HP <= 0 then
		MeteorService.Break(meteor)
	end
	return dealt
end

local function contributors(meteor: Meteor): ({ { Player: Player, Damage: number } }, number)
	local list = {}
	local total = 0
	for player, damage in meteor.Damage do
		if damage > 0 then
			table.insert(list, { Player = player, Damage = damage })
			total += damage
		end
	end
	table.sort(list, function(a, b)
		return a.Damage > b.Damage
	end)
	return list, total
end

function MeteorService.Break(meteor: Meteor)
	if meteor.Dead then
		return
	end
	meteor.Dead = true
	meteors[meteor.Id] = nil
	local list, total = contributors(meteor)
	local count = #list
	local rarity = Rarities.Get(meteor.Rarity)
	local mvp = list[1] and list[1].Player

	if meteor.Comet then
		Registry.CometService.OnBroken(meteor, list, total)
	else
		local baseLoot = Economy.GetMeteorLoot(meteor.Zone, meteor.Rarity) * (1 + Config.Meteors.TeamworkBonus * math.max(0, count - 1))
		for _, entry in list do
			local player = entry.Player
			local data = Registry.DataService.Get(player)
			if player.Parent == Players and data then
				local share = entry.Damage / math.max(total, 1)
				local loot = baseLoot * share * Registry.StatsService.GetStardustMultiplier(player)
				local isMvp = player == mvp
				if isMvp then
					loot *= 1 + Config.Meteors.MvpBonus
				end
				loot = math.max(1, math.floor(loot))
				Registry.DataService.AddStardust(player, loot)
				data.Stats.Meteors += 1
				Registry.QuestService.Progress(player, "BreakMeteors", 1)
				if rarity.Order >= 3 then
					data.Stats.RareMeteors += 1
					Registry.QuestService.Progress(player, "BreakRare", 1)
				end
				if isMvp and count > 0 then
					data.Stats.MVPs += 1
					Registry.QuestService.Progress(player, "BeMVP", 1)
				end
				Registry.DataService.UpdateDisplay(player)
				Registry.DataService.MarkDirty(player)
				Net.Effect(player, "Loot", { Amount = loot, Position = meteor.Position, MVP = isMvp and count > 1, Share = share })
			end
		end
		-- Huevo de meteorito para el MVP
		if mvp and mvp.Parent == Players and rng:NextNumber() < rarity.EggChance then
			local critterRarity = if rarity.Name == "Cosmic" then "Mythic" else rarity.Name
			Registry.CritterService.GiveCritterOfRarity(mvp, critterRarity, meteor.Zone, rarity.Name == "Cosmic", "meteor")
		end
		if rarity.Announce and mvp then
			Net.Announce(("💥 %s broke a %s meteor!"):format(mvp.DisplayName, string.upper(rarity.Name)), rarity.Color, 3)
		end
	end

	Net.EffectAll("Break", { Position = meteor.Position, Rarity = meteor.Rarity, Comet = meteor.Comet, Radius = meteor.Radius })
	if meteor.Model then
		meteor.Model:Destroy()
		meteor.Model = nil
	end
end

function MeteorService.Expire(meteor: Meteor)
	if meteor.Dead then
		return
	end
	meteor.Dead = true
	meteors[meteor.Id] = nil
	if meteor.Model then
		meteor.Model:Destroy()
	end
	if meteor.Marker then
		meteor.Marker:Destroy()
	end
end

local function updateBillboard(meteor: Meteor)
	meteor.BillboardDirty = false
	if not meteor.HpFill or not meteor.HpText or not meteor.TopText then
		return
	end
	local fraction = math.clamp(meteor.HP / meteor.MaxHP, 0, 1)
	meteor.HpFill.Size = UDim2.fromScale(fraction, 1)
	meteor.HpText.Text = Format.Abbreviate(math.ceil(meteor.HP)) .. " / " .. Format.Abbreviate(meteor.MaxHP)
	local list, total = contributors(meteor)
	local parts = {}
	for i = 1, math.min(3, #list) do
		table.insert(parts, ("%s %d%%"):format(list[i].Player.DisplayName, math.floor(list[i].Damage / math.max(total, 1) * 100 + 0.5)))
	end
	local reserved = ""
	if meteor.ReservedFor and now() < meteor.ReservedUntil then
		reserved = ("🔒 %s %ds  "):format(meteor.ReservedFor.DisplayName, math.ceil(meteor.ReservedUntil - now()))
	elseif meteor.ReservedFor and meteor.Landed then
		meteor.ReservedFor = nil
	end
	meteor.TopText.Text = reserved .. table.concat(parts, "  •  ")
end

-- Meteorito invocado por un producto: cae junto al jugador
function MeteorService.SummonFor(player: Player): Meteor?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local data = Registry.DataService.Get(player)
	if not data then
		return nil
	end
	local roll = rng:NextNumber()
	local rarity = if roll < 0.05 then "Cosmic" elseif roll < 0.25 then "Mythic" else "Legendary"
	local zoneIndex = math.clamp(Registry.ZoneService.GetCurrentZone(player), 1, data.Zone)
	local near = if root and root:IsA("BasePart") then root.Position else nil
	local meteor = MeteorService.Spawn(zoneIndex, rarity, { Near = near, ReservedFor = player })
	if not meteor then
		meteor = MeteorService.Spawn(zoneIndex, rarity, { ReservedFor = player })
	end
	if meteor then
		Net.Announce(("🌠 %s summoned a %s meteor!"):format(player.DisplayName, string.upper(rarity)), Rarities.Get(rarity).Color, 4)
	end
	return meteor
end

function MeteorService.Start()
	folder = workspace:WaitForChild("Meteors") :: Folder

	-- Aparición por zona (solo donde hay jugadores)
	task.spawn(function()
		while true do
			task.wait(1)
			local playersPerZone: { [number]: number } = {}
			for _, player in Players:GetPlayers() do
				local zone = Registry.ZoneService.GetCurrentZone(player)
				if zone > 0 then
					playersPerZone[zone] = (playersPerZone[zone] or 0) + 1
				end
			end
			local interval = Config.Meteors.SpawnInterval / Registry.EventService.GetSpawnRateMultiplier()
			for zoneIndex = 1, Zones.Count() do
				local playerCount = playersPerZone[zoneIndex] or 0
				if playerCount > 0 then
					zoneTimers[zoneIndex] = (zoneTimers[zoneIndex] or 0) + 1
					local cap = math.min(Config.Meteors.MaxActivePerZone + (playerCount - 1) * Config.Meteors.ExtraPerPlayer, Config.Meteors.MaxActiveCap)
					if zoneTimers[zoneIndex] >= interval and MeteorService.CountActive(zoneIndex) < cap then
						zoneTimers[zoneIndex] = 0
						local ok, err = pcall(MeteorService.Spawn, zoneIndex)
						if not ok then
							warn("[MeteorService] " .. tostring(err))
						end
					end
				else
					zoneTimers[zoneIndex] = 0
				end
			end
			-- Caducidad
			local t = now()
			for _, meteor in meteors do
				if meteor.Landed and not meteor.Comet and t - meteor.LandedAt > Config.Meteors.Lifetime then
					MeteorService.Expire(meteor)
				end
			end
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.2 then
			return
		end
		elapsed = 0
		for _, meteor in meteors do
			if meteor.BillboardDirty or (meteor.ReservedFor and meteor.Landed) then
				updateBillboard(meteor)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		reservedNotice[player] = nil
	end)
end

return MeteorService
