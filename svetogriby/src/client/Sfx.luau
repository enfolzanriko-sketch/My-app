--!nonstrict
-- Звуки. ID задаются в Shared/Config.luau → Config.SOUNDS
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Sfx = {}
local cache = {}

function Sfx.play(name: string, volume: number?)
	local id = Config.SOUNDS[name]
	if not id or id == 0 then
		return
	end
	local s = cache[name]
	if not s then
		s = Instance.new("Sound")
		s.Name = "Sfx_" .. name
		s.SoundId = "rbxassetid://" .. tostring(id)
		s.Volume = volume or 0.6
		s.Parent = SoundService
		cache[name] = s
	end
	SoundService:PlayLocalSound(s)
end

function Sfx.startMusic()
	local id = Config.SOUNDS.music
	if not id or id == 0 then
		return
	end
	local s = Instance.new("Sound")
	s.Name = "Music"
	s.SoundId = "rbxassetid://" .. tostring(id)
	s.Looped = true
	s.Volume = 0.25
	s.Parent = SoundService
	s:Play()
end

return Sfx
