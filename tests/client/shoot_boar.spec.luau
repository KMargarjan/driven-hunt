-- shoot_boar.spec: the end-to-end assertion the harness could not make until now.
--
-- A real replayed mouse click, from the harness, through ContextActionService, through the client
-- weapon, over FireRequest, through the server's validator, cast and pellets, onto a REAL boar's
-- zone part, back through HitReported and the boar's own runtime, and home as the shooter's hit
-- marker. Nothing in that chain is stubbed. Until Task 30 it could not be written, for one reason:
-- the harness cannot aim. The camera's yaw comes from mouse movement, and under
-- MouseBehavior = LockCenter StudioMCP's moveTo delivers no usable delta
-- (docs/design/camera.md section 9.3), so a replayed click fired wherever the camera happened to
-- point -- which was never at the boar.
--
-- Two halves, and they are deliberately different:
--   * THE HARNESS places the character and takes the first aim, through the `stage` block on the
--     scenario (tools/studio_mcp.py) and the camera owner's own LookAtRequest. Delete the stage and
--     the player stands wherever they spawned, a hundred studs away, and this spec goes red.
--   * THIS SPEC keeps the aim on the boar, because the boar RUNS as soon as a player appears within
--     DETECT_RADIUS. A stage that aims once cannot follow an animal at 28 studs/s.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- SINCE MILESTONE 1.7a THE BOARS BELONG TO THE DRIVE: none exists until the match releases the
-- first one, about FIRST_RELEASE_SECONDS into a drive, so the stage may find Workspace.Boars empty
-- and the harness waits for a target rather than failing on the first look.
--
-- Design: docs/design/hit-zones.md (section 14 item D), docs/design/camera.md (section 9.3)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local InputReady = require(ReplicatedStorage:WaitForChild("ClientTests"):WaitForChild("InputReady"))
local Role = require(ReplicatedStorage:WaitForChild("ClientTests"):WaitForChild("Role"))

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Camera = require(scripts:WaitForChild("Camera"))

-- Set by the harness's stage step, and by nothing else. Tracking starts when it appears, so this
-- spec never fights another spec for the camera: before the stage it does not touch it at all.
local STAGE_ATTRIBUTE = "StagedTarget"
-- Seconds to wait for the harness to stage this scenario. It is the LAST of four, and the whole
-- replay takes about 50 s from wherever it starts, which is not tied to where this suite starts.
-- Task 36 raised it from 120: `test2` now sends every step to BOTH clients, so each step costs two
-- StudioMCP calls and the whole replay takes about twice as long in that mode. The budget starts
-- where TestEZ reaches the `it`, and waiting longer costs a passing run nothing.
local STAGE_TIMEOUT = 210
local TRACK_SECONDS = 15
local AIM_HEIGHT = 0.4 -- studs above the trunk's centre: the chest band, not the legs

local markers = {}
local latchedAt: number? = nil
local stagedDistance: number? = nil

-- ONLY the markers that arrive after the stage. A stray pellet from an earlier scenario hitting a
-- wandering boar would otherwise satisfy this spec without the staged shot doing anything -- and it
-- did, twice, while the stage itself was broken: the run went green on a coincidence both times.
Shotgun.remotes().HitMarker.OnClientEvent:Connect(function(payload)
	if latchedAt then
		table.insert(markers, payload)
	end
end)

local function boarPart(): BasePart?
	local folder = Workspace:FindFirstChild("Boars")
	local part = folder and folder:FindFirstChildWhichIsA("BasePart")
	return part
end

local function rootPart(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Keeps the camera on the boar through the OWNER's API. It never writes workspace.CurrentCamera --
-- the camera's own foreign-write detector would count it if it did, and weapon_client.spec asserts
-- that counter does not move.
local tracking = RunService.RenderStepped:Connect(function()
	if not latchedAt then
		local staged = player:GetAttribute(STAGE_ATTRIBUTE)
		if type(staged) == "string" and staged ~= "" then
			latchedAt = os.clock()
			local boar, root = boarPart(), rootPart()
			stagedDistance = if boar and root then (boar.Position - root.Position).Magnitude else nil
		end
		return
	end
	if #markers > 0 or os.clock() - latchedAt > TRACK_SECONDS then
		return -- the shot landed, or the window closed: give the camera back
	end
	local boar = boarPart()
	if boar then
		Camera.lookAt(boar.Position + Vector3.new(0, AIM_HEIGHT, 0))
	end
end)

InputReady.ready("shoot_boar")

local function waitUntil(seconds: number, predicate: () -> boolean): boolean
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if predicate() then
			return true
		end
		task.wait(0.05)
	end
	return predicate()
end

return function()
	describe("the look-at request the harness stages through", function()
		-- These run at the start of the suite, while the replay is still on its first scenario and
		-- long before the stage: nothing is tracking yet, so nothing is fighting for the camera.
		it("is an Instance, because execute_luau cannot reach this module", function()
			-- MEASURED 2026-09-25: a require() through execute_luau returns a FRESH module, which
			-- reports mode=Loading and frames=0 while the live camera is Scriptable at FOV 70. The
			-- harness therefore cannot call Camera.lookAt; it invokes this, and the OWNER writes.
			local request = scripts:WaitForChild("Camera"):FindFirstChild("LookAtRequest")
			expect(request).to.be.ok()
			expect(request:IsA("BindableFunction")).to.equal(true)
		end)

		it("turns the real camera onto a point, without anyone writing the camera", function()
			expect(waitUntil(20, function()
				return Camera.getMode() ~= "Loading" and rootPart() ~= nil
			end)).to.equal(true)
			local root = rootPart()
			local before = Camera.stats().foreignCameraWrites
			local request = scripts:WaitForChild("Camera"):FindFirstChild("LookAtRequest")

			-- 60 studs out and 8 up, square to the character: nowhere the camera already points.
			local target = root.Position + Vector3.new(60, 8, 0)
			expect(request:Invoke(target.X, target.Y, target.Z)).to.equal(true)
			RunService.RenderStepped:Wait()
			RunService.RenderStepped:Wait()

			local cam = Workspace.CurrentCamera
			local dot = cam.CFrame.LookVector:Dot((target - cam.CFrame.Position).Unit)
			print(
				string.format("[shoot_boar] look-at error: %.2f degrees", math.deg(math.acos(math.clamp(dot, -1, 1))))
			)
			expect(dot > 0.999).to.equal(true) -- within about 2.5 degrees
			-- The owner did it. If the request had written the camera itself, this would rise.
			expect(Camera.stats().foreignCameraWrites).to.equal(before)
		end)

		it("refuses a request that is not three numbers", function()
			local request = scripts:WaitForChild("Camera"):FindFirstChild("LookAtRequest")
			expect(request:Invoke("over", "there", nil)).to.equal(false)
		end)
	end)

	describe("a replayed click at a real boar", function()
		-- ROLE-AWARE (TASKS.md row 34a). The harness stages and shoots on the SHOOTER's client only:
		-- a driver carries no gun (`DRIVERS_MAY_SHOOT = false`), so there is nothing for him to fire
		-- and the stage would put two characters in the same place. The driver's branch is not a
		-- skip -- it asserts the rule: he is never staged, and nothing of his ever lands.
		it("staged this client only if it is the shooter's -- a driver has no gun to fire", function()
			if Role.isShooter() then
				-- The shooter's half of this pair is the next two `it`s; here, only that the harness and
				-- this spec agree on who he is.
				expect(player.Team).to.be.ok()
				expect(player.Team.Name).to.equal("Shooters")
				return
			end
			-- Give the whole replay time to finish before claiming nothing arrived.
			task.wait(5)
			expect(player:GetAttribute(STAGE_ATTRIBUTE)).to.equal(nil)
			expect(latchedAt).to.equal(nil)
			expect(#markers).to.equal(0)
		end)

		it("was staged by the harness: the player is standing next to the boar", function()
			if Role.isDriver() then
				-- Asserted above, and the camera was never touched by this spec here: `latchedAt` is
				-- what gates the tracking loop.
				expect(latchedAt).to.equal(nil)
				return
			end
			-- The specs run WHILE the replay does, so this really is a wait for the harness to reach
			-- the last scenario -- and MEASURED, the whole replay takes about 50 s, so 40 s was not
			-- enough and this test failed while the shot itself landed. The harness waits for the
			-- client report long after the replay, so waiting here costs the run nothing.
			--
			-- WHY IT IS THIS LONG (Task 34): the budget starts where TestEZ reaches this `it`, and
			-- the thing it waits for happens at a fixed point in the replay -- so the margin is
			-- however long the specs before this one took, which is NOT the same in the one-player
			-- and two-player modes. In `test2` the replay does not even begin until the harness has
			-- classified three processes and opened the gate. A budget that assumes "the replay
			-- starts when the suite starts" is the assumption, and this is the fix for it.
			expect(waitUntil(STAGE_TIMEOUT, function()
				return latchedAt ~= nil
			end)).to.equal(true)
			print(
				string.format(
					"[shoot_boar] staged on %s, %.0f studs away",
					tostring(player:GetAttribute(STAGE_ATTRIBUTE)),
					stagedDistance or -1
				)
			)
			-- The stage places the character at the scenario's offset. Far enough away and the shot
			-- is a lottery; this is the number the scenario asks for, with room for one frame of
			-- the boar's own movement.
			expect(stagedDistance ~= nil and stagedDistance < 40).to.equal(true)
		end)

		it("hit it: the server confirmed a hit on a damageable target and told this client", function()
			if Role.isDriver() then
				-- A driver's shot does not exist, so a marker from one cannot either. (The server
				-- DOES send both clients a test marker in weapon_hits.spec; that is a different
				-- remote payload and a different claim, asserted in hit_marker.spec. This list only
				-- collects markers that arrive after this spec's own stage, which never happened.)
				expect(#markers).to.equal(0)
				return
			end
			local arrived = waitUntil(16, function()
				return #markers > 0
			end)
			if not arrived then
				local boar = boarPart()
				print(
					string.format(
						"[shoot_boar] no hit marker: boar %s, camera mode %s",
						if boar then "still there" else "GONE",
						Camera.getMode()
					)
				)
			end
			expect(arrived).to.equal(true)
			expect(type(markers[1])).to.equal("table")
			-- The zone is whatever the pellets found; that it is one of the boar's is the point.
			print(
				string.format(
					"[shoot_boar] marker: kind=%s zone=%s",
					tostring(markers[1].kind),
					tostring(markers[1].zone)
				)
			)
			expect(markers[1].kind == "hit" or markers[1].kind == "kill").to.equal(true)
		end)

		afterAll(function()
			if tracking.Connected then
				tracking:Disconnect()
			end
		end)
	end)
end
