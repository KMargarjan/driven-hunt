--!strict
-- Lobby.Join: WHEN STANDING SOMEWHERE IS A REQUEST TO HUNT. PURE: no Instance, no service, no clock,
-- no Random. That is what lets `tests/server/lobby.spec.luau` drive the entry, the cancel, the
-- re-entry and the exact boundary second with hand-written numbers and no character at all.
--
-- KAREN chose *"Walk to a car"*, and for this first version *"step into a marked spot by the truck"*.
--
-- Pattern: VALVE'S `trigger_multiple`, READ AS ARITHMETIC.
--   https://developer.valvesoftware.com/wiki/Trigger_multiple  (CC BY-SA, community wiki, and the
--   entity ships in every Source game)
-- A trigger volume's whole value is that it knows who is INSIDE it -- presence, not collision -- and
-- Half-Life's level flow is built on it. `BasePart.Touched` is the opposite: it fires on CONTACT, so
-- a player who stands perfectly still inside the circle generates nothing after the first touch, and
-- `TouchEnded` cannot reliably answer "has he left" -- which is the one question a countdown that
-- cancels on stepping out has to ask every tick. A `ProximityPrompt` was refused for a different
-- reason: it is a BUTTON, and Karen asked to walk to the car (design section 14.3).
--
-- In Roblox the presence test is a subtraction, not an event, and this repo already has that shape:
-- `ForestTest.withinStand` (*"IS THIS POSITION INSIDE THE STAND'S CIRCLE? Pure, so the boundary is
-- one rule and not one rule per reader"*). This is the same rule for a different circle.
--
-- Design: docs/design/lobby.md (section 6)
-- Note:   docs/research/2026-10-13-lobby-and-the-truck.md (section 3)
local Join = {}

-- IS THIS POSITION INSIDE THE CIRCLE?
--
-- FLAT: the Y is ignored, exactly as `ForestTest.withinStand` ignores it, because a player standing
-- on the truck's running board is a stud above the ground and has not left the circle.
--
-- `<=` -- ON the circle is IN it, the same comparison `withinStand` makes. The screen's own
-- "arrived" band (`Objective.CONFIG.ARRIVED_IN_STUDS`, 12 against this radius of 8) is wider on
-- purpose, so the chevron goes out while he is already inside, never the other way round.
function Join.within(position: Vector3, spot: Vector3, radiusStuds: number): boolean
	local dx, dz = position.X - spot.X, position.Z - spot.Z
	return dx * dx + dz * dz <= radiusStuds * radiusStuds
end

-- IS THIS POSITION ON THE LOBBY'S OWN FIELD? The rectangle, not a circle, because the field IS a
-- rectangle (`CONFIG.FIELD.SPAN_STUDS` square) and a circle inscribed in it would call the four
-- corners of Karen's yard "not the lobby".
--
-- IT IS THE ONLY QUESTION THE RETURN RULE ASKS about where a man is standing, and it is here rather
-- than in the owner for the reason `within` is: a boundary asked twice is two boundaries.
function Join.insideField(position: Vector3, anchor: Vector3, cfg): boolean
	local half = cfg.FIELD.SPAN_STUDS / 2
	return math.abs(position.X - anchor.X) <= half and math.abs(position.Z - anchor.Z) <= half
end

-- ONE PLAYER'S COUNTDOWN, as it stands right now.
export type Entry = { since: number, leaveAt: number }

-- THE FOUR VERDICTS, as words rather than as booleans, because the caller does a different thing for
-- each one and a pair of booleans would have a fifth state that means nothing.
Join.IDLE = "idle" -- outside, and was outside: nothing to do
Join.COUNTING = "counting" -- inside, counting down. `entry.leaveAt` is when he goes
Join.CANCELLED = "cancelled" -- he stepped out before it ran down
Join.ENROL = "enrol" -- the countdown is done: the caller calls `world.enrol`

-- ONE STEP OF ONE PLAYER'S COUNTDOWN. PURE over `(entry, inside, now, cfg)`, so the whole rule is a
-- table of cases in a spec with no world: entry, cancel, re-entry, and the exact boundary second.
--
-- RE-ENTRY DOES NOT INHERIT THE OLD DEADLINE. Karen's rule is that stepping back out cancels it, and
-- a cancel that kept the clock running would make stepping out for two seconds and back in enrol him
-- instantly -- which is not a cancel, it is a pause nobody asked for. So the entry is dropped on the
-- way out and a new one is started on the way back in.
--
-- `>=` AT THE DEADLINE: five seconds means five, not five-and-a-frame.
function Join.decide(entry: Entry?, inside: boolean, now: number, cfg): (Entry?, string)
	if not inside then
		return nil, (if entry ~= nil then Join.CANCELLED else Join.IDLE)
	end
	if entry == nil then
		return { since = now, leaveAt = now + cfg.COUNTDOWN_SECONDS }, Join.COUNTING
	end
	local open = entry :: Entry
	if now >= open.leaveAt then
		-- THE ENTRY IS DROPPED WITH THE VERDICT, so the caller cannot enrol the same man twice from
		-- one walk into the circle. `Match.enrol` is idempotent as well (design section 4.2), which
		-- is the belt to this brace.
		return nil, Join.ENROL
	end
	return open, Join.COUNTING
end

-- DOES THIS PLAYER BELONG BACK AT THE LODGE?
--
-- LEVEL-TRIGGERED, NOT EDGE-TRIGGERED, and that is the design's own decision (section 8.1): there
-- are four ways to end up standing in the wrong place and only one of them is a phase change. A
-- player who joins mid-drive may have been put at the place's own `ForestRoadSpawn` before any
-- handler ran; a dismissed player whose drive went `Scoring -> Assigning` never reached `Waiting` at
-- all; a player who pressed Reset has no edge; a player who fell off the shelf's downhill edge has
-- no edge either. A level rule covers all four with one predicate.
--
-- `inField` IS `boolean?` AND nil MEANS "NO ANSWER, DO NOTHING". A player with no character -- joining,
-- or mid-respawn -- has no position, and ABSENT IS NOT OUTSIDE: the rule `MapUi.pointsFor` already
-- states (*"a stale dot is a lie about where somebody is"*). Returning a man who is in the middle of
-- being returned is how a respawn loop starts.
--
-- `held` IS LOAD-BEARING. During the results scene a dismissed player is not a participant and is
-- 570 studs from the lodge, so without this the lobby would respawn him out of Karen's results
-- scene.
function Join.needsReturn(inDrive: boolean, held: boolean, inField: boolean?): boolean
	if inDrive or held then
		return false
	end
	return inField == false
end

return Join
