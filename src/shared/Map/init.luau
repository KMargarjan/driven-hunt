--!strict
-- Map: THE MAP CONTRACT. Frozen data, no behaviour, and NO RUNTIME WRITER AT ALL (CLAUDE.md rule 3).
-- The Builder edits this file and git records it; nothing in the game assigns to it.
--
-- It is the one home for three facts that would otherwise exist in several places:
--   * WHICH WORLD IS THE WORLD (EXPECTED_WORLD). One string, in a diff, read today by
--     tests/server/map_contract.spec.luau, and by ArenaBoot from M2.5, when the switch gives the
--     arena an early return (design section 9.2). It cannot be half-on, and it is never answered by
--     looking for a folder in Workspace -- a predicate like that lies the moment a run half-finishes.
--   * THE TAG STRINGS. Before this, "DrivenHunt.ShooterPost" lived in TestArena, Match.Markers and
--     (soon) MapGen.Markers: three copies of one fact, where a typo yields a silent empty GetTagged.
--   * THE DRIVE RECTANGLE, which must equal Boar.CONFIG.field. The spec asserts they are equal.
--
-- Shared rather than server-only for the reason src/shared/Shotgun/ is: one file, one require path,
-- and the Hud may want the map's name later. It replicates a handful of numbers and no secret.
--
--   CollectionService https://create.roblox.com/docs/reference/engine/classes/CollectionService
--   Instance streaming https://create.roblox.com/docs/workspace/streaming
--
-- Design: docs/design/map-generator.md (section 4)
-- Note:   docs/research/2026-09-24-map-generator.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Map = {}

export type FieldRect = {
	bounds: { minX: number, maxX: number, minZ: number, maxZ: number },
	exitZ: number,
	groundY: number,
}

Map.VERSION = "v1"

-- THE GENERATOR'S OWN VERSION, and its ONE home (M2.8a). MapGen.VERSION reads this instead of
-- carrying a second copy, which closes TASKS.md row 44a(f): two strings for one fact is how a
-- digest and a build end up disagreeing about which generator made the map.
Map.GENERATOR = "m2.8-road-autumn"

-- THE SWITCH (design section 9). "arena" or "map:v1". Milestone 2.1 builds the 512-stud slice as an
-- EDIT-TIME artefact and does not make it the world: the grey box is still what a player stands in,
-- still the rollback, and still what every existing spec is written against. M2.5 flips this, sets
-- SEED and DIGEST, and changes FIELD and Boar.CONFIG.field together.
Map.EXPECTED_WORLD = "arena"
Map.SEED = 0 -- the seed the committed map was built from; 0 while "arena"
Map.DIGEST = "" -- the digest that seed produced; "" while "arena"

-- THE DRIVE RECTANGLE. While EXPECTED_WORLD is "arena" these are the ARENA's numbers, because
-- map_contract.spec asserts Boar.CONFIG.field deep-equals this and the boar is still hunting in the
-- grey box. At the switch both change together, to the design's section 12 corridor.
Map.FIELD = {
	bounds = { minX = -200, maxX = 200, minZ = -200, maxZ = 200 },
	exitZ = -190,
	groundY = 0,
} :: FieldRect

Map.SIZE_STUDS = 2048 -- the whole map; the generator's own copy is MapGen.CONFIG.SIZE_STUDS

-- THE ONE HOME FOR THE TAG STRINGS (design section 4.2).
Map.TAGS = {
	shooterPost = "DrivenHunt.ShooterPost",
	driveLine = "DrivenHunt.DriveLine",
	driverStart = "DrivenHunt.DriverStart",
	boarSpawn = "DrivenHunt.BoarSpawn",
	tree = "DrivenHunt.Tree",
}

-- The counts of the world EXPECTED_WORLD NAMES, so the spec can assert them without a branch of its
-- own. The arena tags its four corner pillars as tie trees; the generated map tags twelve near the
-- line (design section 4.3), and this table changes with the switch.
Map.EXPECTED_COUNTS = { shooterPost = 8, driveLine = 1, driverStart = 1, boarSpawn = 4, tree = 4 }

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
-- The four numbers below are therefore the VALUES M2.6 MUST SET BY HAND, kept here so the intention
-- lives in a diff and the spec can assert them the day the engine exposes them.
Map.STREAMING = {
	enabled = true,
	minRadius = 64,
	targetRadius = 1024,
	integrityMode = "PauseOutsideLoadedArea",
	modelBehavior = "Improved",
	scriptable = { "StreamingEnabled" },
}

-- CHANGED at M2.8a: two new ceilings, because the wood now grows INSIDE the drive corridor and a
-- runaway scatter is the one way this map could stop being playable.
Map.BUDGET = { parts = 20000, visibleParts = 8000, trees = 3000, brush = 600, hedgeParts = 400 }

-- THE FOREST ROAD (design section 6.3). Karen's decision: the shooter line runs along a ride through
-- the woods, not along a field edge. The road's centreline IS the drive line -- there is no second
-- concept -- and it is a flat bench at exactly `groundY`, so every post's bottom face is at ground.
Map.ROAD = { z = -700, halfWidth = 8, verge = 24, from = -900, to = 900 }

-- The drivers' assembly track: they form up on it at the wood edge and walk in. It also flattens the
-- 1,120-stud DriverStart strip, which spans too far to be a disc pad.
Map.ASSEMBLY = { z = 700, halfWidth = 5, verge = 20, from = -700, to = 700 }

-- AUTUMN (design section 8). Roblox terrain has no leaf-litter material, so the lever is per-material
-- colour -- one global table for the whole place. These four are the materials MapGen.Config.MATERIAL
-- already uses.
Map.PALETTE = {
	litter = Color3.fromRGB(150, 108, 62), -- LeafyGrass: the forest floor, the wood's default
	rough = Color3.fromRGB(126, 122, 78), -- Grass: steep ground, clearings, the flank fields
	road = Color3.fromRGB(152, 146, 132), -- Ground: the road bench, the assembly bench, the track
	bog = Color3.fromRGB(96, 82, 62), -- Mud: the bog
}

-- MEASURED, NOT GUESSED (design section 8.4, measurement N1; 2026-09-26, Studio 0.740.x, DEV place
-- with 0 terrain cells and no prior recolour). This is what MapGen.clear restores, and what
-- map_contract.spec asserts in the arena branch -- so an autumn palette left behind after a `clear`
-- is caught rather than becoming "a world nobody chose" (audit-004 must-fix 1).
--
-- The same measurement also settled the three things the design could not verify: SetMaterialColor
-- and GetMaterialColor ARE callable through execute_luau in Edit; the colours SURVIVE Terrain:Clear()
-- (which is exactly why `clear` has to restore them); and they DO replicate to a client, so
-- map_client.spec's colour check stands rather than being dropped. The section 8.3 material-choice
-- fallback is therefore NOT taken, and no code for it exists.
Map.PALETTE_DEFAULT = {
	litter = Color3.fromRGB(106, 134, 64),
	rough = Color3.fromRGB(111, 126, 62),
	road = Color3.fromRGB(140, 130, 104),
	bog = Color3.fromRGB(121, 112, 98),
}

-- Where a spawn pad is flattened, so a boar is never released inside a hill (design section 7.3).
--
-- MEASURED 2026-09-26 (Task 45), and it changed `blend` from the design's 24 to 40: writing the
-- corridor-slope spec that `CORRIDOR_MAX_SLOPE_DEG` had promised since M2.2 showed the drive corridor
-- reaching **22.5 degrees**, against the design's 15. The cause is not the noise -- it is this easing.
-- A pad is flat at GROUND_Y and the terrain around it is up to CORRIDOR_RELIEF studs away, so the
-- shorter the blend, the steeper the ring around every shooter post and every boar spawn. Over three
-- seeds, sampling the corridor on a 20-stud lattice:
--
--     relief 16, blend 24 -> 22.53 deg      relief 16, blend 40 -> 12.94 deg
--     relief 12, blend 24 -> 17.28 deg      relief 12, blend 40 -> 10.70 deg
--
-- 40 with the relief unchanged, because the relief is Karen's taste value for how rolling the corridor
-- is and the blend is not. The deviation from design section 7.3 is queued for the Architect.
-- RADIUS 14 -> 30 at M2.8a: a sounder of up to five boars spawns inside one pad, so the flat disc has
-- to hold the group. The nearest two pads are 300 studs apart, so pads never overlap and
-- Height.atFlattened's nearest-pad rule never has to arbitrate.
Map.SPAWN_PAD = { radius = 30, blend = 40, tolerance = 0.75 }

Shotgun.deepFreeze(Map)

return Map
