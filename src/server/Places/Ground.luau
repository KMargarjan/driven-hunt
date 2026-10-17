--!strict
-- Places.Ground: THE SURFACE OF A DRIVE PLACE'S STRIP, and the only thing in this system that calls
-- `Terrain` at all.
--
-- Karen's goal sentence for task 193 begins *"so you goal fix terrain"*, and three of her four
-- reference frames are about a SURFACE: pale gravel, a grassy ride with two ruts, a dirt double track
-- under brown leaves. Trees alone do not answer that.
--
-- `Terrain:ReplaceMaterial`, NEVER `FillBlock`. It changes the MATERIAL of the voxels in a region and
-- leaves the shape exactly as it was -- which is the only call that can re-surface 29-37 studs of
-- relief without flattening it.
--   https://create.roblox.com/docs/reference/engine/classes/Terrain#ReplaceMaterial
-- `FillBlock` is refused here, and the refusal is already paid for: `Lobby.Field`'s header records
-- what a flat slab costs on sloping ground, and task 191 measured a voxelised surface sitting 0.752
-- studs off its nominal shelf.
--
-- `terrain` IS AN ARGUMENT AND NEVER `Workspace.Terrain`, which is what keeps the harness out of it:
-- a spec hands in a fake with a recording `ReplaceMaterial`, so no spec in the DEV place can write
-- DEV's terrain, ever. That is `Lobby.Field`'s own discipline, borrowed whole.
--
-- THE ROLLBACK IS THAT THERE IS NOTHING TO ROLL BACK: this runs inside a Play session, and a Play
-- session's terrain write is discarded when Play stops.
--
-- **THAT PROPERTY IS CARRIED, NOT VERIFIED.** It is what `Lobby.Field` has relied on in this same
-- place since task 178, and the design (section 18) flags that it was never re-tested; task 193 did
-- not re-test it either, and says so in `reviews/task-193/REQUEST.md`. The paint runs only from the
-- boot, i.e. only inside Play, so no Edit-time write exists for anybody to inspect. If the property
-- ever turns out false the strip paint is a change to Karen's place file, which is rule 7 territory
-- (design section 18's own words) -- so it is stated here as an assumption rather than a fact.
--
-- Design: docs/design/drive-places.md (sections 6.3 and 7)
-- Note:   docs/research/2026-10-17-four-driven-hunt-places.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Forest = require(ReplicatedStorage:WaitForChild("ForestTest"))

local Ground = {}

-- THE ENGINE'S TERRAIN VOXEL, and the only value `ReplaceMaterial` accepts.
Ground.RESOLUTION = 4

-- THE WIDEST CHUNK ALONG x. A region is a box, so a long strip is painted in pieces, each centred on
-- the line's own z at its middle -- and for a CURVED line the chunk has to be short enough that the
-- line never leaves the box.
--
-- THE 200 THAT SHIPPED WAS WRONG AND ITS JUSTIFICATION WAS ARITHMETICALLY FALSE (Reviewer, round 1
-- after the PASS, finding 1). The header claimed *"a 5-stud error at a chunk's edge, inside the
-- band's own half-width"* on the grounds that *"no shipped plan paints a curve"*. Place 1 IS a curve
-- (`amplitudeStuds` 30 over a 440-stud wavelength) and it now has a surface row, and 200 studs is 2.86
-- radians of phase -- so the error reaches the full amplitude. Computed from the shipped numbers: the
-- chunk [2630, 2830] got the band -2080.7..-2058.7 while the road's own z at x 2830 is -2105.4, **21
-- studs outside it** -- and stands 2 and 8, two of the five the Director measured as grass, were left
-- unpainted.
--
-- SO THE CHUNK IS DERIVED FROM THE CURVE, not chosen (`Ground.chunkFor`). This is only the cap for a
-- straight line, where one box covers everything.
Ground.CHUNK_STUDS = 200

-- THE SHORTEST CHUNK WORTH MAKING: two voxels. Below this the region is thinner than the grid it is
-- snapped to and the call does nothing but cost.
Ground.MIN_CHUNK_STUDS = 8

-- WHAT IS REPLACED. **EVERY GROUND MATERIAL THIS WORLD HOLDS, AND THE DIRECTOR'S LOOK IS WHY THE LIST
-- GREW.** It shipped as Grass and LeafyGrass only, on the reasoning that *"those are the world's own
-- rock and made ground, and turning them into soil would be inventing geology"*. Then the frames came
-- back and the Director, 2026-10-17: place 3 *"the hunter stands on GREY ASPHALT-LOOKING ground"*,
-- place 4 *"grey ground again"*.
--
-- IT WAS A MEASUREMENT, NOT A MATTER OF TASTE: along the cut line's own strip **13 of 42 samples are
-- Asphalt**, and along the forest road's **23 of 42** -- more than half of the track Karen was looking
-- at. A paint that skips the greys skips exactly the patches she objected to, so the list is now the
-- whole surface. The STRIP is what gets re-surfaced and nothing else: its width is 18-64 studs
-- against this world's thousands, so no rock outside a track is touched.
Ground.SOURCE_MATERIALS = table.freeze({
	Enum.Material.Grass,
	Enum.Material.LeafyGrass,
	Enum.Material.Asphalt,
	Enum.Material.Limestone,
	Enum.Material.Mud,
	Enum.Material.Ground,
	Enum.Material.Rock,
	Enum.Material.Slate,
	Enum.Material.Sand,
	Enum.Material.Sandstone,
})

-- HOW FAR THE REGION REACHES ABOVE AND BELOW THE GROUND IT MEASURED. The surface is voxelised, so a
-- region that stops exactly at the measured height leaves the half-voxel above it untouched.
Ground.Y_PAD_STUDS = 10

-- HOW LONG A CHUNK MAY BE FOR THIS LINE. PURE.
--
-- A sine of amplitude `a` and wavelength divisor `w` has |dz/dx| at most `a / w`, so over a half-chunk
-- `c / 2` the line wanders at most `c * a / (2 * w)` from the box's own centre line. That has to stay
-- inside the band's USABLE half-width, which gives `c <= 2 * (half - RESOLUTION) * w / a` -- the grid
-- snap costs one column (see below). For place 1 -- half 11, a 30, w 70 -- that is **32 studs**,
-- against the 200 that shipped.
--
-- A STRAIGHT LINE WANDERS NOWHERE, so it keeps the full `CHUNK_STUDS` and one box covers 200 studs of
-- it.
function Ground.chunkFor(layout: any, surface: any): number
	local amplitude = layout.amplitudeStuds
	if amplitude == nil or amplitude <= 0 then
		return Ground.CHUNK_STUDS
	end
	local divisor = Forest.SHAPE.wavelengthDivisor
	-- THE BAND IS SNAPPED TO THE GRID, SO IT IS NOT SYMMETRICAL ABOUT THE LINE, and the chunk has to
	-- pay for that. `bandBounds` puts the first column at or below `z - half`, so the band reaches at
	-- least `half` BELOW the chunk's centre line but only `half - RESOLUTION` above it in the worst
	-- phase. The harness caught the first version of this arithmetic for exactly that reason
	-- (`places.spec:827`): chunk 51 let the line wander 10.9 studs into an upward reach of 8.
	local usable = math.max(Ground.RESOLUTION, surface.halfWidthStuds - Ground.RESOLUTION)
	local longest = 2 * usable * divisor / amplitude
	return math.max(Ground.MIN_CHUNK_STUDS, math.min(Ground.CHUNK_STUDS, math.floor(longest)))
end

-- THE GRID-ALIGNED z BOUNDS OF ONE BAND, and the painted width that follows. PURE.
--
-- `Region3:ExpandToGrid` ROUNDS OUTWARD, so a band whose nominal edges straddle a voxel column comes
-- out WIDER than it was asked to be -- and by how much depends on the accident of the line's own z
-- parity. The Reviewer measured it (round 1 after the PASS, finding 2): the ride's ruts, asked for at
-- 4 studs, were painted **8** because its centre z is a multiple of 4, while the forest road's came
-- out at 4 because its z happens to be 2 off the grid. A rut's width must not depend on where the
-- line was put.
--
-- So the bounds are snapped HERE, to the column the centre falls in, widened by whole columns until
-- the asked-for width is covered. `ExpandToGrid` then has nothing left to do and the painted width is
-- `ceil(2 * half / RESOLUTION) * RESOLUTION` for every line, whatever its parity.
function Ground.bandBounds(centreZ: number, half: number): (number, number)
	local columns = math.max(1, math.ceil((2 * half) / Ground.RESOLUTION))
	local first = Ground.RESOLUTION * math.floor((centreZ - columns * Ground.RESOLUTION / 2) / Ground.RESOLUTION)
	return first, first + columns * Ground.RESOLUTION
end

-- THE Y BAND THE STRIP OCCUPIES: the terrain measured every 20 studs along the strip's own centre
-- line, lowest and highest, padded. PURE given the reader -- `terrainYAt` is handed in, so a spec can
-- drive it with a fake hillside.
--
-- IT IS MEASURED AND NOT DERIVED FROM `centre.Y`, because `centre.Y` is a FALLBACK ground (task 179's
-- design 3.4) and this ground rolls 29-37 studs along a stand line.
function Ground.yBandOf(
	layout: any,
	surface: any,
	lineZ: (number) -> number,
	terrainYAt: (number, number) -> number?
): (number?, number?)
	if surface == nil then
		return nil, nil
	end
	local low, high = math.huge, -math.huge
	local from, to = layout.centre.X - surface.plotHalfWidthStuds, layout.centre.X + surface.plotHalfWidthStuds
	for x = from, to, 20 do
		local y = terrainYAt(x, lineZ(x))
		if y ~= nil then
			low, high = math.min(low, y), math.max(high, y)
		end
	end
	if low == math.huge then
		return nil, nil
	end
	return low - Ground.Y_PAD_STUDS, high + Ground.Y_PAD_STUDS
end

-- PAINT THE STRIP, AND ITS TWO WHEEL RUTS. Returns how many `ReplaceMaterial` calls it made -- 0 for
-- a place with no `SURFACES` row, which is the field edge (its field is grass, and `Ground` there
-- would be a ploughed field, a different place from karen-ref-6).
--
-- `ExpandToGrid(RESOLUTION)` IS NOT TIDINESS. A region whose edge falls off the 4-stud grid leaves
-- the voxels it clips with their old material, which is what task 191 measured as *"623 Ground and
-- 2 Grass"* over a rectangle that should have been uniform.
function Ground.paint(
	terrain: any,
	layout: any,
	surface: any,
	lineZ: (number) -> number,
	terrainYAt: (number, number) -> number?
): number
	if surface == nil or terrain == nil then
		return 0
	end
	local low, high = Ground.yBandOf(layout, surface, lineZ, terrainYAt)
	if low == nil or high == nil then
		return 0
	end
	local calls = 0
	local from, to = layout.centre.X - surface.plotHalfWidthStuds, layout.centre.X + surface.plotHalfWidthStuds
	local chunk = Ground.chunkFor(layout, surface)
	local x = from
	while x < to do
		local nextX = math.min(x + chunk, to)
		local z = lineZ((x + nextX) / 2)
		-- THE STRIP FIRST, THEN THE RUTS OVER IT. The order is the whole of it: a rut painted before
		-- the strip would be painted straight back over, because the strip's own material is in
		-- `SOURCE_MATERIALS` now.
		calls += Ground.band(terrain, x, nextX, low, high, z, surface.halfWidthStuds, surface.material)
		local ruts = surface.ruts
		if ruts ~= nil then
			-- TWO WHEEL RUTS, which is what karen-ref-5 and karen-ref-1 both actually show: not one
			-- bare track but two darker lines with something growing between them. They are STRIPS OF
			-- MATERIAL AND NOT TRENCHES -- a terrain voxel is 4 studs (1.1 m) and a rut is a hand deep,
			-- so cutting one is not reachable and is stated rather than faked (note section 5 item 3).
			for _, side in ipairs({ -1, 1 }) do
				calls += Ground.band(
					terrain,
					x,
					nextX,
					low,
					high,
					z + side * ruts.offsetStuds,
					ruts.halfWidthStuds,
					ruts.material
				)
			end
		end
		x = nextX
	end
	return calls
end

-- ONE BAND OF ONE MATERIAL OVER ONE CHUNK: the strip, or one rut. Split out because the two are the
-- same call with different numbers, and because a spec can then count bands rather than chunks.
function Ground.band(
	terrain: any,
	fromX: number,
	toX: number,
	low: number,
	high: number,
	centreZ: number,
	half: number,
	material: Enum.Material
): number
	-- THE z BOUNDS ARE SNAPPED BEFORE THE REGION IS MADE, so `ExpandToGrid` only ever squares up the x
	-- and y faces and the painted WIDTH is the one asked for (see `bandBounds`).
	local minZ, maxZ = Ground.bandBounds(centreZ, half)
	local region = Region3.new(Vector3.new(fromX, low, minZ), Vector3.new(toX, high, maxZ))
		:ExpandToGrid(Ground.RESOLUTION)
	local calls = 0
	for _, source in ipairs(Ground.SOURCE_MATERIALS) do
		if source ~= material then
			terrain:ReplaceMaterial(region, Ground.RESOLUTION, source, material)
			calls += 1
		end
	end
	return calls
end

return Ground
