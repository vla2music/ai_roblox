--[[=========================================================================
	ЖИЗНЬ НА ЭКРАНЕ ИГРОКА
	• экраны компов переливаются, будто на них идёт игра
	• по улицам города ездят машины с фарами
	• за владельцами геймпасса «Робо-дрон» летает светящийся дрон
==========================================================================]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

-- Экраны «с игрой»
local screens = {}
local function addScreen(g) screens[g] = math.random() * 10 end
for _, g in ipairs(CollectionService:GetTagged("GameScreen")) do addScreen(g) end
CollectionService:GetInstanceAddedSignal("GameScreen"):Connect(addScreen)
CollectionService:GetInstanceRemovedSignal("GameScreen"):Connect(function(g) screens[g] = nil end)

-- Машины: едут по кругу вокруг кварталов
local GROUND = -4
local folder = Instance.new("Folder")
folder.Name = "Машины"
folder.Parent = workspace

local function part(size, color, mat, parent)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Size, p.Color, p.Material = size, color, mat or Enum.Material.SmoothPlastic
	p.Parent = parent or folder
	return p
end

local CAR_COLORS = { Color3.fromRGB(255, 200, 30), Color3.fromRGB(220, 40, 50), Color3.fromRGB(40, 110, 230), Color3.fromRGB(240, 240, 245), Color3.fromRGB(30, 30, 35), Color3.fromRGB(60, 200, 120) }
local function makeCar(color)
	local pieces = {}
	local function add(size, offset, c, mat) table.insert(pieces, { part(size, c, mat), offset }) end
	add(Vector3.new(6, 2, 11), CFrame.new(0, 1.6, 0), color, Enum.Material.Metal)
	add(Vector3.new(5.6, 1.8, 6), CFrame.new(0, 3.4, 0.5), Color3.fromRGB(40, 50, 70), Enum.Material.Glass)
	add(Vector3.new(1.2, 0.6, 0.2), CFrame.new(-2, 1.8, -5.55), Color3.fromRGB(255, 255, 220), Enum.Material.Neon)  -- фары
	add(Vector3.new(1.2, 0.6, 0.2), CFrame.new(2, 1.8, -5.55), Color3.fromRGB(255, 255, 220), Enum.Material.Neon)
	add(Vector3.new(1.2, 0.5, 0.2), CFrame.new(-2, 1.8, 5.55), Color3.fromRGB(255, 30, 30), Enum.Material.Neon)     -- стопы
	add(Vector3.new(1.2, 0.5, 0.2), CFrame.new(2, 1.8, 5.55), Color3.fromRGB(255, 30, 30), Enum.Material.Neon)
	for _, w in ipairs({ { -3, -3.5 }, { 3, -3.5 }, { -3, 3.5 }, { 3, 3.5 } }) do
		add(Vector3.new(0.8, 1.6, 1.6), CFrame.new(w[1], 0.8, w[2]), Color3.fromRGB(20, 20, 20))
	end
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Range = 30
	light.Brightness = 2
	light.Parent = pieces[1][1]
	return pieces
end

-- маршрут: прямоугольник по улицам между рядами домов
local LOOPS = {
	-- по трассе вдоль всех клубов (две полосы)
	{ Vector3.new(-150, 2.2, 134), Vector3.new(1410, 2.2, 134), Vector3.new(1410, 2.2, 146), Vector3.new(-150, 2.2, 146) },
	-- с трассы в киберквартал и обратно
	{ Vector3.new(300, 2.2, 146), Vector3.new(300, 2.2, 235), Vector3.new(940, 2.2, 235), Vector3.new(940, 2.2, 146) },
	{ Vector3.new(300, 0, 235), Vector3.new(940, 0, 235), Vector3.new(940, 0, 355), Vector3.new(300, 0, 355) },
}
local function loopPos(loop, d)
	local total = 0
	local segs = {}
	for i = 1, #loop do
		local a, b = loop[i], loop[i % #loop + 1]
		table.insert(segs, { a, b, (b - a).Magnitude })
		total += (b - a).Magnitude
	end
	d = d % total
	for _, s in ipairs(segs) do
		if d <= s[3] then
			local pos = s[1]:Lerp(s[2], d / s[3])
			return pos + Vector3.new(0, GROUND + 0.8, 0), (s[2] - s[1]).Unit
		end
		d -= s[3]
	end
end

local cars = {}
for i = 1, 12 do
	table.insert(cars, { pieces = makeCar(CAR_COLORS[(i - 1) % #CAR_COLORS + 1]), loop = LOOPS[i <= 6 and 1 or (i <= 9 and 2 or 3)], offset = i * 170, speed = 35 + (i % 3) * 8, dir = i % 2 == 0 and 1 or -1 })
end

-- Дроны
local drones = {}
local function makeDrone()
	local pieces = {}
	local function add(size, offset, c, mat, shape)
		local p = part(size, c, mat)
		if shape then p.Shape = shape end
		table.insert(pieces, { p, offset })
	end
	add(Vector3.new(2, 2, 2), CFrame.new(), Color3.fromRGB(230, 235, 245), Enum.Material.Metal, Enum.PartType.Ball)
	add(Vector3.new(1.2, 0.5, 0.3), CFrame.new(0, 0.2, -0.9), Color3.fromRGB(0, 230, 255), Enum.Material.Neon)          -- «глаза»
	add(Vector3.new(4, 0.15, 0.4), CFrame.new(0, 0.9, 0), Color3.fromRGB(60, 60, 70))                                    -- пропеллер
	add(Vector3.new(0.4, 0.15, 4), CFrame.new(0, 0.9, 0), Color3.fromRGB(60, 60, 70))
	add(Vector3.new(2.6, 0.2, 2.6), CFrame.new(0, -0.9, 0), Color3.fromRGB(255, 60, 200), Enum.Material.Neon, Enum.PartType.Cylinder)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(0, 230, 255)
	light.Range = 12
	light.Parent = pieces[1][1]
	return pieces
end

RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	for g, phase in pairs(screens) do
		if g.Parent then
			g.Rotation = (t * 40 + phase * 36) % 360
			g.Offset = Vector2.new(math.sin(t * 1.3 + phase) * 0.3, 0)
		end
	end
	for _, c in ipairs(cars) do
		local pos, dir = loopPos(c.loop, c.offset + t * c.speed * c.dir)
		if c.dir < 0 then dir = -dir end
		local cf = CFrame.lookAt(pos, pos + dir)
		for _, p in ipairs(c.pieces) do p[1].CFrame = cf * p[2] end
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		local has = pl:GetAttribute("Pass_pet") == true
		local root = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
		local d = drones[pl]
		if has and root then
			if not d then
				-- красивый дрон из магазина Roblox (ReplicatedFirst/КлиентШаблоны/drone),
				-- если его нет — простой из деталей
				local tpl = game:GetService("ReplicatedFirst"):FindFirstChild("КлиентШаблоны")
				tpl = tpl and tpl:FindFirstChild("drone")
				d = { model = tpl and tpl:Clone(), pieces = not tpl and makeDrone() or nil, pos = root.Position }
				if d.model then d.model.Parent = folder end
				drones[pl] = d
			end
			local target = (root.CFrame * CFrame.new(3, 3 + math.sin(t * 2) * 0.5, 2)).Position
			d.pos = d.pos:Lerp(target, math.min(1, dt * 5))
			local cf = CFrame.lookAt(d.pos, d.pos + root.CFrame.LookVector) * CFrame.Angles(math.sin(t * 1.5) * 0.08, 0, math.sin(t * 1.1) * 0.08)
			if d.model then
				d.model:PivotTo(cf)
			else
				for i, p in ipairs(d.pieces) do
					local spin = (i == 3 or i == 4) and CFrame.Angles(0, t * 20, 0) or CFrame.new()
					p[1].CFrame = cf * p[2] * spin
				end
			end
		elseif d then
			if d.model then d.model:Destroy() end
			for _, p in ipairs(d.pieces or {}) do p[1]:Destroy() end
			drones[pl] = nil
		end
	end
end)
