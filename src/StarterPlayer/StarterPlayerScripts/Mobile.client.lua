-- Телефон: уменьшает кнопки/надписи и делает поворот камеры пальцем быстрее.
-- На компьютере ничего не меняет.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local IS_PHONE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
if not IS_PHONE then return end

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ===== Размер интерфейса =====
local DESIGN_HEIGHT = 720      -- интерфейс рисовался под экран такой высоты
local MIN_SCALE = 0.55         -- мельче уже не читается
local SKIP = { TouchGui = true, Arcade = true } -- Arcade считает касания в пикселях сам

local function uiScale()
	return math.clamp(camera.ViewportSize.Y / DESIGN_HEIGHT, MIN_SCALE, 1)
end

local scales = {}
local function applyScreen(gui)
	if not gui:IsA("ScreenGui") or SKIP[gui.Name] then return end
	local s = gui:FindFirstChild("MobileScale") or Instance.new("UIScale")
	s.Name = "MobileScale"
	s.Scale = uiScale()
	s.Parent = gui
	scales[s] = true
	s.Destroying:Connect(function() scales[s] = nil end)
end

-- Надписи над предметами (VIP-зона, сейф и т.п.) — тоже меньше
local function applyBillboard(bg)
	if not bg:IsA("BillboardGui") or bg:GetAttribute("MobileScaled") then return end
	local k = uiScale()
	local sz = bg.Size
	bg.Size = UDim2.new(sz.X.Scale, sz.X.Offset * k, sz.Y.Scale, sz.Y.Offset * k)
	bg:SetAttribute("MobileScaled", true)
end

local playerGui = player:WaitForChild("PlayerGui")
for _, g in playerGui:GetChildren() do applyScreen(g) end
playerGui.ChildAdded:Connect(applyScreen)

for _, d in workspace:GetDescendants() do applyBillboard(d) end
workspace.DescendantAdded:Connect(applyBillboard)

camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	for s in scales do s.Scale = uiScale() end
end)

-- ===== Чувствительность камеры =====
-- Стандартная камера Roblox поворачивается сама; мы добавляем к ней ещё поворот.
-- Больше число — быстрее крутится (0 = как было).
local EXTRA_DEG_PER_PX = 0.45

local pending = Vector2.zero
local cameraTouches = {} -- касание -> прошлая позиция пальца

-- Палец на кнопке интерфейса камеру не крутит
local function overButton(pos)
	for _, obj in playerGui:GetGuiObjectsAtPosition(pos.X, pos.Y) do
		if obj:IsA("GuiButton") and obj.Visible then return true end
	end
	return false
end

UserInputService.TouchStarted:Connect(function(input)
	local pos = Vector2.new(input.Position.X, input.Position.Y)
	local vp = camera.ViewportSize
	-- левая нижняя часть экрана — джойстик ходьбы
	local joystick = pos.X < vp.X * 0.4 and pos.Y > vp.Y * 0.35
	if not joystick and not overButton(pos) then cameraTouches[input] = pos end
end)
UserInputService.TouchEnded:Connect(function(input) cameraTouches[input] = nil end)
UserInputService.TouchMoved:Connect(function(input)
	local last = cameraTouches[input]
	if not last then return end
	local pos = Vector2.new(input.Position.X, input.Position.Y)
	pending += pos - last
	cameraTouches[input] = pos
end)

RunService:BindToRenderStep("MobileCameraBoost", Enum.RenderPriority.Camera.Value + 1, function()
	local d = pending
	pending = Vector2.zero
	if d == Vector2.zero or camera.CameraType ~= Enum.CameraType.Custom then return end
	local count = 0
	for _ in cameraTouches do count += 1 end
	if count ~= 1 then return end -- двумя пальцами — это зум

	local focus = camera.Focus.Position
	local offset = camera.CFrame.Position - focus
	local yaw = -math.rad(d.X * EXTRA_DEG_PER_PX)
	local pitch = -math.rad(d.Y * EXTRA_DEG_PER_PX)

	local rotated = CFrame.fromAxisAngle(Vector3.yAxis, yaw) * offset
	local right = camera.CFrame.RightVector
	local tilted = CFrame.fromAxisAngle(right, pitch) * rotated
	if math.abs(tilted.Unit.Y) < 0.95 then rotated = tilted end -- не переворачиваться через верх

	camera.CFrame = CFrame.lookAt(focus + rotated, focus)
end)
