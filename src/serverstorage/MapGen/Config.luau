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

-- The asset MANIFEST's key list, so a species row carries the key it asks for instead of the placing
-- step naming one key for the whole wood (audit-005 must-fix 2). Data only: `Assets` requires nothing,
-- so there is no cycle, and there is still exactly one id table in the repo (design section 12.2).
local Assets = require(script.Parent:WaitForChild("Assets"))

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

-- M2.8a. A BENCH is a flat strip at exactly GROUND_Y -- the forest road and the drivers' assembly
-- track. BENCH_RELIEF eases the terrain down to +/-6 studs within BENCH_BAND of a bench centreline,
-- so the VERGE is shallow: 6 studs over the 24-stud verge is atan(6/24) = 14.0 degrees, inside
-- CORRIDOR_MAX_SLOPE_DEG = 15. Without it the corridor's +/-16 against a flat road is 33.7 degrees,
-- which the slope spec would correctly fail (design section 6.2).
Config.BENCH_RELIEF = 6
Config.BENCH_BAND = 120

-- The outer ring rises so a player on the road does not look at a void. A FLOOR (max), never a sum,
-- so the maximum height stays 44 -- inside the measured voxel band BAND_Y = {-48, +48}, which is why
-- the tile size measurement A proved does not change. Suppressed within BENCH_BAND of a bench, so the
-- road runs off the map flat and the edge is hidden by trees rather than by a ridge.
Config.EDGE_MAX_Y = 44
Config.EDGE_BAND = 100
Config.CORRIDOR_MAX_SLOPE_DEG = 15 -- the design's conservative ceiling, measured by map_contract.spec
Config.OCTAVES = 4
Config.BASE_FREQUENCY = 1 / 420 -- studs^-1; one broad rise per ~420 studs
Config.LACUNARITY = 2.1
Config.GAIN = 0.5
Config.WARP = 60 -- studs of domain warp: what stops the ridges looking like a sine grid
Config.WARP_FREQUENCY = 1 / 700
Config.ROUGH_SLOPE = 0.3 -- studs per stud: above this the field material becomes LeafyGrass

-- ---------------------------------------------------------------- the world's layout

-- The design's section 15.1 table, in one place. The drive runs from z = +700 (drivers) to
-- z = -700 (the FOREST ROAD, which is the shooter line), 1,400 studs of it, inside a corridor 1,240
-- studs wide -- wide enough to hold a 1,120-stud shooter line at Karen's 45 m spacing.
Config.WORLD = {
	corridor = { minX = -620, maxX = 620, minZ = -880, maxZ = 800 },
	-- 120 studs PAST the road, in the far wood: a boar that beats the line crosses the gravel in
	-- front of a shooter and disappears into trees, which is what Karen's references show and what
	-- makes a missed crossing feel like a miss rather than a despawn.
	exitZ = -820,

	lineZ = -700, -- the shooter line IS the forest road's centreline; there is no second concept
	postCount = 8, -- serves 16 players (8 shooters)
	postSpacing = 160, -- K, 45 m, inside Karen's 40-80 m. Span 1,120 studs
	driveLineSize = Vector3.new(1240, 1, 1), -- the corridor's full width

	driverStartZ = 700,
	-- 1,120 studs over 8 drivers is ~140 studs (39 m) apart: a real driving line, not a huddle.
	-- Map.ASSEMBLY flattens the strip it stands on, which is why this can be a part and not a pad.
	driverStartSize = Vector3.new(1120, 1, 20),

	boarSpawnZ = 600,
	boarSpawnX = { -450, -150, 150, 450 }, -- K, widened with the corridor

	-- THE TIE TREES ARE PLACED, NOT CHOSEN. Milestone 2.1 tagged the twelve scattered trunks nearest
	-- the line; at full size the wood starts beyond the corridor, so the nearest scattered trunk is
	-- ~150 studs from the line and the design's "within 120 studs" (section 4.3) could not hold. Twelve
	-- trees behind the shooter line, between the posts, is also what a real stand looks like.
	tieTrees = 12,
	-- 45 studs BEHIND the line, which since M2.8a is behind the shooters IN THE FAR WOOD: within
	-- sight of the post they left, out of everyone's line of fire, and never between a shooter and
	-- the drive.
	tieTreeZ = -745,
	tieTreeSpan = 1120, -- the post span

	-- THE WOOD IS NO LONGER A COUNT (M2.8b, design section 7.2). A flat `treeCount` scattered
	-- everywhere outside the corridor made a map with a bare drive and a decorated backdrop --
	-- exactly the wrong way round. The candidate grid is fixed at TREE_SPACING and each candidate is
	-- accepted against `Layout.treeDensity`, so the wood is DENSE where the shooter's eye is, thinner
	-- across the rest of the drive, and sparse in the backdrop. The count that comes out is measured,
	-- not asked for, and the step FAILS if it exceeds Map.BUDGET.trees.
	treeArea = { minX = -1000, maxX = 1000, minZ = -1000, maxZ = 1000 },

	-- THE HEDGEROW NETWORK: field boundaries on a grid, each line the full width or depth of the map.
	-- Three run along x (constant z) and two along z (constant x), so the map reads as fields of about
	-- 512 studs (143 m) rather than as one meadow. 10,240 studs of hedge in 24-stud segments is 430
	-- segments before the gates are cut and 400 after, inside the design's 500-part hedge budget; the
	-- design's "<= 6,000 studs of hedge" row is exceeded, and that is queued as TASKS.md row 44a(a)
	-- rather than quietly ignored.
	-- M2.8a: THREE lines, not five. The corridor is now 1,240 studs wide, so the old x = +/-512
	-- lines ran straight through the drive; the field boundaries move out to the flanks at +/-760 and
	-- one line crosses at z = +300. 6,144 studs of hedge in 24-stud segments is ~250 parts, inside
	-- Map.BUDGET.hedgeParts = 400, and it closes TASKS.md row 44a(a) -- the design's own
	-- "<= 6,000 studs" row that the five-line network exceeded.
	hedgeZ = { 300 }, -- lines running along x
	hedgeX = { -760, 760 }, -- lines running along z
	hedgeHalfSpan = 1024,
	gateStuds = 96, -- K: a gate a boar, a driver and a dog can all use
	gatesPerLine = 2, -- inside the corridor, where the drive crosses

	-- ONE FLANK TRACK, material only: the height was already decided by the heightfield.
	--
	-- The two v2 tracks are gone (design section 7.6, and TASKS.md row 58a(d) found the second one
	-- stale): `x = -250` ran ACROSS the drive, and `z = 430` ran the length of the map INSIDE the
	-- widened corridor while its comment still said "outside the corridor". The drive is a wood with
	-- a road in it now; the farm track belongs in the field.
	tracks = {
		{ axis = "z", at = 880, halfWidth = 5 }, -- in the eastern field, well outside the corridor
	},

	-- One bog, OUTSIDE the drive corridor. A bog in the lane is an obstacle in the one place the drive
	-- must be open, and design section 13.3 asks whether it reads as a feature or an annoyance --
	-- which is Karen's call to make while walking it, not one to prejudge by putting it in her way.
	bog = { x = -820, z = -300, radius = 120, depth = 6 },

	-- THE BENCHES (design section 6.3), GEOMETRY FROM THE CONTRACT. A bench is flat at GROUND_Y, eased
	-- over `verge` studs each side and tapered over `taper` studs at each end. Everything the game
	-- stands a player or a boar on is at GROUND_Y -- the road, the assembly track and the four spawn
	-- pads -- so Boar.CONFIG.field.groundY needs no change at the M2.5 switch.
	--
	-- The road is LEVEL, not contour-following. Marked K and named as a simplification: a real forest
	-- road undulates, and the cost of a longitudinal profile is that every post, and the contract's
	-- tolerance check, stops being a comparison against one number (design section 6.3).
	-- READ FROM THE CONTRACT, not copied (round 2 finding 2). `Map.ROAD` and `Map.ASSEMBLY` are the
	-- one source; this table adds only what the contract does not carry -- a name, the axis, and the
	-- end taper, which are generator business rather than contract. Round 1 re-declared all five
	-- numbers here, so the road's geometry lived in two places with nothing checking they agreed --
	-- the very duplication `Config.SPAWN_PAD = Map.SPAWN_PAD` above exists to avoid, and the one
	-- claim 7 said it was closing for `MapGen.VERSION`. `map_contract.spec` asserts the derivation.
	benches = {
		{
			name = "road",
			axis = "x", -- runs along x, at a constant z
			at = Map.ROAD.z,
			halfWidth = Map.ROAD.halfWidth,
			verge = Map.ROAD.verge,
			from = Map.ROAD.from,
			to = Map.ROAD.to,
			taper = 60,
		},
		{
			name = "assembly",
			axis = "x",
			at = Map.ASSEMBLY.z,
			halfWidth = Map.ASSEMBLY.halfWidth,
			verge = Map.ASSEMBLY.verge,
			from = Map.ASSEMBLY.from,
			to = Map.ASSEMBLY.to,
			taper = 60,
		},
	},

	-- The flank farmland. Outside these, and outside the benches, the ground is forest floor.
	fields = { innerX = 760, outerX = 1024, minZ = -400, maxZ = 800 },
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

Config.SCATTER_OVERSAMPLE = 6 -- cells per wanted tree, for the count-based scatters that remain
-- 0.5, NOT the built 0.9, AND IT IS AN ARGUMENT RATHER THAN A TASTE (design section 7.3). A jittered
-- grid displaces a candidate by at most +/- jitter * spacing / 2 inside its own cell, so two
-- candidates in neighbouring cells are at least spacing * (1 - jitter) apart: 22 * 0.5 = 11 studs.
-- The widest trunk is oak at 5, so the worst clear gap is 11 - 2.5 - 2.5 = 6 studs against the boar's
-- AgentRadius = 2, which needs 4. At 0.9 the guaranteed gap is 2.2 studs and the boar cannot pass --
-- which is why the corridor used to be swept clear of trees instead.
Config.SCATTER_JITTER = 0.5
Config.SCATTER_CLEARANCE = 14 -- studs a tree keeps from a HEDGE LINE; a track and the bog reject at their own edge

-- THE WOOD (design sections 7.1-7.4). One candidate grid, three density tiers, four species.
Config.TREE_SPACING = 22 -- studs between candidate cells, before the jitter and the density test

-- The tiers, as weights in 0..1: a candidate is accepted when its own drawn key is below the weight.
-- Dense where the shooter's eye is, thinner across the rest of the drive, sparse in the backdrop.
Config.TREE_DENSITY = {
	dense = 1.0, -- K
	drive = 0.42, -- K
	backdrop = 0.14, -- K
	denseBandStuds = 260, -- K, within this of the road's centreline...
	denseHalfWidth = 700, -- K, ...and inside this |x|
}

-- FOUR SPECIES AND NOTHING ELSE (Karen's list): oak, birch, black alder, spruce. `share` is the
-- fraction of the wood, `height` is the proxy's total height in studs -- which matches
-- docs/design/asset-pipeline.md section 12.1's `sizeStuds`, so a grey box teaches the truth about the
-- mesh that will replace it rather than a 22-stud lollipop (design section 7.1).
--
-- EVERY COLOUR IS ABOVE THE ALBEDO FLOOR. An unlit face renders at roughly 0.275 x albedo at this
-- place's ambient -- measured in Task 22, which turned RGB(90, 80, 70) into near-black -- so no
-- channel maximum here is below 120, spruce included.
--
-- EACH ROW CARRIES THE ASSET KEY IT ASKS FOR (audit-005 must-fix 2). Four species with four trunks
-- and four crowns are four meshes, so they are four keys: `Props.trees` fetches a template per
-- species and hands each tree its own, where it used to hand every tree one `treeSpruce` template
-- and discard the species. `Assets.KEY` holds the names; nothing else in the repo spells them.
Config.SPECIES = {
	{
		name = "spruce",
		assetKey = Assets.KEY.treeSpruce,
		share = 0.4, -- K
		height = 71,
		trunk = Vector3.new(3, 30, 3),
		crown = Vector3.new(14, 44, 14),
		trunkColor = Color3.fromRGB(78, 62, 46),
		crownColor = Color3.fromRGB(95, 132, 96), -- green: a spruce does not turn in autumn
	},
	{
		name = "birch",
		assetKey = Assets.KEY.treeBirch,
		share = 0.25, -- K
		height = 64,
		trunk = Vector3.new(2.5, 34, 2.5),
		crown = Vector3.new(18, 32, 18),
		trunkColor = Color3.fromRGB(225, 222, 210), -- the one white trunk, and it reads at 200 m
		crownColor = Color3.fromRGB(215, 180, 70), -- yellow
	},
	{
		name = "oak",
		assetKey = Assets.KEY.treeOak,
		share = 0.2, -- K
		height = 64,
		trunk = Vector3.new(5, 28, 5),
		crown = Vector3.new(32, 38, 32),
		trunkColor = Color3.fromRGB(96, 78, 58),
		crownColor = Color3.fromRGB(170, 105, 45), -- orange-brown
	},
	{
		name = "alder",
		assetKey = Assets.KEY.treeAlder,
		share = 0.15, -- K
		height = 57,
		trunk = Vector3.new(3, 26, 3),
		crown = Vector3.new(13, 30, 13),
		trunkColor = Color3.fromRGB(84, 72, 60),
		crownColor = Color3.fromRGB(140, 130, 60), -- dull yellow-green
	},
}

-- The species FIELD: a low-frequency noise band decides which species a patch of wood leans to, so
-- the drive crosses dark blocks of spruce and light stands of birch instead of a species salad.
Config.SPECIES_FREQUENCY = 1 / 260 -- K, clumps read at about 70 m
Config.SPECIES_CLUMP_STUDS = 260 -- K, the clump's block size; the noise above only wobbles its edges
-- How much of a clump is its leading species. The rest is drawn from the same shares, so a spruce
-- stand has birch in it and every species' MARGINAL share is still the number in the table above.
Config.SPECIES_CLUMP_STRENGTH = 0.65
-- ...except where it is wet. Black alder is a wet-ground tree, and a spruce in a bog reads as a
-- mistake, so the bog and the hollows force alder whatever the field says.
Config.SPECIES_WET_DEPTH = -6 -- ground below this is a hollow

-- BRUSH: cover for the EYE only (design section 7.4). CanCollide and CanQuery are both false, so a
-- bush never eats a slug and never stops a driver -- an invisible wall a shooter cannot see the
-- reason for is worse than no cover at all.
Config.BRUSH = {
	count = 500, -- K
	size = Vector3.new(10, 5, 10),
	color = Color3.fromRGB(122, 104, 64),
	sink = 1.5, -- studs of the box below the ground, so it sits in the litter rather than on it
}

-- ---------------------------------------------------------------- materials

-- Four materials and no Water: the design's section 1.2 rule. A bog is Mud, because water a player
-- can drown in is a different feature with its own rules.
-- THE FOUR ROLES, and they are named for what the PALETTE calls them (Map.PALETTE), because the two
-- tables have to agree about which material carries which colour.
--
-- M2.8a INVERTED THESE, and the screenshot is what caught it. Before this the default return was
-- `Grass` and the steep return was `LeafyGrass`, so the autumn palette painted the whole forest floor
-- with the olive "rough" colour and put the orange leaf litter on the steep rim -- a map that was
-- correctly generated, correctly digested, and read as a dry summer meadow. `map-wide` and
-- `map-autumn` showed it at once. Design section 8.1: litter is LeafyGrass and is "the forest floor
-- -- the wood's default"; rough is Grass and is "steep ground, clearings, the flank fields".
Config.MATERIAL = {
	litter = Enum.Material.LeafyGrass, -- the wood's default, recoloured to leaf litter
	rough = Enum.Material.Grass, -- steep ground, clearings and the flank fields
	track = Enum.Material.Ground, -- the road and assembly benches, and the dirt tracks
	bog = Enum.Material.Mud,
}

-- ---------------------------------------------------------------- props

Config.PROXY_COLOR = {
	tree = Color3.fromRGB(70, 95, 60),
	hedge = Color3.fromRGB(58, 78, 48),
	marker = Color3.fromRGB(255, 255, 255),
}
-- THE FALLBACK PROXY, for a tree with no species (the tie trees, which are placed on purpose
-- rather than scattered). The wood's own proxies come from Config.SPECIES.
Config.TREE_PROXY = {
	-- THE NAME EVERY TREE BUILT FROM THIS ROW CARRIES, as its `Species` attribute (Props.placeTree).
	-- It is deliberately NOT "spruce": a tie tree is the same shape as a spruce but it is not of the
	-- wood, and the built-wood spec asserts that every tree in `Props.Trees` is one of Karen's four --
	-- which a tie tree calling itself spruce would silently satisfy.
	name = "tieTree",
	assetKey = Assets.KEY.treeSpruce,
	trunk = Vector3.new(3, 30, 3),
	crown = Vector3.new(14, 44, 14),
	height = 71,
	trunkColor = Color3.fromRGB(78, 62, 46),
	crownColor = Color3.fromRGB(95, 132, 96),
}
-- How far a crown's underside may overlap its trunk's top, so a crown never floats: the crown is
-- centred to put its TOP at the species' height, and then pulled down if that would leave a gap.
Config.CROWN_MIN_OVERLAP = 2
Config.HEDGE = { segmentStuds = 24, size = Vector3.new(24, 7, 3) }

-- ---------------------------------------------------------------- the road's furniture (M2.8c)

-- THE NUMBERS FOR EVERYTHING THE ROAD CARRIES, in one table, because M2.8c is six small props and
-- six scattered tables would be six places to look. Design section 18's M2.8c row is the list:
-- stakes beside each post, a high seat as scenery near four of them, a barrier at each end of the
-- road, two log piles on the verge, a fence and a gate on a field boundary, reeds at the bog.
--
-- EVERY PIECE IS SCENERY AND NOTHING IN IT COLLIDES (`Props.furniture`). The contract walks the
-- whole road and fails the build for any collidable part within `Map.ROAD.halfWidth + verge` of the
-- centreline (`MapGen.verifyContract`, Task 58 round 1 finding 1) -- a rule that exists because a
-- hedge wall once stood across the gravel and reachability pathed around it. Rather than place some
-- pieces inside that envelope and some outside it and have to remember which, the whole layer is
-- non-collidable: a grey-box stake a shooter can walk through beats one that traps him on his stand,
-- and when the real meshes arrive somebody decides collision per mesh, once, on purpose.
Config.FURNITURE = {
	-- TWO STAKES FLANK EACH STAND, a step BEHIND the centreline (the drive is at +z), so nothing
	-- this task adds ever stands between a shooter and what he is shooting at. The orange cap is the
	-- part that has to read at 160 studs: TASKS.md row 58a(a) is that every marker is
	-- `Transparency = 1`, so a shot of the road could not answer its own question about the posts.
	stake = {
		offsetX = 5, -- studs either side of the post's centre
		offsetZ = -4, -- behind the centreline, on the far-wood side
		-- MEASURED, NOT GUESSED (rule 5). The first build made the stake 8 studs with a
		-- 1.2 x 1.5 cap, and the screenshot from the road showed one orange speck at 70 studs and
		-- almost nothing at 160 -- which is the distance the question is actually about. A 2.4-stud
		-- cube on a 9-stud stake reads as a clear orange mark at the next stand along.
		size = Vector3.new(0.6, 9, 0.6),
		capSize = Vector3.new(2.4, 2.4, 2.4),
		color = Color3.fromRGB(168, 146, 112), -- peeled softwood
		capColor = Color3.fromRGB(232, 108, 28), -- K, hunter orange: the same signal as the outfits
	},
	-- A HIGH SEAT AS SCENERY near four stands (design 18: "a proxy -- the shooter still stands on
	-- the road in v1"). 40 studs behind the road puts it past the verge, in the far wood, where a
	-- real one stands; `clearRadius` keeps the wood out of it.
	highSeat = {
		atPosts = { 2, 4, 6, 8 }, -- every other stand
		offsetZ = -40,
		legSpan = 5, -- centre-to-centre of the four legs
		legSize = Vector3.new(0.7, 15, 0.7),
		platform = Vector3.new(6.5, 0.8, 6.5),
		rail = Vector3.new(6.5, 3, 0.5), -- across the back, facing the drive
		roof = Vector3.new(7.5, 0.6, 7.5),
		clearRadius = 14, -- no tree inside this of a seat's centre (Layout.treeDensity)
		color = Color3.fromRGB(122, 96, 66),
		deckColor = Color3.fromRGB(146, 118, 84),
	},
	-- A BARRIER ACROSS EACH END OF THE ROAD. Inside `Map.ROAD.to`, on the flat bench, so it stands
	-- on gravel rather than among trunks -- and non-collidable like the rest of the layer.
	barrier = {
		inset = 10, -- studs inside each end of the road
		boom = Vector3.new(1.4, 1.1, 26), -- across the road: the long axis is z
		post = Vector3.new(0.9, 4.5, 0.9),
		postOffsetZ = 12,
		boomBase = 3,
		color = Color3.fromRGB(198, 196, 190),
		bandColor = Color3.fromRGB(232, 108, 28),
	},
	-- TWO LOG PILES ON THE VERGE, one each side, cut to length and stacked 3 + 2 as a forester
	-- stacks them at the roadside.
	logPile = {
		at = { { x = -300, side = -1 }, { x = 420, side = 1 } }, -- side: -1 far wood, +1 drive side
		-- LOOKED AT, THEN CHANGED (rule 5). At 30 studs off the centreline and 3.2 studs tall the
		-- first build's pile was a pale sliver in the shade 33 studs from the camera. 20 studs off
		-- is still inside the 32-stud verge -- which is why the layer does not collide -- and three
		-- rows of thicker logs is 6.6 studs of stack, which reads from the road.
		offsetZ = 20,
		log = Vector3.new(16, 2.2, 2.2),
		color = Color3.fromRGB(138, 112, 78),
		endColor = Color3.fromRGB(176, 152, 112),
	},
	-- A FENCE AND A GATE ON A FIELD BOUNDARY, in the eastern field, with the gate where the farm
	-- track (`WORLD.tracks`, x = 880) passes through it. Well outside the drive corridor
	-- (x <= 620), so it can never be something a boar or a driver has to get round.
	fence = {
		z = -100,
		fromX = 800,
		toX = 1000,
		spacing = 20,
		post = Vector3.new(0.8, 6, 0.8),
		rail = Vector3.new(20, 0.5, 0.35),
		railHeights = { 2.2, 4.2 }, -- centres above ground
		gateFromX = 860, -- the span left open for the track
		gateToX = 900,
		gate = Vector3.new(0.8, 5, 18), -- standing OPEN, swung back along +z on its hinge post
		color = Color3.fromRGB(128, 106, 78),
		gateColor = Color3.fromRGB(152, 134, 104),
	},
	-- REEDS AT THE BOG. A ring on the rim, sunk into the mud; `Layout.treeDensity` already keeps
	-- trees out of the bog itself, so these are what makes it read as wet rather than as a hole.
	reeds = {
		count = 32,
		inset = 12, -- the ring's mean radius is bog.radius - inset...
		jitter = 8, -- ...and each clump moves up to this, deterministically
		-- A CLUMP, not a blade: 1.4 studs thick was invisible against the mud at 100 studs.
		size = Vector3.new(3, 7, 3),
		sink = 1.5,
		color = Color3.fromRGB(152, 142, 96),
	},
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
