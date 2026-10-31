--!nonstrict
-- Точка входа клиента «Светогрибов».
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Action = Remotes:WaitForChild("Action")

local UI = require(script:WaitForChild("UI"))
local Visuals = require(script:WaitForChild("Visuals"))
local Sfx = require(script:WaitForChild("Sfx"))

local function call(name: string, ...)
	local ok, result = pcall(Action.InvokeServer, Action, name, ...)
	if not ok then
		warn("[Action]", name, result)
		return nil
	end
	return result
end

UI.init({
	select = function(id)
		call("select", id)
	end,
	buy = function(id, amount)
		call("buySpore", id, amount)
	end,
	home = function()
		call("home")
	end,
})
Visuals.init()
Sfx.startMusic()

Remotes:WaitForChild("State").OnClientEvent:Connect(UI.setState)
Remotes:WaitForChild("Notify").OnClientEvent:Connect(UI.toast)
Remotes:WaitForChild("Discover").OnClientEvent:Connect(UI.discover)
Remotes:WaitForChild("OpenShop").OnClientEvent:Connect(UI.openShop)
Remotes:WaitForChild("Effect").OnClientEvent:Connect(function(kind, ...)
	if kind == "sell" then
		UI.sold(...)
	else
		Visuals.effect(kind, ...)
	end
end)

local function onStorm()
	local on = ReplicatedStorage:GetAttribute("Storm") == true
	UI.setStorm(on)
	Visuals.setStorm(on)
	if on then
		UI.toast("⚡ Началась Кристальная гроза! Грибы могут мутировать!", "rare")
	end
end
ReplicatedStorage:GetAttributeChangedSignal("Storm"):Connect(onStorm)
if ReplicatedStorage:GetAttribute("Storm") then
	onStorm()
end

-- Первое состояние
local state = call("ready")
if state then
	UI.setState(state)
end
UI.toast("Добро пожаловать в Светогрибы! 🍄 Посади спору на грядку.", "info")
