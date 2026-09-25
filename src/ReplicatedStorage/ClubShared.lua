--[[=========================================================================
	ОБЩИЕ НАСТРОЙКИ (видят и сервер, и меню игрока)
	Геймпассы, пачки монет за Robux, уровни компов, ежедневные награды.
==========================================================================]]

local Shared = {}

-- Геймпассы (разовая покупка). id = 0 — ещё не создан на сайте Roblox.
-- Создать: create.roblox.com -> игра -> Monetization -> Passes.
Shared.GAMEPASSES = {
	{ key = "autocollect", id = 1998614421, price = 99,  icon = "🎒",
	  ru = { "Авто-сбор", "Монеты сами летят\nв карман" },
	  en = { "Auto Collect", "Coins go straight\nto your wallet" } },
	{ key = "doublecash",  id = 1998626423, price = 249, icon = "💰",
	  ru = { "x2 денег", "Весь доход\nнавсегда x2!" },
	  en = { "x2 Cash", "Double income\nforever!" } },
	{ key = "speed",       id = 1998992427, price = 49,  icon = "⚡",
	  ru = { "Быстрый бег", "Бегаешь в 1.7 раза\nбыстрее" },
	  en = { "Speed Boost", "Run 1.7x\nfaster" } },
	{ key = "pet",         id = 1998884429, price = 149, icon = "🤖",
	  ru = { "Робо-дрон", "Летает за тобой\nи светится!" },
	  en = { "Robo Drone", "Follows you\nand glows!" } },
}

-- Пачки монет (можно покупать много раз) = доход клуба за N минут.
-- Создать: Monetization -> Developer Products. id = 0 — ещё не создан.
Shared.COIN_PACKS = {
	{ id = 3714708765, price = 19,  minutes = 15,   icon = "💵", ru = "Доход за 15 минут", en = "15 min of income" },
	{ id = 3714708811, price = 59,  minutes = 60,   icon = "💵", ru = "Доход за 1 час",    en = "1 hour of income" },
	{ id = 3714708857, price = 279, minutes = 360,  icon = "💰", ru = "Доход за 6 часов",  en = "6 hours of income" },
	{ id = 3714708900, price = 849, minutes = 1440, icon = "🏦", ru = "Доход за 24 часа",  en = "24 hours of income" },
}

-- Уровни компьютеров: каждый умножает доход всех ПК и меняет их вид
Shared.PC_TIERS = {
	{ ru = "Обычные",       en = "Basic",     mult = 1, cost = 0,       color = Color3.fromRGB(200, 60, 80) },
	{ ru = "RGB-геймерские", en = "RGB Gamer", mult = 2, cost = 5000,    color = Color3.fromRGB(80, 255, 140) },
	{ ru = "Про-станции",   en = "Pro",       mult = 3, cost = 60000,   color = Color3.fromRGB(255, 200, 60) },
	{ ru = "Легендарные",   en = "Legendary", mult = 5, cost = 400000,  color = Color3.fromRGB(90, 220, 255) },
}

-- Ежедневные награды: доход клуба за N минут (минимум 100 монет)
Shared.DAILY = {
	{ minutes = 5 }, { minutes = 10 }, { minutes = 20 }, { minutes = 30 },
	{ minutes = 60 }, { minutes = 90 }, { minutes = 180 },
}
Shared.DAILY_COOLDOWN = 20 * 3600    -- забирать можно раз в 20 часов
Shared.DAILY_RESET    = 48 * 3600    -- пропустил 2 дня — серия с начала

-- Лимонады: сколько энергии дают, цена = доход за N секунд (в клубе x3)
Shared.LEMONADES = {
	{ order = 1, key = "lemon", ru = "Лимонад",         en = "Lemonade",       energy = 25,  seconds = 5,  minPrice = 10, color = Color3.fromRGB(255, 235, 80) },
	{ order = 2, key = "berry", ru = "Ягодный лимонад", en = "Berry Lemonade", energy = 50,  seconds = 9,  minPrice = 20, color = Color3.fromRGB(230, 60, 140) },
	{ order = 3, key = "mega",  ru = "Мега-лимонад",    en = "Mega Lemonade",  energy = 100, seconds = 16, minPrice = 35, color = Color3.fromRGB(80, 220, 255) },
}

return Shared
