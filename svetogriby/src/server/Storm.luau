--!nonstrict
-- «Кристальная гроза»: событие на весь сервер. Грибы могут стать грозовыми (x3 цена).
-- Для теста в Studio (вид Server в командной строке):
--   game.ReplicatedStorage:SetAttribute("ForceStorm", true)
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Remotes)
local Farm = require(script.Parent.Farm)

local Storm = {}
local rng = Random.new()

function Storm.run()
	local ends = workspace:GetServerTimeNow() + Config.STORM_DURATION
	ReplicatedStorage:SetAttribute("StormEnds", ends)
	ReplicatedStorage:SetAttribute("Storm", true)
	while workspace:GetServerTimeNow() < ends do
		task.wait(Config.STORM_TICK)
		Farm.forEachPlanted(function(bed, player, index)
			if bed:GetAttribute("Mutation") == "none" and rng:NextNumber() < Config.STORM_MUTATION_CHANCE then
				Farm.setMutation(player, bed, index, "storm")
				Remotes.Effect:FireAllClients("mutate", bed)
				Remotes.Notify:FireClient(player, "⚡ Гроза превратила гриб в грозовой! (x3 цена)", "rare")
			end
		end)
	end
	ReplicatedStorage:SetAttribute("Storm", false)
end

function Storm.init()
	ReplicatedStorage:SetAttribute("Storm", false)
	ReplicatedStorage:SetAttribute("StormEnds", 0)
	ReplicatedStorage:SetAttribute("ForceStorm", false)
	task.spawn(function()
		local first = true
		while true do
			local waitTime = rng:NextInteger(Config.STORM_INTERVAL_MIN, Config.STORM_INTERVAL_MAX)
			if first and RunService:IsStudio() then
				waitTime = Config.STUDIO_FIRST_STORM
			end
			first = false
			local start = os.clock()
			while os.clock() - start < waitTime and not ReplicatedStorage:GetAttribute("ForceStorm") do
				task.wait(1)
			end
			ReplicatedStorage:SetAttribute("ForceStorm", false)
			Storm.run()
		end
	end)
end

return Storm
