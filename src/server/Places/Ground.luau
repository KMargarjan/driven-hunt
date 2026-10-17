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

-- WHAT IS REPLACED, AND NOTHING ELSE. A strip that crosses the Limestone, Asphalt or Mud this world
-- also holds (BRIEF M4) KEEPS IT: those are the world's own rock and made ground, and turning them
-- into soil would be inventing geology rather than laying a track.
Ground.SOURCE_MATERIALS = table.freeze({ Enum.Material.Grass, Enum.Material.LeafyGrass })

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
	plan: any,
	lineZ: (number) -> number,
	terrainYAt: (number, number) -> number?
): (number?, number?)
	local surface = plan ~= nil and plan.surface or nil
	if surface == nil then
		return nil, nil
	end
	local low, high = math.huge, -math.huge
	local from, to = layout.centre.X - plan.plotHalfWidthStuds, layout.centre.X + plan.plotHalfWidthStuds
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

-- PAINT THE STRIP. Returns how many `ReplaceMaterial` calls it made -- 0 for a plan with no `surface`
-- row, which is three of the four places (section 7.3).
--
-- `ExpandToGrid(RESOLUTION)` IS NOT TIDINESS. A region whose edge falls off the 4-stud grid leaves
-- the voxels it clips with their old material, which is what task 191 measured as *"623 Ground and
-- 2 Grass"* over a rectangle that should have been uniform.
function Ground.paint(
	terrain: any,
	layout: any,
	plan: any,
	lineZ: (number) -> number,
	terrainYAt: (number, number) -> number?
): number
	local surface = plan ~= nil and plan.surface or nil
	if surface == nil or terrain == nil then
		return 0
	end
	local low, high = Ground.yBandOf(layout, plan, lineZ, terrainYAt)
	if low == nil or high == nil then
		return 0
	end
	local calls = 0
	local from, to = layout.centre.X - plan.plotHalfWidthStuds, layout.centre.X + plan.plotHalfWidthStuds
	local x = from
	while x < to do
		local nextX = math.min(x + Ground.CHUNK_STUDS, to)
		local middle = (x + nextX) / 2
		local z = lineZ(middle)
		local half = surface.halfWidthStuds
		local region = Region3.new(Vector3.new(x, low, z - half), Vector3.new(nextX, high, z + half))
			:ExpandToGrid(Ground.RESOLUTION)
		for _, source in ipairs(Ground.SOURCE_MATERIALS) do
			terrain:ReplaceMaterial(region, Ground.RESOLUTION, source, surface.material)
			calls += 1
		end
		x = nextX
	end
	return calls
end

return Ground
