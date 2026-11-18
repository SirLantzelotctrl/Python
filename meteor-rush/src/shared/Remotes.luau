-- Crea (servidor) u obtiene (cliente) todos los RemoteEvents/RemoteFunctions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"Notify", -- S->C  { Text, Kind }
	"Announce", -- S->C  { Text, Color, Duration }
	"Sync", -- S->C  vista de datos del jugador
	"Effect", -- S->C  (name, payload)
	"Knockback", -- S->C  (velocity: Vector3)
}

local FUNCTIONS = {
	"Action", -- C->S  (actionName, payload) -> (ok, message)
}

local Remotes = {}

local folder: Folder

if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		folder = existing :: Folder
	else
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		for _, name in EVENTS do
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		for _, name in FUNCTIONS do
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.Event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.Function(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
