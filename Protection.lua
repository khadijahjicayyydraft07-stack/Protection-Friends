-- // Combat AI | Jujutsu Shenanigans
-- // T=Nama Target | Y=Start/Stop

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local PFS = game:GetService("PathfindingService")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local root = char:WaitForChild("HumanoidRootPart")
local cam = workspace.CurrentCamera

player.CharacterAdded:Connect(function(c)
	char = c
	hum = c:WaitForChild("Humanoid")
	root = c:WaitForChild("HumanoidRootPart")
end)

-- GUI
local pg = player:WaitForChild("PlayerGui")
if pg:FindFirstChild("CombatGUI") then pg:FindFirstChild("CombatGUI"):Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "CombatGUI"
gui.ResetOnSpawn = false
gui.Parent = pg

local ind = Instance.new("TextLabel", gui)
ind.Size = UDim2.new(0, 220, 0, 30)
ind.Position = UDim2.new(0, 10, 1, -42)
ind.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
ind.BorderSizePixel = 0
ind.Text = "⚔️ COMBAT: OFF"
ind.TextColor3 = Color3.fromRGB(160, 160, 160)
ind.TextScaled = true
ind.Font = Enum.Font.GothamBold
Instance.new("UICorner", ind).CornerRadius = UDim.new(0, 7)

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 300, 0, 90)
frame.Position = UDim2.new(0.5, -150, 1, -110)
frame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
frame.BorderSizePixel = 0
frame.Visible = false
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", frame).Color = Color3.fromRGB(255, 60, 60)

local tlabel = Instance.new("TextLabel", frame)
tlabel.Size = UDim2.new(1, 0, 0, 25)
tlabel.BackgroundTransparency = 1
tlabel.Text = "⚔️ Ketik nama musuh"
tlabel.TextColor3 = Color3.fromRGB(255, 60, 60)
tlabel.TextScaled = true
tlabel.Font = Enum.Font.GothamBold

local tinput = Instance.new("TextBox", frame)
tinput.Size = UDim2.new(1, -20, 0, 32)
tinput.Position = UDim2.new(0, 10, 0, 28)
tinput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
tinput.BorderSizePixel = 0
tinput.Text = ""
tinput.PlaceholderText = "Nama player / NPC..."
tinput.PlaceholderColor3 = Color3.fromRGB(90, 90, 90)
tinput.TextColor3 = Color3.fromRGB(255, 255, 255)
tinput.TextScaled = true
tinput.Font = Enum.Font.Gotham
tinput.ClearTextOnFocus = false
Instance.new("UICorner", tinput).CornerRadius = UDim.new(0, 6)

local tstatus = Instance.new("TextLabel", frame)
tstatus.Size = UDim2.new(1, -20, 0, 22)
tstatus.Position = UDim2.new(0, 10, 0, 63)
tstatus.BackgroundTransparency = 1
tstatus.Text = ""
tstatus.TextColor3 = Color3.fromRGB(200, 200, 200)
tstatus.TextScaled = true
tstatus.Font = Enum.Font.Gotham
tstatus.TextXAlignment = Enum.TextXAlignment.Left

-- STATE
local running = false
local loopThread = nil
local targetChar = nil
local targetName = ""
local lastHP = 100
local blocking = false

local function stop()
	running = false
	if loopThread then task.cancel(loopThread) loopThread = nil end
	hum.WalkSpeed = 16
	ind.Text = "⚔️ COMBAT: OFF"
	ind.TextColor3 = Color3.fromRGB(160, 160, 160)
	frame.Visible = false
end

-- AUTO AIM KAMERA
local function aimAt(targetRoot)
	if not targetRoot then return end
	local dir = (targetRoot.Position - cam.CFrame.Position).Unit
	cam.CFrame = CFrame.new(cam.CFrame.Position, cam.CFrame.Position + dir)
end

-- AUTO M1
local function doM1()
	-- Simulate left click
	local ms = player:GetMouse()
	fireclickdetector = fireclickdetector or function() end
	-- Pakai mouse button down event
	mouse1click = mouse1click or function() end
	pcall(function()
		mouse1press()
		task.wait(0.1)
		mouse1release()
	end)
end

-- AUTO BLOCK
local function doBlock(state)
	blocking = state
	pcall(function()
		if state then
			keypress(0x46) -- F key
		else
			keyrelease(0x46)
		end
	end)
end

-- AUTO DASH
local dashCooldown = false
local function doDash(dir)
	if dashCooldown then return end
	dashCooldown = true
	local dashKeys = {
		front = 0x57,  -- W
		back = 0x53,   -- S
		left = 0x41,   -- A
		right = 0x44,  -- D
	}
	local key = dashKeys[dir]
	if key then
		pcall(function()
			keypress(key)
			task.wait(0.05)
			keypress(key) -- double tap = dash
			task.wait(0.1)
			keyrelease(key)
		end)
	end
	task.delay(0.8, function() dashCooldown = false end)
end

-- DETEKSI MUSUH ATTACK (HP turun)
local function detectIncoming()
	local currentHP = hum and hum.Health or 100
	if currentHP < lastHP - 1 then
		lastHP = currentHP
		return true
	end
	lastHP = currentHP
	return false
end

-- PATHFIND
local function getPath(dest)
	local path = PFS:CreatePath({
		AgentRadius = 1,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentCanClimb = true,
		WaypointSpacing = 1.5,
	})
	local ok = pcall(function() path:ComputeAsync(root.Position, dest) end)
	if ok and path.Status == Enum.PathStatus.Success then
		return path:GetWaypoints()
	end
	return nil
end

-- CARI TARGET
local function findTarget(name)
	name = name:lower()
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():find(name) and p ~= player then
			local c = p.Character
			if c and c:FindFirstChild("HumanoidRootPart") then
				return p.Name, c
			end
		end
	end
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj.Name:lower():find(name) and obj ~= char then
			if obj:FindFirstChild("HumanoidRootPart") and obj:FindFirstChildOfClass("Humanoid") then
				return obj.Name, obj
			end
		end
	end
	return nil, nil
end

-- MAIN COMBAT LOOP
local function startCombat()
	if not targetChar then return end
	running = true
	hum.WalkSpeed = 24
	ind.Text = "⚔️ " .. targetName
	ind.TextColor3 = Color3.fromRGB(255, 60, 60)

	local wps, wi = nil, 1
	local lastDest = Vector3.zero
	local recompTimer = 0
	local stuckPos = root.Position
	local stuckT = 0
	local m1Timer = 0
	local dashTimer = 0

	loopThread = task.spawn(function()
		while running do
			local hrp = targetChar:FindFirstChild("HumanoidRootPart")
			local th = targetChar:FindFirstChildOfClass("Humanoid")
			if not hrp or not targetChar.Parent or (th and th.Health <= 0) then
				tstatus.Text = "☠️ " .. targetName .. " mati!"
				tstatus.TextColor3 = Color3.fromRGB(100, 255, 180)
				stop() break
			end

			local dest = hrp.Position
			local myXZ = Vector2.new(root.Position.X, root.Position.Z)
			local dXZ = Vector2.new(dest.X, dest.Z)
			local dist = (myXZ - dXZ).Magnitude

			-- ✅ AUTO AIM KAMERA ke musuh
			aimAt(hrp)

			-- Update status
			tstatus.Text = "⚔️ " .. targetName .. " | " .. math.floor(dist) .. " stud"
			tstatus.TextColor3 = Color3.fromRGB(255, 150, 0)

			-- ✅ AUTO BLOCK kalau kena hit
			if detectIncoming() then
				tstatus.Text = "🛡️ BLOCKING!"
				tstatus.TextColor3 = Color3.fromRGB(0, 200, 255)
				doBlock(true)
				-- Random dash buat dodge
				local dirs = {"left", "right", "back"}
				doDash(dirs[math.random(1, #dirs)])
				task.wait(0.4)
				doBlock(false)
			end

			-- ✅ AUTO M1 kalau deket
			m1Timer -= 0.05
			if dist < 6 and m1Timer <= 0 then
				m1Timer = 0.35 -- attack tiap 0.35 detik
				tstatus.Text = "👊 M1! " .. targetName
				tstatus.TextColor3 = Color3.fromRGB(255, 60, 60)
				doM1()
			end

			-- ✅ AUTO DASH ke depan kalau jauh
			dashTimer -= 0.05
			if dist > 15 and dashTimer <= 0 then
				dashTimer = 2
				doDash("front")
			end

			-- PATHFIND
			if dist > 5 then
				recompTimer -= 0.05
				local destMoved = (dest - lastDest).Magnitude
				if destMoved > 4 or wps == nil or recompTimer <= 0 then
					lastDest = dest
					recompTimer = 1.5
					local newWps = getPath(dest)
					if newWps and #newWps > 1 then
						wps = newWps
						wi = 2
					end
				end

				if wps and wi <= #wps then
					local wpXZ = Vector2.new(wps[wi].Position.X, wps[wi].Position.Z)
					if (myXZ - wpXZ).Magnitude < 3 then wi += 1 end
				end

				local target = dest
				if wps and wi <= #wps then
					local aw = wps[wi]
					if aw.Position.Y - root.Position.Y > 0.7 then hum.Jump = true end
					if aw.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
					target = aw.Position
				end
				hum:MoveTo(target)

				if (root.Position - stuckPos).Magnitude < 0.5 then
					stuckT += 0.05
					if stuckT > 1.5 then hum.Jump = true wps = nil stuckT = 0 end
				else stuckT = 0 stuckPos = root.Position end
			else
				-- Deket → hadap musuh terus
				root.CFrame = CFrame.new(root.Position, Vector3.new(hrp.Position.X, root.Position.Y, hrp.Position.Z))
			end

			task.wait(0.05)
		end
	end)
end

-- TOMBOL
UIS.InputBegan:Connect(function(key, gp)
	if gp then return end
	if key.KeyCode == Enum.KeyCode.T then
		stop()
		frame.Visible = not frame.Visible
		if frame.Visible then
			tinput.Text = ""
			tinput:CaptureFocus()
			tstatus.Text = "Ketik nama musuh lalu Enter"
			tstatus.TextColor3 = Color3.fromRGB(160, 160, 160)
		end
	elseif key.KeyCode == Enum.KeyCode.Y then
		if running then stop()
		else
			if targetChar then startCombat()
			else
				frame.Visible = true
				tstatus.Text = "⚠️ Tulis nama dulu! (T)"
				tstatus.TextColor3 = Color3.fromRGB(255, 200, 0)
			end
		end
	end
end)

tinput.FocusLost:Connect(function(enter)
	if not enter then return end
	local name = tinput.Text:match("^%s*(.-)%s*$")
	if name == "" then return end
	local found, foundChar = findTarget(name)
	if found then
		targetName = found
		targetChar = foundChar
		tstatus.Text = "✅ Target: " .. found .. " | Y = Serang!"
		tstatus.TextColor3 = Color3.fromRGB(0, 220, 100)
	else
		tstatus.Text = "❌ '" .. name .. "' gak ada!"
		tstatus.TextColor3 = Color3.fromRGB(255, 80, 80)
		targetChar = nil
	end
end)

print("[Combat AI] ✅ T=Nama | Y=Start/Stop | Auto M1+Block+Dash+Aim")
