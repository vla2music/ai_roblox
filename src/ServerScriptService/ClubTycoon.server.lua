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
	SOUND_CROWD    = "",   -- чужой звук гула Roblox не разрешил (403); нужен свой
	CROWD_VOLUME_MIN = 0.12,
	CROWD_VOLUME_MAX = 0.45,

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
	CLICK_COOLDOWN = 0.25,   -- как часто можно жать E (секунды)
	CLICK_BONUS    = 0.3,    -- бонус за нажатие = доход в секунду * это число
	MAX_COINS      = 40,     -- больше монет на площадке не лежит, они «слипаются»

	SERVER_BOOST   = 1.5,    -- серверная умножает весь доход

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
	{ id="hall1", name="Ряд компов 1", en="PC Row 1", cost=900,  income=12, needs="hall",  kind="pcs",
	  pcs={{20,8},{28,8},{36,8},{44,8},{52,8}},    rot=0, btn={36, 3} },
	{ id="hall2", name="Ряд компов 2", en="PC Row 2", cost=1600, income=18, needs="hall1", kind="pcs",
	  pcs={{20,17},{28,17},{36,17},{44,17},{52,17}}, rot=0, btn={36, 12.5} },
	{ id="hall3", name="Ряд компов 3", en="PC Row 3", cost=2800, income=26, needs="hall2", kind="pcs",
	  pcs={{20,26},{28,26},{36,26},{44,26},{52,26}}, rot=0, btn={36, 21.5} },

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
	  kind="room", rect={12, -20, 60, 0}, doors={{"W", -10, 4}}, skip={S=true, E=true}, extra="champDivider",
	  floor=Color3.fromRGB(40, 55, 110), btn={7, -10} },
	{ id="champ1", name="Команда красных (5 ПК)", en="Red Team (5 PCs)", cost=30000, income=60, needs="champ", kind="pcs",
	  pcs={{20,-12},{28,-12},{36,-12},{44,-12},{52,-12}}, rot=180, color=Color3.fromRGB(230, 70, 70), btn={7, -15} },
	{ id="champ2", name="Команда синих (5 ПК)", en="Blue Team (5 PCs)", cost=40000, income=80, needs="champ1", kind="pcs",
	  pcs={{20,-5},{28,-5},{36,-5},{44,-5},{52,-5}}, rot=0, color=Color3.fromRGB(70, 130, 255), btn={7, -4} },

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
			rebirths = tonumber(result.rebirths) or 0,
			pcTier = tonumber(result.pcTier) or 1,
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
function builders.pcs(item, origin, model, lang, plot)
	local tier = plot and plot.pcTier or 1
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
local function spawnAdmin(origin, model)
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
	npc:PivotTo(at(origin, -17.5, 3.2, 10) * CFrame.Angles(0, math.rad(-90), 0))
	npc.Parent = model
	local head = npc:FindFirstChild("Head")
	if head then addLabel(head, "ADMIN", Color3.fromRGB(120, 220, 255), 2) end
end

function builders.model(item, origin, model)
	if item.id == "admin" then spawnAdmin(origin, model) end
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
	-- перегородка между рядом из 4 ПК и стойкой админа
	box(model, origin, Vector3.new(1, H - 2, 34 * S), -19, (H - 2) / 2, 3, INNER_COLOR)

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
	sofa(model, origin, 0, 14, -90, Color3.fromRGB(70, 50, 110))
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
function builders.shops(item, origin, model)
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

	-- табло геймпасов у входа (как у популярных тайкунов)
	local passCards = {}
	local header = box(model, origin, Vector3.new(30, 3.4, 0.6), 18, 13.2, 45, Color3.fromRGB(25, 20, 40))
	addSign(header, Enum.NormalId.Front, "⭐ GAMEPASSES ⭐", Color3.fromRGB(255, 215, 90))
	box(model, origin, Vector3.new(31, 12, 0.4), 18, 6.5, 45.3, Color3.fromRGB(110, 75, 45), Enum.Material.Wood)
	for _, x in ipairs({ 7.5, 28.5 }) do
		box(model, origin, Vector3.new(1, 15, 1), x, 7.5, 45.4, Color3.fromRGB(90, 60, 35), Enum.Material.Wood)
	end
	for i, pass in ipairs(CONFIG.GAMEPASSES) do
		local panel = box(model, origin, Vector3.new(8.4, 10.4, 0.4), 12 + (i - 1) * 6, 6.5, 45, Color3.fromRGB(30, 28, 45))
		panel.Name = "Геймпасс_" .. pass.key

		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
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
		passCards  = passCards,
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
	local tierMult = Shared.PC_TIERS[plot.pcTier or 1].mult
	for id in pairs(plot.owned) do
		local item = ITEM_BY_ID[id]
		if item then
			total += item.kind == "pcs" and item.income * tierMult or item.income
		end
	end
	local boost = plot.owned.server and CONFIG.SERVER_BOOST or 1
	local rebirthBoost = 1 + (plot.rebirths or 0)   -- ребёрт: x2, x3, x4...
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
		if pass.id ~= 0 then
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
		humanoid.WalkSpeed = hasPass(player, "speed") and 28 or 16
	end
end

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
