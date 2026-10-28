--!strict
-- Lobby.Join: WHEN STANDING SOMEWHERE IS A REQUEST TO HUNT. PURE: no Instance, no service, no clock,
-- no Random. That is what lets `tests/server/lobby.spec.luau` drive the entry, the cancel, the
-- re-entry and the exact boundary second with hand-written numbers and no character at all.
--
-- KAREN chose *"Walk to a car"*, and task 182 made the marked spot FOUR coloured rectangles, one
-- behind each truck: *"you come to truck back rectangle and can click and select how many players"*.
-- What is left in this file is the rectangle predicate the pads are measured with, the field
-- rectangle, and the rule about where a man belongs when he is not hunting. The pad STATE MACHINE is
-- `Lobby.Pads`.
--
-- Pattern: VALVE'S `trigger_multiple`, READ AS ARITHMETIC.
--   https://developer.valvesoftware.com/wiki/Trigger_multiple  (CC BY-SA, community wiki, and the
--   entity ships in every Source game)
-- A trigger volume's whole value is that it knows who is INSIDE it -- presence, not collision -- and
-- Half-Life's level flow is built on it. `BasePart.Touched` is the opposite: it fires on CONTACT, so
-- a player who stands perfectly still inside the pad generates nothing after the first touch, and
-- `TouchEnded` cannot reliably answer "has he left" -- which is the one question a pad that cancels
-- on stepping off has to ask every tick. A `ProximityPrompt` was refused for a different reason: it
-- is a BUTTON, and Karen asked to walk to the car (`docs/design/lobby.md` section 14.3).
--
-- In Roblox the presence test is a subtraction, not an event, and this repo already has that shape:
-- `ForestTest.withinStand` (*"IS THIS POSITION INSIDE THE STAND'S CIRCLE? Pure, so the boundary is
-- one rule and not one rule per reader"*). This is the same rule for a different shape.
--
-- Design: docs/design/truck-pads.md (sections 4, 6); docs/design/lobby.md (sections 6, 8.1)
-- Note:   docs/research/2026-10-14-truck-pads.md (section 2a);
--         docs/research/2026-10-13-lobby-and-the-truck.md (section 3)
local Join = {}

-- IS THIS POSITION INSIDE THE PAD'S RECTANGLE?
--
-- KAREN ASKED FOR A RECTANGLE (task 182): *"has to be coloroude circle like in all games or rectangle
-- where people stand"*, and *"you come to truck back rectangle"*. So task 177's squared-distance
-- circle becomes two `math.abs` comparisons. THE MECHANISM IS UNCHANGED and the header above is
-- still the citation: presence, measured as arithmetic, never `BasePart.Touched`.
--
-- FLAT: the Y is ignored, exactly as `ForestTest.withinStand` ignores it, because a player standing
-- on the pad's own slab -- or on the truck's running board -- is above its centre and has not left
-- it.
--
-- `<=` -- ON the edge is IN it, the same comparison `withinStand` makes, and A CORNER IS IN, which
-- is the whole difference from a circle: an inscribed circle would call the four corners of Karen's
-- own rectangle "not the pad".
--
-- `size` IS THE PART'S OWN `Vector3` (`CONFIG.PADS.SIZE`) so the rule and the slab cannot disagree
-- about how big the pad is; `size.Y` is deliberately unread.
function Join.withinRect(position: Vector3, centre: Vector3, size: Vector3): boolean
	return math.abs(position.X - centre.X) <= size.X / 2 and math.abs(position.Z - centre.Z) <= size.Z / 2
end

-- IS THIS POSITION ON THE LOBBY'S OWN FIELD? The rectangle, not a circle, because the field IS a
-- rectangle (`CONFIG.FIELD.SPAN_STUDS` square) and a circle inscribed in it would call the four
-- corners of Karen's yard "not the lobby".
--
-- IT IS THE ONLY QUESTION THE RETURN RULE ASKS about where a man is standing, and it is here rather
-- than in the owner for the reason `withinRect` is: a boundary asked twice is two boundaries.
function Join.insideField(position: Vector3, anchor: Vector3, cfg): boolean
	local half = cfg.FIELD.SPAN_STUDS / 2
	return math.abs(position.X - anchor.X) <= half and math.abs(position.Z - anchor.Z) <= half
end

-- ---------------------------------------------------------------- WHERE A MAN BELONGS (task 302)
--
-- THE LOBBY IS NOT ONLY THE LODGE'S FIELD ANY MORE. Measured in Karen's place, 2026-10-28: a
-- character standing on the range mat at (2650, -3214) was respawned at the lodge 0.6 s later,
-- because the mat is 268 studs from the anchor and the field's half-span is 110. She could not use
-- the range at all.
--
-- A UNION OF RECTANGLES, NOT THE BOUNDING BOX OF THE LODGE AND THE RANGE. The bounding box
-- (x 2558..2960, z -3368..-2840 in her place) is 212,000 studs square and NONE of its edges is a
-- fact about anything: it swallows the forest south-east of the lodge and north-west of the range,
-- where nobody walks, and it grows by the square when a third area is added. Each rectangle of the
-- union has a reason of its own instead -- the lodge's own field, the range's own footprint, and
-- the corridor along the line a man actually walks between them -- so every edge can be defended.
--
-- THE AREAS ARE DATA, HANDED IN BY THE COMPOSITION ROOT (`Range.footprintFor` through
-- `ForestTestBoot`), so this owner requires nothing of the range (design section 3). A world with
-- no range row hands in nothing and gets exactly the old 220 x 220 square, bit for bit.
export type Area = { minX: number, maxX: number, minZ: number, maxZ: number }

-- `withinRect`'s rule in min/max form: FLAT (the Y is ignored) and ON the edge is IN.
function Join.withinArea(position: Vector3, area: Area): boolean
	return position.X >= area.minX and position.X <= area.maxX and position.Z >= area.minZ and position.Z <= area.maxZ
end

-- THE CORRIDOR BETWEEN THE LODGE AND AN OUTLYING AREA: the bounding box of the straight line from
-- the anchor to that area's centre, widened by `FIELD.WALKWAY_HALF_STUDS` on both axes. The whole
-- segment is inside it by construction, so the walk cannot fall through a gap between the two ends.
function Join.walkwayTo(anchor: Vector3, to: Vector3, cfg): Area
	local half = cfg.FIELD.WALKWAY_HALF_STUDS
	return {
		minX = math.min(anchor.X, to.X) - half,
		maxX = math.max(anchor.X, to.X) + half,
		minZ = math.min(anchor.Z, to.Z) - half,
		maxZ = math.max(anchor.Z, to.Z) + half,
	}
end

-- EVERY RECTANGLE A MAN MAY STAND IN AND NOT BE SENT HOME: the field, then each extra area and the
-- corridor that reaches it. Computed ONCE at `Lobby.start` and read every scan.
function Join.homeAreas(anchor: Vector3, cfg, extras: { Area }?): { Area }
	local half = cfg.FIELD.SPAN_STUDS / 2
	local out: { Area } = {
		{ minX = anchor.X - half, maxX = anchor.X + half, minZ = anchor.Z - half, maxZ = anchor.Z + half },
	}
	if type(extras) ~= "table" then
		return out
	end
	for _, area in ipairs(extras) do
		table.insert(out, area)
		local centre = Vector3.new((area.minX + area.maxX) / 2, anchor.Y, (area.minZ + area.maxZ) / 2)
		table.insert(out, Join.walkwayTo(anchor, centre, cfg))
	end
	return out
end

-- IS THIS POSITION ANYWHERE IN THE LOBBY? `insideField`'s replacement at the call site, and the
-- same answer when the list is the field alone.
function Join.insideHome(position: Vector3, areas: { Area }): boolean
	for _, area in ipairs(areas) do
		if Join.withinArea(position, area) then
			return true
		end
	end
	return false
end

-- THE PER-PLAYER COUNTDOWN IS GONE, AND IT WENT TO THE PAD (task 182). Task 177 gave every man his
-- own five-second clock (`Join.Entry`, `Join.decide`, and the four verdicts
-- `IDLE`/`COUNTING`/`CANCELLED`/`ENROL`); a party of four needs ONE clock for the four of them, and
-- that is what `Lobby.Pads` is -- a state machine per pad instead of an entry per player. Both
-- functions are archived with their reason, in full, in
-- `backups/2026-10-14_task-182_the-marked-circle.txt` (rule 7).
--
-- WHAT STAYED IS THIS FILE'S OTHER HALF, below: the field rectangle and the return rule. How a hunt
-- STARTS changed; where a man BELONGS when he is not in one did not.

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
