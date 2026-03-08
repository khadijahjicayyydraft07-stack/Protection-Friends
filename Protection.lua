-- CombinedHealthUI - Updated Pro (No Deletions)
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

-- 1. SCROLLING FRAME (Daftar Darah)
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

-- 2. PING FRAME (Atas Tengah)
local pingContainer = Instance.new("Frame")
pingContainer.Name = "PingContainer"
pingContainer.Parent = gui
pingContainer.AnchorPoint = Vector2.new(0.5, 0)
pingContainer.Position = UDim2.new(0.5, 0, 0, 10)
pingContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
pingContainer.BackgroundTransparency = 0.2
pingContainer.Visible = false

local pingCorner = Instance.new("UICorner")
pingCorner.CornerRadius = UDim.new(0, 8)
pingCorner.Parent = pingContainer

local pingLayout = Instance.new("UIGridLayout")
pingLayout.Parent = pingContainer
pingLayout.FillDirection = Enum.FillDirection.Horizontal
pingLayout.CellSize = UDim2.new(0, 155, 0, 35) -- Ukuran diperbesar untuk profile
pingLayout.CellPadding = UDim2.new(0, 10, 0, 8)
pingLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- 3. DEATH NOTIFICATION FRAME
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
Instance.new("UICorner", deathAvatar).CornerRadius = UDim.new(1, 0)

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

-- ================= STATE & TRACKING =================
local playerFrames = {} 
local pingItems = {} -- Sekarang nyimpen Frame, bukan cuma Label
local conns = {}        
local isDeadState = {}

-- ================= FUNCTIONS =================

-- Minecraft Ping Color Logic
local function getPingColor(pingValue)
    if pingValue < 100 then
        return Color3.fromRGB(85, 255, 85) -- Hijau (Minecraft)
    elseif pingValue < 250 then
        return Color3.fromRGB(255, 255, 85) -- Kuning (Minecraft)
    else
        return Color3.fromRGB(255, 85, 85) -- Merah (Minecraft)
    end
end

-- Bikin Ping Item (Sekarang ada Profile-nya)
local function createPingLabel(p)
    local frame = Instance.new("Frame")
    frame.BackgroundTransparency = 1
    frame.Parent = pingContainer
    
    local img = Instance.new("ImageLabel")
    img.Size = UDim2.new(0, 25, 0, 25)
    img.Position = UDim2.new(0, 2, 0.5, 0)
    img.AnchorPoint = Vector2.new(0, 0.5)
    img.BackgroundTransparency = 1
    img.Parent = frame
    Instance.new("UICorner", img).CornerRadius = UDim.new(1, 0)
    
    task.spawn(function()
        img.Image = Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
    end)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -32, 1, 0)
    lbl.Position = UDim2.new(0, 32, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = FONT
    lbl.TextSize = 13
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame
    
    pingItems[p] = {Label = lbl, Frame = frame}
end

local function showDeathNotification(p)
    if isDeadState[p] then return end
    isDeadState[p] = true

    task.spawn(function()
        local content = Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
        deathAvatar.Image = content
    end)
    deathText.Text = p.Name .. "\nTelah Mati!"
    deathFrame.Visible = true

    local tiIn = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
    TweenService:Create(deathFrame, tiIn, {BackgroundTransparency = 0.2}):Play()
    TweenService:Create(deathAvatar, tiIn, {ImageTransparency = 0}):Play()
    TweenService:Create(deathText, tiIn, {TextTransparency = 0}):Play()

    task.wait(2.5)

    local tiOut = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
    TweenService:Create(deathFrame, tiOut, {BackgroundTransparency = 1}):Play()
    TweenService:Create(deathAvatar, tiOut, {ImageTransparency = 1}):Play()
    TweenService:Create(deathText, tiOut, {TextTransparency = 1}):Play()
    task.wait(0.5)
    deathFrame.Visible = false
end

local function createPlayerCard(p)
    local frame = Instance.new("Frame")
    frame.Name = "Card_" .. p.UserId
    frame.Size = UDim2.new(1, 0, 0, CARD_HEIGHT)
    frame.BackgroundColor3 = Color3.fromRGB(18,18,18)
    frame.BackgroundTransparency = 0.45
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local avatarImg = Instance.new("ImageLabel")
    avatarImg.Size = UDim2.new(0, CARD_HEIGHT - 10, 0, CARD_HEIGHT - 10)
    avatarImg.Position = UDim2.new(0, 5, 0.5, 0)
    avatarImg.AnchorPoint = Vector2.new(0, 0.5)
    avatarImg.BackgroundColor3 = Color3.fromRGB(40,40,40)
    avatarImg.Parent = frame
    Instance.new("UICorner", avatarImg).CornerRadius = UDim.new(1, 0)

    task.spawn(function()
        avatarImg.Image = Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
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
    
    Instance.new("UIStroke", textLabel).Thickness = 1
    frame.Parent = listContainer
    return frame
end

local function updatePlayerUI(p, humanoid)
    if not playerFrames[p] then playerFrames[p] = createPlayerCard(p) end
    if not pingItems[p] then createPingLabel(p) end
    
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
        showDeathNotification(p)
    else
        isDeadState[p] = false
        local status = (cur <= SEKARAT_THRESHOLD) and " (SEKARAT)" or ""
        txt.Text = string.format("Darah: %d / %d%s\n%s", cur, mx, status, p.Name)
        
        local pct = cur / mx
        if pct > 0.6 then txt.TextColor3 = Color3.fromRGB(170, 255, 170)
        elseif pct > 0.25 then txt.TextColor3 = Color3.fromRGB(255, 220, 110)
        else txt.TextColor3 = Color3.fromRGB(255, 110, 110) end
    end
end

local function updateAllPings()
    local totalPlayers = 0
    for p, item in pairs(pingItems) do
        totalPlayers = totalPlayers + 1
        local pingValue
        if p == LocalPlayer then
            pingValue = math.floor(p:GetNetworkPing() * 1000)
        else
            -- Dummy ping lebih stabil biar nggak lompat-lompat aneh
            pingValue = math.random(50, 150) 
        end
        
        item.Label.Text = p.Name .. " . " .. pingValue .. "ms"
        item.Label.TextColor3 = getPingColor(pingValue)
    end
    pingContainer.Size = UDim2.new(0, 340, 0, math.max(40, math.ceil(totalPlayers / 2) * 40 + 10))
end

-- ================= INPUT & CONNECTIONS =================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.P then
        pingContainer.Visible = true
        updateAllPings()
        _G.PingLoop = true
        task.spawn(function()
            while _G.PingLoop and task.wait(0.5) do updateAllPings() end
        end)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.P then
        pingContainer.Visible = false
        _G.PingLoop = false
    end
end)

local function attachToPlayer(p)
    if conns[p] then for _, c in pairs(conns[p]) do c:Disconnect() end end

    local function onCharacter(char)
        local humanoid = char:FindFirstChildWhichIsA("Humanoid") or char:WaitForChild("Humanoid", 5)
        if not humanoid then return end
        updatePlayerUI(p, humanoid)
        local hConn = humanoid.HealthChanged:Connect(function() updatePlayerUI(p, humanoid) end)
        local aConn = char.AncestryChanged:Connect(function(_, parent) if not parent then updatePlayerUI(p, nil) end end)
        conns[p] = { healthConn = hConn, ancestryConn = aConn }
    end

    if p.Character then onCharacter(p.Character) end
    local charConn = p.CharacterAdded:Connect(onCharacter)
    if not conns[p] then conns[p] = {} end
    conns[p].charAddedConn = charConn
end

local function detachPlayer(p)
    if playerFrames[p] then playerFrames[p]:Destroy() playerFrames[p] = nil end
    if pingItems[p] then pingItems[p].Frame:Destroy() pingItems[p] = nil end
    if conns[p] then for _, c in pairs(conns[p]) do c:Disconnect() end conns[p] = nil end
    isDeadState[p] = nil
end

for _, p in ipairs(Players:GetPlayers()) do attachToPlayer(p) end
Players.PlayerAdded:Connect(attachToPlayer)
Players.PlayerRemoving:Connect(detachPlayer)
