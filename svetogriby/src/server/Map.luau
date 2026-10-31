--!nonstrict
-- Генерирует подземный мир: центральный зал, лавки продавцов и 6 пещер-ферм.
-- Свои украшения клади в Workspace в папку "Decor" — скрипт их не трогает.
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Builder = require(ReplicatedStorage.Shared.MushroomBuilder)

local Map = {}

local HUB_RADIUS = 44
local PLOT_DISTANCE = 96
local PLOT_RADIUS = 28
local HEIGHT = 40

local rng = Random.new(7)

local CRYSTAL_COLORS = {
	Color3.fromRGB(110, 230, 255),
	Color3.fromRGB(190, 110, 255),
	Color3.fromRGB(255, 120, 220),
	Color3.fromRGB(120, 255, 180),
}
local DECOR_SPECIES = { "glow_blue", "glow_sun", "glow_moss", "glow_ember", "glow_violet", "glow_mint" }

local function newPart(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function surfaceText(part, text, color, face)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Brightness = 2
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Color = Color3.fromRGB(20, 10, 40)
	st.Parent = label
	gui.Parent = part
	return label
end

local function setupLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 0
	Lighting.Ambient = Color3.fromRGB(34, 26, 58)
	Lighting.OutdoorAmbient = Color3.fromRGB(36, 28, 62)
	Lighting.EnvironmentDiffuseScale = 0.2
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	for _, c in Lighting:GetChildren() do
		if c:IsA("Atmosphere") or c:IsA("PostEffect") then
			c:Destroy()
		end
	end
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 1.1
	bloom.Size = 28
	bloom.Threshold = 0.85
	bloom.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "Mood"
	cc.Saturation = 0.15
	cc.Contrast = 0.08
	cc.TintColor = Color3.fromRGB(240, 235, 255)
	cc.Parent = Lighting
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.36
	atm.Offset = 0
	atm.Color = Color3.fromRGB(70, 45, 120)
	atm.Decay = Color3.fromRGB(25, 12, 50)
	atm.Glare = 0
	atm.Haze = 1.5
	atm.Parent = Lighting
end

local function buildTerrain(plotAngles)
	local terrain = workspace.Terrain
	terrain:Clear()
	terrain:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(72, 62, 98))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(78, 58, 62))

	local extent = (PLOT_DISTANCE + PLOT_RADIUS + 24) * 2
	terrain:FillBlock(CFrame.new(0, 20, 0), Vector3.new(extent, 100, extent), Enum.Material.Slate)

	local AIR = Enum.Material.Air
	-- Центральный зал
	terrain:FillCylinder(CFrame.new(0, HEIGHT / 2, 0), HEIGHT, HUB_RADIUS, AIR)
	terrain:FillBall(Vector3.new(0, HEIGHT - 10, 0), HUB_RADIUS * 0.7, AIR)

	for _, angle in plotAngles do
		local c = Vector3.new(math.cos(angle) * PLOT_DISTANCE, 0, math.sin(angle) * PLOT_DISTANCE)
		-- Пещера
		terrain:FillCylinder(CFrame.new(c.X, HEIGHT * 0.4, c.Z), HEIGHT * 0.8, PLOT_RADIUS, AIR)
		terrain:FillBall(Vector3.new(c.X, HEIGHT * 0.6, c.Z), PLOT_RADIUS * 0.8, AIR)
		-- Земляной пол в пещере
		terrain:FillCylinder(CFrame.new(c.X, -2, c.Z), 4, PLOT_RADIUS - 2, Enum.Material.Ground)
		-- Туннель до зала
		local mid = c / 2
		terrain:FillBlock(CFrame.lookAt(Vector3.new(mid.X, 9, mid.Z), Vector3.new(c.X, 9, c.Z)), Vector3.new(14, 18, PLOT_DISTANCE), AIR)
	end
end

local function crystalCluster(parent, pos: Vector3, color: Color3, scale: number, withLight: boolean)
	local m = Instance.new("Model")
	m.Name = "Crystals"
	m.Parent = parent
	local first
	for _ = 1, rng:NextInteger(3, 5) do
		local h = rng:NextNumber(3, 8) * scale
		local w = rng:NextNumber(0.8, 1.6) * scale
		local tilt = CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.5, 0.5))
		local p = newPart(m, {
			Name = "Crystal",
			Size = Vector3.new(w, h, w),
			CFrame = CFrame.new(pos) * tilt * CFrame.new(0, h / 2 - 0.5, 0),
			Material = Enum.Material.Neon,
			Color = color,
			Transparency = 0.15,
			CanCollide = false,
			CastShadow = false,
		})
		first = first or p
	end
	if withLight and first then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 16
		light.Brightness = 1.2
		light.Shadows = false
		light.Parent = first
	end
end

local function decorMushroom(parent, pos: Vector3, scale: number, withLight: boolean)
	local info = Builder.build(DECOR_SPECIES[rng:NextInteger(1, #DECOR_SPECIES)], "none")
	if not withLight then
		for _, l in info.lights do
			l:Destroy()
		end
	end
	Builder.setScale(info, scale)
	info.model.Parent = parent
	Builder.place(info, CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.15, 0.15)))
end

-- Угол свободен от туннелей и лавок?
local function freeAngle(deg: number): boolean
	deg = deg % 360
	for k = 0, Config.PLOT_COUNT - 1 do
		local tunnel = (30 + k * 360 / Config.PLOT_COUNT) % 360
		local diff = math.abs(((deg - tunnel) + 180) % 360 - 180)
		if diff < 14 then
			return false
		end
	end
	for _, stall in { 0, 180 } do
		local diff = math.abs(((deg - stall) + 180) % 360 - 180)
		if diff < 16 then
			return false
		end
	end
	return true
end

local function buildStall(parent, cf: CFrame, title: string, actionText: string, color: Color3, keeperSpecies: string)
	local m = Instance.new("Model")
	m.Name = title
	m.Parent = parent
	local wood = Color3.fromRGB(110, 75, 50)
	local counter = newPart(m, {
		Name = "Counter",
		Size = Vector3.new(10, 3, 3),
		CFrame = cf * CFrame.new(0, 1.5, 0),
		Material = Enum.Material.WoodPlanks,
		Color = wood,
	})
	for _, x in { -4.6, 4.6 } do
		newPart(m, {
			Name = "Post",
			Size = Vector3.new(0.8, 9, 0.8),
			CFrame = cf * CFrame.new(x, 4.5, 3),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(90, 60, 40),
		})
	end
	newPart(m, {
		Name = "Roof",
		Size = Vector3.new(12, 0.6, 7),
		CFrame = cf * CFrame.new(0, 9.4, 1) * CFrame.Angles(math.rad(14), 0, 0),
		Material = Enum.Material.Fabric,
		Color = color,
	})
	local sign = newPart(m, {
		Name = "Sign",
		Size = Vector3.new(9, 1.8, 0.3),
		CFrame = cf * CFrame.new(0, 8.2, -1.6),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(55, 35, 30),
	})
	surfaceText(sign, title, color)
	local lamp = Instance.new("PointLight")
	lamp.Color = color
	lamp.Range = 18
	lamp.Brightness = 1.5
	lamp.Parent = sign

	-- Продавец — гриб с глазками
	local keeper = Builder.build(keeperSpecies, "none", { eyes = true })
	Builder.setScale(keeper, 1.8)
	keeper.model.Name = "Keeper"
	keeper.model.Parent = m
	Builder.place(keeper, cf * CFrame.new(0, 0, 2.6))

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = actionText
	prompt.ObjectText = title
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = counter
	return prompt
end

local function buildPlot(parent, index: number, angle: number)
	local center = Vector3.new(math.cos(angle) * PLOT_DISTANCE, 0, math.sin(angle) * PLOT_DISTANCE)
	local cf = CFrame.lookAt(center, Vector3.new(0, 0, 0)) -- «вперёд» (-Z) смотрит на центральный зал

	local plot = Instance.new("Model")
	plot.Name = "Plot" .. index
	plot:SetAttribute("OwnerId", 0)
	plot:SetAttribute("Index", index)
	plot.Parent = parent

	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = plot
	local beds = Instance.new("Folder")
	beds.Name = "Beds"
	beds.Parent = plot

	local cols = Config.BED_COLS
	local rows = math.ceil(Config.TOTAL_BEDS / cols)
	local spacing = 8.5
	local woodColor = Color3.fromRGB(125, 88, 62)
	for i = 1, Config.TOTAL_BEDS do
		local r = (i - 1) // cols
		local c = (i - 1) % cols
		local x = (c - (cols - 1) / 2) * spacing
		local z = (r - (rows - 1) / 2) * spacing + 3
		local bedCF = cf * CFrame.new(x, 0.6, z)
		local bed = newPart(beds, {
			Name = "Bed" .. i,
			Size = Vector3.new(6, 1.2, 6),
			CFrame = bedCF,
			Material = Enum.Material.Ground,
			Color = Color3.fromRGB(78, 52, 42),
		})
		bed:SetAttribute("Index", i)
		bed:SetAttribute("Species", "")
		bed:SetAttribute("PlantedAt", 0)
		bed:SetAttribute("GrowTime", 0)
		bed:SetAttribute("Mutation", "none")
		bed:SetAttribute("Ready", false)
		bed:SetAttribute("Unlocked", false)
		CollectionService:AddTag(bed, "Bed")

		-- Деревянная рамка
		for _, b in {
			{ Vector3.new(6.9, 1.5, 0.5), Vector3.new(0, 0.15, 3.2) },
			{ Vector3.new(6.9, 1.5, 0.5), Vector3.new(0, 0.15, -3.2) },
			{ Vector3.new(0.5, 1.5, 6.9), Vector3.new(3.2, 0.15, 0) },
			{ Vector3.new(0.5, 1.5, 6.9), Vector3.new(-3.2, 0.15, 0) },
		} do
			newPart(decor, {
				Name = "Board",
				Size = b[1],
				CFrame = bedCF * CFrame.new(b[2]),
				Material = Enum.Material.WoodPlanks,
				Color = woodColor,
			})
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Prompt"
		prompt.ActionText = "Посадить"
		prompt.ObjectText = "Грядка"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt.Parent = bed

		local lock = Instance.new("BillboardGui")
		lock.Name = "Lock"
		lock.Size = UDim2.fromOffset(110, 40)
		lock.StudsOffset = Vector3.new(0, 2.5, 0)
		lock.MaxDistance = 45
		lock.LightInfluence = 0
		local lockText = Instance.new("TextLabel")
		lockText.BackgroundTransparency = 1
		lockText.Size = UDim2.fromScale(1, 1)
		lockText.Font = Enum.Font.FredokaOne
		lockText.TextScaled = true
		lockText.TextColor3 = Color3.fromRGB(255, 210, 80)
		lockText.Text = "🔒 " .. tostring(Config.BED_PRICES[i] or 0) .. " 🪙"
		lockText.Parent = lock
		lock.Parent = bed
	end

	-- Табличка с именем владельца
	local sign = newPart(plot, {
		Name = "Sign",
		Size = Vector3.new(14, 3, 0.4),
		CFrame = cf * CFrame.new(0, 9, -(PLOT_RADIUS - 5)),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(55, 35, 30),
	})
	surfaceText(sign, "Свободная пещера", Color3.fromRGB(150, 235, 255))
	surfaceText(sign, "Свободная пещера", Color3.fromRGB(150, 235, 255), Enum.NormalId.Back)

	-- Точка появления игрока (смотрит на грядки)
	local homePos = (cf * CFrame.new(0, 1, -(PLOT_RADIUS - 10))).Position
	newPart(plot, {
		Name = "Home",
		Size = Vector3.new(2, 1, 2),
		CFrame = CFrame.lookAt(homePos, Vector3.new(center.X, homePos.Y, center.Z)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})

	-- Украшения пещеры: кристаллы и грибы вдоль задней стены
	for k = 1, 5 do
		local a = math.rad(-150 + k * 50) -- задняя полуокружность (+Z — от зала)
		local r = PLOT_RADIUS - rng:NextNumber(3, 5)
		local local_ = Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
		crystalCluster(decor, (cf * CFrame.new(local_)).Position, CRYSTAL_COLORS[rng:NextInteger(1, #CRYSTAL_COLORS)], rng:NextNumber(0.8, 1.3), k % 2 == 1)
	end
	for k = 1, 6 do
		local a = math.rad(-160 + k * 46 + rng:NextNumber(-8, 8))
		local r = PLOT_RADIUS - rng:NextNumber(5, 8)
		local local_ = Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
		decorMushroom(decor, (cf * CFrame.new(local_)).Position, rng:NextNumber(1, 2.2), false)
	end

	return plot
end

function Map.build()
	-- Убираем стандартную плиту и точки появления из шаблона Baseplate
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	for _, child in workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = "Map"
	folder.Parent = workspace

	setupLighting()

	local plotAngles = {}
	for i = 1, Config.PLOT_COUNT do
		plotAngles[i] = math.rad(30 + (i - 1) * 360 / Config.PLOT_COUNT)
	end
	buildTerrain(plotAngles)

	-- Точка появления
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 0.5, 16)
	spawn.Material = Enum.Material.Neon
	spawn.Color = Color3.fromRGB(120, 230, 255)
	spawn.Transparency = 0.4
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = folder

	-- Статуя в центре зала
	local pedestal = newPart(folder, {
		Name = "Pedestal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 14, 14),
		CFrame = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(90, 80, 120),
	})
	local statue = Builder.build("glow_violet", "none")
	Builder.setScale(statue, 5)
	statue.model.Name = "Statue"
	statue.model.Parent = folder
	statue.lights[1].Range = 40
	statue.lights[1].Brightness = 2
	Builder.place(statue, CFrame.new(0, pedestal.Position.Y + 1, 0))
	for _, e in statue.parts do
		if e.part.Name == "Stem" or e.part.Name == "StemBase" then
			e.part.CanCollide = true
		end
	end

	-- Лавки
	local shopPos = Vector3.new(30, 0, 0)
	local sellPos = Vector3.new(-30, 0, 0)
	local shopPrompt = buildStall(folder, CFrame.lookAt(shopPos, Vector3.zero), "🍄 Споровщик", "Купить споры", Color3.fromRGB(120, 230, 255), "glow_blue")
	local sellPrompt = buildStall(folder, CFrame.lookAt(sellPos, Vector3.zero), "💰 Скупщик", "Продать грибы", Color3.fromRGB(255, 205, 70), "glow_ember")

	-- Украшения зала
	local hubDecor = Instance.new("Folder")
	hubDecor.Name = "HubDecor"
	hubDecor.Parent = folder
	local placed = 0
	for deg = 0, 359, 12 do
		if freeAngle(deg) then
			local a = math.rad(deg + rng:NextNumber(-4, 4))
			local r = HUB_RADIUS - rng:NextNumber(3, 7)
			local pos = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			placed += 1
			if placed % 2 == 0 then
				crystalCluster(hubDecor, pos, CRYSTAL_COLORS[rng:NextInteger(1, #CRYSTAL_COLORS)], rng:NextNumber(1, 1.8), placed % 4 == 0)
			else
				decorMushroom(hubDecor, pos, rng:NextNumber(1.5, 3), placed % 3 == 1)
			end
		end
	end

	local plots = {}
	for i, angle in plotAngles do
		plots[i] = buildPlot(folder, i, angle)
	end

	return {
		plots = plots,
		shopPrompt = shopPrompt,
		sellPrompt = sellPrompt,
	}
end

return Map
