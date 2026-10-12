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
	-- WIDE ENOUGH TO READ AS A LINE from a stand 200 studs away, tight enough that four of them
	-- cover one crossing. Four bots span 4 x this, with the middle left for the real beaters.
	LANE_SPACING_STUDS = 18, -- K
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
	-- *"BLOW THE HORN NOW AND THEN"*. The floor is the horn's own `COOLDOWN` (1.5 s), far below
	-- this, so a bot can never be the thing that tests the cooldown -- `bots_live.spec` asserts that
	-- relation rather than trusting it. Jittered off a deterministic hash, never a Random: a Random
	-- here would make a bug report unreproducible, which is why `Phase` has none either.
	HORN = { EVERY_SECONDS = { min = 18, max = 35 } }, -- K
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
}

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
	blasts = 0,
	blastsRefused = 0,
	walking = 0,
	arrived = 0,
	walkSeconds = 0,
	stuck = 0,
	sideSteps = 0,
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

-- THIS BOT'S OWN START AND GOAL, out of the drive's base and its lane number. PURE, exported so
-- `bots_lane.spec` can state the whole line from one base without building anything.
--
-- A STANDER (lane 0, `to == nil`) IS THE IDENTITY: it stands exactly where the drive put it, which
-- for a bot hunter is the post `Body.placementFor` chose.
function Bots.laneOf(slot: Slot, config: any?): (CFrame, Vector3?)
	local cfg = config or Bots.CONFIG
	local from = Lane.startFor(slot.from, slot.lane, cfg)
	local to = if slot.to ~= nil then Lane.goalFor(slot.to :: Vector3, slot.from, slot.lane, cfg) else nil
	return from, to
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
		-- THE LANE IS APPLIED HERE, and this is the one place it is. The drive hands the measured
		-- BASE and a lane number -- it must not require this system to know the spacing (no owner
		-- requires another owner) -- so `Bots.Lane` turns the two into this bot's own start and its
		-- own goal, both offset by the SAME amount along the base's own right, which is what makes a
		-- line that sets off abreast arrive abreast.
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
				gathered = false,
				index = madeIndex,
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
				bot.walkStartedAt = nil -- a bot put somewhere else starts its walk again
				-- ...AND ITS GAIT SAMPLE GOES WITH IT (round 1 note). `Rig.place` below teleports
				-- the body, so a sample taken before the move would be differenced across the
				-- teleport and feed `Rig.gait` a speed of hundreds of studs/s for one step.
				bot.gaitFrom = nil
				bot.gaitAt = nil
				bot.gathered = false
				Rig.place(bot.model, Bots.groundedFrom(from, cfg), bot.to == nil)
			end
		end
	end
	return counts
end

-- GO. The drive's countdown is over, so a walker may walk. A bot is NOT in `Body`'s `held` table and
-- gets no `Body.hold` -- that table is keyed by userId -- so "held through the countdown exactly as
-- a player is" is this one boolean: until the drive says go, a walker stands on its lane start.
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
		stats.blasts += 1
		return true
	end
	stats.blastsRefused += 1
	return false
end

-- ------------------------------------------------------------------ the step

local function stepWalker(bot: Bot, at: number, config, roomToStand)
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
	end
	if Lane.arrived(here, goal, config.ARRIVE_STUDS) then
		bot.arrived = true
		bot.arrivedAt = at
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

	-- STUCK: it has not moved `STUCK_STUDS` in `STUCK_SECONDS`. One forced side-step and a count --
	-- the count is what opens the note's escape hatch with a number rather than a feeling.
	local forced = 0
	local from = bot.movedFrom
	if from ~= nil and at - bot.movedAt >= config.STUCK_SECONDS then
		if (here - from).Magnitude < config.STUCK_STUDS then
			stats.stuck += 1
			forced = 1
		end
		bot.movedAt = at
		bot.movedFrom = here
	elseif from == nil then
		bot.movedAt = at
		bot.movedFrom = here
	end

	-- THE WHOLE AIM DECISION IS `Lane.clearAim`'S, and it is pure in the world's clearance reader so
	-- `bots_live.spec` drives every branch -- including the stuck one with a reader that answers
	-- "clear", which is the case round 1 found unreachable.
	local aim, stepped = Lane.clearAim(here, goal, forced, roomToStand, config)
	stats.sideSteps += stepped

	if at - bot.lastMoveAt >= config.MOVE_REISSUE_SECONDS then
		bot.lastMoveAt = at
		humanoid:MoveTo(aim)
	end
end

-- ONE TICK. `at` and `roomToStand` are the TWO TEST SEAMS and production passes neither: the
-- Heartbeat below calls `Bots.step(dt)`, so the clock is the world's and the clearance reader is the
-- world's. A spec passes them to drive the stuck window without spending four real seconds of the
-- suite's budget (the trap `zz_horn`'s own `zz_` prefix exists for), and to drive the stuck nudge
-- against a reader that answers "clear" -- the branch round 1 found unreachable.
function Bots.step(_dt: number?, clock: number?, roomToStand: any?)
	local config = Bots.CONFIG
	local at = clock or now()
	local clearance = if roomToStand ~= nil then roomToStand else (world ~= nil and world.roomToStand or nil)
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
			stepWalker(bot, at, config, clearance)
			if bot.horn ~= nil then
				if bot.hornDueAt == nil then
					bot.hornDueAt = Bots.hornDue(bot, at, config)
				elseif at >= (bot.hornDueAt :: number) then
					Bots.blowFor(bot.id, at, config)
				end
			end
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
			.. " | %d stuck, %d side-steps, %d no-ground | %d blasts (%d refused) | %d tool-posed"
			.. " | step %.2f ms avg, %.2f ms max",
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
		s.sideSteps,
		s.groundMissing,
		s.blasts,
		s.blastsRefused,
		s.toolPosed,
		s.stepMsAvg,
		s.stepMsMax
	)
end

return Bots
