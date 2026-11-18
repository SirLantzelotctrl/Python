-- Index: todas las criaturas por huevo (normal y shiny). Las no descubiertas, en silueta.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Critters = require(Shared:WaitForChild("Critters"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local Models = require(Shared:WaitForChild("Models"))

local Modules = script.Parent.Parent.Modules
local UI = require(Modules.UI)
local State = require(Modules.State)

local Index = {
	Title = "📖 CRITTER INDEX",
	Color = UI.Colors.Purple,
	Size = UDim2.fromOffset(780, 520),
}

type Cell = { Frame: Frame, Viewport: ViewportFrame, Name: TextLabel, Key: string? }

local summary: TextLabel
local cells: { Cell } = {}
local eggButtons: { TextButton } = {}
local currentEgg = 1

local function setModel(cell: Cell, critterId: string, shiny: boolean, discovered: boolean)
	local key = critterId .. tostring(shiny) .. tostring(discovered)
	if cell.Key == key then
		return
	end
	cell.Key = key
	for _, child in cell.Viewport:GetChildren() do
		if child:IsA("Model") then
			child:Destroy()
		end
	end
	local model = Models.BuildCritter(critterId, { Shiny = shiny, NoEffects = true, Silhouette = not discovered })
	local height = (model:GetAttribute("Height") :: number?) or 2
	local camera = cell.Viewport.CurrentCamera
	if camera then
		camera.CFrame = CFrame.lookAt(Vector3.new(height * 0.4, height * 0.8, -height * 2.6 - 1.5), Vector3.new(0, height * 0.5, 0))
	end
	model.Parent = cell.Viewport
end

local function setEgg(index: number)
	currentEgg = index
	for i, button in eggButtons do
		UI.SetButtonColor(button, if i == index then UI.Colors.Purple else UI.Colors.Gray)
	end
	if State.Data then
		Index.Refresh(State.Data)
	end
end

function Index.Build(window)
	local content = window.Content
	summary = UI.Text({ Name = "Summary", Text = "", Size = UDim2.new(1, 0, 0, 28), TextColor3 = UI.Colors.Yellow, Parent = content })
	local tabs = UI.New("Frame", { Name = "Eggs", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, 32), Parent = content })
	UI.List(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center).Parent = tabs
	for i, egg in Critters.Eggs do
		eggButtons[i] = UI.Button({
			Name = "Egg" .. i,
			Text = string.gsub(egg.Name, " Egg", ""),
			Color = UI.Colors.Gray,
			Size = UDim2.fromOffset(112, 38),
			LayoutOrder = i,
			OnClick = function()
				setEgg(i)
			end,
			Parent = tabs,
		})
	end
	local grid = UI.New("Frame", { Name = "Grid", BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 80), Size = UDim2.new(1, 0, 1, -80), Parent = content })
	UI.Grid(UDim2.fromOffset(118, 168), 8).Parent = grid
	for slot = 1, 12 do
		local frame = UI.Panel({ Name = "Cell" .. slot, Color = UI.Colors.PanelLight, LayoutOrder = slot, Parent = grid })
		local viewport = UI.New("ViewportFrame", {
			Name = "Viewport",
			BackgroundColor3 = UI.Colors.PanelDark,
			Size = UDim2.new(1, -10, 0, 112),
			Position = UDim2.new(0.5, 0, 0, 5),
			AnchorPoint = Vector2.new(0.5, 0),
			Ambient = Color3.fromRGB(200, 200, 200),
			LightDirection = Vector3.new(-1, -1, 1),
			Parent = frame,
		}, { UI.Corner(10) })
		local camera = Instance.new("Camera")
		camera.FieldOfView = 40
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		local name = UI.Text({ Name = "CritterName", Text = "", Size = UDim2.new(1, -8, 0, 22), Position = UDim2.new(0.5, 0, 0, 120), AnchorPoint = Vector2.new(0.5, 0), Parent = frame })
		cells[slot] = { Frame = frame, Viewport = viewport, Name = name, Key = nil }
	end
	setEgg(1)
end

function Index.Refresh(data)
	local index = data.Index or {}
	summary.Text = ("Discovered %d/%d (normal + ✨shiny)"):format(data.IndexCount or 0, data.IndexTotal or Critters.Count() * 2)
	local list = Critters.ByEgg[currentEgg] or {}
	for slot, cell in cells do
		local def = list[((slot - 1) % #list) + 1]
		local shiny = slot > #list
		if def then
			local variant = if shiny then "Shiny" else "Normal"
			local discovered = index[def.Id] ~= nil and index[def.Id][variant] == true
			setModel(cell, def.Id, shiny, discovered)
			cell.Name.Text = if discovered then (if shiny then "✨" else "") .. def.Name else "???"
			cell.Name.TextColor3 = if discovered then Rarities.Get(def.Rarity).Color else UI.Colors.SubText
		end
	end
end

return Index
