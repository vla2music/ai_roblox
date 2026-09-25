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

-- Быстрая дорожка: пока стоишь на ней — скорость x3
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { city }

while true do
	task.wait(0.15)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if root and hum then
		local base = player:GetAttribute("Pass_speed") == true and 28 or 16
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -6, 0), params)
		local onPath = hit and hit.Instance:GetAttribute("SpeedPath") == true
		hum.WalkSpeed = onPath and 48 or base
	end
end
