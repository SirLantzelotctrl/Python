-- Tienda (Stardust): picos y mejoras permanentes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gear = require(Shared:WaitForChild("Gear"))
local Economy = require(Shared:WaitForChild("Economy"))
local Format = require(Shared:WaitForChild("Format"))
local Products = require(Shared:WaitForChild("Products"))

local Modules = script.Parent.Parent.Modules
local UI = require(Modules.UI)
local State = require(Modules.State)
local Purchase = require(Modules.Purchase)

local Notifications = require(script.Parent.Parent.Controllers.Notifications)

local Shop = {
	Title = "⛏️ SHOP",
	Color = UI.Colors.Green,
	Size = UDim2.fromOffset(720, 490),
}

type Row = { Button: TextButton, Label: TextLabel, Info: TextLabel }

local tabs: { [string]: ScrollingFrame } = {}
local tabButtons: { [string]: TextButton } = {}
local pickRows: { [string]: Row } = {}
local upgradeRows: { [string]: Row } = {}
local currentTab = "Pickaxes"

local function scrolling(parent: Instance, name: string): ScrollingFrame
	local frame = UI.New("ScrollingFrame", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 58),
		Size = UDim2.new(1, 0, 1, -58),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = parent,
	})
	UI.List(Enum.FillDirection.Vertical, 10).Parent = frame
	UI.Padding(4, 12, 8, 4).Parent = frame
	return frame
end

local function setTab(name: string)
	currentTab = name
	for tabName, frame in tabs do
		frame.Visible = tabName == name
		UI.SetButtonColor(tabButtons[tabName], if tabName == name then UI.Colors.Blue else UI.Colors.Gray)
	end
end

local function row(parent: Instance, order: number, icon: string, title: string, onClick: () -> ()): Row
	local frame = UI.Panel({ Name = "Row", Color = UI.Colors.PanelLight, Size = UDim2.new(1, 0, 0, 86), LayoutOrder = order, Parent = parent })
	local iconBox = UI.Panel({ Name = "Icon", Color = UI.Colors.PanelDark, Size = UDim2.fromOffset(66, 66), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = frame })
	UI.Text({ Text = icon, Size = UDim2.fromScale(0.75, 0.75), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), StrokeThickness = 0, Parent = iconBox })
	UI.Text({ Name = "Title", Text = title, Size = UDim2.new(1, -280, 0, 32), Position = UDim2.new(0, 88, 0, 10), TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
	local info = UI.Text({ Name = "Info", Text = "", Size = UDim2.new(1, -280, 0, 24), Position = UDim2.new(0, 88, 0, 48), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Colors.SubText, Parent = frame })
	local button, label = UI.Button({ Name = "Action", Text = "", Size = UDim2.fromOffset(170, 54), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), OnClick = onClick, Parent = frame })
	return { Button = button, Label = label, Info = info }
end

local function act(name: string, payload: { [string]: any })
	local ok, message = State.Action(name, payload)
	if message then
		Notifications.Show(message, if ok then "Success" else "Error")
	end
end

function Shop.Build(window)
	local content = window.Content
	local tabBar = UI.New("Frame", { Name = "Tabs", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48), Parent = content })
	UI.List(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left).Parent = tabBar
	for index, def in { { "Pickaxes", "⛏️ Pickaxes" }, { "Upgrades", "⬆️ Upgrades" } } do
		tabButtons[def[1]] = UI.Button({
			Name = def[1],
			Text = def[2],
			Color = UI.Colors.Gray,
			Size = UDim2.fromOffset(180, 46),
			LayoutOrder = index,
			OnClick = function()
				setTab(def[1])
			end,
			Parent = tabBar,
		})
	end

	tabs.Pickaxes = scrolling(content, "Pickaxes")
	for index, pick in Gear.Pickaxes do
		pickRows[pick.Id] = row(tabs.Pickaxes, index, pick.Icon, pick.Name, function()
			local data = State.Data
			if not data then
				return
			end
			if pick.GamePass then
				if data.Passes and data.Passes[pick.GamePass] then
					act("EquipPickaxe", { Id = pick.Id })
				else
					Purchase.PromptPass(pick.GamePass)
				end
			elseif data.OwnedPickaxes and data.OwnedPickaxes[pick.Id] then
				act("EquipPickaxe", { Id = pick.Id })
			else
				act("BuyPickaxe", { Id = pick.Id })
			end
		end)
		pickRows[pick.Id].Info.Text = ("⚔️ %s damage  •  ⏱ %.2fs"):format(Format.Abbreviate(pick.Damage), pick.Cooldown)
	end

	tabs.Upgrades = scrolling(content, "Upgrades")
	for index, key in Gear.UpgradeOrder do
		local def = Gear.Upgrades[key]
		upgradeRows[key] = row(tabs.Upgrades, index, def.Icon, def.Name, function()
			act("BuyUpgrade", { Key = key })
		end)
	end
	setTab(currentTab)
end

function Shop.Refresh(data)
	local stardust = State.Stardust()
	local bestTier = 1
	for id in data.OwnedPickaxes or {} do
		local pick = Gear.GetPickaxe(id)
		if pick and not pick.GamePass then
			bestTier = math.max(bestTier, Gear.GetTier(id))
		end
	end
	for index, pick in Gear.Pickaxes do
		local refs = pickRows[pick.Id]
		if refs then
			local owned = if pick.GamePass then (data.Passes and data.Passes[pick.GamePass]) == true else (data.OwnedPickaxes and data.OwnedPickaxes[pick.Id]) == true
			if owned and data.ActivePickaxe == pick.Id then
				refs.Label.Text = "EQUIPPED"
				UI.SetButtonColor(refs.Button, UI.Colors.Gray)
			elseif owned then
				refs.Label.Text = "EQUIP"
				UI.SetButtonColor(refs.Button, UI.Colors.Blue)
			elseif pick.GamePass then
				local passDef = Products.GamePasses[pick.GamePass]
				refs.Label.Text = "R$ " .. (if passDef then passDef.PriceHint else "?")
				UI.SetButtonColor(refs.Button, UI.Colors.Pink)
				Purchase.GetPrice("Pass", pick.GamePass, function(price)
					refs.Label.Text = "R$ " .. price
				end)
			elseif index > bestTier + 1 then
				refs.Label.Text = "🔒 " .. Format.Abbreviate(pick.Price)
				UI.SetButtonColor(refs.Button, UI.Colors.Gray)
			else
				refs.Label.Text = Format.Abbreviate(pick.Price) .. " ⭐"
				UI.SetButtonColor(refs.Button, if stardust >= pick.Price then UI.Colors.Green else UI.Colors.Red)
			end
		end
	end
	for key, refs in upgradeRows do
		local def = Gear.Upgrades[key]
		local level = (data.Upgrades and data.Upgrades[key]) or 0
		refs.Info.Text = ("%s  •  Lv %d/%d"):format(def.Description, level, def.MaxLevel)
		if level >= def.MaxLevel then
			refs.Label.Text = "MAX"
			UI.SetButtonColor(refs.Button, UI.Colors.Gray)
		else
			local cost = Economy.GetUpgradeCost(key, level)
			refs.Label.Text = Format.Abbreviate(cost) .. " ⭐"
			UI.SetButtonColor(refs.Button, if stardust >= cost then UI.Colors.Green else UI.Colors.Red)
		end
	end
end

function Shop.Tick()
	if State.Data then
		Shop.Refresh(State.Data)
	end
end

return Shop
