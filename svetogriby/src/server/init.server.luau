--!nonstrict
-- Точка входа сервера «Светогрибов».
local Players = game:GetService("Players")

local Remotes = require(script.Remotes)
local Map = require(script.Map)
local PlayerData = require(script.PlayerData)
local Farm = require(script.Farm)
local Shop = require(script.Shop)
local Storm = require(script.Storm)

local map = Map.build()
Farm.init(map)
Shop.init(map)
Storm.init()

-- Все действия клиента проходят через одну функцию (с защитой от спама)
local lastCall = {}
Remotes.Action.OnServerInvoke = function(player, action, ...)
	if type(action) ~= "string" then
		return nil
	end
	local handler = Remotes.handlers[action]
	if not handler then
		return nil
	end
	local t = os.clock()
	if action ~= "ready" and lastCall[player] and t - lastCall[player] < 0.08 then
		return nil
	end
	lastCall[player] = t
	local ok, result = pcall(handler, player, ...)
	if not ok then
		warn("[Action]", action, result)
		return nil
	end
	return result
end

-- Каждому игроку — маленький фонарик, чтобы в пещере было уютно
local function addLantern(char)
	local head = char:WaitForChild("Head", 10)
	if head then
		local light = Instance.new("PointLight")
		light.Name = "Lantern"
		light.Color = Color3.fromRGB(255, 225, 180)
		light.Range = 14
		light.Brightness = 0.7
		light.Shadows = false
		light.Parent = head
	end
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(addLantern)
	if player.Character then
		task.spawn(addLantern, player.Character)
	end
	local data = PlayerData.load(player)
	if not data then
		return
	end
	Farm.onPlayerAdded(player)
	PlayerData.push(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	Farm.onPlayerRemoving(player)
	PlayerData.release(player)
	lastCall[player] = nil
end)

game:BindToClose(function()
	PlayerData.saveAll()
end)

PlayerData.startAutosave()
