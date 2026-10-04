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

-- "bought": paid for outside the Creator Store, under a licence that allows commercial use and
--           hosting but FORBIDS REDISTRIBUTION -- so the asset is PRIVATE in Karen's account
--           and is never listed. The oak pack is this (task 121).
export type Source = "meshy" | "creator-store" | "roblox" | "own" | "bought"
-- "meshpart": the template is EXACTLY ONE MeshPart. The Loader returns that MeshPart and destroys
--             the Model wrapper it arrived in. The gun is this.
-- "model":    the template is a tree; the Loader returns the Model. Map props may be this.
-- "animation": the row carries an ANIMATION ASSET ID and nothing else is inserted. `Loader` never
--              touches one -- an animation is not an Instance you insert, it is a number you put on
--              an `Animation.AnimationId` -- so `Assets.INSERTABLE` keeps it out of `keysFor`, and
--              the only consumer is `Boar.Body`, which reads the id through `byKey`.
export type Kind = "meshpart" | "model" | "image" | "animation"
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
	-- THE CONSUMER MUST NOT WRITE `Size` ON THIS ONE (task 115). Design 6.1's rule is "the consumer
	-- sets Size, always", and for a SKINNED mesh that rule is wrong: `Size` (and `Model:ScaleTo`)
	-- scales the mesh and NOT the bones, so the model tears the moment a clip plays -- measured by
	-- the Director on 2026-10-03. The scale of such a model is baked into the uploaded geometry
	-- instead (`tools/boar_prep.py`), and this field is how the row says so. `sizeStuds` then
	-- records what it ALREADY measures rather than what to set it to, and `nil`/false is every row
	-- that predates the boar.
	bakedScale: boolean?,
	-- HOW LONG THIS ANIMATION RUNS, in seconds, for a `kind = "animation"` row and nothing else
	-- (task 115). MEASURED by reading the published asset back with
	-- `AnimationClipProvider:GetAnimationClipAsync` and taking its last keyframe's `Time` -- which is
	-- the only honest source, and it is not the frame count: 101 frames at 24 fps SPAN 100 intervals,
	-- so the clip is 4.167 s and not 4.208. `BoarAssetsBoot` compares this against the number
	-- `Boar.CONFIG.MODEL.CLIPS` carries and warns if the two copies have drifted.
	clipSeconds: number?,
	notes: string?,
}

-- THE KEY STRINGS, ONE HOME. The reason is `Map.TAGS`': a typo in a literal is a silent nil and a
-- grey box nobody can explain.
Assets.KEYS = table.freeze({
	shotgunHandle = "shotgun.handle",
	-- THE FIRST PAIR OF FIRST-PERSON HANDS (task 93), RETIRED BY TASK 114. They are not the gun and
	-- they are not the map: nobody but the player holding the shotgun ever saw them, which is why
	-- they carry a scope of their own below -- and that scope is now "retired", because the gun they
	-- were posed against is gone. The keys stay for the reason `gunStock` does: an id that has been
	-- in a place is provenance (rule 7).
	handRight = "hand.right",
	gunStock = "gun.stock",
	-- MODEL B'S TWO HINGE GROUPS AND ITS SHELL (task 105). Karen picked a professional CC-BY model
	-- on 2026-10-02 after calling the exact-geometry gun "bad"; `tools/gltf_split.py` splits it at
	-- the hinge and `Gun.MESH_KEYS` names these two, so the gun's geometry and this table cannot
	-- disagree about which half swings.
	gunBarrels = "gun.barrels",
	gunFrame = "gun.frame",
	gunShell = "gun.shell",
	-- THE GLOVES THAT HOLD MODEL B (task 106, round 2), AND SINCE TASK 114 THE ONLY PAIR. They are a
	-- DIFFERENT KEY rather than a new version of `hand.right`/`hand.left`, and that is finding 1 of
	-- round 1: a new version supersedes, and `byKey` would then have handed the OLD gun -- the
	-- flag-OFF default build -- a pair it was never posed for. The keys stay different now that the
	-- old pair is retired, because `supersededBy` takes a VERSION of the same key and these are a
	-- different model (the same reason `gun.stock` is not a `gun.frame` version).
	gunHandRight = "gun.hand.right",
	gunHandLeft = "gun.hand.left",
	handLeft = "hand.left",
	-- THE BOAR (task 115). One key for the skinned model, and one per clip.
	--
	-- THE TEN CLIP KEYS HAVE NO ROWS YET, AND THAT IS NOT AN OVERSIGHT. An animation asset id can
	-- only be made inside Studio: Open Cloud's Assets API takes an Animation as a `.rbxm`/`.rbxmx`
	-- that was "edited inside Roblox Studio" and nothing outside Studio can write one, and
	-- `AssetService:CreateAssetAsync` answered "CreateAssetAsync and CreateAssetVersionAsync are not
	-- available yet" for both Animation and Model when it was tried here on 2026-10-03. So the ids
	-- arrive from the Animation Editor's "Publish to Roblox", one clip at a time, and
	-- `ESCALATE.md`'s NEEDS DIRECTOR CLICKS entry is the ten clicks, and the rows they will become
	-- carry `kind = "animation"` and `scope = "boar-animation"` -- `INSERTABLE` below is what keeps
	-- them away from `InsertService`, so the scope name is a label and not a mechanism. The KEYS live
	-- here anyway, now,
	-- for the reason `Map.TAGS` gives: a key typed as a literal at the one place that reads it is a
	-- silent nil nobody can explain. Until the rows exist, `byKey` answers nil, `Boar.Body` welds the
	-- model and plays nothing, and the boar stands still -- which is honest and is tested.
	boarMale = "boar.male",
	-- THE SOW AND THE CUB (task 119). Karen: "we need also biger smaller kids ect", and the agreed
	-- makeup is that a sounder is a sow with young while a lone animal is a male. Same package, same
	-- skeleton (`Arm_Boar`, 46 bones), same prep tool, different length baked in.
	boarFemale = "boar.female",
	boarCub = "boar.cub",
	boarIdle = "boar.anim.idle",
	boarWalk = "boar.anim.walk",
	boarTrot = "boar.anim.trot",
	boarRun = "boar.anim.run",
	boarTurnLeft = "boar.anim.turn.left",
	boarTurnRight = "boar.anim.turn.right",
	boarDeathLeft = "boar.anim.death.left",
	boarDeathRight = "boar.anim.death.right",
	boarHitFront = "boar.anim.hit.front",
	boarHitBack = "boar.anim.hit.back",
	-- (Task 117's six are published too; their rows are with the rest, further down this file.)
	-- THE THREE THIS PROJECT AUTHORED (task 116 fix round): `tools/boar_prep.py` writes
	-- `Death_Paddle_L.fbx`, `Death_Paddle_R.fbx` and `Cripple_Drag.fbx`, and an animation asset id
	-- can only be made by hand in Studio's Animation Editor (see the block above, and ESCALATE.md).
	-- The Director published all three on 2026-10-03 and their rows are further down this file. A
	-- declared key with no row is the honest state until a publish: `Assets.byKey` answers nil,
	-- `Boar.Body.hasClip` is false, and the boar behaves exactly as it did before the clips existed.
	boarDeathPaddleLeft = "boar.anim.death.paddle.left",
	boarDeathPaddleRight = "boar.anim.death.paddle.right",
	boarCrippleDrag = "boar.anim.cripple.drag",
	-- THE CALM BOAR (task 117), declared before publishing exactly as the three above were.
	boarSmell = "boar.anim.calm.smell",
	boarGrazeLoop = "boar.anim.calm.graze.loop",
	boarGrazeChew = "boar.anim.calm.graze.chew",
	boarGrazeStart = "boar.anim.calm.graze.start",
	boarGrazeEnd = "boar.anim.calm.graze.end",
	boarDigWalk = "boar.anim.calm.dig.walk",
	-- THE FOREST (task 121). SEVEN DISTINCT AUTUMN OAKS, each published once as a PRIVATE Model
	-- asset in Karen's account out of the pack she bought -- never listed on the Creator Store,
	-- because the licence forbids redistribution and a listing IS redistribution.
	--
	-- SEVEN KEYS AND NOT ONE, and that is what the meshes were bought for: `Config.SPECIES.oak.keys`
	-- names a LIST per tier and each tree draws its own index from its own hash stream, so the wood
	-- is seven shapes at seven yaws instead of ~1,600 copies of one mesh. One mesh over a whole wood
	-- is the colonnade TASKS.md row 79a(d) already reported.
	oakForest01 = "tree.oak.forest01",
	oakForest02 = "tree.oak.forest02",
	oakForest03 = "tree.oak.forest03",
	oakField04 = "tree.oak.field04",
	oakField05 = "tree.oak.field05",
	oakField06 = "tree.oak.field06",
	oakField07 = "tree.oak.field07",
	-- OUR OWN TIMBER STAND, declared before it exists: research found no Drueckjagdbock model
	-- anywhere, so `MapGen.Props.stands` draws one from parts and this key is the seam one mesh
	-- replaces it through. `byKey` answers nil, which means "draw the proxy", not "fail".
	standTower = "prop.standtower",
	-- THE FOUR CC0 GROUND TEXTURES, as `kind = "image"` rows when they land: an image is an id a
	-- property carries and not an Instance to insert, which is why `INSERTABLE` below excludes the
	-- kind. Declared before the rows exist, so a missing one is a NAMED key in the materials step's
	-- report rather than silently grey ground.
	groundLitter = "ground.litter",
	groundGrassRide = "ground.grassride",
	groundGravel = "ground.gravel",
	groundMud = "ground.mud",
})

-- WHICH KINDS `Loader` CAN TURN INTO AN INSTANCE, and therefore which ones `keysFor` may hand a boot
-- script to preload. An "image" is a texture id a property carries; an "animation" is a number an
-- `Animation.AnimationId` carries. Calling `InsertService:LoadAsset` on either is a load that can
-- only fail, and a boot script that spent its budget on one would delay the model that does need it.
Assets.INSERTABLE = table.freeze({ meshpart = true, model = true })

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

-- THE HANDS (task 93), by the same rule and written out the same way: scale UNIFORMLY, and let the
-- other two axes be whatever the hand's own proportions give. Every natural box is MEASURED off that
-- prepped model's own vertex bounds (the run's `model.glb` position accessors, times the hundred
-- Roblox's FBX import applies -- the same hundred that makes the gun's two-unit model 200 units long
-- above).
--
-- TWO PAIRS OF HANDS, ONE PER GUN (task 106, round 2). The OLD gun -- the flag-OFF default build --
-- keeps the v1 pair at the v1 dial, because the TOP-LEVEL poses in `poses.json` were measured
-- against those models and nothing in this task re-measured them. Model B gets Karen's new pair
-- under its own keys. Round 1 shipped the new pair as `hand.right` v2, which supersedes, so the old
-- gun was handed a glove it was never posed for: upside down and at 53 % of the size its poses
-- assume.
--
-- THE NEW PAIR'S SIZE IS PINNED TO THE GRIP, NOT TO THE HAND'S LENGTH, and that is the measured fix
-- for a glove that was the biggest thing in the frame. The v1 dial is the model's LONGEST axis set
-- to 1.27 studs ("a hand plus a cuff is about 330 mm"), which is right for a real hand and wrong for
-- a generated one: Karen's gloves are chunky, so at 1.27 long the new right glove measured 0.665
-- studs ACROSS THE FINGERS -- 173 mm, nearly twice an adult palm -- and the aimed capture of task
-- 105 showed exactly that.
--
-- SO THE ANCHOR IS THE THING THE HAND HAS TO FIT. MEASURED on model B
-- (`tools/gltf_split.py probe`): the stock's WRIST -- the narrow grip between the action's rear and
-- the comb -- runs from z +0.928 to +1.248, which is 0.320 studs, or 83 mm at this gun's 259.8 mm to
-- the stud. A fist closed round a wrist that size is about an adult palm across, 90 mm, so
-- `HAND_ACROSS_STUDS` is 0.35 and the whole model follows from it uniformly.
local HAND_ACROSS_STUDS = 0.35
-- MEASURED off the v2 prep runs (glove_right_v4_r1, glove_left_v4_r1). The right glove's longest
-- axis is X and the LEFT glove's is Z: a palm-up C grip puts the forearm at an angle to the fingers,
-- so its bounding box is a diagonal and no axis is "the hand". That is why the helper below takes
-- the LONGEST axis rather than X.
local HAND_RIGHT_NATURAL = Vector3.new(189.8336, 99.3031, 59.8539)
local HAND_LEFT_NATURAL = Vector3.new(178.9431, 151.8857, 190.2365)
-- The v1 gloves' boxes and their own dial. NOTHING DRAWS THESE SINCE TASK 114 -- the gun whose poses
-- were measured at them is gone, and both rows are `scope = "retired"` below -- so this IS an archive
-- number: 1.27 studs is 330 mm of hand and cuff at this game's scale, and it is the size the retired
-- pair was published at.
local HAND_V1_LENGTH_STUDS = 1.27
local HAND_RIGHT_V1_NATURAL = Vector3.new(190.04, 84.99, 78.93)
local HAND_LEFT_V1_NATURAL = Vector3.new(189.64, 95.52, 72.04)
-- ...so the one dial above becomes the LENGTH the helper below takes: the right glove's own
-- longest-to-across ratio, times the palm it has to be. 0.35 x 189.83 / 99.30 = 0.669 studs, which
-- is 174 mm of glove and cuff. The LEFT glove is scaled to the same number and the pair comes out
-- the same size, because their longest axes are within 0.3 % of each other.
local HAND_LENGTH_STUDS = HAND_ACROSS_STUDS * HAND_RIGHT_NATURAL.X / HAND_RIGHT_NATURAL.Y
-- THE WOOD (task 99), by the same rule: MEASURED off the prepped model's own vertex bounds (the
-- run's `model.glb` position accessors, times the hundred Roblox's FBX import applies), then
-- scaled UNIFORMLY so the LONG AXIS is what `Gun` says that piece is on this gun. The other two
-- sizes are whatever the wood's own proportions give -- a stock squashed to a chosen box measures
-- perfectly and looks wrong (design 6.1, the squashed boar).
local STOCK_NATURAL = Vector3.new(190.153, 69.262, 17.743)
-- UNIFORM TO THE LONGEST AXIS, not to X (task 106). Every model before the new gloves happened to
-- arrive long-axis-X, so `length / natural.X` was the same thing; the LEFT glove's longest axis is
-- Z, and dividing by X there would have scaled it 6 % large against its own pair for no reason
-- anybody could see.
local function uniformTo(natural: Vector3, length: number): Vector3
	local scale = length / math.max(natural.X, natural.Y, natural.Z)
	return Vector3.new(natural.X * scale, natural.Y * scale, natural.Z * scale)
end

-- THE STOCK'S SIZE IS FROZEN AT WHAT TASK 102 SHIPPED, and nothing asks for it any more: model B
-- carries its own chequered stock, so `gun.stock` is retired below rather than scaled to a gun that
-- no longer has a hole for it. The row stays, with its id, because an id that has been in a place is
-- provenance (rule 7), and the number stays with the row it belongs to.
local STOCK_SIZE = Vector3.new(1.32, 0.4808, 0.255)
local HAND_RIGHT_SIZE = uniformTo(HAND_RIGHT_NATURAL, HAND_LENGTH_STUDS)
local HAND_LEFT_SIZE = uniformTo(HAND_LEFT_NATURAL, HAND_LENGTH_STUDS)
-- THE v1 GLOVES KEEP THEIR OWN DIAL, computed the same way, so their retired rows still say what
-- they were published at. `uniformTo` pins the longest axis, and on both v1 models that is X, so
-- these are bit-for-bit the sizes that shipped before task 106.
local HAND_RIGHT_V1_SIZE = uniformTo(HAND_RIGHT_V1_NATURAL, HAND_V1_LENGTH_STUDS)
local HAND_LEFT_V1_SIZE = uniformTo(HAND_LEFT_V1_NATURAL, HAND_V1_LENGTH_STUDS)

-- THE ONE LICENCE MODEL B IS USED UNDER, written once because it is the same condition on every row
-- of it and a credit that drifts between copies is a credit nobody can rely on. CC-BY-4.0 asks for
-- exactly one thing, and `CREDITS.md` carries the same words at the root of the repository.
local MODEL_B_LICENCE = {
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
}

-- THE BOAR'S MEASURED SIZE (task 115), read in Studio off the loaded asset 120607820179994 on
-- 2026-10-03: one skinned MeshPart, Size (1.4011, 3.2573, 5.5000). The Z is `Boar.CONFIG.BODY_SIZE.Z`
-- exactly, which is what the model was scaled to; the other two are the animal's own proportions.
-- It is a constant and not a literal in the row because `Boar.Body`'s own spec asserts against the
-- same number, and two copies of a measurement drift.
local BOAR_MALE_SIZE = Vector3.new(1.4011, 3.2573, 5.5)
-- ...AND THE SOW AND THE CUB (task 119), the same measurement at the two smaller lengths. Blender
-- exports (width, length, height) and Roblox's importer lands it as (width, height, length), which is
-- why the lengths below are the Z: 4.675 is 0.85 of the male and 2.475 is 0.45 of him, which is the
-- Director's decision of 2026-10-04 and is what `tools/boar_prep.py` baked into the geometry.
local BOAR_FEMALE_SIZE = Vector3.new(1.202, 2.647, 4.675)
local BOAR_CUB_SIZE = Vector3.new(0.618, 1.439, 2.475)

-- WHAT AN ANIMATION ROW PUTS IN THE GEOMETRY FIELDS `AssetRow` REQUIRES OF EVERY ROW. Named, so a
-- reader meets "no geometry" instead of a zero vector they have to decide about, and so a grep finds
-- every row that is not a thing you can see.
local NO_GEOMETRY = Vector3.zero
local NO_FIDELITY = "n/a"

-- THE ONE LICENCE THE BOAR IS USED UNDER. Karen bought the package; the licence is hers and this
-- row is the record of it.
--
-- WHAT COULD NOT BE VERIFIED HERE, said plainly (rule 8): `https://www.fab.com/eula` answers 403 to
-- this machine's fetch tool, so the grant below was read from a web search of that page on
-- 2026-10-03 and NOT from the page itself. The two conditions that matter to this repository are not
-- in doubt either way and are both met: the model is a COMPONENT of a game that adds its own value,
-- and it is never distributed on a standalone basis -- the binary is never committed (`.rbxm` is
-- banned outright), and what reaches Roblox is one asset inside Karen's own account, used by her own
-- place. If the exact clause ever matters, Karen has the purchase and the Fab licence page.
local BOAR_LICENCE = {
	basis = "fab-standard",
	quote = 'A "Standard License" grants you a non-exclusive and non-transferable license to '
		.. "privately use, reproduce, display, perform, and modify the Content in accordance with "
		.. "the terms of this Agreement. [...] you may not Distribute Content on a standalone basis "
		.. "to third parties except to your collaborators",
	quotedFrom = "fab.com/eula, read through a web search on 2026-10-03; the page itself answers 403 "
		.. "to this machine (see the comment above)",
	readOn = "2026-10-03",
	attribution = 'Wild boar models and animations: "Boar Family" by RedDeer, bought on Fab '
		.. "(https://www.fab.com) under the Fab Standard License on 2026-10-03",
}

-- ---------------------------------------------------------------- the forest (task 121)

-- THE OAK PACK'S LICENCE. Karen bought BuiltByBit's "Realistic Oak Tree Pack"; the Standard EULA
-- allows commercial use, hosting and modification and FORBIDS redistribution and resale. The
-- consequence is recorded on every row below and it is not a formality: each tree is published as a
-- PRIVATE Model asset in Karen's own account, and listing one on the Creator Store would be
-- redistribution.
--
-- THE QUOTE IS THE DIRECTOR'S RECORD OF THE PURCHASE, not a sentence this Builder read off the
-- vendor's own site -- which is why `quotedFrom` names the brief rather than a URL. Saying so is
-- the point: a licence line nobody can trace is worse than one that names where it came from.
local OAK_LICENCE: Licence = {
	basis = "BuiltByBit Standard EULA (paid asset pack)",
	quote = "commercial use, hosting, modification OK; no redistribution/resale",
	quotedFrom = "reviews/task-121/BRIEF.md, decision 4 -- the Director carrying Karen's purchase record",
	readOn = "2026-10-04",
	attribution = "BuiltByBit: Realistic Oak Tree Pack. Never listed on the Creator Store.",
}

-- ONE SHA FOR ALL SEVEN, because all seven came out of ONE bought file. `sourceSha256` records what
-- arrived, and what arrived is `oak.rbxm`; seven different digests here would claim seven downloads
-- that never happened.
local OAK_SHA = "4f060906a68479caf3838450a307ae1f17cf7a6c0b9149fc55f4b3108e0643c3"

-- THE MATURE OAK'S TARGET BOX (`Config.SPECIES.oak`: 34 studs of crown, 78 of height). It is here
-- for the record and NOT as something a consumer writes: a tree is scaled UNIFORMLY by its height
-- (`MapGen.Props.placeTree`), because writing a non-uniform `Size` onto a tree squashes it and a
-- squashed tree measures perfectly -- the same argument the gun's own row makes further up.
local OAK_TARGET = Vector3.new(34, 78, 34)

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
		-- RETIRED BY TASK 114, and that is what this scope says -- the same shape `gun.stock` took
		-- when model B replaced the drawn gun. Karen accepted model B and the gloves she made to hold
		-- it, so the gun flag retired and the gun THIS pair was posed against went with it;
		-- nothing draws them, and `keysFor("viewmodel")` no longer answers with them, because no boot
		-- line asks for the scope "retired". The row and its id stay (rule 7): an id that has been in
		-- a place is provenance. `supersededBy` would be the wrong field -- it takes a VERSION of this
		-- same key, and what replaced these is a different model under `gun.hand.right`.
		scope = "retired" :: string?,
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
		sizeStuds = HAND_RIGHT_V1_SIZE,
		-- Read through the harness (a plugin context) off the loaded asset: a game script
		-- cannot read `SurfaceAppearance.ColorMap`. 2026-10-01.
		textureId = "rbxassetid://134242352363086",
		-- The median of this model's own `_texture.png`, measured 2026-10-01: dark brown leather.
		fallbackColor = Color3.fromRGB(54, 44, 35),
		naturalSizeStuds = HAND_RIGHT_V1_NATURAL,
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
		scope = "retired" :: string?, -- task 114, with `hand.right` above: see that row
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
		sizeStuds = HAND_LEFT_V1_SIZE,
		-- Read through the harness (a plugin context) off the loaded asset: a game script
		-- cannot read `SurfaceAppearance.ColorMap`. 2026-10-01.
		textureId = "rbxassetid://104214044387030",
		fallbackColor = Color3.fromRGB(54, 44, 35),
		naturalSizeStuds = HAND_LEFT_V1_NATURAL,
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
		supersededBy = 2, -- task 105: v2 takes the sky mirror out (see the block above v2)
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
		licence = MODEL_B_LICENCE,
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
		-- Z -- and the import also brings it in REVERSED along that axis (task 107, measured on
		-- screen). `Gun.MESH_ROTATION_DEG` is the one place both turns are written down.
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
		supersededBy = 2, -- task 105: v2 takes the sky mirror out (see the block above v2)
		kind = "meshpart" :: Kind,
		scope = "viewmodel" :: string?,
		modelId = 123900401924976,
		displayName = "Driven Hunt model B frame group r1",
		fileName = "model.fbx",
		sourceSha256 = "a1781c8eee093a1948437bce3aa43221ce9abb37b2712d969a05c17494a1f34e",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = MODEL_B_LICENCE,
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
		supersededBy = 2, -- task 105: v2 takes the sky mirror out (see the block above v2)
		kind = "meshpart" :: Kind,
		scope = "viewmodel" :: string?,
		modelId = 122800102017287,
		displayName = "Driven Hunt model B shell r1",
		fileName = "model.fbx",
		sourceSha256 = "8fb0221506322e651fa4f1712fe90381a0657b15d6173842b3df9a1976e14b33",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = MODEL_B_LICENCE,
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
	-- ------------------------------- model B v2: the sky mirror, measured and taken out (task 105)
	--
	-- WHAT v1 LOOKED LIKE IN THE GAME, WHICH IS THE ONLY PLACE IT COUNTS (rule 5). The first upload
	-- carried the artist's own ORM map untouched, as the dispatch asked -- metalness 0.98 over every
	-- steel surface -- and the aimed capture showed the barrels as a WHITE mirror filling the lower
	-- half of the frame (`.screenshots/20261002T100632Z-pose-aim.png`). That is task 100's finding
	-- arriving through a different door: a conductor's colour is what it REFLECTS, and in Roblox
	-- daylight over an open field that is the sky. Looking DOWN a tube makes it worse, because every
	-- visible surface is then at a grazing angle.
	--
	-- MEASURED IN FOUR STEPS, in a live session, before anything was re-uploaded:
	--   1. the published texture itself is fine -- put on a Decal in front of the camera it drew the
	--      whole atlas, walnut and steel (`...100703Z-texprobe.png`);
	--   2. so is the published MESH -- cloned into Workspace and lit from the side it was a dark
	--      blued rod (`...100810Z-meshprobe.png`);
	--   3. `AlphaMode.Transparency`, and then destroying the SurfaceAppearance and putting the same
	--      colour map on `TextureID` with `SmoothPlastic`, BOTH left it white
	--      (`...100542Z`, `...100928Z`) -- so it was never the white-glove fault of task 99;
	--   4. `Enum.Material.Fabric`, which has no specular lobe at all, fixed it on the spot
	--      (`...101019Z-pose-aim.png`): flat grey tubes with the valley line between them.
	-- The specular response was the defect, so the fix is in the MAP Roblox reads: metalness 0.10 and
	-- roughness 0.50, which are the gun preset's own measured numbers for "gloss, not mirror".
	--
	-- AND THE ALBEDO HAD TO CARRY THE DARKNESS THE REFLECTION USED TO. With the mirror gone the
	-- artist's own base colour is what shows, and it is pale: RGB(154, 157, 157) at the barrels'
	-- triangles and RGB(89, 77, 72) at the action's, so the r2 prep rendered a taupe tube and a WHITE
	-- action. Each hinge group is its own file, so each gets its own target -- blued RGB(34, 36, 42)
	-- for the barrels, case-hardened RGB(78, 79, 82) for the action -- and the two still read as two
	-- materials. `tools/asset_prep.py`'s `model-b-barrels` and `model-b-frame` presets hold both.
	--
	-- v1'S ROWS STAY, WITH THEIR IDS (rule 7): they are the record of what was measured.
	{
		key = "gun.barrels",
		version = 2,
		kind = "meshpart" :: Kind,
		scope = "viewmodel" :: string?,
		modelId = 113789244777033,
		displayName = "Driven Hunt model B barrel group r2",
		fileName = "model.fbx",
		sourceSha256 = "c7864330609143d0465e655eba81c52e2271eec2272722ef96b4c961e378e286",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = MODEL_B_LICENCE,
		added = "2026-10-02",
		moderation = "approved" :: Moderation,
		trisDeclared = 270,
		texturePx = 1024,
		sizeStuds = Gun.MESH_SIZE_STUDS,
		naturalSizeStuds = Vector3.new(440.0, 66.1652, 15.5427),
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.new(0, Gun.MESH_ROTATION_DEG, 0),
		renderFidelity = "Automatic",
		notes = "As v1 -- two 12-gauge tubes open at both ends, and the chequered forend with its "
			.. "steel iron -- with metalness written down to 0.10, roughness to 0.50 and the steel's "
			.. "base colour moved onto blued RGB(34, 36, 42) (measured drift 8). Looked at before it "
			.. "was called done (render_three-quarter.png): deep blued tubes, two round dark bore "
			.. "openings, walnut forend. The walnut is untouched and written to metalness 0.",
	},
	{
		key = "gun.frame",
		version = 2,
		kind = "meshpart" :: Kind,
		scope = "viewmodel" :: string?,
		modelId = 140462781926086,
		displayName = "Driven Hunt model B frame group r2",
		fileName = "model.fbx",
		sourceSha256 = "061c143fa65dea9e120478e7d59f95a3a751e791c75e26d2288a313c41f595e3",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = MODEL_B_LICENCE,
		added = "2026-10-02",
		moderation = "approved" :: Moderation,
		trisDeclared = 540,
		texturePx = 1024,
		sizeStuds = Gun.MESH_SIZE_STUDS,
		naturalSizeStuds = Vector3.new(440.0, 66.1652, 15.5427),
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.new(0, Gun.MESH_ROTATION_DEG, 0),
		renderFidelity = "Automatic",
		notes = "As v1 -- the action, the chequered walnut stock with its pistol grip, the trigger, "
			.. "the guard, the top lever and the safety -- with metalness 0.10, roughness 0.50 and "
			.. "the steel's base colour on case-hardened RGB(78, 79, 82). Looked at "
			.. "(render_three-quarter.png): a dark engraved action against warm walnut.",
	},
	{
		key = "gun.shell",
		version = 2,
		kind = "meshpart" :: Kind,
		scope = "viewmodel" :: string?,
		modelId = 107524331758435,
		displayName = "Driven Hunt model B shell r2",
		fileName = "model.fbx",
		sourceSha256 = "cfdcebdc4c4951e3156fbdd6ee74bb137e239c1cfe590f2906ea63edb54aa955",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = MODEL_B_LICENCE,
		added = "2026-10-02",
		moderation = "approved" :: Moderation,
		trisDeclared = 96,
		texturePx = 256,
		sizeStuds = Gun.SHELL_MESH_SIZE_STUDS,
		naturalSizeStuds = Vector3.new(13.685, 6.5588, 6.5577),
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.new(0, Gun.SHELL_ROTATION_DEG, 0),
		renderFidelity = "Automatic",
		notes = "As v1 -- a red 12-gauge shotshell with a brass head -- with metalness 0.10 and "
			.. "roughness 0.50 on the brass. Its colour is NOT recoloured: a brass head is already "
			.. "brass, so it keeps the `model-b` preset, which moves no pixel.",
	},
	-- ------------------------------------------------- Karen's new gloves (task 106)
	--
	-- KAREN made both in her own paid Meshy account on 2026-10-02 and gave the upload OK the same day,
	-- verbatim: "upload ok". They replace the v1 pair, whose rows stay above with their ids (rule 7).
	--
	-- WHAT IS DIFFERENT, AND IT IS WHY THEY WERE MADE: these two gloves HOLD SOMETHING. The v1 pair
	-- were a closed fist and a flat cupped palm, so on model B's thin wood there was nothing for the
	-- fingers to be round -- they read as mittens laid against the gun. The right one here grips with
	-- three fingers round an OPEN GAP, the thumb over and the index straight along the side (the
	-- trigger-guard finger); the left is a palm-up C with a gap between the thumb and the curled
	-- fingers, which is a hand a forend sits IN. Both wear the olive sleeve with a turned cuff.
	--
	-- THEY ARE `scope = "viewmodel"` for the reason the retired v1 pair were: a hand is never worn by a Tool
	-- and never replicated as part of one. The server loads it and publishes the template, and
	-- `Camera.Viewmodel` clones it under `workspace.CurrentCamera` for the local player alone.
	--
	-- `rotationDeg` IS ZERO AND NOTHING READS IT, also as before: a hand is posed by
	-- `Camera.Viewmodel` from `Viewmodel.DATA`'s own three named degrees per hand, at one conversion
	-- site, because the pose and the orientation are the same measurement and splitting them over two
	-- files would be two dials for one thing.
	{
		key = "gun.hand.right",
		version = 1,
		kind = "meshpart" :: Kind,
		scope = "viewmodel",
		-- Uploaded by tools/roblox_upload.py on 2026-10-02; the row it wrote is in
		-- assets/uploads.json, and this id is that row's assetId.
		modelId = 97259644277702,
		displayName = "Driven Hunt gloved right hand r2",
		fileName = "model.fbx",
		sourceSha256 = "ddb3e7d1ac1cd39679d0806619f05602544ffd52ac0bc80cbde9add097d1f9cc",
		source = "own" :: Source,
		creator = "8167651842", -- Karen, who is also the place owner: LoadAsset needs LoadOwnedAsset
		licence = {
			basis = "own-work",
			quote = "Karen generated both gloves in her own paid Meshy account on 2026-10-02 and "
				.. "gave the upload OK the same day: upload ok. They were prepared with "
				.. "tools/asset_prep.py's hand preset -- smooth shading, the textures down to 1024 "
				.. "and metalness written to 0 -- and no colour was changed.",
			quotedFrom = "assets/uploads.json (karenOk), TASKS.md row 106",
			readOn = "2026-10-02",
			attribution = nil,
		},
		added = "2026-10-02",
		moderation = "approved" :: Moderation,
		-- MEASURED by the prep run (glove_right_v4_r1): 6,192 triangles, against Roblox's 20,000.
		trisDeclared = 6192,
		texturePx = 1024,
		sizeStuds = HAND_RIGHT_SIZE,
		naturalSizeStuds = HAND_RIGHT_NATURAL,
		-- MEASURED off the prepped model's bounds: the pivot is the bounding-box centre to within
		-- 0.001 of a unit on every axis, which is 4e-6 studs at this scale.
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.zero, -- see the note above: the camera poses the hand
		renderFidelity = "Automatic",
		-- THE COLOUR MAP'S OWN ID, read through the harness off the loaded asset on 2026-10-02 (a
		-- plugin context; a game script cannot read `SurfaceAppearance.ColorMap` at all).
		-- IT WAS LOOKED AT FIRST, and this row was written because of what was on screen: with the
		-- field nil the glove rendered as a WHITE blob beside the barrels
		-- (`.screenshots/20261002T110256Z-pose-aim.png`), which is task 99's white glove exactly --
		-- `ViewmodelAssetsBoot.showItsOwnColour` destroys the `SurfaceAppearance` whose map cannot
		-- draw, and with no id to put on `TextureID` the part is left at Roblox's default grey.
		textureId = "rbxassetid://97720740621443",
		-- The median of this model's own prepped `texture_baseColor.png`, measured 2026-10-02: dark
		-- brown leather. It is what shows if even `TextureID` fails.
		fallbackColor = Color3.fromRGB(60, 40, 28),
		notes = "Brown leather glove, olive jacket cuff; three fingers curled round an open gap with "
			.. "the thumb over and the index straight along the side -- a hand closed on a stock "
			.. "wrist rather than on itself. Smooth shading at 70 degrees. Metalness written to 0 "
			.. "(a glove is not a metal) and the generator's own roughness kept (median 0.50). "
			.. "Textures 2048 and 4096 down to 1024.",
	},
	{
		key = "gun.hand.left",
		version = 1,
		kind = "meshpart" :: Kind,
		scope = "viewmodel",
		modelId = 74971853808718,
		displayName = "Driven Hunt gloved left hand r2",
		fileName = "model.fbx",
		sourceSha256 = "216f6a9dbe67c1ee9623ad47d00760cc197d182b0eb9b63b897c112cdb31fe2f",
		source = "own" :: Source,
		creator = "8167651842",
		licence = {
			basis = "own-work",
			quote = "Karen generated both gloves in her own paid Meshy account on 2026-10-02 and "
				.. "gave the upload OK the same day: upload ok. They were prepared with "
				.. "tools/asset_prep.py's hand preset -- smooth shading, the textures down to 1024 "
				.. "and metalness written to 0 -- and no colour was changed.",
			quotedFrom = "assets/uploads.json (karenOk), TASKS.md row 106",
			readOn = "2026-10-02",
			attribution = nil,
		},
		added = "2026-10-02",
		moderation = "approved" :: Moderation,
		-- MEASURED by the prep run (glove_left_v4_r1): 6,097 triangles.
		trisDeclared = 6097,
		texturePx = 1024,
		sizeStuds = HAND_LEFT_SIZE,
		naturalSizeStuds = HAND_LEFT_NATURAL,
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.zero,
		renderFidelity = "Automatic",
		textureId = "rbxassetid://116218252655092",
		fallbackColor = Color3.fromRGB(47, 31, 26),
		notes = "The same glove and cuff, palm up in a C: the thumb on one side, four curled fingers "
			.. "on the other and an open gap between them for a forend to sit in. Its longest axis "
			.. "is Z, not X -- the forearm runs at an angle to the fingers, so the bounding box is a "
			.. "diagonal, which is why `uniformTo` pins the LONGEST axis rather than X.",
	},
	-- ------------------------------------------------- the boar (task 115)
	--
	-- KAREN bought RedDeer's "Boar Family" on Fab on 2026-10-03 and gave the upload OK the same day,
	-- verbatim: "1. go 2. upload". The package is Male/Female/Cub with 74 clips each; this is the
	-- MALE, with the ten clips the drive asks for. The female and the cub followed in TASK 119
	-- ("we start with one bord and when this works we do with rest"); their rows are below, and all
	-- three play these same clip ids.
	--
	-- THREE ROWS FOR ONE MODEL, AND THE FIRST TWO ARE THE MEASUREMENT (rule 7: the id stays). The
	-- scale of a skinned mesh has to be baked into the uploaded geometry, because `Size` and
	-- `Model:ScaleTo` move the mesh and not the bones and the model tears as soon as a clip plays.
	-- Which number to bake was not known, and two uploads settled it:
	--   v1 (73934667856496)  the scale in the FBX UNIT HEADER (`FBX_SCALE_ALL`): arrived 1.9185
	--                        studs long -- the model's length in Blender METRES. Roblox ignores the
	--                        header entirely.
	--   v2 (95872773434675)  the scale in the geometry via `FBX_SCALE_NONE` at global_scale 2.8668:
	--                        arrived 550 studs long. Blender's exporter ALSO pushes its own
	--                        metre-to-centimetre hundred into the geometry.
	--   v3 (120607820179994) `FBX_SCALE_NONE` at global_scale 0.028668: arrived (1.4011, 3.2573,
	--                        5.5000) studs, which is the length `Boar.CONFIG.BODY_SIZE.Z` asks for.
	-- `tools/boar_prep.py` now re-opens its own export and FAILS the run on a length that is more
	-- than 0.1 % out, so that cannot cost a third upload.
	--
	-- WHY THE MODEL IS 3.26 STUDS TALL AGAINST A 3-STUD BOX: the LENGTH is what it is fitted by.
	-- Fitting all three axes would squash a real animal onto the grey box's proportions, and a
	-- squashed boar measures perfectly (design 6.1's own words). The shoulder standing a quarter of a
	-- stud above the physics envelope is right for an animal, and a ray cannot see it: the model is
	-- `CanQuery = false` and every hit still lands on the box and its three zone parts.
	{
		key = "boar.male",
		version = 1,
		kind = "model" :: Kind,
		scope = "boar" :: string?,
		modelId = 73934667856496,
		supersededBy = 3,
		displayName = "Boar Male RedDeer",
		fileName = "model.fbx",
		sourceSha256 = "983998c514725cf080a27ad1a0a446fe3d72e8bbf9b3dd9fed447344496e77a0",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = BOAR_LICENCE,
		added = "2026-10-03",
		moderation = "approved" :: Moderation,
		trisDeclared = 13976,
		texturePx = 1024,
		sizeStuds = Vector3.new(0.4887, 1.1362, 1.9185),
		naturalSizeStuds = Vector3.new(0.4887, 1.1362, 1.9185),
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.zero,
		renderFidelity = "Automatic",
		bakedScale = true,
		notes = "THE FIRST SCALE MEASUREMENT. Exported with the scale in the FBX unit header; it "
			.. "arrived at the model's length in metres, so Roblox does not read that header.",
	},
	{
		key = "boar.male",
		version = 2,
		kind = "model" :: Kind,
		scope = "boar" :: string?,
		modelId = 95872773434675,
		supersededBy = 3,
		displayName = "Boar Male RedDeer 5.5",
		fileName = "model.fbx",
		sourceSha256 = "9486b21fa2d06406a4ad0907b81295e79c14a0e0b1a7107c0683eab5114d685e",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = BOAR_LICENCE,
		added = "2026-10-03",
		moderation = "approved" :: Moderation,
		trisDeclared = 13976,
		texturePx = 1024,
		sizeStuds = Vector3.new(140.1105, 325.7303, 550.0),
		naturalSizeStuds = Vector3.new(140.1105, 325.7303, 550.0),
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.zero,
		renderFidelity = "Automatic",
		bakedScale = true,
		notes = "THE SECOND SCALE MEASUREMENT. The scale went into the geometry, and Blender's own "
			.. "metre-to-centimetre hundred went in with it: a boar a hundred times too big.",
	},
	{
		key = "boar.male",
		version = 3,
		kind = "model" :: Kind,
		scope = "boar" :: string?,
		modelId = 120607820179994,
		displayName = "Boar Male RedDeer v3",
		fileName = "model.fbx",
		sourceSha256 = "3f74296cedcc5a21412ee0c2113a970ea47c0848e722d9d0c26e6aa188a02973",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = BOAR_LICENCE,
		added = "2026-10-03",
		moderation = "approved" :: Moderation,
		trisDeclared = 13976,
		texturePx = 1024,
		-- `sizeStuds` RECORDS WHAT THIS MODEL ALREADY MEASURES, it is not a size to write: see
		-- `bakedScale` on the AssetRow type. MEASURED in Studio off the loaded asset, 2026-10-03.
		sizeStuds = BOAR_MALE_SIZE,
		naturalSizeStuds = BOAR_MALE_SIZE,
		-- NO PIVOT CORRECTION AND NO ROTATION, and both were measured rather than hoped for. Off the
		-- loaded asset, with the rig's origin at (0, 0, 0): the nose sits at z -2.78 and the last
		-- tail bone at z +2.01, so the animal faces -Z, which is exactly a Part's own LookVector; a
		-- hind hoof sits at y +0.29 and the mesh's lowest vertex at y -0.002, so the origin is the
		-- GROUND the animal stands on. `Boar.Body` works out the one offset it needs -- feet onto the
		-- bottom of the physics box -- from the template's own measured height, so nothing here has
		-- to be kept in step with `BODY_SIZE`.
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.zero,
		renderFidelity = "Automatic",
		bakedScale = true,
		notes = "RedDeer's male wild boar: 13,976 triangles, 40 bones, one skinned MeshPart with a "
			.. "SurfaceAppearance, 1024 albedo/normal/roughness. Prepped by tools/boar_prep.py and "
			.. "looked at in game before it was called done (.screenshots, task 115).",
	},
	-- ------------------------------------------------- the sow and the cub (task 119)
	--
	-- THE SAME PACKAGE, THE SAME PREP, THE SAME SKELETON. RedDeer's "Boar Family" ships three
	-- animals on one rig (`Arm_Boar`, 46 bones); task 115 took the male and this takes the other
	-- two, through `tools/boar_prep.py` with nothing changed but `--animal` and `--length-studs`.
	-- Karen's upload OK of 2026-10-03 ("2. upload") covers the package's models, textures and
	-- animations, and is recorded verbatim against each id in `assets/uploads.json`.
	--
	-- ONE UPLOAD EACH, NOT THREE: the male cost three because the scale had to be found
	-- (`bakedScale` above). `boar_prep.py` re-opens its own export and fails on a length more than
	-- 0.1 % out, so these two arrived at the length they were asked for the first time.
	{
		key = "boar.female",
		version = 1,
		kind = "model" :: Kind,
		scope = "boar" :: string?,
		modelId = 73776255349661,
		displayName = "Boar Female RedDeer",
		fileName = "model.fbx",
		sourceSha256 = "fc7058a1ef6de3b1d20e46f71a0e7d9922876afd5241c254dd1dc9b84bfafb4c",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = BOAR_LICENCE,
		added = "2026-10-04",
		moderation = "approved" :: Moderation,
		trisDeclared = 13644,
		texturePx = 1024,
		sizeStuds = BOAR_FEMALE_SIZE,
		naturalSizeStuds = BOAR_FEMALE_SIZE,
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.zero,
		renderFidelity = "Automatic",
		bakedScale = true,
		notes = "The sow: 13,644 triangles, 40 Bone instances (Blender counts 46 in the armature; the six the exporter drops carry no skin weight), one skinned MeshPart, 1024 albedo/normal/"
			.. "roughness, baked to 4.675 studs (0.85 of the male).",
	},
	{
		key = "boar.cub",
		version = 1,
		kind = "model" :: Kind,
		scope = "boar" :: string?,
		modelId = 78344628955312,
		displayName = "Boar Cub RedDeer",
		fileName = "model.fbx",
		sourceSha256 = "03afb09204cabd56bbdd543708d838b93c8a29ed229b89595e16d1c9182a9db0",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = BOAR_LICENCE,
		added = "2026-10-04",
		moderation = "approved" :: Moderation,
		trisDeclared = 12234,
		texturePx = 1024,
		sizeStuds = BOAR_CUB_SIZE,
		naturalSizeStuds = BOAR_CUB_SIZE,
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.zero,
		renderFidelity = "Automatic",
		bakedScale = true,
		notes = "The striped cub: 12,234 triangles, 40 Bone instances (Blender counts 46), one skinned MeshPart, 1024 albedo/"
			.. "normal/roughness, baked to 2.475 studs (0.45 of the male).",
	},
	-- ------------------------------- the boar's ten clips (task 115, published 2026-10-03)
	--
	-- WHERE THESE IDS CAME FROM, and it is the one part of this task no tool could do. Open Cloud
	-- takes an `Animation` only as a `.rbxm`/`.rbxmx` "edited inside Roblox Studio", which nothing
	-- outside Studio can write, and `AssetService:CreateAssetAsync` answered "CreateAssetAsync and
	-- CreateAssetVersionAsync are not available yet" for both `Animation` and `Model` when it was
	-- tried here. So the DIRECTOR imported each clip's own FBX -- `tools/boar_prep.py` writes one per
	-- clip for exactly this -- into Studio's Animation Editor and published it by hand. `fileName`
	-- and `sourceSha256` are that file, so each id is tied to the bytes it was made from.
	--
	-- EVERY ID WAS LOADED BACK BEFORE IT WAS WRITTEN DOWN (2026-10-03), through
	-- `AnimationClipProvider:GetAnimationClipAsync` in Edit: all ten resolve, every clip's own name
	-- matches the row, and `clipSeconds` is its last keyframe's `Time`. That read-back is also what
	-- corrected the lengths -- a clip of N frames at 24 fps spans N-1 intervals, so Idle is 4.167 s
	-- and not the 4.208 the frame count suggested, and every clip was one frame out the same way.
	--
	-- THEY ARE ALL PUBLISHED `Loop = true`, deaths and flinches included, because the Animation
	-- Editor's dialog does not ask. `Boar.Body` sets `AnimationTrack.Looped` from its own config
	-- before every `Play`, so a death plays once and holds -- a looping death would stand the carcass
	-- back up every 1.2 s, which is why that is a property write and not a hope about the asset.
	--
	-- THE GEOMETRY FIELDS ARE ZERO BECAUSE AN ANIMATION HAS NO GEOMETRY. `AssetRow` asks every row
	-- for a size, an offset, a rotation and a render fidelity; `NO_GEOMETRY` and `NO_FIDELITY` say
	-- "this row is not a thing you can see" in one word each, rather than leaving four zeros a reader
	-- has to decide about. Nothing reads them: `Assets.INSERTABLE` keeps an animation out of
	-- `keysFor`, so `InsertService` is never asked for one, and the only consumer is `Boar.Body`
	-- putting `modelId` on an `Animation.AnimationId`.
	{
		key = Assets.KEYS.boarIdle,
		version = 1,
		kind = "animation" :: Kind,
		scope = "boar-animation" :: string?,
		modelId = 82265692105692,
		displayName = "Arm_Boar|Idle_1",
		fileName = "Idle_1.fbx",
		sourceSha256 = "5fbe3b9cf5e35aac318704723907b0bbea522737c51ec8c5710ac5ebc0ed3bf6",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = BOAR_LICENCE,
		added = "2026-10-03",
		moderation = "approved" :: Moderation,
		clipSeconds = 4.167,
		trisDeclared = 0,
		sizeStuds = NO_GEOMETRY,
		offsetStuds = NO_GEOMETRY,
		rotationDeg = NO_GEOMETRY,
		renderFidelity = NO_FIDELITY,
		notes = "Standing, breathing, the odd ear flick. What a boar does when nothing is pushing it.",
	},
	{
		key = Assets.KEYS.boarWalk,
		version = 1,
		kind = "animation" :: Kind,
		scope = "boar-animation" :: string?,
		modelId = 78821328262922,
		displayName = "Arm_Boar|Walk_F_IP",
		fileName = "Walk_F_IP.fbx",
		sourceSha256 = "47d4e066c5a34126ebb1bd2b5e599325eeb0c08cda834a8c73ddc5f636d3040c",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = BOAR_LICENCE,
		added = "2026-10-03",
		moderation = "approved" :: Moderation,
		clipSeconds = 1.000,
		trisDeclared = 0,
		sizeStuds = NO_GEOMETRY,
		offsetStuds = NO_GEOMETRY,
		rotationDeg = NO_GEOMETRY,
		renderFidelity = NO_FIDELITY,
		notes = "A grazing walk. Hooves travel 2.852 studs/s at rate 1, so it plays at 1.40 for WANDER_SPEED 4.",
	},
	{
		key = Assets.KEYS.boarTrot,
		version = 1,
		kind = "animation" :: Kind,
		scope = "boar-animation" :: string?,
		modelId = 131287194917750,
		displayName = "Arm_Boar|Trot_F_IP",
		fileName = "Trot_F_IP.fbx",
		sourceSha256 = "eb91fcd4a5279d4e7185e8b807bc8fe4f31ab625c1d0c883a60f4c2e7460a943",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = BOAR_LICENCE,
		added = "2026-10-03",
		moderation = "approved" :: Moderation,
		clipSeconds = 0.667,
		trisDeclared = 0,
		sizeStuds = NO_GEOMETRY,
		offsetStuds = NO_GEOMETRY,
		rotationDeg = NO_GEOMETRY,
		renderFidelity = NO_FIDELITY,
		notes = "A pushed trot. Hooves travel 10.244 studs/s at rate 1, so it plays at 1.76 for TROT_SPEED 18.",
	},
	{
		key = Assets.KEYS.boarRun,
		version = 1,
		kind = "animation" :: Kind,
		scope = "boar-animation" :: string?,
		modelId = 80882224687243,
		displayName = "Arm_Boar|Run_F_IP",
		fileName = "Run_F_IP.fbx",
		sourceSha256 = "539e11602636c46b4391da53a6dd529eca2ca4d360d469e4b9f560e490bd9f28",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = BOAR_LICENCE,
		added = "2026-10-03",
		moderation = "approved" :: Moderation,
		clipSeconds = 0.500,
		trisDeclared = 0,
		sizeStuds = NO_GEOMETRY,
		offsetStuds = NO_GEOMETRY,
		rotationDeg = NO_GEOMETRY,
		renderFidelity = NO_FIDELITY,
		notes = "A bolting gallop. Hooves travel 17.210 studs/s at rate 1, so it plays at 2.21 for SPRINT_SPEED 38.",
	},
	{
		key = Assets.KEYS.boarTurnLeft,
		version = 1,
		kind = "animation" :: Kind,
		scope = "boar-animation" :: string?,
		modelId = 139483442990375,
		displayName = "Arm_Boar|Turn_L_IP",
		fileName = "Turn_L_IP.fbx",
		sourceSha256 = "f083335c685c4fb8422007cee3ae66e94516a83b362d93c1a206544d83a8c67c",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = BOAR_LICENCE,
		added = "2026-10-03",
		moderation = "approved" :: Moderation,
		clipSeconds = 0.667,
		trisDeclared = 0,
		sizeStuds = NO_GEOMETRY,
		offsetStuds = NO_GEOMETRY,
		rotationDeg = NO_GEOMETRY,
		renderFidelity = NO_FIDELITY,
		notes = "A pivot to the animal's left, on the spot. Only reachable below WALK_FROM: it skates at any real speed.",
	},
	{
		key = Assets.KEYS.boarTurnRight,
		version = 1,
		kind = "animation" :: Kind,
		scope = "boar-animation" :: string?,
		modelId = 88781568929523,
		displayName = "Arm_Boar|Turn_R_IP",
		fileName = "Turn_R_IP.fbx",
		sourceSha256 = "d1c80f836f638cbb3189e178e18c3190b8b63d08a129182f4165033034f32e5a",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = BOAR_LICENCE,
		added = "2026-10-03",
		moderation = "approved" :: Moderation,
		clipSeconds = 0.667,
		trisDeclared = 0,
		sizeStuds = NO_GEOMETRY,
		offsetStuds = NO_GEOMETRY,
		rotationDeg = NO_GEOMETRY,
		renderFidelity = NO_FIDELITY,
		notes = "The same pivot to the right.",
	},
	{
		key = Assets.KEYS.boarDeathLeft,
		version = 1,
		kind = "animation" :: Kind,
		scope = "boar-animation" :: string?,
		modelId = 128792697872198,
		displayName = "Arm_Boar|Death_L",
		fileName = "Death_L.fbx",
		sourceSha256 = "683cf0e741a2a8af421333e07192530bf208828999c5ef8c4d3b6cf675eb8307",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = BOAR_LICENCE,
		added = "2026-10-03",
		moderation = "approved" :: Moderation,
		clipSeconds = 1.208,
		trisDeclared = 0,
		sizeStuds = NO_GEOMETRY,
		offsetStuds = NO_GEOMETRY,
		rotationDeg = NO_GEOMETRY,
		renderFidelity = NO_FIDELITY,
		notes = "It goes down on its left side -- the side Body.collapse's positive roll tips the box onto. Played ONCE and frozen on its last frame.",
	},
	{
		key = Assets.KEYS.boarDeathRight,
		version = 1,
		kind = "animation" :: Kind,
		scope = "boar-animation" :: string?,
		modelId = 88751192504828,
		displayName = "Arm_Boar|Death_R",
		fileName = "Death_R.fbx",
		sourceSha256 = "849b04fe370427dc7f35774a2f0cd9a5a43459f2b605fe0178cd2c3a7b43926b",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = BOAR_LICENCE,
		added = "2026-10-03",
		moderation = "approved" :: Moderation,
		clipSeconds = 1.208,
		trisDeclared = 0,
		sizeStuds = NO_GEOMETRY,
		offsetStuds = NO_GEOMETRY,
		rotationDeg = NO_GEOMETRY,
		renderFidelity = NO_FIDELITY,
		notes = "The same fall to the right, for a negative COLLAPSE_ROLL_DEG. Nothing plays it today, and it is published so that flipping the sign needs no second trip through Studio.",
	},
	{
		key = Assets.KEYS.boarHitFront,
		version = 1,
		kind = "animation" :: Kind,
		scope = "boar-animation" :: string?,
		modelId = 91365202020290,
		displayName = "Arm_Boar|Hit_F",
		fileName = "Hit_F.fbx",
		sourceSha256 = "f0cd529511c797b9011f7d7521b79634a6351be27dbb6b79c816898f1f497ddd",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = BOAR_LICENCE,
		added = "2026-10-03",
		moderation = "approved" :: Moderation,
		clipSeconds = 0.833,
		trisDeclared = 0,
		sizeStuds = NO_GEOMETRY,
		offsetStuds = NO_GEOMETRY,
		rotationDeg = NO_GEOMETRY,
		renderFidelity = NO_FIDELITY,
		notes = "A flinch away from a shot that came from in front. Played ONCE, and it is the only hit feedback the animal itself gives now that the red flash is on an invisible box.",
	},
	{
		key = Assets.KEYS.boarHitBack,
		version = 1,
		kind = "animation" :: Kind,
		scope = "boar-animation" :: string?,
		modelId = 80205641767239,
		displayName = "Arm_Boar|Hit_B",
		fileName = "Hit_B.fbx",
		sourceSha256 = "1db51f4a2d94fc4120a18e3040993dbd2a04364d5d618c4247f159e5c095249c",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = BOAR_LICENCE,
		added = "2026-10-03",
		moderation = "approved" :: Moderation,
		clipSeconds = 0.833,
		trisDeclared = 0,
		sizeStuds = NO_GEOMETRY,
		offsetStuds = NO_GEOMETRY,
		rotationDeg = NO_GEOMETRY,
		renderFidelity = NO_FIDELITY,
		notes = "The same flinch for a shot from behind.",
	},
	-- THE THREE THIS PROJECT AUTHORED, published by the Director on 2026-10-03 and each id verified
	-- by loading it back with `AnimationClipProvider:GetAnimationClipAsync` and reading its name.
	--
	-- `source` IS "own", NOT "creator-store", and that distinction is the point: these FBX files are
	-- written by `tools/boar_prep.py`'s `SYNTH_CLIPS`, not shipped by RedDeer. What they are made OF
	-- is the package's own poses, so `BOAR_LICENCE` still governs them -- a blend of two frames of
	-- somebody's animation is still their animation -- and `creator` stays the package's creator id
	-- for the same reason.
	--
	-- `sourceSha256` NAMES THE FILE THAT WAS ACTUALLY PUBLISHED. A later prep run writes byte-different
	-- FBXs (the format carries its own timestamps) but measures identically -- same keys, same ground
	-- speeds, same lowest hoof -- so these ids stand and nothing needs re-publishing.
	--
	-- ALL THREE CAME BACK `clip.Loop = true` as well (the Animation Editor's loop toggle), and for
	-- the two PADDLES that is wrong: a looping death-throe would restart the twitch every four
	-- seconds on a carcass that is supposed to be still. `Boar.Body` writes `AnimationTrack.Looped`
	-- from `Boar.CONFIG.MODEL.CLIPS` immediately before every `Play` for exactly this reason, and
	-- `boar_shot.spec` asserts the two paddles are `looped = false` and the drag `looped = true`.
	{
		key = Assets.KEYS.boarCrippleDrag,
		version = 1,
		kind = "animation" :: Kind,
		scope = "boar-animation" :: string?,
		modelId = 82564145780400,
		displayName = "Arm_Boar|Cripple_Drag",
		fileName = "Cripple_Drag.fbx",
		sourceSha256 = "c5c81549a596b427661098d99514551d1f9dbfb6529c1404577435ee9ffa0318",
		source = "own" :: Source,
		creator = "8167651842",
		licence = BOAR_LICENCE,
		added = "2026-10-03",
		moderation = "approved" :: Moderation,
		-- READ BACK OFF THE PUBLISHED ASSET with `Animator:LoadAnimation` on a live rig, not taken
		-- from the FBX: 25 keys at 24 fps is 24 INTERVALS = 1.0000 s, and the prep tool said 1.042
		-- until this measurement corrected it (the same one-frame error the ten package clips had).
		clipSeconds = 1.0,
		trisDeclared = 0,
		sizeStuds = NO_GEOMETRY,
		offsetStuds = NO_GEOMETRY,
		rotationDeg = NO_GEOMETRY,
		renderFidelity = NO_FIDELITY,
		notes = "Walk_F_IP with the hind legs pulled 85 % toward the death pose. MEASURED per hoof: front 2.866 and 2.863 studs/s (the walk's own 2.853, a real walk cycle), hind 0.826 and 0.931 -- a third of it, dragging. Looped.",
	},
	{
		key = Assets.KEYS.boarDeathPaddleLeft,
		version = 1,
		kind = "animation" :: Kind,
		scope = "boar-animation" :: string?,
		modelId = 131795481631371,
		displayName = "Arm_Boar|Death_Paddle_L",
		fileName = "Death_Paddle_L.fbx",
		sourceSha256 = "4de24da23d6890b05391edc54cb70d525a3b9e32db68e4a54822eb24ea62180c",
		source = "own" :: Source,
		creator = "8167651842",
		licence = BOAR_LICENCE,
		added = "2026-10-03",
		moderation = "approved" :: Moderation,
		clipSeconds = 4.0,
		trisDeclared = 0,
		sizeStuds = NO_GEOMETRY,
		offsetStuds = NO_GEOMETRY,
		rotationDeg = NO_GEOMETRY,
		renderFidelity = NO_FIDELITY,
		notes = "Death_L's last frame with the four legs swinging back toward Run_F_IP, decaying to nothing over 4 s, so it ENDS on the pose it began on and the carcass is held there. Published Loop = true; played with Looped FALSE.",
	},
	{
		key = Assets.KEYS.boarDeathPaddleRight,
		version = 1,
		kind = "animation" :: Kind,
		scope = "boar-animation" :: string?,
		modelId = 126675140902675,
		displayName = "Arm_Boar|Death_Paddle_R",
		fileName = "Death_Paddle_R.fbx",
		sourceSha256 = "fdd16f80aa92725caa441e29ec921d7b39caf615c5a90d2a9407340a9046479f",
		source = "own" :: Source,
		creator = "8167651842",
		licence = BOAR_LICENCE,
		added = "2026-10-03",
		moderation = "approved" :: Moderation,
		clipSeconds = 4.0,
		trisDeclared = 0,
		sizeStuds = NO_GEOMETRY,
		offsetStuds = NO_GEOMETRY,
		rotationDeg = NO_GEOMETRY,
		renderFidelity = NO_FIDELITY,
		notes = "The same, from Death_R, for the other side.",
	},
	-- THE CALM REPERTOIRE (task 117), published by the Director on 2026-10-03 and each id verified by
	-- loading it back with `AnimationClipProvider:GetAnimationClipAsync` and reading its name. These
	-- six are the PACKAGE's own clips, not ones this project authored, so `source` is
	-- "creator-store" like the first ten. Which clip does what was chosen by MEASURING the head and
	-- nose bones over all 74 (`tools/boar_prep.py`, `DEFAULT_CLIPS`), and the measurement is in each
	-- row's note.
	--
	-- ALL SIX CAME BACK `Loop = true`, like the thirteen before them. `Boar.Body.play` writes
	-- `AnimationTrack.Looped` from `Boar.CONFIG.MODEL.CLIPS` immediately before every `Play`, so the
	-- three one-shots play once: `boar_calm.spec` asserts which three.
	{
		key = Assets.KEYS.boarSmell,
		version = 1,
		kind = "animation" :: Kind,
		scope = "boar-animation" :: string?,
		modelId = 73988723402295,
		displayName = "Arm_Boar|Idle_5",
		fileName = "Idle_5.fbx",
		sourceSha256 = "a92599b2022214feca2609f3d2871652551195610f29e84824657a2f493b94bd",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = BOAR_LICENCE,
		added = "2026-10-03",
		moderation = "approved" :: Moderation,
		clipSeconds = 4.167,
		trisDeclared = 0,
		sizeStuds = NO_GEOMETRY,
		offsetStuds = NO_GEOMETRY,
		rotationDeg = NO_GEOMETRY,
		renderFidelity = NO_FIDELITY,
		notes = "The head-up smell: the ONLY clip of the package's 74 whose nose rises above horizontal -- -18.9 to +11.5 deg, a 30.4 deg lift, head +0.112 m, hooves never moving. Played once per `smell` activity, with a sniff.",
	},
	{
		key = Assets.KEYS.boarGrazeLoop,
		version = 1,
		kind = "animation" :: Kind,
		scope = "boar-animation" :: string?,
		modelId = 135066580517343,
		displayName = "Arm_Boar|Eat_loop_1",
		fileName = "Eat_loop_1.fbx",
		sourceSha256 = "3374d57d32cf3a3538f13d3f386108b8d17fc5fc312d43c81fb9f2c380ac1a02",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = BOAR_LICENCE,
		added = "2026-10-03",
		moderation = "approved" :: Moderation,
		clipSeconds = 4.167,
		trisDeclared = 0,
		sizeStuds = NO_GEOMETRY,
		offsetStuds = NO_GEOMETRY,
		rotationDeg = NO_GEOMETRY,
		renderFidelity = NO_FIDELITY,
		notes = "Steady grazing: head at 0.505 m, nose -70..-54 deg. LOOPED, between the start and end transitions.",
	},
	{
		key = Assets.KEYS.boarGrazeChew,
		version = 1,
		kind = "animation" :: Kind,
		scope = "boar-animation" :: string?,
		modelId = 101978328680790,
		displayName = "Arm_Boar|Eat_loop_2",
		fileName = "Eat_loop_2.fbx",
		sourceSha256 = "f12028d37966774111075003fc4713ebf235448194c5288a26ef982aced056c0",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = BOAR_LICENCE,
		added = "2026-10-03",
		moderation = "approved" :: Moderation,
		clipSeconds = 4.167,
		trisDeclared = 0,
		sizeStuds = NO_GEOMETRY,
		offsetStuds = NO_GEOMETRY,
		rotationDeg = NO_GEOMETRY,
		renderFidelity = NO_FIDELITY,
		notes = "The same, pulling and chewing: the head moves 0.098 m against the steady loop's 0.001. Looped.",
	},
	{
		key = Assets.KEYS.boarGrazeStart,
		version = 1,
		kind = "animation" :: Kind,
		scope = "boar-animation" :: string?,
		modelId = 81644449087603,
		displayName = "Arm_Boar|EatDrink_start",
		fileName = "EatDrink_start.fbx",
		sourceSha256 = "7462ae8c7cf0776786a611e702c954dbed7335bbeea77e70bf85ff1e00f3b3e3",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = BOAR_LICENCE,
		added = "2026-10-03",
		moderation = "approved" :: Moderation,
		clipSeconds = 1.083,
		trisDeclared = 0,
		sizeStuds = NO_GEOMETRY,
		offsetStuds = NO_GEOMETRY,
		rotationDeg = NO_GEOMETRY,
		renderFidelity = NO_FIDELITY,
		notes = "Standing height to grazing height, 0.788 -> 0.505 m, so the head does not teleport into the grass. Played ONCE at the head of a graze.",
	},
	{
		key = Assets.KEYS.boarGrazeEnd,
		version = 1,
		kind = "animation" :: Kind,
		scope = "boar-animation" :: string?,
		modelId = 98191739274413,
		displayName = "Arm_Boar|EatDrink_end",
		fileName = "EatDrink_end.fbx",
		sourceSha256 = "05ae84475d149c2e441d7748b96d6e0779a10fb2cbd12d0339136d2fe96fc467",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = BOAR_LICENCE,
		added = "2026-10-03",
		moderation = "approved" :: Moderation,
		clipSeconds = 1.083,
		trisDeclared = 0,
		sizeStuds = NO_GEOMETRY,
		offsetStuds = NO_GEOMETRY,
		rotationDeg = NO_GEOMETRY,
		renderFidelity = NO_FIDELITY,
		notes = "The way back out, played once when the boar stops grazing -- before whatever it does next.",
	},
	{
		key = Assets.KEYS.boarDigWalk,
		version = 1,
		kind = "animation" :: Kind,
		scope = "boar-animation" :: string?,
		modelId = 101611878819703,
		displayName = "Arm_Boar|Dig_walk_IP",
		fileName = "Dig_walk_IP.fbx",
		sourceSha256 = "15900eb1905625fe10d69805df7f85c7c3a01a2afec76b75f605af7ef2fd1d5f",
		source = "creator-store" :: Source,
		creator = "8167651842",
		licence = BOAR_LICENCE,
		added = "2026-10-03",
		moderation = "approved" :: Moderation,
		clipSeconds = 1.5,
		trisDeclared = 0,
		sizeStuds = NO_GEOMETRY,
		offsetStuds = NO_GEOMETRY,
		rotationDeg = NO_GEOMETRY,
		renderFidelity = NO_FIDELITY,
		notes = "Rooting ALONG the ground: head low (nose -72..-59 deg) and the hooves travelling 1.901 studs/s, so it is rated like a gait -- Karen's 'move alon'. Looped.",
	},
	{
		key = Assets.KEYS.oakForest01,
		version = 1,
		kind = "model" :: Kind,
		scope = "map" :: string?,
		modelId = 75865291429319,
		displayName = "Forest_OakTree_Var01_LOD_0",
		fileName = "oak.rbxm",
		sourceSha256 = OAK_SHA,
		source = "bought" :: Source,
		creator = "BuiltByBit: Realistic Oak Tree Pack",
		licence = OAK_LICENCE,
		added = "2026-10-04",
		moderation = "approved" :: Moderation,
		trisDeclared = 6000,
		sizeStuds = OAK_TARGET,
		naturalSizeStuds = Vector3.new(31.62, 81.38, 32.73),
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.new(0, 0, 0),
		renderFidelity = "Automatic",
		notes = "Upright as published, 81.4 studs tall and narrow: the `mature` tier, at a scale of about 0.96.",
	},
	{
		key = Assets.KEYS.oakForest02,
		version = 1,
		kind = "model" :: Kind,
		scope = "map" :: string?,
		modelId = 83388490001103,
		displayName = "Forest_OakTree_Var02_LOD_0",
		fileName = "oak.rbxm",
		sourceSha256 = OAK_SHA,
		source = "bought" :: Source,
		creator = "BuiltByBit: Realistic Oak Tree Pack",
		licence = OAK_LICENCE,
		added = "2026-10-04",
		moderation = "approved" :: Moderation,
		trisDeclared = 6000,
		sizeStuds = OAK_TARGET,
		naturalSizeStuds = Vector3.new(32.80, 82.14, 35.50),
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.new(90, 0, 0),
		renderFidelity = "Automatic",
		notes = "PUBLISHED LYING DOWN -- MEASURED 2026-10-04: its bounding box is 82.14 studs along Z and 35.50 along Y. `rotationDeg` stands it up and `naturalSizeStuds` records the UPRIGHT box; the Loader's aspect check sorts the axes, so it passes either way.",
	},
	{
		key = Assets.KEYS.oakForest03,
		version = 1,
		kind = "model" :: Kind,
		scope = "map" :: string?,
		modelId = 107347779714858,
		displayName = "Forest_OakTree_Var03_LOD_0",
		fileName = "oak.rbxm",
		sourceSha256 = OAK_SHA,
		source = "bought" :: Source,
		creator = "BuiltByBit: Realistic Oak Tree Pack",
		licence = OAK_LICENCE,
		added = "2026-10-04",
		moderation = "approved" :: Moderation,
		trisDeclared = 6000,
		sizeStuds = OAK_TARGET,
		naturalSizeStuds = Vector3.new(23.57, 78.34, 24.58),
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.new(90, 0, 0),
		renderFidelity = "Automatic",
		notes = "PUBLISHED LYING DOWN, like Var02: 78.34 studs along Z. The same correction.",
	},
	{
		key = Assets.KEYS.oakField04,
		version = 1,
		kind = "model" :: Kind,
		scope = "map" :: string?,
		modelId = 85037810334946,
		displayName = "Field_OakTree_Var04_LOD_0",
		fileName = "oak.rbxm",
		sourceSha256 = OAK_SHA,
		source = "bought" :: Source,
		creator = "BuiltByBit: Realistic Oak Tree Pack",
		licence = OAK_LICENCE,
		added = "2026-10-04",
		moderation = "approved" :: Moderation,
		trisDeclared = 6000,
		sizeStuds = OAK_TARGET,
		naturalSizeStuds = Vector3.new(29.92, 51.57, 34.05),
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.new(0, 0, 0),
		renderFidelity = "Automatic",
		notes = "Broad and short: the `backdrop` tier, on the rim where no player walks and the mesh is drawn at RenderFidelity Performance.",
	},
	{
		key = Assets.KEYS.oakField05,
		version = 1,
		kind = "model" :: Kind,
		scope = "map" :: string?,
		modelId = 108955269036117,
		displayName = "Field_OakTree_Var05_LOD_0",
		fileName = "oak.rbxm",
		sourceSha256 = OAK_SHA,
		source = "bought" :: Source,
		creator = "BuiltByBit: Realistic Oak Tree Pack",
		licence = OAK_LICENCE,
		added = "2026-10-04",
		moderation = "approved" :: Moderation,
		trisDeclared = 6000,
		sizeStuds = OAK_TARGET,
		naturalSizeStuds = Vector3.new(41.18, 68.49, 38.31),
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.new(0, 0, 0),
		renderFidelity = "Automatic",
		notes = "The broadest of the seven: the `veteran` tier, because a veteran oak IS broad-crowned.",
	},
	{
		key = Assets.KEYS.oakField06,
		version = 1,
		kind = "model" :: Kind,
		scope = "map" :: string?,
		modelId = 88655731342330,
		displayName = "Field_OakTree_Var06_LOD_0",
		fileName = "oak.rbxm",
		sourceSha256 = OAK_SHA,
		source = "bought" :: Source,
		creator = "BuiltByBit: Realistic Oak Tree Pack",
		licence = OAK_LICENCE,
		added = "2026-10-04",
		moderation = "approved" :: Moderation,
		trisDeclared = 6000,
		sizeStuds = OAK_TARGET,
		naturalSizeStuds = Vector3.new(33.05, 58.60, 31.66),
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.new(0, 0, 0),
		renderFidelity = "Automatic",
		notes = "The second `veteran`.",
	},
	{
		key = Assets.KEYS.oakField07,
		version = 1,
		kind = "model" :: Kind,
		scope = "map" :: string?,
		modelId = 94298911590260,
		displayName = "Field_OakTree_Var07_LOD_0",
		fileName = "oak.rbxm",
		sourceSha256 = OAK_SHA,
		source = "bought" :: Source,
		creator = "BuiltByBit: Realistic Oak Tree Pack",
		licence = OAK_LICENCE,
		added = "2026-10-04",
		moderation = "approved" :: Moderation,
		trisDeclared = 6000,
		sizeStuds = OAK_TARGET,
		naturalSizeStuds = Vector3.new(29.34, 52.73, 33.13),
		offsetStuds = Vector3.zero,
		rotationDeg = Vector3.new(0, 0, 0),
		renderFidelity = "Automatic",
		notes = "The second `backdrop`.",
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
		if (row.scope or "runtime") == scope and Assets.INSERTABLE[row.kind] and row.supersededBy == nil then
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
