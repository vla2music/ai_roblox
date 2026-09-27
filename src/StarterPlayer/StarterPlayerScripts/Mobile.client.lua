-- Телефон: уменьшает кнопки и надписи. Камера — стандартная Roblox (как во всех играх).
-- На компьютере ничего не меняет.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

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
