--[[=========================================================================
	ПАРАПЛАН: старт с крыши самого высокого небоскрёба, трасса из колец
	над клубами к морю. Каждое следующее кольцо дороже, за всю трассу бонус.
	Полёт рисует и ведёт Paraglider.client.lua; сервер проверяет, что игрок
	правда рядом с кольцом и летит по порядку.
==========================================================================]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RINGS    = 14
local STEP     = 70     -- расстояние между кольцами
local DROP     = 7      -- на сколько ниже каждое следующее
local RING_R   = 12     -- радиус кольца

while not workspace:GetAttribute("CityReady") do task.wait(0.5) end

local remote = Instance.new("RemoteEvent")
remote.Name = "GliderRing"
remote.Parent = ReplicatedStorage

local folder = Instance.new("Folder")
folder.Name = "Параплан"
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

-- самый высокий небоскрёб
local tallest
for _, p in ipairs(workspace:WaitForChild("Город"):GetChildren()) do
	if p.Name == "Небоскрёб" and (not tallest or p.Size.Y > tallest.Size.Y) then tallest = p end
end
local roofY = tallest.Position.Y + tallest.Size.Y / 2
-- старт на краю крыши, лицом к клубам (-Z)
local launch = Vector3.new(tallest.Position.X, roofY + 3, tallest.Position.Z - tallest.Size.Z / 2 - 4)

--=========================================================================
-- Трасса: прямо к морю, потом плавный поворот вдоль берега к центру
--=========================================================================
local points = {}
local pos, heading = launch, Vector3.new(0, 0, -1)
local turn = launch.X > 600 and -1 or 1          -- поворачиваем к середине
for i = 1, RINGS do
	if i >= 5 and i <= 7 then   -- три кольца по 30° — поворот на 90° над набережной, мимо лайнера
		local a = math.rad(30 * (i - 4))
		heading = Vector3.new(math.sin(a) * turn, 0, -math.cos(a))
	end
	pos = pos + heading * STEP + Vector3.new(0, -DROP, 0)
	points[i] = { pos = pos, dir = heading }
end

-- кольцо из 16 неоновых кусочков; невидимый центр хранит номер
for i, pt in ipairs(points) do
	local color = Color3.fromHSV(i / RINGS * 0.8, 0.8, 1)
	local cf = CFrame.lookAt(pt.pos, pt.pos + pt.dir)
	local center = part({ Name = "Кольцо", Size = Vector3.new(1, 1, 1), CFrame = cf, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	center:SetAttribute("Index", i)
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2
		part({ Parent = center, Name = "Дуга", Size = Vector3.new(1.2, 5, 1.2),
			CFrame = cf * CFrame.Angles(0, 0, a) * CFrame.new(0, RING_R, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = color, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
	end
end
folder:SetAttribute("Rings", RINGS)
folder:SetAttribute("RingRadius", RING_R)

--=========================================================================
-- Стартовая площадка
--=========================================================================
local pad = part({ Name = "Старт", Size = Vector3.new(10, 0.6, 6), Position = Vector3.new(launch.X, roofY + 0.4, launch.Z + 7),
	Color = Color3.fromRGB(60, 255, 140), Material = Enum.Material.Neon })
local board = part({ Size = Vector3.new(12, 4, 0.4), Position = pad.Position + Vector3.new(0, 7, 3.5), Color = Color3.fromRGB(15, 15, 25) })
for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
	local g = Instance.new("SurfaceGui") g.Face = face g.LightInfluence = 0 g.Parent = board
	local t = Instance.new("TextLabel") t.Size = UDim2.fromScale(1, 1) t.BackgroundTransparency = 1 t.Font = Enum.Font.GothamBlack
	t.TextScaled = true t.Text = "🪂 PARAGLIDER · 14 RINGS" t.TextColor3 = Color3.fromRGB(60, 255, 140) t.Parent = g
end
-- видно издалека: как попасть наверх
local sign = part({ Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, Position = pad.Position + Vector3.new(0, 16, 0) })
local bg = Instance.new("BillboardGui") bg.Size = UDim2.new(0, 260, 0, 44) bg.MaxDistance = 900 bg.Parent = sign
local bl = Instance.new("TextLabel") bl.Size = UDim2.fromScale(1, 1) bl.BackgroundTransparency = 1 bl.Font = Enum.Font.GothamBlack
bl.TextScaled = true bl.Text = "🪂 PARAGLIDER" bl.TextColor3 = Color3.fromRGB(60, 255, 140) bl.TextStrokeTransparency = 0.4 bl.Parent = bg

local runs = {}   -- [player] = { next = номер кольца, count = сколько пройдено }

local pr = Instance.new("ProximityPrompt")
pr.ActionText = "Fly!"
pr.ObjectText = "🪂 Paraglider"
pr.HoldDuration = 0
pr.MaxActivationDistance = 10
pr.RequiresLineOfSight = false
pr.Parent = pad
local function startRun(player)
	local char = player.Character
	if not char then return end
	runs[player] = { next = 1, count = 0, earned = 0 }
	char:PivotTo(CFrame.lookAt(launch, launch + Vector3.new(0, 0, -1)))
	player:SetAttribute("GliderRun", (player:GetAttribute("GliderRun") or 0) + 1)   -- клиент начнёт полёт
end
pr.Triggered:Connect(startRun)
-- для проверки из Studio: ServerStorage.DevStartGlider:Fire(player)
local dev = Instance.new("BindableEvent")
dev.Name = "DevStartGlider"
dev.Event:Connect(startRun)
dev.Parent = game:GetService("ServerStorage")

-- награда за кольцо: чем больше колец подряд — тем дороже каждое
local function base(player)
	return math.max(25, math.floor((player:GetAttribute("ChestValue") or 0) * 0.02))
end

remote.OnServerEvent:Connect(function(player, index)
	local run = runs[player]
	if not run or type(index) ~= "number" or index < run.next or index > RINGS then return end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - points[index].pos).Magnitude > RING_R + 20 then return end
	run.next = index + 1
	run.count += 1
	local amount = math.floor(base(player) * (1 + 0.25 * run.count))
	if run.count == RINGS then amount += base(player) * 10 end   -- вся трасса без пропусков
	run.earned += amount
	player.leaderstats.Coins.Value += amount
	remote:FireClient(player, index, amount, run.count, run.earned)
	if index == RINGS then runs[player] = nil end
end)
Players.PlayerRemoving:Connect(function(p) runs[p] = nil end)

print("[Параплан] Трасса из", RINGS, "колец готова на высоте", math.floor(roofY))
