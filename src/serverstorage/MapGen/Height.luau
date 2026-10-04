--!strict
-- MapGen.Height: THE SINGLE SOURCE OF GROUND HEIGHT, and PURE. `Height.at(x, z, seed, config)`.
-- No Terrain, no Instance, no service, no Random -- so `Ground`, `Props`, `Markers` and the digest
-- all ask the same function and cannot disagree about where the ground is. Two systems writing one
-- creature's position is the failure docs/PROJECT_CONTEXT.md names; two systems COMPUTING one
-- ground height is the same shape.
--
-- Pattern: domain-warped fractal value noise, the technique read out of RTerrainGenerator
-- (the design's external sources, "Red Blob Games" and "RTerrainGenerator") and written from
-- scratch on math.noise.
--   math.noise  https://create.roblox.com/docs/reference/engine/libraries/math#noise
--     Perlin-style, deterministic for the same arguments, and it takes NO SEED -- which is why the
--     seed arrives as a coordinate offset. Whether it is stable across engine versions is answered
--     by `mapgen.py verify`; if it ever is not, the fallback is a small value-noise implementation
--     in this file and nothing else changes.
--
-- WET GROUND LIVES HERE, NOT IN `Layout`, AND THAT IS A DEVIATION FROM THE DESIGN'S MODULE TABLE
-- WITH A REASON. The design listed `Layout.wetAt`. Wetness is DERIVED FROM THE HEIGHTFIELD ALONE --
-- a hollow is wet because it is low -- so computing it in `Layout` would mean `Layout` requiring
-- `Height`, which is a dependency edge added to carry a number this module already has. It is one
-- implementation either way, which is the property the design's "Wet ground, derived" actually
-- asks for: the dip, the Mud, the forced alder and the doubled ferns all read this one function and
-- so cannot end up in different places.
--
-- Design: docs/design/map-generator.md, "The heightfield: hills, and a band written in two measured
-- passes" and "Wet ground, derived"
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

local function smoothstep(t: number): number
	local clamped = math.clamp(t, 0, 1)
	return clamped * clamped * (3 - 2 * clamped)
end

-- 1 outside every block, easing to BLOCK_RELIEF / RELIEF inside ONE. Smoothstep rather than a step,
-- because a cliff at a block's edge is exactly the terrain a boar falls off.
--
-- ANY BLOCK, NOT ONE CORRIDOR (v3's `corridorFalloff`): blocks 2-4 are playable the day their
-- content lands, and the slope spec can assert all four of them now.
function Height.blockFalloff(x: number, z: number, config): number
	local inside = config.BLOCK_RELIEF / config.RELIEF
	local blend = 90 -- studs of easing outside each block's edge
	local nearest = math.huge
	for _, name in ipairs(config.BLOCK_ORDER) do
		local b = config.BLOCKS[name].bounds
		local dx = math.max(b.minX - x, x - b.maxX, 0)
		local dz = math.max(b.minZ - z, z - b.maxZ, 0)
		nearest = math.min(nearest, math.max(dx, dz))
	end
	if nearest >= blend then
		return 1
	end
	return inside + (1 - inside) * smoothstep(nearest / blend)
end

-- How far a point is from a bench, ALONG and ACROSS: (across, outside) in studs. `across` is the
-- distance from the centreline; `outside` is how far past the bench's end the point is, 0 inside it.
-- A bench is a strip, not a rectangle with corners, so the two are measured separately and the caller
-- decides how they combine.
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

-- 1 far from every bench; BENCH_RELIEF/RELIEF on a bench centreline; smoothstepped between, over
-- BENCH_BAND studs. Its ONLY job is to keep the verge shallow: 6 studs over the main road's 26-stud
-- verge is atan(6/26) = 13.0 degrees, inside CORRIDOR_MAX_SLOPE_DEG = 15. Without it, a block's
-- relief against a flat road would meet it at a wall.
function Height.benchBand(x: number, z: number, config): number
	local inside = config.BENCH_RELIEF / config.RELIEF
	local nearest = math.huge
	for _, bench in ipairs(config.BENCHES) do
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

-- THE RIM'S CEILING AT A GIVEN DISTANCE FROM THE MAP'S EDGE, as a pure function of that distance
-- alone. It is the UPPER BOUND of `edgeFloor` there -- BOTH suppressions, the road's lateral band and
-- the block's, can only LOWER it -- and it is what lets `Layout.tiles` prove a tile needs no upper
-- band pass instead of sampling for it.
function Height.edgeCeiling(toEdge: number, config): number
	if toEdge >= config.EDGE_BAND then
		return -math.huge
	end
	return config.GROUND_Y + config.EDGE_MAX_Y * (1 - smoothstep(toEdge / config.EDGE_BAND))
end

-- HOW MUCH OF THE RIM SURVIVES HERE: 0 inside any block, 1 `EDGE_BLOCK_BLEND` studs outside one.
--
-- MEASURED 2026-10-04: without this the rim rose 102 studs inside block 1's north-west corner and the
-- slope spec read 47.30 degrees against a ceiling of 15. The rim is scenery and a block is where the
-- game is played, so the rim keeps out of a block -- the same answer, and the same smoothstep, that
-- a road's lateral band already got.
function Height.blockRimSuppression(x: number, z: number, config): number
	local nearest = math.huge
	for _, name in ipairs(config.BLOCK_ORDER) do
		local b = config.BLOCKS[name].bounds
		local dx = math.max(b.minX - x, x - b.maxX, 0)
		local dz = math.max(b.minZ - z, z - b.maxZ, 0)
		nearest = math.min(nearest, math.max(dx, dz))
	end
	if nearest <= 0 then
		return 0
	end
	return smoothstep(nearest / config.EDGE_BLOCK_BLEND)
end

-- The outer ring, as a FLOOR and never a sum: the maximum height stays EDGE_MAX_Y, inside the voxel
-- band, so the measured tile size does not change. Suppressed within BENCH_BAND of a road, so a road
-- runs off the map flat and the edge is hidden by trees instead of by a ridge across the end of the
-- ride -- and suppressed inside a block, so the backdrop never becomes the drive's floor.
function Height.edgeFloor(x: number, z: number, config): number
	local half = config.SIZE_STUDS / 2
	local toEdge = math.min(half - math.abs(x), half - math.abs(z))
	local rise = Height.edgeCeiling(toEdge, config)
	if rise == -math.huge then
		return -math.huge
	end
	-- The suppression, so the two features do not fight: 0 in a bench's LATERAL BAND, 1 a band away.
	--
	-- ACROSS ONLY, and not the distance past the bench's end (measurement N4, 2026-09-26). The main
	-- road is painted from x = -1,440 to +1,440 while the map runs to +/-1,536, so with the end
	-- distance in here the last 96 studs of the ride would rise -- exactly the "ridge across the end
	-- of the ride" this suppression exists to avoid, and exactly what `forest-edge` asks about.
	local nearest = math.huge
	for _, bench in ipairs(config.BENCHES) do
		local across, _outside = benchDistance(x, z, bench)
		nearest = math.min(nearest, across)
	end
	local suppress = smoothstep(nearest / config.BENCH_BAND) * Height.blockRimSuppression(x, z, config)
	return config.GROUND_Y + (rise - config.GROUND_Y) * suppress
end

-- GROUND_Y inside a bench, the eased value in its verge, and the value unchanged where no bench
-- reaches. The caller applies it AFTER the pads, so a bench WINS over a pad where they meet.
function Height.benchHeight(x: number, z: number, config, h: number): number
	local best = nil
	for _, bench in ipairs(config.BENCHES) do
		local across, outside = benchDistance(x, z, bench)
		if outside <= bench.taper then
			-- The taper runs the bench out over its last studs rather than ending it in a cliff.
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

-- THE BASE GROUND: the warped fbm with the block and bench masks on it, and NOTHING ELSE -- no wet
-- dip, no rim, no bench surface, no pad. It exists as its own function because wetness is derived
-- from it, and deriving wetness from a height that already had the wet dip subtracted would be a
-- feedback loop: a hollow would deepen itself every time anything asked.
function Height.base(x: number, z: number, seed: number, config): number
	local ox, oz = Height.offset(seed)
	local wf = config.WARP_FREQUENCY
	local wx = config.WARP * math.noise((x + ox) * wf, (z + oz) * wf)
	local wz = config.WARP * math.noise((x + ox + 313.7) * wf, (z + oz + 71.3) * wf)
	local h = fbm(x + wx + ox, z + wz + oz, config) * config.RELIEF
	return config.GROUND_Y + h * Height.blockFalloff(x, z, config) * Height.benchBand(x, z, config)
end

-- HOW WET A GIVEN BASE HEIGHT IS, 0..1: 0 above WET_DEPTH, 1 a WET_BLEND below it, smoothstepped
-- between. Taking the height as an ARGUMENT is what lets `Height.at` derive the wetness from the
-- base it has already computed instead of computing the noise field a second time.
function Height.wetFor(base: number, config): number
	return smoothstep((config.WET_DEPTH - base) / config.WET_BLEND)
end

-- HOW WET THE GROUND IS HERE, 0..1, FROM THE HEIGHTFIELD ALONE (design, "Wet ground, derived").
-- One function drives four things -- the extra dip, the `wet` material, alder whatever the clump
-- says, and double ferns -- so the mud, the dip, the trees and the undergrowth cannot end up in
-- different places.
--
-- It reads `Height.base`, never `Height.at`: see the note on `base`.
function Height.wetAt(x: number, z: number, seed: number, config): number
	if not config.INCLUDE.relief then
		-- Flat ground is never below WET_DEPTH, so there is nothing wet to find. An early return
		-- rather than arithmetic, for the reason `at` has one: `base` is not meaningful here.
		return 0
	end
	return Height.wetFor(Height.base(x, z, seed, config), config)
end

-- The ground, in studs, at one point. Deterministic in (x, z, seed).
--
--   base          the warped fbm, calmed inside a block and along every verge
--   - wet dip     a hollow that is wet sits a little deeper still
--   max edgeFloor the rim, as a FLOOR and never a sum, so the band's top is unchanged
--
-- The benches and the pads are applied later, by `atFlattened`, because a bench must win over a pad
-- and pads are that function's business.
function Height.at(x: number, z: number, seed: number, config): number
	-- THE BARE WORLD (task 85): one plane at GROUND_Y, and it is an early return rather than
	-- `RELIEF = 0` because `blockFalloff` and `benchBand` DIVIDE by RELIEF. Everything below is
	-- untouched and comes back with `Config.INCLUDE.relief = true`, which is where v4 leaves it.
	if not config.INCLUDE.relief then
		return config.GROUND_Y
	end
	-- THE BASE IS COMPUTED ONCE AND THE WETNESS IS DERIVED FROM IT. Calling `Height.wetAt` here
	-- would evaluate the whole warped fbm a SECOND time for every column of every tile -- 12 noise
	-- calls instead of 6 -- which over 752 tiles is tens of minutes of build. Same answer, half the
	-- arithmetic, and `wetFor` is the shared expression so the two cannot drift apart.
	local base = Height.base(x, z, seed, config)
	local shaped = base - Height.wetFor(base, config) * config.WET_DIP_STUDS
	return math.max(shaped, Height.edgeFloor(x, z, config))
end

-- The ground with the flat pads applied: a disc of `radius` at exactly GROUND_Y, easing back to the
-- terrain over `blend`. Markers and spawns stand on these, which is what stops a boar being released
-- inside a hill.
--
-- FLAT AT GROUND_Y, not at the pad's own noise height, for a reason worth stating: the contract spec
-- asserts every DrivenHunt.BoarSpawn sits within Map.SPAWN_PAD.tolerance (0.75 studs) of
-- Map.FIELD.groundY. Flattening to the noise would put a spawn up to BLOCK_RELIEF studs off that, so
-- the map would fail its own contract. It also means Boar's field.groundY needs no change.
function Height.atFlattened(x: number, z: number, seed: number, config, pads: { { x: number, z: number } }): number
	local h = Height.at(x, z, seed, config)
	local pad = config.SPAWN_PAD
	-- PADS FIRST, THEN BENCHES, so a bench wins where the two meet: a road is what a player walks
	-- and a boar crosses, and a pad that overrode it would put a hump in the gravel.
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
