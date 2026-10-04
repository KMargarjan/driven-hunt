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
Boar.voicePitch = Body.voicePitch
Boar.voiceIds = Body.voiceIds
Boar.farScale = Body.farScale
Boar.cutVolume = Body.cutVolume

-- WHOSE HOOVES A SOUNDER PLAYS (task 120). Karen, 2026-10-04: "several walking ... could be anoying
-- and shit sound / so we need realistic". Five animals running together are one sound with one
-- position to anybody listening, so a sounder has ONE emitter: its leader. Pure, because the two
-- states have to be reachable by parameter -- a spec cannot make six Brains run abreast on command.
--
-- A herd with no leader yet (the tick after one dies) silences nobody: a missing sound is a worse
-- fault than a doubled one, and the next tick picks a leader.
function Boar.isStepEmitter(leaderId: string?, memberId: string, config): boolean
	local crowd = config.SOUND.CROWD
	if crowd == nil or crowd.ENABLED ~= true or crowd.ONE_STEP_EMITTER ~= true then
		return true
	end
	return leaderId == nil or leaderId == memberId
end

-- HOW MANY SQUEALS ARE STILL SOUNDING at `now`, out of a list of the moments each one stops being
-- counted (task 120). Pure, so the cap that keeps a shot-at sounder from stacking five squeals can
-- be driven by a spec with no sound in the world.
function Boar.squealsSounding(expiries: { number }, now: number): number
	local sounding = 0
	for _, expiry in ipairs(expiries) do
		if expiry > now then
			sounding += 1
		end
	end
	return sounding
end
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
-- ...and task 119's two: which row an animal's kind is, and every box that kind's body is made of.
-- Pure, for the same reason as every export above it -- a spec can measure a cub with no cub in the
-- world, and the one that matters is that a cub's hit zones are a cub's size.
Boar.kindRow = Body.kindRow
Boar.kindGeometry = Body.kindGeometry
-- ...and the one review round 2 added: every gait edge and both rate rails for one animal, so "a cub
-- is never asked for a rate its own ceiling refuses" is a sweep with no boar in the world.
Boar.gaitBands = Body.gaitBands
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
		-- THE HEAD IS ON THE DRAWN HEAD (task 119), and until this task it was not: it was a box
		-- hanging in the air 1.15 studs in FRONT of the snout, which is where the grey box's "head"
		-- was when no animal was drawn on it. A shot at the animal's face landed on the trunk and
		-- was charged to `body`.
		--
		-- MEASURED OFF THE LOADED MODEL, 2026-10-04, in a Play session, reading the rig's own bones
		-- out of `ServerStorage.AssetCache` (mesh object space, then +0.1286 on Y to put it in the
		-- trunk's frame -- the offset `Body.visualOffset` applies to stand the feet on the box):
		--     nose  z -2.388, y 0.666      head  z -1.279, y 0.912
		--     eye   z -1.779, y 1.087      Neck  z -0.866, y 0.872
		--     ears  z -1.208, y 1.570      the mesh's own front face z -2.750
		-- So the drawn skull runs z -2.75 to about -1.10 and y 0.35 to 1.65, and these two boxes are
		-- that, with the same PROTRUSION rules task 116 wrote for the rump:
		--   -Z front  PROUD by 0.06 (-2.81 against the trunk's -2.75): the face is the one angle a
		--             head shot is actually taken from, and nothing else of the animal is there.
		--   +Y top    PROUD by 0.15 (+1.65 against +1.50): the top of the skull is the head.
		--   +-X       NOT proud, deliberately, and it is the one thing this box cannot fix: the
		--             drawn head is 1.1 studs wide and the trunk is 2.0, so a ray from the FLANK
		--             meets the trunk before it meets the head and is charged to `body`. That was
		--             already true -- the old box was narrower than the trunk too -- and the only
		--             fix is a narrower trunk at the front, which is a change to the animal's
		--             collision shape that nobody asked for. Front, above and ahead of the shoulder
		--             are head; a pure flank is body.
		--   +Z rear   an interior boundary at -1.45, where `chest` now begins.
		head = {
			part = "ZoneHead",
			size = Vector3.new(1.2, 1.3, 1.36),
			offset = Vector3.new(0, 1.0, -2.13), -- spans y 0.35..1.65, z -2.81..-1.45
			tint = Color3.fromRGB(206, 120, 120),
		},
		-- ...AND THE CHEST MOVED BACK ONTO THE SHOULDER, because it had to: it was at z -2.45..-0.75,
		-- which on the drawn animal is the NECK AND THE BACK OF THE SKULL, and the head cannot sit
		-- where it belongs while another zone part is already there (two boxes at one ray distance is
		-- the coin toss task 116's review removed). It keeps its box and its damage exactly; only the
		-- Z moves, by one stud, onto the shoulder its own comment has always named: the front legs
		-- attach at z -0.53 to -0.70 (`hip_1_f`, `thigh_f`), so heart and lungs are -1.45 to +0.25.
		chest = {
			part = "ZoneChest",
			size = Vector3.new(2.12, 2.01, 1.7),
			offset = Vector3.new(0, 0.555, -0.6), -- heart/lungs behind the shoulder: z -1.45..+0.25
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
		-- SINGLE FILE OR A LOOSE GROUP, DRAWN ONCE PER SOUNDER (task 118). Karen: "they
		-- usually do one line each after another or mixed like in real life" -- so half and
		-- half. Behind `SENSE.ENABLED`: with it off every sounder is the wedge and the probe
		-- latch below is the only column, which is exactly today. Karen's dial.
		COLUMN_CHANCE = 0.5,
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
		-- WHO IS IN A SOUNDER (task 119, behind `BOAR_MODEL`). A sounder is a sow with her young;
		-- a lone animal is a male. That is the agreed makeup (Director, 2026-10-04) and it is also
		-- what a real sounder is -- the boars that travel alone are the mature males.
		--
		-- THE OCCASIONAL YOUNG MALE is the one draw here: a yearling still running with its mother.
		-- It is a MALE-sized animal in a group of cubs, so it is also the thing that makes "aim at
		-- the big one" a decision rather than a reflex. Karen's dial.
		MAKEUP = {
			SOW = "female",
			YOUNG = "cub",
			YOUNG_MALE = "male",
			YOUNG_MALE_CHANCE = 0.25,
			LONE = "male",
		},
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
	--
	-- KAREN, 2026-10-04: "when we shoot and hit, sound has to be lover and softer", and "when I hit
	-- but it doesn't die imediatly after it falls I can hear same hit sound shoudlnt be like that".
	--
	-- IT IS NOT A REPLAY, AND THAT WAS MEASURED (task 120). Every one-shot's `Played` event was
	-- counted through a real wounding shot and the bleed-out that followed it:
	--   hit@1.18  cry@1.18  ... (25 s of breaths) ... death@26.16  fall@26.16  lastBreath@27.16
	--   counts: hit=1 cry=1 death=1 fall=1 lastBreath=1
	-- `hit` plays once, on the hit, and never again. What lands with the death is `FALL` -- and
	-- "Body Fall Gooshy Mud 2" is a wet body impact one id away from the hit's "Body Hit Wet 7", out
	-- of the same library pack. So the two cues ARE nearly the same sound, which is exactly what she
	-- heard, and the fix is their character rather than their order.
	--
	-- SO BOTH ROWS ARE RETUNED, as data (before -> after):
	--   HIT   volume 0.8 -> 0.45, pitch 1.0 -> 0.85, highs cut 18 dB: quieter, lower, and with the
	--         wet snap taken off the top, which is the part that read as a slap.
	--   FALL  volume 0.7 -> 0.4, pitch 1.0 -> 0.72, highs cut 22 dB: a body landing is the heaviest
	--         and dullest thing a boar does, so it is pitched further down than the hit and cut
	--         harder. Lower and quieter than the hit in BOTH numbers, which is what stops it being
	--         mistaken for one -- and `boar_sound.spec` is what holds them apart from here.
	-- Nobody in this toolchain can hear either sample: these are the dials, and Karen's ears decide.
	--
	-- KAREN'S THIRD LISTEN, 2026-10-04: "so die sound still there / I hit once in back part, after
	-- while fallowed it falled on side and was sound of hit or whatever, it shouldnt be like that /
	-- when it dies could be sqeeck sound short / we need also think about sound when there is
	-- several walking and several sqeeng it could be anoying and shit sound / so we need realistic /
	-- I think we can remove hit sound for now / animal react sound is good and when die last sqeek
	-- need short one / pown should sqeen differen, male differen female different".
	--
	-- SO THE TWO IMPACT CUES ARE OFF, BY DATA AND NOT BY DELETION. `enabled = false` is the only
	-- thing `playOneShot` reads; the rows, their ids, volumes and filters are untouched, so bringing
	-- either back is one word. The FALL is the one she kept hearing as a second shot: it is a wet
	-- body impact out of the same pack as the hit, and a boar dying 25 s after it was shot made it
	-- land where a player expects nothing.
	HIT = {
		enabled = false, -- task 120: "I think we can remove hit sound for now"
		id = 9113519976, -- "Body Hit Wet 7"
		volume = 0.45,
		pitch = 0.85,
		eq = { low = 2, mid = -4, high = -18 },
		audibleStuds = 90,
	},
	-- THE REACTION STAYS AS IT IS: "animal react sound is good". Only its VOICE changes, below.
	CRY = { ids = { 9117369876, 9117370072 }, volume = 0.9, audibleStuds = 110 }, -- "Pig Squeals 1 / 3"
	-- A DEATH IS ONE SHORT SQUEAL NOW: "when it dies could be sqeeck sound short". It was
	-- "Pigs Beast-Like Screams 8", a long scream; it is the squeal samples, CUT at 0.6 s with a
	-- 0.15 s fade so it ends rather than stops. `VOICE` gives the male his own rougher sample back.
	DEATH = {
		ids = { 9117369876, 9117370072 }, -- "Pig Squeals 1 / 3"
		volume = 0.85,
		audibleStuds = 110,
		cut = 0.6, -- seconds of sound, whatever the sample's own length is
		fade = 0.15, -- the last of those seconds, taken down to nothing
	},
	-- ...AND NOTHING FOLLOWS IT: "when die last sqeek need short one" is one squeal, not a squeal and
	-- then a breath a second later. Off by data, like the two above.
	LAST_BREATH = { enabled = false, id = 9113629992, volume = 0.6, audibleStuds = 50, delay = 1.0 },
	FALL = {
		enabled = false, -- task 120: the thud she heard as "sound of hit or whatever"
		id = 9113469903, -- "Body Fall Gooshy Mud 2"
		volume = 0.4,
		pitch = 0.72,
		eq = { low = 3, mid = -6, high = -22 },
		audibleStuds = 80,
	},
	-- A VOICE PER KIND -----------------------------------------------------------------------------
	-- Karen: "pown should sqeen differen, male differen female different" (pown = piglet). A boar's
	-- VOICE is the three cues that come out of the animal -- its reaction, its death and its grunts.
	-- Its hooves, its breathing and the sniff are the world and are left alone.
	--
	-- PITCH DOES THE WORK, because nothing in this toolchain can audition a sound library and
	-- inventing an asset id would be a number nobody has heard. The ids below are the ones this
	-- project has already verified and listened to; each kind gets the subset that suits it and a
	-- pitch centre of its own, and the +-8 % jitter still rides on top. The Director or Karen can
	-- swap any id here for a better one without touching code.
	VOICE = {
		ENABLED = true,
		-- WHICH CUES ARE A VOICE. Footsteps, breath and the sniff are not.
		APPLIES = { cry = true, death = true, grunt = true },
		-- Deeper and rougher: the only beast-like scream in the set is his, and the two lower grunts.
		male = {
			pitch = 0.8,
			death = { 9117361361 }, -- "Pigs Beast-Like Screams 8", cut to 0.6 s
			cry = { 9117369876, 9117370072 }, -- "Pig Squeals 1 / 3"
			grunt = { 9117357588, 9117352464 }, -- "Pig Grunts 2 / 3"
		},
		-- The middle, and the sample set the config carried before any of this.
		female = {
			pitch = 1.0,
			death = { 9117369876, 9117370072 },
			cry = { 9117369876, 9117370072 },
			grunt = { 9117352464, 9117344600 }, -- "Pig Grunts 3 / 6"
		},
		-- Higher and thinner: one squeal, played half again as fast, which also makes it shorter.
		cub = {
			pitch = 1.4,
			death = { 9117369876 }, -- "Pig Squeals 1"
			cry = { 9117369876, 9117370072 },
			grunt = { 9117344600 }, -- "Pig Grunts 6"
		},
	},
	-- SIX ANIMALS MUST NOT SOUND LIKE SIX ANIMALS ---------------------------------------------------
	-- Karen: "we need also think about sound when there is several walking and several sqeeng it
	-- could be anoying and shit sound / so we need realistic". A sounder is up to six boars, each
	-- with its own hooves and its own voice, and six copies of one sample playing together is a wall
	-- of noise rather than a herd. Four limits, all data:
	--
	--   * ONE GRUNT PER SOUNDER AT A TIME, with a gap: a herd mutters, it does not chorus. A grunt
	--     that loses the race is SKIPPED, not queued -- the boar simply waits for its next interval,
	--     which is what a real animal that did not grunt does.
	--   * TWO SQUEALS WORLD-WIDE. A third animal crying or dying inside the window makes no sound.
	--     Deaths and reactions share the budget, so a sounder shot into cannot stack five squeals.
	--   * ONE SET OF HOOVES PER SOUNDER: the leader's. Five animals running together are one sound
	--     with one position, which is also what they are to a listener fifty studs away.
	--   * FAR ANIMALS ARE QUIETER than the roll-off alone makes them, measured from the nearest
	--     hunter, so a sounder crossing the far end of the field is background and not an event.
	CROWD = {
		ENABLED = true,
		SOUNDER_GRUNT_GAP = 2.5, -- seconds between grunts from ONE sounder, whoever makes them
		MAX_SQUEALS = 2, -- cries and deaths, world-wide, at once
		SQUEAL_SECONDS = 1.2, -- how long one counts as sounding against that budget
		ONE_STEP_EMITTER = true, -- a sounder's footsteps come from its leader and nobody else
		FAR_STUDS = 60, -- inside this, a voice is at its own volume
		FAR_FADE_STUDS = 60, -- and it reaches FAR_VOLUME this much further out
		FAR_VOLUME = 0.55,
	},
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

-- WHAT A BOAR NOTICES, AND WHAT IT DOES ABOUT IT (task 118), behind `BOAR_BEHAVIOUR`. Karen's scene:
-- "imagine they on easy, then see dog or person spook them they run", "it can be they relaxed if
-- hunter doesnt move", "once move it start to run or turn around and go another direction", "so
-- after shoot they will start sprint", and panic "spreading agree with you".
--
-- Pattern: awareness LEVELS with a dwell time and a refractory period, fed by ONE sensory function,
-- with a separate "notice" and "flush" radius per stimulus and hearing as a world event rather than
-- a query.
--   Tom Leonard, "Building an AI Sensory System: Examining the Design of Thief: The Dark Project"
--     (GDC 2003) https://www.gamedeveloper.com/programming/building-an-ai-sensory-system-examining-the-design-of-i-thief-the-dark-project-i-
--   Unreal Engine AIPerception (per-sense configs, gain radius != lose radius, stimulus age)
--     https://dev.epicgames.com/documentation/en-us/unreal-engine/ai-perception-in-unreal-engine
--     -- pattern only, no code (Unreal EULA)
-- The 25/60 split is Karen's, and it is also what flight-initiation-distance theory reports:
-- distance to flight grows with the approacher's speed and directness (Stankowich & Blumstein,
-- Proc. R. Soc. B 272 (2005) 2627-2634).
--
-- Design: docs/design/boar-behaviour.md (sections 3, 4, 5, 7.1)
-- Note:   docs/research/2026-10-04-boar-behaviour.md
Boar.CONFIG.SENSE = {
	-- THE FLAG, READ ONCE AT THIS BOUNDARY, exactly as `MODEL.ENABLED` and `CALM.ENABLED` read
	-- theirs (CLAUDE.md, feature flags). Every function below takes the value through `config`, so
	-- both branches are reachable by parameter while the flag sits at one of them -- which is the
	-- only way either branch can be tested, because the harness refuses to start with an override.
	ENABLED = Flags.isOn("BOAR_BEHAVIOUR"),

	-- THE TWO RADII KAREN GAVE (brief decision 1, "agree"). A standing person is noticed at 25; a
	-- moving one at 60, which is `Match.CONFIG.POINTS.PUSH_RADIUS` exactly, so push credit and the
	-- boar's own reaction begin at the same distance.
	NOTICE_STANDING = 25,
	NOTICE_MOVING = 60,
	-- ...and the third number, the one the playtest answers: how close a man gets before the animal
	-- bolts whatever it is doing. 0.6 x NOTICE_STANDING leaves a 10-stud band of "head up" first.
	FLUSH_STUDS = 15,

	-- WHAT COUNTS AS MOVING. The default Humanoid.WalkSpeed is 16 studs/s, and a standing
	-- character's server-measured displacement stays well under 1 (the smoothing below is why).
	MOVING_SPEED = 2,
	-- ...measured over this window and not over one frame, for the same reason
	-- `MODEL.YAW_SMOOTH_SECONDS` exists: one frame's delta on a replicated body is noise, not a
	-- rate. Longer than the yaw's 0.2 because this one is a gameplay threshold.
	SPEED_SMOOTH_SECONDS = 0.3,

	-- THE HYSTERESIS, AND THE ONE RELATIONSHIP THAT MUST NOT DRIFT. A boar is calm when nothing is
	-- inside its own notice radius PLUS this margin, and 30 is exactly CALM_RADIUS - DETECT_RADIUS
	-- (70 - 40), so with the flag OFF the calm test is arithmetically today's. `boar_behaviour.spec`
	-- asserts that equality so the two can never drift apart silently.
	CALM_MARGIN = 30,

	-- HEAD UP, THEN SETTLE. A 180-degree turn costs 0.79 s at TURN_RATE = 4 rad/s, which leaves
	-- ~1.7 s of actual head-up hold. Karen's dial.
	ALERT_SECONDS = 2.5,
	-- ...and then it will not go head-up again for this long. Without it a boar standing 20 studs
	-- from a motionless hunter flips IDLE->ALERT->IDLE every 2.5 s for ever; with it the animal
	-- grazes and lifts its head occasionally, which is what Karen asked for ("they relaxed").
	ALERT_REFRACTORY_SECONDS = 8,

	-- TURNED AWAY AND TROTTING OFF. The seconds are `CALM_TIME`: the same "it has stopped caring"
	-- span the system already uses. The angle is past 90 degrees so it reads as a refusal and not a
	-- sidestep ("turn around and go another direction"), and the distance is 2 s of trot plus
	-- margin -- one steering target, drawn on entry and never a path request.
	AVOID_SECONDS = 4,
	AVOID_TURN_DEG = 120,
	AVOID_STUDS = 80,

	-- A SHOT IS A SOUND, HIT OR MISS. 350 studs is ~98 m at 1 stud = 0.28 m. A 12-gauge is really
	-- audible for kilometres, and the whole 1,240 x 1,680 corridor bolting at the first shot would
	-- end a drive in 30 seconds -- so this is a GAMEPLAY number with no real-world anchor, and it is
	-- the one in this block most likely to change. Karen's dial.
	SHOT_AUDIBLE_STUDS = 350,
	-- ...held one second longer than `WOUND.BOLT_SECONDS` = 3: a hit boar carries on because it is
	-- hurt, an unhit one only has the bang.
	SHOT_SPRINT_SECONDS = 4,

	-- PANIC SPREADS MEMBER TO MEMBER, nearest first, so it reads as spreading rather than as a group
	-- teleporting into panic (Karen: "spreading agree with you"). 0.15 s is ~9 frames per hop, and a
	-- sounder of five is fully alarmed inside 0.6 s.
	PANIC_DELAY_SECONDS = 0.15,
	PANIC_DELAY_MAX = 0.6,

	-- A DOG IS A FLUSHER, so its radii are half again a person's. HOOK ONLY: dogs are out of scope
	-- (the brief), nothing produces `kind = "dog"` yet, and the first dog task fills it in and
	-- touches nothing else here.
	DOG_NOTICE_SCALE = 1.5,

	-- LINE OF SIGHT: NO, and this is the dial rather than the argument. A boar is a nose and a pair
	-- of ears first, and a hedge does not hide a man from one. `true` makes a NOTICE (not a flush)
	-- wait on `world.probe`; `docs/design/boar-ai.md` section 12 item 3 left this as Karen's call
	-- with "no line-of-sight" as the default, and this keeps that default.
	REQUIRE_SIGHT = false,
}

-- WHICH ANIMAL A BOAR IS (task 119). Karen, 2026-10-03: "we start with one bord and when this works
-- we do with rest" and "we need also biger smaller kids ect". RedDeer's package is a FAMILY on one
-- skeleton, so the sow and the cub are this same animal at a different length -- and the agreed
-- makeup (Director, 2026-10-04) is that a SOUNDER is a sow with young while a LONE animal is a male.
--
-- `scale` IS THE BOX and `clipScale` IS THE STRIDE, and they are two different measurements:
--   scale      the length the model was baked to, over the male's 5.5 studs. The Director's numbers:
--              0.85 for the sow, 0.45 for a striped cub. Every box -- the physics trunk and all four
--              hit zones -- is the male's times this, so a cub is a small target because it IS small.
--   clipScale  how far THIS animal's feet carry it per stride, over the male's. MEASURED by
--              `tools/boar_prep.py` on each animal's own export, and it is not the same number: the
--              female came out 0.8553 and the cub 0.4372, identically on all four locomotion clips
--              (walk 2.440/1.247 against the male's 2.852, trot 8.762/4.480 against 10.244, run
--              14.720/7.526 against 17.21, dig 1.626/0.831 against 1.901). The male's published clip
--              ids are what all three play -- same bone names, same rig -- so the rate that stops a
--              sow's feet sliding is her own number and not his.
--
-- BEHIND `BOAR_MODEL`, with everything else about the drawn animal: off, every boar is a male-sized
-- grey box and a sounder is five of them, which is the world every spec before this task asserts.
--   deathLiftStuds
--              HOW FAR THE DEAD ANIMAL HAS TO BE PUT BACK UP (task 120). Karen, 2026-10-04: "when
--              shoot cub he is gone not remaining" -- and it was not gone. MEASURED, in a live
--              session and then in the lab: a killed cub's drawn body ends 0.97 studs BELOW the
--              ground, and a cub is 1.44 studs tall, so the carcass is UNDER THE FLOOR. The box is
--              still there, anchored, `Carcass = true`, for the whole CARCASS_SECONDS; what is gone
--              is the picture.
--
--              WHY. A KeyframeSequence's rotations are scale-free but its TRANSLATIONS are absolute
--              studs (the same fact `tools/boar_prep.py` records about reusing one rig's clips), and
--              all three kinds play the MALE's published clips on geometry `boar_prep` baked
--              smaller. The root bone is not the culprit -- measured, it never moves: `root_bone`
--              sat at +0.002 for the whole clip on all three rigs. The fall is built out of CHILD
--              bone translations, and on a smaller rig every one of them is too long.
--
--              MEASURED 2026-10-04 on the real published clips (Death_L 128792697872198 and
--              Death_Paddle_L 131795481631371), at the frame `Body.stepVisual` freezes the death at
--              (`length - HOLD_EPSILON`), as the lowest bone against the rig's own bottom plane --
--              which is the plane `Body.visualOffset` puts on the box's bottom, i.e. the ground:
--
--                            held fall    held paddle   lowest bone
--                male          +0.002       +0.002      root_bone
--                female        -0.191       -0.205      tail_3
--                cub           -1.009       -1.009      hip_b.L
--
--              The paddle agrees with the fall, which is what its own asset note promises ("ENDS on
--              the pose it began on"), so this IS the pose the carcass keeps. Cross-checked against
--              a REAL kill in a live session: -0.97 on a cub whose box bottom was on the ground.
--
--              IT IS DATA AND NOT A FORMULA, because the obvious formula is wrong: scaling by
--              (1 - scale) predicts -0.26 for the sow against the measured -0.205, and no single
--              power of (1 - scale) fits both animals either. The translations are per bone, so
--              each rig's answer is its own measurement. A FOURTH KIND MUST BE MEASURED THE SAME
--              WAY -- and if it is not, `boar_model.spec`'s "the dead animal is drawn on the
--              ground" case is what says so.
Boar.CONFIG.KINDS = {
	ENABLED = Flags.isOn("BOAR_MODEL"),
	DEFAULT = "male",
	ORDER = { "male", "female", "cub" },
	male = { name = "male", scale = 1.0, clipScale = 1.0, model = "male", deathLiftStuds = 0 },
	female = { name = "female", scale = 0.85, clipScale = 0.8553, model = "female", deathLiftStuds = 0.205 },
	cub = { name = "cub", scale = 0.45, clipScale = 0.4372, model = "cub", deathLiftStuds = 1.009 },
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
	-- THE HEAD-UP CLIP AN ALERT BOAR DRAWS (task 118), as a STRING naming a row in `CLIPS` -- which
	-- is the whole of this task's dependency on task 117 and on the Director's publishing. The
	-- Director's decision, 2026-10-04: it is 117's `smell` (Idle_5, 4.1667 s, the nose 30.4 degrees
	-- up), so a boar that has winded somebody stands in the same posture it uses to scent the air.
	-- With no id published `Body.hasClip` is false, the animal plays `idle`, and every behaviour in
	-- task 118 is unchanged -- the same "if an id is missing, the current behaviour stays" rule the
	-- file already rests on. It is a ONE-SHOT, so an ALERT longer than the clip holds its last pose;
	-- `ALERT_SECONDS` = 2.5 is well inside 4.1667.
	ALERT_CLIP = "smell",
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
-- WHO A SOUNDER IS MADE OF (task 119). Pure: a size and a roll per member in, a list of kinds out,
-- so the makeup is a spec case with no boar in the world. The first member is the SOW and the rest
-- are her young, each of which may be the occasional young male.
--
-- IT IS NOT THE LEADER THAT IS THE SOW. The leader is whoever is nearest the exit line
-- (`_chooseLeader`) and it changes while they run; which animal each member IS is decided once, at
-- the spawn, and never again. A sow that falls behind her cubs is still the sow.
function Boar.sounderKinds(size: number, rolls: { number }, config)
	local kinds = {}
	local makeup = config.SOUNDER.MAKEUP
	local on = config.KINDS ~= nil and config.KINDS.ENABLED == true
	for index = 1, math.max(0, math.floor(size)) do
		if not on then
			-- With `BOAR_MODEL` off every animal is the male-sized box this game has always spawned.
			table.insert(kinds, config.KINDS and config.KINDS.DEFAULT or "male")
		elseif index == 1 then
			table.insert(kinds, makeup.SOW)
		elseif (rolls[index] or 1) < makeup.YOUNG_MALE_CHANCE then
			table.insert(kinds, makeup.YOUNG_MALE)
		else
			table.insert(kinds, makeup.YOUNG)
		end
	end
	return kinds
end

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

-- Flat (XZ) copy of a position. Every distance this file measures is a flat one: a boar on a slope
-- is not further away than one on the level.
local function flatOf(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

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
	-- ...AND A SENSE BLOCK MERGED KEY BY KEY (task 118, design section 6), for the same shallow-clone
	-- reason and one worse consequence: a spec or a world passing `config = { SENSE = { ENABLED =
	-- true } }` would REPLACE the whole block, and then every radius and every timer reads nil --
	-- which is not an error, it is a boar that notices nothing at any distance and never settles.
	-- The merge is what makes "the flag's value is the only thing a caller has to say" true.
	local senseOverride = (world.config or {}).SENSE
	self._config.SENSE = table.clone(Boar.CONFIG.SENSE)
	if type(senseOverride) == "table" then
		for key, value in pairs(senseOverride) do
			self._config.SENSE[key] = value
		end
	end
	-- ...AND THE KINDS BLOCK, for exactly the same reason (task 119): a world that passes
	-- `config = { KINDS = { ENABLED = true } }` would otherwise replace the whole table and every
	-- animal's scale, stride and model would read nil -- which is not an error, it is three boars
	-- with no size.
	local kindsOverride = (world.config or {}).KINDS
	self._config.KINDS = table.clone(Boar.CONFIG.KINDS)
	if type(kindsOverride) == "table" then
		for key, value in pairs(kindsOverride) do
			self._config.KINDS[key] = value
		end
	end
	-- The skinned model's two lookups, both nil until a boot script wires them: with no template the
	-- boar is the grey box, which is what every spec before task 115 asserts.
	-- `_heldTemplate` AND NOT `_modelTemplate`: the method below is `Runtime:_modelTemplate`, which
	-- lives on the metatable, so a nil FIELD of that name resolves to the METHOD and the next line to
	-- touch it reads "attempt to index function with 'Parent'". Measured the hard way: it took out
	-- four cases of boar_model.spec on the first gate run of this task.
	-- ONE HELD TEMPLATE PER KIND (task 119): male, female and cub are three different assets and a
	-- single slot would hand a cub the sow's coat. Keyed by the kind's own name.
	self._heldTemplate = {} :: { [string]: Instance }
	self._templateFor = nil :: ((string) -> Instance?)?
	self._animationIdFor = nil :: ((string) -> number?)?
	-- FALSE MEANS "USE THE MODULE'S", and once `Runtime:setModelSource` has been called it is true
	-- for ever. Without this flag, `self._templateFor or moduleTemplateFor` would make "this runtime
	-- has NO template" inexpressible -- a spec asking for the no-model branch would silently be
	-- handed the live server's real boar, and the one case the flag's promise rests on would pass for
	-- the wrong reason.
	self._modelSourceSet = false
	-- ONE "WHEN DID I LAST ASK" PER KIND (task 119, review round 2, note). With one scalar for all
	-- three, `Runtime:step` asking for every kind in the same frame let only the FIRST through per
	-- `ASK_EVERY_SECONDS`: the sow's coat could not arrive until a second after the male's and the
	-- cub's until two, and anything born meanwhile stayed a grey box for that long.
	self._askedModelAt = {} :: { [string]: number }
	self._field = world.field or self._config.field
	self._rng = world.rng or Random.new()
	self._boars = {}
	self._nextId = 0
	-- THE SOUNDERS, and this list is the only place a group exists. The Brain holds no reference to
	-- another boar and Body knows nothing about groups, so "who is in a sounder, who leads it and
	-- how long it is scattering" has exactly one writer (CLAUDE.md rule 3).
	self._sounders = {}
	-- WHEN EACH SQUEAL STOPS COUNTING against `SOUND.CROWD.MAX_SQUEALS` (task 120). One list per
	-- runtime, and production has exactly one runtime, so "two at once" is world-wide.
	self._squeals = {}
	self._nextSounderId = 0
	-- EVERY STIMULUS'S MEASURED SPEED (task 118, design section 4.6), written here and nowhere else:
	-- id -> { position, speed }. A character's own `AssemblyLinearVelocity` is network-owned by that
	-- character's client, so a client that wants to be unnoticed could simply report nothing; a
	-- server-measured displacement of the replicated position cannot be faked, and a provider that
	-- forgets to fill `speed` cannot make every boar think a sprinting driver is standing still.
	self._motion = {}
	-- HEARD SHOTS IN FLIGHT (section 4.5): appended by `Runtime:hearShot`, drained by `Runtime:step`
	-- and handed to every Brain as `obs.sounds`, exactly as `entry.hitEvents` is drained and handed.
	self._sounds = {}
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
		squealsSkipped = 0, -- a cry or a death that found the world's two voices already busy
		zoneHits = {}, -- PELLETS per zone, so it sums to pelletsTaken
		unknownZoneHits = 0, -- hits carrying a zone no DAMAGE row knows: an attribute typo, not free
		tallylessHits = 0, -- hits with no per-pellet tally, charged at the dominant zone
		soundersSpawned = 0,
		soundersDissolved = 0, -- fell to one member (or none): the survivor is a lone boar again
		leaderPromotions = 0,
		membersLeft = 0, -- left ALIVE: mortally wounded, or too far for too long. A despawn is not one
		scatters = 0, -- a hit on any member latches the whole sounder's scatter
		-- TASK 118. `shotsHeard` is boars HANDED a shot sound (the Brain decides what to do with
		-- it); `alarms` is outbreaks of panic spread through a sounder, one per outbreak and not one
		-- per member; `alerts` and `avoids` are counted on the EDGE, so 2.5 s of head-up is one.
		shotsHeard = 0,
		alarms = 0,
		alerts = 0,
		avoids = 0,
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
local moduleTemplateFor: ((string) -> Instance?)? = nil
local moduleAnimationIdFor: ((string) -> number?)? = nil

-- Returns the pair it replaced, so a caller that must put it back can.
function Boar.setModelSource(
	templateFor: ((string) -> Instance?)?,
	animationIdFor: ((string) -> number?)?
): (((string) -> Instance?)?, ((string) -> number?)?)
	local previousTemplate, previousId = moduleTemplateFor, moduleAnimationIdFor
	moduleTemplateFor = templateFor
	moduleAnimationIdFor = animationIdFor
	return previousTemplate, previousId
end

function Runtime:setModelSource(templateFor: ((string) -> Instance?)?, animationIdFor: ((string) -> number?)?)
	self._templateFor = templateFor
	self._animationIdFor = animationIdFor
	self._modelSourceSet = true -- from here on this runtime ignores the module's, nil included
	self._heldTemplate = {}
	self._askedModelAt = {}
end

-- The template, or nil, asking at most once every ASK_EVERY_SECONDS until it has one.
function Runtime:_modelTemplate(kind: string, now: number): Instance?
	local held = self._heldTemplate[kind]
	if held ~= nil and held.Parent ~= nil then
		return held
	end
	local ask = if self._modelSourceSet then self._templateFor else moduleTemplateFor
	if ask == nil then
		return nil
	end
	if now - (self._askedModelAt[kind] or -math.huge) < self._config.MODEL.ASK_EVERY_SECONDS then
		return nil
	end
	self._askedModelAt[kind] = now
	local template = ask(kind)
	if template == nil then
		return nil
	end
	self._heldTemplate[kind] = template
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

-- THE ONE WAY A SOUND ENTERS THIS SYSTEM (task 118, design section 4.5), and it is the shape
-- `takeHit` below already has: `ServerScriptService.Weapon` publishes `ShotFired`, `MatchBoot` --
-- the composition root that already knows both systems -- calls this, and neither owner requires the
-- other. A MISS is a sound too, which is the whole point: "so after shoot they will start sprint".
--
-- Returns how many live boars will be TOLD. The Brain owns the audible radius (`_hearSound` tests it
-- again, because a pure spec must be able to drive a sound at any distance with no runtime at all),
-- so this number is a diagnostic and a fan-out count, not the rule.
function Runtime:hearShot(at: Vector3): number
	if self._destroyed then
		return 0
	end
	local sense = self._config.SENSE
	-- WITH THE FLAG OFF NOTHING HEARS ANYTHING, so nothing is queued and nothing is counted. The
	-- Brain's own gate in `_hearSound` is what makes that true of the BEHAVIOUR; this makes it true
	-- of the BOOKKEEPING as well, because `MatchBoot` wires `Weapon.ShotFired` unconditionally and
	-- a `shotsHeard` that moved in the OFF world would mean "shots fired in range" rather than
	-- "boars told" (review round 2, note).
	if not (sense and sense.ENABLED) then
		return 0
	end
	table.insert(self._sounds, { kind = "shot", position = at })
	local told = 0
	for _, entry in ipairs(self._boars) do
		local state = entry.brain:state()
		-- The same three states `_hearSound` refuses: a carcass, a terminal boar and a crippled one.
		if state ~= "DOWN" and state ~= "GONE" and state ~= "CRIPPLED" then
			if (flatOf(Body.position(entry.body)) - flatOf(at)).Magnitude <= sense.SHOT_AUDIBLE_STUDS then
				told += 1
			end
		end
	end
	self._stats.shotsHeard += told
	return told
end

-- A COPY of one boar's last PERCEPTION, or nil. It follows `woundOf` and `animationOf` exactly: a
-- copy, no setter, and nothing in the game reads it. It exists so a live spec can prove WHY a boar
-- did something instead of inferring it from a velocity (design section 7.2).
function Runtime:perceptionOf(id: string)
	for _, entry in ipairs(self._boars) do
		if entry.id == id then
			return entry.brain:perception()
		end
	end
	return nil
end

-- EVERY STIMULUS'S SPEED, MEASURED HERE AND NOWHERE ELSE (section 4.6). An exponential average over
-- `SPEED_SMOOTH_SECONDS` of the FLAT displacement between steps, for the same measured reason
-- `MODEL.YAW_SMOOTH_SECONDS` exists: one frame's delta on a physics body is noise, not a rate.
--
-- It builds NEW records rather than mutating the provider's -- a provider may cache its list one day
-- -- which costs one small table per stimulus per step, over the <= 16 a corridor can hold.
--
-- A stimulus seen for the first time has no previous sample and reads as standing for exactly one
-- step (16 ms): it can only ever under-react, never over-react.
function Runtime:_measureMotion(threats, dt: number)
	local sense = self._config.SENSE
	local motion = self._motion
	local alpha = if dt > 0 then math.clamp(dt / math.max(sense.SPEED_SMOOTH_SECONDS, 1e-6), 0, 1) else 0
	local out = {}
	local seen = {}
	for _, threat in ipairs(threats) do
		local id = threat.id
		seen[id] = true
		local previous = motion[id]
		local speed = 0
		if previous and dt > 0 then
			local moved = (flatOf(threat.position) - flatOf(previous.position)).Magnitude
			speed = previous.speed + (moved / dt - previous.speed) * alpha
		end
		motion[id] = { position = threat.position, speed = speed }
		table.insert(out, { id = id, position = threat.position, kind = threat.kind, speed = speed })
	end
	for id in pairs(motion) do
		if not seen[id] then
			motion[id] = nil -- it left: forget it, so a rejoin reads as standing for one step
		end
	end
	return out
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
				-- ...AND ONLY IF THE WORLD HAS A VOICE TO SPARE (task 120): two squeals at once is
				-- the cap, and a third animal is not heard rather than heard late.
				if class ~= "vital" and severity ~= "lethal" and self:_claimSqueal() then
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

-- ONE OF THE WORLD'S TWO VOICES, OR NOTHING (task 120). Karen, 2026-10-04: "several sqeeng it
-- could be anoying and shit sound / so we need realistic". Prunes the squeals that have finished,
-- then takes a slot if one is free. A refusal is a SKIP and never a queue: the animal that could not
-- be heard simply was not heard, which is what happens in a wood full of noise.
function Runtime:_claimSqueal(): boolean
	local crowd = self._config.SOUND.CROWD
	if crowd == nil or crowd.ENABLED ~= true then
		return true
	end
	local now = os.clock()
	local kept = {}
	for _, expiry in ipairs(self._squeals) do
		if expiry > now then
			table.insert(kept, expiry)
		end
	end
	self._squeals = kept
	if #kept >= crowd.MAX_SQUEALS then
		self._stats.squealsSkipped += 1
		return false
	end
	table.insert(self._squeals, now + crowd.SQUEAL_SECONDS)
	return true
end

-- WHAT ONE ANIMAL IS ALLOWED TO MAKE A NOISE WITH THIS STEP, and how loud its voice is (task 120).
-- The Runtime answers this because it is the only thing that knows where the hunters are and what
-- the rest of the sounder is doing. With `CROWD` off it answers nil and sets the scale to 1, which
-- is the world every spec before this task asserts.
function Runtime:_voiceFor(entry, threats, now: number)
	local crowd = self._config.SOUND.CROWD
	if crowd == nil or crowd.ENABLED ~= true then
		Body.setVoiceScale(entry.body, 1)
		return nil
	end
	local at = Body.position(entry.body)
	local nearest = nil
	for _, threat in ipairs(threats) do
		if typeof(threat.position) == "Vector3" then
			local flat = Vector3.new(threat.position.X - at.X, 0, threat.position.Z - at.Z).Magnitude
			if nearest == nil or flat < nearest then
				nearest = flat
			end
		end
	end
	Body.setVoiceScale(entry.body, Body.farScale(nearest, self._config))

	local record = self:_sounderRecord(entry.sounderId)
	if record == nil then
		return { grunt = true, steps = true } -- a lone boar competes with nobody
	end
	return {
		grunt = (record.gruntAgainAt or 0) <= now,
		-- The leader is the one set of hooves. With no leader yet (the first tick after one dies)
		-- nobody is silenced, which is the safe way round: a missing sound is worse than a late one.
		steps = Boar.isStepEmitter(record.leaderId, entry.id, self._config),
	}
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
	-- ...AND THE ALARM GOES WITH THE MEMBERSHIP (task 118, section 5.2 item 3). A lone boar has no
	-- group to be alarmed by, and a stale `alarmIn` would keep it fleeing for ever.
	entry.alarmIn = nil
	if counted then
		self._stats.membersLeft += 1
	end
	if record.leaderId == entry.id then
		record.leaderId = nil
	end
end

-- PANIC SPREADS, MEMBER TO MEMBER, WITH A DELAY (task 118, design section 5.2). It REPLACES the
-- leader-only rule in the Brain when the flag is on -- it does not run beside it -- because two
-- correct rules disagreeing is this project's named killer (docs/PROJECT_CONTEXT.md).
--
-- Karen: "spreading agree with you". ALERT does not spread: one animal with its head up while the
-- others graze is what a sounder actually looks like, and only panic is contagious.
function Runtime:_stepAlarm(record, members, dt: number, snapshot)
	local sense = self._config.SENSE

	local function positionOf(entry): Vector3
		local sample = snapshot[entry.id]
		return flatOf(if sample then sample.position else Body.position(entry.body))
	end

	-- COUNTED WITH dt AND NOT WITH A CLOCK, so a spec is deterministic -- the same rule every timer
	-- in the Brain follows.
	--
	-- AND THE ALARM IS A PULSE, NOT A LATCH (review round 2, finding 1). It is published to a member
	-- from the step its own delay runs out until the step that member is ITSELF panicked, and then
	-- it is spent: from there the animal's panic is its own and section 3.2's row 11 owns the
	-- settling, which is what section 5.2 item 4 says ("a follower settles when its own CALM_TIME
	-- has run and the leader is calm").
	--
	-- LATCHED, IT WAS A DEADLOCK WITH NO WAY OUT, and the Reviewer is right that nothing in the
	-- suite could see it: row 8 of `Brain:_senseAware` flushes an alarmed member and `_flush` resets
	-- `_sinceCalm`, so an alarmed member could never become calm; `calm` below was therefore never
	-- true; so `record.alarmed` never dropped and the `alarmIn` that pinned them was never cleared.
	-- Every sounder that panicked once ran until its last member crossed the exit line -- against
	-- section 5.2 item 3, section 3.2 row 11 and section 14's own end-to-end scene.
	for _, entry in ipairs(members) do
		if entry.alarmIn ~= nil then
			entry.alarmIn = math.max(0, entry.alarmIn - dt)
			if entry.alarmIn <= 0 and Brain.classOf(entry.brain:state()) == "panicked" then
				-- DELIVERED. The one job an alarm has is to START this animal running, and it is
				-- running. It is cleared here and not by the Brain because the Brain is pure and
				-- holds no sounder state: who has been told is the Runtime's bookkeeping, like
				-- membership and the leader (CLAUDE.md rule 3).
				entry.alarmIn = nil
			end
		end
	end

	local first, calm = nil, true
	for _, entry in ipairs(members) do
		if Brain.classOf(entry.brain:state()) == "panicked" then
			calm = false
			if first == nil then
				first = entry
			end
		end
	end

	if calm then
		-- IT CLEARS WHEN EVERY MEMBER IS CALM AGAIN, and then the next outbreak spreads afresh.
		if record.alarmed then
			record.alarmed = false
			for _, entry in ipairs(members) do
				entry.alarmIn = nil
			end
		end
		return
	end
	if record.alarmed then
		return -- one alarm per outbreak: "no alarm is running for that sounder"
	end

	record.alarmed = true
	self._stats.alarms += 1
	local from = positionOf(first)
	local others = {}
	for _, entry in ipairs(members) do
		if entry.id ~= first.id then
			table.insert(others, entry)
		end
	end
	-- NEAREST FIRST, tie-broken by id exactly as `_chooseLeader` breaks its own tie: the order a
	-- panic travels in must not depend on the order of a list.
	table.sort(others, function(a, b)
		local da, db = (positionOf(a) - from).Magnitude, (positionOf(b) - from).Magnitude
		if da == db then
			return a.id < b.id
		end
		return da < db
	end)
	for rank, entry in ipairs(others) do
		entry.alarmIn = math.min(sense.PANIC_DELAY_SECONDS * rank, sense.PANIC_DELAY_MAX)
	end
	first.alarmIn = 0 -- it is already running; this only makes the record uniform
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

		-- PANIC SPREADS (task 118, section 5.2), after membership is rebuilt and before any Brain is
		-- asked anything. Behind the flag: with it off no `alarmIn` is ever set, `obs.sounder.alarm`
		-- is false for every member, and the Brain's own leader-panic rule is the only one running.
		if self._config.SENSE.ENABLED and #members > 1 then
			self:_stepAlarm(record, members, dt, snapshot)
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
		-- TASK 118, as plain values like everything else here: which shape this sounder moves in,
		-- and whether the panic has reached THIS member yet (sections 5.1 and 5.2).
		formation = record.formation or "wedge",
		alarm = entry.alarmIn ~= nil and entry.alarmIn <= 0,
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
		formation = record.formation or "wedge", -- task 118, section 5.1
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
		-- SINGLE FILE OR A LOOSE GROUP, DRAWN ONCE AND NEVER WRITTEN AGAIN (task 118, section 5.1).
		-- Karen: "they usually do one line each after another or mixed like in real life". The flag
		-- is tested FIRST so that with it off no number is drawn at all and the runtime's `Random`
		-- stream is bit-for-bit the one every existing spec was written against.
		formation = (if config.SENSE.ENABLED and self._rng:NextNumber() < sounderConfig.COLUMN_CHANCE
			then "column"
			else "wedge"),
		-- Whether a panic is already spreading through this sounder (section 5.2).
		alarmed = false,
	}

	-- WHO THEY ARE (task 119): a sow and her young, drawn before any of them exists so the draw is
	-- one pure call on one list of rolls rather than a decision inside the loop.
	-- GATED, like the formation draw three lines up and for the same reason (review round 2,
	-- note): with `BOAR_MODEL` off no number is drawn at all, so the runtime's `Random` stream is
	-- bit-for-bit the one every spec written before this task was written against.
	local rolls = {}
	if config.KINDS.ENABLED then
		for index = 1, size do
			rolls[index] = self._rng:NextNumber()
		end
	end
	local kinds = Boar.sounderKinds(size, rolls, config)

	local handles = {}
	for index = 1, size do
		local angle = phase + (index - 1) * (math.pi * 2 / size)
		local at = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local handle = self:spawn(at, kinds[index])
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

function Runtime:spawn(position: Vector3?, kind: string?)
	assert(not self._destroyed, "Boar runtime is destroyed")
	assert(#self._boars < self._config.maxBoars, "Boar runtime is at maxBoars")

	local config = self._config
	-- WHICH ANIMAL (task 119). A lone boar is a male -- `SOUNDER.MAKEUP.LONE` -- and a member of a
	-- sounder is told which one it is by `spawnSounder`.
	local geometry = Body.kindGeometry(kind or config.SOUNDER.MAKEUP.LONE, config)
	local at = position or config.spawnPoint
	-- DROPPED FROM THE MALE'S HEIGHT, WHATEVER THE ANIMAL IS, and that is MEASURED and not tidy
	-- (task 119, 2026-10-04). `field.groundY` is the FIELD's ground and the map's real surface is not
	-- always on it: in the generated map a released sow settled with her box bottom 2.0 studs ABOVE
	-- `groundY`, so every boar is spawned embedded and pushed out by the physics. A male's box is 3
	-- studs tall and its top clears that; a CUB's whole box is 1.35 studs and would sit entirely
	-- below the surface -- and a fully embedded part is ejected, not settled. Every cub the drive
	-- released vanished inside a second while the sows and young males beside it lived, and this is
	-- that bug: a cub now falls 0.8 studs further and lands on whatever is actually under it.
	--
	-- IT IS THE MALE'S NUMBER FOR EVERY KIND, so the flag-OFF world spawns at exactly the height it
	-- always did. The right long-term answer is to ask the world how high the ground under the spawn
	-- point is, which is a new seam on `world` and not this task's.
	at = Vector3.new(at.X, self._field.groundY + config.BODY_SIZE.Y / 2 + config.SPAWN_CLEARANCE, at.Z)

	self._nextId += 1
	local id = string.format("Boar%d", self._nextId)
	local body = Body.create(config, self._folder, id, at, geometry.kind)
	local brain = Brain.new(config, self._field, at, self._rng)

	local handle = {
		id = id,
		-- WHICH ANIMAL IT IS (task 119), on the handle because the drive and the specs read handles
		-- and never the entry: "the sounder is a sow and three cubs" is answerable from outside.
		kind = body.kind,
		part = body.part,
		-- WHAT IT HAS BEEN HEARD TO DO (task 120): the live `name -> plays` table `Body.playOneShot`
		-- counts into, so a spec can say "the hit sound played exactly once" across a hit and the
		-- death that came 25 seconds after it. A reference and not a copy, so it keeps counting.
		soundPlays = body.soundPlays,
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
		-- How long until the sounder's panic reaches THIS member, or nil for "no alarm" (task 118,
		-- section 5.2). Written only by `_stepAlarm` and cleared by `_leaveSounder`.
		alarmIn = nil :: number?,
		-- The state the last intent carried, so ALERT and AVOID are counted on the EDGE: 2.5 s of
		-- head-up is one alert, not 150.
		lastState = nil :: string?,
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
		-- WHICH ANIMAL IT WAS (task 120), on the despawn payload as well as the kill one: a rule
		-- about cubs has to be able to tell a cub that was killed from a cub that got away.
		kind = entry.body.kind,
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
	-- THE SPEED OF EVERY STIMULUS, MEASURED (task 118, section 4.6), and only when the flag is on:
	-- with it off nothing reads `speed`, and the OFF world keeps the exact allocation profile it had.
	if config.SENSE.ENABLED then
		threats = self:_measureMotion(threats, dt)
	end
	-- HEARD SHOTS, DRAINED ONCE PER STEP and handed to every boar, exactly as `hitEvents` are
	-- drained per boar: the Brain owns the audible radius (section 4.5). nil when there are none, so
	-- every existing spec is handed the nil it was handed before this task.
	local sounds = nil
	if #self._sounds > 0 then
		sounds = self._sounds
		self._sounds = {}
	end

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
	-- ONE LOOKUP PER KIND PER STEP (task 119), not one per boar: a sounder of five is a sow and four
	-- cubs, which is two assets however many animals are standing in it.
	local visualTemplates: { [string]: Instance? } = {}
	if config.MODEL.ENABLED then
		local now = os.clock()
		for _, kind in ipairs(config.KINDS.ORDER) do
			visualTemplates[kind] = self:_modelTemplate(kind, now)
		end
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
			-- TASK 118: the shots drained above, and the sight probe -- handed in ONLY when
			-- `REQUIRE_SIGHT` asks for it (section 4.7), so the default costs nothing and the hook
			-- is real rather than described.
			sounds = sounds,
			probe = if config.SENSE.REQUIRE_SIGHT then self._world.probe else nil,
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
		local visualTemplate = visualTemplates[entry.body.kind or config.KINDS.DEFAULT]
		if config.MODEL.ENABLED and visualTemplate ~= nil and entry.body.visual == nil then
			Body.attachVisual(entry.body, visualTemplate, config)
		end

		-- ALERT AND AVOID, COUNTED ON THE EDGE (task 118): one per transition, so a stat says how
		-- often the animal reacted and not how many frames it spent reacting.
		if intent.state ~= entry.lastState then
			if intent.state == "ALERT" then
				self._stats.alerts += 1
			elseif intent.state == "AVOID" then
				self._stats.avoids += 1
			end
			entry.lastState = intent.state
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
				Body.playDeath(entry.body, config, self._rng, self:_claimSqueal())
			end
			self._downedSignal:Fire(Wound.killRecord(
				entry.wound,
				entry.id,
				position,
				os.clock() - entry.bornAt,
				config.WOUND,
				entry.body.kind -- WHICH ANIMAL DIED (task 120): what a cub penalty will read
			))
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
				-- HOW FAR THIS ANIMAL'S OWN STRIDE CARRIES IT, over the male's (task 119). It rates
				-- every clip that moves the ground, so a cub playing the male's walk does not skate.
				clipScale = entry.body.geometry and entry.body.geometry.clipScale,
				-- ...AND HEAD UP (task 118, section 3.6), the same shape and for the same reason: a
				-- stopped animal and an alert one are both standing still, so speed cannot carry it.
				alert = intent.state == "ALERT",
				-- WHAT A CALM BOAR IS DOING (task 117). Published by the Brain only while IDLE, so
				-- every other state hands `Body` the nil it handed before.
				activity = intent.activity,
				activityDraw = intent.activityDraw,
			}, config)
			-- The same speed drives the sound, so the footsteps keep time with the legs rather than
			-- with the body's measured velocity, which lags the setpoint by the ACCEL ramp.
			-- WHAT THE CROWD ALLOWS IT (task 120), and the slot it books by being heard: one
			-- grunt per sounder per `SOUNDER_GRUNT_GAP`, whoever makes it.
			local now = os.clock()
			local voice = self:_voiceFor(entry, threats, now)
			local played = Body.stepSound(entry.body, dt, wantSpeed, config, self._rng, voice)
			if played == "grunt" then
				local record = self:_sounderRecord(entry.sounderId)
				if record then
					record.gruntAgainAt = now + config.SOUND.CROWD.SOUNDER_GRUNT_GAP
				end
			end
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
