--!strict
-- Slice: THE BUDGETED LOOP, AND NOTHING ELSE. It decides nothing -- the plan says what goes where,
-- `Places.plantOne` plants it, and this spends a frame budget (task 327c, design 8.3).
--
-- Pattern: MapGen's own step split -- "~3,000 Models in one step is one step that can time out and
-- tell you nothing about where it was" (`src/serverstorage/MapGen/init.luau`).
--
-- DESTROY RUNS BEFORE PLANT, AND THIS MODULE IS WHERE THAT IS TRUE: a `destroy` job is queued AHEAD
-- of every `plant` job whatever order the caller asked in, so the peak part count is one cell's and
-- never two (design 8.3's "whole cell destroyed, FIRST").
--
-- NEAREST THE HUNTER LINE FIRST (`Slice.order`), and that is a LOOK decision with a reason: the
-- hunter is put on his stand at `enterAssigning` and the picture fills outward from his feet, so what
-- he sees while it grows is the near belt and not a bald cell.
--
-- Design: docs/design/grid-map.md (section 8.3)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Forest = require(ReplicatedStorage:WaitForChild("ForestTest"))

local Slice = {}

-- HOW LONG ONE STEP MAY SPEND, in milliseconds. 10 models x 0.45 ms (M9 measured 200 models in
-- 0.09 s), which is design 8.3's own derivation.
Slice.BUDGET_MS = 4.5

-- ...AND HOW MANY ITEMS IT MAY TOUCH, whatever the clock says. The two together are what make a step
-- bounded even on a frame where the clock is lying to us.
Slice.MAX_PER_STEP = 10

-- THE QUEUE ORDER BY KIND. Lower runs first; the numbers are the whole of "destroy before plant".
Slice.ORDER = table.freeze({ destroy = 1, plant = 2 })

-- WHAT A JOB NEEDS FROM ITS CALLER. `work` is called once per item and does the Instance work;
-- `clock` is injected so a spec can drive the budget with a fake one (`os.clock` when nil).
export type Context = {
	work: (any) -> (),
	clock: (() -> number)?,
}

type Job = {
	kind: string,
	items: { any },
	at: number,
	context: Context,
}

local queue: { Job } = {}
local counts = {
	planted = 0,
	destroyed = 0,
	steps = 0,
	msTotal = 0,
	stepMsMax = 0,
	overBudgetStarts = 0,
	seconds = 0,
	startedAt = nil :: number?,
}

-- START AGAIN FROM NOTHING. A spec calls it between cases; `Places.dressCell` calls it per dress, so
-- the counters it prints are that dress's own.
function Slice.reset()
	queue = {}
	counts = {
		planted = 0,
		destroyed = 0,
		steps = 0,
		msTotal = 0,
		stepMsMax = 0,
		overBudgetStarts = 0,
		seconds = 0,
		startedAt = nil,
	}
end

-- NEAREST THE HUNTER LINE FIRST. PURE: a new list, ordered by |z - the line's own z at that x|, with
-- the original index as the tie-break so the order is total and the same every call (`table.sort` is
-- not stable, and a plan that is a pure function of a seed must not stop being one here).
function Slice.order(items: { any }, layout: any): { any }
	local keyed = {}
	for index, item in ipairs(items) do
		local lineZ = if layout ~= nil then Forest.roadZ(item.x, layout) else 0
		table.insert(keyed, { item = item, index = index, key = math.abs(item.z - lineZ) })
	end
	table.sort(keyed, function(a, b)
		if a.key == b.key then
			return a.index < b.index
		end
		return a.key < b.key
	end)
	local out = {}
	for _, row in ipairs(keyed) do
		table.insert(out, row.item)
	end
	return out
end

-- QUEUE ONE JOB. A `destroy` job jumps ahead of the first `plant` job in the queue -- see the header.
function Slice.begin(kind: string, items: { any }, context: Context)
	local job: Job = { kind = kind, items = items, at = 1, context = context }
	local rank = (Slice.ORDER :: any)[kind] or math.huge
	for index, other in ipairs(queue) do
		if ((Slice.ORDER :: any)[other.kind] or math.huge) > rank then
			table.insert(queue, index, job)
			return
		end
	end
	table.insert(queue, job)
end

-- HOW MANY ITEMS ARE STILL WAITING, across every queued job.
function Slice.pending(): number
	local left = 0
	for _, job in ipairs(queue) do
		left += #job.items - (job.at - 1)
	end
	return left
end

-- SPEND ONE FRAME. Returns (items done this step, whether the whole queue is finished).
--
-- `now` IS THE STEP'S OWN START, and the budget is re-read from the context's clock as items go in --
-- which is why `step` takes a number AND the context carries a clock: one call cannot time itself.
--
-- A STEP ALWAYS DOES AT LEAST ONE ITEM, said rather than implied: if the budget were checked before
-- the first one too, a frame that arrived already late would do nothing at all and the queue would
-- never drain. So a step can overrun by exactly one item's cost, and `overBudgetStarts` counts the
-- items that were BEGUN past the budget -- which must stay 0.
function Slice.step(now: number): (number, boolean)
	if #queue == 0 then
		return 0, true
	end
	if counts.startedAt == nil then
		counts.startedAt = now
	end
	local job = queue[1]
	local clock = job.context.clock or os.clock
	local spent = 0
	while job.at <= #job.items do
		if spent >= Slice.MAX_PER_STEP then
			break
		end
		local elapsed = (clock() - now) * 1000
		if spent > 0 and elapsed >= Slice.BUDGET_MS then
			break
		end
		-- THE ONLY ITEM THAT CAN EVER START PAST THE BUDGET IS A STEP'S FIRST, by the paragraph above.
		-- Counted rather than argued, so the allowance is a number in the report.
		if spent == 0 and elapsed >= Slice.BUDGET_MS then
			counts.overBudgetStarts += 1
		end
		local item = job.items[job.at]
		job.at += 1
		job.context.work(item)
		spent += 1
		if job.kind == "destroy" then
			counts.destroyed += 1
		else
			counts.planted += 1
		end
	end
	if job.at > #job.items then
		table.remove(queue, 1)
	end
	local took = (clock() - now) * 1000
	counts.steps += 1
	counts.msTotal += took
	counts.stepMsMax = math.max(counts.stepMsMax, took)
	counts.seconds = clock() - (counts.startedAt or now)
	return spent, #queue == 0
end

-- WHAT IT SPENT. `stepMsAvg` / `stepMsMax` are `src/server/Bots/init.luau`'s own two counters,
-- borrowed by name (rule 2) -- because a budget nobody measures is a hope.
function Slice.stats(): { [string]: any }
	return {
		planted = counts.planted,
		destroyed = counts.destroyed,
		steps = counts.steps,
		stepMsAvg = if counts.steps > 0 then counts.msTotal / counts.steps else 0,
		stepMsMax = counts.stepMsMax,
		overBudgetStarts = counts.overBudgetStarts,
		pending = Slice.pending(),
		seconds = counts.seconds,
	}
end

return Slice
