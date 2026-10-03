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

-- The three hit-zone parts (hit-zones design section 4.2). Massless, so the assembly's mass, centre
-- of mass and inertia are untouched and MAX_FORCE / MAX_TORQUE / ACCEL stay correct; CanCollide
-- false, so the collision body is still the plain box and a protruding head cannot catch on the
-- arena's cover blocks; CanQuery true, because being raycastable is their entire purpose; Anchored
-- false, because an anchored part welded into an assembly anchors the whole boar. Damageable is NOT
-- set on them: it belongs to the target root alone, and two damageable instances in one ancestor
-- chain is an ambiguity, not a feature.
local function buildZones(config, trunk: BasePart): { BasePart }
	local zones = config.ZONES
	local parts = {}
	for _, zone in ipairs(zones.ORDER) do
		local spec = zones[zone]
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

-- Builds one boar body at `position` and returns a handle the Runtime keeps. The Part is parented
-- last, then the zone parts are welded on and the network owner is set: all of those need the part
-- to be in the DataModel.
function Body.create(config, folder: Folder, id: string, position: Vector3)
	local part = Instance.new("Part")
	part.Name = id
	part.Size = config.BODY_SIZE
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
	part.Anchored = false
	part.CanCollide = true
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
	upright.Responsiveness = config.ALIGN_RESPONSIVENESS
	upright.MaxTorque = config.MAX_TORQUE
	upright.CFrame = CFrame.new(position)
	upright.Parent = part

	part.Parent = folder

	local zoneParts = buildZones(config, part)

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
	cloneMesh.CFrame = trunk.CFrame * CFrame.new(Body.visualOffset(cloneMesh.Size, config.BODY_SIZE))
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

	handle.visual = model
	handle.mesh = cloneMesh
	handle.animator = animator
	handle.tracks = {}
	handle.clip = nil

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

	local function gait(name: string): (string, number)
		local clip = clips[name]
		local rate = 1
		if clip and clip.groundStudsPerSecond > 0 then
			rate = info.speed / clip.groundStudsPerSecond
		end
		return name, math.clamp(rate, model.MIN_RATE, model.MAX_RATE)
	end

	-- A DEATH AND A FLINCH ARE IMMEDIATE AND IGNORE THE DWELL BELOW. They are the two the player is
	-- waiting to see, and a quarter-second of politeness would read as the animal not reacting.
	if info.collapsed then
		return (if model.DEATH_TO_THE_LEFT then "deathLeft" else "deathRight"), 1
	end
	if info.hitFor > 0 then
		return (if info.hitFromBehind then "hitBack" else "hitFront"), 1
	end

	local function wanted(): (string, number)
		if info.speed >= model.RUN_FROM then
			return gait("run")
		end
		if info.speed >= model.TROT_FROM then
			return gait("trot")
		end
		if info.speed >= model.WALK_FROM then
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
			return held, math.clamp(info.speed / natural, model.MIN_RATE, model.MAX_RATE)
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
	track:Play(config.MODEL.FADE_SECONDS, 1, rate)
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
				-- ONCE PER KILL. From here `play` leaves this track alone and this branch is skipped,
				-- so the death's speed is written exactly as often as `shouldFreeze` says it is.
				handle.heldClip = name
			end
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

-- The collapse ----------------------------------------------------------------------------------
-- The boar dies: the drive stops, the upright constraint lets go so the body TOPPLES instead of
-- standing dead, one angular nudge makes it fall on a side rather than balance, and the two
-- attributes the rest of the world reads change together -- Damageable false (the weapon's targetOf
-- now finds no damageable root, so further pellets are a miss and no second kill can be counted)
-- and Carcass true (a marker Milestone 1.7 can read without requiring Boar). An attribute rather
-- than a CollectionService tag because the harness compares attributes and does not compare tags.
function Body.collapse(handle, config)
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
