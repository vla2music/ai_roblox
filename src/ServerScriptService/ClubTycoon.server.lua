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
	MUSIC_IDS      = {
		"rbxassetid://110520973603761",  -- Drillbeat
		"rbxassetid://139164113687966",  -- PEACE OF MIND
		"rbxassetid://120540010768924",  -- The Calm After Sunset
	},
	MUSIC_VOLUME   = 0.3,
	SOUND_BUY      = "rbxassetid://131737037329240",  -- звук покупки
	SOUND_COLLECT  = "rbxassetid://7147797532",       -- звук сбора монетки (удар snare)
	-- Гул людей в клубе: включается с первым ПК и растёт с каждым новым.
	SOUND_CROWD    = "rbxassetid://9112787259",       -- Glendale Galleria Mall 1 (SFX)
	CROWD_VOLUME_MIN = 0.12,
	CROWD_VOLUME_MAX = 0.45,

	-- Ковролин для пола (создан в Studio, лежит в MaterialService)
	FLOOR_MATERIAL_VARIANT = "ClubCarpet",

	-- Фото владельца на сцене. Когда загрузим картинку — впиши её ID сюда.
	POSTER_IMAGE   = "",
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
	CLICK_COOLDOWN = 0.25,   -- как часто можно жать E (секунды)
	CLICK_BONUS    = 0.3,    -- бонус за нажатие = доход в секунду * это число
	MAX_COINS      = 40,     -- больше монет на площадке не лежит, они «слипаются»

	SERVER_BOOST   = 1.5,    -- серверная умножает весь доход

	-- ID геймпасса «x2 монеты». Пока 0 — геймпасс выключен.
	DOUBLE_CASH_GAMEPASS = 0,
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
	{ id="shop",   name="Магазин",     en="Snack Shop",  cost=400,  income=6, needs="walls",
	  kind="model", model="vending", pos={-15, -6}, rot=90, btn={-9, -4} },

	{ id="hall",  name="Общий зал", en="Main Hall", cost=600, income=4, needs="shop",
	  kind="room", rect={13, 0.5, 50, 33}, doors={{"W", 31, 4}}, floor=Color3.fromRGB(70, 60, 95), btn={8, 31} },
	{ id="hall1", name="Ряд компов 1", en="PC Row 1", cost=900,  income=12, needs="hall",  kind="pcs",
	  pcs={{17,8},{24,8},{31,8},{38,8},{45,8}},    rot=0, btn={31, 3} },
	{ id="hall2", name="Ряд компов 2", en="PC Row 2", cost=1600, income=18, needs="hall1", kind="pcs",
	  pcs={{17,17},{24,17},{31,17},{38,17},{45,17}}, rot=0, btn={31, 12.5} },
	{ id="hall3", name="Ряд компов 3", en="PC Row 3", cost=2800, income=26, needs="hall2", kind="pcs",
	  pcs={{17,26},{24,26},{31,26},{38,26},{45,26}}, rot=0, btn={31, 21.5} },

	{ id="toilet", name="Туалет", en="Restroom", cost=3500, income=26, needs="hall3",
	  kind="room", rect={-31, 20, -19, 35}, doors={{"E", 25, 4}}, skip={S=true}, extra="toilet",
	  floor=Color3.fromRGB(200, 205, 215), btn={-15, 25} },
	{ id="lounge", name="Лаунж с телевизором", en="TV Lounge", cost=5000, income=15, needs="toilet",
	  kind="lounge", btn={4, 30} },
	{ id="sofaset", name="Диван и стулья", en="Sofa & Chairs", cost=7000, income=20, needs="lounge",
	  kind="sofaset", btn={-2, -9} },
	{ id="toprow", name="Ряд из 6 компов", en="6 PC Row", cost=10000, income=30, needs="sofaset", kind="pcs",
	  pcs={{19,-31},{25,-31},{31,-31},{37,-31},{43,-31},{49,-31}}, rot=0, btn={34, -25} },

	{ id="server", name="Серверная (доход x1.5)", en="Server Room (x1.5 income)", cost=15000, income=0, needs="toprow",
	  kind="room", rect={-60, 20, -31, 35}, doors={{"N", -35, 5}}, skip={W=true, S=true, E=true}, extra="servers",
	  floor=Color3.fromRGB(40, 45, 55), btn={-35, 16} },

	{ id="champ",  name="Зал для чемпионатов", en="Championship Room", cost=22000, income=10, needs="server",
	  kind="room", rect={12, -20, 45, 0}, doors={{"W", -10, 4}}, skip={S=true}, floor=Color3.fromRGB(40, 55, 110), btn={7, -10} },
	{ id="champ1", name="Турнирный ряд 1", en="Tournament Row 1", cost=30000, income=60, needs="champ", kind="pcs",
	  pcs={{16.5,-13},{23,-13},{29.5,-13},{36,-13},{42.5,-13}}, rot=0, btn={29.5, -17.5} },
	{ id="champ2", name="Турнирный ряд 2", en="Tournament Row 2", cost=40000, income=80, needs="champ1", kind="pcs",
	  pcs={{16.5,-4},{23,-4},{29.5,-4},{36,-4},{42.5,-4}}, rot=0, btn={29.5, -8.5} },

	{ id="stream", name="Стримерская", en="Streamer Room", cost=60000, income=120, needs="champ2",
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
local function buildWalls(parent, origin, rect, doors, skip, height, color)
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
				else
					box(parent, origin, Vector3.new(1, height, len), side.fixed, height / 2, mid, color)
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
function builders.pcs(item, origin, model)
	local color = item.color or Color3.fromRGB(200, 60, 80)
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
		else
			simpleDesk(model, cf, color)
		end
	end
end

-- Модель из магазина (ресепшн, автомат...)
function builders.model(item, origin, model)
	local cf = at(origin, item.pos[1], 0, item.pos[2]) * CFrame.Angles(0, math.rad(item.rot or 0), 0)
	local m = cloneTemplate(item.model, item.scale)
	if m then
		m:PivotTo(cf)
		m.Parent = model
	else
		makePart({ Size = Vector3.new(6, 4, 3), CFrame = cf * CFrame.new(0, 2, 0), Color = Color3.fromRGB(60, 120, 200), Parent = model })
	end
end

-- Стены всего клуба + закрытые двери «на будущее» + граффити
function builders.outer(item, origin, model, lang)
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
	lockedDoor(8, -35, true, T(lang, "secret"), Color3.fromRGB(20, 20, 25))
	lockedDoor(-60, -5, false, T(lang, "soon"), Color3.fromRGB(120, 90, 30))
	for _, z in ipairs({ -24, -8, 20 }) do
		lockedDoor(60, z, false, T(lang, "soon"), Color3.fromRGB(70, 60, 80))
	end

	-- граффити на внутренней стороне стен
	local graffiti = {}
	if templates then
		for _, child in ipairs(templates:GetChildren()) do
			if child:IsA("Decal") then table.insert(graffiti, child) end
		end
	end
	local spots = {
		{ 32, -34.4, 0 },    -- верхняя стена, над рядом из 6 ПК
		{ 59.4, 6, -90 },    -- правая стена
		{ 30, 34.4, 180 },   -- нижняя стена, у общего зала
		{ -12, 34.4, 180 },  -- нижняя стена, у админа
	}
	for i, spot in ipairs(spots) do
		if #graffiti == 0 then break end
		local panel = makePart({
			Size = Vector3.new(16, 10, 0.2),
			CFrame = at(origin, spot[1], 8.5, spot[2]) * CFrame.Angles(0, math.rad(spot[3]), 0),
			Transparency = 1,
			CanCollide = false,
			Parent = model,
		})
		local decal = graffiti[(i - 1) % #graffiti + 1]:Clone()
		decal.Face = Enum.NormalId.Back
		decal.Parent = panel
	end
end

-- Комната: пол своего цвета + стены с дверью + начинка
function builders.room(item, origin, model, lang)
	local r = item.rect
	local w, d = (r[3] - r[1]) * S, (r[4] - r[2]) * S
	box(model, origin, Vector3.new(w, 0.2, d), (r[1] + r[3]) / 2, 0.1, (r[2] + r[4]) / 2,
		item.floor or Color3.fromRGB(80, 70, 100), Enum.Material.SmoothPlastic, { CanCollide = false })
	buildWalls(model, origin, r, item.doors, item.skip, CONFIG.WALL_HEIGHT - 2, INNER_COLOR)
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
	for i = 0, 3 do
		local x = -56 + i * 5.5
		local rack = box(model, origin, Vector3.new(4, 9, 4), x, 4.5, 31, Color3.fromRGB(25, 25, 30), Enum.Material.Metal)
		for j = 0, 5 do
			box(model, origin, Vector3.new(3, 0.25, 0.1), x, 1.5 + j * 1.2, 31 - 1.4,
				j % 2 == 0 and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(80, 170, 255), Enum.Material.Neon)
		end
		if i == 0 then
			addLabel(rack, lang == "ru" and "ДОХОД x1.5" or "INCOME x1.5", Color3.fromRGB(120, 255, 160))
		end
	end
end

function builders.stream(item, origin, model)
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
	box(model, origin, Vector3.new(14, 0.1, 12), -50, 0.25, -6, Color3.fromRGB(150, 20, 40), Enum.Material.Fabric)
	builders.pcs({ pcs = { { -50, -9 } }, rot = 0, color = Color3.fromRGB(255, 200, 60) }, origin, model)
	local plate = box(model, origin, Vector3.new(8, 2, 0.3), -50, 9, -13.4, Color3.fromRGB(30, 25, 10))
	addSign(plate, Enum.NormalId.Back, "VIP SOLO", Color3.fromRGB(255, 210, 80))
end

-- Лаунж: диван, столик, телевизор и кресло
function builders.lounge(item, origin, model)
	sofa(model, origin, 0, 14, 90, Color3.fromRGB(70, 50, 110))
	box(model, origin, Vector3.new(3, 1.6, 7), 5.5, 0.8, 14, Color3.fromRGB(60, 40, 30), Enum.Material.Wood)
	tv(model, origin, 10.5, 5, 14, -90, 10)
	box(model, origin, Vector3.new(1, 3.5, 1), 10.5, 1.75, 14, Color3.fromRGB(30, 30, 35))
	local chair = cloneTemplate("chair")
	if chair then
		chair:PivotTo(at(origin, 5.5, 0, 3) * CFrame.Angles(0, math.rad(180), 0))
		chair.Parent = model
	end
end

-- Диван и стулья возле сцены
function builders.sofaset(item, origin, model)
	sofa(model, origin, -2, -17, 180, Color3.fromRGB(110, 40, 60))
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

-- Сцена с фотографией владельца
function builders.stage(item, origin, model, lang)
	box(model, origin, Vector3.new(16 * S, 1.5, 10 * S), -5, 0.75, -30, Color3.fromRGB(40, 35, 60), Enum.Material.Wood)
	box(model, origin, Vector3.new(16 * S, 0.3, 0.4), -5, 1.6, -25, Color3.fromRGB(255, 200, 80), Enum.Material.Neon)
	-- экран вертикальный, как видео (768x1120)
	local frame = box(model, origin, Vector3.new(7, 10.2, 0.5), -5, 7.5, -34.3, Color3.fromRGB(20, 20, 25))
	if CONFIG.POSTER_VIDEO ~= "" then
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.Parent = frame
		local video = Instance.new("VideoFrame")
		video.Size = UDim2.fromScale(1, 1)
		video.BackgroundTransparency = 1
		video.Video = CONFIG.POSTER_VIDEO
		video.Looped = true
		video.Volume = CONFIG.POSTER_VIDEO_VOLUME
		video.Parent = gui
		video:Play()
	elseif CONFIG.POSTER_FLIPBOOK.image ~= "" then
		local fb = CONFIG.POSTER_FLIPBOOK
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.Parent = frame
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromScale(1, 1)
		img.BackgroundTransparency = 1
		img.Image = fb.image
		img.ImageRectSize = Vector2.new(fb.frameW, fb.frameH)
		img.Parent = gui

		local sound
		if fb.sound ~= "" then
			sound = Instance.new("Sound")
			sound.SoundId = fb.sound
			sound.Volume = fb.volume
			sound.RollOffMaxDistance = 80
			sound.Parent = frame
		end

		local total = fb.cols * fb.rows
		local step = fb.length / total
		task.spawn(function()
			while frame.Parent do
				if sound then sound:Play() end
				for i = 0, total - 1 do
					if not frame.Parent then return end
					img.ImageRectOffset = Vector2.new((i % fb.cols) * fb.frameW, math.floor(i / fb.cols) * fb.frameH)
					task.wait(step)
				end
				task.wait(fb.pause)
			end
		end)
	elseif CONFIG.POSTER_IMAGE ~= "" then
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.Parent = frame
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromScale(1, 1)
		img.BackgroundTransparency = 1
		img.Image = CONFIG.POSTER_IMAGE
		img.ScaleType = Enum.ScaleType.Fit
		img.Parent = gui
	else
		addSign(frame, Enum.NormalId.Back, T(lang, "poster"), Color3.fromRGB(255, 220, 150))
	end
	-- прожекторы
	for _, x in ipairs({ -11, 1 }) do
		local lamp = box(model, origin, Vector3.new(1.5, 1.5, 1.5), x, 12, -26, Color3.fromRGB(30, 30, 30), Enum.Material.Metal)
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Bottom
		spot.Angle = 70
		spot.Range = 20
		spot.Brightness = 3
		spot.Color = Color3.fromRGB(255, 220, 180)
		spot.Parent = lamp
	end
end

--=========================================================================
-- 6. УЧАСТКИ
--=========================================================================

local plotsFolder = Instance.new("Folder")
plotsFolder.Name = "Участки"
plotsFolder.Parent = workspace

local plots = {}          -- список всех участков
local plotByPlayer = {}   -- игрок -> участок

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

	-- стрелка над следующей покупкой
	local arrow = makePart({
		Name = "Стрелка",
		Size = Vector3.new(2, 2, 2),
		Color = Color3.fromRGB(255, 220, 60),
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})
	local arrowMesh = Instance.new("SpecialMesh")
	arrowMesh.MeshType = Enum.MeshType.FileMesh
	arrowMesh.MeshId = "rbxassetid://1033714"     -- конус
	arrowMesh.Scale = Vector3.new(1.4, 2.4, 1.4)
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
		local button = box(model, origin, Vector3.new(6, 1.2, 6), item.btn[1], 0.6, item.btn[2], Color3.fromRGB(220, 60, 60))
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
		button.CanCollide = false
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

	if next_ then
		plot.arrow.CFrame = next_.CFrame * CFrame.new(0, 7, 0) * CFrame.Angles(math.rad(180), 0, 0)
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
	for id in pairs(plot.owned) do
		local item = ITEM_BY_ID[id]
		if item then total += item.income end
	end
	local boost = plot.owned.server and CONFIG.SERVER_BOOST or 1
	plot.income = math.floor(total * boost * plot.multiplier)

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
		builder(item, plot.origin, model, plot.lang)
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
	buildItem(plot, item, true)
	recalcIncome(plot)
	refreshButtons(plot)
	playSound(CONFIG.SOUND_BUY, plot.buttons[item.id], 0.6)
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
	plot.lang = langOf(player)
	plot.nameLabel.Text = T(plot.lang, "club", player.DisplayName)
	plot.safeLabel.Text = T(plot.lang, "machine")
	plot.prompt.ActionText = T(plot.lang, "action")
	plot.prompt.ObjectText = T(plot.lang, "object")
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

	local function placeCharacter(character)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root then
			task.wait(0.1)
			root.CFrame = plot.spawnPad.CFrame * CFrame.new(0, 4, 0) * CFrame.Angles(0, math.rad(0), 0)
		end
	end
	-- Только в Studio: сброс прогресса для тестов.
	-- В командной строке Studio: game.Players.ИМЯ:SetAttribute("DevReset", true)
	if game:GetService("RunService"):IsStudio() then
		player:GetAttributeChangedSignal("DevReset"):Connect(function()
			if not player:GetAttribute("DevReset") then return end
			player:SetAttribute("DevReset", false)
			clearPlot(plot)
			money.Value = CONFIG.START_MONEY
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
	Lighting.ClockTime = 16
	Lighting.Brightness = 2.5
	Lighting.ExposureCompensation = 0.2
	Lighting.Ambient = Color3.fromRGB(165, 150, 190)
	Lighting.OutdoorAmbient = Color3.fromRGB(170, 160, 195)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5

	local function ensure(className, name)
		local obj = Lighting:FindFirstChild(name) or Instance.new(className)
		obj.Name = name
		obj.Parent = Lighting
		return obj
	end

	local bloom = ensure("BloomEffect", "КлубBloom")
	bloom.Intensity = 0.3
	bloom.Size = 18
	bloom.Threshold = 1.5

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
	connectPlotTouches(createPlot(index))
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- игроки, которые успели зайти до загрузки скрипта
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

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
			music.SoundId = CONFIG.MUSIC_IDS[index]
			music:Play()
			music.Ended:Wait()
		end
	end)
end

print("[КлубТайкун] Сервер запущен. Участков:", CONFIG.MAX_PLOTS)
