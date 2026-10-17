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
-- `tests/server/places.spec.luau` can assert where all ~1,800 trees go, and that not one of them is
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
-- ground has to be wider than the strip he is standing on. 12 studs is `Forest.PICK`'s own stand
-- radius rounded up, so a tree can never land inside the circle a hunter is locked to either.
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
-- `halfStripStuds`  half the cleared strip the hunters stand on
-- `beltStuds`       how deep the planted wood runs beyond the lane, each side
-- `spacingStuds`    the grid cell: one tree offered per cell, so this IS the density
-- `fernSpacing`     the same, for the floor
-- `bands`           { herbStuds, shrubStuds } measured OUTWARD from the lane edge
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
		spacingStuds = 34,
		fernSpacing = 26,
		bands = table.freeze({ herbStuds = 36, shrubStuds = 72 }),
		-- A hedge is broadleaf scrub under open-grown oaks -- ref-6 exactly: bramble at eye height,
		-- one big oak canopy over the stand.
		herb = mix({ "fern", 1 }),
		shrub = mix({ "fieldOak", 5 }, { "aspen", 4 }, { "birch", 1 }),
		wood = mix({ "fieldOak", 5 }, { "aspen", 3 }, { "birch", 2 }),
		shrubScale = table.freeze({ 0.18, 0.30 }),
		woodScale = table.freeze({ 0.85, 1.15 }),
		seed = 1932,
	}),

	-- KAREN'S PLACE 3, karen-ref-5: a cut line. A 64-stud strip (18 m -- the 10-15 m practitioners
	-- prefer for a `Schussschneise`, at the generous end so a boar is shootable crossing it), forest
	-- BOTH sides, a band of young pines right at the edge and taller mixed wood behind.
	--
	-- THE BELT IS 230 STUDS DEEP because that is 64 m, and the frames show you see 40-60 m between
	-- trunks in high forest: a belt deeper than the sight line IS the horizon, and anything beyond it
	-- is wasted. The beaters form up at z -3520, 40 studs inside the north belt's far edge, so a
	-- hunter never watches them walk in out of open ground.
	ride = table.freeze({
		halfStripStuds = 32,
		beltStuds = 230,
		northBeltStuds = 230,
		spacingStuds = 30,
		fernSpacing = 24,
		bands = table.freeze({ herbStuds = 30, shrubStuds = 80 }),
		herb = mix({ "fern", 1 }),
		-- The young pine band ref-5 is a photograph of.
		shrub = mix({ "young", 8 }, { "birch", 2 }),
		wood = mix({ "conifer", 9 }, { "birch", 4 }, { "aspen", 4 }, { "oak", 3 }),
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
		northBeltStuds = 230,
		spacingStuds = 28,
		fernSpacing = 22,
		bands = table.freeze({ herbStuds = 14, shrubStuds = 50 }),
		herb = mix({ "fern", 1 }),
		shrub = mix({ "young", 9 }, { "birch", 1 }),
		wood = mix({ "conifer", 10 }, { "birch", 6 }, { "aspen", 2 }, { "oak", 2 }),
		shrubScale = table.freeze({ 0.22, 0.40 }),
		woodScale = table.freeze({ 0.8, 1.2 }),
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
	return "wood"
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
	local span = Forest.standSpan(layout)
	-- THE RUN-OUT EITHER END, so the wood does not stop square with the end stand -- a forest that
	-- ends in a straight line across the view is the thing that reads as a stage set.
	local minX = span.minX - plan.beltStuds
	local maxX = span.maxX + plan.beltStuds
	local trees = Places.layer(layout, plan, rng, minX, maxX, plan.spacingStuds, false)
	for _, item in ipairs(trees) do
		table.insert(out, item)
	end
	local ferns = Places.layer(layout, plan, rng, minX, maxX, plan.fernSpacing, true)
	for _, item in ipairs(ferns) do
		table.insert(out, item)
	end
	return out
end

-- ONE LAYER OF THE GRID -- the trees, or the floor. Split out because the two want different cell
-- sizes over the same ground, and because a spec can then drive one without the other.
function Places.layer(
	layout: any,
	plan: any,
	rng: Random,
	minX: number,
	maxX: number,
	spacing: number,
	floor: boolean
): { Planting }
	local out: { Planting } = {}
	local lane = plan.halfStripStuds + Places.LANE_STUDS
	for x = minX, maxX, spacing do
		local lineZ = Forest.roadZ(x, layout)
		for _, side in ipairs({ -1, 1 }) do
			local depth = if side > 0 then plan.northBeltStuds else plan.beltStuds
			local from = lane
			while from < lane + depth do
				local jx = x + (rng:NextNumber() - 0.5) * spacing * Places.JITTER
				local jz = from + rng:NextNumber() * spacing * Places.JITTER
				local z = lineZ + side * jz
				from += spacing
				-- THE SUBTRACTION, re-asked at the JITTERED point and not at the cell's centre --
				-- which is the only version that is true, because the jitter is what could have
				-- walked it into the lane. On a curved layout it is also re-asked at the jittered x,
				-- whose line z differs from the cell's.
				if not Places.inLane(jx, z, layout, plan) then
					local band = Places.bandAt(math.abs(z - Forest.roadZ(jx, layout)) - lane, plan)
					if band ~= nil then
						local wantFloor = floor or band == "herb"
						if wantFloor == floor then
							local group =
								Places.speciesFrom(if floor then plan.herb else (plan :: any)[band], rng:NextNumber())
							local names = (Places.SPECIES :: any)[group]
							local scale = 1
							if not floor then
								local range = if band == "shrub" then plan.shrubScale else plan.woodScale
								scale = range[1] + rng:NextNumber() * (range[2] - range[1])
							else
								scale = 0.8 + rng:NextNumber() * 0.9
							end
							table.insert(out, {
								model = names[rng:NextInteger(1, #names)],
								x = jx,
								z = z,
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
	end
	return out
end

-- THE UPPER BOUND ON WHAT A PLACE PLANTS, known before anything is cloned. A number that can be
-- asserted is what stops a density tweak quietly becoming a 20,000-part world.
function Places.capacity(layout: any, plan: any): number
	if layout == nil or plan == nil then
		return 0
	end
	local span = Forest.standSpan(layout)
	local width = (span.maxX - span.minX) + 2 * plan.beltStuds
	local depth = plan.beltStuds + plan.northBeltStuds
	local columns = math.floor(width / plan.spacingStuds) + 1
	local fernColumns = math.floor(width / plan.fernSpacing) + 1
	return columns * (math.ceil(depth / plan.spacingStuds) + 2)
		+ fernColumns * (math.ceil(depth / plan.fernSpacing) + 2)
end

return Places
