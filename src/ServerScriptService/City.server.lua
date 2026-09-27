--[[=========================================================================
	ГОРОД ПЕРЕД КЛУБАМИ
	Быстрая дорожка вдоль всех участков, город с небоскрёбами,
	колесо обозрения и американские горки, таблицы рекордов.
	Крутят колесо и катают вагончик — Rides.client.lua (у каждого игрока).
==========================================================================]]

local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")

local GROUND = -4          -- верх газона
local rng = Random.new(777)

local city = Instance.new("Folder")
city.Name = "Город"
city.Parent = workspace

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do p[k] = v end
	p.Parent = props.Parent or city
	return p
end

--=========================================================================
-- Быстрая дорожка: встал на неё — бежишь в 3 раза быстрее
--=========================================================================

-- Движущаяся дорожка-петля: к последнему клубу по ближней ленте,
-- обратно по дальней, на концах — разворот по кругу.
local PATH_Z = 100
local X1, X2 = -110, 1310
local BELT_SPEED = 30
local LANE = 10           -- ширина ленты
local GAP = 12            -- расстояние между центрами лент
-- Persistent: всё, что двигает Rides.client.lua, приходит игроку целиком
-- сразу (иначе при загрузке мира по частям колесо, горки и лента ломаются)
local belts = Instance.new("Model")
belts.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
belts.Name = "Лента"
belts.Parent = city

local function belt(cf, length, dir, color)
	local b = part({
		Parent = belts, Size = Vector3.new(length, 1, LANE), CFrame = cf,
		Color = color, Material = Enum.Material.SmoothPlastic,
	})
	b.AssemblyLinearVelocity = dir * BELT_SPEED
	b:SetAttribute("Vel", dir * BELT_SPEED)   -- клиент тоже ставит скорость ленте (физика персонажа у клиента)
	return b
end

local zNear, zFar = PATH_Z - GAP / 2, PATH_Z + GAP / 2
local y = GROUND + 2.5   -- газон террейна «вспухает» примерно до -2, лента должна быть выше
belt(CFrame.new((X1 + X2) / 2, y, zNear), X2 - X1, Vector3.new(1, 0, 0), Color3.fromRGB(40, 190, 255))
belt(CFrame.new((X1 + X2) / 2, y, zFar), X2 - X1, Vector3.new(-1, 0, 0), Color3.fromRGB(255, 120, 60))
-- бегущие стрелки на лентах (двигает их Rides.client.lua)
local chevrons = Instance.new("Folder")
chevrons.Name = "Стрелки"
chevrons.Parent = belts
for _, lane in ipairs({ { zNear, 1 }, { zFar, -1 } }) do
	for x = X1 + 10, X2 - 10, 24 do
		local c = part({
			Parent = chevrons, Size = Vector3.new(3, 0.12, 6), CanCollide = false, CanQuery = false, CanTouch = false,
			CFrame = CFrame.new(x, y + 0.56, lane[1]), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Neon,
		})
		c:SetAttribute("Dir", lane[2])
		c:SetAttribute("X0", x)
	end
end
chevrons:SetAttribute("X1", X1 + 10)
chevrons:SetAttribute("X2", X2 - 10)
chevrons:SetAttribute("Speed", BELT_SPEED)

-- развороты: полукруг из коротких кусочков ленты, каждый толкает по касательной
for _, e in ipairs({ { X2, 1 }, { X1, -1 } }) do
	local cx, side = e[1], e[2]
	local R = GAP / 2                 -- радиус по центру ленты
	local n = 18
	for k = 0, n - 1 do
		local a = (k + 0.5) / n * math.pi
		local center = Vector3.new(cx + side * math.sin(a) * R, y, PATH_Z - math.cos(a) * R)
		-- направление движения: на X2 от ближней к дальней, на X1 наоборот
		local tangent = Vector3.new(side * math.cos(a), 0, math.sin(a)) * (side > 0 and 1 or -1)
		local b = part({
			Parent = belts, Size = Vector3.new(LANE, 1, (R + LANE / 2) * math.pi / n + 1.2),
			CFrame = CFrame.lookAt(center, center + tangent),
			Color = Color3.fromRGB(40, 190, 255):Lerp(Color3.fromRGB(255, 120, 60), side > 0 and k / n or 1 - k / n),
		})
		b.AssemblyLinearVelocity = tangent * BELT_SPEED
		b:SetAttribute("Vel", tangent * BELT_SPEED)
		-- внешний бортик
		local rim = Vector3.new(cx + side * math.sin(a) * (R + LANE / 2 + 0.4), y + 0.8, PATH_Z - math.cos(a) * (R + LANE / 2 + 0.4))
		part({ Size = Vector3.new(0.6, 1.6, (R + LANE) * math.pi / n + 0.6), CFrame = CFrame.lookAt(rim, rim + tangent), Color = Color3.fromRGB(230, 230, 240), Material = Enum.Material.Metal })
	end
end

-- бортики и надпись
for _, z in ipairs({ PATH_Z - GAP / 2 - LANE / 2 - 0.3, PATH_Z + GAP / 2 + LANE / 2 + 0.3 }) do
	part({ Size = Vector3.new(X2 - X1, 1.6, 0.6), Position = Vector3.new((X1 + X2) / 2, y + 0.8, z), Color = Color3.fromRGB(230, 230, 240), Material = Enum.Material.Metal })
end
-- ступеньки от каждого участка вниз к дорожке
for i = 0, 5 do
	local x = i * 240
	for step = 0, 3 do
		part({
			Size = Vector3.new(14, 1.25, 3),
			Position = Vector3.new(x, GROUND + 4.4 - step * 1.25, 71.5 + step * 3),
			Color = Color3.fromRGB(150, 140, 170), Material = Enum.Material.Concrete,
		})
	end
end

--=========================================================================
-- Неоновый киберквартал: тёмные башни, светящиеся окна, неоновые рёбра
-- и вывески, повёрнутые к клубам
--=========================================================================



local NEON = {
	Color3.fromRGB(255, 50, 200), Color3.fromRGB(0, 230, 255), Color3.fromRGB(170, 80, 255),
	Color3.fromRGB(255, 200, 40), Color3.fromRGB(60, 255, 140),
}
local SIGNS = { "ARCADE", "PIZZA", "ESPORTS", "GAME ZONE", "CYBER", "NEON CAFE", "24/7", "NAZAR CLUB", "VLA2MUSIC", "BURGERS" }
local WINDOW_ON = { Color3.fromRGB(255, 225, 150), Color3.fromRGB(160, 220, 255), Color3.fromRGB(255, 160, 220) }

local function tower(x, z, w, d, h, signText)
	local neon = NEON[rng:NextInteger(1, #NEON)]
	local base = Vector3.new(x, GROUND + 0.8, z)
	-- «Небоскрёб» ищет Rooftops.server.lua: лифт, парашют и сундук на крыше
	part({ Name = "Небоскрёб", Size = Vector3.new(w, h, d), Position = base + Vector3.new(0, h / 2, 0), Color = Color3.fromRGB(28, 26, 40), Material = Enum.Material.Glass, Reflectance = 0.15 })
	-- неоновые рёбра по углам и по крыше
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		part({ Size = Vector3.new(0.6, h, 0.6), Position = base + Vector3.new(c[1] * w / 2, h / 2, c[2] * d / 2), Color = neon, Material = Enum.Material.Neon, CanCollide = false })
	end
	part({ Size = Vector3.new(w + 0.6, 0.6, d + 0.6), Position = base + Vector3.new(0, h, 0), Color = neon, Material = Enum.Material.Neon, CanCollide = false })
	-- окна на фасаде к клубам (-Z): часть горит, часть тёмная
	local cols = math.floor(w / 5)
	for fy = 6, h - 5, 6 do
		for cx = 1, cols do
			if rng:NextNumber() < 0.55 then
				part({
					Size = Vector3.new(2.6, 3, 0.2),
					Position = base + Vector3.new(-w / 2 + (cx - 0.5) * (w / cols), fy, -d / 2 - 0.1),
					Color = WINDOW_ON[rng:NextInteger(1, #WINDOW_ON)], Material = Enum.Material.Neon, CanCollide = false,
				})
			end
		end
	end
	-- вывеска
	if signText then
		local sy = math.min(h - 8, rng:NextInteger(14, 26))
		local sign = part({ Size = Vector3.new(w * 0.85, 7, 0.4), Position = base + Vector3.new(0, sy, -d / 2 - 0.6), Color = Color3.fromRGB(10, 10, 15) })
		part({ Size = Vector3.new(w * 0.85 + 0.8, 7.8, 0.2), Position = sign.Position + Vector3.new(0, 0, 0.25), Color = neon, Material = Enum.Material.Neon })
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 0
		gui.Brightness = 2
		gui.Parent = sign
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamBlack
		l.TextScaled = true
		l.Text = signText
		l.TextColor3 = neon
		l.Parent = gui
	end
	-- мигалка на крыше
	local blink = part({ Size = Vector3.new(1.5, 1.5, 1.5), Position = base + Vector3.new(0, h + 1.4, 0), Color = Color3.fromRGB(255, 50, 50), Material = Enum.Material.Neon })
	blink:SetAttribute("Blink", true)
end

local si = 1
local ARCADE_X = 562
for x = 330, 910, 58 do
	for row, z in ipairs({ 205, 265, 325 }) do
		if x == ARCADE_X and row == 1 then
			-- место под игровой зал ARCADE (строит Arcade.server.lua)
			workspace:SetAttribute("ArcadeSpot", Vector3.new(x, GROUND + 0.8, z))
		elseif rng:NextNumber() < 0.9 then
			local h = row == 1 and rng:NextInteger(35, 70) or rng:NextInteger(60, 140)
			local label = row == 1 and SIGNS[(si - 1) % #SIGNS + 1] or nil
			if label then si += 1 end
			tower(x + rng:NextInteger(-4, 4), z, rng:NextInteger(30, 40), rng:NextInteger(26, 34), h, label)
		end
	end
	task.wait()
end

-- фонари вдоль дорожки
for x = -100, 1300, 60 do
	part({ Size = Vector3.new(0.8, 16, 0.8), Position = Vector3.new(x, GROUND + 8, PATH_Z + 13), Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Metal })
	local lamp = part({ Size = Vector3.new(2.4, 1.2, 2.4), Position = Vector3.new(x, GROUND + 16.4, PATH_Z + 13), Color = Color3.fromRGB(255, 230, 170), Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Range = 30
	light.Brightness = 1.5
	light.Color = Color3.fromRGB(255, 220, 170)
	light.Parent = lamp
end

--=========================================================================
-- Колесо обозрения
--=========================================================================

local WHEEL_POS = Vector3.new(170, GROUND + 52, 250)
local WHEEL_R = 42

local wheel = Instance.new("Model")
wheel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
wheel.Name = "КолесоОбозрения"
wheel.Parent = city

-- опоры (не крутятся)
for _, dz in ipairs({ -6, 6 }) do
	for _, dx in ipairs({ -22, 22 }) do
		local foot = Vector3.new(WHEEL_POS.X + dx, GROUND, WHEEL_POS.Z + dz)
		local top = WHEEL_POS + Vector3.new(0, 0, dz)
		local len = (top - foot).Magnitude
		part({ Parent = wheel, Size = Vector3.new(2, len, 2), CFrame = CFrame.lookAt((foot + top) / 2, top) * CFrame.Angles(math.rad(90), 0, 0), Color = Color3.fromRGB(230, 230, 240), Material = Enum.Material.Metal })
	end
end

local hub = part({ Parent = wheel, Name = "Ось", Shape = Enum.PartType.Cylinder, Size = Vector3.new(14, 5, 5), CFrame = CFrame.new(WHEEL_POS) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(80, 80, 90), Material = Enum.Material.Metal })
local rotor = Instance.new("Folder")
rotor.Name = "Ротор"
rotor.Parent = wheel

local SEG = 28
for i = 0, SEG - 1 do
	local a1, a2 = i / SEG * math.pi * 2, (i + 1) / SEG * math.pi * 2
	for _, dz in ipairs({ -5, 5 }) do
		local p1 = WHEEL_POS + Vector3.new(math.cos(a1) * WHEEL_R, math.sin(a1) * WHEEL_R, dz)
		local p2 = WHEEL_POS + Vector3.new(math.cos(a2) * WHEEL_R, math.sin(a2) * WHEEL_R, dz)
		part({ Parent = rotor, Size = Vector3.new(1.4, 1.4, (p2 - p1).Magnitude + 0.4), CFrame = CFrame.lookAt((p1 + p2) / 2, p2),
			Color = Color3.fromHSV(i / SEG, 0.7, 1), Material = Enum.Material.Neon })
	end
end
local CABINS = 12
for i = 0, CABINS - 1 do
	local a = i / CABINS * math.pi * 2
	local rimPoint = WHEEL_POS + Vector3.new(math.cos(a) * WHEEL_R, math.sin(a) * WHEEL_R, 0)
	part({ Parent = rotor, Size = Vector3.new(1, 1, WHEEL_R), CFrame = CFrame.lookAt((WHEEL_POS + rimPoint) / 2, rimPoint), Color = Color3.fromRGB(230, 230, 240), Material = Enum.Material.Metal })
	local cabin = part({ Parent = rotor, Name = "Кабинка", Size = Vector3.new(6, 6, 7), CFrame = CFrame.new(rimPoint - Vector3.new(0, 4, 0)),
		Color = Color3.fromHSV(i / CABINS, 0.6, 0.95) })
	cabin:SetAttribute("Upright", true)
end

--=========================================================================
-- Американские горки
--=========================================================================

local COASTER_C = Vector3.new(1060, GROUND, 250)
local coaster = Instance.new("Model")
coaster.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
coaster.Name = "АмериканскиеГорки"
coaster.Parent = city
local track = Instance.new("Folder")
track.Name = "Трасса"
track.Parent = coaster

local N = 140
local function trackPoint(t)
	local a = t * math.pi * 2
	return COASTER_C + Vector3.new(
		math.cos(a) * 110,
		14 + 30 * (math.sin(a * 2) * 0.5 + 0.5) + 16 * math.max(0, math.sin(a * 3)),
		math.sin(a) * 60
	)
end
for i = 0, N - 1 do
	local p1, p2 = trackPoint(i / N), trackPoint((i + 1) / N)
	local seg = part({ Parent = track, Name = "Рельс", Size = Vector3.new(5, 0.8, (p2 - p1).Magnitude + 0.3), CFrame = CFrame.lookAt((p1 + p2) / 2, p2),
		Color = Color3.fromRGB(230, 60, 60), Material = Enum.Material.Metal })
	seg:SetAttribute("Index", i)
	if i % 2 == 0 then
		local bulb = part({ Parent = coaster, Name = "Лампочка", Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), Position = p1 + Vector3.new(0, 0.9, 0),
			Color = Color3.fromRGB(255, 230, 120), Material = Enum.Material.Neon, CanCollide = false })
		bulb:SetAttribute("Bulb", i)
	end
	if i % 5 == 0 then
		part({ Parent = coaster, Size = Vector3.new(1.2, p1.Y - GROUND, 1.2), Position = Vector3.new(p1.X, (p1.Y + GROUND) / 2, p1.Z), Color = Color3.fromRGB(240, 240, 245), Material = Enum.Material.Metal })
	end
end
for i = 1, 3 do
	local car = part({ Parent = coaster, Name = "Вагончик" .. i, Size = Vector3.new(5, 3, 6), Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Metal, CanCollide = false, CFrame = CFrame.new(trackPoint(0)) })
	car:SetAttribute("Offset", (i - 1) * 3)
end

--=========================================================================
-- Таблицы рекордов (глобальные, по всем серверам)
--=========================================================================

local boards = {
	{ store = "TopEarned_v1",   title = "💰 TOP MONEY EARNED", attr = "TotalEarned", pos = Vector3.new(90, GROUND, 176) },
	{ store = "TopTime_v1",     title = "⏱ TOP TIME PLAYED",  attr = "PlayTime", time = true, pos = Vector3.new(150, GROUND, 176) },
	{ store = "TopRebirths_v1", title = "🔄 TOP REBIRTHS",     stat = "Rebirths", pos = Vector3.new(210, GROUND, 176) },
}

local function short(n)
	if n >= 1e12 then return string.format("%.1fT", n / 1e12) end
	if n >= 1e9 then return string.format("%.1fB", n / 1e9) end
	if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
	if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
	return tostring(n)
end

for _, b in ipairs(boards) do
	for _, dx in ipairs({ -16, 16 }) do
		part({ Size = Vector3.new(2, 30, 2), Position = b.pos + Vector3.new(dx, 15, 0), Color = Color3.fromRGB(120, 80, 50), Material = Enum.Material.Wood })
	end
	local panel = part({ Size = Vector3.new(30, 24, 1), Position = b.pos + Vector3.new(0, 17, 0), Color = Color3.fromRGB(35, 38, 55) })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front  -- смотрит на -Z, к клубам
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.Parent = panel
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.14, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 215, 90)
	title.Text = b.title
	title.Parent = gui
	local rows = {}
	for i = 1, 10 do
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(0.92, 0, 0.08, 0)
		l.Position = UDim2.new(0.04, 0, 0.15 + (i - 1) * 0.085, 0)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamBold
		l.TextScaled = true
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = i <= 3 and Color3.fromRGB(255, 230, 140) or Color3.new(1, 1, 1)
		l.Text = i .. ".  —"
		l.Parent = gui
		rows[i] = l
	end
	b.rows = rows
	b.ods = DataStoreService:GetOrderedDataStore(b.store)
end

local nameCache = {}
local function nameOf(userId)
	if nameCache[userId] then return nameCache[userId] end
	local ok, name = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
	nameCache[userId] = ok and name or ("#" .. userId)
	return nameCache[userId]
end

task.spawn(function()
	while true do
		for _, b in ipairs(boards) do
			for _, player in ipairs(Players:GetPlayers()) do
				local value
				if b.attr then
					value = player:GetAttribute(b.attr)
				else
					local ls = player:FindFirstChild("leaderstats")
					local v = ls and ls:FindFirstChild(b.stat)
					value = v and v.Value
				end
				if value and value > 0 then
					pcall(function() b.ods:SetAsync(tostring(player.UserId), math.floor(value)) end)
				end
			end
			local ok, pages = pcall(function() return b.ods:GetSortedAsync(false, 10) end)
			if ok then
				for i, entry in ipairs(pages:GetCurrentPage()) do
					local v = b.time and string.format("%dh %02dm", entry.value // 3600, entry.value % 3600 // 60) or short(entry.value)
					b.rows[i].Text = string.format("%d.  %s   %s", i, nameOf(tonumber(entry.key)), v)
				end
			end
		end
		task.wait(60)
	end
end)

--=========================================================================
-- ПАСХАЛКА: золотой сундук прячется между небоскрёбами.
-- Нашёл — получаешь половину цены следующей покупки. Потом сундук
-- перепрятывается, у каждого игрока перерыв 10 минут.
--=========================================================================

local SPOTS = {}   -- промежутки между домами в каждом ряду
for x = 359, 881, 58 do
	for _, z in ipairs({ 205, 265, 325 }) do table.insert(SPOTS, Vector3.new(x, 0, z)) end
end

-- Сундук: деревянный корпус, золотые оковки, выпуклая крышка, замок,
-- внутри светятся монеты. Все детали двигаются вместе (PivotTo).
local chestModel = Instance.new("Model")
chestModel.Name = "ЗолотойСундук"
chestModel.Parent = city
local WOOD, GOLD = Color3.fromRGB(110, 60, 30), Color3.fromRGB(255, 195, 50)
local function cpart(size, cf, color, mat, shape)
	local p = part({ Parent = chestModel, Size = size, CFrame = cf, Color = color, Material = mat, CanCollide = false })
	if shape then p.Shape = shape end
	return p
end
local c0 = CFrame.new(0, 500, 0)
local chest = cpart(Vector3.new(5, 3, 3.4), c0 * CFrame.new(0, 1.5, 0), WOOD, Enum.Material.WoodPlanks)          -- корпус
cpart(Vector3.new(5, 3.4, 3.4), c0 * CFrame.new(0, 3, 0), WOOD, Enum.Material.WoodPlanks, Enum.PartType.Cylinder)  -- крышка-полукруг
for _, dx in ipairs({ -1.9, 1.9 }) do                                                                            -- золотые обручи
	cpart(Vector3.new(0.35, 3.1, 3.5), c0 * CFrame.new(dx, 1.5, 0), GOLD, Enum.Material.Metal)
	cpart(Vector3.new(0.35, 3.55, 3.55), c0 * CFrame.new(dx, 3, 0), GOLD, Enum.Material.Metal, Enum.PartType.Cylinder)
end
cpart(Vector3.new(5.1, 0.35, 3.5), c0 * CFrame.new(0, 0.2, 0), GOLD, Enum.Material.Metal)                        -- нижняя кайма
cpart(Vector3.new(5.1, 0.3, 3.5), c0 * CFrame.new(0, 3, 0), GOLD, Enum.Material.Metal)                           -- стык крышки
cpart(Vector3.new(0.9, 1.1, 0.3), c0 * CFrame.new(0, 2.7, -1.8), GOLD, Enum.Material.Metal)                      -- замок
cpart(Vector3.new(0.3, 0.4, 0.1), c0 * CFrame.new(0, 2.6, -1.97), Color3.fromRGB(40, 25, 10))                   -- скважина
for k = 1, 6 do                                                                                                  -- монеты сверху
	cpart(Vector3.new(0.25, 0.9, 0.9), c0 * CFrame.new(-1.6 + k * 0.5, 4.75 + (k % 2) * 0.15, (k % 3 - 1) * 0.5) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(255, 220, 60), Enum.Material.Neon, Enum.PartType.Cylinder)
end
chestModel.PrimaryPart = chest
chestModel.WorldPivot = c0
local sparkle = Instance.new("Sparkles")
sparkle.SparkleColor = Color3.fromRGB(255, 220, 80)
sparkle.Parent = chest
local glow = Instance.new("PointLight")
glow.Color = Color3.fromRGB(255, 210, 80)
glow.Range = 16
glow.Brightness = 2
glow.Parent = chest

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { workspace.Terrain }

local function setChestVisible(on)
	for _, d in ipairs(chestModel:GetDescendants()) do
		if d:IsA("BasePart") then d.Transparency = on and 0 or 1 end
	end
	sparkle.Enabled = on
	glow.Enabled = on
end

local function hideChest()
	local p = SPOTS[rng:NextInteger(1, #SPOTS)]
	local hit = workspace:Raycast(p + Vector3.new(0, 80, 0), Vector3.new(0, -160, 0), groundParams)
	local y = hit and hit.Position.Y or GROUND
	chestModel:PivotTo(CFrame.new(p.X, y, p.Z) * CFrame.Angles(0, math.rad(rng:NextInteger(0, 359)), 0))
	setChestVisible(true)
end
hideChest()

local lastFound = {}
local busy = false
chest.Touched:Connect(function(hit)
	if busy then return end
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if not player or not player:FindFirstChild("leaderstats") then return end
	if lastFound[player] and os.clock() - lastFound[player] < 600 then return end
	busy = true
	lastFound[player] = os.clock()
	-- 5 минут дохода клуба, но не меньше половины следующей покупки
	local income = player:FindFirstChild("Stats") and player.Stats.Income.Value or 0
	local amount = math.floor(math.max(200, income * 300, (player:GetAttribute("NextCost") or 0) * 0.5))
	player.leaderstats.Coins.Value += amount
	player:SetAttribute("ChestBonus", nil)
	player:SetAttribute("ChestBonus", amount)   -- экран покажет «+N»
	setChestVisible(false)
	task.wait(3)
	hideChest()
	busy = false
end)
Players.PlayerRemoving:Connect(function(p) lastFound[p] = nil end)

--=========================================================================
-- ТРАССА вдоль всех клубов, парковки со знаком P, переходы-зебры,
-- тротуар с фонарями, киоски с дешёвыми лимонадами «через дорогу»,
-- пешеходы
--=========================================================================

local ROAD_Z, ROAD_W = 140, 26
local RY = GROUND + 2          -- дорога выше «вспухшего» газона
part({ Name = "Трасса", Size = Vector3.new(1600, 1, ROAD_W), Position = Vector3.new(630, RY, ROAD_Z), Color = Color3.fromRGB(38, 38, 44), Material = Enum.Material.Asphalt })
for x = -160, 1420, 18 do   -- прерывистая разметка
	part({ Size = Vector3.new(9, 0.1, 0.6), Position = Vector3.new(x, RY + 0.55, ROAD_Z), Color = Color3.fromRGB(240, 240, 240), Material = Enum.Material.Neon, CanCollide = false })
end
for _, dz in ipairs({ -ROAD_W / 2 + 0.8, ROAD_W / 2 - 0.8 }) do
	part({ Size = Vector3.new(1600, 0.1, 0.4), Position = Vector3.new(630, RY + 0.55, ROAD_Z + dz), Color = Color3.fromRGB(255, 210, 60), CanCollide = false })
end
-- тротуар и фонари с обеих сторон
for _, sz in ipairs({ ROAD_Z - ROAD_W / 2 - 3, ROAD_Z + ROAD_W / 2 + 3 }) do
	part({ Size = Vector3.new(1600, 1.4, 6), Position = Vector3.new(630, RY + 0.2, sz), Color = Color3.fromRGB(150, 150, 160), Material = Enum.Material.Concrete })
end
for x = -140, 1400, 45 do
	for _, sz in ipairs({ ROAD_Z - ROAD_W / 2 - 4.5, ROAD_Z + ROAD_W / 2 + 4.5 }) do
		part({ Size = Vector3.new(0.7, 14, 0.7), Position = Vector3.new(x, RY + 7, sz), Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Metal })
		local lamp = part({ Size = Vector3.new(2, 1, 2), Position = Vector3.new(x, RY + 14.3, sz), Color = Color3.fromRGB(255, 225, 160), Material = Enum.Material.Neon })
		local l = Instance.new("PointLight") l.Range = 26 l.Brightness = 1.3 l.Color = lamp.Color l.Parent = lamp
	end
end
-- у каждого клуба: парковка с P, зебра и киоск через дорогу
local lemonadePrompt
for _ = 1, 100 do
	lemonadePrompt = _G.ClubLemonadePrompt
	if lemonadePrompt then break end
	task.wait(0.2)
end
for i = 0, 5 do
	local cx = i * 240
	-- парковка между лентой и трассой
	part({ Size = Vector3.new(36, 1, 12), Position = Vector3.new(cx + 40, RY - 0.05, ROAD_Z + ROAD_W / 2 + 13), Color = Color3.fromRGB(45, 45, 52), Material = Enum.Material.Asphalt })
	for k = 0, 5 do
		part({ Size = Vector3.new(0.4, 0.1, 9), Position = Vector3.new(cx + 23 + k * 6.5, RY + 0.5, ROAD_Z + ROAD_W / 2 + 13), Color = Color3.new(1, 1, 1), CanCollide = false })
	end
	part({ Size = Vector3.new(0.5, 9, 0.5), Position = Vector3.new(cx + 20, RY + 4.5, ROAD_Z + ROAD_W / 2 + 7), Color = Color3.fromRGB(150, 150, 160), Material = Enum.Material.Metal })
	local sign = part({ Size = Vector3.new(4, 4, 0.3), Position = Vector3.new(cx + 20, RY + 10, ROAD_Z + ROAD_W / 2 + 7), Color = Color3.fromRGB(30, 90, 220) })
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local g = Instance.new("SurfaceGui") g.Face = face g.LightInfluence = 0 g.Parent = sign
		local t = Instance.new("TextLabel") t.Size = UDim2.fromScale(1, 1) t.BackgroundTransparency = 1 t.Font = Enum.Font.GothamBlack
		t.TextScaled = true t.Text = "P" t.TextColor3 = Color3.new(1, 1, 1) t.Parent = g
	end
	-- зебра
	for k = 0, 6 do
		part({ Size = Vector3.new(1.6, 0.1, ROAD_W - 2), Position = Vector3.new(cx - 6 + k * 2, RY + 0.52, ROAD_Z), Color = Color3.new(1, 1, 1), CanCollide = false })
	end
	-- киоск с лимонадами через дорогу (в 3 раза дешевле, чем в клубе)
	local kz = ROAD_Z + ROAD_W / 2 + 12
	part({ Size = Vector3.new(16, 1, 10), Position = Vector3.new(cx, RY, kz), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.WoodPlanks })
	part({ Size = Vector3.new(16, 0.6, 10), Position = Vector3.new(cx, RY + 10, kz), Color = Color3.fromRGB(255, 200, 40) })
	for _, dx in ipairs({ -7.5, 7.5 }) do
		part({ Size = Vector3.new(0.6, 9.5, 0.6), Position = Vector3.new(cx + dx, RY + 5, kz - 4.5), Color = Color3.fromRGB(240, 240, 240) })
	end
	local board = part({ Size = Vector3.new(16, 3, 0.4), Position = Vector3.new(cx, RY + 11.8, kz - 5), Color = Color3.fromRGB(20, 20, 30) })
	local g = Instance.new("SurfaceGui") g.Face = Enum.NormalId.Front g.LightInfluence = 0 g.Parent = board
	local t = Instance.new("TextLabel") t.Size = UDim2.fromScale(1, 1) t.BackgroundTransparency = 1 t.Font = Enum.Font.GothamBlack
	t.TextScaled = true t.Text = "🍋 LEMONADE -66%" t.TextColor3 = Color3.fromRGB(255, 230, 80) t.Parent = g
	for k, kind in ipairs(require(game:GetService("ReplicatedStorage"):WaitForChild("ClubShared")).LEMONADES) do
		local fridge = part({ Size = Vector3.new(3.5, 6, 3), Position = Vector3.new(cx - 5 + (k - 1) * 5, RY + 3.5, kz + 2), Color = kind.color, Material = Enum.Material.Neon, Transparency = 0.2 })
		if lemonadePrompt then lemonadePrompt(fridge, kind, 1, nil) end
	end
end
-- Улицы киберквартала: две поперечные (x=290 и x=955) от трассы вглубь
-- и три продольные между рядами домов. С разметкой, тротуарами, фонарями.
local STREET_W = 14
local STREETS = { { 290, 153, 290, 355 }, { 955, 153, 955, 355 } }
for _, z in ipairs({ 175, 235, 295, 355 }) do table.insert(STREETS, { 290, z, 955, z }) end
-- фонарь нельзя ставить на проезжую часть (перекрёстки, трасса)
local function onRoad(p)
	if math.abs(p.Z - ROAD_Z) < ROAD_W / 2 + 1 then return true end
	for _, s in ipairs(STREETS) do
		if p.X > math.min(s[1], s[3]) - STREET_W / 2 - 1 and p.X < math.max(s[1], s[3]) + STREET_W / 2 + 1
			and p.Z > math.min(s[2], s[4]) - STREET_W / 2 - 1 and p.Z < math.max(s[2], s[4]) + STREET_W / 2 + 1 then
			return true
		end
	end
	return false
end
local function street(x1, z1, x2, z2)
	local horizontal = z1 == z2
	local len = horizontal and math.abs(x2 - x1) or math.abs(z2 - z1)
	local c = Vector3.new((x1 + x2) / 2, RY, (z1 + z2) / 2)
	local size = horizontal and Vector3.new(len + STREET_W, 1, STREET_W) or Vector3.new(STREET_W, 1, len + STREET_W)
	part({ Size = size, Position = c, Color = Color3.fromRGB(38, 38, 44), Material = Enum.Material.Asphalt })
	-- осевая прерывистая
	for d = -len / 2 + 6, len / 2 - 6, 14 do
		local pos = horizontal and c + Vector3.new(d, 0.55, 0) or c + Vector3.new(0, 0.55, d)
		part({ Size = horizontal and Vector3.new(7, 0.1, 0.5) or Vector3.new(0.5, 0.1, 7), Position = pos, Color = Color3.fromRGB(240, 240, 240), CanCollide = false })
	end
	-- тротуары и фонари по обеим сторонам
	for _, side in ipairs({ -1, 1 }) do
		local off = side * (STREET_W / 2 + 2.5)
		local sw = horizontal and Vector3.new(len + STREET_W + 10, 1.4, 5) or Vector3.new(5, 1.4, len + STREET_W + 10)
		part({ Size = sw, Position = c + (horizontal and Vector3.new(0, 0.2, off) or Vector3.new(off, 0.2, 0)), Color = Color3.fromRGB(150, 150, 160), Material = Enum.Material.Concrete })
		for d = -len / 2, len / 2, 40 do
			local lp = c + (horizontal and Vector3.new(d, 0, off + side * 1.5) or Vector3.new(off + side * 1.5, 0, d))
			if onRoad(lp) then continue end
			part({ Size = Vector3.new(0.6, 12, 0.6), Position = lp + Vector3.new(0, 6, 0), Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Metal })
			local lamp = part({ Size = Vector3.new(1.8, 0.9, 1.8), Position = lp + Vector3.new(0, 12.3, 0), Color = Color3.fromRGB(200, 160, 255), Material = Enum.Material.Neon })
			local l = Instance.new("PointLight") l.Range = 22 l.Brightness = 1.2 l.Color = lamp.Color l.Parent = lamp
		end
	end
end
for _, s in ipairs(STREETS) do street(s[1], s[2], s[3], s[4]) end

-- Пешеходы гуляют по тротуарам и в киберквартал
local ANIM_WALK = "rbxassetid://507777826"
local TweenService = game:GetService("TweenService")
local function pedestrian(points, speed)
	local ok, npc = pcall(function()
		local d = Instance.new("HumanoidDescription")
		local skins = { Color3.fromRGB(234, 184, 146), Color3.fromRGB(198, 140, 100), Color3.fromRGB(141, 85, 56) }
		local s0 = skins[rng:NextInteger(1, 3)]
		d.HeadColor, d.LeftArmColor, d.RightArmColor = s0, s0, s0
		d.TorsoColor = Color3.fromHSV(rng:NextNumber(), 0.7, 0.9)
		local legs = Color3.fromHSV(rng:NextNumber(), 0.4, 0.4)
		d.LeftLegColor, d.RightLegColor = legs, legs
		return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	end)
	if not ok then return end
	npc.Name = "Пешеход"
	npc.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	for _, d in ipairs(npc:GetDescendants()) do if d:IsA("BasePart") then d.CanCollide = false end end
	local root = npc.HumanoidRootPart
	root.Anchored = true
	local h = npc.Humanoid.HipHeight + root.Size.Y / 2
	for k, p in ipairs(points) do points[k] = p + Vector3.new(0, h, 0) end
	npc:PivotTo(CFrame.new(points[1]))
	npc.Parent = city
	local anim = Instance.new("Animation") anim.AnimationId = ANIM_WALK
	local track = npc.Humanoid:WaitForChild("Animator"):LoadAnimation(anim)
	track.Looped = true track:Play()
	task.spawn(function()
		local i = 2
		while npc.Parent do
			local from, to = root.Position, points[i]
			root.CFrame = CFrame.lookAt(from, to)
			local tw = TweenService:Create(root, TweenInfo.new((to - from).Magnitude / speed, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(to, to + (to - from).Unit) })
			tw:Play() tw.Completed:Wait()
			i = i % #points + 1
		end
	end)
end
local walkY = RY + 0.9
for n = 1, 10 do   -- 7 вдоль трассы, 3 по улицам квартала
	local side = n % 2 == 0 and ROAD_Z + ROAD_W / 2 + 3 or ROAD_Z - ROAD_W / 2 - 3
	local x1 = rng:NextInteger(-120, 1100)
	if n <= 7 then
		pedestrian({ Vector3.new(x1, walkY, side), Vector3.new(x1 + rng:NextInteger(150, 300), walkY, side) }, rng:NextInteger(5, 8))
	else
		local sz = ({ 175, 235, 295 })[n - 7] + STREET_W / 2 + 2.5
		pedestrian({ Vector3.new(282, walkY, sz), Vector3.new(963, walkY, sz) }, rng:NextInteger(5, 8))
	end
end

-- Тоннели на обоих концах трассы: портал в скале, внутри темнота
for _, e in ipairs({ { -160, -1 }, { 1420, 1 } }) do
	local x, dir = e[1], e[2]
	-- гора с прорубленным тоннелем — World.server.lua; дорога уходит внутрь,
	-- в глубине темнота и стена
	part({ Size = Vector3.new(90, 1, ROAD_W), Position = Vector3.new(x + dir * 45, RY, ROAD_Z), Color = Color3.fromRGB(38, 38, 44), Material = Enum.Material.Asphalt })
	part({ Size = Vector3.new(2, 20, ROAD_W + 8), Position = Vector3.new(x + dir * 90, RY + 10, ROAD_Z), Color = Color3.new(0, 0, 0), Material = Enum.Material.SmoothPlastic })
	for k = 1, 4 do   -- лампы на потолке тоннеля
		part({ Size = Vector3.new(3, 0.4, 1), Position = Vector3.new(x + dir * k * 18, RY + 17.5, ROAD_Z), Color = Color3.fromRGB(255, 190, 90), Material = Enum.Material.Neon, CanCollide = false })
	end
	-- бетонная арка-портал
	part({ Size = Vector3.new(2, 4, ROAD_W + 10), Position = Vector3.new(x, RY + 19, ROAD_Z), Color = Color3.fromRGB(160, 160, 170), Material = Enum.Material.Concrete })
	for _, side in ipairs({ -1, 1 }) do
		part({ Size = Vector3.new(2, 19, 4), Position = Vector3.new(x, RY + 9.5, ROAD_Z + side * (ROAD_W / 2 + 3)), Color = Color3.fromRGB(160, 160, 170), Material = Enum.Material.Concrete })
	end
	-- жёлтые огоньки над въездом
	for k = -2, 2 do
		part({ Size = Vector3.new(0.6, 0.6, 0.6), Position = Vector3.new(x - dir * 1.2, RY + 18, ROAD_Z + k * 5), Color = Color3.fromRGB(255, 190, 60), Material = Enum.Material.Neon, CanCollide = false })
	end
end

workspace:SetAttribute("CityReady", true)
print("[Город] Дорожка, город, колесо, горки и рекорды готовы")
