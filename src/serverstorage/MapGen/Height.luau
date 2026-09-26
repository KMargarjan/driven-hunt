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
	local c = config.SLICE.corridor
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

-- The ground, in studs, at one point. Deterministic in (x, z, seed).
function Height.at(x: number, z: number, seed: number, config): number
	local ox, oz = Height.offset(seed)
	local wf = config.WARP_FREQUENCY
	local wx = config.WARP * math.noise((x + ox) * wf, (z + oz) * wf)
	local wz = config.WARP * math.noise((x + ox + 313.7) * wf, (z + oz + 71.3) * wf)
	local h = fbm(x + wx + ox, z + wz + oz, config) * config.RELIEF
	return config.GROUND_Y + h * Height.corridorFalloff(x, z, config)
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
function Height.atFlattened(x: number, z: number, seed: number, config, pads: { { x: number, z: number } }): number
	local h = Height.at(x, z, seed, config)
	local pad = config.SPAWN_PAD
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
		return h
	end
	if distance <= pad.radius then
		return config.GROUND_Y
	end
	local t = (distance - pad.radius) / pad.blend
	local smooth = t * t * (3 - 2 * t)
	return config.GROUND_Y + (h - config.GROUND_Y) * smooth
end

return Height
