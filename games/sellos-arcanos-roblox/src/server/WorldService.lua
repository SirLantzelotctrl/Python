-- Construye el mundo al arrancar el servidor: iluminación nocturna con Bloom,
-- la Ciudadela del Sello (centro con 12 portales y la Fuente del Sello) y las
-- 12 islas flotantes del Velo, cada una con su sello en el suelo, decorado,
-- zona de criaturas salvajes, portal de vuelta y altar del Primordial.
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameData = require(Shared.GameData)
local Config = require(Shared.Config)

local World = {}

World.GroundY = 100
World.HubRadius = 82
World.IslandRadius = 120
World.IslandDistance = 1100
World.Islands = {} -- index -> {center, spawn, altar, model, color, wildArea}
World.Hub = nil

local NIGHT = Color3.fromHex("#090817")
local STONE = Color3.fromRGB(29, 25, 54)
local STONE_DARK = Color3.fromRGB(20, 17, 39)

local root = Instance.new("Folder")
root.Name = "Mundo"

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Slate
	p.Color = STONE
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end
World.part = part

-- disco plano (cilindro con el eje en Y)
local function disc(parent, center, radius, height, color, material, transparency)
	local p = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.Slate,
		Transparency = transparency or 0,
		CanCollide = false,
		CastShadow = false,
	})
	p.Parent = parent
	return p
end
World.disc = disc

-- Círculo mágico procedural: anillos de neón concéntricos y una estrella.
-- Si hay una imagen subida en Config.Assets.circles se usa como Decal.
function World.magicCircle(parent, center, radius, color, design, intensity)
	local m = Instance.new("Model")
	m.Name = "Sello"
	pcall(function()
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	local transp = 1 - math.clamp(intensity or 1, 0, 1) * 0.85
	local assetId = Config.Assets.circles[design or "hexagrama"]
	if assetId and assetId ~= 0 then
		local plate = part({
			Size = Vector3.new(radius * 2, 0.05, radius * 2),
			CFrame = CFrame.new(center + Vector3.new(0, 0.06, 0)),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		local d = Instance.new("Decal")
		d.Face = Enum.NormalId.Top
		d.Texture = "rbxassetid://" .. assetId
		d.Color3 = color
		d.Transparency = transp * 0.6
		d.Parent = plate
		plate.Parent = m
	else
		local rings = { 1, 0.93, 0.62, 0.55, 0.16 }
		for i, k in ipairs(rings) do
			local neon = (i % 2 == 1)
			local ring = disc(m, center + Vector3.new(0, 0.05 + i * 0.012, 0), radius * k, 0.04,
				neon and color or NIGHT, neon and Enum.Material.Neon or Enum.Material.SmoothPlastic,
				neon and transp or 0.15)
			ring.CanQuery = false
		end
		-- estrella: n puntas unidas saltando k vértices
		local n = (design == "pentagrama" and 5) or (design == "heptagrama" and 7) or 6
		local step = (n == 6) and 2 or ((n == 7) and 3 or 2)
		local r = radius * 0.6
		for i = 0, n - 1 do
			local a1 = math.rad(-90) + (i / n) * math.pi * 2
			local a2 = math.rad(-90) + (((i + step) % n) / n) * math.pi * 2
			local p1 = center + Vector3.new(math.cos(a1) * r, 0.14, math.sin(a1) * r)
			local p2 = center + Vector3.new(math.cos(a2) * r, 0.14, math.sin(a2) * r)
			local bar = part({
				Size = Vector3.new(math.max(0.12, radius * 0.025), 0.03, (p2 - p1).Magnitude),
				CFrame = CFrame.lookAt((p1 + p2) / 2, p2),
				Color = color,
				Material = Enum.Material.Neon,
				Transparency = transp,
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
			})
			bar.Parent = m
		end
	end
	m.Parent = parent
	return m
end

local function setupLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 1.2
	Lighting.Ambient = Color3.fromRGB(46, 40, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(58, 50, 100)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	Lighting.FogColor = NIGHT
	Lighting.FogStart = 200
	Lighting.FogEnd = 900
	for _, c in ipairs(Lighting:GetChildren()) do
		if c:IsA("PostEffect") or c:IsA("Atmosphere") or c:IsA("Sky") then
			c:Destroy()
		end
	end
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 1
	bloom.Size = 24
	bloom.Threshold = 0.9
	bloom.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.08
	cc.Contrast = 0.08
	cc.TintColor = Color3.fromRGB(235, 228, 255)
	cc.Parent = Lighting
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.32
	atm.Offset = 0.1
	atm.Color = Color3.fromRGB(40, 32, 80)
	atm.Decay = Color3.fromRGB(12, 10, 30)
	atm.Glare = 0
	atm.Haze = 1.2
	atm.Parent = Lighting
	local sky = Instance.new("Sky")
	sky.StarCount = 5000
	sky.CelestialBodiesShown = false
	sky.Parent = Lighting
end

-- raíz de roca colgando bajo una isla (cilindros cada vez más estrechos)
local function rockRoot(parent, center, radius)
	local y = center.Y - 4
	local r = radius
	for i = 1, 6 do
		local h = 10 + i * 2
		local p = disc(parent, Vector3.new(center.X + math.random(-4, 4), y - h / 2, center.Z + math.random(-4, 4)), r, h,
			i % 2 == 0 and STONE_DARK or STONE, Enum.Material.Slate)
		p.CanCollide = false
		y = y - h + 2
		r = r * 0.72
	end
end

local PROP_BUILDERS = {}

function PROP_BUILDERS.crystal(parent, pos, color)
	for k = 1, 3 do
		local h = math.random(5, 14)
		local p = part({
			Size = Vector3.new(2, h, 2),
			CFrame = CFrame.new(pos + Vector3.new(math.random(-3, 3), h / 2, math.random(-3, 3)))
				* CFrame.Angles(math.rad(math.random(-15, 15)), math.rad(math.random(0, 90)), math.rad(math.random(-15, 15))),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.25,
		})
		p.Parent = parent
	end
end

function PROP_BUILDERS.pillar(parent, pos, color)
	local h = math.random(10, 22)
	local p = part({ Size = Vector3.new(4, h, 4), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, math.rad(math.random(0, 90)), math.rad(math.random(-6, 6))), Color = Color3.fromRGB(43, 38, 72) })
	p.Parent = parent
	local strip = part({ Size = Vector3.new(4.2, 0.4, 4.2), CFrame = p.CFrame * CFrame.new(0, h * 0.15, 0), Color = color, Material = Enum.Material.Neon })
	strip.Parent = parent
end

function PROP_BUILDERS.statue(parent, pos)
	local h = math.random(7, 11)
	local body = part({ Size = Vector3.new(3, h, 2), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, math.rad(math.random(0, 180)), 0), Color = Color3.fromRGB(74, 85, 82) })
	body.Parent = parent
	local head = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4), CFrame = body.CFrame * CFrame.new(0, h / 2 + 1.2, 0), Color = Color3.fromRGB(74, 85, 82) })
	head.Parent = parent
end

function PROP_BUILDERS.rock(parent, pos)
	local s = math.random(4, 10)
	local p = part({ Size = Vector3.new(s, s * 0.8, s), CFrame = CFrame.new(pos + Vector3.new(0, s * 0.3, 0)) * CFrame.Angles(math.rad(math.random(0, 40)), math.rad(math.random(0, 90)), math.rad(math.random(0, 40))), Color = Color3.fromRGB(35, 31, 61) })
	p.Parent = parent
end

function PROP_BUILDERS.flower(parent, pos, color)
	for k = 1, 4 do
		local stem = part({ Size = Vector3.new(0.3, 2.5, 0.3), CFrame = CFrame.new(pos + Vector3.new(math.random(-3, 3), 1.25, math.random(-3, 3))), Color = Color3.fromRGB(46, 58, 53), CanCollide = false })
		stem.Parent = parent
		local bloom = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), CFrame = stem.CFrame * CFrame.new(0, 1.4, 0), Color = color, Material = Enum.Material.Neon, CanCollide = false })
		bloom.Parent = parent
	end
end

local PROPS_BY_TYPE = {
	flores = { "flower", "flower", "rock" },
	pilares = { "pillar", "rock" },
	estatuas = { "statue", "statue", "rock" },
	hielo = { "crystal", "rock" },
	rocas = { "rock", "rock", "pillar" },
	cristales = { "crystal", "crystal", "rock" },
	lava = { "rock", "crystal" },
	corales = { "crystal", "rock" },
	telas = { "pillar", "statue" },
	estrellas = { "crystal", "rock" },
	vacio = { "crystal", "pillar", "rock" },
}

-- Portal: arco de piedra con un disco de neón vertical y un ProximityPrompt
local function portal(parent, cf, color, name)
	local m = Instance.new("Model")
	m.Name = name
	for _, sx in ipairs({ -1, 1 }) do
		local pil = part({ Size = Vector3.new(2.4, 15, 2.4), CFrame = cf * CFrame.new(sx * 6, 7.5, 0), Color = Color3.fromRGB(43, 38, 72) })
		pil.Parent = m
	end
	local top = part({ Size = Vector3.new(15, 2.4, 2.6), CFrame = cf * CFrame.new(0, 15.6, 0), Color = Color3.fromRGB(43, 38, 72) })
	top.Parent = m
	local gate = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 12, 12),
		CFrame = cf * CFrame.new(0, 7.6, 0) * CFrame.Angles(0, math.rad(90), 0),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
	})
	gate.Name = "Gate"
	gate.Parent = m
	local prompt = Instance.new("ProximityPrompt")
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = gate
	m.PrimaryPart = gate
	m.Parent = parent
	return m, prompt
end
World.portal = portal

local function buildHub()
	local hub = Instance.new("Model")
	hub.Name = "Ciudadela"
	local c = Vector3.new(0, World.GroundY, 0)
	local floor = disc(hub, c - Vector3.new(0, 3, 0), World.HubRadius, 6, STONE, Enum.Material.Slate)
	floor.CanCollide = true
	floor.Name = "Suelo"
	rockRoot(hub, c - Vector3.new(0, 6, 0), World.HubRadius * 0.95)
	disc(hub, c - Vector3.new(0, 0.0, 0), World.HubRadius + 0.6, 0.1, Color3.fromHex("#cbb8ff"), Enum.Material.Neon, 0.4)
	disc(hub, c + Vector3.new(0, 0.02, 0), World.HubRadius - 0.3, 0.1, STONE, Enum.Material.Slate, 0)
	World.magicCircle(hub, c, 36, Color3.fromHex("#cbb8ff"), "heptagrama", 0.55)
	CollectionService:AddTag(hub:FindFirstChild("Sello"), "SA_Spin")

	-- Fuente del Sello: cura y revive al equipo
	local fountain = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 12, 12), CFrame = CFrame.new(c + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(43, 38, 72) })
	fountain.Parent = hub
	local core = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(5, 5, 5), CFrame = CFrame.new(c + Vector3.new(0, 7, 0)), Color = Color3.fromHex("#cbb8ff"), Material = Enum.Material.Neon, CanCollide = false })
	core.Name = "FuenteNucleo"
	core.Parent = hub
	CollectionService:AddTag(core, "SA_Bob")
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex("#cbb8ff")
	light.Range = 40
	light.Brightness = 2
	light.Parent = core
	local fprompt = Instance.new("ProximityPrompt")
	fprompt.Name = "FuentePrompt"
	fprompt.ActionText = "Restaurar equipo"
	fprompt.ObjectText = "Fuente del Sello"
	fprompt.MaxActivationDistance = 16
	fprompt.RequiresLineOfSight = false
	fprompt.Parent = core

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(c + Vector3.new(0, 0.4, 22))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	-- 12 portales en círculo, uno por isla
	local portals = {}
	for i, isl in ipairs(GameData.Islands) do
		local a = (i - 1) / #GameData.Islands * math.pi * 2
		local pos = c + Vector3.new(math.cos(a) * (World.HubRadius - 10), 0, math.sin(a) * (World.HubRadius - 10))
		local cf = CFrame.lookAt(pos, Vector3.new(c.X, pos.Y, c.Z))
		local boss = GameData.CreatureById[isl.boss]
		local m, prompt = portal(hub, cf, Color3.fromHex(boss.color), "Portal_" .. i)
		m:SetAttribute("IslandIndex", i)
		prompt:SetAttribute("IslandIndex", i)
		prompt.Name = "TravelPrompt"
		prompt.ActionText = "Viajar"
		prompt.ObjectText = isl.name.es
		CollectionService:AddTag(m, "SA_Portal")
		portals[i] = prompt
	end
	hub.Parent = root
	World.Hub = { center = c, spawn = c + Vector3.new(0, 3, 22), model = hub, portals = portals, fountain = fprompt }
end

local function buildIsland(i, isl)
	local a = (i - 1) / #GameData.Islands * math.pi * 2
	local c = Vector3.new(math.cos(a) * World.IslandDistance, World.GroundY, math.sin(a) * World.IslandDistance)
	local boss = GameData.CreatureById[isl.boss]
	local color = Color3.fromHex(boss.color)
	local m = Instance.new("Model")
	m.Name = "Isla_" .. i
	local floor = disc(m, c - Vector3.new(0, 3, 0), World.IslandRadius, 6, STONE, Enum.Material.Slate)
	floor.CanCollide = true
	floor.Name = "Suelo"
	rockRoot(m, c - Vector3.new(0, 6, 0), World.IslandRadius * 0.95)
	disc(m, c, World.IslandRadius + 0.6, 0.1, color, Enum.Material.Neon, 0.55)
	disc(m, c + Vector3.new(0, 0.02, 0), World.IslandRadius - 0.3, 0.1, STONE, Enum.Material.Slate, 0)
	local floorSeal = World.magicCircle(m, c, World.IslandRadius * 0.8, color, boss.circle, 0.18)
	CollectionService:AddTag(floorSeal, "SA_Spin")

	-- decorado en el borde
	local kinds = PROPS_BY_TYPE[isl.props] or PROPS_BY_TYPE.rocas
	for k = 1, 22 do
		local pa = math.random() * math.pi * 2
		local pr = World.IslandRadius * (0.82 + math.random() * 0.14)
		local pos = c + Vector3.new(math.cos(pa) * pr, 0, math.sin(pa) * pr)
		local kind = kinds[math.random(1, #kinds)]
		PROP_BUILDERS[kind](m, pos, color)
	end

	-- portal de vuelta (cerca del borde, mirando al centro)
	local toHub = (Vector3.new(0, c.Y, 0) - c).Unit
	local ppos = c + toHub * (World.IslandRadius - 16)
	local _, back = portal(m, CFrame.lookAt(ppos, c), Color3.fromHex("#cbb8ff"), "PortalVuelta")
	back.Name = "ReturnPrompt"
	back.ActionText = "Volver a la Ciudadela"
	back.ObjectText = isl.name.es
	back:SetAttribute("IslandIndex", i)
	local spawn = c + toHub * (World.IslandRadius - 30) + Vector3.new(0, 3, 0)

	-- altar del Primordial en el lado opuesto
	local altarPos = c - toHub * (World.IslandRadius - 40)
	local altarSeal = World.magicCircle(m, altarPos, 22, color, boss.circle, 0.6)
	CollectionService:AddTag(altarSeal, "SA_Spin")
	local stone = part({ Size = Vector3.new(6, 6, 6), CFrame = CFrame.new(altarPos + Vector3.new(0, 3, 0)) * CFrame.Angles(0, math.rad(45), 0), Color = Color3.fromRGB(43, 38, 72) })
	stone.Name = "Altar"
	stone.Parent = m
	local rune = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), CFrame = CFrame.new(altarPos + Vector3.new(0, 8, 0)), Color = color, Material = Enum.Material.Neon, CanCollide = false })
	rune.Parent = m
	CollectionService:AddTag(rune, "SA_Bob")
	local bprompt = Instance.new("ProximityPrompt")
	bprompt.Name = "BossPrompt"
	bprompt.ActionText = "Desafiar al Primordial"
	bprompt.ObjectText = boss.name.es
	bprompt.HoldDuration = 1
	bprompt.MaxActivationDistance = 16
	bprompt.RequiresLineOfSight = false
	bprompt:SetAttribute("IslandIndex", i)
	bprompt.Parent = stone

	m:SetAttribute("IslandIndex", i)
	m.Parent = root
	World.Islands[i] = {
		index = i, center = c, spawn = spawn, model = m, color = color, toHub = toHub,
		altar = altarPos, bossArena = altarPos + toHub * 34, returnPrompt = back, bossPrompt = bprompt,
		wildCenter = c + toHub * 10, wildRadius = World.IslandRadius * 0.55,
	}
end

-- ¿en qué isla está esta posición? (0 = Ciudadela, nil = cayendo al Abismo)
function World.islandAt(pos)
	if (Vector3.new(pos.X, 0, pos.Z)).Magnitude < World.HubRadius + 20 then
		return 0
	end
	for i, isl in ipairs(World.Islands) do
		local d = Vector3.new(pos.X - isl.center.X, 0, pos.Z - isl.center.Z).Magnitude
		if d < World.IslandRadius + 20 then
			return i
		end
	end
	return nil
end

-- recorta una posición para que quede sobre la isla
function World.clampToIsland(islandIdx, pos, margin)
	local c, r
	if islandIdx == 0 then
		c, r = Vector3.new(0, World.GroundY, 0), World.HubRadius
	else
		local isl = World.Islands[islandIdx]
		if not isl then
			return pos
		end
		c, r = isl.center, World.IslandRadius
	end
	local d = Vector3.new(pos.X - c.X, 0, pos.Z - c.Z)
	local max = r - (margin or 4)
	if d.Magnitude > max then
		d = d.Unit * max
	end
	return Vector3.new(c.X + d.X, World.GroundY, c.Z + d.Z)
end

function World.init()
	math.randomseed(1234)
	setupLighting()
	buildHub()
	for i, isl in ipairs(GameData.Islands) do
		buildIsland(i, isl)
	end
	root.Parent = workspace
	math.randomseed(os.time())
	-- red de seguridad: quien cae al Abismo vuelve a la Ciudadela
	pcall(function()
		workspace.FallenPartsDestroyHeight = World.GroundY - 160
	end)
end

return World
