--!nonstrict
-- Собирает гриб из простых деталей (ножка + шляпка + пятна + свет + частицы).
-- Каждый вид выглядит по-своему благодаря параметрам из Species.luau.
-- Используется и сервером (декор, продавцы), и клиентом (грибы на грядках, превью в UI).

local Species = require(script.Parent.Species)

local Builder = {}

local NEON = Enum.Material.Neon
local SMOOTH = Enum.Material.SmoothPlastic
local ROT_UP = CFrame.Angles(0, 0, math.pi / 2) -- цилиндр в Roblox лежит по оси X, поворачиваем вертикально

local TEX_SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local TEX_FIRE = "rbxasset://textures/particles/fire_main.dds"

local function hashString(s: string): number
	local h = 7
	for i = 1, #s do
		h = (h * 31 + string.byte(s, i)) % 2147483647
	end
	return h
end

local function newPart(name, size, color, material, transparency, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = material or SMOOTH
	p.Color = color
	p.Transparency = transparency or 0
	if shape == "ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "cylinder" then
		p.Shape = Enum.PartType.Cylinder
	elseif shape == "ellipsoid" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Size = size
	return p
end

local function seq(a: number, b: number)
	return NumberSequence.new(a, b)
end

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.Texture = TEX_SPARKLE
	e.LightEmission = 1
	e.LightInfluence = 0
	for k, v in props do
		e[k] = v
	end
	e.Parent = parent
	return e
end

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 60)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(120, 255, 100)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 200, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(170, 100, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 100, 220)),
})

-- Эффекты частиц для каждого fx
local FX = {
	sparkle = function(att, c)
		return emitter(att, {
			Color = ColorSequence.new(c),
			Size = seq(0.18, 0),
			Rate = 3,
			Lifetime = NumberRange.new(1.2, 2.2),
			Speed = NumberRange.new(0.4, 1.2),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, 0.4, 0),
		})
	end,
	spores = function(att, c)
		return emitter(att, {
			Color = ColorSequence.new(c),
			Size = seq(0.12, 0.05),
			Rate = 4,
			Lifetime = NumberRange.new(2, 3.5),
			Speed = NumberRange.new(0.3, 0.8),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, 0.3, 0),
			Drag = 1,
		})
	end,
	embers = function(att, _c)
		return emitter(att, {
			Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 60, 20)),
			Size = seq(0.12, 0),
			Rate = 5,
			Lifetime = NumberRange.new(1, 2),
			Speed = NumberRange.new(0.5, 1.5),
			SpreadAngle = Vector2.new(60, 60),
			Acceleration = Vector3.new(0, 2, 0),
		})
	end,
	mist = function(att, c)
		return emitter(att, {
			Texture = TEX_SMOKE,
			Color = ColorSequence.new(c),
			Size = seq(1, 2.5),
			Transparency = seq(0.75, 1),
			Rate = 2,
			Lifetime = NumberRange.new(2.5, 4),
			Speed = NumberRange.new(0.2, 0.5),
			SpreadAngle = Vector2.new(180, 30),
			Acceleration = Vector3.new(0, -0.3, 0),
			LightEmission = 0.5,
		})
	end,
	snow = function(att, _c)
		return emitter(att, {
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
			Size = seq(0.12, 0.08),
			Rate = 6,
			Lifetime = NumberRange.new(1.5, 2.5),
			Speed = NumberRange.new(0.3, 0.8),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, -1.2, 0),
		})
	end,
	fire = function(att, c)
		return emitter(att, {
			Texture = TEX_FIRE,
			Color = ColorSequence.new(c, Color3.fromRGB(255, 60, 20)),
			Size = seq(0.7, 0.1),
			Transparency = seq(0.2, 1),
			Rate = 14,
			Lifetime = NumberRange.new(0.4, 0.8),
			Speed = NumberRange.new(1, 2),
			SpreadAngle = Vector2.new(15, 15),
			Acceleration = Vector3.new(0, 3, 0),
		})
	end,
	bubbles = function(att, c)
		return emitter(att, {
			Color = ColorSequence.new(c),
			Size = seq(0.22, 0.05),
			Transparency = seq(0.2, 0.8),
			Rate = 4,
			Lifetime = NumberRange.new(1.5, 2.5),
			Speed = NumberRange.new(0.5, 1),
			SpreadAngle = Vector2.new(40, 40),
			Acceleration = Vector3.new(0, 1.5, 0),
		})
	end,
	smoke = function(att, _c)
		return emitter(att, {
			Texture = TEX_SMOKE,
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
			Size = seq(0.5, 2),
			Transparency = seq(0.5, 1),
			Rate = 3,
			Lifetime = NumberRange.new(1.5, 2.5),
			Speed = NumberRange.new(1, 2),
			SpreadAngle = Vector2.new(20, 20),
			Acceleration = Vector3.new(0, 2, 0),
			LightEmission = 0.3,
		})
	end,
	dream = function(att, c)
		return emitter(att, {
			Color = ColorSequence.new(c, Color3.fromRGB(180, 140, 255)),
			Size = seq(0.25, 0),
			Rate = 3,
			Lifetime = NumberRange.new(2.5, 4),
			Speed = NumberRange.new(0.2, 0.5),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, 0.5, 0),
			RotSpeed = NumberRange.new(-90, 90),
		})
	end,
	electric = function(att, c)
		return emitter(att, {
			Color = ColorSequence.new(c, Color3.fromRGB(255, 255, 255)),
			Size = seq(0.2, 0),
			Rate = 10,
			Lifetime = NumberRange.new(0.15, 0.3),
			Speed = NumberRange.new(3, 6),
			SpreadAngle = Vector2.new(180, 180),
		})
	end,
	rainbow = function(att, _c)
		return emitter(att, {
			Color = RAINBOW,
			Size = seq(0.22, 0),
			Rate = 6,
			Lifetime = NumberRange.new(1.5, 2.5),
			Speed = NumberRange.new(0.5, 1.5),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, 0.6, 0),
		})
	end,
}

--[[
	Builder.build(speciesId, mutation, opts) -> info
	info = {
		model, species, mutation, parts = {{part, pos, rot, size}}, caps = {Part},
		lights = {PointLight}, emitters = {ParticleEmitter}, burst = ParticleEmitter,
		attachment = Attachment, glowColor, scale, baseRange, baseBrightness
	}
	Детали собраны вокруг точки (0,0,0) — это низ ножки.
	opts.eyes = true — добавить глазки (для продавцов).
]]
function Builder.build(speciesId: string, mutation: string?, opts: { [string]: any }?)
	local sp = Species.byId[speciesId] or Species.list[1]
	mutation = mutation or "none"
	opts = opts or {}
	local rng = Random.new(hashString(sp.id))

	local capColor = sp.capColor
	local glowColor = sp.glowColor
	local spotColor = sp.spotColor
	if mutation == "gold" then
		capColor = Color3.fromRGB(255, 200, 50)
		glowColor = Color3.fromRGB(255, 220, 120)
		spotColor = Color3.fromRGB(255, 250, 220)
	elseif mutation == "storm" then
		glowColor = Color3.fromRGB(120, 200, 255)
	end

	local model = Instance.new("Model")
	model.Name = sp.id

	local info = {
		model = model,
		species = sp,
		mutation = mutation,
		parts = {},
		caps = {},
		lights = {},
		emitters = {},
		glowColor = glowColor,
		scale = 1,
		baseRange = 9,
		baseBrightness = 1.4,
	}

	local function add(part, cf)
		part.CFrame = cf
		part.Parent = model
		table.insert(info.parts, { part = part, pos = cf.Position, rot = cf.Rotation, size = part.Size })
		return part
	end

	-- Невидимая опора (для PivotTo)
	local root = add(newPart("Root", Vector3.new(0.2, 0.2, 0.2), Color3.new(1, 1, 1), SMOOTH, 1), CFrame.new())
	model.PrimaryPart = root

	local h, w, S = sp.stemHeight, sp.stemWidth, sp.capSize

	-- Ножка: широкое основание + верх
	add(newPart("StemBase", Vector3.new(h * 0.5, w * 1.25, w * 1.25), sp.stemColor, SMOOTH, 0, "cylinder"), CFrame.new(0, h * 0.25, 0) * ROT_UP)
	add(newPart("Stem", Vector3.new(h * 0.75, w, w), sp.stemColor, SMOOTH, 0, "cylinder"), CFrame.new(0, h * 0.625, 0) * ROT_UP)

	-- Светящиеся пластинки под шляпкой
	add(newPart("Gills", Vector3.new(0.3, S * 0.8, S * 0.8), glowColor, NEON, 0, "cylinder"), CFrame.new(0, h + 0.05, 0) * ROT_UP)

	-- Шляпка: набор эллипсоидов {размер, центр}
	local pieces = {}
	local shape = sp.capShape
	if shape == "flat" then
		table.insert(pieces, { Vector3.new(S * 1.25, S * 0.32, S * 1.25), Vector3.new(0, h + S * 0.1, 0) })
	elseif shape == "bell" then
		table.insert(pieces, { Vector3.new(S * 0.9, S * 1.0, S * 0.9), Vector3.new(0, h + S * 0.3, 0) })
	elseif shape == "cone" then
		for k = 0, 3 do
			local sc = 1 - k * 0.24
			table.insert(pieces, { Vector3.new(S * sc, S * 0.36, S * sc), Vector3.new(0, h + 0.1 + k * S * 0.2, 0) })
		end
	elseif shape == "puff" then
		table.insert(pieces, { Vector3.new(S * 0.85, S * 0.65, S * 0.85), Vector3.new(0, h + S * 0.25, 0) })
		for k = 1, 4 do
			local a = k / 4 * math.pi * 2
			table.insert(pieces, {
				Vector3.new(S * 0.55, S * 0.45, S * 0.55),
				Vector3.new(math.cos(a) * S * 0.32, h + S * 0.12, math.sin(a) * S * 0.32),
			})
		end
	elseif shape == "double" then
		table.insert(pieces, { Vector3.new(S * 1.05, S * 0.45, S * 1.05), Vector3.new(0, h + S * 0.08, 0) })
		add(newPart("UpperStem", Vector3.new(S * 0.4, w * 0.6, w * 0.6), sp.stemColor, SMOOTH, 0, "cylinder"), CFrame.new(0, h + S * 0.35, 0) * ROT_UP)
		table.insert(pieces, { Vector3.new(S * 0.6, S * 0.42, S * 0.6), Vector3.new(0, h + S * 0.58, 0) })
	else -- dome
		table.insert(pieces, { Vector3.new(S, S * 0.62, S), Vector3.new(0, h + S * 0.14, 0) })
	end

	local capT = sp.capTransparency or 0
	for i, pc in pieces do
		local cap = add(newPart(i == 1 and "Cap" or ("Cap" .. i), pc[1], capColor, SMOOTH, capT, "ellipsoid"), CFrame.new(pc[2]))
		table.insert(info.caps, cap)
	end
	local mainCap = info.caps[1]
	local mainSize, mainCenter = pieces[1][1], pieces[1][2]

	-- Светящееся «сердечко» внутри прозрачной шляпки (Желейник)
	if capT > 0 then
		local d = S * 0.35
		add(newPart("Core", Vector3.new(d, d, d), glowColor, NEON, 0, "ball"), CFrame.new(mainCenter))
	end

	-- Пятнышки на шляпке
	local rx, ry = mainSize.X / 2, mainSize.Y / 2
	for j = 1, sp.spots do
		local theta = j / sp.spots * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local phi = rng:NextNumber(0.35, 1.05)
		local offset = Vector3.new(rx * math.sin(phi) * math.cos(theta), ry * math.cos(phi), rx * math.sin(phi) * math.sin(theta)) * 0.97
		local d = S * rng:NextNumber(0.13, 0.2)
		add(newPart("Spot", Vector3.new(d, d, d), spotColor, NEON, 0, "ball"), CFrame.new(mainCenter + offset))
	end

	-- Глазки (для продавцов-грибов)
	if opts.eyes then
		for _, side in { -1, 1 } do
			local eyeY = h * 0.72
			local white = w * 0.38
			local pupil = w * 0.2
			add(newPart("Eye", Vector3.new(white, white, white), Color3.new(1, 1, 1), SMOOTH, 0, "ball"), CFrame.new(side * w * 0.22, eyeY, -w * 0.42))
			add(newPart("Pupil", Vector3.new(pupil, pupil, pupil), Color3.fromRGB(20, 15, 30), SMOOTH, 0, "ball"), CFrame.new(side * w * 0.22, eyeY, -w * 0.58))
		end
	end

	-- Свет
	local light = Instance.new("PointLight")
	light.Color = glowColor
	light.Range = info.baseRange
	light.Brightness = info.baseBrightness
	light.Shadows = false
	light.Parent = mainCap
	table.insert(info.lights, light)

	-- Точка для частиц и «мостиков» скрещивания (ось X смотрит вверх)
	local att = Instance.new("Attachment")
	att.Name = "Fx"
	att.CFrame = CFrame.Angles(0, 0, math.pi / 2)
	att.Parent = mainCap
	info.attachment = att

	local fxMaker = FX[sp.fx] or FX.sparkle
	table.insert(info.emitters, fxMaker(att, glowColor))
	if mutation == "gold" then
		table.insert(info.emitters, FX.sparkle(att, Color3.fromRGB(255, 215, 80)))
	elseif mutation == "storm" and sp.fx ~= "electric" then
		table.insert(info.emitters, FX.electric(att, Color3.fromRGB(120, 200, 255)))
	end

	-- Вспышка частиц, когда гриб созрел (вызывается через info.burst:Emit(n))
	info.burst = emitter(att, {
		Color = ColorSequence.new(glowColor, Color3.new(1, 1, 1)),
		Size = seq(0.4, 0),
		Rate = 0,
		Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(4, 9),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
	})

	return info
end

-- Меняет размер всего гриба (s = 1 — обычный размер)
function Builder.setScale(info, s: number)
	s = math.max(s, 0.02)
	if math.abs(info.scale - s) < 0.004 then
		return
	end
	info.scale = s
	for _, e in info.parts do
		e.part.Size = e.size * s
	end
	for _, l in info.lights do
		l.Range = info.baseRange * math.max(s, 0.3)
	end
end

-- Добавляет детали и их CFrame в списки (для одного быстрого workspace:BulkMoveTo)
function Builder.collect(info, rootCF: CFrame, partsOut, cframesOut)
	local s = info.scale
	for _, e in info.parts do
		partsOut[#partsOut + 1] = e.part
		cframesOut[#cframesOut + 1] = rootCF * CFrame.new(e.pos * s) * e.rot
	end
end

-- Ставит гриб в точку rootCF (низ ножки). Модель должна быть в workspace.
function Builder.place(info, rootCF: CFrame)
	local ps, cs = {}, {}
	Builder.collect(info, rootCF, ps, cs)
	workspace:BulkMoveTo(ps, cs, Enum.BulkMoveMode.FireCFrameChanged)
end

function Builder.setEmitters(info, enabled: boolean)
	for _, em in info.emitters do
		em.Enabled = enabled
	end
end

-- Высота гриба при scale = 1 (для камеры превью)
function Builder.height(sp): number
	return sp.stemHeight + sp.capSize * 0.9
end

return Builder
