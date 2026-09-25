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
local belts = Instance.new("Folder")
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

part({ Size = Vector3.new(700, 1, 200), Position = Vector3.new(620, GROUND + 0.3, 270), Color = Color3.fromRGB(30, 30, 38), Material = Enum.Material.Asphalt })

local NEON = {
	Color3.fromRGB(255, 50, 200), Color3.fromRGB(0, 230, 255), Color3.fromRGB(170, 80, 255),
	Color3.fromRGB(255, 200, 40), Color3.fromRGB(60, 255, 140),
}
local SIGNS = { "ARCADE", "PIZZA", "ESPORTS", "GAME ZONE", "CYBER", "NEON CAFE", "24/7", "NAZAR CLUB", "VLA2MUSIC", "BURGERS" }
local WINDOW_ON = { Color3.fromRGB(255, 225, 150), Color3.fromRGB(160, 220, 255), Color3.fromRGB(255, 160, 220) }

local function tower(x, z, w, d, h, signText)
	local neon = NEON[rng:NextInteger(1, #NEON)]
	local base = Vector3.new(x, GROUND + 0.8, z)
	part({ Size = Vector3.new(w, h, d), Position = base + Vector3.new(0, h / 2, 0), Color = Color3.fromRGB(28, 26, 40), Material = Enum.Material.Glass, Reflectance = 0.15 })
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
for x = 330, 910, 58 do
	for row, z in ipairs({ 205, 265, 325 }) do
		if rng:NextNumber() < 0.9 then
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
	{ store = "TopCoins_v1",    title = "🏆 TOP COINS",    stat = "Coins",    pos = Vector3.new(120, GROUND, 118) },
	{ store = "TopRebirths_v1", title = "🔄 TOP REBIRTHS", stat = "Rebirths", pos = Vector3.new(360, GROUND, 118) },
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
				local ls = player:FindFirstChild("leaderstats")
				local v = ls and ls:FindFirstChild(b.stat)
				if v and v.Value > 0 then
					pcall(function() b.ods:SetAsync(tostring(player.UserId), math.floor(v.Value)) end)
				end
			end
			local ok, pages = pcall(function() return b.ods:GetSortedAsync(false, 10) end)
			if ok then
				for i, entry in ipairs(pages:GetCurrentPage()) do
					b.rows[i].Text = string.format("%d.  %s   %s", i, nameOf(tonumber(entry.key)), short(entry.value))
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

local SPOTS = {}
for x = 355, 885, 58 do
	for _, z in ipairs({ 235, 295 }) do table.insert(SPOTS, Vector3.new(x, GROUND + 2.5, z)) end
end
local chest = part({ Name = "ЗолотойСундук", Size = Vector3.new(4, 3, 3), Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Metal, Reflectance = 0.3, CanCollide = false })
part({ Parent = chest, Size = Vector3.new(4.2, 0.5, 3.2), Color = Color3.fromRGB(120, 70, 30), Material = Enum.Material.Wood, CanCollide = false })
local sparkle = Instance.new("Sparkles")
sparkle.SparkleColor = Color3.fromRGB(255, 220, 80)
sparkle.Parent = chest
local glow = Instance.new("PointLight")
glow.Color = Color3.fromRGB(255, 210, 80)
glow.Range = 14
glow.Parent = chest

local function hideChest()
	local p = SPOTS[rng:NextInteger(1, #SPOTS)]
	chest.CFrame = CFrame.new(p) * CFrame.Angles(0, math.rad(rng:NextInteger(0, 359)), 0)
	chest.Transparency = 0
	chest:GetChildren()[1].CFrame = chest.CFrame * CFrame.new(0, 1.7, 0)
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
	local amount = math.max(500, math.floor((player:GetAttribute("NextCost") or 0) * 0.5))
	player.leaderstats.Coins.Value += amount
	player:SetAttribute("ChestBonus", nil)
	player:SetAttribute("ChestBonus", amount)   -- экран покажет «+N»
	chest.Transparency = 1
	task.wait(3)
	hideChest()
	busy = false
end)
Players.PlayerRemoving:Connect(function(p) lastFound[p] = nil end)

print("[Город] Дорожка, город, колесо, горки и рекорды готовы")
