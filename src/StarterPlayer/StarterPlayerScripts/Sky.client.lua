--[[=========================================================================
	НЕБО: самолёты со светящимися иллюминаторами и воздушные шары
	Считается на компьютере игрока, сервер не нагружает.
==========================================================================]]

local RunService = game:GetService("RunService")

local folder = Instance.new("Folder")
folder.Name = "Небо"
folder.Parent = workspace

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do p[k] = v end
	p.Parent = folder
	return p
end

-- Самолёт: список деталей со смещениями от центра (нос смотрит в -Z)
local function makePlane()
	local pieces = {}
	local function add(size, offset, color, mat)
		table.insert(pieces, { part = part({ Size = size, Color = color, Material = mat or Enum.Material.SmoothPlastic }), offset = offset })
	end
	local white = Color3.fromRGB(235, 238, 245)
	add(Vector3.new(4, 4, 34), CFrame.new(), white)                                   -- фюзеляж
	add(Vector3.new(36, 0.6, 7), CFrame.new(0, -0.5, 1), white)                        -- крылья
	add(Vector3.new(12, 0.5, 4), CFrame.new(0, 0.5, 15), white)                        -- хвостовое крыло
	add(Vector3.new(0.5, 6, 5), CFrame.new(0, 3.5, 15), Color3.fromRGB(200, 40, 60))   -- киль
	for z = -12, 10, 2.2 do                                                           -- иллюминаторы
		add(Vector3.new(4.2, 0.9, 1), CFrame.new(0, 0.6, z), Color3.fromRGB(255, 225, 140), Enum.Material.Neon)
	end
	add(Vector3.new(0.8, 0.8, 0.8), CFrame.new(-18, -0.5, 1), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)  -- огни на крыльях
	add(Vector3.new(0.8, 0.8, 0.8), CFrame.new(18, -0.5, 1), Color3.fromRGB(40, 255, 80), Enum.Material.Neon)
	return pieces
end

local planes = {
	{ pieces = makePlane(), center = Vector3.new(600, 190, 0),   radius = 900, speed = 0.035, phase = 0 },
	{ pieces = makePlane(), center = Vector3.new(600, 230, 100), radius = 750, speed = -0.045, phase = 2 },
}

-- Воздушный шар: купол, корзина, горелка, подсветка изнутри
local function makeBalloon(color)
	local pieces = {}
	local dome = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(24, 24, 24), Color = color, Material = Enum.Material.Neon, Transparency = 0.15 })
	table.insert(pieces, { part = dome, offset = CFrame.new(0, 14, 0) })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 40
	light.Brightness = 2
	light.Parent = dome
	table.insert(pieces, { part = part({ Size = Vector3.new(4, 3, 4), Color = Color3.fromRGB(120, 80, 45), Material = Enum.Material.Wood }), offset = CFrame.new(0, -2, 0) })
	table.insert(pieces, { part = part({ Size = Vector3.new(1.2, 1.2, 1.2), Color = Color3.fromRGB(255, 170, 40), Material = Enum.Material.Neon }), offset = CFrame.new(0, 1.5, 0) })
	for _, c in ipairs({ { -1.8, -1.8 }, { 1.8, -1.8 }, { -1.8, 1.8 }, { 1.8, 1.8 } }) do
		table.insert(pieces, { part = part({ Size = Vector3.new(0.2, 6, 0.2), Color = Color3.fromRGB(60, 50, 40) }), offset = CFrame.new(c[1], 2.5, c[2]) })
	end
	return pieces
end

local balloons = {
	{ pieces = makeBalloon(Color3.fromRGB(255, 80, 150)), base = Vector3.new(250, 110, 180), phase = 0 },
	{ pieces = makeBalloon(Color3.fromRGB(80, 200, 255)), base = Vector3.new(700, 140, 160), phase = 2 },
	{ pieces = makeBalloon(Color3.fromRGB(255, 200, 60)), base = Vector3.new(1100, 120, 190), phase = 4 },
	{ pieces = makeBalloon(Color3.fromRGB(150, 255, 120)), base = Vector3.new(-150, 90, -150), phase = 5 },
	{ pieces = makeBalloon(Color3.fromRGB(255, 120, 60)), base = Vector3.new(100, 160, -300), phase = 6 },
	{ pieces = makeBalloon(Color3.fromRGB(180, 110, 255)), base = Vector3.new(400, 75, -220), phase = 7 },
	{ pieces = makeBalloon(Color3.fromRGB(255, 90, 200)), base = Vector3.new(900, 180, -280), phase = 8 },
	{ pieces = makeBalloon(Color3.fromRGB(90, 255, 220)), base = Vector3.new(1300, 100, -120), phase = 9 },
	{ pieces = makeBalloon(Color3.fromRGB(255, 230, 120)), base = Vector3.new(1450, 140, 150), phase = 10 },
	{ pieces = makeBalloon(Color3.fromRGB(120, 160, 255)), base = Vector3.new(-250, 120, 200), phase = 11 },
	{ pieces = makeBalloon(Color3.fromRGB(255, 150, 200)), base = Vector3.new(500, 210, 320), phase = 12 },
	{ pieces = makeBalloon(Color3.fromRGB(255, 255, 255)), base = Vector3.new(850, 90, 60), phase = 13 },
	{ pieces = makeBalloon(Color3.fromRGB(90, 200, 255)), base = Vector3.new(1250, 200, 320), phase = 14 },
}

local function place(pieces, cf)
	for _, p in ipairs(pieces) do p.part.CFrame = cf * p.offset end
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, pl in ipairs(planes) do
		local a = pl.phase + t * pl.speed
		local pos = pl.center + Vector3.new(math.cos(a) * pl.radius, 0, math.sin(a) * pl.radius * 0.5)
		local dir = Vector3.new(-math.sin(a), 0, math.cos(a) * 0.5) * math.sign(pl.speed)
		place(pl.pieces, CFrame.lookAt(pos, pos + dir))
	end
	for _, b in ipairs(balloons) do
		local pos = b.base + Vector3.new(math.sin(t * 0.05 + b.phase) * 60, math.sin(t * 0.3 + b.phase) * 5, math.cos(t * 0.04 + b.phase) * 25)
		place(b.pieces, CFrame.new(pos) * CFrame.Angles(0, t * 0.1, 0))
	end
end)
