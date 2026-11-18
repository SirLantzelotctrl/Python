-- Criaturas: huevos (eclosión con suerte y shiny), inventario, equipar y borrar.
-- Las equipadas dan bonus de daño, ayudan a picar y siguen al jugador (las dibuja el cliente).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Critters = require(Shared.Critters)
local Rarities = require(Shared.Rarities)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)

local Registry = require(script.Parent.Parent.Registry)
local Actions = require(script.Parent.Parent.Actions)
local Net = require(script.Parent.Parent.Net)

local CritterService = {}

local rng = Random.new()
local hatchCooldown: { [Player]: number } = {}

local function count(tbl: { [any]: any }): number
	local n = 0
	for _ in tbl do
		n += 1
	end
	return n
end

local function critterName(id: string, shiny: boolean?): string
	local def = Critters.Get(id)
	return (if shiny then "✨Shiny " else "") .. (if def then def.Name else id)
end

-- Atributo que usan los clientes para dibujar las criaturas que te siguen
function CritterService.UpdateFollowers(player: Player)
	local data = Registry.DataService.Get(player)
	if not data then
		return
	end
	local parts = {}
	for _, uid in data.Equipped do
		local entry = data.Critters[uid]
		if entry then
			table.insert(parts, entry.Id .. ":" .. (if entry.Shiny then "1" else "0"))
		end
	end
	player:SetAttribute("Critters", table.concat(parts, ","))
end

function CritterService.GetEquippedBonus(player: Player): number
	local data = Registry.DataService.Get(player)
	if not data then
		return 0
	end
	local list = {}
	for _, uid in data.Equipped do
		local entry = data.Critters[uid]
		if entry then
			table.insert(list, entry)
		end
	end
	return Economy.GetCritterBonus(list)
end

local function changed(player: Player)
	CritterService.UpdateFollowers(player)
	Registry.StatsService.Invalidate(player)
	Registry.DataService.MarkDirty(player)
end

function CritterService.AddCritter(player: Player, critterId: string, shiny: boolean): string?
	local data = Registry.DataService.Get(player)
	if not data or not Critters.Exists(critterId) then
		return nil
	end
	local uid = "c" .. data.NextCritter
	data.NextCritter += 1
	data.Critters[uid] = { Id = critterId, Shiny = shiny }
	data.Index[critterId] = data.Index[critterId] or {}
	local variant = if shiny then "Shiny" else "Normal"
	if not data.Index[critterId][variant] then
		data.Index[critterId][variant] = true
		Net.Notify(player, "📖 New Index entry: " .. critterName(critterId, shiny) .. "!", "Success")
	end
	-- Equipa automáticamente si hay hueco libre
	if #data.Equipped < Registry.StatsService.GetSlotCount(player) then
		table.insert(data.Equipped, uid)
	end
	changed(player)
	return uid
end

-- Da una criatura de una rareza concreta (huevos de meteorito, cometa, códigos, productos)
function CritterService.GiveCritterOfRarity(player: Player, rarity: string, eggIndex: number?, shiny: boolean?, source: string?): string?
	local data = Registry.DataService.Get(player)
	if not data then
		return nil
	end
	local egg = math.clamp(eggIndex or data.Zone, 1, #Critters.Eggs)
	local critterId = Critters.OfRarity(egg, rarity) or Critters.OfRarity(egg, "Common")
	if not critterId then
		return nil
	end
	local isShiny = shiny == true or rng:NextNumber() < Config.Critters.ShinyChance
	if count(data.Critters) >= Config.Critters.InventoryLimit then
		local compensation = math.floor(Registry.StatsService.GetRewardBase(player) * 20)
		Registry.DataService.AddStardust(player, compensation)
		Net.Notify(player, ("🐾 Inventory full! Got %s ⭐ instead"):format(Format.Abbreviate(compensation)), "Warning")
		return nil
	end
	local uid = CritterService.AddCritter(player, critterId, isShiny)
	local rarityDef = Rarities.Get(rarity)
	local from = if source == "meteor" then " from a meteor egg" elseif source == "comet" then " from the comet" else ""
	Net.Notify(player, ("🥚 You got %s (%s)%s!"):format(critterName(critterId, isShiny), rarity, from), "Success")
	Net.Effect(player, "Hatch", { Egg = egg, Results = { { Id = critterId, Shiny = isShiny } } })
	if rarityDef.Order >= Config.Critters.AnnounceMinRarityOrder then
		Net.Announce(("🥚 %s got a %s %s!"):format(player.DisplayName, string.upper(rarity), critterName(critterId, isShiny)), rarityDef.Color, 4)
	end
	return uid
end

function CritterService.Hatch(player: Player, eggIndex: number, amount: number): (boolean, string?)
	local data = Registry.DataService.Get(player)
	local egg = Critters.GetEgg(eggIndex)
	if not data or not egg then
		return false, "Invalid egg"
	end
	if eggIndex > data.Zone then
		return false, "Unlock this zone first!"
	end
	if amount ~= 1 and amount ~= 3 then
		return false, "Invalid amount"
	end
	if amount == 3 and not Registry.MonetizationService.OwnsPass(player, "TripleHatch") then
		Net.Effect(player, "PromptPass", { Key = "TripleHatch" })
		return false, "Get Triple Hatch to open 3 at once!"
	end
	local t = os.clock()
	if (hatchCooldown[player] or 0) > t then
		return false, nil
	end
	hatchCooldown[player] = t + 1.2
	local space = Config.Critters.InventoryLimit - count(data.Critters)
	if space < amount and not data.Settings.AutoDeleteCommon then
		return false, "Your critter inventory is full! Delete some first."
	end
	local cost = egg.Cost * amount
	if not Registry.DataService.SpendStardust(player, cost) then
		return false, ("You need %s ⭐"):format(Format.Abbreviate(cost))
	end

	local luck = Registry.StatsService.GetHatchLuck(player)
	local results = {}
	for _ = 1, amount do
		local critterId = Critters.Roll(rng, eggIndex, luck)
		local shiny = rng:NextNumber() < Config.Critters.ShinyChance
		local def = Critters.Get(critterId)
		local deleted = false
		if data.Settings.AutoDeleteCommon and def and def.Rarity == "Common" and not shiny then
			deleted = true
			-- Aun así cuenta para el Index
			data.Index[critterId] = data.Index[critterId] or {}
			data.Index[critterId].Normal = true
		elseif count(data.Critters) < Config.Critters.InventoryLimit then
			CritterService.AddCritter(player, critterId, shiny)
		else
			deleted = true
		end
		table.insert(results, { Id = critterId, Shiny = shiny, Deleted = deleted })
		if def and Rarities.Get(def.Rarity).Order >= Config.Critters.AnnounceMinRarityOrder then
			Net.Announce(("🥚 %s hatched a %s %s!"):format(player.DisplayName, string.upper(def.Rarity), critterName(critterId, shiny)), Rarities.Get(def.Rarity).Color, 4)
		end
	end
	data.Stats.Hatched += amount
	Registry.QuestService.Progress(player, "HatchEggs", amount)
	Registry.DataService.MarkDirty(player)
	Net.Effect(player, "Hatch", { Egg = eggIndex, Results = results })
	return true, nil
end

function CritterService.Equip(player: Player, uid: string): (boolean, string?)
	local data = Registry.DataService.Get(player)
	if not data or not data.Critters[uid] then
		return false, "Critter not found"
	end
	if table.find(data.Equipped, uid) then
		return false, "Already equipped"
	end
	if #data.Equipped >= Registry.StatsService.GetSlotCount(player) then
		return false, "No free slots! Unequip one first."
	end
	table.insert(data.Equipped, uid)
	changed(player)
	return true, "Equipped " .. critterName(data.Critters[uid].Id, data.Critters[uid].Shiny)
end

function CritterService.Unequip(player: Player, uid: string): (boolean, string?)
	local data = Registry.DataService.Get(player)
	local index = data and table.find(data.Equipped, uid)
	if not data or not index then
		return false, "Not equipped"
	end
	table.remove(data.Equipped, index)
	changed(player)
	return true, nil
end

function CritterService.EquipBest(player: Player): (boolean, string?)
	local data = Registry.DataService.Get(player)
	if not data then
		return false, nil
	end
	local list = {}
	for uid, entry in data.Critters do
		table.insert(list, { Uid = uid, Power = Critters.GetPower(entry.Id, entry.Shiny) })
	end
	table.sort(list, function(a, b)
		if a.Power == b.Power then
			return a.Uid < b.Uid
		end
		return a.Power > b.Power
	end)
	local slots = Registry.StatsService.GetSlotCount(player)
	local equipped = {}
	for i = 1, math.min(slots, #list) do
		table.insert(equipped, list[i].Uid)
	end
	data.Equipped = equipped
	changed(player)
	return true, "Equipped your best critters!"
end

function CritterService.Delete(player: Player, uid: string): (boolean, string?)
	local data = Registry.DataService.Get(player)
	if not data or not data.Critters[uid] then
		return false, "Critter not found"
	end
	local index = table.find(data.Equipped, uid)
	if index then
		table.remove(data.Equipped, index)
	end
	data.Critters[uid] = nil
	changed(player)
	return true, nil
end

-- Borra todas las NO equipadas de una rareza (y no shiny)
function CritterService.DeleteRarity(player: Player, rarity: string): (boolean, string?)
	local data = Registry.DataService.Get(player)
	if not data or not Rarities.Exists(rarity) then
		return false, "Invalid rarity"
	end
	local removed = 0
	for uid, entry in data.Critters do
		local def = Critters.Get(entry.Id)
		if def and def.Rarity == rarity and not entry.Shiny and not table.find(data.Equipped, uid) then
			data.Critters[uid] = nil
			removed += 1
		end
	end
	changed(player)
	return true, ("Deleted %d %s critters"):format(removed, rarity)
end

function CritterService.FillView(player: Player, view: { [string]: any })
	local data = Registry.DataService.Get(player)
	if not data then
		return
	end
	view.IndexCount = Economy.CountIndex(data.Index)
	view.IndexTotal = Economy.GetIndexTotal()
	view.CritterCount = count(data.Critters)
end

function CritterService.Init()
	Actions.Register("Hatch", function(player, payload)
		return CritterService.Hatch(player, tonumber(payload.Egg) or 0, tonumber(payload.Amount) or 1)
	end)
	Actions.Register("EquipCritter", function(player, payload)
		return CritterService.Equip(player, tostring(payload.Uid))
	end)
	Actions.Register("UnequipCritter", function(player, payload)
		return CritterService.Unequip(player, tostring(payload.Uid))
	end)
	Actions.Register("EquipBest", function(player)
		return CritterService.EquipBest(player)
	end)
	Actions.Register("DeleteCritter", function(player, payload)
		return CritterService.Delete(player, tostring(payload.Uid))
	end)
	Actions.Register("DeleteRarity", function(player, payload)
		return CritterService.DeleteRarity(player, tostring(payload.Rarity))
	end)
	Actions.Register("ToggleAutoDelete", function(player)
		local data = Registry.DataService.Get(player)
		if not data then
			return false, nil
		end
		data.Settings.AutoDeleteCommon = not data.Settings.AutoDeleteCommon
		Registry.DataService.MarkDirty(player)
		return true, if data.Settings.AutoDeleteCommon then "Auto-delete Commons: ON" else "Auto-delete Commons: OFF"
	end)
end

function CritterService.Start()
	-- Prompts en los soportes de huevos
	for eggIndex, stand in Registry.MapService.EggStands do
		local egg = Critters.GetEgg(eggIndex)
		if egg then
			for _, amount in { 1, 3 } do
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "Hatch" .. amount
				prompt.ActionText = if amount == 1 then "Hatch (" .. Format.Abbreviate(egg.Cost) .. " ⭐)" else "Hatch x3 (" .. Format.Abbreviate(egg.Cost * 3) .. " ⭐)"
				prompt.ObjectText = egg.Name
				prompt.KeyboardKeyCode = if amount == 1 then Enum.KeyCode.E else Enum.KeyCode.R
				prompt.HoldDuration = 0.25
				prompt.MaxActivationDistance = 12
				prompt.RequiresLineOfSight = false
				prompt.UIOffset = Vector2.new(0, if amount == 1 then 0 else 80)
				prompt.Parent = stand
				prompt.Triggered:Connect(function(player)
					local ok, message = CritterService.Hatch(player, eggIndex, amount)
					if not ok and message then
						Net.Notify(player, message, "Error")
					end
				end)
			end
			-- Cartel con las probabilidades
			local gui = Instance.new("BillboardGui")
			gui.Name = "Chances"
			gui.Size = UDim2.new(10, 0, 8, 0)
			gui.StudsOffsetWorldSpace = Vector3.new(0, 11, 0)
			gui.LightInfluence = 0
			gui.MaxDistance = 60
			local layout = Instance.new("UIListLayout")
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = gui
			local lines = { { egg.Name .. " • " .. Format.Abbreviate(egg.Cost) .. " ⭐", Color3.fromRGB(255, 255, 255) } }
			for _, def in Critters.ByEgg[eggIndex] or {} do
				local chance = Critters.RarityChances[def.Rarity] * 100
				table.insert(lines, { ("%s  %s%%  (+%s)"):format(def.Name, if chance < 1 then string.format("%.1f", chance) else tostring(math.floor(chance)), Format.Percent(def.Power)), Rarities.Get(def.Rarity).Color })
			end
			for order, line in lines do
				local labelInstance = Instance.new("TextLabel")
				labelInstance.BackgroundTransparency = 1
				labelInstance.Size = UDim2.fromScale(1, 1 / #lines)
				labelInstance.Font = Enum.Font.FredokaOne
				labelInstance.TextScaled = true
				labelInstance.Text = line[1]
				labelInstance.TextColor3 = line[2]
				labelInstance.LayoutOrder = order
				local stroke = Instance.new("UIStroke")
				stroke.Thickness = 2
				stroke.Parent = labelInstance
				labelInstance.Parent = gui
			end
			gui.Parent = stand
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		hatchCooldown[player] = nil
	end)
end

return CritterService
