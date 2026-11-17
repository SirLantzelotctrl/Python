-- Ventanas: elección de inicial, Ciudadela (rango, diaria, contratos),
-- Bestiario y ficha, Tienda (Robux y cristales), Pase Arcano y Ajustes.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameData = require(Shared.GameData)
local Formulas = require(Shared.Formulas)
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Fx = require(script.Parent.Fx)
local Hud = require(script.Parent.Hud)

local Menus = {}
local C = UI.C
local player = Players.LocalPlayer
Menus.current = nil

local function action(name, a, b, c)
	local ok, res, err = pcall(function()
		return Net.get("Action"):InvokeServer(name, a, b, c)
	end)
	if ok and not res and err then
		UI.toast(UI.t(err), "bad")
	end
	return ok and res
end

local function rewardText(g)
	local parts = {}
	if g.essence then
		table.insert(parts, UI.fmt(g.essence) .. " " .. UI.t("essence"))
	end
	if g.ink then
		table.insert(parts, g.ink .. " " .. UI.t("ink"))
	end
	if g.crystals then
		table.insert(parts, g.crystals .. " " .. UI.t("crystals"))
	end
	if g.fragments then
		table.insert(parts, g.fragments .. " Frag.")
	end
	if g.tint then
		table.insert(parts, UI.L(GameData.TintById[g.tint].name))
	end
	if g.seal then
		table.insert(parts, UI.L(GameData.SealById[g.seal].name))
	end
	if g.effect then
		table.insert(parts, UI.L(GameData.EffectById[g.effect].name))
	end
	return table.concat(parts, " · ")
end

local function colorOf(id)
	return Color3.fromHex(GameData.CreatureById[id].color)
end

local function creatureTile(parent, id, size, known)
	local f = UI.panel(parent, { Size = UDim2.fromOffset(size, size), BackgroundColor3 = C.night })
	local st = f:FindFirstChildOfClass("UIStroke")
	if known then
		st.Color = colorOf(id)
		st.Thickness = 2
	end
	-- sello estilizado con la inicial
	local ring = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.78, 0.78), BackgroundTransparency = 1 }, f)
	UI.corner(ring, size)
	UI.stroke(ring, known and colorOf(id) or C.line2, 2, known and 0.2 or 0.5)
	UI.label(f, known and string.sub(Hud.shortName(id), 1, 1) or "?", math.floor(size * 0.42), UI.F.title, known and colorOf(id) or C.dim, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	return f
end

-- --- primera criatura ---------------------------------------------------------------------
function Menus.starter()
	local body = UI.window(UI.t("chooseTitle"), 1000, 520)
	UI.label(body, UI.t("chooseHelp"), 16, UI.F.medium, C.ink, { Size = UDim2.new(1, 0, 0, 44), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
	local row = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 1, -60) }, body)
	UI.list(row, Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Center)
	for i, id in ipairs(GameData.Starters) do
		local c = GameData.CreatureById[id]
		local card = UI.panel(row, { Size = UDim2.new(1 / 3, -10, 1, 0), LayoutOrder = i, StrokeColor = colorOf(id) })
		UI.pad(card, 14)
		UI.list(card, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center)
		creatureTile(card, id, 96, true)
		local el = GameData.Elements[c.el]
		UI.label(card, string.upper(UI.L(el) .. " · " .. UI.L(GameData.Domains[el.domain]) .. " · " .. UI.L(GameData.Roles[c.role])), 12, UI.F.bold, colorOf(id), { TextXAlignment = Enum.TextXAlignment.Center })
		UI.label(card, UI.L(c.name), 24, UI.F.title, C.bright, { TextXAlignment = Enum.TextXAlignment.Center })
		UI.label(card, UI.L(c.lore), 15, UI.F.lore, C.ink, { Size = UDim2.new(1, 0, 0, 76), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top })
		UI.button(card, UI.t("choose"), { Primary = true, Size = UDim2.new(1, 0, 0, 44) }, function()
			Net.get("ChooseStarter"):FireServer(id)
			UI.closeWindow()
			task.delay(1.5, function()
				UI.toast(UI.t("tutorial1"))
				task.wait(5)
				UI.toast(UI.t("tutorial2"))
				task.wait(5)
				UI.toast(UI.t("tutorial3"))
			end)
		end)
	end
	Menus.current = "starter"
end

-- --- Ciudadela: rango, recompensa diaria y contratos ---------------------------------------
function Menus.citadel()
	local p = State.profile
	if not p then
		return
	end
	local body = UI.window(UI.t("citadel"), 820, 560)
	local r = Formulas.rankInfo(p.rankXp)
	local title = Formulas.rankTitle(r.rank)
	UI.label(body, UI.t("rank", { n = r.rank }) .. " · " .. string.upper(UI.L(title)), 18, UI.F.bold, Color3.fromHex("#cbb8ff"))
	local _, fill = UI.bar(body, Color3.fromHex("#cbb8ff"), 6, { Position = UDim2.fromOffset(0, 28) })
	UI.setBar(fill, r.xp / r.need)
	UI.label(body, UI.fmt(r.xp) .. " / " .. UI.fmt(r.need) .. " XP · " .. UI.t("formsSealed", { n = Formulas.formsSealed(p) }), 13, UI.F.medium, C.muted, { Position = UDim2.fromOffset(0, 38) })

	local daily = UI.panel(body, { Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 0, 74), StrokeColor = C.gold })
	UI.pad(daily, 14, 10)
	local day = (p.daily.day % 7) + 1
	UI.label(daily, UI.t("daily"), 18, UI.F.bold, C.bright, { Size = UDim2.new(1, -170, 0, 22) })
	UI.label(daily, UI.t("dayOf", { n = day }) .. " · " .. rewardText(GameData.Daily[day]), 14, UI.F.medium, C.muted, { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, -170, 0, 20) })
	local can = p.daily.last ~= State.today()
	UI.button(daily, can and UI.t("claim") or UI.t("claimed"), { Primary = can, Position = UDim2.new(1, -150, 0.5, -20), Size = UDim2.fromOffset(150, 40), BackgroundColor3 = can and C.gold or C.panel2, TextColor3 = can and Color3.fromRGB(29, 22, 8) or C.dim, StrokeColor = C.gold }, function()
		if can and action("claimDaily") then
			Fx.sound("ping", 1.2, 0.5)
			Menus.citadel()
		end
	end)

	UI.label(body, string.upper(UI.t("dailyContracts")), 13, UI.F.bold, C.muted, { Position = UDim2.fromOffset(0, 158) })
	local list = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 182), Size = UDim2.new(1, 0, 1, -182) }, body)
	UI.list(list, Enum.FillDirection.Vertical, 8)
	for i, c in ipairs(p.contracts.list or {}) do
		local row = UI.panel(list, { Size = UDim2.new(1, 0, 0, 62), LayoutOrder = i, StrokeColor = (c.progress >= c.goal) and C.ok or C.line })
		UI.pad(row, 14, 8)
		UI.label(row, Hud.contractText(c), 16, UI.F.bold, C.bright, { Size = UDim2.new(1, -170, 0, 22) })
		local _, f = UI.bar(row, C.ok, 4, { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, -170, 0, 4) })
		UI.setBar(f, c.progress / c.goal)
		UI.label(row, c.progress .. " / " .. c.goal .. " · +" .. UI.fmt(c.essence) .. " " .. UI.t("essence"), 12, UI.F.medium, C.muted, { Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, -170, 0, 14) })
		if c.claimed then
			UI.label(row, UI.t("claimed"), 14, UI.F.bold, C.dim, { Position = UDim2.new(1, -150, 0, 10), Size = UDim2.fromOffset(150, 24), TextXAlignment = Enum.TextXAlignment.Right })
		elseif c.progress >= c.goal then
			UI.button(row, UI.t("claim"), { Position = UDim2.new(1, -150, 0.5, -20), Size = UDim2.fromOffset(150, 40), BackgroundColor3 = C.gold, TextColor3 = Color3.fromRGB(29, 22, 8), StrokeColor = C.gold }, function()
				if action("claimContract", i) then
					Fx.sound("ping", 1.2, 0.5)
					Menus.citadel()
				end
			end)
		end
	end
	Menus.current = "citadel"
end

-- --- Bestiario ------------------------------------------------------------------------------
function Menus.bestiary()
	local p = State.profile
	if not p then
		return
	end
	local body = UI.window(UI.t("bestiary") .. " · " .. UI.t("formsSealed", { n = Formulas.formsSealed(p) }), 1100, 640)
	local scroll = UI.scroll(body)
	local grid = UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(160, 210), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
	local _ = grid
	for i, c in ipairs(GameData.Creatures) do
		local b = p.bestiary[c.id]
		local own = p.creatures[c.id]
		local card = UI.button(scroll, "", { LayoutOrder = i, BackgroundColor3 = C.panel, StrokeColor = own and colorOf(c.id) or C.line }, function()
			if b.seen then
				Menus.ficha(c.id)
			else
				UI.toast(UI.t("livesIn", { n = c.island, isle = UI.L(GameData.Islands[c.island].name) }))
			end
		end)
		UI.pad(card, 10)
		UI.list(card, Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Center)
		creatureTile(card, c.id, 96, b.seen)
		UI.label(card, "Nº " .. c.num, 12, UI.F.title, C.muted, { TextXAlignment = Enum.TextXAlignment.Center })
		UI.label(card, b.seen and UI.L(c.name) or "???", 14, UI.F.bold, C.bright, { TextXAlignment = Enum.TextXAlignment.Center, TextScaled = false })
		local sub = own and (UI.t("lvl") .. " " .. own.level .. " · " .. UI.t("form" .. own.form)) or (b.seen and UI.t("seenNot") or UI.t("unknown"))
		UI.label(card, sub, 12, UI.F.medium, C.muted, { TextXAlignment = Enum.TextXAlignment.Center })
		local forms = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14) }, card)
		UI.list(forms, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center)
		for k = 1, 3 do
			local d = UI.new("Frame", { Size = UDim2.fromOffset(10, 10), Rotation = 45, BackgroundColor3 = b.forms[k] and colorOf(c.id) or C.night, BorderSizePixel = 0 }, forms)
			UI.stroke(d, b.forms[k] and colorOf(c.id) or C.line2, 1.5)
		end
		if table.find(p.team, c.id) then
			UI.label(card, UI.t("inTeam"), 11, UI.F.bold, colorOf(c.id), { TextXAlignment = Enum.TextXAlignment.Center })
		end
	end
	Menus.current = "bestiary"
end

function Menus.ficha(id)
	local p = State.profile
	local c = GameData.CreatureById[id]
	local own = p.creatures[id]
	local body = UI.window(UI.L(c.name), 1100, 640)
	local col = colorOf(id)
	local left = UI.scroll(body, { Size = UDim2.new(0.56, 0, 1, 0) })
	UI.list(left, Enum.FillDirection.Vertical, 8)
	local el = GameData.Elements[c.el]
	UI.label(left, string.upper("Nº " .. c.num .. " · " .. UI.L(el) .. " · " .. UI.L(GameData.Domains[el.domain]) .. " · " .. UI.L(GameData.Roles[c.role])), 13, UI.F.bold, col, { LayoutOrder = 1 })
	UI.label(left, UI.L(c.sub), 14, UI.F.bold, C.muted, { LayoutOrder = 2 })
	UI.label(left, UI.L(c.lore), 17, UI.F.lore, C.ink, { LayoutOrder = 3, Size = UDim2.new(1, -10, 0, 48), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
	if own then
		local need = Formulas.xpToNext(own.level)
		UI.label(left, UI.t("level") .. " " .. own.level .. " · " .. UI.t("form" .. own.form) .. " · " .. UI.t("bond") .. " " .. own.bond .. "/5", 16, UI.F.bold, C.bright, { LayoutOrder = 4 })
		local _, xf = UI.bar(left, col, 6, { LayoutOrder = 5, Size = UDim2.new(1, -10, 0, 6) })
		UI.setBar(xf, own.level >= Formulas.MaxLevel and 1 or own.xp / need)
		local row = UI.new("Frame", { BackgroundTransparency = 1, LayoutOrder = 6, Size = UDim2.new(1, -10, 0, 44) }, left)
		UI.list(row, Enum.FillDirection.Horizontal, 8)
		local inTeam = table.find(p.team, id) ~= nil
		UI.button(row, inTeam and UI.t("removeTeam") or UI.t("addTeam"), { Size = UDim2.fromOffset(180, 42), StrokeColor = col }, function()
			if action("team", id) then
				Menus.ficha(id)
			end
		end)
		if inTeam and p.team[1] ~= id then
			UI.button(row, UI.t("makeLeader"), { Size = UDim2.fromOffset(140, 42) }, function()
				if action("leader", id) then
					Menus.ficha(id)
				end
			end)
		end
		if own.level < Formulas.MaxLevel then
			UI.button(row, UI.t("train", { c = UI.fmt(Formulas.trainCost(own.level)) }), { Size = UDim2.fromOffset(220, 42) }, function()
				if action("train", id) then
					Fx.sound("ping", 1.4, 0.4)
					Menus.ficha(id)
				end
			end)
		end
		local evo = Formulas.evolveInfo(p, id)
		if evo then
			local erow = UI.new("Frame", { BackgroundTransparency = 1, LayoutOrder = 7, Size = UDim2.new(1, -10, 0, 44) }, left)
			UI.button(erow, UI.t("evolve", { f = UI.t("form" .. evo.to) }), { Size = UDim2.fromOffset(240, 42), BackgroundColor3 = evo.ok and C.gold or C.panel2, TextColor3 = evo.ok and Color3.fromRGB(29, 22, 8) or C.dim, StrokeColor = C.gold }, function()
				if evo.ok and action("evolve", id) then
					Fx.sound("glass", 1, 0.5)
					Menus.ficha(id)
				end
			end)
			if not evo.ok then
				UI.label(erow, evo.to == 2 and UI.t("evoReq1", { h = evo.have }) or UI.t("evoReq2"), 13, UI.F.medium, C.muted, { Position = UDim2.fromOffset(252, 0), Size = UDim2.new(1, -252, 1, 0), TextWrapped = true })
			end
		end
	else
		UI.label(left, UI.t("livesIn", { n = c.island, isle = UI.L(GameData.Islands[c.island].name) }), 15, UI.F.bold, C.bright, { LayoutOrder = 4 })
	end
	UI.label(left, string.upper(UI.t("stats")), 12, UI.F.bold, C.muted, { LayoutOrder = 10 })
	local names = { { "power", c.stats.pow }, { "defense", c.stats.def }, { "agility", c.stats.agi }, { "magic", c.stats.mag } }
	for i, s in ipairs(names) do
		local row = UI.new("Frame", { BackgroundTransparency = 1, LayoutOrder = 10 + i, Size = UDim2.new(1, -10, 0, 18) }, left)
		UI.label(row, UI.t(s[1]), 13, UI.F.medium, C.ink, { Size = UDim2.fromOffset(90, 18) })
		local _, f = UI.bar(row, col, 6, { Position = UDim2.new(0, 96, 0.5, -3), Size = UDim2.new(1, -140, 0, 6) })
		UI.setBar(f, s[2] / 100)
		UI.label(row, tostring(s[2]), 13, UI.F.bold, C.bright, { Position = UDim2.new(1, -36, 0, 0), Size = UDim2.fromOffset(36, 18), TextXAlignment = Enum.TextXAlignment.Right })
	end
	UI.label(left, string.upper(UI.t("abilities")), 12, UI.F.bold, C.muted, { LayoutOrder = 20 })
	for i, a in ipairs(c.abilities) do
		local locked = a.key == "r" and (not own or own.form < 2)
		local txt = "<b>" .. string.upper(a.key) .. " · " .. UI.L(a.name) .. "</b>" .. (a.key == "f" and (" · " .. UI.t("ultimateTag")) or "") .. "\n" .. UI.L(a.desc) .. (locked and (" · " .. UI.t("unlocksAdult")) or "")
		UI.label(left, txt, 14, UI.F.medium, locked and C.dim or C.ink, { LayoutOrder = 20 + i, Size = UDim2.new(1, -10, 0, 40), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
	end
	-- derecha: formas y tintes
	local right = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0.6, 0, 0, 0), Size = UDim2.new(0.4, 0, 1, 0) }, body)
	UI.list(right, Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Center)
	creatureTile(right, id, 150, true)
	local forms = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40) }, right)
	UI.list(forms, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
	for k = 1, 3 do
		local has = p.bestiary[id].forms[k]
		local f = UI.panel(forms, { Size = UDim2.fromOffset(110, 36), StrokeColor = has and col or C.line })
		UI.label(f, UI.t("form" .. k), 13, UI.F.bold, has and C.bright or C.dim, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	end
	if own then
		UI.label(right, string.upper(UI.t("tints")), 12, UI.F.bold, C.muted, { TextXAlignment = Enum.TextXAlignment.Center })
		local tints = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 110) }, right)
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(110, 40), CellPadding = UDim2.fromOffset(8, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center }, tints)
		UI.button(tints, UI.t("original"), { StrokeColor = (own.tint == "" and C.bright) or col }, function()
			if action("untint", id) then
				Menus.ficha(id)
			end
		end)
		for _, t in ipairs(GameData.Tints) do
			if t.creature == id then
				local owned = table.find(p.cosmetics.tints, t.id) ~= nil
				local swatch = (t.color == "prisma" or t.color == "aurora") and C.bright or Color3.fromHex(t.color)
				local b = UI.button(tints, UI.L(t.name) .. (owned and "" or (" · " .. t.price)), { TextSize = 12, StrokeColor = (own.tint == t.id) and C.bright or swatch, TextColor3 = owned and swatch or C.muted }, function()
					if owned then
						if action("equip", "tint", t.id) then
							Menus.ficha(id)
						end
					else
						UI.confirm(UI.t("confirmBuy", { name = UI.L(t.name), p = t.price }), function()
							if action("buyCosmetic", "tint", t.id) then
								Fx.sound("glass", 1.3, 0.5)
								Menus.ficha(id)
							end
						end)
					end
				end)
				local _ = b
			end
		end
	end
	Menus.current = "ficha"
end

-- --- Tienda ---------------------------------------------------------------------------------
function Menus.shop(tab)
	local p = State.profile
	if not p then
		return
	end
	tab = tab or "crystals"
	local body = UI.window(UI.t("shop") .. " · " .. UI.fmt(p.crystals) .. " " .. UI.t("crystals"), 1100, 640)
	local tabs = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40) }, body)
	UI.list(tabs, Enum.FillDirection.Horizontal, 8)
	for i, k in ipairs({ "crystals", "passes", "tints", "seals", "effects" }) do
		local key = "tab" .. string.upper(string.sub(k, 1, 1)) .. string.sub(k, 2)
		UI.button(tabs, UI.t(key), { LayoutOrder = i, Size = UDim2.fromOffset(150, 38), Primary = (k == tab) }, function()
			Menus.shop(k)
		end)
	end
	UI.label(body, UI.t("rules"), 13, UI.F.medium, C.muted, { Position = UDim2.fromOffset(0, 46) })
	local scroll = UI.scroll(body, { Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 1, -74) })
	UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(240, 150), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
	local function card(order, title, desc, color, buttonText, primary, onBuy)
		local f = UI.panel(scroll, { LayoutOrder = order, StrokeColor = color or C.line })
		UI.pad(f, 12)
		UI.label(f, title, 17, UI.F.bold, C.bright, { Size = UDim2.new(1, 0, 0, 22) })
		UI.label(f, desc or "", 13, UI.F.medium, C.muted, { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 52), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
		UI.button(f, buttonText, { Primary = primary, Position = UDim2.new(0, 0, 1, -40), Size = UDim2.new(1, 0, 0, 40) }, onBuy)
		return f
	end
	if tab == "crystals" then
		local any = false
		for i, prod in ipairs(Config.Products) do
			if prod.id ~= 0 and not (prod.founder and p.purchases.founder) then
				any = true
				local desc = prod.founder and UI.t("pack_fundador_desc") or (prod.tag and UI.t("tag_" .. prod.tag) or "")
				card(i, UI.t(prod.key), desc, prod.founder and C.gold or C.crystal, "R$ " .. prod.robux, true, function()
					MarketplaceService:PromptProductPurchase(player, prod.id)
				end)
			end
		end
		if not any then
			UI.label(scroll, UI.t("productsOff"), 15, UI.F.medium, C.muted)
		end
	elseif tab == "passes" then
		local order = 1
		for key, pass in pairs(Config.GamePasses) do
			if pass.id ~= 0 then
				card(order, UI.t(key), UI.t(key .. "_desc"), C.gold, "R$ " .. pass.robux, true, function()
					MarketplaceService:PromptGamePassPurchase(player, pass.id)
				end)
				order = order + 1
			end
		end
		if not p.pass.premium then
			card(order, UI.t("pase_premium"), UI.t("pase_premium_desc"), C.crystal, UI.t("unlockPremium", { c = Config.PassPremiumCrystals }), false, function()
				UI.confirm(UI.t("confirmBuy", { name = UI.t("pase_premium"), p = Config.PassPremiumCrystals }), function()
					if action("passPremiumCrystals") then
						Menus.shop("passes")
					end
				end)
			end)
		end
	elseif tab == "tints" then
		for i, t in ipairs(GameData.Tints) do
			local owned = table.find(p.cosmetics.tints, t.id) ~= nil
			local swatch = (t.color == "prisma" or t.color == "aurora") and C.bright or Color3.fromHex(t.color)
			local name = UI.L(t.name) .. (t.season and " ★" or "")
			card((t.season and 0 or 100) + i, name, UI.t("tintFor", { name = UI.L(GameData.CreatureById[t.creature].name) }), swatch, owned and UI.t("owned") or (tostring(t.price) .. " " .. UI.t("crystals")), not owned, function()
				if owned then
					return
				end
				UI.confirm(UI.t("confirmBuy", { name = UI.L(t.name), p = t.price }), function()
					if action("buyCosmetic", "tint", t.id) then
						Fx.sound("glass", 1.3, 0.5)
						Menus.shop("tints")
					end
				end)
			end)
		end
	else
		local list = (tab == "seals") and GameData.Seals or GameData.Effects
		local kind = (tab == "seals") and "seal" or "effect"
		local ownedList = (tab == "seals") and p.cosmetics.seals or p.cosmetics.effects
		local equipped = (tab == "seals") and p.cosmetics.seal or p.cosmetics.effect
		for i, s in ipairs(list) do
			local owned = table.find(ownedList, s.id) ~= nil
			local label = owned and ((equipped == s.id) and UI.t("equipped") or UI.t("equip")) or (tostring(s.price) .. " " .. UI.t("crystals"))
			card(i, UI.L(s.name), s.desc and UI.L(s.desc) or "", s.season and C.gold or C.line2, label, not owned, function()
				if owned then
					if equipped ~= s.id and action("equip", kind, s.id) then
						Menus.shop(tab)
					end
					return
				end
				UI.confirm(UI.t("confirmBuy", { name = UI.L(s.name), p = s.price }), function()
					if action("buyCosmetic", kind, s.id) then
						Fx.sound("glass", 1.3, 0.5)
						Menus.shop(tab)
					end
				end)
			end)
		end
	end
	Menus.current = "shop"
	Menus.shopTab = tab
end

-- --- Pase Arcano -----------------------------------------------------------------------------
function Menus.pass()
	local p = State.profile
	if not p then
		return
	end
	local tier = Formulas.passTier(p.pass.xp)
	local body = UI.window(UI.t("pass") .. " · " .. UI.t("passLevel", { n = tier }), 1100, 560)
	UI.label(body, UI.t("passHelp"), 14, UI.F.medium, C.muted, { Size = UDim2.new(1, -330, 0, 20) })
	local _, f = UI.bar(body, Color3.fromHex("#c9a0ff"), 6, { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, -330, 0, 6) })
	UI.setBar(f, (p.pass.xp % GameData.PassXpPerTier) / GameData.PassXpPerTier)
	if p.pass.premium then
		UI.label(body, UI.t("premiumActive"), 15, UI.F.bold, C.gold, { Position = UDim2.new(1, -310, 0, 0), Size = UDim2.fromOffset(310, 30), TextXAlignment = Enum.TextXAlignment.Right })
	else
		UI.button(body, UI.t("unlockPremium", { c = Config.PassPremiumCrystals }), { Position = UDim2.new(1, -310, 0, 0), Size = UDim2.fromOffset(310, 40), BackgroundColor3 = C.gold, TextColor3 = Color3.fromRGB(29, 22, 8), StrokeColor = C.gold }, function()
			Menus.shop("passes")
		end)
	end
	local scroll = UI.scroll(body, { Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 1, -52), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X })
	UI.list(scroll, Enum.FillDirection.Horizontal, 10)
	for _, tr in ipairs(GameData.PassTiers) do
		local col = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 130, 1, -12), LayoutOrder = tr.n }, scroll)
		UI.label(col, tostring(tr.n), 18, UI.F.title, tier >= tr.n and C.bright or C.dim, { TextXAlignment = Enum.TextXAlignment.Center })
		local function slot(y, reward, track, claimedList)
			local claimedIt = table.find(claimedList, tr.n) ~= nil
			local reachable = tier >= tr.n and (track == "free" or p.pass.premium)
			local s = UI.panel(col, { Position = UDim2.new(0, 0, 0, y), Size = UDim2.new(1, 0, 0.42, -16), StrokeColor = (reachable and not claimedIt) and C.ok or (track == "prem" and C.gold or C.line) })
			UI.label(s, rewardText(reward), 13, UI.F.bold, claimedIt and C.dim or C.bright, { Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0.6, 0), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center })
			if reachable and not claimedIt then
				UI.button(s, UI.t("claim"), { Position = UDim2.new(0, 6, 1, -38), Size = UDim2.new(1, -12, 0, 32), TextSize = 13 }, function()
					if action("claimPass", tr.n, track) then
						Fx.sound("ping", 1.2, 0.5)
						Menus.pass()
					end
				end)
			elseif claimedIt then
				UI.label(s, UI.t("claimed"), 12, UI.F.bold, C.dim, { Position = UDim2.new(0, 0, 1, -24), TextXAlignment = Enum.TextXAlignment.Center })
			end
		end
		slot(28, tr.free, "free", p.pass.free)
		slot(28 + 210, tr.prem, "prem", p.pass.prem)
	end
	Menus.current = "pass"
end

-- --- Ajustes ---------------------------------------------------------------------------------
function Menus.settings()
	local p = State.profile
	local body = UI.window(UI.t("settings"), 760, 520)
	UI.list(body, Enum.FillDirection.Vertical, 12)
	local function volumeRow(order, key, value, setter)
		local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), LayoutOrder = order }, body)
		UI.label(row, UI.t(key), 16, UI.F.bold, C.bright, { Size = UDim2.fromOffset(200, 42) })
		local valL = UI.label(row, math.floor(value * 100) .. " %", 16, UI.F.bold, C.bright, { Position = UDim2.fromOffset(300, 0), Size = UDim2.fromOffset(80, 42), TextXAlignment = Enum.TextXAlignment.Center })
		local function change(d)
			value = math.clamp(value + d, 0, 1)
			valL.Text = math.floor(value * 100 + 0.5) .. " %"
			setter(value)
		end
		UI.button(row, "−", { Position = UDim2.fromOffset(240, 0), Size = UDim2.fromOffset(50, 42), TextSize = 22 }, function()
			change(-0.1)
		end)
		UI.button(row, "+", { Position = UDim2.fromOffset(390, 0), Size = UDim2.fromOffset(50, 42), TextSize = 22 }, function()
			change(0.1)
		end)
	end
	local music = p and p.settings.music or 0.5
	local sfx = p and p.settings.sfx or 0.8
	volumeRow(1, "music", music, function(v)
		music = v
		Fx.setMusic(v)
		action("settings", music, sfx)
	end)
	volumeRow(2, "sounds", sfx, function(v)
		sfx = v
		Fx.volume = v
		action("settings", music, sfx)
	end)
	local langRow = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), LayoutOrder = 3 }, body)
	UI.label(langRow, UI.t("language"), 16, UI.F.bold, C.bright, { Size = UDim2.fromOffset(200, 42) })
	UI.button(langRow, "Español", { Primary = UI.lang == "es", Position = UDim2.fromOffset(240, 0), Size = UDim2.fromOffset(130, 42) }, function()
		UI.lang = "es"
		Menus.settings()
	end)
	UI.button(langRow, "English", { Primary = UI.lang == "en", Position = UDim2.fromOffset(380, 0), Size = UDim2.fromOffset(130, 42) }, function()
		UI.lang = "en"
		Menus.settings()
	end)
	UI.label(body, string.upper(UI.t("controls")), 13, UI.F.bold, C.muted, { LayoutOrder = 4 })
	UI.label(body, UI.t("controlsText"), 14, UI.F.medium, C.ink, { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 110), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
	UI.label(body, "Sellos Arcanos v" .. Config.Version, 12, UI.F.medium, C.dim, { LayoutOrder = 6 })
	Menus.current = "settings"
end

-- refresca la ventana abierta cuando cambia el perfil
function Menus.refresh()
	if Menus.current == "citadel" then
		Menus.citadel()
	elseif Menus.current == "shop" then
		Menus.shop(Menus.shopTab)
	end
end

function Menus.init()
	UI.onWindowClosed = function()
		Menus.current = nil
	end
	Hud.onMenu = function(name)
		if Menus.current == name then
			UI.closeWindow()
			return
		end
		if name == "citadel" then
			Menus.citadel()
		elseif name == "bestiary" then
			Menus.bestiary()
		elseif name == "shop" then
			Menus.shop()
		elseif name == "pass" then
			Menus.pass()
		elseif name == "settings" then
			Menus.settings()
		end
	end
end

return Menus
