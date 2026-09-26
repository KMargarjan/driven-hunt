--!strict
-- Match.Penalty: did that shot endanger a driver? PURE -- no service, no Instance, no clock, no
-- Player, no Random; `config` is a parameter, not a lookup. It answers exactly ONE question and the
-- owner answers the other three (is the phase Running, is this shooter already tied, is the drive
-- past SAFETY_GRACE_SECONDS), because four questions in one predicate is how "one predicate answered
-- two unrelated questions" happened in the previous project (docs/PROJECT_CONTEXT.md).
--
-- THE RULE IS "YOU FIRED AT A DRIVER", not "you fired within 45 degrees of the drive". The 45-degree
-- cone is the weapon's FILTER (Weapon.SafetyArc.isForbidden, which is what publishes the shot at
-- all); taken as the verdict it would tie everybody in the first minute, because a shooter on a post
-- faces the drive and every legitimate shot is inside that cone (design section 8.1).
--
-- Pattern: point-to-ray distance with the ray TRUNCATED at where the shot stopped -- the standard
-- closest-point-on-a-line formula, kept in one place so the game has one definition of "the shot
-- passed close to him".
--   Vector3:Dot  https://create.roblox.com/docs/reference/engine/datatypes/Vector3#Dot
--
-- Design: docs/design/drive.md (sections 8.1, 8.2, 8.3)
-- Note:   docs/research/2026-09-25-drive.md (section 1.7b)
local Penalty = {}

export type Shot = {
	userId: number,
	muzzle: Vector3,
	aim: Vector3, -- unit, muzzle -> aim point: where the PELLETS went, never the camera direction
	stopAt: number, -- studs from the muzzle to where the shot stopped, or the ammo's range
	at: number,
}

export type DriverPos = { userId: number, position: Vector3 }

Penalty.REASON = "driver-in-line"

-- true when SOME driver was close enough to the shot's own path to have been shot at. The four
-- conditions, in the design's words: in front of the muzzle, not past where the shot stopped, not
-- past the ammo's range, and within SAFETY_MISS_STUDS of the line the pellets flew along.
--
-- SAFETY_BODY_STUDS IS A DEVIATION FROM THE DESIGN AND IT IS THE DIFFERENCE BETWEEN THIS RULE
-- WORKING AND THIS RULE NEVER FIRING (reviews/task-35/DESIGN_DELTA.md). The design's condition is
-- `t <= stopAt`, where t is the distance to the driver's ROOT and stopAt is where the pellets hit.
-- When the shot hits the driver, the pellets stop on his SURFACE -- about a stud in front of the
-- root -- so t > stopAt and a point-blank shot at a driver would be judged harmless. The allowance
-- is the depth of a person; everything the design's own cases require still holds, because the case
-- it exists to reject (a boar killed at 30 studs with a driver 80 studs behind it, in line) is
-- rejected by 50 studs and not by one.
function Penalty.judge(shot: Shot, drivers: { DriverPos }, config): (boolean, string?)
	local aim = shot.aim
	if aim == nil or aim.Magnitude < 1e-6 then
		return false, nil -- a degenerate shot endangers nobody, and must not error
	end
	local unit = aim.Unit
	local reach = math.min(shot.stopAt + config.SAFETY_BODY_STUDS, config.SAFETY_RANGE_STUDS)

	for _, driver in ipairs(drivers) do
		-- Never yourself. It cannot happen in v1 (a driver carries no gun) but it can the day
		-- DRIVERS_MAY_SHOOT is true, and the design says there is no exception to write then.
		if driver.userId ~= shot.userId then
			local toDriver = driver.position - shot.muzzle
			local along = toDriver:Dot(unit)
			if along > 0 and along <= reach then
				local miss = (toDriver - unit * along).Magnitude
				if miss <= config.SAFETY_MISS_STUDS then
					return true, Penalty.REASON
				end
			end
		end
	end
	return false, nil
end

-- Whether a tie that began at `tiedAt` is over. With TIE_UNTIL_DRIVE_END (Karen's rule as written)
-- it never is, and the drive's own `release` effect is what frees everybody. TIE_SECONDS exists for
-- the day she wants the shorter joke, and this is the one place it means anything -- a config number
-- that nothing reads is a lie in a table.
function Penalty.expired(tiedAt: number, now: number, config): boolean
	if config.TIE_UNTIL_DRIVE_END then
		return false
	end
	return now - tiedAt >= config.TIE_SECONDS
end

return Penalty
