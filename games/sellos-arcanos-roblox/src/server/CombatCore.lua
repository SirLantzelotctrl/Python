-- Núcleo del combate (servidor): entidades, daño, estados, habilidades,
-- proyectiles, zonas, rayos y minas. Los efectos visuales se envían a los
-- clientes de la misma isla en lotes (evento remoto «Fx»).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameData = require(Shared.GameData)
local Formulas = require(Shared.Formulas)
local Net = require(Shared.Net)

local Factory = require(script.Parent.CreatureFactory)
local World = require(script.Parent.WorldService)

local Core = {}
Core.entities = {}
Core.hooks = {}
Core.time = 0

local uid = 0
local projectiles, zones, timers, mines = {}, {}, {}, {}
local fxQueue = {} -- island -> lista de efectos

local folder = Instance.new("Folder")
folder.Name = "Criaturas"
folder.Parent = workspace

local CC = { stun = true, freeze = true, petrify = true }
local NEG = { burn = true, poison = true, slow = true, stun = true, freeze = true, petrify = true, root = true, blind = true, mark = true }

-- --- efectos visuales -----------------------------------------------------
function Core.fx(island, payload)
	if island == nil then
		return
	end
	local q = fxQueue[island]
	if not q then
		q = {}
		fxQueue[island] = q
	end
	if #q < 120 then
		table.insert(q, payload)
	end
end

local function flushFx()
	local fxEvent = Net.get("Fx")
	for island, list in pairs(fxQueue) do
		if #list > 0 then
			for _, player in ipairs(Players:GetPlayers()) do
				if player:GetAttribute("Island") == island then
					fxEvent:FireClient(player, list)
				end
			end
		end
	end
	fxQueue = {}
end

function Core.later(t, fn)
	table.insert(timers, { t = Core.time + t, fn = fn })
end

-- --- utilidades -------------------------------------------------------------
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function dist(a, b)
	return (flat(a) - flat(b)).Magnitude
end
Core.dist = dist

function Core.dirTo(from, to)
	local d = flat(to - from)
	if d.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	return d.Unit
end

local function rotateY(v, ang)
	local c, s = math.cos(ang), math.sin(ang)
	return Vector3.new(v.X * c - v.Z * s, 0, v.X * s + v.Z * c)
end
Core.rotateY = rotateY

local function inCone(src, dir, tgt, range, arcDeg)
	local d = flat(tgt.pos - src.pos)
	local m = d.Magnitude
	if m > range + tgt.radius then
		return false
	end
	if m < tgt.radius + 1 then
		return true
	end
	local ang = math.acos(math.clamp(d.Unit:Dot(dir), -1, 1))
	return ang <= math.rad(arcDeg / 2) + math.atan2(tgt.radius, m)
end

function Core.has(ent, t)
	for _, s in ipairs(ent.statuses) do
		if s.t == t then
			return true
		end
	end
	return false
end

function Core.stunned(ent)
	for _, s in ipairs(ent.statuses) do
		if CC[s.t] then
			return true
		end
	end
	return false
end

function Core.rooted(ent)
	return Core.stunned(ent) or Core.has(ent, "root") or ent.sealingBy ~= nil
end

local function speedMul(ent)
	local m = 1
	for _, s in ipairs(ent.statuses) do
		if s.t == "slow" then
			m = math.min(m, 1 - s.val)
		end
	end
	for _, b in ipairs(ent.buffs) do
		if b.spd then
			m = m * (1 + b.spd)
		end
	end
	return m
end
Core.speedMul = speedMul

local function atkMul(ent)
	local m = 1
	for _, b in ipairs(ent.buffs) do
		if b.atk then
			m = m * (1 + b.atk)
		end
	end
	if Core.has(ent, "blind") then
		m = m * 0.5
	end
	return m
end

function Core.cdrMul(ent)
	local m = ent.stats.cdr
	for _, b in ipairs(ent.buffs) do
		if b.cdr then
			m = m * (1 - b.cdr)
		end
	end
	return m
end

local function lifesteal(ent)
	local l = 0
	for _, b in ipairs(ent.buffs) do
		if b.lifesteal then
			l = l + b.lifesteal
		end
	end
	return l
end

function Core.addStatus(ent, st, src, baseDmg)
	if ent.kind == "anchor" or not ent.alive then
		return
	end
	local dur = st.dur
	if ent.boss and (CC[st.t] or st.t == "root") then
		dur = dur * 0.35
	end
	local entry = { t = st.t, dur = dur, val = st.val or 0, src = src, tickT = 0.5 }
	if st.t == "burn" or st.t == "poison" then
		entry.dps = ((baseDmg or 10) * (st.val or 0.5) * 2) / math.max(1, st.dur)
	end
	for i, s in ipairs(ent.statuses) do
		if s.t == st.t then
			ent.statuses[i] = entry
			return
		end
	end
	table.insert(ent.statuses, entry)
end

function Core.cleanse(ent)
	local keep = {}
	for _, s in ipairs(ent.statuses) do
		if not NEG[s.t] then
			table.insert(keep, s)
		end
	end
	ent.statuses = keep
end

function Core.addShield(ent, amount, dur, reflect)
	ent.shield = math.max(ent.shield, amount)
	ent.shieldT = math.max(ent.shieldT, dur)
	ent.reflect = math.max(ent.reflect, reflect or 0)
end

function Core.heal(ent, amount, show)
	if not ent.alive then
		return 0
	end
	if ent.kind == "bench" then
		local s = ent.benchSlot
		s.hp = math.min(s.maxHp, s.hp + amount)
		ent.hp = s.hp
		return amount
	end
	local before = ent.hp
	ent.hp = math.min(ent.maxHp, ent.hp + amount)
	local h = ent.hp - before
	if h > 0 and show ~= false then
		Core.fx(ent.island, { t = "dmg", p = ent.pos + Vector3.new(0, ent.height + 1, 0), v = math.floor(h), k = "heal" })
	end
	return h
end

-- --- entidades ---------------------------------------------------------------
-- opts: creature, kind ("companion"|"wild"|"boss"|"anchor"), level, form, boss, owner, island, pos, glow, seal
function Core.spawn(opts)
	uid = uid + 1
	local def = GameData.CreatureById[opts.creature]
	local stats = Formulas.stats(opts.creature, opts.level, opts.form or 1, opts.boss)
	local ent = {
		id = "e" .. uid, kind = opts.kind, creature = opts.creature, def = def,
		level = opts.level, form = opts.form or 1, boss = opts.boss == true, owner = opts.owner,
		stats = stats, maxHp = stats.hp, hp = opts.hp or stats.hp, energy = 100, seal = 0,
		cds = { q = 0, e = 0, r = 0 }, statuses = {}, buffs = {}, shield = 0, shieldT = 0, reflect = 0,
		pos = opts.pos, facing = opts.facing or 0, island = opts.island, alive = true,
		knock = Vector3.zero, castLock = 0, iframes = 0.8, dodgeCd = 0, aiGcd = 1 + math.random(),
		strafe = (math.random() < 0.5) and 1 or -1, home = opts.pos, contributors = {}, moving = false,
	}
	local model, root, ap, ao, info = Factory.build(opts.creature, { form = ent.form, boss = ent.boss, glow = opts.glow, seal = opts.seal })
	ent.model, ent.root, ent.ap, ent.ao = model, root, ap, ao
	ent.height, ent.radius, ent.flyer = info.height, info.radius, info.flyer
	ap.MaxVelocity = math.max(stats.speed * 1.6, 30)
	local y = World.GroundY + (ent.flyer and info.height * 0.25 or 0)
	model:PivotTo(CFrame.new(Vector3.new(ent.pos.X, y, ent.pos.Z)) * CFrame.Angles(0, ent.facing, 0))
	ap.Position = Vector3.new(ent.pos.X, y, ent.pos.Z)
	ao.CFrame = CFrame.Angles(0, ent.facing, 0)
	model:SetAttribute("EntityId", ent.id)
	model:SetAttribute("Kind", ent.kind)
	model:SetAttribute("Level", ent.level)
	model:SetAttribute("Form", ent.form)
	model:SetAttribute("Boss", ent.boss)
	model:SetAttribute("HP", ent.hp)
	model:SetAttribute("MaxHP", ent.maxHp)
	model:SetAttribute("Sealable", false)
	model:SetAttribute("Island", ent.island)
	if opts.owner then
		model:SetAttribute("OwnerId", opts.owner.UserId)
	end
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	Core.entities[ent.id] = ent
	Core.fx(ent.island, { t = "summon", p = ent.pos, c = def.color, e = opts.effect or "anillo", h = ent.height })
	return ent
end

function Core.despawn(ent, fade)
	if not Core.entities[ent.id] then
		return
	end
	ent.alive = false
	Core.entities[ent.id] = nil
	if ent.model then
		if fade then
			Core.fx(ent.island, { t = "burst", p = ent.pos + Vector3.new(0, ent.height * 0.5, 0), c = ent.def.color, n = 30 })
		end
		ent.model:Destroy()
	end
end

-- enemigos de una entidad en su isla
function Core.foesOf(ent)
	local out = {}
	for _, e in pairs(Core.entities) do
		if e.alive and e.island == ent.island and e ~= ent and not e.sealingBy then
			if ent.kind == "companion" then
				if e.kind ~= "companion" then
					table.insert(out, e)
				end
			elseif e.kind == "companion" then
				table.insert(out, e)
			end
		end
	end
	return out
end

function Core.teamOf(ent)
	if ent.kind == "companion" and Core.hooks.teamOf then
		return Core.hooks.teamOf(ent)
	end
	return { ent }
end

-- --- daño ---------------------------------------------------------------------
function Core.damage(src, tgt, power, stat, ab, opts)
	opts = opts or {}
	if not tgt.alive then
		return 0
	end
	local island = tgt.island
	local labelPos = tgt.pos + Vector3.new(0, tgt.height + 1, 0)
	if tgt.iframes > 0 and not opts.dot then
		Core.fx(island, { t = "dmg", p = labelPos, v = 0, k = "miss" })
		return 0
	end
	if tgt.invuln then
		if not opts.dot and math.random() < 0.3 then
			Core.fx(island, { t = "dmg", p = labelPos, v = 0, k = "immune" })
		end
		return 0
	end
	local statVal = (stat == "m") and src.stats.mag or src.stats.atk
	local elem = opts.dot and 1 or Formulas.domainMult(src.def.el, tgt.def.el)
	local crit = (not opts.dot) and math.random() < 0.05 + src.def.stats.agi * 0.001
	local dmg = opts.raw or (power * statVal * 0.06 * (170 / (100 + tgt.def.stats.def)))
	if not opts.raw then
		dmg = dmg * elem * (crit and 1.5 or 1) * atkMul(src) * (0.92 + math.random() * 0.16)
	end
	if Core.has(tgt, "mark") then
		dmg = dmg * 1.15
	end
	if tgt.kind == "anchor" then
		dmg = math.max(dmg, tgt.maxHp * 0.04)
	end
	dmg = math.max(1, dmg)
	if tgt.shield > 0 then
		local absorbed = math.min(tgt.shield, dmg)
		tgt.shield = tgt.shield - absorbed
		dmg = dmg - absorbed
		if tgt.reflect > 0 and not opts.dot and src.alive and src ~= tgt then
			local r = absorbed * tgt.reflect
			if r > 1 then
				Core.later(0.05, function()
					Core.damage(tgt, src, 0, "m", nil, { raw = r, dot = true })
				end)
			end
		end
		if dmg <= 0 then
			Core.fx(island, { t = "dmg", p = labelPos, v = math.floor(absorbed), k = "shield" })
			return 0
		end
	end
	-- los jefes no caen: hay que sellarlos
	if tgt.boss and not tgt.sealed then
		dmg = math.min(dmg, tgt.hp - 1)
	end
	tgt.hp = tgt.hp - dmg
	tgt.lastHit = Core.time
	if src.owner then
		tgt.contributors[src.owner] = (tgt.contributors[src.owner] or 0) + dmg
	end
	if dmg > 0 then
		local ls = lifesteal(src)
		if ls > 0 and not opts.dot then
			Core.heal(src, dmg * ls, false)
		end
		local kind = (opts.dot and "dot") or (crit and "crit") or (elem > 1 and "adv") or (tgt.kind == "companion" and "taken") or ""
		Core.fx(island, { t = "dmg", p = labelPos, v = math.floor(dmg + 0.5), k = kind })
		if not opts.dot then
			Core.fx(island, { t = "hit", id = tgt.id, p = tgt.pos + Vector3.new(0, tgt.height * 0.5, 0), c = src.def.color, s = (crit or power > 7) and 1 or 0 })
			if src.kind == "companion" and (not ab or ab.key ~= "f") then
				src.seal = math.min(100, src.seal + 2.6)
			end
			if tgt.kind == "companion" then
				tgt.seal = math.min(100, tgt.seal + (dmg / tgt.maxHp) * 30)
			end
			if elem > 1 and Core.hooks.onAdvantage and src.owner then
				Core.hooks.onAdvantage(src.owner)
			end
		end
	end
	if ab and ab.status and not opts.dot then
		Core.addStatus(tgt, ab.status, src, dmg)
	end
	if tgt.model then
		tgt.model:SetAttribute("HP", math.max(0, tgt.hp))
	end
	-- umbral de sellado
	if tgt.kind == "wild" and tgt.hp > 0 and tgt.hp / tgt.maxHp < 0.25 and not tgt.sealable then
		tgt.sealable = true
		tgt.model:SetAttribute("Sealable", true)
		if Core.hooks.onSealable then
			Core.hooks.onSealable(tgt)
		end
	end
	if tgt.boss and tgt.phaseReady3 and tgt.hp / tgt.maxHp < 0.25 and not tgt.sealable and not tgt.invuln then
		tgt.sealable = true
		tgt.model:SetAttribute("Sealable", true)
		if Core.hooks.onSealable then
			Core.hooks.onSealable(tgt)
		end
	end
	if tgt.hp <= 0 then
		tgt.hp = 0
		if Core.hooks.onDown then
			Core.hooks.onDown(tgt, src)
		end
	end
	return dmg
end

function Core.knockback(t, dir, amount)
	if t.boss or t.kind == "anchor" then
		amount = amount * 0.2
	end
	t.knock = t.knock + dir * amount * 4
end

-- --- habilidades ----------------------------------------------------------------
local function clampIsland(ent, p, margin)
	return World.clampToIsland(ent.island, p, margin or 4)
end

local function clampRange(p, from, range)
	local d = flat(p - from)
	if d.Magnitude > range then
		d = d.Unit * range
	end
	return Vector3.new(from.X + d.X, World.GroundY, from.Z + d.Z)
end

function Core.cast(f, ab, aim)
	local color = f.def.color
	local glow = f.model and f.model:GetAttribute("Glow") or color
	f.facing = math.atan2(-aim.dir.X, -aim.dir.Z)
	f.castLock = (ab.type == "cone" and ab.dur and ab.dur > 0) and ab.dur or 0.22
	Core.fx(f.island, { t = "lunge", id = f.id })
	local island = f.island

	if ab.type == "melee" then
		if aim.target then
			local d = dist(f.pos, aim.target.pos) - aim.target.radius - f.radius * 0.5
			if d > ab.range * 0.7 and d < ab.range + 12 then
				f.dash = { dir = aim.dir, left = math.min(12, d - ab.range * 0.5), speed = 70, hit = {} }
			end
		end
		for h = 0, (ab.hits or 1) - 1 do
			Core.later(h * 0.13, function()
				if not f.alive then
					return
				end
				local front = f.pos + aim.dir * ab.range * 0.55
				Core.fx(island, { t = "slash", p = front + Vector3.new(0, f.height * 0.4, 0), d = aim.dir, c = glow, r = ab.range })
				for _, t in ipairs(Core.foesOf(f)) do
					if inCone(f, aim.dir, t, ab.range + f.radius * 0.5, ab.arc) then
						Core.damage(f, t, ab.power, ab.stat, ab)
					end
				end
			end)
		end
	elseif ab.type == "projectile" then
		local n = ab.count or 1
		local spread = math.rad(ab.spread or 0)
		for i = 0, n - 1 do
			local a = (n == 1) and 0 or (-spread / 2 + spread * i / (n - 1))
			local dir = rotateY(aim.dir, a)
			local start = f.pos + dir * f.radius * 0.8 + Vector3.new(0, math.min(5, f.height * 0.5), 0)
			table.insert(projectiles, { f = f, ab = ab, dir = dir, pos = start, left = ab.range, hit = {}, side = f.kind == "companion" })
			Core.fx(island, { t = "proj", p = start, d = dir, s = ab.speed, r = ab.range, c = glow, z = ab.radius })
		end
	elseif ab.type == "cone" then
		local ticks = ab.ticks or 1
		local dur = ab.dur or 0
		Core.fx(island, { t = "breath", p = f.pos + Vector3.new(0, f.height * 0.5, 0), d = aim.dir, r = ab.range, a = ab.arc, c = glow, dur = math.max(0.3, dur) })
		for i = 0, ticks - 1 do
			Core.later(dur * i / ticks, function()
				if not f.alive or (dur > 0 and Core.stunned(f)) then
					return
				end
				for _, t in ipairs(Core.foesOf(f)) do
					if inCone(f, aim.dir, t, ab.range, ab.arc) then
						Core.damage(f, t, ab.power, ab.stat, ab)
						if ab.knock then
							Core.knockback(t, aim.dir, ab.knock)
						end
						if i == ticks - 1 and ab.endStatus then
							Core.addStatus(t, ab.endStatus, f)
						end
					end
				end
			end)
		end
	elseif ab.type == "aoe" then
		local follow = (ab.range or 0) == 0
		local center = follow and f.pos or clampIsland(f, clampRange(aim.pos, f.pos, ab.range))
		local function doIt()
			if not f.alive then
				return
			end
			local c = follow and f.pos or center
			Core.fx(island, { t = "ring", p = c, r = ab.radius, c = glow })
			local ticks = ab.ticks or 1
			for i = 0, ticks - 1 do
				Core.later((ab.dur or 0) * i / ticks, function()
					local cc = follow and f.pos or c
					if ticks > 1 then
						Core.fx(island, { t = "ring", p = cc, r = ab.radius * 0.8, c = glow })
					end
					for _, t in ipairs(Core.foesOf(f)) do
						if dist(t.pos, cc) <= ab.radius + t.radius then
							if ab.power and ab.power > 0 then
								Core.damage(f, t, ab.power, ab.stat, ab)
							elseif ab.status then
								Core.addStatus(t, ab.status, f)
							end
							if ab.pull then
								t.pullTo = { pos = cc, speed = ab.pull, t = math.max(0.4, ab.dur or 0.5) }
							end
						end
					end
					if ab.selfHeal then
						Core.heal(f, f.maxHp * ab.selfHeal)
					end
				end)
			end
			if ab.final then
				Core.later((ab.dur or 0) + 0.05, function()
					local cc = follow and f.pos or c
					Core.fx(island, { t = "ring", p = cc, r = ab.radius * 0.6, c = glow, big = true })
					for _, t in ipairs(Core.foesOf(f)) do
						if dist(t.pos, cc) <= ab.radius * 0.6 + t.radius then
							Core.damage(f, t, ab.final, ab.stat, ab)
						end
					end
				end)
			end
		end
		if ab.delay and ab.delay > 0 then
			Core.fx(island, { t = "tele", p = follow and f.pos or center, r = ab.radius, c = color, time = ab.delay })
			Core.later(ab.delay, doIt)
		else
			doIt()
		end
	elseif ab.type == "dash" then
		local d = ab.range
		if aim.target then
			d = math.min(ab.range, dist(f.pos, aim.target.pos) + 3)
		end
		f.dash = { dir = aim.dir, left = d, speed = ab.speed, ab = ab, hit = {} }
		f.iframes = math.max(f.iframes, 0.2)
		Core.fx(island, { t = "trail", id = f.id, c = glow, time = d / ab.speed })
	elseif ab.type == "heal" then
		for _, t in ipairs(ab.team and Core.teamOf(f) or { f }) do
			if ab.cleanse then
				Core.cleanse(t)
			end
			local amount = t.maxHp * ab.pct
			if not ab.dur or ab.dur == 0 then
				Core.heal(t, amount)
			else
				local steps = math.ceil(ab.dur / 0.5)
				for i = 1, steps do
					Core.later(i * 0.5, function()
						Core.heal(t, amount / steps, i == 1)
					end)
				end
			end
		end
		Core.fx(island, { t = "pillar", p = f.pos, c = glow, h = 14 })
		if ab.burst then
			Core.fx(island, { t = "ring", p = f.pos, r = ab.burst.radius, c = glow })
			for _, t in ipairs(Core.foesOf(f)) do
				if dist(t.pos, f.pos) <= ab.burst.radius + t.radius then
					Core.damage(f, t, ab.burst.power, ab.burst.stat, ab)
				end
			end
		end
	elseif ab.type == "shield" then
		Core.addShield(f, f.maxHp * ab.pct, ab.dur, ab.reflect)
		Core.fx(island, { t = "shield", id = f.id, c = glow, time = ab.dur })
	elseif ab.type == "buff" then
		table.insert(f.buffs, { atk = ab.atk, spd = ab.spd, cdr = ab.cdr, lifesteal = ab.lifesteal, t = ab.dur })
		Core.fx(island, { t = "pillar", p = f.pos, c = glow, h = 18 })
	elseif ab.type == "zone" then
		local center = (ab.range and ab.range > 0) and clampIsland(f, clampRange(aim.pos, f.pos, ab.range)) or f.pos
		table.insert(zones, { f = f, ab = ab, pos = center, t = ab.dur, tickT = 0, inside = {} })
		Core.fx(island, { t = "zone", p = center, r = ab.radius, c = glow, time = ab.dur })
	elseif ab.type == "strike" then
		local foes = Core.foesOf(f)
		local marked = {}
		for _, t in ipairs(foes) do
			if Core.has(t, "mark") then
				table.insert(marked, t)
			end
		end
		local pool = (#marked > 0) and marked or foes
		for i = 1, ab.count do
			local p
			if ab.area or #pool == 0 then
				local base = (#pool > 0) and pool[(i - 1) % #pool + 1].pos or f.pos
				p = base + Vector3.new((math.random() - 0.5) * 20, 0, (math.random() - 0.5) * 20)
			else
				local t = pool[(i - 1) % #pool + 1]
				p = t.pos + Vector3.new((math.random() - 0.5) * 3, 0, (math.random() - 0.5) * 3)
			end
			p = clampIsland(f, p)
			Core.later((i - 1) * (ab.interval or 0.15), function()
				Core.fx(island, { t = "tele", p = p, r = ab.radius, c = color, time = ab.delay })
				Core.later(ab.delay, function()
					Core.fx(island, { t = (f.creature == "tortuga") and "tower" or "bolt", p = p, c = glow, r = ab.radius })
					for _, t in ipairs(Core.foesOf(f)) do
						if dist(t.pos, p) <= ab.radius + t.radius then
							Core.damage(f, t, ab.power, ab.stat, ab)
						end
					end
				end)
			end)
		end
	elseif ab.type == "mines" then
		for i = 1, ab.count do
			local a = f.facing + (i - (ab.count + 1) / 2) * 0.9
			local p = clampIsland(f, f.pos + Vector3.new(-math.sin(a) * 7, 0, -math.cos(a) * 7))
			table.insert(mines, { f = f, ab = ab, pos = p, arm = 0.6, life = 12 })
			Core.fx(island, { t = "mine", p = p, c = glow, time = 12 })
		end
	elseif ab.type == "revive" then
		if f.kind == "companion" and Core.hooks.reviveTeam then
			Core.hooks.reviveTeam(f, ab.pct)
		end
		Core.heal(f, f.maxHp * ab.pct)
		Core.fx(island, { t = "pillar", p = f.pos, c = glow, h = 30 })
		Core.fx(island, { t = "ring", p = f.pos, r = ab.radius, c = glow, big = true })
		for _, t in ipairs(Core.foesOf(f)) do
			if dist(t.pos, f.pos) <= ab.radius + t.radius then
				Core.damage(f, t, ab.power, ab.stat, ab)
				Core.addStatus(t, { t = "burn", dur = 3, val = 0.5 }, f, 10)
			end
		end
	end

	if ab.also then
		local a = ab.also
		if a.type == "shield" then
			local targets = (ab.key == "f" or ab.team) and Core.teamOf(f) or { f }
			for _, t in ipairs(targets) do
				Core.addShield(t, t.maxHp * a.pct, a.dur, a.reflect)
			end
			Core.fx(island, { t = "shield", id = f.id, c = glow, time = a.dur })
		elseif a.type == "buff" then
			table.insert(f.buffs, { atk = a.atk, spd = a.spd, cdr = a.cdr, lifesteal = a.lifesteal, t = a.dur })
		end
	end
end

-- --- simulación ----------------------------------------------------------------
local function stepEntity(e, dt)
	for _, k in ipairs({ "q", "e", "r" }) do
		e.cds[k] = math.max(0, e.cds[k] - dt)
	end
	e.energy = math.min(100, e.energy + dt * 10)
	e.iframes = math.max(0, e.iframes - dt)
	e.dodgeCd = math.max(0, e.dodgeCd - dt)
	e.castLock = math.max(0, e.castLock - dt)
	if e.shieldT > 0 then
		e.shieldT = e.shieldT - dt
		if e.shieldT <= 0 then
			e.shield, e.reflect = 0, 0
		end
	end
	for i = #e.buffs, 1, -1 do
		e.buffs[i].t = e.buffs[i].t - dt
		if e.buffs[i].t <= 0 then
			table.remove(e.buffs, i)
		end
	end
	local tint = nil
	for i = #e.statuses, 1, -1 do
		local s = e.statuses[i]
		s.dur = s.dur - dt
		if s.dps then
			s.tickT = s.tickT - dt
			if s.tickT <= 0 then
				s.tickT = s.tickT + 0.5
				local src = (s.src and s.src.alive) and s.src or e
				Core.damage(src, e, 0, "m", nil, { raw = s.dps * 0.5, dot = true })
			end
		end
		if not tint and (s.t == "freeze" or s.t == "petrify" or s.t == "poison" or s.t == "burn" or s.t == "stun" or s.t == "root") then
			tint = s.t
		end
		if s.dur <= 0 then
			table.remove(e.statuses, i)
		end
	end
	if e.model and e.model:GetAttribute("Status") ~= (tint or "") then
		e.model:SetAttribute("Status", tint or "")
	end
	-- embestidas y esquivas
	if e.dash then
		local step = math.min(e.dash.left, e.dash.speed * dt)
		e.pos = e.pos + e.dash.dir * step
		e.dash.left = e.dash.left - step
		e.facing = math.atan2(-e.dash.dir.X, -e.dash.dir.Z)
		if e.dash.ab then
			for _, t in ipairs(Core.foesOf(e)) do
				if not e.dash.hit[t] and dist(t.pos, e.pos) < t.radius + e.dash.ab.width then
					e.dash.hit[t] = true
					Core.damage(e, t, e.dash.ab.power, e.dash.ab.stat, e.dash.ab)
					if e.dash.ab.knock then
						Core.knockback(t, e.dash.dir, e.dash.ab.knock)
					end
				end
			end
		end
		if e.dash.left <= 0.05 then
			e.dash = nil
		end
	end
	if e.knock.Magnitude > 0.1 then
		e.pos = e.pos + e.knock * dt
		e.knock = e.knock * math.max(0, 1 - dt * 6)
	end
	if e.pullTo then
		local d = dist(e.pos, e.pullTo.pos)
		if d > 3 then
			e.pos = e.pos + Core.dirTo(e.pos, e.pullTo.pos) * math.min(d - 3, e.pullTo.speed * dt * (e.boss and 0.15 or 1))
		end
		e.pullTo.t = e.pullTo.t - dt
		if e.pullTo.t <= 0 then
			e.pullTo = nil
		end
	end
	e.pos = World.clampToIsland(e.island, e.pos, e.radius * 0.5 + 2)
end

local function applyMotion(e)
	if not e.root or not e.root.Parent then
		return
	end
	local y = World.GroundY + (e.flyer and e.height * 0.25 or 0)
	e.ap.Position = Vector3.new(e.pos.X, y, e.pos.Z)
	e.ao.CFrame = CFrame.Angles(0, e.facing, 0)
end

local function stepProjectiles(dt)
	for i = #projectiles, 1, -1 do
		local pr = projectiles[i]
		local step = pr.ab.speed * dt
		pr.pos = pr.pos + pr.dir * step
		pr.left = pr.left - step
		local done = pr.left <= 0 or not Core.entities[pr.f.id] and pr.f.kind ~= "companion"
		if not done then
			for _, t in ipairs(Core.foesOf(pr.f)) do
				if not pr.hit[t] and dist(t.pos, pr.pos) < t.radius + pr.ab.radius then
					pr.hit[t] = true
					if pr.ab.explode then
						Core.fx(pr.f.island, { t = "ring", p = pr.pos, r = pr.ab.explode, c = pr.f.def.color })
						for _, o in ipairs(Core.foesOf(pr.f)) do
							if dist(o.pos, pr.pos) < pr.ab.explode + o.radius then
								Core.damage(pr.f, o, pr.ab.power, pr.ab.stat, pr.ab)
							end
						end
					else
						Core.damage(pr.f, t, pr.ab.power, pr.ab.stat, pr.ab)
					end
					if pr.ab.pullBack and t.alive then
						t.pullTo = { pos = pr.f.pos, speed = 50, t = 0.5 }
					end
					if not pr.ab.pierce then
						done = true
						break
					end
				end
			end
		end
		if done then
			table.remove(projectiles, i)
		end
	end
end

local function stepZones(dt)
	for i = #zones, 1, -1 do
		local z = zones[i]
		z.t = z.t - dt
		z.tickT = z.tickT - dt
		if z.tickT <= 0 then
			z.tickT = z.tickT + (z.ab.tick or 0.5)
			if z.ab.heal then
				for _, t in ipairs(Core.teamOf(z.f)) do
					if t.alive and t.island == z.f.island and dist(t.pos, z.pos) < z.ab.radius + t.radius then
						Core.heal(t, t.maxHp * z.ab.heal)
					end
				end
			else
				for _, t in ipairs(Core.foesOf(z.f)) do
					if dist(t.pos, z.pos) < z.ab.radius + t.radius then
						Core.damage(z.f, t, z.ab.power, z.ab.stat, z.ab)
						if z.ab.freezeAfter then
							z.inside[t] = (z.inside[t] or 0) + (z.ab.tick or 0.5)
							if z.inside[t] >= z.ab.freezeAfter and not Core.has(t, "freeze") then
								Core.addStatus(t, { t = "freeze", dur = 1.5 }, z.f)
							end
						end
					end
				end
			end
		end
		if z.t <= 0 then
			table.remove(zones, i)
		end
	end
end

local function stepMines(dt)
	for i = #mines, 1, -1 do
		local m = mines[i]
		m.arm = m.arm - dt
		m.life = m.life - dt
		local boom = m.life <= 0
		if m.arm <= 0 then
			for _, t in ipairs(Core.foesOf(m.f)) do
				if dist(t.pos, m.pos) < m.ab.radius + t.radius then
					boom = true
				end
			end
		end
		if boom then
			Core.fx(m.f.island, { t = "ring", p = m.pos, r = m.ab.radius * 1.4, c = m.f.def.color })
			for _, t in ipairs(Core.foesOf(m.f)) do
				if dist(t.pos, m.pos) < m.ab.radius * 1.4 + t.radius then
					Core.damage(m.f, t, m.ab.power, m.ab.stat, m.ab)
				end
			end
			table.remove(mines, i)
		end
	end
end

-- separación para que no se monten unas sobre otras
local function separate(list)
	for i = 1, #list do
		for j = i + 1, #list do
			local a, b = list[i], list[j]
			if a.island == b.island then
				local d = flat(b.pos - a.pos)
				local m = d.Magnitude
				local min = (a.radius + b.radius) * 0.7
				if m < min and m > 0.01 then
					local push = (min - m) / 2
					local wa = a.boss and 0.1 or 1
					local wb = b.boss and 0.1 or 1
					a.pos = a.pos - d.Unit * push * wa
					b.pos = b.pos + d.Unit * push * wb
				end
			end
		end
	end
end

function Core.step(dt)
	Core.time = Core.time + dt
	if #timers > 0 then
		local due = {}
		local keep = {}
		for _, t in ipairs(timers) do
			if t.t <= Core.time then
				table.insert(due, t)
			else
				table.insert(keep, t)
			end
		end
		timers = keep
		for _, t in ipairs(due) do
			local ok, err = pcall(t.fn)
			if not ok then
				warn("[Sellos Arcanos] temporizador:", err)
			end
		end
	end
	local list = {}
	for _, e in pairs(Core.entities) do
		if e.alive and e.kind ~= "anchor" then
			stepEntity(e, dt)
			table.insert(list, e)
		end
	end
	separate(list)
	stepProjectiles(dt)
	stepZones(dt)
	stepMines(dt)
	for _, e in ipairs(list) do
		applyMotion(e)
	end
	flushFx()
end

function Core.applyMotion(e)
	applyMotion(e)
end

Core.flat = flat
Core.CollectionService = CollectionService
return Core
