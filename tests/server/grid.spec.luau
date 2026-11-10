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
	local HighSeats = require(ReplicatedStorage:WaitForChild("HighSeats"))
	local Planter = require(ServerScriptService:WaitForChild("Places"))
	-- `Places.Ground` LEFT THIS FILE WITH CASE 19 (task 328e): nothing here reads it now.
	-- `grid_relief.spec`'s 328e-5 is what asserts the archived names are gone.
	local Match = require(ServerScriptService:WaitForChild("Match"))
	local Bots = require(ServerScriptService:WaitForChild("Bots"))
	local ForestTest = require(ServerScriptService:WaitForChild("ForestTest"))
	local Markers = ForestTest.Markers

	-- A FLAT WORLD AT A KNOWN HEIGHT, so the cases about the POST LIST are not cases about DEV's
	-- terrain (`forest_markers.spec`'s own fixture).
	local function flatGround(_x: number, _z: number): number?
		return 140
	end

	-- THE TWO STATES, BY PARAMETER (task 328q). `Grid.CONFIG.bend` ships at 0 and every function
	-- that carries the bend takes it as a trailing optional, so the BENT world is reachable here
	-- while the world Karen plays stays straight. 45 / 60 / 1 is what task 328r commits.
	local STRAIGHT = { ewStuds = 0, nsStuds = 0, harmonic = 1 }
	local BENT = { ewStuds = 45, nsStuds = 60, harmonic = 1 }

	-- C1's WHOLE PLAN, OWN WOOD PLUS A SKIRT ACROSS ALL FOUR ROADS (task 337c), at the shipped bend
	-- and in the straight world. MEASURED (`<runs-dir>/337c-plan-all.txt`,
	-- `<runs-dir>/337c-straight.luau`), not a bound: a count that moves on its own means a recipe
	-- changed by accident. Named once, because cases 5 and 6 pin the same two numbers.
	local BENT_C1, STRAIGHT_C1 = 3558, 3574

	-- A STAND IN WORLD COORDINATES AT ANY AMPLITUDE: the grid point through the map, which is
	-- exactly what `Grid.standPosition` does at the shipped bend. Two returns, x and z.
	local function worldStand(id: string, index: number, bend: any): (number, number)
		local u, v = Grid.standGridOf(id, index, bend)
		return Grid.toWorld(u, v, bend)
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
			-- TASK 328h: WHAT ROW 1's BAKE SHIPPED, pinned to the stud it was measured at, and C1's
			-- row pinned UNCHANGED beside it -- so a re-bake that moved C1 would redden here. The
			-- numbers are `terrainbake.py survey --cells B1,C1,D1` (3,888 samples a cell) plus 54
			-- samples along the realised main line for `lineSpreadStuds`; the towers are 218's
			-- instrument re-run in a PLAY session (design 6.1).
			for _, row in ipairs({
				{ "B1", 66.05, 189.54, 123.50, 22.82, 81.29, { 8, 10, 12, 14 } },
				{ "C1", 89.14, 150.26, 61.12, 20.49, 106.03, { 8, 10, 13 } },
				{ "D1", 101.83, 166.26, 64.43, 36.27, 135.85, { 9 } },
			}) do
				local cell = Grid.cellOf(row[1] :: string)
				expect(cell.relief.minY).to.equal(row[2])
				expect(cell.relief.maxY).to.equal(row[3])
				expect(cell.relief.spreadStuds).to.equal(row[4])
				expect(cell.relief.lineSpreadStuds).to.equal(row[5])
				expect(cell.relief.lineMeanY).to.equal(row[6])
				local towers = Grid.towerStands(row[1] :: string)
				expect(#towers).to.equal(#(row[7] :: { number }))
				for at, want in ipairs(row[7] :: { number }) do
					expect(towers[at]).to.equal(want)
				end
				-- NO TWO ADJACENT, and the cap is five: 327b's rule, asserted on what shipped
				-- rather than re-derived from the gains this spec cannot read.
				expect(#towers <= 5).to.equal(true)
				for at = 2, #towers do
					expect(towers[at] - towers[at - 1] >= 2).to.equal(true)
				end
				-- NONE OF THE THREE RELAXED. B1's and D1's thirty pads were measured in THIS task
				-- (`spread 0.00`, `relief <= 0.12` against the 1.8 threshold); C1's fifteen were
				-- measured in 328r at `relief <= 0.10` and are carried, not re-measured here.
				expect(Grid.towersRelaxed(row[1] :: string)).to.equal(false)
			end
			-- AND THE FIVE CELLS 328h COULD NOT BAKE still carry their PRE-BAKE rows, which is what
			-- says the task is unfinished rather than that this world is done (`ESCALATE.md`).
			expect(Grid.cellOf("B2").relief.lineMeanY).to.equal(181.83)
			expect(Grid.cellOf("C2").relief.lineMeanY).to.equal(211.22)
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
			-- THE WORLD FOOTPRINT IS THE GRID ONE GROWN BY THE AMPLITUDE THAT CAN MOVE A POINT INTO
			-- IT, and every road's WORLD polyline lies inside it -- at the shipped bend and at the
			-- one 328r commits, so the bound is asserted where it can actually bind.
			for _, bend in ipairs({ STRAIGHT, BENT }) do
				local world = Grid.worldFootprint(bend)
				expect(world.minX).to.equal(box.minX - bend.nsStuds)
				expect(world.maxX).to.equal(box.maxX + bend.nsStuds)
				expect(world.minZ).to.equal(box.minZ - bend.ewStuds)
				expect(world.maxZ).to.equal(box.maxZ + bend.ewStuds)
				for _, road in ipairs(roads) do
					for _, point in ipairs(Grid.roadPolyline(road, 97, bend)) do
						local inside = point.X >= world.minX
							and point.X <= world.maxX
							and point.Y >= world.minZ
							and point.Y <= world.maxZ
						expect(inside).to.equal(true)
					end
				end
				for _, id in ipairs(Grid.cellIds()) do
					local cell, grown = Grid.boundsOf(id), Grid.worldBoundsOf(id, bend)
					expect(grown.minX).to.equal(cell.minX - bend.nsStuds)
					expect(grown.maxZ).to.equal(cell.maxZ + bend.ewStuds)
				end
			end
			TestKit.note(
				string.format(
					"footprint %.0f x %.0f at (%d, %d), %d roads; world box +%d x / +%d z at 45/60",
					box.maxX - box.minX,
					box.maxZ - box.minZ,
					c.originX,
					c.originZ,
					#roads,
					BENT.nsStuds,
					BENT.ewStuds
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
			-- AND THE SAME SWEEP IN WORLD COORDINATES AT THE AMPLITUDE 328r COMMITS, BY PARAMETER
			-- (task 328q, design 5.4 / defect F-1). This is the assertion the straight loop above
			-- cannot make: the shear takes up to 43.5 studs off the tight pair's `dx`, and it is
			-- `Grid.flankFirstStuds`' own re-derivation that pays for it. The pinned value is what
			-- gives the case teeth -- at the unfixed set-back of 340 the worst pair is 338.41, which
			-- still clears 330 and would pass a bare inequality.
			local bentWorst, bentAt = math.huge, ""
			for _, id in ipairs(Grid.cellIds()) do
				for a = 1, count - 1 do
					local ax, az = worldStand(id, a, BENT)
					for b = a + 1, count do
						if Grid.sideOf(id, a) ~= Grid.sideOf(id, b) then
							local bx, bz = worldStand(id, b, BENT)
							local apart = math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
							expect(apart >= range).to.equal(true)
							if apart < bentWorst then
								bentWorst, bentAt = apart, string.format("%s %d-%d", id, a, b)
							end
						end
					end
				end
			end
			expect(math.abs(bentWorst - 363.79) < 0.05).to.equal(true)
			-- THE MARGIN IS REPORTED AS A NUMBER, so a CONFIG change that eats it is read rather
			-- than passed over.
			expect(Match.CONFIG.SAFETY_RANGE_STUDS).to.equal(range)
			TestKit.note(
				string.format(
					"worst cross-side pair %.2f studs (%s), range %d, margin %.2f; at bend 45/60 %.2f (%s), margin %.2f",
					worst,
					worstAt,
					range,
					worst - range,
					bentWorst,
					bentAt,
					bentWorst - range
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
			-- ON THE ROAD, AND THE ROAD IS A CURVE (task 328r). `road.at` is the centreline only at
			-- amplitude 0; what holds at every amplitude is that the stand sits exactly on the
			-- road's own curve at its own station, and that the SPACING is 150 in the plane the
			-- spacing is defined in. `Vector3` stores float32, so a world tolerance is 1e-3 and not
			-- 1e-9 -- the arithmetic is exact, the storage is not.
			for index = 1, 7 do
				local at = Grid.standPosition("B1", index)
				expect(math.abs(at.Z - Grid.roadCentreAt(of.main, at.X)) < 1e-3).to.equal(true)
				if index > 1 then
					local u, _ = Grid.standGridOf("B1", index)
					local before, _v = Grid.standGridOf("B1", index - 1)
					expect(math.abs((u - before) - Grid.CONFIG.mainSpacingStuds) < 1e-9).to.equal(true)
				end
			end
			for _, side in ipairs({ { 8, 11, of.west }, { 12, 15, of.east } }) do
				for index = side[1] :: number, side[2] :: number do
					local at = Grid.standPosition("B1", index)
					expect(math.abs(at.X - Grid.roadCentreAt(side[3] :: any, at.Z)) < 1e-3).to.equal(true)
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
			-- `ceil(required) + margin` IS THE AMPLITUDE-0 SOLUTION, so it is asked of STRAIGHT. The
			-- shipped bend solves the fixed point below and answers 366 (task 328r).
			expect(Grid.flankFirstStuds(STRAIGHT)).to.equal(math.ceil(required) + c.flankMarginStuds)
			expect(Grid.flankFirstStuds(STRAIGHT)).to.equal(340)
			-- ...AND IN WORLD COORDINATES IT IS A FIXED POINT, RECOMPUTED HERE (task 328q, design
			-- 5.4). The shear takes `|bendX'|max * f` off the `dx` term and `|bendZ'|max * dx0` off
			-- the dz, so the set-back solves itself. Asserted at BOTH amplitudes and the number of
			-- steps to converge is asserted too: a formula that needed more would be a different one.
			for _, bend in ipairs({ STRAIGHT, BENT }) do
				local slopeX = bend.nsStuds * math.pi * bend.harmonic / Grid.bendPitch("z")
				local slopeZ = bend.ewStuds * math.pi * bend.harmonic / Grid.bendPitch("x")
				local f = math.ceil(required) + c.flankMarginStuds
				local steps = 0
				for _ = 1, 8 do
					local inner = dx - slopeX * f
					local next_ = math.ceil(math.sqrt(range * range - inner * inner) + slopeZ * dx) + c.flankMarginStuds
					if next_ == f then
						break
					end
					f, steps = next_, steps + 1
				end
				expect(steps <= 3).to.equal(true)
				expect(Grid.flankFirstStuds(bend)).to.equal(f)
				-- AND IT IS ENOUGH IN THE WORLD, which is the inequality the number exists for: the
				-- worst realised cross-side pair of every cell, computed from the map.
				for _, id in ipairs(Grid.cellIds()) do
					local ax, az = worldStand(id, 7, bend)
					local bx, bz = worldStand(id, 12, bend)
					expect(math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) >= range).to.equal(true)
				end
			end
			expect(Grid.flankFirstStuds(STRAIGHT)).to.equal(340)
			expect(Grid.flankFirstStuds(BENT)).to.equal(366)
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

	-- ---------------------------------------------------------------- 6b. the bend (task 328q)

	describe("the bend", function()
		-- EVERY CASE BELOW IS DRIVEN BY PARAMETER at `STRAIGHT` and at `BENT`, because the config
		-- ships at 0 and a case that can only ask 0 asserts nothing about the world 328r commits.
		-- Design: docs/design/grid-roads.md 5, 11.1.

		it("is exactly zero at every junction and exactly the amplitude at every half-pitch", function()
			local roads = Grid.roads()
			local junctions = 0
			for _, ew in ipairs(roads) do
				for _, ns in ipairs(roads) do
					if ew.axis == "x" and ns.axis == "z" then
						junctions += 1
						for _, bend in ipairs({ STRAIGHT, BENT }) do
							-- THE ZEROS. `A * sin(pi * m * k)` for integer k, and the half-wavelength
							-- IS the junction pitch (design 5.1), so this is exact and not a limit.
							expect(math.abs(Grid.bendZ(ns.at, bend)) < 1e-12).to.equal(true)
							expect(math.abs(Grid.bendX(ew.at, bend)) < 1e-12).to.equal(true)
							-- ...SO THE TWO WORLD CURVES MEET AT EXACTLY (ns.at, ew.at).
							expect(math.abs(Grid.roadCentreAt(ew, ns.at, bend) - ew.at) < 1e-12).to.equal(true)
							expect(math.abs(Grid.roadCentreAt(ns, ew.at, bend) - ns.at) < 1e-12).to.equal(true)
						end
					end
				end
			end
			expect(junctions).to.equal(15)
			-- **AND THE HALF THAT CAN FAIL AT AMPLITUDE 0** (TASKS.md 328q item (vii)): the zeros
			-- alone are `A * 0` and pass for any A, so the pair is the zeros PLUS the extremum. At
			-- half a pitch from a junction the offset IS the amplitude, to the sign.
			for _, bend in ipairs({ STRAIGHT, BENT }) do
				local atX = Grid.bendOrigin("x") + Grid.bendPitch("x") / 2
				local atZ = Grid.bendOrigin("z") + Grid.bendPitch("z") / 2
				expect(math.abs(Grid.bendZ(atX, bend) - bend.ewStuds) < 1e-9).to.equal(true)
				expect(math.abs(Grid.bendX(atZ, bend) - bend.nsStuds) < 1e-9).to.equal(true)
				-- AND THE HALF-PITCH IS THE CELL'S OWN CENTRE, which is why a stand at the middle of
				-- a main line is the one the bulge moves furthest.
				expect(math.abs(atX - (Grid.boundsOf("A1").minX + Grid.boundsOf("A1").maxX) / 2) < 1e-9).to.equal(true)
			end
			-- A NON-INTEGER HARMONIC BREAKS THE ZEROS, and that is asserted rather than asserted of:
			-- at m = 1.5 two of the five north-south junctions stop being zeros.
			local broken = { ewStuds = 45, nsStuds = 60, harmonic = 1.5 }
			local nonZero = 0
			for _, road in ipairs(roads) do
				if road.axis == "z" and math.abs(Grid.bendZ(road.at, broken)) > 1e-6 then
					nonZero += 1
				end
			end
			expect(nonZero).to.equal(2)
			expect(Grid.CONFIG.bend.harmonic % 1).to.equal(0)
			TestKit.note(
				string.format(
					"15 junctions, bend 0 to 1e-12 at every one; at 45/60 the half-pitch offsets are %.3f / %.3f; m=1.5 breaks %d of 5",
					Grid.bendZ(Grid.bendOrigin("x") + Grid.bendPitch("x") / 2, BENT),
					Grid.bendX(Grid.bendOrigin("z") + Grid.bendPitch("z") / 2, BENT),
					nonZero
				)
			)
		end)

		it("maps between grid and world both ways, inside the contraction's own bound", function()
			-- THE BOUND IS DERIVED PER AMPLITUDE, not typed: the fixed point contracts by
			-- `q = |bendZ'|max * |bendX'|max` per step, so after `TO_WORLD_STEPS` an initial error of
			-- at most `ewStuds + nsStuds` is down to `(ewStuds + nsStuds) * q^steps`.
			--
			-- **A CORRECTION TO DESIGN 11.1 CASE 2, MEASURED HERE:** it asks for 1e-6 "at the shipped
			-- bend and at twice it". At 45 / 60 the residual is 1.2e-7 and 1e-6 holds; at 90 / 120
			-- the same five steps leave 1.2e-4, because q quadruples. The derived bound is what this
			-- case asserts, and 1e-6 is asserted where it is true.
			local box = Grid.footprint()
			local twice = { ewStuds = 2 * BENT.ewStuds, nsStuds = 2 * BENT.nsStuds, harmonic = 1 }
			local worstJacobian, points = 0, 0
			local rounds: { [number]: number } = {}
			for index, bend in ipairs({ STRAIGHT, BENT, twice }) do
				local worstRound = 0
				for x = box.minX, box.maxX, 50 do
					for z = box.minZ, box.maxZ, 50 do
						points += 1
						-- `toGrid` IS THE DEFINITION and `toWorld` is its numeric inverse, so BOTH
						-- compositions have to come home (design 5.6).
						local u, v = Grid.toGrid(x, z, bend)
						local bx, bz = Grid.toWorld(u, v, bend)
						worstRound = math.max(worstRound, math.abs(bx - x), math.abs(bz - z))
						local fx, fz = Grid.toWorld(x, z, bend)
						local gu, gv = Grid.toGrid(fx, fz, bend)
						worstRound = math.max(worstRound, math.abs(gu - x), math.abs(gv - z))
						-- THE SHEAR JACOBIAN, `1 - bendZ' * bendX'` (design 5.6): it is what bounds a
						-- cell's area, and therefore `cellCapacity`, to 1.63 %.
						local j = 1 - Grid.bendSlopeZ(x, bend) * Grid.bendSlopeX(z, bend)
						worstJacobian = math.max(worstJacobian, math.abs(j - 1))
					end
				end
				local q = (bend.ewStuds * math.pi * bend.harmonic / Grid.bendPitch("x"))
					* (bend.nsStuds * math.pi * bend.harmonic / Grid.bendPitch("z"))
				-- A FACTOR OF 2 ON THE DERIVED BOUND (round 2 note): at 45/60 the realised residual is
				-- 1.17e-7 against a bound of 1.20e-7, which is 2.6 % of margin -- one `math.sin` ulp
				-- or a change to the lattice step would redden a correct map.
				expect(worstRound <= 2 * (bend.ewStuds + bend.nsStuds) * q ^ Grid.TO_WORLD_STEPS).to.equal(true)
				rounds[index] = worstRound
			end
			-- AT 0 THE MAP IS THE IDENTITY, EXACTLY; at the shipped 45 / 60 the design's 1e-6 holds.
			expect(rounds[1]).to.equal(0)
			expect(rounds[2] < 1e-6).to.equal(true)
			expect(rounds[3] > 1e-6).to.equal(true)
			-- THE SHEAR IS REAL AND NOT ZERO: 4 x 0.0163 at twice the bend, and a map that never
			-- moved would read 0 here.
			expect(worstJacobian > 0.06 and worstJacobian < 0.07).to.equal(true)
			expect(Grid.TO_WORLD_STEPS).to.equal(5)
			TestKit.note(
				string.format(
					"%d lattice points: worst round-trip %.2e / %.2e / %.2e studs at 0, 45-60, 90-120; worst |J-1| %.4f",
					points,
					rounds[1],
					rounds[2],
					rounds[3],
					worstJacobian
				)
			)
		end)

		it("swings equally on both axes, which is the rule the pair was chosen by", function()
			-- DESIGN 5.2: ONE angle for the whole world, because every bound in the design -- the
			-- cone, the +Z normal, the perpendicular measure, the voxel stair -- is written in it.
			for _, bend in ipairs({ STRAIGHT, BENT }) do
				local ew = Grid.bendFacts("x", bend)
				local ns = Grid.bendFacts("z", bend)
				expect(math.abs(ew.swingDeg - ns.swingDeg) < 0.1).to.equal(true)
				expect(ew.pitchStuds).to.equal(Grid.CONFIG.cellWidthStuds + Grid.CONFIG.roadClearStuds)
				expect(ns.pitchStuds).to.equal(Grid.CONFIG.cellDepthStuds + Grid.CONFIG.roadClearStuds)
				expect(ew.amplitudeStuds).to.equal(bend.ewStuds)
				expect(ns.amplitudeStuds).to.equal(bend.nsStuds)
			end
			-- AND AT 0 THE ANGLE IS 0 AND THE THREE DERIVED LENGTHS ARE INFINITE: a straight road has
			-- no plan radius, no sight limit and no voxel stair. Asserted, so the zero case is a
			-- stated answer and not an accident of arithmetic.
			local flat = Grid.bendFacts("x", STRAIGHT)
			expect(flat.swingDeg).to.equal(0)
			expect(flat.radiusStuds).to.equal(math.huge)
			expect(flat.sightStuds).to.equal(math.huge)
			expect(flat.stairStuds).to.equal(math.huge)
		end)

		it("gives the two roads of an axis the SAME curve, so a cell's depth is exact", function()
			-- THIS IS THE CASE THAT KEEPS `grid-map.md` 4.3's 275-SECOND BEATER WALK (design 2 item
			-- 3 / TASKS.md 328q item (iii)): the exact-translate property, which is the assertable
			-- thing -- the old row restated `cellDepthStuds` and could not fail.
			local roads = Grid.roads()
			local ew, ns = {}, {}
			for _, road in ipairs(roads) do
				table.insert(if road.axis == "x" then ew else ns, road)
			end
			local box = Grid.footprint()
			local worst, worstDepth, stations = 0, 0, 0
			for _, bend in ipairs({ STRAIGHT, BENT }) do
				for i = 1, 200 do
					local x = box.minX + (box.maxX - box.minX) * (i - 1) / 199
					stations += 1
					local first = Grid.roadCentreAt(ew[1], x, bend) - ew[1].at
					for k = 2, #ew do
						worst = math.max(worst, math.abs((Grid.roadCentreAt(ew[k], x, bend) - ew[k].at) - first))
					end
					-- SO THE CELL'S DEPTH ALONG THIS COLUMN IS `cellDepthStuds` EXACTLY: the main
					-- road and the muster road are the same curve, 1472 apart.
					local of = Grid.roadsOf("A1")
					local depth = Grid.roadCentreAt(of.muster, x, bend) - Grid.roadCentreAt(of.main, x, bend)
					worstDepth = math.max(worstDepth, math.abs(depth - (of.muster.at - of.main.at)))
				end
				for i = 1, 200 do
					local z = box.minZ + (box.maxZ - box.minZ) * (i - 1) / 199
					local first = Grid.roadCentreAt(ns[1], z, bend) - ns[1].at
					for k = 2, #ns do
						worst = math.max(worst, math.abs((Grid.roadCentreAt(ns[k], z, bend) - ns[k].at) - first))
					end
				end
			end
			expect(worst < 1e-12).to.equal(true)
			expect(worstDepth < 1e-12).to.equal(true)
			-- **AND THE CURVE THE THREE ROADS SHARE IS NOT THE ZERO CURVE** (round 1 finding 4): every
			-- assertion above is a DIFFERENCE, so all of them pass with `bendZ` and `bendX` stubbed to
			-- return 0. At the half-pitch the shared offset is the amplitude itself.
			local halfX = Grid.bendOrigin("x") + Grid.bendPitch("x") / 2
			local halfZ = Grid.bendOrigin("z") + Grid.bendPitch("z") / 2
			expect(math.abs(Grid.roadCentreAt(ew[1], halfX, BENT) - ew[1].at)).to.be.near(BENT.ewStuds, 1e-9)
			expect(math.abs(Grid.roadCentreAt(ns[1], halfZ, BENT) - ns[1].at)).to.be.near(BENT.nsStuds, 1e-9)
			-- AND THE WALK IS STILL THE CLOCK'S: 1430 / 5.64 inside the 300-second drive less grace.
			local seconds = Grid.CONFIG.cellDepthStuds / Grid.CONFIG.beaterWalkStudsPerSecond
			expect(math.abs(seconds - 253.5) < 0.1).to.equal(true)
			TestKit.note(
				string.format(
					"%d stations at each of 2 amplitudes: worst translate error %.2e, worst cell depth error %.2e, walk %.1f s",
					stations / 2,
					worst,
					worstDepth,
					seconds
				)
			)
		end)

		it("derives its own facts, so nothing in the design is transcribed", function()
			-- RECOMPUTED IN THE CASE from the pitch, the amplitude and the harmonic (design 4's rule
			-- that the facts are a function and not a comment).
			for _, axis in ipairs({ "x", "z" }) do
				for _, bend in ipairs({ STRAIGHT, BENT }) do
					local facts = Grid.bendFacts(axis, bend)
					local pitch = Grid.bendPitch(axis)
					local a = if axis == "x" then bend.ewStuds else bend.nsStuds
					local m = bend.harmonic
					local slope = a * math.pi * m / pitch
					expect(math.abs(facts.swingDeg - math.deg(math.atan(slope))) < 1e-9).to.equal(true)
					if a > 0 then
						expect(math.abs(facts.radiusStuds - pitch * pitch / (a * math.pi * math.pi * m * m)) < 1e-6).to.equal(
							true
						)
						expect(
							math.abs(
								facts.sightStuds - (pitch / (math.pi * m)) * math.sqrt(2 * Grid.TRUNK_FLOOR_STUDS / a)
							) < 1e-6
						).to.equal(true)
						expect(math.abs(facts.stairStuds - Grid.VOXEL_STUDS / slope) < 1e-9).to.equal(true)
					end
				end
			end
			local ew, ns = Grid.bendFacts("x", BENT), Grid.bendFacts("z", BENT)
			TestKit.note(
				string.format(
					"at 45/60: swing %.3f / %.3f deg, plan radius %.0f / %.0f studs, view %.0f / %.0f, voxel stair %.1f / %.1f studs",
					ew.swingDeg,
					ns.swingDeg,
					ew.radiusStuds,
					ns.radiusStuds,
					ew.sightStuds,
					ns.sightStuds,
					ew.stairStuds,
					ns.stairStuds
				)
			)
		end)

		it("makes a beater cross at the bulge, not at the baseline", function()
			-- `Match.lineReferenceFor`'s OWN HEADER: "the stands stand ON the road, so the nearest
			-- one sideways is where the line really is for this beater". This is the case that
			-- mechanism was written for (design 6.5).
			local id = "A1"
			local roads = Grid.roadsOf(id)
			local line = { position = Vector3.new(0, 0, roads.main.at), normal = Vector3.zAxis }
			local function fake(bend: any): { any }
				local out = {}
				for index = 1, Grid.CONFIG.mainStandCount do
					local x, z = worldStand(id, index, bend)
					table.insert(out, { Position = Vector3.new(x, 0, z) })
				end
				return out
			end
			-- THE CELL'S CENTRE COLUMN IS THE HALF-PITCH, so the post there is a full 45 studs NORTH
			-- of `main.at` at the bent amplitude and exactly on it at the straight one.
			local bulgeX = (Grid.boundsOf(id).minX + Grid.boundsOf(id).maxX) / 2
			local _, bulgeZ = worldStand(id, 4, BENT)
			-- NOT EXACTLY 45, AND MEASURED RATHER THAN ASSUMED: the stand's grid v is an east-west
			-- road's `at`, where `bendX` is 0, but its WORLD z is 45 north of that, and `bendX` there
			-- is -5.8 studs -- which moves the station the east-west bulge is read at. The realised
			-- offset is 44.995. The 0.02 allowance is that second-order coupling and nothing else.
			expect(math.abs(bulgeZ - (roads.main.at + BENT.ewStuds)) < 0.02).to.equal(true)
			-- A BEATER HALF-WAY UP THE BULGE: 20 studs north of the baseline, 25 SOUTH of his own
			-- post. He is THROUGH against the bent line and NOT through against the straight one --
			-- the two answers disagree, which is what makes this a case and not a restatement.
			local at = Vector3.new(bulgeX, 0, roads.main.at + 20)
			local bent = Match.lineReferenceFor(at, line, fake(BENT))
			-- 1e-3 AND NOT 1e-6, for case 2's own float32 reason: the post's `Position` is a `Vector3`,
			-- so at a z of -5062 one ulp is 4.9e-4. MEASURED: this line failed at 1e-6.
			expect(math.abs((bent :: Vector3).Z - bulgeZ) < 1e-3).to.equal(true)
			expect(Match.crossedLine(at, line, fake(BENT), 0)).to.equal(true)
			expect(Match.crossedLine(at, line, fake(STRAIGHT), 0)).to.equal(false)
			-- AND NORTH OF THE BULGE HE IS NOT THROUGH EITHER WAY, so the flip is at the bulge and
			-- not simply everywhere.
			local north = Vector3.new(bulgeX, 0, roads.main.at + BENT.ewStuds + 10)
			expect(Match.crossedLine(north, line, fake(BENT), 0)).to.equal(false)
			expect(Match.crossedLine(north, line, fake(STRAIGHT), 0)).to.equal(false)
			TestKit.note(
				string.format(
					"beater %+.0f studs of main.at at the cell's centre column: bent post %+.0f (through), straight post %+.0f (not)",
					at.Z - roads.main.at,
					bulgeZ - roads.main.at,
					select(2, worldStand(id, 4, STRAIGHT)) - roads.main.at
				)
			)
		end)

		it("IS today's world at amplitude zero, value for value, DRIVEN BY PARAMETER", function()
			-- 328q's inert gate, kept and re-pointed (task 328r). It asserted the SHIPPED config was
			-- 0; the shipped config is now 45/60, so every call below names `STRAIGHT` and the case
			-- still answers its own question: the pre-328q arithmetic, written out here, against what
			-- the live functions answer at amplitude 0. The SHIPPED world is the next case.
			local c = Grid.CONFIG
			local box = Grid.footprint()
			-- 1. THE TWO MAPS ARE THE IDENTITY, exactly -- not to a tolerance.
			for x = box.minX, box.maxX, 97 do
				for z = box.minZ, box.maxZ, 97 do
					local u, v = Grid.toGrid(x, z, STRAIGHT)
					expect(u).to.equal(x)
					expect(v).to.equal(z)
					local wx, wz = Grid.toWorld(x, z, STRAIGHT)
					expect(wx).to.equal(x)
					expect(wz).to.equal(z)
				end
			end
			-- 2. `standPosition` IS THE OLD FORMULA: the cell's centre x plus the offset, at the main
			-- road's z; a flank at the road's x, `flankFirst` up, `flankSpacing` apart.
			for _, id in ipairs(Grid.cellIds()) do
				local cell = Grid.cellOf(id) :: any
				local cellBox = Grid.boundsOf(id)
				local roads = Grid.roadsOf(id)
				local centreX = (cellBox.minX + cellBox.maxX) / 2
				for index = 1, Grid.standCount(id) do
					local sx, sz = worldStand(id, index, STRAIGHT)
					local at = Vector3.new(sx, cell.relief.lineMeanY, sz)
					local side = Grid.sideOf(id, index)
					local want: Vector3
					if side == "main" then
						local middle = (c.mainStandCount + 1) / 2
						want = Vector3.new(
							centreX + (index - middle) * c.mainSpacingStuds,
							cell.relief.lineMeanY,
							roads.main.at
						)
					else
						local first = if side == "west"
							then c.mainStandCount + 1
							else c.mainStandCount + c.flankStandCount + 1
						want = Vector3.new(
							if side == "west" then roads.west.at else roads.east.at,
							cell.relief.lineMeanY,
							roads.main.at + 340 + (index - first) * c.flankSpacingStuds
						)
					end
					expect((at - want).Magnitude).to.equal(0)
				end
			end
			expect(Grid.flankFirstStuds(STRAIGHT)).to.equal(340)
			-- 2b. AND THREE OF THOSE POINTS ARE PUBLISHED PRE-328q WORLD COORDINATES, quoted from
			-- `Grid.CELLS`' own `towers` header (task 327b's shared-flank finding): C1 8 IS B1 12,
			-- C1 13 IS D1 9 and C1 15 IS D1 11. They are a DIFF against the code before this task,
			-- and not a recomputation of it.
			for _, row in ipairs({
				{ "C1", 8, -4455, -4767 },
				{ "C1", 13, -3343, -4547 },
				{ "C1", 15, -3343, -4107 },
				{ "B1", 12, -4455, -4767 },
				{ "D1", 9, -3343, -4547 },
				{ "D1", 11, -3343, -4107 },
			}) do
				local atX, atZ = worldStand(row[1] :: string, row[2] :: number, STRAIGHT)
				expect(atX).to.equal(row[3])
				expect(atZ).to.equal(row[4])
			end
			-- 2c. AND WHAT THE BEND WOULD MOVE, PRINTED: the peak offsets at 45/60, so the inert
			-- claim is read beside the size of what is being held at zero.
			local peakZ, peakX = 0, 0
			for i = 0, 200 do
				peakZ = math.max(peakZ, math.abs(Grid.bendZ(box.minX + (box.maxX - box.minX) * i / 200, BENT)))
				peakX = math.max(peakX, math.abs(Grid.bendX(box.minZ + (box.maxZ - box.minZ) * i / 200, BENT)))
			end
			expect(peakZ).to.be.near(BENT.ewStuds, 0.01)
			expect(peakX).to.be.near(BENT.nsStuds, 0.01)
			-- 3. `roadDistance` IS THE AXIS-ALIGNED MINIMUM over the roads that run past the point.
			local roads = Grid.roads()
			for x = box.minX + 13, box.maxX, 211 do
				for z = box.minZ + 7, box.maxZ, 197 do
					local want = math.huge
					for _, road in ipairs(roads) do
						if road.axis == "x" then
							if x >= road.from and x <= road.to then
								want = math.min(want, math.abs(z - road.at))
							end
						elseif z >= road.from and z <= road.to then
							want = math.min(want, math.abs(x - road.at))
						end
					end
					expect(math.abs(Plan.roadDistance(x, z, STRAIGHT) - want) < 1e-9).to.equal(true)
					expect(math.abs(Plan.roadDistanceGrid(x, z, STRAIGHT) - want) < 1e-9).to.equal(true)
				end
			end
			-- 5. `plantCell` EMITS THE SAME LIST: every row is its own grid point (the map is the
			-- identity) and is clear of the mask asked in EITHER space.
			--
			-- **TASK 337c: the skirt is drawn across all four roads again, so the number carries one
			-- again.** It was 2,538 from task 335 (C1's own rectangle, skirt withdrawn because every
			-- neighbour is planted). Measured, not a bound: a straight-world count that moved on its
			-- own would mean the recipe changed by accident.
			local drawn = Plan.plantCell("C1", nil, STRAIGHT)
			expect(#drawn).to.equal(STRAIGHT_C1)
			for _, item in ipairs(drawn) do
				local u, v = Grid.toGrid(item.x, item.z, STRAIGHT)
				expect(u).to.equal(item.x)
				expect(v).to.equal(item.z)
				-- THE TWO SPACES AGREE, WHICH IS THE INERT CLAIM. Not "== nil": a SKIRT row is planted
				-- into a neighbour and masked against THAT cell, and asking C1 about it can answer
				-- `corridor` -- which it did, and which is pre-328q semantics and not a bend defect.
				expect(Plan.mask("C1", item.x, item.z, nil, nil, STRAIGHT)).to.equal(
					Plan.maskGrid("C1", u, v, nil, nil, STRAIGHT)
				)
				expect(Plan.mask("C1", item.x, item.z, item.model, item.scale, STRAIGHT)).to.equal(
					Plan.maskGrid("C1", u, v, item.model, item.scale, STRAIGHT)
				)
			end
			local s8x, s8z = worldStand("C1", 8, STRAIGHT)
			local s13x, s13z = worldStand("C1", 13, STRAIGHT)
			local s15x, s15z = worldStand("C1", 15, STRAIGHT)
			TestKit.note(
				string.format(
					"straight BY PARAMETER: all %d stands of 8 cells exact (C1 8 = %.0f,%.0f; 13 = %.0f,%.0f; 15 = %.0f,%.0f), %d plantings in C1, both maps the identity; the SHIPPED bend is %d/%d and moves max |bendZ| %.2f, max |bendX| %.2f",
					8 * Grid.standCount("A1"),
					s8x,
					s8z,
					s13x,
					s13z,
					s15x,
					s15z,
					#drawn,
					c.bend.ewStuds,
					c.bend.nsStuds,
					peakZ,
					peakX
				)
			)
		end)

		it("IS SHIPPED BENT at 45 / 60, and every number that moved is pinned here", function()
			-- TASK 328r, THE COMMIT ITSELF (design 9.2). This is the case that fails if the bend is
			-- reverted, and it is a DIFF and not a recomputation: every world coordinate below was
			-- MEASURED off `Grid` in DEV on 2026-11-03 before the ground was baked to them, and the
			-- straight value it replaced is written beside it.
			local c = Grid.CONFIG
			expect(c.bend.ewStuds).to.equal(45)
			expect(c.bend.nsStuds).to.equal(60)
			expect(c.bend.harmonic).to.equal(1)
			expect(Grid.maxBendStuds()).to.equal(60)
			-- 1. THE SET-BACK MOVED, and this is defect F-1: the bend eats two thirds of the margin.
			expect(Grid.flankFirstStuds()).to.equal(366)
			expect(Grid.flankFirstStuds(STRAIGHT)).to.equal(340)
			-- 2. THE STANDS MOVED, to the stud. `{ index, straight x, straight z, bent x, bent z }`
			-- -- the straight pair is `Grid.CELLS`' own untouched 327b header, so each row is a diff
			-- across the commit rather than a transcription of one side of it.
			for _, row in ipairs({
				{ 1, -4349, -5107, -4350.674, -5093.928 },
				{ 4, -3899, -5107, -3904.753, -5062.006 },
				{ 8, -4455, -4767, -4496.761, -4746.297 },
				{ 13, -3343, -4547, -3400.237, -4513.755 },
				{ 15, -3343, -4107, -3391.410, -4074.865 },
			}) do
				local index = row[1] :: number
				local flatX, flatZ = worldStand("C1", index, STRAIGHT)
				expect(flatX).to.equal(row[2])
				expect(flatZ).to.equal(row[3])
				local bentX, bentZ = worldStand("C1", index, nil)
				expect(bentX).to.be.near(row[4] :: number, 0.001)
				expect(bentZ).to.be.near(row[5] :: number, 0.001)
				-- AND THE SHIPPED `standPosition` IS THAT BENT POINT, which is what puts a hunter on
				-- the pad the bake cut for him.
				-- 1e-3 AND NOT 1e-9: `standPosition` returns a `Vector3`, whose components are
				-- float32, and at |x| ~ 4,400 one float32 step is about 5e-4. The arithmetic is the
				-- same arithmetic; the storage is what rounds (measured: 1.1e-4 on stand 1).
				local at = Grid.standPosition("C1", index)
				expect(at.X).to.be.near(bentX, 1e-3)
				expect(at.Z).to.be.near(bentZ, 1e-3)
			end
			-- 3. `layoutFor`'s THREE BEND FIELDS carry the amplitude now (328q's `amplitudeStuds`,
			-- and the two spans it grows): 535 -> 595 and 1472 -> 1517.
			local layout = Grid.layoutFor("C1")
			expect(layout.amplitudeStuds).to.equal(45)
			expect(layout.halfSpanStuds).to.equal(535 + 60)
			expect(layout.fieldNorthStuds).to.equal(1472 + 45)
			expect(layout.sides.flanks.firstStuds).to.equal(366)
			-- 4. ...AND `ForestTest.roadZ`'s CELL BRANCH NO LONGER ANSWERS A CONSTANT. At amplitude 0
			-- it answered `layout.centre.Z` for every x (328q's inert case 6); the bent road has to
			-- depart from it by the full amplitude somewhere, and sit ON it at every junction.
			local worst, flat = 0, 0
			local footprint = Grid.footprint()
			for x = footprint.minX, footprint.maxX, 7 do
				local off = Forest.roadZ(x, layout) - layout.centre.Z
				worst = math.max(worst, math.abs(off))
				if math.abs(off) < 1e-9 then
					flat += 1
				end
			end
			expect(worst).to.be.near(45, 0.05)
			expect(flat > 0).to.equal(true)
			-- 5. AND THE JUNCTIONS ARE STILL EXACTLY ON THE STRAIGHT LINES, at the SHIPPED bend --
			-- not only at the parameter the bend case drives. This is what makes the grid a grid.
			local junctions, worstJunction = 0, 0
			for _, ew in ipairs(Grid.roads()) do
				if ew.axis == "x" then
					for _, ns in ipairs(Grid.roads()) do
						if
							ns.axis == "z"
							and ns.at >= ew.from
							and ns.at <= ew.to
							and ew.at >= ns.from
							and ew.at <= ns.to
						then
							junctions += 1
							worstJunction = math.max(
								worstJunction,
								math.abs(Grid.roadCentreAt(ew, ns.at) - ew.at),
								math.abs(Grid.roadCentreAt(ns, ew.at) - ns.at)
							)
						end
					end
				end
			end
			expect(junctions).to.equal(15)
			expect(worstJunction < 1e-12).to.equal(true)
			-- 6. THE PLAN AT THE SHIPPED BEND, pinned beside the straight count the case above pins.
			-- **TASK 337c: `BENT_C1` = own wood + a skirt across all four roads.** It was 2,522 from
			-- task 335, when the skirt was withdrawn from every planted neighbour and C1 planted
			-- `t2418 f104 s0`. The history of the OWN rectangle, which 337c does not touch: 328o
			-- 1,789, 328s 2,448, 328h 2,429 -- every one of them `t1861 f104` plus a skirt of 483 or
			-- 464. BOTH COUNTS ARE NOTED BEFORE EITHER IS ASSERTED, so a run that moves one tells you
			-- the other's value instead of stopping at the first `expect`.
			local drawn = Plan.plantCell("C1")
			local straightCount = #Plan.plantCell("C1", nil, STRAIGHT)
			TestKit.note(string.format("328h: C1 plan bent %d, straight %d", #drawn, straightCount))
			expect(#drawn).to.equal(BENT_C1)
			expect(straightCount).to.equal(STRAIGHT_C1)
			TestKit.note(
				string.format(
					"SHIPPED BENT %d/%d: flank set-back %d (was 340), C1 stand 1 (%.2f,%.2f) 8 (%.2f,%.2f) 10 (%.2f,%.2f), layout span %d / north %d, roadZ departs %.2f st from the centre and is exact at %d sampled stations, %d junctions to %.1e, C1 plan %d (straight 2538)",
					c.bend.ewStuds,
					c.bend.nsStuds,
					Grid.flankFirstStuds(),
					Grid.standPosition("C1", 1).X,
					Grid.standPosition("C1", 1).Z,
					Grid.standPosition("C1", 8).X,
					Grid.standPosition("C1", 8).Z,
					Grid.standPosition("C1", 10).X,
					Grid.standPosition("C1", 10).Z,
					layout.halfSpanStuds,
					layout.fieldNorthStuds,
					worst,
					flat,
					junctions,
					worstJunction,
					#drawn
				)
			)
		end)

		it("never reaches the four old places, whose roadZ is still their own sine", function()
			-- BOUNDARY 7 AGAIN, WITH THE NEW BRANCH IN IT (design 11.1 case 8): the cell branch is
			-- FIRST in `roadZ`, so a shipped row that grew `sides` would take it. None has one, and
			-- `forest_stand.spec`'s number-for-number assertions stand because of that.
			-- `LINE_PLACES` AND NOT `LAYOUT_ORDER` SINCE TASK 327d: the rotation deals cells now, and
			-- this case is about the four ARCHIVED rows (rule 7), which is where boundary 7 lives.
			for _, name in ipairs(Forest.LINE_PLACES) do
				local layout = Forest.layoutNamed(name) :: any
				expect(layout.sides).to.equal(nil)
				expect(Grid.cellOf(name)).to.equal(nil)
				for i = 0, 40 do
					local x = layout.centre.X - 1000 + i * 50
					local want = if layout.amplitudeStuds == 0
						then layout.centre.Z
						else layout.centre.Z + layout.amplitudeStuds * math.sin(
							(x - layout.centre.X) / Forest.SHAPE.wavelengthDivisor
						)
					expect(math.abs(Forest.roadZ(x, layout) - want) < 1e-9).to.equal(true)
				end
			end
			-- AND THE GRID'S WAVELENGTH IS NOT THEIRS: 2,224 studs against 70, which is the 32x
			-- defect F-3's assert in `Ground.chunkFor` now refuses.
			expect(2 * Grid.bendPitch("x") / Forest.SHAPE.wavelengthDivisor > 30).to.equal(true)
			-- REQUIRED HERE AND NOWHERE ELSE IN THIS FILE (the header says `Places.Ground` left it in
			-- 328e): this one assertion is defect F-3's refusal and it belongs with the wavelength.
			local Ground = require(ServerScriptService.Places:WaitForChild("Ground"))
			local cellLayout = Grid.layoutFor("C1")
			expect(pcall(Ground.chunkFor, cellLayout, { halfWidthStuds = 11 })).to.equal(false)
			expect(Ground.chunkFor(Forest.layoutNamed("road"), { halfWidthStuds = 11 }) > 0).to.equal(true)
			TestKit.note(
				string.format(
					"4 places untouched; grid half-wavelength %d studs against SHAPE's %d; chunkFor refuses a cell",
					Grid.bendPitch("x"),
					Forest.SHAPE.wavelengthDivisor
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
			-- `LINE_PLACES` SINCE TASK 327d, for the reason above: these are the archived rows.
			for _, name in ipairs(Forest.LINE_PLACES) do
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
					-- 1e-3 AND NOT 1e-9 ON THE POINT, and it is the float32 reason `forest_stand.spec`
					-- gives for the same comparison: `standX` answers a DOUBLE, but a `Vector3`
					-- stores float32, so at a road z of -2097 one ulp is 2.4e-4. MEASURED: this
					-- case failed at 1e-9 on `road` in the first gate run of this task.
					local at = Forest.standPosition(index, layout)
					expect(math.abs(at.X - x) < 1e-3).to.equal(true)
					expect(at.Y).to.equal(layout.centre.Y)
					expect(math.abs(at.Z - Forest.roadZ(x, layout)) < 1e-3).to.equal(true)
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
				-- THE THREE FIELDS THE BEND MOVES (task 328q, design 6.1), each read off `CONFIG`
				-- rather than typed, so 328r's commit moves them and no assertion here moves.
				expect(layout.amplitudeStuds).to.equal(c.bend.ewStuds)
				expect(layout.halfSpanStuds).to.equal(c.cellWidthStuds / 2 + c.bend.nsStuds)
				expect(layout.sides.main.count).to.equal(c.mainStandCount)
				expect(layout.sides.flanks.count).to.equal(c.flankStandCount)
				expect(layout.sides.flanks.firstStuds).to.equal(Grid.flankFirstStuds())
				expect(layout.beaterNorthStuds).to.equal(c.cellDepthStuds)
				expect(layout.fieldNorthStuds).to.equal(c.cellDepthStuds + c.roadClearStuds + c.bend.ewStuds)
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
				end
				-- **EVERY ONE OF THE FIFTEEN LIES ON ITS OWN ROAD'S WORLD CURVE** (task 328q, design
				-- 11.1 case 4), which is the assertion that replaces `at.Z == roads.main.at` and
				-- `at.X == roads.west.at`. Driven at BOTH amplitudes, because at 0 the curve is the
				-- straight line and the case would otherwise be the old one wearing a new name.
				for _, bend in ipairs({ STRAIGHT, BENT }) do
					for index = 1, Grid.standCount(id) do
						local sx, sz = worldStand(id, index, bend)
						local side = Grid.sideOf(id, index)
						if side == "main" then
							expect(math.abs(sz - Grid.roadCentreAt(roads.main, sx, bend)) < 1e-6).to.equal(true)
						else
							local road = if side == "west" then roads.west else roads.east
							expect(math.abs(sx - Grid.roadCentreAt(road, sz, bend)) < 1e-6).to.equal(true)
						end
					end
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
			-- the east flank's first post is laterally NEARER than the main line's end post...
			local mainEnd = Grid.standPosition(id, Grid.CONFIG.mainStandCount)
			local flankFirst = Grid.standPosition(id, Grid.CONFIG.mainStandCount + Grid.CONFIG.flankStandCount + 1)
			-- ...AND 200 STUDS NORTH OF THE MAIN ROAD, which is SOUTH of the flank post at +340 and
			-- NORTH of the road itself: the one band where the two answers disagree about whether
			-- this beater is through. MEASURED: the first run of this case put him at +700, north of
			-- BOTH posts, where neither answer is "crossed" and the case proved nothing.
			local beaterX = layout.centre.X + 510
			-- 200 STUDS NORTH OF THE ROAD'S OWN CURVE AT HIS x (task 328r), not of `road.at`: at
			-- 45/60 the two differ by up to 45 studs, and "north of the road" is the whole premise.
			-- Every `< 1e-6` below is `< 1e-3` for the same reason the B1 case gives: `Vector3`
			-- stores float32, and these are world coordinates near 5,000.
			local at = Vector3.new(beaterX, 0, Grid.roadCentreAt(roads.main, beaterX) + 200)
			expect(math.abs(flankFirst.X - beaterX) < math.abs(mainEnd.X - beaterX)).to.equal(true)
			-- THE DEFECT, SHOWN FIRST so this case cannot pass with the fix deleted: handed every
			-- post, the reference IS the flank post, up the cell.
			local wrong = Match.lineReferenceFor(at, line, fake(Grid.standCount(id)))
			-- IT IS A FLANK POST, AND WHICH ONE IS THE BEND'S BUSINESS (task 328r). At amplitude 0
			-- the laterally nearest of the fifteen was the east flank's FIRST (index 12); at 45/60
			-- the flank road bows 60 studs west and index 15 comes 2.41 studs closer than index
			-- 12's 3.27 (measured in DEV, 2026-11-03). The defect this case exists for is "a post
			-- up the cell instead of one on the line", and that is what the set-back below asserts
			-- -- naming index 12 was a detail of the straight world.
			local wrongIndex = 0
			for index = 1, Grid.standCount(id) do
				if (Grid.standPosition(id, index) - (wrong :: Vector3)).Magnitude < 1e-3 then
					wrongIndex = index
				end
			end
			expect(wrongIndex > Grid.CONFIG.mainStandCount).to.equal(true)
			expect(math.abs((wrong :: Vector3).X - beaterX) <= math.abs(flankFirst.X - beaterX) + 1e-3).to.equal(true)
			expect(
				(wrong :: Vector3).Z - Grid.roadCentreAt(roads.main, (wrong :: Vector3).X)
					>= Grid.flankFirstStuds() - 1e-3
			).to.equal(true)
			-- ...AND HANDED THE MAIN LINE'S POSTS IT IS THE MAIN POST, ON THE ROAD.
			local right = Match.lineReferenceFor(at, line, fake(Grid.CONFIG.mainStandCount))
			expect(math.abs((right :: Vector3).Z - Grid.roadCentreAt(roads.main, (right :: Vector3).X)) < 1e-3).to.equal(
				true
			)
			expect(math.abs((right :: Vector3).X - mainEnd.X) < 1e-3).to.equal(true)
			-- AND THE DRIVE IS NOT OVER: a beater 200 studs north of the road has not crossed it,
			-- where against the flank post he had.
			expect(Match.crossedLine(at, line, fake(Grid.CONFIG.mainStandCount), 0)).to.equal(false)
			expect(Match.crossedLine(at, line, fake(Grid.standCount(id)), 0)).to.equal(true)
			TestKit.note(
				string.format(
					"beater at x %+.0f, z %+.0f of the road: main post %.0f studs laterally, flank post %.0f -- the flank wins by %.0f, and its z is %+.0f, so every post calls him THROUGH and the line's posts do not",
					beaterX - layout.centre.X,
					at.Z - roads.main.at,
					math.abs(mainEnd.X - beaterX),
					math.abs(flankFirst.X - beaterX),
					math.abs(mainEnd.X - beaterX) - math.abs(flankFirst.X - beaterX),
					flankFirst.Z - roads.main.at
				)
			)
		end)

		it("is answered off the REAL marker set, at the two call sites that read its middle", function()
			-- ROUND 1 FINDING 1: the case above drives `lineReferenceFor` with hand-built lists, so
			-- it passes unchanged with `Match`'s `linePostsOf` reverted to `markers.posts`. This one
			-- builds a real `Markers.Set` for a cell and drives two of the five call sites, so it
			-- FLIPS the moment that revert happens.
			local id = "A1"
			local layout = Grid.layoutFor(id)
			local roads = Grid.roadsOf(id)
			local set = Markers.build(Forest.standX(4, layout), layout, flatGround, flatGround)
			expect(#set.posts).to.equal(15)
			expect(#set.linePosts).to.equal(Grid.CONFIG.mainStandCount)
			-- WHAT THE DEFECT WOULD ANSWER: `posts[ceil(15 / 2)]` is index 8, the west flank's first
			-- stand, `flankFirstStuds` up the cell and a flank road's width off the line.
			local wrongMiddle = set.posts[math.ceil(#set.posts / 2)]
			expect(
				math.abs(
					wrongMiddle.Position.Z
						- (Grid.roadCentreAt(roads.main, wrongMiddle.Position.X) + Grid.flankFirstStuds())
				) < 1e-3
			).to.equal(true)
			-- WHERE THE DEAD ANIMALS ARE LAID OUT (`Match.gatherSpotFor`): behind the middle of the
			-- LINE, on the road, not 340 studs up a flank.
			local behind = Match.CONFIG.SCENE.GATHER_BEHIND_STUDS
			local gather, normal = Match.gatherSpotFor(set, Match.CONFIG)
			expect(gather).to.be.ok()
			expect(math.abs((normal :: Vector3).Z - 1) < 1e-6).to.equal(true)
			-- IT IS BEHIND THE MIDDLE **LINE** POST, and that post is on the road's curve at its own
			-- x (task 328r). `layout.centre.X` is the GRID centre; at 45/60 the middle post's world
			-- x is up to `maxBendStuds` from it, so both are asserted and neither stands in for the
			-- other.
			local middleLine = set.linePosts[math.ceil(#set.linePosts / 2)]
			expect(math.abs((gather :: Vector3).Z - (middleLine.Position.Z - behind)) < 1e-3).to.equal(true)
			expect(math.abs((gather :: Vector3).X - middleLine.Position.X) < 1e-3).to.equal(true)
			expect(math.abs(middleLine.Position.Z - Grid.roadCentreAt(roads.main, middleLine.Position.X)) < 1e-3).to.equal(
				true
			)
			expect(math.abs((gather :: Vector3).X - layout.centre.X) <= Grid.maxBendStuds()).to.equal(true)
			-- ...and it is NOT the flank answer, said as its own assertion so the number that would
			-- have been wrong is named rather than implied.
			expect(math.abs((gather :: Vector3).Z - (wrongMiddle.Position.Z - behind)) > 1).to.equal(true)
			-- WHERE A BEATER WHO IS THROUGH WAITS (`Match.throughSpotFor`), the fifth call site and
			-- the same shape.
			local through = Match.throughSpotFor(set, Match.CONFIG, 0)
			expect(through).to.be.ok()
			local throughBehind = Match.CONFIG.BEATER_THROUGH.BEHIND_STUDS
			-- BEHIND THE SAME MIDDLE LINE POST, on the road's curve at its own x (task 328r).
			expect(math.abs((through :: CFrame).Position.Z - (middleLine.Position.Z - throughBehind)) < 1e-3).to.equal(
				true
			)
			expect(math.abs((through :: CFrame).Position.X - middleLine.Position.X) < 1e-3).to.equal(true)
			expect(math.abs((through :: CFrame).Position.X - layout.centre.X) <= Grid.maxBendStuds()).to.equal(true)
			-- AND ON A SHIPPED LAYOUT NOTHING MOVED: `linePosts` IS `posts` there, so the middle of
			-- the road's nine is the road's stand 5 exactly as before this task.
			local road = Forest.layoutNamed("road") :: any
			local roadSet = Markers.build(Forest.standX(5, road), road, flatGround, flatGround)
			expect(#roadSet.linePosts).to.equal(#roadSet.posts)
			local roadGather = Match.gatherSpotFor(roadSet, Match.CONFIG)
			local roadMiddle = roadSet.posts[math.ceil(#roadSet.posts / 2)]
			expect(math.abs((roadGather :: Vector3).X - roadMiddle.Position.X) < 1e-6).to.equal(true)
			Markers.clear()
			TestKit.note(
				string.format(
					"cell %s: gather at z %+.0f of the road (the flank middle would have been %+.0f); through at %+.0f",
					id,
					(gather :: Vector3).Z - roads.main.at,
					wrongMiddle.Position.Z - behind - roads.main.at,
					(through :: CFrame).Position.Z - roads.main.at
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
			-- THE SPAN IS THE TWO END STANDS' OWN WORLD x, and the bend moves them (task 328r):
			-- their GRID x is still `centre.X +- half` exactly, and the world x is within
			-- `maxBendStuds` of it. Both are asserted, so neither the rule nor its size is lost.
			expect(span.minX).to.equal(Grid.standPosition(id, 1).X)
			expect(span.maxX).to.equal(Grid.standPosition(id, c.mainStandCount).X)
			local minU = select(1, Grid.toGrid(span.minX, Grid.standPosition(id, 1).Z))
			local maxU = select(1, Grid.toGrid(span.maxX, Grid.standPosition(id, c.mainStandCount).Z))
			expect(math.abs(minU - (layout.centre.X - half)) < 1e-3).to.equal(true)
			expect(math.abs(maxU - (layout.centre.X + half)) < 1e-3).to.equal(true)
			expect(math.abs(span.minX - (layout.centre.X - half)) <= Grid.maxBendStuds()).to.equal(true)
			expect(math.abs(span.maxX - (layout.centre.X + half)) <= Grid.maxBendStuds()).to.equal(true)
			local west = Grid.standPosition(id, c.mainStandCount + 1)
			local east = Grid.standPosition(id, c.mainStandCount + c.flankStandCount + 1)
			expect(west.X < span.minX).to.equal(true)
			expect(east.X > span.maxX).to.equal(true)
			-- AND THE CORRIDOR IS THE CELL AND NOT THE FLANK ROADS.
			local corridor = Forest.corridorOf(layout)
			expect(corridor.minX).to.equal(span.minX)
			expect(corridor.maxX).to.equal(span.maxX)
			expect(corridor.maxZ).to.equal(layout.centre.Z + c.cellDepthStuds)
			TestKit.note(
				string.format(
					"main span %.0f..%.0f (%.0f wide); west flank at %.0f, east at %.0f",
					span.minX,
					span.maxX,
					span.maxX - span.minX,
					west.X,
					east.X
				)
			)
		end)

		it("is clamped by ForestTest.hunterStandX itself, on a locked flank pick", function()
			-- ROUND 1 FINDING 2: the case above did the clamp with `math.clamp` of its own, so it
			-- survived deleting `onLine` from `hunterStandX`. This one promotes the cell and locks a
			-- pick, which is the live path (`forest_stand.spec`'s own shape), and FAILS without the
			-- clamp -- a west-flank pick would answer `centre.X - 556`.
			local id = "A1"
			local userId = -3270
			ForestTest.layoutForDrive(3271, id)
			expect(ForestTest.layoutName()).to.equal(id)
			local layout = ForestTest.layout()
			local span = Forest.standSpan(layout)
			local c = Grid.CONFIG
			local function aimAt(standIndex: number): number
				ForestTest.clearPick(userId)
				ForestTest.openPick(userId, 0, standIndex)
				ForestTest.lockPick(userId, Grid.standPosition(id, standIndex), 0, standIndex)
				expect(ForestTest.standIndexOf(userId)).to.equal(standIndex)
				return ForestTest.hunterStandX()
			end
			-- A WEST-FLANK HUNTER PINS THE WAVES TO THE WEST END OF THE LINE, not to his own x 556
			-- studs out, which is outside the ground the waves have.
			local westIndex = c.mainStandCount + 1
			expect(Grid.standPosition(id, westIndex).X < span.minX).to.equal(true)
			expect(aimAt(westIndex)).to.be.near(span.minX, 1e-6)
			-- ...AND AN EAST-FLANK HUNTER TO THE EAST END.
			local eastIndex = c.mainStandCount + c.flankStandCount + 1
			expect(Grid.standPosition(id, eastIndex).X > span.maxX).to.equal(true)
			expect(aimAt(eastIndex)).to.be.near(span.maxX, 1e-6)
			-- A MAIN STAND IS NOT MOVED BY THE CLAMP, every one of the seven.
			for index = 1, c.mainStandCount do
				expect(aimAt(index)).to.be.near(Grid.standPosition(id, index).X, 1e-6)
			end
			ForestTest.clearPick(userId)
			-- Put the world back where the rest of the suite expects it.
			ForestTest.layoutForDrive(3272, Forest.DEFAULT_LAYOUT)
			expect(ForestTest.layoutName()).to.equal(Forest.DEFAULT_LAYOUT)
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

		it("deals the first hunter of a cell the MAIN stand hunterStandX aims at", function()
			-- ROUND 2'S FINDING. With the cell live, the deal was still the ROAD's arithmetic
			-- (`standIndexFor`'s `floor(15/2) + 1` = stand 8, a west flank post 556 studs off
			-- centre) while `hunterStandX` aimed every wave at stand 5. This drives the LIVE path:
			-- the promoted cell, `ForestTest.standWalk()` as `ForestTestBoot`'s `placement` passes
			-- it, and `hunterStandX()` with nobody having picked.
			local id = Grid.DEFAULT_CELL
			ForestTest.layoutForDrive(3273, id)
			expect(ForestTest.layoutName()).to.equal(id)
			local layout = ForestTest.layout()
			expect(layout.sides).never.to.equal(nil)
			-- THE WALK IS THE GRID'S, by call and value for value.
			local walk = ForestTest.standWalk()
			local grid = Grid.standWalk(id)
			expect(#walk).to.equal(#grid)
			for index, value in ipairs(grid) do
				expect(walk[index]).to.equal(value)
			end
			-- THE DEAL, EXACTLY AS THE BOOT MAKES IT for a one-hunter line, both ways round: with
			-- nobody answering the entitlement (today's world) and with the one hunter UNENTITLED
			-- (every seated stand barred), because C1's three seats are flank posts.
			local seated = ForestTest.seatedStands()
			for _, deal in ipairs({
				HighSeats.dealLine(walk, seated, nil, 1, nil),
				HighSeats.dealLine(walk, seated, { false }, 1, nil),
			}) do
				local stand = deal[1]
				expect(stand).to.equal(ForestTest.standIndexFor(1))
				expect(Grid.sideOf(id, stand)).to.equal("main")
				-- AND IT IS THE STAND THE WAVES ARE AIMED AT. `hunterStandX` with no pick is
				-- `defaultPickIndex`, which is the walk's first stand.
				expect(ForestTest.hunterStandX()).to.be.near(Forest.standX(stand, layout), 1e-6)
				expect(ForestTest.defaultPickIndex()).to.equal(ForestTest.standIndexFor(1))
			end
			TestKit.note(
				string.format(
					"%s: walk[1] = stand %d (%s) at x %.0f; hunterStandX %.0f; the road still deals %d",
					id,
					walk[1],
					Grid.sideOf(id, walk[1]),
					Forest.standX(walk[1], layout),
					ForestTest.hunterStandX(),
					math.floor(#walk / 2) + 1
				)
			)
			-- Put the world back where the rest of the suite expects it.
			ForestTest.layoutForDrive(3274, Forest.DEFAULT_LAYOUT)
			expect(ForestTest.layoutName()).to.equal(Forest.DEFAULT_LAYOUT)
			-- THE ROAD'S OWN BRANCH IS UNMOVED (L-093): `forest_stand.spec` pins the centre-out
			-- permutation, and the default stand is still 5 here.
			expect(ForestTest.standIndexFor(1)).to.equal(Forest.PICK.defaultIndex)
			expect(ForestTest.defaultPickIndex()).to.equal(Forest.PICK.defaultIndex)
		end)
	end)

	-- ---------------------------------------------------------------- 19. ARCHIVED (task 328e)

	-- CASE 19 WAS `Ground.paintRoads` THROUGH AN INJECTED TERRAIN, and it is archived WITH that
	-- function, in this commit (design 16: *a case asserting an archived function is a false-PASS
	-- path*). The grid's roads get their material from `ServerStorage.TerrainBake`, in the same
	-- `WriteVoxels` call that cuts their shape; `grid_relief.spec`'s 328d-15, 328d-16 and 328e-2 are
	-- what assert it. Rollback:
	-- `backups/2026-11-02_task-328e_Ground-paintRoads-and-grid-case-19.md`.

	-- ---------------------------------------------------------------- 22. the preview tags nothing

	describe("the switch", function()
		-- A FAKE WORLD WITH A TEMPLATE SOURCE IN IT, because `build` returns `"no-templates"` before
		-- it reaches either loop -- so without one neither case below could see what the loops did.
		-- One Model per species name, under the first name in `Places.TEMPLATE_SOURCES`.
		local function worldWithTemplates(): Instance
			local world = Instance.new("Folder")
			local source = Instance.new("Folder")
			source.Name = Planter.TEMPLATE_SOURCES[1]
			source.Parent = world
			for _, names in pairs(Plan.SPECIES) do
				for _, name in ipairs(names) do
					local model = Instance.new("Model")
					model.Name = name
					local trunk = Instance.new("Part")
					trunk.Name = "Trunk"
					trunk.Size = Vector3.new(4, 40, 4)
					trunk.Position = Vector3.new(0, 20, 0)
					trunk.Anchored = true
					trunk.Parent = model
					model.PrimaryPart = trunk
					model.Parent = source
				end
			end
			return world
		end

		-- CASE 21 (design 13.1): **BOTH WORLDS' FOLDERS ARE DESTROYED, WHICHEVER WORLD IS LIVE**
		-- (design 11.3 step 2). `GRID_PREVIEW` is retired at task 327d, so there is no boolean left
		-- to drive -- and that is the stronger claim: a build cannot leave the other world standing.
		it("case 21: destroys BOTH folders and stands no part of its own", function()
			local world = worldWithTemplates()
			local reader = function(_x: number, _z: number)
				return 120
			end
			local terrain = {
				ReplaceMaterial = function() end,
			}
			-- A STALE WORLD, both folders with a child in each -- the state a second boot finds.
			local staleDrive = Instance.new("Folder")
			staleDrive.Name = Planter.FOLDER
			local staleRoad = Instance.new("Folder")
			staleRoad.Name = "road"
			staleRoad.Parent = staleDrive
			staleDrive.Parent = world
			local staleGrid = Instance.new("Folder")
			staleGrid.Name = Planter.GRID_FOLDER
			local staleCell = Instance.new("Folder")
			staleCell.Name = "C1"
			staleCell.Parent = staleGrid
			staleGrid.Parent = world

			local report = Planter.build(reader, world, terrain)

			-- BOTH OLD FOLDERS ARE GONE, by identity and not by name: a rebuild that re-parented the
			-- old instance would pass a name check.
			expect(staleDrive.Parent).to.equal(nil)
			expect(staleGrid.Parent).to.equal(nil)
			local folder = world:FindFirstChild(Planter.GRID_FOLDER)
			expect(folder ~= nil).to.equal(true)
			expect(folder).never.to.equal(staleGrid)
			-- THE 32 CORNER STAKES ARE GONE (task 328m; Karen, 2026-11-03: *"those gates shouldnt
			-- be"*). The folder is the cell wood's parent and nothing else, so a BUILD puts NO part
			-- in it -- and the fields that counted the stakes are gone with them.
			local ownParts = #(folder :: Instance):GetChildren()
			expect(ownParts).to.equal(0)
			expect((report :: any).gridStakes).to.equal(nil)
			expect((report :: any).gridMissing).to.equal(nil)
			expect((report :: any).gridPaints).to.equal(nil)
			-- IT TAGS NOTHING, BUILDS NO STAND AND NO SEAT: the drive's own `markers` closure owns
			-- those, and since task 327d it is the only builder of them.
			expect(world:FindFirstChild("ForestMarkers")).to.equal(nil)
			expect(world:FindFirstChild("HighSeats")).to.equal(nil)
			-- THE FOLDER NAME IS ONE FACT with the ground-ignore list, so nothing a cell's wood is
			-- parented to can ever answer "where is the ground".
			expect(table.find(Forest.GROUND_IGNORE, Planter.GRID_FOLDER) ~= nil).to.equal(true)
			-- A SECOND BUILD REBUILDS RATHER THAN DOUBLING.
			local again = world:FindFirstChild(Planter.GRID_FOLDER)
			Planter.build(reader, world, terrain)
			expect((again :: Instance).Parent).to.equal(nil)
			expect(world:FindFirstChild(Planter.GRID_FOLDER)).never.to.equal(again)
			-- ONE OF EACH FOLDER AND NO MORE, beside the template source the fixture put in.
			local children: { [string]: number } = {}
			for _, child in ipairs(world:GetChildren()) do
				children[child.Name] = (children[child.Name] or 0) + 1
			end
			expect(children[Planter.FOLDER]).to.equal(1)
			expect(children[Planter.GRID_FOLDER]).to.equal(1)
			expect(children[Planter.TEMPLATE_SOURCES[1]]).to.equal(1)
			expect(#world:GetChildren()).to.equal(3)
			world:Destroy()
			TestKit.note(
				string.format(
					"case 21: both stale folders destroyed, grid folder rebuilt with %d part(s) of its own",
					ownParts
				)
			)
		end)

		-- **THE CASE THAT DIES IF THE ROTATION IS PUT BACK (lesson L-093).** Delete the producer --
		-- `ForestTest.LAYOUT_ORDER = Grid.PLANTED_CELLS` back to
		-- `table.freeze({ "road", "edge", "ride", "track" })` -- and every assertion below reddens.
		it("deals ONLY the planted cells, never a line place and never A1", function()
			local order = Forest.LAYOUT_ORDER
			-- IT IS THE PLANTED LIST ITSELF, not a copy of it: the cells with a wood and the cells
			-- the rotation deals cannot drift apart.
			expect(order).to.equal(Grid.PLANTED_CELLS)
			expect(#order).to.equal(7)
			for _, name in ipairs(order) do
				-- EVERY NAME IS A CELL, AND NO NAME IS A LINE PLACE.
				expect(Grid.cellOf(name)).to.be.ok()
				expect(Forest.layoutNamed(name)).to.equal(nil)
				expect(table.find(Forest.LINE_PLACES, name)).to.equal(nil)
				expect(name).never.to.equal("A1")
				-- ...AND IT RESOLVES TO A CELL LAYOUT, so a dealt name is never a drive with no ground.
				local layout = Forest.layoutOf(name) :: any
				expect(layout.name).to.equal(name)
				expect(layout.cellOf).to.be.ok()
			end
			-- A1 IS THE ONE CELL WITH NO BAKED GROUND, so it is in neither list.
			expect(Grid.cellOf("A1")).to.be.ok()
			expect(table.find(order, "A1")).to.equal(nil)
			-- THE ROTATION CANNOT REACH A LINE PLACE: four full cycles and not one of the four.
			local previous = nil
			for _ = 1, 4 * #order do
				previous = Forest.nextLayout(previous)
				expect(Grid.cellOf(previous)).to.be.ok()
			end
			-- ...AND `Places.build` THEREFORE DRESSES NO LINE PLACE (cell-loading.md 13 D1): the loop
			-- is guarded by `layoutNamed`, which is nil for every cell, so 9,105 parts are not built.
			-- MEASURED HERE AND NOT READ: the report's own counters.
			local world = worldWithTemplates()
			local report = Planter.build(function()
				return 120
			end, world, { ReplaceMaterial = function() end }, nil, {})
			expect(report.reason).to.equal(nil)
			expect(report.places).to.equal(0)
			expect(report.parts).to.equal(0)
			expect(report.paints).to.equal(0)
			local drivePlaces = world:FindFirstChild(Planter.FOLDER)
			expect(drivePlaces).to.be.ok()
			expect(#(drivePlaces :: Instance):GetChildren()).to.equal(0)
			world:Destroy()
			-- ...AND THE FALLBACK IS NOW UNREACHABLE FROM THE ROTATION, which is the line
			-- `reviews/task-337` wrote its tripwire for: `wantedCell` answered `DEFAULT_CELL` because
			-- the rotation dealt line places. It no longer can.
			local Cells = require(ServerScriptService.Places:WaitForChild("Cells"))
			expect(Cells.wantedCell(Forest.LAYOUT_ORDER[1])).to.equal(Forest.LAYOUT_ORDER[1])
			TestKit.note(string.format("the rotation: %s", table.concat(order, " -> ")))
		end)
	end)

	-- ================================================================ task 327c: the cell's wood
	--
	-- EVERY CASE BELOW IS PURE OR DRIVEN THROUGH A FAKE. `Places.plantCell` is arithmetic over
	-- `Grid`'s data, and the one case that puts an Instance anywhere builds its own fake templates on
	-- its own fake hillside in its own Folder.

	-- THE EIGHT PLANTING LISTS, COMPUTED ONCE. Seven cases read them and each list is ~2,400 items;
	-- `plantCell` is a pure function of the id, so computing it once is the same answer as computing
	-- it seven times (case 13 is what proves that, and it computes its own).
	local Slice = require(ServerScriptService.Places:WaitForChild("Slice"))
	local woods: { [string]: any } = {}
	for _, id in ipairs(Grid.cellIds()) do
		woods[id] = Plan.plantCell(id)
	end

	-- ---------------------------------------------------------------- 12. the recipes and the zones

	describe("the eight recipes", function()
		it("name species that exist and tile the cell in zones that never overlap", function()
			local seenRecipes: { [string]: string } = {}
			local lines = {}
			for _, id in ipairs(Grid.cellIds()) do
				local cell = Grid.cellOf(id)
				local plan = Plan.cellPlanFor(id)
				-- EVERY CELL HAS A RECIPE AND EVERY RECIPE IS ITS OWN, so no two cells are dressed
				-- the same -- which is the whole of Karen's *"different trees growing in different
				-- section"*.
				expect(type(cell.recipe)).to.equal("string")
				expect(plan ~= nil).to.equal(true)
				expect(seenRecipes[cell.recipe]).to.equal(nil)
				seenRecipes[cell.recipe] = id
				-- `halfStripStuds` IS ONE FACT WITH THE ROAD, not a second number.
				expect(Plan.laneHalfWidth(plan) * 2).to.equal(Grid.CONFIG.roadClearStuds)
				local clear, covered = 0, 0
				for index, zone in ipairs(plan.zones) do
					local at = zone.at
					expect(#at).to.equal(4)
					-- INSIDE [0,1]^2 AND NON-EMPTY.
					for _, value in ipairs(at) do
						expect(value >= 0 and value <= 1).to.equal(true)
					end
					expect(at[3] > at[1]).to.equal(true)
					expect(at[4] > at[2]).to.equal(true)
					covered += (at[3] - at[1]) * (at[4] - at[2])
					local rows = Plan.cellMixNamed(zone.mix)
					-- THE MIX EXISTS, AND EVERY GROUP IN IT IS A KEY OF `Places.SPECIES` with at
					-- least one model name in it. A name this world does not have plants nothing,
					-- silently, which is exactly the class of defect this case is for.
					expect(rows ~= nil).to.equal(true)
					for _, row in ipairs(rows) do
						local names = (Plan.SPECIES :: any)[row.group]
						expect(names ~= nil).to.equal(true)
						expect(#names > 0).to.equal(true)
						expect(row.weight > 0).to.equal(true)
					end
					-- A CLEARING IS AN EMPTY MIX AND SPACING 0, BOTH WAYS -- so "no trees here"
					-- cannot be said in one of the two places and forgotten in the other.
					expect(#rows == 0).to.equal(zone.spacingStuds == 0)
					if zone.spacingStuds == 0 then
						clear += (at[3] - at[1]) * (at[4] - at[2])
					else
						expect(zone.spacingStuds > 0).to.equal(true)
						expect(zone.band == "wood" or zone.band == "shrub").to.equal(true)
					end
					-- NO TWO ZONES OF ONE CELL OVERLAP.
					for other = index + 1, #plan.zones do
						local b = plan.zones[other].at
						local hit = at[1] < b[3] and b[1] < at[3] and at[2] < b[4] and b[2] < at[4]
						expect(hit).to.equal(false)
					end
				end
				-- THE ZONES TILE THE CELL EXACTLY. Not asked by the design, asserted here because a
				-- gap is a bald patch nobody declared: a clearing is a ZONE with spacing 0, so an
				-- uncovered rectangle can only ever be an arithmetic slip in a recipe.
				expect(math.abs(covered - 1) < 1e-9).to.equal(true)
				-- NO CELL IS MORE THAN A THIRD CLEAR, and **A1 IS THE ONLY CELL WITH A CLEARING LEFT**
				-- (task 336, after 335 took C1's). Karen, 2026-11-08: *"all has to be forest no free
				-- spot excep road"* for C1, and *"can you make now all grounds with different
				-- trees"* for the rest -- so every cell that is PLANTED is planted wall to wall and
				-- its cut is gone. A1 is not planted and keeps its own.
				-- The pair BITES BOTH WAYS: a planted cell gaining a clearing back fails here, and
				-- A1 losing its own fails too.
				expect(clear < 0.34).to.equal(true)
				expect(clear > 0).to.equal(id == "A1")
				table.insert(
					lines,
					string.format("%s=%s(%d zones, %.0f%% clear)", id, cell.recipe, #plan.zones, clear * 100)
				)
			end
			TestKit.note("recipes: " .. table.concat(lines, " "))
		end)
	end)

	-- ---------------------------------------------------------------- 12a. the understorey (task 328m)

	describe("the understorey", function()
		it("is a second storey of young growth, inside the budget, that moves no canopy stem", function()
			-- KAREN, 2026-11-03, HAVING PLAYED C1: *"has to be a bit more realistic more trees"*.
			-- A zone's optional `under` row plants a second, finer layer over the SAME rectangle.
			local withUnder = {}
			for _, id in ipairs(Grid.cellIds()) do
				local plan = Plan.cellPlanFor(id)
				for _, zone in ipairs(plan.zones) do
					local under = zone.under
					if under ~= nil then
						table.insert(withUnder, id)
						-- A ROW THAT PLANTS NOTHING IS A ROW NOBODY MEANT: spacing above 0, a mix
						-- that exists and is not empty, and NOT on a clearing.
						expect(under.spacingStuds > 0).to.equal(true)
						expect(zone.spacingStuds > 0).to.equal(true)
						local rows = Plan.cellMixNamed(under.mix)
						expect(rows ~= nil).to.equal(true)
						expect(#rows > 0).to.equal(true)
						-- IT IS YOUNG GROWTH AND NOT A SECOND CANOPY, and since task 336 that is the
						-- SCALE's job and not the species': the storey is planted at the `shrub`
						-- band (0.25-0.45 of the template, floored at `scaleFloor`) while the canopy
						-- takes `woodScale` 0.8-1.2, so the same species is a sapling underneath and
						-- a tree above. What is asserted instead is that it is THIS CELL'S OWN
						-- species -- Karen's *"all grounds with different trees"* reaches the second
						-- storey too, so a recipe cannot put larch under a spruce cell.
						expect(zone.band == "wood" or zone.band == "shrub").to.equal(true)
						local own: { [string]: boolean } = {}
						for _, other in ipairs(plan.zones) do
							for _, row in ipairs(Plan.cellMixNamed(other.mix) or {}) do
								own[row.group] = true
							end
						end
						for _, row in ipairs(rows) do
							expect(own[row.group]).to.equal(true)
						end
					end
				end
			end
			-- EXACTLY THE PLANTED CELLS HAVE ONE (task 328i): C1's second storey was 328m's, and
			-- 328i gave the same row to the four cells behind and beside it, because it is half of
			-- what carries C1's accepted density. The three UNBAKED cells have none -- the task
			-- that bakes their ground is the one that plants them.
			expect(#withUnder > 0).to.equal(true)
			local planted: { [string]: boolean } = {}
			for _, id in ipairs(Grid.PLANTED_CELLS) do
				planted[id] = true
			end
			-- `withUnder` IS ONE ENTRY PER ZONE, so the count is compared over DISTINCT CELLS:
			-- every planted cell has at least one storeyed zone, and no other cell has any.
			local seenUnder: { [string]: boolean } = {}
			local distinct = 0
			for _, id in ipairs(withUnder) do
				expect(planted[id]).to.equal(true)
				if not seenUnder[id] then
					seenUnder[id] = true
					distinct += 1
				end
			end
			expect(distinct).to.equal(#Grid.PLANTED_CELLS)

			-- IT IS COUNTED IN THE BOUND. `cellCapacity` must be the sum of all four layers, so an
			-- understorey the budget did not count cannot breach `CELL_PLAN_CAP` unseen.
			local plan = Plan.cellPlanFor("C1")
			local function cells(rect: any, spacing: number): number
				if spacing <= 0 then
					return 0
				end
				return (math.floor((rect.maxX - rect.minX) / spacing) + 1)
					* (math.floor((rect.maxZ - rect.minZ) / spacing) + 1)
			end
			local zones, under = 0, 0
			for _, zone in ipairs(plan.zones) do
				local rect = Plan.zoneRect("C1", zone)
				zones += cells(rect, zone.spacingStuds)
				if zone.under ~= nil then
					under += cells(rect, zone.under.spacingStuds)
				end
			end
			local ferns = 0
			for _, rect in ipairs(Plan.fernBands("C1", plan)) do
				ferns += cells(rect, plan.fernSpacing)
			end
			-- THE SKIRT TERM IS COUNTED ON ALL FOUR SIDES (task 337c), the grid's outer edge
			-- included: `skirtSides` answers four entries for every cell, one of C1's with `id`
			-- nil, and each contributes bands to the bound. A skirt term that silently fell back to
			-- zero would be caught by the `> 0` below, which it was not before 337c.
			local skirt, bands, outer = 0, 0, 0
			for _, side in ipairs(Plan.skirtSides("C1")) do
				if side.id == nil then
					outer += 1
				end
				for _, band in ipairs(Plan.skirtBands("C1", side.id, side.axis, plan, side.sign)) do
					bands += 1
					skirt += cells(band.rect, band.spacing)
				end
			end
			expect(#Plan.skirtSides("C1")).to.equal(4)
			expect(outer).to.equal(1)
			-- 12 SINCE TASK 346: four sides, three bands a side -- the near band, the deep band and
			-- the deepest one, which on an outer edge also runs `SKIRT_WIDEN_STUDS` past both ends.
			expect(bands).to.equal(12)
			expect(skirt > 0).to.equal(true)
			expect(under > 0).to.equal(true)
			expect(Plan.cellCapacity("C1")).to.equal(zones + under + ferns + skirt)

			-- IT ACTUALLY PLANTS, AT THE `shrub` BAND'S SCALE. Not "and from no other group": the
			-- mix check above is where the groups are asserted, because `scatter` puts every
			-- non-herb site within `frontage.studs` 60 of a road through `frontageGroupFor`, so a
			-- `fieldOak` at 0.4 is a legal understorey stem (design 7.2).
			local saplings, worstScale = 0, 0
			for _, item in ipairs(woods.C1) do
				if item.band == "shrub" and item.side == 1 then
					saplings += 1
					worstScale = math.max(worstScale, item.scale)
					expect(item.scale >= plan.scaleFloor).to.equal(true)
					expect(item.scale <= plan.shrubScale[2]).to.equal(true)
				end
			end
			-- MORE THAN THE TWO SCRUB ZONES ALONE COULD GIVE: those two hold 381 sites between them
			-- (`driven-hunt-runs/328m-yield-v1.txt`), so a count above that can only be the second
			-- storey, and this case reddens the moment the `under` loop in `plantCell` is removed.
			expect(saplings > 381).to.equal(true)

			-- ...AND IT MOVES NO CANOPY STEM, which is true BY CONSTRUCTION and only half asserted
			-- here, said so nobody reads more into the case than it carries: the `under` loop runs
			-- AFTER every zone on its own `Random`, so the only state it shares with the canopy is
			-- the `trees` bucket grid -- which from there can refuse a SKIRT site and nothing else.
			-- What this asserts is the half that could rot: four distinct stream ids (design 4.6).
			local streams = {}
			for name, value in pairs(Plan.CELL_STREAM) do
				expect(streams[value]).to.equal(nil)
				streams[value] = name
			end
			expect(type(Plan.CELL_STREAM.under)).to.equal("number")

			-- AND THE GAP RULE HAS NO SEAM IN IT. The understorey shares the canopy's neighbour grid
			-- AND its `minGapStuds`, which is both what makes it clump into the gaps between trunks
			-- and what stops a sapling standing inside one. `tooClose` buckets by the gap it is
			-- handed, so a second gap on that grid would silently stop being a rule: this case fails
			-- the moment the understorey is given a grid or a gap of its own.
			local trees = {}
			for _, item in ipairs(woods.C1) do
				if item.band ~= "herb" then
					table.insert(trees, item)
				end
			end
			-- THE GAP RULE LIVES IN GRID SPACE (task 328r): `tooClose` buckets the planner's own grid
			-- points, so that is where `minGapStuds` is exact. The WORLD gap is measured too and
			-- bounded by the shear, because that is the distance Karen walks between two trunks.
			local worst, worstWorld, buckets = math.huge, math.huge, {}
			for _, item in ipairs(trees) do
				local gx, gz = Grid.toGrid(item.x, item.z)
				local cx, cz = math.floor(gx / plan.minGapStuds), math.floor(gz / plan.minGapStuds)
				for dx = -1, 1 do
					for dz = -1, 1 do
						for _, other in ipairs(buckets[(cx + dx) .. ":" .. (cz + dz)] or {}) do
							local ddx, ddz = other.gx - gx, other.gz - gz
							worst = math.min(worst, math.sqrt(ddx * ddx + ddz * ddz))
							local wdx, wdz = other.x - item.x, other.z - item.z
							worstWorld = math.min(worstWorld, math.sqrt(wdx * wdx + wdz * wdz))
						end
					end
				end
				local key = cx .. ":" .. cz
				buckets[key] = buckets[key] or {}
				table.insert(buckets[key], { x = item.x, z = item.z, gx = gx, gz = gz })
			end
			expect(worst >= plan.minGapStuds).to.equal(true)
			-- THE WORLD GAP IS THE GRID GAP THROUGH THE SHEAR, and what bounds it is the SMALLER
			-- SINGULAR VALUE of `[[1, bendX'], [bendZ', 1]]` -- not `|J - 1|`, which is the
			-- determinant's distance from 1 and says nothing about the worst direction. At the peak
			-- slopes (0.1281 and 0.1271) that is 0.8724, so a 12-stud grid gap can read 10.47 in
			-- the world. Derived from the same two slopes `bendFacts` is the angle of, and exactly
			-- 1 at amplitude 0.
			local ax = Grid.bendFacts("z").amplitudeStuds * math.pi * Grid.CONFIG.bend.harmonic / Grid.bendPitch("z")
			local az = Grid.bendFacts("x").amplitudeStuds * math.pi * Grid.CONFIG.bend.harmonic / Grid.bendPitch("x")
			local trace, cross = 2 + ax * ax + az * az, ax + az
			local root = math.sqrt(math.max(0, (az * az - ax * ax) ^ 2 + 4 * cross * cross))
			local shrink = math.sqrt(math.max(0, (trace - root) / 2))
			expect(worstWorld >= plan.minGapStuds * shrink - 1e-9).to.equal(true)
			TestKit.note(
				string.format(
					"C1 understorey: %d sapling(s) to scale %.2f, capacity %d of %d (%d canopy + %d under + %d fern + %d skirt), closest two of %d trees %.2f studs (gap %d)",
					saplings,
					worstScale,
					Plan.cellCapacity("C1"),
					Plan.CELL_PLAN_CAP,
					zones,
					under,
					ferns,
					skirt,
					#trees,
					worst,
					plan.minGapStuds
				)
			)
		end)
	end)

	-- ---------------------------------------------------------------- 13. the same forest every time

	describe("a cell's wood", function()
		it("is the same list twice, and the same list whatever order the cells were built in", function()
			local id = Grid.DEFAULT_CELL
			local first = Plan.plantCell(id)
			local second = Plan.plantCell(id)
			expect(#first).to.equal(#second)
			expect(#first > 0).to.equal(true)
			for index, item in ipairs(first) do
				local other = second[index]
				expect(other.model).to.equal(item.model)
				expect(other.x).to.equal(item.x)
				expect(other.z).to.equal(item.z)
				expect(other.scale).to.equal(item.scale)
				expect(other.yaw).to.equal(item.yaw)
				expect(other.band).to.equal(item.band)
			end
			-- ...AND IN A DIFFERENT BUILD ORDER. `Grid.seedFor` hashes (seed, row, column, stream)
			-- and NEVER a counter, so planting B1 first cannot shift A1 by one draw. This is the
			-- case `drive-places.md` section 10.1 was written after.
			local aFirst = Plan.plantCell("A1")
			local _ = Plan.plantCell("B1")
			local aAfter = Plan.plantCell("A1")
			expect(#aAfter).to.equal(#aFirst)
			for index, item in ipairs(aFirst) do
				expect(aAfter[index].model).to.equal(item.model)
				expect(aAfter[index].x).to.equal(item.x)
				expect(aAfter[index].z).to.equal(item.z)
			end
			-- AND NO TWO CELLS ARE THE SAME FOREST, which is the other half of the property.
			expect(Plan.plantCell("A1")[1].x == Plan.plantCell("B1")[1].x).to.equal(false)
			-- A NAME NOBODY KNOWS GETS NO WOOD rather than the wrong wood.
			expect(#Plan.plantCell("Z9")).to.equal(0)
			expect(Plan.cellPlanFor("Z9")).to.equal(nil)
			TestKit.note(string.format("%s: %d plantings, identical twice and across build orders", id, #first))
		end)
	end)

	-- --------------------------------------------------- 14. under the capacity and the two part caps

	describe("the budget", function()
		-- THE TWO CAPS ARE DERIVED FROM A MEASURED RATIO, not typed (`grid-roads.md` 8.2): the old
		-- `< 3,600` carried `grid-map.md` 8.3's refuted "~7 parts a model" against the measured 3.03,
		-- and left C1 184 models of room where Karen asked for more trees. Archived: backups/README.md.
		it("holds every cell under its own capacity, its plan cap and its part cap", function()
			-- THE CAPS MOVE WITH THE BUDGETS, so the spec recomputes them and never restates them.
			local planCap = math.floor(Plan.PART_BUDGET_DRIVE / Plan.PARTS_PER_MODEL)
			local partCap = math.floor(Plan.PART_BUDGET_CELL / Plan.PARTS_PER_MODEL)
			expect(Plan.CELL_PLAN_CAP).to.equal(planCap)
			expect(Plan.CELL_PART_CAP).to.equal(partCap)
			-- ...AND AT THE PAIR THE DESIGN PUBLISHES (`grid-roads.md` 8.2, `cell-loading.md` 8.1), so
			-- a change to the ratio or to either budget reddens here before it ships undocumented.
			-- **TASK 337c raised all three**: 3.03 -> 3.76 parts a model (C1's own live 9,318/2,476),
			-- and the budgets to fit a skirt on all four roads -- 12,800 drawn, 27,000 planned.
			-- **TASK 346 raised the two budgets again** for the deepest band and its widened flanks
			-- at the corners and the road ends -- 14,200 drawn, 29,000 planned. The ratio is
			-- unchanged: C1's live wood re-measured 3.707 parts a model
			-- (`<runs-dir>/346-split.luau`), which 3.76 still bounds.
			expect(Plan.PARTS_PER_MODEL).to.equal(3.76)
			expect(Plan.CELL_PLAN_CAP).to.equal(7712)
			expect(Plan.CELL_PART_CAP).to.equal(3776)
			local worstId, worstTotal, worstCap = "", 0, 0
			local planSlack, partSlack = math.huge, math.huge
			local lines = {}
			for _, id in ipairs(Grid.cellIds()) do
				local capacity = Plan.cellCapacity(id)
				local total = #woods[id]
				-- 1. WHAT IS DRAWN IS INSIDE WHAT WAS PLANNED.
				expect(total <= capacity).to.equal(true)
				-- 2. THE TYPO GUARD, on the BOUND itself and not on today's draw: a zone at spacing 2
				-- plans 100,000 sites and this catches it before anything is cloned.
				expect(capacity <= Plan.CELL_PLAN_CAP).to.equal(true)
				-- 3. THE BOUND THAT NOW BINDS -- models against the per-cell PART ceiling.
				expect(total <= Plan.CELL_PART_CAP).to.equal(true)
				-- ...AND THE SAME FUNCTION UNDER THE NAME EVERY OTHER CALLER USES.
				expect(Plan.capacity(Grid.layoutFor(id), Plan.cellPlanFor(id))).to.equal(capacity)
				planSlack = math.min(planSlack, Plan.CELL_PLAN_CAP - capacity)
				partSlack = math.min(partSlack, Plan.CELL_PART_CAP - total)
				if total > worstTotal then
					worstId, worstTotal, worstCap = id, total, capacity
				end
				local trees, ferns, skirt = 0, 0, 0
				for _, item in ipairs(woods[id]) do
					if item.band == "herb" then
						ferns += 1
					elseif item.side < 0 then
						skirt += 1
					else
						trees += 1
					end
				end
				table.insert(lines, string.format("%s %d(t%d f%d s%d)/%d", id, total, trees, ferns, skirt, capacity))
			end
			TestKit.note(
				string.format(
					"per cell: %s -- worst %s %d of %d; %.2f parts/model, caps %d plan / %d part; "
						.. "tightest slack %d plan, %d part",
					table.concat(lines, " "),
					worstId,
					worstTotal,
					worstCap,
					Plan.PARTS_PER_MODEL,
					Plan.CELL_PLAN_CAP,
					Plan.CELL_PART_CAP,
					planSlack,
					partSlack
				)
			)
		end)

		-- KAREN, 2026-11-03, HAVING PLAYED C1: *"more trees"*. The floor is pinned so a later tweak
		-- cannot quietly give it back, and the planter's own tally says WHICH RULE refuses the rest.
		-- Task 328s. Design: docs/design/grid-roads.md 8.2.
		it("plants C1 at the density Karen asked for, and accounts for every site it refused", function()
			local rows = Plan.plantCell("C1")
			local tally = Plan.TALLY
			-- THE FLOOR IS ON C1's OWN GROUND, which is the half Karen looked at in 328s, and it is
			-- the number that task already measured: not one tree inside C1 has moved since.
			-- **TASK 337c: the skirt is back on all four sides, so `skirtHere` must now be > 0** --
			-- that is Karen's *"behind the road always has to be forest"*, and a skirt that silently
			-- withdrew again would redden here. 666 at the shipped bend
			-- (`<runs-dir>/337c-plan-all.txt`), asserted as a floor so a recipe tweak costs sites
			-- without stopping the suite.
			local ownHere, skirtHere = 0, 0
			for _, item in ipairs(rows) do
				if item.side < 0 then
					skirtHere += 1
				else
					ownHere += 1
				end
			end
			expect(ownHere >= 1900).to.equal(true)
			expect(skirtHere >= 600).to.equal(true)
			expect(#rows).to.equal(BENT_C1)
			expect(#rows <= Plan.CELL_PART_CAP).to.equal(true)
			expect(tally.planted).to.equal(#rows)
			-- EVERY OFFERED SITE LANDS IN EXACTLY ONE BUCKET, which is what makes the split a
			-- measurement rather than two totals and a guess: a new refusal arm with no counter
			-- reddens here.
			local mask, crown = 0, 0
			for _, n in pairs(tally.mask) do
				mask += n
			end
			for _, n in pairs(tally.crown) do
				crown += n
			end
			local sum = tally.outside + tally.noRows + tally.gap + mask + crown + tally.planted
			expect(sum).to.equal(tally.offered)
			TestKit.note(
				string.format(
					"C1 planned %d of %d offered (cap %d): gap %d, mask %d, crown %d, outside %d, noRows %d",
					#rows,
					tally.offered,
					Plan.CELL_PART_CAP,
					tally.gap,
					mask,
					crown,
					tally.outside,
					tally.noRows
				)
			)
		end)
	end)

	-- ---------------------------------------------------------------- 15. nothing in a road

	describe("the roads", function()
		it("carry no tree, measured independently of Places.inLane and then through it", function()
			local half = Grid.CONFIG.roadClearStuds / 2
			local roads = Grid.roads()
			local worst = math.huge
			local total = 0
			for _, id in ipairs(Grid.cellIds()) do
				local layout = Grid.layoutFor(id)
				local plan = Plan.cellPlanFor(id)
				for _, item in ipairs(woods[id]) do
					total += 1
					-- INDEPENDENTLY: the spec's own loop over the road list, which is
					-- `drive-places.md` section 10.4 item 3's lesson -- a rule asserted only through
					-- the function that implements it asserts nothing.
					for _, road in ipairs(roads) do
						-- MEASURED FROM THE CURVE AND PERPENDICULAR TO IT (task 328q, design 5.5),
						-- with `Grid.roadCentreAt` and the tangent -- not from `road.at`, and not
						-- through `Places.roadDistance`, whose job this checks.
						local gap
						if road.axis == "x" then
							gap = if item.x >= road.from and item.x <= road.to
								then math.abs(item.z - Grid.roadCentreAt(road, item.x)) / math.sqrt(
									1 + Grid.bendSlopeZ(item.x) ^ 2
								)
								else math.huge
						else
							gap = if item.z >= road.from and item.z <= road.to
								then math.abs(item.x - Grid.roadCentreAt(road, item.z)) / math.sqrt(
									1 + Grid.bendSlopeX(item.z) ^ 2
								)
								else math.huge
						end
						expect(gap > half).to.equal(true)
						worst = math.min(worst, gap)
					end
					-- ...AND THROUGH IT. `Places.inLane` measures against the layout's own line z at
					-- that x, which for a cell is its MAIN road -- the one a hunter stands on.
					--
					-- **ASKED ONLY WHERE THAT ROAD ACTUALLY RUNS** (task 346). `inLane` is the LINE
					-- place rule and its line has no ends; a grid road carries `from`/`to`, and the
					-- widened skirt plants past them on purpose -- closing the open channel a road
					-- used to leave where it ran out of the grid. Past the road's end the question
					-- has no road to be about, and `clearOfEveryRoad` below (which does read
					-- `from`/`to`) is the rule that binds there.
					local main = Grid.roadsOf(id).main
					if item.x >= main.from and item.x <= main.to then
						expect(Plan.inLane(item.x, item.z, layout, plan)).to.equal(false)
					end
					expect(Plan.clearOfEveryRoad(item.x, item.z)).to.equal(true)
				end
			end
			-- A STAND'S CLEARANCE FALLS OUT OF THE SAME FACT, and is asserted rather than argued:
			-- every stand of every cell sits ON a road's centre line, so no tree is inside its
			-- circle. 8 studs is the dispatch's number; `ForestTest.PICK.standRadiusStuds` is 12 and
			-- `HighSeats.footprintRadiusStuds` is the tower's own.
			local tightest = math.huge
			for _, id in ipairs(Grid.cellIds()) do
				for index = 1, Grid.standCount(id) do
					local at = Grid.standPosition(id, index)
					for _, item in ipairs(woods[id]) do
						local dx, dz = item.x - at.X, item.z - at.Z
						tightest = math.min(tightest, math.sqrt(dx * dx + dz * dz))
					end
				end
			end
			expect(tightest > 12).to.equal(true)
			expect(tightest > HighSeats.footprintRadiusStuds()).to.equal(true)
			TestKit.note(
				string.format(
					"%d plantings: nearest road centre %.2f studs (clear half %.1f), nearest stand %.2f studs",
					total,
					worst,
					half,
					tightest
				)
			)
		end)
	end)

	-- ---------------------------------------------------------------- 16. the skirt

	describe("the skirt", function()
		it("reaches across all four roads and stops at skirtStuds", function()
			local half = Grid.CONFIG.roadClearStuds / 2
			local box = Grid.footprint()
			local lines = {}
			-- WHAT A CELL'S OWN WOOD IS MADE OF, by group, which is what "the next cell looks like
			-- itself" means as a number. Read off the PLAN and never typed here.
			local function sharesOwn(id: string): any
				local tally: { [string]: number } = {}
				local total = 0
				for _, item in ipairs(woods[id]) do
					if item.side > 0 and item.band ~= "herb" then
						local g = Plan.groupOf(item.model) or "?"
						tally[g] = (tally[g] or 0) + 1
						total += 1
					end
				end
				return { tally = tally, total = total }
			end
			-- WHICH OUTER EDGE A SIDE OR A ROW IS BEYOND, as its own key (round 1, finding 1). A
			-- corner cell has TWO `id == nil` sides, so one shared "OUTER" bucket proved only three
			-- of its four sides: an empty band behind one of them passed off the other's rows.
			-- The two bands are disjoint -- each spans the cell's own extent along the OTHER axis,
			-- so a row beyond the west edge has `gz` inside the footprint and vice versa.
			local function sideKey(side: any): string
				if side.id ~= nil then
					return side.id :: string
				end
				if side.axis == "z" then
					return if side.sign > 0 then "OUTER:E" else "OUTER:W"
				end
				return if side.sign > 0 then "OUTER:N" else "OUTER:S"
			end
			-- WORST ROAD CLEARANCE, SKIRT AND OWN WOOD SIDE BY SIDE: the dispatch's *"the skirt's
			-- roadside edge looks like the cell's own roadside edge"* as one pair of numbers.
			local worstSkirtRoad, worstOwnRoad = math.huge, math.huge
			for _, id in ipairs(Grid.cellIds()) do
				local plan = Plan.cellPlanFor(id)
				local mine = Grid.boundsOf(id)
				local sides = Plan.skirtSides(id)
				-- FOUR SIDES FOR EVERY CELL since task 337c: three neighbours and an outer edge for
				-- a middle cell, two and two for a corner.
				expect(#sides).to.equal(4)
				local count, reach = 0, 0
				local hitEach: { [string]: number } = {}
				local groupOnSide: { [string]: { [string]: number } } = {}
				for _, item in ipairs(woods[id]) do
					if item.side < 0 then
						count += 1
						-- A ROW CARRIES THE WORLD POINT AND EVERY BOX HERE IS A GRID RECT
						-- (task 328r): the skirt is placed in grid space, so that is where it is
						-- inside exactly one neighbour -- or outside the footprint altogether.
						local gx, gz = Grid.toGrid(item.x, item.z)
						-- IT IS OUTSIDE THE ACTIVE CELL...
						local inside = gx > mine.minX and gx < mine.maxX and gz > mine.minZ and gz < mine.maxZ
						expect(inside).to.equal(false)
						-- ...AND INSIDE EXACTLY ONE SIDE: one neighbour cell, or the ground beyond
						-- the grid's own border road.
						local found, key = nil, nil
						for _, side in ipairs(sides) do
							if side.id ~= nil then
								local other = Grid.boundsOf(side.id :: string)
								if gx >= other.minX and gx <= other.maxX and gz >= other.minZ and gz <= other.maxZ then
									expect(key).to.equal(nil)
									found, key = side, side.id
								end
							end
						end
						if key == nil then
							-- THE OUTER EDGE: beyond the footprint, which INCLUDES the border road.
							-- EXACTLY ONE of the four edges, keyed by itself, so a corner cell's two
							-- outer sides are counted apart (round 1, finding 1).
							local beyond = {}
							if gx < box.minX then
								table.insert(beyond, "OUTER:W")
							end
							if gx > box.maxX then
								table.insert(beyond, "OUTER:E")
							end
							if gz > box.maxZ then
								table.insert(beyond, "OUTER:N")
							end
							if gz < box.minZ then
								table.insert(beyond, "OUTER:S")
							end
							-- ONE EDGE, OR TWO AT A WORLD CORNER: since task 346 the deepest band of
							-- an outer edge runs `SKIRT_WIDEN_STUDS` past both ends of the cell's
							-- frontage, so the quadrant diagonally beyond a corner of the GRID is
							-- beyond two of them. The key is still ONE edge -- the first in the
							-- fixed W/E/N/S order -- so every side's own count below still bites.
							expect(#beyond >= 1 and #beyond <= 2).to.equal(true)
							key = beyond[1]
						end
						hitEach[key] = (hitEach[key] or 0) + 1
						local bucket = groupOnSide[key]
						if bucket == nil then
							bucket = {}
							groupOnSide[key] = bucket
						end
						local group = Plan.groupOf(item.model) or "?"
						bucket[group] = (bucket[group] or 0) + 1
						-- THE DISTANCE FROM THE SHARED ROAD'S OWN CENTRE LINE. Into a neighbour the
						-- band starts at that cell's inset edge, `roadClear / 2 + CELL_EDGE_STUDS`
						-- from the centre; over an outer edge it starts at the far kerb, `half`.
						local axis = if found ~= nil then found.axis else nil
						if axis == nil then
							axis = if gx < box.minX or gx > box.maxX then "z" else "x"
						end
						local gap
						if axis == "z" then
							local centre = if gx > mine.maxX then mine.maxX + half else mine.minX - half
							gap = math.abs(gx - centre)
						else
							local centre = if gz > mine.maxZ then mine.maxZ + half else mine.minZ - half
							gap = math.abs(gz - centre)
						end
						expect(gap >= half).to.equal(true)
						-- **THE WIDENED DEEPEST BAND IS THE REACH SINCE TASK 346**, not `skirtStuds`.
						-- `SKIRT_WIDEN_STUDS` is the larger of the two -- the flank runs that far
						-- ACROSS the cell's frontage at an outer edge, while the band itself runs
						-- `SKIRT_DEEPEST_STUDS` out -- plus one spacing of jitter.
						expect(gap <= half + Plan.CELL_EDGE_STUDS + Plan.SKIRT_WIDEN_STUDS + plan.deepSpacingStuds).to.equal(
							true
						)
						reach = math.max(reach, gap)
						-- NOTHING ON A ROAD, A DITCH OR A VERGE, A STAND PAD, A TOWER, A RIDE OR A
						-- BEATER LINE -- asked of the cell whose GROUND it stands on, with the
						-- template and scale the draw settled, which is `scatter`'s own last arm.
						local ground = if found ~= nil then found.id :: string else id
						expect(Plan.maskGrid(ground, gx, gz, item.model, item.scale)).to.equal(nil)
						worstSkirtRoad = math.min(worstSkirtRoad, Plan.roadDistanceGrid(gx, gz))
					elseif item.band ~= "herb" then
						local gx, gz = Grid.toGrid(item.x, item.z)
						worstOwnRoad = math.min(worstOwnRoad, Plan.roadDistanceGrid(gx, gz))
					end
				end
				-- EVERY SIDE IS DRESSED (task 337c), the planted neighbours and the outer edge
				-- alike, so neither "it skirts everything" nor "it skirts nothing" can pass.
				local outerSides = 0
				for _, side in ipairs(sides) do
					if side.id == nil then
						outerSides += 1
					end
					expect((hitEach[sideKey(side)] or 0) > 0).to.equal(true)
				end
				expect(count > 0).to.equal(true)
				-- WHOSE WOOD EACH SIDE IS: across a road into a cell with a wood of its own, THAT
				-- cell's; over an outer edge, and into A1 which has none, this cell's. Asserted
				-- as a SHARE and not as "the same dominant group", because C2's own wood is
				-- 1,252 conifer to 1,218 birch and a 600-stem sample tilts either way, so the
				-- test would be about the tie and not about the rule. A swapped rule still
				-- reddens: C1's birch is ~1 % of B1's own wood and 10 % is far above it.
				for _, side in ipairs(sides) do
					local key = sideKey(side)
					local speciesCell = if side.id ~= nil and Plan.hasOwnWood(side.id) then side.id else id
					local best, bestN = nil, 0
					for g, n in pairs(groupOnSide[key] or {}) do
						if n > bestN then
							best, bestN = g, n
						end
					end
					expect(best ~= nil).to.equal(true)
					local shares = sharesOwn(speciesCell :: string)
					expect(shares.total > 0).to.equal(true)
					expect((shares.tally[best :: string] or 0) / shares.total >= 0.10).to.equal(true)
				end
				table.insert(
					lines,
					string.format(
						"%s %d over %d sides (%d outer, reach %.0f/%d)",
						id,
						count,
						#sides,
						outerSides,
						reach,
						plan.skirtStuds
					)
				)
			end
			-- ONE PAIR, ONE LINE: the skirt's roadside clearance against the own wood's.
			expect(worstSkirtRoad >= Plan.VERGE_STUDS.to).to.equal(true)
			expect(worstOwnRoad >= Plan.VERGE_STUDS.to).to.equal(true)
			TestKit.note(
				string.format(
					"skirt: %s -- nearest road centre skirt %.2f / own %.2f studs (verge ends %.1f)",
					table.concat(lines, " "),
					worstSkirtRoad,
					worstOwnRoad,
					Plan.VERGE_STUDS.to
				)
			)
		end)
	end)

	-- ------------------------------------------- 16a. the corners and the road ends (task 346)

	describe("the deep corners and road ends", function()
		-- Karen, 2026-11-10: *"more tree needs behind, it has to be feeling animals run away to
		-- another forest"* / *"also more trees on back side specially on corners or ending"*.
		--
		-- **THIS CASE DIES IF EITHER HALF OF THE DEEPENING IS DELETED** (lesson L-093). Set
		-- `SKIRT_WIDEN_STUDS` to 0 and every corner quadrant empties; drop the third band from
		-- `skirtBands` and nothing stands past `skirtStuds`. Both are counted off the PLANTED
		-- sites, not off the band rectangles, so a band that plans ground the mask refuses would
		-- not pass it either.
		it("plants every corner quadrant and carries the wood past the old skirt depth", function()
			local lines = {}
			local fp = Grid.footprint()
			for _, id in ipairs(Grid.cellIds()) do
				local box = Grid.boundsOf(id)
				local plan = Plan.cellPlanFor(id)
				local half = Grid.CONFIG.roadClearStuds / 2
				-- A CORNER QUADRANT: beyond the cell in BOTH axes, past the middle of the road, so
				-- nothing a side band drew across the cell's own frontage can be counted here.
				local quads = { SW = 0, SE = 0, NW = 0, NE = 0 }
				-- WHICH CORNERS MUST BE FILLED: the ones an OUTER edge touches, because only an
				-- outer edge's deepest band is widened past the cell's frontage. A middle cell has
				-- one outer side and so two; a corner cell of the grid has two sides and three.
				local wanted: { [string]: boolean } = {}
				for _, side in ipairs(Plan.skirtSides(id)) do
					if side.id == nil then
						if side.axis == "x" then
							local ns = if side.sign > 0 then "N" else "S"
							wanted[ns .. "W"], wanted[ns .. "E"] = true, true
						else
							local we = if side.sign > 0 then "E" else "W"
							wanted["N" .. we], wanted["S" .. we] = true, true
						end
					end
				end
				local deepest, beyondSkirt, outside = 0, 0, 0
				for _, item in ipairs(Plan.plantCell(id)) do
					if item.side < 0 then
						local dx = if item.x < box.minX - half
							then box.minX - item.x
							elseif item.x > box.maxX + half then item.x - box.maxX
							else nil
						local dz = if item.z < box.minZ - half
							then box.minZ - item.z
							elseif item.z > box.maxZ + half then item.z - box.maxZ
							else nil
						if dx ~= nil and dz ~= nil then
							local key = (if item.z > box.maxZ then "N" else "S")
								.. (if item.x > box.maxX then "E" else "W")
							quads[key] += 1
						end
						-- HOW FAR OUT OF THE CELL IT STANDS, on whichever axis took it there.
						local out = math.max(dx or 0, dz or 0)
						if out > plan.skirtStuds then
							beyondSkirt += 1
						end
						deepest = math.max(deepest, out)
						-- ...AND HOW FAR OUTSIDE THE WHOLE GRID, which is the terrain question.
						outside =
							math.max(outside, fp.minX - item.x, item.x - fp.maxX, fp.minZ - item.z, item.z - fp.maxZ)
					end
				end
				local filled = 0
				for key in pairs(wanted) do
					if (quads[key] or 0) <= 0 then
						error(string.format("%s: corner quadrant %s holds no tree", id, key), 0)
					end
					filled += 1
				end
				-- IT HAS TO BITE: every cell of a 2 x 4 grid touches at least one outer edge.
				expect(filled >= 2).to.equal(true)
				-- THE DEEPEST BAND REACHED GROUND NO EARLIER BAND COULD...
				expect(beyondSkirt > 0).to.equal(true)
				-- ...AND EVERY SKIRT SITE STILL STANDS ON GROUND THE TASK 340 TRIM KEPT. K1 is the
				-- footprint grown by `Relief.BLEND_STUDS + 230 + Grid.maxBendStuds()`
				-- (`tools/terrainbake.py`'s `region_for`), which is 490 studs at today's bend;
				-- outside it there is no terrain, so a tree planted there has nothing to stand on.
				-- 230 of that pad is the OLD skirt depth, and the deepest band spends the rest of it.
				expect(outside <= 490).to.equal(true)
				table.insert(
					lines,
					string.format(
						"%s SW%d SE%d NW%d NE%d past%d max%.0f out%.0f",
						id,
						quads.SW,
						quads.SE,
						quads.NW,
						quads.NE,
						beyondSkirt,
						deepest,
						outside
					)
				)
			end
			-- THE TWO NUMBERS ARE ONE FACT WITH THE ROAD, not two typed constants.
			expect(Plan.SKIRT_WIDEN_STUDS).to.equal(Grid.CONFIG.roadClearStuds + Plan.SKIRT_DEEPEST_STUDS)
			TestKit.note(string.format("corners and ends: %s", table.concat(lines, " ")))
		end)
	end)

	-- ---------------------------------------------------------------- 17/18. the slice

	describe("the slice", function()
		-- A CLOCK THE WORK ADVANCES AND READS DO NOT. That is the faithful model: `os.clock()` costs
		-- nothing and cloning a model costs 0.45 ms (design 8.3, M9). A clock that ticked on every
		-- READ would make the measured step length an artefact of how often the loop looks at it.
		local function fakeClock(costSeconds: number)
			local t = 0
			return function()
				return t
			end, function()
				t += costSeconds
			end
		end

		it("spends a budget, finishes, and destroys before it plants", function()
			-- 1.0 ms A MODEL: twice design 8.3's own measurement (M9, 200 models in 0.09 s),
			-- rounded up so the cost is NOT a divisor of `BUDGET_MS`. At 0.9 the fifth item lands on
			-- 4.5 exactly and whether the step stops there is decided by the last bit of a float:
			-- `0.0009 * 5` is 4.500000000000001 ms and `(0.9 / 1000) * 5` is 4.499999999999999, so the
			-- same arithmetic written two ways gave 5 items and 6. A case at a knife edge measures the
			-- float and not the budget.
			local COST_MS = 1.0
			local clock, spend = fakeClock(COST_MS / 1000)
			local plantItems, destroyItems = {}, {}
			for index = 1, 2400 do
				table.insert(plantItems, { kind = "plant", index = index })
			end
			for index = 1, 600 do
				table.insert(destroyItems, { kind = "destroy", index = index })
			end
			local order = {}
			Slice.reset()
			-- THE CALLER ASKS FOR THE PLANT FIRST, ON PURPOSE: the ORDER is the slice's rule and not
			-- the caller's discipline (design 8.3, "whole cell destroyed, FIRST").
			Slice.begin("plant", plantItems, {
				clock = clock,
				work = function(item)
					spend()
					table.insert(order, item.kind)
				end,
			})
			Slice.begin("destroy", destroyItems, {
				clock = clock,
				work = function(item)
					spend()
					table.insert(order, item.kind)
				end,
			})
			expect(Slice.pending()).to.equal(3000)
			local steps, worstStep, done = 0, 0, false
			while not done and steps < 4000 do
				local before = clock()
				local spent, finished = Slice.step(before)
				done = finished
				steps += 1
				-- NO STEP TOUCHES MORE THAN `MAX_PER_STEP` ITEMS...
				expect(spent <= Slice.MAX_PER_STEP).to.equal(true)
				-- ...AND NO STEP RUNS PAST `BUDGET_MS` BY MORE THAN THE ONE ITEM IT WAS ALREADY
				-- DOING. That is the contract `Slice.step`'s header states, and not a weaker one: the
				-- budget is checked BEFORE each item, so a step stops as soon as it is spent and can
				-- only ever overrun by the cost of the item in hand. `overBudgetStarts` below is the
				-- other half -- no item is ever BEGUN past the budget.
				local took = (clock() - before) * 1000
				expect(took <= Slice.BUDGET_MS + COST_MS + 1e-6).to.equal(true)
				worstStep = math.max(worstStep, spent)
			end
			expect(done).to.equal(true)
			expect(Slice.pending()).to.equal(0)
			local stats = Slice.stats()
			-- THE TOTAL EQUALS THE INPUT: nothing dropped, nothing done twice.
			expect(stats.planted).to.equal(2400)
			expect(stats.destroyed).to.equal(600)
			expect(#order).to.equal(3000)
			expect(stats.overBudgetStarts).to.equal(0)
			expect(stats.stepMsMax <= Slice.BUDGET_MS + COST_MS + 1e-6).to.equal(true)
			-- DESTROY RAN BEFORE PLANT: the first 600 work calls are all destroys and no destroy
			-- comes after a plant.
			for index = 1, 600 do
				expect(order[index]).to.equal("destroy")
			end
			for index = 601, 3000 do
				expect(order[index]).to.equal("plant")
			end
			-- AT 1 ms A MODEL THE CLOCK IS WHAT BITES: the fifth item starts at 4.0 ms and the sixth
			-- would start at 5.0, so 5 items a step and not 10.
			expect(worstStep).to.equal(5)
			-- ...AND AT 0.1 ms IT IS `MAX_PER_STEP`. One boolean apart, both bounds proved to bite.
			local fastClock, fastSpend = fakeClock(0.0001)
			Slice.reset()
			Slice.begin("plant", plantItems, {
				clock = fastClock,
				work = function()
					fastSpend()
				end,
			})
			local fastWorst, fastDone, fastSteps = 0, false, 0
			while not fastDone and fastSteps < 4000 do
				local spent, finished = Slice.step(fastClock())
				fastWorst, fastDone, fastSteps = math.max(fastWorst, spent), finished, fastSteps + 1
			end
			expect(fastWorst).to.equal(Slice.MAX_PER_STEP)
			expect(Slice.stats().planted).to.equal(2400)
			-- AN EMPTY QUEUE IS DONE AND NOT A SPIN.
			Slice.reset()
			local spent, finished = Slice.step(0)
			expect(spent).to.equal(0)
			expect(finished).to.equal(true)
			TestKit.note(
				string.format(
					"slice: 3000 items in %d steps, worst %d/step, stepMsMax %.3f ms (budget %.1f + one %.1f ms item); 0.1 ms/model -> %d/step in %d steps",
					steps,
					worstStep,
					stats.stepMsMax,
					Slice.BUDGET_MS,
					COST_MS,
					fastWorst,
					fastSteps
				)
			)
		end)

		it("plants nearest the hunter line first", function()
			local id = Grid.DEFAULT_CELL
			local layout = Grid.layoutFor(id)
			local ordered = Slice.order(woods[id], layout)
			expect(#ordered).to.equal(#woods[id])
			-- MONOTONE IN |z - roadZ(x)|, over every pair in sequence.
			local last = -1
			for _, item in ipairs(ordered) do
				local key = math.abs(item.z - Forest.roadZ(item.x, layout))
				expect(key >= last - 1e-9).to.equal(true)
				last = key
			end
			-- IT IS A PERMUTATION AND NOT A FILTER: every planting is still there, once.
			local seen = {}
			for _, item in ipairs(woods[id]) do
				seen[item] = (seen[item] or 0) + 1
			end
			for _, item in ipairs(ordered) do
				expect(seen[item] >= 1).to.equal(true)
				seen[item] -= 1
			end
			for _, left in pairs(seen) do
				expect(left).to.equal(0)
			end
			-- THE SAME LIST TWICE: `table.sort` is not stable, so the tie-break is the original
			-- index and the order is total.
			local again = Slice.order(woods[id], layout)
			for index, item in ipairs(ordered) do
				expect(again[index]).to.equal(item)
			end
			TestKit.note(
				string.format(
					"order: first %.1f studs off the line, last %.1f",
					math.abs(ordered[1].z - Forest.roadZ(ordered[1].x, layout)),
					last
				)
			)
		end)
	end)

	-- ---------------------------------------------------------------- 18b. every tree ON the ground

	describe("a dressed cell", function()
		it("puts every planted tree on the ground and refuses the rest, destroy before plant", function()
			-- LESSON L-086: design 13.1's cases 12-18 and 20 carry NO ground-contact assertion, and
			-- an unguarded "0 floating" line has shipped twice. Task 326's planter is what guards
			-- it; this case DRIVES that planter -- the real `plantOne`, the real `TreeGround` -- over
			-- a real cell's plan on a hillside that falls 1 stud in 10, and re-measures every model
			-- that went in off the MODEL and not off the lift (`Places.junctionGap`).
			local function hillside(x: number, z: number): number?
				return 120 + 0.1 * (x - Grid.CONFIG.originX) - 0.05 * (z - Grid.CONFIG.originZ)
			end
			-- FAKE TEMPLATES: one Model per species name, a named `Trunk` and a wider crown above it,
			-- which is `places.spec`'s own fixture shape.
			local sources = Instance.new("Folder")
			local function fake(name: string): Model
				local model = Instance.new("Model")
				model.Name = name
				local trunk = Instance.new("Part")
				trunk.Name = "Trunk"
				trunk.Size = Vector3.new(4, 40, 4)
				trunk.Position = Vector3.new(0, 20, 0)
				trunk.Anchored = true
				trunk.Parent = model
				local crown = Instance.new("Part")
				crown.Name = "OuterLeaves"
				crown.Size = Vector3.new(24, 24, 24)
				crown.Position = Vector3.new(0, 48, 0)
				crown.Anchored = true
				crown.Parent = model
				model.PrimaryPart = trunk
				model.Parent = sources
				return model
			end
			local made: { [string]: Model } = {}
			local function template(name: string): Model?
				if made[name] == nil then
					made[name] = fake(name)
				end
				return made[name]
			end

			local id = Grid.DEFAULT_CELL
			local grid = Instance.new("Folder")
			grid.Name = Planter.GRID_FOLDER
			local report = Planter.dressCell(id, grid, hillside, template, nil, nil)
			expect(report.cell).to.equal(id)
			-- THE SAME READER THE DRESS USES (task 328f).
			expect(report.wanted).to.equal(#Plan.plantCell(id, hillside))
			-- **AND SINCE TASK 335 THE TWO ARE EQUAL, WHICH IS SAID HERE RATHER THAN HIDDEN**: no
			-- recipe declares `reliefBias` any more, so a plan WITH a ground reader and one without
			-- are the same plan and the pair above can no longer bite on the COUNT. What still
			-- proves the reader is handed through is `plantOne`'s own use of it -- the "not one of
			-- them is in the air" assertions below -- and the bias itself is proven end to end in
			-- `grid_ground.spec` ("the relief bias ... and it bites"), which drives `plantCell`
			-- with a synthetic plan that declares it.
			expect(#Plan.plantCell(id, hillside)).to.equal(#woods[id])
			expect(report.planted > 0).to.equal(true)
			expect(report.missing).to.equal(0)
			expect(report.destroyed).to.equal(0)
			-- EVERY PLANTING IS ACCOUNTED FOR: planted, refused for a cliff, or skipped. Nothing
			-- silently vanishes.
			expect(report.planted + report.cliff + report.skipped + report.missing).to.equal(report.wanted)
			local here = grid:FindFirstChild(id)
			expect(here ~= nil).to.equal(true)
			expect(#here:GetChildren()).to.equal(report.planted)
			-- ...AND NOT ONE OF THEM IS IN THE AIR. `junctionGap` is junction minus the LOWEST
			-- terrain under the TRUNK'S OWN footprint, read at 25 samples -- never the pivot
			-- (lessons L-024, L-086). Positive is daylight.
			local worst = -math.huge
			for _, model in ipairs(here:GetChildren()) do
				local gap = Planter.junctionGap(model, hillside)
				expect(gap ~= nil).to.equal(true)
				expect(gap <= 1).to.equal(true)
				worst = math.max(worst, gap)
			end
			-- A SECOND DRESS DESTROYS THE FIRST ONE'S WOOD BEFORE PLANTING ITS OWN, and the folder
			-- does not double.
			local second = Planter.dressCell(id, grid, hillside, template, nil, nil)
			expect(second.destroyed).to.equal(report.planted)
			expect(second.planted).to.equal(report.planted)
			local folders = Planter.cellWoodFolders(grid)
			expect(#folders).to.equal(1)
			expect(#folders[1]:GetChildren()).to.equal(second.planted)
			-- A CHILD OF `GridPlaces` THAT IS NOT A CELL FOLDER IS NOT A CELL'S WOOD, and a dress
			-- never touches it.
			local other = Instance.new("Part")
			other.Name = "NotACell"
			other.Parent = grid
			Planter.dressCell(id, grid, hillside, template, nil, nil)
			expect(other.Parent).to.equal(grid)
			-- A NAME NOBODY KNOWS DRESSES NOTHING.
			local none = Planter.dressCell("Z9", grid, hillside, template, nil, nil)
			expect(none.planted).to.equal(0)
			expect(none.reason).to.equal("no-cell")
			TestKit.note(
				string.format(
					"%s on a 1-in-10 hillside: %d planted, %d refused (cliff), %d parts, worst junction %.3f studs above ground",
					id,
					report.planted,
					report.cliff,
					report.parts,
					worst
				)
			)
			grid:Destroy()
			sources:Destroy()
		end)
	end)

	-- ------------------------------------------ 19b. the forest behind the line (task 328i)

	describe("the cells that get a wood", function()
		-- KAREN, 2026-11-04: *"more trees behind the line"*. There were none: `Places.build` dressed
		-- `Grid.DEFAULT_CELL` and nothing else, so seven cells had never had a tree in them.
		it("is a list of baked cells, C1 first and C2 -- the cell behind the line -- second", function()
			local planted = Grid.PLANTED_CELLS
			-- SEVEN SINCE TASK 336: B2 and D2 joined, each with its own species (Karen, 2026-11-08:
			-- *"can you make now all grounds with different trees"*). Their ground is the raw base
			-- and that was the question the plant answered -- by raying every site, not by argument.
			expect(#planted).to.equal(7)
			expect(planted[1]).to.equal(Grid.DEFAULT_CELL)
			expect(planted[2]).to.equal("C2")
			local seen: { [string]: boolean } = {}
			for _, id in ipairs(planted) do
				-- EVERY ID IS A REAL CELL and no id is listed twice -- a duplicate would plant a
				-- cell, keep it, then fell and re-plant it for nothing.
				expect(Grid.cellOf(id) ~= nil).to.equal(true)
				expect(seen[id]).never.to.equal(true)
				seen[id] = true
			end
			-- **A1 IS THE ONE THAT IS OUT**, and it is out because it has no ground at all: it was
			-- never in a bake (`grid-terrain.md` 16's 328h/328x rows). B2 and D2 were out with it
			-- until task 336 for a different reason -- their landform was HELD
			-- (`terrainbake.py --hold-landform`) -- and that reason is spent: holding a landform is
			-- not the same as having none, and both planted.
			expect(seen["A1"]).never.to.equal(true)
			TestKit.note("PLANTED_CELLS: " .. table.concat(planted, ","))
		end)

		-- THE DENSITY, MEASURED ON THE CELL'S OWN GROUND. The SKIRT is excluded on purpose: a
		-- skirt stands in the NEIGHBOUR's rectangle, so counting it would credit a cell with wood
		-- a hunter standing in it cannot see, and it is the term 328i withdraws between two planted
		-- cells. The standard is **1,861 trees**, which is what Karen accepted on 2026-11-04
		-- (*"rest seems ok I think you did good job"*), and every other planted cell is held within
		-- **+-10 %** of it. Pinned so a later tweak cannot quietly give the density back.
		--
		-- **THE STANDARD IS THAT NUMBER AND NO LONGER C1's OWN COUNT** (task 335). It was C1's count
		-- when 328i wrote this rule; Karen's *"all has to be forest no free spot excep road"* then
		-- took C1 to 2,418 of its own, so holding four mixed woods to a one-species cell would mean
		-- raising them on nobody's instruction. C1 is held to the two caps and to its own cover case
		-- in `grid_ground.spec`, and the band below is asserted for the other four.
		-- **AND SINCE TASK 336 THE STANDARD IS C1's OWN 2,418 AGAIN**, for the reason the paragraph
		-- above gives in reverse: every planted cell is now one kind of forest planted wall to wall,
		-- so C1 is no longer the exception -- it is the measurement the other six were solved to
		-- (Karen, 2026-11-08: *"can you make now all grounds with different trees"*; the Director:
		-- *"wall-to-wall like C1"*). The band is still +-10 %, and the ceiling is still the two caps.
		it("plants every cell at C1's accepted density, and C1 itself at the number Karen saw", function()
			local function ownTrees(id: string): number
				local n = 0
				for _, item in ipairs(woods[id]) do
					if item.side > 0 and item.band ~= "herb" then
						n += 1
					end
				end
				return n
			end
			local standard = 2418
			-- C1 IS THE STANDARD AND IS PINNED EXACTLY, so a revert of its v5 recipe fails here too.
			expect(ownTrees(Grid.DEFAULT_CELL)).to.equal(standard)
			local lines = {}
			for _, id in ipairs(Grid.PLANTED_CELLS) do
				local own = ownTrees(id)
				table.insert(lines, string.format("%s %d (%.0f%%) of %d", id, own, 100 * own / standard, #woods[id]))
				if id ~= Grid.DEFAULT_CELL then
					expect(own >= math.floor(standard * 0.9)).to.equal(true)
					expect(own <= math.ceil(standard * 1.1)).to.equal(true)
				end
				-- ...AND THE WHOLE PLAN IS STILL INSIDE BOTH CAPS.
				expect(#woods[id] <= Plan.CELL_PART_CAP).to.equal(true)
				expect(Plan.cellCapacity(id) <= Plan.CELL_PLAN_CAP).to.equal(true)
			end
			-- ...AND A1, THE ONE CELL WITH NO GROUND, IS NOT TOUCHED: it is well under the band, which
			-- is what makes the case above a reading of THESE rows and not of the planter in general.
			expect(ownTrees("A1") < math.floor(standard * 0.9)).to.equal(true)
			TestKit.note(string.format("336 own wood: %s", table.concat(lines, " ")))
		end)

		-- ONE CELL, ONE KIND OF FOREST (task 336). Karen, 2026-11-08: *"can you make now all grounds
		-- with different trees"*; the Director assigned the species, which Karen delegated.
		--
		-- **THE SKIRT IS EXCLUDED AND THAT IS NOT A LOOPHOLE**: a skirt band stands in the
		-- NEIGHBOUR's rectangle and draws the NEIGHBOUR's front mix, which is what blends two woods
		-- at their shared road. So the claim is about `side > 0` -- the wood a hunter standing IN
		-- this cell is looking at -- exactly as the density case above measures it.
		--
		-- IT DIES IF THE RECIPES ARE REVERTED (lesson L-093): the old rows drew six groups in every
		-- cell, so B1 would come back with 735 birch and 721 larch in it and the first loop fails.
		it("gives each planted cell its own species, and C1 nothing but birch", function()
			-- THE ASSIGNMENT, as data. `fieldOak` and `oak` are two different groups in
			-- `Places.SPECIES` (open-grown and drawn-up), so the two oak cells are not one row.
			local WANT = {
				C1 = { "birch" },
				B1 = { "conifer" },
				D1 = { "oak" },
				A2 = { "aspen" },
				B2 = { "young" },
				C2 = { "conifer", "birch" },
				D2 = { "fieldOak", "aspen" },
			}
			local lines = {}
			for _, id in ipairs(Grid.PLANTED_CELLS) do
				local want = WANT[id]
				-- EVERY PLANTED CELL IS IN THE TABLE: a cell added to `PLANTED_CELLS` with no
				-- species assigned is a hole in this case, not a pass.
				expect(want ~= nil).to.equal(true)
				local allowed: { [string]: boolean } = {}
				for _, group in ipairs(want) do
					-- ...AND EVERY NAME IS A REAL GROUP of `Places.SPECIES`.
					expect(#Plan.namesOf(group) > 0).to.equal(true)
					allowed[group] = true
				end
				local counts: { [string]: number } = {}
				local own = 0
				for _, item in ipairs(woods[id]) do
					if item.side > 0 and item.band ~= "herb" then
						local group = Plan.groupOf(item.model)
						expect(group ~= nil).to.equal(true)
						expect(allowed[group :: string]).to.equal(true)
						counts[group :: string] = (counts[group :: string] or 0) + 1
						own += 1
					end
				end
				-- A CELL WHOSE SPECIES IS ASSIGNED PLANTS IT: an empty cell would pass the loop above.
				expect(own > 0).to.equal(true)
				local shares = {}
				for _, group in ipairs(want) do
					local share = (counts[group] or 0) / own
					-- **"ROUGHLY HALF AND HALF" IS A NUMBER** for the two mixed cells: each of the
					-- two carries 35-65 % of the cell's own wood, which equal weights in the mix
					-- produce and a 9:1 weight does not. A single-species cell carries all of it.
					if #want == 1 then
						expect(share).to.equal(1)
					else
						expect(share >= 0.35 and share <= 0.65).to.equal(true)
					end
					table.insert(shares, string.format("%s %.0f%%", group, share * 100))
				end
				table.insert(lines, string.format("%s %d: %s", id, own, table.concat(shares, " ")))
			end
			TestKit.note("336 species: " .. table.concat(lines, " | "))
		end)

		-- THE BOOT'S CRITICAL PATH (reviewer round 1). `Places.build` is `ForestTestBoot`'s
		-- composition root -- `Bots.start`, `Economy.start`, `Lobby.start`, `Shop.start`,
		-- `Match.start` and `HitLog.start` all come after it -- so it plants ONE cell. Five serial
		-- dresses measure ~172 s in Karen's place; one is ~34 s. SINCE TASK 337 THE REST ARE NOT
		-- HANDED BACK EITHER: under one cell at a time their only next action would be to be stored.
		it("plants exactly one cell on the boot path, and no more", function()
			local function hillside(x: number, z: number): number?
				return 120 + 0.1 * (x - Grid.CONFIG.originX) - 0.05 * (z - Grid.CONFIG.originZ)
			end
			-- A FAKE WORLD WITH A TEMPLATE SOURCE IN IT, because `build` returns `"no-templates"`
			-- before it dresses anything. One Model per species name, the fixture shape case 18b
			-- uses, under the first name in `Places.TEMPLATE_SOURCES`.
			local function fakeWorld(): Instance
				local world = Instance.new("Folder")
				local source = Instance.new("Folder")
				source.Name = Planter.TEMPLATE_SOURCES[1]
				source.Parent = world
				for _, names in pairs(Plan.SPECIES) do
					for _, name in ipairs(names) do
						local model = Instance.new("Model")
						model.Name = name
						local trunk = Instance.new("Part")
						trunk.Name = "Trunk"
						trunk.Size = Vector3.new(4, 40, 4)
						trunk.Position = Vector3.new(0, 20, 0)
						trunk.Anchored = true
						trunk.Parent = model
						model.PrimaryPart = trunk
						model.Parent = source
					end
				end
				return world
			end
			local world = fakeWorld()
			local report = Planter.build(hillside, world, nil, nil, { "C1", "C2", "B1" })
			-- ONE REPORT, FOR THE FIRST CELL OF THE LIST, AND ONE CELL STANDING IN THE WORLD.
			expect(#report.gridWoods).to.equal(1)
			expect(report.gridWoods[1].cell).to.equal("C1")
			-- `gridPending` IS GONE WITH THE DEFERRED DRESS (task 337): nothing is handed back, and
			-- nothing but C1 is standing. It dies if the rest are planted again -- the second
			-- assertion would read 3.
			expect(report.gridPending).to.equal(nil)
			-- ...AND NO CELL BUT THE FIRST ONE IS STANDING. Named rather than counted, because a
			-- cell whose every site the fixture's hillside refuses creates no folder at all: what
			-- this case is about is that C2 and B1 were never DRESSED.
			local gridFolder = world:FindFirstChild(Planter.GRID_FOLDER)
			expect(gridFolder:FindFirstChild("C2")).to.equal(nil)
			expect(gridFolder:FindFirstChild("B1")).to.equal(nil)
			expect(#Planter.cellWoodFolders(gridFolder) <= 1).to.equal(true)
			-- THE DEFAULT LIST IS THE CONFIG'S, AND ITS FIRST CELL IS THE ONE A PLAYER STANDS IN.
			local other = fakeWorld()
			local whole = Planter.build(hillside, other, nil, nil)
			expect(whole.gridWoods[1].cell).to.equal(Grid.PLANTED_CELLS[1])
			expect(#whole.gridWoods).to.equal(1)
			expect(whole.gridPending).to.equal(nil)
			local otherGrid = other:FindFirstChild(Planter.GRID_FOLDER)
			for index = 2, #Grid.PLANTED_CELLS do
				expect(otherGrid:FindFirstChild(Grid.PLANTED_CELLS[index])).to.equal(nil)
			end
			-- ...AND `dressPending` REFUSES EVERY SHAPE THAT WOULD PLANT NOTHING, rather than
			-- erroring on the caller's thread. It is kept as the Edit/one-off door.
			expect(#Planter.dressPending({}, world, hillside, nil)).to.equal(0)
			expect(#Planter.dressPending({ "C2" }, world, nil, nil)).to.equal(0)
			expect(#Planter.dressPending({ "C2" }, Instance.new("Folder"), hillside, nil)).to.equal(0)
			TestKit.note(
				string.format(
					"boot path: 1 cell (%s), %d planted, nothing deferred",
					whole.gridWoods[1].cell,
					whole.gridWoods[1].planted
				)
			)
			world:Destroy()
			other:Destroy()
		end)

		-- THE SKIRT RULE, INVERTED BY TASK 337c. Karen, 2026-11-09: *"behind the road always has to
		-- be forest to have impression that animals running in forest not in empty field"*. Task
		-- 328i withdrew the skirt from a planted neighbour because the two woods interpenetrated
		-- (199 trunk pairs inside 6 studs with five cells standing,
		-- `<runs-dir>/328i-overlap-after.txt`); since task 337 exactly one cell stands, so that
		-- cannot happen and every side is dressed. The old case is archived at
		-- `backups/2026-11-09-task-337c-skirt-rule-case.luau` (rule 7).
		--
		-- **IT DIES IF 337c's FIX DIES** (lesson L-093), and the kill was RUN, not argued
		-- (`<runs-dir>/337c-l093.luau` through `336probe.py`, both readings at this commit):
		-- restore `plantCell`'s `if Places.hasOwnWood(side.id) then continue end` and C1's skirt
		-- goes **666 -> 150** -- every row that is left is an outer-edge one -- so `intoPlanted`
		-- below goes 514 -> **0** and reddens. `c1Skirt > 0` alone would NOT have caught it, which
		-- is why that count is here.
		it("skirts all four of a cell's roads, planted neighbour or not, and the outer edge too", function()
			-- C1's three neighbours are ALL planted, and it skirts them anyway.
			local sides = Plan.skirtSides(Grid.DEFAULT_CELL)
			expect(#sides).to.equal(4)
			local planted, outerSides = 0, 0
			for _, side in ipairs(sides) do
				if side.id == nil then
					outerSides += 1
				elseif Plan.hasOwnWood(side.id) then
					planted += 1
				end
			end
			expect(planted).to.equal(3)
			expect(outerSides).to.equal(1)
			local box = Grid.footprint()
			local c1Skirt, outerRows, intoPlanted = 0, 0, 0
			for _, item in ipairs(woods[Grid.DEFAULT_CELL]) do
				if item.side < 0 then
					c1Skirt += 1
					local gx, gz = Grid.toGrid(item.x, item.z)
					if gx < box.minX or gx > box.maxX or gz < box.minZ or gz > box.maxZ then
						outerRows += 1
					else
						for _, side in ipairs(sides) do
							if side.id ~= nil and Plan.hasOwnWood(side.id) then
								local other = Grid.boundsOf(side.id :: string)
								if gx >= other.minX and gx <= other.maxX and gz >= other.minZ and gz <= other.maxZ then
									intoPlanted += 1
									break
								end
							end
						end
					end
				end
			end
			expect(c1Skirt > 0).to.equal(true)
			expect(outerRows > 0).to.equal(true)
			-- THE ROWS 328i's RULE WOULD HAVE REFUSED, and the one count that dies with the fix.
			expect(intoPlanted > 0).to.equal(true)
			-- EVERY CELL SKIRTS, and `A1` -- the one cell with no wood of its own -- is still read
			-- as bare, because that is what decides WHOSE species the skirt into it draws.
			expect(Plan.hasOwnWood("B2")).to.equal(true)
			expect(Plan.hasOwnWood("A1")).to.equal(false)
			expect(Plan.hasOwnWood("Z9")).to.equal(false)
			local worstSkirt = math.huge
			for _, id in ipairs(Grid.cellIds()) do
				local n = 0
				for _, item in ipairs(woods[id]) do
					if item.side < 0 then
						n += 1
					end
				end
				worstSkirt = math.min(worstSkirt, n)
			end
			expect(worstSkirt > 0).to.equal(true)
			-- ...AND NOT ONE SKIRT SITE LANDS IN THE ACTIVE CELL'S OWN GROUND: the skirt is what is
			-- across the road, so a band that leaked inward would be a second wood over this one.
			local stray = 0
			for _, id in ipairs(Grid.cellIds()) do
				local g = Plan.cellGround(id)
				for _, item in ipairs(woods[id]) do
					if item.side < 0 then
						local gx, gz = Grid.toGrid(item.x, item.z)
						if gx >= g.minX and gx <= g.maxX and gz >= g.minZ and gz <= g.maxZ then
							stray += 1
						end
					end
				end
			end
			expect(stray).to.equal(0)
			TestKit.note(
				string.format(
					"skirt: C1 %d across 4 roads (%d outer, %d into planted neighbours), weakest cell %d, 0 strays inward",
					c1Skirt,
					outerRows,
					intoPlanted,
					worstSkirt
				)
			)
		end)

		-- THE BEHAVIOUR, driven through the real planter over a fake hillside -- the fixture case 18b
		-- uses.
		--
		-- **IT DIES IF TASK 337'S FIX DIES** (design 11.1). `dressCell` used to fell every cell
		-- folder not in a `keep` set, so a dress of three cells destroyed a fourth that was standing.
		-- The stale cell below is NOT in the list and MUST survive with its tree: restore the
		-- `keep == nil` arm and `staleTree.Parent` is nil and `standing["D2"]` is nil, both red.
		it("stands every cell of the list up, and fells no cell it was not asked to dress", function()
			local function hillside(x: number, z: number): number?
				return 120 + 0.1 * (x - Grid.CONFIG.originX) - 0.05 * (z - Grid.CONFIG.originZ)
			end
			local sources = Instance.new("Folder")
			local made: { [string]: Model } = {}
			local function template(name: string): Model?
				if made[name] == nil then
					local model = Instance.new("Model")
					model.Name = name
					local trunk = Instance.new("Part")
					trunk.Name = "Trunk"
					trunk.Size = Vector3.new(4, 40, 4)
					trunk.Position = Vector3.new(0, 20, 0)
					trunk.Anchored = true
					trunk.Parent = model
					model.PrimaryPart = trunk
					model.Parent = sources
					made[name] = model
				end
				return made[name]
			end
			local grid = Instance.new("Folder")
			grid.Name = Planter.GRID_FOLDER
			-- ANOTHER CELL'S WOOD IS STANDING BEFORE THE DRESS -- one that is NOT in the list.
			-- This is the forest task 335 felled.
			local stale = Instance.new("Folder")
			stale.Name = "D2"
			stale.Parent = grid
			local staleTree = Instance.new("Model")
			staleTree.Name = "stale"
			staleTree.Parent = stale

			local wanted = { "C1", "C2", "B1" }
			local reports = Planter.dressCells(wanted, grid, hillside, template, nil, nil)
			expect(#reports).to.equal(#wanted)
			local standing: { [string]: number } = {}
			for _, folder in ipairs(Planter.cellWoodFolders(grid)) do
				standing[folder.Name] = #folder:GetChildren()
			end
			-- EVERY CELL OF THE LIST IS STANDING, with its own report's count of trees in it. This
			-- is the assertion the one-cell contract cannot pass.
			for index, id in ipairs(wanted) do
				expect(reports[index].cell).to.equal(id)
				expect(reports[index].planted > 0).to.equal(true)
				expect(standing[id]).to.equal(reports[index].planted)
			end
			-- ...AND THE OTHER CELL IS UNTOUCHED: the SAME folder Instance, with its tree still in
			-- it and still parented to it. This is the assertion the keep set cannot pass.
			expect(standing["D2"]).to.equal(1)
			expect(grid:FindFirstChild("D2")).to.equal(stale)
			expect(staleTree.Parent).to.equal(stale)
			expect(reports[1].destroyed).to.equal(0)
			-- A SECOND RUN OF THE SAME LIST RE-PLANTS AND NEVER DOUBLES: the cell being dressed is
			-- always destroyed first -- that is what re-planting it means.
			local again = Planter.dressCells(wanted, grid, hillside, template, nil, nil)
			local after = Planter.cellWoodFolders(grid)
			-- THE THREE DRESSED CELLS PLUS THE ONE THAT WAS ALREADY THERE.
			expect(#after).to.equal(#wanted + 1)
			for index, id in ipairs(wanted) do
				expect(again[index].cell).to.equal(id)
				expect(again[index].planted).to.equal(reports[index].planted)
			end
			-- AN EMPTY LIST DRESSES NOTHING AND TOUCHES NOTHING -- no `dressCell` call is made, so
			-- the wood already standing stays. That is the branch a spec takes to reach `build`
			-- with no wood at all.
			expect(#Planter.dressCells({}, grid, hillside, template, nil, nil)).to.equal(0)
			expect(#Planter.cellWoodFolders(grid)).to.equal(#wanted + 1)
			-- DRESSING ONE CELL LEAVES EVERY OTHER CELL STANDING, WITH NO KEEP LIST TO SAY SO
			-- (task 337). The keep list is gone; the smaller contract is the fix.
			local later = Planter.dressCells({ "D1" }, grid, hillside, template, nil, nil)
			expect(#later).to.equal(1)
			expect(#Planter.cellWoodFolders(grid)).to.equal(5)
			expect(staleTree.Parent).to.equal(stale)
			-- ...AND A REPEAT OF THAT ONE-CELL CALL STILL FELLS NOTHING BUT ITS OWN.
			expect(#Planter.dressCells({ "D1" }, grid, hillside, template, nil, nil)).to.equal(1)
			expect(#Planter.cellWoodFolders(grid)).to.equal(5)
			TestKit.note(
				string.format(
					"dressCells %s: %d trees standing over %d cells (D2 untouched)",
					table.concat(wanted, ","),
					reports[1].planted + reports[2].planted + reports[3].planted,
					#after
				)
			)
			grid:Destroy()
			sources:Destroy()
		end)
	end)

	-- ---------------------------------------------------------------- 328g. the prebuild's arbiter

	describe("the prebuilt forest's boot arbiter (task 328g, design 10.3)", function()
		-- ALL THREE BRANCHES BY PARAMETER, which is why `prebuildVerdict` takes the two epochs rather
		-- than reading the two attributes: the boot reads them once and this case needs no Workspace.
		it("stands on a match, dresses on an absence, and REFUSES a mismatch", function()
			local live = "58575af518ae6156"
			-- 1. THE PREBUILD STANDS. Nothing is dressed; `dress` false is the only thing the boot acts on.
			local stands = ForestTest.prebuildVerdict(live, live)
			expect(stands.branch).to.equal(ForestTest.PREBUILD.STANDS)
			expect(stands.dress).to.equal(false)
			-- 2. NO PREBUILD: today's boot exactly.
			local absent = ForestTest.prebuildVerdict(live, nil)
			expect(absent.branch).to.equal(ForestTest.PREBUILD.ABSENT)
			expect(absent.dress).to.equal(true)
			-- 3. A STALE FOREST ON RE-BAKED GROUND IS TREES HANGING IN THE AIR -- the defect this whole
			-- task exists to stop. It is REFUSED and NOTHING is silently rebuilt.
			local stale = ForestTest.prebuildVerdict(live, "0000000000000000")
			expect(stale.branch).to.equal(ForestTest.PREBUILD.REFUSED)
			expect(stale.dress).to.equal(false)
			-- BOTH EPOCHS COME BACK, because the REFUSED line prints both.
			expect(stale.live).to.equal(live)
			expect(stale.planted).to.equal("0000000000000000")
			-- THE THREE BRANCH NAMES ARE THREE, so a typo cannot collapse two of them into one.
			expect(ForestTest.PREBUILD.STANDS).never.to.equal(ForestTest.PREBUILD.ABSENT)
			expect(ForestTest.PREBUILD.STANDS).never.to.equal(ForestTest.PREBUILD.REFUSED)
			expect(ForestTest.PREBUILD.ABSENT).never.to.equal(ForestTest.PREBUILD.REFUSED)
			TestKit.note(
				string.format(
					"arbiter: match=%s absent=%s stale=%s",
					tostring(stands.branch),
					tostring(absent.branch),
					tostring(stale.branch)
				)
			)
		end)

		-- UNSTAMPED IS NOT ABSENT, and that distinction is the one the boot would get wrong on its own.
		-- A `GridForest` standing with no epoch means a wood IS there whose provenance nobody can
		-- check; calling it "absent" would dress `GridPlaces` on top of it -- the double forest.
		it("reads an unstamped GridForest as REFUSED and not as absent", function()
			expect(ForestTest.plantedEpochOf(nil)).to.equal(nil)
			local bare = Instance.new("Folder")
			bare.Name = Planter.FOREST_FOLDER
			expect(ForestTest.plantedEpochOf(bare)).to.equal(ForestTest.UNSTAMPED)
			expect(ForestTest.prebuildVerdict("abc", ForestTest.plantedEpochOf(bare)).branch).to.equal(
				ForestTest.PREBUILD.REFUSED
			)
			-- AN EMPTY STRING IS NOT AN EPOCH EITHER.
			bare:SetAttribute(ForestTest.PLANT_EPOCH_ATTR, "")
			expect(ForestTest.plantedEpochOf(bare)).to.equal(ForestTest.UNSTAMPED)
			-- ...AND A STAMPED ONE READS BACK AS ITSELF, so the STANDS branch is reachable from a folder.
			bare:SetAttribute(ForestTest.PLANT_EPOCH_ATTR, "58575af518ae6156")
			expect(ForestTest.plantedEpochOf(bare)).to.equal("58575af518ae6156")
			expect(ForestTest.prebuildVerdict("58575af518ae6156", ForestTest.plantedEpochOf(bare)).dress).to.equal(
				false
			)
			-- NO EPOCH ON EITHER SIDE IS STILL ABSENT: an un-baked world dresses as it always did.
			expect(ForestTest.prebuildVerdict(nil, nil).branch).to.equal(ForestTest.PREBUILD.ABSENT)
			-- ...BUT A STAMPED FOLDER OVER UN-BAKED GROUND IS A MISMATCH, not a match of two nils.
			expect(ForestTest.prebuildVerdict(nil, "58575af518ae6156").branch).to.equal(ForestTest.PREBUILD.REFUSED)
			bare:Destroy()
		end)

		-- WHAT THE BOOT DOES WITH `dress = false`: it hands `Places.build` an EMPTY cell list, which is
		-- the no-wood branch that function already had by parameter. So no cell is dressed, nothing is
		-- handed back to the deferred thread, and `build`'s contract is untouched.
		it("an empty cell list dresses nothing and defers nothing, which is how the boot stands down", function()
			local function hillside(x: number, _z: number): number?
				return 120 + 0.1 * (x - Grid.CONFIG.originX)
			end
			local world = Instance.new("Folder")
			local source = Instance.new("Folder")
			source.Name = Planter.TEMPLATE_SOURCES[1]
			source.Parent = world
			for _, names in pairs(Plan.SPECIES) do
				for _, name in ipairs(names) do
					local model = Instance.new("Model")
					model.Name = name
					local trunk = Instance.new("Part")
					trunk.Name = "Trunk"
					trunk.Size = Vector3.new(4, 40, 4)
					trunk.Position = Vector3.new(0, 20, 0)
					trunk.Anchored = true
					trunk.Parent = model
					model.PrimaryPart = trunk
					model.Parent = source
				end
			end
			-- A PREBUILT FOREST STANDING IN THE SAME WORLD, so this case also reads the one invariant
			-- design 10.1 rests on: `build` destroys `GridPlaces` at every boot and NEVER `GridForest`.
			local prebuilt = Instance.new("Folder")
			prebuilt.Name = Planter.FOREST_FOLDER
			prebuilt.Parent = world
			local cell = Instance.new("Folder")
			cell.Name = "C1"
			cell.Parent = prebuilt
			local standing = Instance.new("Model")
			standing.Name = "prebuilt-tree"
			standing.Parent = cell

			local down = Planter.build(hillside, world, nil, nil, {})
			expect(#(down.gridWoods or {})).to.equal(0)
			expect(down.gridPending).to.equal(nil)
			expect(world:FindFirstChild(Planter.FOREST_FOLDER)).to.be.ok()
			expect(standing.Parent).to.equal(cell)
			-- IT DIES IF THE EMPTY LIST STOPS MEANING "NOTHING": the same world with the default list
			-- dresses one cell and defers the rest.
			local up = Planter.build(hillside, world, nil, nil)
			expect(#up.gridWoods).to.equal(1)
			expect(up.gridPending).to.equal(nil)
			-- ...AND THE PREBUILT WOOD IS STILL THERE AFTER A DRESS THAT DID PLANT.
			expect(standing.Parent).to.equal(cell)
			-- `Places.stats` READS EITHER FOLDER (task 328g), which is what lets the boot print the
			-- prebuild's model count with the counter it already had.
			local forest = Planter.stats(world, Planter.FOREST_FOLDER)
			expect(forest.folder).to.equal(true)
			expect(forest.total).to.equal(1)
			expect(forest.C1).to.equal(1)
			expect(Planter.stats(world, "NoSuchFolder").folder).to.equal(false)
			expect(Planter.stats(world).folder).to.equal(true)
			TestKit.note(
				string.format(
					"stand-down: woods %d; prebuilt %d model(s) survived %d dress(es)",
					#(down.gridWoods or {}),
					forest.total,
					2
				)
			)
			world:Destroy()
		end)
	end)

	-- ------------------------------------------------- 337. one cell at a time (docs/design/cell-loading.md)
	--
	-- Karen, 2026-11-08: *"we only load one per game thats it"*. Every case here runs over FAKE
	-- folders -- never `Workspace`, never `ServerStorage` -- which is `Places.build`'s own discipline.
	describe("one cell at a time", function()
		local Cells = require(ServerScriptService.Places:WaitForChild("Cells"))

		-- A CELL FOLDER WITH `n` MODELS IN IT, parented into `home` under `root`.
		local function putCell(root: Instance, home: string, id: string, n: number): Instance
			local holder = root:FindFirstChild(home)
			if holder == nil then
				local made = Instance.new("Folder")
				made.Name = home
				made.Parent = root
				holder = made
			end
			local folder = Instance.new("Folder")
			folder.Name = id
			folder.Parent = holder
			for index = 1, n do
				local model = Instance.new("Model")
				model.Name = id .. "-tree-" .. index
				model.Parent = folder
			end
			return folder
		end
		local function names(list): { string }
			local out = {}
			for _, wood in ipairs(list) do
				table.insert(out, wood.cell .. "@" .. wood.home)
			end
			table.sort(out)
			return out
		end

		-- `wantedCell` IS PURE, and the fallback is what makes this change invisible today.
		it("answers which cell should be standing, and falls back to the default cell", function()
			expect(Cells.wantedCell("C2")).to.equal("C2")
			expect(Cells.wantedCell(Grid.DEFAULT_CELL)).to.equal(Grid.DEFAULT_CELL)
			expect(Cells.wantedCell("road")).to.equal(Grid.DEFAULT_CELL)
			expect(Cells.wantedCell(nil)).to.equal(Grid.DEFAULT_CELL)
			expect(Cells.wantedCell("Z9")).to.equal(Grid.DEFAULT_CELL)
			-- THE TRIPWIRE FLIPPED AT TASK 327d, AS THE 337 CASE SAID IT WOULD: the rotation deals
			-- cells, so the fallback is no longer reachable from it. The rest of that proof lives in
			-- "the switch" above.
			expect(Grid.cellOf(Forest.LAYOUT_ORDER[1])).to.be.ok()
			TestKit.note(string.format("wantedCell: rotation deals %s -> no fallback", Forest.LAYOUT_ORDER[1]))
		end)

		-- `plan` IS PURE: two lists and a string in, a plan out. Every branch, with no Instance work
		-- beyond the folders the fixture needs.
		it("plans every branch with no world at all", function()
			local world = Instance.new("Folder")
			local c1 = { cell = "C1", home = Planter.FOREST_FOLDER, folder = world, models = 10 }
			local c2 = { cell = "C2", home = Planter.FOREST_FOLDER, folder = world, models = 20 }
			-- STANDING AND WANTED: kept, nothing written.
			local keep = Cells.plan({ c1, c2 }, {}, "C1")
			expect(keep.keep).to.equal(c1)
			expect(keep.stand).to.equal(nil)
			expect(#keep.store).to.equal(1)
			expect(keep.store[1]).to.equal(c2)
			expect(keep.reason).to.equal(nil)
			-- STORED AND WANTED: it must come out.
			local back = Cells.plan({ c2 }, { c1 }, "C1")
			expect(back.stand).to.equal(c1)
			expect(back.keep).to.equal(nil)
			expect(#back.store).to.equal(1)
			-- NEITHER STANDING NOR STORED: a fact to report, not to plant -- and every OTHER cell is
			-- STILL stored, so the world is left holding no cell folder at all (target T1's extreme,
			-- and what design 15 step 2 asks a live run to show). The design's own 5.3 row says
			-- "nothing written" here; 15 step 2 requires C1 stored, and this follows 15.
			local missing = Cells.plan({ c1 }, {}, "C2")
			expect(missing.reason).to.equal("missing")
			expect(missing.stand).to.equal(nil)
			expect(missing.keep).to.equal(nil)
			expect(#missing.store).to.equal(1)
			-- A NIL MUST NOT EMPTY THE WORLD.
			for _, bad in ipairs({ "road", "Z9" }) do
				local none = Cells.plan({ c1, c2 }, {}, bad)
				expect(none.reason).to.equal("no-cell")
				expect(#none.store).to.equal(0)
				expect(none.keep).to.equal(nil)
			end
			expect(Cells.plan({ c1 }, {}, nil).reason).to.equal("no-cell")
			-- TWO FOLDERS FOR THE WANTED CELL, one per home: Karen's Edit wood stays standing.
			local twin = { cell = "C1", home = Planter.GRID_FOLDER, folder = world, models = 3 }
			local both = Cells.plan({ twin, c1 }, {}, "C1")
			expect(both.keep).to.equal(c1)
			expect(#both.store).to.equal(1)
			expect(both.store[1]).to.equal(twin)
			expect(#both.anomalies).to.equal(1)
			-- A STORE COLLISION IS LOUD AND THE STANDING ONE IS LEFT ALONE.
			local clash = Cells.plan({ c2 }, { c2 }, "C1")
			expect(#clash.store).to.equal(0)
			expect(#clash.anomalies).to.equal(1)
			world:Destroy()
		end)

		-- **DESIGN 11.2 -- IT MOVES, NEVER DESTROYS, AND IT IS LEVEL-TRIGGERED.**
		-- Dies if the store branch calls `Destroy` (the model counts read 0), or if the reconcile
		-- returns early when `want` has not changed (the third call's assertions go red).
		it("stands one cell, stores the rest, and writes nothing when nothing changed", function()
			local world = Instance.new("Folder")
			local store = Instance.new("Folder")
			putCell(world, Planter.FOREST_FOLDER, "C1", 7)
			putCell(world, Planter.FOREST_FOLDER, "C2", 5)
			-- A CHILD THAT IS NOT A CELL FOLDER IS NEVER TOUCHED.
			local stake = Instance.new("Part")
			stake.Name = "NotACell"
			stake.Parent = world:FindFirstChild(Planter.FOREST_FOLDER)

			local first = Cells.reconcile("C1", world, store, nil, false)
			expect(first.stood).to.equal("C1")
			expect(first.stoodModels).to.equal(7)
			expect(first.moved).to.equal(1)
			-- `moved` COUNTS CELLS; `models` IS WHAT THE SLICE MOVED (task 343). Both, so a change
			-- to either number is a red case rather than a quiet rename.
			expect(first.models).to.equal(5)
			expect(first.bites > 0).to.equal(true)
			expect(first.storedCells).to.equal(1)
			expect(first.storedModels).to.equal(5)
			expect(first.reason).to.equal(nil)
			expect(table.concat(names(Cells.standing(world)), " ")).to.equal("C1@" .. Planter.FOREST_FOLDER)
			expect(table.concat(names(Cells.stored(store)), " ")).to.equal("C2@" .. Planter.FOREST_FOLDER)
			expect(stake.Parent).to.equal(world:FindFirstChild(Planter.FOREST_FOLDER))
			-- MOVED, NOT DESTROYED: C2's five models are still its children, and they are now
			-- descendants of the STORE. This is the assertion a `Destroy` cannot pass.
			local stored = Cells.stored(store)[1]
			expect(stored.models).to.equal(5)
			expect(stored.folder:GetChildren()[1]:IsDescendantOf(store)).to.equal(true)
			expect(stored.folder:GetAttribute(Cells.HOME_ATTRIBUTE)).to.equal(Planter.FOREST_FOLDER)

			-- THE SWAP. Both counts survive the round trip, and the cell goes back to its own home.
			local swap = Cells.reconcile("C2", world, store, nil, false)
			expect(swap.stood).to.equal("C2")
			expect(swap.stoodModels).to.equal(5)
			expect(swap.moved).to.equal(2)
			expect(swap.models).to.equal(12)
			expect(table.concat(names(Cells.standing(world)), " ")).to.equal("C2@" .. Planter.FOREST_FOLDER)
			expect(table.concat(names(Cells.stored(store)), " ")).to.equal("C1@" .. Planter.FOREST_FOLDER)
			expect(Cells.stored(store)[1].models).to.equal(7)
			expect(Cells.standing(world)[1].models).to.equal(5)

			-- **LEVEL-TRIGGERED**: the same want again writes nothing and says nothing (target T8).
			local again = Cells.reconcile("C2", world, store, nil, false)
			expect(again.moved).to.equal(0)
			expect(again.models).to.equal(0)
			expect(again.bites).to.equal(0)
			expect(again.stood).to.equal("C2")
			expect(Cells.line(again)).to.equal(nil)
			expect(table.concat(names(Cells.standing(world)), " ")).to.equal("C2@" .. Planter.FOREST_FOLDER)

			-- A WANTED CELL WITH NO WOOD: nothing stands, everything else is stored, and it SAYS so.
			local none = Cells.reconcile("B1", world, store, nil, false)
			expect(none.reason).to.equal("missing")
			expect(none.stood).to.equal(nil)
			expect(#Cells.standing(world)).to.equal(0)
			expect(#Cells.stored(store)).to.equal(2)
			expect(string.find(Cells.line(none) or "", "MISSING") ~= nil).to.equal(true)
			TestKit.note(
				string.format(
					"reconcile: C1(7)/C2(5) -> stand C1, swap to C2, no-op, then B1 MISSING; %d stored",
					#Cells.stored(store)
				)
			)
			world:Destroy()
			store:Destroy()
		end)

		-- **DESIGN 11.3 -- THE TWO NAMES ANSWER DIFFERENTLY where the facts differ.**
		-- Dies if `isStanding` is re-implemented off `Grid.PLANTED_CELLS` -- the exact defect task
		-- 335's verdict names: C2 would then read `true, true` instead of `true, false`.
		it("tells a wood that EXISTS from a wood that is STANDING", function()
			local world = Instance.new("Folder")
			local store = Instance.new("Folder")
			putCell(world, Planter.FOREST_FOLDER, "C1", 2)
			putCell(world, Planter.FOREST_FOLDER, "C2", 2)
			Cells.reconcile("C1", world, store, nil, false)
			-- BOTH CELLS ARE IN `Grid.PLANTED_CELLS`, so the STATIC fact is true of both...
			expect(Plan.hasOwnWood("C1")).to.equal(true)
			expect(Plan.hasOwnWood("C2")).to.equal(true)
			-- ...AND ONLY ONE OF THEM IS STANDING.
			expect(Cells.isStanding("C1", world)).to.equal(true)
			expect(Cells.isStanding("C2", world)).to.equal(false)
			expect(Cells.isStanding("A1", world)).to.equal(false)
			expect(Cells.isStanding(nil, world)).to.equal(false)
			world:Destroy()
			store:Destroy()
		end)

		-- **DESIGN 11.4 -- THE EDIT REFUSAL.** `ServerStorage` is Rojo-owned with the default
		-- `$ignoreUnknownInstances: false`, so a store created in Edit would be DELETED at the next
		-- Connect, and Karen's wood with it. Dies if the guard is removed: the store folder appears.
		it("refuses at Edit time and creates no store", function()
			local world = Instance.new("Folder")
			local store = Instance.new("Folder")
			putCell(world, Planter.FOREST_FOLDER, "C1", 2)
			putCell(world, Planter.FOREST_FOLDER, "C2", 2)
			local refused = Cells.reconcile("C1", world, store, nil, true)
			expect(refused.reason).to.equal("edit-time")
			expect(refused.moved).to.equal(0)
			expect(store:FindFirstChild(Cells.STORE_NAME)).to.equal(nil)
			expect(#Cells.standing(world)).to.equal(2)
			-- AND THE PREDICATE ITSELF IS THE ONE `MapGen.Contract` USES: under the harness we are
			-- in Studio and RUNNING, so it must answer false.
			expect(Cells.editTime()).to.equal(false)
			-- **...AND THE DEFAULT ARM, WHICH IS THE ONLY ONE THE GAME EVER RUNS** (round 1, finding
			-- 1). Both live call sites pass three arguments -- `Cells.reconcile(want, workspace,
			-- ServerStorage)` -- so `clock` and `isEdit` are nil and the refusal is decided by
			-- `Cells.editTime()`. Until this line existed, inverting that default to "refuse unless
			-- told otherwise" left all five cases green and the harness at 34/34 while the game
			-- never reconciled at all. Under the harness `editTime()` is false (asserted above), so
			-- the default arm MUST reconcile.
			local defaulted = Cells.reconcile("C1", world, store, nil, nil)
			expect(defaulted.reason).to.equal(nil)
			expect(defaulted.moved).to.equal(1)
			expect(defaulted.stood).to.equal("C1")
			expect(#Cells.standing(world)).to.equal(1)
			expect(#Cells.stored(store)).to.equal(1)
			world:Destroy()
			store:Destroy()
		end)

		-- **TASK 343 -- THE SWAP GOES IN BITES, STORE BEFORE STAND, AND MOVES NOTHING WHEN QUEUED.**
		-- `cell-loading.md` 12's named fallback for T7, taken because the whole-folder write measured
		-- 738 ms of FRAME in Karen's place against T7's 500 ms (`343-before-swap-C1.txt`).
		--
		-- **IT DIES IF THE SLICE DIES.** Delete the slicing (go back to `wood.folder.Parent = ...`)
		-- and every one of the three assertions below goes red: `begin` would have moved the models
		-- already (so `pending` is 0 and the world is swapped before a single bite), `bites` would be
		-- 1, and the bite-by-bite walk would never see a store-only intermediate state.
		it("swaps a cell in Slice bites, store before stand, and queues without moving", function()
			local Slicer = require(ServerScriptService.Places:WaitForChild("Slice"))
			local world = Instance.new("Folder")
			local store = Instance.new("Folder")
			-- BIG ENOUGH TO NEED MANY BITES at the move cap, so "it was sliced" is not an accident
			-- of a small cell: 2 x `MOVE_MAX_PER_STEP` + 7.
			local n = Slicer.MOVE_MAX_PER_STEP * 2 + 7
			putCell(world, Planter.FOREST_FOLDER, "C1", n)
			putCell(world, Planter.FOREST_FOLDER, "C2", n)
			Cells.reset()
			-- FIRST: stand C1, store C2, so both halves exist in the next swap.
			Cells.reconcile("C1", world, store, nil, false)

			-- **A CLOCK THAT NEVER ADVANCES**, so the time budget can never end a bite and the ITEM
			-- cap is what does -- which is the only way to count bites deterministically.
			local frozen = function()
				return 0
			end
			Cells.reset()
			local queued = Cells.begin("C2", world, store, frozen, false)
			-- (1) **QUEUED AND NOTHING MOVED.** This is what lets the `markers` closure call it from
			-- inside `Match`'s `dispatch`, which may not yield and may not stall for 738 ms.
			expect(queued.pending).to.equal(n * 2)
			expect(queued.models).to.equal(0)
			expect(queued.bites).to.equal(0)
			expect(Cells.pending()).to.equal(n * 2)
			expect(Cells.isStanding("C1", world)).to.equal(true)
			expect(Cells.isStanding("C2", world)).to.equal(false)

			-- (2) **STORE BEFORE STAND.** Walk the bites and watch the world: C1 must be fully gone
			-- from `Workspace` before C2 has put its first model there, so the peak is one cell's
			-- models plus one bite's and never two cells'.
			-- MODELS, NEVER `isStanding`: the emptied shell survives until the queue drains, so the
			-- NAME of a cell in the world is not the question -- how many of its models are.
			local peak, bites, bothHadModels = 0, 0, false
			local done, final = false, nil
			while not done and bites < n * 2 + 4 do
				local _, finished, report = Cells.spend(frozen(), false, frozen)
				done = finished
				final = report or final
				bites += 1
				local inWorld, byCell = 0, {}
				for _, wood in ipairs(Cells.standing(world)) do
					inWorld += wood.models
					byCell[wood.cell] = wood.models
				end
				peak = math.max(peak, inWorld)
				if (byCell.C1 or 0) > 0 and (byCell.C2 or 0) > 0 then
					bothHadModels = true
				end
			end
			expect(done).to.equal(true)
			expect(bothHadModels).to.equal(false)
			-- ONE CELL'S MODELS PLUS ONE BITE, NEVER TWO CELLS'.
			expect(peak <= n + Slicer.MOVE_MAX_PER_STEP).to.equal(true)
			-- (3) **IT TOOK MANY BITES**, which a single `Parent` write cannot do.
			expect(bites > 2).to.equal(true)
			expect((final :: any).bites).to.equal(bites)
			expect((final :: any).models).to.equal(n * 2)
			expect((final :: any).moved).to.equal(2)
			expect((final :: any).unbudgetedSteps).to.equal(0)
			-- ...AND THE WORLD ENDED WHERE IT HAD TO: C2 stands with every model, C1 is in the store
			-- with every model, and no empty shell was left behind to answer "C1 stands".
			expect(table.concat(names(Cells.standing(world)), " ")).to.equal("C2@" .. Planter.FOREST_FOLDER)
			expect(Cells.standing(world)[1].models).to.equal(n)
			expect(table.concat(names(Cells.stored(store)), " ")).to.equal("C1@" .. Planter.FOREST_FOLDER)
			expect(Cells.stored(store)[1].models).to.equal(n)
			expect(Cells.stored(store)[1].folder:GetAttribute(Cells.HOME_ATTRIBUTE)).to.equal(Planter.FOREST_FOLDER)
			TestKit.note(
				string.format(
					"343 swap: %d models in %d bites, peak %d in world (one cell is %d)",
					n * 2,
					bites,
					peak,
					n
				)
			)
			Cells.reset()
			world:Destroy()
			store:Destroy()
		end)

		-- **TASK 343 -- THE DRIVE DOES NOT START MID-SWAP.** Past `Cells.DRAIN_SECONDS` the rest of
		-- the queue is finished in ONE step, so a slow drain cannot bleed past the horn
		-- (`Match.CONFIG.INTERMISSION_SECONDS` is 5 and the drain measures ~1 s).
		--
		-- **IT DIES IF THE DEADLINE ARM DIES**: without `unbudgeted`, one bite leaves `pending > 0`
		-- and `unbudgetedSteps` stays 0, so both halves of this case go red.
		it("finishes the swap in one step once the drain deadline has passed", function()
			local world = Instance.new("Folder")
			local store = Instance.new("Folder")
			local n = 400
			putCell(world, Planter.FOREST_FOLDER, "C1", n)
			putCell(world, Planter.FOREST_FOLDER, "C2", n)
			Cells.reset()
			Cells.reconcile("C1", world, store, nil, false)

			-- A CLOCK THE CASE OWNS, so the deadline is reached by arithmetic and not by waiting.
			local at = 0
			local clock = function()
				return at
			end
			Cells.reset()
			Cells.begin("C2", world, store, clock, false)
			expect(Cells.pending()).to.equal(n * 2)
			-- ONE BUDGETED BITE: still pending, because a bite is bounded.
			local _, done = Cells.spend(clock(), false, clock)
			expect(done).to.equal(false)
			expect(Cells.pending() > 0).to.equal(true)
			-- THE DEADLINE PASSES, and the CALLER sees it the way the Heartbeat does.
			at = Cells.DRAIN_SECONDS + 0.5
			expect(Cells.elapsed(at) >= Cells.DRAIN_SECONDS).to.equal(true)
			local _, finished, report = Cells.spend(clock(), true, clock)
			expect(finished).to.equal(true)
			expect(Cells.pending()).to.equal(0)
			expect((report :: any).unbudgetedSteps > 0).to.equal(true)
			expect((report :: any).models).to.equal(n * 2)
			expect(Cells.isStanding("C2", world)).to.equal(true)
			expect(Cells.isStanding("C1", world)).to.equal(false)
			-- A SECOND `begin` WHILE ONE IS IN FLIGHT IS REFUSED, never a second queue (rule 3).
			Cells.reset()
			putCell(world, Planter.FOREST_FOLDER, "C3", 5)
			Cells.begin("C1", world, store, clock, false)
			local twice = Cells.begin("C1", world, store, clock, false)
			expect(twice.reason).to.equal("in-flight")
			expect(twice.models).to.equal(0)
			Cells.reset()
			world:Destroy()
			store:Destroy()
		end)

		-- THE NAMES AND THE HOMES ARE READ OFF THE PLANTER, never written twice.
		it("names the two homes and the store once", function()
			expect(Cells.STORE_NAME).to.equal("GridWood")
			expect(#Cells.HOMES).to.equal(2)
			expect(Cells.HOMES[1]).to.equal(Planter.FOREST_FOLDER)
			expect(Cells.HOMES[2]).to.equal(Planter.GRID_FOLDER)
			expect(Planter.FOREST_FOLDER).never.to.equal(Planter.GRID_FOLDER)
			-- A STORED CELL IS NOT IN `Workspace`, so no ground ray can stop on it and no
			-- `GROUND_IGNORE` row is needed for the store.
			expect(table.find(Forest.GROUND_IGNORE, Cells.STORE_NAME)).to.equal(nil)
			for _, home in ipairs(Cells.HOMES) do
				expect(table.find(Forest.GROUND_IGNORE, home) ~= nil).to.equal(true)
			end
		end)
	end)

	-- ---------------------------------------------------------------- 20. one name, one fact

	describe("the grid folder's name", function()
		it("is the same fact as the ground-ignore list", function()
			-- SO A PLANTED TREE CAN NEVER ANSWER "WHERE IS THE GROUND" for the next one, and nothing
			-- the preview parents can answer it at all (design 8.4).
			expect(table.find(Forest.GROUND_IGNORE, Planter.GRID_FOLDER) ~= nil).to.equal(true)
			expect(table.find(Forest.GROUND_IGNORE, Planter.FOLDER) ~= nil).to.equal(true)
			expect(Planter.GRID_FOLDER).never.to.equal(Planter.FOLDER)
			-- ...AND THE THIRD FOLDER TOO (task 328g): the prebuilt wood is as able to answer "where
			-- is the ground" wrongly as the preview's, and it is the one that is SAVED WITH THE PLACE.
			expect(table.find(Forest.GROUND_IGNORE, Planter.FOREST_FOLDER) ~= nil).to.equal(true)
			expect(Planter.FOREST_FOLDER).never.to.equal(Planter.GRID_FOLDER)
			expect(Planter.FOREST_FOLDER).never.to.equal(Planter.FOLDER)
			TestKit.note(
				string.format(
					"GROUND_IGNORE carries %s, %s and %s of %d names",
					Planter.FOLDER,
					Planter.GRID_FOLDER,
					Planter.FOREST_FOLDER,
					#Forest.GROUND_IGNORE
				)
			)
		end)
	end)
end
