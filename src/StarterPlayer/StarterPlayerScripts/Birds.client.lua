--[[=========================================================================
	ПТИЦЫ
	Стайки птиц кружат над клубами. Считаются на компьютере игрока,
	поэтому сервер не нагружают.
==========================================================================]]

local RunService = game:GetService("RunService")

local CENTER_X = 600      -- середина ряда участков
local FLOCKS   = 5
local PER_FLOCK = 4

local folder = Instance.new("Folder")
folder.Name = "Птицы"
folder.Parent = workspace

local function part(size, color)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = folder
	return p
end

local birds = {}
for f = 1, FLOCKS do
	local flock = {
		center = Vector3.new(CENTER_X + math.random(-700, 700), math.random(70, 130), math.random(-250, 250)),
		radius = math.random(60, 160),
		speed = (math.random() * 0.15 + 0.1) * (math.random() < 0.5 and -1 or 1),
		phase = math.random() * math.pi * 2,
	}
	for i = 1, PER_FLOCK do
		table.insert(birds, {
			flock = flock,
			offset = Vector3.new(math.random(-8, 8), math.random(-4, 4), math.random(-8, 8)),
			flap = math.random() * math.pi * 2,
			body = part(Vector3.new(0.7, 0.5, 1.6), Color3.fromRGB(40, 40, 45)),
			left = part(Vector3.new(2.2, 0.1, 0.9), Color3.fromRGB(55, 55, 60)),
			right = part(Vector3.new(2.2, 0.1, 0.9), Color3.fromRGB(55, 55, 60)),
		})
	end
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, b in ipairs(birds) do
		local fl = b.flock
		local a = fl.phase + t * fl.speed
		local pos = fl.center + Vector3.new(math.cos(a) * fl.radius, math.sin(t * 0.5 + fl.phase) * 6, math.sin(a) * fl.radius) + b.offset
		-- направление полёта — по касательной к кругу
		local dir = Vector3.new(-math.sin(a), 0, math.cos(a)) * math.sign(fl.speed)
		local cf = CFrame.lookAt(pos, pos + dir)
		local wing = math.sin(t * 9 + b.flap) * 0.6
		b.body.CFrame = cf
		b.left.CFrame = cf * CFrame.new(-0.35, 0, 0) * CFrame.Angles(0, 0, wing) * CFrame.new(-1.1, 0, 0)
		b.right.CFrame = cf * CFrame.new(0.35, 0, 0) * CFrame.Angles(0, 0, -wing) * CFrame.new(1.1, 0, 0)
	end
end)
