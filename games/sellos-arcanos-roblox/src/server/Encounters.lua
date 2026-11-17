-- Encuentros: criaturas salvajes de cada isla (con IA y avisos en el suelo),
-- jefes Primordiales de tres fases con cuatro anclas rúnicas, sellado validado
-- en el servidor, recompensas y viajes entre la Ciudadela y las islas.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameData = require(Shared.GameData)
local Formulas = require(Shared.Formulas)
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local Core = require(script.Parent.CombatCore)
local DataService = require(script.Parent.DataService)
local Progression = require(script.Parent.ProgressionService)
local Companions = require(script.Parent.Companions)
local World = require(script.Parent.WorldService)

local Encounters = {}
local wild = {} -- island -> {entities}
local respawnAt = {} -- island -> lista de tiempos
local bosses = {} -- island -> estado del jefe
local emptySince = {} -- island -> tiempo sin jugadores

local function playersOn(island)
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl:GetAttribute("Island") == island then
			table.insert(list, pl)
		end
	end
	return list
end

local function banner(island, key, vars, kind)
	for _, pl in ipairs(playersOn(island)) do
		Net.get("Banner"):FireClient(pl, key, vars or {}, kind or "")
	end
end

-- --- viajes ------------------------------------------------------------------
function Encounters.teleport(player, pos)
	local ch = player.Character
	if not ch then
		return
	end
	pcall(function()
		player:RequestStreamAroundAsync(pos, 5)
	end)
	ch:PivotTo(CFrame.new(pos))
	player:SetAttribute("Island", World.islandAt(pos))
end

function Encounters.toHub(player)
	Encounters.teleport(player, World.Hub.spawn)
end
Companions.toHub = Encounters.toHub

local function onPortal(player, prompt)
	local idx = prompt:GetAttribute("IslandIndex")
	local p = DataService.get(player)
	if not p or not idx then
		return
	end
	if not p.starterChosen then
		Progression.toast(player, "chooseFirstToast", {}, "")
		return
	end
	if idx > p.islands.unlocked then
		local prev = GameData.Islands[idx - 1]
		Progression.toast(player, "portalLocked", { isle = prev and prev.index or 1 }, "bad")
		return
	end
	Encounters.teleport(player, World.Islands[idx].spawn)
	Net.get("Banner"):FireClient(player, "islandEnter", { i = idx }, "island")
end

-- --- criaturas salvajes ---------------------------------------------------------
local function spawnWild(island)
	local isl = GameData.Islands[island]
	local w = World.Islands[island]
	local id = isl.pool[math.random(1, #isl.pool)]
	local lvl = math.random(isl.levels[1], isl.levels[2])
	local a = math.random() * math.pi * 2
	local r = math.random() * w.wildRadius
	local pos = World.clampToIsland(island, w.wildCenter + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), 10)
	local ent = Core.spawn({ creature = id, kind = "wild", level = lvl, form = 1, island = island, pos = pos, facing = math.random() * 6.28 })
	ent.home = pos
	table.insert(wild[island], ent)
	return ent
end

local function nearestCompanion(e, range)
	local best, bd = nil, range
	for _, o in pairs(Core.entities) do
		if o.alive and o.kind == "companion" and o.island == e.island then
			local d = Core.dist(o.pos, e.pos)
			if d < bd then
				best, bd = o, d
			end
		end
	end
	return best, bd
end

local TELEGRAPHED = { cone = true, aoe = true, dash = true, zone = true, revive = true }

local function aiStep(e, dt)
	if not e.alive or Core.stunned(e) or e.sealingBy then
		e.moving = false
		return
	end
	-- objetivo
	if e.target and (not e.target.alive or e.target.island ~= e.island) then
		e.target = nil
	end
	if not e.target then
		e.target = nearestCompanion(e, e.boss and 200 or Config.AggroRange)
	end
	-- correa: si se aleja demasiado vuelve a casa y se recupera
	if not e.boss and Core.dist(e.pos, e.home) > Config.LeashRange then
		e.target = nil
		e.returning = true
	end
	local t = e.target
	if e.windup then
		e.windup.t = e.windup.t - dt
		e.moving = false
		e.facing = math.atan2(-e.windup.dir.X, -e.windup.dir.Z)
		if e.windup.t <= 0 then
			local w = e.windup
			e.windup = nil
			Core.cast(e, w.ab, { dir = w.dir, pos = w.pos, target = t })
		end
		return
	end
	local speed = e.stats.speed * Core.speedMul(e) * (e.boss and 0.7 or 0.62)
	if not t then
		-- deambular cerca de casa
		e.wanderT = (e.wanderT or 0) - dt
		if e.returning or e.wanderT <= 0 or not e.wanderGoal then
			if e.returning then
				e.wanderGoal = e.home
				if Core.dist(e.pos, e.home) < 4 then
					e.returning = false
					e.hp = e.maxHp
					e.sealable = false
					e.model:SetAttribute("HP", e.hp)
					e.model:SetAttribute("Sealable", false)
				end
			else
				local a = math.random() * math.pi * 2
				e.wanderGoal = World.clampToIsland(e.island, e.home + Vector3.new(math.cos(a) * 16, 0, math.sin(a) * 16), 8)
				e.wanderT = 3 + math.random() * 4
			end
		end
		local d = Core.flat(e.wanderGoal - e.pos)
		if d.Magnitude > 1.5 and not Core.rooted(e) then
			e.pos = e.pos + d.Unit * math.min(d.Magnitude, speed * (e.returning and 2 or 0.45) * dt)
			e.facing = math.atan2(-d.Unit.X, -d.Unit.Z)
			e.moving = true
		else
			e.moving = false
		end
		return
	end
	local toP = Core.dirTo(e.pos, t.pos)
	local distT = Core.dist(e.pos, t.pos)
	local first = e.def.abilities[1]
	local meleeish = first.type == "melee" or first.type == "dash"
	local want = (meleeish and 5 or 18) + e.radius + t.radius
	e.aiGcd = e.aiGcd - dt
	if e.aiGcd <= 0 and e.castLock <= 0 and not e.dash then
		local keys = e.boss and { "f", "r", "e", "q" } or (e.form >= 2 and { "r", "e", "q" } or { "e", "q" })
		for _, k in ipairs(keys) do
			local ab = e.def.abilityByKey[k]
			local ready = ab and ((k == "f" and e.seal >= 100) or (k ~= "f" and e.cds[k] <= 0))
			local inRange = ab and (ab.type == "heal" or ab.type == "shield" or ab.type == "buff" or distT <= (ab.range or 14) + t.radius + 2)
			if ab and ab.type == "heal" and e.hp / e.maxHp > 0.6 then
				inRange = false
			end
			if ready and inRange then
				if k == "f" then
					e.seal = 0
				else
					local phase = e.bossPhase or 1
					e.cds[k] = ab.cd * (e.boss and (phase >= 2 and 1.3 or 1.6) or 2.2)
				end
				local wind = e.boss and ((e.bossPhase or 1) >= 3 and 0.5 or 0.65) or 0.75
				local pos = t.pos
				if TELEGRAPHED[ab.type] or k == "f" then
					e.windup = { ab = ab, dir = toP, pos = pos, t = wind }
					if ab.type == "cone" then
						Core.fx(e.island, { t = "tele", p = e.pos, r = ab.range, cone = ab.arc, d = toP, time = wind, c = "#ff3355" })
					elseif ab.type == "dash" then
						Core.fx(e.island, { t = "tele", p = e.pos, len = ab.range, w = ab.width * 1.6, d = toP, time = wind, c = "#ff3355" })
					elseif ab.type == "aoe" then
						Core.fx(e.island, { t = "tele", p = (ab.range and ab.range > 0) and pos or e.pos, r = ab.radius, time = wind, c = "#ff3355" })
					elseif ab.type == "zone" then
						Core.fx(e.island, { t = "tele", p = pos, r = ab.radius, time = wind, c = "#ff3355" })
					else
						Core.fx(e.island, { t = "tele", p = e.pos, r = ab.radius or 12, time = wind, c = "#ff3355" })
					end
				elseif ab.type == "melee" or ab.type == "projectile" then
					e.windup = { ab = ab, dir = toP, pos = pos, t = 0.28 }
				else
					Core.cast(e, ab, { dir = toP, pos = pos, target = t })
				end
				e.aiGcd = e.boss and ((e.bossPhase or 1) >= 2 and 0.9 or 1.2) or (1.4 + math.random() * 1.2)
				if e.boss then
					e.seal = math.min(100, e.seal + 12)
				end
				return
			end
		end
	end
	if Core.rooted(e) or e.dash then
		e.moving = false
		return
	end
	local mv = Vector3.zero
	if distT > want + 1 then
		mv = toP
	elseif distT < want - 4 then
		mv = -toP
	end
	if not e.boss then
		mv = mv + Vector3.new(-toP.Z, 0, toP.X) * e.strafe * 0.5
		if math.random() < dt * 0.3 then
			e.strafe = -e.strafe
		end
	end
	if mv.Magnitude > 0.01 then
		e.pos = e.pos + mv.Unit * speed * dt
		e.moving = true
	else
		e.moving = false
	end
	e.facing = math.atan2(-toP.X, -toP.Z)
end

-- --- recompensas ------------------------------------------------------------------
local function giveTeamXp(player, xp)
	local p = DataService.get(player)
	local st = Companions.state(player)
	local ups = {}
	for i, id in ipairs(p.team) do
		local own = p.creatures[id]
		if own then
			local share = (st and st.active == i) and 1 or 0.5
			local n = Progression.giveXp(own, xp * share)
			Progression.addBond(own, share >= 1 and 2 or 1)
			if n > 0 then
				table.insert(ups, { id = id, level = own.level })
			end
		end
	end
	if #ups > 0 then
		Companions.refreshLevels(player)
		for _, u in ipairs(ups) do
			Progression.toast(player, "levelUp", { id = u.id, n = u.level }, "gold")
		end
	end
end

local function rewardKill(e)
	local total = 0
	for _, dmg in pairs(e.contributors) do
		total = total + dmg
	end
	for player, dmg in pairs(e.contributors) do
		if player.Parent and DataService.get(player) and dmg >= total * 0.1 then
			local p = DataService.get(player)
			local xp = 10 + e.level * 6
			local ess = 15 + e.level * 4
			p.essence = p.essence + ess
			p.stats.kills = p.stats.kills + 1
			giveTeamXp(player, xp)
			Progression.addRankXp(player, xp * 0.6)
			Progression.addPassXp(player, 4)
			Progression.progress(player, "kills")
			Net.get("Reward"):FireClient(player, { essence = ess, xp = xp })
			DataService.sync(player)
		end
	end
end

-- --- jefes Primordiales ----------------------------------------------------------
local function spawnAnchor(b, pos)
	local color = Color3.fromHex(b.ent.def.color)
	local p = World.part({
		Size = Vector3.new(3.5, 11, 3.5),
		CFrame = CFrame.new(pos + Vector3.new(0, 8, 0)) * CFrame.Angles(0, math.rad(45), 0),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
		CanCollide = false,
	})
	p.Name = "AnclaRunica"
	local m = Instance.new("Model")
	m.Name = "AnclaRunica"
	p.Parent = m
	local beam = World.part({ Size = Vector3.new(0.4, 0.4, (pos - b.ent.pos).Magnitude), CFrame = CFrame.lookAt((pos + b.ent.pos) / 2 + Vector3.new(0, 6, 0), b.ent.pos + Vector3.new(0, 6, 0)), Color = color, Material = Enum.Material.Neon, Transparency = 0.4, CanCollide = false, CanQuery = false })
	beam.Parent = m
	local hp = math.floor(b.ent.maxHp * 0.045)
	m:SetAttribute("HP", hp)
	m:SetAttribute("MaxHP", hp)
	m:SetAttribute("Kind", "anchor")
	m:SetAttribute("Island", b.island)
	m:SetAttribute("CreatureId", b.ent.creature)
	m.Parent = workspace:FindFirstChild("Criaturas")
	local a = {
		id = "a" .. tostring(math.random(1, 1e9)), kind = "anchor", alive = true, island = b.island, pos = pos, radius = 3,
		height = 12, hp = hp, maxHp = hp, def = b.ent.def, statuses = {}, buffs = {}, shield = 0, shieldT = 0, reflect = 0,
		iframes = 0, knock = Vector3.zero, contributors = {}, model = m, stats = b.ent.stats, level = b.ent.level, form = 1,
	}
	m:SetAttribute("EntityId", a.id)
	Core.entities[a.id] = a
	table.insert(b.anchors, a)
end

function Encounters.startBoss(player, island)
	if bosses[island] then
		return
	end
	local p = DataService.get(player)
	if not p or not p.starterChosen then
		return
	end
	local isl = GameData.Islands[island]
	local w = World.Islands[island]
	local nPlayers = math.max(1, #playersOn(island))
	local ent = Core.spawn({ creature = isl.boss, kind = "boss", level = isl.levels[2], form = 3, boss = true, island = island, pos = w.bossArena, facing = math.atan2(w.toHub.X, w.toHub.Z) })
	local mult = 1 + 0.5 * (nPlayers - 1)
	ent.maxHp = math.floor(ent.maxHp * mult)
	ent.hp = ent.maxHp
	ent.home = w.bossArena
	ent.bossPhase = 1
	ent.aiGcd = 2.5
	ent.model:SetAttribute("HP", ent.hp)
	ent.model:SetAttribute("MaxHP", ent.maxHp)
	bosses[island] = { ent = ent, island = island, anchors = {}, lastNear = Core.time }
	Core.fx(island, { t = "pillar", p = ent.pos, c = ent.def.color, h = 60 })
	Core.fx(island, { t = "roar", p = ent.pos })
	banner(island, "bossAppears", { id = ent.creature }, "boss")
	w.bossPrompt.Enabled = false
end

local function endBoss(island)
	local b = bosses[island]
	if not b then
		return
	end
	for _, a in ipairs(b.anchors) do
		if a.model then
			a.model:Destroy()
		end
		Core.entities[a.id] = nil
	end
	if b.ent.alive then
		Core.despawn(b.ent, true)
	end
	for _, add in ipairs(b.adds or {}) do
		if add.alive then
			Core.despawn(add, true)
		end
	end
	bosses[island] = nil
	World.Islands[island].bossPrompt.Enabled = true
end

local function bossStep(island, b, dt)
	local e = b.ent
	if not e.alive then
		endBoss(island)
		return
	end
	local near = nearestCompanion(e, 220)
	if near then
		b.lastNear = Core.time
	elseif Core.time - b.lastNear > 40 then
		endBoss(island)
		return
	end
	local k = e.hp / e.maxHp
	if e.bossPhase == 1 and k < 0.66 then
		e.bossPhase = 2
		banner(island, "phase", { n = 2 }, "boss")
		Core.fx(island, { t = "roar", p = e.pos })
		b.adds = {}
		local pool = GameData.Islands[island].pool
		for i = 1, 2 do
			local id = pool[(i % #pool) + 1]
			local a = math.random() * math.pi * 2
			local add = Core.spawn({ creature = id, kind = "wild", level = math.max(1, e.level - 4), form = 1, island = island, pos = World.clampToIsland(island, e.pos + Vector3.new(math.cos(a) * 24, 0, math.sin(a) * 24), 8) })
			add.home = add.pos
			add.noRespawn = true
			table.insert(b.adds, add)
		end
	elseif e.bossPhase == 2 and k < 0.34 then
		e.bossPhase = 3
		e.invuln = true
		e.model:SetAttribute("Invuln", true)
		banner(island, "anchors", {}, "boss")
		Core.fx(island, { t = "roar", p = e.pos })
		for i = 0, 3 do
			local a = math.pi / 4 + i * math.pi / 2
			spawnAnchor(b, World.clampToIsland(island, e.pos + Vector3.new(math.cos(a) * 28, 0, math.sin(a) * 28), 6))
		end
	end
	if e.sealingBy and Core.time > (e.sealDeadline or 0) then
		Encounters.resolveSeal(e.sealingBy, e, { done = false })
	end
end

-- --- caídas ------------------------------------------------------------------------
function Encounters.onDown(e, src)
	if e.kind == "anchor" then
		e.alive = false
		Core.entities[e.id] = nil
		Core.fx(e.island, { t = "burst", p = e.pos + Vector3.new(0, 8, 0), c = e.def.color, n = 40 })
		if e.model then
			e.model:Destroy()
		end
		local b = bosses[e.island]
		if b then
			local left = 0
			for _, a in ipairs(b.anchors) do
				if a.alive then
					left = left + 1
				end
			end
			if left == 0 then
				b.ent.invuln = false
				b.ent.phaseReady3 = true
				b.ent.model:SetAttribute("Invuln", false)
				Core.addStatus(b.ent, { t = "stun", dur = 9 }, e)
				banner(e.island, "anchorsBroken", {}, "gold")
			end
		end
		return
	end
	if e.kind == "companion" then
		Companions.onFaint(e)
		return
	end
	if e.kind == "wild" then
		rewardKill(e)
		Core.despawn(e, true)
		if not e.noRespawn and wild[e.island] then
			table.insert(respawnAt[e.island], Core.time + Config.WildRespawn)
		end
	end
end

-- --- sellado --------------------------------------------------------------------------
local function sealRequest(player, entId)
	local e = Core.entities[entId]
	local p = DataService.get(player)
	if not e or not p or not e.alive or not e.sealable or e.sealingBy then
		return nil
	end
	if player:GetAttribute("Island") ~= e.island then
		return nil
	end
	local st = Companions.state(player)
	local anchor = (st and st.ent and st.ent.pos) or e.pos
	if Core.dist(anchor, e.pos) > 90 then
		return nil
	end
	if not e.boss then
		DataService.tickInk(p)
		if p.ink <= 0 then
			return { error = "noInk" }
		end
		if p.ink >= Config.InkMax then
			p.inkTs = os.time()
		end
		p.ink = p.ink - 1
		DataService.sync(player)
	end
	local nodes = e.boss and 9 or math.clamp(e.def.nodes - 2 + math.floor((e.island - 1) / 4), 4, 7)
	local time = e.boss and 7 or 5
	e.sealingBy = player
	e.invuln = true
	e.sealStart = Core.time
	e.sealDeadline = Core.time + time + 6
	e.sealNodes = nodes
	e.sealTime = time
	return { nodes = nodes, time = time, moving = e.boss or e.form >= 2, color = e.model:GetAttribute("Glow") or e.def.color, id = e.creature, boss = e.boss, seed = math.random(1, 100000) }
end

function Encounters.resolveSeal(player, e, result)
	if not e or e.sealingBy ~= player then
		return
	end
	e.sealingBy = nil
	e.invuln = false
	local elapsed = Core.time - (e.sealStart or Core.time)
	local done = type(result) == "table" and result.done == true and elapsed >= e.sealNodes * 0.12
	local errors = (type(result) == "table" and tonumber(result.errors)) or 3
	if not done then
		Core.heal(e, e.maxHp * 0.1, false)
		if e.hp / e.maxHp >= 0.25 then
			e.sealable = false
			e.model:SetAttribute("Sealable", false)
		end
		Core.fx(e.island, { t = "dmg", p = e.pos + Vector3.new(0, e.height + 1, 0), v = 0, k = "resist" })
		return
	end
	local perfect = errors == 0 and elapsed <= e.sealTime * (e.boss and 0.75 or 0.65) + 1
	e.sealed = true
	Core.fx(e.island, { t = "sealed", p = e.pos, c = e.model:GetAttribute("Glow") or e.def.color, h = e.height })
	-- recompensas: quien sella; en los jefes, todos los participantes
	local winners = {}
	if e.boss then
		for _, pl in ipairs(playersOn(e.island)) do
			local st = Companions.state(pl)
			if (st and st.ent and Core.dist(st.ent.pos, e.pos) < 160) or e.contributors[pl] then
				table.insert(winners, pl)
			end
		end
		if not table.find(winners, player) then
			table.insert(winners, player)
		end
	else
		winners = { player }
	end
	for _, pl in ipairs(winners) do
		local p = DataService.get(pl)
		if p then
			local summary = { sealed = e.creature, perfect = perfect and pl == player, boss = e.boss }
			local ess = math.floor((25 + e.level * 6) * ((perfect and pl == player) and 1.5 or 1))
			local xp = math.floor((10 + e.level * 6) * 1.2)
			if e.boss then
				ess = ess + 600 + e.level * 25
				xp = xp + 200 + e.level * 20
				local isl = e.island
				local el = e.def.el
				local first = not table.find(p.islands.cleared, isl)
				local frags = first and 12 or 6
				p.fragments[el] = (p.fragments[el] or 0) + frags
				summary.fragments = frags
				if first then
					table.insert(p.islands.cleared, isl)
					p.stats.bosses = p.stats.bosses + 1
					p.crystals = p.crystals + 25
					summary.crystals = 25
					if isl < #GameData.Islands and p.islands.unlocked < isl + 1 then
						p.islands.unlocked = isl + 1
						summary.unlocked = isl + 1
					end
				end
				Progression.progress(pl, "boss")
				-- el Primordial sellado se une como Cría si no la tenías
				local res = Progression.addCreature(pl, e.creature, GameData.Islands[isl].levels[1], perfect and pl == player)
				summary.isNew = res.isNew
				Progression.addPassXp(pl, 40)
			else
				local res = Progression.addCreature(pl, e.creature, e.level, perfect)
				summary.isNew = res.isNew
				summary.fragments = res.fragments
				Progression.addPassXp(pl, 10)
			end
			p.essence = p.essence + ess
			summary.essence = ess
			summary.xp = xp
			p.stats.seals = p.stats.seals + 1
			if perfect and pl == player then
				p.stats.perfect = p.stats.perfect + 1
				Progression.progress(pl, "perfect")
			end
			Progression.progress(pl, "seal")
			giveTeamXp(pl, xp)
			Progression.addRankXp(pl, xp * 0.6 + 25 + (e.boss and 150 or 0))
			Net.get("Reward"):FireClient(pl, summary)
			DataService.sync(pl)
			if summary.isNew then
				Companions.rebuild(pl, true)
			end
		end
	end
	if e.boss then
		task.delay(1.5, function()
			endBoss(e.island)
		end)
		Core.despawn(e, false)
	else
		Core.despawn(e, false)
		if not e.noRespawn and wild[e.island] then
			table.insert(respawnAt[e.island], Core.time + Config.WildRespawn)
		end
	end
end

-- --- bucle --------------------------------------------------------------------------
function Encounters.step(dt)
	for island = 1, #GameData.Islands do
		local list = wild[island]
		-- limpia muertos
		for i = #list, 1, -1 do
			if not list[i].alive then
				table.remove(list, i)
			end
		end
		local here = #playersOn(island) > 0
		if here then
			emptySince[island] = nil
			local pending = respawnAt[island]
			for i = #pending, 1, -1 do
				if pending[i] <= Core.time then
					table.remove(pending, i)
				end
			end
			if #list + #pending < Config.WildPerIsland then
				spawnWild(island)
			end
		else
			emptySince[island] = emptySince[island] or Core.time
			if Core.time - emptySince[island] > 30 and #list > 0 then
				for _, e in ipairs(list) do
					Core.despawn(e, false)
				end
				wild[island] = {}
				respawnAt[island] = {}
			end
		end
		for _, e in ipairs(wild[island]) do
			if e.alive then
				aiStep(e, dt)
				if e.sealingBy and Core.time > (e.sealDeadline or 0) then
					Encounters.resolveSeal(e.sealingBy, e, { done = false })
				end
			end
		end
		local b = bosses[island]
		if b then
			if b.ent.alive then
				aiStep(b.ent, dt)
			end
			for _, add in ipairs(b.adds or {}) do
				if add.alive then
					aiStep(add, dt)
				end
			end
			bossStep(island, b, dt)
		end
	end
end

function Encounters.init()
	for i = 1, #GameData.Islands do
		wild[i] = {}
		respawnAt[i] = {}
	end
	Core.hooks.onDown = Encounters.onDown
	Core.hooks.onSealable = function(e)
		Core.fx(e.island, { t = "sealable", id = e.id, p = e.pos, c = e.def.color })
	end
	Core.hooks.onAdvantage = function(player)
		Progression.progress(player, "advantage")
	end
	for _, prompt in ipairs(World.Hub.portals) do
		prompt.Triggered:Connect(function(player)
			onPortal(player, prompt)
		end)
	end
	World.Hub.fountain.Triggered:Connect(function(player)
		Companions.restore(player)
		Progression.toast(player, "restored", {}, "good")
	end)
	for i, w in ipairs(World.Islands) do
		w.returnPrompt.Triggered:Connect(function(player)
			Encounters.toHub(player)
			Companions.restore(player)
		end)
		w.bossPrompt.Triggered:Connect(function(player)
			Encounters.startBoss(player, i)
		end)
	end
	Net.get("SealRequest").OnServerInvoke = function(player, entId)
		if type(entId) ~= "string" then
			return nil
		end
		return sealRequest(player, entId)
	end
	Net.get("SealResult").OnServerEvent:Connect(function(player, entId, result)
		local e = type(entId) == "string" and Core.entities[entId] or nil
		if e then
			Encounters.resolveSeal(player, e, result)
		end
	end)
end

Encounters.Formulas = Formulas
return Encounters
