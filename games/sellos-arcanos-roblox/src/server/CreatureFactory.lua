-- Construye el modelo de una criatura listo para moverse por física.
--
-- Usa los modelos importados desde los .obj del paquete de arte (ServerStorage >
-- CreatureModels > Hidra, Fenix, ...). Las piezas se reconocen por su nombre
-- (Cuerpo, Cuerpo2, Hueso, Brillo, Ojos, Plumas, Plumaje, Membrana, Cristal,
-- CristalTenue, Estrellas, Oscuro) y reciben automáticamente material Neon y el
-- color del elemento, como indica el LEEME. Si un modelo aún no se ha importado,
-- se crea una figura provisional para que el juego funcione igualmente.
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameData = require(Shared.GameData)
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local World = require(script.Parent.WorldService)

local Factory = {}

local FLYERS = { fenix = true, grifo = true, wyvern = true, leviatan = true }
Factory.FLYERS = FLYERS

-- giro para que el frente de los .obj (+Z) mire hacia el frente de Roblox (−Z)
Config.ModelYawOffset = Config.ModelYawOffset or 180

local modelsFolder = ServerStorage:FindFirstChild("CreatureModels")
if not modelsFolder then
	modelsFolder = Instance.new("Folder")
	modelsFolder.Name = "CreatureModels"
	modelsFolder.Parent = ServerStorage
end

local function findTemplate(fileName)
	local lower = string.lower(fileName)
	for _, child in ipairs(modelsFolder:GetChildren()) do
		if string.lower(child.Name) == lower or string.find(string.lower(child.Name), lower, 1, true) == 1 then
			return child
		end
	end
	return nil
end

function Factory.hasImported(id)
	local c = GameData.CreatureById[id]
	return findTemplate(c.file) ~= nil
end

-- tipo de pieza a partir de su nombre
local function classify(name)
	local n = string.lower(name)
	if string.find(n, "cristaltenue", 1, true) then
		return "tenue"
	end
	for _, k in ipairs({ "brillo", "estrellas" }) do
		if string.find(n, k, 1, true) then
			return "glow"
		end
	end
	if string.find(n, "ojos", 1, true) then
		return "eyes"
	end
	if string.find(n, "plumaje", 1, true) then
		return "plumaje"
	end
	if string.find(n, "plumas", 1, true) or string.find(n, "cristal", 1, true) then
		return "glow"
	end
	if string.find(n, "hueso", 1, true) then
		return "bone"
	end
	if string.find(n, "cuerpo2", 1, true) then
		return "body2"
	end
	if string.find(n, "membrana", 1, true) then
		return "membrane"
	end
	if string.find(n, "oscuro", 1, true) then
		return "dark"
	end
	return "body"
end

local function scaleColor(c, k)
	return Color3.new(math.min(1, c.R * k), math.min(1, c.G * k), math.min(1, c.B * k))
end

-- Pinta las piezas. glowStr es "#rrggbb", "prisma" o "aurora".
function Factory.paint(model, def, glowStr, t)
	local glow = Formulas.resolveColor(glowStr, t or 0)
	local body = Color3.fromHex(def.body)
	local bone = Color3.fromHex(def.bone)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "Root" and not p:GetAttribute("CircleRing") then
			local kind = p:GetAttribute("PartKind") or classify(p.Name)
			p:SetAttribute("PartKind", kind)
			if kind == "glow" then
				p.Material = Enum.Material.Neon
				p.Color = glow
			elseif kind == "eyes" then
				p.Material = Enum.Material.Neon
				p.Color = glow:Lerp(Color3.new(1, 1, 1), 0.55)
			elseif kind == "tenue" then
				p.Material = Enum.Material.Neon
				p.Color = glow
				p.Transparency = 0.45
			elseif kind == "bone" then
				p.Material = Enum.Material.SmoothPlastic
				p.Color = bone
			elseif kind == "body2" then
				p.Material = Enum.Material.Slate
				p.Color = scaleColor(body, 1.18)
			elseif kind == "plumaje" then
				p.Material = Enum.Material.SmoothPlastic
				p.Color = scaleColor(body, 1.22)
			elseif kind == "membrane" then
				p.Material = Enum.Material.SmoothPlastic
				p.Color = scaleColor(body, 1.1)
			elseif kind == "dark" then
				p.Material = Enum.Material.Slate
				p.Color = scaleColor(body, 0.6)
			else
				p.Material = Enum.Material.Slate
				p.Color = body
			end
		end
	end
end

-- figura provisional (si el modelo no se ha importado todavía)
local function placeholder(def)
	local m = Instance.new("Model")
	m.Name = def.file
	local function add(name, shape, size, cf)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape
		p.Size = size
		p.CFrame = cf
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = m
		return p
	end
	local role = def.role
	local w = (role == "tanque") and 3.2 or 2.4
	add("Cuerpo", Enum.PartType.Ball, Vector3.new(w, w * 0.9, w * 1.3), CFrame.new(0, 1.9, 0))
	add("Cuerpo2", Enum.PartType.Ball, Vector3.new(1.7, 1.5, 1.8), CFrame.new(0, 3.2, -1.3))
	add("Ojos", Enum.PartType.Ball, Vector3.new(0.35, 0.35, 0.35), CFrame.new(0.42, 3.4, -2.15))
	add("Ojos", Enum.PartType.Ball, Vector3.new(0.35, 0.35, 0.35), CFrame.new(-0.42, 3.4, -2.15))
	add("Brillo", Enum.PartType.Block, Vector3.new(0.15, 0.15, w * 1.2), CFrame.new(0, 1.9 + w * 0.46, 0))
	add("Brillo", Enum.PartType.Block, Vector3.new(w * 0.95, 0.15, 0.15), CFrame.new(0, 1.9, 0) * CFrame.Angles(0, 0, math.rad(20)))
	for _, sx in ipairs({ -1, 1 }) do
		add("Hueso", Enum.PartType.Block, Vector3.new(0.5, 1.4, 0.5), CFrame.new(sx * w * 0.32, 0.7, -0.6))
		add("Hueso", Enum.PartType.Block, Vector3.new(0.5, 1.4, 0.5), CFrame.new(sx * w * 0.32, 0.7, 0.7))
		if FLYERS[def.id] then
			add("Plumas", Enum.PartType.Wedge, Vector3.new(0.2, 1.4, 3.2), CFrame.new(sx * (w * 0.5 + 1.4), 2.6, 0.2) * CFrame.Angles(0, 0, math.rad(-sx * 70)))
		end
	end
	add("Hueso", Enum.PartType.Block, Vector3.new(0.35, 0.9, 0.35), CFrame.new(0.35, 4.2, -1.2) * CFrame.Angles(math.rad(-20), 0, math.rad(-15)))
	add("Hueso", Enum.PartType.Block, Vector3.new(0.35, 0.9, 0.35), CFrame.new(-0.35, 4.2, -1.2) * CFrame.Angles(math.rad(-20), 0, math.rad(15)))
	m:SetAttribute("Placeholder", true)
	return m
end

-- Construye el modelo. opts: form (1..3), boss, glow ("#hex"/"prisma"/"aurora"), seal (diseño), circle (bool)
function Factory.build(id, opts)
	opts = opts or {}
	local def = GameData.CreatureById[id]
	local template = findTemplate(def.file)
	local model
	if template then
		model = template:Clone()
		if not model:IsA("Model") then
			local wrap = Instance.new("Model")
			model.Parent = wrap
			model = wrap
		end
	else
		model = placeholder(def)
	end
	model.Name = def.file
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Humanoid") then
			d:Destroy()
		end
	end
	Factory.paint(model, def, opts.glow or def.color, 0)

	-- girar para que mire hacia −Z y escalar a la altura de su forma
	local pivot = model:GetPivot()
	model:PivotTo(CFrame.new(pivot.Position) * CFrame.Angles(0, math.rad(Config.ModelYawOffset), 0))
	local size = model:GetExtentsSize()
	local target = opts.boss and Config.BossHeight or Config.FormHeights[opts.form or 1]
	if size.Y > 0.01 then
		model:ScaleTo(model:GetScale() * (target / size.Y))
	end
	local cf, ext = model:GetBoundingBox()
	local bottom = cf.Position - Vector3.new(0, ext.Y / 2, 0)

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CFrame = CFrame.new(bottom)
	root.Parent = model
	model.PrimaryPart = root

	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p ~= root then
			p.Anchored = false
			p.CanCollide = false
			p.CanTouch = false
			p.Massless = true
			p.CastShadow = true
			local wc = Instance.new("WeldConstraint")
			wc.Part0 = root
			wc.Part1 = p
			wc.Parent = p
		end
	end

	-- círculo mágico bajo sus patas
	local radius = math.max(ext.X, ext.Z) * 0.62
	if opts.circle ~= false then
		local glow = Formulas.resolveColor(opts.glow or def.color, 0)
		local circle = World.magicCircle(model, bottom, radius, glow, opts.seal or def.circle, opts.circleIntensity or 0.85)
		circle.Name = "Circulo"
		for _, p in ipairs(circle:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = false
				p.Massless = true
				p.CastShadow = false
				p:SetAttribute("CircleRing", true)
				local wc = Instance.new("WeldConstraint")
				wc.Part0 = root
				wc.Part1 = p
				wc.Parent = p
			end
		end
	end

	-- halo de la Hidra y el Fénix
	if def.halo then
		local glow = Formulas.resolveColor(opts.glow or def.color, 0)
		local halo = Instance.new("Part")
		halo.Name = "Halo"
		halo.Shape = Enum.PartType.Cylinder
		halo.Size = Vector3.new(0.12, ext.Y * 0.55, ext.Y * 0.55)
		halo.CFrame = CFrame.new(bottom + Vector3.new(0, ext.Y * 0.8, 0)) * CFrame.new(0, 0, ext.Z * 0.25) * CFrame.Angles(0, math.rad(90), 0)
		halo.Material = Enum.Material.Neon
		halo.Color = glow
		halo.Transparency = 0.55
		halo.Anchored = false
		halo.CanCollide = false
		halo.CanQuery = false
		halo.Massless = true
		halo:SetAttribute("PartKind", "glow")
		halo.Parent = model
		local wc = Instance.new("WeldConstraint")
		wc.Part0 = root
		wc.Part1 = halo
		wc.Parent = halo
	end

	-- luz del elemento
	local light = Instance.new("PointLight")
	light.Color = Formulas.resolveColor(opts.glow or def.color, 0)
	light.Range = math.clamp(ext.Y * 2.2, 10, 40)
	light.Brightness = opts.boss and 3 or 1.6
	light.Shadows = false
	light.Parent = root

	-- movimiento por física (suave en todos los clientes)
	local att = Instance.new("Attachment")
	att.Parent = root
	local ap = Instance.new("AlignPosition")
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = att
	ap.MaxForce = 1e7
	ap.MaxVelocity = 60
	ap.Responsiveness = 45
	ap.Parent = root
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.MaxTorque = 1e7
	ao.Responsiveness = 25
	ao.Parent = root

	model:SetAttribute("CreatureId", id)
	model:SetAttribute("Glow", opts.glow or def.color)
	model:SetAttribute("Height", ext.Y)
	model:SetAttribute("Radius", radius)
	CollectionService:AddTag(model, "SA_Creature")
	return model, root, ap, ao, { height = ext.Y, radius = radius, flyer = FLYERS[id] == true }
end

return Factory
