--[[=========================================================================
	МИР ВОКРУГ КЛУБОВ
	Газон, горы со снежными шапками, водопады с озёрами, деревья, облака.
	Всё строится кодом при запуске сервера. Птиц рисует Birds.client.lua.
==========================================================================]]

local terrain = workspace.Terrain

-- Где стоят участки (см. CONFIG в ClubTycoon): 6 штук в ряд вдоль X
local PLOTS_FROM_X = -100
local PLOTS_TO_X   = 5 * 240 + 100
local CENTER       = Vector3.new((PLOTS_FROM_X + PLOTS_TO_X) / 2, 0, 0)

local MOUNTAIN_RX  = 1000   -- горы стоят по кругу (эллипсу) вокруг участков
local MOUNTAIN_RZ  = 480

local rng = Random.new(20260925)   -- одинаковый мир при каждом запуске

-- Газон на 4 студа ниже пола участков: террейн сглаживает поверхность
-- и чуть «вспухает» вверх, без запаса он перекрывает ковёр клуба.
local GROUND = -4

-- серая площадка из шаблона Roblox больше не нужна
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then baseplate:Destroy() end

--=========================================================================
-- Газон
--=========================================================================

terrain:FillBlock(
	CFrame.new(CENTER.X, GROUND - 6, 0),
	Vector3.new(MOUNTAIN_RX * 2 + 400, 12, MOUNTAIN_RZ * 2 + 400),
	Enum.Material.Grass
)

--=========================================================================
-- Горы
--=========================================================================

local mountains = {}
local COUNT = 36
for i = 1, COUNT do
	local angle = (i / COUNT) * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
	local radius = rng:NextNumber(110, 190)
	local pos = Vector3.new(
		CENTER.X + math.cos(angle) * (MOUNTAIN_RX + rng:NextNumber(-40, 60)),
		-radius * 0.35,
		math.sin(angle) * (MOUNTAIN_RZ + rng:NextNumber(-30, 60))
	)
	terrain:FillBall(pos, radius, Enum.Material.Rock)
	-- зелёные склоны внизу
	terrain:FillBall(pos + Vector3.new(0, -radius * 0.25, 0), radius * 0.95, Enum.Material.Grass)
	-- снежная шапка
	local top = pos + Vector3.new(0, radius * 0.72, 0)
	terrain:FillBall(top, radius * 0.4, Enum.Material.Snow)
	table.insert(mountains, { pos = pos, radius = radius, angle = angle })
	if i % 6 == 0 then task.wait() end   -- не подвешиваем сервер
end

--=========================================================================
-- Водопады: столб воды по склону горы + озеро внизу + брызги
--=========================================================================

local function waterfall(m)
	-- точка на склоне, повёрнутом к участкам
	local toCenter = (Vector3.new(CENTER.X, 0, 0) - Vector3.new(m.pos.X, 0, m.pos.Z)).Unit
	local r = m.radius
	local center = Vector3.new(m.pos.X, 0, m.pos.Z)
	-- вода стекает по поверхности горы: от вершины к подножию
	for t = 0, 1, 0.04 do
		local d = r * (0.25 + 0.72 * t)                       -- расстояние от центра горы
		local surface = m.pos.Y + math.sqrt(math.max(r * r - d * d, 0))
		local p = center + toCenter * d + Vector3.new(0, surface - 3, 0)
		terrain:FillBall(p, 7, Enum.Material.Water)
	end
	local base = center + toCenter * (r * 0.97)
	-- озеро
	local lake = base + toCenter * 40
	terrain:FillCylinder(CFrame.new(lake.X, GROUND - 2, lake.Z), 6, 42, Enum.Material.Water)
	terrain:FillCylinder(CFrame.new(lake.X, GROUND - 6.5, lake.Z), 3, 46, Enum.Material.Sand)

	-- брызги у подножия
	local mist = Instance.new("Part")
	mist.Anchored = true
	mist.CanCollide = false
	mist.Transparency = 1
	mist.Size = Vector3.new(20, 2, 20)
	mist.Position = base + toCenter * 8 + Vector3.new(0, 2, 0)
	mist.Parent = workspace

	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxasset://textures/particles/smoke_main.dds"
	particles.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255))
	particles.Transparency = NumberSequence.new(0.5, 1)
	particles.Size = NumberSequence.new(6, 14)
	particles.Lifetime = NumberRange.new(2, 3)
	particles.Rate = 12
	particles.Speed = NumberRange.new(4, 8)
	particles.SpreadAngle = Vector2.new(60, 60)
	particles.Parent = mist

end

-- два водопада позади участков и два спереди
table.sort(mountains, function(a, b) return a.pos.Z < b.pos.Z end)
waterfall(mountains[3])
waterfall(mountains[6])
waterfall(mountains[#mountains - 2])
waterfall(mountains[#mountains - 5])

--=========================================================================
-- Деревья
--=========================================================================

local treesFolder = Instance.new("Folder")
treesFolder.Name = "Деревья"
treesFolder.Parent = workspace

local function makeTree(pos)
	local height = rng:NextNumber(14, 24)
	local trunk = Instance.new("Part")
	trunk.Anchored = true
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size = Vector3.new(height, 2.2, 2.2)
	trunk.CFrame = CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	trunk.Color = Color3.fromRGB(105, 70, 45)
	trunk.Material = Enum.Material.Wood
	trunk.Parent = treesFolder

	for i = 1, 3 do
		local leaves = Instance.new("Part")
		leaves.Anchored = true
		leaves.Shape = Enum.PartType.Ball
		local s = rng:NextNumber(9, 13) - i
		leaves.Size = Vector3.new(s, s, s)
		leaves.Position = pos + Vector3.new(rng:NextNumber(-2, 2), height + i * 2.5 - 2, rng:NextNumber(-2, 2))
		leaves.Color = Color3.fromRGB(60 + rng:NextInteger(0, 30), 140 + rng:NextInteger(0, 40), 60)
		leaves.Material = Enum.Material.Grass
		leaves.Parent = treesFolder
	end
end

local placed = 0
while placed < 140 do
	local x = rng:NextNumber(CENTER.X - MOUNTAIN_RX * 0.85, CENTER.X + MOUNTAIN_RX * 0.85)
	local z = rng:NextNumber(-MOUNTAIN_RZ * 0.8, MOUNTAIN_RZ * 0.8)
	local insideEllipse = ((x - CENTER.X) / (MOUNTAIN_RX * 0.85)) ^ 2 + (z / (MOUNTAIN_RZ * 0.8)) ^ 2 < 1
	local nearPlots = x > PLOTS_FROM_X - 30 and x < PLOTS_TO_X + 30 and math.abs(z) < 110
	if insideEllipse and not nearPlots then
		makeTree(Vector3.new(x, GROUND, z))
		placed += 1
	end
end

--=========================================================================
-- Облака и дневной свет
--=========================================================================

local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
clouds.Cover = 0.55
clouds.Density = 0.6
clouds.Color = Color3.fromRGB(255, 255, 255)
clouds.Parent = terrain

terrain.WaterColor = Color3.fromRGB(60, 150, 200)
terrain.WaterTransparency = 0.4
terrain.WaterWaveSize = 0.2
terrain.WaterWaveSpeed = 12

print("[Мир] Горы, водопады и деревья готовы")
