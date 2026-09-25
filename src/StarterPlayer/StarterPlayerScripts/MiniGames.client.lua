--[[=========================================================================
	МИНИ-ИГРЫ (кнопки справа, раз в 5 минут каждая)
	🎯 Лови кружки — за минуту нажать как можно больше кружков
	🧮 Быстрый счёт — примеры на сложение и вычитание, выбрать ответ
==========================================================================]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("MiniGame")
local isRu = player.LocaleId:sub(1, 2) == "ru"
local function L(ru, en) return isRu and ru or en end
local GAME_TIME = 60   -- меняется под каждую игру

local function short(n)
	n = math.floor(n)
	if n >= 1e9 then return string.format("%.1fB", n / 1e9) end
	if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
	if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
	return tostring(n)
end

local screen = Instance.new("ScreenGui")
screen.Name = "МиниИгры"
screen.ResetOnSpawn = false
screen.Parent = player:WaitForChild("PlayerGui")

local function corner(o, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r or 12) c.Parent = o end
local function stroke(o, c, t) local s = Instance.new("UIStroke") s.Color = c s.Thickness = t or 2 s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border s.Parent = o end
local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Text = ""
	for k, v in pairs(props) do l[k] = v end
	l.Parent = parent
	return l
end
local function button(parent, props, onClick)
	local b = Instance.new("TextButton")
	b.Font = Enum.Font.GothamBlack
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	for k, v in pairs(props) do b[k] = v end
	b.Parent = parent
	corner(b, 12)
	if onClick then b.MouseButton1Click:Connect(onClick) end
	return b
end

--=========================================================================
-- Окно игры
--=========================================================================

local win = Instance.new("Frame")
win.Size = UDim2.new(0.6, 0, 0.7, 0)
win.Position = UDim2.new(0.2, 0, 0.15, 0)
win.BackgroundColor3 = Color3.fromRGB(24, 22, 32)
win.Visible = false
win.Parent = screen
corner(win, 18)
stroke(win, Color3.fromRGB(120, 220, 255), 4)
local title = label(win, { Size = UDim2.new(0.6, 0, 0.1, 0), Position = UDim2.new(0.03, 0, 0.02, 0), TextXAlignment = Enum.TextXAlignment.Left })
local timerL = label(win, { Size = UDim2.new(0.3, 0, 0.08, 0), Position = UDim2.new(0.62, 0, 0.03, 0), TextColor3 = Color3.fromRGB(255, 215, 90) })
local scoreL = label(win, { Size = UDim2.new(0.5, 0, 0.07, 0), Position = UDim2.new(0.03, 0, 0.12, 0), TextColor3 = Color3.fromRGB(120, 255, 140), TextXAlignment = Enum.TextXAlignment.Left })
local area = Instance.new("Frame")
area.Size = UDim2.new(0.94, 0, 0.76, 0)
area.Position = UDim2.new(0.03, 0, 0.21, 0)
area.BackgroundColor3 = Color3.fromRGB(34, 32, 46)
area.ClipsDescendants = true
area.Parent = win
corner(area, 14)

local running = false
local closeB = button(win, { Size = UDim2.new(0.07, 0, 0.1, 0), Position = UDim2.new(0.94, 0, -0.04, 0), BackgroundColor3 = Color3.fromRGB(230, 50, 50), Text = "X" },
	function()
		-- закрыть можно в любой момент; незаконченная игра не засчитывается
		running = false
		win.Visible = false
	end)
local _ = closeB

local function clearArea() for _, c in ipairs(area:GetChildren()) do if not c:IsA("UICorner") then c:Destroy() end end end

local function showResult(reward)
	clearArea()
	label(area, { Size = UDim2.new(0.8, 0, 0.25, 0), Position = UDim2.new(0.1, 0, 0.2, 0),
		Text = reward and ("💰 +" .. short(reward)) or L("Не засчитано", "Not counted"), TextColor3 = Color3.fromRGB(255, 215, 90) })
	label(area, { Size = UDim2.new(0.8, 0, 0.12, 0), Position = UDim2.new(0.1, 0, 0.5, 0), Font = Enum.Font.GothamMedium,
		Text = L("Сыграть снова можно через 5 минут", "Play again in 5 minutes") })
	button(area, { Size = UDim2.new(0.3, 0, 0.14, 0), Position = UDim2.new(0.35, 0, 0.72, 0), BackgroundColor3 = Color3.fromRGB(40, 190, 90), Text = "OK" },
		function() win.Visible = false end)
end

local function runTimer(onTick)
	local start = os.clock()
	while os.clock() - start < GAME_TIME and running do
		timerL.Text = "⏱ " .. math.ceil(GAME_TIME - (os.clock() - start))
		if onTick then onTick() end
		task.wait(0.1)
	end
end

--=========================================================================
-- 🎯 Лови кружки
--=========================================================================

local function playClick()
	local score = 0
	scoreL.Text = L("Поймано: 0   💣 = −5", "Caught: 0   💣 = −5")
	clearArea()
	local colors = { Color3.fromRGB(255, 80, 120), Color3.fromRGB(255, 210, 60), Color3.fromRGB(80, 220, 255), Color3.fromRGB(120, 255, 120), Color3.fromRGB(200, 120, 255) }
	local function spawnCircle()
		local size = math.random(55, 85)
		local isBomb = math.random() < 0.25
		local c = button(area, {
			Size = UDim2.new(0, size, 0, size),
			Position = UDim2.new(math.random() * 0.85, 0, math.random() * 0.8, 0),
			BackgroundColor3 = isBomb and Color3.fromRGB(35, 35, 40) or colors[math.random(#colors)],
			Text = isBomb and "💣" or "💰", AutoButtonColor = false,
		})
		corner(c, size)
		stroke(c, Color3.new(1, 1, 1), 3)
		c.MouseButton1Down:Connect(function()
			if not running then return end
			if isBomb then
				score = math.max(0, score - 5)
				area.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
				task.delay(0.15, function() area.BackgroundColor3 = Color3.fromRGB(34, 32, 46) end)
			else
				score += 1
			end
			scoreL.Text = L("Поймано: ", "Caught: ") .. score
			c:Destroy()
			spawnCircle()
		end)
		-- если долго не ловят — исчезает и появляется в другом месте
		task.delay(1.6, function()
			if c.Parent and running then c:Destroy() spawnCircle() end
		end)
	end
	for _ = 1, 3 do spawnCircle() end
	runTimer()
	return score
end

--=========================================================================
-- 🧮 Быстрый счёт
--=========================================================================

local function playMath()
	local score = 0
	scoreL.Text = L("Решено: 0", "Solved: 0")
	local function nextQuestion()
		clearArea()
		local a, b = math.random(2, 99), math.random(2, 99)
		local plus = math.random() < 0.5
		if not plus and b > a then a, b = b, a end
		local answer = plus and a + b or a - b
		label(area, { Size = UDim2.new(0.8, 0, 0.3, 0), Position = UDim2.new(0.1, 0, 0.06, 0),
			Text = a .. (plus and " + " or " − ") .. b .. " = ?", TextColor3 = Color3.fromRGB(255, 230, 140) })
		local options = { answer }
		while #options < 4 do
			local wrong = answer + math.random(-12, 12)
			if wrong ~= answer and wrong >= 0 and not table.find(options, wrong) then table.insert(options, wrong) end
		end
		for i = #options, 2, -1 do local j = math.random(i) options[i], options[j] = options[j], options[i] end
		for i, v in ipairs(options) do
			local b2 = button(area, {
				Size = UDim2.new(0.4, 0, 0.22, 0),
				Position = UDim2.new(i % 2 == 1 and 0.07 or 0.53, 0, i <= 2 and 0.42 or 0.7, 0),
				BackgroundColor3 = Color3.fromRGB(60, 90, 200), Text = tostring(v),
			})
			b2.MouseButton1Click:Connect(function()
				if not running then return end
				if v == answer then
					score += 1
					scoreL.Text = L("Решено: ", "Solved: ") .. score
					nextQuestion()
				else
					-- ошибка: сразу новый пример, угадывать бесполезно
					b2.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
					area.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
					task.wait(0.25)
					area.BackgroundColor3 = Color3.fromRGB(34, 32, 46)
					if running then nextQuestion() end
				end
			end)
		end
	end
	nextQuestion()
	runTimer()
	return score
end

--=========================================================================
-- Кнопки справа с обратным отсчётом
--=========================================================================

local GAMES = {
	{ key = "click", icon = "🎯", ru = "Лови кружки", en = "Catch Coins", play = playClick, color = Color3.fromRGB(230, 90, 50), time = 30 },
	{ key = "math",  icon = "🧮", ru = "Быстрый счёт", en = "Quick Math", play = playMath, color = Color3.fromRGB(70, 110, 230), time = 60 },
}

local side = Instance.new("Frame")
side.Size = UDim2.new(0, 100, 0, 220)
side.Position = UDim2.new(1, -112, 0.5, -110)
side.BackgroundTransparency = 1
side.Parent = screen
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 10)
list.Parent = side

for _, g in ipairs(GAMES) do
	local b = button(side, { Size = UDim2.new(1, 0, 0, 100), BackgroundColor3 = g.color, Text = "" })
	stroke(b, Color3.new(1, 1, 1), 3)
	label(b, { Size = UDim2.new(1, 0, 0.5, 0), Position = UDim2.new(0, 0, 0.04, 0), Text = g.icon })
	local cap = label(b, { Size = UDim2.new(1, -8, 0.36, 0), Position = UDim2.new(0, 4, 0.58, 0), Text = "" })
	local function ready() return (player:GetAttribute("MG_" .. g.key) or 0) <= os.time() end
	task.spawn(function()
		while true do
			local left = (player:GetAttribute("MG_" .. g.key) or 0) - os.time()
			if left > 0 then
				cap.Text = string.format("%d:%02d", left // 60, left % 60)
				b.BackgroundColor3 = Color3.fromRGB(80, 80, 95)
			else
				cap.Text = isRu and g.ru or g.en
				b.BackgroundColor3 = g.color
			end
			task.wait(1)
		end
	end)
	b.MouseButton1Click:Connect(function()
		if running or not ready() then return end
		if remote:InvokeServer("start", g.key) ~= true then return end
		GAME_TIME = g.time
		title.Text = g.icon .. " " .. (isRu and g.ru or g.en)
		win.Visible = true
		running = true
		local score = g.play()
		local finished = running
		running = false
		timerL.Text = ""
		if finished then
			showResult(remote:InvokeServer("finish", g.key, score))
		end
	end)
end
