--[[=========================================================================
	КЛУБ-ТАЙКУН — интерфейс игрока
	Клиентский скрипт. Кладётся в StarterPlayer > StarterPlayerScripts.

	Показывает сверху экрана три цифры: сколько монет, сколько капает
	в секунду и сколько лежит в сейфе.
==========================================================================]]

local Players = game:GetService("Players")

local player  = Players.LocalPlayer
local CURRENCY = "Монеты"

local leaderstats = player:WaitForChild("leaderstats")
local money       = leaderstats:WaitForChild(CURRENCY)
local stats       = player:WaitForChild("Stats")
local income      = stats:WaitForChild("Income")
local storage     = stats:WaitForChild("Storage")

-- «1 монета», «2 монеты», «5 монет»
local function coins(n)
	n = math.floor(math.abs(n))
	local lastTwo = n % 100
	local lastOne = n % 10
	if lastTwo >= 11 and lastTwo <= 14 then return "монет" end
	if lastOne == 1 then return "монета" end
	if lastOne >= 2 and lastOne <= 4 then return "монеты" end
	return "монет"
end

local function short(n)
	n = math.floor(n)
	if n >= 1e9 then return string.format("%.1fМрд", n / 1e9) end
	if n >= 1e6 then return string.format("%.1fМлн", n / 1e6) end
	if n >= 1e3 then return string.format("%.1fК",   n / 1e3) end
	return tostring(n)
end

--=========================================================================
-- Интерфейс
--=========================================================================

local screen = Instance.new("ScreenGui")
screen.Name = "КлубИнтерфейс"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 300, 0, 96)
panel.Position = UDim2.new(0.5, -150, 0, 12)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Parent = screen

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(0, 255, 200)
stroke.Thickness = 2
stroke.Transparency = 0.4
stroke.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 2)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = panel

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 8)
padding.Parent = panel

local function makeRow(order, textSize, color)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -16, 0, textSize + 6)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextColor3 = color
	label.LayoutOrder = order
	label.Text = ""
	label.Parent = panel
	return label
end

local moneyLabel   = makeRow(1, 26, Color3.fromRGB(255, 220, 90))
local incomeLabel  = makeRow(2, 15, Color3.fromRGB(0, 255, 200))
local storageLabel = makeRow(3, 15, Color3.fromRGB(200, 200, 215))

--=========================================================================
-- Обновление
--=========================================================================

local function refresh()
	moneyLabel.Text   = short(money.Value) .. " " .. coins(money.Value)
	incomeLabel.Text  = "+" .. short(income.Value) .. " в секунду"
	storageLabel.Text = "В сейфе: " .. short(storage.Value) .. "  (подойди и забери)"
end

money:GetPropertyChangedSignal("Value"):Connect(refresh)
income:GetPropertyChangedSignal("Value"):Connect(refresh)
storage:GetPropertyChangedSignal("Value"):Connect(refresh)
refresh()

--=========================================================================
-- Подсказка в начале игры
--=========================================================================

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(0, 460, 0, 40)
hint.Position = UDim2.new(0.5, -230, 0, 120)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.GothamMedium
hint.TextSize = 17
hint.TextColor3 = Color3.fromRGB(255, 255, 255)
hint.TextStrokeTransparency = 0.5
hint.Text = "Наступи на красную кнопку, чтобы купить. Деньги забирай в СЕЙФЕ."
hint.Parent = screen

task.delay(14, function()
	for i = 1, 20 do
		hint.TextTransparency = i / 20
		hint.TextStrokeTransparency = 0.5 + i / 40
		task.wait(0.05)
	end
	hint:Destroy()
end)
