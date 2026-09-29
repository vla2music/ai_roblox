-- Скорость на слабых телефонах: мелкие детали не отбрасывают тень.
-- Тени мелочи (кнопки, провода, лампочки, листья) почти не видны, а считать их дорого.
local SMALL = 4 -- студов: всё, что меньше по самой длинной стороне

local function trim(d)
	if d:IsA("BasePart") and d.CastShadow then
		local s = d.Size
		if math.max(s.X, s.Y, s.Z) < SMALL then d.CastShadow = false end
	end
end

workspace.DescendantAdded:Connect(trim)
for _, d in ipairs(workspace:GetDescendants()) do trim(d) end

-- размер детали иногда задаётся уже после появления в мире,
-- поэтому через минуту (мир строится ~30 сек) проходим ещё раз
task.spawn(function()
	task.wait(60)
	local n = 0
	for _, d in ipairs(workspace:GetDescendants()) do
		trim(d)
		n += 1
		if n % 5000 == 0 then task.wait() end
	end
end)
