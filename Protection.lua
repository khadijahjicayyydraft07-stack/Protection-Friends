-- LocalHealthGUI.lua
-- Letakkan sebagai LocalScript di StarterPlayer > StarterPlayerScripts
-- Menampilkan "Darah: <current> / <max>" di kiri bawah hanya untuk pemain lokal.
-- Menampilkan teks "SEKARAT" ketika darah <= SEKARAT_THRESHOLD.

local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Konfigurasi tampilan
local PADDING_X = 10
local PADDING_Y = 10
local LABEL_WIDTH = 220
local LABEL_HEIGHT = 36
local FONT = Enum.Font.SourceSansBold
local FONT_SIZE = 20
local BG_COLOR = Color3.fromRGB(24, 24, 24)
local BG_TRANSPARENCY = 0.4
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)

-- Ambang batas "sekarat" (ubah sesuai keinginan; contoh: 16)
local SEKARAT_THRESHOLD = 16

local function createUI()
    local playerGui = player:WaitForChild("PlayerGui")
    local screenGui = playerGui:FindFirstChild("LocalHealthUI")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "LocalHealthUI"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = playerGui
    end

    local label = screenGui:FindFirstChild("HealthText")
    if not label then
        label = Instance.new("TextLabel")
        label.Name = "HealthText"
        label.Parent = screenGui

        label.AnchorPoint = Vector2.new(0, 1) -- bottom-left anchor
        label.Position = UDim2.new(0, PADDING_X, 1, -PADDING_Y)
        label.Size = UDim2.new(0, LABEL_WIDTH, 0, LABEL_HEIGHT)

        label.BackgroundColor3 = BG_COLOR
        label.BackgroundTransparency = BG_TRANSPARENCY
        label.BorderSizePixel = 0

        label.TextColor3 = TEXT_COLOR
        label.Font = FONT
        label.TextSize = FONT_SIZE
        label.Text = "Darah: -- / --"
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Center
        -- optional padding inside label
        -- Note: TextLabel.Padding property not available; use RichText spacing if needed.
    end

    return screenGui, label
end

local function clamp(v, a, b) if v < a then return a end if v > b then return b end return v end

local function attachToHumanoid(humanoid, label)
    if not humanoid or not label then return end

    local function update()
        local current = math.floor(humanoid.Health + 0.5)
        local max = math.floor(humanoid.MaxHealth + 0.5)
        current = clamp(current, 0, max > 0 and max or 1)
        max = math.max(1, max)

        local statusText = ""
        if current <= SEKARAT_THRESHOLD then
            statusText = " — SEKARAT"
        end

        label.Text = string.format("Darah: %d / %d%s", current, max, statusText)

        -- Warna teks berubah sesuai persentase (opsional)
        local pct = current / max
        if pct > 0.5 then
            label.TextColor3 = Color3.fromRGB(120, 255, 120) -- hijau
        elseif pct > 0.2 then
            label.TextColor3 = Color3.fromRGB(255, 200, 80)  -- kuning/oranye
        else
            label.TextColor3 = Color3.fromRGB(255, 90, 90)   -- merah
        end
    end

    -- initial
    update()

    -- sambungkan event
    local healthConn = humanoid.HealthChanged:Connect(update)
    local maxConn = humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update)

    -- kembalikan fungsi cleanup
    return function()
        if healthConn then healthConn:Disconnect() end
        if maxConn then maxConn:Disconnect() end
    end
end

-- Main flow: buat UI dan attach ke humanoid saat spawn/respawn
local screenGui, healthLabel = createUI()
local currentDisconnectFunc

local function onCharacterAdded(character)
    local humanoid = character:FindFirstChildWhichIsA("Humanoid") or character:WaitForChild("Humanoid", 5)
    if not humanoid then return end

    if currentDisconnectFunc then
        currentDisconnectFunc()
        currentDisconnectFunc = nil
    end

    currentDisconnectFunc = attachToHumanoid(humanoid, healthLabel)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
    onCharacterAdded(player.Character)
end
