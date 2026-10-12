--!strict
-- Bots.Lane: WHERE A BOT WALKS. PURE -- no services, no Instances, no clock, no Random. Every
-- function takes CFrames and Vector3s and returns CFrames and Vector3s, which is what lets
-- tests/server/bots_lane.spec.luau drive the whole beater line with hand-written numbers and no
-- world, no terrain and no rig.
--
-- A LANE IS THE FEATURE. Karen, 2026-10-11: *"beater are behind animals and moving towards hunter
-- line (road) like in real life"*. A beater line walks ABREAST, and a shortest path is per agent --
-- so eight shortest paths are eight different detours and the line is gone. That is the whole reason
-- `PathfindingService` is rejected for this (docs/research/2026-10-12-bots.md section 3): a lane
-- per bot, from its own point on the start line to its own point on the road, IS the line.
--
-- THREE PROPERTIES, and they are why it is written this way rather than as "spread them out":
--   * LANE 0 IS NEVER ISSUED, so the middle stays the PEOPLE's. The forest puts every real beater on
--     one measured point (`ForestTest.beaterStartPosition` ignores its index) and that point is on
--     the push line through the stand the drive aims at; the arena spreads real drivers about the
--     pad centre. Bots start at +-LANE_SPACING_STUDS and outward, so they flank.
--   * THE SPREAD IS ALONG THE BASE'S OWN RightVector, not along world X. The forest's road is a sine
--     whose tangent swings +-23 degrees (`docs/design/forest-drive.md`), so a line laid out on world
--     X would not be square to the push it is walking down.
--   * THE GOAL IS OFFSET BY THE SAME AMOUNT as the start, so a line that sets off abreast ARRIVES
--     abreast instead of converging on one point in front of one stand.
--
-- Pattern: the per-waypoint `Humanoid:MoveTo` loop of Roblox's own character-pathfinding guide, with
-- the pathfinder taken out and a lane put in -- and the re-issue interval set by the engine's
-- documented 8-second `MoveTo` timeout (the owner holds the clock; this module holds the geometry).
--   https://create.roblox.com/docs/characters/pathfinding
--   https://create.roblox.com/docs/reference/engine/classes/Humanoid#MoveTo
-- The side-step is `ForestTest.beaterStartPosition`'s own alternating search (rule 2: borrowed from
-- inside this repo), re-pointed at a lane point instead of at a spawn point.
--
-- Design: docs/design/bots.md (section 9.1)
-- Note:   docs/research/2026-10-12-bots.md (sections 2.3, 2.4, 2.5, 3)
local Lane = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- LANE 1 IS +spacing, LANE 2 IS -spacing, LANE 3 IS +2x, LANE 4 IS -2x. The same alternating
-- nearest-first shape `ForestTest.beaterStartPosition` uses for its side tries, so four bots span
-- 4 * LANE_SPACING_STUDS with nobody in the middle.
--
-- LANE 0 RETURNS 0, and that is not a lane: a stander carries `lane = 0` and never asks this. It
-- answers rather than erroring because a nil here would be a crash in the one place a spec cannot
-- see, and `bots_lane.spec` asserts the owner never issues it.
function Lane.offsetFor(lane: number, config): number
	if lane <= 0 then
		return 0
	end
	local step = math.ceil(lane / 2) * config.LANE_SPACING_STUDS
	return if lane % 2 == 1 then step else -step
end

-- WHERE THIS LANE STARTS: the base the drive chose, moved sideways along the base's own right.
-- The facing is the base's, unchanged -- every bot of a line looks the same way, down the push.
function Lane.startFor(base: CFrame, lane: number, config): CFrame
	local offset = Lane.offsetFor(lane, config)
	if offset == 0 then
		return base
	end
	return base + base.RightVector * offset
end

-- WHERE THIS LANE ENDS: the base's goal, moved sideways by the SAME offset and along the SAME axis.
-- Flat: the Y is the goal's, because the ground under the goal is the drive's measurement and not
-- this module's.
function Lane.goalFor(baseGoal: Vector3, base: CFrame, lane: number, config): Vector3
	local offset = Lane.offsetFor(lane, config)
	if offset == 0 then
		return baseGoal
	end
	local side = flat(base.RightVector)
	if side.Magnitude < 1e-4 then
		return baseGoal
	end
	return baseGoal + side.Unit * offset
end

-- IS IT THERE? Flat, because a bot standing 3 studs below its goal on a hill has arrived.
function Lane.arrived(at: Vector3, goal: Vector3, arriveStuds: number): boolean
	return flat(goal - at).Magnitude <= arriveStuds
end

-- THE NEXT POINT DOWN THE LANE, `aheadStuds` on from where the bot is -- and NEVER PAST THE GOAL,
-- which is the one thing a "walk a bit further" aim point must not do: a `MoveTo` beyond the line
-- would walk a beater through the hunters and out the other side.
--
-- Flat in XZ: the Y is whatever the bot is standing on. `Humanoid:MoveTo` takes a point and the
-- humanoid's own physics finds the ground, so a Y guessed here would be a second answer to "where is
-- the ground" (the world's `groundAt` is the first, and the owner uses it only when it PLACES).
function Lane.aimFor(at: Vector3, goal: Vector3, aheadStuds: number): Vector3
	local away = flat(goal - at)
	local gap = away.Magnitude
	if gap <= aheadStuds or gap < 1e-4 then
		return Vector3.new(goal.X, at.Y, goal.Z)
	end
	local step = away.Unit * aheadStuds
	return Vector3.new(at.X + step.X, at.Y, at.Z + step.Z)
end

-- THE SIDE-STEP, when the lane's next point is inside something. `try` is 1-based and alternates
-- nearest-first -- +step, -step, +2step, -2step -- exactly as `ForestTest.beaterStartPosition`
-- searches for a clear spawn, so there is one shape of answer to "that point is blocked, where
-- instead" in this repo rather than two.
--
-- PERPENDICULAR TO THE LANE, not to the world: the nudge has to be across the direction of travel,
-- or a bot walking south would be nudged along the line it is already walking.
function Lane.sideStep(aim: Vector3, at: Vector3, goal: Vector3, try: number, config): Vector3
	local along = flat(goal - at)
	if along.Magnitude < 1e-4 then
		return aim
	end
	local side = Vector3.new(-along.Unit.Z, 0, along.Unit.X)
	local step = math.ceil(try / 2) * config.SIDE_STEP_STUDS * (if try % 2 == 1 then 1 else -1)
	return aim + side * step
end

return Lane
