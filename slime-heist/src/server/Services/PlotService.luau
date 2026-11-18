-- Bases de los jugadores: construcción, asignación, pedestales, candado y barrera.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Economy = require(Shared.Economy)

local Registry = require(script.Parent.Parent.Registry)
local Layout = require(script.Parent.Parent.Layout)
local Net = require(script.Parent.Parent.Net)

local PlotService = {}

export type Slot = {
	Index: number,
	CFrame: CFrame,
	Pedestal: Part,
	Glow: Part,
	Pad: Part,
	PadGui: BillboardGui,
	PadLabel: TextLabel,
	LockGui: SurfaceGui,
	Unlocked: boolean,
	LastText: string,
}

export type Plot = {
	Index: number,
	CFrame: CFrame,
	Model: Model,
	Floor: Part,
	Barrier: Part,
	LockPad: Part,
	LockLabel: TextLabel,
	SignName: TextLabel,
	SignIncome: TextLabel,
	SignAvatar: ImageLabel,
	SpawnCFrame: CFrame,
	Owner: Player?,
	LockedUntil: number,
	CooldownUntil: number,
	Slots: { Slot },
	LastLockText: string,
}

local W = Config.Plots.Width
local D = Config.Plots.Depth
local FLOOR_COLORS = {
	Color3.fromRGB(255, 205, 205),
	Color3.fromRGB(200, 228, 255),
	Color3.fromRGB(210, 255, 210),
	Color3.fromRGB(255, 240, 190),
	Color3.fromRGB(232, 212, 255),
	Color3.fromRGB(255, 222, 175),
	Color3.fromRGB(190, 255, 240),
	Color3.fromRGB(255, 208, 236),
}
local EMPTY_GLOW = Color3.fromRGB(120, 125, 140)
local PAD_COLOR = Color3.fromRGB(70, 255, 120)

local plots: { Plot } = {}
local playerPlots: { [Player]: Plot } = {}
local touchDebounce: { [string]: number } = {}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent
	return p
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
	stroke.Color = Color3.fromRGB(15, 15, 25)
	stroke.Parent = l
	l.Parent = parent
	return l
end

local function playerFromHit(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	return Players:GetPlayerFromCharacter(model)
end

local function debounce(key: string, seconds: number): boolean
	local now = os.clock()
	if (touchDebounce[key] or 0) > now then
		return false
	end
	touchDebounce[key] = now + seconds
	return true
end

-- ---------------------------------------------------------------------
-- Construcción
-- ---------------------------------------------------------------------
local function buildSlot(plot: Plot, index: number, offset: Vector3): Slot
	local cf = plot.CFrame
	local model = plot.Model
	local pedestal = part({
		Name = "Pedestal" .. index,
		Size = Vector3.new(7, 1.2, 6),
		CFrame = cf * CFrame.new(offset.X, Layout.FloorHeight + 0.6, offset.Z),
		Color = Color3.fromRGB(60, 64, 82),
		Parent = model,
	})
	local glow = part({
		Name = "Glow" .. index,
		Size = Vector3.new(7.4, 0.3, 6.4),
		CFrame = cf * CFrame.new(offset.X, Layout.FloorHeight + 0.15, offset.Z),
		Color = EMPTY_GLOW,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	local pad = part({
		Name = "CollectPad" .. index,
		Size = Vector3.new(5, 0.3, 2.4),
		CFrame = cf * CFrame.new(offset.X, Layout.FloorHeight + 0.15, offset.Z - 4.6),
		Color = PAD_COLOR,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		CanCollide = false,
		Parent = model,
	})
	pad:SetAttribute("Slot", index)

	local padGui = Instance.new("BillboardGui")
	padGui.Name = "Stored"
	padGui.Size = UDim2.new(5, 0, 1.3, 0)
	padGui.StudsOffset = Vector3.new(0, 1.3, 0)
	padGui.LightInfluence = 0
	padGui.MaxDistance = 55
	padGui.Parent = pad
	local padLabel = label(padGui, { Name = "Amount", Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = Color3.fromRGB(120, 255, 140) })

	local lockGui = Instance.new("SurfaceGui")
	lockGui.Name = "Locked"
	lockGui.Face = Enum.NormalId.Top
	lockGui.LightInfluence = 0
	lockGui.CanvasSize = Vector2.new(140, 120)
	lockGui.Parent = pedestal
	label(lockGui, { Name = "Text", Size = UDim2.fromScale(1, 1), Text = "🔒\nREBIRTH", TextColor3 = Color3.fromRGB(230, 230, 240) })

	return {
		Index = index,
		CFrame = cf * CFrame.new(offset.X, Layout.PedestalTop, offset.Z),
		Pedestal = pedestal,
		Glow = glow,
		Pad = pad,
		PadGui = padGui,
		PadLabel = padLabel,
		LockGui = lockGui,
		Unlocked = true,
		LastText = "",
	}
end

local function buildPlot(index: number, cf: CFrame, parent: Instance): Plot
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)

	local wallH = Config.Plots.WallHeight
	local floorY = Layout.FloorHeight
	local wallColor = Color3.fromRGB(245, 245, 252)

	part({ Name = "Base", Size = Vector3.new(W + 2, 0.8, D + 2), CFrame = cf * CFrame.new(0, 0.4, 0), Color = Color3.fromRGB(70, 74, 95), Parent = model })
	local floor = part({ Name = "Floor", Size = Vector3.new(W, 1, D), CFrame = cf * CFrame.new(0, 0.5, 0), Color = FLOOR_COLORS[((index - 1) % #FLOOR_COLORS) + 1], Parent = model })
	model.PrimaryPart = floor

	-- Muros bajos (decorativos: la protección real es la barrera del candado)
	part({ Name = "Wall", Size = Vector3.new(W, wallH, 1), CFrame = cf * CFrame.new(0, floorY + wallH / 2, D / 2 - 0.5), Color = wallColor, Parent = model })
	for _, side in { -1, 1 } do
		part({ Name = "Wall", Size = Vector3.new(1, wallH, D), CFrame = cf * CFrame.new(side * (W / 2 - 0.5), floorY + wallH / 2, 0), Color = wallColor, Parent = model })
		local segment = W / 2 - 8
		part({ Name = "Wall", Size = Vector3.new(segment, wallH, 1), CFrame = cf * CFrame.new(side * (8 + segment / 2), floorY + wallH / 2, -D / 2 + 0.5), Color = wallColor, Parent = model })
		-- Columnas del arco de entrada
		part({ Name = "Pillar", Size = Vector3.new(2, 17, 2), CFrame = cf * CFrame.new(side * 9, floorY + 8.5, -D / 2 + 0.5), Color = Color3.fromRGB(60, 64, 82), Parent = model })
		for corner = -1, 1, 2 do
			part({ Name = "CornerPost", Size = Vector3.new(1.6, wallH + 1, 1.6), CFrame = cf * CFrame.new(side * (W / 2 - 0.5), floorY + (wallH + 1) / 2, corner * (D / 2 - 0.5)), Color = Color3.fromRGB(60, 64, 82), Parent = model })
		end
	end

	-- Cartel de la base
	local sign = part({ Name = "Sign", Size = Vector3.new(24, 7, 1), CFrame = cf * CFrame.new(0, floorY + 20.5, -D / 2 + 0.5), Color = Color3.fromRGB(35, 38, 56), Parent = model })
	part({ Name = "SignFrame", Size = Vector3.new(25, 8, 0.6), CFrame = sign.CFrame * CFrame.new(0, 0, 0.4), Color = FLOOR_COLORS[((index - 1) % #FLOOR_COLORS) + 1], Material = Enum.Material.Neon, Parent = model })
	local signGui = Instance.new("SurfaceGui")
	signGui.Name = "SignGui"
	signGui.Face = Enum.NormalId.Front
	signGui.LightInfluence = 0
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 30
	signGui.Parent = sign
	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.BackgroundColor3 = Color3.fromRGB(60, 64, 90)
	avatar.Size = UDim2.new(0, 170, 0, 170)
	avatar.Position = UDim2.new(0, 20, 0.5, -85)
	avatar.Image = ""
	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = UDim.new(0.5, 0)
	avatarCorner.Parent = avatar
	avatar.Parent = signGui
	local signName = label(signGui, { Name = "OwnerName", Size = UDim2.new(1, -220, 0.55, 0), Position = UDim2.new(0, 205, 0.05, 0), Text = "EMPTY BASE", TextXAlignment = Enum.TextXAlignment.Left })
	local signIncome = label(signGui, { Name = "Income", Size = UDim2.new(1, -220, 0.35, 0), Position = UDim2.new(0, 205, 0.6, 0), Text = "", TextColor3 = Color3.fromRGB(110, 255, 130), TextXAlignment = Enum.TextXAlignment.Left })

	-- Botón del candado
	local lockPad = part({
		Name = "LockPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 5, 5),
		CFrame = cf * CFrame.new(-W / 2 + 6, floorY + 0.25, -D / 2 + 6) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(255, 70, 70),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	local lockGui = Instance.new("BillboardGui")
	lockGui.Name = "LockInfo"
	lockGui.Size = UDim2.new(7, 0, 1.6, 0)
	lockGui.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
	lockGui.LightInfluence = 0
	lockGui.MaxDistance = 80
	lockGui.Parent = lockPad
	local lockLabel = label(lockGui, { Name = "Status", Size = UDim2.fromScale(1, 1), Text = "🔓 STEP TO LOCK" })

	-- Barrera (visible solo con el candado activo)
	local barrier = part({
		Name = "Barrier",
		Size = Vector3.new(W + 1, 38, D + 1),
		CFrame = cf * CFrame.new(0, floorY + 19, 0),
		Color = Color3.fromRGB(255, 80, 80),
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		CastShadow = false,
		CollisionGroup = "Barrier" .. index,
		Parent = model,
	})

	local plot: Plot = {
		Index = index,
		CFrame = cf,
		Model = model,
		Floor = floor,
		Barrier = barrier,
		LockPad = lockPad,
		LockLabel = lockLabel,
		SignName = signName,
		SignIncome = signIncome,
		SignAvatar = avatar,
		SpawnCFrame = cf * CFrame.new(0, floorY + 3.5, -D / 2 + 9),
		Owner = nil,
		LockedUntil = 0,
		CooldownUntil = 0,
		Slots = {},
		LastLockText = "",
	}

	for slotIndex, offset in Layout.SlotOffsets do
		plot.Slots[slotIndex] = buildSlot(plot, slotIndex, offset)
	end

	-- Eventos de contacto
	lockPad.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if player and player == plot.Owner and debounce("lock" .. index, 1) then
			PlotService.TryLock(player, false)
		end
	end)
	for _, slot in plot.Slots do
		slot.Pad.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if player and player == plot.Owner and slot.Unlocked and debounce(("pad%d_%d"):format(index, slot.Index), 0.4) then
				Registry.SlimeService.CollectSlot(player, slot.Index)
			end
		end)
	end

	model.Parent = parent
	return plot
end

-- ---------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------
function PlotService.Init()
	for i = 1, Config.Plots.Count do
		for _, groupName in { "Barrier" .. i, "Owner" .. i } do
			pcall(function()
				PhysicsService:RegisterCollisionGroup(groupName)
			end)
		end
		PhysicsService:CollisionGroupSetCollidable("Barrier" .. i, "Owner" .. i, false)
	end
end

function PlotService.Build(parent: Instance)
	for index, cf in Layout.PlotCFrames do
		if index > Config.Plots.Count then
			break
		end
		plots[index] = buildPlot(index, cf, parent)
		PlotService.ResetVisuals(plots[index])
	end
end

function PlotService.Start()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.2 then
			return
		end
		elapsed = 0
		local now = workspace:GetServerTimeNow()
		for _, plot in plots do
			if plot.Owner then
				if plot.LockedUntil > 0 and now >= plot.LockedUntil then
					PlotService.Unlock(plot)
				elseif plot.LockedUntil > now then
					PlotService.ExpelIntruders(plot)
				end
				PlotService.UpdateLockLabel(plot, now)
			end
		end
	end)
end

-- ---------------------------------------------------------------------
-- Asignación
-- ---------------------------------------------------------------------
function PlotService.Assign(player: Player): Plot?
	for _, plot in plots do
		if not plot.Owner then
			plot.Owner = player
			playerPlots[player] = plot
			player:SetAttribute("PlotIndex", plot.Index)
			plot.Model:SetAttribute("OwnerUserId", player.UserId)
			plot.SignName.Text = string.upper(player.DisplayName) .. "'S BASE"
			plot.SignIncome.Text = "$0/s"
			task.spawn(function()
				local ok, image = pcall(function()
					return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
				end)
				if ok and plot.Owner == player then
					plot.SignAvatar.Image = image
				end
			end)
			if player.Character then
				PlotService.ApplyOwnerCollision(player, player.Character)
			end
			return plot
		end
	end
	return nil
end

function PlotService.Release(player: Player)
	local plot = playerPlots[player]
	if not plot then
		return
	end
	playerPlots[player] = nil
	plot.Owner = nil
	plot.Model:SetAttribute("OwnerUserId", 0)
	PlotService.Unlock(plot)
	plot.LockedUntil = 0
	plot.CooldownUntil = 0
	PlotService.ResetVisuals(plot)
end

function PlotService.ResetVisuals(plot: Plot)
	plot.SignName.Text = "EMPTY BASE"
	plot.SignIncome.Text = ""
	plot.SignAvatar.Image = ""
	plot.LockLabel.Text = ""
	plot.LastLockText = ""
	for _, slot in plot.Slots do
		slot.Glow.Color = EMPTY_GLOW
		slot.PadLabel.Text = ""
		slot.LastText = ""
		PlotService.SetSlotUnlockedVisual(slot, true)
	end
end

function PlotService.ApplyOwnerCollision(player: Player, character: Model)
	local plot = playerPlots[player]
	if not plot then
		return
	end
	local groupName = "Owner" .. plot.Index
	local function apply(descendant: Instance)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = groupName
		end
	end
	for _, descendant in character:GetDescendants() do
		apply(descendant)
	end
	character.DescendantAdded:Connect(apply)
end

-- ---------------------------------------------------------------------
-- Consultas
-- ---------------------------------------------------------------------
function PlotService.GetPlot(player: Player): Plot?
	return playerPlots[player]
end

function PlotService.GetPlots(): { Plot }
	return plots
end

function PlotService.Contains(plot: Plot, position: Vector3, margin: number?): boolean
	local localPos = plot.CFrame:PointToObjectSpace(position)
	local m = margin or 0.5
	return math.abs(localPos.X) <= W / 2 + m and math.abs(localPos.Z) <= D / 2 + m and localPos.Y > -6 and localPos.Y < 45
end

function PlotService.GetSlot(player: Player, slotIndex: number): Slot?
	local plot = playerPlots[player]
	return plot and plot.Slots[slotIndex]
end

function PlotService.GetSlotCFrame(player: Player, slotIndex: number): CFrame?
	local slot = PlotService.GetSlot(player, slotIndex)
	return slot and slot.CFrame
end

-- Puntos de camino para que un slime entre andando a la base
function PlotService.GetEntrancePath(player: Player, slotIndex: number): { CFrame }
	local plot = playerPlots[player]
	local slot = plot and plot.Slots[slotIndex]
	if not plot or not slot then
		return {}
	end
	local outside = plot.CFrame * CFrame.new(0, Layout.FloorHeight, -D / 2 - 6)
	local inside = plot.CFrame * CFrame.new(0, Layout.FloorHeight, -D / 2 + 4)
	local slotLocal = plot.CFrame:PointToObjectSpace(slot.CFrame.Position)
	local beside = plot.CFrame * CFrame.new(slotLocal.X, Layout.FloorHeight, slotLocal.Z - 6.5)
	return { outside, inside, beside, slot.CFrame }
end

-- ---------------------------------------------------------------------
-- Visuales de los slots
-- ---------------------------------------------------------------------
function PlotService.SetSlotUnlockedVisual(slot: Slot, unlocked: boolean)
	slot.Unlocked = unlocked
	slot.Pedestal.Transparency = if unlocked then 0 else 0.55
	slot.Glow.Transparency = if unlocked then 0 else 0.8
	slot.Pad.Transparency = if unlocked then 0.2 else 1
	slot.PadGui.Enabled = unlocked
	slot.LockGui.Enabled = not unlocked
end

function PlotService.UpdateSlotCount(player: Player, count: number)
	local plot = playerPlots[player]
	if not plot then
		return
	end
	for _, slot in plot.Slots do
		local unlocked = slot.Index <= count
		if slot.Unlocked ~= unlocked then
			PlotService.SetSlotUnlockedVisual(slot, unlocked)
		end
	end
end

function PlotService.SetSlotGlow(player: Player, slotIndex: number, color: Color3?)
	local slot = PlotService.GetSlot(player, slotIndex)
	if slot then
		slot.Glow.Color = color or EMPTY_GLOW
	end
end

function PlotService.SetStoredText(player: Player, slotIndex: number, amount: number?)
	local slot = PlotService.GetSlot(player, slotIndex)
	if not slot then
		return
	end
	local text = if amount and amount >= 1 then Format.Money(amount) else ""
	if text ~= slot.LastText then
		slot.LastText = text
		slot.PadLabel.Text = text
	end
end

function PlotService.SetSignIncome(player: Player, income: number)
	local plot = playerPlots[player]
	if plot then
		local text = Format.PerSecond(income)
		if plot.SignIncome.Text ~= text then
			plot.SignIncome.Text = text
		end
	end
end

-- ---------------------------------------------------------------------
-- Candado
-- ---------------------------------------------------------------------
function PlotService.IsLocked(plot: Plot): boolean
	return plot.LockedUntil > workspace:GetServerTimeNow()
end

function PlotService.IsPlayerLocked(player: Player): boolean
	local plot = playerPlots[player]
	return plot ~= nil and PlotService.IsLocked(plot)
end

function PlotService.TryLock(player: Player, force: boolean): (boolean, string?)
	local plot = playerPlots[player]
	if not plot then
		return false, "You don't have a base"
	end
	local now = workspace:GetServerTimeNow()
	if plot.LockedUntil > now then
		if force then
			-- Producto "Instant Lock" con el candado ya puesto: se extiende
			local data = Registry.DataService.Get(player)
			local passes = Registry.MonetizationService.GetOwnedPasses(player)
			local duration = Economy.GetLockDuration(data and data.Rebirths or 0, data and data.Upgrades.Lock or 0, passes.LongerLock == true)
			plot.LockedUntil += duration
			plot.CooldownUntil = plot.LockedUntil + Config.Lock.Cooldown
			player:SetAttribute("LockEndsAt", plot.LockedUntil)
			player:SetAttribute("LockCooldownEndsAt", plot.CooldownUntil)
			return true
		end
		return false, "Your base is already locked"
	end
	if not force and plot.CooldownUntil > now then
		Net.Notify(player, ("Lock is recharging... %ds"):format(math.ceil(plot.CooldownUntil - now)), "Error")
		return false, "Lock is recharging"
	end

	local data = Registry.DataService.Get(player)
	local passes = Registry.MonetizationService.GetOwnedPasses(player)
	local duration = Economy.GetLockDuration(data and data.Rebirths or 0, data and data.Upgrades.Lock or 0, passes.LongerLock == true)
	plot.LockedUntil = now + duration
	plot.CooldownUntil = plot.LockedUntil + Config.Lock.Cooldown
	player:SetAttribute("LockEndsAt", plot.LockedUntil)
	player:SetAttribute("LockCooldownEndsAt", plot.CooldownUntil)

	plot.Barrier.Transparency = 0
	plot.Barrier.CanCollide = true
	plot.LockPad.Color = Color3.fromRGB(80, 255, 120)
	PlotService.ExpelIntruders(plot)
	Net.Notify(player, ("🔒 Base locked for %ds!"):format(duration), "Success")
	Net.Effect(player, "Sound", { Name = "Lock" })
	return true
end

function PlotService.Unlock(plot: Plot)
	plot.LockedUntil = 0
	plot.Barrier.Transparency = 1
	plot.Barrier.CanCollide = false
	plot.LockPad.Color = Color3.fromRGB(255, 70, 70)
	if plot.Owner then
		plot.Owner:SetAttribute("LockEndsAt", 0)
	end
end

function PlotService.ExpelIntruders(plot: Plot)
	for _, other in Players:GetPlayers() do
		if other ~= plot.Owner then
			local character = other.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if character and root and root:IsA("BasePart") and PlotService.Contains(plot, root.Position, 1) then
				if plot.Owner and Registry.StealService.GetVictim(other) == plot.Owner then
					Registry.StealService.Cancel(other, "locked")
				end
				local outside = plot.CFrame * CFrame.new(math.random(-6, 6), Layout.FloorHeight + 3.5, -D / 2 - 9)
				character:PivotTo(CFrame.lookAt(outside.Position, outside.Position + plot.CFrame.LookVector))
				Net.Notify(other, "🔒 That base is locked!", "Error")
			end
		end
	end
end

function PlotService.UpdateLockLabel(plot: Plot, now: number)
	local text
	if plot.LockedUntil > now then
		text = ("🔒 LOCKED %ds"):format(math.ceil(plot.LockedUntil - now))
	elseif plot.CooldownUntil > now then
		text = ("⏳ RECHARGING %ds"):format(math.ceil(plot.CooldownUntil - now))
	else
		text = "🔓 STEP TO LOCK"
	end
	if text ~= plot.LastLockText then
		plot.LastLockText = text
		plot.LockLabel.Text = text
		plot.LockLabel.TextColor3 = if plot.LockedUntil > now then Color3.fromRGB(120, 255, 140) elseif plot.CooldownUntil > now then Color3.fromRGB(255, 210, 90) else Color3.fromRGB(255, 255, 255)
	end
end

return PlotService
