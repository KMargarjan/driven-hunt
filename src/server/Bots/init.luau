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
	WALK_SPEED = 9, -- K
	-- THIS SYSTEM'S OWN CLOCK, declared rather than discovered. The drive's is 4
	-- (`MATCH_STEP_HZ`) and the boar runtime has its own; this is a third.
	STEP_HZ = 5,
	-- WELL INSIDE THE ENGINE'S DOCUMENTED 8-SECOND `MoveTo` TIMEOUT. Roblox: if the goal is not
	-- reached within 8 seconds the humanoid STOPS WALKING and `MoveToFinished` fires with
	-- `reached = false`; the timeout is reset by calling `MoveTo` again inside the window, which is
	-- what the vendor's own sample does. A beater has ~260 studs to cross at 9 studs/s, which is
	-- half a minute, so ONE `MoveTo` could never do it whatever route it followed.
	--   https://create.roblox.com/docs/reference/engine/classes/Humanoid#MoveTo
	MOVE_REISSUE_SECONDS = 2,
	-- 1.3 SECONDS OF WALKING at `WALK_SPEED`, so the aim point is always still ahead of the bot when
	-- the next re-issue comes round.
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
	-- A BOT THAT HAS NOT MOVED THIS FAR IN THIS LONG IS STUCK. At 9 studs/s four seconds is 36
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
	building: boolean,
	lastMoveAt: number,
	lastHornAt: number?,
	hornDueAt: number?,
	movedAt: number,
	movedFrom: Vector3?,
	arrived: boolean,
	arrivedAt: number?,
	gathered: boolean,
	index: number,
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
		if slot.to ~= nil then
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
				building = false,
				lastMoveAt = 0,
				lastHornAt = nil,
				hornDueAt = nil,
				movedAt = 0,
				movedFrom = nil,
				arrived = false,
				arrivedAt = nil,
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

function Bots.hold()
	released = false
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
			bot.gathered = true
			moved += 1
			stats.gathered += 1
		end
		index += 1
	end
	return moved
end

function Bots.clear(): number
	epoch += 1
	released = false
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

local function stepWalker(bot: Bot, at: number, config)
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
	if Lane.arrived(here, goal, config.ARRIVE_STUDS) then
		bot.arrived = true
		bot.arrivedAt = at
		stats.arrived += 1
		if bot.movedAt > 0 then
			stats.walkSeconds = math.max(stats.walkSeconds, at - bot.movedAt)
		end
		return
	end

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

	local aim = Lane.aimFor(here, goal, config.AHEAD_STUDS)
	local room = world ~= nil and world.roomToStand ~= nil
	if room or forced > 0 then
		local clear = if room then world.roomToStand(aim, config.LANE_CLEAR_STUDS) else false
		if not clear then
			for try = forced > 0 and forced or 1, config.SIDE_TRIES do
				local candidate = Lane.sideStep(aim, here, goal, try, config)
				if not room or world.roomToStand(candidate, config.LANE_CLEAR_STUDS) then
					aim = candidate
					stats.sideSteps += 1
					break
				end
			end
		end
	end

	if at - bot.lastMoveAt >= config.MOVE_REISSUE_SECONDS then
		bot.lastMoveAt = at
		humanoid:MoveTo(aim)
	end
end

function Bots.step(_dt: number?)
	local config = Bots.CONFIG
	local at = now()
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
			stepWalker(bot, at, config)
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
			.. " | %d stuck, %d side-steps, %d no-ground | %d blasts (%d refused) | step %.2f ms avg, %.2f ms max",
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
		s.stepMsAvg,
		s.stepMsMax
	)
end

return Bots
