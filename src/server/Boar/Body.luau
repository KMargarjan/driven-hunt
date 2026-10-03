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
		bornAt = os.clock(),
		-- THE SKINNED MODEL (task 115), nil until `attachVisual` succeeds and nil for ever with
		-- `BOAR_MODEL` off. Everything above this line is byte-identical in both states.
		visual = nil :: Model?,
		mesh = nil :: BasePart?,
		animator = nil :: Animator?,
		tracks = {} :: { [string]: AnimationTrack },
		clip = nil :: string?, -- which clip is playing now
		lastFacing = nil :: Vector3?, -- for the yaw rate, which nothing else measures
		yawRate = 0, -- degrees per second, signed. + is a turn to the boar's left
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

	cloneMesh.Massless = true -- the assembly's mass, centre of mass and inertia are untouched
	cloneMesh.CanCollide = false -- the collision body is still the plain box
	cloneMesh.CanQuery = false -- A RAY MUST NEVER MEET THIS: every hit stays on the box and its zones
	cloneMesh.CanTouch = false
	cloneMesh.Anchored = false -- an anchored part welded into an assembly anchors the whole boar
	cloneMesh.CastShadow = true
	cloneMesh.CFrame = trunk.CFrame * CFrame.new(Body.visualOffset(cloneMesh.Size, config.BODY_SIZE))
	model.PrimaryPart = cloneMesh
	model.Parent = trunk

	local weld = Instance.new("WeldConstraint")
	weld.Name = "VisualWeld"
	weld.Part0 = trunk
	weld.Part1 = cloneMesh
	weld.Parent = cloneMesh

	-- THE RIG ROOT IS THE CONTROLLER'S PARENT, so the controller goes in the Model beside the mesh
	-- whose Bones it drives -- not on the trunk, which has no bones. On the SERVER, so every client
	-- is shown the same animal doing the same thing and no client decides anything.
	local controller = Instance.new("AnimationController")
	controller.Name = "BoarAnimation"
	local animator = Instance.new("Animator")
	animator.Parent = controller
	controller.Parent = model

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

	if info.collapsed then
		return (if model.DEATH_TO_THE_LEFT then "deathLeft" else "deathRight"), 1
	end
	if info.hitFor > 0 then
		return (if info.hitFromBehind then "hitBack" else "hitFront"), 1
	end
	if info.speed >= model.RUN_FROM then
		return gait("run")
	end
	if info.speed >= model.TROT_FROM then
		return gait("trot")
	end
	if info.speed >= model.WALK_FROM then
		return gait("walk")
	end
	if math.abs(info.yawRate) >= model.TURN_FROM_DEG then
		return (if info.yawRate > 0 then "turnLeft" else "turnRight"), 1
	end
	return "idle", 1
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
local function play(handle, name: string, rate: number, config)
	if handle.clip == name then
		local current = handle.tracks[name]
		if current and current.IsPlaying and math.abs(current.Speed - rate) > config.MODEL.RATE_EPSILON then
			current:AdjustSpeed(rate)
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
	local facing = info.facing
	if facing and dt > 0 then
		local flat = Vector3.new(facing.X, 0, facing.Z)
		if flat.Magnitude > 1e-6 then
			flat = flat.Unit
			local previous = handle.lastFacing
			if previous then
				local radians = math.atan2(previous.X * flat.Z - previous.Z * flat.X, previous:Dot(flat))
				handle.yawRate = math.deg(radians) / dt
			end
			handle.lastFacing = flat
		end
	end

	if handle.visual == nil then
		return
	end

	local name, rate = Body.clipFor({
		collapsed = handle.collapsed,
		hitFor = handle.hitFor,
		hitFromBehind = handle.hitFromBehind,
		speed = info.speed,
		yawRate = handle.yawRate,
	}, config)
	if name then
		play(handle, name, rate, config)
	end

	-- A DEATH HOLDS ITS LAST FRAME. Letting the track stop would snap the animal back to its rest
	-- pose -- standing up, inside a carcass that is lying on its side -- so the clip is frozen at the
	-- end instead of ended.
	if handle.collapsed then
		local track = handle.tracks[name or ""]
		if track and track.IsPlaying then
			if Body.shouldFreeze(track.TimePosition, track.Length, track.Speed, config.MODEL.HOLD_EPSILON) then
				track:AdjustSpeed(0)
			end
		end
	end
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
	-- The topple. ONE CFrame write, at the moment of death -- not the per-frame CFrame writing the
	-- design forbids (boar-ai design section 6), and not the design's ApplyAngularImpulse either,
	-- which was measured here and either does nothing or launches the animal (the number is in
	-- Boar.CONFIG.WOUND.COLLAPSE_ROLL_DEG, with the measurements). Rolling the body past its tipping
	-- angle lets GRAVITY lay it on its side, which is the visible difference between "dropped" and
	-- "paused" that this step exists for.
	part.CFrame = part.CFrame * CFrame.Angles(0, 0, math.rad(config.COLLAPSE_ROLL_DEG))
end

-- Destroys the Part (its Attachment, constraints and zone parts go with it). It never destroys the
-- folder or anything it did not create (CLAUDE.md rule 7).
function Body.destroy(handle)
	if handle.part.Parent then
		handle.part:Destroy()
	end
end

return Body
