--[[=========================================================================
	ИГРОВОЙ ЗАЛ ARCADE — игры на ловкость (без ставок, бесплатно).
	Автоматы ставит Arcade.server.lua (у кнопки атрибут ArcadeGame).
	🎯 shoot   — Тир: 30 сек, жми на мишени
	⏱️ timing  — Стоп на зелёном: 10 раундов, зона всё уже
	🧱 stacker — Башня: ставь блоки ровно, промах обрезает блок
	🏒 hockey  — Аэрохоккей против бота, 60 сек
	Награду считает и проверяет сервер (MiniGame в ClubTycoon), раз в 5 минут.
==========================================================================]]

local Players                = game:GetService("Players")
local ReplicatedStorage      = game:GetService("ReplicatedStorage")
local RunService             = game:GetService("RunService")
local UserInputService       = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("MiniGame")
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
-- Окно
--=========================================================================
local screen = Instance.new("ScreenGui")
screen.Name = "Arcade"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.Parent = player:WaitForChild("PlayerGui")

local function corner(o, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r or 12) c.Parent = o end
local function new(class, parent, props)
	local o = Instance.new(class)
	if o:IsA("GuiObject") then o.BorderSizePixel = 0 end
	if o:IsA("TextLabel") or o:IsA("TextButton") then
		o.Font = Enum.Font.GothamBlack
		o.TextScaled = true
		o.TextColor3 = Color3.new(1, 1, 1)
		o.BackgroundTransparency = 1
	end
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

local win = new("Frame", screen, { Size = UDim2.fromScale(0.62, 0.78), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(18, 14, 30), Visible = false })
corner(win, 18)
local st = Instance.new("UIStroke") st.Color = Color3.fromRGB(255, 50, 200) st.Thickness = 3 st.Parent = win
local title = new("TextLabel", win, { Size = UDim2.fromScale(0.7, 0.08), Position = UDim2.fromScale(0.04, 0.02), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(0, 230, 255) })
local info = new("TextLabel", win, { Size = UDim2.fromScale(0.92, 0.06), Position = UDim2.fromScale(0.04, 0.1), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold })
local closeBtn = new("TextButton", win, { Size = UDim2.fromScale(0.08, 0.08), Position = UDim2.fromScale(0.9, 0.02), Text = "✕", BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(200, 50, 70) })
corner(closeBtn, 10)
local area = new("Frame", win, { Size = UDim2.fromScale(0.92, 0.78), Position = UDim2.fromScale(0.04, 0.18), BackgroundColor3 = Color3.fromRGB(8, 6, 16), BackgroundTransparency = 0, ClipsDescendants = true })
corner(area, 12)

local running = nil      -- имя игры
local cancelled = false
local function clearArea() for _, c in ipairs(area:GetChildren()) do if not c:IsA("UICorner") then c:Destroy() end end end
local function close()
	cancelled = true
	running = nil
	win.Visible = false
	clearArea()
end
closeBtn.MouseButton1Click:Connect(close)

-- большой текст в центре поля (итог, «жди N мин»)
local function banner(text, color)
	clearArea()
	new("TextLabel", area, { Size = UDim2.fromScale(0.9, 0.3), Position = UDim2.fromScale(0.05, 0.35), Text = text, TextColor3 = color or Color3.new(1, 1, 1), TextWrapped = true })
end

local function finish(name, score)
	if running ~= name then return end
	running = nil
	local reward = remote:InvokeServer("finish", name, score)
	if reward then
		banner(L("Очки: ", "Score: ") .. score .. "\n💰 +" .. short(reward), Color3.fromRGB(255, 215, 80))
	else
		banner(L("Очки: ", "Score: ") .. score, Color3.new(1, 1, 1))
	end
	task.delay(3.5, function() if not running then close() end end)
end

--=========================================================================
-- 🎯 Тир
--=========================================================================
local function shoot()
	local score, T = 0, 30
	local t0 = os.clock()
	while running == "shoot" and os.clock() - t0 < T do
		info.Text = L("🎯 Попаданий: ", "🎯 Hits: ") .. score .. L("   ⏳ ", "   ⏳ ") .. math.ceil(T - (os.clock() - t0))
		-- мишень выезжает сбоку и едет через поле
		local fromLeft = math.random() < 0.5
		local y = math.random(10, 80) / 100
		local size = math.random(10, 15) / 100
		local b = new("TextButton", area, { Size = UDim2.fromScale(size * 0.6, size), Text = "🎯", Position = UDim2.fromScale(fromLeft and -0.1 or 1.0, y) })
		local speed = (math.random(35, 70) / 100) * (fromLeft and 1 or -1)
		local born = os.clock()
		b.MouseButton1Down:Connect(function()
			if running ~= "shoot" then return end
			score += 1
			b:Destroy()
		end)
		task.spawn(function()
			while b.Parent and os.clock() - born < 3 do
				local dt = task.wait()
				b.Position = b.Position + UDim2.fromScale(speed * dt, 0)
			end
			if b.Parent then b:Destroy() end
		end)
		task.wait(0.55)
	end
	finish("shoot", score)
end

--=========================================================================
-- ⏱️ Стоп на зелёном
--=========================================================================
local function timing()
	local score = 0
	for round = 1, 10 do
		if running ~= "timing" then return end
		clearArea()
		info.Text = L("⏱️ Раунд ", "⏱️ Round ") .. round .. "/10   ✅ " .. score
		local bar = new("Frame", area, { Size = UDim2.fromScale(0.9, 0.16), Position = UDim2.fromScale(0.05, 0.3), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(60, 30, 40) })
		corner(bar, 8)
		local zw = 0.22 - round * 0.015            -- зелёная зона всё уже
		local zx = math.random(10, math.floor((0.9 - zw) * 100)) / 100
		new("Frame", bar, { Size = UDim2.fromScale(zw, 1), Position = UDim2.fromScale(zx, 0), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(60, 230, 110) })
		local marker = new("Frame", bar, { Size = UDim2.fromScale(0.012, 1.4), Position = UDim2.fromScale(0, -0.2), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1) })
		local stop = new("TextButton", area, { Size = UDim2.fromScale(0.4, 0.22), Position = UDim2.fromScale(0.3, 0.62), Text = "STOP", BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(255, 60, 90) })
		corner(stop, 14)
		local x, dir, speed = 0, 1, 0.55 + round * 0.09
		local pressed = false
		stop.MouseButton1Down:Connect(function() pressed = true end)
		local conn = UserInputService.InputBegan:Connect(function(i, gp)
			if not gp and i.KeyCode == Enum.KeyCode.Space then pressed = true end
		end)
		while not pressed and running == "timing" do
			local dt = RunService.RenderStepped:Wait()
			x += dir * speed * dt
			if x > 0.988 then x, dir = 0.988, -1 elseif x < 0 then x, dir = 0, 1 end
			marker.Position = UDim2.fromScale(x, -0.2)
		end
		conn:Disconnect()
		local hit = x + 0.006 >= zx and x + 0.006 <= zx + zw
		if hit then score += 1 end
		stop.Text = hit and "✅" or "❌"
		task.wait(0.8)
	end
	finish("timing", score)
end

--=========================================================================
-- 🧱 Башня
--=========================================================================
local function stacker()
	clearArea()
	local H = 0.07                           -- высота блока (доля поля)
	local left, width = 0.3, 0.4             -- нижний блок
	new("Frame", area, { Size = UDim2.fromScale(width, H), Position = UDim2.fromScale(left, 1 - H), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(255, 200, 40) })
	local score, level = 0, 1
	local pressed = false
	local btn = new("TextButton", area, { Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 5 })
	btn.MouseButton1Down:Connect(function() pressed = true end)
	local conn = UserInputService.InputBegan:Connect(function(i, gp)
		if not gp and i.KeyCode == Enum.KeyCode.Space then pressed = true end
	end)
	while running == "stacker" do
		info.Text = L("🧱 Этаж: ", "🧱 Height: ") .. score .. L("   жми, когда блок над башней", "   tap when it's above the tower")
		-- башня выше середины — сдвигаем всё вниз
		local y = 1 - H * (level + 1)
		if y < 0.3 then
			for _, c in ipairs(area:GetChildren()) do
				if c:IsA("Frame") then c.Position = c.Position + UDim2.fromScale(0, H) end
			end
			y += H
		end
		local block = new("Frame", area, { Size = UDim2.fromScale(width, H), Position = UDim2.fromScale(0, y), BackgroundTransparency = 0,
			BackgroundColor3 = Color3.fromHSV((level * 0.07) % 1, 0.8, 1) })
		local x, dir, speed = 0, 1, 0.45 + level * 0.04
		pressed = false
		while not pressed and running == "stacker" do
			local dt = RunService.RenderStepped:Wait()
			x += dir * speed * dt
			if x > 1 - width then x, dir = 1 - width, -1 elseif x < 0 then x, dir = 0, 1 end
			block.Position = UDim2.fromScale(x, y)
		end
		-- обрезаем то, что свисает
		local a, b = math.max(x, left), math.min(x + width, left + width)
		if b - a <= 0.01 then
			block.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
			task.wait(0.6)
			break
		end
		left, width = a, b - a
		block.Position = UDim2.fromScale(left, y)
		block.Size = UDim2.fromScale(width, H)
		score += 1
		level += 1
		if score >= 30 then break end
		task.wait(0.25)
	end
	conn:Disconnect()
	finish("stacker", score)
end

--=========================================================================
-- 🏒 Аэрохоккей: ты внизу, бот наверху. Ворота — посередине верха и низа.
--=========================================================================
local function hockey()
	clearArea()
	local T = 60
	local rink = new("Frame", area, { Size = UDim2.fromScale(0.5, 1), Position = UDim2.fromScale(0.25, 0), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(230, 240, 255) })
	new("Frame", rink, { Size = UDim2.fromScale(1, 0.01), Position = UDim2.fromScale(0, 0.495), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(255, 80, 80) })
	for _, gy in ipairs({ 0, 0.985 }) do
		new("Frame", rink, { Size = UDim2.fromScale(0.4, 0.015), Position = UDim2.fromScale(0.3, gy), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(40, 40, 60) })
	end
	local function disc(color, size)
		local d = new("Frame", rink, { Size = UDim2.fromScale(size, size), SizeConstraint = Enum.SizeConstraint.RelativeXX, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 0, BackgroundColor3 = color })
		corner(d, 999)
		return d
	end
	local puck = disc(Color3.fromRGB(20, 20, 30), 0.1)
	local me = disc(Color3.fromRGB(0, 170, 255), 0.18)
	local bot = disc(Color3.fromRGB(255, 60, 90), 0.18)

	-- всё считаем в пикселях поля
	local W, Hh = rink.AbsoluteSize.X, rink.AbsoluteSize.Y
	local PR, MR = W * 0.05, W * 0.09
	local p, v = Vector2.new(W / 2, Hh / 2), Vector2.new(0, 0)
	local mePos, meVel = Vector2.new(W / 2, Hh * 0.85), Vector2.new()
	local botPos = Vector2.new(W / 2, Hh * 0.15)
	local myGoals, botGoals = 0, 0
	local t0 = os.clock()

	local function reset(towardMe)
		p = Vector2.new(W / 2, Hh / 2)
		v = Vector2.new((math.random() - 0.5) * W * 0.4, (towardMe and 1 or -1) * Hh * 0.25)
	end
	reset(true)

	local function hit(pos, vel)
		local d = p - pos
		if d.Magnitude < PR + MR and d.Magnitude > 0 then
			local n = d.Unit
			p = pos + n * (PR + MR)
			local along = v:Dot(n)
			if along < 0 then v = v - 2 * along * n end
			v = v + vel * 0.6 + n * W * 0.15
		end
	end

	while running == "hockey" and os.clock() - t0 < T do
		local dt = math.min(RunService.RenderStepped:Wait(), 1 / 30)
		info.Text = L("🏒 Ты ", "🏒 You ") .. myGoals .. " : " .. botGoals .. L(" Бот", " Bot") .. "   ⏳ " .. math.ceil(T - (os.clock() - t0))
		-- моя бита за мышкой / пальцем, только своя половина
		local m = UserInputService:GetMouseLocation() - rink.AbsolutePosition   -- окно без отступа сверху (IgnoreGuiInset)
		local target = Vector2.new(math.clamp(m.X, MR, W - MR), math.clamp(m.Y, Hh / 2 + MR, Hh - MR))
		local newPos = mePos:Lerp(target, math.min(1, dt * 20))
		meVel = (newPos - mePos) / dt
		mePos = newPos
		-- бот: едет к шайбе на своей половине, но не быстрее своей скорости
		local goal = p.Y < Hh / 2 and Vector2.new(p.X, math.max(p.Y - MR, MR)) or Vector2.new(p.X * 0.5 + W * 0.25, Hh * 0.15)
		local step = goal - botPos
		local maxStep = W * 0.9 * dt
		if step.Magnitude > maxStep then step = step.Unit * maxStep end
		local botVel = step / dt
		botPos += step
		-- шайба
		p += v * dt
		v *= (1 - 0.35 * dt)
		if v.Magnitude > W * 3 then v = v.Unit * W * 3 end
		if p.X < PR then p, v = Vector2.new(PR, p.Y), Vector2.new(-v.X, v.Y) end
		if p.X > W - PR then p, v = Vector2.new(W - PR, p.Y), Vector2.new(-v.X, v.Y) end
		local inGoalX = p.X > W * 0.3 and p.X < W * 0.7
		if p.Y < PR then
			if inGoalX then myGoals += 1 reset(false) else p, v = Vector2.new(p.X, PR), Vector2.new(v.X, -v.Y) end
		elseif p.Y > Hh - PR then
			if inGoalX then botGoals += 1 reset(true) else p, v = Vector2.new(p.X, Hh - PR), Vector2.new(v.X, -v.Y) end
		end
		hit(mePos, meVel)
		hit(botPos, botVel)
		puck.Position = UDim2.fromOffset(p.X, p.Y)
		me.Position = UDim2.fromOffset(mePos.X, mePos.Y)
		bot.Position = UDim2.fromOffset(botPos.X, botPos.Y)
	end
	finish("hockey", myGoals)
end

--=========================================================================
-- Запуск по кнопке у автомата
--=========================================================================
local GAMES = {
	shoot   = { L("🎯 ТИР", "🎯 SHOOTING"), shoot },
	timing  = { L("⏱️ СТОП НА ЗЕЛЁНОМ", "⏱️ STOP ON GREEN"), timing },
	stacker = { L("🧱 БАШНЯ", "🧱 STACKER"), stacker },
	hockey  = { L("🏒 АЭРОХОККЕЙ", "🏒 AIR HOCKEY"), hockey },
}

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local name = prompt:GetAttribute("ArcadeGame")
	local g = name and GAMES[name]
	if not g or running then return end
	win.Visible = true
	title.Text = g[1]
	info.Text = ""
	clearArea()
	local ok = remote:InvokeServer("start", name)
	if ok == false then
		local left = math.max(1, math.ceil(((player:GetAttribute("MG_" .. name) or 0) - os.time()) / 60))
		banner(L("⏳ Этот автомат снова через " .. left .. " мин.\nПопробуй другой!", "⏳ This machine again in " .. left .. " min.\nTry another one!"))
		task.delay(3, function() if not running then close() end end)
		return
	elseif ok == nil then
		banner(L("Сначала займи свой клуб 🙂", "Claim your club first 🙂"))
		task.delay(3, function() if not running then close() end end)
		return
	end
	cancelled = false
	running = name
	task.spawn(g[2])
end)
