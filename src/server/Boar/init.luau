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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Flags = require(ReplicatedStorage:WaitForChild("Flags"))

local Brain = require(script.Brain)
local Body = require(script.Body)
local Wound = require(script.Wound)

local Boar = {}

Boar.Brain = Brain
-- The pure damage model, exported for specs exactly as Brain is, and for the same reason: it must be
-- drivable with no world (hit-zones design section 3.2).
Boar.Wound = Wound

-- THE THREE PURE RULES OF THE SKINNED MODEL (task 115), and ONLY those three. `Body` itself stays
-- private, because it writes Instances and "the only writer of a boar's Instances" is a claim that an
-- export would weaken; these take numbers and return numbers, so a spec can drive every gait, every
-- flinch, every rate and the death's held frame with no boar in the world at all -- which is the
-- same reason `Brain` and `Wound` are exported whole.
Boar.clipFor = Body.clipFor
Boar.visualOffset = Body.visualOffset
Boar.shouldFreeze = Body.shouldFreeze
-- ...and the two the carcass anchor rests on, for the same reason: a spec cannot make a physics
-- body topple on command, so the DECISION is testable even where the motion is not.
Boar.carcassIsStill = Body.carcassIsStill
Boar.shouldAnchorCarcass = Body.shouldAnchorCarcass
-- ...and the one review round 1's finding 1 turns on: whether a clip that is already playing needs
-- its rate rewritten. A HELD clip never does.
Boar.shouldAdjustRate = Body.shouldAdjustRate
-- ...and how wide the freeze window is this frame, which decides whether a death holds its last
-- frame or runs past it into the rest pose.
Boar.freezeReach = Body.freezeReach
-- ...and task 116's three: which footstep loop a speed asks for, the pitch jitter band, and the
-- shape of the dying twitch. Pure, for the same reason as every export above it -- a spec cannot
-- make a boar run, die or be heard.
Boar.stepSoundFor = Body.stepSoundFor
Boar.jitteredPitch = Body.jitteredPitch
Boar.paddleOffset = Body.paddleOffset
-- ...and the fix round's two: how much of the flinch a moving animal shows, and how long a clip
-- takes to blend in. Both are what "the hit lands on the frame the player expects" reduces to.
Boar.flinchWindow = Body.flinchWindow
Boar.fadeFor = Body.fadeFor
-- ...and the two the authored clips turn on: which pair a death is, and whether a clip has an id
-- yet. The second is the whole of "if an id is missing, the current behaviour stays".
Boar.deathClips = Body.deathClips
Boar.hasClip = Body.hasClip
-- ...and task 117's three: which activity a roll draws, the row for a name, and the clip an activity
-- draws. Pure, so every weight, every clip and every transition is a case with no boar in the world.
Boar.calmActivity = Brain.calmActivity
Boar.firstPhase = Brain.firstPhase
Boar.activityRow = Body.activityRow
Boar.activityClip = Body.activityClip

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
	-- WHERE A ROUTE STARTS, and it is NOT where the boar stands. MEASURED 2026-09-26 (Task 60), in
	-- this place, with the boar's own AGENT settings: `ComputeAsync` from the centre of an
	-- unanchored, collidable, boar-sized body returns **NoPath** -- one body or five, 10 studs
	-- apart or 20. Six studs ahead of it returns a 95-waypoint route over the same ground. The
	-- start point is inside the body, so the navmesh has no node there; Roblox's own NPCs are
	-- Humanoid characters, which pathfinding ignores, and a bare Part is not.
	--
	-- This was measured because the sounder's live spec asserts the leader's path budget and found
	-- 23 of 25 requests failing. It is NOT a sounder defect: it is every boar, since Milestone 1.2,
	-- quietly falling back to the straight-line Reynolds flee that exists for exactly this case.
	-- BODY_SIZE.Z/2 = 2.75 plus AgentRadius = 2 is 4.75; 6 clears it with a margin.
	PATH_START_AHEAD = 6,

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

	-- THE WORLD IT LIVES IN. SINCE M2.8e that is the generated map's drive corridor, not the Task 17
	-- arena: design section 17 step 6, "`Boar.CONFIG.field` to the same numbers -- a data change
	-- inside `ServerScriptService.Boar`'s own file, by its owner". It must deep-equal `Map.FIELD`,
	-- and `map_contract.spec` asserts exactly that.
	--
	-- 1,240 studs wide to hold the 1,120-stud shooter line, and `exitZ` = -820 is 120 studs PAST the
	-- forest road at z = -700: Karen's decision that the boars CROSS the road rather than stopping
	-- at it. `groundY` is 0 in both worlds, which is why the switch needs no other boar change, and
	-- the arena's old rectangle is the rollback and lives in git.
	field = {
		bounds = { minX = -620, maxX = 620, minZ = -880, maxZ = 800 },
		exitZ = -820,
		groundY = 0,
	},
	-- A FALLBACK ONLY, and its old comment described a world that no longer exists (review round 1
	-- of Task 79, note). It read "210 studs from exitZ ... clear of PillarMid and WallWest in the
	-- Task 17 arena": with `exitZ = -820` it is 840 studs, and neither part is built any more. What
	-- is still true is the reason it exists -- it is comfortably beyond HOME_RADIUS + the wander
	-- tolerance, so an idle boar cannot drift onto the exit line (Task 17 review, finding 6) -- and
	-- that it is UNUSED IN PRODUCTION: the drive always passes a marker position to `Runtime:spawn`
	-- (`docs/design/drive.md`, "`Boar.CONFIG.spawnPoint` stays unused in production").
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
		ORDER = { "head", "chest", "rear", "legs" }, -- creation order; also the order specs walk them in
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
		-- THE HINDQUARTERS (task 116). Karen, 2026-10-03: "can be hit to back part start to do circles
		-- with first legs on" -- the spine shot every hunting game has, and the one reaction this
		-- model could not express because no zone covered the back end above the legs.
		--
		-- IT IS ADDED THE WAY EVERY ZONE EXISTS AND IN NO OTHER WAY: a row here plus its `ORDER`
		-- entry. `Body.buildZones` builds whatever this table lists, `Wound` charges whatever
		-- `DAMAGE` names, and nothing in the hit path knows the difference. The three zone parts that
		-- were here, their boxes, the `body` fallback and every damage number are untouched.
		--
		-- WHERE IT SITS, FACE BY FACE, and every face is accounted for -- because a zone part FLUSH
		-- with the trunk is not a zone, it is a coin toss: two coincident surfaces at the same ray
		-- distance, and which one `Raycast` returns is the engine's business (review round 2,
		-- finding 1 -- the first version of this row was 2.0 wide, exactly the trunk's own +-1.0, so
		-- a flank shot into the rump was decided by a tie-break and could be charged to `body`).
		--   +X / -X  PROUD by `PROTRUSION`: 2 + 2 x 0.06 = 2.12, the same width `chest` and `legs`
		--            take, and the flank is the angle players actually shoot from.
		--   +Y top   PROUD by `PROTRUSION`: +1.56 against the trunk's +1.5. The top of the rump is
		--            the animal's back and a shot from above belongs to it.
		--   -Y floor NOT proud, deliberately: `legs` tops out at -0.5 and this starts at -0.3, so
		--            there is 0.2 of clear air between them. Two zone parts meeting at one surface
		--            is the same tie this row exists to remove.
		--   +Z rear  PROUD by 0.15, against the trunk's rear face at +2.75.
		--   -Z front NOT proud, deliberately: it is an interior boundary at +1.1: `chest` ends at
		--            -0.75 and the trunk is all around it, so no ray reaches it from outside.
		rear = {
			part = "ZoneRear",
			size = Vector3.new(2.12, 1.86, 1.8),
			offset = Vector3.new(0, 0.63, 2.0), -- spans x +-1.06, y -0.30..+1.56, z +1.1..+2.9
			tint = Color3.fromRGB(150, 150, 190),
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
			-- THE TRUNK'S OWN NUMBERS, because the rump IS trunk: as much meat and bone as a flank,
			-- and this row only exists so the CLASS table can call it crippling. One slug is MORTAL
			-- and well short of LETHAL, which is the whole shape of the reaction -- the back end
			-- goes, the animal is alive to be finished, and the 90-stud flight below runs it down in
			-- about 18 s of circling at `CRIPPLE_SPEED` (90 is the UNTAPERED flight;
			-- `Wound.flightStuds` tapers it by how far past MORTAL the damage is, and one 55-point
			-- slug is 5 of the 50-point span, so 81 studs -- review round 2, note 1). Below mortal it
			-- is a graze, and `Brain` refuses to cripple on a graze (see `_reactToHit`): a boar that
			-- could neither die nor escape would circle in the arena for ever.
			rear = { Slug = 55, Pellet = 11 },
		},
		-- Studs run before collapsing, from the worst zone hit. Validated against Stokke et al.
		-- (2018): efd = 1.14*M^0.73 m and mfd = 4.92*M^0.73 m give 100 and 429 studs at 80 kg
		-- (docs/research/2026-09-25-hit-zones.md source C).
		-- `rear` is SHORT on purpose and is not a flight distance in the paper's sense: a crippled
		-- animal does not run, it turns on the spot. The number is how long it has left, carried by
		-- the same mechanism as every other zone's.
		-- `rear` went 60 -> 90 with `CRIPPLE_SPEED` 3 -> 4.5. UNTAPERED that is 20 s of circling
		-- (90 / 4.5); a single rump slug is 5 points past MORTAL of a 50-point span, so
		-- `Wound.flightStuds` gives it 81 studs and about 18 s -- either way inside
		-- `BLEED_OUT_MAX_SECONDS`.
		FLIGHT = { head = 0, chest = 0, body = 120, legs = 420, rear = 90 },

		-- WHAT A HIT THERE MEANS, as data (task 116). The zone decides a CLASS and the class decides
		-- the reaction: `Brain` reads it on the hit tick to pick its state, `Body` reads it to pick
		-- the sound, and neither holds a list of zone names. A zone with no row here is `nonVital`,
		-- which is the safe answer: it flinches and runs on, exactly as every zone did before.
		--   vital     heart and lungs. A short dash or a stumble, then down (DJV's "Zeichnen").
		--   crippling the spine and hindquarters. The back end goes and it circles on the spot.
		--   nonVital  belly, haunch, a leg. It cries and runs on wounded.
		CLASS = {
			head = "vital",
			chest = "vital",
			rear = "crippling",
			body = "nonVital",
			legs = "nonVital",
		},
		-- THE CRIPPLED CRAWL, AND THE CIRCLE SHE CAN ACTUALLY SEE (task 116 fix round). Karen,
		-- 2026-10-03: "no cicrcle but I can see back legs disabled".
		--
		-- MEASURED on a real crippled boar, every Heartbeat for 12 s: it DID circle -- but at 3
		-- studs/s and 70 deg/s the radius is v / w = 3 / 1.222 = 2.45 studs, so the circle it drew
		-- was 4.9 studs ACROSS and the animal is 5.5 studs LONG. A path smaller than the animal is
		-- not a circle anybody can see: it is a boar pivoting on the spot, which is exactly what she
		-- reported. The lap took 5.0 s.
		--
		-- SO THE FIX IS A BIGGER CIRCLE, NOT A TIGHTER ONE, and that is the opposite of what the
		-- dispatch asked for -- said here because the measurement is the reason. 4.5 studs/s and
		-- 45 deg/s give a radius of 5.73, a circle 11.5 studs across (about two body lengths) and a
		-- lap of 8.0 s: the animal travels 36 studs per lap, so from a post at 20-40 studs it is
		-- plainly going round rather than standing still. The speed stays a crawl -- above
		-- `WANDER_SPEED` 4 only enough to make the walk clip read as walking rather than sliding.
		CRIPPLE_SPEED = 4.5,
		CRIPPLE_TURN_DEG = 45,
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

		-- A DEAD BOAR STAYS WHERE IT FELL (Karen, 2026-10-03: "when they died and lie on ground I can
		-- move them by walking it has to stay in same place without move"). A carcass is an unanchored
		-- physics body with CanCollide on, so a character walking into it shoves it -- MEASURED with the
		-- flag OFF as well as on: one impulse the size of a walking character (the boar's own 23.1 mass
		-- times 16 studs/s) moved it 1.826 studs. So it is ANCHORED once it has come to rest, which is
		-- the one thing that cannot be pushed at all.
		--
		-- IT IS ANCHORED WHEN IT HAS STOPPED, NOT AFTER A FIXED WAIT, because the two flag states stop
		-- at different times: with the flag off it has to ROLL past its tipping angle and fall over
		-- first, and with it on it only drops the SPAWN_CLEARANCE it was standing above. Anchoring on a
		-- timer would freeze one of them mid-topple.
		--
		-- The thresholds are MEASURED and are 30x apart, which is what makes "still" unambiguous: a
		-- resting carcass reads 0.000-0.003 on both, and one that is still toppling peaked at 28.6
		-- linear and 5.6 angular in the same session.
		CARCASS_STILL_LINEAR = 0.1, -- studs/s
		CARCASS_STILL_ANGULAR = 0.1, -- radians/s
		-- ...held for this long, so a carcass that is momentarily slow between two bounces is not
		-- mistaken for one that has stopped.
		CARCASS_STILL_SECONDS = 0.25,
		-- THE BACKSTOP, so a player cannot keep a carcass shoveable for ever by leaning on it. Four
		-- seconds is well past both settles (`boar_hit.spec` allows the topple three). It will NOT
		-- anchor something in mid-air: a body still falling faster than CARCASS_FALLING_Y keeps waiting,
		-- because a boar frozen above the ground is a worse bug than one that can be nudged.
		CARCASS_ANCHOR_BY_SECONDS = 4.0,
		CARCASS_FALLING_Y = 1.0, -- studs/s of downward speed that still counts as falling
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

-- THE SKINNED MODEL (task 115), behind `BOAR_MODEL`. It is a separate block and not a field above
-- because every threshold in it is DERIVED from the speeds above: written as literals they would
-- quietly stop matching the gaits the moment Karen turned one of her dials.
--
-- EVERY CLIP NUMBER HERE WAS MEASURED OFF THE CLIP, by `tools/boar_prep.py`, on 2026-10-03 at this
-- model's own scale (5.5 studs long). `groundStudsPerSecond` is how fast the ground slides under the
-- clip at playback rate 1: all ten clips are in place (the root bone's drift measured 0.0000), so the
-- animal's speed is carried entirely by its feet, and the speed of a PLANTED hoof is the clip's
-- ground speed. The rate that makes feet not slide is then `speed / that`, which is what
-- `Body.clipFor` computes. A zero means the clip has no gait at all, and no rate can give one.
--
-- WHICH ASSET ID EACH CLIP IS, this file does not know and must not: ids have one home
-- (`src/serverstorage/Assets`), and a mapping between two owners belongs in the composition root.
-- `Runtime:setModelSource` takes both lookups from the boot script; `ANIMATION_IDS` is filled per
-- RUNTIME, once, and is empty until then -- with it empty the boar is welded, visible and standing
-- still, which is exactly the state until the ten clips have been published out of Studio.
-- `seconds` IS THE PUBLISHED CLIP'S OWN LENGTH, read back out of Roblox on 2026-10-03 with
-- `AnimationClipProvider:GetAnimationClipAsync` and taking its last keyframe's `Time`. It is NOT the
-- frame count divided by the frame rate, which is what this table said until the ids existed and
-- which was one frame long on every single clip: N frames at 24 fps span N-1 intervals, so Idle is
-- 4.167 s and not 4.208. `groundStudsPerSecond` was never affected -- `tools/boar_prep.py` divides
-- by the INTERVALS it counted, not by the frame count -- and `BoarAssetsBoot` warns if this column
-- and the manifest's `clipSeconds` ever drift apart.
-- HOISTED so the band edge below is the derivation its comment claims and not the same literal
-- written twice (review round 1, note).
local WALK_MAX_RATE = 1.8

local BOAR_CLIPS = {
	idle = { clip = "Idle_1", seconds = 4.167, groundStudsPerSecond = 0, looped = true },
	walk = { clip = "Walk_F_IP", seconds = 1.0, groundStudsPerSecond = 2.852, looped = true },
	trot = { clip = "Trot_F_IP", seconds = 0.667, groundStudsPerSecond = 10.244, looped = true },
	run = { clip = "Run_F_IP", seconds = 0.5, groundStudsPerSecond = 17.21, looped = true },
	turnLeft = { clip = "Turn_L_IP", seconds = 0.667, groundStudsPerSecond = 1.855, looped = true },
	turnRight = { clip = "Turn_R_IP", seconds = 0.667, groundStudsPerSecond = 1.855, looped = true },
	deathLeft = { clip = "Death_L", seconds = 1.208, groundStudsPerSecond = 0, looped = false },
	deathRight = { clip = "Death_R", seconds = 1.208, groundStudsPerSecond = 0, looped = false },
	hitFront = { clip = "Hit_F", seconds = 0.833, groundStudsPerSecond = 0, looped = false },
	hitBack = { clip = "Hit_B", seconds = 0.833, groundStudsPerSecond = 0, looped = false },
	-- THE THREE THIS PROJECT AUTHORED, because the package has none of them (task 116 fix round).
	-- `tools/boar_prep.py`'s `SYNTH_CLIPS` builds each one by blending poses the package's own
	-- animator made -- nothing is invented -- and `tools/boar_prep_blender.py` measures them with
	-- the same hoof-contact rule as the other ten. Every number below is off that run:
	--
	--   Death_Paddle_L/R  97 keys, 4.000 s. Death_L/R's LAST frame with the four legs swinging
	--                     back toward Run_F_IP, decaying to nothing, so the clip ENDS on the pose
	--                     the carcass is then held at and nothing pops. MEASURED per hoof: the legs
	--                     on the up side travel 1.74-4.64 studs/s and the two against the ground
	--                     0.30-0.37 -- a leg under a lying animal cannot swing, which is right.
	--   Cripple_Drag      25 keys, 1.000 s, looped: Walk_F_IP with the hind legs pulled 85 % of
	--                     the way to the death pose. MEASURED per hoof: FRONT 2.866 and 2.863
	--                     studs/s (Walk_F_IP's own 2.853, so a real walk cycle) and HIND 0.826 and
	--                     0.931 (a third of it, dragging). That measurement IS Karen's "circles
	--                     with first legs on", in numbers.
	--
	-- `groundStudsPerSecond` is what the playback rate divides by, so it is the FRONT hooves' 2.864
	-- for the drag -- the legs that are actually carrying the animal -- and 0 for the paddles, which
	-- are not a gait and are always played at rate 1.
	--
	-- UNTIL THE DIRECTOR PUBLISHES THEM they have no id, `trackFor` returns nil, `play` leaves the
	-- animal on whatever it was playing, and every behaviour below is exactly what it was.
	deathPaddleLeft = { clip = "Death_Paddle_L", seconds = 4.0, groundStudsPerSecond = 0, looped = false },
	deathPaddleRight = { clip = "Death_Paddle_R", seconds = 4.0, groundStudsPerSecond = 0, looped = false },
	crippleDrag = { clip = "Cripple_Drag", seconds = 1.0, groundStudsPerSecond = 2.864, looped = true },
	-- THE CALM BOAR (task 117). Karen, 2026-10-03: "boar also can move alon and walk and lift head
	-- like smell ect". Six of the package's remaining 61 clips, MEASURED by `tools/boar_prep.py` with
	-- the same hoof-contact rule as the rest, and chosen by what the HEAD does (the numbers are in
	-- `SYNTH_CLIPS`' neighbour, `DEFAULT_CLIPS`, where the selection was made):
	--   smell       Idle_5, the ONLY clip whose nose rises above horizontal -- -18.9 to +11.5 deg,
	--               a 30.4 deg lift, head +0.112 m, hooves never moving. Idle_4 is its opposite
	--               (nose to -72 deg) and Idle_2/3/6 are 9-15 deg ground-level fidgets.
	--   grazeLoop   Eat_loop_1, head at 0.505 m and the nose at -70..-54 deg: steady grazing.
	--   grazeChew   Eat_loop_2, the same but pulling and chewing (head moves 0.098 m, not 0.001).
	--   grazeStart  EatDrink_start / EatDrink_end: the 1.08 s transition between standing height
	--   grazeEnd    and grazing height, so the head does not teleport into the grass.
	--   digWalk     Dig_walk_IP, head low AND hooves travelling 1.901 studs/s -- rooting along the
	--               ground, which is Karen's "move alon". It is rated like a gait for that reason.
	smell = { clip = "Idle_5", seconds = 4.167, groundStudsPerSecond = 0, looped = false },
	grazeLoop = { clip = "Eat_loop_1", seconds = 4.167, groundStudsPerSecond = 0, looped = true },
	grazeChew = { clip = "Eat_loop_2", seconds = 4.167, groundStudsPerSecond = 0, looped = true },
	grazeStart = { clip = "EatDrink_start", seconds = 1.083, groundStudsPerSecond = 0, looped = false },
	grazeEnd = { clip = "EatDrink_end", seconds = 1.083, groundStudsPerSecond = 0, looped = false },
	digWalk = { clip = "Dig_walk_IP", seconds = 1.5, groundStudsPerSecond = 1.901, looped = true },
}

-- THE SOUND OF A BOAR (task 116). Karen, 2026-10-03: *"I just need that once they walk you can hear
-- (as example hunter waiting and hear something comming and then boars are visible running, walking
-- ect)"*, and on which sounds: *"you decide what sounds"*.
--
-- IT IS ALL DATA, ids included, so a sound Karen does not like is one number in this table and not a
-- code change -- and a library id that is moderated away can be swapped the same way. The ids are
-- the Director's provisional ProSoundEffects picks; nothing here was uploaded.
--
-- SPATIAL FOR FREE. A `Sound` parented to a `BasePart` is positional, and the boar already has one
-- part that everything is welded to -- so `Body` creates them in the trunk, every client hears the
-- same animal from the right direction, and there is no new remote and no client-side mixer.
--   Sound       https://create.roblox.com/docs/reference/engine/classes/Sound
--   RollOffMode https://create.roblox.com/docs/reference/engine/enums/RollOffMode
-- `InverseTapered` is the mode Roblox recommends for world sounds; the docs publish no curve, so
-- `audibleStuds` is a number to pick and then LISTEN to, which is what the playtest is for.
Boar.CONFIG.SOUND = {
	ENABLED = true, -- rides `BOAR_MODEL` with everything else; this is the switch for sound alone
	FOLDER = "Sounds",
	ROLL_OFF = "InverseTapered",
	-- Inside this, a sound is at full volume; past its own `audibleStuds` it is gone.
	NEAR_STUDS = 12,
	PITCH_JITTER = 0.08, -- +-8%: a repeat must not sound like a loop
	-- FOOTSTEPS, CHOSEN BY GAIT and rated by speed, so a walking boar is quiet and a galloping one is
	-- not. Silent when standing: `MIN_SPEED` is below the walk band's own floor, and a standing boar
	-- is most of what a grazing one is doing.
	--
	-- EVERY ROW CARRIES ITS OWN `audibleStuds`, because `makeSound` reads it off the row and a shared
	-- one two levels up resolved to nil (a `RollOffMaxDistance` of nil is a hard error on the first
	-- boar that moves). It is also the better answer: a walking boar at 45 studs is a noise in the
	-- brush, a trotting one at 70 is "the last few seconds of approach" at 18 studs/s, and a
	-- galloping one at 90 is something coming -- which is exactly the warning Karen asked to hear.
	--
	-- `baseSpeed` IS THE CLIP'S OWN MEASURED GROUND SPEED, taken from `BOAR_CLIPS` and not copied:
	-- the footstep loop is rated by `speed / baseSpeed`, which is the same arithmetic that rates the
	-- animation, so the steps land under the hooves. Typing the three numbers again would let a
	-- re-measured clip drift away from its own sound, silently.
	STEPS = {
		MIN_SPEED = 0.6,
		-- "Goat Footsteps Only 1" -- a hoof on soil, and the nearest thing the library has to a
		-- walking pig. Karen, 2026-10-03: "sound you choose best practice you do".
		walk = { id = 9114623726, volume = 0.35, baseSpeed = BOAR_CLIPS.walk.groundStudsPerSecond, audibleStuds = 45 },
		trot = { id = 9114623726, volume = 0.5, baseSpeed = BOAR_CLIPS.trot.groundStudsPerSecond, audibleStuds = 70 },
		-- "Donkey Footsteps 1" -- heavier and faster, for a gallop.
		run = { id = 9114127078, volume = 0.7, baseSpeed = BOAR_CLIPS.run.groundStudsPerSecond, audibleStuds = 90 },
	},
	-- Calm grunts while it is idling or grazing. The interval is random inside the band so a sounder
	-- does not grunt in chorus.
	GRUNTS = {
		ids = { 9117357588, 9117352464, 9117344600 }, -- "Pig Grunts 2 / 3 / 6"
		volume = 0.45,
		audibleStuds = 70,
		MIN_SECONDS = 3,
		MAX_SECONDS = 8,
		MAX_SPEED = 6, -- only while calm: a bolting boar breathes instead
	},
	-- Breathing and snorts while it is running.
	BREATH = {
		ids = { 9113629992, 9113630137 }, -- "Bull Breaths 8 / 10"
		volume = 0.5,
		audibleStuds = 60,
		MIN_SECONDS = 1.5,
		MAX_SECONDS = 3.0,
		MIN_SPEED = 11, -- TROT_FROM: it is working
	},
	-- One-shots. `hit` is the bullet landing, `cry` the animal, and they play together on a non-vital
	-- or a crippling hit -- a vital hit gets the hit sound and then the death.
	HIT = { id = 9113519976, volume = 0.8, audibleStuds = 90 }, -- "Body Hit Wet 7"
	CRY = { ids = { 9117369876, 9117370072 }, volume = 0.9, audibleStuds = 110 }, -- "Pig Squeals 1 / 3"
	DEATH = { id = 9117361361, volume = 1.0, audibleStuds = 120 }, -- "Pigs Beast-Like Screams 8"
	LAST_BREATH = { id = 9113629992, volume = 0.6, audibleStuds = 50, delay = 1.0 },
	FALL = { id = 9113469903, volume = 0.7, audibleStuds = 80 }, -- "Body Fall Gooshy Mud 2"
	-- THE SNIFF, when the head comes up (task 117). It REUSES a ProSoundEffects id this project has
	-- already verified -- "Bull Breaths 10" -- played high and short, because nothing in this
	-- toolchain can search the audio library and inventing an id would be a number nobody has heard.
	-- It is one number in this table: the Director or Karen can swap it for a real pig snort without
	-- touching code, and nobody here can hear either.
	SNIFF = { id = 9113630137, volume = 0.55, audibleStuds = 55, pitch = 1.25 },
}

-- WHAT A BOAR DOES WHEN NOTHING IS WRONG (task 117). Karen, 2026-10-03: "boar also can move alon and
-- walk and lift head like smell ect", and the scene she described -- "imagine they on easy, then see
-- dog or person spook them they run". This is the ON EASY half only; being spooked is task 118.
--
-- IT IS A PICKER INSIDE THE EXISTING `IDLE`, NOT A NEW STATE. The Brain's IDLE already alternated
-- "stand still" and "wander at WANDER_SPEED" through one boolean; this replaces that boolean with a
-- weighted draw from the table below and publishes the answer as `intent.activity`, which `Body`
-- turns into a clip. No state is added, so task 118 has nothing to undo: it will add the ways OUT of
-- IDLE, and every one of them already overrides this (`activity` is published only while IDLE).
--
-- EVERY NUMBER IS DATA and every activity is reachable by name, so the weights, the durations and
-- which clip an activity plays are all tunable without touching code.
Boar.CONFIG.CALM = {
	-- THE FLAG, READ ONCE AT THIS BOUNDARY, exactly as `MODEL.ENABLED` reads it (CLAUDE.md, feature
	-- flags). It was a literal `true` for one round, which shipped a feel-critical movement change --
	-- an idle boar's speed setpoint drawn from this table instead of `WANDER_SPEED` -- in the FLAG
	-- OFF path, i.e. the live game (review round 2, finding 2). Off, `Brain:_stepCalm` and
	-- `Body.activityRow` both fall back and an idle boar stands and wanders exactly as before.
	ENABLED = Flags.isOn("BOAR_MODEL"),
	-- A boar that has just spawned starts somewhere INSIDE its first activity, not at the beginning
	-- of one, so a sounder of five is not five animals doing the same thing on the same frame. A row
	-- whose band is a single value is EXEMPT: `smell` is exactly one clip length so the 30.4 deg lift
	-- completes, and shortening it would cut the lift off (review round 2, note).
	FIRST_PHASE_SECONDS = 6,
	FIRST_PHASE_FLOOR = 0.5, -- however the roll falls, a first activity lasts at least this long
	-- `speed` is the Brain's setpoint while the activity runs; `clip` is what `Body` draws, and nil
	-- means "let the gait bands decide", which is how `walk` gets the ordinary walk cycle. `enter`
	-- and `exit` are one-shots played before and after, so a head does not teleport to the ground.
	ACTIVITIES = {
		-- Standing, breathing, looking at nothing: the resting state and the one it returns to.
		{ name = "stand", clip = "idle", speed = 0, weight = 3, minSeconds = 3, maxSeconds = 7 },
		-- Head down in the grass, which is what a wild boar does most of the day.
		{
			name = "graze",
			clip = "grazeLoop",
			enter = "grazeStart",
			exit = "grazeEnd",
			speed = 0,
			weight = 4,
			minSeconds = 6,
			maxSeconds = 14,
		},
		-- Rooting ALONG the ground: the dig clip carries the animal at its own 1.901 studs/s, so the
		-- speed here is the clip's, and the feet do not slide.
		{ name = "root", clip = "digWalk", speed = 1.901, weight = 2, minSeconds = 4, maxSeconds = 9 },
		-- THE HEAD COMES UP. One clip length exactly, so the lift completes and is not cut off in
		-- the middle; `SOUND.SNIFF` plays with it.
		{
			name = "smell",
			clip = "smell",
			speed = 0,
			weight = 2,
			minSeconds = 4.167,
			maxSeconds = 4.167,
			sound = "sniff",
		},
		-- A few steps somewhere else. No clip of its own: at `WANDER_SPEED` the gait bands answer
		-- "walk", which is the clip task 115 already rated so the feet do not slide.
		{ name = "walk", clip = nil, speed = 4, weight = 3, minSeconds = 3, maxSeconds = 8 },
	},
}

Boar.CONFIG.MODEL = {
	-- THE FLAG, READ ONCE AT THIS BOUNDARY and passed inward as `config` -- the only permitted shape
	-- (CLAUDE.md, feature flags). Every function below takes the value as a parameter, so both
	-- branches stay reachable while the flag sits at one of them.
	ENABLED = Flags.isOn("BOAR_MODEL"),
	NAME = "Visual", -- the one child `Body.attachVisual` adds, and the only one
	CLIPS = BOAR_CLIPS,
	ANIMATION_IDS = {}, -- filled per runtime by `setModelSource`; see above
	-- The grey box is not deleted, it is made invisible -- and only once the model is really there.
	-- `CanQuery` and `CanCollide` are untouched, so every shot lands exactly where it landed before.
	HIDE_BOX = true,
	-- THE THREE GAITS. Karen's dials are 4 (grazing), 18 (pushed) and 38 (bolting), and the three
	-- anchors are hers: walk on 4, trot on 18, run on 38. Splitting at the CLIPS' own natural speeds
	-- instead (2.85, 10.24, 17.21) would put 18 on the RUN clip, which is not what being pushed looks
	-- like.
	--
	-- WHERE WALK ENDS IS NOT A MIDPOINT, AND THAT WAS MEASURED IN A LIVE SESSION (2026-10-03). It sat
	-- at (4 + 18) / 2 = 11, which asks the walk clip -- whose hooves travel 2.852 studs/s -- to play
	-- at up to 3.86. `MAX_RATE` clamped it to 2.50 and the feet slid by nearly 40 %. A healthy boar
	-- crosses that band in the 0.1 s `ACCEL` takes and nobody sees it; a WOUNDED one does not, because
	-- `Wound.speedScale` puts it at whatever fraction of 18 its injury says -- measured at 8.99 and
	-- 9.84 studs/s, held for seconds, walking with clamped feet. So the walk band ends where the walk
	-- clip reaches `WALK_MAX_RATE`, and from there the TROT clip -- natural speed 10.244 -- takes over
	-- at a rate near 1.0, which is what a boar at 9 studs/s should look like anyway.
	WALK_FROM = 0.5, -- anything moving at all is walking, not standing
	-- A brisk but believable walk: 1.8x is a 0.58 s stride. Past that the animal is trotting.
	WALK_MAX_RATE = WALK_MAX_RATE,
	TROT_FROM = BOAR_CLIPS.walk.groundStudsPerSecond * WALK_MAX_RATE,
	RUN_FROM = (Boar.CONFIG.TROT_SPEED + Boar.CONFIG.SPRINT_SPEED) / 2,
	-- A TURN IN PLACE, and it is reachable only below WALK_FROM on purpose: Turn_L/R are pivots
	-- whose hooves travel 1.855 studs/s, so at any real speed they skate. 60 deg/s is a quarter of
	-- the Brain's own TURN_RATE ceiling (4 rad/s = 229 deg/s), which is a deliberate turn rather
	-- than the wander's jitter.
	TURN_FROM_DEG = 60,
	-- ...AND IT LEAVES AT A LOWER NUMBER THAN IT ENTERS (Karen, 2026-10-03: "head shaking sometimes
	-- vierd"). With one threshold the turn clip chatters: MEASURED over three 7-second windows on
	-- standing boars, the per-frame yaw swung -120..+173 deg/s, crossed 60 in both directions
	-- constantly, and produced 24 clip changes in 7 seconds on one animal -- several of them 0.03 s
	-- long, which is a fifth of FADE_SECONDS. 35 is a little over half of 60, so a turn has to decay
	-- properly before the animal is called still again.
	TURN_EXIT_DEG = 35,
	-- THE YAW IS SMOOTHED BEFORE ANYTHING LOOKS AT IT, and that is the other half of the same fault.
	-- One frame's facing delta divided by dt is not a turn rate, it is noise on a physics body under
	-- an AlignOrientation -- hence the +-170 deg/s on an animal standing still. 0.2 s is long enough
	-- to average that away and short enough that a real turn (the Brain slews at up to 229 deg/s and
	-- holds it) reaches the threshold inside a fifth of a second.
	YAW_SMOOTH_SECONDS = 0.2,
	-- NO CLIP MAY BE REPLACED BEFORE ITS OWN CROSSFADE HAS FINISHED. This is the structural half: a
	-- decision that changes faster than the transition it starts leaves THREE tracks playing at
	-- partial weight, all writing the same bones, and the head -- the end of the longest bone chain
	-- -- amplifies their disagreement most (measured: maxConcurrentTracks 3, and the head moving
	-- 8.0 studs/s on a boar whose body speed was 0.0). A hair over FADE_SECONDS, so two is the most
	-- that can ever overlap. A DEATH AND A FLINCH IGNORE IT: those must be instant, and they are the
	-- two the player is waiting to see.
	MIN_CLIP_SECONDS = 0.18,
	-- WHICH WAY IT FALLS, derived from the roll `Body.collapse` applies rather than chosen: a
	-- positive roll about the trunk's own Z tips its UpVector toward -X, which is the animal's LEFT.
	-- Flip `COLLAPSE_ROLL_DEG`'s sign and the clip follows it, which a literal would not.
	DEATH_TO_THE_LEFT = Boar.CONFIG.WOUND.COLLAPSE_ROLL_DEG > 0,
	-- The flinch lasts exactly as long as the flinch clip, so the gait resumes on the frame the
	-- animation ends instead of a tenth of a second either side of it.
	HIT_SECONDS = BOAR_CLIPS.hitFront.seconds,
	-- ...UNLESS THE ANIMAL IS RUNNING (task 116 fix round). Karen, 2026-10-03: "body shot is a bit
	-- odd now feels late hit and odd". The flinch clips are IN PLACE and a body hit bolts the boar to
	-- `SPRINT_SPEED * BOLT_KICK` on the same tick, so the full 0.833 s window slid the animal some 30
	-- studs with its legs still before the run clip was allowed to start. 0.25 s is the jerk -- long
	-- enough to read as being hit, short enough that the running begins while the player is still
	-- watching the impact. `HIT_FULL_BELOW` is `WALK_FROM`: an animal that is not going anywhere has
	-- nothing to fight with and gets the whole clip.
	HIT_MOVING_SECONDS = 0.25,
	HIT_FULL_BELOW = 0.5,
	FADE_SECONDS = 0.15, -- a gait change is a blend, not a cut
	-- ...and a HIT or a DEATH is a cut, not a blend. 0.15 s of crossfade on the way in is 0.15 s of
	-- the animal not yet reacting, which is the part of "feels late" that was not asset loading.
	HIT_FADE_SECONDS = 0.03,
	-- THE SILENT PRE-ROLL, in seconds (task 116 fix round). Every clip at weight 0 and every sound at
	-- volume 0, once, when the coat goes on, so the CLIENT has fetched them before the first shot
	-- needs one -- measured: a cry and a flinch that arrived 364 ms after the bullet because nothing
	-- had ever asked for them. Long enough for a fetch to be issued and for `stepVisual` to have run
	-- a dozen times; short enough to be over before any boar is in range of a gun.
	WARM_SECONDS = 0.5,
	RATE_EPSILON = 0.02, -- do not re-adjust a track's speed for a 2 % change: it is a property write
	HOLD_EPSILON = 0.03, -- how close to the end a death clip is frozen at, so the carcass stays down
	-- THE TWITCH AFTER IT GOES DOWN, and it is NOT what was asked for -- see the research note.
	-- `Bone.Transform` is the Animator's output and a script's write to it does not survive a single
	-- frame (measured: 0 of 122 samples, server and client), so isolated paddling legs cannot be
	-- drawn over the held death pose. What CAN be driven is the death clip's own `TimePosition`, so
	-- the body twitches back and forth over the last of its fall and settles.
	--
	-- THESE ARE `MODEL` NUMBERS, NOT `WOUND` ONES: they describe a drawn thing, they are read only
	-- behind `BOAR_MODEL`, and the code that reads them (`Body.paddleOffset`, `Body.stepVisual`)
	-- takes them off `config.MODEL`. They sat in `WOUND` for one build and nothing in the suite
	-- noticed, because no spec can load an animation asset and the freeze branch therefore never
	-- ran -- it would have been a nil comparison in a live session on the first boar that died.
	PADDLE_SECONDS = 2.5,
	PADDLE_HZ = 3.5, -- twitches per second at the start
	PADDLE_SPAN = 0.09, -- seconds of clip scrubbed at full amplitude, decaying to nothing
	MIN_RATE = 0.4,
	-- THE CEILING IS ABOVE EVERYTHING THE GAME CAN ASK FOR, so it never shapes how an animal moves --
	-- it only refuses the absurd rate a mis-measured clip would produce. The worst real ask is the
	-- TROT clip at the top of its band (`RUN_FROM` 28 / 10.244 = 2.73); the run clip at SPRINT_SPEED
	-- needs 2.21 and the walk clip is bounded by `WALK_MAX_RATE`. 2.8 clears all three, and
	-- `boar_model.spec` sweeps every speed a boar can reach and fails if any of them clamps.
	MAX_RATE = 2.8,
	-- How often the runtime asks for a template it has not got yet. `Loader.preload` is bounded at
	-- 15 s and may land after the first boar exists, so asking once at boot would leave that boar a
	-- grey box for its whole life; asking every frame would count a miss sixty times a second in
	-- `Loader.stats`.
	ASK_EVERY_SECONDS = 1,
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
	-- A MODEL BLOCK OF ITS OWN, because `table.clone` is SHALLOW and `ANIMATION_IDS` is filled at
	-- run time: without this, one runtime's ids would be written into `Boar.CONFIG.MODEL` and read by
	-- every other runtime and every spec in the same session. This repository has paid for a shallow
	-- clone twice already (Drive, Task 23a note (b); Flags' own deepFreeze).
	self._config.MODEL = table.clone(self._config.MODEL)
	self._config.MODEL.ANIMATION_IDS = table.clone(self._config.MODEL.ANIMATION_IDS)
	-- The skinned model's two lookups, both nil until a boot script wires them: with no template the
	-- boar is the grey box, which is what every spec before task 115 asserts.
	-- `_heldTemplate` AND NOT `_modelTemplate`: the method below is `Runtime:_modelTemplate`, which
	-- lives on the metatable, so a nil FIELD of that name resolves to the METHOD and the next line to
	-- touch it reads "attempt to index function with 'Parent'". Measured the hard way: it took out
	-- four cases of boar_model.spec on the first gate run of this task.
	self._heldTemplate = nil :: Instance?
	self._templateFor = nil :: (() -> Instance?)?
	self._animationIdFor = nil :: ((string) -> number?)?
	-- FALSE MEANS "USE THE MODULE'S", and once `Runtime:setModelSource` has been called it is true
	-- for ever. Without this flag, `self._templateFor or moduleTemplateFor` would make "this runtime
	-- has NO template" inexpressible -- a spec asking for the no-model branch would silently be
	-- handed the live server's real boar, and the one case the flag's promise rests on would pass for
	-- the wrong reason.
	self._modelSourceSet = false
	self._askedModelAt = -math.huge
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

	-- THE GUARD FOR A WHOLE CLASS OF BUG, and it is here because this task shipped one of them.
	-- `Runtime.__index = Runtime`, so a field whose name is also a METHOD name is invisible while it
	-- is nil: the lookup falls through to the metatable and hands back the function. `_modelTemplate`
	-- was both, and the next line to read it said "attempt to index function with 'Parent'" -- four
	-- cases of boar_model.spec, on the first gate run of task 115. A nil field is the normal state of
	-- half the table above, so this is a trap every future field walks past.
	local clashes = Boar.fieldMethodClashes(self, Runtime)
	assert(
		#clashes == 0,
		string.format(
			"Boar.newRuntime: %s is both a field and a method of Runtime. While the field is nil the"
				.. " method answers in its place, which is a silent wrong value and not an error."
				.. " Rename the field (src/server/Boar/init.luau).",
			table.concat(clashes, ", ")
		)
	)
	return self
end

-- Every name that is both an own field of `instance` and a key of `methods`. Pure, sorted, and its
-- own function so the guard above is mutation-checkable: a spec can hand it a clash it built itself
-- (tests/server/boar_model.spec.luau), which no spec can do to a real Runtime without first
-- introducing the defect.
function Boar.fieldMethodClashes(instance: { [string]: any }, methods: { [string]: any }): { string }
	local out = {}
	for name in pairs(instance) do
		-- `__index` is Runtime pointing at itself and is not a method anybody calls; every other key
		-- of `methods` is.
		if name ~= "__index" and methods[name] ~= nil then
			table.insert(out, name)
		end
	end
	table.sort(out)
	return out
end

function Runtime:folder(): Folder
	return self._folder
end

-- THE SKINNED MODEL'S TWO LOOKUPS, wired by a boot script and by nothing else (task 115).
--   `templateFor()`            -> the cached template Instance, or nil. MUST NOT YIELD: it is
--                                 called from inside the step loop. `Assets.Loader.template` is
--                                 exactly this shape and is documented never to yield.
--   `animationIdFor(clipName)` -> that clip's animation asset id, or nil.
-- Both are injected rather than required, so neither owner requires the other (the property
-- docs/design/shotgun.md section 6.3 established and `WeaponBoot` already follows), and so a spec
-- can drive both the "no model" and the "model" branch with no network at all.
--
-- THERE ARE TWO SETTERS, AND THE REASON IS A MEASURED HAZARD, NOT TIDINESS.
--   * `Boar.setModelSource` is MODULE level, because `BoarAssetsBoot` has no runtime to set it on:
--     `MatchBoot` creates the runtime, and two Scripts in ServerScriptService have no defined order
--     and cannot share a Luau value. This is the same shape `Weapon.Hardware.setTemplateProvider`
--     already has here, set by `WeaponBoot` and reviewed as such.
--   * `Runtime:setModelSource` is PER RUNTIME and wins over it, and that is what a spec uses. A spec
--     that borrowed the module-level one would be lending its fake to the live server for as long as
--     its case ran -- and the live runtime asks for a template once a SECOND, so it could cache that
--     fake and hand every player a fake boar for the rest of the session. That is Task 76's defect
--     exactly ("a spec that borrows this seam and puts back NIL"), and a runtime-local override
--     makes it unreachable rather than unlikely.
-- Either way the ids are read ONCE, when the template first arrives, into THIS runtime's own
-- `CONFIG.MODEL.ANIMATION_IDS`. An id that appears later is not picked up, which is deliberate: a
-- manifest is frozen data edited in git, so a row that was not there at boot was not there at all.
local moduleTemplateFor: (() -> Instance?)? = nil
local moduleAnimationIdFor: ((string) -> number?)? = nil

-- Returns the pair it replaced, so a caller that must put it back can.
function Boar.setModelSource(
	templateFor: (() -> Instance?)?,
	animationIdFor: ((string) -> number?)?
): ((() -> Instance?)?, ((string) -> number?)?)
	local previousTemplate, previousId = moduleTemplateFor, moduleAnimationIdFor
	moduleTemplateFor = templateFor
	moduleAnimationIdFor = animationIdFor
	return previousTemplate, previousId
end

function Runtime:setModelSource(templateFor: (() -> Instance?)?, animationIdFor: ((string) -> number?)?)
	self._templateFor = templateFor
	self._animationIdFor = animationIdFor
	self._modelSourceSet = true -- from here on this runtime ignores the module's, nil included
	self._heldTemplate = nil
	self._askedModelAt = -math.huge
end

-- The template, or nil, asking at most once every ASK_EVERY_SECONDS until it has one.
function Runtime:_modelTemplate(now: number): Instance?
	local held = self._heldTemplate
	if held ~= nil and held.Parent ~= nil then
		return held
	end
	local ask = if self._modelSourceSet then self._templateFor else moduleTemplateFor
	if ask == nil then
		return nil
	end
	if now - self._askedModelAt < self._config.MODEL.ASK_EVERY_SECONDS then
		return nil
	end
	self._askedModelAt = now
	local template = ask()
	if template == nil then
		return nil
	end
	self._heldTemplate = template
	local ids = self._config.MODEL.ANIMATION_IDS
	local lookup = if self._modelSourceSet then self._animationIdFor else moduleAnimationIdFor
	if lookup then
		for name in pairs(self._config.MODEL.CLIPS) do
			local id = lookup(name)
			if type(id) == "number" and id > 0 then
				ids[name] = id
			end
		end
	end
	return template
end

function Runtime:stats()
	local out = table.clone(self._stats)
	out.zoneHits = table.clone(self._stats.zoneHits) -- table.clone is shallow; this is a counter, not state
	return out
end

-- A copy of one boar's ANIMATION state, or nil. There is no setter and nothing in the game reads it:
-- it exists so a spec can count what `Boar.Body` did to the Animator, exactly as `woundOf` below
-- exists so a spec can read a wound. `rateWrites` is every `AdjustSpeed` Body has issued for this
-- boar, which is the one number review round 1's finding is about -- a frozen death must stop
-- costing writes, and "no more writes" is not observable from `AnimationTrack.Speed` because the old
-- fault wrote 1 and 0 inside the same frame.
function Runtime:animationOf(id: string)
	for _, entry in ipairs(self._boars) do
		if entry.id == id then
			-- `tracks` is HOW MANY CLIPS THIS BOAR HAS ACTUALLY LOADED, which is the one observable
			-- the silent pre-roll leaves behind (task 116 round 2, note): `warmAssets` builds one per
			-- entry in `MODEL.CLIPS`, where a lazily-dressed boar would hold only the two or three it
			-- has played. Counted here because `Body`'s handle is private and stays private.
			local tracks = 0
			for _ in pairs(entry.body.tracks) do
				tracks += 1
			end
			return {
				clip = entry.body.clip,
				heldClip = entry.body.heldClip,
				rateWrites = entry.body.rateWrites,
				collapsed = entry.body.collapsed,
				tracks = tracks,
			}
		end
	end
	return nil
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
			-- THE CLASS TRAVELS WITH THE EVENT (task 116), worked out by the pure `Wound.hitClass`
			-- here rather than in the Brain: the Brain is told what the hit MEANS, never which
			-- zones exist, exactly as it is told a severity and never a damage number.
			table.insert(entry.hitEvents, {
				severity = severity,
				zone = record.zone,
				class = Wound.hitClass(record.zone, wound),
				from = from,
			})

			-- THE FLINCH (task 115), from the SAME `from` the Brain bolts away from, so the clip and
			-- the decision can never disagree about where the shot came from. Behind means behind:
			-- the shot's direction of arrival against the animal's own facing. With no hint at all
			-- the answer is the front clip, which is the one a player is looking at.
			if self._config.MODEL.ENABLED then
				local fromBehind = false
				if typeof(from) == "Vector3" then
					local toShooter = from - Body.position(entry.body)
					local flat = Vector3.new(toShooter.X, 0, toShooter.Z)
					local facing = entry.body.part.CFrame.LookVector
					if flat.Magnitude > 1e-6 then
						fromBehind = flat.Unit:Dot(Vector3.new(facing.X, 0, facing.Z)) < 0
					end
				end
				Body.setHit(entry.body, self._config.MODEL.HIT_SECONDS, fromBehind)

				-- THE SOUND OF THE SHOT LANDING, and the animal's answer to it (task 116). The wet
				-- hit plays wherever the pellet went; the CRY is the animal, so it plays for a
				-- non-vital or a crippling hit and not for one that kills outright -- a boar shot
				-- through the heart does not squeal, it goes down and the death sound covers it.
				local sound = self._config.SOUND
				Body.playOneShot(entry.body, "hit", sound.HIT, self._config, self._rng)
				local class = Wound.hitClass(record.zone, wound)
				if class ~= "vital" and severity ~= "lethal" then
					Body.playOneShot(entry.body, "cry", sound.CRY, self._config, self._rng)
				end
			end

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
		-- The calm activity drawn last frame, so a sound fires on the EDGE and not every frame
		-- (task 117). nil until the first step, which is exactly when the first activity starts.
		lastActivity = nil :: string?,
		waypoints = nil,
		pathFailed = false,
		forceRepath = false, -- set by the world's Path.Blocked listener
		wound = Wound.new(), -- the ONE wound state, written only by takeHit and step
		hitEvents = {}, -- hits since the last step; handed to the Brain and cleared
		lastPosition = at,
		bornAt = os.clock(),
		lastPathAt = 0, -- when this boar last asked for a route; the forced-repath cooldown reads it
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
	entry.lastPathAt = os.clock()
	self._stats.pathRequests += 1
	local from = Body.position(entry.body)
	-- ...AHEAD OF THE BODY, never from inside it (see PATH_START_AHEAD). The boar is already going
	-- this way, and the first waypoint it follows is ahead of it in any case.
	local facing = entry.body.part.CFrame.LookVector
	local ahead = Vector3.new(facing.X, 0, facing.Z)
	if ahead.Magnitude > 1e-6 then
		from += ahead.Unit * self._config.PATH_START_AHEAD
	end
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
			self._stats.pathBlocked += 1
			-- AT MOST ONE FORCED REPATH PER REPATH_INTERVAL, measured 2026-09-26 (Task 60): a
			-- sounder's leader asked for 29 routes in 3 seconds against the design's budget of 12,
			-- because its own herd-mates stand on its route and Path.Blocked fires again every time
			-- one of them moves. A blockage found INSIDE that window buys nothing -- the Brain's own
			-- repath is at most REPATH_INTERVAL away and will see the same obstruction -- so this
			-- only removes churn. It applies to a lone boar too, where it is the same improvement.
			if os.clock() - (entry.lastPathAt or 0) >= self._config.REPATH_INTERVAL then
				entry.forceRepath = true
			end
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

	-- THE SKINNED MODEL, once per step and not once per boar: the template is one Instance every
	-- boar clones from, and asking for it per boar would multiply both the lookup and the miss
	-- counter by however many are alive.
	local visualTemplate: Instance? = nil
	if config.MODEL.ENABLED then
		visualTemplate = self:_modelTemplate(os.clock())
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

		-- THE COAT GOES ON BEFORE THE ANIMAL CAN DIE IN THIS TICK, and that ordering is the fix for a
		-- narrow but real race. `Body.collapse` decides whether to ROLL the box by asking whether
		-- anything is drawn on it -- the death clip lays the animal down itself, so rolling as well
		-- buries it (see that function). Attaching after the collapse meant a boar that died on the
		-- very tick its coat arrived got both. It is attached late by design -- `Loader.preload` is
		-- bounded at 15 s and the first boar can exist before it lands -- so a boar born grey puts
		-- its coat on as soon as the asset arrives, the same "late is not lost" rule the loader
		-- itself follows. With the flag off neither line runs and nothing differs from before task 115.
		if config.MODEL.ENABLED and visualTemplate ~= nil and entry.body.visual == nil then
			Body.attachVisual(entry.body, visualTemplate, config)
		end

		if intent.downed then
			-- Exactly once per boar: the Brain reports `downed` on the tick it enters DOWN and never
			-- again, so the kill cannot be published twice.
			self._stats.downed += 1
			Body.collapse(entry.body, config.WOUND)
			-- IT DIES OUT LOUD, AND THEN IT STOPS MAKING NOISE (task 116). The scream and the body
			-- landing play together -- a boar goes down and hits the ground in one movement -- and
			-- every looping sound is cut, because a carcass has no footsteps.
			if config.MODEL.ENABLED then
				Body.playDeath(entry.body, config, self._rng)
			end
			self._downedSignal:Fire(
				Wound.killRecord(entry.wound, entry.id, position, os.clock() - entry.bornAt, config.WOUND)
			)
		end

		Body.stepFlash(entry.body, dt, config.WOUND)
		-- BOTH FLAG STATES, because the push it closes is not the model's: a carcass is an
		-- unanchored physics body and the grey box has been shoveable since Task 28 (measured
		-- 2026-10-03: 1.826 studs from one walking-speed impulse, with the flag OFF). It does
		-- nothing until the body has stopped, and nothing at all once it has anchored.
		Body.stepCarcass(entry.body, dt, config.WOUND)

		-- The SPEED it is given is the Brain's own `targetVelocity`, not the body's measured one: the
		-- setpoint is what the animal is TRYING to do, so a boar shoved into a cover block keeps
		-- running on the spot instead of flicking to idle for the frames the physics holds it still.
		if config.MODEL.ENABLED then
			local wantSpeed = Vector3.new(intent.targetVelocity.X, 0, intent.targetVelocity.Z).Magnitude
			Body.stepVisual(entry.body, dt, {
				speed = wantSpeed,
				facing = facing,
				-- THE ONE PIECE OF STATE THE DRAWING NEEDS THAT SPEED CANNOT CARRY (task 116 fix
				-- round): a crippled boar crawls at `CRIPPLE_SPEED`, which is a walking speed, so
				-- without this it would walk normally. It travels as an intent like everything else.
				crippled = intent.state == "CRIPPLED",
				-- WHAT A CALM BOAR IS DOING (task 117). Published by the Brain only while IDLE, so
				-- every other state hands `Body` the nil it handed before.
				activity = intent.activity,
			}, config)
			-- The same speed drives the sound, so the footsteps keep time with the legs rather than
			-- with the body's measured velocity, which lags the setpoint by the ACCEL ramp.
			Body.stepSound(entry.body, dt, wantSpeed, config, self._rng)
			-- THE SNIFF, ONCE PER HEAD-LIFT (task 117). The activity carries the sound's name, so
			-- which sound an activity makes is data like everything else, and `_lastActivity` is the
			-- edge detector: it fires when the activity BECOMES `smell`, not every frame it is.
			if intent.activity ~= entry.lastActivity then
				entry.lastActivity = intent.activity
				local row = Body.activityRow(intent.activity, config)
				if row and row.sound and config.SOUND[string.upper(row.sound)] then
					Body.playOneShot(entry.body, row.sound, config.SOUND[string.upper(row.sound)], config, self._rng)
				end
			end
		end

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
