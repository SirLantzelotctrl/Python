-- Sellos Arcanos · arranque del cliente
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameData = require(Shared.GameData)
local Net = require(Shared.Net)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Hud = require(script.Parent.Hud)
local Fx = require(script.Parent.Fx)
local Sealing = require(script.Parent.Sealing)
local Menus = require(script.Parent.Menus)

local player = Players.LocalPlayer

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

State.init()
State.bindControls()
Hud.init()
Fx.init()
Sealing.init()
Menus.init()

local starterShown = false
State.onProfile = function(p)
	Fx.refreshPortals(p)
	Fx.volume = p.settings and p.settings.sfx or 0.8
	if not p.starterChosen and not starterShown then
		starterShown = true
		task.delay(1, Menus.starter)
	end
	Menus.refresh()
end

Net.get("Toast").OnClientEvent:Connect(function(key, vars, kind)
	vars = vars or {}
	if vars.id and GameData.CreatureById[vars.id] then
		vars.name = UI.L(GameData.CreatureById[vars.id].name)
	end
	if vars.isle and GameData.Islands[vars.isle] then
		vars.isle = UI.L(GameData.Islands[vars.isle].name)
	end
	if key == "contractDone" then
		Fx.sound("ping", 1.5, 0.4)
	end
	UI.toast(UI.t(key, vars), kind)
end)

Net.get("Banner").OnClientEvent:Connect(function(key, vars, kind)
	vars = vars or {}
	if key == "islandEnter" then
		local isl = GameData.Islands[vars.i]
		UI.banner(UI.L(isl.name), "island", UI.t("islandLevels", { n = vars.i, a = isl.levels[1], b = isl.levels[2] }), 2.6)
	elseif key == "bossAppears" then
		local c = GameData.CreatureById[vars.id]
		UI.banner(UI.L(c.name), "boss", UI.t("form3"), 3)
	elseif key == "ult" then
		local c = GameData.CreatureById[vars.id]
		UI.banner(UI.L(c.abilityByKey.f.name), "ult", UI.t("ultimateTag"), 1.4)
	else
		UI.banner(UI.t(key, vars), kind, nil, 2.2)
	end
end)

Net.get("Reward").OnClientEvent:Connect(function(r)
	if r.sealed then
		local c = GameData.CreatureById[r.sealed]
		UI.banner(r.perfect and UI.t("perfect") or UI.t("sealed"), "seal", UI.L(c.name), 2.4)
		UI.toast(r.isNew and UI.t("newCreature", { name = UI.L(c.name) }) or UI.t("dupCreature", { name = UI.L(c.name) }), "gold")
		if r.unlocked then
			UI.toast(UI.t("islandUnlocked", { isle = UI.L(GameData.Islands[r.unlocked].name) }), "gold")
		end
		if r.crystals then
			UI.toast(UI.t("firstClear", { c = r.crystals }), "gold")
		end
	end
	if r.essence then
		UI.toast(UI.t("rewardLine", { e = r.essence, x = r.xp or 0 }), "good")
	end
end)

player:SetAttribute("ClientReady", true)

-- pide el perfil (el primer envío del servidor puede llegar antes de escuchar)
task.spawn(function()
	for _ = 1, 10 do
		if State.profile then
			return
		end
		pcall(function()
			Net.get("Action"):InvokeServer("sync")
		end)
		task.wait(2)
	end
end)
