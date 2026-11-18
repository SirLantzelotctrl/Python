-- Inventario de criaturas: equipar, quitar, borrar, equipar las mejores y auto-borrado.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Critters = require(Shared:WaitForChild("Critters"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local Format = require(Shared:WaitForChild("Format"))
local Models = require(Shared:WaitForChild("Models"))

local Modules = script.Parent.Parent.Modules
local UI = require(Modules.UI)
local State = require(Modules.State)

local Notifications = require(script.Parent.Parent.Controllers.Notifications)

local CrittersWindow = {
	Title = "🐾 CRITTERS",
	Color = UI.Colors.Orange,
	Size = UDim2.fromOffset(780, 520),
}

local summary: TextLabel
local autoButton: TextButton
local autoLabel: TextLabel
local grid: ScrollingFrame
local cards: { [string]: Frame } = {}
local selected: string? = nil
local detailViewport: ViewportFrame
local detailName: TextLabel
local detailInfo: TextLabel
local equipButton: TextButton
local equipLabel: TextLabel
local deleteButton: TextButton
local previewKey = ""

local function act(name: string, payload: { [string]: any }?)
	local ok, message = State.Action(name, payload)
	if message then
		Notifications.Show(message, if ok then "Success" else "Error")
	end
	return ok
end

local function setPreview(critterId: string?, shiny: boolean)
	local key = tostring(critterId) .. tostring(shiny)
	if key == previewKey then
		return
	end
	previewKey = key
	for _, child in detailViewport:GetChildren() do
		if child:IsA("Model") then
			child:Destroy()
		end
	end
	if not critterId then
		return
	end
	local model = Models.BuildCritter(critterId, { Shiny = shiny, NoEffects = true })
	local height = (model:GetAttribute("Height") :: number?) or 2
	local camera = detailViewport.CurrentCamera
	if camera then
		camera.CFrame = CFrame.lookAt(Vector3.new(height * 0.4, height * 0.8, -height * 2.6 - 1.5), Vector3.new(0, height * 0.5, 0))
	end
	model.Parent = detailViewport
end

local function updateDetail(data: { [string]: any })
	local entry = selected and data.Critters and data.Critters[selected]
	if not entry then
		selected = nil
		detailName.Text = "Select a critter"
		detailName.TextColor3 = UI.Colors.Text
		detailInfo.Text = ""
		equipButton.Visible = false
		deleteButton.Visible = false
		setPreview(nil, false)
		return
	end
	local def = Critters.Get(entry.Id)
	if not def then
		return
	end
	local rarity = Rarities.Get(def.Rarity)
	detailName.Text = (if entry.Shiny then "✨ " else "") .. def.Name
	detailName.TextColor3 = rarity.Color
	detailInfo.Text = ("%s  •  +%s damage"):format(def.Rarity, Format.Percent(Critters.GetPower(def.Id, entry.Shiny)))
	local equipped = table.find(data.Equipped or {}, selected) ~= nil
	equipButton.Visible = true
	deleteButton.Visible = true
	equipLabel.Text = if equipped then "UNEQUIP" else "EQUIP"
	UI.SetButtonColor(equipButton, if equipped then UI.Colors.Gray else UI.Colors.Green)
	setPreview(entry.Id, entry.Shiny == true)
end

function CrittersWindow.Build(window)
	local content = window.Content
	summary = UI.Text({ Name = "Summary", Text = "", Size = UDim2.new(0.55, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Colors.Yellow, Parent = content })
	UI.Button({
		Name = "EquipBest",
		Text = "⭐ Equip Best",
		Color = UI.Colors.Green,
		Size = UDim2.fromOffset(160, 40),
		Position = UDim2.new(1, -170, 0, -4),
		AnchorPoint = Vector2.new(1, 0),
		OnClick = function()
			act("EquipBest")
		end,
		Parent = content,
	})
	autoButton, autoLabel = UI.Button({
		Name = "AutoDelete",
		Text = "",
		Color = UI.Colors.Gray,
		Size = UDim2.fromOffset(160, 40),
		Position = UDim2.new(1, 0, 0, -4),
		AnchorPoint = Vector2.new(1, 0),
		TextSizeScale = 0.55,
		OnClick = function()
			act("ToggleAutoDelete")
		end,
		Parent = content,
	})

	grid = UI.New("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 44),
		Size = UDim2.new(1, -250, 1, -44),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = content,
	})
	UI.Grid(UDim2.fromOffset(110, 110), 8).Parent = grid
	UI.Padding(4, 10, 8, 4).Parent = grid

	local detail = UI.Panel({ Name = "Detail", Color = UI.Colors.PanelDark, Size = UDim2.new(0, 238, 1, -44), Position = UDim2.new(1, 0, 0, 44), AnchorPoint = Vector2.new(1, 0), Parent = content })
	detailViewport = UI.New("ViewportFrame", {
		Name = "Preview",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -20, 0, 170),
		Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		Ambient = Color3.fromRGB(200, 200, 200),
		LightDirection = Vector3.new(-1, -1, 1),
		Parent = detail,
	})
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = detailViewport
	detailViewport.CurrentCamera = camera
	detailName = UI.Text({ Name = "Name", Text = "Select a critter", Size = UDim2.new(1, -16, 0, 32), Position = UDim2.new(0.5, 0, 0, 182), AnchorPoint = Vector2.new(0.5, 0), Parent = detail })
	detailInfo = UI.Text({ Name = "Info", Text = "", Size = UDim2.new(1, -16, 0, 24), Position = UDim2.new(0.5, 0, 0, 216), AnchorPoint = Vector2.new(0.5, 0), TextColor3 = UI.Colors.SubText, Parent = detail })
	equipButton, equipLabel = UI.Button({
		Name = "Equip",
		Text = "EQUIP",
		Color = UI.Colors.Green,
		Size = UDim2.new(1, -24, 0, 46),
		Position = UDim2.new(0.5, 0, 1, -64),
		AnchorPoint = Vector2.new(0.5, 1),
		OnClick = function()
			local data = State.Data
			if not data or not selected then
				return
			end
			if table.find(data.Equipped or {}, selected) then
				act("UnequipCritter", { Uid = selected })
			else
				act("EquipCritter", { Uid = selected })
			end
		end,
		Parent = detail,
	})
	deleteButton = UI.Button({
		Name = "Delete",
		Text = "🗑️ DELETE",
		Color = UI.Colors.Red,
		Size = UDim2.new(1, -24, 0, 42),
		Position = UDim2.new(0.5, 0, 1, -12),
		AnchorPoint = Vector2.new(0.5, 1),
		OnClick = function()
			if selected and act("DeleteCritter", { Uid = selected }) then
				selected = nil
			end
		end,
		Parent = detail,
	})
	equipButton.Visible = false
	deleteButton.Visible = false
end

function CrittersWindow.Refresh(data)
	local critters = data.Critters or {}
	local equipped = data.Equipped or {}
	local count = data.CritterCount or 0
	local bonus = 0
	for _, uid in equipped do
		local entry = critters[uid]
		if entry then
			bonus += Critters.GetPower(entry.Id, entry.Shiny)
		end
	end
	summary.Text = ("Equipped %d/%d  •  +%s dmg  •  %d/%d owned"):format(#equipped, data.SlotCount or 3, Format.Percent(bonus), count, data.InventoryLimit or 80)
	local auto = data.Settings and data.Settings.AutoDeleteCommon
	autoLabel.Text = if auto then "🗑️ Auto-delete Common: ON" else "Auto-delete Common: OFF"
	UI.SetButtonColor(autoButton, if auto then UI.Colors.Red else UI.Colors.Gray)

	-- Ordenadas: equipadas primero, después por poder
	local list = {}
	for uid, entry in critters do
		local def = Critters.Get(entry.Id)
		if def then
			table.insert(list, { Uid = uid, Entry = entry, Def = def, Power = Critters.GetPower(def.Id, entry.Shiny), Equipped = table.find(equipped, uid) ~= nil })
		end
	end
	table.sort(list, function(a, b)
		if a.Equipped ~= b.Equipped then
			return a.Equipped
		end
		if a.Power ~= b.Power then
			return a.Power > b.Power
		end
		return a.Uid < b.Uid
	end)

	local alive = {}
	for order, item in list do
		alive[item.Uid] = true
		local card = cards[item.Uid]
		local rarity = Rarities.Get(item.Def.Rarity)
		if not card then
			card = UI.Panel({ Name = item.Uid, Color = UI.Darken(rarity.Color, 0.55), Parent = grid })
			local button = UI.New("TextButton", { Name = "Select", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = card })
			local uid = item.Uid
			button.Activated:Connect(function()
				selected = uid
				if State.Data then
					updateDetail(State.Data)
				end
			end)
			UI.Text({ Name = "Icon", Text = "", Size = UDim2.new(1, 0, 0, 44), Position = UDim2.new(0, 0, 0, 6), StrokeThickness = 0, Parent = card })
			UI.Text({ Name = "CardName", Text = item.Def.Name, Size = UDim2.new(1, -8, 0, 22), Position = UDim2.new(0.5, 0, 0, 52), AnchorPoint = Vector2.new(0.5, 0), Parent = card })
			UI.Text({ Name = "Power", Text = "", Size = UDim2.new(1, -8, 0, 20), Position = UDim2.new(0.5, 0, 0, 78), AnchorPoint = Vector2.new(0.5, 0), TextColor3 = rarity.Color, Parent = card })
			cards[item.Uid] = card
		end
		card.LayoutOrder = order
		local icon = card:FindFirstChild("Icon") :: TextLabel
		icon.Text = (if item.Equipped then "✅" else "") .. (if item.Entry.Shiny then "✨" else "") .. "🐾"
		local power = card:FindFirstChild("Power") :: TextLabel
		power.Text = "+" .. Format.Percent(item.Power)
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if item.Uid == selected then UI.Colors.Yellow elseif item.Equipped then UI.Colors.Green else UI.Colors.Stroke
		end
	end
	for uid, card in cards do
		if not alive[uid] then
			card:Destroy()
			cards[uid] = nil
		end
	end
	updateDetail(data)
end

return CrittersWindow
