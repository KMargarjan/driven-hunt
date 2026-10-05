--!strict
-- Weapon.Hardware: the ONLY writer of Tool Instances in this system. It builds the gun, hands it
-- over, and destroys it. It holds no state and touches no remote.
--
-- Everything positioned or coloured is built in code from Shotgun.CONFIG, not from a .rbxm (banned,
-- CLAUDE.md) and not from typed JSON property values (which the harness cannot compare yet,
-- TASKS.md row 16). Same choice as src/server/TestArena.luau and Boar.Body.
--   Tool        https://create.roblox.com/docs/reference/engine/classes/Tool
--   Attachment  https://create.roblox.com/docs/reference/engine/classes/Attachment
-- The muzzle is an Attachment, not a number re-derived at each call site: the server reads its
-- WorldPosition for the shot and the client reads the same Attachment for the flash, so the offset
-- is defined once and cannot drift between them (design section 8).
--
-- SINCE TASK 71 THE GUN IS A SIDE-BY-SIDE BUILT FROM PARTS, not one wooden box: `Weapon.Shape` is
-- the pure list of what it is made of and this file is still the only thing that creates any of it.
-- The ADS viewmodel gets the same look by CLONING the Handle (docs/design/camera.md section 3.2), so
-- there is one source for the gun's appearance and not two.
--
-- SINCE TASK 76 IT ALSO UPGRADES A GUN IT ALREADY BUILT (`Hardware.upgrade`). The preload does not
-- block the boot, so a gun handed out in the server's first second wears the parts fallback; when the
-- template lands, every gun still wearing it gets the mesh. One path, idempotent, and it is still the
-- only writer of Tool Instances.
--
-- Design: docs/design/shotgun.md (section 8), docs/design/asset-pipeline.md (sections 5.2, 6.6)
-- Note:   docs/research/2026-09-26-shotgun-model.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Shape = require(script.Parent.Shape)

local Hardware = {}

-- THE MESH, OR THE PARTS. Injected rather than required, for two reasons: `Hardware` must not drag
-- `ServerStorage.Assets` into every weapon spec, and a spec has to be able to drive BOTH paths --
-- the loaded mesh and the fallback -- without a network. `WeaponBoot` wires this to
-- `Assets.Loader.template`, which never yields (docs/design/asset-pipeline.md section 5.2), so the
-- grant path stays yield-free. `nil` restores "always build the parts gun".
--
-- The same shape as `Weapon.setDriveLineProvider` and `Viewmodel.setSource`.
local templateFor: ((string) -> (Instance?, any))? = nil
local warned = false
local barrelsWarned = false
-- Once per server, not once per grant: see the warning itself (task 90).
local sightWarned = false

function Hardware.setTemplateProvider(fn: ((string) -> (Instance?, any))?)
	templateFor = fn
	warned = false
end

-- So a spec can borrow the seam and PUT THE LIVE ONE BACK. Without this a spec that injects a fake
-- leaves the running server wearing the grey box for the rest of the session -- including in any
-- screenshot taken afterwards, which is exactly the kind of quiet difference rule 5 exists for.
function Hardware.getTemplateProvider(): ((string) -> (Instance?, any))?
	return templateFor
end

-- The key this system asks for. A string literal on purpose: the weapon's config must not require
-- the manifest (docs/design/asset-pipeline.md section 4.2), and a spec asserts it resolves.
Hardware.ASSET_KEY = "shotgun.handle"

-- The name every granted Tool carries. One per player, so it is also how a stray one is found.
Hardware.TOOL_NAME = "Shotgun"

-- THE NAME OF THE WORN MESH, AND IT IS ALSO THE ONE FACT THE UPGRADE PATH READS. A Handle either has
-- this child -- the loaded gun -- or it does not, in which case what is on it is Task 71's parts
-- fallback. No attribute, no flag and no table: the visible model IS the state, so "has this gun
-- already been upgraded" cannot disagree with what is on screen.
Hardware.MODEL_NAME = "Model"
-- THE PIECE THAT HINGES (task 96). Karen, 2026-09-27: the reload is a BREAK ACTION like the real
-- Beretta 486 Parallelo, so the barrels must be able to swing down off the action -- and one
-- MeshPart cannot hinge. The gun is worn as two welded pieces, and this is the name the
-- first-person viewmodel looks for to rotate one of them. A player who is not holding the gun sees
-- the same two pieces welded in the same place, which is the same gun they saw before.
Hardware.BARRELS_KEY = "shotgun.barrels"
Hardware.BARRELS_NAME = "Barrels"
-- The attachment the first-person camera lines the view up with (task 90, docs/design/camera.md
-- section 6.5). Named here because `Hardware` is its only writer and `Camera.Viewmodel` reads it off
-- the CLONE by the same name.
Hardware.SIGHT_NAME = "Sight"

function Hardware.build(): Tool
	local config = Shotgun.CONFIG
	local tool = Instance.new("Tool")
	tool.Name = Hardware.TOOL_NAME
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.Grip = config.GRIP

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = config.HANDLE_SIZE
	handle.Color = config.HANDLE_COLOR
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Anchored = false
	-- INVISIBLE SINCE TASK 71, and still the gun's one real part: the hand grips it, the Muzzle hangs
	-- on it, and it is the only part of the gun a ray can hit. The shape that is SEEN is welded to it
	-- below. `HANDLE_TRANSPARENCY = 0` puts the envelope box back on screen.
	handle.Transparency = config.HANDLE_TRANSPARENCY
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.CFrame = CFrame.new(config.MUZZLE_OFFSET)
	muzzle.Parent = handle

	-- THE SIGHT, beside the muzzle and for exactly the same reason (task 90): where a feature of the
	-- gun IS belongs on the gun as an Attachment, once, rather than as a number re-derived at each
	-- call site. The server never reads this one -- the first-person camera does, to line the bead up
	-- with the view axis -- but the gun is what knows where its own bead is, and a mesh and the parts
	-- fallback answer differently. `addMesh` overwrites it from the manifest row when that row has a
	-- measurement (docs/design/camera.md section 6.5).
	Hardware.setSight(handle, Shape.sight(config))

	if not Hardware.addMesh(handle, config) then
		Hardware.addParts(handle, config)
	end

	return tool
end

-- THE PIECE THAT HINGES, welded to the Handle beside the body (task 96). Its own function because
-- it is its own state: a gun handed out between the two templates landing wears the body and needs
-- exactly this, and nothing else, when the sweep comes round.
--
-- The same pose and the same size as the body: both rows carry the whole gun's bounding box, baked
-- into each half by `asset_prep` as anchor triangles, so the two pieces assemble at ONE CFrame with
-- no measured offset. A missing barrels template is not an error -- the body alone is still a gun --
-- and the warning says so once.
function Hardware.addBarrels(handle: BasePart, size: Vector3, pose: CFrame): boolean
	if handle:FindFirstChild(Hardware.BARRELS_NAME) ~= nil then
		return true
	end
	if templateFor == nil then
		return false
	end
	local barrels, report = templateFor(Hardware.BARRELS_KEY)
	if not (barrels and barrels:IsA("BasePart")) then
		if not barrelsWarned then
			barrelsWarned = true
			warn(
				string.format(
					"[Weapon] no %s template (%s); the gun wears its body alone and cannot break open",
					Hardware.BARRELS_KEY,
					if typeof(report) == "table" and report.reason then report.reason else "not preloaded"
				)
			)
		end
		return false
	end
	local worn = (barrels :: BasePart):Clone()
	worn.Name = Hardware.BARRELS_NAME
	worn.Size = size
	worn.Anchored = false
	worn.CanCollide = false
	worn.CanQuery = false
	worn.CanTouch = false
	worn.Massless = true
	worn.CastShadow = true
	worn.CFrame = handle.CFrame * pose
	worn.Parent = handle
	local weld = Instance.new("Weld")
	weld.Name = "BarrelsWeld"
	weld.Part0 = handle
	weld.Part1 = worn
	weld.C0 = pose
	weld.Parent = handle
	return true
end

-- CREATE-OR-UPDATE, never a second one. The attachment IS the state, so `build`, `addMesh` and
-- `upgrade` can all call this and a gun ends up with exactly one `Sight` -- the same shape
-- `Hardware.upgrade` already has for the worn model.
function Hardware.setSight(handle: BasePart, cframe: CFrame): Attachment
	local existing = handle:FindFirstChild(Hardware.SIGHT_NAME)
	local sight = if existing and existing:IsA("Attachment") then existing else Instance.new("Attachment")
	sight.Name = Hardware.SIGHT_NAME
	sight.CFrame = cframe
	sight.Parent = handle
	return sight
end

-- THE LOADED MODEL, WELDED TO THE HANDLE. Returns false when there is nothing to wear, which is not
-- an error: the caller builds Task 71's parts gun instead and the player is never gunless.
--
-- WHAT DOES NOT CHANGE, AND IT IS THE WHOLE POINT: the `Handle` is still exactly `HANDLE_SIZE`,
-- still the grip (`Tool.Grip`), still the anchor of the `Muzzle` attachment the server reads for
-- every shot, and still the ONLY part of the gun a ray can hit. The mesh is scenery welded to it --
-- `CanQuery = false`, `CanCollide = false`, `Massless = true` -- so firing, hit zones, the safety
-- arc, reloading and ADS are all bit-for-bit what they were.
--
-- THE SIZE IS UNIFORM AND THE MANIFEST SAYS WHY (`Assets` row `sizeStuds`): the mesh is scaled so
-- its LENGTH is `HANDLE_SIZE.Z`, not squeezed into the envelope's 0.4 x 0.5 cross-section, because
-- a non-uniform fit is a squashed gun that measures perfectly.
function Hardware.addMesh(handle: BasePart, config): boolean
	if templateFor == nil then
		return false
	end
	local template, report = templateFor(Hardware.ASSET_KEY)
	if template == nil then
		-- ONCE, NOT PER GRANT. A gun is granted on every spawn; a warning per spawn is a log nobody
		-- reads and a frame nobody gets back.
		if not warned then
			warned = true
			warn(
				string.format(
					"[Weapon] no %s template (%s); wearing the grey box",
					Hardware.ASSET_KEY,
					if typeof(report) == "table" and report.reason then report.reason else "not preloaded"
				)
			)
		end
		return false
	end

	local row = if typeof(report) == "table" then report.row else nil
	local size = if typeof(row) == "table" and typeof(row.sizeStuds) == "Vector3"
		then row.sizeStuds
		else config.HANDLE_SIZE
	local rotation = if typeof(row) == "table" and typeof(row.rotationDeg) == "Vector3"
		then row.rotationDeg
		else Vector3.zero
	local offset = if typeof(row) == "table" and typeof(row.offsetStuds) == "Vector3"
		then row.offsetStuds
		else Vector3.zero

	-- THE MESH'S OWN SIGHT, when the row carries a measurement. It cannot be derived: the uploaded
	-- gun is exactly one MeshPart with a PAINTED bead and no Instance to read, so the number is
	-- measured on screen in ADS and recorded in the row (docs/design/camera.md section 6.5, Director
	-- item C). Without it the parts-gun bead is the fallback and this warns ONCE, because a gun is
	-- granted on every spawn and a warning per spawn is a log nobody reads.
	local sightOffset = if typeof(row) == "table" and typeof(row.sightOffsetStuds) == "Vector3"
		then row.sightOffsetStuds
		else nil
	if sightOffset then
		Hardware.setSight(handle, CFrame.new(sightOffset))
	elseif not sightWarned then
		sightWarned = true
		warn(
			string.format(
				"[Weapon] the %s row carries no sightOffsetStuds; the first-person sight falls back "
					.. "to the parts gun's bead at %s",
				Hardware.ASSET_KEY,
				tostring(Shape.beadOffset(config))
			)
		)
	end

	local pose = CFrame.new(offset) * CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))

	-- EACH PIECE ON ITS OWN (task 96). A gun that already wears the body and is missing the barrels
	-- -- which is every gun handed out between the two templates landing -- must get the barrels and
	-- not a second body.
	if handle:FindFirstChild(Hardware.MODEL_NAME) ~= nil then
		return Hardware.addBarrels(handle, size, pose)
	end

	local model = template:Clone()
	model.Name = Hardware.MODEL_NAME
	if model:IsA("BasePart") then
		model.Size = size
	end
	for _, part in ipairs({ model, table.unpack(model:GetDescendants()) }) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			part.CastShadow = true
		end
	end
	if model:IsA("BasePart") then
		model.CFrame = handle.CFrame * pose
		model.Parent = handle
		local weld = Instance.new("Weld")
		weld.Name = "ModelWeld"
		weld.Part0 = handle
		weld.Part1 = model
		weld.C0 = pose
		weld.Parent = handle
	elseif model:IsA("Model") then
		-- THE CONSUMER SETS THE SIZE, FOR A MODEL TOO (design 6.1). A Model has no Size, so the
		-- equivalent is a uniform scale onto the row's target length -- without this the `model`
		-- branch was the one path that shipped whatever the exporter happened to choose.
		local _, natural = model:GetBoundingBox()
		local longest = math.max(natural.X, natural.Y, natural.Z)
		local target = math.max(size.X, size.Y, size.Z)
		if longest > 0 and target > 0 then
			model:ScaleTo(target / longest)
		end
		model:PivotTo(handle.CFrame * pose)
		model.Parent = handle
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				local weld = Instance.new("Weld")
				weld.Part0 = handle
				weld.Part1 = part
				weld.C0 = handle.CFrame:ToObjectSpace(part.CFrame)
				weld.Parent = handle
			end
		end
	else
		-- NEITHER, SO WEAR THE GREY BOX. Returning true here left the clone unparented and the
		-- player holding an empty Handle with no parts gun behind it (review round 1, note): the
		-- one shape this whole seam exists to make impossible.
		model:Destroy()
		if not warned then
			warned = true
			warn(
				string.format(
					"[Weapon] the %s template is a %s, which cannot be worn; wearing the " .. "grey box",
					Hardware.ASSET_KEY,
					template.ClassName
				)
			)
		end
		return false
	end
	-- ...AND THE BARRELS, WHICHEVER SHAPE THE BODY CAME IN. This used to sit at the end of the
	-- `Model` branch alone, so a body that arrives as a MeshPart -- which is what this gun is --
	-- never got them: the spec's own note read `body=true barrels=false` while the game, where the
	-- gun is upgraded through the other path, looked right. One call, after either branch.
	Hardware.addBarrels(handle, size, pose)
	return true
end

-- ONE PIECE OF THE GUN'S LOOK, welded to the Handle. Appearance only, and the three properties that
-- say so are not decoration:
--
--  * `CanQuery = false`. The Handle stays the ONLY part of the gun a ray can hit, exactly as before
--    Task 71. Without this, ten new boxes on another player's gun become ten new things a slug can
--    stop against -- an appearance task that quietly changed hit detection.
--  * `Massless = true`. The assembly's root part is picked anchored-first, then "Parts with Massless
--    set to false (default) take precedence" (https://create.roblox.com/docs/physics/assemblies), so
--    a heavy decorative barrel could take the root away from the Handle and move the Tool's grip.
--  * a legacy `Weld` with an explicit `C0`, NOT a `WeldConstraint`. A WeldConstraint records the
--    offset the parts happen to have when it is enabled and needs both of them in the DataModel
--    (src/server/Boar/Body.luau says so where it uses one); `Hardware.build` returns a Tool that is
--    not parented anywhere yet. A Weld carries the offset AS DATA, so the geometry comes from
--    `Weapon.Shape` rather than from wherever the parts were at the time.
--
-- The weld is parented to the Handle, which is what keeps it part of the tool's own assembly.
function Hardware.addPiece(handle: BasePart, piece): BasePart
	local part = Instance.new("Part")
	part.Name = piece.name
	part.Shape = piece.shape
	part.Size = piece.size
	part.Color = piece.color
	part.Material = piece.material
	part.CFrame = handle.CFrame * piece.offset
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = handle

	local weld = Instance.new("Weld")
	weld.Name = piece.name .. "Weld"
	weld.Part0 = handle
	weld.Part1 = part
	weld.C0 = piece.offset
	weld.Parent = handle

	return part
end

-- TASK 71'S FALLBACK, AS ONE CALL. `build` is its one caller, and `removeParts` below is its exact
-- opposite: naming both means the list of what the parts gun is made of is walked in one place,
-- forwards and backwards, instead of being spelled out wherever a parts gun is put on or taken off.
function Hardware.addParts(handle: BasePart, config)
	for _, piece in ipairs(Shape.pieces(config)) do
		Hardware.addPiece(handle, piece)
	end
end

-- THE FALLBACK COMES OFF, AND ONLY THE FALLBACK. It destroys exactly the pieces `Shape.pieces` names
-- and their welds -- BY NAME, from the same one list `addParts` builds from -- so the Handle, the
-- `Muzzle` attachment, the worn mesh and its `ModelWeld` cannot be caught by it. Not a
-- "destroy every child but the Muzzle" sweep: that would be a second, looser idea of what the gun is
-- made of, and the first thing it deleted would be the attachment every shot is measured from.
function Hardware.removeParts(handle: BasePart, config): number
	local removed = 0
	for _, piece in ipairs(Shape.pieces(config)) do
		local part = handle:FindFirstChild(piece.name)
		if part then
			part:Destroy()
			removed += 1
		end
		local weld = handle:FindFirstChild(piece.name .. "Weld")
		if weld then
			weld:Destroy()
		end
	end
	return removed
end

-- Is this Tool wearing the loaded gun, or the parts fallback? Read off the Instance, never off a
-- table this module keeps: a Tool granted by a server that has since reloaded, or one the sweep found
-- and this module never recorded, answers correctly anyway.
function Hardware.wearsMesh(tool: Tool): boolean
	local handle = tool:FindFirstChild("Handle")
	-- BOTH PIECES SINCE TASK 96. A gun wearing the body and no barrels is half a gun, and saying it
	-- "wears the mesh" is what stopped the upgrade sweep from ever giving it the rest: the first
	-- Play session of that task handed out a body-only gun and nothing ever fixed it, because the
	-- body alone answered this question yes.
	return handle ~= nil
		and handle:FindFirstChild(Hardware.MODEL_NAME) ~= nil
		and handle:FindFirstChild(Hardware.BARRELS_NAME) ~= nil
end

-- THE ONE UPGRADE PATH (TASKS.md row 75a(h)). A player who spawns inside the server's first second
-- gets the parts gun, because `WeaponBoot` starts the weapon system BEFORE the preload finishes and
-- that ordering is deliberate (Task 74 review round 1: a stalled `LoadAsset` must not mean a gunless
-- player). Nothing used to rebuild a Tool that was granted early, so that player kept the fallback
-- for as long as they held it -- and in Studio Play, where a join takes well under a second, that is
-- every player, every time.
--
-- Returns true only when THIS call put the mesh on. It is:
--
--  * IDEMPOTENT. The worn model is the state (`MODEL_NAME`), so a second arrival, the next sweep pass
--    and the boot line's own call all find the mesh already there and do nothing. Two `Model`
--    children -- two guns in one hand -- is the shape this makes impossible.
--  * SAFE WHEN THERE IS NOTHING TO WEAR. The mesh goes on BEFORE the parts come off, and a false from
--    `addMesh` returns with the fallback untouched. A template that never arrives changes nothing.
--  * BLIND TO EVERYTHING BUT THE LOOK. It does not touch the `Handle` (still `HANDLE_SIZE`, still the
--    grip, still the only part a ray can hit), the `Muzzle` the server reads for every shot, the
--    Tool's Parent, or any weapon state: a player mid-reload or mid-aim sees the gun change and
--    nothing else. `Weapon`'s reducer is not consulted because there is nothing in it to change.
--
-- The ADS viewmodel follows from its one source without being told: it CLONES this Handle
-- (docs/design/camera.md 3.2) and `Camera.Viewmodel` rebuilds the clone when the source's children
-- change, so the first-person gun cannot be left wearing a look the third-person gun has dropped.
function Hardware.upgrade(tool: Tool): boolean
	local handle = tool:FindFirstChild("Handle")
	if handle == nil or not handle:IsA("BasePart") then
		return false
	end
	if Hardware.wearsMesh(tool) then
		return false
	end
	local config = Shotgun.CONFIG
	if not Hardware.addMesh(handle, config) then
		return false
	end
	Hardware.removeParts(handle, config)
	return true
end

-- Every gun already in a hand, upgraded. Walks the players rather than a table of this module's own,
-- for the same reason `toolsOf` does: a Tool nobody recorded is still a Tool a player is looking at.
-- NEVER YIELDS, so it is safe from the arming sweep and from a boot line.
-- `after` IS CALLED ONCE PER GUN THIS PASS ACTUALLY UPGRADED (task 123 round 9), with the player it
-- belongs to. It exists because of Karen's *"There is no weapon something is broken"*: when the
-- barrels template lands AFTER the gun was handed out -- measured in her session at 2096 ms against
-- a 416 ms handle -- the upgraded Tool ended up in the BACKPACK, and she stood at the stand with
-- empty hands. Putting it back in the hand is `Weapon`'s decision, not this module's: `AUTO_EQUIP`
-- lives there, and `Hardware.upgrade`'s own promise is that it is blind to everything but the look.
function Hardware.upgradeAll(after: ((Player, Tool) -> ())?): number
	local upgraded = 0
	for _, player in ipairs(Players:GetPlayers()) do
		for _, tool in Hardware.toolsOf(player) do
			if Hardware.upgrade(tool) then
				upgraded += 1
				if after then
					after(player, tool)
				end
			end
		end
	end
	return upgraded
end

-- The Backpack is where a Tool waits; the character is where it is held.
-- Puts the tool in the player's Backpack, and SAYS WHETHER IT LANDED.
--
-- IT NEVER YIELDS, and that is a requirement, not an implementation detail. It waited for the
-- Backpack for a while (Task 34) and that wait made the grant interleavable: while it was parked
-- the player held no tool, so every other caller -- the Backpack hook the wait was waiting for, and
-- the arming sweep -- decided to grant one too, and a player ended up with two Tools, only one of
-- them recorded. The same yield also parked the drive's Heartbeat step, which applies refreshArming
-- synchronously. A Backpack that is not there yet is covered by the hook that fires when it
-- arrives, which is what it is for.
function Hardware.give(tool: Tool, player: Player): boolean
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return false
	end
	tool.Parent = backpack
	return true
end

-- Every Tool of ours this player is carrying, Backpack and character both. Arming is one-tool-per
-- -player, and this is how that is enforced rather than assumed.
function Hardware.toolsOf(player: Player): { Tool }
	local found = {}
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child.Name == Hardware.TOOL_NAME then
					table.insert(found, child)
				end
			end
		end
	end
	return found
end

-- THE HUMANOID IS NOT THERE YET WHEN THE GUN IS GRANTED, AND THAT IS WHY THE GUN WAS IN THE
-- BACKPACK (task 129, found by the gate the moment it could run again).
--
-- `Weapon.watchPlayer` grants on `CharacterAdded`, and at that instant the character model is still
-- being assembled: `FindFirstChildOfClass("Humanoid")` answers nil, this function did nothing, and
-- the Tool stayed in the Backpack with nothing to equip it afterwards. MEASURED in the DEV gate run:
-- three guns handed over, "+2.5s hand, +75.9s backpack, +75.9s backpack" -- the first grant (before
-- a respawn) was equipped and the two after the drive's placement respawn were not, so the player
-- stood at his stand with empty hands and no viewmodel. It is Karen's *"There is no weapon something
-- is broken"* from task 123 round 9 arriving by a second road.
--
-- IT WAITS FOR THE HUMANOID RATHER THAN RETRYING FOR EVER: `WaitForChild` with a timeout, in its own
-- thread so the grant does not block, and it gives up quietly if the character has been replaced
-- again in the meantime. A player who holsters his gun later is untouched -- this fires once, on the
-- grant, exactly like the direct call above it.
-- WHAT HAPPENED, COUNTED (task 129). A grant that silently fails to equip is indistinguishable from
-- a player who put his gun away, and that is how a shooter stood at a stand with it in his Backpack
-- for a whole drive. One table, read by `Weapon.stats`.
Hardware.equipStats = { now = 0, noCharacter = 0, deferred = 0, late = 0, gaveUp = 0 }

function Hardware.equip(tool: Tool, player: Player)
	local character = player.Character
	if character == nil then
		Hardware.equipStats.noCharacter += 1
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:EquipTool(tool)
		Hardware.equipStats.now += 1
		return
	end
	Hardware.equipStats.deferred += 1
	task.spawn(function()
		local arrived = character:WaitForChild("Humanoid", 5)
		if arrived == nil then
			return
		end
		-- ...AND `EquipTool` ITSELF IS NOT READY THE INSTANT THE HUMANOID EXISTS: it needs the
		-- character's root part, which arrives on its own frame, and it fails SILENTLY before then.
		-- So the equip is retried for a bounded second and a bit, and stops the moment the Tool is
		-- where it was asked to be -- or the character has been replaced again, which is somebody
		-- else's grant to finish.
		for _ = 1, 20 do
			if player.Character ~= character or tool.Parent == nil then
				Hardware.equipStats.gaveUp += 1
				return
			end
			if tool.Parent == character then
				Hardware.equipStats.late += 1
				return
			end
			(arrived :: Humanoid):EquipTool(tool)
			task.wait(0.1)
		end
		Hardware.equipStats.gaveUp += 1
	end)
end

function Hardware.muzzlePosition(tool: Tool): Vector3?
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	local muzzle = handle and handle:FindFirstChild("Muzzle") :: Attachment?
	return muzzle and muzzle.WorldPosition
end

-- WHERE THE FIRED BARREL'S MUZZLE IS, AND WHICH WAY IT POINTS (task 92): the frame every client draws
-- the flash and the smoke in. Karen, after playing S2: "when firing this animation where flies light
-- has to be from pipes not from shoulder."
--
-- IT IS COSMETIC AND IT IS DELIBERATELY NOT WHERE THE PELLETS START. `muzzlePosition` above is the
-- ballistic origin and nothing here changes it: the pattern, the safety arc and every hit spec still
-- measure from the one `Muzzle` attachment on the Handle's axis. This adds the barrel's own lateral
-- offset -- `Shotgun.barrelMuzzleOffset`, the one definition of "the right tube is +0.09" -- so the
-- light comes out of the tube that fired instead of the middle of the pair.
function Hardware.muzzleCFrame(tool: Tool, barrel: number?): CFrame?
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	local muzzle = handle and handle:FindFirstChild("Muzzle") :: Attachment?
	if not muzzle then
		return nil
	end
	return (muzzle :: Attachment).WorldCFrame * CFrame.new(Shotgun.barrelMuzzleOffset(barrel, Shotgun.CONFIG))
end

function Hardware.destroy(tool: Tool?)
	if tool then
		tool:Destroy()
	end
end

return Hardware
