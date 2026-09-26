--[[=========================================================================
	КЛУБ-ТАЙКУН — строим компьютерный клуб
	Серверный скрипт. Кладётся в ServerScriptService.

	Весь мир строится прямо из кода — ничего руками лепить не нужно.
	Хочешь поменять цены, доход или добавить новую покупку — правь
	таблицу ITEMS ниже.

	Планировка — по рисунку Назара (первый этаж):
	  слева комнаты PlayStation / VIP SOLO / Стрим, внизу серверная и туалет,
	  в центре банкомат, сцена с фото, магазин, стойка админа, лаунж,
	  справа чемпионатная и общий зал с компами.
==========================================================================]]

local Players            = game:GetService("Players")
local DataStoreService   = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService       = game:GetService("TweenService")
local SoundService       = game:GetService("SoundService")
local ServerStorage      = game:GetService("ServerStorage")
local Lighting           = game:GetService("Lighting")
local MaterialService    = game:GetService("MaterialService")

-- Красивые модели из магазина Roblox лежат в ServerStorage > Шаблоны.
-- Если какой-то модели там нет, вместо неё строится простая из кубиков.
local templates = ServerStorage:FindFirstChild("Шаблоны")
local Shared = require(game:GetService("ReplicatedStorage"):WaitForChild("ClubShared"))

--=========================================================================
-- 1. НАСТРОЙКИ
--=========================================================================

local CONFIG = {
	CURRENCY_NAME  = "Coins",   -- колонка в таблице игроков (одна для всех языков)
	MAX_PLOTS      = 6,      -- сколько игроков может строить одновременно
	PLOT_WIDTH     = 200,    -- участок: ширина (X) в студах
	PLOT_DEPTH     = 140,    -- участок: глубина (Z) в студах
	PLOT_GAP       = 40,     -- расстояние между участками
	START_MONEY    = 0,
	AUTOSAVE_SEC   = 60,
	DATASTORE_NAME = "ClubTycoon_v2",   -- v2: новая планировка, все начинают заново

	-- План нарисован в «клетках» 120 x 70. Одна клетка = SCALE студов.
	SCALE          = 1.5,
	WALL_HEIGHT    = 14,
	PC_SCALE       = 0.75,   -- компьютеры из магазина немного уменьшены

	-- Участок приподнят над базовой площадкой Roblox, чтобы пол не рябил.
	PLOT_HEIGHT    = 1,

	-- Музыка и звуки. Пусто = звука нет.
	MUSIC_IDS      = {   -- саундтрек, написанный VLA2music для игры
		"rbxassetid://133708548304035",  -- 1 main theme v1
		"rbxassetid://130837476281470",  -- 2 chill build v1
		"rbxassetid://95389529482733",   -- 3 money rush v1
		"rbxassetid://80980528574776",   -- 4 night grind v1
		"rbxassetid://110101349456930",  -- 1 main theme v2
		"rbxassetid://85207777649406",   -- 2 chill build v2
		"rbxassetid://137736757201497",  -- 3 money rush v2
		"rbxassetid://78794045428310",   -- 4 night grind v2
	},
	MUSIC_VOLUME   = 0.3,
	SOUND_BUY      = "rbxassetid://131737037329240",  -- звук покупки
	SOUND_COLLECT  = "rbxassetid://119832205290967",  -- звон монетки (загружен VLA2music)
	-- Гул людей в клубе: включается с первым ПК и растёт с каждым новым.
	SOUND_CROWD    = "rbxassetid://101285875048662",  -- гул клуба (загружен VLA2music)
	CROWD_VOLUME_MIN = 0.13,
	CROWD_VOLUME_MAX = 0.5,

	-- Ковролин для пола (создан в Studio, лежит в MaterialService)
	FLOOR_MATERIAL_VARIANT = "ClubCarpet",

	-- Фото владельца на сцене. Когда загрузим картинку — впиши её ID сюда.
	POSTER_IMAGE   = "",   -- реальные фото детей Roblox запрещает (правило о личных данных). Только аватар!
	-- Видео владельца на сцене (важнее фото). Впиши ID после загрузки
	-- на create.roblox.com, например "rbxassetid://1234567890".
	POSTER_VIDEO   = "",
	POSTER_VIDEO_VOLUME = 0.5,
	-- Бесплатная замена видео: «мультик» из кадров в одной картинке
	-- (раскадровка 6x4, кадр 170x248) + отдельный звук.
	POSTER_FLIPBOOK = {
		image  = "",   -- ID картинки media/nazar_spritesheet.png
		sound  = "",   -- ID звука media/nazar_sound.mp3
		cols   = 6, rows = 4,
		frameW = 170, frameH = 248,
		length = 5.17,  -- секунд на весь ролик
		pause  = 3,     -- пауза на последнем кадре перед повтором
		volume = 0.5,
	},

	-- Банкомат: сам выбрасывает монетки на площадку,
	-- а если жать E рядом с ним — выбрасывает ещё и бонусные.
	CLICK_COOLDOWN = 0.4,   -- как часто можно жать E (секунды)
	CLICK_BONUS    = 0.1,    -- бонус за нажатие = доход в секунду * это число
	MAX_COINS      = 40,     -- больше монет на площадке не лежит, они «слипаются»

	SERVER_BOOST   = 1.5,
	-- В Studio создатель автоматически «владеет» всеми геймпассами, из-за этого
	-- монеты не падают (авто-сбор). true = в Studio играем как обычный игрок.
	STUDIO_IGNORE_PASSES = true,    -- серверная умножает весь доход

	-- Геймпассы (табло у входа). id = 0 — ещё не создан, карточка пишет «скоро».
	-- Создать: create.roblox.com -> игра -> Monetization -> Passes -> Create,
	-- потом вписать сюда ID. price — только для надписи на табло, реальную
	-- цену ставишь на сайте Roblox.
	GAMEPASSES = Shared.GAMEPASSES,   -- настройки геймпассов — в ReplicatedStorage/ClubShared
}

local S = CONFIG.SCALE

--=========================================================================
-- 2. ЧТО МОЖНО ПОСТРОИТЬ
--
-- Все координаты — в клетках плана: X от -60 (лево) до 60 (право),
-- Z от -35 (верх рисунка) до 35 (низ, там вход).
--
--   id      — уникальное имя (латиницей)
--   name/en — название по-русски и по-английски
--   cost    — цена, income — монет в секунду
--   needs   — что нужно купить до этого
--   kind    — "model" (модель из магазина), "pcs" (компьютеры),
--             "room" (комната со стенами), "outer" (стены клуба),
--             "lounge", "sofaset", "stage"
--   btn     — где стоит кнопка покупки
--=========================================================================

local ITEMS = {
	{ id="admin",   name="Стойка админа",   en="Admin Desk",       cost=0,      income=1,   needs=nil,
	  kind="model", model="reception", pos={-13, 10}, rot=90, scale=0.8, btn={-4, 28} },

	{ id="pc1", name="Игровой ПК №1", en="Gaming PC #1", cost=15,  income=1, needs="admin", kind="pcs", pcs={{-24, 14}}, rot=-90, btn={-30, 14} },
	{ id="pc2", name="Игровой ПК №2", en="Gaming PC #2", cost=40,  income=2, needs="pc1",   kind="pcs", pcs={{-24,  5}}, rot=-90, btn={-30,  5} },
	{ id="pc3", name="Игровой ПК №3", en="Gaming PC #3", cost=90,  income=3, needs="pc2",   kind="pcs", pcs={{-24, -3}}, rot=-90, btn={-30, -3} },
	{ id="pc4", name="Игровой ПК №4", en="Gaming PC #4", cost=160, income=4, needs="pc3",   kind="pcs", pcs={{-24,-11}}, rot=-90, btn={-30,-11} },

	{ id="walls",  name="Стены клуба", en="Club Walls",  cost=250,  income=3, needs="pc4",  kind="outer", btn={8, 28} },
	{ id="shop",   name="Два магазина", en="Two Snack Shops", cost=400, income=6, needs="walls",
	  kind="shops", btn={-9, -4} },

	{ id="hall",  name="Общий зал", en="Main Hall", cost=600, income=4, needs="shop",
	  kind="room", rect={13, 0.5, 60, 35}, doors={{"W", 31, 4}}, skip={E=true, S=true}, floor=Color3.fromRGB(70, 60, 95), btn={8, 31} },
	{ group="hall1", name="ПК в зале", en="Hall PC", minTier=2, kind="pcs",
	  pcs={{20,8},{28,8},{36,8},{44,8},{52,8}},    rot=0, btnDz=-4.5 },
	{ group="hall2", name="ПК в зале", en="Hall PC", minTier=2, kind="pcs",
	  pcs={{20,17},{28,17},{36,17},{44,17},{52,17}}, rot=0, btnDz=-4.5 },
	{ group="hall3", name="ПК в зале", en="Hall PC", minTier=2, kind="pcs",
	  pcs={{20,26},{28,26},{36,26},{44,26},{52,26}}, rot=0, btnDz=-4.5 },

	{ id="toilet", name="Туалет", en="Restroom", cost=3500, income=26, needs="hall3",
	  kind="room", rect={-31, 20, -19, 35}, doors={{"E", 25, 4}}, skip={S=true}, extra="toilet",
	  floor=Color3.fromRGB(200, 205, 215), btn={-15, 25} },
	{ id="lounge", name="Лаунж с телевизором", en="TV Lounge", cost=5000, income=15, needs="toilet",
	  kind="lounge", btn={4, 30} },
	{ id="sofaset", name="Диван и стулья", en="Sofa & Chairs", cost=7000, income=20, needs="lounge",
	  kind="sofaset", btn={-2, -9} },
	{ group="graffiti", name="Граффити", en="Graffiti", kind="graffiti",
	  pcs={ {32,-34.4,0,32,-27}, {50,-34.4,0,50,-27}, {59.4,6,-90,55,6}, {59.4,26,-90,55,28}, {30,34.4,180,26,31}, {48,34.4,180,44,31}, {-12,34.4,180,-8,31} } },
	{ group="toprow", name="ПК у стены", en="Wall PC", kind="pcs",
	  pcs={{19,-31},{25,-31},{31,-31},{37,-31},{43,-31},{49,-31}}, rot=0, btnDz=4.5 },

	{ id="server", name="Серверная (доход +10%)", en="Server Room (+10% income)", needs=nil,
	  kind="room", rect={-60, 20, -31, 35}, doors={{"N", -35, 5}}, skip={W=true, S=true, E=true}, extra="servers",
	  floor=Color3.fromRGB(40, 45, 55), btn={-35, 16} },
	{ group="racks", name="Серверная стойка (+10%)", en="Server Rack (+10%)", kind="rack",
	  pcs={{-57,31},{-51.5,31},{-46,31},{-40.5,31},{-35,31}}, btnDz=-5.5 },

	{ id="champ",  name="Зал для чемпионатов", en="Championship Room", cost=22000, income=10, needs="server",
	  kind="room", rect={12, -20, 60, 0}, doors={{"W", -10, 4}}, skip={S=true, E=true}, extra="champDivider",
	  floor=Color3.fromRGB(40, 55, 110), btn={7, -10} },
	{ group="champ1", name="Красные: ПК", en="Red Team PC", kind="pcs", minTier=2,
	  pcs={{20,-12},{28,-12},{36,-12},{44,-12},{52,-12}}, rot=180, color=Color3.fromRGB(230, 70, 70), btnDz=-4.5 },
	{ group="champ2", name="Синие: ПК", en="Blue Team PC", kind="pcs", minTier=2,
	  pcs={{20,-5},{28,-5},{36,-5},{44,-5},{52,-5}}, rot=0, color=Color3.fromRGB(70, 130, 255), btnDz=3.5 },

	{ id="stream", trim=Color3.fromRGB(255, 30, 50), name="Стримерская", en="Streamer Room", cost=60000, income=120, needs="champ2",
	  kind="room", rect={-60, 3, -40, 20}, doors={{"E", 12, 4}}, skip={W=true, S=true}, extra="stream",
	  floor=Color3.fromRGB(60, 30, 70), btn={-36, 12} },
	{ id="console", name="Комната PlayStation", en="PlayStation Room", cost=90000, income=160, needs="stream",
	  kind="room", rect={-60, -35, -40, -14}, doors={{"E", -24, 4}}, skip={W=true, N=true}, extra="console",
	  floor=Color3.fromRGB(30, 50, 90), btn={-36, -24} },
	{ id="vip", name="VIP SOLO", en="VIP SOLO", cost=130000, income=250, needs="console",
	  kind="room", rect={-60, -14, -40, 3}, doors={{"E", -5, 4}}, skip={W=true, N=true, S=true}, extra="vip",
	  floor=Color3.fromRGB(90, 70, 20), btn={-36, -5} },
	{ id="stage", name="Сцена с фото владельца", en="Stage & Owner Photo", cost=180000, income=350, needs="vip",
	  kind="stage", btn={-5, -21} },
}

-- Группы (ряды компов, стойки) разворачиваем в покупки по одной штуке
do
	local expanded, counters = {}, {}
	for _, item in ipairs(ITEMS) do
		if item.group then
			for k, p in ipairs(item.pcs) do
				local base = item.name
				counters[base] = (counters[base] or 0) + 1
				local n = counters[base]
				local single = table.clone(item)
				single.id = item.group .. "_" .. k
				single.name = base .. " №" .. n
				single.en = item.en .. " #" .. n
				single.pcs = { p }
				single.btn = p[4] and { p[4], p[5] } or { p[1], p[2] + (item.btnDz or -4.5) }
				table.insert(expanded, single)
			end
		else
			table.insert(expanded, item)
		end
	end
	ITEMS = expanded
end

-- Экономика: цена растёт в 1.22 раза с каждой покупкой, окупаемость
-- покупки = 30 + 6*номер секунд. Весь этаж ≈ 30 мин без нажатий E,
-- ≈ 25 мин при активной игре (E, мини-игры, сундук).
do
	local C0, GROWTH, PB0, PBK = 12, 1.22, 30, 6   -- первый проход ≈25 мин (см. комментарий выше)
	for i, item in ipairs(ITEMS) do
		item.needs = i > 1 and ITEMS[i - 1].id or nil
		if i == 1 then
			item.cost, item.income = 0, 1
		else
			item.cost = math.floor(C0 * GROWTH ^ (i - 2))
			if item.cost > 1000 then item.cost = math.floor(item.cost / 10) * 10 end
			item.income = math.max(1, math.floor(item.cost / (PB0 + PBK * (i - 1))))
		end
		-- стойки и серверная дают процент ко всему доходу, а не монеты
		if item.kind == "rack" or item.id == "server" then item.income = 0 end
	end
end

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
			owned = (function(owned)
				owned = type(owned) == "table" and owned or {}
				for _, item in ipairs(ITEMS) do
					local g = item.id:match("^(.-)_%d+$")
					if g and owned[g] then owned[item.id] = true end
					if item.kind == "rack" and owned.server then owned[item.id] = true end
				end
				return owned
			end)(result.owned),
			rebirths = tonumber(result.rebirths) or 0,
			pcTier = tonumber(result.pcTier) or 1,
			playTime = tonumber(result.playTime) or 0,
			totalEarned = tonumber(result.totalEarned) or 0,
			dailyLast = tonumber(result.dailyLast) or 0,
			dailyStreak = tonumber(result.dailyStreak) or 0,
		}
	end
	if not ok then
		warn("[КлубТайкун] Не удалось загрузить данные:", result)
		-- loadFailed: сохранять такого игрока нельзя, иначе пустой клуб
		-- затрёт настоящий прогресс в хранилище
		return { money = CONFIG.START_MONEY, owned = {}, rebirths = 0, pcTier = 1, dailyLast = 0, dailyStreak = 0, loadFailed = true }
	end
	return { money = CONFIG.START_MONEY, owned = {}, rebirths = 0, pcTier = 1, dailyLast = 0, dailyStreak = 0 }
end

local noSave = {}   -- userId -> true, если сохранение не загрузилось

local function saveData(userId, data)
	if noSave[userId] then
		warn("[КлубТайкун] Пропускаю сохранение: прогресс не был загружен", userId)
		return false
	end
	local ok, err = pcall(function()
		store:SetAsync("p_" .. userId, {
			money = data.money, owned = data.owned, rebirths = data.rebirths,
			pcTier = data.pcTier, dailyLast = data.dailyLast, dailyStreak = data.dailyStreak,
			playTime = data.playTime, totalEarned = data.totalEarned,
		})
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
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		part[key] = value
	end
	return part
end

-- точка на плане (в клетках) -> CFrame на участке; y — в студах
local function at(origin, x, y, z)
	return origin * CFrame.new(x * S, y, z * S)
end

-- коробка: size в студах, позиция на плане
local function box(parent, origin, size, x, y, z, color, material, extra)
	local props = {
		Size = size,
		CFrame = at(origin, x, y, z),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	}
	if extra then
		for k, v in pairs(extra) do props[k] = v end
	end
	return makePart(props)
end

-- Красиво пишет большие числа: 15400 -> "15.4K"
local function short(n)
	n = math.floor(n)
	if n >= 1e9 then return string.format("%.1fB", n / 1e9) end
	if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
	if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
	return tostring(n)
end

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

--=========================================================================
-- ЯЗЫК: русскоязычные видят русский, все остальные — английский
--=========================================================================

local TEXT = {
	ru = {
		free      = "БЕСПЛАТНО",
		freePlot  = "СВОБОДНЫЙ УЧАСТОК",
		club      = "КЛУБ · %s",
		machine   = "БАНКОМАТ\nжми E!",
		machineOn = "БАНКОМАТ\n+%s/сек · жми E!",
		action    = "Получить монеты",
		object    = "Банкомат",
		locked    = "🔒 %s\n%s",
		soon      = "🔒 СКОРО",
		secret    = "???",
		poster    = "ФОТО ВЛАДЕЛЬЦА\nскоро",
	},
	en = {
		free      = "FREE",
		freePlot  = "FREE PLOT",
		club      = "%s'S CLUB",
		machine   = "ATM\npress E!",
		machineOn = "ATM\n+%s/sec · press E!",
		action    = "Get coins",
		object    = "ATM",
		locked    = "🔒 %s\n%s",
		soon      = "🔒 COMING SOON",
		secret    = "???",
		poster    = "OWNER PHOTO\ncoming soon",
	},
}

local function langOf(player)
	local locale = player and player.LocaleId or ""
	if locale:sub(1, 2) == "ru" then return "ru" end
	return "en"
end

local function T(lang, key, ...)
	local text = (TEXT[lang] or TEXT.en)[key]
	if select("#", ...) > 0 then return string.format(text, ...) end
	return text
end

local function itemName(item, lang)
	if lang == "ru" then return item.name end
	return item.en or item.name
end

local function priceText(item, lang)
	if item.cost == 0 then return T(lang, "free") end
	if lang == "ru" then return short(item.cost) .. " " .. coins(item.cost) end
	return short(item.cost) .. (item.cost == 1 and " coin" or " coins")
end

-- Проигрывает звук один раз и убирает его за собой
local function playSound(soundId, parent, volume)
	if not soundId or soundId == "" or not parent then return end

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.Parent = parent
	sound:Play()

	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	task.delay(10, function()
		if sound.Parent then sound:Destroy() end
	end)
end

local function addLabel(part, text, color, offsetY)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 220, 0, 60)
	gui.StudsOffset = Vector3.new(0, offsetY or ((part.Size.Y / 2) + 2), 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui

	return label
end

-- надпись на плоскости (вывеска на стене)
local function addSign(part, face, text, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.Parent = gui
	return label
end

--=========================================================================
-- 5. СТРОИТЕЛИ
--=========================================================================

local WALL_COLOR  = Color3.fromRGB(85, 75, 110)
local INNER_COLOR = Color3.fromRGB(110, 100, 135)

-- Стены прямоугольника с проёмами-дверями.
-- rect = {x1, z1, x2, z2} (клетки), doors = {{"N"/"S"/"W"/"E", где, ширина}}
-- skip = {N=true,...} — сторону не строить (там уже есть другая стена)
local NEON_TRIM = Color3.fromRGB(0, 230, 255)   -- неоновые плинтусы

local function buildWalls(parent, origin, rect, doors, skip, height, color, trim)
	local x1, z1, x2, z2 = rect[1], rect[2], rect[3], rect[4]
	skip = skip or {}
	local sides = {
		N = { horizontal = true,  fixed = z1, from = x1, to = x2 },
		S = { horizontal = true,  fixed = z2, from = x1, to = x2 },
		W = { horizontal = false, fixed = x1, from = z1, to = z2 },
		E = { horizontal = false, fixed = x2, from = z1, to = z2 },
	}
	for name, side in pairs(sides) do
		if not skip[name] then
			-- собираем проёмы на этой стороне
			local gaps = {}
			for _, door in ipairs(doors or {}) do
				if door[1] == name then
					table.insert(gaps, { door[2] - door[3] / 2, door[2] + door[3] / 2 })
				end
			end
			table.sort(gaps, function(a, b) return a[1] < b[1] end)

			local cursor = side.from
			local segments = {}
			for _, gap in ipairs(gaps) do
				if gap[1] > cursor then table.insert(segments, { cursor, gap[1] }) end
				cursor = math.max(cursor, gap[2])
			end
			if side.to > cursor then table.insert(segments, { cursor, side.to }) end

			for _, seg in ipairs(segments) do
				local mid = (seg[1] + seg[2]) / 2
				local len = (seg[2] - seg[1]) * S
				if side.horizontal then
					box(parent, origin, Vector3.new(len, height, 1), mid, height / 2, side.fixed, color)
					box(parent, origin, Vector3.new(len, 0.35, 1.3), mid, 0.4, side.fixed, trim or NEON_TRIM, Enum.Material.Neon, { CanCollide = false })
				else
					box(parent, origin, Vector3.new(1, height, len), side.fixed, height / 2, mid, color)
					box(parent, origin, Vector3.new(1.3, 0.35, len), side.fixed, 0.4, mid, trim or NEON_TRIM, Enum.Material.Neon, { CanCollide = false })
				end
			end
		end
	end
end

local function cloneTemplate(name, scale)
	local template = templates and templates:FindFirstChild(name)
	if not template then return nil end
	local model = template:Clone()
	if scale and scale ~= 1 then
		model:ScaleTo(scale)
	end
	return model
end

local function sofa(parent, origin, x, z, rot, color)
	local base = at(origin, x, 0, z) * CFrame.Angles(0, math.rad(rot or 0), 0)
	local function piece(size, offset)
		makePart({ Size = size, CFrame = base * offset, Color = color, Material = Enum.Material.Fabric, Parent = parent })
	end
	piece(Vector3.new(9, 1.6, 3.4), CFrame.new(0, 1, 0))          -- сиденье
	piece(Vector3.new(9, 2.6, 0.9), CFrame.new(0, 2.8, 1.3))      -- спинка
	piece(Vector3.new(0.9, 2.2, 3.4), CFrame.new(-4.5, 2, 0))     -- подлокотник
	piece(Vector3.new(0.9, 2.2, 3.4), CFrame.new( 4.5, 2, 0))
end

local function tv(parent, origin, x, y, z, rot, width)
	local cf = at(origin, x, y, z) * CFrame.Angles(0, math.rad(rot or 0), 0)
	makePart({ Size = Vector3.new(width, width * 0.58, 0.5), CFrame = cf, Color = Color3.fromRGB(20, 20, 25), Parent = parent })
	makePart({ -- экран
		Size = Vector3.new(width - 0.5, width * 0.58 - 0.5, 0.1),
		CFrame = cf * CFrame.new(0, 0, -0.3),
		Color = Color3.fromRGB(90, 150, 230),
		Material = Enum.Material.Glass,
		Parent = parent,
	})
	-- на экране «передача»: переливающаяся картинка + бегущая строка
	local screen = parent:GetChildren()[#parent:GetChildren()]
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.Parent = screen
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.Parent = gui
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 140)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 200, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 220, 60)),
		})
		g.Parent = f
		game:GetService("CollectionService"):AddTag(g, "GameScreen")
		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(1, 0, 0.35, 0)
		t.Position = UDim2.new(0, 0, 0.6, 0)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0
		t.Text = "📺 ESPORTS LIVE · NAZAR CLUB"
		t.Parent = f
	end
end

local builders = {}

-- Запасной компьютерный стол из кубиков (если шаблона "pc" нет)
local function simpleDesk(parent, cf, color)
	makePart({ Size = Vector3.new(6, 0.5, 3), CFrame = cf * CFrame.new(0, 3, 0), Color = Color3.fromRGB(45, 45, 55), Parent = parent })
	makePart({ Size = Vector3.new(0.6, 3, 0.6), CFrame = cf * CFrame.new(0, 1.5, 0), Color = Color3.fromRGB(35, 35, 40), Parent = parent })
	makePart({ Size = Vector3.new(4, 2.4, 0.3), CFrame = cf * CFrame.new(0, 4.6, -1), Color = color, Material = Enum.Material.Glass, Parent = parent })
	makePart({ Size = Vector3.new(2.4, 0.6, 2.4), CFrame = cf * CFrame.new(0, 1.6, 3), Color = Color3.fromRGB(30, 30, 35), Parent = parent })
end

-- Компьютеры: один или целый ряд
--=========================================================================
-- ЖИВЫЕ ЛЮДИ: посетители за компами, продавец, уборщик, кот
--=========================================================================

local applySpeedRef = function() end   -- настоящая функция подставится ниже

-- ЭНЕРГИЯ: медленно падает, чем меньше — тем медленнее ходишь.
-- Пополняется лимонадами (в клубе дороже в 3 раза, чем в киоске через дорогу).
local plotByPlayerRef = {}
local function lemonadePrice(plot, kind, mult)
	return math.max(kind.minPrice, math.floor(plot.income * kind.seconds)) * mult
end

local function lemonadePrompt(host, kind, mult, plot)
	local prompt = Instance.new("ProximityPrompt")
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = host
	prompt:SetAttribute("LemonSeconds", kind.seconds)
	prompt:SetAttribute("LemonMin", kind.minPrice)
	prompt:SetAttribute("LemonMult", mult)
	prompt:SetAttribute("LemonEnergy", kind.energy)
	game:GetService("CollectionService"):AddTag(prompt, "Lemonade")
	local function label(lang, p)
		prompt.ObjectText = (lang == "ru" and kind.ru or kind.en) .. " +" .. kind.energy .. "⚡"
		prompt.ActionText = (lang == "ru" and "Купить · " or "Buy · ") .. (p and short(lemonadePrice(p, kind, mult)) or "")
	end
	task.spawn(function()
		while prompt.Parent do
			if plot then label(plot.lang, plot) else label("en") end
			task.wait(3)
		end
	end)
	prompt.Triggered:Connect(function(player)
		local p = plot or plotByPlayerRef[player]
		if not p or not player:FindFirstChild("leaderstats") then return end
		local money = player.leaderstats[CONFIG.CURRENCY_NAME]
		local cost = lemonadePrice(p, kind, mult)
		if money.Value < cost then return end
		if (player:GetAttribute("Energy") or 100) >= 100 then return end
		money.Value -= cost
		player:SetAttribute("Energy", math.min(100, (player:GetAttribute("Energy") or 100) + kind.energy))
		applySpeedRef(player)
	end)
	return prompt
end
_G.ClubLemonadePrompt = lemonadePrompt   -- киоск в городе (City.server.lua)

local ANIM_SIT  = "rbxassetid://2506281703"
local ANIM_WALK = "rbxassetid://507777826"
local SKIN = { Color3.fromRGB(234, 184, 146), Color3.fromRGB(198, 140, 100), Color3.fromRGB(141, 85, 56), Color3.fromRGB(255, 213, 170) }
local CLOTH = { Color3.fromRGB(220, 50, 60), Color3.fromRGB(40, 120, 220), Color3.fromRGB(40, 170, 90), Color3.fromRGB(240, 200, 50),
	Color3.fromRGB(150, 70, 200), Color3.fromRGB(30, 30, 35), Color3.fromRGB(240, 240, 245), Color3.fromRGB(255, 130, 40) }

local function makeNPC(name, shirt, pants)
	local ok, npc = pcall(function()
		local d = Instance.new("HumanoidDescription")
		local skin = SKIN[math.random(#SKIN)]
		d.HeadColor, d.LeftArmColor, d.RightArmColor = skin, skin, skin
		d.TorsoColor = shirt or CLOTH[math.random(#CLOTH)]
		local legs = pants or CLOTH[math.random(#CLOTH)]
		d.LeftLegColor, d.RightLegColor = legs, legs
		return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	end)
	if not ok then return nil end
	npc.Name = name
	npc.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	for _, d in ipairs(npc:GetDescendants()) do
		if d:IsA("BasePart") then d.CanCollide = false end
	end
	return npc
end

local function playAnim(npc, id, speed)
	local animator = npc.Humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", npc.Humanoid)
	local a = Instance.new("Animation")
	a.AnimationId = id
	local track = animator:LoadAnimation(a)
	track.Looped = true
	track:Play()
	if speed then track:AdjustSpeed(speed) end
	return track
end

-- Посетитель садится в кресло у компа и «играет»
local seats = {}   -- кресло -> модель, куда сажать; живые/свободные места
local function fade(npc, to, time)
	for _, d in ipairs(npc:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			TweenService:Create(d, TweenInfo.new(time), { Transparency = to }):Play()
		elseif d:IsA("Decal") then
			TweenService:Create(d, TweenInfo.new(time), { Transparency = to }):Play()
		end
	end
end

local function sitDown(seat, model, appear)
	local npc = makeNPC("Посетитель")
	if not npc then return end
	npc.HumanoidRootPart.Anchored = true
	npc:PivotTo(seat.CFrame * CFrame.new(0, npc.Humanoid.HipHeight + 0.2, 0))
	if appear then
		for _, d in ipairs(npc:GetDescendants()) do
			if (d:IsA("BasePart") and d.Name ~= "HumanoidRootPart") or d:IsA("Decal") then d.Transparency = 1 end
		end
	end
	npc.Parent = model
	playAnim(npc, ANIM_SIT)
	if appear then fade(npc, 0, 1.2) end
	seats[seat].npc = npc
end

-- Посетитель садится в кресло у компа и «играет»
local function seatVisitor(pc, model)
	local seat = pc:FindFirstChildWhichIsA("Seat", true)
	if not seat then return end
	seats[seat] = { model = model }
	if math.random() <= 0.8 then sitDown(seat, model) end   -- 80% компов заняты
end

-- Люди приходят и уходят: раз в несколько секунд кто-то встаёт и уходит,
-- а на свободное место садится новый посетитель
task.spawn(function()
	while true do
		task.wait(math.random(4, 9))
		local list = {}
		for seat, info in pairs(seats) do
			if not seat.Parent then seats[seat] = nil else table.insert(list, seat) end
		end
		if #list > 0 then
			local seat = list[math.random(#list)]
			local info = seats[seat]
			if info.npc and info.npc.Parent then
				local npc = info.npc
				info.npc = nil
				fade(npc, 1, 1.2)
				task.delay(1.3, function() npc:Destroy() end)
			else
				sitDown(seat, info.model, true)
			end
		end
	end
end)

-- Ходит по кругу через точки, пока его модель существует
local function walkLoop(npc, points, speed)
	local root = npc.HumanoidRootPart
	root.Anchored = true
	local track = playAnim(npc, ANIM_WALK, 0.9)
	task.spawn(function()
		local i = 1
		while npc.Parent do
			local target = points[i]
			local from = root.Position
			local dist = (target - from).Magnitude
			if dist > 0.5 then
				local tween = TweenService:Create(root, TweenInfo.new(dist / speed, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(target, target + (target - from).Unit) })
				root.CFrame = CFrame.lookAt(from, Vector3.new(target.X, from.Y, target.Z))
				track:AdjustSpeed(0.9)
				tween:Play()
				tween.Completed:Wait()
			end
			track:AdjustSpeed(0)
			task.wait(math.random(10, 30) / 10)
			i = i % #points + 1
		end
	end)
end

local function npcPoint(origin, npc, x, z)
	local root = npc.HumanoidRootPart
	return at(origin, x, npc.Humanoid.HipHeight + root.Size.Y / 2, z).Position
end

-- Кот: гуляет по клубу, его можно погладить (E) — маленький бонус
local function spawnCat(origin, model, plot)
	local cat = Instance.new("Model")
	cat.Name = "Кот"
	local fur = Color3.fromRGB(240, 150, 60)
	local body = makePart({ Size = Vector3.new(1.4, 1.2, 2.6), Color = fur, Material = Enum.Material.Fabric, CanCollide = false, Parent = cat })
	local function add(size, offset, color, shape)
		local p = makePart({ Size = size, Color = color or fur, Material = Enum.Material.Fabric, CanCollide = false, Parent = cat, CFrame = body.CFrame * offset })
		if shape then p.Shape = shape end
		local w = Instance.new("WeldConstraint") w.Part0 = body w.Part1 = p w.Parent = p
		p.Anchored = false
	end
	add(Vector3.new(1.3, 1.2, 1.2), CFrame.new(0, 0.6, -1.6))                                     -- голова
	add(Vector3.new(0.35, 0.5, 0.2), CFrame.new(-0.4, 1.35, -1.6))                                -- уши
	add(Vector3.new(0.35, 0.5, 0.2), CFrame.new(0.4, 1.35, -1.6))
	add(Vector3.new(0.2, 0.2, 0.1), CFrame.new(-0.3, 0.75, -2.22), Color3.fromRGB(40, 200, 90))  -- глаза
	add(Vector3.new(0.2, 0.2, 0.1), CFrame.new(0.3, 0.75, -2.22), Color3.fromRGB(40, 200, 90))
	add(Vector3.new(0.3, 0.3, 1.8), CFrame.new(0, 0.7, 1.9) * CFrame.Angles(math.rad(35), 0, 0))  -- хвост
	for _, c in ipairs({ { -0.5, -0.9 }, { 0.5, -0.9 }, { -0.5, 0.9 }, { 0.5, 0.9 } }) do
		add(Vector3.new(0.35, 0.7, 0.35), CFrame.new(c[1], -0.85, c[2]))                          -- лапы
	end
	body.Anchored = true
	cat.PrimaryPart = body
	cat.Parent = model
	addLabel(body, "🐱", Color3.new(1, 1, 1), 2.2)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = plot.lang == "ru" and "Погладить" or "Pet"
	prompt.ObjectText = plot.lang == "ru" and "Кот" or "Cat"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	local last = {}
	prompt.Triggered:Connect(function(player)
		if last[player] and os.clock() - last[player] < 60 then return end
		last[player] = os.clock()
		local bonus = math.max(10, plot.income * 10)
		player.leaderstats[CONFIG.CURRENCY_NAME].Value += bonus
		player:SetAttribute("ChestBonus", nil)
		player:SetAttribute("CatBonus", bonus)
		local hearts = Instance.new("ParticleEmitter")
		hearts.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		hearts.Color = ColorSequence.new(Color3.fromRGB(255, 90, 150))
		hearts.Rate = 0
		hearts.Speed = NumberRange.new(3, 5)
		hearts.Parent = body
		hearts:Emit(25)
		task.delay(2, function() hearts:Destroy() end)
	end)

	local spots = { { -8, 20 }, { 2, 24 }, { 6, 8 }, { -4, 2 }, { 0, -6 }, { -6, 12 } }
	task.spawn(function()
		local i = 1
		while cat.Parent do
			local t = at(origin, spots[i][1], 1.6, spots[i][2]).Position
			local from = body.Position
			local tw = TweenService:Create(body, TweenInfo.new((t - from).Magnitude / 5, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(t, t + (t - from).Unit) })
			body.CFrame = CFrame.lookAt(from, Vector3.new(t.X, from.Y, t.Z))
			tw:Play()
			tw.Completed:Wait()
			task.wait(math.random(20, 60) / 10)
			i = math.random(#spots)
		end
	end)
end

function builders.pcs(item, origin, model, lang, plot)
	local tier = math.max(plot and plot.pcTier or 1, item.minTier or 1)
	local tierColor = Shared.PC_TIERS[tier].color
	local color = item.color or tierColor
	for _, p in ipairs(item.pcs) do
		local cf = at(origin, p[1], 0, p[2]) * CFrame.Angles(0, math.rad(item.rot or 0), 0)
		local pc = cloneTemplate("pc", CONFIG.PC_SCALE)
		if pc then
			pc:PivotTo(cf)
			for _, part in ipairs(pc:GetDescendants()) do
				if part:IsA("BasePart") and part.Name == "Screen" then
					part.Material = Enum.Material.Glass
					part.Color = color:Lerp(Color3.new(1, 1, 1), 0.3)
				end
			end
			pc.Parent = model
			seatVisitor(pc, model)
			-- экраны «с игрой» (переливы анимирует Rides.client.lua)
			for _, part in ipairs(pc:GetDescendants()) do
				if part:IsA("BasePart") and part.Name == "Screen" then
					local gui = Instance.new("SurfaceGui")
					gui.LightInfluence = 0
					gui.Face = Enum.NormalId.Front
					gui.Parent = part
					local f = Instance.new("Frame")
					f.Size = UDim2.fromScale(1, 1)
					f.BorderSizePixel = 0
					f.BackgroundColor3 = Color3.new(1, 1, 1)
					f.Parent = gui
					local g = Instance.new("UIGradient")
					g.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, color),
						ColorSequenceKeypoint.new(0.5, Color3.fromHSV(math.random(), 0.8, 1)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 40)),
					})
					g.Parent = f
					game:GetService("CollectionService"):AddTag(g, "GameScreen")
					local backGui = gui:Clone()
					backGui.Face = Enum.NormalId.Back
					backGui.Parent = part
					game:GetService("CollectionService"):AddTag(backGui.Frame.UIGradient, "GameScreen")
				end
			end
			-- с уровня 2: светящаяся подсветка под столом цвета уровня
			if tier >= 2 then
				local glow = makePart({
					Size = Vector3.new(6, 0.15, 5.5),
					CFrame = cf * CFrame.new(0, 0.1, 0),
					Color = tierColor,
					Material = Enum.Material.Neon,
					Transparency = 0.35,
					CanCollide = false,
					Parent = model,
				})
				if tier >= 4 then
					local sparkle = Instance.new("ParticleEmitter")
					sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
					sparkle.Color = ColorSequence.new(tierColor)
					sparkle.Rate = 3
					sparkle.Lifetime = NumberRange.new(1, 2)
					sparkle.Speed = NumberRange.new(1, 2)
					sparkle.Size = NumberSequence.new(0.4)
					sparkle.Parent = glow
				end
			end
		else
			simpleDesk(model, cf, color)
		end
	end
end

-- Модель из магазина (ресепшн, автомат...)
-- Человечек-администратор за стойкой
local function spawnAdmin(origin, model, desk)
	local ok, npc = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		desc.Shirt = 0
		desc.HeadColor = Color3.fromRGB(234, 184, 146)
		desc.TorsoColor = Color3.fromRGB(40, 120, 200)
		desc.LeftArmColor = desc.HeadColor
		desc.RightArmColor = desc.HeadColor
		desc.LeftLegColor = Color3.fromRGB(30, 30, 40)
		desc.RightLegColor = Color3.fromRGB(30, 30, 40)
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not npc then return end
	npc.Name = "Админ"
	npc.HumanoidRootPart.Anchored = true
	npc.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	-- стоит за стойкой, лицом к залу
	-- в центре изгиба стойки, ногами на полу, лицом к залу (+X)
	local center = desk and desk:GetBoundingBox().Position or at(origin, -13, 0, 10).Position
	local root = npc.HumanoidRootPart
	local pos = Vector3.new(center.X - 1.5, origin.Y + npc.Humanoid.HipHeight + root.Size.Y / 2, center.Z)
	npc:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(1, 0, 0)))
	npc.Parent = model
	local head = npc:FindFirstChild("Head")
	if head then addLabel(head, "ADMIN", Color3.fromRGB(120, 220, 255), 2) end
end

function builders.model(item, origin, model)
	local cf = at(origin, item.pos[1], 0, item.pos[2]) * CFrame.Angles(0, math.rad(item.rot or 0), 0)
	local m = cloneTemplate(item.model, item.scale)
	if m then
		m:PivotTo(cf)
		m.Parent = model
		if item.id == "admin" then spawnAdmin(origin, model, m) end
	else
		makePart({ Size = Vector3.new(6, 4, 3), CFrame = cf * CFrame.new(0, 2, 0), Color = Color3.fromRGB(60, 120, 200), Parent = model })
	end
end

-- Стены всего клуба + закрытые двери «на будущее» + граффити
function builders.outer(item, origin, model, lang, plot)
	local H = CONFIG.WALL_HEIGHT
	local doors = {
		{ "S", 0, 10 },     -- вход
		{ "N", 8, 4 },      -- тайная дверь
		{ "W", -5, 4 },     -- дверь из VIP SOLO (дальше — второй этаж)
		{ "E", -24, 4 }, { "E", -8, 4 }, { "E", 20, 4 },   -- комнаты справа (потом)
	}
	buildWalls(model, origin, { -60, -35, 60, 35 }, doors, nil, H, WALL_COLOR)

	-- закрытые двери
	local function lockedDoor(x, z, alongX, text, color)
		local size = alongX and Vector3.new(4 * S, 9, 0.6) or Vector3.new(0.6, 9, 4 * S)
		local door = box(model, origin, size, x, 4.5, z, color, Enum.Material.Wood)
		addLabel(door, text, Color3.fromRGB(255, 230, 150), 6)
	end
	-- перегородка между рядом из 4 ПК и стойкой админа
	box(model, origin, Vector3.new(1, H - 2, 34 * S), -19, (H - 2) / 2, 3, INNER_COLOR)
	box(model, origin, Vector3.new(1.3, 0.35, 34 * S), -19, 0.4, 3, NEON_TRIM, Enum.Material.Neon, { CanCollide = false })

	lockedDoor(8, -35, true, T(lang, "secret"), Color3.fromRGB(20, 20, 25))
	lockedDoor(-60, -5, false, T(lang, "soon"), Color3.fromRGB(120, 90, 30))
	for _, z in ipairs({ -24, -8, 20 }) do
		lockedDoor(60, z, false, T(lang, "soon"), Color3.fromRGB(70, 60, 80))
	end

	-- Входная дверь: стеклянная, раздвижная. Открыть/закрыть может только
	-- хозяин клуба — чтобы чужие игроки не забегали. Сначала открыта.
	local isRu = lang == "ru"
	local closedCF = at(origin, 0, H / 2, 35)
	local openCF = closedCF * CFrame.new(10 * S, 0, 0.8)   -- уезжает за стену
	local door = box(model, origin, Vector3.new(10 * S, H, 0.5), 0, H / 2, 35, Color3.fromRGB(120, 200, 255), Enum.Material.Glass,
		{ Name = "ВходнаяДверь", Transparency = 0.45, CFrame = openCF, CanCollide = false })
	local signs = { addSign(door, Enum.NormalId.Back, "", Color3.fromRGB(255, 90, 90)), addSign(door, Enum.NormalId.Front, "", Color3.fromRGB(255, 90, 90)) }
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = isRu and "🚪 Дверь клуба" or "🚪 Club door"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = box(model, origin, Vector3.new(1, 1, 1), 0, 5, 35, Color3.new(), nil, { Transparency = 1, CanCollide = false })
	local closed = false
	local function apply()
		TweenService:Create(door, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { CFrame = closed and closedCF or openCF }):Play()
		door.CanCollide = closed
		for _, l in ipairs(signs) do l.Text = closed and (isRu and "🔒 ЗАКРЫТО" or "🔒 CLOSED") or "" end
		prompt.ActionText = closed and (isRu and "Открыть" or "Open") or (isRu and "Закрыть" or "Close")
	end
	apply()
	prompt.Triggered:Connect(function(player)
		if player ~= plot.owner then
			-- гость внутри закрытого клуба всегда может выйти
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if closed and root and origin:PointToObjectSpace(root.Position).Z < 35 * S then
				player.Character:PivotTo(at(origin, 0, 3, 38))
				return
			end
			player:SetAttribute("Toast", nil)
			player:SetAttribute("Toast", isRu and "🔒 Дверь открывает только хозяин клуба" or "🔒 Only the club owner can use this door")
			return
		end
		closed = not closed
		apply()
	end)
end

-- Граффити на стене (покупается за монеты)
local graffitiDecals
function builders.graffiti(item, origin, model)
	if not graffitiDecals then
		graffitiDecals = {}
		for _, child in ipairs(templates and templates:GetChildren() or {}) do
			if child:IsA("Decal") then table.insert(graffitiDecals, child) end
		end
		table.sort(graffitiDecals, function(a, b) return a.Name < b.Name end)
	end
	if #graffitiDecals == 0 then return end
	local spot = item.pcs[1]
	local panel = makePart({
		Size = Vector3.new(16, 10, 0.2),
		CFrame = at(origin, spot[1], 8.5, spot[2]) * CFrame.Angles(0, math.rad(spot[3]), 0),
		Transparency = 1, CanCollide = false, Parent = model,
	})
	local n = tonumber(item.id:match("_(%d+)$")) or 1
	local decal = graffitiDecals[(n - 1) % #graffitiDecals + 1]:Clone()
	decal.Face = Enum.NormalId.Back
	decal.Parent = panel
end

-- Комната: пол своего цвета + стены с дверью + начинка
function builders.room(item, origin, model, lang, plot)
	if item.id == "hall" then
		task.defer(function()
			local npc = makeNPC("Уборщик", Color3.fromRGB(40, 150, 200), Color3.fromRGB(40, 60, 90))
			if not npc then return end
			local pts = {}
			for _, xz in ipairs({ { 16, 3 }, { 56, 3 }, { 56, 12.5 }, { 16, 12.5 }, { 16, 21.5 }, { 56, 21.5 }, { 56, 31 }, { 16, 31 } }) do
				table.insert(pts, npcPoint(origin, npc, xz[1], xz[2]))
			end
			npc:PivotTo(CFrame.new(pts[1]))
			npc.Parent = model
			-- швабра
			local mop = makePart({ Size = Vector3.new(0.3, 5, 0.3), Color = Color3.fromRGB(150, 110, 70), CanCollide = false, Anchored = false, Parent = npc })
			mop.CFrame = npc.RightHand.CFrame * CFrame.new(0, -1, -0.5) * CFrame.Angles(math.rad(20), 0, 0)
			local w = Instance.new("WeldConstraint") w.Part0 = npc.RightHand w.Part1 = mop w.Parent = mop
			walkLoop(npc, pts, 6)
		end)
	end
	local r = item.rect
	local w, d = (r[3] - r[1]) * S, (r[4] - r[2]) * S
	box(model, origin, Vector3.new(w, 0.2, d), (r[1] + r[3]) / 2, 0.1, (r[2] + r[4]) / 2,
		item.floor or Color3.fromRGB(80, 70, 100), Enum.Material.SmoothPlastic, { CanCollide = false })
	buildWalls(model, origin, r, item.doors, item.skip, CONFIG.WALL_HEIGHT - 2, INNER_COLOR, item.trim)
	if item.extra and builders[item.extra] then
		builders[item.extra](item, origin, model, lang)
	end
end

function builders.toilet(item, origin, model)
	local white = Color3.fromRGB(240, 240, 245)
	box(model, origin, Vector3.new(2.4, 1.6, 3), -28, 0.8, 31, white)            -- унитаз
	box(model, origin, Vector3.new(2.6, 2.2, 0.8), -28, 2.2, 32.8, white)        -- бачок
	box(model, origin, Vector3.new(3, 0.6, 2), -22, 3, 33.5, white)              -- раковина
	box(model, origin, Vector3.new(0.6, 3, 0.6), -22, 1.5, 33.5, white)
	box(model, origin, Vector3.new(3, 3.5, 0.2), -22, 6, 34.3,
		Color3.fromRGB(200, 230, 255), Enum.Material.Glass)                     -- зеркало
	box(model, origin, Vector3.new(0.3, 8, 5), -25, 4, 31, Color3.fromRGB(150, 160, 175)) -- перегородка
end

function builders.servers(item, origin, model, lang)
	-- кабель-каналы под потолком и охлаждение
	box(model, origin, Vector3.new(29 * S, 0.8, 1.2), -45.5, 11, 28, Color3.fromRGB(30, 30, 35), Enum.Material.Metal)
	box(model, origin, Vector3.new(6, 3, 2), -58, 9, 34, Color3.fromRGB(200, 205, 215), Enum.Material.Metal)
	box(model, origin, Vector3.new(4.5, 0.2, 0.1), -58, 9, 34 - 1.1 / S, Color3.fromRGB(80, 200, 255), Enum.Material.Neon)
end

-- Одна серверная стойка: корпус, мигающие огоньки, вентилятор
function builders.rack(item, origin, model)
	local p = item.pcs[1]
	local x, z = p[1], p[2]
	box(model, origin, Vector3.new(4.2, 10, 4), x, 5, z, Color3.fromRGB(22, 22, 28), Enum.Material.Metal)
	box(model, origin, Vector3.new(3.8, 9.4, 0.1), x, 5, z - 2.05 / S, Color3.fromRGB(60, 70, 90), Enum.Material.Glass, { Transparency = 0.4 })
	for j = 0, 7 do
		local led = box(model, origin, Vector3.new(3, 0.22, 0.1), x, 1.2 + j * 1.1, z - 1.95 / S,
			j % 3 == 0 and Color3.fromRGB(255, 180, 40) or (j % 2 == 0 and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(80, 170, 255)), Enum.Material.Neon)
		led:SetAttribute("Blink", true)
	end
	local glow = box(model, origin, Vector3.new(4.2, 0.2, 4), x, 0.1, z, Color3.fromRGB(80, 170, 255), Enum.Material.Neon, { CanCollide = false })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(80, 170, 255)
	light.Range = 10
	light.Parent = glow
end

function builders.stream(item, origin, model)
	local tag = box(model, origin, Vector3.new(1, 1, 1), -50, 13, 11, Color3.new(), nil, { Transparency = 1, CanCollide = false })
	addLabel(tag, "🔴 STREAM ROOM", Color3.fromRGB(255, 70, 80), 0)
	builders.pcs({ pcs = { { -50, 8 } }, rot = 0, color = Color3.fromRGB(180, 80, 255) }, origin, model)
	-- кольцевая лампа
	local ring = box(model, origin, Vector3.new(0.4, 3.2, 3.2), -44.5, 6, 8, Color3.fromRGB(255, 250, 240), Enum.Material.Neon, { Shape = Enum.PartType.Cylinder })
	ring.CFrame = ring.CFrame * CFrame.Angles(0, math.rad(90), 0)
	box(model, origin, Vector3.new(0.3, 5, 0.3), -44.5, 2.5, 8, Color3.fromRGB(30, 30, 30))
	-- вывеска ON AIR
	local sign = box(model, origin, Vector3.new(7, 2, 0.3), -50, 9, 3.6, Color3.fromRGB(40, 10, 10))
	addSign(sign, Enum.NormalId.Back, "● ON AIR", Color3.fromRGB(255, 60, 60))
end

function builders.console(item, origin, model)
	tv(model, origin, -50, 6, -34.3, 180, 12)
	box(model, origin, Vector3.new(8, 1.4, 2), -50, 0.7, -33.2, Color3.fromRGB(30, 30, 35))   -- тумба
	box(model, origin, Vector3.new(2.2, 0.6, 1.6), -50, 1.7, -33.2, Color3.fromRGB(245, 245, 250)) -- приставка
	sofa(model, origin, -50, -22, 0, Color3.fromRGB(40, 60, 120))
end

function builders.vip(item, origin, model)
	local tag = box(model, origin, Vector3.new(1, 1, 1), -50, 13, -5, Color3.new(), nil, { Transparency = 1, CanCollide = false })
	addLabel(tag, "👑 VIP SOLO", Color3.fromRGB(255, 215, 80), 0)
	box(model, origin, Vector3.new(14, 0.1, 12), -50, 0.25, -6, Color3.fromRGB(150, 20, 40), Enum.Material.Fabric)
	builders.pcs({ pcs = { { -50, -9 } }, rot = 0, color = Color3.fromRGB(255, 200, 60) }, origin, model)
	local plate = box(model, origin, Vector3.new(8, 2, 0.3), -50, 9, -13.4, Color3.fromRGB(30, 25, 10))
	addSign(plate, Enum.NormalId.Back, "VIP SOLO", Color3.fromRGB(255, 210, 80))
end

-- Лаунж: диван, столик, телевизор и кресло
function builders.lounge(item, origin, model, lang, plot)
	if plot then spawnCat(origin, model, plot) end
	sofa(model, origin, 0, 14, -90, Color3.fromRGB(70, 50, 110))
	box(model, origin, Vector3.new(4.2, 0.3, 10.4), 0, 0.15, 14, Color3.fromRGB(255, 220, 40), Enum.Material.Neon, { CanCollide = false })
	box(model, origin, Vector3.new(3, 1.6, 7), 5.5, 0.8, 14, Color3.fromRGB(60, 40, 30), Enum.Material.Wood)
	tv(model, origin, 10.5, 5, 14, 90, 10)
	box(model, origin, Vector3.new(1, 3.5, 1), 10.5, 1.75, 14, Color3.fromRGB(30, 30, 35))
	local chair = cloneTemplate("chair")
	if chair then
		chair:PivotTo(at(origin, 5.5, 0, 3) * CFrame.Angles(0, math.rad(180), 0))
		chair.Parent = model
	end
end

-- Диван и стулья возле сцены
function builders.sofaset(item, origin, model)
	sofa(model, origin, -2, -17, 0, Color3.fromRGB(110, 40, 60))
	local chair = cloneTemplate("chair")
	for i = 0, 2 do
		local x = -6 + i * 4
		if chair then
			local c = chair:Clone()
			c:PivotTo(at(origin, x, 0, -12.5))
			c.Parent = model
		end
	end
end

-- Два магазина у перегородки
function builders.shops(item, origin, model, lang, plot)
	for _, z in ipairs({ -9, -2.5 }) do
		local cf = at(origin, -15, 0, z) * CFrame.Angles(0, math.rad(90), 0)
		local m = cloneTemplate("vending")
		if m then
			m:PivotTo(cf)
			m.Parent = model
		else
			makePart({ Size = Vector3.new(4, 8, 3), CFrame = cf * CFrame.new(0, 4, 0), Color = Color3.fromRGB(230, 150, 30), Parent = model })
		end
	end
	-- лимонады: у автоматов и продавца, в клубе цена x3 от уличного киоска
	if plot then
		local spots = {}
		for _, m in ipairs(model:GetChildren()) do
			if m:IsA("Model") then table.insert(spots, m:FindFirstChildWhichIsA("BasePart", true)) end
		end
		for k, kind in ipairs(Shared.LEMONADES) do
			local host = spots[k] or spots[1]
			if host then lemonadePrompt(host, kind, 3, plot) end
		end
	end

	-- продавец стоит рядом с автоматами
	local npc = makeNPC("Продавец", Color3.fromRGB(230, 60, 60), Color3.fromRGB(40, 40, 50))
	if npc then
		npc.HumanoidRootPart.Anchored = true
		local pos = npcPoint(origin, npc, -12, -5.75)
		npc:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(1, 0, 0)))
		npc.Parent = model
		addLabel(npc.Head, "🍕 SHOP", Color3.fromRGB(255, 200, 80), 2)
	end
end

-- Чемпионатная: команды сидят лицом друг к другу, между столами — перегородка,
-- чтобы соперники не видели чужие экраны
function builders.champDivider(item, origin, model, lang)
	box(model, origin, Vector3.new(44 * S, 8, 0.6), 36, 4, -8.5, Color3.fromRGB(25, 25, 35))
	local red = box(model, origin, Vector3.new(10, 3, 0.3), 36, 10, -19.4, Color3.fromRGB(120, 20, 20))
	addSign(red, Enum.NormalId.Back, lang == "ru" and "КРАСНЫЕ" or "RED TEAM", Color3.fromRGB(255, 200, 200))
	local vs = box(model, origin, Vector3.new(4, 3, 0.3), 36, 9.5, -8.5, Color3.fromRGB(25, 25, 35))
	addSign(vs, Enum.NormalId.Back, "5 × 5", Color3.fromRGB(255, 230, 120))
	addSign(vs, Enum.NormalId.Front, "5 × 5", Color3.fromRGB(255, 230, 120))
end

-- Сцена: подиум со ступеньками, занавес, большой портрет владельца, прожекторы
function builders.stage(item, origin, model, lang)
	local x0, z0 = -5, -30
	-- подиум и ступеньки
	box(model, origin, Vector3.new(16 * S, 3, 9 * S), x0, 1.5, z0 - 0.5, Color3.fromRGB(45, 35, 70), Enum.Material.Wood)
	box(model, origin, Vector3.new(8 * S, 1.5, 1.5 * S), x0, 0.75, z0 + 4.8, Color3.fromRGB(60, 50, 90), Enum.Material.Wood)
	box(model, origin, Vector3.new(16 * S, 0.3, 0.3), x0, 3.1, z0 + 4, Color3.fromRGB(255, 200, 80), Enum.Material.Neon)
	-- задник
	local back = box(model, origin, Vector3.new(16 * S, 16, 0.6), x0, 11, -34.3, Color3.fromRGB(30, 25, 45))
	-- занавес по бокам
	for _, dx in ipairs({ -7, 7 }) do
		box(model, origin, Vector3.new(3.5 * S, 16, 1), x0 + dx, 8, -33.6, Color3.fromRGB(150, 20, 40), Enum.Material.Fabric)
	end
	-- большая вывеска «NAZAR CLUB» на заднике
	local _ = back
	box(model, origin, Vector3.new(13 * S, 8.6, 0.3), x0, 10, -33.85, Color3.fromRGB(230, 180, 60), Enum.Material.Metal)
	local sign = box(model, origin, Vector3.new(12.4 * S, 8, 0.3), x0, 10, -33.7, Color3.fromRGB(18, 14, 30))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = sign
	local function line(text, y, h, color)
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, -40, h, 0)
		l.Position = UDim2.new(0, 20, y, 0)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamBlack
		l.TextScaled = true
		l.Text = text
		l.TextColor3 = color
		l.Parent = gui
		local st = Instance.new("UIStroke")
		st.Color = Color3.fromRGB(120, 40, 200)
		st.Thickness = 3
		st.Parent = l
	end
	line("NAZAR", 0.08, 0.46, Color3.fromRGB(255, 215, 90))
	line("CLUB", 0.52, 0.4, Color3.fromRGB(90, 230, 255))
	-- прожекторы разных цветов
	for i, x in ipairs({ -11, -5, 1 }) do
		local lamp = box(model, origin, Vector3.new(1.5, 1.5, 1.5), x, 15, -26, Color3.fromRGB(30, 30, 30), Enum.Material.Metal)
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Bottom
		spot.Angle = 60
		spot.Range = 26
		spot.Brightness = 3
		spot.Color = ({ Color3.fromRGB(255, 120, 200), Color3.fromRGB(255, 230, 180), Color3.fromRGB(120, 200, 255) })[i]
		spot.Parent = lamp
	end
	box(model, origin, Vector3.new(16 * S, 0.8, 0.8), x0, 15.8, -26, Color3.fromRGB(40, 40, 45), Enum.Material.Metal) -- ферма
end

--=========================================================================
-- 6. УЧАСТКИ
--=========================================================================

local plotsFolder = Instance.new("Folder")
plotsFolder.Name = "Участки"
plotsFolder.Parent = workspace

local plots = {}          -- список всех участков
local plotByPlayer = plotByPlayerRef   -- игрок -> участок

local function createPlot(index)
	local origin = CFrame.new(
		(index - 1) * (CONFIG.PLOT_WIDTH + CONFIG.PLOT_GAP),
		CONFIG.PLOT_HEIGHT,
		0
	)

	local model = Instance.new("Model")
	model.Name = "Участок" .. index
	model.Parent = plotsFolder

	-- пол
	local floor = makePart({
		Name = "Пол",
		Size = Vector3.new(CONFIG.PLOT_WIDTH, 2, CONFIG.PLOT_DEPTH),
		CFrame = origin * CFrame.new(0, -1, 0),
		Color = Color3.fromRGB(110, 100, 130),
		Material = Enum.Material.Carpet,
		Parent = model,
	})
	if MaterialService:FindFirstChild(CONFIG.FLOOR_MATERIAL_VARIANT, true) then
		floor.MaterialVariant = CONFIG.FLOOR_MATERIAL_VARIANT
	end
	model.PrimaryPart = floor

	-- контур будущего клуба на полу, чтобы было видно, где строим
	for _, edge in ipairs({
		{ Vector3.new(120 * S, 0.2, 0.6), 0, -35 }, { Vector3.new(120 * S, 0.2, 0.6), 0, 35 },
		{ Vector3.new(0.6, 0.2, 70 * S), -60, 0 },  { Vector3.new(0.6, 0.2, 70 * S), 60, 0 },
	}) do
		box(model, origin, edge[1], edge[2], 0.1, edge[3], Color3.fromRGB(170, 120, 255), nil, { CanCollide = false })
	end

	-- точка появления: снаружи у входа
	local spawnPad = box(model, origin, Vector3.new(10, 1, 8), 0, 0.5, 40, Color3.fromRGB(80, 200, 120))
	spawnPad.Name = "Спавн"

	-- табличка «свободно / клуб такого-то»
	local pole = box(model, origin, Vector3.new(1, 18, 1), -12, 9, 42, Color3.fromRGB(30, 30, 40))
	pole.Name = "Табличка"
	local nameLabel = addLabel(pole, T("en", "freePlot"), Color3.fromRGB(150, 255, 150))

	-- банкомат (на месте кухни): выбрасывает монеты на площадку перед собой
	local machine = box(model, origin, Vector3.new(6, 9, 3), -24, 4.5, -33, Color3.fromRGB(40, 60, 110), Enum.Material.Metal)
	machine.Name = "Банкомат"
	box(model, origin, Vector3.new(4, 2.5, 0.2), -24, 6.2, -33 + 1.6 / S, Color3.fromRGB(120, 220, 255), Enum.Material.Glass)
	box(model, origin, Vector3.new(3.5, 0.6, 0.3), -24, 2.8, -33 + 1.6 / S, Color3.fromRGB(0, 255, 200), Enum.Material.Neon)

	local machineLight = Instance.new("PointLight")
	machineLight.Color = Color3.fromRGB(120, 220, 255)
	machineLight.Range = 16
	machineLight.Parent = machine

	local safeLabel = addLabel(machine, T("en", "machine"), Color3.fromRGB(255, 240, 150))

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = T("en", "action")
	prompt.ObjectText = T("en", "object")
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = machine

	-- площадка, куда падают монеты
	local coinPad = box(model, origin, Vector3.new(16, 0.2, 10), -24, 0.1, -25, Color3.fromRGB(90, 70, 20), Enum.Material.Metal, { CanCollide = false })
	coinPad.Name = "ПлощадкаМонет"

	-- гул людей: звучит из центра клуба, слышно только рядом
	local crowdPart = box(model, origin, Vector3.new(1, 1, 1), 0, 6, 0, Color3.new(), nil,
		{ Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false })
	local crowd = Instance.new("Sound")
	crowd.Name = "ГулЛюдей"
	crowd.SoundId = CONFIG.SOUND_CROWD
	crowd.Looped = true
	crowd.Volume = 0
	crowd.RollOffMode = Enum.RollOffMode.InverseTapered
	crowd.RollOffMinDistance = 60
	crowd.RollOffMaxDistance = 140
	crowd.Parent = crowdPart

	local coinFolder = Instance.new("Folder")
	coinFolder.Name = "Монеты"
	coinFolder.Parent = model

	-- табло геймпасов у входа (как у популярных тайкунов)
	local passCards = {}
	local header = box(model, origin, Vector3.new(37, 3.4, 0.6), 21, 13.2, 45, Color3.fromRGB(25, 20, 40))
	addSign(header, Enum.NormalId.Back, "⭐ GAMEPASSES ⭐", Color3.fromRGB(255, 215, 90))
	box(model, origin, Vector3.new(38, 12, 0.4), 21, 6.5, 44.7, Color3.fromRGB(110, 75, 45), Enum.Material.Wood)
	for _, x in ipairs({ 4, 38 }) do
		box(model, origin, Vector3.new(1, 15, 1), x, 7.5, 45.4, Color3.fromRGB(90, 60, 35), Enum.Material.Wood)
	end
	for i, pass in ipairs(CONFIG.GAMEPASSES) do
		local panel = box(model, origin, Vector3.new(8.4, 10.4, 0.4), 12 + (i - 1) * 6, 6.5, 45, Color3.fromRGB(30, 28, 45))
		panel.Name = "Геймпасс_" .. pass.key

		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back   -- смотрит наружу, к дороге
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = panel

		local function label(y, h, text, size, color, font)
			local l = Instance.new("TextLabel")
			l.Size = UDim2.new(1, -20, 0, h)
			l.Position = UDim2.new(0, 10, 0, y)
			l.BackgroundTransparency = 1
			l.Font = font or Enum.Font.GothamBlack
			l.TextScaled = true
			l.TextColor3 = color
			l.Text = text
			l.Parent = gui
			return l
		end
		local title = label(12, 50, "", 0, Color3.fromRGB(255, 215, 90))
		label(66, 130, pass.icon, 0, Color3.new(1, 1, 1))
		local desc = label(200, 80, "", 0, Color3.fromRGB(230, 230, 240), Enum.Font.GothamMedium)
		local price = Instance.new("TextLabel")
		price.Size = UDim2.new(1, -60, 0, 62)
		price.Position = UDim2.new(0, 30, 1, -84)
		price.Font = Enum.Font.GothamBlack
		price.TextScaled = true
		price.TextColor3 = Color3.new(1, 1, 1)
		price.Parent = gui
		Instance.new("UICorner", price).CornerRadius = UDim.new(0, 14)

		local prompt = Instance.new("ProximityPrompt")
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = panel
		prompt.Triggered:Connect(function(player)
			if pass.id == 0 or hasPass(player, pass.key) then return end
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		end)

		passCards[pass.key] = { title = title, desc = desc, price = price, prompt = prompt }
	end

	-- площадки «доход за N часов» за Robux (наступил — открылась покупка)
	local padLabels = {}
	for k, pack in ipairs(Shared.COIN_PACKS) do
		local pad = box(model, origin, Vector3.new(7, 0.8, 7), -48 + (k - 1) * 7, 0.9, 41, Color3.fromRGB(255, 205, 40), Enum.Material.SmoothPlastic)
		box(model, origin, Vector3.new(0.5, 9.2, 9.2), -48 + (k - 1) * 7, 0.25, 41, Color3.fromRGB(60, 60, 70), Enum.Material.Metal,
			{ Shape = Enum.PartType.Cylinder, CanCollide = false }).CFrame = at(origin, -48 + (k - 1) * 7, 0.3, 41) * CFrame.Angles(0, 0, math.rad(90))
		pad.Shape = Enum.PartType.Cylinder
		pad.Size = Vector3.new(1, 8, 8)
		pad.CFrame = at(origin, -48 + (k - 1) * 7, 0.95, 41) * CFrame.Angles(0, 0, math.rad(90))
		local lbl = addLabel(pad, "", Color3.fromRGB(120, 255, 140), 0)
		lbl.Parent.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
		lbl.Parent.Size = UDim2.new(0, 160, 0, 60)
		padLabels[k] = { label = lbl, pack = pack }
		local cooldown = {}
		pad.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player or pack.id == 0 then return end
			if cooldown[player] and os.clock() - cooldown[player] < 5 then return end
			cooldown[player] = os.clock()
			local base = pad:GetAttribute("BaseCF") or pad.CFrame
			pad:SetAttribute("BaseCF", base)
			TweenService:Create(pad, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { CFrame = base * CFrame.new(-0.45, 0, 0), Color = Color3.fromRGB(255, 255, 140) }):Play()
			task.delay(0.25, function()
				TweenService:Create(pad, TweenInfo.new(0.35, Enum.EasingStyle.Back), { CFrame = base, Color = Color3.fromRGB(255, 205, 40) }):Play()
			end)
			playSound(CONFIG.SOUND_COLLECT, pad, 0.5)
			MarketplaceService:PromptProductPurchase(player, pack.id)
		end)
	end

	-- стрелка над следующей покупкой
	local arrow = makePart({
		Name = "Стрелка",
		Size = Vector3.new(2, 2, 2),
		Color = Color3.fromRGB(255, 230, 60),
		Material = Enum.Material.Neon,
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})
	local arrowMesh = Instance.new("SpecialMesh")
	arrowMesh.MeshType = Enum.MeshType.FileMesh
	arrowMesh.MeshId = "rbxassetid://1033714"     -- конус
	arrowMesh.Scale = Vector3.new(2.2, 3.6, 2.2)
	arrowMesh.VertexColor = Vector3.new(1.5, 1.3, 0.3)
	arrowMesh.Parent = arrow

	local plot = {
		index      = index,
		model      = model,
		origin     = origin,
		spawnPad   = spawnPad,
		machine    = machine,
		prompt     = prompt,
		coinPad    = coinPad,
		coinFolder = coinFolder,
		arrow      = arrow,
		passCards  = passCards,
		padLabels  = padLabels,
		crowd      = crowd,
		lastClick  = 0,
		lang       = "en",
		safeLabel  = safeLabel,
		nameLabel  = nameLabel,
		owner      = nil,
		owned      = {},   -- id -> true
		built      = {},   -- id -> Model
		buttons    = {},   -- id -> Part
		ghosts     = {},   -- id -> Part (закрытые комнаты)
		storage    = 0,
		income     = 0,
		multiplier = 1,
	}

	-- кнопки покупок
	for _, item in ipairs(ITEMS) do
		-- кнопка: серый круглый постамент + красная «шайба» сверху (без неона)
		local button = box(model, origin, Vector3.new(0.9, 6, 6), item.btn[1], 0.75, item.btn[2], Color3.fromRGB(215, 45, 55), Enum.Material.SmoothPlastic,
			{ Shape = Enum.PartType.Cylinder, Reflectance = 0.1 })
		button.CFrame = at(origin, item.btn[1], 0.75, item.btn[2]) * CFrame.Angles(0, 0, math.rad(90))
		local rim = makePart({ Name = "Обод", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 7.4, 7.4),
			CFrame = at(origin, item.btn[1], 0.3, item.btn[2]) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Metal, CanCollide = false, Parent = button })
		local _ = rim
		button:SetAttribute("BaseCF", button.CFrame)
		button.Name = "Кнопка_" .. item.id
		button:SetAttribute("ItemId", item.id)
		addLabel(button, itemName(item, "en") .. "\n" .. priceText(item, "en"))
		button.Transparency = 1
		button.CanCollide = false
		button:FindFirstChildWhichIsA("BillboardGui").Enabled = false
		plot.buttons[item.id] = button

		-- «призрак» закрытой комнаты: видно, что тут что-то будет
		if item.kind == "room" then
			local r = item.rect
			local ghost = box(model, origin, Vector3.new((r[3] - r[1]) * S, 0.15, (r[4] - r[2]) * S),
				(r[1] + r[3]) / 2, 0.08, (r[2] + r[4]) / 2, Color3.fromRGB(20, 15, 30), nil,
				{ Transparency = 1, CanCollide = false })
			addLabel(ghost, "", Color3.fromRGB(200, 190, 230), 3).Parent.Enabled = false
			plot.ghosts[item.id] = ghost
		end
	end

	-- стрелка качается вверх-вниз
	TweenService:Create(arrowMesh, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Offset = Vector3.new(0, 1.5, 0) }):Play()

	plots[index] = plot
	return plot
end

local function isAvailable(plot, item)
	return plot.owner ~= nil
		and not plot.owned[item.id]
		and (item.needs == nil or plot.owned[item.needs] == true)
end

-- Показывать нужно только те кнопки, которые уже доступны по цепочке
local function refreshButtons(plot)
	local next_ = nil
	for _, item in ipairs(ITEMS) do
		local button = plot.buttons[item.id]
		local available = isAvailable(plot, item)
		if available and not next_ then next_ = button end

		button.Transparency = available and 0 or 1
		button.CanCollide = available   -- стоишь на кнопке, а не проваливаешься
		for _, c in ipairs(button:GetChildren()) do
			if c:IsA("BasePart") then c.Transparency = button.Transparency end
		end
		local gui = button:FindFirstChildWhichIsA("BillboardGui")
		gui.Enabled = available
		gui.Text.Text = itemName(item, plot.lang) .. "\n" .. priceText(item, plot.lang)

		local ghost = plot.ghosts[item.id]
		if ghost then
			local show = plot.owner ~= nil and not plot.owned[item.id]
			ghost.Transparency = show and 0.6 or 1
			local g = ghost:FindFirstChildWhichIsA("BillboardGui")
			g.Enabled = show
			g.Text.Text = T(plot.lang, "locked", itemName(item, plot.lang), priceText(item, plot.lang))
		end
	end

	-- следующая цель — для полоски прогресса на экране
	if plot.owner then
		local nextItem
		for _, item in ipairs(ITEMS) do
			if isAvailable(plot, item) then nextItem = item break end
		end
		plot.owner:SetAttribute("NextName", nextItem and itemName(nextItem, plot.lang) or "")
		plot.owner:SetAttribute("NextCost", nextItem and nextItem.cost or 0)
		plot.owner:SetAttribute("NextPos", nextItem and plot.buttons[nextItem.id].Position or nil)
		-- клад в городе: хватает на следующую треть клуба
		local sum, n, started = 0, 0, false
		for _, item in ipairs(ITEMS) do
			if item == nextItem then started = true end
			if started and n < math.ceil(#ITEMS / 6) then sum += item.cost n += 1 end
		end
		plot.owner:SetAttribute("ChestValue", sum)   -- ≈ шестая часть клуба
	end

	if next_ then
		plot.arrow.CFrame = CFrame.new(next_.Position + Vector3.new(0, 7, 0)) * CFrame.Angles(math.rad(180), 0, 0)
		plot.arrow.Transparency = 0
	else
		plot.arrow.Transparency = 1
	end
end

-- Чем больше компьютеров, тем громче гул людей
local function updateCrowd(plot)
	local pcs = 0
	for id in pairs(plot.owned) do
		local item = ITEM_BY_ID[id]
		if item and item.kind == "pcs" then pcs += #item.pcs end
	end
	local crowd = plot.crowd
	if pcs == 0 or CONFIG.SOUND_CROWD == "" then
		crowd:Stop()
		return
	end
	local t = math.clamp(pcs / 35, 0, 1)   -- всего на этаже ~35 ПК
	local target = CONFIG.CROWD_VOLUME_MIN + (CONFIG.CROWD_VOLUME_MAX - CONFIG.CROWD_VOLUME_MIN) * t
	if not crowd.IsPlaying then crowd:Play() end
	TweenService:Create(crowd, TweenInfo.new(2), { Volume = target }):Play()
end


local function recalcIncome(plot)
	local total = 0
	local tierMult = Shared.PC_TIERS[plot.pcTier or 1].mult
	for id in pairs(plot.owned) do
		local item = ITEM_BY_ID[id]
		if item then
			total += item.kind == "pcs" and item.income * tierMult or item.income
		end
	end
	local boost = 1 + (plot.owned.server and 0.1 or 0)
	for id in pairs(plot.owned) do
		local it = ITEM_BY_ID[id]
		if it and it.kind == "rack" then boost += 0.1 end
	end
	local rebirthBoost = 1 + 0.5 * (plot.rebirths or 0)   -- ребёрт: x1.5, x2, x2.5...
	if plot.owner then
		boost += (plot.owner:GetAttribute("FriendBoost") or 0) + (plot.owner:GetAttribute("PremiumBoost") or 0)
	end
	plot.income = math.floor(total * boost * plot.multiplier * rebirthBoost)

	if plot.owner then
		local stats = plot.owner:FindFirstChild("Stats")
		if stats then stats.Income.Value = plot.income end
	end
	updateCrowd(plot)
end

local function buildItem(plot, item, animate)
	if plot.built[item.id] then return end

	local model = Instance.new("Model")
	model.Name = item.id
	local builder = builders[item.kind]
	if builder then
		builder(item, plot.origin, model, plot.lang, plot)
	end
	model.Parent = plot.model
	plot.built[item.id] = model

	if animate then
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
	plot.coinFolder:ClearAllChildren()
	plot.crowd:Stop()
	plot.crowd.Volume = 0
	local stats = plot.owner and plot.owner:FindFirstChild("Stats")
	if stats then stats.Storage.Value = 0 end
end

--=========================================================================
-- 7. ПОКУПКИ
--=========================================================================

local fireworks
-- Салют над сценой NAZAR CLUB
function fireworks(plot)
	local colors = { Color3.fromRGB(255, 60, 120), Color3.fromRGB(255, 220, 60), Color3.fromRGB(80, 220, 255), Color3.fromRGB(140, 255, 100), Color3.fromRGB(200, 100, 255) }
	for i = 1, 14 do
		local start = (plot.origin * CFrame.new((-5 + math.random(-12, 12)) * S, 2, -28 * S)).Position
		local rocket = makePart({ Size = Vector3.new(0.6, 1.6, 0.6), Position = start, Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, CanCollide = false, Parent = plot.model })
		local peak = start + Vector3.new(math.random(-6, 6), math.random(45, 70), math.random(-6, 6))
		local fly = TweenService:Create(rocket, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = peak })
		fly:Play()
		fly.Completed:Connect(function()
			rocket.Transparency = 1
			local c = colors[math.random(#colors)]
			local burst = Instance.new("ParticleEmitter")
			burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			burst.Color = ColorSequence.new(c)
			burst.LightEmission = 1
			burst.Size = NumberSequence.new(1.6, 0)
			burst.Lifetime = NumberRange.new(1.2, 1.8)
			burst.Speed = NumberRange.new(25, 35)
			burst.SpreadAngle = Vector2.new(180, 180)
			burst.Acceleration = Vector3.new(0, -15, 0)
			burst.Drag = 1.5
			burst.Rate = 0
			burst.Parent = rocket
			burst:Emit(120)
			local light = Instance.new("PointLight")
			light.Color = c
			light.Range = 60
			light.Brightness = 4
			light.Parent = rocket
			task.delay(0.4, function() light:Destroy() end)
			task.delay(2.5, function() rocket:Destroy() end)
		end)
		task.wait(math.random(15, 40) / 100)
	end
end

local buyCooldown = {}   -- игрок -> время последней попытки

local function tryBuy(player, plot, item)
	if plot.owner ~= player then return end
	if not isAvailable(plot, item) then return end

	local now = os.clock()
	if buyCooldown[player] and now - buyCooldown[player] < 0.35 then return end
	buyCooldown[player] = now

	local money = player.leaderstats[CONFIG.CURRENCY_NAME]
	if money.Value < item.cost then
		return
	end

	money.Value -= item.cost
	plot.owned[item.id] = true

	-- анимация нажатия: кнопка проседает, вспышка искр и звон монет
	local button = plot.buttons[item.id]
	local base = button:GetAttribute("BaseCF")
	local fx = makePart({ Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, Position = button.Position + Vector3.new(0, 1, 0), Parent = plot.model })
	local burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Color = ColorSequence.new(Color3.fromRGB(255, 215, 80))
	burst.LightEmission = 1
	burst.Rate = 0
	burst.Speed = NumberRange.new(10, 18)
	burst.SpreadAngle = Vector2.new(70, 70)
	burst.Lifetime = NumberRange.new(0.5, 0.9)
	burst.Acceleration = Vector3.new(0, -30, 0)
	burst.Parent = fx
	burst:Emit(40)
	playSound(CONFIG.SOUND_COLLECT, fx, 0.6)
	task.delay(2, function() fx:Destroy() end)
	-- вдавливается на полкнопки, зеленеет, потом плавно пружинит обратно
	TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { CFrame = base * CFrame.new(-0.35, 0, 0), Color = Color3.fromRGB(80, 220, 100) }):Play()
	task.delay(0.25, function()
		TweenService:Create(button, TweenInfo.new(0.3, Enum.EasingStyle.Back), { CFrame = base }):Play()
	end)
	task.delay(0.6, function()
		button.Color = Color3.fromRGB(215, 45, 55)
		refreshButtons(plot)
	end)

	buildItem(plot, item, true)
	recalcIncome(plot)

	if item.id == "stage" then task.spawn(fireworks, plot) end

	-- последняя покупка этажа: клиент покажет праздничный экран
	if item.id == ITEMS[#ITEMS].id then
		player:SetAttribute("Floor1Done", true)
	end
end

--=========================================================================
-- 7б. МОНЕТЫ НА ПЛОЩАДКЕ
--=========================================================================

local function updateStorage(plot)
	local total = 0
	for _, coin in ipairs(plot.coinFolder:GetChildren()) do
		total += coin:GetAttribute("Value") or 0
	end
	plot.storage = total
	if plot.owner then
		local stats = plot.owner:FindFirstChild("Stats")
		if stats then stats.Storage.Value = total end
	end
end

local function pickUpCoin(plot, coin, player)
	if coin:GetAttribute("Taken") then return end
	coin:SetAttribute("Taken", true)

	local value = coin:GetAttribute("Value") or 0
	player.leaderstats[CONFIG.CURRENCY_NAME].Value += value
	playSound(CONFIG.SOUND_COLLECT, plot.coinPad, 0.28)

	-- монетка подпрыгивает и исчезает
	local tween = TweenService:Create(coin, TweenInfo.new(0.25), {
		CFrame = coin.CFrame + Vector3.new(0, 3, 0),
		Transparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function() coin:Destroy() end)
	task.defer(updateStorage, plot)
end

local function dropCoin(plot, value)
	value = math.max(1, math.floor(value))

	-- геймпасс «Авто-сбор»: монеты сразу в кошелёк, бегать не надо
	if plot.owner and plot.owner:GetAttribute("Pass_autocollect") == true then
		plot.owner.leaderstats[CONFIG.CURRENCY_NAME].Value += value
		return
	end

	-- площадка переполнена: добавляем стоимость к случайной монете
	local existing = plot.coinFolder:GetChildren()
	if #existing >= CONFIG.MAX_COINS then
		local coin = existing[math.random(1, #existing)]
		coin:SetAttribute("Value", (coin:GetAttribute("Value") or 0) + value)
		updateStorage(plot)
		return
	end

	local pad = plot.coinPad
	local target = pad.CFrame * CFrame.new(
		(math.random() - 0.5) * (pad.Size.X - 2),
		0.6,
		(math.random() - 0.5) * (pad.Size.Z - 2)
	) * CFrame.Angles(0, 0, math.rad(90))   -- монетка лежит плашмя

	local coin = makePart({
		Name = "Монета",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 1.6, 1.6),
		-- вылетает из щели банкомата в сторону площадки (+Z)
		CFrame = plot.machine.CFrame * CFrame.new(0, -1.7, 2) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 200, 40),
		Material = Enum.Material.Metal,
		Reflectance = 0.2,
		CanCollide = false,
		Parent = plot.coinFolder,
	})
	coin:SetAttribute("Value", value)
	-- гравировка «$» с обеих сторон и золотой ободок
	for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 60
		g.Parent = coin
		local ring = Instance.new("Frame")
		ring.Size = UDim2.fromScale(0.82, 0.82)
		ring.Position = UDim2.fromScale(0.09, 0.09)
		ring.BackgroundTransparency = 1
		ring.Parent = g
		Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
		local st = Instance.new("UIStroke") st.Color = Color3.fromRGB(190, 130, 20) st.Thickness = 4 st.Parent = ring
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.Text = "$"
		t.TextColor3 = Color3.fromRGB(200, 140, 20)
		t.Parent = ring
	end

	TweenService:Create(coin, TweenInfo.new(0.5, Enum.EasingStyle.Bounce), { CFrame = target }):Play()

	coin.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and player == plot.owner then
			pickUpCoin(plot, coin, player)
		end
	end)

	updateStorage(plot)
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

	-- нажатие E у банкомата: бонусная монетка
	plot.prompt.Triggered:Connect(function(player)
		if player ~= plot.owner then return end
		local now = os.clock()
		if now - plot.lastClick < CONFIG.CLICK_COOLDOWN then return end
		plot.lastClick = now

		dropCoin(plot, math.max(1, plot.income * CONFIG.CLICK_BONUS))

		-- банкомат «вздрагивает»
		local base = plot.machine.CFrame
		plot.machine.CFrame = base * CFrame.new(0, 0.3, 0)
		task.delay(0.08, function() plot.machine.CFrame = base end)
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

-- Есть ли у игрока геймпасс (ответ запоминаем в атрибуте Pass_<key>)
local function checkPasses(player)
	for _, pass in ipairs(CONFIG.GAMEPASSES) do
		local owns = false
		local ignore = CONFIG.STUDIO_IGNORE_PASSES and game:GetService("RunService"):IsStudio()
		if pass.id ~= 0 and not ignore then
			local ok, res = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			owns = ok and res
		end
		player:SetAttribute("Pass_" .. pass.key, owns)
	end
end

local function hasPass(player, key)
	return player and player:GetAttribute("Pass_" .. key) == true
end

local function applySpeed(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local speed = hasPass(player, "speed") and 34 or 20
		local e = player:GetAttribute("Energy") or 100
		speed *= e > 50 and 1 or (e > 20 and 0.8 or (e > 0 and 0.6 or 0.45))
		humanoid.WalkSpeed = speed
	end
end
applySpeedRef = applySpeed

-- Надписи на табло: язык владельца участка, «куплено» или цена
local function refreshPassBoard(plot)
	local lang = plot.lang
	for _, pass in ipairs(CONFIG.GAMEPASSES) do
		local card = plot.passCards[pass.key]
		local texts = pass[lang] or pass.en
		card.title.Text = texts[1]
		card.desc.Text = texts[2]
		if hasPass(plot.owner, pass.key) then
			card.price.Text = lang == "ru" and "✓ КУПЛЕНО" or "✓ OWNED"
			card.price.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
		elseif pass.id == 0 then
			card.price.Text = lang == "ru" and "СКОРО" or "SOON"
			card.price.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
		else
			card.price.Text = "R$ " .. pass.price
			card.price.BackgroundColor3 = Color3.fromRGB(40, 190, 90)
		end
		card.prompt.ActionText = lang == "ru" and "Купить" or "Buy"
		card.prompt.ObjectText = texts[1]
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then return end
	for _, pass in ipairs(CONFIG.GAMEPASSES) do
		if pass.id == passId then
			player:SetAttribute("Pass_" .. pass.key, true)
		end
	end
	local plot = plotByPlayer[player]
	if plot then
		plot.multiplier = hasPass(player, "doublecash") and 2 or 1
		recalcIncome(plot)
		refreshPassBoard(plot)
	end
	applySpeed(player)
end)

local function onPlayerAdded(player)
	-- статистика в таблице игроков
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local money = Instance.new("IntValue")
	money.Name = CONFIG.CURRENCY_NAME
	money.Parent = leaderstats

	local rebirthsValue = Instance.new("IntValue")
	rebirthsValue.Name = "Rebirths"
	rebirthsValue.Parent = leaderstats

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
	if data.loadFailed then noSave[player.UserId] = true end
	money.Value = data.money
	rebirthsValue.Value = data.rebirths
	player:SetAttribute("Energy", 100)
	player:SetAttribute("FreeLemonade", 1)   -- один бесплатный лимонад на старте
	player:SetAttribute("PlayTime", data.playTime or 0)
	player:SetAttribute("TotalEarned", data.totalEarned or 0)
	local lastMoney = money.Value
	money:GetPropertyChangedSignal("Value"):Connect(function()
		local diff = money.Value - lastMoney
		lastMoney = money.Value
		if diff > 0 then player:SetAttribute("TotalEarned", (player:GetAttribute("TotalEarned") or 0) + diff) end
	end)

	local plot = findFreePlot()
	if not plot then
		warn("[КлубТайкун] Свободных участков нет для", player.Name)
		return
	end

	plot.owner = player
	plot.owned = {}
	checkPasses(player)
	plot.multiplier = hasPass(player, "doublecash") and 2 or 1
	plot.rebirths = data.rebirths
	plot.pcTier = math.clamp(data.pcTier, 1, #Shared.PC_TIERS)
	plot.dailyLast = data.dailyLast
	plot.dailyStreak = data.dailyStreak
	plotByPlayer[player] = plot
	plot.lang = langOf(player)
	plot.nameLabel.Text = T(plot.lang, "club", player.DisplayName)
	plot.safeLabel.Text = T(plot.lang, "machine")
	plot.prompt.ActionText = T(plot.lang, "action")
	plot.prompt.ObjectText = T(plot.lang, "object")
	plot.nameLabel.TextColor3 = Color3.fromRGB(0, 255, 200)
	refreshPassBoard(plot)

	-- восстанавливаем всё, что было куплено раньше
	for _, item in ipairs(ITEMS) do
		if data.owned[item.id] then
			plot.owned[item.id] = true
			buildItem(plot, item, false)
		end
	end

	recalcIncome(plot)
	refreshButtons(plot)
	player:SetAttribute("Floor1Done", plot.owned[ITEMS[#ITEMS].id] == true)

	local function placeCharacter(character)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root then
			task.wait(0.1)
			root.CFrame = plot.spawnPad.CFrame * CFrame.new(0, 4, 0) * CFrame.Angles(0, math.rad(0), 0)
		end
		applySpeed(player)
	end
	-- Только в Studio: сброс прогресса для тестов.
	-- В командной строке Studio: game.Players.ИМЯ:SetAttribute("DevReset", true)
	if game:GetService("RunService"):IsStudio() then
		player:GetAttributeChangedSignal("DevReset"):Connect(function()
			if not player:GetAttribute("DevReset") then return end
			player:SetAttribute("DevReset", false)
			clearPlot(plot)
			player:SetAttribute("Floor1Done", false)
			money.Value = CONFIG.START_MONEY
			plot.rebirths = 0
			rebirthsValue.Value = 0
			plot.pcTier = 1
			plot.dailyLast = 0
			plot.dailyStreak = 0
			recalcIncome(plot)
			refreshButtons(plot)
		end)
	end

	player.CharacterAdded:Connect(placeCharacter)
	if player.Character then task.spawn(placeCharacter, player.Character) end
end

local function collectData(player)
	local plot = plotByPlayer[player]
	local money = player:FindFirstChild("leaderstats")
		and player.leaderstats:FindFirstChild(CONFIG.CURRENCY_NAME)

	local rebirths = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Rebirths")
	return {
		money = money and money.Value or CONFIG.START_MONEY,
		owned = plot and plot.owned or {},
		rebirths = rebirths and rebirths.Value or 0,
		pcTier = plot and plot.pcTier or 1,
		playTime = player:GetAttribute("PlayTime") or 0,
		totalEarned = player:GetAttribute("TotalEarned") or 0,
		dailyLast = plot and plot.dailyLast or 0,
		dailyStreak = plot and plot.dailyStreak or 0,
	}
end

-- Ребёрт: игрок «продаёт» готовый клуб и начинает заново с бонусом к доходу
local rebirthEvent = Instance.new("RemoteEvent")
rebirthEvent.Name = "ClubRebirth"
rebirthEvent.Parent = game:GetService("ReplicatedStorage")

rebirthEvent.OnServerEvent:Connect(function(player)
	local plot = plotByPlayer[player]
	if not plot or plot.owner ~= player then return end
	if not plot.owned[ITEMS[#ITEMS].id] then return end   -- только после всего этажа

	local keepMultiplier = plot.multiplier
	clearPlot(plot)
	plot.multiplier = keepMultiplier
	plot.rebirths = (plot.rebirths or 0) + 1

	player.leaderstats.Rebirths.Value = plot.rebirths
	player.leaderstats[CONFIG.CURRENCY_NAME].Value = CONFIG.START_MONEY
	player:SetAttribute("Floor1Done", false)
	recalcIncome(plot)
	refreshButtons(plot)
	saveData(player.UserId, collectData(player))

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then root.CFrame = plot.spawnPad.CFrame * CFrame.new(0, 4, 0) end
end)

--=========================================================================
-- МЕНЮ: улучшение компов, ежедневные награды, покупка монет за Robux
--=========================================================================

local function dailyAmount(plot, day)
	local minutes = Shared.DAILY[day].minutes
	return math.max(100, math.floor(plot.income * 60 * minutes))
end

local function menuState(plot)
	local now = os.time()
	local since = now - (plot.dailyLast or 0)
	local streak = plot.dailyStreak or 0
	if since > Shared.DAILY_RESET then streak = 0 end
	local day = streak % #Shared.DAILY + 1
	return {
		pcTier = plot.pcTier or 1,
		income = plot.income,
		dailyDay = day,
		dailyReadyIn = math.max(0, Shared.DAILY_COOLDOWN - since),
		dailyAmount = dailyAmount(plot, day),
	}
end

local clubAction = Instance.new("RemoteFunction")
clubAction.Name = "ClubAction"
clubAction.Parent = game:GetService("ReplicatedStorage")

clubAction.OnServerInvoke = function(player, action)
	local plot = plotByPlayer[player]
	if not plot or plot.owner ~= player then return nil end
	local money = player.leaderstats[CONFIG.CURRENCY_NAME]

	if action == "upgrade" then
		local nextTier = (plot.pcTier or 1) + 1
		local tier = Shared.PC_TIERS[nextTier]
		if tier and money.Value >= tier.cost then
			money.Value -= tier.cost
			plot.pcTier = nextTier
			-- перестраиваем все купленные компы в новом виде
			for _, item in ipairs(ITEMS) do
				if item.kind == "pcs" and plot.built[item.id] then
					plot.built[item.id]:Destroy()
					plot.built[item.id] = nil
					buildItem(plot, item, true)
				end
			end
			recalcIncome(plot)
			playSound(CONFIG.SOUND_BUY, plot.machine, 0.6)
		end
	elseif action == "drinkFree" then
		local left = player:GetAttribute("FreeLemonade") or 0
		if left > 0 and (player:GetAttribute("Energy") or 100) < 100 then
			player:SetAttribute("FreeLemonade", left - 1)
			player:SetAttribute("Energy", 100)
			applySpeedRef(player)
		end
	elseif action == "claimDaily" then
		local st = menuState(plot)
		if st.dailyReadyIn == 0 then
			money.Value += st.dailyAmount
			plot.dailyStreak = (os.time() - (plot.dailyLast or 0) > Shared.DAILY_RESET) and 1 or (plot.dailyStreak or 0) + 1
			plot.dailyLast = os.time()
		end
	end
	return menuState(plot)
end

-- МИНИ-ИГРЫ: «Лови кружки» и «Быстрый счёт». Раз в 5 минут каждая.
-- Сервер сам проверяет время и потолок очков, чтобы нельзя было накрутить.
local MINIGAMES = {
	-- Хорошая игра (≈25 кружков / ≈10 примеров) даёт примерно 3/4 цены
	-- следующей покупки или минуту дохода — что больше. Раз в 5 минут
	-- это заметная помощь, но не ломает прогресс.
	click = { maxScore = 45, good = 25, time = 15 },
	math  = { maxScore = 25, good = 10, time = 30 },
	-- игровой зал ARCADE (Arcade.client.lua). rate — сколько очков
	-- максимум можно набрать за секунду (для игр без фиксированной длины)
	shoot   = { maxScore = 40, good = 18, time = 30 },
	timing  = { maxScore = 10, good = 7,  time = 5, rate = 0.8 },
	stacker = { maxScore = 30, good = 12, time = 4, rate = 1.5 },
	hockey  = { maxScore = 10, good = 5,  time = 60 },
}
local MINIGAME_COOLDOWN = 300
local MINIGAME_TIME = 60
local miniStart = {}

local miniGame = Instance.new("RemoteFunction")
miniGame.Name = "MiniGame"
miniGame.Parent = game:GetService("ReplicatedStorage")
miniGame.OnServerInvoke = function(player, action, name, score)
	local cfg = MINIGAMES[name]
	local plot = plotByPlayer[player]
	if not cfg or not plot then return nil end
	local key = "MG_" .. name
	if action == "start" then
		if (player:GetAttribute(key) or 0) > os.time() then return false end
		miniStart[player] = miniStart[player] or {}
		miniStart[player][name] = os.clock()
		return true
	elseif action == "finish" then
		local started = miniStart[player] and miniStart[player][name]
		if not started then return nil end
		miniStart[player][name] = nil
		if os.clock() - started < cfg.time - 3 then return nil end   -- слишком рано — не засчитываем
		score = math.clamp(math.floor(tonumber(score) or 0), 0, cfg.maxScore)
		if cfg.rate then score = math.min(score, math.floor((os.clock() - started) * cfg.rate)) end
		local pool = math.max(plot.income * 60, (player:GetAttribute("NextCost") or 0) * 0.75, 50)
		local reward = math.floor(pool * score / cfg.good)
		player.leaderstats[CONFIG.CURRENCY_NAME].Value += reward
		player:SetAttribute(key, os.time() + MINIGAME_COOLDOWN)
		return reward
	end
end
Players.PlayerRemoving:Connect(function(p) miniStart[p] = nil end)

-- Покупка пачек монет за Robux (Developer Products)
MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local plot = player and plotByPlayer[player]
	if not plot then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	for _, pack in ipairs(Shared.COIN_PACKS) do
		if pack.id ~= 0 and pack.id == receipt.ProductId then
			local amount = math.max(1000, math.floor(plot.income * 60 * pack.minutes))
			player.leaderstats[CONFIG.CURRENCY_NAME].Value += amount
			saveData(player.UserId, collectData(player))
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function onPlayerRemoving(player)
	saveData(player.UserId, collectData(player))

	local plot = plotByPlayer[player]
	if plot then
		clearPlot(plot)
		plot.owner = nil
		plot.nameLabel.Text = T("en", "freePlot")
		plot.nameLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
		refreshButtons(plot)
		plotByPlayer[player] = nil
	end
	buyCooldown[player] = nil
end

--=========================================================================
-- 9. ЗАПУСК
--=========================================================================

-- Атмосфера клуба: мягкий вечерний свет, лёгкая дымка
local function setupAtmosphere()
	-- ночь: неон и огни города видно лучше всего
	Lighting.ClockTime = 0
	Lighting.Brightness = 1.5
	Lighting.ExposureCompensation = 0.3
	Lighting.Ambient = Color3.fromRGB(95, 85, 135)
	Lighting.OutdoorAmbient = Color3.fromRGB(110, 100, 160)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5

	local function ensure(className, name)
		local obj = Lighting:FindFirstChild(name) or Instance.new(className)
		obj.Name = name
		obj.Parent = Lighting
		return obj
	end

	local bloom = ensure("BloomEffect", "КлубBloom")
	bloom.Intensity = 0.6
	bloom.Size = 18
	bloom.Threshold = 1.1

	local cc = ensure("ColorCorrectionEffect", "КлубЦвет")
	cc.Saturation = 0.2
	cc.Contrast = 0.1
	cc.TintColor = Color3.fromRGB(240, 230, 255)

	local atmo = ensure("Atmosphere", "КлубДымка")
	atmo.Density = 0.1
	atmo.Color = Color3.fromRGB(120, 90, 180)
	atmo.Decay = Color3.fromRGB(60, 30, 110)
	atmo.Glare = 0.2
	atmo.Haze = 1.5
end
setupAtmosphere()

for index = 1, CONFIG.MAX_PLOTS do
	local plot = createPlot(index)
	connectPlotTouches(plot)
	refreshPassBoard(plot)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- игроки, которые успели зайти до загрузки скрипта
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- Бонусы: +10% за каждого друга на сервере (до +50%), +10% за Roblox Premium
local function refreshBoosts()
	for _, player in ipairs(Players:GetPlayers()) do
		local friends = 0
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player then
				local ok, yes = pcall(function() return player:IsFriendsWith(other.UserId) end)
				if ok and yes then friends += 1 end
			end
		end
		player:SetAttribute("FriendBoost", math.min(0.5, friends * 0.1))
		player:SetAttribute("PremiumBoost", player.MembershipType == Enum.MembershipType.Premium and 0.1 or 0)
		local plot = plotByPlayer[player]
		if plot then recalcIncome(plot) end
	end
end
Players.PlayerAdded:Connect(function() task.wait(3) refreshBoosts() end)
Players.PlayerRemoving:Connect(function() task.defer(refreshBoosts) end)
task.delay(3, refreshBoosts)

-- энергия падает: 100 -> 0 за 10 минут; время в игре растёт
task.spawn(function()
	while true do
		task.wait(6)
		for _, player in ipairs(Players:GetPlayers()) do
			local before = player:GetAttribute("Energy")
			if before then
				local e = math.max(0, before - 1)   -- 1% каждые 6 сек = 100% за 10 минут
				player:SetAttribute("Energy", e)
				if (before > 50) ~= (e > 50) or (before > 20) ~= (e > 20) or (before > 0) ~= (e > 0) then
					applySpeed(player)
				end
			end
			player:SetAttribute("PlayTime", (player:GetAttribute("PlayTime") or 0) + 6)
		end
	end
end)

-- надписи на площадках за Robux: сколько монет получишь
task.spawn(function()
	while true do
		for _, plot in ipairs(plots) do
			for _, p in ipairs(plot.padLabels) do
				local amount = math.max(1000, math.floor(plot.income * 60 * p.pack.minutes))
				local period = p.pack.minutes >= 60 and (p.pack.minutes // 60 .. (plot.lang == "ru" and " ч" or "h")) or (p.pack.minutes .. (plot.lang == "ru" and " мин" or " min"))
				p.label.Text = "+" .. short(amount) .. "\n" .. period .. " · R$" .. p.pack.price
			end
		end
		task.wait(5)
	end
end)

-- раз в секунду банкомат сам выбрасывает монету размером с доход
task.spawn(function()
	while true do
		task.wait(1)
		for _, plot in ipairs(plots) do
			if plot.owner and plot.income > 0 then
				dropCoin(plot, plot.income)
				plot.safeLabel.Text = T(plot.lang, "machineOn", short(plot.income))
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

-- фоновая музыка: треки играют по кругу
if #CONFIG.MUSIC_IDS > 0 then
	task.spawn(function()
		local music = Instance.new("Sound")
		music.Name = "Музыка"
		music.Volume = CONFIG.MUSIC_VOLUME
		music.Looped = false
		music.Parent = SoundService

		local index = 0
		while true do
			index = index % #CONFIG.MUSIC_IDS + 1
			music:Stop()
			music.SoundId = CONFIG.MUSIC_IDS[index]
			-- ждём загрузку (не больше 10 сек), иначе пропускаем трек
			local t0 = os.clock()
			while not music.IsLoaded and os.clock() - t0 < 10 do task.wait(0.2) end
			if music.IsLoaded and music.TimeLength > 0 then
				music.TimePosition = 0
				music:Play()
				-- ждём конца трека по длине, а не по событию Ended
				local length = music.TimeLength
				local start = os.clock()
				while os.clock() - start < length + 0.5 do
					task.wait(0.5)
					if not music.IsPlaying and os.clock() - start > 2 then break end
				end
			else
				warn("[Музыка] трек не загрузился:", CONFIG.MUSIC_IDS[index])
			end
		end
	end)
end

print("[КлубТайкун] Сервер запущен. Участков:", CONFIG.MAX_PLOTS)
