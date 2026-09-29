--[[=========================================================================
	МАСТЕРСКАЯ «СОБЕРИ ПК» — за первой правой дверью клуба
	(дверь открывается после 2 этажа, см. refreshDoors в ClubTycoon).
	Комната стоит далеко в небе, игрока переносит модуль Zones.
	Верстаки запускают мини-игру «Собери ПК» (Arcade.client.lua),
	награду проверяет сервер (MiniGame в ClubTycoon, игра buildpc).
==========================================================================]]

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Zones        = require(script.Parent:WaitForChild("Zones"))

local ORIGIN = Zones.ORIGINS.workshop
local W, D, H = 64, 44, 16

local folder = Instance.new("Model")
folder.Name = "Мастерская"
folder.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
folder.Parent = workspace

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		if k ~= "At" then p[k] = v end
	end
	if props.At then p.CFrame = ORIGIN * props.At end
	p.Parent = props.Parent or folder
	return p
end

local function sign(p, face, text, color)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.LightInfluence = 0
	g.Parent = p
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	l.Parent = g
end

local function prompt(host, object, attrs)
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Play"   -- текст на языке игрока ставит Arcade.client.lua
	pr.ObjectText = object
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 9
	pr.RequiresLineOfSight = false
	for k, v in pairs(attrs) do pr:SetAttribute(k, v) end
	pr.Parent = host
	return pr
end

--=========================================================================
-- Комната: пол, стены, потолок, свет
--=========================================================================
local WALL = Color3.fromRGB(130, 122, 145)
part({ Size = Vector3.new(W, 1, D), At = CFrame.new(0, -0.5, 0), Color = Color3.fromRGB(70, 70, 80), Material = Enum.Material.Concrete })
part({ Size = Vector3.new(W, 1, D), At = CFrame.new(0, H + 0.5, 0), Color = Color3.fromRGB(40, 38, 50) })
for _, s in ipairs({ { 0, -D / 2, W, 1 }, { 0, D / 2, W, 1 }, { -W / 2, 0, 1, D }, { W / 2, 0, 1, D } }) do
	part({ Size = Vector3.new(s[3], H, s[4]), At = CFrame.new(s[1], H / 2, s[2]), Color = WALL })
	-- жёлто-чёрная «заводская» полоса внизу стен
	part({ Size = Vector3.new(s[3] + 0.2, 0.6, s[4] + 0.2), At = CFrame.new(s[1], 0.6, s[2]), Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Neon, CanCollide = false })
end
for _, z in ipairs({ -12, 0, 12 }) do
	part({ Size = Vector3.new(W - 8, 0.2, 1.2), At = CFrame.new(0, H - 0.1, z), Color = Color3.fromRGB(255, 245, 225), Material = Enum.Material.Neon, CanCollide = false })
end
for _, x in ipairs({ -20, 0, 20 }) do
	local lamp = part({ Size = Vector3.new(1, 1, 1), At = CFrame.new(x, H - 1, -4), Transparency = 1, CanCollide = false })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 235, 200)
	light.Range = 50
	light.Brightness = 2.5
	light.Parent = lamp
end

local board = part({ Size = Vector3.new(34, 4, 0.4), At = CFrame.new(0, 12, -D / 2 + 0.7), Color = Color3.fromRGB(20, 16, 30) })
sign(board, Enum.NormalId.Back, "🔧 NAZAR WORKSHOP · МАСТЕРСКАЯ", Color3.fromRGB(255, 210, 80))
local hint = part({ Size = Vector3.new(22, 2, 0.3), At = CFrame.new(0, 9, -D / 2 + 0.7), Color = Color3.fromRGB(20, 16, 30) })
sign(hint, Enum.NormalId.Back, "Собери ПК за 45 сек! · Build PCs in 45 sec!", Color3.fromRGB(150, 255, 180))

--=========================================================================
-- Верстаки: корпус с подсветкой, монитор, детали. Подходишь — «Собери ПК»
--=========================================================================
for i, x in ipairs({ -20, 0, 20 }) do
	local z = -D / 2 + 5
	local top = part({ Size = Vector3.new(12, 0.6, 5), At = CFrame.new(x, 3.4, z), Color = Color3.fromRGB(120, 85, 55), Material = Enum.Material.Wood })
	for _, l in ipairs({ { -5.5, -2 }, { 5.5, -2 }, { -5.5, 2 }, { 5.5, 2 } }) do
		part({ Size = Vector3.new(0.6, 3.1, 0.6), At = CFrame.new(x + l[1], 1.55, z + l[2]), Color = Color3.fromRGB(50, 50, 55), Material = Enum.Material.Metal })
	end
	-- корпус с прозрачным боком и радужной подсветкой внутри
	part({ Size = Vector3.new(2.6, 4.4, 4.2), At = CFrame.new(x + 3.5, 5.9, z), Color = Color3.fromRGB(25, 25, 30), Material = Enum.Material.Metal })
	part({ Size = Vector3.new(0.1, 3.8, 3.6), At = CFrame.new(x + 2.15, 5.9, z), Color = Color3.fromHSV(i * 0.3 % 1, 0.8, 1), Material = Enum.Material.Neon, CanCollide = false })
	-- монитор и детали на столе
	part({ Size = Vector3.new(4, 2.5, 0.3), At = CFrame.new(x - 2.5, 5.2, z - 1.5), Color = Color3.fromRGB(60, 150, 255), Material = Enum.Material.Glass })
	part({ Size = Vector3.new(2.2, 0.3, 1.2), At = CFrame.new(x - 0.5, 3.85, z + 1.2), Color = Color3.fromRGB(40, 170, 90), Material = Enum.Material.Metal })     -- видеокарта
	part({ Size = Vector3.new(0.3, 0.2, 1.6), At = CFrame.new(x - 3, 3.8, z + 1.2), Color = Color3.fromRGB(80, 200, 255), Material = Enum.Material.Neon, CanCollide = false }) -- память
	prompt(top, "🔧 Собери ПК · Build a PC", { ArcadeGame = "buildpc" })
	-- табурет
	local stool = part({ Size = Vector3.new(0.6, 2.4, 2.4), At = CFrame.new(x, 1.5, z + 4.5) * CFrame.Angles(0, 0, math.rad(90)),
		Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(200, 60, 60) })
	local _ = stool
end

--=========================================================================
-- Полки с коробками деталей, стенд с инструментами, робот-рука
--=========================================================================
for k, y in ipairs({ 3, 6.5, 10 }) do
	part({ Size = Vector3.new(2.4, 0.3, 26), At = CFrame.new(-W / 2 + 1.7, y, 2), Color = Color3.fromRGB(60, 60, 65), Material = Enum.Material.Metal })
	for b = 0, 5 do
		part({ Size = Vector3.new(1.8, 1.6, 2.2), At = CFrame.new(-W / 2 + 1.7, y + 0.95, -9 + b * 4.4), Color = Color3.fromHSV((b * 0.17 + k * 0.23) % 1, 0.55, 0.9) })
	end
end
part({ Size = Vector3.new(0.3, 8, 20), At = CFrame.new(W / 2 - 0.7, 7, 2), Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.Wood })
for t = 0, 5 do
	part({ Size = Vector3.new(0.3, 3 + (t % 2), 0.5), At = CFrame.new(W / 2 - 1, 7, -6 + t * 3.2) * CFrame.Angles(math.rad(t % 2 == 0 and 15 or -15), 0, 0),
		Color = Color3.fromRGB(170, 175, 185), Material = Enum.Material.Metal, CanCollide = false })
end

-- робот-рука медленно поворачивается над столом со сборкой
part({ Size = Vector3.new(10, 3, 6), At = CFrame.new(0, 1.5, 4), Color = Color3.fromRGB(45, 45, 55), Material = Enum.Material.Metal })
part({ Size = Vector3.new(2.4, 4, 4.4), At = CFrame.new(-2.5, 5, 4), Color = Color3.fromRGB(25, 25, 30), Material = Enum.Material.Metal })
part({ Size = Vector3.new(0.1, 3.4, 3.8), At = CFrame.new(-1.25, 5, 4), Color = Color3.fromRGB(255, 80, 200), Material = Enum.Material.Neon, CanCollide = false })
local base = part({ Size = Vector3.new(1.5, 3, 3), At = CFrame.new(4, 4.5, 4) * CFrame.Angles(0, 0, math.rad(90)), Shape = Enum.PartType.Cylinder,
	Color = Color3.fromRGB(255, 170, 40), Material = Enum.Material.Metal })
local arm = Instance.new("Model")
arm.Name = "РобоРука"
arm.Parent = folder
local a1 = part({ Parent = arm, Size = Vector3.new(0.9, 5, 0.9), At = CFrame.new(4, 7.5, 4), Color = Color3.fromRGB(255, 170, 40), Material = Enum.Material.Metal })
part({ Parent = arm, Size = Vector3.new(4.5, 0.8, 0.8), At = CFrame.new(1.9, 9.8, 4), Color = Color3.fromRGB(255, 170, 40), Material = Enum.Material.Metal })
part({ Parent = arm, Size = Vector3.new(0.8, 1.6, 0.8), At = CFrame.new(-0.2, 9, 4), Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Metal })
part({ Parent = arm, Size = Vector3.new(0.5, 0.5, 0.5), At = CFrame.new(-0.2, 8, 4), Color = Color3.fromRGB(0, 230, 255), Material = Enum.Material.Neon, CanCollide = false })
arm.PrimaryPart = a1
local _ = base
task.spawn(function()
	local pivot = a1.CFrame
	local angle = 0
	while arm.Parent do
		angle = angle == 0 and 70 or 0
		local target = pivot * CFrame.Angles(0, math.rad(angle), 0)
		local v = Instance.new("CFrameValue")
		v.Value = arm:GetPivot()
		v.Changed:Connect(function(cf) arm:PivotTo(cf) end)
		local tw = TweenService:Create(v, TweenInfo.new(2.5, Enum.EasingStyle.Sine), { Value = target })
		tw:Play()
		tw.Completed:Wait()
		v:Destroy()
		task.wait(1.5)
	end
end)

-- мастер у робота
local ok, npc = pcall(function()
	local d = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(198, 140, 100)
	d.HeadColor, d.LeftArmColor, d.RightArmColor = skin, skin, skin
	d.TorsoColor = Color3.fromRGB(40, 90, 170)
	d.LeftLegColor, d.RightLegColor = Color3.fromRGB(40, 60, 90), Color3.fromRGB(40, 60, 90)
	return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
end)
if ok and npc then
	npc.Name = "Мастер"
	npc.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	for _, d in ipairs(npc:GetDescendants()) do
		if d:IsA("BasePart") then d.CanCollide = false d.Anchored = d.Name == "HumanoidRootPart" end
	end
	local y = npc.Humanoid.HipHeight + npc.HumanoidRootPart.Size.Y / 2
	npc:PivotTo(ORIGIN * CFrame.lookAt(Vector3.new(9, y, 8), Vector3.new(0, y, 4)))
	npc.Parent = folder
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 200, 0, 40)
	bb.StudsOffset = Vector3.new(0, 2.5, 0)
	bb.MaxDistance = 35
	bb.Parent = npc.Head
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(255, 210, 80)
	l.TextStrokeTransparency = 0.4
	l.Text = "🔧 Mechanic · Мастер"
	l.Parent = bb
end

--=========================================================================
-- Дверь назад в клуб и место появления
--=========================================================================
local door = part({ Size = Vector3.new(6, 9, 0.4), At = CFrame.new(0, 4.5, D / 2 - 0.7), Color = Color3.fromRGB(70, 50, 40), Material = Enum.Material.Wood })
for _, s in ipairs({ { -3.3, 4.7, 0.4, 9.6 }, { 3.3, 4.7, 0.4, 9.6 }, { 0, 9.4, 7, 0.4 } }) do
	part({ Size = Vector3.new(s[3], s[4], 0.5), At = CFrame.new(s[1], s[2], D / 2 - 0.8), Color = Color3.fromRGB(80, 255, 140), Material = Enum.Material.Neon, CanCollide = false })
end
local exit = prompt(door, "🚪 Club · Клуб", { ZoneExit = true })
exit.ActionText = "Back"
exit.Triggered:Connect(function(player) Zones.leave(player) end)

Zones.register("workshop", ORIGIN * CFrame.new(0, 3.5, D / 2 - 6))
print("[Мастерская] Готова")
