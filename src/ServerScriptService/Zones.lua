--[[=========================================================================
	ЗОНЫ ЗА ДВЕРЯМИ КЛУБА: Мастерская, дальше — другие миры.
	Каждая зона — отдельная комната далеко от города (высоко в небе).
	Дверь в клубе переносит игрока в зону, дверь «Назад» — туда, откуда пришёл.
	Атрибут игрока Zone = имя зоны (пока он там), клиенту — для света и звуков.
==========================================================================]]

local Players = game:GetService("Players")

local Zones = {
	-- где стоит каждая зона (центр пола)
	ORIGINS = {
		workshop = CFrame.new(-3000, 800, 0),
	},
	spots = {},   -- имя -> где появляется игрок
	back = {},    -- игрок -> куда вернуть
}

function Zones.register(name, cf)
	Zones.spots[name] = cf
end

local function move(player, cf)
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return false end
	-- мир приходит игроку по частям: сначала просим прогрузить место
	pcall(function() player:RequestStreamAroundAsync(cf.Position, 5) end)
	char:PivotTo(cf)
	return true
end

function Zones.enter(player, name, backCF)
	local cf = Zones.spots[name]
	if not cf then return end
	Zones.back[player] = backCF
	if move(player, cf) then player:SetAttribute("Zone", name) end
end

function Zones.leave(player)
	local cf = Zones.back[player]
	Zones.back[player] = nil
	player:SetAttribute("Zone", nil)
	if cf then move(player, cf) end
end

local function watch(player)
	-- новый персонаж появляется у клуба — значит, он уже не в зоне
	player.CharacterAdded:Connect(function() player:SetAttribute("Zone", nil) end)
end
Players.PlayerAdded:Connect(watch)
for _, p in ipairs(Players:GetPlayers()) do watch(p) end
Players.PlayerRemoving:Connect(function(p) Zones.back[p] = nil end)

return Zones
