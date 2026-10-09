# `Line.rejoinOrder` and its spec case, removed 2026-10-09 (task 139)

**Why it is gone.** Task 136 added it so an animal whose flight had ended rejoined its line at the
TAIL rather than keeping a station up the middle of a file that had closed up behind it. Task 137
proved its rank guard with six assertions, after the Reviewer found in round 1 that it could demote a
bolting sow.

**Karen, 2026-10-09, after playing `0c7f736`:** *"when boars crossing road they can't come back to
same view, they just move on a specially after spook or shoot"*. The Director's decision the same
day: **once an animal has fled or crossed the road it leaves line mode permanently** -- never
rejoins, never re-ordered. There is no "after a flight ends" left to order, and a function nothing
can reach is worse than no function.

**It was also the regression this task went looking for.** With flights pointed south
(`Brain:_latchFlight`, same task), the tail this rule sent animals to is NORTH of the road: measured
at 19 to 26 animals coming back north over the road in a 150 s run, against 0 on main. The "stands
and stays" Karen reported is the same path -- the line takes a shot animal back, hands it the tail
station, and the overrun rule orders `point = here, speed = 0`, which is a wounded boar standing
perfectly still in the open.

**Where the rule lives now:** `ForestTest.stepLines`, `line.gone` -- flying, hurt, or south of the
road means out of the file for good.

---

## `src/server/ForestTest/Line.luau`

```lua
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

```

## `tests/server/forest_line.spec.luau`

```lua
		it("sends a follower that has stopped flying to the TAIL, and never the leader", function()
			-- TASK 136's ROUND-1 BLOCKING FINDING, AS A TEST (task 137). The rank guard was proved by
			-- reading only, so it could have been deleted green -- which is how it shipped broken in
			-- the first place. `Line.rejoinOrder`'s own comment is the why.
			local function file(...)
				local out = {}
				for _, id in ipairs({ ... }) do
					table.insert(out, { id = id, kind = "female" })
				end
				return out
			end
			local function ids(members)
				local out = {}
				for _, m in ipairs(members) do
					table.insert(out, m.id)
				end
				return table.concat(out, ",")
			end
			local none = function(_id: string)
				return false
			end

			-- A FOLLOWER COMES BACK: it goes behind everybody, and the rest keep their order.
			local back, moved = Line.rejoinOrder(file("sow", "b", "c", "d"), none, { c = true })
			expect(ids(back)).to.equal("sow,b,d,c")
			expect(#moved).to.equal(1)
			expect(moved[1]).to.equal("c")

			-- TWO OF THEM COME BACK: both go to the tail, in the order they stood in.
			local two = Line.rejoinOrder(file("sow", "b", "c", "d"), none, { b = true, d = true })
			expect(ids(two)).to.equal("sow,c,b,d")

			-- THE LEADER COMES BACK AND NOTHING MOVES AT ALL. This is the guard: with it gone the
			-- answer is "b,c,d,sow", the trail's next crumb runs backwards across the gap the sow
			-- bolted, and the whole file is driven up her dead flight path.
			local sow, sowMoved = Line.rejoinOrder(file("sow", "b", "c", "d"), none, { sow = true })
			expect(ids(sow)).to.equal("sow,b,c,d")
			expect(#sowMoved).to.equal(0)

			-- ...AND THE LEADER IS STILL NOT MOVED WHEN A FOLLOWER IS, so the guard cannot be
			-- satisfied by the "nothing moved" shortcut alone.
			local both = Line.rejoinOrder(file("sow", "b", "c", "d"), none, { sow = true, b = true })
			expect(ids(both)).to.equal("sow,c,d,b")

			-- STILL FLYING IS NOT REJOINING: the rule fires on the step the flight ENDS.
			local air = Line.rejoinOrder(file("sow", "b", "c"), function(id)
				return id == "b"
			end, { b = true })
			expect(ids(air)).to.equal("sow,b,c")
			-- ...and an animal that never flew is never moved.
			local calm = Line.rejoinOrder(file("sow", "b", "c"), none, {})
			expect(ids(calm)).to.equal("sow,b,c")
		end)

```
