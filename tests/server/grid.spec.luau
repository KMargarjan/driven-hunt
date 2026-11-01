--!nocheck
-- Task 327a: THE GRID -- one world, eight drive cells, and the roads that cut it.
--
-- EVERYTHING IN HERE RUNS WITH NO WORLD AND NO TERRAIN. `Grid` is pure by construction; the paint is
-- driven through an INJECTED terrain with a recording `ReplaceMaterial`, which is `places.spec`'s own
-- discipline and the reason no spec in the DEV place can write DEV's terrain.
--
-- This file holds design section 13.1's cases 1-11, 19 and 22: 1, 3, 5, 6, 9, 11, 19 and 22 are
-- 327a's; 2, 4, 7, 8 and 10 are 327b's. Cases 12-18 and 20 are 327c's, 21 is 327d's.
--
-- Design: docs/design/grid-map.md
-- Note:   docs/research/2026-11-01-the-grid-map.md
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
	local Grid = require(ReplicatedStorage:WaitForChild("Grid"))
	local Forest = require(ReplicatedStorage:WaitForChild("ForestTest"))
	local Plan = require(ReplicatedStorage:WaitForChild("Places"))
	local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
	local Planter = require(ServerScriptService:WaitForChild("Places"))
	local Ground = require(ServerScriptService.Places:WaitForChild("Ground"))
	local Match = require(ServerScriptService:WaitForChild("Match"))
	local Bots = require(ServerScriptService:WaitForChild("Bots"))
	local Markers = require(ServerScriptService:WaitForChild("ForestTest")).Markers

	-- A FLAT WORLD AT A KNOWN HEIGHT, so the cases about the POST LIST are not cases about DEV's
	-- terrain (`forest_markers.spec`'s own fixture).
	local function flatGround(_x: number, _z: number): number?
		return 140
	end

	-- ---------------------------------------------------------------- 1. eight cells

	describe("the eight cells", function()
		it("is two rows of four, keyed A1..D2, with eight distinct seeds", function()
			local ids = Grid.cellIds()
			expect(#ids).to.equal(8)
			expect(#Grid.CELLS).to.equal(8)
			expect(Grid.CONFIG.rows * Grid.CONFIG.columns).to.equal(8)
			local expected = { "A1", "B1", "C1", "D1", "A2", "B2", "C2", "D2" }
			for index, id in ipairs(expected) do
				expect(ids[index]).to.equal(id)
				local cell = Grid.cellOf(id)
				expect(cell ~= nil).to.equal(true)
				expect(cell.id).to.equal(id)
				-- THE ID IS DERIVED FROM THE COORDINATE and is not a second naming: the letter is the
				-- column west to east, the digit is the row, 1 = north.
				expect(Grid.COLUMN_LETTERS[cell.column]).to.equal(string.sub(id, 1, 1))
				expect(tostring(cell.row)).to.equal(string.sub(id, 2, 2))
				-- THE RELIEF IS MEASURED (design 4.4), so every row has to BE a measurement: four
				-- numbers that agree with each other and a character from the classified set.
				local relief = cell.relief
				expect(relief.maxY > relief.minY).to.equal(true)
				expect(math.abs(relief.spreadStuds - (relief.maxY - relief.minY)) < 0.11).to.equal(true)
				expect(relief.lineSpreadStuds <= relief.spreadStuds).to.equal(true)
				expect(relief.lineMeanY >= relief.minY and relief.lineMeanY <= relief.maxY).to.equal(true)
				local known = relief.character == "flat"
					or relief.character == "slope"
					or relief.character == "ridge"
					or relief.character == "dip"
					or relief.character == "rolling"
				expect(known).to.equal(true)
			end
			-- A NAME NOBODY KNOWS GETS NO CELL rather than the wrong one.
			expect(Grid.cellOf("E1")).to.equal(nil)
			expect(Grid.cellOf(nil)).to.equal(nil)
			expect(Grid.cellOf("road")).to.equal(nil)
			-- EIGHT DISTINCT SEEDS, or two cells grow the same wood and nobody ever sees why.
			local seen = {}
			for _, id in ipairs(ids) do
				for stream = 1, 4 do
					local seed = Grid.seedFor(id, stream)
					expect(seen[seed]).to.equal(nil)
					seen[seed] = id
					-- SAME INPUT, SAME ANSWER: there is no counter anywhere in it.
					expect(Grid.seedFor(id, stream)).to.equal(seed)
				end
			end
			-- A FRESH COPY EACH CALL, so a caller that shuffles cannot shuffle the table.
			local mine = Grid.cellIds()
			mine[1] = "ZZ"
			expect(Grid.cellIds()[1]).to.equal("A1")
			TestKit.note(string.format(
				"grid %s: %d cells, relief %s",
				Grid.VERSION,
				#Grid.CELLS,
				table.concat({
					Grid.CELLS[1].relief.character,
					Grid.CELLS[8].relief.character,
				}, "/")
			))
		end)
	end)

	-- ---------------------------------------------------------------- 3. the footprint is arithmetic

	describe("the footprint", function()
		it("is 4490 x 2986, holds every road, and no two cells overlap", function()
			local c = Grid.CONFIG
			local box = Grid.footprint()
			expect(box.maxX - box.minX).to.equal(4 * c.cellWidthStuds + 5 * c.roadClearStuds)
			expect(box.maxZ - box.minZ).to.equal(2 * c.cellDepthStuds + 3 * c.roadClearStuds)
			expect(box.maxX - box.minX).to.equal(4490)
			expect(box.maxZ - box.minZ).to.equal(2986)
			-- EVERY CELL INSIDE THE FOOTPRINT, and the right size.
			local cells = {}
			for _, id in ipairs(Grid.cellIds()) do
				local cell = Grid.boundsOf(id)
				expect(cell.maxX - cell.minX).to.equal(c.cellWidthStuds)
				expect(cell.maxZ - cell.minZ).to.equal(c.cellDepthStuds)
				expect(cell.minX >= box.minX and cell.maxX <= box.maxX).to.equal(true)
				expect(cell.minZ >= box.minZ and cell.maxZ <= box.maxZ).to.equal(true)
				table.insert(cells, cell)
			end
			-- NO TWO CELLS OVERLAP. The roads are what separate them, so this is really the
			-- assertion that the road width was subtracted and not forgotten.
			for a = 1, #cells - 1 do
				for b = a + 1, #cells do
					local one, two = cells[a], cells[b]
					local apart = one.maxX <= two.minX
						or two.maxX <= one.minX
						or one.maxZ <= two.minZ
						or two.maxZ <= one.minZ
					expect(apart).to.equal(true)
				end
			end
			-- EVERY ROAD INSIDE THE FOOTPRINT, with its painted strip inside it too: three east-west
			-- and five north-south (the border road is forced -- design 4.1).
			local roads = Grid.roads()
			expect(#roads).to.equal((c.rows + 1) + (c.columns + 1))
			local ew, ns = 0, 0
			for _, road in ipairs(roads) do
				local half = c.roadClearStuds / 2
				if road.axis == "x" then
					ew += 1
					expect(road.from).to.equal(box.minX)
					expect(road.to).to.equal(box.maxX)
					expect(road.at - half >= box.minZ and road.at + half <= box.maxZ).to.equal(true)
				else
					ns += 1
					expect(road.from).to.equal(box.minZ)
					expect(road.to).to.equal(box.maxZ)
					expect(road.at - half >= box.minX and road.at + half <= box.maxX).to.equal(true)
				end
			end
			expect(ew).to.equal(3)
			expect(ns).to.equal(5)
			-- EVERY CELL'S FOUR ROADS ARE FOUR DIFFERENT ROADS, and the main one is its SOUTH road
			-- (every drive pushes south), the muster one its north.
			for _, id in ipairs(Grid.cellIds()) do
				local cell = Grid.boundsOf(id)
				local of = Grid.roadsOf(id)
				expect(of.main.axis).to.equal("x")
				expect(of.muster.axis).to.equal("x")
				expect(of.west.axis).to.equal("z")
				expect(of.east.axis).to.equal("z")
				expect(of.main.at < cell.minZ).to.equal(true)
				expect(of.muster.at > cell.maxZ).to.equal(true)
				expect(of.west.at < cell.minX).to.equal(true)
				expect(of.east.at > cell.maxX).to.equal(true)
			end
			TestKit.note(
				string.format(
					"footprint %.0f x %.0f at (%d, %d), %d roads",
					box.maxX - box.minX,
					box.maxZ - box.minZ,
					c.originX,
					c.originZ,
					#roads
				)
			)
		end)
	end)

	-- ---------------------------------------------------------------- 5. cross-side separation

	describe("safety by geometry", function()
		it("keeps every cross-side stand pair at least a slug's range apart", function()
			-- THIS IS DESIGN SECTION 7, AND IT IS WHAT MAKES D10 A PROPERTY OF THE DATA rather than
			-- a hope: past `RANGE_STUDS.Slug` nothing arrives, so two stands that far apart cannot
			-- shoot each other whatever the player does.
			--
			-- COMPUTED BY THIS LOOP AND NOT BY CALLING `Grid.separationStuds`, so the case cannot
			-- pass because that function is wrong in the same way.
			local range = Shotgun.CONFIG.RANGE_STUDS.Slug
			local count = Grid.standCount("A1")
			expect(count).to.equal(15)
			local worst, worstAt, pairs_ = math.huge, "", 0
			for _, id in ipairs(Grid.cellIds()) do
				for a = 1, count - 1 do
					for b = a + 1, count do
						if Grid.sideOf(id, a) ~= Grid.sideOf(id, b) then
							local pa, pb = Grid.standPosition(id, a), Grid.standPosition(id, b)
							local dx, dz = pa.X - pb.X, pa.Z - pb.Z
							local apart = math.sqrt(dx * dx + dz * dz)
							pairs_ += 1
							expect(apart >= range).to.equal(true)
							if apart < worst then
								worst, worstAt = apart, string.format("%s %d-%d", id, a, b)
							end
						end
					end
				end
			end
			-- 105 pairs per cell is every pair; the cross-side ones are 7x4 + 7x4 + 4x4 = 72.
			expect(pairs_).to.equal(8 * 72)
			-- AND `Grid.separationStuds` AGREES with the loop, cell for cell.
			for _, id in ipairs(Grid.cellIds()) do
				local mine = math.huge
				for a = 1, count - 1 do
					for b = a + 1, count do
						if Grid.sideOf(id, a) ~= Grid.sideOf(id, b) then
							local pa, pb = Grid.standPosition(id, a), Grid.standPosition(id, b)
							local dx, dz = pa.X - pb.X, pa.Z - pb.Z
							mine = math.min(mine, math.sqrt(dx * dx + dz * dz))
						end
					end
				end
				expect(math.abs(Grid.separationStuds(id) - mine) < 1e-9).to.equal(true)
			end
			-- THE MARGIN IS REPORTED AS A NUMBER, so a CONFIG change that eats it is read rather
			-- than passed over.
			expect(Match.CONFIG.SAFETY_RANGE_STUDS).to.equal(range)
			TestKit.note(
				string.format(
					"worst cross-side pair %.1f studs (%s), range %d, margin %.1f",
					worst,
					worstAt,
					range,
					worst - range
				)
			)
		end)

		it("puts the sides where the index says they are", function()
			-- THE INDEX ORDER IS LOAD-BEARING (design 6.2): main 1..7, west 8..11, east 12..15.
			for index = 1, 7 do
				expect(Grid.sideOf("B1", index)).to.equal("main")
			end
			for index = 8, 11 do
				expect(Grid.sideOf("B1", index)).to.equal("west")
			end
			for index = 12, 15 do
				expect(Grid.sideOf("B1", index)).to.equal("east")
			end
			expect(Grid.mainStandCount("B1")).to.equal(7)
			-- THE MAIN LINE IS ON THE MAIN ROAD, west to east at the accepted 150 studs; a flank runs
			-- NORTH from it, into the cell, and stops well short of the muster road.
			local of = Grid.roadsOf("B1")
			local cell = Grid.boundsOf("B1")
			for index = 1, 7 do
				local at = Grid.standPosition("B1", index)
				expect(math.abs(at.Z - of.main.at) < 1e-9).to.equal(true)
				if index > 1 then
					local before = Grid.standPosition("B1", index - 1)
					expect(math.abs((at.X - before.X) - Grid.CONFIG.mainSpacingStuds) < 1e-9).to.equal(true)
				end
			end
			for _, side in ipairs({ { 8, 11, of.west.at }, { 12, 15, of.east.at } }) do
				for index = side[1], side[2] do
					local at = Grid.standPosition("B1", index)
					expect(math.abs(at.X - side[3]) < 1e-9).to.equal(true)
					expect(at.Z > of.main.at).to.equal(true)
					expect(at.Z < cell.maxZ).to.equal(true)
				end
			end
		end)
	end)

	-- ---------------------------------------------------------------- 6. the set-back is a formula

	describe("the flank set-back", function()
		it("is solved from the slug's range and not written down", function()
			-- RECOMPUTED HERE FROM THE CONFIG, so a change to the cell width, the main count or the
			-- spacing MOVES the set-back instead of silently breaking the separation above.
			local c = Grid.CONFIG
			local dx = (c.cellWidthStuds / 2 + c.roadClearStuds / 2) - ((c.mainStandCount - 1) / 2) * c.mainSpacingStuds
			local range = Shotgun.CONFIG.RANGE_STUDS.Slug
			local required = math.sqrt(range * range - dx * dx)
			expect(math.abs(dx - 106) < 1e-9).to.equal(true)
			expect(math.abs(required - 312.51) < 0.01).to.equal(true)
			expect(Grid.flankFirstStuds()).to.equal(math.ceil(required) + c.flankMarginStuds)
			expect(Grid.flankFirstStuds()).to.equal(340)
			-- AND IT IS ENOUGH, which is the inequality the number exists for.
			expect(math.sqrt(dx * dx + Grid.flankFirstStuds() ^ 2) >= range).to.equal(true)
			-- THE FLANK FITS IN THE CELL: four stands 220 apart from the set-back is 1000 of 1430.
			local span = Grid.flankFirstStuds() + (c.flankStandCount - 1) * c.flankSpacingStuds
			expect(span < c.cellDepthStuds).to.equal(true)
			TestKit.note(
				string.format(
					"flank set-back %d studs (needed %.1f), deepest flank stand %d of %d",
					Grid.flankFirstStuds(),
					required,
					span,
					c.cellDepthStuds
				)
			)
		end)
	end)

	-- ---------------------------------------------------------------- 9. the beaters' clock

	describe("the beaters", function()
		it("walk the cell inside the drive's clock, with every release slot played first", function()
			-- DESIGN 4.3: the cell's DEPTH is where the walk speed comes from, so this is the
			-- assertion that the cell was sized by the clock and not by taste.
			local c = Grid.CONFIG
			local walkSeconds = c.cellDepthStuds / c.beaterWalkStudsPerSecond
			local grace = Match.CONFIG.BEATERS_THROUGH_GRACE_SECONDS
			expect(walkSeconds <= Forest.DRIVE.seconds - grace).to.equal(true)
			-- ...AND EVERY ONE OF THE FIFTEEN SLOTS IS DUE BEFORE THE LINE ARRIVES. The relation is
			-- asserted, never the number: move `intervalSeconds` and this is what reddens.
			local slots = 0
			for _, row in ipairs(Forest.SCHEDULE.drive) do
				slots = math.max(slots, row.slot)
			end
			expect(slots).to.equal(15)
			local lastSlotAt = Forest.slotSeconds(slots, Forest.SCHEDULE)
			expect(lastSlotAt <= walkSeconds).to.equal(true)
			TestKit.note(
				string.format(
					"beaters %.0fs over %d studs at %.1f (clock %ds - %ds grace); slot %d at %.0fs, %.0fs of margin",
					walkSeconds,
					c.cellDepthStuds,
					c.beaterWalkStudsPerSecond,
					Forest.DRIVE.seconds,
					grace,
					slots,
					lastSlotAt,
					walkSeconds - lastSlotAt
				)
			)
		end)
	end)

	-- ---------------------------------------------------------------- 2. the four old places

	describe("the four shipped places", function()
		it("carry none of the four new fields and answer value for value", function()
			for _, name in ipairs(Forest.LAYOUT_ORDER) do
				local layout = Forest.layoutNamed(name) :: any
				-- ALL FOUR OPTIONAL FIELDS ABSENT. This is boundary 7: a shipped row that grew one of
				-- them would take the cell code path through the world Karen plays today.
				expect(layout.sides).to.equal(nil)
				expect(layout.beaterNorthStuds).to.equal(nil)
				expect(layout.fieldNorthStuds).to.equal(nil)
				expect(layout.cellOf).to.equal(nil)
				expect(Grid.cellOf(name)).to.equal(nil)
				-- ...AND EVERY FUNCTION 327b TOUCHED STILL DOES ITS PRE-327b ARITHMETIC, written out
				-- here rather than cited: `standX` is the offset along one line, `standPosition` is
				-- that x on `roadZ`, `standSpan` is stand 1 to stand `standCount`, `beaterNorthStuds`
				-- is the one 580 for every layout, and the field's north edge is the old formula.
				local middle = (layout.standCount + 1) / 2
				for index = 1, layout.standCount do
					local x = layout.centre.X + (index - middle) * layout.standSpacing
					expect(math.abs(Forest.standX(index, layout) - x) < 1e-9).to.equal(true)
					local at = Forest.standPosition(index, layout)
					expect(math.abs(at.X - x) < 1e-9).to.equal(true)
					expect(at.Y).to.equal(layout.centre.Y)
					expect(math.abs(at.Z - Forest.roadZ(x, layout)) < 1e-9).to.equal(true)
				end
				local span = Forest.standSpan(layout)
				expect(span.minX).to.equal(layout.centre.X + (1 - middle) * layout.standSpacing)
				expect(span.maxX).to.equal(layout.centre.X + (layout.standCount - middle) * layout.standSpacing)
				expect(Forest.beaterNorthStuds(layout)).to.equal(Forest.beaterNorthStuds())
				expect(Forest.beaterNorthStuds(layout)).to.equal(
					Forest.LINE.spawnNorthStuds + Forest.BEATER.behindLineStuds
				)
				expect(Forest.exitZOf(layout)).to.equal(
					layout.centre.Z - layout.amplitudeStuds - Forest.EXIT_SOUTH_STUDS
				)
				local box = Forest.boundsOf(layout)
				expect(box.minX).to.equal(layout.centre.X - layout.halfSpanStuds)
				expect(box.maxX).to.equal(layout.centre.X + layout.halfSpanStuds)
				expect(box.minZ).to.equal(Forest.exitZOf(layout) - 100)
				expect(box.maxZ).to.equal(layout.centre.Z + Forest.DRIVERS.startNorthStuds + 200)
				local field = Forest.fieldFor(layout)
				expect(field.bounds.maxZ).to.equal(box.maxZ)
				expect(field.exitZ).to.equal(Forest.exitZOf(layout))
				local corridor = Forest.corridorOf(layout)
				expect(corridor.minX).to.equal(span.minX)
				expect(corridor.maxX).to.equal(span.maxX)
				expect(corridor.maxZ).to.equal(layout.centre.Z + Forest.beaterNorthStuds())
				-- AND `linePosts` IS THE POST LIST ITSELF where there are no sides, so every reader
				-- of it in `Match` answers exactly what it answered before this task.
				local set = Markers.build(Forest.standX(1, layout), layout, flatGround, flatGround)
				expect(#set.linePosts).to.equal(#set.posts)
				expect(#set.linePosts).to.equal(layout.standCount)
				for index, post in ipairs(set.posts) do
					expect(set.linePosts[index]).to.equal(post)
				end
			end
			-- THE ROAD'S OWN FIVE NUMBERS, PINNED AS LITERALS (`forest_stand.spec`'s own anchor), so
			-- a change to the formula above cannot move them unnoticed.
			local road = Forest.fieldFor(Forest.layoutNamed("road"))
			expect(road.bounds.minX).to.equal(2230)
			expect(road.bounds.maxX).to.equal(3830)
			expect(road.bounds.minZ).to.equal(-2477)
			expect(road.bounds.maxZ).to.equal(-1197)
			expect(road.exitZ).to.equal(-2377)
			expect(Forest.beaterNorthStuds()).to.equal(580)
			Markers.clear()
		end)
	end)

	-- ---------------------------------------------------------------- 4. a cell IS a layout

	describe("a cell as a layout", function()
		it("agrees with ForestTest.standPosition on every main index, and names every side", function()
			local c = Grid.CONFIG
			for _, id in ipairs(Grid.cellIds()) do
				local layout = Grid.layoutFor(id)
				-- THE ROW `ForestTest.LAYOUTS` TAKES: fifteen stands, the main line's spacing, the
				-- cell's own half width, and all four new fields present.
				expect(layout.name).to.equal(id)
				expect(layout.standCount).to.equal(15)
				expect(layout.standSpacing).to.equal(c.mainSpacingStuds)
				expect(layout.amplitudeStuds).to.equal(0)
				expect(layout.halfSpanStuds).to.equal(c.cellWidthStuds / 2)
				expect(layout.sides.main.count).to.equal(c.mainStandCount)
				expect(layout.sides.flanks.count).to.equal(c.flankStandCount)
				expect(layout.sides.flanks.firstStuds).to.equal(Grid.flankFirstStuds())
				expect(layout.beaterNorthStuds).to.equal(c.cellDepthStuds)
				expect(layout.fieldNorthStuds).to.equal(c.cellDepthStuds + c.roadClearStuds)
				expect(layout.cellOf.row).to.equal((Grid.cellOf(id) :: any).row)
				expect(layout.cellOf.column).to.equal((Grid.cellOf(id) :: any).column)
				-- MEMOISED: the boot compares a promoted layout by identity, so a fresh table per
				-- call would be a layout that never stops changing.
				expect(Grid.layoutFor(id)).to.equal(layout)
				-- THE TWO ARITHMETICS AGREE EXACTLY ON A MAIN INDEX, which is the whole of 6.2, and
				-- they can only do it through the delegation: `(15 + 1) / 2` is 8, so the old
				-- formula would put stand 1 at `centre.X - 1050`.
				for index = 1, c.mainStandCount do
					local a = Forest.standPosition(index, layout)
					local b = Grid.standPosition(id, index)
					expect((a - b).Magnitude < 1e-9).to.equal(true)
					expect(math.abs(Forest.standX(index, layout) - b.X) < 1e-9).to.equal(true)
					expect(Grid.sideOf(id, index)).to.equal("main")
				end
				for index = c.mainStandCount + 1, c.mainStandCount + c.flankStandCount do
					expect(Grid.sideOf(id, index)).to.equal("west")
				end
				for index = c.mainStandCount + c.flankStandCount + 1, Grid.standCount(id) do
					expect(Grid.sideOf(id, index)).to.equal("east")
				end
				-- A FLANK STAND IS NOT ON THE MAIN ROAD, so the delegation is doing work rather than
				-- reproducing one line.
				local roads = Grid.roadsOf(id)
				for index = c.mainStandCount + 1, Grid.standCount(id) do
					local at = Forest.standPosition(index, layout)
					expect(at.Z > roads.main.at + 1).to.equal(true)
					local onFlank = math.abs(at.X - roads.west.at) < 1e-6 or math.abs(at.X - roads.east.at) < 1e-6
					expect(onFlank).to.equal(true)
				end
				-- AN INDEX NOBODY HAS IS AN ERROR AND NOT A POINT OUTSIDE THE WORLD (327a note (d)):
				-- 327b wires a client-supplied index into this seam.
				expect(pcall(Grid.standPosition, id, 16)).to.equal(false)
				expect(pcall(Grid.standPosition, id, 0)).to.equal(false)
				expect(pcall(Grid.standPosition, id, 7.5)).to.equal(false)
				expect(pcall(Grid.sideOf, id, 99)).to.equal(false)
			end
			TestKit.note(
				string.format(
					"cell A1: %d stands, main %d at %d, flanks %d at %d from %d",
					Grid.standCount("A1"),
					Grid.CONFIG.mainStandCount,
					Grid.CONFIG.mainSpacingStuds,
					Grid.CONFIG.flankStandCount,
					Grid.CONFIG.flankSpacingStuds,
					Grid.flankFirstStuds()
				)
			)
		end)

		it("gives a cell fifteen posts of which seven answer a line question", function()
			local layout = Grid.layoutFor("A1")
			local set = Markers.build(Forest.standX(4, layout), layout, flatGround, flatGround)
			expect(#set.posts).to.equal(15)
			expect(#set.linePosts).to.equal(Grid.CONFIG.mainStandCount)
			for index = 1, Grid.CONFIG.mainStandCount do
				expect(set.linePosts[index]).to.equal(set.posts[index])
			end
			-- NOT ONE FLANK POST IS IN IT, read off the names rather than off the count.
			for _, post in ipairs(set.linePosts) do
				local index = tonumber(string.match(post.Name, "^Stand(%d+)$"))
				expect(index ~= nil).to.equal(true)
				expect(Grid.sideOf("A1", index :: number)).to.equal("main")
			end
			Markers.clear()
		end)
	end)

	-- ---------------------------------------------------------------- 7. a flank post never answers

	describe("the line question", function()
		it("is answered by a main post even where a flank post is nearer laterally", function()
			local id = "A1"
			local layout = Grid.layoutFor(id)
			local roads = Grid.roadsOf(id)
			local line = { position = Vector3.new(layout.centre.X, 0, roads.main.at), normal = Vector3.zAxis }
			local function fake(count: number): { any }
				local out = {}
				for index = 1, count do
					table.insert(out, { Position = Grid.standPosition(id, index) })
				end
				return out
			end
			-- DESIGN 6.4's OWN x: the beater walks south 510 studs east of the cell's centre, where
			-- the east flank's first post is laterally NEARER than the main line's end post.
			local mainEnd = Grid.standPosition(id, Grid.CONFIG.mainStandCount)
			local flankFirst = Grid.standPosition(id, Grid.CONFIG.mainStandCount + Grid.CONFIG.flankStandCount + 1)
			local beaterX = layout.centre.X + 510
			local at = Vector3.new(beaterX, 0, roads.main.at + 700)
			expect(math.abs(flankFirst.X - beaterX) < math.abs(mainEnd.X - beaterX)).to.equal(true)
			-- THE DEFECT, SHOWN FIRST so this case cannot pass with the fix deleted: handed every
			-- post, the reference IS the flank post, 340 studs up the cell.
			local wrong = Match.lineReferenceFor(at, line, fake(Grid.standCount(id)))
			expect(math.abs((wrong :: Vector3).Z - flankFirst.Z) < 1e-6).to.equal(true)
			expect((wrong :: Vector3).Z - roads.main.at >= Grid.flankFirstStuds() - 1e-6).to.equal(true)
			-- ...AND HANDED `linePosts` IT IS THE MAIN POST, ON THE ROAD.
			local right = Match.lineReferenceFor(at, line, fake(Grid.CONFIG.mainStandCount))
			expect(math.abs((right :: Vector3).Z - roads.main.at) < 1e-6).to.equal(true)
			expect(math.abs((right :: Vector3).X - mainEnd.X) < 1e-6).to.equal(true)
			-- AND THE DRIVE DOES NOT END THERE: a beater 700 studs north of the road has not crossed
			-- it, where against the flank post he had.
			expect(Match.crossedLine(at, line, fake(Grid.CONFIG.mainStandCount), 0)).to.equal(false)
			expect(Match.crossedLine(at, line, fake(Grid.standCount(id)), 0)).to.equal(true)
			TestKit.note(
				string.format(
					"beater at x %+.0f: main post %.0f studs laterally, flank post %.0f -- the flank wins by %.0f, and its z is %+.0f",
					beaterX - layout.centre.X,
					math.abs(mainEnd.X - beaterX),
					math.abs(flankFirst.X - beaterX),
					math.abs(mainEnd.X - beaterX) - math.abs(flankFirst.X - beaterX),
					flankFirst.Z - roads.main.at
				)
			)
		end)
	end)

	-- ---------------------------------------------------------------- 8. the waves stay on the line

	describe("the wave's aim", function()
		it("is clamped to the main line's span on both flanks", function()
			local id = "A1"
			local layout = Grid.layoutFor(id)
			local span = Forest.standSpan(layout)
			local c = Grid.CONFIG
			-- THE SPAN IS THE MAIN LINE'S, not the fifteen stands': `standX(15)` is an east flank
			-- stand 556 studs out, and `corridorOf` and `hunterStandX` both read this rectangle.
			local half = ((c.mainStandCount - 1) / 2) * c.mainSpacingStuds
			expect(math.abs(span.minX - (layout.centre.X - half)) < 1e-9).to.equal(true)
			expect(math.abs(span.maxX - (layout.centre.X + half)) < 1e-9).to.equal(true)
			local west = Grid.standPosition(id, c.mainStandCount + 1)
			local east = Grid.standPosition(id, c.mainStandCount + c.flankStandCount + 1)
			expect(west.X < span.minX).to.equal(true)
			expect(east.X > span.maxX).to.equal(true)
			-- BOTH ENDS CLAMP ONTO THE LINE, which is what `ForestTest.hunterStandX` does with the
			-- pick it is handed (design 6.4). The clamp itself is asserted here as the arithmetic the
			-- server reads, because `hunterStandX` reads live pick state.
			expect(math.clamp(west.X, span.minX, span.maxX)).to.equal(span.minX)
			expect(math.clamp(east.X, span.minX, span.maxX)).to.equal(span.maxX)
			-- A MAIN STAND IS NOT MOVED BY IT.
			for index = 1, c.mainStandCount do
				local x = Grid.standPosition(id, index).X
				expect(math.clamp(x, span.minX, span.maxX)).to.equal(x)
			end
			-- AND THE CORRIDOR IS THE CELL AND NOT THE FLANK ROADS.
			local corridor = Forest.corridorOf(layout)
			expect(corridor.minX).to.equal(span.minX)
			expect(corridor.maxX).to.equal(span.maxX)
			expect(corridor.maxZ).to.equal(layout.centre.Z + c.cellDepthStuds)
			TestKit.note(
				string.format(
					"main span %.0f..%.0f (%.0f wide); west flank at %.0f, east at %.0f -- both clamped",
					span.minX,
					span.maxX,
					span.maxX - span.minX,
					west.X,
					east.X
				)
			)
		end)
	end)

	-- ---------------------------------------------------------------- 10. the release clamp

	describe("the release clamp", function()
		it("does not bite on a cell, where on today's road it pins the last slots to the floor", function()
			local layout = Grid.layoutFor("A1")
			local schedule = Forest.SCHEDULE
			local walk = Grid.CONFIG.beaterWalkStudsPerSecond
			local slots = 0
			for _, row in ipairs(schedule.drive) do
				slots = math.max(slots, row.slot)
			end
			local lastSlotAt = Forest.slotSeconds(slots, schedule)
			-- WHERE THE LINE IS WHEN THE LAST SLOT IS DUE: the cell's whole depth less the walk.
			local lineNorth = Forest.beaterNorthStuds(layout) - walk * lastSlotAt
			expect(lineNorth > 0).to.equal(true)
			local worst, worstSlot = math.huge, 0
			for _, row in ipairs(schedule.drive) do
				local at = Forest.slotSeconds(row.slot, schedule)
				local line = Forest.beaterNorthStuds(layout) - walk * at
				local depth = Forest.releaseDepth(row.northStuds, line, Forest.routeFloor(row, schedule), schedule)
				-- NEVER THE FLOOR: a row pinned to `minNorthStuds` is a sounder put down 25 studs in
				-- front of the hunter, which is what task 251c had to accept on the 580-stud road.
				expect(depth > schedule.minNorthStuds).to.equal(true)
				-- AND ALWAYS AT LEAST `leadStuds` OF ROOM IN FRONT OF THE MEN.
				expect(line - depth >= schedule.leadStuds - 1e-9).to.equal(true)
				if line - depth < worst then
					worst, worstSlot = line - depth, row.slot
				end
			end
			-- THE SAME ARITHMETIC ON TODAY'S ROAD DOES BITE, which is what makes this a measurement
			-- of the deeper cell and not of `releaseDepth`.
			local road = Forest.layoutNamed("road") :: any
			local bitten = 0
			for _, row in ipairs(schedule.drive) do
				local at = Forest.slotSeconds(row.slot, schedule)
				local line = Forest.beaterNorthStuds(road) - Bots.CONFIG.WALK_SPEED * at
				local depth = Forest.releaseDepth(row.northStuds, line, Forest.routeFloor(row, schedule), schedule)
				if depth <= schedule.minNorthStuds then
					bitten += 1
				end
			end
			expect(bitten > 0).to.equal(true)
			TestKit.note(
				string.format(
					"cell: slot %d is the tightest at %.0f studs of lead (asked %d); line at %.0f when slot %d is due; today's road pins %d of %d rows to the %d-stud floor",
					worstSlot,
					worst,
					schedule.leadStuds,
					lineNorth,
					slots,
					bitten,
					#schedule.drive,
					schedule.minNorthStuds
				)
			)
		end)
	end)

	-- ---------------------------------------------------------------- 11. the walk

	describe("the stand walk", function()
		it("is the main line centre-out, then the flanks alternating near-first", function()
			local walk = Grid.standWalk("C2")
			local expected = { 4, 3, 5, 2, 6, 1, 7, 8, 12, 9, 13, 10, 14, 11, 15 }
			expect(#walk).to.equal(#expected)
			for index, value in ipairs(expected) do
				expect(walk[index]).to.equal(value)
			end
			-- A PERMUTATION OF 1..15, so no stand is offered twice and none is unreachable.
			local seen = {}
			for _, value in ipairs(walk) do
				expect(seen[value]).to.equal(nil)
				expect(value >= 1 and value <= 15).to.equal(true)
				seen[value] = true
			end
			for index = 1, 15 do
				expect(seen[index]).to.equal(true)
			end
			-- THE FIRST STAND OFFERED IS THE MIDDLE OF THE LINE, which is `ForestTest.standWalk`'s
			-- own rule: a lone hunter stands in the middle.
			expect(walk[1]).to.equal(math.ceil(Grid.CONFIG.mainStandCount / 2))
			expect(Grid.sideOf("C2", walk[1])).to.equal("main")
			-- AND ONE FLANK IS NEVER FILLED BEFORE THE OTHER IS TOUCHED.
			local west, east = 0, 0
			for index = 8, 15 do
				local side = Grid.sideOf("C2", walk[index])
				if side == "west" then
					west += 1
				else
					east += 1
				end
				expect(math.abs(west - east) <= 1).to.equal(true)
			end
		end)
	end)

	-- ---------------------------------------------------------------- 19. the roads are painted

	describe("the road paint", function()
		local function recorder()
			local calls = {}
			return {
				regions = calls,
				ReplaceMaterial = function(_self, region, resolution, source, target)
					table.insert(calls, {
						region = region,
						resolution = resolution,
						source = source,
						target = target,
					})
				end,
			}
		end

		it("paints through an injected terrain, inside every road, under the call budget", function()
			-- THE TERRAIN IS A FAKE WITH A RECORDING `ReplaceMaterial`, so no spec in the DEV place
			-- can write DEV's terrain -- `Places.Ground`'s own discipline.
			local terrain = recorder()
			local surface = Plan.surfaceFor("track")
			expect(surface ~= nil).to.equal(true)
			expect(surface.halfWidthStuds * 2).to.equal(Grid.CONFIG.roadPaintStuds)
			local roads = Grid.roads()
			-- A FLAT FAKE HILLSIDE at a known height, so the y band is arithmetic.
			local reader = function(_x: number, _z: number)
				return 100
			end
			local calls = Ground.paintRoads(terrain, roads, surface, reader, true)
			expect(calls).to.equal(#terrain.regions)
			expect(calls > 0).to.equal(true)
			expect(calls <= Ground.ROAD_CALL_BUDGET).to.equal(true)
			-- 30 BANDS x 9 SOURCE MATERIALS (ten, less the one being painted) = 270.
			local sources = 0
			for _, material in ipairs(Ground.SOURCE_MATERIALS) do
				if material ~= surface.material then
					sources += 1
				end
			end
			local bands = 0
			for _, road in ipairs(roads) do
				bands += #Ground.roadChunks(road)
			end
			expect(calls).to.equal(bands * sources)
			-- EVERY REGION IS INSIDE ITS ROAD'S OWN CLEAR WIDTH -- the 21 studs either side of the
			-- centre line that no tree may stand in. The snap widens a band by up to a voxel column
			-- either side (`Ground.bandBounds`), and 9 + 4 is still well inside 21.
			local slack = Grid.CONFIG.roadClearStuds / 2
			for _, call in ipairs(terrain.regions) do
				expect(call.resolution).to.equal(Ground.RESOLUTION)
				expect(call.target).to.equal(surface.material)
				expect(call.source ~= surface.material).to.equal(true)
				local min = call.region.CFrame.Position - call.region.Size / 2
				local max = call.region.CFrame.Position + call.region.Size / 2
				local inside = false
				for _, road in ipairs(roads) do
					if road.axis == "x" then
						if
							min.Z >= road.at - slack
							and max.Z <= road.at + slack
							and min.X >= road.from - Ground.RESOLUTION
							and max.X <= road.to + Ground.RESOLUTION
						then
							inside = true
						end
					else
						if
							min.X >= road.at - slack
							and max.X <= road.at + slack
							and min.Z >= road.from - Ground.RESOLUTION
							and max.Z <= road.to + Ground.RESOLUTION
						then
							inside = true
						end
					end
				end
				expect(inside).to.equal(true)
			end
			-- ...AND ZERO CALLS WHEN IT IS OFF. The flag's own state, reachable by parameter.
			local quiet = recorder()
			expect(Ground.paintRoads(quiet, roads, surface, reader, false)).to.equal(0)
			expect(#quiet.regions).to.equal(0)
			-- A CHUNK IS DERIVED FROM THE BUDGET, not chosen: nine calls a band over 28,400 studs of
			-- road cannot fit in 300 at any shorter chunk.
			local roadStuds = 0
			for _, road in ipairs(roads) do
				roadStuds += road.to - road.from
			end
			expect(roadStuds).to.equal(3 * 4490 + 5 * 2986)
			expect(Ground.ROAD_CHUNK_STUDS >= roadStuds * sources / Ground.ROAD_CALL_BUDGET).to.equal(true)
			-- THE SLICE SPENDS THE FRAME IT PROMISED: `breathe` is called, and never with more than
			-- `ROAD_CALLS_PER_STEP` calls between two of them.
			local breaths = 0
			local sliced = recorder()
			Ground.paintRoads(sliced, roads, surface, reader, true, function()
				breaths += 1
			end)
			-- ONE BREATH EVERY `ROAD_CALLS_PER_STEP` CALLS, so a 270-call paint is spread over ~135
			-- frames and not one.
			expect(breaths).to.equal(math.floor(calls / Ground.ROAD_CALLS_PER_STEP))
			TestKit.note(
				string.format(
					"road paint: %d calls (budget %d), %d bands x %d materials, %d studs of road, %d breaths",
					calls,
					Ground.ROAD_CALL_BUDGET,
					bands,
					sources,
					roadStuds,
					breaths
				)
			)
		end)

		it("skips a chunk with no ground under it rather than painting the sky", function()
			local terrain = recorder()
			local surface = Plan.surfaceFor("track")
			local none = function(_x: number, _z: number)
				return nil
			end
			expect(Ground.paintRoads(terrain, Grid.roads(), surface, none, true)).to.equal(0)
			-- AND THE Y BAND IS THE MEASURED GROUND, PADDED -- not `centre.Y` and not a constant.
			local road = Grid.roads()[1]
			local low, high = Ground.roadYBand(road, road.from, road.from + 100, function(x: number, _z: number)
				return 100 + x * 0
			end)
			expect(low).to.equal(100 - Ground.Y_PAD_STUDS)
			expect(high).to.equal(100 + Ground.Y_PAD_STUDS)
		end)
	end)

	-- ---------------------------------------------------------------- 22. the preview tags nothing

	describe("the preview", function()
		it("stakes the corners and changes nothing else about the world", function()
			-- THE FLAG IS REACHABLE BY PARAMETER, which is what lets both states be asserted while
			-- `GRID_PREVIEW` sits at one of them (CLAUDE.md, "Feature flags").
			local before = Forest.layoutNames()
			local world = Instance.new("Folder")
			local reader = function(_x: number, _z: number)
				return 120
			end
			local terrain = {
				ReplaceMaterial = function() end,
			}
			local report = Planter.build(reader, world, terrain, true)
			-- 8 CELLS x 4 CORNERS.
			expect(report.gridStakes).to.equal(32)
			expect(report.gridMissing).to.equal(0)
			local folder = world:FindFirstChild(Planter.GRID_FOLDER)
			expect(folder ~= nil).to.equal(true)
			expect(#folder:GetChildren()).to.equal(32)
			-- IT TAGS NOTHING, BUILDS NO STAND AND NO SEAT, and the layout list does not move: with
			-- the preview on, everything the drive reads answers exactly what it answered before.
			for _, child in ipairs(folder:GetChildren()) do
				expect(child:IsA("BasePart")).to.equal(true)
				-- A STAKE MUST NOT BE THE GROUND AND MUST NOT STOP A BULLET.
				expect(child.CanQuery).to.equal(false)
				expect(child.CanCollide).to.equal(false)
				expect(child.Anchored).to.equal(true)
				expect(string.find(child.Name, "^Stake_") ~= nil).to.equal(true)
				expect(string.find(child.Name, "^Stand") == nil).to.equal(true)
				expect(#child:GetTags()).to.equal(0)
			end
			expect(world:FindFirstChild("ForestMarkers")).to.equal(nil)
			expect(world:FindFirstChild("HighSeats")).to.equal(nil)
			local after = Forest.layoutNames()
			expect(#after).to.equal(#before)
			for index, name in ipairs(before) do
				expect(after[index]).to.equal(name)
			end
			-- NO CELL ROW IS IN `LAYOUTS` YET (that is task 327d), so a cell id cannot be dealt as a
			-- layout by accident.
			for _, id in ipairs(Grid.cellIds()) do
				expect(Forest.layoutNamed(id)).to.equal(nil)
			end

			-- ...AND WITH IT OFF, NOTHING AT ALL. The same call, the same world, one boolean apart.
			local quiet = Instance.new("Folder")
			local off = Planter.build(reader, quiet, terrain, false)
			expect(off.gridStakes).to.equal(0)
			expect(off.gridPaints).to.equal(0)
			expect(quiet:FindFirstChild(Planter.GRID_FOLDER)).to.equal(nil)
			-- THE FOLDER NAME IS ONE FACT with the ground-ignore list, so a stake can never answer
			-- "where is the ground" even though its parts are already unqueryable.
			expect(table.find(Forest.GROUND_IGNORE, Planter.GRID_FOLDER) ~= nil).to.equal(true)
			-- A SECOND BUILD REBUILDS RATHER THAN DOUBLING, and an OFF build cleans up an ON one:
			-- design 11.3 step 2's rule, in the direction this task can reach.
			Planter.build(reader, world, terrain, false)
			expect(world:FindFirstChild(Planter.GRID_FOLDER)).to.equal(nil)
			world:Destroy()
			quiet:Destroy()
			TestKit.note(
				string.format(
					"preview on: %d stakes, %d layouts before and after; preview off: %d stakes",
					report.gridStakes,
					#after,
					off.gridStakes
				)
			)
		end)
	end)
end
