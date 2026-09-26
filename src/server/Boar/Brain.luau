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
-- Design: docs/design/boar-ai.md (sections 4, 5, 7), docs/design/hit-zones.md (section 6)
-- Note:   docs/research/2026-09-24-boar-ai.md, docs/research/2026-09-25-hit-zones.md

local Brain = {}
Brain.__index = Brain

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
	}
end

-- Nearest threat and the centroid of those inside `radius`, both flat. Returns nil when there are none.
function Brain:_threatInfo(position: Vector3, threats)
	local nearest, nearestDistance = nil, math.huge
	local sum, count = Vector3.zero, 0
	local radius = self._config.DETECT_RADIUS

	for _, threat in ipairs(threats) do
		local d = flatDistance(position, threat.position)
		if d < nearestDistance then
			nearest, nearestDistance = flat(threat.position), d
		end
		if d <= radius then
			sum += flat(threat.position)
			count += 1
		end
	end

	if not nearest then
		return nil, math.huge
	end
	local centroid = if count > 0 then sum / count else nearest
	return centroid, nearestDistance
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
	if (self._state == "FLEE" or self._state == "WOUNDED") and position.Z <= field.exitZ then
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

	if self._grazeFor <= 0 and rng:NextNumber() < config.GRAZE_CHANCE then
		self._grazeFor = rng:NextNumber(config.GRAZE_MIN, config.GRAZE_MAX)
	end
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
	local offset = if self._columnFor > 0 then column else (settings.FORMATION[slot] or column)
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

	if event.severity == "mortal" then
		self._state = "WOUNDED"
	elseif self._state == "IDLE" then
		self._state = "FLEE"
	end

	-- BOLT. The one documented bypass of the ACCEL ramp in the whole system: a shot animal does not
	-- accelerate over 0.63 s. It is an assignment, once per hit, not a new rule.
	self._boltFor = wound.BOLT_SECONDS
	self._grazeFor = 0
	self._sinceCalm = 0
	self._sinceRepath = math.huge -- path immediately, as the IDLE->FLEE transition already does
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
	self._boltFor = math.max(0, self._boltFor - dt)
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

	local centroid, nearestDistance = self:_threatInfo(position, obs.threats)
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

	if sensing then
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
	if self._state == "IDLE" then
		if self._grazeFor > 0 then
			self._grazeFor -= dt
			desiredSpeed = 0
		else
			desiredSpeed = config.WANDER_SPEED
		end
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
		local threatened = nearestDistance <= config.DETECT_RADIUS or self._boltFor > 0
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
	intent.targetVelocity = self._desired * self._speed
	intent.facing = self._desired
	return intent
end

return Brain
