--!strict
-- Weapon.Pattern: aim direction + seeded rng -> one unit direction per pellet, inside the ammo's
-- cone. Pure: the rng is a parameter, so a spec gets the same pattern every run.
--
-- THE ONE CONVERSION FROM DEGREES TO RADIANS IN THIS SYSTEM (design section 4). CONFIG stores a
-- FULL cone angle in degrees; the half-angle used by the maths is derived here and nowhere else,
-- which is what makes the Task 19 2x defect unrepeatable. Slug and Buck take the same code path:
-- a 0.16-degree cone is simply a very tight one.
--
-- Pattern: uniform sampling of a spherical cap, the standard method --
--   https://en.wikipedia.org/wiki/Spherical_cap  (area-uniform: cos(theta) uniform in [cos(max),1])
--   Roblox Random     https://create.roblox.com/docs/reference/engine/classes/Random
-- A naive "random X and Y jitter" clusters pellets at the cone's centre; this does not.
--
-- Design: docs/design/shotgun.md (sections 4, 5.3)
-- Note:   docs/research/2026-09-24-shotgun.md
local Pattern = {}

-- Any unit vector perpendicular to `v`. Picking the axis `v` is least aligned with keeps the cross
-- product well away from zero.
local function perpendicular(v: Vector3): Vector3
	local axis = if math.abs(v.X) < 0.9 then Vector3.xAxis else Vector3.yAxis
	return v:Cross(axis).Unit
end

function Pattern.directions(ammo: string, aim: Vector3, rng: Random, config): { Vector3 }
	assert(aim.Magnitude > 1e-6, "Pattern.directions: aim must be a non-zero vector")
	local count = config.PELLETS[ammo]
	local fullDeg = config.SPREAD_FULL_DEG[ammo]
	assert(count and fullDeg, "Pattern.directions: unknown ammo " .. tostring(ammo))

	local forward = aim.Unit
	local halfRad = math.rad(fullDeg) * 0.5 -- the one halving, in one place
	local right = perpendicular(forward)
	local up = forward:Cross(right)

	local out = {}
	for _ = 1, count do
		local cosTheta = 1 - rng:NextNumber() * (1 - math.cos(halfRad))
		local sinTheta = math.sqrt(math.max(0, 1 - cosTheta * cosTheta))
		local phi = rng:NextNumber() * 2 * math.pi
		out[#out + 1] = (forward * cosTheta + right * (sinTheta * math.cos(phi)) + up * (sinTheta * math.sin(phi))).Unit
	end
	return out
end

return Pattern
