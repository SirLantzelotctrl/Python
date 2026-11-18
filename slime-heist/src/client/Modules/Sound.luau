-- Sonidos locales (solo los oye este jugador).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Sound = {}

local cache: { [string]: Sound } = {}
local lastPlayed: { [string]: number } = {}

function Sound.Play(name: string, volume: number?)
	local id = Config.Sounds[name]
	if not id then
		return
	end
	local now = os.clock()
	if (lastPlayed[name] or 0) + 0.05 > now then
		return
	end
	lastPlayed[name] = now
	local sound = cache[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = id
		sound.Parent = SoundService
		cache[name] = sound
	end
	sound.Volume = volume or 0.5
	SoundService:PlayLocalSound(sound)
end

return Sound
