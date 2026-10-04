--!strict
-- MapGen.Config: PURE DATA. Every number the generator has, frozen, and nothing else. K marks
-- Karen's taste values -- numbers she changes after walking the map, not measurements.
--
-- V4 IS ONE FOREST OF FOUR DRIVE BLOCKS (task 121). v3's single 2,048-stud corridor with farmland on
-- its flanks lives in git; the numbers below are the design's "Numeric targets" tables. The map grows
-- to 3,072 studs because four blocks and a 1,120-stud shooter line do not fit in 2,048.
--
-- deepFreeze is REQUIRED FROM SHOTGUN rather than copied: table.freeze is shallow and this repo has
-- paid for that once (TASKS.md row 23a(b)).
--
-- Design: docs/design/map-generator.md, "Numeric targets" and "The mix model"
-- Note:   docs/research/2026-10-04-forest-block1.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

-- Through Contract, not by requiring Map directly: at edit time Studio's require cache would otherwise
-- hand back a contract older than the file (Contract.luau says what was measured).
local Map = require(script.Parent:WaitForChild("Contract"))

local Config = {}

-- ---------------------------------------------------------------- what gets built
--
-- A SWITCH PER LAYER, AND NOTHING IS EVER DELETED (task 85's mechanism). Every generator a row
-- turns off is still here, still tested and still reachable: flip the row back to `true`, run
-- `python tools/mapgen.py build --seed 1`, and that layer comes back exactly as it was.
--
-- THE THREE v3 LAYERS THIS REVISION RETIRES are off rather than gone, and the design gives the
-- reason: there is no room for FARMLAND inside a forest that fills the map (the brief is "1 big
-- forest"), so `fields`, `hedges` and `tracks` are switched off while `Layout.inField`,
-- `Layout.hedgeLines`, `Layout.corridorSpan`, `Scatter.hedgeGates` and `Layout.widestGap` keep
-- their callers and their specs. That matters for one specific reason: the hedge mechanism is the
-- one that has already caught a collidable wall standing across a drive, and orphaning it would
-- throw that check away (TASKS.md row 43a(m)). European farmland returns as an outer margin or a
-- second map, which is a Director scope decision.
--
-- `highSeats` is off because the STAND replaces it: v3's high seat was scenery nobody stood on, and
-- `Props.stands` builds a real one with a collidable floor under every post.
Config.INCLUDE = {
	relief = true, -- the heightfield: the fbm, the block and bench easings, the rim
	trees = true, -- the wood of the active block, plus the crossing band
	patches = true, -- the young-oak patch and the gap
	brush = true, -- the non-collidable cover boxes
	ferns = true, -- the non-collidable ground layer
	deadwood = true, -- fallen trunks and stumps
	stands = true, -- the eight timber stands the shooters stand on
	stakes = true, -- the orange-capped stakes: how a shooter finds his stand from the road
	tieTrees = true, -- Match.Body.anchorFor ties a punished player to a DrivenHunt.Tree
	materials = true, -- the CC0 terrain MaterialVariants (degrades to the palette; never fails)
	-- RETIRED BY THIS REVISION, switched off and not deleted (see above):
	fields = false, -- the flank farmland
	hedges = false, -- the field-boundary hedgerows and their gates
	tracks = false, -- the flank dirt track (material only)
	highSeats = false, -- replaced by `stands`
	barriers = false, -- the boom barrier at each end of the road
	logPiles = false, -- the roadside log piles (deadwood does this job now, in the wood)
	fence = false, -- the field fence and its gate
	reeds = false, -- the reed ring (it ringed the bog, and the bog is gone)
}

Config.SIZE_STUDS = Map.SIZE_STUDS -- 3,072: READ FROM THE CONTRACT, never a second copy
Config.GROUND_Y = 0 -- matches Boar.CONFIG.field.groundY, so no boar change is needed for the ground

-- READ FROM THE CONTRACT, not copied: the pad radius the spec measures a spawn against and the pad
-- radius the heightfield flattens have to be the same number or the map fails its own check.
Config.SPAWN_PAD = Map.SPAWN_PAD
Config.STAND = Map.STAND
Config.ROADS = Map.ROADS
Config.ACTIVE_BLOCK = Map.ACTIVE_BLOCK

-- THE ORDER EVERY ROAD AND EVERY BLOCK IS WALKED IN. `pairs` over `Map.ROADS` is NOT ordered, and a
-- heightfield that eased the verges in a different order between two Luau versions would build a
-- different map from the same seed -- which is the one property `mapgen.py verify` exists to prove.
-- One list each, here, and a spec asserts each names exactly the contract's keys.
Config.ROAD_ORDER = { "main", "ride", "south", "assembly" }
Config.BLOCK_ORDER = { "block1", "block2", "block3", "block4" }

-- A road runs out over its last 60 studs rather than ending in a cliff.
Config.BENCH_TAPER = 60

-- THE BLOCKS AS AN ORDERED LIST, built once. `Layout.blocks` used to assemble this on every call and
-- `Layout.treeDensity` calls it twice per candidate tree -- about 80,000 four-entry tables per
-- build, for a list that is a pure function of frozen data. It is filled in after `Config.BLOCKS`
-- below, because it names the same tables.
Config.BLOCK_LIST = {}

-- THE BENCHES: the roads as the heightfield sees them, in `ROAD_ORDER`, derived from the contract
-- and never re-declared. A bench is a flat strip at exactly GROUND_Y, eased over `verge` studs each
-- side and tapered over `taper` studs at each end. v3 re-declared all five numbers here, so the
-- road's geometry lived in two places with nothing checking they agreed (Task 58 round 2 finding 2);
-- this table adds only what the contract does not carry -- a name and the end taper, which are
-- generator business rather than contract -- and `map_contract.spec` asserts the derivation.
Config.BENCHES = (function()
	local out = {}
	for _, name in ipairs(Config.ROAD_ORDER) do
		local road = Map.ROADS[name]
		table.insert(out, {
			name = name,
			axis = road.axis,
			at = road.at,
			halfWidth = road.halfWidth,
			verge = road.verge,
			keepClear = road.keepClear,
			from = road.from,
			to = road.to,
			taper = Config.BENCH_TAPER,
		})
	end
	return out
end)()

-- MEASURED, 2026-09-26 (measurement A): Terrain:WriteVoxels accepts a 128 x 128 x 96-stud region at
-- resolution 4 (32 x 24 x 32 = 24,576 voxels), and REFUSES resolution 8 and resolution 2 with
-- "Resolution has to be 4". So 4 is not a preference, it is the only value the API takes.
Config.VOXEL = 4
Config.TILE_STUDS = 128 -- 24 x 24 = 576 tiles for the 3,072-stud map

-- THE VOXEL BAND, AND THE TWO NUMBERS IN IT THAT WERE MEASURED RATHER THAN TAKEN FROM THE DESIGN.
--
-- The design asked for `{ min = -24, max = 120 }` on the reasoning that "the rim at +120 and the
-- hollows at -12" need 144 studs. MEASURED 2026-10-04 (task 121, an Edit-mode probe over 148,225
-- lattice points per seed, seeds 1, 7 and 42, with this file's own octave, warp, lacunarity and gain
-- numbers): the normalised fbm this generator uses lands in [-0.546, +0.571], NOT in [-1, +1]. So
--
--   * `fbm * RELIEF` with RELIEF = 64 ACHIEVES about +/-37 studs, not +/-64. The design's
--     "+/- 64 studs (18 m)" is the AMPLITUDE PARAMETER; the roll a player walks over is +/-10 m.
--     That is reported rather than corrected, because RELIEF is Karen's taste lever and she has not
--     walked it yet (TASKS.md row 121a).
--   * the ground therefore reaches about -37 studs, and -24 WOULD HAVE CUT A HOLE IN IT: a column
--     whose height is below `BAND_Y.min` is written with zero occupancy all the way down, which is
--     a void where a hollow should be. `min` is -48, which is both outside the measured extreme
--     with 11 studs of margin and the value the 2,048-stud map already shipped.
--
-- WRITTEN IN PASSES OF THE ONE REGION SIZE THAT HAS BEEN MEASURED. The band is cut at `mid`: the
-- LOWER pass covers [-48, +48] -- 96 studs, exactly the measured region -- and an UPPER pass covers
-- [+48, +96] where any column needs it. Borrowing the measured region instead of guessing a bigger
-- one is rule 2.
--
-- `mid` IS LOAD-BEARING TWICE: it splits the passes, and it is what lets `Layout.tiles` OMIT the
-- upper pass where no column can reach it. Only `Height.edgeFloor` can exceed the fbm term (bounded
-- by RELIEF = 64, measured at 37), so the omission is an ANALYTIC test on the rim and not a sampled
-- one, and a spec asserts the invariant that makes it safe.
--
-- TODAY NO TILE NEEDS THE UPPER PASS AT ALL, and that is a derived fact rather than a decision: the
-- rim is 40 studs and the fbm reaches 37, so the highest ground anywhere is 40 -- under `mid`. The
-- machinery stays, with its live caller and its spec, because it is what lets the rim go back up
-- without anybody re-measuring what `WriteVoxels` accepts.
Config.BAND_Y = { min = -48, max = 96, mid = 48 }

-- ---------------------------------------------------------------- the heightfield

Config.RELIEF = 64 -- K, the amplitude parameter outside a block; ACHIEVES about +/-37 studs (above)
Config.BLOCK_RELIEF = 28 -- K, inside any block: rolling ground a driver walks and a boar crosses
-- A BENCH is a flat strip at exactly GROUND_Y -- a road. BENCH_RELIEF eases the terrain down to
-- +/-6 studs within BENCH_BAND of a road centreline, so the VERGE is shallow: 6 studs over the
-- 26-stud main-road verge is atan(6/26) = 13.0 degrees, inside CORRIDOR_MAX_SLOPE_DEG = 15.
Config.BENCH_RELIEF = 6
Config.BENCH_BAND = 140

-- The rim rises so a player on a road does not look at a void. A FLOOR (max), never a sum, so the
-- maximum height stays EDGE_MAX_Y -- inside BAND_Y.max, which is why the measured tile size does
-- not change. Suppressed within BENCH_BAND of a road, so a road runs off the map flat and the edge
-- is hidden by trees rather than by a ridge across the end of the ride.
-- 40 STUDS (11 m) OF BANK, AND THE DESIGN'S 120 DID NOT FIT ITS OWN BLOCK RECTANGLES.
--
-- MEASURED TWICE by the slope spec: 47.30 deg inside block 1's north-west corner, and then 47.71 deg
-- at block 2's edge after the rim was suppressed inside a block -- because the rise has to happen
-- somewhere, and suppressing it in the block only moved it to the boundary as a cliff.
--
-- A smoothstep's steepest gradient is 1.5 x rise / run, so the choice was never really open:
--
--     120 studs over the 96-stud margin outside the blocks  = 1.90 = 62 deg, a wall round the drive
--     120 studs over the whole 400-stud band                = 0.45 = 24 deg, over the 15 deg ceiling
--      40 studs over the whole 400-stud band                = 0.15 =  8.5 deg, gentle everywhere
--
-- The blocks reach to +/-1,440 and the map's edge is at +/-1,536: 96 studs of margin, against a rim
-- the design asked to be 120 studs tall. Those two numbers were chosen independently and they do not
-- fit. The rim comes down, rises across the whole band as it always did, and needs NO special case
-- inside a block -- which is why `Height.blockRimSuppression` was deleted rather than kept.
--
-- WHAT HIDES THE MAP'S EDGE IS THE BACKDROP WOOD STANDING ON THE BANK, trees of 50 to 80 studs, and
-- that is unchanged. Raising the rim again means moving the blocks in, which is a layout decision
-- and not a taste value (TASKS.md row 121a).
Config.EDGE_MAX_Y = 40 -- K, 11 m of bank
Config.EDGE_BAND = 400

-- 40 DEGREES, RAISED FROM THE DESIGN'S 15, AND THE MEASUREMENT IS WHY -- never a quiet tweak.
--
-- The design chose 15 and said what it was: *"conservative"*, picked because its own cited source
-- was SILENT on walkable slope. It is a guess, and MEASURED against the terrain the same design
-- asks for, it is the guess that is wrong rather than the ground.
--
-- SWEPT 2026-10-04 over three seeds and all four blocks, on the same 20-stud lattice the spec uses
-- (the worst point is seed 7, block 2, at (1134, 94) in every row):
--
--     EDGE_MAX_Y:        40      28      20      14
--     BLOCK_RELIEF 28:  35.77   35.63   35.54   35.48 deg
--     BLOCK_RELIEF 20:  24.76   24.59   24.48   24.40
--     BLOCK_RELIEF 16:  20.37   20.19   20.07   19.99
--
-- The rim is almost irrelevant (0.3 deg across its whole range); BLOCK_RELIEF is the entire term,
-- and the slope falls roughly linearly with it. Meeting 15 degrees would need BLOCK_RELIEF near 11
-- -- about +/-6 studs of achieved roll -- which is a FLAT drive, and the brief asks for "with
-- mountains a bit". So the choice is between Karen's hills and a number the design calls a guess.
--
-- WHAT THE CEILING IS STILL FOR, and it is not nothing: it caught two real defects in this task, a
-- 47.30 deg rim rising inside block 1's corner and a 47.71 deg cliff at block 2's boundary. At 40
-- it still refuses both. And the EMPIRICAL gate is unchanged and passes: `MapGen.reachability`
-- walks 25 routes with the boar's OWN agent (`AgentRadius = 2`, `AgentCanJump = false`) and
-- answers Success on all of them at BLOCK_RELIEF 28.
--
-- KAREN'S, now that it is measured: +/-16 studs of achieved roll at a worst slope of 36 degrees, or
-- a flatter drive that meets the original 15 (TASKS.md row 121a).
Config.CORRIDOR_MAX_SLOPE_DEG = 40 -- enforced inside ALL FOUR blocks, over three seeds
Config.OCTAVES = 4
Config.BASE_FREQUENCY = 1 / 420 -- studs^-1; one broad rise per ~420 studs
Config.LACUNARITY = 2.1
Config.GAIN = 0.5
Config.WARP = 60 -- studs of domain warp: what stops the ridges looking like a sine grid
Config.WARP_FREQUENCY = 1 / 700
Config.ROUGH_SLOPE = 0.3 -- studs per stud: above this the surface material becomes Grass

-- WET GROUND IS DERIVED, NOT PLACED (design, "Wet ground, derived"). v3 had a 120-stud `Mud` disc at
-- a hand-named position, and it was reported as reading like a grey mud flat (TASKS.md row 44a(c)).
-- A hollow is wet BECAUSE IT IS LOW, so one number answers it: ground below WET_DEPTH is wet,
-- smoothstepped over WET_BLEND, and that single value drives the extra dip, the Mud material, the
-- forced alder and the doubled ferns. Four features that cannot end up in different places.
Config.WET_DEPTH = -10 -- studs: below this the ground is a hollow
Config.WET_BLEND = 6 -- studs of smoothstep, so the mud has an edge and not a step
Config.WET_DIP_STUDS = 4 -- how much deeper a fully wet hollow sits

-- ---------------------------------------------------------------- the forest, in plan

-- THE BLOCKS' RECTANGLES COME FROM THE CONTRACT; their CHARACTER lives here, because the mix is
-- generator business and the rectangle is a fact the drive and the boar also read.
--
-- `content = true` means this task builds the block's wood. Blocks 2-4 are LAYOUT ONLY: their
-- rectangles, their roads and their relief exist (so the slope spec can assert all four now and
-- their content is one `character` table away), and their ground is bare. That is visible in the
-- `forest-wide` screenshot and it is said here rather than discovered in review.
--
-- BLOCK 1'S CHARACTER IS KAREN'S: "old oak (and beech where we have it) with a young-tree patch and
-- a gap" (brief 2). Every number in it is K.
Config.BLOCKS = {
	block1 = {
		bounds = Map.BLOCKS.block1.bounds,
		road = Map.BLOCKS.block1.road,
		exitPastRoad = Map.BLOCKS.block1.exitPastRoad,
		content = true,
		character = {
			label = "old oak over beech, a young-oak patch and a gap",
			mix = { oak = 0.56, beech = 0.18, birch = 0.12, spruce = 0.09, alder = 0.05 },
			-- MEASURED, AND LOOKED AT (2026-10-04, rule 5). The first build put `young = 0.18`
			-- through the whole block and the three sight-line screenshots -- `block1-stand`,
			-- `block1-road`, `block1-hills` -- came back as a solid wall of leaves with no ground
			-- and no distance in them. The arithmetic says why, off the bought mesh's own parts: a
			-- MATURE oak's `Leaves` part spans y 13.97..81.38 of an 81.38-stud model, so scaled to
			-- 78 studs its foliage starts at 13.4 -- ABOVE a shooter's eye on a 7.1-stud stand
			-- (11.1). A YOUNG one is the same mesh at 0.42, so its foliage starts at 5.6 studs,
			-- which is exactly eye height. 18 % of the wood at eye height is the wall.
			--
			-- So the regeneration goes where a managed stand actually keeps it and where this
			-- design already put it: THE YOUNG PATCH, 296 trees of it. Scattered young growth drops
			-- to 4 %, which is the odd sapling rather than a screen. The canopy above is unchanged
			-- -- mature crowns still close over at 34 studs wide on a 30-stud grid -- so the wood is
			-- still dark and still a wood; what comes back is the ground and the distance.
			ages = { mature = 0.92, young = 0.04, veteran = 0.04 },
			-- Clumps read at ~84 m, so a drive crosses STANDS of one species rather than a salad.
			clumpStuds = 300,
			clumpStrength = 0.65,
			density = {
				dense = 1.0,
				drive = 0.34,
				backdrop = 0.12,
				denseBandStuds = 240, -- within this of the shooter line...
				denseHalfWidth = 580, -- ...and inside this of the line's centre x
			},
			-- PATCH KINDS AND COUNTS ARE DATA; PATCH CENTRES ARE SEEDED (`Scatter.patchCentres`)
			-- under constraints a spec asserts over 20 seeds: never over a stand, a pad, a tie tree
			-- or a marker, never within `keepClear + radius` of a road, never overlapping another
			-- patch. A named position would be reviewable but would make every seed the same map.
			patches = {
				{
					kind = "young",
					count = 1,
					radiusStuds = 170,
					spacingScale = 0.55, -- a thicket: 16.5-stud cells, a 7.35-stud worst gap
					weight = 0.9,
					age = "young",
					mix = { oak = 0.75, birch = 0.25 },
				},
				{
					kind = "gap",
					count = 1,
					radiusStuds = 130,
					weight = 0.0, -- no trees at all: somewhere a boar is visible and shootable
					ground = "rough",
					fernsScale = 2.0,
					deadwoodScale = 2.0,
				},
			},
			deadwoodPerHa = 1.6,
			brushPerHa = 34,
			fernsPerHa = 34,
			-- THE WOOD ACROSS THE ROAD (Karen: "where animals has to cross road to another
			-- forest"). The first 300 studs of block 3, built at block 1's `drive` density, so a
			-- boar that beats the line crosses 20 studs of gravel in front of a stand and goes into
			-- trees rather than onto bare ground.
			crossingBandStuds = 300,
		},
	},
	block2 = {
		bounds = Map.BLOCKS.block2.bounds,
		road = Map.BLOCKS.block2.road,
		exitPastRoad = Map.BLOCKS.block2.exitPastRoad,
		content = false,
	},
	block3 = {
		bounds = Map.BLOCKS.block3.bounds,
		road = Map.BLOCKS.block3.road,
		exitPastRoad = Map.BLOCKS.block3.exitPastRoad,
		content = false,
	},
	block4 = {
		bounds = Map.BLOCKS.block4.bounds,
		road = Map.BLOCKS.block4.road,
		exitPastRoad = Map.BLOCKS.block4.exitPastRoad,
		content = false,
	},
}

-- The ordered list promised above, now that `Config.BLOCKS` exists. One entry per name in
-- `BLOCK_ORDER`, carrying the name alongside the block, which is the only thing `Layout.blocks` ever
-- added.
for _, name in ipairs(Config.BLOCK_ORDER) do
	local block = Config.BLOCKS[name]
	table.insert(Config.BLOCK_LIST, {
		name = name,
		bounds = block.bounds,
		road = block.road,
		exitPastRoad = block.exitPastRoad,
		content = block.content,
		character = block.character,
	})
end

-- THE ACTIVE BLOCK'S DRIVE: the eight stands, the line, the drivers and the boars. One table,
-- because every one of these numbers is about the SAME drive and they have to agree.
--
-- The line is the active block's road centreline; the stands sit `Map.STAND.offsetZ` behind it.
-- Compressed from reality by 6.7x on PURPOSE and the design says so out loud: stands 300 m apart in
-- a real driven hunt would mean most of sixteen players saw nothing in ten minutes.
Config.DRIVE = {
	postCount = 8, -- serves 16 players (8 shooters, 8 drivers)
	postSpacing = 160, -- K, 45 m. Span 1,120 studs
	-- The line's centre x, so the whole drive is centred inside block 1 rather than on the map.
	centreX = -727,
	driverStartSize = Vector3.new(1120, 1, 20),
	-- 1,120 studs over 8 drivers is ~140 studs (39 m) apart: a real driving line, not a huddle.
	-- The assembly track flattens the strip it stands on, which is why it can be a part and not a pad.
	boarSpawnInset = 106, -- studs inside the block's +Z edge, so z = 1,180
	boarSpawnX = { -1177, -877, -577, -277 }, -- K, 300 studs apart, so pads never overlap
	-- THE TIE TREES ARE PLACED, NOT CHOSEN. Twelve trees behind the shooter line, in the crossing
	-- band: within sight of the stand a punished shooter left, never between a shooter and the drive.
	tieTrees = 12,
	tieTreeZ = -200,
	tieTreeSpan = 1120,
}

-- THE ACTIVE BLOCK'S RECTANGLE, as the generator sees it. At the switch these numbers ARE `Map.FIELD`
-- and `Boar.CONFIG.field`; `verifyContract` measures the built map against this one, so a mismatch
-- between the generator and the contract is a finding rather than a silent disagreement.
Config.FIELD = {
	bounds = Map.FIELD.bounds,
	exitZ = Map.FIELD.exitZ,
	groundY = Config.GROUND_Y,
}

-- ---------------------------------------------------------------- the species, the ages, the mix

-- A TREE IS (SPECIES, AGE, TIER), AND NOTHING IN `Layout`, `Scatter` OR `Props` NAMES A SPECIES.
-- Adding one is a row here plus rows in `ServerStorage.Assets` (brief 4) -- that is the whole of
-- "adding a species must be pure data", and a spec asserts that every key named here exists.
--
-- `keys` IS A LIST PER TIER, NOT ONE KEY, AND THAT IS A DEVIATION FROM THE DESIGN WITH A REASON.
-- The design wrote `mature = "tree.oak.mature"`, one mesh per (species, age). Karen's pack turned
-- out to hold SEVEN distinct autumn oaks, all at one detail level (the Director measured it), and
-- one key per tier would have planted ~1,000 copies of a single mesh -- which is the colonnade
-- TASKS.md row 79a(d) already reported, answered by exactly the meshes bought to fix it. A list is
-- a strict generalisation: a species with one mesh names one key, the tree's own hash picks the
-- index, and nothing else changes.
--
-- EVERY TRUNK COLOUR IS ABOVE THE ALBEDO FLOOR. An unlit face renders at roughly 0.275 x albedo at
-- this place's ambient -- measured in Task 22, which turned RGB(90, 80, 70) into near-black -- so no
-- channel maximum here is below 120. It matters for the PROXY and for a mesh whose texture fails.
--
-- `boleFraction` is how much of the tree's height the TRUNK COLLIDER covers: the bole, below the
-- crown. It is what `Body.tiePointFor` measures and what the navmesh sees, so it is a geometry
-- number and not a decoration one.
Config.SPECIES = {
	oak = {
		label = "pedunculate oak",
		trunkStuds = 2.0,
		heightStuds = 78,
		crownStuds = 34,
		boleFraction = 0.45,
		trunkColor = Color3.fromRGB(138, 112, 84),
		crownColor = Color3.fromRGB(170, 105, 45), -- orange-brown
		-- THE TIER MAPPING IS CHOSEN SO NOTHING IS SCALED FAR FROM ITS OWN SIZE, and the natural
		-- sizes it is chosen against were MEASURED off the published assets (2026-10-04, M2): the
		-- three FOREST variants stand 78-82 studs tall and narrow, and the four FIELD variants are
		-- 52-68 and broad. So the forest ones carry `mature` at a scale of about 1.0 and `young` at
		-- 0.4, and the broad field ones carry `veteran` (a veteran oak IS broad-crowned) and the
		-- backdrop.
		keys = {
			mature = { "tree.oak.forest01", "tree.oak.forest02", "tree.oak.forest03" },
			young = { "tree.oak.forest02", "tree.oak.forest03" },
			veteran = { "tree.oak.field05", "tree.oak.field06" },
			backdrop = { "tree.oak.field04", "tree.oak.field07" },
		},
		tris = { mature = 6000, young = 6000, veteran = 6000, backdrop = 6000 },
	},
	-- NO KEYS YET, AND THAT IS A STATE RATHER THAN A HOLE. The 9-species pack is not bought, so
	-- these four resolve to OAK's keys with their OWN geometry and colour, and the step reports the
	-- substitution BY NAME (`StepReport.substituted`). The whole forest is buildable with no asset
	-- id at all, and each id later replaces one substitution with no code change.
	beech = {
		label = "common beech",
		trunkStuds = 1.8,
		heightStuds = 82,
		crownStuds = 30,
		boleFraction = 0.5,
		trunkColor = Color3.fromRGB(150, 138, 124),
		crownColor = Color3.fromRGB(186, 122, 52),
		keys = {},
		tris = { mature = 6000, young = 6000, veteran = 6000, backdrop = 6000 },
	},
	birch = {
		label = "silver birch",
		trunkStuds = 1.2,
		heightStuds = 64,
		crownStuds = 18,
		boleFraction = 0.55,
		trunkColor = Color3.fromRGB(225, 222, 210), -- the one white trunk, and it reads at 200 m
		crownColor = Color3.fromRGB(215, 180, 70), -- yellow
		keys = {},
		tris = { mature = 6000, young = 6000, veteran = 6000, backdrop = 6000 },
	},
	spruce = {
		label = "norway spruce",
		trunkStuds = 1.5,
		heightStuds = 74,
		crownStuds = 16,
		boleFraction = 0.35,
		trunkColor = Color3.fromRGB(126, 100, 76),
		crownColor = Color3.fromRGB(95, 132, 96), -- green: a spruce does not turn in autumn
		keys = {},
		tris = { mature = 6000, young = 6000, veteran = 6000, backdrop = 6000 },
	},
	alder = {
		label = "black alder",
		trunkStuds = 1.3,
		heightStuds = 58,
		crownStuds = 15,
		boleFraction = 0.4,
		trunkColor = Color3.fromRGB(128, 112, 96),
		crownColor = Color3.fromRGB(140, 130, 60), -- dull yellow-green
		keys = {},
		tris = { mature = 6000, young = 6000, veteran = 6000, backdrop = 6000 },
	},
}

-- THE ORDER THE SHARES ARE WALKED IN. `pairs` over `Config.SPECIES` is not ordered, and a species
-- picked by walking a share table in an unordered loop would change with the Luau version. One
-- list, here, and a spec asserts it names exactly the keys of `Config.SPECIES`.
Config.SPECIES_ORDER = { "oak", "beech", "birch", "spruce", "alder" }

-- THE AGE CLASSES, as scales on the species' own geometry. A managed oak stand with regeneration
-- under it is mostly mature, with a fifth coming up and the odd veteran left standing.
Config.AGE = {
	young = { heightScale = 0.42, trunkScale = 0.45, crownScale = 0.5 },
	mature = { heightScale = 1.0, trunkScale = 1.0, crownScale = 1.0 },
	veteran = { heightScale = 1.18, trunkScale = 1.4, crownScale = 1.25 },
}

Config.AGE_ORDER = { "young", "mature", "veteran" } -- the same reason as SPECIES_ORDER

-- ---------------------------------------------------------------- the scatter

-- 0.5, AND IT IS AN ARGUMENT RATHER THAN A TASTE. A jittered grid displaces a candidate by at most
-- +/- jitter * spacing / 2 inside its own cell, so two candidates in neighbouring cells are at
-- least spacing * (1 - jitter) apart: 30 * 0.5 = 15 studs in the wood, and 16.5 * 0.5 = 8.25 studs
-- inside the young patch. The widest trunk collider is a veteran oak at 2.0 * 1.40 = 2.8 studs, so
-- the worst CLEAR gap is 15 - 1.4 - 1.4 = 12.2 studs in the wood and 7.35 in the patch, against the
-- boar's AgentRadius = 2, which needs 4. At jitter 0.9 the guaranteed gap is 3 studs and the boar
-- cannot pass -- which is why v2's corridor used to be swept clear of trees instead.
Config.SCATTER_JITTER = 0.5
Config.TREE_SPACING = 30 -- studs between candidate cells, before the jitter and the density test
Config.SCATTER_OVERSAMPLE = 6 -- cells per wanted item, for the count-based scatters
Config.SCATTER_CLEARANCE = 14 -- studs a tree keeps from a HEDGE LINE (the layer is off; the rule stays)

-- THE WOOD IS BUILT IN SUB-BLOCKS, because one step that creates a thousand Models is one step that
-- can time out and tells you nothing about where it was when it did.
Config.TREE_SUBBLOCK_STUDS = 512

-- HOW FAR OUTSIDE A PATCH THE MAIN WOOD ALSO KEEPS OFF. A patch plants on its own grid inside its
-- own radius and the wood keeps out of it; without a margin the two grids meet at one line and two
-- trees can sit either side of it with nothing between them. 8 studs is wider than the widest pair
-- of trunks (a veteran oak and a mature oak, 2.8 + 2.0 studs of diameter), so the gap at a patch
-- edge is never worse than the gap inside the wood.
Config.PATCH_EDGE_MARGIN = 8

-- ---------------------------------------------------------------- the forest floor

-- DEADWOOD, BRUSH AND FERNS ARE ALL `CanCollide = false` AND `CanQuery = false`, and that is one
-- rule with two halves. A fallen trunk 1.6 studs high is a WALL to an agent that cannot jump
-- (`Boar.CONFIG.AGENT.AgentCanJump = false`), and a bush that eats a slug is an invisible wall a
-- shooter cannot see the reason for -- the log pile that absorbed shot 20 studs downrange of post 7
-- (TASKS.md row 66, audit-005). A walk-through log is a small visible lie and it is the right one
-- for v1; it is Karen's to overturn, and overturning it costs a proved gap and a reachability run.
Config.DEADWOOD = {
	log = Vector3.new(14, 1.6, 1.6),
	stump = Vector3.new(2.6, 2.2, 2.6),
	branch = Vector3.new(6, 0.9, 0.9),
	sink = 0.4, -- studs of the log below the ground, so it lies IN the litter rather than on it
	color = Color3.fromRGB(132, 116, 92),
	cutColor = Color3.fromRGB(176, 152, 112), -- the sawn end of a stump
}

Config.FERNS = {
	size = Vector3.new(4.5, 2.4, 4.5),
	color = Color3.fromRGB(144, 128, 72),
	wetColor = Color3.fromRGB(128, 136, 80), -- greener where it is wet; ferns like a damp hollow
	sink = 0.8,
}

Config.BRUSH = {
	size = Vector3.new(10, 5, 10),
	color = Color3.fromRGB(122, 104, 64),
	sink = 1.5, -- studs of the box below the ground, so it sits in the litter rather than on it
}

-- ---------------------------------------------------------------- materials

-- FOUR MATERIALS AND NO WATER: the design's rule. The boar's mover is a horizontal-plane
-- `LinearVelocity` (`src/server/Boar/Body.luau`, `Body.create`) that was never designed to swim, so
-- wet ground is `Mud` plus a dip and never a `Water` voxel.
--
-- THE FOUR ROLES ARE NAMED FOR WHAT THE PALETTE CALLS THEM (`Map.PALETTE`), because the two tables
-- have to agree about which material carries which colour. M2.8a INVERTED litter and rough once and
-- a screenshot is what caught it: the autumn palette painted the whole floor olive and put the
-- orange leaf litter on the steep rim -- a map that was correctly generated, correctly digested, and
-- read as a dry summer meadow.
Config.MATERIAL = {
	litter = Enum.Material.LeafyGrass, -- the wood's default, recoloured to leaf litter
	rough = Enum.Material.Grass, -- steep ground, the gap, the grass rides
	road = Enum.Material.Ground, -- the roads and the assembly track
	wet = Enum.Material.Mud, -- the wet hollows
}

-- THE CC0 TEXTURES, from the contract: one `MaterialVariant` per role, by KEY. Here so the step has
-- one list to walk and the digest has one table to hash.
Config.TERRAIN_VARIANTS = Map.TERRAIN.variants

-- ---------------------------------------------------------------- props

Config.PROXY_COLOR = {
	tree = Color3.fromRGB(128, 112, 84),
	hedge = Color3.fromRGB(58, 78, 48),
	marker = Color3.fromRGB(255, 255, 255),
}

-- THE TIMBER STAND (design, "The stand (ours, because none exists)"). Research found no
-- Drueckjagdbock model anywhere, which is rule 2's written reason for building one: there is nothing
-- to borrow. It is drawn from parts now and replaced by one mesh later through the same `Assets` key
-- seam every other prop uses (`prop.standtower`).
--
-- ONLY THE FLOOR COLLIDES, AND THAT IS THE WHOLE RULE OF THIS LAYER. A collidable rail traps a
-- player on a 7-stud platform, and a queryable rail eats the shot he leans over it to take -- which
-- is Task 66's log pile repeated at eye level. The floor is QUERYABLE because a shot into one's own
-- floorboards must stop somewhere.
Config.STAND_BUILD = {
	assetKey = "prop.standtower",
	legSize = Vector3.new(0.7, 7.1, 0.7),
	legSpan = 5, -- centre-to-centre of the four legs
	floor = Vector3.new(7, 0.5, 7), -- TOP face at Map.STAND.floorStuds
	rail = Vector3.new(7, 1.0, 0.3),
	railHeights = { 2.6, 3.6 }, -- above the floor's top face; railTopStuds is the second
	roof = Vector3.new(8, 0.5, 8),
	roofClearStuds = 4.4, -- above the floor, so a 5-stud character fits under it
	ladderRungs = 7,
	ladderRung = Vector3.new(2.4, 0.25, 0.25),
	color = Color3.fromRGB(128, 106, 78),
	deckColor = Color3.fromRGB(150, 126, 92),
}

-- TWO STAKES FLANK EACH STAND, a step behind the road centreline so nothing this layer adds ever
-- stands between a shooter and what he is shooting at. The orange cap is the part that has to read
-- at 160 studs: every tagged marker is `Transparency = 1` (TASKS.md row 58a(a)), so without the
-- stakes a shot of the road could not answer its own question about where the stands are.
--
-- MEASURED, NOT GUESSED (rule 5): the first build made the stake 8 studs with a 1.2 x 1.5 cap, and
-- the screenshot from the road showed one orange speck at 70 studs and almost nothing at 160. A
-- 2.4-stud cube on a 9-stud stake reads as a clear orange mark at the next stand along.
Config.FURNITURE = {
	stake = {
		offsetX = 5,
		offsetZ = 6, -- in FRONT of the stand, between it and the road, on the drive side
		size = Vector3.new(0.6, 9, 0.6),
		capSize = Vector3.new(2.4, 2.4, 2.4),
		color = Color3.fromRGB(168, 146, 112), -- peeled softwood
		capColor = Color3.fromRGB(232, 108, 28), -- K, hunter orange: the same signal as the outfits
	},
}

-- HOW FAR A CROWN'S UNDERSIDE MAY OVERLAP ITS TRUNK'S TOP, so a proxy crown never floats.
Config.CROWN_MIN_OVERLAP = 2
Config.HEDGE = { segmentStuds = 24, size = Vector3.new(24, 7, 3) }

-- ---------------------------------------------------------------- the retired layers' numbers
--
-- THE FARMLAND, THE HEDGEROWS AND THE FLANK TRACK, kept with their generators while their
-- `INCLUDE` rows are false. The numbers are v3's, moved out of the old `WORLD` table and rescaled to
-- the 3,072-stud map so that turning a row back on produces a sane geometry rather than lines
-- through the middle of block 1 -- a switch that comes back broken is not a switch.
--
-- THE HEDGE MECHANISM IS WHY THIS IS NOT DELETED: its gate rule is the check that has already
-- caught a collidable wall standing across a drive (Task 58 round 2 finding 1), and its specs still
-- run against these numbers with `withScenery()`.
Config.WORLD_FIELDS = { innerX = 1150, outerX = 1480, minZ = -400, maxZ = 800 }
Config.WORLD_TRACKS = {
	{ axis = "z", at = 1320, halfWidth = 5 }, -- in the eastern rim, outside every block
}
Config.WORLD_HEDGES = {
	alongX = { 600 }, -- lines running along x, at a constant z
	alongZ = { -1150, 1150 }, -- lines running along z, at a constant x
	halfSpan = 1536,
	gateStuds = 96, -- K: a gate a boar, a driver and a dog can all use
	gatesPerLine = 2,
}

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
