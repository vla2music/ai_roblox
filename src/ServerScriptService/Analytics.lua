--[[=========================================================================
	АНАЛИТИКА, ЗНАЧКИ, ОБУЧЕНИЕ (модуль: require из любого серверного скрипта)

	• Аналитика Roblox (графики в Creator Hub → Analytics):
	  – Onboarding: где новички бросают игру в первые минуты;
	  – Economy: откуда приходят монеты и на что тратятся (копим по игроку
	    и отправляем раз в минуту — Roblox просит не слать каждое событие);
	  – Custom: каждая покупка клуба (на какой покупке уходят).
	• Значки (BadgeService): ID вписываются в Shared.BADGES, 0 = ещё не создан.
	• Обучение: атрибут игрока TutorialStep, текст рисует ClubUI.client.lua.
==========================================================================]]

local AnalyticsService = game:GetService("AnalyticsService")
local BadgeService     = game:GetService("BadgeService")
local Players          = game:GetService("Players")
local Shared = require(game:GetService("ReplicatedStorage"):WaitForChild("ClubShared"))

local A = {}

local function balance(player)
	local ls = player:FindFirstChild("leaderstats")
	local c = ls and ls:FindFirstChild("Coins")
	return c and c.Value or 0
end

--=========================================================================
-- Обучение и онбординг (только для новичков: атрибут NewPlayer)
--=========================================================================
-- шаги воронки новичка; номер = порядок, считается один раз
A.ONBOARDING = {
	"Joined",          -- 1 получил клуб
	"FreeDesk",        -- 2 встал на кнопку FREE — стойка админа (с неё идут монеты)
	"FirstCoin",       -- 3 собрал монету
	"FirstPC",         -- 4 купил первый ПК
	"Purchase5",       -- 5 пять покупок
	"Walls",           -- 6 стены клуба (≈ 3–4 минута)
	"Purchase15",      -- 7
	"Purchase30",      -- 8 половина этажа
	"Floor1Done",      -- 9 весь этаж
}
local STEP_INDEX = {}
for i, name in ipairs(A.ONBOARDING) do STEP_INDEX[name] = i end

local done = {}   -- [player] = { [step] = true }

function A.step(player, name)
	if not player:GetAttribute("NewPlayer") then return end
	local i = STEP_INDEX[name]
	done[player] = done[player] or {}
	if not i or done[player][name] then return end
	done[player][name] = true
	pcall(function() AnalyticsService:LogOnboardingStepEvent(player, i, name) end)
	-- экранное обучение: TutorialStep = следующий шаг (2 — кнопка FREE,
	-- 3 — собери монеты, 4 — купи ПК, 5 — готово)
	if i <= 4 then
		local cur = player:GetAttribute("TutorialStep") or 0
		if i + 1 > cur then player:SetAttribute("TutorialStep", i + 1) end
	end
end

--=========================================================================
-- Экономика: копим и отправляем раз в минуту
--=========================================================================
-- kind: "Income", "Minigame", "Chest", "Glider", "Daily", "RobuxPack", "Click"
-- для трат: "ClubItem", "PCUpgrade", "Lemonade"
local TX = {
	Income = "Gameplay", Click = "Gameplay", Minigame = "Gameplay", Chest = "Gameplay", Glider = "Gameplay",
	Daily = "TimedReward", RobuxPack = "IAP", ClubItem = "Shop", PCUpgrade = "Shop", Lemonade = "Shop",
}
local pending = {}   -- [player] = { ["Source|Income"] = сумма }

local function add(player, flow, kind, amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then return end
	pending[player] = pending[player] or {}
	local key = flow .. "|" .. kind
	pending[player][key] = (pending[player][key] or 0) + amount
end
function A.source(player, amount, kind) add(player, "Source", kind, amount) end
function A.sink(player, amount, kind) add(player, "Sink", kind, amount) end

local function flush(player)
	local list = pending[player]
	pending[player] = nil
	if not list then return end
	for key, amount in pairs(list) do
		local flow, kind = key:match("^(%a+)|(%a+)$")
		pcall(function()
			AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType[flow], "Coins", amount, balance(player),
				Enum.AnalyticsEconomyTransactionType[TX[kind] or "Gameplay"].Name, kind)
		end)
	end
end

task.spawn(function()
	while true do
		task.wait(60)
		for _, p in ipairs(Players:GetPlayers()) do flush(p) end
	end
end)

--=========================================================================
-- Любое событие: покупка №N, параплан, мини-игра и т.д.
--=========================================================================
function A.event(player, name, value)
	pcall(function() AnalyticsService:LogCustomEvent(player, name, value or 1) end)
end

--=========================================================================
-- Значки
--=========================================================================
function A.badge(player, key)
	local id = Shared.BADGES and Shared.BADGES[key]
	if not id or id == 0 then return end
	task.spawn(function()
		local ok, has = pcall(function() return BadgeService:UserHasBadgeAsync(player.UserId, id) end)
		if ok and not has then
			pcall(function() BadgeService:AwardBadge(player.UserId, id) end)
		end
	end)
end

Players.PlayerRemoving:Connect(function(p)
	flush(p)
	done[p] = nil
end)

return A
