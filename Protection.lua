-- // Protect Team | By AI
-- // T = Input nama teman | Y = ON/OFF Protect

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local PFS = game:GetService("PathfindingService")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local root = char:WaitForChild("HumanoidRootPart")

player.CharacterAdded:Connect(function(c)
	char = c
	hum = c:WaitForChild("Humanoid")
	root = c:WaitForChild("HumanoidRootPart")
end)

-- GUI
local pg = player:WaitForChild("PlayerGui")
if pg:FindFirstChild("PTGui") then pg:FindFirstChild("PTGui"):Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "PTGui"
gui.ResetOnSpawn = false
gui.Parent = pg

local ind = Instance.new("TextLabel", gui)
ind.Size = UDim2.new(0, 220, 0, 30)
ind.Position = UDim2.new(0, 10, 1, -42)
ind.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
ind.BorderSizePixel = 0
ind.Text = "🛡️ PROTECT: OFF"
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
local fStr = Instance.new("UIStroke", frame)
fStr.Color = Color3.fromRGB(0, 180, 255)
fStr.Thickness = 2

local flabel = Instance.new("TextLabel", frame)
flabel.Size = UDim2.new(1, 0, 0, 25)
flabel.BackgroundTransparency = 1
flabel.Text = "🛡️ Ketik nama teman"
flabel.TextColor3 = Color3.fromRGB(0, 180, 255)
flabel.TextScaled = true
flabel.Font = Enum.Font.GothamBold

local finput = Instance.new("TextBox", frame)
finput.Size = UDim2.new(1, -20, 0, 32)
finput.Position = UDim2.new(0, 10, 0, 28)
finput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
finput.BorderSizePixel = 0
finput.Text = ""
finput.PlaceholderText = "Nama teman (contoh: Faizul)"
finput.PlaceholderColor3 = Color3.fromRGB(90, 90, 90)
finput.TextColor3 = Color3.fromRGB(255, 255, 255)
finput.TextScaled = true
finput.Font = Enum.Font.Gotham
finput.ClearTextOnFocus = false
Instance.new("UICorner", finput).CornerRadius = UDim.new(0, 6)

local fstatus = Instance.new("TextLabel", frame)
fstatus.Size = UDim2.new(1, -20, 0, 22)
fstatus.Position = UDim2.new(0, 10, 0, 63)
fstatus.BackgroundTransparency = 1
fstatus.Text = ""
fstatus.TextColor3 = Color3.fromRGB(200, 200, 200)
fstatus.TextScaled = true
fstatus.Font = Enum.Font.Gotham
fstatus.TextXAlignment = Enum.TextXAlignment.Left

-- STATE
local running = false
local loopThread = nil
local friendChar = nil
local friendName = ""

local function stop()
	running = false
	if loopThread then task.cancel(loopThread) loopThread = nil end
	hum.WalkSpeed = 16
	ind.Text = "🛡️ PROTECT: OFF"
	ind.TextColor3 = Color3.fromRGB(160, 160, 160)
end

-- PATH
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

-- PROTECT LOOP
local function startProtect()
	if not friendChar then return end
	running = true
	hum.WalkSpeed = 24
	ind.Text = "🛡️ PROTECT: " .. friendName
	ind.TextColor3 = Color3.fromRGB(0, 180, 255)

	local wps = nil
	local wi = 1
	local lastDest = Vector3.zero
	local recompTimer = 0
	local stuckPos = root.Position
	local stuckT = 0

	loopThread = task.spawn(function()
		while running do
			local hrp = friendChar:FindFirstChild("HumanoidRootPart")
			if not hrp or not friendChar.Parent then
				fstatus.Text = "❌ " .. friendName .. " hilang!"
				fstatus.TextColor3 = Color3.fromRGB(255, 80, 80)
				stop() break
			end

			local dest = hrp.Position
			local myXZ = Vector2.new(root.Position.X, root.Position.Z)
			local dXZ = Vector2.new(dest.X, dest.Z)
			local dist = (myXZ - dXZ).Magnitude

			-- Update status
			local dots = math.floor(tick() * 2) % 3 + 1
			fstatus.Text = "🔵 " .. friendName .. string.rep(".", dots) .. " " .. math.floor(dist) .. " stud"
			fstatus.TextColor3 = Color3.fromRGB(0, 200, 255)
			ind.Text = "🛡️ " .. friendName .. " | " .. math.floor(dist) .. "s"

			-- Kalau udah deket 10 stud, berhenti
			if dist < 10 then
				hum:MoveTo(root.Position) -- diam di tempat
				stuckT = 0
				stuckPos = root.Position
				task.wait(0.05)
				continue
			end

			-- Recompute tiap 2 detik
			recompTimer -= 0.05
			local destMoved = (dest - lastDest).Magnitude
			if destMoved > 5 or wps == nil or recompTimer <= 0 then
				lastDest = dest
				recompTimer = 2
				local newWps = getPath(dest)
				if newWps and #newWps > 1 then
					wps = newWps
					wi = 2
				end
			end

			-- Maju waypoint (2D XZ)
			if wps and wi <= #wps then
				local wpXZ = Vector2.new(wps[wi].Position.X, wps[wi].Position.Z)
				if (myXZ - wpXZ).Magnitude < 3 then
					wi += 1
				end
			end

			-- Target
			local target = dest
			if wps and wi <= #wps then
				local aw = wps[wi]
				if aw.Position.Y - root.Position.Y > 0.7 then hum.Jump = true end
				if aw.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
				target = aw.Position
			end

			hum:MoveTo(target)

			-- Stuck
			if (root.Position - stuckPos).Magnitude < 0.5 then
				stuckT += 0.05
				if stuckT > 1.5 then
					hum.Jump = true
					wps = nil
					stuckT = 0
				end
			else
				stuckT = 0
				stuckPos = root.Position
			end

			task.wait(0.05)
		end
	end)
end

-- CARI TEMAN
local function findFriend(name)
	name = name:lower()
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():find(name) and p ~= player then
			local c = p.Character
			if c and c:FindFirstChild("HumanoidRootPart") then
				return p.Name, c
			end
		end
	end
	return nil, nil
end

-- TOMBOL
UIS.InputBegan:Connect(function(key, gp)
	if gp then return end
	if key.KeyCode == Enum.KeyCode.T then
		stop()
		frame.Visible = not frame.Visible
		if frame.Visible then
			finput.Text = ""
			finput:CaptureFocus()
			fstatus.Text = "Ketik nama teman lalu Enter"
			fstatus.TextColor3 = Color3.fromRGB(160, 160, 160)
		end
	elseif key.KeyCode == Enum.KeyCode.Y then
		if running then
			stop()
			frame.Visible = false
		else
			if friendChar then
				frame.Visible = true
				startProtect()
			else
				frame.Visible = true
				finput:CaptureFocus()
				fstatus.Text = "⚠️ Tulis nama dulu! (T)"
				fstatus.TextColor3 = Color3.fromRGB(255, 200, 0)
			end
		end
	end
end)

finput.FocusLost:Connect(function(enter)
	if not enter then return end
	local name = finput.Text:match("^%s*(.-)%s*$")
	if name == "" then return end
	local found, foundChar = findFriend(name)
	if found then
		friendName = found
		friendChar = foundChar
		fstatus.Text = "✅ Ketemu " .. found .. "! Y = Start"
		fstatus.TextColor3 = Color3.fromRGB(0, 220, 100)
		fStr.Color = Color3.fromRGB(0, 220, 100)
	else
		fstatus.Text = "❌ '" .. name .. "' gak ada!"
		fstatus.TextColor3 = Color3.fromRGB(255, 80, 80)
		friendChar = nil
	end
end)

print("[Protect Team] ✅ T = Input nama | Y = Start/Stop")
