-- Eventos remotos con nombre. El servidor los crea; el cliente los espera.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local EVENTS = {
	"ProfileSync", -- S→C perfil del jugador
	"Toast", -- S→C aviso {key, vars, kind}
	"Banner", -- S→C texto grande {key, vars, kind}
	"Fx", -- S→C efectos visuales
	"Reward", -- S→C resumen de recompensas
	"Cast", -- C→S usar habilidad {key, targetId}
	"Switch", -- C→S cambiar de criatura {slot}
	"Dodge", -- C→S esquivar {dir}
	"SealResult", -- C→S resultado del minijuego
	"ChooseStarter", -- C→S elegir la primera criatura
}
local FUNCTIONS = {
	"SealRequest", -- C→S pide sellar a un enemigo → parámetros de la runa
	"Action", -- C→S acciones de menú (entrenar, evolucionar, comprar...)
}

local folder

local function getFolder()
	if folder then
		return folder
	end
	if RunService:IsServer() then
		folder = ReplicatedStorage:FindFirstChild("Remotes")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "Remotes"
			folder.Parent = ReplicatedStorage
		end
		for _, n in ipairs(EVENTS) do
			if not folder:FindFirstChild(n) then
				local e = Instance.new("RemoteEvent")
				e.Name = n
				e.Parent = folder
			end
		end
		for _, n in ipairs(FUNCTIONS) do
			if not folder:FindFirstChild(n) then
				local f = Instance.new("RemoteFunction")
				f.Name = n
				f.Parent = folder
			end
		end
	else
		folder = ReplicatedStorage:WaitForChild("Remotes")
	end
	return folder
end

function Net.get(name)
	local f = getFolder()
	if RunService:IsServer() then
		return f:FindFirstChild(name)
	end
	return f:WaitForChild(name)
end

function Net.init()
	getFolder()
end

return Net
