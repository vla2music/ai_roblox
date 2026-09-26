--[[ NAZARTOK: «ролики» на экранах небоскрёбов (Billboards.server.lua ставит
     экраны). Это не настоящее видео, а анимация: прыгающие эмодзи, подпись,
     лайки, полоска просмотра. В подписях — подсказки к пасхалкам.
     Здесь же граффити получают русский текст для русских игроков. ]]

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local isRu = player.LocaleId:sub(1, 2) == "ru"
local function L(ru, en) return isRu and ru or en end

local CLIP_TIME = 7

-- ролик: эмодзи (скачут по очереди), подпись, автор, фон
local CLIPS = {
	{ { "🪂", "💨", "💍" }, L("Пролетел 14 колец с крыши 😱 #параплан", "Flew through 14 rings 😱 #paraglider"), Color3.fromRGB(20, 60, 50) },
	{ { "👀", "💰", "🏙️" }, L("Где прячется золотой сундук? Между домами… #пасхалка", "Where's the gold chest? Between towers… #secret"), Color3.fromRGB(60, 45, 10) },
	{ { "🛗", "🏢", "🪂" }, L("Лифт на крышу → парашют → соседняя крыша #трюк", "Lift → roof → parachute → next roof #stunt"), Color3.fromRGB(40, 20, 70) },
	{ { "🐱", "❤️", "🎮" }, L("Кот в клубе даёт бонус, если погладить 🐾", "The club cat gives a bonus if you pet it 🐾"), Color3.fromRGB(70, 30, 50) },
	{ { "🛥️", "🌊", "💎" }, L("На яхтах тоже есть сундуки… доплыви 🏊", "Yachts have chests too… swim there 🏊"), Color3.fromRGB(10, 40, 80) },
	{ { "🍋", "⚡", "😎" }, L("Лимонад через дорогу в 3 раза дешевле 🍋", "Lemonade across the road is 3x cheaper 🍋"), Color3.fromRGB(70, 65, 10) },
	{ { "🤫", "🚪", "❓" }, L("Тайная дверь «???» в клубе… что там? 🤔", "Secret door «???» in the club… what's behind? 🤔"), Color3.fromRGB(25, 25, 30) },
	{ { "🎡", "🌙", "✨" }, L("Колесо обозрения ночью — топ вид 🔥", "Ferris wheel at night — best view 🔥"), Color3.fromRGB(30, 20, 60) },
}

local function short(n)
	if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
	if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
	return tostring(n)
end

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	for k, v in pairs(props) do l[k] = v end
	l.Parent = parent
	return l
end

local function runScreen(gui)
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	label(bg, { Size = UDim2.fromScale(0.9, 0.06), Position = UDim2.fromScale(0.05, 0.02), Text = "♪ NazarTok", TextColor3 = Color3.fromRGB(255, 60, 140), TextXAlignment = Enum.TextXAlignment.Left })
	local emoji = label(bg, { Size = UDim2.fromScale(0.7, 0.35), Position = UDim2.fromScale(0.5, 0.38), AnchorPoint = Vector2.new(0.5, 0.5), Text = "" })
	local caption = label(bg, { Size = UDim2.fromScale(0.72, 0.16), Position = UDim2.fromScale(0.05, 0.72), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true })
	label(bg, { Size = UDim2.fromScale(0.6, 0.04), Position = UDim2.fromScale(0.05, 0.67), Text = "@nazar_club", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(200, 200, 210) })
	label(bg, { Size = UDim2.fromScale(0.16, 0.07), Position = UDim2.fromScale(0.8, 0.5), Text = "❤️" })
	local likes = label(bg, { Size = UDim2.fromScale(0.18, 0.035), Position = UDim2.fromScale(0.79, 0.575), Text = "0" })
	label(bg, { Size = UDim2.fromScale(0.16, 0.07), Position = UDim2.fromScale(0.8, 0.62), Text = "💬" })
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(0, 0.012)
	bar.Position = UDim2.fromScale(0, 0.97)
	bar.BackgroundColor3 = Color3.fromRGB(255, 60, 140)
	bar.BorderSizePixel = 0
	bar.Parent = bg

	local i = gui:GetAttribute("Offset") or 1
	while gui.Parent do
		local clip = CLIPS[(i - 1) % #CLIPS + 1]
		bg.BackgroundColor3 = clip[3]
		caption.Text = clip[2]
		local n = math.random(1200, 90000)
		bar.Size = UDim2.fromScale(0, 0.012)
		TweenService:Create(bar, TweenInfo.new(CLIP_TIME, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 0.012) }):Play()
		local t0 = os.clock()
		local k = 0
		while os.clock() - t0 < CLIP_TIME and gui.Parent do
			k += 1
			emoji.Text = clip[1][(k - 1) % #clip[1] + 1]
			-- «прыжок» эмодзи
			emoji.Rotation = math.random(-12, 12)
			emoji.Size = UDim2.fromScale(0.5, 0.25)
			TweenService:Create(emoji, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.7, 0.35) }):Play()
			n += math.random(50, 900)
			likes.Text = short(n)
			task.wait(CLIP_TIME / 6)
		end
		i += 1
	end
end

local function hook(d)
	if d:IsA("SurfaceGui") and d.Name == "NazarTok" then
		task.spawn(runScreen, d)
	elseif d:IsA("TextLabel") and d.Name == "Text" and d:GetAttribute("Ru") and isRu then
		d.Text = d:GetAttribute("Ru")
	end
end

local ads = workspace:WaitForChild("Реклама")
for _, d in ipairs(ads:GetDescendants()) do hook(d) end
ads.DescendantAdded:Connect(hook)
