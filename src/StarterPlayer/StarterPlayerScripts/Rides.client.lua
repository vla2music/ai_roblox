--[[=========================================================================
	АТТРАКЦИОНЫ И БЫСТРАЯ ДОРОЖКА (на компьютере игрока)
	Крутит колесо обозрения, катает вагончики по горкам,
	ускоряет игрока на дорожке.
==========================================================================]]

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local city = workspace:WaitForChild("Город", 60)
if not city then return end

-- Колесо обозрения
local wheel = city:WaitForChild("КолесоОбозрения", 30)
local hub = wheel and wheel:WaitForChild("Ось", 10)
local rotorParts = {}
if hub then
	local hubCF = CFrame.new(hub.Position)
	for _, p in ipairs(wheel:WaitForChild("Ротор"):GetChildren()) do
		table.insert(rotorParts, { part = p, offset = hubCF:ToObjectSpace(p.CFrame), upright = p:GetAttribute("Upright") })
	end
end

-- Горки
local coaster = city:WaitForChild("АмериканскиеГорки", 30)
local points = {}
local cars = {}
if coaster then
	local segs = coaster:WaitForChild("Трасса"):GetChildren()
	table.sort(segs, function(a, b) return a:GetAttribute("Index") < b:GetAttribute("Index") end)
	for _, s in ipairs(segs) do table.insert(points, s.CFrame) end
	for _, c in ipairs(coaster:GetChildren()) do
		if c.Name:match("^Вагончик") then table.insert(cars, c) end
	end
end

local WHEEL_SPEED = 0.08    -- радиан в секунду
local CAR_SPEED = 14        -- сегментов в секунду

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	if hub then
		local rot = CFrame.new(hub.Position) * CFrame.Angles(0, 0, t * WHEEL_SPEED)
		for _, r in ipairs(rotorParts) do
			local cf = rot * r.offset
			r.part.CFrame = r.upright and CFrame.new(cf.Position) or cf
		end
	end
	local n = #points
	if n > 1 then
		for _, car in ipairs(cars) do
			local f = (t * CAR_SPEED - car:GetAttribute("Offset")) % n
			local i = math.floor(f)
			local a, b = points[i + 1], points[(i + 1) % n + 1]
			car.CFrame = a:Lerp(b, f - i) * CFrame.new(0, 2, 0)
		end
	end
end)

-- Лента-конвейер: скорость частям задаём здесь, иначе персонаж не едет
local beltFolder = city:WaitForChild("Лента", 30)
if beltFolder then
	for _, b in ipairs(beltFolder:GetChildren()) do
		local v = b:IsA("BasePart") and b:GetAttribute("Vel")
		if v then b.AssemblyLinearVelocity = v end
	end
end

-- Бегущие стрелки на движущейся дорожке
local arrows = city:WaitForChild("Лента", 30)
arrows = arrows and arrows:WaitForChild("Стрелки", 10)
if arrows then
	local x1, x2, speed = arrows:GetAttribute("X1"), arrows:GetAttribute("X2"), arrows:GetAttribute("Speed")
	local list = arrows:GetChildren()
	local y, span = nil, x2 - x1
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, c in ipairs(list) do
			local x = x1 + ((c:GetAttribute("X0") - x1) + c:GetAttribute("Dir") * speed * t) % span
			c.CFrame = CFrame.new(x, c.Position.Y, c.Position.Z)
		end
	end)
end
