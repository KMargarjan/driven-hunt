# Archived 2026-11-02, task 328e: Ground.paintRoads and grid.spec case 19

Rule 7. Archived, not deleted. Design: docs/design/grid-terrain.md sections 2, 3.1 and 16 --
"the Edit-time tile pass writes shape and material together", so a run-time painter is a second
writer of the same voxels. Section 16's row for task 328e: archive `Ground.paintRoads` AND
`grid.spec`'s case 19 IN THE SAME COMMIT, because a case asserting an archived function is a
false-PASS path.

WHAT REPLACES IT: `ServerStorage.TerrainBake`, driven by `tools/terrainbake.py` in Karen's Forest
Test at EDIT time. It writes height and material in the SAME `WriteVoxels` call, so the road's
material can never disagree with the road's shape. MEASURED in her place 2026-11-02 after the
328d bake (`<runs-dir>/328e-xsec-BEFORE.json`): on EW2, Ground over the carriageway, Mud ruts at
|d| 6..9, a Mud ditch 1.98 studs below the crown at |d| 21..25, Grass verge to |d| 34. That is
design 7.1's cross-section, which an 18-stud flat `Ground` strip cannot be.

ROLLBACK: restore the two blocks below, put `report.gridPaints` back in `src/server/Places/init.luau`
(three places) and the "%d road paint call(s)" clause back in `src/server/ForestTestBoot.server.luau`,
and re-add the `off.gridPaints` assertion to `tests/server/grid.spec.luau` case 22.

`Grid.CONFIG.roadPaintStuds` (18) is LEFT IN PLACE: it is data, `docs/design/grid-map.md` section
8.3 quotes it, and nothing reads it now.

## src/server/Places/Ground.luau

```luau
-- ---------------------------------------------------------------- THE GRID'S ROADS (task 327a)

-- HOW LONG ONE ROAD CHUNK MAY BE, AND IT IS DERIVED FROM THE CALL BUDGET rather than chosen.
--
-- `Ground.band` makes ONE `ReplaceMaterial` call PER SOURCE MATERIAL, and `SOURCE_MATERIALS` holds
-- ten -- so a band whose own material is in that list costs NINE calls, not the two
-- `docs/design/grid-map.md` section 8.3 assumed when it set the 300-call budget. The grid's eight
-- roads are 3 x 4490 + 5 x 2986 = 28,400 studs, so the budget fixes the chunk:
--
--   chunk >= 28,400 x 9 / 300 = 852   ->  1000, which gives 3 x 5 + 5 x 3 = 30 bands = 270 calls
--
-- AND THE GRID'S ROADS CARRY NO WHEEL RUTS, for the same arithmetic: two rut bands per chunk would
-- treble that to 810. A `track` rut is karen-ref-1's NEAR view; 1.26 km of forest road seen from a
-- stand is the 18-stud `Ground` strip, which is what section 4.1 asks for.
Ground.ROAD_CHUNK_STUDS = 1000

-- THE BUDGET SECTION 8.3 SETS, asserted by `grid.spec` rather than trusted.
Ground.ROAD_CALL_BUDGET = 300

-- HOW MANY CALLS MAY LAND IN ONE FRAME. The paint runs once at boot, and a boot that stalls is a
-- boot Karen sees as a freeze.
Ground.ROAD_CALLS_PER_STEP = 2

-- ONE ROAD'S CHUNKS, AS EVEN SPANS. PURE. A road is STRAIGHT, so a chunk never wanders off its own
-- centre line and `Ground.chunkFor`'s curve arithmetic has nothing to do here.
function Ground.roadChunks(road: any): { { from: number, to: number } }
	local length = road.to - road.from
	local pieces = math.max(1, math.ceil(length / Ground.ROAD_CHUNK_STUDS))
	local each = length / pieces
	local out: { { from: number, to: number } } = {}
	for index = 1, pieces do
		table.insert(out, { from = road.from + (index - 1) * each, to = road.from + index * each })
	end
	return out
end

-- THE Y BAND ONE CHUNK OCCUPIES: the terrain sampled every 20 studs along the chunk's own centre
-- line, lowest and highest, padded. PURE given the reader. It is PER CHUNK and not per road, because
-- this footprint rolls 241 studs end to end (task 327a's survey) and one band over all of it would
-- paint a region sixty voxels taller than the ground it is re-surfacing.
function Ground.roadYBand(
	road: any,
	from: number,
	to: number,
	terrainYAt: (number, number) -> number?
): (number?, number?)
	local low, high = math.huge, -math.huge
	for at = from, to, 20 do
		local y = if road.axis == "x" then terrainYAt(at, road.at) else terrainYAt(road.at, at)
		if y ~= nil then
			low, high = math.min(low, y), math.max(high, y)
		end
	end
	if low == math.huge then
		return nil, nil
	end
	return low - Ground.Y_PAD_STUDS, high + Ground.Y_PAD_STUDS
end

-- ONE BAND OF ONE MATERIAL OVER ONE CHUNK OF ONE ROAD, either axis. `Ground.band` is x-ranged with a
-- centre z and so can only paint an east-west line; this is its twin for both.
--
-- THE CROSS-AXIS BOUNDS ARE SNAPPED BY `Ground.bandBounds`, exactly as `Ground.band` does it, so the
-- painted width is `ceil(2 * half / RESOLUTION) * RESOLUTION` whatever the road's own parity is --
-- the defect the Reviewer measured on the ride's ruts (that function's header).
function Ground.roadBand(
	terrain: any,
	road: any,
	from: number,
	to: number,
	low: number,
	high: number,
	half: number,
	material: Enum.Material,
	-- CALLED AFTER EVERY `ReplaceMaterial`, so the slice is per CALL and not per band: a band is nine
	-- calls over one region, and nine in a frame is four and a half times the budget section 8.3 set.
	onCall: (() -> ())?
): number
	local nearSide, farSide = Ground.bandBounds(road.at, half)
	local region = if road.axis == "x"
		then Region3.new(Vector3.new(from, low, nearSide), Vector3.new(to, high, farSide))
		else Region3.new(Vector3.new(nearSide, low, from), Vector3.new(farSide, high, to))
	region = region:ExpandToGrid(Ground.RESOLUTION)
	local calls = 0
	for _, source in ipairs(Ground.SOURCE_MATERIALS) do
		if source ~= material then
			terrain:ReplaceMaterial(region, Ground.RESOLUTION, source, material)
			calls += 1
			if onCall ~= nil then
				onCall()
			end
		end
	end
	return calls
end
```

## src/server/Places/init.luau -- the one call site

```luau
	-- THE SURFACE IS THE `track` PLACE'S, which is the one Karen's reference frames demand: an
	-- 18-stud `Ground` strip (design 4.1). The ruts are NOT painted on a grid road -- see
	-- `Ground.ROAD_CHUNK_STUDS` for the call arithmetic that decides it.
	report.gridPaints = Ground.paintRoads(terrain, Grid.roads(), Plan.surfaceFor("track"), reader, previewOn, breathe)
	local gridFolder: Instance? = nil
```

## tests/server/grid.spec.luau -- case 19

```luau
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

```
