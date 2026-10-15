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
		-- and the drawn MeshPart is mirrored in X against that file, so `align`'s +X pointed at the
		-- cuff. Every pose solved in that frame came out backwards. The sign is measured in the
		-- RUNNING game now -- see that file -- and these cases are what hold it.)
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
	-- shifts every number below by up to 0.063 studs. The DRAWN hands are untouched: the transport
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

		it("the horn's hand is where task 176 drew it", function()
			-- `carry` and `blow` carry the same three angles, so one pose answers for both; the
			-- positions differ and are not this case's business.
			local tip, cuff = ends(hornPoses.carry.right)
			TestKit.note(
				string.format(
					"task189 horn right hand: fingertip (%.4f, %.4f, %.4f), cuff (%.4f, %.4f, %.4f)",
					tip.X,
					tip.Y,
					tip.Z,
					cuff.X,
					cuff.Y,
					cuff.Z
				)
			)
			expect((tip - Vector3.new(-0.1295, -0.0382, 0.0582)).Magnitude < TOLERANCE).to.equal(true)
			expect((cuff - Vector3.new(0.1399, -0.1903, 0.6411)).Magnitude < TOLERANCE).to.equal(true)
		end)

		it("...and the shotgun's carry hand holds the gun with the fingers, like the rifle's", function()
			-- A FREE READING OF A HAND NOBODY RE-SOLVED, and it is the question Karen asked of the
			-- rifle. At the hip the shotgun's right hand passes: the cuff trails the fingertip by
			-- 0.447 studs, more than half the glove's own length, so the forearm runs back along the
			-- gun. THE AIMED POSE DOES NOT -- it trails by -0.447, which is the same hand end-for-end
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
