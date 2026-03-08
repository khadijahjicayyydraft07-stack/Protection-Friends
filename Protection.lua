-- LocalShowOthersHealth.lua
-- LocalScript -> letakkan di StarterPlayer > StarterPlayerScripts
-- Menampilkan darah pemain LAIN (bukan self) di kiri-atas.
-- Gunakan hanya di game yang kamu kembangkan / diberi izin.

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

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
