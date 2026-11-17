-- Efectos visuales y de sonido en el cliente. El servidor envía lotes de
-- efectos (evento «Fx») y aquí se dibujan con piezas de neón y tweens, sin
-- cargar la red. También pone barras de vida sobre las criaturas, anima los
-- círculos, traduce los avisos de interacción y colorea los tintes animados.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameData = require(Shared.GameData)
local Formulas = require(Shared.Formulas)
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)

local Fx = {}
local player = Players.LocalPlayer
local C = UI.C

local fxFolder = Instance.new("Folder")
fxFolder.Name = "SA_Fx"
fxFolder.Parent = Workspace

local GROUND = 100

-- --- sonido -------------------------------------------------------------------------
local SOUNDS = {
	hit = "rbxasset://sounds/swordslash.wav",
	cast = "rbxasset://sounds/swordlunge.wav",
	ping = "rbxasset://sounds/electronicpingshort.wav",
	boom = "rbxasset://sounds/collide.wav",
	glass = "rbxasset://sounds/glassbreak.wav",
	shot = "rbxasset://sounds/Rocket shot.wav",
}
Fx.volume = 0.8
function Fx.sound(name, pitch, vol)
	local id = SOUNDS[name]
	if not id then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = (vol or 0.5) * Fx.volume
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 3)
end

-- --- piezas efímeras ----------------------------------------------------------------
local function neon(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = fxFolder
	return p
end

local function hex(c)
	if typeof(c) == "Color3" then
		return c
	end
	local ok, col = pcall(Formulas.resolveColor, c or "#ffffff", os.clock())
	return ok and col or Color3.new(1, 1, 1)
end

local function tween(o, t, props, style)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function flatDisc(pos, radius, color, transp, height)
	return neon({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height or 0.1, radius * 2, radius * 2),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = transp or 0.3,
	})
end

local function ring(pos, radius, color, big)
	local p = flatDisc(Vector3.new(pos.X, GROUND + 0.3, pos.Z), 0.5, color, 0.2, 0.15)
	tween(p, big and 0.6 or 0.45, { Size = Vector3.new(0.15, radius * 2, radius * 2), Transparency = 1 })
	Debris:AddItem(p, 0.7)
	-- borde brillante
	local edge = flatDisc(Vector3.new(pos.X, GROUND + 0.35, pos.Z), radius * 0.3, color, 0.5, 0.05)
	tween(edge, 0.5, { Size = Vector3.new(0.05, radius * 2.1, radius * 2.1), Transparency = 1 })
	Debris:AddItem(edge, 0.6)
end

local function burst(pos, color, n)
	for i = 1, (n or 12) do
		local s = math.random() * 0.6 + 0.3
		local p = neon({ Size = Vector3.new(s, s, s), CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), Color = color })
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5).Unit * (6 + math.random() * 8)
		tween(p, 0.6 + math.random() * 0.3, { CFrame = p.CFrame + dir, Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1) })
		Debris:AddItem(p, 1)
	end
end

local function pillar(pos, color, h)
	local p = neon({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(h, 2.4, 2.4),
		CFrame = CFrame.new(Vector3.new(pos.X, GROUND + h / 2, pos.Z)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = 0.35,
	})
	tween(p, 0.9, { Size = Vector3.new(h, 0.2, 0.2), Transparency = 1 })
	Debris:AddItem(p, 1)
end

-- --- números de daño ------------------------------------------------------------------
local DMG_COLORS = {
	crit = C.gold, adv = Color3.fromHex("#9affc1"), taken = C.danger, heal = C.ok, dot = Color3.fromHex("#c9a0ff"),
	miss = C.inkBlue, shield = C.inkBlue, immune = C.inkBlue, resist = C.danger,
}
local function damageNumber(pos, value, kind)
	local anchor = neon({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(pos + Vector3.new((math.random() - 0.5) * 2, 0, 0)) })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(160, 40)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 140
	bb.Parent = anchor
	local text
	if kind == "miss" then
		text = UI.t("miss")
	elseif kind == "immune" then
		text = UI.t("immune")
	elseif kind == "resist" then
		text = UI.t("resist")
	else
		text = ((kind == "heal") and "+" or "") .. tostring(value) .. ((kind == "crit") and "!" or "")
	end
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Text = text
	l.Font = UI.F.bold
	l.TextScaled = false
	l.TextSize = (kind == "crit") and 30 or 24
	l.TextColor3 = DMG_COLORS[kind] or C.bright
	l.TextStrokeTransparency = 0.3
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	l.Parent = bb
	tween(anchor, 0.9, { CFrame = anchor.CFrame + Vector3.new(0, 5, 0) })
	task.delay(0.5, function()
		tween(l, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	Debris:AddItem(anchor, 1)
end

-- --- criaturas: barra de vida, destello, estados ----------------------------------------
local models = {} -- model -> {bb, fill, highlight}

local STATUS_COLORS = {
	freeze = Color3.fromHex("#9fefff"), petrify = Color3.fromRGB(140, 140, 140), poison = Color3.fromHex("#3dff88"),
	burn = Color3.fromHex("#ff7a2e"), stun = Color3.fromHex("#fff2a0"), root = Color3.fromHex("#ff4fd2"),
}

local function setupModel(m)
	if models[m] or not m:IsA("Model") then
		return
	end
	local id = m:GetAttribute("CreatureId")
	if not id then
		return
	end
	local def = GameData.CreatureById[id]
	local root = m:FindFirstChild("Root") or m.PrimaryPart
	local info = { model = m }
	models[m] = info
	local h = m:GetAttribute("Height") or 5
	if root then
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(150, 34)
		bb.StudsOffsetWorldSpace = Vector3.new(0, h + 2.5, 0)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.MaxDistance = 120
		bb.Parent = root
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Size = UDim2.new(1, 0, 0, 16)
		name.Font = UI.F.bold
		name.TextSize = 13
		name.TextColor3 = C.bright
		name.TextStrokeTransparency = 0.4
		name.Parent = bb
		local back = Instance.new("Frame")
		back.BackgroundColor3 = Color3.new(0, 0, 0)
		back.BackgroundTransparency = 0.4
		back.BorderSizePixel = 0
		back.Position = UDim2.fromOffset(15, 20)
		back.Size = UDim2.new(1, -30, 0, 6)
		back.Parent = bb
		local fill = Instance.new("Frame")
		fill.BorderSizePixel = 0
		fill.BackgroundColor3 = Color3.fromHex(def.color)
		fill.Size = UDim2.fromScale(1, 1)
		fill.Parent = back
		info.bb, info.name, info.fill = bb, name, fill
		info.baseColor = Color3.fromHex(def.color)
		local kind = m:GetAttribute("Kind")
		local owner = m:GetAttribute("OwnerId")
		if kind == "companion" then
			local pl = owner and Players:GetPlayerByUserId(owner)
			name.Text = (pl and pl.DisplayName .. " · " or "") .. UI.L(def.name)
			name.TextColor3 = (owner == player.UserId) and C.ok or C.ink
		elseif kind == "anchor" then
			name.Text = UI.t("anchor")
		else
			name.Text = UI.L(def.name) .. " · " .. UI.t("lvl") .. " " .. (m:GetAttribute("Level") or 1)
		end
	end
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 1
	hl.OutlineTransparency = 1
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = m
	info.hl = hl
end

local function hitFlash(id, color)
	local f = Workspace:FindFirstChild("Criaturas")
	if not f then
		return
	end
	for _, m in ipairs(f:GetChildren()) do
		if m:GetAttribute("EntityId") == id then
			local info = models[m]
			if info and info.hl then
				info.flash = 1
				info.flashColor = color
			end
			return
		end
	end
end

-- --- efectos del servidor ------------------------------------------------------------------
local HANDLERS = {}

function HANDLERS.dmg(e)
	damageNumber(e.p, e.v, e.k)
end

function HANDLERS.hit(e)
	hitFlash(e.id, hex(e.c))
	burst(e.p, hex(e.c), e.s == 1 and 10 or 5)
	Fx.sound("hit", 0.9 + math.random() * 0.3, e.s == 1 and 0.5 or 0.3)
end

function HANDLERS.slash(e)
	local col = hex(e.c)
	local p = neon({ Size = Vector3.new(e.r * 1.2, 0.2, 0.6), CFrame = CFrame.lookAt(e.p, e.p + e.d) * CFrame.Angles(0, math.rad(90), math.rad(math.random(-30, 30))), Color = col, Transparency = 0.2 })
	tween(p, 0.25, { Transparency = 1, Size = Vector3.new(e.r * 1.6, 0.05, 0.2) })
	Debris:AddItem(p, 0.3)
	Fx.sound("cast", 1.2, 0.25)
end

function HANDLERS.proj(e)
	local col = hex(e.c)
	local size = math.max(0.8, (e.z or 1) * 0.9)
	local p = neon({ Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), CFrame = CFrame.new(e.p), Color = col })
	local light = Instance.new("PointLight")
	light.Color = col
	light.Range = 8
	light.Parent = p
	local t = e.r / e.s
	tween(p, t, { CFrame = CFrame.new(e.p + e.d * e.r) }, Enum.EasingStyle.Linear)
	Debris:AddItem(p, t + 0.05)
	Fx.sound("shot", 1.5 + math.random() * 0.3, 0.15)
end

function HANDLERS.breath(e)
	local col = hex(e.c)
	local n = 14
	for i = 1, n do
		task.delay((i / n) * e.dur, function()
			local a = (math.random() - 0.5) * math.rad(e.a)
			local c, s = math.cos(a), math.sin(a)
			local dir = Vector3.new(e.d.X * c - e.d.Z * s, 0, e.d.X * s + e.d.Z * c)
			local p = neon({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(e.p), Color = col, Transparency = 0.2 })
			tween(p, 0.5, { CFrame = CFrame.new(e.p + dir * e.r), Size = Vector3.new(3.5, 3.5, 3.5), Transparency = 1 })
			Debris:AddItem(p, 0.55)
		end)
	end
	Fx.sound("cast", 0.7, 0.35)
end

function HANDLERS.ring(e)
	ring(e.p, e.r, hex(e.c), e.big)
	Fx.sound("boom", e.big and 0.6 or 0.9, 0.35)
end

-- aviso en el suelo que se llena hasta que cae el golpe
function HANDLERS.tele(e)
	local col = hex(e.c)
	local pos = Vector3.new(e.p.X, GROUND + 0.25, e.p.Z)
	local parts = {}
	if e.cone then
		local n = 9
		for i = 0, n - 1 do
			local a = math.rad(-e.cone / 2 + e.cone * i / (n - 1))
			local c, s = math.cos(a), math.sin(a)
			local dir = Vector3.new(e.d.X * c - e.d.Z * s, 0, e.d.X * s + e.d.Z * c)
			local mid = pos + dir * e.r / 2
			table.insert(parts, neon({ Size = Vector3.new(e.r * 0.12, 0.05, e.r), CFrame = CFrame.lookAt(mid, mid + dir), Color = col, Transparency = 0.6 }))
		end
	elseif e.len then
		local mid = pos + e.d * e.len / 2
		table.insert(parts, neon({ Size = Vector3.new(e.w, 0.05, e.len), CFrame = CFrame.lookAt(mid, mid + e.d), Color = col, Transparency = 0.6 }))
	else
		table.insert(parts, flatDisc(pos, e.r, col, 0.65, 0.06))
		local fill = flatDisc(pos + Vector3.new(0, 0.02, 0), 0.3, col, 0.35, 0.06)
		tween(fill, e.time, { Size = Vector3.new(0.06, e.r * 2, e.r * 2) }, Enum.EasingStyle.Linear)
		table.insert(parts, fill)
	end
	for _, p in ipairs(parts) do
		Debris:AddItem(p, e.time + 0.05)
	end
	Fx.sound("ping", 0.6, 0.15)
end

function HANDLERS.zone(e)
	local col = hex(e.c)
	local d = flatDisc(Vector3.new(e.p.X, GROUND + 0.2, e.p.Z), e.r, col, 0.6, 0.08)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(col)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(0.6, 0)
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Rate = 25
	emitter.Speed = NumberRange.new(3, 6)
	emitter.SpreadAngle = Vector2.new(15, 15)
	emitter.EmissionDirection = Enum.NormalId.Right
	emitter.Parent = d
	task.delay(math.max(0, e.time - 0.4), function()
		if d.Parent then
			emitter.Enabled = false
			tween(d, 0.4, { Transparency = 1 })
		end
	end)
	Debris:AddItem(d, e.time + 0.5)
end

function HANDLERS.pillar(e)
	pillar(e.p, hex(e.c), e.h or 14)
end

function HANDLERS.bolt(e)
	local col = hex(e.c)
	local p = neon({ Size = Vector3.new(0.6, 40, 0.6), CFrame = CFrame.new(Vector3.new(e.p.X, GROUND + 20, e.p.Z)), Color = col })
	tween(p, 0.25, { Transparency = 1 })
	Debris:AddItem(p, 0.3)
	ring(e.p, e.r, col)
	Fx.sound("boom", 1.4, 0.3)
end

function HANDLERS.tower(e)
	local col = hex(e.c)
	local p = neon({ Size = Vector3.new(3, 0.5, 3), CFrame = CFrame.new(Vector3.new(e.p.X, GROUND, e.p.Z)) * CFrame.Angles(0, math.rad(45), 0), Color = col, Transparency = 0.15 })
	tween(p, 0.2, { Size = Vector3.new(3, 12, 3), CFrame = p.CFrame + Vector3.new(0, 6, 0) }, Enum.EasingStyle.Back)
	task.delay(2, function()
		if p.Parent then
			tween(p, 0.4, { Transparency = 1 })
		end
	end)
	Debris:AddItem(p, 2.5)
	Fx.sound("glass", 1, 0.3)
end

function HANDLERS.mine(e)
	local col = hex(e.c)
	local p = neon({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(Vector3.new(e.p.X, GROUND + 1, e.p.Z)), Color = col })
	Debris:AddItem(p, e.time or 12)
end

function HANDLERS.shield(e)
	local f = Workspace:FindFirstChild("Criaturas")
	if not f then
		return
	end
	for _, m in ipairs(f:GetChildren()) do
		if m:GetAttribute("EntityId") == e.id then
			local root = m:FindFirstChild("Root")
			local h = m:GetAttribute("Height") or 5
			if root then
				local b = Instance.new("Part")
				b.Shape = Enum.PartType.Ball
				b.Size = Vector3.new(h * 1.4, h * 1.4, h * 1.4)
				b.Material = Enum.Material.ForceField
				b.Color = hex(e.c)
				b.CanCollide = false
				b.CanQuery = false
				b.Massless = true
				b.CFrame = root.CFrame + Vector3.new(0, h * 0.5, 0)
				b.Parent = fxFolder
				local w = Instance.new("WeldConstraint")
				w.Part0 = root
				w.Part1 = b
				w.Parent = b
				Debris:AddItem(b, e.time or 4)
			end
			break
		end
	end
end

function HANDLERS.trail(e)
	hitFlash(e.id, hex(e.c))
end

function HANDLERS.summon(e)
	local col = hex(e.c)
	ring(e.p, 8, col)
	if e.e == "pilar" then
		pillar(e.p, col, 40)
	elseif e.e == "estrellas" then
		for i = 1, 14 do
			local p = neon({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.7), CFrame = CFrame.new(e.p + Vector3.new((math.random() - 0.5) * 10, 30 + math.random() * 10, (math.random() - 0.5) * 10)), Color = col })
			tween(p, 0.6 + math.random() * 0.3, { CFrame = CFrame.new(e.p + Vector3.new((math.random() - 0.5) * 6, 1, (math.random() - 0.5) * 6)), Transparency = 0.6 }, Enum.EasingStyle.Quad)
			Debris:AddItem(p, 1)
		end
	elseif e.e == "espiral" then
		for i = 1, 20 do
			local a = i * 0.6
			local p = neon({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), CFrame = CFrame.new(e.p + Vector3.new(math.cos(a) * 5, i * 0.5, math.sin(a) * 5)), Color = col })
			tween(p, 0.8, { Transparency = 1, CFrame = p.CFrame + Vector3.new(0, 4, 0) })
			Debris:AddItem(p, 0.9)
		end
	else
		pillar(e.p, col, (e.h or 6) * 2.5)
	end
	Fx.sound("ping", 0.8, 0.3)
end

function HANDLERS.burst(e)
	burst(e.p, hex(e.c), e.n or 20)
end

function HANDLERS.sealable(e)
	Fx.sound("ping", 1.6, 0.4)
end

function HANDLERS.sealed(e)
	local col = hex(e.c)
	pillar(e.p, col, 70)
	ring(e.p, 26, col, true)
	burst(e.p + Vector3.new(0, (e.h or 5) * 0.5, 0), col, 40)
	Fx.sound("glass", 0.7, 0.5)
end

function HANDLERS.roar(e)
	Fx.sound("boom", 0.4, 0.8)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and (root.Position - e.p).Magnitude < 150 then
		Fx.shake(0.8)
	end
end

function HANDLERS.lunge(e)
end

-- --- temblor de cámara ---------------------------------------------------------------------
local shakeAmt = 0
function Fx.shake(a)
	shakeAmt = math.max(shakeAmt, a)
end

-- --- bucle por fotograma ---------------------------------------------------------------------
local function frame(dt)
	local t = os.clock()
	for m, info in pairs(models) do
		if not m.Parent then
			models[m] = nil
		else
			if info.fill then
				local hp, maxHp = m:GetAttribute("HP") or 1, m:GetAttribute("MaxHP") or 1
				info.fill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
				local sealable = m:GetAttribute("Sealable")
				info.fill.BackgroundColor3 = sealable and C.gold or info.baseColor
			end
			-- destello al recibir golpes y color de estado
			local status = m:GetAttribute("Status") or ""
			local target = (State.targetModel and State.targetModel() == m)
			if info.flash and info.flash > 0 then
				info.flash = info.flash - dt * 5
				info.hl.FillColor = info.flashColor or C.bright
				info.hl.FillTransparency = 1 - math.max(0, info.flash) * 0.7
				info.hl.OutlineTransparency = 1
			elseif STATUS_COLORS[status] then
				info.hl.FillColor = STATUS_COLORS[status]
				info.hl.FillTransparency = 0.55
				info.hl.OutlineTransparency = 1
			elseif m:GetAttribute("Sealable") then
				info.hl.FillTransparency = 1
				info.hl.OutlineColor = C.gold
				info.hl.OutlineTransparency = 0.1 + math.abs(math.sin(t * 5)) * 0.5
			elseif target then
				info.hl.FillTransparency = 1
				info.hl.OutlineColor = C.bright
				info.hl.OutlineTransparency = 0.4
			else
				info.hl.FillTransparency = 1
				info.hl.OutlineTransparency = 1
			end
			-- tintes animados (Prisma, Aurora)
			local glow = m:GetAttribute("Glow")
			if glow == "prisma" or glow == "aurora" then
				local col = Formulas.resolveColor(glow, t)
				for _, p in ipairs(m:GetDescendants()) do
					if p:IsA("BasePart") then
						local k = p:GetAttribute("PartKind")
						if k == "glow" or k == "tenue" or p:GetAttribute("CircleRing") and p.Material == Enum.Material.Neon then
							p.Color = col
						elseif k == "eyes" then
							p.Color = col:Lerp(Color3.new(1, 1, 1), 0.55)
						end
					end
				end
			end
		end
	end
	-- círculos que giran y orbes que flotan (solo en este cliente)
	for _, m in ipairs(CollectionService:GetTagged("SA_Spin")) do
		if m:IsA("Model") then
			local piv = m:GetPivot()
			m:PivotTo(piv * CFrame.Angles(0, dt * 0.08, 0))
		end
	end
	for _, p in ipairs(CollectionService:GetTagged("SA_Bob")) do
		if p:IsA("BasePart") then
			local base = p:GetAttribute("BaseY")
			if not base then
				base = p.Position.Y
				p:SetAttribute("BaseY", base)
			end
			p.CFrame = CFrame.new(p.Position.X, base + math.sin(t * 2) * 0.6, p.Position.Z)
		end
	end
	if shakeAmt > 0 then
		local cam = Workspace.CurrentCamera
		cam.CFrame = cam.CFrame * CFrame.new((math.random() - 0.5) * shakeAmt, (math.random() - 0.5) * shakeAmt, 0)
		shakeAmt = math.max(0, shakeAmt - dt * 2)
	end
end

-- --- textos del mundo en el idioma del jugador ------------------------------------------------
local function localizePrompt(prompt)
	local idx = prompt:GetAttribute("IslandIndex")
	local isl = idx and GameData.Islands[idx]
	if prompt.Name == "TravelPrompt" and isl then
		prompt.ActionText = UI.t("travel")
		prompt.ObjectText = UI.L(isl.name)
	elseif prompt.Name == "ReturnPrompt" then
		prompt.ActionText = UI.t("returnCitadel")
		prompt.ObjectText = isl and UI.L(isl.name) or ""
	elseif prompt.Name == "BossPrompt" and isl then
		prompt.ActionText = UI.t("challenge")
		prompt.ObjectText = UI.L(GameData.CreatureById[isl.boss].name)
	elseif prompt.Name == "FuentePrompt" then
		prompt.ActionText = UI.t("restore")
		prompt.ObjectText = UI.t("fountain")
	end
end

local portalLabels = {}
local function setupPortal(m)
	local idx = m:GetAttribute("IslandIndex")
	local gate = m:FindFirstChild("Gate")
	local isl = idx and GameData.Islands[idx]
	if not gate or not isl then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 60)
	bb.StudsOffset = Vector3.new(0, 11, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = 90
	bb.Parent = gate
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 28)
	name.Font = UI.F.title
	name.TextSize = 22
	name.TextColor3 = C.bright
	name.TextStrokeTransparency = 0.4
	name.Text = UI.L(isl.name)
	name.Parent = bb
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromOffset(0, 30)
	sub.Size = UDim2.new(1, 0, 0, 20)
	sub.Font = UI.F.bold
	sub.TextSize = 14
	sub.TextColor3 = C.muted
	sub.TextStrokeTransparency = 0.5
	sub.Parent = bb
	portalLabels[idx] = { sub = sub, gate = gate, levels = isl.levels }
	if State.profile then
		Fx.refreshPortals(State.profile)
	end
end

function Fx.refreshPortals(profile)
	for idx, info in pairs(portalLabels) do
		local unlocked = profile and idx <= profile.islands.unlocked
		local cleared = profile and table.find(profile.islands.cleared, idx)
		info.sub.Text = UI.t("islandLevels", { n = idx, a = info.levels[1], b = info.levels[2] }) .. (cleared and "  ✓" or (unlocked and "" or ("  · " .. UI.t("locked"))))
		info.sub.TextColor3 = unlocked and C.muted or C.danger
		info.gate.Transparency = unlocked and 0.35 or 0.85
	end
end

function Fx.setMusic(vol)
	local s = SoundService:FindFirstChild("SA_Music")
	if Config.Assets.music ~= 0 then
		if not s then
			s = Instance.new("Sound")
			s.Name = "SA_Music"
			s.SoundId = "rbxassetid://" .. Config.Assets.music
			s.Looped = true
			s.Parent = SoundService
			s:Play()
		end
		s.Volume = 0.4 * vol
	end
end

function Fx.init()
	Net.get("Fx").OnClientEvent:Connect(function(list)
		for _, e in ipairs(list) do
			local h = HANDLERS[e.t]
			if h then
				local ok, err = pcall(h, e)
				if not ok then
					warn("[Sellos Arcanos] fx", e.t, err)
				end
			end
		end
	end)
	local function watchFolder(f)
		for _, m in ipairs(f:GetChildren()) do
			task.spawn(setupModel, m)
		end
		f.ChildAdded:Connect(function(m)
			task.wait()
			setupModel(m)
		end)
	end
	local f = Workspace:FindFirstChild("Criaturas")
	if f then
		watchFolder(f)
	end
	Workspace.ChildAdded:Connect(function(c)
		if c.Name == "Criaturas" then
			watchFolder(c)
		end
	end)
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			localizePrompt(d)
		end
	end
	Workspace.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") then
			task.wait()
			localizePrompt(d)
		end
	end)
	for _, m in ipairs(CollectionService:GetTagged("SA_Portal")) do
		setupPortal(m)
	end
	CollectionService:GetInstanceAddedSignal("SA_Portal"):Connect(setupPortal)
	RunService.RenderStepped:Connect(frame)
end

return Fx
