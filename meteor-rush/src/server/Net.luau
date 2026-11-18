-- Atajos para enviar mensajes a los clientes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local NotifyEvent = Remotes.Event("Notify")
local AnnounceEvent = Remotes.Event("Announce")
local EffectEvent = Remotes.Event("Effect")

local Net = {}

-- Kind: "Info" | "Success" | "Error" | "Warning" | "Cash"
function Net.Notify(player: Player, text: string, kind: string?)
	if player.Parent ~= Players then
		return
	end
	NotifyEvent:FireClient(player, { Text = text, Kind = kind or "Info" })
end

function Net.NotifyAll(text: string, kind: string?)
	NotifyEvent:FireAllClients({ Text = text, Kind = kind or "Info" })
end

function Net.Announce(text: string, color: Color3?, duration: number?)
	AnnounceEvent:FireAllClients({ Text = text, Color = color or Color3.fromRGB(255, 255, 255), Duration = duration or 4 })
end

function Net.AnnounceTo(player: Player, text: string, color: Color3?, duration: number?)
	if player.Parent ~= Players then
		return
	end
	AnnounceEvent:FireClient(player, { Text = text, Color = color or Color3.fromRGB(255, 255, 255), Duration = duration or 4 })
end

function Net.Effect(player: Player, name: string, payload: { [string]: any }?)
	if player.Parent ~= Players then
		return
	end
	EffectEvent:FireClient(player, name, payload or {})
end

function Net.EffectAll(name: string, payload: { [string]: any }?)
	EffectEvent:FireAllClients(name, payload or {})
end

return Net
