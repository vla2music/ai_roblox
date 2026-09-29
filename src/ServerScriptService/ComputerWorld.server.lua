--[[=========================================================================
	«ВНУТРИ КОМПЬЮТЕРА» — параллельная реальность за тайной дверью «???».
	Чтобы войти, нужно найти в городе 3 ключ-карты (атрибут KeyCards, биты 1/2/4,
	сохраняется в ClubTycoon). Внутри — неоновая дорожка из платформ над пустотой,
	в конце «Сердце сервера» с наградой (6 минут дохода, раз в 20 минут).
==========================================================================]]

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Zones        = require(script.Parent:WaitForChild("Zones"))
local Analytics    = require(script.Parent:WaitForChild("Analytics"))

local ORIGIN = Zones.ORIGINS.computer
local CYAN, PINK = Color3.fromRGB(0, 230, 255), Color3.fromRGB(255, 60, 200)
local REWARD_MIN, COOLDOWN = 6, 20 * 60

local world = Instance.new("Model")
world.Name = "ВнутриКомпьютера"
world.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
world.Parent = workspace

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do if k ~= "At" and k ~= "World" then p[k] = v end end
	if props.At then p.CFrame = ORIGIN * props.At end
	if props.World then p.CFrame = props.World end
	p.Parent = props.Parent or world
	return p
end

local function toast(player, ru, en)
	player:SetAttribute("Toast", nil)
	player:SetAttribute("Toast", player.LocaleId:sub(1, 2) == "ru" and ru or en)
end

local function label(host, text, color)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 260, 0, 50)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.MaxDistance = 60
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
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 10
	pr.RequiresLineOfSight = false
	pr.Parent = host
	return pr
end

--=========================================================================
-- Мир: сетка внизу, летающие кубики-данные, дорожка платформ
--=========================================================================
for i = -10, 10 do
	part({ Size = Vector3.new(0.4, 0.2, 400), At = CFrame.new(i * 20, -80, -150), Color = CYAN, Material = Enum.Material.Neon, CanCollide = false })
	part({ Size = Vector3.new(400, 0.2, 0.4), At = CFrame.new(0, -80, -150 + i * 20), Color = PINK, Material = Enum.Material.Neon, CanCollide = false })
end
local rng = Random.new(7)
for _ = 1, 40 do
	local s = rng:NextNumber(1, 4)
	part({ Size = Vector3.new(s, s, s), At = CFrame.new(rng:NextNumber(-90, 90), rng:NextNumber(-40, 60), rng:NextNumber(-320, 20)) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0),
		Color = rng:NextNumber() < 0.5 and CYAN or PINK, Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.3 })
end

-- старт: площадка, дверь назад, вывеска
local start = part({ Size = Vector3.new(24, 1, 24), At = CFrame.new(0, -0.5, 0), Color = Color3.fromRGB(10, 20, 35), Material = Enum.Material.Glass })
part({ Size = Vector3.new(24.4, 0.3, 24.4), At = CFrame.new(0, -0.9, 0), Color = CYAN, Material = Enum.Material.Neon, CanCollide = false })
local sign = part({ Size = Vector3.new(1, 1, 1), At = CFrame.new(0, 6, -10), Transparency = 1, CanCollide = false })
label(sign, "🖥 INSIDE THE COMPUTER · ВНУТРИ КОМПЬЮТЕРА", CYAN)
local door = part({ Size = Vector3.new(6, 9, 0.5), At = CFrame.new(0, 4.5, 11), Color = Color3.fromRGB(20, 20, 30), Material = Enum.Material.Glass, Transparency = 0.3 })
for _, s in ipairs({ { -3.3, 4.7, 0.4, 9.6 }, { 3.3, 4.7, 0.4, 9.6 }, { 0, 9.4, 7, 0.4 } }) do
	part({ Size = Vector3.new(s[3], s[4], 0.6), At = CFrame.new(s[1], s[2], 11), Color = Color3.fromRGB(80, 255, 140), Material = Enum.Material.Neon, CanCollide = false })
end
local exit = prompt(door, "🚪", "Back")
exit:SetAttribute("ZoneExit", true)
exit.Triggered:Connect(function(player) Zones.leave(player) end)
Zones.register("computer", ORIGIN * CFrame.new(0, 3.5, 6))

-- дорожка: платформы поднимаются змейкой, посередине — точка сохранения
local checkpoint = {}          -- игрок -> CFrame, куда вернуть после падения
local CHECK_AT = 8
local last = CFrame.new(0, 0, 0)
local cpPad
for i = 1, 15 do
	local x = (i % 2 == 0) and 6 or -6
	if i % 5 == 0 then x = 0 end
	local pos = CFrame.new(x, i * 1.8, -10 - i * 13)
	local big = i == CHECK_AT
	local size = big and Vector3.new(16, 1, 16) or Vector3.new(i % 3 == 0 and 6 or 10, 1, i % 3 == 0 and 6 or 10)
	local p = part({ Size = size, At = pos * CFrame.new(0, -0.5, 0), Color = Color3.fromRGB(10, 20, 35), Material = Enum.Material.Glass })
	part({ Size = size + Vector3.new(0.4, -0.7, 0.4), At = pos * CFrame.new(0, -0.9, 0), Color = big and Color3.fromRGB(80, 255, 140) or (i % 2 == 0 and CYAN or PINK), Material = Enum.Material.Neon, CanCollide = false })
	if big then
		cpPad = p
		label(p, "✅ CHECKPOINT", Color3.fromRGB(80, 255, 140))
	end
	last = pos
end
cpPad.Touched:Connect(function(hit)
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if player and not checkpoint[player] then
		checkpoint[player] = cpPad.CFrame * CFrame.new(0, 3.5, 0)
		toast(player, "✅ Точка сохранения!", "✅ Checkpoint saved!")
	end
end)

-- упал в пустоту — возвращаемся на старт или точку сохранения
local void = part({ Size = Vector3.new(600, 2, 600), At = CFrame.new(0, -60, -150), Transparency = 1, CanCollide = false })
void.Touched:Connect(function(hit)
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if not player then return end
	hit.Parent:PivotTo(checkpoint[player] or (ORIGIN * CFrame.new(0, 3.5, 6)))
end)

--=========================================================================
-- Финал: «Сердце сервера» и награда
--=========================================================================
local heartAt = last * CFrame.new(0, 0, -24)
part({ Size = Vector3.new(30, 1, 30), At = heartAt * CFrame.new(0, -0.5, 0), Color = Color3.fromRGB(10, 20, 35), Material = Enum.Material.Glass })
part({ Size = Vector3.new(30.4, 0.3, 30.4), At = heartAt * CFrame.new(0, -0.9, 0), Color = PINK, Material = Enum.Material.Neon, CanCollide = false })
local core = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(8, 8, 8), At = heartAt * CFrame.new(0, 7, -6), Color = CYAN, Material = Enum.Material.Neon, CanCollide = false })
local light = Instance.new("PointLight")
light.Color = CYAN
light.Range = 40
light.Brightness = 3
light.Parent = core
TweenService:Create(core, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Size = Vector3.new(10, 10, 10) }):Play()
label(core, "💠 SERVER HEART · СЕРДЦЕ СЕРВЕРА", CYAN)
local chest = part({ Size = Vector3.new(5, 3.5, 3.5), At = heartAt * CFrame.new(0, 1.75, 4), Color = Color3.fromRGB(30, 30, 45), Material = Enum.Material.Metal })
part({ Size = Vector3.new(5.2, 0.4, 3.7), At = heartAt * CFrame.new(0, 2.6, 4), Color = CYAN, Material = Enum.Material.Neon, CanCollide = false })
local open = prompt(chest, "💾 DATA CHEST", "Open")
open.HoldDuration = 0.5
open.Triggered:Connect(function(player)
	local ready = player:GetAttribute("CoreReadyAt") or 0
	if ready > os.time() then
		toast(player, "⏳ Сундук снова через " .. math.ceil((ready - os.time()) / 60) .. " мин.", "⏳ Chest again in " .. math.ceil((ready - os.time()) / 60) .. " min.")
		return
	end
	local stats = player:FindFirstChild("Stats")
	local money = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Coins")
	if not stats or not money then return end
	local amount = math.max(100, math.floor(stats.Income.Value * 60 * REWARD_MIN))
	money.Value += amount
	Analytics.source(player, amount, "ServerHeart")
	player:SetAttribute("CoreReadyAt", os.time() + COOLDOWN)
	toast(player, "💾 Ты взломал сердце сервера! +" .. amount, "💾 You hacked the server heart! +" .. amount)
	checkpoint[player] = nil
end)
Players.PlayerRemoving:Connect(function(p) checkpoint[p] = nil end)

--=========================================================================
-- 3 ключ-карты в городе: игровой зал (2 этаж), смотровая башня, самый высокий небоскрёб
--=========================================================================
local CARD_SPOTS = { Vector3.new(556, 14.3, 213), Vector3.new(1010, 120, 270), Vector3.new(682, 141, 325) }
local cards = Instance.new("Model")
cards.Name = "КлючКарты"
cards.Parent = workspace
for i, pos in ipairs(CARD_SPOTS) do
	local card = part({ Parent = cards, Size = Vector3.new(2.4, 1.6, 0.2), World = CFrame.new(pos), Color = Color3.fromRGB(255, 215, 60), Material = Enum.Material.Neon, CanCollide = false })
	label(card, "🔑", Color3.fromRGB(255, 230, 120))
	local l = Instance.new("PointLight") l.Color = Color3.fromRGB(255, 215, 60) l.Range = 14 l.Parent = card
	TweenService:Create(card, TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(180), 0) }):Play()
	local bit = 2 ^ (i - 1)
	card.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then return end
		local mask = player:GetAttribute("KeyCards") or 0
		if math.floor(mask / bit) % 2 == 1 then return end
		mask += bit
		player:SetAttribute("KeyCards", mask)
		local n = (mask % 2) + (math.floor(mask / 2) % 2) + (math.floor(mask / 4) % 2)
		if n >= 3 then
			toast(player, "🔓 Все 3 ключ-карты! Тайная дверь «???» в клубе открыта", "🔓 All 3 key cards! The secret «???» door in your club is open")
		else
			toast(player, "🔑 Ключ-карта " .. n .. "/3", "🔑 Key card " .. n .. "/3")
		end
	end)
end

print("[Внутри компьютера] Готово")
