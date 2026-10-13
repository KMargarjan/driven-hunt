--!strict
-- Economy: THE ONE OWNER of a player's coins (CLAUDE.md rule 3) -- the in-memory balance, the
-- ProfileStore session behind it, and what the last drive paid each player.
--
-- Karen, 2026-10-11: *"Scoring - yes get money when shoot boar not much but get money and first
-- place ofc more legendary more ect"*. 2026-10-10, her design doc: *"Progress trophys, money can
-- purchase more"*.
--
-- IT IS ITS OWN OWNER AND NOT A MODULE UNDER `src/server/Match/`, for the reason `Bots` is not one
-- either: NOTHING UNDER THERE CONNECTS ANYTHING. This connects three things
-- (`Players.PlayerAdded`, `Players.PlayerRemoving`, and one `Profile.OnSessionEnd` per player) and
-- spawns threads that yield. The second reason is stronger: a PROFILE OUTLIVES A DRIVE AND OUTLIVES
-- `Match.stop()`, and a session lock dropped without `EndSession` is exactly the loss ProfileStore
-- exists to prevent.
--
-- WHAT IT ADDS NO SOURCE OF TRUTH FOR. `Match.Score` still owns points; this owns money, and money
-- is a pure function of the board (`Economy.Coins`). No coin is awarded anywhere a point is not.
-- The drive is handed a read-only VIEW (`Economy.view()`) -- the `Bots.view()` /
-- `ForestTest.readOnlyBoars` idiom -- so the drive cannot open a session, cannot write a balance and
-- cannot see the library.
--
-- WHAT IT NEVER DOES: own a clock (no Heartbeat, no `task.delay`, no auto-save of ours -- the period
-- is ProfileStore's default and we call no `SetConstant`), hold a `Player` (keyed by userId, the
-- discipline `Score`'s header states), fire a remote, write anything drawn, or read a flag anywhere
-- but at its own boundary.
--
-- THE FLAG IS `COINS`, BORN OFF, and OFF is the game before task 170 bit for bit: no session is
-- opened, no key is written, no coin is awarded, and `Match.snapshot()`'s rows carry neither `coins`
-- nor `earned` -- so the Hud draws today's one-table board because the DATA is absent, not because
-- a second renderer was written.
--
-- Design: docs/design/economy.md
-- Note:   docs/research/2026-10-13-coins-persistence.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Drive = require(ReplicatedStorage:WaitForChild("Drive"))
local Flags = require(ReplicatedStorage:WaitForChild("Flags"))

local Coins = require(script.Coins)
local StoreModule = require(script.Store)

local Economy = {}
-- Exported for the specs ONLY, exactly as `Match.Score` and `Boar.Brain` are: the pure halves are
-- where every number in this system is provable in milliseconds.
Economy.Coins = Coins
Economy.Store = StoreModule

export type Store = StoreModule.Store

-- Server-only and NEVER REPLICATED. `ReplicatedStorage.Drive`'s header states the rule these numbers
-- are kept on this side by: a client that knows a rate learns nothing it is not already told, and
-- the one place a rate belongs is the one place the rule is applied.
Economy.CONFIG = {
	-- THE ONE FLAG READ, at this owner's boundary, passed inward through `Economy.start`'s
	-- `world.enabled` -- the only permitted shape (CLAUDE.md, "Feature flags"), and what keeps both
	-- branches reachable by parameter while the flag sits at one of them.
	ENABLED = Flags.isOn("COINS"),

	-- *"not much but get money"*. A male boar is 10 points (`Match.CONFIG.POINTS.KIND.male`), so a
	-- boar is 20 coins plus participation -- a round number a player can count in his head, and
	-- `POINTS.KIND` stays the ONE place the ratios between animals live.
	COINS_PER_POINT = 2, -- K
	-- HALF A BOAR FOR TURNING UP AND FINISHING THE DRIVE. It is the reason a beater whose animals
	-- nobody shot does not read a nought, which is the same argument `POINTS.BEATER_PUSH` rests on
	-- (`Score`'s own header: *"if only the killer scores then half the players end a ten-minute drive
	-- with an empty line"*).
	PARTICIPATION = 10, -- K
	-- 1.25 BOARS, AND IT IS PAID PER RANKING -- the top hunter and the top beater each get one.
	-- Karen, 2026-10-11: *"first place ofc more"*, and 2026-10-12: separate rankings for the two
	-- sides. A tie at the top of a ranking pays NOBODY, which is `Drive.Rank`'s rule and ioquake3's.
	FIRST_PLACE = 25, -- K
	-- A BALANCE NEVER GOES BELOW ZERO. The drive's own line may: two piglets and a safety violation
	-- is -30 points, which is -50 coins, and that number is what the results table prints. A player
	-- who has a bad drive earns nothing from it; he does not go into debt.
	FLOOR = 0, -- K

	-- VERSIONED IN THE NAME, because that is the only migration tool that cannot corrupt live data:
	-- a change `Store.read` cannot make additively bumps this to `_v2` and leaves every `_v1` key
	-- untouched and readable. It is NOT called "Coins": the next thing into this table is Karen's
	-- *"Progress trophys"*, and a store named after one of its columns forces either a second store
	-- or a lie.
	STORE_NAME = "DrivenHuntPlayer_v1",
	-- Roblox's documented key cap (the limits page: key name length *"50"*). `Store.keyFor` is 26
	-- characters at the longest userId Roblox can issue, and `economy.spec` asserts it against this.
	KEY_MAX = 50,
	-- The bound on `closeAll`, inside `BindToClose`'s own window. A shutdown that cannot end every
	-- session says how many it could not, rather than hanging.
	CLOSE_TIMEOUT_SECONDS = 20,
}
Drive.deepFreeze(Economy.CONFIG)

-- ------------------------------------------------------------------------------- the only state
--
-- Four tables, one fact each, and nothing else in the repository may write any of them.

-- The in-memory balance -- the one the wire reports. A userId with NO ROW has no open profile, which
-- is NOT the same fact as a balance of zero (see `Economy.balanceOf`).
local balances: { [number]: number } = {}
-- Whose profile is open. A pay-out for a userId with no row here is refused and counted.
local sessions: { [number]: true } = {}
-- What the LAST PAID DRIVE was worth to each row. Replaced WHOLE by each pay-out, so a previous
-- drive's figure can never linger on the wire next to a new drive's.
local earnedThisDrive: { [number]: number } = {}
-- THE DOUBLE-PAY GUARD. A belt over the brace of the phase edge in `Match`'s dispatch, and it is
-- justified: `Match.start` resets `driveNumber` to 0, so two worlds in one process both count from 1
-- and the guard is reset by `start`/`stop` rather than trusted to be unique for ever.
local paidUpTo = 0

local store: Store? = nil
local players: any = nil
local enabled = false
local started = false
local connections: { RBXScriptConnection } = {}

local stats = {
	loads = 0,
	-- A REFUSED SESSION LOCK and A THROWN ERROR are counted apart and treated the same (no session,
	-- so no earning and no saving). The split matters in a report: one is another server holding the
	-- player, the other is Roblox being down.
	loadsRefused = 0,
	loadsFailed = 0,
	-- A load that answered a balance for a player who had already left between the call and the
	-- reply. The session is handed straight back rather than installed.
	loadsAbandoned = 0,
	releases = 0,
	-- A session another server took off us, through `Profile.OnSessionEnd`.
	sessionsLost = 0,
	drivesPaid = 0,
	duplicatePayouts = 0,
	rowsPaid = 0,
	coinsPaid = 0,
	-- How often the floor actually fired. "Does a bad drive cost a player his savings" is a real
	-- question about the rates, and the answer belongs in a number rather than in a feeling.
	coinsClamped = 0,
	skippedNoProfile = 0,
	skippedLeft = 0,
	skippedNotAPlayer = 0,
	closeTimeouts = 0,
}

function Economy.stats()
	return table.clone(stats)
end

-- EVERY COUNTER BACK TO ZERO, called by `start`. They describe THIS owner's session and `start` is
-- where one begins -- and a module-level table that outlived `stop()` made every spec that ran
-- second read the one before it (round 1: `drivesPaid` was 2 where the case had paid once).
local function resetStats()
	for key in pairs(stats) do
		stats[key] = 0
	end
end

-- ------------------------------------------------------------------------------- pure, exported

-- WHICH STORE A RUN TAKES, as a pure function of one boolean. Exported for exactly
-- `Match.quickTestEnabled`'s reason, in its own words: *"Pure and exported so the guard itself is
-- testable ... which is the assertion that says a live server can never run this however the
-- attribute got there"*.
--
-- Inside Studio `RunService:IsStudio()` is ALWAYS true and no harness run can make it false, so the
-- live branch is provable only like this: `storeKindFor(false) == "live"` and
-- `storeKindFor(true) == "memory"`. That assertion is the whole evidence that a playtest cannot
-- write a live DataStore key even with *Enable Studio Access to API Services* on.
function Economy.storeKindFor(isStudio: boolean): string
	return if isStudio then "memory" else "live"
end

-- ------------------------------------------------------------------------------- reads

-- `nil`, NOT `0`, for a player with no open profile. `0` would be this owner asserting that he has no
-- coins; `nil` is the truth, and the Hud draws it as `--`.
function Economy.balanceOf(userId: number): number?
	return balances[userId]
end

function Economy.earnedOf(userId: number): number?
	return earnedThisDrive[userId]
end

function Economy.balances(): { [number]: number }
	return table.freeze(table.clone(balances))
end

function Economy.earned(): { [number]: number }
	return table.freeze(table.clone(earnedThisDrive))
end

function Economy.storeKind(): string
	if not enabled then
		return "off"
	end
	local current = store
	return if current then current.kind else "off"
end

function Economy.isEnabled(): boolean
	return enabled
end

-- The highest drive number this owner has paid. The double-pay guard, readable.
function Economy.lastPaidDrive(): number
	return paidUpTo
end

-- ------------------------------------------------------------------------------- the pay-out

export type Receipt = {
	driveNumber: number,
	paid: number,
	coins: number,
	skippedLeft: number,
	skippedNoProfile: number,
	skippedNotAPlayer: number,
	clamped: number,
	duplicate: boolean,
}

-- WHAT A DRIVE PAID, AND IT NEVER YIELDS. It runs inside `Match`'s `dispatch`, on the `Scoring`
-- edge, BEFORE `applyEffects` -- and a yield there would apply the drive's own effects late. The
-- only calls it makes are into the four tables above and `Store.save`, which performs no network
-- call by contract (the library's auto-save and `EndSession` do the writing).
--
-- `rows` is `Score.leaderboard(board)`: the pure board, not `Match.snapshot()`. Building the snapshot
-- here would cache a copy from BEFORE the pay-out.
function Economy.payDrive(driveNumber: number, rows): Receipt
	local receipt: Receipt = {
		driveNumber = driveNumber,
		paid = 0,
		coins = 0,
		skippedLeft = 0,
		skippedNoProfile = 0,
		skippedNotAPlayer = 0,
		clamped = 0,
		duplicate = false,
	}
	if not enabled then
		return receipt
	end
	-- EXACTLY ONE PAY-OUT PER DRIVE NUMBER. The phase edge already makes this structural; this makes
	-- it provable from inside this owner, and it is what `stats().duplicatePayouts` counts.
	if driveNumber <= paidUpTo then
		stats.duplicatePayouts += 1
		receipt.duplicate = true
		return receipt
	end
	paidUpTo = driveNumber

	local breakdown = Coins.forDrive(rows, Economy.CONFIG)
	receipt.skippedLeft = breakdown.skippedLeft
	receipt.skippedNotAPlayer = breakdown.skippedNotAPlayer
	stats.skippedLeft += breakdown.skippedLeft
	stats.skippedNotAPlayer += breakdown.skippedNotAPlayer

	-- REPLACED WHOLE, never merged: a row that is not in this drive must not keep the last drive's
	-- figure on the wire.
	local nextEarned: { [number]: number } = {}
	for userId, coins in pairs(breakdown.coins) do
		if sessions[userId] == nil then
			-- NO PROFILE, NO EARNING, and it is counted rather than queued. The three options were
			-- "earn and lose it silently" (a lie on screen), "earn into a queue" (a second store of
			-- the same fact, written for a player who may never come back), and "do not earn,
			-- visibly". The retry at the next drive start makes the window one drive.
			receipt.skippedNoProfile += 1
			stats.skippedNoProfile += 1
		else
			local before = balances[userId] or 0
			local after = Coins.credit(before, coins, Economy.CONFIG)
			if after ~= before + coins then
				receipt.clamped += 1
				stats.coinsClamped += 1
			end
			balances[userId] = after
			nextEarned[userId] = coins
			receipt.paid += 1
			receipt.coins += coins
			stats.rowsPaid += 1
			stats.coinsPaid += coins
			local current = store
			if current then
				current.save(userId, after)
			end
		end
	end
	earnedThisDrive = nextEarned
	stats.drivesPaid += 1
	return receipt
end

-- ------------------------------------------------------------------------------- sessions

-- LOADS A PLAYER'S BALANCE, in a thread of its own because the store yields. Idempotent per userId:
-- a second call while one is in flight, or after it succeeded, opens no second session.
local inFlight: { [number]: true } = {}

function Economy.load(player: Player)
	if not enabled then
		return
	end
	local userId = player.UserId
	if sessions[userId] or inFlight[userId] then
		return
	end
	inFlight[userId] = true
	task.spawn(function()
		local current = store
		local balance, reason = nil, nil
		if current then
			balance, reason = current.load(userId)
		end
		inFlight[userId] = nil
		stats.loads += 1
		if balance == nil then
			-- TOLD APART BY THE STORE, which is the only thing that can tell them apart (see
			-- `Store.load`): "refused" is another server holding this player's lock, "error" is the
			-- call throwing. Both mean no session; the two numbers are what a report acts on.
			if reason == "error" then
				stats.loadsFailed += 1
			else
				stats.loadsRefused += 1
			end
			warn(
				string.format(
					"[economy] no profile session for userId %d: he earns nothing this drive and nothing is saved."
						.. " Retried at the next drive start.",
					userId
				)
			)
			return
		end
		-- A session this server lost between the call and the reply must not install a balance.
		if not player.Parent then
			stats.loadsAbandoned += 1
			if current then
				current.release(userId)
			end
			return
		end
		sessions[userId] = true
		balances[userId] = balance
	end)
end

function Economy.release(userId: number)
	if not enabled then
		return
	end
	if not sessions[userId] then
		return
	end
	sessions[userId] = nil
	balances[userId] = nil
	earnedThisDrive[userId] = nil
	stats.releases += 1
	task.spawn(function()
		local current = store
		if current then
			current.release(userId)
		end
	end)
end

-- THE LEVEL-TRIGGERED RETRY, called at every drive start. The `Weapon.refreshArming` / `syncBots`
-- discipline, and for their stated reason: *"every edge-triggered grant in this repo has been
-- measured missing one"*. A transient Roblox outage costs one drive's coins, not the session's.
function Economy.onDriveStart()
	if not enabled then
		return
	end
	for _, player in ipairs(players:GetPlayers()) do
		Economy.load(player)
	end
end

-- SHUTDOWN ONLY, and the one function here that YIELDS -- `BindToClose` is given time to finish.
-- Bounded: it stops after `CLOSE_TIMEOUT_SECONDS` and says how many it could not end.
--
-- SAFE TO CALL WHEN NOTHING WAS EVER STARTED, which is what makes the composition root's
-- unconditional registration correct: `BindToClose` cannot be disconnected, so registering it
-- inside `Economy.start` would leave one callback per spec run bound for the rest of the session.
function Economy.closeAll(): number
	local current = store
	if not current then
		return 0
	end
	local ended = 0
	local finished = false
	task.spawn(function()
		ended = current.releaseAll()
		finished = true
	end)
	local deadline = os.clock() + Economy.CONFIG.CLOSE_TIMEOUT_SECONDS
	while not finished and os.clock() < deadline do
		task.wait(0.1)
	end
	if not finished then
		stats.closeTimeouts += 1
		warn(
			string.format(
				"[economy] closeAll did not finish within %d s: some sessions were left to ProfileStore's own"
					.. " shutdown handling.",
				Economy.CONFIG.CLOSE_TIMEOUT_SECONDS
			)
		)
	end
	table.clear(sessions)
	table.clear(balances)
	return ended
end

-- ------------------------------------------------------------------------------- the view

export type View = {
	payDrive: (driveNumber: number, rows: any) -> (),
	balances: () -> { [number]: number },
	earned: () -> { [number]: number },
}

-- WHAT THE DRIVE IS HANDED: three functions, no `start`, no `stop`, no store and no setter -- the
-- `Bots.view()` / `ForestTest.readOnlyBoars` idiom. The drive cannot open a session, cannot write a
-- balance and cannot reach the library through it.
function Economy.view(): View
	return {
		payDrive = function(driveNumber: number, rows)
			Economy.payDrive(driveNumber, rows)
		end,
		balances = Economy.balances,
		earned = Economy.earned,
	}
end

-- ------------------------------------------------------------------------------- lifecycle

export type World = {
	store: Store?,
	players: any?,
	enabled: boolean?,
}

-- NOTHING HAPPENS ON REQUIRE. `injected.enabled` is what makes both branches of the flag reachable
-- by parameter while the flag sits at one of them; `injected.store` is what lets a spec drive the
-- whole owner with no library, no network and no DataStore.
function Economy.start(injected: World?)
	assert(not started, "Economy.start called twice")
	local world = injected or {}
	enabled = if world.enabled ~= nil then world.enabled else Economy.CONFIG.ENABLED
	players = world.players or Players
	paidUpTo = 0
	resetStats()
	table.clear(balances)
	table.clear(sessions)
	table.clear(inFlight)
	earnedThisDrive = {}
	started = true

	if not enabled then
		-- OFF CONNECTS NOTHING AND LOADS NOTHING. The absence of data is what makes the rest of the
		-- game identical to before this task.
		store = nil
		print("[economy] coins=off (born dark, task 170): no session is opened and no key is written")
		return
	end

	if world.store then
		store = world.store
	else
		-- THE ONE DECISION THAT KEEPS STUDIO OFF THE LIVE KEYS, and it is a pure predicate so it can
		-- be asserted from inside Studio (`Economy.storeKindFor`).
		local kind = Economy.storeKindFor(RunService:IsStudio())
		store = if kind == "live" then StoreModule.live(Economy.CONFIG.STORE_NAME) else StoreModule.memory()
	end
	local current = store :: Store
	-- *"after the `Profile.OnSessionEnd` signal is fired, no further changes to `Profile.Data` should
	-- be made"* -- so the row goes the instant ownership moves, and he stops earning rather than
	-- writing into a dead table.
	current.setOnLost(function(userId: number)
		if sessions[userId] then
			stats.sessionsLost += 1
		end
		sessions[userId] = nil
		balances[userId] = nil
	end)
	-- WHICH STORE WAS TAKEN, said out loud once (the dispatch's *"clearly logged"*). A module never
	-- prints in this repo for a measured reason -- a tool that requires it over StudioMCP gets a
	-- sandboxed copy -- but this is the one fact a reader of the console needs to know whether a
	-- session is being saved at all, and `Economy.start` runs once per server.
	print(
		string.format(
			"[economy] coins=on store=%s%s",
			current.kind,
			if current.kind == "memory" then " (Studio: nothing is written to a live DataStore key)" else ""
		)
	)

	-- The sweep plus the signal, exactly as `Match.start` does it: a player already on the server
	-- must have a session open before the first dispatch.
	for _, player in ipairs(players:GetPlayers()) do
		Economy.load(player)
	end
	table.insert(connections, players.PlayerAdded:Connect(Economy.load))
	table.insert(
		connections,
		players.PlayerRemoving:Connect(function(player: Player)
			Economy.release(player.UserId)
		end)
	)
end

-- A spec that stops this owner must not leave a session open, or a `lastPaidDrive` that refuses the
-- next spec's drive 1.
function Economy.stop()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
	local current = store
	if current then
		current.releaseAll()
	end
	store = nil
	players = nil
	enabled = false
	started = false
	paidUpTo = 0
	table.clear(balances)
	table.clear(sessions)
	table.clear(inFlight)
	earnedThisDrive = {}
end

return Economy
