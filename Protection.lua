-- TeammateHealthUI.lua
-- Letakkan sebagai LocalScript di StarterPlayer > StarterPlayerScripts
-- Menerima update dari RemoteEvent "TeamHealthUpdate" dan menampilkan teks sederhana.
-- Menampilkan "SEKARAT" saat HP <= ambang.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local REMOTE_NAME = "TeamHealthUpdate"
local remote = ReplicatedStorage:WaitForChild(REMOTE_NAME)

-- UI config
local PADDING_X = 10
local PADDING_Y = 10
local LABEL_WIDTH = 220
local LABEL_HEIGHT = 28
local FONT = Enum.Font.SourceSansBold
local FONT_SIZE = 18
local SEKARAT_THRESHOLD = 16

-- Container UI (top-left list)
local function createUI()
    local playerGui = player:WaitForChild("PlayerGui")
    local screenGui = playerGui:FindFirstChild("TeammateHealthUI")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "TeammateHealthUI"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = playerGui
    end

    local frame = screenGui:FindFirstChild("ListFrame")
    if not frame then
        frame = Instance.new("Frame")
        frame.Name = "ListFrame"
        frame.Parent = screenGui
        frame.AnchorPoint = Vector2.new(0, 0) -- top-left
        frame.Position = UDim2.new(0, PADDING_X, 0, PADDING_Y)
        frame.Size = UDim2.new(0, LABEL_WIDTH, 0, 300)
        frame.BackgroundTransparency = 1
    end

    return screenGui, frame
end

local screenGui, frame = createUI()

-- Keep labels by userId
local labels = {}

local function makeLabelFor(userId, displayName)
    local lbl = Instance.new("TextLabel")
    lbl.Name = "HP_" .. tostring(userId)
    lbl.Parent = frame
    lbl.Size = UDim2.new(1, 0, 0, LABEL_HEIGHT)
    lbl.BackgroundTransparency = 0.4
    lbl.BackgroundColor3 = Color3.fromRGB(20,20,20)
    lbl.BorderSizePixel = 0
    lbl.Font = FONT
    lbl.TextSize = FONT_SIZE
    lbl.TextColor3 = Color3.fromRGB(255,255,255)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Center
    lbl.Text = displayName .. ": -- / --"
    return lbl
end

local function updateLayout()
    -- stack labels vertically
    local idx = 0
    for _, lbl in pairs(labels) do
        lbl.Position = UDim2.new(0, 0, 0, idx * LABEL_HEIGHT)
        idx = idx + 1
    end
    -- adjust frame height
    frame.Size = UDim2.new(0, LABEL_WIDTH, 0, math.max(1, idx) * LABEL_HEIGHT)
end

local function removeLabel(userId)
    local lbl = labels[userId]
    if lbl then
        lbl:Destroy()
        labels[userId] = nil
        updateLayout()
    end
end

local function setLabel(userId, name, current, max, left)
    if left then
        removeLabel(userId)
        return
    end

    local lbl = labels[userId]
    if not lbl then
        lbl = makeLabelFor(userId, name)
        labels[userId] = lbl
    end

    -- Guard: avoid showing local player's own HP here if you prefer
    if userId == player.UserId then
        -- optional: skip showing self in teammate list
        removeLabel(userId)
        return
    end

    local cur = math.floor(current + 0.5)
    local m = math.max(1, math.floor(max + 0.5))
    cur = math.clamp(cur, 0, m)

    local status = ""
    if cur <= SEKARAT_THRESHOLD then
        status = " — SEKARAT"
    end

    lbl.Text = string.format("%s: %d / %d%s", name, cur, m, status)

    -- color coding by pct
    local pct = (m > 0) and (cur / m) or 0
    if pct > 0.6 then
        lbl.TextColor3 = Color3.fromRGB(160,255,160)
    elseif pct > 0.25 then
        lbl.TextColor3 = Color3.fromRGB(255,210,110)
    else
        lbl.TextColor3 = Color3.fromRGB(255,120,120)
    end

    updateLayout()
end

-- Receive updates from server
remote.OnClientEvent:Connect(function(data)
    -- data = { userId = number, name = string, current = number, max = number, left = bool (optional) }
    if not data or not data.userId then return end

    -- Only show teammates because server only sends to teammates
    setLabel(data.userId, data.name or "Player", data.current or 0, data.max or 0, data.left)
end)

-- Cleanup when players leave
Players.PlayerRemoving:Connect(function(leaving)
    removeLabel(leaving.UserId)
end)

-- Optionally: request initial snapshot from server (not implemented here).
-- You can extend server to FireClient with initial states on player join.
