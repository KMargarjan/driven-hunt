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
local ServerStorage = game:GetService("ServerStorage")

local Store = {}

export type Store = {
	kind: string, -- "memory" | "live"
	-- YIELDS. The balance, or nil for NO SESSION plus the REASON -- "refused" (another server holds
	-- the lock) or "error" (the call itself threw). The owner treats them the same (no session means
	-- no earning and no saving) and COUNTS THEM APART, because one is another player's server and
	-- the other is Roblox being down, and a report that cannot tell them apart cannot be acted on.
	load: (userId: number) -> (number?, string?),
	-- Writes the LOCAL copy and performs NO network call. ProfileStore's own auto-save and its
	-- `EndSession` do the writing (see the header). `false` when there is no session.
	save: (userId: number, balance: number) -> boolean,
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
	drivesPaid = 0,
}

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
		if out[key] == nil then
			out[key] = value
		end
	end
	return out
end

-- ------------------------------------------------------------------ the in-memory store

-- THE DOUBLE *AND* THE STUDIO PATH, which is why its two options are not a production test seam:
-- this implementation is what a Studio session gets, every time, so a playtest cannot write a live
-- key even with the API toggle on -- and the harness never requires the library at all.
--
--   `seed`   userId -> a starting balance, so a spec can prove a load/save round trip.
--   `refuse` userId -> true, so `load` answers nil, which is how the REFUSED-SESSION branch is
--            driven without a second Roblox server (the one case that cannot be reproduced here:
--            one Studio session is one server).
function Store.memory(options: { seed: { [number]: number }?, refuse: { [number]: boolean }? }?): Store
	local opts = options or {}
	local saved: { [string]: any } = {}
	local open: { [number]: boolean } = {}
	local counts: { [string]: number } = { load = 0, save = 0, release = 0, releaseAll = 0 }
	local onLost: ((userId: number) -> ())? = nil

	for userId, balance in pairs(opts.seed or {}) do
		saved[Store.keyFor(userId)] = { coins = balance }
	end

	return {
		kind = "memory",
		load = function(userId: number): (number?, string?)
			counts.load += 1
			if (opts.refuse or {})[userId] then
				return nil, "refused"
			end
			open[userId] = true
			return Store.read(saved[Store.keyFor(userId)]).coins, nil
		end,
		save = function(userId: number, balance: number): boolean
			counts.save += 1
			if not open[userId] then
				return false
			end
			local key = Store.keyFor(userId)
			local data = Store.read(saved[key])
			data.coinsEarnedTotal += math.max(0, balance - data.coins)
			data.coins = balance
			data.drivesPaid += 1
			saved[key] = data
			return true
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
	local module = ServerStorage:WaitForChild("ServerPackages"):WaitForChild("ProfileStore")
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
		load = function(userId: number): (number?, string?)
			counts.load += 1
			if profiles[userId] then
				return Store.read(profiles[userId].Data).coins, nil
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
			return profile.Data.coins, nil
		end,
		save = function(userId: number, balance: number): boolean
			counts.save += 1
			local profile = profiles[userId]
			if not profile then
				return false
			end
			-- NOT A NETWORK CALL. The library's own auto-save and `EndSession` do the writing, which
			-- is the whole reason it was borrowed.
			local data = profile.Data
			data.coinsEarnedTotal += math.max(0, balance - (data.coins or 0))
			data.coins = balance
			data.drivesPaid = (data.drivesPaid or 0) + 1
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
