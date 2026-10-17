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
local Ground = {}

-- THE ENGINE'S TERRAIN VOXEL, and the only value `ReplaceMaterial` accepts.
Ground.RESOLUTION = 4

-- ONE CALL PER CHUNK ALONG x. A region is a box, so a long strip is painted in pieces -- and for a
-- curved layout each piece is centred on the line's own z at the chunk's middle, which over the
-- road's amplitude 30 and wavelength 440 would be a 5-stud error at a chunk's edge, inside the band's
-- own half-width. No shipped plan paints a curve (section 7.3), and this is written down so the next
-- reader does not have to derive it.
Ground.CHUNK_STUDS = 200

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
	local x = from
	while x < to do
		local nextX = math.min(x + Ground.CHUNK_STUDS, to)
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
	local region = Region3.new(Vector3.new(fromX, low, centreZ - half), Vector3.new(toX, high, centreZ + half))
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
