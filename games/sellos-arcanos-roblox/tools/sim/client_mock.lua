-- Ampliación del simulador para ejecutar también el cliente (HUD, menús,
-- minijuego) en el mismo proceso que el servidor. Los RemoteEvents hacen de
-- «bucle»: lo que el servidor envía con FireClient llega al cliente en el
-- siguiente paso y lo que el cliente envía con FireServer llega al servidor.
local M = ...
local newInstance = M.newInstance

-- --- tipos de interfaz ----------------------------------------------------------------
local V2 = {}
V2.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y) end
	if k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y)
		if m == 0 then return Vector2.new(0, 0) end
		return Vector2.new(v.X / m, v.Y / m)
	end
	return V2[k]
end
V2.__add = function(a, b) return Vector2.new(a.X + b.X, a.Y + b.Y) end
V2.__sub = function(a, b) return Vector2.new(a.X - b.X, a.Y - b.Y) end
V2.__unm = function(a) return Vector2.new(-a.X, -a.Y) end
V2.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return Vector2.new(a.X * b, a.Y * b) end
	return Vector2.new(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b)
	if type(b) == "number" then return Vector2.new(a.X / b, a.Y / b) end
	return Vector2.new(a.X / b.X, a.Y / b.Y)
end
V2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
V2.__tostring = function(v) return string.format("(%.1f, %.1f)", v.X, v.Y) end
function V2.Dot(a, b) return a.X * b.X + a.Y * b.Y end
function V2.Lerp(a, b, t) return a + (b - a) * t end
Vector2 = { new = function(x, y)
	assert(x == nil or type(x) == "number", "Vector2.new: x no es número")
	assert(y == nil or type(y) == "number", "Vector2.new: y no es número")
	return setmetatable({ X = x or 0, Y = y or 0, __type = "Vector2" }, V2)
end }
Vector2.zero = Vector2.new(0, 0)
Vector2.one = Vector2.new(1, 1)

local UD = {}
UD.__index = UD
UD.__add = function(a, b) return UDim.new(a.Scale + b.Scale, a.Offset + b.Offset) end
UD.__sub = function(a, b) return UDim.new(a.Scale - b.Scale, a.Offset - b.Offset) end
UDim = { new = function(s, o)
	assert(s == nil or type(s) == "number", "UDim.new: escala no es número")
	assert(o == nil or type(o) == "number", "UDim.new: offset no es número")
	return setmetatable({ Scale = s or 0, Offset = o or 0, __type = "UDim" }, UD)
end }

local U2 = {}
U2.__index = function(u, k)
	if k == "Width" then return u.X end
	if k == "Height" then return u.Y end
	return U2[k]
end
U2.__add = function(a, b) return UDim2.new(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset) end
U2.__sub = function(a, b) return UDim2.new(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset) end
U2.__eq = function(a, b) return a.X.Scale == b.X.Scale and a.X.Offset == b.X.Offset and a.Y.Scale == b.Y.Scale and a.Y.Offset == b.Y.Offset end
function U2.Lerp(a, b, t)
	return UDim2.new(a.X.Scale + (b.X.Scale - a.X.Scale) * t, a.X.Offset + (b.X.Offset - a.X.Offset) * t, a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t, a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t)
end
UDim2 = {
	new = function(xs, xo, ys, yo)
		if type(xs) == "table" then
			return setmetatable({ X = xs, Y = xo, __type = "UDim2" }, U2)
		end
		for i, v in ipairs({ xs or 0, xo or 0, ys or 0, yo or 0 }) do
			assert(type(v) == "number", "UDim2.new: argumento " .. i .. " no es número")
		end
		return setmetatable({ X = UDim.new(xs, xo), Y = UDim.new(ys, yo), __type = "UDim2" }, U2)
	end,
	fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end,
	fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end,
}

local function tagged(t, kind)
	t.__type = kind
	return t
end
ColorSequenceKeypoint = { new = function(t, c) return tagged({ Time = t, Value = c }, "ColorSequenceKeypoint") end }
NumberSequenceKeypoint = { new = function(t, v, e) return tagged({ Time = t, Value = v, Envelope = e or 0 }, "NumberSequenceKeypoint") end }
ColorSequence = { new = function(a, b)
	assert(type(a) == "table", "ColorSequence.new: argumento inválido")
	return tagged({ Keypoints = a.__type and { a, b or a } or a }, "ColorSequence")
end }
NumberSequence = { new = function(a, b)
	assert(type(a) == "number" or type(a) == "table", "NumberSequence.new: argumento inválido")
	return tagged({ Keypoints = a }, "NumberSequence")
end }
NumberRange = { new = function(a, b)
	assert(type(a) == "number", "NumberRange.new: argumento inválido")
	return tagged({ Min = a, Max = b or a }, "NumberRange")
end }
TweenInfo = { new = function(t)
	assert(t == nil or type(t) == "number", "TweenInfo.new: tiempo inválido")
	return tagged({ Time = t or 1 }, "TweenInfo")
end }
Rect = { new = function(a, b, c, d) return tagged({ Min = Vector2.new(a, b), Max = Vector2.new(c, d) }, "Rect") end }
RaycastParams = { new = function() return tagged({ FilterDescendantsInstances = {} }, "RaycastParams") end }
os.clock = function() return M.now end -- tiempo simulado

-- --- propiedades por defecto al leer -------------------------------------------------------
local GUI = { ScreenGui = true, BillboardGui = true, SurfaceGui = true, Frame = true, TextLabel = true, TextButton = true, TextBox = true,
	ImageLabel = true, ImageButton = true, ScrollingFrame = true, CanvasGroup = true, ViewportFrame = true }
M.GUI = GUI
local DEFAULTS = {
	Text = "", Visible = true, Enabled = true, Transparency = 0, BackgroundTransparency = 0, TextTransparency = 0,
	ImageTransparency = 0, Rotation = 0, ZIndex = 1, LayoutOrder = 0, Thickness = 1, Scale = 1, Value = 0,
	Health = 100, MaxHealth = 100, WalkSpeed = 16, TextSize = 14, Image = "", Volume = 0.5, Brightness = 1,
	AnchorPoint = Vector2.new(0, 0), AbsoluteSize = Vector2.new(120, 40), AbsolutePosition = Vector2.new(0, 0),
	TextBounds = Vector2.new(80, 18), CanvasPosition = Vector2.new(0, 0), AbsoluteCanvasSize = Vector2.new(120, 400),
	AbsoluteWindowSize = Vector2.new(120, 300), BackgroundColor3 = Color3.new(1, 1, 1), TextColor3 = Color3.new(0, 0, 0),
	ImageColor3 = Color3.new(1, 1, 1), Color = Color3.new(1, 1, 1), CornerRadius = UDim.new(0, 8),
}
M.DEFAULTS = DEFAULTS

-- crea instancias de interfaz con Size/Position como UDim2 (en el simulador del
-- servidor todo era una pieza 3D)
local baseNew = Instance.new
Instance.new = function(class, parent)
	local o = baseNew(class)
	if GUI[class] or class:sub(1, 2) == "UI" then
		rawset(o, "_gui", true)
		rawset(o, "CFrame", nil)
		rawset(o, "Size", class ~= "BillboardGui" and UDim2.new(0, 100, 0, 100) or UDim2.new(0, 100, 0, 100))
		rawset(o, "_guiPos", UDim2.new())
	end
	if parent then o.Parent = parent end
	return o
end

-- IsA con la jerarquía de interfaz
local Inst = getmetatable(game)
local baseIsA = Inst.IsA
local LAYER = { ScreenGui = true, BillboardGui = true, SurfaceGui = true }
local BUTTON = { TextButton = true, ImageButton = true }
function Inst:IsA(c)
	local cl = self.ClassName
	if c == "GuiObject" then return GUI[cl] == true and not LAYER[cl] end
	if c == "GuiBase2d" then return GUI[cl] == true end
	if c == "LayerCollector" then return LAYER[cl] == true end
	if c == "GuiButton" then return BUTTON[cl] == true end
	if c == "UIComponent" then return cl:sub(1, 2) == "UI" end
	return baseIsA(self, c)
end

-- --- servicios del cliente -----------------------------------------------------------------
for _, n in ipairs({ "UserInputService", "ContextActionService", "GuiService" }) do
	local s = newInstance(n)
	s.Name = n
	s.Parent = game
	M.services[n] = s
end
local UIS = M.services.UserInputService
rawset(UIS, "TouchEnabled", false)
rawset(UIS, "KeyboardEnabled", true)
rawset(UIS, "MouseEnabled", true)
rawset(UIS, "GamepadEnabled", false)
function UIS:GetFocusedTextBox() return nil end
function UIS:GetLastInputType() return Enum.UserInputType.Keyboard end
function UIS:GetMouseLocation() return Vector2.new(640, 360) end
function UIS:IsKeyDown() return false end

local CAS = M.services.ContextActionService
M.actions = {}
function CAS:BindAction(name, fn, touch, ...)
	assert(type(name) == "string" and type(fn) == "function", "BindAction: argumentos inválidos")
	M.actions[name] = { fn = fn, keys = { ... } }
end
function CAS:BindActionAtPriority(name, fn, touch, prio, ...)
	assert(type(prio) == "number", "BindActionAtPriority: prioridad no numérica")
	M.actions[name] = { fn = fn, keys = { ... } }
end
function CAS:UnbindAction(name) M.actions[name] = nil end
function CAS:GetButton() return nil end
function CAS:SetTitle() end
function CAS:SetImage() end
function CAS:SetPosition() end

local GS = M.services.GuiService
function GS:GetGuiInset() return Vector2.new(0, 36), Vector2.new(0, 0) end

local TS = M.services.TweenService
M.tweens = 0
function TS:Create(obj, info, props)
	assert(type(obj) == "table" and obj.ClassName, "TweenService:Create: objeto inválido")
	assert(type(info) == "table" and info.__type == "TweenInfo", "TweenService:Create: TweenInfo inválido")
	assert(type(props) == "table", "TweenService:Create: propiedades inválidas")
	local tw = newInstance("Tween")
	local completed = M.Signal()
	rawset(tw, "Completed", completed)
	function tw:Play()
		M.tweens = M.tweens + 1
		for k, v in pairs(props) do obj[k] = v end
		task.delay(info.Time or 0, function() completed:Fire(Enum.PlaybackState.Completed) end)
	end
	function tw:Cancel() end
	function tw:Pause() end
	return tw
end
local Debris = M.services.Debris
function Debris:AddItem(o, t)
	assert(type(o) == "table" and o.ClassName, "Debris:AddItem: objeto inválido")
	task.delay(t or 10, function() o:Destroy() end)
end
local SG = M.services.StarterGui
function SG:SetCoreGuiEnabled() end
function SG:SetCore() end
local MS = M.services.MarketplaceService
function MS:PromptGamePassPurchase() end
M.priceQueries = 0
function MS:GetProductInfoAsync(id, infoType)
	assert(type(id) == "number" and id > 0, "GetProductInfoAsync: id inválido")
	assert(typeof(infoType) == "EnumItem", "GetProductInfoAsync: InfoType inválido")
	M.priceQueries = M.priceQueries + 1
	task.wait(0.2)
	return { PriceInRobux = 199, Name = "Producto " .. id }
end

local HS = M.services.HttpService
function HS:JSONDecode(s)
	assert(type(s) == "string", "JSONDecode: no es texto")
	local pos = 1
	local function ws() pos = s:find("[^ \t\r\n]", pos) or #s + 1 end
	local val
	local function str()
		local out = {}
		pos = pos + 1
		while true do
			local c = s:sub(pos, pos)
			if c == "" then error("JSON sin cerrar") end
			if c == '"' then pos = pos + 1 break end
			if c == "\\" then
				local n = s:sub(pos + 1, pos + 1)
				local map = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f" }
				if n == "u" then
					table.insert(out, utf8.char(tonumber(s:sub(pos + 2, pos + 5), 16)))
					pos = pos + 6
				else
					table.insert(out, map[n] or n)
					pos = pos + 2
				end
			else
				table.insert(out, c)
				pos = pos + 1
			end
		end
		return table.concat(out)
	end
	function val()
		ws()
		local c = s:sub(pos, pos)
		if c == "{" then
			local t = {}
			pos = pos + 1
			ws()
			if s:sub(pos, pos) == "}" then pos = pos + 1 return t end
			while true do
				ws()
				local k = str()
				ws()
				assert(s:sub(pos, pos) == ":", "JSON: falta ':'")
				pos = pos + 1
				t[k] = val()
				ws()
				local d = s:sub(pos, pos)
				pos = pos + 1
				if d == "}" then return t end
				assert(d == ",", "JSON: falta ','")
			end
		elseif c == "[" then
			local t = {}
			pos = pos + 1
			ws()
			if s:sub(pos, pos) == "]" then pos = pos + 1 return t end
			while true do
				table.insert(t, val())
				ws()
				local d = s:sub(pos, pos)
				pos = pos + 1
				if d == "]" then return t end
				assert(d == ",", "JSON: falta ','")
			end
		elseif c == '"' then
			return str()
		elseif s:sub(pos, pos + 3) == "true" then pos = pos + 4 return true
		elseif s:sub(pos, pos + 4) == "false" then pos = pos + 5 return false
		elseif s:sub(pos, pos + 3) == "null" then pos = pos + 4 return nil
		else
			local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
			assert(num and #num > 0, "JSON: valor inesperado en " .. pos)
			pos = pos + #num
			return tonumber(num)
		end
	end
	return val()
end

-- cámara
local cam = newInstance("Camera")
cam.Name = "Camera"
rawset(cam, "ViewportSize", Vector2.new(1280, 720))
rawset(cam, "FieldOfView", 70)
cam.CFrame = CFrame.new(0, 120, 40)
cam.Parent = workspace
rawset(workspace, "CurrentCamera", cam)
function cam:ScreenPointToRay(x, y)
	assert(type(x) == "number" and type(y) == "number", "ScreenPointToRay: coordenadas inválidas")
	return { Origin = Vector3.new(0, 120, 40), Direction = Vector3.new(0, -1, 0), __type = "Ray" }
end
function cam:WorldToViewportPoint(p) return Vector3.new(640, 360, 10), true end
function workspace:Raycast(origin, dir, params)
	assert(typeof(origin) == "Vector3" and typeof(dir) == "Vector3", "Raycast: argumentos inválidos")
	return nil
end

-- --- bucle de red ------------------------------------------------------------------------
M.clientQueue = {}
M.localPlayer = nil
function Inst:FireClient(player, ...)
	table.insert(M.fired, { remote = self.Name, player = player, args = { ... } })
	if player == M.localPlayer then
		local args = table.pack(...)
		local remote = self
		table.insert(M.clientQueue, function() remote.OnClientEvent:Fire(table.unpack(args, 1, args.n)) end)
	end
end
function Inst:FireAllClients(...)
	table.insert(M.fired, { remote = self.Name, args = { ... } })
	local args = table.pack(...)
	local remote = self
	table.insert(M.clientQueue, function() remote.OnClientEvent:Fire(table.unpack(args, 1, args.n)) end)
end
function Inst:FireServer(...)
	assert(M.localPlayer, "FireServer sin jugador local")
	self.OnServerEvent:Fire(M.localPlayer, ...)
end
function Inst:InvokeServer(...)
	local fn = rawget(self, "OnServerInvoke")
	assert(fn, "InvokeServer sin OnServerInvoke en " .. self.Name)
	return fn(M.localPlayer, ...)
end
function M.flushClient()
	local q = M.clientQueue
	M.clientQueue = {}
	for _, fn in ipairs(q) do
		local ok, e = pcall(fn)
		if not ok then M.err(e) end
	end
end

-- simula una pulsación de una acción enlazada
function M.press(name)
	local a = M.actions[name]
	assert(a, "acción no enlazada: " .. name)
	local input = { UserInputType = Enum.UserInputType.Keyboard, KeyCode = a.keys[1], Position = Vector3.new(640, 360, 0), UserInputState = Enum.UserInputState.Begin, Delta = Vector3.zero }
	local ok, e = pcall(a.fn, name, Enum.UserInputState.Begin, input)
	if not ok then M.err(e) end
	input.UserInputState = Enum.UserInputState.End
	ok, e = pcall(a.fn, name, Enum.UserInputState.End, input)
	if not ok then M.err(e) end
end

-- recorre la interfaz y pulsa botones: devuelve los visibles con su texto
function M.buttons(root)
	local out = {}
	for _, d in ipairs(root:GetDescendants()) do
		if (d.ClassName == "TextButton" or d.ClassName == "ImageButton") then
			table.insert(out, d)
		end
	end
	return out
end
function M.click(btn)
	btn.Activated:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(0, 0, 0) }, 1)
	btn.MouseButton1Click:Fire()
end

return M
