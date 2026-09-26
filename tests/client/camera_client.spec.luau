-- camera_client.spec: the REAL camera in the real client. The maths is proved on the server
-- (tests/server/camera_mode.spec.luau); this proves the things only a running client can show --
-- that nothing else writes the camera or the mouse, that the aim path moves the real camera, and
-- that the viewmodel is genuinely on screen rather than merely existing.
--
-- It reaches the owner through Players.LocalPlayer.PlayerScripts, never through
-- StarterPlayerScripts, which is a template (docs/design/shotgun.md section 3.2).
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/camera.md (sections 9.2, 9.3)
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local InputReady = require(ReplicatedStorage:WaitForChild("ClientTests"):WaitForChild("InputReady"))
local Role = require(ReplicatedStorage:WaitForChild("ClientTests"):WaitForChild("Role"))

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Camera = require(scripts:WaitForChild("Camera"))
local Config = Camera.Config

-- The harness replays every scenario once the LAST expected spec says it is ready, so this file
-- signals at require time like the others (docs/design/shotgun.md section 13.3).
InputReady.ready("camera_client")

local function waitFrames(n: number)
	for _ = 1, n do
		RunService.RenderStepped:Wait()
	end
end

local function waitUntil(seconds: number, predicate: () -> boolean): boolean
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if predicate() then
			return true
		end
		task.wait(0.03)
	end
	return predicate()
end

local function rootPart(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

return function()
	describe("the camera owns the camera", function()
		it("holds the camera, and says whether a stock module had to be disabled", function()
			expect(waitUntil(20, function()
				return Camera.getMode() ~= "Loading"
			end)).to.equal(true)
			local acquired, reason = Camera.acquired()
			-- This place has no PlayerScripts.PlayerModule at all (measured 2026-09-25), so the
			-- disable step is a no-op here and says so rather than failing. Whether anything else
			-- writes the camera is the next test, and that is the assertion that matters.
			print(
				string.format(
					"[camera_client] acquired=%s stockCamerasDisabled=%s reason=%s",
					tostring(acquired),
					tostring(Camera.Rig.stockCamerasDisabled()),
					tostring(reason)
				)
			)
			expect(acquired).to.equal(true)
			expect(Workspace.CurrentCamera.CameraType).to.equal(Enum.CameraType.Scriptable)
		end)

		it("is the ONLY thing writing the camera and the mouse", function()
			waitFrames(120)
			local stats = Camera.stats()
			print(
				string.format(
					"[camera_client] %d frames, foreign camera writes %d, cursor reasserts %d, maxUpdate %.3f ms",
					stats.frames,
					stats.foreignCameraWrites,
					stats.cursorReasserts,
					stats.maxUpdateMs
				)
			)
			expect(stats.frames >= 120).to.equal(true)
			-- A detection, not a promise: if the stock camera ever comes back, or a plugin or a
			-- future LocalScript writes the camera, this is the number that says so.
			expect(stats.foreignCameraWrites).to.equal(0)
			expect(stats.cursorReasserts).to.equal(0)
		end)

		it("sits in third person with the third-person field of view", function()
			expect(Camera.getMode()).to.equal("Third")
			expect(math.abs(Workspace.CurrentCamera.FieldOfView - Config.FOV_THIRD_DEG) < 0.01).to.equal(true)
		end)

		it("stays inside the shotgun validator's tolerance, all session", function()
			local stats = Camera.stats()
			print(string.format("[camera_client] max distance from root: %.2f studs", stats.maxDistanceFromRoot))
			expect(stats.maxDistanceFromRoot < 15).to.equal(true)
			-- docs/design/shotgun.md section 11: the server refuses a fire request whose origin is
			-- more than CAMERA_ORIGIN_TOLERANCE = 30 studs from HumanoidRootPart.
			expect(stats.maxDistanceFromRoot < 30).to.equal(true)
		end)

		it("keeps the update inside its frame budget", function()
			local stats = Camera.stats()
			print(
				string.format(
					"[camera_client] update: %.3f ms average, %.3f ms worst, over %d frames",
					stats.avgUpdateMs,
					stats.maxUpdateMs,
					stats.frames
				)
			)
			-- The AVERAGE against the design's 0.3 ms budget: the cost of the camera every frame.
			-- The worst frame of a session is a hitch, not a budget (Task 26 measured 0.22-0.34 ms
			-- maxima for identical code), so it is printed and not asserted -- except loosely, to
			-- catch a hitch that could only be a bug.
			expect(stats.avgUpdateMs < 0.3).to.equal(true)
			expect(stats.maxUpdateMs < 5).to.equal(true)
		end)
	end)

	-- FIRST, and that ordering is the test. Round 1, finding 1: this used to run after the
	-- fake-source tests, which left their fake installed and had already moved aimEnters/aimExits --
	-- so it passed with the aim-hold scenario deleted, and the "real right mouse drove the camera"
	-- claim rested on counters a fake had moved. It now runs while the PRODUCTION source installed
	-- by CameraBoot is still the only one, and asserts a DELTA taken here.
	describe("the harness-driven aim", function()
		-- ROLE-AWARE (TASKS.md row 34a). The aim action is bound by PlayerScripts.Weapon.Input on
		-- Tool.Equipped and unbound on Unequipped, so a DRIVER -- who is never given a Tool, because
		-- `Match.CONFIG.DRIVERS_MAY_SHOOT` is false -- has no aim action at all and a replayed right
		-- mouse button reaches nothing. That is a rule, not an excuse, and it is asserted rather
		-- than skipped.
		it("is bound to a gun: a shooter has the aim action, a driver has none at all", function()
			if Role.isShooter() then
				-- A shooter's aim action is bound on Tool.Equipped, which weapon_client.spec's cue does,
				-- and the next `it` is what proves a replayed button reaches it. What is worth
				-- asserting here is that the role this whole file branches on is the drive's own.
				expect(player.Team and player.Team.Name).to.equal("Shooters")
				return
			end
			local before = Camera.stats()
			local bound = ContextActionService:GetAllBoundActionInfo()
			for name in pairs(bound) do
				expect(string.sub(name, 1, 18)).never.to.equal("DrivenHunt.Weapon.")
			end
			-- The whole replay reaches this client too (both clients get the same steps since Task
			-- 36), so this really is "the right mouse button arrived and did nothing".
			task.wait(5)
			expect(Camera.stats().aimEnters).to.equal(before.aimEnters)
			expect(Camera.getMode()).never.to.equal("Aiming")
		end)

		it("entered and left Aiming from the real right mouse button", function()
			if Role.isDriver() then
				return -- asserted above, the other way round
			end
			local before = Camera.stats()
			local baselineEnters, baselineExits = before.aimEnters, before.aimExits
			local baselineHistory = #Camera.modeHistory()
			print(
				string.format(
					"[camera_client] baseline before the replay: enters=%d exits=%d history=%d",
					baselineEnters,
					baselineExits,
					baselineHistory
				)
			)

			-- TWO holds are replayed in a run: the weapon scenario's, then the camera's own
			-- `aim-hold`. Round 2's note: waiting for the first delta was satisfied by the weapon
			-- scenario, so deleting `aim-hold` would not have failed this. Wait for BOTH.
			local first = waitUntil(60, function()
				return Camera.stats().aimEnters > baselineEnters
			end)
			if not first then
				print("[camera_client] no replayed right mouse reached the weapon's aim action at all")
			end
			expect(first).to.equal(true)
			expect(waitUntil(20, function()
				return Camera.stats().aimExits > baselineExits
			end)).to.equal(true)

			local afterFirst = Camera.stats()
			local second = waitUntil(60, function()
				return Camera.stats().aimEnters > afterFirst.aimEnters
			end)
			if not second then
				print("[camera_client] the aim-hold scenario's own right mouse never arrived")
			end
			expect(second).to.equal(true)
			expect(waitUntil(20, function()
				return Camera.stats().aimExits > afterFirst.aimExits
			end)).to.equal(true)

			local history = Camera.modeHistory()
			print("[camera_client] mode history: " .. table.concat(history, ","))
			local sawAimingAfterBaseline = false
			for index = baselineHistory + 1, #history do
				if history[index] == "Aiming" then
					sawAimingAfterBaseline = true
				end
			end
			expect(sawAimingAfterBaseline).to.equal(true)
		end)
	end)

	-- Audit-003 must-fix 2. The detector is the ONLY runtime proof that one thing writes the camera
	-- (this place has no PlayerScripts.PlayerModule, so GetCameras():Disable() never runs), and it
	-- compared position and field of view only: a second writer that TURNED the view without moving
	-- the camera read as zero. These two tests make the detector itself falsifiable -- the property
	-- boar_hit.spec's teardown test was rewritten to have, after a test that could not fail guarded
	-- the one line it existed for.
	describe("the foreign-write detector", function()
		it("counts a rotation-only write, which is the case it exists for", function()
			local cam = Workspace.CurrentCamera
			local before = Camera.stats().foreignCameraWrites
			local at = cam.CFrame
			-- Same position, same field of view, opposite look: invisible to the old check.
			cam.CFrame = CFrame.lookAt(at.Position, at.Position - at.LookVector)
			waitFrames(3)
			local after = Camera.stats().foreignCameraWrites
			print(string.format("[camera_client] rotation-only write: %d -> %d", before, after))
			expect(after > before).to.equal(true)
		end)

		it("does not count the camera's own writes, before or after that", function()
			-- Otherwise the test above would prove only that the counter can count.
			local before = Camera.stats().foreignCameraWrites
			waitFrames(60)
			expect(Camera.stats().foreignCameraWrites).to.equal(before)
		end)
	end)

	-- Task 50. `test2` got faster and two of three runs then measured the camera 82 and 89 degrees
	-- off a point it had just been asked to look at: the spec that asked had waited a fixed TWO
	-- frames, and a replayed mouse delta consumed in the same frame took the camera elsewhere. The
	-- owner now says when a request has actually been RENDERED, and these tests are what make that
	-- signal falsifiable in a ONE-player run -- the two-player race itself needs two clients and a
	-- human click, so it can never be a regression test.
	describe("the look-at landed signal", function()
		it("does not count a request until a frame has been rendered", function()
			expect(waitUntil(20, function()
				return Camera.getMode() ~= "Loading" and rootPart() ~= nil
			end)).to.equal(true)
			local root = rootPart()
			local before = Camera.stats()
			-- NOT A YIELD between these two lines, deliberately: nothing can have rendered, so a
			-- counter that rose here would be counting the ASK, which is the bug this exists to stop.
			expect(Camera.lookAt(root.Position + Vector3.new(0, 6, 55))).to.equal(true)
			local asked = Camera.stats()
			expect(asked.lookAtRequests).to.equal(before.lookAtRequests + 1)
			expect(asked.lookAtLanded).to.equal(before.lookAtLanded)

			-- And it does count, once a frame goes by.
			expect(waitUntil(5, function()
				return Camera.stats().lookAtLanded > before.lookAtLanded
			end)).to.equal(true)
		end)

		it("never lands more requests than were asked for", function()
			local stats = Camera.stats()
			expect(stats.lookAtLanded <= stats.lookAtRequests).to.equal(true)
		end)

		it("does not count a request that was refused", function()
			-- No character to turn -> Camera.lookAt returns false and nothing is pending. The
			-- LookAtRequest BindableFunction refuses non-numbers the same way (shoot_boar.spec).
			local request = scripts:WaitForChild("Camera"):FindFirstChild("LookAtRequest")
			local before = Camera.stats()
			expect(request:Invoke("over", "there", nil)).to.equal(false)
			waitFrames(3)
			local after = Camera.stats()
			expect(after.lookAtRequests).to.equal(before.lookAtRequests)
			expect(after.lookAtLanded).to.equal(before.lookAtLanded)
		end)
	end)

	describe("the aim path", function()
		local fake = { aiming = false }
		local production = nil

		beforeEach(function()
			production = production or Camera.getAimSource()
			Camera.setAimSource({
				isAiming = function()
					return fake.aiming
				end,
			})
		end)

		afterEach(function()
			fake.aiming = false
			waitFrames(30)
		end)

		afterAll(function()
			-- Put back what CameraBoot installed. A test that leaves a fake in place makes every
			-- later assertion about the real aim path meaningless (round 1, finding 1).
			Camera.setAimSource(production)
		end)

		it("zooms to the eye and back, on the real camera", function()
			fake.aiming = true
			expect(waitUntil(Config.AIM_BLEND_SECONDS + 0.5, function()
				return Camera.getMode() == "Aiming" and Camera.getBlend() >= 1
			end)).to.equal(true)
			expect(math.abs(Workspace.CurrentCamera.FieldOfView - Config.FOV_AIM_DEG) < 0.01).to.equal(true)

			local root = rootPart()
			expect(root).to.be.ok()
			local distance = (Workspace.CurrentCamera.CFrame.Position - (root :: BasePart).Position).Magnitude
			print(string.format("[camera_client] aimed camera is %.2f studs from the root", distance))
			expect(distance < 2.5).to.equal(true)

			fake.aiming = false
			expect(waitUntil(Config.AIM_BLEND_SECONDS + 0.5, function()
				return Camera.getMode() == "Third" and Camera.getBlend() <= 0
			end)).to.equal(true)
			expect(math.abs(Workspace.CurrentCamera.FieldOfView - Config.FOV_THIRD_DEG) < 0.01).to.equal(true)
		end)

		it("shows a viewmodel that is really on screen, and unparents it afterwards", function()
			if Role.isDriver() then
				-- The viewmodel is a clone of the Tool's Handle (docs/design/camera.md section 7), so
				-- a driver aiming an empty pair of hands must get NO viewmodel -- not an empty Model,
				-- and not somebody else's gun.
				fake.aiming = true
				expect(waitUntil(2, function()
					return Camera.getBlend() >= 1
				end)).to.equal(true)
				expect(Camera.Viewmodel.current()).to.equal(nil)
				expect(Camera.stats().viewmodelParented).to.equal(false)
				fake.aiming = false
				expect(waitUntil(2, function()
					return Camera.getBlend() <= 0
				end)).to.equal(true)
				return
			end
			fake.aiming = true
			expect(waitUntil(2, function()
				return Camera.getBlend() >= 1
			end)).to.equal(true)

			local model = Camera.Viewmodel.current()
			-- Unconditional (round 1, note): wrapping this in `if model then` meant the whole block
			-- passed when no viewmodel was ever built.
			expect(model).to.be.ok()
			if model then
				expect(model:IsA("Model")).to.equal(true)
				expect(model.Parent).to.equal(Workspace.CurrentCamera)
				-- SINCE TASK 71 THE VIEWMODEL IS A WHOLE GUN, not one box: the Tool's Handle is an
				-- invisible envelope and the side-by-side is welded to it, so the clone carries a
				-- barrel pair, a rib, a bead, an action, a lever, a forend, a stock, a guard and a
				-- trigger. What is asserted is therefore "the ENVELOPE is the only invisible part",
				-- which is a stronger claim than the old "every part is visible" and still fails on
				-- the thing that check existed for -- a viewmodel that is on screen but blank.
				local parts, visible = 0, 0
				for _, part in ipairs(model:GetDescendants()) do
					if part:IsA("BasePart") then
						parts += 1
						if part.Transparency < 1 then
							visible += 1
						end
						expect(part.LocalTransparencyModifier < 1).to.equal(true)
						-- Not optional: the camera is a child of Workspace, so a CanQuery part here
						-- would be hit by this system's own occlusion ray.
						expect(part.CanQuery).to.equal(false)
						-- Nothing under the camera may be simulated: the clone is anchored, welds and
						-- all other non-shape children destroyed.
						expect(part.Anchored).to.equal(true)
					end
				end
				expect(parts >= 4).to.equal(true) -- a gun, not a box
				expect(parts <= 16).to.equal(true) -- a gun, not somebody's character
				expect((model.PrimaryPart :: BasePart).Transparency).to.equal(1)
				expect(visible).to.equal(parts - 1)

				-- Every ancestor present, up to the DataModel: an orphaned tree is invisible however
				-- true its properties are (docs/PROJECT_CONTEXT.md).
				local node: Instance? = model
				while node and node ~= game do
					node = node.Parent
				end
				expect(node).to.equal(game)
			end

			fake.aiming = false
			expect(waitUntil(2, function()
				return Camera.getBlend() <= 0
			end)).to.equal(true)
			waitFrames(3)
			expect(Camera.stats().viewmodelParented).to.equal(false)
		end)
	end)

	describe("the hidden local body", function()
		-- audit-003 F1 / audit-004 must-fix 2, and the one defect in that audit Karen would SEE: in ADS
		-- the real shotgun was drawn beside the viewmodel, two guns on screen at once.
		--
		-- The cause is a cache, not a missing rule. `Rig.setLocalBodyHidden` walks the character once
		-- per life and then only writes when the flag CHANGES -- and the Tool's `Handle` is granted on
		-- `CharacterAdded` server-side, so it reaches the client after that walk. It was therefore in
		-- no list and nothing ever wrote it.
		--
		-- This test adds a part to the character AFTER the body is hidden, which is the same arrival
		-- the Handle makes.
		--
		-- MEASURED 2026-09-26, and the first version of this test was wrong about it: `DescendantAdded`
		-- is DEFERRED, not synchronous. A probe that parented a part and read the value in the same
		-- breath saw `synchronous=false`, and only `afterOneWait=true`. So the loop below waits -- and
		-- re-asserts the flag on every pass, because `Camera.step` sets it from the real aim blend on
		-- every render step and will lower it while we wait. Re-asserting CANNOT make this pass by
		-- itself: `setLocalBodyHidden` only writes the parts in its own list, and the whole point of
		-- the defect is that the late arrival was never in that list.
		it("hides a part that arrives after the body was already hidden", function()
			local character = player.Character
			expect(character).to.be.ok()

			Camera.Rig.setLocalBodyHidden(true)
			-- INERT AND OUT OF THE WAY. The first version left a 1-stud anchored part at the world
			-- ORIGIN for the length of the wait loop, inside the arena, while weapon_client.spec was
			-- firing live rounds -- and its ammo counts moved by one. A probe that can be shot is a
			-- probe that changes another spec's answer (the Task 34 lesson, in miniature).
			local probe = Instance.new("Part")
			probe.Name = "AuditF1LateArrival"
			probe.Size = Vector3.new(1, 1, 1)
			probe.Transparency = 1
			probe.Anchored = true
			probe.CanCollide = false
			probe.CanQuery = false
			probe.CanTouch = false
			probe.CFrame = character:GetPivot()
			probe.Parent = character

			local hidden, modifier = false, probe.LocalTransparencyModifier
			local deadline = os.clock() + 3
			while os.clock() < deadline do
				Camera.Rig.setLocalBodyHidden(true)
				modifier = probe.LocalTransparencyModifier
				if modifier == 1 then
					hidden = true
					break
				end
				task.wait()
			end
			local counted = Camera.Rig.hiddenPartCount()
			probe:Destroy()
			Camera.Rig.setLocalBodyHidden(false)

			if not hidden then
				error(
					string.format(
						"a part parented to the character while the body was hidden still had "
							.. "LocalTransparencyModifier = %.1f after 3 s: in ADS that is the real gun drawn "
							.. "beside the viewmodel (audit-003 F1)",
						modifier
					),
					0
				)
			end
			expect(counted > 0).to.equal(true)
		end)

		-- A DRIVER holds no Tool at all (Match.CONFIG.DRIVERS_MAY_SHOOT is false), so the Handle is
		-- named as a case rather than promised: the claim is every part the character HAS.
		it("hides every part the character has, the Tool's Handle among them when it holds one", function()
			local character = player.Character
			expect(character).to.be.ok()

			Camera.Rig.setLocalBodyHidden(true)
			local visible, total = {}, 0
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") then
					total += 1
					if part.LocalTransparencyModifier ~= 1 then
						table.insert(visible, part:GetFullName())
					end
				end
			end
			Camera.Rig.setLocalBodyHidden(false)

			expect(total > 0).to.equal(true)
			if #visible > 0 then
				error(
					string.format(
						"%d of %d character part(s) stayed visible in ADS: %s",
						#visible,
						total,
						table.concat(visible, ", ")
					),
					0
				)
			end
			print(
				string.format("[camera_client] hidden body: %d character part(s) at LocalTransparencyModifier 1", total)
			)
		end)

		-- Review round 1 of Task 47: the fix for the late arrival introduced its own defect. A part
		-- that LEAVES the character while the body is hidden was dropped from the list still at 1, and
		-- nothing writes it again -- so unequipping the shotgun mid-aim left the player's own gun
		-- invisible in third person for the rest of that life. `Rig` is the only writer of
		-- LocalTransparencyModifier on the local character, so nothing else could put it back.
		it("puts a part back when it leaves the character while the body is hidden", function()
			local character = player.Character
			expect(character).to.be.ok()

			local probe = Instance.new("Part")
			probe.Name = "AuditF1Departure"
			probe.Size = Vector3.new(1, 1, 1)
			probe.Transparency = 1
			probe.Anchored = true
			probe.CanCollide = false
			probe.CanQuery = false
			probe.CanTouch = false
			probe.CFrame = character:GetPivot()
			probe.Parent = character

			-- Wait for the deferred DescendantAdded, re-asserting the flag as the camera lowers it --
			-- and READ IN THE SAME BREATH AS THE WRITE. The first version of this loop read after the
			-- `task.wait()`, which is always just after a `Camera.step` that set the flag from the real
			-- aim blend and wrote every listed part back to 0: it could never see a 1, and said so.
			local hidden = false
			local deadline = os.clock() + 3
			while os.clock() < deadline do
				Camera.Rig.setLocalBodyHidden(true)
				if probe.LocalTransparencyModifier == 1 then
					hidden = true
					break
				end
				task.wait()
			end
			expect(hidden).to.equal(true)

			-- Out of the character while hidden, exactly as the Tool reparents to the Backpack when the
			-- player unequips mid-aim. Nothing writes this part after it leaves the list, so reading it
			-- at any later moment is safe -- which is the whole defect: without the restore it stays at
			-- 1 for the rest of the life.
			probe.Parent = player.Backpack -- where the Tool goes, and out of the world entirely
			deadline = os.clock() + 3
			while os.clock() < deadline and probe.LocalTransparencyModifier ~= 0 do
				task.wait()
			end
			local afterLeaving = probe.LocalTransparencyModifier
			Camera.Rig.setLocalBodyHidden(false)
			local afterUnhide = probe.LocalTransparencyModifier
			probe:Destroy()

			if afterLeaving ~= 0 or afterUnhide ~= 0 then
				error(
					string.format(
						"a part that left the character while hidden stayed at LocalTransparencyModifier "
							.. "%.1f (and %.1f after the flag cleared): that is the player's own gun going "
							.. "invisible when they unequip mid-aim",
						afterLeaving,
						afterUnhide
					),
					0
				)
			end
		end)

		it("puts the body back when the flag clears", function()
			local character = player.Character
			Camera.Rig.setLocalBodyHidden(true)
			Camera.Rig.setLocalBodyHidden(false)
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") then
					expect(part.LocalTransparencyModifier).to.equal(0)
				end
			end
		end)
	end)

	describe("occlusion", function()
		it("pulls in short of what the one ray found, once per frame", function()
			local calls = 0
			local hit: Vector3? = nil
			Camera.Rig.setCast(function(from: Vector3, to: Vector3): Vector3?
				calls += 1
				if hit then
					local direction = (to - from)
					if direction.Magnitude > 1e-4 then
						return from + direction.Unit * 4 -- 4 studs from the pivot
					end
				end
				return nil
			end)

			waitFrames(5)
			local before = calls
			waitFrames(10)
			expect(calls - before >= 10).to.equal(true) -- at least one per frame
			expect(calls - before <= 12).to.equal(true) -- and not more

			hit = Vector3.zero -- switch the fake cast on
			-- In third person only: while the replay holds the aim button the camera is already at
			-- the eye, ~0.4 studs from the pivot, and an occluder 4 studs away has nothing to pull
			-- in. Measured 0.40 on the run that taught this.
			expect(waitUntil(10, function()
				return Camera.getMode() == "Third" and Camera.getBlend() <= 0
			end)).to.equal(true)
			waitFrames(5)
			local root = rootPart()
			expect(root).to.be.ok()
			local pivot = (root :: BasePart).Position + Vector3.new(0, Config.PIVOT_HEIGHT_STUDS, 0)
			local distance = (Workspace.CurrentCamera.CFrame.Position - pivot).Magnitude
			print(string.format("[camera_client] occluded camera sits %.2f studs from the pivot", distance))
			expect(math.abs(distance - (4 - Config.OCCLUSION_PAD_STUDS)) < 0.2).to.equal(true)

			Camera.Rig.setCast(nil)
			waitFrames(3)
		end)
	end)

	describe("the cursor", function()
		it("is locked and hidden by default, and freed only by request", function()
			expect(UserInputService.MouseBehavior).to.equal(Enum.MouseBehavior.LockCenter)
			expect(UserInputService.MouseIconEnabled).to.equal(false)

			Camera.Cursor.requestFree("spec")
			waitFrames(2)
			expect(UserInputService.MouseBehavior).to.equal(Enum.MouseBehavior.Default)
			expect(UserInputService.MouseIconEnabled).to.equal(true)
			expect(Camera.Cursor.isFree()).to.equal(true)

			Camera.Cursor.requestFree("second")
			Camera.Cursor.release("spec")
			waitFrames(2)
			expect(Camera.Cursor.isFree()).to.equal(true) -- two tags need two releases
			expect(UserInputService.MouseBehavior).to.equal(Enum.MouseBehavior.Default)

			Camera.Cursor.release("second")
			waitFrames(2)
			expect(Camera.Cursor.isFree()).to.equal(false)
			expect(UserInputService.MouseBehavior).to.equal(Enum.MouseBehavior.LockCenter)
			expect(Camera.Cursor.stats().reasserts).to.equal(0)
		end)
	end)
end
