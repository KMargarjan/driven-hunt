--!strict
-- Places.Cells: ONE CELL STANDS, EVERY OTHER PLANTED CELL IS STORED, and this module is the only
-- thing in the repository that MOVES a cell folder between its home and the store.
-- (`Places.dressCell` parents the folder it creates; same owner, different verb.)
--
-- Karen, 2026-11-08: *"so we will need to optimize, we only load one per game thats it"*.
--
-- IT MAKES AND DESTROYS NO WOOD. `Places.dressCell` makes and destroys models in its own cell's
-- folder; this MOVES a cell's models between `Workspace.<home>` and `ServerStorage.GridWood`.
-- The split is by VERB, which is the shape `Places.Ground` and `Places.Slice` already have. The one
-- thing it does create is the cell's own empty folder SHELL on the receiving side, and the one thing
-- it destroys is the emptied shell it left behind -- which is the price of the slice below.
--
-- SINCE TASK 343 THE MOVE IS SLICED, PER MODEL, THROUGH `Slice` -- `cell-loading.md` 12's own named
-- fallback for T7, taken because the whole-folder write measured 738 ms of frame against T7's 500 ms
-- (337c, and `343-before-swap-*.txt`). `begin` queues and moves nothing; `spend` is one bite;
-- `reconcile` is begin-then-drain and is what the boot and the specs call. STORE IS QUEUED BEFORE
-- STAND (`Slice.ORDER`), so the peak is one cell's parts plus one bite and never two cells.
--
-- LEVEL-TRIGGERED, NEVER EDGE-TRIGGERED (lesson L-029). `reconcile` compares what stands against the
-- one cell that should, and corrects the difference. A keep set computed per call is what let task
-- 335 fell a stored forest; a reconciliation cannot.
--
-- Design: docs/design/cell-loading.md (2, 4, 5, 9)
-- Note:   docs/research/2026-11-08-one-cell-at-a-time.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Grid = require(ReplicatedStorage:WaitForChild("Grid"))
-- `Cells` REQUIRES `Places`; `Places` NEVER REQUIRES `Cells` (design 2). `tools/terrainbake.py`
-- rewrites every `require` line in `Places/init.luau` for its Edit injection and its selftest
-- asserts each rewrite matches once -- a require pointing the other way would hang that call.
local Places = require(ServerScriptService:WaitForChild("Places"))
-- THE BUDGETED LOOP THE SWAP IS SLICED THROUGH (task 343). `Slice` requires nothing of this module.
local Slice = require(ServerScriptService:WaitForChild("Places"):WaitForChild("Slice"))

local Cells = {}

-- WHERE A CELL'S WOOD WAITS. A child of `ServerStorage`, which Roblox documents as "Not Replicated":
-- on the server, addressable, reaching no client, not rendered, not in `Workspace`'s queries.
--   https://create.roblox.com/docs/reference/engine/classes/ServerStorage
Cells.STORE_NAME = "GridWood"

-- WHICH `Workspace` FOLDER A STORED CELL CAME OUT OF, so it goes back where it was.
Cells.HOME_ATTRIBUTE = "WoodHome"

-- THE TWO FOLDERS A CELL'S WOOD CAN STAND IN, read off the planter and never written as literals:
-- "is C1 standing" must have exactly one answer.
Cells.HOMES = table.freeze({ Places.FOREST_FOLDER, Places.GRID_FOLDER })

-- HOW LONG THE SWAP MAY STAY BUDGETED. Past it the rest of the queue is finished in ONE step
-- (`Slice.step(now, true)`), because the drive must not start on a half-stood cell:
-- `Match.CONFIG.INTERMISSION_SECONDS` is 5, the drain measures ~1 s, and 3 s leaves 2 s of margin
-- before the horn. The arm is COUNTED (`unbudgetedSteps`), never assumed.
Cells.DRAIN_SECONDS = 3

export type Wood = {
	cell: string,
	home: string,
	folder: Instance,
	models: number,
}

export type Plan = {
	want: string?,
	keep: Wood?,
	stand: Wood?,
	store: { Wood },
	anomalies: { string },
	reason: string?,
}

export type Report = {
	want: string?,
	stood: string?,
	stoodModels: number,
	storedCells: number,
	storedModels: number,
	moved: number,
	-- HOW MANY MODELS WENT WITH THOSE CELLS (task 343). `moved` counts CELLS and always has;
	-- the slice moves models, so the two numbers are both printed and neither is renamed.
	models: number,
	ms: number,
	-- THE SLICE'S OWN THREE NUMBERS (task 343): how many bites it took, how long the drain ran, and
	-- whether the deadline arm had to fire. A budget nobody measures is a hope (`Slice.stats`).
	bites: number,
	seconds: number,
	unbudgetedSteps: number,
	pending: number,
	anomalies: { string },
	reason: string?,
}

-- ---------------------------------------------------------------- pure

-- WHICH CELL SHOULD BE STANDING, from the live layout's name. PURE.
--
-- THE FALLBACK IS WHAT MAKES THIS CHANGE INVISIBLE TODAY (design 5.1): `chosen.name` starts at
-- `road` and the rotation still deals the four line places, so without it the first boot would store
-- C1 and Karen's forest would leave the world she plays. When `ForestTest.LAYOUT_ORDER` becomes the
-- eight cell ids the fallback is unreachable, and `grid.spec` asserts that rather than assuming it.
function Cells.wantedCell(layoutName: string?): string
	if type(layoutName) == "string" and Grid.cellOf(layoutName :: string) ~= nil then
		return layoutName :: string
	end
	return Grid.DEFAULT_CELL
end

-- IS THIS THE HOME A CELL'S OWN WOOD BELONGS IN WHEN TWO STAND? `FOREST_FOLDER` is Karen's Edit-time
-- wood and is irreplaceable; a `GRID_FOLDER` cell is reproducible from its seed and that folder is
-- destroyed at every boot anyway (`grid-map.md` 11.3 step 2).
local function prefers(a: Wood, b: Wood): boolean
	if a.home == b.home then
		return false
	end
	return a.home == Places.FOREST_FOLDER
end

-- WHAT TO MOVE. PURE: two lists and a string in, a plan out -- so every branch below is reachable
-- from a spec with no world at all.
function Cells.plan(standing: { Wood }, stored: { Wood }, want: string?): Plan
	local out: Plan = { want = want, keep = nil, stand = nil, store = {}, anomalies = {} }
	if type(want) ~= "string" or Grid.cellOf(want :: string) == nil then
		-- A NIL MUST NOT EMPTY THE WORLD. Defensive only: `wantedCell` always answers a cell.
		out.reason = "no-cell"
		return out
	end
	-- WHAT IS ALREADY IN THE STORE, by (cell, home), so a collision is seen rather than created.
	local held: { [string]: Wood } = {}
	for _, wood in ipairs(stored) do
		local key = wood.cell .. "/" .. wood.home
		if held[key] ~= nil then
			table.insert(out.anomalies, string.format("%s is stored twice under %s", wood.cell, wood.home))
		else
			held[key] = wood
		end
	end
	for _, wood in ipairs(standing) do
		if wood.cell ~= want then
			-- A STORE COLLISION IS LOUD AND NEVER SILENTLY RESOLVED: two folders for one (cell, home)
			-- means two writers. Leave the standing one alone and say so.
			if held[wood.cell .. "/" .. wood.home] ~= nil then
				table.insert(
					out.anomalies,
					string.format("%s stands in %s and is ALSO in the store; left standing", wood.cell, wood.home)
				)
			else
				table.insert(out.store, wood)
			end
		elseif out.keep == nil then
			out.keep = wood
		else
			-- TWO FOLDERS FOR THE WANTED CELL, one per home. Keep the irreplaceable one standing.
			local loser = out.keep :: Wood
			if prefers(wood, loser) then
				out.keep = wood
			else
				loser = wood
			end
			table.insert(out.store, loser)
			table.insert(
				out.anomalies,
				string.format(
					"%s stands in both %s and %s; kept %s, stored %s",
					want :: string,
					Places.FOREST_FOLDER,
					Places.GRID_FOLDER,
					(out.keep :: Wood).home,
					loser.home
				)
			)
		end
	end
	if out.keep ~= nil then
		return out
	end
	for _, wood in ipairs(stored) do
		if wood.cell == want then
			out.stand = wood
			return out
		end
	end
	-- A CELL WITH NO WOOD IS A FACT TO REPORT, NOT TO PLANT: wood is made at Edit time by
	-- `tools/terrainbake.py plant`. Every OTHER cell is still stored, so the world is left holding
	-- no cell folder at all -- which is target T1 at its extreme, and is what design 15 step 2 asks
	-- a live run to show.
	out.reason = "missing"
	return out
end

-- ---------------------------------------------------------------- read-only

-- EDIT TIME IS `IsStudio() AND NOT IsRunning()` -- the predicate borrowed by name from
-- `src/serverstorage/MapGen/Contract.luau` (rule 2).
--   https://create.roblox.com/docs/reference/engine/classes/RunService#IsRunning
function Cells.editTime(): boolean
	return RunService:IsStudio() and not RunService:IsRunning()
end

local function woodOf(folder: Instance, home: string): Wood
	return { cell = folder.Name, home = home, folder = folder, models = #folder:GetChildren() }
end

-- EVERY CELL FOLDER STANDING IN THE WORLD, over BOTH homes.
function Cells.standing(world: Instance?): { Wood }
	local root = world or Workspace
	local out: { Wood } = {}
	for _, home in ipairs(Cells.HOMES) do
		local folder = root:FindFirstChild(home)
		if folder then
			-- `Places.cellWoodFolders` IS THE ONE RULE for "a child that is a cell's wood", so a
			-- stake or any other child is not touched here either.
			for _, child in ipairs(Places.cellWoodFolders(folder)) do
				table.insert(out, woodOf(child, home))
			end
		end
	end
	return out
end

-- EVERY CELL FOLDER WAITING IN THE STORE. A stored folder carries the home it came out of; a folder
-- with no stamp is treated as the prebuild's, which is where every cell in this world starts.
function Cells.stored(store: Instance?): { Wood }
	local root = store or ServerStorage
	local out: { Wood } = {}
	local folder = root:FindFirstChild(Cells.STORE_NAME)
	if folder == nil then
		return out
	end
	for _, child in ipairs(Places.cellWoodFolders(folder)) do
		local home = child:GetAttribute(Cells.HOME_ATTRIBUTE)
		table.insert(out, woodOf(child, if type(home) == "string" then home :: string else Places.FOREST_FOLDER))
	end
	return out
end

-- IS THIS CELL'S WOOD IN `Workspace` NOW? **The LIVE fact**, read off the world and never off
-- `Grid.PLANTED_CELLS` -- which is the whole of lesson L-093. The STATIC fact ("a wood exists for
-- this cell somewhere") is `Places.hasOwnWood` in the shared plan, and the two must not be confused:
-- the plan is a pure function of (cell, seed) and may not read the world.
function Cells.isStanding(cellId: string?, world: Instance?): boolean
	if type(cellId) ~= "string" then
		return false
	end
	for _, wood in ipairs(Cells.standing(world)) do
		if wood.cell == cellId then
			return true
		end
	end
	return false
end

-- ---------------------------------------------------------------- the one writer

-- THE ONE SWAP IN FLIGHT. Module state, because a bite is a call and the queue outlives it; there is
-- never more than one, since `begin` refuses while one is pending. `Cells.reset()` drops it.
type Flight = {
	want: string,
	storeRoot: Instance,
	report: Report,
	startedAt: number,
	-- THE EMPTIED SHELLS, destroyed when the queue drains. An empty folder left standing would make
	-- `Cells.standing` answer "this cell stands" with no wood in it, so this is not tidying.
	tidy: { Instance },
}
local flight: Flight? = nil

local function emptyReport(want: string?): Report
	return {
		want = want,
		stood = nil,
		stoodModels = 0,
		storedCells = 0,
		storedModels = 0,
		moved = 0,
		models = 0,
		ms = 0,
		bites = 0,
		seconds = 0,
		unbudgetedSteps = 0,
		pending = 0,
		anomalies = {},
	}
end

local function ensure(parent: Instance, name: string): Instance
	local found = parent:FindFirstChild(name)
	if found then
		return found
	end
	local made = Instance.new("Folder")
	made.Name = name
	made.Parent = parent
	return made
end

-- THE RECEIVING SHELL FOR ONE CELL'S MODELS, carrying every attribute the shell it replaces had, so
-- a move stays attribute-preserving whatever a later task stamps on a cell folder.
local function shellFor(parent: Instance, from: Instance, home: string): Instance
	local made = Instance.new("Folder")
	made.Name = from.Name
	for key, value in pairs(from:GetAttributes()) do
		made:SetAttribute(key, value)
	end
	made:SetAttribute(Cells.HOME_ATTRIBUTE, home)
	made.Parent = parent
	return made
end

-- HOW MANY MODELS THE SWAP IN FLIGHT HAS LEFT TO MOVE; 0 when none is running.
function Cells.pending(): number
	return if flight == nil then 0 else Slice.pending()
end

-- HOW LONG THE SWAP IN FLIGHT HAS BEEN RUNNING, in seconds; 0 when none is.
function Cells.elapsed(now: number): number
	local one = flight
	return if one == nil then 0 else now - one.startedAt
end

-- DROP THE SWAP IN FLIGHT. A spec calls it between cases.
function Cells.reset()
	flight = nil
	Slice.reset()
end

local function finish(
	storeRoot: Instance,
	report: Report,
	tidy: { Instance },
	tick: () -> number,
	started: number
): Report
	for _, shell in ipairs(tidy) do
		-- EMPTY BY CONSTRUCTION: its children were the job's items. Checked anyway, because an empty
		-- folder destroyed is tidying and a full one destroyed is Karen's wood.
		if #shell:GetChildren() == 0 then
			shell:Destroy()
		else
			table.insert(report.anomalies, string.format("%s's shell was not empty; left standing", shell.Name))
		end
	end
	local stats = Slice.stats()
	report.models = stats.moved
	report.bites = stats.steps
	report.unbudgetedSteps = stats.unbudgetedSteps
	report.seconds = stats.seconds
	report.pending = 0
	report.storedCells = 0
	report.storedModels = 0
	for _, wood in ipairs(Cells.stored(storeRoot)) do
		report.storedCells += 1
		report.storedModels += wood.models
	end
	report.ms = (tick() - started) * 1000
	return report
end

-- QUEUE THE SWAP THE WORLD NEEDS, AND MOVE NOTHING (task 343). **IT DOES NOT YIELD AND IT MOVES NO
-- MODEL**, which is what lets the `markers` closure call it: that closure runs inside `Match`'s
-- `dispatch`, whose own contract is *"it MUST NOT YIELD"* (`Match.measureMarkers`).
--
-- IT REFUSES AT EDIT TIME, and that refusal is not caution (design 4.3): `default.project.json` maps
-- ALL of `ServerStorage` to `src/serverstorage` with Rojo's default `$ignoreUnknownInstances: false`,
-- so a store created in Edit would be DELETED at the next Connect -- and 9,318 parts of Karen's wood
-- with it. https://rojo.space/docs/v7/project-format/
function Cells.begin(
	want: string?,
	world: Instance?,
	store: Instance?,
	clock: (() -> number)?,
	-- BOTH ARMS BY PARAMETER, so a spec reaches the refusal without being in Edit.
	isEdit: boolean?
): Report
	local tick = clock or os.clock
	local started = tick()
	local report = emptyReport(want)
	if if isEdit == nil then Cells.editTime() else isEdit then
		report.reason = "edit-time"
		return report
	end
	-- ONE SWAP AT A TIME. A second `begin` while one is in flight would queue a second answer to
	-- which cell stands, which is two writers of one fact (rule 3). The level-triggered caller asks
	-- again next frame, and by then this one has drained.
	if flight ~= nil then
		report.reason = "in-flight"
		report.pending = Slice.pending()
		return report
	end
	local root = world or Workspace
	local storeRoot = store or ServerStorage
	local plan = Cells.plan(Cells.standing(root), Cells.stored(storeRoot), want)
	report.anomalies = plan.anomalies
	report.reason = plan.reason
	if plan.reason == "no-cell" then
		return report
	end
	-- NOTHING IS CREATED UNLESS SOMETHING MOVES. A no-op reconcile is two `FindFirstChild`s and a
	-- list compare, and it writes nothing at all (target T8).
	local queued = #plan.store + (if plan.stand ~= nil then 1 else 0)
	if queued == 0 then
		if plan.keep ~= nil then
			report.stood = (plan.keep :: Wood).cell
			report.stoodModels = (plan.keep :: Wood).models
		end
		Slice.reset()
		return finish(storeRoot, report, {}, tick, started)
	end
	Slice.reset()
	local tidy: { Instance } = {}
	-- STORE FIRST, THEN STAND -- and `Slice.ORDER` is where that is true rather than this loop's
	-- order (`store = 1, stand = 2`): the peak number of cell parts in `Workspace` is one cell's
	-- plus one bite's, never two cells'.
	for _, wood in ipairs(plan.store) do
		local shelf = ensure(storeRoot, Cells.STORE_NAME)
		local into: Instance? = nil
		Slice.begin("store", wood.folder:GetChildren(), {
			clock = tick,
			work = function(model: Instance)
				if into == nil then
					into = shellFor(shelf, wood.folder, wood.home)
				end
				model.Parent = into
			end,
		})
		table.insert(tidy, wood.folder)
	end
	if plan.stand ~= nil then
		local wood = plan.stand :: Wood
		local home = ensure(root, wood.home)
		local into: Instance? = nil
		Slice.begin("stand", wood.folder:GetChildren(), {
			clock = tick,
			work = function(model: Instance)
				if into == nil then
					into = shellFor(home, wood.folder, wood.home)
				end
				model.Parent = into
			end,
		})
		table.insert(tidy, wood.folder)
		report.stood = wood.cell
		report.stoodModels = wood.models
	elseif plan.keep ~= nil then
		report.stood = (plan.keep :: Wood).cell
		report.stoodModels = (plan.keep :: Wood).models
	end
	report.moved = queued
	report.pending = Slice.pending()
	flight = {
		want = want :: string,
		storeRoot = storeRoot,
		report = report,
		startedAt = started,
		tidy = tidy,
	}
	return report
end

-- SPEND ONE BITE OF THE SWAP IN FLIGHT. Returns (models moved this bite, whether it is finished, the
-- finished report or nil). **IT DOES NOT YIELD**: the caller owns the frame boundary, exactly as
-- `Places.dressCell`'s loop does.
--
-- `unbudgeted` FINISHES THE QUEUE IN THIS ONE CALL. The caller passes it once the drain has run past
-- `Cells.DRAIN_SECONDS`, so a swap that is somehow slow still cannot bleed into the drive.
function Cells.spend(now: number, unbudgeted: boolean?, clock: (() -> number)?): (number, boolean, Report?)
	local one = flight
	if one == nil then
		return 0, true, nil
	end
	local tick = clock or os.clock
	local spent, finished = Slice.step(now, unbudgeted)
	if unbudgeted then
		-- ONE CALL, WHATEVER IS LEFT: `Slice.step` drains one JOB per call, and a swap has at most
		-- one `store` job per standing cell plus one `stand`.
		local guard = 0
		while not finished and guard < 16 do
			local more: number
			more, finished = Slice.step(tick(), true)
			spent += more
			guard += 1
		end
	end
	one.report.pending = Slice.pending()
	if not finished then
		return spent, false, nil
	end
	flight = nil
	return spent, true, finish(one.storeRoot, one.report, one.tidy, tick, one.startedAt)
end

-- MAKE THE WORLD HOLD THE CELL IT SHOULD, AND NOTHING ELSE, DRIVING THE SWAP TO ITS END. Returns
-- what it found and what it moved. The BOOT and the specs call this; the drive boundary calls
-- `begin` and lets the composition root's Heartbeat spend the bites, because it may not yield there.
--
-- `breathe` IS THE FRAME BOUNDARY AND IT IS THE CALLER'S (`Places.dressCell`'s own shape): with it,
-- one bite per frame; without it, a tight loop, which is what a spec with a fake clock wants.
function Cells.reconcile(
	want: string?,
	world: Instance?,
	store: Instance?,
	clock: (() -> number)?,
	isEdit: boolean?,
	breathe: (() -> ())?
): Report
	local tick = clock or os.clock
	local report = Cells.begin(want, world, store, clock, isEdit)
	if flight == nil then
		return report
	end
	-- A HARD BITE CEILING SO A BROKEN `work` CANNOT SPIN FOR EVER: every bite does at least one
	-- model, so the queue cannot need more bites than it has models.
	local ceiling = report.pending + 4
	local bites = 0
	local done = false
	local final: Report? = nil
	while not done and bites < ceiling do
		local _, finished, out = Cells.spend(tick(), false, clock)
		done = finished
		final = out or final
		bites += 1
		if breathe ~= nil and not done then
			breathe()
		end
	end
	if flight ~= nil then
		-- THE CEILING WAS HIT: finish it rather than leave a half-stood cell behind.
		local _, _, out = Cells.spend(tick(), true, clock)
		final = out or final
	end
	return final or report
end

-- THE CONSOLE LINE, OR NIL WHEN NOTHING HAPPENED. A print every drive that said nothing had changed
-- would bury the one that did (`ForestTest.layoutForDrive`'s own rule).
function Cells.line(report: Report): string?
	if report.moved == 0 and report.bites == 0 and report.reason == nil and #report.anomalies == 0 then
		return nil
	end
	local head = if report.reason == "missing"
		then string.format(
			"[Places.Cells] want=%s: MISSING -- no wood standing and none stored "
				.. "(plant it: tools/terrainbake.py plant --cells %s)",
			tostring(report.want),
			tostring(report.want)
		)
		elseif report.reason ~= nil then string.format(
			"[Places.Cells] want=%s: %s",
			tostring(report.want),
			tostring(report.reason)
		)
		else string.format(
			"[Places.Cells] want=%s stood=%s (%d models) stored=%d cell(s)/%d models moved=%d cell(s)"
				.. "/%d model(s) in %.0f ms over %d bite(s) / %.2f s (unbudgeted=%d)",
			tostring(report.want),
			tostring(report.stood),
			report.stoodModels,
			report.storedCells,
			report.storedModels,
			report.moved,
			report.models,
			report.ms,
			report.bites,
			report.seconds,
			report.unbudgetedSteps
		)
	if #report.anomalies == 0 then
		return head
	end
	return head .. " | ANOMALY: " .. table.concat(report.anomalies, "; ")
end

return Cells
