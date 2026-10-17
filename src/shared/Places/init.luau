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
-- THE STRIP IS A SUBTRACTION, NOT A SHAPE. Nothing is planted within `halfStripStuds + LANE_STUDS`
-- of the line. That is the one rule that keeps the shooting lanes clear -- `places.spec` asserts it
-- over every planting of every place -- rather than a row of trees a later tweak could walk inward.
--
-- Design: docs/design/drive-places.md
-- Note:   docs/research/2026-10-17-four-driven-hunt-places.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Forest = require(ReplicatedStorage:WaitForChild("ForestTest"))

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
	band: string, -- "herb" | "shrub" | "wood", for the report and the spec
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
	-- straight across this whole stand span), and the FIELD is the 504 studs of open ground between.
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
		-- THE ONE PAINTED SURFACE IN THE WHOLE SYSTEM (design 7.3). karen-ref-1 is bare soil and leaf
		-- litter under the trees, which is the one surface the frames demand and our assets can give --
		-- the road's gravel is Karen's own Studio content, the ride IS grassy in ref-5, and painting
		-- place 2's field `Ground` would make a ploughed field, a different place from ref-6.
		--
		-- 18 STUDS IS 5 m, source B's `Rueckegasse` at its generous end. Only Grass and LeafyGrass are
		-- replaced, so where this track crosses the world's own Limestone or Asphalt it stays rock.
		surface = table.freeze({ halfWidthStuds = 9, material = Enum.Material.Ground }),
		seed = 1934,
	}),
})

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
	return math.abs(z - lineZ) <= plan.halfStripStuds + Places.LANE_STUDS
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
						if jx >= minX and jx <= maxX and not Places.inLane(jx, z, layout, plan) then
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

-- THE UPPER BOUND ON WHAT A PLACE PLANTS, known before anything is cloned. A number that can be
-- asserted is what stops a density tweak quietly becoming a 20,000-part world. It counts the deep
-- band at its own coarser cell (design 10.2) over the SURVEYED width (design 10.5).
function Places.capacity(layout: any, plan: any): number
	if layout == nil or plan == nil then
		return 0
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
