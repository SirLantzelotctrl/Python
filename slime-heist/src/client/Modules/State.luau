-- Estado del jugador en el cliente (recibido del servidor con el remote "Sync").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Signal = require(Shared:WaitForChild("Signal"))

local State = {}

State.Data = nil :: { [string]: any }?
State.Changed = Signal.new()

local actionRemote: RemoteFunction

function State.Init()
	actionRemote = Remotes.Function("Action")
	Remotes.Event("Sync").OnClientEvent:Connect(function(view)
		State.Data = view
		State.Changed:Fire(view)
	end)
	task.spawn(function()
		State.Action("RequestSync")
	end)
end

-- Llama a una acción del servidor. Devuelve ok, mensaje.
function State.Action(name: string, payload: { [string]: any }?): (boolean, string?)
	local ok, success, message = pcall(function()
		return actionRemote:InvokeServer(name, payload or {})
	end)
	if not ok then
		return false, "Connection error"
	end
	return success == true, message
end

-- Conecta una función y la llama ya si hay datos
function State.Observe(fn: (data: { [string]: any }) -> ())
	local connection = State.Changed:Connect(fn)
	if State.Data then
		task.spawn(fn, State.Data)
	end
	return connection
end

function State.Cash(): number
	local value = Players.LocalPlayer:GetAttribute("Cash")
	if typeof(value) == "number" then
		return value
	end
	return if State.Data then State.Data.Cash else 0
end

function State.Get(key: string): any
	return if State.Data then State.Data[key] else nil
end

return State
