-- ULTIMATE UI: Health List + Death Notif + DEVICE DETECTOR (PC/Hape)
-- LocalScript -> StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- ========== CONFIG ==========
local SEKARAT_THRESHOLD = 16
local FONT = Enum.Font.GothamBold
local CARD_HEIGHT = 50
local VISIBLE_PLAYERS = 5 
-- ============================

local function clamp(v, a, b) if v < a then return a end if v > b then return b end return v end

-- ================= GUI SETUP =================
local pg = LocalPlayer:WaitForChild("PlayerGui")
local gui = pg:FindFirstChild("PlayerHealthUI")
if gui then gui:Destroy() end 

gui = Instance.new("ScreenGui")
gui.Name = "PlayerHealthUI"
gui.ResetOnSpawn = false
gui.Parent = pg

-- 1. SCROLLING FRAME (Daftar Darah - Kiri Atas)
local listContainer = Instance.new("ScrollingFrame")
listContainer.Name = "HealthList"
listContainer.Parent = gui
listContainer.BackgroundTransparency = 1
listContainer.Position = UDim2.new(0, 15, 0, 15)
listContainer.Size = UDim2.new(0, 240, 0, (CARD_HEIGHT * VISIBLE_PLAYERS) + (5 * (VISIBLE_PLAYERS - 1)))
listContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
listContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
listContainer.ScrollBarThickness = 4

local listLayout = Instance.new("UIListLayout")
listLayout.Parent = listContainer
listLayout.Padding = UDim.new(0, 5)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- 2. DEVICE DETECTOR FRAME (Pusat Kendali Perangkat)
local detectorContainer = Instance.new("Frame")
detectorContainer.Name = "DetectorContainer" -- Nama udah diganti bang!
detectorContainer.Parent = gui
detectorContainer.AnchorPoint = Vector2.new(0.5, 0)
detectorContainer.Position = UDim2.new(0.5, 0, 0, 10)
detectorContainer.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
detectorContainer.BackgroundTransparency = 0.3
detectorContainer.Visible = false

local detCorner = Instance.new("UICorner")
detCorner.CornerRadius = UDim.new(0, 8)
detCorner.Parent = detectorContainer

local detLayout = Instance.new("UIGridLayout")
detLayout.Parent = detectorContainer
detLayout.FillDirection = Enum.FillDirection.Horizontal
detLayout.CellSize = UDim2.new(0, 155, 0, 40)
detLayout.CellPadding = UDim2.new(0, 10, 0, 8)
detLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- 3. DEATH NOTIFICATION (Tengah Layar)
local deathFrame = Instance.new("Frame")
deathFrame.Name = "DeathFrame"
deathFrame.Parent = gui
deathFrame.AnchorPoint = Vector2.new(0.5, 0.5)
deathFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
deathFrame.Size = UDim2.new(0, 300, 0, 90)
deathFrame.BackgroundColor3 = Color3.fromRGB(180, 20, 20)
deathFrame.BackgroundTransparency = 1
deathFrame.Visible = false

local deathCorner = Instance.new("UICorner")
deathCorner.CornerRadius = UDim.new(0, 12)
deathCorner.Parent = deathFrame

local deathAvatar = Instance.new("ImageLabel")
deathAvatar.Parent = deathFrame
deathAvatar.Size = UDim2.new(0, 70, 0, 70)
deathAvatar.Position = UDim2.new(0, 10, 0.5, 0)
deathAvatar.AnchorPoint = Vector2.new(0, 0.5)
deathAvatar.BackgroundTransparency = 1
deathAvatar.ImageTransparency = 1
Instance.new("UICorner", deathAvatar).CornerRadius = UDim.new(1, 0)

local deathText = Instance.new("TextLabel")
deathText.Parent = deathFrame
deathText.Size = UDim2.new(1, -90, 1, 0)
deathText.Position = UDim2.new(0, 90, 0, 0)
deathText.BackgroundTransparency = 1
deathText.Font = FONT
deathText.TextSize = 22
deathText.TextColor3 = Color3.fromRGB(255, 255, 255)
deathText.TextTransparency = 1
deathText.Text = "Player Mati"

-- ================= DETECTOR LOGIC =================

local function getDeviceType(p)
	if p == LocalPlayer then
		-- Deteksi asli buat lu sendiri
		if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
			return "Hape", Color3.fromRGB(85, 255, 85) -- Hijau
		elseif UserInputService.GamepadEnabled then
			return "Console", Color3.fromRGB(255, 170, 0) -- Oranye
		else
			return "PC", Color3.fromRGB(85, 255, 255) -- Cyan/Biru Minecraft
		end
	else
		-- Tebakan buat player lain (karena LocalScript)
		-- Lu bisa ganti default ini sesuka hati
		return "PC/Hape", Color3.fromRGB(200, 200, 200) 
	end
end

-- ================= STATE & TRACKING =================
local playerFrames = {} 
local detectorItems = {}
local conns = {}        
local isDeadState = {}

-- ================= FUNCTIONS =================

local function createDetectorItem(p)
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Parent = detectorContainer
	
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.new(0, 30, 0, 30)
	img.Position = UDim2.new(0, 2, 0.5, 0)
	img.AnchorPoint = Vector2.new(0, 0.5)
	img.BackgroundTransparency = 1
	img.Parent = frame
	Instance.new("UICorner", img).CornerRadius = UDim.new(1, 0)
	
	task.spawn(function()
		img.Image = Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
	end)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -35, 1, 0)
	lbl.Position = UDim2.new(0, 35, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = FONT
	lbl.TextSize = 12
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = frame
	
	detectorItems[p] = {Label = lbl, Frame = frame}
end

local function showDeath(p)
	if isDeadState[p] then return end
	isDeadState[p] = true

	task.spawn(function()
		deathAvatar.Image = Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	deathText.Text = p.Name .. "\nTelah Mati!"
	deathFrame.Visible = true

	local ti = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	TweenService:Create(deathFrame, ti, {BackgroundTransparency = 0.2}):Play()
	TweenService:Create(deathAvatar, ti, {ImageTransparency = 0}):Play()
	TweenService:Create(deathText, ti, {TextTransparency = 0}):Play()

	task.wait(2.5)

	local to = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
	TweenService:Create(deathFrame, to, {BackgroundTransparency = 1}):Play()
	TweenService:Create(deathAvatar, to, {ImageTransparency = 1}):Play()
	TweenService:Create(deathText, to, {TextTransparency = 1}):Play()
	task.wait(0.5)
	deathFrame.Visible = false
end

local function createHealthCard(p)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, CARD_HEIGHT)
	frame.BackgroundColor3 = Color3.fromRGB(18,18,18)
	frame.BackgroundTransparency = 0.45
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

	local av = Instance.new("ImageLabel")
	av.Size = UDim2.new(0, 40, 0, 40)
	av.Position = UDim2.new(0, 5, 0.5, 0)
	av.AnchorPoint = Vector2.new(0, 0.5)
	av.BackgroundTransparency = 1
	av.Parent = frame
	Instance.new("UICorner", av).CornerRadius = UDim.new(1, 0)
	task.spawn(function() av.Image = Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48) end)

	local info = Instance.new("TextLabel")
	info.Name = "Info"
	info.Size = UDim2.new(1, -55, 1, 0)
	info.Position = UDim2.new(0, 50, 0, 0)
	info.BackgroundTransparency = 1
	info.Font = FONT
	info.TextSize = 14
	info.TextColor3 = Color3.fromRGB(255,255,255)
	info.TextXAlignment = Enum.TextXAlignment.Left
	info.Parent = frame
	
	Instance.new("UIStroke", info).Thickness = 1
	frame.Parent = listContainer
	return frame
end

local function updateHealthUI(p, hum)
	if not playerFrames[p] then playerFrames[p] = createHealthCard(p) end
	local txt = playerFrames[p].Info
	if not hum then
		txt.Text = "Loading...\n" .. p.Name
		return
	end

	local hp = math.floor(hum.Health + 0.5)
	local mx = math.max(1, math.floor(hum.MaxHealth + 0.5))
	
	if hp <= 0 then
		txt.Text = "0 / " .. mx .. "\n" .. p.Name .. " (MATI)"
		txt.TextColor3 = Color3.fromRGB(255, 60, 60)
		showDeath(p)
	else
		isDeadState[p] = false
		txt.Text = string.format("%d / %d%s\n%s", hp, mx, (hp <= SEKARAT_THRESHOLD and " !" or ""), p.Name)
		local pct = hp/mx
		txt.TextColor3 = (pct > 0.6 and Color3.fromRGB(170, 255, 170)) or (pct > 0.25 and Color3.fromRGB(255, 220, 110)) or Color3.fromRGB(255, 110, 110)
	end
end

local function refreshDetector()
	local count = 0
	for p, item in pairs(detectorItems) do
		count = count + 1
		local deviceName, deviceColor = getDeviceType(p)
		
		item.Label.Text = p.Name .. "\n[" .. deviceName .. "]"
		item.Label.TextColor3 = deviceColor
	end
	detectorContainer.Size = UDim2.new(0, 340, 0, math.max(45, math.ceil(count / 2) * 45 + 10))
end

-- ================= CONNECTIONS =================
UserInputService.InputBegan:Connect(function(i, g)
	if g then return end
	if i.KeyCode == Enum.KeyCode.P then
		for _, p in ipairs(Players:GetPlayers()) do if not detectorItems[p] then createDetectorItem(p) end end
		detectorContainer.Visible = true
		refreshDetector()
	end
end)

UserInputService.InputEnded:Connect(function(i)
	if i.KeyCode == Enum.KeyCode.P then detectorContainer.Visible = false end
end)

local function setup(p)
	p.CharacterAdded:Connect(function(c)
		local h = c:WaitForChild("Humanoid")
		h.HealthChanged:Connect(function() updateHealthUI(p, h) end)
		updateHealthUI(p, h)
	end)
	if p.Character then 
		local h = p.Character:FindFirstChild("Humanoid")
		if h then updateHealthUI(p, h) end
	end
end

for _, p in ipairs(Players:GetPlayers()) do setup(p) end
Players.PlayerAdded:Connect(setup)
Players.PlayerRemoving:Connect(function(p)
	if playerFrames[p] then playerFrames[p]:Destroy() playerFrames[p] = nil end
	if detectorItems[p] then detectorItems[p].Frame:Destroy() detectorItems[p] = nil end
end)
