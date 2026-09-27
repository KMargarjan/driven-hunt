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
local Hud = require(scripts:WaitForChild("Hud"))
local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

-- THE ON BRANCH BY PARAMETER (docs/design/feature-flags.md 13.3). The flag is born OFF, so the
-- first-person POSE -- and the bead measurement that rests on it -- is driven through the public
-- `Viewmodel.update(camCFrame, state, config)` with a config of this spec's own, on the real camera
-- in the real viewport. Nothing is flipped and nothing has to be restored.
local firstPersonConfig = table.clone(Config) :: any
firstPersonConfig.FIRST_PERSON = true
table.freeze(firstPersonConfig)

-- WHICH LIVE BRANCH RAN. `FIRST_PERSON` decides which of the two `describe`s below is even built,
-- and the last `it` in the file asserts this is exactly 1. A guard that merely returns early is a
-- test that passes when the flag flips and nothing runs (design section 9); this one fails.
local liveBranches = 0

-- A state at a blend with every cosmetic term at its exact rest -- what `Viewmodel.update` takes
-- since task 89.
local function stateAtBlend(blend: number)
	local state = table.clone(Camera.Mode.initial(Config)) :: any
	state.mode = if blend > 0 then "Aiming" else "Third"
	state.blend = blend
	return table.freeze(state)
end

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

		it("says which camera this build is running, and agrees with the flag", function()
			-- ONE LINE, and it is what ties every branch guard in this file to the build actually
			-- running. The camera owns the switch (`Camera.isFirstPerson`) and the Hud asks IT, not
			-- `Flags`; both are asserted to be the same fact so the indirection cannot drift.
			print(
				string.format(
					"[camera_client] FIRST_PERSON = %s (Config %s, flag %s)",
					tostring(Camera.isFirstPerson()),
					tostring(Config.FIRST_PERSON),
					tostring(Flags.isOn("FIRST_PERSON"))
				)
			)
			expect(Camera.isFirstPerson()).to.equal(Config.FIRST_PERSON)
			expect(Camera.isFirstPerson()).to.equal(Flags.isOn("FIRST_PERSON"))
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

	-- ------------------------------------------------------- the two live branches (task 89, S1)
	-- Only one of these is built, and the counter at the bottom of the file proves it.
	if not Config.FIRST_PERSON then
		liveBranches += 1
		describe("third person -- the live OFF branch", function()
			it("sits in third person with the third-person field of view", function()
				expect(Camera.getMode()).to.equal("Third")
				expect(math.abs(Workspace.CurrentCamera.FieldOfView - Config.FOV_THIRD_DEG) < 0.01).to.equal(true)
			end)

			it("sits a boom behind the pivot, which is what first person removes", function()
				local root = rootPart()
				expect(root).to.be.ok()
				expect(waitUntil(5, function()
					return Camera.getMode() == "Third" and Camera.getBlend() <= 0
				end)).to.equal(true)
				waitFrames(2)
				local pivot = (root :: BasePart).Position + Vector3.new(0, Config.PIVOT_HEIGHT_STUDS, 0)
				local distance = (Workspace.CurrentCamera.CFrame.Position - pivot).Magnitude
				print(string.format("[camera_client] third-person camera sits %.2f studs from the pivot", distance))
				-- Loose on purpose: an occluder in the map may legitimately pull it in. The claim is
				-- that there IS a boom, which is the thing first person does away with.
				expect(distance > 2.5).to.equal(true)
			end)
		end)
	end

	if Config.FIRST_PERSON then
		liveBranches += 1
		describe("first person -- the live ON branch", function()
			-- NOT RUN IN A HARNESS RUN, and that is stated rather than hidden: the flag is born OFF,
			-- `test` and `test2` refuse to start while an override is set, and a playtest with the
			-- override on runs no specs. The ON branch's MATHS is covered by parameter in
			-- tests/server/camera_mode.spec.luau, its POSE by the viewmodel cases below, and its live
			-- wiring by the Director's screenshots (design section 9.4 says exactly this).
			it("puts the real camera at the eye, with the gun carried at blend 0", function()
				local root = rootPart()
				expect(root).to.be.ok()
				expect(waitUntil(5, function()
					return Camera.getBlend() <= 0
				end)).to.equal(true)
				waitFrames(2)
				local pivot = (root :: BasePart).Position + Vector3.new(0, Config.PIVOT_HEIGHT_STUDS, 0)
				local distance = (Workspace.CurrentCamera.CFrame.Position - pivot).Magnitude
				print(string.format("[camera_client] first-person camera sits %.2f studs from the pivot", distance))
				expect(distance <= Config.AIM_PIVOT_FORWARD_STUDS + 0.2).to.equal(true)
				-- CARRIED, NOT SUMMONED: the gun is on screen at blend 0, which is the difference
				-- VIEWMODEL_SHOW_BLEND makes in the other branch.
				expect(Camera.Viewmodel.isParented()).to.equal(true)
			end)

			it("casts no ray at all", function()
				local calls = 0
				Camera.Rig.setCast(function()
					calls += 1
					return nil
				end)
				waitFrames(10)
				Camera.Rig.setCast(nil)
				expect(calls).to.equal(0)
			end)
		end)
	end

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
			--
			-- AND IT IS MEASURED WITH NO FRAME IN BETWEEN (task 82). The refusal is SYNCHRONOUS --
			-- the BindableFunction's OnInvoke returns false before Camera.lookAt is reached, and
			-- `lookAtRequests` is written inside `Camera.lookAt` -- so this is a claim about ONE
			-- call, and one call is what the counters can answer for. Across three frames it was a
			-- claim about a GLOBAL counter instead, and this client has another legitimate caller:
			-- `shoot_boar.spec` connects a RenderStepped tracker at require time and calls
			-- `Camera.lookAt` EVERY FRAME for up to its 15 s once the harness has staged its shot and
			-- a boar is on the field -- and the spec suite runs while the input replay is staging it.
			-- Measured in the two-player run at 8daf457: `Expected 13, got 15`, two frames' worth of
			-- somebody else's traffic. The windowed claim that survives another caller is
			-- `landed <= requests`, which is the case above.
			local request = scripts:WaitForChild("Camera"):FindFirstChild("LookAtRequest")
			local before = Camera.stats()
			expect(request:Invoke("over", "there", nil)).to.equal(false)
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

		it("keeps the appearance of the gun it clones, and still strips everything else", function()
			-- THE ONE CLIENT-VISIBLE CHANGE OF TASK 74, AND IT WAS ASSERTED BY NOTHING (review
			-- round 1, finding 2). Karen's uploaded shotgun is a MeshPart carrying its PBR maps on a
			-- SurfaceAppearance child; the clone's sweep used to destroy every child that was not an
			-- Attachment, so the FIRST-PERSON gun would have lost its maps while the third-person
			-- gun kept them -- visible only in ADS, only to the player holding it.
			--
			-- Driven by injection rather than by whatever the server happened to load, so it says
			-- the same thing on a machine where the asset does not load at all.
			-- A MeshPart, because Roblox refuses a SurfaceAppearance anywhere else ("SurfaceAppearance
			-- can only be parented to MeshParts") -- and because that is what the real gun is.
			local source = Instance.new("MeshPart")
			source.Name = "Handle"
			source.Size = Vector3.new(0.4, 0.5, 4.4)
			source.Transparency = 1
			local keep = {
				Instance.new("SurfaceAppearance"),
				Instance.new("Texture"),
				Instance.new("Decal"),
				Instance.new("Attachment"),
			}
			local strip = { Instance.new("Weld"), Instance.new("Sound"), Instance.new("Folder") }
			for _, child in ipairs(keep) do
				child.Parent = source
			end
			for _, child in ipairs(strip) do
				child.Parent = source
			end
			-- a welded visible piece, so the clone has something to show as well as something to keep
			local piece = Instance.new("MeshPart")
			piece.Name = "BarrelLeft"
			piece.Size = Vector3.new(0.17, 0.17, 2.7)
			piece.Parent = source
			local pieceSkin = Instance.new("SurfaceAppearance")
			pieceSkin.Parent = piece

			local live = Camera.Viewmodel.getSource()
			Camera.Viewmodel.setSource(function()
				return source
			end)
			-- THE SOURCE IS ASKED FOUR TIMES A SECOND, NOT EVERY FRAME (Viewmodel's own comment: the
			-- pose is what has to be per frame). One update after setSource therefore rebuilds from
			-- the PREVIOUS handle -- which is how the first version of this test read the live gun's
			-- Handle and reported no SurfaceAppearance. Wait past the interval, then update.
			Camera.Viewmodel.clear()
			task.wait(0.3)
			Camera.Viewmodel.update(CFrame.new(0, 10, 0), stateAtBlend(1), Config)
			local model = Camera.Viewmodel.current()
			expect(model).to.be.ok()
			local clone = (model :: Model).PrimaryPart :: BasePart
			expect(clone).to.be.ok()

			local kept = {}
			for _, child in ipairs((clone :: Instance):GetChildren()) do
				kept[child.ClassName] = (kept[child.ClassName] or 0) + 1
			end
			-- WHAT MUST SURVIVE: the appearance, and the attachment the muzzle rides on.
			expect(kept.SurfaceAppearance).to.equal(1)
			expect(kept.Texture).to.equal(1)
			expect(kept.Decal).to.equal(1)
			-- THE GUN'S OWN ATTACHMENT SURVIVES THE SWEEP -- it is what the muzzle and the sight ride
			-- on -- and in THIS branch it is the only one there is.
			expect(kept.Attachment).to.equal(1)

			-- ------------------------------------------------ the first-person extras (round 2, f1)
			-- THE FILL LIGHT IS FIRST PERSON'S, AND ONLY FIRST PERSON'S. The clone is drawn in both
			-- branches -- with the flag off it is the ADS viewmodel Karen accepted on 2026-09-25 --
			-- so a light added to every clone put a glow on the ground behind a third-person player,
			-- in the camera task 89 promised not to touch. Both branches are driven here, from the
			-- same handle, because "it is absent" means nothing unless the same code can produce it.
			expect(clone:FindFirstChild("ViewmodelFillAt")).to.equal(nil)
			expect(clone:FindFirstChildOfClass("PointLight")).to.equal(nil)
			expect(clone:FindFirstChild("SightBead")).to.equal(nil)

			-- WHAT MUST NOT: a weld would be simulated under the camera, a sound would play twice.
			expect(kept.Weld).to.equal(nil)
			expect(kept.Sound).to.equal(nil)
			expect(kept.Folder).to.equal(nil)
			-- ...and the appearance of a welded PIECE survives too, not just the root's.
			local clonedPiece = (clone :: Instance):FindFirstChild("BarrelLeft")
			expect(clonedPiece).to.be.ok()
			expect((clonedPiece :: Instance):FindFirstChildOfClass("SurfaceAppearance")).to.be.ok()

			-- ...AND THE SAME HANDLE, REBUILT FOR FIRST PERSON, DOES GET THEM. Last, because a rebuild
			-- destroys the clone every assertion above reads: `clone` is a dead Instance after it.
			Camera.Viewmodel.clear() -- a config change does not rebuild a cached clone; this does
			Camera.Viewmodel.update(CFrame.new(0, 10, 0), stateAtBlend(1), firstPersonConfig)
			local lit = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
			local fill = lit:FindFirstChild("ViewmodelFillAt") :: Attachment
			expect(fill).to.be.ok()
			expect(fill:FindFirstChildOfClass("PointLight")).to.be.ok()
			local fillLights = 0
			for _, descendant in ipairs(lit:GetDescendants()) do
				if descendant:IsA("PointLight") then
					fillLights += 1
				end
			end
			expect(fillLights).to.equal(1)

			-- PUT THE LIVE SOURCE BACK. `CameraBoot` set it once at boot, so `setSource(nil)` would
			-- not restore it -- it would end it, and every later frame of this session would draw no
			-- viewmodel at all.
			Camera.Viewmodel.clear()
			Camera.Viewmodel.setSource(live)
			source:Destroy()
			expect(Camera.Viewmodel.getSource()).to.equal(live)
		end)

		it("rebuilds the clone when the source Handle's children change", function()
			-- TASK 76. The server upgrades a gun that was handed out before the mesh loaded
			-- (`Weapon.Hardware.upgrade`): the SAME Handle Instance loses ten welded parts and gains a
			-- `Model`. `builtFrom ~= handle` therefore never fires, so without watching the children
			-- the first-person gun would keep the parts fallback while the third-person gun -- the
			-- Tool this is a clone of -- wore the mesh. Two looks for one gun, which is the thing
			-- cloning the Handle exists to prevent.
			local source = Instance.new("Part")
			source.Name = "Handle"
			source.Size = Vector3.new(0.4, 0.5, 4.4)
			source.Transparency = 1
			local piece = Instance.new("Part")
			piece.Name = "BarrelLeft"
			piece.Size = Vector3.new(0.17, 0.17, 2.7)
			piece.Parent = source

			local live = Camera.Viewmodel.getSource()
			Camera.Viewmodel.setSource(function()
				return source
			end)
			Camera.Viewmodel.clear()
			task.wait(0.3) -- the source is asked four times a second, not per frame
			Camera.Viewmodel.update(CFrame.new(0, 10, 0), stateAtBlend(1), Config)
			local before = Camera.Viewmodel.current()
			expect(before).to.be.ok()
			local firstClone = (before :: Model).PrimaryPart :: Instance
			expect(firstClone:FindFirstChild("BarrelLeft")).to.be.ok()
			expect(firstClone:FindFirstChild("Model")).to.equal(nil)

			-- exactly what the upgrade does, in the same order: the mesh on, then the parts off
			local mesh = Instance.new("MeshPart")
			mesh.Name = "Model"
			mesh.Size = Vector3.new(4.4, 0.69, 0.25)
			mesh.Parent = source
			piece:Destroy()
			-- ChildAdded/ChildRemoved are DEFERRED, so the handlers have not run yet in this
			-- resumption. Waiting is the only way to see them; the production loop is running the
			-- whole time and leaves the model unparented at blend 0, so the update below is what
			-- rebuilds and reparents it.
			task.wait(0.1)

			Camera.Viewmodel.update(CFrame.new(0, 10, 0), stateAtBlend(1), Config)
			local after = Camera.Viewmodel.current()
			expect(after).to.be.ok()
			expect(after).never.to.equal(before)
			local clone = (after :: Model).PrimaryPart :: Instance
			expect(clone:FindFirstChild("Model")).to.be.ok()
			expect(clone:FindFirstChild("BarrelLeft")).to.equal(nil)

			Camera.Viewmodel.clear()
			Camera.Viewmodel.setSource(live)
			source:Destroy()
			expect(Camera.Viewmodel.getSource()).to.equal(live)
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
				-- EITHER GUN, AND THE CLAIM IS THE SAME FOR BOTH. Since Task 74 the gun may be one
				-- MeshPart welded to the invisible Handle (Karen's model) or Task 71's ten parts,
				-- depending on whether the asset loaded -- so the number is a range and what is
				-- really asserted is below: the envelope is the ONLY invisible part and everything
				-- else shows. A blank viewmodel still fails that.
				expect(parts >= 2).to.equal(true) -- the envelope plus at least one visible thing
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

	-- ------------------------------------------------------------------ the bead (task 90, S2)
	describe("the bead sight", function()
		-- A gun of this spec's own, so the case says the same thing on a machine where the uploaded
		-- asset never loads: the envelope, a `Sight` where `Shape.beadOffset` puts it, and a `Bead`
		-- piece at the same point -- which is what the parts gun really is.
		local SIGHT_LOCAL = CFrame.new(0, 0.255, -2.15)

		local function gunWithSight(withBead: boolean): BasePart
			local handle = Instance.new("MeshPart")
			handle.Name = "Handle"
			handle.Size = Shotgun.CONFIG.HANDLE_SIZE
			handle.Transparency = 1
			local sight = Instance.new("Attachment")
			sight.Name = "Sight"
			sight.CFrame = SIGHT_LOCAL
			sight.Parent = handle
			if withBead then
				local bead = Instance.new("Part")
				bead.Name = "Bead"
				bead.Shape = Enum.PartType.Ball
				bead.Size = Vector3.new(0.05, 0.05, 0.05)
				bead.CFrame = handle.CFrame * SIGHT_LOCAL
				bead.Parent = handle
			end
			return handle
		end

		-- Installs `handle` as the viewmodel's source, poses it against the LIVE camera with the
		-- first-person config, and hands the caller the clone -- then puts the live source back
		-- whatever happened. The source is asked four times a second, so the wait is not optional.
		local function posed(handle: BasePart, body)
			local live = Camera.Viewmodel.getSource()
			Camera.Viewmodel.setSource(function()
				return handle
			end)
			Camera.Viewmodel.clear()
			task.wait(0.3)
			local ok, why = pcall(body)
			Camera.Viewmodel.clear()
			Camera.Viewmodel.setSource(live)
			handle:Destroy()
			if not ok then
				error(why, 0)
			end
		end

		it("keeps the pivot the pose assumes: the model's pivot IS the cloned Handle", function()
			-- `aimOffset` is arithmetic about the model's pivot, and it is only the Handle's CFrame
			-- because `PrimaryPart` is set and `WorldPivot` is never written. An engine default this
			-- design leans on is a test and not a hope (design section 5.5).
			posed(gunWithSight(true), function()
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAtBlend(1), firstPersonConfig)
				local model = Camera.Viewmodel.current()
				expect(model).to.be.ok()
				local clone = (model :: Model).PrimaryPart :: BasePart
				expect(((model :: Model):GetPivot().Position - clone.Position).Magnitude < 1e-3).to.equal(true)
			end)
		end)

		it("puts the bead on the screen centre, which is where the shot goes", function()
			-- THE ONE TESTABLE NUMBER (design section 9.2 item 12), and the Director's question in
			-- this task: how far apart, in pixels, are the bead a player follows the animal with and
			-- the line the pellets travel down?
			--
			-- They are the same line by construction: `Weapon` fires from
			-- `workspace.CurrentCamera.CFrame` along its LookVector (docs/design/shotgun.md 5.5), so
			-- the shot's own aim point at any range projects to the centre of the screen. What is
			-- NOT free is that the drawn bead lands there too -- that is what `aimOffset` has to
			-- earn, and what this measures.
			--
			-- NO YIELD between the pose and the measurement: the production render step re-poses the
			-- viewmodel and moves the camera every frame, and a yield here would measure a pose this
			-- case did not set.
			posed(gunWithSight(true), function()
				local cam = Workspace.CurrentCamera
				local camCFrame = cam.CFrame
				local state = stateAtBlend(1)
				expect(state.swayDeg).to.equal(Vector2.zero)
				expect(state.bobStuds).to.equal(Vector3.zero)
				expect(state.recoilCamPitchDeg).to.equal(0)

				Camera.Viewmodel.update(camCFrame, state, firstPersonConfig)
				local model = Camera.Viewmodel.current()
				-- UNCONDITIONAL: `if model then` would make this whole block pass when no viewmodel
				-- was built at all (the Task 74 round-1 note).
				expect(model).to.be.ok()
				local clone = (model :: Model).PrimaryPart :: BasePart
				local sight = clone:FindFirstChild("Sight") :: Attachment
				local bead = clone:FindFirstChild("Bead") :: BasePart
				expect(sight).to.be.ok()
				expect(bead).to.be.ok()

				local viewport = cam.ViewportSize
				local centre = Vector2.new(viewport.X / 2, viewport.Y / 2)
				local perDegree = viewport.Y / cam.FieldOfView
				local tolerancePx = Config.BEAD_CENTRE_TOLERANCE_DEG * perDegree
				-- The shot's own line, 143 studs out (40 m, the range the design measures the
				-- tolerance at).
				local aimPoint = camCFrame.Position + camCFrame.LookVector * 143
				local shot = cam:WorldToViewportPoint(aimPoint)
				local shotPx = Vector2.new(shot.X, shot.Y)

				local worst = 0
				for _, point in ipairs({ sight.WorldPosition, bead.Position }) do
					local projected, onScreen = cam:WorldToViewportPoint(point)
					expect(onScreen).to.equal(true)
					local px = Vector2.new(projected.X, projected.Y)
					worst = math.max(worst, (px - centre).Magnitude, (px - shotPx).Magnitude)
					expect((px - centre).Magnitude <= tolerancePx).to.equal(true)
					expect((px - shotPx).Magnitude <= tolerancePx).to.equal(true)
				end
				TestKit.note(
					string.format(
						"task90 bead: worst %.2f px from the shot line and the screen centre, "
							.. "tolerance %.2f px (%.2f deg, viewport %dx%d, fov %.0f)",
						worst,
						tolerancePx,
						Config.BEAD_CENTRE_TOLERANCE_DEG,
						viewport.X,
						viewport.Y,
						cam.FieldOfView
					)
				)
				-- and the gun really did carry its own sight: nothing fell back
				expect(Camera.Viewmodel.sight()).to.equal(SIGHT_LOCAL)
			end)
		end)

		it("draws a bead when the gun has none, and leaves the parts gun's own alone", function()
			-- Karen, 2026-09-27: "we are missing front knob or how it calls where you aim and follow
			-- animal with that point". The uploaded gun is ONE MeshPart with a painted bead a few
			-- pixels across; this is the mark that replaces it, and it is drawn at the very
			-- attachment the pose lines up -- so the thing a player follows the animal with IS the
			-- thing the geometry aims.
			posed(gunWithSight(false), function()
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAtBlend(1), firstPersonConfig)
				local model = Camera.Viewmodel.current()
				expect(model).to.be.ok()
				local clone = (model :: Model).PrimaryPart :: BasePart
				local marker = clone:FindFirstChild("SightBead") :: BasePart
				expect(marker).to.be.ok()
				expect(marker.CanQuery).to.equal(false)
				expect(marker.CanCollide).to.equal(false)
				expect(marker.Anchored).to.equal(true)
				-- WITHIN A FLOAT, NOT EQUAL TO ONE. `BasePart.Size` is stored as float32, so the
				-- config's 0.055 comes back as 0.054999999701976776 -- measured, in the first
				-- two-player run of this task. The claim is the size the config asks for, and a
				-- round trip through the engine's own precision is not a difference.
				expect(math.abs(marker.Size.X - Config.BEAD_MARKER_STUDS) < 1e-4).to.equal(true)
				expect(marker.Color).to.equal(Config.BEAD_MARKER_COLOR)
				-- ON the sight, not near it: within a tenth of a bead of the attachment.
				local sight = clone:FindFirstChild("Sight") :: Attachment
				expect((marker.Position - sight.WorldPosition).Magnitude < 1e-3).to.equal(true)
			end)

			-- ...and the OFF BRANCH gets no drawn bead at all (round 2, finding 1): its sight picture
			-- is the framing Karen accepted for the shoulder camera, not a bead on the view axis.
			posed(gunWithSight(false), function()
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAtBlend(1), Config)
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				expect(clone:FindFirstChild("SightBead")).to.equal(nil)
			end)

			-- ...and a gun that brought its own bead gets nothing added: one bead, never two.
			posed(gunWithSight(true), function()
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAtBlend(1), firstPersonConfig)
				local model = Camera.Viewmodel.current()
				expect(model).to.be.ok()
				local clone = (model :: Model).PrimaryPart :: BasePart
				expect(clone:FindFirstChild("SightBead")).to.equal(nil)
				expect(clone:FindFirstChild("Bead")).to.be.ok()
			end)

			-- IT IS A METAL BEAD, NOT A RED DOT (task 92). Karen, after playing S2: "that red dot is
			-- not realistic, we need to improve what actually is on Beretta Parallelo" -- and what a
			-- 486 Parallelo carries is a small BRASS BALL on the rib. So the assertion is brass and
			-- metal: warm (red above green above blue), not saturated like the dot it replaces, and a
			-- material that is not its own light source. It is still deliberately NOT
			-- `Shotgun.CONFIG.LOOK.bead`: that off-white is the parts gun's own bead, a piece of the
			-- weapon other players see, while this is the aiming mark the camera draws for one player.
			local brass = Config.BEAD_MARKER_COLOR
			expect(brass.R > brass.G and brass.G > brass.B).to.equal(true)
			expect(brass.B * 255 > 40).to.equal(true) -- brass, not a red LED: blue is present
			expect(brass.R * 255 < 240).to.equal(true) -- and it is metal, not a glowing dot
			expect(Config.BEAD_MARKER_MATERIAL).to.equal(Enum.Material.Metal)
			expect(brass).never.to.equal(Shotgun.CONFIG.LOOK.bead)
			-- ...and the drawn bead really wears both, or the config rows above are a description of
			-- something nobody applied.
			posed(gunWithSight(false), function()
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAtBlend(1), firstPersonConfig)
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				local marker = clone:FindFirstChild("SightBead") :: BasePart
				expect(marker.Material).to.equal(Enum.Material.Metal)
				expect(marker.Color).to.equal(Config.BEAD_MARKER_COLOR)
			end)

			-- THE GUN CARRIES ITS OWN LIGHT (task 92). Karen: "Weapon color we need to improve and
			-- style now feels a bit broken, it has to be smooth and nice." A first-person gun lit by
			-- the sun alone is a near-black silhouette, so the viewmodel adds one PointLight of its
			-- own -- inside the camera, so it lights the gun and nothing a player could point at.
			posed(gunWithSight(false), function()
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAtBlend(1), firstPersonConfig)
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				local at = clone:FindFirstChild("ViewmodelFillAt") :: Attachment
				expect(at).to.be.ok()
				local light = at:FindFirstChildOfClass("PointLight") :: PointLight
				expect(light).to.be.ok()
				expect(light.Shadows).to.equal(false)
				-- WITHIN A FLOAT, for the same reason the bead's size is: `Light.Brightness` is
				-- float32, so 1.4 comes back as 1.399999976158142 (measured, this task's first run).
				expect(math.abs(light.Brightness - Config.VIEWMODEL_FILL_BRIGHTNESS) < 1e-4).to.equal(true)
				expect(math.abs(light.Range - Config.VIEWMODEL_FILL_RANGE_STUDS) < 1e-4).to.equal(true)
				-- ONE light, never one per rebuild: a leak here is a light per shot fired.
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAtBlend(1), firstPersonConfig)
				local lights = 0
				for _, descendant in ipairs(clone:GetDescendants()) do
					if descendant:IsA("PointLight") then
						lights += 1
					end
				end
				expect(lights).to.equal(1)
			end)
		end)
	end)

	-- ------------------------------------------------------------------ recoil, live (task 92)
	describe("the shot's kick", function()
		it("is wired, does nothing to the live third-person camera, and settles the gun", function()
			-- KAREN, after playing S2: "shooting has to have recoil a bit".
			--
			-- THE LIVE HALF IS THE PROMISE, not the feel: this client runs with `FIRST_PERSON` off, so
			-- `Camera.kick()` must be a no-op on the camera a player is looking through right now --
			-- task 89's promise that the flag-off branch is the shoulder camera Karen accepted.
			local before = Camera.getState()
			Camera.kick()
			local after = Camera.getState()
			expect(after.recoilCamPitchDeg).to.equal(0)
			expect(after.recoilGunPitchDeg).to.equal(0)
			expect(Camera.Mode.recoiling(after)).to.equal(false)
			expect(Camera.stats().recoilKicks).to.equal(0)
			expect(before.recoilCamPitchDeg).to.equal(0)

			-- ...and the first-person branch, by parameter, moves the gun on screen and brings it
			-- home: the same reducer the live camera would run with the flag on. The POSE is what a
			-- player sees, so that is what is measured rather than the numbers behind it.
			local kicked = Camera.Mode.kick(stateAtBlend(1), firstPersonConfig)
			local rest = Camera.Mode.viewmodelOffset(stateAtBlend(1), nil, firstPersonConfig)
			local shot = Camera.Mode.viewmodelOffset(kicked, nil, firstPersonConfig)
			expect((shot.Position - rest.Position).Magnitude > 0.05).to.equal(true)
			local settling = kicked
			for _ = 1, 120 do
				settling = Camera.Mode.step(
					settling,
					{ aiming = true, alive = true, hasCharacter = true, lookDelta = Vector2.zero },
					1 / 60,
					firstPersonConfig
				)
			end
			expect(Camera.Mode.recoiling(settling)).to.equal(false)
			expect(Camera.Mode.viewmodelOffset(settling, nil, firstPersonConfig)).to.equal(rest)
			TestKit.note(
				string.format(
					"task92 kick: gun moves %.3f studs on screen and is home in under 2 s; live branch kicked %d time(s)",
					(shot.Position - rest.Position).Magnitude,
					Camera.stats().recoilKicks
				)
			)
		end)
	end)

	-- ------------------------------------------------------ the break-open reload (task 96)
	describe("the break", function()
		it("hinges the barrels off the action, and throws a shell per fired barrel", function()
			-- KAREN, 2026-09-27: a BREAK ACTION like the real gun. `Weapon.Hardware` wears the gun as
			-- two welded meshes since this task, and the viewmodel rotates the one called `Barrels`
			-- about the knuckle -- which is the only reason the model was split at all.
			local handle = Instance.new("MeshPart")
			handle.Name = "Handle"
			handle.Size = Shotgun.CONFIG.HANDLE_SIZE
			handle.Transparency = 1
			local sight = Instance.new("Attachment")
			sight.Name = "Sight"
			sight.CFrame = CFrame.new(0, 0.336, -2.19)
			sight.Parent = handle
			local barrels = Instance.new("Part")
			barrels.Name = "Barrels"
			barrels.Size = Vector3.new(0.2, 0.2, 2.7)
			barrels.CFrame = handle.CFrame
			barrels.Parent = handle

			local live = Camera.Viewmodel.getSource()
			Camera.Viewmodel.setSource(function()
				return handle
			end)
			local ok, err = pcall(function()
				Camera.Viewmodel.clear()
				task.wait(0.3)

				-- SHUT: the barrels sit exactly where the body does, and there are no shells.
				Camera.Viewmodel.setReload({ open = false, spent = 0 })
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAtBlend(0), firstPersonConfig)
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				local cloned = clone:FindFirstChild("Barrels") :: BasePart
				expect(cloned).to.be.ok()
				local restAngle =
					math.deg(math.acos(math.clamp(cloned.CFrame.LookVector:Dot(clone.CFrame.LookVector), -1, 1)))
				expect(restAngle < 0.01).to.equal(true)
				expect(clone:FindFirstChild("SpentShell1")).to.equal(nil)

				-- OPEN, WITH BOTH BARRELS FIRED: the barrels swing down by the config's own angle
				-- about the hinge, and the muzzle drops rather than the whole gun turning.
				local open = table.clone(stateAtBlend(0)) :: any
				open.openTilt = 1
				table.freeze(open)
				Camera.Viewmodel.setReload({ open = true, spent = 2 })
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), open, firstPersonConfig)
				local swung =
					math.deg(math.acos(math.clamp(cloned.CFrame.LookVector:Dot(clone.CFrame.LookVector), -1, 1)))
				expect(math.abs(swung - firstPersonConfig.BREAK_OPEN_DEG) < 0.5).to.equal(true)
				expect(cloned.CFrame.LookVector.Y < clone.CFrame.LookVector.Y).to.equal(true) -- muzzle DOWN
				-- ...and a shell for each barrel that fired, drawn where the chambers are.
				expect(clone:FindFirstChild("SpentShell1")).to.be.ok()
				expect(clone:FindFirstChild("SpentShell2")).to.be.ok()
				TestKit.note(
					string.format(
						"task96 break: barrels swing %.1f deg, %d shell(s) drawn",
						swung,
						Camera.Viewmodel.stats().shellsDrawn
					)
				)

				-- ONE FIRED BARREL THROWS ONE SHELL. The thing a player notices if it is wrong.
				Camera.Viewmodel.setReload({ open = false, spent = 0 })
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAtBlend(0), firstPersonConfig)
				expect(clone:FindFirstChild("SpentShell1")).to.equal(nil)
				Camera.Viewmodel.setReload({ open = true, spent = 1 })
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), open, firstPersonConfig)
				expect(clone:FindFirstChild("SpentShell1")).to.be.ok()
				expect(clone:FindFirstChild("SpentShell2")).to.equal(nil)

				-- AND THE OFF BRANCH HINGES NOTHING: the third-person gun has no break to draw. At
				-- BLEND 1, because that branch only draws a viewmodel while the player is aiming --
				-- at blend 0 it unparents the clone, and an unparented clone is not a test of the
				-- hinge, it is a test of the threshold (measured: the case failed here first).
				local openAimed = table.clone(open) :: any
				openAimed.mode = "Aiming"
				openAimed.blend = 1
				table.freeze(openAimed)
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), openAimed, Config)
				local offAngle =
					math.deg(math.acos(math.clamp(cloned.CFrame.LookVector:Dot(clone.CFrame.LookVector), -1, 1)))
				expect(offAngle < 0.01).to.equal(true)

				Camera.Viewmodel.setReload(nil)
				Camera.Viewmodel.clear()
			end)
			Camera.Viewmodel.setSource(live)
			handle:Destroy()
			if not ok then
				error(err, 0)
			end
			-- THE LIVE CAMERA IS BACK AS IT WAS: nothing left open, nothing left holding shells.
			expect(Camera.Viewmodel.reloadState().open).to.equal(false)
			expect(Camera.stats().breakAngleDeg).to.equal(0)
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

	-- OFF-BRANCH ONLY, and it does not touch the counter: the counter counts the two branch blocks
	-- above, and one more `if` that silently skipped would be the thing the counter exists to catch.
	-- In first person the owner never calls `occlude` at all (design section 4.3), which the ON
	-- block asserts directly.
	describe("occlusion", function()
		it("pulls in short of what the one ray found, once per frame", function()
			if Config.FIRST_PERSON then
				-- Not a skip: the same claim, the other way round. With the flag on there is no cast
				-- to count, and the ON branch's own case asserts zero calls.
				expect(Camera.Rig).to.be.ok()
				return
			end
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

	describe("the crosshair", function()
		local equipped = { equipped = true }
		local bare = { equipped = false }

		it("is never drawn in first person, in all eight combinations", function()
			-- BY PARAMETER, so all eight run whichever branch this build is: the predicate is pure
			-- and public for exactly that reason (design section 6.2).
			for _, state in ipairs({ equipped, bare }) do
				for _, aiming in ipairs({ true, false }) do
					expect(Hud.crosshairVisible(state, aiming, true)).to.equal(false)
				end
			end
			-- ...and in third person it is the gun plus the hipfire, which is the case the "never"
			-- above would otherwise be true of for the wrong reason.
			expect(Hud.crosshairVisible(equipped, false, false)).to.equal(true)
			expect(Hud.crosshairVisible(equipped, true, false)).to.equal(false)
			expect(Hud.crosshairVisible(bare, false, false)).to.equal(false)
			expect(Hud.crosshairVisible(bare, true, false)).to.equal(false)
			expect(Hud.crosshairVisible(nil, false, false)).to.equal(false)
		end)

		it("is drawn on screen exactly as the predicate says, in this build", function()
			-- THE HALF THAT STOPS A PREDICATE BEING RIGHT WHILE THE DRAWING IS WRONG. The Hud reads
			-- the camera every frame, so the live GUI must agree with what the predicate answers for
			-- the same three inputs.
			local Weapon = require(scripts:WaitForChild("Weapon"))
			waitFrames(2)
			local wanted = Hud.crosshairVisible(Weapon.get(), Camera.getMode() == "Aiming", Camera.isFirstPerson())
			print(
				string.format(
					"[camera_client] crosshair drawn=%s, predicate=%s (firstPerson=%s, aiming=%s)",
					tostring(Hud.isCrosshairVisible()),
					tostring(wanted),
					tostring(Camera.isFirstPerson()),
					tostring(Camera.getMode() == "Aiming")
				)
			)
			expect(Hud.isCrosshairVisible()).to.equal(wanted)
			if Camera.isFirstPerson() then
				expect(Hud.isCrosshairVisible()).to.equal(false)
			end
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

	-- LAST IN THE FILE, and that is the point: it asserts that exactly one of the two live branch
	-- blocks was built. Both would mean the flag is two things at once; neither would mean a build
	-- whose camera nothing live tested -- and a guard that returns early inside an `it` would report
	-- a pass for a branch that never ran (design section 9).
	describe("the branch guard", function()
		it("ran exactly one live branch, and says which", function()
			print(
				string.format(
					"[camera_client] live branch: %s (%d built)",
					if Config.FIRST_PERSON then "first person" else "third person",
					liveBranches
				)
			)
			expect(liveBranches).to.equal(1)
		end)
	end)
end
