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
-- Design: docs/design/boar-ai.md (sections 4, 5, 7)
-- Note:   docs/research/2026-09-24-boar-ai.md

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

	self._waypoints = nil :: { Vector3 }?
	self._consumed = 0 -- waypoints of the current route already passed; see Brain:consumed()
	self._target = nil :: Vector3?
	self._threatPoint = nil :: Vector3?

	self._stuckFrom = flat(start)
	self._stuckTime = 0
	self._stuckCount = 0

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
	if self._state == "FLEE" and position.Z <= field.exitZ then
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

	if sensing then
		if self._state == "IDLE" then
			if nearestDistance <= config.DETECT_RADIUS then
				self._state = "FLEE"
				self._sinceCalm = 0
				self._sinceRepath = math.huge -- path immediately
				self._grazeFor = 0
			else
				self:_senseIdle(position, obs)
			end
		else
			if nearestDistance > config.CALM_RADIUS then
				self._sinceCalm += config.SENSE_INTERVAL
				if self._sinceCalm >= config.CALM_TIME then
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
		desiredDirection = self._heading
	else
		if stuck then
			self._sinceRepath = math.huge
		end
		if
			self._sinceRepath >= config.REPATH_INTERVAL
			or obs.forceRepath
			or (not self._waypoints and not obs.pathFailed)
		then
			local anchor = centroid or flat(position)
			self._target = self:_routeTarget(position, anchor)
			intent.pathRequest = self._target
			self._sinceRepath = 0
		end
		desiredDirection = self:_fleeDirection(position)
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
		desiredSpeed = if nearestDistance <= config.DETECT_RADIUS then config.SPRINT_SPEED else config.TROT_SPEED
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
