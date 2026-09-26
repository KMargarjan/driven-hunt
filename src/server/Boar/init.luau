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
local Wound = require(script.Wound)

local Boar = {}

Boar.Brain = Brain
-- The pure damage model, exported for specs exactly as Brain is, and for the same reason: it must be
-- drivable with no world (hit-zones design section 3.2).
Boar.Wound = Wound

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
	-- Albedo, not the colour you see. The cause of the near-black sides in the Task 18 screenshots
	-- was this number, not the material: a face turned away from the sun is lit by the place's
	-- Lighting.Ambient / OutdoorAmbient, both left at the default RGB(70, 70, 70) = 0.275, so
	-- RGB(90, 80, 70) rendered at roughly RGB(25, 22, 19) on the shaded sides while the arena floor
	-- (RGB(150, 150, 150)) stayed near-white. Raised, and raised in saturation too, because the
	-- bluish sky ambient washes the hue out of a shaded face: measured on screen at this value
	-- (Task 22), the lit sides read warm sand and the shaded sides a warm grey-brown, both clearly
	-- against the floor from all four sides. Karen's dial.
	BODY_COLOR = Color3.fromRGB(198, 158, 110),
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
	-- A guard, not a feature. Raised from 4 in Milestone 1.7a: a killed boar stays in the list
	-- for CARCASS_SECONDS = 120 and counts against this, so four kills inside two minutes would
	-- stop a drive dead (docs/design/drive.md section 6.3). The drive's own MAX_ALIVE_BOARS = 4
	-- counts only boars that are neither DOWN nor GONE.
	maxBoars = 8,

	BOUNDS_SLACK = 10,
	FALL_LIMIT = 50,

	-- HIT ZONES (hit-zones design section 4.2). Three parts welded to the trunk, each PROTRUDING
	-- past the surface a pellet can arrive from, because a ray returns the nearest surface and a
	-- nested part would never be hit. The trunk itself stays HitZone = "body", so belly, flank, rear
	-- and brisket -- whatever no zone part covers -- are the default zone. Local coordinates: the
	-- trunk is 2 x 3 x 5.5 and its -Z is the boar's front.
	ZONES = {
		ORDER = { "head", "chest", "legs" }, -- creation order; also the order specs walk them in
		ZONE_TINT = true, -- Karen's dial: a grey-box teaching aid, off when the model arrives
		PROTRUSION = 0.06, -- studs every zone part stands proud by, so the ray meets it first
		head = {
			part = "ZoneHead",
			size = Vector3.new(1.2, 1.2, 1.4),
			offset = Vector3.new(0, 0.5, -3.2), -- 1.15 studs proud of the front face
			tint = Color3.fromRGB(206, 120, 120),
		},
		chest = {
			part = "ZoneChest",
			size = Vector3.new(2.12, 2.01, 1.7),
			offset = Vector3.new(0, 0.555, -1.6), -- heart/lungs behind the shoulder
			tint = Color3.fromRGB(198, 150, 150),
		},
		legs = {
			part = "ZoneLegs",
			size = Vector3.new(2.12, 1.0, 5.4),
			offset = Vector3.new(0, -1.0, 0.15), -- the bottom third, the whole length, past the rear
			tint = Color3.fromRGB(150, 128, 104),
		},
	},

	-- THE WOUND MODEL (hit-zones design sections 5 and 11.2). Two quantities per zone: damage decides
	-- WHETHER the boar dies, flight decides HOW FAR it gets first. Every one of these is Karen's feel
	-- value except COLLAPSE_ANGULAR_IMPULSE, which is physics.
	WOUND = {
		LETHAL = 100,
		MORTAL = 50,
		DAMAGE = {
			head = { Slug = 100, Pellet = 34 }, -- a slug kills; 3 pellets kill
			chest = { Slug = 100, Pellet = 25 }, -- a slug kills; 2 pellets are already mortal
			body = { Slug = 55, Pellet = 11 }, -- one slug is mortal; 5 pellets are
			legs = { Slug = 30, Pellet = 6 }, -- one slug is NOT enough: "several hits needed"
		},
		-- Studs run before collapsing, from the worst zone hit. Validated against Stokke et al.
		-- (2018): efd = 1.14*M^0.73 m and mfd = 4.92*M^0.73 m give 100 and 429 studs at 80 kg
		-- (docs/research/2026-09-25-hit-zones.md source C).
		FLIGHT = { head = 0, chest = 0, body = 120, legs = 420 },
		BLEED_OUT_MAX_SECONDS = 25, -- ceiling: a wounded boar wedged against a wall still dies
		WOUND_SPEED_START = 1.0,
		WOUND_SPEED_END = 0.45, -- 38 -> 17 studs/s across the flight
		LIMP_SCALE = 0.75, -- 28.5 studs/s: still faster than a player's 16, so it is catchable
		BOLT_SECONDS = 3.0, -- sprint away from the shot point whatever the threats say
		BOLT_KICK = 0.8, -- the setpoint jumps to 0.8 x sprint on the hit tick: the one ACCEL bypass
		-- How far back along the impact normal the "where the shot came from" hint is placed when the
		-- caller did not say. It was the one number in the hit path written inline (TASKS.md 28a(f)),
		-- against this system's own claim that every number is in CONFIG. It is a hint: the Brain runs
		-- away from the point, so the distance only has to put it clearly on the far side of the body.
		BOLT_HINT_STUDS = 10,
		FLASH_COLOR = Color3.fromRGB(190, 40, 40),
		FLASH_SECONDS = 0.25, -- 15 frames: long enough to read, short enough not to look like state
		CARCASS_SECONDS = 120,
		-- MEASURED, 2026-09-25, and it replaces the design's COLLAPSE_ANGULAR_IMPULSE = 1200, which
		-- does not work. A 2 x 3 x 5.5 boar weighs 23.1. Probed in Play against a body moving at a
		-- sprint, as a killed boar is: an impulse of 1200 does NOTHING (up stays 1.00, and the first
		-- carcass screenshot was a box standing to attention); 2000 still does not topple it; 3500
		-- topples it but throws it 9 studs into the air, and 12000 launched the real boar to y = 87 at
		-- 161 studs/s. Setting AssemblyAngularVelocity directly does not topple it at any rate up to
		-- 12 rad/s. What works is gravity: a 2-wide, 3-tall box tips at atan(1/1.5) = 33.7 degrees, so
		-- rolling the carcass past that angle at the moment it dies makes it fall over on its own --
		-- measured peak height 0.2 studs, final UpVector.Y = 0.00, i.e. lying on its side.
		COLLAPSE_ROLL_DEG = 45, -- comfortably past the 33.7-degree tipping angle
	},

	-- Pathfinding agent. Tunables, not structure: they decide whether the navmesh will route a
	-- 2 x 3 x 5.5 body past the cover blocks (review round 1, finding 6).
	AGENT = {
		AgentRadius = 2,
		AgentHeight = 3,
		AgentCanJump = false,
		AgentCanClimb = false,
	},

	-- THE SOUNDER (a group of boars; German Rotte). Every number here is the behaviour half --
	-- how a sounder stands, follows, spreads and breaks. How BIG a release is and how often is the
	-- drive's half and lives in Match.CONFIG.SOUNDER, which this task does not build.
	--
	-- Design: docs/design/drive.md ("the sounder's behaviour, and who writes it", and "the sounder
	-- numbers") -- normative for sounders until docs/design/boar-ai.md is regenerated.
	-- Note:   docs/research/2026-09-25-drive.md (Addendum 2)
	-- Pattern: Reynolds leader following + boids separation/cohesion/alignment, blended into the
	-- setpoint this Brain already slews and ramps. https://www.red3d.com/cwr/steer/gdc99/ and
	-- https://www.red3d.com/cwr/boids/ -- technique taken, no code.
	SOUNDER = {
		SPAWN_RING_STUDS = 10, -- 5 on a ring of 10 stand 11.8 studs apart with a 5.5-long body
		PAD_MARGIN_STUDS = 4, -- clamped inside spawnRadius - 4, so it is 10 at a pad radius of 14 and of 30
		SLOT_BACK_STUDS = 9, -- ~1.6 body lengths behind the leader. Karen's dial
		SLOT_SIDE_STUDS = 7, -- two abreast, clear of each other. Karen's dial
		-- The wedge, in the LEADER'S frame: +X is its right, +Z is BEHIND it. ~18 studs wide, well
		-- inside a 96-stud hedge gate (map-generator.md section 15.1), so a sounder goes through a
		-- gate without any code that knows a gate exists.
		FORMATION = {
			[2] = Vector3.new(-7, 0, 9),
			[3] = Vector3.new(7, 0, 9),
			[4] = Vector3.new(-3.5, 0, 18),
			[5] = Vector3.new(3.5, 0, 18),
		},
		COLUMN_SPACING_STUDS = 9, -- single file: slot i -> (0, 0, (i-1) * 9)
		COLUMN_LATCH_SECONDS = 1.5, -- how long blockedAhead holds the column after the probe clears
		SLOT_TOLERANCE_STUDS = 5, -- inside it, cohesion is 0 (arrival) and the speed matches the leader
		NEIGHBOUR_STUDS = 25, -- the boids neighbourhood: a boid only sees flockmates within a radius
		SEPARATION_STUDS = 7, -- 1.3 body lengths; below it, push apart
		COHESION = 1.0,
		-- SEPARATION DOMINATES, and this is THIS BUILD'S decision, not Reynolds': the boids page
		-- states no hierarchy among the three rules (Addendum 2 corrects the design on that). The
		-- reason is local: five CanCollide bodies of ~23 mass driven at MAX_FORCE = 6000
		-- interpenetrating is a physics fight, not a graphical artefact.
		SEPARATION = 1.6,
		ALIGNMENT = 0.4,
		FLEE_WEIGHT = 0.8,
		IDLE_COHESION = 0.5, -- a grazing sounder is a loose group, not a wedge. Karen's dial
		IDLE_SPREAD_STUDS = 18, -- ...and only past this does an idle member close up at all
		CATCHUP = 1.15, -- while out of position, capped at SPRINT_SPEED
		BREAK_STUDS = 60, -- 1.5 x DETECT_RADIUS. Karen's dial
		BREAK_SECONDS = 4, -- ...for this long, and then it is a lone boar. Karen's dial
		SCATTER_SECONDS = 6, -- the sounder breaks up at the shot. Karen's dial
		SCATTER_SEPARATION = 3.0, -- they spread while scattering
		SCATTER_ON_HIT = true, -- ANY hit, not only a kill. Karen's dial
		LEAVE_ON_MORTAL = true, -- a mortally wounded animal drops out of the sounder. Karen's dial
		LEADER_PATHS_ONLY = true, -- one ComputeAsync per sounder (design, "one route per sounder")
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
				if #points == 0 then
					-- Success with nothing usable past where we already stand. The Runtime counts this
					-- as a failure, so the world must record it too, or the diagnostic has a blind spot
					-- exactly where the silent straight-line fallback lives (review round 5, finding 1).
					local reason = "success: no waypoints"
					pathProblems[reason] = (pathProblems[reason] or 0) + 1
					done(nil)
					return
				end
				done(points)
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
	-- THE SOUNDERS, and this list is the only place a group exists. The Brain holds no reference to
	-- another boar and Body knows nothing about groups, so "who is in a sounder, who leads it and
	-- how long it is scattering" has exactly one writer (CLAUDE.md rule 3).
	self._sounders = {}
	self._nextSounderId = 0
	self._signal = Instance.new("BindableEvent")
	self._connection = nil
	self._destroyed = false
	self._stats = {
		pathRequests = 0,
		pathFailures = 0,
		pathBlocked = 0,
		spawned = 0,
		despawned = 0,
		hits = 0,
		pelletsTaken = 0,
		damageTaken = 0,
		downed = 0, -- Downed fired: the animal died
		killed = 0, -- its carcass was removed; downed - killed is how many carcasses are lying about
		escapedWounded = 0, -- crossed the exit line carrying damage
		zoneHits = {}, -- PELLETS per zone, so it sums to pelletsTaken
		unknownZoneHits = 0, -- hits carrying a zone no DAMAGE row knows: an attribute typo, not free
		tallylessHits = 0, -- hits with no per-pellet tally, charged at the dominant zone
		soundersSpawned = 0,
		soundersDissolved = 0, -- fell to one member (or none): the survivor is a lone boar again
		leaderPromotions = 0,
		membersLeft = 0, -- left ALIVE: mortally wounded, or too far for too long. A despawn is not one
		scatters = 0, -- a hit on any member latches the whole sounder's scatter
	}

	self.Despawned = self._signal.Event
	self._hitSignal = Instance.new("BindableEvent")
	self.Hit = self._hitSignal.Event
	-- Downed and Despawned are two events on purpose: 1.7 must be able to award a kill at the moment
	-- the boar dies, not CARCASS_SECONDS later, and the body leaving the world is a different fact
	-- from the animal dying (hit-zones design section 8.3).
	self._downedSignal = Instance.new("BindableEvent")
	self.Downed = self._downedSignal.Event

	self._folder = Body.ensureFolder(world.parent, world.folderName)
	world.folder = self._folder
	return self
end

function Runtime:folder(): Folder
	return self._folder
end

function Runtime:stats()
	local out = table.clone(self._stats)
	out.zoneHits = table.clone(self._stats.zoneHits) -- table.clone is shallow; this is a counter, not state
	return out
end

-- A copy of one boar's wound state, or nil. There is no setter: takeHit and step are the only
-- writers (hit-zones design section 3.3).
function Runtime:woundOf(id: string)
	for _, entry in ipairs(self._boars) do
		if entry.id == id then
			return table.clone(entry.wound)
		end
	end
	return nil
end

-- The ONE way a hit enters this system (shotgun design section 6.2). The weapon publishes
-- HitReported; BoarBoot -- the composition root that already knows both systems -- calls this.
-- Neither owner requires the other.
--
-- Since Milestone 1.5 it also charges the damage. The MODEL is Boar.Wound and is pure; this
-- function is the only place a wound state is stored, the Brain is told a severity and a direction
-- and never a number, and Body does the flashing. Returns false for a part that is not one of this
-- runtime's live boars, and for a boar that is already down -- so a carcass cannot be killed twice
-- and 1.7 cannot double-count a kill.
function Runtime:takeHit(part: BasePart, hit): boolean
	for _, entry in ipairs(self._boars) do
		if entry.body.part == part then
			local state = entry.brain:state()
			if entry.dead or state == "DOWN" or state == "GONE" then
				return false
			end

			local wound = self._config.WOUND
			local payload = if type(hit) == "table" then hit else {}
			local nextWound, severity = Wound.apply(entry.wound, payload, wound)
			local record = nextWound.wounds[#nextWound.wounds]
			entry.wound = nextWound
			entry.lastHit = payload

			self._stats.hits += 1
			self._stats.pelletsTaken += record.pellets
			self._stats.damageTaken += record.damage
			if record.tallyless then
				self._stats.tallylessHits += 1
			end
			if record.unknownPellets > 0 then
				self._stats.unknownZoneHits += 1
			end
			-- TALLIED UNDER THE ZONE THE DAMAGE WAS CHARGED TO (TASKS.md 28a(g)). An unknown zone
			-- name used to open its own bucket here while Wound.apply charged its damage to `body`,
			-- so zoneHits and damageTaken disagreed about the same pellets. unknownZoneHits above is
			-- still what counts the typo.
			local zoneHits = self._stats.zoneHits
			local function tally(zone: string, count: number)
				if count <= 0 then
					return -- Wound.apply's `charge` returns early on the same condition
				end
				local charged = Wound.chargedZone(zone, self._config.WOUND)
				zoneHits[charged] = (zoneHits[charged] or 0) + count
			end
			if type(payload.zones) == "table" and next(payload.zones) ~= nil then
				for zone, count in pairs(payload.zones) do
					tally(zone, count)
				end
			else
				tally(record.zone, record.pellets)
			end

			-- THE SOUNDER BREAKS UP AT THE SHOT (SCATTER_ON_HIT): any hit on any member, not only a
			-- kill. A real sounder scatters, and it also stops a group from queueing up in front of
			-- one barrel. The latch is here rather than in the step because a hit is the event.
			local sounder = self:_sounderRecord(entry.sounderId)
			if sounder and self._config.SOUNDER.SCATTER_ON_HIT then
				sounder.scatterFor = self._config.SOUNDER.SCATTER_SECONDS
				self._stats.scatters += 1
			end

			Body.setFlash(entry.body, wound.FLASH_SECONDS)

			-- Where the shot came from, for the bolt. The shooter's position when the caller knows
			-- it; otherwise a point out along the impact normal, which faces back toward whoever
			-- fired. Either way it is a hint, and the Brain runs away from it rather than at it.
			local from = payload.shooterPosition
			if not from and typeof(payload.normal) == "Vector3" then
				from = Body.position(entry.body) + payload.normal * self._config.WOUND.BOLT_HINT_STUDS
			end
			table.insert(entry.hitEvents, { severity = severity, zone = record.zone, from = from })

			self._hitSignal:Fire({
				id = entry.id,
				zone = record.zone,
				zones = payload.zones,
				ammo = record.ammo,
				pellets = record.pellets,
				damage = record.damage,
				severity = severity,
				distance = record.distance,
				shooterUserId = record.shooterUserId,
				at = record.at,
			})
			return true
		end
	end
	return false
end

-- Removes every live boar, through the same despawn path a boar takes when it leaves the field:
-- Body.destroy, releasePath, the Despawned signal. Added in Milestone 1.7a because the DRIVE decides
-- when a boar exists (docs/design/drive.md section 6.3) and the Match may not touch a boar Instance
-- itself -- so the request comes here, to the owner. Carcasses go too: the drive is over.
function Runtime:clear(reason: string?)
	for index = #self._boars, 1, -1 do
		local entry = self._boars[index]
		self:_despawn(entry, index, reason or "cleared", Body.position(entry.body))
	end
	-- ...and no sounder is left behind. This is NOT counted as a dissolve: the drive is over, and a
	-- counter that moves when the world is torn down cannot be used to ask how the drive went.
	table.clear(self._sounders)
end

function Runtime:boars()
	local out = {}
	for _, entry in ipairs(self._boars) do
		table.insert(out, entry.handle)
	end
	return out
end

-- ---------------------------------------------------------------- sounders
--
-- Design: docs/design/drive.md ("the boar runtime's sounder interface"). Every function below
-- returns a COPY: there is no setter, and the drive never reads any of them in production -- they
-- exist for specs, for diagnostics, and for the step's own bookkeeping.

local function flatOf(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function Runtime:_sounderRecord(id: string?)
	if id == nil then
		return nil
	end
	for _, record in ipairs(self._sounders) do
		if record.id == id then
			return record
		end
	end
	return nil
end

function Runtime:_entryById(id: string?)
	if id == nil then
		return nil
	end
	for _, entry in ipairs(self._boars) do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

-- The member nearest the exit line leads, tie-broken by id: the animal at the front leads, and it
-- is one line and deterministic. `promoted` is false the first time (a spawn is not a promotion).
function Runtime:_chooseLeader(record, promoted: boolean)
	local best, bestKey = nil, nil
	for _, id in ipairs(record.memberIds) do
		local entry = self:_entryById(id)
		if entry then
			local key = math.abs(Body.position(entry.body).Z - self._field.exitZ)
			if best == nil or key < bestKey or (key == bestKey and entry.id < best.id) then
				best, bestKey = entry, key
			end
		end
	end
	if best == nil then
		record.leaderId = nil
		return
	end
	-- SLOTS STAY DISTINCT: the new leader takes slot 1 and hands its own slot to whoever held 1.
	-- Two members sharing a slot would steer at the same point in the formation, which is the one
	-- way a wedge turns into a collision.
	local vacated = best.slot
	if vacated ~= nil and vacated ~= 1 then
		for _, id in ipairs(record.memberIds) do
			local other = self:_entryById(id)
			if other and other.id ~= best.id and other.slot == 1 then
				other.slot = vacated
			end
		end
	end
	record.leaderId = best.id
	best.slot = 1
	if promoted then
		self._stats.leaderPromotions += 1
	end
end

-- Takes one member out of a sounder while it is still ALIVE (a despawn is handled by the
-- bookkeeping instead). The boar keeps running as a lone boar: obs.sounder is nil from the next
-- step, so every existing code path applies to it unchanged.
function Runtime:_leaveSounder(record, entry, counted: boolean)
	entry.sounderId = nil
	entry.slot = nil
	entry.awayFor = 0
	if counted then
		self._stats.membersLeft += 1
	end
	if record.leaderId == entry.id then
		record.leaderId = nil
	end
end

-- Per step, before any boar is asked to decide anything: membership, the leader, the scatter timer,
-- the two ways a live member leaves, and the dissolve. Nothing here touches a Brain or a Body.
function Runtime:_stepSounders(dt: number, snapshot)
	local sounderConfig = self._config.SOUNDER
	for index = #self._sounders, 1, -1 do
		local record = self._sounders[index]
		record.scatterFor = math.max(0, record.scatterFor - dt)

		-- MEMBERSHIP IS REBUILT FROM THE BOARS, never edited in two places: a boar that despawned
		-- (escaped, out of bounds, carcass timed out) is simply not in the list any more.
		local members = {}
		for _, entry in ipairs(self._boars) do
			if entry.sounderId == record.id then
				table.insert(members, entry)
			end
		end

		-- LEAVE_ON_MORTAL: a dying animal cannot hold formation, and if the group matched its speed
		-- the whole sounder would crawl to the line.
		if sounderConfig.LEAVE_ON_MORTAL then
			for position = #members, 1, -1 do
				local entry = members[position]
				local severity = entry.wound.severity
				if severity == "mortal" or severity == "lethal" then
					self:_leaveSounder(record, entry, true)
					table.remove(members, position)
				end
			end
		end

		local leader = nil
		for _, entry in ipairs(members) do
			if entry.id == record.leaderId then
				leader = entry
			end
		end

		-- TOO FAR FOR TOO LONG, counted with dt and reset on coming back inside. There is no
		-- re-forming rule: a member that left never rejoins (design, "a member leaves in exactly
		-- four ways").
		if leader then
			local leaderAt = flatOf(snapshot[leader.id] and snapshot[leader.id].position or Body.position(leader.body))
			for position = #members, 1, -1 do
				local entry = members[position]
				if entry.id ~= leader.id then
					local at = snapshot[entry.id] and snapshot[entry.id].position or Body.position(entry.body)
					if (flatOf(at) - leaderAt).Magnitude > sounderConfig.BREAK_STUDS then
						entry.awayFor += dt
						if entry.awayFor >= sounderConfig.BREAK_SECONDS then
							self:_leaveSounder(record, entry, true)
							table.remove(members, position)
						end
					else
						entry.awayFor = 0
					end
				end
			end
		end

		record.memberIds = {}
		for _, entry in ipairs(members) do
			table.insert(record.memberIds, entry.id)
		end

		if #members <= 1 then
			-- DISSOLVED. One animal is not a sounder, and the survivor has no per-step group work
			-- left. A sounder crossing the line dissolves itself this way for free.
			for _, entry in ipairs(members) do
				self:_leaveSounder(record, entry, false)
			end
			table.remove(self._sounders, index)
			self._stats.soundersDissolved += 1
		elseif leader == nil then
			self:_chooseLeader(record, true)
		end
	end
end

-- ONE OBSERVATION per member per step, or nil for a lone boar. Everything in it is a plain value:
-- the Brain decides with data and never reaches into another boar (design, the ownership table).
function Runtime:_sounderObs(entry, snapshot)
	local record = self:_sounderRecord(entry.sounderId)
	if record == nil then
		return nil
	end
	local sounderConfig = self._config.SOUNDER
	local mine = snapshot[entry.id]
	if mine == nil then
		return nil
	end
	local at = flatOf(mine.position)
	local scattering = record.scatterFor > 0
	local isLeader = record.leaderId == entry.id

	local sum, count = Vector3.zero, 0
	local neighbours = {}
	for _, id in ipairs(record.memberIds) do
		local sample = snapshot[id]
		if sample then
			sum += flatOf(sample.position)
			count += 1
			if id ~= entry.id and (flatOf(sample.position) - at).Magnitude <= sounderConfig.NEIGHBOUR_STUDS then
				-- The boids neighbourhood (https://www.red3d.com/cwr/boids/): a member only sees
				-- flockmates within a radius, which is what keeps this O(n^2) over n <= 5.
				table.insert(neighbours, { position = sample.position, velocity = sample.velocity })
			end
		end
	end

	-- WHILE SCATTERING THERE IS NO LEADER, for everybody: cohesion and alignment have nothing to
	-- point at, and each member runs its own route with the existing Reynolds fallback.
	local leader, leaderState = nil, nil
	if not isLeader and not scattering then
		local leaderEntry = self:_entryById(record.leaderId)
		local sample = leaderEntry and snapshot[leaderEntry.id]
		if leaderEntry and sample then
			leaderState = leaderEntry.brain:state()
			leader = {
				position = sample.position,
				velocity = sample.velocity,
				facing = sample.facing,
				speed = flatOf(sample.velocity).Magnitude,
			}
		end
	end

	return {
		isLeader = isLeader,
		slot = entry.slot or 1,
		scattering = scattering,
		leaderState = leaderState,
		leader = leader,
		centroid = if count > 0 then sum / count else at,
		neighbours = neighbours,
	}
end

-- A COPY of one sounder, in the order the design names: leader first, then by slot.
function Runtime:_sounderView(record)
	local ordered = {}
	for _, id in ipairs(record.memberIds) do
		local entry = self:_entryById(id)
		table.insert(ordered, { id = id, slot = (entry and entry.slot) or math.huge })
	end
	table.sort(ordered, function(a, b)
		if a.slot == b.slot then
			return a.id < b.id
		end
		return a.slot < b.slot
	end)
	local memberIds = {}
	for _, row in ipairs(ordered) do
		table.insert(memberIds, row.id)
	end
	return {
		id = record.id,
		leaderId = record.leaderId,
		memberIds = memberIds,
		scatterFor = record.scatterFor,
		bornAt = record.bornAt,
	}
end

function Runtime:sounders()
	local out = {}
	for _, record in ipairs(self._sounders) do
		table.insert(out, self:_sounderView(record))
	end
	return out
end

function Runtime:sounderOf(boarId: string)
	local entry = self:_entryById(boarId)
	local record = entry and self:_sounderRecord(entry.sounderId)
	if record == nil then
		return nil
	end
	return self:_sounderView(record)
end

-- The drive's pre-check reads these two rather than guessing at this module's internals: a release
-- is held back by the PURE machine before it is ever attempted, because Runtime:spawn asserts and
-- an assert inside the Heartbeat step kills the step, not the spawn (design section 6.3, hazard 1).
function Runtime:capacity(): number
	return self._config.maxBoars
end

function Runtime:count(): number
	return #self._boars -- carcasses included: they hold a slot for CARCASS_SECONDS
end

-- ALL OR NOTHING: it creates the whole sounder or nothing at all, so a half sounder cannot exist
-- and the drive's budget arithmetic can never disagree with the world. A size of 1 is exactly
-- Runtime:spawn and creates NO sounder record -- which is why the flag-OFF world has no group code
-- running anywhere: obs.sounder is nil and every existing path applies unchanged.
function Runtime:spawnSounder(center: Vector3, size: number, maxSpread: number?)
	assert(not self._destroyed, "Boar runtime is destroyed")
	size = math.floor(tonumber(size) or 0)
	if size < 1 or #self._boars + size > self._config.maxBoars then
		return {}
	end
	if size == 1 then
		return { self:spawn(center) }
	end

	local config = self._config
	local sounderConfig = config.SOUNDER
	-- The ring is clamped inside the pad the MAP guarantees, because Runtime:spawn overwrites the
	-- caller's Y with groundY + BODY_SIZE.Y/2 + SPAWN_CLEARANCE: a member placed on a slope off the
	-- pad would be spawned inside a hill (docs/design/map-generator.md section 11).
	local radius = math.max(
		config.BODY_SIZE.Z,
		math.min(
			sounderConfig.SPAWN_RING_STUDS,
			(maxSpread or sounderConfig.SPAWN_RING_STUDS) - sounderConfig.PAD_MARGIN_STUDS
		)
	)
	-- The phase is from the runtime's own Random, so two releases at one marker do not stand in the
	-- same footprints.
	local phase = self._rng:NextNumber(0, math.pi * 2)

	self._nextSounderId += 1
	local record = {
		id = string.format("Sounder%d", self._nextSounderId),
		leaderId = nil :: string?,
		memberIds = {},
		scatterFor = 0,
		bornAt = os.clock(),
	}

	local handles = {}
	for index = 1, size do
		local angle = phase + (index - 1) * (math.pi * 2 / size)
		local at = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local handle = self:spawn(at)
		local entry = self._boars[#self._boars]
		entry.sounderId = record.id
		entry.slot = index
		entry.awayFor = 0
		table.insert(record.memberIds, entry.id)
		table.insert(handles, handle)
	end

	table.insert(self._sounders, record)
	self._stats.soundersSpawned += 1
	self:_chooseLeader(record, false)
	return handles
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
		wound = Wound.new(), -- the ONE wound state, written only by takeHit and step
		hitEvents = {}, -- hits since the last step; handed to the Brain and cleared
		lastPosition = at,
		bornAt = os.clock(),
		-- sounderId and slot stay nil for a lone boar, which is what makes obs.sounder nil and
		-- every existing code path apply to it unchanged.
		awayFor = 0,
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
	if reason == "killed" then
		self._stats.killed += 1
	elseif reason == "escaped" and entry.wound.damage > 0 then
		self._stats.escapedWounded += 1
	end
	-- The existing four fields keep their names and meanings; the wound is additive, so a listener
	-- written against the Milestone 1.2 payload still works (hit-zones design section 2.2).
	self._signal:Fire({
		id = entry.id,
		reason = reason,
		position = position,
		aliveFor = os.clock() - entry.bornAt,
		wounded = entry.wound.damage > 0,
		mortallyWounded = entry.wound.severity == "mortal" or entry.wound.severity == "lethal",
		damage = entry.wound.damage,
		wounds = entry.wound.wounds,
		contributors = entry.wound.contributors,
	})
end

function Runtime:step(dt: number)
	if self._destroyed then
		return
	end
	local config = self._config
	local threats = self._world.threats()

	-- ONE SNAPSHOT FIRST. A sounder is about where its members are THIS tick: assembling the
	-- observations inside the loop below would let one member see a neighbour before it moved and
	-- another after, which is a formation that depends on the order of a list. It also reads each
	-- body's position and velocity once instead of twice.
	local snapshot = {}
	for _, entry in ipairs(self._boars) do
		snapshot[entry.id] = {
			position = Body.position(entry.body),
			velocity = Body.velocity(entry.body),
			facing = entry.body.part.CFrame.LookVector,
		}
	end
	if #self._sounders > 0 then
		self:_stepSounders(dt, snapshot)
	end

	for index = #self._boars, 1, -1 do
		local entry = self._boars[index]
		local sample = snapshot[entry.id]
		local position = if sample then sample.position else Body.position(entry.body)
		local facing = if sample then sample.facing else entry.body.part.CFrame.LookVector

		-- A mortal wound runs out over the distance the boar ACTUALLY covers, not over a timer, so
		-- a boar held against a wall does not bleed out at full speed. BLEED_OUT_MAX_SECONDS is the
		-- ceiling for exactly that case, and it lives in Wound.advance with the rest of the model.
		local moved = (position - entry.lastPosition) * Vector3.new(1, 0, 1)
		entry.lastPosition = position
		local collapse = false
		if not entry.body.collapsed then
			-- A carcass has nothing left to run out, and advancing it would allocate and re-freeze a
			-- wound state 60 times a second for the whole CARCASS_SECONDS (review round 1, note 6).
			entry.wound, collapse = Wound.advance(entry.wound, moved.Magnitude, dt, config.WOUND)
		end

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

		local hitEvents = entry.hitEvents
		entry.hitEvents = {}

		local intent = entry.brain:step(dt, {
			position = position,
			velocity = if sample then sample.velocity else Body.velocity(entry.body),
			threats = threats,
			-- nil for a lone boar, and then the Brain runs exactly the code it ran before this
			-- task. Plain values only: the Brain never holds a reference to another boar.
			sounder = self:_sounderObs(entry, snapshot),
			waypoints = waypoints,
			pathFailed = pathFailed,
			blockedAhead = blockedAhead,
			forceRepath = forceRepath,
			hitEvents = hitEvents,
			wound = {
				severity = entry.wound.severity,
				speedScale = Wound.speedScale(entry.wound, config.WOUND),
				collapse = collapse,
			},
		})

		if intent.downed then
			-- Exactly once per boar: the Brain reports `downed` on the tick it enters DOWN and never
			-- again, so the kill cannot be published twice.
			self._stats.downed += 1
			Body.collapse(entry.body, config.WOUND)
			self._downedSignal:Fire(
				Wound.killRecord(entry.wound, entry.id, position, os.clock() - entry.bornAt, config.WOUND)
			)
		end

		Body.stepFlash(entry.body, dt, config.WOUND)

		if intent.despawn then
			self:_despawn(entry, index, intent.reason or "outOfBounds", position)
		elseif not entry.body.collapsed then
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
	table.clear(self._sounders)
	self._signal:Destroy()
	self._hitSignal:Destroy()
	self._downedSignal:Destroy()
end

return Boar
