--[[=========================================================================
	МОРЕ ЗА КЛУБАМИ: набережная с фонарями и гуляющими людьми,
	луна с лунной дорожкой, светящийся круизный лайнер и яхты.
	Смотровая башня с лестницей на крышу и парашютом.
==========================================================================]]

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local terrain      = workspace.Terrain
local templates    = game:GetService("ServerStorage"):FindFirstChild("Шаблоны")

local GROUND = -4
local SHORE_Z = -100          -- набережная
local rng = Random.new(4242)

-- Звуки (загрузит VLA2music): чайки и разговоры людей на набережной
local SOUND_GULLS  = ""
local SOUND_CROWD  = ""

local sea = Instance.new("Folder")
sea.Name = "Море"
sea.Parent = workspace

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do p[k] = v end
	p.Parent = props.Parent or sea
	return p
end

-- ждём, пока World.server.lua насыплет газон, иначе он закроет воду
while not workspace:GetAttribute("WorldReady") do task.wait(0.5) end

--=========================================================================
-- Вода
--=========================================================================
-- большими блоками Terrain заполняет не всё, поэтому кусками 200x200.
-- Заливаем дважды: газон мира иногда досыпается позже и закрывает воду.
local function fillSea()
	for x = -1200, 2400, 200 do
		for z = -1700, -300, 200 do   -- до z = -100 (набережная)
			terrain:FillBlock(CFrame.new(x + 100, GROUND + 18, z + 100), Vector3.new(200, 48, 200), Enum.Material.Air)
			terrain:FillBlock(CFrame.new(x + 100, GROUND - 12, z + 100), Vector3.new(200, 16, 200), Enum.Material.Water)
			terrain:FillBlock(CFrame.new(x + 100, GROUND - 22, z + 100), Vector3.new(200, 4, 200), Enum.Material.Sand)
		end
		task.wait()
	end
end
fillSea()
task.delay(10, fillSea)
terrain.WaterColor = Color3.fromRGB(20, 45, 90)
terrain.WaterReflectance = 0.8
terrain.WaterTransparency = 0.3
terrain.WaterWaveSize = 0.35
terrain.WaterWaveSpeed = 8

--=========================================================================
-- Луна и лунная дорожка
--=========================================================================
local moon = part({ Name = "Луна", Shape = Enum.PartType.Ball, Size = Vector3.new(160, 160, 160),
	Position = Vector3.new(600, 420, -2600), Color = Color3.fromRGB(255, 250, 225), Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
local moonLight = Instance.new("PointLight") moonLight.Range = 60 moonLight.Color = moon.Color moonLight.Parent = moon
for k = 0, 14 do   -- мерцающая дорожка от горизонта к берегу
	local z = SHORE_Z - 60 - k * 85
	local w = 6 + k * 2
	local strip = part({ Size = Vector3.new(w, 0.1, 18), Position = Vector3.new(600 + rng:NextNumber(-6, 6), GROUND - 0.15, z),
		Color = Color3.fromRGB(255, 245, 200), Material = Enum.Material.Neon, Transparency = 0.8 + k * 0.01, CanCollide = false, CastShadow = false })
	strip:SetAttribute("MoonGlint", true)
end

--=========================================================================
-- Набережная: плитка, парапет, фонари, скамейки
-- Плитка на 1 выше газона, иначе они мерцают на одном уровне.
--=========================================================================
local X1, X2 = -150, 1350
part({ Size = Vector3.new(X2 - X1, 3, 18), Position = Vector3.new((X1 + X2) / 2, GROUND + 1.5, SHORE_Z), Color = Color3.fromRGB(190, 180, 165), Material = Enum.Material.Pavement })
part({ Size = Vector3.new(X2 - X1, 10, 3), Position = Vector3.new((X1 + X2) / 2, GROUND - 4, SHORE_Z - 10), Color = Color3.fromRGB(120, 115, 110), Material = Enum.Material.Cobblestone })
part({ Size = Vector3.new(X2 - X1, 0.6, 0.6), Position = Vector3.new((X1 + X2) / 2, GROUND + 6, SHORE_Z - 8.5), Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Metal })
for x = X1, X2, 6 do
	part({ Size = Vector3.new(0.4, 3, 0.4), Position = Vector3.new(x, GROUND + 4.5, SHORE_Z - 8.5), Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Metal })
end
for x = X1 + 20, X2 - 20, 40 do
	part({ Size = Vector3.new(0.6, 13, 0.6), Position = Vector3.new(x, GROUND + 9.5, SHORE_Z - 6.5), Color = Color3.fromRGB(30, 30, 40), Material = Enum.Material.Metal })
	local lamp = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), Position = Vector3.new(x, GROUND + 16.5, SHORE_Z - 6.5), Color = Color3.fromRGB(255, 220, 150), Material = Enum.Material.Neon })
	local l = Instance.new("PointLight") l.Range = 28 l.Brightness = 1.6 l.Color = lamp.Color l.Parent = lamp
	-- скамейка между фонарями
	local bx = x + 20
	part({ Size = Vector3.new(6, 0.5, 2), Position = Vector3.new(bx, GROUND + 4.2, SHORE_Z + 6), Color = Color3.fromRGB(120, 75, 40), Material = Enum.Material.Wood })
	part({ Size = Vector3.new(6, 2, 0.4), Position = Vector3.new(bx, GROUND + 5.4, SHORE_Z + 7), Color = Color3.fromRGB(120, 75, 40), Material = Enum.Material.Wood })
end

-- звук: разговоры людей и чайки вдоль набережной
local function ambient(id, vol)
	if id == "" then return end
	for x = X1 + 100, X2 - 100, 300 do
		local p = part({ Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, Position = Vector3.new(x, GROUND + 6, SHORE_Z) })
		local s = Instance.new("Sound") s.SoundId = id s.Looped = true s.Volume = vol
		s.RollOffMinDistance = 30 s.RollOffMaxDistance = 160 s.Parent = p s:Play()
	end
end
ambient(SOUND_CROWD, 0.5)
ambient(SOUND_GULLS, 0.4)

-- гуляющие люди
local ANIM_WALK = "rbxassetid://507777826"
local function walker(z, x1, x2, speed)
	local ok, npc = pcall(function()
		local d = Instance.new("HumanoidDescription")
		local skin = ({ Color3.fromRGB(234, 184, 146), Color3.fromRGB(198, 140, 100), Color3.fromRGB(141, 85, 56) })[rng:NextInteger(1, 3)]
		d.HeadColor, d.LeftArmColor, d.RightArmColor = skin, skin, skin
		d.TorsoColor = Color3.fromHSV(rng:NextNumber(), 0.6, 0.95)
		local legs = Color3.fromHSV(rng:NextNumber(), 0.3, 0.35)
		d.LeftLegColor, d.RightLegColor = legs, legs
		return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	end)
	if not ok then return end
	npc.Name = "Гуляющий"
	npc.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	for _, d in ipairs(npc:GetDescendants()) do if d:IsA("BasePart") then d.CanCollide = false end end
	local root = npc.HumanoidRootPart
	root.Anchored = true
	local y = GROUND + 3 + npc.Humanoid.HipHeight + root.Size.Y / 2
	local a, b = Vector3.new(x1, y, z), Vector3.new(x2, y, z)
	npc:PivotTo(CFrame.new(a))
	npc.Parent = sea
	local anim = Instance.new("Animation") anim.AnimationId = ANIM_WALK
	local tr = npc.Humanoid:WaitForChild("Animator"):LoadAnimation(anim) tr.Looped = true tr:Play()
	task.spawn(function()
		local from, to = a, b
		while npc.Parent do
			root.CFrame = CFrame.lookAt(from, to)
			local tw = TweenService:Create(root, TweenInfo.new((to - from).Magnitude / speed, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(to, to + (to - from).Unit) })
			tw:Play() tw.Completed:Wait()
			from, to = to, from
		end
	end)
end
for i = 1, 12 do
	local x1 = rng:NextInteger(X1 + 10, X2 - 250)
	walker(SHORE_Z + rng:NextNumber(-4, 4), x1, x1 + rng:NextInteger(120, 250), rng:NextNumber(4, 6.5))
end

--=========================================================================
-- Круизный лайнер и яхты (лёгкое покачивание)
--=========================================================================
local function glowWindows(model, colors)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and (d.Material == Enum.Material.Glass or d.Name:lower():find("window")) then
			d.Material = Enum.Material.Neon
			d.Color = colors[rng:NextInteger(1, #colors)]
		end
	end
end
local function light(model, color, range)
	local body = model:FindFirstChildWhichIsA("BasePart", true)
	if not body then return end
	local l = Instance.new("PointLight") l.Color = color l.Range = range l.Brightness = 3 l.Parent = body
end
local function stringLights(cf, length, height, count)
	-- гирлянда разноцветных огней вдоль корпуса
	for k = 0, count - 1 do
		local t = k / (count - 1) - 0.5
		part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = cf * CFrame.new(t * length, height + math.sin(k) * 0.3, 0),
			Color = Color3.fromHSV(k / count, 0.6, 1), Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
	end
end

local floaters = {}
local function place(name, cf, windowColors, glow)
	local tpl = templates and templates:FindFirstChild(name)
	if not tpl then return end
	local m = tpl:Clone()
	m:PivotTo(cf)
	m:SetAttribute("Ship", name)   -- сундук на палубу ставит Rooftops.server.lua
	m.Parent = sea
	glowWindows(m, windowColors)
	light(m, glow, 120)
	local _, size = m:GetBoundingBox()
	stringLights(cf * CFrame.new(0, 0, 0), size.X * 0.9, size.Y * 0.75, math.floor(size.X / 6))
	table.insert(floaters, { model = m, base = cf, phase = rng:NextNumber(0, 6) })
end
local WATER_Y = GROUND - 9   -- корпус наполовину в воде
place("cruise", CFrame.new(650, WATER_Y - 12, -520) * CFrame.Angles(0, math.rad(8), 0), { Color3.fromRGB(255, 230, 150), Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 220, 255) }, Color3.fromRGB(255, 230, 170))
place("yacht", CFrame.new(150, WATER_Y, -260) * CFrame.Angles(0, math.rad(-20), 0), { Color3.fromRGB(80, 220, 255) }, Color3.fromRGB(80, 200, 255))
place("yacht", CFrame.new(1100, WATER_Y, -300) * CFrame.Angles(0, math.rad(160), 0), { Color3.fromRGB(255, 80, 200) }, Color3.fromRGB(255, 90, 200))

task.spawn(function()
	while true do
		local t = os.clock()
		for _, f in ipairs(floaters) do
			f.model:PivotTo(f.base * CFrame.new(0, math.sin(t * 0.6 + f.phase) * 0.4, 0) * CFrame.Angles(math.sin(t * 0.5 + f.phase) * 0.01, 0, math.sin(t * 0.4 + f.phase) * 0.015))
		end
		task.wait(0.1)
	end
end)

--=========================================================================
-- Смотровая башня: винтовая лестница снаружи до крыши, на крыше парашют
--=========================================================================
local TX, TZ, TH, TW = 1010, 270, 120, 26
local towerBase = Vector3.new(TX, GROUND, TZ)
part({ Name = "СмотроваяБашня", Size = Vector3.new(TW, TH, TW), Position = towerBase + Vector3.new(0, TH / 2, 0), Color = Color3.fromRGB(30, 28, 45), Material = Enum.Material.Glass, Reflectance = 0.1 })
for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
	part({ Size = Vector3.new(0.7, TH, 0.7), Position = towerBase + Vector3.new(c[1] * TW / 2, TH / 2, c[2] * TW / 2), Color = Color3.fromRGB(60, 255, 140), Material = Enum.Material.Neon, CanCollide = false })
end
for y = 8, TH - 4, 7 do   -- окна
	part({ Size = Vector3.new(TW + 0.3, 1.5, TW + 0.3), Position = towerBase + Vector3.new(0, y, 0), Color = Color3.fromRGB(255, 225, 150), Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.2 })
end
-- крыша-смотровая площадка с перилами
local roofY = GROUND + TH
part({ Size = Vector3.new(TW + 10, 1, TW + 10), Position = Vector3.new(TX, roofY + 0.5, TZ), Color = Color3.fromRGB(70, 70, 85), Material = Enum.Material.DiamondPlate })
for _, e in ipairs({ { 0, (TW + 10) / 2, TW + 10, 0.4 }, { 0, -(TW + 10) / 2, TW + 10, 0.4 }, { (TW + 10) / 2, 0, 0.4, TW + 10 }, { -(TW + 10) / 2, 0, 0.4, TW + 10 } }) do
	part({ Size = Vector3.new(e[3], 3.5, e[4]), Position = Vector3.new(TX + e[1], roofY + 2.5, TZ + e[2]), Color = Color3.fromRGB(120, 220, 255), Material = Enum.Material.Glass, Transparency = 0.5 })
end
-- винтовая лестница: пандус по периметру, 6 витков
local R = TW / 2 + 4          -- расстояние от центра до середины лестницы
local LAPS, STEPS_PER_SIDE = 6, 3
local rise = TH / (LAPS * 4 * STEPS_PER_SIDE)
local corners = { Vector3.new(-R, 0, -R), Vector3.new(R, 0, -R), Vector3.new(R, 0, R), Vector3.new(-R, 0, R) }
local h = 0
for lap = 1, LAPS do
	for side = 1, 4 do
		local a, b = corners[side], corners[side % 4 + 1]
		for k = 0, STEPS_PER_SIDE - 1 do
			local p1 = towerBase + a:Lerp(b, k / STEPS_PER_SIDE) + Vector3.new(0, h, 0)
			h += rise
			local p2 = towerBase + a:Lerp(b, (k + 1) / STEPS_PER_SIDE) + Vector3.new(0, h, 0)
			part({ Size = Vector3.new(7, 1, (p2 - p1).Magnitude + 0.6), CFrame = CFrame.lookAt((p1 + p2) / 2, p2), Color = Color3.fromRGB(150, 150, 165), Material = Enum.Material.Concrete })
		end
		-- угловая площадка
		local c = towerBase + b + Vector3.new(0, h, 0)
		part({ Size = Vector3.new(7.5, 1, 7.5), Position = c, Color = Color3.fromRGB(150, 150, 165), Material = Enum.Material.Concrete })
	end
end
-- с последней площадки на крышу
part({ Size = Vector3.new(7, 1, 10), CFrame = CFrame.lookAt(towerBase + corners[1] + Vector3.new(2, h + 0.5, 4), Vector3.new(TX, roofY + 1, TZ)), Color = Color3.fromRGB(150, 150, 165), Material = Enum.Material.Concrete })
local sign = part({ Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, Position = towerBase + Vector3.new(0, 10, -R - 4) })
local bg = Instance.new("BillboardGui") bg.Size = UDim2.new(0, 240, 0, 50) bg.AlwaysOnTop = false bg.Parent = sign
local bl = Instance.new("TextLabel") bl.Size = UDim2.fromScale(1, 1) bl.BackgroundTransparency = 1 bl.Font = Enum.Font.GothamBlack
bl.TextScaled = true bl.Text = "🗼 VIEW TOWER ↑" bl.TextColor3 = Color3.fromRGB(120, 255, 170) bl.Parent = bg

-- парашют на крыше
local rack = part({ Name = "Парашют", Size = Vector3.new(3, 4, 2), Position = Vector3.new(TX + 8, roofY + 3, TZ), Color = Color3.fromRGB(230, 70, 60), Material = Enum.Material.Fabric })
local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "Take parachute"
prompt.ObjectText = "🪂"
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 10
prompt.Parent = rack
prompt.Triggered:Connect(function(player)
	-- каждый раз новое число, чтобы клиент заметил и повторное взятие
	player:SetAttribute("Parachute", (player:GetAttribute("Parachute") or 0) + 1)
end)

workspace:SetAttribute("SeaReady", true)
print("[Море] Набережная, лайнер, яхты и башня готовы")
