-- Boar.Body: the only writer of a boar's Instances. It creates the Part, its Attachment, its two
-- constraints and -- since Milestone 1.5 -- its three welded hit-zone parts; it sets the server as
-- network owner, drives them each tick, flashes them when the boar is hit, collapses them when it
-- dies, and is the only thing that destroys them. Nothing else in the codebase may touch
-- Workspace.Boars, and nothing else decides anything: every number arrives in `config`.
--
-- Pattern: an unanchored, physically simulated body driven by constraints, never by per-frame CFrame
-- writes. Two systems writing a creature's position killed the previous project
-- (docs/PROJECT_CONTEXT.md, "Overlapping owners").
--   Network ownership  https://create.roblox.com/docs/physics/network-ownership
--     "the server always owns anchored BaseParts and you cannot manually change their ownership",
--     so the body MUST be unanchored or SetNetworkOwner errors.
--   LinearVelocity     https://create.roblox.com/docs/reference/engine/classes/LinearVelocity
--     Plane mode leaves the plane normal (Y) free, so gravity -- not the constraint -- owns falling.
--   AlignOrientation   https://create.roblox.com/docs/reference/engine/classes/AlignOrientation
--     keeps the box upright and turned along travel without manual torque maths.
--   Assemblies + WeldConstraint  https://create.roblox.com/docs/physics/assemblies
--     "an assembly is considered a single rigid body"; the root part is "the part used to keep
--     consistent physics replication and network ownership", and parts with "Massless set to false
--     (default) take precedence" when the engine picks that root -- so the massless zone parts can
--     never take it away from the trunk, and SetNetworkOwner, the mover and the upright constraint
--     go on working on the same part as before.
--   Raycasting + CanQuery  https://create.roblox.com/docs/workspace/raycasting
--     "You can exempt any BasePart from hit detection by setting its BasePart.CanQuery property to
--     false" -- and CanCollide is a different property, which is why a hit box may protrude where a
--     collision box must not.
--
-- THE ZONE PARTS PROTRUDE, AND THAT IS THE WHOLE TRICK. A ray returns the nearest surface, so zone
-- parts nested inside the trunk would never be hit: every shot would report `body`, and a spec that
-- called takeHit with zone = "head" directly would pass while no player could ever produce a head
-- shot. tests/server/boar_zones.spec.luau fires twelve real rays from outside for that reason.
--
-- THE SKINNED MODEL IS A PASSENGER AND NOTHING ELSE (task 115, behind `BOAR_MODEL`). With the flag
-- on, every boar gains ONE visual child: RedDeer's skinned boar, welded to the trunk, `Massless`,
-- `CanCollide = false`, `CanQuery = false`, `CanTouch = false`, and carrying NO `Damageable` and no
-- `HitZone`. So the physics, the raycasts, the wounds and the sounders are the same code over the
-- same Instances as before it, and the flag's two states differ by exactly what is DRAWN.
--   Skinned meshes      https://create.roblox.com/docs/art/modeling/rigging
--     Bones are descendants of the MeshPart, so moving the MeshPart moves the whole rig, and the
--     scale has to be baked into the upload: `Size` and `Model:ScaleTo` move the mesh and not the
--     bones, which tears the animal as soon as a clip plays.
--   AnimationController + Animator  https://create.roblox.com/docs/reference/engine/classes/AnimationController
--     The rig root is the controller's PARENT, which is why the controller is a child of the cloned
--     Model rather than of the trunk. `Animator:LoadAnimation` on the SERVER replicates the track to
--     every client, so every player sees the same animal doing the same thing.
--
-- Design: docs/design/boar-ai.md (section 6), docs/design/hit-zones.md (sections 4, 7)
-- Note:   docs/research/2026-09-24-boar-ai.md, docs/research/2026-09-25-hit-zones.md,
--         docs/research/2026-10-03-boar-skinned-model.md
local ContentProvider = game:GetService("ContentProvider")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

local Body = {}

function Body.ensureFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- ---------------------------------------------------------------- the three animals (task 119)
--
-- Karen: "we need also biger smaller kids ect". RedDeer's package is a FAMILY on one skeleton
-- (`Arm_Boar`; 40 `Bone` instances arrive in Studio, the same 40 names in all three -- counted off
-- the three loaded templates on 2026-10-04), so a sow and a cub are the same animal at
-- a different length: `tools/boar_prep.py` baked 4.675 and 2.475 studs into their geometry against
-- the male's 5.5, and everything this file builds around them is the male's numbers times that ratio.
--
-- ONE SCALE, EVERY BOX. The physics trunk and all four hit zones scale together, so a cub is a SMALL
-- TARGET in exactly the way it looks small: its chest is 0.45 of the male's chest and its head is
-- 0.45 of his head, and no number anywhere says so twice.
--
-- THE PROTRUSION SCALES WITH THEM, deliberately. `ZONES.PROTRUSION` is the clearance that stops a
-- zone part being FLUSH with the trunk, because two coincident surfaces at one ray distance is a
-- coin toss and not a hit zone (task 116, review round 2). Scaled, a cub's zones stand 0.027 studs
-- proud instead of 0.06 -- smaller, but still a clearance a float comparison settles the same way
-- every time, and still proportionally what the male has.
--
-- WITH `BOAR_MODEL` OFF EVERY KIND IS THE MALE, box for box: the flag gates the whole block, so the
-- grey-box world is the one Milestone 1.2 shipped and every spec written against it still holds.
function Body.kindRow(kind: string?, config)
	local kinds = config.KINDS
	if kinds == nil or kinds.ENABLED ~= true then
		-- The no-KINDS fallback carries its own `name`, so `kindGeometry(...).kind` is never nil
		-- and `Body.create` cannot stamp a handle with no kind (review round 2, note).
		return kinds and kinds[kinds.DEFAULT] or { name = "male", scale = 1, clipScale = 1, model = "male" }
	end
	return kinds[kind or kinds.DEFAULT] or kinds[kinds.DEFAULT]
end

-- Every box one kind's body is made of. Pure, so a spec can measure a cub with no cub in the world.
function Body.kindGeometry(kind: string?, config)
	local row = Body.kindRow(kind, config)
	local scale = row.scale
	local zones = {}
	for _, name in ipairs(config.ZONES.ORDER) do
		local spec = config.ZONES[name]
		zones[name] = {
			part = spec.part,
			size = spec.size * scale,
			offset = spec.offset * scale,
			tint = spec.tint,
		}
	end
	return {
		kind = row.name,
		scale = scale,
		clipScale = row.clipScale,
		model = row.model,
		bodySize = config.BODY_SIZE * scale,
		zones = zones,
		-- HOW FAR THIS ANIMAL'S CARCASS HAS TO BE PUT BACK UP (task 120), travelling with the rest
		-- of its geometry because that is what it is. Measured per kind; the derivation and the
		-- numbers are in `Boar.CONFIG.KINDS`. Zero for the male, and zero for every kind with
		-- `KINDS` off, so the grey-box world and the animal Karen accepted are untouched.
		deathLift = row.deathLiftStuds or 0,
	}
end

-- EVERY BAND EDGE AND BOTH RATE RAILS, FOR ONE ANIMAL (task 119, review round 2, finding 1).
--
-- `MAX_RATE`'s own derivation says what it is for: "THE CEILING IS ABOVE EVERYTHING THE GAME CAN ASK
-- FOR, so it never shapes how an animal moves -- it only refuses the absurd rate a mis-measured clip
-- would produce". 2.8 clears everything the MALE can ask for. It does not come close to clearing what
-- a CUB asks for, and the Reviewer measured it: a cub's trot clip carries 10.244 x 0.4372 = 4.479
-- studs/s, so the ceiling is reached at 12.5 while the animal is pushed to `TROT_SPEED` = 18 and runs
-- at `SPRINT_SPEED` = 38 -- rates of 4.02 and 5.05, both clamped, so the feet carried 12.5 and 21.1
-- studs/s while the body travelled 18 and 38. A 30 % and a 45 % slide, on a cub running beside its
-- mother, which is the one thing in this task a player looks straight at.
--
-- SO THE RAILS ARE THE ANIMAL'S OWN, and so are the gait edges. Both are the male's numbers
-- expressed in this animal's stride:
--   * the CEILING is a cadence. The male's legs may be played at up to 2.8 of the clip's own speed;
--     a cub's stride is 0.4372 of his, so the same cadence ceiling in the cub's units is 2.8 /
--     0.4372 = 6.40. That is not a licence to look silly -- it is what keeps the rail ABOVE
--     everything the game can ask for, which is the only promise the number ever made. The FLOOR
--     stays where it is, for the reason written on it below.
--   * a band edge is a WORLD SPEED at which an animal changes gait, and the two that matter are
--     derived from the male's clips (`TROT_FROM` is where the walk clip reaches `WALK_MAX_RATE`). A
--     small animal changes gait at a lower absolute speed -- a piglet is running where its mother
--     trots -- so the edges scale with the stride too. The cub then plays `run` at 2.39 when the
--     sounder is at 18 and 5.05 at a sprint, instead of trotting at a 4x blur.
-- With `BOAR_MODEL` off, and for the male in either state, `clipScale` is 1 and every number here is
-- the literal `MODEL` value: the flag-OFF world is arithmetically untouched.
function Body.gaitBands(clipScale: number?, config)
	local model = config.MODEL
	local scale = if clipScale and clipScale > 0 then clipScale else 1
	return {
		scale = scale,
		walkFrom = model.WALK_FROM * scale,
		trotFrom = model.TROT_FROM * scale,
		runFrom = model.RUN_FROM * scale,
		-- THE FLOOR DOES NOT SCALE AND THE CEILING DOES, and the difference is what each rail is
		-- about. `MIN_RATE` says a clip may not be played so slowly that it reads as slow motion --
		-- a property of the CLIP, the same 0.4 whatever is wearing it; scaling it up put a cub's
		-- floor at 0.915 and clamped the trot clip at the BOTTOM of its own band, where every animal
		-- asks for 0.501. `MAX_RATE` says the opposite thing about the game rather than the clip --
		-- "the ceiling is above everything the game can ask for" is its own derivation -- and what
		-- the game asks of a cub is its stride's worth more.
		minRate = model.MIN_RATE,
		maxRate = model.MAX_RATE / scale,
	}
end

-- The three hit-zone parts (hit-zones design section 4.2). Massless, so the assembly's mass, centre
-- of mass and inertia are untouched and MAX_FORCE / MAX_TORQUE / ACCEL stay correct; CanCollide
-- false, so the collision body is still the plain box and a protruding head cannot catch on the
-- arena's cover blocks; CanQuery true, because being raycastable is their entire purpose; Anchored
-- false, because an anchored part welded into an assembly anchors the whole boar. Damageable is NOT
-- set on them: it belongs to the target root alone, and two damageable instances in one ancestor
-- chain is an ambiguity, not a feature.
local function buildZones(config, trunk: BasePart, geometry): { BasePart }
	local zones = config.ZONES
	local parts = {}
	for _, zone in ipairs(zones.ORDER) do
		-- THE KIND'S OWN BOX, not the male's (task 119). `geometry.zones` is the male's table times
		-- this animal's scale, and with `BOAR_MODEL` off it IS the male's table.
		local spec = geometry.zones[zone]
		local zonePart = Instance.new("Part")
		zonePart.Name = spec.part
		zonePart.Size = spec.size
		zonePart.Color = if zones.ZONE_TINT then spec.tint else config.BODY_COLOR
		zonePart.Material = Enum.Material.SmoothPlastic
		zonePart.TopSurface = Enum.SurfaceType.Smooth
		zonePart.BottomSurface = Enum.SurfaceType.Smooth
		zonePart.Massless = true
		zonePart.CanCollide = false
		zonePart.CanQuery = true
		zonePart.CanTouch = false
		zonePart.Anchored = false
		zonePart.CFrame = trunk.CFrame * CFrame.new(spec.offset)
		zonePart:SetAttribute("HitZone", zone)
		-- The trunk must already be in the DataModel: a WeldConstraint needs both parts parented.
		zonePart.Parent = trunk

		local weld = Instance.new("WeldConstraint")
		weld.Name = "ZoneWeld"
		weld.Part0 = trunk
		weld.Part1 = zonePart
		weld.Parent = zonePart

		table.insert(parts, zonePart)
	end
	return parts
end

-- REGISTERED ONCE, PER SERVER, and then every trunk joins it. `RegisterCollisionGroup` throws if the
-- name is already taken, which is why this is wrapped and latched: `Body.create` runs once per
-- animal and the registration must not.
local collisionGroupReady = false

function Body.useCollisionGroup(part: BasePart, config)
	local rule = config.BOAR_COLLISION
	if rule == nil or rule.ENABLED ~= true then
		return false
	end
	if not collisionGroupReady then
		collisionGroupReady = true
		pcall(function()
			PhysicsService:RegisterCollisionGroup(rule.GROUP)
		end)
		-- THE WHOLE POINT, in one line: the group does not collide with ITSELF. Every other pair --
		-- boar against Default, which is the terrain, the trees and the players -- is untouched.
		pcall(function()
			PhysicsService:CollisionGroupSetCollidable(rule.GROUP, rule.GROUP, false)
		end)
	end
	local ok = pcall(function()
		part.CollisionGroup = rule.GROUP
	end)
	return ok
end

-- Builds one boar body at `position` and returns a handle the Runtime keeps. The Part is parented
-- last, then the zone parts are welded on and the network owner is set: all of those need the part
-- to be in the DataModel.
function Body.create(config, folder: Folder, id: string, position: Vector3, kind: string?)
	local geometry = Body.kindGeometry(kind, config)
	local part = Instance.new("Part")
	part.Name = id
	part.Size = geometry.bodySize
	part.Color = config.BODY_COLOR
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	-- What the weapon reads to know this is a target and which zone was hit (shotgun design
	-- section 6.4). Boar-owned data the boar publishes about itself: Body is still the only writer
	-- of boar Instances, and the weapon only reads. The trunk keeps HitZone = "body", so belly,
	-- flank, rear and brisket -- whatever no zone part covers -- are the default zone.
	part:SetAttribute("Damageable", true)
	part:SetAttribute("HitZone", "body")
	-- WHICH ANIMAL THIS IS, on the trunk (task 123 round 3). The march order is a fact about kinds,
	-- and without this it is a fact nobody outside the server can see -- not in the Explorer, not in
	-- a diagnostic, not in the frame Karen is looking at.
	if kind ~= nil then
		part:SetAttribute("Kind", kind)
	end
	part.Anchored = false
	part.CanCollide = true
	-- ...AND IT DOES NOT SHOVE ITS OWN KIND (task 127 round 3). See `Boar.CONFIG.BOAR_COLLISION`:
	-- the group is registered once and told not to collide with itself, so a file can close up nose
	-- to tail the way a real sounder does. Everything else -- terrain, trunks, the player -- is in
	-- `Default` and still collides exactly as before.
	Body.useCollisionGroup(part, config)
	part.CFrame = CFrame.new(position)

	local attachment = Instance.new("Attachment")
	attachment.Name = "Drive"
	attachment.Parent = part

	local mover = Instance.new("LinearVelocity")
	mover.Name = "Mover"
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	mover.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	mover.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	mover.PlaneVelocity = Vector2.zero
	mover.MaxForce = config.MAX_FORCE
	mover.Parent = part

	local upright = Instance.new("AlignOrientation")
	upright.Name = "Upright"
	upright.Mode = Enum.OrientationAlignmentMode.OneAttachment
	upright.Attachment0 = attachment
	upright.RigidityEnabled = false
	-- HOW FAST THE DRAWN BODY SWINGS TO ITS HEADING (task 123 round 3). The Brain's per-gait turn
	-- cap bounds the STEERING SETPOINT; this bounds the body that chases it, and MEASURED they are
	-- different numbers -- capping the setpoint at 90 deg/s took the mean body turn from 50-85 to
	-- 28-34 deg/s and left the WORST sample near 600, because an `AlignOrientation` at
	-- responsiveness 25 snaps. `PACE.ALIGN_RESPONSIVENESS` is the playtest world's softer value;
	-- with PACE off it is `config.ALIGN_RESPONSIVENESS`, which is the DEV world unchanged.
	local pace = config.PACE
	upright.Responsiveness = if pace ~= nil
			and pace.ENABLED == true
			and pace.ALIGN_RESPONSIVENESS ~= nil
		then pace.ALIGN_RESPONSIVENESS
		else config.ALIGN_RESPONSIVENESS
	upright.MaxTorque = config.MAX_TORQUE
	upright.CFrame = CFrame.new(position)
	upright.Parent = part

	part.Parent = folder

	local zoneParts = buildZones(config, part, geometry)

	-- Only the server may own the boar: a client must not be able to push it. This errors on an
	-- anchored part, which is why the body is unanchored. It is also server-only, so a Studio Play
	-- session running this on the client would throw; the runtime is server code and never requires
	-- this module from a LocalScript.
	if RunService:IsServer() then
		part:SetNetworkOwner(nil)
	end

	-- Each part's own base colour, so a flash can be undone without erasing the zone tint (restoring
	-- everything to BODY_COLOR would silently flatten the boar after its very first hit).
	local baseColor: { [BasePart]: Color3 } = { [part] = part.Color }
	for _, zonePart in ipairs(zoneParts) do
		baseColor[zonePart] = zonePart.Color
	end

	return {
		id = id,
		-- WHICH ANIMAL THIS IS (task 119): "male", "female" or "cub". It decides the boxes above, the
		-- model that is drawn on it and the rate its clips play at, and it never changes after this.
		kind = geometry.kind,
		geometry = geometry,
		part = part,
		attachment = attachment,
		mover = mover,
		upright = upright,
		zoneParts = zoneParts,
		baseColor = baseColor,
		flashFor = 0,
		flashing = false,
		collapsed = false,
		collapsedFor = 0, -- seconds since it died; the carcass anchor reads it
		stillFor = 0, -- seconds it has been at rest; likewise
		bornAt = os.clock(),
		-- THE SKINNED MODEL (task 115), nil until `attachVisual` succeeds and nil for ever with
		-- `BOAR_MODEL` off. Everything above this line is byte-identical in both states.
		visual = nil :: Model?,
		-- name -> how many times `playOneShot` has really played it (task 120).
		soundPlays = {} :: { [string]: number },
		-- name -> { left = seconds of sound still to play, spec = the row it was played from },
		-- which is what `stepCuts` fades and stops (task 120, review round 1 note).
		cutIn = {} :: { [string]: { left: number, spec: any } },
		-- How loud this animal's voice is right now, as a fraction of each cue's own volume: 1 near
		-- a hunter, down to `CROWD.FAR_VOLUME` far from one. Written only by `Body.setVoiceScale`.
		voiceScale = 1,
		mesh = nil :: BasePart?,
		animator = nil :: Animator?,
		tracks = {} :: { [string]: AnimationTrack },
		clip = nil :: string?, -- which clip is playing now
		lastFacing = nil :: Vector3?, -- for the yaw rate, which nothing else measures
		yawRate = 0, -- degrees per second, signed, SMOOTHED. + is a turn to the boar's left
		clipHeldFor = 0, -- seconds the current clip has been playing; the dwell reads it
		-- WHICH CLIP IS FROZEN ON ITS LAST FRAME, or nil. A held clip's speed is deliberately NOT the
		-- clip's rate, so `play` must know not to "correct" it (review round 1, finding 1).
		heldClip = nil :: string?,
		-- The dying twitch (task 116): seconds left of it, and the frame the death clip is held at.
		paddleFor = 0,
		-- Seconds since it went down, which is what moves the death from the fall to the paddle.
		deadFor = 0,
		-- THE CALM REPERTOIRE (task 117): which activity is being drawn, how long it has been
		-- drawn for (so an `enter` clip gets its own length), and the one-shot `exit` clip the one
		-- before it asked for -- the head coming out of the grass, which must finish before the next
		-- activity starts or the animal snaps upright.
		activity = nil :: string?,
		activityDraw = nil :: number?,
		activityFor = 0,
		exitClip = nil :: string?,
		exitFor = 0,
		heldAt = nil :: number?,
		-- The sounds, created with the visual and destroyed with the boar. `sounds` is name -> Sound;
		-- `nextGrunt` and `nextBreath` are countdowns, not clocks, so nothing here reads os.clock.
		sounds = {} :: { [string]: Sound },
		soundFolder = nil :: Instance?,
		-- nil until the first step in the band arms them: see `stepSound`.
		nextGrunt = nil :: number?,
		nextBreath = nil :: number?,
		-- Seconds until the last breath, armed by `playDeath`. nil means not armed.
		lastBreathIn = nil :: number?,
		stepClip = nil :: string?,
		-- THE WARM-UP (task 116 fix round): seconds left of the silent pre-roll that makes the client
		-- fetch every clip and every sound BEFORE the first shot needs one. See `Body.warmAssets`.
		warmFor = 0,
		-- How many times this boar's animation speed has been written. Nothing in the game reads it;
		-- `Runtime:animationOf` hands it to a spec, the way `Runtime:woundOf` hands out a wound.
		rateWrites = 0,
		hitFor = 0, -- seconds of flinch left
		hitFromBehind = false,
	}
end

-- Writes the tick's intent onto the constraints. X/Z only: Y is left to gravity.
function Body.drive(handle, velocity: Vector3, facing: Vector3?)
	handle.mover.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)
	if facing and facing.Magnitude > 1e-6 then
		local flatFacing = Vector3.new(facing.X, 0, facing.Z)
		if flatFacing.Magnitude > 1e-6 then
			handle.upright.CFrame = CFrame.lookAt(Vector3.zero, flatFacing.Unit)
		end
	end
end

function Body.position(handle): Vector3
	return handle.part.Position
end

function Body.velocity(handle): Vector3
	return handle.part.AssemblyLinearVelocity
end

-- The hit flash ---------------------------------------------------------------------------------
-- A 0.25 s red flash is the cheapest unambiguous answer to "did I hit it?" at 100 studs with no
-- sound and no animation, and it needs no new owner: colour on a boar part is already Body's.

-- Starts (or extends) the flash. The colour itself is written by stepFlash, on a transition only.
function Body.setFlash(handle, seconds: number)
	handle.flashFor = math.max(handle.flashFor, seconds)
end

local function paint(handle, flashColor: Color3?)
	handle.part.Color = flashColor or handle.baseColor[handle.part]
	for _, zonePart in ipairs(handle.zoneParts) do
		zonePart.Color = flashColor or handle.baseColor[zonePart]
	end
end

-- Called once per boar per Runtime step. TWO property writes per part per hit -- one when the flash
-- starts, one when it ends -- never one per frame for the whole flash.
function Body.stepFlash(handle, dt: number, config)
	if handle.flashFor <= 0 then
		return
	end
	if not handle.flashing then
		handle.flashing = true
		paint(handle, config.FLASH_COLOR)
	end
	handle.flashFor -= dt
	if handle.flashFor <= 0 then
		handle.flashFor = 0
		handle.flashing = false
		paint(handle, nil)
	end
end

function Body.isFlashing(handle): boolean
	return handle.flashing
end

-- The skinned model ----------------------------------------------------------------------------
-- Task 115, behind `BOAR_MODEL`. One visual child per boar, welded to the trunk, drawn and nothing
-- else. See this file's header for why it can never change a hit.

-- The one MeshPart inside a template, or nil. A template may BE the MeshPart (`kind = "meshpart"`)
-- or contain exactly one (`kind = "model"`); anything else is a different asset than the row
-- describes, and the honest answer to that is the grey box.
local function soleMesh(template: Instance): BasePart?
	if template:IsA("MeshPart") then
		return template
	end
	local found: BasePart? = nil
	for _, descendant in ipairs(template:GetDescendants()) do
		if descendant:IsA("MeshPart") then
			if found ~= nil then
				return nil -- two meshes: not this asset
			end
			found = descendant
		end
	end
	return found
end

-- WHERE THE MODEL SITS ON THE BOX, from the model's OWN measured height and nothing else.
--
-- The animal's feet go on the bottom of the physics box, so the mesh's centre rises by half its own
-- height and falls by half the box's. The boar is 3.257 studs tall and the box is 3, so this is
-- +0.129 -- and if either number ever changes it stays right, which a literal would not. X and Z are
-- zero because the mesh is exactly `BODY_SIZE.Z` long: centring it and aligning its snout with the
-- box's front face are the same placement.
function Body.visualOffset(meshSize: Vector3, bodySize: Vector3): Vector3
	return Vector3.new(0, meshSize.Y / 2 - bodySize.Y / 2, 0)
end

-- Builds the visual child. Returns true if it attached, false if it already had one or the template
-- is not one mesh. It NEVER touches the trunk's attributes, its constraints, its zone parts or its
-- CanQuery: the only thing it changes about the box is whether you can see it.
function Body.attachVisual(handle, template: Instance, config): boolean
	if handle.visual ~= nil then
		return false
	end
	-- A CARCASS IS NEVER DRESSED. If the asset arrives after this boar has already died, its box has
	-- already been rolled by `Body.collapse` -- which rolls precisely because nothing was drawn on it
	-- -- and putting the model on now would lay the death clip down a second time and bury it. It has
	-- CARCASS_SECONDS left and it stays the grey box it died as, which is honest and is the state
	-- every spec before task 115 asserts anyway.
	if handle.collapsed then
		return false
	end
	local mesh = soleMesh(template)
	if mesh == nil then
		return false
	end

	local trunk = handle.part
	local model = Instance.new("Model")
	model.Name = config.MODEL.NAME
	local clone = template:Clone()
	local cloneMesh = soleMesh(clone) :: BasePart
	-- The template may be the MeshPart itself, in which case the clone IS the mesh and there is
	-- nothing to unwrap; when it is a Model, its children move across and the wrapper goes.
	if clone == cloneMesh then
		clone.Parent = model
	else
		for _, child in ipairs(clone:GetChildren()) do
			child.Parent = model
		end
		clone:Destroy()
	end

	-- EVERY BasePart THE TEMPLATE BRINGS, not just the mesh (review round 1, note). `soleMesh` only
	-- refuses a SECOND MeshPart, so any other part an asset carried would have been cloned in
	-- untouched -- queryable, collidable and loose inside the assembly, which would make "NO RAY CAN
	-- SEE IT" false of exactly the thing nobody looked at. RedDeer's model has none today; this makes
	-- the claim true of whatever arrives next.
	local parts: { BasePart } = {}
	if model:IsA("BasePart") then
		table.insert(parts, model)
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	for _, drawn in ipairs(parts) do
		drawn.Massless = true -- the assembly's mass, centre of mass and inertia are untouched
		drawn.CanCollide = false -- the collision body is still the plain box
		drawn.CanQuery = false -- A RAY MUST NEVER MEET THIS: every hit stays on the box and its zones
		drawn.CanTouch = false
		drawn.Anchored = false -- an anchored part welded into an assembly anchors the whole boar
	end
	cloneMesh.CastShadow = true
	-- THE KIND'S OWN BOX (task 119): the offset is worked out from the template's measured height
	-- against the box this animal actually has, so a cub's feet land on a cub's box.
	local boxSize = (handle.geometry and handle.geometry.bodySize) or config.BODY_SIZE
	cloneMesh.CFrame = trunk.CFrame * CFrame.new(Body.visualOffset(cloneMesh.Size, boxSize))
	model.PrimaryPart = cloneMesh
	model.Parent = trunk

	-- EVERY DRAWN PART IS WELDED, not only the mesh (review round 2, note). The loop above forces
	-- `Anchored = false` on all of them -- an anchored part welded into an assembly anchors the whole
	-- boar -- so a part left unwelded would be loose inside it rather than held where it was.
	-- RedDeer's model carries one mesh and nothing else; this makes the next template safe too.
	for _, drawn in ipairs(parts) do
		local weld = Instance.new("WeldConstraint")
		weld.Name = "VisualWeld"
		weld.Part0 = trunk
		weld.Part1 = drawn
		weld.Parent = drawn
	end

	-- ONE RIG, ONE CONTROLLER, AND THE ASSET BRINGS ITS OWN (measured, 2026-10-03).
	-- `InsertService:LoadAsset` hands back `Model > Model "Boar Male RedDeer v3" > { MeshPart,
	-- InitialPoses, AnimationController }` -- Roblox's importer writes that controller, and it has no
	-- Animator. Adding a second controller beside it left TWO on one rig, and then NEITHER stepped:
	-- every track loaded (its `Length` was right), `WeightTarget` went to 1, and `WeightCurrent`,
	-- `TimePosition` and every `Bone.Transform` stayed at zero for ever, on the server and on the
	-- client. A/B'd in a live session against three copies of the same clone: the one that kept the
	-- asset's controller never moved, while a copy with a FRESH controller and one with a Humanoid
	-- both animated identically. So the asset's own is removed first, and there is exactly one after.
	-- It is the same class as the devforum's "a Humanoid disables an AnimationController": two things
	-- claiming one rig is not a fallback, it is a stalemate.
	for _, existing in ipairs(model:GetDescendants()) do
		if existing:IsA("AnimationController") or existing:IsA("Animator") then
			existing:Destroy()
		end
	end

	-- THE RIG ROOT IS THE CONTROLLER'S PARENT, so the controller goes in the Model beside the mesh
	-- whose Bones it drives -- not on the trunk, which has no bones. On the SERVER, so every client
	-- is shown the same animal doing the same thing and no client decides anything.
	local controller = Instance.new("AnimationController")
	controller.Name = "BoarAnimation"
	local animator = Instance.new("Animator")
	animator.Parent = controller
	controller.Parent = model

	-- EXACTLY ONE, ASSERTED RATHER THAN ASSUMED, because the failure mode is silent: a second
	-- controller does not error, it just means nothing ever animates (see the loop above).
	local controllers, animators = 0, 0
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("AnimationController") then
			controllers += 1
		elseif descendant:IsA("Animator") then
			animators += 1
		end
	end
	assert(
		controllers == 1 and animators == 1,
		string.format(
			"Boar.Body.attachVisual: the boar's visual ended up with %d AnimationController(s) and %d"
				.. " Animator(s), not one each. Two on one rig means NEITHER steps and the animal"
				.. " stands still for ever (measured, task 115).",
			controllers,
			animators
		)
	)

	Body.attachSounds(handle, config)

	handle.visual = model
	handle.mesh = cloneMesh
	handle.animator = animator
	handle.tracks = {}
	handle.clip = nil

	-- ...and ask the clients for every clip and every sound NOW, silently, so the first shot does not
	-- pay the fetch (see `Body.warmAssets`: measured at 364 ms of late cry and late flinch). AFTER
	-- the four lines above, not before: `warmAssets` builds tracks through the handle's own animator,
	-- and `handle.tracks = {}` would throw every one of them away again.
	Body.warmAssets(handle, config)

	if config.MODEL.HIDE_BOX then
		-- ONLY NOW, and only because the model is really there: a box hidden before a load that then
		-- failed would be an invisible boar. Transparency changes nothing a ray or a collision can
		-- see -- `CanQuery` and `CanCollide` are untouched above and below this line.
		trunk.Transparency = 1
		for _, zonePart in ipairs(handle.zoneParts) do
			zonePart.Transparency = 1
		end
	end
	return true
end

-- HOW MUCH OF THE FLINCH IS SHOWN AT THIS SPEED. Pure, so the "one motion" claim is assertable with
-- no boar in the world: below `HIT_FULL_BELOW` the animal is not going anywhere and gets the whole
-- clip; above it, only the first `HIT_MOVING_SECONDS` -- the head-and-shoulder jerk -- and then the
-- gait takes over, which is the flinch BLENDING INTO the bolt rather than delaying it.
function Body.flinchWindow(speed: number, config): number
	local model = config.MODEL
	if speed < model.HIT_FULL_BELOW then
		return model.HIT_SECONDS
	end
	return model.HIT_MOVING_SECONDS
end

-- THE ACTIVITY ROW FOR A NAME, or nil. Pure, and a linear walk of five rows -- the table is data and
-- stays data, so nothing here holds a list of activity names (task 117).
function Body.activityRow(name: string?, config)
	local calm = config.CALM
	if name == nil or not (calm and calm.ENABLED) then
		return nil
	end
	for _, row in ipairs(calm.ACTIVITIES) do
		if row.name == name then
			return row
		end
	end
	return nil
end

-- WHICH CLIP A CALM BOAR IS DRAWING, and nil for "let the gait bands answer" (task 117). Pure, so
-- every activity, its enter clip and its exit clip are test cases with no boar in the world.
--
-- ONE ACTIVITY AT A TIME, AND ONE CLIP AT A TIME. The order is: the exit the LAST activity asked for
-- (the head coming out of the grass finishes first, or the animal snaps upright), then the enter for
-- the first `enter` clip's length, then the activity's own loop. A row with no `clip` -- `walk` --
-- answers nil on purpose and the gait bands take it, which is how a calm boar still walks on the
-- clip task 115 measured.
function Body.activityClip(info, config): (string?, number)
	-- NOT CALM, NOT A CALM CLIP -- AND THE EXIT IS INSIDE THAT, WHICH IT WAS NOT (review round 2,
	-- finding 1). A boar that bolts stops being calm on the tick the Brain leaves IDLE, and
	-- `info.activity` goes nil with it. The exit used to be tested FIRST, so a grazing boar that was
	-- startled drew `grazeEnd` -- an in-place eating transition, ground speed 0 -- for its whole
	-- 1.083 s while the body accelerated to `SPRINT_SPEED`: about 25 studs of sliding with its head
	-- in the grass. That is the same fault task 116 measured on the flinch, re-opened and longer.
	-- The three tests below are one statement: a calm clip is for an animal that is still calm.
	if info.activity == nil or info.crippled == true or info.collapsed == true then
		return nil, 1
	end
	local row = Body.activityRow(info.activity, config)
	if row == nil then
		return nil, 1
	end
	-- The exit the LAST activity asked for comes before anything the new one wants, so the head
	-- finishes coming out of the grass -- but only while the animal is still calm.
	if info.exitClip ~= nil and info.exitFor > 0 and Body.hasClip(info.exitClip, config) then
		return info.exitClip, 1
	end
	if row.enter and Body.hasClip(row.enter, config) and info.activityFor < config.MODEL.CLIPS[row.enter].seconds then
		return row.enter, 1
	end
	if row.clip == nil or not Body.hasClip(row.clip, config) then
		return nil, 1
	end
	-- A clip that carries the animal is rated off its own ground speed, exactly as a gait is, so
	-- `digWalk`'s feet do not slide at the speed the row asks the Brain for.
	local clip = config.MODEL.CLIPS[row.clip]
	if clip.groundStudsPerSecond > 0 then
		-- The kind's own stride AND the kind's own rails, exactly as `clipFor`'s gaits read them
		-- (task 119, review round 2).
		local bands = Body.gaitBands(info.clipScale, config)
		return row.clip,
			math.clamp(info.speed / (clip.groundStudsPerSecond * bands.scale), bands.minRate, bands.maxRate)
	end
	return row.clip, 1
end

-- WHICH TWO CLIPS A DEATH IS: the fall, and the paddle that follows it. Derived from the same
-- `DEATH_TO_THE_LEFT` the roll is, so flipping `COLLAPSE_ROLL_DEG` moves all four together.
function Body.deathClips(config): (string, string)
	if config.MODEL.DEATH_TO_THE_LEFT then
		return "deathLeft", "deathPaddleLeft"
	end
	return "deathRight", "deathPaddleRight"
end

-- WHETHER A CLIP CAN ACTUALLY BE PLAYED, which for an authored clip means "has the Director
-- published it yet". Pure, and the one test the whole "if an id is missing the current behaviour
-- stays" promise rests on.
function Body.hasClip(name: string, config): boolean
	local id = config.MODEL.ANIMATION_IDS[name]
	return config.MODEL.CLIPS[name] ~= nil and type(id) == "number" and id > 0
end

-- WHICH CLIP, AND HOW FAST. Pure: no Instance, no service, no state -- `info` in, two values out, so
-- every gait, every flinch and every rate is a test case with no boar in the world.
--
-- THE ORDER IS THE RULE. Death beats everything (a dead animal is not trotting); a flinch beats a
-- gait (it is a quarter of a second and it is the only feedback a hit has now that the box is
-- invisible); then the three gaits by speed; then a turn in place, which is reachable only below
-- `WALK_FROM` because the turn clips are pivots and would skate at any real speed; then idle.
--
-- THE RATE IS `speed / the clip's own measured ground speed`, which is the one arithmetic that makes
-- feet not slide: a planted hoof moves backwards at exactly the speed the body moves forward, so a
-- clip whose hooves travel 2.852 studs/s must play at 1.40 to carry an animal at 4.
-- `tools/boar_prep.py` measured all three off the package itself.
function Body.clipFor(info, config): (string?, number)
	local model = config.MODEL
	local clips = model.CLIPS

	-- A SMALLER ANIMAL COVERS LESS GROUND PER STRIDE, and `clipScale` is that ratio MEASURED rather
	-- than assumed (task 119): `tools/boar_prep.py` reports each animal's own ground speed for every
	-- clip, and the female's came out 0.8553 of the male's and the cub's 0.4372, the same ratio on
	-- all four locomotion clips. So the rate that stops the feet sliding divides by the male's
	-- number times this animal's scale. It is 1 for the male and 1 with `BOAR_MODEL` off.
	local bands = Body.gaitBands(info.clipScale, config)
	local clipScale = bands.scale
	local function gait(name: string): (string, number)
		local clip = clips[name]
		local rate = 1
		if clip and clip.groundStudsPerSecond > 0 then
			rate = info.speed / (clip.groundStudsPerSecond * clipScale)
		end
		return name, math.clamp(rate, bands.minRate, bands.maxRate)
	end

	-- A DEATH AND A FLINCH ARE IMMEDIATE AND IGNORE THE DWELL BELOW. They are the two the player is
	-- waiting to see, and a quarter-second of politeness would read as the animal not reacting.
	if info.collapsed then
		-- ...AND THE DEATH IS TWO CLIPS WHEN THE SECOND ONE EXISTS (task 116 fix round): the fall,
		-- and then the legs paddling and going still. `Death_Paddle_L/R` is authored by
		-- `tools/boar_prep.py` and ends on the same pose the fall ended on, so the hold after it is
		-- the pose the carcass keeps. WITH NO ID PUBLISHED this returns the fall for ever and the
		-- behaviour is exactly what it was -- which is the whole point of asking `ANIMATION_IDS`.
		local fall, paddle = Body.deathClips(config)
		if Body.hasClip(paddle, config) and info.deadFor >= model.CLIPS[fall].seconds then
			return paddle, 1
		end
		return fall, 1
	end

	-- THE BACK END IS GONE: it drags. One clip, looped, rated off its FRONT hooves (the legs doing
	-- the carrying), so the walk the front legs do keeps time with the ground the animal covers.
	-- Karen, 2026-10-03: "can be hit to back part start to do circles with first legs on".
	--
	-- IT SITS AHEAD OF THE FLINCH, so a crippled boar shot again does NOT play `hitFront`/`hitBack`.
	-- That is deliberate and it is the weaker of the two readings (review round 2, note): the drag
	-- is the animal's whole posture and a half-second in-place flinch on top of it would read as the
	-- back legs coming back. Whether a crippled animal should still jerk at a second slug is a feel
	-- question for Karen, queued as 116a.
	if info.crippled and Body.hasClip("crippleDrag", config) then
		local clip = model.CLIPS.crippleDrag
		local rate = 1
		if clip.groundStudsPerSecond > 0 then
			rate = math.clamp(info.speed / (clip.groundStudsPerSecond * clipScale), bands.minRate, bands.maxRate)
		end
		return "crippleDrag", rate
	end
	-- THE FLINCH IS CUT SHORT ON AN ANIMAL THAT IS RUNNING (task 116 fix round). Karen, 2026-10-03:
	-- "body shot is a bit odd". The flinch clips are 0.833 s and they are IN PLACE, and a body hit
	-- bolts the animal to `SPRINT_SPEED * BOLT_KICK` on the same tick -- so for five-sixths of a
	-- second the boar slid across the ground with its legs still, and only then began to run. That
	-- reads as the reaction arriving late even when it did not. A standing animal still gets the
	-- whole clip, because there is nothing for it to fight with.
	if info.hitFor > 0 and info.hitFor > model.HIT_SECONDS - Body.flinchWindow(info.speed, config) then
		return (if info.hitFromBehind then "hitBack" else "hitFront"), 1
	end

	-- A CALM BOAR DRAWS WHAT IT IS DOING (task 117), and only a calm one: the Brain publishes
	-- `activity` while IDLE and nothing else, so a fleeing, wounded or dead animal reaches this with
	-- nil and every line below is the code it was. It sits after the death, the cripple and the
	-- flinch because none of those is a calm animal.
	-- ...AND ONLY WHILE IT IS ACTUALLY STANDING STILL (task 139), which is the LARGEST cause of
	-- Karen's *"sliding"*.
	--
	-- MEASURED over three 150 s runs: 25.1 % of all samples in which a boar was moving faster than
	-- 1 stud/s had no locomotion clip under it at all, and the clips playing instead were `idle`
	-- (2,151 samples) and the GRAZE pair -- `grazeLoop` 2,052, `smell` 377, `grazeStart` 181. This
	-- branch is why: it sits ahead of the gait selection and answers for any calm animal, so a boar
	-- the drive was walking along at 4 studs/s with its head down played the grazing clip and skated.
	-- Grazing is a thing an animal does standing still, and `STILL_SPEED` is that in one number.
	local calmName, calmRate = Body.activityClip(info, config)
	if calmName ~= nil then
		-- THE EXIT STILL PLAYS WHILE IT MOVES, AND NOTHING ELSE CALM DOES (task 139). `grazeEnd` is
		-- the head coming out of the grass: a one-second transition the animal has already begun,
		-- and `boar_calm.spec`'s "plays the EXIT clip before anything the next CALM activity wants"
		-- is right that walking must not cut it off.
		--
		-- EVERY OTHER CALM CLIP IS FOR AN ANIMAL STANDING STILL, and that is the largest cause of
		-- Karen's *"sliding"*: this branch sits ahead of the gait selection and answered for ANY calm
		-- animal, so a boar the drive was walking along at 4 studs/s with its head down played the
		-- grazing LOOP and skated. MEASURED over three 150 s runs: 25.1 % of samples in which a boar
		-- was moving above 1 stud/s had no locomotion clip under it, and the clips playing instead
		-- were `idle` (2,151 samples), `grazeLoop` (2,052), `smell` (377) and `grazeStart` (181).
		-- ...AND A CALM CLIP THAT CARRIES ITS OWN GROUND IS A LOCOMOTION CLIP: `digWalk` is a boar
		-- rooting AS IT WALKS, and `boar_calm.spec` is right to ask for it at 1.9 studs/s. The test
		-- is the clip's own `groundStudsPerSecond`, so it is a fact about the clip and not a list of
		-- names to keep in step.
		local calmRow = clips[calmName]
		local walks = calmRow ~= nil and (calmRow.groundStudsPerSecond or 0) > 0
		local exiting = info.exitClip ~= nil and info.exitFor > 0 and calmName == info.exitClip
		if walks or exiting or info.speed <= model.STILL_SPEED then
			return calmName, calmRate
		end
	end

	local function wanted(): (string, number)
		if info.speed >= bands.runFrom then
			return gait("run")
		end
		if info.speed >= bands.trotFrom then
			return gait("trot")
		end
		if info.speed >= bands.walkFrom then
			return gait("walk")
		end
		-- HYSTERESIS: a turn that is already running keeps running down to TURN_EXIT_DEG, and one
		-- that is not needs TURN_FROM_DEG to start. With one threshold this flipped three times a
		-- second on a standing animal (see `TURN_EXIT_DEG` in Boar.CONFIG.MODEL).
		local turning = info.currentClip == "turnLeft" or info.currentClip == "turnRight"
		local enter = if turning then model.TURN_EXIT_DEG else model.TURN_FROM_DEG
		if math.abs(info.yawRate) >= enter then
			return (if info.yawRate > 0 then "turnLeft" else "turnRight"), 1
		end
		-- HEAD UP (task 118, design section 3.6). It sits AFTER the turn hysteresis because a
		-- boar still swinging round to face the cause is turning -- ALERT's facing goes through
		-- the same `TURN_RATE` slew every other state's does -- and BEFORE `idle` because an
		-- alert animal is standing still and would otherwise draw the resting clip.
		--
		-- `MODEL.ALERT_CLIP` NAMES A ROW IN `CLIPS`, and that string is the whole of this
		-- task's dependency on the drawn animal: with no id published `hasClip` is false, the
		-- boar plays `idle`, and every behaviour in task 118 is unchanged.
		if info.alert and Body.hasClip(model.ALERT_CLIP, config) then
			return model.ALERT_CLIP, 1
		end
		return "idle", 1
	end

	local name, rate = wanted()
	-- THE DWELL. A gait may not replace another gait before the crossfade it started has finished,
	-- because three tracks at partial weight all writing the same bones is what "the head shakes"
	-- looked like. The RATE still follows the speed every frame -- the animal is not held at the
	-- wrong tempo, only at the wrong gait, and only for MIN_CLIP_SECONDS.
	local held = info.currentClip
	if held ~= nil and name ~= held and info.heldFor < model.MIN_CLIP_SECONDS and clips[held] ~= nil then
		local natural = clips[held].groundStudsPerSecond
		if natural > 0 then
			-- ...TIMES THE ANIMAL'S OWN STRIDE, WHICH THIS LINE FORGOT (task 139). Karen, 2026-10-09:
			-- *"I can see some boars are sliding"*.
			--
			-- EVERY OTHER RATE IN THIS FILE divides by `clip.groundStudsPerSecond * clipScale` -- see
			-- `gait` above and the cripple drag. This one divided by the clip alone, so for the whole
			-- `MIN_CLIP_SECONDS` dwell a female played at 0.855 of the rate she needed and a cub at
			-- 0.437 of it, and the dwell is entered on EVERY gait change. The clamps are the bands'
			-- too, for the same reason: `MIN_RATE` does not scale and `MAX_RATE` does.
			return held, math.clamp(info.speed / (natural * clipScale), bands.minRate, bands.maxRate)
		end
		return held, 1
	end
	return name, rate
end

-- The track for one clip name, or nil. Built once per boar per clip, from the id the asset manifest
-- holds; nil when the manifest has no row for it yet, which is the honest state until the ten clips
-- have been published out of Studio (see Assets.KEYS, the boar block).
local function trackFor(handle, name: string, config): AnimationTrack?
	local held = handle.tracks[name]
	if held then
		return held
	end
	local clip = config.MODEL.CLIPS[name]
	local animator = handle.animator
	if clip == nil or animator == nil then
		return nil
	end
	local id = config.MODEL.ANIMATION_IDS[name]
	if id == nil or id <= 0 then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.Name = name
	animation.AnimationId = "rbxassetid://" .. tostring(id)
	animation.Parent = animator
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok or track == nil then
		animation:Destroy() -- an Animation nothing can play is an orphan, not a record
		return nil
	end
	track.Priority = Enum.AnimationPriority.Movement
	track.Looped = clip.looped
	handle.tracks[name] = track
	return track
end

-- Plays `name` if it is not already the one playing. A one-shot clip restarts when it is re-asked
-- for AFTER something else has played, never while it is still running, so a second pellet inside
-- one flinch does not snap the animal back to frame zero.
-- Whether the clip that is ALREADY playing needs its rate rewritten. Pure, because it is the whole
-- of review round 1's finding 1 and the live path cannot be made to show it: a frozen death's two
-- writes landed inside one Heartbeat, so every sample of `AnimationTrack.Speed` read 0 and the pose
-- looked perfectly held while 120 property writes a second replicated to every client.
--
-- A HELD CLIP IS NEVER RE-RATED. Its speed is 0 on purpose while `clipFor` goes on answering the
-- death's nominal rate of 1, so "the speed does not match the rate" is true for ever and is not a
-- reason to write anything.
function Body.shouldAdjustRate(
	heldClip: string?,
	name: string,
	currentSpeed: number,
	wantedRate: number,
	epsilon: number
): boolean
	if heldClip == name then
		return false
	end
	return math.abs(currentSpeed - wantedRate) > epsilon
end

-- How long THIS clip takes to blend in. Pure and exported for the same reason every rule here is.
function Body.fadeFor(name: string, config): number
	local model = config.MODEL
	if name == "hitFront" or name == "hitBack" or name == "deathLeft" or name == "deathRight" then
		return model.HIT_FADE_SECONDS
	end
	return model.FADE_SECONDS
end

local function play(handle, name: string, rate: number, config)
	if handle.clip == name then
		-- A HELD CLIP IS NOT RE-RATED, AND THAT IS THE WHOLE OF REVIEW ROUND 1'S FINDING 1. A frozen
		-- death sits at speed 0 on purpose while `clipFor` goes on answering "deathLeft, rate 1" --
		-- so this branch saw a 1.0 difference and wrote `AdjustSpeed(1)`, and the freeze below wrote
		-- `AdjustSpeed(0)` back, EVERY FRAME, for `CARCASS_SECONDS` and up to `maxBoars` carcasses,
		-- on a server Animator whose every write replicates. The pose held on the server because both
		-- writes land in one Heartbeat; what reached the clients was a non-looped track at its end
		-- being told to run at speed 1, which is how a carcass gets back up.
		--
		-- `heldClip` is the fix at the cause: the rate is the CLIP's business only while the clip is
		-- still playing itself. `Body.shouldFreeze`'s own "a speed already 0" guard stays as the
		-- second line of defence it was always written to be.
		local current = handle.tracks[name]
		if
			current
			and current.IsPlaying
			and Body.shouldAdjustRate(handle.heldClip, name, current.Speed, rate, config.MODEL.RATE_EPSILON)
		then
			current:AdjustSpeed(rate)
			handle.rateWrites += 1
		end
		return
	end
	local track = trackFor(handle, name, config)
	if track == nil then
		return -- no id for this clip yet: the animal holds whatever pose it has
	end
	local previous = handle.clip and handle.tracks[handle.clip]
	if previous and previous.IsPlaying then
		previous:Stop(config.MODEL.FADE_SECONDS)
	end
	-- SET AGAIN, HERE, AND NOT ONLY WHERE THE TRACK WAS BUILT. All ten clips were published with
	-- `Loop = true` -- the Animation Editor's publish dialog does not ask -- and `AnimationTrack`
	-- takes its `Looped` from the asset WHEN THE ASSET ARRIVES, which is after `LoadAnimation`
	-- returns. A value written before that can be overwritten by the load; a value written
	-- immediately before `Play` cannot. A looping death would stand the carcass back up every 1.2
	-- seconds, in front of the player who just shot it.
	track.Looped = config.MODEL.CLIPS[name].looped
	-- A HIT AND A DEATH CUT IN; A GAIT BLENDS. The same reason `clipFor` lets them skip the dwell:
	-- they are the two the player is waiting to see, and 0.15 s of crossfade on the way IN is 0.15 s
	-- of the animal not yet reacting (task 116 fix round -- it was a third of the measured lateness
	-- that was not asset loading).
	track:Play(Body.fadeFor(name, config), 1, rate)
	handle.clip = name
	handle.clipHeldFor = 0
	handle.heldClip = nil -- a new clip is running, not held
end

-- Once per boar per Runtime step, with the flag on. It measures the yaw rate (nothing else does),
-- counts the flinch down, asks `clipFor` and plays the answer.
function Body.stepVisual(handle, dt: number, info, config)
	if handle.hitFor > 0 then
		handle.hitFor = math.max(handle.hitFor - dt, 0)
	end

	if handle.collapsed then
		handle.deadFor += dt
	end

	-- THE ACTIVITY CLOCK (task 117). `info.activity` is the Brain's answer this frame; when it
	-- changes, the one before it gets its `exit` one-shot -- the head coming out of the grass -- and
	-- the new one starts its own clock so its `enter` clip gets exactly its own length.
	if handle.exitFor > 0 then
		handle.exitFor = math.max(handle.exitFor - dt, 0)
	end
	-- A NEW ACTIVITY IS A NEW NAME *OR* A NEW DRAW (review round 3, note). The Brain redraws rather
	-- than repeat a row, but a draw number is what makes "it began again" observable at all, and it
	-- is what would restart a one-shot if the redraw ever landed on the same name anyway.
	if info.activity ~= handle.activity or info.activityDraw ~= handle.activityDraw then
		if info.activity == handle.activity then
			handle.clip = nil -- same activity, new draw: make `play` replay the clip
		end
		handle.activityDraw = info.activityDraw
	end
	if info.activity ~= handle.activity then
		local leaving = Body.activityRow(handle.activity, config)
		-- LEAVING IDLE ALTOGETHER CANCELS THE EXIT (review round 2, finding 1). `info.activity` is
		-- nil for every state but IDLE, so this is "the animal stopped being calm": the flee starts
		-- on its own gait at once instead of finishing a 1.083 s eating transition in place. Moving
		-- from one calm activity to another still arms it, which is what it is for.
		--
		-- IT IS BELT AND BRACES, AND MEASURED TO BE SO (review round 3): `activityClip` refuses every
		-- calm clip when `info.activity` is nil, so deleting these two lines changes nothing any spec
		-- can see. They are kept because leaving a stale exit armed on a running animal is the fault
		-- this round removed, and a second line of defence against it costs two assignments.
		if info.activity == nil then
			handle.exitClip = nil
			handle.exitFor = 0
		elseif leaving and leaving.exit and Body.hasClip(leaving.exit, config) then
			handle.exitClip = leaving.exit
			handle.exitFor = config.MODEL.CLIPS[leaving.exit].seconds
		end
		handle.activity = info.activity
		handle.activityFor = 0
	else
		handle.activityFor += dt
	end

	-- The warm-up ends here, in the one function that is already called once per boar per step.
	if handle.warmFor > 0 then
		handle.warmFor -= dt
		if handle.warmFor <= 0 then
			Body.coolAssets(handle, config)
		end
	end

	-- THE YAW RATE, from the trunk's own facing. Two facings and the time between them is all a turn
	-- is, and taking it here keeps the Brain untouched -- it is told nothing new and asked nothing
	-- new. The signed angle about +Y is positive when the look direction swings to the boar's left.
	--
	-- AND IT IS SMOOTHED, because ONE frame's delta is not a turn rate. Measured on standing boars
	-- over three 7-second windows: the raw per-frame value swung -120..+173 deg/s on an animal whose
	-- body speed was 0.0 -- a physics body under an AlignOrientation never sits perfectly still --
	-- and the turn clip chased every crossing of its threshold. The exponential constant is derived
	-- from dt rather than assumed, so a frame-rate change does not change how much smoothing there is.
	local facing = info.facing
	if facing and dt > 0 then
		local flat = Vector3.new(facing.X, 0, facing.Z)
		if flat.Magnitude > 1e-6 then
			flat = flat.Unit
			local previous = handle.lastFacing
			if previous then
				local radians = math.atan2(previous.X * flat.Z - previous.Z * flat.X, previous:Dot(flat))
				local raw = math.deg(radians) / dt
				local alpha = 1 - math.exp(-dt / config.MODEL.YAW_SMOOTH_SECONDS)
				handle.yawRate += (raw - handle.yawRate) * alpha
			end
			handle.lastFacing = flat
		end
	end

	handle.clipHeldFor += dt

	if handle.visual == nil then
		return
	end

	local name, rate = Body.clipFor({
		collapsed = handle.collapsed,
		deadFor = handle.deadFor,
		crippled = info.crippled == true,
		alert = info.alert == true,
		activity = handle.activity,
		activityFor = handle.activityFor,
		exitClip = handle.exitClip,
		exitFor = handle.exitFor,
		hitFor = handle.hitFor,
		hitFromBehind = handle.hitFromBehind,
		speed = info.speed,
		yawRate = handle.yawRate,
		currentClip = handle.clip,
		heldFor = handle.clipHeldFor,
	}, config)
	if name then
		play(handle, name, rate, config)
	end

	-- A DEATH HOLDS ITS LAST FRAME. Letting the track stop would snap the animal back to its rest
	-- pose -- standing up, inside a carcass that is lying on its side -- so the clip is frozen at the
	-- end instead of ended.
	if handle.collapsed and handle.heldClip == nil then
		local track = handle.tracks[name or ""]
		if track and track.IsPlaying then
			-- THE WINDOW HAS TO BE AT LEAST A FRAME WIDE (review round 1, note). `HOLD_EPSILON` alone
			-- is 0.03 s, under two frames at 60 fps, and `stepVisual` is handed the raw Heartbeat
			-- `dt` -- `DT_CLAMP` is applied to the Brain, not here. One long frame steps
			-- `TimePosition` clean past `length`, the non-looped track STOPS, and the carcass snaps
			-- to its rest pose standing up: the exact fault the freeze exists to prevent. So the
			-- window is whichever is larger, the fixed epsilon or the distance this clip covers in
			-- this frame. Once frozen the speed is 0, so the second term vanishes.
			local reach = Body.freezeReach(track.Speed, dt, config.MODEL.HOLD_EPSILON)
			if Body.shouldFreeze(track.TimePosition, track.Length, track.Speed, reach) then
				track:AdjustSpeed(0)
				handle.rateWrites += 1
				handle.heldAt = track.TimePosition
				handle.paddleFor = config.MODEL.PADDLE_SECONDS
				-- ONCE PER KILL. From here `play` leaves this track alone and this branch is skipped,
				-- so the death's speed is written exactly as often as `shouldFreeze` says it is.
				handle.heldClip = name
			end
		end
	elseif
		handle.collapsed
		and handle.paddleFor > 0
		and not Body.hasClip(select(2, Body.deathClips(config)), config)
	then
		-- THE DYING TWITCH, AND IT IS THE FALLBACK NOW (task 116 fix round). Scrubbing the held death
		-- clip's own tail is what a script can do when there is no clip of an animal paddling; once
		-- `Death_Paddle_L/R` is published there IS one, the branch above plays it, and this is
		-- skipped entirely. Until then it is exactly what it was.
		--
		-- The one thing in this file that writes a property every frame on purpose, and it is
		-- BOUNDED: `PADDLE_SECONDS` of it, once per kill, then the track is put back on its held
		-- frame and never touched again.
		local track = handle.tracks[handle.heldClip or ""]
		local heldAt = handle.heldAt
		if track and heldAt then
			local elapsed = config.MODEL.PADDLE_SECONDS - handle.paddleFor
			track.TimePosition = heldAt + Body.paddleOffset(elapsed, config)
		end
		handle.paddleFor = math.max(handle.paddleFor - dt, 0)
		if handle.paddleFor <= 0 and track and heldAt then
			track.TimePosition = heldAt -- back on the held frame, and silent from here
		end
	end
end

-- HOW WIDE THE FREEZE WINDOW IS THIS FRAME. Exported and pure because the spec used to assert
-- `math.max` rather than this repository's code (review round 2, note), and because it is the one
-- number standing between a death clip and the rest pose.
--
-- `HOLD_EPSILON` alone is 0.03 s, under two frames at 60 fps, and `stepVisual` is handed the RAW
-- Heartbeat `dt` -- `DT_CLAMP` is applied to the Brain, not here. One long frame steps `TimePosition`
-- clean past `length`, the non-looped track STOPS, and the carcass snaps to its rest pose. So the
-- window is whichever is larger: the fixed epsilon, or the distance this clip covers in this frame.
--
-- ON A BAD HITCH IT OVERSHOOTS, and that is the trade taken knowingly (review round 2, note): a
-- quarter-second frame would freeze the death a quarter-second short of its end rather than at it.
-- The clip is 1.21 s and its last frames are an animal settling, so a frame early is invisible; a
-- frame late is the animal standing back up. Once frozen the speed is 0 and the second term vanishes.
function Body.freezeReach(speed: number, dt: number, epsilon: number): number
	return math.max(epsilon, math.abs(speed) * dt)
end

-- Whether a one-shot track has reached its end and should be frozen there. Pure, because the branch
-- above is otherwise untestable: `AnimationTrack.Length` is 0 until the asset has loaded from the
-- network, and no spec in this repository can load one -- so a death that snapped back to the rest
-- pose would be a bug nothing could catch. A zero length means "not loaded yet", never "already
-- over"; a speed already 0 means it was frozen on an earlier frame.
function Body.shouldFreeze(timePosition: number, length: number, speed: number, epsilon: number): boolean
	if length <= 0 or speed == 0 then
		return false
	end
	return timePosition >= length - epsilon
end

-- THE DYING TWITCH'S SHAPE, AND IT IS NOT WHAT WAS ASKED FOR. Karen, 2026-10-03: "can fall on side
-- and legs moving like in real life". Isolated legs cannot be moved: `Bone.Transform` is the
-- Animator's output and a script's write to it does not survive one frame (MEASURED, 2026-10-04:
-- 0 of 122 samples on the server, 0 of 121 on the client), and this package has no death-throes clip.
-- What IS writable is the held death track's own `TimePosition` -- scrubbing it moved the hind hoof
-- 0.432 studs and the head 1.641 -- so the body twitches back over the last of its fall and settles.
-- A WHOLE-BODY twitch, then, not paddling legs. The research note says so and so does the report.
--
-- Pure, and negative-only: the scrub never runs the clip PAST its end, where a non-looped track
-- stops and the animal stands back up (task 115's own fault, and it stays fixed).
function Body.paddleOffset(elapsed: number, config): number
	local model = config.MODEL
	if elapsed >= model.PADDLE_SECONDS or elapsed < 0 then
		return 0
	end
	-- Decays linearly to nothing, so the animal goes still rather than stopping mid-twitch.
	local decay = 1 - elapsed / model.PADDLE_SECONDS
	return -model.PADDLE_SPAN * decay * math.abs(math.sin(elapsed * model.PADDLE_HZ * math.pi * 2))
end

-- The flinch. Called by the runtime on the tick a pellet lands, from the same payload the flash and
-- the wound are charged from, so the clip and the damage can never disagree about which hit this is.
function Body.setHit(handle, seconds: number, fromBehind: boolean)
	handle.hitFor = math.max(handle.hitFor, seconds)
	handle.hitFromBehind = fromBehind
	-- A new hit RESTARTS the flinch, which is what makes a second pellet readable: the clip is
	-- re-asked for from frame zero rather than carrying on from where the first one left it.
	if handle.clip == "hitFront" or handle.clip == "hitBack" then
		handle.clip = nil
	end
end

-- The sound of a boar ---------------------------------------------------------------------------
-- Task 116. Karen, 2026-10-03: "I just need that once they walk you can hear (as example hunter
-- waiting and hear something comming and then boars are visible running, walking ect)".
--
-- EVERY SOUND IS A `Sound` INSIDE THE TRUNK, which makes it positional for free -- the boar already
-- has one part that everything is welded to, so there is no new owner, no remote and no client-side
-- mixer, and every client hears the same animal from the right direction. `Body` creates them
-- because `Body` is the only writer of a boar's Instances, and it destroys them with the boar
-- because they are its children.
--   Sound        https://create.roblox.com/docs/reference/engine/classes/Sound
--   RollOffMode  https://create.roblox.com/docs/reference/engine/enums/RollOffMode
-- Every id, volume, range and interval is in `Boar.CONFIG.SOUND`: a sound Karen does not like is one
-- number in a table, not a code change, and a library id that is moderated away is swapped the same
-- way.

-- One configured Sound. `audibleStuds` is the distance past which it is gone; `NEAR_STUDS` is where
-- it stops getting louder, and a row may name its OWN `nearStuds` instead (task 123). A spec row
-- carries either one `id` or a list of `ids` to pick between; the first of a list is the one it is
-- born with, and `playOneShot` re-picks on every play.
--
-- WHY A ROW NEEDS ITS OWN PLATEAU. `InverseTapered` falls as `RollOffMinDistance / distance`, so the
-- plateau sets the FAR tail and not only the near one -- and one shared number cannot make a pig's
-- voice carry 120 studs while a hoof on soil dies at 40. Karen, 2026-10-05: *"I hear only when it;s
-- close inaf to me if it's far away I don't hear"*.
local function makeSound(name: string, spec, config, parent: Instance): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = Body.soundUri(if spec.ids then spec.ids[1] else spec.id)
	sound.Volume = spec.volume
	sound.RollOffMode = Enum.RollOffMode[config.SOUND.ROLL_OFF]
	sound.RollOffMinDistance = spec.nearStuds or config.SOUND.NEAR_STUDS
	sound.RollOffMaxDistance = spec.audibleStuds
	-- SOFTER IS A FILTER, NOT ONLY A VOLUME (task 120). Karen, 2026-10-04: "sound has to be lover
	-- and softer". Turning a sample down makes it distant; taking the top off it makes it SOFT, and
	-- the high end is where a wet impact's slap lives. One EqualizerSoundEffect per sound that asks
	-- for one, built with the sound and never touched again -- the gains are data in
	-- `Boar.CONFIG.SOUND`, so retuning them is three numbers and no code.
	-- HOW HEAVY THE ANIMAL SOUNDS, without touching how fast it walks (task 129). Karen, 2026-10-05:
	-- *"and walking sound sounds like horse we need animal not horse"* -- `pitch` on a FOOTSTEP row
	-- is that dial, and it is a `PitchShiftSoundEffect` because `PlaybackSpeed` would drag the
	-- cadence with it and slide the feet. `Octave` is a multiplier on the frequency, so the row's
	-- number means the same thing it always did; a row without one gets no effect at all.
	--   https://create.roblox.com/docs/reference/engine/classes/PitchShiftSoundEffect
	--
	-- ONE-SHOTS ARE NOT TOUCHED: their `pitch` is the CENTRE of `Body.jitteredPitch`, applied to
	-- `PlaybackSpeed` by `playOneShot`, and a squeal has no stride to keep.
	if spec.steps == true and spec.pitch ~= nil and spec.pitch ~= 1 then
		local shift = Instance.new("PitchShiftSoundEffect")
		shift.Name = "Heavier"
		shift.Octave = spec.pitch
		shift.Parent = sound
	end
	if spec.eq then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.Name = "Softer"
		eq.LowGain = spec.eq.low
		eq.MidGain = spec.eq.mid
		eq.HighGain = spec.eq.high
		eq.Parent = sound
	end
	sound.Parent = parent
	return sound
end

-- A PITCH THAT IS NEVER TWICE THE SAME. The Director's brief: +-8%, so a grunt heard three times in
-- ten seconds does not read as a loop. It is a pure function of a roll so a spec can check the band
-- without a Random.
function Body.jitteredPitch(roll: number, jitter: number): number
	return 1 + (roll * 2 - 1) * jitter
end

-- WHICH FOOTSTEP LOOP A SPEED ASKS FOR, and how fast to play it. Pure: the same `speed / the clip's
-- own ground speed` rule the gaits use, so the steps keep time with the legs instead of drifting
-- against them. nil means silence -- a standing boar makes no footsteps, which is most of what a
-- grazing one is doing.
-- A BARE NUMBER IS AN ASSET ID; ANYTHING WITH A SCHEME IS ALREADY A URI (task 126). The footsteps
-- are now `rbxasset://` engine assets -- Roblox's OWN files, which ship inside the engine -- and
-- gluing "rbxassetid://" in front of one makes a path that resolves to nothing and plays silence with
-- no error. Every other row in `SOUND` is still a number and goes through the same line unchanged.
function Body.soundUri(id: any): string
	local text = tostring(id)
	return if string.find(text, "://", 1, true) then text else "rbxassetid://" .. text
end

function Body.stepSoundFor(speed: number, config): (string?, number)
	local sound = config.SOUND
	local model = config.MODEL
	if speed < sound.STEPS.MIN_SPEED then
		return nil, 0
	end
	local gait = if speed >= model.RUN_FROM then "run" elseif speed >= model.TROT_FROM then "trot" else "walk"
	local spec = sound.STEPS[gait]
	-- THE RATE IS THE STRIDE AND NOTHING ELSE, and task 126 broke that by multiplying the gait's
	-- `pitch` into it (fixed in task 129). `PlaybackSpeed` is cadence AND pitch at once, so a 0.7
	-- "make it heavier" dial also played the footfalls at 70 % of the speed the legs move at -- the
	-- feet slid, which is the exact fault `baseSpeed` exists to prevent, and it put the rate below
	-- `MIN_RATE` at a walk. The timbre is applied where it belongs instead: a
	-- `PitchShiftSoundEffect` on the loop itself (see `makeSound`), which shifts the pitch and
	-- leaves the speed alone.
	--   https://create.roblox.com/docs/reference/engine/classes/PitchShiftSoundEffect
	return gait, math.clamp(speed / spec.baseSpeed, model.MIN_RATE, model.MAX_RATE)
end

-- A VOICE PER KIND (task 120) ---------------------------------------------------------------------
-- Karen, 2026-10-04: "pown should sqeen differen, male differen female different". Three pure
-- functions, so a spec can ask what a cub's death squeal sounds like with no cub in the world.
--
-- `voiceRow` is nil whenever the voice is off, the kind is unknown, or the cue is not one of the
-- animal's own (hooves, breath and the sniff are the world, not the animal) -- and every caller
-- then gets exactly what it got before task 120.
function Body.voiceRow(name: string, kind: string?, config)
	local voice = config.SOUND.VOICE
	if voice == nil or voice.ENABLED ~= true or kind == nil then
		return nil
	end
	if voice.APPLIES[name] ~= true then
		return nil
	end
	return voice[kind]
end

-- The CENTRE of the pitch jitter for one cue on one animal: the kind's own voice, or 1 (or the
-- row's own `pitch`, which is how the sniff stays high for every kind).
function Body.voicePitch(name: string, kind: string?, spec, config): number
	local row = Body.voiceRow(name, kind, config)
	if row == nil or row.pitch == nil then
		return spec.pitch or 1
	end
	return row.pitch
end

-- Which samples this animal has for this cue: its own list when it has one, else the row's.
function Body.voiceIds(name: string, kind: string?, spec, config)
	local row = Body.voiceRow(name, kind, config)
	if row and row[name] then
		return row[name]
	end
	return spec.ids
end

-- HOW LOUD A VOICE IS AT `distance` FROM THE NEAREST HUNTER (task 120). 1 inside `FAR_STUDS`, down
-- to `FAR_VOLUME` over the `FAR_FADE_STUDS` beyond it, and never below. Pure, and it is a fraction
-- of the sound's own volume rather than a replacement for it -- the roll-off still does its work;
-- this is the extra step that stops a sounder at the far end of the field being an event.
function Body.farScale(distance: number?, config): number
	local crowd = config.SOUND.CROWD
	if crowd == nil or crowd.ENABLED ~= true or distance == nil then
		return 1
	end
	if distance <= crowd.FAR_STUDS then
		return 1
	end
	local over = (distance - crowd.FAR_STUDS) / math.max(crowd.FAR_FADE_STUDS, 1e-6)
	return math.max(crowd.FAR_VOLUME, 1 - over * (1 - crowd.FAR_VOLUME))
end

-- WHAT A HUNTER HEARS OF ONE SOUND AT `distance` (task 120). Karen, 2026-10-04: "and when its verry
-- fal I cant hear them / when close only".
--
-- `RollOffMode.InverseTapered` is inverse close in and tapers to silence at the row's own
-- `audibleStuds`, so the level goes as `NEAR_STUDS / d` and the MAX is a hard cut. That is the model
-- these numbers were chosen with: it is not Roblox's exact blend -- nothing in this toolchain can
-- read back the level a client renders, and that is said in the request -- but it has the two
-- properties that matter, that the plateau sets the far tail and that nothing is heard past the max.
function Body.heardAt(spec, distance: number, config): number
	if distance >= spec.audibleStuds then
		return 0
	end
	local near = config.SOUND.NEAR_STUDS
	if distance <= near then
		return spec.volume
	end
	return spec.volume * (near / distance)
end

-- A CUT SOUND'S VOLUME, `left` seconds before it is stopped. Full until the fade begins, then down
-- to nothing in a straight line, so a squeal ENDS instead of being chopped. Pure.
function Body.cutVolume(left: number, spec): number
	local fade = spec.fade or 0
	if fade <= 0 or left >= fade then
		return spec.volume
	end
	return spec.volume * math.max(left, 0) / fade
end

-- THE ONE-SHOT SOUNDS, name to config row, in ONE place: `attachSounds` builds them from this and
-- `Body.warmAssets` puts their volumes back from it, so a sound cannot exist in one and not the
-- other -- which is how `lastBreath` would go quiet after a warm-up nobody updated.
function Body.oneShotSpecs(sound)
	return {
		hit = sound.HIT,
		cry = sound.CRY,
		death = sound.DEATH,
		lastBreath = sound.LAST_BREATH,
		fall = sound.FALL,
		grunt = sound.GRUNTS,
		breath = sound.BREATH,
		sniff = sound.SNIFF, -- task 117: the head comes up
	}
end

-- Builds every sound this boar will ever make, once, beside the model. Called from `attachVisual`,
-- so sound rides `BOAR_MODEL` with everything else this task adds.
function Body.attachSounds(handle, config)
	local sound = config.SOUND
	if not sound.ENABLED or handle.soundFolder ~= nil then
		return false
	end
	local folder = Instance.new("Folder")
	folder.Name = sound.FOLDER
	folder.Parent = handle.part

	-- The three footstep loops are built once and only one is ever playing.
	for _, gait in ipairs({ "walk", "trot", "run" }) do
		local steps = makeSound("steps_" .. gait, sound.STEPS[gait], config, folder)
		steps.Looped = true
		handle.sounds["steps_" .. gait] = steps
	end
	-- The one-shots. One Sound per kind, replayed, rather than an Instance per squeal.
	for name, spec in pairs(Body.oneShotSpecs(sound)) do
		handle.sounds[name] = makeSound(name, spec, config, folder)
	end

	handle.soundFolder = folder
	return true
end

-- Plays one of the one-shots, picking an id from a list when the spec has several and jittering the
-- pitch. `rng` is passed in so nothing here owns a Random (the Runtime has one, seeded).
function Body.playOneShot(handle, name: string, spec, config, rng: Random)
	local sound = handle.sounds[name]
	if sound == nil then
		return false
	end
	-- OFF BY DATA (task 120). Karen, 2026-10-04: "I think we can remove hit sound for now". The
	-- Sound still exists, with its id and its volume: this is the only line that keeps it quiet, so
	-- bringing a cue back is one word in `Boar.CONFIG.SOUND` and nothing else.
	if spec.enabled == false then
		return false
	end
	-- THE ANIMAL'S OWN VOICE, where the cue is one (task 120): its kind's samples and its kind's
	-- pitch. With `VOICE` off, or for a cue that is not a voice, both answer exactly what the row
	-- said before.
	local ids = Body.voiceIds(name, handle.kind, spec, config)
	if ids then
		sound.SoundId = Body.soundUri(ids[rng:NextInteger(1, #ids)])
	end
	-- THE VOLUME IS SET ON EVERY PLAY, which is what makes the warm-up safe: a sound at volume 0 is
	-- one nobody is listening to, so `coolAssets` may stop it, and this is the line that says "this
	-- one is real". It is also one less place for a retuned volume to be stale.
	-- ...AND QUIETER WHEN THE ANIMAL IS FAR (task 120). `voiceScale` is written by the Runtime,
	-- which is the only thing that knows where the hunters are; it is 1 until something sets it.
	sound.Volume = spec.volume * (handle.voiceScale or 1)
	-- A spec may carry its own `pitch` as the CENTRE of the jitter: the sniff is the same breath
	-- sample played high (task 117), and that is a number in the table rather than a second asset.
	-- Task 120: a kind's voice is the same dial, chosen by which animal is making the noise.
	sound.PlaybackSpeed = Body.voicePitch(name, handle.kind, spec, config)
		* Body.jitteredPitch(rng:NextNumber(), config.SOUND.PITCH_JITTER)
	-- A CUT CUE ENDS ON TIME (task 120): "when die last sqeek need short one". The countdown is
	-- stepped in `stepSound`, which runs for a carcass too, and the fade is `Body.cutVolume`.
	if spec.cut then
		handle.cutIn[name] = { left = spec.cut, spec = spec }
	end
	-- HOW MANY TIMES THIS BOAR HAS REALLY MADE THIS NOISE (task 120). `warmAssets` plays every sound
	-- at volume 0 and does NOT come through here, so this counts the ones somebody can hear -- which
	-- is what lets a spec say "the hit sound played exactly once" across a hit and the death that
	-- followed it 25 seconds later.
	handle.soundPlays[name] = (handle.soundPlays[name] or 0) + 1
	sound:Play()
	return true
end

-- THE SILENT PRE-ROLL, AND WHY A SHOT FELT LATE (task 116 fix round) -------------------------------
-- Karen, 2026-10-03: "body shot is a bit odd now feels late hit and odd". MEASURED on the client
-- that fired, at RenderStepped, from the frame the mouse went down:
--   t = 0.000  the click
--   t = 0.069  the server's answer lands: the `hit` Sound plays (it was already `IsLoaded`), the
--              `cry` Sound is told to play -- and `cry.IsLoaded` is FALSE and its `TimePosition`
--              stays 0.00; the flinch track exists with `WeightCurrent` 0.00 and `TimePosition` 0.00
--   t = 0.433  the cry finally loads and starts, and the flinch's TimePosition finally moves
--   t = 0.568  the flinch reaches full weight
-- So the animal's answer to being shot was 364 MS LATE and only fully drawn at 568 ms, and none of
-- that is logic: it is the CLIENT fetching an audio and an animation asset it had never been asked
-- for. A boar that is never shot never plays its cry, so the first boar anybody shoots pays for it.
--
-- WHAT THIS ACTUALLY DOES, AND WHAT IT DOES NOT (task 126 round 4, after the Reviewer caught the
-- comment claiming more than the code delivers).
--
-- THE CLIPS ARE STILL ASKED FOR THE OLD WAY: every animation is played at WEIGHT 0 when the coat
-- goes on and stopped `WARM_SECONDS` later. An animation plays on the SERVER too -- the Animator is
-- the server's -- so that fetch is real and the flinch is no longer 568 ms late.
--
-- THE SOUNDS ARE NOT WARMED ON ANY CLIENT, and nothing here can warm them. `PreloadAsync` is a
-- CLIENT call (https://create.roblox.com/docs/reference/engine/classes/ContentProvider): run from
-- the server it fills the SERVER's cache, which no listener hears from. The measured 364 ms-late
-- cry is therefore still there for the first boar anybody shoots in a fresh session, and saying
-- otherwise in a comment is worse than the lateness.
--
-- WHY IT IS STILL CALLED: it costs one spawned pcall per boar and it does warm the server's own
-- copy, which is where `Body` reads `IsLoaded` from; and it replaced a loop that PLAYED all eleven
-- sounds at volume 0, which held eleven voices per animal and made the sound counts unreadable (the
-- Director's smoke read 67 playing sounds with 34 boars out and the steady state was 3).
--
-- WHAT WOULD ACTUALLY FIX IT is a client-side preload of the boar's sound ids -- one small owner on
-- the client, given the id list the server already has. That is a task, not a comment, and it is
-- queued in `TASKS.md` under before-release rather than implied here.
--
-- IT IS BOUNDED AND IT IS SILENT: once per boar, weight 0 and volume 0 throughout, stopped by the
-- same `stepVisual` that draws everything else. A real play always sets its own volume first, so
-- the cool-down below can tell a warm sound from one that is really being heard.
function Body.warmAssets(handle, config)
	if handle.animator == nil then
		return false
	end
	for name in pairs(config.MODEL.CLIPS) do
		local track = trackFor(handle, name, config)
		if track then
			track:Play(0, 0, 0) -- no fade, NO WEIGHT, no speed: fetched, and invisible
		end
	end
	-- THE SOUNDS ARE FETCHED, NOT PLAYED (task 126 round 2).
	--
	-- THE DIRECTOR'S SMOKE COUNTED 67 PLAYING SOUNDS WITH 34 BOARS OUT, against task 123's 1-3, and
	-- read it as the footsteps escaping the voice ration. THEY HAD NOT -- measured, the steady state
	-- is `steps=1` and `total<=3` across a whole 125 s run, and the spike was THIS LOOP: at the
	-- sampled instant, 8 of EVERY ONE of the eleven sound names, which is eight freshly-released
	-- boars times eleven sounds and the signature of a pre-roll rather than of hooves. Task 126 made
	-- it visible by moving the footsteps to `rbxasset://` engine assets, which load on the same frame
	-- where a marketplace id was still loading and so not yet `IsPlaying`.
	--
	-- They were SILENT (`Volume = 0`), so this was never audible -- but a silent Sound still holds a
	-- voice, and a count nobody can read is a measurement nobody can use.
	--
	-- `ContentProvider:PreloadAsync` IS THE THING THAT EXISTS FOR THIS: it fetches an asset without
	-- playing it, which is the whole of what the pre-roll was for ("make the client fetch every clip
	-- and every sound BEFORE the first shot needs one" -- the comment this replaces). It is spawned
	-- because it YIELDS, and `warmAssets` is called from `Body.create` on a server step.
	--   https://create.roblox.com/docs/reference/engine/classes/ContentProvider#PreloadAsync
	-- The ANIMATION half above still plays its tracks: a track is not an asset request, it is how a
	-- clip's own asset is resolved, and nothing in this round measured it as a cost.
	local list = {}
	for _, sound in pairs(handle.sounds) do
		table.insert(list, sound)
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)
	handle.warmFor = config.MODEL.WARM_SECONDS
	return true
end

-- Ends the pre-roll. A track the animal is really playing and a sound somebody can really hear are
-- both left alone -- the volume is the test, and every real play sets it (see `playOneShot` and
-- `stepSound`).
function Body.coolAssets(handle, config)
	for name, track in pairs(handle.tracks) do
		if name ~= handle.clip and track.IsPlaying then
			track:Stop(0)
		end
	end
	local specs = Body.oneShotSpecs(config.SOUND)
	for name, sound in pairs(handle.sounds) do
		if sound.Volume == 0 then
			sound:Stop()
			local spec = specs[name] or config.SOUND.STEPS[string.gsub(name, "^steps_", "")]
			if spec then
				sound.Volume = spec.volume
			end
		end
	end
	handle.warmFor = 0
end

-- IT DIES OUT LOUD, AND THEN IT STOPS MAKING NOISE. One call, so the order can never come apart:
-- the scream and the body landing together (a boar goes down and hits the ground in one movement),
-- every looping sound cut because a carcass has no footsteps, and the last breath ARMED rather than
-- played -- it lands `LAST_BREATH.delay` seconds later, which is the Director's "death = the scream
-- plus a breath" and is the only sound a dead boar ever makes.
-- `squeal` IS THE WORLD'S PERMISSION (task 120): false when two squeals are already sounding
-- somewhere, which is the cap that stops a sounder shot into from stacking five of them. The rest of
-- the death -- the loops cut, the fall's own row -- happens either way.
function Body.playDeath(handle, config, rng: Random, squeal: boolean?)
	if handle.soundFolder == nil then
		return false
	end
	local sound = config.SOUND
	if squeal ~= false then
		Body.playOneShot(handle, "death", sound.DEATH, config, rng)
	end
	Body.playOneShot(handle, "fall", sound.FALL, config, rng) -- off by data since task 120
	Body.silenceLoops(handle)
	-- ARMED ONLY IF IT EXISTS. Karen, 2026-10-04: one short squeal and nothing after it.
	if sound.LAST_BREATH.enabled ~= false then
		handle.lastBreathIn = sound.LAST_BREATH.delay
	end
	return true
end

-- EVERY CUT CUE, A STEP CLOSER TO ITS END (task 120). Called every step, carcass or not, because
-- the one sound a dead boar makes is a squeal that has to STOP: Karen, 2026-10-04, "when die last
-- sqeek need short one". The fade is `Body.cutVolume`, so it ends rather than being chopped.
function Body.stepCuts(handle, dt: number)
	for name, row in pairs(handle.cutIn) do
		row.left -= dt
		local sound = handle.sounds[name]
		if row.left <= 0 then
			handle.cutIn[name] = nil
			if sound then
				sound:Stop()
			end
		elseif sound then
			sound.Volume = Body.cutVolume(row.left, row.spec) * (handle.voiceScale or 1)
		end
	end
end

-- Once per boar per step, with the flag on. Footsteps follow the gait; grunts and breaths are
-- countdowns, so a sounder does not grunt in chorus.
--
-- `voice` IS WHAT THE CROWD ALLOWS THIS ANIMAL THIS STEP (task 120, one key per LAYER since task
-- 123), from the Runtime, which is the only thing that knows what else is making a noise:
-- `steps = false` for an animal that is not one of its herd's or the world's few footstep voices,
-- `breath = false` likewise, `grunt = false` while the sounder's grunt slot is taken or the world's
-- mutter ceiling is full. nil means "no limits", which is what every caller written before task 120
-- passes. Returns which one-shot it played, so the Runtime can book the slot it just used.
function Body.stepSound(handle, dt: number, speed: number, config, rng: Random, voice): string?
	if handle.soundFolder == nil then
		return nil
	end
	local sound = config.SOUND
	Body.stepCuts(handle, dt)

	-- FOOTSTEPS. Exactly one loop plays, and a standing boar is silent.
	local gait, rate = Body.stepSoundFor(speed, config)
	-- ONE OR TWO SETS OF HOOVES, NOT TWENTY: animals running together are one sound with one
	-- position to a listener fifty studs away, and twenty copies of one sample is the "to many
	-- noise" Karen asked not to have. The rest go silent exactly as a standing boar does.
	if voice and voice.steps == false then
		gait = nil
	end
	if gait ~= handle.stepClip then
		if handle.stepClip then
			local was = handle.sounds["steps_" .. handle.stepClip]
			if was then
				was:Stop()
			end
		end
		handle.stepClip = gait
		if gait then
			local now = handle.sounds["steps_" .. gait]
			if now then
				now.Volume = sound.STEPS[gait].volume -- real, not warm: see `Body.coolAssets`
				now.PlaybackSpeed = rate
				now:Play()
			end
		end
	elseif gait then
		local now = handle.sounds["steps_" .. gait]
		-- The same reason `play` has a RATE_EPSILON: a property write is not free, and a 2 % change
		-- in a footstep's pitch is not audible.
		if now and math.abs(now.PlaybackSpeed - rate) > config.MODEL.RATE_EPSILON then
			now.PlaybackSpeed = rate
		end
		-- ...AND A LOOP SOMETHING ELSE STOPPED COMES BACK (task 120, review round 1 note). The
		-- silent pre-roll plays every sound at volume 0 and `coolAssets` STOPS the ones it finds
		-- there -- a boar whose gait did not change across that moment then ran silently for ever,
		-- because the branch above only plays on a CHANGE. Measured in a spec: six boars all
		-- fleeing, one audible loop. It matters more since this task, because a sounder's hooves
		-- are now one or two animals's (`Boar.hasVoice`): a silent one could be the whole herd's voice,
		-- which is the opposite of "hear them coming".
		if now and not now.IsPlaying then
			now.Volume = sound.STEPS[gait].volume
			now:Play()
		end
	end

	if handle.collapsed then
		-- A dead boar neither grunts nor breathes -- it has exactly one sound left, and it is the
		-- one `playDeath` armed. A countdown, not a clock: nothing in this file reads os.clock.
		-- (Task 120: `LAST_BREATH` is off by data, so this arms nothing until it comes back.)
		if handle.lastBreathIn ~= nil then
			handle.lastBreathIn -= dt
			if handle.lastBreathIn <= 0 then
				handle.lastBreathIn = nil
				Body.playOneShot(handle, "lastBreath", sound.LAST_BREATH, config, rng)
			end
		end
		return nil
	end

	-- GRUNTS WHILE IT WALKS OR TROTS, BREATH WHILE IT RUNS. Never both: since task 123 the two
	-- bands MEET at `MODEL.RUN_FROM` rather than leaving a gap, and the `if ... elseif` below gives
	-- the meeting point to the grunt, so no speed can satisfy both and sound like two animals.
	--
	-- IT USED TO BE "CALM GRUNTS, BREATH WHILE WORKING", with the grunt band ending at 6 studs/s --
	-- grazing pace. Karen, 2026-10-05: *"when they cross road or they close they don't make any pig
	-- sound besides walking"*. A crossing herd moves at 4 to 18 studs/s, so it grunted at none of
	-- the speeds anybody ever watches it at.
	--
	-- THE FIRST INTERVAL IS ARMED, NOT FIRED. A countdown starting at zero means every boar grunts on
	-- the frame its coat goes on -- and a sounder is five boars, so they would grunt in chorus and
	-- read as one loud animal. nil means "not armed yet": the first tick in the band picks a random
	-- interval and plays nothing.
	local played: string? = nil
	local function countdown(left: number?, row): number?
		if left == nil then
			return rng:NextNumber(row.MIN_SECONDS, row.MAX_SECONDS)
		end
		local next_ = left - dt
		if next_ > 0 then
			return next_
		end
		local name = if row == sound.GRUNTS then "grunt" else "breath"
		-- SKIPPED, NEVER QUEUED (task 120): a cue that loses its slot simply does not happen, and
		-- the animal waits for its next interval like one that had nothing to say. Queuing it would
		-- move the chorus a second later instead of removing it.
		--
		-- THE LAYER'S OWN NAME IS THE KEY (task 123). It was `name ~= "grunt" or ...`, which let
		-- BREATH through unrationed -- and twenty animals working is twenty breaths, measured at 8
		-- of the 31 sounds playing at once in the Forest Test. Reading `voice[name]` means a third
		-- layer would add a row to the ration and no branch here.
		local allowed = voice == nil or voice[name] ~= false
		-- THE GRUNT IS AN EVENT, NOT AN INTERVAL, SINCE TASK 123 ROUND 6. Karen asked for "one hriu
		-- sound per flack when they are close", which is an approach and not a clock, so
		-- `Runtime:_stepApproachGrunts` owns it and this countdown must not fire one as well -- two
		-- owners for one cue is how a herd ends up muttering again. `ON_APPROACH = false` gives the
		-- interval mode back and costs nothing else.
		if name == "grunt" and sound.GRUNTS.ON_APPROACH == true then
			allowed = false
		end
		if allowed and Body.playOneShot(handle, name, row, config, rng) then
			played = name
		end
		return rng:NextNumber(row.MIN_SECONDS, row.MAX_SECONDS)
	end

	if speed <= sound.GRUNTS.MAX_SPEED then
		handle.nextGrunt = countdown(handle.nextGrunt, sound.GRUNTS)
	elseif speed >= sound.BREATH.MIN_SPEED then
		handle.nextBreath = countdown(handle.nextBreath, sound.BREATH)
	end
	return played
end

-- HOW LOUD THIS ANIMAL'S VOICE IS, from the Runtime, which is the only thing that knows where the
-- hunters are. One number, read by `playOneShot` on the next cue it plays (task 120).
function Body.setVoiceScale(handle, scale: number)
	handle.voiceScale = scale
end

-- Silences everything that loops. Called when the boar dies: a carcass has no footsteps.
function Body.silenceLoops(handle)
	for name, sound in pairs(handle.sounds) do
		if string.sub(name, 1, 6) == "steps_" then
			sound:Stop()
		end
	end
	handle.stepClip = nil
end

-- The collapse ----------------------------------------------------------------------------------
-- The boar dies: the drive stops, the upright constraint lets go so the body TOPPLES instead of
-- standing dead, one angular nudge makes it fall on a side rather than balance, and the two
-- attributes the rest of the world reads change together -- Damageable false (the weapon's targetOf
-- now finds no damageable root, so further pellets are a miss and no second kill can be counted)
-- and Carcass true (a marker Milestone 1.7 can read without requiring Boar). An attribute rather
-- than a CollectionService tag because the harness compares attributes and does not compare tags.
-- `config` IS THE WOUND'S OWN TABLE, as it has been since task 28; `full` is the WHOLE config and
-- is appended, never inserted (task 120, review round 1 note). It is here for one question -- is
-- there a death clip to fall with? -- and a caller that does not hand it over gets no lift, which
-- is the pre-120 behaviour and the safe way round: a carcass that was never raised is a carcass
-- lying where the clip left it, and a carcass raised with nothing to pull it down floats.
function Body.collapse(handle, config, full)
	if handle.collapsed then
		return
	end
	handle.collapsed = true

	handle.mover.PlaneVelocity = Vector2.zero
	handle.mover.Enabled = false
	handle.upright.Enabled = false

	local part = handle.part
	part:SetAttribute("Damageable", false)
	part:SetAttribute("Carcass", true)
	-- CanCollide stays true, so the carcass lies on the ground instead of falling through it.
	--
	-- THE TOPPLE, AND WHO DOES IT. ONE CFrame write, at the moment of death -- not the per-frame
	-- CFrame writing the design forbids (boar-ai design section 6), and not the design's
	-- ApplyAngularImpulse either, which was measured here and either does nothing or launches the
	-- animal (the number is in Boar.CONFIG.WOUND.COLLAPSE_ROLL_DEG, with the measurements). Rolling
	-- the body past its tipping angle lets GRAVITY lay it on its side, which is the visible
	-- difference between "dropped" and "paused" that this step exists for.
	--
	-- ...BUT ONLY WHEN THERE IS NOTHING DRAWN ON IT (Karen, 2026-10-03: "yes synced in when died").
	-- The death CLIP already lays the animal down, in the RIG'S OWN FRAME, from standing to flat. Roll
	-- the box as well and the rotation happens TWICE: measured on a real kill, the head finished
	-- 1.20 studs BELOW the ground, the ear 1.93 below, and the hooves 0.85 ABOVE it -- a boar buried
	-- upside down with its legs in the air, which is exactly what her screenshot shows. Measured again
	-- with the same carcass's box put back upright: the lowest bone sat at -0.02 of the ground and the
	-- animal lay on its flank. So when a visual exists the clip does the falling and the box holds
	-- still, and when it does not the box topples exactly as it has since Task 28.
	if handle.visual == nil then
		part.CFrame = part.CFrame * CFrame.Angles(0, 0, math.rad(config.COLLAPSE_ROLL_DEG))
		return
	end

	-- ...AND WHEN THERE IS SOMETHING DRAWN, THE CLIP THAT DOES THE FALLING OVERSHOOTS ON A SMALL
	-- ANIMAL (task 120). Karen, 2026-10-04: "when shoot cub he is gone not remaining". The cub was
	-- not gone -- its box was there, anchored, `Carcass = true` -- it was drawn 1.01 studs UNDER THE
	-- FLOOR, which on an animal 1.44 studs tall is the whole of it. All three kinds play the male's
	-- clips, a KeyframeSequence's bone translations are absolute studs, and the fall is built out of
	-- child-bone translations: on geometry baked smaller every one of them is too long and they all
	-- point down. The numbers, the measurements and why this is data and not a formula are in
	-- `Boar.CONFIG.KINDS`.
	--
	-- ONE WRITE, AT THE MOMENT OF DEATH, exactly like the roll above and for the same reason: the
	-- design forbids per-frame CFrame writing on the boar (boar-ai design section 6), and the pose
	-- this corrects is the one the carcass is HELD on for CARCASS_SECONDS. What a player sees is
	-- the dying animal start its fall a body-height high instead of ending it under the ground --
	-- downward motion masking a lift, rather than a carcass that has to pop up at rest.
	--
	-- ...AND ONLY WHERE THERE IS A FALL TO CANCEL (review round 1, note). The lift gives back what
	-- the DEATH CLIP takes off a smaller rig, so with no death clip published there is nothing to
	-- give back -- and lifting anyway would hang a cub's carcass 1.009 studs in the air for
	-- `CARCASS_SECONDS`. Task 116 supports that world on purpose (`stepVisual`'s twitch branch, and
	-- `boar_shot.spec`'s `withIds({})`), so it is asked rather than assumed.
	local lift = (handle.geometry and handle.geometry.deathLift) or 0
	local falls = full ~= nil and Body.hasClip((Body.deathClips(full)), full)
	if lift > 0 and falls then
		Body.liftDrawn(handle, lift)
	end
end

-- Moves everything drawn up by `studs` and leaves it welded. A WeldConstraint stores the relative
-- transform at the moment it is ENABLED, so the offset is changed by disabling it, moving the part
-- and enabling it again -- all inside this one call, so no physics step runs while anything is
-- loose and nothing can drift. Every weld is off before any part moves, so the order of the drawn
-- parts cannot matter.
--
-- IT TOUCHES NOTHING A SHOT READS. The trunk, its attributes, its zone parts, its CanQuery and its
-- CanCollide are not in this function: the hit boxes stay exactly where the animal died, which is
-- also why a lifted carcass is no harder to hit (and `Damageable` is already false by here anyway).
function Body.liftDrawn(handle, studs: number)
	local model = handle.visual
	if model == nil or studs <= 0 then
		return
	end
	local parts: { BasePart } = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	local function welds(drawn: BasePart, enabled: boolean)
		for _, child in ipairs(drawn:GetChildren()) do
			if child:IsA("WeldConstraint") then
				child.Enabled = enabled
			end
		end
	end
	for _, drawn in ipairs(parts) do
		welds(drawn, false)
	end
	local up = Vector3.new(0, studs, 0)
	for _, drawn in ipairs(parts) do
		drawn.CFrame = drawn.CFrame + up
	end
	for _, drawn in ipairs(parts) do
		welds(drawn, true)
	end
end

-- WHETHER A CARCASS HAS COME TO REST. Pure, because the branch it guards is the difference between a
-- dead boar that stays where it fell and one a player can shove around the field, and a spec cannot
-- make a physics body topple on command. `linear` is the whole velocity vector because the backstop
-- has to know whether the body is still FALLING; `angular` is a magnitude because no axis of a spin
-- matters differently.
function Body.carcassIsStill(linear: Vector3, angular: number, config): boolean
	return linear.Magnitude < config.CARCASS_STILL_LINEAR and angular < config.CARCASS_STILL_ANGULAR
end

-- Whether to anchor NOW. Two ways in, and the second is a backstop rather than the normal path:
--   * it has been still for CARCASS_STILL_SECONDS -- what every carcass that is left alone does;
--   * or CARCASS_ANCHOR_BY_SECONDS have passed since it died AND it is not falling, so somebody
--     leaning on it cannot keep it pushable for ever.
-- It takes `linear` and not the angular speed: a carcass still SPINNING at the backstop is one
-- something is doing to it, and stopping it is the point. Falling is the only thing worth waiting
-- for, because a boar frozen in mid-air is a worse bug than one that can be nudged.
function Body.shouldAnchorCarcass(linear: Vector3, stillFor: number, collapsedFor: number, config): boolean
	if stillFor >= config.CARCASS_STILL_SECONDS then
		return true
	end
	if collapsedFor >= config.CARCASS_ANCHOR_BY_SECONDS and linear.Y > -config.CARCASS_FALLING_Y then
		return true
	end
	return false
end

-- Called once per boar per Runtime step, in BOTH flag states, until the carcass is anchored. The
-- push it closes is not the model's: the grey box has been shoveable since Task 28 and nobody had
-- walked into one.
--
-- ANCHORING IS THE WHOLE FIX, and it is the one thing a walking character cannot move. It does not
-- touch `CanQuery`, `CanCollide`, `Damageable`, `HitZone` or the welded zone parts, so a dead boar
-- answers a ray exactly as it did before; and it happens only AFTER the body has stopped, so the
-- carcass still falls, still topples with the flag off, and still lands on the ground.
function Body.stepCarcass(handle, dt: number, config)
	if not handle.collapsed or handle.part.Anchored then
		return
	end
	handle.collapsedFor += dt
	local linear = handle.part.AssemblyLinearVelocity
	local angular = handle.part.AssemblyAngularVelocity.Magnitude
	if Body.carcassIsStill(linear, angular, config) then
		handle.stillFor += dt
	else
		handle.stillFor = 0
	end
	if Body.shouldAnchorCarcass(linear, handle.stillFor, handle.collapsedFor, config) then
		-- The assembly goes with it: the zone parts are welded to this part, so anchoring the trunk
		-- anchors the whole dead boar, model included.
		handle.part.Anchored = true
	end
end

-- Destroys the Part (its Attachment, constraints and zone parts go with it). It never destroys the
-- folder or anything it did not create (CLAUDE.md rule 7).
function Body.destroy(handle)
	if handle.part.Parent then
		handle.part:Destroy()
	end
end

return Body
