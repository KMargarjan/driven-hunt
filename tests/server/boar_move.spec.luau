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
	describe("a shot heard ends at the exit and nowhere else (task 150)", function()
		-- KAREN, 2026-10-10 ~21:20: *"after shoot they run then com closer to road and stay / let's
		-- make this way / once they hear shoot they run and don't stop"*.
		--
		-- WHAT SHE WATCHED WAS THE CONFIG DOING ITS JOB: `SHOT_SPRINT_SECONDS` of bolt (4) and
		-- `FLIGHT_MIN_STUDS` of latched line (300), and then the pace clamp's `spooked` goes false,
		-- the animal drops to `PACE.WALK_SPEED`, and `CALM_TIME` of quiet settles it into IDLE --
		-- grazing, beside the road it has just walked back to.
		--
		-- THE TWO STATES ARE THE FLAG'S, which is the shape `docs/design/feature-flags.md` 13.3 asks
		-- for: `SENSE.SHOT_FLIGHT_UNTIL_EXIT` on and off, with everything else identical.
		local function flown(untilExit: boolean)
			local config = moveConfig(true)
			local sense = table.clone(config.SENSE)
			sense.SHOT_FLIGHT_UNTIL_EXIT = untilExit
			config.SENSE = sense
			local brain = Brain.new(config, FIELD, START, Random.new(77))
			-- the third argument is what says the fright was a BANG rather than a beater
			brain:spook(Vector3.new(0, 0, 60), nil, true)
			local position = START
			local slowest, calmAt, goneAt = math.huge, nil, nil
			local seconds = 40
			for frame = 1, math.ceil(seconds / DT) do
				local intent = brain:step(DT, obs(position, {}))
				position += intent.targetVelocity * DT
				-- STOP MEASURING WHEN IT HAS LEFT, and that was this case's own first mistake: an
				-- animal that reaches `field.exitZ` goes GONE and publishes a zero velocity, so
				-- "the slowest it ever went" came out 0.0 at 22.0 s -- the moment it SUCCEEDED.
				if brain:state() == "GONE" then
					goneAt = goneAt or frame * DT
					break
				end
				-- past the ACCEL ramp, which is the only reason the first second is slow
				if frame > math.ceil(1 / DT) then
					local flat = Vector3.new(intent.targetVelocity.X, 0, intent.targetVelocity.Z)
					slowest = math.min(slowest, flat.Magnitude)
				end
				if calmAt == nil and brain:state() == "IDLE" then
					calmAt = frame * DT
				end
			end
			return slowest, calmAt, goneAt
		end

		it("latches on what the CALLER asked for, not on what frightened it (task 154)", function()
			-- KAREN, 2026-10-11, about a beater and a horn and not about a gun: *"once I get a bit
			-- closer they just run away without stop it's not like they cool down they spooked and
			-- run away"* and *"horn reach is further once they hear also run without stop"*. So the
			-- third argument is "this fright does not wear off" and NOT "this fright was a bang" --
			-- which is why it is called `untilExit` since this task.
			--
			-- THE CONFIG IS THE SAME IN BOTH HALVES, which is the whole point: with
			-- `SHOT_FLIGHT_UNTIL_EXIT` on, the ordinary push the drive has always made still wears
			-- off, and only a fright that ASKS to latch latches.
			local function latched(untilExit: boolean?): boolean
				local brain = Brain.new(moveConfig(true), FIELD, START, Random.new(31))
				brain:spook(Vector3.new(0, 0, 60), nil, untilExit)
				local position = START
				for _ = 1, math.ceil(40 / DT) do
					local intent = brain:step(DT, obs(position, {}))
					position += intent.targetVelocity * DT
					if brain:state() == "GONE" then
						return true -- it left, which is the only way a latched flight ends
					end
					if brain:state() == "IDLE" then
						return false -- it settled
					end
				end
				return false
			end

			expect(latched(true)).to.equal(true)
			expect(latched(false)).to.equal(false)
			expect(latched(nil)).to.equal(false)
			TestKit.note("spook(from, nil, true) leaves and never settles; the drive's own push still calms down")
		end)

		it("runs at a RUN until it is off the board, where the flag off slows to a walk", function()
			local onSlowest, onCalm, onGone = flown(true)
			local offSlowest, offCalm, offGone = flown(false)
			TestKit.note(
				string.format(
					"shot flight: ON slowest %.1f studs/s, calm %s, gone at %s | OFF slowest %.1f, calm %s, gone %s",
					onSlowest,
					tostring(onCalm),
					tostring(onGone),
					offSlowest,
					tostring(offCalm),
					tostring(offGone)
				)
			)
			-- ON: it leaves, it never stopped running on the way, and it was never IDLE.
			expect(onGone).to.be.ok()
			expect(onSlowest >= CONFIG.PACE.RUN_SPEED - 1e-3).to.equal(true)
			expect(onCalm).to.equal(nil)
			-- OFF: the same animal and the same bang drops below a trot -- `MOVE.FLIGHT_MIN_STUDS`
			-- of line and `SENSE.SHOT_SPRINT_SECONDS` of bolt run out and the pace clamp puts it on
			-- `PACE.WALK_SPEED`. That is the behaviour Karen described and what this flag ends.
			expect(offSlowest < CONFIG.PACE.TROT_SPEED).to.equal(true)
		end)
	end)

	describe("wedged against a trunk (task 150)", function()
		-- KAREN, 2026-10-10 ~21:20, for the third playtest running: *"still can see sometimes boar
		-- hit tree and wal in place so not avoiding tree"*.
		--
		-- THE WORLD IS THE TEST: the animal is handed the SAME position every frame, which is what
		-- being pinned against a trunk looks like from inside the Brain -- a setpoint that says run
		-- and ground that does not pass. Nothing else here is special.
		-- IT IS LET GO FIRST, AND THAT WAS THIS CASE'S OWN FIRST MISTAKE. A freshly spooked animal
		-- swings onto its latched flight line, which is up to 179 degrees of turn in the first half
		-- second -- so a baseline taken on frame one measured the flight latch and not the sidestep,
		-- and both worlds "turned" at 0.45 s. It runs for two seconds with the ground passing under
		-- it, exactly as it would in the wood, and only then walks into something.
		local SETTLE = 2
		local function turnedAfter(seconds: number, wedge: boolean)
			local config = moveConfig(true)
			local move = table.clone(config.MOVE)
			if not wedge then
				move.WEDGE_SECONDS = nil -- the detector off, everything else identical
			end
			config.MOVE = move
			local brain = Brain.new(config, FIELD, START, Random.new(97))
			brain:spook(Vector3.new(0, 0, 60))
			local position = START
			for _ = 1, math.ceil(SETTLE / DT) do
				local intent = brain:step(DT, obs(position, {}))
				position += intent.targetVelocity * DT
			end
			-- ...and now the trunk: the same position every frame, for an animal still told to run.
			local first, turnedAt = nil, nil
			for frame = 1, math.ceil(seconds / DT) do
				local intent = brain:step(DT, obs(position, {}))
				local facing = intent.facing
				if facing.Magnitude > 1e-6 then
					local unit = facing.Unit
					if first == nil then
						first = unit
					else
						local dot = math.clamp(first:Dot(unit), -1, 1)
						if turnedAt == nil and math.deg(math.acos(dot)) >= 60 then
							turnedAt = frame * DT
						end
					end
				end
			end
			return turnedAt
		end

		it("turns across the obstruction inside WEDGE_SECONDS, where before it pushed for two", function()
			-- THE WINDOW IS 1.5 s ON PURPOSE. `STUCK_TIME` is 2 s and the old recovery fires on the
			-- tick THAT window closes, so anything inside 1.5 s is the new detector and nothing
			-- else: the comparison cannot be contaminated by the recovery it is replacing.
			local withWedge = turnedAfter(1.5, true)
			local without = turnedAfter(1.5, false)
			TestKit.note(
				string.format(
					"wedge: turned 60 deg at %s s with the detector, %s without",
					tostring(withWedge),
					tostring(without)
				)
			)
			expect(withWedge).to.be.ok()
			expect((withWedge :: number) <= CONFIG.MOVE.WEDGE_SECONDS + 0.5).to.equal(true)
			expect(without).to.equal(nil)
		end)

		it("never fires on an animal that is actually covering ground", function()
			-- THE FALSE POSITIVE IS THE RISK, and this is the case that holds it down: the same
			-- frightened animal, running the same latched line, with its position INTEGRATED from
			-- its own intent so the ground really does pass under it. A detector that turned this
			-- one would turn every boar in the wood ninety degrees every 0.75 s.
			local brain = Brain.new(moveConfig(true), FIELD, START, Random.new(98))
			brain:spook(Vector3.new(0, 0, 60))
			local position = START
			-- the same two seconds of settling as the case above, for the same reason
			for _ = 1, math.ceil(SETTLE / DT) do
				local intent = brain:step(DT, obs(position, {}))
				position += intent.targetVelocity * DT
			end
			local first, worst = nil, 0
			for _ = 1, math.ceil(3 / DT) do
				local intent = brain:step(DT, obs(position, {}))
				position += intent.targetVelocity * DT
				local facing = intent.facing
				if facing.Magnitude > 1e-6 then
					if first == nil then
						first = facing.Unit
					else
						local dot = math.clamp(first:Dot(facing.Unit), -1, 1)
						worst = math.max(worst, math.deg(math.acos(dot)))
					end
				end
			end
			TestKit.note(string.format("wedge: a running boar turned at most %.1f deg in 3 s", worst))
			expect(worst < 60).to.equal(true)
			expect(Vector3.new(position.X - START.X, 0, position.Z - START.Z).Magnitude > 30).to.equal(true)
		end)
	end)

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

		it("LOOKS BACK 150 DEGREES OVER THE WHOLE CHECK AND NEVER REVERSES (task 251 part 2)", function()
			-- ROUND 1'S BLOCKING FINDING, AND IT IS THE CASE THAT CATCHES IT. The pure helper
			-- (`Brain.lookBack`, driven in `deer.spec`) was right and the COMPOSED path was not: the
			-- branch measured its 150 degrees from `self._desired`, which is the field the turn-rate
			-- slew at the bottom of `_step` rewrites every tick -- so the limit clamped one FRAME's
			-- rotation, the angle shrank tick by tick, fell under 150, and the animal came right round
			-- to stare at the man and then set off on that heading. At `PACE.WALK_TURN_DEG` 90 deg/s a
			-- 180-degree reversal takes about 2 s, which is inside the stag's own 2-6 second check.
			--
			-- SO THIS CASE DRIVES A WHOLE CHECK, step by step, with the man DEAD ASTERN -- the worst
			-- case, and the only one where a clamp at 150 is distinguishable from no clamp at all.
			local config = moveConfig(true)
			local move = table.clone(config.MOVE)
			move.EDGE_LOOK_BACK_DEG = 150
			-- The chance is forced so no seed hunting is needed: the claim is about the POSE, and the
			-- roll is `deer.spec`'s and `boar_move`'s own case above.
			move.EDGE_CHANCE = 1
			config.MOVE = move
			-- ...AND `LINE` IS ON, because that is what lets the approach below be a real one:
			-- `Brain:leadTo` refuses outright with it off, which is how the first run of this case
			-- found itself asserting an IDLE wander's heading. It is the drive's own switch and it is
			-- on in the Forest Test (`ForestTestBoot`), which is where this behaviour lives.
			local line = table.clone(config.LINE)
			line.ENABLED = true
			config.LINE = line

			local brain = Brain.new(config, FIELD, START, Random.new(7))
			-- IT ARRIVES WALKING SOUTH, which is what every line in this game does: the road is south
			-- and `releaseLine` walks them at it. Two seconds of ordered walking settle `_desired` onto
			-- that heading through the same slew, so the latch is taken from a real approach and not
			-- from a hand-written vector.
			local toward = Vector3.new(0, 0, -1)
			local position = START
			for _ = 1, math.ceil(2 / DT) do
				brain:leadTo(Vector3.new(0, 0, -200), 4.5)
				local intent = brain:step(DT, obs(position, {}))
				position += intent.targetVelocity * DT
			end
			local arrived = brain:step(DT, obs(position, {})).facing.Unit
			expect(arrived:Dot(toward) > 0.99).to.equal(true)

			-- THE MAN IS BEHIND HIM, 40 STUDS NORTH -- 180 degrees off the way he came, and
			-- deliberately beyond every reaction radius this config has: `SENSE.NOTICE_STANDING` 25,
			-- `SENSE.FLUSH_STUDS` 15 and `PACE.SPOOK_STUDS` 30. So he is the NEAREST thing and nothing
			-- else -- no ALERT, no flush, no spook -- which is what makes this a case about the POSE
			-- and about nothing else. (`Brain.perceive` reports `nearest` for any stimulus at any
			-- distance, which is why 40 studs is still seen.)
			local behind = { { id = "h", position = position + Vector3.new(0, 0, 40), kind = "shooter", speed = 0 } }
			expect(brain:check(4)).to.equal(true)
			local facing = arrived
			for _ = 1, math.ceil(3.5 / DT) do
				local intent = brain:step(DT, obs(position, behind))
				-- IT REALLY IS STOPPED for the whole check, which is the other half of the claim: a
				-- look back that walked would be a turn and not a stop.
				expect(intent.targetVelocity.Magnitude < 0.001).to.equal(true)
				if intent.facing.Magnitude > 1e-6 then
					facing = intent.facing.Unit
				end
			end

			-- IT CAME ROUND, and it came round to 150 degrees and stopped there. The dead band
			-- (`PACE.TURN_DEADBAND_DEG`) is what the tolerance is for: the slew stops inside it.
			local degrees = math.deg(math.acos(math.clamp(facing:Dot(arrived), -1, 1)))
			local band = config.PACE.TURN_DEADBAND_DEG or 4
			TestKit.note(
				string.format(
					"task251 look back: arrived on (%.2f, %.2f), ended %.1f deg off it (asked 150, dead band %.0f)",
					arrived.X,
					arrived.Z,
					degrees,
					band
				)
			)
			expect(degrees > 150 - band - 1).to.equal(true)
			-- **AND THIS IS THE ASSERTION THAT FAILS WITHOUT THE LATCH**: unclamped it reaches ~180
			-- (the man's own direction) and keeps it.
			expect(degrees < 150 + band + 1).to.equal(true)

			-- ...AND A BOAR, WHICH CARRIES `EDGE_LOOK_BACK_DEG` 0, DOES NOT TURN AT ALL: the same
			-- approach, the same man, the behaviour task 126 shipped. Without this the case would pass
			-- for an animal that always looked back, which is not what any row asks for.
			local plain = moveConfig(true)
			local plainMove = table.clone(plain.MOVE)
			plainMove.EDGE_CHANCE = 1
			plain.MOVE = plainMove
			expect(plainMove.EDGE_LOOK_BACK_DEG).to.equal(0)
			local plainLine = table.clone(plain.LINE)
			plainLine.ENABLED = true
			plain.LINE = plainLine
			local boar = Brain.new(plain, FIELD, START, Random.new(7))
			local at = START
			for _ = 1, math.ceil(2 / DT) do
				boar:leadTo(Vector3.new(0, 0, -200), 4.5)
				local intent = boar:step(DT, obs(at, {}))
				at += intent.targetVelocity * DT
			end
			local boarArrived = boar:step(DT, obs(at, {})).facing.Unit
			expect(boar:check(4)).to.equal(true)
			local boarFacing = boarArrived
			local boarBehind = { { id = "h", position = at + Vector3.new(0, 0, 40), kind = "shooter", speed = 0 } }
			for _ = 1, math.ceil(3.5 / DT) do
				local intent = boar:step(DT, obs(at, boarBehind))
				if intent.facing.Magnitude > 1e-6 then
					boarFacing = intent.facing.Unit
				end
			end
			expect(math.deg(math.acos(math.clamp(boarFacing:Dot(boarArrived), -1, 1))) < 1).to.equal(true)
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

	describe("avoidance BEFORE the contact (task 167)", function()
		-- KAREN, 2026-10-12 ~16:10: *"also when boars running sometimes hit the tree"*. The third
		-- playtest running. What was there was two RECOVERIES (task 150's wedge detector, task 139's
		-- honest clip) and one reflex: three 9-stud rays answered with a fixed 55-degree turn. A
		-- speed-scaled reach alone was measured at 24 contacts against 24 and left off. So the turn
		-- is the thing that changed: `Brain.clearTurnDeg` sweeps candidate headings and takes the
		-- SMALLEST one with room for the body.

		it("takes the smallest clear turn, and its own side breaks the tie", function()
			-- Everything inside 30 degrees is blocked; both 35s are clear.
			local tried = {}
			local function blocked(degrees: number)
				table.insert(tried, degrees)
				return math.abs(degrees) < 30
			end
			local turn, casts = Brain.clearTurnDeg({ 12, 22, 35, 50 }, 1, blocked, 10)
			expect(turn).to.equal(35) -- +35 before -35: its own side first
			expect(casts).to.equal(5) -- 12, -12, 22, -22, 35
			-- SMALLEST FIRST, which is what makes it an avoidance and not a swerve.
			expect(tried[1]).to.equal(12)
			expect(tried[2]).to.equal(-12)

			-- ...and the mirror: the same readings, the other side, turns the other way.
			local mirrored = Brain.clearTurnDeg({ 12, 22, 35, 50 }, -1, blocked, 10)
			expect(mirrored).to.equal(-35)
		end)

		it("picks the side that actually has room, whichever side the animal prefers", function()
			-- A trunk to the LEFT: every negative heading is blocked, so it goes right even though
			-- the animal's own side is left. Committing to a blocked side is how it hits the tree.
			local function blocked(degrees: number)
				return degrees <= 0
			end
			expect(Brain.clearTurnDeg({ 12, 22, 35 }, -1, blocked, 10)).to.equal(12)
			expect(Brain.clearTurnDeg({ 12, 22, 35 }, 1, blocked, 10)).to.equal(12)
		end)

		it("answers nil when it is boxed in, and leaves the dead end to the wedge detector", function()
			local function blocked()
				return true
			end
			local turn, casts = Brain.clearTurnDeg({ 12, 22, 35 }, 1, blocked, 10)
			expect(turn).to.equal(nil)
			expect(casts).to.equal(6) -- three magnitudes, both sides
		end)

		it("spends no more casts than the budget, whatever the fan is asked for", function()
			local spent = 0
			local function blocked()
				spent += 1
				return true
			end
			local turn, casts = Brain.clearTurnDeg({ 12, 22, 35, 50, 70, 85 }, 1, blocked, 3)
			expect(turn).to.equal(nil)
			expect(casts).to.equal(3)
			expect(spent).to.equal(3)
		end)

		it("deflects by the MEASURED turn and not by the fixed 55, and fires with the rays all clear", function()
			local on = moveConfig(true)
			local NORTH = Vector3.new(0, 0, 1)
			-- THE WHOLE POINT OF THE LOOKAHEAD: the swept fan reaches up to `AVOID_MAX_STUDS` and the
			-- three rays reach 9, so a trunk 20 studs ahead is seen by one and not the other. Before
			-- this task `steerAroundTrunk` returned early on exactly this reading.
			local far = { ahead = false, left = false, right = false, clearDeg = 12 }
			local steered = Brain.steerAroundTrunk(NORTH, far, on, 1, false)
			expect(steered.X < 0).to.equal(true) -- turned, from a reading that used to turn nothing
			-- 12 DEGREES AND NOT 55: a gentle early turn is the difference between threading the
			-- trees and swerving across the drive.
			local angle = math.deg(math.acos(math.clamp(steered:Dot(NORTH), -1, 1)))
			expect(angle).to.be.near(12, 0.01)
			expect(on.PACE.WHISKER_TURN_DEG).to.equal(55) -- the walk's number, unchanged

			-- ...AND IT WINS OVER THE RAYS when both are reading, because it is a measurement of
			-- where the BODY fits and they are three lines from its centre.
			local both = { ahead = true, left = true, right = false, clearDeg = -22 }
			local overridden = Brain.steerAroundTrunk(NORTH, both, on, 1, false)
			local overriddenAngle = math.deg(math.acos(math.clamp(overridden:Dot(NORTH), -1, 1)))
			expect(overriddenAngle).to.be.near(22, 0.01)
			expect(overridden.X > 0).to.equal(true) -- the fan's side, not the rays'

			-- WITH NO FAN ANSWER the old behaviour is byte for byte what it was.
			local rays = { ahead = true, left = true, right = false }
			local old = Brain.steerAroundTrunk(NORTH, rays, on, 1, false)
			local oldAngle = math.deg(math.acos(math.clamp(old:Dot(NORTH), -1, 1)))
			expect(oldAngle).to.be.near(55, 0.01)
		end)

		it("commits to the side the fan found, so the deflection does not flip frame to frame", function()
			-- `Brain:avoidSide()` is what the Runtime hands the fan as its first guess, and task 126
			-- measured the alternative at 1,385 degrees of turning in ten seconds.
			local on = moveConfig(true)
			local brain = Brain.new(on, FIELD, START, Random.new(7))
			local before = brain:avoidSide()
			expect(before == 1 or before == -1).to.equal(true)
			local reading = obs(START, {})
			reading.whisker = { ahead = false, left = false, right = false, clearDeg = -35 }
			brain:step(DT, reading)
			expect(brain:avoidSide()).to.equal(-1) -- the side the fan found room on
			-- ...and it is HELD: the next tick's reading cannot swap it inside
			-- `WHISKER_HOLD_SECONDS`.
			local flipped = obs(START, {})
			flipped.whisker = { ahead = true, left = false, right = true, clearDeg = nil }
			brain:step(DT, flipped)
			expect(brain:avoidSide()).to.equal(-1)
		end)

		it("names the numbers the fan ships with, and the relations between them", function()
			local move = CONFIG.MOVE
			expect(move.AVOID_ENABLED).to.equal(true)
			-- FROM A TROT UP: the walk keeps the 9-stud whiskers Karen has already accepted.
			expect(move.AVOID_FROM_SPEED).to.equal(CONFIG.PACE.TROT_SPEED)
			expect(move.AVOID_FROM_SPEED < CONFIG.PACE.RUN_SPEED).to.equal(true)
			-- THE LOOKAHEAD HAS TO BEAT THE OLD ONE AT A RUN, or nothing has changed: at
			-- `RUN_SPEED` the reach is longer than the 9 studs three rays give.
			local atRun =
				math.clamp(CONFIG.PACE.RUN_SPEED * move.AVOID_SECONDS, move.AVOID_MIN_STUDS, move.AVOID_MAX_STUDS)
			expect(atRun > CONFIG.MOVE.WHISKER_MIN_STUDS).to.equal(true)
			expect(atRun > CONFIG.BODY_SIZE.Z * 2).to.equal(true) -- more than two body lengths
			-- THE SWEEP IS AT LEAST THE BODY'S OWN HALF-WIDTH, or it is answering for a ray again.
			expect(move.AVOID_RADIUS_STUDS >= CONFIG.BODY_SIZE.X / 2).to.equal(true)
			-- SMALLEST FIRST, ascending, and never a full reversal.
			local angles = move.AVOID_ANGLES_DEG
			expect(#angles > 0).to.equal(true)
			for index = 2, #angles do
				expect(angles[index] > angles[index - 1]).to.equal(true)
			end
			expect(angles[#angles] < 90).to.equal(true)
			-- THE BUDGET IS A CEILING ON CASTS PER ANIMAL PER SECOND, and it is the Director's own
			-- condition: `AVOID_HZ` evaluations, each one forward sweep plus at most `AVOID_CASTS`.
			expect(move.AVOID_HZ > 0).to.equal(true)
			expect(move.AVOID_CASTS > 0).to.equal(true)
			-- One forward sweep plus up to `AVOID_CASTS` at the far horizon and `AVOID_CASTS` at the
			-- nearer one: 104 swept casts a second for an animal running at a wall of trunks, against
			-- the 180 rays a second the three 9-stud whiskers beside it already cost at 60 Hz.
			expect(move.AVOID_NEAR_SCALE > 0 and move.AVOID_NEAR_SCALE < 1).to.equal(true)
			expect(move.AVOID_HZ * (2 * move.AVOID_CASTS + 1) <= 120).to.equal(true)
			-- ...and the measurement that says whether any of it worked is on.
			expect(move.COUNT_CONTACTS).to.equal(true)
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
