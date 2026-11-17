-- Minijuego de sellado: une los nodos de la runa en orden antes de que el
-- círculo se apague. Se traza con el dedo, el ratón o el stick del mando.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameData = require(Shared.GameData)
local Formulas = require(Shared.Formulas)
local Net = require(Shared.Net)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Fx = require(script.Parent.Fx)

local Sealing = {}
local player = Players.LocalPlayer
local C = UI.C

local function gcd(a, b)
	while b ~= 0 do
		a, b = b, a % b
	end
	return a
end

-- N nodos alrededor del círculo recorridos como un polígono estrellado
local function runePoints(n, seed)
	local rng = Random.new(seed)
	local k = math.max(1, math.floor(n / 2) - ((n % 2 == 0) and 1 or 0))
	while gcd(n, k) ~= 1 and k > 1 do
		k = k - 1
	end
	local rot = rng:NextNumber() * math.pi * 2
	local pts = {}
	for i = 0, n - 1 do
		local idx = (i * k) % n
		local a = rot + (idx / n) * math.pi * 2
		local r = 0.5 + rng:NextNumber() * 0.32
		table.insert(pts, { bx = math.cos(a) * r, by = math.sin(a) * r, ph = rng:NextNumber() * 10 })
	end
	return pts
end

local function ringFrame(parent, cx, cy, r, color, thick, transp)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(cx, cy)
	f.Size = UDim2.fromOffset(r * 2, r * 2)
	f.BackgroundTransparency = 1
	f.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thick
	s.Transparency = transp or 0
	s.Parent = f
	return f, s
end

local function segment(parent, color, thick)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.Size = UDim2.fromOffset(0, thick)
	f.Parent = parent
	return f
end

local function placeSegment(f, a, b)
	local d = b - a
	f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	f.Size = UDim2.fromOffset(d.Magnitude, f.Size.Y.Offset)
	f.Rotation = math.deg(math.atan2(d.Y, d.X))
end

function Sealing.start(model)
	if State.sealing then
		return
	end
	State.sealing = true
	local entId = model:GetAttribute("EntityId")
	local ok, params = pcall(function()
		return Net.get("SealRequest"):InvokeServer(entId)
	end)
	if not ok or not params or params.error then
		State.sealing = false
		UI.toast(UI.t((params and params.error) or "resist"), "bad")
		return
	end
	local def = GameData.CreatureById[params.id]
	local color = Formulas.resolveColor(params.color or def.color, os.clock())
	local cam = Workspace.CurrentCamera
	local vs = cam.ViewportSize
	local k = math.clamp(math.min(vs.X / 1280, vs.Y / 720), 0.55, 1.6)

	local gui = Instance.new("ScreenGui")
	gui.Name = "SA_Sealing"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = C.night
	back.BackgroundTransparency = 0.25
	back.Active = true
	back.Parent = gui

	local function text(t, size, font, col, y)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.new(0.5, 0, 0, y)
		l.Size = UDim2.new(1, 0, 0, size + 8)
		l.Text = t
		l.TextSize = size
		l.Font = font
		l.TextColor3 = col
		l.TextStrokeTransparency = 0.5
		l.Parent = back
		return l
	end
	text(UI.t("sealing"), math.floor(15 * k), UI.F.bold, color, math.floor(18 * k))
	text(UI.t("traceTitle", { name = UI.L(def.name) }), math.floor(34 * k), UI.F.title, C.bright, math.floor(40 * k))
	local help = text(UI.t("traceHelp") .. "  " .. UI.t("struggle"), math.floor(16 * k), UI.F.medium, C.ink, math.floor(84 * k))
	local timerL = text("", math.floor(30 * k), UI.F.title, C.bright, vs.Y - math.floor(70 * k))
	local resultL = text("", math.floor(56 * k), UI.F.title, C.gold, vs.Y / 2 - math.floor(40 * k))
	resultL.ZIndex = 5

	local R = math.min(vs.X, vs.Y) * 0.33
	local cx, cy = vs.X / 2, vs.Y / 2 + math.floor(30 * k)
	local _, timerStroke = ringFrame(back, cx, cy, R * 1.05, color, 5, 0)
	ringFrame(back, cx, cy, R * 0.99, color, 1.5, 0.5)
	ringFrame(back, cx, cy, R * 0.9, color, 1, 0.75)
	ringFrame(back, cx, cy, R * 0.4, color, 1, 0.8)

	local pts = runePoints(params.nodes, params.seed or 1)
	local hitR = math.max(26, R * 0.1)
	local nodes, guides, done = {}, {}, {}
	for i = 1, #pts - 1 do
		local g = segment(back, color, 2)
		g.BackgroundTransparency = 0.6
		guides[i] = g
	end
	for i = 1, #pts do
		local n, st = ringFrame(back, 0, 0, hitR * 0.55, color, 3, 0)
		n.BackgroundTransparency = 0
		n.BackgroundColor3 = Color3.fromRGB(6, 16, 12)
		local num = Instance.new("TextLabel")
		num.BackgroundTransparency = 1
		num.Size = UDim2.fromScale(1, 1)
		num.Text = tostring(i)
		num.TextColor3 = C.bright
		num.Font = UI.F.bold
		num.TextSize = math.floor(14 * k)
		num.Parent = n
		nodes[i] = { frame = n, stroke = st }
	end
	local cursor = ringFrame(back, cx, cy, 14, C.bright, 2, 0)
	cursor.Visible = false
	local trailSeg = segment(back, Color3.new(1, 1, 1), 4)
	trailSeg.Visible = false

	local state = { idx = 0, errors = 0, left = params.time, intro = 0.45, done = false, down = false, pointer = Vector2.new(cx, cy), lastWrong = nil, tt = 0 }

	local function nodePos(i)
		local p = pts[i]
		local x = cx + p.bx * R + math.sin(state.tt * 37 + p.ph) * (params.boss and 3.5 or 2.5)
		local y = cy + p.by * R + math.cos(state.tt * 41 + p.ph) * (params.boss and 3.5 or 2.5)
		if params.moving then
			x = x + math.sin(state.tt * 0.9 + p.ph) * R * 0.08
			y = y + math.cos(state.tt * 0.7 + p.ph * 2) * R * 0.08
		end
		return Vector2.new(x, y)
	end

	local conns = {}
	local function finish(result)
		if state.done then
			return
		end
		state.done = true
		if result == "fail" then
			resultL.Text = UI.t("failed")
			resultL.TextColor3 = C.danger
			Fx.sound("boom", 0.5, 0.4)
		else
			resultL.Text = (result == "perfect") and UI.t("perfect") or UI.t("sealed")
			resultL.TextColor3 = (result == "perfect") and C.gold or C.bright
			if result == "perfect" then
				help.Text = UI.t("perfectBonus")
			end
			Fx.sound("glass", 1.2, 0.5)
		end
		Net.get("SealResult"):FireServer(entId, { done = result ~= "fail", errors = state.errors })
		task.delay(1.2, function()
			for _, c in ipairs(conns) do
				c:Disconnect()
			end
			ContextActionService:UnbindAction("SA_SealCursor")
			gui:Destroy()
			State.sealing = false
		end)
	end

	local function tryNode(pos)
		for i = state.idx + 1, #pts do
			if (nodePos(i) - pos).Magnitude < hitR then
				if i == state.idx + 1 then
					state.idx = i
					done[i] = true
					Fx.sound("ping", 0.8 + i * 0.12, 0.45)
					if state.idx >= #pts then
						local perfect = state.errors == 0 and state.left / params.time >= (params.boss and 0.3 or 0.4)
						finish(perfect and "perfect" or "ok")
					end
				elseif state.lastWrong ~= i then
					state.errors = state.errors + 1
					state.lastWrong = i
					Fx.sound("boom", 1.8, 0.25)
					back.BackgroundColor3 = Color3.fromRGB(60, 10, 20)
					task.delay(0.12, function()
						back.BackgroundColor3 = C.night
					end)
					if state.errors >= 3 then
						finish("fail")
					end
				end
				return
			end
		end
		state.lastWrong = nil
	end

	local function screenPos(input)
		local inset = GuiService:GetGuiInset()
		return Vector2.new(input.Position.X + inset.X, input.Position.Y + inset.Y)
	end

	table.insert(conns, UserInputService.InputBegan:Connect(function(input)
		if state.done then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			state.down = true
			state.pointer = screenPos(input)
			tryNode(state.pointer)
		end
	end))
	table.insert(conns, UserInputService.InputChanged:Connect(function(input)
		if state.done then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			state.pointer = screenPos(input)
			if state.down then
				tryNode(state.pointer)
			end
		end
	end))
	table.insert(conns, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			state.down = false
		end
	end))
	-- stick o WASD mueven un cursor (y no al personaje mientras sellas)
	local stick = Vector2.zero
	local keys = {}
	ContextActionService:BindActionAtPriority("SA_SealCursor", function(_, inputState, input)
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			stick = Vector2.new(input.Position.X, -input.Position.Y)
			if stick.Magnitude < 0.2 then
				stick = Vector2.zero
			end
		else
			keys[input.KeyCode] = inputState == Enum.UserInputState.Begin or inputState == Enum.UserInputState.Change
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.Thumbstick1, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right)

	local useCursor = false
	table.insert(conns, RunService.RenderStepped:Connect(function(dt)
		state.tt = state.tt + dt
		if state.intro > 0 then
			state.intro = state.intro - dt
		elseif not state.done then
			state.left = state.left - dt
			if state.left <= 0 then
				state.left = 0
				finish("fail")
			end
		end
		local mv = stick
		local kx = ((keys[Enum.KeyCode.D] or keys[Enum.KeyCode.Right]) and 1 or 0) - ((keys[Enum.KeyCode.A] or keys[Enum.KeyCode.Left]) and 1 or 0)
		local ky = ((keys[Enum.KeyCode.S] or keys[Enum.KeyCode.Down]) and 1 or 0) - ((keys[Enum.KeyCode.W] or keys[Enum.KeyCode.Up]) and 1 or 0)
		if kx ~= 0 or ky ~= 0 then
			mv = Vector2.new(kx, ky)
		end
		if mv.Magnitude > 0.1 and not state.done then
			if not useCursor then
				useCursor = true
				state.pointer = (state.idx > 0) and nodePos(state.idx) or nodePos(1) + Vector2.new(-40, -40)
			end
			state.pointer = state.pointer + mv.Unit * math.max(520, R * 2.4) * dt * math.min(1, mv.Magnitude)
			tryNode(state.pointer)
		end
		-- dibujo
		timerStroke.Transparency = 1 - math.clamp(state.left / params.time, 0, 1)
		timerL.Text = string.format("%.1f s", state.left)
		for i = 1, #pts do
			local p = nodePos(i)
			local n = nodes[i]
			n.frame.Position = UDim2.fromOffset(p.X, p.Y)
			if done[i] then
				n.frame.BackgroundColor3 = Color3.new(1, 1, 1)
				n.stroke.Color = color
			elseif i == state.idx + 1 then
				n.stroke.Thickness = 3 + math.abs(math.sin(state.tt * 8)) * 3
				n.frame.BackgroundColor3 = Color3.fromRGB(6, 16, 12)
			else
				n.stroke.Thickness = 2
				n.stroke.Transparency = 0.3
			end
		end
		for i = 1, #pts - 1 do
			placeSegment(guides[i], nodePos(i), nodePos(i + 1))
			guides[i].BackgroundColor3 = (i < state.idx) and Color3.new(1, 1, 1) or color
			guides[i].BackgroundTransparency = (i < state.idx) and 0 or 0.65
			guides[i].Size = UDim2.fromOffset(guides[i].Size.X.Offset, (i < state.idx) and 5 or 2)
		end
		local showTrail = state.idx > 0 and (state.down or useCursor) and not state.done
		trailSeg.Visible = showTrail
		if showTrail then
			placeSegment(trailSeg, nodePos(state.idx), state.pointer)
		end
		cursor.Visible = useCursor and not state.done
		cursor.Position = UDim2.fromOffset(state.pointer.X, state.pointer.Y)
	end))
end

function Sealing.init()
	State.onSeal = Sealing.start
end

return Sealing
