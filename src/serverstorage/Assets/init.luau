--!strict
-- Assets: THE ASSET MANIFEST. Pure data and pure lookups: it creates no Instance, holds no
-- state, never yields, and nothing in it touches the world. It DOES require
-- `ReplicatedStorage.Shotgun` -- for `deepFreeze` and for the one number the gun's size is
-- derived from -- so "no service" would be a lie: `game:GetService` is called once, at require
-- time, for a module (review round 1, note).
--
-- THIS IS THE ONE SOURCE OF ASSET IDS (docs/design/asset-pipeline.md section 2.1, section 4). It has
-- NO RUN-TIME WRITER AT ALL: the Builder edits this file from what `tools/roblox_upload.py` printed
-- into `assets/uploads.json`, and git records the change. `GAME_DESIGN.md`'s owners table says the
-- same in one line.
--
-- ROWS ARE APPENDED AND VERSIONED, NEVER EDITED (section 4.4): a changed mesh is a NEW asset id, so
-- replacing an id in place would destroy the provenance of everything already built from the old
-- one, and a moderated-away id would become undiagnosable. `byKey` answers with the highest version
-- whose moderation is not "rejected".
--
-- THE BINARY IS NEVER COMMITTED (`.rbxm` is banned outright, CLAUDE.md), so this table plus the id IS
-- the record of where each model came from and under what licence.
--
-- WHY `MapGen.Assets` STILL EXISTS. `docs/design/map-generator.md` section 12.2 says MapGen's own
-- table is the only id table "until M2.7a lands", and then `MapGen.Props` moves onto `Assets.Loader`
-- and `MapGen.Assets` is archived. This file is M2.7a's manifest, and it holds the only id in the
-- repo -- `MapGen.Assets.ROWS` is still EMPTY, so there is no id in two places. Moving the map onto
-- this loader is its own task (design section 6.8, `TASKS.md` row 74a): it changes what the map
-- generator does, needs `mapgen verify`, and has nothing to do with the gun.
--
-- Design: docs/design/asset-pipeline.md (sections 2.1, 4)
-- Note:   docs/research/2026-09-26-roblox-upload.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
-- THE FIRST-PERSON GUN'S OWN GEOMETRY (task 99), and only for two numbers: how long each wooden
-- piece is on that gun. The gun decides the scale, so the manifest does not carry a second copy
-- of it -- the rule `Gun.beadOffset` and `Shape.beadOffset` already follow one layer over.
local Gun = require(ReplicatedStorage:WaitForChild("Gun"))

local Assets = {}

Assets.VERSION = "m2.7a-shotgun"

export type Source = "meshy" | "creator-store" | "roblox" | "own"
-- "meshpart": the template is EXACTLY ONE MeshPart. The Loader returns that MeshPart and destroys
--             the Model wrapper it arrived in. The gun is this.
-- "model":    the template is a tree; the Loader returns the Model. Map props may be this.
export type Kind = "meshpart" | "model" | "image"
export type Moderation = "approved" | "reviewing" | "rejected" | "unknown"

export type Licence = {
	basis: string,
	quote: string,
	quotedFrom: string,
	readOn: string,
	attribution: string?,
}

export type AssetRow = {
	key: string,
	version: number,
	kind: Kind,
	modelId: number, -- what the Open Cloud upload returned. 0 is never valid.
	displayName: string,
	fileName: string, -- the dropped file's NAME only, never a path (CLAUDE.md's history check)
	sourceSha256: string,
	source: Source,
	creator: string,
	licence: Licence,
	added: string,
	moderation: Moderation,
	trisDeclared: number,
	texturePx: number?,
	sizeStuds: Vector3, -- the TARGET bounding box; the consumer sets Size to this
	naturalSizeStuds: Vector3?, -- MEASURED off the template, so the aspect check has something to
	-- compare against rather than a hope
	offsetStuds: Vector3,
	rotationDeg: Vector3, -- the backwards-knife correction; only a screenshot checks it (6.3)
	-- WHERE THIS MESH'S BEAD IS, in the Handle's frame, so the first-person camera can line the view
	-- up with it (docs/design/camera.md section 6.5). OPTIONAL, and nil is the honest value until
	-- somebody has looked: a single MeshPart has a PAINTED bead and no Instance to read, so this can
	-- only be measured on screen in ADS. With it nil, `Weapon.Hardware` falls back to the parts
	-- gun's own bead and warns once. It lives here rather than in `Shotgun.CONFIG` because it
	-- describes ONE upload: a new mesh is a new row with a new measurement.
	sightOffsetStuds: Vector3?,
	-- WHO NEEDS THIS ROW BEFORE A PLAYER CAN USE IT (task 93). `nil` means "runtime": the server
	-- needs it before it can hand the thing over, which is every row that predates the hands.
	-- "viewmodel" is a row only the LOCAL player's camera ever draws, so a different boot line asks
	-- for it and it must not be loaded twice -- `keysFor` answers per scope rather than per table.
	scope: string?,
	renderFidelity: string,
	-- SET WHEN A LATER VERSION REPLACES THIS ROW. The row STAYS (rule 7: never delete, archive
	-- with a note) -- an id that has been in a place is provenance, and a moderated-away or
	-- rolled-back asset is undiagnosable without it. `byKey` skips a superseded row even if it is
	-- somehow the highest version, so the FIELD is the decision and the version number is not.
	supersededBy: number?,
	-- THE COLOUR THE PART IS LEFT AT WHEN ITS TEXTURE DOES NOT DRAW (task 99), measured off the
	-- SOURCE texture rather than guessed.
	--
	-- MEASURED, AND IT IS WHY THIS FIELD EXISTS. Karen, 2026-10-01: the right glove is WHITE in game.
	-- Both hands carry a `SurfaceAppearance` with a `ColorMap` -- probed on the server in a live
	-- session, both ids present -- and both source textures are dark brown (median ~54, 44, 35). But
	-- the pixels of the aimed screenshot read (115, 120, 131) and (132, 138, 151): that is Roblox's
	-- DEFAULT medium stone grey, shaded by the sky, which is what a part shows when its colour map
	-- does not draw. Beside it the gun mesh's own texture rendered at (39, 16, 13), so the place and
	-- the lighting are not the fault.
	--
	-- So the fix is not to argue with the renderer: a part whose map fails falls back to its `Color`,
	-- and this is that colour. If the map ever does draw it overwrites this and nothing is lost; if
	-- it does not, the glove is brown leather instead of a white blob. `nil` for rows nobody draws
	-- without a texture.
	fallbackColor: Color3?,
	-- THE COLOUR MAP'S OWN ASSET ID, so a game script can put it on the MeshPart's `TextureID`
	-- (task 99). It is HERE and not read off the model at run time because a normal script CANNOT
	-- read `SurfaceAppearance.ColorMap` at all -- measured, 2026-10-01: "The current thread cannot
	-- read 'ColorMap' (lacking capability Plugin)", which took `ViewmodelAssetsBoot` down with it and
	-- published nothing. Only a plugin context can read it, which is what `execute_luau` is, so the
	-- id is read ONCE through the harness when the row is written and kept here like every other
	-- measured fact about an upload.
	textureId: string?,
	notes: string?,
}

-- THE KEY STRINGS, ONE HOME. The reason is `Map.TAGS`': a typo in a literal is a silent nil and a
-- grey box nobody can explain.
Assets.KEYS = table.freeze({
	shotgunHandle = "shotgun.handle",
	-- THE TWO FIRST-PERSON HANDS (task 93). They are not the gun and they are not the map: nobody
	-- but the player holding the shotgun ever sees them, which is why they carry a scope of their
	-- own below.
	handRight = "hand.right",
	gunStock = "gun.stock",
	-- MODEL B'S TWO HINGE GROUPS AND ITS SHELL (task 105). Karen picked a professional CC-BY model
	-- on 2026-10-02 after calling the exact-geometry gun "bad"; `tools/gltf_split.py` splits it at
	-- the hinge and `Gun.MESH_KEYS` names these two, so the gun's geometry and this table cannot
	-- disagree about which half swings.
	gunBarrels = "gun.barrels",
	gunFrame = "gun.frame",
	gunShell = "gun.shell",
	handLeft = "hand.left",
})

-- THE SIZE IS UNIFORM, AND THAT IS A DECISION WORTH READING (design 6.1 says "the consumer sets
-- Size, always", and 6.1's table pins `shotgun.handle` to HANDLE_SIZE = (0.4, 0.5, 4.4)).
--
-- MEASURED: the imported template's natural bounding box is 199.999 x 31.314 x 11.311 studs, long
-- axis X. Writing HANDLE_SIZE onto it directly would be a NON-UNIFORM fit: the grey box is a thin
-- 0.4 x 0.5 envelope with a 8.8:1 length-to-height ratio, and the real gun's is 6.4:1 -- so the mesh
-- would be squashed 28 % flatter and stretched 60 % wider, and a squashed gun measures perfectly
-- (design 6.1's own words about the squashed boar). The smallest choice that keeps every number the
-- rest of the system is built on: scale UNIFORMLY so the LENGTH is `HANDLE_SIZE.Z`, which is what
-- `GRIP` and `MUZZLE_OFFSET` are built on, and let the height and width be whatever the gun's own
-- proportions give. The Handle itself stays exactly `HANDLE_SIZE` -- it is the envelope, the grip
-- and the only part of the gun a ray can hit (Task 71) -- so the hitbox does not move either.
local NATURAL = Vector3.new(199.999, 31.314, 11.311)
local SCALE = Shotgun.CONFIG.HANDLE_SIZE.Z / NATURAL.X
local GUN_SIZE = Vector3.new(NATURAL.X * SCALE, NATURAL.Y * SCALE, NATURAL.Z * SCALE)

-- THE HANDS (task 93), by the same rule and written out the same way: scale UNIFORMLY so the long
-- axis is `HAND_LENGTH_STUDS`, and let the other two be whatever the hand's own proportions give.
-- The two natural boxes are MEASURED off each prepped model's own vertex bounds (the run's
-- `model.glb` position accessors, times the hundred Roblox's FBX import applies -- the same hundred
-- that makes the gun's two-unit model 200 units long above). See the rows for where 1.28 comes from.
-- 1.27 SINCE TASK 105, AND IT IS BACK TO LIFE SIZE BECAUSE THE GUN IS. Task 99 cut this from 1.28 to
-- 1.10 for one measured reason: the drawn gun's barrels were 0.145 studs across where a real pair at
-- this length is about 0.078, so the metal was drawn at nearly twice life and a life-size hand beside
-- it read as the biggest thing in the frame. Model B's tubes ARE 0.078 -- 21.7 mm, a 12-gauge -- so
-- the gun is life size in cross-section now and the hand has to be too. 1.27 is the original
-- measurement, not a new guess: a hand plus a cuff is about 330 mm, this game's scale is 1143 mm of
-- gun to 4.4 studs, and 330 / 259.8 = 1.27. Still the one dial for how bulky a hand reads, and still
-- the Director's to tune.
local HAND_LENGTH_STUDS = 1.27
local HAND_RIGHT_NATURAL = Vector3.new(190.04, 84.99, 78.93)
local HAND_LEFT_NATURAL = Vector3.new(189.64, 95.52, 72.04)
-- THE WOOD (task 99), by the same rule: MEASURED off the prepped model's own vertex bounds (the
-- run's `model.glb` position accessors, times the hundred Roblox's FBX import applies), then
-- scaled UNIFORMLY so the LONG AXIS is what `Gun` says that piece is on this gun. The other two
-- sizes are whatever the wood's own proportions give -- a stock squashed to a chosen box measures
-- perfectly and looks wrong (design 6.1, the squashed boar).
local STOCK_NATURAL = Vector3.new(190.153, 69.262, 17.743)
local function uniformTo(natural: Vector3, length: number): Vector3
	local scale = length / natural.X
	return Vector3.new(natural.X * scale, natural.Y * scale, natural.Z * scale)
end

-- THE STOCK'S SIZE IS FROZEN AT WHAT TASK 102 SHIPPED, and nothing asks for it any more: model B
-- carries its own chequered stock, so `gun.stock` is retired below rather than scaled to a gun that
-- no longer has a hole for it. The row stays, with its id, because an id that has been in a place is
-- provenance (rule 7), and the number stays with the row it belongs to.
local STOCK_SIZE = Vector3.new(1.32, 0.4808, 0.255)
local HAND_RIGHT_SIZE = uniformTo(HAND_RIGHT_NATURAL, HAND_LENGTH_STUDS)
local HAND_LEFT_SIZE = uniformTo(HAND_LEFT_NATURAL, HAND_LENGTH_STUDS)

Assets.ROWS = {
	{
		key = "shotgun.handle",
		version = 1,
		kind = "meshpart" :: Kind,
		-- Uploaded by tools/roblox_upload.py on 2026-09-26; the row it wrote is in
		-- assets/uploads.json, and this id is that row's assetId.
		modelId = 117134580332969,
		displayName = "Driven Hunt shotgun (side-by-side)",
		fileName = "model.fbx",
		sourceSha256 = "472602e31c11e860a93a873905eca8f5f0fdfe9c52f68f24469554fa4aab0950",
		source = "own" :: Source,
		creator = "8167651842", -- Karen, who is also the place owner: LoadAsset needs LoadOwnedAsset
		licence = {
			basis = "own-work",
			quote = "Karen generated the model in her own paid Meshy account and prepared it with "
				.. "tools/asset_prep.py; she gave the upload OK on 2026-09-26 and the in-game OK on "
				.. "2026-09-26.",
			quotedFrom = "assets/uploads.json (karenOk), TASKS.md rows 72-74",
			readOn = "2026-09-26",
			attribution = nil,
		},
		added = "2026-09-26",
		moderation = "approved" :: Moderation,
		-- MEASURED, not declared: tools/asset_prep.py counted 19,325 triangles on the prepped mesh
		-- and the GLB's own index accessor agreed. Roblox's ceiling is 20,000 per mesh.
		trisDeclared = 19325,
		-- 4096, NOT THE 2048 THIS ROW CLAIMED UNTIL TASK 75. The prep down-sampled its own copies to
		-- 2048 and this row recorded that, but the FBX that was uploaded embedded Meshy's untouched
		-- 4096 maps -- so the number described the intention and not the asset (review round 1,
		-- note). Version 2's 2048 is measured on what actually shipped.
		texturePx = 4096,
		sizeStuds = GUN_SIZE,
		naturalSizeStuds = NATURAL,
		offsetStuds = Vector3.zero, -- measured: the template's pivot is its bounding-box centre to
		-- within 0.003 studs
		-- THE MESH'S LONG AXIS IS ITS LOCAL X, AND ITS MUZZLE IS AT +X -- WHICH IS NOT WHAT THE
		-- BLENDER MEASUREMENT SAID. `tools/asset_prep.py` measured the muzzle at the MINIMUM X of
		-- the source model (the thinner end), and the arithmetic from that gives -90 degrees about
		-- Y. The first screenshot showed the gun pointing backwards, so the FBX import flips the
		-- long axis somewhere between Blender and Roblox: +90 is the correction, and it was found
		-- the only way it can be found.
		-- ONLY A SCREENSHOT CHECKS THIS (design 6.3, and PROJECT_CONTEXT's knife held backwards for
		-- three rounds). This is that bug, caught on the first look instead of the third round.
		rotationDeg = Vector3.new(0, 90, 0),
		renderFidelity = "Automatic",
		supersededBy = 2,
		notes = "SUPERSEDED BY VERSION 2, and kept because rule 7 keeps things. This upload's FBX "
			.. "embedded Meshy's untouched textures: the prep tool wrote its corrected maps beside "
			.. "the export and repointed nothing, so what shipped was metalness 0.91 / roughness "
			.. "0.19 -- a mirror. That is why the barrels read bright silver in Roblox daylight "
			.. "(Karen, 2026-09-26: barrels too shiny). Measured by reading the PNGs back out of "
			.. "the uploaded file (Task 75).",
	},
	{
		key = "shotgun.handle",
		version = 2,
		kind = "meshpart" :: Kind,
		-- Uploaded by tools/roblox_upload.py on 2026-09-27; the row it wrote is in
		-- assets/uploads.json, and this id is that row's assetId.
		--
		-- WHY THERE IS A VERSION 2 AT ALL. Karen asked for one correction -- "barrels too shiny
		-- ... make more realistic" (2026-09-26) -- and it took a tool fix to deliver it: the prep
		-- recipe's metalness and roughness lived on a Blender material, and Roblox reads MAPS and
		-- has nowhere to put a material scalar, so those numbers reached the renders and never the
		-- game. Since Task 75 they are written into the maps and the export carries them.
		-- MEASURED in Studio, on this id: ONE SurfaceAppearance, ColorMap 137831763707305,
		-- MetalnessMap 97235862383876, RoughnessMap 113964612606991 -- all three new, where
		-- version 1 came back carrying the raw model's own map ids.
		supersededBy = 3, -- task 92: v3 is the same model with smooth normals and a softer action
		modelId = 103304840285660,
		displayName = "Driven Hunt shotgun (side-by-side) r4",
		fileName = "model.fbx",
		sourceSha256 = "1cedac2b5485d709b4a796df51fba26a030b466689989a6720bd3ab598a8930d",
		source = "own" :: Source,
		creator = "8167651842", -- Karen, who is also the place owner: LoadAsset needs LoadOwnedAsset
		licence = {
			basis = "own-work",
			quote = "Karen generated the model in her own paid Meshy account and prepared it with "
				.. "tools/asset_prep.py; she gave the upload OK on 2026-09-26 and asked for this "
				.. "exact correction the same day: barrels too shiny, make more realistic. The "
				.. "re-upload carries her correction and nothing else -- same model, same geometry, "
				.. "new textures.",
			quotedFrom = "assets/uploads.json (karenOk), TASKS.md rows 74-75",
			readOn = "2026-09-27",
			attribution = nil,
		},
		added = "2026-09-27",
		moderation = "approved" :: Moderation,
		-- MEASURED, not declared: the geometry did not change, and Roblox handed back the SAME
		-- MeshId (rbxassetid://72415641939074), so the count and the bounding box are version 1's.
		trisDeclared = 19325,
		texturePx = 2048,
		sizeStuds = GUN_SIZE,
		naturalSizeStuds = NATURAL,
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.new(0, 90, 0),
		-- MEASURED ON SCREEN, 2026-09-27 (task 90), the only way this can be measured: the mesh's
		-- bead is PAINTED, so there is no Instance to read. The first ADS screenshot put the drawn
		-- bead at the parts gun's own height (Y = 0.255) and it was INVISIBLE -- buried inside the
		-- muzzle's own metal, which the brightest pixel within 60 px of the screen centre confirmed
		-- (185, 197, 219: the mesh's lit rim, not a Neon ball). This clears the mesh outright: the
		-- template's box is `naturalSizeStuds.Y * SCALE` = 0.689 studs tall about the Handle's
		-- centre, so nothing the mesh has reaches above +0.345, and +0.375 is 0.03 studs clear of
		-- the highest point it could possibly have. Z stays with the parts gun's bead, 0.05 behind
		-- the muzzle face.
		sightOffsetStuds = Vector3.new(0, 0.375, -2.15),
		renderFidelity = "Automatic",
		notes = "Barrels and rib at metalness 0.10 / roughness 0.50, action 0.70 / 0.35, stock "
			.. "0.00 / 0.62, written into the MAPS, which is the only channel Roblox reads. One "
			.. "MeshPart with ONE SurfaceAppearance child (version 1's export made four, three of "
			.. "them empty); the viewmodel's clone must keep it (design 6.6).",
	},
	{
		key = "shotgun.handle",
		version = 3,
		kind = "meshpart" :: Kind,
		-- Uploaded by tools/roblox_upload.py on 2026-09-27; the row it wrote is in
		-- assets/uploads.json, and this id is that row's assetId.
		--
		-- WHY THERE IS A VERSION 3. Karen, after playing the first-person build (PLAYTEST.md,
		-- 2026-09-27): "Weapon color we need to improve and style now feels a bit broken, it has to
		-- be smooth and nice." What she was looking at was FLAT SHADING: `tools/asset_prep.py`
		-- exported every run with `mesh_smooth_type="FACE"`, so each of the model's 19,325 triangles
		-- was lit as its own plane and a round barrel an inch from a first-person eye became a ring
		-- of bright shards with dark seams. The tool now shades the mesh smooth and keeps as SHARP
		-- only the edges whose faces meet at more than 35 degrees (`smoothAngleDeg`), and exports
		-- with `mesh_smooth_type="EDGE"` so those flags travel: MEASURED on this run, 9,050 of
		-- 28,992 edges stayed sharp. The action's shine came down with it -- metalness 0.70 -> 0.45,
		-- roughness 0.35 -> 0.50 -- because a mirror is what turned the shards white.
		--
		-- SAME MODEL, SAME GEOMETRY: the same Meshy source file as v2, not decimated, so the
		-- triangle count, the bounding box and `sightOffsetStuds` are unchanged and no number the
		-- rest of the system is built on moves.
		supersededBy = 4, -- task 94: v4 has barrels this repo built rather than smoothed
		modelId = 137252961155547,
		displayName = "Driven Hunt shotgun (side-by-side) r5 smooth",
		fileName = "model.fbx",
		sourceSha256 = "0d27f24e14b3b95125aac621ecfd0b12242c2810ad2cd24a1a445c8efd9b4fee",
		source = "own" :: Source,
		creator = "8167651842", -- Karen, who is also the place owner: LoadAsset needs LoadOwnedAsset
		licence = {
			basis = "own-work",
			quote = "Karen generated the model in her own paid Meshy account and prepared it with "
				.. "tools/asset_prep.py; she gave the upload OK on 2026-09-26 and asked for this "
				.. "exact correction on 2026-09-27, after playing it: weapon colour and style feel "
				.. "a bit broken, it has to be smooth and nice. The re-upload carries her "
				.. "correction and nothing else -- same model, same geometry, smooth shading.",
			quotedFrom = "assets/uploads.json (karenOk), PLAYTEST.md 2026-09-27, TASKS.md row 92",
			readOn = "2026-09-27",
			attribution = nil,
		},
		added = "2026-09-27",
		moderation = "approved" :: Moderation,
		trisDeclared = 19325,
		texturePx = 2048,
		sizeStuds = GUN_SIZE,
		naturalSizeStuds = NATURAL,
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.new(0, 90, 0),
		-- UNCHANGED FROM v2, and it may be: the geometry is the same file, so the painted bead is
		-- where it was. See v2 for how this was measured on screen.
		sightOffsetStuds = Vector3.new(0, 0.375, -2.15),
		renderFidelity = "Automatic",
		notes = "Smooth normals at 35 degrees (9,050 of 28,992 edges kept sharp), exported with "
			.. "EDGE smoothing. Barrels and rib at metalness 0.10 / roughness 0.50, action 0.45 / "
			.. "0.50, stock 0.00 / 0.62, written into the MAPS. One MeshPart with ONE "
			.. "SurfaceAppearance child; the viewmodel's clone must keep it (design 6.6).",
	},
	{
		key = "shotgun.handle",
		version = 4,
		kind = "meshpart" :: Kind,
		-- Uploaded by tools/roblox_upload.py on 2026-09-27; the row it wrote is in
		-- assets/uploads.json, and this id is that row's assetId.
		--
		-- WHY THERE IS A VERSION 4. Karen, after her third test (2026-09-27): "gun is not smooth and
		-- nice ... nozzle is terrible (ending where we aim) ... barrels don't feel smooth". A
		-- generated mesh is lumpy BY CONSTRUCTION -- it is a surface fitted to an image, not a tube --
		-- and v3 proved that shading it smooth does not change its SHAPE. So `tools/asset_prep.py`
		-- now CUTS the model at the front of the action, keeps Karen's stock, her silver action and
		-- her wooden forend, and BUILDS the rest: two round barrels side by side and touching, 64
		-- segments each, a rib along their top, a thin-walled muzzle with two real openings, and a
		-- bead on the rib. Beretta 486 Parallelo proportions -- barrels 0.62 of the gun's length,
		-- 23 mm across, a 1.7 mm wall.
		--
		-- FEWER TRIANGLES THAN BEFORE, because a tube costs less than a fitted lump: 11,770 against
		-- v3's 19,325.
		supersededBy = 5, -- task 94: v4 reached Roblox with no smoothing groups (see v5)
		modelId = 80699745427569,
		displayName = "Driven Hunt shotgun r6 clean barrels",
		fileName = "model.fbx",
		sourceSha256 = "a72131f7f43fca8d04246d451513c6fd9d3fb0a68cc298558890fb78e85c5244",
		source = "own" :: Source,
		creator = "8167651842", -- Karen, who is also the place owner: LoadAsset needs LoadOwnedAsset
		licence = {
			basis = "own-work",
			quote = "Karen generated the model in her own paid Meshy account and prepared it with "
				.. "tools/asset_prep.py; she gave the upload OK on 2026-09-26 and asked on "
				.. "2026-09-27, after playing it, for the gun to be built smooth like the video she "
				.. "sent. The barrels are this repository's own geometry; the stock and action are "
				.. "hers, unchanged.",
			quotedFrom = "assets/uploads.json (karenOk), PLAYTEST.md 2026-09-27, TASKS.md row 94",
			readOn = "2026-09-27",
			attribution = nil,
		},
		added = "2026-09-27",
		moderation = "approved" :: Moderation,
		trisDeclared = 11770,
		texturePx = 2048,
		-- THE BOX IS v1's, AND IT IS 0.8 % GENEROUS IN HEIGHT. The rebuilt barrels are slimmer than
		-- the generated ones, so the model measures 31.07 units tall against the 31.31 declared here;
		-- the mesh is scaled to `sizeStuds` either way, so keeping the shared numbers stretches it by
		-- less than a hundredth and keeps one size for the whole key.
		sizeStuds = GUN_SIZE,
		naturalSizeStuds = NATURAL,
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.new(0, 90, 0),
		-- COMPUTED FROM THE GEOMETRY THAT WAS BUILT, not measured off a screenshot: the prep reports
		-- the bead at 0.0021 of the model's length from the muzzle and 0.491 of its height above the
		-- centre (`rebuiltBarrels.bead` in the run's report.json), which at this scale is 2.19 studs
		-- forward and 0.336 up. v3's 0.375 was a bound on a PAINTED bead nobody could see; this one
		-- is where the ball actually is.
		sightOffsetStuds = Vector3.new(0, 0.336, -2.19),
		renderFidelity = "Automatic",
		notes = "Barrels, rib, muzzle and bead built by asset_prep's `rebuildBarrels`; blued steel "
			.. "written into the maps by the step that owns those texels (metalness 0.10, roughness "
			.. "0.50). Action 0.45 / 0.50, stock 0.00 / 0.62. Custom split normals cleared before "
			.. "smoothing at 35 degrees, which is what took the lengthwise stripes off the tubes. "
			.. "One MeshPart with ONE SurfaceAppearance child; the viewmodel's clone must keep it.",
	},
	{
		key = "shotgun.handle",
		version = 5,
		kind = "meshpart" :: Kind,
		-- Uploaded by tools/roblox_upload.py on 2026-09-27; the row it wrote is in
		-- assets/uploads.json, and this id is that row's assetId.
		--
		-- WHY THERE IS A VERSION 5, AND IT WAS MEASURED IN THE GAME RATHER THAN IN A RENDER. v4's
		-- tubes are perfectly smooth in Blender's own photograph of them and arrived in Roblox as a
		-- HERRINGBONE of flat triangles down both barrels -- an inch from a first-person eye, which
		-- is exactly the "not smooth" this task exists to fix. The cause is the FBX export: task 92
		-- switched it from smoothing GROUPS ("FACE") to per-edge sharp flags ("EDGE") on the belief
		-- that groups meant flat shading, and Roblox's importer reads the groups and not the flags.
		-- Same geometry as v4, same maps, exported with smoothing groups.
		supersededBy = 6, -- task 94: v5 still shimmered where the tubes and the rib touched exactly
		modelId = 73632997167378,
		displayName = "Driven Hunt shotgun r7 smooth tubes",
		fileName = "model.fbx",
		sourceSha256 = "f25d6431628d08ff1a121af9530488028bfbf7a2d6ed9c59bae10c51b8672dd5",
		source = "own" :: Source,
		creator = "8167651842", -- Karen, who is also the place owner: LoadAsset needs LoadOwnedAsset
		licence = {
			basis = "own-work",
			quote = "Karen generated the model in her own paid Meshy account and prepared it with "
				.. "tools/asset_prep.py; she gave the upload OK on 2026-09-26 and asked on "
				.. "2026-09-27, after playing it, for the gun to be built smooth like the video she "
				.. "sent. The barrels are this repository's own geometry; the stock and action are "
				.. "hers, unchanged.",
			quotedFrom = "assets/uploads.json (karenOk), PLAYTEST.md 2026-09-27, TASKS.md row 94",
			readOn = "2026-09-27",
			attribution = nil,
		},
		added = "2026-09-27",
		moderation = "approved" :: Moderation,
		trisDeclared = 11770,
		texturePx = 2048,
		sizeStuds = GUN_SIZE,
		naturalSizeStuds = NATURAL,
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.new(0, 90, 0),
		-- v4's number, computed from the same geometry: the prep reports the bead 0.0021 of the
		-- model's length from the muzzle and 0.491 of its height above the centre.
		sightOffsetStuds = Vector3.new(0, 0.336, -2.19),
		renderFidelity = "Automatic",
		notes = "As v4 -- barrels, rib, muzzle and bead built by `rebuildBarrels`, blued steel "
			.. "written into the maps by the step that owns those texels -- exported with smoothing "
			.. "groups so Roblox shades the tubes round. One MeshPart with ONE SurfaceAppearance.",
	},
	{
		key = "shotgun.handle",
		version = 6,
		kind = "meshpart" :: Kind,
		-- Uploaded by tools/roblox_upload.py on 2026-09-27; the row it wrote is in
		-- assets/uploads.json, and this id is that row's assetId.
		--
		-- WHY THERE IS A VERSION 6, AND AGAIN IT WAS MEASURED IN THE GAME. v5's barrels carried a
		-- bright scalloped shimmer down each side in first person -- the two tubes were built exactly
		-- tangent to each other and the rib's underside exactly tangent to both, and coincident
		-- surfaces fight for the depth buffer. A real side-by-side is brazed tube to tube; a renderer
		-- needs a hair of daylight, so `clearanceT` puts 0.4 mm between them. Same geometry
		-- otherwise, same maps, same smoothing groups.
		supersededBy = 7, -- task 94: v6's barrels still speckled at a distance (mipmaps; see v7)
		modelId = 94500894676280,
		displayName = "Driven Hunt shotgun r8 no z-fight",
		fileName = "model.fbx",
		sourceSha256 = "5a380efbc97c5faf2775d8ea2197646f4efb294de9b55966cf71ba63cf13b28a",
		source = "own" :: Source,
		creator = "8167651842", -- Karen, who is also the place owner: LoadAsset needs LoadOwnedAsset
		licence = {
			basis = "own-work",
			quote = "Karen generated the model in her own paid Meshy account and prepared it with "
				.. "tools/asset_prep.py; she gave the upload OK on 2026-09-26 and asked on "
				.. "2026-09-27, after playing it, for the gun to be built smooth like the video she "
				.. "sent. The barrels are this repository's own geometry; the stock and action are "
				.. "hers, unchanged.",
			quotedFrom = "assets/uploads.json (karenOk), PLAYTEST.md 2026-09-27, TASKS.md row 94",
			readOn = "2026-09-27",
			attribution = nil,
		},
		added = "2026-09-27",
		moderation = "approved" :: Moderation,
		trisDeclared = 11770,
		texturePx = 2048,
		sizeStuds = GUN_SIZE,
		naturalSizeStuds = NATURAL,
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.new(0, 90, 0),
		-- Computed from the geometry that was built: the prep reports the bead 0.0021 of the model's
		-- length from the muzzle and 0.491 of its height above the centre.
		sightOffsetStuds = Vector3.new(0, 0.336, -2.19),
		renderFidelity = "Automatic",
		notes = "As v5, with 0.4 mm of clearance between the two tubes and under the rib. Barrels, "
			.. "rib, muzzle and bead built by `rebuildBarrels`; blued steel written into the maps by "
			.. "the step that owns those texels; smoothing groups on export. One MeshPart with ONE "
			.. "SurfaceAppearance.",
	},
	{
		key = "shotgun.handle",
		version = 7,
		kind = "meshpart" :: Kind,
		-- Uploaded by tools/roblox_upload.py on 2026-09-27; the row it wrote is in
		-- assets/uploads.json, and this id is that row's assetId.
		--
		-- WHY THERE IS A VERSION 7, AND IT IS MIPMAPS. The rebuilt barrels take their colour from a
		-- borrowed patch of the atlas, and Roblox halves that texture over and over for distance:
		-- by the third level a patch a few dozen pixels wide has blended into whatever the generator
		-- left beside it, which came out on screen as a speckled, scalloped shimmer down both tubes
		-- -- and never appeared in Blender's own render, which has no mip chain. The built faces now
		-- take a small island in the MIDDLE of the largest empty square of atlas (3 x 3 cells of a
		-- 48-cell grid, about 123 px), and the repaint fills that whole square with the same flat
		-- blued steel, so several mip levels are flat before anything else can bleed in.
		supersededBy = 8, -- task 95: the forend hung off the new tubes; v8 seats it
		modelId = 107443663683446,
		displayName = "Driven Hunt shotgun r9 flat atlas block",
		fileName = "model.fbx",
		sourceSha256 = "3bcd2c6587cb30e5a37854f82842a0c37c140ee8f671437791323bbe3f9e8ebe",
		source = "own" :: Source,
		creator = "8167651842", -- Karen, who is also the place owner: LoadAsset needs LoadOwnedAsset
		licence = {
			basis = "own-work",
			quote = "Karen generated the model in her own paid Meshy account and prepared it with "
				.. "tools/asset_prep.py; she gave the upload OK on 2026-09-26 and asked on "
				.. "2026-09-27, after playing it, for the gun to be built smooth like the video she "
				.. "sent. The barrels are this repository's own geometry; the stock and action are "
				.. "hers, unchanged.",
			quotedFrom = "assets/uploads.json (karenOk), PLAYTEST.md 2026-09-27, TASKS.md row 94",
			readOn = "2026-09-27",
			attribution = nil,
		},
		added = "2026-09-27",
		moderation = "approved" :: Moderation,
		trisDeclared = 11770,
		texturePx = 2048,
		sizeStuds = GUN_SIZE,
		naturalSizeStuds = NATURAL,
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.new(0, 90, 0),
		sightOffsetStuds = Vector3.new(0, 0.336, -2.19),
		renderFidelity = "Automatic",
		notes = "As v6 -- built barrels, rib, muzzle and bead, 0.4 mm of clearance between the tubes "
			.. "and under the rib, smoothing groups on export -- with the built faces on a small UV "
			.. "island inside a flat 123-pixel block of atlas. One MeshPart with ONE SurfaceAppearance.",
	},
	{
		key = "shotgun.handle",
		version = 8,
		kind = "meshpart" :: Kind,
		-- Uploaded by tools/roblox_upload.py on 2026-09-27; the row it wrote is in
		-- assets/uploads.json, and this id is that row's assetId.
		--
		-- WHY THERE IS A VERSION 8: THE FOREND. Karen's wood was carved for the GENERATED barrels,
		-- which were far fatter and ran right into the action; against the tubes task 94 built it
		-- read as a separate dark flap with daylight above it and a gap behind it -- visible in every
		-- carry frame of task 95 round 1. It is her wood, so `rebuildBarrels` MOVES it rather than
		-- replacing it: stretched back along the gun's own axis until its rear meets the cut (x1.22)
		-- and lifted if it hangs below the tubes (it did not need lifting here). Only the vertices
		-- that belong to the forend alone are moved; one shared with the action would tear the mesh.
		--
		-- WHAT IT LOOKS LIKE IN THE GAME, from `.screenshots/...t95r3-carry.png` at the carry, where
		-- the gun is closest to the eye: the wood is one piece with the gun at the action end and
		-- runs forward UNDER the barrels as a dark walnut wedge. It is not flush all the way -- toward
		-- its front the wood narrows away from the tubes and a thin dark gap opens between its top
		-- edge and the barrel's underside. The flap that hung off the gun with daylight above it and
		-- a gap behind it is gone; the wedge at the front is not, and it is the next thing to fix
		-- there.
		supersededBy = 9, -- task 96: the gun ships in two pieces now, so a break-action can hinge
		modelId = 126484176321060,
		displayName = "Driven Hunt shotgun r10 seated forend",
		fileName = "model.fbx",
		sourceSha256 = "d8cfc5bbbab61bea70e2da2d12f03944dc7c2cc52647327c63e039e4ecc2bb2a",
		source = "own" :: Source,
		creator = "8167651842", -- Karen, who is also the place owner: LoadAsset needs LoadOwnedAsset
		licence = {
			basis = "own-work",
			quote = "Karen generated the model in her own paid Meshy account and prepared it with "
				.. "tools/asset_prep.py; she gave the upload OK on 2026-09-26 and asked on "
				.. "2026-09-27, after playing it, for the gun to be built smooth like the video she "
				.. "sent. The barrels are this repository's own geometry; the stock, action and "
				.. "forend are hers.",
			quotedFrom = "assets/uploads.json (karenOk), PLAYTEST.md 2026-09-27, TASKS.md row 95",
			readOn = "2026-09-27",
			attribution = nil,
		},
		added = "2026-09-27",
		moderation = "approved" :: Moderation,
		trisDeclared = 11770,
		texturePx = 2048,
		sizeStuds = GUN_SIZE,
		naturalSizeStuds = NATURAL,
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.new(0, 90, 0),
		sightOffsetStuds = Vector3.new(0, 0.336, -2.19),
		renderFidelity = "Automatic",
		notes = "As v7 -- built barrels, rib, muzzle and bead, clearance between the tubes, smoothing "
			.. "groups, the built faces on a flat block of atlas -- with the forend seated against "
			.. "the action and the tubes. One MeshPart with ONE SurfaceAppearance.",
	},
	-- ------------------------------------------------------ the gun in two pieces (task 96)
	--
	-- KAREN, 2026-09-27: the reload is a BREAK ACTION, like the real Beretta 486 Parallelo -- the
	-- barrels hinge down off the action -- and not the reference game's pump-style muzzle-up reload.
	-- One MeshPart cannot hinge, so `tools/asset_prep.py` writes the same model out in two more
	-- files, split at the plane it cut the generated barrels off at: the BARRELS (the built tubes,
	-- the rib, the bead and Karen's forend) and the BODY (her action and stock).
	--
	-- THEY ASSEMBLE AT ONE CFRAME AND NEED NO MEASURED OFFSET, which is the whole reason the split
	-- is done this way: each piece carries two anchor triangles a ten-thousandth of a unit across at
	-- the WHOLE gun's opposite corners, so Roblox imports both at the same size and the same origin.
	-- That is two millionths of a stud at this scale -- smaller than any pixel the game will draw --
	-- and it is why both rows below carry v8's `sizeStuds` and a zero `offsetStuds`.
	{
		key = "shotgun.handle",
		version = 9,
		kind = "meshpart" :: Kind,
		-- THE BODY, and it keeps the `shotgun.handle` key because the body IS the gun as far as
		-- every other system is concerned: the Handle's envelope, the grip, the Muzzle attachment and
		-- the Sight all hang on it, and the barrels are scenery welded in front.
		modelId = 121405298612730,
		displayName = "Driven Hunt shotgun body r1",
		fileName = "model_body.fbx",
		sourceSha256 = "8115feb2b20d9bc55fa164534f085b72875c78c0f12a57d0444b2e59a600651a",
		source = "own" :: Source,
		creator = "8167651842",
		licence = {
			basis = "own-work",
			quote = "Karen generated the model in her own paid Meshy account and prepared it with "
				.. "tools/asset_prep.py; she gave the upload OK on 2026-09-26 and asked on "
				.. "2026-09-27 for a break-action reload like the real gun, which is why it ships "
				.. "in two pieces. The barrels are this repository's own geometry; the stock, action "
				.. "and forend are hers.",
			quotedFrom = "assets/uploads.json (karenOk), PLAYTEST.md 2026-09-27, TASKS.md row 96",
			readOn = "2026-09-27",
			attribution = nil,
		},
		added = "2026-09-27",
		moderation = "approved" :: Moderation,
		trisDeclared = 9701,
		texturePx = 2048,
		sizeStuds = GUN_SIZE,
		naturalSizeStuds = NATURAL,
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.new(0, 90, 0),
		sightOffsetStuds = Vector3.new(0, 0.336, -2.19),
		renderFidelity = "Automatic",
		notes = "The body half of v8: action and stock, same maps, same smoothing groups, the whole "
			.. "gun's bounding box baked in with anchor triangles so it assembles with the barrels.",
	},
	{
		key = "shotgun.barrels",
		version = 1,
		kind = "meshpart" :: Kind,
		-- THE BARREL GROUP, the piece that hinges. `Camera.Viewmodel` rotates it about the action's
		-- knuckle for the break-open reload; the server welds it to the Handle like any other
		-- scenery, so a player who is not holding this gun sees exactly what they saw before.
		modelId = 85998258056906,
		displayName = "Driven Hunt shotgun barrels r1",
		fileName = "model_barrels.fbx",
		sourceSha256 = "bddc32d0f89ec820242fd9413465ce0b5f0fbb472670b60e8781c1c52cbc77b5",
		source = "own" :: Source,
		creator = "8167651842",
		licence = {
			basis = "own-work",
			quote = "Karen generated the model in her own paid Meshy account and prepared it with "
				.. "tools/asset_prep.py; she gave the upload OK on 2026-09-26 and asked on "
				.. "2026-09-27 for a break-action reload like the real gun, which is why it ships "
				.. "in two pieces. The barrels are this repository's own geometry; the forend on "
				.. "them is hers.",
			quotedFrom = "assets/uploads.json (karenOk), PLAYTEST.md 2026-09-27, TASKS.md row 96",
			readOn = "2026-09-27",
			attribution = nil,
		},
		added = "2026-09-27",
		moderation = "approved" :: Moderation,
		trisDeclared = 2073,
		texturePx = 2048,
		sizeStuds = GUN_SIZE,
		naturalSizeStuds = NATURAL,
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.new(0, 90, 0),
		renderFidelity = "Automatic",
		notes = "The barrel half of v8: two tubes, rib, muzzle, bead and the seated forend, same "
			.. "maps and smoothing groups, the whole gun's bounding box baked in with anchor "
			.. "triangles so it assembles with the body at one CFrame.",
	},
	-- ------------------------------------------------------ the hands (task 93)
	--
	-- KAREN made both of these in her own paid Meshy account and gave the upload OK on 2026-09-27
	-- ("ok to upload"): a RIGHT hand gripping, index finger extended along the side, and a LEFT hand
	-- palm up and cupped to cradle the barrels. `tools/asset_prep.py` prepped each with the `hand`
	-- preset -- smooth shading and nothing else; her leather and her olive cuff are untouched.
	--
	-- THEY ARE `scope = "viewmodel"`, WHICH IS THE ONE THING THAT MAKES THEM DIFFERENT FROM THE GUN.
	-- A hand is never worn by a Tool and never replicated as part of one: the server loads it and
	-- publishes the template, and `Camera.Viewmodel` clones it under `workspace.CurrentCamera` for
	-- the local player alone. Other players see the character's own arms, exactly as before.
	--
	-- THE SIZE IS A FIRST PICK AND IT IS THE ONE NUMBER A SCREENSHOT DECIDES. Meshy normalises every
	-- model it makes to a two-unit box, so the file says nothing about how big a hand is -- unlike
	-- the gun, whose length is a published number (a Beretta 486 Parallelo is 1,143 mm). What is
	-- known: this game's scale is the gun's, `HANDLE_SIZE.Z` = 4.4 studs for 1,143 mm, i.e. 260 mm to
	-- the stud; and these models are a hand plus a cuff, which on a person is about 200 mm of hand
	-- and 130 mm of sleeve. 330 mm / 260 = 1.27, so the long axis is scaled UNIFORMLY to 1.28 studs
	-- and the other two axes are whatever the hand's own proportions give -- the same rule, and for
	-- the same reason, as `GUN_SIZE` above. If the hands read too big or too small against the gun in
	-- the first-person screenshot, this constant is the dial.
	--
	-- `rotationDeg` IS ZERO AND NOTHING READS IT. The gun's rotation is applied by
	-- `Weapon.Hardware`, which wears the mesh on a Tool; a hand is posed by `Camera.Viewmodel` from
	-- `Camera.Config`'s own three named degrees per hand, at one conversion site, because the pose
	-- and the orientation are the same measurement and splitting them over two files would be two
	-- dials for one thing.
	{
		key = "gun.stock",
		version = 1,
		kind = "meshpart" :: Kind,
		-- RETIRED BY TASK 105, and that is what this scope says. Karen replaced the whole gun with
		-- model B on 2026-10-02; model B's frame group IS a stock, so nothing draws this one. The
		-- row and its id stay (rule 7) and `keysFor` no longer answers with it, because no boot line
		-- asks for the scope "retired". `supersededBy` would be the wrong field: it takes a VERSION
		-- of this same key, and there is no `gun.stock` v2 -- the thing that replaced it is a
		-- different model under a different key.
		scope = "retired" :: string?,
		-- Uploaded by tools/roblox_upload.py on 2026-10-01; the row it wrote is in
		-- assets/uploads.json, and this id is that row's assetId.
		modelId = 115346777423870,
		displayName = "Driven Hunt shotgun stock r1",
		fileName = "model.fbx",
		sourceSha256 = "06a515eeefc0cf77e9a6de562c4596af9f36601ae6b285d891abeff6414bcd3b",
		source = "own" :: Source,
		creator = "8167651842", -- Karen, who is also the place owner: LoadAsset needs LoadOwnedAsset
		licence = {
			basis = "own-work",
			quote = "Karen generated the two wooden pieces of the new shotgun in her own paid Meshy "
				.. "account on 2026-10-01 and gave the upload OK the same evening, at about 23:05: "
				.. "upload ok. It was prepared with tools/asset_prep.py's hand preset -- smooth "
				.. "shading and the shine maps, textures down to 1024, and no recolour.",
			quotedFrom = "assets/uploads.json (karenOk), TASKS.md row 99",
			readOn = "2026-10-01",
			attribution = nil,
		},
		added = "2026-10-01",
		moderation = "approved" :: Moderation,
		-- MEASURED by the prep run (gun_stock_r1): 5,146 triangles, against Roblox's 20,000.
		trisDeclared = 5146,
		texturePx = 1024,
		sizeStuds = STOCK_SIZE,
		-- Read through the harness (a plugin context) off the loaded asset: a game script
		-- cannot read `SurfaceAppearance.ColorMap`. 2026-10-01.
		textureId = "rbxassetid://96976091145006",
		naturalSizeStuds = STOCK_NATURAL,
		-- MEASURED off the prepped model's bounds: the pivot is the bounding-box centre to within
		-- 0.003 of a unit on every axis, which is 2e-5 studs at this scale.
		offsetStuds = Vector3.zero,
		-- THE MESH ITSELF IS NOT MIS-ORIENTED, so there is nothing to correct here. How it is TURNED
		-- to lie on the gun is the gun's business and lives in `Gun.MESH_ROTATION_DEG` (task 99 called it `Gun.WOOD_ROTATION_DEG`): the same
		-- model on a different gun would be turned differently, and this row describes the model.
		rotationDeg = Vector3.zero,
		renderFidelity = "Automatic",
		notes = "Walnut stock with a half-pistol grip, chequering and a butt plate; the flat square "
			.. "front face is where the action fits. Looked at before it was called done "
			.. "(render_three-quarter.png): light golden walnut with strong grain, a rounded butt "
			.. "and a clean grip. Metalness written to 0 -- wood is not a metal -- and the "
			.. "generator's own roughness kept (median 0.31).",
	},
	{
		key = "hand.right",
		version = 1,
		kind = "meshpart" :: Kind,
		scope = "viewmodel",
		-- Uploaded by tools/roblox_upload.py on 2026-09-28; the row it wrote is in
		-- assets/uploads.json, and this id is that row's assetId.
		modelId = 135163569224932,
		displayName = "Driven Hunt gloved right hand r1",
		fileName = "model.fbx",
		sourceSha256 = "0b48cbfe76be38fd2d0968ca5387b37ee586ef3137e1872975a4838c3f201686",
		source = "own" :: Source,
		creator = "8167651842", -- Karen, who is also the place owner: LoadAsset needs LoadOwnedAsset
		licence = {
			basis = "own-work",
			quote = "Karen generated both hands in her own paid Meshy account on 2026-09-27 and "
				.. "gave the upload OK the same day: ok to upload (hands). They were prepared with "
				.. "tools/asset_prep.py's hand preset, which changes the shading and no colour.",
			quotedFrom = "assets/uploads.json (karenOk), TASKS.md row 93",
			readOn = "2026-09-28",
			attribution = nil,
		},
		added = "2026-09-28",
		moderation = "approved" :: Moderation,
		-- MEASURED by the prep run (hand_right_r4): 2,080 triangles, against Roblox's 20,000.
		trisDeclared = 2080,
		texturePx = 2048,
		sizeStuds = HAND_RIGHT_SIZE,
		-- Read through the harness (a plugin context) off the loaded asset: a game script
		-- cannot read `SurfaceAppearance.ColorMap`. 2026-10-01.
		textureId = "rbxassetid://134242352363086",
		-- The median of this model's own `_texture.png`, measured 2026-10-01: dark brown leather.
		fallbackColor = Color3.fromRGB(54, 44, 35),
		naturalSizeStuds = HAND_RIGHT_NATURAL,
		offsetStuds = Vector3.zero, -- measured: the model's pivot is its bounding-box centre to
		-- within 0.001 of a unit on every axis
		rotationDeg = Vector3.zero, -- see the note above: the camera poses the hand
		renderFidelity = "Automatic",
		notes = "Brown leather glove, olive jacket cuff, fingers curled into a grip with the index "
			.. "extended along the side. Smooth shading at 70 degrees (280 of 3,120 edges kept "
			.. "sharp, against 1,476 the file arrived flagged with). Metalness written to 0 -- a "
			.. "glove is not a metal -- and the generator's own roughness kept.",
	},
	{
		key = "hand.left",
		version = 1,
		kind = "meshpart" :: Kind,
		scope = "viewmodel",
		-- Uploaded by tools/roblox_upload.py on 2026-09-28; the row it wrote is in
		-- assets/uploads.json, and this id is that row's assetId.
		modelId = 89496857904040,
		displayName = "Driven Hunt gloved left hand r1",
		fileName = "model.fbx",
		sourceSha256 = "78bb1c079d849f30213e5cd4686861bddfe11381dc206b2f8e555d1c7903d0e9",
		source = "own" :: Source,
		creator = "8167651842",
		licence = {
			basis = "own-work",
			quote = "Karen generated both hands in her own paid Meshy account on 2026-09-27 and "
				.. "gave the upload OK the same day: ok to upload (hands). They were prepared with "
				.. "tools/asset_prep.py's hand preset, which changes the shading and no colour.",
			quotedFrom = "assets/uploads.json (karenOk), TASKS.md row 93",
			readOn = "2026-09-28",
			attribution = nil,
		},
		added = "2026-09-28",
		moderation = "approved" :: Moderation,
		-- MEASURED by the prep run (hand_left_r1): 2,061 triangles.
		trisDeclared = 2061,
		texturePx = 2048,
		sizeStuds = HAND_LEFT_SIZE,
		-- Read through the harness (a plugin context) off the loaded asset: a game script
		-- cannot read `SurfaceAppearance.ColorMap`. 2026-10-01.
		textureId = "rbxassetid://104214044387030",
		fallbackColor = Color3.fromRGB(54, 44, 35),
		naturalSizeStuds = HAND_LEFT_NATURAL,
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.zero,
		renderFidelity = "Automatic",
		notes = "The same glove and cuff, palm up and cupped, thumb raised: the hand a shooter "
			.. "cradles the forend in. Smooth shading at 70 degrees (268 of 3,093 edges kept sharp, "
			.. "against 1,479 the file arrived flagged with). Metalness written to 0.",
	},
	-- ------------------------------------------------- model B, Karen's chosen gun (task 105)
	--
	-- KAREN, 2026-10-02, on the exact-geometry gun tasks 99 to 103 built: "bad". She then picked a
	-- professional model and downloaded it, and gave the upload OK the same morning (~09:20, verbatim
	-- "upload ok"):
	--
	--   "Double Barrel Shotgun" by Ryan_Nein
	--   https://sketchfab.com/3d-models/double-barrel-shotgun-063cb20627ea40b0915f9d9eeb65c8dd
	--   CC-BY-4.0: commercial use allowed, THE AUTHOR MUST BE CREDITED.
	--
	-- THE CREDIT IS A LICENCE CONDITION AND IT IS KEPT IN THREE PLACES, on purpose: `CREDITS.md` at
	-- the root of the repository, the `attribution` field of each row below (which is what this
	-- manifest exists for), and the uploaded asset's own description on Roblox, which is the copy
	-- that travels with the file. `assets/uploads.json` holds the fourth, with the sha256 of exactly
	-- what was sent.
	--
	-- TWO ROWS FOR ONE MODEL, because a break-action hinges and one MeshPart cannot.
	-- `tools/gltf_split.py` splits the glTF BY NODE at the hinge and gives both halves the WHOLE
	-- gun's bounding box with two anchor triangles, so they import at one size and one origin --
	-- which is why both rows carry the same `sizeStuds` and a zero `offsetStuds`, exactly as
	-- `shotgun.handle` v9 and `shotgun.barrels` do. That trick is task 96's.
	--
	-- `sizeStuds` COMES FROM `Gun`, not from a number typed twice: the model is scaled UNIFORMLY so
	-- its own length is `HANDLE_SIZE.Z` and the other two axes are whatever the gun's proportions
	-- give (design 6.1), and `Gun.MESH_SIZE_STUDS` is that. The natural box below is the MEASURED one
	-- (the prep run's `model.glb` position accessors, times the hundred Roblox's FBX import applies),
	-- and it matches `sizeStuds` exactly because `tools/gltf_split.py` already wrote the file in
	-- studs.
	{
		key = "gun.barrels",
		version = 1,
		kind = "meshpart" :: Kind,
		scope = "viewmodel" :: string?,
		-- Uploaded by tools/roblox_upload.py on 2026-10-02; the row it wrote is in
		-- assets/uploads.json, and this id is that row's assetId.
		modelId = 114543475864056,
		displayName = "Driven Hunt model B barrel group r1",
		fileName = "model.fbx",
		sourceSha256 = "fa66b378b4e1f0ad1930bb3e485df2e8c4cca46b91269e33012b47fc6cf62f9c",
		source = "creator-store" :: Source,
		creator = "8167651842", -- Karen, who is also the place owner: LoadAsset needs LoadOwnedAsset
		licence = {
			basis = "cc-by-4.0",
			quote = "Model License: license type: CC-BY-4.0 "
				.. "(http://creativecommons.org/licenses/by/4.0/); requirements: Author must be "
				.. "credited. Commercial use is allowed.",
			quotedFrom = "license.txt, shipped with the Sketchfab download of the model",
			readOn = "2026-10-02",
			attribution = 'This work is based on "Double Barrel Shotgun" '
				.. "(https://sketchfab.com/3d-models/double-barrel-shotgun-063cb20627ea40b0915f9d9eeb65c8dd) "
				.. "by Ryan_Nein (https://sketchfab.com/Ryan_Nein) licensed under CC-BY-4.0 "
				.. "(http://creativecommons.org/licenses/by/4.0/)",
		},
		added = "2026-10-02",
		moderation = "approved" :: Moderation,
		-- MEASURED by the prep run: 268 of the model's own triangles plus the two anchors.
		trisDeclared = 270,
		texturePx = 1024,
		sizeStuds = Gun.MESH_SIZE_STUDS,
		naturalSizeStuds = Vector3.new(440.0, 66.1652, 15.5427),
		-- The anchor triangles put the box's centre at the model's own, so the pivot IS the centre.
		offsetStuds = Vector3.zero,
		-- The model arrives with its long axis along X (the prep run measured it), and this gun's is
		-- Z. `Gun.MESH_ROTATION_DEG` is the one place that quarter turn is written down.
		rotationDeg = Vector3.new(0, Gun.MESH_ROTATION_DEG, 0),
		renderFidelity = "Automatic",
		notes = "The half that swings: two 12-gauge tubes, open at both ends, and the chequered "
			.. "forend with its steel iron. Looked at before it was called done "
			.. "(render_three-quarter.png, render_muzzle.png): dark blued barrels, two round dark "
			.. "bore openings with a thin wall, walnut forend. The artist's own base colour, normal "
			.. "and ORM maps, resized to 1024 and the ORM split into the two single-channel maps "
			.. "Roblox needs; nothing recoloured.",
	},
	{
		key = "gun.frame",
		version = 1,
		kind = "meshpart" :: Kind,
		scope = "viewmodel" :: string?,
		modelId = 123900401924976,
		displayName = "Driven Hunt model B frame group r1",
		fileName = "model.fbx",
		sourceSha256 = "a1781c8eee093a1948437bce3aa43221ce9abb37b2712d969a05c17494a1f34e",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = {
			basis = "cc-by-4.0",
			quote = "Model License: license type: CC-BY-4.0 "
				.. "(http://creativecommons.org/licenses/by/4.0/); requirements: Author must be "
				.. "credited. Commercial use is allowed.",
			quotedFrom = "license.txt, shipped with the Sketchfab download of the model",
			readOn = "2026-10-02",
			attribution = 'This work is based on "Double Barrel Shotgun" '
				.. "(https://sketchfab.com/3d-models/double-barrel-shotgun-063cb20627ea40b0915f9d9eeb65c8dd) "
				.. "by Ryan_Nein (https://sketchfab.com/Ryan_Nein) licensed under CC-BY-4.0 "
				.. "(http://creativecommons.org/licenses/by/4.0/)",
		},
		added = "2026-10-02",
		moderation = "approved" :: Moderation,
		trisDeclared = 540,
		texturePx = 1024,
		sizeStuds = Gun.MESH_SIZE_STUDS,
		naturalSizeStuds = Vector3.new(440.0, 66.1652, 15.5427),
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.new(0, Gun.MESH_ROTATION_DEG, 0),
		renderFidelity = "Automatic",
		notes = "The half that does not swing: the silver action, the chequered walnut stock with "
			.. "its pistol grip, the trigger, the guard, the top lever and the safety. Looked at "
			.. "before it was called done (render_three-quarter.png).",
	},
	{
		key = "gun.shell",
		version = 1,
		kind = "meshpart" :: Kind,
		scope = "viewmodel" :: string?,
		modelId = 122800102017287,
		displayName = "Driven Hunt model B shell r1",
		fileName = "model.fbx",
		sourceSha256 = "8fb0221506322e651fa4f1712fe90381a0657b15d6173842b3df9a1976e14b33",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = {
			basis = "cc-by-4.0",
			quote = "Model License: license type: CC-BY-4.0 "
				.. "(http://creativecommons.org/licenses/by/4.0/); requirements: Author must be "
				.. "credited. Commercial use is allowed.",
			quotedFrom = "license.txt, shipped with the Sketchfab download of the model",
			readOn = "2026-10-02",
			attribution = 'This work is based on "Double Barrel Shotgun" '
				.. "(https://sketchfab.com/3d-models/double-barrel-shotgun-063cb20627ea40b0915f9d9eeb65c8dd) "
				.. "by Ryan_Nein (https://sketchfab.com/Ryan_Nein) licensed under CC-BY-4.0 "
				.. "(http://creativecommons.org/licenses/by/4.0/)",
		},
		added = "2026-10-02",
		moderation = "approved" :: Moderation,
		trisDeclared = 96,
		texturePx = 256,
		-- NO ANCHORS AND ITS OWN BOX: a loose cartridge in the gun's bounding box would be a
		-- 4.4-stud MeshPart. `tools/gltf_split.py` gives it its own frame as well -- the artist left
		-- it lying at an angle -- measured the same way the gun's is, at the GUN'S scale, so this is
		-- the size a 12-gauge really is in this gun's chambers.
		sizeStuds = Gun.SHELL_MESH_SIZE_STUDS,
		naturalSizeStuds = Vector3.new(13.685, 6.5588, 6.5577),
		offsetStuds = Vector3.zero,
		-- The mouth is at the file's +X, the same convention the gun's muzzle is written in, so it
		-- takes the same quarter turn.
		rotationDeg = Vector3.new(0, Gun.SHELL_ROTATION_DEG, 0),
		renderFidelity = "Automatic",
		notes = "A red 12-gauge shotshell with a brass head. Looked at before it was called done "
			.. "(render_three-quarter.png): red hull, brass head with lettering on it.",
	},
} :: { AssetRow }

-- The newest usable row for a key, or nil -- which means "use the grey box", not "fail".
--
-- `rows` is here so the RULES can be tested rather than only the current data: with one row per key
-- and versions in order, "skips a superseded row" and "prefers the highest version" cannot be told
-- apart by looking at `Assets.ROWS`. A spec passes its own table and asks each question separately.
-- Production never passes it.
function Assets.byKey(key: string, rows: { AssetRow }?): AssetRow?
	local best: AssetRow? = nil
	for _, row in ipairs(rows or Assets.ROWS) do
		if row.key == key and row.moderation ~= "rejected" and row.supersededBy == nil then
			if best == nil or row.version > best.version then
				best = row
			end
		end
	end
	return best
end

-- An alias, kept because consumers read like this (design 4.2).
function Assets.describe(key: string, rows: { AssetRow }?): AssetRow?
	return Assets.byKey(key, rows)
end

-- What a boot script preloads. "runtime" is everything a server needs before a player can hold it.
-- ONE KEY, ONCE, AND NEVER A SUPERSEDED ONE. The moment this table held two rows for one key it
-- started answering `{"shotgun.handle", "shotgun.handle"}`, which is what `Loader.preload` is meant
-- to be called with (design 5.2) -- two network loads for one gun, the second finding the first
-- already cached (review round 1, note). Nothing calls it that way yet; that is the point of fixing
-- it now rather than when something does.
function Assets.keysFor(scope: string): { string }
	local out, seen = {}, {}
	for _, row in ipairs(Assets.ROWS) do
		if (row.scope or "runtime") == scope and row.kind ~= "image" and row.supersededBy == nil then
			if not seen[row.key] then
				seen[row.key] = true
				table.insert(out, row.key)
			end
		end
	end
	return out
end

Shotgun.deepFreeze(Assets.ROWS)
Shotgun.deepFreeze(Assets.KEYS)

return Assets
