-- // Combat AI v2 | Jujutsu Shenanigans
-- // T=Nama | Y=Start/Stop

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local PFS = game:GetService("PathfindingService")
local RS = game:GetService("RunService")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local root = char:WaitForChild("HumanoidRootPart")
local cam = workspace.CurrentCamera

player.CharacterAdded:Connect(function(c)
	char=c hum=c:WaitForChild("Humanoid") root=c:WaitForChild("HumanoidRootPart")
end)

-- GUI
local pg = player:WaitForChild("PlayerGui")
if pg:FindFirstChild("CAIG") then pg:FindFirstChild("CAIG"):Destroy() end
local gui = Instance.new("ScreenGui") gui.Name="CAIG" gui.ResetOnSpawn=false gui.Parent=pg

local ind = Instance.new("TextLabel",gui)
ind.Size=UDim2.new(0,220,0,30) ind.Position=UDim2.new(0,10,1,-42)
ind.BackgroundColor3=Color3.fromRGB(18,18,18) ind.BorderSizePixel=0
ind.Text="⚔️ COMBAT: OFF" ind.TextColor3=Color3.fromRGB(160,160,160)
ind.TextScaled=true ind.Font=Enum.Font.GothamBold
Instance.new("UICorner",ind).CornerRadius=UDim.new(0,7)

local frame = Instance.new("Frame",gui)
frame.Size=UDim2.new(0,300,0,100) frame.Position=UDim2.new(0.5,-150,1,-120)
frame.BackgroundColor3=Color3.fromRGB(18,18,18) frame.BorderSizePixel=0 frame.Visible=false
Instance.new("UICorner",frame).CornerRadius=UDim.new(0,10)
Instance.new("UIStroke",frame).Color=Color3.fromRGB(255,60,60)

local tlabel=Instance.new("TextLabel",frame)
tlabel.Size=UDim2.new(1,0,0,25) tlabel.BackgroundTransparency=1
tlabel.Text="⚔️ Ketik nama musuh" tlabel.TextColor3=Color3.fromRGB(255,60,60)
tlabel.TextScaled=true tlabel.Font=Enum.Font.GothamBold

local tinput=Instance.new("TextBox",frame)
tinput.Size=UDim2.new(1,-20,0,32) tinput.Position=UDim2.new(0,10,0,28)
tinput.BackgroundColor3=Color3.fromRGB(35,35,35) tinput.BorderSizePixel=0
tinput.Text="" tinput.PlaceholderText="Nama player / NPC..."
tinput.PlaceholderColor3=Color3.fromRGB(90,90,90)
tinput.TextColor3=Color3.fromRGB(255,255,255) tinput.TextScaled=true
tinput.Font=Enum.Font.Gotham tinput.ClearTextOnFocus=false
Instance.new("UICorner",tinput).CornerRadius=UDim.new(0,6)

-- Autocomplete label (bayangan nama)
local autoLabel=Instance.new("TextLabel",frame)
autoLabel.Size=UDim2.new(1,-20,0,32) autoLabel.Position=UDim2.new(0,10,0,28)
autoLabel.BackgroundTransparency=1 autoLabel.Text=""
autoLabel.TextColor3=Color3.fromRGB(80,80,80) autoLabel.TextScaled=true
autoLabel.Font=Enum.Font.Gotham autoLabel.TextXAlignment=Enum.TextXAlignment.Left
autoLabel.ZIndex=0

local tstatus=Instance.new("TextLabel",frame)
tstatus.Size=UDim2.new(1,-20,0,22) tstatus.Position=UDim2.new(0,10,0,72)
tstatus.BackgroundTransparency=1 tstatus.Text=""
tstatus.TextColor3=Color3.fromRGB(200,200,200) tstatus.TextScaled=true
tstatus.Font=Enum.Font.Gotham tstatus.TextXAlignment=Enum.TextXAlignment.Left

-- STATE
local running=false
local loopThread=nil
local targetChar=nil
local targetName=""
local lastHP=100
local m1Count=0
local m1Timer=0
local dashCD=false
local skill2CD=false
local skill3CD=false
local phase2=false
local passive=false
local selectMode=false

local function stop()
	running=false
	if loopThread then task.cancel(loopThread) loopThread=nil end
	hum.WalkSpeed=16 hum.JumpPower=50
	phase2=false
	ind.Text="⚔️ COMBAT: OFF" ind.TextColor3=Color3.fromRGB(160,160,160)
	frame.Visible=false
end

-- AUTOCOMPLETE
local function getPlayerNames()
	local names={}
	for _,p in ipairs(Players:GetPlayers()) do
		if p~=player then table.insert(names,p.Name) end
	end
	for _,obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj~=char and obj:FindFirstChildOfClass("Humanoid") then
			table.insert(names,obj.Name)
		end
	end
	return names
end

tinput:GetPropertyChangedSignal("Text"):Connect(function()
	local txt=tinput.Text
	if txt=="" then autoLabel.Text="" return end
	for _,name in ipairs(getPlayerNames()) do
		if name:lower():sub(1,#txt)==txt:lower() then
			autoLabel.Text=name
			return
		end
	end
	autoLabel.Text=""
end)

-- Tab = autocomplete
UIS.InputBegan:Connect(function(key,gp)
	if key.KeyCode==Enum.KeyCode.Tab and frame.Visible and autoLabel.Text~="" then
		tinput.Text=autoLabel.Text
		autoLabel.Text=""
	end
end)

-- AIM KAMERA
local aimConn=nil
local function startAim(hrp)
	if aimConn then aimConn:Disconnect() end
	aimConn=RS.RenderStepped:Connect(function()
		if not hrp or not hrp.Parent then aimConn:Disconnect() return end
		local dir=(hrp.Position-cam.CFrame.Position).Unit
		cam.CFrame=CFrame.new(cam.CFrame.Position,cam.CFrame.Position+dir)
	end)
end
local function stopAim()
	if aimConn then aimConn:Disconnect() aimConn=nil end
end

-- DASH - Click Q (game dash)
local function doDash(dir)
	if dashCD then return end
	dashCD=true
	-- Rotate dulu ke arah yang mau di-dash
	if dir=="left" then
		root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(90), 0)
	elseif dir=="right" then
		root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(-90), 0)
	elseif dir=="back" then
		root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(180), 0)
	end
	-- ✅ Click Q beneran!
	pcall(function()
		keypress(0x51)
		task.wait(0.08)
		keyrelease(0x51)
	end)
	task.delay(0.7, function() dashCD=false end)
end

-- SKILL 2
local function doSkill2()
	if skill2CD then return end
	skill2CD=true
	pcall(function() keypress(0x32) task.wait(0.1) keyrelease(0x32) end)
	task.delay(3, function() skill2CD=false end)
end

-- SKILL 3 - Dash kanan lalu kiri sambil skill 3
local function doSkill3()
	if skill3CD then return end
	skill3CD=true
	task.spawn(function()
		-- Dash kanan
		doDash("right")
		task.wait(0.15)
		-- Tekan skill 3
		pcall(function() keypress(0x33) task.wait(0.1) keyrelease(0x33) end)
		task.wait(0.15)
		-- Dash kiri
		doDash("left")
	end)
	task.delay(3, function() skill3CD=false end)
end

-- BLOCK
local function doBlock(state)
	pcall(function()
		if state then keypress(0x46) else keyrelease(0x46) end
	end)
end

-- PATHFIND
local function getPath(dest)
	local path=PFS:CreatePath({AgentRadius=1,AgentHeight=5,AgentCanJump=true,AgentCanClimb=true,WaypointSpacing=1.5})
	local ok=pcall(function() path:ComputeAsync(root.Position,dest) end)
	if ok and path.Status==Enum.PathStatus.Success then return path:GetWaypoints() end
	return nil
end

-- FIND TARGET
local function findTarget(name)
	name=name:lower()
	for _,p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():find(name) and p~=player then
			local c=p.Character
			if c and c:FindFirstChild("HumanoidRootPart") then return p.Name,c end
		end
	end
	for _,obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj.Name:lower():find(name) and obj~=char then
			if obj:FindFirstChild("HumanoidRootPart") and obj:FindFirstChildOfClass("Humanoid") then
				return obj.Name,obj end
		end
	end
	return nil,nil
end

-- MAIN COMBAT LOOP
local function startCombat()
	if not targetChar then return end
	running=true m1Count=0
	hum.WalkSpeed=24 hum.JumpPower=60
	ind.Text="⚔️ "..targetName ind.TextColor3=Color3.fromRGB(255,60,60)

	local wps,wi=nil,1
	local lastDest=Vector3.zero
	local recompT=0
	local stuckPos=root.Position
	local stuckT=0
	local dashT=0
	local jumpT=0

	-- Start aim
	local hrp=targetChar:FindFirstChild("HumanoidRootPart")
	startAim(hrp)

	loopThread=task.spawn(function()
		while running do
			hrp=targetChar:FindFirstChild("HumanoidRootPart")
			local th=targetChar:FindFirstChildOfClass("Humanoid")
			if not hrp or not targetChar.Parent or (th and th.Health<=0) then
				tstatus.Text="☠️ "..targetName.." mati!"
				tstatus.TextColor3=Color3.fromRGB(100,255,180)
				stopAim() stop() break
			end

			local dest=hrp.Position
			local myXZ=Vector2.new(root.Position.X,root.Position.Z)
			local dXZ=Vector2.new(dest.X,dest.Z)
			local dist=(myXZ-dXZ).Magnitude

			-- HP detect → block + dash belakang
			local curHP=hum and hum.Health or 100
			if curHP<lastHP-1 then
				lastHP=curHP
				tstatus.Text="🛡️ BLOCK + DASH BELAKANG!"
				tstatus.TextColor3=Color3.fromRGB(0,200,255)
				doBlock(true)
				task.wait(0.1)
				-- Dash ke belakang musuh! Muter layar dulu
				doDash("back")
				task.wait(0.3)
				doBlock(false)
				-- Rotate ke belakang target
				root.CFrame=CFrame.new(
					hrp.Position + hrp.CFrame.LookVector*2.5,
					hrp.Position
				)
			end
			lastHP=curHP

			-- Phase 2: HP < 39 → SUPER FAST!
			local curHP2 = hum and hum.Health or 100
			if curHP2 <= 39 and not phase2 then
				phase2 = true
				hum.WalkSpeed = 50
				hum.JumpPower = 80
				ind.Text = "⚔️ ⚡ PHASE 2!"
				ind.TextColor3 = Color3.fromRGB(255, 50, 255)
				-- Flash effect
				task.spawn(function()
					for _ = 1, 5 do
						ind.TextColor3 = Color3.fromRGB(255,255,0)
						task.wait(0.1)
						ind.TextColor3 = Color3.fromRGB(255,50,255)
						task.wait(0.1)
					end
				end)
			end

			-- Random loncat
			jumpT-=0.05
			if jumpT<=0 and dist<8 then
				jumpT=math.random(20,40)*0.1
				if math.random(1,3)==1 then hum.Jump=true end
			end

			-- M1 + skill logic
			m1Timer-=0.05
			if dist<6 and m1Timer<=0 then
				m1Timer = phase2 and 0.2 or 0.3
				pcall(function() mouse1press() task.wait(0.08) mouse1release() end)
				m1Count+=1
				tstatus.Text="👊 M1 x"..m1Count.." | "..targetName
				tstatus.TextColor3=Color3.fromRGB(255,60,60)

				-- Skill 3 setelah M1 ke-2 → dash kanan kiri
				if m1Count==2 then
					doSkill3()
					tstatus.Text="⚡ SKILL 3 + DASH!"
					tstatus.TextColor3=Color3.fromRGB(255,150,0)
				end
				-- Skill 2 setelah M1 ke-4
				if m1Count>=4 then
					m1Count=0
					doSkill2()
					tstatus.Text="💥 SKILL 2!"
					tstatus.TextColor3=Color3.fromRGB(255,200,0)
				end
			end

			-- Dash ke depan kalau jauh
			dashT-=0.05
			if dist>15 and dashT<=0 then
				dashT=1.5
				doDash("front")
			end

			-- Pathfind
			if dist>5 then
				hum.WalkSpeed=24
				recompT-=0.05
				if (dest-lastDest).Magnitude>4 or wps==nil or recompT<=0 then
					lastDest=dest recompT=1.5
					local nw=getPath(dest)
					if nw and #nw>1 then wps=nw wi=2 end
				end
				if wps and wi<=#wps then
					local wpXZ=Vector2.new(wps[wi].Position.X,wps[wi].Position.Z)
					if (myXZ-wpXZ).Magnitude<3 then wi+=1 end
				end
				local tgt=dest
				if wps and wi<=#wps then
					local aw=wps[wi]
					if aw.Position.Y-root.Position.Y>0.7 then hum.Jump=true end
					if aw.Action==Enum.PathWaypointAction.Jump then hum.Jump=true end
					tgt=aw.Position
				end
				hum:MoveTo(tgt)
				if (root.Position-stuckPos).Magnitude<0.5 then
					stuckT+=0.05
					if stuckT>1.5 then hum.Jump=true wps=nil stuckT=0 end
				else stuckT=0 stuckPos=root.Position end
			else
				hum.WalkSpeed=16
				root.CFrame=CFrame.new(root.Position,Vector3.new(hrp.Position.X,root.Position.Y,hrp.Position.Z))
			end

			task.wait(0.05)
		end
	end)
end

-- TOMBOL
UIS.InputBegan:Connect(function(key,gp)
	if gp then return end
	if key.KeyCode==Enum.KeyCode.T then
		stop() stopAim()
		frame.Visible=not frame.Visible
		if frame.Visible then
			tinput.Text="" tinput:CaptureFocus()
			tstatus.Text="Ketik nama musuh lalu Enter"
			tstatus.TextColor3=Color3.fromRGB(160,160,160)
		end
	elseif key.KeyCode==Enum.KeyCode.Y then
		if running then stop() stopAim()
		else
			if targetChar then startCombat()
			else
				frame.Visible=true
				tstatus.Text="⚠️ Tulis nama dulu! (T)"
				tstatus.TextColor3=Color3.fromRGB(255,200,0)
			end
		end
	elseif key.KeyCode==Enum.KeyCode.P then
		passive=not passive
		ind.Text=passive and "⚔️ PASSIVE ON" or "⚔️ "..(running and targetName or "COMBAT: OFF")
		ind.TextColor3=passive and Color3.fromRGB(0,200,255) or Color3.fromRGB(255,60,60)
	elseif key.KeyCode==Enum.KeyCode.U then
		-- U = Select target dari list player terdekat
		if selectMode then
			selectMode=false
			ind.Text=running and "⚔️ "..targetName or "⚔️ COMBAT: OFF"
			ind.TextColor3=running and Color3.fromRGB(255,60,60) or Color3.fromRGB(160,160,160)
		else
			selectMode=true
			stop() stopAim()
			-- Cari semua target tersedia
			local targets={}
			for _,p in ipairs(Players:GetPlayers()) do
				if p~=player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
					local d=math.floor((root.Position-p.Character.HumanoidRootPart.Position).Magnitude)
					table.insert(targets,{name=p.Name,char=p.Character,dist=d})
				end
			end
			table.sort(targets,function(a,b) return a.dist<b.dist end)
			if #targets==0 then
				ind.Text="⚔️ Gak ada target!"
				ind.TextColor3=Color3.fromRGB(255,80,80)
				selectMode=false
				task.delay(2,function()
					ind.Text="⚔️ COMBAT: OFF"
					ind.TextColor3=Color3.fromRGB(160,160,160)
				end)
			else
				-- Show list di GUI
				frame.Visible=true
				local listText="🎯 Pilih (ketik nama):\n"
				for i,t in ipairs(targets) do
					listText=listText..i..". "..t.name.." ("..t.dist.."s)\n"
					if i>=5 then break end
				end
				tstatus.Text=listText
				tstatus.TextColor3=Color3.fromRGB(255,200,0)
				tinput.Text="" tinput:CaptureFocus()
				ind.Text="⚔️ SELECT TARGET"
				ind.TextColor3=Color3.fromRGB(255,200,0)
			end
		end
	end
end)

tinput.FocusLost:Connect(function(enter)
	if not enter then return end
	local name=tinput.Text:match("^%s*(.-)%s*$")
	if name=="" then return end
	local found,foundChar=findTarget(name)
	if found then
		targetName=found targetChar=foundChar
		tstatus.Text="✅ Target: "..found.." | Y = Serang!"
		tstatus.TextColor3=Color3.fromRGB(0,220,100)
	else
		tstatus.Text="❌ '"..name.."' gak ada!"
		tstatus.TextColor3=Color3.fromRGB(255,80,80)
		targetChar=nil
	end
end)

-- // JJS Remote Scanner
-- // Jalanin dulu buat liat nama Remote Events nya!

local RS = game:GetService("ReplicatedStorage")
local player = game.Players.LocalPlayer

print("========== REMOTE EVENTS ==========")
for _, obj in ipairs(RS:GetDescendants()) do
	if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
		print(obj.ClassName .. " | " .. obj:GetFullName())
	end
end

print("========== BINDABLE EVENTS ==========")
for _, obj in ipairs(RS:GetDescendants()) do
	if obj:IsA("BindableEvent") or obj:IsA("BindableFunction") then
		print(obj.ClassName .. " | " .. obj:GetFullName())
	end
end

print("========== PLAYER REMOTES ==========")
local char = player.Character
if char then
	for _, obj in ipairs(char:GetDescendants()) do
		if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
			print(obj.ClassName .. " | " .. obj:GetFullName())
		end
	end
end

print("===================================")
print("Copy semua hasil ini dan kasih ke gua!")


print("[Combat AI v2] T=Nama | Y=Fight | P=Passive | Tab=Autocomplete")
