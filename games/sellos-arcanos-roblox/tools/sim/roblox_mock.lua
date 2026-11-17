-- Simulación mínima del entorno de Roblox para ejecutar la lógica del
-- servidor fuera de Studio (pruebas automáticas). No pretende ser exacta:
-- solo lo suficiente para detectar errores de ejecución.
local M = {}
M.errors = {}
M.fired = {}
M.now = 0

local function err(msg)
	table.insert(M.errors, msg)
	print("ERROR: " .. tostring(msg))
end
M.err = err

-- --- Luau → Lua ---------------------------------------------------------------
math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
math.clamp = function(x, a, b) if x < a then return a elseif x > b then return b end return x end
math.sign = function(x) return x > 0 and 1 or (x < 0 and -1 or 0) end
math.round = function(x) return math.floor(x + 0.5) end
table.find = function(t, v) for i, x in ipairs(t) do if x == v then return i end end return nil end
table.clone = function(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end
unpack = unpack or table.unpack

-- --- tipos -------------------------------------------------------------------------
local V3 = {}
V3.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if k == "Unit" then local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) if m == 0 then return Vector3.new(0, 0, 0) end return Vector3.new(v.X / m, v.Y / m, v.Z / m) end
	return V3[k]
end
V3.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__unm = function(a) return Vector3.new(-a.X, -a.Y, -a.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return Vector3.new(a.X * b, a.Y * b, a.Z * b) end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b) return Vector3.new(a.X / b, a.Y / b, a.Z / b) end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3.__tostring = function(v) return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z) end
function V3.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function V3.Lerp(a, b, t) return a + (b - a) * t end
Vector3 = {
	new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, __type = "Vector3" }, V3) end,
}
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.one = Vector3.new(1, 1, 1)
Vector2 = { new = function(x, y) return { X = x or 0, Y = y or 0, __type = "Vector2" } end }
Vector2.zero = Vector2.new(0, 0)

local CF = {}
CF.__index = function(c, k)
	if k == "LookVector" then return Vector3.new(-math.sin(c.yaw), 0, -math.cos(c.yaw)) end
	if k == "RightVector" then return Vector3.new(math.cos(c.yaw), 0, -math.sin(c.yaw)) end
	if k == "UpVector" then return Vector3.new(0, 1, 0) end
	if k == "X" then return c.Position.X end
	if k == "Y" then return c.Position.Y end
	if k == "Z" then return c.Position.Z end
	return CF[k]
end
local function rot(yaw, v)
	local c, s = math.cos(yaw), math.sin(yaw)
	return Vector3.new(v.X * c + v.Z * s, v.Y, -v.X * s + v.Z * c)
end
CF.__mul = function(a, b)
	if getmetatable(b) == CF then
		return setmetatable({ Position = a.Position + rot(a.yaw, b.Position), yaw = a.yaw + b.yaw, __type = "CFrame" }, CF)
	end
	return a.Position + rot(a.yaw, b)
end
CF.__add = function(a, v) return setmetatable({ Position = a.Position + v, yaw = a.yaw, __type = "CFrame" }, CF) end
CF.__sub = function(a, v) return setmetatable({ Position = a.Position - v, yaw = a.yaw, __type = "CFrame" }, CF) end
CFrame = {
	new = function(x, y, z)
		local p = (type(x) == "table") and x or Vector3.new(x or 0, y or 0, z or 0)
		return setmetatable({ Position = p, yaw = 0, __type = "CFrame" }, CF)
	end,
	Angles = function(rx, ry, rz) return setmetatable({ Position = Vector3.zero, yaw = ry or 0, __type = "CFrame" }, CF) end,
	lookAt = function(p, target)
		local d = target - p
		return setmetatable({ Position = p, yaw = math.atan(-d.X, -d.Z), __type = "CFrame" }, CF)
	end,
}
CFrame.identity = CFrame.new()

local C3 = {}
C3.__index = C3
function C3.Lerp(a, b, t) return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end
Color3 = {
	new = function(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0, __type = "Color3" }, C3) end,
	fromRGB = function(r, g, b) return Color3.new(r / 255, g / 255, b / 255) end,
	fromHSV = function(h, s, v) return Color3.new(v, v, v) end,
	fromHex = function(h)
		assert(type(h) == "string" and #h >= 6, "fromHex inválido: " .. tostring(h))
		h = h:gsub("#", "")
		assert(#h == 6, "fromHex inválido: " .. h)
		return Color3.fromRGB(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16))
	end,
}
UDim = { new = function(a, b) return { Scale = a, Offset = b } end }
UDim2 = { new = function() return {} end, fromScale = function() return {} end, fromOffset = function() return {} end }
TweenInfo = { new = function() return {} end }
NumberRange = { new = function() return {} end }
NumberSequence = { new = function() return {} end }
ColorSequence = { new = function() return {} end }
Random = { new = function(seed) return { NextNumber = function() return math.random() end, NextInteger = function(_, a, b) return math.random(a, b) end } end }

function typeof(v)
	if type(v) == "table" and v.__type then return v.__type end
	if type(v) == "table" and v.ClassName then return "Instance" end
	return type(v)
end

-- Enum: Enum.X.Y devuelve un símbolo
-- (los elementos se guardan para que Enum.X.Y == Enum.X.Y, como en Roblox)
local enumCache = {}
Enum = setmetatable({}, { __index = function(_, e)
	if not enumCache[e] then
		enumCache[e] = setmetatable({}, { __index = function(t, item)
			local v = { Name = item, EnumType = e, __type = "EnumItem" }
			rawset(t, item, v)
			return v
		end })
	end
	return enumCache[e]
end })

-- --- señales ------------------------------------------------------------------------
local function Signal()
	local s = { handlers = {} }
	function s:Connect(fn)
		table.insert(self.handlers, fn)
		local handlers = self.handlers
		return { Connected = true, Disconnect = function()
			for i, h in ipairs(handlers) do if h == fn then table.remove(handlers, i) break end end
		end }
	end
	-- como en Roblox, cada manejador corre en su propio hilo (puede esperar)
	function s:Fire(...)
		local list = {}
		for i, fn in ipairs(self.handlers) do list[i] = fn end
		for _, fn in ipairs(list) do
			local co = coroutine.create(fn)
			local ok, e = coroutine.resume(co, ...)
			if not ok then err(debug.traceback(co, e)) end
		end
	end
	s.Once = s.Connect
	return s
end
M.Signal = Signal

-- --- planificador de tareas ------------------------------------------------------------
local sleeping = {}
local function resume(co, ...)
	local ok, e = coroutine.resume(co, ...)
	if not ok then err(debug.traceback(co, e)) end
end
task = {
	spawn = function(fn, ...)
		local co = coroutine.create(fn)
		resume(co, ...)
		return co
	end,
	defer = function(fn, ...) return task.spawn(fn, ...) end,
	delay = function(t, fn, ...)
		local args = table.pack(...)
		local co = coroutine.create(function() fn(table.unpack(args, 1, args.n)) end)
		table.insert(sleeping, { at = M.now + (t or 0), co = co })
	end,
	wait = function(t)
		local co, main = coroutine.running()
		if main then
			M.now = M.now + (t or 0)
			return t
		end
		table.insert(sleeping, { at = M.now + (t or 0.03), co = co })
		return coroutine.yield()
	end,
}
function wait(t) return task.wait(t) end
function M.advance(dt)
	M.now = M.now + dt
	local due = {}
	for i = #sleeping, 1, -1 do
		if sleeping[i].at <= M.now then
			table.insert(due, table.remove(sleeping, i))
		end
	end
	for _, s in ipairs(due) do
		resume(s.co, dt)
	end
end
function warn(...) print("WARN:", ...) end

-- --- instancias -----------------------------------------------------------------------
local BASEPARTS = { Part = true, MeshPart = true, SpawnLocation = true, WedgePart = true }
local Inst = {}
local uid = 0
local SIGNALS = { PlayerAdded = true, PlayerRemoving = true, CharacterAdded = true, Triggered = true, Heartbeat = true,
	OnServerEvent = true, OnClientEvent = true, PromptGamePassPurchaseFinished = true, ChildAdded = true, DescendantAdded = true,
	Changed = true, Activated = true, RenderStepped = true, Stepped = true, InputBegan = true, InputChanged = true, InputEnded = true,
	MouseEnter = true, MouseLeave = true, MouseButton1Click = true, MouseButton1Down = true, MouseButton1Up = true, FocusLost = true,
	Touched = true, Died = true, AncestryChanged = true, ChildRemoved = true, DescendantRemoving = true, Destroying = true,
	PromptShown = true, PromptHidden = true, TouchTap = true }

M.aligns = {}
local function newInstance(class)
	uid = uid + 1

	local o = { ClassName = class, Name = class, _children = {}, _attrs = {}, _tags = {}, _id = uid, _signals = {} }
	o.CFrame = CFrame.new()
	o.Size = Vector3.new(1, 1, 1)
	setmetatable(o, Inst)
	if class == "AlignPosition" then table.insert(M.aligns, o) end
	return o
end

-- «físicas»: cada AlignPosition lleva su pieza (y su modelo) a la posición
-- pedida, como haría el motor de Roblox
function M.physics()
	for i = #M.aligns, 1, -1 do
		local ap = M.aligns[i]
		if rawget(ap, "_destroyed") then
			table.remove(M.aligns, i)
		else
			local att = rawget(ap, "Attachment0")
			local part = att and att.Parent
			if part and rawget(ap, "CFrame") then
				local model = part.Parent
				local target = rawget(ap, "CFrame").Position
				if model and model.ClassName == "Model" then
					model:PivotTo(CFrame.new(target))
				else
					rawset(part, "CFrame", CFrame.new(target))
				end
			end
		end
	end
end

local function signalOf(o, name)
	local s = rawget(o, "_signals")[name]
	if not s then
		s = Signal()
		rawget(o, "_signals")[name] = s
	end
	return s
end

Inst.__index = function(o, k)
	local v = rawget(Inst, k)
	if v then return v end
	if k == "Parent" then return rawget(o, "_parent") end
	if k == "Position" then
		if rawget(o, "_gui") then return rawget(o, "_guiPos") end
		local cf = rawget(o, "CFrame")
		return cf and cf.Position or nil
	end
	if k == "PrimaryPart" then return rawget(o, "_primary") end
	if SIGNALS[k] then
		return signalOf(o, k)
	end
	-- hijos por nombre
	for _, c in ipairs(rawget(o, "_children")) do
		if c.Name == k then return c end
	end
	if M.DEFAULTS and M.DEFAULTS[k] ~= nil then return M.DEFAULTS[k] end
	return nil
end
Inst.__newindex = function(o, k, v)
	if k == "Parent" then
		local old = rawget(o, "_parent")
		if old then
			local list = rawget(old, "_children")
			for i, c in ipairs(list) do if c == o then table.remove(list, i) break end end
		end
		rawset(o, "_parent", v)
		if v then table.insert(rawget(v, "_children"), o) end
		return
	end
	if k == "Position" then
		if rawget(o, "_gui") then
			assert(typeof(v) == "UDim2", "Position de interfaz debe ser UDim2")
			rawset(o, "_guiPos", v)
		else
			assert(typeof(v) == "Vector3", "Position de pieza debe ser Vector3")
			rawset(o, "CFrame", CFrame.new(v))
		end
		return
	end
	if k == "Size" and rawget(o, "_gui") then
		assert(typeof(v) == "UDim2", "Size de interfaz debe ser UDim2 (" .. o.ClassName .. ")")
	end
	if rawget(o, "_destroyed") and k ~= "Parent" then
		-- escribir en algo destruido no rompe en Roblox; solo lo anotamos
	end
	if k == "PrimaryPart" then rawset(o, "_primary", v) return end
	rawset(o, k, v)
end
function Inst:IsA(c)
	if c == self.ClassName then return true end
	if c == "BasePart" then return BASEPARTS[self.ClassName] == true end
	if c == "Instance" then return true end
	if c == "GuiObject" then return false end
	return false
end
function Inst:FindFirstChild(n) for _, c in ipairs(self._children) do if c.Name == n then return c end end return nil end
function Inst:WaitForChild(n) return self:FindFirstChild(n) end
function Inst:FindFirstChildOfClass(cl) for _, c in ipairs(self._children) do if c.ClassName == cl then return c end end return nil end
function Inst:FindFirstAncestorOfClass(cl) local p = self.Parent while p do if p.ClassName == cl then return p end p = p.Parent end return nil end
function Inst:GetChildren() local t = {} for i, c in ipairs(self._children) do t[i] = c end return t end
function Inst:GetDescendants()
	local out = {}
	local function walk(o) for _, c in ipairs(o._children) do table.insert(out, c) walk(c) end end
	walk(self)
	return out
end
function Inst:SetAttribute(k, v) self._attrs[k] = v signalOf(self, "Attr_" .. k):Fire() end
function Inst:GetAttribute(k) return self._attrs[k] end
function Inst:GetAttributeChangedSignal(k) return signalOf(self, "Attr_" .. k) end
function Inst:GetPropertyChangedSignal(k) return signalOf(self, "Prop_" .. k) end
function Inst:Destroy() self.Parent = nil rawset(self, "_destroyed", true) end
function Inst:Clone()
	local o = newInstance(self.ClassName)
	for k, v in pairs(self) do if type(k) == "string" and k:sub(1, 1) ~= "_" then rawset(o, k, v) end end
	for _, c in ipairs(self._children) do c:Clone().Parent = o end
	return o
end
function Inst:GetPivot()
	local p = self.PrimaryPart or (self:IsA("BasePart") and self) or nil
	if p then return p.CFrame end
	local first = nil
	for _, d in ipairs(self:GetDescendants()) do if d:IsA("BasePart") then first = d break end end
	return first and first.CFrame or CFrame.new()
end
function Inst:PivotTo(cf)
	local cur = self:GetPivot()
	local delta = cf.Position - cur.Position
	if self:IsA("BasePart") then rawset(self, "CFrame", cf) return end
	for _, d in ipairs(self:GetDescendants()) do
		if d:IsA("BasePart") then rawset(d, "CFrame", setmetatable({ Position = d.CFrame.Position + delta, yaw = cf.yaw, __type = "CFrame" }, getmetatable(cf))) end
	end
end
function Inst:GetExtentsSize() return Vector3.new(4, 4.5, 4) end
function Inst:GetBoundingBox() return self:GetPivot() + Vector3.new(0, 2.25, 0), Vector3.new(4, 4.5, 4) end
function Inst:ScaleTo(s) rawset(self, "_scale", s) end
function Inst:GetScale() return rawget(self, "_scale") or 1 end
function Inst:SetNetworkOwner() end
function Inst:FireClient(player, ...) table.insert(M.fired, { remote = self.Name, player = player, args = { ... } }) end
function Inst:FireAllClients(...) table.insert(M.fired, { remote = self.Name, args = { ... } }) end
function Inst:RequestStreamAroundAsync() end
function Inst:Play() end
function Inst:Stop() end
function Inst:GetPlayers() return M.players end
function Inst:GetPlayerByUserId(id) for _, p in ipairs(M.players) do if p.UserId == id then return p end end return nil end
function Inst:IsServer() return true end
function Inst:IsClient() return false end
function Inst:GetService(n) return M.services[n] end
function Inst:BindToClose(fn) M.closeHandlers = M.closeHandlers or {} table.insert(M.closeHandlers, fn) end

Instance = { new = function(class, parent) local o = newInstance(class) if parent then o.Parent = parent end return o end }
M.newInstance = newInstance

-- --- servicios -------------------------------------------------------------------------
M.players = {}
M.services = {}
game = newInstance("DataModel")
rawset(game, "JobId", "sim-job")
workspace = newInstance("Workspace")
workspace.Name = "Workspace"
workspace.Parent = game
for _, n in ipairs({ "Players", "RunService", "ReplicatedStorage", "ServerScriptService", "ServerStorage", "Lighting", "CollectionService", "HttpService", "MarketplaceService", "DataStoreService", "TweenService", "Debris", "SoundService", "StarterGui", "TeleportService" }) do
	local s = newInstance(n)
	s.Name = n
	s.Parent = game
	M.services[n] = s
end
M.services.Workspace = workspace
local CS = M.services.CollectionService
local tagged = {}
function CS:AddTag(o, t) tagged[t] = tagged[t] or {} table.insert(tagged[t], o) end
function CS:GetTagged(t) return tagged[t] or {} end
function CS:GetInstanceAddedSignal(t) return signalOf(CS, "Tag_" .. t) end
local HS = M.services.HttpService
function HS:JSONEncode(v)
	local function enc(x)
		local t = type(x)
		if t == "table" then
			if #x > 0 or next(x) == nil then
				local parts = {} for _, y in ipairs(x) do table.insert(parts, enc(y)) end return "[" .. table.concat(parts, ",") .. "]"
			end
			local parts = {} for k, y in pairs(x) do table.insert(parts, string.format("%q:%s", tostring(k), enc(y))) end return "{" .. table.concat(parts, ",") .. "}"
		elseif t == "string" then return string.format("%q", x)
		elseif t == "number" or t == "boolean" then return tostring(x)
		elseif x == nil then return "null" end
		return "\"?\""
	end
	return enc(v)
end
-- DataStore en memoria
M.storeData = {}
local DSS = M.services.DataStoreService
function DSS:GetDataStore(name)
	local st = {}
	function st:UpdateAsync(key, fn)
		local cur = M.storeData[key]
		local new = fn(cur)
		if new ~= nil then M.storeData[key] = new end
		return new
	end
	function st:GetAsync(key) return M.storeData[key] end
	function st:SetAsync(key, v) M.storeData[key] = v end
	return st
end
local MS = M.services.MarketplaceService
function MS:UserOwnsGamePassAsync() return false end
function MS:PromptProductPurchase() end

function M.addPlayer(userId, name)
	local p = newInstance("Player")
	p.Name = name
	p.DisplayName = name
	p.UserId = userId
	p.LocaleId = "es-es"
	p.MembershipType = Enum.MembershipType.None
	local ch = newInstance("Model")
	ch.Name = name
	local hrp = newInstance("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.CFrame = CFrame.new(0, 103, 22)
	hrp.Parent = ch
	local hum = newInstance("Humanoid")
	hum.Parent = ch
	ch.PrimaryPart = hrp
	ch.Parent = workspace
	p.Character = ch
	p.Parent = M.services.Players
	table.insert(M.players, p)
	M.services.Players.PlayerAdded:Fire(p)
	return p
end

return M
