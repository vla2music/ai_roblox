--[[=========================================================================
	МЕНЮ ИГРОКА: кнопки слева и окна
	🛒 Магазин   — геймпассы и пачки монет за Robux
	💻 Компы     — улучшение всех компьютеров (x2, x3, x5 дохода)
	📅 Награды   — ежедневные награды на 7 дней
	👥 Друзья    — пригласить друзей в игру
==========================================================================]]

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local SocialService      = game:GetService("SocialService")
local TweenService       = game:GetService("TweenService")
local UserInputService   = game:GetService("UserInputService")
local GuiService         = game:GetService("GuiService")

local player = Players.LocalPlayer
local Shared = require(ReplicatedStorage:WaitForChild("ClubShared"))
local clubAction = ReplicatedStorage:WaitForChild("ClubAction")
local money = player:WaitForChild("leaderstats"):WaitForChild("Coins")

local isRu = player.LocaleId:sub(1, 2) == "ru"
local function L(ru, en) return isRu and ru or en end

local function short(n)
	n = math.floor(n)
	if n >= 1e9 then return string.format("%.1fB", n / 1e9) end
	if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
	if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
	return tostring(n)
end

--=========================================================================
-- Заготовки интерфейса
--=========================================================================

local screen = Instance.new("ScreenGui")
screen.Name = "КлубМеню"
screen.ResetOnSpawn = false
screen.Parent = player:WaitForChild("PlayerGui")

local function corner(obj, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = obj
end

local function stroke(obj, color, t)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = t or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = obj
end

local function text(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	for k, v in pairs(props) do l[k] = v end
	l.Parent = parent
	return l
end

local function button(parent, props, onClick)
	local b = Instance.new("TextButton")
	b.Font = Enum.Font.GothamBlack
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.AutoButtonColor = true
	for k, v in pairs(props) do b[k] = v end
	b.Parent = parent
	corner(b, 10)
	if onClick then b.MouseButton1Click:Connect(onClick) end
	return b
end

-- Окно: тёмная панель с заголовком и красным крестиком
local openWindow
local function makeWindow(title, accent)
	local win = Instance.new("Frame")
	win.Size = UDim2.new(0.62, 0, 0.66, 0)
	win.Position = UDim2.new(0.19, 0, 0.17, 0)
	win.BackgroundColor3 = Color3.fromRGB(24, 22, 32)
	win.Visible = false
	win.Parent = screen
	corner(win, 18)
	stroke(win, accent, 4)
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1.5
	ar.Parent = win

	text(win, {
		Size = UDim2.new(0.8, 0, 0.1, 0), Position = UDim2.new(0.04, 0, 0.025, 0),
		Text = title, TextXAlignment = Enum.TextXAlignment.Left,
	})
	button(win, {
		Size = UDim2.new(0.08, 0, 0.12, 0), Position = UDim2.new(0.935, 0, -0.04, 0),
		BackgroundColor3 = Color3.fromRGB(230, 50, 50), Text = "X",
	}, function() win.Visible = false end)

	local body = Instance.new("ScrollingFrame")
	body.Size = UDim2.new(0.94, 0, 0.83, 0)
	body.Position = UDim2.new(0.03, 0, 0.14, 0)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 6
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.Parent = win
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body
	return win, body
end

-- Джойстик: при открытии окна выделяем первую кнопку в нём
local function firstButton(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("GuiButton") and d.Visible and d.Selectable and d.Text ~= "X" then return d end
	end
end

local function show(win, refresh)
	if openWindow and openWindow ~= win then openWindow.Visible = false end
	openWindow = win
	win.Visible = not win.Visible
	if win.Visible and refresh then task.spawn(refresh) end
	if UserInputService.GamepadEnabled then
		if win.Visible then
			task.delay(0.2, function()
				if win.Visible then GuiService.SelectedObject = firstButton(win) end
			end)
		else
			GuiService.SelectedObject = nil
		end
	end
end

local function section(body, title, color, order)
	text(body, {
		Size = UDim2.new(1, 0, 0, 34), Text = "~ " .. title .. " ~",
		TextColor3 = color, LayoutOrder = order,
	})
end

local function card(body, height, color, order)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, -10, 0, height)
	f.BackgroundColor3 = color
	f.LayoutOrder = order
	f.Parent = body
	corner(f, 14)
	stroke(f, Color3.fromRGB(90, 85, 110), 2)
	return f
end

--=========================================================================
-- 🛒 МАГАЗИН
--=========================================================================

local shopWin, shopBody = makeWindow(L("МАГАЗИН", "SHOP"), Color3.fromRGB(255, 200, 60))

section(shopBody, L("Постоянные геймпассы", "Permanent Gamepasses"), Color3.fromRGB(255, 215, 90), 1)
local passRow = card(shopBody, 190, Color3.fromRGB(34, 32, 46), 2)
local passLayout = Instance.new("UIListLayout")
passLayout.FillDirection = Enum.FillDirection.Horizontal
passLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
passLayout.VerticalAlignment = Enum.VerticalAlignment.Center
passLayout.Padding = UDim.new(0.02, 0)
passLayout.Parent = passRow

local passButtons = {}
for _, pass in ipairs(Shared.GAMEPASSES) do
	local tile = Instance.new("Frame")
	tile.Size = UDim2.new(0.23, 0, 0.9, 0)
	tile.BackgroundColor3 = Color3.fromRGB(46, 42, 62)
	tile.Parent = passRow
	corner(tile, 12)
	local t = isRu and pass.ru or pass.en
	text(tile, { Size = UDim2.new(1, -10, 0.18, 0), Position = UDim2.new(0, 5, 0.03, 0), Text = t[1], TextColor3 = Color3.fromRGB(255, 215, 90) })
	text(tile, { Size = UDim2.new(1, 0, 0.32, 0), Position = UDim2.new(0, 0, 0.22, 0), Text = pass.icon })
	text(tile, { Size = UDim2.new(1, -14, 0.2, 0), Position = UDim2.new(0, 7, 0.55, 0), Text = t[2], Font = Enum.Font.GothamMedium })
	passButtons[pass.key] = button(tile, {
		Size = UDim2.new(0.8, 0, 0.17, 0), Position = UDim2.new(0.1, 0, 0.79, 0),
		BackgroundColor3 = Color3.fromRGB(40, 190, 90),
		Text = pass.id == 0 and L("СКОРО", "SOON") or ("R$ " .. pass.price),
	}, function()
		if pass.id ~= 0 and player:GetAttribute("Pass_" .. pass.key) ~= true then
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		end
	end)
end

section(shopBody, L("Денежные продукты", "Cash Packs"), Color3.fromRGB(90, 255, 140), 3)
local income = player:WaitForChild("Stats"):WaitForChild("Income")
local packLabels = {}
for i, pack in ipairs(Shared.COIN_PACKS) do
	local c = card(shopBody, 90, Color3.fromRGB(34, 32, 46), 3 + i)
	text(c, { Size = UDim2.new(0.12, 0, 0.8, 0), Position = UDim2.new(0.02, 0, 0.1, 0), Text = pack.icon })
	text(c, { Size = UDim2.new(0.45, 0, 0.4, 0), Position = UDim2.new(0.16, 0, 0.1, 0), Text = isRu and pack.ru or pack.en, TextXAlignment = Enum.TextXAlignment.Left })
	packLabels[i] = text(c, { Size = UDim2.new(0.45, 0, 0.36, 0), Position = UDim2.new(0.16, 0, 0.55, 0), Text = "", TextColor3 = Color3.fromRGB(90, 255, 140), TextXAlignment = Enum.TextXAlignment.Left })
	button(c, {
		Size = UDim2.new(0.28, 0, 0.62, 0), Position = UDim2.new(0.69, 0, 0.19, 0),
		BackgroundColor3 = Color3.fromRGB(40, 190, 90),
		Text = pack.id == 0 and L("СКОРО", "SOON") or ("R$ " .. pack.price),
	}, function()
		if pack.id ~= 0 then MarketplaceService:PromptProductPurchase(player, pack.id) end
	end)
end

local function refreshShop()
	for i, pack in ipairs(Shared.COIN_PACKS) do
		packLabels[i].Text = "+" .. short(math.max(1000, income.Value * 60 * pack.minutes))
	end
	for _, pass in ipairs(Shared.GAMEPASSES) do
		if player:GetAttribute("Pass_" .. pass.key) == true then
			passButtons[pass.key].Text = L("✓ ЕСТЬ", "✓ OWNED")
			passButtons[pass.key].BackgroundColor3 = Color3.fromRGB(90, 90, 110)
		end
	end
end

--=========================================================================
-- 💻 УЛУЧШЕНИЕ КОМПОВ
--=========================================================================

local upWin, upBody = makeWindow(L("УЛУЧШЕНИЕ КОМПОВ", "PC UPGRADES"), Color3.fromRGB(90, 220, 255))
text(upBody, {
	Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 0, Font = Enum.Font.GothamMedium,
	Text = L("Все компы в клубе станут мощнее и красивее!", "All PCs in your club get stronger and cooler!"),
	TextColor3 = Color3.fromRGB(200, 200, 220),
})
local tierButtons = {}
for i, tier in ipairs(Shared.PC_TIERS) do
	local c = card(upBody, 96, Color3.fromRGB(34, 32, 46), i)
	local swatch = Instance.new("Frame")
	swatch.Size = UDim2.new(0.1, 0, 0.7, 0)
	swatch.Position = UDim2.new(0.03, 0, 0.15, 0)
	swatch.BackgroundColor3 = tier.color
	swatch.Parent = c
	corner(swatch, 10)
	text(swatch, { Size = UDim2.new(1, 0, 1, 0), Text = "💻" })
	text(c, { Size = UDim2.new(0.5, 0, 0.42, 0), Position = UDim2.new(0.16, 0, 0.08, 0), Text = isRu and tier.ru or tier.en, TextColor3 = tier.color, TextXAlignment = Enum.TextXAlignment.Left })
	text(c, { Size = UDim2.new(0.5, 0, 0.36, 0), Position = UDim2.new(0.16, 0, 0.55, 0), Font = Enum.Font.GothamMedium, Text = L("Доход компов x", "PC income x") .. tier.mult, TextXAlignment = Enum.TextXAlignment.Left })
	tierButtons[i] = button(c, {
		Size = UDim2.new(0.3, 0, 0.62, 0), Position = UDim2.new(0.67, 0, 0.19, 0),
		BackgroundColor3 = Color3.fromRGB(40, 190, 90), Text = "",
	}, function()
		local st = clubAction:InvokeServer("upgrade")
		if st then task.spawn(function() tierButtons.refresh(st) end) end
	end)
end
function tierButtons.refresh(st)
	for i, tier in ipairs(Shared.PC_TIERS) do
		local b = tierButtons[i]
		if i <= st.pcTier then
			b.Text = L("✓ ЕСТЬ", "✓ DONE")
			b.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
		elseif i == st.pcTier + 1 then
			b.Text = "$" .. short(tier.cost)
			b.BackgroundColor3 = money.Value >= tier.cost and Color3.fromRGB(40, 190, 90) or Color3.fromRGB(150, 60, 60)
		else
			b.Text = "🔒"
			b.BackgroundColor3 = Color3.fromRGB(60, 58, 75)
		end
	end
end

--=========================================================================
-- 📅 ЕЖЕДНЕВНЫЕ НАГРАДЫ
--=========================================================================

local dayWin, dayBody = makeWindow(L("ЕЖЕДНЕВНЫЕ НАГРАДЫ", "DAILY REWARDS"), Color3.fromRGB(255, 120, 200))
local dayGrid = card(dayBody, 300, Color3.fromRGB(34, 32, 46), 1)
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0.23, 0, 0.45, 0)
grid.CellPadding = UDim2.new(0.02, 0, 0.04, 0)
grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
grid.VerticalAlignment = Enum.VerticalAlignment.Center
grid.Parent = dayGrid
local dayTiles = {}
for i = 1, #Shared.DAILY do
	local tile = Instance.new("Frame")
	tile.BackgroundColor3 = Color3.fromRGB(50, 46, 66)
	tile.Parent = dayGrid
	corner(tile, 12)
	text(tile, { Size = UDim2.new(1, 0, 0.26, 0), Position = UDim2.new(0, 0, 0.04, 0), Text = L("День ", "Day ") .. i })
	text(tile, { Size = UDim2.new(1, 0, 0.36, 0), Position = UDim2.new(0, 0, 0.3, 0), Text = i == 7 and "🎁" or "💵" })
	dayTiles[i] = text(tile, { Size = UDim2.new(1, -10, 0.24, 0), Position = UDim2.new(0, 5, 0.7, 0), Text = "", Font = Enum.Font.GothamBold })
end
local claimButton = button(dayBody, {
	Size = UDim2.new(0.5, 0, 0, 60), LayoutOrder = 2,
	BackgroundColor3 = Color3.fromRGB(40, 190, 90), Text = "",
})
local dayState
local function refreshDaily(st)
	dayState = st or clubAction:InvokeServer("state")
	if not dayState then return end
	for i, lbl in ipairs(dayTiles) do
		local tile = lbl.Parent
		if i < dayState.dailyDay then
			lbl.Text = "✓"
			tile.BackgroundColor3 = Color3.fromRGB(40, 110, 60)
		elseif i == dayState.dailyDay then
			lbl.Text = "+" .. short(dayState.dailyAmount)
			tile.BackgroundColor3 = Color3.fromRGB(150, 90, 30)
		else
			lbl.Text = L("скоро", "soon")
			tile.BackgroundColor3 = Color3.fromRGB(50, 46, 66)
		end
	end
	if dayState.dailyReadyIn <= 0 then
		claimButton.Text = L("ЗАБРАТЬ!", "CLAIM!")
		claimButton.BackgroundColor3 = Color3.fromRGB(40, 190, 90)
	else
		local h = math.floor(dayState.dailyReadyIn / 3600)
		local m = math.floor(dayState.dailyReadyIn % 3600 / 60)
		claimButton.Text = L("Через ", "In ") .. h .. L("ч ", "h ") .. m .. L("м", "m")
		claimButton.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
	end
end
claimButton.MouseButton1Click:Connect(function()
	if dayState and dayState.dailyReadyIn <= 0 then
		refreshDaily(clubAction:InvokeServer("claimDaily"))
	end
end)

--=========================================================================
-- Кнопки слева
--=========================================================================

local side = Instance.new("Frame")
side.Size = UDim2.new(0, 96, 0, 420)
side.Position = UDim2.new(0, 12, 0.5, -210)
side.BackgroundTransparency = 1
side.Parent = screen
local sideList = Instance.new("UIListLayout")
sideList.Padding = UDim.new(0, 10)
sideList.Parent = side

local function sideButton(icon, label, color, onClick)
	local b = button(side, {
		Size = UDim2.new(1, 0, 0, 94), BackgroundColor3 = color, Text = "",
	}, onClick)
	stroke(b, Color3.fromRGB(255, 255, 255), 3)
	text(b, { Size = UDim2.new(1, 0, 0.6, 0), Position = UDim2.new(0, 0, 0.04, 0), Text = icon })
	text(b, { Size = UDim2.new(1, -6, 0.3, 0), Position = UDim2.new(0, 3, 0.66, 0), Text = label })
	return b
end

local shopBtn = sideButton("🛒", L("Магазин", "Shop"), Color3.fromRGB(230, 70, 70), function() show(shopWin, refreshShop) end)
sideButton("💻", L("Компы", "PCs"), Color3.fromRGB(50, 130, 230), function()
	show(upWin, function()
		local st = clubAction:InvokeServer("state")
		if st then tierButtons.refresh(st) end
	end)
end)
local dailyBtn = sideButton("📅", L("Награды", "Daily"), Color3.fromRGB(200, 70, 170), function() show(dayWin, refreshDaily) end)
sideButton("👥", L("Друзья", "Invite"), Color3.fromRGB(40, 170, 90), function()
	pcall(function()
		if SocialService:CanSendGameInviteAsync(player) then
			SocialService:PromptGameInvite(player)
		end
	end)
end)

--=========================================================================
-- «Живой» экран: покачивание кнопок, значок «!», всплывающие +монеты,
-- полоска до следующей покупки
--=========================================================================

-- кнопки магазина и наград слегка покачиваются, чтобы на них смотрели
for i, b in ipairs({ shopBtn, dailyBtn }) do
	task.spawn(function()
		task.wait(i * 0.6)
		while b.Parent do
			TweenService:Create(b, TweenInfo.new(0.12), { Rotation = 6 }):Play() task.wait(0.12)
			TweenService:Create(b, TweenInfo.new(0.12), { Rotation = -6 }):Play() task.wait(0.12)
			TweenService:Create(b, TweenInfo.new(0.12), { Rotation = 0 }):Play()
			task.wait(3)
		end
	end)
end

-- красный значок «!», когда ежедневная награда готова
local badge = text(dailyBtn, {
	Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(1, -18, 0, -12),
	BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(230, 40, 40), Text = "!", Visible = false,
})
corner(badge, 15)
task.spawn(function()
	while true do
		local ok, st = pcall(function() return clubAction:InvokeServer("state") end)
		badge.Visible = ok and st ~= nil and st.dailyReadyIn <= 0
		task.wait(30)
	end
end)

-- всплывающие «+монеты» при каждом пополнении
local last = money.Value
money:GetPropertyChangedSignal("Value"):Connect(function()
	local diff = money.Value - last
	last = money.Value
	if diff <= 0 then return end
	local pop = text(screen, {
		Size = UDim2.new(0, 220, 0, 40),
		Position = UDim2.new(0.5, math.random(-60, 60), 0, 118),
		AnchorPoint = Vector2.new(0.5, 0),
		Text = "+" .. short(diff), TextColor3 = Color3.fromRGB(110, 255, 140),
	})
	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.Parent = pop
	TweenService:Create(pop, TweenInfo.new(0.9, Enum.EasingStyle.Quad), {
		Position = pop.Position - UDim2.new(0, 0, 0, 60), TextTransparency = 1,
	}):Play()
	TweenService:Create(s, TweenInfo.new(0.9), { Transparency = 1 }):Play()
	task.delay(1, function() pop:Destroy() end)
end)

-- полоска «до следующей покупки» внизу экрана
local goal = Instance.new("Frame")
goal.Size = UDim2.new(0, 420, 0, 46)
goal.Position = UDim2.new(0.5, -210, 1, -70)
goal.BackgroundColor3 = Color3.fromRGB(24, 22, 32)
goal.BackgroundTransparency = 0.15
goal.Parent = screen
corner(goal, 12)
stroke(goal, Color3.fromRGB(255, 200, 60), 2)
local fill = Instance.new("Frame")
fill.Size = UDim2.new(0, 0, 1, 0)
fill.BackgroundColor3 = Color3.fromRGB(60, 200, 90)
fill.Parent = goal
corner(fill, 12)
local goalText = text(goal, { Size = UDim2.new(1, -20, 0.8, 0), Position = UDim2.new(0, 10, 0.1, 0), Text = "", ZIndex = 2 })

local function refreshGoal()
	local name, cost = player:GetAttribute("NextName") or "", player:GetAttribute("NextCost") or 0
	goal.Visible = name ~= ""
	if name == "" then return end
	local k = cost > 0 and math.clamp(money.Value / cost, 0, 1) or 1
	TweenService:Create(fill, TweenInfo.new(0.25), { Size = UDim2.new(k, 0, 1, 0) }):Play()
	if k >= 1 then
		goalText.Text = L("✅ Можно купить: ", "✅ Ready: ") .. name .. L(" — иди к стрелке!", " — follow the arrow!")
	else
		goalText.Text = "🎯 " .. name .. ": " .. short(money.Value) .. " / " .. short(cost)
	end
end
money:GetPropertyChangedSignal("Value"):Connect(refreshGoal)
player:GetAttributeChangedSignal("NextName"):Connect(refreshGoal)
player:GetAttributeChangedSignal("NextCost"):Connect(refreshGoal)
refreshGoal()

-- Пасхалка: нашёл золотой сундук в городе
player:GetAttributeChangedSignal("ChestBonus"):Connect(function()
	local v = player:GetAttribute("ChestBonus")
	if not v then return end
	local msg = text(screen, {
		Size = UDim2.new(0, 520, 0, 60), Position = UDim2.new(0.5, 0, 0.3, 0), AnchorPoint = Vector2.new(0.5, 0.5),
		Text = L("💰 СУНДУК! +", "💰 TREASURE! +") .. short(v), TextColor3 = Color3.fromRGB(255, 215, 80),
	})
	local st = Instance.new("UIStroke") st.Thickness = 3 st.Parent = msg
	task.delay(2.5, function() msg:Destroy() end)
	player:SetAttribute("ChestBonus", nil)
end)

-- короткое сообщение от сервера (например, «дверь открывает только хозяин»)
player:GetAttributeChangedSignal("Toast"):Connect(function()
	local v = player:GetAttribute("Toast")
	if not v then return end
	local msg = text(screen, {
		Size = UDim2.new(0, 560, 0, 50), Position = UDim2.new(0.5, 0, 0.3, 0), AnchorPoint = Vector2.new(0.5, 0.5),
		Text = v, TextColor3 = Color3.fromRGB(255, 200, 200),
	})
	task.delay(2.5, function() msg:Destroy() end)
	player:SetAttribute("Toast", nil)
end)

-- сундук на крыше/палубе уже открыт: подождать
player:GetAttributeChangedSignal("ChestWait"):Connect(function()
	local v = player:GetAttribute("ChestWait")
	if not v then return end
	local msg = text(screen, {
		Size = UDim2.new(0, 520, 0, 50), Position = UDim2.new(0.5, 0, 0.3, 0), AnchorPoint = Vector2.new(0.5, 0.5),
		Text = L("⏳ Сундук пуст. Загляни через " .. v .. " мин", "⏳ Empty. Come back in " .. v .. " min"), TextColor3 = Color3.fromRGB(230, 230, 240),
	})
	task.delay(2.5, function() msg:Destroy() end)
	player:SetAttribute("ChestWait", nil)
end)

player:GetAttributeChangedSignal("CatBonus"):Connect(function()
	local v = player:GetAttribute("CatBonus")
	if not v then return end
	local msg = text(screen, {
		Size = UDim2.new(0, 460, 0, 50), Position = UDim2.new(0.5, 0, 0.32, 0), AnchorPoint = Vector2.new(0.5, 0.5),
		Text = L("🐱 Мур! +", "🐱 Purr! +") .. short(v), TextColor3 = Color3.fromRGB(255, 150, 200),
	})
	local st = Instance.new("UIStroke") st.Thickness = 3 st.Parent = msg
	task.delay(2, function() msg:Destroy() end)
	player:SetAttribute("CatBonus", nil)
end)

--=========================================================================
-- Слева внизу: бонус друзей и Premium, справа внизу: энергия
--=========================================================================

local function boostIcon(icon, x, attr, tip)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(0, 84, 0, 84)
	f.Position = UDim2.new(0, x, 1, -96)
	f.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	f.Parent = screen
	corner(f, 16)
	stroke(f, Color3.new(1, 1, 1), 3)
	text(f, { Size = UDim2.new(1, 0, 0.62, 0), Text = icon })
	local l = text(f, { Size = UDim2.new(1, 0, 0.36, 0), Position = UDim2.new(0, 0, 0.64, 0), Text = "+0%" })
	local st = Instance.new("UIStroke") st.Thickness = 2 st.Parent = l
	local function refresh() l.Text = "+" .. math.floor((player:GetAttribute(attr) or 0) * 100 + 0.5) .. "%" end
	player:GetAttributeChangedSignal(attr):Connect(refresh)
	refresh()
	local hint = text(f, { Size = UDim2.new(0, 260, 0, 26), Position = UDim2.new(0, 0, 0, -30), Text = tip, Visible = false, Font = Enum.Font.GothamBold })
	f.MouseEnter:Connect(function() hint.Visible = true end)
	f.MouseLeave:Connect(function() hint.Visible = false end)
end
boostIcon("👥", 12, "FriendBoost", L("+10% за каждого друга на сервере", "+10% per friend in server"))
boostIcon("⭐", 106, "PremiumBoost", L("+10% с Roblox Premium", "+10% with Roblox Premium"))

-- шкала энергии
local eFrame = Instance.new("Frame")
eFrame.Size = UDim2.new(0, 240, 0, 36)
eFrame.Position = UDim2.new(1, -256, 1, -52)
eFrame.BackgroundColor3 = Color3.fromRGB(24, 22, 32)
eFrame.Parent = screen
corner(eFrame, 10)
stroke(eFrame, Color3.fromRGB(255, 230, 80), 2)
local eFill = Instance.new("Frame")
eFill.Size = UDim2.new(1, 0, 1, 0)
eFill.BackgroundColor3 = Color3.fromRGB(80, 220, 90)
eFill.Parent = eFrame
corner(eFill, 10)
local eText = text(eFrame, { Size = UDim2.new(1, -12, 0.8, 0), Position = UDim2.new(0, 6, 0.1, 0), Text = "", ZIndex = 2 })
local function refreshEnergy()
	local e = player:GetAttribute("Energy") or 100
	TweenService:Create(eFill, TweenInfo.new(0.3), { Size = UDim2.new(e / 100, 0, 1, 0) }):Play()
	eFill.BackgroundColor3 = e > 50 and Color3.fromRGB(80, 220, 90) or (e > 20 and Color3.fromRGB(240, 190, 40) or Color3.fromRGB(230, 60, 60))
	eText.Text = "⚡ " .. math.floor(e) .. "%" .. (e <= 20 and L("  — выпей лимонад!", "  — drink lemonade!") or "")
end
-- бесплатный лимонад рядом со шкалой
local freeBtn = button(screen, {
	Size = UDim2.new(0, 70, 0, 50), Position = UDim2.new(1, -334, 1, -59),
	BackgroundColor3 = Color3.fromRGB(255, 220, 60), Text = "🍋 x1", TextColor3 = Color3.fromRGB(60, 40, 0),
}, function()
	clubAction:InvokeServer("drinkFree")
end)
stroke(freeBtn, Color3.new(1, 1, 1), 2)
local function refreshFree()
	local n = player:GetAttribute("FreeLemonade") or 0
	freeBtn.Visible = n > 0
	freeBtn.Text = "🍋 x" .. n
end
player:GetAttributeChangedSignal("FreeLemonade"):Connect(refreshFree)
refreshFree()

-- уведомления, когда энергия падает ниже 50% и 20%
local lastE = player:GetAttribute("Energy") or 100
local function toast(msg, color)
	local t = text(screen, {
		Size = UDim2.new(0, 560, 0, 46), Position = UDim2.new(0.5, 0, 0.26, 0), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 0.1, BackgroundColor3 = Color3.fromRGB(24, 22, 32), Text = msg, TextColor3 = color,
	})
	corner(t, 12)
	stroke(t, color, 2)
	task.delay(4, function() t:Destroy() end)
end
player:GetAttributeChangedSignal("Energy"):Connect(function()
	local e = player:GetAttribute("Energy") or 100
	local hasFree = (player:GetAttribute("FreeLemonade") or 0) > 0
	local tip = hasFree and L(" Жми 🍋 внизу справа!", " Tap 🍋 bottom right!") or L(" Купи лимонад!", " Buy lemonade!")
	if lastE > 50 and e <= 50 then
		toast(L("⚡ Энергия 50% — ты замедляешься.", "⚡ Energy 50% — slowing down.") .. tip, Color3.fromRGB(240, 190, 40))
	elseif lastE > 20 and e <= 20 then
		toast(L("⚠️ Энергия почти на нуле!", "⚠️ Energy almost empty!") .. tip, Color3.fromRGB(255, 80, 80))
	end
	if hasFree and e <= 50 then
		TweenService:Create(freeBtn, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true), { Rotation = 10 }):Play()
	end
	lastE = e
end)

player:GetAttributeChangedSignal("Energy"):Connect(refreshEnergy)
refreshEnergy()

-- Светящаяся «нить» от игрока к следующей кнопке покупки
local beamTarget = Instance.new("Part")
beamTarget.Anchored, beamTarget.CanCollide, beamTarget.CanQuery, beamTarget.CanTouch = true, false, false, false
beamTarget.Transparency = 1
beamTarget.Size = Vector3.new(0.2, 0.2, 0.2)
beamTarget.Parent = workspace
local a1 = Instance.new("Attachment", beamTarget)
local beam = Instance.new("Beam")
beam.Attachment1 = a1
beam.Color = ColorSequence.new(Color3.fromRGB(255, 230, 60))
beam.LightEmission = 1
beam.Width0, beam.Width1 = 0.6, 0.6
beam.FaceCamera = true
beam.Texture = "rbxassetid://446111271"
beam.TextureMode = Enum.TextureMode.Static
beam.TextureLength = 3
beam.TextureSpeed = 2
beam.Transparency = NumberSequence.new(0.2)
beam.Parent = beamTarget
local function hookBeam()
	local pos = player:GetAttribute("NextPos")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if pos and root then
		beamTarget.Position = pos + Vector3.new(0, 1.5, 0)
		local a0 = root:FindFirstChild("ЛучКЦели") or Instance.new("Attachment")
		a0.Name = "ЛучКЦели"
		a0.Position = Vector3.new(0, -2, 0)
		a0.Parent = root
		beam.Attachment0 = a0
		beam.Enabled = true
	else
		beam.Enabled = false
	end
end
player:GetAttributeChangedSignal("NextPos"):Connect(hookBeam)
player.CharacterAdded:Connect(function(c) c:WaitForChild("HumanoidRootPart") hookBeam() end)
task.spawn(function() task.wait(2) hookBeam() end)

-- Цены лимонадов в киосках считаем от дохода именно этого игрока
local CollectionService = game:GetService("CollectionService")
task.spawn(function()
	while true do
		local inc = player.Stats.Income.Value
		for _, pr in ipairs(CollectionService:GetTagged("Lemonade")) do
			local price = math.max(pr:GetAttribute("LemonMin"), math.floor(inc * pr:GetAttribute("LemonSeconds"))) * pr:GetAttribute("LemonMult")
			pr.ActionText = L("Купить · ", "Buy · ") .. short(price)
		end
		task.wait(2)
	end
end)

--=========================================================================
-- Джойстик (PlayStation / Xbox):
--   Y (△)  — перейти к кнопкам слева / выйти из меню
--   B (○)  — закрыть открытое окно
--   стрелки — выбор кнопки, A (✕) — нажать
--=========================================================================
local padHint = text(screen, {
	Size = UDim2.new(0, 96, 0, 22), Position = UDim2.new(0, 12, 0.5, 216),
	Text = "△ / Y — " .. L("меню", "menu"), Font = Enum.Font.GothamBold,
	Visible = UserInputService.GamepadEnabled,
})
UserInputService.GamepadConnected:Connect(function() padHint.Visible = true end)
UserInputService.GamepadDisconnected:Connect(function() padHint.Visible = UserInputService.GamepadEnabled end)

UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.ButtonY then
		if GuiService.SelectedObject then
			GuiService.SelectedObject = nil
		else
			GuiService.SelectedObject = shopBtn
		end
	elseif input.KeyCode == Enum.KeyCode.ButtonB and openWindow and openWindow.Visible then
		openWindow.Visible = false
		GuiService.SelectedObject = shopBtn
	end
end)
