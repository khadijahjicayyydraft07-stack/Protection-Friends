-- CombinedHealthUI - Fixed & Upgraded
-- LocalScript -> letakkan di StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- ========== CONFIG ==========
local SEKARAT_THRESHOLD = 16
local LIST_POSITION = UDim2.new(0, 15, 0, 15) -- Posisi list di layar (kiri atas)
local CARD_WIDTH = 240
local CARD_HEIGHT = 50
local FONT = Enum.Font.SourceSansBold
local BACKGROUND_COLOR = Color3.fromRGB(18,18,18)
local BACKGROUND_TRANSPARENCY = 0.45
-- ============================

local function clamp(v, a, b) if v < a then return a end if v > b then return b end return v end

-- Create Gui & Container
local function getOrCreateGui()
    local pg = LocalPlayer:WaitForChild("PlayerGui")
    local gui = pg:FindFirstChild("PlayerHealthUI")
    if not gui then
        gui = Instance.new("ScreenGui")
        gui.Name = "PlayerHealthUI"
        gui.ResetOnSpawn = false
        gui.Parent = pg
    end
    
    local listFrame = gui:FindFirstChild("ListContainer")
    if not listFrame then
        listFrame = Instance.new("Frame")
        listFrame.Name = "ListContainer"
        listFrame.Parent = gui
        listFrame.BackgroundTransparency = 1
        listFrame.Position = LIST_POSITION
        listFrame.Size = UDim2.new(0, CARD_WIDTH, 1, -30)
        
        -- Pake UIListLayout biar otomatis rapi nyusun ke bawah
        local layout = Instance.new("UIListLayout")
        layout.Parent = listFrame
        layout.Padding = UDim.new(0, 5)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
    end
    
    return listFrame
end

local listContainer = getOrCreateGui()

-- Tracking tables
local playerFrames = {} -- [player] = Frame
local conns = {}        -- [player] = { ... }

-- Bikin Kotak UI (Card) untuk masing-masing player
local function createPlayerCard(p)
    local frame = Instance.new("Frame")
    frame.Name = "Card_" .. p.UserId
    frame.Size = UDim2.new(1, 0, 0, CARD_HEIGHT)
    frame.BackgroundColor3 = BACKGROUND_COLOR
    frame.BackgroundTransparency = BACKGROUND_TRANSPARENCY
    frame.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    -- Profile Picture (Avatar)
    local avatarImg = Instance.new("ImageLabel")
    avatarImg.Name = "Avatar"
    avatarImg.Size = UDim2.new(0, CARD_HEIGHT - 10, 0, CARD_HEIGHT - 10)
    avatarImg.Position = UDim2.new(0, 5, 0.5, 0)
    avatarImg.AnchorPoint = Vector2.new(0, 0.5)
    avatarImg.BackgroundColor3 = Color3.fromRGB(40,40,40)
    avatarImg.Parent = frame
    
    local imgCorner = Instance.new("UICorner")
    imgCorner.CornerRadius = UDim.new(1, 0) -- Bikin bulat
    imgCorner.Parent = avatarImg

    -- Load Thumbnail (Pake task.spawn biar script gak stuck nunggu loading)
    task.spawn(function()
        local content, isReady = Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
        if avatarImg then avatarImg.Image = content end
    end)

    -- Text Data
    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "InfoText"
    textLabel.Size = UDim2.new(1, -(CARD_HEIGHT + 5), 1, 0)
    textLabel.Position = UDim2.new(0, CARD_HEIGHT + 5, 0, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Font = FONT
    textLabel.TextSize = 16
    textLabel.TextColor3 = Color3.fromRGB(255,255,255)
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.TextYAlignment = Enum.TextYAlignment.Center
    textLabel.Text = p.Name .. "\nLoading..."
    textLabel.Parent = frame
    
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Parent = textLabel

    frame.Parent = listContainer
    return frame
end

-- Update Text & Warna
local function updatePlayerUI(p, humanoid)
    if not playerFrames[p] then
        playerFrames[p] = createPlayerCard(p)
    end
    
    local frame = playerFrames[p]
    local txt = frame:FindFirstChild("InfoText")
    
    if not humanoid then
        txt.Text = "Menunggu Spawn...\n" .. p.Name
        txt.TextColor3 = Color3.fromRGB(150, 150, 150)
        return
    end
    
    local cur = math.floor(humanoid.Health + 0.5)
    local mx = math.max(1, math.floor(humanoid.MaxHealth + 0.5))
    cur = clamp(cur, 0, mx)
    
    -- LOGIKA MATI & SEKARAT
    if cur <= 0 then
        txt.Text = p.Name .. ".Mati"
        txt.TextColor3 = Color3.fromRGB(255, 60, 60)
    else
        local status = ""
        if cur <= SEKARAT_THRESHOLD then status = " (SEKARAT)" end
        
        -- NAMA DI BAWAH, DARAH DI ATAS
        txt.Text = string.format("Darah: %d / %d%s\n%s", cur, mx, status, p.Name)
        
        local pct = cur / mx
        if pct > 0.6 then
            txt.TextColor3 = Color3.fromRGB(170, 255, 170) -- Hijau
        elseif pct > 0.25 then
            txt.TextColor3 = Color3.fromRGB(255, 220, 110) -- Kuning
        else
            txt.TextColor3 = Color3.fromRGB(255, 110, 110) -- Merah (Sekarat)
        end
    end
end

-- Deteksi Karakter & Humanoid
local function attachToPlayer(p)
    if conns[p] then
        for _, c in pairs(conns[p]) do c:Disconnect() end
        conns[p] = nil
    end

    local function onCharacter(char)
        local humanoid = char:FindFirstChildWhichIsA("Humanoid") or char:WaitForChild("Humanoid", 5)
        if not humanoid then
            updatePlayerUI(p, nil)
            return
        end

        updatePlayerUI(p, humanoid)

        local hConn = humanoid.HealthChanged:Connect(function() updatePlayerUI(p, humanoid) end)
        local mConn = humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function() updatePlayerUI(p, humanoid) end)
        local aConn = char.AncestryChanged:Connect(function(_, parent)
            if not parent then
                updatePlayerUI(p, nil)
                if hConn then hConn:Disconnect() end
                if mConn then mConn:Disconnect() end
            end
        end)

        conns[p] = { healthConn = hConn, maxConn = mConn, ancestryConn = aConn }
    end

    if p.Character then
        onCharacter(p.Character)
    end
    
    local charConn = p.CharacterAdded:Connect(onCharacter)
    if not conns[p] then conns[p] = {} end
    conns[p].charAddedConn = charConn
end

local function detachPlayer(p)
    if playerFrames[p] then
        playerFrames[p]:Destroy()
        playerFrames[p] = nil
    end
    if conns[p] then
        for _, c in pairs(conns[p]) do c:Disconnect() end
        conns[p] = nil
    end
end

-- INIT
for _, p in ipairs(Players:GetPlayers()) do attachToPlayer(p) end
Players.PlayerAdded:Connect(attachToPlayer)
Players.PlayerRemoving:Connect(detachPlayer)
