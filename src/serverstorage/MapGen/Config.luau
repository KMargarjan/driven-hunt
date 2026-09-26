--!strict
-- MapGen.Config: PURE DATA. Every number the generator has, frozen, and nothing else. K marks
-- Karen's taste values -- numbers she changes after walking the map, not measurements.
--
-- MILESTONE 2.1 BUILDS A 512-STUD SLICE, not the 2048 map: the design's smallest first task
-- (section 14). The slice's own layout numbers are here beside the map's, each labelled, because the
-- slice is a scale model of the same shape -- a drive corridor, a shooter line along one edge, a
-- driver start at the other -- and the code that lays it out is the code the full map will use.
--
-- deepFreeze is REQUIRED FROM SHOTGUN rather than copied: table.freeze is shallow and this repo has
-- paid for that once (TASKS.md row 23a(b)).
--
-- Design: docs/design/map-generator.md (section 12)
-- Note:   docs/research/2026-09-24-map-generator.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

-- Through Contract, not by requiring Map directly: at edit time Studio's require cache would otherwise
-- hand back a contract older than the file (Contract.luau says what was measured).
local Map = require(script.Parent:WaitForChild("Contract"))

local Config = {}

-- ---------------------------------------------------------------- the world

Config.SLICE_STUDS = 512 -- M2.1. The full map is Map.SIZE_STUDS (2048) and is M2.2's business.
Config.GROUND_Y = 0 -- matches Boar.CONFIG.field.groundY, so the switch needs no boar change

-- READ FROM THE CONTRACT, not copied: the pad radius the spec measures a spawn against and the pad
-- radius the heightfield flattens have to be the same number or the map fails its own check.
Config.SPAWN_PAD = Map.SPAWN_PAD

-- MEASURED, 2026-09-26 (design section 13.5 measurement A): Terrain:WriteVoxels accepts a
-- 128 x 128 x 96-stud region at resolution 4 (32 x 24 x 32 = 24,576 voxels), and REFUSES resolution
-- 8 and resolution 2 with "Resolution has to be 4". So 4 is not a preference, it is the only value
-- the API takes, and the design's "unverified" on this row is closed.
Config.VOXEL = 4
Config.TILE_STUDS = 128 -- 4 x 4 = 16 tiles for the slice; 16 x 16 = 256 for the full map
Config.BAND_Y = { min = -48, max = 48 } -- 24 voxel layers, covering +/- 40 studs of relief

-- ---------------------------------------------------------------- the heightfield

Config.RELIEF = 40 -- K, studs, whole map: gentle farmland, well inside Boar's FALL_LIMIT of 50
Config.CORRIDOR_RELIEF = 16 -- K, inside the drive corridor, so terrain never spawns or eats a boar
Config.OCTAVES = 4
Config.BASE_FREQUENCY = 1 / 420 -- studs^-1; one broad rise per ~420 studs
Config.LACUNARITY = 2.1
Config.GAIN = 0.5
Config.WARP = 60 -- studs of domain warp: what stops the ridges looking like a sine grid
Config.WARP_FREQUENCY = 1 / 700

-- ---------------------------------------------------------------- the slice's layout (M2.1)

-- The same shape as the design's section 12 corridor, scaled into 512 studs. The full-map numbers
-- (line z = -700, start z = +700, spacing 80) arrive with M2.2, in this table, in a diff.
Config.SLICE = {
	corridor = { minX = -190, maxX = 190, minZ = -210, maxZ = 210 },
	lineZ = -180, -- the shooter line, along the wood edge
	postCount = 8,
	postSpacing = 46, -- K, span 322 studs inside a 512 slice
	driverStartZ = 180,
	driverStartSize = Vector3.new(120, 1, 12),
	boarSpawnZ = 150,
	boarSpawnX = { -150, -50, 50, 150 }, -- K
	driveLineSize = Vector3.new(340, 1, 1),
	-- One line, M2.1's single hedge, WITH A GATE IN IT. A continuous 7-stud hedge across the drive
	-- corridor is a wall between the boars and the shooter line, and the boar's agent has
	-- AgentCanJump = false: the drive would simply stop at it (review round 2, finding 2). Real
	-- farmland has gates and gaps in its hedgerows for exactly the same reason.
	hedgerow = { z = 40, fromX = -230, toX = 230, gateStuds = 72 },
	treeCount = 50, -- M2.1: one asset key, proxies until Karen's ids arrive
	tieTrees = 12, -- tagged DrivenHunt.Tree, the nearest to the line (design section 4.3)
	-- The whole slice: the corridor is carved out of it by Layout.inCorridor, so the wood ends up
	-- behind the shooter line, along both flanks and behind the drivers -- a lane through trees,
	-- which is what a driven hunt is. A rectangle "behind the line" alone gives a hedge, not a wood.
	treeArea = { minX = -250, maxX = 250, minZ = -250, maxZ = 250 },
	trackZ = -60, -- one dirt track across the slice, material only
	trackHalfWidth = 6,
}

-- MEASURED on the first real build (seed 7): the drive corridor and the track reject about two
-- thirds of the cells, so 3 cells per wanted tree yielded 46 of 50 and the step failed honestly
-- rather than shipping a thin wood. 6 leaves ~100 candidates for 50 trees.
Config.SCATTER_OVERSAMPLE = 6
Config.SCATTER_JITTER = 0.9 -- of a cell; 0 is a grid, 1 lets two neighbours touch
Config.ROUGH_SLOPE = 0.3 -- studs per stud: above this the field material becomes LeafyGrass

-- ---------------------------------------------------------------- materials

-- Four materials and no Water: the design's section 1.2 rule. A bog is Mud, because water a player
-- can drown in is a different feature with its own rules.
Config.MATERIAL = {
	field = Enum.Material.Grass,
	rough = Enum.Material.LeafyGrass,
	track = Enum.Material.Ground,
	bog = Enum.Material.Mud,
}

-- ---------------------------------------------------------------- props

Config.PROXY_COLOR = {
	tree = Color3.fromRGB(70, 95, 60),
	hedge = Color3.fromRGB(58, 78, 48),
	marker = Color3.fromRGB(255, 255, 255),
}
Config.TREE_PROXY = { trunk = Vector3.new(3, 22, 3), crown = Vector3.new(11, 12, 11) }
Config.HEDGE = { segmentStuds = 12, size = Vector3.new(12, 7, 3) }
Config.STAND_HEIGHT_STUDS = 3.5 -- how far above the ground a marker part's centre sits

-- ---------------------------------------------------------------- the digest

Config.DIGEST_TERRAIN_SAMPLES = 4096 -- 64 x 64 across the slice
Config.DIGEST_ROUND = 100 -- two decimal places, as integers

Config.ROOT_NAME = "DrivenHuntMap"

Shotgun.deepFreeze(Config)

return Config
