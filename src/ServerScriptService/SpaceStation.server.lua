--[[=========================================================================
	КОСМИЧЕСКАЯ СТАНЦИЯ — куда уносит VR-шлем на 2 этаже (VR-зона).
	Слабая гравитация (ZoneFX.client.lua), станция со стеклянным куполом,
	прыжки по астероидам к спутнику с наградой (5 минут дохода, раз в 20 минут).
==========================================================================]]

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Zones        = require(script.Parent:WaitForChild("Zones"))
local Analytics    = require(script.Parent:WaitForChild("Analytics"))

local ORIGIN = Zones.ORIGINS.space
local REWARD_MIN, COOLDOWN = 5, 20 * 60
local START = ORIGIN * CFrame.new(0, 3.5, 8)

local world = Instance.new("Model")
world.Name = "КосмическаяСтанция"
world.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
world.Parent = workspace

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do if k ~= "At" then p[k] = v end end
	if props.At then p.CFrame = ORIGIN * props.At end
	p.Parent = world
	return p
end

local function toast(player, ru, en)
	player:SetAttribute("Toast", nil)
	player:SetAttribute("Toast", player.LocaleId:sub(1, 2) == "ru" and ru or en)
end

local function label(host, text, color)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 260, 0, 50)
	bb.StudsOffset = Vector3.new(0, 5, 0)
	bb.MaxDistance = 80
	bb.Parent = host
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.3
	l.Text = text
	l.Parent = bb
end

local function prompt(host, object, action)
	local pr = Instance.new("ProximityPrompt")
	pr.ObjectText = object
	pr.ActionText = action
	pr.HoldDuration = 0.3
	pr.MaxActivationDistance = 10
	pr.RequiresLineOfSight = false
	pr.Parent = host
	return pr
end

--=========================================================================
-- Небо: планета, кольцо, звёзды
--=========================================================================
local planet = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(400, 400, 400), At = CFrame.new(-260, 80, -760),
	Color = Color3.fromRGB(70, 110, 220), Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.1 })
local _ = planet
part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 620, 620), At = CFrame.new(-260, 80, -760) * CFrame.Angles(0, math.rad(20), math.rad(75)),
	Color = Color3.fromRGB(255, 200, 120), Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.6 })
local rng = Random.new(11)
for _ = 1, 60 do
	local s = rng:NextNumber(0.6, 1.6)
	part({ Shape = Enum.PartType.Ball, Size = Vector3.new(s, s, s), At = CFrame.new(rng:NextNumber(-300, 300), rng:NextNumber(40, 250), rng:NextNumber(-500, 200)),
		Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, CanCollide = false })
end

--=========================================================================
-- Станция: круглая площадка, стеклянный купол из колец, VR-выход
--=========================================================================
part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 40, 40), At = CFrame.new(0, -0.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
	Color = Color3.fromRGB(200, 205, 215), Material = Enum.Material.DiamondPlate })
part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 41, 41), At = CFrame.new(0, -0.9, 0) * CFrame.Angles(0, 0, math.rad(90)),
	Color = Color3.fromRGB(80, 200, 255), Material = Enum.Material.Neon, CanCollide = false })
for i = 0, 7 do   -- «рёбра» купола
	local a = math.rad(i * 45)
	part({ Size = Vector3.new(0.6, 14, 0.6), At = CFrame.new(math.cos(a) * 19, 7, math.sin(a) * 19), Color = Color3.fromRGB(220, 225, 235), Material = Enum.Material.Metal })
end
part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 40, 40), At = CFrame.new(0, 14, 0) * CFrame.Angles(0, 0, math.rad(90)),
	Color = Color3.fromRGB(160, 220, 255), Material = Enum.Material.Glass, Transparency = 0.7 })
local lamp = part({ Size = Vector3.new(1, 1, 1), At = CFrame.new(0, 12, 0), Transparency = 1, CanCollide = false })
local light = Instance.new("PointLight") light.Range = 40 light.Brightness = 1.5 light.Color = Color3.fromRGB(200, 220, 255) light.Parent = lamp
local sign = part({ Size = Vector3.new(1, 1, 1), At = CFrame.new(0, 8, -8), Transparency = 1, CanCollide = false })
label(sign, "🚀 SPACE STATION NAZAR · КОСМОС", Color3.fromRGB(150, 220, 255))

-- выход: стойка со шлемом «снять VR»
local stand = part({ Size = Vector3.new(1.6, 4, 1.6), At = CFrame.new(0, 2, 14), Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Metal })
part({ Size = Vector3.new(1.8, 1, 1.4), At = CFrame.new(0, 4.5, 14), Color = Color3.fromRGB(245, 245, 250) })
local exit = prompt(stand, "🥽 VR", "Back")
exit:SetAttribute("ZoneExit", true)
exit.Triggered:Connect(function(player) Zones.leave(player) end)
Zones.register("space", START)

--=========================================================================
-- Астероиды к спутнику (гравитация слабая — прыжки длинные)
--=========================================================================
local last
for i = 1, 10 do
	local a = i * 0.55
	local pos = CFrame.new(math.sin(a) * 14, 3 + i * 4, -26 - i * 16)
	local s = rng:NextNumber(7, 10)
	part({ Shape = Enum.PartType.Ball, Size = Vector3.new(s, s * 0.6, s), At = pos * CFrame.new(0, -s * 0.3, 0),
		Color = Color3.fromRGB(170 + i * 5, 150, 140), Material = Enum.Material.Slate })
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, s + 1, s + 1), At = pos * CFrame.new(0, -0.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 180, 80), Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.4 })
	last = pos
end
-- спутник с наградой
local satAt = last * CFrame.new(0, 6, -26)
part({ Size = Vector3.new(16, 1, 16), At = satAt * CFrame.new(0, -0.5, 0), Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.DiamondPlate })
for _, x in ipairs({ -14, 14 }) do
	part({ Size = Vector3.new(12, 0.3, 6), At = satAt * CFrame.new(x, 2, 0), Color = Color3.fromRGB(40, 70, 180), Material = Enum.Material.Glass })
end
local chest = part({ Size = Vector3.new(5, 3.5, 3.5), At = satAt * CFrame.new(0, 1.75, 0), Color = Color3.fromRGB(230, 230, 240), Material = Enum.Material.Metal })
part({ Size = Vector3.new(5.2, 0.4, 3.7), At = satAt * CFrame.new(0, 2.6, 0), Color = Color3.fromRGB(255, 200, 60), Material = Enum.Material.Neon, CanCollide = false })
label(chest, "🛰 SATELLITE · СПУТНИК", Color3.fromRGB(255, 220, 120))
local open = prompt(chest, "🛰 SPACE CHEST", "Open")
open.Triggered:Connect(function(player)
	local ready = player:GetAttribute("SpaceReadyAt") or 0
	if ready > os.time() then
		local m = math.ceil((ready - os.time()) / 60)
		toast(player, "⏳ Сундук снова через " .. m .. " мин.", "⏳ Chest again in " .. m .. " min.")
		return
	end
	local stats = player:FindFirstChild("Stats")
	local money = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Coins")
	if not stats or not money then return end
	local amount = math.max(100, math.floor(stats.Income.Value * 60 * REWARD_MIN))
	money.Value += amount
	Analytics.source(player, amount, "SpaceChest")
	player:SetAttribute("SpaceReadyAt", os.time() + COOLDOWN)
	toast(player, "🛰 Космический сундук! +" .. amount, "🛰 Space chest! +" .. amount)
end)

-- упал в космос — обратно на станцию
local void = part({ Size = Vector3.new(700, 2, 700), At = CFrame.new(0, -70, -150), Transparency = 1, CanCollide = false })
void.Touched:Connect(function(hit)
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if player then hit.Parent:PivotTo(START) end
end)

-- ракета медленно летает вокруг станции
local rocket = part({ Size = Vector3.new(2, 2, 7), At = CFrame.new(60, 30, 0), Color = Color3.fromRGB(240, 240, 245), Material = Enum.Material.Metal, CanCollide = false })
local flame = Instance.new("Fire") flame.Size = 3 flame.Heat = 0 flame.Color = Color3.fromRGB(255, 140, 40) flame.Parent = rocket
task.spawn(function()
	local t = 0
	while rocket.Parent do
		t += task.wait(0.05) * 0.15
		local p = ORIGIN * CFrame.new(math.cos(t) * 60, 30 + math.sin(t * 2) * 6, math.sin(t) * 60)
		rocket.CFrame = CFrame.lookAt(p.Position, (ORIGIN * CFrame.new(math.cos(t + 0.1) * 60, 30, math.sin(t + 0.1) * 60)).Position)
	end
end)

print("[Космос] Станция готова")
