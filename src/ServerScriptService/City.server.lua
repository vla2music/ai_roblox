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

local PATH_Z = 100
local path = part({
	Name = "БыстраяДорожка",
	Size = Vector3.new(1480, 1, 14),
	Position = Vector3.new(600, GROUND + 0.5, PATH_Z),
	Color = Color3.fromRGB(215, 220, 235),
	Material = Enum.Material.Concrete,
})
path:SetAttribute("SpeedPath", true)
for _, dz in ipairs({ -7.3, 7.3 }) do
	part({ Size = Vector3.new(1480, 1.4, 0.6), Position = Vector3.new(600, GROUND + 0.7, PATH_Z + dz), Color = Color3.fromRGB(120, 80, 50), Material = Enum.Material.Wood })
end
-- стрелки на дорожке
for x = -100, 1300, 40 do
	local arrow = part({ Size = Vector3.new(6, 0.1, 3), Position = Vector3.new(x, GROUND + 1.02, PATH_Z), Color = Color3.fromRGB(80, 220, 255), Material = Enum.Material.Neon, CanCollide = false })
	arrow:SetAttribute("SpeedPath", true)
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
-- Город: небоскрёбы со светящимися окнами
--=========================================================================

part({ Size = Vector3.new(700, 1, 200), Position = Vector3.new(620, GROUND + 0.3, 270), Color = Color3.fromRGB(60, 62, 70), Material = Enum.Material.Asphalt })

local palette = {
	Color3.fromRGB(90, 110, 150), Color3.fromRGB(150, 90, 120), Color3.fromRGB(80, 140, 140),
	Color3.fromRGB(170, 150, 110), Color3.fromRGB(110, 100, 160),
}
for x = 320, 920, 50 do
	for z = 200, 330, 55 do
		if rng:NextNumber() < 0.85 then
			local h = rng:NextInteger(40, 130)
			local w = rng:NextInteger(26, 36)
			local base = Vector3.new(x + rng:NextInteger(-4, 4), GROUND + 0.8 + h / 2, z)
			part({ Size = Vector3.new(w, h, w), Position = base, Color = palette[rng:NextInteger(1, #palette)], Material = Enum.Material.Concrete })
			-- полосы окон
			for y = GROUND + 8, GROUND + h - 4, 9 do
				part({ Size = Vector3.new(w + 0.3, 2.2, w + 0.3), Position = Vector3.new(base.X, y, base.Z),
					Color = rng:NextNumber() < 0.5 and Color3.fromRGB(255, 230, 150) or Color3.fromRGB(150, 210, 255),
					Material = Enum.Material.Glass, Transparency = 0.2 })
			end
			-- мигалка на крыше
			part({ Size = Vector3.new(1.5, 1.5, 1.5), Position = Vector3.new(base.X, GROUND + h + 1.6, base.Z), Color = Color3.fromRGB(255, 60, 60), Material = Enum.Material.Neon })
		end
	end
	task.wait()
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

print("[Город] Дорожка, город, колесо, горки и рекорды готовы")
