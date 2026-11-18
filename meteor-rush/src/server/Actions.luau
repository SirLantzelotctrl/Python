-- Router de acciones del cliente (un único RemoteFunction "Action").
-- Cada servicio registra sus acciones con Actions.Register(nombre, handler).
-- Incluye límite de peticiones por jugador (anti-spam / anti-exploit).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Actions = {}

type Handler = (player: Player, payload: any) -> (boolean?, string?)

local handlers: { [string]: Handler } = {}
local buckets: { [Player]: { Tokens: number, Last: number } } = {}

local MAX_TOKENS = 12
local REFILL_PER_SECOND = 8

function Actions.Register(name: string, handler: Handler)
	assert(handlers[name] == nil, "Acción duplicada: " .. name)
	handlers[name] = handler
end

local function allow(player: Player): boolean
	local now = os.clock()
	local bucket = buckets[player]
	if not bucket then
		bucket = { Tokens = MAX_TOKENS, Last = now }
		buckets[player] = bucket
	end
	bucket.Tokens = math.min(MAX_TOKENS, bucket.Tokens + (now - bucket.Last) * REFILL_PER_SECOND)
	bucket.Last = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

function Actions.Start()
	local remote = Remotes.Function("Action")
	remote.OnServerInvoke = function(player: Player, actionName: any, payload: any)
		if typeof(actionName) ~= "string" then
			return false, "Invalid action"
		end
		local handler = handlers[actionName]
		if not handler then
			return false, "Unknown action"
		end
		if not allow(player) then
			return false, "Slow down!"
		end
		if payload ~= nil and typeof(payload) ~= "table" then
			payload = nil
		end
		local ok, success, message = pcall(handler, player, payload or {})
		if not ok then
			warn(("[Actions] Error en '%s': %s"):format(actionName, tostring(success)))
			return false, "Something went wrong"
		end
		return success == true, message
	end

	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return Actions
