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

-- ------------------------------------------------------------------ seeing it, and getting off it
--
-- TASK 208. KAREN, 2026-10-18 ~14:20: *"bot beater stuck we definatly need to fix that they not
-- stuck the can avoid"*, with *"do not try to fix forest, we will go together"* in the same message
-- -- so the bots cope with the wood as it is.
--
-- WHAT WAS MEASURED (`docs/research/2026-10-19-bots-unstuck.md` section 4), in Karen's own Forest
-- Test, all four places, every bot sampled at 2 Hz: **three episodes over three seconds**, the worst
-- **34.0 s**, and two of the three were a beater pressed against an ANCHORED BOT HUNTER standing on
-- the very stand its lane aims 20 studs past. The clearance reader above cannot see that by
-- construction -- `ForestTest.roomToStand` says in so many words that *a person is not an obstacle*
-- -- and the nudge the stuck window does fire was being thrown away before the humanoid saw it (the
-- owner's `MoveTo` cadence; section 4.3).
--
-- So three things are added, and every one of them is a borrow (note section 2):
--   `isStuck`      the boar's own fast wedge test (`Brain:_updateWedge`, task 150)
--   `detourAim`    Reynolds' obstacle avoidance: the smallest deflection that has room
--   `recoveryFor` / `recoverAim`   ioquake3's three answers and its try counter (`be_ai_move.c`)

-- IS IT STUCK? PURE, and it is the BOAR'S OWN WEDGE TEST re-pointed (`Boar.CONFIG.MOVE.WEDGE_*`,
-- task 150): told to move faster than `STUCK_ORDERED_SPEED`, actually covering less than
-- `STUCK_SLOW_SPEED` of ground, over at least `STUCK_FAST_SECONDS`. Karen's complaint about the
-- animals then -- *"still can see sometimes boar hit tree and wal in place so not avoiding tree"* --
-- is her complaint about the bots now, so the answer that worked is the answer borrowed.
--
-- MEASURED OFF POSITION, NOT OFF THE SETPOINT, which is that function's own stated reason: *"a
-- setpoint cannot know the animal is not moving"*. `Humanoid.MoveDirection` cannot do it either:
-- MEASURED 2026-10-19 in Karen's Forest Test, a bot rig walking at 5 studs/s under `MoveTo` reads
-- `MoveDirection.Magnitude = 0.000` on the SERVER on every sample while its state is `Running`
-- (note section 4.1). The property is documented Not Replicated and is evidently not filled in for
-- a server-driven humanoid.
--
-- WHY THE WINDOW IS 0.8 s AND NOT THE EXISTING 4: `STUCK_SECONDS` only answers on the tick its
-- window closes, so the first report of a bot that stopped dead is up to four seconds late and a
-- three-second recovery cannot start from it. Both tests live side by side, exactly as the boar's
-- two do.
function Lane.isStuck(coveredStuds: number, overSeconds: number, orderedSpeed: number, config): boolean
	if overSeconds < config.STUCK_FAST_SECONDS or orderedSpeed < config.STUCK_ORDERED_SPEED then
		return false
	end
	return coveredStuds / overSeconds < config.STUCK_SLOW_SPEED
end

-- THE DEFLECTED AIM POINT, `degrees` off the lane. PURE. The lane's own direction is rotated about Y
-- and the aim is re-measured from the bot, so a deflection is still a point `AHEAD_STUDS` away and
-- never past the goal: a detour is a DEFLECTION OF THE LANE, which is what keeps four of these a
-- line (note 2026-10-12 section 3).
function Lane.turnedAim(here: Vector3, goal: Vector3, degrees: number, config): Vector3
	local away = flat(goal - here)
	if away.Magnitude < 1e-4 then
		return Lane.aimFor(here, goal, config.AHEAD_STUDS)
	end
	local reach = math.min(away.Magnitude, config.AHEAD_STUDS)
	local radians = math.rad(degrees)
	local unit = away.Unit
	local turned = Vector3.new(
		unit.X * math.cos(radians) - unit.Z * math.sin(radians),
		0,
		unit.X * math.sin(radians) + unit.Z * math.cos(radians)
	)
	return Vector3.new(here.X + turned.X * reach, here.Y, here.Z + turned.Z * reach)
end

-- GO ROUND IT, BY THE SMALLEST DEFLECTION THAT HAS ROOM. `blockedAt(point)` is the world's own swept
-- test, passed in (`ForestTest.laneAhead`, wrapped by the owner), so every branch here is a spec's
-- to drive with a function of its own. Returns the aim and the degrees it cost, or nil when no
-- candidate in the fan is clear -- and nil means "say nothing", which leaves the lane point and the
-- stuck ladder to it.
--
-- Pattern: Reynolds' obstacle avoidance -- *"takes action only when a nearby obstacle lies directly
-- in front of the character"*, and the steering is only as large as the intrusion needs
-- (<http://www.red3d.com/cwr/steer/gdc99/>). It is `Brain.clearTurnDeg`'s shape, and the reason it
-- is not that function is an owner boundary: `Bots` must not require `Boar` to walk a man through a
-- wood (CLAUDE.md rule 3, and rule 2's written reason for a second copy).
--
-- THE BOT'S OWN SIDE FIRST, alternating after it, so two bots on one trunk do not both choose left.
function Lane.detourAim(here: Vector3, goal: Vector3, side: number, blockedAt, config): (Vector3?, number?)
	local prefer = if side < 0 then -1 else 1
	local spent = 0
	for _, magnitude in ipairs(config.DETOUR_ANGLES_DEG) do
		if spent >= config.DETOUR_CASTS then
			return nil, nil
		end
		local degrees = magnitude * prefer
		local candidate = Lane.turnedAim(here, goal, degrees, config)
		spent += 1
		if blockedAt(candidate) ~= true then
			return candidate, degrees
		end
	end
	return nil, nil
end

-- WHICH RECOVERY, AND IT IS A MEASUREMENT AND NOT A GUESS. `aheadStuds` is how far down the lane the
-- first solid thing is and `stepStuds` how far its top stands above the bottom of the swept body --
-- both from the world's own cast. ioquake3's three answers, in its own order (`be_ai_move.c`): a low
-- thing is JUMPED (`BotCheckBarrierJump`), anything else is gone ROUND, and a route element that
-- keeps failing is BACKED AWAY FROM and counted (`AVOIDREACH_TRIES` 4; this ladder reaches its last
-- rung at `BACK_OFF_AFTER_TRIES` 3, because the bar here is three seconds per episode).
--
-- NO MEASUREMENT (the DEV arena injects no reader) IS A SIDESTEP, which is exactly what the stuck
-- nudge has always done there.
function Lane.recoveryFor(aheadStuds: number?, stepStuds: number?, tries: number, config): string
	if tries >= config.BACK_OFF_AFTER_TRIES then
		return "backoff"
	end
	if aheadStuds ~= nil and stepStuds ~= nil and stepStuds <= config.JUMP_OVER_STUDS then
		return "jump"
	end
	return "sidestep"
end

-- WHERE A RECOVERY AIMS. PURE.
--   `sidestep`  perpendicular to the lane, the width growing with the tries and the side
--               ALTERNATING -- `Lane.sideStep`'s own existing law, which is the boar's
--               `_wedgeCount % 2`: a bot that cannot get past on one side tries the other instead of
--               leaning harder on the same one.
--   `jump`      the lane's own point. The jump is the ACTION (the owner changes the humanoid's
--               state); the aim must not move, or the bot hops sideways off a log it is clearing.
--   `backoff`   behind the bot, down its own lane, and then offset to the side it is about to try --
--               so the next sidestep starts from clear ground rather than from against the thing.
function Lane.recoverAim(here: Vector3, goal: Vector3, kind: string, tries: number, config): Vector3
	local aim = Lane.aimFor(here, goal, config.AHEAD_STUDS)
	if kind == "jump" then
		return aim
	end
	local try = math.max(tries, 1)
	if kind == "backoff" then
		local away = flat(goal - here)
		if away.Magnitude < 1e-4 then
			return aim
		end
		local back = here - away.Unit * config.BACK_OFF_STUDS
		return Lane.sideStep(Vector3.new(back.X, here.Y, back.Z), here, goal, try, config)
	end
	return Lane.sideStep(aim, here, goal, try, config)
end

return Lane
