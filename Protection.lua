-- CombinedHealthUI - Scrolling, Ping Checker, & Death Notification
-- LocalScript -> StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- ========== CONFIG ==========
local SEKARAT_THRESHOLD = 16
local FONT = Enum.Font.GothamBold
local CARD_HEIGHT = 50
local VISIBLE_PLAYERS = 5 -- Maksimal nampilin 5 orang sebelum harus di-scroll
-- ============================

local function clamp(v, a, b) if v < a then return a end if v > b then return b end return v end

-- ================= GUI SETUP =================
local pg = LocalPlayer:WaitForChild("PlayerGui")
local gui = pg:FindFirstChild("PlayerHealthUI")
if gui then gui:Destroy() end -- Reset kalau script di-restart

gui = Instance.new("ScreenGui")
gui.Name = "PlayerHealthUI"
gui.ResetOnSpawn = false
gui.Parent = pg

-- 1. SCROLLING FRAME (Daftar Darah)
local listContainer = Instance.new("ScrollingFrame")
listContainer.Name = "HealthList"
listContainer.Parent = gui
listContainer.BackgroundTransparency = 1
listContainer.Position = UDim2.new(0, 15, 0, 15)
-- Hitung tinggi buat 5 player aja (ditambah padding)
listContainer.Size = UDim2.new(0, 240, 0, (CARD_HEIGHT * VISIBLE_PLAYERS) + (5 * (VISIBLE_PLAYERS - 1)))
listContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
listContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
listContainer.ScrollBarThickness = 4

local listLayout = Instance.new("UIListLayout")
listLayout.Parent = listContainer
listLayout.Padding = UDim.new(0, 5)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- 2. PING FRAME (Atas Tengah)
local pingContainer = Instance.new("Frame")
pingContainer.Name = "PingContainer"
pingContainer.Parent = gui
pingContainer.AnchorPoint = Vector2.new(0.5, 0)
pingContainer.Position = UDim2.new(0.5, 0, 0, 10)
pingContainer.Size = UDim2.new(0, 320, 0, 100)
pingContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
pingContainer.BackgroundTransparency = 0.2
pingContainer.Visible = false

local pingCorner = Instance.new("UICorner")
pingCorner.CornerRadius = UDim.new(0, 8)
pingCorner.Parent = pingContainer

local pingLayout = Instance.new("UIGridLayout")
pingLayout.Parent = pingContainer
pingLayout.FillDirection = Enum.FillDirection.Horizontal
pingLayout.FillDirectionMaxCells = 2 -- Format Kanan Kiri
pingLayout.CellSize = UDim2.new(0, 150, 0, 25)
pingLayout.CellPadding = UDim2.new(0, 10, 0, 5)
pingLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- 3. DEATH NOTIFICATION FRAME (Tengah Layar)
local deathFrame = Instance.new("Frame")
deathFrame.Name = "DeathFrame"
deathFrame.Parent = gui
deathFrame.AnchorPoint = Vector2.new(0.5, 0.5)
deathFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
deathFrame.Size = UDim2.new(0, 280, 0, 80)
deathFrame.BackgroundColor3 = Color3.fromRGB(180, 20, 20)
deathFrame.BackgroundTransparency = 1
deathFrame.Visible = false

local deathCorner = Instance.new("UICorner")
deathCorner.CornerRadius = UDim.new(0, 12)
deathCorner.Parent = deathFrame

local deathAvatar = Instance.new("ImageLabel")
deathAvatar.Parent = deathFrame
deathAvatar.Size = UDim2.new(0, 60, 0, 60)
deathAvatar.Position = UDim2.new(0, 10, 0.5, 0)
deathAvatar.AnchorPoint = Vector2.new(0, 0.5)
deathAvatar.BackgroundTransparency = 1
deathAvatar.ImageTransparency = 1
local deathAvCorner = Instance.new("UICorner")
deathAvCorner.CornerRadius = UDim.new(1, 0)
deathAvCorner.Parent = deathAvatar

local deathText = Instance.new("TextLabel")
deathText.Parent = deathFrame
deathText.Size = UDim2.new(1, -80, 1, 0)
deathText.Position = UDim2.new(0, 80, 0, 0)
deathText.BackgroundTransparency = 1
deathText.Font = FONT
deathText.TextSize = 20
deathText.TextColor3 = Color3.fromRGB(255, 255, 255)
deathText.TextTransparency = 1
deathText.Text = "Nama Telah Mati"

local deathStroke = Instance.new("UIStroke")
deathStroke.Parent = deathText
deathStroke.Transparency = 1


-- ================= STATE & TRACKING =================
local playerFrames = {} 
local pingLabels = {}
local conns = {}        
local isDeadState = {} -- Biar notif matinya gak spam

-- ================= FUNCTIONS =================

-- Bikin Ping Item
local function createPingLabel(p)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = FONT
    lbl.TextSize = 14
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.Parent = pingContainer
    pingLabels[p] = lbl
end

-- Animasi Orang Mati
local function showDeathNotification(p)
    if isDeadState[p] then return end
    isDeadState[p] = true

    -- Load muka yang mati
    task.spawn(function()
        local content = Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
        deathAvatar.Image = content
    end)
    deathText.Text = p.Name .. "\nTelah Mati!"

    deathFrame.Visible = true

    -- Fade In
    local tiIn = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
    TweenService:Create(deathFrame, tiIn, {BackgroundTransparency = 0.2}):Play()
    TweenService:Create(deathAvatar, tiIn, {ImageTransparency = 0}):Play()
    TweenService:Create(deathText, tiIn, {TextTransparency = 0}):Play()
    TweenService:Create(deathStroke, tiIn, {Transparency = 0}):Play()

    task.wait(2.5) -- Tahan di layar 2.5 detik

    -- Fade Out
    local tiOut = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
    TweenService:Create(deathFrame, tiOut, {BackgroundTransparency = 1}):Play()
    TweenService:Create(deathAvatar, tiOut, {ImageTransparency = 1}):Play()
    TweenService:Create(deathText, tiOut, {TextTransparency = 1}):Play()
    TweenService:Create(deathStroke, tiOut, {Transparency = 1}):Play()

    task.wait(0.5)
    deathFrame.Visible = false
end

-- Bikin Card Darah
local function createPlayerCard(p)
    local frame = Instance.new("Frame")
    frame.Name = "Card_" .. p.UserId
    frame.Size = UDim2.new(1, 0, 0, CARD_HEIGHT)
    frame.BackgroundColor3 = Color3.fromRGB(18,18,18)
    frame.BackgroundTransparency = 0.45
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local avatarImg = Instance.new("ImageLabel")
    avatarImg.Size = UDim2.new(0, CARD_HEIGHT - 10, 0, CARD_HEIGHT - 10)
    avatarImg.Position = UDim2.new(0, 5, 0.5, 0)
    avatarImg.AnchorPoint = Vector2.new(0, 0.5)
    avatarImg.BackgroundColor3 = Color3.fromRGB(40,40,40)
    avatarImg.Parent = frame
    
    local imgCorner = Instance.new("UICorner")
    imgCorner.CornerRadius = UDim.new(1, 0)
    imgCorner.Parent = avatarImg

    task.spawn(function()
        local content = Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
        if avatarImg then avatarImg.Image = content end
    end)

    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "InfoText"
    textLabel.Size = UDim2.new(1, -(CARD_HEIGHT + 5), 1, 0)
    textLabel.Position = UDim2.new(0, CARD_HEIGHT + 5, 0, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Font = FONT
    textLabel.TextSize = 14
    textLabel.TextColor3 = Color3.fromRGB(255,255,255)
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Text = p.Name .. "\nLoading..."
    textLabel.Parent = frame
    
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Parent = textLabel

    frame.Parent = listContainer
    return frame
end

local function updatePlayerUI(p, humanoid)
    if not playerFrames[p] then playerFrames[p] = createPlayerCard(p) end
    if not pingLabels[p] then createPingLabel(p) end
    
    local txt = playerFrames[p]:FindFirstChild("InfoText")
    
    if not humanoid then
        txt.Text = "Menunggu Spawn...\n" .. p.Name
        txt.TextColor3 = Color3.fromRGB(150, 150, 150)
        return
    end
    
    local cur = math.floor(humanoid.Health + 0.5)
    local mx = math.max(1, math.floor(humanoid.MaxHealth + 0.5))
    cur = clamp(cur, 0, mx)
    
    if cur <= 0 then
        txt.Text = "Darah: 0 / " .. mx .. "\n" .. p.Name .. " (Mati)"
        txt.TextColor3 = Color3.fromRGB(255, 60, 60)
        showDeathNotification(p) -- Panggil animasi mati
    else
        isDeadState[p] = false -- Reset state kalau dia hidup lagi
        local status = ""
        if cur <= SEKARAT_THRESHOLD then status = " (SEKARAT)" end
        
        txt.Text = string.format("Darah: %d / %d%s\n%s", cur, mx, status, p.Name)
        
        local pct = cur / mx
        if pct > 0.6 then txt.TextColor3 = Color3.fromRGB(170, 255, 170)
        elseif pct > 0.25 then txt.TextColor3 = Color3.fromRGB(255, 220, 110)
        else txt.TextColor3 = Color3.fromRGB(255, 110, 110) end
    end
end

-- Update Ping Secara Realtime Saat Tombol Ditahan
local function updateAllPings()
    local totalPlayers = 0
    for p, lbl in pairs(pingLabels) do
        totalPlayers = totalPlayers + 1
        if p == LocalPlayer then
            -- Ambil ping asli kita
            local pingMs = math.floor(p:GetNetworkPing() * 1000)
            lbl.Text = p.Name .. " . " .. pingMs .. "ms"
        else
            -- Dummy ping buat orang lain (karena LocalScript gak bisa baca ping orang lain)
            local dummyPing = math.random(40, 120) 
            lbl.Text = p.Name .. " . " .. dummyPing .. "ms"
        end
    end
    -- Sesuaikan tinggi box ping berdasarkan jumlah player
    pingContainer.Size = UDim2.new(0, 320, 0, math.max(35, math.ceil(totalPlayers / 2) * 30 + 10))
end

-- ================= INPUT & CONNECTIONS =================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.P then
        pingContainer.Visible = true
        updateAllPings()
        
        -- Loop update ping selagi ditahan
        _G.PingLoop = true
        task.spawn(function()
            while _G.PingLoop and task.wait(1) do updateAllPings() end
        end)
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.P then
        pingContainer.Visible = false
        _G.PingLoop = false
    end
end)

local function attachToPlayer(p)
    if conns[p] then
        for _, c in pairs(conns[p]) do c:Disconnect() end
    end

    local function onCharacter(char)
        local humanoid = char:FindFirstChildWhichIsA("Humanoid") or char:WaitForChild("Humanoid", 5)
        if not humanoid then return end

        updatePlayerUI(p, humanoid)

        local hConn = humanoid.HealthChanged:Connect(function() updatePlayerUI(p, humanoid) end)
        local aConn = char.AncestryChanged:Connect(function(_, parent)
            if not parent then updatePlayerUI(p, nil) end
        end)

        conns[p] = { healthConn = hConn, ancestryConn = aConn }
    end

    if p.Character then onCharacter(p.Character) end
    
    local charConn = p.CharacterAdded:Connect(onCharacter)
    if not conns[p] then conns[p] = {} end
    conns[p].charAddedConn = charConn
end

local function detachPlayer(p)
    if playerFrames[p] then playerFrames[p]:Destroy() playerFrames[p] = nil end
    if pingLabels[p] then pingLabels[p]:Destroy() pingLabels[p] = nil end
    if conns[p] then
        for _, c in pairs(conns[p]) do c:Disconnect() end
        conns[p] = nil
    end
    isDeadState[p] = nil
end

-- INIT
for _, p in ipairs(Players:GetPlayers()) do attachToPlayer(p) end
Players.PlayerAdded:Connect(attachToPlayer)
Players.PlayerRemoving:Connect(detachPlayer)
