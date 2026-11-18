-- Genera el mundo: 6 zonas en fila con su suelo y decoración, puertas, plaza central,
-- soportes de huevos, tienda, altar de Supernova, tablones e iluminación.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Zones = require(Shared.Zones)
local Critters = require(Shared.Critters)
local Models = require(Shared.Models)
local Format = require(Shared.Format)

local Layout = require(script.Parent.Parent.Layout)

local MapService = {}

MapService.Folder = nil :: Folder?
MapService.Boards = {} :: { [string]: SurfaceGui }
MapService.Gates = {} :: { [number]: Part }
MapService.EggStands = {} :: { [number]: Part }
MapService.Obstacles = {} :: { { Position: Vector3, Radius: number } }

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

local function textLabel(parent: Instance, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	for key, value in props do
		(label :: any)[key] = value
	end
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(15, 15, 25)
	stroke.Parent = label
	label.Parent = parent
	return label
end

local function addObstacle(position: Vector3, radius: number)
	table.insert(MapService.Obstacles, { Position = position, Radius = radius })
end

-- ---------------------------------------------------------------------
-- Decoración
-- ---------------------------------------------------------------------
local function tree(parent: Instance, position: Vector3, scale: number, leafColor: Color3, trunkColor: Color3, pine: boolean)
	part({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8 * scale, 2 * scale, 2 * scale), CFrame = CFrame.new(position + Vector3.new(0, 4 * scale, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = trunkColor, Material = Enum.Material.Wood, Parent = parent })
	if pine then
		for i = 0, 2 do
			part({ Name = "Leaves", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6 * scale, (7 - i * 2) * scale, (7 - i * 2) * scale), CFrame = CFrame.new(position + Vector3.new(0, (7 + i * 2.6) * scale, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = leafColor, Material = Enum.Material.Snow, CanCollide = false, Parent = parent })
		end
	else
		for i, offset in { Vector3.new(0, 9, 0), Vector3.new(2.2, 7.5, 1), Vector3.new(-2, 7.8, -1.2) } do
			part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.one * (6.5 - i * 0.7) * scale, CFrame = CFrame.new(position + offset * scale), Color = leafColor, Material = Enum.Material.Grass, CanCollide = false, Parent = parent })
		end
	end
	addObstacle(position, 4 * scale)
end

local function cactus(parent: Instance, position: Vector3, scale: number)
	local green = Color3.fromRGB(80, 160, 80)
	part({ Name = "Cactus", Size = Vector3.new(2, 9, 2) * scale, CFrame = CFrame.new(position + Vector3.new(0, 4.5 * scale, 0)), Color = green, Material = Enum.Material.Grass, Parent = parent })
	for _, side in { -1, 1 } do
		part({ Name = "CactusArm", Size = Vector3.new(1.4, 4, 1.4) * scale, CFrame = CFrame.new(position + Vector3.new(side * 1.9, 5.5 + side * 0.8, 0) * scale), Color = green, Material = Enum.Material.Grass, Parent = parent })
		part({ Name = "CactusJoint", Size = Vector3.new(1.6, 1.4, 1.4) * scale, CFrame = CFrame.new(position + Vector3.new(side * 1.2, 3.9 + side * 0.8, 0) * scale), Color = green, Material = Enum.Material.Grass, Parent = parent })
	end
	addObstacle(position, 3.5 * scale)
end

local function boulder(parent: Instance, position: Vector3, scale: number, color: Color3, material: Enum.Material)
	part({ Name = "Boulder", Shape = Enum.PartType.Ball, Size = Vector3.one * 6 * scale, CFrame = CFrame.new(position + Vector3.new(0, 1.5 * scale, 0)), Color = color, Material = material, Parent = parent })
	addObstacle(position, 3.5 * scale)
end

local function crystalCluster(parent: Instance, position: Vector3, scale: number, color: Color3)
	for i = 0, 4 do
		local angle = math.rad(i * 72)
		local tilt = CFrame.Angles(math.rad(15) * math.cos(angle), 0, math.rad(15) * math.sin(angle))
		part({ Name = "Crystal", Size = Vector3.new(1.6, 7 - i * 0.8, 1.6) * scale, CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * 1.4, 3, math.sin(angle) * 1.4) * scale) * tilt, Color = color, Material = Enum.Material.Neon, Transparency = 0.1, CanCollide = false, Parent = parent })
	end
	addObstacle(position, 3 * scale)
end

local function decorate(zone: Zones.Zone, parent: Instance)
	local rng = Random.new(zone.Index * 1337)
	local minX, maxX = Layout.ZoneXRange(zone.Index)
	local count = 22
	for _ = 1, count do
		local x = rng:NextNumber(minX + 8, maxX - 8)
		local zSide = if rng:NextNumber() < 0.5 then -1 else 1
		local z = zSide * rng:NextNumber(70, 94)
		local position = Vector3.new(x, 0, z)
		local scale = rng:NextNumber(0.9, 1.4)
		if zone.Decor == "Trees" then
			tree(parent, position, scale, Color3.fromRGB(80, 175, 75), Color3.fromRGB(120, 80, 50), false)
		elseif zone.Decor == "Cacti" then
			if rng:NextNumber() < 0.7 then
				cactus(parent, position, scale)
			else
				boulder(parent, position, scale, Color3.fromRGB(190, 140, 90), Enum.Material.Sandstone)
			end
		elseif zone.Decor == "Pines" then
			tree(parent, position, scale, Color3.fromRGB(235, 245, 255), Color3.fromRGB(90, 70, 55), true)
		elseif zone.Decor == "Lava" then
			if rng:NextNumber() < 0.5 then
				part({ Name = "LavaPool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 12 * scale, 12 * scale), CFrame = CFrame.new(position + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(255, 110, 30), Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
				addObstacle(position, 6 * scale)
			else
				boulder(parent, position, scale, Color3.fromRGB(40, 32, 32), Enum.Material.Basalt)
			end
		elseif zone.Decor == "Craters" then
			part({ Name = "CraterRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 14 * scale, 14 * scale), CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(150, 150, 160), Material = Enum.Material.Slate, Parent = parent })
			part({ Name = "CraterHole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.3, 10 * scale, 10 * scale), CFrame = CFrame.new(position + Vector3.new(0, 0.32, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(110, 110, 120), Material = Enum.Material.Slate, Parent = parent })
			addObstacle(position, 7 * scale)
		elseif zone.Decor == "Crystals" then
			crystalCluster(parent, position, scale, if rng:NextNumber() < 0.5 then Color3.fromRGB(230, 110, 255) else Color3.fromRGB(110, 200, 255))
		end
	end
end

-- ---------------------------------------------------------------------
-- Piezas del mundo
-- ---------------------------------------------------------------------
local function buildZoneGround(zone: Zones.Zone, parent: Instance)
	local center = Layout.ZoneCenter(zone.Index)
	part({ Name = "Ground" .. zone.Index, Size = Vector3.new(Layout.ZoneWidth, 4, Layout.ZoneDepth), CFrame = CFrame.new(center + Vector3.new(0, -2, 0)), Color = zone.GroundColor, Material = zone.GroundMaterial, Parent = parent })
	-- Borde exterior (muros) a lo largo de Z
	for _, side in { -1, 1 } do
		part({ Name = "Fence", Size = Vector3.new(Layout.ZoneWidth, 6, 2), CFrame = CFrame.new(center + Vector3.new(0, 3, side * (Layout.ZoneDepth / 2 + 1))), Color = zone.GroundColor:Lerp(Color3.new(0, 0, 0), 0.35), Material = zone.GroundMaterial, Parent = parent })
		part({ Name = "Boundary", Size = Vector3.new(Layout.ZoneWidth, 120, 2), CFrame = CFrame.new(center + Vector3.new(0, 60, side * (Layout.ZoneDepth / 2 + 2))), Transparency = 1, Parent = parent })
	end
	-- Cartel con el nombre de la zona
	local sign = part({ Name = "ZoneSign", Size = Vector3.new(1, 6, 26), CFrame = CFrame.new(center + Vector3.new(-Layout.ZoneWidth / 2 + 6, 14, 30)) * CFrame.Angles(0, 0, 0), Transparency = 1, CanCollide = false, Parent = parent })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.LightInfluence = 0
	gui.PixelsPerStud = 30
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = sign
	textLabel(gui, { Size = UDim2.fromScale(1, 1), Text = zone.Icon .. " " .. string.upper(zone.Name), TextColor3 = zone.AccentColor })
end

local function buildGate(zone: Zones.Zone, parent: Instance)
	local x = Layout.GatePosition(zone.Index).X
	local half = Layout.GateHalfWidth
	local wallColor = Color3.fromRGB(70, 75, 100)
	local segment = Layout.ZoneDepth / 2 - half
	for _, side in { -1, 1 } do
		part({ Name = "ZoneWall", Size = Vector3.new(3, 24, segment), CFrame = CFrame.new(x, 12, side * (half + segment / 2)), Color = wallColor, Material = Enum.Material.Metal, Parent = parent })
		part({ Name = "WallTop", Size = Vector3.new(3.4, 1, segment), CFrame = CFrame.new(x, 24.5, side * (half + segment / 2)), Color = zone.AccentColor, Material = Enum.Material.Neon, Parent = parent })
		part({ Name = "GatePillar", Size = Vector3.new(5, 30, 4), CFrame = CFrame.new(x, 15, side * (half + 2)), Color = Color3.fromRGB(45, 48, 70), Material = Enum.Material.Metal, Parent = parent })
		part({ Name = "Boundary", Size = Vector3.new(3, 120, segment), CFrame = CFrame.new(x, 60, side * (half + segment / 2)), Transparency = 1, Parent = parent })
	end
	local gate = part({
		Name = "Gate" .. zone.Index,
		Size = Vector3.new(1.5, 30, half * 2),
		CFrame = CFrame.new(x, 15, 0),
		Color = zone.AccentColor,
		Material = Enum.Material.ForceField,
		Parent = parent,
	})
	gate:SetAttribute("Zone", zone.Index)
	-- Cartel encima de la puerta (visible desde ambos lados)
	local sign = part({ Name = "GateSign", Size = Vector3.new(2, 7, 30), CFrame = CFrame.new(x, 34, 0), Color = Color3.fromRGB(30, 32, 50), Parent = parent })
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 25
		gui.Parent = sign
		textLabel(gui, { Size = UDim2.new(1, -20, 0.55, 0), Position = UDim2.new(0, 10, 0.05, 0), Text = zone.Icon .. " " .. string.upper(zone.Name), TextColor3 = zone.AccentColor })
		textLabel(gui, { Name = "Price", Size = UDim2.new(1, -20, 0.35, 0), Position = UDim2.new(0, 10, 0.6, 0), Text = "🔒 " .. Format.Abbreviate(zone.Cost) .. " ⭐", TextColor3 = Color3.fromRGB(255, 230, 110) })
	end
	MapService.Gates[zone.Index] = gate
end

local function buildEggStand(eggIndex: number, parent: Instance)
	local egg = Critters.GetEgg(eggIndex)
	if not egg then
		return
	end
	local position = Layout.EggPosition(eggIndex)
	local stand = part({ Name = "EggStand" .. eggIndex, Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 9, 9), CFrame = CFrame.new(position + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(50, 54, 80), Material = Enum.Material.Metal, Parent = parent })
	part({ Name = "StandGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 9.6, 9.6), CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = egg.SpotColor, Material = Enum.Material.Neon, Parent = parent })
	stand:SetAttribute("Egg", eggIndex)
	local model = Models.BuildEgg(eggIndex, 1.6)
	model:PivotTo(CFrame.new(position + Vector3.new(0, 2, 0)) * CFrame.Angles(0, math.rad(-90), 0))
	model.Parent = parent
	if model.PrimaryPart then
		model.PrimaryPart:AddTag("Spin")
	end
	addObstacle(position, 7)
	MapService.EggStands[eggIndex] = stand
end

local function buildStand(name: string, position: Vector3, title: string, color: Color3, parent: Instance): Part
	local base = part({ Name = name, Size = Vector3.new(12, 1, 8), CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)), Color = Color3.fromRGB(50, 54, 80), Parent = parent })
	part({ Name = name .. "Counter", Size = Vector3.new(12, 3.5, 2), CFrame = CFrame.new(position + Vector3.new(0, 2.75, -2)), Color = color, Parent = parent })
	for _, side in { -1, 1 } do
		part({ Name = "Post", Size = Vector3.new(0.8, 9, 0.8), CFrame = CFrame.new(position + Vector3.new(side * 5.6, 5.5, 3.4)), Color = Color3.fromRGB(240, 240, 250), Parent = parent })
	end
	local roof = part({ Name = name .. "Roof", Size = Vector3.new(13, 1, 9), CFrame = CFrame.new(position + Vector3.new(0, 10.5, 0)), Color = color, Parent = parent })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(14, 0, 3, 0)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Parent = roof
	textLabel(gui, { Size = UDim2.fromScale(1, 1), Text = title, TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.4) })
	addObstacle(position, 8)
	return base
end

local function buildBoard(parent: Instance, name: string, title: string, position: Vector3, lookAt: Vector3, color: Color3)
	local board = part({ Name = name, Size = Vector3.new(16, 22, 1), CFrame = CFrame.lookAt(position + Vector3.new(0, 12, 0), lookAt + Vector3.new(0, 12, 0)), Color = Color3.fromRGB(30, 32, 48), Parent = parent })
	part({ Name = "Frame", Size = Vector3.new(17, 23, 0.8), CFrame = board.CFrame * CFrame.new(0, 0, 0.3), Color = color, Material = Enum.Material.Neon, Parent = parent })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.PixelsPerStud = 30
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = board
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = gui
	textLabel(gui, { Name = "Header", Size = UDim2.new(1, -20, 0, 70), Text = title, TextColor3 = color, LayoutOrder = 0 })
	for rank = 1, 10 do
		local row = textLabel(gui, {
			Name = "Row" .. rank,
			BackgroundTransparency = 0.1,
			BackgroundColor3 = if rank % 2 == 0 then Color3.fromRGB(40, 44, 64) else Color3.fromRGB(48, 52, 74),
			Size = UDim2.new(1, -24, 0, 50),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if rank == 1 then Color3.fromRGB(255, 215, 60) elseif rank == 2 then Color3.fromRGB(220, 220, 230) elseif rank == 3 then Color3.fromRGB(230, 150, 90) else Color3.fromRGB(240, 240, 255),
			Text = ("  #%d  ---"):format(rank),
			LayoutOrder = rank,
		})
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = row
	end
	MapService.Boards[name] = gui
end

local function buildHub(parent: Instance)
	local plaza = Layout.PlazaCenter
	part({ Name = "Plaza", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, Layout.PlazaRadius * 2, Layout.PlazaRadius * 2), CFrame = CFrame.new(plaza + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(215, 210, 230), Material = Enum.Material.Concrete, Parent = parent })
	part({ Name = "PlazaRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, Layout.PlazaRadius * 2 + 3, Layout.PlazaRadius * 2 + 3), CFrame = CFrame.new(plaza + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(140, 230, 255), Material = Enum.Material.Neon, Parent = parent })
	part({ Name = "CometMark", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 10, 10), CFrame = CFrame.new(plaza + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(80, 90, 140), Material = Enum.Material.Neon, Parent = parent })

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(Layout.SpawnPosition + Vector3.new(0, 0.5, 0))
	spawn.Color = Color3.fromRGB(140, 230, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.3
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = parent

	-- Título
	local title = part({ Name = "Title", Size = Vector3.new(1, 10, 44), CFrame = CFrame.new(Layout.ZoneXRange(1) + 1, 22, 0), Transparency = 1, CanCollide = false, Parent = parent })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.LightInfluence = 0
	gui.PixelsPerStud = 30
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = title
	textLabel(gui, { Size = UDim2.fromScale(1, 1), Text = "☄️ " .. string.upper(Config.GameName), TextColor3 = Color3.fromRGB(255, 200, 90) })

	local boards = Instance.new("Folder")
	boards.Name = "Leaderboards"
	boards.Parent = parent
	local x = Layout.LeaderboardX
	buildBoard(boards, "TopStardust", "⭐ TOP STARDUST", Vector3.new(x, 0, -60), Vector3.new(0, 0, -60), Color3.fromRGB(255, 220, 90))
	buildBoard(boards, "TopMeteors", "☄️ TOP METEORS", Vector3.new(x, 0, -80), Vector3.new(0, 0, -80), Color3.fromRGB(120, 220, 255))
	buildBoard(boards, "TopSupernovas", "🌟 TOP SUPERNOVAS", Vector3.new(x, 0, 64), Vector3.new(0, 0, 64), Color3.fromRGB(255, 120, 200))

	MapService.ShopStand = buildStand("ShopStand", Layout.ShopPosition, "🛒 PICKAXES", Color3.fromRGB(70, 200, 110), parent)
	MapService.Altar = buildStand("SupernovaAltar", Layout.AltarPosition, "🌟 SUPERNOVA", Color3.fromRGB(255, 120, 200), parent)
end

local function setupLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(100, 100, 115)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 155)
	Lighting.GlobalShadows = true
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(200, 225, 255)
	atmosphere.Decay = Color3.fromRGB(110, 140, 200)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.7
	bloom.Size = 28
	bloom.Threshold = 1.5
	bloom.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.Name = "ZoneColor"
	color.Saturation = 0.15
	color.Contrast = 0.06
	color.Parent = Lighting
end

function MapService.Build()
	local map = Instance.new("Folder")
	map.Name = "Map"
	MapService.Folder = map

	for _, zone in Zones.List do
		local folder = Instance.new("Folder")
		folder.Name = zone.Id
		folder.Parent = map
		buildZoneGround(zone, folder)
		decorate(zone, folder)
		if zone.Index > 1 then
			buildGate(zone, folder)
		end
		buildEggStand(zone.Index, folder)
	end
	buildHub(map)

	-- Muros de los extremos
	local firstMin = Layout.ZoneXRange(1)
	local _, lastMax = Layout.ZoneXRange(Zones.Count())
	for _, x in { firstMin - 1, lastMax + 1 } do
		part({ Name = "EndWall", Size = Vector3.new(2, 8, Layout.ZoneDepth), CFrame = CFrame.new(x, 4, 0), Color = Color3.fromRGB(60, 64, 90), Parent = map })
		part({ Name = "Boundary", Size = Vector3.new(2, 120, Layout.ZoneDepth), CFrame = CFrame.new(x, 60, 0), Transparency = 1, Parent = map })
	end

	for _, name in { "Meteors", "Effects" } do
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = workspace
	end

	map.Parent = workspace
	setupLighting()
	return map
end

-- ¿Hay espacio libre para un meteorito de radio r en esta posición?
function MapService.IsClear(position: Vector3, radius: number): boolean
	for _, obstacle in MapService.Obstacles do
		local flat = Vector3.new(position.X - obstacle.Position.X, 0, position.Z - obstacle.Position.Z)
		if flat.Magnitude < obstacle.Radius + radius + 2 then
			return false
		end
	end
	return true
end

return MapService
