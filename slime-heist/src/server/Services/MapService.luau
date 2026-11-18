-- Genera el mundo por código: suelo, pasarela, portal, decoración, tablones e iluminación.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Parent.Layout)

local MapService = {}

MapService.Folder = nil :: Folder?
MapService.Boards = {} :: { [string]: SurfaceGui }

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

local function setupLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(95, 95, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 155)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(200, 220, 255)
	atmosphere.Decay = Color3.fromRGB(120, 150, 200)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 26
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.18
	color.Contrast = 0.06
	color.Brightness = 0.02
	color.Parent = Lighting

	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Intensity = 0.06
	sunRays.Spread = 0.6
	sunRays.Parent = Lighting
end

local function buildTree(parent: Instance, position: Vector3, scale: number)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local trunk = part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(8 * scale, 2.2 * scale, 2.2 * scale),
		CFrame = CFrame.new(position + Vector3.new(0, 4 * scale, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(120, 80, 50),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	local leafColors = { Color3.fromRGB(70, 170, 70), Color3.fromRGB(90, 190, 80), Color3.fromRGB(60, 150, 65) }
	for i, offset in { Vector3.new(0, 9, 0), Vector3.new(2.2, 7.5, 1), Vector3.new(-2, 7.8, -1.2), Vector3.new(0.5, 11, -0.5) } do
		part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (6.5 - i * 0.6) * scale,
			CFrame = CFrame.new(position + offset * scale),
			Color = leafColors[(i % #leafColors) + 1],
			Material = Enum.Material.Grass,
			CanCollide = false,
			Parent = model,
		})
	end
	model.PrimaryPart = trunk
	model.Parent = parent
end

local function buildPortal(parent: Instance)
	local folder = Instance.new("Model")
	folder.Name = "Portal"
	local center = Layout.PortalPosition + Vector3.new(0, 11, 0)
	local radius = 10
	local count = 22
	for i = 0, count - 1 do
		local angle = (i / count) * math.pi * 2
		local offset = Vector3.new(0, math.sin(angle) * radius, math.cos(angle) * radius)
		local color = Color3.fromHSV(i / count, 0.7, 1)
		part({
			Name = "Ring",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2.4,
			CFrame = CFrame.new(center + offset),
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = folder,
		})
	end
	local core = part({
		Name = "Core",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, radius * 2 - 1, radius * 2 - 1),
		CFrame = CFrame.new(center),
		Color = Color3.fromRGB(150, 90, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.45,
		CanCollide = false,
		Parent = folder,
	})
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(200, 150, 255), Color3.fromRGB(120, 255, 255))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(1, 2)
	emitter.Rate = 25
	emitter.Speed = NumberRange.new(3, 6)
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.LightEmission = 1
	emitter.EmissionDirection = Enum.NormalId.Right
	emitter.Parent = core
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(170, 120, 255)
	light.Range = 30
	light.Brightness = 2
	light.Parent = core

	-- Cartel con el nombre del juego
	local sign = part({
		Name = "TitleSign",
		Size = Vector3.new(1, 8, 34),
		CFrame = CFrame.new(center + Vector3.new(-2, radius + 7, 0)),
		Transparency = 1,
		CanCollide = false,
		Parent = folder,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.LightInfluence = 0
	gui.PixelsPerStud = 40
	gui.Parent = sign
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 1)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.Text = string.upper(Config.GameName)
	title.TextColor3 = Color3.fromRGB(140, 255, 120)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 6
	stroke.Color = Color3.fromRGB(20, 60, 20)
	stroke.Parent = title
	title.Parent = gui
	folder.Parent = parent
end

local function buildBoard(parent: Instance, name: string, title: string, position: Vector3, lookAt: Vector3, color: Color3)
	local board = part({
		Name = name,
		Size = Vector3.new(16, 22, 1),
		CFrame = CFrame.lookAt(position + Vector3.new(0, 12, 0), lookAt + Vector3.new(0, 12, 0)),
		Color = Color3.fromRGB(30, 32, 48),
		Parent = parent,
	})
	part({
		Name = "Frame",
		Size = Vector3.new(17, 23, 0.8),
		CFrame = board.CFrame * CFrame.new(0, 0, 0.3),
		Color = color,
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	for _, side in { -1, 1 } do
		part({
			Name = "Leg",
			Size = Vector3.new(1, 2, 1),
			CFrame = board.CFrame * CFrame.new(side * 6, -12, 0),
			Color = Color3.fromRGB(30, 32, 48),
			Parent = parent,
		})
	end

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

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, -20, 0, 70)
	header.Font = Enum.Font.FredokaOne
	header.TextScaled = true
	header.Text = title
	header.TextColor3 = color
	header.LayoutOrder = 0
	local headerStroke = Instance.new("UIStroke")
	headerStroke.Thickness = 3
	headerStroke.Parent = header
	header.Parent = gui

	for rank = 1, 10 do
		local row = Instance.new("TextLabel")
		row.Name = "Row" .. rank
		row.BackgroundColor3 = if rank % 2 == 0 then Color3.fromRGB(40, 44, 64) else Color3.fromRGB(48, 52, 74)
		row.BackgroundTransparency = 0.1
		row.Size = UDim2.new(1, -24, 0, 50)
		row.Font = Enum.Font.FredokaOne
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = if rank == 1 then Color3.fromRGB(255, 215, 60) elseif rank == 2 then Color3.fromRGB(220, 220, 230) elseif rank == 3 then Color3.fromRGB(230, 150, 90) else Color3.fromRGB(240, 240, 255)
		row.Text = ("  #%d  ---"):format(rank)
		row.LayoutOrder = rank
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = row
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 6)
		padding.PaddingBottom = UDim.new(0, 6)
		padding.Parent = row
		row.Parent = gui
	end

	MapService.Boards[name] = gui
end

function MapService.Build()
	local map = Instance.new("Folder")
	map.Name = "Map"
	MapService.Folder = map

	-- Suelo
	part({ Name = "Ground", Size = Vector3.new(520, 4, 340), CFrame = CFrame.new(0, -2, 0), Color = Color3.fromRGB(95, 180, 80), Material = Enum.Material.Grass, Parent = map })
	part({ Name = "Plaza", Size = Vector3.new(380, 0.2, 40), CFrame = CFrame.new(0, 0.1, 0), Color = Color3.fromRGB(225, 215, 190), Material = Enum.Material.Concrete, Parent = map })
	part({ Name = "SpawnPlaza", Size = Vector3.new(60, 0.2, 90), CFrame = CFrame.new(Layout.SpawnPosition.X - 8, 0.1, 0), Color = Color3.fromRGB(225, 215, 190), Material = Enum.Material.Concrete, Parent = map })

	-- Pasarela
	local runwayLength = (Layout.RunwayEnd - Layout.RunwayStart).Magnitude + 8
	local runwayCenter = (Layout.RunwayStart + Layout.RunwayEnd) / 2
	part({ Name = "Runway", Size = Vector3.new(runwayLength, 1, Layout.RunwayWidth), CFrame = CFrame.new(runwayCenter.X, 0.5, runwayCenter.Z), Color = Color3.fromRGB(45, 45, 62), Parent = map })
	for _, side in { -1, 1 } do
		part({
			Name = "RunwayEdge",
			Size = Vector3.new(runwayLength, 1.3, 0.8),
			CFrame = CFrame.new(runwayCenter.X, 0.65, side * (Layout.RunwayWidth / 2 + 0.4)),
			Color = if side < 0 then Color3.fromRGB(255, 80, 200) else Color3.fromRGB(80, 220, 255),
			Material = Enum.Material.Neon,
			Parent = map,
		})
	end
	-- Flechas (chevrons) en la pasarela
	local x = Layout.RunwayStart.X + 10
	while x < Layout.RunwayEnd.X - 4 do
		for _, side in { -1, 1 } do
			part({
				Name = "Chevron",
				Size = Vector3.new(0.6, 0.12, 5),
				CFrame = CFrame.new(x, 1.04, side * 1.6) * CFrame.Angles(0, side * math.rad(-40), 0),
				Color = Color3.fromRGB(255, 255, 255),
				Material = Enum.Material.Neon,
				Transparency = 0.55,
				CanCollide = false,
				Parent = map,
			})
		end
		x += 14
	end
	-- Final de la pasarela
	part({
		Name = "Drain",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 14, 14),
		CFrame = CFrame.new(Layout.RunwayEnd.X + 4, 0.6, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(20, 20, 30),
		Material = Enum.Material.Neon,
		Parent = map,
	})

	buildPortal(map)

	-- Spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.new(Layout.SpawnPosition.X, 0.5, 0)
	spawn.Color = Color3.fromRGB(120, 255, 140)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.3
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = map

	-- Tablones de clasificación
	local boards = Instance.new("Folder")
	boards.Name = "Leaderboards"
	boards.Parent = map
	local boardX = Layout.SpawnPosition.X - 26
	buildBoard(boards, "TopEarned", "💰 TOP EARNERS", Vector3.new(boardX, 0, -24), Vector3.new(0, 0, -24), Color3.fromRGB(90, 255, 120))
	buildBoard(boards, "TopRebirths", "♻️ TOP REBIRTHS", Vector3.new(boardX, 0, 24), Vector3.new(0, 0, 24), Color3.fromRGB(255, 200, 60))
	buildBoard(boards, "TopSteals", "😈 TOP THIEVES", Vector3.new(boardX - 4, 0, 0), Vector3.new(0, 0, 0), Color3.fromRGB(255, 90, 110))

	-- Árboles decorativos
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = map
	local rng = Random.new(42)
	for i = 1, 26 do
		local side = if i % 2 == 0 then 1 else -1
		local tx = -230 + (i / 26) * 460 + rng:NextNumber(-6, 6)
		local tz = side * rng:NextNumber(110, 150)
		buildTree(decor, Vector3.new(tx, 0, tz), rng:NextNumber(0.9, 1.4))
	end
	for i = 1, 8 do
		local tz = -140 + i * 31
		buildTree(decor, Vector3.new(235 + rng:NextNumber(-8, 8), 0, tz), rng:NextNumber(0.9, 1.4))
		buildTree(decor, Vector3.new(-245 + rng:NextNumber(-6, 6), 0, tz), rng:NextNumber(0.9, 1.4))
	end

	-- Muros invisibles en el borde del mapa
	for _, wall in {
		{ Vector3.new(0, 50, -168), Vector3.new(520, 100, 2) },
		{ Vector3.new(0, 50, 168), Vector3.new(520, 100, 2) },
		{ Vector3.new(-258, 50, 0), Vector3.new(2, 100, 340) },
		{ Vector3.new(258, 50, 0), Vector3.new(2, 100, 340) },
	} do
		part({ Name = "Boundary", Size = wall[2], CFrame = CFrame.new(wall[1]), Transparency = 1, CanCollide = true, Parent = map })
	end

	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = map

	local slimes = Instance.new("Folder")
	slimes.Name = "Slimes"
	slimes.Parent = workspace

	local effects = Instance.new("Folder")
	effects.Name = "Effects"
	effects.Parent = workspace

	map.Parent = workspace
	setupLighting()
	return map
end

return MapService
