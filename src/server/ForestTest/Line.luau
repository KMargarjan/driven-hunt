--!strict
-- ForestTest.Line: THE ARITHMETIC OF A LINE OF BOARS. Pure -- no Instance, no clock, no service, no
-- runtime -- so every rule below is drivable by a spec with no world and no animal.
--
-- Karen, 2026-10-05: *"imagine they have to go from one side to another / crossing roud with one
-- line could be 2 i line ect how in real life ... imagine they come from one side in one line and
-- crossing road thats it"*.
--
-- THE LINE IS A TRAIL, NOT A FORMATION, and that is the whole idea. Task 126 built a file by having
-- each follower STEER at a point behind the animal ahead, and measured the result: the gap stayed at
-- 23-35 studs, the turning went UP, and the thing never read as a line. Steering at a moving point
-- is a chase, and a chase wanders.
--
-- Here the leader walks a route and DROPS BREADCRUMBS. Follower k stands at `k * SPACING` measured
-- ALONG THAT TRAIL -- arc length, not straight-line distance -- so it walks exactly where she walked.
-- It therefore cannot cut a corner, cannot spread, cannot circle, and cannot hit a tree she missed.
-- The same idea a train has: the carriages do not steer.
--
-- Pattern: Reynolds' `path following` for the leader plus `queueing` behind her, with the queue
-- resolved by ARC LENGTH rather than by steering.
--   https://www.red3d.com/cwr/steer/gdc99/
--
-- Note: docs/research/2026-10-05-sounder-movement.md (section 4: a chain cannot orbit)
local Line = {}

-- A breadcrumb: where the leader was, and how far she had walked when she was there.
export type Crumb = { at: Vector3, s: number }

-- WHERE THE LEADER HAS BEEN. Appends only when she has moved `minStuds`, so a stopped leader does
-- not fill the trail with one point repeated, and the arc length `s` is cumulative.
--
-- IT RETURNS A NEW LENGTH RATHER THAN MUTATING A COUNTER somewhere else: the trail and its length
-- are one fact, and two places holding it is how they disagree.
function Line.addCrumb(trail: { Crumb }, at: Vector3, minStuds: number): boolean
	local last = trail[#trail]
	if last == nil then
		table.insert(trail, { at = at, s = 0 })
		return true
	end
	local moved = (Vector3.new(at.X, 0, at.Z) - Vector3.new(last.at.X, 0, last.at.Z)).Magnitude
	if moved < minStuds then
		return false
	end
	table.insert(trail, { at = at, s = last.s + moved })
	return true
end

-- HOW LONG THE TRAIL IS, in studs walked.
function Line.length(trail: { Crumb }): number
	local last = trail[#trail]
	return if last == nil then 0 else last.s
end

-- THE POINT `back` STUDS BEHIND THE HEAD OF THE TRAIL, interpolated between crumbs, plus the
-- direction of travel there. Returns nil while the trail is shorter than `back` -- the line is still
-- forming and that follower has not been overtaken by the leader yet.
--
-- INTERPOLATED, NOT SNAPPED TO THE NEAREST CRUMB: at `CRUMB_STUDS` = 1 a snapped follower would
-- jitter by up to a stud every step, which reads as a limp.
function Line.pointBack(trail: { Crumb }, back: number): (Vector3?, Vector3?)
	local head = trail[#trail]
	if head == nil then
		return nil, nil
	end
	local want = head.s - back
	if want < 0 then
		return nil, nil
	end
	return Line.pointAt(trail, want)
end

-- THE POINT AT AN ARC LENGTH ALONG THE TRAIL, plus the direction of travel there. This is the one
-- primitive; `pointBack` is it measured from the head.
function Line.pointAt(trail: { Crumb }, s: number): (Vector3?, Vector3?)
	local head = trail[#trail]
	if head == nil then
		return nil, nil
	end
	if s >= head.s then
		return head.at, nil
	end
	if s <= trail[1].s then
		return trail[1].at, nil
	end
	for index = #trail, 2, -1 do
		local ahead, behind = trail[index], trail[index - 1]
		if behind.s <= s then
			local span = ahead.s - behind.s
			local t = if span > 1e-6 then (s - behind.s) / span else 0
			local travel = Vector3.new(ahead.at.X - behind.at.X, 0, ahead.at.Z - behind.at.Z)
			return behind.at:Lerp(ahead.at, t), if travel.Magnitude > 1e-6 then travel.Unit else nil
		end
	end
	return trail[1].at, nil
end

-- WHERE AN ANIMAL IS *ON* THE TRAIL, as an arc length: the nearest point of the polyline to it.
--
-- THIS IS WHAT MAKES A FOLLOWER WALK THE TRAIL RATHER THAN ACROSS IT (task 127 round 2). Ordering an
-- animal straight at a station that is round a corner is ordering it to CUT that corner -- through
-- whatever the leader had gone round, which is a trunk. Knowing its own arc position means the next
-- order can be a point a little FURTHER ALONG the same polyline, so it walks the leader's path
-- instead of a chord across it.
-- ...AND IT REMEMBERS WHERE THE ANIMAL WAS, WHICH IS THE WHOLE OF TASK 136's FIRST FIX.
--
-- THE NEAREST POINT ON THE WHOLE POLYLINE IS THE WRONG ANSWER WHEN THE TRAIL DOUBLES BACK, and the
-- leader doubles back every time she rounds a trunk. The two passes come within a few studs of each
-- other, so a follower walking the FIRST pass is geometrically nearest the SECOND -- and this
-- answered with the second one's arc length. Everything downstream then went wrong at once: `slack`
-- came out negative, so the animal was told it had overrun and stopped; and `ownS + lookahead` was a
-- point on the far branch, so when it did move it cut straight across the loop the leader had just
-- walked round. That is "followers cutting inside where the trail doubles back" from task 127 round
-- 3's own note, and it is why the offset p90 was 7 studs against a 1.3 median: the median is the
-- file walking normally and the tail is this.
--
-- SO THE SEARCH IS LOCAL. `fromS` is where this animal was on the trail last step and `window` is how
-- far it could credibly have moved since; only segments overlapping that window are considered. An
-- animal with no history -- a new line, or one rejoining after a flight -- passes `nil` and gets the
-- old global search, which is the right answer exactly once.
--
-- A WINDOW THAT FINDS NOTHING FALLS BACK rather than returning a stale number: the trail is trimmed
-- from behind, so a hint can fall off the back of it.
function Line.arcAt(trail: { Crumb }, at: Vector3, fromS: number?, window: number?): number
	local best, bestD = 0, math.huge
	local low, high = -math.huge, math.huge
	if fromS ~= nil and window ~= nil then
		low, high = fromS - window, fromS + window
	end
	for _pass = 1, 2 do
		for index = #trail, 2, -1 do
			local ahead, behind = trail[index], trail[index - 1]
			local segment = Vector3.new(ahead.at.X - behind.at.X, 0, ahead.at.Z - behind.at.Z)
			local length = segment.Magnitude
			if length > 1e-6 and ahead.s >= low and behind.s <= high then
				local to = Vector3.new(at.X - behind.at.X, 0, at.Z - behind.at.Z)
				local t = math.clamp(to:Dot(segment) / (length * length), 0, 1)
				local closest = behind.at:Lerp(ahead.at, t)
				local d = (Vector3.new(at.X - closest.X, 0, at.Z - closest.Z)).Magnitude
				if d < bestD then
					bestD, best = d, behind.s + t * length
				end
			end
		end
		if bestD < math.huge then
			break
		end
		-- Nothing in the window: widen to the whole trail and try once more.
		low, high = -math.huge, math.huge
	end
	return best
end

-- WHERE A FOLLOWER AIMS, AS AN ARC LENGTH. Pure arithmetic, pulled out of the drive so it can be
-- driven by a spec without a world (task 136).
--
-- FOUR RULES, IN THIS ORDER, AND THE ORDER IS THE POINT:
--   1. a lookahead further along the trail -- short, because the only promise is that the leader
--      walked this bit (task 127 round 3);
--   2. NEVER PAST THE ONE IN FRONT: `aheadS` is the arc position measured for the rank above, not
--      its station, so a file that has bunched up is regulated against where the animals ARE;
--   3. NEVER UNDER ITS OWN FEET: a clamp that pulls the aim inside
--      `Boar.CONFIG.LINE.ARRIVE_STUDS` stops the
--      animal dead, and a stopped follower is a broken line. MEASURED: with rule 2 at a body length
--      and no rule 3, a 6.5-stud station aimed an animal 1.0 stud ahead -- exactly `ARRIVE_STUDS` --
--      and the run went from 15 stuck to 58;
--   4. and it stays on the trail that exists, between its tail and its head.
-- Rule 3 can therefore beat rule 2 when a follower is right on the bumper of the one in front. That
-- is deliberate: holding it back is the SPEED's job (`Line.followerSpeed`), not the aim's.
function Line.aimFor(
	ownS: number,
	lookahead: number,
	aheadS: number,
	noOvertake: number,
	minAim: number,
	headS: number,
	tailS: number
): number
	local aim = math.min(ownS + lookahead, headS)
	aim = math.min(aim, aheadS - noOvertake)
	aim = math.max(aim, ownS + minAim)
	aim = math.min(aim, headS)
	return math.max(aim, tailS)
end

-- WHO IS IN THE FILE, AND IN WHAT ORDER, AFTER A FLIGHT ENDS. Pure, and pulled out of the drive so
-- a spec can drive it without a world (task 137; the Reviewer's first note on task 136, and the one
-- that mattered -- the rank guard below was round 1's BLOCKING finding and was proved by reading
-- only, so it could have been deleted green).
--
-- TWO RULES:
--   1. AN ANIMAL WHOSE FLIGHT HAS JUST ENDED GOES TO THE TAIL. It used to keep its rank, which is a
--      station up the middle of a file that closed up behind it while it was away -- so it walked
--      ACROSS the line to reach it. The tail is behind everybody and reachable by walking the trail.
--   2. NEVER THE LEADER. She has no mid-file station, so rule 1's reason does not apply to her -- and
--      demoting her was reachable by the central action of this game. Shoot at a line, the sow bolts,
--      and the step her flight ends she was moved to the back: `line.trail` follows whoever is
--      `live[1]`, so the next crumb ran from HER position to the position of the animal that replaced
--      her -- one segment BACKWARDS across the whole gap she had bolted. Every follower's station
--      then leapt onto that segment while its hinted arc position stayed on the forward branch, and
--      the file was driven on up the dead flight path. It also handed `line.route` and `line.leg`,
--      computed for the sow, to a cub.
--
-- `members` is `{ id, kind }` in file order. `flying(id)` is now and `was[id]` is last step. The
-- answer is the new order and the ids that moved, and the order is STABLE for everybody else.
function Line.rejoinOrder(
	members: { { id: string, kind: string? } },
	flying: (string) -> boolean,
	was: { [string]: boolean }
): ({ { id: string, kind: string? } }, { string })
	local moved: { string } = {}
	local back: { [string]: boolean } = {}
	for place, member in ipairs(members) do
		if place > 1 and was[member.id] == true and not flying(member.id) then
			table.insert(moved, member.id)
			back[member.id] = true
		end
	end
	if #moved == 0 then
		return members, moved
	end
	local kept = {}
	for _, member in ipairs(members) do
		if not back[member.id] then
			table.insert(kept, member)
		end
	end
	for _, member in ipairs(members) do
		if back[member.id] then
			table.insert(kept, member)
		end
	end
	return kept, moved
end

-- FORGETS THE TAIL NOBODY IS STANDING ON any more, so a wave that walks 800 studs does not keep 800
-- crumbs for ever. `keepBack` is how far behind the head the last follower is, plus a margin.
function Line.trim(trail: { Crumb }, keepBack: number)
	local head = trail[#trail]
	if head == nil then
		return
	end
	local cut = head.s - keepBack
	while #trail > 2 and trail[2].s < cut do
		table.remove(trail, 1)
	end
end

-- WHO WALKS WHERE. Karen's order, and task 123's: the sow leads, then the other females, then the
-- piglets, and the males bring up the rear or travel alone -- which is the Animal Diversity Web
-- sentence task 123 quoted ("mothers keep their young in the middle, with adults in the lead and
-- rear") read as a single file.
--
-- `members` is `{ id, kind }`; the answer is the same list, ordered. Stable: ties keep their input
-- order, so the same wave always forms the same line.
function Line.order(members: { { id: string, kind: string? } }): { { id: string, kind: string? } }
	local rank = { female = 1, cub = 2, male = 3 }
	local indexed = {}
	for index, member in ipairs(members) do
		table.insert(indexed, { member = member, index = index, rank = rank[member.kind or ""] or 2 })
	end
	table.sort(indexed, function(a, b)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		return a.index < b.index
	end)
	local out = {}
	for _, row in ipairs(indexed) do
		table.insert(out, row.member)
	end
	return out
end

-- HOW MANY LINES, and who is in each. Karen: *"could be 2 i line"*. Two lines are two leaders with
-- their own routes a few studs apart; the order above is dealt out between them so each line keeps
-- a sow at its head.
function Line.split(ordered: { { id: string, kind: string? } }, lines: number)
	local groups = {}
	for which = 1, math.max(1, lines) do
		groups[which] = {}
	end
	for index, member in ipairs(ordered) do
		local which = ((index - 1) % #groups) + 1
		table.insert(groups[which], member)
	end
	return groups
end

-- THE SPEED A FOLLOWER ASKS FOR: the leader's, nudged by how far out of station it is, and clamped
-- so a line never concertinas. `slack` is positive when the follower is BEHIND its station.
--
-- THE CLAMP IS THE POINT. Without it a follower that falls 20 studs behind sprints to catch up and
-- overshoots, which is the oscillation task 126 measured; with it the line closes gently and the
-- whole thing stays at the leader's pace, which is what "in one line" looks like.
-- `slack` IS AN ARC-LENGTH ERROR NOW, SIGNED: positive means the animal is BEHIND its station, which
-- is the only reading that lets "ahead" and "behind" be told apart. The euclidean distance this used
-- to take could not: a follower that had overshot and one that had fallen behind both read positive,
-- so both sped up, which is half of why the measured gaps stayed at a 12.7 median.
function Line.followerSpeed(leaderSpeed: number, slack: number, tolerance: number, catchup: number): number
	if math.abs(slack) <= tolerance then
		return leaderSpeed
	end
	local scale = if slack > 0 then 1 + catchup else 1 - catchup
	return math.max(0, leaderSpeed * scale)
end

-- ...AND THE LEADER WAITS FOR HER TAIL, which is what a sow does and what stops a line becoming a
-- procession of singletons. `lag` is how far the LAST animal is behind its own station; past
-- `patience` she comes down to `slow` of her pace until it has closed.
function Line.leaderSpeed(pace: number, lag: number, patience: number, slow: number): number
	if lag <= patience then
		return pace
	end
	-- Linear from full pace at `patience` to `slow` at twice it, then flat: a sow eases up, she does
	-- not stop dead and leave a gap in the file.
	local over = math.clamp((lag - patience) / math.max(patience, 1e-6), 0, 1)
	return pace * (1 - over * (1 - slow))
end

return Line
