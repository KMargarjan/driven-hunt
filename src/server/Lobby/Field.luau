--!strict
-- Lobby.Field: THE ONE WRITER OF THE LOBBY'S TERRAIN, and the only thing in this system that touches
-- `Terrain` at all. Two `FillBlock` calls inside one rectangle: grass up to the shelf, air above it.
--
--   Terrain:FillBlock https://create.roblox.com/docs/reference/engine/classes/Terrain#FillBlock
--   Enum.Material     https://create.roblox.com/docs/reference/engine/enums/Material
--
-- WHY TERRAIN AND NOT A SLAB OF PARTS (research note section 6). The measured ground over this
-- footprint spans 16 studs, so a flat slab's downhill edge would FLOAT 16 studs in the air -- which
-- is precisely the failure this project was built to stop ("Things measured correct and looked
-- wrong", docs/PROJECT_CONTEXT.md). A cut-and-filled shelf meets the hillside in a STEP instead, and
-- a step in a grass bank is what a farmyard terrace on a slope actually looks like.
--
-- THE OWNER BOUNDARY, WRITTEN OUT BECAUSE IT MOVED (design section 3.1). `MapGen.Ground`'s header
-- says it is *"THE ONLY WRITER OF `Terrain` IN THE REPO"*, and since this task that sentence needs a
-- qualifier -- so this module and that one cannot meet, by three independent facts:
--   * A DIFFERENT WORLD. `Lobby.anchorFor` has a row for `forest-test` and none for `map:v1`, so
--     nothing here runs in the DEV place at all.
--   * A DIFFERENT MODE. `MapGen` runs at EDIT time, driven step by step by `tools/mapgen.py`; this
--     runs only inside a running session, and a Play-session terrain write does not persist.
--   * A BOUNDED RECTANGLE. Every region this module computes is inside `CONFIG.FIELD`, and
--     `lobby.spec` asserts every corner of both blocks against it.
--
-- `terrain` IS AN ARGUMENT AND NEVER `Workspace.Terrain`, which is what keeps the harness out of it:
-- a spec hands in a fake with a recording `FillBlock`, so no spec in the DEV place can write DEV's
-- terrain, ever (design section 16.1 case 6).
--
-- Design: docs/design/lobby.md (sections 9, 9.1)
-- Note:   docs/research/2026-10-13-lobby-and-the-truck.md (section 6)
local Field = {}

-- PURE. The CFrame and Size of the GRASS block: a solid slab whose TOP IS THE SHELF and whose bottom
-- reaches `DEPTH_STUDS` below it, so it meets undisturbed ground even on the lowest corner.
function Field.grassBlock(anchor: Vector3, shelfY: number, cfg): (CFrame, Vector3)
	local span = cfg.FIELD.SPAN_STUDS
	local depth = cfg.FIELD.DEPTH_STUDS
	return CFrame.new(anchor.X, shelfY - depth / 2, anchor.Z), Vector3.new(span, depth, span)
end

-- PURE. The AIR block that cuts the hill off: it starts AT the shelf (so it never eats the grass
-- below it) and rises `CLEAR_STUDS`, which is well over the worst measured ground spread and well
-- above the lodge's own ridge.
function Field.airBlock(anchor: Vector3, shelfY: number, cfg): (CFrame, Vector3)
	local span = cfg.FIELD.SPAN_STUDS
	local clear = cfg.FIELD.CLEAR_STUDS
	return CFrame.new(anchor.X, shelfY + clear / 2, anchor.Z), Vector3.new(span, clear, span)
end

-- IS EVERY CORNER OF THIS BOX INSIDE THE FIELD'S OWN RECTANGLE? PURE, and it is the rule
-- *"it writes nothing outside `FIELD`"* made checkable rather than promised. The y is not bounded:
-- the rectangle is a footprint.
function Field.insideField(anchor: Vector3, at: CFrame, size: Vector3, cfg): boolean
	local half = cfg.FIELD.SPAN_STUDS / 2
	local centre = at.Position
	local dx, dz = size.X / 2, size.Z / 2
	return math.abs(centre.X - anchor.X) + dx <= half + 1e-6 and math.abs(centre.Z - anchor.Z) + dz <= half + 1e-6
end

-- THE BOX SPLIT INTO CHUNKS ALONG X. PURE, and it exists because `MapGen.Ground`'s header records a
-- MEASURED per-region voxel ceiling in this Studio version (24,576 for `WriteVoxels`). `FillBlock`
-- is a different API and its own ceiling is not measured here, so the fill is chunked the way
-- `Ground.paintTrack` already chunks its regions: one shape, whatever the ceiling turns out to be.
-- A chunk width at or over the span returns the single box unchanged.
function Field.chunks(at: CFrame, size: Vector3, chunkStuds: number): { { at: CFrame, size: Vector3 } }
	local out = {}
	local width = math.max(1, chunkStuds)
	if size.X <= width then
		table.insert(out, { at = at, size = size })
		return out
	end
	local centre = at.Position
	local minX = centre.X - size.X / 2
	local left = size.X
	local x = minX
	while left > 1e-6 do
		local take = math.min(width, left)
		table.insert(out, {
			at = CFrame.new(x + take / 2, centre.Y, centre.Z),
			size = Vector3.new(take, size.Y, size.Z),
		})
		x += take
		left -= take
	end
	return out
end

-- THE ONLY TERRAIN WRITE IN THIS SYSTEM. Grass FIRST and then air: the grass block's top IS the
-- shelf, and the air block removes whatever hill stood above it. The other order would fill the hole
-- the air had just made.
--
-- Returns how many `FillBlock` calls it made and how many of them were grass, so "which path it
-- took" is a number in `Lobby.stats()` and not a belief (design section 18 item 1).
function Field.fill(terrain: any, anchor: Vector3, shelfY: number, cfg): (number, number)
	local chunk = cfg.FIELD.CHUNK_STUDS
	local calls, grassCalls = 0, 0
	local grassAt, grassSize = Field.grassBlock(anchor, shelfY, cfg)
	for _, piece in ipairs(Field.chunks(grassAt, grassSize, chunk)) do
		terrain:FillBlock(piece.at, piece.size, cfg.FIELD.MATERIAL)
		calls += 1
		grassCalls += 1
	end
	local airAt, airSize = Field.airBlock(anchor, shelfY, cfg)
	for _, piece in ipairs(Field.chunks(airAt, airSize, chunk)) do
		terrain:FillBlock(piece.at, piece.size, Enum.Material.Air)
		calls += 1
	end
	return calls, grassCalls
end

return Field
