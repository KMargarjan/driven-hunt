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
	self._carcassFor = 0
	self._downedReported = false

	self._waypoints = nil :: { Vector3 }?
	self._consumed = 0 -- waypoints of the current route already passed; see Brain:consumed()
	self._target = nil :: Vector3?
	self._threatPoint = nil :: Vector3?

	self._stuckFrom = flat(start)
	self._stuckTime = 0
	self._stuckCount = 0

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

	-- Which way a crippled boar circles, chosen once when its back end goes (task 116).
	self._crippleTurn = nil :: number?

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
	if (self._state == "FLEE" or self._state == "WOUNDED" or self._state == "AVOID") and position.Z <= field.exitZ then
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
	local toSlot = flat(self:_slotPoint(obs.sounder)) - flat(position)
	local catchup = if toSlot.Magnitude > settings.SLOT_TOLERANCE_STUDS then settings.CATCHUP else 1
	return math.min((leader.speed or 0) * catchup, config.SPRINT_SPEED)
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
	self._speed = math.max(self._speed, config.SPRINT_SPEED * wound.BOLT_KICK)
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
function Brain:_settle(position: Vector3)
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
	if flatDistance(position, sound.position) > sense.SHOT_AUDIBLE_STUDS then
		return
	end
	self._boltFor = math.max(self._boltFor, sense.SHOT_SPRINT_SECONDS)
	self._lastShotPoint = flat(sound.position)
	self._sinceCalm = 0
	-- WOUNDED is left in WOUNDED: it is already an animal that never calms down, and the bolt above
	-- is the whole of what the sprint is.
	if state == "IDLE" or state == "ALERT" or state == "AVOID" then
		self:_flush()
	end
	-- THE BOLT KICK, the same documented ACCEL bypass a hit uses: a boar at a shotgun blast does not
	-- accelerate over 0.63 s. An assignment, once per sound, not a new rule.
	self._speed = math.max(self._speed, config.SPRINT_SPEED * config.WOUND.BOLT_KICK)
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

	local reaction = perception.reaction

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

	local stuck = self:_updateStuck(dt, position)

	local desiredDirection, desiredSpeed
	local stuckTurn = nil :: number?
	if self._state == "ALERT" then
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
		-- The wound scales the SETPOINT, never the physics (hit-zones design section 5.5): bleeding
		-- out ramps it down over the flight and a leg hit multiplies a limp on top. The ACCEL ramp
		-- below still applies, so a wounded boar slows the way it accelerates.
		if obs.wound and obs.wound.speedScale then
			desiredSpeed *= obs.wound.speedScale
		end
	end

	-- Turn rate and acceleration limit the SETPOINT, not the physics, so both are assertable with no
	-- physics at all (design section 5).
	self._desired = slew(self._desired, unit(desiredDirection, self._desired), config.TURN_RATE * dt)
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
