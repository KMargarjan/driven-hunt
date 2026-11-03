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
-- WHERE A TREE MEETS THE GROUND (task 199). PURE arithmetic, no Instance: this module reads
-- `CLIFF_STUDS` and `samples` from it so the planter and the census share ONE rule (design 9.1).
local TreeGround = require(ReplicatedStorage:WaitForChild("TreeGround"))

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

-- WHICH GROUPS ARE GROUND COVER AND NOT TREES. A fern is wider than it is tall, so the template
-- audit's "the trunk's longest extent must be Y" rule is a TREE's rule (design 9.3) -- MEASURED on
-- all five fern templates on 2026-11-02: 2.2-3.1 studs tall against 8.2-9.6 studs wide.
Places.HERB_GROUPS = table.freeze({ fern = true })

-- IS THIS MODEL NAME GROUND COVER? Asked of the NAME, because that is all a planted clone carries.
function Places.isHerbName(name: string): boolean
	for group, herb in pairs(Places.HERB_GROUPS) do
		if herb then
			for _, candidate in ipairs((Places.SPECIES :: any)[group]) do
				if candidate == name then
					return true
				end
			end
		end
	end
	return false
end

-- THE NAMES A GROUP MAY PLANT: its `SPECIES` row, MINUS anything quarantined. The ONE door between
-- the species table and a planting list, so a quarantined template cannot be planted by any caller
-- (design 9.3: *listed and never planted*).
local PLANTABLE: { [string]: { string } } = {}
function Places.namesOf(group: string): { string }
	local cached = PLANTABLE[group]
	if cached ~= nil then
		return cached
	end
	local names = (Places.SPECIES :: any)[group]
	if names == nil then
		return {}
	end
	local out: { string } = {}
	for _, name in ipairs(names) do
		if not Places.isQuarantined(name) then
			table.insert(out, name)
		end
	end
	PLANTABLE[group] = out
	return out
end

-- FORGET THE MEMO. `QUARANTINE` is frozen data, so nothing in the game ever needs this -- it exists
-- so `grid_ground.spec` can make a name quarantined and watch the door shut, which an empty
-- quarantine cannot otherwise prove (round 1, finding 1). `Places.junctionGap`'s own reason.
function Places.forgetPlantable()
	PLANTABLE = {}
	-- AND THE MASK'S PER-CELL GEOMETRY with it, for the same reason: a spec that stubs a cell plan
	-- must see the new one. Defined further down, so it is looked up at call time.
	Places.forgetCells()
end

-- EVERY PLANTED TEMPLATE'S REFERENCE DIMENSIONS -- **GENERATED, NOT TYPED**: re-measured in Karen's
-- Forest Test on 2026-11-03 by `python tools/forest_ground.py dims --write` (read-only without the
-- flag, Edit mode), one row per name in `Places.SPECIES` (35 of 35 found in `Workspace.OurForest`).
-- Design 9.2 named that tool; task 328l wrote it, so this table is no longer a hand-copied paste.
--
-- EACH ROW IS THE **MEDIAN-SCALE INSTANCE** OF THAT NAME, and that is the whole correction task 328l
-- made. `OurForest` is the WOOD: every name has 16 to 125 instances whose own scales span x1.65 to
-- x1.84, so `FindFirstChild(name)` answered an arbitrary tree and 27 of the 35 rows described a
-- different one than the day before (`live / row` 0.589 to 1.371). `Places.nearestScale` now finds
-- the row's instance by its scale, `Places.rescaledReason` refuses one more than 2 % off it, and
-- `live / row` is 1.000 for all 35 (`driven-hunt-runs/328l-dims-AFTER.txt`).
--
-- `item.scale` IS RELATIVE TO THAT SCALE: `plantOne` scales with `made:ScaleTo(made:GetScale() *
-- item.scale)`, so a reference "at scale 1" would fail the audit on everything. 30 of these 35 stand
-- at a scale that is not 1 (the birches at 0.039-0.046, the larches at 1.6-1.9); the ferns are the
-- only 1.0, and all 1,326 of them are exactly 1.0.
--
-- WHAT INVALIDATES THEM: a re-import or a re-scale of the wood. The guard is the boot-time audit --
-- more than 2 % off the row's scale, or 15 % off its extents, and the name is quarantined with the
-- reason on the boot's face (`report.quarantinedBy`).
--
-- `foliageDropStuds` IS HOW FAR THE CROWN HANGS BELOW THE TRUNK BOX'S FOOT, 0 for 30 of the 35. It
-- is what `TreeGround.sinkFor` leaves room for, and it is measured per CLONE at plant time; the row
-- is the reference the quarantine decision is argued from.
--
-- `crownHalfWidthStuds` IS THE UNION OF THE FOLIAGE-NAMED PARTS, half-extent, the larger of X and Z
-- -- `Places.isFoliageName` below, which `places.spec` already asserts matches no trunk name. The
-- five ferns have NO foliage-named part (one `MeshPart` each), so their crown reads 0: a herb has no
-- crown to hang over a road.
Places.TEMPLATE_DIMS = table.freeze({
	-- conifer
	Old_Spruce_Tree_Var01_LOD_0 = table.freeze({
		scale = 0.3786,
		heightStuds = 69.8,
		trunkHalfWidthStuds = 5.92,
		crownHalfWidthStuds = 13.99,
		foliageDropStuds = 0.00,
		parts = 3,
	}),
	Old_Spruce_Tree_Var02_LOD_0 = table.freeze({
		scale = 0.3775,
		heightStuds = 76.8,
		trunkHalfWidthStuds = 9.05,
		crownHalfWidthStuds = 14.54,
		foliageDropStuds = 0.00,
		parts = 3,
	}),
	Old_Spruce_Tree_Var03_LOD_0 = table.freeze({
		scale = 0.3448,
		heightStuds = 99.6,
		trunkHalfWidthStuds = 8.13,
		crownHalfWidthStuds = 17.67,
		foliageDropStuds = 0.00,
		parts = 3,
	}),
	Old_Spruce_Tree_Var04_LOD_0 = table.freeze({
		scale = 0.3773,
		heightStuds = 122.9,
		trunkHalfWidthStuds = 9.68,
		crownHalfWidthStuds = 22.80,
		foliageDropStuds = 0.00,
		parts = 3,
	}),
	Old_Spruce_Tree_Var06_LOD_0 = table.freeze({
		scale = 0.3410,
		heightStuds = 53.9,
		trunkHalfWidthStuds = 4.69,
		crownHalfWidthStuds = 11.37,
		foliageDropStuds = 0.00,
		parts = 3,
	}),
	Spruce_Tree_Var01_LOD_0 = table.freeze({
		scale = 0.3829,
		heightStuds = 59.1,
		trunkHalfWidthStuds = 2.55,
		crownHalfWidthStuds = 13.24,
		foliageDropStuds = 0.00,
		parts = 2,
	}),
	Spruce_Tree_Var02_LOD_0 = table.freeze({
		scale = 0.3934,
		heightStuds = 50.0,
		trunkHalfWidthStuds = 3.42,
		crownHalfWidthStuds = 14.09,
		foliageDropStuds = 0.00,
		parts = 3,
	}),
	-- young
	LarchTree_Var01 = table.freeze({
		scale = 1.9361,
		heightStuds = 38.3,
		trunkHalfWidthStuds = 7.25,
		crownHalfWidthStuds = 9.26,
		foliageDropStuds = 0.00,
		parts = 3,
	}),
	LarchTree_Var02 = table.freeze({
		scale = 1.8193,
		heightStuds = 32.3,
		trunkHalfWidthStuds = 7.95,
		crownHalfWidthStuds = 10.13,
		foliageDropStuds = 0.10,
		parts = 3,
	}),
	LarchTree_Var03 = table.freeze({
		scale = 1.8472,
		heightStuds = 35.8,
		trunkHalfWidthStuds = 8.91,
		crownHalfWidthStuds = 11.78,
		foliageDropStuds = 0.00,
		parts = 3,
	}),
	LarchTree_Var04 = table.freeze({
		scale = 1.5623,
		heightStuds = 58.4,
		trunkHalfWidthStuds = 10.40,
		crownHalfWidthStuds = 15.21,
		foliageDropStuds = 0.00,
		parts = 3,
	}),
	-- birch
	SilverBirch_Var01_LOD_0 = table.freeze({
		scale = 0.0394,
		heightStuds = 46.5,
		trunkHalfWidthStuds = 1.19,
		crownHalfWidthStuds = 12.33,
		foliageDropStuds = 0.00,
		parts = 3,
	}),
	SilverBirch_Var02_LOD_0 = table.freeze({
		scale = 0.0459,
		heightStuds = 62.2,
		trunkHalfWidthStuds = 0.70,
		crownHalfWidthStuds = 9.69,
		foliageDropStuds = 0.00,
		parts = 3,
	}),
	SilverBirch_Var05_LOD_0 = table.freeze({
		scale = 0.0425,
		heightStuds = 53.4,
		trunkHalfWidthStuds = 8.52,
		crownHalfWidthStuds = 14.42,
		foliageDropStuds = 0.00,
		parts = 3,
	}),
	SilverBirch_Var08_LOD_0 = table.freeze({
		scale = 0.0439,
		heightStuds = 43.0,
		trunkHalfWidthStuds = 8.10,
		crownHalfWidthStuds = 14.30,
		foliageDropStuds = 0.00,
		parts = 3,
	}),
	SilverBirch_Var11_LOD_0 = table.freeze({
		scale = 0.0435,
		heightStuds = 74.7,
		trunkHalfWidthStuds = 2.55,
		crownHalfWidthStuds = 16.41,
		foliageDropStuds = 0.00,
		parts = 4,
	}),
	SilverBirch_Var13_LOD_0 = table.freeze({
		scale = 0.0407,
		heightStuds = 85.3,
		trunkHalfWidthStuds = 3.27,
		crownHalfWidthStuds = 18.46,
		foliageDropStuds = 0.00,
		parts = 4,
	}),
	SilverBirchTree_Var02 = table.freeze({
		scale = 0.3497,
		heightStuds = 62.3,
		trunkHalfWidthStuds = 1.38,
		crownHalfWidthStuds = 19.47,
		foliageDropStuds = 0.00,
		parts = 5,
	}),
	SilverBirchTree_Var06 = table.freeze({
		scale = 0.3552,
		heightStuds = 95.8,
		trunkHalfWidthStuds = 1.35,
		crownHalfWidthStuds = 18.11,
		foliageDropStuds = 0.00,
		parts = 4,
	}),
	-- oak
	Forest_OakTree_Var01_LOD_0 = table.freeze({
		scale = 0.2176,
		heightStuds = 78.4,
		trunkHalfWidthStuds = 1.99,
		crownHalfWidthStuds = 21.35,
		foliageDropStuds = 0.00,
		parts = 3,
	}),
	Forest_OakTree_Var02_LOD_0 = table.freeze({
		scale = 0.2203,
		heightStuds = 80.1,
		trunkHalfWidthStuds = 1.41,
		crownHalfWidthStuds = 23.13,
		foliageDropStuds = 0.00,
		parts = 3,
	}),
	Forest_OakTree_Var03_LOD_0 = table.freeze({
		scale = 0.2035,
		heightStuds = 70.6,
		trunkHalfWidthStuds = 1.39,
		crownHalfWidthStuds = 14.16,
		foliageDropStuds = 0.00,
		parts = 3,
	}),
	-- fieldOak
	Field_OakTree_Var04_LOD_0 = table.freeze({
		scale = 0.2084,
		heightStuds = 47.6,
		trunkHalfWidthStuds = 11.93,
		crownHalfWidthStuds = 18.27,
		foliageDropStuds = 1.35,
		parts = 3,
	}),
	Field_OakTree_Var05_LOD_0 = table.freeze({
		scale = 0.2015,
		heightStuds = 61.1,
		trunkHalfWidthStuds = 15.29,
		crownHalfWidthStuds = 21.05,
		foliageDropStuds = 1.68,
		parts = 3,
	}),
	Field_OakTree_Var06_LOD_0 = table.freeze({
		scale = 0.2077,
		heightStuds = 53.9,
		trunkHalfWidthStuds = 9.60,
		crownHalfWidthStuds = 15.25,
		foliageDropStuds = 0.37,
		parts = 3,
	}),
	Field_OakTree_Var07_LOD_0 = table.freeze({
		scale = 0.2114,
		heightStuds = 49.4,
		trunkHalfWidthStuds = 11.29,
		crownHalfWidthStuds = 20.51,
		foliageDropStuds = 1.30,
		parts = 3,
	}),
	-- aspen
	SM_AspenTree_Var02 = table.freeze({
		scale = 0.6791,
		heightStuds = 73.1,
		trunkHalfWidthStuds = 1.66,
		crownHalfWidthStuds = 20.56,
		foliageDropStuds = 0.00,
		parts = 3,
	}),
	SM_AspenTree_Var04 = table.freeze({
		scale = 0.6642,
		heightStuds = 69.0,
		trunkHalfWidthStuds = 7.58,
		crownHalfWidthStuds = 16.42,
		foliageDropStuds = 0.00,
		parts = 3,
	}),
	SM_AspenTree_Var06 = table.freeze({
		scale = 0.6299,
		heightStuds = 74.8,
		trunkHalfWidthStuds = 1.11,
		crownHalfWidthStuds = 14.63,
		foliageDropStuds = 0.00,
		parts = 3,
	}),
	SM_AspenTree_Var09 = table.freeze({
		scale = 0.6444,
		heightStuds = 74.5,
		trunkHalfWidthStuds = 2.04,
		crownHalfWidthStuds = 16.64,
		foliageDropStuds = 0.00,
		parts = 3,
	}),
	-- fern
	SM_Forest_Fern_Var01 = table.freeze({
		scale = 1.0000,
		heightStuds = 2.2,
		trunkHalfWidthStuds = 4.80,
		crownHalfWidthStuds = 0.00,
		foliageDropStuds = 0.00,
		parts = 1,
	}),
	SM_Forest_Fern_Var03 = table.freeze({
		scale = 1.0000,
		heightStuds = 2.6,
		trunkHalfWidthStuds = 4.92,
		crownHalfWidthStuds = 0.00,
		foliageDropStuds = 0.00,
		parts = 1,
	}),
	SM_Forest_Fern_Var05 = table.freeze({
		scale = 1.0000,
		heightStuds = 2.8,
		trunkHalfWidthStuds = 4.09,
		crownHalfWidthStuds = 0.00,
		foliageDropStuds = 0.00,
		parts = 1,
	}),
	SM_Lady_Fern_Var02 = table.freeze({
		scale = 1.0000,
		heightStuds = 2.8,
		trunkHalfWidthStuds = 3.62,
		crownHalfWidthStuds = 0.00,
		foliageDropStuds = 0.00,
		parts = 1,
	}),
	SM_Lady_Fern_Var04 = table.freeze({
		scale = 1.0000,
		heightStuds = 3.1,
		trunkHalfWidthStuds = 3.48,
		crownHalfWidthStuds = 0.00,
		foliageDropStuds = 0.00,
		parts = 1,
	}),
})

-- THE REFERENCE ROW FOR A MODEL NAME, or nil for anything this world does not plant.
function Places.dimsFor(name: string): any?
	return (Places.TEMPLATE_DIMS :: any)[name]
end

-- THE TEMPLATES THE AUDIT REFUSED, with the reason, and they are NEVER PLANTED (design 9.3).
--
-- IT IS EMPTY, AND THAT IS A MEASUREMENT RATHER THAN AN OMISSION: run over all 35 templates on
-- 2026-11-02, every one passed -- the trunk's longest extent is Y on all 30 trees, the worst trunk
-- tilt is 0.2 degrees (`LarchTree_Var04`), no model has a detached foliage part, and the five ferns
-- are exempt from the axis rule by `HERB_GROUPS` above. The run-time audit in
-- `ServerScriptService.Places` is what keeps it that way, and `grid_ground.spec` proves each arm of
-- it bites with a synthetic template rather than relying on this table being non-empty.
Places.QUARANTINE = table.freeze({})

-- IS THIS TEMPLATE REFUSED? One lookup, so `namesOf` and the planter cannot disagree.
function Places.isQuarantined(name: string): boolean
	return (Places.QUARANTINE :: any)[name] ~= nil
end

-- WHICH PARTS ARE FOLIAGE, BY NAME. MOVED HERE in task 328b from `ServerScriptService.Places`, which
-- still carries the whole measurement behind it (623 queryable leaves, 127 colliding branches, and
-- the control that proved `CanQuery = false` is not enough) and now aliases these two. It is here
-- because `TEMPLATE_DIMS`'s crown half-width and `ServerStorage.GridCensus` both need it and neither
-- may reach into the server's planter (design 9.2, 9.4).
Places.FOLIAGE_WORDS = table.freeze({
	"leaf",
	"leaves",
	"branch",
	"twig",
	"frond",
	"fern",
	"needle",
	"canopy",
	"crown",
	"bush",
	"shrub",
})

-- IS THIS PART FOLIAGE BY NAME? Case-insensitive substring, so `SM_Leaves`, `OuterLeaves`,
-- `Branch.002` and `Bush4` all answer true and `Trunk`, `SM_Trunk` and `CollidePart` all answer
-- false. ONE definition, so the sweep, the census and the spec cannot disagree about what a leaf is.
function Places.isFoliageName(name: string): boolean
	local lower = string.lower(name)
	for _, word in ipairs(Places.FOLIAGE_WORDS) do
		if string.find(lower, word, 1, true) then
			return true
		end
	end
	return false
end

-- HOW MUCH GROUND SPREAD A TREE OF THIS HEIGHT MAY BE PLANTED ACROSS. MOVED HERE in task 328b for
-- `GridCensus`'s sake (design 9.1: the census SHARES THE THRESHOLDS and shares no measurement);
-- `ServerScriptService.Places.stepAllowance` is now an alias and carries the measurement that chose
-- it -- a flat 4 refused 776 of 2,713 candidates, 29% of the forest, as holes.
function Places.stepAllowanceStuds(heightStuds: number): number
	return math.max(TreeGround.CLIFF_STUDS, 0.10 * heightStuds)
end

-- THE AUDIT'S FOUR NUMBERS (design 9.3), named rather than typed into the arms below.
Places.AUDIT_LYING_DEGREES = 5
Places.AUDIT_DETACHED_STUDS = 1
Places.AUDIT_EXTENTS_FRACTION = 0.15
-- HOW FAR A CHOSEN TEMPLATE'S OWN `GetScale()` MAY SIT FROM ITS ROW. 2 % is wider than the 4
-- decimals a row carries (0.3 % on the thinnest birch at 0.0316) and far inside the x1.8 spread
-- `Places.nearestScale` picks out of, so only a RE-IMPORT of the wood can trip it.
Places.AUDIT_SCALE_FRACTION = 0.02

-- WHICH STANDING TREE IS "THE TEMPLATE": the one whose own scale is nearest the row's, and NOT
-- whichever `FindFirstChild` answers first.
--
-- MEASURED in Karen's Forest Test on 2026-11-03 (`tools/forest_ground.py dims`, task 328l): every
-- one of the 35 names has 16 to 125 standing instances in `Workspace.OurForest`, and within ONE name
-- the scales span a factor of **1.65 to 1.84** (`Old_Spruce_Tree_Var01_LOD_0`: 21 instances,
-- 0.2855 to 0.4703). `FindFirstChild(name)` answers an arbitrary one of them, so `TEMPLATE_DIMS`
-- described a different tree on 2026-11-02 than it does today -- 27 of the 35 rows read `live / row`
-- 0.589 to 1.371 -- and `item.scale`, which is RELATIVE to the template, planted a different size
-- every time the folder's child order moved. This picker is what makes the row a fact: nearest wins,
-- then the smaller scale, so the answer cannot depend on child order.
function Places.nearestScale(scales: { number }, want: number): number?
	local best: number?, bestGap = nil, math.huge
	for index, scale in ipairs(scales) do
		local gap = math.abs(scale - want)
		local bestScale = if best ~= nil then scales[best :: number] else math.huge
		if gap < bestGap - 1e-9 or (gap <= bestGap + 1e-9 and scale < bestScale) then
			best, bestGap = index, gap
		end
	end
	return best
end

-- IS THE CHOSEN TEMPLATE STILL THE ONE THE ROW WAS MEASURED ON? Design 9.2's refusal, and it is the
-- TEMPLATE's arm alone -- never a planted clone's, whose `GetScale()` is the template's times
-- `item.scale` on purpose. Nil means plant it.
function Places.rescaledReason(live: number, dims: any?): string?
	if dims == nil then
		return nil
	end
	local want = dims.scale
	if want == nil or want <= 0 then
		return nil
	end
	if math.abs(live / want - 1) > Places.AUDIT_SCALE_FRACTION then
		return "template-rescaled"
	end
	return nil
end

-- ONE MODEL'S MEASURED GEOMETRY, as plain numbers, so the audit below needs no Instance and no
-- world. `tiltCos` is the lowest non-foliage part's `UpVector . Y`.
export type Measured = {
	name: string,
	parts: number,
	tiltCos: number,
	trunk: TreeGround.Box?,
	whole: TreeGround.Box?,
	crown: TreeGround.Box?,
}

-- THE TEMPLATE AUDIT (design 9.3), AS ARITHMETIC AND NOTHING ELSE. Nil means it passed; otherwise the
-- reason, in one word. **ONE definition, called twice**: the planter audits each TEMPLATE at build
-- time and `ServerStorage.GridCensus` audits each PLANTED model (where design 9.4 calls it `broken`),
-- so the two can never disagree about what broken means -- they disagree only about what they measure.
--
-- `scale` IS THE MODEL'S `GetScale()` and the extents arm divides it by `dims.scale` (design 9.2);
-- `dims` nil means there is no reference and nothing but the two geometry arms can be judged.
function Places.auditReason(measured: Measured, dims: any?, scale: number): string?
	local trunk, whole = measured.trunk, measured.whole
	if trunk == nil or whole == nil then
		return "no-geometry"
	end
	-- A HERB IS WIDER THAN IT IS TALL AND THAT IS NOT A DEFECT (see `HERB_GROUPS`), so the axis arm
	-- and the lying arm are a TREE's. This arm is what catches 327c-f3's lying birch at the source.
	if not Places.isHerbName(measured.name) then
		local tx, ty, tz = trunk.maxX - trunk.minX, trunk.maxY - trunk.minY, trunk.maxZ - trunk.minZ
		if ty < tx or ty < tz then
			return "trunk-axis-not-Y"
		end
		if measured.tiltCos < math.cos(math.rad(Places.AUDIT_LYING_DEGREES)) then
			return "trunk-lying"
		end
	end
	-- DETACHED FOLIAGE: a crown whose bottom is more than a stud above the trunk's top, or which does
	-- not overlap the trunk in X or Z at all.
	local crown = measured.crown
	if crown ~= nil then
		local overX = math.min(crown.maxX, trunk.maxX) - math.max(crown.minX, trunk.minX)
		local overZ = math.min(crown.maxZ, trunk.maxZ) - math.max(crown.minZ, trunk.minZ)
		if crown.minY - trunk.maxY > Places.AUDIT_DETACHED_STUDS or overX <= 0 or overZ <= 0 then
			return "foliage-detached"
		end
	end
	if dims == nil then
		return nil
	end
	if measured.parts ~= dims.parts then
		return "part-count"
	end
	local want = dims.heightStuds * (scale / math.max(dims.scale, 1e-6))
	if want > 0 and math.abs((whole.maxY - whole.minY) - want) > Places.AUDIT_EXTENTS_FRACTION * want then
		return "extents"
	end
	return nil
end

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
	-- v2 (task 328f, design 8.1 and 8.3), all optional:
	jitter: number?, -- how far a site wanders off the grid, as a fraction of the spacing
	rows: string?, -- "NS": hold the x line and let only the depth wander -- a plantation
	reliefBias: boolean?, -- spruce below hn .30, birch above .70, off the cell's measured relief
	floor: string?, -- which floor table this zone takes (the bake's, not the planter's)
	-- v3 (task 328m): A SECOND STOREY over the same rectangle, young growth under the canopy.
	under: { spacingStuds: number, mix: string, jitter: number? }?,
}

-- A HELPER SO A RECIPE READS AS A TILING AND NOT AS PUNCTUATION. The eight recipes below are its
-- only callers.
-- `extra` IS THE v2 HALF (task 328f): `jitter`, `rows`, `reliefBias` and `floor`, all optional, all
-- data, so a recipe row stays one line per zone and a zone that wants none of them reads exactly as
-- it did before.
local function zone(
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	spacing: number,
	name: string,
	band: string,
	extra: { [string]: any }?
): Zone
	local made: { [string]: any } = {
		at = table.freeze({ x0, z0, x1, z1 }),
		mix = name,
		spacingStuds = spacing,
		band = band,
	}
	for key, value in pairs(extra or {}) do
		made[key] = value
	end
	return table.freeze(made) :: any
end

-- HOW FAR INSIDE ITS OWN EDGE A CELL PLANTS. The lane rule measures `<=` (`Places.inLane`), so a
-- candidate landing exactly on the cell's edge reads as IN the road's clear width -- a cell's
-- interior starts exactly `roadClearStuds / 2` from each road's centre line. Three studs is clear of
-- that and costs 0.6 % of the cell's area.
Places.CELL_EDGE_STUDS = 3

-- THE RANDOM STREAMS, one per layer, hashed through `Grid.seedFor` -- so the trees, the floor and the
-- skirt cannot shift each other, and NO stream is a counter (design 4.6: a cell's wood is the same
-- whatever order the cells were built in).
-- `under` IS THE UNDERSTOREY'S OWN STREAM (task 328m), so adding a second storey to one zone cannot
-- move a single canopy stem -- `grid.spec` asserts that pair rather than assuming it.
Places.CELL_STREAM = table.freeze({ trees = 1, ferns = 2, skirt = 3, under = 4 })

-- HOW FAR AN UNDERSTOREY SITE WANDERS off its grid, as a fraction of its own spacing, when the row
-- names none. 1.0 -- the whole cell -- because a sapling thicket has no grid in it at all, and
-- because the canopy is planted FIRST and shares `minGapStuds`: a wandering sapling finds the gaps
-- between trunks, which is where young growth actually stands.
Places.UNDER_JITTER = 1.0

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
		-- v2 (task 328f). THE FRONTAGE RULE (design 7.2): within 60 studs of any road or ride
		-- centreline only these four groups are drawn, so a mature crown is set back from the one
		-- thing a hunter sights along at no cost in density -- the roadside draws birch and larch
		-- instead of spruce rather than drawing nothing.
		frontage = table.freeze({ studs = 60, groups = table.freeze({ "birch", "young", "aspen", "fieldOak" }) }),
		-- THE FERN BAND, MEASURED FROM THE ROAD CENTRELINE (defect F-5): 34 is the far edge of the
		-- verge, so no bracken stands in the ditch or on the verge design 7.1 keeps bare.
		fernBand = table.freeze({ fromStuds = 34, depthStuds = 30 }),
		scaleFloor = 0.35,
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
		-- v2 (task 328f). THE FRONTAGE RULE (design 7.2): within 60 studs of any road or ride
		-- centreline only these four groups are drawn, so a mature crown is set back from the one
		-- thing a hunter sights along at no cost in density -- the roadside draws birch and larch
		-- instead of spruce rather than drawing nothing.
		frontage = table.freeze({ studs = 60, groups = table.freeze({ "birch", "young", "aspen", "fieldOak" }) }),
		-- THE FERN BAND, MEASURED FROM THE ROAD CENTRELINE (defect F-5): 34 is the far edge of the
		-- verge, so no bracken stands in the ditch or on the verge design 7.1 keeps bare.
		fernBand = table.freeze({ fromStuds = 34, depthStuds = 30 }),
		scaleFloor = 0.35,
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
		-- C1's RIDES AND CUTS (SWARM_DESIGN section 2.2): a V ride straight out from stand 5, an X
		-- cut across stand 3's sight line, and an L ride into the cell from each flank -- W9 and
		-- E14, which `Grid.standPosition` puts at z 560 and z 780, the two depths that table names.
		-- The design gives no length for an X cut; 300 is the L ride's own published length and it
		-- spans the +-30 degree cone at the crossing distance (161 studs) with 70 either side.
		rides = table.freeze({
			table.freeze({ kind = "V", atStandIndex = 5, lengthStuds = 700 }),
			table.freeze({ kind = "X", atStandIndex = 3, lengthStuds = 300 }),
			table.freeze({ kind = "L", atStandIndex = 9, lengthStuds = 300 }),
			table.freeze({ kind = "L", atStandIndex = 14, lengthStuds = 300 }),
		}),
		-- v2 (task 328f). THE FRONTAGE RULE (design 7.2): within 60 studs of any road or ride
		-- centreline only these four groups are drawn, so a mature crown is set back from the one
		-- thing a hunter sights along at no cost in density -- the roadside draws birch and larch
		-- instead of spruce rather than drawing nothing.
		frontage = table.freeze({ studs = 60, groups = table.freeze({ "birch", "young", "aspen", "fieldOak" }) }),
		-- THE FERN BAND, MEASURED FROM THE ROAD CENTRELINE (defect F-5): 34 is the far edge of the
		-- verge, so no bracken stands in the ditch or on the verge design 7.1 keeps bare.
		fernBand = table.freeze({ fromStuds = 34, depthStuds = 30 }),
		scaleFloor = 0.35,
		-- `reliefBias` ON THE FOUR WOOD ZONES (design 8.3): C1 is the ridge cell, so spruce takes the
		-- cold bottom under hn .30 and birch the crest over .70. The two scrub zones and the
		-- clearing are left alone -- a bias that rewrote the scrub would erase the beaters' ground.
		-- v3 (task 328m). KAREN, 2026-11-03, HAVING PLAYED C1: *"it's not broken trees it's good has
		-- to be a bit more realistic more trees but rest is good"*. C1 is the only recipe that takes
		-- these rows -- the other seven are untouched until she has judged this one.
		--
		-- WHAT EACH ZONE GETS, SAID PER ZONE, because "the rest is good" is a claim about ZONES and
		-- round 1's header made it about three of them while the rows made it about four
		-- (`reviews/task-328m/RESULT.md` finding 1):
		--  * `spruceThicket`, `mixedWood`, `birchStand` -- CLOSER (24/32/30 -> 21/28/27) AND a second
		--    storey (`under`): young larch at the `shrub` band's 0.35-0.45 scale, sharing the
		--    canopy's `minGapStuds` so it clumps into the gaps between trunks.
		--  * `oakPark` -- SPACING AND STOREY BOTH UNCHANGED. It is the park a hunter can see across
		--    (this recipe's own header: *"an oak park to the east where the sight lines open"*) and
		--    it is the part of "the rest" she said was good, so it gets neither.
		--  * the clearing -- NOTHING. Spacing 0, no jitter, plants nothing, exactly as before.
		--  * the two `scrub` zones -- SPACING UNCHANGED, but `jitter` 1.0 like every other zone, so
		--    their sites DO move. That is not "untouched" and is not claimed to be: at the 0.8
		--    default a site wanders over 80 % of its own step, which leaves a 20 % empty stripe per
		--    row -- a grid you can see. 1.0 spans the step, costs no capacity, and is the dispatch's
		--    *"no rows where the design does not ask for rows"*.
		--
		-- THE BUDGET IS WHAT SETS THE NUMBERS, not taste: the bound is `grid-roads.md` 8.2's pair,
		-- `cellCapacity <= CELL_PLAN_CAP` (7,260) and drawn `<= CELL_PART_CAP` (2,640). C1 stood at
		-- 2,598; these rows put its capacity at 3,416 and its draw at 1,687, so 953 models of room.
		-- MEASURED, three allocations of that same budget (`driven-hunt-runs/328m-yield-v{1,2,3}.txt`):
		-- 1,885 / 1,876 / 1,886 planned models at capacity 3,548 / 3,588 / 3,526. The count PLATEAUS,
		-- because what refuses a site is `minGapStuds` and `Places.mask`, not the grid -- a per-zone
		-- yield of 54-76 % in the canopy and 19-47 % under it. So the three are one count with three
		-- storey splits, and this one is the split with the most understorey (232 saplings against
		-- 148 and 150). `minGapStuds` 12 is NOT lowered: these crowns are 20-80 studs wide and
		-- already interpenetrate at 12.
		zones = table.freeze({
			zone(0.00, 0.00, 0.40, 0.35, 21, "spruceThicket", "wood", {
				reliefBias = true,
				jitter = 1.0,
				under = table.freeze({ spacingStuds = 42, mix = "larchYoung" }),
			}),
			zone(0.40, 0.00, 1.00, 0.35, 28, "mixedWood", "wood", {
				reliefBias = true,
				jitter = 1.0,
				under = table.freeze({ spacingStuds = 42, mix = "larchYoung" }),
			}),
			zone(0.00, 0.35, 0.60, 0.70, 27, "birchStand", "wood", {
				reliefBias = true,
				jitter = 1.0,
				under = table.freeze({ spacingStuds = 42, mix = "larchYoung" }),
			}),
			zone(0.60, 0.35, 1.00, 0.70, 44, "oakPark", "wood", {
				reliefBias = true,
				jitter = 1.0,
			}),
			zone(0.15, 0.70, 0.65, 1.00, 0, "clearing", "wood"),
			zone(0.00, 0.70, 0.15, 1.00, 24, "scrub", "shrub", { jitter = 1.0 }),
			zone(0.65, 0.70, 1.00, 1.00, 26, "scrub", "shrub", { jitter = 1.0 }),
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
		-- D1's MEADOW (SWARM_DESIGN section 2.2: "a field in a shallow dish", 798 x 515 studs). The
		-- fractions are of the cell's inset ground, 1064 x 1424, so they come out 798 x 513. The
		-- 12-stud headland is where the hedge and the four lone oaks stand; the mask keeps trees out
		-- of the field INSIDE it, not out of the headland.
		field = table.freeze({
			at = table.freeze({ 0.12, 0.05, 0.87, 0.41 }),
			headlandStuds = 12,
			stripePitchStuds = 8,
		}),
		-- v2 (task 328f). THE FRONTAGE RULE (design 7.2): within 60 studs of any road or ride
		-- centreline only these four groups are drawn, so a mature crown is set back from the one
		-- thing a hunter sights along at no cost in density -- the roadside draws birch and larch
		-- instead of spruce rather than drawing nothing.
		frontage = table.freeze({ studs = 60, groups = table.freeze({ "birch", "young", "aspen", "fieldOak" }) }),
		-- THE FERN BAND, MEASURED FROM THE ROAD CENTRELINE (defect F-5): 34 is the far edge of the
		-- verge, so no bracken stands in the ditch or on the verge design 7.1 keeps bare.
		fernBand = table.freeze({ fromStuds = 34, depthStuds = 30 }),
		scaleFloor = 0.35,
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
		-- v2 (task 328f). THE FRONTAGE RULE (design 7.2): within 60 studs of any road or ride
		-- centreline only these four groups are drawn, so a mature crown is set back from the one
		-- thing a hunter sights along at no cost in density -- the roadside draws birch and larch
		-- instead of spruce rather than drawing nothing.
		frontage = table.freeze({ studs = 60, groups = table.freeze({ "birch", "young", "aspen", "fieldOak" }) }),
		-- THE FERN BAND, MEASURED FROM THE ROAD CENTRELINE (defect F-5): 34 is the far edge of the
		-- verge, so no bracken stands in the ditch or on the verge design 7.1 keeps bare.
		fernBand = table.freeze({ fromStuds = 34, depthStuds = 30 }),
		scaleFloor = 0.35,
		zones = table.freeze({
			zone(0.00, 0.00, 1.00, 0.26, 26, "larchYoung", "shrub", { rows = "NS", jitter = 0.25 }),
			zone(0.00, 0.26, 0.35, 0.65, 28, "larchYoung", "shrub", { rows = "NS", jitter = 0.25 }),
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
		-- v2 (task 328f). THE FRONTAGE RULE (design 7.2): within 60 studs of any road or ride
		-- centreline only these four groups are drawn, so a mature crown is set back from the one
		-- thing a hunter sights along at no cost in density -- the roadside draws birch and larch
		-- instead of spruce rather than drawing nothing.
		frontage = table.freeze({ studs = 60, groups = table.freeze({ "birch", "young", "aspen", "fieldOak" }) }),
		-- THE FERN BAND, MEASURED FROM THE ROAD CENTRELINE (defect F-5): 34 is the far edge of the
		-- verge, so no bracken stands in the ditch or on the verge design 7.1 keeps bare.
		fernBand = table.freeze({ fromStuds = 34, depthStuds = 30 }),
		scaleFloor = 0.35,
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
		-- v2 (task 328f). THE FRONTAGE RULE (design 7.2): within 60 studs of any road or ride
		-- centreline only these four groups are drawn, so a mature crown is set back from the one
		-- thing a hunter sights along at no cost in density -- the roadside draws birch and larch
		-- instead of spruce rather than drawing nothing.
		frontage = table.freeze({ studs = 60, groups = table.freeze({ "birch", "young", "aspen", "fieldOak" }) }),
		-- THE FERN BAND, MEASURED FROM THE ROAD CENTRELINE (defect F-5): 34 is the far edge of the
		-- verge, so no bracken stands in the ditch or on the verge design 7.1 keeps bare.
		fernBand = table.freeze({ fromStuds = 34, depthStuds = 30 }),
		scaleFloor = 0.35,
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
		-- v2 (task 328f). THE FRONTAGE RULE (design 7.2): within 60 studs of any road or ride
		-- centreline only these four groups are drawn, so a mature crown is set back from the one
		-- thing a hunter sights along at no cost in density -- the roadside draws birch and larch
		-- instead of spruce rather than drawing nothing.
		frontage = table.freeze({ studs = 60, groups = table.freeze({ "birch", "young", "aspen", "fieldOak" }) }),
		-- THE FERN BAND, MEASURED FROM THE ROAD CENTRELINE (defect F-5): 34 is the far edge of the
		-- verge, so no bracken stands in the ditch or on the verge design 7.1 keeps bare.
		fernBand = table.freeze({ fromStuds = 34, depthStuds = 30 }),
		scaleFloor = 0.35,
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
								-- `namesOf` AND NOT `SPECIES` DIRECTLY, the same door `scatter` uses: it is
								-- the ONE place a quarantined template is dropped, and the four line
								-- places must not be the hole in it (round 1, finding 1).
								local names = Places.namesOf(group)
								if #names == 0 then
									continue
								end
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
--
-- MEMOISED PER (cell, zone), and that is not a micro-optimisation: `Places.mask` asks `zoneAt` for
-- every candidate, `zoneAt` asks this for every zone, and the planter plus the specs make something
-- like a million calls -- each of which allocated a fresh table. Both inputs are frozen (`Grid.CELLS`
-- and `CELL_PLANS`), so there is nothing to invalidate; `Places.forgetCells` drops it anyway, for the
-- same reason the mask's own cache has that door.
local ZONE_RECTS: { [string]: { [any]: any } } = {}
function Places.zoneRect(cellId: string, z: any): { minX: number, maxX: number, minZ: number, maxZ: number }
	local forCell = ZONE_RECTS[cellId]
	if forCell == nil then
		forCell = {}
		ZONE_RECTS[cellId] = forCell
	end
	local found = forCell[z]
	if found ~= nil then
		return found
	end
	local ground = Places.cellGround(cellId)
	local width = ground.maxX - ground.minX
	local depth = ground.maxZ - ground.minZ
	local made = {
		minX = ground.minX + z.at[1] * width,
		minZ = ground.minZ + z.at[2] * depth,
		maxX = ground.minX + z.at[3] * width,
		maxZ = ground.minZ + z.at[4] * depth,
	}
	forCell[z] = made
	return made
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
-- `reachStuds` IS THE CROWN (task 328b, design 9.4's `crownOverRoad`): 0 asks about the TRUNK, which
-- is every caller written before it, and a crown half-width asks whether the canopy hangs over.
--
-- WORLD IN, `Grid.toGrid` ONCE, AND THE BODY IS UNCHANGED (task 328q, design 6.1): in grid
-- coordinates every road is straight at its own `at`, so this is the same test it always was. The
-- measure is axis-aligned in that plane, which reads up to 0.82 % wide against the true
-- perpendicular at the shipped bend (design 5.5) and exactly right at amplitude 0.
function Places.clearOfEveryRoad(x: number, z: number, reachStuds: number?, bend: any?): boolean
	local u, v = Grid.toGrid(x, z, bend)
	return Places.clearOfEveryRoadGrid(u, v, reachStuds, bend)
end

-- THE SAME QUESTION IN GRID COORDINATES, and it is the KERNEL (task 328r, 328q note (i)): the
-- rectangle test below is a GRID test, so `scatter` -- which already holds a grid point -- asked it
-- by mapping forward and letting the wrapper map straight back, two five-step inverses a site.
-- `bend` is carried only so the signature matches the rest of the seam; nothing here reads it.
function Places.clearOfEveryRoadGrid(u: number, v: number, reachStuds: number?, _bend: any?): boolean
	local half = Grid.CONFIG.roadClearStuds / 2 + (reachStuds or 0)
	for _, road in ipairs(allRoads()) do
		if road.axis == "x" then
			if math.abs(v - road.at) <= half and u >= road.from and u <= road.to then
				return false
			end
		elseif math.abs(u - road.at) <= half and v >= road.from and v <= road.to then
			return false
		end
	end
	return true
end

-- ===================================================================== the forest, v2 (task 328f)
--
-- WHAT THIS BLOCK IS FOR, in Karen's words (2026-11-02): *"not broken trees hanging or to inside"*.
-- One pure function, `Places.mask`, answers "may a tree stand here?" for every site in the world,
-- and every exclusion the design names is a named reason in it.
-- Design: docs/design/grid-terrain.md sections 7.2, 7.3, 7.4, 8.1-8.5.

-- THE TRUNK-FREE HALF-WIDTHS, and both are FLOORS that a crown term can only raise (design 7.2).
-- 34 is the far edge of the verge (design 7.1's cross-section: road 0-21, ditch 22-30, verge 30-34),
-- so the three road reasons below tile [0, 34] exactly and the floor IS the cross-section.
Places.ROAD_TRUNK_FLOOR_STUDS = 34
Places.RIDE_TRUNK_FLOOR_STUDS = 27

-- THE RIDE: 54 studs trunk-free (design 7.3, settled against BASC's 15 m minimum), painted 24.
Places.RIDE_CLEAR_STUDS = 54
Places.RIDE_PAINT_STUDS = 24

-- THE DITCH AND THE VERGE, from design 7.1's table. No tree and no fern stands in either.
--
-- THE DITCH STARTS AT `roadClearStuds / 2` (21) AND NOT AT THE TABLE'S 22, so the three bands tile
-- [0, 34] with no stud between them belonging to nothing: 21 is the clear width the rest of the
-- game already measures against (`Places.clearOfEveryRoad`, `grid.spec` case 12's identity), and a
-- one-stud gap would have read `nil` -- plantable -- between the road and the ditch.
Places.VERGE_STUDS = table.freeze({ from = 30, to = 34 })

-- HOW FAR A PLANTED TREE'S TRUNK CENTRE CAN END UP FROM THE POINT THE PLAN ASKED FOR, and it is
-- MEASURED, not chosen: `plantOne` puts the model's PIVOT at (x, z) and then moves the clone in Y
-- only, but a Model with no `PrimaryPart` carries its bounding-box centre for a pivot, which a
-- one-sided crown pulls off the trunk. Over C1's 1,999 planted trees in Karen's Forest Test on
-- 2026-11-02 (`driven-hunt-runs/328f-offset.luau`): mean 0.746, worst **9.273**
-- (`SM_AspenTree_Var04`), 19 of them over 8 studs. The crown rule adds 10 so the CENSUS -- which
-- measures the trunk box, not the pivot -- cannot find a crown over a road the plan set back.
Places.CROWN_DRIFT_STUDS = 10

-- ...AND THE SLACK THAT USED TO SIT BESIDE IT IS **RETIRED** (task 328l, Director decision
-- 2026-11-03). `Places.CROWN_SCALE_SLACK` was 1.40: the planner knows `item.scale` (relative to the
-- template) and the census divides `model:GetScale()` by `dims.scale`, so the two agreed only while
-- `dims.scale` WAS the chosen template's own scale -- and for 27 of the 35 it was not, by ratios
-- 0.589 to 1.371, because `FindFirstChild` answered an arbitrary one of 16-125 standing instances.
-- `Places.nearestScale` now chooses that instance by the row, the audit refuses a template more than
-- 2 % off it, so `live / row` is 1.000 for all 35 and the two reaches are the same number. The
-- archived text and its arithmetic are in `backups/2026-11-03-crown-scale-slack.md`.

-- CLEARANCE AROUND WHAT A HUNTER STANDS ON (design 7.4 / SWARM_DESIGN section 3.3).
Places.POST_CLEAR_STUDS = 20
Places.TOWER_CLEAR_STUDS = 24

-- THE FRONT CONE. Trunk-free for the first 40 studs; out to 140 no young growth, which is the band
-- a hunter actually shoots into.
Places.CONE = table.freeze({
	halfDegrees = 30,
	nearStuds = 40,
	-- On a TOWER stand young growth is allowed in the far cone: a larch's top is under the
	-- 17.5-stud deck eye (`HighSeats.DIMS.DECK_RISE_STUDS` 12.5 + 5), so he looks over it.
	farStuds = 140,
})

-- WHERE AN "X" CUT CROSSES THE SIGHT LINE: the far edge of the managed cone, so the cut ends the
-- shot zone rather than striping through the middle of it. DERIVED from `CONE.farStuds`.
Places.CUT_CROSS_STUDS = 140

-- THE SIX BEATER CORRIDORS (SWARM_DESIGN section 3.4): 10 studs wide, measured from the cell's WEST
-- edge, each centreline wandering +-20 studs on a 240-stud wavelength so it reads as a deer path.
Places.CORRIDOR = table.freeze({
	atStuds = table.freeze({ 160, 310, 460, 610, 760, 910 }),
	halfStuds = 5,
	jitterStuds = 20,
	waveStuds = 240,
})

-- THE FERN CAP (B9) and the zones a fern may stand in: design 8.3's W, M, B and Bo. Not under a
-- thicket, not in scrub, not in a larch plantation and not in a clearing.
Places.FERN_CAP = 400
Places.FERN_MIXES = table.freeze({
	oakWood = true,
	oakPark = true,
	mixedWood = true,
	birchStand = true,
	birchOpen = true,
})

-- NO TREE SMALLER THAN THIS FRACTION OF ITS TEMPLATE (design 8.3). Below it a larch reads as litter.
Places.SCALE_FLOOR = 0.35

-- WHY A SITE IS REFUSED. `Places.mask` answers with one of these, or `nil` for "plantable".
--
-- TWO OF THE FIFTEEN ARE NOT THIS FUNCTION'S TO ANSWER, and the names are kept so one vocabulary
-- covers the whole planting path: **`CLIFF`** needs terrain, so `Places.plantOne`'s own `"cliff"`
-- refusal answers it from real rays; **`GAP`** is the `minGapStuds` rule, a fact about the trees
-- already placed, so it lives in `scatter`'s neighbour grid. `grid_ground.spec` case 4 asserts both
-- as reasons the pure mask never returns.
Places.REASON = table.freeze({
	ROAD = "road",
	VERGE = "verge",
	DITCH = "ditch",
	RIDE = "ride",
	STAND = "stand",
	TOWER = "tower",
	CONE = "cone",
	CORRIDOR = "corridor",
	NO_TREES = "noTrees",
	CLIFF = "cliff",
	FIELD = "field",
	CLEARING = "clearing",
	FRONTAGE = "frontage",
	CROWN = "crown",
	GAP = "gap",
})

-- THE ORDER THE MASK ASKS IN, OUTERMOST FACT FIRST -- the world's own geometry, then the cell's
-- plan, then this one tree. A TABLE and not prose, so a spec can assert it (design 8.2); and it
-- matters because the FIRST match is the reason the caller is given, so a point in a ditch that is
-- also under a crown reads `ditch`, which is the fact a person can act on.
Places.REASON_ORDER = table.freeze({
	Places.REASON.ROAD,
	Places.REASON.DITCH,
	Places.REASON.VERGE,
	Places.REASON.RIDE,
	Places.REASON.CLIFF,
	Places.REASON.NO_TREES,
	Places.REASON.FIELD,
	Places.REASON.CLEARING,
	Places.REASON.TOWER,
	Places.REASON.STAND,
	Places.REASON.CONE,
	Places.REASON.CORRIDOR,
	Places.REASON.FRONTAGE,
	Places.REASON.CROWN,
	Places.REASON.GAP,
})

-- THE TWO REASONS A PURE MASK CANNOT REACH, named here rather than in a comment so the spec reads
-- the same list the header promises.
Places.REASON_NOT_MASKED = table.freeze({ Places.REASON.CLIFF, Places.REASON.GAP })

-- WHICH GROUP A TEMPLATE BELONGS TO. Built once from `SPECIES`, the one table that says so.
local GROUP_OF: { [string]: string }? = nil
function Places.groupOf(name: string?): string?
	if type(name) ~= "string" then
		return nil
	end
	if GROUP_OF == nil then
		local built: { [string]: string } = {}
		for group, names in pairs(Places.SPECIES) do
			for _, each in ipairs(names) do
				built[each] = group
			end
		end
		GROUP_OF = built
	end
	return (GROUP_OF :: any)[name]
end

-- HOW FAR THIS TREE'S CROWN REACHES SIDEWAYS, in world studs, or nil for a template with no measured
-- row. `TEMPLATE_DIMS` records the crown half-width at the chosen template's OWN scale and
-- `item.scale` is relative to it, so the product is the absolute reach -- the same arithmetic
-- `GridCensus.survey` does as `crownHalfWidthStuds * (model:GetScale() / dims.scale)`, which IS
-- `item.scale` once `nearestScale` and the audit make `GetScale() / dims.scale` 1.000.
function Places.crownReachStuds(template: string?, scale: number?): number?
	local dims = Places.dimsFor(template or "")
	if dims == nil then
		return nil
	end
	return dims.crownHalfWidthStuds * (scale or 1)
end

-- THE TRUNK MINIMUM BESIDE A ROAD AND BESIDE A RIDE (design 7.2): how far from the CENTRELINE a
-- trunk may stand.
--
-- **THE LINEAR TERM IS MEASURED FROM THE SAME HALF-WIDTH THE CENSUS USES, NOT FROM THE PAINTED
-- CARRIAGEWAY.** Design 7.2 writes `halfCrown * scale + 10`, taking 10 from the painted half-width;
-- but `GridCensus`' `crownOverRoad` counts a tree inside `roadClearStuds / 2` (21) PLUS its crown
-- reach of a centreline, so a tree set back by `crown + 10` still counts. MEASURED in Karen's Forest
-- Test at `121eb5ce` before this task (`driven-hunt-runs/328f-diag.luau`): **crownOverRoad 88** of
-- 1,999 trees, worst overhang 22.77 studs, in every group -- conifer 29, birch 24, aspen 16, oak 7,
-- young 3, fieldOak 2 -- so the frontage rule alone could not answer it. Taking the census's own 21
-- plus the measured pivot drift makes the count 0 by construction, and is strictly stronger than
-- design 7.2's number at a cost of about 5 studs on the widest crown.
--
-- WITH NO `TEMPLATE_DIMS` ROW the linear term is skipped and the floor is the whole rule (design
-- 7.2), which is what the census's `crownOverRoad=UNMEASURED` means.
function Places.roadTrunkMin(template: string?, scale: number?): number
	local reach = Places.crownReachStuds(template, scale)
	if reach == nil then
		return Places.ROAD_TRUNK_FLOOR_STUDS
	end
	return math.max(Places.ROAD_TRUNK_FLOOR_STUDS, Grid.CONFIG.roadClearStuds / 2 + reach + Places.CROWN_DRIFT_STUDS)
end

function Places.rideTrunkMin(template: string?, scale: number?): number
	local reach = Places.crownReachStuds(template, scale)
	if reach == nil then
		return Places.RIDE_TRUNK_FLOOR_STUDS
	end
	return math.max(Places.RIDE_TRUNK_FLOOR_STUDS, Places.RIDE_CLEAR_STUDS / 2 + reach + Places.CROWN_DRIFT_STUDS)
end

-- HOW FAR A GRID POINT IS FROM THE NEAREST ROAD CENTRELINE, over the roads that actually run past
-- it, measured PERPENDICULAR TO THE ROAD -- because a crown hangs over a carriageway across it, not
-- across the z axis (design 5.5). `math.huge` for a point no road reaches.
--
-- THE KERNEL: today's arithmetic in the plane where the roads are straight, times `cos(swing)` for
-- the road. At amplitude 0 the slope is 0, the cosine is exactly 1, and this answers what it always
-- answered. The station the slope is read at is the WORLD one, through `Grid.toWorld`, so there is
-- one definition of the seam and no second sine here.
--
-- `bend` IS A TRAILING OPTIONAL and nil means `Grid.CONFIG.bend` (task 328r, 328q note (a)): with
-- no parameter no case could drive the perpendicular factor or the band thresholds at a non-zero
-- amplitude, and both of 328q's blocking findings were invisible to every spec for exactly that
-- reason.
--
-- THE MINIMUM IS TAKEN OVER THE PERPENDICULAR DISTANCES, NOT OVER THE AXIS-ALIGNED ONES (328q note
-- (b)): round 1 picked the road by |v - at| and only then divided by sec(swing), so near a junction
-- it could pick a road that is not the perpendicular nearest and answer that one's distance.
-- THE INVERSE IS PAID AT MOST ONCE PER ASK, and only when a road actually reaches the point
-- (328q note (d)): `maskGrid` asks this ~3,000 times a cell and `Grid.toWorld` is five fixed-point
-- steps of ten trig calls. Most of a cell is out of every road's `from`/`to`, and that costs none.
function Places.roadDistanceGrid(u: number, v: number, bend: any?): number
	local best = math.huge
	local wx, wz = nil :: number?, nil :: number?
	for _, road in ipairs(allRoads()) do
		local along, across
		if road.axis == "x" then
			along, across = u, v
		else
			along, across = v, u
		end
		if along >= road.from and along <= road.to then
			local gap = math.abs(across - road.at)
			if gap > 0 then
				if wx == nil then
					wx, wz = Grid.toWorld(u, v, bend)
				end
				local slope = if road.axis == "x"
					then Grid.bendSlopeZ(wx :: number, bend)
					else Grid.bendSlopeX(wz :: number, bend)
				gap /= math.sqrt(1 + slope * slope)
			end
			best = math.min(best, gap)
		end
	end
	return best
end

-- THE SAME MEASURE, ASKED IN WORLD COORDINATES. One of the five seam functions (design 6.3).
function Places.roadDistance(x: number, z: number, bend: any?): number
	local u, v = Grid.toGrid(x, z, bend)
	return Places.roadDistanceGrid(u, v, bend)
end

-- WHICH WAY A STAND FACES: into its own cell, away from the road it stands on. A main-line stand
-- looks up the cell (the drive comes at it); a flank stand looks across it. Unit, in XZ.
-- IT IS A GRID-COORDINATE UNIT VECTOR (task 328q, design 6.4), which is why it reads
-- `Grid.standGridOf` and compares against the cell's grid rectangle. Mapped into the world the cone
-- is perpendicular to the LOCAL road, at most `bendFacts().swingDeg` off the drive axis.
-- `bend` IS A TRAILING OPTIONAL (task 328r, 328q note (a)/(j)): `Grid.standGridOf` moves a FLANK
-- stand with the amplitude (`flankFirstStuds` 340 -> 366), so this answer is a function of the bend
-- and a case that cannot name one cannot show the flank arm moving.
function Places.standFacing(cellId: string, standIndex: number, bend: any?): (number, number)
	local box = Grid.boundsOf(cellId)
	local u, v = Grid.standGridOf(cellId, standIndex, bend)
	if Grid.sideOf(cellId, standIndex) == "main" then
		return 0, if v <= (box.minZ + box.maxZ) / 2 then 1 else -1
	end
	return (if u <= (box.minX + box.maxX) / 2 then 1 else -1), 0
end

-- ONE RIDE OR CUT CENTRELINE.
export type Segment = { kind: string, ax: number, az: number, bx: number, bz: number }

-- THE RIDE AND CUT CENTRELINES OF A CELL. One rule for all three letters: a ride runs from its stand
-- ALONG that stand's facing, into the cell; an X cut runs ACROSS the sight line at `CUT_CROSS_STUDS`,
-- centred on it.
function Places.rideSegments(cellId: string, bend: any?): { Segment }
	local plan = Places.cellPlanFor(cellId)
	local out: { Segment } = {}
	if plan == nil or plan.rides == nil or Grid.cellOf(cellId) == nil then
		return out
	end
	for _, ride in ipairs(plan.rides) do
		-- GRID COORDINATES (task 328q): a ride is straight in the plane and a gentle curve in the
		-- world, which is what a cut through a sheared cell looks like.
		local su, sv = Grid.standGridOf(cellId, ride.atStandIndex, bend)
		local spot = Vector2.new(su, sv)
		local fx, fz = Places.standFacing(cellId, ride.atStandIndex, bend)
		if ride.kind == "X" then
			local cx = spot.X + fx * Places.CUT_CROSS_STUDS
			local cz = spot.Y + fz * Places.CUT_CROSS_STUDS
			local half = ride.lengthStuds / 2
			table.insert(out, {
				kind = ride.kind,
				ax = cx - fz * half,
				az = cz + fx * half,
				bx = cx + fz * half,
				bz = cz - fx * half,
			})
		else
			table.insert(out, {
				kind = ride.kind,
				ax = spot.X,
				az = spot.Y,
				bx = spot.X + fx * ride.lengthStuds,
				bz = spot.Y + fz * ride.lengthStuds,
			})
		end
	end
	return out
end

-- THE DISTANCE FROM A POINT TO A SEGMENT, in XZ. The one piece of geometry the ride rule needs.
local function segmentDistance(seg: Segment, x: number, z: number): number
	local dx, dz = seg.bx - seg.ax, seg.bz - seg.az
	local len2 = dx * dx + dz * dz
	local t = if len2 <= 0 then 0 else math.clamp(((x - seg.ax) * dx + (z - seg.az) * dz) / len2, 0, 1)
	local px, pz = seg.ax + t * dx, seg.az + t * dz
	return math.sqrt((x - px) * (x - px) + (z - pz) * (z - pz))
end

-- THE CELL'S FIELD, as a world rectangle, or nil where the recipe carries none (design 8.1: D1).
function Places.fieldRect(cellId: string): { minX: number, maxX: number, minZ: number, maxZ: number }?
	local plan = Places.cellPlanFor(cellId)
	if plan == nil or plan.field == nil then
		return nil
	end
	return Places.zoneRect(cellId, plan.field)
end

-- THE PER-CELL GEOMETRY THE MASK ASKS ~3,000 TIMES A CELL, worked out once. Every input is frozen
-- data (`Grid.CELLS`, `Places.CELL_PLANS`), so there is nothing to invalidate; `forgetPlantable`
-- drops it anyway, because a spec that re-stubs a cell plan must see the new one.
type CellFacts = {
	rides: { Segment },
	stands: { { x: number, z: number, fx: number, fz: number, tower: boolean } },
	corridors: { number },
	minX: number,
}
local CELL_FACTS: { [string]: CellFacts } = {}
-- THE CACHE IS KEYED ON THE CELL AND HOLDS THE **SHIPPED** BEND'S FACTS ONLY (task 328r).
--
-- 328q's header here said *"these are grid facts and the bend does not move them"*, and for a MAIN
-- stand that is true. For a FLANK stand it is not: `Grid.standGridOf` adds `Grid.flankFirstStuds`,
-- which solves a fixed point against the amplitude and goes 340 -> 366 at 45/60. MEASURED: asking
-- `plantCell("C1", nil, STRAIGHT)` while the cache held the shipped bend's stands answered 1,795
-- rows against the straight world's own 1,823 -- the stand, tower and cone arms of the mask were
-- reading flank posts 26 studs from where that world puts them.
--
-- SO THERE ARE TWO CACHES, AND THE SECOND IS KEYED ON THE BEND TABLE'S IDENTITY. `nil` -- every
-- production caller -- is cached exactly as before and costs nothing. An explicit bend gets its own
-- cache, emptied the moment a DIFFERENT table is handed in, which is what a spec driving two
-- amplitudes does. Without it `maskGrid` rebuilt fifteen stands and the rides on EVERY site:
-- `plantCell` asks it about 3,000 times a cell and the server suite stopped reporting inside its
-- 300 s window.
local CELL_FACTS_BENT: { [string]: CellFacts } = {}
local LAST_BEND: any = nil
local function cellFacts(cellId: string, bend: any?): CellFacts
	local found
	if bend == nil then
		found = CELL_FACTS[cellId]
	else
		if bend ~= LAST_BEND then
			CELL_FACTS_BENT, LAST_BEND = {}, bend
		end
		found = CELL_FACTS_BENT[cellId]
	end
	if found ~= nil then
		return found
	end
	local built: CellFacts = { rides = Places.rideSegments(cellId, bend), stands = {}, corridors = {}, minX = 0 }
	if Grid.cellOf(cellId) ~= nil then
		local towers: { [number]: boolean } = {}
		for _, index in ipairs(Grid.towerStands(cellId)) do
			towers[index] = true
		end
		for index = 1, Grid.standCount(cellId) do
			-- GRID COORDINATES, and the flank's v carries the bend (above).
			local su, sv = Grid.standGridOf(cellId, index, bend)
			local fx, fz = Places.standFacing(cellId, index, bend)
			table.insert(built.stands, { x = su, z = sv, fx = fx, fz = fz, tower = towers[index] == true })
		end
		built.minX = Grid.boundsOf(cellId).minX
		for index = 1, #Places.CORRIDOR.atStuds do
			table.insert(built.corridors, (Grid.seedFor(cellId, 90 + index) % 1000) / 1000 * math.pi * 2)
		end
	end
	if bend == nil then
		CELL_FACTS[cellId] = built
	else
		CELL_FACTS_BENT[cellId] = built
	end
	return built
end

-- A BEATER CORRIDOR'S CENTRELINE AT ONE DEPTH. The wander is a hash of the cell and the corridor
-- plus a sine of z, so it is PURE and the same every run -- `Grid.seedFor`'s own discipline, with no
-- `Random` object carrying state between calls.
function Places.corridorXAt(cellId: string, index: number, z: number, bend: any?): number
	local facts = cellFacts(cellId, bend)
	local wander = math.sin(z / Places.CORRIDOR.waveStuds * math.pi * 2 + facts.corridors[index])
		* Places.CORRIDOR.jitterStuds
	return facts.minX + Places.CORRIDOR.atStuds[index] + wander
end

-- FORGET IT. `Places.forgetPlantable`'s own reason, for the mask's half of the data.
function Places.forgetCells()
	CELL_FACTS = {}
	CELL_FACTS_BENT, LAST_BEND = {}, nil
	ZONE_RECTS = {}
end

-- MAY A TREE STAND HERE? `nil` means yes; anything else is a `Places.REASON`, in `REASON_ORDER`.
-- PURE: no Instance, no raycast, no terrain -- which is why `CLIFF` and `GAP` are its callers'.
--
-- `template` AND `scale` ARE OPTIONAL, and they are what the frontage and crown rules need. Asked
-- without them the answer is the SITE's own facts, which is the question `scatter` asks first.
-- WORLD IN; `Grid.toGrid` ONCE; `Places.maskGrid` IS TODAY'S BODY (task 328q, design 6.1). The
-- planner calls `maskGrid` directly and pays no inverse.
function Places.mask(cellId: string, x: number, z: number, template: string?, scale: number?, bend: any?): string?
	local u, v = Grid.toGrid(x, z, bend)
	return Places.maskGrid(cellId, u, v, template, scale, bend)
end

-- THE SAME QUESTION IN GRID COORDINATES, where every road, zone, ride, cone and corridor is the
-- straight thing it has always been. `x` and `z` below are grid coordinates throughout.
--
-- `bend` IS A TRAILING OPTIONAL (task 328r, 328q note (a)): the three road bands below are the only
-- thing here that moves with the amplitude, and without the parameter no case could cross a band
-- threshold at 45/60 while `Grid.CONFIG.bend` sat at one value.
function Places.maskGrid(cellId: string, x: number, z: number, template: string?, scale: number?, bend: any?): string?
	local R = Places.REASON
	local herb = template ~= nil and Places.isHerbName(template)
	-- 1-3 THE ROAD CROSS-SECTION (design 7.1), which tiles [0, 34] in three named bands.
	local d = Places.roadDistanceGrid(x, z, bend)
	if d <= Grid.CONFIG.roadClearStuds / 2 then
		return R.ROAD
	end
	if d < Places.VERGE_STUDS.from then
		return R.DITCH
	end
	if d < Places.VERGE_STUDS.to then
		return R.VERGE
	end
	local facts = cellFacts(cellId, bend)
	-- 4 THE RIDES, at their own trunk-free half-width. A fern may floor a ride; a trunk may not.
	if not herb then
		for _, seg in ipairs(facts.rides) do
			if segmentDistance(seg, x, z) <= Places.RIDE_CLEAR_STUDS / 2 then
				return R.RIDE
			end
		end
	end
	local plan = Places.cellPlanFor(cellId)
	-- 6 THE SCARP AND ANYTHING ELSE A RECIPE DECLARES BARE.
	if plan ~= nil and plan.noTrees ~= nil then
		for _, rect in ipairs(plan.noTrees) do
			local box = Places.zoneRect(cellId, rect)
			if x >= box.minX and x <= box.maxX and z >= box.minZ and z <= box.maxZ then
				return R.NO_TREES
			end
		end
	end
	-- 7 THE FIELD, less its headland: the headland is where the hedge and the lone oaks stand.
	local field = Places.fieldRect(cellId)
	if plan ~= nil and field ~= nil then
		local inset = plan.field.headlandStuds or 0
		if
			x >= field.minX + inset
			and x <= field.maxX - inset
			and z >= field.minZ + inset
			and z <= field.maxZ - inset
		then
			return R.FIELD
		end
	end
	-- 8 A CLEARING is a zone whose spacing is 0 -- the one fact that says "nothing is drawn here".
	local zoneHere = Places.zoneAt(cellId, x, z)
	if zoneHere ~= nil and zoneHere.spacingStuds <= 0 then
		return R.CLEARING
	end
	-- 9-11 THE STANDS, THE TOWERS AND THE FRONT CONES. A fern is allowed round a post (it is what a
	-- hunter stands in); a trunk is not.
	if not herb then
		local group = Places.groupOf(template)
		local coneCos = math.cos(math.rad(Places.CONE.halfDegrees))
		for _, stand in ipairs(facts.stands) do
			local dx, dz = x - stand.x, z - stand.z
			local range = math.sqrt(dx * dx + dz * dz)
			if stand.tower then
				if range <= Places.TOWER_CLEAR_STUDS then
					return R.TOWER
				end
			elseif range <= Places.POST_CLEAR_STUDS then
				return R.STAND
			end
			if range > 0 and range <= Places.CONE.farStuds then
				local cos = (dx * stand.fx + dz * stand.fz) / range
				if cos >= coneCos then
					if range <= Places.CONE.nearStuds then
						return R.CONE
					end
					-- THE MANAGED BAND: no young growth in front of a hunter, unless he is up a
					-- tower and looking over it.
					if group == "young" and not stand.tower then
						return R.CONE
					end
				end
			end
		end
	end
	-- 12 THE BEATER CORRIDORS.
	if not herb then
		for index = 1, #facts.corridors do
			if math.abs(x - Places.corridorXAt(cellId, index, z, bend)) <= Places.CORRIDOR.halfStuds then
				return R.CORRIDOR
			end
		end
	end
	-- 13 THE FRONTAGE. Within `frontage.studs` of a road or a ride centreline, only the named groups
	-- are drawn -- which is what keeps a mature crown away from the carriageway at no density cost
	-- (design 7.2). `scatter` draws FROM the allowed groups rather than refusing, so this arm is the
	-- rule stated for a caller that hands in a template of its own.
	if plan ~= nil and plan.frontage ~= nil and template ~= nil and not herb then
		local near = d <= plan.frontage.studs
		if not near then
			for _, seg in ipairs(facts.rides) do
				if segmentDistance(seg, x, z) <= plan.frontage.studs then
					near = true
					break
				end
			end
		end
		if near and not Places.frontageAllows(plan, template) then
			return R.FRONTAGE
		end
	end
	-- 14 THE CROWN. The floors above have already cleared 34 studs of road and 27 of ride; this is
	-- the linear term, and it bites only on a crown wide enough to reach past them.
	if template ~= nil and not herb then
		if d < Places.roadTrunkMin(template, scale) then
			return R.CROWN
		end
		local rideMin = Places.rideTrunkMin(template, scale)
		for _, seg in ipairs(facts.rides) do
			if segmentDistance(seg, x, z) < rideMin then
				return R.CROWN
			end
		end
	end
	return nil
end

-- IS THIS GROUP ONE THE FRONTAGE ALLOWS? A plan with no `frontage` row allows everything.
function Places.frontageAllowsGroup(plan: any, group: string?): boolean
	if plan == nil or plan.frontage == nil then
		return true
	end
	for _, each in ipairs(plan.frontage.groups) do
		if each == group then
			return true
		end
	end
	return false
end

-- ...AND THE SAME QUESTION ASKED OF A TEMPLATE NAME, which is what the mask has. Two names for one
-- rule because the two callers hold two different things, and asking the template version with a
-- GROUP answers false for every group there is -- round 2's own defect, caught by the spec.
function Places.frontageAllows(plan: any, template: string?): boolean
	return Places.frontageAllowsGroup(plan, Places.groupOf(template))
end

-- IS THIS POINT IN A FRONTAGE BAND -- within `frontage.studs` of a road or a ride centreline?
--
-- WORLD IN, `Grid.toGrid` ONCE, AND `inFrontageGrid` IS THE KERNEL -- the `mask` / `maskGrid`
-- treatment, for the same reason (round 1 finding 2): its two arms measure against a road and
-- against a RIDE, and a ride is a grid-coordinate segment, so one body cannot straddle the seam.
function Places.inFrontage(cellId: string, x: number, z: number, bend: any?): boolean
	local u, v = Grid.toGrid(x, z, bend)
	return Places.inFrontageGrid(cellId, u, v, bend)
end

-- THE SAME QUESTION IN GRID COORDINATES. `scatter` calls this one and pays no inverse.
function Places.inFrontageGrid(cellId: string, x: number, z: number, bend: any?): boolean
	local plan = Places.cellPlanFor(cellId)
	if plan == nil or plan.frontage == nil then
		return false
	end
	if Places.roadDistanceGrid(x, z, bend) <= plan.frontage.studs then
		return true
	end
	for _, seg in ipairs(cellFacts(cellId, bend).rides) do
		if segmentDistance(seg, x, z) <= plan.frontage.studs then
			return true
		end
	end
	return false
end

-- THE MIX A FRONTAGE BAND DRAWS FROM. Design 7.2 says it plainly -- *"within 60 st of any road or
-- ride centreline, only those four groups are drawn"*, and A1's spruce thicket *"becomes birch and
-- larch"* -- so it is the FOUR GROUPS, not the four a zone happens to already carry. The zone's own
-- weights are kept where they overlap and a missing group joins at weight 1, which keeps a frontage
-- in character instead of making all eight cells the same hedge.
--
-- **AND IT IS WHY THE RULE COSTS NO DENSITY.** MEASURED: taking the INTERSECTION instead left C1's
-- roadside thicket able to draw only `young`, which the front cone then refuses in the 40-140 st
-- band of every stand -- and frame `328f-AFTER-G5` (2026-11-02, cycle 2) came back as bare grass
-- where Karen had a wall of spruce. An empty mix (a clearing) stays empty: a frontage must not
-- invent a wood in one.
--
-- **IT IS A TREE RULE.** A mix carrying ground cover (`Places.HERB_GROUPS`) is passed through
-- untouched, so the fern floor can never be rewritten into a wood -- round 1, finding 1.
function Places.frontageRows(plan: any, rows: any): any
	if plan == nil or plan.frontage == nil or rows == nil or #rows == 0 then
		return rows
	end
	for _, row in ipairs(rows) do
		if (Places.HERB_GROUPS :: any)[row.group] then
			return rows
		end
	end
	local out = {}
	local carried: { [string]: boolean } = {}
	for _, row in ipairs(rows) do
		for _, each in ipairs(plan.frontage.groups) do
			if each == row.group then
				table.insert(out, row)
				carried[row.group] = true
				break
			end
		end
	end
	for _, each in ipairs(plan.frontage.groups) do
		if not carried[each] then
			table.insert(out, { group = each, weight = 1 })
		end
	end
	return out
end

-- THE GROUP A FRONTAGE SITE ACTUALLY TAKES, given the one the zone -- and then the relief bias --
-- chose. A group the frontage allows is kept, so the zone's own character survives wherever it can;
-- anything else is re-drawn from `frontage.groups`. `roll` is in [0, 1). Ground cover is never
-- rewritten (round 1, finding 1).
function Places.frontageGroupFor(plan: any, group: string, roll: number): string
	if plan == nil or plan.frontage == nil then
		return group
	end
	if (Places.HERB_GROUPS :: any)[group] or Places.frontageAllowsGroup(plan, group) then
		return group
	end
	local rows = {}
	for _, each in ipairs(plan.frontage.groups) do
		table.insert(rows, { group = each, weight = 1 })
	end
	return Places.speciesFrom(rows, roll)
end

-- WHICH LETTER A STAND IS, DERIVED FROM THE PLAN AND NEVER WRITTEN DOWN (design 8.5). A hand-written
-- table and the zones that actually stand there are two writers of one fact, and they disagree the
-- first time a recipe moves. The letters are SWARM_DESIGN section 2.1's.
Places.STAND_LETTERS = table.freeze({ "T", "V", "X", "L", "F", "P", "C", "S", "R", "O" })
-- `bend` IS A TRAILING OPTIONAL (task 328r, 328q note (j)): the letter is derived from the GRID
-- point, and a flank stand's grid v moves with the amplitude, so the parameter is what lets a case
-- drive all fifteen letters at 45/60 instead of only at whatever `Grid.CONFIG.bend` happens to say.
function Places.standTypeFor(cellId: string, standIndex: number, bend: any?): string
	local plan = Places.cellPlanFor(cellId)
	if plan == nil or Grid.cellOf(cellId) == nil then
		return "O"
	end
	for _, index in ipairs(Grid.towerStands(cellId)) do
		if index == standIndex then
			return "T"
		end
	end
	if plan.rides ~= nil then
		for _, ride in ipairs(plan.rides) do
			if ride.atStandIndex == standIndex then
				return ride.kind
			end
		end
	end
	-- THE GRID POINT, AND ONE SPACE (round 2 finding 1): `standFacing` is a grid unit vector and
	-- `zoneRect`, `zoneAt` and `rideSegments` are all grid facts, so the sight line this letter is
	-- derived from has to be the grid one too. `standPosition` is the WORLD point and would be up to
	-- 60 studs in x away from the rects it is compared against at 45/60.
	local su, sv = Grid.standGridOf(cellId, standIndex, bend)
	local spot = Vector2.new(su, sv)
	local fx, fz = Places.standFacing(cellId, standIndex, bend)
	local ax, az = spot.X + fx * Places.CONE.farStuds, spot.Y + fz * Places.CONE.farStuds
	if plan.field ~= nil then
		local field = Places.zoneRect(cellId, plan.field)
		if ax >= field.minX and ax <= field.maxX and az >= field.minZ and az <= field.maxZ then
			return "P"
		end
		local reach = Places.CONE.farStuds * 2
		if
			spot.X >= field.minX - reach
			and spot.X <= field.maxX + reach
			and spot.Y >= field.minZ - reach
			and spot.Y <= field.maxZ + reach
		then
			return "F"
		end
	end
	-- A RIDE OR A CUT CROSSING THE SIGHT LINE rather than starting at it.
	for _, seg in ipairs(Places.rideSegments(cellId, bend)) do
		if segmentDistance(seg, ax, az) <= Places.RIDE_CLEAR_STUDS then
			return "X"
		end
	end
	-- WHAT IS IN FRONT: the zone at the far edge of the managed cone, which is the ground a hunter
	-- is looking at rather than the two metres under his boots.
	local ahead = Places.zoneAt(cellId, ax, az)
	if ahead == nil then
		return "O"
	end
	if ahead.spacingStuds <= 0 then
		return "C"
	end
	if ahead.mix == "spruceThicket" or ahead.mix == "scrub" then
		return "S"
	end
	if Grid.sideOf(cellId, standIndex) == "main" then
		return "R"
	end
	return "O"
end

-- THE CELL NEAREST A POINT OUTSIDE THE GRID, by its bounding box.
function Places.nearestCellTo(x: number, z: number): string?
	-- WORLD IN, `Grid.toGrid` ONCE (task 328q, design 6.3): the boxes below are grid rectangles.
	local u, v = Grid.toGrid(x, z)
	x, z = u, v
	local best, bestD = nil, math.huge
	for _, id in ipairs(Grid.cellIds()) do
		local box = Grid.boundsOf(id)
		local dx = math.max(box.minX - x, 0, x - box.maxX)
		local dz = math.max(box.minZ - z, 0, z - box.maxZ)
		local d = dx * dx + dz * dz
		if d < bestD then
			best, bestD = id, d
		end
	end
	return best
end

-- THE MIX OF A CELL'S FRONT ZONE -- the first zone its recipe lists that draws anything.
function Places.frontMixOf(cellId: string): any
	local plan = Places.cellPlanFor(cellId)
	if plan == nil then
		return nil
	end
	for _, item in ipairs(plan.zones) do
		if item.spacingStuds > 0 then
			return Places.cellMixNamed(item.mix)
		end
	end
	return nil
end

-- THE BORDER WOOD (design 8.4): 230 studs of wood all round the grid's footprint, at 40-stud
-- spacing, drawn from the mix of the NEAREST cell's front zone -- so the wood a hunter sees over the
-- world's edge is the same wood as the cell he stands in. It closes 327c's own finding, *"a row-2
-- cell's hunter looks south out of the world"*.
--
-- PURE, like every other plan here, and NOT planted by `dressCell`: the whole-world prebuild into
-- `Workspace.GridForest` is task 328i's (design 10.1).
Places.BORDER_STUDS = 230
Places.BORDER_SPACING_STUDS = 40
function Places.borderPlan(): { Planting }
	local out: { Planting } = {}
	-- THE WORLD BOX, not the grid one (task 328q): the border wood is drawn in world coordinates and
	-- has to start outside everything the bend moved. At amplitude 0 the two boxes are equal.
	local box = Grid.worldFootprint()
	local rng = Random.new(Grid.seedFor(Grid.CELL_ORDER[1], 97))
	local depth = Places.BORDER_STUDS
	local step = Places.BORDER_SPACING_STUDS
	local rings = {
		{ minX = box.minX - depth, maxX = box.maxX + depth, minZ = box.minZ - depth, maxZ = box.minZ },
		{ minX = box.minX - depth, maxX = box.maxX + depth, minZ = box.maxZ, maxZ = box.maxZ + depth },
		{ minX = box.minX - depth, maxX = box.minX, minZ = box.minZ, maxZ = box.maxZ },
		{ minX = box.maxX, maxX = box.maxX + depth, minZ = box.minZ, maxZ = box.maxZ },
	}
	for _, rect in ipairs(rings) do
		for x = rect.minX, rect.maxX, step do
			for z = rect.minZ, rect.maxZ, step do
				local jx = x + (rng:NextNumber() - 0.5) * step * Places.JITTER
				local jz = z + (rng:NextNumber() - 0.5) * step * Places.JITTER
				local nearest = Places.nearestCellTo(jx, jz)
				local rows = if nearest ~= nil then Places.frontMixOf(nearest) else nil
				if rows ~= nil and #rows > 0 then
					local group = Places.speciesFrom(rows, rng:NextNumber())
					local names = Places.namesOf(group)
					if #names > 0 then
						table.insert(out, {
							model = names[rng:NextInteger(1, #names)],
							x = jx,
							z = jz,
							scale = math.max(Places.SCALE_FLOOR, 0.8 + rng:NextNumber() * 0.4),
							yaw = rng:NextNumber() * math.pi * 2,
							band = "wood",
							side = -1,
						})
					end
				end
			end
		end
	end
	return out
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
	local box = Grid.boundsOf(cellId)
	-- **MEASURED FROM THE ROAD CENTRELINE, NOT FROM THE CELL EDGE** -- defect F-5 (design 8.1). A
	-- cell's edge is exactly `roadClearStuds / 2` from the road that bounds it, so the old
	-- `fernBandStuds` band started 21 studs out and planted bracken through the ditch (22-30) and
	-- the verge (30-34), which design 7.1 keeps bare. `fernBand.fromStuds` is the distance from the
	-- CENTRELINE, so the inset off the cell edge is the difference.
	local band = plan.fernBand
	local from, depth
	if band ~= nil then
		from, depth = band.fromStuds, band.depthStuds
	else
		from, depth = Grid.CONFIG.roadClearStuds / 2, plan.fernBandStuds
	end
	local inset = from - Grid.CONFIG.roadClearStuds / 2
	local g = {
		minX = box.minX + inset,
		maxX = box.maxX - inset,
		minZ = box.minZ + inset,
		maxZ = box.maxZ - inset,
	}
	local w = depth
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
-- ...AND NOTHING COMES OUT BELOW `scaleFloor` (design 8.3): the shrub band's own low end is 0.25,
-- which on a larch is a 7-stud twig that reads as litter rather than as young growth.
local function scaleFor(plan: any, band: string, rng: Random): number
	local floor = plan.scaleFloor or 0
	if band == "shrub" then
		return math.max(floor, plan.shrubScale[1] + rng:NextNumber() * (plan.shrubScale[2] - plan.shrubScale[1]))
	end
	return math.max(floor, plan.woodScale[1] + rng:NextNumber() * (plan.woodScale[2] - plan.woodScale[1]))
end

-- ONE JITTERED GRID OVER ONE RECTANGLE. The same arithmetic `Places.layer` uses on a band, lifted so
-- a zone, a fern band and a skirt band are three callers of one loop rather than three copies of it.
--
-- `pick` ANSWERS (mix, band) FOR A POINT or nil to plant nothing there, which is how a clearing on the
-- far side of a road stays a clearing: the skirt asks the NEIGHBOUR's zones.
--
-- `opts` IS THE v2 HALF (task 328f) and every field is optional, so `Places.layer`'s four callers are
-- untouched: `maskCell` turns the whole of `Places.mask` on for this rectangle, `zone` carries the
-- per-zone `jitter` / `rows` / `reliefBias`, `heightAt` is the pure ground reader the relief bias
-- needs, and `cap` stops a layer at a count (the ferns' 400, B9).
type ScatterOpts = {
	maskCell: string?,
	maskPlan: any?,
	zone: any?,
	heightAt: ((number, number) -> number?)?,
	cap: number?,
	-- THE BEND, carried from `plantCell` (task 328r, 328q note (a)). nil is `Grid.CONFIG.bend`.
	bend: any?,
}
local function scatter(
	out: { Planting },
	rect: any,
	spacing: number,
	grid: any,
	gap: number,
	rng: Random,
	plan: any,
	side: number,
	pick: (number, number) -> (any, string?),
	opts: ScatterOpts?
)
	if spacing <= 0 then
		return
	end
	local o: ScatterOpts = opts or {}
	local recipe = o.zone
	-- IN ROWS, a plantation is planted: the x line is held and only the depth wanders (design 8.3).
	local rows = recipe ~= nil and recipe.rows == "NS"
	local jitter = (recipe ~= nil and recipe.jitter) or Places.JITTER
	local relief = nil
	if o.maskCell ~= nil and recipe ~= nil and recipe.reliefBias == true and o.heightAt ~= nil then
		local cell = Grid.cellOf(o.maskCell)
		if cell ~= nil and cell.relief ~= nil and cell.relief.spreadStuds > 0 then
			relief = cell.relief
		end
	end
	local planted = 0
	for x = rect.minX, rect.maxX, spacing do
		local z = rect.minZ
		while z < rect.maxZ do
			if o.cap ~= nil and planted >= o.cap then
				return
			end
			local jx = x + (if rows then 0 else (rng:NextNumber() - 0.5) * spacing * jitter)
			local jz = z + rng:NextNumber() * spacing * jitter
			z += spacing
			-- **jx / jz ARE GRID COORDINATES** and so is every rect, zone and gap below (task 328q,
			-- design 6.1). The site is mapped into the world once, for `heightAt` and the row.
			local site: string? = nil
			if o.maskCell ~= nil then
				site = Places.maskGrid(o.maskCell, jx, jz, nil, nil, o.bend)
			elseif not Places.clearOfEveryRoadGrid(jx, jz, nil, o.bend) then
				-- GRID IN, GRID OUT (328q note (i)): this arm asked a GRID point a WORLD question
				-- through `Grid.toWorld`, and `clearOfEveryRoad` mapped it straight back with
				-- `toGrid`. Two five-step inverses per site, for an answer the grid already had.
				site = "road"
			end
			if jx >= rect.minX and jx <= rect.maxX and jz >= rect.minZ and jz <= rect.maxZ and site == nil then
				local rowsFor, band = pick(jx, jz)
				if rowsFor ~= nil and band ~= nil and #rowsFor > 0 and not tooClose(grid, jx, jz, gap) then
					local wx, wz = Grid.toWorld(jx, jz, o.bend)
					local group = Places.speciesFrom(rowsFor, rng:NextNumber())
					-- THE RELIEF BIAS FIRST (design 8.3): spruce in the cold bottom, birch on the
					-- top. BEFORE the frontage, so the bias reads the zone's own wood and the
					-- frontage still has the last word -- which is what keeps a crown off the road.
					if relief ~= nil then
						local y = (o.heightAt :: any)(wx, wz)
						if y ~= nil then
							local hn = (y - relief.minY) / relief.spreadStuds
							if hn < 0.30 and group ~= "conifer" then
								group = "conifer"
							elseif hn > 0.70 and group == "conifer" then
								group = "birch"
							end
						end
					end
					-- THE FRONTAGE DRAWS FROM THE ALLOWED GROUPS rather than refusing the site,
					-- which is why the rule costs no density (design 7.2).
					--
					-- **IT IS A RULE ABOUT TREES AND IT MAY NOT TOUCH THE FLOOR** (round 1, finding
					-- 1): `fernFloor` carries one row, `fern`, which is in no `frontage.groups`, so
					-- rewriting the herb layer dropped that row, put the four TREE groups back, and
					-- planted full trees at the herb band's own 0.8-1.7 scale -- wider than the wood
					-- band's 0.8-1.2 -- on the FLOOR's neighbour grid, where `minGapStuds` could not
					-- see them against the zone layer's trunks.
					if
						band ~= "herb"
						and o.maskCell ~= nil
						and o.maskPlan ~= nil
						and Places.inFrontageGrid(o.maskCell, jx, jz, o.bend)
					then
						group = Places.frontageGroupFor(o.maskPlan, group, rng:NextNumber())
					end
					-- `namesOf` AND NOT `SPECIES` DIRECTLY: it is the one door that drops a quarantined
					-- template, so no caller can plant one (design 9.3).
					local names = Places.namesOf(group)
					if #names == 0 then
						continue
					end
					local model = names[rng:NextInteger(1, #names)]
					local scale = if band == "herb" then 0.8 + rng:NextNumber() * 0.9 else scaleFor(plan, band, rng)
					-- AND NOW THIS TREE'S OWN FACTS: the crown term, which needs the template and the
					-- scale the draw has just settled (design 7.2).
					if o.maskCell ~= nil and Places.maskGrid(o.maskCell, jx, jz, model, scale, o.bend) ~= nil then
						continue
					end
					planted += 1
					table.insert(out, {
						model = model,
						x = wx,
						z = wz,
						scale = scale,
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
--
-- `heightAt` IS OPTIONAL AND IT IS THE RELIEF BIAS'S ONE INPUT (design 8.3): a pure ground reader,
-- handed in rather than measured here, so this function stays pure OF ITS ARGUMENTS and a spec can
-- drive the bias with a synthetic hillside. Called with none, the bias is simply off and the list is
-- the same one every caller before task 328f got.
-- `bend` IS A TRAILING OPTIONAL (task 328r, 328q note (a)): the whole plan is grid-coordinate work,
-- but the mask's three road bands and the world point each row carries both move with it, so this
-- is what lets one case pin the STRAIGHT plan and the BENT plan side by side.
function Places.plantCell(cellId: string, heightAt: ((number, number) -> number?)?, bend: any?): { Planting }
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
		end, { maskCell = cellId, maskPlan = plan, zone = item, heightAt = heightAt, bend = bend })
	end
	-- THE UNDERSTOREY (task 328m), AFTER EVERY CANOPY ZONE AND ON THE SAME NEIGHBOUR GRID.
	--
	-- Karen, 2026-11-03, on C1: *"it's not broken trees it's good has to be a bit more realistic more
	-- trees but rest is good"*. A mature wood has two storeys; this one had one, so the floor between
	-- the trunks read as a lawn.
	--
	-- **THE SAME `trees` GRID AND THE SAME `minGapStuds`**, for two reasons. `tooClose` buckets by the
	-- gap it is handed, so two gaps in one grid would bucket inconsistently and the rule would stop
	-- being a rule. And sharing it is what makes the layer CLUMP: the canopy went in first, so a
	-- sapling is refused where the stems are close and planted where they are not.
	--
	-- NO `reliefBias` AND NO `heightAt`: the bias rewrites `young` to `conifer` below hn .30, and a
	-- spruce at a sapling's scale is a 1-stud-thick trunk (`Places.SPECIES.young`'s own header).
	local underRng = Random.new(Grid.seedFor(cellId, Places.CELL_STREAM.under))
	for _, item in ipairs(plan.zones) do
		local under = item.under
		if under ~= nil then
			local rows = Places.cellMixNamed(under.mix)
			-- THE SYNTHETIC RECIPE CARRIES `jitter` AND NOTHING ELSE, so an understorey is never
			-- biased by relief and never planted in rows. A `rows = "NS"` zone would get a scattered
			-- storey under a planted one; no recipe has both today (C1 has no `rows` zone).
			scatter(
				out,
				Places.zoneRect(cellId, item),
				under.spacingStuds,
				trees,
				plan.minGapStuds,
				underRng,
				plan,
				1,
				function()
					return rows, "shrub"
				end,
				{
					maskCell = cellId,
					maskPlan = plan,
					zone = { jitter = under.jitter or Places.UNDER_JITTER },
					bend = bend,
				}
			)
		end
	end
	-- THE FLOOR, on its own stream and its own neighbour grid (`Places.layer`'s own discipline: a fern
	-- under a tree is right, two ferns in one spot is not).
	--
	-- **IN W, M, B AND Bo ZONES ONLY, AND CAPPED AT 400 A CELL** (design 8.3, B9): bracken does not
	-- grow under a closed spruce thicket, and a cell that floors its whole edge in fern is 1,500
	-- extra models for ground the hunter never walks on.
	local floor = {}
	local fernRng = Random.new(Grid.seedFor(cellId, Places.CELL_STREAM.ferns))
	local fernRows = Places.cellMixNamed("fernFloor")
	local ferns = 0
	for _, rect in ipairs(Places.fernBands(cellId, plan)) do
		local before = #out
		scatter(out, rect, plan.fernSpacing, floor, 0.5 * plan.fernSpacing, fernRng, plan, 1, function(x, z)
			local zoneThere = Places.zoneAt(cellId, x, z)
			if zoneThere == nil or not Places.FERN_MIXES[zoneThere.mix] then
				return nil, nil
			end
			return fernRows, "herb"
		end, {
			maskCell = cellId,
			maskPlan = plan,
			heightAt = heightAt,
			cap = math.max(0, Places.FERN_CAP - ferns),
			bend = bend,
		})
		ferns += #out - before
	end
	-- THE SKIRT, into every neighbour, at THIS cell's density and the NEIGHBOUR's own species.
	local skirtRng = Random.new(Grid.seedFor(cellId, Places.CELL_STREAM.skirt))
	for _, near in ipairs(Places.neighboursOf(cellId)) do
		local theirPlan = Places.cellPlanFor(near.id)
		for _, band in ipairs(Places.skirtBands(cellId, near.id, near.axis, plan)) do
			scatter(out, band.rect, band.spacing, trees, plan.minGapStuds, skirtRng, plan, -1, function(x, z)
				local zoneThere = Places.zoneAt(near.id, x, z)
				if zoneThere == nil then
					return nil, nil
				end
				return Places.cellMixNamed(zoneThere.mix), zoneThere.band
			end, { maskCell = near.id, maskPlan = theirPlan, heightAt = heightAt, bend = bend })
		end
	end
	return out
end

-- WHAT A MODEL COSTS IN PARTS. MEASURED in Karen's Forest Test at task 328m's code commit: 5,104
-- parts for 1,687 planted models in C1 (`reviews/task-328m/RESULT.md`, re-derived by the Reviewer).
-- It SUPERSEDES `grid-map.md` 8.3's "~7 descendants per model", which made that section's own two
-- bounds disagree by 3,200 parts (3,600 x 7 = 25,200 against its 22,000 ceiling). It is C1's MIX, so
-- the census prints `parts` every run and this number is re-read, never trusted forever.
-- Design: docs/design/grid-roads.md 8.2. Note: docs/research/2026-11-03-curved-grid-roads.md 4.
Places.PARTS_PER_MODEL = 3.03

-- THE TWO PART CEILINGS the model caps come from. `PART_BUDGET_CELL` is DERIVED, NOT MEASURED
-- (`grid-terrain.md` 12.2): 328g's client frame -- <= 16.7 ms with <= 17,000 parts inside 1,024
-- studs -- is what can raise or lower it, and nothing may cite 8,000 as a measurement before it.
Places.PART_BUDGET_DRIVE = 22000
Places.PART_BUDGET_CELL = 8000

-- THE MODEL CAPS, COMPUTED AND NOT TYPED (lesson L-167): change a budget or the ratio and these move
-- with it. 7,260 bounds the PLAN (a typo guard) and 2,640 bounds what is DRAWN in one cell.
Places.CELL_PLAN_CAP = math.floor(Places.PART_BUDGET_DRIVE / Places.PARTS_PER_MODEL)
Places.CELL_PART_CAP = math.floor(Places.PART_BUDGET_CELL / Places.PARTS_PER_MODEL)

-- THE UPPER BOUND ON WHAT ONE CELL PLANTS, known before anything runs: every grid's cell count, with
-- nothing subtracted for the lane rule or the gap rule. `grid-roads.md` 8.2's caps bound it and
-- `grid.spec` case 14 asserts all three -- `#plantCell(id) <= this`, `this <= CELL_PLAN_CAP` and
-- `#plantCell(id) <= CELL_PART_CAP`.
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
		-- THE UNDERSTOREY IS PART OF THE BOUND (task 328m) and not an exemption from it: a second
		-- storey that the budget did not count would breach `CELL_PLAN_CAP` unseen.
		if item.under ~= nil then
			total += cells(Places.zoneRect(cellId, item), item.under.spacingStuds)
		end
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
