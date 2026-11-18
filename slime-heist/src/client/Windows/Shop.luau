-- Ventana de tienda (cash): bates y mejoras.

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
	Title = "🛒 SHOP",
	Color = UI.Colors.Green,
	Size = UDim2.fromOffset(700, 480),
}

type Row = { Button: TextButton, Label: TextLabel, Info: TextLabel? }

local tabs: { [string]: ScrollingFrame } = {}
local tabButtons: { [string]: TextButton } = {}
local batRows: { [string]: Row } = {}
local upgradeRows: { [string]: Row } = {}
local currentTab = "Bats"

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

local function row(parent: Instance, order: number, icon: string, title: string): (Frame, TextLabel)
	local frame = UI.Panel({ Name = "Row", Color = UI.Colors.PanelLight, Size = UDim2.new(1, 0, 0, 88), LayoutOrder = order, Parent = parent })
	local iconBox = UI.Panel({ Name = "Icon", Color = UI.Colors.PanelDark, Size = UDim2.fromOffset(68, 68), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = frame })
	UI.Text({ Text = icon, Size = UDim2.fromScale(0.75, 0.75), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), StrokeThickness = 0, Parent = iconBox })
	UI.Text({ Name = "Title", Text = title, Size = UDim2.new(1, -270, 0, 32), Position = UDim2.new(0, 90, 0, 10), TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
	local info = UI.Text({ Name = "Info", Text = "", Size = UDim2.new(1, -270, 0, 24), Position = UDim2.new(0, 90, 0, 48), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Colors.SubText, Parent = frame })
	return frame, info
end

function Shop.Build(window)
	local content = window.Content
	local tabBar = UI.New("Frame", { Name = "Tabs", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48), Parent = content })
	UI.List(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left).Parent = tabBar
	for index, def in { { "Bats", "🏏 Bats" }, { "Upgrades", "⬆️ Upgrades" } } do
		local button = UI.Button({
			Name = def[1],
			Text = def[2],
			Color = UI.Colors.Gray,
			Size = UDim2.fromOffset(170, 46),
			LayoutOrder = index,
			OnClick = function()
				setTab(def[1])
			end,
			Parent = tabBar,
		})
		tabButtons[def[1]] = button
	end

	-- Bates
	local batsFrame = scrolling(content, "Bats")
	tabs.Bats = batsFrame
	for index, bat in Gear.Bats do
		local frame, info = row(batsFrame, index, bat.Icon, bat.Name)
		info.Text = ("💥 Power %d  •  ⏱ %.2fs  •  📏 %d"):format(bat.Knockback, bat.Cooldown, bat.Range)
		local button, label = UI.Button({
			Name = "Action",
			Text = "",
			Size = UDim2.fromOffset(160, 54),
			Position = UDim2.new(1, -12, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			OnClick = function()
				local data = State.Data
				if not data then
					return
				end
				if bat.GamePass then
					if data.Passes and data.Passes[bat.GamePass] then
						local ok, message = State.Action("EquipBat", { Id = bat.Id })
						Notifications.Show(message or "", if ok then "Success" else "Error")
					else
						Purchase.PromptPass(bat.GamePass)
					end
					return
				end
				local ok, message
				if data.OwnedBats and data.OwnedBats[bat.Id] then
					ok, message = State.Action("EquipBat", { Id = bat.Id })
				else
					ok, message = State.Action("BuyBat", { Id = bat.Id })
				end
				if message then
					Notifications.Show(message, if ok then "Success" else "Error")
				end
			end,
			Parent = frame,
		})
		batRows[bat.Id] = { Button = button, Label = label, Info = info }
	end

	-- Mejoras
	local upgradesFrame = scrolling(content, "Upgrades")
	tabs.Upgrades = upgradesFrame
	for index, key in Gear.UpgradeOrder do
		local def = Gear.Upgrades[key]
		local frame, info = row(upgradesFrame, index, def.Icon, def.Name)
		info.Text = def.Description
		local button, label = UI.Button({
			Name = "Action",
			Text = "",
			Size = UDim2.fromOffset(160, 54),
			Position = UDim2.new(1, -12, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			OnClick = function()
				local ok, message = State.Action("BuyUpgrade", { Key = key })
				if message then
					Notifications.Show(message, if ok then "Success" else "Error")
				end
			end,
			Parent = frame,
		})
		upgradeRows[key] = { Button = button, Label = label, Info = info }
	end

	setTab(currentTab)
end

function Shop.Refresh(data)
	local cash = State.Cash()
	for _, bat in Gear.Bats do
		local refs = batRows[bat.Id]
		if refs then
			local owned = (data.OwnedBats and data.OwnedBats[bat.Id]) or (bat.GamePass ~= nil and data.Passes and data.Passes[bat.GamePass])
			local equipped = data.EquippedBat == bat.Id
			if equipped and owned then
				refs.Label.Text = "EQUIPPED"
				UI.SetButtonColor(refs.Button, UI.Colors.Gray)
			elseif owned then
				refs.Label.Text = "EQUIP"
				UI.SetButtonColor(refs.Button, UI.Colors.Blue)
			elseif bat.GamePass then
				local passDef = Products.GamePasses[bat.GamePass]
				refs.Label.Text = "R$ " .. (if passDef then tostring(passDef.PriceHint) else "?")
				UI.SetButtonColor(refs.Button, UI.Colors.Pink)
				Purchase.GetPrice("Pass", bat.GamePass, function(price)
					if not (data.Passes and data.Passes[bat.GamePass]) then
						refs.Label.Text = "R$ " .. price
					end
				end)
			elseif (data.Rebirths or 0) < bat.RebirthRequired then
				refs.Label.Text = "🔒 Rebirth " .. bat.RebirthRequired
				UI.SetButtonColor(refs.Button, UI.Colors.Gray)
			else
				refs.Label.Text = Format.Money(bat.Price)
				UI.SetButtonColor(refs.Button, if cash >= bat.Price then UI.Colors.Green else UI.Colors.Red)
			end
		end
	end
	for key, refs in upgradeRows do
		local def = Gear.Upgrades[key]
		local level = (data.Upgrades and data.Upgrades[key]) or 0
		if level >= def.MaxLevel then
			refs.Label.Text = "MAX"
			UI.SetButtonColor(refs.Button, UI.Colors.Gray)
		else
			local cost = Economy.GetUpgradeCost(key, level)
			refs.Label.Text = Format.Money(cost)
			UI.SetButtonColor(refs.Button, if cash >= cost then UI.Colors.Green else UI.Colors.Red)
		end
		if refs.Info then
			refs.Info.Text = ("%s  •  Lv %d/%d"):format(def.Description, level, def.MaxLevel)
		end
	end
end

function Shop.Tick()
	if State.Data then
		Shop.Refresh(State.Data)
	end
end

return Shop
