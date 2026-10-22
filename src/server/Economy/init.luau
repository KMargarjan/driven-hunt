--!strict
-- Economy: THE ONE OWNER of a player's PERSISTENT RECORD (CLAUDE.md rule 3) -- the in-memory
-- balance, what he owns, how many drives he has finished, WHICH ROLE HE IS OWED NEXT (task 217),
-- the ProfileStore session behind all of it, and what the last drive paid each player.
--
-- IT IS THE ONE PERSISTENCE OWNER AND NOT "the coins owner", which is why task 217 extended this
-- record rather than opening a second store: one key per player, one session lock, one place that
-- may reach `DataStoreService` (Roblox's own best-practices page, and the Director's instruction).
-- Karen, 2026-10-11: *"ROLES ROTATE: you start as a hunter, next round you are a beater; it is
-- REMEMBERED across logout/login (no cheating back to hunter)"*.
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
-- Design: docs/design/economy.md, docs/design/role-rotation.md (sections 4.4, 5)
-- Note:   docs/research/2026-10-13-coins-persistence.md, docs/research/2026-10-20-role-rotation.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- THE ROBUX DOOR'S SERVICE (task 238), and the only reference to it on the server. `ProcessReceipt`
-- is installed by `Economy.start` OUTSIDE STUDIO ONLY (see it), so no harness run and no spec ever
-- writes this service; the function it installs, `Economy.processReceipt`, is driven by parameter
-- instead, which is the whole reason it answers a string rather than an Enum.
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
-- For ONE read, once, in `Economy.start`: the Studio-only test grant's attribute (task 178, the
-- Director). `ServerStorage` is server-only and never replicates, which is the same door
-- `DHFlag_*` and `DHForestStartRole` already come through.
local ServerStorage = game:GetService("ServerStorage")

local Drive = require(ReplicatedStorage:WaitForChild("Drive"))
local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
-- THE SHOP'S CATALOGUE AND ITS PURE REFUSAL (task 178). Frozen shared DATA with no writer, required
-- for the same reason `Match` requires `ReplicatedStorage.Licences`: the rule about what a purchase
-- costs and when it may happen lives in one table, and the thing that takes the money reads it
-- rather than keeping a second copy of the prices. It adds no owner edge -- `ServerScriptService.Shop`
-- is NOT required here, and it does not require this.
local ShopData = require(ReplicatedStorage:WaitForChild("Shop"))

local Coins = require(script.Coins)
local StoreModule = require(script.Store)

local Economy = {}
-- Exported for the specs ONLY, exactly as `Match.Score` and `Boar.Brain` are: the pure halves are
-- where every number in this system is provable in milliseconds.
Economy.Coins = Coins
Economy.Store = StoreModule

export type Store = StoreModule.Store
-- THE TWO TEAM NAMES, AS A TYPE. `Drive.TeamName` cannot be reached as a type from here: the require
-- above goes through `WaitForChild`, so Luau cannot resolve that module's exports -- which is why
-- `Match.Body` declares its own copy of this line too. The RUNTIME answer is not copied: the
-- membership test is `Drive.TEAMS`, read by the one validator below, so there is exactly one place
-- the two strings are checked (design section 3.4).
export type TeamName = "Drivers" | "Shooters"

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

	-- ------------------------------------------------------------------ the Studio test grant (178)
	--
	-- WHY IT EXISTS (the Director, 2026-10-14): in Studio the store is the IN-MEMORY one, always, so
	-- every session starts a player at nought -- and with `SHOP` on Karen can walk up to the counter
	-- and afford nothing she is meant to try. A drive is 300 seconds and pays ~20-60 coins, so
	-- earning the 1500-coin rifle in a playtest is forty drives.
	--
	-- 12,750 BUYS THE WHOLE CATALOGUE THAT IS FOR SALE (task 221, raised in task 223): the items
	-- are 120 + 250 + 600 + 750 + 900 + 1500 + 2000 = 6,120 and the packages
	-- 575 + 1800 + 3750 = 6,125, so everything for sale is $12,245 and this covers it with $505
	-- over -- the same margin 12,000 left before the DEER LICENCE was sellable. **THE CARD IS
	-- COUNTED NOW BECAUSE IT CAN BE BOUGHT**: Karen's red deer arrived on 2026-10-20, so the row
	-- that was `sale = false` went on sale in the same commit as the animal, and a test grant that
	-- did not cover it would leave her unable to try the one thing this task added.
	-- 30 HUNTS is exactly the highest gate in the catalogue (ALWAYS
	-- HUNTER and THE FULL SEASON), so every rung is unlocked and nothing is bought FOR her -- she
	-- still presses every button and sees every state.
	--
	-- `economy.spec` ASSERTS BOTH NUMBERS AGAINST THE CATALOGUE rather than against themselves, so
	-- the grant cannot fall behind a row somebody adds later without the harness saying so.
	-- 12,750 -> 13,000 SINCE TASK 224: the lever rifle is a 650-coin rung, so the old grant no
	-- longer covered the catalogue and `economy.spec` -- which asserts this against the sum of
	-- every sellable row rather than against itself -- said so. 13,000 is 105 clear of the 12,895
	-- total, which is the same headroom the old number had.
	-- 13500 SINCE TASK 225, and it moves with the catalogue rather than being a round number
	-- somebody liked: the grant exists so Karen can buy EVERY rung and see every state, and the
	-- semi-automatic shotgun took the sale total from 12895 to 13395 -- 395 past the old 13000.
	-- `economy.spec` asserts both halves, which is how that was caught rather than shipped.
	TEST_GRANT = { coins = 13500, hunts = 30 },
}
Drive.deepFreeze(Economy.CONFIG)

-- ------------------------------------------------------------------------------- the only state
--
-- One table per fact, and nothing else in the repository may write any of them. (The count in this
-- line used to be "four" and had been stale since task 178 added `ownedSets`; task 217 adds
-- `nextTeams` and its memo, so the sentence says the RULE now instead of a number that drifts.)

-- The in-memory balance -- the one the wire reports. A userId with NO ROW has no open profile, which
-- is NOT the same fact as a balance of zero (see `Economy.balanceOf`).
local balances: { [number]: number } = {}
-- Whose profile is open. A pay-out for a userId with no row here is refused and counted.
local sessions: { [number]: true } = {}
-- What the LAST PAID DRIVE was worth to each row. Replaced WHOLE by each pay-out, so a previous
-- drive's figure can never linger on the wire next to a new drive's.
local earnedThisDrive: { [number]: number } = {}
-- WHAT EACH OPEN PROFILE OWNS (task 178): userId -> itemId -> true. REPLACED WHOLE by each purchase,
-- the rule `earnedThisDrive` above already follows and for a second reason here: `Economy.ownedOf`
-- hands out FROZEN COPIES and a reader may still be holding one.
local ownedSets: { [number]: { [string]: boolean } } = {}
-- TWO PROFILE FIELDS MIRRORED IN MEMORY, read at load and written by `payDrive` in the same breath
-- as the store write -- so the in-memory number and the saved field have ONE writer and cannot
-- diverge (design section 8.2b: the store derives nothing now).
--
--   `huntsCache`   `drivesPaid`: the completed hunts the shop's gates read (`Economy.huntsOf`).
--   `earnedTotals` `coinsEarnedTotal`: the one number SPENDING destroys and cannot rebuild.
local huntsCache: { [number]: number } = {}
local earnedTotals: { [number]: number } = {}
-- WHOSE TURN IS WHICH (task 217): userId -> the TEAM he must be given at the next assignment he
-- takes part in. The in-memory mirror of the profile's `nextTeam`, with ONE writer
-- (`Economy.noteNextTeams`) and one reader (`Economy.owedTeams`), so the number in memory and the
-- saved field cannot diverge -- the discipline `huntsCache` and `earnedTotals` above already follow.
local nextTeams: { [number]: string } = {}
-- ...AND THE FROZEN ANSWER, MEMOISED. `Match.dispatch` asks for this on EVERY event (the
-- `aliveBoars` idiom), and while TASKS.md 214a(a) is open that dispatch is stepped at ~15x
-- `MATCH_STEP_HZ` -- so a clone-and-freeze per call would be ~60 table builds a second for a table
-- that changes at most twice a drive. Rebuilt (never mutated) by `invalidateOwed` below, which is
-- called by every writer of `nextTeams`.
local owedFrozen: { [number]: string }? = nil

local function invalidateOwed()
	owedFrozen = nil
end

-- WHO BOUGHT THE HUNTER'S PLACE (task 221), as a FROZEN MEMO, for `owedTeams`' own measured reason:
-- `Match.dispatch` asks for it on EVERY event, and while TASKS.md 214a(a) is open that dispatch is
-- stepped at ~15x `MATCH_STEP_HZ` -- so asking `ownedOf` per participant per event would be ~16
-- clone-and-freezes about sixty times a second.
--
-- IT IS A PROJECTION OF A PROFILE THIS OWNER ALREADY HOLDS, through the pure
-- `ShopData.grantsAlwaysHunter`: no new owner, no new fact and no second store. REBUILT AND NEVER
-- MUTATED by `invalidateAlways`, which every writer of `ownedSets` calls -- so a reader still
-- holding the previous table holds a correct snapshot of the moment it asked.
local alwaysFrozen: { [number]: boolean }? = nil

local function invalidateAlways()
	alwaysFrozen = nil
end
-- THE DOUBLE-PAY GUARD. A belt over the brace of the phase edge in `Match`'s dispatch, and it is
-- justified: `Match.start` resets `driveNumber` to 0, so two worlds in one process both count from 1
-- and the guard is reset by `start`/`stop` rather than trusted to be unique for ever.
local paidUpTo = 0

local store: Store? = nil
local players: any = nil
-- THE STUDIO TEST GRANT for this session, resolved ONCE at `Economy.start`'s boundary and passed
-- inward -- the shape a flag read has, and what keeps both branches reachable by parameter. nil is
-- every live server and every harness run.
local testGrant: { coins: number, hunts: number }? = nil
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
	-- THE SHOP (task 178). A granted purchase, a refused one, what was spent, and which rule said
	-- no -- the split `Weapon.stats` makes between a refusal and a forgery, on this side of the door.
	-- How many players this session's Studio test grant topped up. 0 in every live server and in
	-- every harness run, by construction.
	testGrants = 0,
	-- THE TURN (task 217): rows written, and the two reasons a row is skipped. A skip is not an
	-- error -- a player whose profile is not open simply keeps whatever is on his key -- but "how
	-- often did the rotation fail to be recorded" is a real question about a live server and the
	-- answer belongs in a number rather than in a feeling.
	nextTeamsWritten = 0,
	nextTeamSkippedNoProfile = 0,
	nextTeamRefused = 0,
	purchases = 0,
	purchasesRefused = 0,
	coinsSpent = 0,
	-- THE GRANT PATH (task 221), counted apart from the purchase that usually causes one: a grant
	-- can also arrive from a Robux receipt (task 222), and "how many entitlements arrived by Robux"
	-- is a number this report should be able to answer the day that door opens.
	grants = 0,
	grantsAlready = 0,
	grantsBySource = {} :: { [string]: number },
	-- THE ROBUX DOOR (task 238). `receipts` is every call of `Economy.processReceipt`;
	-- `receiptsGranted` the ones that answered `GRANTED`; `receiptsAlready` the subset of those that
	-- were a REDELIVERY of a receipt already granted, which is the number that says the idempotency
	-- is being exercised for real; `receiptsUnknown` a malformed receipt or a product no row
	-- carries; `receiptsNotProcessed` a grant that was refused (no session, closed, unknown row).
	-- All 0 in this build and in every harness run: no developer product exists (`rowsOk`'s I12).
	receipts = 0,
	receiptsGranted = 0,
	receiptsAlready = 0,
	receiptsUnknown = 0,
	receiptsNotProcessed = 0,
	refusedBy = {} :: { [string]: number },
	-- The live store refused to be built and the memory one was taken instead, so this server saves
	-- nothing. It is never non-zero in Studio, which never asks for the live store at all.
	storeFellBack = 0,
}

function Economy.stats()
	local out = table.clone(stats)
	out.refusedBy = table.clone(stats.refusedBy)
	out.grantsBySource = table.clone(stats.grantsBySource)
	return out
end

-- EVERY COUNTER BACK TO ZERO, called by `start`. They describe THIS owner's session and `start` is
-- where one begins -- and a module-level table that outlived `stop()` made every spec that ran
-- second read the one before it (round 1: `drivesPaid` was 2 where the case had paid once).
local function resetStats()
	for key, value in pairs(stats) do
		if type(value) == "number" then
			stats[key] = 0
		end
	end
	stats.refusedBy = {}
	stats.grantsBySource = {}
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

-- THE STUDIO TEST GRANT'S ATTRIBUTE, on `ServerStorage` (task 178, the Director).
--
-- IT IS DELIBERATELY NOT A `DHFlag_`, and the difference is the point: a `DHFlag_` is a FEATURE
-- SWITCH -- `tools/flags.py` writes and clears them, both harness modes REFUSE to start while one
-- is set, and the publish step strips them (TASKS.md task 2) -- and this is not a feature. It is a
-- TEST FIXTURE, the shape `DHForestStartRole` already has: a thing the Director sets in one Studio
-- to stage a playtest.
--
-- WHY IT CANNOT LEAK INTO A LIVE SERVER, in two halves, and only one of them has to hold:
--   1. `RunService:IsStudio()` IS FALSE ON EVERY LIVE SERVER. It is the SAME predicate that already
--      decides which store a run takes (`Economy.storeKindFor`), so the grant and the in-memory
--      store are gated on one fact: where a grant is possible, nothing is saved, and where
--      something is saved, no grant is possible. `Economy.testGrantFor(false, true)` is nil, and
--      `economy.spec` asserts exactly that -- which is the only shape in which the live branch is
--      provable at all from inside Studio (`Match.quickTestEnabled`'s own argument).
--   2. The attribute lives on `ServerStorage`, which never replicates, so no client can set it and
--      no client can read it.
-- THE COST IS STATED RATHER THAN DISCOVERED: because it is not a `DHFlag_`, the harness does NOT
-- refuse to run while it is set, so a DEV place carrying it would run the suite with granted coins.
-- That is why the grant is also INJECTED (`world.testGrant`) and every spec drives it by parameter,
-- and why the one place it is ever set is the Forest Test Studio.
Economy.TEST_GRANT_ATTRIBUTE = "DHShopTestGrant"

-- PURE, and exported for `storeKindFor`'s reason: inside Studio `IsStudio()` is always true, so this
-- is the only way to assert that a live server can never grant anything, however the attribute got
-- there. BOTH halves are required and the attribute must be the boolean `true` -- a string "true",
-- a 1 or a stale `false` grants nothing.
function Economy.testGrantFor(isStudio: boolean, attribute: any, config): { coins: number, hunts: number }?
	if not isStudio or attribute ~= true then
		return nil
	end
	local grant = (config or Economy.CONFIG).TEST_GRANT
	return { coins = grant.coins, hunts = grant.hunts }
end

-- PURE, exported. THE ONE VALIDATOR of the turn (task 217), at this owner's boundary and nowhere
-- else -- the discipline `Economy.load`'s four `type(...)` checks already follow.
--
-- IT ANSWERS nil FOR ANYTHING THAT IS NOT ONE OF THE TWO TEAM NAMES, and `nil` MEANS *no turn
-- stored*: `""` (the template's own default), a stale `"hunter"` from a vocabulary this project
-- never shipped, a number, a boolean, a table, a key written by a build that does not exist yet.
-- Never an error, never a crash and never a guess -- a corrupted profile puts a man on the smaller
-- side, which is the brand-new-player path and already has to work.
--
-- `Drive.TEAMS` IS THE MEMBERSHIP TEST and not two literals here, so there is no sixth copy of the
-- two strings to drift (design section 3.4).
function Economy.teamFromRecord(value: any): TeamName?
	if type(value) == "string" and (Drive.TEAMS :: any)[value] then
		return (value :: any) :: TeamName
	end
	return nil
end

-- WHAT EACH OPEN PROFILE IS OWED: userId -> team. FROZEN, so no reader can write the table it was
-- handed -- the `Economy.balances` idiom -- and MEMOISED, which `balances` is not, for a measured
-- reason: `Match.dispatch` reads this on EVERY event (the `aliveBoars` idiom), and while TASKS.md
-- 214a(a) is open that dispatch is stepped at ~15x `MATCH_STEP_HZ`. One table read, no clone and no
-- freeze per call.
--
-- THE MEMO IS REBUILT AND NEVER MUTATED (hazard 2): every writer of `nextTeams` calls
-- `invalidateOwed`, so a reader still holding the previous table holds a correct snapshot of the
-- moment it asked rather than a table that changed under it.
--
-- EMPTY when the flag is off (no session is ever opened, so no row exists), when no profile is open,
-- and in every spec that starts no money -- which is the first link of the flag-off identity
-- (design section 7).
function Economy.owedTeams(): { [number]: TeamName }
	local cached = owedFrozen
	if cached == nil then
		cached = table.freeze(table.clone(nextTeams))
		owedFrozen = cached
	end
	return (cached :: any) :: { [number]: TeamName }
end

-- WHO IS OWED `Shooters` EVERY DRIVE BECAUSE HE PAID FOR IT (task 221). Karen, 2026-10-20:
-- *"Posibility to be a hunter always"*.
--
-- FROZEN and MEMOISED for `owedTeams`' reason above, and derived from the owned sets this owner
-- already holds -- so it cannot disagree with what he bought, and there is nothing extra to save.
--
-- EMPTY when the shop is off, when nobody owns the row and in every spec that starts no money,
-- which is what makes `Roster.owedWith` answer BY IDENTITY and the game before this task bit for
-- bit.
function Economy.alwaysHunters(): { [number]: boolean }
	local cached = alwaysFrozen
	if cached == nil then
		local built: { [number]: boolean } = {}
		for userId, owned in pairs(ownedSets) do
			if ShopData.grantsAlwaysHunter(owned) then
				built[userId] = true
			end
		end
		cached = table.freeze(built)
		alwaysFrozen = cached
	end
	return (cached :: any) :: { [number]: boolean }
end

-- THE ONE WRITER OF `nextTeam`, AND IT DERIVES NOTHING. It is told each player's next team and it
-- stores exactly that -- which is hazard 2's lesson and the reason `Store.save` stopped deriving in
-- task 178: a `save` that computed the turn would have had to know which EVENT it was being called
-- for, and the two callers mean opposite things (the team he is playing, and the team he is owed
-- next). The rule that tells them apart is pure and lives at the caller (`Roster.invert`).
--
-- Returns HOW MANY ROWS IT WROTE, so a spec can assert a number rather than a feeling.
--   * a userId with NO OPEN SESSION is skipped and counted. His key on disk is untouched, which is
--     what makes the profile-load race cost one drive and never the record (design section 5.4);
--   * a value `teamFromRecord` refuses is skipped and counted;
--   * THE CALLER'S TABLE IS READ AND NEVER RETAINED.
--
-- EVERY ACCEPTED ROW IS WRITTEN, even one whose value is already the stored one, and the reason is
-- that `Store.save` IS FREE: it writes the server-local copy and performs no network call, so the
-- figure a spec can hold this to is an exact one -- `save` rises by exactly 2N over a complete
-- drive of N players with open sessions, one at each edge (design section 8.6). A
-- write-if-different would have made that number depend on whether the previous drive's turn had
-- been honoured, which is a worse thing to own than one free call.
--
-- THE MEMO IS A DIFFERENT QUESTION and is invalidated only when a row's VALUE actually moved: the
-- memo exists because `Match.dispatch` reads it ~60 times a second, and rebuilding it for a write
-- that changed nothing would throw that away.
function Economy.noteNextTeams(teams: { [number]: any }): number
	if not enabled then
		return 0
	end
	local written = 0
	for userId, value in pairs(teams or {}) do
		local team = Economy.teamFromRecord(value)
		if team == nil then
			stats.nextTeamRefused += 1
		elseif sessions[userId] == nil then
			stats.nextTeamSkippedNoProfile += 1
		else
			if nextTeams[userId] ~= team then
				nextTeams[userId] = team
				invalidateOwed()
			end
			local current = store
			if current then
				current.save(userId, { nextTeam = team })
			end
			stats.nextTeamsWritten += 1
			written += 1
		end
	end
	return written
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

-- WHAT HE HAS BOUGHT, as a FROZEN COPY so no reader can write the set it was handed -- the shape
-- `Economy.balances` already uses. `nil`, NOT `{}`, for a player with no open profile, and the
-- difference is load-bearing: every reader of what ownership GIVES treats nil as "nobody answered,
-- leave the game as it was" (docs/design/shop.md section 7.1), so a refused session lock or a
-- DataStore outage cannot take away the rifle a man paid for.
function Economy.ownedOf(userId: number): { [string]: boolean }?
	local set = ownedSets[userId]
	if set == nil then
		return nil
	end
	return table.freeze(table.clone(set))
end

-- HOW MANY DRIVES HE HAS FINISHED AND BEEN PAID FOR -- the number the shop's hunt gates read. It is
-- the profile's `drivesPaid` and there is no second field (design section 8.3): one event, one
-- increment, and this accessor is the one reader outside `Store`, so the day the key is renamed one
-- function changes.
function Economy.huntsOf(userId: number): number?
	if sessions[userId] == nil then
		return nil
	end
	return huntsCache[userId] or 0
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
			-- THE TWO DERIVED PROFILE FIELDS, INCREMENTED HERE AND NOWHERE ELSE (task 178, design
			-- section 8.2b). `Store.save` used to do both and had to stop: a purchase calls `save`
			-- too, and a `save` that counted a drive would have counted a hat as a completed hunt.
			-- This is where the DELTA and the EVENT are both known, which is the whole argument.
			huntsCache[userId] = (huntsCache[userId] or 0) + 1
			earnedTotals[userId] = (earnedTotals[userId] or 0) + math.max(0, after - before)
			local current = store
			if current then
				current.save(userId, {
					coins = after,
					drivesPaid = huntsCache[userId],
					coinsEarnedTotal = earnedTotals[userId],
				})
			end
		end
	end
	earnedThisDrive = nextEarned
	stats.drivesPaid += 1
	return receipt
end

-- ------------------------------------------------------------------------------- the purchase

-- NOT `Receipt`, which this module already exports for a PAY-OUT (the Reviewer's round-1 note):
-- two type declarations of one name in one file make `payDrive`'s annotated return ambiguous to a
-- reader, even though types are erased at run time.
export type PurchaseReceipt = {
	ok: boolean,
	item: string?,
	price: number?,
	balance: number?,
	refused: string?, -- one of `Shop.REASON`
	refusedNumber: number?, -- the number its line prints: money short, or hunts short
	-- HE ALREADY HAD IT (task 221). `ok = true` and NOTHING WAS WRITTEN -- the shape Roblox's
	-- `ProcessReceipt` contract needs, because a refusal for an already-granted receipt would make
	-- it retry for ever.
	already: boolean?,
}

-- ---------------------------------------------------------------- the one grant path (task 221)
--
-- WHERE THE ENTITLEMENT CAME FROM. Karen will also sell these for Robux (task 222, which needs her
-- Creator Dashboard), and the whole of what task 221 owes it is that a Robux receipt grants the
-- same entitlement through the same owner by the same function.
Economy.SOURCE = table.freeze({
	MONEY = "money",
	ROBUX = "robux",
})

-- THE ONE WRITER OF THE OWNED SET, EITHER IN MEMORY OR ON THE KEY, AND IT NEVER YIELDS.
--
-- IDEMPOTENT, AND THAT IS A CONTRACT RATHER THAN A CONVENIENCE: Roblox documents that
-- `ProcessReceipt` is called AGAIN for a receipt that was not confirmed, including after a server
-- restart, so a second call must be a SUCCESS and not a refusal -- a refusal would make Roblox
-- retry for ever and the player would be charged with nothing to show for it. An entitlement SET
-- is naturally idempotent, which is why no receipt-id ledger is kept: granting a row twice is the
-- same set, and a second store of the same fact is the thing this owner exists to avoid.
--
-- WHAT IT CHECKS, AND NOTHING ELSE. It does NOT check the price, the hunt gate, the counter or the
-- balance: those are `Economy.purchase`'s rules and Roblox's, and keeping them out of here is the
-- whole point of the split.
--
-- A RETIRED ID CANNOT BE GRANTED and NEITHER CAN THE RED STAG CARD: `ShopData.row` answers only
-- what is for sale, and `sale ~= true` is refused below -- so there is no path in this repository
-- that hands over a row Karen has taken off the shelf or an animal that does not exist.
function Economy.grant(userId: number, itemId: any, source: string): PurchaseReceipt
	if not enabled then
		return { ok = false, refused = ShopData.REASON.CLOSED }
	end
	if sessions[userId] == nil then
		return { ok = false, refused = ShopData.REASON.NO_PROFILE }
	end
	local row = ShopData.row(itemId)
	if row == nil then
		return { ok = false, refused = ShopData.REASON.UNKNOWN }
	end
	if (row :: ShopData.Row).sale ~= true then
		return { ok = false, refused = ShopData.REASON.NOT_SALE }
	end
	local id = (row :: ShopData.Row).id
	-- ALREADY HIS: a SUCCESS, and nothing is written. `ShopData.owns` and NOT `ownedOrCovered` --
	-- a bundle covering a row is not that row, and a receipt for that row must still write it.
	if ShopData.owns(ownedSets[userId], id) then
		stats.grantsAlready += 1
		return { ok = true, item = id, balance = balances[userId], already = true }
	end
	-- THE SET, REPLACED WHOLE rather than written into (shop design section 9.1). `ownedOf` hands
	-- out frozen copies and a reader may be holding one, and a replaced table is what makes "no
	-- previous state can linger" provable -- `earnedThisDrive`'s own rule.
	local nextOwned: { [string]: boolean } = {}
	for owned in pairs(ownedSets[userId] or {}) do
		nextOwned[owned] = true
	end
	nextOwned[id] = true
	ownedSets[userId] = nextOwned
	-- THE MEMO OF WHO IS OWED THE HUNTER'S PLACE IS NOW STALE (task 221). Every writer of
	-- `ownedSets` calls this, which is the `invalidateOwed` discipline verbatim.
	invalidateAlways()
	stats.grants += 1
	stats.grantsBySource[source] = (stats.grantsBySource[source] or 0) + 1
	local current = store
	if current then
		-- TWO FIELDS, AND NOTHING DERIVED. A purchase is not a drive: `drivesPaid` is not touched,
		-- which is hazard 2 closed. The balance is READ rather than passed in, so a Robux grant --
		-- which debits nothing of ours -- saves the balance he already had.
		current.save(userId, { coins = balances[userId], owned = nextOwned })
	end
	return { ok = true, item = id, balance = balances[userId] }
end
-- THE ONLY WRITER OF A PURCHASE, EITHER HALF OF IT, AND IT NEVER YIELDS (task 178).
--
-- TEST, THEN EXECUTE -- OpenTTD's `CommandCost` (docs/research/2026-10-14-the-shop.md section 2.3),
-- the shape `Weapon.Rules.refuse` already brought into this repo. `ShopData.refuse` is the whole
-- test and it is PURE; everything below the refusal is the whole execution. Between them nothing
-- yields: `Store.save` performs no network call by contract and Luau is single-threaded per server,
-- so the test and the execute are atomic BY CONSTRUCTION rather than by a lock -- the identical
-- claim `payDrive` makes, for the identical reason.
--
-- IT RE-ASKS TWO FACTS THE DOOR HAS ALREADY SEEN, and that is defence in depth rather than a second
-- rule: this owner holds the balance and the set, so it is the only thing that can promise a balance
-- never goes below zero and an item is never charged twice. The reason it answers is the one the
-- screen prints, so a disagreement between the door and the till shows up as a line rather than as
-- a wrong balance.
--
-- `facts.atCounter` IS THE DOOR'S MEASUREMENT, passed in because this owner reads no Instance at
-- all (its own header). nil means "nobody measured", which does not refuse -- the rule `Weapon`'s
-- gate applies to every injected fact.
function Economy.purchase(userId: number, itemId: any, facts: { atCounter: boolean? }?): PurchaseReceipt
	local reason, number = ShopData.refuse({
		itemId = itemId,
		coinsOn = enabled,
		hasProfile = sessions[userId] ~= nil,
		atCounter = if facts ~= nil then facts.atCounter else nil,
		owned = ownedSets[userId],
		balance = balances[userId],
		hunts = huntsCache[userId],
	})
	if reason ~= nil then
		stats.purchasesRefused += 1
		stats.refusedBy[reason] = (stats.refusedBy[reason] or 0) + 1
		return { ok = false, refused = reason, refusedNumber = number }
	end
	local row = ShopData.row(itemId) :: ShopData.Row
	local before = balances[userId] or 0
	-- THE COINS. The floor is not reached here -- `ShopData.refuse` has already answered `poor` for
	-- anything he cannot pay -- so this subtraction cannot go negative.
	balances[userId] = before - row.price
	stats.purchases += 1
	stats.coinsSpent += row.price
	-- ...AND THE SET, THROUGH THE ONE WRITER OF IT (task 221). `grant` is what performs the single
	-- `store.save`, and it READS the live balance rather than being told it -- so the profile write
	-- still happens once, with both fields, and nothing yields between the debit and it.
	local receipt = Economy.grant(userId, itemId, Economy.SOURCE.MONEY)
	receipt.price = row.price
	return receipt
end

-- ----------------------------------------------------- the Robux door (task 238; planned by 222)
--
-- `MarketplaceService.ProcessReceipt`'s BODY, AND THE ONLY PLACE A ROBUX PURCHASE IS GRANTED.
-- Karen, 2026-10-21: *"and then you want to buy and roblox popup like they do to purchase"*.
--
-- `docs/design/economy-v1.md` section 11 wrote this function's shape before it existed: *"The Robux
-- door (task 222) will be `ProcessReceipt` -> `grant(..., Economy.SOURCE.ROBUX)`"*. That is all it
-- is. It writes nothing itself, holds no state and keeps no ledger: `Economy.grant` above is still
-- the one writer of the owned set and still performs the one `store.save`.
--
-- PURE OF ROBLOX, AND THAT IS WHY IT IS TESTABLE. It takes the `receiptInfo` table and ANSWERS A
-- STRING -- `"granted"` or `"not-processed"` -- rather than an `Enum.ProductPurchaseDecision`, so a
-- spec drives both branches with a hand-written table and no MarketplaceService at all. The boot
-- line that installs the callback is the one place the string becomes the enum
-- (`Economy.DECISION`), which is the seam `Weapon.onFireRequest` and `Shop.onRequest` already are.
--
-- IDEMPOTENT, AND **NOT** BY A `PurchaseId` LEDGER. Roblox documents that the callback is retried
-- *"until it returns `Enum.ProductPurchaseDecision.PurchaseGranted`"*, including on the player's
-- next join, so the same `PurchaseId` arrives twice; its own sample answers that with a per-player
-- DataStore list of receipt ids. **This repository refuses that list**, for the reason already
-- written in `Economy.grant`'s header and in the design: *"an entitlement SET is naturally
-- idempotent... a second store of the same fact is the thing this owner exists to avoid"*.
--
-- For a NON-CONSUMABLE that is strictly stronger rather than a shortcut. A redelivered receipt
-- reaches `grant`, which finds the row already in the set and answers `{ok = true, already = true}`
-- having written nothing -- a SUCCESS, so Roblox stops retrying, with no second charge, no second
-- write and no window between the grant and the record of the grant. The ledger's own two famous
-- failures are exactly that window (the note's source 2: the sample has shipped both *"the same
-- paid items with every server join"* and a version that ate the charge).
--
-- **THE LIMIT, AND IT IS THE ONE THING THAT WOULD MAKE THIS WRONG LATER (the note's section 3.5):
-- this holds for non-consumables ONLY.** The day a COIN PACK is sold for Robux, granting twice
-- really does double the goods, the set stops being the record, and a `PurchaseId` ledger becomes
-- necessary. No row in this catalogue grants a consumable -- `Shop.GRANT_FIELDS` has no `coins`
-- entry, so no row CAN -- and the invariant holding the line today is `rowsOk`'s **I12**, which
-- refuses any non-nil `robuxProductId` outright. (I13 is the `anywhere` rule and reads no product
-- id; an earlier draft of this paragraph named it here and the Reviewer caught it.) The day a
-- consumable is sold for Robux, I12 comes off and the ledger goes on in the same commit.
--
--   ProcessReceipt  https://create.roblox.com/docs/reference/engine/classes/MarketplaceService
--
-- Note: docs/research/2026-10-22-licence-popup-and-robux.md sections 3.4 and 3.5
Economy.DECISION = table.freeze({
	GRANTED = "granted",
	NOT_PROCESSED = "not-processed",
})

-- THE ONE PLACE A DECISION STRING BECOMES ROBLOX'S ENUM. Two lines, so the Enum appears exactly
-- once in the repository and `Economy.processReceipt` stays drivable with no engine types at all.
function Economy.decisionEnum(decision: string?): Enum.ProductPurchaseDecision
	return if decision == Economy.DECISION.GRANTED
		then Enum.ProductPurchaseDecision.PurchaseGranted
		else Enum.ProductPurchaseDecision.NotProcessedYet
end

-- IS THE ROBUX DOOR INSTALLED IN THIS ENVIRONMENT? PURE, so both answers are a case rather than an
-- `if` nobody can reach (`Economy.storeKindFor`'s own shape, and for the same reason).
--
-- NOT IN STUDIO. A receipt cannot arrive there -- there is no developer product in this build at all
-- (`Shop.rowsOk`'s I12) -- and writing a service callback from a harness run would make every spec
-- that calls `Economy.start` a writer of `MarketplaceService`. `given == false` refuses it
-- outright, which is what a spec that wants the OFF branch passes.
function Economy.installsReceiptHandler(given: any, isStudio: boolean): boolean
	if given == false then
		return false
	end
	if given ~= nil then
		return true
	end
	return not isStudio
end

function Economy.processReceipt(receiptInfo: any, rows: any?): string
	stats.receipts += 1
	if type(receiptInfo) ~= "table" then
		stats.receiptsUnknown += 1
		return Economy.DECISION.NOT_PROCESSED
	end
	local userId = (receiptInfo :: any).PlayerId
	local productId = (receiptInfo :: any).ProductId
	if type(userId) ~= "number" then
		stats.receiptsUnknown += 1
		return Economy.DECISION.NOT_PROCESSED
	end
	-- WHICH ROW THIS PRODUCT IS, through the one pure reverse lookup. nil for a product no row
	-- carries -- a stale id of Karen's, or two rows sharing one -- and then NOT the player's fault:
	-- `NOT_PROCESSED` leaves Roblox holding the charge and retrying, which is the honest answer to
	-- "I do not know what you just bought". Granting nothing and answering `GRANTED` would take his
	-- Robux for nothing.
	local itemId = ShopData.itemForProduct(productId, rows)
	if itemId == nil then
		stats.receiptsUnknown += 1
		warn(
			string.format(
				"[economy] a Robux receipt for product %s matches no catalogue row: it is left unprocessed "
					.. "and Roblox will redeliver it.",
				tostring(productId)
			)
		)
		return Economy.DECISION.NOT_PROCESSED
	end
	-- THE ONE WRITER, and `SOURCE.ROBUX` is already in the enum with `grantsBySource` already
	-- counting it (task 221 built both for this day). A refusal here is `NO_PROFILE` (his session is
	-- not open on this server -- he just joined, or another server holds his lock) or `CLOSED` or
	-- `UNKNOWN`; every one of them is a reason to RETRY rather than to confirm.
	local receipt = Economy.grant(userId, itemId :: string, Economy.SOURCE.ROBUX)
	if receipt.ok ~= true then
		stats.receiptsNotProcessed += 1
		return Economy.DECISION.NOT_PROCESSED
	end
	stats.receiptsGranted += 1
	if receipt.already == true then
		-- THE REDELIVERY, counted apart because it is the number that says the idempotency is
		-- actually being exercised in a live server rather than only in a spec.
		stats.receiptsAlready += 1
	end
	return Economy.DECISION.GRANTED
end

-- WHAT ONE PLAYER'S PANEL IS TOLD: his own wallet, and the catalogue already decided against it.
-- A WALLET IS ONE PLAYER'S BUSINESS, so it goes out by `FireClient` and never in a broadcast.
--
-- `rows` IS BUILT BY THE PURE `ShopData.rowsFor`, so `buyable` is computed ONCE, on this side, and
-- is the only field the panel's button reads: two readers of "can he buy this" is how a greyed-out
-- button and an accepted purchase disagree (design hazard 10).
--
-- `atCounter` IS DELIBERATELY NOT PASSED. The reach is the DOOR's rule, measured per request; a
-- panel that greyed every button the moment he stepped back would be a second reader of it.
function Economy.shopStateFor(userId: number, receipt: PurchaseReceipt?): ShopData.State
	local balance = balances[userId]
	local hunts = huntsCache[userId] or 0
	return {
		coinsOn = enabled,
		balance = balance,
		hunts = hunts,
		rows = ShopData.rowsFor(ownedSets[userId], balance, hunts, enabled),
		refused = if receipt ~= nil then receipt.refused else nil,
		refusedNumber = if receipt ~= nil then receipt.refusedNumber else nil,
		bought = if receipt ~= nil and receipt.ok == true then receipt.item else nil,
	}
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
		local profile, reason = nil, nil
		if current then
			profile, reason = current.load(userId)
		end
		inFlight[userId] = nil
		stats.loads += 1
		if profile == nil then
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
		-- THE PROJECTION IS THIS OWNER'S, which is why `Store.load` hands over the whole profile
		-- (design section 8.2b): the store knows how to read a key, and the owner knows which fields
		-- it wants. Four of them, each defended against a corrupted key -- `Store.read` fills a
		-- missing one and type-checks a table, and a number that came back as a string would
		-- otherwise poison every sum after it.
		local data = profile :: { [string]: any }
		balances[userId] = if type(data.coins) == "number" then data.coins else 0
		ownedSets[userId] = if type(data.owned) == "table" then table.clone(data.owned) else {}
		-- THE ALWAYS-HUNTER MEMO IS STALE THE MOMENT A SET CHANGES (task 221).
		invalidateAlways()
		huntsCache[userId] = if type(data.drivesPaid) == "number" then data.drivesPaid else 0
		earnedTotals[userId] = if type(data.coinsEarnedTotal) == "number" then data.coinsEarnedTotal else 0
		-- THE TURN (task 217), the fifth projected field and the only one with a VALIDATOR rather
		-- than a `type` check: `""` is the template's own default and means *no turn stored*, so the
		-- "is it one of the two team names" question cannot be asked with `type` alone.
		nextTeams[userId] = Economy.teamFromRecord(data.nextTeam)
		invalidateOwed()
		-- THE STUDIO TEST GRANT (task 178), applied to the IN-MEMORY copy and never saved: in Studio
		-- the store is the memory one anyway, so there is nothing to persist and nothing to undo.
		-- It RAISES rather than sets, so a player who has already earned more keeps what he earned,
		-- and it buys nothing for him -- every item is still a button he has to press.
		local grant = testGrant
		if grant ~= nil then
			balances[userId] = math.max(balances[userId], grant.coins)
			huntsCache[userId] = math.max(huntsCache[userId], grant.hunts)
			stats.testGrants += 1
		end
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
	ownedSets[userId] = nil
	invalidateAlways()
	huntsCache[userId] = nil
	earnedTotals[userId] = nil
	-- THE TURN'S ROW GOES WITH THE SESSION (task 217) AND THE KEY ON DISK KEEPS IT. A player who
	-- left reads as *no turn stored* to the drive -- which is correct, because he is not in it -- and
	-- the value `Store.release` has just saved is what his next `load` reads back. That round trip IS
	-- the feature.
	nextTeams[userId] = nil
	invalidateOwed()
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
	table.clear(ownedSets)
	invalidateAlways()
	table.clear(huntsCache)
	table.clear(earnedTotals)
	table.clear(nextTeams)
	invalidateOwed()
	return ended
end

-- ------------------------------------------------------------------------------- the view

export type View = {
	payDrive: (driveNumber: number, rows: any) -> (),
	balances: () -> { [number]: number },
	earned: () -> { [number]: number },
	-- IS THERE MONEY IN THIS BUILD AT ALL (round 2, finding 1)? The drive has to be able to ask,
	-- because the SCREEN has to tell "the economy is off" from "this player has no profile open" --
	-- and both of those look identical from the rows alone: no `coins` field either way. It answers
	-- the FLAG's resolved value and nothing about any player, so it is still not a setter and still
	-- not a rule number: a client that learns coins are on learns what it can already see.
	enabled: () -> boolean,
	-- WHAT A PLAYER HAS BOUGHT (task 178), as a frozen copy or nil. READ-ONLY, like the three
	-- above: the drive asks it to answer two questions it already owns -- may this beater carry a
	-- gun (`Match.mayCarryWeapon`) and what colour is his hat (`Match.Body`) -- and it cannot write
	-- a set, cannot buy anything and cannot reach the store.
	ownedOf: (userId: number) -> { [string]: boolean }?,
	-- WHOSE TURN IS WHICH (task 217): userId -> the team he must be given at his next assignment, as
	-- a FROZEN, MEMOISED table. READ-ONLY, like the four above, and the drive reads it on every event
	-- (`Match.dispatch`, the `aliveBoars` idiom) to hand it to the pure roster as a SUGGESTION --
	-- `Roster.assign`'s balance rule may discard it entirely, and nothing is consumed when it does.
	owedTeams: () -> { [number]: TeamName },
	alwaysHunters: () -> { [number]: boolean },
	-- ...AND THE ONE NAMED WRITE, in `payDrive`'s shape and not a setter: the drive is the only thing
	-- that knows who played which role, so it has to be able to say so. It names no profile field --
	-- this owner chooses that -- and it DERIVES NOTHING: the rotation rule is pure and lives at the
	-- caller (`Roster.invert`).
	--
	-- WHAT THE DRIVE STILL CANNOT DO THROUGH THIS VIEW: open a session, end one, read or write a
	-- balance, read or write a hunt count, buy or grant anything, name a profile field, reach
	-- `Store`, reach ProfileStore, reach `DataStoreService`, start or stop this owner, or write any
	-- row for a userId whose profile is not open.
	noteNextTeams: (teams: { [number]: any }) -> (),
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
		enabled = Economy.isEnabled,
		ownedOf = Economy.ownedOf,
		owedTeams = Economy.owedTeams,
		-- WHO BOUGHT THE HUNTER'S PLACE (task 221). A read-only projection, like every other member
		-- here: the drive still cannot open a session, write a balance, name a profile field or buy
		-- anything through this table.
		alwaysHunters = Economy.alwaysHunters,
		noteNextTeams = function(teams: { [number]: any })
			Economy.noteNextTeams(teams)
		end,
	}
end

-- ------------------------------------------------------------------------------- lifecycle

export type World = {
	store: Store?,
	players: any?,
	enabled: boolean?,
	-- THE STUDIO TEST GRANT (task 178): a table to grant it, `false` to refuse it whatever the
	-- attribute says, nil to ask the two production facts. Every spec passes one of the first two,
	-- which is what keeps both branches reachable while the attribute is set in one Studio only.
	testGrant: any?,
	-- WHERE `ProcessReceipt` IS INSTALLED (task 238). nil asks the production fact (is this Studio);
	-- `false` installs nothing whatever the environment says; a table is a stand-in a spec can read
	-- the installed callback back off. Every spec written before task 238 passes nil and installs
	-- nothing, because the harness runs in Studio.
	marketplace: any?,
}

-- NOTHING HAPPENS ON REQUIRE. `injected.enabled` is what makes both branches of the flag reachable
-- by parameter while the flag sits at one of them; `injected.store` is what lets a spec drive the
-- whole owner with no library, no network and no DataStore.
function Economy.start(injected: World?)
	assert(not started, "Economy.start called twice")
	local world = injected or {}
	enabled = if world.enabled ~= nil then world.enabled else Economy.CONFIG.ENABLED
	players = world.players or Players
	-- THE ONE READ OF THE TEST GRANT, at this owner's boundary, passed inward exactly as the flag
	-- is: a spec says `testGrant = { coins = ..., hunts = ... }` or `false`, and production asks the
	-- two facts that have to be true together (see `Economy.testGrantFor`).
	if world.testGrant ~= nil then
		testGrant = if world.testGrant == false then nil else world.testGrant
	else
		testGrant = Economy.testGrantFor(
			RunService:IsStudio(),
			ServerStorage:GetAttribute(Economy.TEST_GRANT_ATTRIBUTE),
			Economy.CONFIG
		)
	end
	paidUpTo = 0
	resetStats()
	table.clear(balances)
	table.clear(sessions)
	table.clear(inFlight)
	table.clear(ownedSets)
	invalidateAlways()
	table.clear(huntsCache)
	table.clear(earnedTotals)
	table.clear(nextTeams)
	invalidateOwed()
	earnedThisDrive = {}
	started = true

	if not enabled then
		-- OFF CONNECTS NOTHING AND LOADS NOTHING. The absence of data is what makes the rest of the
		-- game identical to before this task.
		store = nil
		print("[economy] coins=off (born dark, task 170): no session is opened and no key is written")
		return
	end

	-- THE ROBUX DOOR (task 238). ONE assignment, in the owner that performs the grant, so a grep for
	-- `ProcessReceipt` under `src/` finds this line and `Economy.processReceipt` and nothing else.
	--
	-- IT IS INSTALLED EVEN THOUGH NOTHING CAN ARRIVE THROUGH IT, and that is the point: the moment
	-- Karen puts a `robuxProductId` on a row, `ShopPanel.press` will prompt Roblox for real money,
	-- and a prompt with no `ProcessReceipt` behind it charges the player and retries for ever with
	-- nothing granted. Wiring the door in the same task as the prompt is what makes that state
	-- unreachable rather than documented.
	--
	-- WHERE THAT STOPS, SAID PLAINLY (the Reviewer's round-1 note): this sits BELOW the `not enabled`
	-- return above, so with `COINS` off no handler is installed. Harmless today -- no row carries a
	-- product id, so nothing can prompt -- and it is the honest place for it: a build with the money
	-- switched off has no purchases of any currency. The day a row carries an id, `COINS` being off
	-- must also mean the shop is off, which `Shop.start`'s own gate already says.
	if Economy.installsReceiptHandler(world.marketplace, RunService:IsStudio()) then
		local service = if world.marketplace ~= nil and world.marketplace ~= false
			then world.marketplace
			else MarketplaceService
		service.ProcessReceipt = function(receiptInfo)
			return Economy.decisionEnum(Economy.processReceipt(receiptInfo))
		end
	end

	if world.store then
		store = world.store
	else
		-- THE ONE DECISION THAT KEEPS STUDIO OFF THE LIVE KEYS, and it is a pure predicate so it can
		-- be asserted from inside Studio (`Economy.storeKindFor`).
		local kind = Economy.storeKindFor(RunService:IsStudio())
		if kind == "memory" then
			store = StoreModule.memory()
		else
			-- A LIVE STORE THAT CANNOT BE BUILT MUST NOT TAKE THE SERVER DOWN WITH IT (round 1
			-- note 2). `Store.live` refuses loudly when the package tree is missing -- it is an
			-- OPTIONAL Rojo path, so a build without `wally install` really has none -- and this runs
			-- INSIDE `Economy.start`, which both composition roots call BEFORE `Match.start`. Letting
			-- that error through would cost the whole drive in order to save nothing; falling back
			-- costs only the money, says so in the console, and leaves the game running.
			local ok, built = pcall(StoreModule.live, Economy.CONFIG.STORE_NAME)
			if ok then
				store = built
			else
				stats.storeFellBack += 1
				warn(
					string.format(
						"[economy] the live store could not be built (%s): falling back to memory, so NOTHING IS"
							.. " SAVED on this server. The drive runs; the coins do not persist.",
						tostring(built)
					)
				)
				store = StoreModule.memory()
			end
		end
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
		-- ...AND WHAT HE OWNS, for the same stated reason: *"after the `Profile.OnSessionEnd` signal
		-- is fired, no further changes to `Profile.Data` should be made"*. A purchase into a dead
		-- table is exactly what dropping the row prevents -- and the readers then see nil, which is
		-- "nobody answered" and leaves his gun as it was (design section 7.1).
		ownedSets[userId] = nil
		invalidateAlways()
		huntsCache[userId] = nil
		earnedTotals[userId] = nil
		-- ...AND THE TURN'S ROW (task 217), for the same sentence: a `Store.save` into a dead table
		-- is what dropping the row prevents. He reads as *no turn stored* until a session opens
		-- again, and what is on his key is whatever the last live write put there -- so a stolen
		-- session costs the turn for that server and never corrupts the record (hazard 3).
		nextTeams[userId] = nil
		invalidateOwed()
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
	-- SAID OUT LOUD, ONCE, because a session where everybody is rich must never be a surprise: this
	-- is the one line that tells a reader of the console why a playtest could afford a rifle.
	if testGrant ~= nil then
		print(
			string.format(
				"[economy] %s=true in Studio: every profile this session is topped up to %d coins and %d hunt(s)."
					.. " Nothing is saved (the store is the in-memory one) and no item is bought for anybody.",
				Economy.TEST_GRANT_ATTRIBUTE,
				testGrant.coins,
				testGrant.hunts
			)
		)
	end

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
	testGrant = nil
	enabled = false
	started = false
	paidUpTo = 0
	table.clear(balances)
	table.clear(sessions)
	table.clear(inFlight)
	table.clear(ownedSets)
	invalidateAlways()
	table.clear(huntsCache)
	table.clear(earnedTotals)
	table.clear(nextTeams)
	invalidateOwed()
	earnedThisDrive = {}
end

return Economy
