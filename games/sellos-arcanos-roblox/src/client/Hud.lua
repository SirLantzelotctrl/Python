-- HUD de combate y barra superior (monedas y menús).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameData = require(Shared.GameData)
local Formulas = require(Shared.Formulas)
local Config = require(Shared.Config)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)

local Hud = {}
local C = UI.C
local refs = {}
local player = Players.LocalPlayer

local function creatureColor(id)
	return Color3.fromHex(GameData.CreatureById[id].color)
end

local function shortName(id)
	local n = UI.L(GameData.CreatureById[id].name)
	local first = string.match(n, "^(%S+)")
	return first or n
end
Hud.shortName = shortName

local function build()
	local root = UI.root
	-- --- criatura activa (arriba a la izquierda) ---
	local self = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 16), Size = UDim2.fromOffset(330, 150) }, root)
	refs.self = self
	local badge = UI.panel(self, { Size = UDim2.fromOffset(64, 64), BackgroundColor3 = C.night })
	refs.badgeStroke = badge:FindFirstChildOfClass("UIStroke")
	refs.badgeStroke.Thickness = 2.5
	refs.badgeLetter = UI.label(badge, "", 30, UI.F.title, C.bright, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	refs.name = UI.label(self, "", 18, UI.F.bold, C.bright, { Position = UDim2.fromOffset(76, 0), Size = UDim2.fromOffset(170, 22), TextStrokeTransparency = 0.6 })
	refs.level = UI.label(self, "", 16, UI.F.bold, C.bright, { Position = UDim2.fromOffset(250, 0), Size = UDim2.fromOffset(76, 22), TextXAlignment = Enum.TextXAlignment.Right })
	local hpBack, hpFill = UI.bar(self, C.bright, 9, { Position = UDim2.fromOffset(76, 26), Size = UDim2.fromOffset(250, 9) })
	refs.hpFill = hpFill
	local _ = hpBack
	refs.hpText = UI.label(self, "", 12, UI.F.medium, C.muted, { Position = UDim2.fromOffset(76, 37), Size = UDim2.fromOffset(250, 14), TextXAlignment = Enum.TextXAlignment.Right })
	UI.label(self, UI.t("hp"), 12, UI.F.bold, C.muted, { Position = UDim2.fromOffset(76, 37), Size = UDim2.fromOffset(120, 14) })
	local _, enFill = UI.bar(self, C.inkBlue, 5, { Position = UDim2.fromOffset(76, 54), Size = UDim2.fromOffset(250, 5) })
	refs.enFill = enFill
	local _, slFill = UI.bar(self, C.accent, 5, { Position = UDim2.fromOffset(76, 62), Size = UDim2.fromOffset(250, 5) })
	refs.slFill = slFill
	refs.slText = UI.label(self, "", 12, UI.F.medium, C.muted, { Position = UDim2.fromOffset(76, 69), Size = UDim2.fromOffset(250, 14) })
	-- equipo 1 · 2 · 3
	local slots = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 92), Size = UDim2.fromOffset(330, 52) }, self)
	UI.list(slots, Enum.FillDirection.Horizontal, 8)
	refs.slots = {}
	for i = 1, 3 do
		local b = UI.button(slots, "", { Size = UDim2.fromOffset(52, 52), LayoutOrder = i, TextSize = 22, Font = UI.F.title }, function()
			State.switch(i)
		end)
		local key = UI.label(b, tostring(i), 11, UI.F.bold, C.bright, { Position = UDim2.new(1, -14, 1, -15), Size = UDim2.fromOffset(12, 12), TextXAlignment = Enum.TextXAlignment.Center })
		local _2 = key
		local _3, fill = UI.bar(b, C.ok, 4, { Position = UDim2.new(0, 4, 1, -7), Size = UDim2.new(1, -8, 0, 4) })
		refs.slots[i] = { button = b, fill = fill, stroke = b:FindFirstChildOfClass("UIStroke") }
	end

	-- --- objetivo (arriba al centro) ---
	local target = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16), Size = UDim2.fromOffset(440, 64), Visible = false }, root)
	refs.target = target
	refs.tName = UI.label(target, "", 18, UI.F.bold, C.bright, { Size = UDim2.new(1, -120, 0, 22), TextStrokeTransparency = 0.6 })
	refs.tLevel = UI.label(target, "", 14, UI.F.medium, C.muted, { Position = UDim2.new(1, -150, 0, 0), Size = UDim2.fromOffset(150, 22), TextXAlignment = Enum.TextXAlignment.Right })
	local _, tFill = UI.bar(target, C.bright, 9, { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 9) })
	refs.tFill = tFill
	refs.tAdv = UI.label(target, "", 13, UI.F.bold, C.ok, { Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, -130, 0, 18) })
	refs.tSeal = UI.label(target, "", 13, UI.F.bold, C.gold, { Position = UDim2.new(1, -220, 0, 40), Size = UDim2.fromOffset(220, 18), TextXAlignment = Enum.TextXAlignment.Right })

	-- --- monedas y menús (arriba a la derecha) ---
	local top = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 16), Size = UDim2.fromOffset(520, 96) }, root)
	local chips = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40) }, top)
	local cl = UI.list(chips, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right)
	local _4 = cl
	local function chip(color, order)
		local f = UI.panel(chips, { Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order, BackgroundColor3 = C.night })
		UI.pad(f, 12, 0)
		local dot = UI.new("Frame", { BackgroundColor3 = color, Size = UDim2.fromOffset(10, 10), Position = UDim2.new(0, 0, 0.5, -5), Rotation = 45, BorderSizePixel = 0 }, f)
		local _5 = dot
		local l = UI.label(f, "", 17, UI.F.bold, C.bright, { Position = UDim2.fromOffset(18, 0), Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X })
		return l
	end
	refs.essence = chip(C.essence, 1)
	refs.ink = chip(C.inkBlue, 2)
	refs.crystals = chip(C.crystal, 3)
	local menu = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 42) }, top)
	UI.list(menu, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right)
	refs.menu = {}
	local entries = { { "citadel", "citadel" }, { "bestiary", "bestiary" }, { "shop", "shop" }, { "pass", "pass" }, { "settings", "settings" } }
	for i, e in ipairs(entries) do
		local b = UI.button(menu, UI.t(e[2]), { Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = i, TextSize = 14 }, function()
			if Hud.onMenu then
				Hud.onMenu(e[1])
			end
		end)
		UI.pad(b, 12, 0)
		local dot = UI.new("Frame", { BackgroundColor3 = C.danger, Size = UDim2.fromOffset(12, 12), Position = UDim2.new(1, -6, 0, -4), Visible = false, BorderSizePixel = 0 }, b)
		UI.corner(dot, 6)
		refs.menu[e[1]] = dot
	end

	-- --- habilidades (abajo a la derecha) ---
	local abil = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -18), Size = UDim2.fromOffset(470, 110) }, root)
	refs.abil = {}
	local function abButton(key, x, y, size, isUlt)
		local b = UI.button(abil, "", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(size, size), BackgroundColor3 = C.night, TextSize = 12 }, function()
			State.press(key)
		end)
		b:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
		local nameL = UI.label(b, "", isUlt and 12 or 11, UI.F.bold, C.ink, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -8, 0, 28), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Bottom })
		local keyL = UI.label(b, string.upper(key == "dodge" and "⇧" or key), isUlt and 26 or 22, UI.F.title, C.bright, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.new(1, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Center })
		local cd = UI.new("Frame", { BackgroundColor3 = C.night, BackgroundTransparency = 0.25, Size = UDim2.fromScale(1, 1), Visible = false }, b)
		UI.corner(cd, size / 2)
		local cdL = UI.label(cd, "", 22, UI.F.bold, C.bright, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
		local fill = nil
		if isUlt then
			local back, f = UI.bar(b, C.accent, 6, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 4), Size = UDim2.new(0.8, 0, 0, 6) })
			local _6 = back
			fill = f
		end
		refs.abil[key] = { button = b, name = nameL, key = keyL, cd = cd, cdL = cdL, fill = fill, stroke = b:FindFirstChildOfClass("UIStroke") }
	end
	abButton("dodge", 0, 38, 64, false)
	abButton("q", 76, 26, 78, false)
	abButton("e", 166, 26, 78, false)
	abButton("r", 256, 26, 78, false)
	abButton("f", 350, 0, 104, true)

	-- --- trazar sello (abajo al centro) ---
	local sealBox = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -22), Size = UDim2.fromOffset(330, 84), Visible = false }, root)
	refs.sealBox = sealBox
	refs.sealBtn = UI.button(sealBox, UI.t("traceSeal") .. "  (G)", { Size = UDim2.fromOffset(330, 56), BackgroundColor3 = Color3.fromRGB(40, 32, 8), TextColor3 = C.gold, TextSize = 20, StrokeColor = C.gold }, function()
		State.press("seal")
	end)
	refs.sealSub = UI.label(sealBox, "", 13, UI.F.medium, C.muted, { Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.6 })

	-- --- contrato activo (abajo a la izquierda) ---
	refs.contract = UI.label(root, "", 14, UI.F.medium, C.muted, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -16), Size = UDim2.fromOffset(420, 18), TextStrokeTransparency = 0.7 })
end

local function contractText(c)
	return UI.t("c_" .. c.type, { n = c.goal })
end
Hud.contractText = contractText

function Hud.update()
	local p = State.profile
	local team = State.team
	if p then
		refs.essence.Text = UI.fmt(p.essence)
		refs.ink.Text = tostring(p.ink) .. " / " .. Config.InkMax
		refs.crystals.Text = UI.fmt(p.crystals) .. "  +"
		local daily = p.daily.last ~= State.today()
		local ready = 0
		for _, c in ipairs(p.contracts.list or {}) do
			if c.progress >= c.goal and not c.claimed then
				ready = ready + 1
			end
		end
		refs.menu.citadel.Visible = daily or ready > 0
		local tier = Formulas.passTier(p.pass.xp)
		local passReady = false
		for n = 1, tier do
			if not table.find(p.pass.free, n) or (p.pass.premium and not table.find(p.pass.prem, n)) then
				passReady = true
			end
		end
		refs.menu.pass.Visible = passReady
		local ct = nil
		for _, c in ipairs(p.contracts.list or {}) do
			if not c.claimed and c.progress < c.goal then
				ct = c
				break
			end
		end
		refs.contract.Text = ct and (UI.t("contract") .. ": " .. contractText(ct) .. " · " .. ct.progress .. "/" .. ct.goal) or ""
	end
	-- criatura activa
	local active = team and team.slots and team.slots[team.active]
	refs.self.Visible = active ~= nil
	if active then
		local col = creatureColor(active.id)
		refs.badgeStroke.Color = col
		refs.badgeLetter.Text = string.sub(shortName(active.id), 1, 1)
		refs.badgeLetter.TextColor3 = col
		refs.name.Text = shortName(active.id)
		refs.level.Text = UI.t("lvl") .. " " .. active.level
		UI.setBar(refs.hpFill, active.hp / math.max(1, active.maxHp))
		refs.hpFill.BackgroundColor3 = (active.hp / math.max(1, active.maxHp) < 0.3) and C.danger or C.bright
		refs.hpText.Text = UI.fmt(active.hp) .. " / " .. UI.fmt(active.maxHp) .. ((active.shield or 0) > 0 and (" (+" .. active.shield .. ")") or "")
		UI.setBar(refs.enFill, active.energy / 100)
		UI.setBar(refs.slFill, active.seal / 100)
		refs.slFill.BackgroundColor3 = col
		refs.slText.Text = UI.t("energy") .. " " .. active.energy .. " · " .. UI.t("sealBar") .. " " .. active.seal .. " %"
		local def = GameData.CreatureById[active.id]
		for _, k in ipairs({ "q", "e", "r", "f" }) do
			local a = def.abilityByKey[k]
			local r = refs.abil[k]
			r.name.Text = UI.L(a.name)
			local locked = (k == "r" and active.form < 2)
			local cd = (k == "q" and active.cq) or (k == "e" and active.ce) or (k == "r" and active.cr) or 0
			if k == "f" then
				UI.setBar(r.fill, active.seal / 100)
				r.fill.BackgroundColor3 = col
				r.stroke.Color = active.seal >= 100 and col or C.line2
				r.stroke.Thickness = active.seal >= 100 and 3 or 1.5
				r.cd.Visible = false
			else
				local noEnergy = active.energy < (a.cost or 0)
				r.cd.Visible = locked or cd > 0 or noEnergy
				r.cdL.Text = locked and "🔒" or (cd > 0 and tostring(math.ceil(cd)) or "")
			end
		end
	end
	if team and team.slots then
		for i = 1, 3 do
			local r = refs.slots[i]
			local s = team.slots[i]
			r.button.Visible = s ~= nil
			if s then
				r.button.Text = string.sub(shortName(s.id), 1, 1)
				r.button.TextColor3 = s.fainted and C.dim or creatureColor(s.id)
				r.stroke.Color = (i == team.active) and creatureColor(s.id) or C.line2
				UI.setBar(r.fill, s.fainted and 0 or s.hp / math.max(1, s.maxHp))
			end
		end
	end
	-- objetivo
	local m = State.targetModel()
	refs.target.Visible = m ~= nil
	if m then
		local id = m:GetAttribute("CreatureId")
		local def = GameData.CreatureById[id]
		local kind = m:GetAttribute("Kind")
		local hp, maxHp = m:GetAttribute("HP") or 0, m:GetAttribute("MaxHP") or 1
		UI.setBar(refs.tFill, hp / maxHp)
		refs.tFill.BackgroundColor3 = Color3.fromHex(def.color)
		if kind == "anchor" then
			refs.tName.Text = UI.t("anchor")
			refs.tLevel.Text = ""
			refs.tAdv.Text = ""
			refs.tSeal.Text = ""
		else
			refs.tName.Text = UI.L(def.name)
			refs.tLevel.Text = UI.t("lvl") .. " " .. (m:GetAttribute("Level") or 1) .. " · " .. UI.t("form" .. (m:GetAttribute("Form") or 1))
			if active then
				local mult = Formulas.domainMult(GameData.CreatureById[active.id].el, def.el)
				local da = GameData.Domains[GameData.Elements[GameData.CreatureById[active.id].el].domain]
				local db = GameData.Domains[GameData.Elements[def.el].domain]
				if mult > 1 then
					refs.tAdv.Text = UI.L(da) .. " " .. UI.t("beats") .. " " .. UI.L(db) .. " · +30 %"
					refs.tAdv.TextColor3 = C.ok
				elseif mult < 1 then
					refs.tAdv.Text = UI.L(db) .. " " .. UI.t("beats") .. " " .. UI.L(da) .. " · −23 %"
					refs.tAdv.TextColor3 = C.danger
				else
					refs.tAdv.Text = UI.L(da) .. " · " .. UI.L(db)
					refs.tAdv.TextColor3 = C.muted
				end
			end
			refs.tSeal.Text = m:GetAttribute("Invuln") and UI.t("immuneAnchors") or (m:GetAttribute("Sealable") and UI.t("sealable") or "")
		end
	end
	-- botón de sellar
	local sm = State.sealableModel()
	refs.sealBox.Visible = sm ~= nil and not State.sealing
	if sm and p then
		refs.sealSub.Text = sm:GetAttribute("Boss") and UI.t("bossSealFree") or (p.ink > 0 and UI.t("sealCost", { n = p.ink }) or UI.t("noInk"))
	end
end

function Hud.init()
	build()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc >= 0.1 then
			acc = 0
			Hud.update()
		end
	end)
end

Hud.player = player
return Hud
