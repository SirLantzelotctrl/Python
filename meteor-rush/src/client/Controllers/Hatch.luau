-- Animación de eclosión: el huevo tiembla, destello y aparece la criatura.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Models = require(Shared:WaitForChild("Models"))
local Critters = require(Shared:WaitForChild("Critters"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local Format = require(Shared:WaitForChild("Format"))

local Modules = script.Parent.Parent.Modules
local UI = require(Modules.UI)
local Sound = require(Modules.Sound)

local Hatch = {}

local overlay: Frame
local queue: { { Egg: number, Results: { any } } } = {}
local playing = false
local skip = false

local function frameModel(viewport: ViewportFrame, model: Model, height: number)
	local camera = viewport.CurrentCamera
	if camera then
		local distance = height * 2.4 + 2
		camera.CFrame = CFrame.lookAt(Vector3.new(height * 0.35, height * 0.75, -distance), Vector3.new(0, height * 0.5, 0))
	end
	model.Parent = viewport
end

local function showOne(egg: number, results: { any })
	overlay.Visible = true
	skip = false
	for _, child in overlay:GetChildren() do
		if child:IsA("Frame") and child.Name == "Cell" then
			child:Destroy()
		end
	end
	local count = #results
	local cells = {}
	for index, result in results do
		local cell = UI.New("Frame", {
			Name = "Cell",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(240, 330),
			Position = UDim2.new(0.5, (index - (count + 1) / 2) * 260, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Parent = overlay,
		})
		local viewport = UI.New("ViewportFrame", {
			Name = "Viewport",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(240, 240),
			Ambient = Color3.fromRGB(200, 200, 200),
			LightColor = Color3.fromRGB(255, 255, 255),
			LightDirection = Vector3.new(-1, -1, 1),
			Parent = cell,
		})
		local camera = Instance.new("Camera")
		camera.FieldOfView = 40
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		local eggModel = Models.BuildEgg(egg, 1)
		frameModel(viewport, eggModel, 3)
		local nameLabel = UI.Text({ Name = "Name", Text = "", Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 0, 240), StrokeThickness = 3, Parent = cell })
		local infoLabel = UI.Text({ Name = "Info", Text = "", Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 0, 276), Parent = cell })
		table.insert(cells, { Viewport = viewport, Egg = eggModel, Name = nameLabel, Info = infoLabel, Result = result })
	end

	-- Temblor del huevo
	local started = os.clock()
	while os.clock() - started < 1.3 and not skip do
		local t = os.clock() - started
		for _, cell in cells do
			local amplitude = math.rad(6 + t * 18)
			cell.Egg:PivotTo(CFrame.Angles(0, 0, math.sin(t * 28) * amplitude))
		end
		RunService.RenderStepped:Wait()
	end

	-- Revelación
	Sound.Play("Hatch", 0.7)
	local bestOrder = 0
	for _, cell in cells do
		cell.Egg:Destroy()
		local result = cell.Result
		local def = Critters.Get(result.Id)
		if def then
			local critter = Models.BuildCritter(def.Id, { Shiny = result.Shiny, NoEffects = true })
			frameModel(cell.Viewport, critter, (critter:GetAttribute("Height") :: number?) or 2)
			local rarity = Rarities.Get(def.Rarity)
			bestOrder = math.max(bestOrder, rarity.Order)
			cell.Name.Text = (if result.Shiny then "✨ " else "") .. def.Name
			cell.Name.TextColor3 = rarity.Color
			if result.Deleted then
				cell.Info.Text = "🗑️ auto-deleted"
				cell.Info.TextColor3 = Color3.fromRGB(200, 200, 210)
			else
				cell.Info.Text = ("%s  •  +%s dmg"):format(def.Rarity, Format.Percent(Critters.GetPower(def.Id, result.Shiny)))
				cell.Info.TextColor3 = rarity.Color
			end
			local scale = UI.New("UIScale", { Scale = 0.4, Parent = cell.Viewport })
			UI.Tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end
	local flash = UI.New("Frame", { BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = if bestOrder >= 5 then 0.1 else 0.5, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = overlay })
	UI.Tween(flash, 0.5, { BackgroundTransparency = 1 })
	local waited = 0
	while waited < 2.4 and not skip do
		waited += RunService.RenderStepped:Wait()
	end
	flash:Destroy()
	overlay.Visible = false
end

function Hatch.Play(egg: number, results: { any })
	table.insert(queue, { Egg = egg, Results = results })
	if playing then
		return
	end
	playing = true
	task.spawn(function()
		while #queue > 0 do
			local item = table.remove(queue, 1)
			local ok, err = pcall(showOne, item.Egg, item.Results)
			if not ok then
				warn("[Hatch] " .. tostring(err))
				overlay.Visible = false
			end
		end
		playing = false
	end)
end

function Hatch.Init()
	local _, root = UI.Screen("MeteorRushHatch", 20)
	overlay = UI.New("TextButton", {
		Name = "Overlay",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(10, 10, 25),
		BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = root,
	})
	;(overlay :: any).Activated:Connect(function()
		skip = true
	end)
end

return Hatch
