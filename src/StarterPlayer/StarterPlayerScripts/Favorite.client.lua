--[[ ИЗБРАННОЕ: один раз за сессию, через 8 минут игры, сразу после
     приятного момента (покупка, сундук) Roblox спрашивает «добавить
     игру в избранное?». Избранное сильно влияет на рекомендации Roblox.
     Если игра уже в избранном — не спрашиваем. ]]

local Players             = game:GetService("Players")
local AvatarEditorService = game:GetService("AvatarEditorService")
local player = Players.LocalPlayer

local AFTER = 8 * 60
local t0 = os.clock()
local asked = false

local function alreadyFavorite()
	local ok, fav = pcall(function()
		return AvatarEditorService:GetFavorite(game.PlaceId, Enum.AvatarItemType.Asset)
	end)
	return ok and fav
end

local function maybeAsk()
	if asked or os.clock() - t0 < AFTER or game.PlaceId == 0 then return end
	-- не мешаем полёту и играм в игровом зале
	local pg = player:FindFirstChild("PlayerGui")
	local arcade = pg and pg:FindFirstChild("Arcade")
	if arcade and arcade:FindFirstChildWhichIsA("Frame") and arcade:FindFirstChildWhichIsA("Frame").Visible then return end
	asked = true
	if alreadyFavorite() then return end
	task.wait(1.5)   -- дать порадоваться награде
	pcall(function() AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true) end)
end

-- приятные моменты
player:GetAttributeChangedSignal("NextCost"):Connect(maybeAsk)     -- что-то купил
player:GetAttributeChangedSignal("ChestBonus"):Connect(function()
	if player:GetAttribute("ChestBonus") then maybeAsk() end
end)
