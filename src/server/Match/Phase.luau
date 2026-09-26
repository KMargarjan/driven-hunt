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
	releasesDone: number,
	nextReleaseAt: number,
	boarsAccounted: number, -- killed + escaped this drive
	seed: number,
}

export type Event = {
	kind: string, -- "tick" | "join" | "leave" | "kill" | "gone" | "violation" | "markers"
	userId: number?,
	name: string?,
	record: any?,
	at: number?,
	aliveBoars: number?,
	complete: boolean?,
	missing: { string }?,
	boarSpawns: { Vector3 }?,
}

export type Effect = {
	kind: string,
	force: boolean?, -- "broadcast": a phase change, which no client may miss behind the throttle
	assignment: { [number]: TeamName }?,
	userId: number?, -- "freeze": the one player to tie to a tree
	userIds: { number }?,
	position: Vector3?,
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
		releasesDone = 0,
		nextReleaseAt = math.huge,
		boarsAccounted = 0,
		seed = config.SEED or 1,
	})
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

-- Deterministic jitter, so the release schedule is not a metronome AND a spec still gets the same
-- drive twice from the same seed. A Random here would make a bug report unreproducible, which is the
-- whole reason Roster has none either.
function Phase.jitter(seed: number, index: number, spread: number): number
	if spread <= 0 then
		return 0
	end
	local hashed = (seed * 1103515245 + index * 12345) % 2147483648
	local unit = (hashed % 10007) / 10007 -- [0, 1)
	return (unit * 2 - 1) * spread
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
	state.phaseEndsAt = now + config.INTERMISSION_SECONDS
	state.driveNumber += 1
	state.releasesDone = 0
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
	table.insert(effects, { kind = "placePlayers" })
	table.insert(effects, { kind = "refreshArming", userIds = userIds })
	feed(effects, { kind = "phase", text = "Drive " .. tostring(state.driveNumber), at = now })
	table.insert(effects, { kind = "broadcast", force = true })
end

local function enterRunning(state: State, effects: { Effect }, now: number, config)
	state.phase = "Running"
	state.phaseEndsAt = now + config.DRIVE_SECONDS
	-- The FIRST release is exact; only the rhythm after it is jittered. The drive starts on time,
	-- which is both truer to "the drivers are walking now" and the difference between a harness run
	-- that can stage a shot at a boar and one that cannot: with the first release jittered by up to
	-- 15 s either way, the only boar in the session arrived after the replay had finished
	-- (measured, twice). reviews/task-32/DESIGN_DELTA.md records it.
	state.nextReleaseAt = now + config.FIRST_RELEASE_SECONDS
	feed(effects, { kind = "phase", text = "Drive on", at = now })
	table.insert(effects, { kind = "broadcast", force = true })
end

local function enterScoring(state: State, effects: { Effect }, now: number, config)
	state.phase = "Scoring"
	state.phaseEndsAt = now + config.SCORE_SECONDS
	state.previousAssignment = state.assignment
	state.nextReleaseAt = math.huge
	-- Everyone tied to a tree is freed, and whatever is still standing in the drive is removed.
	table.insert(effects, { kind = "release" })
	table.insert(effects, { kind = "clearBoars" })
	feed(effects, { kind = "phase", text = "Drive over", at = now })
	table.insert(effects, { kind = "broadcast", force = true })
end

local function enterWaiting(state: State, effects: { Effect }, now: number)
	state.phase = "Waiting"
	state.phaseEndsAt = math.huge
	state.nextReleaseAt = math.huge
	state.assignment = {}
	feed(effects, { kind = "phase", text = "Waiting for players", at = now })
	table.insert(effects, { kind = "broadcast", force = true })
end

-- The release schedule: BOARS_PER_DRIVE boars, the first after FIRST_RELEASE_SECONDS and the rest
-- every RELEASE_INTERVAL_SECONDS, each jittered. A release is HELD BACK, never dropped, when the
-- runtime is at its limit.
--
-- THIS IS THE ONLY GUARD, and round 1 found out why that matters: the owner used to check the live
-- boar count as well, and the two disagreed. `event.aliveBoars` was filled in only on the tick, so a
-- join or a leave landing on a release moment read zero, passed here, incremented releasesDone and
-- pushed nextReleaseAt forward -- and then the owner refused the spawn. The boar was never released
-- and never retried: a six-boar drive quietly ran five, and the Hud counted one that did not exist.
-- The owner now fills aliveBoars on EVERY event and has no guard of its own; when the runtime still
-- refuses a spawn it hands the release back through Phase.releaseFailed.
local function maybeRelease(state: State, effects: { Effect }, now: number, event: Event, config)
	if state.releasesDone >= config.BOARS_PER_DRIVE or now < state.nextReleaseAt then
		return
	end
	local alive = event.aliveBoars or 0
	if alive >= config.MAX_ALIVE_BOARS then
		return -- retried next tick; the owner counts it
	end
	local spawns = state.boarSpawns
	local position = if #spawns > 0 then spawns[(state.releasesDone % #spawns) + 1] else nil
	state.releasesDone += 1
	table.insert(effects, { kind = "spawnBoar", position = position })
	state.nextReleaseAt = now
		+ config.RELEASE_INTERVAL_SECONDS
		+ Phase.jitter(state.seed + state.driveNumber, state.releasesDone + 1, config.RELEASE_JITTER_SECONDS)
end

-- The owner could not perform a release this machine committed to. Give it back: releasesDone goes
-- down and the next release is due now, so it is retried on the next step rather than lost.
function Phase.releaseFailed(state: State, now: number): State
	if state.releasesDone <= 0 then
		return state
	end
	local next_ = copy(state)
	next_.releasesDone -= 1
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
	elseif kind == "join" and event.userId then
		next_.participants[event.userId] = event.name or tostring(event.userId)
		feed(effects, { kind = "join", userId = event.userId, name = event.name, at = now })
		if next_.phase == "Running" or next_.phase == "Assigning" then
			-- Assigned immediately to the SMALLER team and placed. Nobody already playing moves: a
			-- team swap mid-drive is the worst kind of surprise (design section 1.2).
			local team = Roster.smallerTeam(Roster.counts(next_.assignment), config)
			next_.assignment[event.userId] = team
			table.insert(effects, { kind = "assignTeams", assignment = { [event.userId] = team } })
			table.insert(effects, { kind = "placePlayers", userIds = { event.userId } })
			table.insert(effects, { kind = "refreshArming", userIds = { event.userId } })
		end
		table.insert(effects, { kind = "broadcast" })
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
		if now >= next_.phaseEndsAt then
			enterScoring(next_, effects, now, config)
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
