--[[=========================================================================
	РЕКЛАМА НА НЕБОСКРЁБАХ
	• Экраны «NazarTok» на самых высоких домах: ролики крутит NazarTok.client.lua
	  (в подписях — подсказки к пасхалкам).
	• Рекламные баннеры на боковых стенах (реклама того, что есть в игре).
	• Граффити с подсказками внизу, со стороны улиц квартала.
==========================================================================]]

while not workspace:GetAttribute("CityReady") do task.wait(0.5) end

local rng = Random.new(2027)
local folder = Instance.new("Folder")
folder.Name = "Реклама"
folder.Parent = workspace

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do p[k] = v end
	p.Parent = props.Parent or folder
	return p
end

local towers = {}
for _, p in ipairs(workspace:WaitForChild("Город"):GetChildren()) do
	if p.Name == "Небоскрёб" then table.insert(towers, p) end
end
table.sort(towers, function(a, b) return a.Size.Y > b.Size.Y end)

-- точка на грани дома: face = "front" (-Z, к клубам), "back" (+Z), "east" (+X), "west" (-X)
local function onFace(t, face, y, w, h)
	local c, s = t.Position, t.Size
	local base = c.Y - s.Y / 2
	if face == "front" then return CFrame.lookAt(Vector3.new(c.X, base + y, c.Z - s.Z / 2 - 0.5), Vector3.new(c.X, base + y, c.Z - s.Z)), Vector3.new(w, h, 0.4) end
	if face == "back"  then return CFrame.lookAt(Vector3.new(c.X, base + y, c.Z + s.Z / 2 + 0.5), Vector3.new(c.X, base + y, c.Z + s.Z)), Vector3.new(w, h, 0.4) end
	if face == "east"  then return CFrame.lookAt(Vector3.new(c.X + s.X / 2 + 0.5, base + y, c.Z), Vector3.new(c.X + s.X, base + y, c.Z)), Vector3.new(w, h, 0.4) end
	return CFrame.lookAt(Vector3.new(c.X - s.X / 2 - 0.5, base + y, c.Z), Vector3.new(c.X - s.X, base + y, c.Z)), Vector3.new(w, h, 0.4)
end

local function surface(p, name)
	local g = Instance.new("SurfaceGui")
	g.Name = name
	g.Face = Enum.NormalId.Front   -- лицевая сторона смотрит наружу (lookAt)
	g.LightInfluence = 0
	g.Brightness = 1.6
	g.CanvasSize = Vector2.new(p.Size.X * 25, p.Size.Y * 25)
	g.Parent = p
	return g
end

--=========================================================================
-- NazarTok: 5 самых высоких домов, вертикальный экран 9:16 в неоновой рамке
--=========================================================================
for i = 1, math.min(5, #towers) do
	local t = towers[i]
	local h = math.min(40, t.Size.Y * 0.35)
	local w = h * 9 / 16
	local cf, size = onFace(t, "front", t.Size.Y - h / 2 - 6, w, h)
	part({ Size = size + Vector3.new(1.2, 1.2, -0.2), CFrame = cf * CFrame.new(0, 0, 0.15), Color = Color3.fromRGB(255, 40, 120), Material = Enum.Material.Neon })
	local screen = part({ Name = "NazarTokЭкран", Size = size, CFrame = cf, Color = Color3.new(0, 0, 0) })
	surface(screen, "NazarTok"):SetAttribute("Offset", i)   -- у каждого экрана свой ролик
end

--=========================================================================
-- Рекламные баннеры на боковых стенах
--=========================================================================
local ADS = {
	{ "🪂", "PARAGLIDER", "14 RINGS · $$$", Color3.fromRGB(60, 255, 140) },
	{ "🍋", "LEMONADE", "-66% ACROSS THE ROAD", Color3.fromRGB(255, 220, 60) },
	{ "🎮", "NAZAR CLUB", "BEST PCs IN TOWN", Color3.fromRGB(0, 230, 255) },
	{ "🎧", "VLA2MUSIC", "NEW TRACKS IN THE CLUB", Color3.fromRGB(200, 120, 255) },
	{ "🛗", "ROOFTOP LIFT", "EVERY TOWER · TRY IT", Color3.fromRGB(255, 150, 60) },
	{ "🎡", "FERRIS WHEEL", "NIGHT VIEW", Color3.fromRGB(255, 90, 200) },
}
for i, t in ipairs(towers) do
	if i > 5 and t.Size.Y > 50 and rng:NextNumber() < 0.6 then
		local ad = ADS[(i - 1) % #ADS + 1]
		local face = rng:NextNumber() < 0.5 and "east" or "west"
		local cf, size = onFace(t, face, t.Size.Y * 0.55, math.min(14, t.Size.Z * 0.5), 26)
		local banner = part({ Size = size, CFrame = cf, Color = Color3.fromRGB(12, 10, 20) })
		part({ Size = size + Vector3.new(0.8, 0.8, -0.2), CFrame = cf * CFrame.new(0, 0, 0.15), Color = ad[4], Material = Enum.Material.Neon })
		local g = surface(banner, "Ad")
		local list = Instance.new("UIListLayout") list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = Enum.VerticalAlignment.Center list.Padding = UDim.new(0.03, 0) list.Parent = g
		for k, txt in ipairs({ ad[1], ad[2], ad[3] }) do
			local l = Instance.new("TextLabel")
			l.Size = UDim2.fromScale(0.9, ({ 0.35, 0.18, 0.12 })[k])
			l.BackgroundTransparency = 1
			l.Font = Enum.Font.GothamBlack
			l.TextScaled = true
			l.Text = txt
			l.TextColor3 = k == 3 and Color3.new(1, 1, 1) or ad[4]
			l.LayoutOrder = k
			l.Parent = g
		end
	end
end

--=========================================================================
-- Граффити с подсказками: на задней стене (+Z) домов, у земли, к улицам
--=========================================================================
local HINTS = {
	{ "ЗОЛОТОЙ СУНДУК ПРЯЧЕТСЯ МЕЖДУ ДОМАМИ 👀", "GOLD CHEST HIDES BETWEEN TOWERS 👀" },
	{ "ЛИФТ НА КРЫШУ — У КАЖДОГО ДОМА 🛗", "EVERY TOWER HAS A ROOF LIFT 🛗" },
	{ "С КРЫШИ НА КРЫШУ? БЕРИ ПАРАШЮТ 🪂", "ROOF TO ROOF? GRAB A PARACHUTE 🪂" },
	{ "НА ЯХТАХ ТОЖЕ ЕСТЬ СУНДУКИ 🛥️", "YACHTS HAVE CHESTS TOO 🛥️" },
	{ "14 КОЛЕЦ БЕЗ ПРОПУСКА = СУПЕРБОНУС 💍", "ALL 14 RINGS = SUPER BONUS 💍" },
	{ "ПОГЛАДЬ КОТА В КЛУБЕ 🐱", "PET THE CLUB CAT 🐱" },
	{ "ТАЙНАЯ ДВЕРЬ «???» … СКОРО 🤫", "SECRET DOOR «???» … SOON 🤫" },
	{ "СМОТРОВАЯ БАШНЯ: ПАРАШЮТ НАВЕРХУ 🗼", "VIEW TOWER: PARACHUTE ON TOP 🗼" },
}
local SPRAY = { Color3.fromRGB(255, 60, 160), Color3.fromRGB(60, 230, 255), Color3.fromRGB(255, 220, 40), Color3.fromRGB(120, 255, 90), Color3.fromRGB(190, 100, 255) }
local pool = {}
for i = 1, #towers do pool[i] = towers[i] end
for k, hint in ipairs(HINTS) do
	if #pool == 0 then break end
	local t = table.remove(pool, rng:NextInteger(1, #pool))
	local w = math.min(26, t.Size.X - 4)
	local cf, size = onFace(t, "back", 7, w, 9)
	local wall = part({ Name = "Граффити", Size = size, CFrame = cf, Transparency = 1 })
	wall:SetAttribute("Hint", k)
	local g = surface(wall, "Graffiti")
	g.Brightness = 1.2
	local color = SPRAY[(k - 1) % #SPRAY + 1]
	-- «пятно» краски под надписью
	local blob = Instance.new("Frame")
	blob.Size = UDim2.fromScale(1, 1)
	blob.BackgroundColor3 = color
	blob.BackgroundTransparency = 0.75
	blob.Parent = g
	Instance.new("UICorner", blob).CornerRadius = UDim.new(0.5, 0)
	local l = Instance.new("TextLabel")
	l.Name = "Text"
	l.Size = UDim2.fromScale(0.94, 0.8)
	l.Position = UDim2.fromScale(0.03, 0.1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.PermanentMarker
	l.TextScaled = true
	l.Rotation = rng:NextNumber(-3, 3)
	l.Text = hint[2]
	l.TextColor3 = color
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	l.TextStrokeTransparency = 0
	l.Parent = g
	l:SetAttribute("Ru", hint[1])   -- NazarTok.client.lua поставит русский текст
end

print("[Реклама] Экраны NazarTok, баннеры и граффити готовы")
