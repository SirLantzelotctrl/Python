-- Tienda de Robux: Game Passes y Developer Products.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Products = require(Shared:WaitForChild("Products"))

local Modules = script.Parent.Parent.Modules
local UI = require(Modules.UI)
local Purchase = require(Modules.Purchase)

local Store = {
	Title = "💎 STORE",
	Color = UI.Colors.Pink,
	Size = UDim2.fromOffset(720, 500),
}

local passButtons: { [string]: { Button: TextButton, Label: TextLabel } } = {}

local function sectionTitle(parent: Instance, text: string, order: number)
	UI.Text({ Name = "Section", Text = text, Size = UDim2.new(1, -20, 0, 36), LayoutOrder = order, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Colors.Yellow, StrokeThickness = 3, Parent = parent })
end

local function card(parent: Instance, order: number, icon: string, name: string, description: string, color: Color3, onClick: () -> ()): (TextButton, TextLabel)
	local frame = UI.Panel({ Name = name, Color = UI.Colors.PanelLight, LayoutOrder = order, Parent = parent })
	UI.Gradient(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 200, 215)).Parent = frame
	UI.Text({ Name = "Icon", Text = icon, Size = UDim2.new(1, 0, 0, 52), Position = UDim2.new(0, 0, 0, 6), StrokeThickness = 0, Parent = frame })
	UI.Text({ Name = "Name", Text = name, Size = UDim2.new(1, -12, 0, 28), Position = UDim2.new(0.5, 0, 0, 60), AnchorPoint = Vector2.new(0.5, 0), Parent = frame })
	UI.Text({ Name = "Description", Text = description, Size = UDim2.new(1, -14, 0, 40), Position = UDim2.new(0.5, 0, 0, 90), AnchorPoint = Vector2.new(0.5, 0), TextWrapped = true, TextColor3 = UI.Colors.SubText, StrokeThickness = 1, Parent = frame })
	local button, label = UI.Button({
		Name = "Buy",
		Text = "R$ ...",
		Color = color,
		Size = UDim2.new(1, -20, 0, 42),
		Position = UDim2.new(0.5, 0, 1, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		OnClick = onClick,
		Parent = frame,
	})
	return button, label
end

local function grid(parent: Instance, order: number): Frame
	local frame = UI.New("Frame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = parent,
	})
	UI.Grid(UDim2.fromOffset(200, 196), 12).Parent = frame
	return frame
end

function Store.Build(window)
	local scroll = UI.New("ScrollingFrame", {
		Name = "Scroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = window.Content,
	})
	UI.List(Enum.FillDirection.Vertical, 10).Parent = scroll
	UI.Padding(4, 12, 10, 4).Parent = scroll

	sectionTitle(scroll, "🍀 BOOSTS & ITEMS", 1)
	local productGrid = grid(scroll, 2)
	for index, key in Products.ProductOrder do
		local def = Products.DevProducts[key]
		local _, label = card(productGrid, index, def.Icon, def.Name, def.Description, UI.Colors.Green, function()
			Purchase.PromptProduct(key)
		end)
		Purchase.GetPrice("Product", key, function(price)
			label.Text = "R$ " .. price
		end)
	end

	sectionTitle(scroll, "⭐ GAME PASSES (FOREVER)", 3)
	local passGrid = grid(scroll, 4)
	for index, key in Products.PassOrder do
		local def = Products.GamePasses[key]
		local button, label = card(passGrid, index, def.Icon, def.Name, def.Description, UI.Colors.Pink, function()
			Purchase.PromptPass(key)
		end)
		passButtons[key] = { Button = button, Label = label }
	end
end

function Store.Refresh(data)
	for key, refs in passButtons do
		if data.Passes and data.Passes[key] then
			refs.Label.Text = "✅ OWNED"
			UI.SetButtonColor(refs.Button, UI.Colors.Gray)
			refs.Button.Active = false
		else
			UI.SetButtonColor(refs.Button, UI.Colors.Pink)
			Purchase.GetPrice("Pass", key, function(price)
				if not (data.Passes and data.Passes[key]) then
					refs.Label.Text = "R$ " .. price
				end
			end)
		end
	end
end

return Store
