--[[=========================================================================
	КЛУБ-ТАЙКУН — строим компьютерный клуб
	Серверный скрипт. Кладётся в ServerScriptService.

	Весь мир строится прямо из кода — ничего руками лепить не нужно.
	Хочешь поменять цены, доход или добавить новую покупку — правь
	таблицу ITEMS ниже, больше нигде ничего трогать не надо.
==========================================================================]]

local Players            = game:GetService("Players")
local DataStoreService   = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService       = game:GetService("TweenService")

--=========================================================================
-- 1. НАСТРОЙКИ
--=========================================================================

local CONFIG = {
	CURRENCY_NAME  = "Монеты",
	MAX_PLOTS      = 6,      -- сколько игроков может строить одновременно
	PLOT_SIZE      = 90,     -- размер участка в студах
	PLOT_GAP       = 40,     -- расстояние между участками
	START_MONEY    = 0,
	AUTOSAVE_SEC   = 60,
	DATASTORE_NAME = "ClubTycoon_v1",

	-- ID геймпасса «x2 монеты». Пока 0 — геймпасс просто выключен.
	-- Когда создашь геймпасс на сайте Roblox, впиши сюда его номер.
	DOUBLE_CASH_GAMEPASS = 0,
}

--=========================================================================
-- 2. ЧТО МОЖНО ПОСТРОИТЬ
--
--   id      — уникальное имя (латиницей, без пробелов)
--   name    — что увидит игрок на кнопке
--   cost    — сколько стоит
--   income  — сколько монет в секунду приносит
--   needs   — что нужно купить до этого (id предыдущей покупки)
--   pos     — где стоит объект (X, Y, Z относительно центра участка)
--   kind    — как выглядит: "desk" (комп. стол), "box" (ящик/автомат),
--             "zone" (зона на полу), "sign" (вывеска), "walls" (стены)
--=========================================================================

local ITEMS = {
	{ id="reception", name="Ресепшн",              cost=0,     income=1,   needs=nil,         pos=Vector3.new(  0, 0,  36), kind="box",  size=Vector3.new(10,4,3),  color=Color3.fromRGB( 60,120,200) },
	{ id="pc1",       name="Игровой ПК №1",        cost=25,    income=2,   needs="reception", pos=Vector3.new(-34, 0, -30), kind="desk", color=Color3.fromRGB(200, 60, 80) },
	{ id="pc2",       name="Игровой ПК №2",        cost=120,   income=3,   needs="pc1",       pos=Vector3.new(-34, 0, -15), kind="desk", color=Color3.fromRGB(200, 60, 80) },
	{ id="pc3",       name="Игровой ПК №3",        cost=300,   income=5,   needs="pc2",       pos=Vector3.new(-34, 0,   0), kind="desk", color=Color3.fromRGB(200, 60, 80) },
	{ id="vending",   name="Автомат с едой",       cost=650,   income=9,   needs="pc3",       pos=Vector3.new( 34, 0,  30), kind="box",  size=Vector3.new(5,9,4),   color=Color3.fromRGB(230,150, 30) },
	{ id="chairs",    name="Геймерские кресла",    cost=1200,  income=14,  needs="vending",   pos=Vector3.new(-14, 0,  16), kind="zone", size=Vector3.new(16,1,16),  color=Color3.fromRGB(120, 60,190) },
	{ id="pc4",       name="Игровой ПК №4",        cost=2000,  income=20,  needs="chairs",    pos=Vector3.new(-34, 0,  15), kind="desk", color=Color3.fromRGB(200, 60, 80) },
	{ id="pc5",       name="Игровой ПК №5",        cost=3200,  income=26,  needs="pc4",       pos=Vector3.new(-34, 0,  30), kind="desk", color=Color3.fromRGB(200, 60, 80) },
	{ id="ac",        name="Кондиционер",          cost=5000,  income=35,  needs="pc5",       pos=Vector3.new(  0, 8, -40), kind="box",  size=Vector3.new(12,5,4),  color=Color3.fromRGB(220,220,230) },
	{ id="stream",    name="Стримерская комната",  cost=8000,  income=55,  needs="ac",        pos=Vector3.new( 30, 0, -28), kind="desk", color=Color3.fromRGB( 40,180,140) },
	{ id="vip",       name="VIP-зона",             cost=13000, income=85,  needs="stream",    pos=Vector3.new( 28, 0,  -4), kind="zone", size=Vector3.new(18,1,18),  color=Color3.fromRGB(240,200, 60) },
	{ id="tourney",   name="Турнирная сцена",      cost=22000, income=140, needs="vip",       pos=Vector3.new(  4, 0, -20), kind="zone", size=Vector3.new(22,2,14),  color=Color3.fromRGB( 90,110,255) },
	{ id="walls",     name="Стены и крыша",        cost=35000, income=60,  needs="tourney",   pos=Vector3.new(  0, 0,   0), kind="walls", btn=Vector3.new(-8, 0, 30) },
	{ id="neon",      name="Неоновая вывеска",     cost=50000, income=250, needs="walls",     pos=Vector3.new(  0,26,  42), kind="sign", btn=Vector3.new( 8, 0, 30) },
}

local ITEM_BY_ID = {}
for _, item in ipairs(ITEMS) do
	ITEM_BY_ID[item.id] = item
end

--=========================================================================
-- 3. СОХРАНЕНИЕ ПРОГРЕССА
--=========================================================================

local store = DataStoreService:GetDataStore(CONFIG.DATASTORE_NAME)

local function loadData(userId)
	local ok, result = pcall(function()
		return store:GetAsync("p_" .. userId)
	end)
	if ok and type(result) == "table" then
		return {
			money = tonumber(result.money) or CONFIG.START_MONEY,
			owned = type(result.owned) == "table" and result.owned or {},
		}
	end
	if not ok then
		warn("[КлубТайкун] Не удалось загрузить данные:", result)
	end
	return { money = CONFIG.START_MONEY, owned = {} }
end

local function saveData(userId, data)
	local ok, err = pcall(function()
		store:SetAsync("p_" .. userId, { money = data.money, owned = data.owned })
	end)
	if not ok then
		warn("[КлубТайкун] Не удалось сохранить данные:", err)
	end
	return ok
end

--=========================================================================
-- 4. МЕЛКИЕ ПОМОЩНИКИ
--=========================================================================

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Material = Enum.Material.SmoothPlastic
	for key, value in pairs(props) do
		part[key] = value
	end
	return part
end

-- Красиво пишет большие числа: 15400 -> "15.4К"
local function short(n)
	n = math.floor(n)
	if n >= 1e9 then return string.format("%.1fМрд", n / 1e9) end
	if n >= 1e6 then return string.format("%.1fМлн", n / 1e6) end
	if n >= 1e3 then return string.format("%.1fК",   n / 1e3) end
	return tostring(n)
end

local function addLabel(part, text, color, size)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 220, 0, 60)
	gui.StudsOffset = Vector3.new(0, (part.Size.Y / 2) + 2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 140
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = size ~= "small"
	label.TextSize = 16
	label.Text = text
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui

	return label
end

--=========================================================================
-- 5. СТРОИТЕЛИ ОБЪЕКТОВ
--=========================================================================

local builders = {}

-- Компьютерный стол: столешница + монитор + системник + кресло
function builders.desk(item, origin)
	local model = Instance.new("Model")
	model.Name = item.id

	local table_ = makePart({
		Size = Vector3.new(9, 0.6, 4),
		CFrame = origin * CFrame.new(0, 3.2, 0),
		Color = Color3.fromRGB(45, 45, 55),
		Parent = model,
	})

	makePart({
		Size = Vector3.new(0.8, 3.2, 0.8),
		CFrame = origin * CFrame.new(0, 1.6, 0),
		Color = Color3.fromRGB(35, 35, 40),
		Parent = model,
	})

	makePart({ -- монитор
		Size = Vector3.new(6, 3.4, 0.4),
		CFrame = origin * CFrame.new(0, 5.2, -1.2),
		Color = item.color,
		Material = Enum.Material.Neon,
		Parent = model,
	})

	makePart({ -- системник
		Size = Vector3.new(1.8, 4, 3),
		CFrame = origin * CFrame.new(3.6, 2, 0),
		Color = Color3.fromRGB(25, 25, 30),
		Parent = model,
	})

	makePart({ -- кресло
		Size = Vector3.new(3, 1, 3),
		CFrame = origin * CFrame.new(0, 2, 4),
		Color = Color3.fromRGB(30, 30, 35),
		Parent = model,
	})
	makePart({ -- спинка кресла
		Size = Vector3.new(3, 4.5, 1),
		CFrame = origin * CFrame.new(0, 4.2, 5.2),
		Color = item.color,
		Parent = model,
	})

	model.PrimaryPart = table_
	return model
end

-- Простая коробка: автомат, ресепшн, кондиционер
function builders.box(item, origin)
	local model = Instance.new("Model")
	model.Name = item.id

	local size = item.size or Vector3.new(6, 6, 4)
	local part = makePart({
		Size = size,
		CFrame = origin * CFrame.new(0, size.Y / 2, 0),
		Color = item.color,
		Parent = model,
	})

	makePart({ -- светящаяся полоска, чтобы не выглядело скучно
		Size = Vector3.new(size.X * 0.7, 0.4, size.Z + 0.1),
		CFrame = origin * CFrame.new(0, size.Y * 0.75, 0),
		Color = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.Neon,
		Parent = model,
	})

	model.PrimaryPart = part
	return model
end

-- Зона на полу: ковёр с подсветкой и подписью
function builders.zone(item, origin)
	local model = Instance.new("Model")
	model.Name = item.id

	local size = item.size or Vector3.new(16, 1, 16)
	local pad = makePart({
		Size = size,
		CFrame = origin * CFrame.new(0, size.Y / 2, 0),
		Color = item.color,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		Parent = model,
	})

	addLabel(pad, item.name, item.color)

	model.PrimaryPart = pad
	return model
end

-- Неоновая вывеска над входом
function builders.sign(item, origin)
	local model = Instance.new("Model")
	model.Name = item.id

	local board = makePart({
		Size = Vector3.new(34, 8, 1),
		CFrame = origin,
		Color = Color3.fromRGB(20, 20, 30),
		Parent = model,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.AlwaysOnTop = false
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = "CYBER CLUB"
	label.TextColor3 = Color3.fromRGB(0, 255, 200)
	label.Parent = gui

	model.PrimaryPart = board
	return model
end

-- Стены и крыша вокруг всего участка
function builders.walls(item, origin)
	local model = Instance.new("Model")
	model.Name = item.id

	local half = CONFIG.PLOT_SIZE / 2
	local height = 24
	local color = Color3.fromRGB(70, 70, 90)

	local sides = {
		{ Vector3.new(CONFIG.PLOT_SIZE, height, 2), CFrame.new(0, height / 2, -half) },
		{ Vector3.new(CONFIG.PLOT_SIZE, height, 2), CFrame.new(0, height / 2,  half) },
		{ Vector3.new(2, height, CONFIG.PLOT_SIZE), CFrame.new(-half, height / 2, 0) },
		{ Vector3.new(2, height, CONFIG.PLOT_SIZE), CFrame.new( half, height / 2, 0) },
	}

	local first
	for _, side in ipairs(sides) do
		local wall = makePart({
			Size = side[1],
			CFrame = origin * side[2],
			Color = color,
			Transparency = 0.15,
			Parent = model,
		})
		first = first or wall
	end

	makePart({ -- крыша
		Size = Vector3.new(CONFIG.PLOT_SIZE, 2, CONFIG.PLOT_SIZE),
		CFrame = origin * CFrame.new(0, height, 0),
		Color = Color3.fromRGB(40, 40, 55),
		Transparency = 0.35,
		Parent = model,
	})

	model.PrimaryPart = first
	return model
end

--=========================================================================
-- 6. УЧАСТКИ
--=========================================================================

local plotsFolder = Instance.new("Folder")
plotsFolder.Name = "Участки"
plotsFolder.Parent = workspace

local plots = {}          -- список всех участков
local plotByPlayer = {}   -- игрок -> участок

-- Где стоит кнопка покупки: чуть ближе к центру, чем сам объект
local function buttonPosition(item)
	if item.btn then
		return item.btn
	end
	local flat = Vector3.new(item.pos.X, 0, item.pos.Z)
	if flat.Magnitude < 1 then
		return Vector3.new(0, 0, 12)
	end
	return flat - flat.Unit * 9
end

local function createPlot(index)
	local origin = CFrame.new((index - 1) * (CONFIG.PLOT_SIZE + CONFIG.PLOT_GAP), 0, 0)

	local model = Instance.new("Model")
	model.Name = "Участок" .. index
	model.Parent = plotsFolder

	-- пол
	local floor = makePart({
		Name = "Пол",
		Size = Vector3.new(CONFIG.PLOT_SIZE, 2, CONFIG.PLOT_SIZE),
		CFrame = origin * CFrame.new(0, -1, 0),
		Color = Color3.fromRGB(55, 55, 65),
		Material = Enum.Material.Concrete,
		Parent = model,
	})
	model.PrimaryPart = floor

	-- точка появления игрока
	local spawnPad = makePart({
		Name = "Спавн",
		Size = Vector3.new(10, 1, 10),
		CFrame = origin * CFrame.new(0, 0.5, 40),
		Color = Color3.fromRGB(80, 200, 120),
		Material = Enum.Material.Neon,
		Parent = model,
	})

	-- табличка «свободно / клуб такого-то»
	local pole = makePart({
		Name = "Табличка",
		Size = Vector3.new(1, 14, 1),
		CFrame = origin * CFrame.new(0, 7, 44),
		Color = Color3.fromRGB(30, 30, 40),
		Parent = model,
	})
	local nameLabel = addLabel(pole, "СВОБОДНЫЙ УЧАСТОК", Color3.fromRGB(150, 255, 150))

	-- сейф: сюда капает доход, отсюда игрок его забирает
	local safe = makePart({
		Name = "Сейф",
		Size = Vector3.new(8, 8, 6),
		CFrame = origin * CFrame.new(20, 4, 40),
		Color = Color3.fromRGB(240, 190, 50),
		Material = Enum.Material.Metal,
		Parent = model,
	})
	local safeLabel = addLabel(safe, "СЕЙФ\n0", Color3.fromRGB(255, 240, 150))

	local plot = {
		index      = index,
		model      = model,
		origin     = origin,
		spawnPad   = spawnPad,
		safe       = safe,
		safeLabel  = safeLabel,
		nameLabel  = nameLabel,
		owner      = nil,
		owned      = {},   -- id -> true
		built      = {},   -- id -> Model
		buttons    = {},   -- id -> Part
		storage    = 0,
		income     = 0,
		multiplier = 1,
	}

	-- кнопки покупок
	for _, item in ipairs(ITEMS) do
		local offset = buttonPosition(item)
		local button = makePart({
			Name = "Кнопка_" .. item.id,
			Size = Vector3.new(6, 1.2, 6),
			CFrame = origin * CFrame.new(offset.X, 0.6, offset.Z),
			Color = Color3.fromRGB(200, 70, 70),
			Material = Enum.Material.Neon,
			Parent = model,
		})
		button:SetAttribute("ItemId", item.id)
		addLabel(button, item.name .. "\n" .. short(item.cost) .. " " .. CONFIG.CURRENCY_NAME)
		button.Transparency = 1
		button.CanCollide = false
		for _, child in ipairs(button:GetChildren()) do
			if child:IsA("BillboardGui") then child.Enabled = false end
		end
		plot.buttons[item.id] = button
	end

	plots[index] = plot
	return plot
end

-- Показывать нужно только те кнопки, которые уже доступны по цепочке
local function refreshButtons(plot)
	for _, item in ipairs(ITEMS) do
		local button = plot.buttons[item.id]
		local available =
			plot.owner ~= nil
			and not plot.owned[item.id]
			and (item.needs == nil or plot.owned[item.needs] == true)

		button.Transparency = available and 0 or 1
		button.CanCollide = false
		for _, child in ipairs(button:GetChildren()) do
			if child:IsA("BillboardGui") then
				child.Enabled = available
			end
		end
	end
end

local function recalcIncome(plot)
	local total = 0
	for id in pairs(plot.owned) do
		local item = ITEM_BY_ID[id]
		if item then total += item.income end
	end
	plot.income = total * plot.multiplier

	if plot.owner then
		local stats = plot.owner:FindFirstChild("Stats")
		if stats then stats.Income.Value = plot.income end
	end
end

local function buildItem(plot, item, animate)
	if plot.built[item.id] then return end

	local origin = plot.origin * CFrame.new(item.pos)
	local builder = builders[item.kind] or builders.box
	local model = builder(item, origin)
	model.Parent = plot.model
	plot.built[item.id] = model

	if animate and model.PrimaryPart then
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				local target = part.Transparency
				part.Transparency = 1
				TweenService:Create(part, TweenInfo.new(0.45), { Transparency = target }):Play()
			end
		end
	end
end

local function clearPlot(plot)
	for id, model in pairs(plot.built) do
		model:Destroy()
		plot.built[id] = nil
	end
	plot.owned = {}
	plot.storage = 0
	plot.income = 0
	plot.multiplier = 1
end

--=========================================================================
-- 7. ПОКУПКИ
--=========================================================================

local buyCooldown = {}   -- игрок -> время последней попытки

local function tryBuy(player, plot, item)
	if plot.owner ~= player then return end
	if plot.owned[item.id] then return end
	if item.needs and not plot.owned[item.needs] then return end

	local now = os.clock()
	if buyCooldown[player] and now - buyCooldown[player] < 0.35 then return end
	buyCooldown[player] = now

	local money = player.leaderstats[CONFIG.CURRENCY_NAME]
	if money.Value < item.cost then
		return
	end

	money.Value -= item.cost
	plot.owned[item.id] = true
	buildItem(plot, item, true)
	recalcIncome(plot)
	refreshButtons(plot)
end

local function connectPlotTouches(plot)
	for id, button in pairs(plot.buttons) do
		local item = ITEM_BY_ID[id]
		button.Touched:Connect(function(hit)
			if button.Transparency == 1 then return end
			local character = hit.Parent
			local player = character and Players:GetPlayerFromCharacter(character)
			if player then
				tryBuy(player, plot, item)
			end
		end)
	end

	plot.safe.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player or plot.owner ~= player then return end
		if plot.storage < 1 then return end

		local amount = math.floor(plot.storage)
		plot.storage -= amount
		player.leaderstats[CONFIG.CURRENCY_NAME].Value += amount

		local stats = player:FindFirstChild("Stats")
		if stats then stats.Storage.Value = plot.storage end
		plot.safeLabel.Text = "СЕЙФ\n0"
	end)
end

--=========================================================================
-- 8. ИГРОКИ
--=========================================================================

local function findFreePlot()
	for _, plot in ipairs(plots) do
		if plot.owner == nil then return plot end
	end
	return nil
end

local function hasDoubleCash(player)
	if CONFIG.DOUBLE_CASH_GAMEPASS == 0 then return false end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, CONFIG.DOUBLE_CASH_GAMEPASS)
	end)
	return ok and owns
end

local function onPlayerAdded(player)
	-- статистика в таблице игроков
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local money = Instance.new("IntValue")
	money.Name = CONFIG.CURRENCY_NAME
	money.Parent = leaderstats

	-- вспомогательные значения для интерфейса
	local stats = Instance.new("Folder")
	stats.Name = "Stats"
	stats.Parent = player

	local income = Instance.new("NumberValue")
	income.Name = "Income"
	income.Parent = stats

	local storage = Instance.new("NumberValue")
	storage.Name = "Storage"
	storage.Parent = stats

	local data = loadData(player.UserId)
	money.Value = data.money

	local plot = findFreePlot()
	if not plot then
		warn("[КлубТайкун] Свободных участков нет для", player.Name)
		return
	end

	plot.owner = player
	plot.owned = {}
	plot.multiplier = hasDoubleCash(player) and 2 or 1
	plotByPlayer[player] = plot
	plot.nameLabel.Text = "КЛУБ · " .. player.DisplayName
	plot.nameLabel.TextColor3 = Color3.fromRGB(0, 255, 200)

	-- восстанавливаем всё, что было куплено раньше
	for _, item in ipairs(ITEMS) do
		if data.owned[item.id] then
			plot.owned[item.id] = true
			buildItem(plot, item, false)
		end
	end

	recalcIncome(plot)
	refreshButtons(plot)

	player.CharacterAdded:Connect(function(character)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root then
			task.wait(0.1)
			root.CFrame = plot.spawnPad.CFrame * CFrame.new(0, 4, 0)
		end
	end)
end

local function collectData(player)
	local plot = plotByPlayer[player]
	local money = player:FindFirstChild("leaderstats")
		and player.leaderstats:FindFirstChild(CONFIG.CURRENCY_NAME)

	return {
		money = money and money.Value or CONFIG.START_MONEY,
		owned = plot and plot.owned or {},
	}
end

local function onPlayerRemoving(player)
	saveData(player.UserId, collectData(player))

	local plot = plotByPlayer[player]
	if plot then
		clearPlot(plot)
		plot.owner = nil
		plot.nameLabel.Text = "СВОБОДНЫЙ УЧАСТОК"
		plot.nameLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
		plot.safeLabel.Text = "СЕЙФ\n0"
		refreshButtons(plot)
		plotByPlayer[player] = nil
	end
	buyCooldown[player] = nil
end

--=========================================================================
-- 9. ЗАПУСК
--=========================================================================

for index = 1, CONFIG.MAX_PLOTS do
	connectPlotTouches(createPlot(index))
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- игроки, которые успели зайти до загрузки скрипта
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- доход капает в сейф раз в секунду
task.spawn(function()
	while true do
		task.wait(1)
		for _, plot in ipairs(plots) do
			if plot.owner and plot.income > 0 then
				plot.storage += plot.income
				plot.safeLabel.Text = "СЕЙФ\n" .. short(plot.storage)

				local stats = plot.owner:FindFirstChild("Stats")
				if stats then stats.Storage.Value = plot.storage end
			end
		end
	end
end)

-- автосохранение
task.spawn(function()
	while true do
		task.wait(CONFIG.AUTOSAVE_SEC)
		for _, player in ipairs(Players:GetPlayers()) do
			saveData(player.UserId, collectData(player))
		end
	end
end)

-- сохраняем всех при выключении сервера
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveData(player.UserId, collectData(player))
	end
	task.wait(2)
end)

print("[КлубТайкун] Сервер запущен. Участков:", CONFIG.MAX_PLOTS)
