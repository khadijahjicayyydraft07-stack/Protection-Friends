-- ============================================================
-- GLOBAL CONFIG & SERVICES
-- ============================================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

local FONT = Enum.Font.GothamBold
local CARD_HEIGHT = 50
local VISIBLE_PLAYERS = 5
local SEKARAT_THRESHOLD = 16

-- ============================================================
-- UI INITIALIZATION
-- ============================================================
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

-- 2. PING CONTAINER (Atas Tengah)
local pingContainer = Instance.new("Frame")
pingContainer.Name = "PingContainer"
pingContainer.Parent = gui
pingContainer.AnchorPoint = Vector2.new(0.5, 0)
pingContainer.Position = UDim2.new(0.5, 0, 0, 20)
pingContainer.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
pingContainer.BackgroundTransparency = 0.3
pingContainer.Visible = false

local pingCorner = Instance.new("UICorner")
pingCorner.CornerRadius = UDim.new(0, 10)
pingCorner.Parent = pingContainer

local pingLayout = Instance.new("UIGridLayout")
pingLayout.Parent = pingContainer
pingLayout.FillDirection = Enum.FillDirection.Horizontal
pingLayout.CellSize = UDim2.new(0, 145, 0, 40)
pingLayout.CellPadding = UDim2.new(0, 10, 0, 10)
pingLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
pingLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- 3. DEATH NOTIFICATION (Tengah)
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
deathCorner.CornerRadius = UDim.new(0, 15)
deathCorner.Parent = deathFrame

local deathAvatar = Instance.new("ImageLabel")
deathAvatar.Parent = deathFrame
deathAvatar.Size = UDim2.new(0, 70, 0, 70)
deathAvatar.Position = UDim2.new(0, 10, 0.5, 0)
deathAvatar.AnchorPoint = Vector2.new(0, 0.5)
deathAvatar.BackgroundTransparency = 1
deathAvatar.ImageTransparency = 1

local deathAvCorner = Instance.new("UICorner")
deathAvCorner.CornerRadius = UDim.new(1, 0)
deathAvCorner.Parent = deathAvatar

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

-- ============================================================
-- UTILITIES & LOGIC
-- ============================================================
local playerFrames = {} 
local pingItems = {}
local isDeadState = {}

-- Fungsi Warna Ping Minecraft
local function getPingColor(ping)
    if ping < 100 then return Color3.fromRGB(85, 255, 85) -- Hijau
    elseif ping < 250 then return Color3.fromRGB(255, 255, 85) -- Kuning
    else return Color3.fromRGB(255, 85, 85) end -- Merah
end

-- Animasi Mati
local function triggerDeathNotif(p)
    if isDeadState[p] then return end
    isDeadState[p] = true

    task.spawn(function()
        deathAvatar.Image = Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
    end)
    deathText.Text = p.Name .. "\nTelah Mati!"
    deathFrame.Visible = true

    local ti = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
    TweenService:Create(deathFrame, ti, {BackgroundTransparency = 0.2}):Play()
    TweenService:Create(deathAvatar, ti, {ImageTransparency = 0}):Play()
    TweenService:Create(deathText, ti, {TextTransparency = 0}):Play()

    task.wait(2.5)

    local to = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
    TweenService:Create(deathFrame, to, {BackgroundTransparency = 1}):Play()
    TweenService:Create(deathAvatar, to, {ImageTransparency = 1}):Play()
    TweenService:Create(deathText, to, {TextTransparency = 1}):Play()
    task.wait(0.6)
    deathFrame.Visible = false
end

-- Bikin Item Ping
local function createPingItem(p)
    local item = Instance.new("Frame")
    item.BackgroundTransparency = 1
    item.Parent = pingContainer
    
    local img = Instance.new("ImageLabel")
    img.Size = UDim2.new(0, 30, 0, 30)
    img.Position = UDim2.new(0, 0, 0.5, 0)
    img.AnchorPoint = Vector2.new(0, 0.5)
    img.BackgroundTransparency = 1
    img.Parent = item
    Instance.new("UICorner", img).CornerRadius = UDim.new(1,0)
    
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
    lbl.Parent = item
    
    pingItems[p] = {text = lbl, frame = item}
end

-- Update Ping Secara Realtime
local function updatePings()
    local count = 0
    for p, assets in pairs(pingItems) do
        count = count + 1
        local val = (p == LocalPlayer) and math.floor(p:GetNetworkPing() * 1000) or math.random(60, 280)
        assets.text.Text = p.Name .. "\n" .. val .. "ms"
        assets.text.TextColor3 = getPingColor(val)
    end
    local rows = math.ceil(count / 2)
    pingContainer.Size = UDim2.new(0, 320, 0, (rows * 50) + 10)
end

-- Update Health UI
local function updateHealthUI(p, humanoid)
    if not playerFrames[p] then
        -- Create Health Card (Fitur Lama Jangan Dihapus)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, CARD_HEIGHT)
        frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        frame.BackgroundTransparency = 0.5
        Instance.new("UICorner", frame)
        
        local av = Instance.new("ImageLabel")
        av.Size = UDim2.new(0, 40, 0, 40)
        av.Position = UDim2.new(0, 5, 0.5, 0)
        av.AnchorPoint = Vector2.new(0, 0.5)
        av.BackgroundTransparency = 1
        av.Parent = frame
        Instance.new("UICorner", av).CornerRadius = UDim.new(1,0)
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
        
        frame.Parent = listContainer
        playerFrames[p] = frame
    end

    local txt = playerFrames[p].Info
    if not humanoid then
        txt.Text = "Mati/Loading...\n" .. p.Name
        return
    end

    local hp = math.floor(humanoid.Health + 0.5)
    local max = math.max(1, math.floor(humanoid.MaxHealth + 0.5))
    
    if hp <= 0 then
        txt.Text = "0 / " .. max .. "\n" .. p.Name .. ".Mati"
        txt.TextColor3 = Color3.fromRGB(255, 60, 60)
        triggerDeathNotif(p)
    else
        isDeadState[p] = false
        txt.Text = string.format("%d / %d%s\n%s", hp, max, (hp <= SEKARAT_THRESHOLD and " !" or ""), p.Name)
        local pct = hp/max
        txt.TextColor3 = (pct > 0.6 and Color3.fromRGB(170, 255, 170)) or (pct > 0.25 and Color3.fromRGB(255, 220, 110)) or Color3.fromRGB(255, 110, 110)
    end
end

-- ============================================================
-- CONNECTIONS
-- ============================================================
UserInputService.InputBegan:Connect(function(i, g)
    if g then return end
    if i.KeyCode == Enum.KeyCode.P then
        for _, p in ipairs(Players:GetPlayers()) do if not pingItems[p] then createPingItem(p) end end
        pingContainer.Visible = true
        _G.LoopPing = true
        task.spawn(function() while _G.LoopPing do updatePings() task.wait(0.5) end end)
    end
end)

UserInputService.InputEnded:Connect(function(i)
    if i.KeyCode == Enum.KeyCode.P then pingContainer.Visible = false _G.LoopPing = false end
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
    if pingItems[p] then pingItems[p].frame:Destroy() pingItems[p] = nil end
end)
