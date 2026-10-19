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
-- THE RIFLE'S RIGHT HAND (task 188) needs three things this file did not read before: where the gun
-- is held (`Rifle.Geometry`), where the hand holds (`HandAssets`), and the rifle's own pose set.
local Rifle = require(ReplicatedStorage:WaitForChild("Rifle"))
local RifleGeometry = require(ReplicatedStorage:WaitForChild("Rifle"):WaitForChild("Geometry"))
local HandAssets = require(ReplicatedStorage:WaitForChild("HandAssets"))
-- THE HORN'S OWN GEOMETRY (task 202): `TUBE_SAMPLES` is where the tube actually lies inside the
-- Handle, raycast off the real one, and it is what the drawn horn and its glove are measured against.
local Horn = require(ReplicatedStorage:WaitForChild("Horn"))
-- POSES.JSON IS VERSION 4 (task 140): every pose set lives under `weapons.<id>`, and this file is
-- about the SHOTGUN's, which is what it has always been about. One alias, so the cases below read
-- exactly as they did.
local SET = Data.DATA.weapons.shotgun

local scripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
local Camera = scripts:WaitForChild("Camera")
local Config = require(Camera:WaitForChild("Config"))
local Mode = require(Camera:WaitForChild("Mode"))
local Poses = require(Camera:WaitForChild("Poses"))

-- A config of each FIRST_PERSON branch, built here rather than read off the live one: the flag sits
-- at one of the two and both must stay reachable by parameter (docs/design/feature-flags.md 13.3).
local function configWith(firstPerson: boolean, data: any?)
	local out = table.clone(Config) :: any
	if data ~= nil then
		for key, value in pairs(Data.view(data)) do
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
			expect(table.isfrozen(SET.carry)).to.equal(true)
			expect(table.isfrozen(SET.carry.gun.pos)).to.equal(true)
			expect(function()
				(SET.carry.gun.pos :: any).x = 99
			end).to.throw()
		end)

		it("ships with no mid keyframes, which is the swing the camera has had since task 89", function()
			expect(#SET.raise.keyframes).to.equal(0)
		end)

		-- A RULE ABOUT THE GAME AND NOT A TASTE, so it is asserted rather than left to a comment: the
		-- DRAWN swing must finish before the server's own step ends, or the gun is caught half open
		-- when the shells arrive. Tuning `reload.openSeconds` past the server's break fails here.
		it("draws the break and the close faster than the server performs them", function()
			TestKit.note(
				string.format(
					"task98 break: drawn %.2f s vs server %.2f s; close drawn %.2f s vs server %.2f s",
					SET.reload.openSeconds,
					Shotgun.CONFIG.RELOAD_BREAK,
					SET.reload.closeSeconds,
					Shotgun.CONFIG.RELOAD_CLOSE
				)
			)
			expect(SET.reload.openSeconds < Shotgun.CONFIG.RELOAD_BREAK).to.equal(true)
			expect(SET.reload.closeSeconds < Shotgun.CONFIG.RELOAD_CLOSE).to.equal(true)
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
				data.weapons.shotgun.carry.gun.pos.y = nil
			end)).to.equal(1)
		end)

		-- THE PER-WEAPON SHAPE (task 140, the Reviewer's finding 2). Version 4 added three refusals
		-- and the first round shipped them reachable by nothing: a weapon set that is missing, one
		-- that carries BOTH actions, and one that carries neither. A weapon has ONE action -- a
		-- break-action opens (`reload`) and a bolt cycles (`cycle`) -- and a file with both is a file
		-- nobody can say which of them is drawn from.
		it("names a weapon set that is missing, and one that carries two actions or none", function()
			expect(#broken(function(data)
				data.weapons.rifle = nil
			end)).to.equal(1)
			local both = broken(function(data)
				data.weapons.rifle.reload = data.weapons.shotgun.reload
			end)
			expect(#both).to.equal(1)
			expect(string.find(both[1], "carries both reload and cycle") ~= nil).to.equal(true)
			local neither = broken(function(data)
				data.weapons.rifle.cycle = nil
			end)
			expect(#neither).to.equal(1)
			expect(string.find(neither[1], "carries neither reload nor cycle") ~= nil).to.equal(true)
			-- ...and the shotgun's own set is checked by the same rule, from the other side.
			local shotgunBoth = broken(function(data)
				data.weapons.shotgun.cycle = data.weapons.rifle.cycle
			end)
			expect(#shotgunBoth).to.equal(1)
		end)

		-- THE HORN'S BLOCK (task 176). KAREN, 2026-10-13: *"horn still hangign somewhere it has to be
		-- in hand"*, so the beater's horn is drawn in first person and its two poses are DATA in the
		-- content lane like every other pose in this file. It sits at the TOP LEVEL beside `look`,
		-- because a horn is not a weapon: it has no aim, no action and no shot, and every
		-- `weapons.<id>` is required to carry exactly one action by the case above.
		it("names a missing horn pose, and every half of one", function()
			local gone = broken(function(data)
				data.horn = nil
			end)
			expect(#gone).to.equal(1)
			expect(string.find(gone[1], "horn is missing") ~= nil).to.equal(true)
			local noBlow = broken(function(data)
				data.horn.blow = nil
			end)
			expect(#noBlow).to.equal(1)
			expect(string.find(noBlow[1], "horn.blow is missing") ~= nil).to.equal(true)
			-- HALF A POSE IS THE FAILURE THE CHECK EXISTS FOR: a missing number is a
			-- `CFrame.new(nil)`, which is a horn in a place nobody chose rather than an error
			-- anybody can trace.
			expect(#broken(function(data)
				data.horn.carry.item.pos.z = nil
			end)).to.equal(1)
			expect(#broken(function(data)
				data.horn.carry.item.rot.y = nil
			end)).to.equal(1)
			expect(#broken(function(data)
				data.horn.blow.right.rot.twist = nil
			end)).to.equal(1)
			expect(#broken(function(data)
				data.horn.blow.right = nil
			end)).to.equal(1)
		end)

		-- THE FIRST-PERSON CLONE'S SCALE (task 211) IS REFUSED THE SAME WAY, and for the same reason
		-- every other number in this block is: the two poses are SOLVED for a horn of that size, so
		-- a file that carries them without it -- or with a scale that is not a scale -- would draw
		-- the glove a horn's length away from the horn. The bound is (0, 1]: above 1 the first-person
		-- horn would be BIGGER than the one in the world, which is not a viewmodel scale.
		it("names a horn scale that is missing or is not a scale", function()
			local gone = broken(function(data)
				data.horn.scale = nil
			end)
			expect(#gone).to.equal(1)
			expect(string.find(gone[1], "horn.scale is missing") ~= nil).to.equal(true)
			for _, bad in ipairs({ 0, -0.5, 1.5 }) do
				local problems = broken(function(data)
					data.horn.scale = bad
				end)
				expect(#problems).to.equal(1)
				expect(string.find(problems[1], "horn.scale") ~= nil).to.equal(true)
			end
			-- ...AND A FILE WITHOUT IT PUBLISHES NO HORN, rather than one drawn at a size nobody
			-- chose -- exactly what half a pose already does.
			local without = Data.copy(Data.DATA)
			without.horn.scale = nil
			expect(Data.view(without).HORN).to.equal(nil)
		end)

		-- ...AND WHAT THE CAMERA IS HANDED IS TWO POSES AND NO TIMINGS (task 176). How long the raise,
		-- the hold and the lower take is `Horn.BLOW_POSE` and `Horn.CONFIG.BLOW_SECONDS` -- the same
		-- three numbers the SERVER plays the third-person arm with -- so a timing in this file would be
		-- a second source for a gesture that has to be one.
		it("publishes the horn's two poses as CFrames, and nothing about time", function()
			local view = Data.view(Data.DATA)
			expect(view.HORN).to.be.ok()
			expect(typeof(view.HORN.carry.item)).to.equal("CFrame")
			expect(typeof(view.HORN.carry.right)).to.equal("CFrame")
			expect(typeof(view.HORN.blow.item)).to.equal("CFrame")
			expect(typeof(view.HORN.blow.right)).to.equal("CFrame")
			-- THE TWO POSES ARE DIFFERENT PLACES, or the raise draws nothing at all.
			expect((view.HORN.carry.item.Position - view.HORN.blow.item.Position).Magnitude > 0.5).to.equal(true)
			-- THE POSITION IS THE FILE'S, read through the one conversion site rather than repeated
			-- here: `view` is the only thing in the repo that turns these three numbers into a Vector3.
			local pos = Data.DATA.horn.carry.item.pos
			expect((view.HORN.carry.item.Position - Vector3.new(pos.x, pos.y, pos.z)).Magnitude < 1e-6).to.equal(true)
			-- NO TIMING FIELD, under any name a tuner might reach for.
			for _, name in ipairs({ "raiseSeconds", "lowerSeconds", "seconds", "holdSeconds" }) do
				expect(Data.DATA.horn[name]).to.equal(nil)
				expect(Data.DATA.horn.carry[name]).to.equal(nil)
				expect(Data.DATA.horn.blow[name]).to.equal(nil)
			end
			-- A FILE WITHOUT THE BLOCK PUBLISHES NO HORN RATHER THAN A HORN FROM NOWHERE. `validate`
			-- is what refuses such a file (the case above); this is what the drawing side sees if one
			-- ever got past it -- nil, which it counts and draws nothing for.
			local without = Data.copy(Data.DATA)
			without.horn = nil
			expect(Data.view(without).HORN).to.equal(nil)
			local half = Data.copy(Data.DATA)
			half.horn.blow.item = nil
			expect(Data.view(half).HORN).to.equal(nil)
		end)

		-- ...AND THE DIRECTOR CAN TUNE IT LIVE, which is the whole point of a pose being data
		-- (CLAUDE.md, the content lane): `tools/pose.py set` validates a path against
		-- `Viewmodel.paths`, so a horn number that is not in it cannot be moved without a commit.
		it("lists the horn's numbers as tunable paths", function()
			local paths = Data.paths(Data.DATA)
			for _, path in ipairs({
				"horn.carry.item.pos.x",
				"horn.carry.item.rot.y",
				"horn.carry.right.pos.z",
				"horn.carry.right.rot.twist",
				"horn.blow.item.pos.y",
				"horn.blow.item.rot.x",
				"horn.blow.right.rot.pitch",
			}) do
				expect(paths[path]).to.be.a("number")
			end
			-- AND AN OVERRIDE OF ONE REACHES THE CAMERA'S CONFIG, through the same `merge` plus
			-- `view` the live attribute takes -- so "the Director moves a number and the horn moves"
			-- is asserted rather than hoped for.
			local merged = select(1, Data.merge(Data.DATA, { ["horn.blow.item.pos.y"] = 2.5 }))
			expect(Data.view(merged).HORN.blow.item.Position.Y).to.equal(2.5)
		end)

		-- ...AND THE VIEW ANSWERS FOR EITHER WEAPON, with the same flat names (task 140). A reader
		-- that got a nil for one gun and a number for the other is the shape version 3 existed to
		-- remove, and this is what stops it coming back.
		it("publishes one flat name set, whichever weapon is asked for", function()
			local shotgunView = Data.view(Data.DATA, "shotgun")
			local rifleView = Data.view(Data.DATA, "rifle")
			local missing = {}
			for key in pairs(shotgunView) do
				if rifleView[key] == nil then
					table.insert(missing, key)
				end
			end
			expect(#missing).to.equal(0)
			-- The default is the shotgun's, which is what `Camera.Config` publishes at boot, so
			-- every reader written before the rifle gets exactly what it got before.
			expect(Data.view(Data.DATA).CARRY_PITCH_DEG).to.equal(shotgunView.CARRY_PITCH_DEG)
			expect(rifleView.BOLT_LIFT_DEG).to.be.ok()
			expect(shotgunView.BOLT_LIFT_DEG).to.equal(nil)
		end)

		it("refuses an easing nobody implemented", function()
			local problems = broken(function(data)
				data.weapons.shotgun.raise.easing = "cubicInOut"
			end)
			expect(#problems).to.equal(1)
			expect(string.find(problems[1], "only quadOut is implemented") ~= nil).to.equal(true)
		end)

		-- THE VERSION IS THE SHAPE (task 114). Version 2 carried two pose sets and version 3 carries
		-- one; a version-2 file read by this code would be read as the RETIRED gun's poses, silently,
		-- which is the one failure a pose file must not have.
		it("refuses a file at the version that carried two guns", function()
			local problems = broken(function(data)
				data.version = 2
			end)
			expect(#problems).to.equal(1)
			expect(string.find(problems[1], "version must be 4") ~= nil).to.equal(true)
		end)

		-- THE LOADING MOVE IS CHECKED SINCE TASK 114. It was `newGun.reload.load` and only one of the
		-- two guns had one, so `view` handed `SHELL_LOAD` through as nil for the other and nothing
		-- about its shape could be asserted at all. One gun means the block is always there.
		it("names a missing piece of the left hand's loading move", function()
			expect(#broken(function(data)
				data.weapons.shotgun.reload.load = nil
			end)).to.equal(1)
			expect(#broken(function(data)
				data.weapons.shotgun.reload.load.fetchSeconds = 0
			end)).to.equal(1)
			expect(#broken(function(data)
				data.weapons.shotgun.reload.load.above.pos.y = nil
			end)).to.equal(1)
			expect(#broken(function(data)
				data.weapons.shotgun.reload.load.shellInHand.z = nil
			end)).to.equal(1)
		end)

		it("refuses a non-positive duration", function()
			expect(#broken(function(data)
				data.weapons.shotgun.raise.raiseSeconds = 0
			end)).to.equal(1)
			expect(#broken(function(data)
				data.weapons.shotgun.reload.openSeconds = -1
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
					data.weapons.shotgun.raise.keyframes = { one }
				end)
				expect(#problems).to.equal(1)
			end
			-- IN ORDER, which is the one a human gets wrong: two keyframes whose times go backwards
			-- would make the swing run backwards for a stretch.
			local first, second = Data.copy(frame), Data.copy(frame)
			first.t, second.t = 0.6, 0.3
			expect(#broken(function(data)
				data.weapons.shotgun.raise.keyframes = { first, second }
			end)).to.equal(1)
		end)

		it("accepts a keyframe in the middle, with or without hands", function()
			local frame = {
				t = 0.45,
				gun = { pos = { x = 0, y = 0, z = -1 }, rot = { x = 0, y = 0, z = 0 } },
			}
			expect(#broken(function(data)
				data.weapons.shotgun.raise.keyframes = { frame }
			end)).to.equal(0)
			local withHand = Data.copy(frame)
			withHand.right = Data.copy(SET.carry.right)
			expect(#broken(function(data)
				data.weapons.shotgun.raise.keyframes = { withHand }
			end)).to.equal(0)
			-- ...and a hand that IS named must be a whole hand.
			local halfHand = Data.copy(frame)
			halfHand.left = { pos = { x = 0, y = 0, z = 0 } }
			expect(#broken(function(data)
				data.weapons.shotgun.raise.keyframes = { halfHand }
			end) > 0).to.equal(true)
		end)
	end)

	describe("paths and merge", function()
		it("lists every pose number by dotted path, and no string or version", function()
			local paths = Data.paths(Data.DATA)
			for _, wanted in ipairs({
				"weapons.shotgun.carry.gun.pos.x",
				"weapons.shotgun.carry.gun.rot.y",
				"weapons.shotgun.carry.right.rot.twist",
				"weapons.shotgun.aim.eyeReliefStuds",
				"weapons.shotgun.aim.cheekDeg",
				"weapons.shotgun.raise.raiseSeconds",
				"weapons.shotgun.fire.gunPitchDeg",
				"weapons.shotgun.reload.openDeg",
				"weapons.shotgun.reload.shells.feedSeconds",
			}) do
				expect(paths[wanted]).to.be.ok()
			end
			expect(paths["version"]).to.equal(nil)
			expect(paths["weapons.shotgun.raise.easing"]).to.equal(nil)
			expect(paths["carry"]).to.equal(nil) -- a pose is not a number
		end)

		it("applies an override and moves nothing else", function()
			local merged, problems = Data.merge(Data.DATA, { ["weapons.shotgun.aim.cheekDeg"] = 7.5 })
			expect(#problems).to.equal(0)
			expect(merged.weapons.shotgun.aim.cheekDeg).to.equal(7.5)
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
			expect(SET.aim.cheekDeg).to.equal(before["weapons.shotgun.aim.cheekDeg"])
			expect(table.isfrozen(merged.weapons.shotgun.aim)).to.equal(true)
		end)

		it("refuses a path that is not a pose number, and keeps the data as it was", function()
			for _, bad in ipairs({
				{ ["weapons.shotgun.aim.cheeckDeg"] = 1 },
				{ ["aim"] = 1 },
				{ ["weapons.shotgun.raise.easing"] = 1 },
				{ ["version"] = 3 },
				{ ["weapons.shotgun.aim.cheekDeg"] = "4.2" },
				{ ["weapons.shotgun.aim.cheekDeg"] = true },
			}) do
				local merged, problems = Data.merge(Data.DATA, bad)
				expect(#problems).to.equal(1)
				expect(merged.weapons.shotgun.aim.cheekDeg).to.equal(SET.aim.cheekDeg)
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
			data.weapons.shotgun.raise.keyframes = {
				{ t = 0.5, gun = { pos = { x = 0, y = 0, z = -1 }, rot = { x = 0, y = 0, z = 0 } } },
			}
			expect(Data.paths(data)["weapons.shotgun.raise.keyframes.1.gun.pos.z"]).to.equal(-1)
			local merged, problems = Data.merge(data, { ["weapons.shotgun.raise.keyframes.1.gun.pos.z"] = -2 })
			expect(#problems).to.equal(0)
			expect(merged.weapons.shotgun.raise.keyframes[1].gun.pos.z).to.equal(-2)
		end)
	end)

	describe("the view Camera.Config publishes", function()
		-- THE WHOLE OF "ONE SOURCE". `Camera.Config` does not define these numbers any more; it
		-- computes them from the data. If the two ever disagreed, there would be two sources again.
		it("is what the live Config carries", function()
			for key, value in pairs(Data.view(Data.DATA)) do
				if typeof(value) == "number" or typeof(value) == "Vector3" then
					expect(Config[key]).to.equal(value)
				end
			end
			-- `POSES` IS A VIEW, not the whole file: the three poses that are about the gun, plus the
			-- swing and the shot. The fields are references into the data, so this is still one
			-- source. Until task 114 it carried whichever of TWO sets the gun flag chose.
			expect(Config.POSES.carry).to.equal(SET.carry)
			expect(Config.POSES.aim).to.equal(SET.aim)
			expect(Config.POSES.reload).to.equal(SET.reload)
			expect(Config.POSES.raise).to.equal(SET.raise)
			expect(Config.POSES.fire).to.equal(SET.fire)
		end)

		-- ONE GUN, ONE POSE SET (task 114). `view` took a `newGun` boolean while the flag chose
		-- between two; the file carries one now, so what has to be asserted is that there is NO
		-- second set left for anything to resolve -- a `newGun` key in the data would mean the
		-- retired gun's numbers were still shipping, unread, beside the ones Karen tuned.
		it("reads one pose set, and poses.json carries no second one", function()
			local view = Data.view(Data.DATA)
			expect(Data.DATA.newGun).to.equal(nil)
			expect(view.POSES.carry).to.equal(SET.carry)
			expect(view.POSES.aim).to.equal(SET.aim)
			expect(view.POSES.reload).to.equal(SET.reload)
			-- The swing's timings and the shot's spring are read off the same one place too, so
			-- there is nothing for a second set to have been read from.
			expect(view.POSES.raise).to.equal(SET.raise)
			expect(view.RECOIL_GUN_PITCH_DEG).to.equal(SET.fire.gunPitchDeg)
			expect(view.AIM_RAISE_SECONDS).to.equal(SET.raise.raiseSeconds)
			-- THE SHOT'S COSMETICS COME THROUGH WHOLE (task 112): the flash, the smoke and the three
			-- volumes are shapes rather than numbers, and only the gun that survived ever had them.
			expect(view.FIRE).to.equal(SET.fire)
			expect(view.FIRE.flash).to.be.ok()
			expect(view.FIRE.smoke).to.be.ok()
			expect(view.FIRE.volume).to.be.ok()
			-- ...and so does the left hand's loading move, which was the other half of what only one
			-- gun had (task 111).
			expect(view.SHELL_LOAD).to.equal(SET.reload.load)
		end)

		it("follows the data when the data changes", function()
			local data = Data.copy(Data.DATA)
			data.weapons.shotgun.carry.gun.rot.y = 12.5
			data.weapons.shotgun.aim.eyeReliefStuds = 5.0
			local view = Data.view(data)
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
			data.weapons.shotgun.raise.keyframes = { { t = 0.5, gun = mid } }
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
			data.weapons.shotgun.raise.keyframes = {
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
			data.weapons.shotgun.raise.keyframes = {
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

		-- WHAT THIS CASE USED TO SAY, AND WHY IT HAD TO CHANGE (task 114). It asserted that the shipped
		-- file seeds every pose's hands the SAME, so `handOffsetAt` answered the carry hand at every
		-- blend and every tilt. That was a fact about the RETIRED gun's pose set -- task 98 seeded its
		-- three poses identical so that task changed no pixel -- and it kept passing only because the
		-- flag made `Camera.Config` read that set during a harness run. Karen then posed model B's
		-- hands by eye (`pose.py edit`, tasks 108 and 109) and her three poses are genuinely
		-- different: the right hand sits further forward during the reload than at the carry, and the
		-- aimed left hand is further down the barrels than the carried one.
		--
		-- SO THE CLAIM IS THE ONE THAT WAS ALWAYS UNDERNEATH IT: the blend's ENDS are the poses
		-- themselves. Each pose's own state must give back exactly that pose's own numbers, through
		-- the one conversion site -- which is what makes `poses.json` the single source and cannot be
		-- satisfied by a file that seeds them all alike.
		it("answers each pose's own numbers at that pose's own state", function()
			local states = {
				{ pose = "carry", state = stateAt(0, 0) },
				{ pose = "aim", state = stateAt(1, 0) },
				{ pose = "reload", state = stateAt(0, 1) },
			}
			for _, case in ipairs(states) do
				for _, side in ipairs({ "right", "left" }) do
					local entry = SET[case.pose][side]
					local wanted = Mode.handOffset(Data.vec(entry.pos), entry.rot.yaw, entry.rot.pitch, entry.rot.twist)
					expect(Mode.handOffsetAt(side, case.state, firstPerson)).to.equal(wanted)
				end
			end
			-- ...AND THEY ARE REALLY THREE POSES, not one written three times. Without this the case
			-- above would pass just as well for a file that seeded them identical -- which is exactly
			-- the state it used to assert, and what made it stop measuring anything.
			local carriedRight = Mode.handOffsetAt("right", stateAt(0, 0), firstPerson)
			local aimedRight = Mode.handOffsetAt("right", stateAt(1, 0), firstPerson)
			local carriedLeft = Mode.handOffsetAt("left", stateAt(0, 0), firstPerson)
			local aimedLeft = Mode.handOffsetAt("left", stateAt(1, 0), firstPerson)
			TestKit.note(
				string.format(
					"task114 the aim moves the right hand %.3f studs and the left %.3f from the carry",
					(aimedRight.Position - carriedRight.Position).Magnitude,
					(aimedLeft.Position - carriedLeft.Position).Magnitude
				)
			)
			expect(aimedRight).never.to.equal(carriedRight)
			expect(aimedLeft).never.to.equal(carriedLeft)
			-- The carry end is still bit-for-bit `rightHandOffset`, which is the half of the old case
			-- that was about the ARITHMETIC rather than about the file (see the case above it).
			expect(carriedRight).to.equal(Mode.rightHandOffset(firstPerson))
			expect(carriedLeft).to.equal(Mode.leftHandOffset(firstPerson))
		end)

		it("moves a hand when its own pose says a different thing", function()
			local data = Data.copy(Data.DATA)
			data.weapons.shotgun.aim.right.pos.y = data.weapons.shotgun.carry.right.pos.y + 1.0
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
			data.weapons.shotgun.aim.left.pos.x = data.weapons.shotgun.carry.left.pos.x + 1.0
			local plain = configWith(true, data)
			local framed = Data.copy(data)
			framed.weapons.shotgun.raise.keyframes = {
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
			local hand = Data.copy(SET.carry.right)
			hand.pos.z = hand.pos.z + 2.0
			data.weapons.shotgun.raise.keyframes = {
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
			-- ...BUT A SECOND WEAPON WITH NO OVERRIDE IS NOT `base` (task 140, design 13.1): this is
			-- the branch a PUBLISHED server takes for the rifle, where there is no attribute to
			-- read, and it must recompute the flat names from that weapon's own set.
			local rifle, rifleHold, rifleProblems = Poses.resolve(firstPerson, nil, "rifle")
			expect(#rifleProblems).to.equal(0)
			expect(rifleHold).to.equal(nil)
			expect(rifle).never.to.equal(firstPerson)
			-- BY VALUE FOR THE NUMBERS AND BY PRESENCE FOR THE REST: `Data.view` builds its
			-- table-valued names (the Vector-shaped ones) fresh on every call, so identity is the
			-- wrong question for those and the right one for every scalar.
			local expected = Data.view(Data.DATA, "rifle")
			local shotgunView = Data.view(Data.DATA, "shotgun")
			local compared, differed = 0, 0
			for key, value in pairs(expected) do
				if type(value) == "table" then
					expect(rifle[key]).to.be.ok()
				else
					expect(rifle[key]).to.equal(value)
					compared += 1
					if shotgunView[key] ~= value then
						differed += 1
					end
				end
			end
			expect(compared > 0).to.equal(true)
			-- ...AND THEY ARE THE RIFLE'S OWN NUMBERS, not the shotgun's handed back under a new
			-- name: at least one scalar must differ, or this branch proved nothing.
			expect(differed > 0).to.equal(true)
			expect(rifle.FIRST_PERSON).to.equal(firstPerson.FIRST_PERSON)
			-- ...and naming the default weapon explicitly is the same answer as naming none.
			expect((Poses.resolve(firstPerson, nil, Data.DEFAULT_WEAPON))).to.equal(firstPerson)
		end)

		it("a good override changes the config the camera is handed", function()
			local resolved, hold, problems = Poses.resolve(firstPerson, '{"weapons.shotgun.aim.cheekDeg": 9}')
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
			local resolved, _, problems =
				Poses.resolve(firstPerson, '{"weapons.shotgun.aim.cheekDeg": 9, "serial": 41, "hold": "aim"}')
			expect(#problems).to.equal(0)
			expect(resolved.ADS_CHEEK_DEG).to.equal(9)
		end)

		it("refuses the WHOLE override when any path is wrong", function()
			local resolved, _, problems =
				Poses.resolve(firstPerson, '{"weapons.shotgun.aim.cheekDeg": 9, "weapons.shotgun.aim.nope": 1}')
			expect(#problems).to.equal(1)
			-- The good path is NOT applied: a half-applied override is a pose in no file and in no
			-- command, which is the one thing a tuning session must never show.
			expect(resolved).to.equal(firstPerson)
		end)

		it("survives anything that is not an override", function()
			for _, rubbish in ipairs({ "not json", "[1,2,3]", "null", '{"weapons.shotgun.aim.cheekDeg": "high"}', "{" }) do
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

	-- THE RIFLE'S RIGHT HAND (task 188). Karen, 2026-10-15: *"rifle is ok now / we need to improve
	-- right hand now seems odd it has to be aligned perfectly"*, and asked where: *"Bolt pull,
	-- Holding (hip)"*.
	--
	-- WHAT THESE CASES ARE FOR. Until this task nothing in the repo said where the rifle was HELD, so
	-- the right hand's poses could not be wrong -- there was nothing to be wrong about. They were in
	-- fact the SHOTGUN's six numbers, on a gun whose grip is a fifth of a stud away, and the hand
	-- hung under the trigger guard with the wrist of the stock above it. Both ends are measured now
	-- (`Rifle.Geometry.gripOffset` / `boltKnobOffset`, `HandAssets.GRIP_STUDS`) and these cases are
	-- what holds the pose file to them: a `poses.json` that puts the hand off the grip or off the
	-- knob fails the harness, which blocks the merge gate, exactly as a bad `expires` date does.
	--
	-- THE TOLERANCE IS THE HAND'S OWN GAP, not a number somebody liked: `GRIP_RADIUS_STUDS` is half
	-- the hole the fist closes around, so a grip point that far off still has the wood -- or the
	-- knob -- inside the hand.
	describe("the rifle's right hand, against the gun's own grip and bolt knob", function()
		local rifleView = Data.view(Data.DATA, "rifle")
		local rifleConfig = (function()
			local out = table.clone(Config) :: any
			for key, value in pairs(rifleView) do
				out[key] = value
			end
			out.FIRST_PERSON = true
			return table.freeze(out)
		end)()
		-- TWO TOLERANCES, AND EACH MEANS A DIFFERENT THING. The WRIST is a column the hand can slide
		-- a little way along and still be holding: what has to be true is that the grip point is
		-- inside the WOOD, so the bound is half the wrist's own narrowest width. The KNOB is a ball
		-- the fist closes on: what has to be true is that it is inside the HAND, so the bound there
		-- is half the hand's own gap. Neither is a number somebody liked.
		local WRIST_TOLERANCE = RifleGeometry.gripRadius(Rifle.CONFIG)
		local KNOB_TOLERANCE = HandAssets.GRIP_RADIUS_STUDS
		local function gripPointOf(offset: CFrame): Vector3
			return offset:PointToWorldSpace(HandAssets.GRIP_STUDS)
		end

		it("holds the wrist of the stock at the hip, aimed, and when the cycle starts", function()
			-- The three states the right hand can be in before it leaves for the bolt. `handOffsetAt`
			-- is the one conversion site, so these are the CFrames the viewmodel really draws with.
			for _, case in ipairs({
				{ name = "hip", state = stateAt(0, 0) },
				{ name = "aimed", state = stateAt(1, 0) },
				{ name = "cycle", state = stateAt(0, 1) },
			}) do
				local offset = Mode.handOffsetAt("right", case.state, rifleConfig)
				local at = gripPointOf(offset)
				local off = RifleGeometry.offGripAxis(Rifle.CONFIG, at)
				-- ...AND HOW FAR ALONG IT, which is the half of this that round 1 of this task got
				-- wrong: a pose 0.045 off the axis and 0.158 ALONG it is a hand on the COMB, and an
				-- off-axis bound on its own passed it. See `GRIP_HALF_LENGTH`.
				local along = RifleGeometry.alongGripAxis(Rifle.CONFIG, at)
				TestKit.note(
					string.format("rifle right hand %s: %.4f off the wrist axis, %+.4f along it", case.name, off, along)
				)
				expect(off < WRIST_TOLERANCE).to.equal(true)
				expect(math.abs(along) < RifleGeometry.gripHalfLength(Rifle.CONFIG)).to.equal(true)
			end
		end)

		it("reads its three angles the way `Mode.handOffset` composes them", function()
			-- THE DEFECT OF ROUND 1, WRITTEN DOWN. The carry/aim/cycle hands go through
			-- `Mode.handOffset`, which is yaw, THEN pitch, THEN twist about the hand's OWN long axis --
			-- and NOT `CFrame.Angles(pitch, yaw, twist)`, which is what every other hand block in
			-- `poses.json` is built with (`BOLT_HAND.grip`, `MAGAZINE_SWAP.hand`, the horn's two).
			-- Two conventions in one file, and a pose solved in the wrong one lands somewhere nobody
			-- chose: the first numbers this task shipped put the hand on the comb, 0.158 studs behind
			-- the wrist, and the live session is what caught it. Nothing can make the two conventions
			-- the same; what this case does is say which one this pose is in.
			local set = Data.DATA.weapons.rifle.carry.right
			local pos = Vector3.new(set.pos.x, set.pos.y, set.pos.z)
			local built = Mode.handOffset(pos, set.rot.yaw, set.rot.pitch, set.rot.twist)
			local byHand = CFrame.new(pos)
				* CFrame.Angles(0, math.rad(set.rot.yaw), 0)
				* CFrame.Angles(0, 0, math.rad(set.rot.pitch))
				* CFrame.fromAxisAngle(Vector3.xAxis, math.rad(set.rot.twist))
			expect(built.RightVector:Dot(byHand.RightVector) > 1 - 1e-6).to.equal(true)
			-- ...and it is NOT the other convention, which is the whole point of the case.
			local other = CFrame.new(pos)
				* CFrame.Angles(math.rad(set.rot.pitch), math.rad(set.rot.yaw), math.rad(set.rot.twist))
			expect(built.RightVector:Dot(other.RightVector) < 0.99).to.equal(true)
			-- And the hand this file draws is the first one.
			local drawn = Mode.handOffsetAt("right", stateAt(0, 0), rifleConfig)
			expect((drawn.Position - built.Position).Magnitude < 1e-6).to.equal(true)
			expect(drawn.RightVector:Dot(built.RightVector) > 1 - 1e-6).to.equal(true)
		end)

		it("does not move between the hip and the aim: one hand, one grip", function()
			-- A right hand that changed place when the eye went to the scope would read as the gun
			-- being re-gripped every time Karen aims. It is the SAME grip in both, so it is the same
			-- six numbers, and this is what says so.
			local hip = Mode.handOffsetAt("right", stateAt(0, 0), rifleConfig)
			local aimed = Mode.handOffsetAt("right", stateAt(1, 0), rifleConfig)
			expect((hip.Position - aimed.Position).Magnitude < 1e-6).to.equal(true)
		end)

		it("pinches the bolt knob, and keeps pinching it wherever the bolt has got to", function()
			local grip = rifleConfig.BOLT_HAND.grip
			local knob = RifleGeometry.boltKnobOffset(Rifle.CONFIG)
			local miss = (gripPointOf(grip) - knob).Magnitude
			TestKit.note(string.format("rifle bolt hand: %.4f studs from the knob's centre", miss))
			expect(miss < KNOB_TOLERANCE).to.equal(true)
			-- ...AND IT CANNOT COME OFF IT. `Camera.Viewmodel.poseHands` places this hand from the
			-- SAME transform the bolt is drawn with (`Viewmodel.hinge`'s return), so the miss is
			-- invariant under any rigid motion of the bolt -- which is the whole reason the hand is
			-- placed that way rather than from a second clock. Driven with an arbitrary one here,
			-- because the property is about the composition and not about any particular frame.
			local carried = CFrame.new(0.31, -0.17, 0.44) * CFrame.Angles(0.3, -1.1, 0.7)
			local movedMiss = (gripPointOf(carried * grip) - carried:PointToWorldSpace(knob)).Magnitude
			expect(math.abs(movedMiss - miss) < 1e-5).to.equal(true)
		end)

		-- WHICH END OF THE HAND IS DOING THE HOLDING (task 189). Karen, 2026-10-15, after playing
		-- task 188: *"hadn is oposit now reload with ending of arm not fingers"*.
		--
		-- THE CASE TASK 188 COULD NOT HAVE FAILED. Its only landmark on the glove was the grip point,
		-- and a grip point is exactly as far from the knob whichever way round the hand is -- so a
		-- hand drawn end-for-end passed every bound in this file twice. `HandAssets.FINGERTIP_STUDS`
		-- and `CUFF_STUDS` are the two ends, measured, and these two cases ask the question that
		-- needed asking: is the FIST on the knob, and does the WRIST trail back toward the shooter?
		--
		-- (What was actually wrong was `HandAssets.AXES.RIGHT.fingers`: measured off the source glTF,
		-- and the drawn MeshPart is a HALF TURN ABOUT Y against that file -- task 189 believed a
		-- mirror and task 190 measured the rotation -- so `align`'s +X pointed at the cuff. Every
		-- pose solved in that frame came out backwards. Both signs are measured in the RUNNING game
		-- now -- see that file -- and these cases are what hold the pose against them.)
		--
		-- WHAT THESE TWO CASES CAN AND CANNOT FAIL ON, said plainly so the next task does not trust
		-- them for more than they hold. The landmarks are constants IN THE ALIGNED FRAME, where the
		-- fingertip is at +X by construction -- so what is held here is the POSE against the
		-- landmarks, which is what a mis-solved pose gets wrong. The mesh-to-aligned sign itself --
		-- `HandAssets.AXES` -- is held by the marker-ball screenshots in the running game and by
		-- nothing in this file, because Luau cannot read a vertex of a MeshPart.
		local HALF_HAND = (HandAssets.FINGERTIP_STUDS - HandAssets.CUFF_STUDS).Magnitude / 2

		it("holds the knob with the FINGERS, and the wrist trails back toward the shooter", function()
			local knob = RifleGeometry.boltKnobOffset(Rifle.CONFIG)
			local grip = rifleConfig.BOLT_HAND.grip
			local fingertip = grip:PointToWorldSpace(HandAssets.FINGERTIP_STUDS)
			local cuff = grip:PointToWorldSpace(HandAssets.CUFF_STUDS)
			TestKit.note(
				string.format(
					"rifle bolt hand: fingertip %.3f from the knob, cuff %.3f, cuff %.3f studs behind it in Z",
					(fingertip - knob).Magnitude,
					(cuff - knob).Magnitude,
					cuff.Z - fingertip.Z
				)
			)
			-- The fist end is the near end. This is what fails on a hand that is round the wrong way.
			expect((fingertip - knob).Magnitude < (cuff - knob).Magnitude).to.equal(true)
			-- ...AND THE ARM RUNS BACK ALONG THE GUN, not across it. +Z is toward the butt (the muzzle
			-- is at -Z), so the cuff must be behind the fingertip by more than half the glove's own
			-- length -- which is only true if the hand lies along the rifle the way a forearm does.
			-- Task 188's pose stood the hand vertically on the receiver: 0.18 studs, and it failed
			-- this.
			expect(cuff.Z - fingertip.Z > HALF_HAND).to.equal(true)

			-- EVERY FRAME OF THE CYCLE, not just this one. The bolt's lift is a turn about the gun's
			-- Z (`Geometry.boltLift`) and its draw is a slide along Z, and the hand is placed from
			-- that same transform -- so neither moves the cuff's Z relative to the fingertip's by more
			-- than the lift's own arc. Driven here at four turns, which is the property stated rather
			-- than assumed.
			for _, turn in ipairs({ 0, 0.35, 0.7, 1 }) do
				local carried = RifleGeometry.boltLift(Rifle.CONFIG, rifleConfig.BOLT_LIFT_DEG, turn)
				local at = carried * grip
				local tip = at:PointToWorldSpace(HandAssets.FINGERTIP_STUDS)
				local back = at:PointToWorldSpace(HandAssets.CUFF_STUDS)
				local lifted = carried:PointToWorldSpace(knob)
				expect((tip - lifted).Magnitude < (back - lifted).Magnitude).to.equal(true)
				expect(back.Z - tip.Z > HALF_HAND).to.equal(true)
			end
		end)

		it("holds the stock the same way at the hip and aimed: fist forward, wrist back", function()
			local wrist = RifleGeometry.gripOffset(Rifle.CONFIG)
			for _, case in ipairs({
				{ name = "hip", state = stateAt(0, 0) },
				{ name = "aimed", state = stateAt(1, 0) },
				{ name = "cycle", state = stateAt(0, 1) },
			}) do
				local offset = Mode.handOffsetAt("right", case.state, rifleConfig)
				local fingertip = offset:PointToWorldSpace(HandAssets.FINGERTIP_STUDS)
				local cuff = offset:PointToWorldSpace(HandAssets.CUFF_STUDS)
				TestKit.note(
					string.format(
						"rifle right hand %s: fingertip %.3f from the wrist of the stock, cuff %.3f, trail %.3f",
						case.name,
						(fingertip - wrist).Magnitude,
						(cuff - wrist).Magnitude,
						cuff.Z - fingertip.Z
					)
				)
				expect((fingertip - wrist).Magnitude < (cuff - wrist).Magnitude).to.equal(true)
				expect(cuff.Z - fingertip.Z > HALF_HAND).to.equal(true)
			end
		end)

		-- WHICH WAY THE HAND IS ROLLED (task 190). Karen, 2026-10-15, after playing task 189:
		-- *"now right hand reload with outside of fingersit has to palm inside now is outside fix
		-- that"* -- the fist was the right way round and the BACK of it was on the knob.
		--
		-- THE CASE THE TWO ABOVE COULD NOT BE. Both landmarks lie within a tenth of a stud of the
		-- fingers axis, so a 180 degree roll about that axis barely moves either: the hand was
		-- inside out and every bound in this file passed. The palm is the axis the roll turns, and
		-- `align` is DEFINED to put it on +Y -- so the drawn palm IS `offset.UpVector`, and what
		-- this asks is where that points.
		--
		-- WHAT IT HOLDS AND WHAT IT DOES NOT, plainly. It holds the POSE: a pose rolled a half turn
		-- fails it. It does NOT hold `HandAssets.AXES` -- `align` puts the palm on +Y whatever that
		-- table says, so a wrong table moves the glove and not this number. The table is held by the
		-- marker-ball photographs in the running game (`HandAssets.AXES`'s comment) and, for the
		-- handedness the task turns on, by `gun.spec`'s "the right glove's own thumb".
		--
		-- WHAT THESE TWO CASES COST TODAY, SAID PLAINLY (Reviewer, round 2). The rifle's three
		-- `right` blocks in `poses.json` are byte-identical and the bolt dot is invariant under the
		-- lift (see below), so the three states below and the four turns above are FOUR AND THREE
		-- COPIES OF ONE ASSERTION EACH. They are written as loops because the states and the turns
		-- are what a future pose file will differ across, not because they differ now.
		--
		-- THE REFERENCE IS THE BOLT'S OWN AXIS, NOT THE KNOB, and the difference matters. A closed
		-- fist's palm normal is the axis of the HOLE the fist makes, and the knob sits IN that hole
		-- (`GRIP_STUDS` is at aligned Y = 0, the middle of the hand) -- so "palm toward the knob" is
		-- near 90 degrees whichever way round the hand is, and says nothing. What a hunter's hand
		-- really does is face the RECEIVER: the palm points in at the line the bolt turns about.
		-- Measured in the running game on the drawn parts, before and after task 190: 111.0-117.9
		-- degrees, then 73.3-80.3. The sign is the whole of it.
		it("turns the PALM onto the bolt, not the knuckles (task 190)", function()
			local axisY = RifleGeometry.boltAxis(Rifle.CONFIG).Y
			local grip = rifleConfig.BOLT_HAND.grip
			for _, turn in ipairs({ 0, 0.35, 0.7, 1 }) do
				local at = RifleGeometry.boltLift(Rifle.CONFIG, rifleConfig.BOLT_LIFT_DEG, turn) * grip
				local hand = at.Position
				-- The nearest point of the line the bolt turns about: it runs ALONG the gun through
				-- (0, axisY, *), so the nearest point to the hand shares the hand's own Z.
				local inward = (Vector3.new(0, axisY, hand.Z) - hand)
				local toward = at.UpVector:Dot(inward.Unit)
				TestKit.note(string.format("task190 bolt hand at turn %.2f: palm . inward %.4f", turn, toward))
				expect(toward > 0).to.equal(true)
			end
		end)

		it("...and onto the wood at the hip and aimed, the same way", function()
			-- The same question of the hand that holds the stock: Karen asked for the hip grip to be
			-- checked too (*"palm on the wood, knuckles out"*). The reference here is the wrist of
			-- the stock itself, which is the thing the fingers close on.
			local wrist = RifleGeometry.gripOffset(Rifle.CONFIG)
			for _, case in ipairs({
				{ name = "hip", state = stateAt(0, 0) },
				{ name = "aimed", state = stateAt(1, 0) },
				{ name = "cycle", state = stateAt(0, 1) },
			}) do
				local offset = Mode.handOffsetAt("right", case.state, rifleConfig)
				local inward = wrist - offset.Position
				local toward = offset.UpVector:Dot(inward.Unit)
				TestKit.note(string.format("task190 %s hand: palm . toward the wrist %.4f", case.name, toward))
				expect(toward > 0).to.equal(true)
			end
		end)

		it("lifts the bolt handle UP and clear, not down into the receiver", function()
			-- THE SIGN (task 188). The knob hangs 0.067 studs BELOW the line it turns about, so the
			-- direction of the turn decides whether the handle rises on the right or sweeps down
			-- through the wood. It used to sweep down: at a full lift the knob landed at x -0.014,
			-- left of the gun's centre line and inside the stock, and the hand went with it.
			local knob = RifleGeometry.boltKnobOffset(Rifle.CONFIG)
			local axisY = RifleGeometry.boltAxis(Rifle.CONFIG).Y
			expect(knob.Y < axisY).to.equal(true) -- a CLOSED handle hangs below the axis
			local lifted = RifleGeometry.boltLift(Rifle.CONFIG, rifleConfig.BOLT_LIFT_DEG, 1):PointToWorldSpace(knob)
			TestKit.note(
				string.format(
					"bolt knob: closed (%.4f, %.4f) -> lifted (%.4f, %.4f), axis Y %.4f",
					knob.X,
					knob.Y,
					lifted.X,
					lifted.Y,
					axisY
				)
			)
			expect(lifted.Y > axisY).to.equal(true) -- lifted, it is above it
			expect(lifted.X > knob.X).to.equal(true) -- and further out on the RIGHT, not across
			-- At rest it is exactly where it was: nothing moves until the cycle does.
			expect(
				(RifleGeometry.boltLift(Rifle.CONFIG, rifleConfig.BOLT_LIFT_DEG, 0):PointToWorldSpace(knob) - knob).Magnitude
					< 1e-6
			).to.equal(true)
			-- A turn outside 0..1 is clamped rather than trusted (the handle would otherwise be
			-- driven past the top and back down into the wood from the other side).
			local past = RifleGeometry.boltLift(Rifle.CONFIG, rifleConfig.BOLT_LIFT_DEG, 2.5):PointToWorldSpace(knob)
			expect((past - lifted).Magnitude < 1e-6).to.equal(true)
		end)
	end)

	-- THE FIVE RIGHT HANDS THIS TASK DID NOT RE-SOLVE, PINNED WHERE THEY WERE (task 189, round 2 --
	-- the Reviewer's finding 1, and it was right).
	--
	-- Flipping `HandAssets.AXES.RIGHT` changes what EVERY right-hand pose means, not just the
	-- rifle's: `Camera.Viewmodel.poseHands` draws the right glove as `base * align` for whatever
	-- weapon is in hand, and the horn branch does the same. The rifle's four poses were re-solved
	-- because Karen said they were wrong. The shotgun's three and the horn's two are hands she has
	-- already accepted, so they were RE-EXPRESSED instead -- `pose_new = pose_old * (align_old *
	-- align_new^-1)` -- which leaves what is drawn identical to 2e-16, and the arithmetic is in the
	-- note (section 3a).
	--
	-- THIS IS WHAT SAYS SO. The numbers below are where those five hands put the glove's two ends,
	-- in the gun's own frame, measured off the poses task 188 shipped and composed with the
	-- alignment task 188 drew with. They are an outside constant: they come from the build Karen
	-- played, not from the file this case reads. Flip the axis again without re-expressing these
	-- five and every one of them moves about 150 degrees, which is what this fails on.
	--
	-- THEY MOVED IN TASK 190 AND THE HANDS DID NOT, which is worth being exact about. These are
	-- `offset:PointToWorldSpace(landmark)`, and the LANDMARK is a constant in the aligned frame --
	-- so the point this case reads moves when either the POSE or the LANDMARK changes. Task 190 put
	-- `FINGERTIP_STUDS`'s and `CUFF_STUDS`'s Z back to task 188's sign (the import is a rotation,
	-- not a mirror, so no aligned coordinate ever moved; `HandAssets` has the measurement), which
	-- shifts every number below. BY EXACTLY TWO AMOUNTS, which is the check: the transport is one
	-- 170.2 degree roll about the fingers axis, so every fingertip below moves 0.0901 studs and
	-- every cuff 0.0468 -- the same two numbers for the shotgun's carry, the shotgun's aim and the
	-- horn, because it is one rotation applied to one pair of landmarks. (0.063 is the LANDMARK's
	-- own displacement, 2 x 0.0315, which is not what these points move by.)
	-- The DRAWN hands are untouched: the transport
	-- reproduces each of the five to 6e-16, and `camera_mode.spec`'s "the two hands are posed
	-- differently" measures the drawn rotations and reads the same 152.1 degrees either side of
	-- this task. So what changed is the yardstick, not the hand.
	--
	-- AND THE HORN'S TWO ANGLES ARE NOT READ IN THIS ORDER. `Viewmodel.hornPose` builds its right
	-- hand as `CFrame.Angles(pitch, yaw, twist)` -- Rx*Ry*Rz -- while `Mode.handOffset` builds the
	-- gun's as `Ry(yaw)*Rz(pitch)*Rx(twist)`. A transport computed in the wrong one of those moves
	-- the drawn horn hand 58.3 degrees, which is exactly what the horn case below caught in task
	-- 190's first gate run.
	describe("the shotgun's and the horn's right hand did not move (task 189)", function()
		local shotgunConfig = configWith(true, Data.DATA)
		local hornPoses = Data.view(Data.DATA).HORN
		local TOLERANCE = 0.002 -- the poses are written to four decimals, so this is round-off only

		local function ends(offset: CFrame): (Vector3, Vector3)
			return offset:PointToWorldSpace(HandAssets.FINGERTIP_STUDS), offset:PointToWorldSpace(HandAssets.CUFF_STUDS)
		end

		it("the shotgun's carry and aimed hands are where task 188 drew them", function()
			for _, case in ipairs({
				{
					name = "carry",
					state = stateAt(0, 0),
					tip = Vector3.new(-0.1007, 0.0658, 0.7872),
					cuff = Vector3.new(0.0605, -0.4124, 1.2124),
				},
				{
					name = "aimed",
					state = stateAt(1, 0),
					tip = Vector3.new(0.2634, -0.2751, 1.3048),
					cuff = Vector3.new(-0.2148, -0.1139, 0.8796),
				},
			}) do
				local tip, cuff = ends(Mode.handOffsetAt("right", case.state, shotgunConfig))
				TestKit.note(
					string.format(
						"task189 shotgun %s right hand: fingertip (%.4f, %.4f, %.4f), cuff (%.4f, %.4f, %.4f)",
						case.name,
						tip.X,
						tip.Y,
						tip.Z,
						cuff.X,
						cuff.Y,
						cuff.Z
					)
				)
				expect((tip - case.tip).Magnitude < TOLERANCE).to.equal(true)
				expect((cuff - case.cuff).Magnitude < TOLERANCE).to.equal(true)
			end
		end)

		it("the horn's hand is where task 212 solved it", function()
			-- SINCE TASK 212 THE TWO POSES SHARE EVERY NUMBER, which is why both rows below are the
			-- same pair of points. The Designer's spec asks for it in so many words
			-- (`driven-hunt-runs/design/horngrip-spec.md` section 4): *"The grip never changes. Same
			-- point on the horn, same hand, in carry, in blow, and through the walk sway. If the
			-- hand slides along the tube between poses, the horn stops being held and starts being
			-- followed."* `blow.right == carry.right` below is what holds that.
			--
			-- WHY THEY MOVED OFF TASK 211's. Task 211 placed the glove so the FIST'S OWN HOLE ran
			-- along the tube -- 0.00 degrees of hole-axis against the tangent, the grip point dead
			-- on the centre line -- and that pose is exactly the one Karen rejected on 2026-10-19
			-- (*"still need to improve hand position when holding horn"*, with the glove lying on
			-- the tube in `karen-2026-10-19/horn-carry.png`). The hole cannot take the tube, which
			-- is measured in `closes the right fist` below; so the pose that scores perfectly on the
			-- hole is the pose that photographs as a sticker. These are the Designer's grip's.
			for _, case in ipairs({
				{
					name = "carry",
					pose = hornPoses.carry.right,
					tip = Vector3.new(-0.0488, 0.0063, 0.2931),
					cuff = Vector3.new(0.2656, -0.3373, 0.7606),
				},
				{
					name = "blow",
					pose = hornPoses.blow.right,
					tip = Vector3.new(-0.0488, 0.0063, 0.2931),
					cuff = Vector3.new(0.2656, -0.3373, 0.7606),
				},
			}) do
				local tip, cuff = ends(case.pose)
				TestKit.note(
					string.format(
						"task212 horn %s right hand: fingertip (%.4f, %.4f, %.4f), cuff (%.4f, %.4f, %.4f)",
						case.name,
						tip.X,
						tip.Y,
						tip.Z,
						cuff.X,
						cuff.Y,
						cuff.Z
					)
				)
				expect((tip - case.tip).Magnitude < TOLERANCE).to.equal(true)
				expect((cuff - case.cuff).Magnitude < TOLERANCE).to.equal(true)
			end
		end)

		it("...and the shotgun's carry hand holds the gun with the fingers, like the rifle's", function()
			-- A FREE READING OF A HAND NOBODY RE-SOLVED, and it is the question Karen asked of the
			-- rifle. At the hip the shotgun's right hand passes: the cuff trails the fingertip by
			-- 0.4252 studs, more than half the glove's own length (0.3300), so the forearm runs back
			-- along the gun. THE AIMED POSE DOES NOT -- it trails by -0.4252, the same hand end-for-end
			-- -- and that is a pose Karen has accepted and task 189 was not asked to touch. It is
			-- reported (TASKS.md 189a) rather than changed here, and this case is what will hold it
			-- once someone does.
			local HALF = (HandAssets.FINGERTIP_STUDS - HandAssets.CUFF_STUDS).Magnitude / 2
			local tip, cuff = ends(Mode.handOffsetAt("right", stateAt(0, 0), shotgunConfig))
			TestKit.note(
				string.format(
					"task189 shotgun carry hand: cuff trails %.4f studs (half the glove is %.4f)",
					cuff.Z - tip.Z,
					HALF
				)
			)
			expect(cuff.Z - tip.Z > HALF).to.equal(true)
			local aimTip, aimCuff = ends(Mode.handOffsetAt("right", stateAt(1, 0), shotgunConfig))
			TestKit.note(
				string.format(
					"task189 shotgun AIMED hand: cuff trails %.4f studs -- reported, not fixed (189a)",
					aimCuff.Z - aimTip.Z
				)
			)
		end)
	end)

	-- ---------------------------------------------------------------- the horn is in the picture
	--
	-- KAREN, 2026-10-14 ~17:00: *"beater hadn is bad and 2 horsn instead 1 it's broken"*. MEASURED in
	-- the Forest Test on 2026-10-17, as a beater in first person: there is exactly ONE horn drawn in
	-- every state (at rest, blowing, after a respawn, after a new drive, after /hunter -> /beater) --
	-- the viewmodel clone, with the real Tool's three parts at `LocalTransparencyModifier` 1, which
	-- is what task 176 said and it is still true. What was broken is that the ONE horn was drawn as
	-- TWO: the shipped carry pose ran the 3.125-stud horn from 3.61 studs in front of the lens to
	-- 0.99, so its near end projected to x = 1455 on a 955-pixel screen and left the picture, and the
	-- glove sat across the middle of what was left. A ray cast through the viewmodel at eye height
	-- hit the horn at x = 500..700, the glove at 740..800, NOTHING at 840..880, and the horn again at
	-- 910..940. Two pale masses with clear background between them. The blow pose was worse: the
	-- mouthpiece ended up 0.23 studs BEHIND the eye.
	--
	-- THESE TWO CASES ARE THE EVIDENCE AND THE PIN ABOVE IS NOT. A pin says "nobody moved this"; it
	-- cannot say whether what it is holding was ever right, which is why task 176's hand passed every
	-- gate while sitting 0.16 studs off the tube it was supposed to be holding. These measure the
	-- drawn horn against the PICTURE and the glove against the HORN -- `Horn.TUBE_SAMPLES`, raycast
	-- off the real Handle in the same session -- so a pose that leaves the frame or a hand that
	-- leaves the tube fails here instead of waiting for Karen. Run against the pose data this task
	-- replaced, both of them fail (the numbers are in the notes below).
	--
	-- THE VIEWPORT IS ASSUMED NO NARROWER THAN IT IS TALL. Roblox's `FieldOfView` is the VERTICAL
	-- angle, so the vertical bound is exact for every window; the horizontal one is the vertical
	-- bound again, which is what a square window would give and is therefore the strictest any
	-- window can ask for. Karen plays at 955 x 785, where the horizontal room is 1.22x this.
	describe("the drawn horn is in the picture, and the glove is on it (task 202, 211)", function()
		local hornPoses = Data.view(Data.DATA).HORN
		-- THE FIRST-PERSON CLONE'S SCALE (task 211). Every row of `TUBE_SAMPLES` is multiplied by it
		-- here for the same reason `Camera.Viewmodel` multiplies the mouthpiece offset: the samples
		-- were raycast off the REAL Handle, and what is drawn under the camera is a uniformly scaled
		-- copy of it. `item.pos` carries the same factor, so every ratio below -- which is what the
		-- picture IS -- comes out exactly as it did before the scale existed. That is the point of
		-- option B: the horn Karen sees is the same size on screen and only the HAND changed.
		local SCALE = hornPoses.scale
		-- Half the view, as a ratio of the distance: everything inside the picture has
		-- |x| / depth and |y| / depth below it. `FOV_THIRD_DEG` is the hip field of view, which is
		-- the one a beater is ever looking through -- a horn has no aim.
		local HALF_VIEW = math.tan(math.rad(Config.FOV_THIRD_DEG / 2))
		-- Nothing may be nearer the lens than this. The engine would still draw it, but a section of
		-- horn a stud from the eye is the wall of horn task 176 shipped -- AND THAT BOUND IS ABOUT A
		-- 3.125-STUD HORN (task 211), so it scales with the horn that is actually drawn. The floor
		-- under it is the camera's own `NEAR_PLANE_MARGIN_STUDS`, which is what every piece of the
		-- GUN is already held to an inch from the same lens: a scale small enough to put the horn
		-- inside the near plane is a scale that fails here instead of slicing the horn on screen.
		local NEAREST_STUDS = math.max(1.0 * SCALE, Config.NEAR_PLANE_MARGIN_STUDS)
		-- THE MOUTHPIECE MAY LEAVE THE BOTTOM OF THE PICTURE WHEN IT IS AT THE MOUTH, and only then:
		-- the mouth IS the camera, so a blow that keeps the whole horn on screen is a blow that holds
		-- it away from the face. Everything from the bell to here stays inside. It is a Z ON THE
		-- DRAWN HORN, so it carries the scale like every other length here.
		local MOUTHPIECE_FROM = 1.0 * SCALE

		-- Every measured section of the tube, in the camera's own frame, for one pose -- AT THE SIZE
		-- IT IS DRAWN (task 211).
		local function sections(item: CFrame)
			local out = {}
			for _, row in ipairs(Horn.TUBE_SAMPLES) do
				table.insert(out, {
					z = row.z * SCALE,
					at = item * (Vector3.new(0, row.y, row.z) * SCALE),
					r = row.r * SCALE,
				})
			end
			return out
		end

		-- THE SCALE IS THE FIRST-PERSON CLONE'S AND NOTHING ELSE'S (task 211). The Director's
		-- decision on task 206's escalation was option B *because* option A -- shrinking the real
		-- horn -- would have undone Karen's own instruction of 2026-10-13 (*"for beater horn has to
		-- be doubble or tripple size now is to small"*), which `Horn.MESH.SIZE_STUDS` is. So the two
		-- numbers that say how big the horn is IN THE WORLD, and where it is held there, are pinned
		-- here beside the viewmodel's scale: a later task that reaches for the easy fix moves one of
		-- them and this case says what it is undoing.
		it("scales the drawn horn only -- the world horn and its carry are Karen's size", function()
			expect(SCALE > 0 and SCALE <= 1).to.equal(true)
			-- KAREN'S HORN, UNTOUCHED: 3.125 studs = 0.875 m, which is task 175's reading of her
			-- "double or triple" over task 169's 1.25.
			expect(Horn.MESH.SIZE_STUDS.X).to.equal(3.125)
			-- ...AND WHERE THE THIRD PERSON HOLDS IT, which task 206 fixed and this task may not
			-- move: `Horn.CONFIG.GRIP` is the Tool's own grip, read by the server.
			expect(Horn.CONFIG.GRIP).to.equal(CFrame.new(0, 0, 0.25))
			TestKit.note(
				string.format(
					"task211 the drawn horn is %.4f studs long (%.3f m at %.2f m/stud) against the"
						.. " world horn's %.4f; scale %.4f",
					Horn.MESH.SIZE_STUDS.X * SCALE,
					Horn.MESH.SIZE_STUDS.X * SCALE * Horn.CONFIG.METRES_PER_STUD,
					Horn.CONFIG.METRES_PER_STUD,
					Horn.MESH.SIZE_STUDS.X,
					SCALE
				)
			)
		end)

		it("draws the whole horn inside the picture at the carry", function()
			local worstX, worstY, nearest = 0, 0, math.huge
			for _, section in ipairs(sections(hornPoses.carry.item)) do
				local depth = -section.at.Z - section.r
				nearest = math.min(nearest, depth)
				expect(depth > 0).to.equal(true)
				worstX = math.max(worstX, (math.abs(section.at.X) + section.r) / depth)
				worstY = math.max(worstY, (math.abs(section.at.Y) + section.r) / depth)
			end
			TestKit.note(
				string.format(
					"task202 carry: worst |x|/depth %.4f, |y|/depth %.4f, nearest %.4f studs"
						.. " (half view %.4f, nearest allowed %.2f; task 176 shipped"
						.. " 1.6270 / 0.8580 / 1.0885)",
					worstX,
					worstY,
					nearest,
					HALF_VIEW,
					NEAREST_STUDS
				)
			)
			expect(worstX < HALF_VIEW).to.equal(true)
			expect(worstY < HALF_VIEW).to.equal(true)
			expect(nearest > NEAREST_STUDS).to.equal(true)
		end)

		it("brings the mouthpiece to the mouth without filling the screen", function()
			local worstX, worstY, nearest = 0, 0, math.huge
			for _, section in ipairs(sections(hornPoses.blow.item)) do
				local depth = -section.at.Z - section.r
				nearest = math.min(nearest, depth)
				expect(depth > 0).to.equal(true)
				if section.z <= MOUTHPIECE_FROM then
					worstX = math.max(worstX, (math.abs(section.at.X) + section.r) / depth)
					worstY = math.max(worstY, (math.abs(section.at.Y) + section.r) / depth)
				end
			end
			TestKit.note(
				string.format(
					"task202 blow: worst |x|/depth %.4f, |y|/depth %.4f over the horn up to z=%.1f,"
						.. " nearest %.4f studs (task 176 shipped 10.4059 / 1.3913 / -0.2297 -- the"
						.. " mouthpiece was BEHIND the eye)",
					worstX,
					worstY,
					MOUTHPIECE_FROM,
					nearest
				)
			)
			expect(worstX < HALF_VIEW).to.equal(true)
			expect(worstY < HALF_VIEW).to.equal(true)
			expect(nearest > NEAREST_STUDS).to.equal(true)
		end)

		-- THE FIST CLOSES ROUND THE TUBE (task 211), WHICH IS NOT WHAT TASK 202 ASKED.
		--
		-- That case required all THREE landmarks inside the tube's radius, and the pose that passed
		-- it is the one Karen called broken: a hand lying FLAT on the horn, fist hole across the
		-- tube at 90.0 degrees and the fingers running 0.0 degrees along it, with horn visible
		-- through the finger ring (`.screenshots/t206-before-fp.png`). A wrist that HOLDS something
		-- leaves the thing it holds -- measured, the cuff is about 0.49 studs off the tube in every
		-- correct grip -- so "all three on the tube" is a test a grip cannot pass and a sticker
		-- cannot fail. What a grip IS, as three facts anyone can check:
		--   * the GRIP point -- the hole task 188 measured in the glove's own silhouette -- is on
		--     the tube's measured centre line, within the tube's own radius there;
		--   * the HOLE AXIS, which is the aligned +Y that hole runs along, is along the tube's
		--     TANGENT at that point rather than across it (the dispatch's bound: under 15 degrees);
		--   * the FINGERTIP is nearer the tube than the CUFF, so the hand holds with its fingers and
		--     not with its sleeve -- task 189's defect, in the one place it could come back.
		--
		-- `right` is in the HORN's frame, so a landmark's own Z says which section to ask for -- no
		-- camera and no item pose comes into it, which is why this answers the same question for a
		-- pose nobody has looked at yet. The Z IS DIVIDED BY THE SCALE before it is asked: the
		-- samples are the real horn's and the pose is solved against the DRAWN one.
		local function gripOf(pose: CFrame, scale: number)
			local on = pose:PointToWorldSpace(HandAssets.GRIP_STUDS)
			local centre, radius, slope = Horn.tubeAt(on.Z / scale)
			local tangent = Vector3.new(0, slope, 1).Unit
			-- The fist's own hole runs along the ALIGNED +Y (`HandAssets.GRIP_STUDS`' header: "whose
			-- axis is the aligned Y"), and `Camera.Viewmodel.poseHands` applies `align` on the RIGHT
			-- of this pose -- so the pose's UpVector IS that axis in the horn's frame.
			local angle = math.deg(math.acos(math.clamp(math.abs(pose.UpVector:Dot(tangent)), 0, 1)))
			local off = (Vector2.new(on.X, on.Y - centre * scale)).Magnitude
			return on, off, radius * scale, angle
		end

		-- HOW MUCH OF THE HAND THE HORN COVERS, and since task 212 this is what says the hand is
		-- holding the horn rather than lying on it. The Designer's spec, section 4: *"The palm, the
		-- knuckles and the finger roots go BEHIND the tube; the fingertips and the thumb go in FRONT
		-- of it. The hand's silhouette must be BROKEN by the horn. One plane = touching."*
		--
		-- THE SAMPLES ARE THE FIST'S OWN BOX in the aligned frame (`HandAssets`: fingers +X, palm
		-- +Y, thumb +Z) -- 6 x 4 x 4 points over x 0.00..0.33, y -0.10..0.11, z -0.10..0.14, which
		-- is the hand end of the glove. A BOX AND NOT THE MESH because a spec cannot read a
		-- MeshPart's vertices; it is checked against the mesh rather than assumed. Measured off the
		-- published `prepped/glove_right_v4_r1/model.glb` (which is the drawn part: its bounds times
		-- a hundred are `Assets.HAND_RIGHT_NATURAL` to the digit, and it carries the 6,192 triangles
		-- that manifest row records) with this same ray test, the real vertices answer 0.29 and 0.39
		-- for task 211's two poses where this box answers 0.24 and 0.26, and 0.56 and 0.43 for task
		-- 212's where it answers 0.43 and 0.44. The box tracks the mesh across all four.
		local SAMPLES = {}
		for i = 0, 5 do
			for j = 0, 3 do
				for k = 0, 3 do
					table.insert(SAMPLES, Vector3.new(0.33 * i / 5, -0.10 + 0.21 * j / 3, -0.10 + 0.24 * k / 3))
				end
			end
		end

		-- IS THE DRAWN HORN BETWEEN THE EYE AND THIS POINT? The viewmodel's frame has the lens at
		-- the origin, so the ray is the segment from zero to the point and the horn is the measured
		-- tube: `Horn.tubeAt` at the sample's own Z, divided by the scale for the reason `gripOf`
		-- gives. 64 steps over the segment -- the tube is 0.14 studs across at the grip and the
		-- segment is about a stud, so a step is a fifth of the tube's width and cannot pass through
		-- it. It never looks past the point itself (t <= 0.995), because horn BEHIND the hand is
		-- exactly what this is here to tell apart from horn in front of it.
		local function hornInFront(point: Vector3, horn: CFrame, scale: number): boolean
			for step = 0, 63 do
				local t = 0.02 + (0.995 - 0.02) * step / 63
				local u = horn:PointToObjectSpace(point * t) / scale
				-- THE TUBE HAS ENDS, and `Horn.tubeAt` does not say so: its header records that
				-- "past either end it holds the end row", which is right for a question about the
				-- horn and wrong for a ray that has flown off it. Without this line the test sees an
				-- infinite cylinder -- radius 0.108 past the bell and 0.0715 past the mouthpiece --
				-- and a ray that misses the horn entirely counts as covered. `TUBE_SAMPLES` runs
				-- -1.5 .. +1.5. (It changes no shipped number: both poses here and both of task
				-- 211's answer the same share with it and without it. It is here so the measure
				-- cannot be fooled by a pose that puts the hand off the end of the horn.)
				if u.Z >= -1.5 and u.Z <= 1.5 then
					local centre, radius = Horn.tubeAt(u.Z)
					if math.sqrt(u.X * u.X + (u.Y - centre) * (u.Y - centre)) <= radius then
						return true
					end
				end
			end
			return false
		end

		local function hiddenShare(pose, scale: number): number
			local hidden = 0
			for _, sample in ipairs(SAMPLES) do
				if hornInFront((pose.item * pose.right):PointToWorldSpace(sample), pose.item, scale) then
					hidden += 1
				end
			end
			return hidden / #SAMPLES
		end

		-- THE BOUND IS 0.35 AND THE TWO SIDES OF IT ARE BUILDS THAT WERE LOOKED AT: task 211's two
		-- poses answer 0.24 and 0.26 (the case below runs them), and task 212's answer 0.43 and
		-- 0.44. It is nowhere near either, so a pose has to really move for this to change hands.
		local COVERED = 0.35

		it("closes the right fist around the tube in both poses", function()
			for _, case in ipairs({
				{ name = "carry", pose = hornPoses.carry, right = hornPoses.carry.right },
				{ name = "blow", pose = hornPoses.blow, right = hornPoses.blow.right },
			}) do
				local share = hiddenShare(case.pose, SCALE)
				local on, off, radius, angle = gripOf(case.right, SCALE)
				local tip = case.right:PointToWorldSpace(HandAssets.FINGERTIP_STUDS)
				local cuff = case.right:PointToWorldSpace(HandAssets.CUFF_STUDS)
				local function offTube(point: Vector3): number
					local centre = Horn.tubeAt(point.Z / SCALE)
					return (Vector2.new(point.X, point.Y - centre * SCALE)).Magnitude
				end
				local tipOff, cuffOff = offTube(tip), offTube(cuff)
				TestKit.note(
					string.format(
						"task212 %s grip: the horn covers %.3f of the fist (task 211 covered 0.24 and"
							.. " 0.26, and this file asks for more than 0.35); grip (%.4f, %.4f,"
							.. " %.4f) is %.4f off the centre line (tube"
							.. " radius %.4f there), hole axis %.2f deg off the tangent, fingertip"
							.. " %.4f off against the cuff's %.4f",
						case.name,
						share,
						on.X,
						on.Y,
						on.Z,
						off,
						radius,
						angle,
						tipOff,
						cuffOff
					)
				)
				-- THE HORN CROSSES THE HAND. This replaces task 211's `off <= radius` and
				-- `angle < 15`, which asked whether the FIST'S HOLE was threaded on the tube.
				-- MEASURED in task 212, by voxelising the published glove at 0.004 studs in the
				-- aligned frame: along the thumb axis -- the way a tube has to run for this grip --
				-- the fist has NO through-hole at all (2 voxels, radius 0.004), and along the
				-- fingers none either. The one hole it has runs along the PALM NORMAL and is
				-- 0.052 x 0.072 studs, largest inscribed radius 0.0170, while the tube at the grip
				-- is 0.339 studs across unscaled. So the hole is a fifth of the tube's width AND it
				-- points the wrong way: the fist was modelled closed on the rifle's bolt knob, a
				-- ball of radius 0.0256 (`Rifle.Geometry.boltKnobOffset`), and that is what fits it.
				-- A pose that scores 0.00 degrees on that hole is a pose that cannot be holding
				-- anything -- which is why task 211 passed this file and failed Karen's eye.
				expect(share > COVERED).to.equal(true)
				-- ...AND THE FINGERS ARE THE END THAT IS ON IT, which is the one thing task 189's
				-- end-for-end defect could not fake and is kept exactly as it was.
				expect(tipOff < cuffOff).to.equal(true)
			end
		end)

		-- THE GRIP NEVER CHANGES, and it is one equality rather than two pins (the Designer's spec,
		-- section 4). The hand is posed in the HORN's own frame, so the same CFrame in both poses IS
		-- the same hand on the same point of the tube however far the horn swings -- and task 211,
		-- which carried two different ones, is what let the glove slide between the carry and the
		-- mouth. `CFrame` has no tolerance here on purpose: these come from one block of numbers in
		-- `poses.json`, so anything but equality means somebody edited one half.
		it("holds the horn with the same hand in the carry and at the lips", function()
			TestKit.note(
				string.format(
					"task212 carry.right %s / blow.right %s",
					tostring(hornPoses.carry.right),
					tostring(hornPoses.blow.right)
				)
			)
			expect(hornPoses.carry.right).to.equal(hornPoses.blow.right)
		end)

		-- WHERE THE HAND IS IN THE PICTURE (task 211 round 2). THE DIRECTOR, 2026-10-19, having
		-- looked at round 1's blow frame: *"the glove fills about a third of the screen, floats in
		-- the middle of the view ... the bar is that it looks like the shotgun's hands do when
		-- aiming: hand at the bottom edge, forearm entering from the bottom, the horn's mouthpiece
		-- at the lips (bottom-centre), the bell pointing up and forward out of the view."*
		--
		-- ROUND 1 HAD NOTHING LOOKING AT THE GLOVE AT ALL, which is the Reviewer's own note (211a(c))
		-- and is how a hand in the middle of the screen passed every case in the file: the two cases
		-- above measure the HORN against the picture and the GLOVE against the horn, and the glove
		-- against the PICTURE was nobody's. It is the only thing this task moved on screen.
		--
		-- THE BOTTOM QUARTER, as a ratio of the depth exactly like the horn's own bounds: the frame
		-- runs from -HALF_VIEW to +HALF_VIEW, so its bottom quarter is -HALF_VIEW .. -HALF_VIEW/2.
		-- The CUFF is required BELOW the glove's centre rather than inside the frame, because a
		-- forearm that enters from the bottom edge leaves it -- which is what the shotgun's own
		-- right hand does at the carry (its centre projects to -1.71, entirely under the picture).
		local function onScreen(point: Vector3)
			return Vector2.new(point.X / -point.Z, point.Y / -point.Z)
		end

		it("puts the blowing hand at the bottom of the frame, forearm leaving it", function()
			for _, case in ipairs({
				{ name = "carry", pose = hornPoses.carry, bottomQuarter = false },
				{ name = "blow", pose = hornPoses.blow, bottomQuarter = true },
			}) do
				local hand = case.pose.item * case.pose.right
				local centre = onScreen(hand.Position)
				local cuff = onScreen(hand:PointToWorldSpace(HandAssets.CUFF_STUDS))
				local tip = onScreen(hand:PointToWorldSpace(HandAssets.FINGERTIP_STUDS))
				TestKit.note(
					string.format(
						"task211r2 %s glove: centre (%.3f, %.3f) at %.3f studs, cuff (%.3f, %.3f),"
							.. " fingertip (%.3f, %.3f); half view %.3f, bottom quarter %.3f..%.3f"
							.. " (round 1's blow centre was -0.011, -0.060 at 0.687 studs)",
						case.name,
						centre.X,
						centre.Y,
						hand.Position.Magnitude,
						cuff.X,
						cuff.Y,
						tip.X,
						tip.Y,
						HALF_VIEW,
						-HALF_VIEW,
						-HALF_VIEW / 2
					)
				)
				-- THE FOREARM LEAVES THE BOTTOM in both poses: the cuff is below the hand's centre,
				-- which is what makes the arm read as coming from the player rather than floating.
				expect(cuff.Y < centre.Y).to.equal(true)
				expect(tip.Y > cuff.Y).to.equal(true)
				if case.bottomQuarter then
					expect(math.abs(centre.X) < HALF_VIEW).to.equal(true)
					expect(centre.Y < -HALF_VIEW / 2).to.equal(true)
					expect(centre.Y > -HALF_VIEW).to.equal(true)
				end
			end
		end)

		it("...and round 1's blowing hand floated in the middle of that frame", function()
			-- THE CASE ABOVE CAN FAIL, SHOWN ON THE NUMBERS IT WAS WRITTEN FOR (Learning Agent
			-- L-028). These twelve are `poses.json`'s `horn.blow` as task 211 round 1 shipped it --
			-- the pose in `.screenshots/t211-after-blow.png`, the one the Director bounced -- and the
			-- hand in it sits a twentieth of the frame below the centre line, not in the bottom
			-- quarter.
			local item = CFrame.new(-0.204, 0.034, -0.748)
				* CFrame.Angles(math.rad(42.51), math.rad(7.0), math.rad(-82.42))
			local right = CFrame.new(0.0135, 0.0623, 0.1134)
				* CFrame.Angles(math.rad(-113.9412), math.rad(-83.2375), math.rad(-180.0))
			local centre = onScreen((item * right).Position)
			TestKit.note(
				string.format(
					"task211r2 the REPLACED blow glove: centre (%.3f, %.3f), which is %.3f of the way"
						.. " down a half frame of %.3f -- the bottom quarter starts at %.3f",
					centre.X,
					centre.Y,
					-centre.Y,
					HALF_VIEW,
					-HALF_VIEW / 2
				)
			)
			expect(centre.Y > -HALF_VIEW / 2).to.equal(true)
		end)

		it("...and the horn covered a quarter of the fist on the pose Karen rejected", function()
			-- THE CASE ABOVE CAN FAIL, AND THIS IS THE PROOF RATHER THAN THE CLAIM (Learning Agent
			-- L-028: a new bound offered as evidence has to be shown failing on the data it was
			-- written for). These are `poses.json`'s own `horn` block AS TASK 211 SHIPPED IT -- the
			-- build in `karen-2026-10-19/horn-carry.png` and `horn-blow.png`, the two frames Karen
			-- answered with *"still need to improve hand position when holding horn"* -- read
			-- through the same `hiddenShare`.
			--
			-- IT IS THE QUANTITY THE DEFECT MOVED, not a pivot and not a box corner: on those
			-- numbers the GLOVE is the thing in front, so the horn covers a quarter of the fist and
			-- this bound is missed by a wide margin. Both are run, because the blow was re-composed
			-- in task 211 round 2 and passed that round's own cases while still covering 0.26.
			--
			-- AT THEIR OWN SCALE, WHICH WAS 0.34: those poses were solved against a horn drawn that
			-- size, and measuring them against today's 0.42 would be comparing them with a horn
			-- they never saw.
			for _, case in ipairs({
				{
					name = "carry",
					item = CFrame.new(0.187, -0.51, -1.224)
						* CFrame.Angles(math.rad(68.2), math.rad(72.42), math.rad(-69.13)),
					right = CFrame.new(-0.1601, -0.1249, 0.1965)
						* CFrame.Angles(math.rad(-113.9412), math.rad(-16.1747), math.rad(0.0)),
				},
				{
					name = "blow",
					item = CFrame.new(-0.1007, -0.0655, -0.8939)
						* CFrame.Angles(math.rad(45.0447), math.rad(8.541), math.rad(-8.4607)),
					right = CFrame.new(0.0773, -0.1934, 0.2949)
						* CFrame.Angles(math.rad(74.1455), math.rad(-60.0), math.rad(180.0)),
				},
			}) do
				local share = hiddenShare({ item = case.item, right = case.right }, 0.34)
				TestKit.note(
					string.format(
						"task212 the REJECTED %s: the horn covers %.3f of the fist, against the %.2f"
							.. " this file now asks for",
						case.name,
						share,
						COVERED
					)
				)
				expect(share < COVERED).to.equal(true)
			end
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
	-- ---------------------------------------------------------------- the load (task 204)
	--
	-- Karen, 2026-10-18: *"we need to change shooting sound and power to shotgun when slugs and
	-- shells is used slugs are harder"*. What is asserted here is the DATA and the two pure readers;
	-- that a real shot out of a real gun actually comes out harder is `weapon_client.spec`'s, which
	-- fires one of each through `FireRequest:FireServer` and measures the camera and the Sound.
	describe("the shot, per load", function()
		it("ships a scale for each of the shotgun's two loads, and the slug is the harder one", function()
			local loads = SET.fire.loads
			expect(type(loads)).to.equal("table")
			for _, kind in ipairs({ "Slug", "Buck" }) do
				expect(type(loads[kind])).to.equal("table")
				for _, key in ipairs(Data.LOAD_SCALES) do
					expect(type(loads[kind][key])).to.equal("number")
					expect(loads[kind][key] > 0).to.equal(true)
				end
			end
			-- THE WHOLE POINT, AS THREE INEQUALITIES. "Harder" is a bigger kick and a louder report;
			-- "deeper" is a LOWER playback speed, which is why that one runs the other way.
			expect(loads.Slug.recoilScale > loads.Buck.recoilScale).to.equal(true)
			expect(loads.Slug.volumeScale > loads.Buck.volumeScale).to.equal(true)
			expect(loads.Slug.pitchScale < loads.Buck.pitchScale).to.equal(true)
			-- BUCKSHOT IS THE GUN KAREN ALREADY ACCEPTED, unchanged: this task moved the slug away
			-- from it and left the reference where it was.
			expect(loads.Buck.recoilScale).to.equal(1)
			expect(loads.Buck.volumeScale).to.equal(1)
			expect(loads.Buck.pitchScale).to.equal(1)
			TestKit.note(
				string.format(
					"load scales: slug recoil=%.2f volume=%.2f pitch=%.2f | buck recoil=%.2f volume=%.2f pitch=%.2f",
					loads.Slug.recoilScale,
					loads.Slug.volumeScale,
					loads.Slug.pitchScale,
					loads.Buck.recoilScale,
					loads.Buck.volumeScale,
					loads.Buck.pitchScale
				)
			)
		end)

		it("answers NEUTRAL for a weapon, an ammo or a row it does not know", function()
			local fire = SET.fire
			expect(Data.loadFor(fire, "Slug")).to.equal(fire.loads.Slug)
			-- The rifle has no block at all, which is what keeps its shot bit-for-bit what it was.
			expect(Data.loadFor(Data.DATA.weapons.rifle.fire, "Slug")).to.equal(Data.NEUTRAL_LOAD)
			expect(Data.loadFor(fire, "Birdshot")).to.equal(Data.NEUTRAL_LOAD)
			expect(Data.loadFor(fire, nil)).to.equal(Data.NEUTRAL_LOAD)
			expect(Data.loadFor(nil, "Slug")).to.equal(Data.NEUTRAL_LOAD)
			-- A HALF-WRITTEN ROW IS NEUTRAL, NOT HALF-APPLIED: a shot whose volume moved and whose
			-- kick did not is the defect this whole task is about, in miniature.
			expect(Data.loadFor({ loads = { Slug = { volumeScale = 2 } } }, "Slug")).to.equal(Data.NEUTRAL_LOAD)
			for _, scale in ipairs(Data.LOAD_SCALES) do
				expect(Data.NEUTRAL_LOAD[scale]).to.equal(1)
			end
		end)

		it("refuses a loads block that is not three positive numbers per load", function()
			local function withLoads(loads: any): { string }
				local data = Data.copy(Data.DATA)
				data.weapons.shotgun.fire.loads = loads
				return Data.validate(data)
			end
			expect(#withLoads(nil)).to.equal(0) -- OPTIONAL: a gun with one kind of shell has none
			expect(#withLoads({ Slug = { recoilScale = 1.45, volumeScale = 1.25, pitchScale = 0.82 } })).to.equal(0)
			expect(#withLoads("heavy") > 0).to.equal(true)
			expect(#withLoads({ Slug = 1.45 }) > 0).to.equal(true)
			expect(#withLoads({ Slug = { recoilScale = 1.45, volumeScale = 1.25 } }) > 0).to.equal(true)
			expect(#withLoads({ Slug = { recoilScale = 0, volumeScale = 1, pitchScale = 1 } }) > 0).to.equal(true)
			expect(#withLoads({ Slug = { recoilScale = -1, volumeScale = 1, pitchScale = 1 } }) > 0).to.equal(true)
		end)

		it("scales the six recoil amplitudes for the load and nothing else about the spring", function()
			local base = configWith(true, Data.DATA)
			-- BUCKSHOT IS THE CONFIG ITSELF, not a copy of it: `recoilScale == 1` is the shot this
			-- repo has always fired, out of the very same frozen table.
			expect(Poses.forLoad(base, "Buck")).to.equal(base)
			expect(Poses.forLoad(base, nil)).to.equal(base)
			local slug = Poses.forLoad(base, "Slug")
			expect(slug).never.to.equal(base)
			local scale = SET.fire.loads.Slug.recoilScale
			for _, key in ipairs(Poses.RECOIL_SCALED) do
				expect(math.abs(slug[key] - base[key] * scale) < 1e-6).to.equal(true)
			end
			-- THE SPRING'S SHAPE IS NOT THE LOAD'S BUSINESS. A slug is heavier; it is not a
			-- different gun, and `camera_mode.spec` rests on this spring settling to exactly zero.
			for _, key in ipairs({
				"RECOIL_FREQUENCY_HZ",
				"RECOIL_DAMPING_RATIO",
				"RECOIL_REST_EPSILON",
				"RECOIL_MAX_SUBSTEP_SECONDS",
			}) do
				expect(slug[key]).to.equal(base[key])
			end
			-- ...AND THE KICK THE CAMERA ACTUALLY TAKES IS BIGGER, through `Mode.kick` itself.
			local rest = Mode.initial(base)
			local afterBuck = Mode.kick(rest, Poses.forLoad(base, "Buck"))
			local afterSlug = Mode.kick(rest, slug)
			expect(afterSlug.recoilCamPitchDeg > afterBuck.recoilCamPitchDeg).to.equal(true)
			expect(afterSlug.recoilGunPitchDeg > afterBuck.recoilGunPitchDeg).to.equal(true)
			expect(afterSlug.recoilGunBackStuds > afterBuck.recoilGunBackStuds).to.equal(true)
			TestKit.note(
				string.format(
					"one shot, pure: camPitch buck=%.3f slug=%.3f deg; gunPitch buck=%.2f slug=%.2f deg",
					afterBuck.recoilCamPitchDeg,
					afterSlug.recoilCamPitchDeg,
					afterBuck.recoilGunPitchDeg,
					afterSlug.recoilGunPitchDeg
				)
			)
		end)
	end)
end
