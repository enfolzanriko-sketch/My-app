--!nonstrict
-- Магазин спор, продажа грибов, выбор споры для посадки.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Species = require(ReplicatedStorage.Shared.Species)
local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local Shop = {}

local ALLOWED_AMOUNTS = { [1] = true, [5] = true, [10] = true }

local function notify(player, text: string, kind: string?)
	Remotes.Notify:FireClient(player, text, kind or "info")
end

function Shop.sellAll(player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local total, count = 0, 0
	for key, n in data.mushrooms do
		local sid, mut = string.match(key, "^(.-)|(.+)$")
		local sp = Species.byId[sid]
		local m = Config.MUTATIONS[mut] or Config.MUTATIONS.none
		if sp and type(n) == "number" and n > 0 then
			total += math.floor(sp.sellPrice * m.mult * n)
			count += n
		end
	end
	if count == 0 then
		notify(player, "Корзина пуста! Собери грибы в своей пещере 🧺", "warn")
		return
	end
	data.mushrooms = {}
	data.coins += total
	PlayerData.push(player)
	Remotes.Effect:FireClient(player, "sell", total, count)
end

Remotes.handlers.buySpore = function(player, speciesId, amount)
	local data = PlayerData.get(player)
	local sp = type(speciesId) == "string" and Species.byId[speciesId]
	if not data or not sp or not sp.sporePrice or not ALLOWED_AMOUNTS[amount] then
		return false
	end
	local cost = sp.sporePrice * amount
	if data.coins < cost then
		notify(player, "Не хватает монет 🪙", "warn")
		return false
	end
	data.coins -= cost
	PlayerData.addSpore(player, speciesId, amount)
	PlayerData.push(player)
	notify(player, string.format("Куплено: %s x%d", sp.name, amount), "good")
	return true
end

Remotes.handlers.select = function(player, speciesId)
	local data = PlayerData.get(player)
	if not data or type(speciesId) ~= "string" or (data.spores[speciesId] or 0) <= 0 then
		return false
	end
	data.selected = speciesId
	PlayerData.push(player)
	return true
end

function Shop.init(map)
	map.shopPrompt.Triggered:Connect(function(player)
		Remotes.OpenShop:FireClient(player)
	end)
	map.sellPrompt.Triggered:Connect(function(player)
		Shop.sellAll(player)
	end)
end

return Shop
