--[[ ПАРАШЮТ: взял на крыше (башня, небоскрёбы) — на экране кнопка 🪂.
     Прыгнул — купол раскрывается сам или по кнопке / пробелу в воздухе.
     Падаешь медленно и рулишь. После приземления исчезает.
     Сервер каждый раз ставит новый номер в атрибут Parachute, поэтому
     повторное взятие тоже срабатывает. ]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local isRu = player.LocaleId:sub(1, 2) == "ru"

local ready = false
local open = nil   -- { parts, force }

-- кнопка на экране (видна, пока парашют в рюкзаке)
local gui = Instance.new("ScreenGui")
gui.Name = "Parachute"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 220, 0, 64)
button.Position = UDim2.new(0.5, -110, 0.72, 0)
button.BackgroundColor3 = Color3.fromRGB(230, 70, 60)
button.TextColor3 = Color3.new(1, 1, 1)
button.Font = Enum.Font.GothamBlack
button.TextScaled = true
button.Visible = false
button.Parent = gui
Instance.new("UICorner", button).CornerRadius = UDim.new(0, 14)
local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(0, 520, 0, 34)
hint.Position = UDim2.new(0.5, -260, 0.72, -40)
hint.BackgroundTransparency = 1
hint.TextColor3 = Color3.new(1, 1, 1)
hint.TextStrokeTransparency = 0.3
hint.Font = Enum.Font.GothamBold
hint.TextScaled = true
hint.Text = isRu and "Прыгай с крыши — купол раскроется сам" or "Jump off the roof — it opens by itself"
hint.Visible = false
hint.Parent = gui

local function refresh()
	button.Visible = ready and not open
	hint.Visible = button.Visible
	button.Text = isRu and "🪂 ОТКРЫТЬ" or "🪂 OPEN"
end

local function closeChute()
	if not open then return end
	for _, p in ipairs(open.parts) do p:Destroy() end
	if open.force then open.force:Destroy() end
	open = nil
	refresh()
end

local function openChute(root)
	local parts = {}
	local function mk(size, offset, color)
		local p = Instance.new("Part")
		p.Size, p.Color, p.Material = size, color, Enum.Material.Fabric
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
		p.CFrame = root.CFrame * offset
		p.Parent = workspace
		local w = Instance.new("WeldConstraint") w.Part0, w.Part1 = root, p w.Parent = p
		table.insert(parts, p)
	end
	local colors = { Color3.fromRGB(230, 60, 60), Color3.fromRGB(255, 255, 255), Color3.fromRGB(40, 120, 230) }
	for i = -2, 2 do   -- купол из полос
		mk(Vector3.new(3, 0.5, 9), CFrame.new(i * 2.9, 9 - math.abs(i) * 0.7, 0) * CFrame.Angles(0, 0, math.rad(-i * 12)), colors[(i + 3) % 3 + 1])
	end
	for _, x in ipairs({ -6, 6 }) do   -- стропы
		mk(Vector3.new(0.1, 8, 0.1), CFrame.new(x * 0.6, 4.5, 0) * CFrame.Angles(0, 0, math.rad(x * 3)), Color3.fromRGB(230, 230, 230))
	end
	local att = root:FindFirstChild("RootAttachment") or Instance.new("Attachment", root)
	local force = Instance.new("VectorForce")
	force.Attachment0 = att
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.Parent = root
	open = { parts = parts, force = force }
	refresh()
end

local function tryOpen()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not ready or open or not hum or not root then return end
	if hum.FloorMaterial ~= Enum.Material.Air then return end   -- только в воздухе
	openChute(root)
end

button.Activated:Connect(tryOpen)
UserInputService.JumpRequest:Connect(tryOpen)   -- пробел / прыжок в воздухе

player:GetAttributeChangedSignal("Parachute"):Connect(function()
	if player:GetAttribute("Parachute") then
		ready = true
		refresh()
	end
end)
player.CharacterAdded:Connect(function()   -- умер — парашют пропал
	open = nil
	ready = false
	refresh()
end)

RunService.Heartbeat:Connect(function()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root then return end
	if ready and not open and root.AssemblyLinearVelocity.Y < -35 and hum.FloorMaterial == Enum.Material.Air then
		openChute(root)   -- падаешь быстро — раскрываем сами
	end
	if open then
		-- сопротивление воздуха: скорость падения около 12
		local mass = root.AssemblyMass
		local vy = root.AssemblyLinearVelocity.Y
		local up = mass * workspace.Gravity + math.max(0, -vy - 12) * mass * 8
		open.force.Force = Vector3.new(0, up, 0)
		if hum.FloorMaterial ~= Enum.Material.Air then
			closeChute()
			ready = false
			refresh()
		end
	end
end)
