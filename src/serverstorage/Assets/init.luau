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
	renderFidelity: string,
	-- SET WHEN A LATER VERSION REPLACES THIS ROW. The row STAYS (rule 7: never delete, archive
	-- with a note) -- an id that has been in a place is provenance, and a moderated-away or
	-- rolled-back asset is undiagnosable without it. `byKey` skips a superseded row even if it is
	-- somehow the highest version, so the FIELD is the decision and the version number is not.
	supersededBy: number?,
	notes: string?,
}

-- THE KEY STRINGS, ONE HOME. The reason is `Map.TAGS`': a typo in a literal is a silent nil and a
-- grey box nobody can explain.
Assets.KEYS = table.freeze({
	shotgunHandle = "shotgun.handle",
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
		if scope == "runtime" and row.kind ~= "image" and row.supersededBy == nil then
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
