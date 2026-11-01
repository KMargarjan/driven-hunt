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
	-- 1430 / 5.2 = 275 s, inside `DRIVE.seconds` 300 less the 15 s through-grace, so Karen's
	-- "when all beaters cross line of hunters" ending can actually fire (design 4.3). `Bots.CONFIG`
	-- takes this number in task 327d; nothing reads it yet.
	beaterWalkStudsPerSecond = 5.2,
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
})

-- WEST TO EAST, and the id is the column letter plus the row number, so `Places.CELL_PLANS`,
-- `HighSeats.STANDS`, `ForestTest.LAYOUTS` and the vote's wire all key on one string.
Grid.COLUMN_LETTERS = table.freeze({ "A", "B", "C", "D" })

-- THE FALLBACK CYCLE, and the order the eight rows are written in. Row 1 is the NORTH row (the
-- larger z), because this world's drives all push south (`ForestTest.EXIT_SOUTH_STUDS`).
Grid.CELL_ORDER = table.freeze({ "A1", "B1", "C1", "D1", "A2", "B2", "C2", "D2" })

-- WHICH CELL `GRID_PREVIEW` DRESSES, so Karen walks ONE cell's stands and towers rather than eight
-- cells' worth of posts (task 327b). **C1 BECAUSE IT HAS THE MOST TO SHOW**, which is a reading and
-- not a preference: it is the only cell whose tower measurement takes THREE stands, it takes them on
-- BOTH flanks, and it needs no relief relaxation. Task 327d retires the preview and this row with it.
Grid.PREVIEW_CELL = "C1"

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
-- A later task that GENERATES the relief writes the same fields from its own heightfield and no
-- assertion in `grid.spec` moves. `recipe` (327c) and `animals` (327h) are not here yet.
Grid.CELLS = table.freeze({
	table.freeze({
		id = "A1",
		row = 1,
		column = 1,
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
		relief = table.freeze({
			character = "slope",
			minY = 70.2,
			maxY = 173.2,
			spreadStuds = 103.0,
			lineSpreadStuds = 21.8,
			lineMeanY = 80.50,
		}),
		towers = table.freeze({ 12 }), -- 12 east gain +80, spread 0.00, relief 0.00
	}),
	table.freeze({
		id = "C1",
		row = 1,
		column = 3,
		relief = table.freeze({
			character = "rolling",
			minY = 89.2,
			maxY = 150.9,
			spreadStuds = 61.7,
			lineSpreadStuds = 21.0,
			lineMeanY = 106.98,
		}),
		towers = table.freeze({ 8, 13, 15 }), -- 8 west +80/0.00/0.00; 13 east +244/0.00/0.02; 15 east +95/0.30/1.42
	}),
	table.freeze({
		id = "D1",
		row = 1,
		column = 4,
		relief = table.freeze({
			character = "rolling",
			minY = 103.3,
			maxY = 166.8,
			spreadStuds = 63.5,
			lineSpreadStuds = 36.8,
			lineMeanY = 134.35,
		}),
		towers = table.freeze({ 9, 11 }), -- 9 west +244/0.00/0.02; 11 west +95/0.30/1.42
	}),
	table.freeze({
		id = "A2",
		row = 2,
		column = 1,
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
function Grid.flankFirstStuds(): number
	local c = Grid.CONFIG
	local dx = (c.cellWidthStuds / 2 + c.roadClearStuds / 2) - ((c.mainStandCount - 1) / 2) * c.mainSpacingStuds
	local range = Shotgun.CONFIG.RANGE_STUDS.Slug
	local required = math.sqrt(math.max(0, range * range - dx * dx))
	return math.ceil(required) + c.flankMarginStuds
end

-- WHERE A HUNTER STANDS, as a world position. Side-aware.
--
-- FOR A MAIN INDEX THIS IS `ForestTest.standPosition`'s OWN ARITHMETIC, by construction: the cell's
-- centre x plus `(index - (count + 1)/2) * spacing`, at the main road's z, with the cell's measured
-- line mean as the fallback y. Task 327b makes `ForestTest.standPosition` delegate here and asserts
-- the two agree to 1e-9 for indices 1..7 of every cell.
function Grid.standPosition(id: string, standIndex: number): Vector3
	local cell = Grid.cellOf(id)
	assert(cell ~= nil, "Grid.standPosition: no such cell")
	assertStandIndex("standPosition", id, standIndex)
	local c = Grid.CONFIG
	local box = Grid.boundsOf(id)
	local centreX = (box.minX + box.maxX) / 2
	local y = cell.relief.lineMeanY
	local roads = Grid.roadsOf(id)
	local mainZ = roads.main.at
	local side = Grid.sideOf(id, standIndex)
	if side == "main" then
		local middle = (c.mainStandCount + 1) / 2
		return Vector3.new(centreX + (standIndex - middle) * c.mainSpacingStuds, y, mainZ)
	end
	-- A FLANK RUNS NORTH FROM THE MAIN ROAD, into the cell: stand 1 of a flank is `flankFirst` up,
	-- then `flankSpacing` apart, so four stands span 660 of the cell's 1430 studs.
	local first = if side == "west" then c.mainStandCount + 1 else c.mainStandCount + c.flankStandCount + 1
	local step = standIndex - first
	local z = mainZ + Grid.flankFirstStuds() + step * c.flankSpacingStuds
	return Vector3.new(if side == "west" then roads.west.at else roads.east.at, y, z)
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
		-- A CELL'S ROADS ARE STRAIGHT IN PLAN, and 0 is a straight line in one code path (design 2).
		amplitudeStuds = 0,
		standCount = Grid.standCount(id),
		standSpacing = c.mainSpacingStuds,
		-- THE CELL'S OWN HALF WIDTH: 900 studs of stands plus 85 of run-out each end is 535, which
		-- is `cellWidth / 2` exactly -- so the boar field spans the cell and stops at its roads.
		halfSpanStuds = c.cellWidthStuds / 2,
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
		-- 4.3): 1430 / 5.2 = 275 s, inside the 300 s clock less the 15 s through-grace.
		beaterNorthStuds = c.cellDepthStuds,
		-- THE BOAR FIELD REACHES THE MUSTER ROAD and stops there: a field that ended at the old 900
		-- would clamp every animal 530 studs short of where the beaters start.
		fieldNorthStuds = c.cellDepthStuds + c.roadClearStuds,
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
