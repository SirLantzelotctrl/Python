--!nocheck
-- =====================================================================
--  Simulador mínimo de Roblox para probar Slime Heist fuera de Studio.
--  - Instancias falsas validadas contra el API-Dump oficial (propiedades,
--    tipos, permisos, eventos y métodos).
--  - Planificador con tiempo virtual (task.wait / delay / spawn / defer).
--  - Contextos separados de servidor y de cada cliente (cachés de require
--    independientes, RemoteEvents/RemoteFunctions entre contextos).
--  - DataStores en memoria con validación de serialización.
-- =====================================================================

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Sim = {}

Sim.Errors = {} :: { string }
Sim.Warnings = {} :: { string }
Sim.Prints = {} :: { string }
Sim.Unimplemented = {} :: { [string]: number }
Sim.Verbose = false
Sim.IsStudio = true
Sim.Epoch = 1_800_000_000
Sim.DataStoreFail = false
Sim.Kicked = {} :: { [number]: string }
Sim.PromptedPurchases = {} :: { any }
Sim.OwnedPasses = {} :: { [number]: { [number]: boolean } }
Sim.Friends = {} :: { [string]: boolean }

local Enum = roblox.Enum

-- ---------------------------------------------------------------------
-- API dump
-- ---------------------------------------------------------------------
local API = { Classes = {}, Enums = {} }

local function toSet(list)
	local set = {}
	if list then
		for _, v in list do
			if type(v) == "string" then
				set[v] = true
			end
		end
	end
	return set
end

function Sim.LoadApi(path: string)
	local dump = serde.decode("json", fs.readFile(path))
	for _, class in dump.Classes do
		local entry = {
			Name = class.Name,
			Superclass = class.Superclass,
			Tags = toSet(class.Tags),
			Properties = {},
			Functions = {},
			Events = {},
			Callbacks = {},
		}
		for _, member in class.Members do
			local tags = toSet(member.Tags)
			if member.MemberType == "Property" then
				local security = member.Security
				local writeSecurity = if type(security) == "table" then security.Write else security
				local readSecurity = if type(security) == "table" then security.Read else security
				entry.Properties[member.Name] = {
					Type = member.ValueType,
					ReadOnly = tags.ReadOnly == true,
					NotScriptable = tags.NotScriptable == true,
					WriteSecurity = writeSecurity,
					ReadSecurity = readSecurity,
				}
			elseif member.MemberType == "Function" then
				entry.Functions[member.Name] = { Security = member.Security }
			elseif member.MemberType == "Event" then
				entry.Events[member.Name] = true
			elseif member.MemberType == "Callback" then
				entry.Callbacks[member.Name] = true
			end
		end
		API.Classes[class.Name] = entry
	end
end

local memberCache = {}
local function findMember(className: string, member: string)
	local key = className .. "." .. member
	local cached = memberCache[key]
	if cached ~= nil then
		if cached == false then
			return nil
		end
		return cached[1], cached[2]
	end
	local current = className
	while current and current ~= "<<<ROOT>>>" do
		local class = API.Classes[current]
		if not class then
			break
		end
		if class.Properties[member] then
			memberCache[key] = { "Property", class.Properties[member] }
			return "Property", class.Properties[member]
		elseif class.Functions[member] then
			memberCache[key] = { "Function", class.Functions[member] }
			return "Function", class.Functions[member]
		elseif class.Events[member] then
			memberCache[key] = { "Event", true }
			return "Event", true
		elseif class.Callbacks[member] then
			memberCache[key] = { "Callback", true }
			return "Callback", true
		end
		current = class.Superclass
	end
	memberCache[key] = false
	return nil
end

local function classIsA(className: string, target: string): boolean
	local current = className
	while current and current ~= "<<<ROOT>>>" do
		if current == target then
			return true
		end
		local class = API.Classes[current]
		if not class then
			return false
		end
		current = class.Superclass
	end
	return false
end

-- ---------------------------------------------------------------------
-- Errores y logs
-- ---------------------------------------------------------------------
function Sim.ReportError(message: string)
	table.insert(Sim.Errors, message)
	print("\27[31m[ERROR] " .. message .. "\27[0m")
end

function Sim.ReportWarning(message: string)
	table.insert(Sim.Warnings, message)
	if Sim.Verbose or not string.find(message, "Infinite yield", 1, true) then
		print("\27[33m[warn] " .. message .. "\27[0m")
	end
end

local function noteUnimplemented(name: string)
	Sim.Unimplemented[name] = (Sim.Unimplemented[name] or 0) + 1
end

-- ---------------------------------------------------------------------
-- Planificador con tiempo virtual
-- ---------------------------------------------------------------------
local Sched = {
	Now = 0,
	Queue = {},
	Seq = 0,
	Contexts = setmetatable({}, { __mode = "k" }),
	Cancelled = setmetatable({}, { __mode = "k" }),
	DefaultContext = nil,
}
Sim.Sched = Sched

function Sched.currentContext()
	local co = coroutine.running()
	return Sched.Contexts[co] or Sched.DefaultContext
end

local function resume(thread, ...)
	if coroutine.status(thread) ~= "suspended" then
		return
	end
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		Sim.ReportError(tostring(err) .. "\n" .. debug.traceback(thread))
	end
end
Sched.resume = resume

function Sched.spawnIn(context, fnOrThread, ...)
	local thread = if type(fnOrThread) == "thread" then fnOrThread else coroutine.create(fnOrThread)
	if not Sched.Contexts[thread] then
		Sched.Contexts[thread] = context
	end
	resume(thread, ...)
	return thread
end

function Sched.schedule(at: number, thread: thread, args)
	Sched.Seq += 1
	table.insert(Sched.Queue, { At = at, Seq = Sched.Seq, Thread = thread, Args = args })
end

local simTask = {}

function simTask.spawn(fnOrThread, ...)
	return Sched.spawnIn(Sched.currentContext(), fnOrThread, ...)
end

function simTask.defer(fnOrThread, ...)
	local thread = if type(fnOrThread) == "thread" then fnOrThread else coroutine.create(fnOrThread)
	Sched.Contexts[thread] = Sched.Contexts[thread] or Sched.currentContext()
	Sched.schedule(Sched.Now, thread, table.pack(...))
	return thread
end

function simTask.delay(seconds, fnOrThread, ...)
	local thread = if type(fnOrThread) == "thread" then fnOrThread else coroutine.create(fnOrThread)
	Sched.Contexts[thread] = Sched.Contexts[thread] or Sched.currentContext()
	Sched.schedule(Sched.Now + (seconds or 0), thread, table.pack(...))
	return thread
end

function simTask.wait(seconds)
	local co = coroutine.running()
	if not Sched.Contexts[co] then
		error("task.wait llamado fuera de un hilo del simulador")
	end
	local duration = math.max(seconds or 0, 1 / 60)
	local start = Sched.Now
	Sched.schedule(Sched.Now + duration, co, "WAIT")
	coroutine.yield()
	return Sched.Now - start
end

function simTask.cancel(thread)
	Sched.Cancelled[thread] = true
end

function simTask.synchronize() end
function simTask.desynchronize() end

Sim.Task = simTask

-- Ejecuta todo lo que toque hasta "Now"
local function runDue()
	local guard = 0
	while true do
		guard += 1
		if guard > 200000 then
			Sim.ReportError("Planificador: demasiadas iteraciones (¿bucle infinito sin espera?)")
			return
		end
		local bestIndex, best = nil, nil
		for index, item in Sched.Queue do
			if item.At <= Sched.Now + 1e-9 and (best == nil or item.At < best.At or (item.At == best.At and item.Seq < best.Seq)) then
				bestIndex, best = index, item
			end
		end
		if not best then
			return
		end
		table.remove(Sched.Queue, bestIndex)
		local threadContext = Sched.Contexts[best.Thread]
		if not Sched.Cancelled[best.Thread] and not (threadContext and threadContext.Dead) then
			if best.Args == "WAIT" then
				resume(best.Thread)
			else
				resume(best.Thread, table.unpack(best.Args, 1, best.Args.n or #best.Args))
			end
		end
	end
end

-- ---------------------------------------------------------------------
-- Señales (RBXScriptSignal)
-- ---------------------------------------------------------------------
local SignalMT = {}
SignalMT.__index = SignalMT
local signalSet = setmetatable({}, { __mode = "k" })
local connectionSet = setmetatable({}, { __mode = "k" })

local function newSignal(name: string)
	local signal = setmetatable({ Name = name, Conns = {}, Waiting = {} }, SignalMT)
	signalSet[signal] = true
	return signal
end
Sim.NewSignal = newSignal

function SignalMT:Connect(fn)
	if type(fn) ~= "function" then
		error("Attempt to connect failed: Passed value is not a function", 2)
	end
	local conn = { Connected = true, Fn = fn, Context = Sched.currentContext(), Signal = self }
	function conn.Disconnect(c)
		c.Connected = false
		local index = table.find(self.Conns, c)
		if index then
			table.remove(self.Conns, index)
		end
	end
	setmetatable(conn, {
		__index = function(_, key)
			error(tostring(key) .. " is not a valid member of RBXScriptConnection", 2)
		end,
	})
	connectionSet[conn] = true
	table.insert(self.Conns, conn)
	return conn
end

function SignalMT:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

function SignalMT:ConnectParallel(fn)
	return self:Connect(fn)
end

function SignalMT:Wait()
	local co = coroutine.running()
	table.insert(self.Waiting, co)
	return coroutine.yield()
end

-- Solo para el simulador: dispara a todos, o solo a conexiones cuyo contexto pase el filtro
function SignalMT:Fire(...)
	self:FireFiltered(nil, ...)
end

function SignalMT:FireFiltered(filter, ...)
	for _, conn in table.clone(self.Conns) do
		if conn.Connected and not (conn.Context and conn.Context.Dead) and (filter == nil or filter(conn.Context)) then
			Sched.spawnIn(conn.Context, conn.Fn, ...)
		end
	end
	local waiting = self.Waiting
	self.Waiting = {}
	for _, co in waiting do
		resume(co, ...)
	end
end

-- ---------------------------------------------------------------------
-- Datatypes extra (TweenInfo, Random)
-- ---------------------------------------------------------------------
local typeTags = setmetatable({}, { __mode = "k" })

local SimTweenInfo = {}
function SimTweenInfo.new(time, style, direction, repeatCount, reverses, delayTime)
	local info = {
		Time = time or 1,
		EasingStyle = style or Enum.EasingStyle.Quad,
		EasingDirection = direction or Enum.EasingDirection.Out,
		RepeatCount = repeatCount or 0,
		Reverses = reverses or false,
		DelayTime = delayTime or 0,
	}
	if typeof(info.EasingStyle) ~= "EnumItem" or typeof(info.EasingDirection) ~= "EnumItem" then
		error("TweenInfo.new: estilo/dirección inválidos", 2)
	end
	typeTags[info] = "TweenInfo"
	return table.freeze(info)
end

local SimRandom = {}
local RandomMT = {}
RandomMT.__index = RandomMT
function SimRandom.new(seed)
	local state = (seed or (os.clock() * 1e6)) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	local rng = setmetatable({ State = state }, RandomMT)
	typeTags[rng] = "Random"
	return rng
end
function RandomMT:_next()
	self.State = (self.State * 16807) % 2147483647
	return self.State / 2147483647
end
function RandomMT:NextNumber(min, max)
	local n = self:_next()
	if min then
		return min + n * ((max or 1) - min)
	end
	return n
end
function RandomMT:NextInteger(min, max)
	return math.floor(min + self:_next() * (max - min + 1))
end

-- ---------------------------------------------------------------------
-- Instancias
-- ---------------------------------------------------------------------
local S = setmetatable({}, { __mode = "k" }) -- estado interno de cada instancia
local InstanceMT = {}
local Custom = {} -- [ClassName] = { [member] = function/getter }
local Getters = {}
local Setters = {}
local Defaults = {}

local DataModel -- game

local function isInstance(value)
	return type(value) == "table" and S[value] ~= nil
end
Sim.IsInstance = isInstance

local function simTypeof(value)
	if type(value) == "table" then
		if S[value] then
			return "Instance"
		elseif signalSet[value] then
			return "RBXScriptSignal"
		elseif connectionSet[value] then
			return "RBXScriptConnection"
		elseif typeTags[value] then
			return typeTags[value]
		end
	end
	return typeof(value)
end
Sim.typeof = simTypeof

local function fullName(obj)
	local parts = {}
	local current = obj
	while current and current ~= DataModel do
		table.insert(parts, 1, S[current].Props.Name)
		current = S[current].Parent
	end
	return table.concat(parts, ".")
end

local function getSignal(obj, name)
	local st = S[obj]
	local signal = st.Signals[name]
	if not signal then
		signal = newSignal(name)
		st.Signals[name] = signal
	end
	return signal
end
Sim.GetSignal = getSignal

local function isInGame(obj)
	local current = obj
	while current do
		if current == DataModel then
			return true
		end
		current = S[current].Parent
	end
	return false
end

local function isDescendantOf(obj, ancestor)
	local current = S[obj].Parent
	while current do
		if current == ancestor then
			return true
		end
		current = S[current].Parent
	end
	return false
end

local function descendants(obj, out)
	out = out or {}
	for _, child in S[obj].Children do
		table.insert(out, child)
		descendants(child, out)
	end
	return out
end

-- Validación de tipos de propiedades
local DATATYPE_ALIASES = {
	Content = { string = true, Content = true },
	ContentId = { string = true },
	BinaryString = { string = true },
	ProtectedString = { string = true },
	QDir = { string = true },
	QFont = { string = true },
}

local function checkType(className, propName, info, value)
	local valueType = info.Type
	if not valueType then
		return
	end
	local category, name = valueType.Category, valueType.Name
	local actual = simTypeof(value)
	if category == "Primitive" then
		if name == "bool" then
			if actual ~= "boolean" then
				error(("Invalid value for %s.%s: expected bool, got %s"):format(className, propName, actual), 4)
			end
		elseif name == "string" then
			if actual ~= "string" then
				error(("Invalid value for %s.%s: expected string, got %s"):format(className, propName, actual), 4)
			end
		else
			if actual ~= "number" then
				error(("Invalid value for %s.%s: expected number, got %s"):format(className, propName, actual), 4)
			end
			if value ~= value then
				error(("NaN asignado a %s.%s"):format(className, propName), 4)
			end
		end
	elseif category == "DataType" then
		local alias = DATATYPE_ALIASES[name]
		if alias then
			if not alias[actual] then
				error(("Invalid value for %s.%s: expected %s, got %s"):format(className, propName, name, actual), 4)
			end
		elseif value == nil then
			if name ~= "PhysicalProperties" and name ~= "Font" then
				error(("Invalid value for %s.%s: nil"):format(className, propName), 4)
			end
		elseif actual ~= name then
			error(("Invalid value for %s.%s: expected %s, got %s"):format(className, propName, name, actual), 4)
		end
	elseif category == "Enum" then
		if actual ~= "EnumItem" or tostring(value.EnumType) ~= ("Enum." .. name) and tostring(value.EnumType) ~= name then
			error(("Invalid value for %s.%s: expected Enum.%s, got %s (%s)"):format(className, propName, name, actual, tostring(value)), 4)
		end
	elseif category == "Class" then
		if value ~= nil and (not isInstance(value) or not classIsA(S[value].Class, name)) then
			error(("Invalid value for %s.%s: expected %s instance"):format(className, propName, name), 4)
		end
	end
end

local function defaultFor(className, propName, info)
	local current = className
	while current and current ~= "<<<ROOT>>>" do
		local defaults = Defaults[current]
		if defaults and defaults[propName] ~= nil then
			local value = defaults[propName]
			if type(value) == "function" then
				return value()
			end
			return value
		end
		local class = API.Classes[current]
		current = class and class.Superclass
	end
	local valueType = info.Type
	if not valueType then
		return nil
	end
	local category, name = valueType.Category, valueType.Name
	if category == "Primitive" then
		if name == "bool" then
			return false
		elseif name == "string" then
			return ""
		end
		return 0
	elseif category == "DataType" then
		local ctor = roblox[name]
		if name == "Vector3" then
			return roblox.Vector3.zero
		elseif name == "Vector2" then
			return roblox.Vector2.zero
		elseif name == "CFrame" then
			return roblox.CFrame.new()
		elseif name == "Color3" then
			return roblox.Color3.fromRGB(163, 162, 165)
		elseif name == "UDim2" then
			return roblox.UDim2.new()
		elseif name == "UDim" then
			return roblox.UDim.new()
		elseif name == "Content" or name == "ContentId" then
			return ""
		elseif ctor and ctor.new then
			local ok, value = pcall(ctor.new)
			if ok then
				return value
			end
		end
		return nil
	elseif category == "Enum" then
		local ok, items = pcall(function()
			return Enum[name]:GetEnumItems()
		end)
		if ok and items then
			return items[1]
		end
		return nil
	end
	return nil
end

local function fireChanged(obj, prop)
	local st = S[obj]
	if st.Signals.Changed then
		st.Signals.Changed:Fire(prop)
	end
	local propSignal = st.PropSignals[prop]
	if propSignal then
		propSignal:Fire()
	end
end

-- CollectionService
local tagAdded = {}
local tagRemoved = {}
local function tagSignal(map, tag)
	map[tag] = map[tag] or newSignal("Tag:" .. tag)
	return map[tag]
end

local function setParent(obj, newParent)
	local st = S[obj]
	if st.ParentLocked then
		error(("The Parent property of %s is locked, current parent: NULL"):format(st.Props.Name), 3)
	end
	if newParent ~= nil and not isInstance(newParent) then
		error("Parent must be an Instance or nil", 3)
	end
	if newParent == obj or (newParent and isDescendantOf(newParent, obj)) then
		error("Attempt to set parent of " .. st.Props.Name .. " to itself or a descendant", 3)
	end
	local old = st.Parent
	if old == newParent then
		return
	end
	local wasInGame = isInGame(obj)
	if old then
		local siblings = S[old].Children
		local index = table.find(siblings, obj)
		if index then
			table.remove(siblings, index)
		end
	end
	st.Parent = newParent
	if newParent then
		table.insert(S[newParent].Children, obj)
	end
	local nowInGame = isInGame(obj)

	if old and S[old].Signals.ChildRemoved then
		S[old].Signals.ChildRemoved:Fire(obj)
	end
	if newParent then
		if S[newParent].Signals.ChildAdded then
			S[newParent].Signals.ChildAdded:Fire(obj)
		end
		local all = { obj }
		descendants(obj, all)
		local ancestor = newParent
		while ancestor do
			local signal = S[ancestor].Signals.DescendantAdded
			if signal then
				for _, d in all do
					signal:Fire(d)
				end
			end
			ancestor = S[ancestor].Parent
		end
	end
	if wasInGame ~= nowInGame then
		local all = { obj }
		descendants(obj, all)
		for _, d in all do
			for tag in S[d].Tags do
				local signal = if nowInGame then tagAdded[tag] else tagRemoved[tag]
				if signal then
					signal:Fire(d)
				end
			end
		end
	end
	fireChanged(obj, "Parent")
	if st.Signals.AncestryChanged then
		st.Signals.AncestryChanged:Fire(obj, newParent)
	end
end

local function newInstance(className: string)
	local obj = setmetatable({}, InstanceMT)
	S[obj] = {
		Class = className,
		Props = { Name = className },
		Children = {},
		Parent = nil,
		Attributes = {},
		Tags = {},
		Signals = {},
		PropSignals = {},
		AttrSignals = {},
		Callbacks = {},
		ParentLocked = false,
		Destroyed = false,
	}
	return obj
end

local function simInstanceNew(className, parent)
	if type(className) ~= "string" then
		error("Instance.new: className must be a string", 2)
	end
	local class = API.Classes[className]
	if not class then
		error(("Unable to create an Instance of type \"%s\""):format(className), 2)
	end
	if class.Tags.NotCreatable or class.Tags.Service then
		error(("Unable to create an Instance of type \"%s\" (NotCreatable)"):format(className), 2)
	end
	local obj = newInstance(className)
	if Custom[className] and Custom[className].__init then
		Custom[className].__init(obj)
	end
	if parent then
		obj.Parent = parent
	end
	return obj
end
Sim.NewInstance = simInstanceNew

local function findCustom(className, key)
	local current = className
	while current and current ~= "<<<ROOT>>>" do
		local custom = Custom[current]
		if custom and custom[key] ~= nil then
			return custom[key]
		end
		local class = API.Classes[current]
		current = class and class.Superclass
	end
	return nil
end

local function findAccessor(map, className, key)
	local current = className
	while current and current ~= "<<<ROOT>>>" do
		local entry = map[current]
		if entry and entry[key] then
			return entry[key]
		end
		local class = API.Classes[current]
		current = class and class.Superclass
	end
	return nil
end

InstanceMT.__index = function(obj, key)
	local st = S[obj]
	if type(key) ~= "string" then
		error("Instance index must be a string", 2)
	end
	local custom = findCustom(st.Class, key)
	if custom ~= nil then
		return custom
	end
	local kind, info = findMember(st.Class, key)
	if kind == "Property" then
		if info.NotScriptable then
			error(("%s is not a valid member of %s (not scriptable)"):format(key, st.Class), 2)
		end
		local getter = findAccessor(Getters, st.Class, key)
		if getter then
			return getter(obj)
		end
		local value = st.Props[key]
		if value == nil and key ~= "Parent" then
			value = defaultFor(st.Class, key, info)
		end
		if key == "Parent" then
			return st.Parent
		end
		return value
	elseif kind == "Event" then
		return getSignal(obj, key)
	elseif kind == "Function" then
		return function()
			noteUnimplemented(st.Class .. ":" .. key)
			return nil
		end
	elseif kind == "Callback" then
		return st.Callbacks[key]
	end
	for _, child in st.Children do
		if S[child].Props.Name == key then
			return child
		end
	end
	error(("%s is not a valid member of %s \"%s\""):format(key, st.Class, fullName(obj)), 2)
end

InstanceMT.__newindex = function(obj, key, value)
	local st = S[obj]
	local setter = findAccessor(Setters, st.Class, key)
	local kind, info = findMember(st.Class, key)
	if kind == "Property" then
		if info.NotScriptable then
			error(("%s is not a valid member of %s (not scriptable)"):format(key, st.Class), 2)
		end
		if info.ReadOnly and not setter then
			error(("Unable to assign property %s. Property is read only"):format(key), 2)
		end
		if info.WriteSecurity and info.WriteSecurity ~= "None" then
			error(("The current thread cannot write '%s' (lacking capability %s)"):format(key, tostring(info.WriteSecurity)), 2)
		end
		if key ~= "Parent" then
			checkType(st.Class, key, info, value)
		end
		if setter then
			setter(obj, value)
			return
		end
		local old = st.Props[key]
		st.Props[key] = value
		if old ~= value then
			fireChanged(obj, key)
		end
		return
	elseif kind == "Callback" then
		if value ~= nil and type(value) ~= "function" then
			error(key .. " must be a function", 2)
		end
		st.Callbacks[key] = value
		return
	end
	error(("%s is not a valid member of %s \"%s\""):format(tostring(key), st.Class, fullName(obj)), 2)
end

InstanceMT.__tostring = function(obj)
	return S[obj].Props.Name
end

local linkParts -- definido más abajo (soldaduras)

-- Métodos comunes de Instance
Custom.Instance = {}
local I = Custom.Instance

function I.IsA(self, className)
	return classIsA(S[self].Class, className)
end

function I.FindFirstChild(self, name, recursive)
	for _, child in S[self].Children do
		if S[child].Props.Name == name then
			return child
		end
	end
	if recursive then
		for _, child in S[self].Children do
			local found = I.FindFirstChild(child, name, true)
			if found then
				return found
			end
		end
	end
	return nil
end

function I.FindFirstChildOfClass(self, className)
	for _, child in S[self].Children do
		if S[child].Class == className then
			return child
		end
	end
	return nil
end

function I.FindFirstChildWhichIsA(self, className, recursive)
	for _, child in S[self].Children do
		if classIsA(S[child].Class, className) then
			return child
		end
	end
	if recursive then
		for _, child in S[self].Children do
			local found = I.FindFirstChildWhichIsA(child, className, true)
			if found then
				return found
			end
		end
	end
	return nil
end

function I.FindFirstAncestor(self, name)
	local current = S[self].Parent
	while current do
		if S[current].Props.Name == name then
			return current
		end
		current = S[current].Parent
	end
	return nil
end

function I.FindFirstAncestorOfClass(self, className)
	local current = S[self].Parent
	while current do
		if S[current].Class == className then
			return current
		end
		current = S[current].Parent
	end
	return nil
end

function I.FindFirstAncestorWhichIsA(self, className)
	local current = S[self].Parent
	while current do
		if classIsA(S[current].Class, className) then
			return current
		end
		current = S[current].Parent
	end
	return nil
end

function I.WaitForChild(self, name, timeout)
	local found = I.FindFirstChild(self, name)
	if found then
		return found
	end
	local waited = 0
	local warned = false
	while true do
		simTask.wait(1 / 30)
		waited += 1 / 30
		found = I.FindFirstChild(self, name)
		if found then
			return found
		end
		if timeout and waited >= timeout then
			return nil
		end
		if not timeout and waited > 5 and not warned then
			warned = true
			Sim.ReportWarning(("Infinite yield possible on '%s:WaitForChild(\"%s\")'"):format(fullName(self), name))
		end
	end
end

function I.GetChildren(self)
	return table.clone(S[self].Children)
end

function I.GetDescendants(self)
	return descendants(self)
end

function I.IsDescendantOf(self, ancestor)
	return isDescendantOf(self, ancestor)
end

function I.IsAncestorOf(self, descendant)
	return isDescendantOf(descendant, self)
end

function I.GetFullName(self)
	return fullName(self)
end

function I.ClearAllChildren(self)
	for _, child in table.clone(S[self].Children) do
		I.Destroy(child)
	end
end

function I.Destroy(self)
	local st = S[self]
	if st.Destroyed then
		return
	end
	for _, child in table.clone(st.Children) do
		I.Destroy(child)
	end
	if st.Parent then
		setParent(self, nil)
	end
	if st.Class == "WeldConstraint" then
		linkParts(st.Props.Part0, st.Props.Part1, false)
	end
	st.Destroyed = true
	st.ParentLocked = true
	if st.Signals.Destroying then
		st.Signals.Destroying:Fire()
	end
	for _, signal in st.Signals do
		table.clear(signal.Conns)
	end
end

function I.Clone(self)
	local st = S[self]
	if st.Class == "Player" then
		return nil
	end
	local copy = newInstance(st.Class)
	local cst = S[copy]
	for key, value in st.Props do
		cst.Props[key] = value
	end
	for key, value in st.Attributes do
		cst.Attributes[key] = value
	end
	for tag in st.Tags do
		cst.Tags[tag] = true
	end
	cst.SourcePath = st.SourcePath
	cst.Source = st.Source
	for _, child in st.Children do
		local childCopy = I.Clone(child)
		if childCopy then
			setParent(childCopy, copy)
		end
	end
	return copy
end

local ATTRIBUTE_TYPES = {
	boolean = true,
	number = true,
	string = true,
	Vector3 = true,
	Vector2 = true,
	Color3 = true,
	UDim = true,
	UDim2 = true,
	CFrame = true,
	NumberRange = true,
	NumberSequence = true,
	ColorSequence = true,
	Rect = true,
	BrickColor = true,
	EnumItem = true,
	Font = true,
}

function I.SetAttribute(self, name, value)
	if type(name) ~= "string" or not string.match(name, "^[%w_]+$") or #name > 100 then
		error("Invalid attribute name: " .. tostring(name), 2)
	end
	if value ~= nil and not ATTRIBUTE_TYPES[simTypeof(value)] then
		error(("SetAttribute: type %s is not supported (%s)"):format(simTypeof(value), name), 2)
	end
	local st = S[self]
	local old = st.Attributes[name]
	st.Attributes[name] = value
	if old ~= value then
		if st.AttrSignals[name] then
			st.AttrSignals[name]:Fire()
		end
		if st.Signals.AttributeChanged then
			st.Signals.AttributeChanged:Fire(name)
		end
	end
end

function I.GetAttribute(self, name)
	return S[self].Attributes[name]
end

function I.GetAttributes(self)
	return table.clone(S[self].Attributes)
end

function I.GetAttributeChangedSignal(self, name)
	local st = S[self]
	st.AttrSignals[name] = st.AttrSignals[name] or newSignal("Attr:" .. name)
	return st.AttrSignals[name]
end

function I.GetPropertyChangedSignal(self, prop)
	local st = S[self]
	local kind = findMember(st.Class, prop)
	if kind ~= "Property" then
		error(("%s is not a valid property name."):format(tostring(prop)), 2)
	end
	st.PropSignals[prop] = st.PropSignals[prop] or newSignal("Prop:" .. prop)
	return st.PropSignals[prop]
end

local function addTag(obj, tag)
	local st = S[obj]
	if st.Tags[tag] then
		return
	end
	st.Tags[tag] = true
	if isInGame(obj) and tagAdded[tag] then
		tagAdded[tag]:Fire(obj)
	end
end

local function removeTag(obj, tag)
	local st = S[obj]
	if not st.Tags[tag] then
		return
	end
	st.Tags[tag] = nil
	if isInGame(obj) and tagRemoved[tag] then
		tagRemoved[tag]:Fire(obj)
	end
end

function I.AddTag(self, tag)
	addTag(self, tag)
end
function I.RemoveTag(self, tag)
	removeTag(self, tag)
end
function I.HasTag(self, tag)
	return S[self].Tags[tag] == true
end
function I.GetTags(self)
	local list = {}
	for tag in S[self].Tags do
		table.insert(list, tag)
	end
	return list
end

-- Name y Parent
Setters.Instance = {
	Parent = function(obj, value)
		setParent(obj, value)
	end,
}
Getters.Instance = {
	Parent = function(obj)
		return S[obj].Parent
	end,
	ClassName = function(obj)
		return S[obj].Class
	end,
}

-- ---------------------------------------------------------------------
-- Defaults razonables
-- ---------------------------------------------------------------------
Defaults.BasePart = {
	Size = function()
		return roblox.Vector3.new(4, 1, 2)
	end,
	Anchored = false,
	CanCollide = true,
	CanTouch = true,
	CanQuery = true,
	CastShadow = true,
	CollisionGroup = "Default",
	Material = Enum.Material.Plastic,
}
Defaults.Part = { Shape = Enum.PartType.Block }
Defaults.GuiObject = {
	Visible = true,
	Size = function()
		return roblox.UDim2.fromOffset(100, 100)
	end,
	BackgroundTransparency = 0,
	Active = true,
}
Defaults.GuiBase2d = {}
Defaults.LayerCollector = { Enabled = true, ResetOnSpawn = true }
Defaults.BillboardGui = { Enabled = true }
Defaults.SurfaceGuiBase = { Enabled = true }
Defaults.ProximityPrompt = { Enabled = true, HoldDuration = 0, MaxActivationDistance = 10, RequiresLineOfSight = true, KeyboardKeyCode = Enum.KeyCode.E }
Defaults.Humanoid = { WalkSpeed = 16, Health = 100, MaxHealth = 100, JumpPower = 50 }
Defaults.Camera = {
	ViewportSize = function()
		return roblox.Vector2.new(1280, 720)
	end,
	FieldOfView = 70,
}
Defaults.Sound = { Volume = 0.5 }
Defaults.Light = { Enabled = true, Brightness = 1 }
Defaults.ParticleEmitter = { Enabled = true, Rate = 5 }
Defaults.Tool = { Enabled = true, RequiresHandle = true, CanBeDropped = true }
Defaults.UIStroke = { Enabled = true, Thickness = 1 }
Defaults.UIScale = { Scale = 1 }

-- ---------------------------------------------------------------------
-- BasePart / Model
-- ---------------------------------------------------------------------
-- Soldaduras (WeldConstraint): mover una pieza mueve todo el conjunto soldado
local welds = setmetatable({}, { __mode = "k" })

linkParts = function(a, b, linked)
	if not a or not b then
		return
	end
	welds[a] = welds[a] or {}
	welds[b] = welds[b] or {}
	welds[a][b] = if linked then true else nil
	welds[b][a] = if linked then true else nil
end

local function connectedParts(startParts)
	local seen = {}
	local queue = {}
	for _, part in startParts do
		if not seen[part] then
			seen[part] = true
			table.insert(queue, part)
		end
	end
	local index = 1
	while index <= #queue do
		local part = queue[index]
		index += 1
		local neighbours = welds[part]
		if neighbours then
			for other in neighbours do
				if not seen[other] and not S[other].Destroyed then
					seen[other] = true
					table.insert(queue, other)
				end
			end
		end
	end
	return seen
end

local function moveGroup(parts, delta)
	for part in parts do
		S[part].Props.CFrame = delta * (S[part].Props.CFrame or roblox.CFrame.new())
		fireChanged(part, "CFrame")
	end
end

Setters.WeldConstraint = {
	Part0 = function(obj, value)
		local st = S[obj]
		linkParts(st.Props.Part0, st.Props.Part1, false)
		st.Props.Part0 = value
		linkParts(st.Props.Part0, st.Props.Part1, true)
	end,
	Part1 = function(obj, value)
		local st = S[obj]
		linkParts(st.Props.Part0, st.Props.Part1, false)
		st.Props.Part1 = value
		linkParts(st.Props.Part0, st.Props.Part1, true)
	end,
}

Getters.BasePart = {
	Position = function(obj)
		local cf = S[obj].Props.CFrame or roblox.CFrame.new()
		return cf.Position
	end,
	Orientation = function()
		return roblox.Vector3.zero
	end,
}
local function setPartCFrame(obj, value)
	local old = S[obj].Props.CFrame or roblox.CFrame.new()
	local group = connectedParts({ obj })
	moveGroup(group, value * old:Inverse())
	S[obj].Props.CFrame = value
end

Setters.BasePart = {
	Position = function(obj, value)
		local cf = S[obj].Props.CFrame or roblox.CFrame.new()
		setPartCFrame(obj, roblox.CFrame.new(value) * cf.Rotation)
		fireChanged(obj, "Position")
	end,
	CFrame = function(obj, value)
		setPartCFrame(obj, value)
	end,
}
Custom.BasePart = {
	GetPivot = function(self)
		return S[self].Props.CFrame or roblox.CFrame.new()
	end,
	PivotTo = function(self, cf)
		self.CFrame = cf
	end,
	ApplyImpulse = function() end,
	ApplyAngularImpulse = function() end,
	GetMass = function()
		return 1
	end,
	GetTouchingParts = function()
		return {}
	end,
}

local function modelPivot(model)
	local primary = S[model].Props.PrimaryPart
	if primary then
		return primary.CFrame
	end
	for _, d in descendants(model) do
		if classIsA(S[d].Class, "BasePart") then
			return d.CFrame
		end
	end
	return roblox.CFrame.new()
end

Custom.PVInstance = {
	GetPivot = function(self)
		if classIsA(S[self].Class, "Model") then
			return modelPivot(self)
		end
		return roblox.CFrame.new()
	end,
}
Custom.Model = {
	GetPivot = function(self)
		return modelPivot(self)
	end,
	PivotTo = function(self, cf)
		if simTypeof(cf) ~= "CFrame" then
			error("PivotTo expects a CFrame", 2)
		end
		local old = modelPivot(self)
		local delta = cf * old:Inverse()
		local parts = {}
		for _, d in descendants(self) do
			if classIsA(S[d].Class, "BasePart") then
				table.insert(parts, d)
			end
		end
		moveGroup(connectedParts(parts), delta)
	end,
	GetBoundingBox = function(self)
		return modelPivot(self), roblox.Vector3.new(4, 4, 4)
	end,
	GetExtentsSize = function()
		return roblox.Vector3.new(4, 4, 4)
	end,
}
Setters.Model = {
	PrimaryPart = function(obj, value)
		if value ~= nil and not isDescendantOf(value, obj) then
			Sim.ReportWarning("Model.PrimaryPart asignado a una pieza que no es descendiente: " .. fullName(obj))
		end
		S[obj].Props.PrimaryPart = value
	end,
}

Getters.Attachment = {
	WorldPosition = function(obj)
		local parent = S[obj].Parent
		local position = S[obj].Props.Position or roblox.Vector3.zero
		if parent and classIsA(S[parent].Class, "BasePart") then
			return parent.CFrame * position
		end
		return position
	end,
}
Setters.Attachment = {
	WorldPosition = function(obj, value)
		S[obj].Props.Position = value
	end,
}

-- ---------------------------------------------------------------------
-- Tweens
-- ---------------------------------------------------------------------
Custom.Tween = {
	Play = function(self)
		local st = S[self]
		local token = {}
		st.Token = token
		simTask.delay(st.Info.Time + st.Info.DelayTime, function()
			if st.Token ~= token then
				return
			end
			for key, value in st.Goals do
				if not S[st.Target].Destroyed then
					st.Target[key] = value
				end
			end
			getSignal(self, "Completed"):Fire(Enum.PlaybackState.Completed)
		end)
	end,
	Cancel = function(self)
		S[self].Token = nil
		getSignal(self, "Completed"):Fire(Enum.PlaybackState.Cancelled)
	end,
	Pause = function(self)
		S[self].Token = nil
	end,
}

Custom.TweenService = {
	Create = function(_self, target, info, goals)
		if not isInstance(target) then
			error("TweenService:Create: target inválido", 2)
		end
		if typeTags[info] ~= "TweenInfo" then
			error("TweenService:Create: TweenInfo inválido", 2)
		end
		for key, value in goals do
			local kind, propInfo = findMember(S[target].Class, key)
			if kind ~= "Property" then
				error(("TweenService:Create: %s no es una propiedad de %s"):format(key, S[target].Class), 2)
			end
			checkType(S[target].Class, key, propInfo, value)
		end
		local tween = newInstance("Tween")
		S[tween].Target = target
		S[tween].Info = info
		S[tween].Goals = goals
		return tween
	end,
}

-- ---------------------------------------------------------------------
-- Contextos (servidor / clientes)
-- ---------------------------------------------------------------------
local Contexts = {}
Sim.Contexts = Contexts

local function newContext(kind, player)
	local context = { Kind = kind, Player = player, Cache = {} }
	table.insert(Contexts, context)
	return context
end

local ServerContext = newContext("Server", nil)
Sim.ServerContext = ServerContext
Sched.DefaultContext = ServerContext

-- ---------------------------------------------------------------------
-- Servicios
-- ---------------------------------------------------------------------
local services = {}

local function getService(name)
	if services[name] then
		return services[name]
	end
	local class = API.Classes[name]
	if not class then
		error(("'%s' is not a valid Service name"):format(tostring(name)), 3)
	end
	local service = newInstance(name)
	S[service].Props.Name = name
	setParent(service, DataModel)
	services[name] = service
	return service
end

Custom.DataModel = {
	GetService = function(_self, name)
		return getService(name)
	end,
	FindService = function(_self, name)
		return services[name]
	end,
	BindToClose = function(_self, fn)
		Sim.CloseCallbacks = Sim.CloseCallbacks or {}
		table.insert(Sim.CloseCallbacks, fn)
	end,
	IsLoaded = function()
		return true
	end,
}
Getters.DataModel = {
	JobId = function()
		return "sim-job-1"
	end,
	CreatorId = function()
		return 0
	end,
	CreatorType = function()
		return Enum.CreatorType.User
	end,
	PlaceId = function()
		return 0
	end,
}

Custom.RunService = {
	IsServer = function()
		return Sched.currentContext().Kind == "Server"
	end,
	IsClient = function()
		return Sched.currentContext().Kind == "Client"
	end,
	IsStudio = function()
		return Sim.IsStudio
	end,
	IsRunning = function()
		return true
	end,
}

Custom.Workspace = {
	GetServerTimeNow = function()
		return Sim.Epoch + Sched.Now
	end,
	Raycast = function()
		return nil
	end,
}

Custom.Players = {
	GetPlayers = function(self)
		local list = {}
		for _, child in S[self].Children do
			if S[child].Class == "Player" then
				table.insert(list, child)
			end
		end
		return list
	end,
	GetPlayerByUserId = function(self, userId)
		for _, child in S[self].Children do
			if S[child].Class == "Player" and S[child].Props.UserId == userId then
				return child
			end
		end
		return nil
	end,
	GetPlayerFromCharacter = function(self, character)
		for _, child in S[self].Children do
			if S[child].Class == "Player" and character ~= nil and S[child].Props.Character == character then
				return child
			end
		end
		return nil
	end,
	GetUserThumbnailAsync = function()
		simTask.wait(0.1)
		return "rbxthumb://type=AvatarHeadShot&id=1&w=150&h=150", true
	end,
	GetNameFromUserIdAsync = function(_self, userId)
		simTask.wait(0.05)
		return "User" .. tostring(userId)
	end,
}
Getters.Players = {
	LocalPlayer = function()
		local context = Sched.currentContext()
		return context.Player
	end,
}

Custom.Player = {
	Kick = function(self, message)
		Sim.Kicked[S[self].Props.UserId] = message or ""
		Sim.ReportWarning(("Player %s kicked: %s"):format(S[self].Props.Name, tostring(message)))
		simTask.defer(function()
			Sim.RemovePlayer(self)
		end)
	end,
	IsFriendsWith = function(self, userId)
		simTask.wait(0.05)
		local a, b = S[self].Props.UserId, userId
		return Sim.Friends[math.min(a, b) .. "-" .. math.max(a, b)] == true
	end,
	IsInGroup = function()
		simTask.wait(0.05)
		return false
	end,
	GetRankInGroup = function()
		simTask.wait(0.05)
		return 0
	end,
	LoadCharacter = function(self)
		Sim.SpawnCharacter(self)
	end,
}
Setters.Player = {
	Character = function(obj, value)
		S[obj].Props.Character = value
		fireChanged(obj, "Character")
	end,
}

Custom.Humanoid = {
	ChangeState = function() end,
	TakeDamage = function(self, amount)
		self.Health = math.max(0, self.Health - amount)
	end,
	MoveTo = function() end,
	LoadAnimation = function()
		return nil
	end,
}

Custom.CollectionService = {
	AddTag = function(_self, obj, tag)
		addTag(obj, tag)
	end,
	RemoveTag = function(_self, obj, tag)
		removeTag(obj, tag)
	end,
	HasTag = function(_self, obj, tag)
		return S[obj].Tags[tag] == true
	end,
	GetTagged = function(_self, tag)
		local list = {}
		for _, d in descendants(DataModel) do
			if S[d].Tags[tag] then
				table.insert(list, d)
			end
		end
		return list
	end,
	GetInstanceAddedSignal = function(_self, tag)
		return tagSignal(tagAdded, tag)
	end,
	GetInstanceRemovedSignal = function(_self, tag)
		return tagSignal(tagRemoved, tag)
	end,
}

local collisionGroups = { Default = true }
Custom.PhysicsService = {
	RegisterCollisionGroup = function(_self, name)
		collisionGroups[name] = true
	end,
	CollisionGroupSetCollidable = function(_self, a, b, collidable)
		if not collisionGroups[a] or not collisionGroups[b] then
			error("CollisionGroupSetCollidable: grupo no registrado " .. tostring(a) .. "/" .. tostring(b), 2)
		end
		if type(collidable) ~= "boolean" then
			error("CollisionGroupSetCollidable: collidable debe ser bool", 2)
		end
	end,
	IsCollisionGroupRegistered = function(_self, name)
		return collisionGroups[name] == true
	end,
}
local basePartSetters = Setters.BasePart
basePartSetters.CollisionGroup = function(obj, value)
	if not collisionGroups[value] then
		Sim.ReportWarning("CollisionGroup no registrado: " .. tostring(value))
	end
	S[obj].Props.CollisionGroup = value
end

Custom.Debris = {
	AddItem = function(_self, item, lifetime)
		simTask.delay(lifetime or 10, function()
			if not S[item].Destroyed then
				I.Destroy(item)
			end
		end)
	end,
}

Custom.SoundService = {
	PlayLocalSound = function(_self, sound)
		if not isInstance(sound) or S[sound].Class ~= "Sound" then
			error("PlayLocalSound expects a Sound", 2)
		end
	end,
}

Custom.Sound = {
	Play = function() end,
	Stop = function() end,
	Pause = function() end,
	Resume = function() end,
}

Custom.ParticleEmitter = {
	Emit = function() end,
	Clear = function() end,
}

-- DataStores en memoria ----------------------------------------------------
Sim.DataStores = {}

local function validateSerializable(value, path, seen)
	seen = seen or {}
	local t = simTypeof(value)
	if t == "table" then
		if seen[value] then
			error("DataStore: referencia cíclica en " .. path)
		end
		seen[value] = true
		local hasNumber, hasString = false, false
		local count, maxIndex = 0, 0
		for key, child in value do
			if type(key) == "number" then
				hasNumber = true
				count += 1
				maxIndex = math.max(maxIndex, key)
			elseif type(key) == "string" then
				hasString = true
			else
				error("DataStore: clave no serializable en " .. path)
			end
			validateSerializable(child, path .. "." .. tostring(key), seen)
		end
		if hasNumber and hasString then
			error("DataStore: tabla mixta (claves numéricas y de texto) en " .. path)
		end
		if hasNumber and maxIndex ~= count then
			error("DataStore: array con huecos en " .. path)
		end
	elseif t ~= "number" and t ~= "string" and t ~= "boolean" and t ~= "nil" then
		error(("DataStore: valor de tipo %s no serializable en %s"):format(t, path))
	elseif t == "number" and (value ~= value or value == math.huge or value == -math.huge) then
		error("DataStore: número inválido (NaN/inf) en " .. path)
	end
end

local function deepCopy(value)
	if type(value) ~= "table" or isInstance(value) then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = deepCopy(child)
	end
	return copy
end
Sim.DeepCopy = deepCopy

local function makeStore(name)
	local data = Sim.DataStores[name] or {}
	Sim.DataStores[name] = data
	local store = {}
	function store.GetAsync(_self, key)
		simTask.wait(0.05)
		if Sim.DataStoreFail then
			error("502: API Services rejected request (sim)")
		end
		return deepCopy(data[key])
	end
	function store.SetAsync(_self, key, value)
		simTask.wait(0.05)
		if Sim.DataStoreFail then
			error("502: API Services rejected request (sim)")
		end
		validateSerializable(value, name .. "/" .. key)
		data[key] = deepCopy(value)
	end
	function store.UpdateAsync(_self, key, transform)
		simTask.wait(0.05)
		if Sim.DataStoreFail then
			error("502: API Services rejected request (sim)")
		end
		local result = transform(deepCopy(data[key]), nil)
		if result ~= nil then
			validateSerializable(result, name .. "/" .. key)
			data[key] = deepCopy(result)
		end
		return deepCopy(result)
	end
	function store.RemoveAsync(_self, key)
		data[key] = nil
	end
	return store
end

local function makeOrderedStore(name)
	local data = Sim.DataStores["ordered:" .. name] or {}
	Sim.DataStores["ordered:" .. name] = data
	local store = {}
	function store.SetAsync(_self, key, value)
		simTask.wait(0.05)
		if type(value) ~= "number" or math.floor(value) ~= value or value < 0 or value > 2 ^ 63 then
			error("OrderedDataStore: valor no entero/válido " .. tostring(value))
		end
		data[key] = value
	end
	function store.GetSortedAsync(_self, ascending, pageSize)
		simTask.wait(0.05)
		local entries = {}
		for key, value in data do
			table.insert(entries, { key = key, value = value })
		end
		table.sort(entries, function(a, b)
			if ascending then
				return a.value < b.value
			end
			return a.value > b.value
		end)
		local page = {}
		for i = 1, math.min(pageSize, #entries) do
			page[i] = entries[i]
		end
		return {
			IsFinished = true,
			GetCurrentPage = function()
				return page
			end,
		}
	end
	return store
end

Custom.DataStoreService = {
	GetDataStore = function(_self, name)
		return makeStore(name)
	end,
	GetOrderedDataStore = function(_self, name)
		return makeOrderedStore(name)
	end,
}

-- Marketplace ---------------------------------------------------------------
Custom.MarketplaceService = {
	UserOwnsGamePassAsync = function(_self, userId, passId)
		simTask.wait(0.1)
		return Sim.OwnedPasses[userId] ~= nil and Sim.OwnedPasses[userId][passId] == true
	end,
	GetProductInfo = function(_self, id)
		simTask.wait(0.1)
		return { PriceInRobux = 77, Name = "Product " .. tostring(id) }
	end,
	PromptProductPurchase = function(_self, player, id)
		table.insert(Sim.PromptedPurchases, { Kind = "Product", Player = player, Id = id })
	end,
	PromptGamePassPurchase = function(_self, player, id)
		table.insert(Sim.PromptedPurchases, { Kind = "Pass", Player = player, Id = id })
	end,
}

-- Remotes -------------------------------------------------------------------
local function validateRemoteArg(value, path, seen)
	local t = simTypeof(value)
	if t == "function" then
		error("Remote: no se pueden enviar funciones (" .. path .. ")")
	elseif t == "table" then
		seen = seen or {}
		if seen[value] then
			error("Remote: tabla cíclica en " .. path)
		end
		seen[value] = true
		local hasNumber, hasString = false, false
		for key, child in value do
			if type(key) == "number" then
				hasNumber = true
			elseif type(key) == "string" then
				hasString = true
			else
				error("Remote: clave no válida en " .. path)
			end
			validateRemoteArg(child, path .. "." .. tostring(key), seen)
		end
		if hasNumber and hasString then
			error("Remote: tabla mixta en " .. path .. " (se perderán datos)")
		end
	end
end

local function copyArgs(...)
	local args = table.pack(...)
	for i = 1, args.n do
		validateRemoteArg(args[i], "arg" .. i)
		args[i] = deepCopy(args[i])
	end
	return args
end

local function clientFilter(player)
	return function(context)
		return context.Kind == "Client" and context.Player == player
	end
end

Custom.RemoteEvent = {
	FireClient = function(self, player, ...)
		if Sched.currentContext().Kind ~= "Server" then
			error("FireClient can only be called from the server", 2)
		end
		if not isInstance(player) or S[player].Class ~= "Player" then
			error("FireClient: argument 1 must be a Player", 2)
		end
		local args = copyArgs(...)
		getSignal(self, "OnClientEvent"):FireFiltered(clientFilter(player), table.unpack(args, 1, args.n))
	end,
	FireAllClients = function(self, ...)
		if Sched.currentContext().Kind ~= "Server" then
			error("FireAllClients can only be called from the server", 2)
		end
		local args = copyArgs(...)
		getSignal(self, "OnClientEvent"):FireFiltered(function(context)
			return context.Kind == "Client"
		end, table.unpack(args, 1, args.n))
	end,
	FireServer = function(self, ...)
		local context = Sched.currentContext()
		if context.Kind ~= "Client" then
			error("FireServer can only be called from the client", 2)
		end
		local args = copyArgs(...)
		getSignal(self, "OnServerEvent"):FireFiltered(function(c)
			return c.Kind == "Server"
		end, context.Player, table.unpack(args, 1, args.n))
	end,
}

Custom.RemoteFunction = {
	InvokeServer = function(self, ...)
		local context = Sched.currentContext()
		if context.Kind ~= "Client" then
			error("InvokeServer can only be called from the client", 2)
		end
		local args = copyArgs(...)
		local caller = coroutine.running()
		local done, results = false, nil
		Sched.spawnIn(ServerContext, function()
			while not S[self].Callbacks.OnServerInvoke do
				simTask.wait(0.1)
			end
			results = table.pack(S[self].Callbacks.OnServerInvoke(context.Player, table.unpack(args, 1, args.n)))
			for i = 1, results.n do
				validateRemoteArg(results[i], "return" .. i)
				results[i] = deepCopy(results[i])
			end
			done = true
			if coroutine.status(caller) == "suspended" then
				resume(caller)
			end
		end)
		if not done then
			coroutine.yield()
		end
		return table.unpack(results, 1, results.n)
	end,
}

-- ---------------------------------------------------------------------
-- Entorno de los scripts
-- ---------------------------------------------------------------------
local LOADING = {}

local simRequire

local function makeEnv(scriptInstance)
	local simOs = setmetatable({
		clock = function()
			return Sched.Now
		end,
		time = function(t)
			if t then
				return os.time(t)
			end
			return math.floor(Sim.Epoch + Sched.Now)
		end,
	}, { __index = os })
	return {
		script = scriptInstance,
		game = DataModel,
		workspace = getService("Workspace"),
		Instance = { new = simInstanceNew },
		Enum = Enum,
		typeof = simTypeof,
		require = simRequire,
		task = simTask,
		warn = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				table.insert(parts, tostring(select(i, ...)))
			end
			Sim.ReportWarning(table.concat(parts, " "))
		end,
		print = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				table.insert(parts, tostring(select(i, ...)))
			end
			local line = table.concat(parts, " ")
			table.insert(Sim.Prints, line)
			if Sim.Verbose then
				print("[game] " .. line)
			end
		end,
		tick = function()
			return Sim.Epoch + Sched.Now
		end,
		time = function()
			return Sched.Now
		end,
		os = simOs,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		Rect = roblox.Rect,
		BrickColor = roblox.BrickColor,
		PhysicalProperties = roblox.PhysicalProperties,
		Ray = roblox.Ray,
		Font = roblox.Font,
		TweenInfo = SimTweenInfo,
		Random = SimRandom,
	}
end

local function runScript(scriptInstance)
	local path = S[scriptInstance].SourcePath
	if not path then
		error("Script sin código fuente: " .. fullName(scriptInstance))
	end
	-- El código se lee al construir el árbol: las funciones async de Lune no pueden
	-- llamarse dentro de los hilos del simulador (cederían a otro planificador).
	local source = S[scriptInstance].Source
	local chunk = luau.load(source, { debugName = path, environment = makeEnv(scriptInstance) })
	return chunk()
end

simRequire = function(module)
	if not isInstance(module) or S[module].Class ~= "ModuleScript" then
		error("Attempted to call require with invalid argument(s).", 2)
	end
	local context = Sched.currentContext()
	local cache = context.Cache
	local cached = cache[module]
	if cached == LOADING then
		error("Requested module was required recursively: " .. fullName(module), 2)
	end
	if cached ~= nil then
		return cached
	end
	cache[module] = LOADING
	local ok, result = pcall(runScript, module)
	if not ok then
		cache[module] = nil
		error("Requested module experienced an error while loading: " .. fullName(module) .. "\n" .. tostring(result), 2)
	end
	if result == nil then
		cache[module] = nil
		error("Module code did not return exactly one value: " .. fullName(module), 2)
	end
	cache[module] = result
	return result
end

-- ---------------------------------------------------------------------
-- Construcción del árbol desde los ficheros (reglas de Rojo)
-- ---------------------------------------------------------------------
local function buildFromPath(path: string, name: string, parent)
	if fs.isDir(path) then
		local folder = newInstance("Folder")
		S[folder].Props.Name = name
		setParent(folder, parent)
		local entries = fs.readDir(path)
		table.sort(entries)
		for _, entry in entries do
			buildFromPath(path .. "/" .. entry, entry, folder)
		end
		return folder
	end
	local className, baseName
	if string.match(name, "%.server%.luau$") then
		className, baseName = "Script", string.gsub(name, "%.server%.luau$", "")
	elseif string.match(name, "%.client%.luau$") then
		className, baseName = "LocalScript", string.gsub(name, "%.client%.luau$", "")
	elseif string.match(name, "%.luau$") then
		className, baseName = "ModuleScript", string.gsub(name, "%.luau$", "")
	else
		return nil
	end
	local scriptInstance = newInstance(className)
	S[scriptInstance].Props.Name = baseName
	S[scriptInstance].SourcePath = path
	S[scriptInstance].Source = fs.readFile(path)
	setParent(scriptInstance, parent)
	return scriptInstance
end

function Sim.Init(options)
	Sim.LoadApi(options.ApiPath)
	Sim.IsStudio = options.IsStudio ~= false
	Sim.DataStoreFail = options.DataStoreFail == true
	DataModel = newInstance("DataModel")
	S[DataModel].Props.Name = "Game"
	Sim.Game = DataModel

	local workspaceService = getService("Workspace")
	local camera = newInstance("Camera")
	S[camera].Props.Name = "Camera"
	setParent(camera, workspaceService)
	S[workspaceService].Props.CurrentCamera = camera
	local terrain = newInstance("Terrain")
	S[terrain].Props.Name = "Terrain"
	setParent(terrain, workspaceService)
	Getters.Workspace = {
		Terrain = function()
			return terrain
		end,
	}

	local root = options.ProjectRoot
	local shared = buildFromPath(root .. "/src/shared", "Shared", getService("ReplicatedStorage"))
	local server = buildFromPath(root .. "/src/server", "Server", getService("ServerScriptService"))
	local starterPlayer = getService("StarterPlayer")
	local starterScripts = newInstance("StarterPlayerScripts")
	S[starterScripts].Props.Name = "StarterPlayerScripts"
	setParent(starterScripts, starterPlayer)
	local client = buildFromPath(root .. "/src/client", "Client", starterScripts)
	Sim.SharedFolder = shared
	Sim.ServerFolder = server
	Sim.ClientFolder = client
end

function Sim.Step(seconds: number, dt: number?)
	local stepSize = dt or (1 / 30)
	local target = Sched.Now + seconds
	local runService = getService("RunService")
	while Sched.Now < target - 1e-9 do
		local delta = math.min(stepSize, target - Sched.Now)
		Sched.Now += delta
		runDue()
		getSignal(runService, "Stepped"):Fire(Sched.Now, delta)
		getSignal(runService, "Heartbeat"):Fire(delta)
		getSignal(runService, "RenderStepped"):FireFiltered(function(context)
			return context.Kind == "Client"
		end, delta)
		runDue()
	end
end

function Sim.Run(context, fn, ...)
	return Sched.spawnIn(context, fn, ...)
end

-- Ejecuta fn en un contexto y avanza el tiempo hasta que termine
function Sim.RunAndWait(context, fn, maxSeconds)
	local done = false
	local results
	Sched.spawnIn(context, function()
		results = table.pack(fn())
		done = true
	end)
	local waited = 0
	while not done and waited < (maxSeconds or 30) do
		Sim.Step(1 / 30)
		waited += 1 / 30
	end
	if not done then
		Sim.ReportError("RunAndWait: no terminó a tiempo")
		return nil
	end
	return table.unpack(results, 1, results.n)
end

Sim.RunScript = runScript
Sim.Require = function(module)
	return simRequire(module)
end

function Sim.StartServer()
	for _, d in descendants(Sim.ServerFolder) do
		if S[d].Class == "Script" then
			Sched.spawnIn(ServerContext, function()
				runScript(d)
			end)
		end
	end
end

function Sim.ServerModule(instance)
	return ServerContext.Cache[instance]
end

function Sim.ClientModule(player, relativePath: { string })
	local context = Sim.ClientContexts[player]
	local current = S[player].Props.PlayerScriptsFolder
	for _, name in relativePath do
		current = I.FindFirstChild(current, name)
		if not current then
			return nil
		end
	end
	return context.Cache[current]
end

Sim.ClientContexts = {}

function Sim.SpawnCharacter(player)
	local old = S[player].Props.Character
	if old then
		I.Destroy(old)
	end
	local character = newInstance("Model")
	S[character].Props.Name = S[player].Props.Name
	local humanoid = newInstance("Humanoid")
	setParent(humanoid, character)
	local root = newInstance("Part")
	S[root].Props.Name = "HumanoidRootPart"
	S[root].Props.Size = roblox.Vector3.new(2, 2, 1)
	S[root].Props.CFrame = roblox.CFrame.new(-200, 4, 0)
	setParent(root, character)
	local head = newInstance("Part")
	S[head].Props.Name = "Head"
	S[head].Props.CFrame = roblox.CFrame.new(-200, 5.5, 0)
	setParent(head, character)
	S[character].Props.PrimaryPart = root
	local backpack = I.FindFirstChildOfClass(player, "Backpack")
	if not backpack then
		backpack = newInstance("Backpack")
		S[backpack].Props.Name = "Backpack"
		setParent(backpack, player)
	end
	setParent(character, getService("Workspace"))
	player.Character = character
	getSignal(player, "CharacterAdded"):Fire(character)
	return character
end

function Sim.AddPlayer(name: string, userId: number)
	local players = getService("Players")
	local player = newInstance("Player")
	local st = S[player]
	st.Props.Name = name
	st.Props.DisplayName = name
	st.Props.UserId = userId
	st.Props.MembershipType = Enum.MembershipType.None
	local playerGui = newInstance("PlayerGui")
	S[playerGui].Props.Name = "PlayerGui"
	setParent(playerGui, player)
	local playerScripts = newInstance("PlayerScripts")
	S[playerScripts].Props.Name = "PlayerScripts"
	setParent(playerScripts, player)
	setParent(player, players)

	local context = newContext("Client", player)
	Sim.ClientContexts[player] = context

	getSignal(players, "PlayerAdded"):Fire(player)

	-- Scripts de cliente
	local clientCopy = I.Clone(Sim.ClientFolder)
	setParent(clientCopy, playerScripts)
	st.Props.PlayerScriptsFolder = clientCopy
	for _, d in descendants(clientCopy) do
		if S[d].Class == "LocalScript" then
			Sched.spawnIn(context, function()
				runScript(d)
			end)
		end
	end

	simTask.delay(0.2, function()
		Sim.SpawnCharacter(player)
	end)
	return player
end

function Sim.RemovePlayer(player)
	if S[player].Parent == nil then
		return
	end
	local players = getService("Players")
	getSignal(players, "PlayerRemoving"):Fire(player)
	local character = S[player].Props.Character
	if character then
		I.Destroy(character)
	end
	setParent(player, nil)
	for index, context in Contexts do
		if context.Player == player then
			context.Dead = true
			table.remove(Contexts, index)
			break
		end
	end
	Sim.ClientContexts[player] = nil
end

function Sim.Close()
	for _, fn in Sim.CloseCallbacks or {} do
		Sched.spawnIn(ServerContext, fn)
	end
end

function Sim.GetService(name)
	return getService(name)
end

function Sim.Fire(context, signal, ...)
	local args = table.pack(...)
	Sched.spawnIn(context, function()
		signal:Fire(table.unpack(args, 1, args.n))
	end)
end

function Sim.Children(obj)
	return S[obj].Children
end

function Sim.ClassOf(obj)
	return S[obj].Class
end

function Sim.SetProp(obj, prop, value)
	S[obj].Props[prop] = value
	fireChanged(obj, prop)
end

function Sim.IsDestroyed(obj)
	return S[obj].Destroyed
end

Sim.Descendants = descendants
Sim.FullName = fullName

return Sim
