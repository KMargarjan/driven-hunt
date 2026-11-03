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
				expect(worstRound <= (bend.ewStuds + bend.nsStuds) * q ^ Grid.TO_WORLD_STEPS).to.equal(true)
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
			-- AND THE WALK IS STILL THE CLOCK'S: 1430 / 5.2 inside the 300-second drive less grace.
			local seconds = Grid.CONFIG.cellDepthStuds / Grid.CONFIG.beaterWalkStudsPerSecond
			expect(math.abs(seconds - 275) < 0.1).to.equal(true)
			TestKit.note(
				string.format(
					"%d stations x 2 amplitudes: worst translate error %.2e, worst cell depth error %.2e, walk %.1f s",
					stations,
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
			expect(bulgeZ > roads.main.at + BENT.ewStuds - 0.02).to.equal(true)
			-- A BEATER HALF-WAY UP THE BULGE: 20 studs north of the baseline, 25 SOUTH of his own
			-- post. He is THROUGH against the bent line and NOT through against the straight one --
			-- the two answers disagree, which is what makes this a case and not a restatement.
			local at = Vector3.new(bulgeX, 0, roads.main.at + 20)
			local bent = Match.lineReferenceFor(at, line, fake(BENT))
			expect(math.abs((bent :: Vector3).Z - bulgeZ) < 1e-6).to.equal(true)
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

		it("IS today's world at amplitude zero, value for value", function()
			-- **THIS IS WHAT MAKES THE STRUCTURAL TASK PROVABLY INERT** (design 11.1 case 7). Every
			-- answer below is recomputed from the PRE-328q arithmetic, written out here, and compared
			-- with what the live functions answer at the shipped config.
			local c = Grid.CONFIG
			expect(c.bend.ewStuds).to.equal(0)
			expect(c.bend.nsStuds).to.equal(0)
			local box = Grid.footprint()
			-- 1. THE TWO MAPS ARE THE IDENTITY, exactly -- not to a tolerance.
			for x = box.minX, box.maxX, 97 do
				for z = box.minZ, box.maxZ, 97 do
					local u, v = Grid.toGrid(x, z)
					expect(u).to.equal(x)
					expect(v).to.equal(z)
					local wx, wz = Grid.toWorld(x, z)
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
					local at = Grid.standPosition(id, index)
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
			expect(Grid.flankFirstStuds()).to.equal(340)
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
					expect(math.abs(Plan.roadDistance(x, z) - want) < 1e-9).to.equal(true)
					expect(math.abs(Plan.roadDistanceGrid(x, z) - want) < 1e-9).to.equal(true)
				end
			end
			-- 4. `layoutFor`'s THREE BEND FIELDS ARE THE PRE-328q LITERALS.
			local layout = Grid.layoutFor("C1")
			expect(layout.amplitudeStuds).to.equal(0)
			expect(layout.halfSpanStuds).to.equal(535)
			expect(layout.fieldNorthStuds).to.equal(1472)
			expect(layout.sides.flanks.firstStuds).to.equal(340)
			-- 5. `plantCell` EMITS THE SAME LIST: every row is its own grid point (the map is the
			-- identity) and is clear of the mask asked in EITHER space. C1's plan is 328p's measured
			-- 1,823 and the count is pinned, not reported, because this is the inert gate.
			local drawn = Plan.plantCell("C1")
			expect(#drawn).to.equal(1823)
			for _, item in ipairs(drawn) do
				local u, v = Grid.toGrid(item.x, item.z)
				expect(u).to.equal(item.x)
				expect(v).to.equal(item.z)
				-- THE TWO SPACES AGREE, WHICH IS THE INERT CLAIM. Not "== nil": a SKIRT row is planted
				-- into a neighbour and masked against THAT cell, and asking C1 about it can answer
				-- `corridor` -- which it did, and which is pre-328q semantics and not a bend defect.
				expect(Plan.mask("C1", item.x, item.z)).to.equal(Plan.maskGrid("C1", u, v))
				expect(Plan.mask("C1", item.x, item.z, item.model, item.scale)).to.equal(
					Plan.maskGrid("C1", u, v, item.model, item.scale)
				)
			end
			-- 6. AND `ForestTest.roadZ`'s NEW CELL BRANCH ANSWERS THE LAYOUT'S OWN centre.Z, which is
			-- what the `amplitudeStuds == 0` branch answered before it.
			for x = box.minX, box.maxX, 101 do
				expect(math.abs(Forest.roadZ(x, layout) - layout.centre.Z) < 1e-9).to.equal(true)
			end
			TestKit.note(
				string.format(
					"inert at bend 0: all %d stands of 8 cells exact, %d plantings in C1, both maps the identity",
					8 * Grid.standCount("A1"),
					#drawn
				)
			)
		end)

		it("never reaches the four old places, whose roadZ is still their own sine", function()
			-- BOUNDARY 7 AGAIN, WITH THE NEW BRANCH IN IT (design 11.1 case 8): the cell branch is
			-- FIRST in `roadZ`, so a shipped row that grew `sides` would take it. None has one, and
			-- `forest_stand.spec`'s number-for-number assertions stand because of that.
			for _, name in ipairs(Forest.LAYOUT_ORDER) do
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
			local at = Vector3.new(beaterX, 0, roads.main.at + 200)
			expect(math.abs(flankFirst.X - beaterX) < math.abs(mainEnd.X - beaterX)).to.equal(true)
			-- THE DEFECT, SHOWN FIRST so this case cannot pass with the fix deleted: handed every
			-- post, the reference IS the flank post, 340 studs up the cell.
			local wrong = Match.lineReferenceFor(at, line, fake(Grid.standCount(id)))
			expect(math.abs((wrong :: Vector3).Z - flankFirst.Z) < 1e-6).to.equal(true)
			expect((wrong :: Vector3).Z - roads.main.at >= Grid.flankFirstStuds() - 1e-6).to.equal(true)
			-- ...AND HANDED THE MAIN LINE'S POSTS IT IS THE MAIN POST, ON THE ROAD.
			local right = Match.lineReferenceFor(at, line, fake(Grid.CONFIG.mainStandCount))
			expect(math.abs((right :: Vector3).Z - roads.main.at) < 1e-6).to.equal(true)
			expect(math.abs((right :: Vector3).X - mainEnd.X) < 1e-6).to.equal(true)
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
			expect(math.abs(wrongMiddle.Position.Z - (roads.main.at + Grid.flankFirstStuds())) < 1e-3).to.equal(true)
			-- WHERE THE DEAD ANIMALS ARE LAID OUT (`Match.gatherSpotFor`): behind the middle of the
			-- LINE, on the road, not 340 studs up a flank.
			local behind = Match.CONFIG.SCENE.GATHER_BEHIND_STUDS
			local gather, normal = Match.gatherSpotFor(set, Match.CONFIG)
			expect(gather).to.be.ok()
			expect(math.abs((normal :: Vector3).Z - 1) < 1e-6).to.equal(true)
			expect(math.abs((gather :: Vector3).Z - (roads.main.at - behind)) < 1e-3).to.equal(true)
			expect(math.abs((gather :: Vector3).X - layout.centre.X) < 1e-3).to.equal(true)
			-- ...and it is NOT the flank answer, said as its own assertion so the number that would
			-- have been wrong is named rather than implied.
			expect(math.abs((gather :: Vector3).Z - (wrongMiddle.Position.Z - behind)) > 1).to.equal(true)
			-- WHERE A BEATER WHO IS THROUGH WAITS (`Match.throughSpotFor`), the fifth call site and
			-- the same shape.
			local through = Match.throughSpotFor(set, Match.CONFIG, 0)
			expect(through).to.be.ok()
			local throughBehind = Match.CONFIG.BEATER_THROUGH.BEHIND_STUDS
			expect(math.abs((through :: CFrame).Position.Z - (roads.main.at - throughBehind)) < 1e-3).to.equal(true)
			expect(math.abs((through :: CFrame).Position.X - layout.centre.X) < 1e-3).to.equal(true)
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
			expect(math.abs(span.minX - (layout.centre.X - half)) < 1e-9).to.equal(true)
			expect(math.abs(span.maxX - (layout.centre.X + half)) < 1e-9).to.equal(true)
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
			local id = Grid.PREVIEW_CELL
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

	describe("the preview", function()
		it("stands no part of its own and changes nothing else about the world", function()
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
			local folder = world:FindFirstChild(Planter.GRID_FOLDER)
			expect(folder ~= nil).to.equal(true)
			-- THE 32 CORNER STAKES ARE GONE (task 328m; Karen, 2026-11-03: *"those gates shouldnt
			-- be"*). The folder is the cell wood's parent and nothing else, so a BUILD puts NO part
			-- in it -- and the fields that counted the stakes are gone with them, which is what
			-- stops a later report quietly reintroducing a count nobody reads.
			local ownParts = #folder:GetChildren()
			expect(ownParts).to.equal(0)
			expect((report :: any).gridStakes).to.equal(nil)
			expect((report :: any).gridMissing).to.equal(nil)
			-- IT TAGS NOTHING, BUILDS NO STAND AND NO SEAT, and the layout list does not move: with
			-- the preview on, everything the drive reads answers exactly what it answered before.
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

			-- ...AND WITH IT OFF, NO FOLDER AT ALL. The same call, the same world, one boolean apart.
			local quiet = Instance.new("Folder")
			local off = Planter.build(reader, quiet, terrain, false)
			-- `off.gridPaints` WENT WITH `Ground.paintRoads` (task 328e): the report has no such
			-- field now, because nothing in `src/` paints a grid road.
			expect((off :: any).gridPaints).to.equal(nil)
			expect(quiet:FindFirstChild(Planter.GRID_FOLDER)).to.equal(nil)
			-- THE FOLDER NAME IS ONE FACT with the ground-ignore list, so nothing the preview parents
			-- can ever answer "where is the ground".
			expect(table.find(Forest.GROUND_IGNORE, Planter.GRID_FOLDER) ~= nil).to.equal(true)
			-- A SECOND BUILD REBUILDS RATHER THAN DOUBLING, and an OFF build cleans up an ON one:
			-- design 11.3 step 2's rule, in the direction this task can reach.
			Planter.build(reader, world, terrain, false)
			expect(world:FindFirstChild(Planter.GRID_FOLDER)).to.equal(nil)
			world:Destroy()
			quiet:Destroy()
			TestKit.note(
				string.format(
					"preview on: folder present with %d part(s) of its own, %d layouts before and after; preview off: no folder",
					ownParts,
					#after
				)
			)
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
				-- EVERY CELL HAS AT LEAST ONE CLEARING and none is more than a third clear.
				expect(clear > 0 and clear < 0.34).to.equal(true)
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
						-- IT IS YOUNG GROWTH AND NOT A SECOND CANOPY. Every group in the mix is one
						-- of the two small-tree groups, so a recipe cannot quietly put a second
						-- storey of mature spruce under the first.
						for _, row in ipairs(rows) do
							expect(row.group == "young" or row.group == "birch").to.equal(true)
						end
					end
				end
			end
			-- C1 IS THE ONLY CELL THAT HAS ONE, until Karen has judged it (the recipe says so).
			expect(#withUnder > 0).to.equal(true)
			for _, id in ipairs(withUnder) do
				expect(id).to.equal("C1")
			end

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
			local skirt = 0
			for _, near in ipairs(Plan.neighboursOf("C1")) do
				for _, band in ipairs(Plan.skirtBands("C1", near.id, near.axis, plan)) do
					skirt += cells(band.rect, band.spacing)
				end
			end
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
			local worst, buckets = math.huge, {}
			for _, item in ipairs(trees) do
				local cx, cz = math.floor(item.x / plan.minGapStuds), math.floor(item.z / plan.minGapStuds)
				for dx = -1, 1 do
					for dz = -1, 1 do
						for _, other in ipairs(buckets[(cx + dx) .. ":" .. (cz + dz)] or {}) do
							local ddx, ddz = other.x - item.x, other.z - item.z
							worst = math.min(worst, math.sqrt(ddx * ddx + ddz * ddz))
						end
					end
				end
				local key = cx .. ":" .. cz
				buckets[key] = buckets[key] or {}
				table.insert(buckets[key], item)
			end
			expect(worst >= plan.minGapStuds).to.equal(true)
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
			local id = Grid.PREVIEW_CELL
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
			-- ...AND AT THE PAIR THE DESIGN PUBLISHES (`grid-roads.md` 8.2, `grid-map.md` 19), so a
			-- change to the ratio or to either budget reddens here before it ships undocumented.
			expect(Plan.CELL_PLAN_CAP).to.equal(7260)
			expect(Plan.CELL_PART_CAP).to.equal(2640)
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
					expect(Plan.inLane(item.x, item.z, layout, plan)).to.equal(false)
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
		it("reaches into every neighbour from the shared road and stops at skirtStuds", function()
			local half = Grid.CONFIG.roadClearStuds / 2
			local lines = {}
			for _, id in ipairs(Grid.cellIds()) do
				local plan = Plan.cellPlanFor(id)
				local mine = Grid.boundsOf(id)
				local near = Plan.neighboursOf(id)
				-- A 2 x 4 GRID HAS NO CELL WITH FOUR NEIGHBOURS (design 8.3's skirt row is wrong
				-- about that, lesson L-167): a corner cell has 2 and a middle one 3.
				expect(#near >= 2 and #near <= 3).to.equal(true)
				local count, reach = 0, 0
				local hitEach: { [string]: number } = {}
				for _, item in ipairs(woods[id]) do
					if item.side < 0 then
						count += 1
						-- IT IS OUTSIDE THE ACTIVE CELL...
						local inside = item.x > mine.minX
							and item.x < mine.maxX
							and item.z > mine.minZ
							and item.z < mine.maxZ
						expect(inside).to.equal(false)
						-- ...AND INSIDE EXACTLY ONE NEIGHBOUR, within `skirtStuds` of the road the
						-- two of them share.
						local found = nil
						for _, other in ipairs(near) do
							local box = Grid.boundsOf(other.id)
							if
								item.x >= box.minX
								and item.x <= box.maxX
								and item.z >= box.minZ
								and item.z <= box.maxZ
							then
								expect(found).to.equal(nil)
								found = other
							end
						end
						expect(found ~= nil).to.equal(true)
						hitEach[found.id] = (hitEach[found.id] or 0) + 1
						-- THE DISTANCE FROM THE SHARED ROAD'S OWN CENTRE LINE. The band starts at
						-- the neighbour's inset edge, which is `roadClear / 2 + CELL_EDGE_STUDS`
						-- from that centre, and runs `skirtStuds` further.
						local gap
						if found.axis == "z" then
							local centre = if item.x > mine.maxX then mine.maxX + half else mine.minX - half
							gap = math.abs(item.x - centre)
						else
							local centre = if item.z > mine.maxZ then mine.maxZ + half else mine.minZ - half
							gap = math.abs(item.z - centre)
						end
						expect(gap >= half + Plan.CELL_EDGE_STUDS).to.equal(true)
						expect(gap <= half + Plan.CELL_EDGE_STUDS + plan.skirtStuds).to.equal(true)
						reach = math.max(reach, gap)
						-- AND IT IS THE NEIGHBOUR'S OWN WOOD, not this cell's: the species came from
						-- the zone the point is in over THERE, which is what makes two sections
						-- either side of one road read differently.
						local zoneThere = Plan.zoneAt(found.id, item.x, item.z)
						expect(zoneThere ~= nil).to.equal(true)
						expect(zoneThere.spacingStuds > 0).to.equal(true)
						-- ...THROUGH THE FRONTAGE RULE (task 328f): within 60 studs of a road or a
						-- ride centreline only `frontage.groups` are drawn, so the mix a skirt
						-- planting comes from is the neighbour zone's mix AS THAT RULE LEAVES IT.
						-- `frontageRows` returns the mix unchanged outside the band.
						local theirPlan = Plan.cellPlanFor(found.id)
						local rows = Plan.cellMixNamed(zoneThere.mix)
						if Plan.inFrontage(found.id, item.x, item.z) then
							rows = Plan.frontageRows(theirPlan, rows)
						end
						local names = {}
						for _, row in ipairs(rows) do
							for _, name in ipairs((Plan.SPECIES :: any)[row.group]) do
								names[name] = true
							end
						end
						expect(names[item.model]).to.equal(true)
					end
				end
				-- EVERY NEIGHBOUR IS DRESSED, not just the first one found.
				for _, other in ipairs(near) do
					expect((hitEach[other.id] or 0) > 0).to.equal(true)
				end
				expect(count > 0).to.equal(true)
				table.insert(
					lines,
					string.format("%s %d into %d (reach %.0f/%d)", id, count, #near, reach, plan.skirtStuds)
				)
			end
			TestKit.note("skirt: " .. table.concat(lines, " "))
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
			local id = Grid.PREVIEW_CELL
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

			local id = Grid.PREVIEW_CELL
			local grid = Instance.new("Folder")
			grid.Name = Planter.GRID_FOLDER
			local report = Planter.dressCell(id, grid, hillside, template, nil, nil)
			expect(report.cell).to.equal(id)
			-- THE SAME READER THE DRESS USES (task 328f): `Plan.plantCell`'s relief bias is a pure
			-- function of a height, so a plan made WITHOUT one is a different, equally valid plan --
			-- `woods` above has no reader on purpose, and comparing the two would compare two worlds.
			expect(report.wanted).to.equal(#Plan.plantCell(id, hillside))
			-- ...AND THAT IS NOT A VALUE COMPARED WITH ITSELF (round 1, finding 2): the plan WITH a
			-- reader and the plan without one are different plans, so the line above fails if
			-- `dressCell` stops handing the ground reader through. `woods[id]` is the no-reader one.
			expect(#Plan.plantCell(id, hillside) ~= #woods[id]).to.equal(true)
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

	-- ---------------------------------------------------------------- 20. one name, one fact

	describe("the grid folder's name", function()
		it("is the same fact as the ground-ignore list", function()
			-- SO A PLANTED TREE CAN NEVER ANSWER "WHERE IS THE GROUND" for the next one, and nothing
			-- the preview parents can answer it at all (design 8.4).
			expect(table.find(Forest.GROUND_IGNORE, Planter.GRID_FOLDER) ~= nil).to.equal(true)
			expect(table.find(Forest.GROUND_IGNORE, Planter.FOLDER) ~= nil).to.equal(true)
			expect(Planter.GRID_FOLDER).never.to.equal(Planter.FOLDER)
			TestKit.note(
				string.format(
					"GROUND_IGNORE carries %s and %s of %d names",
					Planter.FOLDER,
					Planter.GRID_FOLDER,
					#Forest.GROUND_IGNORE
				)
			)
		end)
	end)
end
