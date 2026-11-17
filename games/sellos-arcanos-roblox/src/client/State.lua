-- Estado del cliente y controles: perfil, equipo, objetivo y teclas/botones.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local State = {}
local player = Players.LocalPlayer

State.profile = nil
State.team = nil
State.sealing = false
State.lockedTarget = nil
State.onSeal = nil

function State.today()
	return os.date("!%Y-%m-%d")
end

local function creaturesFolder()
	return Workspace:FindFirstChild("Criaturas")
end

local function myRoot()
	local ch = player.Character
	return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function modelPos(m)
	local ok, cf = pcall(function()
		return m:GetPivot()
	end)
	return ok and cf.Position or nil
end
State.modelPos = modelPos

local function isFoe(m)
	local kind = m:GetAttribute("Kind")
	return (kind == "wild" or kind == "boss" or kind == "anchor") and m:GetAttribute("Island") == player:GetAttribute("Island")
end

local function foes()
	local list = {}
	local f = creaturesFolder()
	if not f then
		return list
	end
	for _, m in ipairs(f:GetChildren()) do
		if isFoe(m) then
			table.insert(list, m)
		end
	end
	return list
end
State.foes = foes

function State.targetModel()
	local root = myRoot()
	if not root then
		return nil
	end
	local t = State.lockedTarget
	if t and t.Parent and isFoe(t) then
		local p = modelPos(t)
		if p and (p - root.Position).Magnitude < 110 then
			return t
		end
	end
	State.lockedTarget = nil
	local best, bd = nil, 70
	for _, m in ipairs(foes()) do
		local p = modelPos(m)
		if p then
			local d = (p - root.Position).Magnitude
			if d < bd then
				best, bd = m, d
			end
		end
	end
	return best
end

function State.sealableModel()
	local root = myRoot()
	if not root then
		return nil
	end
	local best, bd = nil, 90
	for _, m in ipairs(foes()) do
		if m:GetAttribute("Sealable") and not m:GetAttribute("Invuln") then
			local p = modelPos(m)
			if p then
				local d = (p - root.Position).Magnitude
				if d < bd then
					best, bd = m, d
				end
			end
		end
	end
	return best
end

function State.cycleTarget()
	local list = foes()
	if #list == 0 then
		return
	end
	local idx = table.find(list, State.lockedTarget) or 0
	State.lockedTarget = list[(idx % #list) + 1]
end

function State.switch(i)
	Net.get("Switch"):FireServer(i)
end

function State.press(key)
	if State.sealing then
		return
	end
	if key == "seal" then
		local m = State.sealableModel()
		if m and State.onSeal then
			State.onSeal(m)
		end
		return
	end
	if key == "target" then
		State.cycleTarget()
		return
	end
	if key == "dodge" then
		local ch = player.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		local dir = hum and hum.MoveDirection or Vector3.zero
		if dir.Magnitude < 0.1 then
			local cam = Workspace.CurrentCamera
			dir = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
		end
		Net.get("Dodge"):FireServer(Vector3.new(dir.X, 0, dir.Z))
		return
	end
	local m = State.targetModel()
	Net.get("Cast"):FireServer(key, m and m:GetAttribute("EntityId") or "")
	if m and not State.lockedTarget then
		State.lockedTarget = m
	end
end

-- --- controles ---------------------------------------------------------------------
local BINDS = {
	{ "SA_Q", "q", { Enum.KeyCode.Q, Enum.KeyCode.ButtonX } },
	{ "SA_E", "e", { Enum.KeyCode.E, Enum.KeyCode.ButtonY } },
	{ "SA_R", "r", { Enum.KeyCode.R, Enum.KeyCode.ButtonB } },
	{ "SA_F", "f", { Enum.KeyCode.F, Enum.KeyCode.ButtonR1 } },
	{ "SA_Dodge", "dodge", { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL1 } },
	{ "SA_Seal", "seal", { Enum.KeyCode.G, Enum.KeyCode.ButtonR2 } },
	{ "SA_Target", "target", { Enum.KeyCode.Tab, Enum.KeyCode.ButtonL2 } },
	{ "SA_Sw1", "sw1", { Enum.KeyCode.One, Enum.KeyCode.DPadLeft } },
	{ "SA_Sw2", "sw2", { Enum.KeyCode.Two, Enum.KeyCode.DPadUp } },
	{ "SA_Sw3", "sw3", { Enum.KeyCode.Three, Enum.KeyCode.DPadRight } },
}

function State.bindControls()
	for _, b in ipairs(BINDS) do
		local action = b[2]
		ContextActionService:BindAction(b[1], function(_, inputState)
			if inputState ~= Enum.UserInputState.Begin then
				return Enum.ContextActionResult.Pass
			end
			if UserInputService:GetFocusedTextBox() then
				return Enum.ContextActionResult.Pass
			end
			if string.sub(action, 1, 2) == "sw" then
				State.switch(tonumber(string.sub(action, 3)))
			else
				State.press(action)
			end
			-- dejamos pasar la tecla para no bloquear los avisos de interacción (E)
			return Enum.ContextActionResult.Pass
		end, false, table.unpack(b[3]))
	end
	-- clic en un enemigo para fijarlo
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local cam = Workspace.CurrentCamera
			local ray = cam:ScreenPointToRay(input.Position.X, input.Position.Y)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			local f = creaturesFolder()
			if not f then
				return
			end
			params.FilterDescendantsInstances = { f }
			local hit = Workspace:Raycast(ray.Origin, ray.Direction * 400, params)
			if hit and hit.Instance then
				local m = hit.Instance:FindFirstAncestorOfClass("Model")
				while m and m.Parent ~= f do
					m = m:FindFirstAncestorOfClass("Model")
				end
				if m and isFoe(m) then
					State.lockedTarget = m
				end
			end
		end
	end)
end

function State.init()
	Net.get("ProfileSync").OnClientEvent:Connect(function(p)
		State.profile = p
		if State.onProfile then
			State.onProfile(p)
		end
	end)
	local function readTeam()
		local json = player:GetAttribute("TeamState")
		if json then
			local ok, data = pcall(function()
				return HttpService:JSONDecode(json)
			end)
			if ok then
				State.team = data
			end
		end
	end
	player:GetAttributeChangedSignal("TeamState"):Connect(readTeam)
	readTeam()
end

return State
