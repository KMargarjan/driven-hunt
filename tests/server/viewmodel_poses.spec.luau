--!strict
-- The viewmodel's POSE DATA (task 98): the shipped `poses.json`, the pure merge of a live override
-- onto it, the flat view `Camera.Config` publishes, and the keyframe player's own arithmetic.
--
-- WHY IT IS A SERVER SPEC when everything it tests draws a gun on a client: all of it is PURE.
-- `ReplicatedStorage.Viewmodel` holds no Instances, and `Camera.Mode` has no services, no clock and
-- no camera -- the same reason `camera_mode.spec` runs here. What needs a real viewport is in
-- `tests/client/camera_client.spec.luau`.
--
-- EVERY CASE BUILDS ITS OWN TABLES, except the ones that are ABOUT the shipped file. Those are the
-- tripwire: a `poses.json` that is missing a field, asks for an easing nobody implemented, or puts a
-- keyframe out of order FAILS THE HARNESS, which blocks the merge gate -- the same shape as the flag
-- `expires` check (docs/design/feature-flags.md). A pose file that half-loads would otherwise show
-- up as a gun drawn in the wrong place with nothing saying why.
--
-- Note: docs/research/2026-10-01-poses-as-data.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Data = require(ReplicatedStorage:WaitForChild("Viewmodel"))

local scripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
local Camera = scripts:WaitForChild("Camera")
local Config = require(Camera:WaitForChild("Config"))
local Mode = require(Camera:WaitForChild("Mode"))
local Poses = require(Camera:WaitForChild("Poses"))

-- A config of each branch, built here rather than read off the live one: the flag sits at one of the
-- two and both must stay reachable by parameter (docs/design/feature-flags.md 13.3).
local function configWith(firstPerson: boolean, data: any?)
	local out = table.clone(Config) :: any
	if data ~= nil then
		for key, value in pairs(Data.view(data, Config.NEW_GUN)) do
			out[key] = value
		end
	end
	out.FIRST_PERSON = firstPerson
	return table.freeze(out)
end

local function stateAt(blend: number, openTilt: number)
	local state = table.clone(Mode.initial(Config)) :: any
	state.mode = if blend > 0 then "Aiming" else "Third"
	state.blend = blend
	state.openTilt = openTilt
	return table.freeze(state)
end

return function()
	describe("the shipped poses.json", function()
		it("loads, and `validate` finds nothing wrong with it", function()
			local problems = Data.validate(Data.DATA)
			TestKit.note(
				"task98 poses.json problems: " .. (if #problems == 0 then "none" else table.concat(problems, "; "))
			)
			expect(#problems).to.equal(0)
		end)

		it("is deep frozen, so nothing in the game can write a pose number", function()
			expect(table.isfrozen(Data.DATA)).to.equal(true)
			expect(table.isfrozen(Data.DATA.carry)).to.equal(true)
			expect(table.isfrozen(Data.DATA.carry.gun.pos)).to.equal(true)
			expect(function()
				(Data.DATA.carry.gun.pos :: any).x = 99
			end).to.throw()
		end)

		it("ships with no mid keyframes, which is the swing the camera has had since task 89", function()
			expect(#Data.DATA.raise.keyframes).to.equal(0)
		end)

		-- A RULE ABOUT THE GAME AND NOT A TASTE, so it is asserted rather than left to a comment: the
		-- DRAWN swing must finish before the server's own step ends, or the gun is caught half open
		-- when the shells arrive. Tuning `reload.openSeconds` past the server's break fails here.
		it("draws the break and the close faster than the server performs them", function()
			TestKit.note(
				string.format(
					"task98 break: drawn %.2f s vs server %.2f s; close drawn %.2f s vs server %.2f s",
					Data.DATA.reload.openSeconds,
					Shotgun.CONFIG.RELOAD_BREAK,
					Data.DATA.reload.closeSeconds,
					Shotgun.CONFIG.RELOAD_CLOSE
				)
			)
			expect(Data.DATA.reload.openSeconds < Shotgun.CONFIG.RELOAD_BREAK).to.equal(true)
			expect(Data.DATA.reload.closeSeconds < Shotgun.CONFIG.RELOAD_CLOSE).to.equal(true)
		end)
	end)

	describe("validate", function()
		local function broken(mutate)
			local copy = Data.copy(Data.DATA)
			mutate(copy)
			return Data.validate(copy)
		end

		-- THE MUTATION CHECK FOR THE TRIPWIRE ABOVE. Each of these is a way a hand-edited or
		-- tool-written poses.json can be wrong; if any of them passed, the case that asserts the
		-- shipped file is clean would be asserting nothing.
		it("names a missing field", function()
			expect(#broken(function(data)
				data.carry.gun.pos.y = nil
			end)).to.equal(1)
		end)

		it("refuses an easing nobody implemented", function()
			local problems = broken(function(data)
				data.raise.easing = "cubicInOut"
			end)
			expect(#problems).to.equal(1)
			expect(string.find(problems[1], "only quadOut is implemented") ~= nil).to.equal(true)
		end)

		it("refuses a non-positive duration", function()
			expect(#broken(function(data)
				data.raise.raiseSeconds = 0
			end)).to.equal(1)
			expect(#broken(function(data)
				data.reload.openSeconds = -1
			end)).to.equal(1)
		end)

		it("refuses a keyframe at either end, or out of order", function()
			local frame = {
				gun = { pos = { x = 0, y = 0, z = -1 }, rot = { x = 0, y = 0, z = 0 } },
			}
			for _, time in ipairs({ 0, 1, 1.5, -0.2 }) do
				local one = Data.copy(frame)
				one.t = time
				local problems = broken(function(data)
					data.raise.keyframes = { one }
				end)
				expect(#problems).to.equal(1)
			end
			-- IN ORDER, which is the one a human gets wrong: two keyframes whose times go backwards
			-- would make the swing run backwards for a stretch.
			local first, second = Data.copy(frame), Data.copy(frame)
			first.t, second.t = 0.6, 0.3
			expect(#broken(function(data)
				data.raise.keyframes = { first, second }
			end)).to.equal(1)
		end)

		it("accepts a keyframe in the middle, with or without hands", function()
			local frame = {
				t = 0.45,
				gun = { pos = { x = 0, y = 0, z = -1 }, rot = { x = 0, y = 0, z = 0 } },
			}
			expect(#broken(function(data)
				data.raise.keyframes = { frame }
			end)).to.equal(0)
			local withHand = Data.copy(frame)
			withHand.right = Data.copy(Data.DATA.carry.right)
			expect(#broken(function(data)
				data.raise.keyframes = { withHand }
			end)).to.equal(0)
			-- ...and a hand that IS named must be a whole hand.
			local halfHand = Data.copy(frame)
			halfHand.left = { pos = { x = 0, y = 0, z = 0 } }
			expect(#broken(function(data)
				data.raise.keyframes = { halfHand }
			end) > 0).to.equal(true)
		end)
	end)

	describe("paths and merge", function()
		it("lists every pose number by dotted path, and no string or version", function()
			local paths = Data.paths(Data.DATA)
			for _, wanted in ipairs({
				"carry.gun.pos.x",
				"carry.gun.rot.y",
				"carry.right.rot.twist",
				"aim.eyeReliefStuds",
				"aim.cheekDeg",
				"raise.raiseSeconds",
				"fire.gunPitchDeg",
				"reload.openDeg",
				"reload.shells.feedSeconds",
			}) do
				expect(paths[wanted]).to.be.ok()
			end
			expect(paths["version"]).to.equal(nil)
			expect(paths["raise.easing"]).to.equal(nil)
			expect(paths["carry"]).to.equal(nil) -- a pose is not a number
		end)

		it("applies an override and moves nothing else", function()
			local merged, problems = Data.merge(Data.DATA, { ["aim.cheekDeg"] = 7.5 })
			expect(#problems).to.equal(0)
			expect(merged.aim.cheekDeg).to.equal(7.5)
			local before, after = Data.paths(Data.DATA), Data.paths(merged)
			local moved = 0
			for path, value in pairs(after) do
				if math.abs(value - before[path]) > 1e-12 then
					moved += 1
				end
			end
			expect(moved).to.equal(1)
			-- The source is untouched and the result is frozen: the data is the one source, and a
			-- merge is a new table rather than an edit of it.
			expect(Data.DATA.aim.cheekDeg).to.equal(before["aim.cheekDeg"])
			expect(table.isfrozen(merged.aim)).to.equal(true)
		end)

		it("refuses a path that is not a pose number, and keeps the data as it was", function()
			for _, bad in ipairs({
				{ ["aim.cheeckDeg"] = 1 },
				{ ["aim"] = 1 },
				{ ["raise.easing"] = 1 },
				{ ["version"] = 2 },
				{ ["aim.cheekDeg"] = "4.2" },
				{ ["aim.cheekDeg"] = true },
			}) do
				local merged, problems = Data.merge(Data.DATA, bad)
				expect(#problems).to.equal(1)
				expect(merged.aim.cheekDeg).to.equal(Data.DATA.aim.cheekDeg)
			end
		end)

		it("reads the hold out of the same object, and refuses one nobody implemented", function()
			expect(Data.hold(nil)).to.equal(nil)
			expect(Data.hold({})).to.equal(nil)
			expect(Data.hold({ hold = "aim" })).to.equal("aim")
			expect(Data.hold({ hold = "sideways" })).to.equal(nil)
			expect(Data.hold({ hold = 3 })).to.equal(nil)
			-- The hold is not a pose number, so the merge must not treat it as a typo'd path.
			local _, problems = Data.merge(Data.DATA, { hold = "aim" })
			expect(#problems).to.equal(0)
		end)

		it("reaches into a keyframe by index, counting from 1 like Luau", function()
			local data = Data.copy(Data.DATA)
			data.raise.keyframes = {
				{ t = 0.5, gun = { pos = { x = 0, y = 0, z = -1 }, rot = { x = 0, y = 0, z = 0 } } },
			}
			expect(Data.paths(data)["raise.keyframes.1.gun.pos.z"]).to.equal(-1)
			local merged, problems = Data.merge(data, { ["raise.keyframes.1.gun.pos.z"] = -2 })
			expect(#problems).to.equal(0)
			expect(merged.raise.keyframes[1].gun.pos.z).to.equal(-2)
		end)
	end)

	describe("the view Camera.Config publishes", function()
		-- THE WHOLE OF "ONE SOURCE". `Camera.Config` does not define these numbers any more; it
		-- computes them from the data. If the two ever disagreed, there would be two sources again.
		it("is what the live Config carries", function()
			for key, value in pairs(Data.view(Data.DATA, Config.NEW_GUN)) do
				if typeof(value) == "number" or typeof(value) == "Vector3" then
					expect(Config[key]).to.equal(value)
				end
			end
			-- `POSES` IS A VIEW SINCE TASK 99, not the whole file: it carries the three poses of
			-- WHICHEVER GUN the flag chose, plus the swing and the shot, which both guns share. The
			-- fields are references into the data, so this is still one source.
			local chosen = if Config.NEW_GUN then Data.DATA.newGun else Data.DATA
			expect(Config.POSES.carry).to.equal(chosen.carry)
			expect(Config.POSES.aim).to.equal(chosen.aim)
			expect(Config.POSES.reload).to.equal(chosen.reload)
			expect(Config.POSES.raise).to.equal(Data.DATA.raise)
			expect(Config.POSES.fire).to.equal(Data.DATA.fire)
		end)

		it("gives each gun its own carry, aim and reload, and one swing and one kick", function()
			local classic = Data.view(Data.DATA, false)
			local fresh = Data.view(Data.DATA, true)
			-- The two guns are held differently, so the three poses differ...
			expect(classic.HAND_LEFT_POS_STUDS).never.to.equal(fresh.HAND_LEFT_POS_STUDS)
			expect(classic.POSES.carry).to.equal(Data.DATA.carry)
			expect(fresh.POSES.carry).to.equal(Data.DATA.newGun.carry)
			-- ...and the swing's timings are the player's, not the gun's.
			expect(classic.AIM_RAISE_SECONDS).to.equal(fresh.AIM_RAISE_SECONDS)
			-- THE RECOIL IS THE GUN'S NOW (task 112), and it was the player's until then: Karen's
			-- order was to finish the weapon, and model B kicks harder than the gun she has been
			-- playing. `set.fire` is what makes that per gun, so the two must DIFFER here, and the
			-- old gun's block is still the top-level one it always read.
			expect(classic.RECOIL_GUN_PITCH_DEG).to.equal(Data.DATA.fire.gunPitchDeg)
			expect(fresh.RECOIL_GUN_PITCH_DEG).to.equal(Data.DATA.newGun.fire.gunPitchDeg)
			expect(classic.RECOIL_GUN_PITCH_DEG).never.to.equal(fresh.RECOIL_GUN_PITCH_DEG)
			expect(fresh.POSES.raise).to.equal(Data.DATA.raise)
		end)

		it("follows the data when the data changes", function()
			local data = Data.copy(Data.DATA)
			data.carry.gun.rot.y = 12.5
			data.aim.eyeReliefStuds = 5.0
			local view = Data.view(data, false)
			expect(view.CARRY_YAW_DEG).to.equal(12.5)
			expect(view.EYE_RELIEF_STUDS).to.equal(5.0)
			-- ...and the pose built from it moves, which is the point: the camera reads the view.
			local moved = configWith(true, data)
			expect(Mode.carryOffset(moved)).never.to.equal(Mode.carryOffset(configWith(true)))
		end)
	end)

	describe("the keyframe player", function()
		local firstPerson = configWith(true)
		-- A sight 2 studs in front of the Handle's centre and a little above it, like the real one.
		local sight = CFrame.new(0, 0.12, -2.0)

		it("with no mid keyframes it is exactly the carry-to-aim ease it has always been", function()
			for step = 0, 10 do
				local blend = step / 10
				local state = stateAt(blend, 0)
				local hip = Mode.carryOffset(firstPerson)
				local aim = Mode.aimOffset(sight, firstPerson)
				expect(Mode.viewmodelOffset(state, sight, firstPerson)).to.equal(hip:Lerp(aim, Mode.ease(blend)))
			end
		end)

		it("a mid keyframe is passed through, exactly, at its own time", function()
			local data = Data.copy(Data.DATA)
			local mid = { pos = { x = 0.5, y = -0.25, z = -3.0 }, rot = { x = 10, y = -20, z = 5 } }
			data.raise.keyframes = { { t = 0.5, gun = mid } }
			local config = configWith(true, data)
			-- `blend` is eased, so the frame at `t = 0.5` is reached at the blend whose ease is 0.5:
			-- 1 - (1 - b)^2 = 0.5 => b = 1 - sqrt(0.5).
			local blend = 1 - math.sqrt(0.5)
			local pose = Mode.viewmodelOffset(stateAt(blend, 0), sight, config)
			local wanted = Mode.gunPose(mid)
			TestKit.note(
				string.format(
					"task98 mid keyframe at blend %.4f: %.4f studs from the keyframe",
					blend,
					(pose.Position - wanted.Position).Magnitude
				)
			)
			expect((pose.Position - wanted.Position).Magnitude < 1e-3).to.equal(true)
			-- AND THE TWO ENDS ARE STILL THE TWO POSES, which is what makes a mid keyframe a bend in
			-- the swing rather than a replacement for it. To a tolerance rather than bit-for-bit:
			-- with a keyframe in the way these are the ends of a SEGMENT whose other end is the
			-- keyframe, so they come out of a slerp between two quite different rotations, and
			-- claiming the last bit of a float there would be claiming something about CFrame:Lerp.
			local atCarry = Mode.viewmodelOffset(stateAt(0, 0), sight, config)
			local atAim = Mode.viewmodelOffset(stateAt(1, 0), sight, config)
			expect((atCarry.Position - Mode.carryOffset(config).Position).Magnitude < 1e-5).to.equal(true)
			expect((atAim.Position - Mode.aimOffset(sight, config).Position).Magnitude < 1e-5).to.equal(true)
		end)

		it("a mid keyframe takes the gun somewhere the plain ease never goes", function()
			local data = Data.copy(Data.DATA)
			data.raise.keyframes = {
				{ t = 0.5, gun = { pos = { x = 2.0, y = 2.0, z = -1.0 }, rot = { x = 0, y = 0, z = 0 } } },
			}
			local bent = configWith(true, data)
			local straight = 0
			local blend = 1 - math.sqrt(0.5)
			local plain = Mode.viewmodelOffset(stateAt(blend, 0), sight, firstPerson)
			local curved = Mode.viewmodelOffset(stateAt(blend, 0), sight, bent)
			straight = (plain.Position - curved.Position).Magnitude
			TestKit.note(string.format("task98 the bent swing is %.3f studs off the straight one", straight))
			expect(straight > 0.5).to.equal(true)
		end)

		it("the third-person branch takes no keyframes at all", function()
			local data = Data.copy(Data.DATA)
			data.raise.keyframes = {
				{ t = 0.5, gun = { pos = { x = 9, y = 9, z = -9 }, rot = { x = 0, y = 0, z = 0 } } },
			}
			local third = configWith(false, data)
			for step = 0, 4 do
				local blend = step / 4
				expect(Mode.viewmodelOffset(stateAt(blend, 0), sight, third)).to.equal(
					(third.VIEWMODEL_HIP_OFFSET :: CFrame):Lerp(third.VIEWMODEL_AIM_OFFSET, Mode.ease(blend))
				)
			end
		end)

		it("segmentAt walks the path and clamps outside it", function()
			local times = { 0, 0.25, 1 }
			local index, along = Mode.segmentAt(times, 0)
			expect(index).to.equal(1)
			expect(along).to.equal(0)
			index, along = Mode.segmentAt(times, 0.125)
			expect(index).to.equal(1)
			expect(math.abs(along - 0.5) < 1e-9).to.equal(true)
			index, along = Mode.segmentAt(times, 0.625)
			expect(index).to.equal(2)
			expect(math.abs(along - 0.5) < 1e-9).to.equal(true)
			index, along = Mode.segmentAt(times, 2)
			expect(index).to.equal(2)
			expect(along).to.equal(1)
		end)
	end)

	describe("a hand per pose", function()
		local firstPerson = configWith(true)

		it("at the carry, with the gun shut, both hands are exactly where task 93 put them", function()
			local state = stateAt(0, 0)
			expect(Mode.handOffsetAt("right", state, firstPerson)).to.equal(Mode.rightHandOffset(firstPerson))
			expect(Mode.handOffsetAt("left", state, firstPerson)).to.equal(Mode.leftHandOffset(firstPerson))
		end)

		it("the shipped file seeds every pose's hands the same, so nothing moved", function()
			for _, blend in ipairs({ 0, 0.25, 0.5, 0.75, 1 }) do
				for _, tilt in ipairs({ 0, 0.5, 1 }) do
					local state = stateAt(blend, tilt)
					expect(Mode.handOffsetAt("right", state, firstPerson)).to.equal(Mode.rightHandOffset(firstPerson))
				end
			end
		end)

		it("moves a hand when its own pose says a different thing", function()
			local data = Data.copy(Data.DATA)
			data.aim.right.pos.y = data.carry.right.pos.y + 1.0
			local config = configWith(true, data)
			local carried = Mode.handOffsetAt("right", stateAt(0, 0), config)
			local aimed = Mode.handOffsetAt("right", stateAt(1, 0), config)
			expect(math.abs((aimed.Position.Y - carried.Position.Y) - 1.0) < 1e-6).to.equal(true)
			-- Half way is half way: the three angles and the position blend numerically.
			local half = Mode.handOffsetAt("right", stateAt(1 - math.sqrt(0.5), 0), config)
			expect(math.abs((half.Position.Y - carried.Position.Y) - 0.5) < 1e-3).to.equal(true)
		end)

		it("a mid keyframe that names no hand leaves the plain blend alone", function()
			local data = Data.copy(Data.DATA)
			data.aim.left.pos.x = data.carry.left.pos.x + 1.0
			local plain = configWith(true, data)
			local framed = Data.copy(data)
			framed.raise.keyframes = {
				{ t = 0.5, gun = { pos = { x = 0, y = 0, z = -1 }, rot = { x = 0, y = 0, z = 0 } } },
			}
			local withFrame = configWith(true, framed)
			for _, blend in ipairs({ 0, 0.3, 1 - math.sqrt(0.5), 0.8, 1 }) do
				local state = stateAt(blend, 0)
				expect(
					(
						Mode.handOffsetAt("left", state, plain).Position
						- Mode.handOffsetAt("left", state, withFrame).Position
					).Magnitude < 1e-6
				).to.equal(true)
			end
		end)

		it("a mid keyframe that DOES name a hand puts it there", function()
			local data = Data.copy(Data.DATA)
			local hand = Data.copy(Data.DATA.carry.right)
			hand.pos.z = hand.pos.z + 2.0
			data.raise.keyframes = {
				{
					t = 0.5,
					gun = { pos = { x = 0, y = 0, z = -1 }, rot = { x = 0, y = 0, z = 0 } },
					right = hand,
				},
			}
			local config = configWith(true, data)
			local at = Mode.handOffsetAt("right", stateAt(1 - math.sqrt(0.5), 0), config)
			expect(math.abs(at.Position.Z - hand.pos.z) < 1e-3).to.equal(true)
		end)
	end)

	describe("the live override, resolved", function()
		local firstPerson = configWith(true)

		it("no override is the base table itself, not a copy", function()
			local resolved, hold, problems = Poses.resolve(firstPerson, nil)
			expect(resolved).to.equal(firstPerson)
			expect(hold).to.equal(nil)
			expect(#problems).to.equal(0)
			expect((Poses.resolve(firstPerson, ""))).to.equal(firstPerson)
		end)

		it("a good override changes the config the camera is handed", function()
			local resolved, hold, problems = Poses.resolve(firstPerson, '{"aim.cheekDeg": 9}')
			expect(#problems).to.equal(0)
			expect(hold).to.equal(nil)
			expect(resolved.ADS_CHEEK_DEG).to.equal(9)
			expect(resolved.FIRST_PERSON).to.equal(true) -- the flag is carried through untouched
			expect(table.isfrozen(resolved)).to.equal(true)
			-- ...and the aimed pose it builds is a different pose.
			local sight = CFrame.new(0, 0.12, -2.0)
			expect(Mode.aimOffset(sight, resolved)).never.to.equal(Mode.aimOffset(sight, firstPerson))
		end)

		it("tunes the viewmodel's own FILL LIGHT live, because the light was the defect", function()
			-- TASK 102, AND IT WAS MEASURED. Task 100 put the action at an albedo of (118, 120, 122)
			-- and the aimed capture still read the fences and top strap at (155, 161, 173) -- a pale
			-- blue-grey slab. What is pale is the LIGHT, inches from the lens, and it lived as four
			-- literals in `Camera.Config`, so moving it cost a commit, a gate and a review round.
			-- It is `look.fill` in poses.json now, which means it is one command and a look.
			local resolved, _, problems = Poses.resolve(firstPerson, '{"look.fill.brightness": 0.2}')
			expect(#problems).to.equal(0)
			expect(resolved.VIEWMODEL_FILL_BRIGHTNESS).to.equal(0.2)
			expect(resolved.VIEWMODEL_FILL_BRIGHTNESS).never.to.equal(firstPerson.VIEWMODEL_FILL_BRIGHTNESS)
			-- ...and the other three are still the file's, so one dial moves one thing.
			expect(resolved.VIEWMODEL_FILL_RANGE_STUDS).to.equal(firstPerson.VIEWMODEL_FILL_RANGE_STUDS)
			expect(resolved.VIEWMODEL_FILL_COLOR).to.equal(firstPerson.VIEWMODEL_FILL_COLOR)
			expect(resolved.VIEWMODEL_FILL_OFFSET_STUDS).to.equal(firstPerson.VIEWMODEL_FILL_OFFSET_STUDS)
		end)

		it("carries the fit tool's serial without treating it as a pose number", function()
			-- `tools/pose.py fit` bumps `serial` on every candidate it writes so it can tell a
			-- reading of the pose it just asked for from a reading of the one before it. It is not a
			-- pose number: if `merge` refused it, every candidate the search wrote would be refused
			-- WHOLE and the gun would never move.
			local resolved, _, problems = Poses.resolve(firstPerson, '{"aim.cheekDeg": 9, "serial": 41, "hold": "aim"}')
			expect(#problems).to.equal(0)
			expect(resolved.ADS_CHEEK_DEG).to.equal(9)
		end)

		it("refuses the WHOLE override when any path is wrong", function()
			local resolved, _, problems = Poses.resolve(firstPerson, '{"aim.cheekDeg": 9, "aim.nope": 1}')
			expect(#problems).to.equal(1)
			-- The good path is NOT applied: a half-applied override is a pose in no file and in no
			-- command, which is the one thing a tuning session must never show.
			expect(resolved).to.equal(firstPerson)
		end)

		it("survives anything that is not an override", function()
			for _, rubbish in ipairs({ "not json", "[1,2,3]", "null", '{"aim.cheekDeg": "high"}', "{" }) do
				local resolved, _, problems = Poses.resolve(firstPerson, rubbish)
				expect(resolved).to.equal(firstPerson)
				expect(#problems > 0).to.equal(true)
			end
		end)

		it("carries the hold through, and only the four that exist", function()
			local _, hold = Poses.resolve(firstPerson, '{"hold": "aim"}')
			expect(hold).to.equal("aim")
			local _, bad = Poses.resolve(firstPerson, '{"hold": "upside-down"}')
			expect(bad).to.equal(nil)
		end)
	end)

	describe("the held pose", function()
		it("forces the blend and the tilt for each of the four", function()
			local playing = stateAt(0.3, 0.2)
			expect(Poses.holdState(playing, nil)).to.equal(playing)
			local carry = Poses.holdState(playing, "carry")
			expect(carry.blend).to.equal(0)
			expect(carry.openTilt).to.equal(0)
			local aimed = Poses.holdState(playing, "aim")
			expect(aimed.blend).to.equal(1)
			expect(aimed.mode).to.equal("Aiming")
			expect(Poses.holdState(playing, "raise").blend).to.equal(0.5)
			local open = Poses.holdState(playing, "reload")
			expect(open.openTilt).to.equal(1)
			expect(open.blend).to.equal(0)
			expect(Poses.holdState(playing, "sideways")).to.equal(playing)
		end)

		it("never puts a viewmodel on screen while Loading or Dead", function()
			for _, mode in ipairs({ "Loading", "Dead" }) do
				local state = table.clone(stateAt(0, 0)) :: any
				state.mode = mode
				table.freeze(state)
				expect(Poses.holdState(state, "aim")).to.equal(state)
			end
		end)

		it("only the reload hold asks the viewmodel to draw an open gun", function()
			expect(Poses.holdReload(nil)).to.equal(nil)
			expect(Poses.holdReload("aim")).to.equal(nil)
			local drawn = Poses.holdReload("reload")
			expect(drawn).to.be.ok()
			expect((drawn :: any).open).to.equal(true)
			expect((drawn :: any).spent).to.equal(2)
			-- BOTH CHAMBERS FED, so the held frame shows shells seated in the bores rather than an
			-- empty open gun: the spent pair has finished ejecting long before a capture is taken.
			expect((drawn :: any).loaded[1]).to.equal(true)
			expect((drawn :: any).loaded[2]).to.equal(true)
		end)
	end)
end
