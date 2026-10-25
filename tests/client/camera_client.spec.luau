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
-- One fact, for one question: is the Tool in the hand a GUN? (task 152)
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
-- ...AND THE WIDER ONE THE TWO CAMERA MODULES ACTUALLY ASK (task 176): does the first-person view
-- DRAW the Tool in this hand? The owner asks it in `Camera.Viewmodel` and in `Camera.Rig`, and every
-- case below that excludes -- or requires -- a carried Tool asks the SAME one, never a looser test of
-- its own. Since task 176 the beater's HORN is drawn and therefore hidden; anything else in a hand is
-- not drawn and stays visible.
local HeldTool = require(ReplicatedStorage:WaitForChild("HeldTool"))
-- THE HORN'S OWN DATA, for the pose the drawn horn is asserted against and the attribute a blast is
-- stamped with -- never numbers this file repeats.
local Horn = require(ReplicatedStorage:WaitForChild("Horn"))
-- THE GUN THE VIEWMODEL BUILDS (task 114): its piece list, its sight and its bead colour, so this
-- file asserts against the one definition rather than against numbers it repeats.
local Gun = require(ReplicatedStorage:WaitForChild("Gun"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

-- THE ON BRANCH BY PARAMETER (docs/design/feature-flags.md 13.3). The flag is born OFF, so the
-- first-person POSE -- and the bead measurement that rests on it -- is driven through the public
-- `Viewmodel.update(camCFrame, state, config)` with a config of this spec's own, on the real camera
-- in the real viewport. Nothing is flipped and nothing has to be restored.
local firstPersonConfig = table.clone(Config) :: any
firstPersonConfig.FIRST_PERSON = true
table.freeze(firstPersonConfig)

-- AND THE OFF BRANCH BY PARAMETER TOO, SINCE TASK 97 FLIPPED THE DEFAULT. Every case below that
-- drives "the shoulder camera" used to pass the LIVE `Config` and get it by accident, because the
-- flag was born off. It is the live camera now, so those cases were asserting third-person claims --
-- no drawn bead, no fill light, no hinge -- about a first-person config. Both branches are built
-- here and neither is the live one; `Config` is still what the LIVE-branch cases read.
local thirdPersonConfig = table.clone(Config) :: any
thirdPersonConfig.FIRST_PERSON = false
table.freeze(thirdPersonConfig)

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

-- WHAT THE CAMERA PROMISES IS RENDERED TIME, NOT WALL TIME (task 156). `Mode.step` advances the
-- blend by `dt / Mode.blendSeconds(...)` -- "frame-rate-independent blending", in the owner's own
-- words at the top of Mode.luau -- so what it promises is that the move lands after that many
-- seconds OF RENDERED TIME. A wall clock asserts one more thing on top: that this machine kept
-- rendering through the window. The camera does not promise that and these cases are not about it;
-- the client runs sixteen client specs while the harness replays 95 s of input into it, and
-- `camera_client.spec:602` failed once in the task 155 gate (<runs-dir>/test-t155.log) and passed
-- at the same commit on the re-run.
--   FRAMES WITH NO LIVE CHARACTER DO NOT COUNT EITHER: `Mode.nextMode` holds the camera in Loading
-- or Dead for as long as a respawn takes, and the blend clock is not running there.
--   THE WALL-CLOCK CAP STAYS, far out, so a client that stops rendering FAILS rather than hangs.
--   The second return value is the MEASUREMENT -- rendered, wall, frames, the longest single frame,
-- the modes seen and the end state -- which is what makes the margin a number in the log instead of
-- a guess in a comment.
local function waitRendered(seconds: number, predicate: () -> boolean)
	local rendered, gap, frames = 0, 0, 0
	local modes, seen = {}, {}
	local startedAt = os.clock()
	local wallDeadline = startedAt + math.max(20, seconds * 20)
	local function record()
		local mode = Camera.getMode()
		if not seen[mode] then
			seen[mode] = true
			table.insert(modes, mode)
		end
		return mode
	end
	record()
	while rendered < seconds and os.clock() < wallDeadline do
		if predicate() then
			break
		end
		local dt = RunService.RenderStepped:Wait()
		frames += 1
		gap = math.max(gap, dt)
		local mode = record()
		if mode ~= "Loading" and mode ~= "Dead" then
			rendered += dt
		end
	end
	return predicate(),
		{
			rendered = rendered,
			wall = os.clock() - startedAt,
			frames = frames,
			gap = gap,
			modes = table.concat(modes, ","),
			mode = Camera.getMode(),
			blend = Camera.getBlend(),
			fov = Workspace.CurrentCamera.FieldOfView,
		}
end

-- THE BUDGET, ASKED OF THE SAME FUNCTION THE CAMERA ASKS, WITH THE SAME ARGUMENT (task 156). The
-- cases below used to budget `Config.AIM_BLEND_SECONDS + 0.5` -- the THIRD-person number, 0.20 --
-- for a move the live first-person camera makes in `AIM_RAISE_SECONDS` / `AIM_LOWER_SECONDS`
-- (0.25 / 0.20, from poses.json). `Mode.blendSeconds` is the one site that answers "how long does
-- this move take", `Camera.poseConfig()` is the very config `Camera.update` hands it every frame,
-- and tests/server/camera_mode.spec.luau already pins that pairing. A spec that works the number
-- out for itself is a second answer to a question with one owner.
local function blendBudget(aiming: boolean): number
	return Camera.Mode.blendSeconds(Camera.poseConfig(), aiming) + 0.5
end

-- One line per measured wait, so the next failure names its own cause instead of being re-guessed.
local function describeWait(at, budget: number): string
	return string.format(
		"%.3f s rendered of %.3f budgeted, %.3f s on the clock over %d frame(s), longest frame %.3f s;"
			.. " modes seen %s; ended mode=%s blend=%.3f fov=%.2f",
		at.rendered,
		budget,
		at.wall,
		at.frames,
		at.gap,
		at.modes,
		at.mode,
		at.blend,
		at.fov
	)
end

local function rootPart(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

return function()
	-- KAREN, 2026-10-09: *"no weapon when it loads"*. Two windows, both measured in the Forest Test
	-- with a per-frame trace from t = 0, and one assertion each -- see task 133.
	describe("there is a gun on screen when the session starts", function()
		-- KAREN, 2026-10-16 ~19:00: *"once I close shop I can't move mouse seems disabled need to go
		-- back to turn again fix that"*.
		--
		-- A MOUSE LOCKED TO THE CENTRE HAS NO POINTER, so a `gameProcessedEvent` on a mouse movement
		-- at that moment can only come from a piece of interface the player cannot point at and
		-- cannot get out from under -- and the camera used to drop the delta for it, which is a
		-- camera that will not turn for a reason nobody can see. `Camera.wantsDelta` is the rule, and
		-- it is pure so this is the whole of it.
		--
		-- THE OLD CODE FAILS THE SECOND LINE: it was `if processed then return end`, which is this
		-- function answering false for a locked cursor.
		it("takes a mouse delta the interface claimed only while the cursor is locked", function()
			local LOCKED = Enum.MouseBehavior.LockCenter
			local FREE = Enum.MouseBehavior.Default
			-- NOBODY CLAIMED IT: the camera turns, whatever the cursor is doing.
			expect(Camera.wantsDelta(false, LOCKED)).to.equal(true)
			expect(Camera.wantsDelta(false, FREE)).to.equal(true)
			-- THE INTERFACE CLAIMED IT AND THE CURSOR IS LOCKED: there is no pointer, so it is the
			-- camera's. This is the line that fails on the old code.
			expect(Camera.wantsDelta(true, LOCKED)).to.equal(true)
			-- THE INTERFACE CLAIMED IT AND THE CURSOR IS FREE: the player is pointing at a menu, and
			-- a camera that turned under his hand would be fighting him. Unchanged.
			expect(Camera.wantsDelta(true, FREE)).to.equal(false)
			-- ...AND THE LIVE CAMERA IS IN THE STATE THE RULE IS WRITTEN FOR: `Camera.Cursor` is the
			-- one writer of that property, and with no menu open it locks.
			Camera.Cursor.apply()
			expect(UserInputService.MouseBehavior).to.equal(LOCKED)
			expect(Camera.wantsDelta(true, UserInputService.MouseBehavior)).to.equal(true)
		end)

		it("has its sources wired by the composition root, every single boot", function()
			-- THE ONE THAT MADE HER SESSION GUNLESS. `CameraBoot` read `PlayerScripts.Weapon` with
			-- `FindFirstChild`, so on a boot where that module had not replicated yet the whole
			-- wiring block was skipped FOR THE SESSION: no aim source, no muzzle provider, no break
			-- source, and no viewmodel source -- which draws no gun at all, for ever, while the Tool
			-- sits correctly in the character.
			--
			-- MEASURED: 4 of 10 fresh Plays on this machine. A failing one read `frames=465
			-- parented=false fp=true/true src=false tool=HAND(Shotgun,handle=true,Part)`.
			--
			-- THIS IS THE ASSERTION THAT CATCHES IT, and it is why "no source" may not be treated as
			-- an acceptable state anywhere in this file: the aim-path case below reads the source to
			-- decide whether this client has a gun, and a source that was never installed answers
			-- "no handle" -- so the bug PASSED every case in this spec.
			-- WAITED FOR, NOT SAMPLED: the fix is a `WaitForChild` with a ten-second bound, so the
			-- claim is "they are wired within the boot window", which is the same shape the mode
			-- assertion below uses. A nil after that is the bug, not a slow boot.
			expect(waitUntil(20, function()
				return Camera.Viewmodel.getSource() ~= nil
			end)).to.equal(true)
			expect(Camera.getAimSource()).to.be.ok()
			expect(Camera.getBreakSource()).to.be.ok()
			TestKit.note("camera_client: the composition root wired the viewmodel, aim and break sources")
		end)

		it("never wears a mesh this client has not downloaded", function()
			-- THE SECOND WINDOW. The gun is built from `Gun.pieces`, and each piece is either model
			-- B's published MESH or the measured BOX beside it. The build took the mesh as soon as
			-- the server had published it -- but a `MeshPart` whose mesh has not been downloaded
			-- renders as NOTHING, and the box had already been dropped. Measured: from 2.942 s to
			-- 3.332 s the whole gun on screen was the bead.
			--
			-- `Viewmodel.meshReady` is the rule that closed it, and this drives both of its answers
			-- without a network: a plain Part has nothing to download, and a MeshPart with no mesh at
			-- all can never be drawn.
			local plain = Instance.new("Part")
			expect(Camera.Viewmodel.meshReady(plain)).to.equal(true)
			plain:Destroy()
			local empty = Instance.new("MeshPart")
			expect(Camera.Viewmodel.meshReady(empty)).to.equal(false)
			empty:Destroy()

			-- ...AND THERE IS ALWAYS SOMETHING TO DRAW INSTEAD, which is what makes the rule safe:
			-- every piece that CAN be a mesh carries its own box, so withholding the mesh is a plain
			-- dark gun and never a hole where a gun should be.
			local boxed = 0
			for _, piece in ipairs(Gun.pieces(Shotgun.CONFIG)) do
				if piece.meshKey ~= nil then
					expect(piece.size).to.be.ok()
					expect(piece.shape).to.be.ok()
					expect(piece.color).to.be.ok()
					boxed += 1
				end
			end
			expect(boxed >= 2).to.equal(true)

			-- ...AND NOTHING ON THE GUN THAT IS ON SCREEN RIGHT NOW is a mesh this client cannot
			-- draw. The live half of the claim: by the time the suite runs the downloads have long
			-- landed, so this asserts the END state the rebuild is supposed to reach -- the meshes,
			-- not the boxes it started with.
			Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAtBlend(1), firstPersonConfig)
			local gun = Camera.Viewmodel.current()
			if gun ~= nil then
				local waiting = 0
				for _, part in ipairs(gun:GetDescendants()) do
					if part:IsA("MeshPart") and not Camera.Viewmodel.meshReady(part) then
						waiting += 1
					end
				end
				expect(waiting).to.equal(0)
				TestKit.note(
					string.format(
						"camera_client: the drawn gun wears %d mesh(es) and 0 it cannot draw",
						Camera.Viewmodel.stats().meshesDrawn
					)
				)
			end
		end)
	end)

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
			-- RUN IN EVERY HARNESS RUN SINCE TASK 97, which flipped the flag's default to true: this
			-- is the camera the game has. The branch's MATHS is still covered by parameter in
			-- tests/server/camera_mode.spec.luau and its POSE by the viewmodel cases below; what only
			-- this block can say is that the real camera, in a real client, is at the eye.
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
				--
				-- ROLE-AWARE, because a DRIVER carries no GUN
				-- (`Match.CONFIG.DRIVERS_MAY_SHOOT = false`) and the viewmodel clones the Handle of
				-- the Tool in the local character. "A driver has a gun in frame" would be the bug,
				-- so it is asserted rather than skipped (TASKS.md row 34a).
				--
				-- NO GUN IS NOT THE SAME AS NO TOOL, SINCE `HORN` BECAME A V1 DEFAULT (task 233).
				-- This branch read `expect(Camera.Viewmodel.isParented()).to.equal(false)` -- written
				-- when a beater carried NOTHING -- and it failed in the Director's two-player gate,
				-- `[harness2] FAIL: 32/36 @ 6ade841d`, *"Expected false, got true"* on the DRIVER
				-- client. It was right to fail: that client really was holding
				-- `Workspace.Player2.Horn.Handle` (the run's own note, from the case further down
				-- this file), and since task 176 the horn has its own viewmodel branch and its own
				-- poses, so a parented clone is the CORRECT answer for a beater.
				--
				-- WHAT THE CLAIM BECOMES IS STRICTLY MORE, NOT LESS. The original sentence -- a gun
				-- in a driver's frame is the bug -- is now ASSERTED IN SO MANY WORDS rather than
				-- implied by an empty screen: what he is holding is named, and it must be the HORN.
				-- The question is asked of `HeldTool`, the one shared fact the viewmodel itself
				-- keys off, exactly as the empty-handed case further down this file already does --
				-- so this spec carries no second opinion about what draws.
				--
				-- BOTH ARMS STAY LIVE. With `HORN` off a beater carries nothing, `drawsFirstPerson`
				-- is false and the `else` below is the assertion this branch always made; the
				-- carry rule's own two states are proved by parameter in `zz_horn.spec`
				-- (`Horn.carriesFor(on, team)`).
				--
				-- A SHOOTER IS WAITED FOR, NOT SAMPLED. The gun arrives when the drive arms him,
				-- which is some way into the run and not at the moment this case happens to reach
				-- here -- measured: this read false on the shooter's first `test2` pass.
				if Role.isDriver() then
					waitFrames(5)
					local driverSource = Camera.Viewmodel.getSource()
					local driverHandle = if driverSource then driverSource() else nil
					local driverTool = driverHandle and driverHandle.Parent
					local draws = driverTool ~= nil and driverTool:IsA("Tool") and HeldTool.drawsFirstPerson(driverTool)
					if draws then
						-- THE HORN, AND NEVER A WEAPON. This is the old sentence, made explicit.
						expect(HeldTool.kindOf(driverTool)).to.equal(HeldTool.HORN)
						expect(HeldTool.kindOf(driverTool)).never.to.equal(HeldTool.WEAPON)
						expect(Camera.Viewmodel.isParented()).to.equal(true)
						TestKit.note(
							string.format(
								"camera_client: the driver's first-person frame holds %s, drawn as a %s and not a weapon",
								(driverTool :: Tool).Name,
								tostring(HeldTool.kindOf(driverTool))
							)
						)
					else
						expect(Camera.Viewmodel.isParented()).to.equal(false)
						TestKit.note(
							string.format(
								"camera_client: the driver draws nothing in first person; he carries %s",
								if driverTool ~= nil then (driverTool :: Instance).Name else "no Tool at all"
							)
						)
					end
				else
					-- THE VIEWMODEL FOLLOWS THE EQUIPPED TOOL, and that is the claim -- not "the drive
					-- has armed him by now", which is a fact about the drive's clock and not about
					-- the camera.
					--
					-- WHY IT IS WRITTEN THIS WAY (task 129). Measured in a plain DEV Play, with no
					-- harness: the Shotgun is in the CHARACTER and the viewmodel is parented from
					-- 12 s to 95 s, every sample. Measured in the gate's own run, in this window:
					-- the character holds nothing and the Backpack holds one. Something in the
					-- harness's session -- the replayed input, or the drive's placement respawn
					-- landing inside it -- takes the gun off him, and a case that demands "armed
					-- within 25 seconds" is then asserting the harness's timing rather than the
					-- camera's rule. The server's own tally says every grant WAS equipped
					-- (`match_live` note: equip now=3 late=3 gaveUp=0).
					--
					-- So: whenever the Tool is in the character, the viewmodel must be there with
					-- it. The sampling runs for the same 25 seconds, and the note records which of
					-- the two worlds this run was.
					local held, parented, samples = false, false, 0
					local deadline = os.clock() + 25
					while os.clock() < deadline do
						samples += 1
						local character = player.Character
						local carrying = false
						for _, child in ipairs(character and character:GetChildren() or {}) do
							if child:IsA("Tool") then
								carrying = true
							end
						end
						if carrying then
							held = true
							parented = waitUntil(1, function()
								return Camera.Viewmodel.isParented()
							end)
							break
						end
						task.wait(0.1)
					end
					if held then
						expect(parented).to.equal(true)
					else
						local backpack = player:FindFirstChildOfClass("Backpack")
						local waiting = 0
						for _, child in ipairs(backpack and backpack:GetChildren() or {}) do
							if child:IsA("Tool") then
								waiting += 1
							end
						end
						TestKit.note(
							string.format(
								"camera_client: the drive had not put a gun in his hands during this"
									.. " window -- %d sample(s) over 25 s, %d Tool(s) waiting in the Backpack."
									.. " The viewmodel rule is only asserted while he is carrying one.",
								samples,
								waiting
							)
						)
					end
				end
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
			local raiseBudget = blendBudget(true)
			fake.aiming = true
			local raised, raiseAt = waitRendered(raiseBudget, function()
				return Camera.getMode() == "Aiming" and Camera.getBlend() >= 1
			end)
			TestKit.note("camera_client: the raise took " .. describeWait(raiseAt, raiseBudget))
			expect(raised).to.equal(true)
			expect(math.abs(Workspace.CurrentCamera.FieldOfView - Config.FOV_AIM_DEG) < 0.01).to.equal(true)

			local root = rootPart()
			expect(root).to.be.ok()
			local distance = (Workspace.CurrentCamera.CFrame.Position - (root :: BasePart).Position).Magnitude
			print(string.format("[camera_client] aimed camera is %.2f studs from the root", distance))
			expect(distance < 2.5).to.equal(true)

			local lowerBudget = blendBudget(false)
			fake.aiming = false
			local lowered, lowerAt = waitRendered(lowerBudget, function()
				return Camera.getMode() == "Third" and Camera.getBlend() <= 0
			end)
			TestKit.note("camera_client: the lower took " .. describeWait(lowerAt, lowerBudget))
			expect(lowered).to.equal(true)
			expect(math.abs(Workspace.CurrentCamera.FieldOfView - Config.FOV_THIRD_DEG) < 0.01).to.equal(true)
		end)

		it("shows a viewmodel that is really on screen, and unparents it afterwards", function()
			if Role.isDriver() then
				-- The viewmodel is a clone of the Tool's Handle (docs/design/camera.md section 7), so
				-- a driver aiming an empty pair of hands must get NO viewmodel -- not an empty Model,
				-- and not somebody else's gun.
				fake.aiming = true
				local raisedForDriver = waitRendered(blendBudget(true), function()
					return Camera.getBlend() >= 1
				end)
				expect(raisedForDriver).to.equal(true)
				-- ...AND THE CLAIM IS ASKED OF THE SAME FUNCTION THE CAMERA ASKS. `Role` is resolved
				-- once, at require time, from the team this player was put on, and `test2` ends a
				-- drive and respawns everybody -- so a client can be re-teamed under a role this file
				-- already decided, and "a driver has no gun" then measures the wrong thing. What the
				-- viewmodel actually depends on is the SOURCE: no Handle, no viewmodel. Reading the
				-- source itself cannot disagree with what the camera saw this frame, which reading
				-- the character separately can (measured: it did, twice).
				local source = Camera.Viewmodel.getSource()
				local handle = if source then source() else nil
				-- ...AND A HANDLE IS NOT ENOUGH, SINCE TASK 152: the beater's HORN is a Tool in the
				-- character, so the source hands one back for a driver who is carrying no gun at all.
				-- What the view does with it is one shared fact -- `HeldTool.kindOf` -- and the claim
				-- follows it: a Tool it names draws a viewmodel (since task 176 the horn is one of
				-- those, with its own branch and its own poses), and a Tool it does not name draws
				-- nothing, which is the EMPTY-HANDED claim. The same question the owner asks, asked
				-- here, rather than a looser test of what is in the hand.
				local tool = handle and handle.Parent
				if tool ~= nil and tool:IsA("Tool") and not HeldTool.drawsFirstPerson(tool) then
					TestKit.note(
						string.format(
							"camera_client: this driver carries %s, which is not a weapon; no viewmodel is the claim",
							(tool :: Tool).Name
						)
					)
					handle = nil
				end
				if handle == nil then
					expect(Camera.Viewmodel.current()).to.equal(nil)
					expect(Camera.stats().viewmodelParented).to.equal(false)
				else
					-- ...AND THE POSITIVE IS ASSERTED TOO, so both arms carry a claim: a handle means a
					-- clone on screen, which is this spec's whole subject.
					TestKit.note(
						string.format(
							"camera_client: this client is on the drivers but holds %s; the shooter's claim applies",
							handle:GetFullName()
						)
					)
					expect(waitUntil(5, function()
						return Camera.Viewmodel.current() ~= nil
					end)).to.equal(true)
					expect(Camera.stats().viewmodelParented).to.equal(true)
				end
				fake.aiming = false
				local loweredForDriver = waitRendered(blendBudget(false), function()
					return Camera.getBlend() <= 0
				end)
				expect(loweredForDriver).to.equal(true)
				return
			end
			fake.aiming = true
			local raisedForViewmodel = waitRendered(blendBudget(true), function()
				return Camera.getBlend() >= 1
			end)
			expect(raisedForViewmodel).to.equal(true)

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
				-- THE MUZZLE FLASH IS NOT A PIECE OF THE GUN (task 112, `Viewmodel.flash`): it is an
				-- invisible 0.05-stud Part named `MuzzleFlash`, created under the clone to carry a
				-- PointLight and two emitters, and `Debris` takes it away `smoke.seconds +
				-- flash.seconds + 0.2` = 1.835 s after each shot. While it is alive the clone has a
				-- THIRD invisible part and `visible == parts - 2` is false -- which is exactly how
				-- `test2` failed at task 118's head, in a file task 118 does not touch. It is
				-- skipped by NAME rather than counted: the claim below is about the gun's own
				-- pieces, and a blank viewmodel still fails it.
				local FLASH_NAME = "MuzzleFlash"
				local parts, visible = 0, 0
				for _, part in ipairs(model:GetDescendants()) do
					if part:IsA("BasePart") and part.Name ~= FLASH_NAME then
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
				-- HOW MANY PARTS IS A RANGE, because a hinge group whose upload has not landed is
				-- drawn as its own measured box -- so what is really asserted is below: the two
				-- ENVELOPES are the only invisible parts and everything else shows. A blank
				-- viewmodel still fails that.
				expect(parts >= 3).to.equal(true) -- two envelopes plus at least one visible thing
				-- A GUN, NOT SOMEBODY'S CHARACTER -- plus, in first person, the two gloved hands that
				-- hold it (design section 8.2 budgets the gun at 16 and the arms at 4 on top).
				expect(parts <= (if Config.FIRST_PERSON then 20 else 16)).to.equal(true)
				-- TWO INVISIBLE ENVELOPES, AND THEY ARE NAMED (task 114). The retired gun was a CLONE
				-- of the Tool's Handle: one invisible envelope with the visible pieces welded under
				-- it, so "the envelope is the only invisible part" read `parts - 1`. The gun is BUILT
				-- now (`buildNewGun`, task 99) and carries a second one -- `Barrels`, the group that
				-- swings -- because what hinges has to be a PARENT rather than a list of names. Both
				-- are asserted by name, which is stricter than counting them.
				local handle = model.PrimaryPart :: BasePart
				local barrels = handle:FindFirstChild("Barrels") :: BasePart
				expect(handle.Transparency).to.equal(1)
				expect(barrels).to.be.ok()
				expect(barrels.Transparency).to.equal(1)
				expect(visible).to.equal(parts - 2)

				-- Every ancestor present, up to the DataModel: an orphaned tree is invisible however
				-- true its properties are (docs/PROJECT_CONTEXT.md).
				local node: Instance? = model
				while node and node ~= game do
					node = node.Parent
				end
				expect(node).to.equal(game)
			end

			fake.aiming = false
			local loweredForViewmodel = waitRendered(blendBudget(false), function()
				return Camera.getBlend() <= 0
			end)
			expect(loweredForViewmodel).to.equal(true)
			waitFrames(3)
			-- AND WHAT HAPPENS AT BLEND 0 IS THE BRANCH'S OWN ANSWER. With the flag off the clone is
			-- UNPARENTED below `VIEWMODEL_SHOW_BLEND`, which is what makes a leak visible on screen
			-- instead of hiding as a transparent part. In first person the gun is CARRIED: it stays
			-- in frame at blend 0, and that is the whole of task 89's carry pose.
			expect(Camera.stats().viewmodelParented).to.equal(Config.FIRST_PERSON)
		end)
	end)

	-- ------------------------------------------------------------------ the bead (task 90, S2)
	describe("the bead sight", function()
		-- A SOURCE HANDLE OF THIS SPEC'S OWN, AND NOTHING ELSE ON IT (task 114). The viewmodel BUILDS
		-- the gun now -- `Gun`'s piece list plus model B's two hinge groups where the server has
		-- published them -- so the Handle it is handed answers exactly one question: is the player
		-- holding the gun. Its own `Sight` and its own `Bead` come from `Gun.sight` and
		-- `Gun.beadOffset`, which is why this case says the same thing on a machine where the
		-- uploaded asset never loads.
		local SIGHT_LOCAL = Gun.sight(Shotgun.CONFIG)

		local function gunSource(): BasePart
			local handle = Instance.new("MeshPart")
			handle.Name = "Handle"
			handle.Size = Shotgun.CONFIG.HANDLE_SIZE
			handle.Transparency = 1
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
			task.wait(0.3)
			-- CLEARED WITH NO YIELD AFTER IT, so the `update` inside `body` is the call that builds
			-- the gun: the live first-person render step would otherwise have built it already, from
			-- this spec's source but with the LIVE config.
			Camera.Viewmodel.clear()
			local ok, why = pcall(body)
			Camera.Viewmodel.clear()
			Camera.Viewmodel.setSource(live)
			handle:Destroy()
			if not ok then
				error(why, 0)
			end
		end

		it("keeps the pivot the pose assumes: the model's pivot IS the Handle it builds", function()
			-- `aimOffset` is arithmetic about the model's pivot, and it is only the Handle's CFrame
			-- because `PrimaryPart` is set and `WorldPivot` is never written. An engine default this
			-- design leans on is a test and not a hope (design section 5.5).
			posed(gunSource(), function()
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
			posed(gunSource(), function()
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
				-- THE BEAD IS THE BARREL GROUP'S PIECE (task 114). It was looked for on the Handle
				-- while the gun was a clone of the Tool's -- that gun's drawn marker hung there --
				-- and `Gun.pieces` gives this one `group = "barrels"`, because a bead is a sight ON
				-- the barrels and has to swing down with them when the gun breaks open.
				local bead = (clone:FindFirstChild("Barrels") :: BasePart):FindFirstChild("Bead") :: BasePart
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
				-- and the gun really did carry its own sight: nothing fell back. `Gun.sight` is the
				-- one definition of where it is, and `buildNewGun` is what puts the attachment there.
				expect(Camera.Viewmodel.sight()).to.equal(SIGHT_LOCAL)
			end)
		end)

		it("carries ONE bead of its own, on the rib, and the gun's own light", function()
			-- KAREN, 2026-09-27: "we are missing front knob or how it calls where you aim and follow
			-- animal with that point".
			--
			-- IT IS THE GUN'S OWN PIECE SINCE TASK 114, and that is the whole of this case's history.
			-- The gun used to be a CLONE of the Tool's Handle -- one MeshPart with a bead painted a
			-- few pixels across -- so the viewmodel DREW one, `SightBead`, at the `Sight` attachment
			-- when the clone had none. The built gun carries a real `Bead` at exactly
			-- `Gun.beadOffset`, which is the same expression `Gun.sight` answers with, so the mark a
			-- player follows the animal with and the point the geometry aims are one Instance.
			posed(gunSource(), function()
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAtBlend(1), firstPersonConfig)
				local model = Camera.Viewmodel.current()
				expect(model).to.be.ok()
				local clone = (model :: Model).PrimaryPart :: BasePart
				-- ONE BEAD, NEVER TWO, and no drawn marker left anywhere: `SightBead` was the name
				-- the drawn one carried, and nothing writes it any more.
				local beads = 0
				for _, found in ipairs(clone:GetDescendants()) do
					if found:IsA("BasePart") and found.Name == "Bead" then
						beads += 1
					end
					expect(found.Name).never.to.equal("SightBead")
				end
				expect(beads).to.equal(1)
				local bead = (clone:FindFirstChild("Barrels") :: BasePart):FindFirstChild("Bead") :: BasePart
				expect(bead).to.be.ok()
				expect(bead.CanQuery).to.equal(false)
				expect(bead.CanCollide).to.equal(false)
				expect(bead.Anchored).to.equal(true)
				-- IT IS METAL AND NOT A RED DOT (task 92). Karen, after playing S2: "that red dot is
				-- not realistic, we need to improve what actually is on Beretta Parallelo" -- and
				-- what a 486 Parallelo carries is a small brass ball on the rib. `Gun.LOOK.bead` is
				-- the one definition of its colour, and the piece really wears it.
				expect(bead.Material).to.equal(Enum.Material.Metal)
				expect(bead.Color).to.equal(Gun.LOOK.bead)
				-- ON THE SIGHT, not near it: the attachment the aimed pose lines up with the view
				-- axis is at the same point, within a thousandth of a stud.
				local sight = clone:FindFirstChild("Sight") :: Attachment
				expect((bead.Position - sight.WorldPosition).Magnitude < 1e-3).to.equal(true)
				TestKit.note(
					string.format(
						"task114 the bead is the gun's own piece, %.4f studs from the Sight",
						(bead.Position - sight.WorldPosition).Magnitude
					)
				)
			end)

			-- THE GUN CARRIES ITS OWN LIGHT (task 92). Karen: "Weapon color we need to improve and
			-- style now feels a bit broken, it has to be smooth and nice." A first-person gun lit by
			-- the sun alone is a near-black silhouette, so the viewmodel adds one PointLight of its
			-- own -- inside the camera, so it lights the gun and nothing a player could point at.
			posed(gunSource(), function()
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
		it("is wired, kicks the live camera the branch says it should, and settles the gun", function()
			-- KAREN, after playing S2: "shooting has to have recoil a bit".
			--
			-- THE LIVE HALF IS THE PROMISE, not the feel, and since task 97 the live branch is FIRST
			-- PERSON: `Camera.kick()` really does move the camera a player is looking through, and
			-- then brings it back to EXACTLY where it was. Both halves are asserted here, because
			-- "it kicked" without "it came home" is a camera that drifts a degree per shot.
			-- IT STARTS FROM REST, AND THAT IS WAITED FOR RATHER THAN ASSUMED (task 120). The input
			-- scenario fires REAL shots into this client, so a kick from another case's shot can
			-- still be settling when this one begins: on the stack gate of 2026-10-04 this read
			-- 0.0000136 and failed a spec about a camera that was behaving perfectly. Waiting is the
			-- promise itself and not a weakening of it -- `Mode.recoiling` is true while ANY recoil
			-- field is non-zero, and the spring snaps all six to EXACT zero together below
			-- `RECOIL_REST_EPSILON`, so "not recoiling" and "pitch is exactly 0" are the same fact.
			-- The "it came home" assertion after the kick is untouched.
			expect(waitUntil(3, function()
				return not Camera.Mode.recoiling(Camera.getState())
			end)).to.equal(true)
			local kicks = Camera.stats().recoilKicks
			local before = Camera.getState()
			expect(before.recoilCamPitchDeg).to.equal(0)
			Camera.kick()
			local after = Camera.getState()
			if Config.FIRST_PERSON then
				expect(Camera.Mode.recoiling(after)).to.equal(true)
				expect(Camera.stats().recoilKicks).to.equal(kicks + 1)
				-- AND THE LIVE CAMERA IS LEFT AS IT WAS FOUND. The spring is critically damped and
				-- snaps to exact zero at `RECOIL_REST_EPSILON`, so this is a value and not an
				-- asymptote -- and a spec that left the live camera recoiling would hand every
				-- screenshot after it a tilted horizon.
				expect(waitUntil(3, function()
					return not Camera.Mode.recoiling(Camera.getState())
				end)).to.equal(true)
				expect(Camera.getState().recoilCamPitchDeg).to.equal(0)
			else
				expect(after.recoilCamPitchDeg).to.equal(0)
				expect(after.recoilGunPitchDeg).to.equal(0)
				expect(Camera.Mode.recoiling(after)).to.equal(false)
				expect(Camera.stats().recoilKicks).to.equal(kicks)
			end

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
				local function angleBetween(): number
					return math.deg(math.acos(math.clamp(cloned.CFrame.LookVector:Dot(clone.CFrame.LookVector), -1, 1)))
				end
				local restAngle = angleBetween()
				TestKit.note(string.format("task96 shut: barrels %.3f deg off the body", restAngle))
				-- 0.1 DEGREE, NOT 0.01, AND IT IS MEASURED RATHER THAN RELAXED (task 97). The barrels'
				-- rest pose is read off the clone as `clone.CFrame:ToObjectSpace(barrels.CFrame)` and
				-- put back as `swungGun * rest`, which is a round trip through two float32 CFrames.
				-- Since task 97 the live first-person camera builds this clone, so that round trip
				-- starts from a real world pose instead of this spec's tidy CFrame.new(0, 12, 0) --
				-- and the driver's two-player run measured 0.020 degrees of residue where the
				-- shooter's measured 0.000. The thing this bound exists to exclude is a 35-degree
				-- swing, so 0.1 is still 350 times smaller than the failure it catches.
				expect(restAngle < 0.1).to.equal(true)
				-- WHERE THE BEAD SITS WITH THE GUN SHUT, and whose it is: the barrels'. Both are read
				-- here so the open case can say it MOVED and that it moved WITH them. It is the gun's
				-- own `Bead` piece since task 114; the drawn `SightBead` went with the cloned gun.
				local shutBead = cloned:FindFirstChild("Bead") :: BasePart
				expect(shutBead).to.be.ok()
				expect(shutBead.Parent).to.equal(cloned)
				local openBeadRest = shutBead.Position
				local beadOnBarrels = cloned.CFrame:ToObjectSpace(shutBead.CFrame)
				expect(clone:FindFirstChild("SpentShell1")).to.equal(nil)

				-- OPEN, WITH BOTH BARRELS FIRED: the barrels swing down by the config's own angle
				-- about the hinge, and the muzzle drops rather than the whole gun turning.
				local open = table.clone(stateAtBlend(0)) :: any
				open.openTilt = 1
				table.freeze(open)
				Camera.Viewmodel.setReload({ open = true, spent = 2, loaded = { false, false } })
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), open, firstPersonConfig)
				local swung = angleBetween()
				TestKit.note(
					string.format(
						"task96 open: barrels %.2f deg (asked %.0f), muzzle Y %.3f vs body %.3f",
						swung,
						firstPersonConfig.BREAK_OPEN_DEG,
						cloned.CFrame.LookVector.Y,
						clone.CFrame.LookVector.Y
					)
				)
				expect(math.abs(swung - firstPersonConfig.BREAK_OPEN_DEG) < 0.5).to.equal(true)
				expect(cloned.CFrame.LookVector.Y < clone.CFrame.LookVector.Y).to.equal(true) -- muzzle DOWN
				-- THE BEAD TRAVELS WITH THE BARRELS (round 2). A bead is a sight on the rib: with the
				-- gun open it belongs down at the muzzle, not floating where the muzzle used to be.
				local marker = cloned:FindFirstChild("Bead") :: BasePart
				expect(marker).to.be.ok()
				expect((marker.Position - openBeadRest).Magnitude > 0.2).to.equal(true)
				-- ...and it is still in the SAME place on the barrels, which is what makes it a
				-- sight rather than a decoration that happens to move.
				local carried = cloned.CFrame:ToObjectSpace(marker.CFrame)
				expect((carried.Position - beadOnBarrels.Position).Magnitude < 1e-4).to.equal(true)

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
				Camera.Viewmodel.setReload({ open = false, spent = 0, loaded = { true, true } })
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAtBlend(0), firstPersonConfig)
				expect(clone:FindFirstChild("SpentShell1")).to.equal(nil)
				Camera.Viewmodel.setReload({ open = true, spent = 1, loaded = { false, false } })
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), open, firstPersonConfig)
				expect(clone:FindFirstChild("SpentShell1")).to.be.ok()
				expect(clone:FindFirstChild("SpentShell2")).to.equal(nil)

				-- A CHAMBER THE SERVER HAS LOADED GETS ITS FRESH SHELL, and only that chamber: the
				-- reload feeds one barrel at a time and the drawn shells follow the replica rather
				-- than a timer (round 2, finding 1).
				--
				-- ...BUT NOT UNTIL THE HAND HAS CARRIED IT IN (task 111, and this is what task 114
				-- made the only answer). Karen, watching the first version: "either we have 2
				-- animation when shells go inside or one go straight another from hand" -- so a shell
				-- exists ONLY once the left hand has fetched it, and before the fetch is over there is
				-- nothing to see. The RETIRED gun's shells slid themselves in the instant the replica
				-- said "loaded", which is the behaviour this block used to read while the flag was
				-- off. So the load is driven on the viewmodel's own CLOCK SEAM, forward past the whole
				-- fetch-carry-seat, which is the state being measured: a shell in the chamber.
				local load = firstPersonConfig.SHELL_LOAD
				local seatAfter = load.fetchSeconds + load.carrySeconds + load.seatSeconds + 0.05
				local fake = 3000.0
				Camera.Viewmodel.setClock(function()
					return fake
				end)
				Camera.Viewmodel.setReload({ open = true, spent = 1, loaded = { true, false } })
				-- BEFORE THE FETCH IS OVER THERE IS NOTHING, which is the half of the claim that the
				-- old self-sliding feed could never have made.
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), open, firstPersonConfig)
				expect(clone:FindFirstChild("FreshShell1")).to.equal(nil)
				fake += seatAfter
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), open, firstPersonConfig)
				local drawn = {}
				for _, child in ipairs(clone:GetChildren()) do
					table.insert(drawn, child.Name)
				end
				TestKit.note(
					string.format(
						"task114 feed: reload=%s, %.2f s after the server loaded barrel 1, clone holds [%s]",
						tostring(Camera.Viewmodel.reloadState().open),
						seatAfter,
						table.concat(drawn, ", ")
					)
				)
				expect(clone:FindFirstChild("FreshShell1")).to.be.ok()
				expect(clone:FindFirstChild("FreshShell2")).to.equal(nil)
				-- THE SECOND BARREL IS ITS OWN LOAD, on its own clock: the server feeds one at a time.
				Camera.Viewmodel.setReload({ open = true, spent = 1, loaded = { true, true } })
				fake += seatAfter
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), open, firstPersonConfig)
				local after = {}
				for _, child in ipairs(clone:GetChildren()) do
					table.insert(after, child.Name)
				end
				local both = Camera.Viewmodel.reloadState()
				TestKit.note(
					string.format(
						"task114 feed2: loaded=[%s, %s], clone holds [%s]",
						tostring(both.loaded[1]),
						tostring(both.loaded[2]),
						table.concat(after, ", ")
					)
				)
				expect(clone:FindFirstChild("FreshShell2")).to.be.ok()
				-- THE LIVE CLOCK IS BACK before the branch check below, which needs a spent shell to
				-- really be on the gun -- see the note there.
				Camera.Viewmodel.setClock(nil)

				-- AND THE OFF BRANCH HINGES NOTHING: the third-person gun has no break to draw. At
				-- BLEND 1, because that branch only draws a viewmodel while the player is aiming --
				-- at blend 0 it unparents the clone, and an unparented clone is not a test of the
				-- hinge, it is a test of the threshold (measured: the case failed here first).
				local openAimed = table.clone(open) :: any
				openAimed.mode = "Aiming"
				openAimed.blend = 1
				table.freeze(openAimed)
				-- RE-ARMED FIRST, so the claim below is not satisfied by an eject that had simply
				-- finished (task 114). The spent shells live for `SHELL_EJECT_SECONDS` from the rising
				-- edge of "open", and the block above has just stepped a clock well past it: without
				-- this, "the OFF branch draws no shells" would pass with nothing to draw. A fresh
				-- `setReload` is a new rising edge, so the shells are really there to be taken away.
				Camera.Viewmodel.setReload({ open = false, spent = 0, loaded = { false, false } })
				Camera.Viewmodel.setReload({ open = true, spent = 2, loaded = { false, false } })
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), open, firstPersonConfig)
				expect(clone:FindFirstChild("SpentShell1")).to.be.ok()
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), openAimed, thirdPersonConfig)
				local offAngle = angleBetween()
				TestKit.note(string.format("task96 flag off: barrels %.3f deg off the body", offAngle))
				expect(offAngle < 0.1).to.equal(true) -- see the shut case above for why 0.1
				-- ...AND IT DRAWS NO SHELLS EITHER (round 2, finding 2). The gun wears its barrels as
				-- a separate piece in every build, so without a flag test the DEFAULT camera would
				-- swing them and litter the clone with shells the moment a player reloaded.
				expect(clone:FindFirstChild("SpentShell1")).to.equal(nil)
				expect(clone:FindFirstChild("FreshShell1")).to.equal(nil)
				expect(clone:FindFirstChild("FreshShell2")).to.equal(nil)

				Camera.Viewmodel.setReload(nil)
				Camera.Viewmodel.clear()
			end)
			Camera.Viewmodel.setClock(nil) -- whatever happened above, the live clock is back
			Camera.Viewmodel.setSource(live)
			handle:Destroy()
			if not ok then
				error(err, 0)
			end
			-- THE LIVE CAMERA IS BACK AS IT WAS: nothing left open, nothing left holding shells.
			expect(Camera.Viewmodel.reloadState().open).to.equal(false)
			-- THE BREAK ANGLE IS THE LIVE GUN'S, NOT THIS CASE'S (task 129). It was asserted at
			-- exactly 0 and failed in three gate runs out of nine, at 9.3, 27.7 and 31.4 degrees --
			-- because the harness replays a real reload while the client specs run, and a gun that is
			-- genuinely open mid-drive has a real angle. What this case owns is its own clone, which
			-- it has just destroyed; what it can honestly claim about the live camera is that the
			-- angle is a REAL one and not a leftover beyond the gun's own travel.
			local liveBreak = Camera.stats().breakAngleDeg
			expect(liveBreak >= 0).to.equal(true)
			expect(liveBreak <= Camera.Poses.config(Config).BREAK_OPEN_DEG + 0.001).to.equal(true)
		end)
	end)

	-- ------------------------------------------------------------------------ the hands (task 93)
	describe("the hands", function()
		it("puts the right hand on the body and the left on the barrels, and neither on the player", function()
			-- KAREN, 2026-09-27: "right hand grip and left hand pipes like in real life". The pose
			-- itself is proved on the server (`camera_mode.spec`, pure geometry); this proves the
			-- things only a running client can show -- that the hands are REAL Instances under the
			-- camera, posed from that same geometry, parented to the piece each one holds, and that
			-- they are not on the character.
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

			-- THE TEMPLATES, INJECTED. The real ones are loaded on the server and published into
			-- ReplicatedStorage, which a Studio with no network may not have; driving the seam means
			-- both branches -- hands and no hands -- are reached on purpose rather than on a good day.
			-- TASK 252 PROBE: the two numbers that mark the drawn gun STALE and rebuild it mid-call
			-- (`Viewmodel.update`'s quarter-second tick): how many pieces the server has published
			-- into this weapon's folder, and how many of them this client can draw yet.
			local folderName = Camera.Viewmodel.geometryNow().FOLDER_NAME
			local function folderChildren(): { Instance }
				local folder = ReplicatedStorage:FindFirstChild(folderName)
				return if folder then folder:GetChildren() else {}
			end

			-- WHICH STEP OF THIS CASE WAS RUNNING, so a failure names itself (task 252). This case
			-- restores the live camera's source and templates in a `pcall` and re-raises at the
			-- bottom, and `error(err, 0)` put EVERY failure in this 200-line body on the re-raise's
			-- own line: `camera_client.spec:1618` is what tasks 235, 242, 249, 251 and 253 all had
			-- to go on, and not one of them could say which assertion it was. The stage is prepended
			-- to the message instead.
			local stage = "setup"

			local fakes: { [string]: BasePart } = {}
			local liveSource = Camera.Viewmodel.getSource()
			local liveHands = Camera.Viewmodel.getHandTemplates()
			Camera.Viewmodel.setSource(function()
				return handle
			end)
			Camera.Viewmodel.setHandTemplates(function(name: string): BasePart?
				if fakes[name] == nil then
					local part = Instance.new("Part")
					part.Name = name .. "Template"
					part.Size = Vector3.new(1.28, 0.57, 0.53)
					fakes[name] = part
				end
				return fakes[name]
			end)

			local ok, err = pcall(function()
				stage = "the first build"
				Camera.Viewmodel.clear()
				task.wait(0.3)

				-- THE LAST WRITER BEFORE THE MEASUREMENT IS THIS SPEC, AND IT HAS TO BE (task 252).
				-- `Camera.step` calls `Viewmodel.setReload(breaking)` EVERY FRAME off the weapon
				-- replica (`src/client/Camera/init.luau`), so a `setReload(nil)` placed BEFORE the
				-- `task.wait` above is overwritten by the next live render frame -- and with the
				-- replayed input holding the real gun open with a shell in flight, the "carry" frame
				-- below drew the left hand at the SHELL-FEED pose instead of on the forend. That is
				-- the flake, and it is measured: at `c1084110` the pair below read "left hand moved
				-- 0.182 studs on the body and 0.2695 on the barrels" against its `< 1e-3` claim,
				-- where the same tree reads 0.219 / 0.0000 -- `<runs-dir>/test-t229-r2b.log` against
				-- `test-t229-r2c.log`, with the RIGHT hand byte-identical in both, so the gun and
				-- the barrels were in the same place and only the left hand was somewhere else.
				--
				-- SO IT IS SET AFTER THE LAST YIELD, and nothing from here to the end of this case
				-- yields at all: the whole measurement runs inside one resumption, which is the only
				-- way a module that another owner writes every frame can be held still.
				Camera.Viewmodel.setReload(nil)
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAtBlend(0), firstPersonConfig)
				local builtModel = Camera.Viewmodel.current()
				local builtAt = Camera.Viewmodel.stats().rebuilds
				local readyAtCapture = Camera.Viewmodel.readyMeshesIn(folderName)
				local childrenAtCapture = #folderChildren()
				local clone = (builtModel :: Model).PrimaryPart :: BasePart
				local cloned = clone:FindFirstChild("Barrels") :: BasePart
				local right = clone:FindFirstChild("HandRight") :: BasePart
				local left = cloned:FindFirstChild("HandLeft") :: BasePart
				expect(right).to.be.ok()
				expect(left).to.be.ok()
				stage = "whose piece each hand is"
				-- NO COUNTER HERE. Since task 97 the live camera is first person, so its own render
				-- step draws hands on this clone too -- from the REAL templates, in whatever frame
				-- falls between this spec's calls. A delta of exactly 2 was a claim about which of
				-- the two got there first, and a session-wide total is satisfied by any earlier live
				-- frame; neither is the claim. The claim is the two parts found on the clone, on the
				-- right pieces, at the pose the pure geometry gives -- which is what follows.
				-- WHOSE PIECE EACH ONE IS, asserted as the parent rather than as a position: the
				-- grip is on the body and the forend is on the barrels, and that is what decides
				-- which one swings when the gun breaks open.
				expect(right.Parent).to.equal(clone)
				expect(left.Parent).to.equal(cloned)
				-- NOT THE PLAYER'S OWN ARMS. The two owners are disjoint by parent (design section
				-- 9.2): the camera's hands are under workspace.CurrentCamera and `Rig`'s hidden body
				-- parts are under the character, and neither may reach into the other.
				expect(right:IsDescendantOf(Workspace.CurrentCamera)).to.equal(true)
				local character = player.Character
				if character then
					expect(right:IsDescendantOf(character)).to.equal(false)
					expect(left:IsDescendantOf(character)).to.equal(false)
				end
				for _, hand in ipairs({ right, left }) do
					expect(hand.Anchored).to.equal(true)
					expect(hand.CanQuery).to.equal(false) -- the occlusion cast must not hit them
					expect(hand.CanCollide).to.equal(false)
					-- NO SCRIPTS CAME WITH THEM, which is the claim -- not "no children". A real
					-- uploaded hand carries its `SurfaceAppearance`, and it must: a hand that loses
					-- its maps is the purple untextured leg of docs/PROJECT_CONTEXT.md.
					for _, inside in ipairs(hand:GetDescendants()) do
						expect(inside:IsA("LuaSourceContainer")).to.equal(false)
					end
				end
				-- POSED FROM THE PURE GEOMETRY, not from numbers this file repeats.
				stage = "the right hand's pose"
				local wantRight = Camera.Mode.rightHandOffset(firstPersonConfig)
				local gotRight = clone.CFrame:ToObjectSpace(right.CFrame)
				TestKit.note(
					string.format(
						"task93 right hand at (%.2f, %.2f, %.2f), wanted (%.2f, %.2f, %.2f)",
						gotRight.Position.X,
						gotRight.Position.Y,
						gotRight.Position.Z,
						wantRight.Position.X,
						wantRight.Position.Y,
						wantRight.Position.Z
					)
				)
				expect((gotRight.Position - wantRight.Position).Magnitude < 1e-3).to.equal(true)

				-- THE LEFT HAND RIDES THE BARRELS AND THE RIGHT ONE DOES NOT. On a break gun the
				-- forend is bolted to the barrels, so the hand holding it swings down with them --
				-- and the hand on the grip stays exactly where it was, because the body does not
				-- move at all.
				--
				-- MEASURED IN THE BODY'S OWN FRAME, NOT IN THE WORLD, and the first run of this case is
				-- why: opening the gun also moves the WHOLE gun into `Mode.breakOffset`, so both hands
				-- travel in world space and "the left hand moved" would have passed for the wrong
				-- reason while "the right hand did not" simply failed. What is being claimed is about
				-- the gun's own parts: the left hand's place on the BODY changes (it went down with the
				-- barrels) while its place on the BARRELS does not, and the right hand's place on the
				-- body does not change at all.
				stage = "the break: which hand rides the barrels"
				-- WAIT ON THE FACT, NOT ON THE CLOCK (L-029). What this pair claims -- "the left
				-- hand's place on the barrels did not change" -- is only true while that hand is
				-- holding the FOREND. `Viewmodel.loading` is the one thing that takes it off the
				-- barrels to push a shell into the breech, and it answers a weight: 0 means no feed
				-- is being drawn. Asserted on BOTH measured frames, so a writer that does get in
				-- fails this case at its own line instead of mismeasuring the pair.
				local feedShut = select(1, Camera.Viewmodel.loading(firstPersonConfig))
				expect(feedShut).to.equal(0)
				local leftOnBarrels = cloned.CFrame:ToObjectSpace(left.CFrame)
				local leftOnBody = clone.CFrame:ToObjectSpace(left.CFrame)
				local rightOnBody = clone.CFrame:ToObjectSpace(right.CFrame)
				local open = table.clone(stateAtBlend(0)) :: any
				open.openTilt = 1
				table.freeze(open)
				Camera.Viewmodel.setReload({ open = true, spent = 2, loaded = { false, false } })
				-- A TRUE RISING EDGE, because the line above runs with the breech SHUT: `setReload`
				-- starts the spent shells' clock and clears `loadedAt` only on the 0 -> 1 edge, so an
				-- "open" the module was already in leaves another writer's feed clocks standing.
				expect(select(1, Camera.Viewmodel.loading(firstPersonConfig))).to.equal(0)
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), open, firstPersonConfig)
				-- TASK 252 PROBE: did the module rebuild UNDER this measurement? The pair above and
				-- below is only a measurement if both halves came off the SAME clone.
				TestKit.note(
					string.format(
						"task252: shell feed %.3f shut / %.3f open (0 = the left hand is on the forend), rebuilds %d -> %d, same model %s, folder %d/%d children ready, was %d/%d",
						feedShut,
						select(1, Camera.Viewmodel.loading(firstPersonConfig)),
						builtAt,
						Camera.Viewmodel.stats().rebuilds,
						tostring(Camera.Viewmodel.current() == builtModel),
						Camera.Viewmodel.readyMeshesIn(folderName),
						#folderChildren(),
						readyAtCapture,
						childrenAtCapture
					)
				)
				local leftNowOnBody = clone.CFrame:ToObjectSpace(left.CFrame)
				local leftNowOnBarrels = cloned.CFrame:ToObjectSpace(left.CFrame)
				local rightNowOnBody = clone.CFrame:ToObjectSpace(right.CFrame)
				TestKit.note(
					string.format(
						"task93 break: left hand moved %.3f studs on the body and %.4f on the barrels; right hand %.4f",
						(leftNowOnBody.Position - leftOnBody.Position).Magnitude,
						(leftNowOnBarrels.Position - leftOnBarrels.Position).Magnitude,
						(rightNowOnBody.Position - rightOnBody.Position).Magnitude
					)
				)
				expect((leftNowOnBody.Position - leftOnBody.Position).Magnitude > 0.05).to.equal(true)
				expect((leftNowOnBarrels.Position - leftOnBarrels.Position).Magnitude < 1e-3).to.equal(true)
				-- THE RIGHT HAND IS PLACED FROM THE BODY, AND THAT IS THE CLAIM -- not that it stands
				-- still (task 114). It used to be asserted as "moved less than a thousandth of a
				-- stud", which was true of the RETIRED gun's pose file: task 98 seeded its carry, aim
				-- and reload hands identical, so opening the gun moved nothing. Karen posed model B's
				-- hands by eye and her reload really does hold the grip further forward than the
				-- carry -- 0.12 studs -- so "it did not move" is now a claim about her picture rather
				-- than about the owner boundary.
				--
				-- WHAT THE OWNER BOUNDARY ACTUALLY SAYS is that each hand is placed from the piece it
				-- HOLDS: the right from the body's transform, the left from the barrels'. So both are
				-- measured against `Mode.handOffsetAt` in that piece's own frame, which is the one
				-- answer `Viewmodel.poseHands` is allowed to draw -- and it cannot pass for the wrong
				-- reason, because a hand carried along by the wrong transform lands somewhere else.
				-- MEASURED IN THE BODY'S FRAME, which for the RIGHT hand is the frame it is posed in:
				-- the model's pivot IS the Handle (`PrimaryPart` set, `WorldPivot` never written), so
				-- `clone.CFrame:ToObjectSpace` undoes exactly the transform `poseHands` applied. The
				-- LEFT hand's own frame is the one `Viewmodel.hinge` RETURNS rather than the barrel
				-- PART's -- the part sits at its own rest offset down the gun from it -- which is why
				-- its claim above is "its place on the barrels did not change" and not a pose
				-- comparison: that constant offset would have to be added back by hand here.
				local wantOpen = Camera.Mode.handOffsetAt("right", open, firstPersonConfig)
				expect((rightNowOnBody.Position - wantOpen.Position).Magnitude < 1e-3).to.equal(true)

				-- THE FLAG-OFF CAMERA HAS NO HANDS, and it TAKES THEM OFF rather than walking away
				-- (the lesson the barrels taught in task 96, round 2): the clone is drawn in that
				-- branch too, while aiming, and a session that flipped the flag must not leave two
				-- gloves floating by the shoulder camera's gun.
				stage = "the flag-off camera takes the hands off"
				Camera.Viewmodel.setReload(nil)
				local aimedOff = table.clone(stateAtBlend(1)) :: any
				aimedOff.mode = "Aiming"
				table.freeze(aimedOff)
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), aimedOff, thirdPersonConfig)
				expect(clone:FindFirstChild("HandRight")).to.equal(nil)
				expect(cloned:FindFirstChild("HandLeft")).to.equal(nil)

				-- AND A GUN WITH NO TEMPLATES IS STILL A GUN (design 5.3). The load can fail, the
				-- asset can be moderated away, a Studio can have no network: the fallback is no
				-- hands, never a broken gun, and it is COUNTED rather than silent.
				stage = "a gun with no templates is still a gun"
				Camera.Viewmodel.setHandTemplates(function(): BasePart?
					return nil
				end)
				local missingBefore = Camera.Viewmodel.stats().handsMissing
				Camera.Viewmodel.clear()
				-- NO `task.wait` HERE, AND THAT IS THE CLAIM (task 252). This used to `clear()`, sleep
				-- 0.3 s and then assert the counter had moved -- and MEASURED, it had already moved
				-- inside the sleep: the note read "handsMissing 11 -> 12 (12 after the wait)" on every
				-- run, so what passed was the LIVE render step rebuilding on the injected source, and
				-- the call below contributed nothing (`handsMissingCounted` is set once per clone, and
				-- the live frame had already set it). The sleep bought nothing either: `clear()` drops
				-- the model, `cachedHandle` is unchanged, so the very next `update` rebuilds -- so the
				-- call under test is now what counts, with no live frame able to get in front of it.
				--
				-- IT IS ALSO WHY THREE TASKS NAMED THE WRONG ASSERTION. `handsMissing` only ever
				-- rises and `clear()` resets the per-clone guard immediately above, so this line
				-- cannot read false on a live camera at all -- yet 235, 242a(c) and 249a(d) all
				-- recorded it as the flake, because the only line a failure could be reported on was
				-- the `pcall` re-raise at the bottom of this 200-line case (see `stage`).
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAtBlend(0), firstPersonConfig)
				local bare = Camera.Viewmodel.current()
				expect(bare).to.be.ok()
				local bareClone = (bare :: Model).PrimaryPart :: BasePart
				expect(bareClone:FindFirstChild("HandRight")).to.equal(nil)
				TestKit.note(
					string.format(
						"task93 no templates: handsMissing %d -> %d, gun still drawn with %d part(s)",
						missingBefore,
						Camera.Viewmodel.stats().handsMissing,
						Camera.Viewmodel.stats().parts
					)
				)
				expect(Camera.Viewmodel.stats().handsMissing > missingBefore).to.equal(true)

				Camera.Viewmodel.clear()
			end)
			Camera.Viewmodel.setHandTemplates(liveHands)
			Camera.Viewmodel.setSource(liveSource)
			for _, fake in pairs(fakes) do
				fake:Destroy()
			end
			handle:Destroy()
			if not ok then
				error(string.format("[hands: %s] %s", stage, tostring(err)), 0)
			end
			-- THE LIVE CAMERA IS BACK AS IT WAS: its own source, its own templates, nothing open.
			expect(Camera.Viewmodel.getSource()).to.equal(liveSource)
			expect(Camera.Viewmodel.getHandTemplates()).to.equal(liveHands)
		end)
	end)

	-- THE BEATER'S HORN, DRAWN IN THE FIRST PERSON (task 176). KAREN, 2026-10-13 ~19:05: *"horn
	-- still hangign somewhere it has to be in hand now I can turn around and horn stand in place
	-- somehwere behind"*. The horn is welded to the character's hand and the character does not turn
	-- with the look, so the only fix that holds is the gun's: draw it in CAMERA space.
	--
	-- DRIVEN THROUGH THE PUBLIC `Viewmodel.update` WITH AN INJECTED SOURCE, exactly as the hands case
	-- above is, so this runs on every client of every run -- a hunter's as well as a beater's -- and
	-- asserts the real path rather than a parallel one. The Tool is this spec's own: named what
	-- `Weapon.Horn` names its Tool, because the NAME is what the shared fact reads.
	describe("the horn in the hand", function()
		-- A horn-shaped Handle with one visible piece on it, which is what the server's own Handle is
		-- (an invisible envelope wearing the uploaded mesh, or task 152's coil of parts).
		local function hornTool(): (Tool, BasePart)
			local tool = Instance.new("Tool")
			tool.Name = Horn.TOOL_NAME
			tool.RequiresHandle = true
			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Size = Horn.CONFIG.HANDLE_SIZE
			handle.Transparency = 1
			-- A `MeshPart`, WHICH IS WHAT THE SERVER WELDS ON (task 169): the uploaded horn, sized by
			-- the manifest row to `Horn.MESH.SIZE_STUDS`. It matters to this case because
			-- `Viewmodel.hornMouthpiece` reads which BUILD is on screen off the clone -- a mesh horn
			-- and task 152's coil of parts put their mouthpiece in different places -- so a probe made
			-- of plain parts would measure the fallback's geometry and not the one Karen is holding.
			local body = Instance.new("MeshPart")
			body.Name = "Body"
			body.Size = Horn.MESH.SIZE_STUDS
			body.Parent = handle
			-- THE VOICE, WHICH MUST NOT BE CLONED UNDER THE CAMERA: the blast is the real Tool's, 3D,
			-- from the beater's own position. A second copy an inch from the ear is a second voice.
			local sound = Instance.new("Sound")
			sound.Name = "Blast"
			sound.Parent = handle
			handle.Parent = tool
			return tool, handle
		end

		-- THE DRAWN HORN IS SCALED AND THE REAL ONE IS NOT (task 211). KAREN, 2026-10-18: *"also horn
		-- is broken arm is wrong"*. The Director's decision on task 206's escalation (option B,
		-- 2026-10-19) is that the FIRST-PERSON CLONE shrinks so the glove -- which is not scaled with
		-- it -- comes nearer and draws bigger, while the horn every other player sees keeps the size
		-- Karen asked for. That is a claim about two objects, so it is measured on both: the clone
		-- under the camera carries `HORN.scale`, and the Tool's own Handle and its mesh are the size
		-- they were handed in. `viewmodel_poses.spec` holds the pose arithmetic; this is the only
		-- place the engine's own `ScaleTo` actually runs.
		it("scales the clone under the camera and never the Tool's own Handle", function()
			local tool, handle = hornTool()
			local body = handle:FindFirstChild("Body") :: BasePart
			local wasHandle, wasBody = handle.Size, body.Size
			local live = Camera.Viewmodel.getSource()
			Camera.Viewmodel.setSource(function()
				return handle
			end)
			local ok, err = pcall(function()
				Camera.Viewmodel.clear()
				task.wait(0.3)
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAtBlend(0), firstPersonConfig)
				local drawn = Camera.Viewmodel.current()
				expect(drawn).to.be.ok()
				expect((drawn :: Model).Name).to.equal("DrivenHuntHornViewmodel")
				local scale = (firstPersonConfig :: any).HORN.scale
				TestKit.note(
					string.format(
						"task211 the drawn horn is at scale %.4f (the file says %.4f); the Tool's"
							.. " Handle is still %.4f x %.4f x %.4f and its mesh %.4f long",
						(drawn :: Model):GetScale(),
						scale,
						handle.Size.X,
						handle.Size.Y,
						handle.Size.Z,
						body.Size.X
					)
				)
				expect(math.abs((drawn :: Model):GetScale() - scale) < 1e-4).to.equal(true)
				-- THE CLONE'S OWN PARTS ACTUALLY SHRANK, which is what `GetScale` is a record of and
				-- not a substitute for: the drawn body is the real one times the scale.
				local drawnBody = ((drawn :: Model).PrimaryPart :: BasePart):FindFirstChild("Body")
				expect(drawnBody).to.be.ok()
				expect(math.abs((drawnBody :: BasePart).Size.X - wasBody.X * scale) < 1e-3).to.equal(true)
				-- AND THE TOOL IS UNTOUCHED. The Handle the server welded to the character is what
				-- every other player sees, and a viewmodel that resized it would have shrunk the
				-- horn in the world -- which is the option the Director did NOT take.
				expect(handle.Size).to.equal(wasHandle)
				expect(body.Size).to.equal(wasBody)
			end)
			Camera.Viewmodel.setSource(live)
			Camera.Viewmodel.clear()
			tool:Destroy()
			if not ok then
				error(err, 0)
			end
		end)

		it("draws the horn in CAMERA space, so a 360 turn cannot leave it behind", function()
			local tool, handle = hornTool()
			local live = Camera.Viewmodel.getSource()
			Camera.Viewmodel.setSource(function()
				return handle
			end)
			local ok, err = pcall(function()
				Camera.Viewmodel.clear()
				-- THE SOURCE IS ASKED FOUR TIMES A SECOND, NOT EVERY FRAME (task 133's throttle), and
				-- `clear()` does not drop the cached Handle -- so an update called the instant after
				-- `setSource` still draws whatever was in the hand before. The hands case above waits
				-- for the same reason; without it this case measures the live gun.
				task.wait(0.3)
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAtBlend(0), firstPersonConfig)
				local made = Camera.Viewmodel.current()
				expect(made).to.be.ok()
				expect((made :: Model).Parent).to.equal(Workspace.CurrentCamera)
				-- IT IS A CLONE OF THE HANDLE AND ITS CHILDREN -- the same object the world shows --
				-- and it carries no `Sound`, no joint and no script.
				local clone = (made :: Model).PrimaryPart :: BasePart
				expect(clone).to.be.ok()
				expect(clone:FindFirstChild("Body")).to.be.ok()
				expect(clone:FindFirstChildOfClass("Sound")).to.equal(nil)
				for _, inside in ipairs((made :: Model):GetDescendants()) do
					expect(inside:IsA("LuaSourceContainer")).to.equal(false)
					expect(inside:IsA("JointInstance")).to.equal(false)
					if inside:IsA("BasePart") then
						expect(inside.Anchored).to.equal(true)
						-- The occlusion cast must not hit our own horn (the module header).
						expect(inside.CanQuery).to.equal(false)
						expect(inside.CanCollide).to.equal(false)
						-- `Camera.Rig` holds the SOURCE parts at 1 for the local player and `Clone()`
						-- copies the property: without this line the first-person horn is invisible
						-- exactly when it is the only one on screen.
						expect(inside.LocalTransparencyModifier).to.equal(0)
					end
				end

				-- THE CLAIM KAREN'S WORDS ASK FOR, AS A MEASUREMENT: the drawn horn's offset from the
				-- camera is the SAME CFrame whichever way the camera faces. Four very different
				-- cameras, including one upside down and one a thousand studs away.
				local offsets = {}
				for _, cam in ipairs({
					CFrame.new(0, 12, 0),
					CFrame.new(0, 12, 0) * CFrame.Angles(0, math.rad(90), 0),
					CFrame.new(0, 12, 0) * CFrame.Angles(0, math.rad(180), math.rad(35)),
					CFrame.new(900, 40, -1200) * CFrame.Angles(math.rad(-25), math.rad(270), 0),
				}) do
					Camera.Viewmodel.update(cam, stateAtBlend(0), firstPersonConfig)
					local drawn = (Camera.Viewmodel.current() :: Model):GetPivot()
					table.insert(offsets, cam:ToObjectSpace(drawn))
				end
				for index = 2, #offsets do
					local delta = (offsets[index].Position - offsets[1].Position).Magnitude
					expect(delta < 1e-3).to.equal(true)
					-- The rotation too: a horn that kept its place and turned in the hand would pass
					-- a position-only check.
					local turn = (offsets[index]:Inverse() * offsets[1])
					local axis, angle = turn:ToAxisAngle()
					expect(axis).to.be.ok()
					expect(math.abs(angle) < 1e-3).to.equal(true)
				end
				-- ...AND IT IS WHERE `poses.json` PUTS IT, through the one conversion site. The pose
				-- is read off the config the camera was handed, so a tuned number moves this claim
				-- with the horn rather than against it.
				local want = (firstPersonConfig :: any).HORN.carry.item
				expect((offsets[1].Position - want.Position).Magnitude < 1e-3).to.equal(true)

				-- ...AND A SWITCH BACK TO A GUN REBUILDS IT AS A GUN. `builtFrom` is a Handle identity
				-- and says nothing about what was MADE out of it, so without `builtKind` the next
				-- frame would pose a horn's clone with a gun's numbers -- or keep drawing the horn for
				-- a player who has just been handed a shotgun.
				--
				-- THIS CASE STATES ITS OWN PRECONDITION SINCE TASK 177, AND THE OLD ONE WAS LUCK.
				-- It used to swap the source, `task.wait(0.3)` and assert on the very next `update`,
				-- on the reasoning that 0.3 s clears the module's 0.25 s source throttle. It does not:
				-- `lastSourceCheck` is shared with the LIVE camera loop, which calls `update` every
				-- frame and resets it, so the wait guarantees nothing. The two-player run of task 177
				-- is where that came due -- `[harness2] FAIL 31/35 @ 4b3da2c`, BOTH clients, still
				-- drawing `DrivenHuntHornViewmodel` here -- and one player had been winning the race
				-- for eleven tasks. `Viewmodel.setSource` now drops the cached handle, so the next
				-- `update` from anybody re-asks; `drawnAfterSwap` asserts that rather than assuming it,
				-- and REPORTS how many updates it took, so a regression says so instead of flaking.
				--
				-- NOTHING HERE IS WEAKENED: `Viewmodel.clear()` is deliberately NOT called across the
				-- swap, so `builtKind` remains the ONLY thing that can turn the horn's model into the
				-- gun's -- which is exactly what this half of the case exists to prove.
				local function drawnAfterSwap(wanted: string): number
					for attempt = 1, 30 do
						Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAtBlend(0), firstPersonConfig)
						local drawnNow = Camera.Viewmodel.current()
						if drawnNow ~= nil and (drawnNow :: Model).Name == wanted then
							return attempt
						end
						task.wait(0.05)
					end
					local got = Camera.Viewmodel.current()
					expect(if got then (got :: Model).Name else "<nothing>").to.equal(wanted)
					return -1
				end

				local gunHandle = Instance.new("MeshPart")
				gunHandle.Name = "Handle"
				gunHandle.Size = Shotgun.CONFIG.HANDLE_SIZE
				gunHandle.Transparency = 1
				Camera.Viewmodel.setSource(function()
					return gunHandle
				end)
				local toGun = drawnAfterSwap("DrivenHuntViewmodel")
				local swapped = Camera.Viewmodel.current()
				expect(swapped).to.be.ok()
				expect((swapped :: Model).Name).to.equal("DrivenHuntViewmodel")
				expect(Camera.Viewmodel.hornMouthpiece()).to.equal(nil)
				gunHandle:Destroy()
				Camera.Viewmodel.setSource(function()
					return handle
				end)
				local toHorn = drawnAfterSwap("DrivenHuntHornViewmodel")
				expect((Camera.Viewmodel.current() :: Model).Name).to.equal("DrivenHuntHornViewmodel")
				-- ONE UPDATE EACH is what the dropped cache buys, and it is asserted rather than hoped
				-- for: anything more means the swap is back to waiting on the throttle.
				expect(toGun).to.equal(1)
				expect(toHorn).to.equal(1)
				TestKit.note(
					string.format(
						"camera_client: a source swap is drawn on update %d (to the gun) and %d (back to the horn)",
						toGun,
						toHorn
					)
				)

				-- THE RIGHT GLOVE IS ON IT, when the templates are there at all. The real ones are
				-- loaded on the server, so this is a note rather than a demand -- `handsMissing`
				-- counts the other case, and the gun's own case drives the injected templates.
				-- READ OFF THE MODEL THAT IS ON SCREEN NOW, not off `clone`: the swap above destroyed
				-- the first clone and built a third one, so the old reference is a destroyed part.
				local rebuilt = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				local hand = rebuilt:FindFirstChild("HandRight")
				TestKit.note(
					string.format("camera_client: the drawn horn has %s right glove", if hand then "its" else "NO")
				)
			end)
			Camera.Viewmodel.setSource(live)
			Camera.Viewmodel.clear()
			tool:Destroy()
			if not ok then
				error(err, 0)
			end
			expect(Camera.Viewmodel.getSource()).to.equal(live)
		end)

		it("goes to the mouth on an accepted blast, and comes back down", function()
			local tool, handle = hornTool()
			local live = Camera.Viewmodel.getSource()
			local liveClock = Camera.Viewmodel.getClock()
			-- THE VIEWMODEL'S OWN CLOCK, DRIVEN BY HAND (the seam task 111 added for exactly this):
			-- the gesture is 1.25 s of wall time, and a spec that waited for it would spend the
			-- suite's budget and still be racing the live camera's own frames.
			local now = 0
			Camera.Viewmodel.setClock(function()
				return now
			end)
			Camera.Viewmodel.setSource(function()
				return handle
			end)
			local ok, err = pcall(function()
				Camera.Viewmodel.clear()
				task.wait(0.3) -- the source throttle: see the case above
				local cam = CFrame.new(0, 12, 0)
				local function drawnOffset(): CFrame
					Camera.Viewmodel.update(cam, stateAtBlend(0), firstPersonConfig)
					return cam:ToObjectSpace((Camera.Viewmodel.current() :: Model):GetPivot())
				end
				local poses = (firstPersonConfig :: any).HORN
				-- CARRIED. The Tool carries no blast attribute at all, which is every horn that has
				-- never been blown.
				expect((drawnOffset().Position - poses.carry.item.Position).Magnitude < 1e-3).to.equal(true)

				-- A BLAST, AS THE SERVER PUBLISHES ONE: an increasing number on the Tool, stamped
				-- inside `Weapon.Horn.blowTool` -- the one door every accepted blast comes through, so
				-- a REFUSED one (the cooldown, or a beater through the line) never moves this and the
				-- horn never goes to a mouth that makes no sound.
				tool:SetAttribute(Horn.BLOW_ATTRIBUTE, 1)
				-- THE FRAME THAT NOTICES IS THE START OF THE GESTURE, NOT A FRAME INTO IT, and this
				-- is where that is asserted rather than assumed: the attribute replicates whenever it
				-- replicates, so the clock starts on the frame this client first sees it and the horn
				-- is still at the carry for that one frame. (Round zero of this case had the raise a
				-- frame early, measured here.)
				local startedAt = now
				expect((drawnOffset().Position - poses.carry.item.Position).Magnitude < 1e-3).to.equal(true)
				-- Half way up the raise: between the two poses and at neither of them.
				now = startedAt + Horn.BLOW_POSE.RAISE_SECONDS / 2
				local half = drawnOffset()
				expect((half.Position - poses.carry.item.Position).Magnitude > 0.05).to.equal(true)
				expect((half.Position - poses.blow.item.Position).Magnitude > 0.05).to.equal(true)
				-- AT THE MOUTH, and it stays there for the whole blast.
				now = startedAt + Horn.BLOW_POSE.RAISE_SECONDS
				expect((drawnOffset().Position - poses.blow.item.Position).Magnitude < 1e-3).to.equal(true)
				now = startedAt + Horn.CONFIG.BLOW_SECONDS - 0.01
				expect((drawnOffset().Position - poses.blow.item.Position).Magnitude < 1e-3).to.equal(true)
				-- ...AND IT COMES BACK DOWN. The gesture ends exactly `LOWER_SECONDS` after the blast
				-- does, which is task 168's own number and the server's own fade.
				now = startedAt + Horn.CONFIG.BLOW_SECONDS + Horn.BLOW_POSE.LOWER_SECONDS
				expect((drawnOffset().Position - poses.carry.item.Position).Magnitude < 1e-3).to.equal(true)
				-- A SECOND BLAST IS A SECOND NUMBER, and nothing else: the same attribute value
				-- written again is not a blast, which is what stops a replicated re-send raising the
				-- horn twice.
				tool:SetAttribute(Horn.BLOW_ATTRIBUTE, 1)
				now += 10
				expect((drawnOffset().Position - poses.carry.item.Position).Magnitude < 1e-3).to.equal(true)
				tool:SetAttribute(Horn.BLOW_ATTRIBUTE, 2)
				startedAt = now
				expect((drawnOffset().Position - poses.carry.item.Position).Magnitude < 1e-3).to.equal(true)
				now = startedAt + Horn.BLOW_POSE.RAISE_SECONDS
				expect((drawnOffset().Position - poses.blow.item.Position).Magnitude < 1e-3).to.equal(true)
				-- THE MOUTHPIECE IS WHAT REACHES THE MOUTH, and where it is on the object comes from
				-- `Horn.mouthpieceOffset` rather than from a number here. In the camera's frame it is
				-- below the eye and near the view's own vertical axis -- the bottom-centre of the
				-- frame, which is where a mouth is.
				local mouthpiece = Camera.Viewmodel.hornMouthpiece()
				expect(mouthpiece).to.be.ok()
				local local_ = cam:ToObjectSpace(mouthpiece :: CFrame)
				TestKit.note(
					string.format(
						"camera_client: the raised mouthpiece sits at (%.3f, %.3f, %.3f) in the camera's frame",
						local_.Position.X,
						local_.Position.Y,
						local_.Position.Z
					)
				)
				expect(local_.Position.Y < 0).to.equal(true)
				-- THE TARGET IS THE NOTE'S (section 4): within 0.15 studs of the view's own vertical
				-- axis -- the bottom-CENTRE of the frame, which is where a mouth is -- and below the
				-- eye. Both are properties of the pose data, so a tuning session that moved the horn
				-- off the mouth would fail here rather than ship a gesture nobody can read.
				expect(math.abs(local_.Position.X) <= 0.15).to.equal(true)
			end)
			Camera.Viewmodel.setSource(live)
			Camera.Viewmodel.setClock(liveClock)
			Camera.Viewmodel.clear()
			tool:Destroy()
			if not ok then
				error(err, 0)
			end
			expect(Camera.Viewmodel.getClock()).to.equal(liveClock)
		end)

		it("draws NOTHING for a Tool it does not name, which is task 152 kept", function()
			local tool = Instance.new("Tool")
			tool.Name = "CameraSpecProbeLantern"
			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Transparency = 1
			handle.Parent = tool
			local live = Camera.Viewmodel.getSource()
			Camera.Viewmodel.setSource(function()
				return handle
			end)
			local ok, err = pcall(function()
				Camera.Viewmodel.clear()
				task.wait(0.3) -- the source throttle: see the case above
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAtBlend(0), firstPersonConfig)
				-- The whole of task 152's fix: a non-weapon Tool that is not the horn draws no
				-- viewmodel, and `Camera.Rig` leaves the real one visible instead.
				expect(Camera.Viewmodel.current()).to.equal(nil)
				expect(HeldTool.kindOf(tool)).to.equal(nil)
			end)
			Camera.Viewmodel.setSource(live)
			Camera.Viewmodel.clear()
			tool:Destroy()
			if not ok then
				error(err, 0)
			end
		end)
	end)

	describe("what the reload should draw", function()
		it("counts the spent barrels from BEFORE the break, and the fresh from the chambers", function()
			-- ROUND 1'S DEFECT, AS A MEASUREMENT: the server's `Break` opens the gun AND empties both
			-- barrels in one reduction, so a replica that says "open" has already forgotten what was
			-- fired. Asking it counts nothing -- which is why no spent shell was ever drawn in the
			-- game, while the spec passed on a number it had made up itself.
			local fired = { open = false, barrels = { "Spent", "Live" }, loaded = { "None", "Buck" } }
			local opened = { open = true, barrels = { "Live", "Live" }, loaded = { "None", "None" } }
			local one = Camera.breakFrom(fired, opened)
			expect(one.open).to.equal(true)
			expect(one.spent).to.equal(1)
			expect(one.loaded[1]).to.equal(false)
			expect(one.loaded[2]).to.equal(false)
			-- TWO FIRED, TWO SHELLS.
			local bothFired = { open = false, barrels = { "Spent", "Spent" }, loaded = { "None", "None" } }
			expect(Camera.breakFrom(bothFired, opened).spent).to.equal(2)
			-- ...and each LOAD shows up as a chamber that now holds a shell.
			local half = { open = true, barrels = { "Live", "Live" }, loaded = { "Buck", "None" } }
			local fed = Camera.breakFrom(bothFired, half)
			expect(fed.loaded[1]).to.equal(true)
			expect(fed.loaded[2]).to.equal(false)
			-- A SHUT GUN DRAWS NOTHING, whatever it remembers.
			local shut = Camera.breakFrom(bothFired, { open = false, barrels = { "Live", "Live" } })
			expect(shut.open).to.equal(false)
			expect(shut.spent).to.equal(0)
			-- ...and no memory at all is a shut gun too, not a crash.
			expect(Camera.breakFrom(nil, opened).spent).to.equal(0)
			expect(Camera.breakFrom(nil, nil).open).to.equal(false)
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

		-- ...BUT NOT WHAT IS IN THE HAND AND IS NOT A GUN (task 152). "In first person the viewmodel
		-- IS the gun" is the sentence this module was written around, and it stopped being the whole
		-- truth the day the beater got a horn: a horn has no viewmodel, so hiding it would leave a
		-- beater holding nothing at all. MEASURED in the Forest Test, 2026-10-11, before the fix: the
		-- server said the character held the `Horn` and the first-person frame was a SHOTGUN.
		--
		-- The two halves are complements and this case drives BOTH against the same probe: the gun's
		-- part is hidden (the viewmodel draws it) and the horn's is not (nothing else will).
		it("leaves a non-weapon Tool visible, and still hides a gun's", function()
			local character = player.Character
			expect(character).to.be.ok()

			local function probeTool(name: string, weaponId: string?): (Tool, BasePart)
				local tool = Instance.new("Tool")
				tool.Name = name
				tool.RequiresHandle = false
				if weaponId then
					tool:SetAttribute("DrivenHunt.Weapon", weaponId)
				end
				local part = Instance.new("Part")
				part.Name = "Probe"
				part.Size = Vector3.new(0.2, 0.2, 0.2)
				part.Transparency = 1
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.CFrame = character:GetPivot()
				part.Parent = tool
				tool.Parent = character
				return tool, part
			end

			-- A horn is a Tool this camera must not hide; a gun is one it must.
			--
			-- THE GUN PROBE IS NOT NAMED "Shotgun", AND THAT IS NOT COSMETIC. `Weapon.Input.watchTool`
			-- adopts any Tool whose NAME is a weapon's, binds the four `DrivenHunt.Weapon.*` actions
			-- on its Equipped and unbinds on its Unequipped -- so the first version of this case put
			-- a second "Shotgun" in the LIVE character and destroyed it, which took the real
			-- player's trigger away for the rest of the session. It cost `zz_tie_to_a_tree` its shot
			-- in two `test2` runs. The game no longer unbinds for a Tool that is not the bound one
			-- (that was a real bug and is fixed at its owner), and this probe no longer impersonates
			-- a weapon the server grants: `Weapons.isWeaponTool` reads the ATTRIBUTE first, so the
			-- camera's question is asked exactly as before while `Weapons.isToolName` stays false.
			local horn, hornPart = probeTool("CameraSpecProbeHorn", nil)
			local gun, gunPart = probeTool("CameraSpecProbeGun", Weapons.PRIMARY)
			-- ...AND THE REAL HORN, WHICH CHANGED SIDES IN TASK 176. `CameraSpecProbeHorn` above is a
			-- Tool this camera draws nothing for and never will (task 152's refusal, kept); a Tool
			-- named exactly what `Weapon.Horn` builds is one it DOES draw now, so the real one must be
			-- hidden exactly as the gun's is. Both arms of the complement, in one case, against the
			-- one shared fact.
			local realHorn, realHornPart = probeTool(Horn.TOOL_NAME, nil)

			-- `DescendantAdded` is DEFERRED (the case above measured that), so the arrivals are given
			-- the same bounded wait and the flag is re-asserted on every pass for the same reason.
			local hornHidden, gunHidden, realHornHidden = false, false, false
			local deadline = os.clock() + 3
			while os.clock() < deadline do
				Camera.Rig.setLocalBodyHidden(true)
				hornHidden = hornPart.LocalTransparencyModifier == 1
				gunHidden = gunPart.LocalTransparencyModifier == 1
				realHornHidden = realHornPart.LocalTransparencyModifier == 1
				if gunHidden and realHornHidden then
					break
				end
				task.wait()
			end
			-- Read once more AFTER the gun is in the list: if the undrawn probe were being tracked it
			-- would have been written on the same pass.
			Camera.Rig.setLocalBodyHidden(true)
			hornHidden = hornPart.LocalTransparencyModifier == 1
			realHornHidden = realHornPart.LocalTransparencyModifier == 1
			local toolAbove = Camera.Rig.toolAbove(hornPart)
			horn:Destroy()
			gun:Destroy()
			realHorn:Destroy()
			Camera.Rig.setLocalBodyHidden(false)

			expect(toolAbove).to.be.ok()
			expect((toolAbove :: Tool).Name).to.equal("CameraSpecProbeHorn")
			-- A part of the BODY has no Tool above it, which is what stops this rule hiding nothing.
			expect(Camera.Rig.toolAbove(character:FindFirstChild("HumanoidRootPart"))).to.equal(nil)
			expect(gunHidden).to.equal(true)
			expect(hornHidden).to.equal(false)
			-- THE HORN IS HIDDEN NOW, which is the whole of task 176's change to this module: the
			-- viewmodel draws it in camera space, so the welded one on the body must not be on screen
			-- as well. The two probes differ by NAME alone, which is what makes this a test of the
			-- shared fact and not of two different shapes.
			expect(realHornHidden).to.equal(true)
			expect(HeldTool.drawsFirstPerson(realHorn)).to.equal(true)
			expect(HeldTool.drawsFirstPerson(horn)).to.equal(false)
		end)

		-- THE STOCK TransparencyController IS A SECOND WRITER AND IT CANNOT BE REMOVED (task 151
		-- round 3). `Rig.acquire` already warns that this PlayerModule will not turn its cameras
		-- off -- "this PlayerModule's GetCameras() has no Disable method" -- and
		-- `PlayerModule.CameraModule.TransparencyController` keeps running beside us, computing
		-- `LocalTransparencyModifier` from its OWN zoom distance rather than from where this camera
		-- actually put the eye. It decides the player is in third person and writes 0 over
		-- everything, every frame.
		--
		-- MEASURED in the Forest Test before the fix: 1 written on all 18 drawable parts of the
		-- local character, and TWO SECONDS LATER ONLY 2 WERE STILL 1. On screen that was the
		-- player's own right arm as a tan block in the bottom-right and, once task 151 gave
		-- everybody a cap, their own orange brim across the top of the view.
		--
		-- So hiding is re-asserted every frame, and this case is the one that would notice if that
		-- stopped: it hides, waits long enough for the other writer to have had many frames, and
		-- asks again WITHOUT hiding in between.
		it("keeps the body hidden against the stock TransparencyController, which writes every frame", function()
			-- GATED ON THE FLAG (review round 1, note). This case leans on the camera's own loop to
			-- re-assert, and that loop only hides the body unconditionally in first person: with
			-- `FIRST_PERSON` back at false -- the one-line rollback the flag exists for -- `hideBody`
			-- is `blend > BODY_HIDE_BLEND` and the step writes 0 once, so the case would fail for a
			-- reason that is not a defect.
			if not Config.FIRST_PERSON then
				TestKit.note(
					"task151 camera: FIRST_PERSON is off, so the body is hidden by blend and this case is skipped"
				)
				return
			end
			local character = player.Character
			expect(character).to.be.ok()

			local before = Camera.Rig.reassertions()
			Camera.Rig.setLocalBodyHidden(true)
			-- the camera's own loop is what re-asserts; this only waits for it to run
			task.wait(1.5)
			local stillHidden, total = 0, 0
			local visible = {}
			for _, part in ipairs((character :: Model):GetDescendants()) do
				-- EVERY PART OF THE BODY, AND NOT WHAT IS IN THE HAND THAT THE VIEW DOES NOT DRAW
				-- (task 152, widened in task 176). `Camera.Rig` leaves such a Tool visible ON
				-- PURPOSE -- it has no viewmodel, so hiding it would leave the player holding nothing
				-- at all -- and the exclusion here is the SAME shared fact the owner asks. A Tool the
				-- view DOES draw (a gun, and since task 176 the horn) must be hidden like the body,
				-- so it is counted with it rather than excluded.
				local tool = if part:IsA("BasePart") then Camera.Rig.toolAbove(part) else nil
				local carriedUndrawn = tool ~= nil and not HeldTool.drawsFirstPerson(tool)
				if part:IsA("BasePart") and not carriedUndrawn then
					total += 1
					if part.LocalTransparencyModifier == 1 then
						stillHidden += 1
					else
						table.insert(visible, part.Name)
					end
				end
			end
			local after = Camera.Rig.reassertions()
			Camera.Rig.setLocalBodyHidden(false)

			TestKit.note(
				string.format(
					"task151 camera: %d of %d local part(s) still hidden after 1.5 s; re-asserted %d frame(s)",
					stillHidden,
					total,
					after - before
				)
			)
			expect(total > 0).to.equal(true)
			if stillHidden ~= total then
				error(
					string.format(
						"%d of %d local part(s) came back visible while the body was hidden (%s): the stock "
							.. "TransparencyController won, and the player sees their own arm and cap",
						total - stillHidden,
						total,
						table.concat(visible, ", ")
					),
					0
				)
			end
			-- ...and the camera's own loop really did run over this window. THIS DOES NOT PROVE
			-- CONTENTION, and round 1's request said it did -- wrongly (the Reviewer's note):
			-- `Camera.step` calls `setLocalBodyHidden(true)` every frame in first person, so the
			-- counter rises whether or not anything overwrote the value. What proves contention is
			-- the pre-fix experiment recorded in `Rig`'s header -- 1 written on all 18 parts, only 2
			-- still 1 two seconds later. What bites here is the `20 of 20` above.
			expect(after > before).to.equal(true)
		end)

		-- A DRIVER holds no Tool at all (Match.CONFIG.DRIVERS_MAY_SHOOT is false), so the Handle is
		-- named as a case rather than promised: the claim is every part the character HAS.
		it("hides every part the character has, the Tool's Handle among them when it holds one", function()
			local character = player.Character
			expect(character).to.be.ok()

			Camera.Rig.setLocalBodyHidden(true)
			local visible, total, carried = {}, 0, 0
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") then
					-- ...EXCEPT WHAT IS IN THE HAND THAT THE VIEW DOES NOT DRAW (task 152, widened in
					-- task 176): see the case above. Counted rather than silently skipped, so what
					-- stays on screen by design is a number in the note and not an omission.
					local tool = Camera.Rig.toolAbove(part)
					if tool ~= nil and not HeldTool.drawsFirstPerson(tool) then
						carried += 1
					else
						total += 1
						if part.LocalTransparencyModifier ~= 1 then
							table.insert(visible, part:GetFullName())
						end
					end
				end
			end
			Camera.Rig.setLocalBodyHidden(false)
			if carried > 0 then
				TestKit.note(
					string.format(
						"camera_client: %d part(s) of a carried non-weapon Tool stay drawn, by design",
						carried
					)
				)
			end

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

	-- THE LIVE POSE OVERRIDE (task 98). The merge, every refusal and the view are proved on the
	-- server (tests/server/viewmodel_poses.spec.luau); what only a CLIENT can show is the half this
	-- whole task exists for -- that a number written into the attribute while the game RUNS reaches
	-- the gun that is actually drawn, with no commit and no rebuild.
	describe("the live pose override", function()
		it("moves the drawn gun, and is put back", function()
			local folder = ReplicatedStorage:WaitForChild("Viewmodel")
			local before = folder:GetAttribute("DHPose")
			-- ITS OWN GUN, WITH A SIGHT ON IT, for the reason every viewmodel case here builds one:
			-- the aimed pose is solved FROM the sight, so a gun that carries none falls back to the
			-- accepted framing and the number this case moves would change nothing. Measured: the
			-- first run of this case used the live handle and the gun moved 0.000 studs.
			local handle = Instance.new("MeshPart")
			handle.Name = "Handle"
			handle.Size = Shotgun.CONFIG.HANDLE_SIZE
			handle.Transparency = 1
			local sight = Instance.new("Attachment")
			sight.Name = "Sight"
			sight.CFrame = CFrame.new(0, 0.12, -2.0)
			sight.Parent = handle
			local live = Camera.Viewmodel.getSource()
			Camera.Viewmodel.setSource(function()
				return handle
			end)
			-- THE ATTRIBUTE IS SET LOCALLY, which is enough and is the honest test: a client write
			-- does not replicate, and the claim is that THIS client's camera reads it.
			-- `tools/pose.py` writes it on the server, where it reaches every client the same way.
			-- THE PATH CARRIES THE WEAPON SINCE TASK 140: `poses.json` is version 4 and every pose set
			-- lives under `weapons.<id>`, so a v3 path is refused whole -- which is the behaviour this
			-- case would otherwise mistake for "the override did not reach the camera".
			folder:SetAttribute("DHPose", '{"weapons.shotgun.aim.eyeReliefStuds": 9.5}')
			local ok, why = pcall(function()
				local resolved = Camera.Poses.config(firstPersonConfig)
				expect(resolved).never.to.equal(firstPersonConfig)
				expect(resolved.EYE_RELIEF_STUDS).to.equal(9.5)
				expect(resolved.FIRST_PERSON).to.equal(true)
				task.wait(0.3) -- the source is asked four times a second, not per frame
				Camera.Viewmodel.clear()
				Camera.Viewmodel.setReload(nil)
				-- NO YIELD from here on: the live render step re-poses the clone with the LIVE
				-- config every frame, so both measurements are taken inside one frame.
				local at = CFrame.new(0, 14, 0)
				Camera.Viewmodel.update(at, stateAtBlend(1), firstPersonConfig)
				local model = Camera.Viewmodel.current()
				expect(model).to.be.ok()
				local plain = ((model :: Model).PrimaryPart :: BasePart).CFrame
				Camera.Viewmodel.update(at, stateAtBlend(1), resolved)
				local moved = ((model :: Model).PrimaryPart :: BasePart).CFrame
				local distance = (moved.Position - plain.Position).Magnitude
				TestKit.note(
					string.format(
						"task98 live override moved the drawn gun %.3f studs (relief %.2f -> 9.50)",
						distance,
						firstPersonConfig.EYE_RELIEF_STUDS
					)
				)
				-- THE GUN SITS AS FAR BEHIND THE BEAD AS THE RELIEF SAYS, so the whole gun travels
				-- by the difference: 9.5 - 3.65 is 5.85 studs, and anything over a stud is the
				-- override having reached the drawn Instance rather than float noise.
				expect(distance > 1.0).to.equal(true)
			end)
			-- PUT BACK WHATEVER WAS THERE, on every path: an override left set would fail the next
			-- harness run's own guard, which is exactly the trap this case would otherwise lay.
			folder:SetAttribute("DHPose", before)
			Camera.Viewmodel.clear()
			Camera.Viewmodel.setSource(live)
			handle:Destroy()
			if not ok then
				error(why, 0)
			end
			expect(folder:GetAttribute("DHPose")).to.equal(before)
			-- AND THE OVERRIDE IS GONE FOR THE CAMERA TOO, not just for the attribute: the resolver
			-- caches on the attribute's own text, so this is what proves the cache follows it back.
			expect(Camera.Poses.config(firstPersonConfig)).to.equal(firstPersonConfig)
		end)

		-- THE HOLD IS RELEASED WHEN THE OVERRIDE GOES AWAY, which is the Reviewer's round-2 finding
		-- on task 140 as a test. `tools/pose.py clear` and `pose.py compare`'s own release path both
		-- clear by REMOVING the attribute, so the next frame reads nil -- and a `Poses.config` that
		-- answered the base config before writing its cache left `cachedHold` holding the last
		-- override's pose. `Camera.update` applies `Poses.holdState` every frame, so the camera and
		-- the drawn gun stayed pinned at `mode = "Aiming"`, `blend = 1` for the rest of the session.
		it("releases a held pose when the attribute is removed, not just when it changes", function()
			local folder = ReplicatedStorage:WaitForChild("Viewmodel")
			local before = folder:GetAttribute("DHPose")
			local ok, why = pcall(function()
				folder:SetAttribute("DHPose", '{"hold": "aim"}')
				expect(Camera.Poses.config(firstPersonConfig)).never.to.equal(firstPersonConfig)
				expect(Camera.Poses.hold()).to.equal("aim")
				-- REMOVED, not set to another pose: this is the shape `tools/pose.py` writes.
				folder:SetAttribute("DHPose", nil)
				expect(folder:GetAttribute("DHPose")).to.equal(nil)
				expect(Camera.Poses.config(firstPersonConfig)).to.equal(firstPersonConfig)
				expect(Camera.Poses.hold()).to.equal(nil)
				-- ...and the state it would have forced is the state it is handed.
				local rest = stateAtBlend(0)
				expect(Camera.Poses.holdState(rest, Camera.Poses.hold())).to.equal(rest)
			end)
			folder:SetAttribute("DHPose", before)
			-- The cache follows the attribute back, which the case above already proves; this only
			-- leaves the session as it found it.
			Camera.Poses.config(firstPersonConfig)
			if not ok then
				error(why, 0)
			end
		end)
	end)

	-- THE STUDIO-ONLY HELD LOOK (task 263). `Camera.TestLook` is the one reader of `DHTestLook`, and
	-- the half that matters for the game is the one that can NEVER run here: inside a Studio session
	-- `RunService:IsStudio()` is always true, so the production branch is only reachable by parameter.
	-- That is why `TestLook.point` takes the gate as an argument -- `Economy.testGrantFor`'s own reason,
	-- quoted in that file.
	describe("the Studio-only held look", function()
		it("answers the point in Studio and NOTHING outside it", function()
			local TestLook = Camera.TestLook
			expect(TestLook.point(true, "10,20,30", nil)).to.equal(Vector3.new(10, 20, 30))
			-- THE PRODUCTION BRANCH, and the whole safety of the feature: a live server reads nothing,
			-- however the attribute got there.
			expect(TestLook.point(false, "10,20,30", nil)).to.equal(nil)
		end)

		it("is released by DHTestLookOff, and `off` wins over a point that is still set", function()
			local TestLook = Camera.TestLook
			expect(TestLook.point(true, "1,2,3", true)).to.equal(nil)
			-- ...and only the boolean true releases: a stale string or a 1 left by a tool that wrote the
			-- wrong type must not quietly hand the view back half way through a measurement.
			expect(TestLook.point(true, "1,2,3", "true")).to.equal(Vector3.new(1, 2, 3))
			expect(TestLook.point(true, "1,2,3", false)).to.equal(Vector3.new(1, 2, 3))
		end)

		it("refuses anything that is not three finite numbers, and never throws", function()
			local TestLook = Camera.TestLook
			for _, bad in ipairs({ "1,2", "1,2,3,4", "a,2,3", "", "1,2,nan", "1,2,inf" }) do
				expect(TestLook.point(true, bad, nil)).to.equal(nil)
			end
			expect(TestLook.point(true, nil, nil)).to.equal(nil)
			expect(TestLook.point(true, Vector3.new(1, 2, 3), nil)).to.equal(nil)
		end)

		it("moves the REAL camera, holds it there, and gives it back", function()
			-- THE OWNER'S OWN COUNTER IS THE HANDSHAKE (task 263): `DHTestLook` is level-triggered and
			-- the camera never writes it back, so "did it steer" cannot be read off the attribute. It is
			-- read off `stats.testLookFrames`, which only `Camera.update` increments.
			-- A ROOT IS WHAT THE HOLD TURNS ABOUT: `Mode.anglesToward` takes the body's CFrame, and
			-- `Camera.update` skips the hold entirely while there is none. Waited for, never read.
			local character = player.Character or player.CharacterAdded:Wait()
			character:WaitForChild("HumanoidRootPart", 10)
			local before = Workspace.CurrentCamera.CFrame
			-- 60 studs off to the LEFT at eye height: any honest hold has to swing the view a long way,
			-- so "it was already pointing there" cannot pass this.
			local point = before.Position - before.RightVector * 60 + before.LookVector * 5
			local framesBefore = Camera.stats().testLookFrames
			-- THE WHOLE CASE IS INSIDE A pcall AND THE RELEASE IS OUTSIDE IT (task 264 item 5, from
			-- task 263's review note 263a(a)). This case WRITES THE REAL CAMERA'S OVERRIDE, and
			-- `DHTestLook` is level-triggered: an assert that throws in the first half -- the four
			-- `expect`s between the write and the release -- would leave the attribute set, and
			-- `Camera.update` would go on holding the live view 85 degrees off its own target for
			-- every case that runs after it in this session. That is task 252's cascade: one red
			-- line, then a file of casualties that look like defects of their own. The `DHPose` case
			-- twenty-five lines above is the pattern -- write, `pcall`, restore on BOTH paths,
			-- `error(why, 0)` so the original message is what the runner reports.
			player:SetAttribute("DHTestLookOff", nil)
			player:SetAttribute("DHTestLook", string.format("%f,%f,%f", point.X, point.Y, point.Z))
			local ok, why = pcall(function()
				for _ = 1, 12 do
					RunService.RenderStepped:Wait()
				end
				local steered = Camera.stats().testLookFrames - framesBefore
				local after = Workspace.CurrentCamera.CFrame
				-- HELD, not snapped once: a one-shot would steer exactly one of those twelve frames.
				expect(steered >= 8).to.equal(true)
				-- THE ATTRIBUTE IS STILL THERE. The old `DHLookAt` cleared it as its handshake, which is
				-- the write that breaks the server path (`<runs-dir>/263-camlook-server.luau`).
				expect(player:GetAttribute("DHTestLook")).to.be.ok()
				local toTarget = point - after.Position
				expect(toTarget.Magnitude > 1e-3).to.equal(true)
				expect(after.LookVector:Dot(toTarget.Unit) >= Config.LOOK_AT_LANDED_DOT).to.equal(true)
				expect(after.LookVector:Dot(before.LookVector) < 0.9).to.equal(true)

				-- ...AND IT GIVES THE VIEW BACK. `DHTestLookOff` releases without deleting the point,
				-- which is what lets an instrument hand control to Karen and still say where it had been
				-- aiming. It stays INSIDE the pcall because the release is what the second half asserts;
				-- the restore below is unconditional and is a different thing.
				player:SetAttribute("DHTestLookOff", true)
				for _ = 1, 4 do
					RunService.RenderStepped:Wait()
				end
				local held = Camera.stats().testLookFrames
				for _ = 1, 6 do
					RunService.RenderStepped:Wait()
				end
				expect(Camera.stats().testLookFrames).to.equal(held)
			end)
			-- BOTH PATHS, and `DHTestLookOff` first: while the point is still set, removing only the
			-- release would hand the view straight back to the hold for a frame.
			player:SetAttribute("DHTestLookOff", true)
			player:SetAttribute("DHTestLook", nil)
			player:SetAttribute("DHTestLookOff", nil)
			if not ok then
				error(why, 0)
			end
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
