--!strict
-- TerrainBake: THE ONLY WRITER OF **KAREN'S FOREST TEST** `Terrain`, at EDIT time, one tile per
-- call, driven by `tools/terrainbake.py`. It requires `ReplicatedStorage` modules only and takes
-- every other writer as an injected seam, so it never requires `ServerScriptService.Places`.
--
--   Terrain:WriteVoxels  https://create.roblox.com/docs/reference/engine/classes/Terrain#WriteVoxels
--   Terrain:ReadVoxels   https://create.roblox.com/docs/reference/engine/classes/Terrain#ReadVoxels
--   Region3:ExpandToGrid https://create.roblox.com/docs/reference/engine/datatypes/Region3
--
-- MEASURED 2026-09-26 and recorded by `MapGen.Config.VOXEL`: a 128 x 128 x 96-stud region at
-- resolution 4 is accepted (32 x 24 x 32 = 24,576 voxels); resolution 8 and 2 are both refused with
-- "Resolution has to be 4". The tile sits EXACTLY on that ceiling, so `bakeTile` splits its Y band
-- into stacked calls rather than assuming one call is enough.
--
-- Design: docs/design/grid-terrain.md (sections 3, 5, 7.1)
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GridFolder = ReplicatedStorage:WaitForChild("Grid")
local Grid = require(GridFolder)
local Relief = require(GridFolder:WaitForChild("Relief"))

local TerrainBake = {}

local AIR = Enum.Material.Air

-- Asserted by the tool before EVERY mutating call (design 6.2 item 2), and kept here so a hand-run
-- expression in the wrong place cannot reshape DEV.
TerrainBake.PLACE_ID = 130094961655666
TerrainBake.TILE_STUDS = 128
TerrainBake.MAX_VOXELS = 24576
-- ReadVoxels' own documented ceiling, which is far above WriteVoxels' measured one. A snapshot that
-- would pass it is refused with its size, not left to the engine to reject with no location.
-- https://create.roblox.com/docs/reference/engine/classes/Terrain#ReadVoxels
TerrainBake.MAX_READ_VOXELS = 4194304
TerrainBake.BAND_PAD = table.freeze({ belowStuds = 16, aboveStuds = 32 })
-- How far past a road centreline the bake owns the ground: the design's 34-stud verge plus the
-- 12-stud bank (7.1, last row). A `--cells` region is grown to this on each of the cell's roads.
TerrainBake.ROAD_HALF_STUDS = 46
-- HOW FAR PAST A TILE THE SHAPING GRID REACHES so the slope limiter does not depend on the tile
-- lattice (round-1 finding 2). `Relief.limitPass`' window is 16 studs and it makes 8 relaxation
-- passes, so influence travels up to 8 windows; 128 studs is that reach, and the margin is
-- discarded after the limit so only the inner 128-stud tile is written.
TerrainBake.LIMIT_MARGIN_STUDS = 128
-- SWARM 2.2 for B2: "Scree (Ground 70 / Rock 30) where the slope is 30-40 degrees". `materialAt`
-- answers Rock for the whole band; this is the 30 % of columns that keep it.
TerrainBake.SCREE_ROCK_SHARE = 0.3

-- THE STAND PAD (design 7.4): "the pad is level to +-0.25 st and the census measures relief
-- <= 1.8 st". 1.8 is `HighSeats.JUMP_RELIEF_STUDS` and 327b's instrument reads that roll over a
-- RING AT 12 STUDS, so the level core covers that ring plus one voxel column.
--   docs/design/grid-terrain.md section 7.4
TerrainBake.STAND_PAD = table.freeze({
	-- 12 is 327b's ring; +2 so the outermost ring sample is inside the level core, not on its lip.
	levelRadiusStuds = 14,
	-- OUT TO 22, THE DITCH LIP, AND NO FURTHER. A pad that reached the ditch band (realised d 19..27,
	-- design 7.1) would fill the ditch it is standing next to. 8 studs is also enough to rejoin a
	-- 10 % road: 14 st of held grade is 1.4 st, and smoothstep's worst gradient is 1.5*1.4/8 = 0.26,
	-- which is 14.7 degrees -- under `Relief.LIMIT_DEG.tree` 20, so the blend is never a cliff.
	blendStuds = 8,
	toleranceStuds = 0.25,
})

export type Bounds = Relief.Bounds

-- A SNAPSHOT IS THE BASE AND NOTHING ELSE. `heightAt` never reads live terrain, which is what makes
-- a re-run of the bake a no-op rather than a drift (design 5.3 step 2).
export type Snapshot = {
	pitch: number,
	minX: number,
	minZ: number,
	nx: number,
	nz: number,
	height: { number },
	-- THE SURFACE MATERIAL, where the reader kept it. `shapeTile` never reads it -- the bake paints
	-- from `Relief.materialAt` -- so a slice that arrives over the wire omits it rather than
	-- shipping 18,000 strings nothing looks at.
	material: { string }?,
	minY: number,
	maxY: number,
	-- A COLUMN WITH NO SINGLE HEIGHT: Water, an overhang, or no ground in the Y band. The index is
	-- `readerFor`'s own, and the reader answers nil there, so a hole is never a guessed zero
	-- (design 5.3 step 2, note 4 item 5).
	hole: { [number]: boolean }?,
	holes: number?,
	holeWhy: { string }?,
}

export type Tile = { minX: number, minZ: number }

-- ONE STAND'S LEVEL LANDING: where it is, and the height the ground is held at there.
export type StandPad = { x: number, z: number, y: number, cell: string, index: number }

export type TileReport = {
	minX: number,
	minZ: number,
	calls: number,
	voxels: number,
	bandMin: number,
	bandMax: number,
	elapsedMs: number,
	message: string?,
	-- WHICH CELLS THIS TILE RE-SHAPED AND WHY, printed by the tool and kept in the run log, so a
	-- run that silently skipped the landform cannot look like one that applied it.
	reshape: string?,
	-- THE STANDS `standPadsFor` COULD NOT PLACE A PAD UNDER, comma-separated and "" for none.
	padsMissed: string?,
}

-- ---------------------------------------------------------------- the region

-- THE REGION A RUN COVERS. All eight cells: the footprint plus `BLEND_STUDS` 200 and the border
-- wood's 230 (design 5.2). A subset: those cells and their roads plus `BLEND_STUDS`, so the result
-- returns to the base at the edge of what was actually baked and nowhere else.
function TerrainBake.regionFor(cellIds: { string }): Bounds
	assert(#cellIds > 0, "TerrainBake.regionFor: no cells")
	-- GROWN BY THE BEND (task 328q): every tile the curved road touches has to be re-written, and a
	-- box is the only thing `WriteVoxels` takes. 0 at the born amplitude, so the region is today's.
	local bend = Grid.maxBendStuds()
	if #cellIds == #Grid.cellIds() then
		local box = Grid.footprint()
		local pad = Relief.BLEND_STUDS + 230 + bend
		return { minX = box.minX - pad, maxX = box.maxX + pad, minZ = box.minZ - pad, maxZ = box.maxZ + pad }
	end
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, id in cellIds do
		local cell = Grid.boundsOf(id)
		local roads = Grid.roadsOf(id)
		minX = math.min(minX, cell.minX, roads.west.at - TerrainBake.ROAD_HALF_STUDS)
		maxX = math.max(maxX, cell.maxX, roads.east.at + TerrainBake.ROAD_HALF_STUDS)
		minZ = math.min(minZ, cell.minZ, roads.main.at - TerrainBake.ROAD_HALF_STUDS)
		maxZ = math.max(maxZ, cell.maxZ, roads.muster.at + TerrainBake.ROAD_HALF_STUDS)
	end
	local pad = Relief.BLEND_STUDS + bend
	return { minX = minX - pad, maxX = maxX + pad, minZ = minZ - pad, maxZ = maxZ + pad }
end

-- Pure, and it delegates: the tile lattice is `Relief.tiles`' arithmetic, never a second copy.
function TerrainBake.tilePlan(region: Bounds): { Tile }
	return Relief.tiles(region, TerrainBake.TILE_STUDS)
end

-- ---------------------------------------------------------------- the base snapshot

local function index(snapshot: Snapshot, i: number, k: number): number
	return (k - 1) * snapshot.nx + i
end

-- THE BASE READER a snapshot hands to `Relief.heightAt`: nil outside the snapshot, so a point the
-- bake has no base for is answered nil here. `shapeTile` then KEEPS the ground (`snapshot.minY`,
-- marked exempt) rather than cutting a hole; `bakeTileAt` refuses such a tile before that, so the
-- branch is a floor and not a guess the bake relies on.
local function readOne(snapshot: Snapshot, x: number, z: number): number?
	local i = math.floor((x - snapshot.minX) / snapshot.pitch) + 1
	local k = math.floor((z - snapshot.minZ) / snapshot.pitch) + 1
	if i < 1 or k < 1 or i > snapshot.nx or k > snapshot.nz then
		return nil
	end
	local at = index(snapshot, i, k)
	local hole = snapshot.hole
	if hole ~= nil and hole[at] == true then
		return nil
	end
	return snapshot.height[at]
end

-- `extras` ARE MORE SLICES OF THE SAME BASE FILE, tried in order when the first has no column
-- (task 328h). The bench is the one op that leaves its own tile: it walks the base over its band's
-- first `Relief.BENCH_ANCHOR_STUDS`, which can be a cell away in z, so the tool cuts that band as a
-- second rectangle rather than growing every tile's slice to the whole cell depth. Same `.bin`,
-- same bytes, same arithmetic -- only the reader's reach changes.
function TerrainBake.readerFor(snapshot: Snapshot, extras: { Snapshot }?): (number, number) -> number?
	return function(x: number, z: number): number?
		local here = readOne(snapshot, x, z)
		if here ~= nil then
			return here
		end
		if extras ~= nil then
			for _, extra in extras do
				local there = readOne(extra, x, z)
				if there ~= nil then
					return there
				end
			end
		end
		return nil
	end
end

-- WHY ONE COLUMN HAS NO SINGLE HEIGHT, or nil when it has one. FOUR SEPARATE ARMS, and they are
-- out here as a pure function so each can be ENTERED by a case rather than argued from the code
-- that happens to be near it (lesson L-093): Water has no single height, an overhang has two, an
-- empty column has none, and a column whose TOP voxel is solid has one the band cannot see.
-- Guessing any of them is how a bake silently fills a cave -- or flattens a hilltop.
--
-- THE CEILING ARM IS MEASURED, not imagined (2026-11-03). The whole-footprint read at a Y band of
-- -100..400 came back with `maxY` exactly 400.00: the walk takes the highest SOLID voxel inside the
-- band, so ground that continues above the band reports the band's own ceiling as its surface. That
-- is a truncated hilltop dressed as a height, and it is the one fault that looks like data.
function TerrainBake.columnFault(
	water: boolean,
	runs: number,
	hasTop: boolean,
	atCeiling: boolean,
	x: number,
	z: number,
	yMin: number,
	yMax: number
): string?
	if water then
		return string.format("Water at (%.0f, %.0f) has no single height", x, z)
	end
	if runs > 1 then
		return string.format("an overhang at (%.0f, %.0f): %d solid runs in one column", x, z, runs)
	end
	if not hasTop then
		return string.format("no ground at (%.0f, %.0f) in the Y band %.0f..%.0f", x, z, yMin, yMax)
	end
	if atCeiling then
		return string.format(
			"ground at (%.0f, %.0f) reaches the top of the Y band %.0f..%.0f, so its surface is above "
				.. "what was read: widen the band",
			x,
			z,
			yMin,
			yMax
		)
	end
	return nil
end

-- ONE REGION OF BASE TERRAIN, through `ReadVoxels`. REFUSES Water and REFUSES an overhang (two
-- separated solid runs in one column): neither has a single height, and guessing one is how a bake
-- silently fills a cave (design 5.3 step 2; note 4 item 5). `allowHoles` records such a column
-- instead, which is what the WHOLE-REGION base pass needs -- one pond must not lose a million
-- columns -- and `bakeTileAt` then refuses any tile whose own columns hold one.
--
-- THE LATTICE IS `ExpandToGrid`'s, NOT THE REGION'S (task 328k). `ExpandToGrid(4)` rounds outward,
-- so a region whose edge is not a multiple of 4 reads columns centred on the EXPANDED box while
-- `readerFor` indexed from the raw edge -- up to one voxel of shear. Every caller before 328k
-- passed a 4-aligned region so nothing was wrong; the base pass tiles the whole footprint, whose
-- edges are not aligned, so the stored origin is now the one the columns were actually read on.
function TerrainBake.snapshot(region: Bounds, yMin: number, yMax: number, allowHoles: boolean?): (Snapshot?, string?)
	local v = Relief.VOXEL
	if region.maxX - region.minX < v or region.maxZ - region.minZ < v then
		return nil, "the region is smaller than one voxel"
	end
	local box = Region3.new(Vector3.new(region.minX, yMin, region.minZ), Vector3.new(region.maxX, yMax, region.maxZ))
		:ExpandToGrid(v)
	local size = box.Size
	local min = box.CFrame.Position - size / 2
	local nx = math.floor(size.X / v + 0.5)
	local nz = math.floor(size.Z / v + 0.5)
	local ny = math.floor(size.Y / v + 0.5)
	local reads = nx * nz * ny
	if reads > TerrainBake.MAX_READ_VOXELS then
		return nil,
			string.format(
				"the snapshot is %d voxels, over ReadVoxels' ceiling %d: narrow the Y band",
				reads,
				TerrainBake.MAX_READ_VOXELS
			)
	end
	local snapshot: Snapshot = {
		pitch = v,
		minX = min.X,
		minZ = min.Z,
		nx = nx,
		nz = nz,
		height = table.create(nx * nz, 0),
		material = table.create(nx * nz, "Air"),
		minY = math.huge,
		maxY = -math.huge,
		hole = {},
		holes = 0,
		holeWhy = {},
	}
	local materials, occupancies = Workspace.Terrain:ReadVoxels(box, v)
	for i = 1, nx do
		local x = min.X + (i - 0.5) * v
		for k = 1, nz do
			local z = min.Z + (k - 0.5) * v
			-- WALK THE COLUMN DOWN: the first solid voxel is the surface. Count the solid RUNS --
			-- more than one, with air between, is an overhang and has no single height.
			local top: number? = nil
			local runs, inRun, material = 0, false, "Air"
			local water = false
			local atCeiling = occupancies[i][ny][k] > 0
			for j = ny, 1, -1 do
				local occupancy = occupancies[i][j][k]
				if occupancy > 0 then
					if materials[i][j][k] == Enum.Material.Water then
						water = true
					end
					if not inRun then
						runs += 1
						inRun = true
						if top == nil then
							top = min.Y + (j - 1) * v + occupancy * v
							material = materials[i][j][k].Name
						end
					end
				else
					inRun = false
				end
			end
			-- `allowHoles` is the WHOLE-REGION base pass (the bake's step 2): it RECORDS a faulted
			-- column instead of losing the other million, and `bakeTileAt` then REFUSES any tile
			-- whose own columns hold one -- never guesses.
			local why = TerrainBake.columnFault(water, runs, top ~= nil, atCeiling, x, z, yMin, yMax)
			local at = index(snapshot, i, k)
			if why ~= nil then
				if allowHoles ~= true then
					return nil, why
				end
				(snapshot.hole :: any)[at] = true
				snapshot.holes = (snapshot.holes :: number) + 1
				local seen = snapshot.holeWhy :: { string }
				if #seen < 20 then
					table.insert(seen, why)
				end
			else
				snapshot.height[at] = top :: number
				(snapshot.material :: { string })[at] = material
				snapshot.minY = math.min(snapshot.minY, top :: number)
				snapshot.maxY = math.max(snapshot.maxY, top :: number)
			end
		end
	end
	return snapshot, nil
end

-- ---------------------------------------------------------------- the slice, over the wire

-- THE BASE SNAPSHOT IS A FILE OUTSIDE THE REPOSITORY and Studio cannot read a file, so the tool
-- reads the slice a tile needs out of it and sends it as text. int16 at 1/64 of a stud, which is
-- 0.0156 st -- the same granularity a voxel's own occupancy byte has (4 / 255 = 0.0157), so the
-- quantisation is below what `WriteVoxels` can express. 536 x 536 studs of slice is 36 KB of
-- payload rather than 150 KB of JSON floats.
TerrainBake.SLICE_SCALE = 64
-- ONE FIXED FRAME for every slice, so two reads of the same ground are the SAME BYTES and the file
-- can be stitched out of chunks without a per-chunk offset. int16 at 1/64 spans -512.00 to 511.98
-- studs, which holds the bake's whole Y band (-100..400). MEASURED 2026-11-03: a -256 offset put
-- the ceiling at 255.98 and her place has ground at 256.52, so `encodeSlice` refused the chunk --
-- which is the assert working, and the frame that was wrong.
TerrainBake.SLICE_OFFSET = 0

local B64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_REV: { [number]: number } = {}
for i = 1, #B64_ALPHABET do
	B64_REV[string.byte(B64_ALPHABET, i)] = i - 1
end

-- RFC 4648 base64 -> bytes. Written here because Luau has no decoder, `loadstring` is disabled in
-- Roblox and `HttpService` offers none, so an int16 payload can only arrive as text.
--   https://datatracker.ietf.org/doc/html/rfc4648#section-4
local function fromBase64(text: string): buffer
	local clean = (string.gsub(text, "[^A-Za-z0-9+/]", ""))
	local n = #clean
	local groups = n // 4
	local tail = n - groups * 4
	local bytes = groups * 3 + (if tail == 3 then 2 elseif tail == 2 then 1 else 0)
	assert(tail ~= 1, "base64: a 1-character tail cannot be a byte")
	local out = buffer.create(bytes)
	local at = 0
	for g = 0, groups - 1 do
		local p, q, r, t = string.byte(clean, g * 4 + 1, g * 4 + 4)
		local value = B64_REV[p] * 262144 + B64_REV[q] * 4096 + B64_REV[r] * 64 + B64_REV[t]
		buffer.writeu8(out, at, value // 65536 % 256)
		buffer.writeu8(out, at + 1, value // 256 % 256)
		buffer.writeu8(out, at + 2, value % 256)
		at += 3
	end
	if tail >= 2 then
		local p, q = string.byte(clean, groups * 4 + 1, groups * 4 + 2)
		local value = B64_REV[p] * 4 + B64_REV[q] // 16
		buffer.writeu8(out, at, value % 256)
		if tail == 3 then
			local r = string.byte(clean, groups * 4 + 3)
			buffer.writeu8(out, at + 1, (B64_REV[q] % 16) * 16 + B64_REV[r] // 4)
		end
	end
	return out
end

TerrainBake.fromBase64 = fromBase64

local function toBase64(buf: buffer): string
	local n = buffer.len(buf)
	local pieces: { string } = {}
	local at = 0
	while at + 3 <= n do
		local value = buffer.readu8(buf, at) * 65536 + buffer.readu8(buf, at + 1) * 256 + buffer.readu8(buf, at + 2)
		table.insert(
			pieces,
			string.sub(B64_ALPHABET, value // 262144 + 1, value // 262144 + 1)
				.. string.sub(B64_ALPHABET, value // 4096 % 64 + 1, value // 4096 % 64 + 1)
				.. string.sub(B64_ALPHABET, value // 64 % 64 + 1, value // 64 % 64 + 1)
				.. string.sub(B64_ALPHABET, value % 64 + 1, value % 64 + 1)
		)
		at += 3
	end
	local left = n - at
	if left == 1 then
		local a = buffer.readu8(buf, at)
		table.insert(
			pieces,
			string.sub(B64_ALPHABET, a // 4 + 1, a // 4 + 1)
				.. string.sub(B64_ALPHABET, a % 4 * 16 + 1, a % 4 * 16 + 1)
				.. "=="
		)
	elseif left == 2 then
		local a, b = buffer.readu8(buf, at), buffer.readu8(buf, at + 1)
		table.insert(
			pieces,
			string.sub(B64_ALPHABET, a // 4 + 1, a // 4 + 1)
				.. string.sub(B64_ALPHABET, (a % 4 * 16 + b // 16) + 1, (a % 4 * 16 + b // 16) + 1)
				.. string.sub(B64_ALPHABET, b % 16 * 4 + 1, b % 16 * 4 + 1)
				.. "="
		)
	end
	return table.concat(pieces)
end

TerrainBake.toBase64 = toBase64

-- A SNAPSHOT, COMPACT ENOUGH TO COME BACK THROUGH ONE MCP CALL. 16,384 columns of JSON floats plus
-- 16,384 material strings is ~280 KB of reply; the same columns as int16 in a fixed frame are
-- 43 KB of base64. `decodeSlice` is its exact inverse, and the tool's own encoder is checked against
-- this one by `terrainbake.py selftest` (task 328k).
--
-- THE HOLES ARE A BITMASK, NOT A LIST, and that is measured: a chunk of the border pad where NO
-- column has ground sent 16,384 hole INDICES, the reply was truncated mid-object, and `parse_json`
-- fell back to the one array it could close -- `holeWhy` -- so the tool read a list of sentences
-- where a slice should have been (2026-11-03). One bit a column is 2 KB for the same chunk.
function TerrainBake.encodeSlice(snapshot: Snapshot): any
	local scale = TerrainBake.SLICE_SCALE
	local offset = TerrainBake.SLICE_OFFSET
	local count = snapshot.nx * snapshot.nz
	local buf = buffer.create(count * 2)
	local bits = buffer.create((count + 7) // 8)
	local hole = snapshot.hole
	local holes = 0
	for at = 1, count do
		local slot = at - 1
		if hole ~= nil and hole[at] == true then
			holes += 1
			local byte = slot // 8
			buffer.writeu8(bits, byte, bit32.bor(buffer.readu8(bits, byte), bit32.lshift(1, slot % 8)))
			buffer.writei16(buf, slot * 2, 0)
		else
			local code = math.round((snapshot.height[at] - offset) * scale)
			assert(
				code >= -32768 and code <= 32767,
				string.format("encodeSlice: height %.3f is outside the slice frame", snapshot.height[at])
			)
			buffer.writei16(buf, slot * 2, code)
		end
	end
	return {
		pitch = snapshot.pitch,
		minX = snapshot.minX,
		minZ = snapshot.minZ,
		nx = snapshot.nx,
		nz = snapshot.nz,
		scale = scale,
		offset = offset,
		minY = if snapshot.minY < math.huge then snapshot.minY else 0,
		maxY = if snapshot.maxY > -math.huge then snapshot.maxY else 0,
		holes = holes,
		holeBits = toBase64(bits),
		holeWhy = snapshot.holeWhy,
		b64 = toBase64(buf),
	}
end

-- ONE TILE'S SLICE OF THE BASE SNAPSHOT, decoded. The payload is the tool's, and its `holes` are
-- the columns the base pass could not give a single height: `readerFor` answers nil there and
-- `bakeTileAt` refuses the tile, so a Water column is never silently filled (design 5.3 step 2).
function TerrainBake.decodeSlice(payload: any): Snapshot
	assert(type(payload) == "table", "TerrainBake.decodeSlice: the payload is not a table")
	local nx = math.round(payload.nx)
	local nz = math.round(payload.nz)
	assert(nx >= 1 and nz >= 1, "TerrainBake.decodeSlice: the slice is empty")
	local scale = payload.scale or TerrainBake.SLICE_SCALE
	local offset = payload.offset or TerrainBake.SLICE_OFFSET
	local buf = fromBase64(payload.b64)
	local count = nx * nz
	assert(
		buffer.len(buf) == count * 2,
		string.format("TerrainBake.decodeSlice: %d bytes for %d x %d columns", buffer.len(buf), nx, nz)
	)
	-- THE HOLES FIRST, BECAUSE THE RANGE MUST NOT COUNT THEM. A hole's code on the wire is 0, which
	-- decodes to a height of 0, and `minY` is what `shapeTile` writes where the reader has no answer
	-- -- so taking the range over every slot put a 0-stud floor under ground that stands at 100-150
	-- (Reviewer, round 1, finding 1). EITHER SHAPE: a base64 BITMASK, one bit a column, which is what
	-- `encodeSlice` sends, or a plain list of 1-based indices, which the tool's tile slices and a
	-- hand-written fixture use. The bitmask wins when both are present.
	local hole: { [number]: boolean } = {}
	local holes = 0
	if type(payload.holeBits) == "string" then
		local bits = fromBase64(payload.holeBits)
		for at = 1, count do
			local slot = at - 1
			local byte = slot // 8
			if byte < buffer.len(bits) and bit32.band(buffer.readu8(bits, byte), bit32.lshift(1, slot % 8)) ~= 0 then
				hole[at] = true
				holes += 1
			end
		end
	else
		for _, at in payload.holes or {} do
			hole[math.round(at)] = true
			holes += 1
		end
	end
	local height = table.create(count, 0)
	local lo, hi = math.huge, -math.huge
	for at = 1, count do
		local h = offset + buffer.readi16(buf, (at - 1) * 2) / scale
		height[at] = h
		if not hole[at] then
			lo = math.min(lo, h)
			hi = math.max(hi, h)
		end
	end
	-- EVERY COLUMN A HOLE: there is no range to take, so the sender's own numbers stand. `encodeSlice`
	-- sends 0 for that case and the tool sends the ground minimum it stitched, so this is a floor and
	-- never an invented height -- and such a slice refuses its tile anyway.
	if lo == math.huge then
		lo = payload.minY or 0
		hi = payload.maxY or lo
	end
	return {
		pitch = payload.pitch or Relief.VOXEL,
		minX = payload.minX,
		minZ = payload.minZ,
		nx = nx,
		nz = nz,
		height = height,
		minY = lo,
		maxY = hi,
		hole = hole,
		holes = holes,
		holeWhy = {},
	}
end

-- WHICH OF A SLICE'S HOLES FALL INSIDE THE TILE ITSELF, not in its pad. A hole in the pad only
-- blurs; a hole in the tile is ground this bake would have to invent, so `bakeTileAt` refuses.
function TerrainBake.holesInTile(slice: Snapshot, tile: Tile): number
	local hole = slice.hole
	if hole == nil then
		return 0
	end
	local v = slice.pitch
	local count = 0
	for at in hole do
		local i = (at - 1) % slice.nx + 1
		local k = (at - 1) // slice.nx + 1
		local x = slice.minX + (i - 0.5) * v
		local z = slice.minZ + (k - 0.5) * v
		if
			x >= tile.minX
			and x < tile.minX + TerrainBake.TILE_STUDS
			and z >= tile.minZ
			and z < tile.minZ + TerrainBake.TILE_STUDS
		then
			count += 1
		end
	end
	return count
end

-- ---------------------------------------------------------------- the base, at named points only

-- A SAMPLER THAT ANSWERS ONLY THE POINTS IT WAS GIVEN, read off the base snapshot FILE by the tool.
-- A long profile reads the base at exactly `profileSamples`' points, so this is the whole of what it
-- needs -- and a point nobody sent is nil, never a live raycast. That raycast is the +2 studs a bake
-- the road half drifted (ESCALATE.md, task 328e: lineMeanY 108.88 -> 112.83 -> 114.81).
-- `rows` is flat: x, z, y, x, z, y, ...
function TerrainBake.pointSampler(rows: { number }): (number, number) -> number?
	local by: { [string]: number } = {}
	local at = 1
	while at + 2 <= #rows do
		by[string.format("%d:%d", math.round(rows[at]), math.round(rows[at + 1]))] = rows[at + 2]
		at += 3
	end
	return function(x: number, z: number): number?
		return by[string.format("%d:%d", math.round(x), math.round(z))]
	end
end

-- EXACTLY THE POINTS `profilesFor` WILL ASK THE BASE FOR, so the tool reads those out of the
-- snapshot file and the sample lattice is never written twice. The road set is `profilesFor`'s own:
-- EVERY east-west road in the world, plus the four roads of each named cell. Flat: x, z, x, z, ...
function TerrainBake.profileSamples(cellIds: { string }): { number }
	local step = TerrainBake.ROAD.sampleStuds
	local wanted: { [string]: Relief.Road } = {}
	for _, road in Grid.roads() do
		if road.axis == "x" then
			wanted[road.id] = road
		end
	end
	for _, id in cellIds do
		for _, key in { "main", "muster", "west", "east" } do
			local road = (Grid.roadsOf(id) :: any)[key]
			wanted[road.id] = road
		end
	end
	local ids: { string } = {}
	for id in wanted do
		table.insert(ids, id)
	end
	table.sort(ids)
	local out: { number } = {}
	for _, id in ids do
		local road = wanted[id]
		local n = math.floor((road.to - road.from) / step) + 1
		for i = 1, n do
			local along = road.from + (i - 1) * step
			-- THE CURVE'S OWN POINT, never `road.at` (task 328q): `longProfile` reads the base here
			-- and the two sample lattices must be the same one.
			local centre = Grid.roadCentreAt(road, along)
			if road.axis == "x" then
				table.insert(out, along)
				table.insert(out, centre)
			else
				table.insert(out, centre)
				table.insert(out, along)
			end
		end
	end
	return out
end

-- ---------------------------------------------------------------- which cell, and one blend

-- WHICH CELL OWNS A POINT: the one whose bounds contain it, else the nearest. There is no per-cell
-- fade here, because the ROAD FADE is the blend between cells -- `Relief.roadFadeAt` is 0 for 51
-- studs either side of a centreline and cells only ever meet at a road.
function TerrainBake.cellAt(cellIds: { string }, x: number, z: number): string
	-- WORLD IN, `Grid.toGrid` ONCE (task 328q): `boundsOf` is a GRID rectangle.
	local u, v = Grid.toGrid(x, z)
	x, z = u, v
	local best, bestD = cellIds[1], math.huge
	for _, id in cellIds do
		local b = Grid.boundsOf(id)
		local dx = math.max(b.minX - x, x - b.maxX, 0)
		local dz = math.max(b.minZ - z, z - b.maxZ, 0)
		local d = dx * dx + dz * dz
		if d < bestD then
			best, bestD = id, d
		end
	end
	return best
end

-- THE UNION OF THE CELLS BEING BAKED, which is what `blendAt` fades from.
-- IT IS A WORLD BOX, so it is `worldBoundsOf` and not `boundsOf` (task 328q): `blendAt` measures
-- how far a WORLD point is outside what was baked, and the bend moves the cell's edge.
function TerrainBake.unionOf(cellIds: { string }): Bounds
	local out = { minX = math.huge, maxX = -math.huge, minZ = math.huge, maxZ = -math.huge }
	for _, id in cellIds do
		local b = Grid.worldBoundsOf(id)
		out.minX = math.min(out.minX, b.minX)
		out.maxX = math.max(out.maxX, b.maxX)
		out.minZ = math.min(out.minZ, b.minZ)
		out.maxZ = math.max(out.maxZ, b.maxZ)
	end
	return out
end

-- ONE BLEND, AT THE EDGE OF WHAT WAS BAKED -- the 328d decision the 328c note asks for.
-- `Relief.heightAt` fades `k` from ONE CELL's bounds, which bleeds every cell's delta up to 200
-- studs into its neighbours; the bake REPLACES that `k` with one fade from the baked union.
function TerrainBake.blendAt(union: Bounds, x: number, z: number): number
	local dx = math.max(union.minX - x, x - union.maxX, 0)
	local dz = math.max(union.minZ - z, z - union.maxZ, 0)
	local outside = math.sqrt(dx * dx + dz * dz)
	if outside >= Relief.BLEND_STUDS then
		return 0
	end
	local t = outside / Relief.BLEND_STUDS
	return 1 - t * t * (3 - 2 * t)
end

-- ---------------------------------------------------------------- the road (design 7.1)

-- DESIGN 7.1's CROSS-SECTION, as data. `d` is the distance from the centreline; every band below is
-- NOMINAL and `Relief.columnsFor` realises it as whole voxel columns (correction F-2: the BAND
-- snaps, never the centre, because all eight centres sit at = 1 mod 4).
TerrainBake.ROAD = table.freeze({
	carriagewayStuds = 20, -- 0 to +-20, level
	-- WHERE `mid` ENDS AND `outer` BEGINS, and it is design 7.1's table row and not a choice: "0 to
	-- +-6 ... Ground / Grass" then "+-10 to +-20 ... Grass". 328d wrote this boundary as d < 10, so
	-- the realised columns at |d| 10..13 came out `mid` where the table asks for `outer` -- MEASURED
	-- on EW2 in Karen's place 2026-11-02, `<runs-dir>/328e-xsec-BEFORE.json`, 4 studs of Ground
	-- either side of the carriageway edge. The rut band still overrides whatever this answers.
	midStuds = 6,
	-- "crossfall <= 0.5 st over 44 st": 0.2 st from the crown to each edge is 0.4 over 44, under it.
	crownFallStuds = 0.2,
	rut = table.freeze({ nearStuds = 6, farStuds = 10 }), -- F-3: +-6..+-10, never +-4 (they merged)
	ditch = table.freeze({ nearStuds = 22, farStuds = 30, depthStuds = 2 }),
	vergeStuds = 34, -- no tree, no fern (the mask is Places.mask's, 328f)
	bankMinStuds = 12, -- at least 12 wide, and never steeper than 1:2
	bankMaxSlope = 0.5,
	-- The long profile's clamps: 8 % east-west, 10 % north-south, <= 2 % change per 50 st,
	-- cut-or-fill <= 12 st. A breach RELAXES the grade on that road and is printed, never hidden.
	gradePercent = table.freeze({ x = 8, z = 10 }),
	gradeChangePercentPer50 = 2,
	-- CUT-OR-FILL, PER AXIS, IN STUDS. 12 is design 7.1's and the east-west roads keep it. The
	-- north-south roads are 20 -- Director decision 3 (2026-11-02), walked in Karen's place against
	-- C1's own base, which rises 110 and 124 st over NS3's and NS4's 2,986-st span. The realised
	-- GRADE in PER CENT that each cap buys, measured: 12 st -> NS3 20.00, NS4 20.00 · 16 -> 16.00,
	-- 12.00 · 18 -> 12.00, 10.00 · 20 -> 10.00, 10.00. 20 is the smallest of those under the 12 %
	-- the decision asks for, it is the decision's own hard ceiling, and the cut it realises is
	-- 19.75 st on NS3 and 17.21 on NS4 -- inside it. A deeper cut is what a real forest road does.
	cutFillStuds = table.freeze({ x = 12, z = 20 }),
	sampleStuds = 20,
	-- Design 7.1's material table. `mid` is 0..+-6, `outer` is +-10..+-20.
	material = table.freeze({
		x = table.freeze({ mid = "Ground", rut = "Mud", outer = "Grass", ditch = "Mud", verge = "Grass" }),
		z = table.freeze({ mid = "Grass", rut = "Mud", outer = "Grass", ditch = "Mud", verge = "Grass" }),
	}),
})

export type Profile = {
	road: Relief.Road,
	from: number,
	to: number,
	step: number,
	y: { number },
	gradePercent: number,
	relaxed: boolean,
	worstCutFill: number,
	realisedGradePercent: number,
	worstGradeChangePercent: number,
	gradeChangeSpanStuds: number,
	breaches: { string },
}

-- ONE JUNCTION PIN: the height the road must pass through at `along`. Design 7.1, "pin the 15
-- junctions" -- the world has 3 east-west and 5 north-south roads, so 15 crossings.
export type Pin = { along: number, y: number }

-- HOW FAR EITHER SIDE OF A CROSSING A PIN HOLDS THE PROFILE FLAT. Derived, not chosen: the junction
-- square's half-width (the carriageway, so both roads cover the point) PLUS one sample step, so the
-- 20-st interpolation on each side of the square is flat at the pinned height too. Without the extra
-- step the crown would already be sloping away at the square's boundary and the step would be the
-- road's grade over half a sample -- 1.3 st at 12 %.
function TerrainBake.pinWindowStuds(): number
	return TerrainBake.ROAD.carriagewayStuds + TerrainBake.ROAD.sampleStuds
end

-- WHICH SAMPLES A PIN HOLDS, as sample index -> height.
function TerrainBake.pinnedSamples(road: Relief.Road, n: number, step: number, pins: { Pin }?): { [number]: number }
	local out: { [number]: number } = {}
	if pins == nil then
		return out
	end
	local window = TerrainBake.pinWindowStuds()
	for _, pin in pins do
		for i = 1, n do
			if math.abs(road.from + (i - 1) * step - pin.along) <= window + 1e-9 then
				out[i] = pin.y
			end
		end
	end
	return out
end

-- THE PINS FOR ONE ROAD (design 7.1: "pin the 15 junctions" and "the E-W profile wins inside the
-- junction square"). Those are the same ruling read twice: the east-west road is the authority, so
-- it is pinned by nothing and every north-south road is pinned to the east-west CROWN at each
-- crossing. Without this the two axes' profiles are under no constraint to agree and the surface
-- steps by their whole difference along the junction square's diagonal -- measured at 60.00 studs on
-- a synthetic base before this existed (reviews/task-328d/RESULT.md round-3 finding 2).
function TerrainBake.junctionPins(road: Relief.Road, ewProfiles: { Profile }): { Pin }
	local pins: { Pin } = {}
	if road.axis ~= "z" then
		return pins
	end
	for _, profile in ewProfiles do
		local ew = profile.road
		local crossesIt = road.at >= ew.from and road.at <= ew.to
		local crossesUs = ew.at >= road.from and ew.at <= road.to
		if ew.axis == "x" and crossesIt and crossesUs then
			table.insert(pins, { along = ew.at, y = TerrainBake.profileY(profile, road.at) })
		end
	end
	table.sort(pins, function(a: Pin, b: Pin)
		return a.along < b.along
	end)
	return pins
end

-- HOW MANY SMOOTHING PASSES the grade-change limiter may take. One pass does NOT meet the rule:
-- measured on a 0 -> 10 % kink it leaves 3.80 % per 60 st against a 2.40 % allowance, and it takes
-- ~20 passes to settle at the allowance (round-2 finding 4).
TerrainBake.GRADE_CHANGE_PASSES = 40

-- THE LONG PROFILE of one road: sample the base every 20 st, clamp the grade, limit how fast the
-- grade may change, and cap cut-or-fill at 12 st. A cap that cannot be met RELAXES the grade on
-- THAT road and says so in `breaches` -- design 7.1, "a breach relaxes the grade on that road and
-- is printed, never hidden".
function TerrainBake.longProfile(road: Relief.Road, baseAt: (number, number) -> number?, pins: { Pin }?): Profile?
	local step = TerrainBake.ROAD.sampleStuds
	local n = math.floor((road.to - road.from) / step) + 1
	local base = table.create(n, 0)
	for i = 1, n do
		local at = road.from + (i - 1) * step
		-- THE CENTRELINE IS A FUNCTION OF THE STATION (task 328q, design 7.2). Everything below --
		-- the grade clamp, the 2 %/50 st rule, the cut/fill cap, the pins -- is unchanged.
		local centre = Grid.roadCentreAt(road, at)
		local y = if road.axis == "x" then baseAt(at, centre) else baseAt(centre, at)
		if y == nil then
			return nil
		end
		base[i] = y
	end
	local ceilingPercent = TerrainBake.ROAD.gradePercent[road.axis]
	local cutFillCap = TerrainBake.ROAD.cutFillStuds[road.axis]
	local held = TerrainBake.pinnedSamples(road, n, step, pins)
	local out, relaxed, breaches = table.clone(base), false, {}
	local worst = 0
	-- THE GRADE-CHANGE RULE IS A RATE -- "<= 2 % change per 50 st" (design 7.1). The samples are 20
	-- st apart, so the nearest measurable span is 60 st (3 steps) and the allowance is that SAME
	-- rate over the span actually measured: 2 % x 60/50 = 2.4 %. Re-derived here, not retyped.
	local window = math.max(1, math.floor(50 / step + 0.5))
	local spanStuds = window * step
	local limit = TerrainBake.ROAD.gradeChangePercentPer50 / 100 * (spanStuds / 50)
	local worstChange, pinMiss, pinCost = 0, 0, 0
	for attempt = 1, 6 do
		out = table.clone(base)
		local rise = ceilingPercent / 100 * step
		-- A FORWARD-THEN-BACKWARD MIN-CONE SWEEP, which is exact on a chain -- the same finishing
		-- sweep `Relief.limitPass` uses, and for the same reason.
		for _ = 1, 2 do
			for i = 1, n - 1 do
				if out[i + 1] - out[i] > rise then
					out[i + 1] = out[i] + rise
				end
			end
			for i = n - 1, 1, -1 do
				if out[i] - out[i + 1] > rise then
					out[i] = out[i + 1] + rise
				end
			end
		end
		-- THE GRADE MAY NOT CHANGE FASTER THAN THE RATE ABOVE: smoothing passes over the slopes,
		-- re-integrated, UNTIL NO WINDOW BREACHES. One pass leaves a kink at 3.80 % against the
		-- 2.40 % allowance -- it is a relaxation, and it has to be iterated (round-2 finding 4).
		local slope = table.create(math.max(1, n - 1), 0)
		for _ = 1, TerrainBake.GRADE_CHANGE_PASSES do
			for i = 1, n - 1 do
				slope[i] = (out[i + 1] - out[i]) / step
			end
			local over = 0
			for i = 1, n - 1 - window do
				local change = slope[i + window] - slope[i]
				if math.abs(change) > limit + 1e-12 then
					over += 1
					local excess = (math.abs(change) - limit) / 2 * (if change > 0 then 1 else -1)
					slope[i] += excess
					slope[i + window] -= excess
				end
			end
			for i = 1, n - 1 do
				out[i + 1] = out[i] + slope[i] * step
			end
			if over == 0 then
				break
			end
		end
		-- RE-CENTRE on the base, so the smoothing cannot drift the whole road up or down.
		local drift = 0
		for i = 1, n do
			drift += base[i] - out[i]
		end
		drift /= n
		for i = 1, n do
			out[i] += drift
		end
		-- THE JUNCTION PINS, AS A BAND (design 7.1). The clamp above is a MIN-CONE sweep: it can only
		-- lower, which is right for a slope ceiling and wrong for a pin -- a crossing higher than the
		-- ground each side has to be MET BY FILL, and 12 rounds of lower-then-restore left the pin
		-- 2.75 and 7.55 st out on NS3 and NS4 (measured in Karen's place, cycle 0). So the pins are
		-- applied in closed form instead: each held sample opens a cone of +-`rise` a sample, the
		-- cones intersect into a band [lower, upper] that is zero-width at every held sample, and the
		-- profile is clamped into it. The median of three functions that are each Lipschitz in `rise`
		-- is Lipschitz in `rise`, so the clamped profile still meets the grade ceiling, and it passes
		-- through every crossing exactly rather than nearly.
		pinMiss, pinCost = 0, 0
		local beforePins = table.clone(out)
		if next(held) ~= nil then
			local upper, lower = table.create(n, math.huge), table.create(n, -math.huge)
			for i, y in held do
				upper[i], lower[i] = y, y
			end
			for i = 2, n do
				upper[i] = math.min(upper[i], upper[i - 1] + rise)
				lower[i] = math.max(lower[i], lower[i - 1] - rise)
			end
			for i = n - 1, 1, -1 do
				upper[i] = math.min(upper[i], upper[i + 1] + rise)
				lower[i] = math.max(lower[i], lower[i + 1] - rise)
			end
			local empty = false
			for i = 1, n do
				if lower[i] > upper[i] + 1e-9 then
					empty = true
				end
			end
			if empty then
				-- TWO CROSSINGS FARTHER APART IN HEIGHT THAN THE CLAMP CAN SPAN. There is no profile
				-- that meets both, so neither is forced.
				pinCost = math.huge
			else
				for i = 1, n do
					out[i] = math.clamp(out[i], lower[i], upper[i])
				end
				for i, y in held do
					pinMiss = math.max(pinMiss, math.abs(out[i] - y))
				end
			end
			-- A PIN THE GROUND CANNOT CARRY IS DROPPED, NOT FORCED. Forcing one drags the whole
			-- profile off the hillside: on a synthetic 31-degree ramp the pinned flank's bank reached
			-- 165 studs into a tile it has no business in (328d-17). So on the LAST attempt, after
			-- every relaxation has been tried, a pinning that costs more cut-or-fill than the cap AND
			-- more than not pinning at all is given up and said so.
			local pinned, bare = 0, 0
			for i = 1, n do
				pinned = math.max(pinned, math.abs(out[i] - base[i]))
				bare = math.max(bare, math.abs(beforePins[i] - base[i]))
			end
			if pinCost == math.huge or (attempt == 6 and pinned > cutFillCap and pinned > bare) then
				out = beforePins
				pinCost, pinMiss = pinned, 0
			end
		end
		worst = 0
		for i = 1, n do
			worst = math.max(worst, math.abs(out[i] - base[i]))
		end
		if worst <= cutFillCap then
			break
		end
		if attempt < 6 then
			relaxed = true
			ceilingPercent += 2
			table.insert(
				breaches,
				string.format(
					"%s: cut-or-fill %.1f st over the %d-st cap, so the grade is relaxed to %d %%",
					road.id,
					worst,
					cutFillCap,
					ceilingPercent
				)
			)
		else
			table.insert(
				breaches,
				string.format("%s: cut-or-fill %.1f st STILL over the cap at %d %%", road.id, worst, ceilingPercent)
			)
		end
	end
	-- THE REALISED GRADE CHANGE, off the profile that is actually returned. A breach that the
	-- passes above could not settle is RECORDED, never hidden (design 7.1).
	for i = 1, n - 1 - window do
		local a = (out[i + 1] - out[i]) / step
		local b = (out[i + window + 1] - out[i + window]) / step
		worstChange = math.max(worstChange, math.abs(b - a))
	end
	-- 1e-6 OF A SLOPE, not 1e-9: the convergence loop settles every window to within 1e-12 of the
	-- limit, and re-integrating the heights puts ~1e-10 of float noise back. At 1e-9 the first live
	-- run on C1 printed a "breach" of 2.40 % against a 2.40 % allowance on all four roads, which is
	-- noise wearing a breach's name. 1e-6 is a ten-thousandth of the printed precision.
	-- A PIN GIVEN UP, and a pin that could not be met, are breach lines like any other: printed,
	-- never hidden. Both need a base whose crossings are steeper apart than the clamp can span.
	if pinCost > 1e-6 then
		table.insert(
			breaches,
			string.format(
				"%s: pinning its junctions needs %.1f st of cut or fill, over the %d-st cap, so this road is NOT pinned",
				road.id,
				pinCost,
				cutFillCap
			)
		)
	end
	if pinMiss > 1e-6 then
		table.insert(breaches, string.format("%s: a junction pin is still %.2f st out of its band", road.id, pinMiss))
	end
	if worstChange > limit + 1e-6 then
		table.insert(
			breaches,
			string.format(
				"%s: grade change %.2f %% over %d st, over the %.2f %% allowance",
				road.id,
				worstChange * 100,
				spanStuds,
				limit * 100
			)
		)
	end
	-- WHAT THE ROAD ACTUALLY DOES, not what it was allowed: `gradePercent` is the ceiling the
	-- relaxation arm ended on, and on a base it cannot meet that is 20 % while the realised grade
	-- may be far less. Both are reported so neither can stand in for the other.
	local realised = 0
	for i = 1, n - 1 do
		realised = math.max(realised, math.abs(out[i + 1] - out[i]) / step)
	end
	return {
		road = road,
		from = road.from,
		to = road.to,
		step = step,
		y = out,
		gradePercent = ceilingPercent,
		realisedGradePercent = realised * 100,
		relaxed = relaxed,
		worstCutFill = worst,
		worstGradeChangePercent = worstChange * 100,
		gradeChangeSpanStuds = spanStuds,
		breaches = breaches,
	}
end

-- The profile's own height at one point along the road, linearly between its 20-st samples.
function TerrainBake.profileY(profile: Profile, along: number): number
	local t = (along - profile.from) / profile.step
	local i = math.clamp(math.floor(t) + 1, 1, #profile.y)
	local j = math.clamp(i + 1, 1, #profile.y)
	local f = math.clamp(t - (i - 1), 0, 1)
	return profile.y[i] + (profile.y[j] - profile.y[i]) * f
end

-- THE ONE BAND REALISER, and every road path goes through it (round-2 finding 1, lesson L-031).
-- It answers the band as bounds on |d|, the distance from the centreline, for the side the point is
-- on. `Relief.columnsFor` snaps a band to whole voxel columns on the PLUS side only; every centre
-- sits at = 1 (mod 4) (design 7.1 correction F-2), so the minus side's whole columns are 2 studs off
-- that lattice and a mirrored band would not be whole columns there. Reflecting the centre through
-- the origin turns the minus side into a plus side, so ONE function realises both: each side gets
-- the same number of whole columns, the same width, and midpoints half a voxel apart -- which is the
-- closest to symmetric a centre at = 1 (mod 4) allows.
function TerrainBake.bandFor(centre: number, nearStuds: number, farStuds: number, side: number): (number, number)
	if side >= 0 then
		local first, last = Relief.columnsFor(centre, nearStuds, farStuds)
		return first - centre, last - centre
	end
	local first, last = Relief.columnsFor(-centre, nearStuds, farStuds)
	return first + centre, last + centre
end

-- THE CROSS-SECTION at one point: the height the road wants there, the material, and how strongly
-- the road owns the ground (1 inside the verge, falling to 0 across the bank). Returns nil when the
-- point is outside every road's reach, which is most of a cell.
--
-- The rut and the ditch are realised by `Relief.columnsFor` at the road's own parity, so their
-- WIDTH does not depend on where the centreline happens to fall (correction F-2).
--
-- `bend` IS A TRAILING OPTIONAL (task 328r, 328q note (a)): every band below is measured from
-- `Grid.roadCentreAt`, which moves with the amplitude, and with no parameter no case could put a
-- point in the ditch of a BENT road while `Grid.CONFIG.bend` sat at one value.
function TerrainBake.roadAt(
	profiles: { Profile },
	naturalY: number,
	x: number,
	z: number,
	bend: any?
): (number?, string?, number)
	local spec = TerrainBake.ROAD
	-- THE NEAREST CENTRELINE ON EACH AXIS, kept apart, because inside a junction square both roads
	-- cover the point and the design says which one wins.
	local bestX: Profile? = nil
	local bestZ: Profile? = nil
	local dX, dZ = math.huge, math.huge
	local alongX, alongZ = 0, 0
	for _, profile in profiles do
		local road = profile.road
		local along = if road.axis == "x" then x else z
		if along >= road.from and along <= road.to then
			local d = math.abs((if road.axis == "x" then z else x) - Grid.roadCentreAt(road, along, bend))
			if road.axis == "x" then
				if d < dX then
					bestX, dX, alongX = profile, d, along
				end
			elseif d < dZ then
				bestZ, dZ, alongZ = profile, d, along
			end
		end
	end
	local best: Profile? = nil
	local bestAlong = 0
	-- DESIGN 7.1: "Junctions: the E-W profile wins inside the junction square." The square is where
	-- the two CARRIAGEWAYS overlap. Without this the nearest-centreline rule switches surfaces along
	-- the square's diagonal, and the two crowns are only as close as their independent deviations
	-- allow -- 60.00 studs apart on the synthetic base of 328j-1, and 13 studs of cut apart on
	-- Karen's real ground (EW2 1.02 st against NS3 14.07 st).
	local inSquare = bestX ~= nil and bestZ ~= nil and dX <= spec.carriagewayStuds and dZ <= spec.carriagewayStuds
	if bestX ~= nil and (inSquare or bestZ == nil or dX <= dZ) then
		best, bestAlong = bestX, alongX
	else
		best, bestAlong = bestZ, alongZ
	end
	if best == nil then
		return nil, nil, 0
	end
	local profile = best :: Profile
	local road = profile.road
	-- THE CENTRE IS A FUNCTION OF THE STATION (task 328q, design 7.2). The band still snaps to whole
	-- WORLD voxel columns at each station, which is correction F-2 kept: the cost is a 4-stud lateral
	-- stair every 31.5 studs along a bend, printed by the census.
	local centre = Grid.roadCentreAt(road, bestAlong, bend)
	local across = (if road.axis == "x" then z else x)
	local d = math.abs(across - centre)
	local crownY = TerrainBake.profileY(profile, bestAlong)
	local material = spec.material[road.axis]
	-- Which band, measured OUTWARD from the centreline, on THE SIDE THE POINT IS ON. Round 2 built
	-- the far side's bounds as `centre - far`, which is negative and so unreachable by |d|: the ditch
	-- and the ruts were dead on the minus side of every road in the world (round-2 finding 1).
	local side = if across >= centre then 1 else -1
	local lo, hi = TerrainBake.bandFor(centre, spec.rut.nearStuds, spec.rut.farStuds, side)
	local ditchLo, ditchHi = TerrainBake.bandFor(centre, spec.ditch.nearStuds, spec.ditch.farStuds, side)
	if d <= spec.carriagewayStuds then
		local y = crownY - spec.crownFallStuds * (d / spec.carriagewayStuds)
		-- Design 7.1: `mid` 0..+-6, the rut +-6..+-10 as ONE whole column, `outer` +-10..+-20. The
		-- realised column is 4 st wide, so what is left of the nominal rut band keeps the
		-- carriageway's own material. Round 2 wrote this as three arms whose first and last agreed.
		local name = if d < spec.midStuds then material.mid else material.outer
		if d >= lo and d <= hi then
			name = material.rut
		end
		return y, name, 1
	end
	if d >= ditchLo and d <= ditchHi then
		return crownY - spec.ditch.depthStuds, material.ditch, 1
	end
	if d < ditchLo then
		-- The shoulder between the carriageway edge and the ditch lip: level with the edge.
		return crownY - spec.crownFallStuds, material.outer, 1
	end
	if d <= spec.vergeStuds then
		return crownY - spec.crownFallStuds, material.verge, 1
	end
	-- THE BANK: back to the natural ground, never steeper than 1:2 and never narrower than 12 st.
	local vergeY = crownY - spec.crownFallStuds
	local drop = math.abs(naturalY - vergeY)
	local width = math.max(spec.bankMinStuds, drop / spec.bankMaxSlope)
	local t = (d - spec.vergeStuds) / width
	if t >= 1 then
		return nil, nil, 0
	end
	local smooth = t * t * (3 - 2 * t)
	return vergeY + (naturalY - vergeY) * smooth, nil, 1 - smooth
end

-- ---------------------------------------------------------------- the stand pads (design 7.4)

-- EVERY STAND AND TOWER OF THE CELLS A RUN TOUCHES, with the height its pad is held at. PURE given
-- the profiles, and computed once per tile from them, so two tiles that share a pad agree by
-- construction (`profilesFor`' own reason).
--
-- THE PAD'S HEIGHT IS THE ROAD'S OWN CROWN AT THE STAND, NEVER `Grid.standPosition`'s Y. That Y is
-- the cell's single `relief.lineMeanY` for all fifteen stands (106.03 for C1, task 328r), and C1's west flank
-- road rises 35.4 studs between stands 8 and 11 -- MEASURED 2026-11-02 in Karen's place
-- (`<runs-dir>/328e-ground-BEFORE.json`): ground 93.41 and 128.82, which is the road's own clamped
-- 5.4 % grade over 660 studs. Levelling those two pads to 106.98 would mean a 21.84-stud pit and a
-- 13.57-stud mound, and a 21.84-stud wall at `Relief.LIMIT_DEG.tree` 20 degrees needs 60 studs of
-- ring -- a 134-stud crater at every stand, overlapping its neighbour 220 studs away. The gap
-- against that Y is `standPosition`'s to close (the post-bake re-survey, 328h), not the ground's.
-- Second returned value: the stands no road reaches, which the caller reports rather than hides.
function TerrainBake.standPadsFor(cellIds: { string }, profiles: { Profile }, bend: any?): ({ StandPad }, { string })
	local out: { StandPad } = {}
	local missed: { string } = {}
	for _, id in cellIds do
		if Grid.cellOf(id) ~= nil then
			for standIndex = 1, Grid.standCount(id) do
				-- THE STAND'S OWN WORLD POINT AT THIS AMPLITUDE (task 328r): `standPosition` reads
				-- the shipped bend, so a spec driving a different one has to map it itself.
				local u, v = Grid.standGridOf(id, standIndex, bend)
				local wx, wz = Grid.toWorld(u, v, bend)
				local at = Vector3.new(wx, Grid.standPosition(id, standIndex).Y, wz)
				local y, _, weight = TerrainBake.roadAt(profiles, at.Y, at.X, at.Z, bend)
				if y ~= nil and weight >= 1 then
					table.insert(out, { x = at.X, z = at.Z, y = y, cell = id, index = standIndex })
				else
					table.insert(missed, string.format("%s/%d", id, standIndex))
				end
			end
		end
	end
	return out, missed
end

-- THE PAD AT ONE POINT: the height the nearest pad wants there, and how strongly it owns the ground
-- (1 inside the level core, falling to 0 across the blend). Nil outside every pad's reach, which is
-- almost all of a cell. `naturalY` is the height the road and the landform have already produced at
-- this point, so the blend ends ON the road rather than on raw ground -- the same shape `roadAt`'s
-- bank uses, and the reason the join is continuous with a zero gradient at the outer edge.
function TerrainBake.standPadAt(
	pads: { StandPad },
	naturalY: number,
	x: number,
	z: number,
	_bend: any?
): (number?, number)
	local spec = TerrainBake.STAND_PAD
	local reach = spec.levelRadiusStuds + spec.blendStuds
	local best: StandPad? = nil
	local bestD = math.huge
	for _, pad in pads do
		local dx, dz = x - pad.x, z - pad.z
		local d = math.sqrt(dx * dx + dz * dz)
		if d < reach and d < bestD then
			best, bestD = pad, d
		end
	end
	if best == nil then
		return nil, 0
	end
	local pad = best :: StandPad
	if bestD <= spec.levelRadiusStuds then
		return pad.y, 1
	end
	local t = (bestD - spec.levelRadiusStuds) / spec.blendStuds
	local smooth = t * t * (3 - 2 * t)
	return pad.y + (naturalY - pad.y) * smooth, 1 - smooth
end

-- ---------------------------------------------------------------- the slope limiter, BOTH axes

-- BOTH AXES -- the 328d decision the 328c note asks for. `Relief.limitPass` runs along one axis at a
-- time and 328c asserted only z; a tree ceiling is a slope in ANY direction, and the note measured
-- B2's scarp climbing back to ~22 degrees in x where nothing pinned it.
function TerrainBake.limitGrid(
	grid: { number },
	nx: number,
	nz: number,
	pitch: number,
	ceilingDeg: number,
	exempt: { boolean }?
): { number }
	local out = table.clone(grid)
	for k = 1, nz do
		local column, mask = table.create(nx, 0), table.create(nx, false)
		for i = 1, nx do
			column[i] = out[(k - 1) * nx + i]
			mask[i] = exempt ~= nil and exempt[(k - 1) * nx + i] == true
		end
		local limited = Relief.limitPass(column, pitch, ceilingDeg, mask)
		for i = 1, nx do
			out[(k - 1) * nx + i] = limited[i]
		end
	end
	for i = 1, nx do
		local column, mask = table.create(nz, 0), table.create(nz, false)
		for k = 1, nz do
			column[k] = out[(k - 1) * nx + i]
			mask[k] = exempt ~= nil and exempt[(k - 1) * nx + i] == true
		end
		local limited = Relief.limitPass(column, pitch, ceilingDeg, mask)
		for k = 1, nz do
			out[(k - 1) * nx + i] = limited[k]
		end
	end
	return out
end

-- ---------------------------------------------------------------- one tile

-- THE Y BAND of one tile, from the shaped heights it will write: min - 16 to max + 32, split into
-- stacked calls whenever that band exceeds the measured 96-stud ceiling (design 5.1).
function TerrainBake.bandsFor(lo: number, hi: number): { { min: number, max: number } }
	local v = Relief.VOXEL
	local min = v * math.floor((lo - TerrainBake.BAND_PAD.belowStuds) / v)
	local max = v * math.ceil((hi + TerrainBake.BAND_PAD.aboveStuds) / v)
	local columns = (TerrainBake.TILE_STUDS / v) * (TerrainBake.TILE_STUDS / v)
	local perCall = v * math.floor(TerrainBake.MAX_VOXELS / columns)
	local out = {}
	local at = min
	while at < max do
		local top = math.min(at + perCall, max)
		table.insert(out, { min = at, max = top })
		at = top
	end
	return out
end

-- THE SHAPE OF ONE TILE, PURE: heights and material names for the tile's own 32 x 32 columns, and
-- it touches `Terrain` nowhere. Split out of `bakeTile` so the thing that decides the ground can be
-- asserted by a spec over a synthetic snapshot (round-1 finding 7).
--
-- THE GRID IS WIDER THAN THE TILE. The slope limiter reaches `LIMIT_MARGIN_STUDS` past a column, so
-- limiting the tile alone would clamp the same ground to two heights either side of a 128-stud seam
-- (round-1 finding 2). It is shaped and limited over the tile plus that margin; only the inner tile
-- is returned.
function TerrainBake.shapeTile(
	tile: Tile,
	snapshot: Snapshot,
	cellIds: { string },
	plans: { [string]: any },
	profiles: { Profile }?,
	-- WHICH CELLS' LANDFORM THIS TILE MAY APPLY. Nil means all of them, which is a virgin base.
	-- `bakeTileAt` fills it from `reshapeWanted`; a spec drives both states by parameter, because a
	-- bake over already-baked ground must not add the landform twice (see `reshapeWanted`).
	reshape: { [string]: boolean }?,
	-- THE BEND, TRAILING AND OPTIONAL (task 328r, 328q note (a)). nil is `Grid.CONFIG.bend`, so no
	-- production caller changes; a spec drives the straight tile and the bent one side by side,
	-- which is what keeps the cross-section's whole-voxel-column claims exact.
	bend: any?,
	-- THE BENCH BANDS (task 328h), decoded slices of the SAME base file, read only where the tile's
	-- own slice has no column. Nil for a run with no bench; `bakeTileAt` refuses a bench cell that
	-- arrives without them, exactly as it refuses a tile with no profiles.
	extras: { Snapshot }?
): ({ number }, { string }, number)
	local v = Relief.VOXEL
	local side = TerrainBake.TILE_STUDS
	local n = math.floor(side / v)
	local margin = math.floor(TerrainBake.LIMIT_MARGIN_STUDS / v)
	local wide = n + 2 * margin
	local union = TerrainBake.unionOf(cellIds)
	local baseAt = TerrainBake.readerFor(snapshot, extras)
	-- THE BASE IS STILL READ AT THE REAL WORLD POINT (design 7.3): `Relief` is handed grid
	-- coordinates and this reader maps them back. One composition, no second definition.
	local baseAtGrid = function(a: number, b: number): number?
		return baseAt(Grid.toWorld(a, b, bend))
	end
	local shaped = table.create(wide * wide, 0)
	local exempt = table.create(wide * wide, false)
	local names: { string } = table.create(wide * wide, "")
	local depth = table.create(wide * wide, 0)
	local roads = Grid.roads()
	-- THE STAND PADS, from the profiles this tile was handed -- so every tile of a run builds the
	-- same pads from the same bytes (design 7.4).
	local pads: { StandPad } = if profiles ~= nil then (TerrainBake.standPadsFor(cellIds, profiles, bend)) else {}
	-- THE BLUR, ONCE, SEPARABLY, over the whole shaping grid (328c note (c)). Per point it is
	-- 1,369 base reads; over the grid it is 2 x 37, and `grid_relief.spec` measures that the two
	-- agree. With the per-point kernel this task's own spec run passed the harness 300-s cap.
	local blurred =
		Relief.blurredGrid(baseAt, tile.minX + (1 - margin - 0.5) * v, tile.minZ + (1 - margin - 0.5) * v, wide, wide)
	for i = 1, wide do
		local x = tile.minX + (i - margin - 0.5) * v
		for k = 1, wide do
			local z = tile.minZ + (k - margin - 0.5) * v
			local at = (k - 1) * wide + i
			local base = baseAt(x, z)
			local id = TerrainBake.cellAt(cellIds, x, z)
			local form = Relief.LANDFORMS[id]
			-- THE GRID POINT, AND A BASE READER COMPOSED WITH `toWorld` (task 328q, design 7.3). In
			-- grid coordinates the roads are straight at their own `at`, so `Relief.roadFadeAt`
			-- becomes curve-correct with NO EDIT and `BAKE_VERSION` stays 1.
			local gx, gz = Grid.toGrid(x, z, bend)
			if base == nil then
				-- `readerFor` has no answer here. KEEP GROUND rather than invent one: writing 0
				-- would cut a hole from the band floor up to y = 0 (round-1 note).
				shaped[at] = snapshot.minY
				exempt[at] = true
			elseif form == nil or (reshape ~= nil and reshape[id] ~= true) then
				-- EITHER NO LANDFORM, OR ITS LANDFORM IS ALREADY IN THIS GROUND: the base IS the
				-- shaped height, and the road, the pad and the material are written onto it.
				-- `depth` STAYS 0 HERE, and that is a real consequence: `Relief.materialAt`'s
				-- `mudDepthStuds` rule reads the cut below the landform's own base, and a re-bake
				-- cuts nothing. C1 has no such rule (328e-5 asserts it); A1's gully Mud and D1's
				-- dish Mud would not be re-painted by a re-bake of those cells.
				shaped[at] = base
				exempt[at] = form ~= nil and Relief.isExempt(form, Grid.boundsOf(id), gx, gz)
			else
				local bounds = Grid.boundsOf(id)
				-- ONE FADE, handed to the arithmetic that owns it (round-1 finding 7). Multiplying
				-- the bake's own fade onto `heightAt`'s cell-edge `k` put two fades in series.
				local here = Relief.heightAt(
					form,
					bounds,
					roads,
					baseAtGrid,
					gx,
					gz,
					TerrainBake.blendAt(union, x, z),
					blurred[at]
				)
				shaped[at] = here or base
				exempt[at] = Relief.isExempt(form, bounds, gx, gz)
				depth[at] = TerrainBake.depthAt(base, here or base)
			end
			-- THE ROAD WINS over the landform inside its verge and blends back across its bank
			-- (design 7.1). Its columns are EXEMPT from the limiter: a limiter free to move a ditch
			-- has not cut a ditch.
			if profiles ~= nil then
				local roadY, roadName, weight = TerrainBake.roadAt(profiles, shaped[at], x, z, bend)
				if roadY ~= nil then
					shaped[at] = roadY
					if roadName ~= nil then
						names[at] = roadName
					end
					if weight >= 1 then
						exempt[at] = true
					end
				end
			end
			-- THE PAD WINS OVER THE ROAD AND THE LANDFORM inside its own radius (design 7.4): a
			-- stand is a level landing, and every grid stand sits on a road centreline, so this is
			-- the last word on that column. Its core is EXEMPT for the road's reason -- a limiter
			-- free to tilt a pad has not levelled one.
			if #pads > 0 then
				local padY, padWeight = TerrainBake.standPadAt(pads, shaped[at], x, z, bend)
				if padY ~= nil then
					shaped[at] = padY
					if padWeight >= 1 then
						exempt[at] = true
					end
				end
			end
		end
	end
	shaped = TerrainBake.limitGrid(shaped, wide, wide, v, Relief.LIMIT_DEG.tree, exempt)
	-- MATERIALS IN A SECOND PASS, over the LIMITED grid: `Relief.materialAt`'s scree rule reads the
	-- slope, and the slope is only real once the limiter has finished with it. The road's own name,
	-- set above, wins -- a road is gravel whatever the ground under it was going to be (design 7.1).
	local inner = table.create(n * n, 0)
	local innerNames: { string } = table.create(n * n, "")
	for i = 1, n do
		for k = 1, n do
			local from = (k + margin - 1) * wide + (i + margin)
			local to = (k - 1) * n + i
			inner[to] = shaped[from]
			local name = names[from]
			if name == "" then
				local x = tile.minX + (i - 0.5) * v
				local z = tile.minZ + (k - 0.5) * v
				local id = TerrainBake.cellAt(cellIds, x, z)
				local form = Relief.LANDFORMS[id]
				if form == nil then
					name = "Ground"
				else
					local slope = TerrainBake.slopeAt(shaped, wide, i + margin, k + margin, v)
					name = Relief.materialAt(form, Grid.boundsOf(id), plans[id], slope, depth[from], x, z)
					-- THE 70/30 SCREE MIX is the bake's, not `materialAt`'s -- its own header says
					-- so (design 5.3 step 3). Deterministic in the column, so a re-run is a no-op.
					if name == "Rock" and TerrainBake.mixAt(x, z) >= TerrainBake.SCREE_ROCK_SHARE then
						name = form.floor.default
					end
				end
			end
			innerNames[to] = name
		end
	end
	return inner, innerNames, n
end

-- ONE TILE: shape and material in the SAME WriteVoxels call (design 5.3 step 3). IDEMPOTENT --
-- every voxel of the region is written from the snapshot, so a re-run against the same snapshot is
-- a no-op. `dryRun` builds every array and skips only the write, so its cost is the real cost less
-- one engine call -- not a different measurement wearing the same name.
function TerrainBake.bakeTile(
	tile: Tile,
	snapshot: Snapshot,
	cellIds: { string },
	plans: { [string]: any },
	dryRun: boolean?,
	profiles: { Profile }?,
	reshape: { [string]: boolean }?,
	bend: any?,
	extras: { Snapshot }?
): TileReport
	local started = os.clock()
	local v = Relief.VOXEL
	local side = TerrainBake.TILE_STUDS
	local inner, innerNames, n = TerrainBake.shapeTile(tile, snapshot, cellIds, plans, profiles, reshape, bend, extras)
	local lo, hi = math.huge, -math.huge
	for _, h in inner do
		lo = math.min(lo, h)
		hi = math.max(hi, h)
	end
	local bands = TerrainBake.bandsFor(lo, hi)
	local report: TileReport = {
		minX = tile.minX,
		minZ = tile.minZ,
		calls = #bands,
		voxels = 0,
		bandMin = bands[1].min,
		bandMax = bands[#bands].max,
		elapsedMs = 0,
	}
	for _, band in bands do
		local region = Region3.new(
			Vector3.new(tile.minX, band.min, tile.minZ),
			Vector3.new(tile.minX + side, band.max, tile.minZ + side)
		):ExpandToGrid(v)
		local size = region.Size
		local ny = math.floor(size.Y / v + 0.5)
		local voxels = n * ny * n
		if voxels > TerrainBake.MAX_VOXELS then
			report.message = string.format(
				"tile (%d, %d) band %.0f..%.0f is %d voxels, over the measured ceiling %d",
				tile.minX,
				tile.minZ,
				band.min,
				band.max,
				voxels,
				TerrainBake.MAX_VOXELS
			)
			report.elapsedMs = math.floor((os.clock() - started) * 1000 + 0.5)
			return report
		end
		local min = region.CFrame.Position - size / 2
		local materials, occupancies = {}, {}
		for i = 1, n do
			materials[i], occupancies[i] = {}, {}
			for j = 1, ny do
				materials[i][j], occupancies[i][j] = {}, {}
			end
		end
		for i = 1, n do
			for k = 1, n do
				local at = (k - 1) * n + i
				local h = inner[at]
				local material = (Enum.Material :: any)[innerNames[at]] or Enum.Material.Ground
				for j = 1, ny do
					local bottom = min.Y + (j - 1) * v
					local occupancy = math.clamp((h - bottom) / v, 0, 1)
					materials[i][j][k] = if occupancy > 0 then material else AIR
					occupancies[i][j][k] = occupancy
				end
			end
		end
		if not dryRun then
			Workspace.Terrain:WriteVoxels(region, v, materials, occupancies)
		end
		report.voxels += voxels
	end
	report.elapsedMs = math.floor((os.clock() - started) * 1000 + 0.5)
	return report
end

-- HOW DEEP A POINT SITS BELOW THE GROUND THE LANDFORM CAME FROM -- what `Relief.materialAt`'s mud
-- rule reads (`A1.floor.mudDepthStuds` 10, `D1` 6). Round 1 passed a literal 0, so the rule could
-- never fire; C1's floor is plain `Ground`, so nothing was wrong for THIS cell, and 328f reads it.
function TerrainBake.depthAt(base: number, shaped: number): number
	return math.max(0, base - shaped)
end

-- HOW FAR OUTSIDE A TILE THE SNAPSHOT MUST REACH: the limiter's margin, plus the blur's own
-- cutoff, plus one voxel so the outermost sample has a neighbour. `Relief.blurredAt` is the only
-- point reader that leaves its point -- except a `bench`, which walks the base across its whole v
-- band (`applyOps`), and `bakeTileAt` refuses that rather than snapshot a slice it does not hold.
function TerrainBake.padFor(): number
	local v = Relief.VOXEL
	return v * math.ceil((TerrainBake.LIMIT_MARGIN_STUDS + Relief.BLUR.cutoffStuds + v) / v)
end

-- THE LONG PROFILES of every road a run touches, computed ONCE from the BASE SNAPSHOT before any
-- voxel is written. THE SAMPLER IS REQUIRED (task 328k): it used to default to a terrain raycast,
-- which reads the base only while nothing has been written yet -- so a second bake read its own
-- first bake and the road half drifted +2 studs a run (lineMeanY 108.88 -> 112.83 -> 114.81,
-- ESCALATE.md 2026-11-02). `TerrainBake.pointSampler` over `profileSamples` is the route.
function TerrainBake.profilesFor(cellIds: { string }, sampler: ((number, number) -> number?)?): { Profile }
	local read = assert(
		sampler,
		"TerrainBake.profilesFor: no sampler. The long profiles read the BASE SNAPSHOT (design 5.3 "
			.. "step 2); a live raycast here reads ground an earlier bake wrote, which is the +2 studs "
			.. "a bake the road half drifted on C1 (ESCALATE.md 2026-11-02)."
	)
	local wanted: { [string]: Relief.Road } = {}
	for _, id in cellIds do
		for _, key in { "main", "muster", "west", "east" } do
			local road = (Grid.roadsOf(id) :: any)[key]
			wanted[road.id] = road
		end
	end
	-- EVERY EAST-WEST ROAD IN THE WORLD FIRST, not just this run's. The E-W profile wins at a
	-- junction (design 7.1), so it is computed free -- and a north-south road is pinned to the E-W
	-- crown at EVERY crossing it has, including crossings outside the cells being baked. That is
	-- what makes a north-south profile the same bytes whatever cell list it is asked for, so two
	-- runs that share a road cannot meet at a step.
	local ewProfiles: { Profile } = {}
	for _, road in Grid.roads() do
		if road.axis == "x" then
			local profile = TerrainBake.longProfile(road, read)
			if profile ~= nil then
				table.insert(ewProfiles, profile)
			end
		end
	end
	local out: { Profile } = {}
	for _, road in wanted do
		local profile: Profile? = nil
		if road.axis == "x" then
			for _, ready in ewProfiles do
				if ready.road.id == road.id then
					profile = ready
				end
			end
		else
			profile = TerrainBake.longProfile(road, read, TerrainBake.junctionPins(road, ewProfiles))
		end
		if profile ~= nil then
			table.insert(out, profile)
		end
	end
	table.sort(out, function(a, b)
		return a.road.id < b.road.id
	end)
	return out
end

-- WHAT THE STEP AT EVERY CROSSING ACTUALLY IS, measured off the profiles the bake will use. Three
-- numbers a crossing, all of them read rather than argued:
--   `pinStuds`      the two crowns' disagreement AT the crossing. The pin makes this 0.
--   `worstStepStuds` the worst height difference between two voxel-adjacent columns on the junction
--                   square and one voxel past it -- which is the step the ground shows. The corner
--                   outside BOTH carriageways is skipped: there the 2-st ditch lip is the feature.
--   `explainedStuds` what the step at the square's edge is allowed to be anyway: the E-W crown's own
--                   rise over the square's half-width (`ewSpanStuds`) plus the crossfall, because
--                   the N-S crown is pinned FLAT across the square while the E-W one keeps climbing.
--                   A step above this is a discontinuity; below it, it is the road's own grade.
--
-- THE SQUARE IS WALKED IN THE ROADS' OWN LOCAL FRAME (task 328r, design 7.2): `dx` is measured from
-- the N-S road's REALISED centre at that z and `dz` from the E-W road's realised centre at that x,
-- so the sample 24 studs along a bend is still 24 studs along the CARRIAGEWAY and not 3 studs into
-- the ditch. At amplitude 0 both centres are `at` and every sample point is exactly what it was.
function TerrainBake.junctionSteps(profiles: { Profile }, bend: any?): { any }
	local spec = TerrainBake.ROAD
	local v = Relief.VOXEL
	local reach = spec.carriagewayStuds + v
	local rows = {}
	for _, ew in profiles do
		for _, ns in profiles do
			local a, b = ew.road, ns.road
			local crosses = a.axis == "x"
				and b.axis == "z"
				and b.at >= a.from
				and b.at <= a.to
				and a.at >= b.from
				and a.at <= b.to
			if crosses then
				local crownEW = TerrainBake.profileY(ew, b.at)
				local crownNS = TerrainBake.profileY(ns, a.at)
				local grid: { [string]: number } = {}
				for dx = -reach, reach, v do
					for dz = -reach, reach, v do
						-- THE SQUARE, PLUS ONE VOXEL PAST ITS BOUNDARY, minus the corner that is on
						-- neither carriageway (there the 2-st ditch lip is the feature, not a step)
						-- and minus anything past either road's END: the world's north edge is 21 st
						-- from EW3, so NS3 simply stops there and EW3's ditch is what is beyond it.
						-- That is a road end, not a junction, and it read 1.80 st when counted.
						local onEither = math.abs(dx) <= spec.carriagewayStuds or math.abs(dz) <= spec.carriagewayStuds
						-- THE REALISED CENTRES, SOLVED (task 328r). One pass is NOT enough: `bendX`
						-- is a function of z, and z is `a.at + bendZ(x) + dz`, which is up to 45
						-- studs from `a.at + dz` -- so the NS centre was read at the wrong station
						-- and a sample 16 studs onto the carriageway could land in the E-W ditch.
						-- MEASURED before the fix: worst step 1.8379 st at (+16,+24). The map
						-- contracts by |bendZ'| * |bendX'| <= 0.0163 a step, so three settle it.
						local x = Grid.roadCentreAt(b, a.at + dz, bend) + dx
						local z = Grid.roadCentreAt(a, x, bend) + dz
						for _ = 1, 3 do
							x = Grid.roadCentreAt(b, z, bend) + dx
							z = Grid.roadCentreAt(a, x, bend) + dz
						end
						-- THE RANGE TEST IS A GRID TEST, because `from`/`to` are grid stations.
						local u, w = Grid.toGrid(x, z, bend)
						local inBoth = u >= a.from and u <= a.to and w >= b.from and w <= b.to
						if onEither and inBoth then
							local y = TerrainBake.roadAt(profiles, crownEW, x, z, bend)
							if y ~= nil then
								grid[string.format("%d:%d", dx, dz)] = y
							end
						end
					end
				end
				local worst, atX, atZ = 0, 0, 0
				for key, y in grid do
					local dx = tonumber(string.match(key, "^(-?%d+):")) :: number
					local dz = tonumber(string.match(key, ":(-?%d+)$")) :: number
					for _, shift in { { v, 0 }, { 0, v } } do
						local other = grid[string.format("%d:%d", dx + shift[1], dz + shift[2])]
						if other ~= nil and math.abs(other - y) > worst then
							worst, atX, atZ = math.abs(other - y), dx, dz
						end
					end
				end
				local samples = 0
				for _ in grid do
					samples += 1
				end
				-- WHAT A STEP AT THE SQUARE'S EDGE IS ALLOWED TO BE, DERIVED. Inside the square the
				-- height is the E-W crown at x; just outside it on the N-S carriageway it is the N-S
				-- crown, which the pin holds FLAT at the E-W crown's value AT THE CROSSING. So the
				-- residual is the E-W crown's own rise over the square's half-width, plus the
				-- crossfall, because the two roads' crossfalls are perpendicular. Measured off this
				-- crossing's own profile, not off the road's worst grade.
				local ewSpan = math.max(
					math.abs(TerrainBake.profileY(ew, b.at + spec.carriagewayStuds) - crownEW),
					math.abs(TerrainBake.profileY(ew, b.at - spec.carriagewayStuds) - crownEW)
				)
				-- THE LATERAL STAIR, PRINTED (design 7.2 and the dispatch's own measure): the band
				-- is snapped to whole WORLD voxel columns at each station, so a bent road's rut and
				-- ditch edges step by one voxel every `Grid.bendFacts().stairStuds`. 0 at amplitude
				-- 0, because then there is no stair to climb.
				local facts = Grid.bendFacts(a.axis, bend)
				table.insert(rows, {
					ew = a.id,
					ns = b.id,
					samples = samples,
					x = b.at,
					z = a.at,
					pinStuds = math.abs(crownEW - crownNS),
					worstStepStuds = worst,
					atOffsetX = atX,
					atOffsetZ = atZ,
					ewSpanStuds = ewSpan,
					stairStuds = facts.stairStuds,
					swingDeg = facts.swingDeg,
					explainedStuds = ewSpan + spec.crownFallStuds,
				})
			end
		end
	end
	table.sort(rows, function(p: any, q: any)
		return p.ew .. p.ns < q.ew .. q.ns
	end)
	return rows
end

-- The terrain raycast reader, in one place: the survey and the profiles both use it.
function TerrainBake.terrainReader(): (number, number) -> number?
	return function(x: number, z: number): number?
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { Workspace.Terrain }
		params.IgnoreWater = true
		local hit = Workspace:Raycast(Vector3.new(x, 2000, z), Vector3.new(0, -4000, 0), params)
		return if hit then hit.Position.Y else nil
	end
end

function TerrainBake.readsWholeCell(form: any): boolean
	for _, op in form.ops do
		if op.kind == "bench" then
			return true
		end
	end
	return false
end

-- THE BAND OF BASE A BENCH READS OUTSIDE ITS OWN TILE, one rectangle a bench op, in WORLD studs
-- (task 328h). `applyOps` anchors a bench on the mean base over its band's first
-- `Relief.BENCH_ANCHOR_STUDS` at the same x, so a tile at the far end of the cell still reads ground
-- up to a cell's depth away -- which is why `bakeTileAt` used to refuse A1, B2 and D2 outright.
--
-- THE PAD IS THE THREE REACHES ADDED, never guessed: the blur's own cutoff plus one voxel (the
-- anchor smooths the base through `blurredAt`), and `Grid.maxBendStuds` because the walk is in GRID
-- coordinates and `baseAtGrid` reads the WORLD point the bend maps it to.
function TerrainBake.benchBands(cellIds: { string }): { any }
	local pad = Relief.BLUR.cutoffStuds + Relief.VOXEL + Grid.maxBendStuds()
	local out: { any } = {}
	for _, id in cellIds do
		local form = Relief.LANDFORMS[id]
		if form ~= nil then
			local bounds = Grid.boundsOf(id)
			for _, op in form.ops do
				if op.kind == "bench" then
					local z0 = bounds.minZ + op.v0 * (bounds.maxZ - bounds.minZ)
					table.insert(out, {
						cell = id,
						minX = bounds.minX - pad,
						maxX = bounds.maxX + pad,
						minZ = z0 - pad,
						maxZ = z0 + Relief.BENCH_ANCHOR_STUDS + pad,
					})
				end
			end
		end
	end
	return out
end

-- ONE TILE BY ITS INDEX IN THE PLAN -- what `tools/terrainbake.py` calls, so the tool sends one
-- expression and no geometry. It snapshots only what this tile's shaping reads.
function TerrainBake.bakeTileAt(
	tileIndex: number,
	cellIds: { string },
	dryRun: boolean,
	profiles: { Profile }?,
	-- ONE TILE'S SLICE OF THE BASE SNAPSHOT, as `tools/terrainbake.py` cut it out of the `.bin`
	-- (task 328k). REQUIRED: this used to call `TerrainBake.snapshot` here, which reads LIVE ground
	-- -- so a second bake read its own first bake and the landform could not be un-applied.
	slice: any?,
	-- ONE SLICE A BENCH BAND (task 328h): the same `.bin`, cut over `TerrainBake.benchBands`'
	-- rectangle clipped to this tile's own shaping window. A bench cell that arrives without its
	-- band is REFUSED below, never shaped off a reader that would answer nil in the band and leave
	-- the plane anchored on the unsmoothed base.
	benchSlices: { any }?
): TileReport
	local plan = TerrainBake.tilePlan(TerrainBake.regionFor(cellIds))
	assert(tileIndex >= 1 and tileIndex <= #plan, string.format("tile %d is not in a plan of %d", tileIndex, #plan))
	local tile = plan[tileIndex]
	local pad = TerrainBake.padFor()
	local side = TerrainBake.TILE_STUDS
	local bare = {
		minX = tile.minX,
		minZ = tile.minZ,
		calls = 0,
		voxels = 0,
		bandMin = 0,
		bandMax = 0,
		elapsedMs = 0,
	}
	if slice == nil then
		local refusal: TileReport = table.clone(bare)
		refusal.message = "no base snapshot slice was handed to tile "
			.. tostring(tileIndex)
			.. ". The base is read ONCE, before any write, from <runs-dir>/terrain-base-<sha>.bin; a "
			.. "slice read here would be read off ground this bake has already written (design 5.3 "
			.. "step 2, task 328k)."
		return refusal
	end
	local base = TerrainBake.decodeSlice(slice)
	-- THE SLICE MUST COVER THE TILE PLUS `padFor()`, or the limiter and the blur would read nil at
	-- the edge and `shapeTile` would KEEP GROUND there -- a seam, dressed as a snapshot.
	local wantMinX, wantMinZ = tile.minX - pad, tile.minZ - pad
	local wantMaxX, wantMaxZ = tile.minX + side + pad, tile.minZ + side + pad
	local haveMaxX = base.minX + base.nx * base.pitch
	local haveMaxZ = base.minZ + base.nz * base.pitch
	if
		base.minX > wantMinX + 1e-6
		or base.minZ > wantMinZ + 1e-6
		or haveMaxX < wantMaxX - 1e-6
		or haveMaxZ < wantMaxZ - 1e-6
	then
		local refusal: TileReport = table.clone(bare)
		refusal.message = string.format(
			"the slice x[%.0f,%.0f] z[%.0f,%.0f] does not cover tile %d plus its %d-stud pad, "
				.. "x[%.0f,%.0f] z[%.0f,%.0f]",
			base.minX,
			haveMaxX,
			base.minZ,
			haveMaxZ,
			tileIndex,
			pad,
			wantMinX,
			wantMaxX,
			wantMinZ,
			wantMaxZ
		)
		return refusal
	end
	-- A TILE WHOSE BASE HAS A HOLE ANYWHERE IN ITS SLICE IS REFUSED, NEVER GUESSED (design 5.3 step
	-- 2). THE PAD COUNTS, and that is the round-1 finding: the blur reads 72 studs out and the slope
	-- limiter 128, so a hole out there reaches the tile's own columns through
	-- `Relief.limitPass`, which pulls an unpinned neighbour down to within one window's ceiling of
	-- its pinned partner. Before 328k `bakeTileAt` snapshotted the tile plus pad with no `allowHoles`
	-- and got `nil, why` for a fault anywhere in it -- so refusing on the tile alone was a
	-- loosening, not a rule. The two counts are reported apart because they mean different things to
	-- whoever widens the band or the terrain.
	local inside = TerrainBake.holesInTile(base, tile)
	local holes = base.holes or 0
	if holes > 0 then
		local refusal: TileReport = table.clone(bare)
		refusal.message = string.format(
			"tile %d (%.0f, %.0f) holds %d base column(s) with no single height (Water, an overhang, "
				.. "or no ground in the Y band): %d inside the tile and %d in its %d-stud pad, which "
				.. "the blur and the slope limiter both read. A tile like that is REFUSED, never guessed.",
			tileIndex,
			tile.minX,
			tile.minZ,
			holes,
			inside,
			holes - inside,
			pad
		)
		return refusal
	end
	-- THE PROFILES ARE HANDED IN, ALWAYS. Round 2 fell back to `profilesFor` here, which raycasts
	-- LIVE terrain: from the second tile onwards that reads ground this bake has already written, so
	-- two tiles of one road would meet at a step and the result would depend on the tile order
	-- (round-2 finding 2). `tools/terrainbake.py` computes them ONCE from the base and sends the
	-- same set to every tile; a tile with none is REFUSED rather than given a profile of its own.
	if profiles == nil then
		return {
			minX = tile.minX,
			minZ = tile.minZ,
			calls = 0,
			voxels = 0,
			bandMin = 0,
			bandMax = 0,
			elapsedMs = 0,
			message = "no profiles were handed to tile "
				.. tostring(tileIndex)
				.. ". The long profiles are computed ONCE from the base, before any write, and sent "
				.. "to every tile; a profile read here would be read off half-baked ground.",
		}
	end
	-- THE BENCH BANDS, DECODED, AND A BENCH CELL WITHOUT ONE IS REFUSED (task 328h). The old rule
	-- here refused every bench cell outright -- A1, B2 and D2, three of the eight -- on the ground
	-- that "one tile's snapshot does not hold" the band. Since 328k the base is a sha-checked FILE,
	-- so the tool can cut that band out of it as a second rectangle and hand it in; what cannot be
	-- allowed is a bench shaped off a reader that answers nil over the band, because `applyOps` then
	-- anchors the plane on nothing and the tile comes out flat-dressed-as-shaped.
	local extras: { Snapshot } = {}
	if benchSlices ~= nil then
		for _, one in benchSlices do
			table.insert(extras, TerrainBake.decodeSlice(one))
		end
	end
	for _, band in TerrainBake.benchBands(cellIds) do
		local bandMinX = math.max(band.minX, tile.minX - pad)
		local bandMaxX = math.min(band.maxX, tile.minX + side + pad)
		if bandMinX < bandMaxX then
			local covered = false
			for _, extra in extras do
				local eMaxX = extra.minX + extra.nx * extra.pitch
				local eMaxZ = extra.minZ + extra.nz * extra.pitch
				if
					extra.minX <= bandMinX + 1e-6
					and eMaxX >= bandMaxX - 1e-6
					and extra.minZ <= band.minZ + 1e-6
					and eMaxZ >= band.maxZ - 1e-6
				then
					covered = true
				end
			end
			if not covered then
				local refusal: TileReport = table.clone(bare)
				refusal.message = string.format(
					"%s's landform has a bench and tile %d was handed no base slice covering its anchor "
						.. "band x[%.0f,%.0f] z[%.0f,%.0f]. The band is `TerrainBake.benchBands`' and is cut "
						.. "from the same `.bin` as the tile's own slice (task 328h); shaping without it "
						.. "would anchor the bench plane on nil.",
					band.cell,
					tileIndex,
					bandMinX,
					bandMaxX,
					band.minZ,
					band.maxZ
				)
				return refusal
			end
		end
	end
	-- THE LANDFORM ALWAYS GOES IN, BECAUSE `slice` IS THE VIRGIN BASE (task 328r; design 7.1).
	-- `reshapeWanted` was built when both halves of the bake raycast LIVE ground, where a second
	-- bake read its own first bake and `Relief.deltaAt`'s ops ADDED (+24.04 studs of second ridge on
	-- C1, 2026-11-02). Since 328k the slice is REQUIRED and comes out of the sha-checked `.bin`, so
	-- the bake writes ABSOLUTE heights over the old bake and there is nothing to double.
	--
	-- MEASURED, and it is why this is a defect and not a tidy-up: `reshapeWanted("C1")` answers
	-- `wanted=false, kind=stamped` in Karen's Forest Test (2026-11-03), so the old rule would have
	-- taken `shapeTile`'s keep-the-base branch and written C1's roads and pads onto ground with NO
	-- landform in it -- the ridge erased. The stamp is still WRITTEN (`stampShape`) and still read by
	-- the tool's own report; what it no longer does is decide this.
	local reshape: { [string]: boolean } = {}
	local why: { string } = {}
	for _, id in cellIds do
		reshape[id] = true
		local _, reason, kind = TerrainBake.reshapeWanted(id)
		table.insert(why, string.format("%s reshape=true (base is virgin; stamp says %s: %s)", id, kind, reason))
	end
	local report = TerrainBake.bakeTile(tile, base, cellIds, {}, dryRun, profiles, reshape, nil, extras)
	report.reshape = table.concat(why, "; ")
	-- THE STANDS NO ROAD REACHES, ON THE REPORT and not only in a header's promise (Reviewer, round
	-- 1, note 1): the caller said it reported them and nothing carried them out of `shapeTile`.
	local _, missed = TerrainBake.standPadsFor(cellIds, profiles)
	report.padsMissed = table.concat(missed, ",")
	return report
end

-- HOW FAR A POINT IS FROM THE NEAREST ROAD CENTRELINE it actually lies along, or math.huge. Used to
-- split the dry-run diff: the ROAD band drifts for the long profile's reason, the rest for the
-- landform's, and one mean over both would hide either.
-- SECOND COPY, NAMED: `Places.roadDistance` is the same arithmetic in another file (defect F-4,
-- `grid-roads.md` 12). Both read `Grid.roadCentreAt`, so `Grid` owns the line they measure from.
-- THE `from`/`to` TEST IS ASKED IN GRID COORDINATES (task 328r, 328q note (c)): a road's `from` and
-- `to` are grid stations, and testing a WORLD x against them put the end of the range up to 60
-- studs out at 45/60. The gap is then the GRID AXIS GAP -- `|z - roadCentreAt(road, x)|` IS
-- `|v - road.at|`, by `Grid.toGrid`'s own definition -- and that is the right one here, because the
-- caller is splitting a world-lattice diff into a road band and the rest and the two spaces agree
-- about which band a point is in. Named exactly (round 1, note).
function TerrainBake.roadDistance(x: number, z: number, bend: any?): number
	local best = math.huge
	local u, v = Grid.toGrid(x, z, bend)
	for _, road in Grid.roads() do
		if road.axis == "x" then
			if u >= road.from and u <= road.to then
				best = math.min(best, math.abs(z - Grid.roadCentreAt(road, x, bend)))
			end
		elseif v >= road.from and v <= road.to then
			best = math.min(best, math.abs(x - Grid.roadCentreAt(road, z, bend)))
		end
	end
	return best
end

-- THE DRY RUN'S DIFF, FOR ONE TILE: what the bake WOULD write against the ground that is there now.
-- IT WRITES NOTHING. Two classes, reported apart -- inside `ROAD.ditch.farStuds` of a centreline is
-- the road band, everything else is the landform's. `liveBase` true re-runs the SAME arithmetic off
-- a LIVE per-tile read, which is the pre-328k route, so the two can be compared with one instrument
-- (task 328k; design 5.3 step 2).
function TerrainBake.diffTileAt(
	tileIndex: number,
	cellIds: { string },
	profiles: { Profile }?,
	slice: any?,
	yMin: number,
	yMax: number,
	liveBase: boolean?,
	-- WHETHER THE LANDFORM GOES IN. nil asks `reshapeWanted`, which is what a bake does; true and
	-- false are the two questions a dry run has to be able to ask separately. With it FALSE the
	-- shaped height IS the base away from the roads, so the diff against already-baked ground is
	-- the whole landform -- which says nothing about whether a re-bake would double it. TRUE is the
	-- re-bake-from-the-base case, and its diff is the DRIFT alone.
	reshapeAll: boolean?
): any
	local plan = TerrainBake.tilePlan(TerrainBake.regionFor(cellIds))
	assert(tileIndex >= 1 and tileIndex <= #plan, string.format("tile %d is not in a plan of %d", tileIndex, #plan))
	local tile = plan[tileIndex]
	local v = Relief.VOXEL
	local side = TerrainBake.TILE_STUDS
	local pad = TerrainBake.padFor()
	local base: Snapshot
	if liveBase == true then
		local read, why = TerrainBake.snapshot({
			minX = tile.minX - pad,
			maxX = tile.minX + side + pad,
			minZ = tile.minZ - pad,
			maxZ = tile.minZ + side + pad,
		}, yMin, yMax, true)
		if read == nil then
			return { tile = tileIndex, message = why }
		end
		base = read
	else
		if slice == nil then
			return { tile = tileIndex, message = "no base snapshot slice" }
		end
		base = TerrainBake.decodeSlice(slice)
	end
	local reshape: { [string]: boolean } = {}
	local said: { string } = {}
	for _, id in cellIds do
		if reshapeAll ~= nil then
			reshape[id] = reshapeAll
			table.insert(said, string.format("%s reshape=%s (asked for)", id, tostring(reshapeAll)))
		else
			local wanted, reason = TerrainBake.reshapeWanted(id)
			reshape[id] = wanted
			table.insert(said, string.format("%s reshape=%s (%s)", id, tostring(wanted), reason))
		end
	end
	local inner, _names, n = TerrainBake.shapeTile(tile, base, cellIds, {}, profiles, reshape)
	-- AN IDENTITY FOR WHAT THIS TILE WOULD WRITE: FNV-1a over the heights at 1/64 of a stud. Not a
	-- cryptographic digest -- it is here so two dry runs can be compared in one number, which is
	-- what "a re-bake from the same snapshot is a no-op" means (design 1.1, idempotent).
	-- THE GROUND THAT IS THERE NOW, on the tile's own 32 x 32 column centres. A hole is skipped and
	-- counted, never compared against an invented height.
	local now, why = TerrainBake.snapshot({
		minX = tile.minX,
		maxX = tile.minX + side,
		minZ = tile.minZ,
		maxZ = tile.minZ + side,
	}, yMin, yMax, true)
	if now == nil then
		return { tile = tileIndex, message = why }
	end
	local fnv = 2166136261
	for at = 1, n * n do
		local q = math.round(inner[at] * TerrainBake.SLICE_SCALE) % 4294967296
		for _ = 1, 4 do
			fnv = bit32.bxor(fnv, q % 256)
			fnv = (fnv * 16777619) % 4294967296
			q = q // 256
		end
	end
	local out = {
		tile = tileIndex,
		minX = tile.minX,
		minZ = tile.minZ,
		shapeFnv = string.format("%08x", fnv),
		reshape = table.concat(said, "; "),
		n = 0,
		maxAbs = 0,
		sum = 0,
		roadN = 0,
		roadMaxAbs = 0,
		roadSum = 0,
		skipped = now.holes :: number,
		baseHoles = (base.holes :: number) or 0,
	}
	for i = 1, n do
		local x = tile.minX + (i - 0.5) * v
		for k = 1, n do
			local z = tile.minZ + (k - 0.5) * v
			local at = (k - 1) * n + i
			local hole = now.hole
			if not (hole ~= nil and hole[at] == true) then
				local d = inner[at] - now.height[at]
				out.n += 1
				out.sum += d
				out.maxAbs = math.max(out.maxAbs, math.abs(d))
				if TerrainBake.roadDistance(x, z) <= TerrainBake.ROAD.ditch.farStuds then
					out.roadN += 1
					out.roadSum += d
					out.roadMaxAbs = math.max(out.roadMaxAbs, math.abs(d))
				end
			end
		end
	end
	return out
end

-- A STABLE 0..1 PER COLUMN, from its own coordinates: the scree mix has to come out the same on
-- every run, so it cannot use `Random`. One integer hash, the shape `Grid.seedFor` already uses.
function TerrainBake.mixAt(x: number, z: number): number
	local h = bit32.bxor(
		bit32.band(math.floor(x / Relief.VOXEL) * 73856093, 0x7FFFFFFF),
		bit32.band(math.floor(z / Relief.VOXEL) * 19349663, 0x7FFFFFFF)
	)
	h = bit32.band(h * 1103515245 + 12345, 0x7FFFFFFF)
	return h / 0x7FFFFFFF
end

-- The slope at one grid point, in degrees, from its neighbours. One number for `Relief.materialAt`,
-- which is what decides scree -- never a second noise field.
function TerrainBake.slopeAt(grid: { number }, n: number, i: number, k: number, pitch: number): number
	local function at(a: number, b: number): number
		return grid[(math.clamp(b, 1, n) - 1) * n + math.clamp(a, 1, n)]
	end
	local dx = (at(i + 1, k) - at(i - 1, k)) / (2 * pitch)
	local dz = (at(i, k + 1) - at(i, k - 1)) / (2 * pitch)
	return math.deg(math.atan(math.sqrt(dx * dx + dz * dz)))
end

-- ---------------------------------------------------------------- the survey, read-only

-- 327a's own four fields plus `lineMeanY`, per cell, on the same 20-stud lattice. READ-ONLY: a
-- commit writes the numbers into `Grid.CELLS[*].relief`, never this function (design 5.5).
-- `heightOf` is the seam, so a spec can survey a synthetic world with no terrain in it.
-- A GRID RANGE, READ AT THE WORLD POINTS IT MAPS TO (task 328r, 328q note (c)). `Grid.boundsOf` is
-- the cell's GRID rectangle and `reader` is a WORLD reader: walking the grid range and handing its
-- numbers straight to the reader sampled the right points only at amplitude 0, and put the END of
-- the range up to 60 studs outside the cell at 45/60. Every sample now goes through `Grid.toWorld`,
-- which is the identity at 0, so no number here moves until the bend does.
--
-- `bend` IS A TRAILING OPTIONAL for the same reason as everywhere else in this seam.
function TerrainBake.survey(cellId: string, heightOf: ((number, number) -> number?)?, bend: any?): any
	local bounds = Grid.boundsOf(cellId)
	local reader = heightOf or TerrainBake.terrainReader()
	local lo, hi, sum, n = math.huge, -math.huge, 0, 0
	for u = bounds.minX, bounds.maxX, 20 do
		for v = bounds.minZ, bounds.maxZ, 20 do
			local y = reader(Grid.toWorld(u, v, bend))
			if y ~= nil then
				n += 1
				sum += y
				lo = math.min(lo, y)
				hi = math.max(hi, y)
			end
		end
	end
	local road = Grid.roadsOf(cellId).main
	local lineSum, lineN = 0, 0
	for u = bounds.minX, bounds.maxX, 20 do
		-- ALONG THE CURVE (task 328q): `lineMeanY` is the mean ground along the cell's own main line,
		-- so the sample has to follow it. `toWorld` gives the world x of this grid station; the main
		-- line's own z there is `roadCentreAt`, which IS that world curve.
		local x = (Grid.toWorld(u, road.at, bend))
		local y = reader(x, Grid.roadCentreAt(road, x, bend))
		if y ~= nil then
			lineN += 1
			lineSum += y
		end
	end
	local spread = if n > 0 then hi - lo else 0
	return {
		cell = cellId,
		samples = n,
		minY = if n > 0 then lo else 0,
		maxY = if n > 0 then hi else 0,
		meanY = if n > 0 then sum / n else 0,
		spreadStuds = spread,
		lineMeanY = if lineN > 0 then lineSum / lineN else 0,
		-- 327a's classifier, unchanged, so a baked ridge classifies by the same rule that classified
		-- the base as a slope and `grid.spec`'s assertions do not move (design 5.5).
		character = if spread < 20 then "flat" elseif spread < 60 then "slope" else "ridge",
	}
end

-- ---------------------------------------------------------------- the epoch

-- NO CODE COMMIT IN IT: a commit-based epoch fails the census after every paperwork commit, which
-- makes the census a liar on every review round (design 5.4). The digest itself is the tool's --
-- this is the input string, which has to be one definition.
function TerrainBake.epochInputFor(baseSnapshotSha: string): string
	local config = Grid.CONFIG
	local geometry = {
		originX = config.originX,
		originZ = config.originZ,
		cellWidthStuds = config.cellWidthStuds,
		cellDepthStuds = config.cellDepthStuds,
		roadClearStuds = config.roadClearStuds,
		rows = config.rows,
		columns = config.columns,
		-- THE BEND, so a changed amplitude changes the epoch and the stale-forest refusal fires
		-- (task 328q, defect F-2). `Relief.epochInput` flattens it into three hashed rows.
		bend = config.bend,
	}
	return baseSnapshotSha .. Relief.epochInput(Relief.LANDFORMS, geometry) .. tostring(Relief.BAKE_VERSION)
end

-- THE ONE WRITER of `TerrainEpoch`.
function TerrainBake.stamp(epoch: string, where: Instance?): ()
	local target = where or Workspace.Terrain
	target:SetAttribute("TerrainEpoch", epoch)
end

-- ---------------------------------------------------------------- the landform is written ONCE

-- A CELL'S LANDFORM SHAPE, as a string: `baseKeep` and `ops`, and NOT `floor`, which is material and
-- moves no ground. `Relief.epochInput`'s own canonical encoder, so there is one definition of "the
-- same landform".
function TerrainBake.shapeInputFor(cellId: string): string
	local form = Relief.LANDFORMS[cellId]
	if form == nil then
		return ""
	end
	return Relief.epochInput({ [cellId] = { baseKeep = form.baseKeep, ops = form.ops } }, Grid.CONFIG)
end

-- MAY THIS RUN APPLY THE LANDFORM TO THIS CELL, OR IS IT ALREADY IN THE GROUND?
--
-- `Relief.deltaAt`'s ops are ADDITIVE (`h += weightOf(op) * dyStuds`), and `heightAt` returns
-- `base + k * ((h0 - base) + roadFade * delta)`. So a bake whose BASE IS ALREADY BAKED GROUND adds
-- the landform a second time. MEASURED in Karen's Forest Test on 2026-11-02 before this task wrote
-- anything (`<runs-dir>/328e-drift-BEFORE.json`): over 90 points of C1 a fresh bake would have
-- raised the ground by a mean of 3.67 studs, 27 points by more than half a stud, NONE lowered, and
-- the worst was **+24.04 studs on the ridge line** -- which is `C1.ops[1].dyStuds` 24, exactly. The
-- cell would have grown a second ridge on top of the one 328d and 328j already put there.
--
-- THE RULE: the landform goes in ONCE, AND IT IS ASKED PER CELL. `TerrainShape_<id>` is written at
-- the end of a WET run, for the cells THAT RUN covered, and a run covers only its own `--cells`
-- (`regionFor`). `TerrainEpoch` is ONE attribute for the whole Terrain, so it cannot answer this
-- question: round 1 read it and would have told a never-baked A1 that its landform was already in
-- the ground, painting roads and pads onto raw relief -- the one thing this series exists to build
-- (Reviewer, task 328e round 1, finding 1). Only the per-cell stamp is evidence about a cell.
--
-- WHAT THIS DOES NOT DO, said plainly: it cannot UN-apply a landform. Changing a cell's `ops` after
-- a bake needed the original base back. SINCE TASK 328k IT DOES NOT: the base is a sha-checked
-- `.bin` and the bake writes ABSOLUTE heights, so `bakeTileAt` applies the landform every time and
-- this answer is a REPORT; `tools/terrainbake.py` no longer refuses on it (refusal 7b, retired in
-- task 328r and archived under `backups/`).
--
-- **WHAT NOTHING CHECKS, SAID PLAINLY:** that the `--base` file was captured off VIRGIN ground.
-- `check_base` proves the bytes match `--base-sha`, not that they are the original; a snapshot
-- taken after a bake would pass it and the landform would go in twice. The operator naming the
-- recorded sha is the whole guard.
-- Storing the base snapshot so a re-shape needs no backup is design 5.3 step 2's whole-cell route
-- and is not built.
--
-- The third return is the reason as a WORD, so the tool branches on it and not on prose.
function TerrainBake.reshapeWanted(cellId: string, where: Instance?): (boolean, string, string)
	local target = where or Workspace.Terrain
	local stamped = target:GetAttribute("TerrainShape_" .. cellId)
	if stamped == nil then
		return true, string.format("no TerrainShape_%s: this cell's landform is not in its ground", cellId), "virgin"
	end
	if tostring(stamped) ~= TerrainBake.shapeInputFor(cellId) then
		return true, "the landform's shape has changed since the stamp: the base must be restored first", "changed"
	end
	return false, "the stamped shape is this landform: it is already in the ground", "stamped"
end

-- THE ONE WRITER of `TerrainShape_<id>`, called at the end of a wet run beside `stamp`.
function TerrainBake.stampShape(cellIds: { string }, where: Instance?): number
	local target = where or Workspace.Terrain
	local written = 0
	for _, id in cellIds do
		if Relief.LANDFORMS[id] ~= nil then
			target:SetAttribute("TerrainShape_" .. id, TerrainBake.shapeInputFor(id))
			written += 1
		end
	end
	return written
end

-- ---------------------------------------------------------------- the archive, and the census

-- B3: REPARENT ONLY, never Destroy (rule 7). `seams.archiveParent` is handed in, so nothing here
-- requires a server script.
function TerrainBake.archive(folderName: string, seams: any): any
	local source = Workspace:FindFirstChild(folderName)
	if source == nil then
		return { moved = 0, message = folderName .. " is not in Workspace" }
	end
	local into = (seams ~= nil and seams.archiveParent) or game:GetService("ServerStorage")
	local moved = #source:GetChildren()
	source.Name = folderName .. "-archived-" .. os.date("!%Y%m%dT%H%M%SZ")
	source.Parent = into
	return { moved = moved, name = source.Name, into = into:GetFullName() }
end

-- Delegates to `ServerStorage.GridCensus`, handed in as a seam so this module requires no server
-- script (design 5.1).
function TerrainBake.census(seams: any): any
	assert(seams ~= nil and seams.census ~= nil, "TerrainBake.census: no census seam")
	return seams.census()
end

return TerrainBake
