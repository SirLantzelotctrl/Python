-- Modelos 3D hechos con piezas: criaturas, huevos y meteoritos.
-- Convención: el modelo se construye en el origen, Root en la base, el frente mira a -Z.

local CollectionService = game:GetService("CollectionService")

local Critters = require(script.Parent.Critters)
local Rarities = require(script.Parent.Rarities)
local Zones = require(script.Parent.Zones)

local Models = {}

local WHITE = Color3.fromRGB(255, 255, 255)
local BLACK = Color3.fromRGB(20, 20, 26)
local PINK = Color3.fromRGB(255, 130, 160)
local GOLD = Color3.fromRGB(255, 205, 60)
local SILHOUETTE = Color3.fromRGB(18, 18, 28)

type Ctx = {
	Model: Model,
	Root: BasePart,
	S: number,
	W: number,
	H: number,
	D: number,
	CY: number,
	Color: Color3,
	Accent: Color3,
	Silhouette: boolean,
	Effects: boolean,
	Body: BasePart?,
	Eyes: { Vector3 },
	EyeSize: number,
}

-- ---------------------------------------------------------------------
-- Geometría
-- ---------------------------------------------------------------------
local function prepare(ctx: Ctx, part: BasePart, name: string, color: Color3, material: Enum.Material?)
	part.Name = name
	part.Color = if ctx.Silhouette then SILHOUETTE else color
	part.Material = if ctx.Silhouette then Enum.Material.SmoothPlastic else (material or Enum.Material.SmoothPlastic)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.Anchored = false
	part.CastShadow = false
	part.Parent = ctx.Model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = ctx.Root
	weld.Part1 = part
	weld.Parent = part
end

local function ball(ctx: Ctx, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = cf
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	prepare(ctx, part, name, color, material)
	return part
end

local function block(ctx: Ctx, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = cf
	prepare(ctx, part, name, color, material)
	return part
end

local function alongDir(center: Vector3, dir: Vector3): CFrame
	local unit = dir.Unit
	if math.abs(unit.Y) > 0.999 then
		return if unit.Y > 0 then CFrame.new(center) else CFrame.new(center) * CFrame.Angles(math.pi, 0, 0)
	end
	return CFrame.lookAt(center, center + dir) * CFrame.Angles(-math.pi / 2, 0, 0)
end

local function cylinder(ctx: Ctx, name: string, height: number, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(height, diameter, diameter)
	part.CFrame = cf * CFrame.Angles(0, 0, math.pi / 2)
	prepare(ctx, part, name, color, material)
	return part
end

local function cylBetween(ctx: Ctx, name: string, a: Vector3, b: Vector3, diameter: number, color: Color3, material: Enum.Material?): Part
	return cylinder(ctx, name, (b - a).Magnitude, diameter, alongDir((a + b) / 2, b - a), color, material)
end

local function blockBetween(ctx: Ctx, name: string, a: Vector3, b: Vector3, w: number, d: number, color: Color3, material: Enum.Material?): Part
	return block(ctx, name, Vector3.new(w, (b - a).Magnitude, d), alongDir((a + b) / 2, b - a), color, material)
end

-- Punto en la superficie del cuerpo (elipsoide centrado en (0, CY, 0)) en la dirección dada
local function surface(ctx: Ctx, dir: Vector3, inset: number?): Vector3
	local d = dir.Unit
	local a, b, c = ctx.W / 2, ctx.H / 2, ctx.D / 2
	local t = 1 / math.sqrt((d.X / a) ^ 2 + (d.Y / b) ^ 2 + (d.Z / c) ^ 2)
	return Vector3.new(0, ctx.CY, 0) + d * (t - (inset or 0))
end

local function tag(instance: Instance, name: string)
	CollectionService:AddTag(instance, name)
end

local function effect(ctx: Ctx, instance: Instance, parent: Instance?)
	if not ctx.Effects then
		instance:Destroy()
		return
	end
	instance.Parent = parent or ctx.Body or ctx.Root
end

local function particles(ctx: Ctx, a: Color3, b: Color3, rate: number, size: number, parent: Instance?)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(a, b)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.8, 1.5)
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(1, 2.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 0.8
	emitter.Drag = 1
	effect(ctx, emitter, parent)
end

local function light(ctx: Ctx, color: Color3, range: number, brightness: number, parent: Instance?)
	local pointLight = Instance.new("PointLight")
	pointLight.Color = color
	pointLight.Range = range
	pointLight.Brightness = brightness
	effect(ctx, pointLight, parent)
end

local function darker(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

local function lighter(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

local function newModel(name: string, rootSize: Vector3): (Model, Part)
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = rootSize
	root.CFrame = CFrame.new()
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Parent = model
	model.PrimaryPart = root
	return model, root
end

-- ---------------------------------------------------------------------
-- Rasgos de las criaturas
-- ---------------------------------------------------------------------
local Features: { [string]: (Ctx) -> () } = {}

local function topY(ctx: Ctx): number
	return ctx.CY + ctx.H / 2
end

local function pair(fn: (side: number) -> ())
	fn(-1)
	fn(1)
end

Features.TinyLeaf = function(ctx)
	local S = ctx.S
	local base = Vector3.new(0, topY(ctx) - S * 0.03, 0)
	cylBetween(ctx, "Stem", base, base + Vector3.new(0, S * 0.12, 0), S * 0.04, Color3.fromRGB(70, 150, 60))
	ball(ctx, "Leaf", Vector3.new(S * 0.26, S * 0.05, S * 0.14), CFrame.new(base + Vector3.new(S * 0.08, S * 0.14, 0)) * CFrame.Angles(0, 0, math.rad(25)), Color3.fromRGB(90, 200, 80))
end

Features.Sprout = function(ctx)
	local S = ctx.S
	local base = Vector3.new(0, topY(ctx) - S * 0.03, 0)
	local tip = base + Vector3.new(0, S * 0.24, 0)
	cylBetween(ctx, "Stem", base, tip, S * 0.05, Color3.fromRGB(70, 160, 60))
	pair(function(side)
		ball(ctx, "Leaf", Vector3.new(S * 0.3, S * 0.06, S * 0.16), CFrame.new(tip + Vector3.new(side * S * 0.13, S * 0.02, 0)) * CFrame.Angles(0, 0, side * math.rad(25)), Color3.fromRGB(110, 220, 90))
	end)
end

Features.Stripes = function(ctx)
	for _, yf in { -0.15, 0.25 } do
		local y = ctx.CY + yf * ctx.H / 2
		local r = (ctx.W / 2) * math.sqrt(1 - yf * yf)
		cylinder(ctx, "Stripe", ctx.S * 0.09, r * 2.04, CFrame.new(0, y, ctx.S * 0.02), BLACK)
	end
end

Features.BugWings = function(ctx)
	local S = ctx.S
	pair(function(side)
		local wing = ball(ctx, "Wing", Vector3.new(S * 0.55, S * 0.32, S * 0.04), CFrame.new(side * S * 0.36, ctx.CY + S * 0.28, S * 0.3) * CFrame.Angles(0, side * math.rad(-25), side * math.rad(35)), Color3.fromRGB(220, 245, 255), Enum.Material.Glass)
		wing.Transparency = 0.35
	end)
end

Features.Antennae = function(ctx)
	local S = ctx.S
	local tipColor = Rarities.Get(ctx.Model:GetAttribute("Rarity") or "Common").Color
	pair(function(side)
		local base = surface(ctx, Vector3.new(side * 0.35, 1, -0.1), S * 0.02)
		local tip = base + Vector3.new(side * 0.35, 1, -0.15).Unit * S * 0.4
		cylBetween(ctx, "Antenna", base, tip, S * 0.04, darker(ctx.Color, 0.5))
		ball(ctx, "AntennaTip", Vector3.one * S * 0.12, CFrame.new(tip), tipColor, Enum.Material.Neon)
	end)
end

local function ear(ctx: Ctx, side: number, size: Vector3, tilt: number, inner: boolean, yLift: number?)
	local S = ctx.S
	local base = surface(ctx, Vector3.new(side * 0.55, 1, 0), S * 0.05)
	local cf = CFrame.new(base + Vector3.new(0, size.Y * 0.4 + (yLift or 0), 0)) * CFrame.Angles(0, 0, -side * math.rad(tilt))
	ball(ctx, "Ear", size, cf, ctx.Color)
	if inner then
		ball(ctx, "EarInner", size * Vector3.new(0.55, 0.7, 0.6), cf * CFrame.new(0, -size.Y * 0.05, -size.Z * 0.3), PINK)
	end
end

Features.PointyEars = function(ctx)
	pair(function(side)
		ear(ctx, side, Vector3.new(ctx.S * 0.22, ctx.S * 0.42, ctx.S * 0.1), 18, true)
	end)
end

Features.RoundEars = function(ctx)
	pair(function(side)
		ear(ctx, side, Vector3.new(ctx.S * 0.28, ctx.S * 0.28, ctx.S * 0.12), 10, true, -ctx.S * 0.05)
	end)
end

Features.BunnyEars = function(ctx)
	pair(function(side)
		ear(ctx, side * 0.6, Vector3.new(ctx.S * 0.18, ctx.S * 0.65, ctx.S * 0.09), 10, true)
	end)
end

Features.FloppyEars = function(ctx)
	local S = ctx.S
	pair(function(side)
		local pos = surface(ctx, Vector3.new(side, 0.4, 0), -S * 0.02)
		ball(ctx, "FloppyEar", Vector3.new(S * 0.16, S * 0.45, S * 0.24), CFrame.new(pos + Vector3.new(side * S * 0.04, -S * 0.12, 0)) * CFrame.Angles(0, 0, side * math.rad(15)), darker(ctx.Color, 0.25))
	end)
end

Features.OwlTufts = function(ctx)
	local S = ctx.S
	pair(function(side)
		local base = surface(ctx, Vector3.new(side * 0.7, 1, 0), S * 0.06)
		ball(ctx, "Tuft", Vector3.new(S * 0.14, S * 0.32, S * 0.1), CFrame.new(base + Vector3.new(side * S * 0.05, S * 0.12, 0)) * CFrame.Angles(0, 0, -side * math.rad(35)), darker(ctx.Color, 0.3))
	end)
end

Features.FluffyTail = function(ctx)
	local S = ctx.S
	local pos = surface(ctx, Vector3.new(0, -0.2, 1), -S * 0.15)
	local cf = CFrame.new(pos + Vector3.new(S * 0.15, S * 0.15, 0)) * CFrame.Angles(math.rad(-35), 0, math.rad(-20))
	ball(ctx, "Tail", Vector3.new(S * 0.38, S * 0.75, S * 0.38), cf, ctx.Color)
	ball(ctx, "TailTip", Vector3.new(S * 0.3, S * 0.3, S * 0.3), cf * CFrame.new(0, S * 0.32, 0), WHITE)
end

Features.LongTail = function(ctx)
	local S = ctx.S
	local start = surface(ctx, Vector3.new(0, -0.4, 1), S * 0.05)
	local points = { start, start + Vector3.new(S * 0.1, S * 0.05, S * 0.35), start + Vector3.new(S * 0.25, S * 0.2, S * 0.6), start + Vector3.new(S * 0.3, S * 0.45, S * 0.75) }
	for i = 1, #points - 1 do
		cylBetween(ctx, "Tail", points[i], points[i + 1], S * (0.18 - i * 0.04), ctx.Color)
	end
	ball(ctx, "TailTip", Vector3.one * S * 0.12, CFrame.new(points[#points]), darker(ctx.Color, 0.2))
end

Features.CometTail = function(ctx)
	local S = ctx.S
	local start = surface(ctx, Vector3.new(0, 0, 1), S * 0.1)
	local tail = ball(ctx, "CometTail", Vector3.new(S * 0.35, S * 0.35, S * 1.6), CFrame.new(start + Vector3.new(0, 0, S * 0.7)), Color3.fromRGB(150, 230, 255), Enum.Material.Neon)
	tail.Transparency = 0.3
	particles(ctx, Color3.fromRGB(150, 230, 255), WHITE, 8, S * 0.15, tail)
end

Features.Antlers = function(ctx)
	local S = ctx.S
	local color = Color3.fromRGB(200, 160, 110)
	pair(function(side)
		local base = surface(ctx, Vector3.new(side * 0.4, 1, 0), S * 0.03)
		local mid = base + Vector3.new(side * 0.3, 1, 0).Unit * S * 0.3
		local tip = mid + Vector3.new(side * 0.5, 1, 0.1).Unit * S * 0.25
		local branch = mid + Vector3.new(-side * 0.1, 1, -0.4).Unit * S * 0.2
		cylBetween(ctx, "Antler", base, mid, S * 0.07, color)
		cylBetween(ctx, "Antler", mid, tip, S * 0.06, color)
		cylBetween(ctx, "Antler", mid, branch, S * 0.05, color)
	end)
end

Features.StarSpots = function(ctx)
	local S = ctx.S
	for _, dir in { Vector3.new(0.6, 0.5, 0.6), Vector3.new(-0.7, 0.2, 0.7), Vector3.new(0.2, 0.8, 0.5), Vector3.new(-0.4, 0.6, 0.8), Vector3.new(0.8, -0.1, 0.5) } do
		ball(ctx, "Spot", Vector3.one * S * 0.09, CFrame.new(surface(ctx, dir, S * 0.01)), Color3.fromRGB(255, 250, 210), Enum.Material.Neon)
	end
end

Features.Halo = function(ctx)
	local S = ctx.S
	local y = topY(ctx) + S * 0.32
	for i = 0, 11 do
		local angle = math.rad(i * 30)
		ball(ctx, "Halo", Vector3.one * S * 0.09, CFrame.new(math.cos(angle) * S * 0.28, y, math.sin(angle) * S * 0.28), Color3.fromRGB(255, 240, 130), Enum.Material.Neon)
	end
end

Features.Sparkle = function(ctx)
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = lighter(ctx.Color, 0.4)
	effect(ctx, sparkles)
end

Features.Mandibles = function(ctx)
	local S = ctx.S
	pair(function(side)
		local base = surface(ctx, Vector3.new(side * 0.35, -0.3, -1), S * 0.03)
		blockBetween(ctx, "Mandible", base, base + Vector3.new(-side * S * 0.08, -S * 0.04, -S * 0.2), S * 0.06, S * 0.05, darker(ctx.Color, 0.45))
	end)
end

Features.CactusArms = function(ctx)
	local S = ctx.S
	pair(function(side)
		local pos = surface(ctx, Vector3.new(side, 0.1, 0), -S * 0.04)
		ball(ctx, "Arm", Vector3.new(S * 0.18, S * 0.42, S * 0.18), CFrame.new(pos + Vector3.new(side * S * 0.06, S * 0.12, 0)), darker(ctx.Color, 0.1))
	end)
	for _, dir in { Vector3.new(0.5, 0.4, 0.7), Vector3.new(-0.6, 0.1, 0.7), Vector3.new(0.3, -0.3, 0.9) } do
		local pos = surface(ctx, dir, -0.01)
		blockBetween(ctx, "Spine", pos, pos + dir.Unit * S * 0.08, S * 0.02, S * 0.02, Color3.fromRGB(250, 245, 210))
	end
end

Features.Flower = function(ctx)
	local S = ctx.S
	local center = Vector3.new(S * 0.12, topY(ctx) + S * 0.02, 0)
	for i = 0, 4 do
		local angle = math.rad(i * 72)
		ball(ctx, "Petal", Vector3.new(S * 0.13, S * 0.05, S * 0.13), CFrame.new(center + Vector3.new(math.cos(angle) * S * 0.09, 0, math.sin(angle) * S * 0.09)), Color3.fromRGB(255, 120, 190))
	end
	ball(ctx, "FlowerCenter", Vector3.one * S * 0.08, CFrame.new(center + Vector3.new(0, S * 0.02, 0)), Color3.fromRGB(255, 220, 60))
end

Features.Shell = function(ctx)
	local S = ctx.S
	local shell = ball(ctx, "Shell", Vector3.new(ctx.W * 1.02, ctx.H * 0.75, ctx.D * 0.8), CFrame.new(0, ctx.CY + ctx.H * 0.12, ctx.D * 0.14), darker(ctx.Color, 0.25), Enum.Material.SmoothPlastic)
	shell.Reflectance = 0.25
	block(ctx, "ShellLine", Vector3.new(S * 0.04, ctx.H * 0.5, ctx.D * 0.55), CFrame.new(0, ctx.CY + ctx.H * 0.25, ctx.D * 0.2), darker(ctx.Color, 0.55))
end

Features.Horn = function(ctx)
	local S = ctx.S
	local base = surface(ctx, Vector3.new(0, 0.6, -0.8), S * 0.04)
	local tip = base + Vector3.new(0, 0.9, -0.5).Unit * S * 0.45
	cylBetween(ctx, "Horn", base, tip, S * 0.11, darker(ctx.Color, 0.5))
	ball(ctx, "HornTip", Vector3.one * S * 0.09, CFrame.new(tip), darker(ctx.Color, 0.5))
end

Features.Horns = function(ctx)
	local S = ctx.S
	local color = Color3.fromRGB(240, 230, 210)
	pair(function(side)
		local base = surface(ctx, Vector3.new(side * 0.4, 1, 0.1), S * 0.04)
		local mid = base + Vector3.new(side * 0.4, 0.9, 0.2).Unit * S * 0.18
		local tip = mid + Vector3.new(side * 0.1, 0.5, 0.7).Unit * S * 0.16
		cylBetween(ctx, "Horn", base, mid, S * 0.1, color)
		cylBetween(ctx, "Horn", mid, tip, S * 0.07, color)
	end)
end

Features.Frill = function(ctx)
	local S = ctx.S
	for i = -2, 2 do
		local angle = math.rad(i * 28)
		local dir = Vector3.new(math.sin(angle), math.cos(angle), 0.3)
		ball(ctx, "Frill", Vector3.new(S * 0.16, S * 0.42, S * 0.04), CFrame.new(Vector3.new(0, ctx.CY + S * 0.05, ctx.D * 0.25) + dir * S * 0.42) * CFrame.Angles(0, 0, -angle), lighter(ctx.Color, 0.25))
	end
end

Features.SunDisc = function(ctx)
	local S = ctx.S
	local center = Vector3.new(0, topY(ctx) + S * 0.25, S * 0.12)
	cylBetween(ctx, "SunDisc", center + Vector3.new(0, 0, S * 0.03), center - Vector3.new(0, 0, S * 0.03), S * 0.5, GOLD, Enum.Material.Neon)
end

Features.Headdress = function(ctx)
	local S = ctx.S
	local y = ctx.CY + ctx.H * 0.25
	local r = (ctx.W / 2) * math.sqrt(1 - 0.25)
	cylinder(ctx, "Band", S * 0.1, r * 2.06, CFrame.new(0, y, 0), GOLD, Enum.Material.Metal)
	pair(function(side)
		block(ctx, "Flap", Vector3.new(S * 0.06, ctx.H * 0.55, S * 0.3), CFrame.new(side * ctx.W * 0.5, ctx.CY, S * 0.05), Color3.fromRGB(40, 70, 180))
	end)
end

Features.Fluff = function(ctx)
	local S = ctx.S
	for _, dir in { Vector3.new(0, 1, 0), Vector3.new(0.6, 0.8, 0.2), Vector3.new(-0.6, 0.8, 0.1), Vector3.new(0.2, 0.7, 0.7), Vector3.new(-0.3, 0.6, -0.4) } do
		ball(ctx, "Fluff", Vector3.one * S * 0.3, CFrame.new(surface(ctx, dir, S * 0.08)), lighter(ctx.Color, 0.3))
	end
end

Features.Fins = function(ctx)
	local S = ctx.S
	pair(function(side)
		local pos = surface(ctx, Vector3.new(side, -0.1, 0.2), S * 0.04)
		ball(ctx, "Fin", Vector3.new(S * 0.4, S * 0.06, S * 0.26), CFrame.new(pos + Vector3.new(side * S * 0.12, 0, 0)) * CFrame.Angles(0, 0, side * math.rad(-20)), darker(ctx.Color, 0.15))
	end)
	local top = surface(ctx, Vector3.new(0, 1, 0.3), S * 0.06)
	ball(ctx, "TopFin", Vector3.new(S * 0.05, S * 0.3, S * 0.28), CFrame.new(top + Vector3.new(0, S * 0.08, 0)) * CFrame.Angles(math.rad(-20), 0, 0), darker(ctx.Color, 0.15))
end

Features.IceSpikes = function(ctx)
	local S = ctx.S
	for _, dir in { Vector3.new(0, 1, 0.2), Vector3.new(0.5, 0.8, 0.3), Vector3.new(-0.5, 0.8, 0.3), Vector3.new(0.2, 0.6, 0.8) } do
		local base = surface(ctx, dir, S * 0.04)
		local spike = blockBetween(ctx, "IceSpike", base, base + dir.Unit * S * 0.3, S * 0.09, S * 0.09, Color3.fromRGB(190, 240, 255), Enum.Material.Glass)
		spike.Transparency = 0.15
	end
end

Features.Crystals = function(ctx)
	local S = ctx.S
	for _, dir in { Vector3.new(0.3, 0.7, 0.7), Vector3.new(-0.4, 0.6, 0.7), Vector3.new(0, 0.4, 1) } do
		local base = surface(ctx, dir, S * 0.05)
		blockBetween(ctx, "Crystal", base, base + dir.Unit * S * 0.4, S * 0.14, S * 0.14, Color3.fromRGB(140, 220, 255), Enum.Material.Neon)
	end
end

local function featherWings(ctx: Ctx, color: Color3, material: Enum.Material?)
	local S = ctx.S
	pair(function(side)
		local base = CFrame.new(side * ctx.W * 0.45, ctx.CY + S * 0.12, S * 0.12) * CFrame.Angles(0, side * math.rad(-20), side * math.rad(30))
		for i = 0, 2 do
			ball(ctx, "Feather", Vector3.new(S * (0.55 - i * 0.12), S * 0.2, S * 0.05), base * CFrame.new(side * S * (0.2 + i * 0.03), -i * S * 0.1, 0), lighter(color, i * 0.12), material)
		end
	end)
end

Features.BirdWings = function(ctx)
	featherWings(ctx, lighter(ctx.Color, 0.15))
end

Features.BatWings = function(ctx)
	local S = ctx.S
	local color = darker(ctx.Color, 0.3)
	pair(function(side)
		local base = CFrame.new(side * ctx.W * 0.45, ctx.CY + S * 0.15, S * 0.15) * CFrame.Angles(0, side * math.rad(-25), side * math.rad(25))
		ball(ctx, "BatWing", Vector3.new(S * 0.6, S * 0.35, S * 0.04), base * CFrame.new(side * S * 0.22, 0, 0), color)
		for i = 0, 2 do
			ball(ctx, "WingTip", Vector3.new(S * 0.12, S * 0.2, S * 0.04), base * CFrame.new(side * S * (0.12 + i * 0.16), -S * 0.17, 0), color)
		end
	end)
end

Features.Flame = function(ctx)
	local S = ctx.S
	local base = Vector3.new(0, topY(ctx), 0)
	local outer = ball(ctx, "FlameOuter", Vector3.new(S * 0.32, S * 0.42, S * 0.32), CFrame.new(base + Vector3.new(0, S * 0.08, 0)), Color3.fromRGB(255, 120, 30), Enum.Material.Neon)
	ball(ctx, "FlameInner", Vector3.new(S * 0.18, S * 0.28, S * 0.18), CFrame.new(base + Vector3.new(0, S * 0.12, -S * 0.05)), Color3.fromRGB(255, 230, 80), Enum.Material.Neon)
	local fire = Instance.new("Fire")
	fire.Size = 2
	fire.Heat = 4
	fire.Color = Color3.fromRGB(255, 130, 30)
	fire.SecondaryColor = Color3.fromRGB(255, 220, 60)
	effect(ctx, fire, outer)
end

Features.LavaCracks = function(ctx)
	local S = ctx.S
	for _, dir in { Vector3.new(0.5, 0.5, 0.6), Vector3.new(-0.6, 0.3, 0.6), Vector3.new(0.1, 0.9, 0.4), Vector3.new(0.7, -0.2, 0.6) } do
		local pos = surface(ctx, dir, -S * 0.005)
		block(ctx, "Crack", Vector3.new(S * 0.04, S * 0.22, S * 0.03), CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, 0, math.rad(30)), Color3.fromRGB(255, 120, 30), Enum.Material.Neon)
	end
end

Features.Goggles = function(ctx)
	local S = ctx.S
	for index, eye in ctx.Eyes do
		local lens = cylBetween(ctx, "Goggle" .. index, eye + Vector3.new(0, 0, S * 0.02), eye - Vector3.new(0, 0, S * 0.1), ctx.EyeSize * 1.35, Color3.fromRGB(120, 90, 60))
		lens.Transparency = 0
		local glass = cylBetween(ctx, "GoggleGlass" .. index, eye - Vector3.new(0, 0, S * 0.09), eye - Vector3.new(0, 0, S * 0.11), ctx.EyeSize * 1.1, Color3.fromRGB(150, 230, 255), Enum.Material.Glass)
		glass.Transparency = 0.5
	end
	local y = ctx.Eyes[1].Y
	local r = ctx.W / 2 * math.sqrt(math.max(0, 1 - ((y - ctx.CY) / (ctx.H / 2)) ^ 2))
	cylinder(ctx, "Strap", S * 0.06, r * 2.04, CFrame.new(0, y, 0), Color3.fromRGB(60, 45, 35))
end

Features.Claws = function(ctx)
	local S = ctx.S
	pair(function(side)
		local pos = surface(ctx, Vector3.new(side * 0.5, -0.5, -0.7), -S * 0.05)
		ball(ctx, "Paw", Vector3.new(S * 0.22, S * 0.14, S * 0.18), CFrame.new(pos), lighter(ctx.Color, 0.15))
		for i = -1, 1 do
			blockBetween(ctx, "Claw", pos + Vector3.new(i * S * 0.06, 0, -S * 0.07), pos + Vector3.new(i * S * 0.07, -S * 0.03, -S * 0.16), S * 0.03, S * 0.03, WHITE)
		end
	end)
end

Features.Crest = function(ctx)
	local S = ctx.S
	local base = Vector3.new(0, topY(ctx) - S * 0.04, 0)
	for i = -1, 1 do
		ball(ctx, "Plume", Vector3.new(S * 0.08, S * 0.36, S * 0.12), CFrame.new(base + Vector3.new(i * S * 0.08, S * 0.15, i * S * 0.02)) * CFrame.Angles(math.rad(-15), 0, math.rad(-i * 22)), Color3.fromRGB(255, 200 - i * 40, 60), Enum.Material.Neon)
	end
end

Features.Craters = function(ctx)
	local S = ctx.S
	for _, dir in { Vector3.new(0.6, 0.5, 0.5), Vector3.new(-0.5, 0.6, 0.6), Vector3.new(0.7, -0.1, 0.7), Vector3.new(-0.2, 0.9, 0.3) } do
		local pos = surface(ctx, dir, S * 0.01)
		ball(ctx, "Crater", Vector3.new(S * 0.16, S * 0.16, S * 0.03), CFrame.lookAt(pos, pos + dir), darker(ctx.Color, 0.25))
	end
end

Features.OrbitRing = function(ctx)
	local S = ctx.S
	local cf = CFrame.new(0, ctx.CY, 0) * CFrame.Angles(math.rad(20), 0, math.rad(12))
	local ringPart = cylinder(ctx, "Orbit", S * 0.02, ctx.W * 1.7, cf, Color3.fromRGB(200, 220, 255), Enum.Material.Neon)
	ringPart.Transparency = 0.55
	ball(ctx, "Moon", Vector3.one * S * 0.16, cf * CFrame.new(ctx.W * 0.82, 0, 0), Color3.fromRGB(230, 230, 240))
end

Features.Tentacles = function(ctx)
	local S = ctx.S
	for i = 0, 4 do
		local angle = math.rad(i * 72 + 18)
		local base = Vector3.new(math.cos(angle) * ctx.W * 0.28, ctx.CY - ctx.H * 0.35, math.sin(angle) * ctx.D * 0.28)
		local tip = base + Vector3.new(math.cos(angle) * S * 0.1, -S * 0.4, math.sin(angle) * S * 0.1)
		local tentacle = cylBetween(ctx, "Tentacle", base, tip, S * 0.08, lighter(ctx.Color, 0.15), Enum.Material.Glass)
		tentacle.Transparency = 0.25
	end
end

Features.Glow = function(ctx)
	light(ctx, lighter(ctx.Color, 0.3), ctx.S * 4, 1.5)
	particles(ctx, lighter(ctx.Color, 0.4), WHITE, 4, ctx.S * 0.08)
end

Features.Gills = function(ctx)
	local S = ctx.S
	pair(function(side)
		for i = -1, 1 do
			local base = surface(ctx, Vector3.new(side, 0.5 + i * 0.25, 0), S * 0.03)
			ball(ctx, "Gill", Vector3.new(S * 0.24, S * 0.07, S * 0.07), CFrame.new(base + Vector3.new(side * S * 0.1, i * S * 0.05, 0)) * CFrame.Angles(0, 0, side * math.rad(20 + i * 25)), Color3.fromRGB(255, 100, 150))
		end
	end)
end

Features.Helmet = function(ctx)
	local glass = ball(ctx, "Helmet", Vector3.one * math.max(ctx.W, ctx.H) * 1.25, CFrame.new(0, ctx.CY + ctx.H * 0.05, 0), Color3.fromRGB(180, 225, 255), Enum.Material.Glass)
	glass.Transparency = 0.7
end

Features.Crescent = function(ctx)
	local S = ctx.S
	for i = 0, 6 do
		local angle = math.rad(-60 + i * 20)
		local pos = Vector3.new(math.sin(angle) * S * 0.16, ctx.CY + ctx.H * 0.36 + math.cos(angle) * S * 0.16 - S * 0.1, 0)
		local p = surface(ctx, pos - Vector3.new(0, ctx.CY, 0) + Vector3.new(0, 0, -ctx.D), S * 0.01)
		ball(ctx, "Crescent", Vector3.one * S * (0.06 + math.sin(math.rad(i * 30)) * 0.03), CFrame.new(p), GOLD, Enum.Material.Neon)
	end
end

Models.Features = Features

-- ---------------------------------------------------------------------
-- Cara
-- ---------------------------------------------------------------------
local function face(ctx: Ctx)
	local S = ctx.S
	local e = S * 0.26
	ctx.EyeSize = e
	ctx.Eyes = {}
	for _, side in { -1, 1 } do
		local pos = surface(ctx, Vector3.new(side * 0.36, 0.12, -1), e * 0.3)
		table.insert(ctx.Eyes, pos)
		ball(ctx, "Eye", Vector3.new(e, e * 1.15, e * 0.6), CFrame.new(pos), BLACK)
		ball(ctx, "EyeShine", Vector3.new(e * 0.38, e * 0.38, e * 0.15), CFrame.new(pos + Vector3.new(e * 0.14, e * 0.2, -e * 0.3)), WHITE)
		ball(ctx, "EyeShine2", Vector3.new(e * 0.16, e * 0.16, e * 0.1), CFrame.new(pos + Vector3.new(-e * 0.15, -e * 0.18, -e * 0.3)), WHITE)
	end
	ball(ctx, "Mouth", Vector3.new(S * 0.12, S * 0.06, S * 0.05), CFrame.new(surface(ctx, Vector3.new(0, -0.12, -1), -S * 0.01)), Color3.fromRGB(80, 30, 40))
	if not ctx.Silhouette then
		for _, side in { -1, 1 } do
			local cheek = ball(ctx, "Cheek", Vector3.new(S * 0.14, S * 0.08, S * 0.03), CFrame.new(surface(ctx, Vector3.new(side * 0.6, -0.05, -0.8), S * 0.005)) * CFrame.Angles(0, -side * math.rad(35), 0), PINK)
			cheek.Transparency = 0.3
		end
	end
end

-- ---------------------------------------------------------------------
-- API: criaturas
-- ---------------------------------------------------------------------
local RARITY_SCALE = { Common = 1, Uncommon = 1.06, Rare = 1.12, Epic = 1.2, Legendary = 1.3, Mythic = 1.45, Cosmic = 1.6 }

export type CritterOptions = { Shiny: boolean?, NoEffects: boolean?, Silhouette: boolean?, Scale: number? }

function Models.CritterSize(critterId: string, scale: number?): number
	local def = Critters.Get(critterId) or Critters.List[1]
	return 1.8 * (RARITY_SCALE[def.Rarity] or 1) * (scale or 1)
end

function Models.BuildCritter(critterId: string, options: CritterOptions?): Model
	local opts = options or {}
	local def = Critters.Get(critterId) or Critters.List[1]
	local S = Models.CritterSize(def.Id, opts.Scale)
	local W, H, D = S, S * 0.92, S
	if def.Body == "Bean" then
		W, H, D = S * 0.85, S * 1.15, S * 0.85
	elseif def.Body == "Wide" then
		W, H, D = S * 1.25, S * 0.8, S * 1.05
	end
	local model, root = newModel(def.Name, Vector3.new(S * 0.5, 0.2, S * 0.5))
	model:SetAttribute("CritterId", def.Id)
	model:SetAttribute("Rarity", def.Rarity)
	model:SetAttribute("Shiny", opts.Shiny == true)

	local silhouette = opts.Silhouette == true
	local color = def.Color
	if opts.Shiny then
		local h, s, v = color:ToHSV()
		color = Color3.fromHSV((h + 0.13) % 1, math.min(1, s * 0.85 + 0.15), math.min(1, v * 1.1 + 0.05))
	end
	local ctx: Ctx = {
		Model = model,
		Root = root,
		S = S,
		W = W,
		H = H,
		D = D,
		CY = H / 2 + S * 0.08,
		Color = color,
		Accent = lighter(color, 0.35),
		Silhouette = silhouette,
		Effects = not silhouette and not opts.NoEffects,
		Body = nil,
		Eyes = {},
		EyeSize = 0,
	}

	local body = ball(ctx, "Body", Vector3.new(W, H, D), CFrame.new(0, ctx.CY, 0), color, def.Material)
	if def.Material == Enum.Material.Glass and not silhouette then
		body.Transparency = 0.2
	end
	ctx.Body = body
	if def.Body == "Drop" then
		for i = 1, 3 do
			ball(ctx, "Drop", Vector3.one * S * (0.5 - i * 0.12), CFrame.new(0, ctx.CY + H * 0.38 + i * S * 0.1, S * 0.03 * i), color, def.Material).Transparency = body.Transparency
		end
	end
	if not silhouette then
		ball(ctx, "Belly", Vector3.new(W * 0.55, H * 0.45, D * 0.2), CFrame.new(surface(ctx, Vector3.new(0, -0.45, -1), S * 0.06)), lighter(color, 0.35)).Transparency = body.Transparency
	end
	-- Patitas
	for _, side in { -1, 1 } do
		ball(ctx, "Foot", Vector3.new(S * 0.22, S * 0.12, S * 0.28), CFrame.new(side * W * 0.22, S * 0.08, -D * 0.12), darker(color, 0.15))
	end
	face(ctx)
	for _, feature in def.Features do
		local builder = Features[feature]
		if builder then
			builder(ctx)
		else
			warn("[Models] Rasgo desconocido: " .. feature)
		end
	end

	local rarity = Rarities.Get(def.Rarity)
	if ctx.Effects then
		if rarity.Order >= 5 then
			light(ctx, rarity.Color, S * 3, 1)
		end
		if rarity.Order >= 6 then
			particles(ctx, rarity.Color, WHITE, 4, S * 0.08)
		end
		if opts.Shiny then
			local sparkles = Instance.new("Sparkles")
			sparkles.SparkleColor = Color3.fromRGB(255, 250, 200)
			effect(ctx, sparkles)
		end
	end
	if not silhouette then
		tag(body, "CritterBody")
	end
	model:SetAttribute("Height", ctx.CY + H / 2)
	return model
end

-- ---------------------------------------------------------------------
-- API: huevos
-- ---------------------------------------------------------------------
function Models.BuildEgg(eggIndex: number, scale: number?): Model
	local def = Critters.GetEgg(eggIndex) or Critters.Eggs[1]
	local S = 3 * (scale or 1)
	local model, root = newModel(def.Name, Vector3.new(S * 0.5, 0.2, S * 0.5))
	local ctx: Ctx = {
		Model = model,
		Root = root,
		S = S,
		W = S * 0.82,
		H = S,
		D = S * 0.82,
		CY = S / 2,
		Color = def.Color,
		Accent = def.SpotColor,
		Silhouette = false,
		Effects = true,
		Body = nil,
		Eyes = {},
		EyeSize = 0,
	}
	local body = ball(ctx, "Shell", Vector3.new(ctx.W, ctx.H, ctx.D), CFrame.new(0, ctx.CY, 0), def.Color)
	body.Reflectance = 0.1
	ctx.Body = body
	for _, dir in { Vector3.new(0.4, 0.5, -0.7), Vector3.new(-0.6, 0.1, -0.7), Vector3.new(0.7, -0.3, -0.5), Vector3.new(-0.2, 0.8, -0.5), Vector3.new(0.1, -0.2, -1), Vector3.new(0.8, 0.3, 0.4), Vector3.new(-0.8, -0.2, 0.3), Vector3.new(0, 0.3, 1) } do
		local pos = surface(ctx, dir, S * 0.015)
		ball(ctx, "Spot", Vector3.new(S * 0.16, S * 0.16, S * 0.03), CFrame.lookAt(pos, pos + dir), def.SpotColor, if eggIndex >= 4 then Enum.Material.Neon else Enum.Material.SmoothPlastic)
	end
	if eggIndex >= 5 then
		particles(ctx, def.SpotColor, WHITE, 3, S * 0.06)
	end
	tag(body, "EggBody")
	return model
end

-- ---------------------------------------------------------------------
-- API: meteoritos
-- ---------------------------------------------------------------------
export type MeteorOptions = { Comet: boolean? }

function Models.BuildMeteor(rarityName: string, zoneIndex: number, options: MeteorOptions?): Model
	local opts = options or {}
	local rarity = Rarities.Get(rarityName)
	local zone = Zones.Get(zoneIndex)
	local R = if opts.Comet then 13 else rarity.Size
	local model, root = newModel(if opts.Comet then "Comet" else rarity.Name .. " Meteor", Vector3.new(R, 0.2, R))
	local glowColor = if opts.Comet then Color3.fromRGB(140, 230, 255) else rarity.Color
	local rockColor = if opts.Comet then Color3.fromRGB(40, 45, 70) else zone.RockColor:Lerp(rarity.Color, 0.12)
	local ctx: Ctx = {
		Model = model,
		Root = root,
		S = R * 2,
		W = R * 2,
		H = R * 1.6,
		D = R * 2,
		CY = R * 0.65,
		Color = rockColor,
		Accent = glowColor,
		Silhouette = false,
		Effects = true,
		Body = nil,
		Eyes = {},
		EyeSize = 0,
	}
	-- Cráter
	cylinder(ctx, "Crater", 0.3, R * 3.6, CFrame.new(0, 0.12, 0), darker(zone.GroundColor, 0.45))
	cylinder(ctx, "CraterRim", 0.5, R * 2.8, CFrame.new(0, 0.2, 0), darker(zone.GroundColor, 0.25))
	-- Roca principal + bultos
	local body = ball(ctx, "Rock", Vector3.new(ctx.W, ctx.H, ctx.D), CFrame.new(0, ctx.CY, 0), rockColor, Enum.Material.Slate)
	ctx.Body = body
	local seed = Random.new(rarity.Order * 97 + zoneIndex * 13 + (if opts.Comet then 7 else 0))
	for _ = 1, 6 do
		local dir = Vector3.new(seed:NextNumber(-1, 1), seed:NextNumber(-0.1, 1), seed:NextNumber(-1, 1))
		if dir.Magnitude < 0.1 then
			dir = Vector3.new(0, 1, 0)
		end
		local size = R * seed:NextNumber(0.6, 1.0)
		ball(ctx, "Lump", Vector3.new(size, size * 0.8, size), CFrame.new(surface(ctx, dir, size * 0.35)), darker(rockColor, seed:NextNumber(0, 0.2)), Enum.Material.Slate)
	end
	-- Cristales brillantes
	local crystalCount = if opts.Comet then 16 else 4 + rarity.Order
	for i = 1, crystalCount do
		local dir = Vector3.new(seed:NextNumber(-1, 1), seed:NextNumber(0.15, 1), seed:NextNumber(-1, 1))
		local base = surface(ctx, dir, R * 0.15)
		local length = R * seed:NextNumber(0.55, 1.05)
		local width = R * seed:NextNumber(0.24, 0.36)
		local crystal = blockBetween(ctx, "Crystal", base, base + dir.Unit * length, width, width, glowColor, Enum.Material.Neon)
		if rarity.Animated or opts.Comet then
			tag(crystal, "RainbowPart")
		end
		local _ = i
	end
	-- Haz de luz para verlo de lejos
	local beam = cylinder(ctx, "LightPillar", 90, if rarity.Order >= 3 or opts.Comet then 1.4 else 0.7, CFrame.new(0, 45, 0), glowColor, Enum.Material.Neon)
	beam.Transparency = if rarity.Order >= 3 or opts.Comet then 0.45 else 0.75
	light(ctx, glowColor, R * 4, if rarity.Order >= 4 or opts.Comet then 2 else 1)
	if rarity.Order >= 4 or opts.Comet then
		particles(ctx, glowColor, Color3.fromRGB(255, 160, 60), if opts.Comet then 20 else 6, R * 0.2)
	end
	model:SetAttribute("Radius", R)
	model:SetAttribute("Rarity", rarity.Name)
	return model
end

-- Bola de fuego que cae (la usa el cliente para la animación del impacto)
function Models.BuildFireball(rarityName: string, comet: boolean?): Model
	local rarity = Rarities.Get(rarityName)
	local R = if comet then 10 else rarity.Size * 0.8
	local model, root = newModel("Fireball", Vector3.new(1, 1, 1))
	local ctx: Ctx = {
		Model = model,
		Root = root,
		S = R * 2,
		W = R * 2,
		H = R * 2,
		D = R * 2,
		CY = 0,
		Color = rarity.Color,
		Accent = rarity.Color,
		Silhouette = false,
		Effects = true,
		Body = nil,
		Eyes = {},
		EyeSize = 0,
	}
	local core = ball(ctx, "Core", Vector3.one * R * 2, CFrame.new(), Color3.fromRGB(255, 200, 120), Enum.Material.Neon)
	ctx.Body = core
	local glow = ball(ctx, "Glow", Vector3.one * R * 2.8, CFrame.new(), if comet then Color3.fromRGB(140, 230, 255) else rarity.Color, Enum.Material.Neon)
	glow.Transparency = 0.6
	local fire = Instance.new("Fire")
	fire.Size = math.clamp(R * 2, 2, 30)
	fire.Heat = 20
	fire.Color = Color3.fromRGB(255, 140, 40)
	fire.SecondaryColor = if comet then Color3.fromRGB(140, 230, 255) else rarity.Color
	fire.Parent = core
	light(ctx, rarity.Color, R * 6, 3)
	return model
end

return Models
