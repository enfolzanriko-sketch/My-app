--!nonstrict
-- Всё, что видно в мире: грибы на грядках с анимациями роста и покачивания,
-- полоски роста, «мостики» скрещивания, вспышки, гроза.
-- Грибы рисуются на клиенте — сервер хранит только данные грядки (атрибуты).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Species = require(Shared:WaitForChild("Species"))
local Recipes = require(Shared:WaitForChild("Recipes"))
local Builder = require(Shared:WaitForChild("MushroomBuilder"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Visuals = {}

local folder = Instance.new("Folder")
folder.Name = "MushroomVisuals"
folder.Parent = workspace

local entries = {} -- [bed] = entry
local dirty = {} -- [bed] = true -> пересобрать в следующем кадре
local bridges = {} -- [key] = Beam
local uidCounter = 0

local DRAW_DISTANCE = 170
local FONT = Enum.Font.FredokaOne
local TEX_SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local function bedPlot(bed)
	return bed.Parent and bed.Parent.Parent
end

local function isMine(bed): boolean
	local plot = bedPlot(bed)
	return plot ~= nil and plot:GetAttribute("OwnerId") == player.UserId
end

local function fmtTime(sec: number): string
	sec = math.max(0, math.ceil(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

-- ===== Табличка над грядкой =====
local function makeBillboard(bed, sp, mutation)
	local bb = Instance.new("BillboardGui")
	bb.Name = "GrowInfo"
	bb.Size = UDim2.fromOffset(140, 44)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 8, 0)
	bb.MaxDistance = 45
	bb.LightInfluence = 0
	bb.Adornee = bed

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 20)
	name.Font = FONT
	name.TextScaled = true
	name.TextColor3 = Species.rarityOf(sp).color
	local mut = Config.MUTATIONS[mutation]
	name.Text = (mut and mut.name ~= "" and (mut.name .. " · ") or "") .. sp.name
	if mutation == "gold" then
		name.TextColor3 = Color3.fromRGB(255, 210, 70)
	elseif mutation == "storm" then
		name.TextColor3 = Color3.fromRGB(130, 210, 255)
	end
	name.Parent = bb
	local nameStroke = Instance.new("UIStroke")
	nameStroke.Thickness = 2
	nameStroke.Color = Color3.fromRGB(20, 10, 40)
	nameStroke.Parent = name

	local barBg = Instance.new("Frame")
	barBg.Position = UDim2.fromOffset(10, 24)
	barBg.Size = UDim2.new(1, -20, 0, 16)
	barBg.BackgroundColor3 = Color3.fromRGB(25, 15, 45)
	barBg.BackgroundTransparency = 0.2
	barBg.Parent = bb
	local c1 = Instance.new("UICorner")
	c1.CornerRadius = UDim.new(1, 0)
	c1.Parent = barBg

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = sp.glowColor
	fill.Parent = barBg
	local c2 = Instance.new("UICorner")
	c2.CornerRadius = UDim.new(1, 0)
	c2.Parent = fill

	local timeText = Instance.new("TextLabel")
	timeText.BackgroundTransparency = 1
	timeText.Size = UDim2.fromScale(1, 1)
	timeText.Font = FONT
	timeText.TextScaled = true
	timeText.TextColor3 = Color3.new(1, 1, 1)
	timeText.Text = ""
	timeText.ZIndex = 2
	timeText.Parent = barBg
	local timeStroke = Instance.new("UIStroke")
	timeStroke.Thickness = 1.5
	timeStroke.Color = Color3.fromRGB(20, 10, 40)
	timeStroke.Parent = timeText

	bb.Parent = bed
	return { gui = bb, fill = fill, time = timeText, lastText = "" }
end

local function updateBillboard(e, p: number, now: number)
	local bb = e.bb
	if not bb then
		return
	end
	local text
	if p >= 1 then
		text = "✨ Готово!"
		bb.fill.Size = UDim2.fromScale(1, 1)
	else
		text = fmtTime(e.plantedAt + e.growTime - now)
		bb.fill.Size = UDim2.fromScale(p, 1)
	end
	if text ~= bb.lastText then
		bb.lastText = text
		bb.time.Text = text
	end
end

-- ===== Грибы на грядках =====
local function clearEntry(bed)
	local e = entries[bed]
	if e then
		e.info.model:Destroy()
		if e.bb then
			e.bb.gui:Destroy()
		end
		entries[bed] = nil
	end
end

local function bedTop(bed): CFrame
	return bed.CFrame * CFrame.new(0, bed.Size.Y / 2, 0)
end

local function rebuild(bed)
	clearEntry(bed)
	local sid = bed:GetAttribute("Species")
	local sp = type(sid) == "string" and Species.byId[sid]
	if not sp then
		return
	end
	local mutation = bed:GetAttribute("Mutation") or "none"
	local info = Builder.build(sid, mutation)
	info.model.Parent = folder
	uidCounter += 1
	local e = {
		uid = uidCounter,
		bed = bed,
		info = info,
		sp = sp,
		plantedAt = bed:GetAttribute("PlantedAt") or 0,
		growTime = math.max(bed:GetAttribute("GrowTime") or 1, 0.1),
		phase = math.random() * 10,
		yaw = math.random() * math.pi * 2,
		fxOn = true,
	}
	local now = workspace:GetServerTimeNow()
	local p = math.clamp((now - e.plantedAt) / e.growTime, 0, 1)
	e.wasReady = p >= 1
	e.bb = makeBillboard(bed, sp, mutation)
	Builder.setScale(info, 0.12 + 0.88 * p)
	Builder.place(info, bedTop(bed) * CFrame.Angles(0, e.yaw, 0))
	entries[bed] = e
end

local function watchBed(bed)
	dirty[bed] = true
	for _, attr in { "Species", "PlantedAt", "Mutation", "GrowTime" } do
		bed:GetAttributeChangedSignal(attr):Connect(function()
			dirty[bed] = true
		end)
	end
	bed.AncestryChanged:Connect(function()
		if not bed:IsDescendantOf(workspace) then
			clearEntry(bed)
		end
	end)
	-- Подсказки (кнопки E) показываем только на своих грядках
	local prompt = bed:WaitForChild("Prompt", 10)
	local plot = bedPlot(bed)
	local function refresh()
		if prompt then
			prompt.Enabled = isMine(bed)
		end
	end
	refresh()
	if plot then
		plot:GetAttributeChangedSignal("OwnerId"):Connect(refresh)
	end
end

-- ===== Мостики скрещивания =====
local function makeBeam(a, b)
	local beam = Instance.new("Beam")
	beam.Attachment0 = a.info.attachment
	beam.Attachment1 = b.info.attachment
	beam.Color = ColorSequence.new(a.info.glowColor, b.info.glowColor)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Width0 = 0.4
	beam.Width1 = 0.4
	beam.FaceCamera = true
	beam.CurveSize0 = 3
	beam.CurveSize1 = -3
	beam.Segments = 20
	beam.Texture = TEX_SPARKLE
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = 1.5
	beam.TextureSpeed = 1
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 0.7),
	})
	beam.Parent = a.info.model
	return beam
end

local function updateBridges(now: number)
	local ready = {} -- [plot] = { [index] = entry }
	for bed, e in entries do
		local plot = bedPlot(bed)
		if plot and now - e.plantedAt >= e.growTime then
			ready[plot] = ready[plot] or {}
			ready[plot][bed:GetAttribute("Index")] = e
		end
	end
	local active = {}
	for _, map in ready do
		for idx, e in map do
			for _, n in Config.neighbors(idx) do
				local o = map[n]
				if n > idx and o and Recipes.find(e.sp.id, o.sp.id) then
					local key = e.uid .. "_" .. o.uid
					active[key] = true
					if not bridges[key] or not bridges[key].Parent then
						bridges[key] = makeBeam(e, o)
					end
				end
			end
		end
	end
	for key, beam in bridges do
		if not active[key] then
			if beam.Parent then
				beam:Destroy()
			end
			bridges[key] = nil
		end
	end
end

-- ===== Одноразовые эффекты =====
local function burstAt(cf: CFrame, color: Color3, count: number, speed: number)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = cf
	p.Parent = folder
	local em = Instance.new("ParticleEmitter")
	em.Texture = TEX_SPARKLE
	em.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	em.LightEmission = 1
	em.Size = NumberSequence.new(0.45, 0)
	em.Lifetime = NumberRange.new(0.6, 1.2)
	em.Speed = NumberRange.new(speed * 0.5, speed)
	em.SpreadAngle = Vector2.new(180, 180)
	em.Drag = 3
	em.Acceleration = Vector3.new(0, 2, 0)
	em.Rate = 0
	em.Parent = p
	task.defer(function()
		em:Emit(count)
	end)
	Debris:AddItem(p, 3)
end

function Visuals.effect(kind: string, bed, speciesId, crossedId)
	if typeof(bed) ~= "Instance" then
		return
	end
	local top = bedTop(bed) * CFrame.new(0, 1, 0)
	local mine = isMine(bed)
	if kind == "plant" then
		burstAt(top, Color3.fromRGB(150, 110, 70), 18, 6)
		if mine then
			Sfx.play("plant")
		end
	elseif kind == "harvest" then
		local sp = Species.byId[speciesId]
		burstAt(top * CFrame.new(0, 2, 0), sp and sp.glowColor or Color3.new(1, 1, 1), 35, 10)
		if crossedId then
			local csp = Species.byId[crossedId]
			burstAt(top * CFrame.new(0, 3, 0), csp and csp.glowColor or Color3.new(1, 1, 1), 60, 14)
		end
		if mine then
			Sfx.play("harvest")
		end
	elseif kind == "mutate" then
		burstAt(top * CFrame.new(0, 2, 0), Color3.fromRGB(120, 200, 255), 50, 12)
	elseif kind == "unlock" then
		burstAt(top, Color3.fromRGB(255, 210, 80), 40, 10)
		if mine then
			Sfx.play("unlock")
		end
	end
end

-- ===== Гроза =====
local stormFx = Instance.new("ColorCorrectionEffect")
stormFx.Name = "StormFlash"
stormFx.Parent = Lighting
local stormOn = false

function Visuals.setStorm(on: boolean)
	if on == stormOn then
		return
	end
	stormOn = on
	if not on then
		TweenService:Create(stormFx, TweenInfo.new(2), { TintColor = Color3.new(1, 1, 1), Brightness = 0 }):Play()
		return
	end
	TweenService:Create(stormFx, TweenInfo.new(2), { TintColor = Color3.fromRGB(205, 220, 255) }):Play()
	task.spawn(function()
		while stormOn do
			task.wait(math.random(25, 60) / 10)
			if not stormOn then
				break
			end
			stormFx.Brightness = 0.45
			TweenService:Create(stormFx, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
			Sfx.play("thunder", 0.5)
			-- Лёгкая тряска камеры
			local start = os.clock()
			local conn
			conn = RunService.RenderStepped:Connect(function()
				local k = os.clock() - start
				if k > 0.35 then
					conn:Disconnect()
					return
				end
				local a = (0.35 - k) * 0.6
				camera.CFrame = camera.CFrame * CFrame.Angles(math.random(-10, 10) / 100 * a, math.random(-10, 10) / 100 * a, 0)
			end)
		end
	end)
end

-- ===== Главный цикл анимации =====
local bridgeTimer = 0

local function step(dt: number)
	for bed in dirty do
		dirty[bed] = nil
		if bed:IsDescendantOf(workspace) then
			rebuild(bed)
		end
	end

	local now = workspace:GetServerTimeNow()
	local t = os.clock()
	local camPos = camera.CFrame.Position
	local ps, cs = {}, {}

	for bed, e in entries do
		local p = math.clamp((now - e.plantedAt) / e.growTime, 0, 1)
		local ready = p >= 1
		updateBillboard(e, p, now)

		if ready and not e.wasReady then
			e.popT = t -- гриб только что созрел: «пуф!»
			if e.info.burst then
				e.info.burst:Emit(30)
			end
		end
		e.wasReady = ready

		if (bed.Position - camPos).Magnitude < DRAW_DISTANCE then
			local tt = t + e.phase
			-- Рост: плавно, с шагом 1%
			local s = 0.12 + 0.88 * (math.floor(p * 100) / 100)
			if e.popT then
				local k = t - e.popT
				if k < 1.2 then
					s *= 1 + 0.3 * math.exp(-4 * k) * math.sin(k * 14)
				else
					e.popT = nil
				end
			end
			Builder.setScale(e.info, s)

			-- Покачивание
			local yOff, tiltX, tiltZ = 0, 0, 0
			local anim = e.sp.anim
			if anim == "bounce" then
				yOff = math.abs(math.sin(tt * 2.4)) * 0.3 * s
				tiltX = math.sin(tt * 1.2) * 0.04
			elseif anim == "wobble" then
				tiltX = math.sin(tt * 4.5) * 0.07
				tiltZ = math.cos(tt * 3.7) * 0.07
			else
				tiltX = math.sin(tt * 1.3) * 0.07
				tiltZ = math.sin(tt * 0.9 + 1) * 0.06
			end
			if ready then
				yOff += math.abs(math.sin(tt * 3)) * 0.12
			end
			local root = bedTop(bed) * CFrame.new(0, yOff, 0) * CFrame.Angles(tiltX, e.yaw, tiltZ)
			Builder.collect(e.info, root, ps, cs)

			-- Свечение: мягкая пульсация, у грозовых — искры
			local light = e.info.lights[1]
			if light then
				local b = e.info.baseBrightness * (0.75 + 0.25 * math.sin(tt * 2))
				if ready then
					b *= 1.3
				end
				if (e.info.mutation == "storm" or e.sp.fx == "electric") and math.random() < 0.08 then
					b *= 2.5
				end
				light.Brightness = b
			end

			-- Радужник переливается
			if e.sp.fx == "rainbow" then
				local hue = (tt * 0.12) % 1
				for i, cap in e.info.caps do
					cap.Color = Color3.fromHSV((hue + i * 0.15) % 1, 0.55, 1)
				end
				if light then
					light.Color = Color3.fromHSV(hue, 0.4, 1)
				end
			end

			-- Частицы включаются, когда гриб подрос
			local wantFx = p > 0.6
			if e.fxOn ~= wantFx then
				e.fxOn = wantFx
				Builder.setEmitters(e.info, wantFx)
			end
		end
	end

	if #ps > 0 then
		workspace:BulkMoveTo(ps, cs, Enum.BulkMoveMode.FireCFrameChanged)
	end

	bridgeTimer += dt
	if bridgeTimer > 0.5 then
		bridgeTimer = 0
		updateBridges(now)
	end
end

function Visuals.init()
	for _, bed in CollectionService:GetTagged("Bed") do
		task.spawn(watchBed, bed)
	end
	CollectionService:GetInstanceAddedSignal("Bed"):Connect(function(bed)
		task.spawn(watchBed, bed)
	end)
	CollectionService:GetInstanceRemovedSignal("Bed"):Connect(clearEntry)
	RunService.RenderStepped:Connect(step)
end

return Visuals
