--!strict
-- Places: WHAT DRESSES A DRIVE PLACE, as arithmetic and nothing else.
--
-- Karen, 2026-10-15: *"make 4 hunting places where each time person will be in new place when is
-- hunter then loop it again"*, and *"be sure you do it properly not fake it or broken"*. Task 193.
--
-- WHERE THE SPLIT IS. `ForestTest` says WHERE THE LINE IS -- the stand positions, the corridor, the
-- boar field. This module says WHAT STANDS AROUND IT -- the strip down the middle and the forest
-- either side of it -- and it is PURE: no Instance, no service, no raycast, no `Workspace`. The
-- caller measures the world and plants; `src/server/Places` is the only thing that does.
--
-- That is task 199's own split, and `docs/research/2026-10-17-forest-trees-on-the-ground.md` says
-- why it is not one lump: when the arithmetic and the measuring were one, *"neither could be checked
-- alone"*, and the lobby's ground-fit was wrong for rounds at a time. Here it means
-- `tests/server/places.spec.luau` can assert where all ~3,000 trees go, and that not one of them is
-- in a shooting lane, with no Studio running at all.
--
-- THE PLAN IS A PURE FUNCTION OF (layout, seed). Same layout, same seed, same forest -- so a frame
-- Karen judges can be rebuilt from a commit, and a defect can be bisected.
--
-- Pattern: A JITTERED GRID WITH BRIDSON'S GRID NEIGHBOUR TEST, not his active list.
--   Robert Bridson, "Fast Poisson Disk Sampling in Arbitrary Dimensions", SIGGRAPH 2007
--   https://www.cs.ubc.ca/~rbridson/docs/bridson-siggraph07-poissondisk.pdf
--   Reference implementation: scipy.stats.qmc.PoissonDisk (BSD-3, maintained)
-- Bridson's background grid sized so each cell holds at most one sample is taken whole; his
-- active-list loop is not. We need the plan to be a pure function of a seed, the tree count bounded
-- before anything runs, and cell (i, j) to be the same tree every time so a spec can assert one --
-- none of which an unordered active-list set gives. The cost is a slightly more regular scatter than
-- true blue noise, which at `JITTER` 0.8 of a cell is not visible in a frame.
--
-- Pattern: THREE DEPTH BANDS PER EDGE, not one density. Gehlken, *Der "ideale Waldrand"* (Uni
-- Goettingen 2014) and the DVL practice booklet: a forest edge is a `Krautsaum` of 5-10 m, then a
-- `Strauchmantel` of 5-10 m, then the `Baummantel` of full trees.
--   https://www.uni-goettingen.de/de/document/download/9ef453bebe0d4d3d4b5fd07c1e814771.pdf/Gehlken%202014%20Waldrand.pdf
-- That one rule is what makes karen-ref-5's young pines in front of taller forest, karen-ref-6's
-- bramble wall beside the stand and karen-ref-1's young firs at the track ONE table with different
-- numbers, instead of three hand-placed rows.
--
-- THE STRIP IS A SUBTRACTION, NOT A SHAPE, AND THE SUBTRACTION IS GLOBAL. Nothing is planted within
-- `halfStripStuds + LANE_STUDS` of **any** place's line (`Places.clearOfEveryLane`). That is the one
-- rule that keeps the shooting lanes clear -- `places.spec` asserts it over every planting of every
-- place against every layout -- rather than a row of trees a later tweak could walk inward. It is
-- global because it had to be: the cut line's north belt reaches 684 studs and the forest road's line
-- is 600 studs away, so a per-place rule planted one place's wood through the other's track.
--
-- Design: docs/design/drive-places.md
-- Note:   docs/research/2026-10-17-four-driven-hunt-places.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Forest = require(ReplicatedStorage:WaitForChild("ForestTest"))
-- THE GRID (task 327c): the eight cells' geometry and their seeds. PURE data, one direction only
-- -- `Grid` requires neither this module nor `ForestTest`.
local Grid = require(ReplicatedStorage:WaitForChild("Grid"))

local Places = {}

-- ONE PLANTING: what to clone, where to put it, how big and which way round. In STUDS and RADIANS,
-- world space, and `y` is deliberately absent -- the ground is the one thing only the world can
-- answer, and inventing a y here is exactly the mistake `TreeGround` exists to stop.
export type Planting = {
	model: string, -- the template's name under the templates folder
	x: number,
	z: number,
	scale: number, -- `Model:ScaleTo`; 1 is the template's own size
	yaw: number, -- radians about Y
	band: string, -- "herb" | "shrub" | "wood" | "deep", for the report and the spec
	side: number, -- -1 south of the line, +1 north of it
}

-- HOW FAR BEYOND THE STRIP NOTHING IS PLANTED, on top of the strip's own half-width. The dispatch's
-- *"no trees in the shooting lanes"*: a hunter standing on the line shoots across it, so the clear
-- ground has to be wider than the strip he is standing on. 12 studs IS `ForestTest.PICK`'s own
-- `standRadiusStuds` -- the same number, not a rounding of it -- so the lane rule alone already
-- clears every stand circle, and `places.spec` asserts that identity rather than describing it.
Places.LANE_STUDS = 12

-- THE JITTER, as a fraction of the cell. 0 is a visible grid; 1 lets two neighbours touch. 0.8 is
-- the value the frames were judged at.
Places.JITTER = 0.8

-- THE SPECIES OF THIS WORLD, grouped by what they look like from a stand. Every name is a child of
-- `Workspace.OurForest` in Karen's Forest Test, counted there on 2026-10-17 (61 models, 4,819
-- instances). Nothing here invents a model: a name that is not in that folder plants nothing, which
-- is what makes the DEV place (where the folder does not exist at all) a silent no-op rather than a
-- crash.
Places.SPECIES = table.freeze({
	-- The dark, tall conifers. karen-ref-1's left-hand wall.
	conifer = table.freeze({
		"Old_Spruce_Tree_Var01_LOD_0",
		"Old_Spruce_Tree_Var02_LOD_0",
		"Old_Spruce_Tree_Var03_LOD_0",
		"Old_Spruce_Tree_Var04_LOD_0",
		"Old_Spruce_Tree_Var06_LOD_0",
		"Spruce_Tree_Var01_LOD_0",
		"Spruce_Tree_Var02_LOD_0",
	}),
	-- The larches: feathery, pine-shaped and the SMALLEST trees this world has (26-96 studs against
	-- the spruces' 56-156), which is why they are the young growth rather than a scaled spruce. A
	-- spruce at the scale a 3 m sapling needs is a 1-stud-thick trunk.
	young = table.freeze({
		"LarchTree_Var01",
		"LarchTree_Var02",
		"LarchTree_Var03",
		"LarchTree_Var04",
	}),
	-- White trunks in groups. karen-ref-3 is nothing else.
	birch = table.freeze({
		"SilverBirch_Var01_LOD_0",
		"SilverBirch_Var02_LOD_0",
		"SilverBirch_Var05_LOD_0",
		"SilverBirch_Var08_LOD_0",
		"SilverBirch_Var11_LOD_0",
		"SilverBirch_Var13_LOD_0",
		"SilverBirchTree_Var02",
		"SilverBirchTree_Var06",
	}),
	-- The broadleaves. `Forest_*` are the drawn-up forest form, `Field_*` the open-grown one, so the
	-- field edge gets the spreading ones and the deep wood the straight ones.
	oak = table.freeze({
		"Forest_OakTree_Var01_LOD_0",
		"Forest_OakTree_Var02_LOD_0",
		"Forest_OakTree_Var03_LOD_0",
	}),
	fieldOak = table.freeze({
		"Field_OakTree_Var04_LOD_0",
		"Field_OakTree_Var05_LOD_0",
		"Field_OakTree_Var06_LOD_0",
		"Field_OakTree_Var07_LOD_0",
	}),
	aspen = table.freeze({
		"SM_AspenTree_Var02",
		"SM_AspenTree_Var04",
		"SM_AspenTree_Var06",
		"SM_AspenTree_Var09",
	}),
	-- OUR BRACKEN. Karen's forest frames are floored in dry fern and leaf litter, and these ten
	-- models are the only thing in this world that is one.
	fern = table.freeze({
		"SM_Forest_Fern_Var01",
		"SM_Forest_Fern_Var03",
		"SM_Forest_Fern_Var05",
		"SM_Lady_Fern_Var02",
		"SM_Lady_Fern_Var04",
	}),
})

-- WHICH SPECIES, IN WHAT PROPORTION, PER BAND. Each row is a list of `{ group, weight }` and the
-- weights are read cumulatively, so a row is one `math.random` and not a chain of ifs.
--
-- THE MIXES ARE READ OFF KAREN'S FRAMES, named per place below, and they are DATA: changing what a
-- place looks like is changing numbers in this table, not code.
local function mix(...): { { group: string, weight: number } }
	local rows = {}
	for _, pair in ipairs({ ... }) do
		table.insert(rows, table.freeze({ group = pair[1] :: string, weight = pair[2] :: number }))
	end
	return table.freeze(rows) :: any
end

-- THE DRESSING OF EACH PLACE. One row per `ForestTest.LAYOUTS` name; a layout with no row here is
-- dressed with nothing, which is how `road` stays task 179's world untouched.
--
-- `halfStripStuds`      half the cleared strip the hunters stand on
-- `beltStuds`           how deep the planted wood runs beyond the lane, SOUTH of the line
-- `northBeltStuds`      the same, north of it. 0 means "plant nothing there"
-- `spacingStuds`        the grid cell in the full-density bands: one tree offered per cell
-- `deepSpacingStuds`    the coarse cell beyond `bands.woodStuds` (design 10.2)
-- `fernSpacing`         the cell for the floor
-- `minGapStuds`         no two trees closer than this (design 10.3)
-- `plotHalfWidthStuds`  how far either side of `centre.X` the ground was SURVEYED (design 10.5)
-- `bands`               { herbStuds, shrubStuds, woodStuds } measured OUTWARD from the lane edge
Places.PLANS = table.freeze({
	-- KAREN'S PLACE 2, karen-ref-6: a stand inside a hedge looking across a field at a far tree
	-- line. THE FAR FOREST IS THIS WORLD'S REAL WOOD (its southern face is at z -2900, measured
	-- straight across this whole stand span), and the FIELD is the 350 studs -- 98 m -- of open ground
	-- between.
	-- So this plan plants ONE side only: the hunters' own edge, behind and beside them.
	--
	-- `northBelt = 0` IS THE WHOLE POINT and not an omission: plant anything north of this line and
	-- the field stops being a field.
	edge = table.freeze({
		halfStripStuds = 30, -- the grass headland the guns stand on, 17 m across
		beltStuds = 190,
		northBeltStuds = 0,
		spacingStuds = 26,
		deepSpacingStuds = 60,
		fernSpacing = 26,
		-- 0.54 of the cell. `TreeGround.FLARE_FRACTION` 0.08 on an 85-stud aspen is a 13.6-stud
		-- flare, so two trunks 5 studs apart share a stump -- which is measured-correct and looks
		-- wrong, the exact class `PROJECT_CONTEXT.md` was written about.
		minGapStuds = 14,
		plotHalfWidthStuds = 410,
		-- `herbStuds` 10 AND NOT 36, AND A FRAME IS WHY. At 36 the first BUSH stood 78 studs (22 m)
		-- behind the gun and the stand read as a bare paddock; karen-ref-6 has bramble within arm's
		-- reach of the barrel. The `Krautsaum` is still there, it is just a fern skirt and not a
		-- twenty-metre lawn.
		bands = table.freeze({ herbStuds = 10, shrubStuds = 60, woodStuds = 190 }),
		-- A hedge is broadleaf scrub under open-grown oaks -- ref-6 exactly: bramble at eye height,
		-- one big oak canopy over the stand.
		herb = mix({ "fern", 1 }),
		shrub = mix({ "fieldOak", 5 }, { "aspen", 4 }, { "birch", 1 }),
		wood = mix({ "fieldOak", 5 }, { "aspen", 3 }, { "birch", 2 }),
		deep = mix({ "fieldOak", 5 }, { "aspen", 3 }, { "birch", 2 }),
		shrubScale = table.freeze({ 0.18, 0.30 }),
		woodScale = table.freeze({ 0.85, 1.15 }),
		seed = 1932,
	}),

	-- KAREN'S PLACE 3, karen-ref-5: a cut line. A 64-stud strip (18 m -- the 10-15 m practitioners
	-- prefer for a `Schussschneise`, at the generous end so a boar is shootable crossing it), forest
	-- BOTH sides, a band of young pines right at the edge and taller mixed wood behind.
	--
	-- THE FULL-DENSITY WOOD IS 230 STUDS DEEP because that is 64 m, and the frames show you see
	-- 40-60 m between trunks in high forest: past the sight line a tighter grid buys nothing.
	--
	-- BUT THE BELT ITSELF REACHES 640 STUDS, AND THAT IS A DEFECT THE ARCHITECT CAUGHT BEFORE IT
	-- SHIPPED (design 10.2). `beaterNorthStuds()` is 580, so the beaters muster at z -3920 -- and a
	-- 230-stud belt ends at -4226, which left them forming up in **306 studs of bare grass** that a
	-- hunter looks straight up the ride at. Worse, `REST.farRoadStuds` is 425 and `restSpot` only
	-- takes a spot within `nearTrunkStuds` (22) of something solid, so beyond the belt there was no
	-- legal resting wood at all. 640 is 580 + the same 60-stud run-out task 179 used elsewhere.
	-- Beyond `bands.woodStuds` the same wood mix is planted on `deepSpacingStuds` with no ferns.
	ride = table.freeze({
		halfStripStuds = 32,
		beltStuds = 230,
		northBeltStuds = 640,
		-- 20 AND NOT 30, AND IT WAS MEASURED TWICE. With 30 the belts stopped **19 of 105** rays
		-- fired from the stands at eye height over 300 studs, mean sight 280 -- i.e. a hunter looked
		-- straight through the wood at open hillside, which the frame confirmed. 20 is the close
		-- bands' cell; the deep band stays at 60, where nothing can see it.
		spacingStuds = 20,
		deepSpacingStuds = 60,
		fernSpacing = 24,
		minGapStuds = 11,
		plotHalfWidthStuds = 410,
		-- `herbStuds` 6 AND NOT 30, FOR THE SAME REASON: at 30 the nearest trunk to a stand measured
		-- **99 studs**, and karen-ref-5's young pines stand at the ride's own edge. The lane (44
		-- studs) already keeps the shooting ground clear; a thirty-stud herb strip on top of it just
		-- pushed the wood out of the picture.
		bands = table.freeze({ herbStuds = 6, shrubStuds = 60, woodStuds = 230 }),
		herb = mix({ "fern", 1 }),
		-- The young pine band ref-5 is a photograph of.
		shrub = mix({ "young", 8 }, { "birch", 2 }),
		wood = mix({ "conifer", 9 }, { "birch", 4 }, { "aspen", 4 }, { "oak", 3 }),
		-- THE DEEP BAND IS THE SAME WOOD, THINNER. Named rather than aliased so a band name always
		-- indexes a mix and `Places.layer` needs no special case.
		deep = mix({ "conifer", 9 }, { "birch", 4 }, { "aspen", 4 }, { "oak", 3 }),
		shrubScale = table.freeze({ 0.25, 0.45 }),
		woodScale = table.freeze({ 0.8, 1.2 }),
		seed = 1933,
	}),

	-- KAREN'S PLACE 4, karen-ref-1: a narrow dirt double track, forest CLOSE. An 18-stud strip (5 m,
	-- the generous end of a `Rueckegasse`'s 3-4 m) and the belt starting right at it, so young firs
	-- stand at the wheel ruts. Spruce and birch, which is what the frame holds.
	--
	-- `LANE_STUDS` STILL APPLIES, so the clear ground is 9 + 12 = 21 studs either side of the centre
	-- line and the first trunk is 21 studs out. That is close enough that the canopy closes over the
	-- track and far enough that a hunter has a shot across it.
	track = table.freeze({
		halfStripStuds = 9,
		beltStuds = 230,
		northBeltStuds = 640,
		spacingStuds = 18,
		deepSpacingStuds = 60,
		fernSpacing = 22,
		minGapStuds = 10,
		plotHalfWidthStuds = 410,
		-- 4 STUDS OF HERB, which is as close to "forest at the wheel ruts" as the lane allows:
		-- karen-ref-1 has young firs touching the track. The first trunk is 21 + 4 = 25 studs (7 m)
		-- from the centre line.
		bands = table.freeze({ herbStuds = 4, shrubStuds = 50, woodStuds = 230 }),
		herb = mix({ "fern", 1 }),
		shrub = mix({ "young", 9 }, { "birch", 1 }),
		wood = mix({ "conifer", 10 }, { "birch", 6 }, { "aspen", 2 }, { "oak", 2 }),
		deep = mix({ "conifer", 10 }, { "birch", 6 }, { "aspen", 2 }, { "oak", 2 }),
		shrubScale = table.freeze({ 0.22, 0.40 }),
		woodScale = table.freeze({ 0.8, 1.2 }),
		seed = 1934,
	}),
})

-- WHAT EACH PLACE'S STRIP IS MADE OF. **A SEPARATE TABLE FROM `PLANS`, and the Director's look is
-- why.** Painting and planting are different questions: `road` keeps task 179's wood exactly (BRIEF
-- decision 3) and so has no planting plan at all, but it is still the place NAMED for a road and its
-- surface is half missing -- measured 2026-10-17 along its own line, 65 samples: `Ground` 31,
-- **`Grass` 29**, Asphalt 3, Limestone 1, Mud 1, with the grass at stands 1, 2, 7, 8 and 9. A hunter
-- on five of its nine stands is standing in a field.
--
-- `halfWidthStuds`      half the painted strip
-- `material`            what the strip becomes
-- `ruts`                optional: two narrow strips either side of the centre line
-- `plotHalfWidthStuds`  how far either side of `centre.X` to paint (the surveyed plot, as `PLANS`)
Places.SURFACES = table.freeze({
	-- KAREN'S PLACE 1, karen-ref-7: a pale gravel forest road curving away between mossy verges.
	-- **`Ground` AND NOT A GREY GRAVEL**, because 31 of its 65 samples ALREADY are `Ground` -- that
	-- is the road Karen built, and painting the other 29 to match it finishes her road rather than
	-- laying a second one over it. Its geometry is untouched (BRIEF decision 3): this paints the
	-- surface and plants nothing.
	road = table.freeze({
		halfWidthStuds = 11,
		material = Enum.Material.Ground,
		plotHalfWidthStuds = 800,
	}),

	-- KAREN'S PLACE 3, karen-ref-5: a GRASSY ride with two darker wheel ruts of bare earth and taller
	-- dry grass at its edges. The Director, 2026-10-17, on the first build's frame: *"the hunter
	-- stands on GREY ASPHALT-LOOKING ground"* -- measured, 13 of this strip's 42 samples are Asphalt.
	-- So the ride is painted `Grass` and the ruts `Mud`.
	ride = table.freeze({
		halfWidthStuds = 32,
		material = Enum.Material.Grass,
		-- NARROW AND WELL APART, because the first paint's ruts filled the near view and the frame
		-- read grey again. 4 studs is the thinnest a rut can be: a terrain voxel is 4 studs, so
		-- anything finer snaps back to this -- and `Ground.bandBounds` is what makes 4 mean 4 whatever
		-- this line's z parity is (the Reviewer measured these at EIGHT studs before that existed).
		-- At +-12 the grass between them is 20 studs, which is what karen-ref-5 shows: grass with two
		-- darker lines in it, not two lines with grass in them.
		ruts = table.freeze({ offsetStuds = 12, halfWidthStuds = 2, material = Enum.Material.Mud }),
		plotHalfWidthStuds = 410,
	}),

	-- KAREN'S PLACE 4, karen-ref-1: a narrow DIRT track under BROWN LEAVES, two ruts, leaf litter
	-- between and beside. **23 of its 42 samples were Asphalt** -- more than half the track read grey.
	-- `Ground` is the brownest thing the engine gives us without touching `Terrain.MaterialColors`,
	-- which is GLOBAL and would recolour the lodge's lawn and the whole existing wood with it.
	track = table.freeze({
		halfWidthStuds = 9,
		material = Enum.Material.Ground,
		-- +-6 AND NOT +-4: measured after the first paint, a 4-stud offset snapped to the voxel grid and
		-- the two ruts MERGED -- the whole 18-stud track came back Mud, with no litter between them. At
		-- +-6 the middle 8 studs stay `Ground`, which is ref-1's leaf litter between two wheel tracks.
		ruts = table.freeze({ offsetStuds = 6, halfWidthStuds = 2, material = Enum.Material.Mud }),
		plotHalfWidthStuds = 410,
	}),
})

-- ---------------------------------------------------------------- the grid's cells (task 327c)

-- THE NAMED MIXES A CELL'S ZONES DRAW FROM. Karen, 2026-11-01: *"one big terrain where is different
-- trees growing in different section, mixed"* -- so the SECTION is what names a mix, and two sections
-- either side of one road must not read the same.
-- Pattern: character-then-recipe per region (Red Blob Games, "Making maps with noise functions",
-- design 12D). Every group is a key of `Places.SPECIES`; `grid.spec` case 12 asserts that.
Places.CELL_MIXES = table.freeze({
	spruceThicket = mix({ "conifer", 8 }, { "young", 2 }),
	spruceHigh = mix({ "conifer", 9 }, { "birch", 1 }),
	mixedWood = mix({ "conifer", 4 }, { "birch", 3 }, { "aspen", 2 }, { "oak", 2 }),
	birchStand = mix({ "birch", 8 }, { "aspen", 2 }),
	birchOpen = mix({ "birch", 6 }, { "fieldOak", 2 }, { "young", 1 }),
	oakWood = mix({ "oak", 6 }, { "birch", 2 }, { "aspen", 2 }),
	oakPark = mix({ "fieldOak", 7 }, { "birch", 2 }),
	larchYoung = mix({ "young", 8 }, { "birch", 2 }),
	aspenWood = mix({ "aspen", 6 }, { "birch", 3 }, { "oak", 1 }),
	scrub = mix({ "young", 5 }, { "birch", 3 }, { "fieldOak", 2 }),
	-- THE FLOOR OF A CELL, hugging its four roads: `Places.PLANS`' own `herb` row, under a name,
	-- because a cell's zones index a mix by name and its floor must index one too.
	fernFloor = mix({ "fern", 1 }),
	-- A CLEARING IS AN EMPTY MIX AND NOT A MISSING ONE, so a zone always names a mix that exists and
	-- `grid.spec` can assert the pair as one fact: an empty mix has `spacingStuds` 0, and spacing 0
	-- has an empty mix. Nothing is ever drawn from it.
	clearing = mix(),
})

-- ONE ZONE of a cell: a rectangle in CELL-RELATIVE FRACTIONS (design 4.5), so a zone row is
-- independent of the cell's size and survives a `Grid.CONFIG` change to it. `at` is
-- { x0, z0, x1, z1 } with 0 at the cell's min corner.
export type Zone = {
	at: { number },
	mix: string,
	spacingStuds: number, -- 0 = no trees at all
	band: string, -- "wood" | "shrub": which of the plan's two scale bands this zone's trees take
}

-- A HELPER SO A RECIPE READS AS A TILING AND NOT AS PUNCTUATION. The eight recipes below are its
-- only callers.
local function zone(x0: number, z0: number, x1: number, z1: number, spacing: number, name: string, band: string): Zone
	return table.freeze({
		at = table.freeze({ x0, z0, x1, z1 }),
		mix = name,
		spacingStuds = spacing,
		band = band,
	}) :: any
end

-- HOW FAR INSIDE ITS OWN EDGE A CELL PLANTS. The lane rule measures `<=` (`Places.inLane`), so a
-- candidate landing exactly on the cell's edge reads as IN the road's clear width -- a cell's
-- interior starts exactly `roadClearStuds / 2` from each road's centre line. Three studs is clear of
-- that and costs 0.6 % of the cell's area.
Places.CELL_EDGE_STUDS = 3

-- THE RANDOM STREAMS, one per layer, hashed through `Grid.seedFor` -- so the trees, the floor and the
-- skirt cannot shift each other, and NO stream is a counter (design 4.6: a cell's wood is the same
-- whatever order the cells were built in).
Places.CELL_STREAM = table.freeze({ trees = 1, ferns = 2, skirt = 3 })

-- THE EIGHT RECIPES, one per cell, keyed by the name `Grid.CELLS[i].recipe` carries.
--
-- WHAT A ROW CARRIES THAT `Places.PLANS` DOES NOT, and why the band record is gone: a line place is
-- dressed in DEPTH BANDS measured out from one road, and a cell is dressed in ZONES over an area
-- bounded by four. `bands` / `beltStuds` / `northBeltStuds` / `plotHalfWidthStuds` have no meaning
-- over a rectangle, so they are not carried; `zones` replaces them, and the SURVEYED plot is the cell
-- itself (task 327a re-measured this block at 20 studs: 33,750/33,750 terrain hits, 0 parts inside).
-- Everything else is the same field under the same name: `halfStripStuds`, `spacingStuds`,
-- `deepSpacingStuds`, `fernSpacing`, `minGapStuds`, the two scale bands and `seed`.
--
-- `halfStripStuds` IS 9 AND THAT IS ONE FACT WITH THE ROAD, not a second number: `laneHalfWidth`
-- (9 + `LANE_STUDS` 12) is 21, which is `Grid.CONFIG.roadClearStuds / 2` exactly, so `Places.inLane`
-- and the grid's own road geometry answer the same question. `grid.spec` case 15 asserts the identity
-- and then asks the question BOTH ways.
--
-- THE TREE COUNT OF EACH ROW IS DERIVED AND WAS CHECKED BEFORE IT WAS WRITTEN (lesson L-167), as
-- `sum(zone area / spacing^2)` over a 1070 x 1430 cell: A1 1667, B1 1562, C1 1511, D1 1268, A2 1475,
-- B2 1640, C2 1552, D2 1191 -- against design 8.3's target of ~1,500 for the active cell's own wood.
-- The spread is deliberate (an open birch wood IS thinner than a spruce thicket), and the actual
-- planted number is lower again by the `minGapStuds` drops, which is why the census MEASURES it.
--
-- ONE DESIGN NUMBER IS WRONG AND IS NOT BUILT TO (lesson L-167): design 8.3's skirt row says "worst
-- case (4 neighbours)". **In a 2 x 4 grid no cell has four neighbours** -- the grid has no third row,
-- so a corner cell has 2 and B1/C1/B2/C2 have 3. The worst skirt here is C1's 565 trees against the
-- design's 650, so the BOUND is not breached; the arithmetic behind it is.
Places.CELL_PLANS = table.freeze({
	-- A1, measured `slope`, 113.4 studs of spread: the thicket is on the LOW ground by the main road
	-- and the wood thins uphill, so the hunter looks into cover and the beaters walk out of light.
	-- Strips across the fall line, which is what a slope reads as from the road.
	spruceSlope = table.freeze({
		halfStripStuds = 9,
		spacingStuds = 26,
		deepSpacingStuds = 60,
		fernSpacing = 24,
		fernBandStuds = 30,
		minGapStuds = 12,
		skirtFullStuds = 80,
		skirtStuds = 230,
		shrubScale = table.freeze({ 0.25, 0.45 }),
		woodScale = table.freeze({ 0.8, 1.2 }),
		seed = 3271,
		zones = table.freeze({
			zone(0.00, 0.00, 1.00, 0.30, 24, "spruceThicket", "wood"),
			zone(0.00, 0.30, 1.00, 0.55, 30, "mixedWood", "wood"),
			zone(0.20, 0.55, 0.80, 0.74, 0, "clearing", "wood"),
			zone(0.00, 0.55, 0.20, 0.74, 34, "spruceHigh", "wood"),
			zone(0.80, 0.55, 1.00, 0.74, 34, "spruceHigh", "wood"),
			zone(0.00, 0.74, 1.00, 1.00, 34, "spruceHigh", "wood"),
		}),
	}),

	-- B1, measured `slope`, 103.0 studs: white trunks, and one wide clearing off centre so the
	-- crossings funnel west of it. The regrowth strip at the back is the beaters' own ground.
	birchSlope = table.freeze({
		halfStripStuds = 9,
		spacingStuds = 30,
		deepSpacingStuds = 60,
		fernSpacing = 24,
		fernBandStuds = 30,
		minGapStuds = 12,
		skirtFullStuds = 80,
		skirtStuds = 230,
		shrubScale = table.freeze({ 0.25, 0.45 }),
		woodScale = table.freeze({ 0.8, 1.2 }),
		seed = 3272,
		zones = table.freeze({
			zone(0.00, 0.00, 0.55, 0.40, 30, "birchStand", "wood"),
			zone(0.55, 0.00, 1.00, 0.40, 24, "spruceThicket", "wood"),
			zone(0.00, 0.40, 1.00, 0.62, 38, "birchOpen", "wood"),
			zone(0.30, 0.62, 0.95, 0.85, 0, "clearing", "wood"),
			zone(0.00, 0.62, 0.30, 0.85, 30, "birchStand", "wood"),
			zone(0.95, 0.62, 1.00, 0.85, 30, "birchStand", "wood"),
			zone(0.00, 0.85, 1.00, 1.00, 26, "scrub", "shrub"),
		}),
	}),

	-- C1, measured `rolling`, 61.7 studs -- the gentlest cell, and the one `Grid.PREVIEW_CELL` shows.
	-- SEVEN ZONES AND FOUR DIFFERENT WOODS, because it is the cell Karen looks into first: a thicket
	-- at her left shoulder, mixed wood ahead, an oak park to the east where the sight lines open, and
	-- a clearing two thirds in with scrub either side of it.
	mixedRolling = table.freeze({
		halfStripStuds = 9,
		spacingStuds = 28,
		deepSpacingStuds = 60,
		fernSpacing = 24,
		fernBandStuds = 30,
		minGapStuds = 12,
		skirtFullStuds = 80,
		skirtStuds = 230,
		shrubScale = table.freeze({ 0.25, 0.45 }),
		woodScale = table.freeze({ 0.8, 1.2 }),
		seed = 3273,
		zones = table.freeze({
			zone(0.00, 0.00, 0.40, 0.35, 24, "spruceThicket", "wood"),
			zone(0.40, 0.00, 1.00, 0.35, 32, "mixedWood", "wood"),
			zone(0.00, 0.35, 0.60, 0.70, 30, "birchStand", "wood"),
			zone(0.60, 0.35, 1.00, 0.70, 44, "oakPark", "wood"),
			zone(0.15, 0.70, 0.65, 1.00, 0, "clearing", "wood"),
			zone(0.00, 0.70, 0.15, 1.00, 24, "scrub", "shrub"),
			zone(0.65, 0.70, 1.00, 1.00, 26, "scrub", "shrub"),
		}),
	}),

	-- D1, measured `rolling`, 63.5 studs but 36.8 along the line: open-grown oak over a park-like
	-- east half, so this is the cell a hunter can actually see across -- the thinnest wood of row 1.
	oakRolling = table.freeze({
		halfStripStuds = 9,
		spacingStuds = 32,
		deepSpacingStuds = 60,
		fernSpacing = 24,
		fernBandStuds = 30,
		minGapStuds = 12,
		skirtFullStuds = 80,
		skirtStuds = 230,
		shrubScale = table.freeze({ 0.25, 0.45 }),
		woodScale = table.freeze({ 0.8, 1.2 }),
		seed = 3274,
		zones = table.freeze({
			zone(0.00, 0.00, 1.00, 0.22, 34, "oakPark", "wood"),
			zone(0.00, 0.22, 0.50, 0.60, 28, "oakWood", "wood"),
			zone(0.50, 0.22, 1.00, 0.60, 44, "oakPark", "wood"),
			zone(0.00, 0.60, 0.45, 1.00, 32, "mixedWood", "wood"),
			zone(0.45, 0.60, 1.00, 0.80, 0, "clearing", "wood"),
			zone(0.45, 0.80, 1.00, 1.00, 30, "birchOpen", "wood"),
		}),
	}),

	-- A2, measured `rolling`, 97.7 studs with 42.2 along the line: a larch plantation. The SMALLEST
	-- trees this world has (`Places.SPECIES.young`: 26-96 studs against the spruces' 56-156), so this
	-- is the cell where a hunter sees over the wood and a boar is in view the whole way.
	larchRolling = table.freeze({
		halfStripStuds = 9,
		spacingStuds = 28,
		deepSpacingStuds = 60,
		fernSpacing = 24,
		fernBandStuds = 30,
		minGapStuds = 12,
		skirtFullStuds = 80,
		skirtStuds = 230,
		shrubScale = table.freeze({ 0.30, 0.55 }),
		woodScale = table.freeze({ 0.8, 1.2 }),
		seed = 3275,
		zones = table.freeze({
			zone(0.00, 0.00, 1.00, 0.26, 26, "larchYoung", "shrub"),
			zone(0.00, 0.26, 0.35, 0.65, 28, "larchYoung", "shrub"),
			zone(0.35, 0.26, 1.00, 0.65, 38, "mixedWood", "wood"),
			zone(0.00, 0.65, 1.00, 0.82, 0, "clearing", "wood"),
			zone(0.00, 0.82, 1.00, 1.00, 28, "scrub", "shrub"),
		}),
	}),

	-- B2, measured `slope`, 129.9 studs and 61.3 along the line -- the steepest line in the world.
	-- FOUR ZONES, THE FEWEST, and one clearing band straight across the middle: on ground that falls
	-- 61 studs under the stands the relief IS the variety, and a quilt of small zones would not read.
	aspenSlope = table.freeze({
		halfStripStuds = 9,
		spacingStuds = 30,
		deepSpacingStuds = 60,
		fernSpacing = 24,
		fernBandStuds = 30,
		minGapStuds = 12,
		skirtFullStuds = 80,
		skirtStuds = 230,
		shrubScale = table.freeze({ 0.25, 0.45 }),
		woodScale = table.freeze({ 0.8, 1.2 }),
		seed = 3276,
		zones = table.freeze({
			zone(0.00, 0.00, 1.00, 0.34, 28, "aspenWood", "wood"),
			zone(0.00, 0.34, 1.00, 0.52, 0, "clearing", "wood"),
			zone(0.00, 0.52, 0.65, 1.00, 30, "aspenWood", "wood"),
			zone(0.65, 0.52, 1.00, 1.00, 24, "spruceThicket", "wood"),
		}),
	}),

	-- C2, measured `rolling`, 142.7 studs: dark conifer either side of a lighter middle, so the
	-- crossings read against the thickets and not against the sky.
	spruceRolling = table.freeze({
		halfStripStuds = 9,
		spacingStuds = 30,
		deepSpacingStuds = 60,
		fernSpacing = 24,
		fernBandStuds = 30,
		minGapStuds = 12,
		skirtFullStuds = 80,
		skirtStuds = 230,
		shrubScale = table.freeze({ 0.25, 0.45 }),
		woodScale = table.freeze({ 0.8, 1.2 }),
		seed = 3277,
		zones = table.freeze({
			zone(0.00, 0.00, 0.30, 0.45, 26, "spruceThicket", "wood"),
			zone(0.30, 0.00, 0.70, 0.45, 34, "birchOpen", "wood"),
			zone(0.70, 0.00, 1.00, 0.45, 26, "spruceThicket", "wood"),
			zone(0.25, 0.45, 0.75, 0.68, 0, "clearing", "wood"),
			zone(0.00, 0.45, 0.25, 0.68, 28, "spruceHigh", "wood"),
			zone(0.75, 0.45, 1.00, 0.68, 28, "spruceHigh", "wood"),
			zone(0.00, 0.68, 1.00, 1.00, 32, "mixedWood", "wood"),
		}),
	}),

	-- D2, measured `rolling`, 173.0 studs -- the most broken ground in the world, and the thinnest
	-- wood on it (1191 trees): an open birch stand with a wide oak park through the middle, where
	-- what a hunter reads is the hollows and not the trunks.
	birchRolling = table.freeze({
		halfStripStuds = 9,
		spacingStuds = 34,
		deepSpacingStuds = 60,
		fernSpacing = 24,
		fernBandStuds = 30,
		minGapStuds = 12,
		skirtFullStuds = 80,
		skirtStuds = 230,
		shrubScale = table.freeze({ 0.25, 0.45 }),
		woodScale = table.freeze({ 0.8, 1.2 }),
		seed = 3278,
		zones = table.freeze({
			zone(0.00, 0.00, 1.00, 0.28, 30, "birchStand", "wood"),
			zone(0.00, 0.28, 1.00, 0.50, 44, "oakPark", "wood"),
			zone(0.10, 0.50, 0.60, 0.74, 0, "clearing", "wood"),
			zone(0.00, 0.50, 0.10, 0.74, 28, "birchStand", "wood"),
			zone(0.60, 0.50, 1.00, 0.74, 28, "birchStand", "wood"),
			zone(0.00, 0.74, 1.00, 1.00, 36, "birchOpen", "wood"),
		}),
	}),
})

-- THE SURFACE FOR A LAYOUT, OR NIL. Nil is a place whose ground is left as the world made it --
-- `edge`, because its field is grass and painting it `Ground` would make a ploughed field, which is a
-- different place from karen-ref-6.
function Places.surfaceFor(layoutName: string?): any
	if type(layoutName) ~= "string" then
		return nil
	end
	return (Places.SURFACES :: any)[layoutName]
end

-- THE PLAN FOR A LAYOUT, OR NIL. Nil is a layout this task does not dress -- `road`, which stays
-- task 179's world number for number (BRIEF decision 3).
function Places.planFor(layoutName: string?): any
	if type(layoutName) ~= "string" then
		return nil
	end
	return (Places.PLANS :: any)[layoutName]
end

-- IS THIS POINT IN THE CLEARED STRIP (or its lane)? PURE, and the ONE definition -- both the planner
-- and the spec ask this function, so "no tree in a shooting lane" is one rule and not two.
--
-- IT MEASURES AGAINST THE LINE'S OWN z AT THAT x, so a curved layout gets a curved strip for free.
function Places.inLane(x: number, z: number, layout: any, plan: any): boolean
	local lineZ = Forest.roadZ(x, layout)
	return math.abs(z - lineZ) <= Places.laneHalfWidth(plan)
end

-- HOW WIDE A LAYOUT'S CLEARED GROUND IS, either side of its line. A layout with no dressing plan --
-- `road` -- still has one: its stands are 12-stud circles on its line, so `LANE_STUDS` alone is the
-- ground that must stay clear there.
function Places.laneHalfWidth(plan: any): number
	return (if plan ~= nil then plan.halfStripStuds else 0) + Places.LANE_STUDS
end

-- IS THIS POINT CLEAR OF **EVERY** PLACE'S LANE? THE RULE IS GLOBAL SINCE ROUND 3, and the Reviewer
-- is who found out why (round 2, finding 1).
--
-- WHAT WENT WRONG. `layer` asked `inLane` about its OWN layout only. Task 179 had the places 3,300
-- studs apart in x so that was harmless; claim 2 of round 1 re-sited them for sight lines and put the
-- cut line 600 studs south of the forest road -- and the cut line's north belt reaches 684 studs, so
-- it planted **through the forest road's track and across five of its six stands**. The code's own
-- comment called the shared wood a feature (*"one continuous wood"*) and nobody checked it against
-- the other place's lane.
--
-- WHY THIS AND NOT A GAP BETWEEN THE PLACES. The Reviewer put the conflict exactly: at these two
-- centres *"the belt reaches the beaters' muster"* and *"no tree in the track's lane"* cannot both
-- hold -- IF the belt has to be unbroken. It does not. A cleared corridor through the wood **is what
-- a forest road is**: the cut line's north belt now reaches its full 640 studs with a 42-stud gap
-- where the forest road's track crosses it, which is the one shape that keeps both properties and is
-- also the more honest landscape. Moving a line instead would throw away the sight-line measurement
-- that put it there, and no scored candidate pair is far enough apart to avoid the overlap.
--
-- IT IS ASKED AT THE JITTERED POINT, like `inLane`, because the jitter is what walks a candidate into
-- a lane.
function Places.clearOfEveryLane(x: number, z: number): boolean
	for _, name in ipairs(Forest.LAYOUT_ORDER) do
		local layout = Forest.layoutNamed(name)
		if layout ~= nil then
			if math.abs(z - Forest.roadZ(x, layout)) <= Places.laneHalfWidth(Places.planFor(name)) then
				return false
			end
		end
	end
	return true
end

-- WHICH BAND A POINT IS IN, by its distance from the LANE EDGE (not from the line): "herb", "shrub"
-- or "wood". Nil inside the lane, where nothing is planted.
function Places.bandAt(distanceStuds: number, plan: any): string?
	if distanceStuds <= 0 then
		return nil
	end
	if distanceStuds <= plan.bands.herbStuds then
		return "herb"
	end
	if distanceStuds <= plan.bands.shrubStuds then
		return "shrub"
	end
	if distanceStuds <= plan.bands.woodStuds then
		return "wood"
	end
	-- THE FOURTH BAND (design 10.2): the same wood mix on a coarser grid, out to the belt's far edge,
	-- which is what carries the north belt the 640 studs to where the beaters muster.
	return "deep"
end

-- ONE DRAW FROM A MIX. `roll` is a number in [0, 1).
function Places.speciesFrom(rows: any, roll: number): string
	local total = 0
	for _, row in ipairs(rows) do
		total += row.weight
	end
	local want = math.clamp(roll, 0, 0.999999) * total
	local seen = 0
	for _, row in ipairs(rows) do
		seen += row.weight
		if want < seen then
			return row.group
		end
	end
	return rows[#rows].group
end

-- THE GROUND THAT WAS SURVEYED, as an x range (design 10.5). The BRIEF measured an 820-stud plot
-- about each place's `centre.X` and the terrain sweep of M4 stopped at x 4600, so planting out to
-- `span + beltStuds` reached up to 145 studs past ground nobody looked at. It is not a crash --
-- `plantOne` answers "no-ground" and counts it -- it is a CLAIM problem: "every tree is on the
-- ground" must not be asserted over ground that was never measured.
function Places.plotOf(layout: any, plan: any): { minX: number, maxX: number }
	local half = plan.plotHalfWidthStuds
	return { minX = layout.centre.X - half, maxX = layout.centre.X + half }
end

-- HOW WIDE THE PLANTED GROUND IS: the stands' span plus a belt's worth of run-out either end, CLAMPED
-- to the surveyed plot. The run-out exists so the wood does not stop square with the end stand -- a
-- forest that ends in a straight line across the view is what reads as a stage set.
function Places.widthOf(layout: any, plan: any): (number, number)
	local span = Forest.standSpan(layout)
	local plot = Places.plotOf(layout, plan)
	return math.max(span.minX - plan.beltStuds, plot.minX), math.min(span.maxX + plan.beltStuds, plot.maxX)
end

-- THE WHOLE PLANTING LIST FOR ONE PLACE. PURE: `Random.new(seed)` is seeded from the plan, so the
-- same (layout, plan) pair answers the same list every time, in the same order.
--
-- THE GRID IS LAID IN WORLD x AND z, not along the line, so two adjacent layouts could never
-- interleave their cells; and the cell count is known before the loop runs, which is what bounds the
-- tree count (`Places.capacity`).
function Places.plant(layout: any, plan: any): { Planting }
	local out: { Planting } = {}
	if layout == nil or plan == nil then
		return out
	end
	local rng = Random.new(plan.seed)
	local minX, maxX = Places.widthOf(layout, plan)
	for _, item in ipairs(Places.layer(layout, plan, rng, minX, maxX, false)) do
		table.insert(out, item)
	end
	for _, item in ipairs(Places.layer(layout, plan, rng, minX, maxX, true)) do
		table.insert(out, item)
	end
	return out
end

-- THE NEIGHBOUR TEST, AND IT IS BRIDSON'S AND NOT A SWEEP (design 10.3). A hash of occupied cells at
-- `gap` resolution, and a candidate is compared against the NINE cells around it -- which is enough
-- because nothing outside them can be within `gap`, and it is O(1) rather than O(n). Without it two
-- trees in adjacent cells could land 5 studs apart while a trunk flare is up to 13.6 studs across,
-- i.e. two trunks in one stump.
--
-- EACH CELL KEEPS A LIST AND NOT ONE POINT, and the harness is what taught that: with one point per
-- cell at this resolution Bridson's invariant does NOT hold -- a cell of side `gap` can legally hold
-- two points `gap * sqrt(2)` apart, so storing one FORGETS the other and a third candidate can land
-- inside the forgotten one. `places.spec` keeps every point in its own grid and caught it
-- (`places.spec:311`, 2026-10-17). Bridson's own cell is `r / sqrt(n)`; keeping the list is the same
-- guarantee without a second magic number.
local function tooClose(grid: any, x: number, z: number, gap: number): boolean
	local cx, cz = math.floor(x / gap), math.floor(z / gap)
	for dx = -1, 1 do
		for dz = -1, 1 do
			for _, other in ipairs(grid[(cx + dx) .. ":" .. (cz + dz)] or {}) do
				local ddx, ddz = other.x - x, other.z - z
				if ddx * ddx + ddz * ddz < gap * gap then
					return true
				end
			end
		end
	end
	local key = cx .. ":" .. cz
	grid[key] = grid[key] or {}
	table.insert(grid[key], { x = x, z = z })
	return false
end

-- ONE LAYER OF THE GRID -- the trees, or the floor. Split out because the two want different cell
-- sizes over the same ground, and because a spec can then drive one without the other.
--
-- THE TREE LAYER WALKS THE BANDS, EACH WITH ITS OWN CELL. `herb` holds no trees at all (it is the
-- `Krautsaum`), `shrub` and `wood` are the full-density grid, and `deep` -- everything past
-- `bands.woodStuds` out to the belt's far edge -- is the same wood mix on `deepSpacingStuds`. That is
-- what carries the north belt the 640 studs to where the beaters muster without paying for 640 studs
-- of full-density forest (design 10.2).
function Places.layer(layout: any, plan: any, rng: Random, minX: number, maxX: number, floor: boolean): { Planting }
	local out: { Planting } = {}
	local lane = plan.halfStripStuds + Places.LANE_STUDS
	local grid = {}
	-- THE FLOOR IS ONE BAND OVER THE FULL-DENSITY DEPTH; the deep band has no ferns, because nothing
	-- can see the floor three hundred studs into a wood.
	local bands = if floor
		then { { from = 0, to = plan.bands.woodStuds, spacing = plan.fernSpacing } }
		else {
			{ from = plan.bands.herbStuds, to = plan.bands.shrubStuds, spacing = plan.spacingStuds },
			{ from = plan.bands.shrubStuds, to = plan.bands.woodStuds, spacing = plan.spacingStuds },
			{ from = plan.bands.woodStuds, to = math.huge, spacing = plan.deepSpacingStuds },
		}
	local gap = if floor then 0.5 * plan.fernSpacing else plan.minGapStuds
	for _, side in ipairs({ -1, 1 }) do
		local depth = if side > 0 then plan.northBeltStuds else plan.beltStuds
		for _, band in ipairs(bands) do
			local to = math.min(band.to, depth)
			if band.from < to then
				local spacing = band.spacing
				for x = minX, maxX, spacing do
					local from = band.from
					while from < to do
						local jx = x + (rng:NextNumber() - 0.5) * spacing * Places.JITTER
						local jz = from + rng:NextNumber() * spacing * Places.JITTER
						local z = Forest.roadZ(x, layout) + side * (lane + jz)
						from += spacing
						-- THE SUBTRACTION, re-asked at the JITTERED point and not at the cell's centre --
						-- the only version that is true, because the jitter is what could have walked it
						-- into the lane. On a curved layout the jittered x has its own line z, so this
						-- re-asks that too.
						-- EVERY PLACE'S LANE, not just this one (round 2, finding 1).
						if jx >= minX and jx <= maxX and Places.clearOfEveryLane(jx, z) then
							local reach = math.abs(z - Forest.roadZ(jx, layout)) - lane
							local into = if floor then "herb" else Places.bandAt(reach, plan)
							if into ~= nil and reach > 0 and not tooClose(grid, jx, z, gap) then
								local group = Places.speciesFrom((plan :: any)[into], rng:NextNumber())
								local names = (Places.SPECIES :: any)[group]
								local scale
								if floor then
									scale = 0.8 + rng:NextNumber() * 0.9
								elseif into == "shrub" then
									scale = plan.shrubScale[1]
										+ rng:NextNumber() * (plan.shrubScale[2] - plan.shrubScale[1])
								else
									scale = plan.woodScale[1]
										+ rng:NextNumber() * (plan.woodScale[2] - plan.woodScale[1])
								end
								table.insert(out, {
									model = names[rng:NextInteger(1, #names)],
									x = jx,
									z = z,
									scale = scale,
									yaw = rng:NextNumber() * math.pi * 2,
									band = into,
									side = side,
								})
							end
						end
					end
				end
			end
		end
	end
	return out
end

-- ---------------------------------------------------------------- a cell's wood (task 327c)

-- THE RECIPE A CELL IS DRESSED WITH, or nil for a name nobody knows -- `planFor`'s own discipline, so
-- a typo gets no wood rather than the wrong wood.
function Places.cellPlanFor(cellId: string?): any
	local cell = Grid.cellOf(cellId)
	if cell == nil then
		return nil
	end
	return (Places.CELL_PLANS :: any)[cell.recipe]
end

-- THE MIX A ZONE DRAWS FROM. Nil for a name no mix carries, which `grid.spec` case 12 proves cannot
-- happen for any shipped zone.
function Places.cellMixNamed(name: string?): any
	if type(name) ~= "string" then
		return nil
	end
	return (Places.CELL_MIXES :: any)[name]
end

-- THE CELL'S PLANTABLE GROUND: its interior, inset by `CELL_EDGE_STUDS` so a jittered candidate can
-- never land in a road's clear width (see that constant).
function Places.cellGround(cellId: string): { minX: number, maxX: number, minZ: number, maxZ: number }
	local box = Grid.boundsOf(cellId)
	local inset = Places.CELL_EDGE_STUDS
	return {
		minX = box.minX + inset,
		maxX = box.maxX - inset,
		minZ = box.minZ + inset,
		maxZ = box.maxZ - inset,
	}
end

-- ONE ZONE AS A WORLD RECTANGLE. The fractions are of the cell's INSET ground, so the zones still
-- tile it exactly and the inset is taken off the outside and never out of a zone boundary.
function Places.zoneRect(cellId: string, z: any): { minX: number, maxX: number, minZ: number, maxZ: number }
	local ground = Places.cellGround(cellId)
	local width = ground.maxX - ground.minX
	local depth = ground.maxZ - ground.minZ
	return {
		minX = ground.minX + z.at[1] * width,
		minZ = ground.minZ + z.at[2] * depth,
		maxX = ground.minX + z.at[3] * width,
		maxZ = ground.minZ + z.at[4] * depth,
	}
end

-- WHICH ZONE A WORLD POINT IS IN, or nil outside the cell's ground and in a gap no zone covers. The
-- SKIRT asks this of the NEIGHBOUR cell, which is how the wood across a road is that cell's own wood
-- and not the active cell's -- Karen's *"different trees growing in different section"* (design 8.2).
function Places.zoneAt(cellId: string, x: number, z: number): any
	local plan = Places.cellPlanFor(cellId)
	if plan == nil then
		return nil
	end
	for _, item in ipairs(plan.zones) do
		local rect = Places.zoneRect(cellId, item)
		if x >= rect.minX and x <= rect.maxX and z >= rect.minZ and z <= rect.maxZ then
			return item
		end
	end
	return nil
end

-- EVERY ROAD, ONCE. `Grid.roads()` hands back fresh tables on purpose (nothing can mutate the
-- world's shape through them), and this module asks the question per candidate -- about 3,000 times a
-- cell -- so the list is read once and never written.
local ROADS: { any }? = nil
local function allRoads(): { any }
	if ROADS == nil then
		ROADS = Grid.roads()
	end
	return ROADS :: { any }
end

-- IS THIS POINT CLEAR OF EVERY GRID ROAD'S CLEAR WIDTH? The cell rule, and the ONE definition -- the
-- planner and `grid.spec` case 15 both ask this function.
--
-- IT IS NOT `clearOfEveryLane`, AND THE REASON IS THAT FUNCTION'S OWN GEOMETRY: a layout's line is a
-- `roadZ(x)` defined for every x, so `ride`'s line at z -4540 would cut a 42-stud bare stripe across
-- the whole grid footprint 5,000 studs west of where that place actually is. The four line places and
-- the eight cells are two worlds (design 11.3), only one of them is ever live, and task 327d retires
-- the first.
function Places.clearOfEveryRoad(x: number, z: number): boolean
	local half = Grid.CONFIG.roadClearStuds / 2
	for _, road in ipairs(allRoads()) do
		if road.axis == "x" then
			if math.abs(z - road.at) <= half and x >= road.from and x <= road.to then
				return false
			end
		elseif math.abs(x - road.at) <= half and z >= road.from and z <= road.to then
			return false
		end
	end
	return true
end

-- THE CELLS THAT SHARE A ROAD WITH THIS ONE, in `Grid.CELL_ORDER`, with the axis of the road between
-- them ("x" is an east-west road, so the shared frontage is the cell's WIDTH; "z" its depth).
--
-- IN `CELL_ORDER` AND NOT IN A COMPASS ORDER, because the skirt's random stream walks this list: a
-- fixed order is what makes a cell's skirt the same list every time (design 4.6).
function Places.neighboursOf(cellId: string): { { id: string, axis: string } }
	local cell = Grid.cellOf(cellId)
	local out: { { id: string, axis: string } } = {}
	if cell == nil then
		return out
	end
	for _, id in ipairs(Grid.cellIds()) do
		local other = Grid.cellOf(id)
		if other ~= nil and id ~= cellId then
			if other.row == cell.row and math.abs(other.column - cell.column) == 1 then
				table.insert(out, { id = id, axis = "z" })
			elseif other.column == cell.column and math.abs(other.row - cell.row) == 1 then
				table.insert(out, { id = id, axis = "x" })
			end
		end
	end
	return out
end

-- THE SKIRT'S BANDS INSIDE ONE NEIGHBOUR, measured from the SHARED ROAD inward (design 8.2): the
-- first `skirtFullStuds` at the ACTIVE cell's own spacing, then out to `skirtStuds` at
-- `deepSpacingStuds`. A hunter on the main line looks 21 studs across the road into the next cell, so
-- without this he is looking at bare grass.
function Places.skirtBands(cellId: string, other: string, axis: string, plan: any): { any }
	local mine = Grid.boundsOf(cellId)
	local theirs = Places.cellGround(other)
	local out: { any } = {}
	-- WHICH WAY IS INWARD: from the shared road, into the neighbour, away from this cell.
	local from, sign
	if axis == "z" then
		-- an east-west step: the shared road is a north-south one, so the band runs in x.
		sign = if theirs.minX > mine.maxX then 1 else -1
		from = if sign > 0 then theirs.minX else theirs.maxX
	else
		sign = if theirs.minZ > mine.maxZ then 1 else -1
		from = if sign > 0 then theirs.minZ else theirs.maxZ
	end
	for _, band in ipairs({
		{ near = 0, far = plan.skirtFullStuds, spacing = plan.spacingStuds },
		{ near = plan.skirtFullStuds, far = plan.skirtStuds, spacing = plan.deepSpacingStuds },
	}) do
		local a = from + sign * band.near
		local b = from + sign * band.far
		local rect
		if axis == "z" then
			rect = {
				minX = math.max(theirs.minX, math.min(a, b)),
				maxX = math.min(theirs.maxX, math.max(a, b)),
				minZ = theirs.minZ,
				maxZ = theirs.maxZ,
			}
		else
			rect = {
				minX = theirs.minX,
				maxX = theirs.maxX,
				minZ = math.max(theirs.minZ, math.min(a, b)),
				maxZ = math.min(theirs.maxZ, math.max(a, b)),
			}
		end
		if rect.maxX > rect.minX and rect.maxZ > rect.minZ then
			table.insert(out, { rect = rect, spacing = band.spacing, deep = band.near > 0 })
		end
	end
	return out
end

-- THE FOUR FERN BANDS, hugging the cell's own edges from the inside -- design 8.2's `Krautsaum`
-- applied to a rectangle instead of to a line. Four rectangles and not one ring, so the corners are
-- covered once each and the spec can add their areas up.
function Places.fernBands(cellId: string, plan: any): { any }
	local g = Places.cellGround(cellId)
	local w = plan.fernBandStuds
	local inner = { minX = g.minX + w, maxX = g.maxX - w, minZ = g.minZ + w, maxZ = g.maxZ - w }
	return {
		{ minX = g.minX, maxX = g.maxX, minZ = g.minZ, maxZ = g.minZ + w },
		{ minX = g.minX, maxX = g.maxX, minZ = g.maxZ - w, maxZ = g.maxZ },
		{ minX = g.minX, maxX = g.minX + w, minZ = inner.minZ, maxZ = inner.maxZ },
		{ minX = g.maxX - w, maxX = g.maxX, minZ = inner.minZ, maxZ = inner.maxZ },
	}
end

-- THE SCALE FOR ONE ZONE'S BAND. `shrub` is this world's young growth (`LarchTree_*` at 0.25-0.55 of
-- the template), `wood` a full tree.
local function scaleFor(plan: any, band: string, rng: Random): number
	if band == "shrub" then
		return plan.shrubScale[1] + rng:NextNumber() * (plan.shrubScale[2] - plan.shrubScale[1])
	end
	return plan.woodScale[1] + rng:NextNumber() * (plan.woodScale[2] - plan.woodScale[1])
end

-- ONE JITTERED GRID OVER ONE RECTANGLE. The same arithmetic `Places.layer` uses on a band, lifted so
-- a zone, a fern band and a skirt band are three callers of one loop rather than three copies of it.
--
-- `pick` ANSWERS (mix, band) FOR A POINT or nil to plant nothing there, which is how a clearing on the
-- far side of a road stays a clearing: the skirt asks the NEIGHBOUR's zones.
local function scatter(
	out: { Planting },
	rect: any,
	spacing: number,
	grid: any,
	gap: number,
	rng: Random,
	plan: any,
	side: number,
	pick: (number, number) -> (any, string?)
)
	if spacing <= 0 then
		return
	end
	for x = rect.minX, rect.maxX, spacing do
		local z = rect.minZ
		while z < rect.maxZ do
			local jx = x + (rng:NextNumber() - 0.5) * spacing * Places.JITTER
			local jz = z + rng:NextNumber() * spacing * Places.JITTER
			z += spacing
			if
				jx >= rect.minX
				and jx <= rect.maxX
				and jz >= rect.minZ
				and jz <= rect.maxZ
				and Places.clearOfEveryRoad(jx, jz)
			then
				local rows, band = pick(jx, jz)
				if rows ~= nil and band ~= nil and #rows > 0 and not tooClose(grid, jx, jz, gap) then
					local group = Places.speciesFrom(rows, rng:NextNumber())
					local names = (Places.SPECIES :: any)[group]
					table.insert(out, {
						model = names[rng:NextInteger(1, #names)],
						x = jx,
						z = jz,
						scale = if band == "herb" then 0.8 + rng:NextNumber() * 0.9 else scaleFor(plan, band, rng),
						yaw = rng:NextNumber() * math.pi * 2,
						band = band,
						side = side,
					})
				end
			end
		end
	end
end

-- THE WHOLE PLANTING LIST FOR ONE CELL: its zones, its fern bands, and a skirt into every neighbour.
-- PURE -- no Instance, no terrain, no `Workspace`, and no `y`.
--
-- A PURE FUNCTION OF THE CELL ID AND NOTHING ELSE. Every stream is `Grid.seedFor(id, stream)`, which
-- hashes `(CONFIG.seed, row, column, stream)` and never a counter, so planting B1 before A1 gives A1
-- exactly the list planting A1 first gives it (`grid.spec` case 13). That is Minecraft's own per-chunk
-- rule, and `drive-places.md` section 10.1 is where this project learned why it matters.
function Places.plantCell(cellId: string): { Planting }
	local out: { Planting } = {}
	local plan = Places.cellPlanFor(cellId)
	if plan == nil then
		return out
	end
	-- ONE NEIGHBOUR GRID FOR EVERY TREE, cell and skirt alike: two trees on opposite sides of a road
	-- are 42 studs apart and can never be within `minGapStuds`, but one hash costs nothing and means
	-- the gap rule has no seam in it.
	local trees = {}
	local rng = Random.new(Grid.seedFor(cellId, Places.CELL_STREAM.trees))
	for _, item in ipairs(plan.zones) do
		local rect = Places.zoneRect(cellId, item)
		local rows = Places.cellMixNamed(item.mix)
		scatter(out, rect, item.spacingStuds, trees, plan.minGapStuds, rng, plan, 1, function()
			return rows, item.band
		end)
	end
	-- THE FLOOR, on its own stream and its own neighbour grid (`Places.layer`'s own discipline: a fern
	-- under a tree is right, two ferns in one spot is not).
	local floor = {}
	local fernRng = Random.new(Grid.seedFor(cellId, Places.CELL_STREAM.ferns))
	local fernRows = Places.cellMixNamed("fernFloor")
	for _, rect in ipairs(Places.fernBands(cellId, plan)) do
		scatter(out, rect, plan.fernSpacing, floor, 0.5 * plan.fernSpacing, fernRng, plan, 1, function()
			return fernRows, "herb"
		end)
	end
	-- THE SKIRT, into every neighbour, at THIS cell's density and the NEIGHBOUR's own species.
	local skirtRng = Random.new(Grid.seedFor(cellId, Places.CELL_STREAM.skirt))
	for _, near in ipairs(Places.neighboursOf(cellId)) do
		for _, band in ipairs(Places.skirtBands(cellId, near.id, near.axis, plan)) do
			scatter(out, band.rect, band.spacing, trees, plan.minGapStuds, skirtRng, plan, -1, function(x, z)
				local zoneThere = Places.zoneAt(near.id, x, z)
				if zoneThere == nil then
					return nil, nil
				end
				return Places.cellMixNamed(zoneThere.mix), zoneThere.band
			end)
		end
	end
	return out
end

-- THE UPPER BOUND ON WHAT ONE CELL PLANTS, known before anything runs: every grid's cell count, with
-- nothing subtracted for the lane rule or the gap rule. Design 8.3's hard bound is 3,600 models a
-- drive and `grid.spec` case 14 asserts BOTH halves -- `#plantCell(id) <= this` and `this < 3600`.
function Places.cellCapacity(cellId: string): number
	local plan = Places.cellPlanFor(cellId)
	if plan == nil then
		return 0
	end
	local function cells(rect: any, spacing: number): number
		if spacing <= 0 then
			return 0
		end
		return (math.floor((rect.maxX - rect.minX) / spacing) + 1) * (math.floor((rect.maxZ - rect.minZ) / spacing) + 1)
	end
	local total = 0
	for _, item in ipairs(plan.zones) do
		total += cells(Places.zoneRect(cellId, item), item.spacingStuds)
	end
	for _, rect in ipairs(Places.fernBands(cellId, plan)) do
		total += cells(rect, plan.fernSpacing)
	end
	for _, near in ipairs(Places.neighboursOf(cellId)) do
		for _, band in ipairs(Places.skirtBands(cellId, near.id, near.axis, plan)) do
			total += cells(band.rect, band.spacing)
		end
	end
	return total
end

-- THE UPPER BOUND ON WHAT A PLACE PLANTS, known before anything is cloned. A number that can be
-- asserted is what stops a density tweak quietly becoming a 20,000-part world. It counts the deep
-- band at its own coarser cell (design 10.2) over the SURVEYED width (design 10.5).
function Places.capacity(layout: any, plan: any): number
	if layout == nil or plan == nil then
		return 0
	end
	-- A CELL IS BOUNDED BY FOUR ROADS AND A LINE PLACE BY ONE, so the two bounds are different
	-- arithmetic -- but they answer the same question and callers ask it under one name. The PLAN is
	-- what says which: only a cell recipe carries `zones` (task 327c).
	if plan.zones ~= nil then
		return Places.cellCapacity(layout.name)
	end
	local minX, maxX = Places.widthOf(layout, plan)
	local width = maxX - minX
	local total = 0
	for _, side in ipairs({ -1, 1 }) do
		local depth = if side > 0 then plan.northBeltStuds else plan.beltStuds
		local close = math.max(0, math.min(plan.bands.woodStuds, depth) - plan.bands.herbStuds)
		local deep = math.max(0, depth - plan.bands.woodStuds)
		local floorDepth = math.min(plan.bands.woodStuds, depth)
		total += (math.floor(width / plan.spacingStuds) + 1) * (math.ceil(close / plan.spacingStuds) + 2)
		total += (math.floor(width / plan.deepSpacingStuds) + 1) * (math.ceil(deep / plan.deepSpacingStuds) + 2)
		total += (math.floor(width / plan.fernSpacing) + 1) * (math.ceil(floorDepth / plan.fernSpacing) + 2)
	end
	return total
end

return Places
