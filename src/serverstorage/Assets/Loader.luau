--!strict
-- Assets.Loader: THE ONE PLACE AN ASSET ID BECOMES AN INSTANCE (docs/design/asset-pipeline.md
-- section 5, and the owner row `GAME_DESIGN.md` gained in Task 73).
--
-- It is the only caller of `InsertService:LoadAsset` in `src/` outside the map generator, and when
-- `MapGen.Props` moves onto it (design section 6.8, `TASKS.md` row 74a) it will be the only one at
-- all. Nothing else may insert an asset: one caller means one script-refusal implementation, one
-- cache shape, and one place to look when a model does not appear.
--
--   InsertService:LoadAsset  https://create.roblox.com/docs/reference/engine/classes/InsertService
--     "Yields", and it needs the LoadOwnedAsset capability -- which is why this works at all: the
--     asset's creator (8167651842) is also the place's owner.
--
-- THE YIELD BOUNDARY IS THE WHOLE POINT OF TWO FUNCTIONS (design 5.2):
--   * `preload` YIELDS and hits the network. A boot script calls it, once.
--   * `template` NEVER yields. It returns the cached template or nil, and nil is not an error -- it
--     means "wear the grey box". `Hardware.give` must never yield (its own header says what a yield
--     in a grant path cost this project), so the thing it calls must not either.
--
-- A FAILURE NEVER BREAKS THE GAME (design 5.3). Every branch ends playable: no row, a refused
-- insert, a script inside the template, the wrong number of MeshParts -- all of them return nil with
-- a reason, and the consumer draws what it drew before.
--
-- ALL MUTABLE STATE IS IN ONE TABLE, AND THE TABLE IS INJECTABLE (`newState`, `getState`,
-- `setState`). That is not tidiness, it is the fix for a defect that survived two review rounds:
-- `clear()` used to walk a MODULE-LEVEL `templates` table, so a spec that cleared the loader
-- destroyed the live `shotgun.handle` the running server had preloaded -- whatever container that
-- spec had nominated for its own templates. Nominating a cache folder guarded the FOLDER and not the
-- templates inside the live one (review finding 3, found twice). With the state injectable, a spec
-- runs against a state of its own and `clear()` structurally cannot reach an entry it did not put
-- there; a load already in flight keeps the state it started in, so a late arrival cannot be parked
-- into a different one either.
--
-- Design: docs/design/asset-pipeline.md (sections 5, 6.1, 6.7)
local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")

local Assets = require(script.Parent)

local Loader = {}

Loader.CONFIG = table.freeze({
	CACHE_NAME = "AssetCache",
	-- The template's measured bounding box must match the row's `naturalSizeStuds` aspect within
	-- this, or the row is describing a different mesh than the one that arrived (design 6.1).
	ASPECT_TOLERANCE = 0.05,
	-- BOTH OF THESE EXIST BECAUSE A BOOT THAT WAITS ON THE NETWORK IS A GAME THAT DOES NOT START.
	-- Design 5.2: "preload is bounded by PRELOAD_BUDGET_S. Past it, boot CONTINUES with whatever
	-- loaded and warns. A boot that blocks on a moderation queue is a game that will not start."
	-- `LoadAsset` yields and has no documented rate limit, no documented timeout and no cancel, so
	-- the only bound available is to stop WAITING for it: the load runs in its own thread and this
	-- one gives up at the deadline with reason "timeout". The abandoned thread may still finish --
	-- if it does, `adopt` takes the template, so a slow load is late rather than lost.
	-- THE TWO NUMBERS ARE DESIGN SECTION 12'S TARGETS, 10 and 15, not numbers invented here. Round 2
	-- had the budget at 20, which is an undocumented deviation from a design this task is built to
	-- (review round 2, note).
	LOAD_TIMEOUT_S = 10, -- one key
	PRELOAD_BUDGET_S = 15, -- the whole call, however many keys
})

export type LoadReport = {
	key: string,
	version: number?,
	modelId: number?,
	ok: boolean,
	reason: string?, -- "no-row" | "insert-failed" | "contains-script" | "no-meshpart"
	-- | "multi-meshpart" | "aspect" | "timeout"
	route: string?,
	meshParts: number?,
	naturalSizeStuds: Vector3?,
	renderFidelity: string?,
	elapsedMs: number,
}

export type Counters = {
	requested: number,
	loaded: number,
	failed: number,
	refusedScripts: number,
	proxies: number,
}

-- EVERYTHING THE LOADER REMEMBERS, IN ONE VALUE. `createdCache` is the folder THIS state made for
-- itself, and it is the only folder `clear()` may destroy: "destroys only what it created" (rule 7)
-- is then a fact about the data rather than a claim in a comment.
export type State = {
	templates: { [string]: Instance },
	reports: { [string]: LoadReport },
	lastReasons: { [string]: string },
	counters: Counters,
	cacheParent: Instance?,
	createdCache: Instance?,
	insertFn: ((number) -> Instance?)?,
	preloadDeadline: number?,
}

-- A STATE NOTHING ELSE SHARES. A spec borrows the live one, runs against a fresh one, and puts the
-- live one back; production never calls this.
function Loader.newState(): State
	return {
		templates = {},
		reports = {},
		lastReasons = {},
		counters = { requested = 0, loaded = 0, failed = 0, refusedScripts = 0, proxies = 0 },
		cacheParent = nil,
		createdCache = nil,
		insertFn = nil,
		preloadDeadline = nil,
	}
end

local state: State = Loader.newState()

function Loader.getState(): State
	return state
end

-- Returns the state that WAS current, so a borrow-and-restore cannot forget which one was live:
-- `local live = Loader.setState(Loader.newState())` ... `Loader.setState(live)`.
function Loader.setState(nextState: State): State
	local previous = state
	state = nextState
	return previous
end

-- INJECTED, SO A SPEC CAN DRIVE BOTH PATHS WITH NO NETWORK. `nil` restores InsertService, which is
-- what production uses. This is the same shape `Weapon.setCast` and `Viewmodel.setSource` already
-- have, and it is what makes "the loaded mesh is used" and "a failure falls back" both testable.
function Loader.setInsert(fn: ((number) -> Instance?)?)
	state.insertFn = fn
end

function Loader.setCacheParent(container: Instance?)
	state.cacheParent = container
end

local function cache(self: State): Instance
	if self.cacheParent then
		return self.cacheParent
	end
	local existing = ServerStorage:FindFirstChild(Loader.CONFIG.CACHE_NAME)
	if existing then
		return existing
	end
	-- Created at RUN TIME only. ServerStorage is Rojo-owned with `$ignoreUnknownInstances: false`,
	-- so a folder parked here in Edit would be deleted at the next Connect (CLAUDE.md); a folder a
	-- running server makes for itself lives and dies with that server.
	local made = Instance.new("Folder")
	made.Name = Loader.CONFIG.CACHE_NAME
	made.Parent = ServerStorage
	self.createdCache = made
	return made
end

-- A FREE MODEL WITH A SCRIPT IN IT IS REFUSED, NOT STRIPPED (design 5.4, and `MapGen.Props` already
-- says the same). One surviving Script makes the harness's "no script outside Rojo-managed paths"
-- check fail every run from then on, and a stripped model is half-functional in ways nobody looks
-- for: the right answer is a different asset.
local function scriptIn(instance: Instance): string?
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("LuaSourceContainer") then
			return descendant:GetFullName()
		end
	end
	return nil
end

local function meshPartsIn(container: Instance): { MeshPart }
	local found = {}
	if container:IsA("MeshPart") then
		table.insert(found, container)
	end
	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:IsA("MeshPart") then
			table.insert(found, descendant)
		end
	end
	return found
end

local function aspectOf(size: Vector3): (number, number)
	-- SORT ALL THREE, do not try to remove "the longest one" by value. The first version dropped
	-- every axis EQUAL to the longest, so a cube (or any mesh whose two longest axes tie) came back
	-- as (0, thin) and failed the aspect check for arithmetic reasons rather than for shape --
	-- which is also why round 1's (100, 100, 100) test case passed (review round 1, note).
	local axes = { size.X, size.Y, size.Z }
	table.sort(axes, function(a, b)
		return a > b
	end)
	local longest = axes[1]
	if longest <= 0 then
		return 0, 0
	end
	return axes[2] / longest, axes[3] / longest
end

local function finish(self: State, report: LoadReport): LoadReport
	self.reports[report.key] = report
	if report.ok then
		self.counters.loaded += 1
	else
		self.counters.failed += 1
		self.lastReasons[report.key] = report.reason or "unknown"
	end
	return report
end

-- How much of the whole `preload` budget is left. Set by `preload`, so one slow key cannot eat the
-- budget of the keys behind it.
local function budgetLeft(self: State): number
	if self.preloadDeadline == nil then
		return Loader.CONFIG.LOAD_TIMEOUT_S
	end
	return math.max(self.preloadDeadline - os.clock(), 0)
end

-- A LATE ARRIVAL IS LATE, NOT LOST. If a load we stopped waiting for finishes afterwards and the
-- key is still empty, take it: the next Tool built wears the mesh instead of the grey box.
--
-- It takes the state the LOAD STARTED IN, never whatever is current when it lands. A spec's slow
-- fake returning after its case has ended must not park a fake mesh into the live server's cache and
-- hand it to a player (review round 2, note on `adopt`).
local function adopt(self: State, key: string, row, container: Instance)
	local parts = meshPartsIn(container)
	if row.kind == "meshpart" and #parts ~= 1 then
		container:Destroy()
		return
	end
	local template: Instance = if row.kind == "meshpart" then parts[1] else container
	template.Parent = cache(self)
	if template ~= container then
		container:Destroy()
	end
	self.templates[key] = template
	self.lastReasons[key] = "late"
end

-- ONE KEY. Yields, but never for longer than the budget. Caches the template on success.
local function loadOne(self: State, key: string): LoadReport
	local started = os.clock()
	self.counters.requested += 1
	local row = Assets.byKey(key)
	local function elapsed()
		return math.floor((os.clock() - started) * 1000)
	end
	if row == nil then
		return finish(self, { key = key, ok = false, reason = "no-row", elapsedMs = elapsed() })
	end
	local held = self.templates[key]
	if held and held.Parent then
		return self.reports[key]
			or finish(self, {
				key = key,
				ok = true,
				version = row.version,
				modelId = row.modelId,
				elapsedMs = elapsed(),
			})
	end

	local insert = self.insertFn
		or function(modelId: number): Instance?
			local ok, result = pcall(function()
				return InsertService:LoadAsset(modelId)
			end)
			return if ok then result else nil
		end

	-- THE WAIT IS BOUNDED, THE CALL IS NOT -- because it cannot be. `LoadAsset` yields and Roblox
	-- gives no way to cancel it, so the load runs in its own thread and THIS thread stops waiting at
	-- the deadline. Nothing is left half-applied: a late arrival is adopted below if the key is
	-- still empty, and otherwise destroyed.
	local done, container = false, nil :: Instance?
	task.spawn(function()
		local result = insert(row.modelId)
		if done then
			-- We already gave up on it. Take it if nothing else filled the slot; never leave an
			-- orphan Instance parented into the world.
			if result then
				if self.templates[key] == nil then
					adopt(self, key, row, result)
				else
					result:Destroy()
				end
			end
			return
		end
		container = result
		done = true
	end)

	local deadline = os.clock() + math.min(Loader.CONFIG.LOAD_TIMEOUT_S, budgetLeft(self))
	while not done and os.clock() < deadline do
		task.wait(0.05)
	end
	if not done then
		done = true -- tells the loader thread it is on its own
		return finish(self, {
			key = key,
			ok = false,
			reason = "timeout",
			version = row.version,
			modelId = row.modelId,
			route = "insert",
			elapsedMs = elapsed(),
		})
	end
	if container == nil then
		return finish(self, {
			key = key,
			ok = false,
			reason = "insert-failed",
			version = row.version,
			modelId = row.modelId,
			route = "insert",
			elapsedMs = elapsed(),
		})
	end

	local found = scriptIn(container)
	if found then
		container:Destroy()
		self.counters.refusedScripts += 1
		return finish(self, {
			key = key,
			ok = false,
			reason = "contains-script",
			version = row.version,
			modelId = row.modelId,
			route = "insert",
			elapsedMs = elapsed(),
		})
	end

	local parts = meshPartsIn(container)
	local template: Instance = container
	if row.kind == "meshpart" then
		-- ONE MESH PER KEY, DELIBERATELY (design 6.7): one Size write, one pivot, one texture and
		-- one thing to look at in a screenshot. Two is not "pick the biggest", it is a different
		-- asset than the row describes.
		if #parts == 0 then
			container:Destroy()
			return finish(self, {
				key = key,
				ok = false,
				reason = "no-meshpart",
				version = row.version,
				modelId = row.modelId,
				route = "insert",
				meshParts = 0,
				elapsedMs = elapsed(),
			})
		end
		if #parts > 1 then
			container:Destroy()
			return finish(self, {
				key = key,
				ok = false,
				reason = "multi-meshpart",
				version = row.version,
				modelId = row.modelId,
				route = "insert",
				meshParts = #parts,
				elapsedMs = elapsed(),
			})
		end
		template = parts[1]
		template.Parent = cache(self)
		container:Destroy() -- the Model wrapper LoadAsset returns is not the asset
	else
		container.Parent = cache(self)
	end

	-- THE ASPECT CHECK, which is what stops a squashed model measuring perfectly (design 6.1). It
	-- compares the template's OWN bounding box against the row's recorded natural size: if they
	-- disagree, the row is describing a different mesh than the one that arrived.
	local natural: Vector3? = nil
	if template:IsA("BasePart") then
		natural = template.Size
	elseif template:IsA("Model") then
		local _, size = template:GetBoundingBox()
		natural = size
	end
	if natural and row.naturalSizeStuds then
		local gotMid, gotThin = aspectOf(natural)
		local wantMid, wantThin = aspectOf(row.naturalSizeStuds)
		if
			math.abs(gotMid - wantMid) > Loader.CONFIG.ASPECT_TOLERANCE
			or math.abs(gotThin - wantThin) > Loader.CONFIG.ASPECT_TOLERANCE
		then
			template:Destroy()
			return finish(self, {
				key = key,
				ok = false,
				reason = "aspect",
				version = row.version,
				modelId = row.modelId,
				route = "insert",
				naturalSizeStuds = natural,
				elapsedMs = elapsed(),
			})
		end
	end

	self.templates[key] = template
	return finish(self, {
		key = key,
		ok = true,
		version = row.version,
		modelId = row.modelId,
		route = "insert",
		meshParts = #parts,
		naturalSizeStuds = natural,
		renderFidelity = if template:IsA("MeshPart") then tostring(template.RenderFidelity) else nil,
		elapsedMs = elapsed(),
	})
end

-- YIELDS, BUT NEVER PAST THE BUDGET. A boot script only, once per server.
--
-- Design 5.2: past `PRELOAD_BUDGET_S` boot CONTINUES with whatever loaded and warns. So the budget
-- is a deadline for the WHOLE call, and a key reached after it is refused as `timeout` without even
-- starting -- otherwise one stalled key would spend the budget of every key behind it.
--
-- The state is read ONCE, here, and carried through: a load in flight belongs to the state that
-- started it even if something else becomes current while it yields.
function Loader.preload(keys: { string }): { LoadReport }
	local self = state
	self.preloadDeadline = os.clock() + Loader.CONFIG.PRELOAD_BUDGET_S
	local out = {}
	for _, key in ipairs(keys) do
		table.insert(out, loadOne(self, key))
	end
	self.preloadDeadline = nil
	return out
end

-- NEVER YIELDS. nil means "use the grey box", and it is counted rather than logged into silence.
function Loader.template(key: string): (Instance?, LoadReport?)
	local template = state.templates[key]
	if template and template.Parent then
		return template, state.reports[key]
	end
	state.counters.proxies += 1
	return nil, state.reports[key]
end

function Loader.stats()
	return {
		requested = state.counters.requested,
		loaded = state.counters.loaded,
		failed = state.counters.failed,
		refusedScripts = state.counters.refusedScripts,
		proxies = state.counters.proxies,
		lastReasons = table.clone(state.lastReasons),
	}
end

-- Destroys ONLY WHAT THIS STATE PUT THERE (rule 7): the templates in this state's own table, and the
-- cache folder only if this state created it. It cannot reach another state's templates, because it
-- has no way to name them -- which is the structural half of review finding 3. A spec therefore runs
-- `Loader.setState(Loader.newState())` first, and the live server's preloaded mesh is untouchable.
function Loader.clear()
	local self = state
	for _, template in pairs(self.templates) do
		if template and template.Parent then
			template:Destroy()
		end
	end
	self.templates = {}
	self.reports = {}
	self.lastReasons = {}
	self.counters = { requested = 0, loaded = 0, failed = 0, refusedScripts = 0, proxies = 0 }
	local made = self.createdCache
	if made and made.Parent then
		made:Destroy()
	end
	self.createdCache = nil
end

return Loader
