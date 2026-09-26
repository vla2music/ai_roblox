--[[=========================================================================
	КЛУБ-ТАЙКУН — интерфейс игрока
	Клиентский скрипт. Кладётся в StarterPlayer > StarterPlayerScripts.

	Показывает сверху экрана три цифры: сколько монет, сколько капает
	в секунду и сколько монет лежит на площадке.
==========================================================================]]

local Players = game:GetService("Players")

local player  = Players.LocalPlayer
local CURRENCY = "Coins"

-- русскоязычные видят русский, все остальные — английский
local isRu = player.LocaleId:sub(1, 2) == "ru"

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
	if n >= 1e9 then return string.format("%.1fB", n / 1e9) end
	if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
	if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
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
	if isRu then
		moneyLabel.Text   = short(money.Value) .. " " .. coins(money.Value)
		incomeLabel.Text  = "+" .. short(income.Value) .. " в секунду"
		storageLabel.Text = "На площадке: " .. short(storage.Value) .. "  (беги собирай!)"
	else
		moneyLabel.Text   = short(money.Value) .. (money.Value == 1 and " coin" or " coins")
		incomeLabel.Text  = "+" .. short(income.Value) .. " per second"
		storageLabel.Text = "On the pad: " .. short(storage.Value) .. "  (go grab them!)"
	end
end

money:GetPropertyChangedSignal("Value"):Connect(refresh)
income:GetPropertyChangedSignal("Value"):Connect(refresh)
storage:GetPropertyChangedSignal("Value"):Connect(refresh)
refresh()

--=========================================================================
-- Подсказка в начале игры
--=========================================================================

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(0, 560, 0, 60)
hint.Position = UDim2.new(0.5, -280, 0, 120)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.GothamMedium
hint.TextSize = 17
hint.TextColor3 = Color3.fromRGB(255, 255, 255)
hint.TextStrokeTransparency = 0.5
hint.Text = isRu
	and "Докажи, что построишь лучший киберклуб в городе!\nЖми E у банкомата, собирай монеты, иди за жёлтой стрелкой."
	or "Build the #1 Cyber Club in town!\nPress E at the ATM, grab coins, follow the yellow arrow."
hint.Parent = screen

task.delay(14, function()
	for i = 1, 20 do
		hint.TextTransparency = i / 20
		hint.TextStrokeTransparency = 0.5 + i / 40
		task.wait(0.05)
	end
	hint:Destroy()
end)

--=========================================================================
-- Финал этажа: клуб построен
--=========================================================================

local TweenService = game:GetService("TweenService")
local joinedAt = os.clock()

-- постоянная строка под панелью, когда этаж достроен
local doneLabel = Instance.new("TextLabel")
doneLabel.Size = UDim2.new(0, 420, 0, 26)
doneLabel.Position = UDim2.new(0.5, -210, 0, 112)
doneLabel.BackgroundTransparency = 1
doneLabel.Font = Enum.Font.GothamBold
doneLabel.TextSize = 16
doneLabel.TextColor3 = Color3.fromRGB(255, 215, 90)
doneLabel.TextStrokeTransparency = 0.5
doneLabel.Text = isRu and "🏆 Этаж 1 построен · 2 этаж — скоро!" or "🏆 Floor 1 complete · Floor 2 coming soon!"
doneLabel.Visible = player:GetAttribute("Floor1Done") == true
doneLabel.Parent = screen

local function celebrate()
	local banner = Instance.new("Frame")
	banner.Size = UDim2.new(0, 560, 0, 190)
	banner.Position = UDim2.new(0.5, -280, 0.5, -95)
	banner.BackgroundColor3 = Color3.fromRGB(20, 16, 34)
	banner.BackgroundTransparency = 0.1
	banner.Parent = screen
	Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 18)
	local s = Instance.new("UIStroke", banner)
	s.Color = Color3.fromRGB(255, 200, 80)
	s.Thickness = 3

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -30, 0, 70)
	title.Position = UDim2.new(0, 15, 0, 18)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 215, 90)
	title.Text = isRu and "🏆 КЛУБ ПОСТРОЕН!" or "🏆 CLUB COMPLETE!"
	title.Parent = banner

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -40, 0, 80)
	sub.Position = UDim2.new(0, 20, 0, 95)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamMedium
	sub.TextScaled = true
	sub.TextWrapped = true
	sub.TextColor3 = Color3.new(1, 1, 1)
	sub.Text = isRu
		and "Ты построил лучший киберклуб в городе!\nЖми РЕБЁРТ — начни заново с двойным доходом!"
		or "You built the best cyber club in town!\nHit REBIRTH to start over with double income!"
	sub.Parent = banner

	-- конфетти
	local colors = { Color3.fromRGB(255, 90, 120), Color3.fromRGB(255, 220, 80), Color3.fromRGB(90, 220, 255), Color3.fromRGB(150, 255, 120) }
	for i = 1, 70 do
		local c = Instance.new("Frame")
		c.Size = UDim2.new(0, math.random(6, 12), 0, math.random(10, 18))
		c.Position = UDim2.new(math.random(), 0, 0, -20)
		c.Rotation = math.random(0, 360)
		c.BackgroundColor3 = colors[math.random(#colors)]
		c.BorderSizePixel = 0
		c.Parent = screen
		TweenService:Create(c, TweenInfo.new(math.random(25, 45) / 10, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(c.Position.X.Scale + (math.random() - 0.5) * 0.2, 0, 1.1, 0),
			Rotation = c.Rotation + math.random(-360, 360),
		}):Play()
		task.delay(5, function() c:Destroy() end)
	end

	task.delay(7, function()
		TweenService:Create(banner, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		for _, d in ipairs(banner:GetDescendants()) do
			if d:IsA("TextLabel") then TweenService:Create(d, TweenInfo.new(0.6), { TextTransparency = 1 }):Play() end
			if d:IsA("UIStroke") then TweenService:Create(d, TweenInfo.new(0.6), { Transparency = 1 }):Play() end
		end
		task.wait(0.7)
		banner:Destroy()
	end)
end

--=========================================================================
-- Ребёрт: продать готовый клуб и начать заново с бонусом к доходу
--=========================================================================

local rebirthEvent = game:GetService("ReplicatedStorage"):WaitForChild("ClubRebirth")
local rebirths = leaderstats:WaitForChild("Rebirths")

local rebirthButton = Instance.new("TextButton")
rebirthButton.Size = UDim2.new(0, 320, 0, 48)
rebirthButton.Position = UDim2.new(0.5, -160, 0, 144)
rebirthButton.BackgroundColor3 = Color3.fromRGB(255, 190, 60)
rebirthButton.Font = Enum.Font.GothamBlack
rebirthButton.TextScaled = true
rebirthButton.TextColor3 = Color3.fromRGB(40, 25, 0)
rebirthButton.Parent = screen
Instance.new("UICorner", rebirthButton).CornerRadius = UDim.new(0, 12)
local rbPad = Instance.new("UIPadding", rebirthButton)
rbPad.PaddingLeft = UDim.new(0, 10)
rbPad.PaddingRight = UDim.new(0, 10)
rbPad.PaddingTop = UDim.new(0, 6)
rbPad.PaddingBottom = UDim.new(0, 6)

local confirming = false
local function rebirthText()
	local nextBoost = 1 + 0.5 * (rebirths.Value + 1)
	if confirming then
		return isRu and ("Точно? Клуб и монеты сбросятся. Жми ещё раз!") or "Sure? Club & coins reset. Click again!"
	end
	return isRu and ("🔄 РЕБЁРТ: доход ×" .. nextBoost .. " навсегда") or ("🔄 REBIRTH: x" .. nextBoost .. " income forever")
end
local function refreshRebirth()
	rebirthButton.Visible = player:GetAttribute("Floor1Done") == true
	rebirthButton.Text = rebirthText()
end
refreshRebirth()
rebirths:GetPropertyChangedSignal("Value"):Connect(refreshRebirth)

rebirthButton.MouseButton1Click:Connect(function()
	if not confirming then
		confirming = true
		rebirthButton.BackgroundColor3 = Color3.fromRGB(255, 110, 80)
		refreshRebirth()
		task.delay(4, function()
			confirming = false
			rebirthButton.BackgroundColor3 = Color3.fromRGB(255, 190, 60)
			refreshRebirth()
		end)
		return
	end
	confirming = false
	rebirthButton.BackgroundColor3 = Color3.fromRGB(255, 190, 60)
	rebirthEvent:FireServer()
end)

player:GetAttributeChangedSignal("Floor1Done"):Connect(refreshRebirth)

player:GetAttributeChangedSignal("Floor1Done"):Connect(function()
	local done = player:GetAttribute("Floor1Done") == true
	-- при входе в игру атрибут приходит с сервера — это не новая победа
	if done and not doneLabel.Visible and os.clock() - joinedAt > 5 then celebrate() end
	doneLabel.Visible = done
end)
