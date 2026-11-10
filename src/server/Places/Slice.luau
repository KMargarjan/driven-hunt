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
-- SINCE TASK 343 IT ALSO CARRIES THE CELL SWAP, in the two kinds `store` and `stand`: T7's own named
-- fallback, "a per-model move in `Slice` bites, with `Slice.ORDER` gaining store = 1, stand = 2".
-- A move is a single `Parent` write and costs a fifth of a plant, so it has its OWN budget row
-- (`MOVE_BUDGET_MS`) -- one number per kind of work, measured, never one number for both.
--
-- Design: docs/design/grid-map.md (section 8.3), docs/design/cell-loading.md (section 12, T7)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Forest = require(ReplicatedStorage:WaitForChild("ForestTest"))

local Slice = {}

-- HOW LONG ONE STEP MAY SPEND, in milliseconds. 10 models x 0.45 ms (M9 measured 200 models in
-- 0.09 s), which is design 8.3's own derivation.
Slice.BUDGET_MS = 4.5

-- ...AND HOW MANY ITEMS IT MAY TOUCH, whatever the clock says. The two together are what make a step
-- bounded even on a frame where the clock is lying to us.
Slice.MAX_PER_STEP = 10

-- A MOVE GETS ITS OWN BUDGET, AND THE NUMBER IS A READING (task 343). Measured in Karen's Forest
-- Test on main 6f1156e9: one whole-cell move of 3,141 models / 11,645 parts cost 400 ms by
-- `os.clock` and 738 ms of FRAME (the engine re-adds the parts after the write returns) -- so
-- 0.127 ms per model by the clock and 0.235 ms of frame. 12 ms of clock is therefore ~94 models and
-- ~22 ms of frame, a fifth of task 343's 100 ms worst-frame ceiling, and a 3,141-model half drains
-- in ~34 bites. `343-before-swap-*.txt` / `343-after-swap-*.txt` are both readings.
Slice.MOVE_BUDGET_MS = 12

-- ...AND ITS OWN ITEM CAP, for the frame where the clock lies: 200 x 0.235 ms = 47 ms, still inside
-- the ceiling. It is a guard and not the limiter -- the clock above is.
Slice.MOVE_MAX_PER_STEP = 200

-- THE QUEUE ORDER BY KIND. Lower runs first; the numbers are the whole of "destroy before plant"
-- and, since task 343, of "STORE BEFORE STAND" -- so the peak is one cell's parts and never two
-- (`cell-loading.md` 12, T7's fallback: "store = 1, stand = 2").
Slice.ORDER = table.freeze({ destroy = 1, store = 1, plant = 2, stand = 2 })

-- WHICH KINDS ARE A MOVE. One table, so "is this a move" has exactly one answer in this file.
Slice.MOVE_KINDS = table.freeze({ store = true, stand = true })

-- THE BUDGET AND THE CAP FOR ONE KIND. PURE.
function Slice.budgetFor(kind: string): number
	return if (Slice.MOVE_KINDS :: any)[kind] then Slice.MOVE_BUDGET_MS else Slice.BUDGET_MS
end

function Slice.maxFor(kind: string): number
	return if (Slice.MOVE_KINDS :: any)[kind] then Slice.MOVE_MAX_PER_STEP else Slice.MAX_PER_STEP
end

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
local function fresh()
	return {
		planted = 0,
		destroyed = 0,
		moved = 0,
		steps = 0,
		msTotal = 0,
		stepMsMax = 0,
		overBudgetStarts = 0,
		unbudgetedSteps = 0,
		seconds = 0,
		startedAt = nil :: number?,
	}
end
local counts = fresh()

-- START AGAIN FROM NOTHING. A spec calls it between cases; `Places.dressCell` calls it per dress, so
-- the counters it prints are that dress's own.
function Slice.reset()
	queue = {}
	counts = fresh()
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
--
-- `unbudgeted` SPENDS THE WHOLE JOB IN ONE STEP, and it is the deadline arm of the cell swap and
-- nothing else (task 343, `Cells.DRAIN_SECONDS`): a swap that has not drained in time must finish
-- before the horn, and a long frame with nobody at the stand beats a half-stood cell with a drive
-- running in it. It is COUNTED (`unbudgetedSteps`), so "the budget held" is a reading.
function Slice.step(now: number, unbudgeted: boolean?): (number, boolean)
	if #queue == 0 then
		return 0, true
	end
	if counts.startedAt == nil then
		counts.startedAt = now
	end
	local job = queue[1]
	local clock = job.context.clock or os.clock
	-- ONE BUDGET PER KIND OF WORK (task 343). A plant clones, rays and scales; a move is one
	-- `Parent` write and costs a fifth as much, measured -- see `MOVE_BUDGET_MS`.
	local budgetMs = Slice.budgetFor(job.kind)
	local maxPerStep = Slice.maxFor(job.kind)
	if unbudgeted then
		counts.unbudgetedSteps += 1
	end
	local spent = 0
	while job.at <= #job.items do
		if not unbudgeted then
			if spent >= maxPerStep then
				break
			end
			local elapsed = (clock() - now) * 1000
			if spent > 0 and elapsed >= budgetMs then
				break
			end
			-- THE ONLY ITEM THAT CAN EVER START PAST THE BUDGET IS A STEP'S FIRST, by the paragraph
			-- above. Counted rather than argued, so the allowance is a number in the report.
			if spent == 0 and elapsed >= budgetMs then
				counts.overBudgetStarts += 1
			end
		end
		local item = job.items[job.at]
		job.at += 1
		job.context.work(item)
		spent += 1
		if job.kind == "destroy" then
			counts.destroyed += 1
		elseif (Slice.MOVE_KINDS :: any)[job.kind] then
			counts.moved += 1
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
		moved = counts.moved,
		unbudgetedSteps = counts.unbudgetedSteps,
		steps = counts.steps,
		stepMsAvg = if counts.steps > 0 then counts.msTotal / counts.steps else 0,
		stepMsMax = counts.stepMsMax,
		overBudgetStarts = counts.overBudgetStarts,
		pending = Slice.pending(),
		seconds = counts.seconds,
	}
end

return Slice
