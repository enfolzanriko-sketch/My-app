--!nonstrict
-- Каналы связи сервер <-> клиент.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local function make(className: string, name: string)
	local r = Instance.new(className)
	r.Name = name
	r.Parent = folder
	return r
end

local Remotes = {
	Action = make("RemoteFunction", "Action"), -- клиент -> сервер: действия игрока
	State = make("RemoteEvent", "State"), -- сервер -> клиент: монеты, споры, книга
	Notify = make("RemoteEvent", "Notify"), -- сервер -> клиент: всплывающее сообщение
	Discover = make("RemoteEvent", "Discover"), -- сервер -> клиент: открыт новый вид
	OpenShop = make("RemoteEvent", "OpenShop"), -- сервер -> клиент: открыть магазин спор
	Effect = make("RemoteEvent", "Effect"), -- сервер -> клиенты: визуальные эффекты
	handlers = {}, -- [имя действия] = function(player, ...)
}

folder.Parent = ReplicatedStorage

return Remotes
