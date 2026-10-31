--!nonstrict
-- Сохранение и загрузка прогресса игрока (DataStore).
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Species = require(ReplicatedStorage.Shared.Species)
local Remotes = require(script.Parent.Remotes)

local PlayerData = {}

local cache = {} -- [player] = data
local canSave = {} -- [player] = true, если загрузка прошла успешно

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[Data] DataStore недоступен:", result)
	end
end

local function defaultData()
	return {
		v = 1,
		coins = Config.START_COINS,
		spores = table.clone(Config.START_SPORES),
		mushrooms = {}, -- ["speciesId|mutation"] = количество
		discovered = { glow_blue = true },
		bedsUnlocked = Config.START_BEDS,
		beds = {}, -- ["1".."8"] = { s = speciesId, t = plantedAt, g = growTime, m = mutation }
		selected = "glow_blue",
	}
end

local function sanitize(data)
	local def = defaultData()
	if type(data) ~= "table" then
		return def
	end
	for k, v in def do
		if type(data[k]) ~= type(v) then
			data[k] = v
		end
	end
	return data
end

local function countKeys(t): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function makeLeaderstats(player, data)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Монеты"
	coins.Value = data.coins
	coins.Parent = ls
	local kinds = Instance.new("IntValue")
	kinds.Name = "Виды"
	kinds.Value = countKeys(data.discovered)
	kinds.Parent = ls
	ls.Parent = player
end

function PlayerData.load(player)
	local key = "u_" .. player.UserId
	local loaded, ok = nil, false
	if store then
		for attempt = 1, 3 do
			local success, result = pcall(function()
				return store:GetAsync(key)
			end)
			if success then
				loaded = result
				ok = true
				break
			end
			warn(string.format("[Data] Попытка %d загрузки %s не удалась: %s", attempt, player.Name, tostring(result)))
			task.wait(1.5)
		end
	end
	if not ok then
		warn("[Data] Прогресс " .. player.Name .. " НЕ будет сохраняться. В Studio: Game Settings → Security → Enable Studio Access to API Services")
	end

	local isNew = loaded == nil
	local data = sanitize(loaded)
	if isNew and RunService:IsStudio() then
		data.coins += Config.STUDIO_BONUS_COINS
	end

	if not player.Parent then
		return nil -- игрок вышел, пока грузились данные
	end
	cache[player] = data
	canSave[player] = ok
	makeLeaderstats(player, data)
	return data
end

function PlayerData.get(player)
	return cache[player]
end

function PlayerData.snapshot(player)
	local d = cache[player]
	if not d then
		return nil
	end
	return {
		coins = d.coins,
		spores = d.spores,
		mushrooms = d.mushrooms,
		discovered = d.discovered,
		bedsUnlocked = d.bedsUnlocked,
		selected = d.selected,
	}
end

-- Отправить игроку актуальное состояние и обновить таблицу лидеров
function PlayerData.push(player)
	local d = cache[player]
	if not d then
		return
	end
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		local coins = ls:FindFirstChild("Монеты")
		local kinds = ls:FindFirstChild("Виды")
		if coins then
			coins.Value = d.coins
		end
		if kinds then
			kinds.Value = countKeys(d.discovered)
		end
	end
	Remotes.State:FireClient(player, PlayerData.snapshot(player))
end

-- Выдать споры (и открыть вид в книге, если он новый)
function PlayerData.addSpore(player, speciesId: string, amount: number)
	local d = cache[player]
	if not d or not Species.byId[speciesId] then
		return
	end
	d.spores[speciesId] = (d.spores[speciesId] or 0) + amount
	if (d.spores[d.selected] or 0) <= 0 then
		d.selected = speciesId
	end
	if not d.discovered[speciesId] then
		d.discovered[speciesId] = true
		Remotes.Discover:FireClient(player, speciesId)
	end
end

function PlayerData.save(player)
	local d = cache[player]
	if not d or not canSave[player] or not store then
		return
	end
	local key = "u_" .. player.UserId
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			store:SetAsync(key, d)
		end)
		if ok then
			return
		end
		warn(string.format("[Data] Попытка %d сохранения %s не удалась: %s", attempt, player.Name, tostring(err)))
		task.wait(1)
	end
end

function PlayerData.release(player)
	PlayerData.save(player)
	cache[player] = nil
	canSave[player] = nil
end

function PlayerData.saveAll()
	local pending = 0
	for player in cache do
		pending += 1
		task.spawn(function()
			PlayerData.save(player)
			pending -= 1
		end)
	end
	local start = os.clock()
	while pending > 0 and os.clock() - start < 25 do
		task.wait(0.2)
	end
end

function PlayerData.startAutosave()
	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_INTERVAL)
			for player in cache do
				task.spawn(PlayerData.save, player)
			end
		end
	end)
end

-- Клиент запрашивает своё состояние при запуске
Remotes.handlers.ready = function(player)
	local waited = 0
	while not cache[player] and waited < 15 do
		waited += task.wait(0.2)
	end
	return PlayerData.snapshot(player)
end

return PlayerData
