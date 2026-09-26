--!strict
-- Assets: THE ASSET MANIFEST. Pure data and pure lookups: no service, no Instance, no yield.
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
	renderFidelity: string,
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
		texturePx = 2048,
		sizeStuds = GUN_SIZE,
		naturalSizeStuds = NATURAL,
		offsetStuds = Vector3.zero, -- measured: the template's pivot is its bounding-box centre to
		-- within 0.003 studs
		-- THE MESH'S LONG AXIS IS ITS LOCAL X AND ITS MUZZLE IS AT -X (tools/asset_prep.py measured
		-- the muzzle end by its thinner cross-section). The Handle's -Z is the muzzle
		-- (Shotgun.CONFIG.GRIP), so -X must become -Z: a -90 degree turn about Y.
		-- ONLY A SCREENSHOT CHECKS THIS (design 6.3, and PROJECT_CONTEXT's knife held backwards).
		rotationDeg = Vector3.new(0, -90, 0),
		renderFidelity = "Automatic",
		notes = "One MeshPart with a SurfaceAppearance child; the import kept the PBR maps, so the "
			.. "viewmodel's clone must not strip non-Attachment children (design 6.6).",
	},
} :: { AssetRow }

-- The newest usable row for a key, or nil -- which means "use the grey box", not "fail".
function Assets.byKey(key: string): AssetRow?
	local best: AssetRow? = nil
	for _, row in ipairs(Assets.ROWS) do
		if row.key == key and row.moderation ~= "rejected" then
			if best == nil or row.version > best.version then
				best = row
			end
		end
	end
	return best
end

-- An alias, kept because consumers read like this (design 4.2).
function Assets.describe(key: string): AssetRow?
	return Assets.byKey(key)
end

-- What a boot script preloads. "runtime" is everything a server needs before a player can hold it.
function Assets.keysFor(scope: string): { string }
	local out = {}
	for _, row in ipairs(Assets.ROWS) do
		if scope == "runtime" and row.kind ~= "image" then
			table.insert(out, row.key)
		end
	end
	return out
end

Shotgun.deepFreeze(Assets.ROWS)
Shotgun.deepFreeze(Assets.KEYS)

return Assets
