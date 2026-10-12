--!strict
-- Match.Phase: the whole match state machine, PURE. `(state, event, now, config) -> (state, effects)`.
-- No service, no Instance, no clock, no Player, no Random. It cannot respawn anybody, so it SAYS what
-- must happen and the owner does it -- and that split is what lets tests/server/match_phase.spec.luau
-- run a whole 600-second drive, with joins, leaves, kills and a server hitch, in milliseconds with no
-- players and no world.
--
-- Pattern: a reducer returning a new frozen state plus an explicit list of effects -- Redux's shape
-- with the side effects made values instead of middleware, which is the part Rodux leaves out and
-- the reason the package is named and not adopted (docs/research/2026-09-25-drive.md source E; and
-- the note corrects the design: Rodux is NOT archived).
--   Boar.Brain and Weapon.StateMachine are the same shape in this repo already.
--
-- EVERY TRANSITION IS TIME-DRIVEN FROM phaseEndsAt, AND phaseEndsAt IS THE ONLY CLOCK. There is no
-- task.delay, no task.wait and no second timer in this system: a hitch cannot skip a phase, and a
-- spec can run ten minutes in a few milliseconds of simulated dt.
--
-- THE END OF A DRIVE IS `Scoring`, AND TASK 159 ADDED NO PHASE EITHER (Karen: *"Timer or when all
-- beaters cross line of hunters. And yes could be that all they standing around the animals there is
-- light on 4 corners and then showing image transperent with results table"*). A drive now ends on
-- EITHER of two conditions and they both enter the one `Scoring` phase, whose deadline is still
-- `SCORE_SECONDS` and still the only clock:
--   * the drive clock, exactly as before -- `now >= phaseEndsAt`;
--   * every REAL beater is through the hunters' line, which this machine asks as one pure question
--     (`Phase.beatersThrough`) of two numbers the owner measures (`event.beaters`,
--     `event.beatersAcross`). With no real beater on the map it is false by construction, so a solo
--     hunter's drive still ends on the clock and nothing else.
-- What is new is `endedEarly` (which of the two it was, for the feed line) and two effects, `scene`
-- and `clearScene`, plus the `hold` that keeps everybody at the results scene -- the SAME hold task
-- 158 built, applied to everybody instead of to the beaters.
--
-- ONE RULE ABOUT THE ORDER OF THESE EFFECTS, AND IT WAS PAID FOR TWICE: **a `hold` or a `free` is
-- emitted BEFORE the `placePlayers` it goes with.** `placePlayers` is the only effect here whose
-- owner YIELDS (`Player:LoadCharacter`), the drive is already in its new phase while it yields, and
-- anything that looks at the drive in that window -- a client, a broadcast, a spec -- would
-- otherwise see a started drive whose beaters are not yet held. Measured by the two-player run of
-- task 159 (`[harness2] FAIL 33/35 @ 7ea945f`); invisible with one player, because a solo player is
-- never a beater.
--
-- THE START OF A DRIVE IS `Assigning`, AND TASK 158 ADDED NO PHASE (Karen: *"timer when start,
-- timer like 10s to find position to stand"*, *"Beater start in line with others and countdown when
-- drive starts"*). The countdown IS this machine's existing intermission: one phase, one deadline,
-- and `phaseEndsAt` is still the only clock -- so the hunter's stand timer, the beater's countdown
-- and the start card are all the SAME number counted down locally, and they cannot disagree. What is
-- new is two effects, `hold` and `free`, and `Phase.heldUserIds` to say who.
--
-- Design: docs/design/drive.md (section 4)
-- Note:   docs/research/2026-09-25-drive.md
local Roster = require(script.Parent.Roster)

local Phase = {}

export type PhaseName = "Waiting" | "Assigning" | "Running" | "Scoring"
export type TeamName = Roster.TeamName

export type State = {
	phase: PhaseName,
	phaseEndsAt: number,
	driveNumber: number,
	participants: { [number]: string }, -- userId -> name
	assignment: { [number]: TeamName },
	previousAssignment: { [number]: TeamName }?,
	markersComplete: boolean,
	missing: { string },
	boarSpawns: { Vector3 },
	-- THE QUICK TEST'S OWN SPAWN (task 83, Studio only): on the road in front of the shooters,
	-- computed by the owner from the drive-line marker because the owner is what reads markers. Nil
	-- whenever the quick test is off, which is what makes every branch below a one-line question.
	quickSpawn: Vector3?,
	-- A RELEASE IS A SOUNDER OF `size` ANIMALS, so the two counts are different questions: the
	-- BUDGET is boars (BOARS_PER_DRIVE), and the RHYTHM -- which marker, which jitter index -- is
	-- sounders. With the flag off every size is 1 and the two are equal, which is what makes the
	-- flag-off schedule the same schedule as before this task (design, "the sounder release").
	boarsReleased: number,
	soundersReleased: number,
	-- Consecutive hold-backs of the sounder currently due: a stall made visible instead of
	-- folkloric (SOUNDER.HOLDBACK_WARN). Reset by a release that happens.
	holdbacks: number,
	nextReleaseAt: number,
	boarsAccounted: number, -- killed + escaped this drive
	-- WHICH OF THE TWO ENDINGS ENDED THE LAST DRIVE (task 159): true when every real beater was
	-- through the hunters' line before the clock ran out. It is the feed line's own word and nothing
	-- else reads it -- the results scene is the same scene either way.
	endedEarly: boolean,
	seed: number,
}

export type Event = {
	kind: string, -- "tick" | "join" | "leave" | "kill" | "gone" | "violation" | "markers" | "team"
	userId: number?,
	name: string?,
	-- "team": the side a world has asked this player to be on (task 157). Read by that branch only.
	team: TeamName?,
	record: any?,
	at: number?,
	aliveBoars: number?,
	-- EVERYTHING the runtime holds, carcasses included, and what it will hold at most. A carcass
	-- occupies a slot for CARCASS_SECONDS and `aliveBoars` does not count it, so a drive that has
	-- killed four can still be at the runtime's ceiling (design section 6.3, hazard 2).
	boarEntries: number?,
	boarCapacity: number?,
	complete: boolean?,
	missing: { string }?,
	boarSpawns: { Vector3 }?,
	quickSpawn: Vector3?,
	-- THE END OF A DRIVE, MEASURED BY THE OWNER AND DECIDED HERE (task 159): how many REAL beaters
	-- are in this drive, and how many of them are through the hunters' line. Two numbers, because
	-- "all of them" is a comparison and not a boolean somebody else already took -- and because with
	-- `beaters = 0` the question answers itself.
	beaters: number?,
	beatersAcross: number?,
}

export type Effect = {
	kind: string,
	-- "spawnSounder": how far from `position` the ring may spread, when the caller knows better than
	-- the map's spawn pad. The quick test does: it spawns on the road (task 83).
	spread: number?,
	force: boolean?, -- "broadcast": a phase change, which no client may miss behind the throttle
	assignment: { [number]: TeamName }?,
	userId: number?, -- "freeze": the one player to tie to a tree
	-- "refreshArming" / "placePlayers": whom. "hold": whom to hold -- at the start line (task 158),
	-- or the whole roster at the results scene (task 159). "free": whom to let go, and NIL MEANS
	-- EVERYBODY HELD -- which is what the start of a drive means (task 158), and what the end of the
	-- results scene means (task 159).
	-- "scene" and "clearScene" carry nothing: the scene is built from the drive's own kills and the
	-- world's own geometry, which are the owner's to read, and taken down whole.
	userIds: { number }?,
	position: Vector3?,
	size: number?, -- "spawnSounder": how many animals this release is
	entry: any?,
}

local function freeze<T>(value: T): T
	if type(value) == "table" and not table.isfrozen(value :: any) then
		table.freeze(value :: any)
	end
	return value
end

local function freezeState(state: State): State
	freeze(state.participants)
	freeze(state.assignment)
	if state.previousAssignment then
		freeze(state.previousAssignment)
	end
	freeze(state.missing)
	freeze(state.boarSpawns)
	return freeze(state)
end

function Phase.initial(config): State
	return freezeState({
		phase = "Waiting" :: PhaseName,
		phaseEndsAt = math.huge,
		driveNumber = 0,
		participants = {},
		assignment = {},
		previousAssignment = nil,
		markersComplete = false,
		missing = { "markers" },
		boarSpawns = {},
		quickSpawn = nil,
		boarsReleased = 0,
		soundersReleased = 0,
		holdbacks = 0,
		nextReleaseAt = math.huge,
		boarsAccounted = 0,
		endedEarly = false,
		seed = config.SEED or 1,
	})
end

-- HOW LONG THE INTERMISSION IS, and HOW LONG AFTER THE DRIVE STARTS THE FIRST RELEASE IS. Two pure
-- questions with one branch each, so the quick test is a value rather than a second schedule: with
-- `QUICK_TEST` off they answer exactly what this drive has always answered (task 83).
function Phase.intermissionSeconds(config): number
	if config.QUICK_TEST then
		return config.QUICK_TEST_INTERMISSION_SECONDS
	end
	return config.INTERMISSION_SECONDS
end

function Phase.firstReleaseSeconds(config): number
	if config.QUICK_TEST then
		-- Not zero: a boar released at the drive's first tick is across the road before a player has
		-- loaded in. See the number's own comment in Match.CONFIG.
		return config.QUICK_TEST_FIRST_RELEASE_SECONDS
	end
	return config.FIRST_RELEASE_SECONDS
end

function Phase.isLive(state: State): boolean
	return state.phase == "Running"
end

function Phase.participantCount(state: State): number
	local n = 0
	for _ in pairs(state.participants) do
		n += 1
	end
	return n
end

-- Why it is waiting, in the words the Hud shows: "players", or the exact tag names that produced
-- nothing. A drive against half a map is worse than no drive (design section 6.2).
function Phase.waitingFor(state: State, config): { string }
	local reasons = {}
	if Phase.participantCount(state) < config.MIN_PLAYERS then
		table.insert(reasons, "players")
	end
	if not state.markersComplete then
		for _, tag in ipairs(state.missing) do
			table.insert(reasons, tag)
		end
	end
	return reasons
end

-- WHO IS HELD AT THE START LINE while the countdown runs (task 158). Karen: *"Beater start in line
-- with others and countdown when drive starts"* -- so the beaters are held and let go at GO, and a
-- HUNTER IS NEVER HELD, because the same ten seconds is the one he walks to his stand with
-- (*"timer like 10s to find position to stand"*).
--
-- The team is `config.START_HOLD_TEAM`, not a literal: "who is held" is then one value a spec drives
-- both ways, and this machine still knows nothing about what a beater is.
-- Sorted, so the effect a drive emits is the same list every time.
function Phase.heldUserIds(assignment: { [number]: TeamName }, config): { number }
	local ids = {}
	for userId, team in pairs(assignment) do
		if team == config.START_HOLD_TEAM then
			table.insert(ids, userId)
		end
	end
	table.sort(ids)
	return ids
end

-- EVERYBODY IN THE DRIVE, sorted -- the list the results scene is held by and laid out in (task
-- 159). `participants` is the roster of the drive, so a player who joined mid-drive is in the scene
-- and a player who left is not, with no second list to keep in step.
function Phase.participantIds(state: State): { number }
	local ids = {}
	for userId in pairs(state.participants) do
		table.insert(ids, userId)
	end
	table.sort(ids)
	return ids
end

-- IS THE DRIVE OVER BECAUSE THE BEATERS ARE THROUGH? (task 159). Karen: *"Timer or when all beaters
-- cross line of hunters"*.
--
-- THREE CLAUSES, AND THE MIDDLE ONE IS THE ONE THAT MATTERS: with NO real beater in the drive this
-- is false, so a solo hunter -- which is every DEV harness session and every session Karen plays
-- alone -- still gets the full drive and ends on the clock. "All of nobody is through" is true in
-- arithmetic and would end the drive on its first tick.
--
-- The GEOMETRY is not here: the owner measures how many beaters there are and how many have crossed
-- (`Match.crossedLine`, which reads the world's own stands and line), and this machine compares two
-- numbers -- so a spec drives both endings with a table and no world.
function Phase.beatersThrough(event: Event, config): boolean
	if config.END_ON_BEATERS_CROSS ~= true then
		return false
	end
	local beaters = event.beaters or 0
	if beaters <= 0 then
		return false
	end
	return (event.beatersAcross or 0) >= beaters
end

-- ONE HASH IN THIS MODULE, and everything drawn is drawn from it: the jitter on the rhythm and the
-- size of a sounder. A Random here would make a bug report unreproducible, which is the whole reason
-- Roster has none either -- and two hashes would be two answers to "is this drive reproducible".
function Phase.unitHash(seed: number, index: number): number
	local hashed = (seed * 1103515245 + index * 12345) % 2147483648
	return (hashed % 10007) / 10007 -- [0, 1)
end

-- Deterministic jitter, so the release schedule is not a metronome AND a spec still gets the same
-- drive twice from the same seed.
function Phase.jitter(seed: number, index: number, spread: number): number
	if spread <= 0 then
		return 0
	end
	return (Phase.unitHash(seed, index) * 2 - 1) * spread
end

-- HOW MANY ANIMALS THE NEXT RELEASE IS. 0 when the drive's budget is spent; 1 whenever the flag is
-- off, which is exactly today's behaviour; otherwise a weighted pick from SIZE_WEIGHTS, clamped to
-- MAX_SIZE and to what is left of the budget -- so the sizes of a drive sum to BOARS_PER_DRIVE
-- exactly, never over (design, "the mix").
function Phase.sounderSize(state: State, config): number
	local remaining = config.BOARS_PER_DRIVE - state.boarsReleased
	if remaining <= 0 then
		return 0
	end
	-- THE QUICK TEST'S FIRST RELEASE IS KAREN'S "SMALL GROUP", whatever the sounder flag says: it is
	-- the release she is waiting for, and one boar 1,300 studs away is the thing being fixed. Only
	-- the FIRST one -- `soundersReleased == 0` -- so the rest of the drive is the real drive.
	if config.QUICK_TEST and state.soundersReleased == 0 then
		return math.max(1, math.min(config.QUICK_TEST_SOUNDER, remaining))
	end

	local sounder = config.SOUNDER
	if not (sounder and sounder.ENABLED) then
		return 1
	end

	local weights = sounder.SIZE_WEIGHTS
	local total = 0
	for _, weight in ipairs(weights) do
		total += weight
	end
	if total <= 0 then
		return 1
	end
	-- The index is the sounder COUNT, not the boar count, so the same drive draws the same sequence
	-- whatever the sizes turn out to be.
	local pick = Phase.unitHash(state.seed + state.driveNumber, state.soundersReleased + 1) * total
	local size, running = #weights, 0
	for index, weight in ipairs(weights) do
		running += weight
		if pick < running then
			size = index
			break
		end
	end
	return math.max(1, math.min(size, sounder.MAX_SIZE, remaining))
end

-- HOW LONG UNTIL THE NEXT ONE. Off the flag this is the fixed 90-second rhythm, unchanged. On it,
-- the gap is PACED: six animals in bites averaging EXPECTED_SIZE is about three encounters, and a
-- fixed 90 would spend the budget by t+300 and leave half the drive empty. So the time left before
-- TAIL_SECONDS is divided by the releases the remaining budget is expected to buy, and clamped.
--
-- CALLED AFTER state.boarsReleased HAS BEEN INCREMENTED, so `remaining` here is what is left AFTER
-- the release being scheduled -- which is the design's `remainingAfterThisRelease`.
-- `_size` is the design's signature and is deliberately unread: the release it describes is already
-- inside `state.boarsReleased` by the time this is called, so reading it as well would count it
-- twice. Kept in the signature so the design and the code still say the same thing.
function Phase.releaseGap(state: State, _size: number, now: number, config): number
	-- THE QUICK TEST'S OWN RHYTHM (task 83), and it is deliberately not the sounder pacing: a
	-- playtest wants the next crossing soon, not the drive's budget spread over ten minutes.
	if config.QUICK_TEST then
		return config.QUICK_TEST_INTERVAL_SECONDS
	end
	local sounder = config.SOUNDER
	if not (sounder and sounder.ENABLED) then
		return config.RELEASE_INTERVAL_SECONDS
	end
	local remaining = math.max(0, config.BOARS_PER_DRIVE - state.boarsReleased)
	local releasesLeft = math.max(1, math.round(remaining / sounder.EXPECTED_SIZE))
	local window = (state.phaseEndsAt - sounder.TAIL_SECONDS) - now
	return math.clamp(window / releasesLeft, sounder.GAP_MIN_SECONDS, sounder.GAP_MAX_SECONDS)
end

local function copy(state: State): State
	local next_: any = table.clone(state :: any)
	next_.participants = table.clone(state.participants)
	next_.assignment = table.clone(state.assignment)
	next_.missing = table.clone(state.missing)
	next_.boarSpawns = table.clone(state.boarSpawns)
	return next_
end

local function enoughPlayers(state: State, config): boolean
	return Phase.participantCount(state) >= config.MIN_PLAYERS
end

local function feed(effects: { Effect }, entry)
	table.insert(effects, { kind = "feed", entry = entry })
end

-- Entering Assigning: teams once, everybody placed, guns re-evaluated, the last drive's boars gone,
-- the scores zeroed by the owner. One broadcast, not one per step -- and a FORCED one, like every
-- other phase entry: STATE_MIN_INTERVAL exists to stop a busy drive pushing faster than 4 Hz, and a
-- phase change is the one thing a client must not learn about at the next 5-second heartbeat. Found
-- by Task 41's clock seam, which crossed two boundaries inside one throttle window and watched the
-- drive-start push vanish (the clients were still being told it was the previous drive).
local function enterAssigning(state: State, effects: { Effect }, now: number, config)
	state.phase = "Assigning"
	-- THE RESULTS SCENE GOES FIRST, AND THE HOLD IT PUT ON EVERYBODY GOES WITH IT (task 159). Before
	-- the teams, before the placement and before the new hold: `clearScene` takes down the lights and
	-- the animals, and `free` -- `userIds = nil`, everybody -- hands back the WalkSpeed the scene
	-- took, so the hunters can walk to their stands while the beaters are held at the line again.
	-- A tied player cannot be caught by this: `enterScoring` releases every tie before it holds
	-- anybody.
	table.insert(effects, { kind = "clearScene" })
	table.insert(effects, { kind = "free" })
	state.phaseEndsAt = now + Phase.intermissionSeconds(config)
	state.driveNumber += 1
	state.boarsReleased = 0
	state.soundersReleased = 0
	state.holdbacks = 0
	state.boarsAccounted = 0
	state.nextReleaseAt = math.huge

	local userIds = {}
	for userId in pairs(state.participants) do
		table.insert(userIds, userId)
	end
	table.sort(userIds)

	state.assignment = Roster.assign(userIds, state.previousAssignment, config)
	table.insert(effects, { kind = "assignTeams", assignment = state.assignment })
	table.insert(effects, { kind = "clearBoars" })
	-- AND THE BEATERS ARE HELD AT THE LINE for the length of this phase (task 158) -- **BEFORE**
	-- `placePlayers`, AND THE ORDER IS A MEASUREMENT, NOT A PREFERENCE (task 159, the Director's
	-- two-player run at `7ea945f`: `[harness2] FAIL 33/35`, zz_drive_boundary "took the scene down
	-- before the next drive, and let everybody go", for the ONE player the roster had just made a
	-- beater).
	--
	-- WHY THE OLD ORDER WAS WRONG: `placePlayers` is the one effect in this list that YIELDS -- the
	-- owner's `applyPlace` calls `Player:LoadCharacter()`, once per player. The drive is already in
	-- `Assigning` with its new number while that yields, so the Heartbeat's next step broadcasts the
	-- new drive to every client (and to anything watching) BEFORE the `hold` at the end of this list
	-- has been applied. For the seconds that takes, a beater the machine has decided to hold is not
	-- held: he can walk off his line, and nothing reading the drive can see that he is supposed to
	-- be held. With one player it is invisible, because a solo player is never a beater
	-- (`ODD_PLAYER_TEAM`), which is why only the two-player run caught it.
	--
	-- HOLDING FIRST COSTS NOTHING AND CLOSES IT: the hold is remembered as a userId
	-- (`Match`'s `heldStill`) before anything can yield, and the character watch puts the freeze on
	-- whatever character the respawn then produces -- which is the mechanism task 158 already wrote
	-- down and relied on ("IT REMEMBERS BEFORE IT WRITES"). Freezing the character that is about to
	-- be replaced is wasted work for one frame and nothing else.
	local heldIds = Phase.heldUserIds(state.assignment, config)
	if #heldIds > 0 then
		table.insert(effects, { kind = "hold", userIds = heldIds })
	end
	table.insert(effects, { kind = "placePlayers" })
	table.insert(effects, { kind = "refreshArming", userIds = userIds })
	feed(effects, { kind = "phase", text = "Drive " .. tostring(state.driveNumber), at = now })
	table.insert(effects, { kind = "broadcast", force = true })
end

local function enterRunning(state: State, effects: { Effect }, now: number, config)
	state.phase = "Running"
	state.phaseEndsAt = now + config.DRIVE_SECONDS
	-- GO. THE ONE PLACE THE HOLD ENDS, and `userIds = nil` means everybody held -- so a beater who
	-- joined mid-countdown is let go by the same effect as the ones who were there at the start
	-- (task 158). Assigning has exactly one exit, this one, so a hold cannot outlive the countdown.
	table.insert(effects, { kind = "free" })
	-- The FIRST release is exact; only the rhythm after it is jittered. The drive starts on time,
	-- which is both truer to "the drivers are walking now" and the difference between a harness run
	-- that can stage a shot at a boar and one that cannot: with the first release jittered by up to
	-- 15 s either way, the only boar in the session arrived after the replay had finished
	-- (measured, twice). reviews/task-32/DESIGN_DELTA.md records it.
	state.nextReleaseAt = now + Phase.firstReleaseSeconds(config)
	feed(effects, { kind = "phase", text = "Drive on", at = now })
	table.insert(effects, { kind = "broadcast", force = true })
end

-- THE END OF A DRIVE, AND SINCE TASK 159 IT IS ALSO THE RESULTS SCENE (Karen: *"all they standing
-- around the animals there is light on 4 corners and then showing image transperent with results
-- table"*). `reason` is "clock" or "beaters" and changes exactly one thing, the feed line: the scene
-- is the same scene either way.
--
-- THE ORDER IS THE DESIGN. The ties are released first (a rope hanging on a man standing at the
-- gathering spot would be two freezes on one character), the drive's animals are cleared, then
-- EVERYBODY is held and the scene is built around them -- `hold` before `scene` because the scene
-- MOVES each character and `Body.stand` holds and pivots the one character it is given, so a hold
-- applied afterwards would save a WalkSpeed the hold itself had already zeroed.
local function enterScoring(state: State, effects: { Effect }, now: number, config, reason: string?)
	state.phase = "Scoring"
	state.phaseEndsAt = now + config.SCORE_SECONDS
	state.previousAssignment = state.assignment
	state.nextReleaseAt = math.huge
	state.endedEarly = reason == "beaters"
	-- Everyone tied to a tree is freed, and whatever is still standing in the drive is removed.
	table.insert(effects, { kind = "release" })
	table.insert(effects, { kind = "clearBoars" })
	-- NOBODY WANDERS OFF WHILE THE RESULTS ARE UP (task 159, the dispatch's item 3). The same hold as
	-- the start line, applied to the whole roster rather than to one team -- and released by
	-- `enterAssigning`'s `free`, which is the next drive's own flow.
	local ids = Phase.participantIds(state)
	if #ids > 0 then
		table.insert(effects, { kind = "hold", userIds = ids })
	end
	table.insert(effects, { kind = "scene" })
	feed(effects, {
		kind = "phase",
		text = if state.endedEarly then "Drive over - the beaters are through" else "Drive over",
		at = now,
	})
	table.insert(effects, { kind = "broadcast", force = true })
end

local function enterWaiting(state: State, effects: { Effect }, now: number)
	state.phase = "Waiting"
	state.phaseEndsAt = math.huge
	state.nextReleaseAt = math.huge
	state.assignment = {}
	-- THE OTHER WAY OUT OF `Scoring` (task 159), and it must take the scene down too: a server that
	-- empties out after a drive would otherwise sit there lit, with the last drive's animals laid out
	-- in front of whoever joins next -- and whoever was still in it would stay frozen for ever.
	table.insert(effects, { kind = "clearScene" })
	table.insert(effects, { kind = "free" })
	feed(effects, { kind = "phase", text = "Waiting for players", at = now })
	table.insert(effects, { kind = "broadcast", force = true })
end

-- The release schedule: BOARS_PER_DRIVE ANIMALS in sounders of `Phase.sounderSize`, the first after
-- FIRST_RELEASE_SECONDS and the rest a `Phase.releaseGap` apart, each jittered. A release is HELD
-- BACK, never dropped, when the runtime is at its limit -- and the whole sounder is held back, not
-- part of it.
--
-- THIS IS THE ONLY GUARD, and round 1 found out why that matters: the owner used to check the live
-- boar count as well, and the two disagreed. `event.aliveBoars` was filled in only on the tick, so a
-- join or a leave landing on a release moment read zero, passed here, consumed the release and
-- pushed nextReleaseAt forward -- and then the owner refused the spawn. The boar was never released
-- and never retried: a six-boar drive quietly ran five, and the Hud counted one that did not exist.
-- The owner now fills aliveBoars on EVERY event and has no guard of its own; when the runtime still
-- refuses a spawn it hands the release back through Phase.releaseFailed.
local function maybeRelease(state: State, effects: { Effect }, now: number, event: Event, config)
	if state.boarsReleased >= config.BOARS_PER_DRIVE or now < state.nextReleaseAt then
		return
	end
	local size = Phase.sounderSize(state, config)
	if size <= 0 then
		return
	end

	-- THE WHOLE SOUNDER FITS OR NONE OF IT IS RELEASED. A half sounder would make the drive's budget
	-- disagree with the world, and `Runtime:spawnSounder` is all-or-nothing for the same reason.
	-- Held back, never dropped: the same hash index draws the same size next tick.
	local alive = event.aliveBoars or 0
	local entries = event.boarEntries or 0
	local capacity = event.boarCapacity or math.huge
	if alive + size > config.MAX_ALIVE_BOARS or entries + size > capacity then
		state.holdbacks += 1
		return -- retried next tick; the owner counts it
	end

	local spawns = state.boarSpawns
	local position = if #spawns > 0 then spawns[(state.soundersReleased % #spawns) + 1] else nil
	-- THE QUICK TEST'S FIRST RELEASE STARTS ON THE ROAD (task 83), not at the far marker 1,300 studs
	-- away, and it carries its own spread because the road is 16 studs wide and a spawn pad is 60.
	-- Every later release in the same drive is the normal one, from the normal marker.
	local spread = nil
	if config.QUICK_TEST and state.soundersReleased == 0 and state.quickSpawn then
		position, spread = state.quickSpawn, config.QUICK_TEST_SPREAD_STUDS
	end
	state.soundersReleased += 1
	state.boarsReleased += size
	state.holdbacks = 0
	table.insert(effects, { kind = "spawnSounder", position = position, size = size, spread = spread })
	state.nextReleaseAt = now
		+ Phase.releaseGap(state, size, now, config)
		+ Phase.jitter(state.seed + state.driveNumber, state.soundersReleased + 1, config.RELEASE_JITTER_SECONDS)
end

-- The owner could not perform a release this machine committed to. Give it back WHOLE: one sounder
-- and `size` boars, with the next release due now -- so the SAME sounder (the same hash index, and
-- therefore the same size) is retried on the next step rather than lost.
function Phase.releaseFailed(state: State, now: number, size: number?): State
	if state.soundersReleased <= 0 then
		return state
	end
	local next_ = copy(state)
	next_.soundersReleased -= 1
	next_.boarsReleased = math.max(0, next_.boarsReleased - math.max(1, size or 1))
	next_.holdbacks += 1
	next_.nextReleaseAt = now
	return freezeState(next_)
end

function Phase.step(state: State, event: Event, now: number, config): (State, { Effect })
	local next_ = copy(state)
	local effects: { Effect } = {}
	local kind = event.kind

	if kind == "markers" then
		next_.markersComplete = event.complete == true
		next_.missing = table.clone(event.missing or {})
		next_.boarSpawns = table.clone(event.boarSpawns or {})
		next_.quickSpawn = event.quickSpawn
	elseif kind == "join" and event.userId then
		next_.participants[event.userId] = event.name or tostring(event.userId)
		feed(effects, { kind = "join", userId = event.userId, name = event.name, at = now })
		if next_.phase == "Running" or next_.phase == "Assigning" then
			-- Assigned immediately to the SMALLER team and placed. Nobody already playing moves: a
			-- team swap mid-drive is the worst kind of surprise (design section 1.2).
			local team = Roster.smallerTeam(Roster.counts(next_.assignment), config)
			next_.assignment[event.userId] = team
			table.insert(effects, { kind = "assignTeams", assignment = { [event.userId] = team } })
			-- A BEATER WHO ARRIVES INSIDE THE COUNTDOWN IS HELD LIKE THE REST (task 158), and only
			-- inside it: in `Running` the line is long behind the drive and nobody is held at all.
			-- BEFORE `placePlayers`, for `enterAssigning`'s reason above (task 159): the placement
			-- yields, and a hold decided before a yield must be recorded before it.
			if next_.phase == "Assigning" and team == config.START_HOLD_TEAM then
				table.insert(effects, { kind = "hold", userIds = { event.userId } })
			end
			table.insert(effects, { kind = "placePlayers", userIds = { event.userId } })
			table.insert(effects, { kind = "refreshArming", userIds = { event.userId } })
		end
		table.insert(effects, { kind = "broadcast" })
	elseif kind == "team" and event.userId and event.team then
		-- ONE PLAYER CHANGES SIDES INSIDE A LIVE DRIVE (task 157, docs/design/forest-drive.md
		-- section 5.2). It is the `join` branch's shape with no participant added: the same three
		-- effects, in the same order, for the one userId.
		--
		-- ONLY INSIDE A DRIVE, and only for somebody who is in it. In `Waiting` and `Scoring` there
		-- is nothing to move him inside of, and the roster's own `enterAssigning` is what decides
		-- the next drive -- so a request outside a drive changes nothing and emits nothing. That is
		-- what makes it a request for THIS drive rather than a preference this machine has to
		-- remember, which would be a second roster.
		if
			(next_.phase == "Running" or next_.phase == "Assigning")
			and next_.participants[event.userId] ~= nil
			and next_.assignment[event.userId] ~= event.team
		then
			next_.assignment[event.userId] = event.team
			table.insert(effects, { kind = "assignTeams", assignment = { [event.userId] = event.team } })
			-- ...AND THE HOLD FOLLOWS THE SIDE HE IS NOW ON, inside the countdown only (task 158):
			-- made a beater, he is held at the line; made a hunter, he is let go, because the rest
			-- of the countdown is his to walk to a stand with. `free` with one userId frees that one
			-- and nobody else, so a role flip cannot release the whole line.
			-- BEFORE `placePlayers`, for `enterAssigning`'s reason above (task 159).
			if next_.phase == "Assigning" then
				local kind_ = if event.team == config.START_HOLD_TEAM then "hold" else "free"
				table.insert(effects, { kind = kind_, userIds = { event.userId } })
			end
			table.insert(effects, { kind = "placePlayers", userIds = { event.userId } })
			table.insert(effects, { kind = "refreshArming", userIds = { event.userId } })
			-- NO FEED LINE, deliberately: the feed's kinds are a contract with the Hud's own
			-- renderer (`join`, `leave`, `kill`, `escape`, `violation`, `phase`), and a dev command
			-- in a playtest world is not a thing to announce to everybody. The broadcast carries the
			-- new team on this player's own row.
			table.insert(effects, { kind = "broadcast" })
		end
	elseif kind == "leave" and event.userId then
		next_.participants[event.userId] = nil
		next_.assignment[event.userId] = nil
		feed(effects, { kind = "leave", userId = event.userId, name = event.name, at = now })
		table.insert(effects, { kind = "broadcast" })
	elseif kind == "kill" or kind == "gone" then
		-- Only inside the drive. A kill in Scoring is a shot at a carcass and scores nothing, which
		-- is one predicate in one place.
		if Phase.isLive(next_) then
			next_.boarsAccounted += 1
			feed(effects, {
				kind = if kind == "kill" then "kill" else "escape",
				userId = event.userId,
				name = event.name,
				zone = event.record and event.record.killingZone,
				at = now,
			})
			table.insert(effects, { kind = "broadcast" })
		end
	elseif kind == "violation" and event.userId then
		if Phase.isLive(next_) then
			-- FREEZE BEFORE FEED AND BROADCAST, and the order is load-bearing: the owner's `tied` set
			-- is what the snapshot reports, so a broadcast applied before the tie would announce the
			-- violation and show nobody tied for up to STATE_MIN_INTERVAL. The owner has already
			-- decided (phase is Running, this shooter is not tied yet, the grace is over, and
			-- Penalty.judge said yes); this machine only says what must now happen.
			table.insert(effects, { kind = "freeze", userId = event.userId })
			feed(effects, { kind = "violation", userId = event.userId, name = event.name, at = now })
			table.insert(effects, { kind = "broadcast" })
		end
	end

	-- Then time, whatever the event was: a `join` that completes the roster starts the drive on the
	-- same step rather than waiting for the next tick.
	if next_.phase == "Waiting" then
		if enoughPlayers(next_, config) and next_.markersComplete then
			enterAssigning(next_, effects, now, config)
		end
	elseif next_.phase == "Assigning" then
		if now >= next_.phaseEndsAt then
			enterRunning(next_, effects, now, config)
		end
	elseif next_.phase == "Running" then
		-- TWO ENDINGS, THE CLOCK FIRST (task 159). The clock is checked first because it is the rule
		-- that has always held and the one a drive cannot run past; the beaters' crossing can only
		-- ever end a drive EARLIER, never extend one.
		if now >= next_.phaseEndsAt then
			enterScoring(next_, effects, now, config, "clock")
		elseif Phase.beatersThrough(event, config) then
			enterScoring(next_, effects, now, config, "beaters")
		else
			maybeRelease(next_, effects, now, event, config)
		end
	elseif next_.phase == "Scoring" then
		if now >= next_.phaseEndsAt then
			if enoughPlayers(next_, config) and next_.markersComplete then
				enterAssigning(next_, effects, now, config)
			else
				enterWaiting(next_, effects, now)
			end
		end
	end

	return freezeState(next_), effects
end

return Phase
