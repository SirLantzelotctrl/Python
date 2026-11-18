-- Construye los modelos 3D de los slimes con piezas básicas (no necesita assets).
-- El modelo se construye en el origen: Root = punto en el suelo, el frente mira a -Z.

local CollectionService = game:GetService("CollectionService")

local Slimes = require(script.Parent.Slimes)
local Rarities = require(script.Parent.Rarities)
local Mutations = require(script.Parent.Mutations)
local Format = require(script.Parent.Format)

local SlimeBuilder = {}

local BASE_SIZE = 3.2
local WHITE = Color3.fromRGB(255, 255, 255)
local BLACK = Color3.fromRGB(20, 20, 25)
local GOLD = Color3.fromRGB(255, 200, 45)
local SILHOUETTE = Color3.fromRGB(18, 18, 28)

export type BuildOptions = {
	NoEffects: boolean?,
	Silhouette: boolean?,
	Scale: number?,
}

type Ctx = {
	Model: Model,
	Root: BasePart,
	Def: any,
	S: number,
	H: number,
	A: number,
	B: number,
	Silhouette: boolean,
	Effects: boolean,
	BodyColor: Color3,
	Body: BasePart?,
	Eyes: { Vector3 },
	EyeSize: number,
}

-- ---------------------------------------------------------------------
-- Helpers de geometría
-- ---------------------------------------------------------------------
local function preparePart(ctx: Ctx, part: BasePart, name: string, color: Color3, material: Enum.Material?)
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

-- Elipsoide (Part + SpecialMesh esfera)
local function ball(ctx: Ctx, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = cframe
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	preparePart(ctx, part, name, color, material)
	return part
end

local function block(ctx: Ctx, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = cframe
	preparePart(ctx, part, name, color, material)
	return part
end

-- CFrame cuyo eje Y apunta en "dir"
local function alongDir(center: Vector3, dir: Vector3): CFrame
	if math.abs(dir.Unit.Y) > 0.999 then
		if dir.Y > 0 then
			return CFrame.new(center)
		end
		return CFrame.new(center) * CFrame.Angles(math.pi, 0, 0)
	end
	return CFrame.lookAt(center, center + dir) * CFrame.Angles(-math.pi / 2, 0, 0)
end

-- Cilindro cuyo eje es el eje Y del cframe dado
local function cylinder(ctx: Ctx, name: string, height: number, diameter: number, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(height, diameter, diameter)
	part.CFrame = cframe * CFrame.Angles(0, 0, math.pi / 2)
	preparePart(ctx, part, name, color, material)
	return part
end

local function cylBetween(ctx: Ctx, name: string, p0: Vector3, p1: Vector3, diameter: number, color: Color3, material: Enum.Material?): Part
	local delta = p1 - p0
	return cylinder(ctx, name, delta.Magnitude, diameter, alongDir((p0 + p1) / 2, delta), color, material)
end

local function blockBetween(ctx: Ctx, name: string, p0: Vector3, p1: Vector3, width: number, depth: number, color: Color3, material: Enum.Material?): Part
	local delta = p1 - p0
	return block(ctx, name, Vector3.new(width, delta.Magnitude, depth), alongDir((p0 + p1) / 2, delta), color, material)
end

-- Punto en la superficie frontal del cuerpo (xf, yf en fracciones de los radios)
local function front(ctx: Ctx, xf: number, yf: number, inset: number?): Vector3
	local inside = 1 - xf * xf - yf * yf
	local zf = if inside > 0 then math.sqrt(inside) else 0
	return Vector3.new(xf * ctx.A, ctx.B + yf * ctx.B, -zf * ctx.A + (inset or 0))
end

-- Punto en la parte superior del cuerpo (xf, zf en fracciones del radio horizontal)
local function top(ctx: Ctx, xf: number, zf: number, lift: number?): Vector3
	local inside = 1 - xf * xf - zf * zf
	local yf = if inside > 0 then math.sqrt(inside) else 0
	return Vector3.new(xf * ctx.A, ctx.B + yf * ctx.B + (lift or 0), zf * ctx.A)
end

local function addEffect(ctx: Ctx, instance: Instance, parent: Instance?)
	if not ctx.Effects then
		instance:Destroy()
		return
	end
	instance.Parent = parent or ctx.Body or ctx.Root
end

local function particles(ctx: Ctx, colors: { Color3 }, rate: number, size: number, lightEmission: number?)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Particles"
	if #colors == 1 then
		emitter.Color = ColorSequence.new(colors[1])
	else
		emitter.Color = ColorSequence.new(colors[1], colors[2])
	end
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new(0.1)
	emitter.Lifetime = NumberRange.new(0.9, 1.6)
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(1, 2.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = lightEmission or 0.7
	emitter.Drag = 1
	addEffect(ctx, emitter)
end

local function light(ctx: Ctx, color: Color3, range: number, brightness: number)
	local pointLight = Instance.new("PointLight")
	pointLight.Color = color
	pointLight.Range = range
	pointLight.Brightness = brightness
	pointLight.Shadows = false
	addEffect(ctx, pointLight)
end

local function tag(instance: Instance, tagName: string)
	CollectionService:AddTag(instance, tagName)
end

local function darker(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

local function crown(ctx: Ctx, bandColor: Color3, jewelColor: Color3, material: Enum.Material)
	local S, H = ctx.S, ctx.H
	local y = H * 0.97
	cylinder(ctx, "CrownBand", S * 0.16, S * 0.5, CFrame.new(0, y, 0), bandColor, material)
	for i = 0, 4 do
		local angle = math.rad(i * 72 + 90)
		local pos = Vector3.new(math.cos(angle) * S * 0.22, y + S * 0.12, math.sin(angle) * S * 0.22)
		block(ctx, "CrownSpike", Vector3.new(S * 0.08, S * 0.16, S * 0.08), CFrame.new(pos) * CFrame.Angles(0, -angle, math.rad(45)), bandColor, material)
		ball(ctx, "CrownJewel", Vector3.one * S * 0.07, CFrame.new(Vector3.new(math.cos(angle) * S * 0.255, y, math.sin(angle) * S * 0.255)), jewelColor, Enum.Material.Neon)
	end
end

local function ring(ctx: Ctx, name: string, y: number, yf: number, height: number, color: Color3, material: Enum.Material?)
	-- Anillo que rodea el cuerpo a la altura relativa yf
	local radius = ctx.A * math.sqrt(math.max(0, 1 - yf * yf))
	return cylinder(ctx, name, height, radius * 2 * 1.04, CFrame.new(0, y, 0), color, material)
end

local function wings(ctx: Ctx, size: Vector3, color: Color3, material: Enum.Material?)
	local S, H = ctx.S, ctx.H
	for _, side in { -1, 1 } do
		-- Alas hacia arriba, hacia fuera y ligeramente hacia atrás
		local cf = CFrame.new(side * S * 0.5, H * 0.72, S * 0.32) * CFrame.Angles(0, side * math.rad(-30), side * math.rad(28))
		ball(ctx, "Wing", size, cf, color, material)
		ball(ctx, "WingTip", size * Vector3.new(0.6, 0.6, 1.1), cf * CFrame.new(side * size.X * 0.32, size.Y * 0.25, 0), color, material)
	end
end

-- ---------------------------------------------------------------------
-- Accesorios
-- ---------------------------------------------------------------------
local Accessories: { [string]: (Ctx) -> () } = {}

Accessories.Bow = function(ctx)
	local S, H = ctx.S, ctx.H
	local color = Color3.fromRGB(255, 85, 160)
	local base = CFrame.new(S * 0.2, H * 0.93, -S * 0.05) * CFrame.Angles(0, 0, math.rad(-20))
	ball(ctx, "BowL", Vector3.new(S * 0.22, S * 0.16, S * 0.08), base * CFrame.new(-S * 0.1, 0, 0) * CFrame.Angles(0, 0, math.rad(20)), color)
	ball(ctx, "BowR", Vector3.new(S * 0.22, S * 0.16, S * 0.08), base * CFrame.new(S * 0.1, 0, 0) * CFrame.Angles(0, 0, math.rad(-20)), color)
	ball(ctx, "BowKnot", Vector3.one * S * 0.09, base, darker(color, 0.15))
end

Accessories.Cap = function(ctx)
	local S, H = ctx.S, ctx.H
	local color = Color3.fromRGB(220, 40, 50)
	ball(ctx, "CapDome", Vector3.new(S * 0.66, S * 0.34, S * 0.66), CFrame.new(0, H * 0.9, S * 0.02), color)
	ball(ctx, "CapBrim", Vector3.new(S * 0.44, S * 0.05, S * 0.36), CFrame.new(0, H * 0.88, -S * 0.3) * CFrame.Angles(math.rad(-8), 0, 0), color)
	ball(ctx, "CapButton", Vector3.one * S * 0.07, CFrame.new(0, H * 0.9 + S * 0.17, S * 0.02), WHITE)
end

Accessories.Moss = function(ctx)
	local S = ctx.S
	local color = Color3.fromRGB(55, 105, 35)
	for _, p in { { -0.4, 0.1 }, { 0.3, 0.35 }, { 0.05, 0.55 }, { -0.25, -0.35 }, { 0.5, -0.1 } } do
		local pos = top(ctx, p[1], p[2])
		ball(ctx, "Moss", Vector3.new(S * 0.24, S * 0.07, S * 0.2), CFrame.new(pos) * CFrame.Angles(p[2] * 0.8, 0, -p[1] * 0.8), color, Enum.Material.Grass)
	end
end

Accessories.Sprout = function(ctx)
	local S, H = ctx.S, ctx.H
	local green = Color3.fromRGB(70, 200, 70)
	local stemTop = Vector3.new(0, H + S * 0.22, 0)
	cylBetween(ctx, "Stem", Vector3.new(0, H * 0.95, 0), stemTop, S * 0.05, green)
	for _, side in { -1, 1 } do
		ball(ctx, "Leaf", Vector3.new(S * 0.22, S * 0.05, S * 0.12), CFrame.new(stemTop + Vector3.new(side * S * 0.1, S * 0.02, 0)) * CFrame.Angles(0, 0, side * math.rad(25)), green)
	end
end

Accessories.Bubbles = function(ctx)
	local S, H = ctx.S, ctx.H
	for index, p in { { -0.62, 0.35, -0.1, 0.18 }, { 0.6, 0.6, 0.1, 0.14 }, { -0.45, 1.05, 0.2, 0.12 }, { 0.4, 1.12, -0.15, 0.2 }, { 0.05, 1.3, 0.1, 0.1 } } do
		local bubble = ball(ctx, "Bubble" .. index, Vector3.one * S * p[4], CFrame.new(p[1] * S, p[2] * H, p[3] * S), Color3.fromRGB(190, 240, 255), Enum.Material.Glass)
		bubble.Transparency = 0.45
	end
end

Accessories.MintLeaf = function(ctx)
	local S, H = ctx.S, ctx.H
	local green = Color3.fromRGB(50, 190, 100)
	cylBetween(ctx, "Stem", Vector3.new(0, H * 0.95, 0), Vector3.new(0, H + S * 0.12, 0), S * 0.05, darker(green, 0.2))
	ball(ctx, "MintLeaf", Vector3.new(S * 0.42, S * 0.05, S * 0.2), CFrame.new(S * 0.16, H + S * 0.15, 0) * CFrame.Angles(0, math.rad(15), math.rad(20)), green)
	ball(ctx, "MintLeaf2", Vector3.new(S * 0.32, S * 0.05, S * 0.16), CFrame.new(-S * 0.13, H + S * 0.12, 0) * CFrame.Angles(0, math.rad(-15), math.rad(-20)), green)
end

Accessories.Pebbles = function(ctx)
	local S = ctx.S
	local color = Color3.fromRGB(120, 115, 110)
	for _, p in { { -0.3, 0.1, 0.16 }, { 0.2, -0.15, 0.13 }, { 0.05, 0.35, 0.11 }, { 0.4, 0.2, 0.1 }, { -0.1, -0.4, 0.12 } } do
		ball(ctx, "Pebble", Vector3.new(S * p[3], S * p[3] * 0.8, S * p[3]), CFrame.new(top(ctx, p[1], p[2])), color, Enum.Material.Slate)
	end
end

Accessories.IceCrystals = function(ctx)
	local S = ctx.S
	local color = Color3.fromRGB(170, 235, 255)
	for _, p in { { 0, 0, 0.42 }, { -0.3, 0.05, 0.32 }, { 0.3, -0.05, 0.34 }, { 0.05, 0.35, 0.28 }, { -0.1, -0.35, 0.26 } } do
		local base = top(ctx, p[1], p[2], -S * 0.05)
		local dir = Vector3.new(p[1] * 0.8, 1, p[2] * 0.8).Unit
		local crystal = blockBetween(ctx, "Crystal", base, base + dir * S * p[3], S * 0.09, S * 0.09, color, Enum.Material.Glass)
		crystal.Transparency = 0.15
	end
end

Accessories.Flame = function(ctx)
	local S, H = ctx.S, ctx.H
	ball(ctx, "FlameOuter", Vector3.new(S * 0.32, S * 0.4, S * 0.32), CFrame.new(0, H + S * 0.08, 0), Color3.fromRGB(255, 110, 20), Enum.Material.Neon)
	ball(ctx, "FlameInner", Vector3.new(S * 0.18, S * 0.28, S * 0.18), CFrame.new(0, H + S * 0.14, -S * 0.04), Color3.fromRGB(255, 230, 80), Enum.Material.Neon)
	local fire = Instance.new("Fire")
	fire.Size = math.clamp(S * 0.9, 2, 10)
	fire.Heat = 6
	fire.Color = Color3.fromRGB(255, 120, 20)
	fire.SecondaryColor = Color3.fromRGB(255, 220, 60)
	addEffect(ctx, fire)
end

Accessories.Antennae = function(ctx)
	local S, H = ctx.S, ctx.H
	local tipColor = Rarities.Get(ctx.Def.Rarity).Color
	for _, side in { -1, 1 } do
		local base = top(ctx, side * 0.22, 0, -S * 0.03)
		local tip = base + Vector3.new(side * math.sin(math.rad(22)), math.cos(math.rad(22)), 0) * S * 0.42
		cylBetween(ctx, "Antenna", base, tip, S * 0.045, BLACK)
		ball(ctx, "AntennaTip", Vector3.one * S * 0.13, CFrame.new(tip), tipColor, Enum.Material.Neon)
	end
	local _ = H
end

Accessories.Sparkle = function(ctx)
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Rarities.Get(ctx.Def.Rarity).Color
	addEffect(ctx, sparkles)
end

Accessories.KnightHelmet = function(ctx)
	local S, H = ctx.S, ctx.H
	local steel = Color3.fromRGB(150, 155, 170)
	ball(ctx, "Helmet", Vector3.new(S * 0.86, H * 0.46, S * 0.86), CFrame.new(0, H * 0.86, 0), steel, Enum.Material.Metal)
	block(ctx, "NoseGuard", Vector3.new(S * 0.06, H * 0.26, S * 0.05), CFrame.new(front(ctx, 0, 0.3, -S * 0.02)), steel, Enum.Material.Metal)
	local plumeColor = Color3.fromRGB(220, 30, 40)
	for i = 0, 2 do
		ball(ctx, "Plume", Vector3.new(S * 0.14, S * 0.2, S * 0.24), CFrame.new(0, H * 1.06 + i * S * 0.06, S * (0.05 + i * 0.1)), plumeColor)
	end
end

Accessories.Headband = function(ctx)
	local S, H = ctx.S, ctx.H
	local red = Color3.fromRGB(220, 30, 40)
	ring(ctx, "Headband", H * 0.76, 0.52, S * 0.11, red)
	for _, side in { -1, 1 } do
		local base = Vector3.new(side * S * 0.08, H * 0.76, S * 0.44)
		blockBetween(ctx, "BandTail", base, base + Vector3.new(side * S * 0.18, -S * 0.22, S * 0.12), S * 0.07, S * 0.03, red)
	end
end

Accessories.Shades = function(ctx)
	local S = ctx.S
	local e = ctx.EyeSize
	for index, eye in ctx.Eyes do
		local lens = block(ctx, "Lens" .. index, Vector3.new(e * 1.35, e * 0.85, S * 0.04), CFrame.new(eye + Vector3.new(0, 0, -e * 0.6)), BLACK, Enum.Material.Glass)
		lens.Reflectance = 0.35
	end
	local mid = (ctx.Eyes[1] + ctx.Eyes[2]) / 2
	block(ctx, "Bridge", Vector3.new(S * 0.62, S * 0.05, S * 0.04), CFrame.new(mid + Vector3.new(0, e * 0.3, -e * 0.62)), BLACK)
end

Accessories.PirateHat = function(ctx)
	local S, H = ctx.S, ctx.H
	ball(ctx, "PirateHat", Vector3.new(S * 0.95, S * 0.32, S * 0.62), CFrame.new(0, H * 0.96, 0), Color3.fromRGB(25, 25, 30))
	block(ctx, "HatTrim", Vector3.new(S * 0.9, S * 0.04, S * 0.05), CFrame.new(0, H * 0.94, -S * 0.27), GOLD, Enum.Material.Metal)
	ball(ctx, "Skull", Vector3.new(S * 0.13, S * 0.13, S * 0.06), CFrame.new(0, H * 1.0, -S * 0.3), WHITE)
end

Accessories.EyePatch = function(ctx)
	local S = ctx.S
	local e = ctx.EyeSize
	local eye = ctx.Eyes[2]
	ball(ctx, "EyePatch", Vector3.new(e * 1.25, e * 1.2, S * 0.05), CFrame.new(eye + Vector3.new(0, 0, -e * 0.56)), BLACK)
	block(ctx, "PatchStrap", Vector3.new(S * 0.75, S * 0.035, S * 0.03), CFrame.new(eye + Vector3.new(-S * 0.18, e * 0.5, -e * 0.4)) * CFrame.Angles(0, 0, math.rad(-22)), BLACK)
end

Accessories.WitchHat = function(ctx)
	local S, H = ctx.S, ctx.H
	local purple = Color3.fromRGB(65, 30, 95)
	cylinder(ctx, "Brim", S * 0.04, S * 1.0, CFrame.new(0, H * 0.94, 0), purple)
	cylinder(ctx, "HatBand", S * 0.07, S * 0.58, CFrame.new(0, H * 0.94 + S * 0.05, 0), GOLD, Enum.Material.Metal)
	local diameters = { 0.55, 0.43, 0.32, 0.22, 0.13 }
	for i, diameter in diameters do
		cylinder(ctx, "HatTier", S * 0.15, S * diameter, CFrame.new(S * 0.02 * i, H * 0.94 + S * (0.08 + i * 0.13), 0), purple)
	end
end

Accessories.Crown = function(ctx)
	crown(ctx, GOLD, Color3.fromRGB(255, 40, 60), Enum.Material.Metal)
end

Accessories.DarkCrown = function(ctx)
	crown(ctx, Color3.fromRGB(25, 20, 35), Color3.fromRGB(180, 60, 255), Enum.Material.Metal)
end

Accessories.Cape = function(ctx)
	local S, H = ctx.S, ctx.H
	ball(ctx, "Cape", Vector3.new(S * 0.95, H * 0.85, S * 0.08), CFrame.new(0, H * 0.45, S * 0.47) * CFrame.Angles(math.rad(-8), 0, 0), Color3.fromRGB(170, 20, 40))
	ball(ctx, "CapeFur", Vector3.new(S * 0.8, S * 0.1, S * 0.14), CFrame.new(0, H * 0.84, S * 0.38), WHITE)
end

Accessories.Mustache = function(ctx)
	local S = ctx.S
	local brown = Color3.fromRGB(70, 40, 20)
	for _, side in { -1, 1 } do
		ball(ctx, "Mustache", Vector3.new(S * 0.2, S * 0.07, S * 0.05), CFrame.new(front(ctx, side * 0.1, -0.02, -S * 0.005)) * CFrame.Angles(0, -side * math.rad(12), side * math.rad(12)), brown)
	end
end

Accessories.Horns = function(ctx)
	local S = ctx.S
	local ivory = Color3.fromRGB(245, 235, 210)
	for _, side in { -1, 1 } do
		local base = top(ctx, side * 0.32, 0.05, -S * 0.04)
		local mid = base + Vector3.new(side * 0.45, 0.9, 0.1).Unit * S * 0.18
		local tip = mid + Vector3.new(side * 0.15, 0.6, 0.45).Unit * S * 0.14
		cylBetween(ctx, "Horn", base, mid, S * 0.13, ivory)
		cylBetween(ctx, "HornUpper", mid, tip, S * 0.09, ivory)
		ball(ctx, "HornJoint", Vector3.one * S * 0.12, CFrame.new(mid), ivory)
		ball(ctx, "HornTip", Vector3.one * S * 0.08, CFrame.new(tip), Color3.fromRGB(215, 200, 170))
	end
end

Accessories.Spikes = function(ctx)
	local S = ctx.S
	local color = darker(ctx.BodyColor, 0.35)
	for _, zf in { 0.05, 0.4, 0.72 } do
		local pos = top(ctx, 0, zf, S * 0.02)
		block(ctx, "Spike", Vector3.new(S * 0.05, S * 0.17, S * 0.17), CFrame.new(pos) * CFrame.Angles(math.rad(45), 0, 0), color)
	end
end

Accessories.SmallWings = function(ctx)
	wings(ctx, Vector3.new(ctx.S * 0.36, ctx.S * 0.22, ctx.S * 0.05), darker(ctx.BodyColor, 0.25))
end

Accessories.Wings = function(ctx)
	local color = WHITE
	local material = Enum.Material.SmoothPlastic
	if table.find(ctx.Def.Accessories, "Flame") then
		color = Color3.fromRGB(255, 150, 40)
		material = Enum.Material.Neon
	end
	wings(ctx, Vector3.new(ctx.S * 0.72, ctx.S * 0.36, ctx.S * 0.06), color, material)
end

Accessories.AstroHelmet = function(ctx)
	local S, H = ctx.S, ctx.H
	local glass = ball(ctx, "AstroGlass", Vector3.one * S * 1.22, CFrame.new(0, H * 0.55, 0), Color3.fromRGB(170, 220, 255), Enum.Material.Glass)
	glass.Transparency = 0.7
	cylinder(ctx, "AstroCollar", S * 0.14, S * 1.08, CFrame.new(0, S * 0.07, 0), Color3.fromRGB(230, 230, 240), Enum.Material.Metal)
end

Accessories.SamuraiHelmet = function(ctx)
	local S, H = ctx.S, ctx.H
	local red = Color3.fromRGB(150, 20, 30)
	ball(ctx, "Kabuto", Vector3.new(S * 0.9, H * 0.42, S * 0.9), CFrame.new(0, H * 0.86, 0), red, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		local base = Vector3.new(side * S * 0.04, H * 1.0, -S * 0.22)
		blockBetween(ctx, "Crest", base, base + Vector3.new(side * S * 0.2, S * 0.38, -S * 0.04), S * 0.05, S * 0.02, GOLD, Enum.Material.Metal)
		blockBetween(ctx, "Flap", Vector3.new(side * S * 0.38, H * 0.8, S * 0.05), Vector3.new(side * S * 0.52, H * 0.55, S * 0.1), S * 0.06, S * 0.3, red, Enum.Material.Metal)
	end
	ball(ctx, "CrestBase", Vector3.one * S * 0.1, CFrame.new(0, H * 0.98, -S * 0.24), GOLD, Enum.Material.Metal)
end

Accessories.Visor = function(ctx)
	local S = ctx.S
	local e = ctx.EyeSize
	local mid = (ctx.Eyes[1] + ctx.Eyes[2]) / 2
	block(ctx, "Visor", Vector3.new(S * 0.78, e * 0.75, S * 0.06), CFrame.new(mid + Vector3.new(0, 0, -e * 0.62)), Color3.fromRGB(0, 255, 255), Enum.Material.Neon)
	block(ctx, "VisorFrame", Vector3.new(S * 0.84, e * 0.95, S * 0.04), CFrame.new(mid + Vector3.new(0, 0, -e * 0.5)), BLACK, Enum.Material.Metal)
end

Accessories.Tentacles = function(ctx)
	local S = ctx.S
	local color = darker(ctx.BodyColor, 0.15)
	for i = 0, 5 do
		local angle = math.rad(i * 60 + 30)
		local dir = Vector3.new(math.cos(angle), -0.25, math.sin(angle)).Unit
		local base = Vector3.new(math.cos(angle) * S * 0.32, S * 0.18, math.sin(angle) * S * 0.32)
		local tip = base + dir * S * 0.5
		cylBetween(ctx, "Tentacle", base, tip, S * 0.12, color)
		ball(ctx, "TentacleTip", Vector3.one * S * 0.12, CFrame.new(tip + Vector3.new(0, S * 0.03, 0)), color)
	end
end

Accessories.Nemes = function(ctx)
	local S, H = ctx.S, ctx.H
	local blue = Color3.fromRGB(30, 60, 170)
	ring(ctx, "NemesBand", H * 0.78, 0.55, S * 0.12, GOLD, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		block(ctx, "NemesFlap", Vector3.new(S * 0.08, H * 0.6, S * 0.32), CFrame.new(side * S * 0.48, H * 0.5, S * 0.06) * CFrame.Angles(0, 0, side * math.rad(8)), blue)
		block(ctx, "NemesStripe", Vector3.new(S * 0.085, H * 0.08, S * 0.33), CFrame.new(side * S * 0.48, H * 0.55, S * 0.06) * CFrame.Angles(0, 0, side * math.rad(8)), GOLD, Enum.Material.Metal)
	end
	ball(ctx, "Cobra", Vector3.new(S * 0.1, S * 0.16, S * 0.08), CFrame.new(front(ctx, 0, 0.58, -S * 0.04)), GOLD, Enum.Material.Metal)
end

Accessories.Halo = function(ctx)
	local S, H = ctx.S, ctx.H
	local y = H + S * 0.3
	local count = 14
	for i = 0, count - 1 do
		local angle = math.rad(i * (360 / count))
		ball(ctx, "Halo", Vector3.one * S * 0.1, CFrame.new(math.cos(angle) * S * 0.3, y, math.sin(angle) * S * 0.3), Color3.fromRGB(255, 235, 120), Enum.Material.Neon)
	end
end

Accessories.Lightning = function(ctx)
	local S, H = ctx.S, ctx.H
	local yellow = Color3.fromRGB(255, 240, 60)
	local points = {
		Vector3.new(0, H * 0.98, 0),
		Vector3.new(S * 0.14, H + S * 0.22, 0),
		Vector3.new(-S * 0.06, H + S * 0.36, 0),
		Vector3.new(S * 0.12, H + S * 0.62, 0),
	}
	for i = 1, #points - 1 do
		blockBetween(ctx, "Bolt", points[i], points[i + 1], S * 0.09, S * 0.05, yellow, Enum.Material.Neon)
	end
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = yellow
	addEffect(ctx, sparkles)
end

Accessories.StarCrown = function(ctx)
	local S, H = ctx.S, ctx.H
	local y = H * 1.0
	for i = 0, 6 do
		local angle = math.rad(i * (360 / 7))
		local color = if i % 2 == 0 then Color3.fromRGB(255, 240, 120) else Color3.fromRGB(255, 140, 230)
		ball(ctx, "Star", Vector3.one * S * 0.12, CFrame.new(math.cos(angle) * S * 0.26, y + S * 0.08, math.sin(angle) * S * 0.26), color, Enum.Material.Neon)
	end
	ball(ctx, "StarCenter", Vector3.one * S * 0.2, CFrame.new(0, y + S * 0.18, 0), Color3.fromRGB(255, 250, 200), Enum.Material.Neon)
end

Accessories.Stars = function(ctx)
	particles(ctx, { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 200, 255) }, 6, ctx.S * 0.08, 1)
end

Accessories.Clock = function(ctx)
	local S, H = ctx.S, ctx.H
	local center = Vector3.new(0, H + S * 0.38, S * 0.12)
	cylBetween(ctx, "ClockRim", center + Vector3.new(0, 0, S * 0.04), center - Vector3.new(0, 0, S * 0.03), S * 0.62, GOLD, Enum.Material.Metal)
	cylBetween(ctx, "ClockFace", center - Vector3.new(0, 0, S * 0.03), center - Vector3.new(0, 0, S * 0.05), S * 0.52, Color3.fromRGB(250, 245, 230))
	local handZ = center.Z - S * 0.065
	block(ctx, "HourHand", Vector3.new(S * 0.03, S * 0.14, S * 0.02), CFrame.new(center.X, center.Y + S * 0.06, handZ), BLACK)
	block(ctx, "MinuteHand", Vector3.new(S * 0.2, S * 0.025, S * 0.02), CFrame.new(center.X + S * 0.09, center.Y, handZ), BLACK)
	block(ctx, "ClockStand", Vector3.new(S * 0.06, S * 0.16, S * 0.06), CFrame.new(0, H + S * 0.02, S * 0.12), GOLD, Enum.Material.Metal)
end

Accessories.GlitchCubes = function(ctx)
	local S, H = ctx.S, ctx.H
	local spots = {
		{ -0.62, 0.3, -0.1, 0.16 },
		{ 0.6, 0.5, 0.15, 0.12 },
		{ -0.4, 1.05, 0.2, 0.1 },
		{ 0.35, 1.1, -0.25, 0.14 },
		{ 0.1, 0.15, -0.55, 0.1 },
		{ -0.2, 0.7, 0.55, 0.12 },
		{ 0.55, 0.95, 0.35, 0.09 },
		{ -0.55, 0.65, -0.4, 0.11 },
	}
	for index, p in spots do
		local color = if index % 2 == 0 then Color3.fromRGB(255, 0, 200) else Color3.fromRGB(0, 255, 150)
		local cube = block(ctx, "Glitch", Vector3.one * S * p[4], CFrame.new(p[1] * S, p[2] * H, p[3] * S) * CFrame.Angles(index, index * 2, 0), color, Enum.Material.Neon)
		if not ctx.Silhouette then
			tag(cube, "GlitchPart")
		end
	end
end

Accessories.Aura = function(ctx)
	local h, _, v = ctx.BodyColor:ToHSV()
	local auraColor = if v < 0.35 then Color3.fromRGB(170, 70, 255) else Color3.fromRGB(255, 230, 140)
	particles(ctx, { auraColor, WHITE }, 10, ctx.S * 0.18, 0.9)
	light(ctx, auraColor, ctx.S * 3, 2)
	local _ = h
end

Accessories.Rings = function(ctx)
	local S, H = ctx.S, ctx.H
	local cf = CFrame.new(0, H * 0.5, 0) * CFrame.Angles(math.rad(18), 0, math.rad(8))
	local outer = cylinder(ctx, "PlanetRing", S * 0.03, S * 1.75, cf, Color3.fromRGB(255, 210, 140), Enum.Material.Neon)
	outer.Transparency = 0.35
	local inner = cylinder(ctx, "PlanetRing2", S * 0.035, S * 1.45, cf, Color3.fromRGB(200, 140, 255), Enum.Material.Neon)
	inner.Transparency = 0.3
end

SlimeBuilder.Accessories = Accessories

-- ---------------------------------------------------------------------
-- Cara
-- ---------------------------------------------------------------------
local function buildFace(ctx: Ctx, eyeScale: number)
	local S = ctx.S
	local e = S * 0.2 * eyeScale
	ctx.EyeSize = e
	ctx.Eyes = {}
	for _, side in { -1, 1 } do
		local pos = front(ctx, 0.3 * side * math.min(eyeScale, 1.2), 0.18, e * 0.3)
		table.insert(ctx.Eyes, pos)
		ball(ctx, "Eye", Vector3.new(e, e * 1.1, e * 0.7), CFrame.new(pos), WHITE)
		ball(ctx, "Pupil", Vector3.new(e * 0.55, e * 0.62, e * 0.4), CFrame.new(pos + Vector3.new(0, -e * 0.05, -e * 0.28)), BLACK)
		ball(ctx, "EyeShine", Vector3.new(e * 0.2, e * 0.2, e * 0.12), CFrame.new(pos + Vector3.new(e * 0.12, e * 0.12, -e * 0.45)), WHITE)
	end
	ball(ctx, "Mouth", Vector3.new(S * 0.2, S * 0.08, S * 0.06), CFrame.new(front(ctx, 0, -0.14, S * 0.012)), Color3.fromRGB(70, 20, 35))
	if not ctx.Silhouette then
		for _, side in { -1, 1 } do
			local cheek = ball(ctx, "Cheek", Vector3.new(S * 0.13, S * 0.07, S * 0.03), CFrame.new(front(ctx, 0.52 * side, -0.02, S * 0.008)) * CFrame.Angles(0, -side * math.rad(35), 0), Color3.fromRGB(255, 120, 150))
			cheek.Transparency = 0.35
		end
	end
end

-- ---------------------------------------------------------------------
-- API pública
-- ---------------------------------------------------------------------
function SlimeBuilder.GetDimensions(slimeId: string, scale: number?): (number, number)
	local def = Slimes.Get(slimeId) or Slimes.List[1]
	local S = BASE_SIZE * Rarities.Get(def.Rarity).Scale * (scale or 1)
	return S, S * 0.82
end

function SlimeBuilder.Build(slimeId: string, mutationName: string?, options: BuildOptions?): Model
	local opts: BuildOptions = options or {}
	local def = Slimes.Get(slimeId) or Slimes.List[1]
	local rarity = Rarities.Get(def.Rarity)
	local mutation = Mutations.Get(mutationName)
	local S, H = SlimeBuilder.GetDimensions(def.Id, opts.Scale)

	local model = Instance.new("Model")
	model.Name = def.Name

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(S * 0.6, 0.2, S * 0.6)
	root.CFrame = CFrame.new(0, 0, 0)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Parent = model
	model.PrimaryPart = root

	local silhouette = opts.Silhouette == true
	local ctx: Ctx = {
		Model = model,
		Root = root,
		Def = def,
		S = S,
		H = H,
		A = S / 2,
		B = H / 2,
		Silhouette = silhouette,
		Effects = not silhouette and not opts.NoEffects,
		BodyColor = def.Color,
		Body = nil,
		Eyes = {},
		EyeSize = 0,
	}

	-- Cuerpo según la mutación
	local bodyColor = def.Color
	local material = def.Material or Enum.Material.SmoothPlastic
	local transparency = 0.04
	local reflectance = 0
	if mutation.Name == "Gold" then
		bodyColor = GOLD
		material = Enum.Material.SmoothPlastic
		reflectance = 0.3
	elseif mutation.Name == "Diamond" then
		bodyColor = Color3.fromRGB(165, 235, 255)
		material = Enum.Material.Glass
		transparency = 0.3
		reflectance = 0.2
	elseif mutation.Name == "Galaxy" then
		bodyColor = Color3.fromRGB(55, 22, 110)
		material = Enum.Material.SmoothPlastic
	elseif mutation.Name == "Rainbow" then
		bodyColor = Color3.fromHSV(math.random(), 0.65, 1)
	end
	ctx.BodyColor = bodyColor

	local body = ball(ctx, "Body", Vector3.new(S, H, S), CFrame.new(0, H / 2, 0), bodyColor, material)
	body.Transparency = if silhouette then 0 else transparency
	body.Reflectance = if silhouette then 0 else reflectance
	ctx.Body = body

	local puddle = ball(ctx, "Puddle", Vector3.new(S * 1.14, S * 0.1, S * 1.14), CFrame.new(0, S * 0.03, 0), bodyColor, material)
	puddle.Transparency = body.Transparency

	if not silhouette then
		local shine = ball(ctx, "Shine", Vector3.new(S * 0.2, S * 0.1, S * 0.08), CFrame.new(front(ctx, -0.42, 0.55, S * 0.015)) * CFrame.Angles(math.rad(-30), math.rad(25), math.rad(30)), WHITE)
		shine.Transparency = 0.25
	end

	buildFace(ctx, def.EyeScale or 1)

	for _, accessoryName in def.Accessories do
		local builder = Accessories[accessoryName]
		if builder then
			builder(ctx)
		else
			warn("[SlimeBuilder] Accesorio desconocido: " .. accessoryName)
		end
	end

	-- Efectos por rareza
	if rarity.Order >= 5 then
		light(ctx, if rarity.Name == "Secret" then WHITE else rarity.Color, S * 2.5, 1.2)
	end
	if rarity.Order >= 6 then
		local colors = if rarity.Name == "Secret" then { WHITE, Color3.fromRGB(40, 40, 40) } else { rarity.Color, WHITE }
		particles(ctx, colors, 5, S * 0.1, 0.8)
	end

	-- Efectos por mutación
	if mutation.Name == "Gold" then
		particles(ctx, { GOLD }, 4, S * 0.08, 1)
	elseif mutation.Name == "Diamond" then
		particles(ctx, { WHITE, Color3.fromRGB(150, 230, 255) }, 5, S * 0.08, 1)
	elseif mutation.Name == "Rainbow" then
		if not silhouette then
			tag(body, "RainbowPart")
			tag(puddle, "RainbowPart")
		end
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = WHITE
		addEffect(ctx, sparkles)
	elseif mutation.Name == "Galaxy" then
		particles(ctx, { WHITE, Color3.fromRGB(200, 150, 255) }, 8, S * 0.06, 1)
		light(ctx, Color3.fromRGB(150, 70, 255), S * 2.5, 1.5)
	end

	model:SetAttribute("SlimeId", def.Id)
	model:SetAttribute("Mutation", mutation.Name)
	model:SetAttribute("Rarity", rarity.Name)
	model:SetAttribute("BodyHeight", H)
	if not silhouette then
		tag(body, "SlimeBody")
	end
	return model
end

-- ---------------------------------------------------------------------
-- Cartel flotante (BillboardGui) con nombre, rareza, ingresos y precio
-- ---------------------------------------------------------------------
export type BillboardInfo = {
	Income: number?,
	Price: number?,
	Extra: string?,
	ExtraColor: Color3?,
}

export type BillboardRefs = {
	Gui: BillboardGui,
	Income: TextLabel?,
	Price: TextLabel?,
	Extra: TextLabel?,
}

local function makeLabel(parent: Instance, name: string, text: string, color: Color3, strokeColor: Color3, order: number, heightScale: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, heightScale)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.LayoutOrder = order
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = strokeColor
	stroke.Parent = label
	label.Parent = parent
	return label
end

function SlimeBuilder.CreateBillboard(model: Model, info: BillboardInfo): BillboardRefs
	local slimeId = model:GetAttribute("SlimeId") :: string
	local mutationName = model:GetAttribute("Mutation") :: string
	local def = Slimes.Get(slimeId) or Slimes.List[1]
	local rarity = Rarities.Get(def.Rarity)
	local mutation = Mutations.Get(mutationName)
	local S, H = SlimeBuilder.GetDimensions(def.Id)

	local lines = 2
	if mutation.Name ~= "Normal" then
		lines += 1
	end
	if info.Income then
		lines += 1
	end
	if info.Price then
		lines += 1
	end
	if info.Extra then
		lines += 1
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Size = UDim2.new(8, 0, lines * 0.62, 0)
	gui.StudsOffsetWorldSpace = Vector3.new(0, H + S * 0.55 + lines * 0.31, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 75
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = gui

	local share = 1 / lines
	local refs: BillboardRefs = { Gui = gui }

	if info.Extra then
		refs.Extra = makeLabel(gui, "Extra", info.Extra, info.ExtraColor or Color3.fromRGB(255, 120, 120), BLACK, 0, share)
	end
	if mutation.Name ~= "Normal" then
		makeLabel(gui, "Mutation", mutation.Icon .. " " .. string.upper(mutation.Name), mutation.Color, BLACK, 1, share)
	end
	makeLabel(gui, "SlimeName", def.Name, WHITE, BLACK, 2, share)
	local rarityLabel = makeLabel(gui, "Rarity", rarity.Name, rarity.Color, rarity.StrokeColor, 3, share)
	if rarity.Animated then
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 230, 90)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 255, 140)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90, 180, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 90, 255)),
		})
		gradient.Parent = rarityLabel
		rarityLabel.TextColor3 = WHITE
		tag(gradient, "RainbowGradient")
	end
	if info.Income then
		refs.Income = makeLabel(gui, "Income", Format.PerSecond(info.Income), Color3.fromRGB(90, 255, 120), BLACK, 4, share)
	end
	if info.Price then
		refs.Price = makeLabel(gui, "Price", Format.Money(info.Price), Color3.fromRGB(255, 225, 70), BLACK, 5, share)
	end

	gui.Parent = model.PrimaryPart or model
	refs.Gui = gui
	return refs
end

return SlimeBuilder
