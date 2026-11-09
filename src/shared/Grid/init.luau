--!strict
-- Grid: ONE WORLD, EIGHT DRIVE CELLS, and nothing but arithmetic over a surveyed footprint.
--
-- Karen, 2026-11-01: *"imagine one big terrain ... road vertical and horizintal in the middle ...
-- then 8 rectangles. So each line is road forest road where hunter can stand"*.
--
-- PURE, AND IT REQUIRES NOTHING BUT `Shotgun` (for the slug's range, which section 7 derives the
-- flank set-back from). `ForestTest` will require `Grid`; `Grid` never requires `ForestTest`.
--
-- Design: docs/design/grid-map.md (sections 4, 6, 7)
-- Note:   docs/research/2026-11-01-the-grid-map.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Grid = {}

-- THE STRING `Map.EXPECTED_WORLD` RESOLVES TO when the switch is thrown (task 327d). Nothing reads
-- it yet: 327a adds no world.
Grid.VERSION = "grid:v1"

-- ---------------------------------------------------------------- the numbers

-- EVERY NUMBER THE WORLD'S SHAPE IS MADE OF, and all of them derived (design 4.1) at 1 stud = 0.28 m.
--
-- `originX` / `originZ` ARE THE FOOTPRINT'S MIN CORNER, AND THEY WERE SURVEYED, NOT CHOSEN. Task
-- 327a scanned a 100-stud lattice over x,z in [-7200, 7200] of Karen's own terrain (21,025 rays),
-- bucketed every `BasePart` in `Workspace` into it and ranked all 10,656 windows of this size:
-- twelve hold 100 % terrain, ZERO non-terrain parts and a 300-stud margin of terrain all round, and
-- this is the one whose WORST cell still carries the most relief. Re-measured at 20 studs over the
-- chosen block: 33,750/33,750 terrain hits, 0 parts inside.
Grid.CONFIG = table.freeze({
	originX = -6700,
	originZ = -6600,
	-- Karen's 300 m x 400 m, rounded to 10 studs.
	cellWidthStuds = 1070,
	cellDepthStuds = 1430,
	-- 2 x (halfStrip 9 + `Places.LANE_STUDS` 12) -- the `track` place's measured clear width, which
	-- is what no tree may stand in. The PAINTED strip is narrower (design 4.1).
	roadClearStuds = 42,
	roadPaintStuds = 18,
	rows = 2,
	columns = 4,
	-- MEASURED, NOT MODELLED (task 327d2). Design 4.3's "1430 / 5.2 = 275 s" leaves out
	-- `GOAL_PAST_LINE_STUDS` 20 and the ground: one live drive in Karen's Forest Test crossed at
	-- 292.9 s, so the 300 s clock ended every drive and `END_ON_BEATERS_CROSS` never fired.
	-- 1450 / 5.64 = 257 s flat, x1.051 measured ground = 270 s, + 15 s grace = 285 s inside the
	-- 300 s clock. The Director's number, 2026-11-09; `ESCALATE.md` holds the arithmetic.
	beaterWalkStudsPerSecond = 5.64,
	-- THE MAIN LINE: 7 stands at Karen's accepted 150 studs (42 m), 900 of the cell's 1070 with
	-- 85 studs of run-out each end.
	--
	-- KAREN'S TWO OPEN CALLS LIVE IN THESE FOUR ROWS (design 15, K-1 and K-4), and they are the
	-- design's defaults until she answers: K-1 is "stands on three sides, NONE on the beaters'
	-- side" -- `Grid.roadsOf().muster` carries no stand, which is `sideOf`'s three answers -- and
	-- K-4 is "fifteen stands per cell", which is `mainStandCount + 2 * flankStandCount`. Both move
	-- here and nowhere else.
	mainStandCount = 7,
	mainSpacingStuds = 150,
	-- A FLANK: 4 stands at 220 studs (61.6 m) -- wider, because a flank sees fewer crossings over a
	-- longer frontage.
	flankStandCount = 4,
	flankSpacingStuds = 220,
	-- HOW MUCH MARGIN THE FLANK SET-BACK CARRIES OVER THE SLUG'S RANGE. The set-back itself is
	-- DERIVED (`Grid.flankFirstStuds`), never written down: design 7 solves
	-- `sqrt(330^2 - 106^2) = 312.5` and states the answer as 340, which is `ceil(312.5) + 27`.
	flankMarginStuds = 27,
	-- THE WORLD SEED. Every per-cell stream hashes from it (`Grid.seedFor`), so a cell's wood is the
	-- same whatever order the cells were built in -- Minecraft's own per-chunk rule (note section 2B).
	seed = 327_001,
	-- THE BEND. Karen, 2026-11-03: *"road could be also not just straight make line in real life"*.
	-- One sine per axis, half-wavelength = the junction pitch, so the offset is exactly 0 at every
	-- junction. Born at 0 in 328q; SWITCHED ON HERE BY COMMIT (task 79's map-switch exception,
	-- CLAUDE.md "Feature flags"), never by a flag -- the ground is baked to these numbers and a
	-- flag-off build would plant trees into the real ditch.
	-- Design: docs/design/grid-roads.md 4, 5, 9.1-9.3.
	bend = table.freeze({
		ewStuds = 45, -- the east-west family (the main and muster lines); design 5.2
		nsStuds = 60, -- the north-south family (the flanks); design 5.2
		harmonic = 1, -- bends per junction span. AN INTEGER, OR THE JUNCTIONS STOP BEING ZEROS
	}),
})

-- THE ENGINE'S TERRAIN VOXEL and the trunk-free half-width, HELD HERE ONLY BECAUSE `bendFacts`
-- NEEDS THEM AND `Grid` REQUIRES NOTHING BUT `Shotgun`. One fact each with `Relief.VOXEL` and
-- `Places.ROAD_TRUNK_FLOOR_STUDS`; `grid_ground.spec` and `grid_relief.spec` assert the equalities,
-- so a second copy cannot drift silently.
Grid.VOXEL_STUDS = 4
Grid.TRUNK_FLOOR_STUDS = 34

-- WEST TO EAST, and the id is the column letter plus the row number, so `Places.CELL_PLANS`,
-- `HighSeats.STANDS`, `ForestTest.LAYOUTS` and the vote's wire all key on one string.
Grid.COLUMN_LETTERS = table.freeze({ "A", "B", "C", "D" })

-- THE FALLBACK CYCLE, and the order the eight rows are written in. Row 1 is the NORTH row (the
-- larger z), because this world's drives all push south (`ForestTest.EXIT_SOUTH_STUDS`).
Grid.CELL_ORDER = table.freeze({ "A1", "B1", "C1", "D1", "A2", "B2", "C2", "D2" })

-- THE CELL A SESSION FALLS BACK TO, so a boot with no drive dealt yet stands ONE cell rather than
-- none. `Cells.wantedCell` and `Places.build`'s boot dress are its two readers, and it is
-- `PLANTED_CELLS[1]` so those two and the rotation's first deal are the same cell.
-- C1 BECAUSE IT HAS THE MOST TO SHOW: the only cell whose tower measurement takes three stands, on
-- both flanks, with no relief relaxation. It was `PREVIEW_CELL` until task 327d retired the preview.
Grid.DEFAULT_CELL = "C1"

-- WHICH CELLS HAVE A WOOD (task 328i). Karen, 2026-11-04: *"more trees behind the line"* -- there
-- were none, because `Places.build` dressed `DEFAULT_CELL` and nothing else.
--
-- **SINCE TASK 327d THIS LIST IS ALSO THE ROTATION**: `ForestTest.LAYOUT_ORDER` IS this table, so
-- "the rotation deals only the cells that have a wood" is true by construction and not by a second
-- hand-written list that could drift. A1 is absent from both for the same one reason.
--
-- **THE LIST IS THE CELLS WHOSE GROUND IS BAKED, and that is a reading, not a preference**: a wood
-- planted on ground that is about to be re-baked is work thrown away, and its trees would be seated
-- on a shape that no longer exists. 328x baked `B1,C1,D1,A2,B2,C2,D2` and HELD B2 and D2's landform
-- (`--hold-landform`), so those two still carry the raw base; A1 was never in a bake at all. That
-- leaves five. **C1 IS FIRST** because `dressCells` plants in the order given and a player stands in
-- it; **C2 IS SECOND** because it is the cell behind C1's hunter line, which is the one Karen named.
-- TASK 336 ADDS B2 AND D2, and the question their ground raised was answered by MEASUREMENT and
-- not by argument: both carry the raw base (328x held their landform), so a tree there might have
-- stood on a cliff. `tools/terrainbake.py plant` rays EVERY site and reports the ones it refuses as
-- `cliff`, and the task's request pastes that count per cell -- a held landform is not the same as
-- no landform, which is what kept them out until now.
-- A1 IS STILL ABSENT and is the one cell with no ground to plant on at all.
Grid.PLANTED_CELLS = table.freeze({ "C1", "C2", "A2", "B1", "D1", "B2", "D2" })

-- THE EIGHT CELLS. **`relief` IS MEASURED AND NOT WRITTEN** (design 4.4): no terrain height is
-- generated anywhere, because 13.41 M sq studs is ~750 `MapGen` tiles and ~50 minutes of Edit-time
-- build over ground Karen already bought (rule 7). The four values below come from task 327a's own
-- survey of THIS footprint, on a 20-stud lattice (33,750 rays), and `character` is classified by a
-- rule rather than picked: spread < 20 is `flat`; |north-south tilt| >= half the spread is `slope`;
-- a middle third 0.25 of the spread above or below the outer thirds is `ridge` or `dip`; anything
-- else is `rolling`.
--
-- `lineMeanY` is the mean terrain height along the cell's own 1070-stud main line (54 samples). It
-- is what task 327b hands to `Layout.centre.Y`, which that record documents as a FALLBACK ground
-- reached only in a column with no terrain in it -- so it has to be this line's own mean and not the
-- cell's midpoint.
--
-- `towers` IS THE SAME KIND OF THING -- MEASURED, NOT CHOSEN (task 327b, design 6.1). All 120
-- stands were measured in a PLAY session in Karen's place with task 218's own instrument
-- (`driven-hunt-runs/327b-towers.luau`, which is `218-sight2.luau` reading `Grid.standPosition`):
-- `gain` is how much further a fan of seven rays reaches north from a deck eye 12.5 studs up than
-- from a ground eye, `spread` the spread of the five footprint grounds, `relief` the roll of the
-- terrain in the stand's own 12-stud circle. Ranked by gain, taken while under `HighSeats.capFor`
-- (5), never two adjacent, `gain >= 60`, `spread <= 4.0`, `relief <= 1.8`.
--
-- **THE WHOLE OF ROW 2 NEEDED THE RELIEF TEST RELAXED, AND IT IS DECLARED RATHER THAN HIDDEN**
-- (`towersRelaxed`, design 6.2 rule 4, exactly as task 218 declared it for `edge`): the four
-- southern cells carry 98-173 studs of spread, and NOT ONE of their stands rolls less than 1.8
-- studs inside its own circle. Each takes ONE tower, and the platform rule is defeatable at a jump
-- apex from the high side of it. **One deviation from 218's rule, named:** a relaxed cell takes the
-- LOWEST-RELIEF candidate rather than the highest-gain one, because the relaxation exists only
-- because relief fails, so the tie-break is the one that breaks it least -- D2 stand 3 scores +160
-- at relief 9.88 against stand 12's +155 at 2.79.
--
-- **A FLANK ROW IS SHARED GROUND AND ITS NUMBERS REPEAT ON PURPOSE** (round 1 finding 3). Two
-- neighbouring cells have ONE road between them, so B1's east flank stand 12 and C1's west flank
-- stand 8 are THE SAME WORLD POINT (-4455, -4767), and so are C1 13 / D1 9 (-3343, -4547) and
-- C1 15 / D1 11 (-3343, -4107). Three triplets therefore read identically across three cells: that
-- is one measurement of one piece of ground quoted twice, not a copied row.
--
-- **AND NOT ONE CELL HAS A TOWER ON EVERY SIDE**, which design 6.1 asks for ("at least one per
-- side"). DECLARED, not hidden: the selection rule the design itself states -- rank by gain, take
-- while under the cap, no two adjacent, three thresholds -- has no per-side term, so it cannot
-- produce one, and the ground is what it is. The design correction is queued, not invented here.
--
-- A later task that GENERATES the relief writes the same fields from its own heightfield and no
-- assertion in `grid.spec` moves.
--
-- `recipe` NAMES THE ROW IN `Places.CELL_PLANS` THIS CELL IS DRESSED WITH (task 327c), and it is
-- chosen from the MEASURED `relief.character` above -- character, then recipe (design 12D). It is
-- a string and not the recipe itself, so `Grid` still requires nothing. `animals` (327h) is not
-- here yet.
Grid.CELLS = table.freeze({
	table.freeze({
		id = "A1",
		row = 1,
		column = 1,
		-- THE WOOD THAT GROWS HERE (task 327c): the slope's thicket on the low ground.
		recipe = "spruceSlope",
		relief = table.freeze({
			character = "slope",
			minY = 51.2,
			maxY = 164.6,
			spreadStuds = 113.4,
			lineSpreadStuds = 14.1,
			lineMeanY = 61.76,
		}),
		towers = table.freeze({ 8 }), -- 8 west gain +125, spread 0.20, relief 1.67
	}),
	table.freeze({
		id = "B1",
		row = 1,
		column = 2,
		-- THE WOOD THAT GROWS HERE (task 336): spruce, wall to wall, nothing else.
		recipe = "spruceRidge",
		-- MEASURED AFTER B1's FIRST BAKE (task 328h), off the ground it describes:
		-- `terrainbake.py survey --cells B1,C1,D1` over 3,888 samples, and `lineSpreadStuds` off 54
		-- samples along the realised main line (`<runs-dir>/328h-line.luau`). `character` is 327c's
		-- own word and is a LABEL, not a reading -- the survey's three-way classifier would say
		-- "ridge" at this spread, and `grid.spec` accepts both vocabularies.
		relief = table.freeze({
			character = "slope",
			minY = 66.05,
			maxY = 189.54,
			spreadStuds = 123.50,
			lineSpreadStuds = 22.82,
			lineMeanY = 81.29,
		}),
		-- RE-MEASURED IN A PLAY SESSION (task 328h; design 6.1 -- an Edit run reads
		-- `DrivePlaces=ABSENT`), 218's instrument over B1's fifteen stands at their bent world
		-- points. Ranked by gain, never two adjacent, `gain >= 60`, `spread <= 4.0`,
		-- `relief <= 1.8`: 14 (+216), 10 (+153), 12 (+120), 8 (+116) -- 15 (+180) is adjacent to
		-- 14, 9 (+137) to 10, 13 (+89) to both. NO MAIN STAND CLEARS +60 on this ground. Every one
		-- of the fifteen pads read `spread 0.00` and `relief <= 0.12`, so `towersRelaxed` is absent.
		towers = table.freeze({ 8, 10, 12, 14 }), -- 8 west +116/0.00/0.09; 10 west +153/0.00/0.12; 12 east +120/0.00/0.01; 14 east +216/0.00/0.11
	}),
	table.freeze({
		id = "C1",
		row = 1,
		column = 3,
		-- THE WOOD THAT GROWS HERE (task 327c): seven zones, four woods -- the preview cell.
		recipe = "mixedRolling",
		-- RE-MEASURED AFTER THE 45/60 RE-BAKE (task 328r), off the ground it describes:
		-- `tools/terrainbake.py survey --cells C1` over 3,888 samples, each one the world point its
		-- GRID station maps to. `character` does not move -- the spread went 61.7 -> 61.12.
		relief = table.freeze({
			character = "rolling",
			minY = 89.14,
			maxY = 150.26,
			spreadStuds = 61.12,
			lineSpreadStuds = 20.49,
			lineMeanY = 106.03,
		}),
		-- RE-MEASURED TOO (task 328r), with 327b's own instrument over C1's fifteen stands at their
		-- new world points (`<runs-dir>/328r-towers.luau`). Ranked by gain, never two adjacent,
		-- `gain >= 60`, `spread <= 4.0`, `relief <= 1.8`: 13 (+234), then 10 (+216), then 8 (+120)
		-- -- 11 (+180) and 9 (+89) are adjacent to 10, and 14 (+120) is adjacent to 13. **15 LEFT
		-- THE SET**: the bend turned its sight line and its gain fell +95 -> +40, under the 60
		-- floor. Every one of the fifteen pads measured `spread 0.00` and `relief <= 0.10`, so
		-- `towersRelaxed` stays absent for C1, which is what design 11.4 said to expect.
		towers = table.freeze({ 8, 10, 13 }), -- 8 west +120/0.00/0.01; 10 west +216/0.00/0.10; 13 east +234/0.00/0.03
	}),
	table.freeze({
		id = "D1",
		row = 1,
		column = 4,
		-- THE WOOD THAT GROWS HERE (task 336): oak, wall to wall, less the meadow (task 327c's park).
		recipe = "oakRolling",
		-- MEASURED AFTER D1's FIRST BAKE (task 328h), same two instruments as B1 above.
		relief = table.freeze({
			character = "rolling",
			minY = 101.83,
			maxY = 166.26,
			spreadStuds = 64.43,
			lineSpreadStuds = 36.27,
			lineMeanY = 135.85,
		}),
		-- RE-MEASURED IN PLAY (task 328h): only 9 (+234) and 10 (+120) clear the +60 floor and they
		-- are adjacent, so the set is ONE. **11 LEFT THE SET** -- its gain fell +95 -> +40 when the
		-- bake cut the road it overlooks. All fifteen pads `spread 0.00`, `relief <= 0.08`.
		towers = table.freeze({ 9 }), -- 9 west +234/0.00/0.03
	}),
	table.freeze({
		id = "A2",
		row = 2,
		column = 1,
		-- THE WOOD THAT GROWS HERE (task 336): aspen, in the plantation rows this cell always had.
		recipe = "aspenRolling",
		relief = table.freeze({
			character = "rolling",
			minY = 54.8,
			maxY = 152.5,
			spreadStuds = 97.7,
			lineSpreadStuds = 42.2,
			lineMeanY = 115.44,
		}),
		towers = table.freeze({ 7 }), -- 7 main gain +88, spread 1.01, relief 3.57 -- RELAXED (best relief of 1 candidate)
		towersRelaxed = true,
	}),
	table.freeze({
		id = "B2",
		row = 2,
		column = 2,
		-- THE WOOD THAT GROWS HERE (task 336): larch -- this world's SMALLEST trees, on its steepest line.
		recipe = "larchSlope",
		relief = table.freeze({
			character = "slope",
			minY = 69.4,
			maxY = 199.3,
			spreadStuds = 129.9,
			lineSpreadStuds = 61.3,
			lineMeanY = 181.83,
		}),
		towers = table.freeze({ 2 }), -- 2 main gain +163, spread 1.08, relief 2.13 -- RELAXED (best relief of 2 candidates)
		towersRelaxed = true,
	}),
	table.freeze({
		id = "C2",
		row = 2,
		column = 3,
		-- THE WOOD THAT GROWS HERE (task 336): spruce and birch, mixed half and half.
		recipe = "spruceBirchRolling",
		relief = table.freeze({
			character = "rolling",
			minY = 94.6,
			maxY = 237.2,
			spreadStuds = 142.7,
			lineSpreadStuds = 53.6,
			lineMeanY = 211.22,
		}),
		towers = table.freeze({ 14 }), -- 14 east gain +141, spread 1.66, relief 6.70 -- RELAXED (only candidate)
		towersRelaxed = true,
	}),
	table.freeze({
		id = "D2",
		row = 2,
		column = 4,
		-- THE WOOD THAT GROWS HERE (task 336): field oak and aspen, mixed half and half.
		recipe = "oakAspenRolling",
		relief = table.freeze({
			character = "rolling",
			-- THE STEEPEST CELL OF THE EIGHT, and it is reported rather than smoothed: 173 studs over
			-- 1070 x 1430 is an 11 % average grade, and its main line alone reads 70 studs.
			minY = 115.1,
			maxY = 288.1,
			spreadStuds = 173.0,
			lineSpreadStuds = 70.2,
			lineMeanY = 252.01,
		}),
		towers = table.freeze({ 12 }), -- 12 east gain +155, spread 0.87, relief 2.79 -- RELAXED (best relief of 4; stand 3 scores +160 at relief 9.88)
		towersRelaxed = true,
	}),
})

-- ---------------------------------------------------------------- the cells

local BY_ID: { [string]: any } = {}
for _, cell in ipairs(Grid.CELLS) do
	BY_ID[cell.id] = cell
end

-- A FRESH COPY, so a caller that shuffles its own bag cannot shuffle the table
-- (`ForestTest.layoutNames`' own discipline).
function Grid.cellIds(): { string }
	return table.clone(Grid.CELL_ORDER)
end

-- THE CELL, OR NIL for a name nobody knows -- which is what makes "a typo gets no cell rather than
-- the wrong cell" possible all the way out to the client.
function Grid.cellOf(id: string?): any
	if type(id) ~= "string" then
		return nil
	end
	return BY_ID[id]
end

-- THE WHOLE WORLD'S BOUNDS: 4 x 1070 + 5 x 42 by 2 x 1430 + 3 x 42 (design 4.1). Three east-west
-- roads (2 border + 1 middle) and five north-south roads (2 border + 3 interior) -- the border road
-- is FORCED, not optional: without it the eight outer cells have only two or three roads, and D4
-- says the active cell's bordering road sides are the hunter line.
function Grid.footprint(): { minX: number, maxX: number, minZ: number, maxZ: number }
	local c = Grid.CONFIG
	return {
		minX = c.originX,
		maxX = c.originX + c.columns * c.cellWidthStuds + (c.columns + 1) * c.roadClearStuds,
		minZ = c.originZ,
		maxZ = c.originZ + c.rows * c.cellDepthStuds + (c.rows + 1) * c.roadClearStuds,
	}
end

-- A CELL'S INTERIOR -- the ground inside its four roads, which is where its wood goes and where its
-- animals start. The roads themselves are outside every cell, so no two cells overlap and no cell
-- holds a road.
function Grid.boundsOf(id: string): { minX: number, maxX: number, minZ: number, maxZ: number }
	local cell = Grid.cellOf(id)
	assert(cell ~= nil, "Grid.boundsOf: no such cell")
	local c = Grid.CONFIG
	local minX = c.originX + c.roadClearStuds + (cell.column - 1) * (c.cellWidthStuds + c.roadClearStuds)
	-- ROW 1 IS THE NORTH ROW, so it sits past the middle road; row 2 is against the south border.
	local rowsFromSouth = c.rows - cell.row
	local minZ = c.originZ + c.roadClearStuds + rowsFromSouth * (c.cellDepthStuds + c.roadClearStuds)
	return { minX = minX, maxX = minX + c.cellWidthStuds, minZ = minZ, maxZ = minZ + c.cellDepthStuds }
end

-- ---------------------------------------------------------------- the roads

export type Road = {
	id: string,
	-- WHICH WAY IT RUNS: "x" is an east-west road (a hunter line or a muster line), "z" a
	-- north-south one (a flank).
	axis: string,
	-- THE OTHER COORDINATE: the road's own centre line.
	at: number,
	from: number,
	to: number,
}

-- EVERY ROAD IN THE WORLD, in a fixed order: the three east-west roads south to north, then the
-- five north-south roads west to east. Fresh tables each call.
function Grid.roads(): { Road }
	local c = Grid.CONFIG
	local box = Grid.footprint()
	local half = c.roadClearStuds / 2
	local out: { Road } = {}
	for row = 0, c.rows do
		table.insert(out, {
			id = "EW" .. tostring(row + 1),
			axis = "x",
			at = c.originZ + half + row * (c.cellDepthStuds + c.roadClearStuds),
			from = box.minX,
			to = box.maxX,
		})
	end
	for column = 0, c.columns do
		table.insert(out, {
			id = "NS" .. tostring(column + 1),
			axis = "z",
			at = c.originX + half + column * (c.cellWidthStuds + c.roadClearStuds),
			from = box.minZ,
			to = box.maxZ,
		})
	end
	return out
end

-- THE FOUR ROADS THAT BOUND ONE CELL, by the job each does in a drive (design 4.2). Every drive
-- pushes SOUTH, so the main line is always the cell's south road and the beaters always muster on
-- its north one -- which means the middle road is a hunter line for row 1 and a muster line for
-- row 2, and over a cycle a hunter stands on every road in the world.
function Grid.roadsOf(id: string): { main: Road, west: Road, east: Road, muster: Road }
	local cell = Grid.cellOf(id)
	assert(cell ~= nil, "Grid.roadsOf: no such cell")
	local c = Grid.CONFIG
	local roads = Grid.roads()
	local ewCount = c.rows + 1
	local rowsFromSouth = c.rows - cell.row
	return {
		main = roads[rowsFromSouth + 1],
		muster = roads[rowsFromSouth + 2],
		west = roads[ewCount + cell.column],
		east = roads[ewCount + cell.column + 1],
	}
end

-- ---------------------------------------------------------------- the bend (design 5, task 328q)

export type Bend = { ewStuds: number, nsStuds: number, harmonic: number }

-- THE BEND IS A TRAILING OPTIONAL on every function below -- the idiom `layoutFor`, `spook`,
-- `beater` and `rest` already use. The arithmetic is pure in a table handed in, so a spec can ask
-- any amplitude anything with no world running and BOTH STATES ARE REACHABLE BY PARAMETER.
local function bendOf(bend: Bend?): Bend
	return (bend or Grid.CONFIG.bend) :: Bend
end

-- THE TWO JUNCTION PITCHES, which are not a choice (design 5.1): the half-wavelength IS the pitch
-- between junctions, so `sin(pi * harmonic * k)` is exactly 0 at every one of them.
--   axis "x" (the east-west family): junctions are the five north-south road centres, 1112 apart
--   axis "z" (the north-south family): the three east-west road centres, 1472 apart
function Grid.bendPitch(axis: string): number
	local c = Grid.CONFIG
	if axis == "x" then
		return c.cellWidthStuds + c.roadClearStuds
	end
	return c.cellDepthStuds + c.roadClearStuds
end

-- THE FIRST JUNCTION OF EACH FAMILY -- the phase reference, so a road centre is a ZERO of the other
-- family and not an extremum. `Grid.roads()`' own arithmetic: `origin + roadClear/2`.
function Grid.bendOrigin(axis: string): number
	local c = Grid.CONFIG
	return (if axis == "x" then c.originX else c.originZ) + c.roadClearStuds / 2
end

-- THE EAST-WEST FAMILY'S z OFFSET AT A WORLD x. Every east-west road is this one curve plus its own
-- `at`, so the three of them are EXACT TRANSLATES and a cell's depth is `cellDepthStuds` along
-- every column (design 2 item 3 -- the property that keeps the beater walk one quotient).
function Grid.bendZ(x: number, bend: Bend?): number
	local b = bendOf(bend)
	if b.ewStuds == 0 then
		return 0
	end
	local pitch = Grid.bendPitch("x")
	return b.ewStuds * math.sin(math.pi * b.harmonic * (x - Grid.bendOrigin("x")) / pitch)
end

-- THE NORTH-SOUTH FAMILY'S x OFFSET AT A WORLD z.
function Grid.bendX(z: number, bend: Bend?): number
	local b = bendOf(bend)
	if b.nsStuds == 0 then
		return 0
	end
	local pitch = Grid.bendPitch("z")
	return b.nsStuds * math.sin(math.pi * b.harmonic * (z - Grid.bendOrigin("z")) / pitch)
end

-- d(bendZ)/dx and d(bendX)/dz, for the tangent, the normal and the perpendicular measure (5.5).
function Grid.bendSlopeZ(x: number, bend: Bend?): number
	local b = bendOf(bend)
	if b.ewStuds == 0 then
		return 0
	end
	local k = math.pi * b.harmonic / Grid.bendPitch("x")
	return b.ewStuds * k * math.cos(k * (x - Grid.bendOrigin("x")))
end

function Grid.bendSlopeX(z: number, bend: Bend?): number
	local b = bendOf(bend)
	if b.nsStuds == 0 then
		return 0
	end
	local k = math.pi * b.harmonic / Grid.bendPitch("z")
	return b.nsStuds * k * math.cos(k * (z - Grid.bendOrigin("z")))
end

-- HOW FAR ANY WORLD BOX HAS TO GROW to hold what the bend moved into it: the larger amplitude, on
-- both axes, because an east-west road wanders in z and a north-south one in x.
function Grid.maxBendStuds(bend: Bend?): number
	local b = bendOf(bend)
	return math.max(b.ewStuds, b.nsStuds)
end

-- ---- THE TWO MAPS, and `toGrid` IS THE DEFINITION (design 5.6).
--
-- In GRID coordinates every road is straight at its own `at`, which is why `Relief`, the whole of
-- `Places` and every zone, ride, cone and corridor keep their arithmetic unchanged. The world is
-- that plane sheared by the two sines:
--
--   u = x - bendX(z)        v = z - bendZ(x)        (closed form, this direction)
--   x = u + bendX(z)        z = v + bendZ(x)        (implicit, solved by the fixed point below)
function Grid.toGrid(x: number, z: number, bend: Bend?): (number, number)
	return x - Grid.bendX(z, bend), z - Grid.bendZ(x, bend)
end

-- THE NUMERIC INVERSE, five fixed-point steps. The contraction per step is |bendZ'| * |bendX'| <=
-- 0.0163, so from a 60-stud initial error 4 steps reach 4e-6 studs and 5 reach 7e-8 (design 5.6).
-- ONE DIRECTION ONLY WOULD BE A SECOND DEFINITION of where the roads are, so this is an inverse of
-- `toGrid` and never a second sine.
Grid.TO_WORLD_STEPS = 5
function Grid.toWorld(u: number, v: number, bend: Bend?): (number, number)
	local b = bendOf(bend)
	if b.ewStuds == 0 and b.nsStuds == 0 then
		-- EXACT, not an approximation: at amplitude 0 both sines are 0 and the map is the identity.
		return u, v
	end
	local x, z = u, v
	for _ = 1, Grid.TO_WORLD_STEPS do
		x = u + Grid.bendX(z, b)
		z = v + Grid.bendZ(x, b)
	end
	return x, z
end

-- WHERE A ROAD'S CENTRELINE IS, in the world, at one station along it: its own `at` plus the OTHER
-- family's bend. `along` is the WORLD coordinate the road runs in (x for an east-west road, z for a
-- north-south one), which is what the bake and the map both already have in hand.
--
-- THE ONE DEFINITION. `TerrainBake.roadAt`, `longProfile`, `profileSamples`, `TerrainBake`'s and
-- `Places`' two `roadDistance`s and `Hud.MapUi` all ask this; none of them re-types a sine.
function Grid.roadCentreAt(road: Road, along: number, bend: Bend?): number
	if road.axis == "x" then
		return road.at + Grid.bendZ(along, bend)
	end
	return road.at + Grid.bendX(along, bend)
end

-- THE ROAD'S DIRECTION AT ONE STATION, in degrees off its own axis. 0 at every junction, +-7.3 at
-- the shipped amplitudes (design 5.2's one rule for the pair).
function Grid.roadTangentDeg(road: Road, along: number, bend: Bend?): number
	local slope = if road.axis == "x" then Grid.bendSlopeZ(along, bend) else Grid.bendSlopeX(along, bend)
	return math.deg(math.atan(slope))
end

-- THE ROAD AS WORLD POINTS, ONE SAMPLER for the map, the specs and the census -- design 3's rule
-- that `MapUi` asks and never re-derives. `samples` is the number of POINTS, so 2 is the end pair.
function Grid.roadPolyline(road: Road, samples: number, bend: Bend?): { Vector2 }
	local n = math.max(2, math.floor(samples))
	local out: { Vector2 } = table.create(n)
	for i = 1, n do
		local along = road.from + (road.to - road.from) * (i - 1) / (n - 1)
		local centre = Grid.roadCentreAt(road, along, bend)
		if road.axis == "x" then
			table.insert(out, Vector2.new(along, centre))
		else
			table.insert(out, Vector2.new(centre, along))
		end
	end
	return out
end

-- THE DERIVED FACTS, AS A FUNCTION AND NOT AS A COMMENT (design 4), so the spec, the census line and
-- this file read the same numbers and nothing is transcribed. `math.huge` where amplitude 0 makes
-- the quantity infinite: a straight road has no plan radius, no sight limit and no voxel stair.
function Grid.bendFacts(
	axis: string,
	bend: Bend?
): {
	pitchStuds: number,
	amplitudeStuds: number,
	harmonic: number,
	swingDeg: number,
	radiusStuds: number,
	sightStuds: number,
	stairStuds: number,
}
	local b = bendOf(bend)
	local pitch = Grid.bendPitch(axis)
	local amplitude = if axis == "x" then b.ewStuds else b.nsStuds
	local m = b.harmonic
	local slope = amplitude * math.pi * m / pitch
	return {
		pitchStuds = pitch,
		amplitudeStuds = amplitude,
		harmonic = m,
		swingDeg = math.deg(math.atan(slope)),
		radiusStuds = if amplitude <= 0 then math.huge else pitch * pitch / (amplitude * math.pi * math.pi * m * m),
		sightStuds = if amplitude <= 0
			then math.huge
			else (pitch / (math.pi * m)) * math.sqrt(2 * Grid.TRUNK_FLOOR_STUDS / amplitude),
		stairStuds = if slope <= 0 then math.huge else Grid.VOXEL_STUDS / slope,
	}
end

-- AN AXIS-ALIGNED WORLD BOX FOR A CELL: its grid rectangle grown by the amplitude that can move a
-- point into it -- the north-south family in x, the east-west family in z. The bake's region, the
-- boar field, the map's bounds and the border wood all need a box and not a curve.
function Grid.worldBoundsOf(id: string, bend: Bend?): { minX: number, maxX: number, minZ: number, maxZ: number }
	local box = Grid.boundsOf(id)
	local b = bendOf(bend)
	return {
		minX = box.minX - b.nsStuds,
		maxX = box.maxX + b.nsStuds,
		minZ = box.minZ - b.ewStuds,
		maxZ = box.maxZ + b.ewStuds,
	}
end

function Grid.worldFootprint(bend: Bend?): { minX: number, maxX: number, minZ: number, maxZ: number }
	local box = Grid.footprint()
	local b = bendOf(bend)
	return {
		minX = box.minX - b.nsStuds,
		maxX = box.maxX + b.nsStuds,
		minZ = box.minZ - b.ewStuds,
		maxZ = box.maxZ + b.ewStuds,
	}
end

-- ---------------------------------------------------------------- the stands

-- HOW MANY STANDS ARE ON THE MAIN LINE, and it is what `Fill.standsFree` must be given -- never
-- `#posts`, which is fifteen (design 6.4).
function Grid.mainStandCount(_id: string?): number
	return Grid.CONFIG.mainStandCount
end

-- HOW MANY STANDS A CELL HAS: 7 + 4 + 4. It is above `sideOf` because `sideOf` is range-checked
-- against it.
function Grid.standCount(_id: string?): number
	local c = Grid.CONFIG
	return c.mainStandCount + 2 * c.flankStandCount
end

-- THE RANGE CHECK ON A STAND INDEX, and it exists because **327b WIRES A CLIENT-SUPPLIED INDEX INTO
-- THIS SEAM** (`StandPick`'s claim, `MapUi`'s `Stand%d` taps). Without it `sideOf(id, 99)` answered
-- `east` and `standPosition` returned a point outside the world -- 327a review note (d).
-- A whole number too: 7.5 would have landed in `main` and placed a hunter between two stands.
local function assertStandIndex(who: string, id: string?, standIndex: number)
	assert(
		type(standIndex) == "number" and standIndex % 1 == 0 and standIndex >= 1 and standIndex <= Grid.standCount(id),
		string.format("Grid.%s: stand index out of range: %s", who, tostring(standIndex))
	)
end

-- WHICH SIDE AN INDEX IS ON. **THE INDEX ORDER IS LOAD-BEARING AND NOT COSMETIC:**
-- `HighSeats.STANDS[cellId]`, `StandPick`'s claim, `snapshot.picks`, `MapUi`'s `Stand%d` nodes and
-- `ForestTest.standArea` all key on it. Main first, because every pre-327 reader assumes the main
-- line IS "the stands".
--   1..7    the main line, west to east
--   8..11   the west flank, nearest the main road first
--   12..15  the east flank, nearest first
function Grid.sideOf(id: string?, standIndex: number): string
	local c = Grid.CONFIG
	assertStandIndex("sideOf", id, standIndex)
	if standIndex <= c.mainStandCount then
		return "main"
	elseif standIndex <= c.mainStandCount + c.flankStandCount then
		return "west"
	end
	return "east"
end

-- HOW FAR UP THE CELL THE FIRST FLANK STAND SITS, **DERIVED AND NEVER A LITERAL** (design 7). The
-- invariant is that every pair of stands on DIFFERENT sides of a cell is at least the slug's own
-- range apart -- past it nothing arrives, which is why `Match.CONFIG.SAFETY_RANGE_STUDS` is that
-- same number. The tightest pair is the main line's end stand against the near flank stand:
--
--   dx = (cellWidth/2 + roadClear/2) - (mainCount - 1)/2 * mainSpacing = 556 - 450 = 106
--   dz = sqrt(range^2 - dx^2) = sqrt(330^2 - 106^2) = 312.5
--   flankFirst = ceil(312.5) + flankMargin 27 = 340     -> the pair is 356.1 apart, 26.1 of margin
--
-- Written as the formula so a change to the cell width, the main count or the spacing MOVES it
-- instead of silently breaking it.
--
-- **AND IT IS SOLVED IN WORLD COORDINATES, BECAUSE THE SHEAR EATS THE MARGIN** (design 5.4, defect
-- F-1). The tight pair differs by `f` in `v`, and `bendX` changes by up to `|bendX'|max * f` over
-- that -- straight off the `dx` term -- while the pair also loses up to `|bendZ'|max * dx0` of dz.
-- So the set-back is the fixed point of
--
--   f(n+1) = ceil( sqrt(range^2 - (dx0 - |bendX'|max * f(n))^2) + |bendZ'|max * dx0 ) + flankMargin
--
-- started at the straight answer. It converges in two steps and this does three:
--   bend 0      340 -> 340                (the sines are 0, so this IS today's arithmetic)
--   bend 45/60  340 -> 365 -> 366 -> 366
function Grid.flankFirstStuds(bend: Bend?): number
	local c = Grid.CONFIG
	local b = bendOf(bend)
	local dx0 = (c.cellWidthStuds / 2 + c.roadClearStuds / 2) - ((c.mainStandCount - 1) / 2) * c.mainSpacingStuds
	local range = Shotgun.CONFIG.RANGE_STUDS.Slug
	-- THE PEAK SLOPES, `A * pi * m / P` on each axis -- the same quantity `bendFacts().swingDeg` is
	-- the angle of, so there is one definition of "how hard the world shears".
	local slopeX = b.nsStuds * math.pi * b.harmonic / Grid.bendPitch("z")
	local slopeZ = b.ewStuds * math.pi * b.harmonic / Grid.bendPitch("x")
	local f = math.ceil(math.sqrt(math.max(0, range * range - dx0 * dx0))) + c.flankMarginStuds
	for _ = 1, 3 do
		local dx = dx0 - slopeX * f
		f = math.ceil(math.sqrt(math.max(0, range * range - dx * dx)) + slopeZ * dx0) + c.flankMarginStuds
	end
	return f
end

-- WHERE A HUNTER STANDS, as a world position. Side-aware.
--
-- FOR A MAIN INDEX THIS IS `ForestTest.standPosition`'s OWN ARITHMETIC, by construction: the cell's
-- centre x plus `(index - (count + 1)/2) * spacing`, at the main road's z, with the cell's measured
-- line mean as the fallback y. Task 327b makes `ForestTest.standPosition` delegate here and asserts
-- the two agree to 1e-9 for indices 1..7 of every cell.
-- WHERE A HUNTER STANDS IN GRID COORDINATES -- today's arithmetic, unchanged, and now named, so
-- `standPosition` is one `toWorld` of it and `Places.rideSegments` can ask for the grid point it
-- actually wants (design 4). Returns `(u, v)`.
function Grid.standGridOf(id: string, standIndex: number, bend: Bend?): (number, number)
	local cell = Grid.cellOf(id)
	assert(cell ~= nil, "Grid.standGridOf: no such cell")
	assertStandIndex("standGridOf", id, standIndex)
	local c = Grid.CONFIG
	local box = Grid.boundsOf(id)
	local roads = Grid.roadsOf(id)
	local mainZ = roads.main.at
	local side = Grid.sideOf(id, standIndex)
	if side == "main" then
		local middle = (c.mainStandCount + 1) / 2
		return (box.minX + box.maxX) / 2 + (standIndex - middle) * c.mainSpacingStuds, mainZ
	end
	-- A FLANK RUNS NORTH FROM THE MAIN ROAD, into the cell: stand 1 of a flank is `flankFirst` up,
	-- then `flankSpacing` apart, so four stands span 660 of the cell's 1430 studs.
	local first = if side == "west" then c.mainStandCount + 1 else c.mainStandCount + c.flankStandCount + 1
	local step = standIndex - first
	local v = mainZ + Grid.flankFirstStuds(bend) + step * c.flankSpacingStuds
	return (if side == "west" then roads.west.at else roads.east.at), v
end

function Grid.standPosition(id: string, standIndex: number): Vector3
	local cell = Grid.cellOf(id)
	assert(cell ~= nil, "Grid.standPosition: no such cell")
	local u, v = Grid.standGridOf(id, standIndex)
	-- THE GRID POINT THROUGH THE MAP, so every stand lies EXACTLY on its own road's world curve
	-- (`grid.spec` case 4 asserts it to 1e-6). The y is unchanged: the cell's measured line mean,
	-- a FALLBACK ground that the real terrain decides.
	local x, z = Grid.toWorld(u, v)
	return Vector3.new(x, cell.relief.lineMeanY, z)
end

-- THE ORDER STANDS ARE OFFERED IN, and it is `HighSeats.dealLine`'s `walk` parameter, so there is no
-- second walk to drift from. **Main line centre-out first** -- a hunter dealt a stand with nobody
-- else playing should be in the middle of the line, which is `ForestTest.standWalk`'s own rule --
-- then the flanks, nearest the main road first and ALTERNATING sides, so one flank is never filled
-- before the other is touched.
--   7 stands:  4 3 5 2 6 1 7      then:  8 12 9 13 10 14 11 15
function Grid.standWalk(_id: string?): { number }
	local c = Grid.CONFIG
	local out: { number } = {}
	local middle = math.ceil(c.mainStandCount / 2)
	table.insert(out, middle)
	for offset = 1, c.mainStandCount do
		if middle - offset >= 1 then
			table.insert(out, middle - offset)
		end
		if middle + offset <= c.mainStandCount then
			table.insert(out, middle + offset)
		end
	end
	for step = 0, c.flankStandCount - 1 do
		table.insert(out, c.mainStandCount + 1 + step)
		table.insert(out, c.mainStandCount + c.flankStandCount + 1 + step)
	end
	return out
end

-- WHICH OF A CELL'S FIFTEEN STANDS CARRY A TOWER, and **IT IS MEASURED, NOT CHOSEN** (design 6.1,
-- task 218's own rule and instrument). `HighSeats.STANDS` takes these rows; the measurement and the
-- gain / spread / relief of every tower are in the `towers` comment of each cell above. A FRESH
-- COPY, `HighSeats.standsFor`'s own discipline.
function Grid.towerStands(id: string): { number }
	local cell = Grid.cellOf(id)
	assert(cell ~= nil, "Grid.towerStands: no such cell")
	return table.clone(cell.towers)
end

-- WHETHER THIS CELL'S TOWER WAS TAKEN WITH THE RELIEF TEST RELAXED. `HighSeats.RELIEF_RELAXED`
-- takes it, and `Seats.takeLine` prints the fact every time it builds.
function Grid.towersRelaxed(id: string): boolean
	local cell = Grid.cellOf(id)
	assert(cell ~= nil, "Grid.towersRelaxed: no such cell")
	return cell.towersRelaxed == true
end

-- THE ROW `ForestTest.LAYOUTS` TAKES FOR THIS CELL (design 3.2), and it is the ONE place a cell
-- becomes a layout -- a second conversion is two worlds that disagree about where stand 7 is.
--
-- MEMOISED, so `chosen.layout` is the same table every time the boot asks: the drive compares a
-- promoted layout by identity in places, and a fresh table per call would make a layout that never
-- stops changing.
--
-- `standCount` IS FIFTEEN -- every stand of the cell, main plus both flanks -- and `standSpacing`
-- is the MAIN line's. The two cannot be multiplied together to get the line's width any more, which
-- is exactly why `ForestTest.standPosition` delegates here instead of doing that arithmetic (6.2).
local LAYOUT_BY_ID: { [string]: any } = {}
function Grid.layoutFor(id: string): any
	local made = LAYOUT_BY_ID[id]
	if made ~= nil then
		return made
	end
	local cell = Grid.cellOf(id)
	assert(cell ~= nil, "Grid.layoutFor: no such cell")
	local c = Grid.CONFIG
	local box = Grid.boundsOf(id)
	local roads = Grid.roadsOf(id)
	local layout = table.freeze({
		-- A CELL'S NAME IS ITS ID. Nothing else keys on a cell.
		name = id,
		label = "Cell " .. id,
		-- Y IS A FALLBACK GROUND ONLY, which is what `ForestTest.Layout` documents it as -- so it is
		-- the cell's own MAIN LINE mean and not its midpoint (`Grid.CELLS[*].relief.lineMeanY`).
		centre = Vector3.new((box.minX + box.maxX) / 2, cell.relief.lineMeanY, roads.main.at),
		-- THE EAST-WEST FAMILY'S AMPLITUDE (task 328q): a cell's main line IS this sine, and 0 is a
		-- straight line in one code path. `ForestTest.roadZ` resolves a cell through `Grid` and never
		-- through `SHAPE.wavelengthDivisor`, so this field is read for its BOUNDS, not its curve.
		amplitudeStuds = c.bend.ewStuds,
		standCount = Grid.standCount(id),
		standSpacing = c.mainSpacingStuds,
		-- THE CELL'S OWN HALF WIDTH: 900 studs of stands plus 85 of run-out each end is 535, which
		-- is `cellWidth / 2` exactly -- so the boar field spans the cell and stops at its roads.
		-- PLUS THE NORTH-SOUTH AMPLITUDE, because a flank road now wanders that far in x.
		halfSpanStuds = c.cellWidthStuds / 2 + c.bend.nsStuds,
		sides = table.freeze({
			main = table.freeze({ count = c.mainStandCount, spacingStuds = c.mainSpacingStuds }),
			flanks = table.freeze({
				count = c.flankStandCount,
				spacingStuds = c.flankSpacingStuds,
				firstStuds = Grid.flankFirstStuds(),
				-- HOW FAR OFF THE CELL'S CENTRE LINE A FLANK ROAD RUNS, which is design 7's own `dx`
				-- term: half the cell plus half the road.
				offsetStuds = c.cellWidthStuds / 2 + c.roadClearStuds / 2,
			}),
		}),
		-- THE BEATERS MUSTER ON THE CELL'S UPWIND ROAD, so the walk IS the cell's depth (design
		-- 4.3). At the pace above: 1450 studs including the overrun, 270 s measured on the ground,
		-- inside the 300 s clock less the 15 s through-grace.
		beaterNorthStuds = c.cellDepthStuds,
		-- THE BOAR FIELD REACHES THE MUSTER ROAD and stops there: a field that ended at the old 900
		-- would clamp every animal 530 studs short of where the beaters start. PLUS THE EAST-WEST
		-- AMPLITUDE, because the muster road itself wanders that far north of its own `at`.
		fieldNorthStuds = c.cellDepthStuds + c.roadClearStuds + c.bend.ewStuds,
		cellOf = table.freeze({ row = cell.row, column = cell.column }),
	})
	LAYOUT_BY_ID[id] = layout
	return layout
end

-- THE WORST CROSS-SIDE STAND PAIR IN A CELL, in studs (design 7). It answers the invariant as a
-- NUMBER so a CONFIG change that eats the 26-stud margin is read rather than guessed.
--
-- Pairs on the SAME side are not counted, and that is said rather than hidden: two hunters on one
-- side are inside slug range of each other, exactly as nine hunters on the `road` layout are today,
-- and the proximity lock and the penalty are what stand in for it.
function Grid.separationStuds(id: string): number
	local count = Grid.standCount(id)
	local worst = math.huge
	for a = 1, count - 1 do
		local sideA = Grid.sideOf(id, a)
		local pa = Grid.standPosition(id, a)
		for b = a + 1, count do
			if Grid.sideOf(id, b) ~= sideA then
				local pb = Grid.standPosition(id, b)
				-- THE PLAN DISTANCE, not the 3-D one: the y values are a fallback ground per cell,
				-- so a 3-D distance here would read a difference that the real terrain decides.
				local dx, dz = pa.X - pb.X, pa.Z - pb.Z
				worst = math.min(worst, math.sqrt(dx * dx + dz * dz))
			end
		end
	end
	return worst
end

-- ---------------------------------------------------------------- the seed

-- ONE 32-BIT MIX. `bit32` ONLY, no multiply: a 32-bit multiply in Luau's doubles overflows 2^53 and
-- stops being exact, and a seed that is not exact is not a seed.
local function mix32(h: number): number
	h = bit32.bxor(h, bit32.lshift(h, 13))
	h = bit32.bxor(h, bit32.rshift(h, 17))
	return bit32.bxor(h, bit32.lshift(h, 5))
end

-- A CELL'S SEED FOR ONE STREAM, hashed from `(CONFIG.seed, row, column, stream)` and from nothing
-- else -- **never from a counter**. That is Minecraft's own per-chunk rule (note section 2B): a
-- cell's wood is the same whatever order the cells were built in, which is the property
-- `drive-places.md` section 10.1 found broken when a planting depended on its own order.
function Grid.seedFor(id: string, stream: number): number
	local cell = Grid.cellOf(id)
	assert(cell ~= nil, "Grid.seedFor: no such cell")
	local h = Grid.CONFIG.seed
	for _, value in ipairs({ cell.row, cell.column, stream }) do
		h = mix32(bit32.bxor(h, value + 0x9E3779B9))
		h = mix32(h)
	end
	return h
end

return Grid
