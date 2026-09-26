--[[ ПАРАШЮТ: взял на крыше башни, прыгнул — купол раскрывается,
     падаешь медленно и можешь рулить. После приземления исчезает. ]]

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local isRu = player.LocaleId:sub(1, 2) == "ru"

local ready = false
local open = nil   -- { canopy, force }

local function closeChute()
	if not open then return end
	for _, p in ipairs(open.parts) do p:Destroy() end
	if open.force then open.force:Destroy() end
	open = nil
end

local function openChute(root)
	local parts = {}
	local function mk(size, offset, color, shape)
		local p = Instance.new("Part")
		p.Size, p.Color, p.Material = size, color, Enum.Material.Fabric
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
		if shape then p.Shape = shape end
		p.CFrame = root.CFrame * offset
		p.Parent = workspace
		local w = Instance.new("WeldConstraint") w.Part0, w.Part1 = root, p w.Parent = p
		table.insert(parts, p)
		return p
	end
	local colors = { Color3.fromRGB(230, 60, 60), Color3.fromRGB(255, 255, 255), Color3.fromRGB(40, 120, 230) }
	for i = -2, 2 do   -- купол из полос
		mk(Vector3.new(3, 0.5, 9), CFrame.new(i * 2.9, 9 - math.abs(i) * 0.7, 0) * CFrame.Angles(0, 0, math.rad(-i * 12)), colors[(i + 3) % 3 + 1])
	end
	for _, x in ipairs({ -6, 6 }) do   -- стропы
		mk(Vector3.new(0.1, 8, 0.1), CFrame.new(x * 0.6, 4.5, 0) * CFrame.Angles(0, 0, math.rad(x * 3)), Color3.fromRGB(230, 230, 230))
	end
	local att = root:FindFirstChild("RootAttachment") or Instance.new("Attachment", root)
	local force = Instance.new("VectorForce")
	force.Attachment0 = att
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.Parent = root
	open = { parts = parts, force = force }
end

player:GetAttributeChangedSignal("Parachute"):Connect(function()
	if player:GetAttribute("Parachute") then
		ready = true
		local hint = Instance.new("Hint")
		hint.Text = isRu and "🪂 Парашют взят! Прыгай с крыши — он раскроется сам." or "🪂 Got a parachute! Jump off the roof — it opens automatically."
		hint.Parent = workspace
		task.delay(4, function() hint:Destroy() end)
	end
end)

RunService.Heartbeat:Connect(function()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root then return end
	local falling = hum:GetState() == Enum.HumanoidStateType.Freefall and root.AssemblyLinearVelocity.Y < -20
	if ready and not open and falling then
		openChute(root)
	end
	if open then
		-- сопротивление воздуха: скорость падения около 12
		local mass = root.AssemblyMass
		local vy = root.AssemblyLinearVelocity.Y
		local up = mass * workspace.Gravity + math.max(0, -vy - 12) * mass * 8
		open.force.Force = Vector3.new(0, up, 0)
		if hum.FloorMaterial ~= Enum.Material.Air then
			closeChute()
			ready = false
		end
	end
end)
