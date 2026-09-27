--!strict
-- Camera.Viewmodel: the only writer of the first-person weapon model under workspace.CurrentCamera.
--
-- It CLONES the Tool's Handle and never touches the original: ServerScriptService.Weapon.Hardware
-- stays the only writer of Tool Instances (docs/design/shotgun.md section 3.1). The clone is local,
-- unreplicated, and rebuilt only when the source part changes identity OR its children change --
-- never per frame.
--
-- CanQuery = false on every part, and it is not optional: workspace.CurrentCamera is a child of
-- Workspace, so a client raycast -- including this system's own occlusion cast -- can hit a part
-- parented to the camera. The symptom would be a camera glued 1.2 studs behind the head.
--   Viewmodel pattern, the technique only and no code copied:
--   https://devforum.roblox.com/t/fps-using-viewmodels-the-improved-version-parts-2-out-of-3/1129877
--   (rokoblox5, 2021; source 4 of docs/research/2026-09-24-shotgun.md and section 7 D of the camera
--   design). That post uses the deprecated SetPrimaryPartCFrame; this uses PivotTo.
--
-- Design: docs/design/camera.md (sections 3.2, 5.5)
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mode = require(script.Parent.Mode)
-- SHARED, AND ONLY FOR THE GEOMETRY OF THE BARRELS (task 92): `Shotgun.barrelMuzzleOffset`. This
-- module still knows nothing about weapon STATE -- it clones a Handle and poses it.
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Viewmodel = {}

local source: (() -> BasePart?)? = nil
local model: Model? = nil
local builtFrom: BasePart? = nil

-- THE CLONE GOES STALE WHEN THE SOURCE'S CHILDREN CHANGE, and since Task 76 that happens in a live
-- game: the server upgrades a gun handed out before the mesh loaded (`Weapon.Hardware.upgrade`), so
-- the Handle loses ten welded parts and gains a `Model`. Rebuilding only on `builtFrom ~= handle`
-- would leave the FIRST-PERSON gun wearing the parts fallback while the third-person gun wore the
-- mesh -- two looks for one gun, which is exactly what cloning the Handle exists to prevent.
--
-- Watched rather than told: this file knows nothing about what the gun is made of, only that its
-- clone is a copy of something that changed. One flag, cleared when the rebuild happens.
local childWatchers: { RBXScriptConnection } = {}
local stale = false

-- THE NAMES THIS MODULE LOOKS FOR ON THE CLONE (task 90). `Sight` is written by
-- `ServerScriptService.Weapon.Hardware` and comes across with the clone; `Bead` is the parts gun's
-- own bright piece; `SightBead` is the one thing this module ADDS, and it adds it only when the gun
-- it cloned has no bead of its own.
local SIGHT_NAME = "Sight"
local BEAD_NAME = "Bead"
local MARKER_NAME = "SightBead"
-- `Muzzle` is written by `Weapon.Hardware` beside `Sight` and comes across with the clone (task 92);
-- `ViewmodelFill` is the one light this module adds.
local MUZZLE_NAME = "Muzzle"
local FILL_NAME = "ViewmodelFill"
-- THE PIECE THAT HINGES (task 96). `Weapon.Hardware` wears the gun as two welded meshes since the
-- break-action reload, and this is the one the barrels live in; `SpentShell`/`FreshShell` are the
-- only other things this module ever adds to the clone.
local BARRELS_NAME = "Barrels"
local SPENT_NAME = "SpentShell"
local FRESH_NAME = "FreshShell"

local stats = { sightMissing = 0, rebuilds = 0, parts = 0, breaksDrawn = 0, shellsDrawn = 0 }

-- WHAT THE WEAPON SAYS ABOUT ITS OWN RELOAD, handed in by the camera every frame (task 96). The
-- server owns the reload and its clock; this module only draws it. `spent` is how many barrels were
-- fired, so only those throw a shell -- the thing a player notices if it is wrong.
local reload = { open = false, spent = 0 }
local openedAt: number? = nil
local barrelsLocal: CFrame? = nil

function Viewmodel.setReload(state: { open: boolean, spent: number }?)
	local next_ = state or { open = false, spent = 0 }
	if next_.open and not reload.open then
		openedAt = os.clock() -- the rising edge: the shells' own clock starts here
	elseif not next_.open then
		openedAt = nil
	end
	reload = { open = next_.open == true, spent = math.clamp(next_.spent or 0, 0, 2) }
end

function Viewmodel.reloadState()
	return { open = reload.open, spent = reload.spent, openedAt = openedAt }
end

function Viewmodel.setSource(fn: (() -> BasePart?)?)
	source = fn
	if not fn then
		Viewmodel.clear()
	end
end

-- So a spec can borrow the source and PUT THE LIVE ONE BACK. `CameraBoot` sets it exactly once at
-- boot -- "the Handle of the Tool in the local character" -- so `setSource(nil)` does not restore
-- it, it ends it: every later frame of that session would draw no viewmodel at all, and any ADS
-- screenshot after would be of nothing. The same seam `Weapon.Hardware.getTemplateProvider` has,
-- and for the same reason (Task 74 review round 1, finding 3 one layer over).
function Viewmodel.getSource(): (() -> BasePart?)?
	return source
end

-- Nil unless the viewmodel is actually in the camera (design section 9.2 item 6). The clone is kept
-- behind this so it is not rebuilt every time the player dips out of aim, but "is there a viewmodel"
-- means "is one on screen".
function Viewmodel.current(): Model?
	return if model and model.Parent then model else nil
end

function Viewmodel.clear()
	if model then
		model:Destroy()
		model = nil
	end
	barrelsLocal = nil -- the next clone reads its own barrels' rest pose (task 96)
	builtFrom = nil
	for _, connection in ipairs(childWatchers) do
		connection:Disconnect()
	end
	childWatchers = {}
	stale = false
end

-- WHERE THE GUN SAYS ITS BEAD IS, in the clone's own frame, or nil when it carries no `Sight`.
-- `PrimaryPart` is the cloned Handle and `WorldPivot` is never written, so an attachment's CFrame is
-- already relative to the model's pivot -- which is exactly the frame `Mode.aimOffset` wants.
function Viewmodel.sight(): CFrame?
	local made = model
	local clone = made and made.PrimaryPart
	local attachment = clone and clone:FindFirstChild(SIGHT_NAME)
	if attachment and attachment:IsA("Attachment") then
		return attachment.CFrame
	end
	return nil
end

function Viewmodel.stats()
	return table.clone(stats)
end

-- THE BEAD A PLAYER CAN ACTUALLY SEE (task 90). Karen, 2026-09-27: "we are missing front knob or how
-- it calls where you aim and follow animal with that point".
--
-- The parts gun already has a `Bead` piece and gets nothing added. The uploaded gun is exactly ONE
-- MeshPart whose bead is PAINTED at a few pixels across, so there is nothing on it to aim with: this
-- draws one at the `Sight` attachment, which is the same point the ADS pose lines up with the view
-- axis. So the mark a player follows the animal with and the point the geometry aims are the same
-- Instance, not two numbers that agree today.
--
-- It is drawn by the VIEWMODEL and not by the weapon on purpose: it is cosmetic, client-side and
-- first-person only -- the gun other players see is unchanged, and `CanQuery = false` keeps it out of
-- every ray in the game, including this system's own occlusion cast.
local function addBeadMarker(clone: BasePart, config): boolean
	local attachment = clone:FindFirstChild(SIGHT_NAME)
	if not (attachment and attachment:IsA("Attachment")) then
		return false
	end
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == BEAD_NAME then
			return false -- the gun brought its own
		end
	end
	local bead = Instance.new("Part")
	bead.Name = MARKER_NAME
	bead.Shape = Enum.PartType.Ball
	bead.Size = Vector3.new(config.BEAD_MARKER_STUDS, config.BEAD_MARKER_STUDS, config.BEAD_MARKER_STUDS)
	bead.Color = config.BEAD_MARKER_COLOR
	-- METAL, NOT NEON (task 92). Karen, after playing S2: "that red dot is not realistic, we need to
	-- improve what actually is on Beretta Parallelo" -- and what that gun has is a brass ball on the
	-- rib. A Neon bead is its own light source and cannot read as metal at any colour, so the material
	-- is a config row rather than a literal, and the fill light below is what keeps it visible.
	bead.Material = config.BEAD_MARKER_MATERIAL
	bead.Anchored = true
	bead.CanCollide = false
	bead.CanQuery = false
	bead.CanTouch = false
	bead.Massless = true
	bead.CastShadow = false
	bead.CFrame = clone.CFrame * (attachment :: Attachment).CFrame
	bead.Parent = clone
	return true
end

-- THE GUN'S OWN LIGHT (task 92). Karen, after playing S2: "Weapon color we need to improve and style
-- now feels a bit broken, it has to be smooth and nice."
--
-- A first-person gun is lit by the sun alone, inches from the eye, so in anything but flat noon light
-- it renders as a near-black silhouette -- which is what "broken" is looking at, and what the S1
-- screenshot showed in the dark. One PointLight inside the camera lifts the blued steel and the walnut
-- into the colours they actually are. `Shadows = false`, because a light this close casting shadows
-- from a gun's own barrels is noise, and it is the only light in the game that is not the sun.
local function addFillLight(clone: BasePart, config): Light
	local light = Instance.new("PointLight")
	light.Name = FILL_NAME
	light.Brightness = config.VIEWMODEL_FILL_BRIGHTNESS
	light.Range = config.VIEWMODEL_FILL_RANGE_STUDS
	light.Color = config.VIEWMODEL_FILL_COLOR
	light.Shadows = false
	-- An Attachment is how a light gets an offset from the part it hangs on: a PointLight's own
	-- position is its parent's, and the light wants to be above and left of the breech rather than
	-- inside the Handle's centre.
	local at = Instance.new("Attachment")
	at.Name = FILL_NAME .. "At"
	at.CFrame = CFrame.new(config.VIEWMODEL_FILL_OFFSET_STUDS)
	at.Parent = clone
	light.Parent = at
	return light
end

-- WHERE THE DRAWN GUN'S MUZZLE IS, in WORLD space, for the fired barrel (task 92) -- or nil when there
-- is no viewmodel on screen, or the cloned gun carries no `Muzzle` attachment. The caller then draws
-- at the world gun's muzzle instead, which is the right answer in third person.
--
-- The barrel's own lateral offset comes from `Shotgun.barrelMuzzleOffset`, the ONE definition of which
-- tube is which -- this module does not know that the right barrel is +0.09 and must not learn it.
function Viewmodel.muzzle(barrel: number?): CFrame?
	local made = Viewmodel.current()
	local clone = made and made.PrimaryPart
	local attachment = clone and clone:FindFirstChild(MUZZLE_NAME)
	if not (attachment and attachment:IsA("Attachment")) then
		return nil
	end
	return (attachment :: Attachment).WorldCFrame * CFrame.new(Shotgun.barrelMuzzleOffset(barrel, Shotgun.CONFIG))
end

-- ONE SHELL: red plastic with a brass base, two parts, drawn for one player and never replicated.
local function makeShell(name: string, config, parent: Instance): Model
	local shell = Instance.new("Model")
	shell.Name = name
	local size = config.SHELL_SIZE_STUDS
	local baseLength = size.Z * config.SHELL_BASE_FRACTION
	for _, piece in ipairs({
		{ name = "Body", length = size.Z - baseLength, colour = config.SHELL_BODY_COLOR, offset = baseLength / 2 },
		{ name = "Base", length = baseLength, colour = config.SHELL_BASE_COLOR, offset = -(size.Z - baseLength) / 2 },
	}) do
		local part = Instance.new("Part")
		part.Name = piece.name
		part.Shape = Enum.PartType.Cylinder
		-- A cylinder's length runs along its own X, so the shell lies along Z once turned.
		part.Size = Vector3.new(piece.length, size.X, size.Y)
		part.Color = piece.colour
		part.Material = if piece.name == "Base" then Enum.Material.Metal else Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = false
		part.Parent = shell
		if piece.name == "Body" then
			shell.PrimaryPart = part
		end
	end
	shell.Parent = parent
	return shell
end

-- WHERE A CHAMBER IS, in the gun's own frame: the breech end of each tube, on its bore line. The
-- barrels are 0.62 of a 4.4-stud gun and the Handle's -Z is the muzzle, so the breech face sits 0.53
-- studs BEHIND the Handle's centre -- the same number the carry pose and the aim's cheek angle are
-- built on. `Shotgun.barrelMuzzleOffset` is still the one definition of which tube is which.
local function chamberOffset(barrel: number): CFrame
	local across = Shotgun.barrelMuzzleOffset(barrel, Shotgun.CONFIG)
	local breechZ = Shotgun.CONFIG.HANDLE_SIZE.Z * (0.62 - 0.5)
	return CFrame.new(across.X, across.Y, breechZ)
end

local function build(handle: BasePart, config): Model
	local made = Instance.new("Model")
	made.Name = "DrivenHuntViewmodel"

	local clone = handle:Clone()
	clone.Name = "Handle"
	-- THE GUN'S PARTS COME WITH IT (Task 71). Since the shotgun became a side-by-side built from
	-- welded parts, the Handle is an INVISIBLE envelope and every visible piece is one of its
	-- children: destroying them, as this did, would have left the first-person gun as nothing at all
	-- while the third-person gun was the real one. One source, two views -- the clone IS how the
	-- viewmodel stays the same object as the Tool, and ServerScriptService.Weapon.Hardware is still
	-- the only writer of the original (docs/design/camera.md section 3.2).
	--
	-- EVERY PART IS ANCHORED, so the welds are not needed and are destroyed with everything else that
	-- is not a shape: an unanchored part under workspace.CurrentCamera would be simulated.
	--
	-- A SurfaceAppearance, a Texture and a Decal ARE the shape (Task 74). The uploaded shotgun is a
	-- MeshPart with a SurfaceAppearance child carrying its PBR maps, and the sweep as written would
	-- have destroyed it -- so the FIRST-PERSON gun would have lost its maps while the third-person
	-- gun kept them: "purple untextured legs" (docs/PROJECT_CONTEXT.md) visible only in ADS, only to
	-- the player holding it, and asserted by nothing. docs/design/asset-pipeline.md section 6.6
	-- predicted this exact sweep and named the fix as the camera owner's, which is this file.
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
			descendant.CastShadow = false
		elseif
			not (
				descendant:IsA("Attachment")
				or descendant:IsA("SurfaceAppearance")
				or descendant:IsA("Texture")
				or descendant:IsA("Decal")
			)
		then
			descendant:Destroy() -- no scripts, no welds, no sounds: a shape and nothing else
		end
	end
	clone.Anchored = true
	clone.CanCollide = false
	clone.CanQuery = false -- see the header: an occlusion ray must not hit our own viewmodel
	clone.CanTouch = false
	clone.Massless = true
	clone.CastShadow = false
	clone.Parent = made
	made.PrimaryPart = clone
	-- FIRST-PERSON EXTRAS, AND THEY BELONG TO THE FIRST-PERSON BRANCH (review round 2, finding 1).
	-- The clone is drawn in BOTH branches -- in the OFF branch it is the ADS viewmodel Karen accepted
	-- on 2026-09-25 -- so a light or a drawn bead added here without asking lands in the camera task
	-- 89 promised not to touch: the fill light was throwing a glow on the ground behind a
	-- third-person player. Neither is any use there either: the shoulder camera's gun is lit by the
	-- same sun as everything else around it, and its sight picture is the accepted framing rather
	-- than a bead on the axis.
	if config.FIRST_PERSON then
		addBeadMarker(clone, config)
		addFillLight(clone, config)
	end

	stats.rebuilds += 1
	local parts = 0
	for _, descendant in ipairs(made:GetDescendants()) do
		if descendant:IsA("BasePart") then
			parts += 1
		end
	end
	stats.parts = parts
	-- COUNTED, NOT WARNED. A gun with no `Sight` still draws -- `Mode.aimOffset(nil, config)` falls
	-- back to the accepted framing -- but the sight picture is then a guess about somebody else's
	-- mesh, so the number says how often that happened and a spec asserts it is zero for a real gun.
	if not clone:FindFirstChild(SIGHT_NAME) then
		stats.sightMissing += 1
	end
	return made
end

-- Parents, poses or unparents the viewmodel for this frame. Below VIEWMODEL_SHOW_BLEND it is
-- UNPARENTED, not merely invisible, so a leak is visible on screen rather than hiding as a
-- transparent part (design section 10).
--
-- IN FIRST PERSON THE GUN IS CARRIED, NOT SUMMONED (task 89): the threshold applies only in the OFF
-- branch, so with the flag on the clone stays parented at blend 0 and the player always has a gun in
-- frame. Nothing else about the clone changes.
--
-- IT TAKES THE WHOLE STATE since task 89, not a blend: sway, bob, recoil and the break-open tilt all
-- live in the state and all land in one offset (`Mode.viewmodelOffset`), so no second module holds a
-- piece of the pose. In this task every one of them is exactly identity.
local cachedHandle: BasePart? = nil
local lastSourceCheck = 0

function Viewmodel.update(camCFrame: CFrame, state: Mode.State, config)
	local cam = Workspace.CurrentCamera
	-- The source walks the character for a Tool, so it is asked four times a second rather than
	-- every frame (the pose below is what has to be per frame, and it is one PivotTo).
	local now = os.clock()
	if source and (now - lastSourceCheck > 0.25 or (cachedHandle and not cachedHandle.Parent)) then
		lastSourceCheck = now
		cachedHandle = source()
	elseif not source then
		cachedHandle = nil
	end
	local handle = cachedHandle

	if not cam or not handle or (state.blend < config.VIEWMODEL_SHOW_BLEND and not config.FIRST_PERSON) then
		if model then
			model.Parent = nil
		end
		return
	end

	if not model or builtFrom ~= handle or stale then
		-- clear() disconnects the old watchers and resets `stale`, so nothing that fired before this
		-- rebuild can mark the new clone stale.
		Viewmodel.clear()
		childWatchers = {
			handle.ChildAdded:Connect(function()
				stale = true
			end),
			handle.ChildRemoved:Connect(function()
				stale = true
			end),
		}
		model = build(handle, config)
		builtFrom = handle
	end

	local made = model :: Model
	if made.Parent ~= cam then
		made.Parent = cam
	end
	-- THE GUN'S OWN SIGHT DECIDES THE AIMED POSE (task 90): read off the clone every frame, because
	-- a rebuild (the mesh arriving late, `Hardware.upgrade`) can change it mid-life.
	local gun = camCFrame * Mode.viewmodelOffset(state, Viewmodel.sight(), config)
	made:PivotTo(gun)
	Viewmodel.hinge(gun, state, config)
end

-- THE BREAK (task 96). Karen, 2026-09-27: the reload is a break action like the real gun, so the
-- barrels swing DOWN off the action -- and that is one piece of the gun moving relative to another,
-- which is why `Weapon.Hardware` wears it as two welded meshes and why this is the only module that
-- can draw it: it owns what is under the camera.
--
-- ROTATION ABOUT THE KNUCKLE, not a translation that looks like one: the barrels turn about
-- `BREAK_HINGE_STUDS` in the Handle's own frame, which is where the hinge pin is on the real gun.
-- Their rest pose is read off the clone ONCE per build, so a mesh that arrives with its own offset
-- still hinges about the right point.
function Viewmodel.hinge(gunCFrame: CFrame, state: Mode.State, config)
	local made = model
	local clone = made and made.PrimaryPart
	local barrels = clone and clone:FindFirstChild(BARRELS_NAME)
	if not (barrels and barrels:IsA("BasePart")) then
		return
	end
	if barrelsLocal == nil then
		barrelsLocal = clone.CFrame:ToObjectSpace((barrels :: BasePart).CFrame)
	end
	local angle = Mode.breakAngleDeg(state, config)
	local hinge = CFrame.new(config.BREAK_HINGE_STUDS)
	-- NEGATIVE ABOUT X IS THE MUZZLE GOING DOWN, which is what "break open" means: a part's
	-- LookVector is its -Z, and `CFrame.Angles(+t, 0, 0)` takes (0, 0, -1) to (0, sin t, -cos t) --
	-- i.e. UP. Measured the hard way: the first run of `camera_client.spec` caught the barrels
	-- swinging toward the sky.
	local swing = hinge * CFrame.Angles(-math.rad(angle), 0, 0) * hinge:Inverse();
	(barrels :: BasePart).CFrame = gunCFrame * swing * (barrelsLocal :: CFrame)
	if angle > 0 then
		stats.breaksDrawn += 1
	end
	Viewmodel.shells(gunCFrame * swing, config)
end

-- THE SHELLS (task 96): spent ones pop out of the barrels that fired, fresh ones slide into the
-- chambers. They are drawn in the BARRELS' frame, so they swing with them, and they live only while
-- the gun is open -- `setReload` gives this module the weapon's own answer and the clock starts at
-- the rising edge of "open".
--
-- Anchored and moved by hand rather than thrown: nothing under `workspace.CurrentCamera` may be
-- simulated (a physics part parented to the camera is a part in the world that nobody can see).
function Viewmodel.shells(barrelsCFrame: CFrame, config)
	local made = model
	local clone = made and made.PrimaryPart
	if not clone then
		return
	end
	local started = openedAt
	local live = {}
	-- BY PREFIX, because a shell is named for its barrel -- `SpentShell1`, `FreshShell2`. Matching
	-- the bare name found nothing, so the spent shells were never cleared and stayed in the gun
	-- after it shut: caught by the client case that asserts a shut gun has none.
	for _, child in ipairs(clone:GetChildren()) do
		local name = child.Name
		if string.sub(name, 1, #SPENT_NAME) == SPENT_NAME or string.sub(name, 1, #FRESH_NAME) == FRESH_NAME then
			table.insert(live, child)
		end
	end
	if not (reload.open and started) then
		for _, shell in ipairs(live) do
			shell:Destroy()
		end
		return
	end

	local elapsed = os.clock() - started
	local wanted = {}
	-- SPENT: one per barrel that fired, rising out of its chamber and back over the shoulder.
	local ejectT = math.clamp(elapsed / config.SHELL_EJECT_SECONDS, 0, 1)
	if ejectT < 1 then
		for barrel = 1, reload.spent do
			wanted[SPENT_NAME .. barrel] = chamberOffset(barrel)
				* CFrame.new(0, config.SHELL_EJECT_RISE_STUDS * ejectT, config.SHELL_EJECT_RISE_STUDS * ejectT)
		end
	end
	-- FRESH: after the spent ones are clear, sliding forward into the chambers and stopping there.
	local feedT = math.clamp((elapsed - config.SHELL_EJECT_SECONDS) / config.SHELL_FEED_SECONDS, 0, 1)
	if feedT > 0 then
		for barrel = 1, math.max(reload.spent, 1) do
			wanted[FRESH_NAME .. barrel] = chamberOffset(barrel)
				* CFrame.new(0, 0, config.SHELL_FEED_FROM_STUDS * (1 - feedT))
		end
	end

	for _, shell in ipairs(live) do
		if wanted[shell.Name] == nil then
			shell:Destroy()
		end
	end
	for name, offset in pairs(wanted) do
		local shell = clone:FindFirstChild(name)
		if not shell then
			shell = makeShell(name, config, clone)
			stats.shellsDrawn += 1
		end
		(shell :: Model):PivotTo(barrelsCFrame * offset * CFrame.Angles(0, math.rad(90), 0))
	end
end

function Viewmodel.isParented(): boolean
	return model ~= nil and model.Parent ~= nil
end

return Viewmodel
