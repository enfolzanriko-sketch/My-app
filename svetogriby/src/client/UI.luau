--!nonstrict
-- Интерфейс: монеты, корзина, панель спор, магазин, книга грибов,
-- окно «Новый вид!», уведомления, баннер грозы. Всё создаётся кодом.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Species = require(Shared:WaitForChild("Species"))
local Builder = require(Shared:WaitForChild("MushroomBuilder"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local UI = {}

local C = {
	panel = Color3.fromRGB(38, 26, 66),
	panel2 = Color3.fromRGB(58, 40, 98),
	dark = Color3.fromRGB(20, 12, 36),
	accent = Color3.fromRGB(110, 230, 255),
	pink = Color3.fromRGB(255, 120, 220),
	gold = Color3.fromRGB(255, 205, 70),
	green = Color3.fromRGB(110, 235, 130),
	red = Color3.fromRGB(255, 100, 110),
	text = Color3.fromRGB(255, 255, 255),
	muted = Color3.fromRGB(180, 170, 210),
}
local FONT = Enum.Font.FredokaOne

-- ===== Помощники =====
local function new(className: string, props, children)
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				inst[k] = v
			end
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(parent, r: number?)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 12), Parent = parent })
end

local function stroke(parent, color: Color3?, thickness: number?, transparency: number?)
	return new("UIStroke", {
		Color = color or C.accent,
		Thickness = thickness or 2,
		Transparency = transparency or 0.3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function label(props)
	local maxSize = props.MaxTextSize or 28
	props.MaxTextSize = nil
	if props.BackgroundTransparency == nil then
		props.BackgroundTransparency = 1
	end
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or C.text
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	local l = new("TextLabel", props)
	new("UITextSizeConstraint", { MaxTextSize = maxSize, Parent = l })
	return l
end

local function pressAnim(btn)
	local scale = new("UIScale", { Parent = btn })
	btn.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 0.92 }):Play()
	end)
	local function up()
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	btn.MouseButton1Up:Connect(up)
	btn.MouseLeave:Connect(up)
end

local function button(props, onClick)
	local maxSize = props.MaxTextSize or 24
	props.MaxTextSize = nil
	props.BackgroundColor3 = props.BackgroundColor3 or C.panel2
	props.Font = FONT
	props.TextColor3 = props.TextColor3 or C.text
	props.TextScaled = true
	props.AutoButtonColor = true
	local b = new("TextButton", props)
	corner(b, 12)
	stroke(b, C.accent, 2, 0.45)
	new("UITextSizeConstraint", { MaxTextSize = maxSize, Parent = b })
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		Parent = b,
	})
	pressAnim(b)
	if onClick then
		b.Activated:Connect(function()
			Sfx.play("click", 0.4)
			onClick()
		end)
	end
	return b
end

local function panel(props)
	props.BackgroundColor3 = props.BackgroundColor3 or C.panel
	if props.BackgroundTransparency == nil then
		props.BackgroundTransparency = 0.06
	end
	local f = new("Frame", props)
	corner(f, 16)
	stroke(f, C.accent, 2, 0.35)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(185, 175, 220)),
		Parent = f,
	})
	return f
end

local function formatNumber(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (out:gsub("^ ", ""))
end

local function fmtTime(sec: number): string
	sec = math.max(0, math.ceil(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

-- 3D-превью гриба внутри интерфейса
local function makePreview(parent, speciesId: string, mutation: string?)
	local vp = new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(190, 185, 215),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1.5, 1),
		Parent = parent,
	})
	local info = Builder.build(speciesId, mutation)
	info.model.Parent = vp
	local sp = info.species
	local height = Builder.height(sp)
	local focus = Vector3.new(0, height * 0.55, 0)
	local dist = height * 1.9 + sp.capSize * 0.4
	local cam = new("Camera", { FieldOfView = 40, Parent = vp })
	cam.CFrame = CFrame.lookAt(focus + Vector3.new(dist * 0.3, height * 0.35, -dist), focus)
	vp.CurrentCamera = cam
	return { vp = vp, info = info }
end

-- ===== Состояние =====
local actions = {}
local current = { coins = 0, spores = {}, mushrooms = {}, discovered = {}, bedsUnlocked = 4, selected = "" }

local gui, uiScale
local coinsText, basketText, bookText
local coinValue = Instance.new("NumberValue")
local coinTween
local hotbarScroll, emptyHint
local slots = {}
local shopPanel, shopRows = nil, {}
local bookPanel, bookTitle, bookCards = nil, nil, {}
local toastHolder
local discoverOverlay, discoverHolder, discoverName, discoverRarity, discoverDesc
local discoverQueue, discoverShowing, discoverSpin = {}, false, nil
local stormBanner, stormText
local openPanelRef = nil

-- ===== Окна =====
local function closePanels()
	if shopPanel then
		shopPanel.Visible = false
	end
	if bookPanel then
		bookPanel.Visible = false
	end
	openPanelRef = nil
end

local function openPanel(p)
	if openPanelRef == p then
		closePanels()
		return
	end
	closePanels()
	openPanelRef = p
	p.Visible = true
	local s = p:FindFirstChild("PopScale")
	if s then
		s.Scale = 0.85
		TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

local function modal(title: string, size: Vector2)
	local p = panel({
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		ZIndex = 10,
		Parent = gui,
	})
	new("UIScale", { Name = "PopScale", Parent = p })
	local titleLabel = label({
		Name = "Title",
		Text = title,
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -80, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.accent,
		MaxTextSize = 34,
		ZIndex = 11,
		Parent = p,
	})
	button({
		Text = "✕",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = C.red,
		ZIndex = 11,
		Parent = p,
	}, closePanels)
	local body = new("ScrollingFrame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 60),
		Size = UDim2.new(1, -24, 1, -72),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.accent,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 11,
		Parent = p,
	})
	return p, body, titleLabel
end

-- ===== Магазин спор =====
local function buildShop()
	local body
	shopPanel, body = modal("🍄 Споровщик", Vector2.new(560, 440))
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })
	for i, sp in Species.list do
		if sp.sporePrice then
			local row = new("Frame", {
				BackgroundColor3 = C.panel2,
				BackgroundTransparency = 0.2,
				Size = UDim2.new(1, -10, 0, 78),
				LayoutOrder = i,
				ZIndex = 12,
				Parent = body,
			})
			corner(row, 12)
			local holder = new("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(6, 4),
				Size = UDim2.fromOffset(70, 70),
				ZIndex = 12,
				Parent = row,
			})
			local pv = makePreview(holder, sp.id)
			pv.vp.ZIndex = 12
			label({
				Text = sp.name,
				Position = UDim2.fromOffset(84, 8),
				Size = UDim2.new(1, -300, 0, 28),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Species.rarityOf(sp).color,
				MaxTextSize = 24,
				ZIndex = 12,
				Parent = row,
			})
			label({
				Text = string.format("Растёт %s · продаётся за %d 🪙", fmtTime(sp.growTime), sp.sellPrice),
				Position = UDim2.fromOffset(84, 40),
				Size = UDim2.new(1, -300, 0, 22),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = C.muted,
				MaxTextSize = 16,
				ZIndex = 12,
				Parent = row,
			})
			local b1 = button({
				Text = string.format("x1 · %d🪙", sp.sporePrice),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -112, 0.5, 0),
				Size = UDim2.fromOffset(100, 46),
				MaxTextSize = 20,
				ZIndex = 12,
				Parent = row,
			}, function()
				actions.buy(sp.id, 1)
			end)
			local b5 = button({
				Text = string.format("x5 · %d🪙", sp.sporePrice * 5),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(100, 46),
				MaxTextSize = 20,
				ZIndex = 12,
				Parent = row,
			}, function()
				actions.buy(sp.id, 5)
			end)
			shopRows[sp.id] = { sp = sp, b1 = b1, b5 = b5 }
		end
	end
end

local function refreshShop()
	for _, row in shopRows do
		local can1 = current.coins >= row.sp.sporePrice
		local can5 = current.coins >= row.sp.sporePrice * 5
		row.b1.BackgroundColor3 = can1 and C.green or C.panel
		row.b5.BackgroundColor3 = can5 and C.green or C.panel
		row.b1.TextColor3 = can1 and C.dark or C.muted
		row.b5.TextColor3 = can5 and C.dark or C.muted
	end
end

-- ===== Книга грибов =====
local function buildBook()
	local body
	bookPanel, body, bookTitle = modal("📖 Книга грибов", Vector2.new(640, 470))
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(140, 176),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = body,
	})
	for i, sp in Species.list do
		local card = new("Frame", {
			BackgroundColor3 = C.panel2,
			BackgroundTransparency = 0.15,
			LayoutOrder = i,
			ZIndex = 12,
			Parent = body,
		})
		corner(card, 12)
		local st = stroke(card, Species.rarityOf(sp).color, 2, 0.4)
		local holder = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(10, 6),
			Size = UDim2.new(1, -20, 0, 92),
			ZIndex = 12,
			Parent = card,
		})
		local question = label({
			Text = "❓",
			Size = UDim2.fromScale(1, 1),
			MaxTextSize = 60,
			ZIndex = 12,
			Parent = holder,
		})
		local name = label({
			Text = "???",
			Position = UDim2.fromOffset(6, 100),
			Size = UDim2.new(1, -12, 0, 22),
			MaxTextSize = 18,
			ZIndex = 12,
			Parent = card,
		})
		local sub = label({
			Text = "",
			Position = UDim2.fromOffset(6, 124),
			Size = UDim2.new(1, -12, 0, 46),
			TextColor3 = C.muted,
			TextWrapped = true,
			MaxTextSize = 14,
			ZIndex = 12,
			Parent = card,
		})
		bookCards[sp.id] = { sp = sp, holder = holder, question = question, name = name, sub = sub, stroke = st, preview = nil }
	end
end

local function refreshBook()
	local found = 0
	for id, card in bookCards do
		local sp = card.sp
		if current.discovered[id] then
			found += 1
			card.question.Visible = false
			if not card.preview then
				card.preview = makePreview(card.holder, id)
				card.preview.vp.ZIndex = 12
			end
			card.name.Text = sp.name
			card.name.TextColor3 = Species.rarityOf(sp).color
			card.sub.Text = Species.rarityOf(sp).name .. " · " .. sp.sellPrice .. " 🪙"
			card.stroke.Transparency = 0.1
		else
			card.question.Visible = true
			card.name.Text = "???"
			card.name.TextColor3 = C.muted
			card.sub.Text = sp.hint
			card.stroke.Transparency = 0.7
		end
	end
	if bookTitle then
		bookTitle.Text = string.format("📖 Книга грибов  %d/%d", found, #Species.list)
	end
end

-- ===== Панель спор (внизу) =====
local function getSlot(sp)
	local slot = slots[sp.id]
	if slot then
		return slot
	end
	local b = new("TextButton", {
		Name = sp.id,
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = C.panel2,
		Size = UDim2.fromOffset(86, 96),
		LayoutOrder = sp.order,
		Parent = hotbarScroll,
	})
	corner(b, 12)
	local st = stroke(b, C.muted, 2, 0.5)
	pressAnim(b)
	local holder = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -8, 0, 58),
		Parent = b,
	})
	makePreview(holder, sp.id)
	local count = label({
		Text = "x0",
		Position = UDim2.fromOffset(3, 58),
		Size = UDim2.new(1, -6, 0, 18),
		MaxTextSize = 18,
		Parent = b,
	})
	label({
		Text = sp.name,
		Position = UDim2.fromOffset(3, 77),
		Size = UDim2.new(1, -6, 0, 15),
		TextColor3 = C.muted,
		MaxTextSize = 13,
		Parent = b,
	})
	b.Activated:Connect(function()
		Sfx.play("click", 0.4)
		actions.select(sp.id)
	end)
	slot = { button = b, stroke = st, count = count }
	slots[sp.id] = slot
	return slot
end

-- ===== Публичные функции =====
function UI.toast(text: string, kind: string?)
	if not toastHolder then
		return
	end
	local color = C.accent
	if kind == "good" then
		color = C.green
	elseif kind == "warn" then
		color = C.red
	elseif kind == "rare" then
		color = C.pink
	end
	local group = new("CanvasGroup", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(440, 42),
		GroupTransparency = 1,
		LayoutOrder = math.floor(os.clock() * 100),
		Parent = toastHolder,
	})
	local f = panel({ Size = UDim2.fromScale(1, 1), Parent = group })
	f.UIStroke.Color = color
	label({
		Text = text,
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 1, -8),
		TextColor3 = color,
		MaxTextSize = 20,
		Parent = f,
	})
	TweenService:Create(group, TweenInfo.new(0.25), { GroupTransparency = 0 }):Play()
	task.delay(3.2, function()
		local tw = TweenService:Create(group, TweenInfo.new(0.4), { GroupTransparency = 1 })
		tw:Play()
		tw.Completed:Wait()
		group:Destroy()
	end)
	-- не больше 4 сообщений одновременно
	local list = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("CanvasGroup") then
			table.insert(list, child)
		end
	end
	if #list > 4 then
		table.sort(list, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		list[1]:Destroy()
	end
end

function UI.setState(state)
	if type(state) ~= "table" then
		return
	end
	current = state

	if coinTween then
		coinTween:Cancel()
	end
	coinTween = TweenService:Create(coinValue, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Value = state.coins })
	coinTween:Play()

	local basket = 0
	for _, n in state.mushrooms do
		basket += n
	end
	basketText.Text = "🧺 " .. basket

	local found = 0
	for _ in state.discovered do
		found += 1
	end
	bookText.Text = string.format("📖 %d/%d", found, #Species.list)

	local any = false
	for _, sp in Species.list do
		local n = state.spores[sp.id] or 0
		if n > 0 then
			any = true
			local slot = getSlot(sp)
			slot.button.Visible = true
			slot.count.Text = "x" .. n
			local selected = state.selected == sp.id
			slot.stroke.Color = selected and C.gold or C.muted
			slot.stroke.Transparency = selected and 0 or 0.5
			slot.stroke.Thickness = selected and 3 or 2
			slot.button.BackgroundColor3 = selected and Color3.fromRGB(90, 62, 130) or C.panel2
		elseif slots[sp.id] then
			slots[sp.id].button.Visible = false
		end
	end
	emptyHint.Visible = not any

	refreshShop()
	refreshBook()
end

function UI.openShop()
	if openPanelRef ~= shopPanel then
		openPanel(shopPanel)
	end
end

local function showNextDiscovery()
	local id = table.remove(discoverQueue, 1)
	if not id then
		discoverShowing = false
		discoverOverlay.Visible = false
		if discoverSpin then
			discoverSpin:Disconnect()
			discoverSpin = nil
		end
		return
	end
	discoverShowing = true
	local sp = Species.byId[id]
	for _, child in discoverHolder:GetChildren() do
		child:Destroy()
	end
	local pv = makePreview(discoverHolder, id)
	pv.vp.ZIndex = 22
	discoverName.Text = sp.name
	discoverRarity.Text = Species.rarityOf(sp).name
	discoverRarity.TextColor3 = Species.rarityOf(sp).color
	discoverDesc.Text = sp.description
	discoverOverlay.Visible = true
	local pop = discoverOverlay:FindFirstChild("Card"):FindFirstChild("PopScale")
	pop.Scale = 0.6
	TweenService:Create(pop, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	if discoverSpin then
		discoverSpin:Disconnect()
	end
	discoverSpin = RunService.RenderStepped:Connect(function()
		if pv.info.model.Parent then
			pv.info.model:PivotTo(CFrame.Angles(0, os.clock() * 1.2, 0))
		end
	end)
	Sfx.play("discover")
end

function UI.discover(id: string)
	if not Species.byId[id] then
		return
	end
	table.insert(discoverQueue, id)
	if not discoverShowing then
		showNextDiscovery()
	end
end

function UI.sold(total: number, count: number)
	Sfx.play("sell")
	UI.toast(string.format("Продано грибов: %d", count), "good")
	local t = label({
		Text = "+" .. formatNumber(total) .. " 🪙",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(400, 80),
		TextColor3 = C.gold,
		MaxTextSize = 64,
		ZIndex = 30,
		Parent = gui,
	})
	stroke(t, C.dark, 3, 0).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	TweenService:Create(t, TweenInfo.new(1.4, Enum.EasingStyle.Quad), {
		Position = UDim2.fromScale(0.5, 0.3),
		TextTransparency = 1,
	}):Play()
	task.delay(1.5, function()
		t:Destroy()
	end)
end

function UI.setStorm(on: boolean)
	stormBanner.Visible = on
end

-- ===== Создание интерфейса =====
function UI.init(callbacks)
	actions = callbacks

	gui = new("ScreenGui", {
		Name = "SvetoUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	uiScale = new("UIScale", { Parent = gui })
	local function rescale()
		local vs = camera.ViewportSize
		uiScale.Scale = math.clamp(math.min(vs.X / 1100, vs.Y / 680), 0.55, 1.15)
	end
	rescale()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	-- Верхние «таблетки»: монеты, корзина, книга
	local top = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(480, 48),
		Parent = gui,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = top,
	})
	local function pill(order: number, text: string, color: Color3, width: number)
		local f = panel({ Size = UDim2.fromOffset(width, 46), LayoutOrder = order, Parent = top })
		return label({
			Text = text,
			Position = UDim2.fromOffset(10, 5),
			Size = UDim2.new(1, -20, 1, -10),
			TextColor3 = color,
			MaxTextSize = 26,
			Parent = f,
		})
	end
	coinsText = pill(1, "🪙 0", C.gold, 170)
	basketText = pill(2, "🧺 0", C.green, 120)
	bookText = pill(3, "📖 0/" .. #Species.list, C.accent, 130)
	coinValue.Changed:Connect(function(v)
		coinsText.Text = "🪙 " .. formatNumber(v + 0.5)
	end)

	-- Уведомления
	toastHolder = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 112),
		Size = UDim2.fromOffset(440, 220),
		Parent = gui,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = toastHolder,
	})

	-- Баннер грозы
	stormBanner = panel({
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(520, 46),
		BackgroundColor3 = Color3.fromRGB(30, 40, 90),
		Parent = gui,
	})
	stormText = label({
		Text = "⚡ Кристальная гроза!",
		Position = UDim2.fromOffset(10, 5),
		Size = UDim2.new(1, -20, 1, -10),
		TextColor3 = Color3.fromRGB(150, 220, 255),
		MaxTextSize = 24,
		Parent = stormBanner,
	})

	-- Кнопки справа
	local side = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(84, 190),
		Parent = gui,
	})
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = side })
	button({ Text = "📖\nКнига", Size = UDim2.fromOffset(84, 84), LayoutOrder = 1, MaxTextSize = 22, Parent = side }, function()
		openPanel(bookPanel)
	end)
	button({ Text = "🏠\nДомой", Size = UDim2.fromOffset(84, 84), LayoutOrder = 2, MaxTextSize = 22, Parent = side }, function()
		closePanels()
		actions.home()
	end)

	-- Панель спор внизу
	local hotbar = panel({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(600, 136),
		Parent = gui,
	})
	label({
		Text = "Споры для посадки — выбери и нажми на грядку",
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -24, 0, 20),
		TextColor3 = C.muted,
		MaxTextSize = 15,
		Parent = hotbar,
	})
	hotbarScroll = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 28),
		Size = UDim2.new(1, -20, 1, -34),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.accent,
		Parent = hotbar,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = hotbarScroll,
	})
	emptyHint = label({
		Text = "Нет спор — купи их у 🍄 Споровщика в центральном зале",
		Position = UDim2.fromOffset(12, 40),
		Size = UDim2.new(1, -24, 0, 40),
		TextColor3 = C.pink,
		MaxTextSize = 20,
		Visible = false,
		Parent = hotbar,
	})

	buildShop()
	buildBook()

	-- Окно «Новый вид!»
	discoverOverlay = new("Frame", {
		Visible = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.new(1, 0, 1, 80),
		Position = UDim2.fromOffset(0, -80),
		ZIndex = 20,
		Active = true,
		Parent = gui,
	})
	local card = panel({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 470),
		ZIndex = 21,
		Parent = discoverOverlay,
	})
	card.UIStroke.Color = C.pink
	card.UIStroke.Thickness = 3
	new("UIScale", { Name = "PopScale", Parent = card })
	label({
		Text = "✨ НОВЫЙ ВИД! ✨",
		Position = UDim2.fromOffset(10, 12),
		Size = UDim2.new(1, -20, 0, 44),
		TextColor3 = C.pink,
		MaxTextSize = 38,
		ZIndex = 22,
		Parent = card,
	})
	discoverHolder = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(220, 200),
		ZIndex = 22,
		Parent = card,
	})
	discoverName = label({
		Text = "",
		Position = UDim2.fromOffset(10, 266),
		Size = UDim2.new(1, -20, 0, 36),
		MaxTextSize = 32,
		ZIndex = 22,
		Parent = card,
	})
	discoverRarity = label({
		Text = "",
		Position = UDim2.fromOffset(10, 302),
		Size = UDim2.new(1, -20, 0, 24),
		MaxTextSize = 22,
		ZIndex = 22,
		Parent = card,
	})
	discoverDesc = label({
		Text = "",
		Position = UDim2.fromOffset(20, 330),
		Size = UDim2.new(1, -40, 0, 60),
		TextColor3 = C.muted,
		TextWrapped = true,
		MaxTextSize = 18,
		ZIndex = 22,
		Parent = card,
	})
	button({
		Text = "Круто!",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(180, 52),
		BackgroundColor3 = C.pink,
		MaxTextSize = 28,
		ZIndex = 22,
		Parent = card,
	}, showNextDiscovery)

	-- Таймер грозы
	task.spawn(function()
		while true do
			task.wait(0.5)
			if stormBanner.Visible then
				local left = (ReplicatedStorage:GetAttribute("StormEnds") or 0) - workspace:GetServerTimeNow()
				stormText.Text = "⚡ Кристальная гроза! Грибы могут стать грозовыми · " .. fmtTime(left)
				local pulse = 0.5 + 0.5 * math.sin(os.clock() * 4)
				stormBanner.UIStroke.Color = Color3.fromRGB(110, 190, 255):Lerp(Color3.new(1, 1, 1), pulse)
			end
		end
	end)
end

return UI
