-- boar_move.spec: HOW A DRIVEN ANIMAL MOVES WHEN `MOVE` IS ON -- the straight flight, the edge stop
-- and the whisker's committed side -- plus the two sound rules the game actually ships.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- IT EXISTS BECAUSE NOTHING COULD TELL THE FLAG ON FROM THE FLAG OFF (tasks 123, 126 and 129, round
-- 2, three Reviewer findings with one shape). `Boar.CONFIG.MOVE` is born off and the playtest world
-- turns it on, and every spec built its config as `table.clone(CONFIG)` -- so the mechanisms Karen
-- asked for by name shipped with no coverage in either state. The same was true of the approach
-- grunt (`GRUNTS.ON_APPROACH`, the whole pig voice) and of the shipped SILENCE: the ration cases
-- switch the cues on by parameter, and nothing asserted what the game ships with them off.
--
-- THE FLAG ARRIVES AS A PARAMETER, which is the one permitted shape (docs/design/feature-flags.md
-- section 13.3) and the only way both states are reachable while the flag sits at one of them.
--
-- Design: no new design document -- the boar's own axis. TASKS.md rows 123, 126, 127.
-- Note:   docs/research/2026-10-05-sounder-movement.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Brain = Boar.Brain
local CONFIG = Boar.CONFIG
local SOUND = CONFIG.SOUND

local DT = 1 / 60
local FIELD = {
	bounds = { minX = -400, maxX = 400, minZ = -400, maxZ = 400 },
	exitZ = -380,
	groundY = 0,
}
local START = Vector3.new(0, 0, 0)

local function moveConfig(on: boolean)
	local config = table.clone(CONFIG)
	config.SENSE = table.clone(CONFIG.SENSE)
	config.SENSE.ENABLED = true
	local pace = table.clone(CONFIG.PACE)
	pace.ENABLED = true
	config.PACE = pace
	local move = table.clone(CONFIG.MOVE)
	move.ENABLED = on
	config.MOVE = move
	return config
end

local function obs(position: Vector3, threats)
	return {
		position = position,
		velocity = Vector3.zero,
		threats = threats or {},
		waypoints = nil,
		pathFailed = false,
		blockedAhead = false,
	}
end

-- Run a brain for `seconds`, integrating its own intent, and report where it went.
local function run(brain, seconds: number, threats)
	local position = START
	local headings = {}
	for _ = 1, math.ceil(seconds / DT) do
		local intent = brain:step(DT, obs(position, threats))
		position += intent.targetVelocity * DT
		if intent.facing.Magnitude > 1e-6 then
			table.insert(headings, intent.facing.Unit)
		end
	end
	return position, headings
end

return function()
	describe("the straight flight (MOVE on)", function()
		it("holds ONE line past a threat that would otherwise bend it", function()
			-- (see the case below for the shooter standing BETWEEN the animal and the way out)
			-- KAREN: *"after shoot animals usually run straight when they spook"*, *"they shouldn do
			-- circles like I see now"*, *"it runs awai a lot until I can;t see them"*.
			--
			-- THE LATCH ONLY SHOWS UP WHEN SOMETHING WOULD TURN THE ANIMAL. Measured first with an
			-- empty field, where it showed nothing at all: an animal fleeing an empty world already
			-- runs straight at the exit, so both states ran 101 studs turning 2.3 deg/frame and the
			-- A/B proved nothing. What the latch changes is what happens when a SECOND thing appears
			-- beside the line -- a driver on the flank, a man at a stand -- which with the flag off
			-- bends the flee vector every frame and with it on does not.
			local function runPast(on: boolean)
				local brain = Brain.new(moveConfig(on), FIELD, START, Random.new(9))
				brain:spook(Vector3.new(0, 0, 40)) -- the bang, from behind
				local position = START
				local first, last = nil, nil
				for frame = 1, math.ceil(6 / DT) do
					-- A DRIVER WALKING ALONG THE ANIMAL'S FLANK, 20 studs to its left and keeping up.
					local threats = {
						{ id = "flank", position = position + Vector3.new(-20, 0, 0), kind = "driver", speed = 5 },
					}
					local intent = brain:step(DT, obs(position, threats))
					position += intent.targetVelocity * DT
					if intent.facing.Magnitude > 1e-6 then
						last = intent.facing.Unit
						if frame > 30 then
							first = first or last
						end
					end
				end
				local bend = 0
				if first ~= nil and last ~= nil then
					bend = math.deg(math.acos(math.clamp(first:Dot(last), -1, 1)))
				end
				return (Vector3.new(position.X, 0, position.Z)).Magnitude, bend
			end

			local straightRun, straightBend = runPast(true)
			local looseRun, looseBend = runPast(false)
			TestKit.note(
				string.format(
					"boar-move: running past a driver on its flank -- MOVE on %.0f studs, bent %.1f deg;"
						.. " MOVE off %.0f studs, bent %.1f deg",
					straightRun,
					straightBend,
					looseRun,
					looseBend
				)
			)
			-- WHAT THE LATCH IS WORTH, AS A NUMBER, and it is not a straight line: measured on this
			-- commit, a man walking the animal's flank for six seconds bends its heading **68
			-- degrees with the flag on and 91 with it off**. The latch takes a third of the bend out
			-- and no more -- the flee vector is still recomputed every frame around the threat, and
			-- the latched line only sets the direction the FLEE branch starts from. Karen's *"they
			-- run and run straigh"* is therefore closer than it was and is not yet true next to a
			-- driver; that limit is in task 126's request rather than asserted away here.
			expect(straightBend < looseBend - 15).to.equal(true)
			-- ...and it still covers ground: far enough to leave a stand behind.
			expect(straightRun > 100).to.equal(true)
			-- ...and with nothing beside it, the line really is a line: the same animal with an empty
			-- field turns 2.3 degrees per frame at most, which is the case this one started as.
			local empty = Brain.new(moveConfig(true), FIELD, START, Random.new(9))
			empty:spook(Vector3.new(0, 0, 40))
			local _, headings = run(empty, 6, {})
			local worst = 0
			for index = 2, #headings do
				worst =
					math.max(worst, math.deg(math.acos(math.clamp(headings[index - 1]:Dot(headings[index]), -1, 1))))
			end
			expect(worst < 5).to.equal(true)
		end)

		it("keeps the first line when a second fright arrives inside its window", function()
			-- ONE LINE, NOT A ZIGZAG: a herd-mate's alarm a moment later must not swing the animal
			-- round. Measured on the heading it is actually travelling on, not on a field.
			local brain = Brain.new(moveConfig(true), FIELD, START, Random.new(11))
			brain:spook(Vector3.new(0, 0, 40))
			expect(brain:flying()).to.equal(true)
			local position = START
			local function headingAfter(seconds: number): Vector3
				local facing = Vector3.new(0, 0, 1)
				for _ = 1, math.ceil(seconds / DT) do
					local intent = brain:step(DT, obs(position, {}))
					position += intent.targetVelocity * DT
					if intent.facing.Magnitude > 1e-6 then
						facing = intent.facing.Unit
					end
				end
				return facing
			end
			local before = headingAfter(0.5)
			brain:spook(Vector3.new(60, 0, 0)) -- a bang from the side, inside the re-latch window
			local after = headingAfter(0.5)
			expect(before:Dot(after) > 0.99).to.equal(true)
		end)

		it("runs for the WAY OUT even when the gun is between, and never back past it", function()
			-- KAREN, 2026-10-09: *"when boars crossing road they can't come back to same view, they
			-- just move on a specially after spook or shoot"*. MEASURED on `0c7f736` over nine shots
			-- in the Forest Test: **five animals ran NORTH afterwards**, back into the view she had
			-- just shot into.
			--
			-- THE CASE THE OLD CODE GOT WRONG IS THIS ONE, and in a drive it is every shot: the
			-- shooter stands between the animal and the exit. `_latchFlight` used to answer `away`
			-- there -- straight back the way it came -- and its comment said so on purpose. A drive
			-- exists to break game PAST the guns.
			--
			-- `FIELD.exitZ` is -380, so the way out is -Z. The shooter is at -60: directly between.
			local brain = Brain.new(moveConfig(true), FIELD, START, Random.new(13))
			brain:spook(Vector3.new(0, 0, -60))
			local position = START
			for _ = 1, math.ceil(3 / DT) do
				local intent = brain:step(DT, obs(position, {}))
				position += intent.targetVelocity * DT
			end
			-- IT WENT TOWARD THE EXIT, not back up the field. This is the assertion that fails the
			-- moment the old `if away:Dot(toExit) <= 0 then away` comes back.
			expect(position.Z < START.Z - 20).to.equal(true)
			-- ...AND IT PASSED HIM TO ONE SIDE rather than running straight down his barrel, which is
			-- what `MOVE.FLIGHT_SWERVE` is for. With the shooter square on the exit line the
			-- away-vector cancels exactly, so the side comes from the animal's own `_whiskerSide`.
			expect(math.abs(position.X) > 5).to.equal(true)
		end)

		it("does not latch at all with the flag off", function()
			local brain = Brain.new(moveConfig(false), FIELD, START, Random.new(11))
			brain:spook(Vector3.new(0, 0, 40))
			expect(brain:flying()).to.equal(false)
		end)
	end)

	describe("the edge stop (MOVE on)", function()
		it("stops a calm animal where it is told to look, once, and never a frightened one", function()
			-- KAREN: *"they can stop before entering the road"*. The drive offers the check; the
			-- Brain decides. `MOVE.EDGE_CHANCE` is a roll, so this drives the seeded Random until it
			-- takes one -- the claim is about the STOP, not about the odds.
			local brain, took = nil, false
			for seed = 1, 40 do
				brain = Brain.new(moveConfig(true), FIELD, START, Random.new(seed))
				if brain:check(1.5) then
					took = true
					break
				end
			end
			expect(took).to.equal(true)
			expect((brain :: any):checking()).to.equal(true)
			-- IT REALLY STOPS: the setpoint is zero while the check runs.
			local intent = (brain :: any):step(DT, obs(START, {}))
			expect(intent.targetVelocity.Magnitude < 0.001).to.equal(true)
			-- ONCE PER APPROACH: a second offer while it is already looking is refused.
			expect((brain :: any):check(1.5)).to.equal(false)

			-- A FRIGHTENED ANIMAL DOES NOT STOP TO LOOK.
			local scared = Brain.new(moveConfig(true), FIELD, START, Random.new(3))
			scared:spook(Vector3.new(0, 0, 40))
			expect(scared:check(1.5)).to.equal(false)
		end)

		it("is refused outright with the flag off", function()
			local brain = Brain.new(moveConfig(false), FIELD, START, Random.new(1))
			expect(brain:check(1.5)).to.equal(false)
			expect(brain:checking()).to.equal(false)
		end)
	end)

	describe("the whisker's committed side (MOVE on)", function()
		it("holds the side it chose while the deflection lasts", function()
			-- THE `locked` BRANCH had no caller in any spec. Committed means: once a side is picked,
			-- the same whisker reading keeps turning the animal the same way -- an animal that
			-- re-picks mid-deflection weaves along the trunk instead of passing it.
			local on = moveConfig(true)
			local NORTH = Vector3.new(0, 0, 1)
			local whisker = { ahead = true, left = true, right = false }
			local free = Brain.steerAroundTrunk(NORTH, whisker, on, 1, false)
			local locked = Brain.steerAroundTrunk(NORTH, whisker, on, 1, true)
			-- Free, the reading decides (something on the left: go right, which is -X facing +Z).
			expect(free.X < 0).to.equal(true)
			-- Locked, the animal's OWN side decides, and `prefer = 1` is its right.
			expect(locked.X < 0).to.equal(true)
			-- ...and the mirror: locked with the other side turns the other way, whatever the
			-- whisker says, which is the whole difference between the two branches.
			local mirrored = Brain.steerAroundTrunk(NORTH, whisker, on, -1, true)
			expect(mirrored.X > 0).to.equal(true)
			local freeMirror = Brain.steerAroundTrunk(NORTH, whisker, on, -1, false)
			expect(freeMirror.X < 0).to.equal(true) -- unlocked, the reading still wins
		end)
	end)

	describe("the voice the game actually ships", function()
		it("is silent except for the approach grunt and the hooves", function()
			-- THE SHIPPED CONFIG, asserted for the first time (task 129 round 2: the ration cases
			-- switch these cues ON by parameter, and nothing checked what Karen actually gets).
			-- Karen: *"when they cross road or they close they don't make any pig sound besides
			-- walking / and I hear only when it;s close inaf to me if it's far away I don't hear"*.
			expect(SOUND.BREATH.enabled).to.equal(false)
			expect(SOUND.SNIFF.enabled).to.equal(false)
			expect(SOUND.GRUNTS.ON_APPROACH).to.equal(true)
			expect(SOUND.CROWD.VOICES_PER_SOUNDER).to.equal(1)
			expect(SOUND.CROWD.MAX_STEP_VOICES).to.equal(1)
		end)

		it("names the distances the approach grunt is armed and re-armed at", function()
			-- The EVENT itself is driven end to end in `boar_shot.spec` ("the GROUP grunts once as it
			-- comes in"); these are the two numbers that rule has to keep: a group must be well
			-- inside hearing before it speaks, and it must go a good way back out before it may
			-- speak again, or a herd milling on the road mutters at the hunter for a minute.
			expect(SOUND.GRUNTS.CLOSE_STUDS > 0).to.equal(true)
			expect(SOUND.GRUNTS.REARM_STUDS > SOUND.GRUNTS.CLOSE_STUDS).to.equal(true)
			expect(SOUND.GRUNTS.audibleStuds > SOUND.GRUNTS.CLOSE_STUDS).to.equal(true)
		end)
	end)
end
