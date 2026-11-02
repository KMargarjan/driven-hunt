--!nocheck
-- THE BAKE'S EPOCH GOLDEN (design docs/design/grid-terrain.md section 5.4). Not a spec: a committed
-- fixture `tests/server/grid_relief.spec.luau` reads. If `Relief`'s ARITHMETIC moves, these samples
-- stop matching, and the fix is to re-measure them AND bump `Relief.BAKE_VERSION` in the same commit.
--
-- MEASURED 2026-11-02 by `tests/server/zz_relief_probe.spec.luau` (task 328c), driving the real
-- `ReplicatedStorage.Grid.Relief` inside a harness Play run -- the MCP thread may not `require`, so a
-- spec is the only instrument that can read this module's own numbers.
local Golden = {}

-- Must equal `Relief.BAKE_VERSION`, so the samples cannot be refreshed without touching the version.
Golden.bakeVersion = 1

-- THE SYNTHETIC BASE these were measured over: a tilted plane plus a 40-stud wave, so the Gaussian
-- blur actually bites (a plane alone blurs to itself and would not exercise `baseKeep`). `xx`/`zz` are
-- measured from each cell's own `Grid.boundsOf` corner.
--   base(x, z) = y0 + perX * xx + perZ * zz + waveAmp * sin(xx / wavePeriod)
Golden.base = { y0 = 100, perX = 0.03, perZ = -0.02, waveAmp = 6, wavePeriod = 40 }

-- THE SIX NAMED POINTS, the same (u, v) in every cell.
Golden.samples = {
	{ u = 0.20, v = 0.10 },
	{ u = 0.50, v = 0.30 },
	{ u = 0.62, v = 0.73 },
	{ u = 0.30, v = 0.50 },
	{ u = 0.50, v = 0.90 },
	{ u = 0.80, v = 0.24 },
}

-- `Relief.heightAt(LANDFORMS[id], Grid.boundsOf(id), Grid.roads(), base, x, z)` at those six points.
Golden.heights = {
	A1 = { 99.051611381, 111.528522208, 97.068879624, 100.770729221, 94.368522208, 121.942981727 },
	B1 = { 99.051611381, 111.528522208, 116.710152911, 100.858946676, 94.389935925, 118.840064771 },
	C1 = { 98.895245223, 135.669285477, 94.560534111, 101.050709237, 94.509285477, 131.360186893 },
	D1 = { 99.051611381, 101.528522208, 94.710152911, 100.858946676, 94.368522208, 121.942981727 },
	A2 = { 99.051611381, 108.278522208, 91.447288168, 100.858946676, 71.618522208, 121.942981727 },
	B2 = { 104.019611381, 84.658522208, 66.710152911, 72.858946676, 66.368522208, 107.942981727 },
	C2 = { 98.973428302, 111.598903843, 94.635343511, 101.070783266, 94.438903843, 121.997208876 },
	D2 = { 99.129794459, 111.458140573, 98.778221687, 100.763065395, 94.298140573, 121.888754579 },
}

-- The reader the spec builds from `Golden.base`, kept here so the fixture owns its own base.
function Golden.readerFor(bounds)
	local b = Golden.base
	return function(x: number, z: number): number
		local xx, zz = x - bounds.minX, z - bounds.minZ
		return b.y0 + b.perX * xx + b.perZ * zz + b.waveAmp * math.sin(xx / b.wavePeriod)
	end
end

return Golden
