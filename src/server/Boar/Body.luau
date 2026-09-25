-- Boar.Body: the only writer of a boar's Instances. It creates the Part, its Attachment and its two
-- constraints, sets the server as network owner, drives them each tick, and is the only thing that
-- destroys them. Nothing else in the codebase may touch Workspace.Boars.
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
--
-- Design: docs/design/boar-ai.md (section 6)
-- Note:   docs/research/2026-09-24-boar-ai.md
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

-- Builds one boar body at `position` and returns a handle the Runtime keeps. The Part is parented
-- last, then the network owner is set: both calls need the part to be in the DataModel.
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
	-- of boar Instances, and the weapon only reads. ROADMAP 1.5 splits the box into parts, each
	-- carrying its own HitZone, and nothing in the weapon changes.
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

	-- Only the server may own the boar: a client must not be able to push it. This errors on an
	-- anchored part, which is why the body is unanchored. It is also server-only, so a Studio Play
	-- session running this on the client would throw; the runtime is server code and never requires
	-- this module from a LocalScript.
	if RunService:IsServer() then
		part:SetNetworkOwner(nil)
	end

	return {
		id = id,
		part = part,
		attachment = attachment,
		mover = mover,
		upright = upright,
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

-- Destroys the Part (its Attachment and constraints go with it). It never destroys the folder or
-- anything it did not create (CLAUDE.md rule 7).
function Body.destroy(handle)
	if handle.part.Parent then
		handle.part:Destroy()
	end
end

return Body
