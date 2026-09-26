--!strict
-- MapGen.Config: PURE DATA. Every number the generator has, frozen, and nothing else. K marks
-- Karen's taste values -- numbers she changes after walking the map, not measurements.
--
-- MILESTONE 2.2 BUILDS THE WHOLE 2048-STUD MAP. Milestone 2.1's 512-stud slice is gone from this
-- file and lives in git at `task-43-map-slice`: it was a scale model of this shape, built to prove
-- the pipeline, and keeping both would be two worlds in one config -- the half-on state the design
-- spends section 9 avoiding. The numbers below are the design's section 12 table.
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

Config.SIZE_STUDS = 2048 -- 573 m at 1 stud = 0.28 m; ~2x StreamingTargetRadius, so streaming is used
Config.GROUND_Y = 0 -- matches Boar.CONFIG.field.groundY, so the M2.5 switch needs no boar change

-- READ FROM THE CONTRACT, not copied: the pad radius the spec measures a spawn against and the pad
-- radius the heightfield flattens have to be the same number or the map fails its own check.
Config.SPAWN_PAD = Map.SPAWN_PAD

-- MEASURED, 2026-09-26 (design section 13.5 measurement A): Terrain:WriteVoxels accepts a
-- 128 x 128 x 96-stud region at resolution 4 (32 x 24 x 32 = 24,576 voxels), and REFUSES resolution
-- 8 and resolution 2 with "Resolution has to be 4". So 4 is not a preference, it is the only value
-- the API takes, and the design's "unverified" on this row is closed.
Config.VOXEL = 4
Config.TILE_STUDS = 128 -- 16 x 16 = 256 tiles for the full map
Config.BAND_Y = { min = -48, max = 48 } -- 24 voxel layers, covering +/- 40 studs of relief

-- ---------------------------------------------------------------- the heightfield

Config.RELIEF = 40 -- K, studs, whole map: gentle farmland, well inside Boar's FALL_LIMIT of 50
Config.CORRIDOR_RELIEF = 16 -- K, inside the drive corridor, so terrain never spawns or eats a boar
Config.CORRIDOR_MAX_SLOPE_DEG = 15 -- the design's conservative ceiling; the spec measures it
Config.OCTAVES = 4
Config.BASE_FREQUENCY = 1 / 420 -- studs^-1; one broad rise per ~420 studs
Config.LACUNARITY = 2.1
Config.GAIN = 0.5
Config.WARP = 60 -- studs of domain warp: what stops the ridges looking like a sine grid
Config.WARP_FREQUENCY = 1 / 700
Config.ROUGH_SLOPE = 0.3 -- studs per stud: above this the field material becomes LeafyGrass

-- ---------------------------------------------------------------- the world's layout

-- The design's section 12 table, in one place. The drive runs from z = +700 (drivers) to z = -700
-- (the shooter line), 1,400 studs of it, inside a corridor 680 studs wide.
Config.WORLD = {
	corridor = { minX = -340, maxX = 340, minZ = -800, maxZ = 800 },
	exitZ = -760, -- 60 studs behind the line: a boar that beats the line vanishes behind the shooters

	lineZ = -700, -- the shooter line, along the wood edge
	postCount = 8, -- serves 16 players (8 shooters)
	postSpacing = 80, -- K, span 560 studs
	driveLineSize = Vector3.new(680, 1, 1), -- the corridor's full width

	driverStartZ = 700,
	driverStartSize = Vector3.new(240, 1, 12), -- K, spread over x +/- 120

	boarSpawnZ = 600,
	boarSpawnX = { -240, -80, 80, 240 }, -- K

	-- THE TIE TREES ARE PLACED, NOT CHOSEN. Milestone 2.1 tagged the twelve scattered trunks nearest
	-- the line; at full size the wood starts beyond the corridor, so the nearest scattered trunk is
	-- ~150 studs from the line and the design's "within 120 studs" (section 4.3) could not hold. Twelve
	-- trees behind the shooter line, between the posts, is also what a real stand looks like.
	tieTrees = 12,
	tieTreeZ = -745, -- 45 studs BEHIND the line, so nothing stands between a shooter and the drive
	tieTreeSpan = 560, -- the post span

	treeCount = 400, -- K, proxies until M2.3 raises it to 3,000 with real meshes
	treeArea = { minX = -1000, maxX = 1000, minZ = -1000, maxZ = 1000 },

	-- THE HEDGEROW NETWORK: field boundaries on a grid, each line the full width or depth of the map.
	-- Three run along x (constant z) and two along z (constant x), so the map reads as fields of about
	-- 512 studs (143 m) rather than as one meadow. 10,240 studs of hedge in 24-stud segments = 427
	-- parts, inside the design's 500-part hedge budget; the design's "<= 6,000 studs of hedge" row is
	-- exceeded, and that is called out in the review request rather than quietly ignored.
	hedgeZ = { -512, 0, 512 }, -- lines running along x
	hedgeX = { -512, 512 }, -- lines running along z
	hedgeHalfSpan = 1024,
	gateStuds = 96, -- K: a gate a boar, a driver and a dog can all use
	gatesPerLine = 2, -- inside the corridor, where the drive crosses

	-- Dirt tracks, material only: the height was already decided by the heightfield.
	tracks = {
		{ axis = "x", at = -250, halfWidth = 7 }, -- across the drive, between the line and mid-field
		{ axis = "z", at = 430, halfWidth = 7 }, -- along the map, outside the corridor
	},

	-- One bog, OUTSIDE the drive corridor. A bog in the lane is an obstacle in the one place the drive
	-- must be open, and design section 13.3 asks whether it reads as a feature or an annoyance --
	-- which is Karen's call to make while walking it, not one to prejudge by putting it in her way.
	bog = { x = -700, z = -300, radius = 120, depth = 6 },
}

-- THE MAP'S OWN RECTANGLE. `Map.FIELD` is the rectangle of the world `Map.EXPECTED_WORLD` NAMES,
-- which until M2.5 is the arena; this is the one the generated map is checked against. At the switch
-- these numbers become `Map.FIELD` and `Boar.CONFIG.field` together, and this table goes away.
Config.FIELD = {
	bounds = Config.WORLD.corridor,
	exitZ = Config.WORLD.exitZ,
	groundY = Config.GROUND_Y,
}

-- ---------------------------------------------------------------- scatter

Config.SCATTER_OVERSAMPLE = 6 -- cells per wanted tree: the corridor, tracks, bog and hedges reject many
Config.SCATTER_JITTER = 0.9 -- of a cell; 0 is a grid, 1 lets two neighbours touch
Config.SCATTER_CLEARANCE = 14 -- studs a tree keeps from a hedge line, a track or the bog edge

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
Config.HEDGE = { segmentStuds = 24, size = Vector3.new(24, 7, 3) }

-- ---------------------------------------------------------------- the digest and the run

Config.DIGEST_TERRAIN_SAMPLES = 4096 -- 64 x 64 across the map
Config.DIGEST_ROUND = 100 -- two decimal places, as integers

-- MEASURED, 2026-09-26: a wall thrown across the corridor still gave PathStatus.Success one second
-- after it appeared, and NoPath after five. Studio rebuilds its navmesh in the background, so the
-- reachability step waits before it asks -- a check that races the navmesh answers about the map as
-- it was, which is worse than no check.
Config.REACH_SETTLE_SECONDS = 6

Config.ROOT_NAME = "DrivenHuntMap"

Shotgun.deepFreeze(Config)

return Config
