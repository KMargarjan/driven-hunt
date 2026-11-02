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

		it("brings every 16-stud window under the ceiling in 8 passes, at both ceilings", function()
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
				-- 0.5 degrees of slack: 8 passes is the design's number, and relaxation converges
				-- to the ceiling rather than landing exactly on it (MEASURED, task 328c).
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

		it("keeps a tile inside the MEASURED 24,576-voxel ceiling, and says when it must split", function()
			-- 128 studs is 32 columns; the Y band is the tile's own relief plus 16 below and 32 above.
			local function layersFor(reliefStuds: number): number
				return math.ceil((reliefStuds + 16 + 32) / Relief.VOXEL)
			end
			expect(32 * 32 * layersFor(0) <= 24576).to.equal(true)
			-- 24 layers is 96 studs, the measured ceiling: a 48-stud band fits exactly.
			expect(layersFor(48)).to.equal(24)
			expect(32 * 32 * layersFor(48)).to.equal(24576)
			-- One stud more and the tile MUST split -- the bake never assumes one call is enough.
			expect(32 * 32 * layersFor(49) > 24576).to.equal(true)
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
			local moved = table.clone(Grid.CONFIG)
			expect(Relief.epochInput(Relief.LANDFORMS, moved)).to.equal(once)
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
			local ALLOWED = { ["ServerScriptService.Lobby.Field"] = true, ["ServerScriptService.Places.Ground"] = true }
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
							local writes = string.find(got, "WriteVoxels", 1, true)
								or string.find(got, ":FillBlock", 1, true)
								or string.find(got, ":ReplaceMaterial", 1, true)
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
end
