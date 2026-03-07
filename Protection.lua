-- // Smart AI v14 | Xeno
-- // T=Random | Y=Target | U=Black | L=Explore
-- // Super simpel - MoveTo loop tiap 0.05s, gak pernah berhenti!

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local PFS = game:GetService("PathfindingService")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local root = char:WaitForChild("HumanoidRootPart")

player.CharacterAdded:Connect(function(c)
	char = c
	hum = c:WaitForChild("Humanoid")
	root = c:WaitForChild("HumanoidRootPart")
end)

-- ============================================================
-- GUI
-- ============================================================
local pg = player:WaitForChild("PlayerGui")
if pg:FindFirstChild("AIGUI") then pg:FindFirstChild("AIGUI"):Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "AIGUI"
gui.ResetOnSpawn = false
gui.Parent = pg

local ind = Instance.new("TextLabel", gui)
ind.Size = UDim2.new(0, 200, 0, 30)
ind.Position = UDim2.new(0, 10, 1, -42)
ind.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
ind.BorderSizePixel = 0
ind.Text = "AI: OFF"
ind.TextColor3 = Color3.fromRGB(160, 160, 160)
ind.TextScaled = true
ind.Font = Enum.Font.GothamBold
Instance.new("UICorner", ind).CornerRadius = UDim.new(0, 7)

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 300, 0, 90)
frame.Position = UDim2.new(0.5, -150, 1, -110)
frame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
frame.BorderSizePixel = 0
frame.Visible = false
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", frame).Color = Color3.fromRGB(0, 200, 100)

local tlabel = Instance.new("TextLabel", frame)
tlabel.Size = UDim2.new(1, 0, 0, 25)
tlabel.BackgroundTransparency = 1
tlabel.Text = "🤖 Ketik nama lalu Enter"
tlabel.TextColor3 = Color3.fromRGB(0, 220, 100)
tlabel.TextScaled = true
tlabel.Font = Enum.Font.GothamBold

local tinput = Instance.new("TextBox", frame)
tinput.Size = UDim2.new(1, -20, 0, 32)
tinput.Position = UDim2.new(0, 10, 0, 28)
tinput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
tinput.BorderSizePixel = 0
tinput.Text = ""
tinput.PlaceholderText = "Nama player / NPC..."
tinput.PlaceholderColor3 = Color3.fromRGB(90, 90, 90)
tinput.TextColor3 = Color3.fromRGB(255, 255, 255)
tinput.TextScaled = true
tinput.Font = Enum.Font.Gotham
tinput.ClearTextOnFocus = false
Instance.new("UICorner", tinput).CornerRadius = UDim.new(0, 6)

local tstatus = Instance.new("TextLabel", frame)
tstatus.Size = UDim2.new(1, -20, 0, 22)
tstatus.Position = UDim2.new(0, 10, 0, 63)
tstatus.BackgroundTransparency = 1
tstatus.Text = ""
tstatus.TextColor3 = Color3.fromRGB(200, 200, 200)
tstatus.TextScaled = true
tstatus.Font = Enum.Font.Gotham
tstatus.TextXAlignment = Enum.TextXAlignment.Left

-- Explore panel
local ep = Instance.new("Frame", gui)
ep.Size = UDim2.new(0, 230, 0, 110)
ep.Position = UDim2.new(0, 10, 1, -160)
ep.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
ep.BorderSizePixel = 0
ep.Visible = false
Instance.new("UICorner", ep).CornerRadius = UDim.new(0, 8)
local epS = Instance.new("UIStroke", ep)
epS.Color = Color3.fromRGB(80, 0, 255)
epS.Thickness = 2

local epT = Instance.new("TextLabel", ep)
epT.Size = UDim2.new(1, 0, 0, 22)
epT.BackgroundTransparency = 1
epT.Text = "◈ EXPLORE VISION"
epT.TextColor3 = Color3.fromRGB(120, 80, 255)
epT.TextScaled = true
epT.Font = Enum.Font.GothamBold

local epSee = Instance.new("TextLabel", ep)
epSee.Size = UDim2.new(1, -10, 0, 38)
epSee.Position = UDim2.new(0, 5, 0, 25)
epSee.BackgroundTransparency = 1
epSee.Text = "👁 Scanning..."
epSee.TextColor3 = Color3.fromRGB(0, 220, 180)
epSee.TextScaled = true
epSee.Font = Enum.Font.Gotham
epSee.TextWrapped = true
epSee.TextXAlignment = Enum.TextXAlignment.Left

local epDist = Instance.new("TextLabel", ep)
epDist.Size = UDim2.new(1, -10, 0, 22)
epDist.Position = UDim2.new(0, 5, 0, 66)
epDist.BackgroundTransparency = 1
epDist.Text = "📍 0 stud dijelajahi"
epDist.TextColor3 = Color3.fromRGB(200, 200, 100)
epDist.TextScaled = true
epDist.Font = Enum.Font.Gotham
epDist.TextXAlignment = Enum.TextXAlignment.Left

local epErr = Instance.new("TextLabel", ep)
epErr.Size = UDim2.new(1, -10, 0, 18)
epErr.Position = UDim2.new(0, 5, 0, 90)
epErr.BackgroundTransparency = 1
epErr.Text = ""
epErr.TextColor3 = Color3.fromRGB(255, 60, 60)
epErr.TextScaled = true
epErr.Font = Enum.Font.GothamBold
epErr.TextXAlignment = Enum.TextXAlignment.Left

-- ============================================================
-- ============================================================
-- BREADCRUMBS
-- ============================================================
local bcF = Instance.new("Folder", workspace)
bcF.Name = "AIBC"
local function clearBC() bcF:ClearAllChildren() end
local function makeBC(wps)
	clearBC()
	for i, wp in ipairs(wps) do
		if i == 1 then continue end
		local p = Instance.new("Part")
		p.Size = Vector3.new(0.3, 0.3, 0.3)
		p.Position = wp.Position + Vector3.new(0, 0.3, 0)
		p.Anchored = true
		p.CanCollide = false
		p.Shape = Enum.PartType.Ball
		p.Material = Enum.Material.Neon
		local t = (i-1) / math.max(#wps-1, 1)
		p.Color = Color3.fromRGB(255*(1-t), 200*t+55, 30)
		p.Parent = bcF
	end
end

-- ============================================================
-- STATE
-- ============================================================
local running = false
local loopThread = nil

local function stop()
	running = false
	if loopThread then task.cancel(loopThread) loopThread = nil end
	clearBC()
	hum.WalkSpeed = 16
	ind.Text = "AI: OFF"
	ind.TextColor3 = Color3.fromRGB(160, 160, 160)
	frame.Visible = false
	ep.Visible = false
	tstatus.Text = ""
end

-- ============================================================
-- RAYCAST JUMP - Deteksi halangan depan tiap frame
-- ============================================================
local function tryJump()
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {char}
	params.FilterType = Enum.RaycastFilterType.Exclude
	local fwd = root.CFrame.LookVector
	local org = root.Position + Vector3.new(0, 0.5, 0)
	-- Cek depan
	local hit = workspace:Raycast(org, fwd * 4, params)
	if hit then
		local h = hit.Position.Y - root.Position.Y
		if h > 0.3 and h < 6 then
			hum.Jump = true
			return
		end
	end
	-- Cek depan-bawah (step kecil)
	local hitLow = workspace:Raycast(org + fwd * 2.5, Vector3.new(0, -4, 0), params)
	if hitLow then
		local step = hitLow.Position.Y - (root.Position.Y - 2.5)
		if step > 0.4 then
			hum.Jump = true
		end
	end
end

-- ============================================================
-- COMPUTE PATH - Coba jalan alternatif kalau blocked!
-- ============================================================
local function getPath(dest, fromPos)
	fromPos = fromPos or root.Position
	local path = PFS:CreatePath({
		AgentRadius = 1,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentCanClimb = true,
		WaypointSpacing = 1.5,
	})
	local ok = pcall(function() path:ComputeAsync(fromPos, dest) end)
	if ok and path.Status == Enum.PathStatus.Success then
		return path:GetWaypoints()
	end

	-- Path gagal → coba 8 arah alternatif dari around dest
	-- Pilih yang paling JAUH dari posisi kita (hindari jalan yang sama)
	local dirs = {
		Vector3.new(8,0,0), Vector3.new(-8,0,0),
		Vector3.new(0,0,8), Vector3.new(0,0,-8),
		Vector3.new(8,0,8), Vector3.new(-8,0,8),
		Vector3.new(8,0,-8), Vector3.new(-8,0,-8),
	}
	local bestWps, bestDist = nil, 0
	for _, offset in ipairs(dirs) do
		local altDest = dest + offset
		local altPath = PFS:CreatePath({
			AgentRadius = 1,
			AgentHeight = 5,
			AgentCanJump = true,
			AgentCanClimb = true,
			WaypointSpacing = 1.5,
		})
		local altOk = pcall(function() altPath:ComputeAsync(fromPos, altDest) end)
		if altOk and altPath.Status == Enum.PathStatus.Success then
			local wps = altPath:GetWaypoints()
			-- Pilih path yang paling panjang (paling jauh = hindari tembok)
			local pathLen = 0
			for i = 2, #wps do
				pathLen += (wps[i].Position - wps[i-1].Position).Magnitude
			end
			if pathLen > bestDist then
				bestDist = pathLen
				bestWps = wps
			end
		end
	end
	return bestWps
end

-- ============================================================
-- CORE LOOP - INTI SEGALANYA
-- getDest() dipanggil terus, MoveTo ke waypoint aktif tiap 0.05s
-- ============================================================
local function startLoop(getDest, speed, label, color, onArrive)
	stop()
	running = true
	hum.WalkSpeed = speed
	ind.Text = label
	ind.TextColor3 = color

	loopThread = task.spawn(function()
		local wps = nil
		local wi = 1
		local lastDest = Vector3.zero
		local stuckPos = root.Position
		local stuckT = 0
		local recompTimer = 0

		while running do
			local dest = getDest()
			if not dest then stop() break end

			local myXZ = Vector2.new(root.Position.X, root.Position.Z)
			local dXZ  = Vector2.new(dest.X, dest.Z)

			-- Cek sampai (2D)
			if (myXZ - dXZ).Magnitude < 4.5 then
				if onArrive then onArrive(dest) end
				task.wait(0.05)
				wps = nil
				wi = 1
				lastDest = Vector3.zero
				recompTimer = 0
				continue
			end

			-- Recompute tiap 2 detik ATAU dest pindah jauh
			recompTimer -= 0.05
			local destMoved = (dest - lastDest).Magnitude
			if destMoved > 5 or wps == nil or recompTimer <= 0 then
				lastDest = dest
				recompTimer = 2
				local newWps = getPath(dest)
				-- Hanya ganti kalau dapat path valid
				if newWps and #newWps > 1 then
					wps = newWps
					wi = 2
					makeBC(wps) -- ✅ Spawn kotak titik otomatis!
				end
			end

			-- Maju wi SATU PER SATU kalau udah deket (2D XZ)
			if wps and wi <= #wps then
				local wpXZ = Vector2.new(wps[wi].Position.X, wps[wi].Position.Z)
				if (myXZ - wpXZ).Magnitude < 3 then
					wi += 1
				end
			end

			-- Tentukan target
			local target = dest
			if wps and wi <= #wps then
				local aw = wps[wi]
				if aw.Position.Y - root.Position.Y > 0.7 then
					hum.Jump = true
				end
				if aw.Action == Enum.PathWaypointAction.Jump then
					hum.Jump = true
				end
				target = aw.Position
			end

			hum:MoveTo(target)

			-- ✅ Raycast jump tiap frame!
			tryJump()

			-- Stuck check
			if (root.Position - stuckPos).Magnitude < 0.5 then
				stuckT += 0.05
				if stuckT > 1.5 then
					hum.Jump = true
					wps = nil
					stuckT = 0
				end
			else
				stuckT = 0
				stuckPos = root.Position
			end

			task.wait(0.05)
		end
	end)
end

-- ============================================================
-- VISITED ZONES
-- ============================================================
local visited = {}
local function visited_has(pos)
	for _, z in ipairs(visited) do
		if (Vector3.new(pos.X,0,pos.Z) - Vector3.new(z.X,0,z.Z)).Magnitude < 18 then
			return true
		end
	end
	return false
end
local function visited_add(pos)
	if not visited_has(pos) then
		table.insert(visited, pos)
		if #visited > 25 then table.remove(visited, 1) end
	end
end
local function randDest(range)
	for _ = 1, 20 do
		local c = root.Position + Vector3.new(math.random(-range,range), 0, math.random(-range,range))
		if not visited_has(c) then return c end
	end
	visited = {}
	return root.Position + Vector3.new(math.random(-range,range), 0, math.random(-range,range))
end

-- ============================================================
-- T: RANDOM
-- ============================================================
local randomDest = Vector3.zero
local function doRandom()
	visited = {}
	randomDest = randDest(50)

	startLoop(
		function() return randomDest end,
		16,
		"AI: 🟡 RANDOM",
		Color3.fromRGB(255, 200, 0),
		function(d)
			visited_add(d)
			if math.random(1,4) == 1 then hum.Jump = true end
			randomDest = randDest(50)
		end
	)
end

-- ============================================================
-- Y: TARGET
-- ============================================================
local function findTarget(name)
	name = name:lower()
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower() == name and p ~= player then
			local c = p.Character
			if c and c:FindFirstChild("HumanoidRootPart") then return c end
		end
	end
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj.Name:lower() == name and obj ~= char then
			if obj:FindFirstChild("HumanoidRootPart") and obj:FindFirstChildOfClass("Humanoid") then
				return obj
			end
		end
	end
	return nil
end

local function doTarget(target)
	frame.Visible = true

	-- BC update tiap 0.6 detik
	task.spawn(function()
		local dots = 0
		while running and frame.Visible do
			local hrp = target:FindFirstChild("HumanoidRootPart")
			if hrp then
				dots = (dots%3)+1
				local d = math.floor((root.Position-hrp.Position).Magnitude)
				tstatus.Text = "🟢 "..target.Name..string.rep(".", dots).." "..d.." stud"
				tstatus.TextColor3 = Color3.fromRGB(0,220,100)
			end
			task.wait(0.4)
		end
	end)

	-- BC spawner
	task.spawn(function()
		local lastBC = Vector3.zero
		while running and frame.Visible do
			local hrp = target:FindFirstChild("HumanoidRootPart")
			if hrp and (hrp.Position - lastBC).Magnitude > 6 then
				lastBC = hrp.Position
				local wps = getPath(hrp.Position)
				if wps then makeBC(wps) end
			end
			task.wait(0.6)
		end
		clearBC()
	end)

	startLoop(
		function()
			local hrp = target:FindFirstChild("HumanoidRootPart")
			if not hrp or not target.Parent then
				tstatus.Text = "❌ Target hilang!"
				tstatus.TextColor3 = Color3.fromRGB(255,80,80)
				return nil
			end
			return hrp.Position
		end,
		32,
		"AI: 🟢 TARGET",
		Color3.fromRGB(0, 220, 100),
		function()
			tstatus.Text = "✅ Sampai!"
			tstatus.TextColor3 = Color3.fromRGB(100,255,180)
			ind.Text = "AI: ✅ FOUND"
			ind.TextColor3 = Color3.fromRGB(100,255,180)
			clearBC()
			task.delay(2, stop)
		end
	)
end

-- ============================================================
-- U: PART HITAM
-- ============================================================
local function doBlack()
	local closest, best = nil, math.huge
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and not obj:IsDescendantOf(char) then
			local c = obj.Color
			if c.R < 0.15 and c.G < 0.15 and c.B < 0.15 then
				local d = (root.Position-obj.Position).Magnitude
				if d < best then closest=obj best=d end
			end
		end
	end
	if not closest then
		ind.Text = "AI: ❌ NO BLACK"
		ind.TextColor3 = Color3.fromRGB(255,80,80)
		task.delay(2, function() ind.Text="AI: OFF" ind.TextColor3=Color3.fromRGB(160,160,160) end)
		return
	end

	startLoop(
		function()
			if not closest or not closest.Parent then return nil end
			local d = math.floor((root.Position-closest.Position).Magnitude)
			ind.Text = "AI: ⬛ "..d.." stud"
			return closest.Position
		end,
		32,
		"AI: ⬛ ...",
		Color3.fromRGB(200,200,200),
		function()
			ind.Text = "AI: ✅ BLACK!"
			ind.TextColor3 = Color3.fromRGB(180,255,180)
			task.delay(2, stop)
		end
	)
end

-- ============================================================
-- L: EXPLORE
-- ============================================================
local errSeq = {
	"⚠ System Error. Debugging...",
	"❌ System Fail.",
	"ERROR.",
	"ERROR. ERROR.",
	"ERROR. ERROR. ERROR.",
	"💀 CRITICAL FAILURE",
	"🔴 SYSTEM MELTDOWN",
	"☠ ALL SYSTEMS DOWN",
}
local partNames = {"Chair","Table","Door","Wall","Floor","Seat","Desk","Lamp","Bed","Sofa","Kursi","Meja","Pintu","Stairs","Ramp","Spawn"}

local explDest = Vector3.zero
local function doExplore()
	ep.Visible = true
	visited = {}
	explDest = randDest(60)

	local totalDist = 0
	local lastPos = root.Position
	local errLv = 0
	local lastD = 0

	-- Vision update
	task.spawn(function()
		while running and ep.Visible do
			local moved = (root.Position-lastPos).Magnitude
			totalDist += moved
			lastPos = root.Position
			epDist.Text = "📍 "..math.floor(totalDist).." stud dijelajahi"

			local seen, checked = {}, {}
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj:IsA("BasePart") and not obj:IsDescendantOf(char) then
					local d = (root.Position-obj.Position).Magnitude
					if d > 30 then continue end
					for _, n in ipairs(partNames) do
						if obj.Name:lower():find(n:lower()) and not checked[n] then
							table.insert(seen, obj.Name.."("..math.floor(d).."s)")
							checked[n] = true
							break
						end
					end
				end
			end
			if #seen > 0 then
				epSee.Text = "👁 "..table.concat(seen, ", ", 1, math.min(3,#seen))
				epSee.TextColor3 = Color3.fromRGB(0,220,180)
			else
				epSee.Text = "👁 Tidak melihat apapun..."
				epSee.TextColor3 = Color3.fromRGB(120,120,120)
			end
			task.wait(0.5)
		end
	end)

	-- Error tracker
	task.spawn(function()
		while running and ep.Visible do
			task.wait(2)
			local d = (root.Position - explDest).Magnitude
			if math.abs(d - lastD) < 1.5 then
				errLv = math.min(errLv+1, #errSeq)
				epErr.Text = errSeq[errLv]
				if errLv >= 5 then
					task.spawn(function()
						for _ = 1,3 do
							epS.Color = Color3.fromRGB(255,0,0)
							task.wait(0.1)
							epS.Color = Color3.fromRGB(80,0,255)
							task.wait(0.1)
						end
					end)
				end
			else
				errLv = math.max(0, errLv-1)
				if errLv == 0 then epErr.Text = "" end
			end
			lastD = d
		end
	end)

	startLoop(
		function() return explDest end,
		20,
		"AI: 🔮 EXPLORE",
		Color3.fromRGB(120, 80, 255),
		function(d)
			visited_add(d)
			explDest = randDest(60)
		end
	)
end

-- ============================================================
-- TOMBOL
-- ============================================================
UIS.InputBegan:Connect(function(key, gp)
	if gp then return end
	if key.KeyCode == Enum.KeyCode.T then
		if running then stop() else doRandom() end
	elseif key.KeyCode == Enum.KeyCode.Y then
		if running then
			stop()
		else
			frame.Visible = not frame.Visible
			if frame.Visible then
				tinput.Text = ""
				tinput:CaptureFocus()
				tstatus.Text = "Ketik nama lalu Enter"
				tstatus.TextColor3 = Color3.fromRGB(160,160,160)
			end
		end
	elseif key.KeyCode == Enum.KeyCode.U then
		if running then stop() else doBlack() end
	elseif key.KeyCode == Enum.KeyCode.L then
		if running then stop() else doExplore() end
	end
end)

tinput.FocusLost:Connect(function(enter)
	if not enter then return end
	local name = tinput.Text:match("^%s*(.-)%s*$")
	if name == "" then return end
	local found = findTarget(name)
	if found then
		tstatus.Text = "🔍 Ketemu "..found.Name
		tstatus.TextColor3 = Color3.fromRGB(0,200,255)
		doTarget(found)
	else
		tstatus.Text = "❌ '"..name.."' gak ada!"
		tstatus.TextColor3 = Color3.fromRGB(255,80,80)
		task.wait(2)
		tstatus.Text = "Ketik nama lalu Enter"
		tstatus.TextColor3 = Color3.fromRGB(160,160,160)
	end
end)

print("[Smart AI v14] ✅ T=Random | Y=Target | U=Black | L=Explore | I=Combat ⚔️")
