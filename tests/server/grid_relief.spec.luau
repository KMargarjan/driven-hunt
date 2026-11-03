--!nocheck
-- Task 328c: THE EIGHT LANDFORMS AND THE SHAPING ARITHMETIC -- design docs/design/grid-terrain.md
-- section 13.1. Pure: it runs in DEV, where there is no grid terrain, because `Relief` requires
-- nothing and takes its base as a function.
--
-- Scope `map` (`src/shared/Grid/` -> map), beside `grid.spec.luau`.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	local ServerStorage = game:GetService("ServerStorage")
	local StarterPlayer = game:GetService("StarterPlayer")
	local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
	local Grid = require(ReplicatedStorage:WaitForChild("Grid"))
	local Relief = require(ReplicatedStorage:WaitForChild("Grid"):WaitForChild("Relief"))
	local Golden = require(ServerStorage:WaitForChild("Tests"):WaitForChild("relief_golden"))

	local ROADS = Grid.roads()

	local function flat(_x: number, _z: number): number?
		return 100
	end

	local function xzOf(bounds, u: number, v: number)
		return bounds.minX + u * (bounds.maxX - bounds.minX), bounds.minZ + v * (bounds.maxZ - bounds.minZ)
	end

	-- The nominal bands of design 7.1's road cross-section table, as (near, far) from the centreline.
	local BANDS = {
		{ name = "carriageway", near = -10, far = 10 },
		{ name = "rut east", near = 6, far = 10 },
		{ name = "shoulder", near = 10, far = 20 },
		{ name = "ditch", near = 22, far = 30 },
		{ name = "verge", near = 30, far = 34 },
	}

	describe("Relief: the data", function()
		it("has one landform for each of the eight cells, with every field in range", function()
			local count = 0
			for id, form in Relief.LANDFORMS do
				count += 1
				expect(Grid.cellOf(id)).to.be.ok()
				expect(form.baseKeep >= 0 and form.baseKeep <= 1).to.equal(true)
				expect(#form.ops > 0).to.equal(true)
				expect(type(form.floor.default)).to.equal("string")
				for _, op in form.ops do
					if op.u ~= nil then
						expect(op.u >= 0 and op.u <= 1).to.equal(true)
					end
					if op.v ~= nil then
						expect(op.v >= 0 and op.v <= 1).to.equal(true)
					end
					for _, point in op.via or {} do
						expect(point.u >= 0 and point.u <= 1).to.equal(true)
						expect(point.v >= 0 and point.v <= 1).to.equal(true)
					end
					if op.kind == "bench" then
						expect(op.v1 > op.v0).to.equal(true)
						expect(op.weight > 0 and op.weight <= 1).to.equal(true)
					end
					if op.kind == "bowl" then
						expect(op.flatFraction >= 0 and op.flatFraction < 1).to.equal(true)
					end
				end
			end
			expect(count).to.equal(#Grid.CELL_ORDER)
		end)

		it("ships B2 with a 24-degree scarp and THREE ramps (design 15 item 4)", function()
			local ops = Relief.LANDFORMS.B2.ops
			local scarp, ramps = nil, {}
			for _, op in ops do
				if op.kind == "scarp" then
					scarp = op
				elseif op.kind == "ramp" then
					table.insert(ramps, op.u)
				end
			end
			expect(scarp).to.be.ok()
			expect(scarp.dropStuds).to.equal(28)
			expect(scarp.runStuds).to.equal(64)
			-- 28 over 64 is 23.63 degrees, which is the recipe's 24 to the half-degree.
			expect(math.abs(math.deg(math.atan(28 / 64)) - 24) < 0.5).to.equal(true)
			table.sort(ramps)
			expect(#ramps).to.equal(3)
			expect(ramps[1]).to.equal(0.20)
			expect(ramps[2]).to.equal(0.50)
			expect(ramps[3]).to.equal(0.78)
			-- The scarp carries no trunk, +- 8 studs beyond its own run (design 3.0).
			local band = Relief.LANDFORMS.B2.noTrees[1]
			local depth = 1430
			expect(math.abs((0.24 - band.v0) * depth - 40) < 1).to.equal(true)
			expect(math.abs((band.v1 - 0.24) * depth - 40) < 1).to.equal(true)
		end)

		it("is one fact with Places.Ground.RESOLUTION and MapGen.Config.VOXEL", function()
			local Ground = require(ServerScriptService:WaitForChild("Places"):WaitForChild("Ground"))
			local Config = require(ServerStorage:WaitForChild("MapGen"):WaitForChild("Config"))
			expect(Relief.VOXEL).to.equal(Ground.RESOLUTION)
			expect(Relief.VOXEL).to.equal(Config.VOXEL)
		end)
	end)

	describe("Relief: the arithmetic", function()
		it("matches relief_golden.luau, and the version it was measured at", function()
			expect(Relief.BAKE_VERSION).to.equal(Golden.bakeVersion)
			local checked = 0
			for id, want in Golden.heights do
				local bounds = Grid.boundsOf(id)
				local reader = Golden.readerFor(bounds)
				for i, sample in Golden.samples do
					local x, z = xzOf(bounds, sample.u, sample.v)
					local got = Relief.heightAt(Relief.LANDFORMS[id], bounds, ROADS, reader, x, z)
					if math.abs(got - want[i]) >= 1e-6 then
						TestKit.note(
							string.format(
								"the bake's maths moved: %s sample %d is %.9f, golden %.9f -- re-measure"
									.. " relief_golden.luau and bump Relief.BAKE_VERSION in the same commit",
								id,
								i,
								got,
								want[i]
							)
						)
					end
					expect(math.abs(got - want[i]) < 1e-6).to.equal(true)
					checked += 1
				end
			end
			expect(checked).to.equal(48)
		end)

		it("gives every op a falloff in [0,1] that reaches 0 with no step a voxel could show", function()
			for id, form in Relief.LANDFORMS do
				local bounds = Grid.boundsOf(id)
				for _, op in form.ops do
					if op.kind ~= "scarp" then
						-- WALK OUT OF THE OP'S SUPPORT: across a ridge or trough, along +z out of a bench,
						-- along +x out of anything radial.
						local cx, cz, dx, dz, support
						if op.via then
							local ax, az = xzOf(bounds, op.via[1].u, op.via[1].v)
							local bx, bz = xzOf(bounds, op.via[2].u, op.via[2].v)
							local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
							cx, cz = (ax + bx) / 2, (az + bz) / 2
							dx, dz = -(bz - az) / len, (bx - ax) / len
							support = op.halfWidthStuds
						elseif op.kind == "bench" then
							cx, cz = xzOf(bounds, 0.5, (op.v0 + op.v1) / 2)
							dx, dz = 0, 1
							support = 40
						elseif op.kind == "ramp" then
							cx, cz = xzOf(bounds, op.u, 0.24)
							dx, dz = 1, 0
							support = 16
						else
							cx, cz = xzOf(bounds, op.u, op.v)
							dx, dz = 1, 0
							support = op.rStuds
						end
						-- How many studs the op can move the ground by, so a weight step becomes a height step.
						local reach = math.abs(op.dyStuds or 0)
						for _, point in op.via or {} do
							reach = math.max(reach, math.abs(point.dyStuds))
						end
						if op.kind == "bench" then
							reach = 14 -- D2's 4 per cent over 343 studs, the largest plane-minus-ground
						elseif op.kind == "ramp" then
							reach = 10 -- max |linear - smoothstep| across a 28-stud scarp is 9.2 studs
						end
						local last, zeroAt = nil, nil
						for d = 0, 2000 do
							local w = Relief.weightOf(op, bounds, cx + dx * d, cz + dz * d)
							expect(w >= 0 and w <= 1).to.equal(true)
							if last ~= nil then
								if w == 0 and last > 0 and zeroAt == nil then
									zeroAt = d
									-- 0.001 of weight a stud is the design's figure and the big falloffs meet
									-- it; a 16-stud blend cannot, so what is asserted there is the thing the
									-- figure is FOR: under a quarter stud of height a stud, one voxel over four.
									if support >= 100 then
										expect(last < 0.001).to.equal(true)
									end
									expect(last * reach <= 0.25).to.equal(true)
									break
								end
							end
							last = w
						end
						expect(zeroAt).to.be.ok()
					end
				end
			end
		end)

		it("keeps the road flat: the fade is 0 inside 51 studs of every centreline and 1 at 120", function()
			local function nearestOther(skip, x: number, z: number): number
				local best = math.huge
				for _, road in ROADS do
					if road.id ~= skip then
						local d = if road.axis == "x"
							then math.sqrt((z - road.at) ^ 2 + math.max(road.from - x, x - road.to, 0) ^ 2)
							else math.sqrt((x - road.at) ^ 2 + math.max(road.from - z, z - road.to, 0) ^ 2)
						best = math.min(best, d)
					end
				end
				return best
			end
			local checked = 0
			for _, road in ROADS do
				for step = 0, 10 do
					local along = road.from + (step / 10) * (road.to - road.from)
					local x = if road.axis == "x" then along else road.at
					local z = if road.axis == "x" then road.at else along
					for _, sign in { -1, 1 } do
						local dx = if road.axis == "x" then 0 else sign
						local dz = if road.axis == "x" then sign else 0
						expect(Relief.roadFadeAt(ROADS, x, z)).to.equal(0)
						expect(Relief.roadFadeAt(ROADS, x + dx * 51, z + dz * 51)).to.equal(0)
						-- AT 120 THE FADE IS FULL -- unless a crossing road is nearer, which is the one
						-- thing that may hold it down, and a junction is not a counter-example.
						local fx, fz = x + dx * 120, z + dz * 120
						if nearestOther(road.id, fx, fz) >= 120 then
							expect(Relief.roadFadeAt(ROADS, fx, fz)).to.equal(1)
							checked += 1
						end
					end
				end
			end
			expect(checked > 100).to.equal(true)
			-- **ASKED IN GRID COORDINATES, AND THAT IS WHY `Relief` IS NOT TOUCHED** (task 328q,
			-- design 7.3): in the plane the roads ARE straight at their own `at`, so `roadFadeAt`
			-- becomes curve-correct with no edit. The assertion is the conversion: a WORLD point
			-- within 51 studs of the CURVED centreline lands inside the grid zero band -- driven by
			-- parameter at the amplitude 328r commits, where the two spaces actually differ.
			local converted = 0
			for _, bend in ipairs({
				{ ewStuds = 0, nsStuds = 0, harmonic = 1 },
				{ ewStuds = 45, nsStuds = 60, harmonic = 1 },
			}) do
				for _, road in ROADS do
					for step = 0, 10 do
						local along = road.from + (step / 10) * (road.to - road.from)
						local centre = Grid.roadCentreAt(road, along, bend)
						for _, sign in { -1, 1 } do
							for _, offset in { 0, 25, 50 } do
								local x = if road.axis == "x" then along else centre + sign * offset
								local z = if road.axis == "x" then centre + sign * offset else along
								local u, v = Grid.toGrid(x, z, bend)
								expect(Relief.roadFadeAt(ROADS, u, v)).to.equal(0)
								converted += 1
							end
						end
					end
				end
			end
			expect(converted).to.equal(2 * #ROADS * 11 * 2 * 3)
			TestKit.note(
				string.format(
					"%d world points within 51 st of a centreline, at bend 0 and 45/60, all inside the grid zero band",
					converted
				)
			)
		end)

		it("gives B2 a 28-stud scarp over 64 studs and three ramps at 15 per cent", function()
			local form, bounds = Relief.LANDFORMS.B2, Grid.boundsOf("B2")
			local zc = bounds.minZ + 0.24 * (bounds.maxZ - bounds.minZ)
			-- OFF the ramps, between the u .50 and .78 ones.
			local xOff = bounds.minX + 0.64 * (bounds.maxX - bounds.minX)
			local drop = Relief.heightAt(form, bounds, ROADS, flat, xOff, zc - 32)
				- Relief.heightAt(form, bounds, ROADS, flat, xOff, zc + 32)
			expect(math.abs(drop - 28) < 3).to.equal(true)
			-- EACH RAMP, over the part of its run the bench has already let go of, so the measurement
			-- is the ramp's own grade and not the plateau's 2 per cent riding on it.
			local run = 28 / 0.15
			local from = bounds.minZ + 0.22 * (bounds.maxZ - bounds.minZ)
			local to = zc + run / 2
			for _, u in { 0.20, 0.50, 0.78 } do
				local x = bounds.minX + u * (bounds.maxX - bounds.minX)
				local fall = Relief.heightAt(form, bounds, ROADS, flat, x, from)
					- Relief.heightAt(form, bounds, ROADS, flat, x, to)
				expect(math.abs(fall / (to - from) * 100 - 15) < 1).to.equal(true)
			end
		end)

		it("makes every bench a PLANE at its own weight times its own grade", function()
			-- Design 13.1 case 4's bench half, over a flat base: inside the band where the bench's own
			-- weight is 1 AND the road fade is 1, `heightAt` must rise at exactly
			-- weight * gradePercent / 100 studs a stud, and that gradient must not vary -- which is what
			-- makes it a plane rather than a bulge.
			local benches = 0
			for _, id in Grid.CELL_ORDER do
				local form, bounds = Relief.LANDFORMS[id], Grid.boundsOf(id)
				for _, op in form.ops do
					if op.kind == "bench" then
						benches += 1
						-- u .64 is clear of A1's gully and of all three of B2's ramps, so what is
						-- measured here is the bench and nothing else sharing the column.
						local x = bounds.minX + 0.64 * (bounds.maxX - bounds.minX)
						local want = op.weight * op.gradePercent / 100
						local lo, hi, slopes = nil, nil, {}
						for z = bounds.minZ, bounds.maxZ, 4 do
							if
								Relief.weightOf(op, bounds, x, z) == 1
								and Relief.weightOf(op, bounds, x, z + 4) == 1
								and Relief.roadFadeAt(ROADS, x, z) == 1
								and Relief.roadFadeAt(ROADS, x, z + 4) == 1
							then
								local here = Relief.heightAt(form, bounds, ROADS, flat, x, z)
								local next4 = Relief.heightAt(form, bounds, ROADS, flat, x, z + 4)
								lo = lo or z
								hi = z + 4
								table.insert(slopes, (next4 - here) / 4)
							end
						end
						expect(#slopes >= 8).to.equal(true)
						local first = slopes[1]
						for _, slope in slopes do
							-- A PLANE: one gradient, not a family of them.
							expect(math.abs(slope - first) < 1e-9).to.equal(true)
							-- ...and it is the recipe's own grade, to a hundredth of a per cent.
							expect(math.abs(slope - want) < 0.0001).to.equal(true)
						end
						-- Crest minus floor across the measured span, within 3 studs of the recipe.
						local rise = Relief.heightAt(form, bounds, ROADS, flat, x, hi)
							- Relief.heightAt(form, bounds, ROADS, flat, x, lo)
						expect(math.abs(rise - want * (hi - lo)) < 3).to.equal(true)
						TestKit.note(
							string.format(
								"grid_relief bench: %s v %.2f-%.2f rises %.3f studs over %d, %.4f st/st against %.4f",
								id,
								op.v0,
								op.v1,
								rise,
								hi - lo,
								first,
								want
							)
						)
					end
				end
			end
			expect(benches).to.equal(3)
		end)

		it("is the base again outside the footprint, past BLEND_STUDS", function()
			for id, form in Relief.LANDFORMS do
				local bounds = Grid.boundsOf(id)
				for _, point in
					{
						{ bounds.minX - Relief.BLEND_STUDS, bounds.minZ - Relief.BLEND_STUDS },
						{ bounds.maxX + Relief.BLEND_STUDS, bounds.maxZ + Relief.BLEND_STUDS },
						{ (bounds.minX + bounds.maxX) / 2, bounds.maxZ + Relief.BLEND_STUDS + 300 },
					}
				do
					local got = Relief.heightAt(form, bounds, ROADS, flat, point[1], point[2])
					expect(math.abs(got - 100) < 1e-9).to.equal(true)
				end
			end
		end)
	end)

	describe("Relief: the slope limiter", function()
		-- A SYNTHETIC CLIFF: 400 studs of flat, a 40-stud drop over 20, then flat again.
		local function cliff(): { number }
			local out = {}
			for i = 1, 200 do
				local z = (i - 1) * 4
				out[i] = if z < 400 then 100 elseif z > 420 then 60 else 100 - 40 * (z - 400) / 20
			end
			return out
		end

		local function worst(column: { number }): number
			local most = 0
			for i = 1, #column - 4 do
				most = math.max(most, math.abs(column[i + 4] - column[i]))
			end
			return math.deg(math.atan(most / 16))
		end

		it("brings every 16-stud window onto the ceiling, at both ceilings", function()
			expect(worst(cliff()) > 50).to.equal(true)
			for _, ceilingDeg in { Relief.LIMIT_DEG.tree, Relief.LIMIT_DEG.open } do
				local once = Relief.limitPass(cliff(), 4, ceilingDeg)
				local twice = Relief.limitPass(once, 4, ceilingDeg)
				TestKit.note(
					string.format(
						"grid_relief limiter: 63.4 deg cliff -> %.2f after 8 passes, %.2f after 16, ceiling %d",
						worst(once),
						worst(twice),
						ceilingDeg
					)
				)
				-- The eight relaxation passes alone leave this cliff at 22.92 degrees; the finishing
				-- min-cone clamp is what lands it ON the ceiling. The 0.5 is slack for the float, not
				-- for convergence (MEASURED, task 328c).
				expect(worst(once) <= ceilingDeg + 0.5).to.equal(true)
			end
		end)

		it("holds every cell's own column under the ceiling, clear of the pins", function()
			-- THE LANDFORMS THEMSELVES, not a synthetic: one 4-stud column a cell at u .64 (off
			-- B2's ramps), plus one through B2's middle ramp, over a flat base so what is measured
			-- is the landform and nothing else.
			local lines = {}
			for _, id in Grid.CELL_ORDER do
				table.insert(lines, { id = id, u = 0.64 })
			end
			table.insert(lines, { id = "B2", u = 0.50 })
			for _, line in lines do
				local form, bounds = Relief.LANDFORMS[line.id], Grid.boundsOf(line.id)
				local relief = Grid.cellOf(line.id).relief
				-- ...and over a base built from THIS cell's own measured `relief` row: a plane from
				-- `lineMeanY` rising the measured spread over the cell's depth. The repo holds four
				-- summary numbers a cell and no height field, so this is consistent-with-measured,
				-- not the measured ground -- the bake reads the real snapshot (design 5.3 step 2).
				local function measured(_x: number, z: number): number?
					return relief.lineMeanY + (z - bounds.minZ) / (bounds.maxZ - bounds.minZ) * relief.spreadStuds
				end
				local x = bounds.minX + line.u * (bounds.maxX - bounds.minX)
				local column, exempt, n = {}, {}, 0
				local onMeasured = {}
				for z = bounds.minZ, bounds.maxZ, 4 do
					n += 1
					column[n] = Relief.heightAt(form, bounds, ROADS, flat, x, z)
					onMeasured[n] = Relief.heightAt(form, bounds, ROADS, measured, x, z)
					exempt[n] = Relief.isExempt(form, bounds, x, z)
				end
				for _, ceilingDeg in { Relief.LIMIT_DEG.tree, Relief.LIMIT_DEG.open } do
					local out = Relief.limitPass(onMeasured, 4, ceilingDeg, exempt)
					local most = 0
					for i = 1, n - 4 do
						if not (exempt[i] or exempt[i + 4]) then
							most = math.max(most, math.abs(out[i + 4] - out[i]))
						end
					end
					local deg = math.deg(math.atan(most / 16))
					TestKit.note(
						string.format(
							"grid_relief slope: %s u=%.2f worst %.2f deg on the measured base, ceiling %d",
							line.id,
							line.u,
							deg,
							ceilingDeg
						)
					)
					expect(deg <= ceilingDeg + 0.01).to.equal(true)
				end
				for _, ceilingDeg in { Relief.LIMIT_DEG.tree, Relief.LIMIT_DEG.open } do
					local out = Relief.limitPass(column, 4, ceilingDeg, exempt)
					local most = 0
					for i = 1, n - 4 do
						if not (exempt[i] or exempt[i + 4]) then
							most = math.max(most, math.abs(out[i + 4] - out[i]))
						end
					end
					local deg = math.deg(math.atan(most / 16))
					TestKit.note(
						string.format(
							"grid_relief slope: %s u=%.2f worst %.2f deg clear of pins, ceiling %d",
							line.id,
							line.u,
							deg,
							ceilingDeg
						)
					)
					expect(deg <= ceilingDeg + 0.01).to.equal(true)
				end
			end
		end)

		it("leaves a pinned band exactly where it was", function()
			local exempt = {}
			for i = 95, 110 do
				exempt[i] = true
			end
			local before = cliff()
			local after = Relief.limitPass(before, 4, Relief.LIMIT_DEG.tree, exempt)
			for i = 95, 110 do
				expect(after[i]).to.equal(before[i])
			end
			-- ...and B2's scarp and ramps are what `isExempt` pins in the world.
			local bounds = Grid.boundsOf("B2")
			local zc = bounds.minZ + 0.24 * (bounds.maxZ - bounds.minZ)
			local xOff = bounds.minX + 0.64 * (bounds.maxX - bounds.minX)
			expect(Relief.isExempt(Relief.LANDFORMS.B2, bounds, xOff, zc)).to.equal(true)
			expect(Relief.isExempt(Relief.LANDFORMS.B2, bounds, xOff, zc + 300)).to.equal(false)
			-- A ramp's strip is pinned further, because its run is longer than the scarp's.
			local xRamp = bounds.minX + 0.50 * (bounds.maxX - bounds.minX)
			expect(Relief.isExempt(Relief.LANDFORMS.B2, bounds, xRamp, zc + 80)).to.equal(true)
			expect(Relief.isExempt(Relief.LANDFORMS.C1, Grid.boundsOf("C1"), xOff, zc)).to.equal(false)
		end)
	end)

	describe("Relief: the voxel grid", function()
		it("emits tiles that are already aligned to the voxel grid", function()
			local box = Grid.footprint()
			local region = {
				minX = box.minX - 430,
				maxX = box.maxX + 430,
				minZ = box.minZ - 430,
				maxZ = box.maxZ + 430,
			}
			local tiles = Relief.tiles(region, 128)
			expect(#tiles > 0).to.equal(true)
			local maxX, maxZ = -math.huge, -math.huge
			for _, tile in tiles do
				expect(tile.minX % Relief.VOXEL).to.equal(0)
				expect(tile.minZ % Relief.VOXEL).to.equal(0)
				maxX = math.max(maxX, tile.minX + 128)
				maxZ = math.max(maxZ, tile.minZ + 128)
			end
			expect(128 % Relief.VOXEL).to.equal(0)
			-- It covers the region, outward.
			expect(tiles[1].minX <= region.minX).to.equal(true)
			expect(tiles[1].minZ <= region.minZ).to.equal(true)
			expect(maxX >= region.maxX).to.equal(true)
			expect(maxZ >= region.maxZ).to.equal(true)
			TestKit.note(string.format("grid_relief: the bake's region is %d tiles of 128 studs", #tiles))
		end)

		it("emits tiles the MEASURED voxel ceiling can carry, from MapGen.Config's own numbers", function()
			-- EVERY NUMBER HERE COMES FROM A SHIPPED MODULE. `MapGen.Config.VOXEL`'s header carries the
			-- measurement (2026-09-26): WriteVoxels takes a 128 x 128 x 96-stud region at resolution 4,
			-- which is 32 x 32 x 24 = 24,576 voxels, and refuses any other resolution.
			local Config = require(ServerStorage:WaitForChild("MapGen"):WaitForChild("Config"))
			local tiles = Relief.tiles(Grid.footprint(), Config.TILE_STUDS)
			expect(#tiles > 0).to.equal(true)
			local columns = Config.TILE_STUDS / Config.VOXEL
			local layers = (Config.BAND_Y.max - Config.BAND_Y.min) / Config.VOXEL
			expect(columns).to.equal(32)
			expect(columns * columns * layers).to.equal(24576)
			-- So a tile of this stride carries at most this many studs of Y band in ONE call.
			expect(layers * Config.VOXEL).to.equal(96)
			-- And every tile `Relief.tiles` emits sits on that stride, so none is wider than the call.
			for _, tile in tiles do
				expect((tile.minX - tiles[1].minX) % Config.TILE_STUDS).to.equal(0)
				expect((tile.minZ - tiles[1].minZ) % Config.TILE_STUDS).to.equal(0)
			end
			expect(Relief.VOXEL).to.equal(Config.VOXEL)
		end)

		it("turns every nominal band into whole voxel columns, whatever the centre's parity", function()
			for _, band in BANDS do
				local width = nil
				for parity = 0, 3 do
					local centre = -6700 + parity
					local lo, hi = Relief.columnsFor(centre, band.near, band.far)
					expect(lo % Relief.VOXEL).to.equal(0)
					expect(hi % Relief.VOXEL).to.equal(0)
					expect(hi - lo >= band.far - band.near).to.equal(true)
					-- THE WIDTH MAY NOT DEPEND ON THE PARITY: that is the defect `bandBounds` exists
					-- for (design 7.1 correction F-2).
					width = width or (hi - lo)
					expect(hi - lo).to.equal(width)
				end
				expect(width).to.equal(math.max(1, math.ceil((band.far - band.near) / Relief.VOXEL)) * Relief.VOXEL)
			end
		end)

		it("snaps the band to whole WORLD columns AT EVERY STATION along a bend (task 328q)", function()
			-- CORRECTION F-2 KEPT AND EXTENDED (design 7.2): the BAND snaps, never the centre, so the
			-- ditch and the rut stay whole columns everywhere -- at the cost of a 4-stud lateral
			-- stair every 31.5 studs along a bend, which is one voxel and the lattice's own
			-- resolution. Driven by parameter at the amplitude 328r commits, where the centre
			-- actually moves between stations.
			local bends = { { ewStuds = 0, nsStuds = 0, harmonic = 1 }, { ewStuds = 45, nsStuds = 60, harmonic = 1 } }
			local road = Grid.roadsOf("C1").main
			for _, bend in ipairs(bends) do
				local steps, phases = 0, {}
				for i = 0, 49 do
					local along = road.from + (road.to - road.from) * i / 49
					local centre = Grid.roadCentreAt(road, along, bend)
					for _, band in BANDS do
						local lo, hi = Relief.columnsFor(centre, band.near, band.far)
						expect(lo % Relief.VOXEL).to.equal(0)
						expect(hi % Relief.VOXEL).to.equal(0)
						-- THE WIDTH NEVER CHANGES, whatever the station's phase: one band is one
						-- width, which is correction F-2's whole point.
						expect(hi - lo).to.equal(
							math.max(1, math.ceil((band.far - band.near) / Relief.VOXEL)) * Relief.VOXEL
						)
					end
					phases[tostring(math.floor(centre) % Relief.VOXEL)] = true
					steps += 1
				end
				expect(steps).to.equal(50)
				-- AND AT THE BENT AMPLITUDE THE CENTRE REALLY DOES CROSS THE LATTICE, which is the
				-- stair: all four residues mod 4 are visited, where a straight road only ever has one.
				local seen = 0
				for _ in phases do
					seen += 1
				end
				expect(seen).to.equal(if bend.ewStuds == 0 then 1 else 4)
			end
			-- THE STAIR'S PITCH IS DERIVED, NOT TRANSCRIBED: `VOXEL / tan(swing)`.
			local stair = Grid.bendFacts("x", bends[2]).stairStuds
			expect(stair > 31 and stair < 32).to.equal(true)
			TestKit.note(
				string.format("50 stations x 2 amplitudes: whole columns everywhere, stair pitch %.2f studs", stair)
			)
		end)
	end)

	describe("Relief: the epoch and the floor", function()
		it("encodes canonically, and moves only when a number moves", function()
			local once = Relief.epochInput(Relief.LANDFORMS, Grid.CONFIG)
			expect(once).to.equal(Relief.epochInput(Relief.LANDFORMS, Grid.CONFIG))
			expect(string.find(once, " ")).to.equal(nil)
			-- Key order is sorted, not insertion order: `bakeVersion` then `config` then `landforms`.
			expect(string.sub(once, 1, 14)).to.equal('{"bakeVersion"')
			expect(string.find(once, '"config"', 1, true) < string.find(once, '"landforms"', 1, true)).to.equal(true)
			-- A changed landform number changes it; a differently ORDERED config does not.
			-- A table built key by key in a DIFFERENT order encodes the same, which is what
			-- `table.sort(keys)` in `canonical` is for.
			local moved: { [string]: any } = {}
			for _, key in
				{ "columns", "rows", "roadClearStuds", "cellDepthStuds", "cellWidthStuds", "originZ", "originX" }
			do
				moved[key] = Grid.CONFIG[key]
			end
			moved.bend = Grid.CONFIG.bend
			expect(Relief.epochInput(Relief.LANDFORMS, moved)).to.equal(once)
			-- **THE THREE BEND ROWS ARE IN THE HASH, AND THEY ARE WHAT FORCES THE RE-BAKE** (task
			-- 328q, defect F-2): without them the epoch would not move when the road did, `PlantEpoch`
			-- would still match and the census would certify a forest standing on moved ground.
			expect(string.find(once, '"bendEwStuds":0', 1, true) ~= nil).to.equal(true)
			expect(string.find(once, '"bendNsStuds":0', 1, true) ~= nil).to.equal(true)
			expect(string.find(once, '"bendHarmonic":1', 1, true) ~= nil).to.equal(true)
			for _, row in { "ewStuds", "nsStuds", "harmonic" } do
				local bent: { [string]: any } = table.clone(Grid.CONFIG.bend)
				bent[row] = (bent[row] :: number) + 1
				moved.bend = bent
				expect(Relief.epochInput(Relief.LANDFORMS, moved)).never.to.equal(once)
			end
			-- AND A MISSING `bend` IS A NAMED REFUSAL, not a silently short hash.
			moved.bend = nil
			expect(pcall(Relief.epochInput, Relief.LANDFORMS, moved)).to.equal(false)
			moved.bend = Grid.CONFIG.bend
			expect(Relief.epochInput(Relief.LANDFORMS, moved)).to.equal(once)
			-- **THE PYTHON TWIN'S FIXTURE, RE-CAPTURED FROM THIS ENCODER** (task 328q, defect F-5):
			-- `tools/terrainbake.py`'s `CANONICAL_FIXTURE_OUTPUT` is the string below, and its
			-- `selftest` compares its own encoder against it. Printed here so the capture is a
			-- reading off the Luau and not a retyping.
			local fixture = Relief.epochInput({
				Z1 = {
					baseKeep = 0.5,
					floor = { default = "Ground", mudDepthStuds = 6 },
					ops = { { dyStuds = -2.5, kind = "dome", rStuds = 10, u = 0.25, v = 0.75 } },
				},
			}, moved)
			TestKit.note("grid_relief: epochInput fixture = " .. fixture)
			moved.originX = Grid.CONFIG.originX + 4
			expect(Relief.epochInput(Relief.LANDFORMS, moved)).never.to.equal(once)
			local forms = { A1 = { baseKeep = 0.6, ops = {}, floor = { default = "Ground" } } }
			local before = Relief.epochInput(forms, Grid.CONFIG)
			forms.A1.baseKeep = 0.61
			expect(Relief.epochInput(forms, Grid.CONFIG)).never.to.equal(before)
		end)

		it("answers the floor rules SWARM section 2.2 states, and nothing else", function()
			local b2 = Relief.LANDFORMS.B2
			expect(Relief.materialAt(b2, Grid.boundsOf("B2"), nil, 10, 0, 0, 0)).to.equal("LeafyGrass")
			expect(Relief.materialAt(b2, Grid.boundsOf("B2"), nil, 35, 0, 0, 0)).to.equal("Rock")
			expect(Relief.materialAt(b2, Grid.boundsOf("B2"), nil, 45, 0, 0, 0)).to.equal("LeafyGrass")
			local d1 = Relief.LANDFORMS.D1
			expect(Relief.materialAt(d1, Grid.boundsOf("D1"), nil, 0, 5.9, 0, 0)).to.equal("Grass")
			expect(Relief.materialAt(d1, Grid.boundsOf("D1"), nil, 0, 6, 0, 0)).to.equal("Mud")
		end)
	end)

	describe("Relief: nothing in src/ writes terrain (design 1.2 item 1)", function()
		it("drives all eight landforms and changes not one voxel of the place", function()
			local terrain = workspace.Terrain
			local before = terrain:CountCells()
			local region = Region3.new(Vector3.new(0, 0, 0), Vector3.new(128, 128, 128)):ExpandToGrid(4)
			local wasMaterial, wasOccupancy = terrain:ReadVoxels(region, 4)
			for id, form in Relief.LANDFORMS do
				local bounds = Grid.boundsOf(id)
				for u = 0, 1, 0.1 do
					for v = 0, 1, 0.1 do
						local x, z = xzOf(bounds, u, v)
						Relief.heightAt(form, bounds, ROADS, flat, x, z)
						Relief.materialAt(form, bounds, nil, 12, 1, x, z)
					end
				end
			end
			expect(terrain:CountCells()).to.equal(before)
			local nowMaterial, nowOccupancy = terrain:ReadVoxels(region, 4)
			local checked = 0
			for i = 1, #wasMaterial do
				for j = 1, #wasMaterial[i] do
					for k = 1, #wasMaterial[i][j] do
						expect(nowMaterial[i][j][k]).to.equal(wasMaterial[i][j][k])
						expect(nowOccupancy[i][j][k]).to.equal(wasOccupancy[i][j][k])
						checked += 1
					end
				end
			end
			expect(checked > 0).to.equal(true)
		end)

		it("finds no WriteVoxels under src/, and only the two writers section 1.2 item 1 names", function()
			-- THE INSTRUMENT FIRST. `Source` needs PluginSecurity and a spec runs below it, so the
			-- scan is only worth anything if a script with known source reads back non-empty.
			local probe = ReplicatedStorage:WaitForChild("Grid"):WaitForChild("Relief")
			local ok, text = pcall(function()
				return (probe :: any).Source
			end)
			local readable = ok and type(text) == "string" and #text > 0
			TestKit.note(
				"grid_relief source scan: Script.Source is " .. (if readable then "readable" else "UNREADABLE")
			)
			if not readable then
				-- NOT a silent pass: the behavioural case above is what proves this path writes
				-- nothing, and the whole-repo scan is `tools/privacy_scan.py`'s kind of job, on disk.
				expect(readable).to.equal(false)
				return
			end
			-- The two the design names as untouched: the lobby field and the four line places' strips.
			-- The three real terrain writers under src/, each one design 1.2 item 1 leaves alone: the
			-- lobby field, the four line places, and the range ground.
			local ALLOWED = {
				["ServerScriptService.Lobby.Field"] = true,
				["ServerScriptService.Places.Ground"] = true,
				["ServerScriptService.Range.Build"] = true,
			}
			local offenders = {}
			for _, root in
				{ ServerScriptService, ReplicatedStorage, StarterPlayer:WaitForChild("StarterPlayerScripts") }
			do
				for _, inst in root:GetDescendants() do
					if inst:IsA("LuaSourceContainer") and not inst:IsDescendantOf(ServerStorage) then
						local got = select(
							2,
							pcall(function()
								return (inst :: any).Source
							end)
						)
						if type(got) == "string" then
							-- THE CALL SHAPE, not the name: each of these appears in a comment
							-- somewhere, and a comment is not a writer.
							local writes = string.find(got, ":WriteVoxels(", 1, true)
								or string.find(got, ":FillBlock(", 1, true)
								or string.find(got, ":ReplaceMaterial(", 1, true)
							if writes and not ALLOWED[inst:GetFullName()] then
								table.insert(offenders, inst:GetFullName())
							end
						end
					end
				end
			end
			if #offenders > 0 then
				TestKit.note("grid_relief: terrain is written under src/ by " .. table.concat(offenders, ", "))
			end
			expect(#offenders).to.equal(0)
		end)
	end)
	-- ---------------------------------------------------------------- task 328d: the bake
	--
	-- PURE PARTS ONLY. `snapshot` and `bakeTile`'s write touch `Terrain`, which this place has none
	-- of for the grid; everything that decides a shape is a function, and is cased here.
	describe("the bake (task 328d)", function()
		local TerrainBake = require(ServerStorage:WaitForChild("TerrainBake"))

		it("328d-1 aims at Karen's Forest Test and not at DEV", function()
			expect(TerrainBake.PLACE_ID).to.equal(130094961655666)
			expect(TerrainBake.PLACE_ID).never.to.equal(game.PlaceId)
		end)

		it("328q-1 leaves every junction pin exactly where it was, at any amplitude", function()
			-- EACH ROAD'S LINE IS A ZERO OF THE OTHER FAMILY'S BEND (design 5.1), so the 15 pinned
			-- junction heights do not move when the amplitude does. Asserted because the pins are
			-- what hold the two crowns together inside the junction square.
			local function sloped(_x: number, z: number): number?
				return 120 + z / 100
			end
			local profiles = {}
			for _, road in Grid.roads() do
				local profile = TerrainBake.longProfile(road, sloped)
				if profile ~= nil then
					table.insert(profiles, profile)
				end
			end
			expect(#profiles).to.equal(8)
			local ew = {}
			for _, profile in profiles do
				if profile.road.axis == "x" then
					table.insert(ew, profile)
				end
			end
			local pinned = 0
			for _, profile in profiles do
				if profile.road.axis == "z" then
					local pins = TerrainBake.junctionPins(profile.road, ew)
					expect(#pins).to.equal(3)
					for _, pin in pins do
						-- THE PIN'S STATION IS AN EAST-WEST ROAD'S OWN `at`, and `bendX` is exactly 0
						-- there, so the pin is at the junction in the WORLD as well as in the grid.
						expect(math.abs(Grid.bendX(pin.along) - 0) < 1e-12).to.equal(true)
						pinned += 1
					end
				end
			end
			expect(pinned).to.equal(15)
			TestKit.note(string.format("%d junction pins, every station an exact zero of the other family", pinned))
		end)

		it("328q-2 cuts the SAME cross-section along a bend: same widths, same materials", function()
			-- THE SECTION IS MOVED, NOT RESHAPED (design 11.3): `roadAt` reads the centre from
			-- `Grid.roadCentreAt` and every band, material and crown fall below it is unchanged.
			--
			-- **WHAT THIS CASE CAN AND CANNOT DO, SAID PLAINLY:** `roadAt` reads `Grid.CONFIG.bend`
			-- and takes no amplitude, so at the shipped 0 the centre IS `road.at` and this is the
			-- INERT gate -- it catches a station-dependent regression (a wrong `bestAlong`, a band
			-- built from the wrong side) and it does NOT prove the section on a real curve. That is
			-- measured in 328r, off the baked ground, and is declared unproven here until then.
			local function level(_x: number, _z: number): number?
				return 120
			end
			local road = Grid.roadsOf("C1").main
			local profile = TerrainBake.longProfile(road, level)
			expect(profile ~= nil).to.equal(true)
			local profiles = { profile }
			local spec = TerrainBake.ROAD
			local reference: { string } = {}
			local stations = 0
			for i = 0, 39 do
				-- INSIDE C1's OWN SPAN, away from the world's ends and from any crossing road, so the
				-- junction-square rule is not what this case is reading.
				local cell = Grid.boundsOf("C1")
				local along = cell.minX + 80 + (cell.maxX - 80 - (cell.minX + 80)) * i / 39
				local centre = Grid.roadCentreAt(road, along)
				local section: { string } = {}
				for d = 0, spec.vergeStuds + 8, 2 do
					local y, name = TerrainBake.roadAt(profiles, 120, along, centre + d)
					table.insert(section, string.format("%s/%.3f", tostring(name), (y or 0) - 120))
				end
				if #reference == 0 then
					reference = section
				else
					for k, value in ipairs(section) do
						expect(value).to.equal(reference[k])
					end
				end
				stations += 1
			end
			expect(stations).to.equal(40)
			expect(#reference > 10).to.equal(true)
			-- AND THE SECTION IS NOT EMPTY: the carriageway, the rut, the ditch and the verge are all
			-- in it, or the comparison above would be forty copies of nothing.
			local materials: { [string]: boolean } = {}
			for _, value in ipairs(reference) do
				materials[string.match(value, "^[^/]+") :: string] = true
			end
			expect(materials[spec.material[road.axis].mid]).to.equal(true)
			expect(materials[spec.material[road.axis].ditch]).to.equal(true)
			expect(materials[spec.material[road.axis].verge]).to.equal(true)
			TestKit.note(
				string.format("%d stations, %d samples a section, identical band for band", stations, #reference)
			)
		end)

		it("328d-2 covers one cell with its roads plus the blend, and the whole world plus 430", function()
			local one = TerrainBake.regionFor({ "C1" })
			local cell = Grid.boundsOf("C1")
			local roads = Grid.roadsOf("C1")
			-- THE NUMBERS, not a re-spelling of the body: C1 plus its four road corridors plus the
			-- 200-stud blend is this box, and a change to any of the three reddens the line.
			expect(one.minX).to.equal(-4701)
			expect(one.maxX).to.equal(-3097)
			expect(one.minZ).to.equal(-5353)
			expect(one.maxZ).to.equal(-3389)
			expect(one.minX).to.equal(
				math.min(cell.minX, roads.west.at - TerrainBake.ROAD_HALF_STUDS) - Relief.BLEND_STUDS
			)
			expect(one.maxZ).to.equal(
				math.max(cell.maxZ, roads.muster.at + TerrainBake.ROAD_HALF_STUDS) + Relief.BLEND_STUDS
			)
			local all = TerrainBake.regionFor(Grid.cellIds())
			local box = Grid.footprint()
			-- The border wood's 230 on top of the blend's 200: design 5.2's "footprint plus 430 st".
			expect(box.minX - all.minX).to.equal(Relief.BLEND_STUDS + 230)
			expect(all.maxX - box.maxX).to.equal(Relief.BLEND_STUDS + 230)
		end)

		it("328d-3 tiles both regions on the voxel lattice, and the counts are the arithmetic's", function()
			local one = TerrainBake.tilePlan(TerrainBake.regionFor({ "C1" }))
			local all = TerrainBake.tilePlan(TerrainBake.regionFor(Grid.cellIds()))
			TestKit.note(string.format("bake tiles: C1 %d, the whole world %d", #one, #all))
			expect(#one).to.equal(208)
			expect(#all).to.equal(1333)
			expect(TerrainBake.TILE_STUDS % Relief.VOXEL).to.equal(0)
			for _, tile in one do
				expect(tile.minX % Relief.VOXEL).to.equal(0)
				expect(tile.minZ % Relief.VOXEL).to.equal(0)
			end
		end)

		it("328d-4 splits the Y band so no call passes the measured voxel ceiling", function()
			local columns = (TerrainBake.TILE_STUDS / Relief.VOXEL) ^ 2
			local short = TerrainBake.bandsFor(100, 140)
			expect(#short).to.equal(1)
			-- 16 below + 40 + 32 above = 88 studs, inside one call, and voxel-aligned.
			expect(short[1].min).to.equal(84)
			expect(short[1].max % Relief.VOXEL).to.equal(0)
			local tall = TerrainBake.bandsFor(0, 250)
			expect(#tall > 1).to.equal(true)
			for _, band in tall do
				expect(columns * ((band.max - band.min) / Relief.VOXEL) <= TerrainBake.MAX_VOXELS).to.equal(true)
			end
			-- The bands abut and cover the whole span, so no slice of ground is left unwritten.
			expect(tall[1].min).to.equal(-16)
			expect(tall[#tall].max).to.equal(284)
			for i = 2, #tall do
				expect(tall[i].min).to.equal(tall[i - 1].max)
			end
		end)

		it("328d-5 blends ONCE, and the one fade is the arithmetic's own", function()
			-- THE 328d DECISION, and round-1 finding 7: round 1 multiplied the bake's fade onto
			-- `heightAt`'s cell-edge `k`, which is two fades in series. The weight is handed in now.
			local union = TerrainBake.unionOf({ "C1" })
			local cell = Grid.boundsOf("C1")
			expect(union.minX).to.equal(cell.minX)
			expect(TerrainBake.blendAt(union, (cell.minX + cell.maxX) / 2, (cell.minZ + cell.maxZ) / 2)).to.equal(1)
			expect(TerrainBake.blendAt(union, cell.minX - Relief.BLEND_STUDS, cell.minZ + 10)).to.equal(0)
			local half = TerrainBake.blendAt(union, cell.minX - Relief.BLEND_STUDS / 2, cell.minZ + 10)
			expect(half > 0).to.equal(true)
			expect(half < 1).to.equal(true)
			-- ONE FADE: the handed-in weight scales the whole shaping term, linearly, and 0 gives
			-- the base back exactly. Two fades in series would not be linear in the weight.
			local form = Relief.LANDFORMS.C1
			local x, z = (cell.minX + cell.maxX) / 2, cell.minZ + 0.30 * (cell.maxZ - cell.minZ)
			local full = Relief.heightAt(form, cell, ROADS, flat, x, z, 1)
			local part = Relief.heightAt(form, cell, ROADS, flat, x, z, 0.25)
			local none = Relief.heightAt(form, cell, ROADS, flat, x, z, 0)
			expect(none).to.equal(flat(x, z))
			expect(math.abs((part - none) - 0.25 * (full - none)) < 1e-9).to.equal(true)
			TestKit.note(string.format("one fade: full %+.3f, quarter %+.3f over the base", full - none, part - none))
			-- AND THE CASE THAT BITES, which one cell cannot show: baking C1 AND C2 makes the road
			-- between them full strength, where each cell's own `k` fades it.
			local pair = TerrainBake.unionOf({ "C1", "C2" })
			local between = Grid.roadsOf("C1").main.at
			local lone = TerrainBake.blendAt(union, (cell.minX + cell.maxX) / 2, between)
			expect(TerrainBake.blendAt(pair, (cell.minX + cell.maxX) / 2, between)).to.equal(1)
			expect(lone < 1).to.equal(true)
		end)

		it("328d-6 runs the slope limiter on BOTH axes, and neither pass survives deletion", function()
			-- THE 328d DECISION. Round 1 asserted a grid flat in z, so the z direction passed before
			-- any pass ran and the x loop could be deleted unnoticed (round-1 finding 5).
			local n, pitch = 16, 4
			local ceiling = Relief.LIMIT_DEG.tree
			local limit = 16 * math.tan(math.rad(ceiling))
			local window = math.max(1, math.floor(16 / pitch + 0.5))
			local function worstIn(g, axis: string): number
				local worst = 0
				for i = 1, n do
					for k = 1, n do
						local bi = if axis == "x" then i + window else i
						local bk = if axis == "x" then k else k + window
						if bi <= n and bk <= n then
							worst = math.max(worst, math.abs(g[(bk - 1) * n + bi] - g[(k - 1) * n + i]))
						end
					end
				end
				return worst
			end
			-- STEEP IN BOTH AXES: 45 degrees each way, so deleting either loop leaves its own axis
			-- over the ceiling and this case red.
			local grid = table.create(n * n, 0)
			for i = 1, n do
				for k = 1, n do
					grid[(k - 1) * n + i] = (i + k) * 4
				end
			end
			expect(worstIn(grid, "x") > limit).to.equal(true)
			expect(worstIn(grid, "z") > limit).to.equal(true)
			local both = TerrainBake.limitGrid(grid, n, n, pitch, ceiling)
			TestKit.note(
				string.format(
					"limiter: ceiling %.2f st per 16; the input holds %.2f in x and %.2f in z, both axes leave %.2f / %.2f",
					limit,
					worstIn(grid, "x"),
					worstIn(grid, "z"),
					worstIn(both, "x"),
					worstIn(both, "z")
				)
			)
			expect(worstIn(both, "x") <= limit + 1e-6).to.equal(true)
			expect(worstIn(both, "z") <= limit + 1e-6).to.equal(true)
			-- AND THE EXEMPT MASK is read on BOTH passes: pin a whole column and it does not move.
			local exempt = table.create(n * n, false)
			for k = 1, n do
				exempt[(k - 1) * n + 8] = true
			end
			local pinned = TerrainBake.limitGrid(grid, n, n, pitch, ceiling, exempt)
			for k = 1, n do
				expect(pinned[(k - 1) * n + 8]).to.equal(grid[(k - 1) * n + 8])
			end
		end)

		it("328d-7 gives every point one owning cell, and the nearest on a road", function()
			local cell = Grid.boundsOf("C1")
			local c2 = Grid.boundsOf("C2")
			expect(TerrainBake.cellAt({ "C1", "C2" }, (cell.minX + cell.maxX) / 2, (cell.minZ + cell.maxZ) / 2)).to.equal(
				"C1"
			)
			expect(TerrainBake.cellAt({ "C1", "C2" }, (c2.minX + c2.maxX) / 2, (c2.minZ + c2.maxZ) / 2)).to.equal("C2")
			-- On the road between them the nearer bound wins, and neither point is left unowned.
			local onRoad = TerrainBake.cellAt({ "C1", "C2" }, (cell.minX + cell.maxX) / 2, Grid.roadsOf("C1").main.at)
			expect(onRoad == "C1" or onRoad == "C2").to.equal(true)
		end)

		it("328d-8 names the landforms whose base reads leave the tile, from the data", function()
			-- A `bench` walks the base over its v band (`Relief.applyOps`), which one tile's slice
			-- does not hold, so `bakeTileAt` refuses it. The cells are named by the data, not here.
			local benched, plain = {}, {}
			for _, id in Grid.cellIds() do
				table.insert(if TerrainBake.readsWholeCell(Relief.LANDFORMS[id]) then benched else plain, id)
			end
			TestKit.note(
				"bake: benched cells " .. table.concat(benched, ",") .. "; tile-local " .. table.concat(plain, ",")
			)
			expect(#benched).to.equal(3)
			expect(TerrainBake.readsWholeCell(Relief.LANDFORMS.C1)).to.equal(false)
			expect(TerrainBake.readsWholeCell(Relief.LANDFORMS.B2)).to.equal(true)
			-- THE PAD a tile needs covers BOTH readers that leave the tile: the limiter's margin
			-- and the blur's cutoff, plus one voxel so the outermost sample has a neighbour.
			expect(TerrainBake.padFor()).to.equal(
				Relief.VOXEL
					* math.ceil(
						(TerrainBake.LIMIT_MARGIN_STUDS + Relief.BLUR.cutoffStuds + Relief.VOXEL) / Relief.VOXEL
					)
			)
			expect(TerrainBake.padFor() >= TerrainBake.LIMIT_MARGIN_STUDS + Relief.BLUR.cutoffStuds).to.equal(true)
			expect(TerrainBake.padFor() % Relief.VOXEL).to.equal(0)
			TestKit.note(
				string.format(
					"bake pad %d st = limiter margin %d + blur cutoff %d + one voxel",
					TerrainBake.padFor(),
					TerrainBake.LIMIT_MARGIN_STUDS,
					Relief.BLUR.cutoffStuds
				)
			)
		end)

		it("328d-9 reads the snapshot inside it and nil outside it", function()
			local slice = {
				pitch = Relief.VOXEL,
				minX = 0,
				minZ = 0,
				nx = 4,
				nz = 4,
				height = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 },
				material = {},
				minY = 1,
				maxY = 16,
			}
			local read = TerrainBake.readerFor(slice)
			expect(read(2, 2)).to.equal(1)
			expect(read(14, 14)).to.equal(16)
			expect(read(-2, 2)).to.equal(nil)
			expect(read(2, 20)).to.equal(nil)
		end)

		it("328d-10 surveys by 327a's own classifier, through a seam with no terrain in it", function()
			local flatRow = TerrainBake.survey("C1", function()
				return 120
			end)
			expect(flatRow.cell).to.equal("C1")
			expect(flatRow.spreadStuds).to.equal(0)
			expect(flatRow.character).to.equal("flat")
			expect(flatRow.meanY).to.equal(120)
			expect(flatRow.lineMeanY).to.equal(120)
			local bounds = Grid.boundsOf("C1")
			local ridgeRow = TerrainBake.survey("C1", function(_x: number, z: number)
				return 100 + (z - bounds.minZ) / (bounds.maxZ - bounds.minZ) * 80
			end)
			expect(ridgeRow.spreadStuds > 60).to.equal(true)
			expect(ridgeRow.character).to.equal("ridge")
			expect(ridgeRow.samples > 0).to.equal(true)
		end)

		it("328d-11 puts no code commit in the epoch input, and the bake version in it", function()
			local a = TerrainBake.epochInputFor("aaaa")
			expect(a).never.to.equal(TerrainBake.epochInputFor("bbbb"))
			expect(string.sub(a, 1, 4)).to.equal("aaaa")
			-- The version is the tail. A maths change that forgets to bump it changes nothing here,
			-- and `relief_golden` is what catches that (design 5.4).
			expect(string.sub(a, -#tostring(Relief.BAKE_VERSION))).to.equal(tostring(Relief.BAKE_VERSION))
			expect(TerrainBake.epochInputFor("aaaa")).to.equal(a)
			expect(string.find(a, "commit", 1, true)).to.equal(nil)
			-- AND THE LANDFORM DIGEST IS IN IT. Round 1 asserted the sha and the version only, so
			-- dropping `Relief.epochInput` from the input left every expectation green.
			expect(string.find(a, "landforms", 1, true)).never.to.equal(nil)
			expect(string.find(a, "C1", 1, true)).never.to.equal(nil)
			expect(string.find(a, "scarp", 1, true)).never.to.equal(nil)
			expect(#a > 2000).to.equal(true)
		end)

		it("328d-12 measures a slope in degrees off the shaped grid", function()
			local n, pitch = 8, 4
			local grid = table.create(n * n, 0)
			for i = 1, n do
				for k = 1, n do
					grid[(k - 1) * n + i] = i * pitch -- 45 degrees in x
				end
			end
			expect(math.abs(TerrainBake.slopeAt(grid, n, 4, 4, pitch) - 45) < 0.001).to.equal(true)
			expect(TerrainBake.slopeAt(table.create(n * n, 7), n, 4, 4, pitch)).to.equal(0)
		end)

		it("328d-13 leaves ServerStorage's Edit-time terrain writers at exactly two", function()
			-- The scan above walks ServerScriptService, ReplicatedStorage and StarterPlayerScripts and
			-- SKIPS ServerStorage, so this bounds the hole that skip leaves rather than widening it.
			local EDIT_TIME = {
				["ServerStorage.MapGen.Ground"] = true,
				["ServerStorage.TerrainBake"] = true,
			}
			local readable = type(select(
				2,
				pcall(function()
					return (script :: any).Source
				end)
			)) == "string"
			TestKit.note(
				"328d-13 source scan: Script.Source is "
					.. (
						if readable
							then "readable, so the scan below ran"
							else "UNREADABLE, so this case proved nothing"
					)
			)
			if not readable then
				expect(readable).to.equal(false)
				return
			end
			local offenders = {}
			for _, inst in ServerStorage:GetDescendants() do
				if inst:IsA("LuaSourceContainer") then
					local got = select(
						2,
						pcall(function()
							return (inst :: any).Source
						end)
					)
					if type(got) == "string" and string.find(got, ":WriteVoxels(", 1, true) then
						if not EDIT_TIME[inst:GetFullName()] then
							table.insert(offenders, inst:GetFullName())
						end
					end
				end
			end
			if #offenders > 0 then
				TestKit.note("328d-13: terrain is written in ServerStorage by " .. table.concat(offenders, ", "))
			end
			expect(#offenders).to.equal(0)
		end)

		-- A SYNTHETIC SNAPSHOT, so the thing that decides the ground can be asserted with no terrain
		-- in the world: the same shape `TerrainBake.snapshot` returns, filled from a function.
		local function sliceFor(tile, heightOf): any
			local pad = TerrainBake.padFor()
			local side = TerrainBake.TILE_STUDS
			local v = Relief.VOXEL
			local minX, minZ = tile.minX - pad, tile.minZ - pad
			local n = (side + 2 * pad) / v
			local slice = {
				pitch = v,
				minX = minX,
				minZ = minZ,
				nx = n,
				nz = n,
				height = table.create(n * n, 0),
				material = table.create(n * n, "Ground"),
				minY = math.huge,
				maxY = -math.huge,
			}
			for i = 1, n do
				for k = 1, n do
					local y = heightOf(minX + (i - 0.5) * v, minZ + (k - 0.5) * v)
					slice.height[(k - 1) * n + i] = y
					slice.minY = math.min(slice.minY, y)
					slice.maxY = math.max(slice.maxY, y)
				end
			end
			return slice
		end

		it("328d-14 clamps the road's long profile, and says so when it has to relax", function()
			-- Design 7.1: 8 % east-west, 10 % north-south, <= 2 % change per 50 st, cut-or-fill
			-- <= 12 st, and a breach relaxes the grade ON THAT ROAD and is printed, never hidden.
			local road = Grid.roadsOf("C1").main
			local spec = TerrainBake.ROAD
			-- A SAWTOOTH the clamp has to flatten: +-6 studs every 20, which is 30 %.
			local n = 0
			local profile = TerrainBake.longProfile(road, function(x: number, _z: number)
				n += 1
				return 100 + (if math.floor((x - road.from) / spec.sampleStuds) % 2 == 0 then 6 else -6)
			end)
			expect(profile).never.to.equal(nil)
			local worst = 0
			for i = 2, #profile.y do
				worst = math.max(worst, math.abs(profile.y[i] - profile.y[i - 1]))
			end
			local allowed = profile.gradePercent / 100 * spec.sampleStuds
			TestKit.note(
				string.format(
					"road %s: %d samples, worst step %.3f st per %d (allowed %.3f at %d %%), cut-or-fill %.2f, relaxed=%s",
					road.id,
					#profile.y,
					worst,
					spec.sampleStuds,
					allowed,
					profile.gradePercent,
					profile.worstCutFill,
					tostring(profile.relaxed)
				)
			)
			-- FAIL FIRST: the input holds 12-stud steps, 30 %, and the clamp is 8 %.
			expect(12 > spec.gradePercent.x / 100 * spec.sampleStuds).to.equal(true)
			expect(worst <= allowed + 1e-6).to.equal(true)
			expect(profile.worstCutFill <= spec.cutFillStuds[road.axis] + 1e-6).to.equal(true)
			-- A north-south road gets the 10 % clamp, not the east-west 8 %.
			local flank = TerrainBake.longProfile(Grid.roadsOf("C1").west, function()
				return 100
			end)
			expect(spec.gradePercent[flank.road.axis]).to.equal(10)
			expect(spec.gradePercent[profile.road.axis]).to.equal(8)
			expect(flank.relaxed).to.equal(false)
		end)

		it("328d-15 cuts design 7.1's cross-section, in whole voxel columns", function()
			local road = Grid.roadsOf("C1").main
			local spec = TerrainBake.ROAD
			local profiles = TerrainBake.profilesFor({ "C1" }, flat)
			local mid = (Grid.boundsOf("C1").minX + Grid.boundsOf("C1").maxX) / 2
			local function at(d: number)
				return TerrainBake.roadAt(profiles, 100, mid, road.at + d)
			end
			-- THE CARRIAGEWAY is level across, with the crown fall under the design's half-stud.
			local crown = at(0)
			local edge = at(spec.carriagewayStuds)
			expect(crown).never.to.equal(nil)
			expect(math.abs((crown - edge) - spec.crownFallStuds) < 1e-9).to.equal(true)
			expect(2 * spec.crownFallStuds <= 0.5).to.equal(true)
			-- THE RUTS AND THE DITCH are the realised whole-column bounds, at the centre's own
			-- parity (correction F-2): ONE column of rut and TWO of ditch, ON EACH SIDE. Round 2
			-- built the minus side's bounds negative, so |d| could never reach them and that whole
			-- half of every road in the world came out flat Grass (round-2 finding 1).
			local rutLo, rutHi = TerrainBake.bandFor(road.at, spec.rut.nearStuds, spec.rut.farStuds, 1)
			local ditchLo, ditchHi = TerrainBake.bandFor(road.at, spec.ditch.nearStuds, spec.ditch.farStuds, 1)
			local mRutLo, mRutHi = TerrainBake.bandFor(road.at, spec.rut.nearStuds, spec.rut.farStuds, -1)
			local mDitchLo, mDitchHi = TerrainBake.bandFor(road.at, spec.ditch.nearStuds, spec.ditch.farStuds, -1)
			local rutNear, rutFar = road.at + rutLo, road.at + rutHi
			local ditchNear, ditchFar = road.at + ditchLo, road.at + ditchHi
			-- THE REALISED WIDTH, pinned: the rut is ONE voxel column and the ditch is TWO, both
			-- sides (328c note: `% VOXEL == 0` was weaker than the sentence above it).
			expect(rutHi - rutLo).to.equal(Relief.VOXEL)
			expect(mRutHi - mRutLo).to.equal(Relief.VOXEL)
			expect(ditchHi - ditchLo).to.equal(2 * Relief.VOXEL)
			expect(mDitchHi - mDitchLo).to.equal(2 * Relief.VOXEL)
			-- WHOLE COLUMNS IN ABSOLUTE COORDINATES on each side, which is what F-2 asks for.
			expect((road.at + rutLo) % Relief.VOXEL).to.equal(0)
			expect((road.at - mRutHi) % Relief.VOXEL).to.equal(0)
			expect((road.at + ditchLo) % Relief.VOXEL).to.equal(0)
			expect((road.at - mDitchHi) % Relief.VOXEL).to.equal(0)
			-- As symmetric as a centre at = 1 (mod 4) allows: half a voxel apart, never more.
			expect(math.abs((rutLo + rutHi) / 2 - (mRutLo + mRutHi) / 2) <= Relief.VOXEL / 2).to.equal(true)
			expect(math.abs((ditchLo + ditchHi) / 2 - (mDitchLo + mDitchHi) / 2) <= Relief.VOXEL / 2).to.equal(true)
			local _, rutName = at((rutLo + rutHi) / 2)
			expect(rutName).to.equal("Mud")
			-- THE HEIGHT IS SYMMETRIC EXACTLY wherever the two sides' bands agree: the carriageway
			-- and the verge depend on |d| alone, and the two ditches overlap over d 21..27.
			for _, d in { 1, 7, 13, 17, 23, 25, 31 } do
				expect(math.abs((at(d) or 0) - (at(-d) or 0)) < 1e-9).to.equal(true)
			end
			-- AND WHERE THEY CANNOT: the bands are half a voxel apart (a centre at = 1 mod 4 admits
			-- no better), so d 29 is still ditch on the minus side and already verge on the plus
			-- side. Said here rather than left for someone to find in the ground. The carriageway
			-- test comes first, so the plus ditch is realised over d 21..27 and the minus over
			-- 21..29 -- two sampled columns each, which is design 7.1's "two whole columns".
			expect(math.abs((at(29) or 0) - (at(-29) or 0)) > 1).to.equal(true)
			-- FAIL FIRST, THE MINUS SIDE: before the fix `at(-d)` answered Grass at the verge
			-- height for every one of these, because the band bounds there were negative.
			local _, mRutName = at(-(mRutLo + mRutHi) / 2)
			expect(mRutName).to.equal("Mud")
			local mDitchY, mDitchName = at(-(mDitchLo + mDitchHi) / 2)
			expect(mDitchName).to.equal("Mud")
			expect(math.abs((crown - mDitchY) - spec.ditch.depthStuds) < 1e-9).to.equal(true)
			local ditchY, ditchName = at((ditchLo + ditchHi) / 2)
			TestKit.note(
				string.format(
					"road %s at %d: rut columns [%d,%d] d %.0f..%.0f, ditch [%d,%d] d %.0f..%.0f, ditch %.2f st below the crown",
					road.id,
					road.at,
					rutNear,
					rutFar,
					rutNear - road.at,
					rutFar - road.at,
					ditchNear,
					ditchFar,
					ditchNear - road.at,
					ditchFar - road.at,
					crown - ditchY
				)
			)
			TestKit.note(
				string.format(
					"road %s MINUS side: rut d %.0f..%.0f abs [%d,%d], ditch d %.0f..%.0f abs [%d,%d], %.2f st below the crown",
					road.id,
					mRutLo,
					mRutHi,
					road.at - mRutHi,
					road.at - mRutLo,
					mDitchLo,
					mDitchHi,
					road.at - mDitchHi,
					road.at - mDitchLo,
					crown - mDitchY
				)
			)
			expect(ditchName).to.equal("Mud")
			expect(math.abs((crown - ditchY) - spec.ditch.depthStuds) < 1e-9).to.equal(true)
			-- THE VERGE is the shoulder, and past the bank the road owns nothing.
			local _, vergeName = at(spec.vergeStuds - 1)
			expect(vergeName).to.equal("Grass")
			local beyond = at(spec.vergeStuds + spec.bankMinStuds + 1)
			expect(beyond).to.equal(nil)
			-- THE BANK is never steeper than 1:2. Drop the natural ground 30 studs and the bank has
			-- to widen past its 12-stud minimum rather than fall faster.
			local steepY, _, weight = TerrainBake.roadAt(profiles, 70, mid, road.at + spec.vergeStuds + 20)
			expect(steepY).never.to.equal(nil)
			expect(weight > 0).to.equal(true)
			expect(steepY > 70).to.equal(true)
			expect(TerrainBake.roadAt(profiles, 70, mid, road.at + spec.vergeStuds + 70)).to.equal(nil)
			-- An east-west carriageway is Ground in the middle; a north-south one is Grass.
			local _, midName = at(0)
			expect(midName).to.equal(spec.material.x.mid)
			expect(spec.material.z.mid).to.equal("Grass")
		end)

		it("328d-16 shapes a whole tile: the road is cut into it, and the ditch is in the ground", function()
			local tile = { minX = -4352, minZ = -5120 } -- holds EW2 at z = -5107
			local road = Grid.roadsOf("C1").main
			local spec = TerrainBake.ROAD
			local slice = sliceFor(tile, flat)
			local profiles = TerrainBake.profilesFor({ "C1" }, flat)
			local heights, names, n = TerrainBake.shapeTile(tile, slice, { "C1" }, {}, profiles)
			expect(n).to.equal(TerrainBake.TILE_STUDS / Relief.VOXEL)
			expect(#heights).to.equal(n * n)
			local function kFor(z: number): number
				return math.floor((z - tile.minZ) / Relief.VOXEL) + 1
			end
			local function h(z: number): number
				return heights[(kFor(z) - 1) * n + 16]
			end
			local function name(z: number): string
				return names[(kFor(z) - 1) * n + 16]
			end
			local ditchLo, ditchHi = TerrainBake.bandFor(road.at, spec.ditch.nearStuds, spec.ditch.farStuds, 1)
			local mDitchLo, mDitchHi = TerrainBake.bandFor(road.at, spec.ditch.nearStuds, spec.ditch.farStuds, -1)
			local crownZ = road.at + 1
			local ditchZ = road.at + (ditchLo + ditchHi) / 2
			local mDitchZ = road.at - (mDitchLo + mDitchHi) / 2
			local awayZ = tile.minZ + TerrainBake.TILE_STUDS - 2
			TestKit.note(
				string.format(
					"tile (%d,%d) over a flat 100 base: crown %.3f (%s), ditch %.3f (%s), 125 st away %.3f (%s)",
					tile.minX,
					tile.minZ,
					h(crownZ),
					name(crownZ),
					h(ditchZ),
					name(ditchZ),
					h(awayZ),
					name(awayZ)
				)
			)
			-- THE DITCH IS CUT: 2 studs below the crown, as Mud, in the ground the tile writes.
			expect(math.abs(h(crownZ) - 100) < 0.25).to.equal(true)
			expect(name(crownZ)).to.equal("Ground")
			expect(math.abs(h(ditchZ) - (h(crownZ) - spec.ditch.depthStuds)) < 0.05).to.equal(true)
			expect(name(ditchZ)).to.equal("Mud")
			-- THE OTHER SIDE OF THE CENTRELINE. The road sits 13 studs above this tile's floor, so
			-- the minus RUT is in this tile and the minus DITCH is in the one below -- which is also
			-- what proves the two tiles agree: the ditch in the SOUTH tile is 2 studs under the
			-- crown THIS tile wrote, at the same x, because both were handed the same profiles.
			local mRutLo, mRutHi = TerrainBake.bandFor(road.at, spec.rut.nearStuds, spec.rut.farStuds, -1)
			local mRutZ = road.at - (mRutLo + mRutHi) / 2
			-- FAIL FIRST, BOTH OF THESE: before round 3 the minus side had no rut and no ditch, so
			-- this read "Ground" at the carriageway height and "Grass" at the verge height.
			expect(name(mRutZ)).to.equal("Mud")
			-- SYMMETRIC IN HEIGHT, to within the sample lattice: the voxel centres fall at odd |d|
			-- on each side and the two sides' odd numbers differ by 2, so the nearest pair to +-12 is
			-- d 13 and d 11 -- 0.02 st of crossfall apart. The exact claim is 328d-15's, on `roadAt`.
			expect(math.abs(h(road.at + 12) - h(road.at - 12)) < 0.05).to.equal(true)
			local south = { minX = tile.minX, minZ = tile.minZ - TerrainBake.TILE_STUDS }
			local southHeights, southNames = TerrainBake.shapeTile(south, sliceFor(south, flat), { "C1" }, {}, profiles)
			local function southAt(z: number): (number, string)
				local k = math.floor((z - south.minZ) / Relief.VOXEL) + 1
				return southHeights[(k - 1) * n + 16], southNames[(k - 1) * n + 16]
			end
			local mDitchY, mDitchName = southAt(mDitchZ)
			TestKit.note(
				string.format(
					"MINUS side: rut z=%.0f (d=%.0f) %s in tile (%d,%d); ditch z=%.0f (d=%.0f) %.3f (%s) in tile (%d,%d), crown %.3f",
					mRutZ,
					road.at - mRutZ,
					name(mRutZ),
					tile.minX,
					tile.minZ,
					mDitchZ,
					road.at - mDitchZ,
					mDitchY,
					mDitchName,
					south.minX,
					south.minZ,
					h(crownZ)
				)
			)
			expect(mDitchName).to.equal("Mud")
			expect(math.abs(mDitchY - (h(crownZ) - spec.ditch.depthStuds)) < 0.05).to.equal(true)
			-- THE TWO TILES SHARE THE ROAD at the seam: the last column of the south tile and the
			-- first of this one are 4 studs apart and the road is continuous across them (round-2
			-- finding 2 -- with a profile read per tile, off half-baked ground, it would not be).
			-- d 15 and d 11, so 0.04 st of crossfall is expected and anything more is a step.
			local seamSouth = southAt(tile.minZ - 2)
			local seamHere = h(tile.minZ + 2)
			expect(math.abs(seamSouth - seamHere) < 0.1).to.equal(true)
			-- FAIL FIRST: with no profiles handed in there is no road, and the ditch is not there.
			local bare = TerrainBake.shapeTile(tile, slice, { "C1" }, {}, nil)
			expect(math.abs(bare[(kFor(ditchZ) - 1) * n + 16] - 100) < 0.05).to.equal(true)
			-- Past the bank the road owns nothing and the landform does.
			expect(math.abs(h(awayZ) - 100) < 1.0).to.equal(true)
		end)

		it("328d-17 limits across a tile seam, which a tile-local limiter cannot", function()
			-- ROUND-1 FINDING 2. Two tiles of one continuous over-steep slope must meet without a
			-- step, and every 16-stud window THAT STRADDLES THE SEAM must be under the ceiling.
			local a = { minX = -4352, minZ = -5120 }
			local b = { minX = -4352, minZ = -4992 }
			local function ramp(_x: number, z: number): number
				return 100 + (z + 5324) * 0.6 -- ~31 degrees, well over the 20-degree tree ceiling
			end
			local profiles = TerrainBake.profilesFor({ "C1" }, ramp)
			local heightsA, _, n = TerrainBake.shapeTile(a, sliceFor(a, ramp), { "C1" }, {}, profiles)
			local heightsB = TerrainBake.shapeTile(b, sliceFor(b, ramp), { "C1" }, {}, profiles)
			local column = table.create(2 * n, 0)
			for k = 1, n do
				column[k] = heightsA[(k - 1) * n + 16]
				column[n + k] = heightsB[(k - 1) * n + 16]
			end
			local window = math.floor(16 / Relief.VOXEL + 0.5)
			local ceiling = 16 * math.tan(math.rad(Relief.LIMIT_DEG.tree))
			local worst, worstAt, worstSeam = 0, 0, 0
			for i = 1, #column - window do
				local step = math.abs(column[i + window] - column[i])
				if step > worst then
					worst, worstAt = step, i
				end
				if i > n - window and i <= n then
					worstSeam = math.max(worstSeam, step)
				end
			end
			TestKit.note(
				string.format(
					"seam at column %d of %d: worst 16-st window %.3f at %d, worst window ACROSS the seam %.3f, ceiling %.3f",
					n,
					#column,
					worst,
					worstAt,
					worstSeam,
					ceiling
				)
			)
			-- The input is far over the ceiling, so this is not a case that passes on its input.
			expect(0.6 * 16 > ceiling).to.equal(true)
			expect(worstSeam <= ceiling + 1e-6).to.equal(true)
			expect(worst <= ceiling + 1e-6).to.equal(true)
		end)

		it("328d-18 keeps the ground where the snapshot has no answer", function()
			-- ROUND-1 NOTE: round 1 wrote 0 there, which cuts a hole from the band floor up to y=0.
			local tile = { minX = -4352, minZ = -5120 }
			local slice = sliceFor(tile, flat)
			slice.nx = 4 -- the reader now answers nil for almost every column of the tile
			slice.nz = 4
			slice.minY = 100
			local heights = TerrainBake.shapeTile(tile, slice, { "C1" }, {}, nil)
			local lowest = math.huge
			for _, y in heights do
				lowest = math.min(lowest, y)
			end
			expect(lowest).to.equal(100)
			expect(lowest).never.to.equal(0)
		end)

		it("328d-19 blurs a grid separably, and it is the SAME blur, measured", function()
			-- 328c note (c): `blurredAt` applies the Gaussian as a full 2-D kernel, 1,369 base reads
			-- a point. 328d is the task that pays -- with the per-point kernel this spec run passed
			-- the harness 300-s cap. A Gaussian is separable exactly, and this case is what says the
			-- two agree rather than a comment promising it.
			local function lumpy(x: number, z: number): number?
				return 100 + 7 * math.sin(x / 53) + 4 * math.cos(z / 31) + 0.002 * x
			end
			local v = Relief.VOXEL
			local minX, minZ, n = -4400, -5100, 24
			local grid = Relief.blurredGrid(lumpy, minX, minZ, n, n)
			local worst, worstAt = 0, ""
			for i = 1, n do
				for k = 1, n do
					local x, z = minX + (i - 1) * v, minZ + (k - 1) * v
					local point = Relief.blurredAtPoint(lumpy, x, z)
					local gap = math.abs(grid[(k - 1) * n + i] - point)
					if gap > worst then
						worst, worstAt = gap, string.format("(%d,%d)", x, z)
					end
				end
			end
			TestKit.note(
				string.format(
					"separable blur vs the per-point kernel: worst %.3e studs at %s over %d points",
					worst,
					worstAt,
					n * n
				)
			)
			expect(worst < 1e-9).to.equal(true)
			-- FAIL FIRST: the blur is not the identity, so a pass that returned the base would fail.
			local middle = grid[(12 - 1) * n + 12]
			expect(math.abs(middle - lumpy(minX + 11 * v, minZ + 11 * v)) > 0.05).to.equal(true)
			-- A CONSTANT BASE COMES BACK THE CONSTANT, which is what pins the kernel's
			-- normalisation -- the 328c note said nothing asserted it.
			local level = Relief.blurredGrid(function()
				return 42
			end, minX, minZ, 6, 6)
			for _, y in level do
				expect(math.abs(y - 42) < 1e-9).to.equal(true)
			end
			-- nil anywhere in a point's support makes that point nil, as the per-point kernel does.
			local holed = Relief.blurredGrid(function(x: number, _z: number)
				return if x < minX - 40 then nil else 100
			end, minX, minZ, 6, 6)
			expect(holed[1]).to.equal(nil)
		end)

		it("328d-20 relaxes the grade on a road it cannot cut to, and names the breach", function()
			-- Design 7.1: cut-or-fill <= 12 st, and a breach "relaxes the grade on that road and is
			-- printed, never hidden". ROUND-2 FINDING 4: the whole relaxation arm could be deleted
			-- with every case still green, because nothing fed it a base it could not meet.
			local road = Grid.roadsOf("C1").main
			local spec = TerrainBake.ROAD
			-- A 20-STUD CLIFF across the road's length. At 8 % the road needs 250 st to climb it, so
			-- the clamped line cuts and fills more than 12 st and the arm has to relax.
			local stepAt = road.from + (road.to - road.from) / 2
			local profile = TerrainBake.longProfile(road, function(x: number, _z: number)
				return if x < stepAt then 100 else 120
			end)
			expect(profile).never.to.equal(nil)
			TestKit.note(
				string.format(
					"road %s over a 20-st cliff: relaxed=%s grade %d %% (clamp %d %%), cut-or-fill %.2f (cap %d), %d breach(es): %s",
					road.id,
					tostring(profile.relaxed),
					profile.gradePercent,
					spec.gradePercent[road.axis],
					profile.worstCutFill,
					spec.cutFillStuds[road.axis],
					#profile.breaches,
					profile.breaches[1] or "none"
				)
			)
			-- FAIL FIRST: delete the relaxation arm and all three of these go the other way.
			expect(profile.relaxed).to.equal(true)
			expect(profile.gradePercent > spec.gradePercent[road.axis]).to.equal(true)
			expect(#profile.breaches >= 1).to.equal(true)
			expect(string.find(profile.breaches[1], road.id, 1, true) ~= nil).to.equal(true)
			-- AND IT IS THE CLIFF THAT DID IT, not the road: the same road over a flat base neither
			-- relaxes nor breaches, so the case cannot pass for the wrong reason.
			local calm = TerrainBake.longProfile(road, function()
				return 100
			end)
			expect(calm.relaxed).to.equal(false)
			expect(#calm.breaches).to.equal(0)
			expect(calm.gradePercent).to.equal(spec.gradePercent[road.axis])
			-- A FLAT BASE REALISES NO GRADE AT ALL, whatever ceiling it was allowed.
			expect(calm.realisedGradePercent < 1e-6).to.equal(true)
			-- AND THE CLIFF ROAD REALISES A GRADE INSIDE THE CEILING IT RELAXED TO.
			expect(profile.realisedGradePercent <= profile.gradePercent + 1e-6).to.equal(true)
			expect(profile.realisedGradePercent > spec.gradePercent[road.axis]).to.equal(true)
		end)

		it("328d-21 holds the grade CHANGE to design 7.1's rate, iterating until it does", function()
			-- ROUND-2 FINDING 4: the grade-change limiter could be deleted with every case green,
			-- because nothing measured a grade CHANGE. And one pass does not meet the rule: on this
			-- very base it left 3.80 % per 60 st against a 2.40 % allowance.
			local road = Grid.roadsOf("C1").west -- north-south, so the 10 % clamp leaves the kink
			local spec = TerrainBake.ROAD
			-- A KINK: dead flat, then 10 % -- inside the axis clamp, so the cone sweep leaves it and
			-- only the grade-CHANGE arm can soften it.
			local kinkAt = road.from + (road.to - road.from) / 2
			local profile = TerrainBake.longProfile(road, function(_x: number, z: number)
				return 100 + (if z < kinkAt then 0 else 0.10 * (z - kinkAt))
			end)
			expect(profile).never.to.equal(nil)
			-- THE RULE IS A RATE: 2 % per 50 st, measured over the span the 20-st samples allow.
			local allowance = spec.gradeChangePercentPer50 * (profile.gradeChangeSpanStuds / 50)
			TestKit.note(
				string.format(
					"road %s over a 0 -> 10 %% kink: worst grade change %.3f %% per %d st (allowance %.3f), cut-or-fill %.2f, %d breach(es)",
					road.id,
					profile.worstGradeChangePercent,
					profile.gradeChangeSpanStuds,
					allowance,
					profile.worstCutFill,
					#profile.breaches
				)
			)
			-- FAIL FIRST: the INPUT's own change is 10 % in one step, four times the allowance.
			expect(10 > allowance).to.equal(true)
			expect(profile.worstGradeChangePercent <= allowance + 1e-6).to.equal(true)
			-- The allowance IS the design's rate, re-derived from the span actually measured.
			expect(
				math.abs(profile.worstGradeChangePercent / profile.gradeChangeSpanStuds)
					<= spec.gradeChangePercentPer50 / 50 + 1e-9
			).to.equal(true)
			-- IT SMOOTHED, it did not flatten: the road still climbs, and the grade it REALISES is
			-- inside the ceiling it was given -- two different numbers, so neither stands in for the
			-- other (the live run on C1 ends at a 20 % ceiling with less than that realised).
			local climb = (profile.y[#profile.y] - profile.y[1]) / (profile.to - profile.from) * 100
			expect(climb > 4).to.equal(true)
			expect(profile.realisedGradePercent >= climb - 1e-6).to.equal(true)
			expect(profile.realisedGradePercent <= profile.gradePercent + 1e-6).to.equal(true)
			-- And a road with no kink in it reports no change and no breach.
			local even = TerrainBake.longProfile(road, function(_x: number, z: number)
				return 100 + 0.05 * (z - road.from)
			end)
			expect(even.worstGradeChangePercent < 1e-6).to.equal(true)
			expect(#even.breaches).to.equal(0)
		end)

		it("328j-1 pins every junction and gives the E-W profile the junction square", function()
			-- ROUND-3 FINDING 2 (reviews/task-328d/RESULT.md): design 7.1's "pin the 15 junctions"
			-- and "the E-W profile wins inside the junction square" were not built, so the two axes'
			-- profiles were under no constraint to agree and the surface switched crowns along the
			-- square's diagonal. The Reviewer measured 60.00 studs on this very base.
			local spec = TerrainBake.ROAD
			-- THE BASE: every east-west centreline 12 studs below all other ground, so each E-W profile
			-- is flat at 148, each north-south one wants 160, and the two disagree by 12 studs at
			-- every crossing -- a cliff across a road, and a cut a north-south road can afford
			-- (328j-3 is this base at 60 studs, which it cannot).
			local function base(_x: number, z: number): number?
				for _, road in Grid.roads() do
					if road.axis == "x" and math.abs(z - road.at) < 0.5 then
						return 160 - 12
					end
				end
				return 160
			end
			local profiles = TerrainBake.profilesFor({ "C1" }, base)
			local ew, ns = Grid.roadsOf("C1").main, Grid.roadsOf("C1").west
			-- FAIL FIRST, AS A NUMBER: the same north-south road with NO pins misses the east-west
			-- crown at the crossing by the whole disagreement. That is the defect, re-measured here;
			-- the Reviewer measured 60.00 st of it on the steeper base 328j-3 uses.
			local bare = TerrainBake.longProfile(ns, base)
			local bareStep = math.abs(TerrainBake.profileY(bare, ew.at) - 148)
			TestKit.note(
				string.format("unpinned %s at the %s crossing is %.2f st off the E-W crown", ns.id, ew.id, bareStep)
			)
			expect(bareStep > 10).to.equal(true)
			-- C1's FOUR CROSSINGS: EW2/EW3 x NS3/NS4, each measured.
			local steps = TerrainBake.junctionSteps(profiles)
			expect(#steps).to.equal(4)
			for _, row in steps do
				TestKit.note(
					string.format(
						"%s x %s at (%d,%d): %d samples, pin %.4f st, worst step %.4f st at (%+d,%+d), explained %.4f",
						row.ew,
						row.ns,
						row.x,
						row.z,
						row.samples,
						row.pinStuds,
						row.worstStepStuds,
						row.atOffsetX,
						row.atOffsetZ,
						row.explainedStuds
					)
				)
				-- THE PIN: the two crowns agree at the crossing. 60.00 before, 0 after.
				expect(row.pinStuds < 1e-6).to.equal(true)
				-- AND THE GROUND SHOWS NO STEP BIGGER THAN THE CROSSFALL across the square and one
				-- voxel past its boundary -- the two roads' crossfalls are perpendicular, so where
				-- one road's crown meets the other's edge the whole crown fall is the residual.
				expect(row.worstStepStuds <= spec.crownFallStuds + 1e-6).to.equal(true)
			end
			-- THE PRECEDENCE, ON ITS OWN: a point inside the square whose NEAREST centreline is the
			-- north-south one. Before this was built the nearest rule answered ~160 there.
			local inside = TerrainBake.roadAt(profiles, 160, ns.at + 4, ew.at + 12)
			local wantEW = 148 - spec.crownFallStuds * (12 / spec.carriagewayStuds)
			TestKit.note(
				string.format("inside the square at (+4,+12): %.4f, the E-W section wants %.4f", inside, wantEW)
			)
			expect(math.abs(inside - wantEW) < 1e-9).to.equal(true)
			-- THE DIAGONAL the Reviewer measured at 60.00 studs: (+5,+10) against (+10,+5).
			local diagA = TerrainBake.roadAt(profiles, 160, ns.at + 5, ew.at + 10)
			local diagB = TerrainBake.roadAt(profiles, 160, ns.at + 10, ew.at + 5)
			TestKit.note(string.format("the square's diagonal: %.4f vs %.4f", diagA, diagB))
			expect(math.abs(diagA - diagB) <= spec.crownFallStuds + 1e-9).to.equal(true)
			-- AND IT IS CONFINED TO THE SQUARE: 500 studs up the same north-south road, away from
			-- every crossing, the nearest centreline still wins and the road is back on its own
			-- crown -- so the precedence rule cannot be passing by flattening the world.
			local away = TerrainBake.roadAt(profiles, 160, ns.at, ew.at + 500)
			local nsProfile = nil
			for _, profile in profiles do
				if profile.road.id == ns.id then
					nsProfile = profile
				end
			end
			expect(nsProfile).never.to.equal(nil)
			TestKit.note(
				string.format(
					"500 st up %s: %.2f, its own crown %.2f",
					ns.id,
					away,
					TerrainBake.profileY(nsProfile, ew.at + 500)
				)
			)
			expect(math.abs(away - TerrainBake.profileY(nsProfile, ew.at + 500)) < 1e-9).to.equal(true)
			expect(away > 155).to.equal(true)
		end)

		it("328j-2 gives the north-south roads their own cut-or-fill cap, not the east-west 12", function()
			-- DIRECTOR DECISION 3 (ESCALATE.md, 2026-11-02 17:05 UTC): C1's base rises 110 and 124 st
			-- over NS3's and NS4's span, so at a 12-st cap the relaxation arm took them to a realised
			-- 15.73 % and 13.47 %. The cap is raised for the north-south roads only, ceiling 20 st.
			local spec = TerrainBake.ROAD
			expect(spec.cutFillStuds.x).to.equal(12)
			expect(spec.cutFillStuds.z <= 20).to.equal(true)
			expect(spec.cutFillStuds.z > spec.cutFillStuds.x).to.equal(true)
			local flank = Grid.roadsOf("C1").west
			local line = Grid.roadsOf("C1").main
			local function cliff(height: number, road)
				local at = road.from + (road.to - road.from) / 2
				return function(x: number, z: number): number?
					local along = if road.axis == "x" then x else z
					return if along < at then 100 else 100 + height
				end
			end
			-- A CLIFF TALL ENOUGH to need more than the east-west 12 st and no more than the 20 the
			-- north-south roads now have -- WALKED, not guessed, so the case cannot drift.
			local chosen, profile = 0, nil
			for height = 10, 80, 2 do
				local candidate = TerrainBake.longProfile(flank, cliff(height, flank))
				if candidate.worstCutFill > spec.cutFillStuds.x and candidate.worstCutFill <= spec.cutFillStuds.z then
					chosen, profile = height, candidate
					break
				end
			end
			expect(profile).never.to.equal(nil)
			TestKit.note(
				string.format(
					"%s over a %d-st cliff: cut-or-fill %.2f st (E-W cap %d, N-S cap %d), relaxed=%s, realised %.2f %%",
					flank.id,
					chosen,
					profile.worstCutFill,
					spec.cutFillStuds.x,
					spec.cutFillStuds.z,
					tostring(profile.relaxed),
					profile.realisedGradePercent
				)
			)
			-- FAIL FIRST: with one 12-st cap for both axes this cut relaxes the grade and breaches.
			expect(profile.worstCutFill > spec.cutFillStuds.x).to.equal(true)
			expect(profile.relaxed).to.equal(false)
			expect(#profile.breaches).to.equal(0)
			expect(profile.realisedGradePercent <= spec.gradePercent.z + 1e-6).to.equal(true)
			-- AND THE EAST-WEST ROADS KEEP THE DESIGN'S 12: the same cut on a hunter line relaxes.
			local onLine = nil
			for height = 10, 120, 2 do
				local candidate = TerrainBake.longProfile(line, cliff(height, line))
				if candidate.worstCutFill > spec.cutFillStuds.x then
					onLine = candidate
					break
				end
			end
			expect(onLine).never.to.equal(nil)
			expect(onLine.relaxed).to.equal(true)
			expect(#onLine.breaches >= 1).to.equal(true)
		end)

		it("328j-3 gives a pin up rather than drag the road off the hillside, and says which", function()
			-- A PIN THE GROUND CANNOT CARRY. 328j-1's base with the east-west lines 60 studs down --
			-- the Reviewer's own base, where it measured the 60.00-stud step. Meeting the pins costs
			-- 60 st of cut against the north-south cap of 20, and forcing them is worse than the step:
			-- on a 31-degree ramp the forced flank's bank reached 165 studs into a tile it has no
			-- business in (328d-17). So the pinning is given up, and a breach line says which road.
			local spec = TerrainBake.ROAD
			local function base(_x: number, z: number): number?
				for _, road in Grid.roads() do
					if road.axis == "x" and math.abs(z - road.at) < 0.5 then
						return 160 - 60
					end
				end
				return 160
			end
			local ns = Grid.roadsOf("C1").west
			local ewProfiles = {}
			for _, road in Grid.roads() do
				if road.axis == "x" then
					table.insert(ewProfiles, TerrainBake.longProfile(road, base))
				end
			end
			local pins = TerrainBake.junctionPins(ns, ewProfiles)
			expect(#pins).to.equal(3)
			local profile = TerrainBake.longProfile(ns, base, pins)
			local given = nil
			for _, line in profile.breaches do
				if string.find(line, "NOT pinned", 1, true) ~= nil then
					given = line
				end
			end
			TestKit.note(string.format("%s with 3 unaffordable pins: %s", ns.id, given or "NOTHING SAID"))
			-- FAIL FIRST: the cut the pins ask for is 3x the cap, so this is not a case that passes
			-- on a base it could have met anyway.
			expect(60 > spec.cutFillStuds.z).to.equal(true)
			expect(given).never.to.equal(nil)
			expect(string.find(given, ns.id, 1, true) ~= nil).to.equal(true)
			-- AND THE PROFILE IS BACK ON THE GROUND it was read off, which the forced one was not.
			expect(profile.worstCutFill <= spec.cutFillStuds.z + 1e-6).to.equal(true)
		end)
		-- ------------------------------------------------------------ 328e: the pads and the paint

		it("328e-1 levels a pad at every stand, to the ROAD's crown and not to lineMeanY", function()
			-- DESIGN 7.4: "the pad is level to +-0.25 st and the census measures relief <= 1.8 st".
			local spec = TerrainBake.STAND_PAD
			local profiles = TerrainBake.profilesFor({ "C1" }, flat)
			local pads, missed = TerrainBake.standPadsFor({ "C1" }, profiles)
			-- EVERY STAND GETS ONE, and none is missed: all fifteen sit on a road centreline.
			expect(#pads).to.equal(Grid.standCount("C1"))
			expect(#missed).to.equal(0)
			-- THE CORE COVERS 327b's RING, which is the instrument `JUMP_RELIEF_STUDS` 1.8 is read
			-- with, plus a voxel column so the outermost ring sample is inside the core.
			expect(spec.levelRadiusStuds >= 12 + Relief.VOXEL / 2).to.equal(true)
			-- ...AND WHAT IT COSTS THE DITCH, measured rather than asserted away. The pad's reach
			-- is 22 studs and the realised ditch band starts at 19, so it DOES overlap by 3 -- but
			-- the ditch's first sampled column centre is at d 21, where the blend is nearly spent.
			local ditchLo, ditchHi = TerrainBake.bandFor(
				Grid.roadsOf("C1").main.at,
				TerrainBake.ROAD.ditch.nearStuds,
				TerrainBake.ROAD.ditch.farStuds,
				1
			)
			local reach = spec.levelRadiusStuds + spec.blendStuds
			expect(reach > ditchLo).to.equal(true) -- it overlaps, and the next line says by how much
			expect(reach - ditchLo).to.equal(3)
			-- THE FILL AT THE NEAREST SAMPLED DITCH COLUMN, in studs: smoothstep is spent there.
			local centreAt = Grid.standPosition("C1", 4)
			local atDitch =
				TerrainBake.standPadAt(pads, pads[1].y - TerrainBake.ROAD.ditch.depthStuds, centreAt.X, centreAt.Z + 21)
			local fill = (atDitch or (pads[1].y - TerrainBake.ROAD.ditch.depthStuds))
				- (pads[1].y - TerrainBake.ROAD.ditch.depthStuds)
			expect(fill < 0.15).to.equal(true)
			expect(ditchHi > ditchLo).to.equal(true)
			-- THE HEIGHT IS THE ROAD'S CROWN THERE. On a flat base every crown is the base, so the
			-- claim that bites is the SHAPE of the dependency: ask the same stand on a base 40 studs
			-- higher and the pad follows the road, where `lineMeanY` would not move at all.
			local function higher(_x: number, _z: number): number?
				return 140
			end
			local lifted = TerrainBake.standPadsFor({ "C1" }, TerrainBake.profilesFor({ "C1" }, higher))
			local lineMeanY = Grid.standPosition("C1", 1).Y
			for index, pad in pads do
				expect(math.abs(pad.y - 100) < 1.0).to.equal(true)
				expect(math.abs(lifted[index].y - 140) < 1.0).to.equal(true)
				expect(math.abs(lifted[index].y - pad.y) > 35).to.equal(true)
			end
			-- FAIL FIRST, AND IT IS THE WHOLE POINT OF THE CHOICE: `lineMeanY` is ONE number for all
			-- fifteen stands and it is 106.98 for C1, so a pad at that height is 6.98 studs off a
			-- 100-stud base at EVERY stand, and in Karen's baked place it was 13.57 above the ground
			-- at stand 8 and 21.84 below it at stand 11 (`<runs-dir>/328e-ground-BEFORE.json`).
			expect(math.abs(lineMeanY - 100) > 5).to.equal(true)
			TestKit.note(
				string.format(
					"C1: %d pads, 0 missed; pad y %.2f on a 100 base and %.2f on a 140 base; lineMeanY %.2f",
					#pads,
					pads[1].y,
					lifted[1].y,
					lineMeanY
				)
			)
		end)

		it("328e-2 enters every arm of the pad: core, blend, out of reach, and no road", function()
			-- L-093: a case that proves nothing for the arms it does not enter is how a defect ships.
			local spec = TerrainBake.STAND_PAD
			local profiles = TerrainBake.profilesFor({ "C1" }, flat)
			local pads = TerrainBake.standPadsFor({ "C1" }, profiles)
			local at = Grid.standPosition("C1", 4)
			local pad = nil
			for _, row in pads do
				if row.index == 4 then
					pad = row
				end
			end
			expect(pad).never.to.equal(nil)
			-- ARM 1: THE LEVEL CORE. Every point inside it is the pad's own height, to the design's
			-- +-0.25 -- measured out to the core's own edge, where the road's crossfall and its
			-- grade would both show if the pad were not holding the ground.
			local worst = 0
			for k = 0, 23 do
				local a = math.rad(k * 15)
				for _, r in { 0, 6, 12, spec.levelRadiusStuds } do
					local y = TerrainBake.standPadAt(pads, 0, at.X + math.cos(a) * r, at.Z + math.sin(a) * r)
					expect(y).never.to.equal(nil)
					worst = math.max(worst, math.abs((y :: number) - pad.y))
				end
			end
			expect(worst <= spec.toleranceStuds).to.equal(true)
			-- ARM 2: THE BLEND. Strictly between the two heights, weight strictly between 0 and 1,
			-- and MONOTONE out -- so there is no lip inside the ring.
			local previous = pad.y
			for step = 1, spec.blendStuds - 1 do
				local y, weight = TerrainBake.standPadAt(pads, 60, at.X + spec.levelRadiusStuds + step, at.Z)
				expect(y).never.to.equal(nil)
				expect(weight > 0 and weight < 1).to.equal(true)
				expect((y :: number) < previous + 1e-9).to.equal(true)
				expect((y :: number) > 60).to.equal(true)
				previous = y :: number
			end
			-- ...AND THE JOIN IS CONTINUOUS AT BOTH ENDS: the pad's height at the core's edge and the
			-- natural height at the outer edge, with no step a voxel could show.
			local inner = TerrainBake.standPadAt(pads, 60, at.X + spec.levelRadiusStuds, at.Z)
			expect(math.abs((inner :: number) - pad.y) < 1e-9).to.equal(true)
			local outer, outerWeight =
				TerrainBake.standPadAt(pads, 60, at.X + spec.levelRadiusStuds + spec.blendStuds - 1e-6, at.Z)
			expect(math.abs((outer :: number) - 60) < 1e-3).to.equal(true)
			expect(outerWeight < 1e-3).to.equal(true)
			-- THE BLEND IS NEVER A CLIFF: smoothstep's worst gradient is 1.5 * drop / width, and a
			-- pad on a 10 % road holds at most `levelRadiusStuds` * 0.10 studs of grade.
			local drop = spec.levelRadiusStuds * TerrainBake.ROAD.gradePercent.z / 100
			local steepest = math.deg(math.atan(1.5 * drop / spec.blendStuds))
			expect(steepest < Relief.LIMIT_DEG.tree).to.equal(true)
			-- ARM 3: OUT OF REACH -- nil and weight 0, which is almost all of a cell.
			local gone, goneWeight =
				TerrainBake.standPadAt(pads, 60, at.X + spec.levelRadiusStuds + spec.blendStuds + 1, at.Z)
			expect(gone).to.equal(nil)
			expect(goneWeight).to.equal(0)
			expect(TerrainBake.standPadAt({}, 60, at.X, at.Z)).to.equal(nil)
			-- ARM 4: NO ROAD UNDER THE STAND. Hand `standPadsFor` an empty profile set and every
			-- stand is REPORTED as missed rather than given a pad at a height nothing measured.
			local none, allMissed = TerrainBake.standPadsFor({ "C1" }, {})
			expect(#none).to.equal(0)
			expect(#allMissed).to.equal(Grid.standCount("C1"))
			expect(allMissed[1]).to.equal("C1/1")
			TestKit.note(
				string.format(
					"pad arms: core worst %.4f st (<= %.2f), blend %d st, steepest %.1f deg (< %d), out of reach nil",
					worst,
					spec.toleranceStuds,
					spec.blendStuds,
					steepest,
					Relief.LIMIT_DEG.tree
				)
			)
		end)

		it("328e-3 writes the pad into the tile, level, and the limiter cannot tilt it", function()
			-- THE TILE THAT HOLDS C1's STAND 4 (x = -3899 on EW2's centreline, z = -5107).
			local at = Grid.standPosition("C1", 4)
			local tile = {
				minX = TerrainBake.TILE_STUDS * math.floor(at.X / TerrainBake.TILE_STUDS),
				minZ = TerrainBake.TILE_STUDS * math.floor(at.Z / TerrainBake.TILE_STUDS),
			}
			-- A BASE THAT RISES 10 % ALONG THE ROAD, so the road has a grade for the pad to flatten
			-- and the limiter has something to clamp. Flat ground could not tell the two apart.
			local function slope(x: number, _z: number): number?
				return 100 + 0.10 * (x - tile.minX)
			end
			local profiles = TerrainBake.profilesFor({ "C1" }, slope)
			local heights, _, n = TerrainBake.shapeTile(tile, sliceFor(tile, slope), { "C1" }, {}, profiles)
			local v = Relief.VOXEL
			local function h(x: number, z: number): number
				local i = math.floor((x - tile.minX) / v) + 1
				local k = math.floor((z - tile.minZ) / v) + 1
				return heights[(k - 1) * n + i]
			end
			-- THE PAD IS LEVEL over 327b's own ring, to the design's +-0.25.
			local centre = h(at.X, at.Z)
			local lo, hi = centre, centre
			for k = 0, 7 do
				local a = math.rad(k * 45)
				local y = h(at.X + math.cos(a) * 12, at.Z + math.sin(a) * 12)
				lo, hi = math.min(lo, y), math.max(hi, y)
			end
			TestKit.note(
				string.format(
					"tile (%d,%d) on a 10 %% slope: pad relief %.4f st over the 12-stud ring, tolerance %.2f, JUMP_RELIEF 1.8",
					tile.minX,
					tile.minZ,
					hi - lo,
					TerrainBake.STAND_PAD.toleranceStuds
				)
			)
			expect(hi - lo <= TerrainBake.STAND_PAD.toleranceStuds).to.equal(true)
			-- FAIL FIRST: with the pads taken away the same ring rolls more than the design allows,
			-- so this case does not pass on ground it would have met anyway.
			local real = TerrainBake.standPadsFor
			TerrainBake.standPadsFor = function()
				return {}, {}
			end
			local without = TerrainBake.shapeTile(tile, sliceFor(tile, slope), { "C1" }, {}, profiles)
			TerrainBake.standPadsFor = real
			local blo, bhi = math.huge, -math.huge
			for k = 0, 7 do
				local a = math.rad(k * 45)
				local i = math.floor((at.X + math.cos(a) * 12 - tile.minX) / v) + 1
				local kk = math.floor((at.Z + math.sin(a) * 12 - tile.minZ) / v) + 1
				local y = without[(kk - 1) * n + i]
				blo, bhi = math.min(blo, y), math.max(bhi, y)
			end
			TestKit.note(string.format("the same ring with NO pad: %.4f st of roll", bhi - blo))
			expect(bhi - blo > TerrainBake.STAND_PAD.toleranceStuds).to.equal(true)
			expect(bhi - blo > hi - lo).to.equal(true)
		end)

		it("328e-4 paints design 7.1's table: `mid` ends at 6 studs, not at 10", function()
			local road = Grid.roadsOf("C1").main
			local spec = TerrainBake.ROAD
			local profiles = TerrainBake.profilesFor({ "C1" }, flat)
			-- OFF THE STANDS AND OFF EVERY JUNCTION, so this is the plain cross-section.
			local along = Grid.standPosition("C1", 4).X + 75
			local function nameAt(d: number): string
				local _, name = TerrainBake.roadAt(profiles, 100, along, road.at + d)
				return name
			end
			expect(spec.midStuds).to.equal(6)
			-- THE REALISED COLUMN CENTRES on this road sit at d = 1 (mod 4), which is what F-2's
			-- "every centre is = 1 (mod 4)" makes them. `mid` for d < 6, `outer` above it, and the
			-- rut band overrides whichever it lands in.
			local rutLo, rutHi = TerrainBake.bandFor(road.at, spec.rut.nearStuds, spec.rut.farStuds, 1)
			for _, d in { 1, 5, 9, 13, 17 } do
				local want
				if d >= rutLo and d <= rutHi then
					want = spec.material.x.rut
				elseif d < spec.midStuds then
					want = spec.material.x.mid
				else
					want = spec.material.x.outer
				end
				expect(nameAt(d)).to.equal(want)
			end
			-- FAIL FIRST, AND IT IS **d 9 ALONE** that does it: under `d < 10` that column answered
			-- `mid` (Ground) where the design's table asks for `outer` (Grass). d 13 and 17 are
			-- already >= 10 and answered `outer` before this change too, so they are a guard and not
			-- the bite -- said here because round 1 claimed all three.
			expect(nameAt(9)).to.equal("Grass")
			expect(9 >= spec.midStuds and 9 < 10).to.equal(true)
			expect(nameAt(13)).to.equal("Grass")
			expect(nameAt(17)).to.equal("Grass")
			expect(spec.material.x.mid).never.to.equal(spec.material.x.outer)
			-- AND THE RUTS ARE STILL AT +-8 IN THE DESIGN'S OWN TERMS (F-3): 8 is the NOMINAL band's
			-- midpoint. The realised column is d 3..7 on this parity and does NOT contain 8 -- the
			-- MEASURED Mud on the ground does (|d| 5..9 on EW2, 328e-xsec2-AFTER.json), because the
			-- written voxel lands about 2 studs out from where it was computed (TASKS.md 328e (a)).
			-- Both halves said, so neither can be read as the other.
			expect((spec.rut.nearStuds + spec.rut.farStuds) / 2).to.equal(8)
			expect(rutLo).to.equal(3)
			expect(rutHi).to.equal(7)
			expect(nameAt((rutLo + rutHi) / 2)).to.equal("Mud")
			TestKit.note(
				string.format(
					"EW2 cross-section: d 1 %s, 5 %s, 9 %s, 13 %s, 17 %s; rut column d %.0f..%.0f, nominal midpoint 8",
					nameAt(1),
					nameAt(5),
					nameAt(9),
					nameAt(13),
					nameAt(17),
					rutLo,
					rutHi
				)
			)
		end)

		it("328e-5 gives C1 a litter floor, and `src/` still paints no grid road", function()
			-- MEASURED in Karen's place after the 328d bake: the cell floor was `Ground` on 5504 of
			-- 5504 lattice samples -- bare brown from every stand (`<runs-dir>/328e-ground-BEFORE.json`).
			expect(Relief.LANDFORMS.C1.floor.default).to.equal("LeafyGrass")
			-- IT REACHES THE GROUND through the one reader, with no mud or scree rule to divert it.
			expect(Relief.LANDFORMS.C1.floor.mudDepthStuds).to.equal(nil)
			expect(Relief.LANDFORMS.C1.floor.screeDegFrom).to.equal(nil)
			expect(Relief.materialAt(Relief.LANDFORMS.C1, Grid.boundsOf("C1"), nil, 0, 0, 0, 0)).to.equal("LeafyGrass")
			expect(Relief.materialAt(Relief.LANDFORMS.C1, Grid.boundsOf("C1"), nil, 35, 40, 0, 0)).to.equal(
				"LeafyGrass"
			)
			-- AND THE EPOCH MOVES WITH IT, because the landforms are hashed into it: the ground this
			-- commit makes cannot be confused with the ground 328d made.
			local before = {} :: any
			for id, form in Relief.LANDFORMS do
				before[id] = form
			end
			before.C1 = table.freeze({
				baseKeep = Relief.LANDFORMS.C1.baseKeep,
				ops = Relief.LANDFORMS.C1.ops,
				floor = table.freeze({ default = "Ground" }),
			})
			expect(Relief.epochInput(Relief.LANDFORMS, Grid.CONFIG)).never.to.equal(
				Relief.epochInput(before, Grid.CONFIG)
			)
			-- `Ground.paintRoads` IS ARCHIVED (task 328e, design 16), and so is `grid.spec` case 19.
			local Planter = require(ServerScriptService:WaitForChild("Places"))
			local Soil = require(ServerScriptService:WaitForChild("Places"):WaitForChild("Ground"))
			expect((Soil :: any).paintRoads).to.equal(nil)
			expect((Soil :: any).roadChunks).to.equal(nil)
			expect((Soil :: any).roadYBand).to.equal(nil)
			expect((Soil :: any).roadBand).to.equal(nil)
			expect((Soil :: any).ROAD_CALL_BUDGET).to.equal(nil)
			-- ...AND THE LANE PAINT THE FOUR LINE PLACES USE IS UNTOUCHED.
			expect(type((Soil :: any).band)).to.equal("function")
			expect(type((Soil :: any).bandBounds)).to.equal("function")
			expect(#(Soil :: any).SOURCE_MATERIALS > 0).to.equal(true)
			expect(type((Planter :: any).build)).to.equal("function")
			TestKit.note(
				string.format(
					"C1 floor %s; Ground.paintRoads archived, Ground.band kept; epoch input %d bytes",
					Relief.LANDFORMS.C1.floor.default,
					#Relief.epochInput(Relief.LANDFORMS, Grid.CONFIG)
				)
			)
		end)
		it("328e-6 puts the landform in ONCE: a bake over baked ground does not add it again", function()
			-- MEASURED IN KAREN'S PLACE BEFORE THIS TASK WROTE ANYTHING
			-- (`<runs-dir>/328e-drift-BEFORE.json`): over 90 points of C1 a fresh bake would have
			-- raised the ground a mean of 3.67 studs, 27 points by over half a stud, NONE lowered,
			-- worst **+24.04 studs on the ridge line** -- which is `C1.ops[1].dyStuds` 24 exactly.
			-- `Relief.deltaAt` adds its ops, so a base that is already baked gets a second ridge.
			local mark = Instance.new("Folder")
			-- ARM 1: NO STAMP -- a cell whose landform has never gone in. It is applied.
			local wanted, why, kind = TerrainBake.reshapeWanted("C1", mark)
			expect(wanted).to.equal(true)
			expect(kind).to.equal("virgin")
			expect(string.find(why, "not in its ground", 1, true) ~= nil).to.equal(true)
			-- ...AND A GLOBAL EPOCH DOES NOT CHANGE THAT. **FAIL FIRST, and it is round 1 finding 1**:
			-- `TerrainEpoch` is ONE attribute for the whole Terrain while a run covers only its own
			-- `--cells`, so reading it told a never-baked cell its landform was already in the
			-- ground -- roads and pads onto raw relief. The stamped cell and the unstamped one must
			-- answer DIFFERENTLY with the same epoch set.
			TerrainBake.stamp("deadbeefdeadbeef", mark)
			expect(TerrainBake.stampShape({ "C1" }, mark)).to.equal(1)
			local bakedWanted, _, bakedKind = TerrainBake.reshapeWanted("C1", mark)
			local freshWanted, _, freshKind = TerrainBake.reshapeWanted("A1", mark)
			expect(bakedWanted).to.equal(false)
			expect(bakedKind).to.equal("stamped")
			expect(freshWanted).to.equal(true)
			expect(freshKind).to.equal("virgin")
			expect(bakedWanted).never.to.equal(freshWanted)
			-- ARM 2: THE STAMPED SHAPE IS THIS LANDFORM. Already in the ground, and the stamp is
			-- per cell -- `stampShape` writes only the cells it is given.
			expect(mark:GetAttribute("TerrainShape_C1")).to.equal(TerrainBake.shapeInputFor("C1"))
			expect(mark:GetAttribute("TerrainShape_A1")).to.equal(nil)
			-- ARM 3: A DIFFERENT SHAPE -- someone moved the ops. Apply, and `terrainbake.py` refuses
			-- the wet run on this word rather than on the prose.
			mark:SetAttribute("TerrainShape_C1", "a landform that is not this one")
			wanted, why, kind = TerrainBake.reshapeWanted("C1", mark)
			expect(wanted).to.equal(true)
			expect(kind).to.equal("changed")
			expect(string.find(why, "shape has changed", 1, true) ~= nil).to.equal(true)
			-- ARM 4: EVERY CELL OF THE WORLD IS VIRGIN ON A BARE MARKER, which is what makes the
			-- round-1 defect impossible to reach for ANY cell and not only A1.
			local bare = Instance.new("Folder")
			TerrainBake.stamp("deadbeefdeadbeef", bare)
			for _, id in Grid.cellIds() do
				local w, _, k = TerrainBake.reshapeWanted(id, bare)
				expect(w).to.equal(true)
				expect(k).to.equal("virgin")
			end
			bare:Destroy()
			-- THE STAMP IS THE SHAPE AND NOT THE FLOOR: this task moved C1's floor from `Ground` to
			-- `LeafyGrass`, which moves no ground, so it may not force a re-shape.
			local painted = Relief.epochInput({
				C1 = {
					baseKeep = Relief.LANDFORMS.C1.baseKeep,
					ops = Relief.LANDFORMS.C1.ops,
					floor = { default = "Rock" },
				},
			}, Grid.CONFIG)
			expect(TerrainBake.shapeInputFor("C1")).never.to.equal(painted)
			expect(string.find(TerrainBake.shapeInputFor("C1"), "floor", 1, true)).to.equal(nil)
			mark:Destroy()

			-- AND IT REACHES THE GROUND: the same tile, shaped both ways over a base that already
			-- carries C1's ridge. With `reshape` off the heights ARE the base; with it on they are
			-- the base plus the landform again, and the difference is the ridge.
			local tile = { minX = -4096, minZ = -4736 } -- inside C1, off every road
			local function base(_x: number, _z: number): number?
				return 120
			end
			local profiles = TerrainBake.profilesFor({ "C1" }, base)
			local slice = sliceFor(tile, base)
			local again = TerrainBake.shapeTile(tile, slice, { "C1" }, {}, profiles, { C1 = true })
			local once = TerrainBake.shapeTile(tile, slice, { "C1" }, {}, profiles, { C1 = false })
			local worstAgain, worstOnce = 0, 0
			for index = 1, #once do
				worstAgain = math.max(worstAgain, math.abs(again[index] - 120))
				worstOnce = math.max(worstOnce, math.abs(once[index] - 120))
			end
			TestKit.note(
				string.format(
					"tile (%d,%d) over a flat 120 base: reshape=true moves it %.2f st, reshape=false %.2f st",
					tile.minX,
					tile.minZ,
					worstAgain,
					worstOnce
				)
			)
			-- FAIL FIRST: `reshape=true` is the old behaviour and it MOVES this ground; the whole
			-- claim is that `reshape=false` leaves it where it is.
			expect(worstAgain > 5).to.equal(true)
			expect(worstOnce < 0.01).to.equal(true)
			-- ...AND `nil` IS THE VIRGIN DEFAULT, identical to asking for every cell.
			local byDefault = TerrainBake.shapeTile(tile, slice, { "C1" }, {}, profiles, nil)
			for index = 1, #byDefault do
				expect(math.abs(byDefault[index] - again[index]) < 1e-9).to.equal(true)
			end
		end)
	end)

	-- ---------------------------------------------------------------- task 328k: the base snapshot
	describe("TerrainBake: the base snapshot (task 328k, design 5.3 step 2)", function()
		local TerrainBake = require(ServerStorage:WaitForChild("TerrainBake"))
		-- THE SAME BYTES `tools/terrainbake.py selftest` checks its own encoder against
		-- (`SLICE_FIXTURE_B64`). Each side is checked against committed bytes, never against the
		-- other side's good intentions.
		local FIXTURE_B64 = "ABkgGVAZwBiwGAAZ"
		local FIXTURE_HEIGHTS = { 100.0, 100.5, 101.25, 99.0, 98.75, 100.0 }

		local function snapshotOf(minX: number, minZ: number, nx: number, nz: number, heightOf, holes)
			local v = Relief.VOXEL
			local snap = {
				pitch = v,
				minX = minX,
				minZ = minZ,
				nx = nx,
				nz = nz,
				height = table.create(nx * nz, 0),
				minY = math.huge,
				maxY = -math.huge,
				hole = holes or {},
				holes = 0,
				holeWhy = {},
			}
			for at in snap.hole do
				snap.holes += 1
				local _ = at
			end
			for i = 1, nx do
				for k = 1, nz do
					local at = (k - 1) * nx + i
					local y = heightOf(minX + (i - 0.5) * v, minZ + (k - 0.5) * v)
					snap.height[at] = y
					-- THE RANGE SKIPS THE HOLES, exactly as `TerrainBake.snapshot` does: a hole has no
					-- height to put in it (Reviewer, round 1, finding 1).
					if not snap.hole[at] then
						snap.minY = math.min(snap.minY, y)
						snap.maxY = math.max(snap.maxY, y)
					end
				end
			end
			return snap
		end

		it("328k-1 ENTERS each of the four column faults, and answers nil for a clean column", function()
			-- L-093: one case per ARM, each one entered, not one case near the code.
			local water = TerrainBake.columnFault(true, 1, true, false, 10, 20, -100, 400)
			local over = TerrainBake.columnFault(false, 2, true, false, 10, 20, -100, 400)
			local empty = TerrainBake.columnFault(false, 0, false, false, 10, 20, -100, 400)
			local ceiling = TerrainBake.columnFault(false, 1, true, true, 10, 20, -100, 400)
			expect(water).never.to.equal(nil)
			expect(string.find(water :: string, "Water", 1, true)).never.to.equal(nil)
			expect(string.find(over :: string, "overhang", 1, true)).never.to.equal(nil)
			expect(string.find(over :: string, "2 solid runs", 1, true)).never.to.equal(nil)
			expect(string.find(empty :: string, "no ground", 1, true)).never.to.equal(nil)
			expect(string.find(empty :: string, "-100..400", 1, true)).never.to.equal(nil)
			expect(string.find(ceiling :: string, "reaches the top of the Y band", 1, true)).never.to.equal(nil)
			-- WATER WINS OVER AN OVERHANG, so a flooded cave is named for the water it holds.
			expect(string.find(TerrainBake.columnFault(true, 3, true, true, 0, 0, 0, 1) :: string, "Water", 1, true)).never.to.equal(
				nil
			)
			-- AND A CLEAN COLUMN IS NOT A FAULT -- without this the whole base would be holes.
			expect(TerrainBake.columnFault(false, 1, true, false, 10, 20, -100, 400)).to.equal(nil)
			TestKit.note("column faults: " .. water .. " | " .. over .. " | " .. empty .. " | " .. ceiling)
		end)

		it("328k-2 decodes the committed slice fixture to the exact heights, and back", function()
			local slice = TerrainBake.decodeSlice({
				pitch = 4,
				minX = -40,
				minZ = -20,
				nx = 3,
				nz = 2,
				scale = 64,
				offset = 0,
				b64 = FIXTURE_B64,
				holes = {},
			})
			expect(slice.nx).to.equal(3)
			expect(slice.nz).to.equal(2)
			for at, want in FIXTURE_HEIGHTS do
				expect(math.abs(slice.height[at] - want) < 1e-9).to.equal(true)
			end
			expect(slice.minY).to.equal(98.75)
			expect(slice.maxY).to.equal(101.25)
			-- AND THE ENCODER IS ITS INVERSE, which is what lets the tool stitch chunks it did not
			-- itself quantise: the same bytes come back out.
			local again = TerrainBake.encodeSlice(slice)
			expect(again.b64).to.equal(FIXTURE_B64)
			expect(again.holes).to.equal(0)
		end)

		it("328k-2b carries the holes as a BITMASK, and decodes the same set back", function()
			-- A chunk of the border pad where NO column has ground sent 16,384 hole INDICES, the
			-- reply truncated mid-object, and the tool read `holeWhy` -- a list of sentences -- where
			-- a slice should have been (MEASURED 2026-11-03). One bit a column is 2 KB instead.
			local want = { [1] = true, [8] = true, [9] = true, [63] = true }
			local snap = snapshotOf(0, 0, 9, 7, flat, want)
			local wire = TerrainBake.encodeSlice(snap)
			expect(wire.holes).to.equal(4)
			expect(type(wire.holeBits)).to.equal("string")
			-- 63 columns is 8 bytes of mask, which is 12 characters of base64 (8 -> ceil(8/3)*4).
			expect(#wire.holeBits).to.equal(12)
			local back = TerrainBake.decodeSlice(wire)
			expect(back.holes).to.equal(4)
			local read = TerrainBake.readerFor(back)
			for at = 1, 63 do
				local i = (at - 1) % 9 + 1
				local k = (at - 1) // 9 + 1
				local there = read((i - 0.5) * Relief.VOXEL, (k - 0.5) * Relief.VOXEL)
				if want[at] then
					expect(there).to.equal(nil)
				else
					expect(there).to.equal(100)
				end
			end
			-- AND AN ALL-HOLE SLICE round-trips too: that is the chunk that broke the wire.
			local every: { [number]: boolean } = {}
			for at = 1, 63 do
				every[at] = true
			end
			local none = TerrainBake.decodeSlice(TerrainBake.encodeSlice(snapshotOf(0, 0, 9, 7, flat, every)))
			expect(none.holes).to.equal(63)
		end)

		it("328k-3 round-trips a slice at 1/64 of a stud, under one voxel's own occupancy step", function()
			local snap = snapshotOf(0, 0, 9, 7, function(x: number, z: number): number
				return 100 + x * 0.01 - z * 0.013
			end)
			local back = TerrainBake.decodeSlice(TerrainBake.encodeSlice(snap))
			local worst = 0
			for at = 1, 9 * 7 do
				worst = math.max(worst, math.abs(back.height[at] - snap.height[at]))
			end
			-- 1/64 = 0.015625 st, and a voxel's occupancy byte can only express 4/255 = 0.01569 st.
			expect(worst <= 1 / (2 * TerrainBake.SLICE_SCALE) + 1e-12).to.equal(true)
			expect(worst < Relief.VOXEL / 255).to.equal(true)
			TestKit.note(
				string.format("slice round trip: worst %.6f st, voxel step %.6f st", worst, Relief.VOXEL / 255)
			)
		end)

		it("328k-4 refuses a slice whose bytes do not match the lattice it claims", function()
			local function bad()
				return TerrainBake.decodeSlice({ nx = 4, nz = 4, b64 = FIXTURE_B64 })
			end
			expect(bad).to.throw()
			local function empty()
				return TerrainBake.decodeSlice({ nx = 0, nz = 0, b64 = "" })
			end
			expect(empty).to.throw()
		end)

		it("328k-2c takes a slice's range over the columns that HAVE a height, never over a hole", function()
			-- A hole's code on the wire is 0, and `shapeTile` writes `snapshot.minY` wherever the reader
			-- has no answer. A range that counted holes therefore put a 0-stud floor under 100-stud
			-- ground, and the slope limiter drags the tile's own edge down to it (round-1 finding 1).
			local snap = snapshotOf(0, 0, 9, 7, function(): number
				return 120
			end, { [5] = true, [40] = true })
			local back = TerrainBake.decodeSlice(TerrainBake.encodeSlice(snap))
			expect(back.holes).to.equal(2)
			-- FAIL FIRST: the hole's own decoded height IS 0, so the range is the only thing keeping 0
			-- out of `minY`.
			expect(back.height[5]).to.equal(0)
			expect(back.minY).to.equal(120)
			expect(back.maxY).to.equal(120)
			-- AND WITH NO COLUMN AT ALL the sender's own number stands rather than a decoded 0.
			local every: { [number]: boolean } = {}
			for at = 1, 63 do
				every[at] = true
			end
			local blank = snapshotOf(0, 0, 9, 7, function(): number
				return 120
			end, every)
			blank.minY, blank.maxY = 111, 111
			local none = TerrainBake.decodeSlice(TerrainBake.encodeSlice(blank))
			expect(none.minY).to.equal(111)
		end)

		it("328k-5 answers nil at a hole, and counts only the holes inside the tile", function()
			-- The reader must not answer a guessed height at a Water column.
			local snap = snapshotOf(0, 0, 4, 4, flat, { [6] = true })
			local read = TerrainBake.readerFor(snap)
			expect(read(2, 2)).to.equal(100)
			expect(read(6, 6)).to.equal(nil)
			-- A HOLE IN THE PAD ONLY BLURS; A HOLE IN THE TILE IS GROUND THE BAKE WOULD INVENT.
			local pad = TerrainBake.padFor()
			local v = Relief.VOXEL
			local tile = { minX = 0, minZ = 0 }
			local wide = (TerrainBake.TILE_STUDS + 2 * pad) / v
			local inside = snapshotOf(-pad, -pad, wide, wide, flat, {})
			local centre = (pad / v) * wide + pad / v + 1
			expect(TerrainBake.holesInTile(inside, tile)).to.equal(0);
			(inside.hole :: any)[1] = true
			expect(TerrainBake.holesInTile(inside, tile)).to.equal(0);
			(inside.hole :: any)[centre] = true
			expect(TerrainBake.holesInTile(inside, tile)).to.equal(1)
		end)

		it("328k-6 REFUSES a tile with no slice, a slice that misses the pad, and a hole in the tile", function()
			local plan = TerrainBake.tilePlan(TerrainBake.regionFor({ "C1" }))
			local tile = plan[1]
			local pad = TerrainBake.padFor()
			local v = Relief.VOXEL
			local wide = (TerrainBake.TILE_STUDS + 2 * pad) / v

			-- (a) NO SLICE AT ALL. This is the whole of B2: before 328k `bakeTileAt` read the base
			-- LIVE here, so a second bake read its own first bake.
			local none = TerrainBake.bakeTileAt(1, { "C1" }, true, { {} :: any }, nil)
			expect(none.message).never.to.equal(nil)
			expect(string.find(none.message :: string, "no base snapshot slice", 1, true)).never.to.equal(nil)
			expect(none.voxels).to.equal(0)

			-- (b) A SLICE THAT DOES NOT REACH THE PAD: the limiter and the blur would read nil at
			-- the edge, and `shapeTile` would KEEP GROUND there -- a seam dressed as a snapshot.
			local short = TerrainBake.encodeSlice(snapshotOf(tile.minX, tile.minZ, 32, 32, flat, {}))
			local missed = TerrainBake.bakeTileAt(1, { "C1" }, true, { {} :: any }, short)
			expect(string.find(missed.message :: string, "does not cover tile", 1, true)).never.to.equal(nil)

			-- (c) A HOLE INSIDE THE TILE: refused, never guessed.
			local holed = snapshotOf(tile.minX - pad, tile.minZ - pad, wide, wide, flat, {});
			(holed.hole :: any)[(pad / v) * wide + pad / v + 1] = true
			local refused = TerrainBake.bakeTileAt(1, { "C1" }, true, { {} :: any }, TerrainBake.encodeSlice(holed))
			expect(string.find(refused.message :: string, "no single height", 1, true)).never.to.equal(nil)
			expect(string.find(refused.message :: string, "REFUSED, never guessed", 1, true)).never.to.equal(nil)
			expect(string.find(refused.message :: string, "1 inside the tile and 0 in its", 1, true)).never.to.equal(
				nil
			)

			-- (d) A HOLE IN THE PAD IS REFUSED TOO. The blur reads 72 studs out and the limiter 128, so a
			-- hole out there reaches the tile's own columns through the limiter's relaxation. Before 328k
			-- the snapshot call refused the whole tile+pad read, so refusing on the tile alone was a
			-- loosening, not a rule (Reviewer, round 1, finding 1).
			local padHole = snapshotOf(tile.minX - pad, tile.minZ - pad, wide, wide, flat, {});
			(padHole.hole :: any)[1] = true
			local outside = TerrainBake.bakeTileAt(1, { "C1" }, true, { {} :: any }, TerrainBake.encodeSlice(padHole))
			expect(string.find(outside.message :: string, "0 inside the tile and 1 in its", 1, true)).never.to.equal(
				nil
			)
			expect(TerrainBake.holesInTile(TerrainBake.decodeSlice(TerrainBake.encodeSlice(padHole)), tile)).to.equal(0)

			-- AND A CLEAN SLICE THAT DOES COVER IT GETS PAST ALL THREE, on to the profiles check --
			-- so the refusals above are the arms they name and not one blanket stop.
			local clean = snapshotOf(tile.minX - pad, tile.minZ - pad, wide, wide, flat, {})
			local good = TerrainBake.bakeTileAt(1, { "C1" }, true, nil, TerrainBake.encodeSlice(clean))
			expect(string.find(good.message :: string, "no profiles were handed", 1, true)).never.to.equal(nil)
		end)

		it("328k-7 makes the long profiles REFUSE to run with no sampler", function()
			-- The default was a live raycast, and that is the measured drift: C1's lineMeanY went
			-- 108.88 -> 112.83 -> 114.81 over three bakes (ESCALATE.md, task 328e).
			local function noSampler()
				return TerrainBake.profilesFor({ "C1" })
			end
			expect(noSampler).to.throw()
			local caught: string? = nil
			local okRun = pcall(function()
				TerrainBake.profilesFor({ "C1" })
			end)
			if not okRun then
				local _, why = pcall(function()
					TerrainBake.profilesFor({ "C1" })
				end)
				caught = tostring(why)
			end
			expect(okRun).to.equal(false)
			expect(string.find(caught :: string, "no sampler", 1, true)).never.to.equal(nil)
		end)

		it("328k-8 answers exactly the points the sampler was given, and nil for any other", function()
			local sampler = TerrainBake.pointSampler({ -4700, -5300, 123.5, -4680, -5300, 124.25 })
			expect(sampler(-4700, -5300)).to.equal(123.5)
			expect(sampler(-4680, -5300)).to.equal(124.25)
			expect(sampler(-4690, -5300)).to.equal(nil)
			expect(sampler(-4700, -5280)).to.equal(nil)
		end)

		it("328k-9 names EVERY point the long profiles read, so the snapshot can answer all of them", function()
			-- THE STRONG FORM: build a sampler that knows ONLY `profileSamples`' points, and ask
			-- `profilesFor` for the same cell. A missing point makes `longProfile` return nil and
			-- the road disappears, so an equal profile set is proof the cover is complete.
			local function hill(x: number, z: number): number?
				return 100 + x * 0.004 - z * 0.003
			end
			local points = TerrainBake.profileSamples({ "C1" })
			expect(#points > 0).to.equal(true)
			expect(#points % 2).to.equal(0)
			local rows: { number } = {}
			for at = 1, #points - 1, 2 do
				table.insert(rows, points[at])
				table.insert(rows, points[at + 1])
				table.insert(rows, hill(points[at], points[at + 1]) :: number)
			end
			local direct = TerrainBake.profilesFor({ "C1" }, hill)
			local viaPoints = TerrainBake.profilesFor({ "C1" }, TerrainBake.pointSampler(rows))
			expect(#viaPoints).to.equal(#direct)
			expect(#direct > 0).to.equal(true)
			local worst = 0
			for index, row in direct do
				expect(viaPoints[index].road.id).to.equal(row.road.id)
				expect(#viaPoints[index].y).to.equal(#row.y)
				for at, y in row.y do
					worst = math.max(worst, math.abs(viaPoints[index].y[at] - y))
				end
			end
			expect(worst < 1e-9).to.equal(true)
			TestKit.note(
				string.format(
					"profileSamples: %d point(s) cover %d road profile(s); worst y difference %.2e st",
					#points // 2,
					#direct,
					worst
				)
			)
			-- FAIL FIRST: drop ONE point of C1's own main road and that road's profile goes away, so
			-- the case above would have caught an incomplete cover. It has to be one of the four
			-- roads this cell asks for -- dropping a sample of some other cell's east-west road
			-- costs a junction PIN, not a profile.
			local main = Grid.roadsOf("C1").main
			local dropped: { number } = {}
			local gone = 0
			for at = 1, #rows - 2, 3 do
				if gone == 0 and rows[at] == main.from and rows[at + 1] == main.at then
					gone += 1
				else
					table.insert(dropped, rows[at])
					table.insert(dropped, rows[at + 1])
					table.insert(dropped, rows[at + 2])
				end
			end
			expect(gone).to.equal(1)
			local short = TerrainBake.profilesFor({ "C1" }, TerrainBake.pointSampler(dropped))
			TestKit.note(
				string.format(
					"fail-first: dropping (%g,%g) leaves %d of %d profile(s)",
					main.from,
					main.at,
					#short,
					#direct
				)
			)
			expect(#short < #direct).to.equal(true)
		end)

		it("328k-10 keeps the snapshot's lattice on ExpandToGrid's own grid", function()
			-- A region whose edge is not a multiple of 4 used to store the RAW edge as the lattice
			-- origin while the columns were read on the expanded box: up to one voxel of shear.
			-- `regionFor` for one cell gives exactly such an edge, which is why this is here.
			local region = TerrainBake.regionFor({ "C1" })
			local v = Relief.VOXEL
			local ragged = region.minX % v ~= 0 or region.minZ % v ~= 0
			TestKit.note(
				string.format(
					"C1 region x[%g,%g] z[%g,%g]; 4-aligned=%s",
					region.minX,
					region.maxX,
					region.minZ,
					region.maxZ,
					tostring(not ragged)
				)
			)
			-- The tile lattice IS aligned, which is the discipline design 5.1 asserts, and that is
			-- why every pre-328k caller was safe.
			for _, tile in TerrainBake.tilePlan(region) do
				expect(tile.minX % v).to.equal(0)
				expect(tile.minZ % v).to.equal(0)
				expect((tile.minX - TerrainBake.padFor()) % v).to.equal(0)
			end
		end)
	end)
end
