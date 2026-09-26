--[[=========================================================================
	ИГРОВОЙ ЗАЛ ARCADE: двухэтажное стеклянное здание в киберквартале
	(место оставляет City.server.lua) и два автомата на палубе лайнера.
	Только игры на ловкость, никаких ставок. Сами игры — Arcade.client.lua,
	награду проверяет сервер (MiniGame в ClubTycoon.server.lua).
==========================================================================]]

while not (workspace:GetAttribute("CityReady") and workspace:GetAttribute("SeaReady")) do task.wait(0.5) end

local folder = Instance.new("Folder")
folder.Name = "ИгровойЗал"
folder.Parent = workspace

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do p[k] = v end
	p.Parent = props.Parent or folder
	return p
end

local function sign(p, face, text, color, font)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.LightInfluence = 0
	g.Brightness = 2
	g.Parent = p
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = font or Enum.Font.GothamBlack
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	l.Parent = g
end

-- автомат: корпус, светящийся экран с названием, кнопка E
local GAMES = {
	shoot   = { "🎯 SHOOTING", Color3.fromRGB(255, 70, 70) },
	timing  = { "⏱️ STOP ON GREEN", Color3.fromRGB(60, 255, 120) },
	stacker = { "🧱 STACKER", Color3.fromRGB(255, 200, 40) },
	hockey  = { "🏒 AIR HOCKEY", Color3.fromRGB(0, 220, 255) },
}
local function machine(cf, game, parent)
	local info = GAMES[game]
	local body = part({ Parent = parent, Name = "Автомат", Size = Vector3.new(4.5, 7.5, 3.5), CFrame = cf * CFrame.new(0, 3.75, 0), Color = Color3.fromRGB(25, 22, 40) })
	local screen = part({ Parent = parent, Size = Vector3.new(3.6, 2.6, 0.2), CFrame = cf * CFrame.new(0, 5, -1.8), Color = info[2], Material = Enum.Material.Neon, CanCollide = false })
	sign(screen, Enum.NormalId.Front, info[1], Color3.new(0, 0, 0))
	part({ Parent = parent, Size = Vector3.new(4.6, 0.4, 3.6), CFrame = cf * CFrame.new(0, 7.6, 0), Color = info[2], Material = Enum.Material.Neon, CanCollide = false })
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Play"
	pr.ObjectText = info[1]
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 8
	pr.RequiresLineOfSight = false
	pr:SetAttribute("ArcadeGame", game)   -- Arcade.client.lua откроет игру
	pr.Parent = body
	return body
end

--=========================================================================
-- Здание: 44 x 32, два этажа по 14, стеклянные стены, вход к клубам (-Z)
--=========================================================================
local spot = workspace:GetAttribute("ArcadeSpot")
if spot then
	local W, D, FH = 44, 32, 14
	local base = CFrame.new(spot)          -- пол первого этажа
	local GLASS = Color3.fromRGB(120, 60, 200)
	local NEON = { Color3.fromRGB(255, 50, 200), Color3.fromRGB(0, 230, 255) }

	part({ Name = "ПолЗала", Size = Vector3.new(W, 1, D), CFrame = base * CFrame.new(0, -0.5, 0), Color = Color3.fromRGB(20, 18, 30), Material = Enum.Material.Marble })
	-- второй этаж: пол с проёмом для лестницы (справа сзади)
	part({ Size = Vector3.new(W - 12, 1, D), CFrame = base * CFrame.new(-6, FH, 0), Color = Color3.fromRGB(20, 18, 30), Material = Enum.Material.Marble })
	part({ Size = Vector3.new(12, 1, D - 14), CFrame = base * CFrame.new(W / 2 - 6, FH, -7), Color = Color3.fromRGB(20, 18, 30), Material = Enum.Material.Marble })
	part({ Size = Vector3.new(W, 1, D), CFrame = base * CFrame.new(0, FH * 2, 0), Color = Color3.fromRGB(30, 25, 45) })   -- крыша
	-- стены: сзади и по бокам глухое стекло, спереди — вход посередине
	for _, side in ipairs({ -1, 1 }) do
		part({ Size = Vector3.new(1, FH * 2, D), CFrame = base * CFrame.new(side * W / 2, FH, 0), Color = GLASS, Material = Enum.Material.Glass, Transparency = 0.35 })
	end
	part({ Size = Vector3.new(W, FH * 2, 1), CFrame = base * CFrame.new(0, FH, D / 2), Color = GLASS, Material = Enum.Material.Glass, Transparency = 0.35 })
	for _, side in ipairs({ -1, 1 }) do   -- перед: две половины + верх над входом
		part({ Size = Vector3.new(W / 2 - 6, FH * 2, 1), CFrame = base * CFrame.new(side * (W / 4 + 3), FH, -D / 2), Color = GLASS, Material = Enum.Material.Glass, Transparency = 0.35 })
	end
	part({ Size = Vector3.new(12, FH * 2 - 10, 1), CFrame = base * CFrame.new(0, 10 + (FH * 2 - 10) / 2, -D / 2), Color = GLASS, Material = Enum.Material.Glass, Transparency = 0.35 })
	-- неоновые рёбра и полосы между этажами
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		part({ Size = Vector3.new(0.8, FH * 2, 0.8), CFrame = base * CFrame.new(c[1] * W / 2, FH, c[2] * D / 2), Color = NEON[1], Material = Enum.Material.Neon, CanCollide = false })
	end
	for _, y in ipairs({ 0.2, FH, FH * 2 }) do
		part({ Size = Vector3.new(W + 1, 0.5, D + 1), CFrame = base * CFrame.new(0, y, 0), Color = NEON[2], Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.6 })
	end
	-- вывеска над входом
	local board = part({ Size = Vector3.new(26, 6, 0.6), CFrame = base * CFrame.new(0, FH * 2 + 4, -D / 2), Color = Color3.fromRGB(10, 8, 18) })
	part({ Size = Vector3.new(27, 7, 0.3), CFrame = base * CFrame.new(0, FH * 2 + 4, -D / 2 + 0.3), Color = NEON[1], Material = Enum.Material.Neon })
	sign(board, Enum.NormalId.Front, "🕹️ ARCADE", NEON[2])
	-- лестница на второй этаж: в проёме справа сзади, от задней стены
	-- к входу, последняя ступень упирается в пол второго этажа (z = 2)
	local STEPS = 14
	for k = 0, STEPS - 1 do
		part({ Size = Vector3.new(8, 1, 1.2), CFrame = base * CFrame.new(W / 2 - 5, (k + 1) * FH / STEPS - 0.5, D / 2 - 1.5 - k), Color = Color3.fromRGB(70, 60, 100) })
	end
	-- свет внутри
	for _, y in ipairs({ FH - 2, FH * 2 - 2 }) do
		for _, x in ipairs({ -12, 12 }) do
			local lamp = part({ Size = Vector3.new(6, 0.4, 6), CFrame = base * CFrame.new(x, y, 0), Color = Color3.fromRGB(255, 220, 255), Material = Enum.Material.Neon, CanCollide = false })
			local l = Instance.new("PointLight") l.Range = 24 l.Brightness = 1.5 l.Color = Color3.fromRGB(255, 180, 255) l.Parent = lamp
		end
	end
	-- автоматы: 1 этаж — тир и «стоп», 2 этаж — башня и аэрохоккей
	-- (все стоят лицом к входу, т.е. экраном к -Z)
	machine(base * CFrame.new(-15, 0, 12), "shoot", folder)
	machine(base * CFrame.new(-8, 0, 12), "timing", folder)
	machine(base * CFrame.new(-15, 0, -4) * CFrame.Angles(0, math.rad(-90), 0), "shoot", folder)
	machine(base * CFrame.new(-15, FH + 0.5, 10), "stacker", folder)
	machine(base * CFrame.new(-6, FH + 0.5, 10), "hockey", folder)
	machine(base * CFrame.new(3, FH + 0.5, 10), "stacker", folder)
	-- стол аэрохоккея для красоты на 2 этаже
	part({ Size = Vector3.new(6, 3, 11), CFrame = base * CFrame.new(-6, FH + 2, -4), Color = Color3.fromRGB(240, 240, 250) })
	part({ Size = Vector3.new(5.6, 0.2, 10.6), CFrame = base * CFrame.new(-6, FH + 3.6, -4), Color = Color3.fromRGB(0, 200, 255), Material = Enum.Material.Neon, CanCollide = false })
	-- табличка «без ставок»
	local note = part({ Size = Vector3.new(12, 3, 0.3), CFrame = base * CFrame.new(-8, 10.5, D / 2 - 0.8) * CFrame.Angles(0, math.rad(180), 0), Color = Color3.fromRGB(10, 8, 18) })
	sign(note, Enum.NormalId.Front, "SKILL GAMES · NO BETS · FREE", Color3.fromRGB(255, 230, 120))
end

--=========================================================================
-- Лайнер: два автомата на палубе (двигаются вместе с кораблём)
--=========================================================================
for _, m in ipairs(workspace:WaitForChild("Море"):GetChildren()) do
	if m:IsA("Model") and m:GetAttribute("Ship") == "cruise" then
		local cf, size = m:GetBoundingBox()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { m }
		for k, game in ipairs({ "timing", "hockey" }) do
			local p = cf * CFrame.new(size.X * (k == 1 and -0.15 or 0.15), 0, 0)
			local hit = workspace:Raycast(p.Position + Vector3.new(0, size.Y, 0), Vector3.new(0, -size.Y * 2, 0), params)
			if hit then machine(CFrame.new(hit.Position) * cf.Rotation, game, m) end
		end
	end
end

print("[Игровой зал] ARCADE готов")
