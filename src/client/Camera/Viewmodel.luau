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
-- SHARED, AND ONLY FOR THE THREE NAMES the hands are published under (task 93). This module does not
-- load them and does not know what an asset id is: the server does that and parks the templates
-- where a client can reach them.
local HandAssets = require(ReplicatedStorage:WaitForChild("HandAssets"))
-- SHARED, AND ONLY FOR THE EXACT GEOMETRY OF THE NEW GUN (task 99). Pure data: a piece list, the
-- hinge axis, the two chambers and the bead. This module still knows nothing about weapon STATE.
local Gun = require(ReplicatedStorage:WaitForChild("Gun"))

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
-- HOW MANY WOODEN PIECES THE CLONE WAS BUILT WITH (task 99), and it is the same staleness problem
-- one layer over. MEASURED: the server loads Karen's stock through `InsertService` and publishes it
-- about 1.6 s into a session, and the viewmodel has usually built its gun before that -- so the
-- first build takes the exact-geometry fallback and, with nothing to make it stale, KEEPS it for the
-- whole life of that clone. The gun had a plain stock all session and `stats().woodDrawn` said 0.
-- Counted rather than told: this module still knows nothing about asset ids or load order.
local builtWood = -1

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
-- THE SLEEVE (task 99): one olive cylinder per hand, on the hand's own long axis, running back
-- past the near plane so the cuff's open end is never in the picture.
local SLEEVE_NAME = "Sleeve"

local stats = {
	sightMissing = 0,
	rebuilds = 0,
	parts = 0,
	breaksDrawn = 0,
	shellsDrawn = 0,
	handsDrawn = 0,
	handsMissing = 0,
	-- How many of the new gun's wooden pieces were Karen's uploaded MESH rather than the piece
	-- list's own part (task 99). A gun with plain wood is a real state -- the upload did not load --
	-- and it must be visible in a number rather than only on screen.
	woodDrawn = 0,
}

-- THE HANDS (task 93). `handsOn` is not a cache of what is on screen -- the Instances are that -- it
-- is how the OFF branch knows whether it has anything to take off without walking the clone every
-- frame for a part that is almost never there. `clear()` resets both it and the model together, so
-- the two cannot disagree.
local handsOn = false
local handsMissingCounted = false
-- INJECTED, SO A SPEC CAN DRIVE BOTH PATHS -- hands and no hands -- with no server and no network.
-- `nil` restores the real lookup, which is what production uses. The same shape `setSource`,
-- `Loader.setInsert` and `Hardware.setTemplateProvider` already have.
local handTemplates: ((string) -> BasePart?)? = nil

-- WHAT THE WEAPON SAYS ABOUT ITS OWN RELOAD, handed in by the camera every frame (task 96). The
-- server owns the reload and its clock; this module only draws it. `spent` is how many barrels were
-- fired, so only those throw a shell -- the thing a player notices if it is wrong.
local reload = { open = false, spent = 0, loaded = { false, false } }
local openedAt: number? = nil
-- WHEN EACH CHAMBER WAS FED (round 2): the server loads one barrel at a time, so each fresh shell
-- has its own clock -- the moment the replica first said that chamber holds a shell.
local loadedAt: { [number]: number } = {}
local barrelsLocal: CFrame? = nil
-- WHAT ELSE RIDES ON THE BARRELS (task 96, round 2): the bead. An anchored part does not follow its
-- parent, so every piece that swings with the barrel group is placed by hand from the same
-- transform, and its rest offset is read off the clone once.
local ridersLocal: { [BasePart]: CFrame } = {}

function Viewmodel.setReload(state: { open: boolean, spent: number, loaded: { boolean }? }?)
	local next_ = state or { open = false, spent = 0, loaded = { false, false } }
	local open = next_.open == true
	if open and not reload.open then
		openedAt = os.clock() -- the rising edge: the spent shells' clock starts here
		table.clear(loadedAt)
	elseif not open then
		openedAt = nil
		table.clear(loadedAt)
	end
	local loaded = { false, false }
	for index = 1, 2 do
		loaded[index] = (next_.loaded or {})[index] == true
		-- EACH CHAMBER STARTS ITS OWN SLIDE when the server's `Load` step lands, which is what the
		-- replica saying "this barrel holds a shell" means.
		if open and loaded[index] and loadedAt[index] == nil then
			loadedAt[index] = os.clock()
		end
	end
	reload = { open = open, spent = math.clamp(next_.spent or 0, 0, 2), loaded = loaded }
end

function Viewmodel.reloadState()
	return { open = reload.open, spent = reload.spent, loaded = table.clone(reload.loaded), openedAt = openedAt }
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

function Viewmodel.setHandTemplates(fn: ((string) -> BasePart?)?)
	handTemplates = fn
end

-- So a spec can put back what it found, exactly as `getSource` exists for: leaving a fake installed
-- would mean every later frame of that session drew somebody's test hands.
function Viewmodel.getHandTemplates(): ((string) -> BasePart?)?
	return handTemplates
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
	handsOn = false -- the hands went with the model (task 93)
	handsMissingCounted = false
	table.clear(ridersLocal)
	builtFrom = nil
	builtWood = -1 -- the next clone counts its own wood (task 99)
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
	-- ON THE BARRELS WHEN THERE ARE BARRELS (task 96, round 2), so the piece it belongs to owns
	-- it: a bead is part of the rib, not part of the action. `hinge` places it either way, but
	-- the parenting is what says whose it is -- and with the gun in one piece, which is what
	-- the OFF branch and the parts gun are, it hangs on the Handle exactly as before.
	local onBarrels = clone:FindFirstChild(BARRELS_NAME)
	bead.Parent = if onBarrels and onBarrels:IsA("BasePart") then onBarrels else clone
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
local function chamberOffset(barrel: number, config): CFrame
	-- THE NEW GUN KNOWS WHERE ITS OWN CHAMBERS ARE (task 99), and that is the whole of "the shell
	-- goes IN". The old answer put the shell at the barrels' breech END on the Handle's centre line,
	-- which with a mesh gun meant it floated in the gap between the two halves; `Gun.chamber` puts it
	-- on the tube's own BORE LINE, inside the barrel, from the same arithmetic the barrels are drawn
	-- from.
	if config ~= nil and config.NEW_GUN == true then
		return Gun.chamber(barrel, Shotgun.CONFIG)
	end
	local across = Shotgun.barrelMuzzleOffset(barrel, Shotgun.CONFIG)
	local breechZ = Shotgun.CONFIG.HANDLE_SIZE.Z * (0.62 - 0.5)
	return CFrame.new(across.X, across.Y, breechZ)
end

-- WHERE A HAND TEMPLATE COMES FROM. The real answer is the folder
-- `ServerScriptService.ViewmodelAssetsBoot` publishes; a spec injects its own with
-- `setHandTemplates`. Never yields and never loads anything: nil means "no hands", which is the gun
-- Karen has been playing since task 95 and not a failure.
local function handTemplate(name: string): BasePart?
	local fn = handTemplates
	if fn then
		return fn(name)
	end
	local folder = ReplicatedStorage:FindFirstChild(HandAssets.FOLDER_NAME)
	local found = if folder then folder:FindFirstChild(name) else nil
	return if found and found:IsA("BasePart") then found :: BasePart else nil
end

local function addHand(clone: BasePart, parent: Instance, name: string, config): boolean
	local template = handTemplate(name)
	if template == nil then
		return false
	end
	local worn = template:Clone()
	worn.Name = name
	-- The same set every other piece under the camera carries. `CanQuery = false` is the one that is
	-- not cosmetic: workspace.CurrentCamera is a child of Workspace, so this system's own occlusion
	-- cast could otherwise hit a hand an inch from the eye (see the header).
	worn.Anchored = true
	worn.CanCollide = false
	worn.CanQuery = false
	worn.CanTouch = false
	worn.Massless = true
	worn.CastShadow = false
	-- PARKED ON THE GUN, NOT POSED HERE (task 98). `Viewmodel.poseHands` places both hands from the
	-- blended pose every frame, in this same frame, and it is the ONE site that does -- a hand that
	-- was also placed here would be two writers of one CFrame, and the one placed at build time is
	-- the one that could not follow a live tuning change. This puts it on the gun so the `PivotTo`
	-- below cannot drag it in from wherever the template happens to sit in the world.
	worn.CFrame = clone.CFrame
	worn.Parent = parent
	-- THE ARM BEHIND THE HAND (task 99). Karen, 2026-10-01: the left cuff's open end faces the camera
	-- as a big black disc in the break-open frame. A hand model ends at the cuff, so wherever the arm
	-- would continue there is a hole; this runs a plain olive cylinder back along the hand's own long
	-- axis, far enough that its far end is behind the eye in every pose. It is a CHILD of the hand,
	-- and `poseHands` places it from the hand's transform, because an anchored part does not follow
	-- its parent.
	local sleeve = Instance.new("Part")
	sleeve.Name = SLEEVE_NAME
	sleeve.Shape = Enum.PartType.Cylinder -- a cylinder's length runs along its own X, like the hand's
	sleeve.Size = Vector3.new(config.SLEEVE_LENGTH_STUDS, config.SLEEVE_DIAMETER_STUDS, config.SLEEVE_DIAMETER_STUDS)
	sleeve.Color = config.SLEEVE_COLOR
	sleeve.Material = config.SLEEVE_MATERIAL
	sleeve.Anchored = true
	sleeve.CanCollide = false
	sleeve.CanQuery = false
	sleeve.CanTouch = false
	sleeve.Massless = true
	sleeve.CastShadow = false
	sleeve.CFrame = worn.CFrame
	sleeve.Parent = worn
	stats.handsDrawn += 1
	handsOn = true
	return true
end

-- THE HANDS ON THE GUN (task 93). KAREN, 2026-09-27: "right hand grip and left hand pipes like in
-- real life".
--
-- WHOSE PIECE EACH HAND IS, WHICH IS THE WHOLE OF THE RELOAD QUESTION. The RIGHT hand goes on the
-- Handle: it holds the grip, which is part of the BODY, and the body does not move when the gun
-- breaks open. The LEFT hand goes on `Barrels`: it holds the forend, and on a break gun the forend
-- is bolted to the barrels and swings down with them -- so the hand that holds it swings too, and a
-- shooter's left hand really does ride the barrels while they open. Parenting says whose it is; the
-- placement follows from that, exactly as the bead's does (`hinge` places every rider from the
-- barrels' own transform). With the gun in one piece -- the parts gun, or a mesh that arrived
-- without its barrels -- both hands hang on the Handle and one `PivotTo` poses them.
--
-- IDEMPOTENT, AND CALLED EVERY FRAME ON PURPOSE. The templates are loaded on the server and
-- replicate, so they can land after the clone was built; two `FindFirstChild` calls a frame is what
-- buys "the hands appear as soon as they exist" without a second staleness flag.
--
-- FIRST PERSON ONLY, AND IT PUTS THINGS BACK RATHER THAN WALKING AWAY -- the lesson the barrels
-- taught in task 96 round 2. The OFF branch is the shoulder camera Karen accepted on 2026-09-25 and
-- draws no hands at all, including in a session that flipped the flag mid-life.
function Viewmodel.hands(made: Model, config)
	local clone = made.PrimaryPart
	if clone == nil then
		return
	end
	if config.FIRST_PERSON ~= true then
		if handsOn then
			Viewmodel.clearHands(clone)
		end
		return
	end
	local barrels = clone:FindFirstChild(BARRELS_NAME)
	local leftParent: Instance = if barrels and barrels:IsA("BasePart") then barrels else clone
	local missing = false
	if clone:FindFirstChild(HandAssets.RIGHT) == nil then
		missing = not addHand(clone, clone, HandAssets.RIGHT, config) or missing
	end
	if leftParent:FindFirstChild(HandAssets.LEFT) == nil then
		missing = not addHand(clone, leftParent, HandAssets.LEFT, config) or missing
	end
	-- COUNTED ONCE PER CLONE, NOT PER FRAME. A gun drawn without hands is a real state -- the load
	-- failed, or the asset was moderated away -- and it must be visible in `stats()` rather than in a
	-- log line nobody reads or a warning sixty times a second. A spec asserts it is zero for a real
	-- session and that it is not zero when the templates are taken away.
	if missing and not handsMissingCounted then
		handsMissingCounted = true
		stats.handsMissing += 1
	end
end

-- Every hand this module has drawn, gone. Walks the clone rather than remembering where it put them:
-- the left hand's parent depends on whether the gun has barrels, and a walk cannot disagree with
-- what is actually on screen.
function Viewmodel.clearHands(clone: BasePart)
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant.Name == HandAssets.RIGHT or descendant.Name == HandAssets.LEFT then
			descendant:Destroy()
		end
	end
	handsOn = false
	handsMissingCounted = false
end

-- BOTH HANDS, PLACED FROM THIS FRAME'S POSE (task 98), and this is the one site that places them.
--
-- WHY EVERY FRAME. Until task 98 a hand was posed once, when the clone was built, and carried along
-- by the `PivotTo`. That had two costs: the glove sat in the carry's place even in the aimed view --
-- one hand pose for the whole game -- and a number changed while a Studio session ran could not
-- reach it, which is exactly what `tools/pose.py` exists to do. `Mode.handOffsetAt` answers the
-- BLENDED pose, so the hands move with the gun through the raise, the aim and the break.
--
-- WHOSE FRAME EACH ONE IS MEASURED IN is the same rule as before and it is the whole reload
-- question: the RIGHT hand holds the grip, which is part of the body, so it is placed from the gun's
-- transform; the LEFT hand holds the forend, which is bolted to the barrels, so it is placed from
-- the BARRELS' transform and swings down with them. With the gun shut the two transforms are equal,
-- so a shut gun's hands are bit-for-bit where task 93 put them.
function Viewmodel.poseHands(gunCFrame: CFrame, barrelsCFrame: CFrame, state: Mode.State, config)
	local made = model
	local clone = made and made.PrimaryPart
	if clone == nil or config.FIRST_PERSON ~= true then
		return -- the OFF branch draws no hands at all; `Viewmodel.hands` is what takes them off
	end
	-- WHICH WAY THE ARM RUNS, and it is measured off the model rather than assumed: the right hand's
	-- fingertips are at its mesh +X and the left hand's at its -X (`Camera.Config`'s HAND_LEFT_YAW
	-- comment, task 93), so the wrist -- and the sleeve -- runs the other way on each.
	local function placeSleeve(hand: BasePart, towardFingers: number)
		local sleeve = hand:FindFirstChild(SLEEVE_NAME)
		if sleeve and sleeve:IsA("BasePart") then
			local back = -towardFingers * (hand.Size.X / 2 + sleeve.Size.X / 2 - config.SLEEVE_OVERLAP_STUDS);
			(sleeve :: BasePart).CFrame = hand.CFrame * CFrame.new(back, 0, 0)
		end
	end

	local right = clone:FindFirstChild(HandAssets.RIGHT)
	if right and right:IsA("BasePart") then
		(right :: BasePart).CFrame = gunCFrame * Mode.handOffsetAt("right", state, config)
		placeSleeve(right :: BasePart, 1)
	end
	-- Walked rather than remembered, for the reason `clearHands` gives: the left hand's parent is the
	-- barrels when the gun has them and the Handle when it does not.
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant.Name == HandAssets.LEFT and descendant:IsA("BasePart") then
			(descendant :: BasePart).CFrame = barrelsCFrame * Mode.handOffsetAt("left", state, config)
			placeSleeve(descendant :: BasePart, -1)
		end
	end
end

-- THE NEW GUN, BUILT RATHER THAN CLONED (task 99, behind `NEW_GUN`). Karen, 2026-10-01:
-- "shooting, weapon, reload, all has to be perfect". The cloned mesh is one AI model cut in two, so
-- the break-open frame showed a torn breech and a shell in the gap; this builds the gun from
-- `ReplicatedStorage.Gun`'s exact piece list instead -- round barrels, two bores at each end, a
-- silver action, and a hinge pin the barrel group really turns about.
--
-- FIRST PERSON ONLY, AND LOCAL ONLY. The Tool's Handle is untouched and every other player sees the
-- uploaded mesh exactly as before: `Weapon.Hardware` is still the only writer of Tool Instances
-- (docs/design/shotgun.md 3.1), and this model lives under `workspace.CurrentCamera`.
--
-- THE SAME SHAPE AS THE CLONE, deliberately: an invisible `Handle` of `HANDLE_SIZE` is the
-- PrimaryPart (so every pose, the pivot and the near-plane arithmetic are unchanged), a `Barrels`
-- envelope holds everything that swings, and the `Sight` and `Muzzle` attachments are where the rest
-- of the system already looks for them.
local function buildNewGun(config): Model
	local made = Instance.new("Model")
	made.Name = "DrivenHuntViewmodel"

	local function dress(part: BasePart)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false -- see the header: an occlusion ray must not hit our own viewmodel
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = false
	end

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Shotgun.CONFIG.HANDLE_SIZE
	handle.Transparency = 1 -- the envelope, exactly as the worn gun's Handle is (Task 71)
	dress(handle)
	handle.Parent = made
	made.PrimaryPart = handle

	-- THE BARREL GROUP'S OWN ENVELOPE, and it is what `Viewmodel.hinge` turns. Every piece in the
	-- group is a CHILD of it, so "what swings" is a parent rather than a list in two files -- the
	-- same rule the old mesh gun's `Barrels` piece already set.
	local at = Gun.layout(Shotgun.CONFIG)
	local barrels = Instance.new("Part")
	barrels.Name = BARRELS_NAME
	barrels.Size = Vector3.new(0.3, 0.2, at.barrelLength)
	barrels.Transparency = 1
	dress(barrels)
	barrels.CFrame = handle.CFrame * CFrame.new(0, 0, at.barrelZ)
	barrels.Parent = handle

	-- KAREN'S WOOD WHERE THERE IS ANY (task 99). The METAL is exact geometry because Meshy is weak
	-- on machined surfaces; the WOOD is exactly what Meshy is good at, so the forend and the stock
	-- are her own models when the server has published them and the piece list's own part when it
	-- has not. The silhouette is the same either way -- `Gun.WOOD_LENGTH_STUDS` is what the mesh is
	-- scaled to -- so a gun whose upload failed to load is a gun with a plain wooden stock, not a
	-- gun with a hole in it.
	local woodFolder = ReplicatedStorage:FindFirstChild(Gun.FOLDER_NAME)
	local function woodFor(name: string): BasePart?
		local found = if woodFolder then woodFolder:FindFirstChild(name) else nil
		return if found and found:IsA("BasePart") then found :: BasePart else nil
	end

	for _, piece in ipairs(Gun.pieces(Shotgun.CONFIG)) do
		local wood = if Gun.WOOD_KEYS[piece.name] ~= nil then woodFor(piece.name) else nil
		local part: BasePart
		local offset = piece.offset
		if wood ~= nil then
			-- The SIZE came from the manifest when the server published it (the consumer sets it,
			-- design 6.1); the TURN is this gun's, because the same model on another gun would be
			-- turned differently.
			part = wood:Clone()
			offset = piece.offset * CFrame.Angles(0, math.rad(Gun.WOOD_ROTATION_DEG[piece.name]), 0)
			stats.woodDrawn += 1
		else
			local made_ = Instance.new("Part")
			made_.Size = piece.size
			made_.Shape = piece.shape
			made_.Color = piece.color
			made_.Material = piece.material
			made_.Reflectance = piece.reflectance or 0
			part = made_
		end
		part.Name = piece.name
		dress(part)
		part.CFrame = handle.CFrame * offset
		part.Parent = if piece.group == "barrels" then barrels else handle
	end

	-- WHERE THE REST OF THE SYSTEM LOOKS. `Mode.aimOffset` solves the aimed pose from `Sight`, and
	-- `Weapon.Effects` draws the flash at `Muzzle`; both are read off the PrimaryPart, so they are
	-- added here rather than left to a gun that was never cloned from a Tool.
	local sight = Instance.new("Attachment")
	sight.Name = SIGHT_NAME
	sight.CFrame = Gun.sight(Shotgun.CONFIG)
	sight.Parent = handle

	local muzzle = Instance.new("Attachment")
	muzzle.Name = MUZZLE_NAME
	muzzle.CFrame = Gun.muzzle(Shotgun.CONFIG)
	muzzle.Parent = handle

	-- NO DRAWN BEAD MARKER: this gun carries its own `Bead` piece, on the rib, at exactly
	-- `Gun.beadOffset` -- the same expression `Gun.sight` answers with. The light is still added,
	-- for the reason it was added in task 92: a gun inches from the eye is lit by the sun alone.
	addFillLight(handle, config)

	builtWood = if woodFolder then #woodFolder:GetChildren() else 0
	stats.rebuilds += 1
	local parts = 0
	for _, descendant in ipairs(made:GetDescendants()) do
		if descendant:IsA("BasePart") then
			parts += 1
		end
	end
	stats.parts = parts
	return made
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
		-- AND WHETHER THE WOOD HAS ARRIVED SINCE THE GUN WAS BUILT (task 99). On the same throttle
		-- as the source, for the same reason: it is a container lookup, not something a frame needs.
		-- `builtWood` is -1 until a new gun has been built, so this never fires for the cloned one.
		if config.NEW_GUN == true and builtWood >= 0 then
			local folder = ReplicatedStorage:FindFirstChild(Gun.FOLDER_NAME)
			if (if folder then #folder:GetChildren() else 0) ~= builtWood then
				stale = true
			end
		end
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
		-- WHICH GUN (task 99). ON: built from `ReplicatedStorage.Gun`'s exact pieces. OFF: the
		-- Tool's Handle, cloned, which is the gun this repo has drawn since Task 71 and the one
		-- every other player sees in both cases.
		model = if config.NEW_GUN == true then buildNewGun(config) else build(handle, config)
		builtFrom = handle
	end

	local made = model :: Model
	if made.Parent ~= cam then
		made.Parent = cam
	end
	-- THE HANDS, BEFORE THE POSE. They are children of the clone (and of its barrels), so the
	-- `PivotTo` below carries them with everything else; adding them after it would leave them one
	-- frame behind the gun.
	Viewmodel.hands(made, config)
	-- THE GUN'S OWN SIGHT DECIDES THE AIMED POSE (task 90): read off the clone every frame, because
	-- a rebuild (the mesh arriving late, `Hardware.upgrade`) can change it mid-life.
	local gun = camCFrame * Mode.viewmodelOffset(state, Viewmodel.sight(), config)
	made:PivotTo(gun)
	-- THE BARRELS FIRST, THEN THE HANDS ON THEM (task 98): `hinge` answers with the transform the
	-- barrel group ended up at -- the gun's own when there is nothing to hinge -- and the left hand
	-- is placed from that, because it holds a forend that swings with them.
	local barrels = Viewmodel.hinge(gun, state, config)
	Viewmodel.poseHands(gun, barrels, state, config)
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
--
-- IT ANSWERS WITH THE TRANSFORM THE BARREL GROUP ENDED UP AT (task 98) -- `gunCFrame` itself when
-- the gun is one piece, or when there is no clone at all -- because the LEFT HAND is placed from it
-- and `Viewmodel.poseHands` must not work that transform out a second time.
function Viewmodel.hinge(gunCFrame: CFrame, state: Mode.State, config): CFrame
	local made = model
	local clone = made and made.PrimaryPart
	-- FIRST PERSON ONLY, AND THE WHOLE DRAWN RELOAD WITH IT (round 2, finding 2). The gun wears its
	-- barrels as a separate piece in EVERY build -- the server welds them whatever the flag says --
	-- so without this the flag-off camera, which is the default one, would swing them and draw
	-- shells the moment a player reloaded. `Mode.breakAngleDeg` already refuses; this refuses the
	-- rest, and clears anything a session that flipped the flag left behind.
	-- FIRST PERSON ONLY, AND IT PUTS THINGS BACK RATHER THAN WALKING AWAY. The gun wears its barrels
	-- as a separate piece in EVERY build -- the server welds them whatever the flag says -- so the
	-- flag-off camera must draw no shells and swing nothing. `Mode.breakAngleDeg` already answers 0
	-- there, so the barrels are still PLACED, at rest: returning early instead left them wherever a
	-- first-person frame had last put them, which the OFF-branch case caught by finding them 35
	-- degrees off the body.
	local firstPerson = config.FIRST_PERSON == true
	if clone and not firstPerson then
		Viewmodel.clearShells(clone)
	end
	local barrels = clone and clone:FindFirstChild(BARRELS_NAME)
	if not (barrels and barrels:IsA("BasePart")) then
		return gunCFrame -- one piece: the barrels' frame IS the gun's frame
	end
	if barrelsLocal == nil then
		barrelsLocal = clone.CFrame:ToObjectSpace((barrels :: BasePart).CFrame)
	end
	local angle = Mode.breakAngleDeg(state, config)
	-- THE AXIS THE BARRELS TURN ABOUT. The new gun has a PIN, drawn at `Gun.hinge`, and the barrels
	-- must turn about exactly that line or the pin is something they swing around rather than on --
	-- so the number comes from the gun's own geometry rather than from a pose the Director tunes.
	-- The old mesh gun keeps `BREAK_HINGE_STUDS`, which is where its knuckle was measured.
	local hinge = if config.NEW_GUN == true
		then CFrame.new(Gun.hinge(Shotgun.CONFIG))
		else CFrame.new(config.BREAK_HINGE_STUDS)
	-- NEGATIVE ABOUT X IS THE MUZZLE GOING DOWN, which is what "break open" means: a part's
	-- LookVector is its -Z, and `CFrame.Angles(+t, 0, 0)` takes (0, 0, -1) to (0, sin t, -cos t) --
	-- i.e. UP. Measured the hard way: the first run of `camera_client.spec` caught the barrels
	-- swinging toward the sky.
	local swing = hinge * CFrame.Angles(-math.rad(angle), 0, 0) * hinge:Inverse()
	local swungGun = gunCFrame * swing
	local barrelPart = barrels :: BasePart
	barrelPart.CFrame = swungGun * (barrelsLocal :: CFrame)
	-- THE BEAD RIDES WITH THEM (round 1's own report, and the Director's reading of the frames):
	-- a bead is a sight ON THE BARRELS, so with the gun open it belongs down at the muzzle where
	-- the barrels are and not floating where the muzzle used to be. Placed from the same
	-- transform, and shut that transform is identity -- so the bead is bit-for-bit where it was
	-- and the shot line is untouched.
	-- EVERY PIECE THE BARREL GROUP OWNS RIDES WITH IT, and since task 99 that is a PARENT rather
	-- than a list of names: anything parented under `Barrels` swings, because that is what being
	-- part of the barrel group means. The old mesh gun has only the bead down there, so it behaves
	-- exactly as it did; the new gun has two tubes, four bores, the rib, the bead, the breech face,
	-- the hinge hook and the wooden forend, and none of them had to be named here.
	--
	-- AN ANCHORED PART DOES NOT FOLLOW ITS PARENT, which is why this loop exists at all: every rider
	-- is placed by hand from the swung transform, with its rest offset read off the clone ONCE.
	--
	-- THE LEFT HAND WAS A RIDER TOO (task 93) AND IS NOT ANY MORE (task 98): it still swings with the
	-- barrels, but `Viewmodel.poseHands` places it from the transform this function RETURNS, because
	-- its offset is a blended pose that changes every frame rather than a rest offset. A captured
	-- offset is exactly what could not follow a live tuning change.
	for _, descendant in ipairs(barrelPart:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name ~= HandAssets.LEFT then
			if ridersLocal[descendant] == nil then
				ridersLocal[descendant] = clone.CFrame:ToObjectSpace(descendant.CFrame)
			end
			descendant.CFrame = swungGun * ridersLocal[descendant]
		end
	end
	-- ...and the OLD gun's drawn bead hangs on the Handle when the clone has no barrels to hang it
	-- on, so it is still looked for by name there. One loop could not do both: on the new gun the
	-- bead is already a child of `Barrels` and would be placed twice.
	for _, descendant in ipairs(clone:GetChildren()) do
		if descendant:IsA("BasePart") and (descendant.Name == MARKER_NAME or descendant.Name == BEAD_NAME) then
			if ridersLocal[descendant] == nil then
				ridersLocal[descendant] = clone.CFrame:ToObjectSpace(descendant.CFrame)
			end
			descendant.CFrame = swungGun * ridersLocal[descendant]
		end
	end
	if angle > 0 then
		stats.breaksDrawn += 1
	end
	if firstPerson then
		Viewmodel.shells(swungGun, config)
	end
	return swungGun
end

-- THE SHELLS (task 96): spent ones pop out of the barrels that fired, fresh ones slide into the
-- chambers. They are drawn in the BARRELS' frame, so they swing with them, and they live only while
-- the gun is open -- `setReload` gives this module the weapon's own answer and the clock starts at
-- the rising edge of "open".
--
-- Anchored and moved by hand rather than thrown: nothing under `workspace.CurrentCamera` may be
-- simulated (a physics part parented to the camera is a part in the world that nobody can see).
-- Every shell this module has drawn, gone. One site, because two places need it: the gun shutting,
-- and the flag-off branch refusing to draw a reload at all.
function Viewmodel.clearShells(clone: BasePart)
	for _, child in ipairs(clone:GetChildren()) do
		local name = child.Name
		if string.sub(name, 1, #SPENT_NAME) == SPENT_NAME or string.sub(name, 1, #FRESH_NAME) == FRESH_NAME then
			child:Destroy()
		end
	end
end

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

	local now = os.clock()
	local elapsed = now - started
	local wanted = {}
	-- SPENT: one per barrel that FIRED, rising out of its chamber and back over the shoulder. The
	-- count comes from the last shut snapshot (`Camera.breakFrom`), because the break that opened
	-- the gun emptied it in the same breath.
	local ejectT = math.clamp(elapsed / config.SHELL_EJECT_SECONDS, 0, 1)
	if ejectT < 1 then
		for barrel = 1, reload.spent do
			wanted[SPENT_NAME .. barrel] = chamberOffset(barrel, config)
				* CFrame.new(0, config.SHELL_EJECT_RISE_STUDS * ejectT, config.SHELL_EJECT_RISE_STUDS * ejectT)
		end
	end
	-- FRESH: ONE PER CHAMBER THE SERVER HAS ACTUALLY LOADED, each sliding forward from its own
	-- moment. Round 1 drew them on a timer and for `max(spent, 1)` barrels, so a two-shell reload
	-- showed one shell and an unfired barrel was fed one it never got.
	for barrel = 1, 2 do
		local at = loadedAt[barrel]
		if reload.loaded[barrel] and at then
			local feedT = math.clamp((now - at) / config.SHELL_FEED_SECONDS, 0, 1)
			wanted[FRESH_NAME .. barrel] = chamberOffset(barrel, config)
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
