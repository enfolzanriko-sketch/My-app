--!nonstrict
-- Фермерство: выдача пещер, посадка, рост, сбор, скрещивание, открытие грядок.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Species = require(ReplicatedStorage.Shared.Species)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local Farm = {}

local rng = Random.new()
local speed = RunService:IsStudio() and Config.STUDIO_SPEED or 1

local plots = {} -- список пещер
local plotBeds = {} -- [plot] = { [index] = bed }
local plotOf = {} -- [player] = plot
local ownerOf = {} -- [plot] = player

local function notify(player, text: string, kind: string?)
	Remotes.Notify:FireClient(player, text, kind or "info")
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function fmtTime(sec: number): string
	sec = math.max(0, math.ceil(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

local function setSign(plot, text: string)
	local sign = plot:FindFirstChild("Sign")
	if not sign then
		return
	end
	for _, gui in sign:GetChildren() do
		if gui:IsA("SurfaceGui") then
			local label = gui:FindFirstChild("Text")
			if label then
				label.Text = text
			end
		end
	end
end

local function speciesLabel(bed): string
	local sp = Species.byId[bed:GetAttribute("Species")]
	local name = sp and sp.name or "?"
	local mut = Config.MUTATIONS[bed:GetAttribute("Mutation")]
	if mut and mut.name ~= "" then
		name = mut.name .. " · " .. name
	end
	return name
end

local function updatePrompt(bed)
	local prompt = bed:FindFirstChild("Prompt")
	local lock = bed:FindFirstChild("Lock")
	local unlocked = bed:GetAttribute("Unlocked")
	local owned = bed.Parent.Parent:GetAttribute("OwnerId") ~= 0
	if lock then
		lock.Enabled = owned and not unlocked
	end
	if not prompt then
		return
	end
	if not unlocked then
		local price = Config.BED_PRICES[bed:GetAttribute("Index")] or 0
		prompt.ActionText = "Открыть за " .. price .. " 🪙"
		prompt.ObjectText = "Закрытая грядка"
		prompt.HoldDuration = 0.4
		return
	end
	prompt.HoldDuration = 0
	if bed:GetAttribute("Species") == "" then
		prompt.ActionText = "Посадить"
		prompt.ObjectText = "Пустая грядка"
	else
		prompt.ObjectText = speciesLabel(bed)
		prompt.ActionText = bed:GetAttribute("Ready") and "Собрать" or "Растёт…"
	end
end

local function setBed(bed, speciesId: string, plantedAt: number, growTime: number, mutation: string)
	bed:SetAttribute("GrowTime", growTime)
	bed:SetAttribute("Mutation", mutation)
	bed:SetAttribute("Ready", speciesId ~= "" and now() >= plantedAt + growTime)
	bed:SetAttribute("PlantedAt", plantedAt)
	bed:SetAttribute("Species", speciesId)
	updatePrompt(bed)
end

local function clearBed(bed)
	setBed(bed, "", 0, 0, "none")
end

local function saveBed(data, index: number, bed)
	local sid = bed:GetAttribute("Species")
	if sid == "" then
		data.beds[tostring(index)] = nil
	else
		data.beds[tostring(index)] = {
			s = sid,
			t = bed:GetAttribute("PlantedAt"),
			g = bed:GetAttribute("GrowTime"),
			m = bed:GetAttribute("Mutation"),
		}
	end
end

-- ===== Действия на грядке =====

local function unlockBed(player, data, bed, index: number)
	if index ~= data.bedsUnlocked + 1 then
		notify(player, "Сначала открой грядку №" .. (data.bedsUnlocked + 1), "warn")
		return
	end
	local price = Config.BED_PRICES[index] or 0
	if data.coins < price then
		notify(player, "Не хватает монет: нужно " .. price .. " 🪙", "warn")
		return
	end
	data.coins -= price
	data.bedsUnlocked = index
	bed:SetAttribute("Unlocked", true)
	updatePrompt(bed)
	PlayerData.push(player)
	Remotes.Effect:FireAllClients("unlock", bed)
	notify(player, "Новая грядка открыта! 🌱", "good")
end

local function plant(player, data, bed, index: number)
	local sid = data.selected
	if type(sid) ~= "string" or (data.spores[sid] or 0) <= 0 then
		sid = nil
		for _, sp in Species.list do
			if (data.spores[sp.id] or 0) > 0 then
				sid = sp.id
				break
			end
		end
	end
	if not sid then
		notify(player, "Нет спор! Купи их у Споровщика в центре 🍄", "warn")
		return
	end

	data.spores[sid] -= 1
	if data.spores[sid] <= 0 then
		data.spores[sid] = nil
		-- автоматически выбираем следующую спору
		for _, sp in Species.list do
			if (data.spores[sp.id] or 0) > 0 then
				data.selected = sp.id
				break
			end
		end
	end

	local sp = Species.byId[sid]
	local mutation = rng:NextNumber() < Config.GOLD_CHANCE and "gold" or "none"
	setBed(bed, sid, now(), sp.growTime / speed, mutation)
	saveBed(data, index, bed)
	PlayerData.push(player)
	Remotes.Effect:FireAllClients("plant", bed)
	if mutation == "gold" then
		notify(player, "✨ Невероятно! Вырастет ЗОЛОТОЙ гриб (x5 цена)!", "rare")
	end
end

local function harvest(player, data, bed, index: number)
	local plot = plotOf[player]
	local sid = bed:GetAttribute("Species")
	local mutation = bed:GetAttribute("Mutation")
	local sp = Species.byId[sid]
	if not sp then
		clearBed(bed)
		return
	end

	-- В корзину
	local key = sid .. "|" .. mutation
	data.mushrooms[key] = (data.mushrooms[key] or 0) + 1

	-- Иногда возвращается спора того же вида
	if rng:NextNumber() < sp.sporeReturn then
		PlayerData.addSpore(player, sid, 1)
	end

	-- Скрещивание с соседями
	local results = {}
	for _, n in Config.neighbors(index) do
		local other = plotBeds[plot][n]
		if other and other:GetAttribute("Ready") then
			local result = Recipes.find(sid, other:GetAttribute("Species"))
			if result then
				table.insert(results, result)
			end
		end
	end
	local crossed = nil
	if #results > 0 and rng:NextNumber() < Config.CROSS_CHANCE then
		crossed = results[rng:NextInteger(1, #results)]
		PlayerData.addSpore(player, crossed, 1)
		notify(player, "🧬 Скрещивание удалось! +1 спора: " .. Species.byId[crossed].name, "rare")
	end

	-- Грозовой гриб может дать спору Грозовика
	if mutation == "storm" and rng:NextNumber() < Config.STORM_SPECIES_CHANCE then
		PlayerData.addSpore(player, "glow_storm", 1)
		notify(player, "⚡ Из грозового гриба выпала спора Грозовика!", "rare")
	end

	Remotes.Effect:FireAllClients("harvest", bed, sid, crossed)
	clearBed(bed)
	saveBed(data, index, bed)
	PlayerData.push(player)
end

local function onBedTriggered(bed, player)
	local plot = plotOf[player]
	if not plot or bed.Parent.Parent ~= plot then
		return
	end
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local index = bed:GetAttribute("Index")
	if not bed:GetAttribute("Unlocked") then
		unlockBed(player, data, bed, index)
	elseif bed:GetAttribute("Species") == "" then
		plant(player, data, bed, index)
	elseif bed:GetAttribute("Ready") then
		harvest(player, data, bed, index)
	else
		local left = bed:GetAttribute("PlantedAt") + bed:GetAttribute("GrowTime") - now()
		notify(player, "Ещё растёт… осталось " .. fmtTime(left), "info")
	end
end

-- ===== Игроки =====

function Farm.teleportHome(player)
	local plot = plotOf[player]
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if plot and hrp then
		hrp.CFrame = plot.Home.CFrame + Vector3.new(0, 3, 0)
	end
end

function Farm.onPlayerAdded(player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local plot
	for _, p in plots do
		if p:GetAttribute("OwnerId") == 0 then
			plot = p
			break
		end
	end
	if not plot then
		notify(player, "Все пещеры заняты 😢 Зайди на другой сервер.", "warn")
		return
	end

	plot:SetAttribute("OwnerId", player.UserId)
	plotOf[player] = plot
	ownerOf[plot] = player
	setSign(plot, "Пещера " .. player.DisplayName)

	for i, bed in plotBeds[plot] do
		bed:SetAttribute("Unlocked", i <= data.bedsUnlocked)
		local saved = data.beds[tostring(i)]
		if type(saved) == "table" and Species.byId[saved.s] and i <= data.bedsUnlocked then
			local growTime = tonumber(saved.g) or (Species.byId[saved.s].growTime / speed)
			setBed(bed, saved.s, tonumber(saved.t) or now(), growTime, saved.m or "none")
		else
			clearBed(bed)
		end
	end

	local function onCharacter(char)
		local hrp = char:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.1)
		if hrp and plotOf[player] == plot then
			hrp.CFrame = plot.Home.CFrame + Vector3.new(0, 3, 0)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

function Farm.onPlayerRemoving(player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	local data = PlayerData.get(player)
	if data then
		for i, bed in plotBeds[plot] do
			saveBed(data, i, bed)
		end
	end
	plotOf[player] = nil
	ownerOf[plot] = nil
	plot:SetAttribute("OwnerId", 0)
	setSign(plot, "Свободная пещера")
	for _, bed in plotBeds[plot] do
		bed:SetAttribute("Unlocked", false)
		clearBed(bed)
	end
end

-- Для событий (гроза): пройтись по всем посаженным грибам
function Farm.forEachPlanted(fn)
	for _, plot in plots do
		local player = ownerOf[plot]
		if player then
			for i, bed in plotBeds[plot] do
				if bed:GetAttribute("Species") ~= "" then
					fn(bed, player, i)
				end
			end
		end
	end
end

function Farm.setMutation(player, bed, index: number, mutation: string)
	bed:SetAttribute("Mutation", mutation)
	updatePrompt(bed)
	local data = PlayerData.get(player)
	if data then
		saveBed(data, index, bed)
	end
end

function Farm.init(map)
	plots = map.plots
	for _, plot in plots do
		local beds = {}
		for _, bed in plot.Beds:GetChildren() do
			beds[bed:GetAttribute("Index")] = bed
			updatePrompt(bed)
			bed.Prompt.Triggered:Connect(function(player)
				onBedTriggered(bed, player)
			end)
		end
		plotBeds[plot] = beds
	end

	-- Проверка созревания
	task.spawn(function()
		while true do
			task.wait(0.5)
			local t = now()
			for plot, beds in plotBeds do
				if ownerOf[plot] then
					for _, bed in beds do
						if bed:GetAttribute("Species") ~= "" and not bed:GetAttribute("Ready") then
							if t >= bed:GetAttribute("PlantedAt") + bed:GetAttribute("GrowTime") then
								bed:SetAttribute("Ready", true)
								updatePrompt(bed)
							end
						end
					end
				end
			end
		end
	end)
end

Remotes.handlers.home = function(player)
	Farm.teleportHome(player)
	return true
end

return Farm
