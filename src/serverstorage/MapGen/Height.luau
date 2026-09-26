--!strict
-- MapGen.Height: THE SINGLE SOURCE OF GROUND HEIGHT, and PURE. `Height.at(x, z, seed, config)`.
-- No Terrain, no Instance, no service, no Random -- so `Ground`, `Props`, `Markers` and the digest
-- all ask the same function and cannot disagree about where the ground is. Two systems writing one
-- creature's position is the failure docs/PROJECT_CONTEXT.md names; two systems COMPUTING one
-- ground height is the same shape.
--
-- Pattern: domain-warped fractal value noise, the technique read out of RTerrainGenerator
-- (docs/design/map-generator.md section 11 source 5) and written from scratch on math.noise.
--   math.noise  https://create.roblox.com/docs/reference/engine/libraries/math#noise
--     Perlin-style, deterministic for the same arguments, and it takes NO SEED -- which is why the
--     seed arrives as a coordinate offset. The design's open question, "is it stable within a
--     session and across engine versions", is answered by `mapgen.py verify` and written down as
--     measurement (docs/design/map-generator.md section 6.4); if it ever is not, the fallback named
--     there is a small value-noise implementation in this file and nothing else changes.
--
-- Design: docs/design/map-generator.md (section 5.3)
local Height = {}

-- The seed as a coordinate offset, derived WITHOUT Random so this module stays pure: the same seed
-- always gives the same offset, and two different seeds give offsets far enough apart that the
-- noise fields do not overlap.
function Height.offset(seed: number): (number, number)
	local s = math.abs(seed % 1048576)
	return 1000 + (s * 137.077) % 9973, 5000 + (s * 311.531) % 9973
end

local function fbm(x: number, z: number, config): number
	local sum, amp, freq, norm = 0, 1, config.BASE_FREQUENCY, 0
	for _ = 1, config.OCTAVES do
		sum += amp * math.noise(x * freq, z * freq)
		norm += amp
		amp *= config.GAIN
		freq *= config.LACUNARITY
	end
	return sum / math.max(norm, 1e-6)
end

-- 1 outside the corridor, easing to CORRIDOR_RELIEF / RELIEF inside it. Smoothstep rather than a
-- step, because a cliff at the corridor edge is exactly the terrain a boar falls off.
function Height.corridorFalloff(x: number, z: number, config): number
	local c = config.WORLD.corridor
	local inside = config.CORRIDOR_RELIEF / config.RELIEF
	local blend = 90 -- studs of easing either side
	local dx = math.max(c.minX - x, x - c.maxX, 0)
	local dz = math.max(c.minZ - z, z - c.maxZ, 0)
	local d = math.max(dx, dz)
	if d >= blend then
		return 1
	end
	local t = d / blend
	local smooth = t * t * (3 - 2 * t)
	return inside + (1 - inside) * smooth
end

-- How far a point is from a bench, ALONG and ACROSS: (across, outside) in studs. `across` is the
-- distance from the centreline; `outside` is how far past the bench's end the point is, 0 inside it.
-- A bench is a strip, not a rectangle with corners, so the two are measured separately and the caller
-- decides how they combine (design section 6.3).
local function benchDistance(x: number, z: number, bench): (number, number)
	local along, across
	if bench.axis == "x" then
		along, across = x, math.abs(z - bench.at)
	else
		along, across = z, math.abs(x - bench.at)
	end
	local outside = math.max(bench.from - along, along - bench.to, 0)
	return across, outside
end

local function smoothstep(t: number): number
	local clamped = math.clamp(t, 0, 1)
	return clamped * clamped * (3 - 2 * clamped)
end

-- 1 far from every bench; BENCH_RELIEF/RELIEF on a bench centreline; smoothstepped between, over
-- BENCH_BAND studs. Its ONLY job is to keep the verge shallow (design section 6.2): 6 studs over the
-- 24-stud verge is atan(6/24) = 14.0 degrees, inside CORRIDOR_MAX_SLOPE_DEG = 15. Without it, the
-- corridor's +/-16 studs against a flat road gives 33.7 degrees.
function Height.benchBand(x: number, z: number, config): number
	local inside = config.BENCH_RELIEF / config.RELIEF
	local nearest = math.huge
	for _, bench in ipairs(config.WORLD.benches) do
		local across, outside = benchDistance(x, z, bench)
		-- Past the end of a bench the band fades out with the taper, so the road does not flatten a
		-- band of terrain beyond where the road actually is.
		nearest = math.min(nearest, math.max(across, outside * (config.BENCH_BAND / bench.taper)))
	end
	if nearest >= config.BENCH_BAND then
		return 1
	end
	return inside + (1 - inside) * smoothstep(nearest / config.BENCH_BAND)
end

-- The outer ring, as a FLOOR and never a sum: the maximum height stays EDGE_MAX_Y, inside the
-- measured voxel band, so the tile size measurement A proved does not change (design section 6.2).
-- Suppressed within BENCH_BAND of a bench, so the road runs off the map flat and the edge is hidden
-- by trees instead of by a ridge across the end of the ride.
function Height.edgeFloor(x: number, z: number, config): number
	local half = config.SIZE_STUDS / 2
	local toEdge = math.min(half - math.abs(x), half - math.abs(z))
	if toEdge >= config.EDGE_BAND then
		return -math.huge
	end
	local rise = config.GROUND_Y + config.EDGE_MAX_Y * (1 - smoothstep(toEdge / config.EDGE_BAND))
	-- The suppression, so the two features do not fight: 0 in a bench's LATERAL BAND, 1 a band away.
	--
	-- ACROSS ONLY, and not the distance past the bench's end (measurement N4, 2026-09-26). The road
	-- is painted from x = -900 to +900 while the map runs to +/-1024, so with the end distance in
	-- here the last 124 studs of the ride rose to 34.8 studs -- exactly the "ridge across the end of
	-- the ride" design section 6.2 says this suppression exists to avoid, and exactly what the
	-- `map-edge` shot asks about. The road's lateral band stays low all the way to the rim; the road
	-- surface stops where it stops, and trees hide the edge.
	local nearest = math.huge
	for _, bench in ipairs(config.WORLD.benches) do
		local across, _outside = benchDistance(x, z, bench)
		nearest = math.min(nearest, across)
	end
	local suppress = smoothstep(nearest / config.BENCH_BAND)
	return config.GROUND_Y + (rise - config.GROUND_Y) * suppress
end

-- GROUND_Y inside a bench, the eased value in its verge, and nil where no bench reaches. The caller
-- applies it AFTER the pads, so a bench WINS over a pad where they meet (design section 6.2).
function Height.benchHeight(x: number, z: number, config, h: number): number
	local best = nil
	for _, bench in ipairs(config.WORLD.benches) do
		local across, outside = benchDistance(x, z, bench)
		if outside <= bench.taper then
			-- The taper runs the bench out over its last 60 studs rather than ending it in a cliff.
			local endFade = smoothstep(1 - outside / bench.taper)
			local width = bench.halfWidth + bench.verge
			if across <= width then
				local t = if across <= bench.halfWidth then 0 else smoothstep((across - bench.halfWidth) / bench.verge)
				-- t = 0 on the gravel, 1 at the outer edge of the verge.
				local blended = config.GROUND_Y + (h - config.GROUND_Y) * t
				local value = h + (blended - h) * endFade
				if best == nil or math.abs(value - config.GROUND_Y) < math.abs(best - config.GROUND_Y) then
					best = value
				end
			end
		end
	end
	return best or h
end

-- How deep the bog dips at a point: 0 outside it, `depth` studs at its centre, eased. The SAME
-- easing the material uses, because `Ground` asks `Layout.bogDepth` for both -- a dip in one place and
-- mud in another would be two systems disagreeing about one feature.
local function bogDip(x: number, z: number, config, bogDepth: ((number, number, any) -> number)?): number
	if bogDepth == nil then
		return 0
	end
	return bogDepth(x, z, config) * config.WORLD.bog.depth
end

-- The ground, in studs, at one point. Deterministic in (x, z, seed).
--
-- `bogDepth` is passed in rather than required, so this module keeps no dependency at all: `Ground`
-- and the specs hand it `Layout.bogDepth`, and a caller that omits it gets the terrain without the
-- bog, which is exactly what the corridor and slope checks want to measure.
function Height.at(x: number, z: number, seed: number, config, bogDepth: ((number, number, any) -> number)?): number
	local ox, oz = Height.offset(seed)
	local wf = config.WARP_FREQUENCY
	local wx = config.WARP * math.noise((x + ox) * wf, (z + oz) * wf)
	local wz = config.WARP * math.noise((x + ox + 313.7) * wf, (z + oz + 71.3) * wf)
	local h = fbm(x + wx + ox, z + wz + oz, config) * config.RELIEF
	-- THE MASKS, IN ORDER (design section 6.2). corridorFalloff calms the drive; benchBand calms the
	-- verge so the road does not meet a 33-degree wall; edgeFloor is a MAX, not an addition, so the
	-- voxel band is unchanged. The bench itself is applied later, by atFlattened, because a bench
	-- must win over a pad and pads are that function's business.
	local shaped = config.GROUND_Y
		+ h * Height.corridorFalloff(x, z, config) * Height.benchBand(x, z, config)
		- bogDip(x, z, config, bogDepth)
	return math.max(shaped, Height.edgeFloor(x, z, config))
end

-- The ground with the flat pads applied: a disc of `radius` at exactly GROUND_Y, easing back to the
-- terrain over `blend`. Markers and spawns stand on these, which is what stops a boar being released
-- inside a hill (design section 7.3).
--
-- FLAT AT GROUND_Y, not at the pad's own noise height, for a reason worth stating: the contract spec
-- asserts every DrivenHunt.BoarSpawn sits within Map.SPAWN_PAD.tolerance (0.75 studs) of
-- Map.FIELD.groundY (design section 13.1 check 4). Flattening to the noise would put a spawn up to
-- CORRIDOR_RELIEF studs off that, so the map would fail its own contract at the M2.5 switch. It also
-- means Boar's field.groundY needs no change when the map becomes the world.
function Height.atFlattened(
	x: number,
	z: number,
	seed: number,
	config,
	pads: { { x: number, z: number } },
	bogDepth: ((number, number, any) -> number)?
): number
	local h = Height.at(x, z, seed, config, bogDepth)
	local pad = config.SPAWN_PAD
	-- PADS FIRST, THEN BENCHES, so a bench wins where the two meet: the road is what a player walks
	-- and a shooter stands on, and a pad that overrode it would put a hump in the gravel.
	local function withBench(value: number): number
		return Height.benchHeight(x, z, config, value)
	end
	-- The NEAREST pad wins, not the first in the list: with two pads overlapping, "first" would make
	-- the ground depend on the order Layout happens to emit them in.
	local nearest, distance = nil, math.huge
	for _, p in ipairs(pads) do
		local d = math.sqrt((x - p.x) ^ 2 + (z - p.z) ^ 2)
		if d < distance then
			nearest, distance = p, d
		end
	end
	if nearest == nil or distance > pad.radius + pad.blend then
		return withBench(h)
	end
	if distance <= pad.radius then
		return withBench(config.GROUND_Y)
	end
	local t = (distance - pad.radius) / pad.blend
	local smooth = t * t * (3 - 2 * t)
	return withBench(config.GROUND_Y + (h - config.GROUND_Y) * smooth)
end

return Height
