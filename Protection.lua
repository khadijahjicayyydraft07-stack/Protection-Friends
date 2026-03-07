--[[
    ╔══════════════════════════════════════════════╗
    ║         COMBAT AI - JJS Edition              ║
    ║  Features:                                   ║
    ║  1. Autocomplete nama (Tab)                  ║
    ║  2. Dash Q (kanan/kiri/depan/belakang)       ║
    ║  3. Kamera selalu hadap musuh                ║
    ║  4. Running speed                            ║
    ║  5. Skill 2 setelah 3x M1                    ║
    ║  6. Mode Passive                             ║
    ║  7. Di-block → dash belakang musuh           ║
    ║  8. Kadang loncat                            ║
    ╚══════════════════════════════════════════════╝
]]

-- ═══════════════════════════════════════
--              SERVICES
-- ═══════════════════════════════════════
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService   = game:GetService("TweenService")
local HttpService    = game:GetService("HttpService")

local LocalPlayer    = Players.LocalPlayer
local Character      = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid       = Character:WaitForChild("Humanoid")
local HRP            = Character:WaitForChild("HumanoidRootPart")
local Camera         = workspace.CurrentCamera

-- ═══════════════════════════════════════
--              KONFIGURASI
-- ═══════════════════════════════════════
local CONFIG = {
    -- Target
    TARGET_NAME       = "",          -- Diisi via autocomplete Tab
    
    -- AI Mode
    ACTIVE            = false,       -- Toggle ON/OFF
    PASSIVE_MODE      = false,       -- Mode passive (tidak serang duluan)

    -- Speed & Distance
    RUN_SPEED         = 28,          -- Kecepatan lari ke musuh
    ATTACK_RANGE      = 6,           -- Jarak mulai serang
    PASSIVE_RANGE     = 20,          -- Jarak aman mode passive
    
    -- Combat Timing (detik)
    M1_COOLDOWN       = 0.35,        -- Jeda antar M1
    SKILL2_COOLDOWN   = 1.2,         -- Jeda Skill 2
    DASH_COOLDOWN     = 0.8,         -- Jeda Dash Q
    JUMP_CHANCE       = 0.18,        -- Probabilitas loncat (0–1)
    JUMP_COOLDOWN     = 2.0,         -- Min jeda antar loncat
    BEHIND_DASH_DELAY = 0.15,        -- Delay sebelum dash balik kalau di-block

    -- Camera
    CAM_LOCK          = true,        -- Lock kamera ke musuh
    CAM_SMOOTH        = 0.12,        -- Smooth factor (0.05 = smooth, 0.3 = cepat)

    -- Keybind
    TOGGLE_KEY        = Enum.KeyCode.RightAlt,
    DASH_KEY          = Enum.KeyCode.Q,
    AUTOCOMPLETE_KEY  = Enum.KeyCode.Tab,
    PASSIVE_KEY       = Enum.KeyCode.P,
}

-- ═══════════════════════════════════════
--              STATE
-- ═══════════════════════════════════════
local State = {
    target         = nil,
    m1Count        = 0,
    lastM1         = 0,
    lastSkill2     = 0,
    lastDash       = 0,
    lastJump       = 0,
    isBlocked      = false,
    isDashing      = false,
    tabIndex       = 1,
    tabCandidates  = {},
    partialName    = "",
}

-- ═══════════════════════════════════════
--              UI (Simple Status HUD)
-- ═══════════════════════════════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name          = "CombatAI_HUD"
ScreenGui.ResetOnSpawn  = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent        = LocalPlayer:WaitForChild("PlayerGui")

local Frame = Instance.new("Frame")
Frame.Size              = UDim2.new(0, 260, 0, 160)
Frame.Position          = UDim2.new(0, 12, 0.5, -80)
Frame.BackgroundColor3  = Color3.fromRGB(10, 10, 15)
Frame.BackgroundTransparency = 0.25
Frame.BorderSizePixel   = 0
Frame.Parent            = ScreenGui
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 10)

local function makeLabel(yPos, size)
    local lbl = Instance.new("TextLabel")
    lbl.Size               = UDim2.new(1, -16, 0, 22)
    lbl.Position           = UDim2.new(0, 8, 0, yPos)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3         = Color3.fromRGB(220, 220, 220)
    lbl.TextSize           = size or 14
    lbl.Font               = Enum.Font.GothamBold
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.Parent             = Frame
    return lbl
end

local TitleLbl  = makeLabel(6,  16)  TitleLbl.Text  = "⚔  COMBAT AI  —  JJS"
local StatusLbl = makeLabel(30, 13)
local TargetLbl = makeLabel(52, 13)
local ModeLbl   = makeLabel(74, 13)
local M1Lbl     = makeLabel(96, 13)
local InputLbl  = makeLabel(126, 12) InputLbl.TextColor3 = Color3.fromRGB(140,200,255)

local function updateHUD()
    local active  = CONFIG.ACTIVE
    local passive = CONFIG.PASSIVE_MODE

    StatusLbl.Text  = "Status  :  " .. (active and "🟢 ON" or "🔴 OFF")
    StatusLbl.TextColor3 = active
        and Color3.fromRGB(100,255,130)
        or  Color3.fromRGB(255,90,90)

    TargetLbl.Text  = "Target  :  " .. (CONFIG.TARGET_NAME ~= "" and CONFIG.TARGET_NAME or "—")
    ModeLbl.Text    = "Mode    :  " .. (passive and "🛡 Passive" or "⚔ Aggressive")
    M1Lbl.Text      = "M1 Combo:  " .. State.m1Count .. " / 3"
    InputLbl.Text   = "Tab=Autocomplete  |  P=Passive  |  RAlt=Toggle"
end
updateHUD()

-- ═══════════════════════════════════════
--         AUTOCOMPLETE (Tab)
-- ═══════════════════════════════════════
--[[
  Cara pakai:
  1. Ketik nama sebagian di kolom chat (atau gunakan nama langsung)
  2. Tekan Tab → daftar pemain yang cocok ditampilkan
  3. Tekan Tab lagi → siklus ke nama berikutnya
  4. Enter / mulai combat → nama terkunci sebagai TARGET
]]

local function getPlayerCandidates(partial)
    local results = {}
    local lp = partial:lower()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Name:lower():sub(1, #lp) == lp then
            table.insert(results, p.Name)
        end
    end
    -- Juga coba full match di tengah
    if #results == 0 then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Name:lower():find(lp, 1, true) then
                table.insert(results, p.Name)
            end
        end
    end
    return results
end

local function cycleAutocomplete()
    -- Ambil partial dari nama yang sudah diset (atau kosong)
    local partial = State.partialName

    if #State.tabCandidates == 0 or State.partialName == "" then
        -- Refresh kandidat
        State.tabCandidates = getPlayerCandidates(partial)
        State.tabIndex = 1
    else
        State.tabIndex = (State.tabIndex % #State.tabCandidates) + 1
    end

    if #State.tabCandidates > 0 then
        local chosen = State.tabCandidates[State.tabIndex]
        CONFIG.TARGET_NAME = chosen
        -- Cari character-nya langsung
        local p = Players:FindFirstChild(chosen)
        if p and p.Character then
            State.target = p.Character
        end
        updateHUD()
        -- Tampilkan kandidat di label input sebentar
        local list = table.concat(State.tabCandidates, "  |  ")
        InputLbl.Text = "[ " .. list .. " ]"
        task.delay(3, function()
            InputLbl.Text = "Tab=Autocomplete  |  P=Passive  |  RAlt=Toggle"
        end)
    else
        InputLbl.Text = "❌ Tidak ada pemain ditemukan"
        task.delay(2, function()
            InputLbl.Text = "Tab=Autocomplete  |  P=Passive  |  RAlt=Toggle"
        end)
    end
end

-- Saat pemain baru join, reset kandidat supaya fresh
Players.PlayerAdded:Connect(function()
    State.tabCandidates = {}
end)
Players.PlayerRemoving:Connect(function(p)
    if CONFIG.TARGET_NAME == p.Name then
        CONFIG.TARGET_NAME = ""
        State.target = nil
        State.tabCandidates = {}
        updateHUD()
    end
end)

-- ═══════════════════════════════════════
--         UTILITY FUNCTIONS
-- ═══════════════════════════════════════
local function getTarget()
    if State.target and State.target.Parent then
        local h = State.target:FindFirstChildOfClass("Humanoid")
        if h and h.Health > 0 then
            return State.target
        end
    end
    -- Auto-cari ulang dari nama
    if CONFIG.TARGET_NAME ~= "" then
        local p = Players:FindFirstChild(CONFIG.TARGET_NAME)
        if p and p.Character then
            local h = p.Character:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 then
                State.target = p.Character
                return State.target
            end
        end
    end
    return nil
end

local function getTargetHRP(tgt)
    return tgt and tgt:FindFirstChild("HumanoidRootPart")
end

local function distanceTo(targetHRP)
    if not targetHRP then return math.huge end
    return (HRP.Position - targetHRP.Position).Magnitude
end

local function now()
    return tick()
end

-- ═══════════════════════════════════════
--         DASH Q  (kanan/kiri/depan/belakang)
-- ═══════════════════════════════════════
local function performDash(direction)
    -- direction: "right" | "left" | "forward" | "backward"
    if State.isDashing then return end
    if (now() - State.lastDash) < CONFIG.DASH_COOLDOWN then return end

    State.isDashing = true
    State.lastDash = now()

    local cf    = HRP.CFrame
    local dirs  = {
        forward  =  cf.LookVector,
        backward = -cf.LookVector,
        right    =  cf.RightVector,
        left     = -cf.RightVector,
    }
    local vec = dirs[direction] or dirs["forward"]
    local goal = HRP.Position + vec * 22 + Vector3.new(0, 0.5, 0)

    -- Simpan & naikkan speed
    local prevSpeed = Humanoid.WalkSpeed
    Humanoid.WalkSpeed = 0

    -- Tween HRP
    local tween = TweenService:Create(HRP, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        CFrame = CFrame.new(goal, goal + cf.LookVector)
    })
    tween:Play()
    tween.Completed:Wait()

    Humanoid.WalkSpeed = prevSpeed
    State.isDashing = false
end

-- ═══════════════════════════════════════
--         DASH BELAKANG MUSUH (saat di-block)
-- ═══════════════════════════════════════
local function dashBehindEnemy(tgtHRP)
    if not tgtHRP then return end
    if State.isDashing then return end
    if (now() - State.lastDash) < CONFIG.DASH_COOLDOWN then return end

    State.isDashing = true
    State.lastDash = now()

    local enemyBack  = tgtHRP.CFrame * CFrame.new(0, 0, 3.5)  -- tepat di belakang musuh
    local lookDir    = tgtHRP.CFrame.LookVector

    local prevSpeed = Humanoid.WalkSpeed
    Humanoid.WalkSpeed = 0

    local tween = TweenService:Create(HRP, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        CFrame = CFrame.new(enemyBack.Position, enemyBack.Position + lookDir)
    })
    tween:Play()
    tween.Completed:Wait()

    Humanoid.WalkSpeed = prevSpeed
    State.isDashing = false
end

-- ═══════════════════════════════════════
--         SIMULATE INPUT (M1 / Skill)
-- ═══════════════════════════════════════
-- Roblox tidak bisa VirtualInputManager di kebanyakan exploit,
-- tapi di executor (mis. Synapse/KRNL) gunakan:

local VIM = game:GetService("VirtualInputManager") -- Untuk executor
-- Fallback: fireproximityprompt / remote jika game pakai custom combat

local function simulateClick()
    -- M1 / klik kiri
    pcall(function()
        VIM:SendMouseButtonEvent(0, 0, 0, true,  game, 1)  -- down
        task.wait(0.05)
        VIM:SendMouseButtonEvent(0, 0, 0, false, game, 1)  -- up
    end)
end

local function simulateKey(keyCode)
    pcall(function()
        VIM:SendKeyEvent(true,  keyCode, false, game)
        task.wait(0.05)
        VIM:SendKeyEvent(false, keyCode, false, game)
    end)
end

-- ═══════════════════════════════════════
--         KAMERA LOCK KE MUSUH
-- ═══════════════════════════════════════
local camConnection
local function startCameraLock()
    if camConnection then camConnection:Disconnect() end
    camConnection = RunService.RenderStepped:Connect(function()
        if not CONFIG.CAM_LOCK or not CONFIG.ACTIVE then return end
        local tgt = getTarget()
        local tgtHRP = getTargetHRP(tgt)
        if not tgtHRP then return end

        -- Posisi kamera: agak di belakang & atas player
        local camPos   = HRP.Position + Vector3.new(0, 4, 0) - HRP.CFrame.LookVector * 10
        local aimPoint = tgtHRP.Position + Vector3.new(0, 2, 0)

        Camera.CameraType = Enum.CameraType.Scriptable
        Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(camPos, aimPoint), CONFIG.CAM_SMOOTH)
    end)
end

local function stopCameraLock()
    if camConnection then
        camConnection:Disconnect()
        camConnection = nil
    end
    Camera.CameraType = Enum.CameraType.Custom
end

-- ═══════════════════════════════════════
--         RUNNING SPEED
-- ═══════════════════════════════════════
local function setRunSpeed(active)
    if active then
        Humanoid.WalkSpeed = CONFIG.RUN_SPEED
    else
        Humanoid.WalkSpeed = 16  -- default Roblox
    end
end

-- ═══════════════════════════════════════
--         DETEKSI BLOCK (sederhana)
-- ═══════════════════════════════════════
-- Logika: jika M1 tidak mengurangi HP musuh dalam window tertentu,
-- diasumsikan di-block. Bisa dimodif sesuai game.
local function checkBlocked(tgtChar)
    if not tgtChar then return false end
    local h = tgtChar:FindFirstChildOfClass("Humanoid")
    if not h then return false end
    -- Simpan HP sebelum M1, cek setelah 0.3 detik
    -- Diimplementasikan di loop utama via State.isBlocked
    return State.isBlocked
end

-- ═══════════════════════════════════════
--         COMBAT LOOP UTAMA
-- ═══════════════════════════════════════
local lastHPCheck    = 0
local lastTargetHP   = math.huge
local combatRunning  = false

local function combatLoop()
    if combatRunning then return end
    combatRunning = true

    RunService.Heartbeat:Connect(function(dt)
        if not CONFIG.ACTIVE then
            setRunSpeed(false)
            return
        end

        local tgt    = getTarget()
        local tgtHRP = getTargetHRP(tgt)

        if not tgt or not tgtHRP then
            Humanoid.WalkSpeed = 16
            return
        end

        local dist = distanceTo(tgtHRP)

        -- ─── MODE PASSIVE ───────────────────────────────
        if CONFIG.PASSIVE_MODE then
            -- Jaga jarak aman, tidak serang duluan
            if dist < CONFIG.PASSIVE_RANGE then
                -- Mundur menjauhi musuh
                local awayDir = (HRP.Position - tgtHRP.Position).Unit
                Humanoid:MoveTo(HRP.Position + awayDir * 6)
            end
            -- Kamera tetap lock
            return
        end

        -- ─── RUNNING SPEED ke musuh ─────────────────────
        setRunSpeed(true)

        -- ─── FACING musuh ───────────────────────────────
        if dist > CONFIG.ATTACK_RANGE then
            Humanoid:MoveTo(tgtHRP.Position)
        else
            -- Berhenti & hadap musuh
            Humanoid.WalkSpeed = 0
            HRP.CFrame = HRP.CFrame:Lerp(
                CFrame.new(HRP.Position, Vector3.new(tgtHRP.Position.X, HRP.Position.Y, tgtHRP.Position.Z)),
                0.25
            )
            Humanoid.WalkSpeed = CONFIG.RUN_SPEED
        end

        -- ─── BLOCK DETECTION ─────────────────────────────
        local t = now()
        if (t - lastHPCheck) > 0.4 then
            local tgtH = tgt:FindFirstChildOfClass("Humanoid")
            if tgtH then
                if tgtH.Health >= lastTargetHP and State.m1Count > 0 then
                    State.isBlocked = true
                else
                    State.isBlocked = false
                end
                lastTargetHP = tgtH.Health
            end
            lastHPCheck = t
        end

        -- ─── KALAU DI-BLOCK → DASH BELAKANG ─────────────
        if State.isBlocked then
            task.delay(CONFIG.BEHIND_DASH_DELAY, function()
                dashBehindEnemy(tgtHRP)
                State.isBlocked = false
                State.m1Count = 0
            end)
            return
        end

        -- ─── COMBAT di range serang ──────────────────────
        if dist <= CONFIG.ATTACK_RANGE then

            -- Skill 2 setelah 3x M1
            if State.m1Count >= 3 then
                if (t - State.lastSkill2) >= CONFIG.SKILL2_COOLDOWN then
                    -- Tekan E (sesuaikan keyCode ke game)
                    simulateKey(Enum.KeyCode.E)
                    State.lastSkill2 = t
                    State.m1Count = 0
                    task.wait(0.4)
                end
                return
            end

            -- M1 attack
            if (t - State.lastM1) >= CONFIG.M1_COOLDOWN then
                simulateClick()
                State.m1Count = State.m1Count + 1
                State.lastM1 = t
            end

            -- Loncat kadang-kadang
            if (t - State.lastJump) >= CONFIG.JUMP_COOLDOWN then
                if math.random() < CONFIG.JUMP_CHANCE then
                    Humanoid.Jump = true
                    State.lastJump = t
                end
            end
        end

        updateHUD()
    end)
end

-- ═══════════════════════════════════════
--         INPUT HANDLING
-- ═══════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    -- Toggle AI ON/OFF
    if input.KeyCode == CONFIG.TOGGLE_KEY then
        CONFIG.ACTIVE = not CONFIG.ACTIVE
        if CONFIG.ACTIVE then
            setRunSpeed(true)
            startCameraLock()
            combatLoop()
        else
            setRunSpeed(false)
            stopCameraLock()
        end
        updateHUD()
        return
    end

    -- Toggle Passive Mode
    if input.KeyCode == CONFIG.PASSIVE_KEY then
        CONFIG.PASSIVE_MODE = not CONFIG.PASSIVE_MODE
        updateHUD()
        return
    end

    -- Autocomplete Tab
    if input.KeyCode == CONFIG.AUTOCOMPLETE_KEY then
        -- Baca partial dari chat jika bisa, atau kosong = list semua
        -- Jika ingin dari chat: ambil dari TextBox fokus
        local focused = UserInputService:GetFocusedTextBox()
        if focused then
            State.partialName = focused.Text or ""
        else
            State.partialName = ""
        end
        State.tabCandidates = getPlayerCandidates(State.partialName)
        State.tabIndex = 0
        cycleAutocomplete()
        return
    end

    -- Skip jika game sedang proses input (chat dll)
    if gameProcessed then return end

    -- Dash Q
    if input.KeyCode == CONFIG.DASH_KEY then
        -- Deteksi arah via WASD
        local moveVec = Humanoid.MoveDirection

        -- Tentukan arah terkuat
        local cf = HRP.CFrame
        local fwd   = cf.LookVector
        local rgt   = cf.RightVector

        local fDot  = moveVec:Dot(fwd)
        local rDot  = moveVec:Dot(rgt)

        local dashDir
        if math.abs(fDot) >= math.abs(rDot) then
            dashDir = fDot >= 0 and "forward" or "backward"
        else
            dashDir = rDot >= 0 and "right" or "left"
        end

        -- Default: kalau diam, dash forward
        if moveVec.Magnitude < 0.1 then dashDir = "forward" end

        performDash(dashDir)
        return
    end
end)

-- ═══════════════════════════════════════
--         CHARACTER RESPAWN HANDLER
-- ═══════════════════════════════════════
LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    Humanoid = char:WaitForChild("Humanoid")
    HRP      = char:WaitForChild("HumanoidRootPart")
    State.m1Count   = 0
    State.isBlocked = false
    State.isDashing = false
    if CONFIG.ACTIVE then
        startCameraLock()
        combatLoop()
    end
    updateHUD()
end)

-- ═══════════════════════════════════════
--         INIT
-- ═══════════════════════════════════════
print("╔══════════════════════════════════╗")
print("║  Combat AI JJS — Loaded!         ║")
print("║  RightAlt  = Toggle ON/OFF        ║")
print("║  Tab       = Autocomplete target  ║")
print("║  Q         = Dash (WASD arah)     ║")
print("║  P         = Toggle Passive Mode  ║")
print("╚══════════════════════════════════╝")
updateHUD()
