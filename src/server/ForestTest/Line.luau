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
function Line.arcAt(trail: { Crumb }, at: Vector3): number
	local best, bestD = 0, math.huge
	for index = #trail, 2, -1 do
		local ahead, behind = trail[index], trail[index - 1]
		local segment = Vector3.new(ahead.at.X - behind.at.X, 0, ahead.at.Z - behind.at.Z)
		local length = segment.Magnitude
		if length > 1e-6 then
			local to = Vector3.new(at.X - behind.at.X, 0, at.Z - behind.at.Z)
			local t = math.clamp(to:Dot(segment) / (length * length), 0, 1)
			local closest = behind.at:Lerp(ahead.at, t)
			local d = (Vector3.new(at.X - closest.X, 0, at.Z - closest.Z)).Magnitude
			if d < bestD then
				bestD, best = d, behind.s + t * length
			end
		end
	end
	return best
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
