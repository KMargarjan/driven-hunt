--!strict
-- MODEL B, the first-person gun, in a real client (task 105), and the gloves that hold it.
--
-- WHY IT IS ITS OWN FILE: `camera_client.spec.luau` grew past what StudioMCP will return in one
-- reply. MEASURED -- the harness refused the run with "Studio's answer for
-- ReplicatedStorage.ClientTests.camera_client.spec was truncated at 100015 chars: one instance is
-- too big for a single StudioMCP result" -- and that is a real bound on how big any one synced
-- instance may be, not a thing to work around. The claims are unchanged; they live here.
--
-- ONE GUN SINCE TASK 114: Karen accepted model B, so the gun flag retired and this is just
-- the gun. `FIRST_PERSON` is still a flag and is still driven by parameter here, the rule every
-- flagged path in this repo follows (docs/design/feature-flags.md 13.3). The GEOMETRY is proved on
-- the server (tests/server/gun.spec.luau); what only a client can show is that the gun is really
-- built, really under the camera, and that its barrel group really turns about the model's own
-- knuckle.
--
-- Note: docs/research/2026-10-01-exact-metal-gun.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Camera = require(scripts:WaitForChild("Camera"))
local Config = Camera.Config
local HandAssets = require(ReplicatedStorage:WaitForChild("HandAssets"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local ViewmodelData = require(ReplicatedStorage:WaitForChild("Viewmodel"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

-- THE ON BRANCH BY PARAMETER, exactly as `camera_client.spec` builds it: nothing is flipped and
-- nothing has to be restored.
local firstPersonConfig = table.clone(Config) :: any
firstPersonConfig.FIRST_PERSON = true
table.freeze(firstPersonConfig)

local function stateAtBlend(blend: number)
	local state = table.clone(Camera.Mode.initial(Config)) :: any
	state.mode = if blend > 0 then "Aiming" else "Third"
	state.blend = blend
	return table.freeze(state)
end

return function()
	-- MODEL B (task 105), AND SINCE TASK 114 THE ONLY GUN: Karen accepted it, so the gun flag retired
	-- and there is no second build path left to drive by parameter. The GEOMETRY is proved on
	-- the server (tests/server/gun.spec.luau); what only a client can show is that it is really built,
	-- really under the camera, and that its barrel group really turns about the model's own knuckle.
	--
	-- NOT ONE OF THESE CASES READS A DRAWN TUBE ANY MORE, and that is the point of the task: the gun
	-- is two MeshParts of somebody else's model, so there is no `BarrelLeft` to measure a flash
	-- against. Every claim is measured against the gun's OWN arithmetic (`Gun.barrelOffset`,
	-- `Gun.chamber`, `Gun.hinge`) on the instances that are really on screen -- which is the harder
	-- test, because the arithmetic is what the mesh has to agree with.
	describe("the gun", function()
		local Gun = require(ReplicatedStorage:WaitForChild("Gun"))

		-- Its own handle, so this never depends on what the live player happens to be holding, and
		-- the live source is always put back.
		local function withNewGun(body)
			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Size = Shotgun.CONFIG.HANDLE_SIZE
			handle.Transparency = 1
			local live = Camera.Viewmodel.getSource()
			Camera.Viewmodel.setSource(function()
				return handle
			end)
			task.wait(0.3) -- the source is asked four times a second, not per frame
			Camera.Viewmodel.clear()
			local ok, why = pcall(body)
			Camera.Viewmodel.setReload(nil)
			-- AND THE CLOCK, for the same reason the source and the reload are put back: a case that
			-- drives the load on the seam (`setClock`, task 111) and then fails would otherwise leave
			-- every later frame of this session reading a clock that does not move.
			Camera.Viewmodel.setClock(nil)
			Camera.Viewmodel.clear()
			Camera.Viewmodel.setSource(live)
			handle:Destroy()
			if not ok then
				error(why, 0)
			end
		end

		-- WHERE A FRESH SHELL COMES FROM, AND WHEN (task 111, and the only answer since task 114).
		-- Karen, watching the first version: "either we have 2 animation when shells go inside or one
		-- go straight another from hand" -- so a shell exists ONLY once the left hand has fetched it
		-- and carried it in, and before the fetch is over there is nothing on screen at all. The
		-- RETIRED gun's shells slid themselves into the chamber the instant the replica said "loaded",
		-- which is what the two cases below used to read while the flag was off.
		--
		-- SO THE LOAD IS DRIVEN ON THE VIEWMODEL'S OWN CLOCK SEAM, forward past the whole
		-- fetch-carry-seat, which is the state they measure: the shell seated in the bore, still.
		-- `withNewGun` puts the live clock back whatever happens.
		local function withSeatedShells(at: CFrame, state, spent: number, loaded: { boolean })
			local load = firstPersonConfig.SHELL_LOAD
			local fake = 4000.0
			Camera.Viewmodel.setClock(function()
				return fake
			end)
			Camera.Viewmodel.setReload({ open = true, spent = spent, loaded = loaded })
			fake += load.fetchSeconds + load.carrySeconds + load.seatSeconds + 0.05
			Camera.Viewmodel.update(at, state, firstPersonConfig)
		end

		-- KAREN, 2026-10-02, PLAYING: "hands are bad / left hand is oposit180deg need to turn or not
		-- sure but broken" and "one arm holds pipes and another stock right ?". THIS CASE IS THAT
		-- QUESTION, asked of the instances that are really drawn: one hand on the barrels, the other
		-- on the stock, neither above the rib, and both arms running back toward the shoulder.
		--
		-- IT STANDS IN ITS OWN GLOVES rather than waiting for the published pair, because the
		-- published pair arrives seconds after boot through `InsertService` and this must say the
		-- same thing on a run that got there first. The alignment is applied to whatever is drawn, so
		-- a stub answers it exactly: the measurement is of the POSE, through `Viewmodel.align`.
		it("holds the gun like a hunter: barrels in the left, stock in the right", function()
			-- A BOX PER GLOVE, not one box twice (round 1, finding 3): the published left glove's box
			-- is its own diagonal (0.629, 0.534, 0.669) and the right's is (0.669, 0.350, 0.211), and
			-- with both stubs shaped like the right one the left branch of the sleeve arithmetic was
			-- never really measured. These are `Assets.byKey(...).sizeStuds` to three places.
			local boxes = {
				[HandAssets.RIGHT] = Vector3.new(0.669, 0.350, 0.211),
				[HandAssets.LEFT] = Vector3.new(0.629, 0.534, 0.669),
			}
			local stubs: { [string]: BasePart } = {}
			for name, box in pairs(boxes) do
				local stub = Instance.new("Part")
				stub.Name = name
				stub.Size = box
				stubs[name] = stub
			end
			local live = Camera.Viewmodel.getSource()
			local liveHands = Camera.Viewmodel.getHandTemplates()
			Camera.Viewmodel.setHandTemplates(function(name)
				return stubs[name]
			end)
			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Size = Shotgun.CONFIG.HANDLE_SIZE
			handle.Transparency = 1
			Camera.Viewmodel.setSource(function()
				return handle
			end)
			local ok, why = pcall(function()
				task.wait(0.3)
				Camera.Viewmodel.clear()
				Camera.Viewmodel.setReload(nil)
				local state = stateAtBlend(0)
				Camera.Viewmodel.update(CFrame.new(0, 16, 0), state, firstPersonConfig)
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				local layout = Gun.layout(Shotgun.CONFIG)
				local found = 0
				for _, drawn in ipairs(clone:GetDescendants()) do
					local isHand = drawn.Name == HandAssets.RIGHT or drawn.Name == HandAssets.LEFT
					if isHand and drawn:IsA("BasePart") then
						found += 1
						local at = clone.CFrame:ToObjectSpace(drawn.CFrame)
						TestKit.note(
							string.format("task108 %s at z %.2f, y %.2f", drawn.Name, at.Position.Z, at.Position.Y)
						)
						if drawn.Name == HandAssets.LEFT then
							-- ON THE PIPES: between the muzzle and the breech, which is the barrel
							-- group's own span, and UNDER them -- Karen sees the rib in the aimed
							-- view, and a glove over it is the sight picture gone.
							expect(at.Position.Z > layout.muzzleZ).to.equal(true)
							expect(at.Position.Z < layout.breechZ).to.equal(true)
							expect(at.Position.Y < layout.barrelY - layout.barrelRadius).to.equal(true)
						else
							-- ON THE STOCK: behind the breech, where the wrist of the stock is, and
							-- below the bore line.
							expect(at.Position.Z > layout.breechZ).to.equal(true)
							expect(at.Position.Z < layout.half).to.equal(true)
							expect(at.Position.Y < layout.barrelY).to.equal(true)
						end
						-- THE GLOVE IS REALLY TURNED BY `Viewmodel.align` (round 1, finding 2). Every
						-- other assertion here reads a POSITION, and `align` is a pure rotation about
						-- the hand's own centre, so deleting it would not move one of them. THIS is
						-- the orientation: each glove's own measured `fingers` vector, carried
						-- through the CFrame of the part that is really drawn, has to land on the
						-- pose frame's +X, and its palm on +Y. That is the convention the three pose
						-- angles are read in, and without the alignment the right glove's fingers
						-- land on -X and the left's nowhere near either.
						local side = if drawn.Name == HandAssets.LEFT then "left" else "right"
						local base = clone.CFrame * Camera.Mode.handOffsetAt(side, state, firstPersonConfig)
						local axes = HandAssets.AXES[drawn.Name]
						local fingers = (drawn :: BasePart).CFrame:VectorToWorldSpace(axes.fingers.Unit)
						local palm = (drawn :: BasePart).CFrame:VectorToWorldSpace(axes.palm.Unit)
						TestKit.note(
							string.format(
								"task108 %s fingers.X %.3f, palm.Y %.3f (1.0 is the convention)",
								drawn.Name,
								base.RightVector:Dot(fingers),
								base.UpVector:Dot(palm)
							)
						)
						expect(base.RightVector:Dot(fingers) > 0.999).to.equal(true)
						-- The palm is SQUARED against the fingers inside `align` (the measured pair is
						-- not orthogonal: a hand is not a perfect slab), so it lands near +Y, not on
						-- it. 0.85 is far outside that correction and far inside any other axis.
						expect(base.UpVector:Dot(palm) > 0.85).to.equal(true)

						-- NO SLEEVE AT ALL, AND NOTHING LEFT THAT COULD DRAW ONE (tasks 111 and 114).
						-- Karen, 2026-10-02: "you can remove those arm extentions from both hands".
						-- Task 111 made `sleeveSegments` answer an empty list for model B while the
						-- retired gun -- the one whose glove had the open cuff they were built for --
						-- kept its own; task 114 retired that gun, so the segments, the taper and
						-- the to-the-shoulder vectors are gone. This asserts it on the parts that
						-- are really drawn, which is the only place a leftover would show.
						local segments = 0
						for _, sleeve in ipairs(drawn:GetChildren()) do
							if sleeve.Name == "Sleeve" and sleeve:IsA("BasePart") then
								segments += 1
							end
						end
						expect(segments).to.equal(0)
					end
				end
				expect(found).to.equal(2)
			end)
			Camera.Viewmodel.clear()
			Camera.Viewmodel.setHandTemplates(liveHands)
			Camera.Viewmodel.setSource(live)
			handle:Destroy()
			for _, stub in pairs(stubs) do
				stub:Destroy()
			end
			if not ok then
				error(why, 0)
			end
		end)

		-- KAREN, 2026-10-02: "can we make that i push ammo inside pipes? just moving hand", and then
		-- "the left loads shell". THE SHELL AND THE HAND ARE PLACED FROM THE SAME TWO NUMBERS --
		-- `loadedAt[barrel]` and `SHELL_FEED_SECONDS` -- so "the shell travels with the hand" is a
		-- claim about a distance between two drawn parts, which is what this measures.
		it("loads with the LEFT hand: the shell travels with it, and the hand goes back", function()
			local boxes = {
				[HandAssets.RIGHT] = Vector3.new(0.669, 0.350, 0.211),
				[HandAssets.LEFT] = Vector3.new(0.629, 0.534, 0.669),
			}
			local stubs: { [string]: BasePart } = {}
			for name, box in pairs(boxes) do
				local stub = Instance.new("Part")
				stub.Name = name
				stub.Size = box
				stubs[name] = stub
			end
			local live = Camera.Viewmodel.getSource()
			local liveHands = Camera.Viewmodel.getHandTemplates()
			Camera.Viewmodel.setHandTemplates(function(name)
				return stubs[name]
			end)
			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Size = Shotgun.CONFIG.HANDLE_SIZE
			handle.Transparency = 1
			Camera.Viewmodel.setSource(function()
				return handle
			end)
			local at = CFrame.new(0, 16, 0)
			local ok, why = pcall(function()
				task.wait(0.3)
				Camera.Viewmodel.clear()
				local state = stateAtBlend(0)
				-- ON ITS OWN CLOCK, which is round 1's finding (the case passed with the feature
				-- deleted). Two things made that possible: the player's camera loop clears the reload
				-- state on every frame it draws, so a spec that WAITS loses it, and a spec that does
				-- not wait only ever sees weight 0. With `Viewmodel.setClock` the whole motion is
				-- driven synchronously, at times this case chooses, and what is read is the DRAWN
				-- left hand.
				local fake = 1000.0
				Camera.Viewmodel.setClock(function()
					return fake
				end)
				Camera.Viewmodel.setReload({ open = true, spent = 2, loaded = { true, false } })
				local load = firstPersonConfig.SHELL_LOAD
				local function drawAt(when: number)
					fake = 1000.0 + when
					Camera.Viewmodel.update(at, state, firstPersonConfig)
				end
				drawAt(0)
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				local function leftHand(): BasePart
					for _, found in ipairs(clone:GetDescendants()) do
						if found.Name == HandAssets.LEFT and found:IsA("BasePart") then
							return found :: BasePart
						end
					end
					error("no left hand was drawn", 0)
				end
				local rest = (clone.CFrame * Camera.Mode.handOffsetAt("left", state, firstPersonConfig)).Position

				-- AT THE FETCH POINT: the hand has LEFT the barrels and gone back toward the hunter,
				-- which is Karen's "arm go up towards hunter" and the thing round 1 did not do.
				drawAt(load.fetchSeconds)
				local atFetch = leftHand().Position
				-- ...and it is where the loading keyframe says, not approximately: the alignment is a
				-- pure rotation about the glove's own centre, so the POSITION is the keyframe's.
				local weight, frame = Camera.Viewmodel.loadingAt(firstPersonConfig, fake)
				-- > 0.99 rather than == 1: `fake` is a float sum, so `since` lands a part in 1e12
				-- short of the segment's own length and the ramp has not quite closed.
				expect(weight > 0.99).to.equal(true)
				local wanted = clone.CFrame * (frame :: CFrame)
				TestKit.note(
					string.format("task111 fetch: hand %.3f studs from Karen's rest pose", (atFetch - rest).Magnitude)
				)
				expect((atFetch - rest).Magnitude > 0.3).to.equal(true)
				expect((atFetch - wanted.Position).Magnitude < 1e-3).to.equal(true)

				-- CARRYING: the shell is in the hand, so the drawn shell is a fixed short distance
				-- from the drawn glove and nowhere near its chamber.
				drawAt(load.fetchSeconds + load.carrySeconds / 2)
				local fresh = clone:FindFirstChild("FreshShell1")
				expect(fresh).to.be.ok()
				local shellAt = (fresh :: Model):GetPivot().Position
				local gap = (shellAt - leftHand().Position).Magnitude
				local mouth = (clone.CFrame * Camera.Viewmodel.shellFeedAt(1, 1, firstPersonConfig)).Position
				TestKit.note(
					string.format(
						"task111 carrying: shell %.3f from the hand, %.3f from its chamber",
						gap,
						(shellAt - mouth).Magnitude
					)
				)
				expect(gap < 0.35).to.equal(true)
				expect((shellAt - mouth).Magnitude > 0.2).to.equal(true)

				-- SEATED: the hand has put it in, and the shell is at the chamber mouth again.
				drawAt(load.fetchSeconds + load.carrySeconds + load.seatSeconds)
				local seatedShell = ((clone:FindFirstChild("FreshShell1") :: Model):GetPivot()).Position
				TestKit.note(
					string.format(
						"task111 seated: shell %.3f studs from the chamber mouth",
						(seatedShell - mouth).Magnitude
					)
				)
				expect((seatedShell - mouth).Magnitude < 0.25).to.equal(true)

				-- AND BACK: after the return the hand is bit-for-bit Karen's own tuned pose again.
				drawAt(load.fetchSeconds + load.carrySeconds + load.seatSeconds + load.returnSeconds + 0.01)
				expect(Camera.Viewmodel.loading(firstPersonConfig)).to.equal(0)
				expect((leftHand().Position - rest).Magnitude < 1e-3).to.equal(true)

				-- THE RIGHT HAND NEVER LEFT THE GRIP through any of it.
				local right = clone:FindFirstChild(HandAssets.RIGHT) :: BasePart
				local grip = (clone.CFrame * Camera.Mode.handOffsetAt("right", state, firstPersonConfig)).Position
				expect((right.Position - grip).Magnitude < 1e-3).to.equal(true)

				-- AND THERE IS ONLY EVER ONE ANIMATION PER SHELL. Karen, live: "either we have 2
				-- animation when shells go inside or one go straight another from hand" -- the old
				-- automatic feed was still sliding each shell into its chamber by itself while the
				-- hand carried another. So at EVERY step of the loading, a barrel's fresh shell is
				-- in one of three states and never a fourth: not drawn at all (the hand has not
				-- picked it up), exactly where the hand is, or exactly at the chamber mouth.
				local whole = load.fetchSeconds + load.carrySeconds + load.seatSeconds
				local steps = 0
				-- The steps sit BETWEEN the boundaries on purpose: `fake` is a float sum, so a step
				-- that lands exactly on `fetchSeconds` can read either side of it -- which is how
				-- this case first failed, asking for a shell the hand had not quite picked up.
				for index = 0, 12 do
					local stepAt = (whole + load.returnSeconds) * (index + 0.5) / 13
					drawAt(stepAt)
					steps += 1
					local shell = clone:FindFirstChild("FreshShell1")
					local carriedWeight, _, carriedBarrel, carriedShell =
						Camera.Viewmodel.loadingAt(firstPersonConfig, fake)
					if stepAt < load.fetchSeconds then
						expect(shell).to.equal(nil)
					else
						expect(shell).to.be.ok()
						local where = ((shell :: Model):GetPivot()).Position
						local inHand = carriedBarrel == 1 and carriedShell ~= nil
						local wantedAt = if inHand
							then (clone.CFrame * (carriedShell :: CFrame)).Position
							else (clone.CFrame * Camera.Viewmodel.shellFeedAt(1, 1, firstPersonConfig)).Position
						expect((where - wantedAt).Magnitude < 1e-3).to.equal(true)
					end
					expect(carriedWeight >= 0).to.equal(true)
				end
				TestKit.note(
					string.format("task111 checked %d steps of the load; no shell ever slid in by itself", steps)
				)
			end)
			Camera.Viewmodel.setReload(nil)
			Camera.Viewmodel.setClock(nil)
			Camera.Viewmodel.clear()
			Camera.Viewmodel.setHandTemplates(liveHands)
			Camera.Viewmodel.setSource(live)
			handle:Destroy()
			for _, stub in pairs(stubs) do
				stub:Destroy()
			end
			if not ok then
				error(why, 0)
			end
		end)

		-- KAREN'S ORDER, 2026-10-02: finish the weapon before the animal, and shooting is next.
		-- THREE THINGS A SHOT DOES, measured where they are: the kick is the new gun's own numbers,
		-- the flash and the smoke come out of the PIPE THAT FIRED on the drawn gun, and the sounds
		-- are asked for once each.
		it("fires: its own kick, a flash on the fired barrel, and a noise", function()
			-- THE NOISE IS ASKED FOR, which is all a spec can hear: `Weapon.Sound` counts every
			-- request, so "the shot plays a sound" is a number even with the id still empty.
			-- THE NOISE, BY WHAT CAME BACK (round 1, finding 4: a counter that counted the test's own
			-- calls proved nothing). `play` answers TRUE only when an id really reached a `Sound`, so
			-- these three say: the clicks have ids and the shot does not yet.
			local Sound = require(scripts:WaitForChild("Weapon")).Sound
			Sound.resetStats()
			-- The shot has an id now (Audioscape's, Director 2026-10-02), so this is TRUE: an id
			-- really reached a `Sound`. Nobody here has heard it.
			expect(Sound.shot(firstPersonConfig)).to.equal(true)
			expect(Sound.open(firstPersonConfig)).to.equal(true)
			expect(Sound.close(firstPersonConfig)).to.equal(true)
			-- ...AND A CALLER WITH NO RESOLVED CONFIG PLAYS NOTHING AND IS NOT COUNTED. The gun-flag
			-- check that used to stand here retired with the gun it kept sounds off (task 114);
			-- what is left is the honest one, because the three volumes are `fire.volume` in
			-- `poses.json` and a caller without the config has no volumes either.
			expect(Sound.open(nil)).to.equal(false)
			expect(Sound.close(nil)).to.equal(false)
			expect(Sound.stats().open).to.equal(1)
			-- THE EDGE IS WHERE THE ONLY LOGIC IS, and it is pure now, so a spec can drive the whole
			-- cycle: shut -> open is one click, open -> open is none, open -> shut is the other.
			expect(Camera.breakSound(false, true)).to.equal("open")
			expect(Camera.breakSound(true, true)).to.equal(nil)
			expect(Camera.breakSound(true, false)).to.equal("close")
			expect(Camera.breakSound(false, false)).to.equal(nil)
			-- ...and the volumes come from the pose data, so they are tunable live.
			expect(firstPersonConfig.FIRE.volume.shot > 0).to.equal(true)
			-- THE KICK IS THE DATA'S, which is what makes it tunable live. It was `newGun.fire`
			-- against a top-level block while there were two guns (task 112); task 114 moved it up,
			-- byte-identical, so the one thing left to assert is that the spring the camera reads IS
			-- the file's and not a literal that came back.
			expect(firstPersonConfig.RECOIL_GUN_PITCH_DEG).to.equal(ViewmodelData.DATA.fire.gunPitchDeg)
			expect(firstPersonConfig.RECOIL_GUN_PITCH_DEG > 0).to.equal(true)
			expect(firstPersonConfig.FIRE).to.equal(ViewmodelData.DATA.fire)
			TestKit.note(string.format("task114 kick: %.2f deg", firstPersonConfig.RECOIL_GUN_PITCH_DEG))

			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Size = Shotgun.CONFIG.HANDLE_SIZE
			handle.Transparency = 1
			local live = Camera.Viewmodel.getSource()
			Camera.Viewmodel.setSource(function()
				return handle
			end)
			local ok, why = pcall(function()
				task.wait(0.3)
				Camera.Viewmodel.clear()
				Camera.Viewmodel.setReload(nil)
				Camera.Viewmodel.update(CFrame.new(0, 16, 0), stateAtBlend(0), firstPersonConfig)
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				-- ONE FLASH PER BARREL, AT THAT BARREL'S OWN MUZZLE. The two bores are 0.078 studs
				-- apart, so "it came out of the pipe that fired" is a measurement and not a shrug.
				for barrel = 1, 2 do
					for _, old in ipairs(clone:GetChildren()) do
						if old.Name == "MuzzleFlash" then
							old:Destroy()
						end
					end
					expect(Camera.Viewmodel.flash(barrel, firstPersonConfig)).to.equal(true)
					local lit = clone:FindFirstChild("MuzzleFlash") :: BasePart
					expect(lit).to.be.ok()
					expect(lit:FindFirstChildOfClass("PointLight")).to.be.ok()
					local emitters = 0
					for _, child in ipairs(lit:GetChildren()) do
						if child:IsA("ParticleEmitter") then
							emitters += 1
						end
					end
					expect(emitters).to.equal(2) -- the flash and the smoke
					-- ...AND NEITHER IS THE DEFAULT SPARKLE (round 3). Karen: "I am not about size I
					-- am about this shape like a star" -- an emitter with no `Texture` draws
					-- Roblox's four-pointed sparkle, which is the star she saw. Both carry one of
					-- the engine's own soft textures instead, and `rbxasset://` says it is shipped
					-- with Studio rather than uploaded.
					for _, child in ipairs(lit:GetChildren()) do
						if child:IsA("ParticleEmitter") then
							local texture = (child :: ParticleEmitter).Texture
							expect(texture).never.to.equal("")
							expect(string.sub(texture, 1, 11)).to.equal("rbxasset://")
							expect(string.find(texture, "sparkle") == nil).to.equal(true)
						end
					end
					-- ...AND THE COLOURS ARE THE ONES KAREN OK'D, read from the data rather than
					-- written twice: the Director previewed them live on 2026-10-02.
					local flashEmitter = lit:FindFirstChild("Flash") :: ParticleEmitter
					local smokeEmitter = lit:FindFirstChild("Smoke") :: ParticleEmitter
					expect(flashEmitter.LightEmission).to.equal(1)
					expect(smokeEmitter.LightEmission).to.equal(0)
					local want = firstPersonConfig.FIRE.flash.colorStart
					local got = flashEmitter.Color.Keypoints[1].Value
					expect(math.abs(got.R * 255 - want.r) < 1).to.equal(true)
					expect(math.abs(got.G * 255 - want.g) < 1).to.equal(true)
					expect(math.abs(got.B * 255 - want.b) < 1).to.equal(true)
					local muzzle = (Camera.Viewmodel.muzzle(barrel) :: CFrame).Position
					TestKit.note(
						string.format(
							"task112 barrel %d flash is %.3f studs from its muzzle",
							barrel,
							(lit.Position - muzzle).Magnitude
						)
					)
					expect((lit.Position - muzzle).Magnitude < 0.25).to.equal(true)
					-- ...and NOT at the other barrel's.
					local other = (Camera.Viewmodel.muzzle(3 - barrel) :: CFrame).Position
					expect((lit.Position - muzzle).Magnitude < (lit.Position - other).Magnitude).to.equal(true)
					lit:Destroy()
				end
				-- WHAT STILL REFUSES TO DRAW IT, now that the gun flag is gone (task 114): a
				-- THIRD-PERSON config, because the flash is parented to the viewmodel and rides it
				-- through the kick, and a config whose `fire` block carries no `flash` at all --
				-- which is what the retired gun's block was. Both are driven here, from the live
				-- config, so the two guards are measured rather than described.
				local shoulder = table.clone(firstPersonConfig) :: any
				shoulder.FIRST_PERSON = false
				table.freeze(shoulder)
				expect(Camera.Viewmodel.flash(1, shoulder)).to.equal(false)
				local noFlash = table.clone(firstPersonConfig) :: any
				noFlash.FIRE = table.freeze({ gunPitchDeg = 4, volume = firstPersonConfig.FIRE.volume })
				table.freeze(noFlash)
				expect(Camera.Viewmodel.flash(1, noFlash)).to.equal(false)
				expect(Camera.Viewmodel.flash(1, nil)).to.equal(false)

				-- AND THE OLD EFFECTS DO NOT DRAW ON TOP OF IT (round 1, finding 1). Karen: "remove
				-- those smokes (white from previous)". `Weapon.Effects` asks first; when the
				-- viewmodel says it drew, the neon box and the grey ball are skipped. Driven through
				-- `Effects.play` itself, with a payload that says the shot is mine.
				local Effects = require(scripts:WaitForChild("Weapon")).Effects
				local liveFlash = Effects.getViewmodelFlash()
				local liveMuzzle = Effects.getMuzzleProvider()
				Effects.setMuzzleProvider(function(barrel: number?): CFrame?
					return Camera.Viewmodel.muzzle(barrel)
				end)
				local payload = {
					shooterUserId = Players.LocalPlayer.UserId,
					barrel = 1,
					muzzle = (Camera.Viewmodel.muzzle(1) :: CFrame).Position,
					impacts = {},
				}
				local function oldPartsNearMuzzle(): number
					local found = 0
					for _, drawn in ipairs(Effects.folder():GetChildren()) do
						if drawn.Name == "Flash" or drawn.Name == "Smoke" then
							found += 1
						end
					end
					return found
				end
				for _, drawn in ipairs(Effects.folder():GetChildren()) do
					drawn:Destroy()
				end
				Effects.setViewmodelFlash(function(barrel: number?): boolean
					return Camera.Viewmodel.flash(barrel, firstPersonConfig)
				end)
				Effects.play(payload)
				TestKit.note(
					string.format(
						"task112 with the viewmodel drawing: %d old Flash/Smoke part(s)",
						oldPartsNearMuzzle()
					)
				)
				expect(oldPartsNearMuzzle()).to.equal(0)
				local emitterSets = 0
				for _, drawn in ipairs(clone:GetChildren()) do
					if drawn.Name == "MuzzleFlash" then
						emitterSets += 1
					end
				end
				expect(emitterSets).to.equal(1)
				-- ...and with nobody drawing the first-person one, the pair is drawn exactly as it
				-- was before this task: the skip is the viewmodel's answer, not a deletion.
				Effects.setViewmodelFlash(nil)
				Effects.play(payload)
				expect(oldPartsNearMuzzle()).to.equal(2)
				for _, drawn in ipairs(Effects.folder():GetChildren()) do
					drawn:Destroy()
				end
				Effects.setViewmodelFlash(liveFlash)
				Effects.setMuzzleProvider(liveMuzzle)
			end)
			Camera.Viewmodel.clear()
			Camera.Viewmodel.setSource(live)
			handle:Destroy()
			if not ok then
				error(why, 0)
			end
		end)

		it("is built, not cloned: the pieces are really under the camera", function()
			withNewGun(function()
				Camera.Viewmodel.setReload(nil)
				Camera.Viewmodel.update(CFrame.new(0, 16, 0), stateAtBlend(0), firstPersonConfig)
				local model = Camera.Viewmodel.current()
				expect(model).to.be.ok()
				local clone = (model :: Model).PrimaryPart :: BasePart
				-- THE ENVELOPE IS UNCHANGED, which is what keeps every pose and the near-plane
				-- arithmetic the same gun they were written for.
				expect(clone.Size).to.equal(Shotgun.CONFIG.HANDLE_SIZE)
				expect(clone.Transparency).to.equal(1)
				expect(clone:IsDescendantOf(Workspace.CurrentCamera)).to.equal(true)
				local barrels = clone:FindFirstChild("Barrels") :: BasePart
				expect(barrels).to.be.ok()
				-- WHAT SWINGS IS A PARENT, not a list of names: the barrel group and the bead are
				-- children of it, and the frame group is not.
				for _, name in ipairs({ Gun.BARREL_GROUP_NAME, "Bead" }) do
					expect(barrels:FindFirstChild(name)).to.be.ok()
				end
				expect(clone:FindFirstChild(Gun.FRAME_GROUP_NAME)).to.be.ok()
				expect(barrels:FindFirstChild(Gun.FRAME_GROUP_NAME)).to.equal(nil)
				-- The two attachments the rest of the system reads off the PrimaryPart.
				expect(clone:FindFirstChild("Sight")).to.be.ok()
				expect(clone:FindFirstChild("Muzzle")).to.be.ok()
				expect((Camera.Viewmodel.sight() :: CFrame).Position).to.equal(Gun.beadOffset(Shotgun.CONFIG))
				-- WHETHER THE UPLOADS LOADED, SAID RATHER THAN ASSUMED. Both halves are published by
				-- the server through `InsertService`, which takes seconds, so a run that got there
				-- first draws the fallback boxes -- a real state, and the reason the fallback exists.
				-- Either way the gun is the same parts in the same places, which is what is asserted.
				local drawn = Camera.Viewmodel.stats().meshesDrawn
				TestKit.note(string.format("task105 %d of 2 group meshes were on this build", drawn))
				for _, name in ipairs({ Gun.BARREL_GROUP_NAME, Gun.FRAME_GROUP_NAME }) do
					local part = clone:FindFirstChild(name) or barrels:FindFirstChild(name)
					expect((part :: BasePart):IsA("BasePart")).to.equal(true)
				end
				-- THE GUN'S OWN PARTS, which is what the budget is about: the two gloves are the
				-- HANDS' cost and are counted in their own case. The two-player run is what taught
				-- this -- there the live templates had arrived, so the drawn model was bigger than
				-- the gun and the budget read as broken when it was not.
				local parts, worn = 0, 0
				for _, found in ipairs((model :: Model):GetDescendants()) do
					if found:IsA("BasePart") then
						if found.Name == "HandRight" or found.Name == "HandLeft" then
							worn += 1
						else
							parts += 1
						end
						-- NOTHING UNDER THE CAMERA MAY BE HIT BY A RAY, including this system's own
						-- occlusion cast (the viewmodel header).
						expect(found.CanQuery).to.equal(false)
						expect(found.Anchored).to.equal(true)
					end
				end
				TestKit.note(string.format("task105 the drawn new gun is %d gun part(s) plus %d worn", parts, worn))
				expect(parts).to.equal(Gun.partCount(Shotgun.CONFIG))
			end)
		end)

		it("swings its barrel group about the model's knuckle, and the frame stays put", function()
			withNewGun(function()
				local at = CFrame.new(0, 16, 0)
				Camera.Viewmodel.setReload(nil)
				Camera.Viewmodel.update(at, stateAtBlend(0), firstPersonConfig)
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				local barrels = clone:FindFirstChild("Barrels") :: BasePart
				local group = barrels:FindFirstChild(Gun.BARREL_GROUP_NAME) :: BasePart
				local frame = clone:FindFirstChild(Gun.FRAME_GROUP_NAME) :: BasePart
				local bead = barrels:FindFirstChild("Bead") :: BasePart
				local hinge = Gun.hinge(Shotgun.CONFIG)
				local shutGroup = clone.CFrame:ToObjectSpace(group.CFrame)
				local shutFrame = clone.CFrame:ToObjectSpace(frame.CFrame)
				local shutBead = clone.CFrame:ToObjectSpace(bead.CFrame)
				local onBarrels = barrels.CFrame:ToObjectSpace(group.CFrame)

				local open = table.clone(stateAtBlend(0)) :: any
				open.openTilt = 1
				table.freeze(open)
				Camera.Viewmodel.setReload({ open = true, spent = 2, loaded = { false, false } })
				Camera.Viewmodel.update(at, open, firstPersonConfig)

				local openGroup = clone.CFrame:ToObjectSpace(group.CFrame)
				local openFrame = clone.CFrame:ToObjectSpace(frame.CFrame)
				local openBead = clone.CFrame:ToObjectSpace(bead.CFrame)
				TestKit.note(
					string.format(
						"task105 break: the barrel group moved %.3f studs on the body, the frame %.4f",
						(openGroup.Position - shutGroup.Position).Magnitude,
						(openFrame.Position - shutFrame.Position).Magnitude
					)
				)
				-- THE BARRELS MOVE AND THE FRAME DOES NOT, which is what a hinge is. The bead is
				-- measured too, because it is the one piece that is still DRAWN and it has to ride
				-- the barrels down rather than hang where the muzzle used to be.
				expect((openGroup.Position - shutGroup.Position).Magnitude > 0.1).to.equal(true)
				expect((openBead.Position - shutBead.Position).Magnitude > 0.1).to.equal(true)
				expect((openFrame.Position - shutFrame.Position).Magnitude < 1e-3).to.equal(true)
				-- ...and the group has not moved relative to the parent it belongs to: it turns as
				-- one piece rather than the mesh tearing, which is the frame task 99 existed to fix.
				local stillOnBarrels = barrels.CFrame:ToObjectSpace(group.CFrame)
				expect((stillOnBarrels.Position - onBarrels.Position).Magnitude < 1e-3).to.equal(true)
				-- AND EVERY RIDER STAYS THE SAME DISTANCE FROM THE HINGE, which is what makes the
				-- motion a rotation about THAT axis rather than a slide that looks like one. The
				-- hinge is a point in the gun's own frame now -- there is no pin part on model B to
				-- read it off -- so it is measured against `Gun.hinge`, which is what swung it.
				for _, row in ipairs({
					{ name = "group", shut = shutGroup, opened = openGroup },
					{ name = "bead", shut = shutBead, opened = openBead },
				}) do
					local shutR = (row.shut.Position - hinge).Magnitude
					local openR = (row.opened.Position - hinge).Magnitude
					TestKit.note(string.format("task105 %s is %.4f from the hinge, was %.4f", row.name, openR, shutR))
					expect(math.abs(shutR - openR) < 1e-3).to.equal(true)
				end
			end)
		end)

		it("draws the muzzle flash on the model's own bore line, at the muzzle", function()
			-- `Camera.Viewmodel.muzzle` is what `Weapon.Effects` draws the first-person flash at, and
			-- it adds the barrel's own rise to the `Muzzle` attachment. Model B's bores are 0.039
			-- studs off the centre line where the drawn gun's were 0.076 and the world gun's are
			-- 0.09, so a flash built from the wrong gun's number lands between the tubes.
			withNewGun(function()
				Camera.Viewmodel.setReload(nil)
				Camera.Viewmodel.update(CFrame.new(0, 16, 0), stateAtBlend(0), firstPersonConfig)
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				local at = Gun.layout(Shotgun.CONFIG)
				for barrel = 1, 2 do
					local flash = Camera.Viewmodel.muzzle(barrel)
					expect(flash).to.be.ok()
					local inGun = clone.CFrame:ToObjectSpace(flash :: CFrame)
					local bore = Gun.barrelOffset(barrel, Shotgun.CONFIG)
					local across = Vector2.new(inGun.Position.X - bore.X, inGun.Position.Y - bore.Y).Magnitude
					TestKit.note(
						string.format(
							"task105 barrel %d flash %.4f studs off its bore line (bore radius %.4f), z %+.4f",
							barrel,
							across,
							at.barrelRadius,
							inGun.Position.Z
						)
					)
					expect(across < 1e-3).to.equal(true)
					-- AT THE MUZZLE END, by sign and by distance: the muzzle is the Handle's -Z.
					expect(inGun.Position.Z < 0).to.equal(true)
					expect(math.abs(inGun.Position.Z - at.muzzleZ) < 1e-3).to.equal(true)
				end
			end)
		end)

		it("seats the uploaded shell brass-head-first, measured on the drawn part", function()
			-- ROUND 2'S FINDING, ON THE INSTANCE. The import's half turn was written onto the cloned
			-- PART and then thrown away: `Model:PivotTo` moves the model so its PIVOT lands on the
			-- CFrame it is given, and with `PrimaryPart` set the pivot IS that part -- so the part's
			-- own CFrame was overwritten on the frame it was made. The uploaded shell kept only the
			-- file's quarter turn and seated brass-head-up-the-barrel.
			--
			-- IT STANDS IN A TEMPLATE, for the reason task 106's flag-OFF guard does:
			-- `InsertService:LoadAsset` has not landed when the client specs run, so the uploaded
			-- branch is never exercised by a harness run that waits for it. What is asserted is the
			-- TURN THAT WAS APPLIED, read off the drawn part -- a stub stands in for the mesh
			-- perfectly well, because the stub takes the same `shellTurnDeg` the cartridge would.
			-- Everything made here is destroyed again.
			local made: { Instance } = {}
			local folder = ReplicatedStorage:FindFirstChild(Gun.FOLDER_NAME)
			if folder == nil then
				local new = Instance.new("Folder")
				new.Name = Gun.FOLDER_NAME
				new.Parent = ReplicatedStorage
				table.insert(made, new)
				folder = new
			end
			local template = (folder :: Instance):FindFirstChild(Gun.SHELL_TEMPLATE_NAME)
			if template == nil then
				local stand = Instance.new("Part")
				stand.Name = Gun.SHELL_TEMPLATE_NAME
				stand.Size = Gun.SHELL_MESH_SIZE_STUDS
				stand.Parent = folder
				table.insert(made, stand)
			end

			local ok, why = pcall(function()
				withNewGun(function()
					local at = CFrame.new(0, 16, 0)
					local open = table.clone(stateAtBlend(0)) :: any
					open.openTilt = 1
					table.freeze(open)
					-- NO YIELD, for the reason the case below gives: the live render step would
					-- rebuild the clone from a different handle between these two calls. The shells are
					-- reached through `withSeatedShells`, because the hand has to have carried them in
					-- before there is a drawn part to measure a TURN on.
					withSeatedShells(at, open, 2, { true, true })
					local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
					local barrels = clone:FindFirstChild("Barrels") :: BasePart
					for barrel = 1, 2 do
						local shell = clone:FindFirstChild("FreshShell" .. barrel) :: Model
						expect(shell).to.be.ok()
						local body = shell:FindFirstChild("Body") :: BasePart
						expect(body).to.be.ok()
						-- THE UPLOADED CARTRIDGE IS ONE PART, so there is no `Rim` child to compare
						-- against: what says which way round it is, is the part's OWN AXES. Its long
						-- axis is its X, and after Roblox's import the BRASS HEAD is at +X (the file
						-- is written mouth-at-+X and the import reverses it, `Gun.MESH_MUZZLE_AXIS`).
						-- So in the barrels' own frame that +X must point at +Z -- toward the breech
						-- face and the shooter -- and not down the tube.
						local headAxis = barrels.CFrame:VectorToObjectSpace(body.CFrame.RightVector)
						TestKit.note(
							string.format(
								"task107 fresh shell %d: its brass axis points (%.3f, %.3f, %.3f) in the barrels' frame",
								barrel,
								headAxis.X,
								headAxis.Y,
								headAxis.Z
							)
						)
						expect(headAxis.Z > 0.99).to.equal(true)
						-- ...AND THE BRASS END IS NEVER INSIDE THE TUBE. The gate's first run of this
						-- case asserted that the shell's CENTRE sits forward of the chamber mouth,
						-- and it failed at 0.853 against a mouth at 0.522 -- not because the shell
						-- was backwards but because it was caught MID-FEED: `Viewmodel.shells` slides
						-- a fresh shell in from `feedFromStuds` behind the seat, so the one claim with
						-- no clock in it is the one that holds at every moment of that slide. The
						-- brass end is at or BEHIND the mouth the whole way in; a shell whose head
						-- had gone past it would be a shell loaded backwards.
						local seatZ = Gun.chamber(barrel, Shotgun.CONFIG).Position.Z
						local centreZ = barrels.CFrame:ToObjectSpace(body.CFrame).Position.Z
							+ Gun.layout(Shotgun.CONFIG).barrelZ
						local brassEndZ = centreZ + headAxis.Z * body.Size.X / 2
						TestKit.note(
							string.format(
								"task107 fresh shell %d: centre z %.4f, brass end %.4f, chamber mouth %.4f",
								barrel,
								centreZ,
								brassEndZ,
								seatZ
							)
						)
						expect(brassEndZ > seatZ - 1e-3).to.equal(true)
					end
				end)
			end)
			for index = #made, 1, -1 do
				made[index]:Destroy()
			end
			if not ok then
				error(why, 0)
			end
		end)

		it("seats a fresh shell on the bore line, its rim OUT of the breech face", function()
			withNewGun(function()
				local at = CFrame.new(0, 16, 0)
				local open = table.clone(stateAtBlend(0)) :: any
				open.openTilt = 1
				table.freeze(open)
				-- NO YIELD ANYWHERE IN HERE, and the two-player run is why: the live render step
				-- draws with the LIVE source, so a `task.wait` between these calls lets it rebuild
				-- the clone from a different handle and this case then measures somebody else's gun.
				--
				-- SO BOTH CLAIMS ARE ONES THAT HOLD AT EVERY MOMENT OF THE FEED: the shell is ON the
				-- tube's own bore line, and its back face is OUTSIDE the breech. A shell still
				-- travelling in is further out than a seated one, so neither depends on a frame.
				withSeatedShells(at, open, 2, { true, true })
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				local barrels = clone:FindFirstChild("Barrels") :: BasePart
				local layout = Gun.layout(Shotgun.CONFIG)
				for barrel = 1, 2 do
					local shell = clone:FindFirstChild("FreshShell" .. barrel)
					expect(shell).to.be.ok()
					-- MEASURED IN THE BARREL GROUP'S FRAME, which is where the shell is drawn and
					-- where it swings: the bore line is `Gun.barrelOffset`, the one definition of it.
					local inBarrels = barrels.CFrame:ToObjectSpace((shell :: Model):GetPivot())
					-- ...and the barrel group's own part sits `at.barrelZ` down the gun from the
					-- Handle, so the bore line in ITS frame is the same X and Y and that Z removed.
					local bore = Gun.barrelOffset(barrel, Shotgun.CONFIG)
					local across = Vector2.new(inBarrels.Position.X - bore.X, inBarrels.Position.Y - bore.Y).Magnitude
					TestKit.note(
						string.format(
							"task105 fresh shell %d is %.4f studs off its bore line (bore radius %.4f)",
							barrel,
							across,
							layout.barrelRadius
						)
					)
					-- EXACTLY on the bore line, not merely inside the tube: the bound used to be the
					-- tube's own radius, which is five times the error the old answer had, so the
					-- case passed with the new gun's branch of it deleted (task 99 round 2).
					expect(across < 1e-3).to.equal(true)
					-- THE SEAT IS OUTSIDE THE BREECH FACE. Rounds 1 and 2 of task 99 seated the shell
					-- down an opaque tube, so a loaded chamber and an empty one were the same
					-- picture. This is the claim with no clock in it: the gun's own seat, against the
					-- gun's own breech.
					local seat = Gun.chamber(barrel, Shotgun.CONFIG).Position.Z
					expect(seat > layout.breechZ).to.equal(true)
					-- AND THE BUILDER AND THE SEAT AGREE ABOUT WHERE THE RIM ENDED UP. The pivot is
					-- backed off from the rim by the shell's own length, so the two can be read back
					-- against each other -- and they must be, or the rim is seated against nothing.
					-- Which shell is drawn depends on whether the upload had loaded, so the back-off
					-- is read off the drawn thing rather than assumed.
					local rim = (shell :: Model):FindFirstChild("Rim")
					local back = if rim ~= nil
						then Gun.shellLayout(firstPersonConfig.SHELL_SIZE_STUDS, firstPersonConfig.SHELL_BASE_FRACTION).back
						else Gun.SHELL_MESH_SIZE_STUDS.X / 2
					local wanted = (Gun.chamber(barrel, Shotgun.CONFIG) * CFrame.new(0, 0, -back)).Position
					local isMesh = rim == nil
					TestKit.note(
						string.format(
							"task105 shell %d is the %s one, backed off %.4f",
							barrel,
							if isMesh then "uploaded" else "drawn",
							back
						)
					)
					-- MEASURED IN THE BARREL GROUP'S FRAME, NOT THE HANDLE'S, and with the gun open
					-- that matters: the shells are drawn from the SWUNG gun's transform, which the
					-- Handle's own CFrame is not. The group's part sits `at.barrelZ` down the gun from
					-- it, so that is what is added back. The feed slides the shell backward along Z from
					-- the seat, so only the two across-axes are exact and Z is a bound.
					expect(math.abs(inBarrels.Position.X - wanted.X) < 1e-3).to.equal(true)
					expect(math.abs(inBarrels.Position.Y - wanted.Y) < 1e-3).to.equal(true)
					expect(inBarrels.Position.Z + layout.barrelZ >= wanted.Z - 1e-3).to.equal(true)
				end
			end)
		end)
		it("draws the gloves out of the one folder the server publishes them into", function()
			-- TASK 106 ROUND 1'S FINDING 1, ON THE INSTANCES THAT ARE REALLY DRAWN, AND WHAT TASK 114
			-- LEFT OF IT. Karen's gloves first shipped as `hand.right` VERSION 2, which supersedes --
			-- so the build whose poses were measured against the v1 models was handed her pair: upside
			-- down and at 53 % of the size those poses assume. Two folders and two keys were the fix.
			-- One gun now means ONE folder, and this is the half only a client can see: the drawn hand
			-- comes out of `HandAssets.FOLDER_NAME` and nowhere else.
			--
			-- IT DOES NOT WAIT FOR THE UPLOADS, AND THAT IS DELIBERATE. `InsertService:LoadAsset`
			-- takes seconds and the client specs run before it lands -- the task 99 gloves case below
			-- has skipped in every harness run for that reason, which is a case that cannot fail. So
			-- where the pair is not published this stands one in: `Camera.Viewmodel.handTemplate`
			-- reads the folder by name, so a part of the right name in the right folder IS the thing
			-- it looks up. Anything made here is destroyed again.
			local made: { Instance } = {}
			local function template(folderName: string, size: Vector3): BasePart
				local folder = ReplicatedStorage:FindFirstChild(folderName)
				if folder == nil then
					local new = Instance.new("Folder")
					new.Name = folderName
					new.Parent = ReplicatedStorage
					table.insert(made, new)
					folder = new
				end
				local hand = (folder :: Instance):FindFirstChild(HandAssets.RIGHT)
				if hand == nil then
					local stand = Instance.new("Part")
					stand.Name = HandAssets.RIGHT
					stand.Size = size
					stand.Parent = folder
					table.insert(made, stand)
					hand = stand
				end
				return hand :: BasePart
			end

			local ok, why = pcall(function()
				-- The published pair's own size when it IS there, and a stand-in of that size when
				-- it is not.
				local size = template(HandAssets.FOLDER_NAME, Vector3.new(0.67, 0.35, 0.21)).Size
				-- A SECOND FOLDER THAT MUST NOT BE READ. `ViewmodelHandsNewGun` is the folder task
				-- 106 added and task 114 removed; a glove of an unmistakable size is parked there,
				-- so a lookup that still reached for it would draw 1.27 studs instead of 0.67 and
				-- this case would say so rather than passing on a name nobody publishes any more.
				local stale = template("ViewmodelHandsNewGun", Vector3.new(1.27, 0.57, 0.53)).Size
				expect(size).never.to.equal(stale)
				TestKit.note(
					string.format(
						"task114 the drawn glove is %.3f studs; the retired folder holds %.3f",
						math.max(size.X, size.Y, size.Z),
						math.max(stale.X, stale.Y, stale.Z)
					)
				)

				local found: Vector3? = nil
				withNewGun(function()
					Camera.Viewmodel.setReload(nil)
					Camera.Viewmodel.update(CFrame.new(0, 16, 0), stateAtBlend(0), firstPersonConfig)
					local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
					local hand = clone:FindFirstChild(HandAssets.RIGHT)
					if hand and hand:IsA("BasePart") then
						found = (hand :: BasePart).Size
					end
				end)
				expect(found).to.be.ok()
				expect(found).to.equal(size)
			end)
			for index = #made, 1, -1 do
				made[index]:Destroy()
			end
			if not ok then
				error(why, 0)
			end
		end)
	end)

	-- THE GLOVES (task 99). Karen, 2026-10-01: the right glove is WHITE in game. The manifest half of
	-- the fix is asserted on the server (`gun.spec`); this is the half only a client can see -- what
	-- is actually published, and that nothing draws a sleeve behind it any more.
	describe("the gloves", function()
		local DEFAULT_GREY = Color3.fromRGB(163, 162, 165)

		it("are never left at Roblox's default grey, and carry no drawn sleeve", function()
			local folder = ReplicatedStorage:FindFirstChild("ViewmodelHands")
			local published = if folder then folder:GetChildren() else {}
			if #published == 0 then
				-- A gun with no hands is a real state -- the load failed, or the asset was moderated
				-- away -- and `Viewmodel.stats().handsMissing` is what reports it. Said rather than
				-- passed silently.
				TestKit.note("task99 gloves: nothing published on this client, so nothing to measure")
			end
			for _, hand in ipairs(published) do
				if hand:IsA("BasePart") then
					TestKit.note(
						string.format(
							"task99 %s published at (%d, %d, %d), %s",
							hand.Name,
							math.round(hand.Color.R * 255),
							math.round(hand.Color.G * 255),
							math.round(hand.Color.B * 255),
							hand.Material.Name
						)
					)
					-- THE DEFECT ITSELF: a part whose colour map does not draw falls back to its
					-- `Color`, and left at the default that is the white blob Karen saw.
					expect(hand.Color).never.to.equal(DEFAULT_GREY)
					-- ...AND THE EXACT STATE THAT CAUSED IT IS GONE. `AlphaMode.Overlay` blends the
					-- colour map over `Color` THROUGH THE MAP'S ALPHA, and these maps have no alpha
					-- channel -- so a hand left with a SurfaceAppearance and no `TextureID` draws no
					-- texture at all, whatever ids it carries. Either the map is on `TextureID`
					-- (the path that does not read alpha) or there is no map to draw.
					local appearance = hand:FindFirstChildOfClass("SurfaceAppearance")
					expect(appearance).to.equal(nil)
					-- ...AND THE MAP IS ON THE PATH THAT DRAWS IT. The id comes from the manifest
					-- row, because a game script cannot READ `SurfaceAppearance.ColorMap` at all --
					-- measured, 2026-10-01: "lacking capability Plugin", which took the whole boot
					-- down and published nothing.
					expect((hand :: any).TextureID).never.to.equal("")
					-- A MeshPart's Color TINTS its TextureID, so a textured hand is left white.
					expect(hand.Color).to.equal(Color3.new(1, 1, 1))
				end
			end

			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Size = Shotgun.CONFIG.HANDLE_SIZE
			handle.Transparency = 1
			local live = Camera.Viewmodel.getSource()
			Camera.Viewmodel.setSource(function()
				return handle
			end)
			local ok, why = pcall(function()
				task.wait(0.3)
				Camera.Viewmodel.clear()
				Camera.Viewmodel.setReload(nil)
				Camera.Viewmodel.update(CFrame.new(0, 16, 0), stateAtBlend(0), firstPersonConfig)
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				local found, sleeves = 0, 0
				for _, drawn in ipairs(clone:GetDescendants()) do
					if drawn.Name == "HandRight" or drawn.Name == "HandLeft" then
						found += 1
					elseif drawn.Name == "Sleeve" then
						sleeves += 1
					end
				end
				-- NO SLEEVE, ANYWHERE UNDER THE GUN (tasks 111 and 114). Karen, 2026-10-02: "you can
				-- remove those arm extentions from both hands". Task 99 drew one because the v1 glove
				-- ended at an open cuff; her pair carries its own turned cuff, so there is nothing
				-- left to plug and nothing left in `Camera.Viewmodel` that could draw one.
				TestKit.note(string.format("task114 %d drawn hand(s), %d sleeve(s)", found, sleeves))
				expect(sleeves).to.equal(0)
				expect(found).to.equal(#published)
			end)
			Camera.Viewmodel.clear()
			Camera.Viewmodel.setSource(live)
			handle:Destroy()
			if not ok then
				error(why, 0)
			end
		end)
	end)
end
