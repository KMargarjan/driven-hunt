--!strict
-- Map: THE MAP CONTRACT. Frozen data, no behaviour, and NO RUNTIME WRITER AT ALL (CLAUDE.md rule 3).
-- The Builder edits this file and git records it; nothing in the game assigns to it.
--
-- It is the one home for four facts that would otherwise exist in several places:
--   * WHICH WORLD IS THE WORLD (EXPECTED_WORLD). One string, in a diff, read by
--     tests/server/map_contract.spec.luau, by ArenaBoot (which declines to build the grey box when
--     the world is not the arena) and by MatchBoot. It cannot be half-on, and it is never answered
--     by looking for a folder in Workspace -- a predicate like that lies the moment a run
--     half-finishes.
--   * WHICH BLOCK THE DRIVE RUNS IN (ACTIVE_BLOCK). The forest has four drive blocks and the drive
--     reads the world through tags, so exactly one block is tagged -- see the comment on the field.
--   * THE TAG STRINGS. Before this, "DrivenHunt.ShooterPost" lived in TestArena, Match.Markers and
--     MapGen.Markers: three copies of one fact, where a typo yields a silent empty GetTagged.
--   * THE DRIVE RECTANGLE, which must equal Boar.CONFIG.field. The spec asserts they are equal.
--
-- Shared rather than server-only for the reason src/shared/Shotgun/ is: one file, one require path,
-- and the Hud may want the map's name later. It replicates a handful of numbers and no secret; it
-- carries NO ASSET ID -- keys only, which ServerStorage.Assets resolves.
--
--   CollectionService https://create.roblox.com/docs/reference/engine/classes/CollectionService
--   Instance streaming https://create.roblox.com/docs/workspace/streaming
--
-- Design: docs/design/map-generator.md, "The map contract -- `ReplicatedStorage.Map`"
-- Note:   docs/research/2026-10-04-forest-block1.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Map = {}

export type FieldRect = {
	bounds: { minX: number, maxX: number, minZ: number, maxZ: number },
	exitZ: number,
	groundY: number,
}

-- A FOREST ROAD, as geometry. `axis = "x"` runs ALONG x at a constant z.
--
-- `verge` and `keepClear` ARE TWO DIFFERENT NUMBERS AND THAT IS THE POINT OF A FOREST RIDE (design,
-- "`keepClear` is not `verge`"). `verge` is how far the TERRAIN easing reaches, and it is forced by
-- the slope ceiling. `keepClear` is how far from the gravel NOTHING COLLIDABLE may stand. v3 kept
-- trees off the gravel plus the whole verge, which cleared 62 studs (17 m) down every ride -- a
-- firebreak, not a forest road. A ride is now 14 + 2 x 4 = 22 studs (6.2 m) of cleared corridor,
-- inside the brief's 4.5-7 m, with trunks standing on the eased verge and crowns overhanging it.
export type Road = {
	axis: string, -- "x" runs ALONG x at a constant z; "z" runs along z at a constant x
	at: number,
	halfWidth: number, -- the gravel
	verge: number, -- how far the TERRAIN easing reaches
	keepClear: number, -- how far NOTHING COLLIDABLE may stand
	from: number,
	to: number,
}

-- A DRIVE BLOCK: one rectangle of wood, bounded by roads. A drive is one block -- the drivers push
-- through it toward -Z, the shooters stand on the road along its -Z edge, and the boars cross that
-- road into the block beyond.
export type Block = {
	bounds: { minX: number, maxX: number, minZ: number, maxZ: number },
	road: string, -- the Map.ROADS key its shooter line stands on (its -Z edge)
	exitPastRoad: number, -- studs past that road's centreline at which the boar is gone
}

Map.VERSION = "v1"

-- THE GENERATOR'S OWN VERSION, and its ONE home (M2.8a). MapGen.VERSION reads this instead of
-- carrying a second copy, which closes TASKS.md row 44a(f): two strings for one fact is how a
-- digest and a build end up disagreeing about which generator made the map.
Map.GENERATOR = "v4-forest-block1"

-- THE SWITCH (design, "The switch, and the rollback"). "arena", "map:v1" or "map:v2": ONE COMMITTED
-- STRING, in a diff, read by `tests/server/map_contract.spec.luau`, by `ArenaBoot` -- which returns
-- early when this is not "arena", so the grey box is not built -- and by `MatchBoot`.
--
-- IT IS NOT A FEATURE FLAG, AND TASK 79 MEASURED WHY (Director decision, 2026-09-27, recorded in
-- `ESCALATE.md` and in CLAUDE.md's "Feature flags" section). A flag lives in code; THE WORLD LIVES
-- IN THE PLACE. Built behind a flag, the map sat in Workspace with the flag off and the same commit
-- went from 32/32 checks to 22/27 with eleven specs failing -- including
-- `GetTagged("DrivenHunt.ShooterPost")` answering 16, because both worlds tag with the same
-- strings, which would have put shooters on map posts 700 studs away. A switch that cannot be
-- switched off is not a switch. So this flips by COMMIT.
--
-- IT STAYS "map:v1" THROUGH THE FOREST BUILD, and the forest is still what a player stands in,
-- because "map:v1" ALREADY NAMED THE GENERATED MAP before this revision: the string's job is to say
-- "the generated map, not the arena", and that answer has not changed. What DID change is the
-- generator and every number below it, so the facts a live check reads -- FIELD, SIZE_STUDS, ROADS,
-- BLOCKS, STAND -- move in the same commit that rebuilds the place, which is the rule the design's
-- build order states. "map:v2" is the label the switch task applies once Karen has walked block 1
-- and the place has been saved and reopened (design, "The switch, and the rollback").
Map.EXPECTED_WORLD = "map:v1"
Map.SEED = 1 -- the seed the committed map was built from
-- The digest that seed produced, filled from the build that made the place this commit describes:
-- `mapgen.py build --seed 1` prints it and `mapgen.py digest` reads it back out of Studio.
Map.DIGEST = ""

-- WHICH BLOCK THE DRIVE RUNS IN, AND WHY IT IS A SECOND COMMITTED STRING RATHER THAN A FLAG.
--
-- The drive reads the world through tags. `src/server/Match/Markers.luau`, `Markers.read`, calls
-- `GetTagged` for each of the five strings, requires EXACTLY ONE drive line, and publishes
-- `complete = false` with the missing names otherwise; `Match` then keeps the match in `Waiting`.
-- Tagging four blocks' posts would give 32 posts and 4 lines, which is not "four drives available"
-- -- it is one broken drive. So exactly one block is tagged, and which one is committed, for the
-- same measured reason the map switch is: the tags live in the PLACE, and a flag that lives in code
-- cannot make 8 posts absent.
--
-- Changing the drive to block 2 is therefore: flip this, flip `Map.FIELD` and `Boar.CONFIG.field`
-- together, rebuild, save, commit. PER-MATCH BLOCK ROTATION IS OUT OF SCOPE and is a change to
-- `Match.Markers` (it would have to read *a* block rather than *the* tags), not to this system.
Map.ACTIVE_BLOCK = "block1"

-- THE DRIVE RECTANGLE: the ACTIVE BLOCK's rectangle plus its exit, and `Boar.CONFIG.field` must
-- deep-equal it -- map_contract.spec asserts that, and the two move together in one commit.
--
-- `minZ` reaches 194 studs PAST the shooter road (z = -140) and 60 studs past `exitZ`, because the
-- rectangle has to CONTAIN the exit: `Brain:_outcome` despawns a fleeing boar at
-- `position.Z <= field.exitZ`, so a boar must be able to stand at `exitZ` while still inside the
-- bounds the brain clamps it to.
Map.FIELD = {
	bounds = { minX = -1440, maxX = -14, minZ = -320, maxZ = 1286 },
	exitZ = -260,
	groundY = 0,
} :: FieldRect

-- 860 m at 1 stud = 0.28 m, 74 ha: four blocks of 12-16 ha plus the roads and the rim. CHANGED from
-- 2048, because four blocks and a 1,120-stud shooter line do not fit in 2,048 studs.
Map.SIZE_STUDS = 3072

-- THE FOUR FOREST ROADS, and the one home for their geometry. The main road is the widest because
-- it is the one two blocks' drives stand on (the brief's "main 5-5.5 m"); the two rides are the
-- brief's 3.5-4.5 m; the assembly track is narrowest because nobody shoots from it.
--
-- THE ROADS ARE LEVEL, NOT CONTOUR-FOLLOWING. Named as a simplification, with v3's reason: a
-- longitudinal profile means every stand, and the contract's `tolerance` check, stops being a
-- comparison against one number.
Map.ROADS = {
	-- 20 studs of gravel = 5.60 m; cleared corridor 28 studs = 7.8 m.
	main = { axis = "x", at = -140, halfWidth = 10, verge = 26, keepClear = 4, from = -1440, to = 1440 } :: Road,
	-- 14 studs = 3.92 m; cleared corridor 22 studs = 6.2 m.
	ride = { axis = "z", at = 0, halfWidth = 7, verge = 24, keepClear = 4, from = -1260, to = 1300 } :: Road,
	south = { axis = "x", at = -1260, halfWidth = 7, verge = 24, keepClear = 4, from = -1440, to = 1440 } :: Road,
	-- The drivers form up on it and walk in. It also flattens the 1,120-stud DriverStart strip,
	-- which spans too far to be a disc pad.
	assembly = { axis = "x", at = 1300, halfWidth = 5, verge = 20, keepClear = 4, from = -1440, to = 1440 } :: Road,
}

-- THE FOUR DRIVE BLOCKS, 2x2, so each block borders two roads and each drive looks a different way.
-- Every block's edge stops at `halfWidth + keepClear` from each bordering road's centreline, so a
-- block and a road never overlap and a spec asserts it.
--
-- EVERY DRIVE PUSHES TOWARD -Z, AND THAT IS NOT A STYLE CHOICE. `src/server/Boar/Brain.luau`,
-- `Brain:_outcome`, despawns a fleeing boar at `position.Z <= field.exitZ`, and `Brain._fleeTarget`
-- returns `Vector3.new(targetX, field.groundY, field.exitZ)`: the escape axis is BAKED INTO THE
-- BOAR. So each block's shooter road is on its -Z edge. Making the drive axis a parameter is a BOAR
-- task, not a map task.
Map.BLOCKS = {
	block1 = {
		bounds = { minX = -1440, maxX = -14, minZ = -126, maxZ = 1286 },
		road = "main",
		exitPastRoad = 120,
	} :: Block,
	block2 = {
		bounds = { minX = 14, maxX = 1440, minZ = -126, maxZ = 1286 },
		road = "main",
		exitPastRoad = 120,
	} :: Block,
	block3 = {
		bounds = { minX = -1440, maxX = -14, minZ = -1246, maxZ = -154 },
		road = "south",
		exitPastRoad = 120,
	} :: Block,
	block4 = {
		bounds = { minX = 14, maxX = 1440, minZ = -1246, maxZ = -154 },
		road = "south",
		exitPastRoad = 120,
	} :: Block,
}

-- THE STAND a shooter stands on: our own timber Drueckjagdbock, because research found no model of
-- one anywhere (design, "The stand (ours, because none exists)"). `floorStuds` is the ONE number
-- that makes the live contract check work in both worlds: the post marker's bottom face sits at
-- `ground + floorStuds`, which was 0 while the shooters stood on the road and is 7.1 now that they
-- stand on boards. ONLY THE FLOOR COLLIDES -- a collidable rail traps a player on a 7-stud platform
-- and a queryable one eats the shot he leans over it to take.
Map.STAND = {
	floorStuds = 7.1, -- the floor's TOP face, 2.0 m: the brief's 1.8-2 m driven-hunt stand
	offsetZ = -20, -- studs behind the road centreline: 10 clear of the gravel, 6 past keepClear
	railTopStuds = 3.6, -- above the floor
	footprintStuds = 7,
	clearRadius = 12, -- no tree inside this of a stand's centre
}

-- THE ONE HOME FOR THE TAG STRINGS.
Map.TAGS = {
	shooterPost = "DrivenHunt.ShooterPost",
	driveLine = "DrivenHunt.DriveLine",
	driverStart = "DrivenHunt.DriverStart",
	boarSpawn = "DrivenHunt.BoarSpawn",
	tree = "DrivenHunt.Tree",
}

-- The counts of the world EXPECTED_WORLD NAMES, so the spec can assert them without a branch of its
-- own. THE ACTIVE BLOCK'S MARKERS, AND NOTHING ELSE IS TAGGED: a second block's posts in this count
-- would be a broken drive, not a spare one.
Map.EXPECTED_COUNTS = { shooterPost = 8, driveLine = 1, driverStart = 1, boarSpawn = 4, tree = 12 }

-- MEASURED 2026-09-26 in Studio 0.740.19 (Task 43), and it contradicts the design's assumption that
-- streaming is off until M2.6:
--   * `Workspace.StreamingEnabled` is ALREADY true in the DEV place -- it is the engine's default for
--     a new place, so every system in Milestone 1 has always run with streaming on. The contract says
--     so rather than turning it off, because flipping it would change client behaviour for every
--     existing system, and that is M2.6's task with a playtest, not this one's.
--   * THE OTHER FOUR PROPERTIES ARE NOT REACHABLE FROM LUAU: reading Workspace.StreamingMinRadius,
--     StreamingTargetRadius, StreamingIntegrityMode, StreamOutBehavior or ModelStreamingBehavior
--     raises "not a valid member of Workspace". They are Studio-panel place settings, so M2.6 is a
--     Karen click plus a playtest, not a line of code. `MapGen.Settings` writes the one it can and
--     reports the rest as unreachable rather than pretending.
Map.STREAMING = {
	enabled = true,
	minRadius = 64,
	targetRadius = 1024,
	integrityMode = "PauseOutsideLoadedArea",
	modelBehavior = "Improved",
	scriptable = { "StreamingEnabled" },
}

-- THE CEILINGS, AND EVERY ONE OF THEM FAILS A BUILD RATHER THAN APPEARING IN A DOCUMENT. A build
-- that quietly overruns is how a place gets slow with no diff to blame.
--
-- `visibleTris` is the one new KIND of ceiling: `Layout.visibleLoad` sums the declared triangles of
-- every tree planted within `STREAMING.targetRadius` of a point, which is PURE -- no world, no
-- Studio -- so a server spec asserts it at all eight stands and the driver start. It is an upper
-- bound on BAKED geometry, not on what is drawn (`RenderFidelity = Automatic` reduces distant
-- meshes and identical meshes instance); what it does is turn "hundreds of trees, LOD, streaming"
-- into a number a machine can refuse.
Map.BUDGET = {
	parts = 20000,
	visibleParts = 8000,
	trees = 1800,
	brush = 700,
	ferns = 700,
	deadwood = 120,
	hedgeParts = 400,
	furniture = 250,
	visibleTris = 7000000,
}

-- AUTUMN. Roblox terrain has no leaf-litter material, so the first lever is per-material colour --
-- one global table for the whole place -- and the second is a MaterialVariant carrying a CC0 photo
-- texture (Map.TERRAIN below). The palette is the one that is MEASURED and already shipped, so it
-- is what the forest falls back to if the variants cannot be reached.
--
-- `bog` is now `wet`: wet ground is DERIVED from the heightfield (a hollow is wet because it is
-- low) rather than being a 120-stud Mud disc at a hand-named position, which read as a grey mud
-- flat (TASKS.md row 44a(c)).
Map.PALETTE = {
	litter = Color3.fromRGB(150, 108, 62), -- LeafyGrass: the forest floor, the wood's default
	rough = Color3.fromRGB(126, 122, 78), -- Grass: steep ground, the gap, the grass rides
	road = Color3.fromRGB(152, 146, 132), -- Ground: the roads and the assembly track
	wet = Color3.fromRGB(96, 82, 62), -- Mud: the wet hollows
}

-- MEASURED, NOT GUESSED (measurement N1; 2026-09-26, Studio 0.740.x, DEV place with 0 terrain cells
-- and no prior recolour). This is what MapGen.clear restores, and what map_contract.spec asserts in
-- the arena branch -- so an autumn palette left behind after a `clear` is caught rather than
-- becoming "a world nobody chose" (audit-004 must-fix 1).
--
-- The same measurement also settled the three things the design could not verify: SetMaterialColor
-- and GetMaterialColor ARE callable through execute_luau in Edit; the colours SURVIVE Terrain:Clear()
-- (which is exactly why `clear` has to restore them); and they DO replicate to a client.
Map.PALETTE_DEFAULT = {
	litter = Color3.fromRGB(106, 134, 64),
	rough = Color3.fromRGB(111, 126, 62),
	road = Color3.fromRGB(140, 130, 104),
	wet = Color3.fromRGB(121, 112, 98),
}

-- THE CC0 GROUND TEXTURES, BY KEY AND NEVER BY ID. A terrain `MaterialVariant` puts a photo texture
-- on a base material; the ids live in `ServerStorage.Assets` as `kind = "image"` rows, which is a
-- kind `Assets.INSERTABLE` deliberately excludes from the Loader because an image is an id a
-- property carries and not an Instance to insert.
--
-- The `materials` step behaves like `Settings.apply`: it writes what it can and REPORTS what it
-- could not reach, and it never fails the build. If a terrain-bound MaterialVariant cannot be made
-- from `execute_luau` in Edit, the forest ships on the measured palette above and the step says so
-- -- which is why block 1 is lookable at before a single texture is uploaded.
Map.TERRAIN = {
	variants = {
		litter = { baseMaterial = "LeafyGrass", studsPerTile = 8, key = "ground.litter" },
		rough = { baseMaterial = "Grass", studsPerTile = 8, key = "ground.grassride" },
		road = { baseMaterial = "Ground", studsPerTile = 6, key = "ground.gravel" },
		wet = { baseMaterial = "Mud", studsPerTile = 6, key = "ground.mud" },
	},
}

-- Where a spawn pad is flattened, so a boar is never released inside a hill.
--
-- MEASURED 2026-09-26 (Task 45), and it changed `blend` from the design's 24 to 40: writing the
-- corridor-slope spec that `CORRIDOR_MAX_SLOPE_DEG` had promised since M2.2 showed the drive
-- reaching 22.5 degrees, against the design's 15. The cause is not the noise -- it is this easing.
-- A pad is flat at GROUND_Y and the terrain around it is up to the block's relief away, so the
-- shorter the blend, the steeper the ring around every boar spawn. RADIUS 14 -> 30 at M2.8a: a
-- sounder of up to five boars spawns inside one pad, so the flat disc has to hold the group.
Map.SPAWN_PAD = { radius = 30, blend = 40, tolerance = 0.75 }

Shotgun.deepFreeze(Map)

return Map
