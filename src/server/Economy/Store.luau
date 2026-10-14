--!strict
-- Economy.Store: THE ONLY THING IN THIS REPOSITORY THAT MAY REACH `DataStoreService`, and the only
-- place that requires ProfileStore. One narrow interface, two implementations behind it.
--
-- THE SAVE LAYER IS BORROWED WHOLE AND NONE OF IT IS WRITTEN HERE. ProfileStore 1.0.3
-- (MadStudioRoblox, Apache-2.0, pinned through Wally as `lm-loleris/profilestore@1.0.3`,
-- ServerStorage.ServerPackages.ProfileStore) is *"a periodic DataStore saving solution with session
-- locking"*: it *"prevents other game servers from accessing this data too soon by establishing a
-- session lock"*. There is no retry loop here, no backoff, no `UpdateAsync` and no auto-save of
-- ours, because all four are its job and Roblox's own best-practice page says so in the same words:
-- *"Load a player's data at the start of a session and keep a server-local copy for gameplay. Update
-- the local copy instead of sending a data store request for every change."*
--   ProfileStore    https://github.com/MadStudioRoblox/ProfileStore (Apache-2.0)
--   API             https://madstudioroblox.github.io/ProfileStore/api/
--   data stores     https://create.roblox.com/docs/cloud-services/data-stores
--   limits          https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits
--   best practices  https://create.roblox.com/docs/cloud-services/data-stores/best-practices
--
-- TWO THINGS ABOUT THE LIBRARY WERE FOUND BY READING ITS SHIPPED SOURCE AND BOTH SHAPE THIS FILE
-- (note section 2.1):
--   1. IT DOES NOT FALL BACK TO A MOCK BY ITSELF. In Studio it probes API access, sets
--      `ProfileStore.DataStoreState` and prints *"Roblox API services unavailable - data will not be
--      saved"*, then carries on using the REAL store. Switching is the caller's job, and its own
--      docs say so in one line: *"if RunService:IsStudio() == true then PlayerStore =
--      PlayerStore.Mock end"*.
--   2. THAT PROBE IS A REAL WRITE: `DataStoreService:GetDataStore("____PS"):SetAsync("____PS",
--      os.time())`, fired by a `task.spawn` at require time. So requiring the module in a Studio
--      session that HAS *Enable Studio Access to API Services* on writes a live key as a side effect
--      of the require. THAT is why the require below is INSIDE `Store.live`'s body and not at the
--      top of this file: a harness run must never perform it, and in Studio nothing ever calls
--      `Store.live`.
--
-- `ProfileStore.Mock` IS NOT USED. It is the library's own code path against a different table
-- (`Mock.StartSessionAsync` sets a one-shot flag and calls the real method), so it proves nothing
-- `Store.memory` does not -- and reaching it still means requiring the library in Studio, which
-- item 2 forbids.
--
-- Design: docs/design/economy.md (sections 4.2, 9)
-- Note:   docs/research/2026-10-13-coins-persistence.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- For `deepFreeze` only, and the reason it is needed at all is hazard 1 (design section 8.2a):
-- `Store.TEMPLATE` now holds a TABLE, and a template whose table could be written into would be
-- one `owned` set shared by every player on the server and on the next one.
local Drive = require(ReplicatedStorage:WaitForChild("Drive"))

local Store = {}

-- HOW LONG `Store.live` WAITS FOR THE PACKAGE TREE before it says so out loud. The tree is an
-- OPTIONAL Rojo path, so "it is not there" is a real state a build can be in, and an unbounded wait
-- inside `Economy.start` would hang the whole server boot rather than report it (round 1 note 2).
local WAIT_FOR_LIBRARY_SECONDS = 10

export type Store = {
	kind: string, -- "memory" | "live"
	-- YIELDS. THE WHOLE PROFILE through `Store.read`, or nil for NO SESSION plus the REASON --
	-- "refused" (another server holds the lock) or "error" (the call itself threw). The owner treats
	-- them the same (no session means no earning and no saving) and COUNTS THEM APART, because one is
	-- another player's server and the other is Roblox being down, and a report that cannot tell them
	-- apart cannot be acted on.
	--
	-- IT ANSWERED JUST THE BALANCE UNTIL TASK 178, and widening it was forced (design section 8.2b):
	-- a profile is ONE TABLE (ProfileStore's own model), the projection belongs to the owner that
	-- knows which fields it wants, and the owner now wants three of them.
	load: (userId: number) -> ({ [string]: any }?, string?),
	-- Writes EXACTLY THE NAMED FIELDS of the local copy and performs NO network call. ProfileStore's
	-- own auto-save and its `EndSession` do the writing (see the header). `false` when there is no
	-- session.
	--
	-- IT DERIVES NOTHING, and that too was forced (design section 8.2b, hazard 2): both
	-- implementations used to do `data.drivesPaid += 1` on every call, which was correct while
	-- `payDrive` was the only caller and became a BUG the moment a purchase called `save` -- buying a
	-- hat would have counted as a completed hunt. The increments live in `Economy.payDrive` now,
	-- which is where the delta and the event are both known, so "who increments this" has one answer.
	save: (userId: number, fields: { [string]: any }) -> boolean,
	-- Ends the session, which saves. Idempotent: a second call answers `false`.
	release: (userId: number) -> boolean,
	-- YIELDS. Shutdown only. How many sessions it ended.
	releaseAll: () -> number,
	-- One setter, one handler: how `Profile.OnSessionEnd` reaches the owner.
	setOnLost: (handler: (userId: number) -> ()) -> (),
	-- How many calls this store has made, by name. The memory store's own report, so a spec can
	-- assert that a pay-out performs NO store call at all.
	calls: () -> { [string]: number },
	-- MEMORY ONLY, and absent on the live store. It is how a spec drives OUR reaction to
	-- `Profile.OnSessionEnd` -- the one case that cannot be reproduced here, because one Studio
	-- session is one server, so a real session steal needs a second one.
	loseSession: ((userId: number) -> ())?,
	-- MEMORY ONLY: what is in the saved key, so a spec can prove a round trip without opening a
	-- second session. Absent on the live store, where the profile IS the local copy.
	peek: ((userId: number) -> { [string]: any })?,
}

-- THE PROFILE'S SHAPE. One table, four numbers, and a `schema` that is READ and never acted on in
-- this task -- it is the number a later migration branches on, and branching on it now would be a
-- migration with nothing to migrate.
--
-- `coinsEarnedTotal` is the one number SPENDING destroys and cannot rebuild, which is why it is here
-- before there is anything to spend on. `drivesPaid` is the double-pay forensic: if a balance ever
-- looks wrong, "how many drives was he paid for" is the first question.
Store.TEMPLATE = {
	schema = 1,
	coins = 0,
	coinsEarnedTotal = 0,
	-- THE COMPLETED-HUNT COUNT, AND THE DOUBLE-PAY FORENSIC, AND THEY ARE THE SAME NUMBER BY
	-- CONSTRUCTION (task 178, design section 8.3). It rises once per player per PAID drive, and
	-- `Coins.forDrive` skips a row that `left` -- *"`PARTICIPATION` is ... for turning up AND
	-- FINISHING the drive"* -- so "drives he finished and was paid for" is what the shop's unlocks
	-- mean by "completed hunts".
	--
	-- A SECOND `hunts` FIELD WAS REFUSED, with the reason written down: it would be incremented by
	-- the same line on the same event, so the two could only ever hold the same number, and two
	-- names for one fact is this project's named failure mode. The key is not renamed either --
	-- renaming a persisted key under one store name orphans the old one and restarts everybody at 0
	-- -- so the one reader outside this file is the accessor `Economy.huntsOf`.
	drivesPaid = 0,
	-- WHAT HE HAS BOUGHT: itemId -> true, a PURE DICTIONARY of string keys (task 178). ioquake3's
	-- `ps->stats[STAT_WEAPONS] |= 1 << weapon` read as a Luau table: ownership is a SET, and nothing
	-- per-player is stored about a weapon except its id.
	--
	-- ADDITIVE, so `STORE_NAME` does not go to `_v2`: an older build keeps this key untouched
	-- (`Store.read`'s keep-unknown half) and a newer one fills it (its fill-missing half).
	owned = {},
}

-- FROZEN, AND IT IS HAZARD 1 (design section 8.2a). With a TABLE in the template, `Store.read`'s
-- fill-missing half used to hand every profile THE SAME TABLE -- the first purchase would have
-- written into the template itself, so one player's hat would be worn by every player on the server
-- and on every later one, because the module is required once per process. `read` clones a table
-- default now, and this freeze is the other half: a mutation of the template ERRORS LOUDLY instead
-- of corrupting silently.
Drive.deepFreeze(Store.TEMPLATE)

-- PURE. The DataStore key. 26 characters at the worst userId Roblox can issue, against the
-- documented 50-character cap (limits page: key name length *"50"*).
function Store.keyFor(userId: number): string
	return string.format("player_%d", userId)
end

-- PURE. The MISSING-KEY RULE, and it is the one invented thing in this system (rule 2 wants the
-- reason written down, so here it is, in two halves):
--
--   * FILLING A MISSING KEY is what lets a profile written by an older build be read by this one.
--     Whether ProfileStore reconciles a template on load is NOT VERIFIED by this repo
--     (docs/design/economy.md section 14), and twelve lines of pure code make the answer irrelevant.
--   * KEEPING AN UNKNOWN KEY is what makes a ROLLBACK survivable. A build that does not know about
--     `trophies` must not delete the trophies a newer build wrote. That is the half a library cannot
--     do for us, because it is a decision about our data and not about saving.
function Store.read(data: any): { [string]: any }
	local out: { [string]: any } = {}
	if type(data) == "table" then
		for key, value in pairs(data) do
			out[key] = value
		end
	end
	for key, value in pairs(Store.TEMPLATE) do
		-- A TABLE DEFAULT IS CLONED AND NEVER HANDED OVER (hazard 1), and a key that came back with
		-- the WRONG TYPE is replaced rather than trusted: nobody here has verified what an empty Lua
		-- table does on a DataStore round trip (design section 17), and `owned = {}` is the common
		-- case for a new player. Checking the type makes the answer irrelevant.
		if out[key] == nil or (type(value) == "table" and type(out[key]) ~= "table") then
			out[key] = if type(value) == "table" then table.clone(value) else value
		end
	end
	return out
end

-- ------------------------------------------------------------------ the in-memory store

-- THE DOUBLE *AND* THE STUDIO PATH, which is why its two options are not a production test seam:
-- this implementation is what a Studio session gets, every time, so a playtest cannot write a live
-- key even with the API toggle on -- and the harness never requires the library at all.
--
--   `seed`   userId -> A WHOLE PROFILE (task 178), so one line seeds a balance, a hunt count AND an
--            ownership set: `{ [7] = { coins = 500, drivesPaid = 30, owned = { ["hat.red"] = true } } }`.
--            It was `userId -> a number` until the shop needed the other two fields; a NUMBER IS
--            STILL ACCEPTED and read as `{ coins = n }`, so no existing caller changes
--            (`backups/2026-10-14_task-178_store-seed-and-save.md`).
--   `refuse` userId -> true, so `load` answers nil, which is how the REFUSED-SESSION branch is
--            driven without a second Roblox server (the one case that cannot be reproduced here:
--            one Studio session is one server).
function Store.memory(options: { seed: { [number]: any }?, refuse: { [number]: boolean }? }?): Store
	local opts = options or {}
	local saved: { [string]: any } = {}
	local open: { [number]: boolean } = {}
	local counts: { [string]: number } = { load = 0, save = 0, release = 0, releaseAll = 0 }
	local onLost: ((userId: number) -> ())? = nil

	for userId, seeded in pairs(opts.seed or {}) do
		saved[Store.keyFor(userId)] = if type(seeded) == "number" then { coins = seeded } else Store.read(seeded)
	end

	return {
		kind = "memory",
		load = function(userId: number): ({ [string]: any }?, string?)
			counts.load += 1
			if (opts.refuse or {})[userId] then
				return nil, "refused"
			end
			open[userId] = true
			return Store.read(saved[Store.keyFor(userId)]), nil
		end,
		-- EXACTLY THE FIELDS IT WAS TOLD, AND NOTHING DERIVED (design section 8.2b). The old body
		-- computed `coinsEarnedTotal` and `drivesPaid` itself, which is archived with its reason in
		-- `backups/2026-10-14_task-178_store-seed-and-save.md`.
		save = function(userId: number, fields: { [string]: any }): boolean
			counts.save += 1
			if not open[userId] then
				return false
			end
			local key = Store.keyFor(userId)
			local data = Store.read(saved[key])
			for field, value in pairs(fields or {}) do
				data[field] = value
			end
			saved[key] = data
			return true
		end,
		-- WHAT IS IN THE KEY, for a spec that wants to prove a round trip through the SAVED table
		-- rather than through a second `load` (which would open a session). Memory only.
		peek = function(userId: number): { [string]: any }
			return Store.read(saved[Store.keyFor(userId)])
		end,
		release = function(userId: number): boolean
			counts.release += 1
			if not open[userId] then
				return false
			end
			open[userId] = nil
			return true
		end,
		releaseAll = function(): number
			counts.releaseAll += 1
			local ended = 0
			for userId in pairs(open) do
				open[userId] = nil
				ended += 1
			end
			return ended
		end,
		setOnLost = function(handler: (userId: number) -> ())
			onLost = handler
		end,
		calls = function()
			return table.clone(counts)
		end,
		-- The memory store never loses a session by itself -- nothing else holds its table -- so this
		-- exists to be CALLED BY A SPEC, which is how our reaction to `Profile.OnSessionEnd` is
		-- proved without a second server.
		loseSession = function(userId: number)
			open[userId] = nil
			if onLost then
				onLost(userId)
			end
		end,
	}
end

-- ------------------------------------------------------------------ the live store

-- THE ONLY `require` OF ProfileStore IN THE REPOSITORY, and it is inside this function's body for
-- the reason in the header (item 2: the require itself writes a key). Nothing in Studio calls this,
-- so no harness run performs it.
function Store.live(storeName: string): Store
	-- BOUNDED, AND LOUD WHEN IT RUNS OUT (round 1 note 2). `default.project.json` maps the package
	-- tree as `{ "optional": "ServerPackages" }`, so a place built without `wally install` simply has
	-- no tree -- and a bare `WaitForChild` here would yield FOR EVER inside `Economy.start`, which
	-- both composition roots call BEFORE `Match.start`. The whole server boot would stop, silently,
	-- the day the flag's default flips. A timeout turns that into a sentence in the console and a
	-- server that still runs its drive, with the money off.
	local packages = ServerStorage:WaitForChild("ServerPackages", WAIT_FOR_LIBRARY_SECONDS)
	local module = packages and packages:WaitForChild("ProfileStore", WAIT_FOR_LIBRARY_SECONDS)
	if not module then
		error(
			"[economy] ServerStorage.ServerPackages.ProfileStore is not in this place after "
				.. tostring(WAIT_FOR_LIBRARY_SECONDS)
				.. " s: run `wally install` and rebuild. Nothing is saved.",
			0
		)
	end
	local ProfileStore = require(module) :: any
	local profileStore = ProfileStore.New(storeName, Store.TEMPLATE)

	local profiles: { [number]: any } = {}
	local counts: { [string]: number } = { load = 0, save = 0, release = 0, releaseAll = 0 }
	local onLost: ((userId: number) -> ())? = nil

	local function endSession(userId: number): boolean
		local profile = profiles[userId]
		if not profile then
			return false
		end
		profiles[userId] = nil
		-- *"you must always call `Profile:EndSession()` after you're done working with a profile"* --
		-- and it is what saves, so this is the save on leave and the save at shutdown both.
		pcall(function()
			profile:EndSession()
		end)
		return true
	end

	return {
		kind = "live",
		load = function(userId: number): ({ [string]: any }?, string?)
			counts.load += 1
			if profiles[userId] then
				return Store.read(profiles[userId].Data), nil
			end
			local ok, profile = pcall(function()
				return profileStore:StartSessionAsync(Store.keyFor(userId))
			end)
			-- TWO DIFFERENT FAILURES, told apart here because this is the only place that can:
			-- a REFUSED LOCK (*":StartSessionAsync() can return nil when another remote Roblox server
			-- attempts to start a session for the same profile at the same time"*) answers nil from a
			-- call that worked, and an ERROR is the call itself throwing. Both mean NO SESSION, so no
			-- earning and no saving until a retry succeeds.
			if not ok then
				return nil, "error"
			end
			if profile == nil then
				return nil, "refused"
			end
			profiles[userId] = profile
			-- *"after the `Profile.OnSessionEnd` signal is fired, no further changes to
			-- `Profile.Data` should be made"* -- so the row goes the instant ownership moves, and the
			-- owner drops the balance with it rather than writing into a dead table.
			profile.OnSessionEnd:Connect(function()
				profiles[userId] = nil
				if onLost then
					onLost(userId)
				end
			end)
			profile.Data = Store.read(profile.Data)
			return profile.Data, nil
		end,
		save = function(userId: number, fields: { [string]: any }): boolean
			counts.save += 1
			local profile = profiles[userId]
			if not profile then
				return false
			end
			-- NOT A NETWORK CALL. The library's own auto-save and `EndSession` do the writing, which
			-- is the whole reason it was borrowed. **Purchases per DataStore request: 0.**
			--
			-- EXACTLY THE FIELDS IT WAS TOLD: the derivation moved to `Economy.payDrive` (design
			-- section 8.2b), because a `save` that counted a drive would have counted a purchase too.
			local data = profile.Data
			for field, value in pairs(fields or {}) do
				data[field] = value
			end
			return true
		end,
		release = function(userId: number): boolean
			counts.release += 1
			return endSession(userId)
		end,
		releaseAll = function(): number
			counts.releaseAll += 1
			local ended = 0
			for userId in pairs(profiles) do
				if endSession(userId) then
					ended += 1
				end
			end
			return ended
		end,
		setOnLost = function(handler: (userId: number) -> ())
			onLost = handler
		end,
		calls = function()
			return table.clone(counts)
		end,
	}
end

return Store
