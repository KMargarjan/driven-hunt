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

Map.SIZE_STUDS = 2048 -- the whole map when it exists; the M2.1 slice is MapGen.CONFIG.SLICE_STUDS

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

Map.BUDGET = { parts = 20000, visibleParts = 8000, trees = 3000 }

-- Where a spawn pad is flattened, so a boar is never released inside a hill (design section 7.3).
Map.SPAWN_PAD = { radius = 14, blend = 24, tolerance = 0.75 }

Shotgun.deepFreeze(Map)

return Map
