--!strict
-- THE EIGHT LANDFORMS, AND THE ARITHMETIC THAT SHAPES THEM. **REQUIRES NOTHING** -- no Instance, no
-- Terrain, no service, no `Random` -- so every landform is assertable with no terrain in the world.
-- Design: docs/design/grid-terrain.md section 4. Recipes: reviews/task-328/SWARM_DESIGN.md section 2.2.
--
-- NOTHING HERE WRITES TERRAIN. The one writer of terrain height and material is the Edit-time bake
-- (`tools/terrainbake.py` driving `ServerStorage.TerrainBake`, task 328d), and design section 1.2
-- item 1 forbids any writer under `src/` -- `tests/server/grid_relief.spec.luau` asserts it.
--
-- `baseAt` IS A FUNCTION HANDED IN (design section 4 rule 1): the bake passes a reader over the base
-- snapshot, a spec passes a fake hillside. This is `Places.groundsUnder`'s own discipline.
-- `Relief` never requires `Grid` and `Grid` never requires `Relief`; the caller composes them.

local Relief = {}

-- ---------------------------------------------------------------- the facts

-- BUMPS WHEN THE ARITHMETIC MOVES -- a falloff shape, the blur sigma, the limiter, the road fade,
-- the Y-band rule, `columnsFor`. NOT for a data change: `epochInput` already covers that.
-- `relief_golden.luau` fails the harness if the maths moves without this number (design 5.4).
--
-- STAYS 1 THROUGH TASK 328x, AND THE REASON IS A MEASUREMENT, NOT A JUDGEMENT (Reviewer round 1,
-- finding 2). 328x adds an `absent` arm to `limitPass` and takes the Y band over the columns that
-- have ground -- both arithmetic by design 5.4's list. But both arms are reached ONLY by a column
-- the base cannot answer, which could not occur in any stamped ground: `bakeTileAt` refused every
-- such tile outright before this task. The evidence is direct rather than argued -- B1, C1 and D1
-- were re-baked by THIS code over ground the OLD code wrote, and all 3 x 95,944 interior columns
-- came back BYTE-IDENTICAL (`328x-row1-before.bin` / `-after2.bin`). A bump would re-stamp every
-- cell to say the ground changed when it is the same ground to the bit. The next change to the
-- limiter or the Y band that CAN move an existing column bumps this.
Relief.BAKE_VERSION = 1

-- How far outside the footprint the result returns to the base, exactly (design 3.0).
Relief.BLEND_STUDS = 200

-- Every op is 0 within 51 studs of a road centreline and full at 120, so no landform tilts a road.
Relief.ROAD_FADE = table.freeze({ zeroStuds = 51, fullStuds = 120 })

-- The base blur: a Gaussian sigma 24 studs cut off at 72 (3 sigma), run separably.
Relief.BLUR = table.freeze({ sigmaStuds = 24, cutoffStuds = 72 })

-- HOW FAR INTO ITS BAND A BENCH WALKS THE BASE to anchor its plane (`applyOps`). Named here, not
-- written twice, because `TerrainBake.benchBands` cuts the base slice that walk reads (task 328h).
Relief.BENCH_ANCHOR_STUDS = 20

-- The slope ceiling the limiter clamps to, by zone (design 3.0). The scarp and ramps are exempt.
Relief.LIMIT_DEG = table.freeze({ tree = 20, open = 32 })

-- THE ENGINE'S TERRAIN VOXEL, and the only resolution `WriteVoxels` takes. One fact with
-- `Places.Ground.RESOLUTION` and `MapGen.Config.VOXEL`; the spec asserts the three are equal.
Relief.VOXEL = 4

-- ---------------------------------------------------------------- types

export type Bounds = { minX: number, maxX: number, minZ: number, maxZ: number }

export type Road = { id: string, axis: string, at: number, from: number, to: number }

export type Op = {
	kind: string,
	-- dome / knoll / bowl
	u: number?,
	v: number?,
	rStuds: number?,
	-- D1's dish is an ellipse, which SWARM section 2.2 asks for and the design's Op sketch has no
	-- field for: `rzStuds` is the z radius, and nil means a circle of `rStuds`.
	rzStuds: number?,
	dyStuds: number?,
	flatFraction: number?,
	-- ridge / trough
	via: { { u: number, v: number, dyStuds: number } }?,
	halfWidthStuds: number?,
	-- bench
	v0: number?,
	v1: number?,
	weight: number?,
	gradePercent: number?,
	-- scarp
	dropStuds: number?,
	runStuds: number?,
	-- ramp
	widthStuds: number?,
}

export type Landform = {
	baseKeep: number,
	ops: { Op },
	noTrees: { { v0: number, v1: number } }?,
	floor: { default: string, mudDepthStuds: number?, screeDegFrom: number?, screeDegTo: number? },
}

-- ---------------------------------------------------------------- small pure maths

-- An op's own field, with the name in the failure -- selene requires every assert to say something.
local function need(value: number?, what: string): number
	return assert(value, "Relief: an op is missing " .. what)
end

local function clamp01(t: number): number
	return if t < 0 then 0 elseif t > 1 then 1 else t
end

-- Hermite smoothstep, the one falloff every op uses (design 3.0).
local function smoothstep(t: number): number
	local c = clamp01(t)
	return c * c * (3 - 2 * c)
end

function Relief.uvOf(bounds: Bounds, x: number, z: number): (number, number)
	return (x - bounds.minX) / (bounds.maxX - bounds.minX), (z - bounds.minZ) / (bounds.maxZ - bounds.minZ)
end

local function xzOf(bounds: Bounds, u: number, v: number): (number, number)
	return bounds.minX + u * (bounds.maxX - bounds.minX), bounds.minZ + v * (bounds.maxZ - bounds.minZ)
end

-- ---------------------------------------------------------------- the blur

-- THE 1-D HALF-KERNEL, normalised over the whole 2-D separable support, sampled at the voxel pitch.
-- Index 1 is the centre tap; the last entry is the tap at the cutoff.
function Relief.blurKernel(): { number }
	local taps = math.floor(Relief.BLUR.cutoffStuds / Relief.VOXEL)
	local out: { number } = {}
	local sum = 0
	for i = 0, taps do
		local d = i * Relief.VOXEL
		local w = math.exp(-(d * d) / (2 * Relief.BLUR.sigmaStuds * Relief.BLUR.sigmaStuds))
		out[i + 1] = w
		sum += if i == 0 then w else 2 * w
	end
	for i = 1, #out do
		out[i] /= sum
	end
	return out
end

local KERNEL: { number } = Relief.blurKernel()

-- blur(base) AT ONE POINT. The kernel is separable, so this is the 1-D kernel applied twice; it
-- returns nil the moment the base reader does, because a hole in the snapshot is not a zero.
local function blurredAt(baseAt: (number, number) -> number?, x: number, z: number): number?
	local taps = #KERNEL - 1
	local total = 0
	for iz = -taps, taps do
		local wz = KERNEL[math.abs(iz) + 1]
		local row = 0
		for ix = -taps, taps do
			local y = baseAt(x + ix * Relief.VOXEL, z + iz * Relief.VOXEL)
			if y == nil then
				return nil
			end
			row += KERNEL[math.abs(ix) + 1] * y
		end
		total += wz * row
	end
	return total
end

-- The per-point kernel, exposed so a spec can measure the separable grid pass against it. The bake
-- never calls this one: it is the reference, not the route (328c note (c)).
function Relief.blurredAtPoint(baseAt: (number, number) -> number?, x: number, z: number): number?
	return blurredAt(baseAt, x, z)
end

-- THE SAME BLUR OVER A WHOLE GRID, as a SEPARABLE row-then-column pass: 2 x 37 reads a point
-- instead of 37 x 37 = 1,369 (328c note (c), and 328d is the task that pays -- its server spec run
-- timed out at 300 s with the per-point kernel). A Gaussian is separable exactly, and both passes
-- normalise by the same 1-D kernel, so the answer is `blurredAt`'s to float error -- which
-- `grid_relief.spec` MEASURES rather than this comment promising it.
--
-- nil anywhere inside a point's support makes that point nil, exactly as `blurredAt` does.
function Relief.blurredGrid(
	baseAt: (number, number) -> number?,
	minX: number,
	minZ: number,
	nx: number,
	nz: number
): { number? }
	local v = Relief.VOXEL
	local taps = #KERNEL - 1
	-- THE ROW PASS RUNS `taps` ROWS PAST THE GRID on each side, so the column pass never falls off
	-- the end and no point has to pay the per-point kernel as a fallback.
	local tall = nz + 2 * taps
	local rows: { number? } = table.create(nx * tall, 0)
	for k = 1, tall do
		local z = minZ + (k - 1 - taps) * v
		for i = 1, nx do
			local x = minX + (i - 1) * v
			local total, ok = 0, true
			for ix = -taps, taps do
				local y = baseAt(x + ix * v, z)
				if y == nil then
					ok = false
					break
				end
				total += KERNEL[math.abs(ix) + 1] * y
			end
			rows[(k - 1) * nx + i] = if ok then total else nil
		end
	end
	local out: { number? } = table.create(nx * nz, 0)
	for i = 1, nx do
		for k = 1, nz do
			local total: number? = 0
			for iz = -taps, taps do
				local y = rows[(k + taps + iz - 1) * nx + i]
				if y == nil then
					total = nil
					break
				end
				total = (total :: number) + KERNEL[math.abs(iz) + 1] * y
			end
			out[(k - 1) * nx + i] = total
		end
	end
	return out
end

-- ---------------------------------------------------------------- one op's falloff

-- The nearest point on a polyline, in STUD space: the perpendicular distance and the `dyStuds`
-- interpolated linearly along the segment it fell on (design 3.0, ridge and trough).
local function alongVia(op: Op, bounds: Bounds, x: number, z: number): (number, number)
	local via = assert(op.via, "Relief: a ridge or trough needs `via`")
	local bestD, bestDy = math.huge, 0
	for i = 1, #via - 1 do
		local ax, az = xzOf(bounds, via[i].u, via[i].v)
		local bx, bz = xzOf(bounds, via[i + 1].u, via[i + 1].v)
		local dx, dz = bx - ax, bz - az
		local len2 = dx * dx + dz * dz
		local t = if len2 > 0 then clamp01(((x - ax) * dx + (z - az) * dz) / len2) else 0
		local px, pz = ax + t * dx, az + t * dz
		local d = math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
		if d < bestD then
			bestD = d
			bestDy = via[i].dyStuds + t * (via[i + 1].dyStuds - via[i].dyStuds)
		end
	end
	return bestD, bestDy
end

-- ONE OP'S FALLOFF, 0..1, and 0 outside its support with a zero first derivative there -- design
-- 13.1 case 3, so no 4-stud voxel can show a step at the edge.
function Relief.weightOf(op: Op, bounds: Bounds, x: number, z: number): number
	if op.kind == "dome" or op.kind == "knoll" or op.kind == "bowl" then
		local cx, cz = xzOf(bounds, need(op.u, "u"), need(op.v, "v"))
		local rx = need(op.rStuds, "rStuds")
		local rz = op.rzStuds or rx
		local t = math.sqrt(((x - cx) / rx) ^ 2 + ((z - cz) / rz) ^ 2)
		local flat = op.flatFraction
		if flat ~= nil and flat > 0 then
			if t <= flat then
				return 1
			end
			return 1 - smoothstep((t - flat) / (1 - flat))
		end
		return 1 - smoothstep(t)
	elseif op.kind == "ridge" or op.kind == "trough" then
		local d = alongVia(op, bounds, x, z)
		local half = need(op.halfWidthStuds, "halfWidthStuds")
		if d >= half then
			return 0
		end
		-- A cos^2 cross-profile: 1 on the line, 0 at the half-width, flat at both ends.
		return math.cos((math.pi / 2) * (d / half)) ^ 2
	elseif op.kind == "bench" then
		local z0 = bounds.minZ + need(op.v0, "v0") * (bounds.maxZ - bounds.minZ)
		local z1 = bounds.minZ + need(op.v1, "v1") * (bounds.maxZ - bounds.minZ)
		-- The v-edges blend by smoothstep over 40 studs (design 3.0), INSIDE the band: a bench that
		-- bled 40 studs past its own v1 put 5.5 studs of plateau on top of B2's scarp and read the
		-- 28-stud face as a 33.5-stud one (MEASURED 2026-11-02, task 328c round 1).
		local rise = smoothstep((z - z0) / 40)
		local fall = 1 - smoothstep((z - (z1 - 40)) / 40)
		return math.min(rise, fall)
	elseif op.kind == "ramp" then
		local cx = bounds.minX + need(op.u, "u") * (bounds.maxX - bounds.minX)
		local half = need(op.widthStuds, "widthStuds") / 2
		local d = math.abs(x - cx)
		if d <= half then
			return 1
		end
		-- The sides blend over 16 studs (design 3.0).
		return 1 - smoothstep((d - half) / 16)
	elseif op.kind == "scarp" then
		return 1
	end
	error("Relief.weightOf: unknown op kind " .. tostring(op.kind))
end

-- THE SCARP'S OWN PROFILE, as a signed delta: 0 on the plateau (low v) and -drop past the face.
-- `runStuds` is handed in, which is what a ramp replaces with the longer run its grade needs.
local function scarpProfile(op: Op, bounds: Bounds, z: number, runStuds: number): number
	local zc = bounds.minZ + need(op.v, "v") * (bounds.maxZ - bounds.minZ)
	local drop = need(op.dropStuds, "dropStuds")
	return -drop * smoothstep((z - (zc - runStuds / 2)) / runStuds)
end

-- ---------------------------------------------------------------- the ops, in order

-- WHAT THE OPS DO TO ONE HEIGHT, applied IN ORDER. `upTo` exists for the bench, whose plane is
-- anchored on the ground it meets -- so it asks this function for the height before itself.
local function applyOps(
	form: Landform,
	bounds: Bounds,
	baseAt: (number, number) -> number?,
	h0: number,
	x: number,
	z: number,
	upTo: number
): number
	local h = h0
	local scarp: Op? = nil
	for i = 1, upTo do
		local op = form.ops[i]
		local kind = op.kind
		if kind == "dome" or kind == "knoll" or kind == "bowl" then
			h += Relief.weightOf(op, bounds, x, z) * need(op.dyStuds, "dyStuds")
		elseif kind == "ridge" or kind == "trough" then
			-- A ridge or trough's height is the polyline's own, interpolated along the segment.
			local _, dy = alongVia(op, bounds, x, z)
			h += Relief.weightOf(op, bounds, x, z) * dy
		elseif kind == "scarp" then
			scarp = op
			h += scarpProfile(op, bounds, z, need(op.runStuds, "runStuds"))
		elseif kind == "ramp" then
			-- THE RAMP REPLACES THE SCARP'S DROP with a linear grade over the run that grade needs,
			-- on its own 60-stud strip. SWARM section 2.2 B2; design 15 item 4 is why there are three.
			local face = assert(scarp, "Relief: a ramp needs a scarp before it")
			local drop = need(face.dropStuds, "dropStuds")
			local run = drop / (need(op.gradePercent, "gradePercent") / 100)
			local zc = bounds.minZ + need(face.v, "v") * (bounds.maxZ - bounds.minZ)
			local linear = -drop * clamp01((z - (zc - run / 2)) / run)
			local plain = scarpProfile(face, bounds, z, need(face.runStuds, "runStuds"))
			h += Relief.weightOf(op, bounds, x, z) * (linear - plain)
		elseif kind == "bench" then
			local w = need(op.weight, "weight") * Relief.weightOf(op, bounds, x, z)
			if w > 0 then
				-- THE PLANE IS ANCHORED ON THE MEAN HEIGHT OVER THE BENCH'S FIRST 20 STUDS at this
				-- same x, so the bench starts on the ground it meets rather than at a chosen Y.
				local z0 = bounds.minZ + need(op.v0, "v0") * (bounds.maxZ - bounds.minZ)
				local sum, n = 0, 0
				for s = 0, Relief.BENCH_ANCHOR_STUDS, Relief.VOXEL do
					local b = baseAt(x, z0 + s)
					if b ~= nil then
						local smoothed = if form.baseKeep >= 1 then b else blurredAt(baseAt, x, z0 + s)
						local hb = form.baseKeep * b + (1 - form.baseKeep) * (smoothed or b)
						sum += applyOps(form, bounds, baseAt, hb, x, z0 + s, i - 1)
						n += 1
					end
				end
				if n > 0 then
					local anchor = sum / n
					local plane = anchor + (z - z0) * (need(op.gradePercent, "gradePercent") / 100)
					h = (1 - w) * h + w * plane
				end
			end
		else
			error("Relief: unknown op kind " .. tostring(kind))
		end
	end
	return h
end

-- EVERYTHING THE OPS ADD TO THE BLURRED BASE at one point, as a signed delta in studs.
function Relief.deltaAt(
	form: Landform,
	bounds: Bounds,
	baseAt: (number, number) -> number?,
	h0: number,
	x: number,
	z: number
): number
	return applyOps(form, bounds, baseAt, h0, x, z, #form.ops) - h0
end

-- ---------------------------------------------------------------- the road fade

-- 0 WITHIN 51 STUDS OF ANY ROAD CENTRELINE and 1 at 120, by smoothstep -- so no landform can tilt a
-- road and no hunter sights along a crowned carriageway (design 3.0, 7.1).
function Relief.roadFadeAt(roads: { Road }, x: number, z: number): number
	local nearest = math.huge
	for _, road in roads do
		local d
		if road.axis == "x" then
			local along = math.max(road.from - x, x - road.to, 0)
			d = math.sqrt((z - road.at) ^ 2 + along * along)
		else
			local along = math.max(road.from - z, z - road.to, 0)
			d = math.sqrt((x - road.at) ^ 2 + along * along)
		end
		if d < nearest then
			nearest = d
		end
	end
	local fade = Relief.ROAD_FADE
	return smoothstep((nearest - fade.zeroStuds) / (fade.fullStuds - fade.zeroStuds))
end

-- ---------------------------------------------------------------- the one height

-- THE SHAPED HEIGHT AT ONE POINT, or nil where the base reader has no answer.
--   h = base + k * ( (1 - baseKeep) * (blur(base) - base) + roadFade * delta )
-- `k` is 1 inside the cell and 0 at `BLEND_STUDS` outside it, so past 200 studs the answer IS the
-- base, exactly -- the blur fades out with the ops (design 3.0, 13.1 case 7).
--
-- `blend` OVERRIDES that `k` (task 328d). The bake fades ONCE, from the edge of the region it is
-- baking, and multiplying its own fade onto this one gave two in series -- the square of the
-- design's falloff. Handing the weight in keeps ONE fade and keeps it here, where the arithmetic
-- lives. Omitted, nothing moves: every caller before 328d gets the cell-edge `k` exactly as before.
function Relief.heightAt(
	form: Landform,
	bounds: Bounds,
	roads: { Road },
	baseAt: (number, number) -> number?,
	x: number,
	z: number,
	blend: number?,
	smoothedAt: number?
): number?
	local base = baseAt(x, z)
	if base == nil then
		return nil
	end
	local k: number
	if blend ~= nil then
		k = blend
	else
		local dx = math.max(bounds.minX - x, x - bounds.maxX, 0)
		local dz = math.max(bounds.minZ - z, z - bounds.maxZ, 0)
		local outside = math.sqrt(dx * dx + dz * dz)
		k = 1 - smoothstep(outside / Relief.BLEND_STUDS)
	end
	if k <= 0 then
		return base
	end
	-- `smoothedAt` is the blur ALREADY COMPUTED for this point, which is how the bake hands in a
	-- separable grid pass instead of paying 1,369 base reads here (328c note (c)).
	local smoothed = if form.baseKeep >= 1
		then base
		elseif smoothedAt ~= nil then smoothedAt
		else blurredAt(baseAt, x, z)
	if smoothed == nil then
		return nil
	end
	local h0 = form.baseKeep * base + (1 - form.baseKeep) * smoothed
	local delta = Relief.deltaAt(form, bounds, baseAt, h0, x, z)
	return base + k * ((h0 - base) + Relief.roadFadeAt(roads, x, z) * delta)
end

-- ---------------------------------------------------------------- the slope limiter

-- WHERE THE LIMITER MAY NOT TOUCH: the scarp's face and the ramps that climb it. Design 3.0 says
-- they are exempt; without this the limiter would flatten the one landform B2 is named for.
function Relief.isExempt(form: Landform, bounds: Bounds, x: number, z: number): boolean
	local face: Op? = nil
	for _, op in form.ops do
		if op.kind == "scarp" then
			face = op
		end
	end
	if face == nil then
		return false
	end
	local op = face :: Op
	local zc = bounds.minZ + need(op.v, "v") * (bounds.maxZ - bounds.minZ)
	local reach = need(op.runStuds, "runStuds") / 2 + 8
	for _, other in form.ops do
		if other.kind == "ramp" and Relief.weightOf(other, bounds, x, z) > 0 then
			local run = need(op.dropStuds, "dropStuds") / (need(other.gradePercent, "gradePercent") / 100)
			reach = math.max(reach, run / 2 + 8)
		end
	end
	return math.abs(z - zc) <= reach
end

-- EIGHT RELAXATION PASSES that bring every 16-stud window under `ceilingDeg`, moving the two ends of
-- an over-steep window half the excess each. `exempt[i]` true pins that sample (the scarp, the ramps).
--
-- `absent[i]` IS A COLUMN THE BASE CANNOT ANSWER -- beyond the edge of the world -- AND IT IS NO
-- CONSTRAINT: every window with an absent end is DROPPED, never pinned (Director decision, task
-- 328x, `ESCALATE.md` 2026-11-04). Pinning it at the band floor made the limiter drag the real
-- ground beside it down toward ground that does not exist.
function Relief.limitPass(
	column: { number },
	pitchStuds: number,
	ceilingDeg: number,
	exempt: { boolean }?,
	absent: { boolean }?
): { number }
	local out: { number } = table.clone(column)
	local gone = function(i: number): boolean
		return absent ~= nil and absent[i] == true
	end
	local window = math.max(1, math.floor(16 / pitchStuds + 0.5))
	local ceiling = 16 * math.tan(math.rad(ceilingDeg))
	-- EIGHT PASSES, ALTERNATING DIRECTION. One direction alone leaves the far end of a long face
	-- 0.3 degrees over the ceiling after 8 passes (MEASURED 2026-11-02, task 328c round 1).
	for pass = 1, 8 do
		local from, to, step = 1, #out - window, 1
		if pass % 2 == 0 then
			from, to, step = #out - window, 1, -1
		end
		for i = from, to, step do
			local j = i + window
			local d = out[j] - out[i]
			local excess = math.abs(d) - ceiling
			if excess > 0 and not (gone(i) or gone(j)) then
				local pinI = exempt ~= nil and exempt[i] == true
				local pinJ = exempt ~= nil and exempt[j] == true
				if not (pinI and pinJ) then
					local sign = if d > 0 then 1 else -1
					local shareI = if pinI then 0 elseif pinJ then excess else excess / 2
					local shareJ = if pinJ then 0 elseif pinI then excess else excess / 2
					out[i] += sign * shareI
					out[j] -= sign * shareJ
				end
			end
		end
	end
	-- AND A FINISHING CLAMP, because eight relaxation passes do not reach the ceiling on their own:
	-- a 63-degree cliff comes out at 22.9 degrees against a ceiling of 20 (MEASURED 2026-11-02).
	-- Windows only link i and i+window, so each residue class mod `window` is an independent chain,
	-- and a forward-then-backward min-cone sweep is EXACT on a chain. It only cuts, and never a pin.
	for _ = 1, 2 do
		for i = 1, #out - window do
			local j = i + window
			if out[j] - out[i] > ceiling and not (exempt ~= nil and exempt[j] == true) and not (gone(i) or gone(j)) then
				out[j] = out[i] + ceiling
			end
		end
		for i = #out - window, 1, -1 do
			local j = i + window
			if out[i] - out[j] > ceiling and not (exempt ~= nil and exempt[i] == true) and not (gone(i) or gone(j)) then
				out[i] = out[j] + ceiling
			end
		end
	end
	return out
end

-- ---------------------------------------------------------------- whole voxel columns

-- A NOMINAL BAND BECOMES WHOLE VOXEL COLUMNS, and the realised WIDTH does not depend on the centre's
-- parity. This is `Places.Ground.bandBounds`' arithmetic generalised to an off-centre band on either
-- axis -- borrowed, not re-derived (design 4 rule 2, 7.1 correction F-2).
function Relief.columnsFor(centreStuds: number, nearStuds: number, farStuds: number): (number, number)
	local columns = math.max(1, math.ceil((farStuds - nearStuds) / Relief.VOXEL))
	local mid = centreStuds + (nearStuds + farStuds) / 2
	local first = Relief.VOXEL * math.floor((mid - columns * Relief.VOXEL / 2) / Relief.VOXEL)
	return first, first + columns * Relief.VOXEL
end

-- ---------------------------------------------------------------- the floor material

-- THE ZONE FLOOR AT ONE POINT. Four cells state a rule in SWARM section 2.2; the other four take
-- C1's litter default (328e, 328y) -- the `Ground` placeholder is gone until `CELL_PLANS` v2
-- carries the per-ZONE floor (328f). The 70/30 scree MIX is the bake's, not this (design 5.3).
function Relief.materialAt(
	form: Landform,
	_bounds: Bounds,
	_plan: any,
	slopeDeg: number,
	depthStuds: number,
	_x: number,
	_z: number
): string
	local floor = form.floor
	if floor.mudDepthStuds ~= nil and depthStuds >= floor.mudDepthStuds then
		return "Mud"
	end
	if
		floor.screeDegFrom ~= nil
		and slopeDeg >= floor.screeDegFrom
		and slopeDeg <= need(floor.screeDegTo, "screeDegTo")
	then
		return "Rock"
	end
	return floor.default
end

-- ---------------------------------------------------------------- the tile plan

-- THE 128-STUD TILES THAT COVER A REGION, expanded OUTWARD to the tile lattice. Every tile stride is
-- a multiple of the voxel, so `Region3:ExpandToGrid(4)` has nothing left to do (design 5.1).
function Relief.tiles(footprint: Bounds, tileStuds: number): { { minX: number, minZ: number } }
	assert(tileStuds % Relief.VOXEL == 0, "Relief.tiles: the tile must be a whole number of voxels")
	local out: { { minX: number, minZ: number } } = {}
	local x0 = tileStuds * math.floor(footprint.minX / tileStuds)
	local z0 = tileStuds * math.floor(footprint.minZ / tileStuds)
	local z = z0
	while z < footprint.maxZ do
		local x = x0
		while x < footprint.maxX do
			table.insert(out, { minX = x, minZ = z })
			x += tileStuds
		end
		z += tileStuds
	end
	return out
end

-- ---------------------------------------------------------------- the epoch input

-- CANONICAL JSON: keys sorted, numbers `%.6g`, no whitespace. Canonical because the value makes two
-- trips through two encoders -- the reason the harness compares a Rojo JSON module's VALUE and not
-- its text. No service: this is the encoder, not `HttpService` (design 5.4).
local function canonical(value: any): string
	local t = type(value)
	if t == "number" then
		return string.format("%.6g", value)
	elseif t == "string" then
		return string.format("%q", value)
	elseif t == "boolean" then
		return tostring(value)
	elseif t ~= "table" then
		error("Relief.epochInput: cannot encode " .. t)
	end
	if #value > 0 then
		local parts: { string } = {}
		for _, item in value do
			table.insert(parts, canonical(item))
		end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	local keys: { string } = {}
	for key in value do
		table.insert(keys, tostring(key))
	end
	table.sort(keys)
	local parts: { string } = {}
	for _, key in keys do
		table.insert(parts, string.format("%q", key) .. ":" .. canonical((value :: any)[key]))
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

-- WHAT THE EPOCH HASHES: the landforms and TEN geometry fields of `Grid.CONFIG`, nothing else.
-- `config` is handed in, so this module still requires no `Grid` (design 5.4).
--
-- **THE THREE BEND ROWS ARE IN IT, AND THAT IS WHAT FORCES THE RE-BAKE** (defect F-2,
-- `grid-roads.md` 7.4): without them a bend added to `CONFIG` would leave `TerrainEpoch` unchanged,
-- `PlantEpoch` would still match and the census would certify a forest standing on moved ground.
-- `nil`-checked and not truthy-checked, because an amplitude of 0 is the shipped value.
function Relief.epochInput(forms: { [string]: Landform }, config: { [string]: any }): string
	-- `~= nil` FOR ALL TEN (task 328r, 328q note (k)): the seven geometry rows were truthy-checked
	-- and the three bend rows nil-checked, two rules for one question. `originX` and `originZ` are
	-- legitimate zeros and an amplitude of 0 is the born value, so "missing" can only ever mean nil.
	local geometry = {}
	for _, key in { "originX", "originZ", "cellWidthStuds", "cellDepthStuds", "roadClearStuds", "rows", "columns" } do
		local value = config[key]
		assert(value ~= nil, "Relief.epochInput: Grid.CONFIG is missing " .. key)
		geometry[key] = value
	end
	local bend = config.bend
	assert(bend ~= nil, "Relief.epochInput: Grid.CONFIG is missing bend")
	for _, pair in { { "ewStuds", "bendEwStuds" }, { "nsStuds", "bendNsStuds" }, { "harmonic", "bendHarmonic" } } do
		local value = bend[pair[1]]
		assert(value ~= nil, "Relief.epochInput: Grid.CONFIG.bend is missing " .. pair[1])
		geometry[pair[2]] = value
	end
	return canonical({ bakeVersion = Relief.BAKE_VERSION, config = geometry, landforms = forms })
end

-- ---------------------------------------------------------------- THE DATA: eight recipes

-- ONE ROW PER CELL, and they are SWARM_DESIGN section 2.2's recipes with the design's two
-- corrections: B2 keeps its 24-degree scarp and gets THREE ramps (design 15 item 4), and C1's two
-- saddles are negative knolls applied after the ridge (design 3.0, "a negative dome").
Relief.LANDFORMS = table.freeze({
	-- A1 THE LONG FACE: a gully down the west third, and a bench across the middle.
	A1 = table.freeze({
		baseKeep = 0.6,
		ops = table.freeze({
			table.freeze({
				kind = "trough",
				via = table.freeze({
					table.freeze({ u = 0.42, v = 0.12, dyStuds = -14 }),
					table.freeze({ u = 0.34, v = 0.50, dyStuds = -14 }),
					table.freeze({ u = 0.30, v = 1.00, dyStuds = -14 }),
				}),
				halfWidthStuds = 45,
			}),
			table.freeze({ kind = "bench", v0 = 0.55, v1 = 0.74, weight = 0.8, gradePercent = 2 }),
		}),
		-- SWARM 2.2: "leaf litter ... and Mud in the gully floor". The gully is 14 studs deep and the
		-- recipe names no depth; 10 is chosen, so Mud is its deepest 4 studs. The west side's needle
		-- floor is the ZONE's, not this function's (328f).
		floor = table.freeze({ default = "LeafyGrass", mudDepthStuds = 10 }),
	}),
	-- B1 HILLTOP CLEARING: a dome off centre, and dead ground at 88 m.
	B1 = table.freeze({
		baseKeep = 0.6,
		ops = table.freeze({
			table.freeze({ kind = "dome", u = 0.62, v = 0.73, rStuds = 280, dyStuds = 22 }),
			table.freeze({
				kind = "trough",
				via = table.freeze({
					table.freeze({ u = 0.00, v = 0.22, dyStuds = -8 }),
					table.freeze({ u = 1.00, v = 0.22, dyStuds = -8 }),
				}),
				halfWidthStuds = 50,
			}),
		}),
		-- SWARM 2.2: "birch floor. The clearing is meadow." No mud rule, so none here.
		floor = table.freeze({ default = "LeafyGrass" }),
	}),
	-- C1 THE RIDGE ACROSS THE DRIVE (the preview cell): animals crest at 120 m.
	C1 = table.freeze({
		baseKeep = 0.8,
		ops = table.freeze({
			table.freeze({
				kind = "ridge",
				via = table.freeze({
					table.freeze({ u = 0.00, v = 0.30, dyStuds = 24 }),
					table.freeze({ u = 1.00, v = 0.30, dyStuds = 24 }),
				}),
				halfWidthStuds = 150,
			}),
			table.freeze({ kind = "knoll", u = 0.28, v = 0.30, rStuds = 70, dyStuds = -12 }),
			table.freeze({ kind = "knoll", u = 0.72, v = 0.30, rStuds = 70, dyStuds = -12 }),
		}),
		-- LEAF LITTER, NOT BARE EARTH (task 328e). MEASURED in Karen's place after the 328d bake:
		-- the cell floor read `Ground` on 5504 of 5504 lattice samples -- bare brown from every one
		-- of the fifteen stands (`<runs-dir>/328e-ground-BEFORE.json`). `Ground` here was the
		-- PLACEHOLDER this function's header names, and `LeafyGrass` is the litter floor A1, B1 and
		-- B2 already carry. The per-ZONE floor (needles under the conifer, mud in a wet hollow) is
		-- `CELL_PLANS` v2's and task 328f's; this is the cell default only.
		floor = table.freeze({ default = "LeafyGrass" }),
	}),
	-- D1 FIELD IN A DISH: an elliptical 10-stud dish with a flat floor and NO RIM.
	D1 = table.freeze({
		baseKeep = 0.6,
		ops = table.freeze({
			table.freeze({
				kind = "bowl",
				u = 0.50,
				v = 0.30,
				rStuds = 260,
				rzStuds = 200,
				dyStuds = -10,
				flatFraction = 0.45,
			}),
		}),
		-- SWARM 2.2: "a Grass headland ... Mud only where the dish is at least 6 st deep."
		floor = table.freeze({ default = "Grass", mudDepthStuds = 6 }),
	}),
	-- A2 VALLEY AND GREEN RIDE: flat at the hunter line, 26 studs deep at the muster.
	A2 = table.freeze({
		baseKeep = 0.6,
		ops = table.freeze({
			table.freeze({
				kind = "trough",
				via = table.freeze({
					table.freeze({ u = 0.50, v = 0.20, dyStuds = 0 }),
					table.freeze({ u = 0.50, v = 1.00, dyStuds = -26 }),
				}),
				halfWidthStuds = 180,
			}),
		}),
		-- C1's FLOOR RULE, BORROWED WHOLE (task 328y): SWARM 2.2 states none for this cell, so the
		-- `Ground` was the header's placeholder -- MEASURED 1,537/1,645 `Ground` against C1's 1,533
		-- `LeafyGrass` (`<runs-dir>/328y-census-before.txt`). C1 has no mud or scree arm to differ.
		floor = table.freeze({ default = "LeafyGrass" }),
	}),
	-- B2 PLATEAU AND THE EDGE: a 2 % bench to the lip, a 24-degree scarp, and THREE ramps up it.
	-- SWARM section 2.2 gives B2's bench no weight; 0.9 is chosen so the plateau reads as a plateau.
	B2 = table.freeze({
		baseKeep = 0.6,
		ops = table.freeze({
			table.freeze({ kind = "bench", v0 = 0.00, v1 = 0.22, weight = 0.9, gradePercent = 2 }),
			table.freeze({ kind = "scarp", v = 0.24, dropStuds = 28, runStuds = 64 }),
			table.freeze({ kind = "ramp", u = 0.20, widthStuds = 60, gradePercent = 15 }),
			table.freeze({ kind = "ramp", u = 0.50, widthStuds = 60, gradePercent = 15 }),
			table.freeze({ kind = "ramp", u = 0.78, widthStuds = 60, gradePercent = 15 }),
		}),
		-- The scarp +- 8 studs carries no trunk (design 3.0): v 0.24 +- 40 studs of 1430.
		noTrees = table.freeze({ table.freeze({ v0 = 0.212, v1 = 0.268 }) }),
		-- SWARM 2.2: "leaf litter. Scree (Ground 70 / Rock 30) where the slope is 30-40 degrees."
		floor = table.freeze({ default = "LeafyGrass", screeDegFrom = 30, screeDegTo = 40 }),
	}),
	-- C2 SADDLE FUNNEL: two knolls with a light gap between two dark walls.
	C2 = table.freeze({
		baseKeep = 0.7,
		ops = table.freeze({
			table.freeze({ kind = "knoll", u = 0.18, v = 0.40, rStuds = 200, dyStuds = 26 }),
			table.freeze({ kind = "knoll", u = 0.82, v = 0.40, rStuds = 200, dyStuds = 26 }),
		}),
		-- C1's FLOOR RULE, BORROWED WHOLE (task 328y): SWARM 2.2 states none for this cell, so the
		-- `Ground` was the header's placeholder -- MEASURED 1,539/1,645 `Ground` against C1's 1,533
		-- `LeafyGrass` (`<runs-dir>/328y-census-before.txt`). C1 has no mud or scree arm to differ.
		floor = table.freeze({ default = "LeafyGrass" }),
	}),
	-- D2 BROKEN HILLSIDE: the hanging meadow on a 4 % bench, and the limiter does the rest.
	D2 = table.freeze({
		baseKeep = 0.5,
		ops = table.freeze({
			table.freeze({ kind = "bench", v0 = 0.50, v1 = 0.74, weight = 0.7, gradePercent = 4 }),
		}),
		-- C1's FLOOR RULE, BORROWED WHOLE (task 328y): SWARM 2.2 states none for this cell, so the
		-- `Ground` was the header's placeholder -- MEASURED 1,545/1,645 `Ground` against C1's 1,533
		-- `LeafyGrass` (`<runs-dir>/328y-census-before.txt`). C1 has no mud or scree arm to differ.
		-- D2 IS HELD: `shapeTile` repaints a held cell's material and leaves its heights (328x note n).
		floor = table.freeze({ default = "LeafyGrass" }),
	}),
})

return Relief
