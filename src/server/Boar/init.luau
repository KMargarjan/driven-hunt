-- Boar: the owner of boar state, movement and lifetime (CLAUDE.md rule 3). It holds the one CONFIG
-- table, the runtime list, the Heartbeat loop, the path threads and the Despawned signal. Brain
-- (decisions) and Body (Instances) are private to it and are called by nothing else.
--
-- Pattern: navmesh route + steering follow + an explicit three-state machine with an injected world.
--   Roblox PathfindingService  https://create.roblox.com/docs/characters/pathfinding
--     CreatePath -> ComputeAsync -> GetWaypoints; Path.Blocked carries blockedWaypointIdx, so we
--     recompute only when the obstacle is ahead of us (the one idea copied from SimplePath).
--   Reynolds steering (GDC 1999) https://www.red3d.com/cwr/steer/gdc99/   -- in Brain
--   Network ownership https://create.roblox.com/docs/physics/network-ownership  -- in Body
--   Roblox units (1 stud = 28 cm) https://create.roblox.com/docs/physics/units  -- every number below
--
-- Nothing happens on require: only BoarBoot starts production, so a spec can require this module and
-- test the Brain with no boar in the world.
--
-- Design: docs/design/boar-ai.md
-- Note:   docs/research/2026-09-24-boar-ai.md
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Brain = require(script.Brain)
local Body = require(script.Body)

local Boar = {}

Boar.Brain = Brain

-- Every number the system has. Derived at 1 stud = 0.28 m (Roblox units), so a 40 km/h boar is
-- 11.1 m/s = 39.7 studs/s, and a 1.5 m x 0.9 m x 0.5 m boar is 5.5 x 3 x 2 studs. The research note
-- originally assumed 1 stud = 1 m; the design corrected it and the addendum records that.
Boar.CONFIG = {
	-- movement
	SPRINT_SPEED = 38, -- studs/s, a real boar's ~40 km/h. Karen's dial.
	TROT_SPEED = 18, -- must exceed the default Humanoid.WalkSpeed of 16 or drivers cannot push it
	WANDER_SPEED = 4, -- grazing pace
	ACCEL = 60, -- studs/s^2: sprint in ~0.63 s
	TURN_RATE = 4, -- rad/s (~230 deg/s): no 180-degree snaps
	DT_CLAMP = 0.1, -- a server hitch cannot fling the boar

	-- senses
	DETECT_RADIUS = 40, -- 1/10 of the arena span
	CALM_RADIUS = 70, -- hysteresis, so the state does not flicker at exactly DETECT_RADIUS
	CALM_TIME = 4, -- seconds beyond CALM_RADIUS before returning to IDLE
	SENSE_INTERVAL = 0.2, -- reaction <= 0.2 s + one frame, against the 0.5 s requirement

	-- idle wander (Reynolds)
	HOME_RADIUS = 120,
	WANDER_JITTER = 0.35, -- rad per sense tick
	HOME_PULL = 0.6, -- radians per sense tick, rotating the heading back toward home (see Brain)
	GRAZE_CHANCE = 0.15, -- per sense tick
	GRAZE_MIN = 1,
	GRAZE_MAX = 3,
	PROBE_LENGTH = 6, -- ~one body length
	PROBE_TURN = 1.6, -- rad

	-- fleeing and the route
	REPATH_INTERVAL = 0.5, -- FLEE only; IDLE never paths
	WAYPOINT_RADIUS = 4,
	ROUTE_SIDE_BIAS = 60, -- > DETECT_RADIUS/2, so the route leaves the threat's circle
	EDGE_MARGIN = 20,
	STUCK_DIST = 3,
	STUCK_TIME = 2,

	-- the body
	BODY_SIZE = Vector3.new(2, 3, 5.5), -- width, height, length; a Part's LookVector is its -Z
	BODY_COLOR = Color3.fromRGB(90, 80, 70),
	MAX_FORCE = 6000,
	MAX_TORQUE = 20000,
	ALIGN_RESPONSIVENESS = 25,
	SPAWN_CLEARANCE = 0.5, -- studs above the ground, so it settles instead of starting embedded

	-- the world it lives in: the Task 17 arena, 400x400 with its surface at y = 0
	field = {
		bounds = { minX = -200, maxX = 200, minZ = -200, maxZ = 200 },
		exitZ = -190, -- the far edge, the future shooter line
		groundY = 0,
	},
	-- 210 studs from exitZ, comfortably beyond HOME_RADIUS + the wander tolerance, so an idle
	-- boar cannot drift onto the exit line (review round 2, finding 6). Clear of PillarMid at
	-- (40, -40) and WallWest at (-60, -100) in the Task 17 arena.
	spawnPoint = Vector3.new(-40, 0, 20),
	maxBoars = 4, -- a guard, not a feature; production spawns one

	BOUNDS_SLACK = 10,
	FALL_LIMIT = 50,

	-- Pathfinding agent. Tunables, not structure: they decide whether the navmesh will route a
	-- 2 x 3 x 5.5 body past the cover blocks (review round 1, finding 6).
	AGENT = {
		AgentRadius = 2,
		AgentHeight = 3,
		AgentCanJump = false,
		AgentCanClimb = false,
	},

	-- The one function that decides who scares a boar (design section 4). v1: every player.
	-- Milestone 1.7 replaces the body with `player.Team == Teams.Drivers` and touches nothing else.
	isThreat = function(_player: Player): boolean
		return true
	end,
}

-- Production implementations of everything the Runtime needs from the world. A spec passes its own.
function Boar.defaultWorld(field)
	local config = Boar.CONFIG
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {}
	local paths = {} -- agentId -> Path, one per boar, created once
	local blockedListeners = {} -- agentId -> the Runtime's onBlocked for that boar
	local pathProblems = {} -- reason -> count, EVERY ComputeAsync failure, not just the last

	local world
	world = {
		field = field or config.field,
		parent = Workspace,
		folderName = "Boars",
		rng = Random.new(),

		threats = function()
			local out = {}
			for _, player in ipairs(Players:GetPlayers()) do
				if config.isThreat(player) then
					local character = player.Character
					local root = character and character.PrimaryPart
					if root then
						table.insert(out, { id = tostring(player.UserId), position = root.Position })
					end
				end
			end
			return out
		end,

		-- Exclude the boar folder, so a boar never probes itself or its herd.
		probe = function(from: Vector3, direction: Vector3, length: number): boolean
			if direction.Magnitude < 1e-6 then
				return false
			end
			params.FilterDescendantsInstances = if world.folder then { world.folder } else {}
			return Workspace:Raycast(from, direction.Unit * length, params) ~= nil
		end,

		-- One Path object per agent, created once and reused, with Path.Blocked connected to it
		-- (design section 6). Never called from inside a step: ComputeAsync yields. `done` is
		-- invoked on a later frame and the Runtime hands the result to the Brain on the next tick.
		-- `onBlocked(blockedWaypointIdx)` fires whenever the engine finds the computed route
		-- obstructed; the Runtime decides whether that index is still ahead of the boar.
		requestPath = function(agentId: string, from: Vector3, to: Vector3, done, onBlocked)
			local path = paths[agentId]
			if not path then
				path = PathfindingService:CreatePath(config.AGENT)
				paths[agentId] = path
				path.Blocked:Connect(function(blockedWaypointIdx)
					local listener = blockedListeners[agentId]
					if listener then
						listener(blockedWaypointIdx)
					end
				end)
			end
			blockedListeners[agentId] = onBlocked

			task.spawn(function()
				local ok, err = pcall(function()
					path:ComputeAsync(from, to)
				end)
				if not ok or path.Status ~= Enum.PathStatus.Success then
					-- Record WHY, not just that it failed. A permanent silent fallback to
					-- straight-line flee is the failure mode this exists to make visible, and
					-- "it failed" is not enough to act on (Task 18 harness run 1).
					local reason = if ok then tostring(path.Status) else "error: " .. tostring(err)
					pathProblems[reason] = (pathProblems[reason] or 0) + 1
					done(nil)
					return
				end
				local points = {}
				for index, waypoint in ipairs(path:GetWaypoints()) do
					if index > 1 then -- waypoint 1 is where we already are
						table.insert(points, waypoint.Position)
					end
				end
				done(if #points > 0 then points else nil)
			end)
		end,

		-- Every distinct reason a path request has failed, with a count for each. A single "last
		-- reason" slot hid any failure but the final one (review round 4, finding 2), which matters
		-- precisely when the interesting failure is the rare one. A diagnostic, not state the Brain
		-- uses.
		pathProblems = function(): { [string]: number }
			return table.clone(pathProblems)
		end,

		-- Called when a boar despawns, so its Path object and listener are not kept alive.
		releasePath = function(agentId: string)
			paths[agentId] = nil
			blockedListeners[agentId] = nil
		end,
	}
	return world
end

local Runtime = {}
Runtime.__index = Runtime

function Boar.newRuntime(world)
	local self = setmetatable({}, Runtime)
	self._world = world
	self._config = table.clone(Boar.CONFIG)
	for key, value in pairs(world.config or {}) do
		self._config[key] = value
	end
	self._field = world.field or self._config.field
	self._rng = world.rng or Random.new()
	self._boars = {}
	self._nextId = 0
	self._signal = Instance.new("BindableEvent")
	self._connection = nil
	self._destroyed = false
	self._stats = { pathRequests = 0, pathFailures = 0, pathBlocked = 0, spawned = 0, despawned = 0 }

	self.Despawned = self._signal.Event

	self._folder = Body.ensureFolder(world.parent, world.folderName)
	world.folder = self._folder
	return self
end

function Runtime:folder(): Folder
	return self._folder
end

function Runtime:stats()
	return table.clone(self._stats)
end

function Runtime:boars()
	local out = {}
	for _, entry in ipairs(self._boars) do
		table.insert(out, entry.handle)
	end
	return out
end

function Runtime:spawn(position: Vector3?)
	assert(not self._destroyed, "Boar runtime is destroyed")
	assert(#self._boars < self._config.maxBoars, "Boar runtime is at maxBoars")

	local config = self._config
	local at = position or config.spawnPoint
	at = Vector3.new(at.X, self._field.groundY + config.BODY_SIZE.Y / 2 + config.SPAWN_CLEARANCE, at.Z)

	self._nextId += 1
	local id = string.format("Boar%d", self._nextId)
	local body = Body.create(config, self._folder, id, at)
	local brain = Brain.new(config, self._field, at, self._rng)

	local handle = {
		id = id,
		part = body.part,
		state = function()
			return brain:state()
		end,
		position = function()
			return Body.position(body)
		end,
	}

	table.insert(self._boars, {
		id = id,
		body = body,
		brain = brain,
		handle = handle,
		pending = false, -- a path request is in flight
		waypoints = nil,
		pathFailed = false,
		forceRepath = false, -- set by the world's Path.Blocked listener
		bornAt = os.clock(),
	})
	self._stats.spawned += 1
	return handle
end

function Runtime:_requestPath(entry, to: Vector3)
	if entry.pending then
		return
	end
	entry.pending = true
	self._stats.pathRequests += 1
	local from = Body.position(entry.body)
	self._world.requestPath(entry.id, from, to, function(points)
		entry.pending = false
		if entry.dead then
			return -- a late reply for a despawned boar
		end
		if points then
			entry.waypoints = points
			entry.pathFailed = false
		else
			entry.waypoints = nil
			entry.pathFailed = true
			self._stats.pathFailures += 1
		end
	end, function(blockedWaypointIdx)
		-- Repath only when the obstruction is still ahead of the boar. A blockage it has already
		-- driven past is not worth a ComputeAsync (design section 6). The Brain counts how many
		-- waypoints it has passed; the engine's index is 1-based over the whole route, and our
		-- list dropped waypoint 1, so the boar's next waypoint is index consumed + 2.
		if entry.dead then
			return
		end
		if blockedWaypointIdx >= entry.brain:consumed() + 2 then
			entry.forceRepath = true
			self._stats.pathBlocked += 1
		end
	end)
end

function Runtime:_despawn(entry, index: number, reason: string, position: Vector3)
	entry.dead = true
	Body.destroy(entry.body)
	table.remove(self._boars, index)
	if self._world.releasePath then
		self._world.releasePath(entry.id)
	end
	self._stats.despawned += 1
	self._signal:Fire({
		id = entry.id,
		reason = reason,
		position = position,
		aliveFor = os.clock() - entry.bornAt,
	})
end

function Runtime:step(dt: number)
	if self._destroyed then
		return
	end
	local config = self._config
	local threats = self._world.threats()

	for index = #self._boars, 1, -1 do
		local entry = self._boars[index]
		local position = Body.position(entry.body)
		local facing = entry.body.part.CFrame.LookVector

		local blockedAhead = false
		if self._world.probe then
			blockedAhead = self._world.probe(position, facing, config.PROBE_LENGTH)
		end

		local waypoints = entry.waypoints
		entry.waypoints = nil -- the Brain takes ownership of the list it is handed
		local pathFailed = entry.pathFailed
		entry.pathFailed = false
		local forceRepath = entry.forceRepath
		entry.forceRepath = false

		local intent = entry.brain:step(dt, {
			position = position,
			velocity = Body.velocity(entry.body),
			threats = threats,
			waypoints = waypoints,
			pathFailed = pathFailed,
			blockedAhead = blockedAhead,
			forceRepath = forceRepath,
		})

		if intent.despawn then
			self:_despawn(entry, index, intent.reason or "outOfBounds", position)
		else
			Body.drive(entry.body, intent.targetVelocity, intent.facing)
			if intent.pathRequest then
				self:_requestPath(entry, intent.pathRequest)
			end
		end
	end
end

-- Connects Heartbeat and returns a function that disconnects it.
function Runtime:run()
	assert(not self._connection, "Boar runtime is already running")
	self._connection = RunService.Heartbeat:Connect(function(dt)
		self:step(dt)
	end)
	local connection = self._connection
	return function()
		if connection.Connected then
			connection:Disconnect()
		end
		if self._connection == connection then
			self._connection = nil
		end
	end
end

function Runtime:destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	for _, entry in ipairs(self._boars) do
		entry.dead = true
		Body.destroy(entry.body)
		if self._world.releasePath then
			self._world.releasePath(entry.id)
		end
	end
	table.clear(self._boars)
	self._signal:Destroy()
end

return Boar
