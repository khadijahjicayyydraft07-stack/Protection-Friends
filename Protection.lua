-- ClientTeamAndSelfHealth.lua
-- LocalScript -> letakkan di StarterPlayer > StarterPlayerScripts
-- Menampilkan darah pemain lokal (kiri-bawah) dan daftar rekan tim (kiri-atas).
-- Gunakan hanya di game yang kamu kembangkan / diberi izin.

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- CONFIG
local SEKARAT_THRESHOLD = 16   -- <= ini dianggap sekarat
local SELF_PADDING = Vector2.new(12, 12)    -- kiri-bawah offset
local TEAM_PADDING = Vector2.new(12, 12)    -- kiri-atas offset
local TEAM_LABEL_WIDTH = 250
local TEAM_LABEL_HEIGHT = 28
local SELF_LABEL_WIDTH = 260
local SELF_LABEL_HEIGHT = 44
local FONT = Enum.Font.SourceSansBold
local SELF_FONT_SIZE = 22
local TEAM_FONT_SIZE = 18

-- UTIL
local function clamp(v, a, b) if v < a then return a end if v > b then return b end return v end

-- Create PlayerGui containers
local function createOrGetScreenGui(name)
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local gui = playerGui:FindFirstChild(name)
    if not gui then
        gui = Instance.new("ScreenGui")
        gui.Name = name
        gui.ResetOnSpawn = false
        gui.Parent = playerGui
    end
    return gui
end

-- SELF UI (bottom-left)
local selfGui = createOrGetScreenGui("LocalSelfHealthUI")
local selfLabel = selfGui:FindFirstChild("SelfHealthLabel")
if not selfLabel then
    selfLabel = Instance.new("TextLabel")
    selfLabel.Name = "SelfHealthLabel"
    selfLabel.Parent = selfGui
    selfLabel.AnchorPoint = Vector2.new(0, 1) -- bottom-left
    selfLabel.Position = UDim2.new(0, SELF_PADDING.X, 1, -SELF_PADDING.Y)
    selfLabel.Size = UDim2.new(0, SELF_LABEL_WIDTH, 0, SELF_LABEL_HEIGHT)
    selfLabel.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    selfLabel.BackgroundTransparency = 0.35
    selfLabel.BorderSizePixel = 0
    selfLabel.Font = FONT
    selfLabel.TextSize = SELF_FONT_SIZE
    selfLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    selfLabel.TextXAlignment = Enum.TextXAlignment.Left
    selfLabel.TextYAlignment = Enum.TextYAlignment.Center

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = Color3.fromRGB(0,0,0)
    stroke.Parent = selfLabel
end

-- TEAM UI (top-left list)
local teamGui = createOrGetScreenGui("LocalTeamHealthUI")
local listFrame = teamGui:FindFirstChild("TeamListFrame")
if not listFrame then
    listFrame = Instance.new("Frame")
    listFrame.Name = "TeamListFrame"
    listFrame.Parent = teamGui
    listFrame.AnchorPoint = Vector2.new(0, 0) -- top-left
    listFrame.Position = UDim2.new(0, TEAM_PADDING.X, 0, TEAM_PADDING.Y)
    listFrame.Size = UDim2.new(0, TEAM_LABEL_WIDTH, 0, 200)
    listFrame.BackgroundTransparency = 1
end

-- Track connections and labels per player
local playerConns = {}  -- [player] = { healthConn = ..., maxConn = ..., charAncestryConn = ... }
local labels = {}       -- [player] = TextLabel

local function makeTeamLabelFor(player)
    local lbl = Instance.new("TextLabel")
    lbl.Name = "HP_" .. tostring(player.UserId)
    lbl.Parent = listFrame
    lbl.Size = UDim2.new(1, 0, 0, TEAM_LABEL_HEIGHT)
    lbl.BackgroundColor3 = Color3.fromRGB(20,20,20)
    lbl.BackgroundTransparency = 0.4
    lbl.BorderSizePixel = 0
    lbl.Font = FONT
    lbl.TextSize = TEAM_FONT_SIZE
    lbl.TextColor3 = Color3.fromRGB(255,255,255)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Center
    lbl.Text = player.Name .. ": -- / --"
    return lbl
end

local function updateLayout()
    local idx = 0
    for _, p in pairs(Players:GetPlayers()) do
        if labels[p] then
            labels[p].Position = UDim2.new(0, 0, 0, idx * TEAM_LABEL_HEIGHT)
            idx = idx + 1
        end
    end
    listFrame.Size = UDim2.new(0, TEAM_LABEL_WIDTH, 0, math.max(1, idx) * TEAM_LABEL_HEIGHT)
end

local function removePlayerUI(p)
    if labels[p] then
        labels[p]:Destroy()
        labels[p] = nil
    end
    -- disconnect any connections
    local c = playerConns[p]
    if c then
        if c.healthConn then c.healthConn:Disconnect() end
        if c.maxConn then c.maxConn:Disconnect() end
        if c.ancestryConn then c.ancestryConn:Disconnect() end
        playerConns[p] = nil
    end
    updateLayout()
end

-- Decide whether to show this other player: same team as local player (and not local player in team list)
local function shouldShowAsTeammate(other)
    if not other then return false end
    if LocalPlayer.Team and other.Team then
        return LocalPlayer.Team == other.Team and other ~= LocalPlayer
    end
    return false
end

local function getHumanoidFromCharacter(character)
    if not character then return nil end
    return character:FindFirstChildWhichIsA("Humanoid")
end

local function updateSelfDisplay(humanoid)
    if not humanoid then
        selfLabel.Text = "Darah: -- / --"
        return
    end
    local cur = math.floor(humanoid.Health + 0.5)
    local max = math.max(1, math.floor(humanoid.MaxHealth + 0.5))
    local status = ""
    if cur <= SEKARAT_THRESHOLD then status = " — SEKARAT" end
    selfLabel.Text = string.format("Darah: %d / %d%s", clamp(cur,0,max), max, status)

    local pct = cur / max
    if pct > 0.6 then
        selfLabel.TextColor3 = Color3.fromRGB(170,255,170)
    elseif pct > 0.25 then
        selfLabel.TextColor3 = Color3.fromRGB(255,220,110)
    else
        selfLabel.TextColor3 = Color3.fromRGB(255,110,110)
    end
end

local function updateTeammateLabel(player, humanoid)
    if not labels[player] then
        labels[player] = makeTeamLabelFor(player)
    end
    local lbl = labels[player]
    if not humanoid then
        lbl.Text = string.format("%s: -- / --", player.Name)
        lbl.TextColor3 = Color3.fromRGB(200,200,200)
        updateLayout()
        return
    end

    local cur = math.floor(humanoid.Health + 0.5)
    local max = math.max(1, math.floor(humanoid.MaxHealth + 0.5))
    local status = ""
    if cur <= SEKARAT_THRESHOLD then status = " — SEKARAT" end
    lbl.Text = string.format("%s: %d / %d%s", player.Name, clamp(cur,0,max), max, status)

    local pct = cur / max
    if pct > 0.6 then
        lbl.TextColor3 = Color3.fromRGB(170,255,170)
    elseif pct > 0.25 then
        lbl.TextColor3 = Color3.fromRGB(255,220,110)
    else
        lbl.TextColor3 = Color3.fromRGB(255,110,110)
    end

    updateLayout()
end

-- Attach to a player's character humanoid (for reading health)
local function attachToPlayerCharacter(player)
    -- cleanup if existed
    if playerConns[player] then
        if playerConns[player].healthConn then playerConns[player].healthConn:Disconnect() end
        if playerConns[player].maxConn then playerConns[player].maxConn:Disconnect() end
        if playerConns[player].ancestryConn then playerConns[player].ancestryConn:Disconnect() end
    end

    local character = player.Character
    if not character then
        -- listen for character spawn
        local ancestryConn
        ancestryConn = player.CharacterAdded:Connect(function(char)
            if playerConns[player] and playerConns[player].ancestryConn then
                playerConns[player].ancestryConn:Disconnect()
            end
            attachToPlayerCharacter(player)
        end)
        playerConns[player] = { ancestryConn = ancestryConn }
        return
    end

    local humanoid = getHumanoidFromCharacter(character)
    if not humanoid then
        humanoid = character:WaitForChild("Humanoid", 5)
        if not humanoid then
            return
        end
    end

    -- update initial
    if player == LocalPlayer then
        updateSelfDisplay(humanoid)
    end
    if shouldShowAsTeammate(player) then
        updateTeammateLabel(player, humanoid)
    else
        if labels[player] then removePlayerUI(player) end
    end

    -- connect events
    local healthConn = humanoid.HealthChanged:Connect(function()
        if player == LocalPlayer then
            updateSelfDisplay(humanoid)
        end
        if shouldShowAsTeammate(player) then
            updateTeammateLabel(player, humanoid)
        end
    end)
    local maxConn = humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
        if player == LocalPlayer then
            updateSelfDisplay(humanoid)
        end
        if shouldShowAsTeammate(player) then
            updateTeammateLabel(player, humanoid)
        end
    end)

    -- detect character removal to cleanup later
    local ancestryConn
    ancestryConn = character.AncestryChanged:Connect(function(_, parent)
        if not parent then
            if player == LocalPlayer then
                selfLabel.Text = "Darah: -- / --"
            end
            if labels[player] then
                labels[player]:Destroy()
                labels[player] = nil
            end
            if playerConns[player] then
                if playerConns[player].healthConn then playerConns[player].healthConn:Disconnect() end
                if playerConns[player].maxConn then playerConns[player].maxConn:Disconnect() end
                if playerConns[player].ancestryConn then playerConns[player].ancestryConn:Disconnect() end
                playerConns[player] = nil
            end
            updateLayout()
        end
    end)

    playerConns[player] = {
        healthConn = healthConn;
        maxConn = maxConn;
        ancestryConn = ancestryConn;
    }
end

-- Re-evaluate teammates when local player's team changes
local function refreshAllTeamDisplays()
    for p, _ in pairs(labels) do
        if not shouldShowAsTeammate(p) then
            removePlayerUI(p)
        end
    end
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and shouldShowAsTeammate(p) then
            attachToPlayerCharacter(p)
        end
    end
    attachToPlayerCharacter(LocalPlayer)
end

-- Player join / leave handlers
Players.PlayerAdded:Connect(function(p)
    p:GetPropertyChangedSignal("Team"):Connect(function()
        refreshAllTeamDisplays()
    end)
    attachToPlayerCharacter(p)
end)

Players.PlayerRemoving:Connect(function(p)
    removePlayerUI(p)
end)

LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
    refreshAllTeamDisplays()
end)

for _, p in ipairs(Players:GetPlayers()) do
    p:GetPropertyChangedSignal("Team"):Connect(function()
        refreshAllTeamDisplays()
    end)
    attachToPlayerCharacter(p)
end

LocalPlayer.CharacterAdded:Connect(function(char)
    attachToPlayerCharacter(LocalPlayer)
end)

-- UI config
local PADDING = Vector2.new(12, 12)
local LABEL_WIDTH = 240
local LABEL_HEIGHT = 26
local FONT = Enum.Font.SourceSansBold
local TEXT_SIZE = 18
local SEKARAT_THRESHOLD = 16

-- helper
local function clamp(v,a,b) if v<a then return a end if v>b then return b end return v end

-- create GUI container
local function getOrCreateGui()
    local pg = LocalPlayer:WaitForChild("PlayerGui")
    local gui = pg:FindFirstChild("OtherHealthUI")
    if not gui then
        gui = Instance.new("ScreenGui")
        gui.Name = "OtherHealthUI"
        gui.ResetOnSpawn = false
        gui.Parent = pg
    end
    return gui
end

local gui = getOrCreateGui()
local listFrame = gui:FindFirstChild("ListFrame")
if not listFrame then
    listFrame = Instance.new("Frame")
    listFrame.Name = "ListFrame"
    listFrame.Size = UDim2.new(0, LABEL_WIDTH, 0, 200)
    listFrame.Position = UDim2.new(0, PADDING.X, 0, PADDING.Y)
    listFrame.BackgroundTransparency = 1
    listFrame.Parent = gui
end

local labels = {}      -- [player] = TextLabel
local conns = {}       -- [player] = { healthConn, maxConn, ancestryConn }

local function makeLabel(p)
    local lbl = Instance.new("TextLabel")
    lbl.Name = "HP_" .. tostring(p.UserId)
    lbl.Size = UDim2.new(1, 0, 0, LABEL_HEIGHT)
    lbl.BackgroundColor3 = Color3.fromRGB(20,20,20)
    lbl.BackgroundTransparency = 0.45
    lbl.BorderSizePixel = 0
    lbl.Font = FONT
    lbl.TextSize = TEXT_SIZE
    lbl.TextColor3 = Color3.fromRGB(255,255,255)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Center
    lbl.Text = p.Name .. ": -- / --"
    lbl.Parent = listFrame
    return lbl
end

local function updateLayout()
    local idx = 0
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and labels[p] then
            labels[p].Position = UDim2.new(0, 0, 0, idx * LABEL_HEIGHT)
            idx = idx + 1
        end
    end
    listFrame.Size = UDim2.new(0, LABEL_WIDTH, 0, math.max(1, idx) * LABEL_HEIGHT)
end

local function updateLabelFor(p, humanoid)
    if labels[p] == nil then labels[p] = makeLabel(p) end
    local lbl = labels[p]
    if not humanoid then
        lbl.Text = string.format("%s: -- / --", p.Name)
        lbl.TextColor3 = Color3.fromRGB(200,200,200)
        updateLayout()
        return
    end
    local cur = math.floor(humanoid.Health + 0.5)
    local mx  = math.max(1, math.floor(humanoid.MaxHealth + 0.5))
    cur = clamp(cur, 0, mx)
    local status = cur <= SEKARAT_THRESHOLD and " — SEKARAT" or ""
    lbl.Text = string.format("%s: %d / %d%s", p.Name, cur, mx, status)
    local pct = cur / mx
    if pct > 0.6 then
        lbl.TextColor3 = Color3.fromRGB(160,255,160)
    elseif pct > 0.25 then
        lbl.TextColor3 = Color3.fromRGB(255,210,110)
    else
        lbl.TextColor3 = Color3.fromRGB(255,120,120)
    end
    updateLayout()
end

local function attachPlayer(p)
    -- skip self
    if p == LocalPlayer then return end

    -- cleanup previous
    if conns[p] then
        if conns[p].healthConn then conns[p].healthConn:Disconnect() end
        if conns[p].maxConn then conns[p].maxConn:Disconnect() end
        if conns[p].ancestryConn then conns[p].ancestryConn:Disconnect() end
        conns[p] = nil
    end

    local function onCharacter(char)
        local humanoid = char:FindFirstChildWhichIsA("Humanoid") or char:WaitForChild("Humanoid", 5)
        if not humanoid then
            updateLabelFor(p, nil)
            return
        end
        updateLabelFor(p, humanoid)
        local hConn = humanoid.HealthChanged:Connect(function() updateLabelFor(p, humanoid) end)
        local mConn = humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function() updateLabelFor(p, humanoid) end)
        local aConn = char.AncestryChanged:Connect(function(_, parent)
            if not parent then
                updateLabelFor(p, nil)
                if hConn then hConn:Disconnect() end
                if mConn then mConn:Disconnect() end
                if aConn then aConn:Disconnect() end
            end
        end)
        conns[p] = { healthConn = hConn, maxConn = mConn, ancestryConn = aConn }
    end

    -- if no character yet, wait for CharacterAdded
    if p.Character then
        onCharacter(p.Character)
    else
        local conn
        conn = p.CharacterAdded:Connect(function(char)
            if conn then conn:Disconnect() end
            onCharacter(char)
        end)
        conns[p] = { ancestryConn = conn }
    end
end

local function detachPlayer(p)
    if labels[p] then labels[p]:Destroy() labels[p] = nil end
    if conns[p] then
        if conns[p].healthConn then conns[p].healthConn:Disconnect() end
        if conns[p].maxConn then conns[p].maxConn:Disconnect() end
        if conns[p].ancestryConn then conns[p].ancestryConn:Disconnect() end
        conns[p] = nil
    end
    updateLayout()
end

-- initial attach for existing players
for _, p in ipairs(Players:GetPlayers()) do
    attachPlayer(p)
end

Players.PlayerAdded:Connect(function(p)
    attachPlayer(p)
end)

Players.PlayerRemoving:Connect(function(p)
    detachPlayer(p)
end)
