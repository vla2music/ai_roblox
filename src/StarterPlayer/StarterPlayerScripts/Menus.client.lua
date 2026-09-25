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
		BackgroundColor3 = Color3.fromRGB(230, 50, 50), Text = "✕",
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

local function show(win, refresh)
	if openWindow and openWindow ~= win then openWindow.Visible = false end
	openWindow = win
	win.Visible = not win.Visible
	if win.Visible and refresh then task.spawn(refresh) end
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
	tile.Size = UDim2.new(0.3, 0, 0.9, 0)
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

sideButton("🛒", L("Магазин", "Shop"), Color3.fromRGB(230, 70, 70), function() show(shopWin, refreshShop) end)
sideButton("💻", L("Компы", "PCs"), Color3.fromRGB(50, 130, 230), function()
	show(upWin, function()
		local st = clubAction:InvokeServer("state")
		if st then tierButtons.refresh(st) end
	end)
end)
sideButton("📅", L("Награды", "Daily"), Color3.fromRGB(200, 70, 170), function() show(dayWin, refreshDaily) end)
sideButton("👥", L("Друзья", "Invite"), Color3.fromRGB(40, 170, 90), function()
	pcall(function()
		if SocialService:CanSendGameInviteAsync(player) then
			SocialService:PromptGameInvite(player)
		end
	end)
end)
