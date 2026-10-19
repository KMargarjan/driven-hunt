--!strict
-- Bots: THE OWNER OF THE BOT RIGS THAT FILL A DRIVE (CLAUDE.md rule 3) -- their lifetime, their
-- movement, their horn rhythm and their clock. Karen's v1 rule: *"Let's make 4 hunters 4 beaters"*,
-- and she plays SOLO, so every slot no real player fills is a visible body: beaters in the orange
-- vest walking the wood abreast and blowing the real horn, hunters standing on the free stands.
--
-- IT DECIDES NOTHING ABOUT THE DRIVE AND THE DRIVE OWNS NO RIG. `Match` hands it a SLOT LIST -- an
-- id, a team, a start CFrame and (for a walker) a goal -- and asks it four questions: fill, gather,
-- clear, and who is where. It never reads a marker, a tag, a Player, a team object or a flag.
--
--   Fill  pure: how many bots a drive wants (ioquake3's `G_CheckMinimumPlayers`, re-pointed)
--   Lane  pure: where each one starts, aims and ends, and how it steps round a trunk
--   Rig   the only writer of a bot rig's Instances and of `Workspace.DriveBots`
--
-- Pattern: a folder module that owns state over pure decision modules driven by an injected world --
-- the shape `src/server/Match/init.luau`, `src/server/Boar/init.luau` and
-- `src/server/Weapon/init.luau` already are, at a fourth instance. NOTHING HAPPENS ON REQUIRE: only
-- `Bots.start(world)` begins production, which is what lets `tests/server/bots_live.spec.luau` build,
-- walk, gather and destroy a whole line with no Play, no avatar service and no clock.
--
-- WHY IT IS NOT A MODULE UNDER `src/server/Match/` (design section 3.1): it needs its OWN clock
-- (`STEP_HZ` 5 against the drive's `MATCH_STEP_HZ` 4) and no module under `Match/` connects anything;
-- `Match`'s own header says it writes "nothing drawn", and eight rigs are drawn; and the rig build
-- can YIELD, which must not happen inside `Match:step`.
--
-- A BOT IS NOT A PLAYER, AND THE MECHANISM IS THAT IT HAS NO userId. Every door in the drive is
-- keyed by one and already refuses a non-numeric id -- `Match.playerDrivers` filters the quick
-- test's phantom out by exactly that, `Match.pushCreditable` refuses an absent userId, and
-- `Phase.participantIds` reads `state.participants`, which only a Player is written into. So "no
-- score row, no push credit, no safety verdict" is structural rather than a filter somebody has to
-- remember.
--
-- Design: docs/design/bots.md
-- Note:   docs/research/2026-10-12-bots.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Drive = require(ReplicatedStorage:WaitForChild("Drive"))

local Fill = require(script.Fill)
local Lane = require(script.Lane)
local Rig = require(script.Rig)

local Bots = {}

-- Exported for specs only, exactly as `Match.Phase` and `Boar.Brain` are.
Bots.Fill = Fill
Bots.Lane = Lane
Bots.Rig = Rig

export type TeamName = "Drivers" | "Shooters"
export type Counts = { hunters: number, beaters: number }
export type Threat = { id: string, position: Vector3, kind: string }

-- ONE BOT, AS THE DRIVE DESCRIBES IT. `to` is nil for a bot that stands, and that is the only thing
-- this module reads to decide walk-or-stand -- so it never learns what a beater is.
export type Slot = {
	id: string,
	team: TeamName,
	from: CFrame,
	to: Vector3?,
	lane: number,
}

-- HOW A BOT BEHAVES. How MANY there are and WHETHER they exist at all is the drive's question and
-- lives in `Match.CONFIG.BOTS` -- two tables, disjoint facts, the split `Match.CONFIG.SOUNDER` and
-- `Boar.CONFIG.SOUNDER` already have. Every number here is a number this module reads.
Bots.CONFIG = {
	-- A WALK, NOT A JOG. `Body.defaultWalkSpeed()` is 16, which reads as a man in a hurry; a beater
	-- walks the wood. K: Karen's eye decides and it is one line.
	--
	-- 9 -> 5, AND IT IS KAREN'S TWO MINUTES (task 162). Karen, 2026-10-12: *"can we make drive
	-- longer, it's to fast / good for testing but now need longer walk for beaters let's say 2
	-- min"*. A bot line ENDS the drive (`Match.beaterCrossing` counts bots into the line), so this
	-- number and where the line starts ARE the length of a drive, and the pair has to make 120 s:
	--
	--   (ForestTest.LINE.spawnNorthStuds 180 + ForestTest.BEATER.behindLineStuds 400
	--    + Match.CONFIG.BOTS.GOAL_PAST_LINE_STUDS 20) / 5 = 120.0 s
	--
	-- `bots_lane.spec` asserts that relation rather than leaving it in a comment, because the two
	-- numbers live in two files that nobody changes together.
	--
	-- 5 STUDS/S IS 1.40 m/s at `ForestTest.SPOOK.METRES_PER_STUD` (0.28), which is a real walking
	-- pace for a man working a wood -- the Director's band was 1.2-1.5 m/s. 9 was 2.52 m/s, which is
	-- a jog, and it is why a drive ended at 0:29 (TASKS.md 161a(e)).
	--
	-- KEEPING 9 WAS MEASURED AND REFUSED: 120 s at 9 studs/s needs 1,060 studs of wood north of the
	-- road, and MEASURED in the Forest Test on 2026-10-12 the trees run out at 775-850 studs
	-- (terrain carries on past 1,000, bare). The wood cannot hold a two-minute walk at a jog, so the
	-- pace had to come down -- see `ForestTest.BEATER.behindLineStuds` for the other half.
	--
	-- A REAL PLAYER IS NOT SLOWED BY THIS. Nothing in this module writes a player's `WalkSpeed` --
	-- `Match.Body` is the only writer of that and still hands out `Body.defaultWalkSpeed()` (16) --
	-- so Karen walking as a beater still covers the 580 studs in ~36 s and then waits for the bot
	-- line, because *"all beaters cross"* is the line and not the first of it.
	WALK_SPEED = 5, -- K
	-- THIS SYSTEM'S OWN CLOCK, declared rather than discovered. The drive's is 4
	-- (`MATCH_STEP_HZ`) and the boar runtime has its own; this is a third.
	STEP_HZ = 5,
	-- WELL INSIDE THE ENGINE'S DOCUMENTED 8-SECOND `MoveTo` TIMEOUT. Roblox: if the goal is not
	-- reached within 8 seconds the humanoid STOPS WALKING and `MoveToFinished` fires with
	-- `reached = false`; the timeout is reset by calling `MoveTo` again inside the window, which is
	-- what the vendor's own sample does. A beater has ~600 studs to cross at 5 studs/s, which is two
	-- minutes (task 162), so ONE `MoveTo` could never do it whatever route it followed.
	--   https://create.roblox.com/docs/reference/engine/classes/Humanoid#MoveTo
	MOVE_REISSUE_SECONDS = 2,
	-- 2.4 SECONDS OF WALKING at `WALK_SPEED`, so the aim point is always still ahead of the bot when
	-- the next re-issue comes round.
	--
	-- AND SINCE TASK 162 THE ARITHMETIC BEHIND THAT SENTENCE HOLDS, which it did not before: the aim
	-- point has to be at least `WALK_SPEED * MOVE_REISSUE_SECONDS` studs out, or the bot can reach
	-- it and have nothing to walk at until the next re-issue. At `WALK_SPEED` 9 that product was 18
	-- against these 12; at 5 it is 10, inside them. `bots_lane.spec` asserts the relation rather
	-- than this comment claiming it.
	--
	-- WHAT IS NOT CLAIMED, because it was not measured: that the old pace was actually clamped by
	-- the cadence. Task 161's own run printed `walkSeconds 30.0` for a 260-stud walk, which is 8.7
	-- studs/s -- not the 6 a hard clamp would give -- so the engine evidently carries a humanoid
	-- past a reached point somehow. Task 162 fixes the relation because it should hold, not because
	-- a measurement said it was biting; the number that decides the length of a drive is the
	-- MEASURED `walkSeconds`, printed by `[bots]` every drive.
	AHEAD_STUDS = 12,
	-- A CHARACTER'S OWN WIDTH: "it is standing on the goal", not "its root is on the point".
	ARRIVE_STUDS = 4,
	-- `LANE_SPACING_STUDS` IS GONE (task 167), with the three functions that read it, and it is
	-- archived in `backups/2026-10-12-bots-lane-offsets.md`. It was 18 studs, so four bots covered 72
	-- studs of front about one base -- and the base is the stand the drive aims at, which is what
	-- Karen saw as *"all bots came to me"*. How wide a drive line is depends on the hunters' front
	-- and where its goals land depends on the shape of the road, and this system can see neither, so
	-- the number does not belong here: `ForestTest.laneSpacing(layout)` holds it now and
	-- `Match.botSlotsFor` asks the world for each lane by index.
	-- `ForestTest.BEATER.clearStuds`: a Roblox character is 2 studs across, so 6 is a body's width
	-- of clearance on every side. The same question answered by the same number.
	LANE_CLEAR_STUDS = 6,
	-- `ForestTest.BEATER.sideStepStuds`, with half its tries: a lane point needs a NUDGE, not a
	-- search. If four nudges cannot clear it, the stuck counter is what says so.
	SIDE_STEP_STUDS = 10,
	SIDE_TRIES = 4,
	-- `ForestTest.BEATER.dropStuds`: dropped onto the ground, not into it.
	DROP_STUDS = 4,
	-- A BOT THAT HAS NOT MOVED THIS FAR IN THIS LONG IS STUCK. At 5 studs/s four seconds is 20
	-- studs, so 3 is unambiguously "not walking". It side-steps and the count is PRINTED -- which is
	-- what opens the research note's escape hatch (SimplePath) with a number rather than a feeling.
	STUCK_SECONDS = 4,
	STUCK_STUDS = 3,

	-- ---------------------------------------------------------------- not getting stuck (task 208)
	--
	-- KAREN, 2026-10-18 ~14:20: *"bot beater stuck we definatly need to fix that they not stuck the
	-- can avoid"* -- and, in the same message, *"do not try to fix forest, we will go together"*. So
	-- these numbers are the whole of the fix: the wood does not change.
	--
	-- THE ESCAPE HATCH ABOVE WAS OPENED BY A MEASUREMENT, which is what it was for. All four places,
	-- every bot sampled at 2 Hz through a whole drive, 2026-10-19
	-- (`docs/research/2026-10-19-bots-unstuck.md` section 4): three episodes over three seconds, the
	-- worst **34.0 s**, and SimplePath was still refused -- what was measured is not a routing
	-- failure (note section 2.4). Two of the three were a beater pressed against an ANCHORED BOT
	-- HUNTER on the stand its own lane aims 20 studs past, which no pathfinder would have helped
	-- with either: `roomToStand` cannot see a body by construction.
	--
	-- THE FAST STUCK TEST, beside the four-second one and not instead of it: the boar's own wedge
	-- test (`Boar.CONFIG.MOVE.WEDGE_SECONDS` 0.75 / `WEDGE_SPEED` 0.5 / `WEDGE_ORDERED_SPEED` 2,
	-- task 150), whose header says why two are needed -- a window only answers on the tick it
	-- closes, so a four-second window is up to four seconds late and cannot start a three-second
	-- recovery.
	--
	-- 0.8 s IS FOUR STEPS at `STEP_HZ` 5: the shortest window that cannot be one sample's noise.
	-- 1.0 studs/s is a FIFTH of the pace it was told to walk, and it is deliberately looser than the
	-- boar's ninth because the measurement leaves two decimal orders of room: a pinned bot crept at
	-- **0.05 studs/s** for eighteen seconds, and a walking one makes **4.7**.
	STUCK_FAST_SECONDS = 0.8,
	STUCK_SLOW_SPEED = 1.0,
	STUCK_ORDERED_SPEED = 2,
	-- HOW LONG A RECOVERY IS HELD. `SIDE_STEP_STUDS` (10) at `WALK_SPEED` (5) is 2.0 s, so the hold
	-- has to be at least that or the bot turns back into the thing before it is past it -- the boar's
	-- `WEDGE_HOLD_SECONDS` reasoning ("the next frame's steering blend starts pulling it back toward
	-- the trunk at once") with this walk's own arithmetic, plus 0.2 s for the turn.
	RECOVER_HOLD_SECONDS = 2.2,
	-- A DETOUR IS A DEFLECTION, NOT A RECOVERY: held for shorter, so the lane is resumed as soon as
	-- the trunk is passed. Above `1 / SEE_HZ` so a held answer is never re-decided inside its hold.
	DETOUR_HOLD_SECONDS = 1.2,
	-- THE DECLARED FLOOR ON THE EXPENSIVE CALL -- SimplePath's `TIME_VARIANCE = 0.07` exists because
	-- the community found one was needed (note 2026-10-12 section 2.4). Every other step; at
	-- `WALK_SPEED` 5 that is 2 studs of travel between looks against a 12-stud lookahead.
	SEE_HZ = 2.5,
	-- THE BODY THAT IS SWEPT DOWN THE LANE. A Roblox character is 2 studs across and about 5 tall;
	-- 4 is its width plus a body's clearance either side, which is `AVOID_RADIUS_STUDS`' own
	-- reasoning for 1.6 against a 2-stud animal, and `ForestTest.clearRoute` sweeps (3, 3, 1) for
	-- the boar for the same reason.
	LANE_BODY_SIZE = Vector3.new(4, 5, 1),
	-- THE CANDIDATE DEFLECTIONS, SMALLEST FIRST: Reynolds' "only as much as the intrusion needs"
	-- (note section 2.2). A 6-stud stand rig 12 studs ahead needs about 27 degrees to pass with a
	-- body's clearance and one 6 studs ahead about 50, so the fan is dense where the answers are and
	-- coarse where they are desperate; the last is a right angle, where a sidestep begins. Five
	-- against the boar's six, because this lookahead is 12 studs and not 26.
	DETOUR_ANGLES_DEG = { 18, 32, 50, 70, 88 },
	-- THE CAST BUDGET, PER BOT PER EVALUATION. With `SEE_HZ` the ceiling is 2.5 * (1 + 5) = **15
	-- swept casts a second per bot** and 120 for eight -- MEASURED at **0.0606 ms a cast** in this
	-- wood (note section 7: 2,000 of them over the beaters' own ground), so the whole line's worst
	-- case is **7.3 ms a second**, or 1.5 ms on a step where every bot is boxed in at once. Today's
	-- step costs 0.20-0.27 ms. That is the number the vendor's performance page does not have.
	DETOUR_CASTS = 5,
	-- ioquake3's `AVOIDREACH_TRIES` IS 4 AND THIS IS 3, on purpose: three sidesteps at
	-- `RECOVER_HOLD_SECONDS` each is 6.6 s and the bar for this task is three seconds an episode, so
	-- the ladder has to reach its last rung sooner than ioquake3's does.
	BACK_OFF_AFTER_TRIES = 3,
	-- Far enough to be clear of a body (2 studs across) or a trunk's flare; short enough that it
	-- reads as a man taking a step back.
	BACK_OFF_STUDS = 8,
	-- WHEN THE TRY COUNT RESETS: PROOF, not a timer. `AHEAD_STUDS` away from where the recovery
	-- began is a bot that has actually got past the thing.
	RECOVERED_STUDS = 12,
	-- A RE-ISSUE COSTS ONE PROPERTY WRITE, so the aim is issued the moment it MOVES (which is task
	-- 208's own defect, below) -- but an aim that jitters by centimetres would re-issue every step
	-- and stutter the gait. 2 studs is less than half a sidestep and more than any rounding.
	AIM_EPSILON_STUDS = 2,
	-- WHAT A MAN STEPS OVER RATHER THAN WALKS ROUND: a log, a bank, a root. Above it is a trunk or a
	-- body, and those are gone round. ioquake3's `BotCheckBarrierJump` is the branch.
	JUMP_OVER_STUDS = 4,
	-- ONE STUD CLEAR OF `JUMP_OVER_STUDS`. Roblox's own default is 7.2, which is a leap; this is a
	-- man getting over a log. **WALKERS ONLY** -- `Rig.prepare` keeps a stander at 0 with its whole
	-- state machine off, which is the vendor's "static NPC" sentence (design section 9.2).
	JUMP_HEIGHT_STUDS = 5.2,
	-- *"BLOW THE HORN NOW AND THEN"*. The floor is the horn's own `COOLDOWN` (1.5 s), far below
	-- this, so a bot can never be the thing that tests the cooldown -- `bots_live.spec` asserts that
	-- relation rather than trusting it. Jittered off a deterministic hash, never a Random: a Random
	-- here would make a bug report unreproducible, which is why `Phase` has none either.
	--
	-- 45 TO 60 SECONDS SINCE TASK 174, UP FROM 18 TO 35. KAREN, 2026-10-13 ~13:40, choosing between
	-- three answers to a measurement from task 172: *"Bots blow less often"*. The measurement is the
	-- reason -- in both of that task's drives the four bot beaters' horns reach 100 m
	-- (`Horn.spookStuds`), so every sounder in the wood was running before the player could walk up
	-- on one, and the notice -> alert -> bolt she asked to SEE did not fire once. Four beaters at
	-- 18-35 s is a blast every ~6.6 s somewhere in the wood, which is less than the time it takes to
	-- walk 100 m; at 45-60 s it is one every ~13 s, so there is quiet between the blasts for a
	-- walk-up to happen in. It is DATA and it is the whole of this item: nothing about the rhythm,
	-- the jitter or the reach changed.
	HORN = { EVERY_SECONDS = { min = 45, max = 60 } }, -- K
	-- EIGHT RIGS OVER FOUR STEPS (0.8 s) instead of one hitch. The build can yield, so it is spawned
	-- off the step loop and rationed -- the declared floor SimplePath's own `TIME_VARIANCE` argues
	-- for, applied to the expensive call this system has.
	BUILD_PER_STEP = 2,
	-- FALSE, AND IT IS THIS REPO'S OWN STATED REASON RATHER THAN TIDINESS: *a prop that stops a
	-- pellet changes what the shot hit, and what the shot hit is what the safety rule and the hit
	-- record read* (`Match.Scene`, `Match.Body` and `ForestTest.Markers` all say it). One property
	-- makes three things true at once: a bot cannot be credited a hit, cannot appear in the drive
	-- report, and cannot stop a shot that is otherwise legal.
	SHOOTABLE = false,
	SEED = 161,
}

Drive.deepFreeze(Bots.CONFIG)

type Bot = {
	id: string,
	team: TeamName,
	lane: number,
	from: CFrame,
	to: Vector3?,
	model: Model?,
	humanoid: Humanoid?,
	horn: any?,
	clips: any?,
	building: boolean,
	lastMoveAt: number,
	lastHornAt: number?,
	hornDueAt: number?,
	-- WHEN THIS BOT'S RAISED HORN COMES DOWN (task 166). Stamped by `Bots.blowFor` off the blast it
	-- just made, so the arm and the sound cannot disagree about how long a blast is.
	blowUntil: number?,
	movedAt: number,
	movedFrom: Vector3?,
	arrived: boolean,
	arrivedAt: number?,
	walkStartedAt: number?,
	gathered: boolean,
	index: number,
	-- THE GAIT SAMPLE (task 164): where this bot was at the last step and when, so the step can
	-- measure the GROUND SPEED it actually made rather than the speed it was told to make. The
	-- stuck window's own `movedFrom`/`movedAt` pair cannot answer this -- it is re-stamped only
	-- every `STUCK_SECONDS`, so it measures over four seconds and a gait needs the last fifth of
	-- one.
	gaitFrom: Vector3?,
	gaitAt: number?,
	-- WHERE IT WAS WHEN IT ARRIVED (task 167), stamped on the arriving step: the results scene moves
	-- every rig into a ring before the report prints, so the position at report time is the ring's.
	arrivedX: number?,
	-- THE FAST STUCK WINDOW (task 208), separate from `movedFrom`/`movedAt` for the same reason the
	-- gait sample is: that pair is re-stamped only every `STUCK_SECONDS` and this one every
	-- `STUCK_FAST_SECONDS`, so one window cannot answer both questions.
	blockFrom: Vector3?,
	blockAt: number?,
	-- THE HELD DECISION (task 208): what it is walking at and until when. ioquake3's
	-- `avoidreachtimes`, SimplePath's `TIME_VARIANCE` and the boar's `_wedgeFor`, which are three
	-- names for "spend the next moment GETTING PAST the thing instead of deciding again".
	holdAim: Vector3?,
	holdUntil: number?,
	-- HOW MANY RECOVERIES IN A ROW (ioquake3's `avoidreachtries`), and where the current run of them
	-- began -- `RECOVERED_STUDS` from there is the proof that resets it.
	tries: number,
	recoverFrom: Vector3?,
	-- WHEN THE FORWARD CAST WAS LAST SPENT, so `SEE_HZ` is a floor and not a wish.
	sawAt: number?,
	-- THE POINT LAST ISSUED TO THE HUMANOID. Without it there is no way to know the aim MOVED, which
	-- is the whole of task 208's third finding.
	aimAt: Vector3?,
	-- WHICH WAY THIS BOT GOES ROUND A THING, drawn once from its own lane rather than from a Random:
	-- two bots on one trunk must not both choose left, and a Random would make a report
	-- unreproducible (the reason `Phase` has none either).
	detourSide: number,
	-- HOW LONG THE CURRENT PIN HAS LASTED, in seconds, so `worstStuckSeconds` can be a DURATION and
	-- not a count: a count cannot say whether one bot was stuck for thirty-four seconds or
	-- thirty-four bots for one, and the task's bar is written in seconds.
	pinnedFor: number?,
}

-- FLAT, IN ONE PLACE. Every distance this module compares against a stud count is horizontal -- the
-- gait's, the stuck window's, the aim's -- for `Lane.arrived`'s own reason: a bot three studs below
-- its goal on a hill has arrived, and a bot that has climbed four studs has not moved along its
-- lane. `Bots.Lane` has its own copy because it is pure and takes no module (the same shape
-- `Boar.Brain`'s `flat` and `Boar`'s `flatOf` are in).
local function flatOf(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local started = false
local world: any = nil
local heartbeat: RBXScriptConnection? = nil
local lastStepAt = 0
local released = false
-- THE EPOCH IS WHAT MAKES A YIELDING BUILD SAFE. Every build task carries the epoch current when it
-- started; a rig that arrives on a stale epoch destroys itself. It is the `Body.dressWhenLoaded`
-- (`watching[userId] ~= row`) and `Horn.blow` (`lastBlast == at`) guard, applied to a yield that can
-- cross a drive boundary.
local epoch = 0
local bots: { [string]: Bot } = {}
local order: { string } = {}
local desired: { hunters: number, beaters: number } = { hunters = 0, beaters = 0 }
local madeIndex = 0

local stats = {
	fills = 0,
	built = 0,
	destroyed = 0,
	buildsFailed = 0,
	staleBuilds = 0,
	dressed = 0,
	dressFailed = 0,
	hornsGiven = 0,
	-- HOW MANY TIMES A BOT'S ARM WENT UP OR CAME DOWN (task 166). `Rig.blow` returns whether it
	-- CHANGED, so this counts poses and not steps -- the discipline `toolPosed` already follows.
	blowPosed = 0,
	blasts = 0,
	blastsRefused = 0,
	walking = 0,
	arrived = 0,
	walkSeconds = 0,
	stuck = 0,
	sideSteps = 0,
	-- TASK 208, AND THEY ARE THE EVIDENCE. `laneCasts` is every swept cast the walk spent (the
	-- budget's own meter, the shape `Boar`'s `avoidCasts` already is); `detours` is how many times a
	-- bot went ROUND something before it touched it; `boxedIn` is how many times no deflection in
	-- the fan had room; and the three recoveries are counted by NAME, because "which branch fired"
	-- is the question a stuck report has to answer and a single total cannot.
	--
	-- `recoverSide` AND NOT `sidesteps`, deliberately: `sideSteps` above is a different counter --
	-- the aim-point nudge `Lane.clearAim` has always made -- and two names differing only in one
	-- capital is a bug nobody would see in a diff.
	laneCasts = 0,
	detours = 0,
	boxedIn = 0,
	recoveries = 0,
	recoverSide = 0,
	recoverBack = 0,
	recoverJump = 0,
	-- THE LONGEST SINGLE PIN OF THE DRIVE, in seconds, measured off the fast window: the one number
	-- the dispatch's bar is written against ("0 bots stuck longer than 3 s"). A count cannot say
	-- whether one bot was stuck for thirty-four seconds or thirty-four bots for one.
	worstStuckSeconds = 0,
	groundMissing = 0,
	gathered = 0,
	-- THE WALK ANIMATION (round 2). A rig built by the engine carries no `Animate` script -- that
	-- comes from `StarterCharacterScripts`, which only a PLAYER's character gets -- so without this
	-- a bot slides upright, which is the first thing Karen would see. These two say whether the
	-- clips actually loaded, because a `LoadAnimation` that fails must show as a NUMBER rather than
	-- as a statue nobody can explain. `clipsFailed` is counted off what `Rig.loadClips` says it
	-- TRIED, so a clip added there can never make it go negative (task 164).
	clipsLoaded = 0,
	clipsFailed = 0,
	-- THE TOOL POSE (task 164). A bot beater carrying the horn plays Roblox's own `ToolNoneAnim`
	-- over the gait, exactly as a player's `Animate` does -- without it the horn rides a freely
	-- swinging arm, which is what the probe measured on every beater in Karen's place.
	toolPosed = 0,
	-- THE CARRY POSE (task 206). ...and then the horn is brought DOWN TO THE SIDE, because the tool
	-- pose above holds the arm straight out in front -- right for a gun, wrong for a horn, and what
	-- Karen's 2026-10-18 frame of a bot beater shows.
	carryPosed = 0,
	steps = 0,
	stepMsTotal = 0,
	stepMsMax = 0,
}

local function now(): number
	if world and world.now then
		return world.now()
	end
	return os.clock()
end

-- ONE HASH IN THIS MODULE, and everything jittered is jittered from it: `Phase.unitHash`'s own
-- discipline and the same arithmetic, because two hashes would be two answers to "is this
-- reproducible".
local function unitHash(seed: number, index: number): number
	local hashed = (seed * 1103515245 + index * 12345) % 2147483648
	return (hashed % 10007) / 10007
end

-- ------------------------------------------------------------------ the rig source seam

function Bots.setRigSource(fn: ((HumanoidDescription, Enum.HumanoidRigType) -> Model?)?)
	Rig.setSource(fn)
end

function Bots.rigSource()
	return Rig.source()
end

-- ------------------------------------------------------------------ building

-- WHERE A SLOT'S BODY IS PUT DOWN, with the world's own ground under it. `groundAt` is INJECTED
-- rather than re-derived: the Forest Test already has ONE answer to "where is the ground"
-- (`ForestTest.Data.groundAt`, the function it already hands to `Markers.setReaders` and to the boar
-- world), and a third copy of it would be two definitions of the same fact. With no reader -- the
-- DEV arena, flat at one `groundY` -- the slot keeps its own Y, which is today's arena exactly.
function Bots.groundedFrom(from: CFrame, config): CFrame
	if world == nil or world.groundAt == nil then
		return from
	end
	local at = from.Position
	local ground = world.groundAt(at.X, at.Z)
	if ground == nil then
		stats.groundMissing += 1
		return from
	end
	local lifted = Vector3.new(at.X, ground + config.DROP_STUDS, at.Z)
	return from - at + lifted
end

local function teamWalks(bot: Bot): boolean
	return bot.to ~= nil
end

local function finishBuild(bot: Bot, model: Model, config, builtAt: number)
	local folder = Rig.folder()
	model.Parent = folder
	local humanoid = Rig.prepare(model, config, teamWalks(bot))
	if humanoid == nil then
		-- A BODY WITH NO HUMANOID CAN NEVER WALK, so it is a build FAILURE and not a bot. Kept as a
		-- slot it would sit in `stats.walking` for the rest of the drive while `stepWalker` returned
		-- at once -- a number that says four bots are walking when none is (round 2 note).
		model:Destroy()
		stats.buildsFailed += 1
		return
	end
	bot.model = model
	bot.humanoid = humanoid
	stats.built += 1

	-- THE OUTFIT IS `Match.Body`'S AND IS REACHED THROUGH THE SEAM, so there is one dressing path in
	-- this repo. `Body.dress` takes a Model and requires only that it be parented, which is why the
	-- parent above comes first.
	if world ~= nil and world.dress ~= nil then
		if world.dress(model, bot.team, world.dressConfig) then
			stats.dressed += 1
		else
			stats.dressFailed += 1
		end
	end

	Rig.place(model, Bots.groundedFrom(bot.from, config), not teamWalks(bot))

	-- A BEATER REALLY CARRIES THE HORN, and WHO may carry one is not a new rule: the seam asks the
	-- horn's own `carriesFor` with the same single boundary read of the same flag that decides for a
	-- player. The Tool is the horn's and the body is this module's -- the same split a player has.
	if teamWalks(bot) and world ~= nil and world.horn ~= nil and world.horn.give ~= nil then
		local tool = world.horn.give(model, bot.team)
		if tool ~= nil then
			bot.horn = tool
			stats.hornsGiven += 1
		end
	end

	-- THE LEGS (round 2). Loaded once per body, counted either way, and a failure cannot stop the
	-- bot walking -- it just slides, which is what every bot did before this.
	local clips, loaded, tried = Rig.loadClips(humanoid)
	bot.clips = clips
	stats.clipsLoaded += loaded
	-- COUNTED OFF WHAT `Rig.loadClips` TRIED, not off a number written here (round 2's note, and
	-- task 164 made it structural): the tool clip was the third one, and with a 2 at this call site
	-- it would have made `clipsFailed` go NEGATIVE -- a number nobody would believe and nobody
	-- would check.
	stats.clipsFailed += tried - loaded
	-- EVERY BOT IS IDLE FROM THE MOMENT IT EXISTS, a walker included, and task 164 is why the
	-- walker was added. A stander never reaches the step loop's gait branch because only a walker
	-- is stepped -- but a WALKER does not reach it either until the drive is RELEASED, and that is
	-- the whole countdown: 15 s (task 163) of four beaters standing on the start line with no clip
	-- playing at all, arms hanging in the rig's bind pose. Karen sees that at the top of every
	-- drive, and it costs one line not to.
	Rig.playClip(clips, "idle")

	-- AND IF IT IS CARRYING SOMETHING, IT HOLDS IT LIKE A PLAYER. After the horn, because the pose
	-- is about there being a Tool in the hand and `bot.horn` is what says so.
	if Rig.holdTool(clips, bot.horn ~= nil) then
		stats.toolPosed += 1
	end

	-- ...AND A HORN HANGS AT THE SIDE (task 206). KAREN, 2026-10-18: *"also horn is broken arm is
	-- wrong"* -- her frame is a bot beater with the horn held straight out in front of it, which is
	-- what the tool pose above does and is right for a gun. The same predicate as the line above,
	-- because it is the same fact: there is a horn in this bot's hand.
	if Rig.holdHorn(clips, bot.horn ~= nil) then
		stats.carryPosed += 1
	end

	bot.movedAt = builtAt
	bot.movedFrom = Rig.positionOf(model)
	bot.lastMoveAt = 0
end

-- SPAWNED, NEVER CALLED INLINE: `Rig.build` may yield, and a yield inside the step loop is the
-- hazard `Phase`'s own ordering comment was paid for twice.
local function startBuild(bot: Bot, config)
	bot.building = true
	local mine = epoch
	local id = bot.id
	task.spawn(function()
		local model = Rig.build(id)
		-- THE EPOCH TEST, AFTER THE YIELD AND BEFORE THE PARENT. A rig whose drive has gone destroys
		-- itself rather than standing in the wood with nobody owning it.
		if mine ~= epoch or bots[id] ~= bot then
			if model ~= nil then
				model:Destroy()
				stats.staleBuilds += 1
			end
			bot.building = false
			return
		end
		bot.building = false
		if model == nil then
			stats.buildsFailed += 1
			return
		end
		finishBuild(bot, model, config, now())
	end)
end

-- ------------------------------------------------------------------ the drive's four questions

-- THIS BOT'S OWN START AND GOAL. PURE, exported so `bots_lane.spec` can state a whole line without
-- building anything.
--
-- IT IS THE IDENTITY SINCE TASK 167, and that is the change rather than an oversight. The drive used
-- to hand one BASE plus a lane number and this turned the pair into a point, `+-LANE_SPACING_STUDS`
-- about the base -- but the spread has to be measured against the hunters' front and the goal has to
-- land on a road that is a sine, and this system can see neither (it reads no marker, no tag and no
-- player, which is the whole of why it is a separate owner). Karen's *"all bots came to me"* was
-- that blindness: 72 studs of front, centred on the one stand she was standing on.
--
-- So the drive states the lane's own start and its own goal -- `Match.botSlotsFor` asks the world for
-- each lane by index, exactly as it asks for a hunter's stand -- and this function is the seam that
-- says so out loud rather than a line of arithmetic nobody can find. The offsets it used to compute
-- are archived in `backups/2026-10-12-bots-lane-offsets.md` (rule 7).
--
-- A STANDER (`to == nil`) stands exactly where the drive put it, which for a bot hunter is the post
-- `Body.placementFor` chose: the same answer this gave before.
function Bots.laneOf(slot: Slot, _config: any?): (CFrame, Vector3?)
	return slot.from, slot.to
end

-- PURE, and the drive's own entry to the arithmetic: `Bots.Fill.counts` by another name, exported
-- here so the view the drive holds is one table and the drive never requires `Fill` itself.
function Bots.fillCounts(real: Counts, config, standsFree: number?): Counts
	return Fill.counts(real, config, standsFree)
end

-- LEVEL-TRIGGERED AND IDEMPOTENT, AND IT NEVER YIELDS. Called at every drive boundary and again
-- whenever a side's real count changes, it compares the slot list it is GIVEN against the rigs it
-- HOLDS, by slot id: a slot that is gone is destroyed, a slot that is new is queued for building, a
-- slot whose start or goal moved is re-placed. The `Horn.refreshCarry` / `Weapon.refreshArming`
-- discipline -- every edge-triggered grant in this repo has been measured missing one.
function Bots.fill(slots: { Slot }, config: any?): Counts
	local cfg = config or Bots.CONFIG
	stats.fills += 1
	local wanted: { [string]: Slot } = {}
	local counts = { hunters = 0, beaters = 0 }
	for _, slot in ipairs(slots) do
		wanted[slot.id] = slot
		-- BY TEAM, NOT BY WALK-OR-STAND (round 1 note). In a world whose markers have no drive line
		-- `botSlotsFor` makes a bot BEATER a stander (`to = nil`), and counting by `to` then printed
		-- `0/4 hunters, 4/0 beaters` -- the report lying about which side is short. `Bots.count(team)`
		-- was already keyed by team; these two now agree.
		if slot.team == "Drivers" then
			counts.beaters += 1
		else
			counts.hunters += 1
		end
	end
	desired = counts

	-- GONE FIRST, so a drive that shrinks frees its bodies before the next build is queued.
	local keep: { string } = {}
	for _, id in ipairs(order) do
		local bot = bots[id]
		if bot == nil then
			continue
		end
		if wanted[id] == nil then
			Rig.destroy(bot.model)
			stats.destroyed += 1
			bots[id] = nil
		else
			table.insert(keep, id)
		end
	end
	order = keep

	for _, slot in ipairs(slots) do
		-- THE LANE'S OWN POINTS, THROUGH THE ONE SEAM THAT NAMES THEM (task 167). The drive measured
		-- them -- it is the only owner that can see the hunters' front and the road -- and this
		-- system walks between them.
		local from, to = Bots.laneOf(slot, cfg)
		local bot = bots[slot.id]
		if bot == nil then
			madeIndex += 1
			bots[slot.id] = {
				id = slot.id,
				team = slot.team,
				lane = slot.lane,
				from = from,
				to = to,
				model = nil,
				humanoid = nil,
				horn = nil,
				clips = nil,
				building = false,
				lastMoveAt = 0,
				lastHornAt = nil,
				hornDueAt = nil,
				movedAt = 0,
				movedFrom = nil,
				arrived = false,
				arrivedAt = nil,
				walkStartedAt = nil,
				gaitFrom = nil,
				gaitAt = nil,
				arrivedX = nil,
				gathered = false,
				index = madeIndex,
				-- TASK 208: the fast stuck window, the held decision, the try counter and the point
				-- last issued. All nil/0, so a bot that has never walked has nothing in force.
				blockFrom = nil,
				blockAt = nil,
				holdAim = nil,
				holdUntil = nil,
				tries = 0,
				recoverFrom = nil,
				sawAt = nil,
				aimAt = nil,
				-- WHICH WAY IT GOES ROUND A THING, drawn once from the lane number and never again:
				-- odd lanes go one way and even the other, so two neighbours on one trunk part
				-- rather than both choosing the same side. The discipline `Rig`'s own jitter follows
				-- -- a hash, never a `Random`, so a report is reproducible.
				detourSide = if slot.lane % 2 == 1 then 1 else -1,
			}
			table.insert(order, slot.id)
		else
			-- THE SAME SLOT, MOVED: re-place rather than rebuild. A drive boundary rebuilds every id
			-- anyway (the drive re-reads its geometry), so this is the mid-drive case.
			local moved = (bot.from.Position - from.Position).Magnitude > 0.1
			bot.team = slot.team
			bot.lane = slot.lane
			bot.from = from
			bot.to = to
			if moved and bot.model ~= nil then
				bot.arrived = false
				bot.arrivedX = nil
				bot.walkStartedAt = nil -- a bot put somewhere else starts its walk again
				-- ...AND ITS GAIT SAMPLE GOES WITH IT (round 1 note). `Rig.place` below teleports
				-- the body, so a sample taken before the move would be differenced across the
				-- teleport and feed `Rig.gait` a speed of hundreds of studs/s for one step.
				bot.gaitFrom = nil
				bot.gaitAt = nil
				bot.gathered = false
				-- ...AND SO DOES EVERYTHING TASK 208 HOLDS, for exactly the gait sample's reason:
				-- a detour committed from where it used to stand, a stuck window anchored there and
				-- an issued aim point behind it are all measurements of a place this body is no
				-- longer in. The teleport invalidates all four.
				bot.blockFrom = nil
				bot.blockAt = nil
				bot.holdAim = nil
				bot.holdUntil = nil
				bot.tries = 0
				bot.recoverFrom = nil
				bot.sawAt = nil
				bot.aimAt = nil
				Rig.place(bot.model, Bots.groundedFrom(from, cfg), bot.to == nil)
			end
		end
	end
	return counts
end

-- GO. A bot is NOT in `Body`'s `held` table and gets no `Body.hold` -- that table is keyed by userId
-- -- so "held exactly as a player is" is this one boolean: until the drive says go, a walker stands
-- on its lane start and blows nothing (`Bots.step` gates both on `released`).
--
-- WHEN THE DRIVE SAYS GO IS NOT THIS MODULE'S QUESTION, and since task 168 the answer is not the
-- phase either: GO is the END of the start fanfare, so the drive holds the whole line -- people and
-- bots -- for `Phase.goHoldSeconds` after `Running` begins and releases both on one dispatch
-- (`Match.botsMayGo`). Before that fix this was called on the first `Running` tick, 2.18 s before
-- the players were freed, and a player beater watched the bot line walk off without her.
function Bots.go(): number
	released = true
	local n = 0
	for _, id in ipairs(order) do
		local bot = bots[id]
		if bot ~= nil and bot.to ~= nil then
			n += 1
		end
	end
	return n
end

function Bots.released(): boolean
	return released
end

-- THE RESULTS SCENE. `ring` is `Scene.ringLayout`'s own answer and `from` is the first slot in it
-- the players have not taken, so the bots stand round the animals with everybody else -- Karen:
-- *"all they standing around the animals"*. It STOPS the walk: an anchored body on a ring CFrame.
function Bots.gather(ring: { CFrame }, from: number): number
	released = false
	-- THE HORNS COME DOWN AT THE DRIVE'S END, IN THIS SAME DISPATCH (round 1 finding 1). The step's
	-- level-trigger would catch it on its next tick anyway, but the results scene begins HERE -- the
	-- rigs are placed into the ring in the lines below -- and a beater that arrives in that ring with
	-- the horn still at its face is the picture Karen would be looking at. So the window is closed
	-- and the pose taken down before anybody is placed, for EVERY bot and not only the ones the ring
	-- has room for.
	for _, id in ipairs(order) do
		local bot = bots[id]
		if bot ~= nil then
			bot.blowUntil = nil
			if Rig.blow(bot.clips, false) then
				stats.blowPosed += 1
			end
		end
	end
	local index = from
	local moved = 0
	for _, id in ipairs(order) do
		local bot = bots[id]
		if bot == nil or bot.model == nil then
			continue
		end
		local cframe = ring[index]
		if cframe == nil then
			break
		end
		if Rig.place(bot.model, cframe, true) then
			Rig.playClip(bot.clips, "idle") -- standing in the ring, not walking in it
			bot.gathered = true
			moved += 1
			stats.gathered += 1
		end
		index += 1
	end
	return moved
end

-- THE PER-DRIVE COUNTERS, and they are reset by `clear()` because the line that prints them says
-- `[bots] drive N` (round 1 note). A lifetime total under a per-drive heading is a number that
-- reads as a measurement and is not one. The LIFETIME ones -- `fills`, `built`, `destroyed`,
-- `steps`, `stepMsTotal`, `epoch` -- are not in this list: they answer "has this system ever gone
-- wrong", which is a question about the session.
local PER_DRIVE_STATS = {
	"buildsFailed",
	"staleBuilds",
	"dressed",
	"dressFailed",
	"hornsGiven",
	"blasts",
	"blastsRefused",
	"walking",
	"arrived",
	"walkSeconds",
	"stuck",
	"sideSteps",
	"groundMissing",
	"gathered",
	"clipsLoaded",
	"clipsFailed",
	-- ROUND 1'S BLOCKING FINDING: `toolPosed` is printed under `[bots] drive N`, and
	-- `Match.syncBots` clears on every drive edge while `finishBuild` re-poses every rebuilt
	-- beater -- so without this row four beaters read `4 tool-posed` on drive 1, `8` on drive 2 and
	-- `12` on drive 3, and the one question it exists to answer ("did the horn pose apply THIS
	-- drive") could not be read off it. Exactly the fault this list's header describes.
	"toolPosed",
	-- `toolPosed`'s reason, for the same kind of counter: "did a bot raise its horn THIS drive".
	"blowPosed",
	-- ...and "did a bot put its horn at its SIDE this drive" (task 206).
	"carryPosed",
	-- TASK 208: every one of them is printed under `[bots] drive N`, so every one of them is
	-- per-drive, for exactly the reason this list's header gives.
	"laneCasts",
	"detours",
	"boxedIn",
	"recoveries",
	"recoverSide",
	"recoverBack",
	"recoverJump",
	"worstStuckSeconds",
	"stepMsMax",
}

-- READABLE FOR SPECS ONLY, the way `Bots.Fill`, `Bots.Lane` and `Bots.Rig` are, and round 1's
-- blocking finding is why: a counter can be ADDED to `stats` and PRINTED under `[bots] drive N`
-- while being left out of this list, and nothing then says so. `bots_live.spec` asserts membership
-- and that every name here is really a counter, so the list cannot quietly rot either.
Bots.PER_DRIVE_STATS = PER_DRIVE_STATS

function Bots.clear(): number
	epoch += 1
	released = false
	for _, key in ipairs(PER_DRIVE_STATS) do
		(stats :: any)[key] = 0
	end
	local n = 0
	for _, id in ipairs(order) do
		local bot = bots[id]
		if bot ~= nil then
			Rig.destroy(bot.model)
			n += 1
		end
		bots[id] = nil
	end
	order = {}
	desired = { hunters = 0, beaters = 0 }
	stats.destroyed += n
	Rig.clearFolder()
	return n
end

-- HOW MANY RIGS EXIST NOW, which is not the same question as how many are WANTED: a build that
-- failed shows up as a gap between the two instead of as silence.
function Bots.count(team: TeamName?): number
	local n = 0
	for _, id in ipairs(order) do
		local bot = bots[id]
		if bot ~= nil and bot.model ~= nil and (team == nil or bot.team == team) then
			n += 1
		end
	end
	return n
end

function Bots.desired(team: TeamName?): number
	if team == "Drivers" then
		return desired.beaters
	elseif team == "Shooters" then
		return desired.hunters
	end
	return desired.hunters + desired.beaters
end

-- EVERY BOT BEATER WITH A BODY, in the shape `Body.driverPositions` answers in -- which is what lets
-- `Match.beaterCrossing` count them against the same `Match.crossedLine` predicate it already uses
-- for people. THE IDS ARE NON-NUMERIC BY DESIGN, so `Match.playerDrivers` drops them from the
-- safety rule and from push credit, exactly as it drops the quick test's phantom.
function Bots.beaters(): { { id: string, position: Vector3 } }
	local out = {}
	for _, id in ipairs(order) do
		local bot = bots[id]
		if bot ~= nil and bot.to ~= nil then
			local at = Rig.positionOf(bot.model)
			if at ~= nil then
				table.insert(out, { id = bot.id, position = at })
			end
		end
	end
	return out
end

-- IS THIS INSTANCE ONE OF THE BEATERS? (task 171) The weapon's fire gate refuses a shot whose aim
-- ray would hit a beater, and a bot beater is a man walking the drive exactly as a player one is --
-- Karen: *"thye just can't shoot them"*, and she tests this world alone with a line of bots.
--
-- `bot.to ~= nil` IS THE SAME QUESTION `teamWalks` ASKS and that is deliberate: a bot that walks is
-- a beater, which is the one definition this module has, used by `Bots.beaters` above and by the
-- gait `Rig.prepare` gives it. A second rule here would be a second answer to "is he a beater".
--
-- It takes an INSTANCE and walks up: a ray hits a limb, not a Model.
function Bots.isBeaterPart(instance: Instance?): boolean
	local node = instance
	while node ~= nil do
		for _, bot in pairs(bots) do
			if bot.model == node then
				return teamWalks(bot)
			end
		end
		node = node.Parent
	end
	return false
end

-- EVERYTHING A BOAR CAN PERCEIVE ABOUT THE BOTS, each carrying its kind -- `Body.boarStimuli`'s own
-- shape and the same two words. **NO `phantom` MARK**, because somebody IS standing here: that mark
-- exists to tell `Boar.CONFIG.PACE` that a "driver" this close is nobody, and the whole point of a
-- visible beater is that it is somebody.
function Bots.threats(): { Threat }
	local out = {}
	for _, id in ipairs(order) do
		local bot = bots[id]
		if bot ~= nil then
			local at = Rig.positionOf(bot.model)
			if at ~= nil then
				table.insert(out, {
					id = bot.id,
					position = at,
					kind = if bot.team == "Drivers" then "driver" else "shooter",
				})
			end
		end
	end
	return out
end

-- WHAT THE DRIVE MAY DO, ENFORCED BY THE SHAPE OF THE TABLE: no `step`, no `start`, no `stop`, no
-- rig and no setter. The `ForestTest.readOnlyBoars` idiom.
function Bots.view()
	return {
		fillCounts = Bots.fillCounts,
		standsFree = Fill.standsFree,
		fill = Bots.fill,
		go = Bots.go,
		gather = Bots.gather,
		clear = Bots.clear,
		count = Bots.count,
		desired = Bots.desired,
		beaters = Bots.beaters,
		-- ...AND WHETHER A PARTICULAR BODY IS ONE OF THEM (task 171), which is the question the
		-- weapon's fire gate asks through `Match.classifyTarget`.
		isBeaterPart = Bots.isBeaterPart,
		threats = Bots.threats,
	}
end

-- ------------------------------------------------------------------ the horn rhythm

-- WHEN THIS BOT NEXT BLOWS, jittered off the one hash. Each bot gets its own due time, so four
-- beaters do not sound together -- which would read as one loud horn rather than as a line of men.
function Bots.hornDue(bot: Bot, at: number, config): number
	local every = config.HORN.EVERY_SECONDS
	local roll = unitHash(config.SEED + bot.index, math.floor(at) + bot.index)
	return at + every.min + (every.max - every.min) * roll
end

-- ONE BLAST, THROUGH THE HORN'S OWN DOOR. The seam is `Weapon.Horn.blowTool`, so a bot is held to
-- the real `Horn.CONFIG.COOLDOWN` by the same table as a player, the real 1.0 s cut of the asset is
-- what sounds, and the real `Blown` signal is what both composition roots already listen to --
-- carrying `blowerUserId = nil`, which `Match.creditPush` already refuses. There is no second blast
-- path and no second reach.
function Bots.blowFor(id: string, at: number, config: any?): boolean
	local cfg = config or Bots.CONFIG
	local bot = bots[id]
	if bot == nil or bot.horn == nil or world == nil or world.horn == nil or world.horn.blow == nil then
		return false
	end
	if world.horn.blow(bot.horn, bot.id, nil, at) then
		bot.lastHornAt = at
		bot.hornDueAt = Bots.hornDue(bot, at, cfg)
		-- THE ARM GOES UP FOR EXACTLY AS LONG AS THE HORN IS AT THE MOUTH, and that length is the
		-- HORN's (`Horn.CONFIG.BLOW_SECONDS`), handed in at the composition root with the rest of
		-- the horn seam. A world that has not wired it gets no raise rather than a number invented
		-- here -- which would be a second answer to "how long is a blast", the failure this repo is
		-- named after.
		local seconds = world.horn.blowSeconds
		bot.blowUntil = if type(seconds) == "number" then at + seconds else nil
		stats.blasts += 1
		return true
	end
	stats.blastsRefused += 1
	return false
end

-- IS THIS BOT'S HORN AT ITS MOUTH RIGHT NOW? PURE in the bot's own stamp and the clock, so a spec
-- drives the raise, the hold and the lower without waiting for a blast or hearing one.
function Bots.blowing(bot: Bot?, at: number): boolean
	if bot == nil then
		return false
	end
	local until_ = bot.blowUntil
	return until_ ~= nil and at < (until_ :: number)
end

-- ------------------------------------------------------------------ the step

local function stepWalker(bot: Bot, at: number, config, roomToStand, laneAhead)
	local model = bot.model
	local humanoid = bot.humanoid
	local goal = bot.to
	if model == nil or humanoid == nil or goal == nil or bot.gathered then
		return
	end
	local here = Rig.positionOf(model)
	if here == nil then
		return
	end

	if bot.arrived then
		return
	end
	-- WHEN THIS WALK BEGAN, stamped on the first released step and nowhere else. Round 1 found the
	-- arrival measuring `at - bot.movedAt`, and `movedAt` is the STUCK WINDOW's own stamp, re-set
	-- every `STUCK_SECONDS` a few lines below -- so a 29-second walk could never print as more than
	-- about four, and the one number this system exists to print (`docs/design/bots.md` section 5.2,
	-- the arithmetic Karen's end-of-drive decision rests on) was a measurement of the wrong thing.
	if bot.walkStartedAt == nil then
		bot.walkStartedAt = at
		-- ...AND THE STUCK WINDOW STARTS WITH THE WALK, not when the body landed. `finishBuild`
		-- stamps `movedAt` at the moment the rig is placed, which is during the COUNTDOWN -- and a
		-- bot standing at the start line because it has been told to is not stuck. Without this
		-- reset a ten-second countdown spends the whole stuck window before the first step, and the
		-- first thing a released bot does is side-step for no reason.
		bot.movedAt = at
		bot.movedFrom = here
		-- ...AND SO DOES THE FAST WINDOW (task 208), for the same reason and not a different one.
		bot.blockAt = at
		bot.blockFrom = here
	end
	if Lane.arrived(here, goal, config.ARRIVE_STUDS) then
		bot.arrived = true
		bot.arrivedAt = at
		-- WHERE IT ARRIVED, STAMPED NOW AND NOT READ LATER (task 167). The first run of this task
		-- read the body's position at REPORT time and printed three bots at x 3020 against goals of
		-- 3030, 2880 and 3330 -- because the report prints at `Scoring`, by which time `applyScene`
		-- has gathered every rig into the results RING behind the middle stand. The lane's arrival
		-- and the ring are two different facts and the measurement needs the first one.
		bot.arrivedX = here.X
		stats.arrived += 1
		stats.walkSeconds = math.max(stats.walkSeconds, at - (bot.walkStartedAt :: number))
		Rig.playClip(bot.clips, "idle") -- it is standing at the line now, not walking at it
		return
	end

	-- THE GAIT, FROM THE GROUND SPEED THIS BOT ACTUALLY MADE (task 164). Karen: *"bots looks odd
	-- improve waliking"*. Measured in her own Forest Test on 2026-10-12, four beaters were covering
	-- 4.70-5.00 studs/s while their walk clip ran at rate 1.000 -- the rate for a 6.74 studs/s gait
	-- (`Rig.GAIT`, every number of it read off the engine's own `Animate` script). So the feet
	-- turned over 35% faster than the ground went by, which is a slide.
	--
	-- MEASURED, NOT ASSUMED, and the difference is the whole point: `config.WALK_SPEED` is what the
	-- bot was TOLD to walk at, and a bot shouldering a trunk or climbing a slope is not making it.
	-- Two steps' positions over the gap between them is its real speed, and `Rig.gait` turns that
	-- into the clip AND the rate -- so a bot that is blocked stands still properly instead of
	-- churning its legs on the spot, which is the other half of "odd".
	--
	-- `config.WALK_SPEED` IS THE FALLBACK FOR THE FIRST STEP ONLY, when there is no previous sample
	-- to difference. It is the pace it was told to walk at, which is the best answer available
	-- before it has moved at all.
	-- HORIZONTAL, AND THAT IS NOT TIDINESS (round 1 note). Both numbers this speed is compared
	-- against were measured off a HORIZONTAL speed -- `NATURAL_WALK_SPEED` 6.74 off the engine's
	-- own rate sweep, `WALK_ABOVE_STUDS` 0.75 off `Animate`'s switch -- and the Forest Test's walk
	-- climbs y 140 -> 234 over ~575 studs, with a drop of `DROP_STUDS` at the start on top. A 3-D
	-- displacement counts that climb as ground speed and reads 5.18 studs/s for a bot walking at 5,
	-- which is a rate lead nobody could trace.
	local measured: number? = nil
	local gaitFrom, gaitAt = bot.gaitFrom, bot.gaitAt
	if gaitFrom ~= nil and gaitAt ~= nil and at > gaitAt then
		local went = here - (gaitFrom :: Vector3)
		measured = Vector3.new(went.X, 0, went.Z).Magnitude / (at - (gaitAt :: number))
	end
	bot.gaitFrom = here
	bot.gaitAt = at
	local clip, rate = Rig.gait(measured or config.WALK_SPEED, bot.clips and bot.clips.playing)
	Rig.playClip(bot.clips, clip, rate)

	-- STUCK, THE LONG WINDOW: it has not moved `STUCK_STUDS` in `STUCK_SECONDS`. The count is what
	-- opened this note's escape hatch with a number rather than a feeling (task 161), and it is
	-- still what `[bots]` prints -- but since task 208 it NO LONGER NUDGES. The recovery is the fast
	-- window's ladder below, which holds its decision and issues it at once; a one-step nudge on a
	-- four-second edge was discarded nine times in ten by the re-issue cadence, and that is how a
	-- bot stood against a spruce for 169 seconds while this counter ticked nine times.
	local from = bot.movedFrom
	if from ~= nil and at - bot.movedAt >= config.STUCK_SECONDS then
		if (here - from).Magnitude < config.STUCK_STUDS then
			stats.stuck += 1
		end
		bot.movedAt = at
		bot.movedFrom = here
	elseif from == nil then
		bot.movedAt = at
		bot.movedFrom = here
	end

	-- ...AND THE FAST ONE BESIDE IT (task 208): the boar's wedge test, which answers inside 0.8 s
	-- instead of up to 4. The two windows are separate stamps on purpose -- one window cannot be
	-- re-set at two rates -- and `Lane.isStuck` is the pure rule.
	local pinned = false
	local blockFrom, blockAt = bot.blockFrom, bot.blockAt
	if blockFrom ~= nil and blockAt ~= nil then
		local over = at - (blockAt :: number)
		if over >= config.STUCK_FAST_SECONDS then
			local covered = flatOf(here - (blockFrom :: Vector3)).Magnitude
			pinned = Lane.isStuck(covered, over, humanoid.WalkSpeed, config)
			if pinned then
				-- HOW LONG THIS PIN HAS LASTED, which is the number the task is judged on. The run
				-- of consecutive pinned windows is what a 34-second episode looks like from in here.
				bot.pinnedFor = (bot.pinnedFor or 0) + over
				stats.worstStuckSeconds = math.max(stats.worstStuckSeconds, bot.pinnedFor :: number)
			else
				bot.pinnedFor = 0
			end
			bot.blockAt = at
			bot.blockFrom = here
		end
	else
		bot.blockAt = at
		bot.blockFrom = here
	end

	-- THE TRY COUNT RESETS ON PROOF, NOT ON A TIMER (ioquake3 drops a reach off its avoid list when
	-- its own clock runs out; here the proof is that the bot actually got past the thing).
	local recoverFrom = bot.recoverFrom
	if bot.tries > 0 and recoverFrom ~= nil then
		if flatOf(here - (recoverFrom :: Vector3)).Magnitude > config.RECOVERED_STUDS then
			bot.tries = 0
			bot.recoverFrom = nil
		end
	end

	-- ------------------------------------------------------------------ what it aims at
	--
	-- THE DECISION IS HELD. While a recovery or a detour is in force nothing re-decides, because the
	-- hold is what the bot SPENDS GETTING PAST the thing: ioquake3's `AVOIDREACH_TIME`, SimplePath's
	-- `TIME_VARIANCE` and the boar's `WEDGE_HOLD_SECONDS`, which are three names for one idea (note
	-- sections 2.1, 2.4, 2.5). Without it the next step's lane point aims straight back into
	-- whatever was in the way, which is what the 34-second pin was made of.
	local aim: Vector3
	local holdUntil = bot.holdUntil
	if holdUntil ~= nil and at < (holdUntil :: number) and bot.holdAim ~= nil then
		aim = bot.holdAim :: Vector3
	elseif pinned then
		-- THE RECOVERY LADDER. Which rung is a MEASUREMENT of what is in front of it, and with no
		-- reader (the DEV arena) it is the sidestep this has always been.
		bot.tries += 1
		bot.recoverFrom = here
		local ahead: number?, step: number? = nil, nil
		if laneAhead ~= nil then
			ahead, step = laneAhead(here, Lane.aimFor(here, goal, config.AHEAD_STUDS), config.LANE_BODY_SIZE, model)
			stats.laneCasts += 1
		end
		local kind = Lane.recoveryFor(ahead, step, bot.tries, config)
		aim = Lane.recoverAim(here, goal, kind, bot.tries, config)
		stats.recoveries += 1
		if kind == "jump" then
			stats.recoverJump += 1
			-- THE JUMP IS THE ACTION, and `JumpHeight` is what makes it worth anything -- a stander
			-- keeps 0 and its state machine off (`Rig.prepare`), so only a walker can ever do this.
			--   https://create.roblox.com/docs/reference/engine/classes/Humanoid
			if humanoid.JumpHeight > 0 then
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		elseif kind == "backoff" then
			stats.recoverBack += 1
		else
			stats.recoverSide += 1
		end
		bot.holdAim = aim
		bot.holdUntil = at + config.RECOVER_HOLD_SECONDS
	else
		local deflected = false
		aim = Lane.aimFor(here, goal, config.AHEAD_STUDS)
		-- SEEING IT BEFORE TOUCHING IT. The swept cast down the lane at `SEE_HZ`, and a detour by
		-- the smallest deflection that has room -- Reynolds' obstacle avoidance (note section 2.2).
		-- This is the half `roomToStand` cannot do: it tests the POINT 12 studs ahead and is blind
		-- to everything between here and there.
		if laneAhead ~= nil and at - (bot.sawAt or -math.huge) >= 1 / config.SEE_HZ then
			bot.sawAt = at
			stats.laneCasts += 1
			local ahead, step = laneAhead(here, aim, config.LANE_BODY_SIZE, model)
			if ahead ~= nil and (step == nil or step > config.JUMP_OVER_STUDS) then
				local blockedAt = function(point: Vector3): boolean
					stats.laneCasts += 1
					return laneAhead(here, point, config.LANE_BODY_SIZE, model) ~= nil
				end
				local detour = Lane.detourAim(here, goal, bot.detourSide, blockedAt, config)
				if detour ~= nil then
					aim = detour :: Vector3
					deflected = true
					stats.detours += 1
					bot.holdAim = aim
					bot.holdUntil = at + config.DETOUR_HOLD_SECONDS
				else
					-- BOXED IN: nothing in the fan had room. Say so with a number and leave it to
					-- the stuck ladder, which is `Boar`'s own `avoidBoxedIn` reasoning -- this
					-- function never has to solve a dead end, only to miss what it can see.
					stats.boxedIn += 1
				end
			end
		end
		-- ...AND THE OLD POINT TEST ANSWERS ITS OWN, DIFFERENT QUESTION, unchanged: "is there room
		-- to STAND where I am sending him".
		--
		-- IT IS ASKED WITH `forced = 0` SINCE TASK 208, AND THAT IS A REAL CHANGE, not tidiness.
		-- The one-step nudge `clearAim` used to make when the FOUR-SECOND window fired is now the
		-- recovery ladder's job, and it has to be: the ladder holds its decision and issues it at
		-- once, which is what the nudge never did (note section 4.3). The two tests cannot disagree
		-- about who recovers, because the fast one is strictly the more sensitive -- 3 studs in 4 s
		-- is 0.75 studs/s, below `STUCK_SLOW_SPEED` (1.0) -- so anything the four-second window
		-- would have nudged is already in the branch above. `STUCK_SECONDS` stays as the REPORT's
		-- long-window number, which is what `[bots]` has always printed and what task 161's escape
		-- hatch was opened with.
		--
		-- ONLY WHEN THIS STEP DID NOT DEFLECT, and that is a defect this task would otherwise have
		-- shipped: `Lane.clearAim` recomputes from the plain LANE point, so letting it speak after a
		-- detour would throw the detour away and aim the bot back at the trunk it had just decided
		-- to go round -- the very shape of the bug being fixed.
		if not deflected then
			local nudged, stepped = Lane.clearAim(here, goal, 0, roomToStand, config)
			if stepped > 0 then
				aim = nudged
				stats.sideSteps += stepped
			end
		end
	end

	-- ------------------------------------------------------------------ ...AND IT REACHES THE HUMANOID
	--
	-- THIS IS TASK 208'S THIRD FINDING, and it is the one that made the other two invisible (note
	-- section 4.3). The aim was computed every step (`STEP_HZ` 5) and issued only every
	-- `MOVE_REISSUE_SECONDS` (2) -- so NINE OUT OF TEN decisions, every stuck nudge among them, were
	-- thrown away before the humanoid ever saw them. In the edge drive the stuck counter fired NINE
	-- times over 34 seconds and the bot never moved.
	--
	-- A DECISION IS ISSUED WHEN IT MOVES. The interval stays as the engine's documented 8-second
	-- `MoveTo` timeout asks (note section 2.3), so a bot walking a clear lane still re-issues every
	-- 2 s and nothing about an unobstructed walk changes; `AIM_EPSILON_STUDS` keeps a jittering aim
	-- from re-issuing every step.
	local moved = bot.aimAt == nil or flatOf(aim - (bot.aimAt :: Vector3)).Magnitude > config.AIM_EPSILON_STUDS
	if moved or at - bot.lastMoveAt >= config.MOVE_REISSUE_SECONDS then
		bot.lastMoveAt = at
		bot.aimAt = aim
		humanoid:MoveTo(aim)
	end
end

-- ONE TICK. `at` and `roomToStand` are the TWO TEST SEAMS and production passes neither: the
-- Heartbeat below calls `Bots.step(dt)`, so the clock is the world's and the clearance reader is the
-- world's. A spec passes them to drive the stuck window without spending four real seconds of the
-- suite's budget (the trap `zz_horn`'s own `zz_` prefix exists for), and to drive the stuck nudge
-- against a reader that answers "clear" -- the branch round 1 found unreachable.
function Bots.step(_dt: number?, clock: number?, roomToStand: any?, laneAhead: any?)
	local config = Bots.CONFIG
	local at = clock or now()
	local clearance = if roomToStand ~= nil then roomToStand else (world ~= nil and world.roomToStand or nil)
	-- THE THIRD SEAM (task 208), injected exactly as the other two are: the world's own swept test
	-- down a lane (`ForestTest.laneAhead`). A world that injects none -- the DEV arena, flat and
	-- empty -- keeps today's behaviour bit for bit, and `bots_live.spec` drives both answers.
	local seeing = if laneAhead ~= nil then laneAhead else (world ~= nil and world.laneAhead or nil)
	local began = os.clock()
	stats.steps += 1

	local queued = 0
	local walking = 0
	for _, id in ipairs(order) do
		local bot = bots[id]
		if bot == nil then
			continue
		end
		if bot.model == nil then
			if not bot.building and queued < config.BUILD_PER_STEP then
				queued += 1
				startBuild(bot, config)
			end
			continue
		end
		if bot.to ~= nil and released then
			walking += 1
			stepWalker(bot, at, config, clearance, seeing)
			if bot.horn ~= nil then
				if bot.hornDueAt == nil then
					bot.hornDueAt = Bots.hornDue(bot, at, config)
				elseif at >= (bot.hornDueAt :: number) then
					Bots.blowFor(bot.id, at, config)
				end
			end
		end
		-- THE HORN AT THE MOUTH (task 166), LEVEL-TRIGGERED FOR EVERY BOT AND OUTSIDE EVERY GUARD
		-- ABOVE -- which is round 1's blocking finding 1 and the comment that used to be here was
		-- false. It sat inside `bot.to ~= nil and released` and `bot.horn ~= nil`, and `Bots.gather`
		-- -- the drive's own end, through `Match.applyScene` -- sets `released = false` as its first
		-- line. So a beater that was mid-blast when the drive ended was never asked again: there was
		-- no next step for it, `gather`'s own `Rig.playClip(clips, "idle")` stops only the gait
		-- (`playClip` iterates `Rig.CLIPS`, which the blow track is not in), and the pose is a
		-- LOOPING clip at `Action` priority -- so it outranks the idle it is standing in and holds
		-- the horn at its face for the whole results scene Karen signed off. One drive in eight with
		-- four beaters, at `HORN.EVERY_SECONDS` against `BLOW_SECONDS`.
		--
		-- HERE IT IS ASKED OF EVERY BOT THAT HAS A BODY, every step, off the one window
		-- `Bots.blowing` answers -- so the ONLY way an arm can be up is that this bot's blast has
		-- not finished, and no path through this file can leave one up. A bot that has never blown
		-- costs one table read: `Rig.blow` returns false without touching the Animator when the
		-- answer it is given is the one already in force.
		if Rig.blow(bot.clips, Bots.blowing(bot, at)) then
			stats.blowPosed += 1
		end
	end
	stats.walking = walking

	local took = (os.clock() - began) * 1000
	stats.stepMsTotal += took
	if took > stats.stepMsMax then
		stats.stepMsMax = took
	end
end

-- ------------------------------------------------------------------ lifetime

function Bots.start(injected: any?)
	assert(not started, "Bots.start() called twice")
	started = true
	world = injected or {}
	released = false
	lastStepAt = 0

	if world.heartbeat ~= false then
		heartbeat = RunService.Heartbeat:Connect(function(dt)
			local at = now()
			if at - lastStepAt < 1 / Bots.CONFIG.STEP_HZ then
				return
			end
			lastStepAt = at
			Bots.step(dt)
		end)
	end
end

function Bots.stop()
	if not started then
		return
	end
	started = false
	Bots.clear() -- nobody is left standing in the wood because a spec stopped the system
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	world = nil
end

-- WHICH CLIP THIS BOT IS PLAYING, for a spec. Read-only: the tracks are `Bots.Rig`'s and nothing
-- outside this module may start or stop one.
function Bots.clipsOf(id: string)
	local bot = bots[id]
	return bot and bot.clips
end

function Bots.stats()
	local out = table.clone(stats)
	out.epoch = epoch
	out.stepMsAvg = if stats.steps > 0 then stats.stepMsTotal / stats.steps else 0
	return out
end

-- ONE LINE PER DRIVE, AND IT IS THE EVIDENCE. The module never prints -- a tool that `require`s it
-- over StudioMCP gets a sandboxed copy with empty state (measured, task 122) -- so the composition
-- root prints what this returns, and the server's own console is the only honest channel for "what
-- are the bots doing".
--
-- IT CARRIES THE TWO NUMBERS NOTHING ELSE CAN ANSWER: the step's own cost, because the vendor's
-- performance page has no numbers in it at all and "eight humanoids are cheap" is therefore a
-- measurement and not a claim; and the walk's own seconds, because the drive now ENDS when the line
-- is through and that is a feel conversation that needs arithmetic in it.
function Bots.report(driveNumber: number): string
	local s = Bots.stats()
	return string.format(
		"[bots] drive %d: %d/%d hunters, %d/%d beaters (%d failed, %d stale) | %d walking, %d arrived in %.1fs"
			.. " | %d stuck, worst pin %.1fs, %d side-steps, %d no-ground | %d detours (%d boxed in),"
			.. " %d recoveries (%d sidestep, %d back off, %d jump), %d casts"
			.. " | %d blasts (%d refused) | %d tool-posed | step %.2f ms avg, %.2f ms max",
		driveNumber,
		Bots.count("Shooters"),
		desired.hunters,
		Bots.count("Drivers"),
		desired.beaters,
		s.buildsFailed,
		s.staleBuilds,
		s.walking,
		s.arrived,
		s.walkSeconds,
		s.stuck,
		-- TASK 208'S OWN NUMBER: the LONGEST single pin of the drive, in seconds. The bar Karen's
		-- complaint is measured against is "no bot stuck longer than 3 s", and a count of stuck
		-- windows cannot say whether that held.
		s.worstStuckSeconds,
		s.sideSteps,
		s.groundMissing,
		s.detours,
		s.boxedIn,
		s.recoveries,
		s.recoverSide,
		s.recoverBack,
		s.recoverJump,
		s.laneCasts,
		s.blasts,
		s.blastsRefused,
		s.toolPosed,
		s.stepMsAvg,
		s.stepMsMax
	)
end

-- WHERE EVERY LANE OF THE LINE ACTUALLY IS, one line for the whole line (task 167). The Director's
-- own condition for the fix: *"print each bot's start x, goal x and arrival x"* -- because *"all bots
-- came to me"* is a claim about three numbers per bot and nothing printed any of them.
--
-- `x` AND NOT A VECTOR: the front is the axis the line spreads along, and the question is whether
-- four beaters cover it or queue on one point of it. The z is the depth of the walk, which
-- `walkSeconds` above already measures.
--
-- EMPTY STRING WHEN THERE ARE NO WALKERS, so the caller can print it or not with one test, which is
-- the shape `Bots.report` is already used with.
function Bots.laneReport(driveNumber: number): string
	local rows = {}
	for _, id in ipairs(order) do
		local bot = bots[id]
		if bot ~= nil and bot.to ~= nil then
			-- THE ARRIVAL IS THE STAMP, not a late read of the body: by the time this prints, the
			-- results scene has GATHERED every rig into its ring, so the body's position then is the
			-- ring's and not the lane's. The first run of this task printed three bots at x 3020
			-- against goals of 3030, 2880 and 3330 for exactly that reason.
			--
			-- A BOT THAT NEVER ARRIVED REPORTS WHERE IT IS, and `nil` once it has been gathered --
			-- because there is no honest answer then and a number that looks like one is this
			-- project's named failure mode.
			local at: number? = bot.arrivedX
			if at == nil and not bot.gathered then
				at = if bot.model ~= nil and bot.model.PrimaryPart ~= nil
					then bot.model.PrimaryPart.Position.X
					else bot.from.Position.X
			end
			table.insert(
				rows,
				string.format(
					"%d: %.0f -> %.0f, at %s%s",
					bot.lane,
					bot.from.Position.X,
					(bot.to :: Vector3).X,
					if at ~= nil then string.format("%.0f", at) else "?",
					if bot.arrived then " (arrived)" elseif bot.gathered then " (gathered first)" else " (still walking)"
				)
			)
		end
	end
	if #rows == 0 then
		return ""
	end
	return string.format("[lanes] drive %d, start x -> goal x: %s", driveNumber, table.concat(rows, " | "))
end

return Bots
