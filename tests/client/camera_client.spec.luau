-- camera_client.spec: the REAL camera in the real client. The maths is proved on the server
-- (tests/server/camera_mode.spec.luau); this proves the things only a running client can show --
-- that nothing else writes the camera or the mouse, that the aim path moves the real camera, and
-- that the viewmodel is genuinely on screen rather than merely existing.
--
-- It reaches the owner through Players.LocalPlayer.PlayerScripts, never through
-- StarterPlayerScripts, which is a template (docs/design/shotgun.md section 3.2).
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/camera.md (sections 9.2, 9.3)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local InputReady = require(ReplicatedStorage:WaitForChild("ClientTests"):WaitForChild("InputReady"))

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
			expect(Camera.stats().maxUpdateMs < 0.3).to.equal(true)
		end)
	end)

	-- FIRST, and that ordering is the test. Round 1, finding 1: this used to run after the
	-- fake-source tests, which left their fake installed and had already moved aimEnters/aimExits --
	-- so it passed with the aim-hold scenario deleted, and the "real right mouse drove the camera"
	-- claim rested on counters a fake had moved. It now runs while the PRODUCTION source installed
	-- by CameraBoot is still the only one, and asserts a DELTA taken here.
	describe("the harness-driven aim", function()
		it("entered and left Aiming from the real right mouse button", function()
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
				local parts = 0
				for _, part in ipairs(model:GetDescendants()) do
					if part:IsA("BasePart") then
						parts += 1
						expect(part.Transparency < 1).to.equal(true)
						expect(part.LocalTransparencyModifier < 1).to.equal(true)
						-- Not optional: the camera is a child of Workspace, so a CanQuery part here
						-- would be hit by this system's own occlusion ray.
						expect(part.CanQuery).to.equal(false)
					end
				end
				expect(parts >= 1).to.equal(true)
				expect(parts <= 4).to.equal(true)

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
