-- // Auto Block | Jujutsu Shenanigans
-- // Deteksi musuh attack → auto press F (block)
-- // Press B = ON/OFF

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")
local hum = char:WaitForChild("Humanoid")

player.CharacterAdded:Connect(function(c)
	char = c
	root = c:WaitForChild("HumanoidRootPart")
	hum = c:WaitForChild("Humanoid")
end)

-- ============================================================
-- GUI
-- ============================================================
local pg = player:WaitForChild("PlayerGui")
if pg:FindFirstChild("ABGui") then pg:FindFirstChild("ABGui"):Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "ABGui"
gui.ResetOnSpawn = false
gui.Parent = pg

local ind = Instance.new("TextLabel", gui)
ind.Size = UDim2.new(0, 200, 0, 30)
ind.Position = UDim2.new(0, 10, 0, 10)
ind.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
ind.BorderSizePixel = 0
ind.Text = "🛡️ AutoBlock: OFF"
ind.TextColor3 = Color3.fromRGB(160, 160, 160)
ind.TextScaled = true
ind.Font = Enum.Font.GothamBold
Instance.new("UICorner", ind).CornerRadius = UDim.new(0, 7)

local statusInd = Instance.new("TextLabel", gui)
statusInd.Size = UDim2.new(0, 200, 0, 24)
statusInd.Position = UDim2.new(0, 10, 0, 45)
statusInd.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
statusInd.BorderSizePixel = 0
statusInd.Text = "👁 Scanning..."
statusInd.TextColor3 = Color3.fromRGB(120, 120, 120)
statusInd.TextScaled = true
statusInd.Font = Enum.Font.Gotham
Instance.new("UICorner", statusInd).CornerRadius = UDim.new(0, 7)

-- ============================================================
-- STATE
-- ============================================================
local active = false
local blocking = false
local blockThread = nil
local lastHP = 100

-- ============================================================
-- BLOCK FUNCTION
-- Simulate tekan F
-- ============================================================
local function pressBlock()
	if blocking then return end
	blocking = true

	-- Simulate F key press
	local args = {
		[1] = Enum.KeyCode.F
	}
	-- Trigger via UIS simulation
	game:GetService("VirtualInputManager"):SendKeyEvent(true, Enum.KeyCode.F, false, game)
	task.wait(0.5) -- tahan block 0.5 detik
	game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.F, false, game)

	blocking = false
end

-- ============================================================
-- DETEKSI MUSUH ATTACK
-- Cara 1: Deteksi HP turun (paling reliable!)
-- Cara 2: Deteksi animasi attack musuh terdekat
-- ============================================================
local function getNearestEnemy()
	local closest, bestDist = nil, math.huge
	for _, p in ipairs(Players:GetPlayers()) do
		if p == player then continue end
		local c = p.Character
		if not c then continue end
		local hrp = c:FindFirstChild("HumanoidRootPart")
		local h = c:FindFirstChildOfClass("Humanoid")
		if hrp and h and h.Health > 0 then
			local d = (root.Position - hrp.Position).Magnitude
			if d < bestDist then
				closest = c
				bestDist = d
			end
		end
	end
	return closest, bestDist
end

local function isEnemyAttacking(enemyChar)
	if not enemyChar then return false end
	-- Cek animasi attack lewat AnimationTrack
	local animator = enemyChar:FindFirstChildOfClass("Humanoid") and
		enemyChar:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator")
	if not animator then return false end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		local name = track.Name:lower()
		-- Deteksi nama animasi yang mengandung kata attack/punch/hit/slash
		if name:find("attack") or name:find("punch") or name:find("hit")
			or name:find("slash") or name:find("strike") or name:find("swing") then
			return true
		end
	end
	return false
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
local function startAutoBlock()
	active = true
	ind.Text = "🛡️ AutoBlock: ON"
	ind.TextColor3 = Color3.fromRGB(0, 220, 100)
	lastHP = hum and hum.Health or 100

	blockThread = task.spawn(function()
		while active do
			local enemy, dist = getNearestEnemy()

			if enemy and dist < 20 then
				-- Cek 1: HP turun → langsung block!
				local currentHP = hum and hum.Health or 100
				if currentHP < lastHP then
					statusInd.Text = "⚠️ HIT! Blocking!"
					statusInd.TextColor3 = Color3.fromRGB(255, 80, 80)
					task.spawn(pressBlock)
				end
				lastHP = currentHP

				-- Cek 2: Animasi attack musuh terdekat
				if isEnemyAttacking(enemy) then
					statusInd.Text = "⚔️ Attack detect! Block!"
					statusInd.TextColor3 = Color3.fromRGB(255, 150, 0)
					task.spawn(pressBlock)
				else
					statusInd.Text = "👁 " .. enemy.Name .. " " .. math.floor(dist) .. "s"
					statusInd.TextColor3 = Color3.fromRGB(200, 200, 100)
				end
			else
				lastHP = hum and hum.Health or 100
				statusInd.Text = "👁 Gak ada musuh"
				statusInd.TextColor3 = Color3.fromRGB(120, 120, 120)
			end

			task.wait(0.05) -- cek tiap 0.05 detik = super cepet!
		end
	end)
end

local function stopAutoBlock()
	active = false
	blocking = false
	if blockThread then task.cancel(blockThread) blockThread = nil end
	ind.Text = "🛡️ AutoBlock: OFF"
	ind.TextColor3 = Color3.fromRGB(160, 160, 160)
	statusInd.Text = "👁 Scanning..."
	statusInd.TextColor3 = Color3.fromRGB(120, 120, 120)
end

-- ============================================================
-- TOMBOL B = ON/OFF
-- ============================================================
UIS.InputBegan:Connect(function(key, gp)
	if gp then return end
	if key.KeyCode == Enum.KeyCode.T then
		if active then stopAutoBlock() else startAutoBlock() end
	end
end)

print("[AutoBlock] ✅ B = ON/OFF | Auto detect attack & block!")
