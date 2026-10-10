-- Boar.Brain: the boar's decisions. Pure: no services, no yields, no Instances, no randomness except
-- the injected Random. Everything it knows arrives in an Observation; everything it wants leaves in
-- an Intent. That is what lets tests/server/boar_brain.spec.luau drive 10000 ticks with no physics.
--
-- Pattern: a small explicit state machine deciding WHAT to do, with steering deciding HOW to move
-- (Buckland, "Programming Game AI by Example", 2005, ch. 2-3), on top of a navmesh route.
--   Reynolds, "Steering Behaviors For Autonomous Characters" (GDC 1999)
--     https://www.red3d.com/cwr/steer/gdc99/  -- wander keeps a heading and jitters it; flee; probe
--   Roblox PathfindingService (the route itself is fetched by init.luau, never here)
--     https://create.roblox.com/docs/characters/pathfinding
--
-- Since Milestone 1.5 it has five states, not three. WOUNDED is FLEE with exactly three
-- differences and no fourth: it never calms down (a mortally wounded animal does not go back to
-- grazing), its speed setpoint is scaled by the wound, and it is counting the studs it has run. Where
-- it runs -- the route to the exit line, the sideways bias away from the threat, the waypoints, the
-- Reynolds fallback, the stuck sidestep -- is the same code called from the same place. DOWN is the
-- carcass: speed zero, no path, and a countdown to the existing despawn path.
--
-- It is told a SEVERITY and a direction, never a damage number and never a zone table, so it cannot
-- be made to disagree with Boar.Wound: it does not hold a copy of the model. `collapse` arrives as a
-- boolean for the same reason.
--
-- Since task 118 it has EIGHT states, and the two new ones are what a boar does about something it
-- has noticed but is not yet running from: ALERT (head up, stopped, turned to the cause) and AVOID
-- (turned away, trotting off on a new heading). Both are behind `SENSE.ENABLED`; with it off this
-- file decides exactly what it decided before, on one 40-stud radius and drivers only.
--
-- Pattern for that half: awareness LEVELS with a dwell time and a refractory period, fed by ONE
-- sensory function, with a separate notice and flush radius per stimulus, and hearing as a world
-- event rather than a query.
--   Tom Leonard, "Building an AI Sensory System: Examining the Design of Thief: The Dark Project"
--     (GDC 2003) https://www.gamedeveloper.com/programming/building-an-ai-sensory-system-examining-the-design-of-i-thief-the-dark-project-i-
--   Unreal Engine AIPerception (per-sense configs, gain radius != lose radius, stimulus age)
--     https://dev.epicgames.com/documentation/en-us/unreal-engine/ai-perception-in-unreal-engine
--     -- pattern only, no code (Unreal EULA)
--
-- Design: docs/design/boar-ai.md (sections 4, 5, 7), docs/design/hit-zones.md (section 6),
--         docs/design/boar-behaviour.md (sections 3, 4, 5)
-- Note:   docs/research/2026-09-24-boar-ai.md, docs/research/2026-09-25-hit-zones.md,
--         docs/research/2026-10-04-boar-behaviour.md

local Brain = {}
Brain.__index = Brain

-- ONE TABLE SAYS WHICH STATES ARE CALM AND WHICH ARE PANICKED (task 118, design section 3.1), and
-- every consumer reads it -- the sounder's alarm, the herd's calm-down, and the specs -- so a ninth
-- state cannot be forgotten in one predicate somewhere. The classes are deliberately coarser than
-- the states: what the rest of the system ever needs to know is "is this animal settled, disturbed,
-- running, finished".
Brain.CLASS = {
	IDLE = "calm",
	ALERT = "calm",
	AVOID = "disturbed",
	FLEE = "panicked",
	WOUNDED = "panicked",
	CRIPPLED = "down",
	DOWN = "down",
	GONE = "gone",
}

-- A STATE THIS TABLE HAS NEVER HEARD OF reads as "gone": the conservative answer, because `gone` is
-- the one class that neither panics a sounder nor counts as calm, so a typo cannot start a stampede
-- and cannot pin a group in FLEE either. Every state in the system comes from `Brain:state()`, so in
-- practice the fallback is unreachable; it is here so that the function is total.
function Brain.classOf(state: string?): string
	if state == nil then
		return "gone"
	end
	return Brain.CLASS[state] or "gone"
end

-- HOW LONG THE FIRST ACTIVITY LASTS (task 117, made pure in review round 2). A boar that has just
-- spawned starts somewhere INSIDE its first activity, so two spawned on the same frame are not doing
-- the same thing for the rest of their lives. Pure, because the case that claimed this used to be a
-- tautology: two brains with different seeds disagree whatever this function does.
--
-- A ROW WHOSE BAND IS A SINGLE VALUE IS EXEMPT: `smell` is exactly one clip length, and cutting it
-- short would cut the 30.4 degree head lift off in the middle.
function Brain.firstPhase(duration: number, roll: number, row, config): number
	if row.maxSeconds <= row.minSeconds then
		return duration
	end
	local taken = math.clamp(roll, 0, 1) * config.FIRST_PHASE_SECONDS
	return math.max(duration - taken, config.FIRST_PHASE_FLOOR)
end

-- WHAT A CALM BOAR DOES NEXT (task 117). Pure: a roll in [0, 1) and the table in, one activity row
-- out, so every weight is a test case with no boar in the world. The draw is proportional to
-- `weight`, and the last row catches any float noise at the top of the range.
function Brain.calmActivity(roll: number, config)
	local activities = config.ACTIVITIES
	local total = 0
	for _, row in ipairs(activities) do
		total += row.weight
	end
	local cut = math.clamp(roll, 0, 1) * total
	local seen = 0
	for _, row in ipairs(activities) do
		seen += row.weight
		if cut < seen then
			return row
		end
	end
	return activities[#activities]
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function flatDistance(a: Vector3, b: Vector3): number
	return (flat(a) - flat(b)).Magnitude
end

-- Unit vector, or `fallback` when the input is degenerate. Never returns NaN.
local function unit(v: Vector3, fallback: Vector3): Vector3
	local m = v.Magnitude
	if m < 1e-6 then
		return fallback
	end
	return v / m
end

local function rotateY(v: Vector3, radians: number): Vector3
	local c, s = math.cos(radians), math.sin(radians)
	return Vector3.new(v.X * c - v.Z * s, 0, v.X * s + v.Z * c)
end

-- Signed angle from `a` to `b` about +Y, in (-pi, pi]. Both must be flat and non-zero.
local function angleBetween(a: Vector3, b: Vector3): number
	return math.atan2(a.X * b.Z - a.Z * b.X, a.X * b.X + a.Z * b.Z)
end

-- Rotate `from` toward `to` by at most `maxRadians`. This is the turn-rate limit: the boar never
-- snaps 180 degrees, and the spec asserts it step by step.
local function slew(from: Vector3, to: Vector3, maxRadians: number): Vector3
	local delta = angleBetween(from, to)
	if math.abs(delta) <= maxRadians then
		return to
	end
	return unit(rotateY(from, maxRadians * math.sign(delta)), from)
end

-- ---------------------------------------------------------------- perception: ONE function
--
-- Design: docs/design/boar-behaviour.md section 4. All of it is pure, module-level and exported on
-- `Brain` (and through `Boar`) for the reason `Brain` and `Wound` are already exported: every band,
-- every radius and every tie is then a spec case with no boar in the world at all.
--
-- A stimulus is anything a boar can perceive: `{ id, position, kind?, speed? }`. `kind` nil means
-- "driver", which is today's meaning, so a provider written before this task is unchanged. `speed`
-- is studs/s, flat, and is filled by the RUNTIME and never by the provider (section 4.6): a
-- character's own velocity is network-owned by its client, and a measured displacement of the
-- replicated position is not.

-- `flee` > `avoid` > `alert` > `none`: the strongest reaction any one stimulus produces is what the
-- animal does, and a tie goes to the nearest.
local REACTION_RANK = { flee = 3, avoid = 2, alert = 1, none = 0 }

function Brain.isMoving(threat, config): boolean
	-- A DOG IS ALWAYS COUNTED AS MOVING (section 4.2's radii table). A dog that is standing still is
	-- a dog that is about to not be, and a flusher's radii are its moving ones whatever it is doing
	-- at the instant it is looked at. HOOK ONLY: nothing produces `kind = "dog"` yet.
	if threat.kind == "dog" then
		return true
	end
	return (threat.speed or 0) >= config.SENSE.MOVING_SPEED
end

-- HOW FAR AWAY THIS STIMULUS IS NOTICED (head up, or turned away from). With the flag OFF there is
-- one radius for everything, which IS today: `DETECT_RADIUS`.
function Brain.noticeRadius(threat, config): number
	local sense = config.SENSE
	if not (sense and sense.ENABLED) then
		return config.DETECT_RADIUS
	end
	-- A DOG'S RADII ARE HALF AGAIN A PERSON'S, because a dog is a flusher -- and it always counts as
	-- moving (see `isMoving`), so a dog is noticed at 90 studs.
	local scale = if threat.kind == "dog" then sense.DOG_NOTICE_SCALE else 1
	return (if Brain.isMoving(threat, config) then sense.NOTICE_MOVING else sense.NOTICE_STANDING) * scale
end

-- ...AND HOW CLOSE IT HAS TO BE TO MAKE THE ANIMAL RUN. A man this close bolts a boar whatever it
-- was doing. `DETECT_RADIUS` keeps its value and its meaning for a MOVING person, so the number
-- Milestone 1.2 was built and reviewed on is untouched.
function Brain.fleeRadius(threat, config): number
	local sense = config.SENSE
	if not (sense and sense.ENABLED) then
		return config.DETECT_RADIUS
	end
	local scale = if threat.kind == "dog" then sense.DOG_NOTICE_SCALE else 1
	return (if Brain.isMoving(threat, config) then config.DETECT_RADIUS else sense.FLUSH_STUDS) * scale
end

-- WHAT THIS BOAR CAN PERCEIVE AND WHAT IT SHOULD DO ABOUT IT, in one answer. It replaces
-- `Brain:_threatInfo` rather than sitting beside it: two functions answering the same question is
-- how two correct rules come to disagree.
--
-- `probe` is optional and is used ONLY when `SENSE.REQUIRE_SIGHT` is on, which it is not: it is the
-- hook of section 4.7, and the Runtime hands it in on a sense tick only, so a notice costs at most
-- one raycast per stimulus per 0.2 s rather than one per frame.
function Brain.perceive(position: Vector3, threats, config, probe)
	local sense = config.SENSE
	local on = sense ~= nil and sense.ENABLED == true

	local reaction, cause, distance = "none", nil, math.huge
	local nearest, nearestDistance = nil, math.huge
	local sum, inside = Vector3.zero, 0
	local calm = true
	-- IS ANYTHING HERE A SPOOK RATHER THAN A PUSH (task 123 round 2)? A separate answer from
	-- `reaction`, because `reaction` keeps only the BEST single cause and a hunter 25 studs away
	-- loses that comparison to a beater 11 studs away -- which is the one case where getting it
	-- wrong matters, since the beater is always closer by construction.
	local pace = config.PACE
	local spook = false

	for _, threat in ipairs(threats or {}) do
		-- WITH THE FLAG OFF, ONLY A DRIVER IS A STIMULUS AT ALL. `MatchBoot` wires the shooters in
		-- unconditionally (section 8), so this one test is the whole of "a shooter standing on a
		-- post is invisible to a boar, exactly as before task 118" -- one assertion in a pure spec
		-- instead of a branch at the composition root that nothing can test.
		if on or (threat.kind or "driver") == "driver" then
			local d = flatDistance(position, threat.position)
			if d < nearestDistance then
				nearest, nearestDistance = flat(threat.position), d
			end
			-- A nil kind is a DRIVER, exactly as the test above reads it: that is what every
			-- stimulus was before kinds existed, and a world that names none still pushes.
			if pace ~= nil and pace.ENABLED == true then
				if (threat.kind or "driver") ~= "driver" then
					-- A man who is not driving -- a hunter at a stand -- at `SPOOK_STUDS`.
					if d <= pace.SPOOK_STUDS then
						spook = true
					end
				elseif threat.phantom ~= true and pace.DRIVER_RUN_STUDS ~= nil then
					-- A REAL driver right on top of the animal (task 123 round 5). `phantom` is the
					-- drive's own mark on the beater it invented; a stimulus with a player behind it
					-- never carries it, so "real" is the default and a world that marks nothing
					-- behaves as Karen asked.
					if d <= pace.DRIVER_RUN_STUDS then
						spook = true
					end
				end
			end

			local flee = Brain.fleeRadius(threat, config)
			local notice = Brain.noticeRadius(threat, config)
			if d <= flee then
				-- The centroid is the ROUTE'S ANCHOR and it is the centroid of what is actually
				-- flushing the animal, which with the flag off is "inside DETECT_RADIUS": today.
				sum += flat(threat.position)
				inside += 1
			end
			-- THE CALM TEST (section 4.3), per stimulus rather than against one global radius. With
			-- the flag off `notice` is `DETECT_RADIUS` and the margin is `CALM_RADIUS -
			-- DETECT_RADIUS`, so this is arithmetically `nearestDistance > CALM_RADIUS`: today.
			if d <= notice + (if on then sense.CALM_MARGIN else config.CALM_RADIUS - config.DETECT_RADIUS) then
				calm = false
			end

			local mine = "none"
			if d <= flee then
				mine = "flee"
			elseif on and d <= notice and Brain.sees(position, threat, config, probe) then
				mine = if Brain.isMoving(threat, config) then "avoid" else "alert"
			end

			local better = REACTION_RANK[mine] > REACTION_RANK[reaction]
				or (mine ~= "none" and REACTION_RANK[mine] == REACTION_RANK[reaction] and d < distance)
			if better then
				reaction, cause, distance = mine, threat, d
			end
		end
	end

	return {
		reaction = reaction,
		cause = cause,
		distance = distance,
		-- nil when there is nothing at all, and the nearest stimulus when there is one but nothing
		-- is inside a flush radius: the two answers `_threatInfo` gave, unchanged.
		centroid = if inside > 0 then sum / inside else nearest,
		nearest = nearest,
		nearestDistance = nearestDistance,
		calm = calm,
		-- True when something that is NOT a driver is inside `PACE.SPOOK_STUDS` (task 123 round 2).
		spook = spook,
	}
end

-- LINE OF SIGHT, AND IT IS OFF (section 4.7). With `REQUIRE_SIGHT` false -- the shipped value -- this
-- is `true` for everything and costs one comparison. With it on, a NOTICE waits on a clear ray; a
-- FLUSH never does, because a boar that close has smelt and heard the man whatever is in the way.
function Brain.sees(position: Vector3, threat, config, probe): boolean
	local sense = config.SENSE
	if not (sense and sense.REQUIRE_SIGHT) then
		return true
	end
	if probe == nil then
		return true -- nobody handed us one: do not invent a wall
	end
	local eye = position + Vector3.new(0, config.BODY_SIZE.Y / 2, 0)
	local toward = threat.position - eye
	-- THE RAY IS AS LONG AS THE RAY, not as long as the FLAT distance (review round 2, note): a
	-- stimulus above or below the animal is further away along the line of sight than it is across
	-- the ground, and the shorter length would report clear air short of the thing in the way. Every
	-- BAND in this file is measured flat; this is the one place the two lengths differ, so the flat
	-- one is not passed in at all any more.
	local reach = toward.Magnitude
	if reach < 1e-6 then
		return true
	end
	return probe(eye, toward.Unit, reach) == false
end

-- ROUND A TRUNK, NOT INTO IT (task 123 round 3). Karen: *"they has to avoid trees to not stuck"*.
-- Pure: a direction and three boolean casts in, a direction out.
--
-- THREE CASTS AND NOT ONE. `obs.blockedAhead` already existed and all it could say was "something is
-- in front"; the animal's answer to that was `PROBE_TURN` with a RANDOM sign, redrawn on every sense
-- tick -- so it was as likely to turn back into the trunk as away from it, and the turning itself
-- read as twitch. With a whisker on each side the animal turns toward the side that is CLEAR, and
-- the ambiguous case uses the animal's OWN fixed side (`_whiskerSide`) rather than a fresh coin.
--
-- A FLANK TOUCH IS A NUDGE, NOT A SWERVE: half the angle, so an animal brushing past a trunk leans
-- off it instead of veering across the drive.
-- `locked` (task 126): when true, `prefer` IS the side and the two side tests below are skipped.
--
-- THE SIDE FLIPPING FRAME TO FRAME IS WHY A WEDGED ANIMAL SPINS. `whisker.left` and `whisker.right`
-- are three raycasts a frame against a forest of thin trunks, so they flicker -- and each flicker
-- swaps `side`, which swaps a 55-degree deflection, which the slew then chases at up to
-- `WALK_TURN_DEG` 90 deg/s. MEASURED: the worst ten-second turn in the whole trace, 1,385 degrees,
-- belonged to the one animal the stuck detector also reported -- Karen's *"they shouldn do circles"*
-- and her *"not hitting the trees and hang"* are the same defect seen from two sides.
function Brain.steerAroundTrunk(direction: Vector3, whisker, config, prefer: number, locked: boolean?): Vector3
	local pace = config.PACE
	if pace == nil or pace.ENABLED ~= true or whisker == nil then
		return direction
	end
	if not (whisker.ahead or whisker.left or whisker.right) then
		return direction
	end
	local turn = math.rad(pace.WHISKER_TURN_DEG)
	local side = if prefer < 0 then -1 else 1
	if locked == true then
		-- Committed: the side was chosen when this deflection began and is held until it ends.
		if whisker.left and whisker.right and whisker.ahead then
			turn *= 2
		end
		if not whisker.ahead then
			turn *= 0.5
		end
		return rotateY(direction, side * turn)
	end
	if whisker.left and not whisker.right then
		side = 1 -- something on the left: go right
	elseif whisker.right and not whisker.left then
		side = -1
	elseif whisker.left and whisker.right and whisker.ahead then
		-- Boxed in. Turn harder, the animal's own way, and let the existing stuck sidestep take over
		-- if that fails: this function never has to solve a dead end, only not to walk into a trunk.
		turn *= 2
	end
	if not whisker.ahead then
		turn *= 0.5
	end
	return rotateY(direction, side * turn)
end

-- WHERE AN AVOID GOES: away from the cause, rotated by a fixed angle, clamped inside the field.
--
-- INVENTED HERE, with the reason (CLAUDE.md rule 2): no source addresses "flee at an ANGLE rather
-- than away" -- Reynolds' flee is straight away and his wander has no cause at all -- it is three
-- lines of arithmetic, and it is one spec assertion. Karen asked for "turn around and go another
-- direction", which is neither of the two things steering already had.
--
-- THE SIGNATURE DIFFERS FROM design section 7.2's sketch, `(position, cause, config, rng)`, in two
-- ways and both are deliberate. It takes the FIELD, because section 4.4's own formula clamps to the
-- bounds and a function cannot clamp to bounds it was not given. And it takes the SIGN rather than a
-- `Random`: the sign is drawn once when the animal enters AVOID and kept in `_avoidTurn` (section
-- 4.4), so drawing it here would mean a new one on every call -- an animal that mirrors its heading
-- every sense tick instead of committing to one.
--
-- AND THE ANGLE IS MEASURED FROM THE LINE *TOWARD* THE CAUSE, not from the line away from it, which
-- is where section 4.4's pseudocode (`rotateY(away, 120 deg)`) says to measure it. That reading
-- cannot be what the design means, by its own arithmetic: 120 degrees off AWAY is 60 degrees off
-- TOWARD, whose radial component is cos 60 = +0.5, so the animal would CLOSE with the man at 9
-- studs a second -- against section 7.1's "past 90 degrees, so it is visibly a refusal, not a
-- sidestep" and against section 12 case 6's "the flat distance to the cause grows". Measured from
-- TOWARD, the dial reads as it is documented: 90 is a pure sidestep, 180 is a straight flee, and
-- 120 opens the distance at cos 120 = -0.5.
function Brain.avoidTarget(position: Vector3, cause: Vector3, sign: number, config, field): Vector3
	local toward = unit(flat(cause) - flat(position), Vector3.new(0, 0, -1))
	local turn = math.rad(config.SENSE.AVOID_TURN_DEG) * (if sign < 0 then -1 else 1)
	return Brain.insideField(flat(position) + rotateY(toward, turn) * config.SENSE.AVOID_STUDS, config, field)
end

-- One steering target, kept off the edge by the same `EDGE_MARGIN` the route already uses, so an
-- AVOID never aims the animal at a wall it would then be stuck against.
function Brain.insideField(point: Vector3, config, field): Vector3
	local bounds = field.bounds
	local margin = config.EDGE_MARGIN
	return Vector3.new(
		math.clamp(point.X, bounds.minX + margin, bounds.maxX - margin),
		field.groundY,
		math.clamp(point.Z, bounds.minZ + margin, bounds.maxZ - margin)
	)
end

function Brain.new(config, field, start: Vector3, rng: Random)
	local self = setmetatable({}, Brain)
	self._config = config
	self._field = field
	self._rng = rng

	self._state = "IDLE"
	self._home = flat(start)
	self._heading = unit(rotateY(Vector3.new(0, 0, 1), rng:NextNumber(-math.pi, math.pi)), Vector3.new(0, 0, 1))
	self._speed = 0 -- current speed setpoint, ramped by ACCEL
	self._desired = self._heading -- current desired direction, slewed by TURN_RATE

	self._sinceSense = math.huge -- sense on the very first step
	self._sinceRepath = math.huge
	self._sinceCalm = 0
	self._grazeFor = 0

	-- THE CALM REPERTOIRE (task 117): which activity an idle boar is doing and how long is left of
	-- it. nil means "pick one on the next step". The first one starts PART-WAY THROUGH, so a sounder
	-- of five is not five animals doing the same thing on the same frame.
	self._calm = nil :: any
	self._calmFor = 0
	-- Whether the first activity has been phased yet. Declared here with the rest of the block
	-- rather than springing into existence inside `_stepCalm` (review round 2, note).
	self._calmPhased = false
	-- HOW MANY ACTIVITIES THIS BOAR HAS DRAWN. Published with the name, because a name alone cannot
	-- say "a new one began": the same row drawn twice running reads as one long activity and its clip
	-- is never replayed (review round 3, note). It is also what makes the no-repeat rule observable
	-- from outside -- one draw per name change, and never two draws on one name.
	self._calmDraws = 0

	-- being shot (hit-zones design section 6.2)
	self._boltFor = 0 -- seconds of "run whatever the threats say", counted down with dt
	self._lastShotPoint = nil :: Vector3?
	-- HAS IT PASSED THE GUNS? One way, set the first sense tick a threat is on the far side from the
	-- exit, read by `_senseAware`'s row 10b (task 149b).
	self._crossed = false
	-- HAS IT HEARD A SHOT? One way, for the rest of its life here (task 150). Karen: *"once they
	-- hear shoot they run and don't stop"*. Set by `spook` when the fright IS a bang; read by
	-- `_flightActive`, `_settle`, `_senseAware`'s row 6b and the pace clamp, which between them are
	-- every path that could slow this animal down or turn it round.
	self._heardShot = false
	self._carcassFor = 0
	self._downedReported = false

	self._waypoints = nil :: { Vector3 }?
	self._consumed = 0 -- waypoints of the current route already passed; see Brain:consumed()
	self._target = nil :: Vector3?
	self._threatPoint = nil :: Vector3?

	self._stuckFrom = flat(start)
	-- WHERE IT IS, kept every step (task 126 round 2). `spook` is called from OUTSIDE -- a shot, a
	-- hit, a herd-mate's alarm -- and had nothing but `_stuckFrom` to latch a flight from, which is
	-- only refreshed every `STUCK_TIME` (2 s) while moving: at 24 studs/s that is a point the animal
	-- left up to 48 studs ago, so both the flight HEADING and its odometer were measured from
	-- somewhere it no longer was.
	self._at = flat(start)
	self._stuckTime = 0
	self._stuckCount = 0
	-- THE FAST WEDGE TEST (task 150), beside the two-second one above and measured the same way:
	-- where the animal was when this window opened, and how long it has been open. `_wedgeFor` is
	-- the seconds of sidestep still owed once the window has answered yes.
	self._wedgeFrom = flat(start)
	self._wedgeTime = 0
	self._wedgeFor = 0
	self._wedgeTurn = 0
	self._wedgeCount = 0

	-- WHICH WAY THIS ANIMAL GOES ROUND A TRUNK when both sides are equally clear (task 123 round 3).
	-- Drawn ONCE, from the shared Random, and kept: a sign drawn per frame is a nose that hunts left
	-- and right in front of the same tree, which is the "mouse turning" this round is about.
	self._whiskerSide = if rng:NextNumber() < 0.5 then -1 else 1
	-- ...and which side THIS obstacle is being passed on, held for `MOVE.WHISKER_HOLD_SECONDS` so a
	-- flickering cast cannot swap it every frame (task 126).
	self._whiskerPick = self._whiskerSide
	self._whiskerFor = 0
	-- HOW LONG THE DRIVE HAS ASKED THIS ANIMAL TO GET A MOVE ON (task 123 round 4): seconds, counted
	-- down with dt like every other timer here. Karen: *"they can trot when crossing"*.
	self._urgeFor = 0
	-- The smoothed steering TARGET. nil until the first step, so the first frame is not smoothed
	-- toward a direction the animal never had.
	self._wanted = nil :: Vector3?

	-- THE COLUMN LATCH (the sounder). `blockedAhead` is momentary -- a probe that clears on the next
	-- frame would flip the formation back and forth between a wedge and a file -- so the column is
	-- held for COLUMN_LATCH_SECONDS after the probe last fired.
	self._columnFor = 0

	-- THE AWARENESS TIMERS (task 118): how much of the head-up hold is left, how long until the
	-- animal may go head-up again, and how much of the turn-away is left. All counted with dt and
	-- never from a clock, so a spec is deterministic -- the same rule `_boltFor` follows.
	self._alertFor = 0
	self._refractoryFor = 0
	self._avoidFor = 0
	-- Which way an AVOID swings, drawn ONCE on entering it, and the single steering target that goes
	-- with it. Redrawing either per tick is an animal mirroring its heading instead of committing.
	self._avoidTurn = 1
	self._avoidPoint = nil :: Vector3?
	-- What an ALERT boar is looking at. Remembered rather than re-read, so the head does not swing
	-- back and forth when the cause steps out of the notice band mid-hold.
	self._alertPoint = nil :: Vector3?
	-- The last perception (task 118, design section 4.2), kept so `Runtime:perceptionOf` can show a
	-- spec WHY the animal did something instead of inferring it from a velocity. Nothing in the game
	-- reads it, and there is no setter.
	self._perception = nil :: any

	-- TASK 127: the order the drive is giving this animal right now -- a point, a speed and a
	-- dead-man's timer. nil/0 means "nobody is driving me", which is every world but the Forest
	-- Test's line mode and every animal in it that is not in a line.
	self._orderPoint = nil :: Vector3?
	self._orderSpeed = 0
	self._orderFor = 0

	-- Which way a crippled boar circles, chosen once when its back end goes (task 116).
	self._crippleTurn = nil :: number?

	-- TASK 126. Five values, and each of them is one of Karen's sentences.
	--
	-- THE FLIGHT LATCH -- *"run straigh"*. The heading taken at the moment of the spook, the seconds
	-- of flight left on the ceiling, and how far the animal has run on it so far. `_flightHeading`
	-- nil means "not in a flight", which is the one test every reader uses.
	self._flightHeading = nil :: Vector3?
	self._flightFor = 0
	self._flightRun = 0
	self._flightFrom = flat(start)
	-- THE EDGE CHECK -- *"they can stop before entering the road"*. Seconds of standing-and-looking
	-- left, and whether this animal has already had its check (one per crossing, not one per frame
	-- the world asks).
	self._checkFor = 0
	self._checked = false
	-- WHERE A STRAYED BOAR IS WALKING BACK TO. One drawn point, replacing the per-tick pull toward
	-- home that was one of the two orbit generators.
	self._homePoint = nil :: Vector3?

	self._despawned = false
	return self
end

function Brain:state(): string
	return self._state
end

-- How many waypoints of the current route the boar has already passed. The Runtime compares a
-- Path.Blocked index against this, so a blockage behind the boar does not force a pointless repath
-- (the one idea taken from SimplePath; design section 6).
function Brain:consumed(): number
	return self._consumed
end

function Brain:debug()
	return {
		home = self._home,
		heading = self._heading,
		target = self._target,
		sinceThreat = self._sinceCalm,
		-- TASK 118's timers, for the same reason the four above are here: a spec can see that the
		-- refractory is what kept a boar grazing rather than guess it from two states that match.
		alertFor = self._alertFor,
		refractoryFor = self._refractoryFor,
		avoidFor = self._avoidFor,
		avoidPoint = self._avoidPoint,
	}
end

-- A COPY of the last perception, or nil before the first step. No setter, and nothing in the game
-- reads it: `Runtime:perceptionOf` hands it to a live spec so that "why" is observable (section 7.2).
function Brain:perception()
	if self._perception == nil then
		return nil
	end
	return table.clone(self._perception)
end

-- The ROUTE rule (design section 5): flee TOWARD the exit line, pushed sideways away from the
-- threat, and twice as far sideways when the threat stands between the boar and the exit. The
-- boar never routes through the driver.
function Brain:_routeTarget(position: Vector3, centroid: Vector3): Vector3
	local config, field = self._config, self._field

	local lateral = if position.X >= centroid.X then 1 else -1

	-- CORRECTION to docs/design/boar-ai.md section 5, which writes this as
	--   onExitSide = (c.Z - field.exitZ) * sign(field.exitZ - position.Z) > 0
	-- That is false exactly when the threat IS in the way. Boar at z = 0, exit at z = -190, threat
	-- at z = -60: (-60 + 190) * sign(-190) = 130 * -1 = -130, which is not > 0, so the design's
	-- formula would use the single bias in the one case the doubled bias exists for. The threat is
	-- between the boar and the exit when it lies on the exit side of the boar, which is this:
	local onExitSide = (centroid.Z - position.Z) * (field.exitZ - position.Z) > 0
	local bias = config.ROUTE_SIDE_BIAS * (if onExitSide then 2 else 1)

	local targetX = math.clamp(
		position.X + lateral * bias,
		field.bounds.minX + config.EDGE_MARGIN,
		field.bounds.maxX - config.EDGE_MARGIN
	)
	return Vector3.new(targetX, field.groundY, field.exitZ)
end

function Brain:_outcome(position: Vector3): string?
	local field, config = self._field, self._config
	local bounds = field.bounds
	local slack = config.BOUNDS_SLACK

	-- "escaped" is a FLEE outcome. An idle boar that wanders over the line has not escaped anything,
	-- and deleting it would lose the only boar in the grey box with no driver anywhere near
	-- (review round 2, finding 6). Leaving the arena outright is still outOfBounds in any state.
	-- WOUNDED escapes exactly as FLEE does: a boar that gets over the line while dying is the
	-- brief's "an escaped wounded boar is also an event", and 1.7 -- not this system -- decides
	-- whether that is a penalty, a partial score or nothing.
	-- A CRIPPLED BOAR IS NOT ESCAPING, so it is not in this test: it circles where it was hit, and
	-- the only ways out are the wound finishing it or another shot.
	-- AVOID COUNTS AS ESCAPING TOO (task 118, design section 3.4). The line is the line: how the
	-- animal got over it does not change that it is over it, and the drive scores on `Despawned`'s
	-- reason. With `SENSE.ENABLED` off the state is unreachable, so this adds nothing to today.
	-- ...AND AN ORDERED ANIMAL ESCAPES TOO (task 127). Karen: *"once they in another side of road they
	-- run away"* -- a line walks its route to the exit in no particular mood, so without this it
	-- would reach the line and stand there. The line is the line: how the animal got over it does not
	-- change that it is over it.
	if
		(self._state == "FLEE" or self._state == "WOUNDED" or self._state == "AVOID" or self:ordered())
		and position.Z <= field.exitZ
	then
		return "escaped"
	end
	if
		position.X < bounds.minX - slack
		or position.X > bounds.maxX + slack
		or position.Z < bounds.minZ - slack
		or position.Z > bounds.maxZ + slack
		or position.Y < field.groundY - config.FALL_LIMIT
	then
		return "outOfBounds"
	end
	return nil
end

-- IDLE: Reynolds wander. Keep a heading, jitter it a little each sense tick, pull back toward home
-- past HOME_RADIUS, turn aside when the probe says something solid is ahead, and graze sometimes.
function Brain:_senseIdle(position: Vector3, obs)
	local config, rng = self._config, self._rng

	self._heading =
		unit(rotateY(self._heading, rng:NextNumber(-config.WANDER_JITTER, config.WANDER_JITTER)), self._heading)

	-- HOME AS A DESTINATION RATHER THAN A PULL WAS BUILT HERE AND TAKEN OUT AGAIN (task 126).
	--
	-- The reasoning was sound and the measurement refused it. Rotating the heading toward home every
	-- sense tick IS an orbit generator in principle -- a boar that strays, is turned back, crosses
	-- home and strays the other way is turned back again -- so it was replaced by one drawn point,
	-- walked to, redrawn only on arrival. Measured against the baseline it did not help: the
	-- ten-second windows over 300 degrees did not fall, and with the other changes of this round they
	-- rose. Since it is not WHY the animals circle, it is reverted rather than kept on a hunch, and
	-- this comment is here so the next reader does not re-derive it. `MOVE.HOME_ARRIVE_STUDS` and
	-- `HOME_SCATTER_STUDS` stay in the config with the same note.
	local fromHome = flat(position) - self._home
	if fromHome.Magnitude > config.HOME_RADIUS then
		-- CORRECTION to docs/design/boar-ai.md section 5, which writes this as
		--   heading = unit(heading + toHome * HOME_PULL)
		-- A weighted sum cannot turn a heading that points exactly away from home: with
		-- HOME_PULL = 0.6, (-toHome) + 0.6 * toHome = -0.4 * toHome, whose unit vector is the
		-- original heading. The boar would keep walking away and only the wander jitter could
		-- rescue it, which the design's own assertion 8 (wander never leaves HOME_RADIUS + 20)
		-- does not tolerate. Rotating toward home by a bounded angle always converges, so
		-- HOME_PULL is radians per sense tick here, not a blend weight.
		local toHome = unit(-fromHome, self._heading)
		self._heading = slew(self._heading, toHome, config.HOME_PULL)
	end

	if obs.blockedAhead then
		local sign = if rng:NextNumber() < 0.5 then -1 else 1
		local turn = config.PROBE_TURN + rng:NextNumber(0, config.WANDER_JITTER)
		self._heading = unit(rotateY(self._heading, sign * turn), self._heading)
	end

	-- THE OLD GRAZE PAUSE, AND ONLY WHEN THE REPERTOIRE IS OFF. With `CALM.ENABLED` on, `_stepCalm`
	-- never decrements `_grazeFor`, so arming it here latched it above zero for the boar's life and
	-- made `GRAZE_CHANCE`, `GRAZE_MIN` and `GRAZE_MAX` dead dials (review round 2, note).
	local calm = config.CALM
	if not (calm and calm.ENABLED) then
		if self._grazeFor <= 0 and rng:NextNumber() < config.GRAZE_CHANCE then
			self._grazeFor = rng:NextNumber(config.GRAZE_MIN, config.GRAZE_MAX)
		end
	end
end

-- ONE STEP OF THE CALM REPERTOIRE, and the only thing it decides is a SPEED (task 117). It runs the
-- current activity down, draws the next one when it expires, and leaves `self._calm` where `step`
-- can publish it. With `CALM.ENABLED` off it answers exactly what the old boolean answered: stand
-- still while grazing, otherwise wander.
function Brain:_stepCalm(dt: number): number
	local config = self._config
	local calm = config.CALM
	if not (calm and calm.ENABLED) then
		if self._grazeFor > 0 then
			self._grazeFor -= dt
			return 0
		end
		return config.WANDER_SPEED
	end

	self._calmFor -= dt
	if self._calm == nil or self._calmFor <= 0 then
		-- NEVER THE SAME ACTIVITY TWICE RUNNING (review round 3, note). `Body` draws a clip when the
		-- activity changes, so a row drawn twice in a row is an activity whose clip is never
		-- re-played: `smell` is a one-shot with no enter or exit, so the boar stood frozen on
		-- `Idle_5`'s last pose for a second 4.167 s -- no lift, no breathing. Redrawing is cheaper
		-- than a restart signal and it is what a real animal does anyway. Bounded: after four tries
		-- it takes what it is given, and `activityDraw` below restarts the clip even then.
		local previous = self._calm and self._calm.name
		for _ = 1, 4 do
			self._calm = Brain.calmActivity(self._rng:NextNumber(), calm)
			if self._calm.name ~= previous then
				break
			end
		end
		self._calmDraws += 1
		self._calmFor = self._rng:NextNumber(self._calm.minSeconds, self._calm.maxSeconds)
		if not self._calmPhased then
			self._calmPhased = true
			self._calmFor = Brain.firstPhase(self._calmFor, self._rng:NextNumber(), self._calm, calm)
		end
	end
	return self._calm.speed
end

-- FLEE: follow the route if we have one, else fall back to Reynolds flee blended with the direction
-- to the exit target, so a failed path never freezes the boar.
function Brain:_fleeDirection(position: Vector3): Vector3
	local flatPos = flat(position)

	local waypoints = self._waypoints
	if waypoints then
		while waypoints[1] and flatDistance(position, waypoints[1]) < self._config.WAYPOINT_RADIUS do
			table.remove(waypoints, 1)
			self._consumed += 1
		end
		local ahead = waypoints[1]
		if ahead then
			return unit(flat(ahead) - flatPos, self._heading)
		end
		self._consumed = math.huge -- the route is finished; any blocked index is behind us
		self._waypoints = nil
	end

	local target = self._target
	local away = if self._threatPoint then unit(flatPos - self._threatPoint, self._heading) else self._heading
	local toTarget = if target then unit(flat(target) - flatPos, away) else away
	return unit(away + toTarget, away)
end

-- ---------------------------------------------------------------- the sounder
--
-- A FOLLOWER's steering, and nothing here runs for a lone boar or for a leader: `obs.sounder` is
-- nil for the first and `isLeader` for the second, so the leader is today's code, unchanged, which
-- is what makes the flag-OFF world provably today's world.
--
-- Pattern: Reynolds leader following (the target is "a point offset slightly behind the leader")
-- plus the boids terms, combined as a weighted sum -- "compute each of the component steering
-- behaviors and sum them together, possibly with a weighting factor for each".
--   https://www.red3d.com/cwr/steer/gdc99/  ·  https://www.red3d.com/cwr/boids/
-- Design: docs/design/drive.md ("the sounder's behaviour, and who writes it")
-- Note:   docs/research/2026-09-25-drive.md (Addendum 2)

-- The point this follower is steering AT, in the leader's frame: +X is the leader's right and +Z is
-- BEHIND it. A latched column turns the wedge into single file at COLUMN_SPACING_STUDS.
function Brain:_slotPoint(sounder): Vector3
	local settings = self._config.SOUNDER
	local leader = sounder.leader
	local forward = unit(flat(leader.facing or leader.velocity or Vector3.zero), Vector3.new(0, 0, 1))
	-- The sign here only mirrors the wedge left-to-right; the formation is symmetric, so which
	-- member stands on which side is not a decision this has to get "right".
	local right = Vector3.new(forward.Z, 0, -forward.X)
	local slot = math.max(sounder.slot or 2, 2)
	local column = Vector3.new(0, 0, (slot - 1) * settings.COLUMN_SPACING_STUDS)
	-- A COLUMN WHEN THE SOUNDER IS A COLUMN, or when the probe latch says so (task 118, design
	-- section 5.1). One expression and no new function: `formation` is nil for every sounder built
	-- before this task and for every one built with the flag off, and then this is exactly the
	-- latch it was.
	local inFile = self._columnFor > 0 or (sounder.formation == "column")
	local offset = if inFile then column else (settings.FORMATION[slot] or column)
	return flat(leader.position) - forward * offset.Z + right * offset.X
end

-- THE FILE (task 126). Karen: *"it could be lines of boars like in real life"*.
--
-- ONE LINK OF A CHAIN, AND THAT IS THE WHOLE IDEA. `_slotPoint` above aims every follower at a point
-- behind THE LEADER, so nine animals converge on nine points on one line through one moving animal
-- and every one of them cuts the corners the leader turns -- measured before this task as a 35.2-stud
-- median gap and a 17.6-stud median offset from the leader's own line, which is a field of animals
-- and not a line of them. This aims each follower at a point `FILE_PITCH_STUDS` behind THE ONE
-- AHEAD OF IT, which is Reynolds' `leader following` applied per link rather than per group.
--   https://www.red3d.com/cwr/steer/gdc99/
--
-- Returns nil when there is no file to be in -- no animal ahead, or it is barely moving -- and then
-- the caller does exactly what it did before this task.
function Brain:_filePoint(sounder): Vector3?
	local move = self._config.MOVE
	if move == nil or move.ENABLED ~= true or move.FILE ~= true then
		return nil
	end
	local ahead = sounder.ahead
	if ahead == nil then
		return nil
	end
	-- BEHIND THE ONE AHEAD, along ITS OWN facing: "a point offset slightly behind the leader" in
	-- Reynolds' words, where the leader of this link is the animal in front.
	local forward = flat(ahead.facing or ahead.velocity or Vector3.zero)
	if forward.Magnitude < 1e-6 then
		forward = self._heading
	end
	return flat(ahead.position) - unit(forward, self._heading) * move.FILE_PITCH_STUDS
end

-- The four terms of the blend. Separation is the boids 1/r repulsion with a floor at zero, so a
-- neighbour past SEPARATION_STUDS contributes nothing at all, and it is weighted to dominate --
-- five CanCollide bodies at MAX_FORCE = 6000 pushing through each other is a physics fight.
function Brain:_sounderDirection(position: Vector3, obs): Vector3
	local settings = self._config.SOUNDER
	local sounder = obs.sounder
	local flatPos = flat(position)
	local fleeDirection = self:_fleeDirection(position)

	local separation = Vector3.zero
	for _, neighbour in ipairs(sounder.neighbours or {}) do
		local away = flatPos - flat(neighbour.position)
		local distance = away.Magnitude
		if distance > 1e-6 then
			local push = (settings.SEPARATION_STUDS / math.max(distance, 1)) - 1
			if push > 0 then
				separation += unit(away, self._heading) * push
			end
		end
	end
	local separationWeight = settings.SEPARATION * (if sounder.scattering then settings.SCATTER_SEPARATION else 1)

	-- IN A FILE, THE ANIMAL AHEAD IS THE ONLY THING THAT DECIDES WHERE THIS ONE GOES (task 126).
	--
	-- MEASURED, AND IT IS WHY THE FIRST VERSION OF THIS TASK CHANGED NOTHING. Adding the file's
	-- target to the blend left the gap between consecutive members at a 34.4-stud median against the
	-- 35.2 it started at -- no file at all. The reason is in the two weights: every member of a
	-- fleeing sounder carries its own `FLEE_WEIGHT` 0.8 pull toward `field.exitZ`, and nine animals
	-- each pulling toward the same line 300 studs south travel as a BROAD FRONT, whatever the
	-- cohesion term asks for. A queue cannot form while every link also knows where it is going.
	--
	-- So a follower with somebody ahead of it does not flee: it FOLLOWS, and the leader is the only
	-- animal in the sounder that reads the route. That is Reynolds' `leader following` as written --
	-- "stay behind the leader" is the whole behaviour, not a term in a sum.
	--   https://www.red3d.com/cwr/steer/gdc99/
	local filePoint = if not sounder.scattering then self:_filePoint(sounder) else nil
	if filePoint ~= nil then
		local toFile = flat(filePoint) - flatPos
		local lead = if toFile.Magnitude > self._config.MOVE.FILE_TOLERANCE_STUDS
			then unit(toFile, self._heading)
			-- ARRIVED: hold the line the one ahead is on, or the follower oscillates on the spot.
			else unit(flat(sounder.ahead.facing or sounder.ahead.velocity or Vector3.zero), self._heading)
		-- SEPARATION STAYS, and it is the one term that must: a file at `FILE_PITCH_STUDS` is inside
		-- nothing, but a follower that catches up, or two files that merge, still needs the boids
		-- repulsion or five CanCollide bodies fight the solver.
		return unit(lead * settings.COHESION + separation * separationWeight, self._heading)
	end

	local blended = separation * separationWeight + fleeDirection * settings.FLEE_WEIGHT

	-- WHILE SCATTERING THERE IS NOTHING TO COHERE TO: the member runs its own flee direction with
	-- separation tripled, which is the sounder breaking up at the shot.
	if not sounder.scattering and sounder.leader then
		local toSlot = flat(self:_slotPoint(sounder)) - flatPos
		-- ARRIVAL: zero inside the tolerance, or the follower oscillates on the spot.
		if toSlot.Magnitude > settings.SLOT_TOLERANCE_STUDS then
			blended += unit(toSlot, self._heading) * settings.COHESION
		end
		local alignTo = flat(sounder.leader.velocity or Vector3.zero)
		if alignTo.Magnitude < 1e-6 then
			alignTo = flat(sounder.leader.facing or Vector3.zero)
		end
		if alignTo.Magnitude > 1e-6 then
			blended += unit(alignTo, fleeDirection) * settings.ALIGNMENT
		end
	end

	return unit(blended, fleeDirection)
end

-- A grazing sounder stays a loose group rather than marching in a wedge: past IDLE_SPREAD_STUDS a
-- member leans back toward the centroid, and it always pushes off a neighbour that is too close.
function Brain:_idleSounderDirection(position: Vector3, obs): Vector3
	local settings = self._config.SOUNDER
	local sounder = obs.sounder
	local flatPos = flat(position)
	local blended = self._heading

	local separation = Vector3.zero
	for _, neighbour in ipairs(sounder.neighbours or {}) do
		local away = flatPos - flat(neighbour.position)
		local distance = away.Magnitude
		if distance > 1e-6 then
			local push = (settings.SEPARATION_STUDS / math.max(distance, 1)) - 1
			if push > 0 then
				separation += unit(away, self._heading) * push
			end
		end
	end
	blended += separation * settings.SEPARATION

	if not sounder.scattering then
		-- THE SOUNDER'S CENTROID IS A POINT ITS MEMBERS STEER AT, which is the shape of an orbit --
		-- and task 126 replaced it with a leash at twice the spread, measured, and put it back. It is
		-- not what makes the animals circle: with it gone the ten-second windows over 300 degrees did
		-- not fall. A grazing sounder closing up past `IDLE_SPREAD_STUDS` is Karen's own accepted
		-- behaviour from task 61 ("seems together, sometimes alone"), so it stands.
		local toCentroid = flat(sounder.centroid or flatPos) - flatPos
		if toCentroid.Magnitude > settings.IDLE_SPREAD_STUDS then
			blended += unit(toCentroid, self._heading) * settings.IDLE_COHESION
		end
	end
	return unit(blended, self._heading)
end

-- The leader's speed, so the sounder does not concertina, with a catch-up while out of position.
--
-- THE DESIGN'S FLOOR OF TROT_SPEED/2 IS NOT IMPLEMENTED, and this is the one deliberate deviation
-- in this task: it cannot coexist with the design's own test "never exceeds leader.speed x CATCHUP"
-- when the leader is standing still, and whenever the leader is moving faster than the floor the
-- floor can never bind anyway. A follower matching a stopped leader is the herd behaviour.
function Brain:_followerSpeed(position: Vector3, obs): number
	local config = self._config
	local settings = config.SOUNDER
	local leader = obs.sounder.leader
	-- AGAINST THE FILE'S OWN TARGET WHERE THERE IS ONE (task 126): a follower 25 studs behind the
	-- animal ahead of it has to be allowed to close, and measuring that gap against the WEDGE slot it
	-- is no longer standing in is how a file stays strung out. Measured: a 25.6-stud median gap after
	-- the file went in, against a `FILE_PITCH_STUDS` of 7.5.
	local filePoint = self:_filePoint(obs.sounder)
	local target = filePoint or flat(self:_slotPoint(obs.sounder))
	local tolerance = if filePoint ~= nil then config.MOVE.FILE_TOLERANCE_STUDS else settings.SLOT_TOLERANCE_STUDS
	local toSlot = flat(target) - flat(position)
	local catchup = if toSlot.Magnitude > tolerance then settings.CATCHUP else 1
	return math.min((leader.speed or 0) * catchup, config.SPRINT_SPEED)
end

-- PINNED AGAINST SOMETHING, ANSWERED INSIDE A SECOND (task 150). Karen: *"still can see sometimes
-- boar hit tree and wal in place so not avoiding tree"*.
--
-- TOLD TO MOVE AND NOT MOVING, which is the whole definition and is why both halves are needed: an
-- animal standing still on purpose (ALERT, grazing, arrived at its ordered point) has a setpoint of
-- zero and must not be sidestepped, and an animal crossing open ground has a setpoint AND ground
-- under it. Only a boar being driven forward into something solid has one without the other.
--
-- IT ANSWERS TRUE ON EXACTLY ONE TICK -- the one the window closes on -- and that is the whole
-- difference between a sidestep and a spin. The turn it asks for is 90 degrees applied to `_desired`
-- AFTER the slew; applied again on the next frame, and the one after, it would be a rotation
-- generator, which is the failure task 126's turn budget was abandoned for (the measurement is in
-- `step`'s comment). So the firing tick turns, and `_wedgeFor` seconds of HOLD keep that line.
--
-- THE SIDE IS THE ANIMAL'S OWN `_whiskerSide`, drawn once when it was born, so two animals wedged on
-- the same trunk do not cross in front of each other -- and the NEXT window flips it: a sidestep
-- that did not work is worth trying the other way round rather than three more times the same way.
function Brain:_updateWedge(dt: number, position: Vector3): boolean
	local move = self._config.MOVE
	if move == nil or move.ENABLED ~= true or move.WEDGE_SECONDS == nil then
		return false
	end
	if self._wedgeFor > 0 then
		-- ALREADY STEPPING ROUND ONE. No second turn, and no re-arming either: the window stays shut
		-- until the hold ends, so the 0.6 s is spent going somewhere rather than turning again.
		return false
	end
	if self._speed < (move.WEDGE_ORDERED_SPEED or 2) then
		self._wedgeFrom = flat(position)
		self._wedgeTime = 0
		return false
	end
	self._wedgeTime += dt
	if self._wedgeTime < move.WEDGE_SECONDS then
		return false
	end
	local covered = flatDistance(position, self._wedgeFrom) / self._wedgeTime
	self._wedgeFrom = flat(position)
	self._wedgeTime = 0
	if covered >= (move.WEDGE_SPEED or 0.5) then
		self._wedgeCount = 0
		return false
	end
	self._wedgeCount += 1
	self._wedgeFor = move.WEDGE_HOLD_SECONDS or 0.6
	-- the animal's own side first, then the other one, then back again
	local side = if self._whiskerSide < 0 then -1 else 1
	if self._wedgeCount % 2 == 0 then
		side = -side
	end
	self._wedgeTurn = side * math.pi / 2
	self._waypoints = nil -- whatever the route said, it leads into this
	self._target = nil
	return true
end

function Brain:_updateStuck(dt: number, position: Vector3): boolean
	if self._speed <= 0 then
		self._stuckFrom = flat(position)
		self._stuckTime = 0
		return false
	end
	self._stuckTime += dt
	if self._stuckTime < self._config.STUCK_TIME then
		return false
	end
	local moved = flatDistance(position, self._stuckFrom)
	self._stuckFrom = flat(position)
	self._stuckTime = 0
	if moved >= self._config.STUCK_DIST then
		self._stuckCount = 0
		return false
	end
	self._stuckCount += 1
	return true
end

-- The reaction to one hit. Called from the top of step(), before the sense gate.
function Brain:_reactToHit(event)
	if self._state == "GONE" or self._state == "DOWN" then
		return -- a hit on a carcass changes nothing and never re-animates it
	end
	local config = self._config
	local wound = config.WOUND

	if event.from then
		self._lastShotPoint = flat(event.from)
	end

	if event.severity == "lethal" then
		self:_collapse()
		return
	end

	-- WHERE IT WAS HIT DECIDES WHAT IT DOES (task 116). The class comes from `Wound.hitClass`, which
	-- is a lookup in `WOUND.CLASS`, so this knows nothing about which zones exist.
	--
	-- CRIPPLING WINS OVER EVERYTHING SHORT OF DEATH, and it is never left: the back end does not come
	-- back. A later hit can still kill it (`severity == "lethal"` returns above).
	--
	-- A GRAZE TO THE RUMP IS A GRAZE, NOT A CRIPPLED ANIMAL, and that is not a nicety -- it is what
	-- stops a boar circling in the arena for ever. A crippled boar is taken out of the escape test
	-- below (it is not going anywhere), so the only two ways it can leave are another shot and
	-- `Wound.advance` finishing it -- and `advance` never collapses a GRAZED animal. Requiring the
	-- wound to be at least mortal makes "it dies or is shot again" true by construction, and it is
	-- also the right answer physically: one pellet in the ham does not take the back legs off.
	if event.class == "crippling" and event.severity ~= "grazed" then
		self._state = "CRIPPLED"
		self._crippleTurn = if self._rng:NextNumber() < 0.5 then -1 else 1
	elseif self._state ~= "CRIPPLED" then
		if event.severity == "mortal" then
			self._state = "WOUNDED"
		elseif self._state == "IDLE" then
			self._state = "FLEE"
		end
	end

	self._grazeFor = 0
	self._sinceCalm = 0
	self._sinceRepath = math.huge -- path immediately, as the IDLE->FLEE transition already does

	-- A CRIPPLED BOAR DOES NOT BOLT. The bolt and its kick are for an animal that can run; giving
	-- them to one whose back legs have gone would have it sprint away from the thing that just took
	-- them off. It keeps the shot point -- it still turns away from the gun -- and nothing else.
	if self._state == "CRIPPLED" then
		self._boltFor = 0
		self._speed = math.min(self._speed, wound.CRIPPLE_SPEED)
		return
	end

	-- BOLT. The one documented bypass of the ACCEL ramp in the whole system: a shot animal does not
	-- accelerate over 0.63 s. It is an assignment, once per hit, not a new rule.
	self._boltFor = wound.BOLT_SECONDS
	self._speed = math.max(self._speed, self:_runSpeed() * wound.BOLT_KICK)
end

-- It has run out of blood or out of time. Entered from any live state, once.
function Brain:_collapse()
	if self._state == "GONE" or self._state == "DOWN" then
		return
	end
	self._state = "DOWN"
	self._speed = 0
	self._waypoints = nil
	self._target = nil
	self._carcassFor = self._config.WOUND.CARCASS_SECONDS
end

-- ---------------------------------------------------------------- awareness (task 118)
--
-- Four transitions, each in one place, so "what state is this animal in and why" has one answer.
-- Design: docs/design/boar-behaviour.md sections 3.2, 3.3, 3.4.

-- HEAD DOWN AGAIN. Both ALERT and AVOID end on their own timer, and both end the same way: calm,
-- home reset to where the animal now stands, nothing routed. Leaving ALERT also arms the refractory,
-- which is what stops a 2.5 s IDLE<->ALERT flip-flop in front of a motionless hunter.
-- Calming down ends the flight and re-arms the edge check: an animal that has crossed, settled and
-- meets another ride may stop and look at that one too.
function Brain:_settle(position: Vector3)
	-- AN ANIMAL THAT HEARD A SHOT NEVER CALMS DOWN AGAIN (task 150). This is the one function in the
	-- file that turns a frightened animal back into a grazing one -- ALERT and AVOID time out
	-- through it, and so does FLEE's calm counter -- so it is the one place the latch has to hold.
	if self._heardShot then
		return
	end
	if self._state == "ALERT" then
		self._refractoryFor = self._config.SENSE.ALERT_REFRACTORY_SECONDS
	end
	self._state = "IDLE"
	self._home = flat(position)
	self._waypoints = nil
	self._target = nil
	self._sinceCalm = 0
	self._alertFor = 0
	self._avoidFor = 0
	self._avoidPoint = nil
	self._alertPoint = nil
	-- TASK 126: settling ends the flight and RE-ARMS the edge check. An animal that has crossed one
	-- ride and calmed down may stand and look at the next one; one that is still running may not.
	self._flightHeading = nil
	self._flightFor = 0
	self._checked = false
	self._checkFor = 0
	self._homePoint = nil
end

-- IT RUNS. This is today's IDLE->FLEE transition, lifted into a function so that precedence rules 7
-- (something inside a flush radius) and 8 (the sounder's alarm) cannot drift apart from it.
function Brain:_flush()
	if self._state == "FLEE" then
		self._sinceCalm = 0
		return
	end
	self._state = "FLEE"
	self._sinceCalm = 0
	self._sinceRepath = math.huge -- path immediately, exactly as the old IDLE->FLEE branch did
	self._grazeFor = 0
	self._alertFor = 0
	self._avoidFor = 0
	self._avoidPoint = nil
end

-- HEAD UP, STOPPED, TURNED TO THE CAUSE. The hold is `ALERT_SECONDS` from the moment it began and is
-- never refreshed by a later tick: a hunter who stands still gets one head-up, then the animal
-- settles and will not look again for `ALERT_REFRACTORY_SECONDS`.
function Brain:_enterAlert(cause)
	self._state = "ALERT"
	self._alertFor = self._config.SENSE.ALERT_SECONDS
	self._alertPoint = flat(cause.position)
	self._waypoints = nil -- ALERT does not route (section 3.1: no paths)
	self._target = nil
	self._sinceCalm = 0
	self._avoidFor = 0
	self._avoidPoint = nil
end

-- TURNED AWAY AND TROTTING OFF, on ONE steering target drawn on entry (section 4.4). No path
-- request is ever made from here: AVOID lasts `AVOID_SECONDS`, it is local, and `ComputeAsync` is
-- the system's one expensive call -- the path budget must not change in a behaviour task.
function Brain:_enterAvoid(position: Vector3, cause)
	local config = self._config
	self._avoidTurn = if self._rng:NextNumber() < 0.5 then -1 else 1
	self._state = "AVOID"
	self._waypoints = nil
	self._target = nil
	self._sinceCalm = 0
	self._alertFor = 0
	self._alertPoint = nil
	self._avoidFor = config.SENSE.AVOID_SECONDS
	self._avoidPoint = Brain.avoidTarget(position, cause.position, self._avoidTurn, config, self._field)
end

-- A SHOT IS A SOUND, NOT A HIT (section 4.5). It arrives through the same door a hit does, and it
-- reuses the EXISTING bolt: `_boltFor` is already "run whatever the threats say" and
-- `_lastShotPoint` is already "while bolting, the shot point IS the threat". There is no second
-- sprint rule, only a second way to start the one that exists.
-- SOMETHING FRIGHTENED THIS ANIMAL, and it is the one bolt this file has (task 123 round 3). It
-- is what `_hearSound` does once it has decided the bang was audible, lifted out so the Runtime can
-- hand the same fact to an animal that was not alive when the gun went off -- Karen: *"next flot
-- comes without spook if there wasant driver or shoot withing 5s otherwise running"*.
--
-- NO SECOND SPRINT RULE: `_boltFor` is already "run whatever the threats say" and `_lastShotPoint`
-- is already "while bolting, this IS the threat".
-- HOW FAST THIS ANIMAL RUNS WHEN IT IS FRIGHTENED (task 123 round 4). `SPRINT_SPEED` is a real
-- boar's 40 km/h and Karen asked for slower: *"when they fleet make speed slover it's to fast"*. One
-- function, so the bolt, the hit and the pace clamp cannot disagree about what "running" is.
function Brain:_runSpeed(): number
	local config = self._config
	local pace = config.PACE
	if pace ~= nil and pace.ENABLED == true and pace.RUN_SPEED ~= nil then
		return pace.RUN_SPEED
	end
	return config.SPRINT_SPEED
end

-- THE DRIVE ASKS FOR A TROT (task 123 round 4). Karen: *"they can trot when crossing"*. The drive
-- knows where its road is and this file does not, so "get across" arrives as seconds of urgency and
-- the pace clamp turns it into `PACE.TROT_SPEED`. It never makes an animal RUN -- only a spook does.
function Brain:urge(seconds: number)
	self._urgeFor = math.max(self._urgeFor, seconds)
end

-- `shot` SAYS THE FRIGHT WAS A BANG, and only a bang latches the leave-and-never-stop of task 150.
-- A beater pushing a wave is a fright too, and Karen's sentence is about shooting: *"once they hear
-- shoot they run and don't stop"*. So the drive's own `Runtime:spook` passes nothing and behaves
-- exactly as it did, while `_hearSound` -- and the wave released into a wood that has just been shot
-- in -- passes true.
function Brain:spook(from: Vector3?, seconds: number?, shot: boolean?)
	local config = self._config
	local state = self._state
	if state == "GONE" or state == "DOWN" or state == "CRIPPLED" then
		return false
	end
	if shot == true and config.SENSE ~= nil and config.SENSE.SHOT_FLIGHT_UNTIL_EXIT == true then
		self._heardShot = true
	end
	self._boltFor = math.max(self._boltFor, seconds or config.SENSE.SHOT_SPRINT_SECONDS)
	if from ~= nil then
		self._lastShotPoint = flat(from)
	end
	self._sinceCalm = 0
	if state == "IDLE" or state == "ALERT" or state == "AVOID" then
		self:_flush()
	end
	self._speed = math.max(self._speed, self:_runSpeed() * config.WOUND.BOLT_KICK)
	-- ...AND THE LINE IT RUNS ON, taken here because this is the one door every fright comes
	-- through: a shot heard, a hit taken, a release that remembers a bang, a driver flushing it.
	self:_latchFlight(self._at, from)
	return true
end

-- THE FLIGHT LATCH (task 126). Karen: *"after shoot animals usually run straight when they spook ofc
-- avoiding opsticals"*.
--
-- ONE HEADING, TAKEN ONCE. Before this task a fleeing animal recomputed "away from the threat" from
-- its CURRENT position every frame, so the away-vector swung round as it ran past the shooter, and a
-- pathfinder route curved it further -- measured as a median 84-99 degrees of deviation from the
-- heading it set off on, and a maximum of 180. This takes the direction at the instant of the spook
-- and keeps it; `Brain.steerAroundTrunk` is then the ONLY thing that deflects it, which is her
-- *"ofc avoiding opsticals"* exactly.
--
-- IT DOES NOT RE-LATCH ON EVERY BANG. A second shot inside `FLIGHT_RELATCH_SECONDS` keeps the first
-- one's line, so a volley does not make an animal pirouette between two shooters.
function Brain:_latchFlight(position: Vector3, from: Vector3?)
	local move = self._config.MOVE
	if move == nil or move.ENABLED ~= true or move.FLIGHT ~= true then
		return
	end
	if self._flightHeading ~= nil and self._flightFor > move.FLIGHT_MAX_SECONDS - move.FLIGHT_RELATCH_SECONDS then
		return -- still inside the re-latch window of a flight that just started
	end
	local flatPos = flat(position)
	-- AWAY FROM WHAT FRIGHTENED IT, and when that is unknown (a herd-mate's alarm, a release that
	-- remembers a bang) the animal keeps the heading it already had. Either way it is ONE line.
	local away = if from ~= nil then unit(flatPos - flat(from), self._heading) else self._heading
	-- ...BENT TOWARD THE WAY OUT, once, at the latch. A straight line away from the gun that runs
	-- into the back fence is not an escape; `field.exitZ` is where this world's animals leave, and
	-- the same blend `_fleeDirection` has always used is applied HERE instead of every frame.
	local exit_ = Vector3.new(flatPos.X, 0, self._field.exitZ)
	local toExit = unit(exit_ - flatPos, away)
	-- ...AND THE WAY OUT ALWAYS WINS, EVEN PAST THE GUN (task 139, the Director's decision A).
	-- Karen, 2026-10-09: *"when boars crossing road they can't come back to same view, they just move
	-- on a specially after spook or shoot"*, and in task 126 *"they don't come back from that side"*.
	--
	-- THIS LINE USED TO SAY THE OPPOSITE and it said why: when the shooter stood between the animal
	-- and `exitZ` it took `away` -- straight back the way it came. IN A DRIVE THE SHOOTER IS ALWAYS
	-- IN THAT POSITION: he stands on the road and the way out is past him. MEASURED at `0c7f736`,
	-- nine shots, **five animals ran north afterwards**, back into the view she had just shot into.
	-- The old reasoning -- "an animal in that position runs from the gun and finds its way out later"
	-- -- is the thing a drive exists to stop: driven game breaks PAST the guns.
	--
	-- SO THE EXIT IS THE HEADING AND THE GUN IS A SWERVE. `sideways` is what is left of "away from
	-- the cause" once the part along the exit line is removed, so the animal still breaks left or
	-- right of him; it just never breaks backwards. Frightened by nothing in particular (`from` nil),
	-- it keeps its own heading exactly as before.
	--
	-- ...AND IT ALWAYS PASSES HIM TO ONE SIDE (task 139 round 3, the Reviewer's note, which was
	-- right and said so with the geometry). When the shooter stands DIRECTLY between the animal and
	-- the exit -- which is the case this whole paragraph is about -- `away` is exactly `-toExit`,
	-- `sideways` is ZERO, and the animal ran straight at the gun.
	--
	-- A SIDE IS THEREFORE CHOSEN WHEN THE GEOMETRY DOES NOT CHOOSE ONE, and it is the animal's OWN
	-- side (`_whiskerSide`, drawn once when it was born) rather than a fresh coin: two animals
	-- abreast break the same way every frame of the same flight, and the herd does not split and
	-- re-split. The cross product with Y is the left/right of the exit line, so the fallback is a
	-- UNIT sideways -- a full `FLIGHT_SWERVE` of break, about 45 degrees with the swerve at 1.
	--
	-- EVERY OTHER FLIGHT KEEPS THE GEOMETRY IT HAD (round 3, the Reviewer's note, which was right
	-- again): `sideways` is NOT normalised in the general case, so the break is still
	-- `atan(|away.X|)`-ish -- a flush from nearly due north runs nearly straight down the exit line,
	-- and only a shooter square on the line gets the full 45 degrees.
	local sideways = away - toExit * away:Dot(toExit)
	if sideways.Magnitude < 1e-3 then
		sideways = Vector3.new(0, 1, 0):Cross(toExit) * (if self._whiskerSide < 0 then -1 else 1)
	end
	self._flightHeading = if from == nil then away else unit(toExit + sideways * (move.FLIGHT_SWERVE or 1), toExit)
	self._flightFor = move.FLIGHT_MAX_SECONDS
	self._flightRun = 0
	self._flightFrom = flatPos
	-- A flight is not a route: a curved path is the other half of what bent the line.
	self._waypoints = nil
	self._target = nil
end

-- WHETHER THE ANIMAL IS STILL ON ITS FLIGHT. Karen: *"it runs awai a lot until I can;t see them ...
-- not run a bit and stop"*. It ends on DISTANCE, not on a timer -- `FLIGHT_MIN_STUDS` of ground
-- covered -- with the seconds only as a ceiling so nothing penned in by the bounds runs for ever.
function Brain:_flightActive(): boolean
	local move = self._config.MOVE
	if move == nil or move.ENABLED ~= true or self._flightHeading == nil then
		return false
	end
	-- ...UNLESS IT WAS A SHOT, AND THEN IT DOES NOT END AT ALL (task 150). Karen: *"once they hear
	-- shoot they run and don't stop"*. The distance cap and the seconds ceiling both answer "how
	-- much of a fright is this worth"; a bang is worth all of it, and the animal is off the board
	-- at `field.exitZ` either way. `_heardShot` is only ever set when `SENSE.SHOT_FLIGHT_UNTIL_EXIT`
	-- is on, so with that off this line cannot fire and the cap is the cap.
	if self._heardShot then
		return true
	end
	return self._flightRun < move.FLIGHT_MIN_STUDS and self._flightFor > 0
end

-- THE EDGE CHECK (task 126). Karen: *"they can stop before entering the road"*.
--
-- A REQUEST FROM THE WORLD, exactly like `Brain:urge` and `Brain:spook`: the thing that knows where
-- the road is is the world, and the thing that knows how an animal stands and looks is this. One
-- check per animal per approach -- `_checked` is cleared by `_settle`, so a boar that has crossed and
-- calmed down may check again at the next road -- and never while it is already frightened.
function Brain:check(seconds: number?): boolean
	local move = self._config.MOVE
	if move == nil or move.ENABLED ~= true then
		return false
	end
	if self._checked or self._checkFor > 0 then
		return false
	end
	local state = self._state
	if state == "GONE" or state == "DOWN" or state == "CRIPPLED" or state == "WOUNDED" then
		return false
	end
	-- A FRIGHTENED ANIMAL DOES NOT STOP TO LOOK, and that is the whole order of Karen's sentence:
	-- *"they can stop before entering the road or walk or trot if there are spook or shoot they run"*.
	if self._boltFor > 0 or self:_flightActive() then
		return false
	end
	self._checked = true
	if self._rng:NextNumber() >= move.EDGE_CHANCE then
		return false -- it had its chance and walked straight out, which is the other half of the dial
	end
	self._checkFor = seconds or self._rng:NextNumber(move.EDGE_MIN_SECONDS, move.EDGE_MAX_SECONDS)
	return true
end

-- WALK TO THIS POINT AT THIS SPEED, AND DECIDE NOTHING (task 127). Karen: *"imagine they come from
-- one side in one line and crossing road thats it"*.
--
-- The same shape as `urge`, `spook` and `check`: the drive states a need and the Brain resolves it.
-- It is re-issued every step by the caller and expires by itself (`LINE.ORDER_SECONDS`), so a wave
-- that retires, or an animal that leaves it, becomes an ordinary boar again without anybody having
-- to remember to cancel.
--
-- IT DOES NOT OVERRIDE DYING. A DOWN, GONE or CRIPPLED animal ignores it, because those branches of
-- `step` return before this one is read -- a carcass does not walk to a waypoint.
function Brain:leadTo(point: Vector3, speed: number): boolean
	local line = self._config.LINE
	if line == nil or line.ENABLED ~= true then
		return false
	end
	local state = self._state
	if state == "GONE" or state == "DOWN" or state == "CRIPPLED" then
		return false
	end
	self._orderPoint = flat(point)
	self._orderSpeed = math.max(0, speed)
	self._orderFor = line.ORDER_SECONDS
	return true
end

function Brain:ordered(): boolean
	return self._orderFor > 0 and self._orderPoint ~= nil
end

-- IS IT RUNNING ON A LATCHED LINE? The drive reads this to leave a frightened animal alone (task
-- 126 round 2); `_flightActive` is the same answer `_step` uses, so the two cannot disagree.
function Brain:flying(): boolean
	return self:_flightActive()
end

function Brain:checking(): boolean
	return self._checkFor > 0
end

function Brain:_hearSound(sound, position: Vector3)
	if sound.kind ~= "shot" then
		return
	end
	local config = self._config
	local sense = config.SENSE
	-- WITH THE FLAG OFF A BOAR DOES NOT HEAR AT ALL, and that is not a nicety: before this task
	-- there was no server-side "a shot was fired" fact anywhere, so reacting to one IS a change to
	-- the flag-OFF world. `MatchBoot` wires the event unconditionally (section 8) and the decision
	-- stays here, at the one boundary that reads the flag.
	if not (sense and sense.ENABLED) then
		return
	end
	local state = self._state
	-- A CARCASS, A TERMINAL BOAR AND A CRIPPLED ONE DO NOT HEAR: the same guard `_reactToHit` uses,
	-- and precedence rows 2-4 say the same thing. A crippled animal's back end is gone; a bang does
	-- not give it back.
	if state == "GONE" or state == "DOWN" or state == "CRIPPLED" then
		return
	end
	-- TWO CIRCLES, AND THE NEARER POINT IS WHAT IT RUNS FROM (task 149b). A shot is heard from the
	-- shooter AND from where the bullet landed, because the animals are at the far end: with one
	-- circle at the muzzle, the pack Karen fired into was outside the radius whenever she shot
	-- further than 33.6 m, which is most of the time (`SENSE`'s own comment has the arithmetic).
	local fromShooter = flatDistance(position, sound.position)
	local fromImpact = if sound.impact ~= nil then flatDistance(position, sound.impact) else math.huge
	local impactStuds = sense.SHOT_AUDIBLE_FROM_IMPACT_STUDS or 0
	if fromShooter > sense.SHOT_AUDIBLE_STUDS and fromImpact > impactStuds then
		return
	end
	-- EVERY ANIMAL THAT HEARS IT RUNS, not only the one that was hit (Karen, 2026-10-05: *"after
	-- shoot all run away"*). This is reached from `Runtime:hearShot` for every live boar, so the two
	-- radii are the whole of the rule. The bolt, the flush and the ACCEL bypass are all
	-- `Brain:spook`, which a freshly released wave also uses.
	--
	-- IT RUNS FROM THE NEARER BANG. An animal standing beside the one that was hit should break away
	-- from the impact, not from a hunter 200 studs behind it.
	self:spook(if fromImpact < fromShooter then sound.impact else sound.position, nil, true)
end

-- ONE SENSE TICK, with the flag ON: the precedence table of design section 3.2, rows 5 to 11, read
-- top to bottom with the first match winning. Rows 1 to 4 (despawn, carcass, hit, crippled) are
-- above this in `step` and are untouched.
--
-- IT IS A SEPARATE FUNCTION FROM THE OLD BRANCH ON PURPOSE. With `SENSE.ENABLED` off, `step` runs
-- the code it ran before this task, line for line -- which is what makes "every existing spec is
-- testing the same world it tested before" a fact rather than a hope.
function Brain:_senseAware(position: Vector3, obs, perception, follower: boolean)
	local config = self._config
	local sounder = obs.sounder
	local state = self._state

	-- ROW 5 and ROW 6: a wounded animal never returns to a calm state, and while it is bolting the
	-- bolt decides. Both are exactly what the old `elseif` said.
	if state == "WOUNDED" or self._boltFor > 0 then
		self._sinceCalm = 0
		return
	end

	-- ROW 6b: IT HEARD A SHOT, SO IT IS LEAVING AND IT IS NOT COMING BACK (task 150). Karen:
	-- *"after shoot they run then com closer to road and stay ... once they hear shoot they run and
	-- don't stop"*. Above every row that could stop it -- the alert that makes it stand and look,
	-- the avoid that makes it trot off at an angle, the calm counter that makes it graze -- because
	-- each of those is something an animal does once it has decided it is safe, and this one has
	-- not. Below the wound and the bolt, because those are already running it.
	if self._heardShot then
		self:_flush()
		return
	end

	local reaction = perception.reaction

	-- HAS IT CROSSED? A threat on the FAR SIDE from the exit is a threat the animal has gone past,
	-- which is what "the other side of the road" means to an animal that has no idea where the road
	-- is (task 149b). Latched one way: an animal cannot un-cross, so a hunter wandering south later
	-- does not put it back in the drive.
	local pace = config.PACE
	if not self._crossed and pace ~= nil and pace.LEAVE_AFTER_CROSSING == true then
		local toExit = self._field.exitZ - position.Z
		for _, threat in ipairs(obs.threats or {}) do
			if (threat.position.Z - position.Z) * toExit < 0 then
				self._crossed = true
				break
			end
		end
	end

	-- ROW 7: anything inside a flush radius, whatever state the animal was in.
	if reaction == "flee" then
		self:_flush()
		return
	end
	-- ROW 8: panic has reached this member (section 5.2). This REPLACES the leader-only rule rather
	-- than running beside it -- two correct rules disagreeing is this project's named killer.
	--
	-- IT IS NOT GATED ON `follower`, AND THAT IS THE WHOLE POINT OF THE NEW RULE: the old one ran
	-- leader -> followers, so a leader could never be told anything. Panic now travels member to
	-- member from whichever animal panicked first, and that animal is as often the one at the front.
	-- Gating this on `follower` cost the live spec its third member -- the leader stood there while
	-- the other two ran (measured, this task's first gate run).
	if sounder ~= nil and sounder.alarm == true then
		self:_flush()
		return
	end

	if state == "AVOID" then
		-- Section 3.4: the clock is "`AVOID_SECONDS` since the last tick any stimulus was noticed",
		-- so a stimulus still in a notice band HOLDS the animal in AVOID. That is also why row 10
		-- cannot fire from here: section 3.4's table has no AVOID->ALERT, and a boar that has
		-- decided to leave does not stop to look.
		if reaction ~= "none" then
			self._avoidFor = config.SENSE.AVOID_SECONDS
		end
		-- THE EXISTING PROBE TURN, on the sense tick exactly as `_senseIdle` applies it: something
		-- solid ahead swings the one steering target aside instead of letting the animal push into
		-- it. No path request, here or anywhere else in AVOID.
		if obs.blockedAhead and self._avoidPoint then
			local away = unit(flat(self._avoidPoint) - flat(position), self._heading)
			local sign = if self._rng:NextNumber() < 0.5 then -1 else 1
			self._avoidPoint = Brain.insideField(
				flat(position) + rotateY(away, sign * config.PROBE_TURN) * config.SENSE.AVOID_STUDS,
				config,
				self._field
			)
		end
		return
	end

	-- ROW 9: noticed, and moving. "once move it start to run or turn around and go another
	-- direction" -- this is the turning-away half.
	if reaction == "avoid" then
		self:_enterAvoid(position, perception.cause)
		return
	end

	if state == "ALERT" then
		return -- the hold runs on its own timer (section 3.3); nothing a sense tick sees refreshes it
	end

	-- ROW 10: noticed, standing, and the animal is willing to look again.
	if reaction == "alert" and self._refractoryFor <= 0 then
		self:_enterAlert(perception.cause)
		return
	end

	-- ROW 10b: IT IS PAST THE GUNS, SO IT IS LEAVING (task 149b). This sits ABOVE the idle row on
	-- purpose: with nothing to react to, an animal that has crossed used to fall through to
	-- `_senseIdle` and graze where it stood. It keeps its flight instead, and `_outcome` takes it off
	-- the board at `field.exitZ`. The GAIT is still the pace system's -- a walk or a trot with
	-- nothing near, a run if something is -- so this says "keep going", not "sprint for ever".
	if self._crossed and pace ~= nil and pace.LEAVE_AFTER_CROSSING == true then
		self:_flush()
		return
	end

	-- ROW 11: nothing to react to.
	if state == "IDLE" then
		self:_senseIdle(position, obs)
		return
	end

	-- FLEE, with nothing in range: today's calm-down, on the per-stimulus calm test of section 4.3
	-- and the herd rule of section 5.2.
	if perception.calm then
		self._sinceCalm += config.SENSE_INTERVAL
		-- HERD CALM, through the one class table (section 3.1), so a leader that is ALERT no longer
		-- pins the whole group in FLEE for ever. While scattering there is no leader, and then the
		-- timer alone decides, as it does for a lone boar.
		local leaderCalm = (not follower) or sounder.leaderState == nil or Brain.classOf(sounder.leaderState) == "calm"
		if self._sinceCalm >= config.CALM_TIME and leaderCalm then
			self:_settle(position)
		end
	else
		self._sinceCalm = 0
	end
end

function Brain:step(dt: number, obs)
	local config = self._config
	dt = math.clamp(dt, 0, config.DT_CLAMP)

	local intent = {
		state = self._state,
		targetVelocity = Vector3.zero,
		facing = nil :: Vector3?,
		pathRequest = nil :: Vector3?,
		despawn = false,
		reason = nil :: string?,
		downed = false, -- true exactly once, on the tick the boar collapses
		-- WHAT A CALM BOAR IS DOING (task 117), published only while IDLE so every other state draws
		-- exactly what it drew before. `Body` turns it into a clip; nothing else reads it.
		activity = nil :: string?,
		-- ...and WHICH draw it is, so `Body` can tell a new activity from the same one continuing.
		activityDraw = nil :: number?,
	}

	if self._state == "GONE" then
		return intent
	end

	local position = obs.position

	-- Despawn wins over everything else, and is reported exactly once.
	local outcome = self:_outcome(position)
	if outcome then
		self._state = "GONE"
		self._speed = 0
		intent.state = "GONE"
		if not self._despawned then
			self._despawned = true
			intent.despawn = true
			intent.reason = outcome
		end
		return intent
	end

	-- HITS ARE HANDLED HERE, before the sense gate and before everything else but the despawn
	-- check (hit-zones design section 6.2). A reaction that waited for the next sense tick would be
	-- up to SENSE_INTERVAL late, and being late is indistinguishable from nothing having happened.
	if obs.hitEvents then
		for _, event in ipairs(obs.hitEvents) do
			self:_reactToHit(event)
		end
	end
	if obs.wound and obs.wound.collapse then
		self:_collapse()
	end
	-- A SHOT IS HEARD HERE, beside the hits and for the same reason: a reaction that waited for the
	-- next sense tick would be up to SENSE_INTERVAL late (task 118, section 4.5). Every boar is
	-- handed every drained sound; the Brain owns the audible radius, which is why the test is in
	-- `_hearSound` and not in the Runtime's fan-out.
	if obs.sounds then
		for _, sound in ipairs(obs.sounds) do
			self:_hearSound(sound, position)
		end
	end
	self._boltFor = math.max(0, self._boltFor - dt)
	self._urgeFor = math.max(0, self._urgeFor - dt)
	-- TASK 126's three timers, counted with dt beside the others. With `MOVE.ENABLED` off none of
	-- them is ever set, so this is three subtractions and nothing else.
	self._flightFor = math.max(0, self._flightFor - dt)
	self._whiskerFor = math.max(0, self._whiskerFor - dt)
	self._orderFor = math.max(0, self._orderFor - dt)
	self._checkFor = math.max(0, self._checkFor - dt)
	self._wedgeFor = math.max(0, self._wedgeFor - dt)
	-- HOW FAR THE FLIGHT HAS RUN, which is what ends it: distance covered, never a clock.
	if self._flightHeading ~= nil then
		self._flightRun = flatDistance(position, self._flightFrom)
		if not self:_flightActive() then
			self._flightHeading = nil
		end
	end
	-- THE AWARENESS TIMERS (task 118), counted with dt beside the bolt. With the flag off they are
	-- never set, so this is three subtractions and nothing else.
	self._alertFor = math.max(0, self._alertFor - dt)
	self._refractoryFor = math.max(0, self._refractoryFor - dt)
	self._avoidFor = math.max(0, self._avoidFor - dt)
	-- ...AND WHAT RUNNING OUT MEANS (sections 3.3 and 3.4). Both are TIMER transitions and not
	-- sense-tick ones, so `ALERT_SECONDS` is 2.5 s and not 2.5 s rounded up to the next tick.
	if (self._state == "ALERT" and self._alertFor <= 0) or (self._state == "AVOID" and self._avoidFor <= 0) then
		self:_settle(position)
	end
	-- The column latch is ticked for every boar and SET only for a follower, so a lone boar's
	-- timers are untouched by this task.
	self._columnFor = math.max(0, self._columnFor - dt)
	if obs.sounder and not obs.sounder.isLeader and obs.blockedAhead and self._config.SOUNDER then
		self._columnFor = self._config.SOUNDER.COLUMN_LATCH_SECONDS
	end

	if self._state == "DOWN" then
		self._speed = 0
		intent.state = "DOWN"
		intent.targetVelocity = Vector3.zero
		if not self._downedReported then
			self._downedReported = true
			intent.downed = true -- the Runtime collapses the body and publishes the kill
		end
		self._carcassFor -= dt
		if self._carcassFor <= 0 and not self._despawned then
			-- Reuses the despawn path that already exists, Body.destroy and Despawned included.
			self._despawned = true
			self._state = "GONE"
			intent.state = "GONE"
			intent.despawn = true
			intent.reason = "killed"
		end
		return intent
	end

	-- CRIPPLED: IT TURNS WHERE IT STANDS (task 116). Karen, 2026-10-03: "can be hit to back part
	-- start to do circles with first legs on". The back legs are gone, so there is no route to
	-- follow and nothing to flee to -- it drags itself round at a crawl until the wound finishes it.
	-- The DECISION is here, where every decision is; the movement goes out as `targetVelocity` and
	-- `facing` like any other, so `Body` is still the only thing that touches the boar's Instances.
	--
	-- `_crippleTurn` is +-1, chosen once when it was hit, so one animal circles one way rather than
	-- wobbling. The wound keeps running down: `Wound.advance` is charged by the distance it actually
	-- covers, so a circling boar bleeds out on the same model as a running one -- a single rump slug
	-- is given 81 of `FLIGHT.rear`'s 90 studs (`Wound.flightStuds` tapers it past MORTAL), which at
	-- `CRIPPLE_SPEED` is about 18 s of circling, inside `BLEED_OUT_MAX_SECONDS`.
	--
	-- THE ACCEL RAMP IS BYPASSED, DOWNWARDS ONLY, and that is said out loud because the bolt above is
	-- the only other place in the system that does it. The back legs went in one frame; a boar easing
	-- from 38 studs/s to 3 over `ACCEL` would slide for half a second looking like it chose to slow
	-- down. It can only ever LOWER the setpoint, so nothing here can make a boar outrun its ramp.
	if self._state == "CRIPPLED" then
		local wound = config.WOUND
		local turn = math.rad(wound.CRIPPLE_TURN_DEG) * dt * (self._crippleTurn or 1)
		self._desired = unit(rotateY(self._heading, turn), self._heading)
		self._heading = self._desired
		self._speed = wound.CRIPPLE_SPEED
		intent.state = "CRIPPLED"
		intent.targetVelocity = self._heading * self._speed
		intent.facing = self._heading
		return intent
	end

	if obs.pathFailed then
		self._waypoints = nil
	elseif obs.waypoints then
		self._waypoints = obs.waypoints
		self._consumed = 0
	end

	self._sinceSense += dt
	self._sinceRepath += dt
	local sensing = self._sinceSense >= config.SENSE_INTERVAL
	if sensing then
		self._sinceSense = 0
	end

	-- PERCEPTION, EVERY STEP (task 118, section 4.2), because the route's anchor and the bolt's
	-- threat point below are read every frame today: perceiving at 5 Hz instead would leave a
	-- fleeing boar's away-vector up to 0.2 s stale, which is a change to the FLAG-OFF world and this
	-- task may not make one. The `probe` is the expensive half and the only per-tick half -- it is
	-- handed in on a sense tick only, and only when `REQUIRE_SIGHT` asks for it at all.
	local perception = Brain.perceive(position, obs.threats, config, if sensing then obs.probe else nil)
	self._perception = perception
	local centroid, nearestDistance = perception.centroid, perception.nearestDistance
	self._threatPoint = centroid
	-- While bolting, the shot point IS the threat, even when the shooter is 200 studs away and would
	-- never have registered as one. That is what makes the existing route code run the boar away
	-- from whoever shot it, with no new rule (hit-zones design section 6.2 item 5).
	if not self._threatPoint and self._boltFor > 0 then
		self._threatPoint = self._lastShotPoint
	end

	-- The sounder, as data. nil for a lone boar and for every existing spec, and `isLeader` for the
	-- animal at the front -- which is why the leader runs exactly the code it ran before.
	local sounder = obs.sounder
	local follower = sounder ~= nil and not sounder.isLeader

	local aware = config.SENSE ~= nil and config.SENSE.ENABLED == true
	if sensing and aware then
		-- THE PRECEDENCE TABLE (task 118, section 3.2). Everything below `elseif sensing then` is
		-- the code this file ran before task 118 and is reached whenever the flag is off.
		self:_senseAware(position, obs, perception, follower)
	elseif sensing then
		if self._state == "IDLE" then
			-- HERD PANIC. A sounder bolts as one animal: without this rule the first contact tears
			-- the group in half, because only the members with the driver inside their own
			-- DETECT_RADIUS would run.
			local leaderPanicked = follower and (sounder.leaderState == "FLEE" or sounder.leaderState == "WOUNDED")
			if nearestDistance <= config.DETECT_RADIUS or leaderPanicked then
				self._state = "FLEE"
				self._sinceCalm = 0
				self._sinceRepath = math.huge -- path immediately
				self._grazeFor = 0
			else
				self:_senseIdle(position, obs)
			end
		elseif self._state == "WOUNDED" or self._boltFor > 0 then
			-- A WOUNDED boar NEVER returns to IDLE, and a bolting one does not calm mid-bolt. The
			-- difference between a fleeing boar and a wounded one is the wound, not the timer.
			self._sinceCalm = 0
		else
			if nearestDistance > config.CALM_RADIUS then
				self._sinceCalm += config.SENSE_INTERVAL
				-- HERD CALM, the reverse of the panic rule: a follower settles only when its own
				-- timer has run AND the leader has settled. While scattering there is no leader,
				-- and then the timer alone decides, as it does for a lone boar.
				local leaderCalm = (not follower) or sounder.leaderState == nil or sounder.leaderState == "IDLE"
				if self._sinceCalm >= config.CALM_TIME and leaderCalm then
					self._state = "IDLE"
					self._home = flat(position)
					self._waypoints = nil
					self._target = nil
				end
			else
				self._sinceCalm = 0
			end
		end
	end

	self._at = flat(position)
	local stuck = self:_updateStuck(dt, position)
	-- ...AND THE FAST ONE (task 150), which answers in 0.75 s where `_updateStuck` takes up to four.
	local wedged = self:_updateWedge(dt, position)

	local desiredDirection, desiredSpeed
	local stuckTurn = nil :: number?
	-- ORDERED (task 127). It is tested FIRST because it outranks every mood: a line crossing a road
	-- does not stop to look at the edge, does not blend with its sounder and does not pick its own
	-- route. The states above this -- despawn, carcass, hit, collapse, CRIPPLED -- already returned.
	local ordered = self:ordered()
	-- A FRIGHT OUTRANKS AN ORDER (task 126 round 2, the Reviewer's blocking finding). The drive
	-- re-orders every member of a line every Heartbeat, so with the order tested first the straight
	-- flight and the edge stop -- the two things this task is FOR -- could never move an animal in
	-- the only world that turns `MOVE` on: a shot boar kept walking its trail at the ordered speed.
	-- The order is dropped outright rather than suspended, because the drive will hand out a new one
	-- within `LINE.ORDER_SECONDS` anyway, and a line that re-forms behind a bolted animal is the
	-- behaviour Karen described: *"they run and run straigh like in real life"*.
	if ordered and (self:_flightActive() or self._checkFor > 0) then
		self._orderFor = 0
		self._orderPoint = nil
		ordered = false
	end
	if ordered then
		local target = self._orderPoint :: Vector3
		local toTarget = target - flat(position)
		local line = config.LINE
		if toTarget.Magnitude <= line.ARRIVE_STUDS then
			-- ARRIVED: hold the heading and stop, rather than jittering on top of the point.
			desiredDirection = self._desired
			desiredSpeed = 0
		else
			desiredDirection = unit(toTarget, self._desired)
			desiredSpeed = self._orderSpeed
		end
		-- The wound still slows it: an animal bleeding out does not keep station.
		if obs.wound and obs.wound.speedScale then
			desiredSpeed *= obs.wound.speedScale
		end
	elseif self._checkFor > 0 then
		-- STOPPED AT THE EDGE, LOOKING THE WAY IT IS GOING (task 126). Karen: *"they can stop before
		-- entering the road"*. It is ALERT's own shape -- a zero setpoint and the facing left alone
		-- -- without entering ALERT, because ALERT is about a THREAT and has its own timers, its own
		-- refractory period and its own `_alertPoint`. The animal has not seen anything; it is
		-- standing at the edge of the open. The file stacks up behind it for free: every follower's
		-- target is a point behind the one ahead, and the one ahead has stopped.
		desiredDirection = self._desired
		desiredSpeed = 0
	elseif self._state == "ALERT" then
		-- HEAD UP, STOPPED, TURNED TO THE CAUSE (section 4.4). Both limits are the existing ones:
		-- the facing goes through the `TURN_RATE` slew below (a 180-degree turn takes 0.79 s) and
		-- the setpoint through the `ACCEL` ramp, so an animal that was walking stops over 0.07 s
		-- rather than snapping. No new mechanism, and no path: ALERT never routes.
		local toward = self._alertPoint
		desiredDirection = if toward then unit(flat(toward) - flat(position), self._desired) else self._desired
		desiredSpeed = 0
	elseif self._state == "AVOID" then
		-- TURNED AWAY AND TROTTING OFF toward the one target `_enterAvoid` drew. The existing
		-- Reynolds fallback, one target, and no `pathRequest` anywhere in this branch.
		local target = self._avoidPoint
		desiredDirection = if target then unit(flat(target) - flat(position), self._heading) else self._heading
		self._heading = desiredDirection
		desiredSpeed = config.TROT_SPEED
		-- The wound scales the SETPOINT here exactly as it does in FLEE below: an animal that is
		-- bleeding does not trot away at full speed.
		if obs.wound and obs.wound.speedScale then
			desiredSpeed *= obs.wound.speedScale
		end
	elseif self._state == "IDLE" then
		-- THE CALM REPERTOIRE, in place of the old "grazing or wandering" boolean (task 117). The
		-- activity decides the speed setpoint and travels out as `intent.activity`, which is the
		-- only thing `Body` needs to draw it. Nothing else about IDLE changes: the heading, the home
		-- pull, the probe turn and the sounder slot are all the code they were.
		desiredSpeed = self:_stepCalm(dt)
		desiredDirection = if follower then self:_idleSounderDirection(position, obs) else self._heading
	else
		if stuck then
			self._sinceRepath = math.huge
		end
		if
			self._sinceRepath >= config.REPATH_INTERVAL
			or obs.forceRepath
			or (not self._waypoints and not obs.pathFailed)
		then
			local anchor = centroid or self._threatPoint or flat(position)
			self._target = self:_routeTarget(position, anchor)
			-- LEADER_PATHS_ONLY: one ComputeAsync per sounder, whatever its size. Five members each
			-- asking could also each be routed through a DIFFERENT gate in a hedge, which splits the
			-- sounder in two -- so this is an invariant, not an optimisation. The one exception is a
			-- follower the stuck detector has reported twice, because the alternative is a member
			-- wedged behind a trunk that the sidestep alone does not clear.
			local mayPath = not follower or not config.SOUNDER.LEADER_PATHS_ONLY or (stuck and self._stuckCount >= 2)
			if mayPath then
				intent.pathRequest = self._target
			end
			self._sinceRepath = 0
		end
		desiredDirection = if follower then self:_sounderDirection(position, obs) else self:_fleeDirection(position)
		-- THE LATCHED LINE WINS (task 126). Karen: *"run straigh like in real life"*. While the
		-- flight is live this replaces every steering blend above -- the route, the away-vector, the
		-- sounder's cohesion -- with the ONE heading taken at the moment of the fright. The whisker
		-- below still deflects it, and nothing else does.
		--
		-- A FOLLOWER STILL KEEPS ITS SEPARATION, because the alternative is nine animals on one line
		-- pushing through each other at 24 studs/s: the latched heading is blended with the boids
		-- repulsion term alone, which is the file running rather than the file dissolving.
		if self:_flightActive() then
			local line = self._flightHeading :: Vector3
			if follower and sounder ~= nil and not sounder.scattering then
				local settings = config.SOUNDER
				local flatPos = flat(position)
				local separation = Vector3.zero
				for _, neighbour in ipairs(sounder.neighbours or {}) do
					local away = flatPos - flat(neighbour.position)
					local distance = away.Magnitude
					if distance > 1e-6 then
						local push = (settings.SEPARATION_STUDS / math.max(distance, 1)) - 1
						if push > 0 then
							separation += unit(away, line) * push
						end
					end
				end
				desiredDirection = unit(line * settings.FLEE_WEIGHT + separation * settings.SEPARATION, line)
			else
				desiredDirection = line
			end
		end
		if stuck and self._stuckCount >= 2 then
			-- Turning `desiredDirection` was still not enough: the slew below moves the output by at
			-- most TURN_RATE * dt (~3.8 degrees at 60 Hz) and the next tick recomputes it, so the
			-- boar kept pushing into the obstruction (review round 2, finding 1). The offset is
			-- applied to self._desired itself, after the slew, so it persists; the slew then pulls
			-- it back toward the route over ~pi/2 / TURN_RATE ~ 0.4 s, which is the sidestep.
			stuckTurn = if self._rng:NextNumber() < 0.5 then -math.pi / 2 else math.pi / 2
			self._waypoints = nil -- the route led into whatever we are stuck on
		end
		self._heading = desiredDirection
		-- SPRINT INSIDE THE FLUSH BAND, TROT OUTSIDE IT (section 3.1). With the flag off every
		-- flush radius IS `DETECT_RADIUS`, so `reaction == "flee"` is exactly the old
		-- `nearestDistance <= DETECT_RADIUS` and this line is one rule instead of a branch.
		local threatened = perception.reaction == "flee" or self._boltFor > 0
		desiredSpeed = if threatened then config.SPRINT_SPEED else config.TROT_SPEED
		-- A FOLLOWER MATCHES ITS LEADER instead of deciding for itself, so the sounder does not
		-- concertina. With no leader -- scattering, or promoted away this tick -- the rule above
		-- applies, which is the lone boar's rule.
		if follower and sounder.leader and not sounder.scattering then
			desiredSpeed = self:_followerSpeed(position, obs)
		end
		-- A PUSH IS NOT A SPOOK (task 123 round 2). Karen: *"they seems walking to fast / they has
		-- to trot or walk when spook then fast"*. Above this line a fleeing animal has exactly two
		-- speeds, 38 and 18, and the Forest Test's beater stands 11 studs behind the rearmost
		-- against a 15-stud flush radius -- so every crossing was a 40 km/h gallop. See
		-- `Boar.CONFIG.PACE`.
		--
		-- A CLAMP, AND THE ORDER MATTERS: it is applied AFTER the follower's leader-matching (so a
		-- herd is paced as a herd) and BEFORE the wound's scale (so a bleeding animal is still
		-- slower than a healthy one at the same pace, rather than being pulled back up to it).
		local pace = config.PACE
		if pace ~= nil and pace.ENABLED == true then
			-- A WOUNDED ANIMAL IS SPOOKED BY DEFINITION, and leaving it out was the bug Karen
			-- photographed: *"potential bug shooted boar stands and stay"* (task 124 step 0).
			--
			-- MEASURED. A body slug charges 55 damage -- mortal -- and buys the animal a 108-stud
			-- flight, and `Wound.advance` spends that flight on the distance it ACTUALLY covers. The
			-- bolt runs for `WOUND.BOLT_SECONDS` = 3; after that `spooked` was false, so the clamp
			-- below put a dying boar on `PACE.WALK_SPEED` = 4.5 and the wound's own `speedScale`
			-- took it from there: traced at 21.8 -> 19.3 -> 17.0 -> 15.0 -> 6.1 -> **2.3 studs/s**,
			-- with 11 studs of its flight still to run. At 2 studs/s that is most of a minute, and
			-- `BLEED_OUT_MAX_SECONDS` (25) is the only reason it ends at all -- twenty-five seconds
			-- of a boar standing on the road, which is exactly what she saw.
			--
			-- The wound's `speedScale` is still what slows it down; what it now scales is a RUN.
			-- ...AND A HEARD SHOT IS A SPOOK UNTIL THE ANIMAL IS OFF THE BOARD (task 150). Without
			-- this line the latch above keeps it in FLEE and pointed at the exit, and then the
			-- `else` below clamps it to `WALK_SPEED` the moment the four-second bolt ends -- an
			-- animal "fleeing" at a walking pace, which is Karen's *"they run then com closer to
			-- road and stay"* with the running taken out.
			local spooked = self._boltFor > 0 or perception.spook == true or self._state == "WOUNDED" or self._heardShot
			if spooked then
				-- A shot, a hit, or a man who is not driving: run, whatever the push said -- and
				-- `_runSpeed` is what running is, which Karen slowed in round 4.
				--
				-- IT IS SET, NOT RAISED, AND THAT WAS A BUG FOR TWO ROUNDS. `math.max` cannot LOWER
				-- the `SPRINT_SPEED` the line above assigns whenever `threatened` is true -- and a
				-- spooked animal is threatened by construction -- so every frightened boar still
				-- bolted at 38 studs/s however low `RUN_SPEED` was set. MEASURED: animals crossing
				-- within `SPOOK_STUDS` of the hunter at 37.7-38.0 while the rest of their wave
				-- trotted at 11-18, which is exactly Karen's *"when they fleet make speed slover
				-- it's to fast"*. The pace is the pace: one assignment, no arithmetic with the
				-- number it is replacing.
				desiredSpeed = self:_runSpeed()
			else
				-- CROWDED BY A BEATER, or asked by the drive to get across the road: a trot.
				local crowded = perception.reaction == "flee" and perception.distance <= pace.TROT_WITHIN_STUDS
				local pushedOn = crowded or self._urgeFor > 0
				desiredSpeed = math.min(desiredSpeed, if pushedOn then pace.TROT_SPEED else pace.WALK_SPEED)
			end
		end
		-- ...AND A FOLLOWER THAT HAS FALLEN BEHIND MAY CLOSE THE GAP (task 126). Karen: *"it could be
		-- lines of boars like in real life"*.
		--
		-- THE CLAMP ABOVE WAS ERASING THE CATCH-UP, which is the third bug of this family in this
		-- round. `_followerSpeed` returns `leader.speed * CATCHUP` for a member out of position, and
		-- the pace clamp then does `math.min(that, WALK_SPEED)` -- so a straggler was pinned to
		-- exactly its leader's own walking speed and could never close a single stud. MEASURED: a
		-- sounder of eight shed six members in about eight seconds, every one of them to the
		-- break-away rule, and "a member that left never rejoins".
		--
		-- IT IS APPLIED AFTER THE CLAMP AND CAPPED AT A TROT, so a file closes up at the pace Karen
		-- accepted for a crossing rather than sprinting back into formation.
		local move = config.MOVE
		if move ~= nil and move.ENABLED == true and follower and sounder.ahead ~= nil and not sounder.scattering then
			local gap = (flat(self:_filePoint(sounder) or position) - flat(position)).Magnitude
			if gap > move.FILE_TOLERANCE_STUDS and not self:_flightActive() then
				desiredSpeed = math.min(desiredSpeed * move.FILE_CATCHUP, config.TROT_SPEED)
			end
		end

		-- The wound scales the SETPOINT, never the physics (hit-zones design section 5.5): bleeding
		-- out ramps it down over the flight and a leg hit multiplies a limp on top. The ACCEL ramp
		-- below still applies, so a wounded boar slows the way it accelerates.
		if obs.wound and obs.wound.speedScale then
			desiredSpeed *= obs.wound.speedScale
		end
	end

	-- ROUND THE TRUNK FIRST (task 123 round 3), so every state -- idle, avoiding, fleeing -- gets
	-- the same answer to "something solid is in front of me" and the blends above do not each need
	-- their own.
	-- NO WHISKERS WHILE ORDERED (task 127), and the Director's brief says so in as many words: the
	-- route was computed by `PathfindingService` against the same trunks the whiskers would find, and
	-- a follower is walking where the leader already walked. A 55-degree deflection on top of that is
	-- an animal arguing with a path that was already correct -- and it is what takes it off the trail
	-- and into the tree beside it.
	if obs.whisker ~= nil and not ordered then
		-- WHICH WAY ROUND, DECIDED ONCE PER OBSTACLE (task 126). While `WHISKER_HOLD_SECONDS` has not
		-- run out the side is held, so a flickering pair of side casts cannot swap a 55-degree
		-- deflection every frame and leave the animal turning on the spot.
		local move = config.MOVE
		local hold = move ~= nil and move.ENABLED == true
		local sees = (obs.whisker.ahead or obs.whisker.left or obs.whisker.right) == true
		if hold and sees then
			if self._whiskerFor <= 0 then
				-- A NEW OBSTACLE: choose the clear side now, and commit to it.
				self._whiskerPick = if obs.whisker.left and not obs.whisker.right
					then 1
					elseif obs.whisker.right and not obs.whisker.left then -1
					else self._whiskerSide
			end
			self._whiskerFor = move.WHISKER_HOLD_SECONDS
		end
		local locked = hold and self._whiskerFor > 0
		desiredDirection = Brain.steerAroundTrunk(
			desiredDirection,
			obs.whisker,
			config,
			if locked then self._whiskerPick else self._whiskerSide,
			locked
		)
	end

	-- ...AND WEDGED IS WEDGED, IN ANY STATE (task 123 round 3). The existing sidestep lives in the
	-- FLEE branch and waits for the SECOND stuck report -- two `STUCK_TIME`s, four seconds -- so a
	-- grazing or avoiding animal pressed against a trunk had no recovery at all, and a fleeing one
	-- had four seconds of pushing first. MEASURED after the whiskers went in: one animal of twenty
	-- still sat with a 4.5 setpoint and a 0.3 body speed for five seconds.
	--
	-- `stuck` IS THE REPORT, NOT A TIMER: `_updateStuck` runs a clock that resets every
	-- `STUCK_TIME` and answers true on the tick it finds the animal has not covered `STUCK_DIST`.
	-- So this is "the FIRST time anyone noticed", against the flee branch's second, and it reuses
	-- that branch's own `stuckTurn` -- which is applied to `_desired` AFTER the slew, so it
	-- persists instead of being smoothed away over the next third of a second.
	if stuck and self._stuckCount >= 1 and not ordered and config.PACE ~= nil and config.PACE.ENABLED == true then
		stuckTurn = stuckTurn or (self._whiskerSide * math.pi / 2)
		self._waypoints = nil -- whatever the route said, it leads into this
	end

	-- ...AND WHILE THE SIDESTEP IS HELD, THE LINE IT CHOSE IS THE STEERING TARGET (task 150). Every
	-- branch above has just recomputed a direction from the same route, centroid or latched heading
	-- that walked the animal into the trunk, and the whiskers have just deflected it by another 55
	-- degrees -- so without this the next frame's blend pulls straight back into what it is stuck on
	-- and the 90-degree turn is undone before the body has moved. `_desired` already holds the
	-- sidestep, because it was applied after the slew on the firing tick.
	if self._wedgeFor > 0 and not wedged then
		desiredDirection = self._desired
	end

	-- HOW IT TURNS (task 123 round 3). Karen: *"they feels like walkin strange like with mouse
	-- turning here there has to be more natural"*. MEASURED before this: a walking boar's facing
	-- changed by up to 688 deg/s. Three things, all data in `Boar.CONFIG.PACE`, and all off with it:
	--   1. the TARGET is smoothed over `HEADING_SMOOTH_SECONDS` -- one frame of a steering blend is
	--      noise, not an intention, exactly as `SPEED_SMOOTH_SECONDS` says of one frame of motion;
	--   2. inside `TURN_DEADBAND_DEG` the animal does not turn at all, which is what stops the nose
	--      hunting left and right on a straight line;
	--   3. the slew is capped by GAIT rather than by one `TURN_RATE` for all three.
	local turnRate = config.TURN_RATE
	local pace = config.PACE
	if pace ~= nil and pace.ENABLED == true then
		local wantedNow = unit(desiredDirection, self._desired)
		local blendIn = math.clamp(dt / math.max(pace.HEADING_SMOOTH_SECONDS, 1e-6), 0, 1)
		local previous = self._wanted or wantedNow
		self._wanted = unit(previous * (1 - blendIn) + wantedNow * blendIn, wantedNow)
		desiredDirection = self._wanted
		local degrees = pace.WALK_TURN_DEG
		if self._speed >= config.MODEL.RUN_FROM then
			degrees = pace.RUN_TURN_DEG
		elseif self._speed >= config.MODEL.TROT_FROM then
			degrees = pace.TROT_TURN_DEG
		end
		if ordered then
			-- A ROUTE'S CORNER IS REAL, so it may be taken at a real rate: `LINE.TURN_SCALE` above
			-- the gait's own cap. Still a cap, and still per gait -- a walking boar does not pivot.
			degrees *= config.LINE.TURN_SCALE
		end
		turnRate = math.rad(degrees)
		local dot = math.clamp(self._desired:Dot(unit(desiredDirection, self._desired)), -1, 1)
		if math.deg(math.acos(dot)) <= pace.TURN_DEADBAND_DEG then
			desiredDirection = self._desired
		end
	end

	-- Turn rate and acceleration limit the SETPOINT, not the physics, so both are assertable with no
	-- physics at all (design section 5).
	-- THE TURN BUDGET WAS BUILT HERE, MEASURED, AND TAKEN OUT AGAIN (task 126). It is recorded rather
	-- than quietly dropped, because the obvious thing to try next is to put it back.
	--
	-- The idea was a backstop for Karen's *"they shouldn do circles like I see now"*: an animal that
	-- spent more than `MOVE.TURN_BUDGET_DEG` of turning inside `TURN_WINDOW_SECONDS` held its heading
	-- for `TURN_HOLD_SECONDS`. It was measured at every step and it never once helped:
	--     baseline, no budget                        4,660 windows over 300 deg, worst 742
	--     budget, hold skipped while a whisker fired  4,281, worst 663
	--     budget, every file member exempt            5,326, worst 981
	--     budget, only a closing follower exempt      7,728, worst 883
	--
	-- IT WAS MAKING THE THING IT MEASURED WORSE, AND THE MECHANISM IS PLAIN ONCE SEEN: while held, the
	-- heading was re-fed through `Brain.steerAroundTrunk`, which rotates by `WHISKER_TURN_DEG` (55
	-- degrees) whenever a whisker fires -- so every held frame near a trunk added another 55 degrees
	-- to an ALREADY deflected heading, compounding frame after frame. A hold that keeps re-deflecting
	-- is a rotation generator, which is the opposite of a hold.
	--
	-- WHAT IS KEPT IS THE PART THAT WORKED: the orbits are removed AT THEIR THREE SOURCES instead --
	-- the sounder's centroid (`_idleSounderDirection`), the pull toward home (`_senseIdle`) and the
	-- route's flipping lateral bias (`_routeTarget`) -- each of which is a point an animal steered
	-- continuously at, which is what an orbit is.
	--
	-- `MOVE.TURN_WINDOW_SECONDS`, `TURN_BUDGET_DEG` and `TURN_HOLD_SECONDS` are left in the config
	-- with this measurement beside them so the next reader does not spend the round I spent.
	self._desired = slew(self._desired, unit(desiredDirection, self._desired), turnRate * dt)

	-- THE WEDGE SIDESTEP, AFTER THE SLEW AND AFTER THE OTHER ONE (task 150). It is applied to
	-- `_desired` itself rather than to the steering target, for the reason review round 2 of task 123
	-- wrote down: the slew moves the output by about 3.8 degrees a frame and the next frame
	-- recomputes the target, so a turn asked for upstream is smoothed away before the animal has
	-- moved. Held for `WEDGE_HOLD_SECONDS`, which is what makes it a step round the trunk rather
	-- than one frame of flinch.
	--
	-- IT IS NOT GATED ON `ordered`. The slow sidestep is, because a line following a computed route
	-- should not argue with it -- but an ordered animal pinned against a trunk is an ordered animal
	-- that is not going anywhere, and task 127's own rule is that the drive re-orders every member
	-- every Heartbeat, so one sidestep costs it nothing.
	if wedged and self._wedgeTurn ~= 0 then
		self._desired = unit(rotateY(self._desired, self._wedgeTurn), self._desired)
	end
	if stuckTurn then
		self._desired = unit(rotateY(self._desired, stuckTurn), self._desired)
	end
	local maxStep = config.ACCEL * dt
	self._speed += math.clamp(desiredSpeed - self._speed, -maxStep, maxStep)

	intent.state = self._state
	-- WHAT A CALM BOAR IS DOING (task 117), published only while IDLE so every other state draws
	-- exactly what it drew before. `Body` turns it into a clip; nothing else reads it.
	intent.activity = if self._state == "IDLE" and self._calm then self._calm.name else nil
	intent.activityDraw = if intent.activity ~= nil then self._calmDraws else nil
	intent.targetVelocity = self._desired * self._speed
	intent.facing = self._desired
	return intent
end

return Brain
