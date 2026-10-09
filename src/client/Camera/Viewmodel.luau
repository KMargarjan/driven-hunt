--!strict
-- Camera.Viewmodel: the only writer of the first-person weapon model under workspace.CurrentCamera.
--
-- IT BUILDS THE GUN; IT NO LONGER CLONES THE TOOL'S HANDLE (task 114). Karen's model B is the only
-- first-person gun now -- the flag that chose between two guns retired when she accepted it -- so
-- the one build path is
-- `buildNewGun`, from `ReplicatedStorage.Gun`'s piece list and the two hinge-group meshes the server
-- publishes. The Tool's own Handle is still never touched: ServerScriptService.Weapon.Hardware stays
-- the only writer of Tool Instances (docs/design/shotgun.md section 3.1), the WORLD gun every other
-- player sees is unchanged, and the Handle is read here for exactly two things -- whether the player
-- is holding the gun at all, and when to rebuild. The model is local, unreplicated and built only
-- when that Handle changes identity, never per frame.
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

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mode = require(script.Parent.Mode)
-- SHARED, AND ONLY FOR `Shotgun.CONFIG` -- the Handle's size, which is the envelope every pose and
-- the near-plane arithmetic are written against. `Shotgun.barrelMuzzleOffset` was read here too
-- until task 114, for the cloned gun's tubes; the WORLD gun still reads it, in
-- `ServerScriptService.Weapon.Hardware`. This module knows nothing about weapon STATE.
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
-- SHARED, AND ONLY FOR THE THREE NAMES the hands are published under (task 93). This module does not
-- load them and does not know what an asset id is: the server does that and parks the templates
-- where a client can reach them.
local HandAssets = require(ReplicatedStorage:WaitForChild("HandAssets"))
-- SHARED, AND ONLY FOR THE EXACT GEOMETRY OF THE NEW GUN (task 99). Pure data: a piece list, the
-- hinge axis, the two chambers and the bead. This module still knows nothing about weapon STATE.
local Gun = require(ReplicatedStorage:WaitForChild("Gun"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))

local Viewmodel = {}

local source: (() -> BasePart?)? = nil
local model: Model? = nil
local builtFrom: BasePart? = nil

-- THE GUN GOES STALE WHEN ITS MESHES ARRIVE (task 99), and since task 114 that is the ONLY way it
-- can. While the gun was a clone of the Tool's Handle it also went stale when that Handle's children
-- changed -- `Weapon.Hardware.upgrade` swaps ten welded parts for a `Model` about a second into a
-- session -- and two watchers on the Handle said so. The gun is BUILT now and shares nothing with the
-- Handle's children, so what it waits for is its own two hinge-group meshes.
--
-- One flag, cleared when the rebuild happens.
local stale = false
-- HOW MANY MESH PIECES THE GUN WAS BUILT WITH. MEASURED: the server loads Karen's model through
-- `InsertService` and publishes it about 1.6 s into a session, and the viewmodel has usually built
-- its gun before that -- so the first build takes the measured-box fallback and, with nothing to
-- make it stale, KEEPS it for the whole life of that model. The gun had plain boxes all session and
-- `stats().meshesDrawn` said 0. Counted rather than told: this module still knows nothing about
-- asset ids or load order.
local builtMeshes = -1
-- ...AND HOW MANY OF THEM THIS CLIENT HAD ACTUALLY DOWNLOADED (task 133). Karen: *"no weapon when
-- it loads"*. `builtMeshes` above counts the templates the server has PUBLISHED, which is a fact
-- about the server; whether this client can DRAW one is a different fact, and the gun was built
-- against the first.
local builtReady = -1
-- Every mesh id this client has been ASKED to fetch, so it is asked once. A template parked in
-- `ReplicatedStorage` is never rendered, so nothing fetches it on its own: `GetAssetFetchStatus`
-- would answer `None` for ever and the gun would wear its fallback boxes for the whole session.
-- `PreloadAsync` is what turns "published" into "downloaded", and it yields, so it is spawned.
local requested: { [string]: boolean } = {}
-- ...AND EVERY ID THAT HAS EVER READ `Success` ON THIS CLIENT, which stays ready for the rest of the
-- session. MEASURED: the frame after the gun was rebuilt with its meshes, both groups read `Loading`
-- again for about 250 ms and then `Success` -- the fresh clone asks for content the client already
-- has, so the status describes a REQUEST and not the cache behind it. Without this the gun went
-- mesh -> box -> mesh in a quarter of a second, three builds where one was needed. Downloaded is a
-- one-way fact: nothing takes a mesh off a client mid-session.
local arrived: { [string]: boolean } = {}

-- THE NAME THIS MODULE WRITES ON THE GUN IT BUILDS (task 90; one gun since task 114). `Sight` is
-- where `Mode.aimOffset` solves the aimed pose from, and `buildNewGun` adds it. The drawn `SightBead`
-- marker went with the cloned gun it existed for: model B carries its own `Bead` piece, on the rib,
-- at exactly `Gun.beadOffset`.
local SIGHT_NAME = "Sight"
-- `Muzzle` is the second attachment `buildNewGun` adds, beside `Sight` (task 92): `Weapon.Effects`
-- draws the flash at it. `ViewmodelFill` is the one light this module adds.
local MUZZLE_NAME = "Muzzle"
local FILL_NAME = "ViewmodelFill"
-- THE PIECE THAT HINGES (task 96). `Weapon.Hardware` wears the gun as two welded meshes since the
-- break-action reload, and this is the one the barrels live in; `SpentShell`/`FreshShell` are the
-- only other things this module ever adds to the clone.
local BARRELS_NAME = "Barrels"
local SPENT_NAME = "SpentShell"
local FRESH_NAME = "FreshShell"

-- CAN THIS CLIENT DRAW THIS MESH YET? The question task 133 was missing.
--
-- MEASURED IN THE FOREST TEST, with a per-frame trace from t = 0: the gun was built from the
-- measured boxes at 2.050 s (3 of its 5 parts on screen), the server published model B at 2.7 s, the
-- rebuild swapped both hinge groups for their MESHES at 2.942 s -- and from there to 3.332 s the
-- whole gun on screen was the BEAD: `VISIBLE=1`, because a `MeshPart` whose mesh has not been
-- downloaded renders as NOTHING and the boxes behind it had been dropped. 390 ms on this machine,
-- whose content cache was warm. On a cold or slow client that is Karen's *"no weapon when it
-- loads"*, for as long as the download takes.
--
-- SO READINESS IS READ, NOT ASSUMED, and the one signal for it is the engine's own:
--   ContentProvider:GetAssetFetchStatus
--   https://create.roblox.com/docs/reference/engine/classes/ContentProvider#GetAssetFetchStatus
-- `Success` is the only value that means "the renderer has this". `None` means nobody has asked yet,
-- so this asks -- see `requested` -- and `Loading`/`Failure`/`TimedOut` all mean the same thing to a
-- player looking at his hands: draw the box instead.
--
-- A NON-MESH PART IS ALWAYS READY: the fallback pieces are plain `Part`s built here, with nothing to
-- download. And a status this cannot read at all answers READY rather than withholding the real gun,
-- because a guard that failed closed would ship the boxes to everybody for ever.
function Viewmodel.meshReady(part: Instance): boolean
	if not part:IsA("MeshPart") then
		return true
	end
	local id = (part :: MeshPart).MeshId
	if id == nil or id == "" then
		return false
	end
	local ok, status = pcall(function()
		return ContentProvider:GetAssetFetchStatus(id)
	end)
	if not ok then
		return true
	end
	if status == Enum.AssetFetchStatus.Success then
		arrived[id] = true
		return true
	end
	if arrived[id] then
		return true -- it came down earlier in this session; see `arrived`
	end
	-- NOBODY HAS ASKED FOR IT YET, SO ASK. Once per id per session: `PreloadAsync` yields, and a
	-- call per frame per piece would be a queue nothing drains.
	if not requested[id] then
		requested[id] = true
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync({ part })
			end)
		end)
	end
	return false
end

-- How much of the published model this client can actually draw RIGHT NOW. The second half of the
-- staleness signal: when a download lands this number moves, the gun is rebuilt, and the mesh
-- replaces its box IN PLACE -- so there is never a frame with neither.
local function readyMeshes(): number
	local folder = ReplicatedStorage:FindFirstChild(Gun.FOLDER_NAME)
	if folder == nil then
		return 0
	end
	local ready = 0
	for _, child in ipairs(folder:GetChildren()) do
		if Viewmodel.meshReady(child) then
			ready += 1
		end
	end
	return ready
end

local stats = {
	rebuilds = 0,
	parts = 0,
	breaksDrawn = 0,
	shellsDrawn = 0,
	flashesDrawn = 0,
	handsDrawn = 0,
	handsMissing = 0,
	-- How many of the new gun's wooden pieces were Karen's uploaded MESH rather than the piece
	-- list's own part (task 99). A gun with plain wood is a real state -- the upload did not load --
	-- and it must be visible in a number rather than only on screen.
	meshesDrawn = 0,
	-- ...AND HOW MANY WERE PUBLISHED BUT NOT DOWNLOADED YET (task 133), so "the gun is wearing its
	-- boxes because the mesh has not arrived" is a NUMBER and not only a picture. Per build, like
	-- `meshesDrawn`.
	meshesWaiting = 0,
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
-- THE CLOCK, AS A SEAM (task 111, round 2). `os.clock` everywhere meant the one thing the loading
-- motion does -- move over time -- could not be asserted at all: the player's own camera loop clears
-- the reload state on every frame it draws, so a spec that waits loses the state, and a spec that
-- does not wait only ever sees weight 0. The Reviewer's finding was exactly that: the case passed
-- with the whole feature deleted. The same shape as `setSource` and `setHandTemplates`: a spec
-- installs its own clock, steps it, and reads the DRAWN hand.
local clock: () -> number = os.clock

function Viewmodel.setClock(fn: (() -> number)?)
	clock = fn or os.clock
end

function Viewmodel.getClock(): () -> number
	return clock
end

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
		openedAt = clock() -- the rising edge: the spent shells' clock starts here
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
			loadedAt[index] = clock()
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

-- Nil unless the viewmodel is actually in the camera (design section 9.2 item 6). The model is kept
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
	builtMeshes = -1 -- the next build counts its own wood (task 99)
	builtReady = -1
	stale = false
end

-- WHERE THE GUN SAYS ITS BEAD IS, in the model's own frame, or nil when it carries no `Sight`.
-- `PrimaryPart` is the Handle `buildNewGun` makes and `WorldPivot` is never written, so an
-- attachment's CFrame is already relative to the model's pivot -- exactly the frame `Mode.aimOffset`
-- wants.
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

-- ...AND IT FOLLOWS THE DATA WHILE THE SESSION RUNS (task 102). The four numbers moved into
-- `poses.json`'s `look.fill` so the Director can tune them live, and a light whose properties were
-- only written once at build time would not have moved until the next rebuild -- which is exactly
-- the hours-per-tweak loop the content lane exists to end. Four comparisons per frame, and a write
-- only when one of them differs.
local function applyFill(made: Model, config)
	local clone = made.PrimaryPart
	local attachment = clone and clone:FindFirstChild(FILL_NAME .. "At")
	local light = attachment and attachment:FindFirstChildOfClass("PointLight")
	if not (attachment and attachment:IsA("Attachment") and light) then
		return false
	end
	if light.Brightness ~= config.VIEWMODEL_FILL_BRIGHTNESS then
		light.Brightness = config.VIEWMODEL_FILL_BRIGHTNESS
	end
	if light.Range ~= config.VIEWMODEL_FILL_RANGE_STUDS then
		light.Range = config.VIEWMODEL_FILL_RANGE_STUDS
	end
	if light.Color ~= config.VIEWMODEL_FILL_COLOR then
		light.Color = config.VIEWMODEL_FILL_COLOR
	end
	local wanted = CFrame.new(config.VIEWMODEL_FILL_OFFSET_STUDS)
	if (attachment :: Attachment).CFrame.Position ~= wanted.Position then
		(attachment :: Attachment).CFrame = wanted
	end
	return true
end

-- WHERE THE DRAWN GUN'S MUZZLE IS, in WORLD space, for the fired barrel (task 92) -- or nil when
-- there is no viewmodel on screen. The caller then draws at the world gun's muzzle instead, which is
-- the right answer in third person.
--
-- The barrel's own lateral offset comes from `Gun.barrelOffset`, the ONE definition of which tube is
-- which on this gun -- this module does not know that the two bores are 0.076 apart and must not
-- learn it. (`Shotgun.barrelMuzzleOffset` is the same answer for the WORLD gun, whose tubes are a
-- different model's.)
function Viewmodel.muzzle(barrel: number?): CFrame?
	local made = Viewmodel.current()
	local clone = made and made.PrimaryPart
	local attachment = clone and clone:FindFirstChild(MUZZLE_NAME)
	if not (attachment and attachment:IsA("Attachment")) then
		return nil
	end
	-- THE GUN'S OWN BORE LINE (round 1, finding 2; one gun since task 114). The `Muzzle` attachment
	-- sits on the HANDLE'S AXIS, so the rise from that axis up to the barrels is added here -- this
	-- gun's tubes are 0.076 apart -- and `Gun.barrelOffset` is the one definition of which tube is
	-- which. Until task 114 the model carried a `DHNewGun` attribute so this could tell two guns
	-- apart without a config; with one gun there is nothing to ask.
	return (attachment :: Attachment).WorldCFrame * CFrame.new(Gun.barrelOffset(barrel, Shotgun.CONFIG))
end

-- ONE SHELL: red plastic, a brass base behind it, and -- on the new gun -- the brass RIM that is the
-- whole of "this chamber is loaded". Drawn for one player and never replicated.
--
-- THE OFFSETS ARE APPLIED (round 2 note). They were computed and then never written anywhere, so
-- both cylinders sat at the model origin and the brass base was wholly inside the red body: a shell
-- with no brass head at all, which is also why there was nothing to show at a chamber mouth. The
-- three parts now lie end to end along the shell's own X, mouth forward, from the ONE layout
-- `Gun.shellLayout` owns -- the same one `Gun.chamber` seats the shell by.
--
-- SINCE TASK 105 THE SHELL IS MODEL B'S OWN CARTRIDGE where the server has published it: a red
-- 12-gauge hull with a brass head, which is what the artist drew and what the chambers it goes in
-- were drawn around. The three cylinders stay as the fallback, for the reason every fallback in this
-- file stays: an upload that did not load must leave a shell, not nothing.
local function gunTemplate(name: string): BasePart?
	local folder = ReplicatedStorage:FindFirstChild(Gun.FOLDER_NAME)
	local found = if folder then folder:FindFirstChild(name) else nil
	return if found and found:IsA("BasePart") then found :: BasePart else nil
end

-- WHICH SHELL IS BEING DRAWN, asked once and answered in one place: the uploaded cartridge when the
-- server has published it, the three drawn cylinders otherwise. Both numbers below turn on it, so
-- they cannot disagree about which shell they are describing. Until task 114 it also asked which gun;
-- there is one gun now, so all that is left is whether the upload arrived.
local function shellIsMesh(): boolean
	return gunTemplate(Gun.SHELL_TEMPLATE_NAME) ~= nil
end

-- HOW FAR BEHIND A SHELL'S PIVOT ITS RIM IS, which is the one number that seats it: `Gun.chamber`
-- says where the RIM goes and `PivotTo` places the PIVOT. The mesh shell's pivot is its own bounding
-- box centre -- Roblox puts it there, and `assets/uploads.json`'s row records that the model's centre
-- is its box's -- so half its length is the answer; the drawn one's pivot is its Body part, and
-- `Gun.shellLayout` owns that answer.
local function shellBack(config): number
	if shellIsMesh() then
		return Gun.SHELL_MESH_SIZE_STUDS.X / 2
	end
	return Gun.shellLayout(config.SHELL_SIZE_STUDS, config.SHELL_BASE_FRACTION).back
end

-- ...AND HOW FAR IT IS TURNED, WHICH HAS TO BE APPLIED WHERE IT SURVIVES (task 107, round 3).
--
-- ROUND 2'S FINDING, AND IT IS AN ENGINE FACT, NOT A STYLE POINT. The import's half turn was written
-- onto the cloned PART, which `Viewmodel.shells` then threw away: `Model:PivotTo` moves the model so
-- its PIVOT lands on the CFrame it is given, and with `PrimaryPart` set and `WorldPivot` never
-- written the pivot IS that part -- the rule `Viewmodel.sight`, `camera_client.spec`'s pivot case and
-- `Gun.shellLayout`'s `back` all already lean on. So the part's own CFrame was overwritten on the
-- frame it was made and every frame after, and the uploaded shell kept only the file's quarter turn:
-- brass head up the barrel, which is the pre-fix state.
--
-- SO THE TURN LIVES AT THE PLACEMENT SITE, composed with the quarter turn rather than fighting it.
-- The DRAWN shell is three cylinders this file lays out mouth-at-+X and never sends through an
-- importer, so it takes the quarter turn alone.
local function shellTurnDeg(): number
	if shellIsMesh() then
		return Gun.SHELL_ROTATION_DEG
	end
	return Gun.MESH_FILE_TURN_DEG
end

local function makeShell(name: string, config, parent: Instance): Model
	local shell = Instance.new("Model")
	shell.Name = name
	local size = config.SHELL_SIZE_STUDS
	local layout = Gun.shellLayout(size, config.SHELL_BASE_FRACTION)
	local template = if shellIsMesh() then gunTemplate(Gun.SHELL_TEMPLATE_NAME) else nil
	if template ~= nil then
		-- ONE PART, AND ITS CFRAME HERE IS WORTH NOTHING: it is the model's `PrimaryPart`, so
		-- `Viewmodel.shells`'s `PivotTo` writes over it on the frame this is built and every frame
		-- after. Round 2 of task 107 caught exactly that -- the import's half turn was set here and
		-- silently discarded. The turn is `shellTurnDeg`, applied where every shell is PLACED.
		local part = template:Clone()
		part.Name = "Body"
		part.CFrame = CFrame.new()
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = false
		part.Parent = shell
		shell.PrimaryPart = part
		shell.Parent = parent
		return shell
	end
	local pieces = {
		{
			name = "Body",
			length = layout.bodyLength,
			across = size.X,
			colour = config.SHELL_BODY_COLOR,
			offset = layout.bodyX,
		},
		{
			name = "Base",
			length = layout.baseLength,
			across = size.X,
			colour = config.SHELL_BASE_COLOR,
			offset = layout.baseX,
		},
	}
	-- THE RIM, which is the whole of "this chamber is loaded" seen from behind an open breech. It was
	-- the new gun's alone while there were two: the cloned gun's chamber was a fraction of a Handle
	-- rather than a measured face, so a rim seated against it would have been a number with no owner.
	-- `Gun.chamber` owns it now, so it is drawn on every shell.
	table.insert(pieces, {
		name = "Rim",
		length = layout.rimThick,
		across = layout.rimDiameter,
		colour = config.SHELL_BASE_COLOR,
		offset = layout.rimX,
	})
	for _, piece in ipairs(pieces) do
		local part = Instance.new("Part")
		part.Name = piece.name
		part.Shape = Enum.PartType.Cylinder
		-- A cylinder's length runs along its own X, so the shell lies along Z once turned.
		part.Size = Vector3.new(piece.length, piece.across, piece.across)
		part.CFrame = CFrame.new(piece.offset, 0, 0)
		part.Color = piece.colour
		-- THE BODY IS THE ONLY PLASTIC ONE: the base and the rim behind it are the same brass.
		part.Material = if piece.name == "Body" then Enum.Material.SmoothPlastic else Enum.Material.Metal
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

-- WHERE A SHELL IS PLACED, in the gun's own frame: at the chamber mouth of each tube, on its own
-- BORE LINE, from the same arithmetic the barrels are drawn from.
--
-- THE GUN KNOWS WHERE ITS OWN CHAMBERS ARE (task 99), and that is the whole of "the shell goes IN".
-- The cloned gun's answer -- the barrels' breech END on the Handle's centre line -- left the shell
-- floating in the gap between its two mesh halves, and it went with that gun in task 114.
--
-- `Gun.chamber` says where the shell's RIM goes: the chamber MOUTH, a hair proud of the breech face
-- (round 2, finding 1 -- a shell seated inside an opaque tube is invisible). What `PivotTo` places is
-- the model's pivot, its Body, so the shell is backed off by its own `back` -- from the same layout
-- `makeShell` draws it from, so the rim lands where this says it does.
local function chamberOffset(barrel: number, config): CFrame
	return Gun.chamber(barrel, Shotgun.CONFIG) * CFrame.new(0, 0, -shellBack(config))
end

-- EACH GLOVE INTO ONE FRAME (task 108), and this is the whole of Karen's "left hand is oposit180deg
-- need to turn or not sure but broken".
--
-- THE TWO MESHES DO NOT SHARE AN AXIS. `HandAssets.AXES` records what was measured off each prepped
-- glove: the RIGHT one's fingers run along its own -X and its palm faces its own +Z; the LEFT one's
-- fingers run along its own +Y. So one `twist` turns them about different things -- the Director's
-- live try of `left.rot.twist 180` swung the glove to the far side of the barrels instead of rolling
-- the palm, which is exactly what a shared number does when the models disagree.
--
-- WHAT THIS RETURNS is the rotation that takes a glove's own axes into the convention the three pose
-- angles are read in: FINGERS ALONG +X, PALM TOWARD +Y. Applied on the RIGHT of the pose offset, so
-- it turns the mesh inside the pose rather than moving where the pose put it -- the hand's position
-- is the offset's, untouched. After it, `yaw` swings both hands' fingers the same way, `pitch` lifts
-- both, and `twist` rolls both palms, which is what `Mode.handOffset`'s comment always claimed.
--
-- THE MEASURED PAIR IS NOT ORTHOGONAL (the palm normal is the hand cloud's flattest axis, and a hand
-- is not a perfect slab), so the palm is squared against the fingers here -- the fingers direction is
-- the one that was measured exactly, centroid to centroid, so it is the one that is kept.
--
-- IT APPLIES TO EVERY GLOVE DRAWN (task 114). While there were two guns this returned identity for
-- the old one, whose pair was a different model posed with no alignment at all; that pair retired
-- with that gun, so there is one convention and `HandAssets.AXES` is its one definition.
local alignCache: { [string]: CFrame } = {}

function Viewmodel.align(name: string): CFrame
	local cached = alignCache[name]
	if cached then
		return cached
	end
	local axes = HandAssets.AXES[name]
	if axes == nil then
		return CFrame.identity
	end
	local fingers = axes.fingers.Unit
	local palm = (axes.palm - fingers * axes.palm:Dot(fingers)).Unit
	-- fromMatrix's three columns are right, up and BACK, and back = right x up for a proper rotation.
	local mesh = CFrame.fromMatrix(Vector3.zero, fingers, palm, fingers:Cross(palm))
	-- `mesh` takes +X to the fingers; the INVERSE is what takes the fingers to +X.
	local align = mesh:Inverse()
	alignCache[name] = align
	return align
end

-- WHERE A HAND TEMPLATE COMES FROM. The real answer is the folder
-- `ServerScriptService.ViewmodelAssetsBoot` publishes; a spec injects its own with
-- `setHandTemplates`. Never yields and never loads anything: nil means "no hands", which is the gun
-- Karen has been playing since task 95 and not a failure.
-- ONE PAIR SINCE TASK 114. Karen made gloves that HOLD this gun, and the v1 pair the retired gun's
-- top-level poses were measured against went with it -- so there is one folder again and one pair of
-- keys (`HandAssets.KEY_OF`). Task 106's reason for having had two is still the reason they could
-- never be ONE key: the surviving glove's `twist` of 180 belongs to a palm-DOWN model, so the old gun
-- drew it upside down at 53 % of the size its poses assumed, and a new version of a key SUPERSEDES.
local function handTemplate(name: string): BasePart?
	local fn = handTemplates
	if fn then
		return fn(name)
	end
	local folder = ReplicatedStorage:FindFirstChild(HandAssets.FOLDER_NAME)
	local found = if folder then folder:FindFirstChild(name) else nil
	return if found and found:IsA("BasePart") then found :: BasePart else nil
end

local function addHand(clone: BasePart, parent: Instance, name: string): boolean
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
	-- NO DRAWN SLEEVE, AND THE WHOLE APPARATUS IS GONE (task 114). Task 99 ran an olive cylinder back
	-- along each hand's long axis because a hand model ends at the cuff and the v1 gloves had an open
	-- hole there; task 108 cut it into a taper and ran it toward the shoulder instead of the wrist;
	-- then Karen, 2026-10-02: "you can remove those arm extentions from both hands", and task 111
	-- made `sleeveSegments` answer an empty list for model B. With model B the only gun that answer is
	-- the only answer -- its gloves carry their own turned cuff -- so the segments, the taper, the
	-- to-the-shoulder vectors and the four SLEEVE numbers went with the gun they were drawn for.
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
		missing = not addHand(clone, clone, HandAssets.RIGHT) or missing
	end
	if leftParent:FindFirstChild(HandAssets.LEFT) == nil then
		missing = not addHand(clone, leftParent, HandAssets.LEFT) or missing
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

-- THE LEFT HAND LOADS THE SHELLS (task 111). Karen, 2026-10-02: "can we make that i push ammo
-- inside pipes? just moving hand", and then, correcting which hand: "the left loads shell".
--
-- IT RUNS ON THE SHELL'S OWN CLOCK, AND THAT IS THE WHOLE DESIGN. `Viewmodel.shells` already slides
-- each fresh shell forward from `SHELL_FEED_FROM_STUDS` behind its chamber over
-- `SHELL_FEED_SECONDS`, starting at `loadedAt[barrel]` -- the moment the SERVER said that barrel was
-- loaded. So the hand is not animated beside the shell on a second timeline that could drift out of
-- step with it: it is placed from the same two numbers, which is what "the shell travels WITH the
-- hand" means when nothing is parented to anything.
--
-- THE SHAPE OF ONE LOAD: the hand blends in over the first `reachShare` of the feed (arriving as the
-- shell starts to move), sits exactly behind the shell all the way home, then blends back to Karen's
-- own `newGun.reload.left` over `returnSeconds`. Two shells are two of these, a moment apart,
-- because the server loads the barrels one at a time; whichever is further along wins, so the second
-- takes over cleanly from the first.
--
-- OPEN ONLY: a shut gun is not being loaded. ("New gun only" stood here too, until task 114 made
-- this gun the only one.)
-- WHERE A FRESH SHELL IS AT THIS POINT OF ITS FEED, in the barrels' frame -- the slide forward that
-- `Viewmodel.shells` has drawn since task 99, and still what a shell does once the hand has let go.
function Viewmodel.shellFeedAt(barrel: number, feedT: number, config): CFrame
	return chamberOffset(barrel, config) * CFrame.new(0, 0, config.SHELL_FEED_FROM_STUDS * (1 - feedT))
end

-- WHAT ONE SHELL'S LOADING LOOKS LIKE, AS FOUR MOMENTS (task 111, round 2). Karen, watching the
-- first version: "wrong ... when left arm is on weapon on reload arm go up towards hunter and then
-- towards pipes where shells in places and again towards hunter and then shell place and then back
-- to weapon". Round 1 went straight from the barrels to the breech with no FETCH, which is what
-- read wrong -- a hand that arrives holding a shell it never picked up.
--
-- So one shell is three segments and a return, all of them seconds in `poses.json`:
--   REST -> FETCH   (`fetchSeconds`): the hand leaves the barrels and goes back toward the hunter,
--                   low and left, where the shells are. It is empty.
--   FETCH -> ABOVE  (`carrySeconds`): it carries the shell up and forward to over the open chamber,
--                   brass up. THE SHELL IS IN THE HAND from the start of this segment.
--   ABOVE -> SEAT   (`seatSeconds`): straight down into the chamber.
--   SEAT -> REST    (`returnSeconds`): back to Karen's own tuned pose, empty again.
-- Two shells are two of those, one after the other, because the server loads one barrel at a time.
--
-- WHICH FRAME EACH POINT IS IN, and they are not the same: `fetch` is a place on the HUNTER, so it
-- is written in the gun's own frame but means "down and back toward the body" -- during the reload
-- the gun is held in one fixed pose (`newGun.reload.gun`), so the two frames differ by a constant
-- and the gun frame is the one `poseHands` already has. `above` and `seat` are offsets FROM THE
-- CHAMBER MOUTH, so they follow the gun's own geometry and stay right if the barrels move.
local function loadKey(entry, base: CFrame): CFrame
	local pos = entry.pos
	return base * Mode.handOffset(Vector3.new(pos.x, pos.y, pos.z), entry.rot.yaw, entry.rot.pitch, entry.rot.twist)
end

-- (weight, hand frame, the barrel whose shell is IN THE HAND or nil, that shell's frame or nil),
-- all in the BARRELS' frame, for `now`. Weight 0 means the hand belongs on the barrels at Karen's
-- numbers, and at weight 0 nothing here is drawn.
-- ONE BARREL'S PLACE IN ITS OWN LOADING, at `since` seconds after the server loaded it:
-- (weight, the hand's frame, whether the shell is IN that hand). Pulled out of the loop below
-- because `Viewmodel.shells` asks the same question of ONE barrel (task 111, round 2 follow-up):
-- Karen, live, "either we have 2 animation when shells go inside or one go straight another from
-- hand" -- the old automatic feed was still sliding each shell into its chamber by itself WHILE the
-- hand carried another, so there were two of them going in at once.
local function loadStep(barrel: number, since: number, config): (number, CFrame?, boolean)
	local load = config.SHELL_LOAD
	local fetchFor = math.max(1e-3, load.fetchSeconds)
	local carryFor = math.max(1e-3, load.carrySeconds)
	local seatFor = math.max(1e-3, load.seatSeconds)
	local backFor = math.max(1e-3, load.returnSeconds)
	local mouth = chamberOffset(barrel, config)
	local held = config.POSES.reload.left
	local rest =
		Mode.handOffset(Vector3.new(held.pos.x, held.pos.y, held.pos.z), held.rot.yaw, held.rot.pitch, held.rot.twist)
	local fetch = loadKey(load.fetch, CFrame.identity)
	local above = loadKey(load.above, mouth)
	local seat = loadKey(load.seat, mouth)
	if since < 0 then
		return 0, nil, false
	elseif since < fetchFor then
		local weight = math.clamp(since / fetchFor, 0, 1)
		return weight, rest:Lerp(fetch, weight), false
	elseif since < fetchFor + carryFor then
		return 1, fetch:Lerp(above, (since - fetchFor) / carryFor), true
	elseif since < fetchFor + carryFor + seatFor then
		return 1, above:Lerp(seat, (since - fetchFor - carryFor) / seatFor), true
	end
	local weight = math.clamp(1 - (since - fetchFor - carryFor - seatFor) / backFor, 0, 1)
	return weight, seat:Lerp(rest, 1 - weight), false
end

-- WHERE ONE BARREL'S FRESH SHELL IS, or nil for "do not draw it at all" -- which is the fix for
-- Karen's two animations. A shell exists ONLY once the hand has it: BEFORE the fetch is over there
-- is nothing to see, DURING the carry and the seat it is in the hand's own frame, and AFTER that it
-- is in the chamber and still. The self-sliding feed this replaced (`shellFeedAt` on a clock) was
-- the retired gun's, and it went with it in task 114; `SHELL_LOAD` is the only shape read here, and
-- it is nil only for a config that carries no `reload.load` block at all.
function Viewmodel.freshShellAt(barrel: number, config, now: number): CFrame?
	local at = loadedAt[barrel]
	if at == nil or not reload.loaded[barrel] then
		return nil
	end
	local load = config ~= nil and config.SHELL_LOAD or nil
	if load == nil then
		return nil
	end
	local _, frame, holding = loadStep(barrel, now - at, config)
	if holding and frame ~= nil then
		return (frame :: CFrame) * CFrame.new(load.shellInHand.x, load.shellInHand.y, load.shellInHand.z)
	end
	local since = now - at
	if since < math.max(1e-3, load.fetchSeconds) then
		return nil -- the hand has not picked it up yet, so there is no shell on screen
	end
	return Viewmodel.shellFeedAt(barrel, 1, config) -- seated, and it stays there
end

function Viewmodel.loadingAt(config, now: number): (number, CFrame?, number?, CFrame?)
	local load = config ~= nil and config.SHELL_LOAD or nil
	if load == nil or not reload.open then
		return 0, nil, nil, nil
	end
	local best, bestFrame, carryBarrel, carryShell = 0, nil, nil, nil
	for barrel = 1, 2 do
		local at = loadedAt[barrel]
		if at ~= nil and reload.loaded[barrel] then
			local weight, frame, holding = loadStep(barrel, now - at, config)
			if weight > best and frame ~= nil then
				best, bestFrame = weight, frame
				if holding then
					carryBarrel = barrel
					carryShell = Viewmodel.freshShellAt(barrel, config, now)
				else
					carryBarrel, carryShell = nil, nil
				end
			end
		end
	end
	return best, bestFrame, carryBarrel, carryShell
end

-- The same question at this instant, which is what the viewmodel asks every frame.
function Viewmodel.loading(config): (number, CFrame?, number?, CFrame?)
	return Viewmodel.loadingAt(config, clock())
end

-- BOTH HANDS, PLACED FROM THIS FRAME'S POSE (task 98), and this is the one site that places them.
--
-- WHY EVERY FRAME. Until task 98 a hand was posed once, when the clone was built, and carried along
-- by the `PivotTo`. That had two costs: the glove sat in the carry's place even in the aimed view --
-- one hand pose for the whole game -- and a number changed while a Studio session ran could not
-- reach it, which is exactly what `tools/pose.py` exists to do. `Mode.handOffsetAt` answers the
-- BLENDED pose, so the hands move with the gun through the raise, the aim and the break.
--
-- IT TAKES NO CAMERA FRAME SINCE TASK 114. It used to, for one thing only: running each drawn
-- sleeve toward its own shoulder, which is a direction in the CAMERA's axes rather than the gun's.
-- The sleeves went with the gun they were drawn for, and a hand's place is the gun's business.
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
	-- THE ALIGNMENT IS APPLIED HERE, ON THE RIGHT OF THE POSE (task 108): the pose says WHERE the
	-- hand is and which way it is turned, and `Viewmodel.align` turns the MESH inside that, so both
	-- gloves answer the same three angles.
	local right = clone:FindFirstChild(HandAssets.RIGHT)
	if right and right:IsA("BasePart") then
		local base = gunCFrame * Mode.handOffsetAt("right", state, config);
		(right :: BasePart).CFrame = base * Viewmodel.align(HandAssets.RIGHT)
	end
	-- Walked rather than remembered, for the reason `clearHands` gives: the left hand's parent is the
	-- barrels when the gun has them and the Handle when it does not.
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant.Name == HandAssets.LEFT and descendant:IsA("BasePart") then
			-- ...AND THE LEFT HAND LEAVES THE BARRELS TO LOAD (task 111). `Viewmodel.loading` says
			-- how far along that is; at weight 0 this is bit-for-bit Karen's own tuned pose.
			local held = Mode.handOffsetAt("left", state, config)
			local weight, loading = Viewmodel.loading(config)
			if loading ~= nil and weight > 0 then
				held = held:Lerp(loading :: CFrame, weight)
			end
			local base = barrelsCFrame * held;
			(descendant :: BasePart).CFrame = base * Viewmodel.align(HandAssets.LEFT)
		end
	end
end

-- THE GUN, BUILT RATHER THAN CLONED (task 99; the only build path since task 114). Karen,
-- 2026-10-01: "shooting, weapon, reload, all has to be perfect". The cloned mesh was one AI model cut
-- in two, so the break-open frame showed a torn breech and a shell in the gap; this builds the gun
-- from `ReplicatedStorage.Gun`'s piece list instead, with Karen's model B cloned over the two hinge
-- groups where the server has published them, and a hinge pin the barrel group really turns about.
--
-- FIRST PERSON ONLY, AND LOCAL ONLY. The Tool's Handle is untouched and every other player sees the
-- uploaded mesh exactly as before: `Weapon.Hardware` is still the only writer of Tool Instances
-- (docs/design/shotgun.md 3.1), and this model lives under `workspace.CurrentCamera`.
--
-- THE SAME SHAPE AS THE CLONE, deliberately: an invisible `Handle` of `HANDLE_SIZE` is the
-- PrimaryPart (so every pose, the pivot and the near-plane arithmetic are unchanged), a `Barrels`
-- envelope holds everything that swings, and the `Sight` and `Muzzle` attachments are where the rest
-- of the system already looks for them.
-- `geometry` IS THE WEAPON'S OWN (task 140): `Gun` for the shotgun, `Rifle.Geometry` for the
-- rifle. Everything this function does -- an invisible Handle of the row's size, one envelope for
-- the group that moves, a clone per published mesh with that group's measured box where the mesh is
-- missing, then the `Sight` and `Muzzle` attachments -- was already weapon-independent; what it
-- needed was to stop naming `Gun` and `Shotgun.CONFIG` directly.
local function buildNewGun(config, geometry, row): Model
	geometry = geometry or Gun
	row = row or Shotgun.CONFIG
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
	handle.Size = row.HANDLE_SIZE
	handle.Transparency = 1 -- the envelope, exactly as the worn gun's Handle is (Task 71)
	dress(handle)
	handle.Parent = made
	made.PrimaryPart = handle

	-- THE BARREL GROUP'S OWN ENVELOPE, and it is what `Viewmodel.hinge` turns. Every piece in the
	-- group is a CHILD of it, so "what swings" is a parent rather than a list in two files -- the
	-- same rule the old mesh gun's `Barrels` piece already set.
	local at = geometry.layout(row)
	local barrels = Instance.new("Part")
	-- THE NAME OF THE GROUP THAT MOVES, from the geometry: `Barrels` on a break-action, `Bolt` on a
	-- bolt rifle. `Viewmodel.hinge` looks for this name and nothing else.
	barrels.Name = geometry.CYCLE_GROUP_NAME or BARRELS_NAME
	barrels.Size = Vector3.new(0.3, 0.2, at.barrelLength or (at.bolt and at.bolt.size.Z) or 0.6)
	barrels.Transparency = 1
	dress(barrels)
	barrels.CFrame = handle.CFrame * CFrame.new(0, 0, at.barrelZ or (at.bolt and at.bolt.at.Z) or 0)
	barrels.Parent = handle

	-- MODEL B WHERE THE SERVER HAS PUBLISHED IT (task 105), and the measured box where it has not.
	-- Karen chose this model after calling the drawn gun "bad"; `ServerScriptService.
	-- ViewmodelAssetsBoot` loads its two hinge groups and parks them in `Gun.FOLDER_NAME`, and this
	-- clones them. A group whose upload did not load is drawn as the box `Gun.pieces` carries for it,
	-- so a gun that failed to load is a plain dark gun and not a hole where a gun should be.
	local gunFolder = ReplicatedStorage:FindFirstChild(geometry.FOLDER_NAME)
	local function meshFor(name: string): BasePart?
		local found = if gunFolder then gunFolder:FindFirstChild(name) else nil
		return if found and found:IsA("BasePart") then found :: BasePart else nil
	end

	-- COUNTED PER BUILD, NOT FOR EVER (TASKS.md 99a(g)): this was incremented per piece per build and
	-- never reset, so after one stale rebuild it read 4 for a two-piece gun. It answers "how much of
	-- the real model is on the gun that is on screen", which is a fact about THIS build.
	stats.meshesDrawn = 0
	stats.meshesWaiting = 0
	for _, piece in ipairs(geometry.pieces(row)) do
		local mesh = if piece.meshKey ~= nil then meshFor(piece.name) else nil
		-- PUBLISHED IS NOT DOWNLOADED (task 133). A mesh this client has not got renders as nothing,
		-- so wearing it means wearing a hole: the measured box below is drawn instead, and the mesh
		-- takes its place the moment it lands, through the same stale-and-rebuild path the folder
		-- appearing already uses.
		if mesh ~= nil and not Viewmodel.meshReady(mesh) then
			mesh = nil
			stats.meshesWaiting += 1
		end
		local part: BasePart
		local offset = piece.offset
		if mesh ~= nil then
			-- The SIZE came from the manifest when the server published it (the consumer sets it,
			-- design 6.1); `meshOffset` is where the MESH goes, which is not where the fallback BOX
			-- goes -- both halves of the model carry the WHOLE gun's bounding box, so a mesh sits at
			-- the gun's centre while a fallback box sits at its own group's.
			part = mesh:Clone()
			offset = piece.meshOffset or piece.offset
			stats.meshesDrawn += 1
		else
			local made_ = Instance.new("Part")
			made_.Size = piece.size
			made_.Shape = piece.shape
			made_.Color = piece.color
			made_.Material = piece.material
			made_.Reflectance = piece.reflectance or 0
			made_.Transparency = piece.transparency or 0
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
	sight.CFrame = geometry.sight(row)
	sight.Parent = handle

	local muzzle = Instance.new("Attachment")
	muzzle.Name = MUZZLE_NAME
	muzzle.CFrame = geometry.muzzle(row)
	muzzle.Parent = handle

	-- NO DRAWN BEAD MARKER: this gun carries its own `Bead` piece, on the rib, at exactly
	-- `Gun.beadOffset` -- the same expression `Gun.sight` answers with. The light is still added,
	-- for the reason it was added in task 92: a gun inches from the eye is lit by the sun alone.
	--
	-- FIRST PERSON ONLY (TASKS.md 99a(g)): this was unconditional, which put a point light back on
	-- the third-person gun -- the glow task 92 measured and gated.
	if config.FIRST_PERSON then
		addFillLight(handle, config)
	end

	builtMeshes = if gunFolder then #gunFolder:GetChildren() else 0
	builtReady = readyMeshes()
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

-- WHICH WEAPON IS ON SCREEN, read off the TOOL the source handed us (task 140). The attribute is
-- written by `Weapon.Hardware.build`, so the drawn gun follows the INSTANCE: a state replica that
-- arrives a frame later can never make this draw the wrong gun.
function Viewmodel.weaponId(): string?
	local handle = cachedHandle
	local tool = handle and handle.Parent
	if tool == nil or not tool:IsA("Tool") then
		return nil
	end
	local id = tool:GetAttribute("DrivenHunt.Weapon")
	return if type(id) == "string" then id :: string else nil
end

-- The geometry module of the weapon on screen, and the shotgun's when there is nothing to go on --
-- which is every session before this task and every Tool built by an older server.
local function geometryNow(): any
	return Weapons.geometry(Viewmodel.weaponId()) or Gun
end
Viewmodel.geometryNow = geometryNow

function Viewmodel.update(camCFrame: CFrame, state: Mode.State, config)
	local cam = Workspace.CurrentCamera
	-- The source walks the character for a Tool, so it is asked four times a second rather than
	-- every frame (the pose below is what has to be per frame, and it is one PivotTo).
	local now = clock()
	-- EVERY FRAME WHILE THERE IS NO GUN IN HAND, a quarter of a second apart once there is (task
	-- 133). MEASURED in the Forest Test with a per-frame trace: the Tool reached the character 208 ms
	-- before the viewmodel noticed it, and that delay is this throttle and nothing else -- a quarter
	-- of a second of empty hands on every spawn, after the server had already done its part. The
	-- lookup is one `FindFirstChildOfClass` on the local character, so paying for it per frame while
	-- the player has nothing to hold is the cheap half of the trade; once the handle is cached the
	-- cadence is exactly what it was.
	if source and (cachedHandle == nil or not cachedHandle.Parent or now - lastSourceCheck > 0.25) then
		cachedHandle = source()
	elseif not source then
		cachedHandle = nil
	end
	-- AND WHETHER THE MESHES HAVE ARRIVED SINCE THE GUN WAS BUILT (task 99). STILL ON THE QUARTER
	-- SECOND, deliberately: it walks the published folder and asks the engine for a fetch status per
	-- piece, which is a container lookup and not something a frame needs -- only the source lookup
	-- above got cheap enough to run per frame. `builtMeshes` is -1 until a gun has been built, so
	-- this never fires before the first build.
	if now - lastSourceCheck > 0.25 then
		lastSourceCheck = now
		if builtMeshes >= 0 then
			local folder = ReplicatedStorage:FindFirstChild(geometryNow().FOLDER_NAME)
			if (if folder then #folder:GetChildren() else 0) ~= builtMeshes then
				stale = true
			end
			-- ...AND WHEN A PUBLISHED MESH FINISHES DOWNLOADING (task 133). Two numbers rather than
			-- one, because they are two facts and either can move without the other: the server can
			-- publish a piece this client cannot draw yet, and this client can finish the download of
			-- a piece that was published long before.
			if readyMeshes() ~= builtReady then
				stale = true
			end
		end
	end
	local handle = cachedHandle

	if not cam or not handle or (state.blend < config.VIEWMODEL_SHOW_BLEND and not config.FIRST_PERSON) then
		if model then
			model.Parent = nil
		end
		return
	end

	if not model or builtFrom ~= handle or stale then
		-- clear() resets `stale`, so a folder count taken before this rebuild cannot mark the new
		-- build stale.
		Viewmodel.clear()
		-- ONE GUN (task 114): built from `ReplicatedStorage.Gun`'s pieces, with model B's two hinge
		-- groups where the server has published them. The Tool's Handle is still what every OTHER
		-- player sees, and it is still untouched.
		-- THE WEAPON THE TOOL SAYS IT IS (task 140). `builtFrom` is the Handle, and a switch is a
		-- different Handle, so a rebuild happens on exactly the frame the player's hands change.
		model = buildNewGun(config, geometryNow(), Weapons.row(Viewmodel.weaponId()) or Shotgun.CONFIG)
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
	-- THE FILL LIGHT, from the data, every frame (task 102): see `applyFill`.
	applyFill(made, config)
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
	-- FIRST PERSON ONLY, AND IT PUTS THINGS BACK RATHER THAN WALKING AWAY (round 2, finding 2). The
	-- gun is built with its barrels as a separate piece in EVERY build, first person or not, so the
	-- third-person camera must draw no shells and swing nothing. `Mode.breakAngleDeg` already answers
	-- 0 there, so the barrels are still PLACED, at rest: returning early instead left them wherever a
	-- first-person frame had last put them, which the OFF-branch case caught by finding them 35
	-- degrees off the body.
	local firstPerson = config.FIRST_PERSON == true
	if clone and not firstPerson then
		Viewmodel.clearShells(clone)
	end
	local geometry = geometryNow()
	local barrels = clone and clone:FindFirstChild(geometry.CYCLE_GROUP_NAME or BARRELS_NAME)
	if not (barrels and barrels:IsA("BasePart")) then
		return gunCFrame -- one piece: the barrels' frame IS the gun's frame
	end
	if barrelsLocal == nil then
		barrelsLocal = clone.CFrame:ToObjectSpace((barrels :: BasePart).CFrame)
	end
	local progress = Mode.cycleProgress(state, config)
	local angle = progress * config.BREAK_OPEN_DEG
	-- THE AXIS THE BARRELS TURN ABOUT. The gun has a PIN, drawn at `Gun.hinge`, and the barrels must
	-- turn about exactly that line or the pin is something they swing around rather than on -- so the
	-- number comes from the gun's own geometry rather than from a pose the Director tunes.
	-- `BREAK_HINGE_STUDS` is where the RETIRED gun's knuckle was measured and is read by nothing
	-- since task 114; it is still published, because `reload.hingeStuds` is one of Karen's tuned
	-- numbers and removing a number nobody reads is the Director's call, not this task's (TASKS 114a).
	local row = Weapons.row(Viewmodel.weaponId())
	local hinge = CFrame.new(geometry.hinge(row or Shotgun.CONFIG))
	-- NEGATIVE ABOUT X IS THE MUZZLE GOING DOWN, which is what "break open" means: a part's
	-- LookVector is its -Z, and `CFrame.Angles(+t, 0, 0)` takes (0, 0, -1) to (0, sin t, -cos t) --
	-- i.e. UP. Measured the hard way: the first run of `camera_client.spec` caught the barrels
	-- swinging toward the sky.
	local swing
	if geometry.CYCLE_KIND == "slide" then
		-- A BOLT, NOT A HINGE (task 140). The same one number -- how far through its action the gun
		-- is -- read as TWO segments: the handle turns up over the first `BOLT_LIFT_FRACTION` of it,
		-- and the bolt then draws straight back over the rest. `Mode.segmentAt` is the two-segment
		-- map the raise's keyframes already use, so there is not a second one here.
		local lift = math.clamp(config.BOLT_LIFT_FRACTION or 0.35, 1e-3, 1)
		local turn = math.min(progress, lift) / lift
		local draw = if progress > lift then (progress - lift) / (1 - lift) else 0
		swing = hinge
			* CFrame.Angles(0, 0, -math.rad((config.BOLT_LIFT_DEG or 0) * turn))
			* hinge:Inverse()
			* CFrame.new(0, 0, (config.BOLT_DRAW_STUDS or 0) * draw)
	else
		-- NEGATIVE ABOUT X IS THE MUZZLE GOING DOWN, which is what "break open" means.
		swing = hinge * CFrame.Angles(-math.rad(angle), 0, 0) * hinge:Inverse()
	end
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
-- and the THIRD-PERSON branch refusing to draw a reload at all.
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

	local now = clock()
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
	-- ONE PLACE DECIDES WHERE A FRESH SHELL IS, AND WHETHER THERE IS ONE AT ALL: the hand's own
	-- frame while it carries it, and the chamber once it is in. `freshShellAt` answers both, and
	-- since task 114 it has only the one answer to give.
	for barrel = 1, 2 do
		local place = Viewmodel.freshShellAt(barrel, config, now)
		if place ~= nil then
			wanted[FRESH_NAME .. barrel] = place
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
		-- THE ONE PLACE EVERY SHELL IS TURNED, drawn or uploaded (task 107, round 3). It was a
		-- literal 90 here, which is right for the three cylinders this file lays out and wrong for a
		-- cartridge that has been through Roblox's importer.
		(shell :: Model):PivotTo(barrelsCFrame * offset * CFrame.Angles(0, math.rad(shellTurnDeg()), 0))
	end
end

-- ----------------------------------------------------------------- the shot's own light (task 112)

local FLASH_NAME = "MuzzleFlash"
-- ROBLOX'S OWN PARTICLE TEXTURES, which ship with the engine (`rbxasset://`, not `rbxassetid://`):
-- no upload, no library asset, and nothing to load over the network.
local FLASH_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

-- A COLOUR IS THREE NUMBERS, so it lives in `poses.json` with the rest of the shot and `pose.py set`
-- reaches it (task 112, round 3: the Director previewed these live and Karen OK'd them -- "smoke
-- looks good now", and the flash "yes").
local function rgbOf(entry): Color3
	return Color3.fromRGB(entry.r, entry.g, entry.b)
end

-- THE FLASH AND THE SMOKE, ON THE PIPE THAT FIRED, UNDER THE CAMERA. Karen's order, 2026-10-02:
-- finish the weapon before the animal, and shooting is next; the reference is
-- `TARGET-fire-smoke.jpg` -- a short white bloom and a grey puff that drifts up and thins out.
--
-- WHY HERE AND NOT IN `Weapon.Effects`, which already draws a flash: this one is parented to the
-- VIEWMODEL, so it rides the gun through the kick instead of hanging in the world where the shot
-- left it, and it is this module's business by the same rule the hands and the shells are (one owner
-- per system).
--
-- AND `Weapon.Effects` NO LONGER DRAWS ITS OWN FOR THIS SHOT (round 2). Round 1's comment here said
-- that one was "in the world, nowhere near" -- it was not: `Effects.muzzleFrame` has asked the
-- viewmodel for the SHOOTER'S OWN muzzle since task 92, so its neon box and grey ball were landing
-- on top of these, which is what Karen saw ("remove those smokes (white from previous)").
-- `Effects.setViewmodelFlash` is the seam: this answers whether it drew, and that pair is skipped
-- for the shot it drew. Everybody else's shot, and the THIRD-PERSON build, are drawn there exactly
-- as before.
--
-- A PARTICLE EMITTER AND A LIGHT, NOT A BOX. Task 92's flash is a neon cube and its own screenshot
-- said so ("it read as a grey BOX hanging off the barrels"). An emitter with a one-burst rate and a
-- `PointLight` is what a muzzle flash is: bright for a frame or two, then nothing.
--
-- EVERY NUMBER IS DATA (`newGun.fire.flash` / `.smoke`), so the Director and Karen tune the look
-- live with `pose.py set` like every other number in this file.
function Viewmodel.flash(barrel: number?, config)
	local made = model
	local clone = made and made.PrimaryPart
	-- FIRST PERSON ONLY, and it still asks the DATA whether there is a flash to draw: a config whose
	-- `fire` block carries no `flash` draws none rather than erroring, which is the check below. Until
	-- task 114 the gun flag was asked here too, and the retired gun's `fire` block was exactly such
	-- a block -- its cosmetics were `Weapon.Effects`' parts in the world.
	if clone == nil or config == nil or config.FIRST_PERSON ~= true then
		return false
	end
	if config.FIRE == nil or config.FIRE.flash == nil or config.FIRE.smoke == nil then
		return false
	end
	local at = Viewmodel.muzzle(barrel)
	if at == nil then
		return false
	end
	local fire = config.FIRE
	local holder = Instance.new("Part")
	holder.Name = FLASH_NAME
	holder.Size = Vector3.new(0.05, 0.05, 0.05)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Massless = true
	holder.CastShadow = false
	holder.CFrame = (at :: CFrame) * CFrame.new(0, 0, -fire.flash.forwardStuds)
	holder.Parent = clone

	local light = Instance.new("PointLight")
	light.Brightness = fire.flash.lightBrightness
	light.Range = fire.flash.lightRange
	light.Color = Color3.fromRGB(255, 226, 170)
	light.Shadows = false
	light.Parent = holder

	local spark = Instance.new("ParticleEmitter")
	spark.Name = "Flash"
	-- THE STAR WAS THE DEFAULT TEXTURE (round 3). Karen: "flash is not perfect seems like animation
	-- kids" and "I am not about size I am about this shape like a star". A `ParticleEmitter` with no
	-- `Texture` draws Roblox's SPARKLE -- a four-pointed star with rays -- which is exactly the shape
	-- she drew with her words. These two are the engine's own particle textures, shipped with Studio
	-- under `rbxasset://`, so nothing is uploaded and nothing is fetched: `fire_main` is a soft
	-- orange-white blob with no spikes, and `smoke_main` is a soft grey puff with no outline.
	spark.Texture = FLASH_TEXTURE
	spark.Color = ColorSequence.new(rgbOf(fire.flash.colorStart), rgbOf(fire.flash.colorEnd))
	spark.Size = NumberSequence.new(fire.flash.sizeStuds)
	spark.Transparency = NumberSequence.new(0)
	spark.Lifetime = NumberRange.new(fire.flash.seconds)
	spark.Speed = NumberRange.new(0)
	spark.Rate = 0
	spark.LightEmission = 1
	spark.Parent = holder
	spark:Emit(6)

	-- THE SMOKE OUTLIVES THE FLASH, which is the whole look: it drifts UP and thins out over a second
	-- or so while the gun is already coming back down.
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = SMOKE_TEXTURE
	smoke.Color = ColorSequence.new(rgbOf(fire.smoke.color))
	smoke.LightEmission = 0
	smoke.Size = NumberSequence.new(fire.smoke.sizeStuds * 0.35, fire.smoke.sizeStuds)
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, fire.smoke.transparency),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Lifetime = NumberRange.new(fire.smoke.seconds * 0.7, fire.smoke.seconds)
	smoke.Speed = NumberRange.new(fire.smoke.riseStuds * 0.5, fire.smoke.riseStuds)
	smoke.SpreadAngle = Vector2.new(fire.smoke.spreadDeg, fire.smoke.spreadDeg)
	smoke.Acceleration = Vector3.new(0, fire.smoke.riseStuds, 0)
	smoke.Rate = 0
	smoke.Parent = holder
	smoke:Emit(math.max(1, math.floor(fire.smoke.rate * fire.smoke.burstSeconds)))

	-- ONE `Debris` ITEM FOR THE WHOLE THING, and it has to outlive the longest PARTICLE rather than
	-- the shot: the emitters have already fired their bursts, and a holder destroyed at the flash's
	-- own lifetime would take the smoke with it.
	Debris:AddItem(holder, fire.smoke.seconds + fire.flash.seconds + 0.2)
	stats.flashesDrawn += 1
	return true
end

function Viewmodel.isParented(): boolean
	return model ~= nil and model.Parent ~= nil
end

return Viewmodel
