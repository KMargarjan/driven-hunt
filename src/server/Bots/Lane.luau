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
-- WHERE THE LANE IS IS NOT THIS MODULE'S ANSWER ANY MORE (task 167), AND THAT IS THE FIX FOR KAREN'S
-- *"and seem like all bots came to me"* (2026-10-12 ~16:10, playing as a hunter with the bots on).
-- It used to take the drive's one BASE and a lane number and deal the line out at
-- +-LANE_SPACING_STUDS (18) about it, with every goal translated sideways off the one base goal.
-- Two things were wrong with that and neither is fixable from in here:
--   * HOW WIDE a drive line is is a fact about the HUNTERS' FRONT, and this module reads no marker,
--     no post and no player -- so 72 studs of total front was a constant, centred on whatever base
--     the drive had measured. In the Forest Test that base is the stand the drive aims at, which is
--     the stand SHE WAS STANDING ON.
--   * A GOAL TRANSLATED SIDEWAYS IS NOT ON THE ROAD. The forest's road is a sine 30 studs deep and
--     `GOAL_PAST_LINE_STUDS` is 20, so at any real width a lane's goal lands north of the tarmac,
--     the bot stops short of the line and `Match.crossedLine` never counts it through.
-- So the drive states each lane's own start and its own goal (`Match.botSlotsFor` asks the world for
-- lane `n` by index, exactly as it asks for a hunter's stand), and what is left here is the WALK:
-- how far down the lane to aim, how to step round a trunk, and whether it has arrived. The three
-- offset functions are archived in `backups/2026-10-12-bots-lane-offsets.md` (rule 7), with the
-- property they existed to protect -- the middle of the line stays the people's -- kept and re-stated
-- in `ForestTest.beaterLaneOffset`, where the front can actually be seen.
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

-- WHERE THIS BOT ACTUALLY AIMS THIS STEP: the lane's next point, nudged aside if it is blocked OR if
-- the bot is STUCK. PURE in its arguments -- `roomToStand` is the world's own clearance reader,
-- passed in, so `bots_live.spec` drives every branch with a function of its own and no world.
-- Returns the aim and how many side-steps it took (0 or 1), which is the number the report prints.
--
-- THE `forced` BRANCH IS NOT AN OPTIMISATION, IT IS THE WHOLE STUCK RULE, and round 1 of this task
-- found it inverted: the nudge used to be reachable only when the clearance reader said the aim was
-- BLOCKED, so in the one world that has trunks a bot pinned against something whose 12-stud-ahead
-- point happened to be clear got counted and never moved. A stuck bot is stuck BECAUSE the thing
-- stopping it is not where the whisker is looking -- its shoulder, its own feet on a root, another
-- bot -- so "the aim looks fine" is exactly the case the nudge exists for. `forced > 0` therefore
-- side-steps whatever the reader answers.
--
-- WITH NO READER (the DEV arena, flat and empty) every point is clear, so an unforced step never
-- nudges and a forced one takes the first candidate. That is this world before the stuck window.
function Lane.clearAim(here: Vector3, goal: Vector3, forced: number, roomToStand, config): (Vector3, number)
	local aim = Lane.aimFor(here, goal, config.AHEAD_STUDS)
	local clear = if roomToStand ~= nil then roomToStand(aim, config.LANE_CLEAR_STUDS) == true else true
	if clear and forced <= 0 then
		return aim, 0
	end
	for try = 1, config.SIDE_TRIES do
		local candidate = Lane.sideStep(aim, here, goal, try, config)
		if roomToStand == nil or roomToStand(candidate, config.LANE_CLEAR_STUDS) == true then
			return candidate, 1
		end
	end
	-- Nothing within `SIDE_TRIES` was clear: walk at the lane point anyway and let the stuck counter
	-- say so. A bot that refuses to move is worse than a bot that bumps a trunk -- the same reasoning
	-- `ForestTest.beaterStartPosition` gives for putting her down behind the crossing anyway.
	return aim, 0
end

return Lane
