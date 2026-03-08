-- NPCCombatAI.lua
-- Server-side combat AI for NPCs (safe, non-exploit)
-- Place this script in ServerScriptService.
-- NPCs should be parented to workspace.NPCs and be a Model containing:
--   - Humanoid
--   - HumanoidRootPart
-- Optionally, set a NumberValue named "AggroRange" or "AttackRange" on the model to customize.

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local NPC_FOLDER = workspace:FindFirstChild("NPCs") or Instance.new("Folder", workspace)
NPC_FOLDER.Name = "NPCs"

-- Configuration defaults
local DEFAULT_AGGRO_RANGE = 50
local DEFAULT_ATTACK_RANGE = 4
local PATH_RECOMPUTE_INTERVAL = 1.0
local LOOP_WAIT = 0.1

-- Utility: find nearest player character within range
local function getNearestPlayerCharacter(npcPosition, maxRange)
	local bestDist = maxRange
	local bestChar = nil
	for _, pl in pairs(Players:GetPlayers()) do
		local char = pl.Character
		if char and char.PrimaryPart and char:FindFirstChildOfClass("Humanoid") then
			local hrp = char.PrimaryPart
			local dist = (hrp.Position - npcPosition).Magnitude
			if dist <= bestDist then
				bestDist = dist
				bestChar = char
			end
		end
	end
	return bestChar, bestDist
end

-- Simple ray LOS check (ignores transparent and some small parts)
local function hasLineOfSight(fromPos, toPos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.IgnoreWater = true
	-- Lines should ignore NPCs themselves; caller may add more filters
	local result = workspace:Raycast(fromPos, (toPos - fromPos), params)
	-- If raycast hits nothing, assume LOS clear; if hit, check if hit instance is part of target character externally handled
	return result == nil
end

-- Create path waypoints from origin to target position
local function computePath(origin, destination)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentCanClimb = false,
		WaypointSpacing = 2,
	})
	local ok, err = pcall(function()
		path:ComputeAsync(origin, destination)
	end)
	if not ok then
		warn("Path compute failed:", err)
		return nil
	end
	if path.Status == Enum.PathStatus.Success then
		return path:GetWaypoints()
	end
	return nil
end

local function safeMoveTo(humanoid, destination)
	-- Use MoveTo for server-side movement; can be replaced with Humanoid:MoveTo or SetVelocity for more advanced movement
	pcall(function()
		humanoid:MoveTo(destination)
	end)
end

-- AI core per-NPC
local function runAIForNPC(npc)
	-- Validate npc
	if not npc or not npc.Parent then return end
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local hrp = npc:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then return end

	-- Per-NPC state
	local aggroRange = npc:FindFirstChild("AggroRange") and npc.AggroRange.Value or DEFAULT_AGGRO_RANGE
	local attackRange = npc:FindFirstChild("AttackRange") and npc.AttackRange.Value or DEFAULT_ATTACK_RANGE
	local baseWalkSpeed = humanoid.WalkSpeed or 16

	local running = true
	local currentTargetChar = nil
	local lastPath = nil
	local nextWaypointIndex = 1
	local lastPathCompute = 0
	local attackCooldown = 0
	local dashCooldown = 0
	local skillCooldown = 0

	-- Helper: perform melee attack (server-side)
	local function performMeleeAttack(targetHumanoid, damage)
		if not targetHumanoid or targetHumanoid.Health <= 0 then return end
		-- Optional: you could add animations, damage events, or hitbox checks here.
		-- We simply apply damage server-side.
		targetHumanoid:TakeDamage(damage)
	end

	-- Helper: perform a short dash toward the target (teleport-like with checks)
	local function performDashTowards(targetPos, dashDistance, dashSpeed)
		-- dashSpeed unused here, present for expansion. We perform small step movement with collisions handled by physics.
		local dir = (targetPos - hrp.Position)
		dir = Vector3.new(dir.X, 0, dir.Z)
		if dir.Magnitude <= 0 then return end
		local unit = dir.Unit
		local newPos = hrp.Position + unit * math.clamp(dashDistance, 0, dashDistance)
		-- Move the NPC root gently using CFrame while preserving Y
		local y = hrp.Position.Y
		local targetCFrame = CFrame.new(Vector3.new(newPos.X, y, newPos.Z), Vector3.new(targetPos.X, y, targetPos.Z))
		-- Apply instantly; you can smooth this if desired
		pcall(function()
			hrp.CFrame = targetCFrame
		end)
	end

	-- Main loop
	local heartbeatConn
	heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		if not running or not npc.Parent then
			heartbeatConn:Disconnect()
			return
		end

		-- Update cooldowns
		attackCooldown = math.max(0, attackCooldown - dt)
		dashCooldown = math.max(0, dashCooldown - dt)
		skillCooldown = math.max(0, skillCooldown - dt)

		-- Acquire or validate target
		if not currentTargetChar or not currentTargetChar.Parent or currentTargetChar:FindFirstChildOfClass("Humanoid") == nil then
			local char, dist = getNearestPlayerCharacter(hrp.Position, aggroRange)
			if char and dist <= aggroRange then
				currentTargetChar = char
				-- Reset path so AI recomputes
				lastPath = nil
				nextWaypointIndex = 1
			else
				currentTargetChar = nil
			end
		end

		if not currentTargetChar then
			-- Idle behavior
			humanoid.WalkSpeed = baseWalkSpeed
			return
		end

		local targetHum = currentTargetChar:FindFirstChildOfClass("Humanoid")
		local targetHRP = currentTargetChar.PrimaryPart
		if not targetHum or not targetHRP or targetHum.Health <= 0 then
			currentTargetChar = nil
			return
		end

		local targetPos = targetHRP.Position
		local toTarget = targetPos - hrp.Position
		local horizontalDist = Vector3.new(toTarget.X, 0, toTarget.Z).Magnitude

		-- If target is within attackRange, try melee
		if horizontalDist <= attackRange then
			-- Face target
			hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z))

			if attackCooldown <= 0 then
				attackCooldown = 1.0 -- melee rate (seconds)
				performMeleeAttack(targetHum, 10) -- damage amount
				-- optional: set animation, effects, etc.
			end

			-- Small chance to dash away after hit (defensive maneuver)
			if dashCooldown <= 0 and math.random() < 0.15 then
				dashCooldown = 2.0
				performDashTowards(hrp.Position - (targetPos - hrp.Position).Unit * 4, 4, 40)
			end

		else
			-- Not in immediate attack range: pathfind and approach
			humanoid.WalkSpeed = (horizontalDist > 20) and (baseWalkSpeed * 1.6) or baseWalkSpeed

			-- Recompute path periodically or if target moved significantly
			lastPathCompute = lastPathCompute + dt
			if lastPath == nil or lastPathCompute >= PATH_RECOMPUTE_INTERVAL then
				lastPathCompute = 0
				local waypoints = computePath(hrp.Position, targetPos)
				if waypoints and #waypoints > 0 then
					lastPath = waypoints
					nextWaypointIndex = 1
				else
					-- fallback: direct MoveTo
					lastPath = nil
					nextWaypointIndex = 1
				end
			end

			-- Follow waypoints if available
			if lastPath and nextWaypointIndex <= #lastPath then
				local wp = lastPath[nextWaypointIndex]
				local wpPos = wp.Position
				-- If waypoint is reachable, step toward it
				local delta = Vector3.new(wpPos.X, 0, wpPos.Z) - Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
				if delta.Magnitude < 3 then
					nextWaypointIndex = nextWaypointIndex + 1
				else
					-- Jump if required
					if wp.Action == Enum.PathWaypointAction.Jump then
						humanoid.Jump = true
					end
					-- Move toward waypoint
					safeMoveTo(humanoid, wpPos)
				end
			else
				-- No path: move directly
				safeMoveTo(humanoid, targetPos)
			end

			-- Occasionally use a dash to close gap if far and cooldown available
			if dashCooldown <= 0 and horizontalDist > 12 and math.random() < 0.25 then
				dashCooldown = 3.0
				performDashTowards(targetPos, math.clamp(horizontalDist - attackRange, 4, 12), 80)
			end

			-- Occasional special skill: short AOE if close and skill ready
			if skillCooldown <= 0 and horizontalDist < 8 and math.random() < 0.08 then
				skillCooldown = 5.0
				-- AOE: damage any humanoid within radius
				local radius = 6
				for _, obj in pairs(workspace:GetDescendants()) do
					if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") and obj:FindFirstChild("HumanoidRootPart") then
						local h = obj:FindFirstChildOfClass("Humanoid")
						local p = obj.PrimaryPart
						if h and p and (p.Position - hrp.Position).Magnitude <= radius and h.Health > 0 then
							h:TakeDamage(8)
						end
					end
				end
			end
		end
	end)
end

-- Attach AI to all existing NPCs in folder and listen for new ones
local function setupNPC(npc)
	-- Quick validation
	if not npc:IsA("Model") then return end
	if not npc:FindFirstChildOfClass("Humanoid") or not npc:FindFirstChild("HumanoidRootPart") then return end
	-- Start AI loop in a coroutine so many NPCs can run concurrently
	spawn(function()
		runAIForNPC(npc)
	end)
end

-- Initialize existing NPCs
for _, npc in pairs(NPC_FOLDER:GetChildren()) do
	setupNPC(npc)
end

-- Watch for new NPCs
NPC_FOLDER.ChildAdded:Connect(function(child)
	-- small delay to allow components to initialize
	task.wait(0.1)
	setupNPC(child)
end)

print("[NPCCombatAI] Loaded. NPCs under workspace.NPCs will run server-side combat AI.")
