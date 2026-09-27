--[[ ПАРАПЛАН (полёт у игрока). Сервер ставит атрибут GliderRun — взлетаем.
     Летим вперёд, рулим как при ходьбе (A/D, стрелки, джойстик),
     прыжок (пробел / кнопка) — набрать высоту, без него — плавно снижаемся.
     Пролетел кольцо — говорим серверу (Paraglider.server.lua), он платит. ]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local isRu = player.LocaleId:sub(1, 2) == "ru"
local function L(ru, en) return isRu and ru or en end

local SPEED     = 38
local SINK      = 3.8    -- снижение, студ/с: ровно по кольцам (7 вниз на 70 вперёд)
local CLIMB     = 5      -- подъём, пока жмёшь прыжок
local TURN_RATE = 1.6    -- радиан в секунду
local MAX_TIME  = 120

local remote = ReplicatedStorage:WaitForChild("GliderRing")
local course = workspace:WaitForChild("Параплан")

local function short(n)
	if n >= 1e9 then return string.format("%.1fB", n / 1e9) end
	if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
	if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
	return tostring(n)
end

-- счётчик на экране
local gui = Instance.new("ScreenGui")
gui.Name = "Paraglider"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local hud = Instance.new("TextLabel")
hud.Size = UDim2.new(0, 460, 0, 46)
hud.Position = UDim2.new(0.5, -230, 0, 175)
hud.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
hud.BackgroundTransparency = 0.25
hud.TextColor3 = Color3.fromRGB(120, 255, 170)
hud.Font = Enum.Font.GothamBlack
hud.TextScaled = true
hud.Visible = false
hud.Parent = gui
Instance.new("UICorner", hud).CornerRadius = UDim.new(0, 12)
local tip = Instance.new("TextLabel")
tip.Size = UDim2.new(0, 560, 0, 28)
tip.Position = UDim2.new(0.5, -280, 0, 225)
tip.BackgroundTransparency = 1
tip.TextColor3 = Color3.new(1, 1, 1)
tip.TextStrokeTransparency = 0.3
tip.Font = Enum.Font.GothamBold
tip.TextScaled = true
tip.Text = L("Рули влево-вправо · прыжок = вверх", "Steer left/right · jump = go up")
tip.Visible = false
tip.Parent = gui

local function rings()
	local list = {}
	for _, c in ipairs(course:GetChildren()) do
		local i = c:GetAttribute("Index")
		if i then list[i] = c end
	end
	return list
end

-- следующее кольцо яркое, остальные бледные
local function highlight(list, nextI)
	for i, c in pairs(list) do
		for _, d in ipairs(c:GetChildren()) do
			d.Transparency = (i == nextI) and 0 or 0.7
		end
	end
end

local flying = nil   -- { wing = {parts}, heading, nextI, count, earned, t0 }
local lastJump = 0
UserInputService.JumpRequest:Connect(function() lastJump = os.clock() end)

local function makeWing(root)
	local parts = {}
	for i = -3, 3 do   -- дуга крыла над головой
		local p = Instance.new("Part")
		p.Size = Vector3.new(3.2, 0.4, 5)
		p.Color = (i % 2 == 0) and Color3.fromRGB(60, 255, 140) or Color3.fromRGB(255, 255, 255)
		p.Material = Enum.Material.Fabric
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
		p.CFrame = root.CFrame * CFrame.new(i * 3, 10 - math.abs(i) * 0.8, 0) * CFrame.Angles(0, 0, math.rad(-i * 10))
		p.Parent = workspace
		local w = Instance.new("WeldConstraint") w.Part0, w.Part1 = root, p w.Parent = p
		table.insert(parts, p)
	end
	-- гасим гравитацию, иначе между кадрами тянет вниз сильнее, чем SINK
	local att = root:FindFirstChild("RootAttachment") or Instance.new("Attachment", root)
	local lift = Instance.new("VectorForce")
	lift.Attachment0 = att
	lift.RelativeTo = Enum.ActuatorRelativeTo.World
	lift.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity, 0)
	lift.Parent = root
	table.insert(parts, lift)
	return parts
end

local function finish()
	if not flying then return end
	for _, p in ipairs(flying.wing) do p:Destroy() end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then hum.PlatformStand = false end
	local total = L("🪂 Полёт окончен! Колец: ", "🪂 Flight over! Rings: ") .. flying.count .. "/" .. (course:GetAttribute("Rings") or 14)
		.. "  +" .. short(flying.earned)
	hud.Text = total
	tip.Visible = false
	highlight(rings(), -1)
	for _, c in pairs(rings()) do for _, d in ipairs(c:GetChildren()) do d.Transparency = 0 end end
	flying = nil
	task.delay(4, function() if not flying then hud.Visible = false end end)
end

player:GetAttributeChangedSignal("GliderRun"):Connect(function()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end
	if flying then finish() end
	hum.PlatformStand = true
	flying = { wing = makeWing(root), heading = Vector3.new(0, 0, -1), nextI = 1, count = 0, earned = 0, t0 = os.clock() }
	highlight(rings(), 1)
	hud.Text = L("🪂 Кольца: 0/", "🪂 Rings: 0/") .. (course:GetAttribute("Rings") or 14)
	hud.Visible, tip.Visible = true, true
	local wait = player:GetAttribute("GliderWait") or 0
	tip.Text = wait > 0
		and L("Полёт без награды: монеты через " .. wait .. " мин", "Practice flight: coins again in " .. wait .. " min")
		or L("Рули влево-вправо · прыжок = вверх", "Steer left/right · jump = go up")
end)

remote.OnClientEvent:Connect(function(index, amount, count, earned)
	if not flying then return end
	flying.count, flying.earned = count, earned
	if amount == 0 then   -- полёт без награды: считаем только кольца
		hud.Text = L("🪂 Кольца: ", "🪂 Rings: ") .. count .. "/" .. (course:GetAttribute("Rings") or 14)
		return
	end
	hud.Text = L("🪂 Кольца: ", "🪂 Rings: ") .. count .. "/" .. (course:GetAttribute("Rings") or 14) .. "   +" .. short(earned)
	if index >= (course:GetAttribute("Rings") or 14) then
		hud.Text = L("🏆 ВСЯ ТРАССА! +", "🏆 FULL COURSE! +") .. short(earned)
	end
end)

player.CharacterAdded:Connect(function() if flying then finish() end end)

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

RunService.Heartbeat:Connect(function(dt)
	if not flying then return end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then finish() return end

	-- поворот к направлению джойстика / клавиш
	local md = hum.MoveDirection
	if md.Magnitude > 0.1 then
		local h, m = flying.heading, Vector3.new(md.X, 0, md.Z).Unit
		local angle = math.atan2(h.X * m.Z - h.Z * m.X, h.X * m.X + h.Z * m.Z)
		local a = math.clamp(angle, -TURN_RATE * dt, TURN_RATE * dt)
		flying.heading = Vector3.new(h.X * math.cos(a) - h.Z * math.sin(a), 0, h.X * math.sin(a) + h.Z * math.cos(a)).Unit
	end
	local vy = (os.clock() - lastJump < 0.3 or UserInputService:IsKeyDown(Enum.KeyCode.Space)) and CLIMB or -SINK
	root.AssemblyLinearVelocity = flying.heading * SPEED + Vector3.new(0, vy, 0)
	root.CFrame = CFrame.lookAt(root.Position, root.Position + flying.heading)

	-- кольца: засчитываем следующее или любое дальше по трассе
	local R = course:GetAttribute("RingRadius") or 12
	for i, c in pairs(rings()) do
		if i >= flying.nextI and (c.Position - root.Position).Magnitude < R then
			flying.nextI = i + 1
			remote:FireServer(i)
			highlight(rings(), flying.nextI)
			break
		end
	end

	-- приземлились (земля, крыша, вода) или слишком долго летим
	groundParams.FilterDescendantsInstances = { char, course }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -4, 0), groundParams)
	if hit or os.clock() - flying.t0 > MAX_TIME then finish() end
end)
