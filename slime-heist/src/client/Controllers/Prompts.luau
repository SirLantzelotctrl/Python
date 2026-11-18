-- Muestra a cada jugador solo los prompts que le tocan:
-- el dueño ve "Sell", los demás ven "Steal".

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Prompts = {}

local player = Players.LocalPlayer

local function apply(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local role = prompt:GetAttribute("Role")
	local ownerId = prompt:GetAttribute("OwnerUserId")
	local isOwner = ownerId == player.UserId
	if role == "Owner" then
		prompt.Enabled = isOwner
	elseif role == "Thief" then
		prompt.Enabled = not isOwner
	end
end

function Prompts.Init()
	CollectionService:GetInstanceAddedSignal("RolePrompt"):Connect(apply)
	for _, prompt in CollectionService:GetTagged("RolePrompt") do
		apply(prompt)
	end
end

return Prompts
