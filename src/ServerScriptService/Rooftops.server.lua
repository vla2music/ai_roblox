--[[=========================================================================
	КРЫШИ И ПАЛУБЫ
	У каждого небоскрёба лифт (дверь внизу, со стороны клубов) — везёт на крышу.
	На каждой крыше парашют: прыгай на соседние крыши.
	На части крыш и на палубах яхт и лайнера — сундуки с монетами.
	У каждого игрока на каждый сундук перерыв 10 минут.
==========================================================================]]

local Players = game:GetService("Players")

local COOLDOWN = 600
local ROOF_CHESTS = 8          -- сколько крыш получат сундук

while not (workspace:GetAttribute("CityReady") and workspace:GetAttribute("SeaReady")) do task.wait(0.5) end

local rng = Random.new(31337)
local folder = Instance.new("Folder")
folder.Name = "Крыши"
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

local function prompt(parent, action, object)
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = action
	pr.ObjectText = object
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 10
	pr.RequiresLineOfSight = false
	pr.Parent = parent
	return pr
end

--=========================================================================
-- Сундук: share — какая доля «цены сундука» игрока (ChestValue) внутри
--=========================================================================
local WOOD, GOLD = Color3.fromRGB(110, 60, 30), Color3.fromRGB(255, 195, 50)
local lastOpened = {}   -- [player][chest] = время

local function chest(cf, parent, share)
	local m = Instance.new("Model")
	m.Name = "Сундук"
	local body = part({ Parent = m, Size = Vector3.new(4, 2.4, 2.8), CFrame = cf * CFrame.new(0, 1.2, 0), Color = WOOD, Material = Enum.Material.WoodPlanks })
	part({ Parent = m, Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 2.8, 2.8), CFrame = cf * CFrame.new(0, 2.4, 0), Color = WOOD, Material = Enum.Material.WoodPlanks, CanCollide = false })
	for _, dx in ipairs({ -1.5, 1.5 }) do
		part({ Parent = m, Size = Vector3.new(0.3, 2.5, 2.9), CFrame = cf * CFrame.new(dx, 1.2, 0), Color = GOLD, Material = Enum.Material.Metal, CanCollide = false })
	end
	part({ Parent = m, Size = Vector3.new(0.8, 0.9, 0.3), CFrame = cf * CFrame.new(0, 2.2, -1.5), Color = GOLD, Material = Enum.Material.Metal, CanCollide = false })
	local s = Instance.new("Sparkles") s.SparkleColor = GOLD s.Parent = body
	local l = Instance.new("PointLight") l.Color = GOLD l.Range = 14 l.Brightness = 2 l.Parent = body
	m.PrimaryPart = body
	m.Parent = parent

	local pr = prompt(body, "Open", "💰 Chest")
	pr.Triggered:Connect(function(player)
		if not player:FindFirstChild("leaderstats") then return end
		lastOpened[player] = lastOpened[player] or {}
		local t = lastOpened[player][m]
		if t and os.clock() - t < COOLDOWN then
			local left = math.ceil((COOLDOWN - (os.clock() - t)) / 60)
			player:SetAttribute("ChestWait", nil)
			player:SetAttribute("ChestWait", left)   -- экран покажет «через N мин»
			return
		end
		lastOpened[player][m] = os.clock()
		local amount = math.max(200, math.floor((player:GetAttribute("ChestValue") or 0) * share))
		player.leaderstats.Coins.Value += amount
		player:SetAttribute("ChestBonus", nil)
		player:SetAttribute("ChestBonus", amount)
	end)
	return m
end
Players.PlayerRemoving:Connect(function(p) lastOpened[p] = nil end)

--=========================================================================
-- Небоскрёбы: лифт, парашют, сундуки
--=========================================================================
local towers = {}
for _, p in ipairs(workspace:WaitForChild("Город"):GetChildren()) do
	if p.Name == "Небоскрёб" then table.insert(towers, p) end
end

local function giveParachute(player)
	-- Parachute.client.lua покажет кнопку; новое число — чтобы заметил и повтор
	player:SetAttribute("Parachute", (player:GetAttribute("Parachute") or 0) + 1)
end

for _, t in ipairs(towers) do
	local cf, size = t.CFrame, t.Size
	local roofY = cf.Y + size.Y / 2
	-- дверь лифта на фасаде к клубам (-Z)
	local door = part({ Name = "Лифт", Size = Vector3.new(6, 8, 0.4), Position = Vector3.new(cf.X, cf.Y - size.Y / 2 + 4, cf.Z - size.Z / 2 - 0.3),
		Color = Color3.fromRGB(190, 190, 205), Material = Enum.Material.Metal })
	part({ Size = Vector3.new(7, 9, 0.2), Position = door.Position + Vector3.new(0, 0.5, -0.1), Color = Color3.fromRGB(0, 230, 255), Material = Enum.Material.Neon, CanCollide = false })
	local top = Vector3.new(cf.X, roofY + 3.5, cf.Z)
	prompt(door, "Roof", "🛗 Lift").Triggered:Connect(function(player)
		local char = player.Character
		if char then char:PivotTo(CFrame.new(top)) end
	end)
	-- на крыше: будка лифта (вниз) и стойка с парашютом
	local booth = part({ Size = Vector3.new(6, 8, 6), Position = Vector3.new(cf.X - size.X / 2 + 5, roofY + 4, cf.Z + size.Z / 2 - 5), Color = Color3.fromRGB(60, 60, 75), Material = Enum.Material.Metal })
	local ground = Vector3.new(cf.X, cf.Y - size.Y / 2 + 3.5, cf.Z - size.Z / 2 - 5)
	prompt(booth, "Down", "🛗 Lift").Triggered:Connect(function(player)
		local char = player.Character
		if char then char:PivotTo(CFrame.new(ground)) end
	end)
	local rack = part({ Size = Vector3.new(2.5, 3.5, 1.6), Position = Vector3.new(cf.X + size.X / 2 - 4, roofY + 1.75, cf.Z + size.Z / 2 - 4), Color = Color3.fromRGB(230, 70, 60), Material = Enum.Material.Fabric })
	prompt(rack, "Take parachute", "🪂").Triggered:Connect(giveParachute)
end

-- сундуки на случайных крышах
for i = 1, math.min(ROOF_CHESTS, #towers) do
	local t = table.remove(towers, rng:NextInteger(1, #towers))
	local roof = t.Position + Vector3.new(rng:NextNumber(-5, 5), t.Size.Y / 2, rng:NextNumber(-5, 5))
	chest(CFrame.new(roof) * CFrame.Angles(0, math.rad(rng:NextInteger(0, 359)), 0), folder, 0.25)
end

--=========================================================================
-- Палубы: сундук на каждом судне (двигается вместе с ним — лежит внутри модели)
--=========================================================================
for _, m in ipairs(workspace:WaitForChild("Море"):GetChildren()) do
	if m:IsA("Model") and m:GetAttribute("Ship") then
		local cf, size = m:GetBoundingBox()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { m }
		local hit = workspace:Raycast(cf.Position + Vector3.new(0, size.Y, 0), Vector3.new(0, -size.Y * 2, 0), params)
		if hit then
			chest(CFrame.new(hit.Position) * cf.Rotation, m, m:GetAttribute("Ship") == "cruise" and 0.6 or 0.4)
		end
	end
end

print("[Крыши] Лифты:", #folder:GetChildren(), "деталей; сундуки на крышах и палубах готовы")
