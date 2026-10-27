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
-- Design: docs/design/drive.md (section 4), docs/design/role-rotation.md (section 4.2)
-- Note:   docs/research/2026-09-25-drive.md, docs/research/2026-10-20-role-rotation.md
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
	-- HAS THIS DRIVE ALREADY ASKED FOR ITS DEER (task 234)? Karen, 2026-10-21: *"we need all a time
	-- in drive deer"* and *"I want to see a deer"*. Exactly one release of every drive carries the
	-- ask, and this latch is what makes it exactly one.
	--
	-- IT LIVES HERE AND NOT IN THE BOAR RUNTIME, which is the whole reason this half of the feature
	-- is in `Phase` at all: `MatchBoot` builds ONE runtime for the whole server and it outlives
	-- every drive, so it has no drive boundary to latch against. This state IS the drive -- it is
	-- reset beside `boarsReleased` in `enterAssigning` -- and it already emits the release.
	--
	-- It is handed BACK by `Phase.releaseFailed` with the release it rode on, exactly as the
	-- sounder count and the boar budget are, so a refused release cannot spend the drive's deer.
	deerReleased: boolean,
	-- Consecutive hold-backs of the sounder currently due: a stall made visible instead of
	-- folkloric (SOUNDER.HOLDBACK_WARN). Reset by a release that happens.
	holdbacks: number,
	nextReleaseAt: number,
	boarsAccounted: number, -- killed + escaped this drive
	-- WHICH OF THE TWO ENDINGS ENDED THE LAST DRIVE (task 159): true when every real beater was
	-- through the hunters' line before the clock ran out. It is the feed line's own word and nothing
	-- else reads it -- the results scene is the same scene either way.
	endedEarly: boolean,
	-- WHEN THE WHOLE BEATER LINE WENT THROUGH, or nil while any of it is still behind (task 261,
	-- item 2). KAREN, 2026-10-25: *"I reach out first and then can go around hunters and spook all
	-- animals in there position and need to wait until all beaters cross or time pass, we need
	-- better solution here"*.
	--
	-- IT IS A LATCH AND IT IS LEVEL-TRIGGERED, which is this machine's own discipline (L-029): the
	-- OWNER measures how much of the line is through on every event and this records the instant the
	-- count first met the line's length -- and clears it again if it stops meeting it, which is a
	-- beater walking back north or a man joining the drivers mid-drive. So the grace cannot be
	-- started by one frame of a measurement and then survive the thing that started it.
	beatersThroughAt: number?,
	-- WHEN THE BEATERS ARE LET GO, AND IT IS AFTER GO (task 168). KAREN, 2026-10-12 ~21:45: *"you
	-- can't move as a beater before horn made signal"* -- so GO is the END of the start fanfare and
	-- not the instant the drive's clock starts. The second deadline in this state, on exactly the
	-- `nextReleaseAt` pattern: a time in the state, read by `Phase.step`'s own time section, so
	-- there is still no `task.delay` in this system and a spec can run the whole thing in
	-- milliseconds. `math.huge` means "nobody is waiting to be let go".
	goFreeAt: number,
	-- WHETHER THE `free` FOR IT HAS ALREADY BEEN EMITTED. It is a second field and not `goFreeAt =
	-- math.huge` for one reason, and it is the screen: `Match`'s snapshot publishes `goFreeAt` as
	-- `holdUntil`, and a beater's own Hud says `GO - push to the road` for five seconds AFTER the
	-- line walks -- which it works out from the AGE of that timestamp (`Match.goAgeSeconds`). Wiping
	-- the time would be wiping the only record of when GO was.
	goFreed: boolean,
	seed: number,
}

export type Event = {
	kind: string, -- "tick" | "join" | "leave" | "dismiss" | "withdraw" | "kill" | "gone" | "violation"
	-- ...plus "restart" (task 287: one man, a drive nobody else is in, started again from the top).
	-- ...plus "fine" (task 250: a money penalty, which draws one feed line), "markers" and "team".
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
	-- WHAT EACH PLAYER IS OWED (task 217): userId -> the team he must be given at the next
	-- assignment he takes part in. Filled by the owner on EVERY event, which is the `aliveBoars` /
	-- `boarEntries` / `beaters` idiom above and the shape TASKS.md 214b prescribes -- an assignment
	-- can happen on a join as well as on a tick, so a fact read only on ticks would be missing one.
	--
	-- A FROZEN table the owner MEMOISES. This machine only READS it and never stores it in the
	-- state: a state field would need a writer, and the only honest writer is the owner, which is
	-- the owner holding one fact twice. Absent or empty means nobody is owed anything, and then
	-- every answer below is today's answer BY IDENTITY (`Roster.previousFrom`, design section 7).
	owed: { [number]: TeamName }?,
	-- WHO BOUGHT THE HUNTER'S PLACE (task 221). Same shape, same discipline and same reason as
	-- `owed` above: filled by the owner on EVERY event off a FROZEN memo
	-- (`Economy.alwaysHunters`), read here and never stored in the state. Absent or empty is the
	-- game before this task, BY IDENTITY (`Roster.owedWith`).
	--
	-- IT IS KEPT APART FROM `owed` ON PURPOSE. They are two different facts -- the turn he is OWED
	-- and the privilege he BOUGHT -- and folding them into one table would leave
	-- `Roster.overruled` nothing to read when the balance rule beats the privilege.
	alwaysShooters: { [number]: boolean }?,
	-- WHO HAS ASKED TO BEAT THIS ONE DRIVE (task 229). Karen, 2026-10-21: *"we also need to have
	-- posibility to choose once you have a card always hunter maybe sometimes I want to be a beater
	-- we need to find a way to do that"*.
	--
	-- Same shape, same discipline and same reason as the two above: filled by the owner on EVERY
	-- event off a FROZEN memo (`Lobby.beaterWishes`), read here and never stored in the state.
	-- Absent or empty is the game before this task, BY IDENTITY (`Roster.wishedWith`).
	--
	-- IT IS KEPT APART FROM `alwaysShooters` ON PURPOSE, and the reason is the same one that keeps
	-- that field apart from `owed`: `Roster.overruled` has to be able to tell a privilege the
	-- BALANCE beat from one its owner GAVE UP, and one table could not.
	beaterWishes: { [number]: boolean }?,
}

export type Effect = {
	kind: string,
	-- "spawnSounder": how far from `position` the ring may spread, when the caller knows better than
	-- the map's spawn pad. The quick test does: it spawns on the road (task 83).
	spread: number?,
	force: boolean?, -- "broadcast": a phase change, which no client may miss behind the throttle
	assignment: { [number]: TeamName }?,
	userId: number?, -- "freeze": the one player to tie to a tree
	-- "refreshArming" / "placePlayers" / "unassign": whom -- and "unassign" is the one that hands a
	-- team BACK (task 177): the ids that had one and are not in the next drive. "hold": whom to hold
	-- -- at the start line (task 158),
	-- or the whole roster at the results scene (task 159). "free": whom to let go, and NIL MEANS
	-- EVERYBODY HELD -- which is what the start of a drive means (task 158), and what the end of the
	-- results scene means (task 159).
	-- "scene" and "clearScene" carry nothing: the scene is built from the drive's own kills and the
	-- world's own geometry, which are the owner's to read, and taken down whole.
	userIds: { number }?,
	position: Vector3?,
	size: number?, -- "spawnSounder": how many animals this release is
	-- "spawnSounder": THIS release is the drive's red deer (task 234). The owner passes it to the
	-- boar runtime, which skips its own chance roll and still decides WHICH deer come -- so the
	-- schedule says WHEN and the animal's own table says WHO, and neither learns the other's job.
	deer: boolean?,
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
		beatersThroughAt = nil,
		markersComplete = false,
		missing = { "markers" },
		boarSpawns = {},
		quickSpawn = nil,
		boarsReleased = 0,
		soundersReleased = 0,
		deerReleased = false,
		holdbacks = 0,
		nextReleaseAt = math.huge,
		boarsAccounted = 0,
		endedEarly = false,
		goFreeAt = math.huge,
		goFreed = true,
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

-- IS THERE A DRIVE TO BE INSIDE OF? (task 248.) `Assigning` OR `Running` -- the countdown and the
-- hunt -- which is not the same question as `Phase.isLive` (Running alone, *"a kill in Scoring is a
-- shot at a carcass"*) and not the same as `Phase.driveOpen` (between the two horns).
--
-- IT EXISTS SO THE WITHDRAWAL RULE HAS ONE ANSWER. The `withdraw` branch below refuses outside it
-- and the owner's respawn sweep does not ask outside it; written twice as an inline comparison, the
-- two could disagree about whether a man who resets during the countdown is out of the drive -- and
-- the answer is yes, he is, because he was in it. The `join` and `team` branches keep their own
-- inline test, which this is deliberately not a refactor of (one task, one change).
function Phase.insideDrive(state: State): boolean
	return state.phase == "Running" or state.phase == "Assigning"
end

-- MAY THIS MAN BE PUT BACK IN? (task 261, item 1.) PURE, and `withdrawnFrom` is the drive number he
-- was taken out of -- nil for a man no drive has ever let go of.
--
-- KAREN, 2026-10-25: *"when I respawn and then go to lobby then go back on pad to hunt I been
-- transfarred to same hunt where I was previuosly with less than min remaining I was hunter but then
-- time pass and done it's a bug / when I respawn and go again to hunt I need to be same role and
-- from begining"*.
--
-- THE RULE IS *A PLAYER WHO LEFT A DRIVE NEVER REJOINS THAT DRIVE* (the Director). Task 248 takes a
-- man who respawns out of the hunt; the pads then put him back into THE SAME ONE, forty seconds
-- before the horn, because `Match.enrol` only ever asked whether he was in the roster now. He has to
-- go with the NEXT drive's party instead (task 246), which is a thing the lobby already collects
-- him into at this drive's end.
--
-- THE TWO CLAUSES ARE BOTH NECESSARY and neither is a guard:
--   * THE DRIVE NUMBER, so the bar lifts by itself. `enterAssigning` raises `driveNumber`, so the
--     next drive is a different drive and nothing has to remember to clear anything -- the shape
--     `roleOverruled` already has in the owner (*"cleared when the drive number moves"*).
--   * `insideDrive`, so a man standing in `Scoring` or `Waiting` can still be enrolled. That is the
--     window the lobby's own party departs in, and it is the SAME two phase names the `withdraw`
--     branch refuses outside of and the lobby's `leftDrive` latch is armed inside -- one rule, three
--     readers, measured against one predicate.
function Phase.barredFromRejoin(state: State, withdrawnFrom: number?): boolean
	if withdrawnFrom == nil then
		return false
	end
	return withdrawnFrom == state.driveNumber and Phase.insideDrive(state)
end

function Phase.participantCount(state: State): number
	local n = 0
	for _ in pairs(state.participants) do
		n += 1
	end
	return n
end

-- MAY A PAD STEP START THIS DRIVE AGAIN FROM THE TOP? (task 287.) PURE, and it is the SOLO
-- question: is there anybody in this live drive at all?
--
-- KAREN, 2026-10-24: *"when I respawn and then go to lobby then go back on pad to hunt I been
-- transferred to same hunt ... with less than min remaining ... I need to be same role and from
-- beginning"*. Task 261 stopped the rejoin (`barredFromRejoin` above) and gave him the next drive's
-- party instead -- which is right while OTHER men are still hunting, and is a man standing alone in
-- a lobby watching a clock run down on a drive nobody is in when he is the only player.
--
-- SO IT IS A QUESTION ABOUT THE ROSTER AND NOTHING ELSE: `participants` is what a drive IS, and a
-- withdrawn man is not in it (the `withdraw` branch below takes him out). An EMPTY roster inside a
-- live drive is a hunt nobody is in, and it is the only state a pad step may restart.
--
-- **AND IT IS WHAT MAKES "EXACTLY ONE FRESH DRIVE" A PROPERTY RATHER THAN A HOPE** (Learning Agent
-- L-029), because the restart itself falsifies it: the man is a participant the moment the branch
-- below runs, so a second pad step in the same tick -- his own, or another barred man's -- finds a
-- roster of one and restarts nothing. The second man is no longer barred either (the drive number
-- moved), so the ordinary `join` takes him into that one drive.
--
-- `insideDrive`, FOR `barredFromRejoin`'S OWN REASON: in `Scoring` and `Waiting` there is no drive
-- to restart -- the loop's own doors start the next one -- and a restart there would skip the
-- results scene Karen asked for.
function Phase.mayRestart(state: State): boolean
	return Phase.insideDrive(state) and Phase.participantCount(state) == 0
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

-- IS THE LINE STILL BEING HELD? (task 168) -- the countdown, OR the fanfare that follows it, which
-- is the window in which a beater may not walk.
--
-- IT EXISTS BECAUSE OF A MEASURED BUG, and the measurement is in the request: in the Forest Test a
-- player who asks to BE a beater is moved at the instant the drive starts
-- (`ForestTestBoot`'s `PhaseChanged -> Running` honours the request there on purpose, task 157: the
-- intermission has already respawned everybody once and honouring inside it would be a second
-- `LoadCharacter`). So she arrived on the beaters' side one step AFTER `Assigning` had ended --
-- and the `team` branch below only held somebody during `Assigning`. MEASURED in a live Play session
-- of the Forest Test, 2026-10-12: `team=Drivers walkSpeed=16 anchored=false` from the moment she was
-- made a beater, which is Karen's own complaint (*"you can't move as a beater before horn made
-- signal"*) with its mechanism attached.
--
-- SO "HELD" IS THE WINDOW AND NOT THE PHASE. A beater who arrives while the fanfare is still
-- sounding is held for the rest of it and let go by the same `free` as everybody else; one who
-- arrives a minute into the drive is not held at all, which is the rule task 158 wrote (*"in
-- `Running` the line is long behind the drive and nobody is held"*) and is unchanged.
function Phase.lineHeld(state: State): boolean
	if state.phase == "Assigning" then
		return true
	end
	return state.phase == "Running" and state.goFreed ~= true
end

-- IS THE DRIVE OPEN? (task 174.) KAREN, 2026-10-13 ~09:35: *"we can't walk or make a horn sound
-- before horn anounce hunting started for beater / for hunter once hunt over (drive) horn anounce
-- then I can; shoot anymore"*. THE SIGNALS ARE THE RULES: the start horn opens the drive, the end
-- horn closes it, and this is that one window as a predicate.
--
-- IT IS THE ONE SOURCE, AND THAT IS THE WHOLE POINT OF PUTTING IT HERE. Three rules read it and none
-- of them owns a clock of its own:
--   * the bot line walks (`Match.botsMayGo`, which before this task said these same two things in
--     its own words),
--   * a horn may sound (`Match.mayBlowHorn`, and a beater who is through the line is refused on top
--     of this -- task 168's rule, which is about the MAN and not about the drive),
--   * a gun may fire (`Weapon.Rules.driveClosed`, through `Match.driveOpen`).
-- A second answer to "is the drive on" is this project's named failure mode, and it would be two
-- clocks: `phaseEndsAt` is the only one (this file's own header).
--
-- SO IT IS FALSE FOR EVERY PHASE BUT `Running`, AND FOR THE FANFARE INSIDE IT. `Waiting` and
-- `Assigning` are before GO, `Scoring` is the results scene the end signal opens -- "through the
-- results scene until the next drive's GO" -- and `lineHeld` is the start fanfare, which is the gap
-- between `Running` beginning and GO (`Phase.goHoldSeconds`).
function Phase.driveOpen(state: State?): boolean
	if state == nil or state.phase ~= "Running" then
		return false
	end
	return not Phase.lineHeld(state)
end

-- HOW LONG AFTER THE DRIVE'S CLOCK STARTS THE BEATERS ARE STILL HELD (task 168). KAREN, 2026-10-12
-- ~21:45: *"you can't move as a beater before horn made signal and there should be countdown"*.
--
-- GO IS THE END OF THE FANFARE. Task 163 sounds the start signal at the instant `Running` begins and
-- task 158 let the beaters go at the same instant, so the line was walking THROUGH its own fanfare.
-- This is the gap between the two, and it is the fanfare's own length -- `Match.CONFIG` reads it off
-- `Horn.CONFIG.SIGNAL` (`Horn.signalSeconds("start")`), so "how long is the fanfare" stays one
-- number in the file that owns the sound and this machine holds no sound numbers at all.
--
-- ZERO IS A REAL VALUE AND IT IS THIS FILE BEFORE TASK 168: `enterRunning` then frees at GO exactly
-- as it always did, which is what makes both behaviours reachable by parameter from a pure spec.
function Phase.goHoldSeconds(config): number
	local seconds = config.GO_HOLD_SECONDS
	return if type(seconds) == "number" and seconds > 0 then seconds else 0
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

-- HOW LONG AFTER THE LAST BEATER IS THROUGH THE DRIVE RUNS ON (task 261, item 2). The Director:
-- *"when ALL beaters (human and bot) are through, the drive ends after a grace of about 15 s (the
-- last animals cross), instead of waiting out the clock"*.
--
-- IT IS WHAT THE GRACE IS FOR: the line being through means nothing is pushing any more, and the
-- animals already moving in front of it are still crossing the road the hunters are sitting on. End
-- on the instant the last beater steps over it and those shots never happen.
--
-- 0 IS TODAY'S GAME EXACTLY, and that is why the rule reads through this function rather than a
-- literal: with no row in the config the drive ends on the crossing, which is task 159's behaviour
-- line for line.
function Phase.throughGraceSeconds(config): number
	local grace = config.BEATERS_THROUGH_GRACE_SECONDS
	return if type(grace) == "number" and grace > 0 then grace else 0
end

-- THE INDEX THE DEER'S ORDINAL IS DRAWN AT (task 234). It is a constant and a LARGE one, because
-- the other two users of this hash index it by the sounder COUNT (1, 2, 3 ...): a small constant
-- would make the drive's deer ordinal the same number as one of its jitters or sizes, which is not
-- wrong but is the kind of coincidence that makes a spec look like it proves something it does not.
local DEER_HASH_INDEX = 9001

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

-- HOW MANY RELEASES THIS DRIVE EXPECTS TO MAKE. Not a new rule: it is `releaseGap`'s own
-- `releasesLeft` arithmetic read at the START of a drive instead of in the middle of one, so the two
-- cannot disagree about what a drive is. Off the sounder flag every release is one animal, so it is
-- the budget itself.
function Phase.expectedReleases(config): number
	local sounder = config.SOUNDER
	if not (sounder and sounder.ENABLED) then
		return math.max(1, config.BOARS_PER_DRIVE)
	end
	return math.max(1, math.round(config.BOARS_PER_DRIVE / math.max(1, sounder.EXPECTED_SIZE)))
end

-- IS THE RELEASE ABOUT TO BE MADE THE DRIVE'S RED DEER (task 234)? PURE, so the guarantee is a spec
-- case and not a playtest. Karen, 2026-10-21: *"we need all a time in drive deer"*.
--
-- THREE CLAUSES, AND THE THIRD IS THE ONE THAT MAKES IT A GUARANTEE:
--
--   1. a drive asks ONCE. `state.deerReleased` latches, and `releaseFailed` hands it back.
--   2. WHICH release is drawn from the drive's own seed through `Phase.unitHash` -- the one hash in
--      this module -- so it is not always the first and a drive is still reproducible.
--   3. ...AND IF THAT ORDINAL IS NEVER REACHED, THE LAST RELEASE CARRIES IT. Without this it is
--      only a better chance: `sounderSize` draws sizes per release, so a drive that happens to draw
--      three fours makes four releases and an ordinal of 5 would never come up. `size` is the
--      release being decided, so `boarsReleased + size >= BOARS_PER_DRIVE` IS "this is the last
--      one" -- `maybeRelease` has already refused to go past the budget.
--
-- IT SAYS NOTHING ABOUT WHETHER DEER EXIST. With `BOAR_MODEL` off there are no deer kinds at all,
-- and `Boar.deerComposition` answers nil to this ask exactly as it does to a chance roll. The
-- schedule's job is WHEN; whether there is an animal is the animal's own table's.
function Phase.deerRelease(state: State, size: number, config): boolean
	if state.deerReleased then
		return false
	end
	if (config.BOARS_PER_DRIVE or 0) <= 0 then
		return false
	end
	if state.boarsReleased + size >= config.BOARS_PER_DRIVE then
		return true -- the last release of the drive, and nothing has carried it yet
	end
	local expected = Phase.expectedReleases(config)
	local ordinal = math.floor(Phase.unitHash(state.seed + state.driveNumber, DEER_HASH_INDEX) * expected) + 1
	return state.soundersReleased + 1 >= math.min(ordinal, expected)
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

-- THE DRIVE'S OWN HORN, AS ONE FEED ENTRY (task 163). Karen, 2026-10-12: *"when hunt starts 3 longer
-- horn calls and when ends the same"*.
--
-- IT RIDES THE FEED AND ADDS NO WIRE, which is the decision. `MatchEvent` is already a server ->
-- client one-shot channel that every client hears, the Hud already has the rule "an entry whose
-- `feedTextFor` is nil draws no line" (task 124 round 3, for `HitLog`'s kills), and a `signal` entry
-- is exactly that: no line, one sound. A second RemoteEvent for one word would be a second wire
-- answering a question this one already answers.
--
-- `which` is "start" or "end" -- the WORD and nothing else, and since task 166 it is also the KEY:
-- `Horn.CONFIG.SIGNAL.PHRASES` is keyed by these two words, so which asset sounds and which cut of
-- it is read by the one client-side owner that plays them. This machine stays pure and holds no
-- sound numbers at all.
local function signal(effects: { Effect }, now: number, config, which: string)
	if not config.SIGNAL_ENABLED then
		return
	end
	feed(effects, { kind = "signal", text = which, at = now })
end

-- Entering Assigning: teams once, everybody placed, guns re-evaluated, the last drive's boars gone,
-- the scores zeroed by the owner. One broadcast, not one per step -- and a FORCED one, like every
-- other phase entry: STATE_MIN_INTERVAL exists to stop a busy drive pushing faster than 4 Hz, and a
-- phase change is the one thing a client must not learn about at the next 5-second heartbeat. Found
-- by Task 41's clock seam, which crossed two boundaries inside one throttle window and watched the
-- drive-start push vanish (the clients were still being told it was the previous drive).
-- `owed` is each player's stored turn, off the EVENT (task 217). It is a SUGGESTION and never a
-- decision: `Roster.previousFrom` folds it into the synthetic `previous` below, and
-- `Roster.assign`'s own balance check may discard the whole swap -- in which case nothing is
-- consumed, because the only thing that ever WRITES a turn is the drive's end (design section 5.3).
local function enterAssigning(state: State, effects: { Effect }, now: number, config, owed, always, wishes)
	state.phase = "Assigning"
	-- THE RESULTS SCENE GOES FIRST, AND THE HOLD IT PUT ON EVERYBODY GOES WITH IT (task 159). Before
	-- the teams, before the placement and before the new hold: `clearScene` takes down the lights and
	-- the animals, and `free` -- `userIds = nil`, everybody -- hands back the WalkSpeed the scene
	-- took, so the hunters can walk to their stands while the beaters are held at the line again.
	-- A tied player cannot be caught by this: `enterScoring` releases every tie before it holds
	-- anybody.
	table.insert(effects, { kind = "clearScene" })
	table.insert(effects, { kind = "free" })
	-- Task 168: the countdown's own hold is `Assigning`'s own deadline, so nothing is pending here --
	-- and the last drive's GO must not still be on a beater's screen when the next one is counting in.
	state.goFreeAt = math.huge
	state.goFreed = true
	state.phaseEndsAt = now + Phase.intermissionSeconds(config)
	state.driveNumber += 1
	state.boarsReleased = 0
	state.soundersReleased = 0
	state.deerReleased = false
	state.holdbacks = 0
	state.boarsAccounted = 0
	state.nextReleaseAt = math.huge
	-- ...AND NO LINE IS THROUGH AT THE START OF A DRIVE (task 261, item 2), which is the belt on the
	-- path that does not reach `enterScoring`: a drive dismissed into `Waiting` and started again.
	state.beatersThroughAt = nil

	local userIds = {}
	for userId in pairs(state.participants) do
		table.insert(userIds, userId)
	end
	table.sort(userIds)

	-- THE STORED TURN IS AN INPUT TO THE SPLIT (task 217), and it arrives as a synthetic `previous`
	-- rather than as a second algorithm: `Roster.previousFrom` answers `state.previousAssignment`
	-- BY IDENTITY when nobody is owed anything, so with no economy in the build this line is the
	-- line it was before this task, value for value (design section 7).
	--
	-- THE STORED TURN GOES IN AS THE SYNTHETIC PREVIOUS, exactly as task 217 built it...
	local previous = Roster.previousFrom(state.previousAssignment, owed)
	-- ...AND THE BOUGHT PLACE GOES IN AS ITS OWN ARGUMENT (task 221 round 3, the Director's
	-- decision of 2026-10-20). It is NOT folded into `owed` any more: doing that moved the SWAPPED
	-- counts by two, so `Roster.assign`'s balance check discarded the whole swap and a paid
	-- always-hunter was overruled on every even roster. `Roster.assign` now places the men who
	-- bought it FIRST and lets the rotation fill what is left, so the result is balanced by
	-- construction rather than by a check that can throw everything away.
	--
	-- `always` nil or empty takes the path this line took before, untouched.
	-- ...AND THE ONE-DRIVE OPT-OUT GOES IN AS ITS OWN ARGUMENT TOO (task 229), for the identical
	-- reason the bought place does: `Roster.assign` deals the wishers a driver's place FIRST and lets
	-- the privilege and then the rotation fill what is left, so the split is balanced by construction
	-- rather than by a check that can throw it away. `wishes` nil or empty takes the path above,
	-- untouched.
	state.assignment = Roster.assign(userIds, previous, config, always, wishes)
	-- ANYBODY WHO WAS IN THE LAST DRIVE AND IS NOT IN THIS ONE (task 177, design section 4.4). The
	-- OTHER door out of `Scoring` is straight into `Assigning` -- a lobby player can enrol during the
	-- results scene -- and that path never reaches `enterWaiting`, so without this a dismissed player
	-- would keep the last drive's team, its vest and its horn through the whole of the next drive.
	--
	-- EMITTED BEFORE `assignTeams`, so a player who is in BOTH drives is unassigned and then assigned
	-- rather than the other way round -- except that he is not in this list at all, which is the
	-- point of the `== nil` test: nobody's team is written twice in one phase entry.
	local dropped = {}
	for userId in pairs(state.previousAssignment or {}) do
		if state.assignment[userId] == nil then
			table.insert(dropped, userId)
		end
	end
	table.sort(dropped)
	if #dropped > 0 then
		table.insert(effects, { kind = "unassign", userIds = dropped })
	end
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
	-- GO, AND SINCE TASK 168 GO IS THE END OF THE FANFARE. Karen: *"you can't move as a beater
	-- before horn made signal"*. The signal is emitted below, at this instant; the beaters are let
	-- go `Phase.goHoldSeconds` later, by the time section's own check -- so the line stands still
	-- for the whole phrase and then walks.
	--
	-- `userIds = nil` MEANS EVERYBODY HELD either way, so a beater who joined mid-countdown is let
	-- go by the same effect as the ones who were there at the start (task 158). `Assigning` has
	-- exactly one exit, this one, so a hold cannot outlive the countdown however many ticks arrive.
	local hold = Phase.goHoldSeconds(config)
	state.goFreeAt = now + hold
	state.goFreed = hold <= 0
	if state.goFreed then
		table.insert(effects, { kind = "free" })
	end
	-- The FIRST release is exact; only the rhythm after it is jittered. The drive starts on time,
	-- which is both truer to "the drivers are walking now" and the difference between a harness run
	-- that can stage a shot at a boar and one that cannot: with the first release jittered by up to
	-- 15 s either way, the only boar in the session arrived after the replay had finished
	-- (measured, twice). reviews/task-32/DESIGN_DELTA.md records it.
	state.nextReleaseAt = now + Phase.firstReleaseSeconds(config)
	feed(effects, { kind = "phase", text = "Drive on", at = now })
	-- ANBLASEN (task 163). Karen: *"when hunt starts 3 longer horn calls and when ends the same"*.
	-- ONE ENTRY, HERE AND NOWHERE ELSE: `Assigning` has exactly one exit and this is it, so the
	-- signal cannot sound twice for one drive however many ticks arrive -- the same argument the
	-- `free` above rests on. The entry carries the WORD and no numbers; `Hud.Sound` owns the sound.
	signal(effects, now, config, "start")
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
	-- THE NEXT DRIVE'S `previous` IS THIS DRIVE'S ASSIGNMENT, UNCHANGED SINCE TASK 217 -- and a man
	-- the drive let go of has no row in it, which is deliberate rather than an omission: the
	-- `withdraw` branch above says what carries HIS role instead (the stored turn), and why a
	-- second mechanism here was built, measured and taken out again.
	-- THE GRACE BELONGS TO THE DRIVE THAT HAS JUST ENDED (task 261, item 2): a latch left standing
	-- would make the next drive's first tick think its line was already through.
	state.beatersThroughAt = nil
	state.previousAssignment = state.assignment
	state.nextReleaseAt = math.huge
	-- NOBODY IS WAITING TO BE LET GO AT THE END OF A DRIVE: the scene holds everybody anyway, and a
	-- pending `goFreeAt` would emit a `free` into the results scene and let the ring wander off (task
	-- 168). The next drive's own `enterAssigning` frees them.
	state.goFreeAt = math.huge
	state.goFreed = true
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
	-- THE END SIGNAL (task 163) -- and the sources name no "Abblasen des Treibens", so it is not
	-- called one here (the research note says which signals they DO name). IT COVERS BOTH ENDINGS
	-- BECAUSE THERE IS ONLY ONE DOOR. The clock and
	-- the beaters' crossing both come through `enterScoring`, so one emit here is one signal per
	-- drive end whichever of the two it was -- which is also why `reason` is not read: the signal is
	-- the same signal either way, exactly as the scene is.
	signal(effects, now, config, "end")
	table.insert(effects, { kind = "broadcast", force = true })
end

local function enterWaiting(state: State, effects: { Effect }, now: number)
	state.phase = "Waiting"
	state.phaseEndsAt = math.huge
	state.nextReleaseAt = math.huge
	state.goFreeAt = math.huge
	state.goFreed = true
	-- EVERY TEAM IS HANDED BACK, and it is emitted BEFORE `state.assignment` is emptied because the
	-- assignment is where the list comes from (task 177, docs/design/lobby.md section 4.4).
	--
	-- NOTHING IN THIS REPO EVER SET A TEAM BACK TO NIL before this line: `Body.setTeam` is the one
	-- writer of `Player.Team` and its only caller was the `assignTeams` effect, which this door does
	-- not emit. It was invisible because `MIN_PLAYERS` is 1, so with anybody on the server this phase
	-- was unreachable. With a lobby it is the normal end of every drive, and a player back at the
	-- lodge still on the Drivers team keeps the horn, the vest and the wrong line on his screen.
	--
	-- IT READS BOTH TABLES, AND THAT IS A CORRECTION THE GATE FOUND rather than a choice (the
	-- design's section 4.4 snippet reads `state.assignment` alone, and `match_phase.spec` came back
	-- `unassign 0` for it). A `dismiss` has already EMPTIED `state.assignment` by the time this door
	-- is reached -- that is what makes `enoughPlayers` false and this door the one taken -- while the
	-- PLAYERS still carry `Player.Team`, because `dismiss` deliberately leaves the badges and the
	-- team colours standing in the results scene. So the list of men who have a team to hand back is
	-- the union of the two, and reading only the live roster would hand nothing back at all: the
	-- exact failure this effect exists to prevent, one table along.
	--
	-- SORTED, like every other id list this machine emits, so the effect is deterministic and a spec
	-- can assert it by value. `applyUnassign` is keyed by userId and a duplicate is impossible,
	-- because `seen` is what decides membership rather than either table's order.
	local dropped = {}
	local seen = {}
	for _, table_ in ipairs({ state.assignment, state.previousAssignment or {} }) do
		for userId in pairs(table_) do
			if not seen[userId] then
				seen[userId] = true
				table.insert(dropped, userId)
			end
		end
	end
	table.sort(dropped)
	if #dropped > 0 then
		table.insert(effects, { kind = "unassign", userIds = dropped })
	end
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
	-- ASKED BEFORE THE COUNTS MOVE (task 234), because `Phase.deerRelease` reads them: `size` is the
	-- release being decided, and "is this the last one" is `boarsReleased + size >= BOARS_PER_DRIVE`
	-- against the budget BEFORE this release is in it.
	local deer = Phase.deerRelease(state, size, config)
	state.soundersReleased += 1
	state.boarsReleased += size
	state.deerReleased = state.deerReleased or deer
	state.holdbacks = 0
	table.insert(
		effects,
		{ kind = "spawnSounder", position = position, size = size, spread = spread, deer = deer or nil }
	)
	state.nextReleaseAt = now
		+ Phase.releaseGap(state, size, now, config)
		+ Phase.jitter(state.seed + state.driveNumber, state.soundersReleased + 1, config.RELEASE_JITTER_SECONDS)
end

-- The owner could not perform a release this machine committed to. Give it back WHOLE: one sounder
-- and `size` boars, with the next release due now -- so the SAME sounder (the same hash index, and
-- therefore the same size) is retried on the next step rather than lost.
-- `deer` IS THE RELEASE'S OWN FLAG, HANDED BACK WITH IT (task 234): a release the owner could not
-- perform must not spend the drive's one deer, or a refusal at the wrong moment would be a drive
-- with no deer in it -- which is the whole defect this guarantee exists for. The caller passes what
-- the effect carried; a caller that passes nothing leaves the latch where it was, which is what
-- every call before task 234 meant.
function Phase.releaseFailed(state: State, now: number, size: number?, deer: boolean?): State
	if state.soundersReleased <= 0 then
		return state
	end
	local next_ = copy(state)
	next_.soundersReleased -= 1
	next_.boarsReleased = math.max(0, next_.boarsReleased - math.max(1, size or 1))
	if deer == true then
		next_.deerReleased = false
	end
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
			-- ...TO THE SMALLER TEAM, OR TO THE TEAM HE IS OWED WHEN THE SIDES ARE LEVEL (task 217):
			-- on a tie the turn costs the balance nothing, because the result differs by one either
			-- way. `Roster.joinTeam` with no owed team IS `Roster.smallerTeam`, which is this line
			-- before task 217. It matters more than it looks: since tasks 177 and 209 a player walks
			-- onto a truck pad during the intermission, so this branch is the NORMAL way into a
			-- drive rather than an edge case (design section 8.5).
			-- THE PRIVILEGE REACHES A MID-DRIVE JOINER TOO (task 221): since tasks 177 and 209 a
			-- player walks onto a truck pad during the intermission, so this is the NORMAL way into a
			-- drive. `joinTeam`'s own rule is unchanged -- the owed team wins only off a tie -- so the
			-- balance still beats the privilege here as well.
			-- ...AND HIS OWN ONE-DRIVE WISH BEATS THE PLACE HE BOUGHT (task 229), applied LAST
			-- because he is the one who bought it. `joinTeam`'s own rule is unchanged, so a wish --
			-- exactly like the turn and the privilege before it -- wins only off a TIE: the balance
			-- still beats all three here, and nothing is consumed when it does.
			local wanted = Roster.wishedWith(Roster.owedWith(event.owed, event.alwaysShooters), event.beaterWishes)
			local owedTeam = if wanted then wanted[event.userId] else nil
			local team = Roster.joinTeam(Roster.counts(next_.assignment), owedTeam, config)
			next_.assignment[event.userId] = team
			table.insert(effects, { kind = "assignTeams", assignment = { [event.userId] = team } })
			-- A BEATER WHO ARRIVES WHILE THE LINE IS STILL HELD IS HELD LIKE THE REST (task 158),
			-- and only then: a minute into `Running` the line is long behind the drive and nobody is
			-- held at all. Since task 168 that window is the countdown PLUS the fanfare
			-- (`Phase.lineHeld`), because GO is the end of the phrase and not the start of it.
			-- BEFORE `placePlayers`, for `enterAssigning`'s reason above (task 159): the placement
			-- yields, and a hold decided before a yield must be recorded before it.
			if Phase.lineHeld(next_) and team == config.START_HOLD_TEAM then
				table.insert(effects, { kind = "hold", userIds = { event.userId } })
			end
			table.insert(effects, { kind = "placePlayers", userIds = { event.userId } })
			table.insert(effects, { kind = "refreshArming", userIds = { event.userId } })
		end
		table.insert(effects, { kind = "broadcast" })
	elseif kind == "restart" and event.userId then
		-- A FRESH HUNT FROM THE TOP, FOR A MAN THE LIVE DRIVE HAS LET GO OF (task 287). Karen:
		-- *"I need to be same role and from beginning"*.
		--
		-- IT IS `enterAssigning` AND NOTHING NEW: the drive number rises (so `barredFromRejoin` is
		-- false for him by construction and the bar lifts with no latch to clear), the clock is the
		-- countdown's and then the full drive's, the scene comes down, and his ROLE comes back through
		-- the stored turn already on the event (`owed` -> `Roster.previousFrom`), which is the
		-- mechanism the `withdraw` branch's own header says answers her.
		--
		-- REFUSED WHILE ANYBODY ELSE IS IN THE DRIVE, which is the whole of the multi-player rule:
		-- `mayRestart` is false, this changes nothing and emits nothing, and the lobby keeps him off
		-- the pad and says so instead (`Lobby`'s own `padLate` notice).
		if Phase.mayRestart(next_) then
			next_.participants[event.userId] = event.name or tostring(event.userId)
			feed(effects, { kind = "join", userId = event.userId, name = event.name, at = now })
			-- **A DRIVE THAT RAN ENDS THROUGH `Scoring`, LIKE EVERY OTHER DRIVE** (task 299). The
			-- pay-out and the rest of the per-drive work hang off that ONE edge, so a restart that
			-- jumped straight to `Assigning` had to pay beside it -- and that second call made the
			-- pad a faucet (task 287 round 3, findings 1 and 2). The loop's own `Scoring` exit then
			-- deals the fresh drive, with the new number and the full clock.
			-- FROM `Assigning` THERE IS NOTHING TO SCORE -- no GO, no points, nobody in it -- so that
			-- restart pays nothing and deals the fresh drive here, exactly as it did.
			if next_.phase == "Running" then
				enterScoring(next_, effects, now, config, "restart")
			else
				enterAssigning(next_, effects, now, config, event.owed, event.alwaysShooters, event.beaterWishes)
			end
		end
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
			-- ...AND THE HOLD FOLLOWS THE SIDE HE IS NOW ON, while the line is held (task 158, and
			-- the window widened to include the fanfare in task 168 -- `Phase.lineHeld`, whose own
			-- comment carries the live measurement that made it necessary): made a beater, he is
			-- held at the line; made a hunter, he is let go, because the rest of the countdown is
			-- his to walk to a stand with. `free` with one userId frees that one and nobody else, so
			-- a role flip cannot release the whole line.
			-- BEFORE `placePlayers`, for `enterAssigning`'s reason above (task 159).
			if Phase.lineHeld(next_) then
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
	elseif kind == "dismiss" then
		-- THE ROSTER, CLEARED, WITH NO FEED LINE -- which is the whole difference from `leave`
		-- (task 177, docs/design/lobby.md section 4.3). A player standing in the results scene has
		-- not LEFT; he is simply not in the next drive, and printing *"X left"* about a man standing
		-- in front of Karen would be a lie in the shape of a fact.
		--
		-- IT CHANGES NO PHASE BY ITSELF. `enoughPlayers` is read at the `Waiting` and `Scoring` exits
		-- below, so a dismissal during `Scoring` makes the drive fall back to `Waiting` through
		-- `enterWaiting` -- the door task 159 already built, which takes the scene down and frees
		-- everybody -- and the clock is untouched.
		--
		-- WHAT IT DELIBERATELY DOES NOT TOUCH, and every one of these matters:
		--   * the owner's `board` (`Score`), so Karen's results table still shows the drive's points
		--     while the roster behind it is empty: `Match.snapshot`'s rows come from the board;
		--   * the owner's `names`, so `enterAssigning` can rebuild the board for whoever enrols next;
		--   * the owner's `heldStill`, so everybody stays frozen in the ring for the rest of the
		--     scene -- `applyFree(nil)` iterates that table and not `participants`;
		--   * `Player.Team`, so the badges and the team colours in the results scene do not blink
		--     off. The team is handed back one phase later, by the `unassign` effect.
		table.clear(next_.participants)
		table.clear(next_.assignment)
		table.insert(effects, { kind = "broadcast" })
	elseif kind == "withdraw" and event.userId then
		-- ONE PLAYER, OUT OF THIS DRIVE, STILL ON THE SERVER (task 248). KAREN, 2026-10-23: *"when I
		-- respown hunt should over then I can enter to next games"*.
		--
		-- IT IS `dismiss` FOR ONE MAN AND NOT `leave` FOR HIM, and the difference is what the other
		-- players are told: he has not LEFT -- he is standing at the lodge -- so there is no feed
		-- line, exactly as `dismiss` prints none (*"printing 'X left' about a man standing in front
		-- of Karen would be a lie in the shape of a fact"*). What he gets instead is the lobby: the
		-- roster no longer has him, so `Match.isParticipant` is false, `Join.needsReturn` walks him
		-- home by its own level rule and the pads let him into the NEXT drive.
		--
		-- HIS RESULT FOR THIS DRIVE STANDS (the Director's rule). The board is the OWNER's and is
		-- untouched here, exactly as `dismiss` leaves it: his points, his kills and his row stay in
		-- the results table. What goes is his place in the drive.
		--
		-- ONLY FROM INSIDE A LIVE DRIVE. In `Waiting` and `Scoring` there is nothing to be taken out
		-- of, and the roster for the next drive is `enterAssigning`'s business -- so a withdrawal
		-- outside a drive changes nothing and emits nothing, which is the call the `team` branch
		-- above already makes for the same reason.
		if Phase.insideDrive(next_) and next_.participants[event.userId] ~= nil then
			-- HIS ROLE FOR THE NEXT DRIVE IS NOT RECORDED HERE, AND THAT IS A DECISION WITH A
			-- MEASUREMENT BEHIND IT (task 261, item 1). KAREN, 2026-10-25: *"when I respawn and go
			-- again to hunt I need to be same role and from begining"* -- and she gets it, from the
			-- mechanism that already ships rather than from a second one here.
			--
			-- WHAT ALREADY ANSWERS HER: the stored turn (task 217). `Match.applyAssignTeams` writes
			-- *the team he is PLAYING* the moment a drive gives him one (write edge 1), and the turn is
			-- flipped to the OTHER side only for the men still in `state.assignment` when the drive
			-- reaches `Scoring` (write edge 2) -- and the line below takes him out of exactly that
			-- table. So a man who did not finish keeps `nextTeam = the side he was playing`,
			-- `Economy.owedTeams` hands it to `enterAssigning` as `owed`, and `Roster.previousFrom`
			-- turns it into the synthetic row the swap deals back to him. A drive he did not finish is
			-- not a turn he has taken, by construction and with no new field.
			--
			-- AND WHY NOT A SECOND MECHANISM HERE: the obvious one -- remember his team and fold
			-- `other(team)` into `previousAssignment` at `enterScoring` -- was built, and the suite
			-- caught it. `Roster.assign`'s swap COUNTS the inverted rows, and one synthetic inversion
			-- moves `counts.Drivers - counts.Shooters` BY TWO: on an even roster the balance check then
			-- discards the WHOLE swap and everybody loses their rotation, not just him. That is the
			-- defect `Roster.assign`'s own header records against task 221 (*"folding the privilege
			-- into the synthetic `previous` moved the SWAPPED counts by two ... and a low userId drove
			-- every drive"*), and it is not a different defect because the row is a withdrawal.
			next_.participants[event.userId] = nil
			next_.assignment[event.userId] = nil
			-- THE TEAM GOES BACK, which `dismiss` leaves for one phase later and this cannot: a
			-- dismissed player is standing in the results scene where the badges are still wanted,
			-- and this one is walking into a lobby where he is not in the hunt at all. It is the
			-- same effect the end of a drive uses (task 177), for one id.
			table.insert(effects, { kind = "unassign", userIds = { event.userId } })
			-- ...AND THE GUN GOES WITH IT. `Match.mayCarryWeapon` answers false for a man with no
			-- assignment, so this is the sweep being told to ask again NOW rather than a second rule
			-- about who carries what -- Karen's *"I respawn ... with weapons"* is exactly this
			-- question being asked a drive too late.
			table.insert(effects, { kind = "refreshArming", userIds = { event.userId } })
			-- ...AND NOTHING HOLDS HIM. A beater taken out of the drive while the start line is
			-- still held would otherwise walk home at `HELD_WALK_SPEED` or not at all (task 158's
			-- freeze); `free` with one userId frees that one and nobody else.
			table.insert(effects, { kind = "free", userIds = { event.userId } })
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
	elseif kind == "fine" and event.userId then
		-- A MONEY FINE, AS ONE FEED LINE (task 250). KAREN, 2026-10-23: *"take big amount of
		-- money"* -- and a charge she is not told about is a charge she will find on the board at
		-- the end of the drive with no idea what it was for.
		--
		-- IT RIDES THE FEED AND ADDS NO WIRE, which is `signal`'s own decision (task 163):
		-- `MatchEvent` already reaches every client once per event, and the Hud already has the
		-- rule that an entry with no text draws nothing. The owner has decided everything -- which
		-- animal, how much, and the word -- and this machine only says it must now be SAID.
		--
		-- ONLY INSIDE THE DRIVE, exactly as the kill it follows is: `Score.kill` scores nothing in
		-- `Scoring`, so there is nothing to announce either. The drive's own TOTAL is published on
		-- the `Scoring` edge instead (`enterScoring`), where the board goes up.
		if Phase.isLive(next_) then
			feed(effects, {
				kind = "fine",
				userId = event.userId,
				name = event.name,
				money = event.money,
				text = event.text,
				at = now,
			})
		end
	elseif kind == "violation" and event.userId then
		if Phase.isLive(next_) then
			-- FREEZE BEFORE FEED AND BROADCAST, and the order is load-bearing: the owner's `tied` set
			-- is what the snapshot reports, so a broadcast applied before the tie would announce the
			-- violation and show nobody tied for up to STATE_MIN_INTERVAL. The owner has already
			-- decided (phase is Running, this shooter is not tied yet, the grace is over, and
			-- Penalty.judge said yes); this machine only says what must now happen.
			table.insert(effects, { kind = "freeze", userId = event.userId })
			-- ...AND THE MONEY RIDES THE SAME LINE (task 250). `event.money` is the signed delta the
			-- owner charged (`-FINE.SAFETY.money`), absent in a build where that row is gone -- so
			-- the tie and the fine are ONE line about one shot, and two lines would read as two.
			feed(effects, {
				kind = "violation",
				userId = event.userId,
				name = event.name,
				money = event.money,
				text = event.text,
				at = now,
			})
			table.insert(effects, { kind = "broadcast" })
		end
	end

	-- Then time, whatever the event was: a `join` that completes the roster starts the drive on the
	-- same step rather than waiting for the next tick.
	if next_.phase == "Waiting" then
		if enoughPlayers(next_, config) and next_.markersComplete then
			enterAssigning(next_, effects, now, config, event.owed, event.alwaysShooters, event.beaterWishes)
		end
	elseif next_.phase == "Assigning" then
		if now >= next_.phaseEndsAt then
			enterRunning(next_, effects, now, config)
		end
	elseif next_.phase == "Running" then
		-- THE FANFARE HAS FINISHED: THE LINE GOES (task 168). Checked BEFORE the two endings, so a
		-- drive that somehow ended inside its own fanfare still hands the hold back -- `enterScoring`
		-- holds everybody for the scene one effect later, and the order (free, then hold) is the one
		-- `enterAssigning` already relies on.
		if not next_.goFreed and now >= next_.goFreeAt then
			next_.goFreed = true
			table.insert(effects, { kind = "free" })
			table.insert(effects, { kind = "broadcast", force = true })
		end
		-- TWO ENDINGS, THE CLOCK FIRST (task 159). The clock is checked first because it is the rule
		-- that has always held and the one a drive cannot run past; the beaters' crossing can only
		-- ever end a drive EARLIER, never extend one.
		if now >= next_.phaseEndsAt then
			enterScoring(next_, effects, now, config, "clock")
		else
			-- THE LINE IS THROUGH, AND THEN THE GRACE (task 261, item 2). The Director: *"when ALL
			-- beaters (human and bot) are through, the drive ends after a grace of about 15 s (the
			-- last animals cross)"*.
			--
			-- THE LATCH IS SET AND CLEARED ON THE LEVEL, not fired on an edge: `event.beatersAcross`
			-- against `event.beaters` is a MEASUREMENT the owner makes every event, and a beater who
			-- walks back north or a man who joins the drivers mid-drive makes it false again -- at
			-- which point the drive has beaters behind the line and no grace running.
			local through = Phase.beatersThrough(event, config)
			if not through then
				next_.beatersThroughAt = nil
			elseif next_.beatersThroughAt == nil then
				next_.beatersThroughAt = now
				-- ONE FEED LINE, ON THE EDGE, through the entry kind the start of a drive already
				-- uses: no new wire and no new word for the Hud to learn. It is the drive saying what
				-- it is doing, which is the thing Karen could not tell from the outside.
				feed(effects, { kind = "phase", text = "The beaters are through - closing", at = now })
				table.insert(effects, { kind = "broadcast", force = true })
			end
			local at = next_.beatersThroughAt
			if at ~= nil and now >= (at :: number) + Phase.throughGraceSeconds(config) then
				enterScoring(next_, effects, now, config, "beaters")
			else
				maybeRelease(next_, effects, now, event, config)
			end
		end
	elseif next_.phase == "Scoring" then
		if now >= next_.phaseEndsAt then
			if enoughPlayers(next_, config) and next_.markersComplete then
				enterAssigning(next_, effects, now, config, event.owed, event.alwaysShooters, event.beaterWishes)
			else
				enterWaiting(next_, effects, now)
			end
		end
	end

	return freezeState(next_), effects
end

return Phase
