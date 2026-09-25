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
-- shot. tests/server/boar_zones.spec.luau fires nine real rays from outside for exactly that reason.
--
-- Design: docs/design/boar-ai.md (section 6), docs/design/hit-zones.md (sections 4, 7)
-- Note:   docs/research/2026-09-24-boar-ai.md, docs/research/2026-09-25-hit-zones.md
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
