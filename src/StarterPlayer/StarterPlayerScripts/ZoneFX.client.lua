-- Свет в мирах за дверями клуба: пока игрок в зоне (атрибут Zone), экран подкрашивается.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer

local TINTS = {
	computer = { tint = Color3.fromRGB(170, 240, 255), contrast = 0.25, saturation = 0.4 },
	space    = { tint = Color3.fromRGB(220, 215, 255), contrast = 0.15, saturation = 0.1, gravity = 45 },
}
local NORMAL_GRAVITY = workspace.Gravity

local fx = Instance.new("ColorCorrectionEffect")
fx.Name = "ЗонаЦвет"
fx.Enabled = false
fx.Parent = Lighting

local function apply()
	local t = TINTS[player:GetAttribute("Zone") or ""]
	fx.Enabled = t ~= nil
	workspace.Gravity = t and t.gravity or NORMAL_GRAVITY   -- в космосе прыгаешь высоко
	if t then
		fx.TintColor = t.tint
		fx.Contrast = t.contrast
		fx.Saturation = t.saturation
	end
end
player:GetAttributeChangedSignal("Zone"):Connect(apply)
apply()
