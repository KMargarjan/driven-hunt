--!strict
-- Weapon.SafetyArc: is this shot pointing into the drive line? Pure, and it is given the direction
-- the PELLETS take (the muzzle-to-aim-point vector), never the client's camera direction -- defect
-- (e) of the Task 23 review, so a published violation matches where the shot actually went.
--
-- The forbidden region is a cone of SAFETY_ARC_HALF_DEG about the line's normal, which points
-- toward the drivers. A HALF angle, and its field name says so (design section 4).
-- v1 has no drive line provider, so this never fires in this task: the safety rule is ROADMAP 1.7.
--
-- Design: docs/design/shotgun.md (sections 5.3, 5.5)
local SafetyArc = {}

function SafetyArc.isForbidden(direction: Vector3, line: any, halfAngleDeg: number): boolean
	assert(line ~= nil, "SafetyArc.isForbidden: the owner checks for a line before calling")
	if direction.Magnitude < 1e-6 or line.normal.Magnitude < 1e-6 then
		return false
	end
	local cosine = direction.Unit:Dot(line.normal.Unit)
	return cosine >= math.cos(math.rad(halfAngleDeg))
end

return SafetyArc
